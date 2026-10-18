-- PB's FurnitureEditor -- reservations
--
-- A house cannot be edited from outside it: every placement call acts on the house the player is
-- standing in, and none takes a house id. So "paste into house 3" cannot be done remotely; what can
-- be done is to decide now and have it happen the moment the player is there.
--
-- A reservation is a clip and the words of a paste (house, mode, rot, up, go), kept in saved
-- variables. Several can wait at once. When the player enters a house that has reservations, the
-- house is given time to load, and then the reservations for it are worked through one at a time:
--
--   reserve copy 1 to 2 same go      the group is read now; house #2 gets it on the next visit
--   reserve cut  1 to 2 same go yes  the group is TAKEN OUT now, and put into house #2 on the next visit
--
-- Three things keep this from surprising anyone:
--
--   * A reservation with `go` does not start at once on arrival. It says so and waits ten seconds,
--     and /pbfe stop in that time cancels it for this visit. (A reservation made months ago and
--     forgotten must not rearrange a house without warning.)
--   * One without `go` only shows its plan on arrival, and is run by hand: reservations run <n> go.
--   * A reservation that comes to nothing (short of items, not the owner, the plan refused) stays on
--     the list and tries again on the next visit; one that stopped part way is marked "partial" and
--     is left alone, because pasting it again would place the pieces twice.
--
-- A cut reservation does the dangerous half now: the furnishings leave this house at once, and the
-- reservation holds the only record of where they go. It needs `yes`, because `go` there already
-- means "paste automatically".

local addon = PBS_FURNITURE_EDITOR

local Call, Try1 = addon.Call, addon.Try1
local Print, Line = addon.Print, addon.Line

local GRACE_MS = 10000
local MAX_RESERVATIONS = 30

-- ---------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------

function addon:FindReservation(id)
	for index, resv in ipairs(self.sv.reservations) do
		if resv.id == id then
			return resv, index
		end
	end
	return nil
end

