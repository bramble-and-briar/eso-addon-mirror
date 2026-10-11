local Addon = LarvalTearMod
local Domains = Addon.Common.Domains
local LTM = Addon
local Log = Addon.Common.Log
local LTM_ATTRIBUTE_SNAPSHOT = Addon.Modules.AttributeSnapshot
local LTM_UI_DISPATCH = Addon.UI.Dispatch
local LTM_SUBCLASS_NAME_HELPER = Addon.SubclassNameHelper
local LTM_SKILL_SNAPSHOT_AUDIT = Addon.Modules.SkillSnapshotAudit
local LTM_SKILL_POINT_RUN_AUDIT = Addon.Modules.SkillPointRunAudit
local LTM_ROLE_STATE = Addon.Modules.RoleState
local LTM_SUBCLASS_SNAPSHOT = Addon.Modules.SubclassSnapshot
local LTM_BUILD_STORE = Addon.Modules.BuildStore
local LTM_TRANSFORM_SKILLS = Addon.Modules.TransformSkills
local LTM_EQUIPMENT_CHANGE = Addon.Modules.EquipmentChange
local LTM_EQUIPMENT_FETCH = Addon.Modules.EquipmentFetch
local LTM_EQUIPMENT_DEPOSIT = Addon.Modules.EquipmentDeposit
local LTM_GEAR_LINK_SUMMARY = Addon.Modules.GearLinkSummary
local LTM_QUICK_SETTINGS_PROFILE_FACADE = Addon.UI.QuickSettings.ProfileFacade

local INVENTORY_SNAPSHOT_EVENT_NAME = "LTM_UI_InventorySnapshotInvalidation"
local INVENTORY_SNAPSHOT_REFRESH_DELAY_MS = 150

local CURRENT_EQUIPMENT_SLOTS = Domains.EquipmentSlotIds
-- Crypt Canon displays an equipment-provided ultimate. The IDs stay local to
-- this display correction so the pseudo-slot path is not mistaken for dead code.
local CRYPT_CANON_ITEM_ID = 194509
local CRYPT_CANON_SPECIAL_ULTIMATE_ID = 195031

local inventorySnapshot = nil
local inventorySnapshotDirty = true
local inventorySnapshotEventsInitialized = false
local inventorySnapshotRefreshScheduled = false
local savedEquipmentStateCacheByCharacter = {}
local activeEquipmentStateCacheCharacterKey = nil
local activeEquipmentStateCacheBuildId = nil

local function GetStringValue(stringIdName, fallback)
    if type(stringIdName) ~= "string" or stringIdName == "" then
        return fallback
    end

    local stringId = rawget(_G, stringIdName)
    local value = type(GetString) == "function" and stringId ~= nil and GetString(stringId) or nil
    if type(value) ~= "string" or value == "" or value == stringIdName then
        return fallback
    end

    return value
end

local function GetBuildDisplayName(buildId, build)
    if type(build) == "table" and type(build.displayName) == "string" and build.displayName ~= "" then
        return build.displayName
    end

    if type(build) == "table" and type(build.name) == "string" and build.name ~= "" then
        return build.name
    end

    return tostring(buildId)
end

local function NormalizeRoleState(role)
    return LTM_ROLE_STATE:NormalizeRoleState(role)
end

local function CaptureCurrentRoleState()
    return LTM_ROLE_STATE:CaptureCurrentRoleState()
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)
    if ok then
        return result
    end

    return nil
end

local function TryStartChatInput(text)
    if type(StartChatInput) ~= "function" or type(text) ~= "string" or text == "" then
        return false
    end

    local ok = pcall(StartChatInput, text)
    return ok == true
end

local function TrySetChatInputText(text)
    if type(text) ~= "string" or text == ""
        or CHAT_SYSTEM == nil
        or CHAT_SYSTEM.textEntry == nil
        or type(CHAT_SYSTEM.textEntry.SetText) ~= "function" then
        return false
    end

    local ok = pcall(CHAT_SYSTEM.textEntry.SetText, CHAT_SYSTEM.textEntry, text)
    return ok == true
end

local function BuildCurrentSkillLineSummary(activeLines)
    return LTM_SUBCLASS_NAME_HELPER:BuildDetailListFromActiveLines(activeLines, {
        includeClass = true,
        preferClassShort = true,
        preferSkillLineShort = false,
    })
end

