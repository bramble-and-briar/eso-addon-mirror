local Addon = LarvalTearMod
local Domains = Addon.Common.Domains
local Log = Addon.Common.Log
local SkillSettings = Addon.Common.SkillSettings
local Util = Addon.Common.Util
local LTM_ATTRIBUTE_SNAPSHOT = Addon.Modules.AttributeSnapshot
local LTM_BUILD_CODEC = Addon.Modules.BuildCodec
local LTM_PASSIVE_SNAPSHOT_APPLY = Addon.Modules.PassiveSnapshotApply
local LTM_ROLE_STATE = Addon.Modules.RoleState
local LTM_SKILL_SNAPSHOT_AUDIT = Addon.Modules.SkillSnapshotAudit
local LTM_SUBCLASS_NAME_HELPER = Addon.SubclassNameHelper
local LTM_SUBCLASS_SNAPSHOT = Addon.Modules.SubclassSnapshot
local LTM_TRANSFORM_SKILLS = Addon.Modules.TransformSkills
local LTM_BUILD_STORE = Addon.Modules.BuildStore

local DEFAULT_PAGE_ID = "page_default"
local MAX_RENAME_TEXT_UNITS = 18
local HOTBAR_CATEGORIES = Util.HOTBAR_CATEGORIES
local SLOT_INDICES = { 3, 4, 5, 6, 7, 8 }
local EQUIPMENT_SLOT_IDS = Domains.EquipmentSlotIds
local OVERWRITE_TYPES = {
    attributes = true,
    class_skills = true,
    equipment = true,
    cp = true,
    passives = true,
    transform_werewolf = true,
    transform_vampire = true,
    all = true,
}
-- Crypt Canon has ESO-specific ultimate behavior. Keep these exception IDs
-- close to the save/filter logic so the special slot handling is not removed
-- as an apparent magic-number cleanup.
local CRYPT_CANON_ITEM_ID = 194509
local CRYPT_CANON_SPECIAL_ULTIMATE_ID = 195031

local function CloneShallow(source)
    local clone = {}
    for key, value in pairs(source or {}) do
        clone[key] = value
    end
    return clone
end

local function GetStringValue(stringIdName, fallback)
    local stringId = type(stringIdName) == "string" and rawget(_G, stringIdName) or nil
    local value = type(GetString) == "function" and stringId ~= nil and GetString(stringId) or nil
    if type(value) == "string" and value ~= "" then
        return value
    end

    return fallback
end

local function GetDefaultPageName()
    return GetStringValue("SI_LTM_PAGE_DEFAULT_NAME", "Default")
end

local function BuildGeneratedPageName(index)
    if type(index) == "number" and index > 1 then
        local formatText = GetStringValue("SI_LTM_PAGE_GENERATED_NAME_WITH_INDEX", "New Page %d")
        return string.format(formatText, index)
    end

    return GetStringValue("SI_LTM_PAGE_GENERATED_NAME", "New Page")
end

local function CollectSortedStringKeys(entries)
    local keys = {}

    for key, value in pairs(entries or {}) do
        if type(key) == "string" and key ~= "" and type(value) == "table" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

local function CountTableEntries(entries)
    local count = 0
    for _ in pairs(entries or {}) do
        count = count + 1
    end
    return count
end

local function ResolveTimestamp()
    return type(GetTimeStamp) == "function" and GetTimeStamp() or 0
end

local function IsCryptCanonEquipped()
    return type(GetItemId) == "function"
        and GetItemId(BAG_WORN, EQUIP_SLOT_CHEST) == CRYPT_CANON_ITEM_ID
end

