-- Putting a saved set back on.
--
-- Gear goes first, one request at a time: the item a request moves changes the backpack, so the next step is
-- worked out again from what is worn now and not from a plan made at the start. A step is finished when the
-- worn slot shows the item (or the slot is empty, for an unequip); one that has not finished after
-- STEP_TIMEOUT_MS is recorded as failed and left alone.
--
-- Skills go second, as one allocation request, the same four calls the client's own skills screen makes when
-- it applies a change (Prepare, one AddHotbarSlotChange per slot, Send). The result is read back from the bar.
--
-- The first request of a load is made from the caller's own context (the wheel's button release, the
-- settings button); the rest run from a short update loop that exists only while a load is in progress.

local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS
local em = EVENT_MANAGER

local JOB = A.name .. "Job"
local POLL_MS = 100
local STEP_TIMEOUT_MS = 3000
local SKILL_TIMEOUT_MS = 5000
local JOB_LIFETIME_MS = 30000
local MAX_GEAR_STEPS = 40

local function Now()
	return GetGameTimeMilliseconds()
end

local function Join(list)
	return table.concat(list, ", ")
end

-- ---------------------------------------------------------------------------------------
-- Gear
-- ---------------------------------------------------------------------------------------

-- Is the saved item already worn in this slot?
function A:InPlace(def, want)
	return GetWornItemInfo(BAG_WORN, def.slot) and self:Matches(def, want, BAG_WORN, def.slot)
end

function A:FindInBackpack(def, want)
	for index = 0, GetBagSize(BAG_BACKPACK) - 1 do
		if GetSlotStackSize(BAG_BACKPACK, index) > 0 and self:Matches(def, want, BAG_BACKPACK, index) then
			return BAG_BACKPACK, index
		end
	end
	return nil
end

-- The saved item may be worn in another slot (a ring on the wrong hand, a weapon on the other bar): that
-- slot is emptied first, because an item can only be equipped from the backpack.
function A:FindWorn(def, want)
	for _, other in ipairs(self.GEAR) do
		if other.slot and other.slot ~= def.slot and GetWornItemInfo(BAG_WORN, other.slot) and self:Matches(def, want, BAG_WORN, other.slot) then
			return other
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- The Mythic rule
--
-- Only one Mythic item (a "秘術アイテム" in the Japanese client) can be worn at a time: the client's text is
-- SI_INVENTORY_ERROR_ONLY_ONE_MYTHIC, and a refused equip raises EVENT_INVENTORY_EQUIP_MYTHIC_FAILED with the
-- worn slot that is in the way. Putting a set on in the order of its slots therefore fails whenever the Mythic
-- piece comes before the slot that holds the old one (a necklace is put on before the rings, say): the request
-- is refused, waits out its timeout and is recorded as failed, and the old Mythic piece only comes off later.
--
-- So before a Mythic item is equipped, the Mythic item that is worn elsewhere is taken care of first: its
-- own slot gets what the set wants there (which replaces it), or the piece is taken off. And when the client
-- says no anyway (the quality could not be read, or it refuses a swap in the same slot), the refusal is read
-- and the blocker is cleared the same way, a few times at most.
-- ---------------------------------------------------------------------------------------

function A:IsMythic(bag, index)
	local mythic = ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
	if type(mythic) ~= "number" or type(GetItemDisplayQuality) ~= "function" then
		return false
	end
	local ok, quality = pcall(GetItemDisplayQuality, bag, index)
	return ok and quality == mythic
end