local function NormalizeDisplayText(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    if type(zo_strformat) == "function" then
        return zo_strformat("<<C:1>>", text)
    end

    return text
end

local function ResolvePassiveSnapshotState(build)
    if type(build) ~= "table" or build.passiveSnapshot == nil then
        return "missing"
    end
    local snapshot = build.passiveSnapshot
    if type(snapshot) ~= "table" or type(snapshot.lines) ~= "table" then
        return "invalid"
    end

    for _, lineEntries in pairs(snapshot.lines) do
        if type(lineEntries) == "table" then
            for _ in pairs(lineEntries) do
                return "saved"
            end
        end
    end

    return "empty"
end

local function ResolveActiveSnapshotState(build)
    if type(build) ~= "table" or build.activeSnapshot == nil then
        return "missing"
    end

    return "saved"
end

local function BuildSavedSubclassSummary(subclassIds)
    local names = LTM_SUBCLASS_NAME_HELPER:BuildDetailListFromIds(subclassIds, {
        includeClass = true,
        preferClassShort = true,
        preferSkillLineShort = true,
    })

    if #names == 0 then
        return GetStringValue("SI_LTM_COMMON_NONE", "")
    end

    return table.concat(names, " / ")
end

local function BuildSavedSkillLineSummaryList(subclassIds)
    return LTM_SUBCLASS_NAME_HELPER:BuildDetailListFromIds(subclassIds, {
        includeClass = true,
        preferClassShort = true,
        preferSkillLineShort = false,
    })
end

local function BuildSavedAttributeSummary(attributes)
    attributes = type(attributes) == "table" and attributes or {}
    return string.format(
        "HP %d / MP %d / ST %d",
        tonumber(attributes.health) or 0,
        tonumber(attributes.magicka) or 0,
        tonumber(attributes.stamina) or 0
    )
end

local function GetUnlockedOutfitCount()
    local count = SafeCall(GetNumUnlockedOutfits, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if type(count) == "number" and count >= 0 and count % 1 == 0 then
        return count
    end
    return nil
end

local function ResolveOutfitName(outfitState, unlockedCount, concise)
    if outfitState == nil then
        if concise then
            return GetStringValue("SI_LTM_OUTFIT_NONE_SHORT", "None")
        end
        return GetStringValue("SI_LTM_OUTFIT_NONE", "None (leave unchanged)")
    end
    if type(outfitState) ~= "table" then
        return GetStringValue("SI_LTM_COMMON_UNKNOWN", "Unknown")
    end
    if outfitState.mode == "default" and outfitState.equippedOutfitIndex == nil then
        if concise then
            return GetStringValue("SI_LTM_OUTFIT_DEFAULT_SHORT", "Default")
        end
        return GetStringValue("SI_LTM_OUTFIT_DEFAULT", "Default (remove outfit)")
    end
    local outfitIndex = outfitState.equippedOutfitIndex
    if outfitState.mode ~= nil or type(outfitIndex) ~= "number" or outfitIndex < 1 or outfitIndex % 1 ~= 0 then
        return GetStringValue("SI_LTM_COMMON_UNKNOWN", "Unknown")
    end
    local label = string.format("%s %d", GetStringValue("SI_LTM_COMMON_OUTFIT", "Outfit"), outfitIndex)
    local count = unlockedCount
    if count == nil then
        count = GetUnlockedOutfitCount()
    end
    if count == nil then
        return label .. " (" .. GetStringValue("SI_LTM_COMMON_UNKNOWN", "Unknown") .. ")"
    end
    if outfitIndex > count then
        return label .. " (" .. GetStringValue("SI_LTM_OUTFIT_UNAVAILABLE", "Unavailable") .. ")"
    end
    local name = SafeCall(GetOutfitName, GAMEPLAY_ACTOR_CATEGORY_PLAYER, outfitIndex)
    if type(name) == "string" and name ~= "" then
        return NormalizeDisplayText(name)
    end
    return label
end

local function ResolveCurrentOutfitName()
    local outfit, err = LTM_BUILD_STORE:CaptureCurrentOutfitForBuild()
    if err ~= nil then
        return GetStringValue("SI_LTM_COMMON_UNKNOWN", "Unknown")
    end
    return ResolveOutfitName(outfit, nil, true)
end

local function ResolveSavedEquipmentItemName(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    if type(GetItemLinkName) == "function" then
        local ok, itemName = pcall(GetItemLinkName, itemLink)
        if ok and type(itemName) == "string" and itemName ~= "" then
            return NormalizeDisplayText(itemName)
        end
    end

    return itemLink
end

local function ResolveSavedEquipmentTraitName(slotEntry, itemLink)
    local traitName = type(slotEntry) == "table" and slotEntry.traitName or nil
    if type(traitName) == "string" and traitName ~= "" then
        return NormalizeDisplayText(traitName)
    end

    local traitType = type(slotEntry) == "table" and slotEntry.traitType or nil
    if type(traitType) == "number" and traitType > 0 and type(GetString) == "function" then
        local localizedTrait = GetString("SI_ITEMTRAITTYPE", traitType)
        if type(localizedTrait) == "string" and localizedTrait ~= "" then
            return NormalizeDisplayText(localizedTrait)
        end
    end

    if type(itemLink) == "string" and itemLink ~= "" and type(GetItemLinkTraitInfo) == "function" and type(GetString) == "function" then
        local resolvedTraitType = GetItemLinkTraitInfo(itemLink)
        if type(resolvedTraitType) == "number" and resolvedTraitType > 0 then
            local localizedTrait = GetString("SI_ITEMTRAITTYPE", resolvedTraitType)
            if type(localizedTrait) == "string" and localizedTrait ~= "" then
                return NormalizeDisplayText(localizedTrait)
            end
        end
    end

    return nil
end

local function ResolveSavedEquipmentQualityColor(slotEntry, itemLink)
    local quality = type(slotEntry) == "table" and slotEntry.quality or nil
    if type(quality) ~= "number" and type(itemLink) == "string" and itemLink ~= "" and type(GetItemLinkDisplayQuality) == "function" then
        quality = GetItemLinkDisplayQuality(itemLink)
    end

    if type(quality) ~= "number" or type(GetItemQualityColor) ~= "function" then
        return nil
    end

    local qualityColor = GetItemQualityColor(quality)
    if qualityColor ~= nil and type(qualityColor.UnpackRGB) == "function" then
        local r, g, b = qualityColor:UnpackRGB()
        return {
            r = r,
            g = g,
            b = b,
        }
    end

    return nil
end

local function ResolveSavedChampionSkillName(championSkillId)
    if type(championSkillId) ~= "number" or championSkillId <= 0 then
        return nil
    end

    if type(GetChampionSkillName) == "function" then
        local ok, skillName = pcall(GetChampionSkillName, championSkillId)
        if ok and type(skillName) == "string" and skillName ~= "" then
            return NormalizeDisplayText(skillName)
        end
    end

    return tostring(championSkillId)
end

local function GetSavedChampionGroupSlottedIds(groupData)
    if type(groupData) ~= "table" then
        return {}
    end

    local source = type(groupData.slotted) == "table" and groupData.slotted or groupData
    local starIds = {}
    for _, championSkillId in ipairs(source) do
        if type(championSkillId) == "number" and championSkillId > 0 then
            starIds[#starIds + 1] = championSkillId
        end
    end
    return starIds
end

local function BuildCurrentEquipmentState()
    local state = {
        isConnected = false,
        entries = {},
    }

    if type(GetItemLink) ~= "function"
        or type(GetItemLinkName) ~= "function"
        or type(GetItemLinkTraitInfo) ~= "function"
        or type(GetItemLinkDisplayQuality) ~= "function" then
        return state
    end

    state.isConnected = true

    for _, equipSlot in ipairs(CURRENT_EQUIPMENT_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, equipSlot, LINK_STYLE_DEFAULT)
        local itemName = type(itemLink) == "string" and itemLink ~= "" and GetItemLinkName(itemLink) or nil
        if type(itemName) == "string" and itemName ~= "" then
            local traitType = GetItemLinkTraitInfo(itemLink)
            local traitName = nil
            if type(traitType) == "number" and traitType > 0 and type(GetString) == "function" then
                local localizedTrait = GetString("SI_ITEMTRAITTYPE", traitType)
                if type(localizedTrait) == "string" and localizedTrait ~= "" then
                    traitName = NormalizeDisplayText(localizedTrait)
                end
            end

            local displayName = NormalizeDisplayText(itemName)
            local qualityR, qualityG, qualityB = 1.0, 1.0, 1.0
            local quality = GetItemLinkDisplayQuality(itemLink)
            if type(GetItemQualityColor) == "function" then
                local qualityColor = GetItemQualityColor(quality)
                if qualityColor ~= nil and type(qualityColor.UnpackRGB) == "function" then
                    qualityR, qualityG, qualityB = qualityColor:UnpackRGB()
                end
            end

            state.entries[#state.entries + 1] = {
                slot = equipSlot,
                itemLink = itemLink,
                itemName = displayName,
                traitName = traitName,
                qualityColor = {
                    r = qualityR,
                    g = qualityG,
                    b = qualityB,
                },
            }
        end
    end

    return state
end

local function IterateInventorySnapshotBagSlots(bagId)
    if bagId == BAG_WORN then
        local index = 0
        return function()
            local equipSlotId = CURRENT_EQUIPMENT_SLOTS[index + 1]
            index = index + 1
            return equipSlotId
        end
    end

    if type(ZO_IterateBagSlots) == "function" then
        return ZO_IterateBagSlots(bagId)
    end

    local bagSize = type(GetBagSize) == "function" and GetBagSize(bagId) or -1
    local index = -1
    return function()
        index = index + 1
        if index <= bagSize then
            return index
        end
        return nil
    end
end

local function BuildInventorySnapshotItemState(bagId, slotIndex)
    if type(GetItemLink) ~= "function" then
        return nil
    end

    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    local itemName = type(GetItemLinkName) == "function" and GetItemLinkName(itemLink) or nil
    if type(itemLink) ~= "string" or itemLink == ""
        or (type(GetItemLinkName) == "function" and (type(itemName) ~= "string" or itemName == "")) then
        return nil
    end

    local itemId = type(GetItemId) == "function" and GetItemId(bagId, slotIndex) or nil
    if (type(itemId) ~= "number" or itemId <= 0) and type(GetItemLinkItemId) == "function" then
        itemId = GetItemLinkItemId(itemLink)
    end

    local traitType = type(GetItemLinkTraitInfo) == "function" and GetItemLinkTraitInfo(itemLink) or nil
    local quality = type(GetItemLinkDisplayQuality) == "function" and GetItemLinkDisplayQuality(itemLink) or nil
    local uniqueId = type(GetItemUniqueId) == "function" and GetItemUniqueId(bagId, slotIndex) or nil
    if uniqueId ~= nil and type(Id64ToString) == "function" then
        uniqueId = Id64ToString(uniqueId)
    end

    return {
        bagId = bagId,
        slotIndex = slotIndex,
        uniqueId = type(uniqueId) == "string" and uniqueId ~= "" and uniqueId or nil,
        itemLink = itemLink,
        itemId = type(itemId) == "number" and itemId > 0 and itemId or nil,
        traitType = type(traitType) == "number" and traitType > 0 and traitType or nil,
        quality = type(quality) == "number" and quality or nil,
    }
end

local function BuildInventorySnapshotCompositeKey(itemId, traitType, quality)
    if type(itemId) ~= "number" or itemId <= 0 then
        return nil
    end

    return tostring(itemId)
        .. "|t=" .. tostring(type(traitType) == "number" and traitType or 0)
        .. "|q=" .. tostring(type(quality) == "number" and quality or 0)
end

local function AddInventorySnapshotIndexValue(index, key, itemState)
    if type(key) ~= "string" or key == "" or type(itemState) ~= "table" then
        return
    end

    if index[key] == nil then
        index[key] = itemState
    end
end

local function BuildInventorySnapshot()
    local snapshot = {
        uniqueIds = {},
        itemLinks = {},
        compositeKeys = {},
        itemIds = {},
    }

    for _, bagId in ipairs({ BAG_WORN, BAG_BACKPACK }) do
        for slotIndex in IterateInventorySnapshotBagSlots(bagId) do
            local itemState = BuildInventorySnapshotItemState(bagId, slotIndex)
            if type(itemState) == "table" then
                AddInventorySnapshotIndexValue(snapshot.uniqueIds, itemState.uniqueId, itemState)
                AddInventorySnapshotIndexValue(snapshot.itemLinks, itemState.itemLink, itemState)
                AddInventorySnapshotIndexValue(
                    snapshot.compositeKeys,
                    BuildInventorySnapshotCompositeKey(itemState.itemId, itemState.traitType, itemState.quality),
                    itemState
                )
                if type(itemState.itemId) == "number" then
                    local itemIdMatches = snapshot.itemIds[itemState.itemId]
                    if type(itemIdMatches) ~= "table" then
                        itemIdMatches = {}
                        snapshot.itemIds[itemState.itemId] = itemIdMatches
                    end
                    itemIdMatches[#itemIdMatches + 1] = itemState
                end
            end
        end
    end

    inventorySnapshot = snapshot
    inventorySnapshotDirty = false

    return snapshot
end

local function GetInventorySnapshot()
    if inventorySnapshot == nil or inventorySnapshotDirty == true then
        return BuildInventorySnapshot()
    end

    return inventorySnapshot
end

local function LookupInventorySnapshotTarget(targetEntry)
    local snapshot = GetInventorySnapshot()
    local matchedItem = nil

    if type(targetEntry) ~= "table" or type(snapshot) ~= "table" then
        return false
    elseif targetEntry.uniqueId ~= nil then
        matchedItem = snapshot.uniqueIds[targetEntry.uniqueId]
    elseif targetEntry.itemLink ~= nil and snapshot.itemLinks[targetEntry.itemLink] ~= nil then
        matchedItem = snapshot.itemLinks[targetEntry.itemLink]
    elseif targetEntry.itemId ~= nil then
        if targetEntry.traitType ~= nil and targetEntry.quality ~= nil then
            matchedItem = snapshot.compositeKeys[BuildInventorySnapshotCompositeKey(
                targetEntry.itemId,
                targetEntry.traitType,
                targetEntry.quality
            )]
        else
            for _, itemState in ipairs(snapshot.itemIds[targetEntry.itemId] or {}) do
                local traitMatches = targetEntry.traitType == nil or targetEntry.traitType == itemState.traitType
                local qualityMatches = targetEntry.quality == nil or targetEntry.quality == itemState.quality
                if traitMatches and qualityMatches then
                    matchedItem = itemState
                    break
                end
            end
        end
    end

    return matchedItem ~= nil
end

local function GetCurrentChampionIconTexture(championSkillId)
    if type(championSkillId) ~= "number" or championSkillId <= 0 then
        return nil
    end

    local skillData = nil
    if type(CHAMPION_DATA_MANAGER) == "table" and type(CHAMPION_DATA_MANAGER.GetChampionSkillData) == "function" then
        local ok, result = pcall(CHAMPION_DATA_MANAGER.GetChampionSkillData, CHAMPION_DATA_MANAGER, championSkillId)
        if ok then
            skillData = result
        end
    elseif type(GetChampionSkillData) == "function" then
        local ok, result = pcall(GetChampionSkillData, championSkillId)
        if ok then
            skillData = result
        end
    end

    if skillData ~= nil and type(skillData.GetAbilityId) == "function" and type(GetAbilityIcon) == "function" then
        local ok, abilityId = pcall(skillData.GetAbilityId, skillData)
        if ok and type(abilityId) == "number" and abilityId > 0 then
            local iconOk, iconTexture = pcall(GetAbilityIcon, abilityId)
            if iconOk and type(iconTexture) == "string" and iconTexture ~= "" then
                return iconTexture
            end
        end
    end

    if type(GetChampionAbilityId) == "function" and type(GetAbilityIcon) == "function" then
        local ok, abilityId = pcall(GetChampionAbilityId, championSkillId)
        if ok and type(abilityId) == "number" and abilityId > 0 then
            local iconOk, iconTexture = pcall(GetAbilityIcon, abilityId)
            if iconOk and type(iconTexture) == "string" and iconTexture ~= "" then
                return iconTexture
            end
        end
    end

    if type(ZO_GetChampionPointsIconSmall) == "function" then
        local ok, iconTexture = pcall(ZO_GetChampionPointsIconSmall)
        if ok and type(iconTexture) == "string" and iconTexture ~= "" then
            return iconTexture
        end
    end

    return nil
end

local function GetCurrentChampionDisciplineType(championSkillId)
    if type(championSkillId) ~= "number" or championSkillId <= 0 then
        return nil
    end

    local skillData = nil
    if type(CHAMPION_DATA_MANAGER) == "table" and type(CHAMPION_DATA_MANAGER.GetChampionSkillData) == "function" then
        local ok, result = pcall(CHAMPION_DATA_MANAGER.GetChampionSkillData, CHAMPION_DATA_MANAGER, championSkillId)
        if ok then
            skillData = result
        end
    elseif type(GetChampionSkillData) == "function" then
        local ok, result = pcall(GetChampionSkillData, championSkillId)
        if ok then
            skillData = result
        end
    end

    if skillData ~= nil
        and type(skillData.GetChampionDisciplineData) == "function" then
        local ok, disciplineData = pcall(skillData.GetChampionDisciplineData, skillData)
        if ok
            and disciplineData ~= nil
            and type(disciplineData.GetType) == "function" then
            local disciplineOk, disciplineType = pcall(disciplineData.GetType, disciplineData)
            if disciplineOk and type(disciplineType) == "number" then
                return disciplineType
            end
        end
    end

    if type(GetChampionDisciplineType) == "function" then
        local ok, disciplineType = pcall(GetChampionDisciplineType, championSkillId)
        if ok and type(disciplineType) == "number" then
            return disciplineType
        end
    end

    return nil
end

local function GetCurrentChampionSkillId(slotIndex)
    if type(GetSlotBoundId) ~= "function" then
        return nil
    end

    local championSkillId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION)
    if type(championSkillId) ~= "number" or championSkillId <= 0 then
        return nil
    end

    return championSkillId
end

local function BuildCurrentChampionState()
    local state = {
        isConnected = false,
        groups = {},
    }

    if type(GetSlotBoundId) ~= "function" or type(GetChampionSkillName) ~= "function" then
        return state
    end

    state.isConnected = true

    for _, group in ipairs(Domains.ChampionGroups) do
        local groupState = {
            id = group.id,
            entries = {},
        }

        for _, slotIndex in ipairs(group.slots or {}) do
            local championSkillId = GetCurrentChampionSkillId(slotIndex)
            if championSkillId ~= nil then
                local championSkillName = GetChampionSkillName(championSkillId)
                local displayName = NormalizeDisplayText(championSkillName)

                groupState.entries[#groupState.entries + 1] = {
                    slot = slotIndex,
                    championSkillId = championSkillId,
                    skillName = displayName ~= "" and displayName or tostring(championSkillId),
                    iconTexture = GetCurrentChampionIconTexture(championSkillId),
                    disciplineType = GetCurrentChampionDisciplineType(championSkillId),
                }
            end
        end

        state.groups[#state.groups + 1] = groupState
    end

    return state
end

local function CountAssignedSkillSlots(skillState)
    local counts = {
        front = 0,
        back = 0,
    }

    local slots = type(skillState) == "table" and skillState.slots or nil
    for _, slot in ipairs(slots or {}) do
        if slot.hotbarCategory == 1 then
            counts.back = counts.back + 1
        else
            counts.front = counts.front + 1
        end
    end

    return counts
end

local function ResolveBuildSlotAbilityName(abilityId)
    if type(abilityId) ~= "number" or abilityId <= 0 or type(GetAbilityName) ~= "function" then
        return nil
    end

    local ok, abilityName = pcall(GetAbilityName, abilityId)
    if ok and type(abilityName) == "string" and abilityName ~= "" then
        return NormalizeDisplayText(abilityName)
    end

    return nil
end

local function ResolveBuildSlotIconTexture(abilityId)
    if type(abilityId) ~= "number" or abilityId <= 0 or type(GetAbilityIcon) ~= "function" then
        return nil
    end

    local ok, iconTexture = pcall(GetAbilityIcon, abilityId)
    if ok and type(iconTexture) == "string" and iconTexture ~= "" then
        return iconTexture
    end

    return nil
end

local function BuildSavedClassMasteryState(classMastery)
    local state = {
        targetSkillLineId = type(classMastery) == "table" and tonumber(classMastery.targetSkillLineId) or nil,
        entries = {},
    }
    local purchasedAbilities = type(classMastery) == "table" and classMastery.purchasedAbilities or nil
    if type(purchasedAbilities) ~= "table" then
        return state
    end

    local abilityIds = {}
    for abilityId, rank in pairs(purchasedAbilities) do
        local normalizedAbilityId = tonumber(abilityId)
        local normalizedRank = tonumber(rank)
        if normalizedAbilityId ~= nil and normalizedAbilityId > 0 and normalizedRank ~= nil and normalizedRank > 0 then
            abilityIds[#abilityIds + 1] = math.floor(normalizedAbilityId)
        end
    end
    table.sort(abilityIds)

    for _, abilityId in ipairs(abilityIds) do
        local iconTexture = ResolveBuildSlotIconTexture(abilityId)
        if type(iconTexture) == "string" and iconTexture ~= "" then
            state.entries[#state.entries + 1] = {
                abilityId = abilityId,
                abilityName = ResolveBuildSlotAbilityName(abilityId),
                iconTexture = iconTexture,
            }
        end
        if #state.entries >= 2 then
            break
        end
    end

    return state
end

local function HasCryptCanonInEquipment(equipment)
    local chestEntry = type(equipment) == "table" and equipment[EQUIP_SLOT_CHEST] or nil
    local itemId = type(chestEntry) == "table" and tonumber(chestEntry.itemId) or nil
    if itemId == CRYPT_CANON_ITEM_ID then
        return true
    end

    local itemLink = type(chestEntry) == "table" and chestEntry.itemLink or nil
    if type(itemLink) == "string" and itemLink ~= "" and type(GetItemLinkItemId) == "function" then
        return GetItemLinkItemId(itemLink) == CRYPT_CANON_ITEM_ID
    end

    return false
end

local function BuildPseudoCryptCanonUltimateSlot(hotbarCategory)
    -- Display-only pseudo slot for Crypt Canon. The saved build does not own
    -- this as a regular skill target, but the UI should still show the ultimate.
    return {
        hotbarCategory = hotbarCategory,
        slot = 8,
        abilityId = nil,
        abilityName = ResolveBuildSlotAbilityName(CRYPT_CANON_SPECIAL_ULTIMATE_ID),
        iconTexture = ResolveBuildSlotIconTexture(CRYPT_CANON_SPECIAL_ULTIMATE_ID),
        isEmpty = false,
        isPseudoCryptCanonUltimate = true,
    }
end

local function BuildSavedSkillBarState(skillState, equipment)
    local bars = {
        front = {},
        back = {},
    }

    for slotIndex = 3, 8 do
        bars.front[#bars.front + 1] = {
            hotbarCategory = 0,
            slot = slotIndex,
            abilityId = nil,
            abilityName = nil,
            iconTexture = nil,
            isEmpty = true,
        }
        bars.back[#bars.back + 1] = {
            hotbarCategory = 1,
            slot = slotIndex,
            abilityId = nil,
            abilityName = nil,
            iconTexture = nil,
            isEmpty = true,
        }
    end

    for _, slot in ipairs(type(skillState) == "table" and skillState.slots or {}) do
        local hotbarCategory = type(slot) == "table" and slot.hotbarCategory or nil
        local slotIndex = type(slot) == "table" and (slot.slot or slot.slotIndex) or nil
        local abilityId = type(slot) == "table" and slot.abilityId or nil
        local targetBar = hotbarCategory == 1 and bars.back or bars.front
        local targetArrayIndex = type(slotIndex) == "number" and (slotIndex - 2) or nil

        if targetArrayIndex ~= nil and targetArrayIndex >= 1 and targetArrayIndex <= 6 then
            targetBar[targetArrayIndex] = {
                hotbarCategory = hotbarCategory == 1 and 1 or 0,
                slot = slotIndex,
                abilityId = abilityId,
                abilityName = ResolveBuildSlotAbilityName(abilityId),
                iconTexture = ResolveBuildSlotIconTexture(abilityId),
                isEmpty = not (type(abilityId) == "number" and abilityId > 0),
            }
        end
    end

    if HasCryptCanonInEquipment(equipment) then
        -- Fill only empty ultimate slots so normal saved ultimates still win.
        if type(bars.front[6]) == "table" and bars.front[6].isEmpty ~= false then
            bars.front[6] = BuildPseudoCryptCanonUltimateSlot(0)
        end
        if type(bars.back[6]) == "table" and bars.back[6].isEmpty ~= false then
            bars.back[6] = BuildPseudoCryptCanonUltimateSlot(1)
        end
    end

    return bars
end

local function BuildSavedEquipmentState(equipment)
    local state = {
        isConnected = true,
        entries = {},
    }

    equipment = type(equipment) == "table" and equipment or {}

    for _, equipSlot in ipairs(CURRENT_EQUIPMENT_SLOTS) do
        local slotEntry = equipment[equipSlot]
        local itemLink = type(slotEntry) == "table" and slotEntry.itemLink or nil
        local itemName = ResolveSavedEquipmentItemName(itemLink)

        if type(itemName) == "string" and itemName ~= "" then
            local targetEntry = LTM_EQUIPMENT_CHANGE:NormalizeTargetEntry(slotEntry)
            local isOwnedNow = true
            if targetEntry ~= nil
                and type(GetItemLink) == "function" then
                isOwnedNow = LookupInventorySnapshotTarget(targetEntry) == true
            end

            local traitName = ResolveSavedEquipmentTraitName(slotEntry, itemLink)
            local qualityColor = ResolveSavedEquipmentQualityColor(slotEntry, itemLink)

            state.entries[#state.entries + 1] = {
                slot = equipSlot,
                itemLink = itemLink,
                itemName = itemName,
                traitName = traitName,
                qualityColor = qualityColor,
                isOwnedNow = isOwnedNow,
            }
        end
    end

    return state
end

local function GetEquipmentStateCacheCharacterKey(build)
    local characterKey = LTM_BUILD_STORE:GetCurrentCharacterKey()
    if characterKey == nil and type(build) == "table" then
        characterKey = build.characterId
    end
    if characterKey == nil then
        return nil
    end

    characterKey = tostring(characterKey)
    return characterKey ~= "" and characterKey or nil
end

local function GetEquipmentStateCacheReference(buildId, build)
    local equipment = type(build) == "table" and type(build.equipment) == "table" and build.equipment or nil
    if type(buildId) ~= "string" or buildId == "" then
        return equipment
    end

    local buildList = LTM_BUILD_STORE:GetBuildListForCurrentCharacter()
    local runtimeBuild = type(buildList) == "table" and buildList[buildId] or nil
    if type(runtimeBuild) == "table" and type(runtimeBuild.equipment) == "table" then
        return runtimeBuild.equipment
    end

    return equipment
end

local function ClearSavedEquipmentStateCacheForBuild(buildId, characterKey)
    if type(buildId) ~= "string" or buildId == "" then
        return false
    end

    characterKey = characterKey or GetEquipmentStateCacheCharacterKey(nil)
    local characterCache = type(characterKey) == "string" and savedEquipmentStateCacheByCharacter[characterKey] or nil
    if type(characterCache) ~= "table" or characterCache[buildId] == nil then
        return false
    end

    characterCache[buildId] = nil
    return true
end

local function ClearSavedEquipmentStateCacheForCurrentCharacter()
    local characterKey = GetEquipmentStateCacheCharacterKey(nil)
    if characterKey == nil or savedEquipmentStateCacheByCharacter[characterKey] == nil then
        return false
    end

    savedEquipmentStateCacheByCharacter[characterKey] = nil
    return true
end

local function ActivateSavedEquipmentStateCache(characterKey, buildId)
    if activeEquipmentStateCacheCharacterKey == characterKey
        and activeEquipmentStateCacheBuildId == buildId then
        return
    end

    ClearSavedEquipmentStateCacheForBuild(
        activeEquipmentStateCacheBuildId,
        activeEquipmentStateCacheCharacterKey
    )
    activeEquipmentStateCacheCharacterKey = characterKey
    activeEquipmentStateCacheBuildId = buildId
end

local function GetSavedEquipmentStateForBuild(buildId, build)
    if type(build) ~= "table" then
        return BuildSavedEquipmentState(nil)
    end

    local equipmentReference = GetEquipmentStateCacheReference(buildId, build)
    local characterKey = GetEquipmentStateCacheCharacterKey(build)
    if characterKey == nil or type(buildId) ~= "string" or buildId == "" then
        return BuildSavedEquipmentState(equipmentReference)
    end

    ActivateSavedEquipmentStateCache(characterKey, buildId)
    local characterCache = savedEquipmentStateCacheByCharacter[characterKey]
    if type(characterCache) ~= "table" then
        characterCache = {}
        savedEquipmentStateCacheByCharacter[characterKey] = characterCache
    end

    local cache = characterCache[buildId]
    if type(cache) == "table"
        and cache.equipmentReference == equipmentReference
        and type(cache.state) == "table" then
        return cache.state
    end

    local state = BuildSavedEquipmentState(equipmentReference)
    characterCache[buildId] = {
        equipmentReference = equipmentReference,
        state = state,
    }
    return state
end

local function ScheduleInventorySnapshotTargetRefresh()
    if inventorySnapshotRefreshScheduled == true then
        return
    end
    if type(zo_callLater) ~= "function" then
        return
    end

    inventorySnapshotRefreshScheduled = true
    zo_callLater(function()
        inventorySnapshotRefreshScheduled = false
        local UI = Addon.UI
        if UI.window ~= nil
            and type(UI.window.IsHidden) == "function"
            and UI.window:IsHidden() ~= true
            and UI:IsArmoryStationTabActive()
            and UI:GetRightPaneMode() == "target" then
            UI:RefreshRightPanePanel()
        end
    end, INVENTORY_SNAPSHOT_REFRESH_DELAY_MS)
end

local function MarkInventorySnapshotDirty(options)
    options = type(options) == "table" and options or {}
    inventorySnapshotDirty = true
    if options.destroy == true then
        inventorySnapshot = nil
    end

    ClearSavedEquipmentStateCacheForCurrentCharacter()

    if options.refreshTarget == true then
        ScheduleInventorySnapshotTargetRefresh()
    end
end

local function BuildSavedChampionState(championPoints)
    local state = {
        isConnected = true,
        groups = {},
    }

    championPoints = type(championPoints) == "table" and championPoints or {}

    for _, group in ipairs(Domains.ChampionGroups) do
        local groupState = {
            id = group.id,
            entries = {},
        }

        for _, championSkillId in ipairs(GetSavedChampionGroupSlottedIds(championPoints[group.id])) do
            groupState.entries[#groupState.entries + 1] = {
                championSkillId = championSkillId,
                skillName = ResolveSavedChampionSkillName(championSkillId),
                iconTexture = nil,
                disciplineType = nil,
            }
        end

        state.groups[#state.groups + 1] = groupState
    end

    return state
end

local function BuildEmptyTargetStateSummary()
    return {
        currentSkillLineNames = {},
        attributes = {
            health = 0,
            magicka = 0,
            stamina = 0,
        },
        skillCounts = {
            front = 0,
            back = 0,
        },
        equipmentState = BuildSavedEquipmentState(nil),
        championState = BuildSavedChampionState(nil),
        targetAvailable = false,
        targetBuildSource = nil,
        targetBuildName = nil,
        outfitName = GetStringValue("SI_LTM_OUTFIT_NONE_SHORT", "None"),
        role = nil,
        classMasteryState = BuildSavedClassMasteryState(nil),
    }
end

function LTM_UI_DISPATCH:InitializeInventorySnapshotInvalidation()
    if inventorySnapshotEventsInitialized == true then
        return
    end
    if type(EVENT_MANAGER) ~= "table" or type(EVENT_MANAGER.RegisterForEvent) ~= "function" then
        return
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE == nil then
        return
    end

    inventorySnapshotEventsInitialized = true
    EVENT_MANAGER:RegisterForEvent(INVENTORY_SNAPSHOT_EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
        if bagId ~= BAG_WORN and bagId ~= BAG_BACKPACK then
            return
        end

        MarkInventorySnapshotDirty({
            refreshTarget = true,
        })
    end)
end

function LTM_UI_DISPATCH:DestroyInventorySnapshot()
    MarkInventorySnapshotDirty({
        destroy = true,
    })
    activeEquipmentStateCacheCharacterKey = nil
    activeEquipmentStateCacheBuildId = nil
end

local function BuildCurrentSkillBarState(hotbarSnapshot)
    local bars = {
        front = {},
        back = {},
    }

    local frontHotbar = type(hotbarSnapshot) == "table" and hotbarSnapshot[0] or nil
    local backHotbar = type(hotbarSnapshot) == "table" and hotbarSnapshot[1] or nil

    for slotIndex = 3, 8 do
        bars.front[#bars.front + 1] = type(frontHotbar) == "table" and frontHotbar[slotIndex] or {
            hotbarCategory = 0,
            slot = slotIndex,
            isEmpty = true,
        }
        bars.back[#bars.back + 1] = type(backHotbar) == "table" and backHotbar[slotIndex] or {
            hotbarCategory = 1,
            slot = slotIndex,
            isEmpty = true,
        }
    end

    return bars
end

local function BuildCurrentEffectState()
    local state = {
        isConnected = false,
        hasActiveEffect = false,
        activeEffectCount = 0,
        primaryEffectName = nil,
        foodIconTexture = nil,
        foodEffectName = nil,
        hasFoodEffect = false,
    }

    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return state
    end

    state.isConnected = true

    local numBuffs = GetNumBuffs("player")
    for index = 1, numBuffs do
        local buffName, _, _, buffSlot = GetUnitBuffInfo("player", index)
        if type(buffSlot) == "number" and buffSlot > 0 and type(buffName) == "string" and buffName ~= "" then
            state.activeEffectCount = state.activeEffectCount + 1
            if state.primaryEffectName == nil then
                state.primaryEffectName = buffName
            end
        end
    end

    state.hasActiveEffect = state.activeEffectCount > 0
    if state.activeEffectCount ~= 1 then
        state.primaryEffectName = nil
    end

    return state
end

function LTM_UI_DISPATCH:GetBuildList()
    local entries = self:GetBuildEntries()
    local list = {}
    for _, entry in ipairs(entries or {}) do
        if type(entry) == "table" and type(entry.buildId) == "string" and type(entry.build) == "table" then
            list[entry.buildId] = entry.build
        end
    end

    return list
end

function LTM_UI_DISPATCH:GetBuildEntries()
    return LTM_BUILD_STORE:GetRuntimeBuildEntriesForSelectedPage()
end

function LTM_UI_DISPATCH:GetBuildIdByOrdinalForSelectedPage(ordinal)
    return LTM_BUILD_STORE:GetBuildIdByOrdinalForSelectedPage(ordinal)
end

function LTM_UI_DISPATCH:GetPageBuildCount(pageId)
    return LTM_BUILD_STORE:GetPageBuildCount(pageId)
end

function LTM_UI_DISPATCH:IsRuntimeCacheAvailable()
    return LTM_BUILD_STORE:IsRuntimeCacheAvailable() == true
end

function LTM_UI_DISPATCH:GetPageEntries()
    return LTM_BUILD_STORE:GetPageList()
end

function LTM_UI_DISPATCH:GetSelectedPageId()
    return LTM_BUILD_STORE:GetSelectedPageId()
end

function LTM_UI_DISPATCH:GetPageNavigationState()
    local pageEntries = self:GetPageEntries()
    local selectedPageId = self:GetSelectedPageId()
    local selectedIndex = 0

    for index, entry in ipairs(pageEntries) do
        if type(entry) == "table" and entry.pageId == selectedPageId then
            selectedIndex = index
            break
        end
    end

    if selectedIndex == 0 and #pageEntries > 0 then
        selectedIndex = 1
        selectedPageId = pageEntries[1].pageId
    end

    local selectedEntry = pageEntries[selectedIndex]
    local previousPageId = selectedIndex > 1 and pageEntries[selectedIndex - 1] and pageEntries[selectedIndex - 1].pageId or nil
    local nextPageId = selectedIndex > 0 and pageEntries[selectedIndex + 1] and pageEntries[selectedIndex + 1].pageId or nil

    return {
        selectedPageId = selectedPageId,
        selectedPageName = type(selectedEntry) == "table" and (selectedEntry.name or selectedEntry.pageId)
            or (type(GetString) == "function" and rawget(_G, "SI_LTM_PAGE_DEFAULT_NAME") ~= nil and GetString(SI_LTM_PAGE_DEFAULT_NAME) or "Default"),
        selectedIndex = selectedIndex,
        pageCount = #pageEntries,
        previousPageId = previousPageId,
        nextPageId = nextPageId,
    }
end

function LTM_UI_DISPATCH:SetSelectedPageId(pageId)
    return LTM_BUILD_STORE:SetSelectedPageId(pageId)
end

function LTM_UI_DISPATCH:CreatePage(pageName)
    return LTM_BUILD_STORE:CreatePage(pageName)
end

function LTM_UI_DISPATCH:RenamePage(pageId, newName)
    return LTM_BUILD_STORE:RenamePage(pageId, newName)
end

function LTM_UI_DISPATCH:DeleteSelectedPage()
    local result, err = LTM_BUILD_STORE:DeleteSelectedPage()
    if type(result) == "table" then
        ClearSavedEquipmentStateCacheForCurrentCharacter()
    end
    return result, err
end

function LTM_UI_DISPATCH:DeletePage(pageId)
    local result, err = LTM_BUILD_STORE:DeletePage(pageId)
    if type(result) == "table" then
        ClearSavedEquipmentStateCacheForCurrentCharacter()
    end
    return result, err
end

function LTM_UI_DISPATCH:SetPageOrder(pageOrder)
    return LTM_BUILD_STORE:SetPageOrder(pageOrder)
end

function LTM_UI_DISPATCH:SetBuildOrderForSelectedPage(buildOrder)
    return LTM_BUILD_STORE:SetBuildOrderForSelectedPage(buildOrder)
end

function LTM_UI_DISPATCH:GetSelectedBuildIdForPage(pageId)
    return LTM_BUILD_STORE:GetSelectedBuildIdForPage(pageId)
end

function LTM_UI_DISPATCH:SetSelectedBuildIdForPage(pageId, buildId)
    return LTM_BUILD_STORE:SetSelectedBuildIdForPage(pageId, buildId)
end

function LTM_UI_DISPATCH:IsBuildInSelectedPage(cardId)
    return LTM_BUILD_STORE:IsBuildInSelectedPage(cardId) == true
end

function LTM_UI_DISPATCH:GetBuildById(cardId)
    if type(cardId) ~= "string" or cardId == "" then
        return nil
    end

    return LTM_BUILD_STORE:GetBuildById(cardId)
end

function LTM_UI_DISPATCH:GetSelectedTargetBuild(cardId)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, nil
    end

    return LTM_BUILD_STORE:GetPreferredBuildById(cardId)
end

function LTM_UI_DISPATCH:GetCardSummary(cardId)
    local build = self:GetBuildById(cardId)
    if type(build) ~= "table" then
        return nil
    end

    local slotCounts = CountAssignedSkillSlots(build.skills)
    local subclassIds = type(build.subclass) == "table" and build.subclass.targetSkillLineIds or nil
    local attributes = type(build.attributes) == "table" and build.attributes or {}

    return {
        cardId = cardId,
        cardName = GetBuildDisplayName(cardId, build),
        role = NormalizeRoleState(build.role),
        outfitSaved = build.outfit ~= nil,
        outfitName = ResolveOutfitName(build.outfit),
        subclassCount = type(subclassIds) == "table" and #subclassIds or 0,
        attributes = {
            health = attributes.health or 0,
            magicka = attributes.magicka or 0,
            stamina = attributes.stamina or 0,
        },
        skillCounts = slotCounts,
        transformEntries = LTM_TRANSFORM_SKILLS:GetDisplayEntries(build.transforms),
    }
end

function LTM_UI_DISPATCH:GetCardDetailState(cardId)
    local build = self:GetBuildById(cardId)
    if type(build) ~= "table" then
        return nil
    end

    local slotCounts = CountAssignedSkillSlots(build.skills)
    local subclassIds = type(build.subclass) == "table" and build.subclass.targetSkillLineIds or nil
    local attributes = type(build.attributes) == "table" and build.attributes or {}
    local equipment = type(build.equipment) == "table" and build.equipment or {}
    local championPoints = type(build.championPoints) == "table" and build.championPoints or {}
    local activeSnapshotState = ResolveActiveSnapshotState(build)
    local passiveSnapshotState = ResolvePassiveSnapshotState(build)
    local forceChampionRespec = build.forceChampionRespec == true
    local quickslotProfileId = type(build.quickslotProfileId) == "string" and build.quickslotProfileId ~= "" and build.quickslotProfileId or nil
    local foodCardId = type(build.foodCardId) == "string" and build.foodCardId ~= "" and build.foodCardId or nil

    return {
        cardId = cardId,
        cardName = GetBuildDisplayName(cardId, build),
        role = NormalizeRoleState(build.role),
        skillSettingsUseOverride = type(build.skillSettings) == "table" and build.skillSettings.useOverride == true,
        activeSnapshotState = activeSnapshotState,
        passiveSnapshotState = passiveSnapshotState,
        forceChampionRespec = forceChampionRespec,
        quickslotProfileId = quickslotProfileId,
        foodCardId = foodCardId,
        subclassCount = type(subclassIds) == "table" and #subclassIds or 0,
        subclassSummary = BuildSavedSubclassSummary(subclassIds),
        outfitName = ResolveOutfitName(build.outfit),
        attributes = {
            health = attributes.health or 0,
            magicka = attributes.magicka or 0,
            stamina = attributes.stamina or 0,
        },
        attributeSummary = BuildSavedAttributeSummary(attributes),
        skillCounts = slotCounts,
        skillBars = BuildSavedSkillBarState(build.skills, build.equipment),
        transformEntries = LTM_TRANSFORM_SKILLS:GetDisplayEntries(build.transforms),
    }
end

function LTM_UI_DISPATCH:SetCardOutfit(cardId, outfit)
    return LTM_BUILD_STORE:SetBuildOutfit(cardId, outfit)
end

function LTM_UI_DISPATCH:OpenAddonSettings()
    return Addon.Modules.SettingsPanel:Open()
end

function LTM_UI_DISPATCH:GetCardOutfitOptions(cardId)
    local build = self:GetBuildById(cardId)
    if type(build) ~= "table" then
        return nil, "build_not_found"
    end
    local saved = build.outfit
    local options = {
        { label = ResolveOutfitName(nil), selected = saved == nil },
        { label = ResolveOutfitName({ mode = "default" }), outfit = { mode = "default" },
            selected = type(saved) == "table" and saved.mode == "default" and saved.equippedOutfitIndex == nil },
    }
    local count = GetUnlockedOutfitCount()
    if count == nil then
        return options, "outfit_count_unavailable"
    end
    for index = 1, count do
        local outfit = { equippedOutfitIndex = index }
        options[#options + 1] = {
            label = ResolveOutfitName(outfit, count),
            outfit = outfit,
            selected = type(saved) == "table" and saved.mode == nil and saved.equippedOutfitIndex == index,
        }
    end
    local savedIndex = type(saved) == "table" and saved.equippedOutfitIndex or nil
    if type(saved) == "table" and saved.mode == nil and type(savedIndex) == "number"
        and savedIndex >= 1 and savedIndex % 1 == 0 and savedIndex > count then
        options[#options + 1] = {
            label = ResolveOutfitName(saved, count),
            selected = true,
            enabled = false,
        }
    end
    return options
end

function LTM_UI_DISPATCH:SetCardTransformApply(cardId, kind, enabled)
    return LTM_BUILD_STORE:SetBuildTransformApply(cardId, kind, enabled == true)
end

function LTM_UI_DISPATCH:OverwriteCardTransform(cardId, kind)
    local overwriteType = kind == "werewolf" and "transform_werewolf"
        or kind == "vampire" and "transform_vampire"
        or nil
    if overwriteType == nil then
        return nil, "transform_kind_invalid"
    end
    return self:OverwriteCard(cardId, overwriteType)
end

function LTM_UI_DISPATCH:DeleteCardTransform(cardId, kind)
    return LTM_BUILD_STORE:DeleteBuildTransform(cardId, kind)
end

function LTM_UI_DISPATCH:GetTransformSkillsPopupState(cardId)
    local build = nil
    if type(cardId) == "string" and cardId ~= "" then
        build = select(1, self:GetSelectedTargetBuild(cardId))
    end

    return {
        cardId = cardId,
        targetEntries = LTM_TRANSFORM_SKILLS:GetDisplayEntries(
            type(build) == "table" and build.transforms or nil
        ),
        currentEntries = LTM_TRANSFORM_SKILLS:GetCurrentDisplayEntries(),
    }
end

function LTM_UI_DISPATCH:GetGlobalSkillSettings()
    return LTM:GetGlobalSkillSettings()
end

function LTM_UI_DISPATCH:SetGlobalSkillSettings(settings)
    return LTM:SetGlobalSkillSettings(settings)
end

function LTM_UI_DISPATCH:GetCardSkillSettingsState(cardId)
    local build = self:GetBuildById(cardId)
    if type(build) ~= "table" then
        return nil, "build_not_found"
    end

    local settings, err = LTM_BUILD_STORE:GetBuildSkillSettings(cardId)
    if type(settings) ~= "table" then
        return nil, err
    end

    return {
        cardId = cardId,
        settings = settings,
        activeSnapshotState = ResolveActiveSnapshotState(build),
        passiveSnapshotState = ResolvePassiveSnapshotState(build),
    }
end

function LTM_UI_DISPATCH:SetCardSkillSettings(cardId, settings)
    return LTM_BUILD_STORE:SetBuildSkillSettings(cardId, settings)
end

function LTM_UI_DISPATCH:GetCardForceChampionRespec(cardId)
    if type(cardId) ~= "string" or cardId == "" then
        return false
    end

    return LTM_BUILD_STORE:GetBuildForceChampionRespec(cardId) == true
end

function LTM_UI_DISPATCH:SetCardForceChampionRespec(cardId, enabled)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    return LTM_BUILD_STORE:SetBuildForceChampionRespec(cardId, enabled == true)
end

function LTM_UI_DISPATCH:GetQuickSlotLinkOptions()
    return LTM_QUICK_SETTINGS_PROFILE_FACADE:GetQuickSlotLinkOptions()
end

function LTM_UI_DISPATCH:GetQuickSlotProfileDisplayName(profileId)
    return LTM_QUICK_SETTINGS_PROFILE_FACADE:GetQuickSlotProfileDisplayName(profileId)
end

function LTM_UI_DISPATCH:HasQuickSlotProfile(profileId)
    return LTM_QUICK_SETTINGS_PROFILE_FACADE:HasQuickSlotProfile(profileId) == true
end

function LTM_UI_DISPATCH:GetFoodLinkOptions()
    return LTM_QUICK_SETTINGS_PROFILE_FACADE:GetFoodLinkOptions()
end

function LTM_UI_DISPATCH:GetFoodCardDisplayName(foodCardId)
    return LTM_QUICK_SETTINGS_PROFILE_FACADE:GetFoodCardDisplayName(foodCardId)
end

function LTM_UI_DISPATCH:HasFoodCard(foodCardId)
    return LTM_QUICK_SETTINGS_PROFILE_FACADE:HasFoodCard(foodCardId) == true
end

function LTM_UI_DISPATCH:SetCardQuickslotProfileId(cardId, profileId)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    return LTM_BUILD_STORE:SetBuildQuickslotProfileId(cardId, profileId)
end

function LTM_UI_DISPATCH:SetCardFoodCardId(cardId, foodCardId)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    return LTM_BUILD_STORE:SetBuildFoodCardId(cardId, foodCardId)
end

function LTM_UI_DISPATCH:RunQuickSlotLinkApply(profileId, continuation)
    if type(continuation) ~= "function" then
        continuation = function()
        end
    end

    if type(profileId) ~= "string" or profileId == "" then
        continuation()
        return
    end

    if LTM_QUICK_SETTINGS_PROFILE_FACADE:HasQuickSlotProfile(profileId) ~= true then
        continuation()
        return
    end

    local profile = LTM_QUICK_SETTINGS_PROFILE_FACADE:SetActiveProfile(profileId)
    if type(profile) ~= "table" then
        continuation()
        return
    end

    local applyState = LTM_QUICK_SETTINGS_PROFILE_FACADE:GetProfileApplyState(profile)
    if type(applyState) == "table" and applyState.canCompare == true and applyState.needsApply ~= true then
        continuation()
        return
    end

    local completed = false
    local function Finish()
        if completed then
            return
        end
        completed = true
        continuation()
    end

    local ok = LTM_QUICK_SETTINGS_PROFILE_FACADE:BeginProfileApply(profile, function()
        Finish()
    end)

    if ok ~= true then
        Finish()
    end
end

function LTM_UI_DISPATCH:RunFoodLinkApply(foodCardId)
    if type(foodCardId) ~= "string" or foodCardId == "" then
        return
    end

    if LTM_QUICK_SETTINGS_PROFILE_FACADE:HasFoodCard(foodCardId) ~= true then
        return
    end

    LTM_QUICK_SETTINGS_PROFILE_FACADE:SetActiveFoodCard(foodCardId)
end

function LTM_UI_DISPATCH:RunCardLinksAfterFullApply(cardId, continuation)
    local detailState = self:GetCardDetailState(cardId)
    local quickslotProfileId = type(detailState) == "table" and detailState.quickslotProfileId or nil
    local foodCardId = type(detailState) == "table" and detailState.foodCardId or nil

    if type(quickslotProfileId) ~= "string" or quickslotProfileId == "" then
        self:RunFoodLinkApply(foodCardId)
        if type(continuation) == "function" then
            continuation()
        end
        return
    end

    self:RunQuickSlotLinkApply(quickslotProfileId, function()
        self:RunFoodLinkApply(foodCardId)
        if type(continuation) == "function" then
            continuation()
        end
    end)
end

function LTM_UI_DISPATCH:GetCardSkillSlotAbility(cardId, hotbarCategory, slotIndex)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    return LTM_BUILD_STORE:GetSavedSkillSlotAbility(cardId, hotbarCategory, slotIndex)
end

function LTM_UI_DISPATCH:SetCardSkillSlotAbility(cardId, hotbarCategory, slotIndex, abilityId)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    return LTM_BUILD_STORE:SetSavedSkillSlotAbility(cardId, hotbarCategory, slotIndex, abilityId)
end

function LTM_UI_DISPATCH:GetCurrentStateSummary()
    if type(self.currentStateSummary) ~= "table" then
        self:RefreshCurrentSnapshot()
    end

    return self.currentStateSummary or {}
end

function LTM_UI_DISPATCH:GetCurrentSkillBarState()
    if type(self.currentSkillBarState) ~= "table" then
        self:RefreshCurrentSnapshot()
    end

    return self.currentSkillBarState or {
        front = {},
        back = {},
    }
end

function LTM_UI_DISPATCH:RefreshCurrentSnapshot()
    local subclassState = LTM_SUBCLASS_SNAPSHOT:CaptureCurrentSubclassState(nil)
    local attributeState = LTM_ATTRIBUTE_SNAPSHOT:CaptureCurrentAttributeState(nil)
    local skillState = LTM_BUILD_STORE:CaptureCurrentSkillState()
    local hotbarSnapshot = LTM_BUILD_STORE:CaptureCurrentSkillBarSnapshot()
    local classMasteryState = LTM_BUILD_STORE:CaptureCurrentClassMasteryForBuild()

    self.currentStateSummary = {
        currentSkillLineNames = BuildCurrentSkillLineSummary(subclassState.activeSkillLines),
        attributes = {
            health = attributeState.health or 0,
            magicka = attributeState.magicka or 0,
            stamina = attributeState.stamina or 0,
        },
        skillCounts = CountAssignedSkillSlots(skillState),
        effectState = BuildCurrentEffectState(),
        equipmentState = BuildCurrentEquipmentState(),
        championState = BuildCurrentChampionState(),
        outfitName = ResolveCurrentOutfitName(),
        role = CaptureCurrentRoleState(),
        classMasteryState = BuildSavedClassMasteryState(classMasteryState),
        transformEntries = LTM_TRANSFORM_SKILLS:GetCurrentDisplayEntries(),
    }
    self.currentSkillBarState = BuildCurrentSkillBarState(hotbarSnapshot)

    return self.currentStateSummary, self.currentSkillBarState
end

function LTM_UI_DISPATCH:GetTargetStateSummary(cardId)
    local build, source = self:GetSelectedTargetBuild(cardId)

    if type(build) ~= "table" then
        return BuildEmptyTargetStateSummary()
    end

    local subclassIds = type(build.subclass) == "table" and build.subclass.targetSkillLineIds or nil
    local attributes = type(build.attributes) == "table" and build.attributes or {}
    local skillState = type(build.skills) == "table" and build.skills or {}

    return {
        currentSkillLineNames = BuildSavedSkillLineSummaryList(subclassIds),
        attributes = {
            health = attributes.health or 0,
            magicka = attributes.magicka or 0,
            stamina = attributes.stamina or 0,
        },
        skillCounts = CountAssignedSkillSlots(skillState),
        equipmentState = GetSavedEquipmentStateForBuild(cardId, build),
        championState = BuildSavedChampionState(build.championPoints),
        targetAvailable = true,
        targetBuildSource = source,
        targetBuildName = build.displayName or build.name or build.id,
        outfitName = ResolveOutfitName(build.outfit, nil, true),
        role = NormalizeRoleState(build.role),
        classMasteryState = BuildSavedClassMasteryState(build.classMastery),
        transformEntries = LTM_TRANSFORM_SKILLS:GetDisplayEntries(build.transforms),
    }
end

function LTM_UI_DISPATCH:GetTargetSkillBarState(cardId)
    local build = nil
    build = select(1, self:GetSelectedTargetBuild(cardId))
    if type(build) ~= "table" then
        return BuildSavedSkillBarState(nil, nil)
    end

    return BuildSavedSkillBarState(build.skills, build.equipment)
end

function LTM_UI_DISPATCH:IsEquipmentFetchAvailable()
    return LTM_EQUIPMENT_FETCH:IsBusy() ~= true
        and LTM_EQUIPMENT_DEPOSIT:IsBusy() ~= true
        and LTM_EQUIPMENT_FETCH:IsFetchContextAvailable()
        or false
end

function LTM_UI_DISPATCH:IsEquipmentDepositAvailable()
    return LTM_EQUIPMENT_DEPOSIT:IsBusy() ~= true
        and LTM_EQUIPMENT_FETCH:IsBusy() ~= true
        and LTM_EQUIPMENT_DEPOSIT:IsDepositContextAvailable()
        or false
end

function LTM_UI_DISPATCH:ApplySelectedCard(cardId, completion, acceptedSkillPointPrecheck)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    return LTM:ApplyRequest({
        buildId = cardId,
        pageId = self:GetSelectedPageId(),
        source = "ui_full_apply",
        acceptedSkillPointPrecheck = acceptedSkillPointPrecheck,
        forceChampionRespec = self:GetCardForceChampionRespec(cardId) == true,
        postFullApply = function(done)
            self:RunCardLinksAfterFullApply(cardId, done)
        end,
    }, function(success, completionErr, finalResult)
        MarkInventorySnapshotDirty({
            refreshTarget = true,
        })
        if type(completion) == "function" then
            completion(success, completionErr, finalResult)
        end
    end)
end

function LTM_UI_DISPATCH:EstimateSelectedCardRouteBPreflight(cardId, partialScope)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    if partialScope ~= nil and partialScope ~= "class_skills" then
        return nil, "partial_scope_invalid"
    end

    return LTM:EvaluateApplyPrecheck({
        buildId = cardId,
        partialScope = partialScope,
        source = partialScope == "class_skills" and "ui_partial_apply" or "ui_full_apply",
    }, {
        interactive = true,
    })
end

function LTM_UI_DISPATCH:GetCurrentSkillSnapshotReport()
    return LTM_SKILL_SNAPSHOT_AUDIT:CaptureAndFormatSnapshot()
end

function LTM_UI_DISPATCH:RecordAcceptedSkillPointRun(metadata, precheck)
    return LTM_SKILL_POINT_RUN_AUDIT:RecordAcceptedRun(metadata, precheck)
end

function LTM_UI_DISPATCH:RecordSkillPointTerminalSummary(runId, buildId, finalResult)
    return LTM_SKILL_POINT_RUN_AUDIT:RecordTerminalSummary(runId, buildId, finalResult)
end

function LTM_UI_DISPATCH:ApplySelectedTargetBuildPartial(
    cardId,
    partialScope,
    completion,
    acceptedSkillPointPrecheck
)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    if partialScope ~= "attributes"
        and partialScope ~= "class_skills"
        and partialScope ~= "equipment"
        and partialScope ~= "champion_points" then
        return nil, "partial_scope_invalid"
    end

    local build, source = self:GetSelectedTargetBuild(cardId)
    if type(build) ~= "table" then
        return nil, "target_build_missing"
    end
    if partialScope == "equipment" and type(build.equipment) ~= "table" then
        return nil, "target_equipment_missing"
    end
    if partialScope == "champion_points" and type(build.championPoints) ~= "table" then
        return nil, "target_champion_points_missing"
    end

    local actionLabel = partialScope == "attributes" and "Attribute Respec button pressed"
        or partialScope == "class_skills" and "Class & Skills Respec button pressed"
        or partialScope == "equipment" and "Equipment Change button pressed"
        or "CP Change button pressed"
    Log.LogDebugSummary(
        actionLabel,
        "cardId=" .. tostring(cardId),
        "source=" .. tostring(source)
    )

    return LTM:ApplyRequest({
        build = build,
        buildId = cardId,
        partialScope = partialScope,
        source = "ui_partial_apply",
        acceptedSkillPointPrecheck = acceptedSkillPointPrecheck,
        forceChampionRespec = partialScope == "champion_points"
            and self:GetCardForceChampionRespec(cardId) == true,
    }, function(success, completionErr, finalResult)
        if partialScope == "equipment" then
            MarkInventorySnapshotDirty({
                refreshTarget = true,
            })
        end
        if type(completion) == "function" then
            completion(success, completionErr, finalResult)
        end
    end)
end

function LTM_UI_DISPATCH:FetchMissingSelectedTargetEquipment(cardId, completion)
    if type(cardId) ~= "string" or cardId == "" then
        return nil, "build_id_missing"
    end

    local build, source = self:GetSelectedTargetBuild(cardId)
    if type(build) ~= "table" then
        return nil, "target_build_missing"
    end
    if type(build.equipment) ~= "table" then
        return nil, "target_equipment_missing"
    end

    Log.LogDebugSummary(
        "Equipment fetch button pressed",
        "cardId=" .. tostring(cardId),
        "source=" .. tostring(source)
    )

    local fetchOk, fetchErr, summary = LTM_EQUIPMENT_FETCH:BeginFetch(build.equipment, function(success, reason, resultSummary)
        MarkInventorySnapshotDirty({
            refreshTarget = true,
        })
        if type(completion) == "function" then
            completion(success, reason, resultSummary)
        end
    end)
    return fetchOk, fetchErr, summary
end

function LTM_UI_DISPATCH:DepositUnusedEquipment(cardId, completion)
    local options = {
        currentBuildId = type(cardId) == "string" and cardId ~= "" and cardId or nil,
        cleanupScope = LTM:GetEquipmentDepositCleanupScope(),
        itemFilter = LTM:GetEquipmentDepositItemFilter(),
        safetyMode = LTM:GetEquipmentDepositSafetyMode(),
    }

    return LTM_EQUIPMENT_DEPOSIT:BeginDeposit(options, function(success, reason, summary)
        MarkInventorySnapshotDirty({
            refreshTarget = true,
        })
        if type(completion) == "function" then
            completion(success, reason, summary)
        end
    end)
end

function LTM_UI_DISPATCH:LinkGearToChat(cardId)
    if (type(IsConsoleUI) == "function" and IsConsoleUI())
        or (type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode()) then
        Log.WriteChat(GetStringValue("SI_LTM_GEAR_LINK_UNAVAILABLE_GAMEPAD", "Link Gear to Chat is available in keyboard mode only."))
        return nil, "gamepad_unavailable"
    end

    local build = select(1, self:GetSelectedTargetBuild(cardId))
    if type(build) ~= "table" or type(build.equipment) ~= "table" then
        Log.WriteChat(GetStringValue("SI_LTM_GEAR_LINK_NO_ITEMS", "No gear links available."))
        return nil, "target_equipment_missing"
    end

    local text = LTM_GEAR_LINK_SUMMARY:BuildChatText(
        build.equipment,
        GetStringValue("SI_LTM_GEAR_LINK_PREFIX", "[LTM Gear]")
    )
    if type(text) ~= "string" or text == "" then
        Log.WriteChat(GetStringValue("SI_LTM_GEAR_LINK_NO_ITEMS", "No gear links available."))
        return nil, "gear_link_empty"
    end

    if TryStartChatInput(text) or TrySetChatInputText(text) then
        return true
    end

    Log.WriteChat(GetStringValue("SI_LTM_GEAR_LINK_UNAVAILABLE_GAMEPAD", "Link Gear to Chat is available in keyboard mode only."))
    return nil, "chat_input_unavailable"
end

function LTM_UI_DISPATCH:AddNewCard()
    local build, err = LTM_BUILD_STORE:SaveCurrentStateAsNewBuild()
    if type(build) == "table" then
        ClearSavedEquipmentStateCacheForBuild(build.id)
    end
    return build, err
end

function LTM_UI_DISPATCH:RenameCard(cardId, newName)
    local build, err = LTM_BUILD_STORE:RenameBuildById(cardId, newName)
    if type(build) == "table" then
        ClearSavedEquipmentStateCacheForBuild(cardId)
    end
    return build, err
end

function LTM_UI_DISPATCH:DeleteCard(cardId)
    local result, err = LTM_BUILD_STORE:DeleteBuildById(cardId)
    if type(result) == "table" then
        ClearSavedEquipmentStateCacheForBuild(cardId)
    end
    return result, err
end

function LTM_UI_DISPATCH:DuplicateCard(cardId)
    local result, err = LTM_BUILD_STORE:DuplicateBuildById(cardId)
    if type(result) == "table" then
        ClearSavedEquipmentStateCacheForBuild(result.copiedBuildId)
    end
    return result, err
end

function LTM_UI_DISPATCH:MoveCardToPage(cardId, targetPageId)
    local result, err = LTM_BUILD_STORE:MoveBuildToPage(cardId, targetPageId)
    if type(result) == "table" then
        ClearSavedEquipmentStateCacheForBuild(cardId)
    end
    return result, err
end

function LTM_UI_DISPATCH:OverwriteCard(cardId, overwriteType)
    local build, err = LTM_BUILD_STORE:OverwriteBuildByIdFromCurrentSnapshotType(cardId, overwriteType)
    if type(build) == "table" then
        ClearSavedEquipmentStateCacheForBuild(cardId)
    end
    return build, err
end
