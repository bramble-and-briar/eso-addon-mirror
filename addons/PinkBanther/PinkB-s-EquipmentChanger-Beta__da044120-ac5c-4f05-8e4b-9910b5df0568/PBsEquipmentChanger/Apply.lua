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
				return { kind = "unequip", key = def.key, name = def.key, slot = def.slot, oldUid = self:WornUid(def.slot) }
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

function A:JobTick()
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
		-- the Mythic rule (see "The Mythic rule" above)
		mythicWorn = {}, -- worn slots the client named when it refused an equip
		mythicIncoming = {}, -- gear keys known to be Mythic although the quality could not be read
		mythicForce = {}, -- gear keys whose Mythic blocker includes the piece in their own slot
		mythicTries = {},
		mythicOff = {}, -- Mythic pieces that were taken off only to make room
	}
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
			self:JobTick()
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
		self:Report(job)
	end
end

function A:Report(job)
	local set = job.set
	local lines, problems = {}, false

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
		if placed < total then
			problems = true
		end
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
			lines[#lines + 1] = string.format(S.reportMissing, Join(missing))
		end
		if #failed > 0 then
			lines[#lines + 1] = string.format(S.reportFailed, Join(failed))
		end
		if job.gearCut then
			lines[#lines + 1] = S.reportCut
		end
		if #job.mythicOff > 0 then
			lines[#lines + 1] = string.format(S.reportMythic, Join(job.mythicOff))
		end
	end

	if self.sv.applySkills and set.bars then
		if job.skillError then
			problems = true
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
				problems = true
			end
		else
			lines[#lines + 1] = S.reportSkillsSame
		end
		if job.skillUnavailable and #job.skillUnavailable > 0 then
			problems = true
			lines[#lines + 1] = string.format(S.reportSkillsNot, Join(job.skillUnavailable))
		end
		local notes = job.skillNotes
		if notes and #notes.morph > 0 then
			problems = true
			lines[#lines + 1] = string.format(S.reportMorph, Join(notes.morph))
		end
		if notes and #notes.scripts > 0 then
			problems = true
			lines[#lines + 1] = string.format(S.reportScripts, Join(notes.scripts))
		end
	end

	if self.sv.applyChampion and set.champion then
		if job.champError then
			problems = true
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
				problems = true
			end
		else
			lines[#lines + 1] = S.reportChampionSame
		end
		if job.champUnavailable and #job.champUnavailable > 0 then
			problems = true
			lines[#lines + 1] = string.format(S.reportChampionNot, Join(job.champUnavailable))
		end
	end

	if job.timedOut then
		problems = true
		lines[#lines + 1] = S.reportTimeout
	end

	self:Print(problems and S.loadedProblems or S.loaded, set.name)
	for _, line in ipairs(lines) do
		self:Print(line)
	end
	self:Alert(string.format(problems and S.loadedProblems or S.loaded, set.name))
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
