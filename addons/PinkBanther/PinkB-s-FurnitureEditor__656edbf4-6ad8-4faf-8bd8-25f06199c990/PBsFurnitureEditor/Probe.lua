-- PB's FurnitureEditor -- probes
--
-- Everything a copy depends on and nothing in the client's own Lua proves. One command each, in
-- the order they are worth running on a console:
--
--   api       which functions exist in this build, and which of them are private
--   state     what the client says about here and now
--   where     whether the player's position and the furnishings' positions are one coordinate space
--   calib     the client's rotation order, worked out from furnishings that are already placed
--   items     placeable items in the backpack, with the slot numbers the next two want
--   probe place <slot> [keep]   place ONE item at your feet, read it back, take it away again
--   probe link  <slot>          the same twice, then link, move the parent, unlink, take both away
--
-- The last two change the house, and say so. Each step prints the client's own answer, so that
-- a refusal reads as the client's words and not as a guess. Both clean up after themselves, and
-- /pbfe stop cancels them where they stand.

local addon = PBS_FURNITURE_EDITOR
local geo = addon.geo

local Call, Try1, Bool = addon.Call, addon.Try1, addon.Bool
local IdKey, IsNoId, SameId = addon.IdKey, addon.IsNoId, addon.SameId
local Print, Line = addon.Print, addon.Line
local Later = addon.RunLater

-- ---------------------------------------------------------------------------------------
-- api
-- ---------------------------------------------------------------------------------------

local API_GROUPS = {
	{
		label = "read",
		names = {
			"GetNextPlacedHousingFurnitureId", "GetPlacedHousingFurnitureInfo",
			"HousingEditorGetFurnitureWorldPosition", "HousingEditorGetFurnitureOrientation",
			"HousingEditorGetFurnitureLocalBounds", "HousingEditorGetFurnitureWorldBounds",
			"GetPlacedFurnitureParent", "GetPlacedFurnitureChildren", "GetCollectibleIdFromFurnitureId",
			"GetPlacedHousingFurnitureCurrentObjectStateIndex", "GetPlacedHousingFurnitureNumObjectStates",
			"HousingEditorGetNumPathNodesForFurniture", "GetPlayerWorldPositionInHouse",
			"HousingEditorGetSelectedFurnitureId", "HousingEditorGetTargetInfo",
			"GetHousingEditorMode", "IsOwnerOfCurrentHouse", "HasAnyEditingPermissionsForCurrentHouse",
		},
	},
	{
		label = "write",
		names = {
			"HousingEditorRequestItemPlacement", "HousingEditorRequestCollectiblePlacement",
			"HousingEditorRequestChangePositionAndOrientation", "HousingEditorRequestChangePosition",
			"HousingEditorRequestSetFurnitureParent", "HousingEditorRequestClearFurnitureParent",
			"HousingEditorRequestRemoveFurniture", "HousingEditorRequestChangeState",
			"HousingEditorRequestModeChange",
		},
	},
	{
		label = "bags",
		names = {
			"GetBagSize", "HasItemInSlot", "IsItemPlaceableFurniture", "GetItemFurnitureDataId",
			"GetSlotStackSize", "IsItemStolen", "GetItemName", "HousingEditorCanPlaceCollectible",
		},
	},
	{
		label = "limits",
		names = {
			"GetFurnitureDataInfo", "GetHouseFurnishingPlacementLimit", "GetNumHouseFurnishingsPlaced",
			"GetCurrentZoneHouseId", "GetCurrentHouseOwner", "IsPrivateFunction",
		},
	},
	{
		label = "ids",
		names = { "Id64ToString", "StringToId64", "AreId64sEqual", "IsId64EqualToNumber" },
	},
}

local EVENT_NAMES = {
	"EVENT_HOUSING_FURNITURE_PLACED", "EVENT_HOUSING_FURNITURE_REMOVED",
	"EVENT_HOUSING_EDITOR_REQUEST_RESULT", "EVENT_HOUSING_EDITOR_COMMAND_RESULT",
	"EVENT_HOUSING_EDITOR_MODE_CHANGED", "EVENT_HOUSING_FURNITURE_MOVED",
}

