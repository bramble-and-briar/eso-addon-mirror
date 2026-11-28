-- Opening the writ reward boxes.
--
-- Which boxes are writ rewards (0.1.3):
--   1. by the box's flavour text: every writ shipment carries the same flavour text, and the game gives it for the
--      shipment items it knows (read through GetItemLinkFlavorText at start-up, so in the client's own
--      language). A box whose flavour text is one of those is a writ reward, whenever and however it arrives.
--   2. learned: a container that arrives within REWARD_WINDOW_MS of a crafting quest being completed (by us or by
--      hand), or BOX_BEFORE_MS before the event; its item id is remembered (at most MAX_BOX_IDS, account-wide).
-- 0.1.0-0.1.2 had only (2) and wanted the arrival flagged "new"; on a PS5 no box was opened, and nothing recorded which
-- step stopped. Now any arrival that adds to a stack counts, and every step leaves a trace (A.boxTrace, /pbwrit).
--
-- Opening is UseItem (protected -> A:Call), out of a fight and a conversation (BoxWait; a menu is fine), not before
-- AFTER_COMPLETE_MS after a writ was completed (the crate's conversation is still closing), not during the global
-- cooldown (a use then does nothing), and with boxReserve (at least 1) backpack slots free. The loot window it opens
-- is emptied before the standard UI updates. A box counts as opened once its stack shrinks or disappears.

local A = PBS_CRAFT_ASSIST
local S = PBS_CRAFT_ASSIST_STRINGS

local MAX_QUEUE = 50
local BOX_WAIT_MS = 1000 -- not the moment: look again this much later
local AFTER_COMPLETE_MS = 1500
local MAX_TRIES = 2

-- Item ID and link subtype for the writ coffer descriptions used in Lazy Writ Crafter's LootHandler.
-- French has separate descriptions for several crafts.
local REWARD_LINK_SUBTYPES = {
	[121302] = 175, [138816] = 3, [147603] = 3, [142175] = 3,
	[58519] = 175, [59714] = 175, [58528] = 175, [57851] = 175, [58510] = 175,
}

A.boxQ = { slots = {}, n = 0 }
A.box = { awaitingAt = nil, slot = nil, before = 0, opened = 0, tries = {} }
A.lastBox = { at = nil, id = nil, slot = nil } -- the last container that arrived (see OnQuestComplete)

-- What happened to boxes, step by step (numbers and short constant strings; /pbwrit prints it).
A.boxTrace = {
	arrivals = 0, -- containers that arrived in the backpack
	lastId = nil, lastNew = nil, lastChange = nil, lastSince = nil, -- the last one: id, isNew, stack change, ms since a completion
	lastWhy = nil, -- what was decided about it: "queued", "not a writ box", "boxes off"
	byFlavor = 0, byLearned = 0, -- how queued boxes were recognised
	wait = nil, -- why the last step waited ("combat", "interaction", "cooldown", "after completion" ...)
	waits = 0,
	calls = 0, -- UseItem calls made
	callWhy = nil, -- the last refusal
	windows = 0, -- loot windows that followed a call
	noWindow = 0, -- boxes gone without a window
	notOpened = 0, -- calls after which the box was still there
	flavors = 0, -- reference flavour texts the game gave
}
local T = A.boxTrace

local function IsBox(bag, slot)
	local itemType, special = GetItemType(bag, slot)
	return itemType == ITEMTYPE_CONTAINER
		and not (SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE and special == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE)
end
A.IsBox = IsBox

-- The reference flavour texts (built once, at the first need).
function A:RewardFlavors()
	local set = self.rewardFlavors
	if set then
		return set
	end
	set = {}
	if GetItemLinkFlavorText then
		for id, subtype in pairs(REWARD_LINK_SUBTYPES) do
			local link = string.format("|H1:item:%d:%d:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h", id, subtype)
			local ok, text = pcall(GetItemLinkFlavorText, link)
			if ok and type(text) == "string" and text ~= "" and not set[text] then
				set[text] = true
				T.flavors = T.flavors + 1
			end
		end
	end
	-- kept only when the game gave something: an empty answer is asked again at the next box
	if next(set) ~= nil then
		self.rewardFlavors = set
	end
	return set
end

-- Is the box in this slot a writ reward? Returns "flavor", "learned" or nil.
function A:RewardKind(bag, slot)
	if not IsBox(bag, slot) then
		return nil
	end
	if self.sv.boxIds[GetItemId(bag, slot)] then
		return "learned"
	end
	if GetItemLink and GetItemLinkFlavorText then
		local text = GetItemLinkFlavorText(GetItemLink(bag, slot, LINK_STYLE_DEFAULT))
		if text and text ~= "" and self:RewardFlavors()[text] then
			return "flavor"
		end
	end
	return nil
end

function A:LearnBox(itemId)
	local ids = self.sv.boxIds
	if ids[itemId] then
		return
	end
	local n = 0
	for _ in pairs(ids) do
		n = n + 1
	end
	if n < self.MAX_BOX_IDS then
		ids[itemId] = true
	end
end

function A:QueueBox(slot)
	local q = self.boxQ
	for i = 1, q.n do
		if q.slots[i] == slot then
			return
		end
	end
	if q.n < MAX_QUEUE then
		q.n = q.n + 1
		q.slots[q.n] = slot
	end
	if not self.box.awaitingAt then
		self:Later("box", self.OPEN_GAP_MS, "BoxStep")
	end
end

local function PopBox(q)
	if q.n == 0 then
		return nil
	end
	local slot = q.slots[1]
	for i = 1, q.n - 1 do
		q.slots[i] = q.slots[i + 1]
	end
	q.slots[q.n] = nil
	q.n = q.n - 1
	return slot
end

-- A new slot and a gain on an existing stack are both arrivals.
function A:OnSlotUpdate(bag, slot, isNew, stackChange)
	local delta = tonumber(stackChange) or 0
	if bag ~= BAG_BACKPACK or delta < 0 or (delta == 0 and not isNew) then
		return
	end
	if not IsBox(bag, slot) then
		return
	end
	local now = GetGameTimeMilliseconds()
	local id = GetItemId(bag, slot)
	T.arrivals = T.arrivals + 1
	T.lastId, T.lastNew, T.lastChange = id, isNew and true or false, stackChange
	T.lastSince = self.completedAt and (now - self.completedAt) or nil
	local last = self.lastBox
	last.at, last.id, last.slot = now, id, slot
	if self.rewardUntil and now <= self.rewardUntil then
		-- one writ gives one box: the first container of the window is the reward, the window closes
		self.rewardUntil = nil
		last.at = nil
		self.boxTakenAt = now
		self:LearnBox(id)
	end
	local kind = self:RewardKind(bag, slot)
	if not kind then
		T.lastWhy = "not a writ box"
	elseif not self.sv.boxes then
		T.lastWhy = "boxes off"
	else
		T.lastWhy = "queued (" .. kind .. ")"
		if kind == "flavor" then
			T.byFlavor = T.byFlavor + 1
			self:LearnBox(id)
		else
			T.byLearned = T.byLearned + 1
		end
		self:QueueBox(slot)
	end
end

-- Keep the first snapshot when several writs are handed in together.
function A:RememberBoxesBeforeDelivery()
	if self.timerOn.boxDelivery then return end
	local before = {}
	for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
		if IsBox(BAG_BACKPACK, slot) then
			before[slot] = { id = GetItemId(BAG_BACKPACK, slot), count = GetSlotStackSize(BAG_BACKPACK, slot) }
		end
	end
	self.boxesBeforeDelivery = before
end

-- Commands and login scan the whole bag. After a hand-in only new or increased stacks qualify.
function A:SweepBoxes(before)
	local n = 0
	local size = GetBagSize(BAG_BACKPACK) or 0
	for slot = 0, size - 1 do
		local count = GetSlotStackSize(BAG_BACKPACK, slot) or 0
		local old = before and before[slot]
		if count > 0 and (not old or count > old.count or GetItemId(BAG_BACKPACK, slot) ~= old.id)
			and self:RewardKind(BAG_BACKPACK, slot) then
			self:QueueBox(slot)
			n = n + 1
		end
	end
	return n
end

function A:CheckDeliveredBoxes()
	local before = self.boxesBeforeDelivery
	self.boxesBeforeDelivery = nil
	if before and self.sv.boxes then self:SweepBoxes(before) end
end

-- Why now is not the moment to use a box (a constant string), or nil.
-- The conditions of Lazy Writ Crafter (0.1.4): no fight, no swimming, no loot window, no conversation (its camera or
-- the "interact" scene), not right after a hand-in, not in the global cooldown. A menu does NOT stop it -- 0.1.0-0.1.3
-- waited for the plain HUD (SCENE_MANAGER:IsShowingBaseScene), which may never be true on a console, and so never
-- opened a box (and never from the settings page either).
function A:BoxWait(now)
	if IsPlayerActivated and not IsPlayerActivated() then
		return "loading"
	end
	if IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player") then
		return "dead"
	end
	if IsUnitInCombat and IsUnitInCombat("player") then
		return "combat"
	end
	if IsUnitSwimming and IsUnitSwimming("player") then
		return "swimming"
	end
	if IsLooting and IsLooting() then
		return "loot window"
	end
	if IsInteractionUsingInteractCamera and IsInteractionUsingInteractCamera() then
		return "conversation"
	end
	local scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
	if type(scene) == "table" and scene.name == "interact" then
		return "conversation"
	end
	if GetInteractionType and INTERACTION_NONE and GetInteractionType() ~= INTERACTION_NONE then
		return "interaction"
	end
	if self.completedAt and now - self.completedAt < AFTER_COMPLETE_MS then
		return "after completion"
	end
	if GetSlotCooldownInfo then
		local ok, remain = pcall(GetSlotCooldownInfo, 1)
		if ok and (tonumber(remain) or 0) > 0 then
			return "cooldown"
		end
	end
	return nil
end

-- A close can precede the inventory update. Give the server time to publish the result.
function A:BoxSettle(now)
	local box = self.box
	local slot = box.slot
	local count = GetSlotStackSize(BAG_BACKPACK, slot) or 0
	local same = count > 0 and GetItemId(BAG_BACKPACK, slot) == box.id
	local consumed = not same or count < box.before
	if (not box.closed or not consumed) and now - box.awaitingAt <= self.OPEN_CHECK_MS then
		return false
	end
	box.awaitingAt, box.slot, box.name = nil, nil, nil
	if consumed then
		if not box.handled then
			T.noWindow = T.noWindow + 1
		end
		box.tries[slot] = nil
		box.opened = box.opened + 1
		self.stats.opened = self.stats.opened + 1
		if same then
			self:QueueBox(slot)
		end
		return true
	end
	T.notOpened = T.notOpened + 1
	self.stats.openFailed = self.stats.openFailed + 1
	local tries = (box.tries[slot] or 0) + 1
	box.tries[slot] = tries
	if tries < MAX_TRIES then
		self:QueueBox(slot)
	end
	return true
end

function A:BoxStep()
	local box, q = self.box, self.boxQ
	local now = GetGameTimeMilliseconds()
	if box.awaitingAt and not self:BoxSettle(now) then
		self:Later("box", BOX_WAIT_MS, "BoxStep")
		return
	end
	if q.n == 0 then
		self:BoxSummary()
		return
	end
	local wait = self:BoxWait(now)
	if wait then
		T.wait, T.waits = wait, T.waits + 1
		self:Later("box", BOX_WAIT_MS, "BoxStep")
		return
	end
	local free = (GetNumBagFreeSlots and GetNumBagFreeSlots(BAG_BACKPACK)) or 0
	if free < math.max(1, self.sv.boxReserve) then
		-- keep the boxes and look again: room may be made
		T.wait, T.waits = "backpack full", T.waits + 1
		self:Notice("boxFull", S.boxNoRoom, math.max(1, self.sv.boxReserve))
		self:Later("box", BOX_WAIT_MS, "BoxStep")
		return
	end
	T.wait = nil
	local slot = PopBox(q)
	local count = slot and (GetSlotStackSize(BAG_BACKPACK, slot) or 0) or 0
	if count > 0 and self:RewardKind(BAG_BACKPACK, slot) then
		-- UseItem can update the slot or dispatch a loot callback before returning.
		box.id = GetItemId(BAG_BACKPACK, slot)
		box.name = GetItemLinkName(GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT))
		box.awaitingAt, box.slot, box.before = now, slot, count
		box.handled, box.closed = false, false
		local ok, why = self:Call("open", "UseItem", BAG_BACKPACK, slot)
		T.calls = T.calls + 1
		if not ok then
			box.awaitingAt, box.slot, box.name = nil, nil, nil
			T.callWhy = tostring(why)
			self.stats.openFailed = self.stats.openFailed + 1
			self:Notice("open", S.openRefused, tostring(why))
			q.n = 0
			self:BoxSummary()
			return
		end
	end
	self:Later("box", box.awaitingAt and BOX_WAIT_MS or self.OPEN_GAP_MS, "BoxStep")
