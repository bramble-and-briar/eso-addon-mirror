BF.BuildAutomation = {}

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function Unpack(t)
    return unpack(t, 1, t.n or #t)
end

local function AddResult(results, area, ok, message)
    table.insert(results, { area = area, ok = ok, message = tostring(message or "") })
end

local function IsPrivate(name)
    if not IsPrivateFunction then return false end
    local ok, value = pcall(IsPrivateFunction, name)
    return ok and value == true
end

local function IsProtected(name)
    if not IsProtectedFunction then return false end
    local ok, value = pcall(IsProtectedFunction, name)
    return ok and value == true
end

local unsafeInsecureCalls = {
    SelectSlotAbility = true,
    SelectSlotItem = true,
    SelectSlotSimpleAction = true,
    ClearSlot = true,
    PickupAbility = true,
    PickupAbilityById = true,
    PickupAction = true,
    PlaceInActionBar = true,
}

function BF.BuildAutomation.SafeCall(functionName, ...)
    if unsafeInsecureCalls[functionName] then return false, functionName .. " is protected and unsafe from addon code" end
    if IsPrivate(functionName) then return false, functionName .. " is private" end
    local fn = _G[functionName]
    if type(fn) == "function" then
        local direct = Pack(pcall(fn, ...))
        if direct[1] then
            local returns = { n = direct.n - 1 }
            for i = 2, direct.n do returns[i - 1] = direct[i] end
            return true, Unpack(returns)
        end
        if not IsProtected(functionName) or not CallSecureProtected then return false, direct[2] end
    end
    if CallSecureProtected then
        local secure = Pack(pcall(CallSecureProtected, functionName, ...))
        if secure[1] and secure[2] == true then
            local returns = { n = secure.n - 2 }
            for i = 3, secure.n do returns[i - 2] = secure[i] end
            return true, Unpack(returns)
        end
        return false, secure[2] or secure[3] or "secure protected call failed"
    end
    return false, functionName .. " unavailable"
end

local function GetPaymentType()
    return RESPEC_PAYMENT_TYPE_GOLD or 0
end

local function GetSkillMode()
    return SKILL_POINT_ALLOCATION_MODE_FULL or SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY or 0
end

local function BuildChampionTargetMap(build)
    local target = {}
    for _, skill in ipairs(build.championSkills or {}) do
        if skill.championSkillId and skill.championSkillId ~= 0 then target[skill.championSkillId] = skill.points or 0 end
    end
    return target
end

local function NeedsChampionRespec(target)
    if not GetNumChampionDisciplines or not GetNumChampionDisciplineSkills or not GetChampionSkillId or not GetNumPointsSpentOnChampionSkill then return false end
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local championSkillId = GetChampionSkillId(disciplineIndex, skillIndex)
            local current = championSkillId and GetNumPointsSpentOnChampionSkill(championSkillId) or 0
            local wanted = target[championSkillId] or 0
            if current > wanted then return true end
        end
    end
    return false
end

function BF.BuildAutomation.ApplyChampionPoints(build, results)
    results = results or {}
    if not build then AddResult(results, "Champion", false, "No build selected") return results end
    if not IsChampionSystemUnlocked or not IsChampionSystemUnlocked() then AddResult(results, "Champion", false, "Champion system is locked") return results end
    local target = BuildChampionTargetMap(build)
    local hasTargets = next(target) ~= nil or #(build.championSlots or {}) > 0
    if not hasTargets then AddResult(results, "Champion", false, "No champion data recorded") return results end
    local ok, err = BF.BuildAutomation.SafeCall("PrepareChampionPurchaseRequest", NeedsChampionRespec(target))
    if not ok then AddResult(results, "Champion", false, err) return results end
    local addedSkills = 0
    for championSkillId, points in pairs(target) do
        local added, addErr = BF.BuildAutomation.SafeCall("AddSkillToChampionPurchaseRequest", championSkillId, points)
        if added then addedSkills = addedSkills + 1 else AddResult(results, "Champion", false, addErr) end
    end
    local addedSlots = 0
    for _, slot in ipairs(build.championSlots or {}) do
        if slot.slotIndex and slot.championSkillId and slot.championSkillId ~= 0 then
            local added, addErr = BF.BuildAutomation.SafeCall("AddHotbarSlotToChampionPurchaseRequest", slot.slotIndex, slot.championSkillId)
            if added then addedSlots = addedSlots + 1 else AddResult(results, "Champion", false, addErr) end
        end
    end
    local availability = GetChampionPurchaseAvailability and GetChampionPurchaseAvailability() or nil
    local sent, sendErr = BF.BuildAutomation.SafeCall("SendChampionPurchaseRequest")
    AddResult(results, "Champion", sent, sent and string.format("Queued %d CP allocations and %d CP slots", addedSkills, addedSlots) or tostring(sendErr or availability))
    return results
end

function BF.BuildAutomation.ApplyAttributes(build, results)
    results = results or {}
    if not build or not build.attributes then AddResult(results, "Attributes", false, "No attribute data recorded") return results end
    if not GetAttributeSpentPoints then AddResult(results, "Attributes", false, "Attribute API unavailable") return results end
    local target = build.attributes
    local currentHealth = GetAttributeSpentPoints(ATTRIBUTE_HEALTH) or 0
    local currentMagicka = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA) or 0
    local currentStamina = GetAttributeSpentPoints(ATTRIBUTE_STAMINA) or 0
    local healthDelta = (target.health or 0) - currentHealth
    local magickaDelta = (target.magicka or 0) - currentMagicka
    local staminaDelta = (target.stamina or 0) - currentStamina
    if healthDelta == 0 and magickaDelta == 0 and staminaDelta == 0 then AddResult(results, "Attributes", true, "Already matched") return results end
    local ok, err = BF.BuildAutomation.SafeCall("SendAttributePointAllocationRequest", GetPaymentType(), healthDelta, magickaDelta, staminaDelta)
    AddResult(results, "Attributes", ok, ok and string.format("Requested H %+d / M %+d / S %+d", healthDelta, magickaDelta, staminaDelta) or err)
    return results
