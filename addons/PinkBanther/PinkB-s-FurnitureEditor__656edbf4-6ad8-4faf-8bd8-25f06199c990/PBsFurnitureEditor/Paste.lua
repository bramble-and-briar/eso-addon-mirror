-- PB's FurnitureEditor -- pasting the clipboard into the house you are standing in
--
-- Three things make this harder than "place N things":
--
--   * Furnishings are consumed. Placing one takes it out of a bag, so a paste is only possible
--     with the items in hand: duplicates in the backpack, a bank, a house chest or the
--     furnishing vault. (Collectible furnishings are placed by collectible id and come from no
--     bag; the client has a "no more than one of this furnishing" message, so a second copy in
--     one house may be refused.)
--   * The server answers one request at a time, and an answer is not the end of it: a placement
--     is a request, then an EVENT_HOUSING_FURNITURE_PLACED whenever the server gets round to it.
--     The new furnishing's id is only known from that event, and a link needs two ids.
--   * Every call this file makes to place, move or link is one nothing in the client's own Lua
--     calls. Whether the console obeys is measured by /pbfe probe; this file is written so that
--     a refusal stops the paste with the client's own words instead of looping on it.
--
-- So a paste is a dry run until it is told "go", it places every furnishing before it links any
-- (a link made early would drag a child along when a parent is nudged into place), it checks
-- where each furnishing really ended up, and it writes down what it placed before it places the
-- next, so that "undo" works after any failure.

local addon = PBS_FURNITURE_EDITOR
local geo = addon.geo

local Call, Try1 = addon.Call, addon.Try1
local IdKey, IsNoId, SameId = addon.IdKey, addon.IsNoId, addon.SameId
local Print, Line = addon.Print, addon.Line
local Round = addon.Round

local EVENT_NAMESPACE = addon.name .. "Run"

-- Where a placeable item may be. The backpack first, because that is where a player expects
-- the copies to come from; the rest in the order the client's own list uses.
local PLACEABLE_BAG_NAMES = {
	"BAG_BACKPACK",
	"BAG_HOUSE_BANK_ONE", "BAG_HOUSE_BANK_TWO", "BAG_HOUSE_BANK_THREE", "BAG_HOUSE_BANK_FOUR",
	"BAG_HOUSE_BANK_FIVE", "BAG_HOUSE_BANK_SIX", "BAG_HOUSE_BANK_SEVEN", "BAG_HOUSE_BANK_EIGHT",
	"BAG_HOUSE_BANK_NINE", "BAG_HOUSE_BANK_TEN",
	"BAG_BANK", "BAG_SUBSCRIBER_BANK", "BAG_FURNITURE_VAULT",
}

-- Answers that mean "not yet" rather than "no".
local RETRY_NAMES = { "REQUEST_IN_PROGRESS", "ALREADY_BEING_MOVED" }

-- Answers that no further furnishing will fare better against, so the paste stops.
local STOP_NAMES = {
	"IN_COMBAT", "IS_DEAD", "NOT_IN_HOUSE", "PERMISSION_FAILED",
}

-- "Metrics limit hit" is the house's performance budget, not a count of one kind: a heavy piece can be refused
-- while light ones still fit. It stops the paste only when that many are refused one after another.
local METRICS_STOP = 3

-- A house has four limits: traditional furnishings, special furnishings, collectibles, special collectibles.
-- A "no room" answer is about ONE of them. A group that mixes kinds (a special piece, a collectible, crate
-- and crafted items) must not stop because one kind is full: the others still fit.
local LIMIT_RESULTS = {
	LOW_IMPACT_ITEM_PLACE_LIMIT = "LOW_IMPACT_ITEM",
	HIGH_IMPACT_ITEM_PLACE_LIMIT = "HIGH_IMPACT_ITEM",
	LOW_IMPACT_COLLECTIBLE_PLACE_LIMIT = "LOW_IMPACT_COLLECTIBLE",
	HIGH_IMPACT_COLLECTIBLE_PLACE_LIMIT = "HIGH_IMPACT_COLLECTIBLE",
}

-- what the player calls each limit, in the order they are shown
local LIMIT_WORDS = {
	{ "LOW_IMPACT_ITEM", "traditional" },
	{ "HIGH_IMPACT_ITEM", "special" },
	{ "LOW_IMPACT_COLLECTIBLE", "collectible" },
	{ "HIGH_IMPACT_COLLECTIBLE", "special collectible" },
}

local function LimitName(limitType)
	for _, row in ipairs(LIMIT_WORDS) do
		if limitType ~= nil and _G["HOUSING_FURNISHING_LIMIT_TYPE_" .. row[1]] == limitType then
			return row[2]
		end
	end
	return tostring(limitType)
end

addon.LimitName = LimitName
addon.LIMIT_WORDS = LIMIT_WORDS

-- placement answer -> the limit type it is about
local function LimitResultMap()
	local map = {}
	for resultSuffix, typeSuffix in pairs(LIMIT_RESULTS) do
		local result = _G["HOUSING_REQUEST_RESULT_" .. resultSuffix]
		if result ~= nil then
			map[result] = _G["HOUSING_FURNISHING_LIMIT_TYPE_" .. typeSuffix] or typeSuffix
		end
	end
	return map
end

-- Placement answers that asking again cannot change.
local NO_RETRY_NAMES = {
	"INVALID_FURNITURE_POSITION", "ITEM_STOLEN", "NO_DUPLICATES", "BLOCKED_BY_BLACKLISTED_COLLECTIBLE",
	"FURNITURE_VAULT_COLLECTIBLE_BLACKLISTED", "ITEM_REMOVE_FAILED_ALREADY_OWN_UNIQUE",
}

-- Link answers that asking again cannot change.
local NO_RELINK_NAMES = {
	"LINK_INFINITE_PARENT_LOOP", "LINK_SAME_FURNITURE", "LINK_NO_BAD_LINKAGE", "PERMISSION_FAILED",
	"LINK_ALREADY_HAS_PARENT", "LINK_ALREADY_LINKED",
}

-- The editor modes to try, in order, when the client says the mode is wrong.
local MODE_ORDER = { "SELECTION", "BROWSE" }

local function ResultSet(names)
	local set = {}
	for _, suffix in ipairs(names) do
		local value = _G["HOUSING_REQUEST_RESULT_" .. suffix]
		if value ~= nil then
			set[value] = true
		end
	end
	return set
end

local MODE_SETTLE_MS = 700
local RETRY_MS = 700
local LINK_FIRST_LOOK_MS = 150
local LINK_POLL_MS = 350
local LINK_POLLS = 12
local MAX_RETRIES = 10

-- A big group is hundreds of requests, and each is a chance for the server to say "not now". So what
-- failed for a reason that may pass is asked again, a few rounds, after a pause in which a late answer
-- can still arrive (it is then taken in, not placed twice).
-- A round is worth another unless the last few got nothing through (a refusal that is for good), and there
-- is a ceiling for a server that gets one more through each time and never finishes.
local REPAIR_ROUNDS_MAX = 8
local REPAIR_STALLS = 4
local REPAIR_WAIT_MS = 1500

-- Is another round of `name` ("place", "link" or "remove") worth it? `count` is how many have gone through
-- so far; the count when the last round began is kept, to see whether it did any good.
local function MoreRounds(run, name, count)
	local mark = run[name .. "Mark"]
	if mark ~= nil then
		if count > mark then
			run[name .. "Stalled"] = 0
		else
			run[name .. "Stalled"] = (run[name .. "Stalled"] or 0) + 1
		end
	end

	if (run[name .. "Rounds"] or 0) >= REPAIR_ROUNDS_MAX or (run[name .. "Stalled"] or 0) >= REPAIR_STALLS then
		return false
	end

	run[name .. "Rounds"] = (run[name .. "Rounds"] or 0) + 1
	run[name .. "Mark"] = count
	return true
end

-- ESO links at most this many children to one furnishing (the Update 20 announcement; the API does not
-- say, and the answer LINK_HAS_TOO_MANY_CHILDREN names the limit when it is hit). Only used in the
-- plan, to say a group is near it; what the server really allows is learned from its own refusal.
local DOCUMENTED_CHILD_LIMIT = 50

-- A furnishing that lands this far from where it was asked to (centimetres, summed over the
-- three axes; radians, summed over the three angles) is "drifted" and is nudged once.
local DRIFT_CM = 3
local DRIFT_RAD = 0.02

-- ---------------------------------------------------------------------------------------
-- What is in the bags
--
-- index.byData[furnitureDataId] = { total = n, slots = { { bag, slot, count }, ... } }
-- ---------------------------------------------------------------------------------------