end

local function LootRewardWindow()
	local box = A.box
	if not box.awaitingAt or box.closed then return false end
	local elapsed = GetGameTimeMilliseconds() - box.awaitingAt
	if elapsed > A.OPEN_CHECK_MS then return false end
	-- Compare the raw localized names. The name passed to UpdateLootWindow is already formatted.
	local target = GetLootTargetInfo()
	if target == "" then
		-- The first update can precede the target name. Let the named update handle the loot.
		return IsLooting() and elapsed < 1000
	end
	if target ~= box.name then
		return false
	end
	if box.handled then return true end
	box.handled = true -- LootAll can cause another update before it returns
	T.windows = T.windows + 1
	if not A:Try(LootAll, true) then
		box.handled = false
		return false
	end
	A.stats.looted = A.stats.looted + 1
	if IsLooting() and GetLootTargetInfo() == box.name then
		A:Try(EndLooting)
	end
	return true
end

function A:InitRewardLoot()
	-- The gamepad loot UI can end the interaction when a menu is showing. Handle the
	-- coffer before that decision, in whichever input mode the player uses.
	local function hook(loot)
		if loot then ZO_PreHook(loot, "UpdateLootWindow", LootRewardWindow) end
	end
	hook(SYSTEMS:GetKeyboardObject("loot"))
	hook(SYSTEMS:GetGamepadObject("loot"))