-- the waiting ones for a house, in the order they were made
function addon:ReservationsFor(houseId)
	local list = {}
	for _, resv in ipairs(self.sv.reservations) do
		if resv.houseId == houseId and resv.status == "waiting" then
			list[#list + 1] = resv
		end
	end
	return list
end

local function Label(clip)
	local first = clip.nodes[1]
	return string.format("%s (%d)", first and first.name or "?", #clip.nodes)
end

local function HouseName(houseId)
	for _, house in ipairs(addon:OwnedHouses()) do
		if house.houseId == houseId then
			return house.nickname and (house.name .. " (" .. house.nickname .. ")") or house.name
		end
	end
	return "house " .. tostring(houseId)
end

local function Age(createdAt)
	local seconds = (Try1(GetTimeStamp) or 0) - (createdAt or 0)
	if seconds < 3600 then
		return string.format("%d min", math.max(math.floor(seconds / 60), 0))
	elseif seconds < 86400 then
		return string.format("%d h", math.floor(seconds / 3600))
	end
	return string.format("%d days", math.floor(seconds / 86400))
end

function addon:AddReservation(kind, target, clip, opts)
	local sv = self.sv
	local id = sv.nextReservationId
	sv.nextReservationId = id + 1

	sv.reservations[#sv.reservations + 1] = {
		id = id,
		kind = kind,                       -- "copy" or "move"
		houseId = target.houseId,
		words = opts.rest,                 -- what a paste is told: mode, rot, up, force, go
		auto = opts.go and true or false,
		clip = clip,
		label = Label(clip),
		createdAt = Try1(GetTimeStamp) or 0,
		status = "waiting",
	}

	return id
end

-- Which kinds of furnishing the bags are short of for this clip. Information at the moment of
-- reserving; the real check is made again on arrival.
function addon:SupplyShortfall(clip)
	local inventory = self:IndexInventory()
	local need, order = {}, {}
	for _, node in ipairs(clip.nodes) do
		if (node.collectibleId or 0) == 0 then
			if not need[node.dataId] then
				need[node.dataId] = { name = node.name, count = 0 }
				order[#order + 1] = node.dataId
			end
			need[node.dataId].count = need[node.dataId].count + 1
		end
	end

	local short = {}
	for _, dataId in ipairs(order) do
		local have = inventory.byData[dataId] and inventory.byData[dataId].total or 0
		if have < need[dataId].count then
			short[#short + 1] = { name = need[dataId].name, need = need[dataId].count, have = have }
		end
	end
	return short
end

-- ---------------------------------------------------------------------------------------
-- reserve
-- ---------------------------------------------------------------------------------------

-- Words that start the options. The selection (1 3, near, sel, all) is whatever comes before.
local OPTION_WORDS = {
	to = true, same = true, here = true, aim = true, rot = true, up = true,
	go = true, force = true, outside = true, yes = true,
}

addon:AddCommand("reserve", "  /pbfe reserve copy|cut <n>|near|sel|all to <h> [aim|here|same] [rot 90] [up 20] [go] [yes]   decide now, paste when you enter", function(self, words)
	local kind = table.remove(words, 1)
	if kind ~= "copy" and kind ~= "cut" then
		Print("reserve what? e.g. /pbfe reserve copy 1 to 2 same go     (cut needs a final 'yes')")
		return
	end

	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return
	end

	local original = table.concat(words, " ")
	local yes = addon.TakeFlag(words, "yes")

	local selection, options = {}, {}
	local inOptions = false
	for _, word in ipairs(words) do
		if OPTION_WORDS[word] then
			inOptions = true
		end
		if inOptions then
			options[#options + 1] = word
		else
			selection[#selection + 1] = word
		end
	end

	local opts, why = addon.ParseOptions(options)
	if not opts then
		Print("%s", why)
		return
	end
	if not opts.to then
		Print("which house? add 'to <number>' (see /pbfe houses)")
		return
	end

	local target = self:OwnedHouses()[opts.to]
	if not target then
		Print("no house #%s -- /pbfe houses", tostring(opts.to))
		return
	end

	if #self.sv.reservations >= MAX_RESERVATIONS then
		Print("there are already %d reservations; /pbfe reservations drop one", MAX_RESERVATIONS)
		return
	end

	-- A reservation that could never run is not made.
	if opts.delta ~= 0 and not (self.sv.convention and self.sv.convention.sy) then
		Print("rot needs /pbfe calib first (the client's rotation order is not known yet)")
		return
	end

	local access, _, pose, chosen = self:SelectGroups(selection, "reserve " .. kind)
	if not access then
		return
	end

	local clip = self:MakeClip(chosen, access, pose)
	local how = opts.go and "starts by itself 10 s after you arrive (/pbfe stop cancels)"
		or "shows its plan when you arrive; run it with /pbfe reservations run <n> go"

	if kind == "copy" then
		local id = self:AddReservation("copy", target, clip, opts)
		Print("reserved #%d: copy of %s -> %s", id, clip.nodes[1].name, HouseName(target.houseId))
		Print("it %s", how)

		local short = self:SupplyShortfall(clip)
		for i = 1, math.min(#short, 3) do
			Line("  you are short of %s: need %d, have %d", short[i].name, short[i].need, short[i].have)
		end
		if #short > 3 then
			Line("  ... and %d more kinds. get them before the paste starts", #short - 3)
		end
		return
	end

	-- cut: the furnishings leave this house now
	if not access.owner then
		Print("you can only cut from a house you own")
		return
	end

	local keys = {}
	for i = #clip.nodes, 1, -1 do
		keys[#keys + 1] = clip.nodes[i].srcKey
	end

	self:RunCut(clip, keys, clip.nodes, yes, opts.force, "/pbfe reserve cut " .. original, function(c)
		local id = self:AddReservation("move", target, c, opts)
		Print("reserved #%d: MOVE of %s -> %s (taking it out of this house now)", id, c.nodes[1].name, HouseName(target.houseId))
		Print("it %s", how)
		return id
	end, "yes")
end)

-- ---------------------------------------------------------------------------------------
-- Arriving in a house that has reservations
-- ---------------------------------------------------------------------------------------

function addon:ReservationsArrived(houseId)
	local waiting = self:ReservationsFor(houseId)
	local clipboard = self.HasClipboardOffer and self:HasClipboardOffer()
	local heldCut = self.sv.clip and self.sv.clip.cut
	if #waiting == 0 and not clipboard and not heldCut then
		return
	end

	self.arrivalToken = (self.arrivalToken or 0) + 1
	local token = self.arrivalToken

	if #waiting > 0 then
		Print("%d reservation%s waiting for this house; letting it finish loading", #waiting, #waiting == 1 and " is" or "s are")
	end
	self:WaitForHouse(function()
		return addon.arrivalToken == token and (Try1(GetCurrentZoneHouseId) or 0) == houseId
	end, function()
		addon:AnnounceMenu(true)
		addon:EnqueueReservations(houseId)
	end)
end

function addon:EnqueueReservations(houseId)
	self.queue = self.queue or {}

	local queued = {}
	for _, id in ipairs(self.queue) do
		queued[id] = true
	end
	for _, resv in ipairs(self:ReservationsFor(houseId)) do
		if not queued[resv.id] then
			self.queue[#self.queue + 1] = resv.id
		end
	end

	self:RunQueue()
end

-- Start the next queued reservation, if nothing else is going on.
function addon:RunQueue()
	if self.run or self.queueWait then
		return
	end

	local here = Try1(GetCurrentZoneHouseId) or 0
	while self.queue and #self.queue > 0 do
		local id = table.remove(self.queue, 1)
		local resv = self:FindReservation(id)

		if resv and resv.status == "waiting" and resv.houseId == here then
			if resv.auto then
				Print("reservation #%d (%s) starts in %d s -- /pbfe stop cancels it", resv.id, resv.label, GRACE_MS / 1000)
				local token = {}
				self.queueWait = token
				addon.Later(GRACE_MS, function()
					if addon.queueWait ~= token then
						return
					end
					addon.queueWait = nil
					addon:StartReservation(id)
				end)
				return
			end

			self:StartReservation(id)
			return
		end
	end
end

function addon:StartReservation(id)
	local resv = self:FindReservation(id)
	if not resv or resv.status ~= "waiting" then
		return self:RunQueue()
	end

	Print("reservation #%d: %s %s", resv.id, resv.kind, resv.label)
	local outcome = self:Paste(resv.words, true, resv.clip, { reservationId = resv.id })

	-- only a paste that has started will say when it is over; anything else lets the next one go
	if outcome ~= "started" then
		self:RunQueue()
	end
end

-- Called when any run ends (Paste.lua's Finish).
function addon:AfterRun(run)
	local meta = run.meta
	if meta and meta.reservationId and run.kind == "paste" then
		self:ReservationPasteFinished(run, meta.reservationId)
	end
	self:RunQueue()

	-- what was picked on the quickslot wheel carries on with the next pick, or the wheel is put back
	if self.menuJobs and #self.menuJobs > 0 then
		self:RunMenuJobs()
	elseif self.MenuRefreshed then
		self:MenuRefreshed()
	end
end

function addon:ReservationPasteFinished(run, id)
	local resv, index = self:FindReservation(id)
	if not resv then
		return
	end

	if run.complete then
		table.remove(self.sv.reservations, index)
		Print("reservation #%d is done", id)
	elseif run.placed == 0 then
		-- nothing was changed, so it can simply try again on the next visit
		resv.note = "did not start"
		Print("reservation #%d placed nothing; it stays on the list", id)
	else
		resv.status = "partial"
		if run.placed + (run.existing or 0) == #run.nodes then
			resv.note = string.format("all placed, %d link%s failed", #run.linkFailed, #run.linkFailed == 1 and "" or "s")
		else
			resv.note = string.format("placed %d of %d", run.placed, #run.nodes)
		end
		Print("reservation #%d stopped part way (%s). /pbfe undo takes the placed ones back;", id, resv.note)
		Print("then /pbfe reservations retry %d", id)
	end
end

-- /pbfe stop: nothing waiting starts this visit. The reservations themselves stay.
function addon:CancelQueue()
	local had = self.queueWait ~= nil or (self.queue ~= nil and #self.queue > 0)
	self.queueWait = nil
	self.queue = {}
	self.arrivalToken = (self.arrivalToken or 0) + 1
	if had then
		Print("the waiting reservations will not start this visit; they stay on the list")
	end
	return had
end

-- ---------------------------------------------------------------------------------------
-- reservations
-- ---------------------------------------------------------------------------------------

-- the reservation a word names, and its place in the list
local function Wanted(self, word)
	local number = tonumber(word)
	local resv, index
	if number then
		resv, index = self:FindReservation(number)
	end
	if not resv then
		Print("no reservation #%s -- /pbfe reservations", tostring(word))
		return nil
	end
	return resv, index
end

addon:AddCommand("reservations", "  /pbfe reservations [run <n> [go]|drop <n>|all|load <n>|retry <n>]   what is waiting", function(self, words)
	local sub = words[1]

	if not sub then
		local list = self.sv.reservations
		if #list == 0 then
			Print("no reservations. /pbfe reserve copy 1 to 2 same go")
			return
		end

		Print("%d reservations", #list)
		for _, resv in ipairs(list) do
			Line("  #%d  %s  %s -> %s  %s  [%s%s]  %s ago", resv.id, resv.kind, resv.label, HouseName(resv.houseId),
				table.concat(resv.words, " "), resv.status, resv.note and (": " .. resv.note) or "", Age(resv.createdAt))
		end
		return
	end

	if sub == "drop" then
		if words[2] == "all" then
			local pending = 0
			for _, resv in ipairs(self.sv.reservations) do
				if resv.clip.cut then
					pending = pending + 1
				end
			end
			if pending > 0 and words[3] ~= "force" then
				Print("%d of them are moves whose furnishings are in your bag; 'drop all force' forgets where they go", pending)
				return
			end
			self.sv.reservations = {}
			Print("all reservations dropped")
			return
		end

		local resv, index = Wanted(self, words[2])
		if not resv then
			return
		end
		if resv.clip.cut and words[3] ~= "force" then
			Print("#%d is a move: its furnishings are out of the house and in your bag, and this is the only record", resv.id)
			Print("of where they go. /pbfe reservations load %d keeps it; 'drop %d force' forgets it", resv.id, resv.id)
			return
		end
		table.remove(self.sv.reservations, index)
		Print("reservation #%d dropped", resv.id)
		return
	end

	if sub == "load" then
		local resv = Wanted(self, words[2])
		if not resv then
			return
		end
		if self:PendingCutBlocks(words[3] == "force") then
			return
		end
		self.sv.clip = addon.DeepCopy(resv.clip)
		Print("#%d is on the clipboard: %d furnishings%s", resv.id, #resv.clip.nodes, resv.clip.cut and " (a cut)" or "")
		return
	end

	if sub == "retry" then
		local resv = Wanted(self, words[2])
		if not resv then
			return
		end
		resv.status = "waiting"
		resv.note = nil
		Print("reservation #%d is waiting again", resv.id)
		return
	end

	if sub == "run" then
		local resv = Wanted(self, words[2])
		if not resv then
			return
		end
		if resv.status ~= "waiting" then
			Print("#%d is %s; /pbfe reservations retry %d first", resv.id, resv.status, resv.id)
			return
		end

		local target
		for _, house in ipairs(self:OwnedHouses()) do
			if house.houseId == resv.houseId then
				target = house
			end
		end
		if not target then
			Print("you no longer have that house")
			return
		end

		local rest = {}
		for _, word in ipairs(resv.words) do
			rest[#rest + 1] = word
		end
		if words[3] == "go" then
			rest[#rest + 1] = "go"
		end

		self:JumpAndPaste(target, rest, false, resv.clip, { reservationId = resv.id })
		return
	end

	Print("reservations what? run <n> [go], drop <n>|all, load <n>, retry <n>")
end)