addon:AddCommand("api", "  /pbfe api               which client functions exist, and which are private", function(self)
	local trouble = 0
	for _, group in ipairs(API_GROUPS) do
		local missing, private = {}, {}
		for _, name in ipairs(group.names) do
			if type(_G[name]) ~= "function" then
				missing[#missing + 1] = name
			elseif Try1(IsPrivateFunction, name) then
				private[#private + 1] = name
			end
		end

		Print("%s: %d / %d usable", group.label, #group.names - #missing - #private, #group.names)
		if #missing > 0 then
			Line("  missing: %s", table.concat(missing, " "))
		end
		if #private > 0 then
			Line("  private: %s", table.concat(private, " "))
		end
		trouble = trouble + #missing + #private
	end

	local noEvent = {}
	for _, name in ipairs(EVENT_NAMES) do
		if _G[name] == nil then
			noEvent[#noEvent + 1] = name
		end
	end
	if #noEvent > 0 then
		Line("  events missing: %s", table.concat(noEvent, " "))
		trouble = trouble + #noEvent
	end

	Print(trouble == 0 and "everything this add-on calls exists and is public" or "%d problems above", trouble)
end)

-- ---------------------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------------------

local LIMIT_NAMES = {
	"HIGH_IMPACT_ITEM", "HIGH_IMPACT_COLLECTIBLE", "LOW_IMPACT_ITEM", "LOW_IMPACT_COLLECTIBLE",
}

addon:AddCommand("state", "  /pbfe state             what the client says about here and now", function(self)
	local access, why = self:HouseAccess()
	if not access then
		Print("%s", why)
		return
	end

	local mode = Try1(GetHousingEditorMode)
	local role = Try1(GetHousingVisitorRole)
	Print("house %d, owner %s: you own=%s edit=%s", access.houseId, tostring(access.ownerName),
		Bool(access.owner), Bool(access.editor))
	Print("editor mode %s (%s), visitor role %s",
		tostring(mode), mode ~= nil and addon.ModeName(mode) or "?", tostring(role))

	for _, suffix in ipairs(LIMIT_NAMES) do
		local limitType = _G["HOUSING_FURNISHING_LIMIT_TYPE_" .. suffix]
		if limitType ~= nil then
			Line("  %s: %s of %s", suffix,
				tostring(Try1(GetNumHouseFurnishingsPlaced, limitType)),
				tostring(Try1(GetHouseFurnishingPlacementLimit, access.houseId, limitType)))
		end
	end

	local house = self:ReadHouse()
	local groups = self:BuildGroups(house, self:PlayerPose())
	Print("%d furnishings read, %d linked, %d groups", #house.list, house.linked, #groups)

	local pose = self:PlayerPose()
	if pose then
		Print("you at x %d y %d z %d, rot %.3f", pose.x, pose.y, pose.z, pose.rot)
	end

	local conv = self.sv.convention
	if conv then
		Print("rotation: sy=%s yawOuter=%s (%s)", tostring(conv.sy), tostring(conv.yawOuter), tostring(conv.bestName))
	else
		Print("rotation: not calibrated (/pbfe calib)")
	end

	local clip = self.sv.clip
	Print("clipboard: %s%s", clip and (#clip.nodes .. " furnishings") or "empty",
		(clip and clip.cut) and " -- a CUT, not yet pasted" or "")
	local waiting = 0
	for _, resv in ipairs(self.sv.reservations) do
		if resv.status == "waiting" then
			waiting = waiting + 1
		end
	end
	Print("reservations: %d waiting, %d in all", waiting, #self.sv.reservations)
	Print("quickslot wheel menu: %s%s", self.sv.menu == false and "off" or "on",
		self.wheelBroken and " (stopped itself)" or "")
	Print("editor buttons: %s%s", self.sv.editorKeys == false and "off" or "on",
		self.editorBroken and " (stopped)" or "")
	Print("pace %d ms, timeout %d ms", self.sv.paceMs, self.sv.timeoutMs)
end)

addon:AddCommand("speed", "  /pbfe speed <ms>        wait this long between requests (default 450)", function(self, words)
	local ms = tonumber(words[1])
	if not ms or ms < 100 or ms > 5000 then
		Print("pace is %d ms; say /pbfe speed 300 (100 to 5000)", self.sv.paceMs)
		return
	end
	self.sv.paceMs = math.floor(ms)
	Print("pace is now %d ms", self.sv.paceMs)
end)

-- ---------------------------------------------------------------------------------------
-- where
--
-- The client's own housing code sorts furnishings by distance from GetPlayerWorldPositionInHouse,
-- which says that call and the furnishings share a space. This is the check, on the numbers.
-- ---------------------------------------------------------------------------------------

local function Distance3(ax, ay, az, bx, by, bz)
	local dx, dy, dz = ax - bx, ay - by, az - bz
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

addon:AddCommand("where", "  /pbfe where             your position, and the nearest furnishings", function(self)
	local pose = self:PlayerPose()
	if not pose then
		Print("GetPlayerWorldPositionInHouse gave nothing; are you in a house?")
		return
	end

	Print("in house: x %d y %d z %d rot %.3f", pose.x, pose.y, pose.z, pose.rot)

	local unit = Call(GetUnitWorldPosition, "player")
	if unit then
		Print("unit world: zone %s x %s y %s z %s", tostring(unit[1]), tostring(unit[2]), tostring(unit[3]), tostring(unit[4]))
	end
	local raw = Call(GetUnitRawWorldPosition, "player")
	if raw then
		Print("unit raw:   zone %s x %s y %s z %s", tostring(raw[1]), tostring(raw[2]), tostring(raw[3]), tostring(raw[4]))
	end
	Print("camera heading %.3f", Try1(GetPlayerCameraHeading) or 0)

	local house = self:ReadHouse()
	local nearest = {}
	for _, entry in ipairs(house.list) do
		if entry.x then
			nearest[#nearest + 1] = { entry = entry, d = Distance3(pose.x, pose.y, pose.z, entry.x, entry.y, entry.z) }
		end
	end
	table.sort(nearest, function(a, b) return a.d < b.d end)
	for i = 1, math.min(#nearest, 3) do
		local entry = nearest[i].entry
		Line("  nearest %d: %.2f m  %s  at x %d y %d z %d", i, nearest[i].d / 100, entry.name, entry.x, entry.y, entry.z)
	end
	Print("stand beside a piece you know; if it is not in the list, the spaces differ")
end)

-- ---------------------------------------------------------------------------------------
-- calib
-- ---------------------------------------------------------------------------------------

local MAX_SAMPLES = 150

local function ReadSample(entry)
	local localBounds = Call(HousingEditorGetFurnitureLocalBounds, entry.id)
	local worldBounds = Call(HousingEditorGetFurnitureWorldBounds, entry.id)
	if not (localBounds and worldBounds and entry.x and entry.pitch) then
		return nil
	end
	if #localBounds < 6 or #worldBounds < 6 then
		return nil
	end

	return {
		name = entry.name,
		pitch = entry.pitch, yaw = entry.yaw, roll = entry.roll,
		x = entry.x, y = entry.y, z = entry.z,
		lmin = { localBounds[1], localBounds[2], localBounds[3] },
		lmax = { localBounds[4], localBounds[5], localBounds[6] },
		wmin = { worldBounds[1], worldBounds[2], worldBounds[3] },
		wmax = { worldBounds[4], worldBounds[5], worldBounds[6] },
	}
end

local function Median(values)
	if #values == 0 then
		return nil
	end
	table.sort(values)
	return values[math.ceil(#values / 2)]
end

-- every k-th element, so that a big house is sampled across, not from one corner
local function Thin(list, limit)
	if #list <= limit then
		return list
	end
	local out = {}
	local step = #list / limit
	for i = 0, limit - 1 do
		out[#out + 1] = list[math.floor(i * step) + 1]
	end
	return out
end

local function PrintRanking(label, ranked)
	for i = 1, math.min(#ranked, 3) do
		Line("  %s %d. %s  err %.1f cm", label, i, ranked[i].conv.name, ranked[i].err)
	end
end

-- Pure: what a set of samples says. Returns the decision, or nil and why.
function addon:Calibrate(samples)
	local flat, tilted, rest = {}, {}, {}
	for _, sample in ipairs(samples) do
		if geo.IsFlat(sample.pitch, sample.roll) and math.abs(sample.yaw) < 0.001 then
			rest[#rest + 1] = geo.RestError(sample)
		end
		if geo.IsInformative(sample) then
			if geo.IsFlat(sample.pitch, sample.roll) then
				flat[#flat + 1] = sample
			else
				tilted[#tilted + 1] = sample
			end
		end
	end

	local result = { flat = #flat, tilted = #tilted, rest = Median(rest) }

	if #flat >= 3 then
		result.flatRanked = geo.FitConventions(Thin(flat, MAX_SAMPLES))
		result.flatDecision = geo.Decide(result.flatRanked)
	end
	if #tilted >= 3 then
		result.tiltRanked = geo.FitConventions(Thin(tilted, MAX_SAMPLES))
		result.tiltDecision = geo.Decide(result.tiltRanked)
	end

	return result
end

local MIN_MARGIN = 1.5
local MAX_ERR_CM = 15

local function Decisive(decision)
	return decision and decision.best.err <= MAX_ERR_CM and decision.margin >= MIN_MARGIN
end

addon:AddCommand("calib", "  /pbfe calib             work out the client's rotation order (read-only)", function(self)
	local access, why = self:HouseAccess()
	if not access then
		Print("%s", why)
		return
	end

	local house = self:ReadHouse()
	local samples = {}
	for _, entry in ipairs(house.list) do
		local sample = ReadSample(entry)
		if sample then
			samples[#samples + 1] = sample
		end
	end

	local result = self:Calibrate(samples)
	Print("calib: %d furnishings read, %d turned flat, %d tilted", #samples, result.flat, result.tilted)
	if result.rest then
		Print("with no rotation the world box misses by %.1f cm (should be about 0)", result.rest)
	end

	if result.flatRanked then
		PrintRanking("flat", result.flatRanked)
	end
	if result.tiltRanked then
		PrintRanking("tilted", result.tiltRanked)
	end

	local flat, tilt = result.flatDecision, result.tiltDecision
	if not Decisive(flat) then
		Print("not enough to decide the yaw sign: stand in a house with turned, off-centre pieces (shelves, cabinets)")
		Print("/pbfe dump 5 prints raw numbers for offline study")
		return
	end

	if flat.sy == nil then
		Print("the best fits disagree on the yaw sign; nothing saved")
		return
	end

	local conv = {
		sy = flat.sy,
		yawOuter = nil,
		bestName = flat.best.conv.name,
		flat = result.flat,
		tilted = result.tilted,
		at = Try1(GetTimeStamp) or 0,
	}

	if Decisive(tilt) then
		if tilt.sy ~= nil and tilt.sy ~= flat.sy then
			Print("flat and tilted pieces disagree on the yaw sign; nothing saved")
			return
		end
		conv.yawOuter = tilt.yawOuter
		conv.bestName = tilt.best.conv.name
	end

	self.sv.convention = conv
	Print("yaw sign %+d. yaw applied last: %s", conv.sy,
		conv.yawOuter == nil and "unknown (tilted pieces cannot be turned yet)" or (conv.yawOuter and "yes" or "no"))
	Print("saved. /pbfe paste rot 90 can turn %s", conv.yawOuter and "everything" or "flat pieces")
end)

addon:AddCommand("dump", nil, function(self, words)
	local count = tonumber(words[1]) or 3
	local house = self:ReadHouse()
	local shown = 0
	for _, entry in ipairs(house.list) do
		local sample = ReadSample(entry)
		if sample and (not geo.IsFlat(sample.pitch, sample.roll) or math.abs(sample.yaw) > 0.05) then
			Line("%s  pos %d %d %d  ori %.4f %.4f %.4f", sample.name, sample.x, sample.y, sample.z, sample.pitch, sample.yaw, sample.roll)
			Line("  local %.3f %.3f %.3f  %.3f %.3f %.3f", sample.lmin[1], sample.lmin[2], sample.lmin[3], sample.lmax[1], sample.lmax[2], sample.lmax[3])
			Line("  world %d %d %d  %d %d %d", sample.wmin[1], sample.wmin[2], sample.wmin[3], sample.wmax[1], sample.wmax[2], sample.wmax[3])
			shown = shown + 1
			if shown >= count then
				break
			end
		end
	end
	if shown == 0 then
		Print("no turned furnishing to show")
	end
end)

-- ---------------------------------------------------------------------------------------
-- kind
--
-- Is a placed furnishing an item or a collectible? The client says it two ways that need not agree,
-- and a first real paste on the console went wrong on exactly that. This prints both, and what the
-- add-on decided, for the nearest few pieces.
-- ---------------------------------------------------------------------------------------

addon:AddCommand("kind", "  /pbfe kind [n]          item or collectible? what the client says about the nearest n pieces", function(self, words)
	local access, why = self:HouseAccess()
	if not access then
		Print("%s", why)
		return
	end

	local count = tonumber(words[1]) or 3
	local pose = self:PlayerPose()
	local house = self:ReadHouse()

	local list = {}
	for _, entry in ipairs(house.list) do
		if entry.x then
			list[#list + 1] = {
				entry = entry,
				d = pose and Distance3(pose.x, pose.y, pose.z, entry.x, entry.y, entry.z) or 0,
			}
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)

	local function yesno(text)
		if type(text) ~= "string" then
			return "n/a"
		end
		return text ~= "" and "yes" or "no"
	end

	local index = self:IndexInventory()

	for i = 1, math.min(#list, count) do
		local entry = list[i].entry
		local links = Call(GetPlacedFurnitureLink, entry.id, LINK_STYLE_BRACKETS or 1)
		Line("%s  data %s", entry.name, tostring(entry.dataId))
		Line("  item link: %s   collectible link: %s", yesno(links and links[1]), yesno(links and links[2]))
		Line("  GetCollectibleIdFromFurnitureId -> %s", tostring(Try1(GetCollectibleIdFromFurnitureId, entry.id)))
		if (entry.collectibleId or 0) ~= 0 then
			Line("  => collectible %d (from the %s)", entry.collectibleId, tostring(entry.kindFrom))
		else
			Line("  => item (from the %s)", tostring(entry.kindFrom))
		end

		-- which of the house's four limits it counts against, and whether a paste could place another
		local info = Call(GetFurnitureDataInfo, entry.dataId)
		Line("  counts against the %s limit", info and info[4] ~= nil and addon.LimitName(info[4]) or "(unknown)")
		if (entry.collectibleId or 0) ~= 0 then
			Line("  can be placed from your collection: %s", tostring(Try1(HousingEditorCanPlaceCollectible, entry.collectibleId)))
		else
			local have = index.byData[entry.dataId]
			Line("  copies in your bags: %d", have and have.total or 0)
		end
	end
end)

-- ---------------------------------------------------------------------------------------
-- items
-- ---------------------------------------------------------------------------------------

addon:AddCommand("items", "  /pbfe items [n]         placeable items in your backpack (the slot numbers probes want)", function(self, words)
	local limit = tonumber(words[1]) or 12
	local bag = BAG_BACKPACK
	local size = Try1(GetBagSize, bag) or 0
	local list = {}

	for slot = 0, size - 1 do
		if Try1(HasItemInSlot, bag, slot) and Try1(IsItemPlaceableFurniture, bag, slot) and not Try1(IsItemStolen, bag, slot) then
			list[#list + 1] = {
				slot = slot,
				count = Try1(GetSlotStackSize, bag, slot) or 1,
				name = addon.Clean(Try1(GetItemName, bag, slot)),
			}
		end
	end

	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.slot < b.slot
	end)

	Print("%d placeable items in the backpack (bag %s); biggest stacks first", #list, tostring(bag))
	for i = 1, math.min(#list, limit) do
		Line("  slot %d  x%d  %s", list[i].slot, list[i].count, list[i].name)
	end
	if #list > limit then
		Line("  ... /pbfe items %d for more", limit + 12)
	end
	Print("/pbfe probe place <slot>   to try one")
end)

-- ---------------------------------------------------------------------------------------
-- probe: one furnishing, placed and taken away
-- ---------------------------------------------------------------------------------------

local function StartProbe(self)
	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return nil
	end

	local access, why = self:HouseAccess()
	if not access then
		Print("%s", why)
		return nil
	end
	if not access.owner then
		Print("placing needs a house you own")
		return nil
	end

	local run = self:NewRun("probe")
	self.run = run
	self:RegisterRunEvents()

	-- everything already here, so a new arrival can be told from the old
	local id = Try1(GetNextPlacedHousingFurnitureId, nil)
	local guard = 0
	while id ~= nil and not IsNoId(id) and guard < 20000 do
		guard = guard + 1
		run.known[IdKey(id)] = true
		id = Try1(GetNextPlacedHousingFurnitureId, id)
	end

	return run
end

local function EndProbe(self, run, verdict)
	local counts = {}
	for name, count in pairs(run.eventCounts) do
		counts[#counts + 1] = name .. " x" .. count
	end
	table.sort(counts)

	if self.run == run then
		self.run = nil
		self:UnregisterRunEvents()
		run.token = run.token + 1
	end

	Print("%s", verdict)
	if #counts > 0 then
		Line("  events: %s", table.concat(counts, ", "))
	end
end

local MODE_ORDER = { "SELECTION", "BROWSE" }

-- Place one furnishing and say what happened. cb(id, why, ms); id is nil on failure.
local function PlaceOne(self, run, bag, slot, dataId, x, y, z, cb)
	local sentAt = addon.Now()
	local modeTries = 0
	local arrived, arrivedAt

	run.onPlaced = function(furnitureId)
		local info = Call(GetPlacedHousingFurnitureInfo, furnitureId)
		if not arrived and not run.known[IdKey(furnitureId)] and (not info or info[3] == dataId) then
			arrived, arrivedAt = furnitureId, addon.Now()
		end
	end

	local function done(id, why)
		run.onPlaced = nil
		if id then
			run.known[IdKey(id)] = true
		end
		cb(id, why, addon.Now() - sentAt)
	end

	local function wait(waited)
		if arrived then
			return done(arrived, nil)
		end

		-- the event may not come; the furnishing may be there regardless
		local found = self:FindNewFurniture(run, { dataId = dataId })
		if found then
			Print("  (no placed event yet, but it is there)")
			return done(found, nil)
		end

		if waited >= run.timeout then
			return done(nil, "no furnishing appeared within " .. run.timeout .. " ms")
		end
		Later(run, 150, function() wait(waited + 150) end)
	end

	local function send()
		local results, err = Call(HousingEditorRequestItemPlacement, bag, slot, x, y, z, 0, 0, 0)
		if not results then
			return done(nil, "call refused: " .. tostring(err))
		end

		local result = results[1]
		Print("  RequestItemPlacement -> %s", addon.ResultText(result))

		if addon.IsSuccess(result) then
			return Later(run, 150, function() wait(150) end)
		end

		if result == HOUSING_REQUEST_RESULT_INCORRECT_MODE then
			modeTries = modeTries + 1
			local name = MODE_ORDER[modeTries]
			if not name then
				return done(nil, "refused in every mode tried")
			end
			local change, changeErr = Call(HousingEditorRequestModeChange, _G["HOUSING_EDITOR_MODE_" .. name])
			Print("  mode -> %s: %s", name, change and addon.ResultName(change[1]) or tostring(changeErr))
			return Later(run, 700, send)
		end

		if result == HOUSING_REQUEST_RESULT_REQUEST_IN_PROGRESS and modeTries < 5 then
			modeTries = modeTries + 1
			return Later(run, 700, send)
		end

		done(nil, addon.ResultText(result))
	end

	send()
end

local function RemoveOne(self, run, id, cb)
	local sentAt = addon.Now()
	local gone = false

	run.onRemoved = function(furnitureId)
		if SameId(furnitureId, id) then
			gone = true
		end
	end

	local function done(ok, why)
		run.onRemoved = nil
		cb(ok, why, addon.Now() - sentAt)
	end

	local function wait(waited)
		local info = Call(GetPlacedHousingFurnitureInfo, id)
		if gone or not info or (info[3] or 0) == 0 then
			return done(true)
		end
		if waited >= run.timeout then
			return done(false, "still there after " .. run.timeout .. " ms")
		end
		Later(run, 150, function() wait(waited + 150) end)
	end

	local results, err = Call(HousingEditorRequestRemoveFurniture, id)
	if not results then
		return done(false, "call refused: " .. tostring(err))
	end
	Print("  RequestRemoveFurniture -> %s", addon.ResultText(results[1]))
	if not addon.IsSuccess(results[1]) then
		return done(false, addon.ResultText(results[1]))
	end
	Later(run, 150, function() wait(150) end)
end

local function ParseSlot(words)
	local numbers = {}
	local keep = false
	for _, word in ipairs(words) do
		if word == "keep" then
			keep = true
		elseif tonumber(word) then
			numbers[#numbers + 1] = tonumber(word)
		end
	end

	if #numbers >= 2 then
		return numbers[1], numbers[2], keep
	end
	return BAG_BACKPACK, numbers[1], keep
end

local function CheckSlot(bag, slot)
	if slot == nil then
		Print("which slot? /pbfe items shows them")
		return nil
	end
	if not Try1(HasItemInSlot, bag, slot) then
		Print("nothing in bag %s slot %s", tostring(bag), tostring(slot))
		return nil
	end
	if not Try1(IsItemPlaceableFurniture, bag, slot) then
		Print("that is not a placeable furnishing")
		return nil
	end
	if Try1(IsItemStolen, bag, slot) then
		Print("that item is stolen; launder it first")
		return nil
	end
	return Try1(GetItemFurnitureDataId, bag, slot)
end

function addon:ProbePlace(words)
	local bag, slot, keep = ParseSlot(words)
	local dataId = CheckSlot(bag, slot)
	if not dataId then
		return
	end

	local pose = self:PlayerPose()
	if not pose then
		Print("could not read your position")
		return
	end

	local run = StartProbe(self)
	if not run then
		return
	end

	local mode = Try1(GetHousingEditorMode)
	Print("probe place: %s from bag %s slot %s, mode %s",
		addon.Clean(Try1(GetItemName, bag, slot)), tostring(bag), tostring(slot),
		mode ~= nil and addon.ModeName(mode) or "?")

	PlaceOne(self, run, bag, slot, dataId, pose.x, pose.y, pose.z, function(id, why, ms)
		if not id then
			return EndProbe(self, run, "PLACE FAILED: " .. tostring(why))
		end

		Print("  placed in %d ms, id %s", ms, tostring(IdKey(id)))
		local position = Call(HousingEditorGetFurnitureWorldPosition, id)
		if position then
			Print("  asked %d %d %d, got %d %d %d", pose.x, pose.y, pose.z, position[1], position[2], position[3])
		end

		if keep then
			return EndProbe(self, run, "PLACE WORKS (left in the house; /pbfe undo is not recorded for probes)")
		end

		RemoveOne(self, run, id, function(ok, removeWhy, removeMs)
			if ok then
				EndProbe(self, run, string.format("PLACE WORKS: placed in %d ms, taken back in %d ms", ms, removeMs))
			else
				EndProbe(self, run, "PLACE WORKS, but taking it back failed: " .. tostring(removeWhy))
			end
		end)
	end)
end

-- ---------------------------------------------------------------------------------------
-- probe: two furnishings, linked
-- ---------------------------------------------------------------------------------------

local function Poll(run, test, timeoutMs, cb)
	local started = addon.Now()
	local function step()
		local value = test()
		if value then
			return cb(true, addon.Now() - started)
		end
		if addon.Now() - started >= timeoutMs then
			return cb(false, addon.Now() - started)
		end
		Later(run, 150, step)
	end
	step()
end

function addon:ProbeLink(words)
	local bag, slot = ParseSlot(words)
	local dataId = CheckSlot(bag, slot)
	if not dataId then
		return
	end

	local stack = Try1(GetSlotStackSize, bag, slot) or 1
	if stack < 2 then
		Print("this needs two of the same item; that stack is %d", stack)
		return
	end

	local pose = self:PlayerPose()
	if not pose then
		Print("could not read your position")
		return
	end

	local run = StartProbe(self)
	if not run then
		return
	end

	Print("probe link: two of %s", addon.Clean(Try1(GetItemName, bag, slot)))

	local idA, idB
	local verdict = "LINK PROBE ENDED EARLY"

	local function cleanup()
		local function removeB()
			if not idB then
				return EndProbe(self, run, verdict)
			end
			RemoveOne(self, run, idB, function() EndProbe(self, run, verdict) end)
		end
		if not idA then
			return removeB()
		end
		RemoveOne(self, run, idA, function() removeB() end)
	end

	local function fail(text)
		verdict = text
		cleanup()
	end

	local function finishUnlink()
		local results, err = Call(HousingEditorRequestClearFurnitureParent, idB)
		if not results then
			return fail("LINK WORKS, but ClearFurnitureParent was refused: " .. tostring(err))
		end
		Print("  RequestClearFurnitureParent -> %s", addon.ResultText(results[1]))
		Poll(run, function()
			local parent = Try1(GetPlacedFurnitureParent, idB)
			return parent == nil or IsNoId(parent)
		end, run.timeout, function(ok, ms)
			verdict = ok and "LINK WORKS: place, link, the child follows, unlink, remove"
				or "LINK WORKS, but the unlink never showed"
			cleanup()
		end)
	end

	local function moveParent()
		local position = Call(HousingEditorGetFurnitureWorldPosition, idA)
		local childBefore = Call(HousingEditorGetFurnitureWorldPosition, idB)
		if not (position and childBefore) then
			return fail("LINK WORKS, but positions cannot be read")
		end

		local target = position[1] + 50
		local results, err = Call(HousingEditorRequestChangePosition, idA, target, position[2], position[3])
		if not results then
			Print("  ChangePosition refused: %s", tostring(err))
			return finishUnlink()
		end
		Print("  RequestChangePosition(parent +50) -> %s", addon.ResultText(results[1]))

		Poll(run, function()
			local now = Call(HousingEditorGetFurnitureWorldPosition, idA)
			return now and now[1] == target
		end, run.timeout, function(ok)
			if not ok then
				Print("  the parent did not move")
				return finishUnlink()
			end
			local childAfter = Call(HousingEditorGetFurnitureWorldPosition, idB)
			if childAfter then
				local moved = childAfter[1] - childBefore[1]
				Print("  child moved %d cm along x (50 means it follows its parent)", moved)
			end
			finishUnlink()
		end)
	end

	local function link()
		local results, err = Call(HousingEditorRequestSetFurnitureParent, idB, idA)
		if not results then
			return fail("LINK REFUSED: " .. tostring(err))
		end
		Print("  RequestSetFurnitureParent -> %s", addon.ResultText(results[1]))
		if not addon.IsSuccess(results[1]) then
			return fail("LINK REFUSED: " .. addon.ResultText(results[1]))
		end

		Poll(run, function()
			return SameId(Try1(GetPlacedFurnitureParent, idB), idA)
		end, run.timeout, function(ok, ms)
			if not ok then
				return fail("LINK ACCEPTED, BUT THE PARENT NEVER SHOWED (" .. ms .. " ms)")
			end
			Print("  linked, parent visible after %d ms", ms)

			local children = Call(GetPlacedFurnitureChildren, idA)
			local listed = false
			for i = 1, children and #children or 0 do
				if SameId(children[i], idB) then
					listed = true
				end
			end
			Print("  parent lists the child: %s", Bool(listed))
			moveParent()
		end)
	end

	PlaceOne(self, run, bag, slot, dataId, pose.x, pose.y, pose.z, function(id, why)
		if not id then
			return fail("PLACE FAILED: " .. tostring(why))
		end
		idA = id
		Print("  A placed")

		PlaceOne(self, run, bag, slot, dataId, pose.x + 100, pose.y, pose.z, function(id2, why2)
			if not id2 then
				return fail("SECOND PLACE FAILED: " .. tostring(why2))
			end
			idB = id2
			Print("  B placed")
			link()
		end)
	end)
end

addon:AddCommand("probe", "  /pbfe probe place|link <slot>   try placing one item / linking two (changes the house, cleans up)", function(self, words)
	local which = table.remove(words, 1)
	if which == "place" then
		self:ProbePlace(words)
	elseif which == "link" then
		self:ProbeLink(words)
	else
		Print("probe what? place <slot> [keep], or link <slot>   (/pbfe items shows slots)")
	end
end)