end

function A:OnLootClosed()
	local box = self.box
	if box.awaitingAt and box.handled then
		box.closed = true
		self:Later("box", self.OPEN_GAP_MS, "BoxStep")
	end
end

function A:BoxSummary()
	local box = self.box
	if box.opened > 0 then
		self:Print(S.boxesOpened, box.opened)
		box.opened = 0
	end
	for k in pairs(box.tries) do
		box.tries[k] = nil
	end
end

-- For /pbwrit.
function A:BoxTraceLines(lines)
	self:RewardFlavors()
	lines[#lines + 1] = string.format("box trace: flavour texts known %d; arrivals %d, last id %s new %s +%s %s after a completion -> %s",
		T.flavors, T.arrivals, tostring(T.lastId), tostring(T.lastNew), tostring(T.lastChange),
		T.lastSince and string.format("%.1f s", T.lastSince / 1000) or "not", tostring(T.lastWhy or "-"))
	lines[#lines + 1] = string.format("box steps: queued now %d (flavour %d, learned %d); waits %d, last wait %s; UseItem calls %d%s; loot windows %d, gone without one %d, still there %d",
		self.boxQ.n, T.byFlavor, T.byLearned, T.waits, tostring(T.wait or "-"), T.calls,
		T.callWhy and (" (refused: " .. T.callWhy .. ")") or "", T.windows, T.noWindow, T.notOpened)
end

PBS_CA_MARK("Rewards")