local function IsCryptCanonSpecialUltimateRecord(slotEntry, hotbarCategory, slotIndex)
    -- The Crypt Canon ultimate is equipment-derived, not a normal saved skill
    -- target. Treating it as a regular ultimate can produce restore mismatch.
    return type(slotEntry) == "table"
        and tonumber(slotEntry.abilityId) == CRYPT_CANON_SPECIAL_ULTIMATE_ID
        and slotIndex == SLOT_INDICES[#SLOT_INDICES]
end

local function NormalizeCharacterKey(characterId)
    if characterId == nil then
        return nil
    end

    return tostring(characterId)
end

local function NormalizeBuildName(name)
    if type(name) ~= "string" then
        return nil
    end

    if type(zo_strtrim) == "function" then
        name = zo_strtrim(name)
    else
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
    end

    if name == "" then
        return nil
    end

    return name
end

local function NormalizePageName(name)
    return NormalizeBuildName(name)
end

local function GetWeightedTextUnits(text)
    if type(text) ~= "string" or text == "" then
        return 0
    end

    local units = 0
    local index = 1
    local length = #text
    while index <= length do
        local byteValue = string.byte(text, index)
        if type(byteValue) ~= "number" then
            break
        end

        if byteValue < 128 then
            units = units + 1
            index = index + 1
        elseif byteValue >= 240 then
            units = units + 2
            index = index + 4
        elseif byteValue >= 224 then
            units = units + 2
            index = index + 3
        elseif byteValue >= 192 then
            units = units + 2
            index = index + 2
        else
            units = units + 2
            index = index + 1
        end
    end

    return units
end

local function NormalizeLimitedName(name)
    local normalizedName = NormalizeBuildName(name)
    if normalizedName == nil then
        return nil, "name_empty"
    end

    if GetWeightedTextUnits(normalizedName) > MAX_RENAME_TEXT_UNITS then
        return nil, "name_too_long"
    end

    return normalizedName
end

local function ResolveFallbackBuildId(sortedBuildIds, deletedIndex)
    if type(sortedBuildIds) ~= "table" or #sortedBuildIds == 0 then
        return nil
    end

    local fallbackIndex = deletedIndex
    if type(fallbackIndex) ~= "number" or fallbackIndex < 1 then
        fallbackIndex = 1
    end

    if fallbackIndex > #sortedBuildIds then
        fallbackIndex = #sortedBuildIds
    end

    return sortedBuildIds[fallbackIndex]
end

local function AppendUniqueString(targetList, seen, value)
    if type(value) ~= "string" or value == "" then
        return
    end

    if seen[value] then
        return
    end

    seen[value] = true
    targetList[#targetList + 1] = value
end

local function NormalizeOrder(orderList, actualEntries)
    actualEntries = type(actualEntries) == "table" and actualEntries or {}

    local normalizedOrder = {}
    local seenIds = {}

    for _, id in ipairs(orderList or {}) do
        if type(actualEntries[id]) == "table" then
            AppendUniqueString(normalizedOrder, seenIds, id)
        end
    end

    for _, id in ipairs(CollectSortedStringKeys(actualEntries)) do
        AppendUniqueString(normalizedOrder, seenIds, id)
    end

    return normalizedOrder, seenIds
end

local function ResolveForceChampionRespec(value)
    return value == true
end

local function ResolveOptionalLinkId(value)
    if type(value) ~= "string" or value == "" or value == "none" then
        return nil
    end

    return value
end

local function NormalizeChampionPointGroupShape(group)
    if type(group) ~= "table" then
        return
    end

    for key in pairs(group) do
        if type(key) == "number" then
            group[key] = nil
        end
    end

    group.disciplineId = nil
    group.disciplineType = nil
end

local function NormalizeClassMasteryShape(classMastery)
    if type(classMastery) ~= "table" then
        return nil
    end

    local targetSkillLineId = tonumber(classMastery.targetSkillLineId)
    if targetSkillLineId == nil or targetSkillLineId <= 0 then
        return nil
    end

    local normalized = {
        targetSkillLineId = math.floor(targetSkillLineId),
    }

    if classMastery.purchasedAbilities ~= nil then
        normalized.purchasedAbilities = {}
        if type(classMastery.purchasedAbilities) == "table" then
            for abilityId, rank in pairs(classMastery.purchasedAbilities) do
                local normalizedAbilityId = tonumber(abilityId)
                local normalizedRank = tonumber(rank)
                if normalizedAbilityId ~= nil and normalizedAbilityId > 0
                    and normalizedRank ~= nil and normalizedRank > 0 then
                    normalized.purchasedAbilities[math.floor(normalizedAbilityId)] = math.floor(normalizedRank)
                end
            end
        end
    end

    return normalized
end

local function NormalizeBuildCommonShape(build)
    build = type(build) == "table" and build or {}
    local displayName = NormalizeBuildName(build.displayName) or NormalizeBuildName(build.name)
    if displayName ~= nil then
        build.displayName = displayName
    end
    -- Keep SavedVariables focused on source data. Display/cache fields are
    -- rebuilt when needed instead of being persisted with each saved build.
    build.name = nil
    build.skillSettings = SkillSettings:NormalizeBuild(build.skillSettings)
    build.passivePolicy = nil
    build.spSaver = nil
    build.quickslotProfileId = ResolveOptionalLinkId(build.quickslotProfileId)
    build.foodCardId = ResolveOptionalLinkId(build.foodCardId)
    build.classMastery = NormalizeClassMasteryShape(build.classMastery)
    build.role = LTM_ROLE_STATE:NormalizeRoleState(build.role)
    if type(build.skills) == "table" and type(build.skills.slots) == "table" then
        for _, slotEntry in ipairs(build.skills.slots) do
            if type(slotEntry) == "table" then
                slotEntry.abilityName = nil
                slotEntry.iconTexture = nil
                slotEntry.isEmpty = nil
            end
        end
    end
    if type(build.championPoints) == "table" then
        for _, groupId in ipairs({ "warfare", "fitness", "craft" }) do
            local group = build.championPoints[groupId]
            NormalizeChampionPointGroupShape(group)
        end
    end
    if type(build.equipment) == "table" then
        for _, slotEntry in pairs(build.equipment) do
            if type(slotEntry) == "table" then
                slotEntry.traitName = nil
            end
        end
    end
    if type(build.outfit) == "table" then
        build.outfit.equippedOutfitName = nil
    end
    return build
end

local function EnsureRuntimeBuildShape(build)
    build = NormalizeBuildCommonShape(build)
    if build.passiveSnapshot ~= nil
        and (type(build.passiveSnapshot) ~= "table" or type(build.passiveSnapshot.lines) ~= "table") then
        build.passiveSnapshot = nil
    end
    return build
end

local function EnsurePersistentBuildShape(build)
    build = NormalizeBuildCommonShape(build)
    if build.passiveSnapshot ~= nil and type(build.passiveSnapshot) ~= "string" then
        build.passiveSnapshot = nil
    end
    return build
end

local function EncodeBuildForPersist(build)
    local persistentBuild, encodeResult = LTM_BUILD_CODEC:EncodeBuildForPersist(build)
    if type(encodeResult) == "table" and encodeResult.status ~= "success" then
        Log.LogDebugSummary(
            "Build persist encode failed",
            "status=" .. tostring(encodeResult.status),
            "reason=" .. tostring(type(encodeResult.errors) == "table" and encodeResult.errors[1] or "unknown")
        )
        return nil, encodeResult
    end

    return EnsurePersistentBuildShape(persistentBuild), encodeResult
end

local function DecodeBuildForRuntime(build)
    local runtimeBuild = LTM_BUILD_CODEC:DecodeBuildForRuntime(build)

    return EnsureRuntimeBuildShape(runtimeBuild)
end

local function StoreBuildForPersist(page, buildId, build)
    if type(page) ~= "table" or type(page.builds) ~= "table" or type(buildId) ~= "string" or buildId == "" then
        return nil
    end

    local persistentBuild, encodeResult = EncodeBuildForPersist(build)
    if type(persistentBuild) ~= "table" then
        return nil, encodeResult
    end
    page.builds[buildId] = persistentBuild
    return persistentBuild
end

local function NormalizePageBuildOrder(page)
    if type(page) ~= "table" then
        return {}
    end

    page.builds = type(page.builds) == "table" and page.builds or {}
    page.buildOrder = NormalizeOrder(page.buildOrder, page.builds)
    return page.buildOrder
end

local function BuildCopiedBuildName(baseName, copyIndex)
    if type(baseName) ~= "string" or baseName == "" then
        baseName = "Build"
    end

    if type(copyIndex) == "number" and copyIndex > 1 then
        return string.format("%s (Copy %d)", baseName, copyIndex)
    end

    return string.format("%s (Copy)", baseName)
end

local function InsertValueAfter(targetList, anchorValue, newValue)
    if type(targetList) ~= "table" then
        return false
    end

    local insertIndex = #targetList + 1
    for index, currentValue in ipairs(targetList) do
        if currentValue == anchorValue then
            insertIndex = index + 1
            break
        end
    end

    table.insert(targetList, insertIndex, newValue)
    return true
end

local function RemoveFirstValue(targetList, targetValue)
    if type(targetList) ~= "table" then
        return nil
    end

    for index, value in ipairs(targetList) do
        if value == targetValue then
            table.remove(targetList, index)
            return index
        end
    end

    return nil
end

local function ResolveCurrentCharacterKey()
    if type(GetCurrentCharacterId) ~= "function" then
        return nil
    end

    local ok, characterId = pcall(GetCurrentCharacterId)
    if not ok then
        return nil
    end

    return NormalizeCharacterKey(characterId)
end

local function ResolveCurrentSlotAbilityId(slotIndex, hotbarCategory)
    if type(ACTION_BAR_ASSIGNMENT_MANAGER) == "table"
        and type(ACTION_BAR_ASSIGNMENT_MANAGER.GetHotbar) == "function" then
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbarCategory)
        local slotData = type(hotbar) == "table" and type(hotbar.GetSlotData) == "function"
            and hotbar:GetSlotData(slotIndex)
            or nil

        if type(slotData) == "table" and type(slotData.GetEffectiveAbilityId) == "function" then
            local effectiveAbilityId = slotData:GetEffectiveAbilityId()
            if type(effectiveAbilityId) == "number" and effectiveAbilityId > 0 then
                return effectiveAbilityId
            end
        end
    end

    if type(GetSlotType) == "function" and type(GetSlotBoundId) == "function" then
        local actionType = GetSlotType(slotIndex, hotbarCategory)
        local boundId = GetSlotBoundId(slotIndex, hotbarCategory)
        if actionType == ACTION_TYPE_ABILITY and type(boundId) == "number" and boundId > 0 then
            return boundId
        end
    end

    return nil
end

local function IsSupportedHotbarCategory(hotbarCategory)
    for _, supportedCategory in ipairs(HOTBAR_CATEGORIES) do
        if hotbarCategory == supportedCategory then
            return true
        end
    end

    return false
end

local function IsSupportedSkillSlotIndex(slotIndex)
    for _, supportedSlotIndex in ipairs(SLOT_INDICES) do
        if slotIndex == supportedSlotIndex then
            return true
        end
    end

    return false
end

local function FindSavedSkillSlotRecordIndex(slots, hotbarCategory, slotIndex)
    if type(slots) ~= "table" then
        return nil
    end

    for index, entry in ipairs(slots) do
        if type(entry) == "table"
            and tonumber(entry.hotbarCategory) == hotbarCategory
            and tonumber(entry.slot or entry.slotIndex) == slotIndex then
            return index
        end
    end

    return nil
end

local function SortSavedSkillSlots(slots)
    if type(slots) ~= "table" then
        return
    end

    table.sort(slots, function(left, right)
        local leftHotbarCategory = type(left) == "table" and tonumber(left.hotbarCategory) or 0
        local rightHotbarCategory = type(right) == "table" and tonumber(right.hotbarCategory) or 0
        if leftHotbarCategory == rightHotbarCategory then
            local leftSlotIndex = type(left) == "table" and tonumber(left.slot or left.slotIndex) or 0
            local rightSlotIndex = type(right) == "table" and tonumber(right.slot or right.slotIndex) or 0
            return leftSlotIndex < rightSlotIndex
        end

        return leftHotbarCategory < rightHotbarCategory
    end)
end

local function NormalizeCraftedScriptIds(primaryScriptId, secondaryScriptId, tertiaryScriptId)
    local scriptIds = {}
    local ids = { primaryScriptId, secondaryScriptId, tertiaryScriptId }
    local hasValue = false

    for index = 1, 3 do
        local scriptId = tonumber(ids[index])
        if scriptId ~= nil and scriptId > 0 then
            scriptIds[index] = math.floor(scriptId)
            hasValue = true
        else
            scriptIds[index] = 0
        end
    end

    if hasValue then
        return scriptIds
    end

    return nil
end

local function ResolveCraftedAbilityScriptIds(craftedAbilityId)
    if type(craftedAbilityId) ~= "number" or craftedAbilityId <= 0 then
        return nil
    end

    if type(GetCraftedAbilityActiveScriptIds) ~= "function" then
        return nil
    end

    local ok, primaryScriptId, secondaryScriptId, tertiaryScriptId =
        pcall(GetCraftedAbilityActiveScriptIds, craftedAbilityId)
    if not ok then
        return nil
    end

    return NormalizeCraftedScriptIds(primaryScriptId, secondaryScriptId, tertiaryScriptId)
end

local function ResolveAbilityName(abilityId)
    if type(abilityId) ~= "number" or abilityId <= 0 or type(GetAbilityName) ~= "function" then
        return nil
    end

    local ok, name = pcall(GetAbilityName, abilityId)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end

    return nil
end

local function ResolveAbilityIcon(abilityId)
    if type(abilityId) ~= "number" or abilityId <= 0 or type(GetAbilityIcon) ~= "function" then
        return nil
    end

    local ok, icon = pcall(GetAbilityIcon, abilityId)
    if ok and type(icon) == "string" and icon ~= "" then
        return icon
    end

    return nil
end

local function ResolveCurrentSlotIcon(slotIndex, hotbarCategory)
    if type(GetSlotTexture) ~= "function" then
        return nil
    end

    local ok, icon = pcall(GetSlotTexture, slotIndex, hotbarCategory)
    if ok and type(icon) == "string" and icon ~= "" then
        return icon
    end

    return nil
end

local function CaptureCurrentSkillSlot(slotIndex, hotbarCategory)
    local entry = {
        hotbarCategory = hotbarCategory,
        slot = slotIndex,
        abilityId = nil,
        slotActionType = nil,
        craftedAbilityId = nil,
        scriptIds = nil,
        abilityName = nil,
        iconTexture = nil,
        isEmpty = true,
    }

    if type(ACTION_BAR_ASSIGNMENT_MANAGER) == "table"
        and type(ACTION_BAR_ASSIGNMENT_MANAGER.GetHotbar) == "function" then
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbarCategory)
        local slotData = type(hotbar) == "table" and type(hotbar.GetSlotData) == "function"
            and hotbar:GetSlotData(slotIndex)
            or nil

        if type(slotData) == "table" then
            local isEmpty = type(slotData.IsEmpty) == "function" and Util:SafeCallMethod(slotData, "IsEmpty")
            if isEmpty == true then
                return entry
            end

            local actionType = type(slotData.GetActionType) == "function"
                and Util:SafeCallMethod(slotData, "GetActionType")
                or nil
            local effectiveAbilityId = type(slotData.GetEffectiveAbilityId) == "function"
                and Util:SafeCallMethod(slotData, "GetEffectiveAbilityId")
                or nil
            local actionId = type(slotData.GetActionId) == "function"
                and Util:SafeCallMethod(slotData, "GetActionId")
                or nil
            local iconTexture = type(slotData.GetIcon) == "function"
                and Util:SafeCallMethod(slotData, "GetIcon")
                or nil

            local resolvedAbilityId = type(effectiveAbilityId) == "number" and effectiveAbilityId > 0 and effectiveAbilityId
                or (type(actionId) == "number" and actionId > 0 and actionId or nil)

            if resolvedAbilityId ~= nil then
                entry.abilityId = resolvedAbilityId
                entry.slotActionType = actionType
                if actionType == ACTION_TYPE_CRAFTED_ABILITY and type(actionId) == "number" and actionId > 0 then
                    entry.craftedAbilityId = actionId
                    entry.scriptIds = ResolveCraftedAbilityScriptIds(actionId)
                end
                entry.abilityName = ResolveAbilityName(resolvedAbilityId)
                entry.iconTexture = type(iconTexture) == "string" and iconTexture ~= "" and iconTexture or ResolveAbilityIcon(resolvedAbilityId)
                entry.isEmpty = false
                return entry
            end

            if type(iconTexture) == "string" and iconTexture ~= "" then
                entry.iconTexture = iconTexture
                entry.isEmpty = false
                return entry
            end
        end
    end

    local abilityId = ResolveCurrentSlotAbilityId(slotIndex, hotbarCategory)
    if type(abilityId) == "number" and abilityId > 0 then
        entry.abilityId = abilityId
        if type(GetSlotType) == "function" then
            local ok, actionType = pcall(GetSlotType, slotIndex, hotbarCategory)
            if ok then
                entry.slotActionType = actionType
            end
        end
        if entry.slotActionType == ACTION_TYPE_CRAFTED_ABILITY and type(GetSlotBoundId) == "function" then
            local ok, craftedAbilityId = pcall(GetSlotBoundId, slotIndex, hotbarCategory)
            if ok and type(craftedAbilityId) == "number" and craftedAbilityId > 0 then
                entry.craftedAbilityId = craftedAbilityId
                entry.scriptIds = ResolveCraftedAbilityScriptIds(craftedAbilityId)
            end
        end
        entry.abilityName = ResolveAbilityName(abilityId)
        entry.iconTexture = ResolveCurrentSlotIcon(slotIndex, hotbarCategory) or ResolveAbilityIcon(abilityId)
        entry.isEmpty = false
    else
        entry.iconTexture = ResolveCurrentSlotIcon(slotIndex, hotbarCategory)
        if type(entry.iconTexture) == "string" and entry.iconTexture ~= "" then
            entry.isEmpty = false
        end
    end

    return entry
end

local function CaptureCurrentEquipmentState()
    local equipment = {}

    if type(GetItemLink) ~= "function" then
        return equipment
    end

    for _, equipSlotId in ipairs(EQUIPMENT_SLOT_IDS) do
        if type(equipSlotId) == "number" then
            local itemLink = GetItemLink(BAG_WORN, equipSlotId, LINK_STYLE_DEFAULT)
            local itemName = type(GetItemLinkName) == "function" and GetItemLinkName(itemLink) or nil
            if type(itemLink) == "string" and itemLink ~= ""
                and ((type(itemName) == "string" and itemName ~= "") or type(GetItemLinkName) ~= "function") then
                local traitType = type(GetItemLinkTraitInfo) == "function" and GetItemLinkTraitInfo(itemLink) or nil
                local quality = type(GetItemLinkDisplayQuality) == "function" and GetItemLinkDisplayQuality(itemLink) or nil
                local uniqueId = type(GetItemUniqueId) == "function" and GetItemUniqueId(BAG_WORN, equipSlotId) or nil
                if uniqueId ~= nil and type(Id64ToString) == "function" then
                    uniqueId = Id64ToString(uniqueId)
                end

                equipment[equipSlotId] = {
                    uniqueId = type(uniqueId) == "string" and uniqueId ~= "" and uniqueId or nil,
                    itemLink = itemLink,
                    traitType = type(traitType) == "number" and traitType > 0 and traitType or nil,
                    quality = type(quality) == "number" and quality or nil,
                }
            end
        end
    end

    return equipment
end

