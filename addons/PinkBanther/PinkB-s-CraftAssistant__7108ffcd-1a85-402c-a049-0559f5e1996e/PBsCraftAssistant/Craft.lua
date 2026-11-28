-- Crafting at the station.
--
-- When a station opens, the writ lines for that station are read from the journal, and each line becomes one craft
-- call that makes everything the line still needs (the game's multi-craft: numIterations). The next call is made
-- when the game reports the previous one finished (EVENT_CRAFT_COMPLETED / _FAILED). After the last line the writs are
-- read again and anything still missing gets another round; a line whose counter did not move since we crafted for
-- it is not crafted again (so a line the game does not count is never crafted twice).
--
-- How a line becomes a call -- the same helpers the game's own craft advisor uses, so nothing is looked up by name:
--   smithing     GetSmithingPatternInfoForItemId(item, material, craft) -> pattern, material index; the amount of
--                material is the pattern's own (GetSmithingPatternMaterialItemInfo); no trait (index 1); a style
--                stone chosen by PickStyle (jewelry has none)
--   enchanting   GetRunesForItemIdIfKnown(item, material, quality) -> the three rune item ids
--   alchemy      GetTraitIdFromBasePotion(item) -> the trait; the solvent is the one the game accepts for the line
--                (IsAlchemySolventForItemAndMaterialId); two reagents with that known trait whose result is the
--                wanted potion (GetAlchemyResultingItemIdIfKnown), the most plentiful such pair
--   provisioning GetRecipeInfoFromItemId(item) -> recipe list and index
-- Every call is checked with the matching GetMaxIterationsPossibleFor* first, so a call the game would refuse is
-- not made; the refusal reason is the game's own text (SI_TRADESKILLRESULT).

local A = PBS_CRAFT_ASSIST
local S = PBS_CRAFT_ASSIST_STRINGS

A.jobs = {} -- reused job records
A.craft = {
	station = nil, -- the open station's craft type, nil when none
	awaiting = nil, -- the job whose craft the game is working on
	round = 0,
	jobCount = 0,
	jobAt = 0,
	madeRound = 0, -- items made in this round
	made = 0, -- items made at this station visit
	printed = 0, -- ... of which the summary has told
	tried = {}, -- quest*100+cond -> the line's counter when we crafted for it
	reasons = {}, -- reasons a line could not be crafted, for the summary (reused)
	reasonCount = 0,
	-- for the panel (Panel.lua): what each line is doing, and what the add-on as a whole is doing
	lineState = {}, -- key -> "craft" | "made" | "fail" | "skip"
	lineReason = {}, -- key -> text
	state = nil, -- "start" | "off" | "autoOff" | "busy" | "crafting" | "done" | "partial" | "nothing"
	stateText = nil, -- the item being crafted
	stateCount = 0,
	-- what the first round found (status and panel)
	diagHere = 0, diagOther = 0, diagOff = 0,
	-- the last station event, as the game sent it (status)
	eventSkill = nil, eventMode = nil, eventAt = nil,
}

local function Clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

function A:SetCraftState(state, text, count)
	local c = self.craft
	c.state, c.stateText, c.stateCount = state, text, count or 0
	self:PanelRefresh()
end

local function ResultText(result)
	if result and GetString then
		local text = GetString("SI_TRADESKILLRESULT", result)
		if text and text ~= "" then
			return text
		end
	end
	return string.format(S.resultCode, tostring(result))
end
A.ResultText = ResultText

local function Job(n)
	local job = A.jobs[n]
	if not job then
		job = {}
		A.jobs[n] = job
	end
	return job
end

function A:AddReason(text)
	local c = self.craft
	for i = 1, c.reasonCount do
		if c.reasons[i] == text then
			return
		end
	end
	if c.reasonCount < 6 then
		c.reasonCount = c.reasonCount + 1
		c.reasons[c.reasonCount] = text
	end
end

-- ---------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------

function A:OnStationInteract(craftSkill, sameStation, craftMode)
	local c = self.craft
	c.station, c.awaiting, c.round, c.made, c.printed, c.reasonCount = craftSkill, nil, 0, 0, 0, 0
	c.eventSkill, c.eventMode, c.eventAt = craftSkill, craftMode, GetGameTimeMilliseconds()
	c.diagHere, c.diagOther, c.diagOff = 0, 0, 0
	Clear(c.tried)
	Clear(c.lineState)
	Clear(c.lineReason)
	if CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION and craftMode == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION then
		c.station = nil
		return
	end
	self:PanelShow()
	-- "acquire" lines whose item sits in the craft bag: bring it to the backpack (any station will do)
	self:PullFromCraftBag()
	if not self.sv.autoCraft then
		self:SetCraftState("autoOff")
		return
	end
	if not self:CraftEnabled(craftSkill) then
		self:SetCraftState("off")
		return
	end
	self:SetCraftState("start")
	self:Later("craft", self.START_DELAY_MS, "CraftRound")
end

function A:OnStationEnd()
	local c = self.craft
	self:Cancel("craft")
	if c.station and (c.made > c.printed or c.reasonCount > 0) then
		self:CraftSummary()
	end
	c.station, c.awaiting = nil, nil
	self:PanelHide()
end

function A:OnCraftCompleted()
	local c = self.craft
	local job = c.awaiting
	if not job then
		return
	end
	c.awaiting = nil
	c.madeRound = c.madeRound + job.items
	c.made = c.made + job.items
	c.lineState[job.key] = "made"
	self.stats.crafted = self.stats.crafted + job.items
	self.sv.totals.crafted = self.sv.totals.crafted + job.items
	self:PanelRefresh()
	if c.station then
		self:Later("craft", self.CHAIN_MS, "NextJob")
	end
end

function A:OnCraftFailed(result)
	local c = self.craft
	if not c.awaiting then
		return
	end
	local job = c.awaiting
	c.awaiting = nil
	self.stats.craftFailed = self.stats.craftFailed + 1
	local why = ResultText(result)
	c.lineState[job.key], c.lineReason[job.key] = "fail", why
	self:AddReason(why)
	self:PanelRefresh()
	if c.station then
		self:Later("craft", self.CHAIN_MS, "NextJob")
	end
end

-- ---------------------------------------------------------------------------------------
-- Rounds and jobs
-- ---------------------------------------------------------------------------------------

function A:CraftRound()
	local c = self.craft
	if not c.station then
		return
	end
	c.round = c.round + 1
	c.madeRound, c.jobAt = 0, 0
	local n, here, other, off = 0, 0, 0, 0
	self:Scan()
	for i = 1, self.lineCount do
		local rec = self.lines[i]
		if self:StationFor(rec) ~= c.station then
			other = other + 1
		elseif not self:CraftEnabled(rec.craftType) then
			off = off + 1
		else
			here = here + 1
			local key = rec.quest * 100 + rec.cond
			if c.tried[key] ~= nil and c.tried[key] >= rec.cur then
				-- crafted for already and the counter did not move: never twice
				c.lineState[key], c.lineReason[key] = "fail", S.reasonNoCount
				self:AddReason(S.reasonNoCount)
			elseif c.lineState[key] ~= "skip" then
				n = n + 1
				local job = Job(n)
				job.key, job.kind, job.itemId, job.materialItemId = key, rec.kind, rec.itemId, rec.materialItemId
				job.craftType, job.quality, job.need, job.cur = rec.craftType, rec.quality, rec.need, rec.cur
				job.items, job.name, job.text = 0, nil, rec.text
			end
		end
	end
	if c.round == 1 then
		c.diagHere, c.diagOther, c.diagOff = here, other, off
	end
	c.jobCount = n
	self:NextJob()
end

function A:NextJob()
	local c = self.craft
	if not c.station or c.awaiting then
		return
	end
	if IsAwaitingCraftingProcessResponse and IsAwaitingCraftingProcessResponse() then
		if c.state ~= "busy" then
			self:SetCraftState("busy")
		end
		self:Later("craft", self.BUSY_RETRY_MS, "NextJob")
		return
	end
	while c.jobAt < c.jobCount do
		c.jobAt = c.jobAt + 1
		local job = self.jobs[c.jobAt]
		local ok, why, notThisKind = self:StartJob(job)
		if ok then
			c.awaiting = job
			c.tried[job.key] = job.cur
			c.lineState[job.key] = "craft"
			self.stats.craftCalls = self.stats.craftCalls + 1
			-- the name of what the game will make (0.1.1 named the line's generic item id, which reads as the lowest
			-- material: "iron helmet" while a rubedite one was made)
			self:SetCraftState("crafting", job.name or job.text or self:ItemName(job.itemId), job.items)
			return
		end
		if notThisKind and job.kind == "gather" then
			-- an "acquire" line for something no station makes (a rune, a reagent): nothing to craft, nothing to say
			c.lineState[job.key], c.lineReason[job.key] = "skip", why
		else
			c.lineState[job.key], c.lineReason[job.key] = "fail", why
			if why then
				self:AddReason(why)
			end
		end
	end
	-- end of the round
	if c.madeRound > 0 and c.round < self.MAX_ROUNDS then
		self:Later("craft", self.RECHECK_MS, "CraftRound")
	else
		self:CraftDone()
	end
end

function A:CraftDone()
	local c = self.craft
	local failed = false
	for _, state in pairs(c.lineState) do
		if state == "fail" then
			failed = true
		end
	end
	if failed then
		self:SetCraftState("partial", nil, c.made)
	elseif c.made > 0 then
		self:SetCraftState("done", nil, c.made)
	else
		self:SetCraftState("nothing")
	end
	self:CraftSummary()
	if self.sv.autoExit and c.station and c.made > 0 and not failed and INTERACTION_CRAFT then
		-- leave only when nothing is left for this station
		self:Scan()
		for i = 1, self.lineCount do
			local rec = self.lines[i]
			if self:StationFor(rec) == c.station and c.lineState[rec.quest * 100 + rec.cond] ~= "skip" then
				return
			end
		end
		self:Try(EndInteraction, INTERACTION_CRAFT)
	end
end

function A:CraftSummary()
	local c = self.craft
	local name = (GetCraftingSkillName and c.station and GetCraftingSkillName(c.station)) or ""
	if c.made > c.printed then
		self:Print(S.crafted, c.made - c.printed, name)
		c.printed = c.made
	end
	for i = 1, c.reasonCount do
		self:Notice("craft" .. i, S.notCrafted, c.reasons[i])
	end
	c.reasonCount = 0
end

-- ---------------------------------------------------------------------------------------
-- One job = one craft call. Returns true when the call was made, or false and why not.
-- ---------------------------------------------------------------------------------------

function A:StartJob(job)
	local ct = job.craftType
	if IsSmithingCraftingType and IsSmithingCraftingType(ct) then
		return self:StartSmithing(job)
	elseif ct == CRAFTING_TYPE_ENCHANTING then
		return self:StartEnchanting(job)
	elseif ct == CRAFTING_TYPE_ALCHEMY then
		return self:StartAlchemy(job)
	elseif ct == CRAFTING_TYPE_PROVISIONING then
		return self:StartProvisioning(job)
	end
	return false, nil
end

-- The style for a smithing item: of the allowed styles the character knows for this pattern, the one with the most
-- stones. Returns the style id, or nil.
local function ConsiderStyle(styleId, universal, pattern, material, quantity, best, bestCount)
	if styleId and styleId > 0 and styleId ~= universal and IsSmithingStyleKnown(styleId, pattern) then
		local count = GetCurrentSmithingStyleItemCount(styleId) or 0
		if count > bestCount then
			if not CanSmithingStyleBeUsedOnPattern or CanSmithingStyleBeUsedOnPattern(styleId, pattern, material, quantity) then
				return styleId, count
			end
		end
	end
	return best, bestCount
end

function A:PickStyle(pattern, material, quantity)
	local best, bestCount = nil, 0
	local universal = GetUniversalStyleId and GetUniversalStyleId() or -1
	if self.sv.styleScope == "all" and GetNumValidItemStyles then
		for i = 1, GetNumValidItemStyles() do
			best, bestCount = ConsiderStyle(GetValidItemStyleId(i), universal, pattern, material, quantity, best, bestCount)
		end
	else
		for i = 1, #self.BASIC_STYLES do
			best, bestCount = ConsiderStyle(self.BASIC_STYLES[i], universal, pattern, material, quantity, best, bestCount)
		end
	end
	return best
end

function A:StartSmithing(job)
	local ct = job.craftType
	if CanSmithingSetPatternsBeCraftedHere and CanSmithingSetPatternsBeCraftedHere() then
		return false, S.reasonSetStation
	end
	local pattern, material = GetSmithingPatternInfoForItemId(job.itemId, job.materialItemId, ct)
	if not (pattern and material) then
		return false, S.reasonPattern, true
	end
	local quantity = select(3, GetSmithingPatternMaterialItemInfo(pattern, material))
	local style = nil
	if not (DoesSmithingTypeIgnoreStyleItems and DoesSmithingTypeIgnoreStyleItems(ct)) then
		style = self:PickStyle(pattern, material, quantity)
		if not style then
			return false, S.reasonStyle
		end
	end
	local trait = (ITEM_TRAIT_TYPE_NONE or 0) + 1
	local max, limit = GetMaxIterationsPossibleForSmithingItem(pattern, material, quantity, style, trait, false)
	local n = math.min(job.need, tonumber(max) or 0)
	if n < 1 then
		return false, ResultText(limit)
	end
	job.items = n
	job.name = self:LinkName(GetSmithingPatternResultLink and GetSmithingPatternResultLink(pattern, material, quantity, style, trait, LINK_STYLE_DEFAULT))
	local ok, err = self:Try(CraftSmithingItem, pattern, material, quantity, style, trait, false, n)
	return ok, (not ok) and tostring(err) or nil
end

function A:StartEnchanting(job)
	local potency, essence, aspect = GetRunesForItemIdIfKnown(job.itemId, job.materialItemId, job.quality)
	if not (potency and essence and aspect) then
		return false, S.reasonRunes, true
	end
	local pb, ps = self:FindItem(potency)
	local eb, es = self:FindItem(essence)
	local ab, as = self:FindItem(aspect)
	if not (pb and eb and ab) then
		return false, S.reasonRunesMissing
	end
	local max, limit = GetMaxIterationsPossibleForEnchantingItem(pb, ps, eb, es, ab, as)
	local n = math.min(job.need, tonumber(max) or 0)
	if n < 1 then
		return false, ResultText(limit)
	end
	job.items = n
	job.name = self:LinkName(GetEnchantingResultingItemLink and GetEnchantingResultingItemLink(pb, ps, eb, es, ab, as, LINK_STYLE_DEFAULT))
	local ok, err = self:Try(CraftEnchantingItem, pb, ps, eb, es, ab, as, n)
	return ok, (not ok) and tostring(err) or nil
end

-- reused scratch arrays for the reagent search
local rb, rs, rc, rid = {}, {}, {}, {}
local MAX_REAGENTS = 40

-- The solvent slot for a line, and the reagent slots that carry the trait (fills rb/rs/rc/rid; returns the count).
function A:AlchemyCandidates(itemId, materialItemId, trait, bags, bagCount)
	local sb, ss, sc = nil, nil, 0
	local n = 0
	for i = 1, bagCount do
		local bag = bags[i]
		if bag then
			local slot = A.NextSlot(bag, nil)
			while slot do
				local _, itemType = GetItemCraftingInfo(bag, slot)
				if itemType == ITEMTYPE_REAGENT then
					if n < MAX_REAGENTS and DoesAlchemyItemHaveKnownTrait(bag, slot, trait) then
						n = n + 1
						rb[n], rs[n], rc[n], rid[n] = bag, slot, GetSlotStackSize(bag, slot) or 0, GetItemId(bag, slot)
					end
				elseif itemType and IsAlchemySolvent and IsAlchemySolvent(itemType) and IsAlchemySolventForItemAndMaterialId(bag, slot, itemId, materialItemId) then
					local count = GetSlotStackSize(bag, slot) or 0
					if count > sc then
						sb, ss, sc = bag, slot, count
					end
				end
				slot = A.NextSlot(bag, slot)
			end
		end
	end
	return n, sb, ss, sc
end
A.reagentScratch = { rb = rb, rs = rs, rc = rc, rid = rid }

-- The best reagent pair for a solvent: indexes into the scratch arrays, or nil.
function A:BestPair(n, sb, ss, itemId)
	local bi, bj, best = nil, nil, 0
	for i = 1, n - 1 do
		for j = i + 1, n do
			if rid[i] ~= rid[j] then
				local result = GetAlchemyResultingItemIdIfKnown(sb, ss, rb[i], rs[i], rb[j], rs[j])
				if result == itemId then
					local score = math.min(rc[i], rc[j])
					if score > best then
						bi, bj, best = i, j, score
					end
				end
			end
		end
	end
	return bi, bj
end

function A:StartAlchemy(job)
	local trait = GetTraitIdFromBasePotion(job.itemId)
	if not trait or trait == 0 then
		return false, S.reasonPotion, true
	end
	local bags = self:CraftBags()
	local n, sb, ss = self:AlchemyCandidates(job.itemId, job.materialItemId, trait, bags, 2)
	if not sb then
		return false, S.reasonSolvent
	end
	local i, j = self:BestPair(n, sb, ss, job.itemId)
	if not i then
		return false, S.reasonReagents
	end
	local yield = (GetAlchemyResultQuantity and GetAlchemyResultQuantity(sb, ss, 1)) or 1
	if yield < 1 then
		yield = 1
	end
	local want = math.ceil(job.need / yield)
	local max, limit = GetMaxIterationsPossibleForAlchemyItem(sb, ss, rb[i], rs[i], rb[j], rs[j])
	local iterations = math.min(want, tonumber(max) or 0)
	if iterations < 1 then
		return false, ResultText(limit)
	end
	job.items = iterations * yield
	job.name = self:LinkName(GetAlchemyResultingItemLink and GetAlchemyResultingItemLink(sb, ss, rb[i], rs[i], rb[j], rs[j], nil, nil, LINK_STYLE_DEFAULT))
	local ok, err = self:Try(CraftAlchemyItem, sb, ss, rb[i], rs[i], rb[j], rs[j], nil, nil, iterations)
	return ok, (not ok) and tostring(err) or nil
end

function A:StartProvisioning(job)
	local _, list, index = GetRecipeInfoFromItemId(job.itemId)
	if not (list and index) then
		return false, S.reasonRecipe, true
	end
	local yield = (GetRecipeResultQuantity and GetRecipeResultQuantity(list, index, 1)) or 1
	if yield < 1 then
		yield = 1
	end
	local want = math.ceil(job.need / yield)
	local max, limit = GetMaxIterationsPossibleForRecipe(list, index)
	local iterations = math.min(want, tonumber(max) or 0)
	if iterations < 1 then
		return false, ResultText(limit)
	end
	job.items = iterations * yield
	job.name = self:LinkName(GetRecipeResultItemLink and GetRecipeResultItemLink(list, index, LINK_STYLE_DEFAULT))
	local ok, err = self:Try(CraftProvisionerItem, list, index, iterations)
	return ok, (not ok) and tostring(err) or nil
end

PBS_CA_MARK("Craft")