end

function BF.BuildAutomation.ApplySkillBars(build, results)
    results = results or {}
    if not build or not build.skills or #build.skills == 0 then AddResult(results, "Skills", false, "No skill bar data recorded") return results end
    local prepared, prepErr = BF.BuildAutomation.SafeCall("PrepareSkillPointAllocationRequest", GetSkillMode(), GetPaymentType())
    local hotbarChanges = 0
    if prepared then
        for _, skill in ipairs(build.skills or {}) do
            if skill.slotIndex and skill.actionType and skill.actionId then
                local ok, err = BF.BuildAutomation.SafeCall("AddHotbarSlotChangeToAllocationRequest", skill.slotIndex, skill.hotbarCategory or HOTBAR_CATEGORY_PRIMARY, skill.actionType, skill.actionId)
                if ok then hotbarChanges = hotbarChanges + 1 else AddResult(results, "Skills", false, err) end
            end
        end
        local sent, sendErr = BF.BuildAutomation.SafeCall("SendSkillPointAllocationRequest")
        AddResult(results, "Skills", sent, sent and string.format("Requested %d hotbar slot changes", hotbarChanges) or sendErr)
    else
        AddResult(results, "Skills", false, prepErr)
    end
    local directSlots = 0
    for _, skill in ipairs(build.skills or {}) do
        if skill.skillType and skill.skillLineIndex and skill.skillIndex and skill.slotIndex then
            local ok = BF.BuildAutomation.SafeCall("SlotSkillAbilityInSlot", skill.skillType, skill.skillLineIndex, skill.skillIndex, skill.slotIndex)
            if ok then directSlots = directSlots + 1 end
        end
    end
    if directSlots > 0 then AddResult(results, "Skills", true, string.format("Attempted %d direct skill slots", directSlots)) end
    return results
end

function BF.BuildAutomation.ApplyArmorySave(build, results)
    results = results or {}
    if not build or not build.armoryBuildIndex then AddResult(results, "Armory", false, "No Armory slot recorded") return results end
    local ok, err = BF.BuildAutomation.SafeCall("SaveArmoryBuild", build.armoryBuildIndex)
    AddResult(results, "Armory", ok, ok and "Requested Armory save" or err)
    return results
end

function BF.BuildAutomation.ApplyAll(build)
    local results = {}
    if not build then BF.Chat("No build selected.") return results end
    if BF.BuildApplier then BF.BuildApplier.ApplyOwnedGear(build) end
    BF.BuildAutomation.ApplySkillBars(build, results)
    BF.BuildAutomation.ApplyChampionPoints(build, results)
    BF.BuildAutomation.ApplyAttributes(build, results)
    AddResult(results, "Mundus", false, "No non-private direct Mundus setter found; use a stone or Armory")
    BF.runtime.automationResults = results
    for _, result in ipairs(results) do
        BF.Chat(string.format("%s: %s - %s", result.area, result.ok and "OK" or "Check", result.message))
    end
    if BF.RefreshUI then BF.RefreshUI() end
    return results
end