local function CaptureCurrentChampionPoints()
    local championPoints = {
        warfare = { slotted = {}, allocated = {} },
        fitness = { slotted = {}, allocated = {} },
        craft = { slotted = {}, allocated = {} },
    }

    if type(GetSlotBoundId) ~= "function" then
        return championPoints
    end

    for _, group in ipairs(Domains.ChampionGroups) do
        local groupEntries = championPoints[group.id]
        if type(groupEntries) == "table" then
            for _, slotIndex in ipairs(group.slots or {}) do
                local starId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION)
                if type(starId) == "number" and starId > 0 then
                    groupEntries.slotted[#groupEntries.slotted + 1] = starId
                end
            end
        end
    end

    if type(GetNumChampionDisciplines) ~= "function"
        or type(GetChampionDisciplineId) ~= "function"
        or type(GetChampionDisciplineType) ~= "function"
        or type(GetNumChampionDisciplineSkills) ~= "function"
        or type(GetChampionSkillId) ~= "function"
        or type(GetNumPointsSpentOnChampionSkill) ~= "function" then
        return championPoints
    end

    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        local disciplineType = type(disciplineId) == "number" and GetChampionDisciplineType(disciplineId) or nil
        local groupId = Domains.ChampionGroupByDisciplineType[disciplineType]
        local groupEntries = type(groupId) == "string" and championPoints[groupId] or nil
        if type(groupEntries) == "table" then
            for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
                local starId = GetChampionSkillId(disciplineIndex, skillIndex)
                local spentPoints = type(starId) == "number" and GetNumPointsSpentOnChampionSkill(starId) or nil
                if type(starId) == "number" and starId > 0 and type(spentPoints) == "number" and spentPoints > 0 then
                    groupEntries.allocated[starId] = spentPoints
                end
            end
        end
    end

    return championPoints
end

local function BuildSubclassName(subclassState)
    local activeLines = type(subclassState) == "table" and subclassState.activeSkillLines or nil
    return LTM_SUBCLASS_NAME_HELPER:BuildBuildNameFromActiveLines(activeLines)
end

local function NormalizeOverwriteType(overwriteType)
    if type(overwriteType) ~= "string" or overwriteType == "" then
        return "all"
    end

    return OVERWRITE_TYPES[overwriteType] and overwriteType or nil
end

local function EnsurePageShape(pageId, page)
    page = type(page) == "table" and page or {}
    page.id = type(page.id) == "string" and page.id ~= "" and page.id or pageId
    page.name = NormalizePageName(page.name) or (pageId == DEFAULT_PAGE_ID and DEFAULT_PAGE_NAME or page.id)
    page.builds = type(page.builds) == "table" and page.builds or {}

    NormalizePageBuildOrder(page)
    return page
end

local function BuildDefaultPage(pageId)
    pageId = type(pageId) == "string" and pageId ~= "" and pageId or DEFAULT_PAGE_ID
    return EnsurePageShape(pageId, {
        id = pageId,
        name = GetDefaultPageName(),
        builds = {},
        buildOrder = {},
    })
end

local function BuildDefaultPageMetadata()
    return {
        pageOrder = { DEFAULT_PAGE_ID },
        pages = {
            [DEFAULT_PAGE_ID] = {
                id = DEFAULT_PAGE_ID,
                name = GetDefaultPageName(),
                buildOrder = {},
                buildCount = 0,
            },
        },
        selectedPageId = DEFAULT_PAGE_ID,
        selectedBuildIdByPage = {},
    }
end

local function CollectLegacyBuilds(bucket)
    local legacyBuilds = {}
    for key, value in pairs(type(bucket) == "table" and bucket or {}) do
        if not LTM_BUILD_CODEC:IsReservedCharacterBucketKey(key) and type(value) == "table" then
            legacyBuilds[key] = value
        end
    end
    return legacyBuilds
end

local function BuildPageMetadataSnapshot(bucket)
    if type(bucket) ~= "table" then
        return BuildDefaultPageMetadata()
    end

    if type(bucket.pages) ~= "table" or type(bucket.pageOrder) ~= "table" then
        local legacyBuilds = CollectLegacyBuilds(bucket)

        local buildOrder = CollectSortedStringKeys(legacyBuilds)
        local uiState = type(bucket.uiState) == "table" and bucket.uiState or {}
        local selectedBuildId = type(uiState.selectedBuildId) == "string" and uiState.selectedBuildId
            or (type(bucket.selectedBuildId) == "string" and bucket.selectedBuildId or nil)
        local selectedBuildIdByPage = {}
        if type(selectedBuildId) == "string" and type(legacyBuilds[selectedBuildId]) == "table" then
            selectedBuildIdByPage[DEFAULT_PAGE_ID] = selectedBuildId
        end

        return {
            pageOrder = { DEFAULT_PAGE_ID },
            pages = {
                [DEFAULT_PAGE_ID] = {
                    id = DEFAULT_PAGE_ID,
                    name = GetDefaultPageName(),
                    buildOrder = buildOrder,
                    buildCount = #buildOrder,
                },
            },
            selectedPageId = DEFAULT_PAGE_ID,
            selectedBuildIdByPage = selectedBuildIdByPage,
        }
    end

    local pageOrder, seenPageIds = NormalizeOrder(bucket.pageOrder, bucket.pages)
    if #pageOrder == 0 then
        return BuildDefaultPageMetadata()
    end

    local pages = {}
    for _, pageId in ipairs(pageOrder) do
        local page = bucket.pages[pageId]
        if type(page) == "table" then
            local builds = type(page.builds) == "table" and page.builds or {}
            local buildOrder = NormalizeOrder(page.buildOrder, builds)
            pages[pageId] = {
                id = type(page.id) == "string" and page.id ~= "" and page.id or pageId,
                name = NormalizePageName(page.name) or (pageId == DEFAULT_PAGE_ID and GetDefaultPageName() or pageId),
                buildOrder = buildOrder,
                buildCount = #buildOrder,
            }
        end
    end

    local uiState = type(bucket.uiState) == "table" and bucket.uiState or {}
    local selectedPageId = type(uiState.selectedPageId) == "string" and seenPageIds[uiState.selectedPageId]
        and uiState.selectedPageId
        or pageOrder[1]
    local selectedBuildIdByPage = {}
    local sourceSelectedBuildIdByPage = type(uiState.selectedBuildIdByPage) == "table"
        and uiState.selectedBuildIdByPage
        or {}
    for pageId, buildId in pairs(sourceSelectedBuildIdByPage) do
        local page = type(bucket.pages) == "table" and bucket.pages[pageId] or nil
        local builds = type(page) == "table" and type(page.builds) == "table" and page.builds or nil
        if type(buildId) == "string" and type(builds) == "table" and type(builds[buildId]) == "table" then
            selectedBuildIdByPage[pageId] = buildId
        end
    end

    return {
        pageOrder = pageOrder,
        pages = pages,
        selectedPageId = selectedPageId,
        selectedBuildIdByPage = selectedBuildIdByPage,
    }
end

function LTM_BUILD_STORE:EnsureSavedVarsShape(readOnly)
    if type(self.savedVars) ~= "table" then
        return nil
    end

    if type(self.savedVars.buildsByCharacter) ~= "table" then
        if readOnly then
            return nil
        end
        self.savedVars.buildsByCharacter = {}
    end

    return self.savedVars
end

function LTM_BUILD_STORE:GetCurrentCharacterKey()
    return ResolveCurrentCharacterKey()
end

function LTM_BUILD_STORE:CaptureCurrentSubclassForBuild()
    local subclassState = LTM_SUBCLASS_SNAPSHOT:CaptureCurrentSubclassState(nil)
    local targetSkillLineIds = type(subclassState) == "table" and type(subclassState.activeSkillLineIds) == "table"
        and CloneShallow(subclassState.activeSkillLineIds)
        or {}

    return {
        subclass = {
            targetSkillLineIds = targetSkillLineIds,
        },
        suggestedName = BuildSubclassName(subclassState),
    }
end

function LTM_BUILD_STORE:CaptureCurrentAttributesForBuild()
    local attributeState = LTM_ATTRIBUTE_SNAPSHOT:CaptureCurrentAttributeState(nil)
    return {
        health = type(attributeState) == "table" and attributeState.health or 0,
        magicka = type(attributeState) == "table" and attributeState.magicka or 0,
        stamina = type(attributeState) == "table" and attributeState.stamina or 0,
    }
end

local function ResolveRankOneAbilityId(skillData)
    local rankData = type(skillData) == "table"
        and type(skillData.GetRankData) == "function"
        and skillData:GetRankData(1)
        or nil
    local abilityId = type(rankData) == "table"
        and type(rankData.GetAbilityId) == "function"
        and rankData:GetAbilityId()
        or nil

    abilityId = tonumber(abilityId)
    return abilityId ~= nil and abilityId > 0 and math.floor(abilityId) or nil
end

local function CaptureClassMasteryPurchasedAbilities(skillLineData)
    local purchasedAbilities = {}
    local purchasedCount = 0
    local candidateCount = 0

    local numSkills = type(skillLineData) == "table"
        and type(skillLineData.GetNumSkills) == "function"
        and skillLineData:GetNumSkills()
        or 0
    if type(numSkills) ~= "number" or numSkills <= 0
        or type(skillLineData.GetSkillDataByIndex) ~= "function" then
        return purchasedAbilities, purchasedCount, candidateCount
    end

    for skillIndex = 1, numSkills do
        local skillData = skillLineData:GetSkillDataByIndex(skillIndex)
        if type(skillData) == "table"
            and type(skillData.IsPassive) == "function"
            and skillData:IsPassive() then
            candidateCount = candidateCount + 1
            if type(skillData.IsPurchased) == "function" and skillData:IsPurchased() then
                local abilityId = ResolveRankOneAbilityId(skillData)
                local rank = type(skillData.GetCurrentRank) == "function" and tonumber(skillData:GetCurrentRank()) or nil
                if abilityId ~= nil and rank ~= nil and rank > 0 then
                    purchasedAbilities[abilityId] = math.floor(rank)
                    purchasedCount = purchasedCount + 1
                end
            end
        end
    end

    return purchasedAbilities, purchasedCount, candidateCount
end

local function GetClassMasteryCandidatePriority(skillLineData, purchasedCount)
    if type(skillLineData) ~= "table" then
        return 0
    end

    if type(skillLineData.IsClassMastery) ~= "function"
        or skillLineData:IsClassMastery() ~= true then
        return 0
    end

    if tonumber(purchasedCount) ~= nil and purchasedCount > 0 then
        return 500
    end

    if type(skillLineData.IsDiscovered) == "function"
        and skillLineData:IsDiscovered() == true then
        return 400
    end

    if type(skillLineData.IsActive) == "function" and skillLineData:IsActive() == true then
        return 300
    end

    if type(skillLineData.IsPlayerClassSkillLine) == "function"
        and skillLineData:IsPlayerClassSkillLine() == true then
        return 200
    end

    return 0
end

function LTM_BUILD_STORE:CaptureCurrentClassMasteryForBuild()
    if type(SKILLS_DATA_MANAGER) ~= "table"
        or type(SKILLS_DATA_MANAGER.SkillTypeIterator) ~= "function" then
        return nil
    end

    local bestCandidate = nil

    for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        if type(skillTypeData) == "table"
            and type(skillTypeData.SkillLineIterator) == "function" then
            for _, skillLineData in skillTypeData:SkillLineIterator() do
                if type(skillLineData) == "table"
                    and type(skillLineData.RefreshDynamicData) == "function" then
                    skillLineData:RefreshDynamicData(true)
                end

                if type(skillLineData) == "table"
                    and type(skillLineData.IsClassMastery) == "function"
                    and skillLineData:IsClassMastery() == true then
                    local skillLineId = type(skillLineData.GetId) == "function" and tonumber(skillLineData:GetId()) or nil
                    if skillLineId ~= nil and skillLineId > 0 then
                        local purchasedAbilities, purchasedCount, candidateCount =
                            CaptureClassMasteryPurchasedAbilities(skillLineData)
                        local priority = GetClassMasteryCandidatePriority(skillLineData, purchasedCount)
                        if priority > 0
                            and (type(bestCandidate) ~= "table" or priority > bestCandidate.priority) then
                            bestCandidate = {
                                priority = priority,
                                skillLineId = math.floor(skillLineId),
                                purchasedAbilities = purchasedAbilities,
                                purchasedCount = purchasedCount,
                                candidateCount = candidateCount,
                            }
                        end
                    end
                end
            end
        end
    end

    if type(bestCandidate) == "table" then
        Log.LogDebugSummary(
            "Mastery line detected",
            "targetSkillLineId=" .. tostring(bestCandidate.skillLineId),
            "candidateCount=" .. tostring(bestCandidate.candidateCount),
            "priority=" .. tostring(bestCandidate.priority)
        )
        Log.LogDebugSummary(
            "Mastery abilities captured",
            "targetSkillLineId=" .. tostring(bestCandidate.skillLineId),
            "purchasedCount=" .. tostring(bestCandidate.purchasedCount)
        )
        return {
            targetSkillLineId = bestCandidate.skillLineId,
            purchasedAbilities = bestCandidate.purchasedAbilities,
        }
    end

    Log.LogDebugSummary("Mastery capture skipped", "reason=mastery_line_not_detected_on_capture")
    return nil
end

function LTM_BUILD_STORE:CaptureCurrentEquipmentForBuild()
    return CaptureCurrentEquipmentState()
end

function LTM_BUILD_STORE:CaptureCurrentOutfitForBuild()
    if type(GetEquippedOutfitIndex) ~= "function" then
        return nil, "outfit_api_unavailable"
    end

    local ok, outfitIndex = pcall(GetEquippedOutfitIndex, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if not ok then
        return nil, "outfit_capture_failed"
    end
    if outfitIndex == nil then
        return { mode = "default" }
    end
    if type(outfitIndex) ~= "number" or outfitIndex < 1 or outfitIndex % 1 ~= 0 then
        return nil, "outfit_capture_invalid"
    end

    return {
        equippedOutfitIndex = outfitIndex,
    }
end

function LTM_BUILD_STORE:CaptureCurrentChampionPointsForBuild()
    return CaptureCurrentChampionPoints()
end

function LTM_BUILD_STORE:CaptureCurrentPassiveSnapshotForBuild(build, buildId, overwriteType, existingSnapshot)
    local snapshot, details = LTM_PASSIVE_SNAPSHOT_APPLY:CaptureCurrentSnapshot({
        build = build,
        buildId = buildId,
        overwriteType = overwriteType,
        existingSnapshot = existingSnapshot,
    })
    if type(snapshot) ~= "table" or type(snapshot.lines) ~= "table" then
        return nil, "passive_snapshot_capture_failed"
    end
    return snapshot, nil, details
end

function LTM_BUILD_STORE:CaptureCurrentActiveSnapshotForBuild()
    local snapshot, err = LTM_SKILL_SNAPSHOT_AUDIT:CaptureCurrentActiveSnapshot()
    if type(snapshot) ~= "table" or type(snapshot.a) ~= "string" then
        return nil, err or "active_snapshot_capture_failed"
    end
    return snapshot, nil
end

local function GetPersistentCharacterBucket(store, characterKey)
    local savedVars = store:EnsureSavedVarsShape(true)
    if type(savedVars) ~= "table" or type(savedVars.buildsByCharacter) ~= "table" then
        return nil
    end

    characterKey = characterKey or store:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    return savedVars.buildsByCharacter[characterKey]
end

local function ResolvePersistentPagesInOrder(bucket)
    if type(bucket) ~= "table" then
        return {}, {}
    end

    if type(bucket.pages) == "table" and type(bucket.pageOrder) == "table" then
        local pageOrder = NormalizeOrder(bucket.pageOrder, bucket.pages)
        return pageOrder, bucket.pages
    end

    local legacyBuilds = CollectLegacyBuilds(bucket)
    return { DEFAULT_PAGE_ID }, {
        [DEFAULT_PAGE_ID] = {
            builds = legacyBuilds,
        },
    }
end

function LTM_BUILD_STORE:GetCharacterPageMetadataReadonly(characterKey)
    return BuildPageMetadataSnapshot(GetPersistentCharacterBucket(self, characterKey))
end

local function EnsureCharacterPagesForWrite(store, characterKey)
    local savedVars = store:EnsureSavedVarsShape(false)
    if type(savedVars) ~= "table" then
        return nil
    end

    characterKey = characterKey or store:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    local bucket = savedVars.buildsByCharacter[characterKey]
    if type(bucket) ~= "table" then
        bucket = {}
        savedVars.buildsByCharacter[characterKey] = bucket
    end

    if type(bucket.pages) ~= "table" or type(bucket.pageOrder) ~= "table" then
        local legacyBuilds = CollectLegacyBuilds(bucket)
        local selectedBuildIdByPage = {}
        local legacyUiState = type(bucket.uiState) == "table" and bucket.uiState or {}
        local legacySelectedBuildId = type(legacyUiState.selectedBuildId) == "string" and legacyUiState.selectedBuildId
            or (type(bucket.selectedBuildId) == "string" and bucket.selectedBuildId or nil)

        if type(legacySelectedBuildId) == "string" and type(legacyBuilds[legacySelectedBuildId]) == "table" then
            selectedBuildIdByPage[DEFAULT_PAGE_ID] = legacySelectedBuildId
        end

        bucket = {
            pageOrder = { DEFAULT_PAGE_ID },
            pages = {
                [DEFAULT_PAGE_ID] = {
                    id = DEFAULT_PAGE_ID,
                    name = DEFAULT_PAGE_NAME,
                    builds = legacyBuilds,
                    buildOrder = CollectSortedStringKeys(legacyBuilds),
                },
            },
            uiState = {
                selectedPageId = DEFAULT_PAGE_ID,
                selectedBuildIdByPage = selectedBuildIdByPage,
            },
        }
        savedVars.buildsByCharacter[characterKey] = bucket
    end

    bucket.pages = type(bucket.pages) == "table" and bucket.pages or {}
    bucket.uiState = type(bucket.uiState) == "table" and bucket.uiState or {}
    bucket.uiState.selectedBuildIdByPage = type(bucket.uiState.selectedBuildIdByPage) == "table"
        and bucket.uiState.selectedBuildIdByPage
        or {}

    local normalizedPageOrder, seenPageIds = NormalizeOrder(bucket.pageOrder, bucket.pages)

    if #normalizedPageOrder == 0 then
        bucket.pages[DEFAULT_PAGE_ID] = BuildDefaultPage(DEFAULT_PAGE_ID)
        AppendUniqueString(normalizedPageOrder, seenPageIds, DEFAULT_PAGE_ID)
    end

    bucket.pageOrder = normalizedPageOrder

    for _, pageId in ipairs(bucket.pageOrder) do
        bucket.pages[pageId] = EnsurePageShape(pageId, bucket.pages[pageId])
    end

    local selectedPageId = bucket.uiState.selectedPageId
    if type(selectedPageId) ~= "string" or not seenPageIds[selectedPageId] then
        bucket.uiState.selectedPageId = bucket.pageOrder[1] or nil
    end

    for pageId, buildId in pairs(bucket.uiState.selectedBuildIdByPage) do
        local page = bucket.pages[pageId]
        if type(page) ~= "table" or type(buildId) ~= "string" or type(page.builds[buildId]) ~= "table" then
            bucket.uiState.selectedBuildIdByPage[pageId] = nil
        end
    end

    return bucket
end

function LTM_BUILD_STORE:GetPageList(characterKey)
    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)

    local entries = {}
    for index, pageId in ipairs(metadata.pageOrder or {}) do
        local page = metadata.pages[pageId]
        if type(page) == "table" then
            entries[#entries + 1] = {
                id = pageId,
                pageId = pageId,
                name = page.name or pageId,
                page = page,
                index = index,
                buildCount = page.buildCount or #page.buildOrder,
            }
        end
    end

    return entries
end

function LTM_BUILD_STORE:GetSelectedPageId(characterKey)
    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    return metadata.selectedPageId or metadata.pageOrder[1] or DEFAULT_PAGE_ID
end

function LTM_BUILD_STORE:SetSelectedPageId(pageId, characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_id_missing"
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    if type(metadata.pages) ~= "table" or type(metadata.pages[pageId]) ~= "table" then
        return nil, "page_not_found"
    end

    local writeBucket = EnsureCharacterPagesForWrite(self, characterKey)
    if type(writeBucket) ~= "table" then
        return nil, "page_bucket_unavailable"
    end

    writeBucket.uiState.selectedPageId = pageId
    return true
end

function LTM_BUILD_STORE:SetPageOrder(newPageOrder, characterKey)
    if type(newPageOrder) ~= "table" then
        return nil, "page_order_invalid"
    end

    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    if type(bucket) ~= "table" or type(bucket.pages) ~= "table" then
        return nil, "page_bucket_unavailable"
    end

    local currentPageOrder = bucket.pageOrder or {}
    local currentPageCount = #currentPageOrder
    local normalizedPageOrder = {}
    local seenPageIds = {}

    for _, pageId in ipairs(newPageOrder) do
        if type(pageId) == "string" and type(bucket.pages[pageId]) == "table" and not seenPageIds[pageId] then
            seenPageIds[pageId] = true
            normalizedPageOrder[#normalizedPageOrder + 1] = pageId
        end
    end

    for _, pageId in ipairs(currentPageOrder) do
        if type(bucket.pages[pageId]) == "table" and not seenPageIds[pageId] then
            seenPageIds[pageId] = true
            normalizedPageOrder[#normalizedPageOrder + 1] = pageId
        end
    end

    if #normalizedPageOrder ~= currentPageCount then
        return nil, "page_order_invalid"
    end

    bucket.pageOrder = normalizedPageOrder
    EnsureCharacterPagesForWrite(self, characterKey)

    return CloneShallow(bucket.pageOrder)
end

function LTM_BUILD_STORE:IsDuplicatePageName(candidateName, excludePageId, characterKey)
    local normalizedName = NormalizePageName(candidateName)
    if normalizedName == nil then
        return false
    end

    for _, entry in ipairs(self:GetPageList(characterKey)) do
        local entryPageId = type(entry) == "table" and entry.pageId or nil
        local entryName = NormalizePageName(type(entry) == "table" and entry.name or nil)
        if entryPageId ~= excludePageId and entryName == normalizedName then
            return true
        end
    end

    return false
end

function LTM_BUILD_STORE:GenerateNextPageId(characterKey)
    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local maxNumber = 0

    if type(bucket) == "table" then
        for pageId in pairs(bucket.pages or {}) do
            local numberPart = type(pageId) == "string" and string.match(pageId, "^page_(%d+)$") or nil
            local numericValue = numberPart ~= nil and tonumber(numberPart) or nil
            if type(numericValue) == "number" and numericValue > maxNumber then
                maxNumber = numericValue
            end
        end
    end

    return string.format("page_%03d", maxNumber + 1)
end

function LTM_BUILD_STORE:GenerateNextPageName(characterKey)
    local existingNames = {}

    for _, entry in ipairs(self:GetPageList(characterKey)) do
        local normalizedName = NormalizePageName(type(entry) == "table" and entry.name or nil)
        if type(normalizedName) == "string" and normalizedName ~= "" then
            existingNames[normalizedName] = true
        end
    end

    local nextIndex = 1
    while true do
        local candidate = BuildGeneratedPageName(nextIndex)
        if not existingNames[candidate] then
            return candidate
        end
        nextIndex = nextIndex + 1
    end
end

function LTM_BUILD_STORE:CreatePage(pageName, characterKey)
    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    if type(bucket) ~= "table" then
        return nil, "page_bucket_unavailable"
    end

    local pageId = self:GenerateNextPageId(characterKey)
    local normalizedPageName = NormalizePageName(pageName) or self:GenerateNextPageName(characterKey)
    local page = EnsurePageShape(pageId, {
        id = pageId,
        name = normalizedPageName,
        buildOrder = {},
        builds = {},
    })

    bucket.pages[pageId] = page
    bucket.pageOrder = bucket.pageOrder or {}
    bucket.pageOrder[#bucket.pageOrder + 1] = pageId
    bucket.uiState = type(bucket.uiState) == "table" and bucket.uiState or {}
    bucket.uiState.selectedBuildIdByPage = type(bucket.uiState.selectedBuildIdByPage) == "table"
        and bucket.uiState.selectedBuildIdByPage
        or {}
    bucket.uiState.selectedPageId = pageId
    bucket.uiState.selectedBuildIdByPage[pageId] = nil

    EnsureCharacterPagesForWrite(self, characterKey)
    return bucket.pages[pageId]
end

function LTM_BUILD_STORE:CreateDefaultPage(characterKey)
    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    if type(bucket) ~= "table" then
        return nil, "page_bucket_unavailable"
    end

    if #bucket.pageOrder == 1
        and bucket.pageOrder[1] == DEFAULT_PAGE_ID
        and type(bucket.pages[DEFAULT_PAGE_ID]) == "table" then
        bucket.uiState.selectedPageId = DEFAULT_PAGE_ID
        bucket.uiState.selectedBuildIdByPage[DEFAULT_PAGE_ID] = bucket.uiState.selectedBuildIdByPage[DEFAULT_PAGE_ID] or nil
        return bucket.pages[DEFAULT_PAGE_ID]
    end

    local pageId = DEFAULT_PAGE_ID
    if type(bucket.pages[pageId]) == "table" then
        pageId = self:GenerateNextPageId(characterKey)
    end

    local page = BuildDefaultPage(pageId)
    bucket.pages[pageId] = page
    bucket.pageOrder = bucket.pageOrder or {}
    bucket.pageOrder[#bucket.pageOrder + 1] = pageId
    bucket.uiState = type(bucket.uiState) == "table" and bucket.uiState or {}
    bucket.uiState.selectedBuildIdByPage = type(bucket.uiState.selectedBuildIdByPage) == "table"
        and bucket.uiState.selectedBuildIdByPage
        or {}
    bucket.uiState.selectedPageId = pageId
    bucket.uiState.selectedBuildIdByPage[pageId] = nil

    EnsureCharacterPagesForWrite(self, characterKey)
    return bucket.pages[pageId]
end

function LTM_BUILD_STORE:RenamePage(pageId, newName, characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_id_missing"
    end

    local normalizedName, normalizeErr = NormalizeLimitedName(newName)
    if normalizedName == nil then
        return nil, normalizeErr == "name_too_long" and "page_name_too_long" or "page_name_empty"
    end

    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local page = type(bucket) == "table" and type(bucket.pages) == "table" and bucket.pages[pageId] or nil
    if type(page) ~= "table" then
        return nil, "page_not_found"
    end

    local currentName = NormalizePageName(page.name)
    if currentName == normalizedName then
        page.name = normalizedName
        return page
    end

    if self:IsDuplicatePageName(normalizedName, pageId, characterKey) then
        return nil, "page_name_duplicate"
    end

    page.name = normalizedName
    return page
end

function LTM_BUILD_STORE:DeletePage(pageId, characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_id_missing"
    end

    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local page = type(bucket) == "table" and type(bucket.pages) == "table" and bucket.pages[pageId] or nil
    if type(page) ~= "table" then
        return nil, "page_not_found"
    end

    local pageOrderBeforeDelete = CloneShallow(bucket.pageOrder or {})
    local deletedIndex = nil
    local previousPageId = nil
    for index, orderedPageId in ipairs(pageOrderBeforeDelete) do
        if orderedPageId == pageId then
            deletedIndex = index
            previousPageId = pageOrderBeforeDelete[index - 1]
            break
        end
    end

    if deletedIndex == nil then
        return nil, "page_not_found"
    end

    bucket.pages[pageId] = nil
    table.remove(bucket.pageOrder, deletedIndex)
    bucket.uiState.selectedBuildIdByPage[pageId] = nil

    local nextSelectedPageId = previousPageId
    if type(nextSelectedPageId) ~= "string" or type(bucket.pages[nextSelectedPageId]) ~= "table" then
        nextSelectedPageId = bucket.pageOrder[1]
    end

    local recreatedDefaultPageId = nil
    if type(nextSelectedPageId) ~= "string" or type(bucket.pages[nextSelectedPageId]) ~= "table" then
        local defaultPage, defaultErr = self:CreateDefaultPage(characterKey)
        if type(defaultPage) ~= "table" then
            return nil, defaultErr or "page_default_recreate_failed"
        end
        nextSelectedPageId = defaultPage.id
        recreatedDefaultPageId = defaultPage.id
        bucket = EnsureCharacterPagesForWrite(self, characterKey)
    else
        bucket.uiState.selectedPageId = nextSelectedPageId
    end

    EnsureCharacterPagesForWrite(self, characterKey)
    self:RefreshRuntimeCache(characterKey, "delete_page")

    return {
        characterId = characterKey,
        deletedPageId = pageId,
        deletedPageName = page.name or pageId,
        nextSelectedPageId = nextSelectedPageId,
        nextSelectedBuildId = type(bucket.uiState.selectedBuildIdByPage) == "table"
            and bucket.uiState.selectedBuildIdByPage[nextSelectedPageId]
            or nil,
        remainingPageCount = CountTableEntries(bucket.pages),
        recreatedDefaultPageId = recreatedDefaultPageId,
    }
end

function LTM_BUILD_STORE:DeleteSelectedPage(characterKey)
    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    if type(GetPersistentCharacterBucket(self, characterKey)) ~= "table" then
        return nil, "page_not_found"
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local pageId = metadata.selectedPageId
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_not_found"
    end

    return self:DeletePage(pageId, characterKey)
end

function LTM_BUILD_STORE:GetSelectedBuildIdForPage(pageId, characterKey)
    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    local buildId = type(metadata.selectedBuildIdByPage) == "table"
        and metadata.selectedBuildIdByPage[pageId]
        or nil

    if type(page) == "table" and type(buildId) == "string" then
        return buildId
    end

    return nil
end

function LTM_BUILD_STORE:SetSelectedBuildIdForPage(pageId, buildId, characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_id_missing"
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    if type(metadata.pages) ~= "table" or type(metadata.pages[pageId]) ~= "table" then
        return nil, "page_not_found"
    end

    local writeBucket = EnsureCharacterPagesForWrite(self, characterKey)
    if type(writeBucket) ~= "table" then
        return nil, "page_bucket_unavailable"
    end

    local writePage = type(writeBucket.pages) == "table" and writeBucket.pages[pageId] or nil
    if type(buildId) ~= "string" or buildId == "" or type(writePage) ~= "table"
        or type(writePage.builds) ~= "table" or type(writePage.builds[buildId]) ~= "table" then
        writeBucket.uiState.selectedBuildIdByPage[pageId] = nil
        return true
    end

    writeBucket.uiState.selectedBuildIdByPage[pageId] = buildId
    return true
end

function LTM_BUILD_STORE:GetRuntimeBuildEntriesForPage(pageId, characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return {}
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    if type(page) ~= "table" then
        return {}
    end

    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return {}
    end

    local runtimeBuilds = type(self.runtimeBuildsByCharacter) == "table"
        and self.runtimeBuildsByCharacter[characterKey]
        or nil
    if type(runtimeBuilds) ~= "table" then
        runtimeBuilds = self:RefreshRuntimeCache(characterKey, "runtime_cache_miss")
    end
    local entries = {}
    for _, buildId in ipairs(page.buildOrder or {}) do
        local build = type(runtimeBuilds) == "table" and runtimeBuilds[buildId] or nil
        if type(build) == "table" then
            entries[#entries + 1] = {
                buildId = buildId,
                ordinal = #entries + 1,
                displayName = build.displayName or build.name or buildId,
                build = build,
                pageId = pageId,
            }
        end
    end

    return entries
end

function LTM_BUILD_STORE:GetBuildIdByOrdinalForPage(pageId, ordinal, characterKey)
    ordinal = tonumber(ordinal)
    if type(ordinal) ~= "number" then
        return nil
    end

    ordinal = math.floor(ordinal)
    if ordinal < 1 then
        return nil
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    if type(page) ~= "table" then
        return nil
    end

    local buildId = page.buildOrder[ordinal]
    if type(buildId) == "string" then
        return buildId
    end

    return nil
end

function LTM_BUILD_STORE:GetBuildOrdinalForPage(pageId, buildId, characterKey)
    if type(buildId) ~= "string" or buildId == "" then
        return nil
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    if type(page) ~= "table" then
        return nil
    end

    for ordinal, orderedBuildId in ipairs(page.buildOrder or {}) do
        if orderedBuildId == buildId then
            return ordinal
        end
    end

    return nil
end

function LTM_BUILD_STORE:GetBuildIdByOrdinalForSelectedPage(ordinal, characterKey)
    local pageId = self:GetSelectedPageId(characterKey)
    return self:GetBuildIdByOrdinalForPage(pageId, ordinal, characterKey)
end

function LTM_BUILD_STORE:GetRuntimeBuildEntriesForSelectedPage(characterKey)
    local pageId = self:GetSelectedPageId(characterKey)
    return self:GetRuntimeBuildEntriesForPage(pageId, characterKey)
end

function LTM_BUILD_STORE:IsBuildInSelectedPage(buildId, characterKey)
    if type(buildId) ~= "string" or buildId == "" then
        return false
    end

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local pageId = metadata.selectedPageId or metadata.pageOrder[1]
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    if type(page) ~= "table" then
        return false
    end

    for _, orderedBuildId in ipairs(page.buildOrder or {}) do
        if orderedBuildId == buildId then
            return true
        end
    end

    return false
end

function LTM_BUILD_STORE:GetPageBuildCount(pageId, characterKey)
    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    pageId = type(pageId) == "string" and pageId ~= "" and pageId or metadata.selectedPageId
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    if type(page) ~= "table" then
        return 0
    end

    return tonumber(page.buildCount) or #(page.buildOrder or {})
end

function LTM_BUILD_STORE:IsRuntimeCacheAvailable(characterKey)
    characterKey = characterKey or self:GetCurrentCharacterKey()
    return type(characterKey) == "string"
        and characterKey ~= ""
        and type(self.runtimeBuildsByCharacter) == "table"
        and type(self.runtimeBuildsByCharacter[characterKey]) == "table"
end

function LTM_BUILD_STORE:GetBuildOrderForPage(pageId, characterKey)
    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
    if type(page) ~= "table" then
        return {}
    end

    return CloneShallow(page.buildOrder or {})
end

function LTM_BUILD_STORE:SetBuildOrderForPage(pageId, newBuildOrder, characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_id_missing"
    end

    if type(newBuildOrder) ~= "table" then
        return nil, "build_order_invalid"
    end

    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local page = type(bucket) == "table" and type(bucket.pages) == "table" and bucket.pages[pageId] or nil
    if type(page) ~= "table" then
        return nil, "page_not_found"
    end

    local currentBuildOrder = page.buildOrder or {}
    local currentBuildCount = #currentBuildOrder
    local normalizedBuildOrder = {}
    local seenBuildIds = {}

    for _, buildId in ipairs(newBuildOrder) do
        if type(buildId) == "string" and type(page.builds[buildId]) == "table" and not seenBuildIds[buildId] then
            seenBuildIds[buildId] = true
            normalizedBuildOrder[#normalizedBuildOrder + 1] = buildId
        end
    end

    if #normalizedBuildOrder ~= currentBuildCount then
        return nil, "build_order_invalid"
    end

    page.buildOrder = normalizedBuildOrder
    EnsureCharacterPagesForWrite(self, characterKey)

    return CloneShallow(page.buildOrder)
end

function LTM_BUILD_STORE:SetBuildOrderForSelectedPage(newBuildOrder, characterKey)
    local pageId = self:GetSelectedPageId(characterKey)
    if type(pageId) ~= "string" or pageId == "" then
        return nil, "page_not_found"
    end

    return self:SetBuildOrderForPage(pageId, newBuildOrder, characterKey)
end

local function FindPersistentBuildLocationById(store, buildId, characterKey, forWrite)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, nil, nil
    end

    local bucket = forWrite == true
        and EnsureCharacterPagesForWrite(store, characterKey)
        or GetPersistentCharacterBucket(store, characterKey)
    if type(bucket) ~= "table" then
        return nil, nil, nil
    end

    local pageOrder, pages = ResolvePersistentPagesInOrder(bucket)
    for _, pageId in ipairs(pageOrder) do
        local page = pages[pageId]
        local build = type(page) == "table" and type(page.builds) == "table" and page.builds[buildId] or nil
        if type(build) == "table" then
            return page, pageId, build
        end
    end

    return nil, nil, nil
end

local function BuildRuntimeList(store, characterKey)
    local merged = {}

    local bucket = GetPersistentCharacterBucket(store, characterKey)
    local pageOrder, pages = ResolvePersistentPagesInOrder(bucket)
    for _, pageId in ipairs(pageOrder) do
        local page = pages[pageId]
        for buildId, build in pairs(type(page) == "table" and page.builds or {}) do
            if type(buildId) == "string" and type(build) == "table" then
                merged[buildId] = DecodeBuildForRuntime(build)
            else
                merged[buildId] = Util:DeepCopy(build)
            end
        end
    end

    return merged
end

function LTM_BUILD_STORE:RefreshRuntimeCache(characterKey, reason)
    self.runtimeBuildsByCharacter = self.runtimeBuildsByCharacter or {}
    characterKey = characterKey or self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return {}
    end

    local list = BuildRuntimeList(self, characterKey)
    self.runtimeBuildsByCharacter[characterKey] = list
    return list
end

function LTM_BUILD_STORE:GetBuildListForCurrentCharacter()
    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return {}
    end

    local runtimeBuilds = type(self.runtimeBuildsByCharacter) == "table"
        and self.runtimeBuildsByCharacter[characterKey]
        or nil

    if type(runtimeBuilds) ~= "table" then
        runtimeBuilds = self:RefreshRuntimeCache(characterKey, "runtime_cache_miss")
    end

    return runtimeBuilds
end

function LTM_BUILD_STORE:GetBuildById(buildId)
    local buildList = self:GetBuildListForCurrentCharacter()
    local build = type(buildList) == "table" and buildList[buildId] or nil
    if type(build) == "table" then
        return build
    end

    return nil
end

local function GetSavedBuildById(store, buildId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil
    end

    local _, _, persistentBuild = FindPersistentBuildLocationById(store, buildId)
    if type(persistentBuild) == "table" then
        return DecodeBuildForRuntime(persistentBuild)
    end

    return nil
end

function LTM_BUILD_STORE:GetPreferredBuildById(buildId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, nil
    end

    local runtimeBuild = self:GetBuildById(buildId)
    if type(runtimeBuild) == "table" then
        return runtimeBuild, "runtime"
    end

    local savedBuild = GetSavedBuildById(self, buildId)
    if type(savedBuild) == "table" then
        return savedBuild, "saved"
    end

    return nil, nil
end

function LTM_BUILD_STORE:SetBuildOutfit(buildId, outfit)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end
    local selection = nil
    if outfit ~= nil then
        if type(outfit) ~= "table" then
            return nil, "outfit_config_invalid"
        end
        if outfit.mode == "default" and outfit.equippedOutfitIndex == nil then
            selection = { mode = "default" }
        elseif outfit.mode == nil and type(outfit.equippedOutfitIndex) == "number"
            and outfit.equippedOutfitIndex >= 1 and outfit.equippedOutfitIndex % 1 == 0 then
            if type(GetNumUnlockedOutfits) ~= "function" then
                return nil, "outfit_api_unavailable"
            end
            local ok, count = pcall(GetNumUnlockedOutfits, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
            if not ok or type(count) ~= "number" or count < 0 or count % 1 ~= 0 then
                return nil, "outfit_count_unavailable"
            end
            if outfit.equippedOutfitIndex > count then
                return nil, "outfit_index_unavailable"
            end
            selection = { equippedOutfitIndex = outfit.equippedOutfitIndex }
        else
            return nil, "outfit_config_invalid"
        end
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end
    local build = DecodeBuildForRuntime(persistentBuild)
    build.outfit = selection
    build.metadata = type(build.metadata) == "table" and build.metadata or {}
    build.metadata.updatedAt = ResolveTimestamp()
    if type(StoreBuildForPersist(page, buildId, build)) ~= "table" then
        return nil, "build_persist_encode_failed"
    end
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "set_build_outfit")
    return build
end

function LTM_BUILD_STORE:SetBuildTransformApply(buildId, kind, enabled)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end
    if kind ~= "werewolf" and kind ~= "vampire" then
        return nil, "transform_kind_invalid"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end
    local build = DecodeBuildForRuntime(persistentBuild)
    local line = type(build.transforms) == "table" and build.transforms[kind] or nil
    if type(line) ~= "table" then
        return nil, "transform_snapshot_missing"
    end
    line.apply = enabled == true
    build.metadata = type(build.metadata) == "table" and build.metadata or {}
    build.metadata.updatedAt = ResolveTimestamp()
    local stored = StoreBuildForPersist(page, buildId, build)
    if type(stored) ~= "table" then
        return nil, "build_persist_encode_failed"
    end
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "set_transform_apply")
    return line.apply
end

function LTM_BUILD_STORE:DeleteBuildTransform(buildId, kind)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end
    if kind ~= "werewolf" and kind ~= "vampire" then
        return nil, "transform_kind_invalid"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end
    local build = DecodeBuildForRuntime(persistentBuild)
    if type(build.transforms) ~= "table" or type(build.transforms[kind]) ~= "table" then
        return nil, "transform_snapshot_missing"
    end
    build.transforms[kind] = nil
    if next(build.transforms) == nil then
        build.transforms = nil
    end
    build.metadata = type(build.metadata) == "table" and build.metadata or {}
    build.metadata.updatedAt = ResolveTimestamp()
    local stored = StoreBuildForPersist(page, buildId, build)
    if type(stored) ~= "table" then
        return nil, "build_persist_encode_failed"
    end
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "delete_transform")
    return true
end

function LTM_BUILD_STORE:GetBuildSkillSettings(buildId)
    if type(buildId) ~= "string" or buildId == "" then
        return SkillSettings:NormalizeBuild(nil), "build_id_missing"
    end

    local build = self:GetBuildById(buildId)
    if type(build) ~= "table" then
        return SkillSettings:NormalizeBuild(nil), "build_not_found"
    end

    return SkillSettings:NormalizeBuild(build.skillSettings)
end

function LTM_BUILD_STORE:SetBuildSkillSettings(buildId, skillSettings)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local _, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local normalizedSettings = SkillSettings:NormalizeBuild(skillSettings)
    -- This setting is codec-independent; update only its field so skill targets,
    -- snapshots, and all other saved Build data remain byte-for-byte untouched.
    persistentBuild.skillSettings = normalizedSettings
    persistentBuild.passivePolicy = nil
    persistentBuild.spSaver = nil
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "set_build_skill_settings")
    return CloneShallow(normalizedSettings)
end

function LTM_BUILD_STORE:SetBuildQuickslotProfileId(buildId, profileId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local savedBuild = DecodeBuildForRuntime(persistentBuild)
    local normalizedProfileId = ResolveOptionalLinkId(profileId)
    savedBuild.quickslotProfileId = normalizedProfileId
    StoreBuildForPersist(page, buildId, savedBuild)
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "set_build_link")
    return normalizedProfileId
end

function LTM_BUILD_STORE:SetBuildFoodCardId(buildId, foodCardId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local savedBuild = DecodeBuildForRuntime(persistentBuild)
    local normalizedFoodCardId = ResolveOptionalLinkId(foodCardId)
    savedBuild.foodCardId = normalizedFoodCardId
    StoreBuildForPersist(page, buildId, savedBuild)
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "set_build_link")
    return normalizedFoodCardId
end

function LTM_BUILD_STORE:SetBuildForceChampionRespec(buildId, enabled)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, nil, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local savedBuild = DecodeBuildForRuntime(persistentBuild)
    local normalizedValue = ResolveForceChampionRespec(enabled)
    savedBuild.forceChampionRespec = normalizedValue
    StoreBuildForPersist(page, buildId, savedBuild)
    self:RefreshRuntimeCache(self:GetCurrentCharacterKey(), "set_force_champion_respec")
    return normalizedValue
end

function LTM_BUILD_STORE:GetSavedSkillSlotAbility(buildId, hotbarCategory, slotIndex)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    hotbarCategory = tonumber(hotbarCategory)
    slotIndex = tonumber(slotIndex)
    if hotbarCategory == nil or slotIndex == nil then
        return nil, "slot_target_invalid"
    end

    hotbarCategory = math.floor(hotbarCategory)
    slotIndex = math.floor(slotIndex)
    if not IsSupportedHotbarCategory(hotbarCategory) or not IsSupportedSkillSlotIndex(slotIndex) then
        return nil, "slot_target_invalid"
    end

    local build = GetSavedBuildById(self, buildId)
    if type(build) ~= "table" then
        return nil, "build_not_found"
    end

    local slots = type(build.skills) == "table" and build.skills.slots or nil
    local recordIndex = FindSavedSkillSlotRecordIndex(slots, hotbarCategory, slotIndex)
    local record = recordIndex ~= nil and slots[recordIndex] or nil
    local abilityId = type(record) == "table" and tonumber(record.abilityId) or 0
    return abilityId or 0
end

function LTM_BUILD_STORE:SetSavedSkillSlotAbility(buildId, hotbarCategory, slotIndex, abilityId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    hotbarCategory = tonumber(hotbarCategory)
    slotIndex = tonumber(slotIndex)
    abilityId = tonumber(abilityId) or 0
    if hotbarCategory == nil or slotIndex == nil then
        return nil, "slot_target_invalid"
    end

    hotbarCategory = math.floor(hotbarCategory)
    slotIndex = math.floor(slotIndex)
    abilityId = math.floor(abilityId)
    if not IsSupportedHotbarCategory(hotbarCategory) or not IsSupportedSkillSlotIndex(slotIndex) then
        return nil, "slot_target_invalid"
    end

    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, characterKey, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local build = DecodeBuildForRuntime(persistentBuild)
    build.skills = type(build.skills) == "table" and build.skills or {
        subclassChanges = {},
        morphChanges = {},
        slots = {},
    }
    build.skills.slots = type(build.skills.slots) == "table" and build.skills.slots or {}

    local slots = build.skills.slots
    local recordIndex = FindSavedSkillSlotRecordIndex(slots, hotbarCategory, slotIndex)
    local previousRecord = recordIndex ~= nil and slots[recordIndex] or nil
    local previousAbilityId = type(previousRecord) == "table" and tonumber(previousRecord.abilityId) or 0

    if abilityId > 0 then
        local updatedRecord = type(previousRecord) == "table" and previousRecord or {}
        updatedRecord.hotbarCategory = hotbarCategory
        updatedRecord.slot = slotIndex
        updatedRecord.abilityId = abilityId
        updatedRecord.slotIndex = nil
        if recordIndex ~= nil then
            slots[recordIndex] = updatedRecord
        else
            slots[#slots + 1] = updatedRecord
        end
    elseif recordIndex ~= nil then
        table.remove(slots, recordIndex)
    end

    SortSavedSkillSlots(slots)

    build.metadata = type(build.metadata) == "table" and build.metadata or {}
    build.metadata.updatedAt = ResolveTimestamp()
    StoreBuildForPersist(page, buildId, build)

    self:RefreshRuntimeCache(characterKey, "set_skill_slot")
    return {
        build = build,
        previousAbilityId = previousAbilityId or 0,
        currentAbilityId = abilityId,
    }
end

function LTM_BUILD_STORE:GetBuildForceChampionRespec(buildId)
    if type(buildId) ~= "string" or buildId == "" then
        return false
    end

    local savedBuild = GetSavedBuildById(self, buildId)
    return type(savedBuild) == "table" and ResolveForceChampionRespec(savedBuild.forceChampionRespec) or false
end

function LTM_BUILD_STORE:RenameBuildById(buildId, newName)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local normalizedName, normalizeErr = NormalizeLimitedName(newName)
    if normalizedName == nil then
        return nil, normalizeErr == "name_too_long" and "build_name_too_long" or "build_name_empty"
    end

    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local page, _, persistentBuild = FindPersistentBuildLocationById(self, buildId, characterKey, true)
    if type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local build = DecodeBuildForRuntime(persistentBuild)
    build.displayName = normalizedName
    build.name = nil
    if type(build.metadata) == "table" then
        build.metadata.updatedAt = ResolveTimestamp()
    end
    StoreBuildForPersist(page, buildId, build)

    self:RefreshRuntimeCache(characterKey, "rename_build")
    return build
end

function LTM_BUILD_STORE:GenerateUniqueCopiedBuildName(page, sourceName)
    page = type(page) == "table" and page or {}
    local existingNames = {}

    for _, buildId in ipairs(page.buildOrder or {}) do
        local build = type(page.builds) == "table" and page.builds[buildId] or nil
        local existingName = type(build) == "table" and NormalizeBuildName(build.displayName or build.name) or nil
        if type(existingName) == "string" and existingName ~= "" then
            existingNames[existingName] = true
        end
    end

    local baseName = NormalizeBuildName(sourceName) or "Build"
    local copyIndex = 1
    while true do
        local candidate = BuildCopiedBuildName(baseName, copyIndex)
        if not existingNames[candidate] then
            return candidate
        end
        copyIndex = copyIndex + 1
    end
end

function LTM_BUILD_STORE:DuplicateBuildById(buildId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local page, pageId, sourcePersistentBuild =
        FindPersistentBuildLocationById(self, buildId, characterKey, true)
    if type(bucket) ~= "table" or type(page) ~= "table" or type(sourcePersistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local sourceBuild = DecodeBuildForRuntime(sourcePersistentBuild)
    local newBuildId = self:GenerateNextBuildId(characterKey)
    local copiedBuild = Util:DeepCopy(sourceBuild)
    local copiedName = self:GenerateUniqueCopiedBuildName(page, sourceBuild.displayName or sourceBuild.name or buildId)
    local timestamp = ResolveTimestamp()

    copiedBuild.id = newBuildId
    copiedBuild.characterId = characterKey
    copiedBuild.displayName = copiedName
    copiedBuild.name = nil
    copiedBuild.metadata = type(copiedBuild.metadata) == "table" and copiedBuild.metadata or {}
    copiedBuild.metadata.createdAt = timestamp
    copiedBuild.metadata.updatedAt = timestamp

    StoreBuildForPersist(page, newBuildId, copiedBuild)
    page.buildOrder = CloneShallow(page.buildOrder or {})
    InsertValueAfter(page.buildOrder, buildId, newBuildId)
    page.buildOrder = NormalizePageBuildOrder(page)
    bucket.uiState.selectedBuildIdByPage[pageId] = newBuildId
    self:RefreshRuntimeCache(characterKey, "duplicate_build")

    return {
        characterId = characterKey,
        pageId = pageId,
        sourceBuildId = buildId,
        copiedBuildId = newBuildId,
        copiedBuildName = copiedName,
        build = copiedBuild,
    }
end

function LTM_BUILD_STORE:MoveBuildToPage(buildId, targetPageId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    if type(targetPageId) ~= "string" or targetPageId == "" then
        return nil, "page_id_missing"
    end

    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local sourcePage, sourcePageId, persistentBuild =
        FindPersistentBuildLocationById(self, buildId, characterKey, true)
    local targetPage = type(bucket) == "table" and type(bucket.pages) == "table" and bucket.pages[targetPageId] or nil
    if type(bucket) ~= "table" or type(sourcePage) ~= "table" or type(persistentBuild) ~= "table" then
        return nil, "build_not_found"
    end
    if type(targetPage) ~= "table" then
        return nil, "page_not_found"
    end
    if sourcePageId == targetPageId then
        return nil, "build_already_in_page"
    end

    local build = DecodeBuildForRuntime(persistentBuild)
    sourcePage.buildOrder = CloneShallow(sourcePage.buildOrder or {})
    local removedIndex = RemoveFirstValue(sourcePage.buildOrder, buildId)
    sourcePage.builds[buildId] = nil
    sourcePage.buildOrder = NormalizePageBuildOrder(sourcePage)

    StoreBuildForPersist(targetPage, buildId, build)
    targetPage.buildOrder = CloneShallow(targetPage.buildOrder or {})
    targetPage.buildOrder[#targetPage.buildOrder + 1] = buildId
    targetPage.buildOrder = NormalizePageBuildOrder(targetPage)

    local sourceSelectedBuildId = bucket.uiState.selectedBuildIdByPage[sourcePageId]
    if sourceSelectedBuildId == buildId or type(sourcePage.builds[sourceSelectedBuildId]) ~= "table" then
        bucket.uiState.selectedBuildIdByPage[sourcePageId] = ResolveFallbackBuildId(sourcePage.buildOrder, removedIndex)
    end

    bucket.uiState.selectedBuildIdByPage[targetPageId] = buildId
    bucket.uiState.selectedPageId = targetPageId

    EnsureCharacterPagesForWrite(self, characterKey)
    self:RefreshRuntimeCache(characterKey, "move_build")

    return {
        characterId = characterKey,
        buildId = buildId,
        buildName = build.displayName or build.name or buildId,
        sourcePageId = sourcePageId,
        targetPageId = targetPageId,
        nextSourceSelectedBuildId = bucket.uiState.selectedBuildIdByPage[sourcePageId],
        targetSelectedBuildId = bucket.uiState.selectedBuildIdByPage[targetPageId],
    }
end

function LTM_BUILD_STORE:DeleteBuildById(buildId)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local bucket = EnsureCharacterPagesForWrite(self, characterKey)
    local page, pageId, build = FindPersistentBuildLocationById(self, buildId, characterKey, true)
    if type(build) ~= "table" then
        return nil, "build_not_found"
    end

    local sortedBuildIdsBeforeDelete = type(page) == "table" and CloneShallow(page.buildOrder) or {}
    local deletedIndex = nil
    for index, sortedBuildId in ipairs(sortedBuildIdsBeforeDelete) do
        if sortedBuildId == buildId then
            deletedIndex = index
            break
        end
    end

    page.builds[buildId] = nil
    page.buildOrder = NormalizePageBuildOrder(page)
    bucket.uiState.selectedBuildIdByPage[pageId] = ResolveFallbackBuildId(page.buildOrder, deletedIndex)
    self:RefreshRuntimeCache(characterKey, "delete_build")

    return {
        characterId = characterKey,
        pageId = pageId,
        deletedBuildId = buildId,
        deletedBuildName = build.displayName or build.name or buildId,
        nextSelectedBuildId = bucket.uiState.selectedBuildIdByPage[pageId],
        remainingCount = #page.buildOrder,
    }
end

function LTM_BUILD_STORE:OverwriteBuildByIdFromCurrentSnapshot(buildId)
    return self:OverwriteBuildByIdFromCurrentSnapshotType(buildId, "all")
end

function LTM_BUILD_STORE:OverwriteBuildByIdFromCurrentSnapshotType(buildId, overwriteType)
    if type(buildId) ~= "string" or buildId == "" then
        return nil, "build_id_missing"
    end

    overwriteType = NormalizeOverwriteType(overwriteType)
    if overwriteType == nil then
        return nil, "overwrite_type_invalid"
    end

    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local page, pageId, existingPersistentBuild =
        FindPersistentBuildLocationById(self, buildId, characterKey, true)
    if type(existingPersistentBuild) ~= "table" then
        return nil, "build_not_found"
    end

    local existingBuild = DecodeBuildForRuntime(existingPersistentBuild)
    local timestamp = ResolveTimestamp()
    local metadata = type(existingBuild.metadata) == "table" and existingBuild.metadata or {}

    if overwriteType == "all" then
        local replacementBuild, err = self:BuildFromCurrentSnapshot()
        if type(replacementBuild) ~= "table" then
            return nil, err
        end

        replacementBuild.id = buildId
        replacementBuild.characterId = characterKey
        replacementBuild.displayName = existingBuild.displayName or existingBuild.name or replacementBuild.displayName
        replacementBuild.name = nil
        replacementBuild.skillSettings = SkillSettings:NormalizeBuild(existingBuild.skillSettings)
        local capturedTransforms = type(replacementBuild.transforms) == "table" and replacementBuild.transforms or {}
        for _, kind in ipairs({ "werewolf", "vampire" }) do
            local existingTransform = type(existingBuild.transforms) == "table"
                and existingBuild.transforms[kind]
                or nil
            if type(capturedTransforms[kind]) == "table" and type(existingTransform) == "table" then
                capturedTransforms[kind].apply = existingTransform.apply ~= false
            elseif capturedTransforms[kind] == nil and type(existingTransform) == "table" then
                capturedTransforms[kind] = Util:DeepCopy(existingTransform)
            end
        end
        if next(capturedTransforms) ~= nil then
            replacementBuild.transforms = capturedTransforms
        elseif type(existingBuild.transforms) == "table"
            and existingBuild.transforms.__decodeError ~= nil then
            replacementBuild.transforms = Util:DeepCopy(existingBuild.transforms)
        else
            replacementBuild.transforms = nil
        end
        local passiveSnapshot, passiveErr, passiveDetails =
            self:CaptureCurrentPassiveSnapshotForBuild(replacementBuild, buildId, "all", existingBuild.passiveSnapshot)
        if type(passiveSnapshot) ~= "table" then
            return nil, passiveErr
        end
        replacementBuild.passiveSnapshot = passiveSnapshot
        if existingBuild.forceChampionRespec ~= nil then
            replacementBuild.forceChampionRespec = ResolveForceChampionRespec(existingBuild.forceChampionRespec)
        end
        replacementBuild.quickslotProfileId = ResolveOptionalLinkId(existingBuild.quickslotProfileId)
        replacementBuild.foodCardId = ResolveOptionalLinkId(existingBuild.foodCardId)
        replacementBuild.metadata = type(replacementBuild.metadata) == "table" and replacementBuild.metadata or {}
        replacementBuild.metadata.createdAt = metadata.createdAt or replacementBuild.metadata.createdAt or timestamp
        replacementBuild.metadata.updatedAt = timestamp
        replacementBuild.metadata.passiveSnapshotCaptureState = type(passiveDetails) == "table"
            and passiveDetails.captureState
            or "full"

        local stored = StoreBuildForPersist(page, buildId, replacementBuild)
        if type(stored) ~= "table" then
            return nil, "build_persist_encode_failed"
        end
        page.buildOrder = NormalizePageBuildOrder(page)
        self:RefreshRuntimeCache(characterKey, "overwrite_build")
        return replacementBuild
    end

    if type(existingBuild.subclass) ~= "table" then
        existingBuild.subclass = {
            targetSkillLineIds = {},
        }
    end
    if type(existingBuild.attributes) ~= "table" then
        existingBuild.attributes = {}
    end
    if type(existingBuild.skills) ~= "table" then
        existingBuild.skills = {
            subclassChanges = {},
            morphChanges = {},
            slots = {},
        }
    end
    if type(existingBuild.equipment) ~= "table" then
        existingBuild.equipment = {}
    end
    if existingBuild.outfit ~= nil and type(existingBuild.outfit) ~= "table" then
        existingBuild.outfit = nil
    end
    if type(existingBuild.championPoints) ~= "table" then
        existingBuild.championPoints = {
            warfare = { slotted = {}, allocated = {} },
            fitness = { slotted = {}, allocated = {} },
            craft = { slotted = {}, allocated = {} },
        }
    end

    if overwriteType == "attributes" then
        local attributes, err = self:CaptureCurrentAttributesForBuild()
        if type(attributes) ~= "table" then
            return nil, err
        end
        existingBuild.attributes = attributes
    elseif overwriteType == "class_skills" then
        local subclassData, subclassErr = self:CaptureCurrentSubclassForBuild()
        if type(subclassData) ~= "table" then
            return nil, subclassErr
        end

        local classMastery = self:CaptureCurrentClassMasteryForBuild()
        local skills = self:CaptureCurrentSkillState()
        local activeSnapshot, activeErr = self:CaptureCurrentActiveSnapshotForBuild()
        if type(activeSnapshot) ~= "table" then
            return nil, activeErr
        end

        existingBuild.subclass = subclassData.subclass or { targetSkillLineIds = {} }
        existingBuild.classMastery = classMastery
        existingBuild.skills = skills
        existingBuild.activeSnapshot = activeSnapshot
    elseif overwriteType == "equipment" then
        local outfit, outfitErr = self:CaptureCurrentOutfitForBuild()
        if type(outfit) ~= "table" then
            return nil, outfitErr
        end
        existingBuild.equipment = self:CaptureCurrentEquipmentForBuild()
        existingBuild.outfit = outfit
    elseif overwriteType == "cp" then
        existingBuild.championPoints = self:CaptureCurrentChampionPointsForBuild()
    elseif overwriteType == "passives" then
        local passiveSnapshot, passiveErr, passiveDetails =
            self:CaptureCurrentPassiveSnapshotForBuild(existingBuild, buildId, "passives", existingBuild.passiveSnapshot)
        if type(passiveSnapshot) ~= "table" then
            return nil, passiveErr
        end
        existingBuild.passiveSnapshot = passiveSnapshot
        existingBuild.metadata = metadata
        existingBuild.metadata.passiveSnapshotCaptureState = type(passiveDetails) == "table"
            and passiveDetails.captureState
            or "full"
    elseif overwriteType == "transform_werewolf" or overwriteType == "transform_vampire" then
        local kind = overwriteType == "transform_werewolf" and "werewolf" or "vampire"
        local captured, captureErr = LTM_TRANSFORM_SKILLS:CaptureAvailableSnapshots(existingBuild.transforms)
        if type(captured) ~= "table" or type(captured[kind]) ~= "table" then
            return nil, captureErr or "transform_skill_line_unavailable:" .. kind
        end
        if type(existingBuild.transforms) ~= "table"
            or existingBuild.transforms.__decodeError ~= nil then
            existingBuild.transforms = {}
        end
        captured[kind].apply = type(existingBuild.transforms[kind]) ~= "table"
            or existingBuild.transforms[kind].apply ~= false
        existingBuild.transforms[kind] = captured[kind]
    end

    existingBuild.metadata = metadata
    existingBuild.metadata.createdAt = metadata.createdAt or timestamp
    existingBuild.metadata.updatedAt = timestamp

    local stored = StoreBuildForPersist(page, buildId, existingBuild)
    if type(stored) ~= "table" then
        return nil, "build_persist_encode_failed"
    end
    self:RefreshRuntimeCache(characterKey, "overwrite_build")
    return existingBuild
end

function LTM_BUILD_STORE:GenerateNextBuildId(characterKey)
    local maxNumber = 0

    local metadata = self:GetCharacterPageMetadataReadonly(characterKey)
    for _, pageId in ipairs(metadata.pageOrder or {}) do
        local page = type(metadata.pages) == "table" and metadata.pages[pageId] or nil
        for _, buildId in ipairs(type(page) == "table" and page.buildOrder or {}) do
            local numberPart = type(buildId) == "string" and string.match(buildId, "^build_(%d+)$") or nil
            local numericValue = numberPart ~= nil and tonumber(numberPart) or nil
            if type(numericValue) == "number" and numericValue > maxNumber then
                maxNumber = numericValue
            end
        end
    end

    return string.format("build_%04d", maxNumber + 1)
end

function LTM_BUILD_STORE:CaptureCurrentSkillState()
    local slots = {}
    local cryptCanonEquipped = IsCryptCanonEquipped()

    for _, hotbarCategory in ipairs(HOTBAR_CATEGORIES) do
        for _, slotIndex in ipairs(SLOT_INDICES) do
            local slotEntry = CaptureCurrentSkillSlot(slotIndex, hotbarCategory)
            local abilityId = slotEntry.abilityId
            if type(abilityId) == "number" and abilityId > 0 then
                -- Do not persist Crypt Canon's equipment-provided ultimate as a
                -- normal skill slot; equipment state is the source of truth.
                if cryptCanonEquipped and IsCryptCanonSpecialUltimateRecord(slotEntry, hotbarCategory, slotIndex) then
                else
                    local slotRecord = {
                        hotbarCategory = hotbarCategory,
                        slot = slotIndex,
                        abilityId = abilityId,
                    }
                    if type(slotEntry.slotActionType) == "number" then
                        slotRecord.slotActionType = slotEntry.slotActionType
                    end
                    if type(slotEntry.craftedAbilityId) == "number" and slotEntry.craftedAbilityId > 0 then
                        slotRecord.craftedAbilityId = slotEntry.craftedAbilityId
                    end
                    if type(slotEntry.scriptIds) == "table" then
                        slotRecord.scriptIds = {
                            slotEntry.scriptIds[1] or 0,
                            slotEntry.scriptIds[2] or 0,
                            slotEntry.scriptIds[3] or 0,
                        }
                    end
                    slots[#slots + 1] = slotRecord
                end
            end
        end
    end

    table.sort(slots, function(left, right)
        if left.hotbarCategory == right.hotbarCategory then
            return left.slot < right.slot
        end

        return left.hotbarCategory < right.hotbarCategory
    end)

    return {
        subclassChanges = {},
        morphChanges = {},
        slots = slots,
    }
end

function LTM_BUILD_STORE:CaptureCurrentSkillBarSnapshot()
    local hotbars = {
        [0] = {},
        [1] = {},
    }

    for _, hotbarCategory in ipairs(HOTBAR_CATEGORIES) do
        for _, slotIndex in ipairs(SLOT_INDICES) do
            hotbars[hotbarCategory][slotIndex] = CaptureCurrentSkillSlot(slotIndex, hotbarCategory)
        end
    end

    return hotbars
end

function LTM_BUILD_STORE:BuildFromCurrentSnapshot()
    local characterKey = self:GetCurrentCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil, "character_id_unavailable"
    end

    local subclassData, subclassErr = self:CaptureCurrentSubclassForBuild()
    if type(subclassData) ~= "table" then
        return nil, subclassErr
    end

    local attributeState, attributeErr = self:CaptureCurrentAttributesForBuild()
    if type(attributeState) ~= "table" then
        return nil, attributeErr
    end

    local equipmentState = self:CaptureCurrentEquipmentForBuild()
    local outfitState, outfitErr = self:CaptureCurrentOutfitForBuild()
    if type(outfitState) ~= "table" then
        return nil, outfitErr
    end
    local championPointState = self:CaptureCurrentChampionPointsForBuild()
    local classMasteryState = self:CaptureCurrentClassMasteryForBuild()
    local roleState = LTM_ROLE_STATE:CaptureCurrentRoleState()
    local timestamp = ResolveTimestamp()

    local warfare = championPointState.warfare or {}
    local fitness = championPointState.fitness or {}
    local craft = championPointState.craft or {}
    Log.LogDebugSummary("Equipment capture summary", "populatedSlots=" .. tostring(CountTableEntries(equipmentState)))
    Log.LogDebugSummary(
        "ChampionPoints capture summary",
        "warfareSlotted=" .. tostring(#(warfare.slotted or {})),
        "fitnessSlotted=" .. tostring(#(fitness.slotted or {})),
        "craftSlotted=" .. tostring(#(craft.slotted or {})),
        "warfareAllocated=" .. tostring(CountTableEntries(warfare.allocated)),
        "fitnessAllocated=" .. tostring(CountTableEntries(fitness.allocated)),
        "craftAllocated=" .. tostring(CountTableEntries(craft.allocated))
    )

    local transforms, transformErr = LTM_TRANSFORM_SKILLS:CaptureAvailableSnapshots(nil)
    if transformErr ~= nil then
        return nil, transformErr
    end

    local build = {
        id = self:GenerateNextBuildId(characterKey),
        characterId = characterKey,
        displayName = subclassData.suggestedName,
        subclass = subclassData.subclass,
        classMastery = classMasteryState,
        skills = self:CaptureCurrentSkillState(),
        attributes = attributeState,
        equipment = equipmentState,
        outfit = outfitState,
        championPoints = championPointState,
        role = roleState,
        transforms = transforms,
        skillSettings = SkillSettings:NormalizeBuild(nil),
        metadata = {
            createdAt = timestamp,
            updatedAt = timestamp,
        },
    }

    local activeSnapshot, activeErr = self:CaptureCurrentActiveSnapshotForBuild()
    if type(activeSnapshot) ~= "table" then
        return nil, activeErr
    end
    build.activeSnapshot = activeSnapshot

    local passiveSnapshot, passiveErr, passiveDetails =
        self:CaptureCurrentPassiveSnapshotForBuild(build, build.id, "new", nil)
    if type(passiveSnapshot) ~= "table" then
        return nil, passiveErr
    end
    build.passiveSnapshot = passiveSnapshot
    build.metadata.passiveSnapshotCaptureState = type(passiveDetails) == "table"
        and passiveDetails.captureState
        or "full"

    return build
end

function LTM_BUILD_STORE:SaveCurrentStateAsNewBuild()
    Log.WriteChat(GetStringValue("SI_LTM_STATUS_SAVE_NEW_CARD_STARTED", "New Card save started"))

    local build, err = self:BuildFromCurrentSnapshot()
    if type(build) ~= "table" then
        return nil, err
    end

    local bucket = EnsureCharacterPagesForWrite(self, build.characterId)
    local pageId = self:GetSelectedPageId(build.characterId)
    if type(bucket.pages[pageId]) ~= "table" then
        pageId = DEFAULT_PAGE_ID
        bucket.pages[pageId] = BuildDefaultPage(pageId)
        bucket.pageOrder = bucket.pageOrder or {}
        local seenPageIds = {}
        local normalizedPageOrder = {}
        for _, orderedPageId in ipairs(bucket.pageOrder) do
            AppendUniqueString(normalizedPageOrder, seenPageIds, orderedPageId)
        end
        AppendUniqueString(normalizedPageOrder, seenPageIds, pageId)
        bucket.pageOrder = normalizedPageOrder
        bucket.uiState.selectedPageId = pageId
    end

    local page = bucket.pages[pageId]
    StoreBuildForPersist(page, build.id, build)
    page.buildOrder = NormalizePageBuildOrder(page)
    bucket.uiState.selectedBuildIdByPage[pageId] = build.id
    self:RefreshRuntimeCache(build.characterId, "save_new_build")

    Log.WriteChat(GetStringValue("SI_LTM_STATUS_SAVE_NEW_CARD_FINISHED", "New Card save finished"))

    return build
end

function LTM_BUILD_STORE:Initialize(savedVars)
    self.savedVars = savedVars
    self.runtimeBuildsByCharacter = {}
    self:RefreshRuntimeCache(nil, "initialize")
end
