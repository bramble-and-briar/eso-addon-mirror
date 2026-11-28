-- Taking what the writs need out of the bank (and "acquire" items out of the craft bag).
--
-- When the bank opens, a plan is made, then carried out one move at a time:
--   1. finished items: any bank slot whose item fulfils an open writ line (DoesItemFulfillJournalQuestCondition --
--      the game's own test) is taken, up to what the line still needs. This covers a potion or glyph made earlier
--      and stored, and the "acquire" lines.
--   2. materials (option): for each line still to be crafted, what the craft will use and the backpack and craft bag
--      do not hold enough of -- the raw material and a style stone (smithing), the three runes (enchanting), the
--      solvent and a reagent pair (alchemy), the recipe's ingredients (provisioning).
-- Moves go through RequestMoveItem, which is protected (A:Call -> CallSecureProtected), into an empty backpack slot.
-- The plan stops when the backpack has no room; the queue is dropped when the bank closes.
--
-- Away from a station the exact amount of a smithing pattern's material cannot be read, so SMITH_MAT_PER_ITEM per
-- item is taken (only when the backpack and craft bag hold less than that).

local A = PBS_CRAFT_ASSIST
local S = PBS_CRAFT_ASSIST_STRINGS

-- the move queue: parallel arrays, reused
local qBag, qSlot, qCount, qId = {}, {}, {}, {}
A.moveQ = { head = 1, tail = 0, items = 0, stacks = 0, failed = 0, why = nil, fromBank = false }
local Q = A.moveQ
local planned = {} -- bag*1000000+slot -> amount already planned from that slot
local wanted = {} -- itemId -> amount the lines still to be crafted will use (summed over the lines)
local styleItems = 0 -- styled smithing items still to be crafted
local plannedId = {} -- itemId -> amount already planned
local reserved = {} -- backpack slots a planned move will land in
local sources = {}
A.planned, A.plannedId, A.reserved = planned, plannedId, reserved

local function Clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function Key(bag, slot)
	return bag * 1000000 + slot
end

function A:QueuedMoves()
	return Q.tail - Q.head + 1
end

local function Push(bag, slot, count, itemId)
	Q.tail = Q.tail + 1
	qBag[Q.tail], qSlot[Q.tail], qCount[Q.tail], qId[Q.tail] = bag, slot, count, itemId
	planned[Key(bag, slot)] = (planned[Key(bag, slot)] or 0) + count
	plannedId[itemId] = (plannedId[itemId] or 0) + count
end

-- room left in the backpack for new stacks, counting the moves already queued
function A:RoomLeft()
	local free = (GetNumBagFreeSlots and GetNumBagFreeSlots(BAG_BACKPACK)) or 0
	return free - self:QueuedMoves()
end

-- Plan `amount` of an item out of the source bags. Returns what could be planned.
function A:TakeById(itemId, amount)
	if not itemId or itemId == 0 or amount <= 0 then
		return 0
	end
	local got = 0
	for i = 1, #sources do
		local bag = sources[i]
		local slot = A.NextSlot(bag, nil)
		while slot and got < amount do
			if GetItemId(bag, slot) == itemId then
				local left = (GetSlotStackSize(bag, slot) or 0) - (planned[Key(bag, slot)] or 0)
				if left > 0 then
					if self:RoomLeft() <= 0 then
						Q.why = S.bankFull
						return got
					end
					local take = math.min(left, amount - got)
					Push(bag, slot, take, itemId)
					got = got + take
				end
			end
			slot = A.NextSlot(bag, slot)
		end
	end
	return got
end

-- Plan whatever an item is short of: wanted in the backpack/craft bag, counting what is already planned.
function A:TopUp(itemId, wanted)
	if not itemId or itemId == 0 then
		return
	end
	local short = wanted - self:CountOwned(itemId) - (plannedId[itemId] or 0)
	if short > 0 then
		self:TakeById(itemId, short)
	end
end

-- Step 1: the items that fulfil a line, from the given source bags. Sets rec.left.
function A:PlanFinished(rec)
	local need = rec.need
	for i = 1, #sources do
		local bag = sources[i]
		local slot = A.NextSlot(bag, nil)
		while slot and need > 0 do
			local left = (GetSlotStackSize(bag, slot) or 0) - (planned[Key(bag, slot)] or 0)
			if left > 0 and DoesItemFulfillJournalQuestCondition(bag, slot, rec.quest, rec.step, rec.cond) then
				if self:RoomLeft() <= 0 then
					Q.why = S.bankFull
					break
				end
				local take = math.min(left, need)
				Push(bag, slot, take, GetItemId(bag, slot))
				need = need - take
			end
			slot = A.NextSlot(bag, slot)
		end
	end
	rec.left = need
end

-- item id of a style's stone (cached; the table holds one number per style id)
A.styleStone = {}
function A:StyleStoneId(styleId)
	local id = self.styleStone[styleId]
	if id == nil then
		local link = GetItemStyleMaterialLink and GetItemStyleMaterialLink(styleId, LINK_STYLE_DEFAULT)
		id = (link and link ~= "" and GetItemLinkItemId(link)) or 0
		self.styleStone[styleId] = id
	end
	return id
end

function A:PlanStyle(items)
	local list = self.BASIC_STYLES
	local have = 0
	for i = 1, #list do
		local id = self:StyleStoneId(list[i])
		if id ~= 0 then
			have = have + self:CountOwned(id) + (plannedId[id] or 0)
		end
	end
	if have >= items then
		return
	end
	-- the base style the bank holds most of
	local bestId, bestCount = nil, 0
	for i = 1, #list do
		local id = self:StyleStoneId(list[i])
		if id ~= 0 then
			local count = 0
			for b = 1, #sources do
				local bag = sources[b]
				local slot = A.NextSlot(bag, nil)
				while slot do
					if GetItemId(bag, slot) == id then
						count = count + (GetSlotStackSize(bag, slot) or 0)
					end
					slot = A.NextSlot(bag, slot)
				end
			end
			if count > bestCount then
				bestId, bestCount = id, count
			end
		end
	end
	if bestId then
		self:TakeById(bestId, items - have)
	end
end

-- Step 2: the materials of a line still to be crafted (rec.left > 0) are added up in `wanted` first (two lines may use
-- the same material), then topped up once per item (PlanWanted).
local function Want(itemId, amount)
	if itemId and itemId ~= 0 and amount > 0 then
		wanted[itemId] = (wanted[itemId] or 0) + amount
	end
end

local allBags = {}
function A:PlanMaterials(rec)
	local ct, left = rec.craftType, rec.left
	if IsSmithingCraftingType and IsSmithingCraftingType(ct) then
		Want(rec.materialItemId, left * self.SMITH_MAT_PER_ITEM)
		if not (DoesSmithingTypeIgnoreStyleItems and DoesSmithingTypeIgnoreStyleItems(ct)) then
			styleItems = styleItems + left
		end
	elseif ct == CRAFTING_TYPE_ENCHANTING then
		local potency, essence, aspect = GetRunesForItemIdIfKnown(rec.itemId, rec.materialItemId, rec.quality)
		if potency and essence and aspect then
			Want(potency, left)
			Want(essence, left)
			Want(aspect, left)
		end
	elseif ct == CRAFTING_TYPE_ALCHEMY then
		local trait = GetTraitIdFromBasePotion(rec.itemId)
		if not trait or trait == 0 then
			return
		end
		-- look for a pair across the backpack, the craft bag and the bank together
		local craftBags = self:CraftBags()
		allBags[1], allBags[2] = craftBags[1], craftBags[2]
		local nb = 2
		for i = 1, #sources do
			nb = nb + 1
			allBags[nb] = sources[i]
		end
		local n, sb, ss = self:AlchemyCandidates(rec.itemId, rec.materialItemId, trait, allBags, nb)
		for i = nb + 1, #allBags do
			allBags[i] = nil
		end
		if not sb then
			return
		end
		local i, j = self:BestPair(n, sb, ss, rec.itemId)
		local yield = (GetAlchemyResultQuantity and GetAlchemyResultQuantity(sb, ss, 1)) or 1
		local iterations = math.ceil(left / math.max(1, yield))
		Want(GetItemId(sb, ss), iterations)
		if i then
			local r = self.reagentScratch
			Want(r.rid[i], iterations)
			Want(r.rid[j], iterations)
		end
	elseif ct == CRAFTING_TYPE_PROVISIONING then
		local _, list, index = GetRecipeInfoFromItemId(rec.itemId)
		if not (list and index) then
			return
		end
		local yield = (GetRecipeResultQuantity and GetRecipeResultQuantity(list, index, 1)) or 1
		local iterations = math.ceil(left / math.max(1, yield))
		local numIngredients = select(3, GetRecipeInfo(list, index)) or 0
		for k = 1, numIngredients do
			local link = GetRecipeIngredientItemLink(list, index, k, LINK_STYLE_DEFAULT)
			local per = select(3, GetRecipeIngredientItemInfo(list, index, k)) or 1
			Want(link and GetItemLinkItemId(link) or 0, per * iterations)
		end
	end
end

function A:PlanWanted()
	for itemId, amount in pairs(wanted) do
		self:TopUp(itemId, amount)
	end
	if styleItems > 0 then
		self:PlanStyle(styleItems)
	end
	Clear(wanted)
	styleItems = 0
end

-- ---------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------

function A:OnOpenBank(bankBag)
	if not self.sv.bank then
		return
	end
	Clear(sources)
	sources[1] = bankBag
	if bankBag == BAG_BANK and BAG_SUBSCRIBER_BANK then
		sources[2] = BAG_SUBSCRIBER_BANK
	end
	Q.fromBank = true
	self:Scan()
	for i = 1, self.lineCount do
		local rec = self.lines[i]
		rec.left = 0
		if self:LineEnabled(rec) then
			self:PlanFinished(rec)
		end
	end
	if self.sv.bankMaterials then
		Clear(wanted)
		styleItems = 0
		for i = 1, self.lineCount do
			local rec = self.lines[i]
			-- either kind of line (see Writs.lua); an "acquire" line for a rune or reagent has no recipe, so nothing is
			-- planned for it here
			if rec.left > 0 and self:CraftEnabled(rec.craftType) then
				self:PlanMaterials(rec)
			end
		end
		self:PlanWanted()
	end
	-- the craft bag too: "acquire" items
	self:PullFromCraftBag(true)
	self:StartMoves()
end

function A:OnCloseBank()
	if Q.fromBank then
		self:StopMoves()
	end
end

-- "Acquire" lines whose item is in the craft bag: move it to the backpack. At the bank this only adds to the plan
-- (planOnly: what the bank already covers is not taken twice, rec.left says what is still missing).
function A:PullFromCraftBag(planOnly)
	if not (HasCraftBagAccess and HasCraftBagAccess() and BAG_VIRTUAL) then
		return
	end
	if not planOnly then
		self:Scan()
	end
	Clear(sources)
	sources[1] = BAG_VIRTUAL
	for i = 1, self.lineCount do
		local rec = self.lines[i]
		if rec.kind == "gather" and self:LineEnabled(rec) then
			local need = rec.need
			if planOnly and rec.left then
				need = rec.left
			end
			if need > 0 then
				local saved = rec.need
				rec.need = need
				self:PlanFinished(rec)
				rec.need = saved
			end
		end
	end
	if not planOnly then
		self:StartMoves()
	end
end

-- ---------------------------------------------------------------------------------------
-- Carrying the plan out
-- ---------------------------------------------------------------------------------------

function A:StartMoves()
	if self:QueuedMoves() > 0 then
		self:Later("move", self.MOVE_GAP_MS, "MoveStep")
	end
end

function A:StopMoves()
	self:Cancel("move")
	Q.head, Q.tail = 1, 0
	self:MoveSummary()
	Clear(planned)
	Clear(plannedId)
	Clear(reserved)
	Q.fromBank = false
end

local function FreeSlot()
	local size = GetBagSize(BAG_BACKPACK) or 0
	for slot = 0, size - 1 do
		if not reserved[slot] and (GetSlotStackSize(BAG_BACKPACK, slot) or 0) == 0 then
			return slot
		end
	end
	return nil
end

function A:MoveStep()
	if Q.head > Q.tail then
		self:StopMoves()
		return
	end
	local h = Q.head
	local bag, slot, count, itemId = qBag[h], qSlot[h], qCount[h], qId[h]
	qBag[h], qSlot[h], qCount[h], qId[h] = nil, nil, nil, nil
	Q.head = h + 1
	if Q.stacks >= self.MOVE_LIMIT then
		Q.why = S.moveLimit
		self:StopMoves()
		return
	end
	-- the slot may have changed since the plan (the player moved something)
	local now = GetSlotStackSize(bag, slot) or 0
	if GetItemId(bag, slot) == itemId and now > 0 then
		count = math.min(count, now)
		local dest = FreeSlot()
		if not dest then
			Q.why = S.bankFull
			self:StopMoves()
			return
		end
		local ok, why = self:Call("move", "RequestMoveItem", bag, slot, BAG_BACKPACK, dest, count)
		if ok then
			reserved[dest] = true
			Q.stacks, Q.items = Q.stacks + 1, Q.items + count
			self.stats.moved = self.stats.moved + 1
		else
			Q.failed = Q.failed + 1
			Q.why = why
			self.stats.moveFailed = self.stats.moveFailed + 1
			-- a refused route refuses every move: stop
			self:StopMoves()
			return
		end
	end
	if Q.head > Q.tail then
		self:StopMoves()
	else
		self:Later("move", self.MOVE_GAP_MS, "MoveStep")
	end
end

function A:MoveSummary()
	if Q.items > 0 then
		self:Print(S.moved, Q.items, Q.stacks)
	end
	if Q.why then
		self:Notice("move", S.moveStopped, Q.why)
	end
	Q.items, Q.stacks, Q.failed, Q.why = 0, 0, 0, nil
end

PBS_CA_MARK("Bank")