-- The definition of a worn slot that holds a Mythic item, or nil. The slot of `def` itself counts only when
-- `includeOwn` is set (a swap in the same slot is the client's to allow). `job.mythicWorn` holds the slots the
-- client named in a refusal.
function A:WornMythic(job, def, includeOwn)
	for _, other in ipairs(self.GEAR) do
		if other.slot and (includeOwn or other.slot ~= def.slot) and GetWornItemInfo(BAG_WORN, other.slot) then
			if self:IsMythic(BAG_WORN, other.slot) or job.mythicWorn[other.slot] then
				return other
			end
		end
	end
	return nil
end

-- If the item about to be equipped in `def` is Mythic and another Mythic item is in the way, the request that
-- clears the way; otherwise nil.
function A:MythicBlocker(job, def, bag, index)
	if not (job.mythicIncoming[def.key] or self:IsMythic(bag, index)) then
		return nil
	end
	local blocker = self:WornMythic(job, def, job.mythicForce[def.key])
	if not blocker or job.failed[blocker.key] then
		return nil
	end
	local worn = A.Plain(SI_TOOLTIP_ITEM_NAME, GetItemName(BAG_WORN, blocker.slot))
	-- what the set wants in that slot, if it is in the backpack and is not itself Mythic: equipping it replaces the piece
	local want = (job.set.gear or {})[blocker.key]
	if want and self:InPlace(blocker, want) then
		-- the set itself asks for this piece to stay (two Mythic pieces in one set): nothing to clear
		return nil
	end
	if want and blocker.slot ~= def.slot and not job.missing[blocker.key] then
		local wbag, windex = self:FindInBackpack(blocker, want)
		if wbag and not self:IsMythic(wbag, windex) then
			return { kind = "equip", key = blocker.key, name = want.name, slot = blocker.slot, def = blocker, want = want, bag = wbag, index = windex, makeRoom = true }
		end
	end
	job.mythicOff[#job.mythicOff + 1] = worn
	return { kind = "unequip", key = blocker.key, name = worn, slot = blocker.slot, oldUid = self:WornUid(blocker.slot), makeRoom = true }
end

-- The client refused an equip because of the Mythic rule: clear whatever Mythic item is worn (the one in the
-- same slot too) and try the request again, at most twice. Returns false when it has given up.
function A:OnMythicRefused(job, op)
	local tries = (job.mythicTries[op.key] or 0) + 1
	job.mythicTries[op.key] = tries
	if tries > 2 then
		job.failed[op.key] = S.mythicRefused
		return false
	end
	job.mythicIncoming[op.key] = true
	job.mythicForce[op.key] = true
	return true
end

-- The next request to make, or nil when every slot is as the set says (or cannot be made so).
function A:NextGearOp(job)
	local gear = job.set.gear or {}
	for _, def in ipairs(self.GEAR) do
		if def.slot and not job.failed[def.key] and not job.missing[def.key] then
			local want = gear[def.key]
			if want then
				if not self:InPlace(def, want) then
					local bag, index = self:FindInBackpack(def, want)
					if bag then
						local makeRoom = self:MythicBlocker(job, def, bag, index)
						if makeRoom then
							return makeRoom
						end
						return { kind = "equip", key = def.key, name = want.name, slot = def.slot, def = def, want = want, bag = bag, index = index }
					end
					local other = self:FindWorn(def, want)
					if other then
						return { kind = "unequip", key = def.key, name = want.name, slot = other.slot, oldUid = self:WornUid(other.slot) }
					end
					job.missing[def.key] = want.name
				end
			elseif self.sv.unequipEmpty and not job.cleared[def.key] and GetWornItemInfo(BAG_WORN, def.slot) then
				job.cleared[def.key] = true
				return { kind = "unequip", key = def.key, name = def.key, slot = def.slot, oldUid = self:WornUid(def.slot), clear = true }
			end
		end
	end
	return nil
end

function A:OpDone(op)
	if op.kind == "equip" then
		return GetWornItemInfo(BAG_WORN, op.slot) and self:Matches(op.def, op.want, BAG_WORN, op.slot) or false
	end
	return self:WornUid(op.slot) ~= op.oldUid
end

-- Make the request. True when it was made; false when it could not be (the slot is then marked failed so it is
-- not tried again); "replan" when the plan has to be made again first (the Mythic rule).
function A:IssueOp(job, op)
	op.at = Now()
	if op.kind == "equip" then
		-- the client's own check before it equips; a query, but asked about first like the rest
		if self:Allowed("IsEquipable") then
			local ok, canEquip, errorId = pcall(IsEquipable, op.bag, op.index)
			if ok and canEquip == false then
				local mythicText = type(SI_INVENTORY_ERROR_ONLY_ONE_MYTHIC) == "number" and errorId == SI_INVENTORY_ERROR_ONLY_ONE_MYTHIC
				if (mythicText or self:IsMythic(op.bag, op.index)) and not job.mythicForce[op.key] and self:WornMythic(job, op.def, true) then
					if self:OnMythicRefused(job, op) then
						return "replan"
					end
					return false
				end
				local text = type(errorId) == "number" and GetString(errorId) or ""
				job.failed[op.key] = text ~= "" and text or S.cannotEquip
				return false
			end
		end
		local ok, err = self:Call("equip", "RequestEquipItem", op.bag, op.index, BAG_WORN, op.slot)
		if not ok then
			job.failed[op.key] = tostring(err or S.cannotEquip)
			job.gearBlocked = true
			return false
		end
	else
		local ok, err = self:Call("equip", "RequestUnequipItem", BAG_WORN, op.slot)
		if not ok then
			job.failed[op.key] = tostring(err or S.cannotEquip)
			job.gearBlocked = true
			return false
		end
	end
	return true
end

function A:GearTick(job)
	local op = job.op
	if op then
		if self:OpDone(op) then
			-- a slot is settled once its item is on, or once it has been emptied on purpose (the progress bar counts these)
			if op.kind == "equip" or op.clear then
				job.resolved[op.key] = true
			end
			job.op = nil
		elseif job.mythicRefused and op.kind == "equip" then
			-- the client said "only one Mythic item": do not wait out the timeout, clear the way and plan again
			job.mythicRefused = nil
			job.op = nil
			self:OnMythicRefused(job, op)
		elseif Now() - op.at > STEP_TIMEOUT_MS then
			job.failed[op.key] = S.noAnswer
			job.op = nil
		else
			return
		end
	end
	while true do
		if job.steps >= MAX_GEAR_STEPS then
			job.gearCut = true
			job.stage = "skills"
			return
		end
		local nextOp = self:NextGearOp(job)
		if not nextOp then
			job.stage = "skills"
			return
		end
		job.steps = job.steps + 1
		local issued = self:IssueOp(job, nextOp)
		if issued == true then
			job.op = nextOp
			return
		end
		if issued ~= "replan" and job.gearBlocked then
			job.stage = "skills"
			return
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Skills
-- ---------------------------------------------------------------------------------------

function A:SkillSlotRange()
	local first, last = 3, 8
	if GetAssignableAbilityBarStartAndEndSlots then
		local a, b = GetAssignableAbilityBarStartAndEndSlots()
		if type(a) == "number" and type(b) == "number" then
			first, last = a, b
		end
	end
	return first, last
end

-- Does this effective ability id (what a bar slot holds) belong to the skill, whatever morph it is at?
function A:HoldsSkill(effectiveId, skill)
	local manager = SKILLS_DATA_MANAGER
	if type(manager) ~= "table" or not skill then
		return false
	end
	local ok, same = pcall(function()
		local progression = manager:GetProgressionDataByAbilityId(effectiveId)
		return progression ~= nil and progression:GetSkillData() == skill
	end)
	return ok and same == true
end

-- A scribed skill: it can be slotted only once it has been scribed. Its scripts belong to the crafted ability,
-- not to the bar, and are changed at the scribing altar; here they are only compared.
function A:ResolveCrafted(entry)
	local info = {}
	if type(IsCraftedAbilityScribed) == "function" then
		local ok, scribed = pcall(IsCraftedAbilityScribed, entry.id)
		if ok and scribed == false then
			return nil, S.notScribed
		end
	end
	if entry.scripts then
		local now = self:ActiveScripts(entry.id)
		if now and (now[1] ~= entry.scripts[1] or now[2] ~= entry.scripts[2] or now[3] ~= entry.scripts[3]) then
			info.scriptsDiffer = true
		end
	end
	return entry.t, entry.id, info
end

-- The saved effective ability id -> the id the allocation request wants, which is the skill's current
-- progression (what ZO_SlottablePlayerSkill:GetActionId gives). Returns type, id and an info table; or nil and
-- the reason when the skill is not available now. info.morphDiffers: the skill is at another morph than when
-- it was saved, so the current one is what gets slotted (another morph needs a skill respec).
function A:ResolveSkill(entry)
	if entry.t == ACTION_TYPE_CRAFTED_ABILITY then
		return self:ResolveCrafted(entry)
	end
	if entry.t ~= ACTION_TYPE_ABILITY then
		return entry.t, entry.id, {}
	end
	local manager = SKILLS_DATA_MANAGER
	if type(manager) ~= "table" or type(manager.GetProgressionDataByAbilityId) ~= "function" then
		return entry.t, entry.id, {}
	end
	local ok, actionType, actionId, skill, differs = pcall(function()
		local progression = manager:GetProgressionDataByAbilityId(entry.id)
		if not progression then
			return entry.t, entry.id
		end
		local skillData = progression:GetSkillData()
		local allocator = skillData:GetPointAllocator()
		if allocator and not allocator:IsPurchased() then
			return nil
		end
		local currentId = skillData:GetPointAllocatorProgressionData():GetAbilityId()
		return ACTION_TYPE_ABILITY, currentId, skillData, entry.pid ~= nil and currentId ~= entry.pid
	end)
	if not ok then
		return entry.t, entry.id, {}
	end
	if actionType == nil then
		return nil, S.notPurchased
	end
	return actionType, actionId, { skill = skill, morphDiffers = differs == true }
end

-- The slot changes that turn the bars into the saved ones, the saved skills that cannot be slotted, and the
-- skills whose morph or scripts are not what they were (names, for the report).
function A:BuildSkillChanges(set)
	local changes, unavailable, notes = {}, {}, { morph = {}, scripts = {} }
	local first, last = self:SkillSlotRange()
	for _, bar in ipairs(self.BARS) do
		local saved = set.bars and set.bars[bar.key]
		if bar.cat and type(saved) == "table" then
			for slot = first, last do
				local entry = saved[slot]
				local currentType = GetSlotType(slot, bar.cat)
				local currentId = GetSlotBoundId(slot, bar.cat)
				if entry then
					local name = entry.name or tostring(entry.id)
					local same = currentType == entry.t and currentId == entry.id
					local actionType, actionId, info = self:ResolveSkill(entry)
					if not actionType then
						if not same then
							unavailable[#unavailable + 1] = name
						end
					else
						if info.scriptsDiffer then
							notes.scripts[#notes.scripts + 1] = name
						end
						if not same then
							local change = { cat = bar.cat, slot = slot, t = actionType, id = actionId, entry = entry }
							if info.morphDiffers then
								notes.morph[#notes.morph + 1] = name
								change.skill = info.skill
								-- the slot may already hold this skill at the morph it has now
								if currentType == ACTION_TYPE_ABILITY and self:HoldsSkill(currentId, info.skill) then
									change = nil
								end
							end
							if change then
								changes[#changes + 1] = change
							end
						end
					end
				elseif self.sv.clearSkills and currentType ~= ACTION_TYPE_NOTHING then
					changes[#changes + 1] = { cat = bar.cat, slot = slot, t = ACTION_TYPE_NOTHING, id = 0, clear = true }
				end
			end
		end
	end
	return changes, unavailable, notes
end

-- ---------------------------------------------------------------------------------------
-- Subclass and Class Mastery: only compared
--
-- A set remembers the active class skill lines and Class Mastery (Core.lua, ReadClassState): for the mastery the
-- lines, whether it is in effect, and the skills of the lines the character has learned (with a passive's rank and an
-- active's morph). They cannot be changed from the HUD, so a load only says when they are not what they were: skills
-- of a line that is not active now are the ones that then show up as "not available".
-- ---------------------------------------------------------------------------------------

local function IdKey(list)
	local ids = {}
	if type(list) == "table" then
		for _, entry in ipairs(list) do
			ids[#ids + 1] = tostring(type(entry) == "table" and entry.id or entry)
		end
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

local function NameList(list)
	local names = {}
	if type(list) == "table" then
		for _, entry in ipairs(list) do
			if type(entry) == "table" and entry.name then
				names[#names + 1] = entry.name
			end
		end
	end
	return names
end

local function LinesText(list)
	local names = NameList(list)
	return #names > 0 and Join(names) or S.noneText
end

-- One learned skill as the player reads it: the name, and for a passive that has ranks the rank it is at ("Name (2/3)").
local function MasterySkillLabel(skill)
	if skill.passive and (tonumber(skill.ranks) or 0) > 1 and tonumber(skill.rank) then
		return string.format(S.masterySkillRank, skill.name, skill.rank, skill.ranks)
	end
	return skill.name
end

-- What the mastery lines hold that the character has learned, as text; nil when no line says (a set saved before the
-- skills were recorded, or a client that could not read them), so that "nothing learned" can be said as such.
-- With several lines each skill list carries its line's name.
local function MasterySkillsText(state)
	local lines = state.mastery
	if type(lines) ~= "table" then
		return nil
	end
	local parts, recorded = {}, false
	for _, line in ipairs(lines) do
		if type(line.skills) == "table" then
			recorded = true
			local labels = {}
			for _, skill in ipairs(line.skills) do
				labels[#labels + 1] = MasterySkillLabel(skill)
			end
			local text = #labels > 0 and Join(labels) or S.masteryNoSkills
			if #lines > 1 then
				text = string.format(S.masteryLineSkills, tostring(line.name), text)
			end
			parts[#parts + 1] = text
		end
	end
	if not recorded then
		return nil
	end
	return table.concat(parts, S.masteryLineSeparator)
end

-- The mastery as the report names it: the lines, whether it is in effect, and what is learned ("Own Mastery (in
-- effect); learned: A, B (2/3)"). A set that did not record the skills says what it knows.
local function MasteryText(state)
	local names = NameList(state.mastery)
	if #names == 0 then
		return S.noneText
	end
	local text = string.format(state.masteryOn and S.masteryOn or S.masteryOff, Join(names))
	local skills = MasterySkillsText(state)
	if skills then
		text = string.format(S.masteryLearned, text, skills)
	end
	return text
end

-- The mastery as the preview's line says it: "Class Mastery (in effect): A, B (2/3)". The line's own name is left out
-- when there is only one (it is the character's class, which the window does not need to be told); a set that did not
-- record the skills shows the lines and the state, as before.
local function MasteryPreviewText(state)
	local names = NameList(state.mastery)
	if #names == 0 then
		return string.format(S.previewMastery, S.noneText)
	end
	local skills = MasterySkillsText(state)
	if not skills then
		return string.format(S.previewMastery, MasteryText(state))
	end
	return string.format(S.previewMasteryDetail, state.masteryOn and S.masteryStateOn or S.masteryStateOff, skills)
end

A.LinesText, A.MasteryText, A.MasteryPreviewText = LinesText, MasteryText, MasteryPreviewText

local function MasteryKey(state)
	local key = IdKey(state.mastery)
	if key ~= "" then
		key = key .. (state.masteryOn and "+" or "-")
	end
	return key
end

-- How many of the skills the set learned are not as learned now: gone, a lower rank (a passive) or another morph (an
-- active). A skill learned since the set was saved is not a difference: the set's own skills are all still there. A line
-- that did not record its skills (an older set) or cannot be read now says nothing.
local function MasterySkillsLost(saved, now)
	local nowById, readable = {}, {}
	for _, line in ipairs(type(now.mastery) == "table" and now.mastery or {}) do
		if type(line.skills) == "table" then
			readable[tostring(line.id)] = true
			for _, skill in ipairs(line.skills) do
				nowById[tostring(skill.id)] = skill
			end
		end
	end
	local lost = 0
	for _, line in ipairs(type(saved.mastery) == "table" and saved.mastery or {}) do
		if type(line.skills) == "table" and readable[tostring(line.id)] then
			for _, skill in ipairs(line.skills) do
				local current = nowById[tostring(skill.id)]
				if not current then
					lost = lost + 1
				elseif skill.passive then
					if (tonumber(current.rank) or 0) < (tonumber(skill.rank) or 0) then
						lost = lost + 1
					end
				elseif skill.morph ~= nil and current.morph ~= skill.morph then
					lost = lost + 1
				end
			end
		end
	end
	return lost
end

-- The report lines for a subclass or Class Mastery that differs from the set's, and nothing for a set saved before
-- this was recorded or a client that cannot say. The second result names what each line is about ("subclass",
-- "mastery"), in the same order.
function A:ClassStateNotes(set)
	local saved = set.class
	if type(saved) ~= "table" then
		return {}, {}
	end
	local now = self:ReadClassState()
	if not now then
		return {}, {}
	end
	local notes, kinds = {}, {}
	if IdKey(saved.lines) ~= IdKey(now.lines) then
		notes[#notes + 1] = string.format(S.reportSubclass, LinesText(saved.lines), LinesText(now.lines))
		kinds[#kinds + 1] = "subclass"
	end
	if MasteryKey(saved) ~= MasteryKey(now) or MasterySkillsLost(saved, now) > 0 then
		notes[#notes + 1] = string.format(S.reportMastery, MasteryText(saved), MasteryText(now))
		kinds[#kinds + 1] = "mastery"
	end
	return notes, kinds
end

-- ---------------------------------------------------------------------------------------
-- Mundus Stone: only compared
--
-- A set remembers which Mundus Stones were active (Core.lua, ReadMundusState). Nothing in the API sets one, so a
-- load only says when they are not what they were. A set saved with no stone has nothing to ask for, and a set
-- saved before this was recorded, or a client that cannot read the stones, is left alone.
-- ---------------------------------------------------------------------------------------

local function MundusKey(state)
	local ids = {}
	for _, entry in ipairs(type(state) == "table" and state.stones or {}) do
		ids[#ids + 1] = tostring(entry.type)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

-- "The Warrior, The Lover", or "none".
local function MundusText(state)
	local names = {}
	for _, entry in ipairs(type(state) == "table" and state.stones or {}) do
		names[#names + 1] = A.MundusName(entry)
	end
	return #names > 0 and Join(names) or S.noneText
end

A.MundusText = MundusText

-- The report line for a Mundus Stone that is not the saved one, or nil when it is (or there is nothing to compare).
function A:MundusNote(set)
	if not (self.sv and self.sv.mundus) then
		return nil
	end
	local saved = set.mundus
	if type(saved) ~= "table" or type(saved.stones) ~= "table" or #saved.stones == 0 then
		return nil
	end
	local now = self:ReadMundusState()
	if not now or MundusKey(saved) == MundusKey(now) then
		return nil
	end
	return string.format(S.reportMundus, MundusText(saved), MundusText(now))
end

function A:SkillsMatch(changes)
	for _, c in ipairs(changes) do
		local slotType, slotId = GetSlotType(c.slot, c.cat), GetSlotBoundId(c.slot, c.cat)
		local done
		if c.clear then
			done = slotType == ACTION_TYPE_NOTHING
		elseif c.skill then
			done = slotType == ACTION_TYPE_ABILITY and self:HoldsSkill(slotId, c.skill)
		else
			done = slotType == c.entry.t and slotId == c.entry.id
		end
		if not done then
			return false
		end
	end
	return true
end

-- Returns nil on success, or the reason the request could not be made.
function A:SendSkillChanges(changes)
	if IsActionBarRespeccable and not IsActionBarRespeccable() then
		local reason = GetActionBarLockedReason and GetActionBarLockedReason()
		if reason == ACTION_BAR_LOCKED_REASON_COMBAT then
			return S.inCombat
		end
		return S.barLocked
	end
	local ok, err = self:Call("skills", "PrepareSkillPointAllocationRequest", SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY, RESPEC_PAYMENT_TYPE_GOLD)
	if not ok then
		return tostring(err)
	end
	for _, c in ipairs(changes) do
		ok, err = self:Call("skills", "AddHotbarSlotChangeToAllocationRequest", c.slot, c.cat, c.t, c.id)
		if not ok then
			self:Call("skills", "CancelSkillPointAllocationRequest")
			return tostring(err)
		end
	end
	ok, err = self:Call("skills", "SendSkillPointAllocationRequest")
	if not ok then
		return tostring(err)
	end
	return nil
end

function A:SkillTick(job)
	if not job.skillStarted then
		job.skillStarted = Now()
		if not (self.sv.applySkills and job.set.bars) then
			job.stage = "champion"
			return
		end
		local changes, unavailable, notes = self:BuildSkillChanges(job.set)
		job.skillChanges, job.skillUnavailable, job.skillNotes = changes, unavailable, notes
		if #changes == 0 then
			job.stage = "champion"
			return
		end
		em:RegisterForEvent(JOB, EVENT_SKILL_RESPEC_RESULT, function(_, result)
			job.respec = result
		end)
		local why = self:SendSkillChanges(changes)
		if why then
			job.skillError = why
			job.stage = "champion"
		end
		return
	end
	if job.respec ~= nil or self:SkillsMatch(job.skillChanges) or Now() - job.skillStarted > SKILL_TIMEOUT_MS then
		job.stage = "champion"
	end
end

-- ---------------------------------------------------------------------------------------
-- Champion bar
--
-- Only which stars are slotted is changed, never how the points are spent: PrepareChampionPurchaseRequest(false)
-- ("no respec needed"), one AddHotbarSlotToChampionPurchaseRequest per changed slot, then Send, the calls
-- the client's champion screen makes when slots are the only thing that changed. The game's own check
-- (GetExpectedResultForChampionPurchaseRequest) is asked before sending, so a refusal (combat, the bar's
-- cooldown, a zone without champion points, the wrong constellation for a slot) comes back as its own text.
-- ---------------------------------------------------------------------------------------

function A:ChampionText(result)
	local text = ""
	if GetString then
		local ok, value = pcall(GetString, "SI_CHAMPIONPURCHASERESULT", result)
		if ok and type(value) == "string" then
			text = value
		end
	end
	if text == "" then
		text = string.format(S.championRefused, tostring(result))
	end
	return text
end

-- Has the character put points in this star? A star with none cannot be slotted.
function A:ChampionUsable(id)
	if not self:Allowed("GetNumPointsSpentOnChampionSkill") then
		return true
	end
	local ok, points = pcall(GetNumPointsSpentOnChampionSkill, id)
	return not ok or type(points) ~= "number" or points > 0
end

function A:BuildChampionChanges(set)
	local changes, unavailable = {}, {}
	local first, last = self:ChampionSlotRange()
	for slot = first, last do
		local saved = set.champion[slot]
		local currentId = self:ChampionAt(slot)
		if saved then
			if currentId ~= saved.id then
				if self:ChampionUsable(saved.id) then
					changes[#changes + 1] = { slot = slot, id = saved.id }
				else
					unavailable[#unavailable + 1] = saved.name or tostring(saved.id)
				end
			end
		elseif self.sv.clearSkills and currentId ~= 0 then
			changes[#changes + 1] = { slot = slot, id = 0 }
		end
	end
	return changes, unavailable
end

function A:ChampionMatch(changes)
	for _, c in ipairs(changes) do
		if self:ChampionAt(c.slot) ~= c.id then
			return false
		end
	end
	return true
end

-- Returns nil on success, or the reason the request could not be made.
function A:SendChampionChanges(changes)
	local success = CHAMPION_PURCHASE_SUCCESS
	if IsChampionSystemUnlocked and not IsChampionSystemUnlocked() then
		return S.championLocked
	end
	if success ~= nil and self:Allowed("GetChampionPurchaseAvailability") then
		local ok, result = pcall(GetChampionPurchaseAvailability)
		if ok and result ~= success then
			return self:ChampionText(result)
		end
	end
	local ok, err = self:Call("champion", "PrepareChampionPurchaseRequest", false)
	if not ok then
		return tostring(err)
	end
	for _, c in ipairs(changes) do
		ok, err = self:Call("champion", "AddHotbarSlotToChampionPurchaseRequest", c.slot, c.id)
		if not ok then
			return tostring(err)
		end
	end
	if success ~= nil and self:Allowed("GetExpectedResultForChampionPurchaseRequest") then
		local okExpected, result = pcall(GetExpectedResultForChampionPurchaseRequest)
		if okExpected and result ~= success then
			return self:ChampionText(result)
		end
	end
	ok, err = self:Call("champion", "SendChampionPurchaseRequest")
	if not ok then
		return tostring(err)
	end
	return nil
end

function A:ChampionTick(job)
	if not job.champStarted then
		job.champStarted = Now()
		if not (self.sv.applyChampion and job.set.champion) then
			self:EndJob()
			return
		end
		local changes, unavailable = self:BuildChampionChanges(job.set)
		job.champChanges, job.champUnavailable = changes, unavailable
		if #changes == 0 then
			self:EndJob()
			return
		end
		if EVENT_CHAMPION_PURCHASE_RESULT then
			em:RegisterForEvent(JOB, EVENT_CHAMPION_PURCHASE_RESULT, function(_, result)
				job.champResult = result
			end)
		end
		local why = self:SendChampionChanges(changes)
		if why then
			job.champError = why
			self:EndJob()
		end
		return
	end
	if job.champResult ~= nil or self:ChampionMatch(job.champChanges) or Now() - job.champStarted > SKILL_TIMEOUT_MS then
		if job.champResult ~= nil and job.champResult ~= CHAMPION_PURCHASE_SUCCESS and not self:ChampionMatch(job.champChanges) then
			job.champError = self:ChampionText(job.champResult)
		end
		self:EndJob()
	end
end

-- ---------------------------------------------------------------------------------------
-- A load
-- ---------------------------------------------------------------------------------------

-- Why nothing may be changed now, or nil.
function A:CannotChange()
	if IsUnitInCombat and IsUnitInCombat("player") then
		return S.inCombat
	end
	if IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player") then
		return S.isDead
	end
	return nil
end

-- `fromPoll` is false for the first tick, which runs in the caller's own context (the wheel's button release, the
-- settings button), and true for the ticks of the update loop.
function A:JobTick(fromPoll)
	local job = self.job
	if not job then
		return
	end
	if Now() - job.started > JOB_LIFETIME_MS then
		job.timedOut = true
		self:EndJob()
		return
	end
	if job.stage == "gear" then
		self:GearTick(job)
	end
	if self.job == job and job.stage == "skills" then
		self:SkillTick(job)
	end
	if self.job == job and job.stage == "champion" then
		self:ChampionTick(job)
	end
	-- the progress bar is drawn from the update loop only, never from the caller's context, and a load that is over
	-- in its first tick never shows one
	if self.job == job and self.progress then
		self.progress:Tick(job, fromPoll == true)
	end
end

-- Put the set in this slot on. `source` only says where the request came from ("wheel", "settings", "command").
function A:Load(index, source)
	local set = self:GetSet(index)
	if not set then
		self:Print(S.slotIsEmpty, index)
		return false
	end
	if self.job then
		if Now() - self.job.started < JOB_LIFETIME_MS then
			self:Print(S.busy)
			return false
		end
		self:EndJob(true)
	end
	local why = self:CannotChange()
	if why then
		self:Print(why)
		return false
	end

	local job = {
		index = index,
		set = set,
		source = source,
		started = Now(),
		stage = (self.sv.applyGear and set.gear) and "gear" or "skills",
		steps = 0,
		missing = {},
		failed = {},
		cleared = {},
		resolved = {}, -- gear slots whose item is on (or that were emptied on purpose): what the progress bar counts
		-- the Mythic rule (see "The Mythic rule" above)
		mythicWorn = {}, -- worn slots the client named when it refused an equip
		mythicIncoming = {}, -- gear keys known to be Mythic although the quality could not be read
		mythicForce = {}, -- gear keys whose Mythic blocker includes the piece in their own slot
		mythicTries = {},
		mythicOff = {}, -- Mythic pieces that were taken off only to make room
	}
	-- What there is to do, counted before the first request changes anything (queries only). A plan that cannot be made
	-- just means no progress bar.
	local planned, plan = pcall(self.ProgressPlan, self, set)
	job.plan = planned and plan or {}
	self.job = job
	if EVENT_INVENTORY_EQUIP_MYTHIC_FAILED then
		em:RegisterForEvent(JOB, EVENT_INVENTORY_EQUIP_MYTHIC_FAILED, function(_, _, slotIndex)
			job.mythicRefused = true
			if type(slotIndex) == "number" then
				job.mythicWorn[slotIndex] = true
			end
		end)
	end
	self:Print(S.loading, set.name)
	self:JobTick()
	if self.job == job then
		em:RegisterForUpdate(JOB, POLL_MS, function()
			self:JobTick(true)
		end)
	end
	return true
end

function A:EndJob(silent)
	local job = self.job
	em:UnregisterForUpdate(JOB)
	em:UnregisterForEvent(JOB, EVENT_SKILL_RESPEC_RESULT)
	if EVENT_CHAMPION_PURCHASE_RESULT then
		em:UnregisterForEvent(JOB, EVENT_CHAMPION_PURCHASE_RESULT)
	end
	if EVENT_INVENTORY_EQUIP_MYTHIC_FAILED then
		em:UnregisterForEvent(JOB, EVENT_INVENTORY_EQUIP_MYTHIC_FAILED)
	end
	self.job = nil
	if job and not silent then
		local verdict = self:Report(job)
		if self.progress then
			self.progress:Finish(job, verdict)
		end
		self:PlayFinished(verdict)
	elseif job and self.progress then
		-- cut short (the player left the world, or an old load was swept aside): nothing to celebrate
		self.progress:Abort(job)
	end
end

-- The sound that says a load is over. The sound table is looked up by name and every name is guarded, so a client without
-- one of them simply plays the next, or nothing; the names were checked against the client's own soundids.lua.
-- ARMORY_RESTORE_SUCCESS is what the client plays when an Armory build has been put on, which is what this is.
local DONE_SOUNDS = { "ARMORY_RESTORE_SUCCESS", "ABILITY_SLOTTED", "DIALOG_ACCEPT" }
local FAILED_SOUNDS = { "GENERAL_ALERT_ERROR", "NEGATIVE_CLICK" }

function A:PlayFinished(verdict)
	if not (self.sv and self.sv.sound) then
		return
	end
	local failed = verdict ~= nil and verdict.other == "error"
	for _, severity in pairs(verdict and verdict.stages or {}) do
		if severity == "error" then
			failed = true
		end
	end
	local names = failed and FAILED_SOUNDS or DONE_SOUNDS
	if type(PlaySound) ~= "function" or type(SOUNDS) ~= "table" then
		return
	end
	for _, name in ipairs(names) do
		local id = SOUNDS[name]
		if id then
			pcall(PlaySound, id)
			self.lastSound = name
			return
		end
	end
end

-- Which stage of a load each reason belongs to, and the reasons that are only a notice (the set was put on as far as it
-- could be, but it is not quite what was saved). The progress bar colours its stages with this, and the finishing sound
-- is the "failed" one only when a stage has a reason that is not a notice.
local REASON_STAGE = {
	reasonMissing = "gear", reasonFailed = "gear", reasonCut = "gear", reasonGear = "gear",
	reasonSkillsError = "skills", reasonSkillsLeft = "skills", reasonSkillsNot = "skills", reasonMorph = "skills",
	reasonScripts = "skills", reasonSubclass = "skills", reasonMastery = "skills",
	reasonChampionError = "champion", reasonChampionLeft = "champion", reasonChampionNot = "champion",
}
-- A reason that belongs to none of the stages (the Mundus Stone is not something a load puts on): the verdict keeps its
-- severity in `other`, which colours the bar's title but none of its segments.
local OUTSIDE = { reasonMundus = true }
local NOTICE = { reasonMorph = true, reasonScripts = true, reasonSubclass = true, reasonMastery = true, reasonMundus = true }

-- What a load did, as one block: the headline, then (when something is wrong) ONE line naming every reason, then one
-- detail line per reason. Every reason found is named -- gear, skills, morph, subclass, Class Mastery and the
-- champion bar are checked independently of one another, and a refusal in one place (the champion bar's wait,
-- say) never hides what was found in another.
--
-- Returns the verdict: { problems, count, stages = { gear = "error" | "warn", ... }, other = "error" | "warn" | nil }
-- (a stage without a reason is absent; `other` is for reasons that belong to no stage).
function A:Report(job)
	local set = job.set
	local lines = {}
	local reasons, seen = {}, {}
	local verdict = { stages = {} }
	-- each reason once, in the order found
	local function reason(key)
		if not seen[key] then
			seen[key] = true
			reasons[#reasons + 1] = S[key]
			local severity = NOTICE[key] and "warn" or "error"
			if OUTSIDE[key] then
				if severity == "error" or not verdict.other then
					verdict.other = severity
				end
			else
				-- a timeout belongs to the stage that was running
				local stage = REASON_STAGE[key] or job.stage
				if severity == "error" or not verdict.stages[stage] then
					verdict.stages[stage] = severity
				end
			end
		end
	end

	if self.sv.applyGear and set.gear then
		local total, placed = 0, 0
		for _, def in ipairs(self.GEAR) do
			local want = set.gear[def.key]
			if def.slot and want then
				total = total + 1
				if self:InPlace(def, want) then
					placed = placed + 1
				end
			end
		end
		lines[#lines + 1] = string.format(S.reportGear, placed, total)
		local missing, failed = {}, {}
		for _, def in ipairs(self.GEAR) do
			if job.missing[def.key] then
				missing[#missing + 1] = job.missing[def.key]
			end
			if job.failed[def.key] then
				failed[#failed + 1] = string.format("%s (%s)", set.gear[def.key] and set.gear[def.key].name or def.key, job.failed[def.key])
			end
		end
		if #missing > 0 then
			reason("reasonMissing")
			lines[#lines + 1] = string.format(S.reportMissing, Join(missing))
		end
		if #failed > 0 then
			reason("reasonFailed")
			lines[#lines + 1] = string.format(S.reportFailed, Join(failed))
		end
		if job.gearCut then
			reason("reasonCut")
			lines[#lines + 1] = S.reportCut
		end
		-- pieces still not in place with no cause recorded above
		if placed < total and #missing == 0 and #failed == 0 and not job.gearCut then
			reason("reasonGear")
		end
		if #job.mythicOff > 0 then
			lines[#lines + 1] = string.format(S.reportMythic, Join(job.mythicOff))
		end
	end

	if self.sv.applySkills and set.bars then
		if job.skillError then
			reason("reasonSkillsError")
			lines[#lines + 1] = string.format(S.reportSkillsError, job.skillError)
		elseif job.skillChanges and #job.skillChanges > 0 then
			local left = 0
			for _, c in ipairs(job.skillChanges) do
				if not self:SkillsMatch({ c }) then
					left = left + 1
				end
			end
			lines[#lines + 1] = string.format(S.reportSkills, #job.skillChanges - left, #job.skillChanges)
			if left > 0 then
				reason("reasonSkillsLeft")
			end
		else
			lines[#lines + 1] = S.reportSkillsSame
		end
		if job.skillUnavailable and #job.skillUnavailable > 0 then
			reason("reasonSkillsNot")
			lines[#lines + 1] = string.format(S.reportSkillsNot, Join(job.skillUnavailable))
		end
		local notes = job.skillNotes
		if notes and #notes.morph > 0 then
			reason("reasonMorph")
			lines[#lines + 1] = string.format(S.reportMorph, Join(notes.morph))
		end
		if notes and #notes.scripts > 0 then
			reason("reasonScripts")
			lines[#lines + 1] = string.format(S.reportScripts, Join(notes.scripts))
		end
		local classNotes, classKinds = self:ClassStateNotes(set)
		for i, line in ipairs(classNotes) do
			reason(classKinds[i] == "mastery" and "reasonMastery" or "reasonSubclass")
			lines[#lines + 1] = line
		end
	end

	if self.sv.applyChampion and set.champion then
		if job.champError then
			reason("reasonChampionError")
			lines[#lines + 1] = string.format(S.reportChampionError, job.champError)
		elseif job.champChanges and #job.champChanges > 0 then
			local left = 0
			for _, c in ipairs(job.champChanges) do
				if not self:ChampionMatch({ c }) then
					left = left + 1
				end
			end
			lines[#lines + 1] = string.format(S.reportChampion, #job.champChanges - left, #job.champChanges)
			if left > 0 then
				reason("reasonChampionLeft")
			end
		else
			lines[#lines + 1] = S.reportChampionSame
		end
		if job.champUnavailable and #job.champUnavailable > 0 then
			reason("reasonChampionNot")
			lines[#lines + 1] = string.format(S.reportChampionNot, Join(job.champUnavailable))
		end
	end

	-- the Mundus Stone is looked at whatever the load put on: it is a boon of the character, not part of any stage
	local mundusNote = self:MundusNote(set)
	if mundusNote then
		reason("reasonMundus")
		lines[#lines + 1] = mundusNote
	end

	if job.timedOut then
		reason("reasonTimeout")
		lines[#lines + 1] = S.reportTimeout
	end

	local problems = #reasons > 0
	local headline = string.format(problems and S.loadedProblems or S.loaded, set.name)
	local out = { headline }
	local summary
	if problems then
		summary = string.format(S.reportReasons, #reasons, table.concat(reasons, S.reasonSeparator))
		out[#out + 1] = summary
	end
	for _, line in ipairs(lines) do
		out[#out + 1] = line
	end
	self:PrintLines(out)
	-- one line on the screen, with every reason (a second alert straight after the first would replace it)
	self:Alert(summary and (headline .. " " .. summary) or headline)
	verdict.problems, verdict.count = problems, #reasons
	return verdict
end

-- A slot given as a number or as (part of) a set name.
function A:FindSlot(text)
	-- ASCII-only trimming and lower-casing: a class or lower() would ask the C library about the bytes of a Japanese name
	text = A.TrimAscii(text)
	local number = tonumber(text)
	if number and number >= 1 and number <= self.NUM_SLOTS and number == math.floor(number) then
		return number
	end
	if text ~= "" then
		local lower = A.LowerAscii(text)
		for i = 1, self.NUM_SLOTS do
			local set = self:GetSet(i)
			if set and A.LowerAscii(set.name) == lower then
				return i
			end
		end
		for i = 1, self.NUM_SLOTS do
			local set = self:GetSet(i)
			if set and A.LowerAscii(set.name):find(lower, 1, true) then
				return i
			end
		end
	end
	return nil
end