function addon:IndexInventory()
	local index = { byData = {}, scanned = 0 }

	for _, bagName in ipairs(PLACEABLE_BAG_NAMES) do
		local bag = _G[bagName]
		if bag ~= nil then
			local size = Try1(GetBagSize, bag) or 0
			for slot = 0, size - 1 do
				if Try1(HasItemInSlot, bag, slot)
					and Try1(IsItemPlaceableFurniture, bag, slot)
					and not Try1(IsItemStolen, bag, slot) then
					local dataId = Try1(GetItemFurnitureDataId, bag, slot)
					if dataId and dataId ~= 0 then
						-- (stack, the most a slot of this holds)
						local size = Call(GetSlotStackSize, bag, slot)
						local count = size and size[1] or 1
						local max = size and size[2]
						if max and max > 0 and self.sv.stackMax then
							self.sv.stackMax[dataId] = max
						end

						local entry = index.byData[dataId]
						if not entry then
							entry = { total = 0, slots = {} }
							index.byData[dataId] = entry
						end
						entry.slots[#entry.slots + 1] = { bag = bag, slot = slot, count = count, max = max }
						entry.total = entry.total + count
						index.scanned = index.scanned + 1
					end
				end
			end
		end
	end

	return index
end

-- The next slot that still holds one of these, checked against the client before it is used:
-- a slot another action emptied since the index was taken is dropped, not trusted.
function addon:PickSlot(index, dataId)
	local entry = index.byData[dataId]
	if not entry then
		return nil
	end

	for _, ref in ipairs(entry.slots) do
		if ref.count > 0 then
			local present = Try1(GetItemFurnitureDataId, ref.bag, ref.slot)
			local stack = Try1(GetSlotStackSize, ref.bag, ref.slot) or 0
			if present == dataId and stack > 0 then
				return ref
			end
			entry.total = entry.total - ref.count
			ref.count = 0
		end
	end

	return nil
end

function addon:UseSlot(index, ref, dataId)
	ref.count = ref.count - 1
	local entry = index.byData[dataId]
	if entry then
		entry.total = entry.total - 1
	end
end

-- ---------------------------------------------------------------------------------------
-- The plan
--
-- plan = {
--   nodes = { { ...the clip node..., tx, ty, tz, tpitch, tyaw, troll, skip = reason }, ... },
--   links = { { child = i, parent = j }, ... },
--   opts, shift = { dx, dy, dz }, problems = { text... }, fatal = n,
-- }
-- ---------------------------------------------------------------------------------------

-- opts.rest is the words that are about THIS house (mode, rot, up, force, go): what is left
-- when "to N" and "outside", which say which house, are taken out. A paste that travels first
-- carries it across the jump and runs it on arrival.
local function ParseOptions(words)
	local opts = { mode = "here", delta = 0, up = 0, go = false, force = false, rest = {} }

	local function keep(...)
		for _, word in ipairs({ ... }) do
			opts.rest[#opts.rest + 1] = word
		end
	end

	local i = 1
	while words[i] do
		local word = words[i]
		if word == "same" or word == "here" or word == "aim" then
			opts.mode = word
			keep(word)
		elseif word == "go" then
			opts.go = true
			keep(word)
		elseif word == "force" then
			opts.force = true
			keep(word)
		elseif word == "outside" then
			opts.outside = true
		elseif word == "to" then
			i = i + 1
			local number = tonumber(words[i])
			if not number then
				return nil, "to needs a house number from /pbfe houses, e.g. to 2"
			end
			opts.to = number
		elseif word == "rot" then
			i = i + 1
			local degrees = tonumber(words[i])
			if not degrees then
				return nil, "rot needs a number of degrees, e.g. rot 90"
			end
			opts.delta = math.rad(degrees)
			opts.degrees = degrees
			keep(word, words[i])
		elseif word == "up" then
			i = i + 1
			local cm = tonumber(words[i])
			if not cm then
				return nil, "up needs centimetres, e.g. up 20"
			end
			opts.up = cm
			keep(word, words[i])
		else
			return nil, "unknown option: " .. word
		end
		i = i + 1
	end

	return opts
end

addon.ParseOptions = ParseOptions

function addon:BuildPlan(clip, opts, access, house, inventory)
	local plan = { clip = clip, opts = opts, nodes = {}, links = {}, problems = {}, fatal = 0, hard = 0 }

	-- fatal: refuses "go" unless "force"; hard: refuses it whatever is said
	local function problem(fatal, text, ...)
		local ok, formatted = pcall(string.format, text, ...)
		plan.problems[#plan.problems + 1] = ok and formatted or text
		if fatal == "hard" then
			plan.hard = plan.hard + 1
		elseif fatal and not opts.force then
			plan.fatal = plan.fatal + 1
		end
	end

	if not access.owner then
		problem(true, "you can only place furnishings in a house you own")
	end

	-- ---- where everything goes
	local src = clip.anchor or { x = 0, y = 0, z = 0 }
	local pose = opts.pose
	local dst = src
	if opts.mode == "here" then
		if pose then
			dst = pose
		else
			problem(false, "could not read your position; using the same coordinates")
		end
	elseif opts.mode == "aim" then
		-- the floor point the cursor meets, at the height of the player's feet (Aim.lua)
		if opts.aim and pose then
			dst = { x = opts.aim.x, y = pose.y, z = opts.aim.z }
		elseif opts.aimDeferred then
			-- shown at a doorway: the point is read when the player picks Paste, not now
			problem(false, "the cursor position is read when you pick Paste on the wheel")
		else
			problem("hard", "could not read where the cursor points (%s); use 'here'", tostring(opts.aimWhy or "?"))
		end
	end

	local shift = { dx = dst.x - src.x, dy = (dst.y - src.y) + opts.up, dz = dst.z - src.z }
	plan.shift = shift

	-- Coordinates belong to a house. The original ones put the group exactly where it was only in the
	-- house it came from, or in one with the same layout and origin; anywhere else they may be outside
	-- the walls, which the client refuses piece by piece. "here" has no such problem.
	if opts.mode == "same" and clip.houseId and clip.houseId ~= access.houseId then
		problem(false, "original coordinates come from house %s; they fit only if this house has the same layout (otherwise use 'here')",
			tostring(clip.houseId))
	end

	local conv = self.sv.convention
	if opts.delta ~= 0 and not (conv and conv.sy) then
		problem("hard", "rot needs /pbfe calib first (the client's rotation order is not known yet)")
	end

	local untilted = 0
	for i, node in ipairs(clip.nodes) do
		local target = {}
		for k, v in pairs(node) do
			target[k] = v
		end

		local dx, dz = node.x - src.x, node.z - src.z
		local yaw = node.yaw
		if opts.delta ~= 0 then
			if geo.CanTurn(conv, node.pitch, node.roll) then
				dx, dz = geo.RotateOffset(conv.sy, opts.delta, dx, dz)
				yaw = geo.NormalizeAngle(yaw + opts.delta)
			elseif conv and conv.sy then
				untilted = untilted + 1
				target.skip = "cannot turn a tilted piece"
			end
		end

		-- A cut that was only partly carried out, pasted back with "same": what is still standing
		-- where it was needs no second copy, and counts as already placed when links are made.
		if clip.cut and opts.mode == "same" and opts.delta == 0 and opts.up == 0
			and node.srcKey and access.houseId == clip.houseId and house.byKey[node.srcKey]
			and house.byKey[node.srcKey].dataId == node.dataId then
			target.skip = "still in place"
			target.present = true
		end

		target.tx = Round(dst.x + dx)
		target.ty = Round(dst.y + (node.y - src.y) + opts.up)
		target.tz = Round(dst.z + dz)
		target.tpitch = node.pitch
		target.tyaw = yaw
		target.troll = node.roll
		plan.nodes[i] = target
	end

	if untilted > 0 then
		problem(true, "%d tilted pieces cannot be turned yet (yaw is not outermost for this client)", untilted)
	end

	-- ---- what we have
	local need = {}
	local needOrder = {}
	local placedCollectibles = {}
	for _, entry in ipairs(house.list) do
		if (entry.collectibleId or 0) ~= 0 then
			placedCollectibles[entry.collectibleId] = true
		end
	end

	local limits = {}
	local missing = {}

	local reclassified = 0
	for i, node in ipairs(plan.nodes) do
		-- A clipboard made by an earlier build may call an ordinary item a collectible (see House.lua).
		-- If the client says that collectible cannot be placed, or it is not this furnishing, and the
		-- bags hold the item, it is an item. This only changes the plan; the saved clipboard is left.
		if not node.skip and (node.collectibleId or 0) ~= 0 and inventory.byData[node.dataId] then
			local own = Try1(GetCollectibleFurnitureDataId, node.collectibleId)
			local mismatch = own ~= nil and own ~= 0 and own ~= node.dataId
			if mismatch or Try1(HousingEditorCanPlaceCollectible, node.collectibleId) == false then
				node.collectibleId = 0
				reclassified = reclassified + 1
			end
		end

		if not node.skip then
			if (node.collectibleId or 0) ~= 0 then
				if Try1(HousingEditorCanPlaceCollectible, node.collectibleId) == false then
					node.skip = "that collectible cannot be placed"
					missing[#missing + 1] = { name = node.name, why = "collectible unavailable" }
					-- the same rule as an item that is short: no "go" without "force"
					problem(true, "%s is a collectible you cannot place (not owned?)", tostring(node.name))
				elseif placedCollectibles[node.collectibleId] then
					-- Not a reason to skip: whether a house may hold a second one is the server's
					-- to say (the client has a message for it), and a refusal is logged anyway.
					problem(false, "%s is already placed here; the game may refuse a second", tostring(node.name))
				end
				placedCollectibles[node.collectibleId] = true
			else
				local entry = need[node.dataId]
				if not entry then
					entry = { name = node.name, count = 0 }
					need[node.dataId] = entry
					needOrder[#needOrder + 1] = node.dataId
				end
				entry.count = entry.count + 1
			end
		end
	end

	if reclassified > 0 then
		problem(false, "%d furnishings are recorded as collectibles, but you hold them as items; treating them as items", reclassified)
	end

	local short = {}
	for _, dataId in ipairs(needOrder) do
		local have = inventory.byData[dataId] and inventory.byData[dataId].total or 0
		if have < need[dataId].count then
			short[#short + 1] = { dataId = dataId, name = need[dataId].name, need = need[dataId].count, have = have }
		end
	end

	-- when short, the LAST copies are the ones given up, so that a group loses its leaves first
	if #short > 0 then
		local missingByData = {}
		for _, entry in ipairs(short) do
			missingByData[entry.dataId] = entry.need - entry.have
		end
		for i = #plan.nodes, 1, -1 do
			local node = plan.nodes[i]
			if not node.skip and (node.collectibleId or 0) == 0 and (missingByData[node.dataId] or 0) > 0 then
				missingByData[node.dataId] = missingByData[node.dataId] - 1
				node.skip = "no copy in your bags"
			end
		end
		problem(true, "%d kinds of furnishing are short", #short)
	end

	-- ---- the house's limits
	local counts = {}
	for _, node in ipairs(plan.nodes) do
		if not node.skip then
			local info = Call(GetFurnitureDataInfo, node.dataId)
			local limitType = info and info[4]
			node.limitType = limitType
			if limitType ~= nil then
				counts[limitType] = (counts[limitType] or 0) + 1
			end
		end
	end
	plan.rooms = {}
	for limitType, wanted in pairs(counts) do
		local limit = Try1(GetHouseFurnishingPlacementLimit, access.houseId, limitType)
		local placed = Try1(GetNumHouseFurnishingsPlaced, limitType)
		local room = limit and placed and math.max(limit - placed, 0) or nil
		plan.rooms[#plan.rooms + 1] = { type = limitType, name = LimitName(limitType), wanted = wanted, room = room }
		if room and wanted > room then
			problem(true, "limit %s: room for %d, need %d", LimitName(limitType), room, wanted)
		end
	end
	table.sort(plan.rooms, function(a, b) return a.name < b.name end)

	-- ---- links between the nodes that will exist
	local function isHere(node)
		return node ~= nil and ((not node.skip) or node.present)
	end

	for i, node in ipairs(plan.nodes) do
		if node.parent and isHere(node) then
			if isHere(plan.nodes[node.parent]) then
				plan.links[#plan.links + 1] = { child = i, parent = node.parent }
			else
				problem(false, "%s loses its parent and will not be linked", tostring(node.name))
			end
		end
	end

	plan.short = short
	plan.missing = missing
	return plan
end

-- ---------------------------------------------------------------------------------------
-- The paste command
-- ---------------------------------------------------------------------------------------

local function Meters(cm)
	return string.format("%.1f", cm / 100)
end

function addon:PrintPlan(plan)
	local opts = plan.opts
	local placeable, skipped, present = 0, 0, 0
	for _, node in ipairs(plan.nodes) do
		if node.present then
			present = present + 1
		elseif node.skip then
			skipped = skipped + 1
		else
			placeable = placeable + 1
		end
	end

	Print("plan: %s%s -- %d to place, %d skipped, %d links",
		opts.mode,
		opts.degrees and (" rot " .. opts.degrees) or "",
		placeable, skipped, #plan.links)
	if present > 0 then
		Print("%d are still standing where they were, and will only be linked", present)
	end
	Print("shift: x %s m, y (up) %s m, z %s m",
		Meters(plan.shift.dx), Meters(plan.shift.dy), Meters(plan.shift.dz))

	-- the most children on one furnishing: ESO allows 50, and a group near it is slower and more fragile
	if #plan.links > 0 then
		local fan, most = {}, 0
		for _, link in ipairs(plan.links) do
			fan[link.parent] = (fan[link.parent] or 0) + 1
			most = math.max(most, fan[link.parent])
		end
		Line("  links: %d, most children on one furnishing: %d (ESO's limit is %d)", #plan.links, most, DOCUMENTED_CHILD_LIMIT)
		if most > DOCUMENTED_CHILD_LIMIT then
			Line("  over the limit: the extra links are made under a sibling if the server refuses them")
		end
	end

	-- what each of the house's four limits holds against what this group needs
	for _, row in ipairs(plan.rooms or {}) do
		Line("  %s furnishings: %d to place, room for %s", row.name, row.wanted, row.room ~= nil and tostring(row.room) or "?")
	end

	for i = 1, math.min(#plan.short, 6) do
		local entry = plan.short[i]
		Line("  short: %s  need %d, have %d", entry.name, entry.need, entry.have)
	end
	if #plan.short > 6 then
		Line("  ... and %d more kinds", #plan.short - 6)
	end
	for i = 1, math.min(#plan.missing, 4) do
		Line("  skip: %s (%s)", tostring(plan.missing[i].name), plan.missing[i].why)
	end
	for _, text in ipairs(plan.problems) do
		Line("  note: %s", text)
	end
end

-- The paste command. fromJump is true when this is the second half of "paste to N": the player
-- has just arrived, and has not chosen where to stand.
-- The paste command. fromJump is true when this is the second half of a trip ("paste to N", or a
-- reservation firing on arrival): the player has just arrived and has not chosen where to stand.
-- clip is what to paste (the clipboard unless a reservation brings its own); meta is carried to the
-- run, so that whoever asked can be told how it ended.
--
-- Returns what happened, because a reservation has to know: "started" (a run began, and Finish
-- will say how it ended), "shown" (only a plan was shown), "travelling" (a trip began), or
-- "refused" (nothing was done, and a message says why).
function addon:Paste(words, fromJump, clip, meta)
	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return "refused"
	end

	clip = clip or self.sv.clip
	if not clip or #clip.nodes == 0 then
		Print("the clipboard is empty -- /pbfe copy first")
		return "refused"
	end

	local opts, why = ParseOptions(words)
	if not opts then
		Print("%s", why)
		return "refused"
	end

	-- "paste to N" goes there first and comes back here on arrival (Travel.lua)
	if opts.to and not fromJump then
		self:PasteTo(opts, clip, meta)
		return "travelling"
	end

	-- A jump lands the player on the doorway, where the client will not let anything be placed.
	-- "here" would put the group on that spot, and "aim" at wherever the cursor happens to point, so
	-- after a jump "here ... go" and "aim ... go" show the plan and wait for the player to walk to
	-- where the group belongs.
	if fromJump and opts.go and (opts.mode == "here" or opts.mode == "aim") then
		opts.go = false
		Print("you arrive at the doorway. walk to where the group goes, then pick Paste (or /pbfe paste go)")
	end

	-- "aim": the point under the cursor. A wheel pick took it the moment it was made, while the camera
	-- was still where the player had pointed it; anything else takes it now.
	if opts.mode == "aim" then
		if fromJump then
			opts.aimDeferred = true
		elseif meta and (meta.aim or meta.aimWhy) then
			opts.aim, opts.aimWhy = meta.aim, meta.aimWhy
		else
			opts.aim, opts.aimWhy = self:AimPoint()
		end

		-- A pick on the wheel is the one way to paste that has nothing to type, so it must not end in
		-- "could not read the cursor": it puts the group where the player stands instead, and says so.
		if not opts.aim and not opts.aimDeferred and meta and meta.aimFallback then
			Print("could not read where the cursor points (%s); placing where you stand instead", tostring(opts.aimWhy or "?"))
			opts.mode = "here"
		end
	end

	local access, accessWhy = self:HouseAccess()
	if not access then
		Print("%s", accessWhy)
		return "refused"
	end

	opts.pose = self:PlayerPose()

	local house = self:ReadHouse()
	local inventory = self:IndexInventory()
	local plan = self:BuildPlan(clip, opts, access, house, inventory)
	plan.access = access

	self:PrintPlan(plan)

	if not opts.go then
		if plan.hard > 0 then
			Print("not possible yet; see the notes above")
			return "refused"
		elseif plan.fatal > 0 then
			Print("not ready; fix the above, or add 'force' to place what can be placed")
			return "refused"
		end
		local again = "/pbfe paste " .. (#opts.rest > 0 and (table.concat(opts.rest, " ") .. " ") or "")
		Print("ready. to place: %sgo", again)
		return "shown"
	end

	if plan.hard > 0 then
		Print("refusing: see the notes above")
		return "refused"
	end

	if plan.fatal > 0 then
		Print("refusing: %d problems above. add 'force' to place what can be placed", plan.fatal)
		return "refused"
	end

	self:StartRun(plan, inventory, meta)
	return "started"
end

addon:AddCommand("paste", "  /pbfe paste [to N] [aim|here|same] [rot 90] [up 20] [force] [go]   dry run, then go", function(self, words)
	self:Paste(words, false)
end)

-- ---------------------------------------------------------------------------------------
-- The run
--
-- A run is a state machine driven by timers and the client's events. Every timer carries the
-- run's token as it was when the timer was set; accepting an answer bumps the token, so a
-- timeout that was waiting for an answer that has since arrived does nothing.
-- ---------------------------------------------------------------------------------------

local function Later(run, ms, fn, ...)
	local token = run.token
	local args = { ... }
	addon.Later(ms, function()
		if addon.run ~= run or run.token ~= token then
			return
		end
		fn(addon, run, unpack(args))
	end)
end

addon.RunLater = Later

-- The progress bar reads how far a run has got from the run itself (Progress.lua).
local function Tick(run)
	if addon.progress then
		addon.progress:Update(run)
	end
end

-- Every kind of run (paste, undo, probe) has the same fields, so that Finish and the event
-- handlers never have to ask which kind they are looking at.
function addon:NewRun(kind)
	return {
		kind = kind,
		token = 0,
		nodes = {},
		ids = {},
		known = {},
		failed = {},
		linkFailed = {},
		commandErrors = {},
		placed = 0,
		linked = 0,
		drifted = 0,
		retries = 0,
		modeTries = 0,
		linkIndex = 0,
		stateIndex = 0,
		removed = 0,
		skipped = 0,
		pace = self.sv.paceMs,
		timeout = self.sv.timeoutMs,
		stopSet = ResultSet(STOP_NAMES),
		retrySet = ResultSet(RETRY_NAMES),
		noRetrySet = ResultSet(NO_RETRY_NAMES),
		limitOf = LimitResultMap(),
		full = {},
		noRelinkSet = ResultSet(NO_RELINK_NAMES),
		kids = {},
		cap = {},
		reparented = 0,
		recovered = 0,
		recoveredLinks = 0,
		started = addon.Now(),
		eventCounts = {},
	}
end

function addon:StartRun(plan, inventory, meta)
	local run = self:NewRun("paste")
	run.meta = meta
	run.plan = plan
	run.nodes = plan.nodes
	run.inventory = inventory
	run.phase = "place"
	run.i = 0
	self.run = run

	local house = self:ReadHouse()
	for _, entry in ipairs(house.list) do
		run.known[entry.key] = true
	end
	for i, node in ipairs(plan.nodes) do
		if node.present then
			run.ids[i] = addon.KeyToId(node.srcKey)
			run.existing = (run.existing or 0) + 1
		end
	end

	local older = self.sv.lastPaste
	if older and #older.keys > 0 then
		Print("(the paste before this one can no longer be undone)")
	end

	-- the record "undo" works from, written before the first request
	self.sv.lastPaste = { houseId = plan.access.houseId, keys = {}, at = Try1(GetTimeStamp) or 0 }

	self:RegisterRunEvents()

	local total = 0
	for _, node in ipairs(plan.nodes) do
		if not node.skip then
			total = total + 1
		end
	end
	run.total = total
	if addon.progress then
		addon.progress:RunStarted(run)
	end
	-- a rough time: a placement and a link each take the pace plus what the server takes to answer
	local seconds = math.ceil((total + #plan.links) * (run.pace + 300) / 1000)
	local howLong = seconds >= 120 and string.format("about %d min", math.ceil(seconds / 60)) or string.format("about %d s", seconds)
	Print("placing %d furnishings, %d ms apart, %s. /pbfe stop to stop.", total, run.pace, howLong)

	Later(run, 100, addon.PlaceNext)
end

function addon:RegisterRunEvents()
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_FURNITURE_PLACED, function(_, furnitureId, collectibleId)
		self:OnFurniturePlaced(furnitureId, collectibleId)
	end)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_FURNITURE_REMOVED, function(_, furnitureId)
		self:OnFurnitureRemoved(furnitureId)
	end)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_EDITOR_REQUEST_RESULT, function(_, result)
		self:OnRequestResult(result)
	end)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_EDITOR_COMMAND_RESULT, function(_, result)
		self:OnCommandResult(result)
	end)
end

function addon:UnregisterRunEvents()
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_FURNITURE_PLACED)
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_FURNITURE_REMOVED)
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_EDITOR_REQUEST_RESULT)
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_EDITOR_COMMAND_RESULT)
end

local function NodeLabel(run, index)
	local node = run.nodes[index]
	return string.format("#%d %s", index, tostring(node and node.name or "?"))
end

-- A placement that did not happen. `final` says asking again cannot help; otherwise the piece is asked
-- for again in a later round.
function addon:Fail(run, index, why, final)
	local text = NodeLabel(run, index) .. ": " .. why
	run.failed[#run.failed + 1] = text

	local node = run.nodes[index]
	if node then
		node.failText = text
		node.placeFail = true
		node.noRetry = final or nil
	end
end

-- The failure of a piece that has since been placed (or is about to be asked for again) is no longer a
-- failure.
function addon:ForgetFailure(run, node)
	if node and node.failText then
		for i, text in ipairs(run.failed) do
			if text == node.failText then
				table.remove(run.failed, i)
				break
			end
		end
	end
	if node then
		node.failText = nil
	end
end

-- ---- placing -------------------------------------------------------------------------

function addon:PlaceNext(run)
	run.pending = nil
	run.retries = 0

	if run.stopping then
		return self:Finish(run, "stopped by you")
	end

	run.i = run.i + 1

	local node = run.nodes[run.i]
	if not node then
		return self:PlacementsDone(run)
	end

	if node.skip or (run.only and not run.only[run.i]) then
		return Later(run, 0, addon.PlaceNext)
	end

	self:PlaceCurrent(run)
end

-- Everything has been asked for once. What failed for a reason that may pass is asked for again after a
-- pause, a few rounds; then the links.
function addon:PlacementsDone(run)
	run.only = nil

	local retry, silent = false, false
	for i, node in ipairs(run.nodes) do
		if node.placeFail and not node.noRetry and not node.skip and not run.ids[i] then
			retry = true
			silent = silent or node.timedOut
		end
	end

	if retry and MoreRounds(run, "place", run.placed) then
		-- A piece the server never answered for may still turn up. Asking for another before it has had
		-- one more wait as long as the first would leave two of it in the house.
		return Later(run, REPAIR_WAIT_MS + (silent and run.timeout or 0), addon.PlaceRepair)
	end

	run.phase = "link"
	Tick(run)
	Later(run, run.pace, addon.LinkNext)
end

function addon:PlaceRepair(run)
	local only, count = {}, 0
	for i, node in ipairs(run.nodes) do
		if node.placeFail and not node.noRetry and not node.skip and not run.ids[i] then
			-- it may be in the house though nobody said so
			local found = self:FindNewFurniture(run, node)
			if found then
				run.late = (run.late or 0) + 1
				run.adopted = (run.adopted or 0) + 1
				self:AdoptPlaced(run, i, found)
			else
				only[i] = true
				count = count + 1
			end
		end
	end

	if count == 0 then
		return self:PlacementsDone(run)
	end

	for i in pairs(only) do
		self:ForgetFailure(run, run.nodes[i])
	end
	Print("%d did not place; asking again (round %d)", count, run.placeRounds)

	run.only = only
	run.i = 0
	run.phase = "place"
	Tick(run)
	Later(run, 0, addon.PlaceNext)
end

function addon:SendPlacement(run, node)
	if (node.collectibleId or 0) ~= 0 then
		return Call(HousingEditorRequestCollectiblePlacement,
			node.collectibleId, node.tx, node.ty, node.tz, node.tpitch, node.tyaw, node.troll)
	end

	local ref = self:PickSlot(run.inventory, node.dataId)
	if not ref then
		-- the bags changed since the plan was made: look once more before giving up
		run.inventory = self:IndexInventory()
		ref = self:PickSlot(run.inventory, node.dataId)
	end
	if not ref then
		return nil, "no item"
	end

	run.sentRef = ref
	return Call(HousingEditorRequestItemPlacement,
		ref.bag, ref.slot, node.tx, node.ty, node.tz, node.tpitch, node.tyaw, node.troll)
end

function addon:PlaceCurrent(run)
	local index = run.i
	local node = run.nodes[index]

	if node.limitType ~= nil and run.full[node.limitType] then
		self:Fail(run, index, "the house has no room for any more " .. LimitName(node.limitType) .. " furnishings", true)
		return Later(run, 0, addon.PlaceNext)
	end

	local results, err = self:SendPlacement(run, node)
	if not results then
		if err == "no item" then
			self:Fail(run, index, "no copy left in the bags", true)
			return Later(run, run.pace, addon.PlaceNext)
		end
		return self:Finish(run, "the placement call was refused: " .. tostring(err))
	end

	local result = results[1]

	if addon.IsSuccess(result) then
		run.pending = { kind = "place", index = index }
		if run.sentRef and (node.collectibleId or 0) == 0 then
			self:UseSlot(run.inventory, run.sentRef, node.dataId)
		end
		Later(run, run.timeout, addon.OnPlaceTimeout, index)
		return
	end

	if run.retrySet[result] and run.retries < MAX_RETRIES then
		run.retries = run.retries + 1
		return Later(run, RETRY_MS, addon.PlaceCurrent)
	end

	if result == HOUSING_REQUEST_RESULT_INCORRECT_MODE then
		run.modeTries = run.modeTries + 1
		local name = MODE_ORDER[run.modeTries]
		if not name then
			return self:Finish(run, "placement is refused in every editor mode I know (INCORRECT_MODE)")
		end
		local mode = _G["HOUSING_EDITOR_MODE_" .. name]
		local change, changeErr = Call(HousingEditorRequestModeChange, mode)
		Print("editor mode -> %s: %s", name, change and addon.ResultName(change[1]) or tostring(changeErr))
		return Later(run, MODE_SETTLE_MS, addon.PlaceCurrent)
	end

	local fullType = run.limitOf[result]
	if fullType ~= nil then
		run.full[fullType] = true
		self:Fail(run, index, addon.ResultText(result), true)
		return Later(run, run.pace, addon.PlaceNext)
	end

	if result == HOUSING_REQUEST_RESULT_METRICS_LIMIT_HIT then
		run.metricsHits = (run.metricsHits or 0) + 1
		if run.metricsHits >= METRICS_STOP then
			return self:Finish(run, "stopped: " .. addon.ResultText(result))
		end
		self:Fail(run, index, addon.ResultText(result), true)
		return Later(run, run.pace, addon.PlaceNext)
	end

	if run.stopSet[result] then
		return self:Finish(run, "stopped: " .. addon.ResultText(result))
	end

	self:Fail(run, index, addon.ResultText(result), run.noRetrySet[result])
	Later(run, run.pace, addon.PlaceNext)
end

-- the server never answered; see whether the furnishing arrived without telling us
function addon:OnPlaceTimeout(run, index)
	local pending = run.pending
	if not pending or pending.index ~= index then
		return
	end

	local node = run.nodes[index]
	local found = self:FindNewFurniture(run, node)
	if found then
		self:AcceptPlaced(run, index, found)
		return
	end

	run.pending = nil
	self:Fail(run, index, "no answer from the server in " .. run.timeout .. " ms")
	node.timedOut = true
	Later(run, run.pace, addon.PlaceNext)
end

-- A collectible is matched by its collectible id: the furniture data id the client reports for
-- one is not promised to be the one it was copied under. An item is matched by data id.
function addon:IsTheOneAskedFor(node, furnitureId, collectibleId)
	if (node.collectibleId or 0) ~= 0 then
		if collectibleId == nil then
			collectibleId = Try1(GetCollectibleIdFromFurnitureId, furnitureId)
		end
		if collectibleId == node.collectibleId then
			return true
		end
	end

	local info = Call(GetPlacedHousingFurnitureInfo, furnitureId)
	local dataId = info and info[3]
	if dataId == nil or node.dataId == nil then
		return true
	end
	return dataId == node.dataId
end

-- How far a furnishing is from where this node was asked to go (centimetres; 0 when it cannot be read).
local function DistanceFromTarget(id, node)
	local position = Call(HousingEditorGetFurnitureWorldPosition, id)
	if not position or position[1] == nil or node.tx == nil then
		return 0
	end
	return math.abs(position[1] - node.tx) + math.abs(position[2] - node.ty) + math.abs(position[3] - node.tz)
end

-- A furnishing that is new to the house and is this node's kind. Several can be (a big group has many of
-- one kind), so the one nearest to where this node was asked to go is the one.
function addon:FindNewFurniture(run, node)
	local id = Try1(GetNextPlacedHousingFurnitureId, nil)
	local guard = 0
	local best, bestOff
	while id ~= nil and not IsNoId(id) and guard < 20000 do
		guard = guard + 1
		local key = IdKey(id)
		if not run.known[key] and self:IsTheOneAskedFor(node, id, nil) then
			local off = DistanceFromTarget(id, node)
			if not best or off < bestOff then
				best, bestOff = id, off
			end
		end
		id = Try1(GetNextPlacedHousingFurnitureId, id)
	end
	return best
end

local function Count(run, name)
	run.eventCounts[name] = (run.eventCounts[name] or 0) + 1
end

function addon:OnFurniturePlaced(furnitureId, collectibleId)
	local run = self.run
	if run then
		Count(run, "PLACED")
		if run.onPlaced then
			run.onPlaced(furnitureId, collectibleId)
		end
	end

	local pending = run and run.pending
	if not pending or pending.kind ~= "place" then
		-- an answer nobody was waiting for: a request given up on that happened after all.
		-- It is in the house, so it is recorded, or "undo" would leave it behind.
		if run and run.kind == "paste" then
			self:RecordLatePlacement(run, furnitureId, collectibleId)
		end
		return
	end

	local node = run.nodes[pending.index]
	if not self:IsTheOneAskedFor(node, furnitureId, collectibleId) then
		-- not the one we asked for: someone else's placement, or the client substituted
		run.strays = (run.strays or 0) + 1
		return
	end

	self:AcceptPlaced(run, pending.index, furnitureId)
end

-- An answer nobody was waiting for. If it is a piece that was given up on (no answer in time, or a refusal
-- that turned out to be stale) it is that piece, taken in, linked and counted. Otherwise it is recorded, so
-- that undo does not leave it behind.
function addon:RecordLatePlacement(run, furnitureId, collectibleId)
	local key = IdKey(furnitureId)
	if run.known[key] then
		return
	end

	local best, bestOff
	for i, node in ipairs(run.nodes) do
		if node.placeFail and not run.ids[i] and not node.skip and self:IsTheOneAskedFor(node, furnitureId, collectibleId) then
			local off = DistanceFromTarget(furnitureId, node)
			if not best or off < bestOff then
				best, bestOff = i, off
			end
		end
	end

	if best then
		run.late = (run.late or 0) + 1
		run.adopted = (run.adopted or 0) + 1
		return self:AdoptPlaced(run, best, furnitureId)
	end

	for _, node in ipairs(run.nodes) do
		if not node.skip and self:IsTheOneAskedFor(node, furnitureId, collectibleId) then
			run.known[key] = true
			local last = self.sv.lastPaste
			if last then
				last.keys[#last.keys + 1] = key
			end
			run.late = (run.late or 0) + 1
			return
		end
	end
end

-- A placed furnishing is this node's: remember it, for the links and for undo.
function addon:NotePlaced(run, index, furnitureId)
	local node = run.nodes[index]
	local key = IdKey(furnitureId)
	run.ids[index] = furnitureId
	run.known[key] = true
	run.placed = run.placed + 1
	run.modeTries = 0
	run.metricsHits = 0

	if node and node.placeFail then
		run.recovered = run.recovered + 1
		node.placeFail, node.timedOut = nil, nil
	end
	self:ForgetFailure(run, node)

	local last = self.sv.lastPaste
	if last then
		last.keys[#last.keys + 1] = key
	end
	Tick(run)
end

function addon:AcceptPlaced(run, index, furnitureId)
	run.token = run.token + 1
	run.pending = nil

	self:NotePlaced(run, index, furnitureId)
	self:CheckDrift(run, index)

	if run.placed % 10 == 0 then
		Print("placed %d / %d", run.placed, run.total)
	end

	Later(run, run.pace, addon.PlaceNext)
end

-- The same for one that came late: nothing is waiting on it, so nothing is scheduled or cancelled.
function addon:AdoptPlaced(run, index, furnitureId)
	self:NotePlaced(run, index, furnitureId)
	self:CheckDrift(run, index)
end

local function AngleOff(a, b)
	return math.abs(geo.NormalizeAngle((a or 0) - (b or 0)))
end

-- Did it land where it was asked to? The engine may snap or clamp; a copy that is a hand's
-- breadth off ruins a link group, so one nudge is made and the rest is reported.
function addon:CheckDrift(run, index)
	local node, id = run.nodes[index], run.ids[index]

	local position = Call(HousingEditorGetFurnitureWorldPosition, id)
	local orientation = Call(HousingEditorGetFurnitureOrientation, id)
	if not position then
		return
	end

	local off = math.abs(position[1] - node.tx) + math.abs(position[2] - node.ty) + math.abs(position[3] - node.tz)
	local turn = 0
	if orientation then
		turn = AngleOff(orientation[1], node.tpitch) + AngleOff(orientation[2], node.tyaw) + AngleOff(orientation[3], node.troll)
	end

	if off > DRIFT_CM or turn > DRIFT_RAD then
		run.drifted = run.drifted + 1
		node.drift = off
		if run.drifted <= 3 then
			Print("%s landed %d cm / %.2f rad off; nudging", NodeLabel(run, index), off, turn)
		end
		self:Nudge(run, index, 0)
	end
end

-- One request to put a furnishing where it was meant to be. The server may be busy with the next
-- placement already, so a "not yet" is asked again a few times before it is given up.
function addon:Nudge(run, index, attempt)
	local node, id = run.nodes[index], run.ids[index]
	local nudge = Call(HousingEditorRequestChangePositionAndOrientation,
		id, node.tx, node.ty, node.tz, node.tpitch, node.tyaw, node.troll)

	if not nudge then
		node.nudge = "refused"
		return
	end

	local result = nudge[1]
	if run.retrySet[result] and attempt < 5 then
		return Later(run, RETRY_MS, addon.Nudge, index, attempt + 1)
	end

	node.nudge = addon.ResultName(result)
end

-- ---- asynchronous answers --------------------------------------------------------------

function addon:OnRequestResult(result)
	local run = self.run
	if run then
		Count(run, "REQUEST_RESULT:" .. addon.ResultName(result))
	end
	if not run or addon.IsSuccess(result) then
		return
	end

	run.requestErrors = run.requestErrors or {}
	local name = addon.ResultName(result)
	run.requestErrors[name] = (run.requestErrors[name] or 0) + 1

	-- a refusal while a placement is waiting is that placement's answer
	local pending = run.pending
	if pending and pending.kind == "place" and not run.retrySet[result] then
		run.token = run.token + 1
		run.pending = nil
		if run.stopSet[result] then
			return self:Finish(run, "stopped: " .. addon.ResultText(result))
		end
		local fullType = run.limitOf[result]
		if fullType ~= nil then
			run.full[fullType] = true
		end
		local metrics = result == HOUSING_REQUEST_RESULT_METRICS_LIMIT_HIT
		if metrics then
			run.metricsHits = (run.metricsHits or 0) + 1
			if run.metricsHits >= METRICS_STOP then
				return self:Finish(run, "stopped: " .. addon.ResultText(result))
			end
		end
		self:Fail(run, pending.index, addon.ResultText(result), run.noRetrySet[result] or fullType ~= nil or metrics)
		Later(run, run.pace, addon.PlaceNext)
	end
end

function addon:OnCommandResult(result)
	local run = self.run
	if run then
		Count(run, "COMMAND_RESULT:" .. addon.CommandResultName(result))
	end
	if not run or result == HOUSING_EDITOR_COMMAND_RESULT_SUCCESS then
		return
	end

	local name = addon.CommandResultName(result)
	run.commandErrors[name] = (run.commandErrors[name] or 0) + 1
	if run.commandErrors[name] == 1 then
		Print("editor says: %s", name)
	end
end

function addon:OnFurnitureRemoved(furnitureId)
	local run = self.run
	if run then
		Count(run, "REMOVED")
		if run.onRemoved then
			run.onRemoved(furnitureId)
		end
	end

	local pending = run and run.pending
	if not pending or pending.kind ~= "remove" then
		return
	end

	if SameId(furnitureId, pending.id) then
		self:RemovedOne(run)
	end
end

-- ---- linking ---------------------------------------------------------------------------

-- Links
--
-- Every child is linked to its parent once both are placed. ESO lets one furnishing take a limited number
-- of children (50 by the Update 20 announcement), and the server says so with LINK_HAS_TOO_MANY_CHILDREN
-- when it is reached. A paste copies the shape it was given, so that is only met when the shape came from
-- somewhere that allowed more; then the child is linked under a sibling that the parent already holds. The
-- group is still one tree, and still moves as one. The limit is learned from the refusal (run.cap), so the
-- children after it go straight to a sibling instead of each asking first.

-- the node a link is to be made to now: its parent, or a sibling when the parent will take no more
function addon:LinkTarget(run, link)
	local parent = link.to or link.parent
	local cap = run.cap[parent] or run.capAny
	if cap and (run.kids[parent] or 0) >= cap then
		local sibling = self:SpareSibling(run, link, parent)
		if sibling then
			link.to = sibling
			return sibling
		end
	end
	return parent
end

-- A node that is already a child of `parent` and has room for one more, the nearest to this child.
function addon:SpareSibling(run, link, parent)
	local node = run.nodes[link.child]
	local best, bestOff
	for _, other in ipairs(run.plan.links) do
		local sibling = other.child
		if other.done and (other.to or other.parent) == parent and sibling ~= link.child and run.ids[sibling] then
			local cap = run.cap[sibling] or run.capAny
			if not cap or (run.kids[sibling] or 0) < cap then
				local target = run.nodes[sibling]
				local off = math.abs(node.tx - target.tx) + math.abs(node.ty - target.ty) + math.abs(node.tz - target.tz)
				if not best or off < bestOff then
					best, bestOff = sibling, off
				end
			end
		end
	end
	return best
end

function addon:LinkNext(run)
	run.pending = nil
	run.linkIndex = run.linkIndex + 1

	local link = run.plan.links[run.linkIndex]
	if not link then
		return self:LinksDone(run)
	end

	if link.done or (run.linkOnly and not run.linkOnly[run.linkIndex]) then
		return Later(run, 0, addon.LinkNext)
	end

	local parentIndex = self:LinkTarget(run, link)
	local child, parent = run.ids[link.child], run.ids[parentIndex]
	if not child or not parent then
		self:FailLink(run, link, "the parent or child was not placed")
		return Later(run, 0, addon.LinkNext)
	end

	if SameId(Try1(GetPlacedFurnitureParent, child), parent) then
		self:LinkDone(run, link, parentIndex)
		return Later(run, 0, addon.LinkNext)
	end

	run.linkRetries = 0
	self:LinkCurrent(run)
end

function addon:FailLink(run, link, why, final)
	local text = NodeLabel(run, link.child) .. ": " .. why
	run.linkFailed[#run.linkFailed + 1] = text
	link.failText = text
	link.noRetry = final or nil
end

-- a link that is made (or is about to be tried again) is no longer a failure
function addon:ForgetLinkFailure(run, link)
	if link.failText then
		for i, text in ipairs(run.linkFailed) do
			if text == link.failText then
				table.remove(run.linkFailed, i)
				break
			end
		end
		link.failText = nil
		return true
	end
	return false
end

function addon:LinkDone(run, link, parentIndex)
	link.done = true
	link.to = parentIndex
	run.linked = run.linked + 1
	run.kids[parentIndex] = (run.kids[parentIndex] or 0) + 1

	if link.failedBefore then
		run.recoveredLinks = run.recoveredLinks + 1
	end
	self:ForgetLinkFailure(run, link)
	if parentIndex ~= link.parent then
		run.reparented = run.reparented + 1
	end

	if run.linked % 10 == 0 then
		Print("linked %d / %d", run.linked, #run.plan.links)
	end
	Tick(run)
end

function addon:LinkCurrent(run)
	local link = run.plan.links[run.linkIndex]
	local parentIndex = link.to or link.parent
	local child, parent = run.ids[link.child], run.ids[parentIndex]

	local results, err = Call(HousingEditorRequestSetFurnitureParent, child, parent)
	if not results then
		return self:Finish(run, "the link call was refused: " .. tostring(err))
	end

	local result = results[1]
	if addon.IsSuccess(result) then
		run.token = run.token + 1
		return Later(run, LINK_FIRST_LOOK_MS, addon.LinkVerify, 0)
	end

	if run.retrySet[result] and (run.linkRetries or 0) < MAX_RETRIES then
		run.linkRetries = (run.linkRetries or 0) + 1
		return Later(run, RETRY_MS, addon.LinkCurrent)
	end

	-- "already linked" and "already has a parent" can both be the true state of a link that was made and not
	-- noticed: look at what the child's parent is
	if result == HOUSING_REQUEST_RESULT_LINK_ALREADY_LINKED or result == HOUSING_REQUEST_RESULT_LINK_ALREADY_HAS_PARENT then
		local now = Try1(GetPlacedFurnitureParent, child)
		if SameId(now, parent) then
			self:LinkDone(run, link, parentIndex)
			return Later(run, run.pace, addon.LinkNext)
		end
		local held = now ~= nil and not IsNoId(now) and self:IndexOfPlaced(run, now)
		if held then
			-- linked into this group already (under a sibling): it is connected
			self:LinkDone(run, link, held)
			return Later(run, run.pace, addon.LinkNext)
		end
	end

	-- the parent will take no more children: remember how many it took, and use a sibling instead
	if result == HOUSING_REQUEST_RESULT_LINK_HAS_TOO_MANY_CHILDREN then
		local held = run.kids[parentIndex] or 0
		run.cap[parentIndex] = held
		run.capAny = math.max(run.capAny or 0, held)
		run.capHits = (run.capHits or 0) + 1
		if run.capHits == 1 then
			Print("%s takes no more than %d children; the rest are linked under their siblings",
				NodeLabel(run, parentIndex), held)
		end

		link.to = nil
		local sibling = (link.redirects or 0) < 20 and self:SpareSibling(run, link, link.parent)
		if sibling then
			link.redirects = (link.redirects or 0) + 1
			link.to = sibling
			return Later(run, 0, addon.LinkCurrent)
		end
		self:FailLink(run, link, "the parent takes no more children and there is no sibling to link under", true)
		return Later(run, run.pace, addon.LinkNext)
	end

	self:FailLink(run, link, addon.ResultText(result), run.noRelinkSet[result])
	Later(run, run.pace, addon.LinkNext)
end

-- the node whose placed furnishing this is
function addon:IndexOfPlaced(run, id)
	local key = IdKey(id)
	for index, placed in pairs(run.ids) do
		if IdKey(placed) == key then
			return index
		end
	end
	return nil
end

-- an accepted link is not yet a link: look until the parent shows, or give up
function addon:LinkVerify(run, polls)
	local link = run.plan.links[run.linkIndex]
	local parentIndex = link.to or link.parent
	local child, parent = run.ids[link.child], run.ids[parentIndex]

	if SameId(Try1(GetPlacedFurnitureParent, child), parent) then
		self:LinkDone(run, link, parentIndex)
		return Later(run, run.pace, addon.LinkNext)
	end

	if polls >= LINK_POLLS then
		self:FailLink(run, link, "accepted, but the parent never showed")
		return Later(run, run.pace, addon.LinkNext)
	end

	Later(run, LINK_POLL_MS, addon.LinkVerify, polls + 1)
end

-- Every link has been tried once. Those that failed for a reason that may pass are tried again, after a
-- pause, a few rounds; then the states.
function addon:LinksDone(run)
	run.linkOnly = nil

	local only, count = {}, 0
	for k, link in ipairs(run.plan.links) do
		if not link.done and not link.noRetry and run.ids[link.child] and run.ids[link.to or link.parent] then
			only[k] = true
			count = count + 1
		end
	end

	if count > 0 and MoreRounds(run, "link", run.linked) then
		for k in pairs(only) do
			local link = run.plan.links[k]
			link.failedBefore = true
			self:ForgetLinkFailure(run, link)
		end
		Print("%d links did not take; trying them again (round %d)", count, run.linkRounds)
		run.linkOnly = only
		run.linkIndex = 0
		Tick(run)
		return Later(run, REPAIR_WAIT_MS, addon.LinkNext)
	end

	run.phase = "state"
	Tick(run)
	Later(run, 0, addon.StateNext)
end

-- ---- states (on / off, open / shut) ---------------------------------------------------------

function addon:StateNext(run)
	run.stateIndex = run.stateIndex + 1

	local index = run.stateIndex
	local node = run.nodes[index]
	if not node then
		return self:Finish(run, nil)
	end

	local id = run.ids[index]
	if id and node.state ~= nil and (node.numStates or 0) > 1 then
		local current = Try1(GetPlacedHousingFurnitureCurrentObjectStateIndex, id)
		if current ~= nil and current ~= node.state then
			Call(HousingEditorRequestChangeState, id, node.state)
			run.statesSet = (run.statesSet or 0) + 1
			return Later(run, run.pace, addon.StateNext)
		end
	end

	Later(run, 0, addon.StateNext)
end

-- ---- the end ---------------------------------------------------------------------------

function addon:Finish(run, reason)
	if self.run ~= run then
		return
	end

	self:FinishRun(run, reason)
	self:AfterRun(run)
end

function addon:FinishRun(run, reason)
	run.token = run.token + 1
	self.run = nil
	self:UnregisterRunEvents()
	if addon.progress then
		addon.progress:RunEnded(run, reason)
	end

	local seconds = (addon.Now() - run.started) / 1000
	if reason then
		Print("%s", reason)
	end

	if run.kind == "probe" then
		return
	end

	if run.kind == "undo" then
		self:FinishUndo(run, seconds)
		return
	end

	if run.kind == "cut" then
		self:FinishCut(run, seconds)
		return
	end

	Print("%s: placed %d / %d, linked %d / %d, %d failed (%.0f s)",
		run.kind, run.placed, run.total or 0, run.linked, #(run.plan and run.plan.links or {}),
		#run.failed + #run.linkFailed, seconds)

	local failures = #run.failed + #run.linkFailed
	addon.Alert("%s: placed %d / %d, linked %d / %d%s", run.kind == "paste" and "Paste" or run.kind,
		run.placed, run.total or 0, run.linked, #(run.plan and run.plan.links or {}),
		failures > 0 and (", " .. failures .. " failed") or "")

	if run.drifted > 0 then
		Print("%d landed off their mark", run.drifted)
	end
	if run.late and run.late > 0 then
		local taken = run.adopted or 0
		if taken > 0 then
			Print("%d answered after they were given up on; they were taken in as the pieces they were", taken)
		end
		if run.late > taken then
			Print("%d answered after they were given up on; they are recorded and are not linked", run.late - taken)
		end
	end
	if run.recovered > 0 or run.recoveredLinks > 0 then
		Print("%d placements and %d links failed the first time and went through on another try", run.recovered, run.recoveredLinks)
	end
	if run.reparented > 0 then
		Print("%d links were made under a sibling because a furnishing took no more than %d children; the group is still one tree",
			run.reparented, run.capAny or 0)
	end
	for i = 1, math.min(#run.failed, 6) do
		Line("  %s", run.failed[i])
	end
	for i = 1, math.min(#run.linkFailed, 6) do
		Line("  link %s", run.linkFailed[i])
	end
	if run.requestErrors then
		for name, count in pairs(run.requestErrors) do
			Line("  server said %s x%d", name, count)
		end
	end
	if run.placed > 0 then
		Print("/pbfe undo takes back what this placed")
	end

	-- every piece is placed (or was already standing), and nothing failed: complete
	run.complete = run.placed + (run.existing or 0) == #run.nodes
		and #run.failed == 0 and #run.linkFailed == 0

	-- The clipboard has been pasted: Paste / Move leave the quickslot wheel. (A paste that placed
	-- nothing leaves it there, to be tried again.)
	local pasted = run.plan and run.plan.clip == self.sv.clip and self.sv.clip
	if pasted and run.placed > 0 then
		self.sv.clipFresh = false
	end

	-- Everything is down: the clipboard has done its job and is emptied, so what was copied does not
	-- sit there to be pasted by mistake (and a finished cut stops blocking the next copy). If any piece
	-- was not placed the clipboard stays: for a cut it is the only record of where the rest goes, and
	-- for a copy it is what a second try pastes from. /pbfe save <name> keeps one for good.
	if pasted and run.complete then
		local was = pasted.cut and "the move is complete" or "pasted"
		self.sv.clip = nil
		self.sv.clipFresh = false
		Print("%s; the clipboard is emptied (/pbfe save <name> before a paste keeps a copy)", was)
	elseif pasted and run.placed > 0 then
		local left = #run.nodes - run.placed - (run.existing or 0)
		Print("%d not placed: the clipboard is kept, so it can be tried again%s", left,
			pasted.cut and " (a cut is only recorded there)" or "")
	end
end

addon:AddCommand("stop", "  /pbfe stop              stop a paste, undo or cut in progress", function(self)
	if self.jump then
		self.jump = nil
		Print("the trip is cancelled (if the jump has already begun, you will still arrive)")
		if not self.run then
			return
		end
	end

	if self.CancelQueue and self:CancelQueue() then
		if not self.run then
			return
		end
	end

	local run = self.run
	if not run then
		Print("nothing is running")
		return
	end

	-- A placement already sent will happen whatever is said now. Wait for it, so that it is
	-- recorded and "undo" can take it back, and send nothing after it.
	local inFlight = (run.kind == "paste" and run.pending and run.pending.kind == "place")
		or ((run.kind == "undo" or run.kind == "cut") and run.pending and run.pending.kind == "remove")
	if inFlight then
		run.stopping = true
		Print("stopping after the furnishing in flight")
		return
	end

	self:Finish(run, "stopped by you")
end)

-- ---------------------------------------------------------------------------------------
-- Undo
--
-- Takes back, one at a time, the furnishings the last paste recorded. They go to the bag the
-- editor retrieves to (the backpack unless changed), so it needs room there.
-- ---------------------------------------------------------------------------------------

-- Is this furnishing (an id as a string) still in the house?
function addon:StillThere(key)
	local info = Call(GetPlacedHousingFurnitureInfo, addon.KeyToId(key))
	return info ~= nil and (info[3] or 0) ~= 0
end

-- Take furnishings out of the house, one at a time, children before parents. Shared by undo (what
-- the last paste placed) and cut (what was just copied). Whether a furnishing is out is read from
-- the house, not from the answer: the answer may never come.
function addon:StartRemoval(kind, keys, clip, reservationId)
	local run = self:NewRun(kind)
	run.clip = clip
	run.reservationId = reservationId
	run.keys = keys
	run.removeIndex = 0
	run.total = #keys
	self.run = run
	if addon.progress then
		addon.progress:RunStarted(run)
	end
	self:RegisterRunEvents()
	Later(run, 100, addon.RemoveNext)
	return run
end

function addon:RemovedOne(run)
	run.token = run.token + 1
	run.pending = nil
	run.removed = run.removed + 1
	run.modeTries = 0

	if run.removed % 10 == 0 then
		Print("took out %d / %d", run.removed, run.total)
	end
	Tick(run)

	Later(run, run.pace, addon.RemoveNext)
end

function addon:RemoveNext(run)
	run.pending = nil

	if run.stopping then
		return self:Finish(run, "stopped by you")
	end

	run.removeIndex = run.removeIndex + 1

	-- "not yet" answers are counted per furnishing. (They were counted over the whole run, so a server that
	-- was busy between requests used up the allowance in ten removals, and the rest failed.)
	if run.retryIndex ~= run.removeIndex then
		run.retryIndex = run.removeIndex
		run.retries = 0
	end

	local key = run.keys[run.removeIndex]
	if not key then
		return self:RemovalDone(run)
	end

	local id = addon.KeyToId(key)
	if not self:StillThere(key) then
		run.skipped = run.skipped + 1
		Tick(run)
		return Later(run, 0, addon.RemoveNext)
	end

	local results, err = Call(HousingEditorRequestRemoveFurniture, id)
	if not results then
		return self:Finish(run, "the remove call was refused: " .. tostring(err))
	end

	local result = results[1]
	if addon.IsSuccess(result) then
		run.pending = { kind = "remove", id = id }
		return Later(run, 150, addon.RemoveVerify, id, 150)
	end

	if run.retrySet[result] and run.retries < MAX_RETRIES then
		run.retries = run.retries + 1
		run.removeIndex = run.removeIndex - 1
		return Later(run, RETRY_MS, addon.RemoveNext)
	end

	if result == HOUSING_REQUEST_RESULT_INCORRECT_MODE then
		run.modeTries = run.modeTries + 1
		local name = MODE_ORDER[run.modeTries]
		if name then
			local change, changeErr = Call(HousingEditorRequestModeChange, _G["HOUSING_EDITOR_MODE_" .. name])
			Print("editor mode -> %s: %s", name, change and addon.ResultName(change[1]) or tostring(changeErr))
			run.removeIndex = run.removeIndex - 1
			return Later(run, MODE_SETTLE_MS, addon.RemoveNext)
		end
	end

	local named = Call(GetPlacedHousingFurnitureInfo, id)
	run.failed[#run.failed + 1] = "remove " .. tostring(named and addon.Clean(named[1]) or key) .. ": " .. addon.ResultText(result)
	if result == HOUSING_REQUEST_RESULT_ITEM_REMOVE_FAILED_INVENTORY_FULL then
		run.bagFull = true
	end

	-- "you already own one of these and it is unique" is about the bag, and asking again does not change it
	if result == HOUSING_REQUEST_RESULT_ITEM_REMOVE_FAILED_ALREADY_OWN_UNIQUE then
		run.stuck = run.stuck or {}
		run.stuck[key] = true
	end
	if run.stopSet[result] or result == HOUSING_REQUEST_RESULT_ITEM_REMOVE_FAILED_INVENTORY_FULL then
		return self:Finish(run, "stopped: " .. addon.ResultText(result))
	end
	Later(run, run.pace, addon.RemoveNext)
end

-- Every furnishing has been asked for once. Those still in the house are asked for again, a few rounds,
-- after a pause: a server that said "not now" to some of a big group is rarely saying it to all of them
-- for good.
function addon:RemovalDone(run)
	local left = {}
	for _, key in ipairs(run.keys) do
		if self:StillThere(key) and not (run.stuck and run.stuck[key]) then
			left[#left + 1] = key
		end
	end

	if #left > 0 and MoreRounds(run, "remove", run.removed) then
		Print("%d are still there; asking again (round %d)", #left, run.removeRounds)
		run.keys = left
		run.removeIndex = 0
		run.retryIndex = nil
		run.failed = {}
		Tick(run)
		return Later(run, REPAIR_WAIT_MS, addon.RemoveNext)
	end

	return self:Finish(run, nil)
end

-- the furnishing is out when the house no longer has it, whether or not anyone said so
function addon:RemoveVerify(run, id, waited)
	local pending = run.pending
	if not pending or pending.kind ~= "remove" then
		return
	end

	local info = Call(GetPlacedHousingFurnitureInfo, id)
	if not info or (info[3] or 0) == 0 then
		return self:RemovedOne(run)
	end

	if waited >= run.timeout then
		run.token = run.token + 1
		run.pending = nil
		run.failed[#run.failed + 1] = "remove: still there after " .. run.timeout .. " ms"
		return Later(run, run.pace, addon.RemoveNext)
	end

	Later(run, 150, addon.RemoveVerify, id, waited + 150)
end

-- ---- undo ------------------------------------------------------------------------------

function addon:FinishUndo(run, seconds)
	-- keep the record of whatever is still standing, so that undo can be asked again
	local last = self.sv.lastPaste
	local left = 0
	if last then
		local keep = {}
		for _, key in ipairs(last.keys) do
			if self:StillThere(key) then
				keep[#keep + 1] = key
			end
		end
		left = #keep
		if left == 0 then
			self.sv.lastPaste = nil
		else
			last.keys = keep
		end
	end

	Print("undo: took back %d / %d, %d were already gone, %d failed (%.0f s)",
		run.removed, run.total or 0, run.skipped, #run.failed, seconds)
	for i = 1, math.min(#run.failed, 6) do
		Line("  %s", run.failed[i])
	end
	if left > 0 then
		Print("%d are still there; /pbfe undo tries again", left)
	end
end

addon:AddCommand("undo", "  /pbfe undo              take back what the last paste placed", function(self)
	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return
	end

	local last = self.sv.lastPaste
	if not last or #last.keys == 0 then
		Print("nothing recorded to undo")
		return
	end

	local access = self:HouseAccess()
	if not access or access.houseId ~= last.houseId then
		Print("that paste was in house %s; go there first", tostring(last.houseId))
		return
	end

	-- children first: the last placed is the leaf end of the group
	local keys = {}
	for i = #last.keys, 1, -1 do
		keys[#keys + 1] = last.keys[i]
	end

	Print("taking back %d furnishings", #keys)
	self:StartRemoval("undo", keys)
end)

-- ---- cut: copy, then take the furnishings out of this house ----------------------------------
--
-- A furnishing exists once, so a move cannot place first and remove after: the item has to come
-- out of the house into a bag before it can go into the next. That makes a cut the dangerous half
-- of a move, and it is built to be undone from either end:
--   * the clipboard holds the whole group before anything is removed, and is not replaced while
--     the cut is pending (copy, cut, load and clear all ask for 'force' first);
--   * "paste same go" in this house puts everything back where it was, and a partly done cut
--     only puts back what is missing (see "still in place" in BuildPlan);
--   * "cut resume go" finishes a cut that stopped part way;
--   * the bag the furnishings come out into is checked for room first.

local function BagLabel(bag)
	if bag == BAG_BACKPACK then
		return "backpack"
	end
	return "bag " .. tostring(bag)
end

-- How many slots will the furnishings of these nodes take in the bag the editor retrieves to?
--
-- A retrieved furnishing joins a stack of its own kind if one has room, and takes a new slot if not;
-- a slot holds at most `max` of a kind. So for each kind that comes out, n of them:
--
--     room in the stacks already there   = the sum of (max - count) over this kind's slots in the bag
--     new slots                          = ceil((n - room) / max)
--
-- `max` is read from a slot of that kind (in the retrieve bag first, then any other bag, then what the
-- bags have taught the saved table before: sv.stackMax). The one thing that cannot be known is the
-- `max` of a kind that is nowhere in any bag and has never been seen. For those the answer is a range:
-- low (they stack as most furnishings do, ASSUMED_STACK) to high (each piece takes its own slot).
--
--   returns { bag, free, low, high, unknown }
--     free     free slots in the bag (nil if the client would not say)
--     low      slots needed if the unknown kinds stack as usual
--     high     slots needed if they do not stack at all
--     unknown  how many kinds had no known maximum
-- Collectible furnishings go to no bag and are not counted. A stolen stack does not take a retrieved
-- furnishing (they do not stack together) and is not in the index either.
local ASSUMED_STACK = 200

function addon:RetrieveSpace(nodes)
	local bag = Try1(HousingEditorGetRetrieveToBag) or BAG_BACKPACK
	local free = Try1(GetNumBagFreeSlots, bag)
	local index = self:IndexInventory()

	-- per kind: how many, and what the item link said about stacking when it was copied (nil: not known)
	local count, order, traits = {}, {}, {}
	for _, node in ipairs(nodes) do
		if (node.collectibleId or 0) == 0 then
			if not count[node.dataId] then
				count[node.dataId] = 0
				order[#order + 1] = node.dataId
				traits[node.dataId] = { never = true, some = false }
			end
			count[node.dataId] = count[node.dataId] + 1
			if node.stackable ~= false then
				traits[node.dataId].never = false
			end
			if node.stackable == true then
				traits[node.dataId].some = true
			end
		end
	end

	local low, high, unknown = 0, 0, 0
	for _, dataId in ipairs(order) do
		local n = count[dataId]
		local max, room = nil, 0

		local entry = index.byData[dataId]
		if entry then
			for _, ref in ipairs(entry.slots) do
				if ref.max and ref.max > 0 then
					if ref.bag == bag then
						room = room + math.max(ref.max - ref.count, 0)
						max = ref.max
					elseif not max then
						max = ref.max
					end
				end
			end
		end
		max = max or self.sv.stackMax[dataId]

		-- An item that does not stack takes a slot a piece; the game says so (IsItemLinkStackable), so it is not
		-- a guess even for a kind that is in no bag.
		if not max and traits[dataId].never then
			max = 1
			self.sv.stackMax[dataId] = 1
		end

		if max and max > 0 then
			local need = math.ceil(math.max(n - room, 0) / max)
			low, high = low + need, high + need
		else
			-- stacks, by how many is not known: at least two to a slot if the link said it stacks
			unknown = unknown + 1
			low = low + math.ceil(n / ASSUMED_STACK)
			high = high + (traits[dataId].some and math.ceil(n / 2) or n)
		end
	end

	return { bag = bag, free = free, low = low, high = high, unknown = unknown }
end

local function RemovalKeys(nodes, onlyStanding, self)
	local keys = {}
	for i = #nodes, 1, -1 do
		local key = nodes[i].srcKey
		if key and (not onlyStanding or self:StillThere(key)) then
			keys[#keys + 1] = key
		end
	end
	return keys
end

local function StandingNodes(self, clip)
	local list = {}
	for _, node in ipairs(clip.nodes) do
		if node.srcKey and self:StillThere(node.srcKey) then
			list[#list + 1] = node
		end
	end
	return list
end

-- Where a pending cut stands: how many of its furnishings are still in the house they came from (nil when
-- this is another house), and whether this is that house.
function addon:CutStatus(clip)
	local access = self:HouseAccess()
	local here = access ~= nil and access.houseId == clip.houseId
	return here and #StandingNodes(self, clip) or nil, here
end

-- What to do next, from where the cut stands. Said whenever something is refused because a cut is waiting.
function addon:PrintCutAdvice(clip)
	local standing, here = self:CutStatus(clip)
	if here and standing and standing > 0 then
		Print("%d of its %d furnishings are still standing in this house: press Cut (square) on one of them, or", standing, #clip.nodes)
		Print("/pbfe cut resume go, to finish taking them out. (/pbfe paste same go puts back what is out)")
	elseif here then
		Print("all %d are out of this house, in your bag: pick Move on the quickslot wheel in a house of yours,", #clip.nodes)
		Print("or /pbfe paste same go to put it back where it was")
	else
		Print("a cut of %d furnishings from house %s is waiting: pick Move on the quickslot wheel in a house of yours,", #clip.nodes, tostring(clip.houseId))
		Print("or go back to house %s and /pbfe paste same go to put it back", tostring(clip.houseId))
	end
	Print("/pbfe clear force forgets it (what is already out stays in your bag)")
end

-- Finish a cut that stopped part way: take out what is still standing. `go` false only shows it.
function addon:ResumeCut(go, force, again)
	local clip = self.sv.clip
	if not (clip and clip.cut) then
		Print("no cut is pending")
		return false
	end

	local access = self:HouseAccess()
	if not access or access.houseId ~= clip.houseId then
		Print("that cut was from house %s; go there first", tostring(clip.houseId))
		return false
	end
	if not access.owner then
		Print("you can only cut from a house you own")
		return false
	end

	local keys = RemovalKeys(clip.nodes, true, self)
	if #keys == 0 then
		Print("everything in the cut is already out of this house")
		return false
	end
	self:RunCut(clip, keys, StandingNodes(self, clip), go, force, again or "/pbfe cut resume")
	return true
end

-- Is this furnishing (an id) one of the pending cut's?
function addon:InPendingCut(clip, id)
	local key = id ~= nil and IdKey(id)
	if not key then
		return false
	end
	for _, node in ipairs(clip.nodes) do
		if node.srcKey == key then
			return true
		end
	end
	return false
end

-- How many of a clip's furnishings fall under each of the house's four limits, as the game itself says
-- (GetFurnitureDataInfo). Returns a text such as "3 traditional, 1 special, 2 collectible".
function addon:ClipKinds(nodes)
	local counts, unknown = {}, 0
	for _, node in ipairs(nodes) do
		local info = Call(GetFurnitureDataInfo, node.dataId)
		local limitType = info and info[4]
		if limitType == nil then
			unknown = unknown + 1
		else
			counts[limitType] = (counts[limitType] or 0) + 1
		end
	end

	local parts = {}
	for _, row in ipairs(LIMIT_WORDS) do
		local limitType = _G["HOUSING_FURNISHING_LIMIT_TYPE_" .. row[1]]
		if limitType ~= nil and counts[limitType] then
			parts[#parts + 1] = string.format("%d %s", counts[limitType], row[2])
			counts[limitType] = nil
		end
	end
	for limitType, count in pairs(counts) do
		parts[#parts + 1] = string.format("%d of limit type %s", count, tostring(limitType))
	end
	if unknown > 0 then
		parts[#parts + 1] = string.format("%d of unknown type", unknown)
	end
	return table.concat(parts, ", ")
end

-- Say what a cut would do, and do it when told to.
-- commit, when given, is what keeps the clip (a reservation does; the plain command puts it on the
-- clipboard) and returns the reservation's number, if any.
function addon:RunCut(clip, keys, nodes, go, force, again, commit, confirm)
	local items, collectibles = self:ClipSummary({ nodes = nodes })
	local room = self:RetrieveSpace(nodes)
	local free = room.free

	Print("cut: %d furnishings (%d items, %d collectibles) leave this house", #keys, items, collectibles)
	Line("  kinds: %s", self:ClipKinds(nodes))
	if collectibles > 0 then
		Line("  collectibles go back to your collection, not to a bag")
	end

	local freeText = free ~= nil and tostring(free) or "?"
	if room.low == room.high then
		Print("they go to your %s: %s free slots, %d needed", BagLabel(room.bag), freeText, room.low)
	else
		-- some kinds are new to this add-on: how they stack is not known, so the need is a range
		Print("they go to your %s: %s free slots, %d needed (up to %d if the %d kinds not yet seen do not stack)",
			BagLabel(room.bag), freeText, room.low, room.high, room.unknown)
	end

	-- Refused only when it is CERTAIN not to fit: fewer free slots than the least it can need. A
	-- range with the free slots inside it goes ahead, warned: if the bag does fill, the cut stops
	-- there with nothing lost, and it is finished or put back by command.
	local enough = free == nil or free >= room.low
	if not enough then
		Print("not enough room in the %s: %d free, at least %d needed%s", BagLabel(room.bag), free, room.low,
			force and " (going on: 'force')" or "")
	elseif free ~= nil and free < room.high then
		Print("it may fill up. if it does the cut stops (nothing is lost): /pbfe cut resume go finishes it")
	end

	if not go then
		Print("nothing has been removed. to do it: %s", again .. " " .. (confirm or "go"))
		return
	end

	if not enough and not force then
		Print("refusing. make room, or add 'force' to start anyway")
		addon.Alert("Cut refused: your %s has %d free slots, %d are needed", BagLabel(room.bag), free, room.low)
		return
	end

	clip.cut = true
	local reservationId
	if commit then
		reservationId = commit(clip)
	else
		self.sv.clip = clip
		self.sv.clipFresh = true
	end
	self:StartRemoval("cut", keys, clip, reservationId)
end

function addon:FinishCut(run, seconds)
	local clip = run.clip or self.sv.clip
	local standing = clip and #StandingNodes(self, clip) or 0
	local bag = Try1(HousingEditorGetRetrieveToBag) or BAG_BACKPACK

	Print("cut: took out %d / %d, %d were already out, %d failed (%.0f s)",
		run.removed, run.total or 0, run.skipped, #run.failed, seconds)
	for i = 1, math.min(#run.failed, 6) do
		Line("  %s", run.failed[i])
	end

	if run.reservationId then
		if standing == 0 then
			Print("all of it is in your %s. reservation #%d will paste it when you enter the other house", BagLabel(bag), run.reservationId)

			-- a move for the house we are standing in is waiting right now: the wheel has it
			local resv = self:FindReservation(run.reservationId)
			if resv and resv.houseId == (Try1(GetCurrentZoneHouseId) or 0) and self.AnnounceMenu then
				self:AnnounceMenu()
			end
		else
			Print("%d are still here. /pbfe reservations load %d, then /pbfe cut resume go finishes the cut", standing, run.reservationId)
		end
	elseif standing == 0 then
		Print("all of it is in your %s. go to a house of yours: the quickslot wheel offers Move (or /pbfe paste)", BagLabel(bag))
		Print("to put it back instead: /pbfe paste same go (in this house)")
		addon.Alert("Cut done: %d furnishings are in your %s. Pick Move in a house of yours", run.removed + run.skipped, BagLabel(bag))
		if self.AnnounceMenu then
			self:AnnounceMenu()
		end
	else
		addon.Alert("Cut stopped: %d of %d are still in this house%s", standing, #(clip and clip.nodes or {}), run.bagFull and " (your bag is full)" or "")
		if run.bagFull then
			Print("your %s is full. Make room, then press Cut (square) on one of the furnishings still here,", BagLabel(bag))
			Print("or /pbfe cut resume go: %d are still standing in this house", standing)
		else
			Print("%d are still here. /pbfe cut resume go finishes the cut;", standing)
		end
		Print("/pbfe paste same go puts back only what has been taken out")
	end
end

addon:AddCommand("cut", "  /pbfe cut <n>|near|sel|all|resume [go]   copy, then take it out of this house (a move)", function(self, words)
	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return
	end

	local go = addon.TakeFlag(words, "go")
	local force = addon.TakeFlag(words, "force")

	-- finish a cut that stopped part way
	if words[1] == "resume" then
		self:ResumeCut(go, force)
		return
	end

	if self:PendingCutBlocks(force) then
		return
	end

	local access, _, pose, chosen = self:SelectGroups(words, "cut")
	if not access then
		return
	end
	if not access.owner then
		Print("you can only cut from a house you own")
		return
	end

	local clip = self:MakeClip(chosen, access, pose)
	local again = "/pbfe cut " .. table.concat(words, " ")
	self:RunCut(clip, RemovalKeys(clip.nodes, false, self), clip.nodes, go, force, again)
end)
