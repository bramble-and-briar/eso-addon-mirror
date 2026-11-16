-- Opening boxes, when the player has asked for it (the option "boxes", OFF by default).
--
-- A "box" is a container item in the backpack (ITEMTYPE_CONTAINER, _STACKABLE, _CURRENCY): using it consumes it and
-- opens a loot window, which Loot.lua then empties.
--
-- With the option off this file does nothing on its own: a box the PLAYER uses opens the same kind of loot window,
-- and Loot.lua empties it like any other (the loot option decides). The only things that open boxes then are the
-- sweeps the player starts (/pbal open, the panel's button), which run whatever the option says.
--
-- The call is UseItem(bag, slot), which the API marks *protected*. See Core.lua for how that is handled (the game
-- is asked; a protected function is reached through CallSecureProtected; the first use after a reload that follows
-- an error screen counts a strike).
--
-- When a box is opened:
--   * only on the plain HUD, out of combat, with no loot window up and nothing being talked to (A:Ready);
--   * only while at least `boxReserve` backpack slots (and never fewer than one) are free, because the contents are
--     lost if the backpack cannot take them;
--   * never a box the player has locked, one the game says cannot be used, or one that was refused twice.
-- A stack of boxes is opened one at a time: after each, the slot is looked at again and queued again while the
-- stack is not empty.
--
-- How it knows a box opened: the backpack changed (the stack got smaller or the slot now holds something else)
-- within OPEN_CHECK_MS. Otherwise the call counts as refused; the second refusal for the same item id puts the id on
-- a short list that lasts until the next login (a box that needs a choice, one that cannot be opened here ...).

local A = PBS_AUTO_LOOT
local S = PBS_AUTO_LOOT_STRINGS

A.boxType = {} -- item type -> true
A.open = { slot = nil, id = 0, count = 0, at = 0, readyAt = 0 } -- the box that was just used and is being waited for
A.boxLootUntil = 0 -- while this is in the future a loot window is ours even with the loot option off

function A:ResolveBoxTypes()
	local types = { "ITEMTYPE_CONTAINER", "ITEMTYPE_CONTAINER_STACKABLE", "ITEMTYPE_CONTAINER_CURRENCY" }
	local map = {}
	for _, name in ipairs(types) do
		local value = _G[name]
		if type(value) == "number" then
			map[value] = true
		end
	end
	self.boxType = map
end

function A:IsBoxSlot(slot)
	local itemType = GetItemType(BAG_BACKPACK, slot)
	return itemType ~= nil and self.boxType[itemType] == true
end

-- true when queued
function A:QueueBox(slot)
	local result = self.boxQ:Push(slot)
	if result == true then
		self.stats.queuedBoxes = self.stats.queuedBoxes + 1
		self:NotePeak()
		self:Wake()
		return true
	elseif result == nil then
		self.stats.dropped = self.stats.dropped + 1
	end
	return false
end

-- Queue every box in the backpack. Returns how many were added.
function A:SweepBoxes()
	local added = 0
	for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
		if self:IsBoxSlot(slot) and self:QueueBox(slot) then
			added = added + 1
		end
	end
	return added
end

-- nil when the slot holds a box that may be opened, else a short reason; then the item id and the stack size.
function A:BoxProblem(slot)
	local count = GetSlotStackSize(BAG_BACKPACK, slot)
	if not count or count <= 0 then
		return "empty"
	end
	if not self:IsBoxSlot(slot) then
		return "not a box"
	end
	if self.sv.skipLocked and IsItemPlayerLocked and IsItemPlayerLocked(BAG_BACKPACK, slot) then
		return "locked"
	end
	local id = GetItemId(BAG_BACKPACK, slot)
	if self.openSkip[id] then
		return "refused before"
	end
	local usable, onlyFromActionSlot = IsItemUsable(BAG_BACKPACK, slot)
	if not usable or onlyFromActionSlot then
		return "cannot be used"
	end
	return nil, id, count
end

-- Remember that this item id refused to open (a short list: MAX_SKIPPED ids).
function A:NoteRefusedBox(id)
	local fails = (self.openFails[id] or 0) + 1
	if self.openFails[id] == nil then
		if self.openFailN >= self.MAX_SKIPPED then
			return
		end
		self.openFailN = self.openFailN + 1
	end
	self.openFails[id] = fails
	if fails >= 2 then
		self.openSkip[id] = true
	end
end

-- One look at the box queue. Returns true while there is something left to do (the timer keeps running).
function A:StepBoxes(now)
	local sv = self.sv
	local stats = self.stats
	local o = self.open
	local q = self.boxQ

	-- 1. a box was used: did the backpack change?
	if o.slot then
		local slot = o.slot
		local count = GetSlotStackSize(BAG_BACKPACK, slot)
		local same = count ~= nil and count > 0 and GetItemId(BAG_BACKPACK, slot) == o.id
		if not same or count < o.count then
			o.slot = nil
			stats.opened = stats.opened + 1
			self:BatchAdd("opened", now)
			if same then
				-- more of the same stack: open the next
				self:QueueBox(slot)
			end
		elseif now - o.at >= self.OPEN_CHECK_MS then
			o.slot = nil
			stats.openFailed = stats.openFailed + 1
			self:BatchAdd("openFailed", now)
			self:NoteRefusedBox(o.id)
		else
			return true
		end
	end

	if q:Count() == 0 then
		self.manualBoxes = false
		return false
	end
	-- the switch governs what arrives; a sweep that the player asked for (/pbal open, the panel's button) runs
	-- whatever the switch says
	if not (sv.boxes or self.manualBoxes) then
		q:Clear()
		return false
	end
	if now < o.readyAt or now - self.lootClosedAt < sv.boxGapMs then
		return true
	end
	local ready = self:Ready()
	if not ready then
		return true
	end

	-- 2. the next box that can be opened (passing over at most a few that cannot, so a tick stays short)
	local slot, id, count
	for _ = 1, 8 do
		local candidate = q:Pop()
		if candidate == nil then
			break
		end
		local why
		why, id, count = self:BoxProblem(candidate)
		if not why then
			slot = candidate
			break
		end
		stats.openSkipped = stats.openSkipped + 1
		self.lastSkip = why
	end
	if not slot then
		return q:Count() > 0
	end

	local free = GetNumBagFreeSlots(BAG_BACKPACK)
	local need = math.max(1, sv.boxReserve)
	if free < need then
		-- do not wait for room to appear on its own: the player decides what to drop, and runs /pbal open again
		q:Clear()
		self:Notice("bagLow", S.bagLow, free, need)
		return false
	end

	o.id, o.count, o.at = id, count, now
	o.readyAt = now + sv.boxGapMs
	self.boxLootUntil = now + self.OPEN_CHECK_MS + 1000
	local ok, why = self:Call("open", "UseItem", BAG_BACKPACK, slot)
	if ok then
		o.slot = slot
		return true
	end
	-- the call was not made or was refused
	stats.openFailed = stats.openFailed + 1
	self.lastOpenWhy = why
	if not self:Route("open") then
		-- the game will not take this call from an add-on: say so once and stop trying
		q:Clear()
		self:Notice("openRefused", S.openRefused, tostring(why))
		return false
	end
	self:BatchAdd("openFailed", now)
	self:NoteRefusedBox(id)
	return q:Count() > 0
end

PBS_AL_MARK("Boxes")
