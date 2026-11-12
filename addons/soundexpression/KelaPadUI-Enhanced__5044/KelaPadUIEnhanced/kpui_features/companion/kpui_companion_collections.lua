-- KelaPadUI companion details for the main Collections > Allies > Companions tooltip.
--
-- Companion level, experience, slotted skills, ultimate, gear, and passive perk
-- are account-wide. Rapport is tracked per character. The game only exposes live
-- companion data while that companion is active, so the tooltip renders live data
-- when possible and falls back to a snapshot recorded while the companion was
-- summoned. Empty or not-yet-initialized sections never replace a good snapshot.

local COMPANION_COLLECTIONS_EVENT_NAMESPACE = "KelaPadUI_CompanionCollections"
local COMPANION_SNAPSHOT_VERSION = 1
local COMPANION_TOOLTIP_STYLE = "companionCollectionsSection"

local function GetCompanionSnapshotStore()
    if type(kpuiSavedVariables) ~= "table" then
        kpuiSavedVariables = {}
    end

    local snapshots = kpuiSavedVariables.companionSnapshots
    if type(snapshots) ~= "table" then
        snapshots = {
            version = COMPANION_SNAPSHOT_VERSION,
            builds = {},
            rapport = {},
        }
        kpuiSavedVariables.companionSnapshots = snapshots
    end

    if type(snapshots.builds) ~= "table" then
        snapshots.builds = {}
    end
    if type(snapshots.rapport) ~= "table" then
        snapshots.rapport = {}
    end

    return snapshots
end

local function GetCachedBuild(companionId)
    local build = GetCompanionSnapshotStore().builds[companionId]
    if type(build) == "table" then
        return build
    end
    return nil
end

local function GetCachedRapport(companionId)
    local characterId = GetCurrentCharacterId()
    if not characterId or characterId == 0 then
        return nil
    end

    local byCharacter = GetCompanionSnapshotStore().rapport[characterId]
    if type(byCharacter) ~= "table" then
        return nil
    end

    local rapport = byCharacter[companionId]
    if type(rapport) == "table" then
        return rapport
    end
    return nil
end

local function MergeBuild(companionId, incoming)
    if type(incoming) ~= "table" then
        return
    end

    local store = GetCompanionSnapshotStore()
    local build = store.builds[companionId]
    if type(build) ~= "table" then
        build = {}
        store.builds[companionId] = build
    end

    local changed = false
    for key, value in pairs(incoming) do
        if value ~= nil then
            build[key] = value
            changed = true
        end
    end

    if changed then
        build.recordedAt = GetTimeStamp()
    end
end

local function MergeRapport(companionId, value, level)
    if value == nil then
        return
    end

    local characterId = GetCurrentCharacterId()
    if not characterId or characterId == 0 then
        return
    end

    local store = GetCompanionSnapshotStore()
    local byCharacter = store.rapport[characterId]
    if type(byCharacter) ~= "table" then
        byCharacter = {}
        store.rapport[characterId] = byCharacter
    end

    local rapport = byCharacter[companionId]
    if type(rapport) ~= "table" then
        rapport = {}
        byCharacter[companionId] = rapport
    end

    rapport.value = value
    if level ~= nil then
        rapport.level = level
    end
    rapport.recordedAt = GetTimeStamp()
end

local function FormatAbilityName(abilityId)
    if not abilityId or abilityId <= 0 then
        return nil
    end

    local name = GetAbilityName(abilityId)
    if name and name ~= "" then
        return zo_strformat(SI_ABILITY_NAME, name)
    end
    return nil
end

local function GetEquipSlotName(equipSlot)
    if equipSlot == EQUIP_SLOT_RING1 then
        return GetString(KELA_COMPANION_TOOLTIP_RING1)
    elseif equipSlot == EQUIP_SLOT_RING2 then
        return GetString(KELA_COMPANION_TOOLTIP_RING2)
    end

    return GetString("SI_EQUIPSLOT", equipSlot)
end

local function BuildLiveCompanionSnapshot(companionId)
    local snapshot = {}
    if GetActiveCompanionDefId() ~= companionId then
        return snapshot
    end

    local level, currentXp, totalXp, isMaxLevel = ZO_COMPANION_MANAGER:GetLevelInfo()
    if level and level > 0 then
        snapshot.level = level
        snapshot.xp = currentXp
        snapshot.xpTotal = totalXp
        snapshot.isMaxLevel = isMaxLevel
    end

    if COMPANION_SKILLS_DATA_MANAGER and COMPANION_SKILLS_DATA_MANAGER:IsDataReady() then
        local skills = {}
        -- Normal slots run up to ACTION_BAR_ULTIMATE_SLOT_INDEX; the ultimate
        -- is the following slot and is stored separately. `index` is the 1-based
        -- bar position for future display.
        local startSlot = GetAssignableAbilityBarStartAndEndSlots()
        for slot = startSlot, ACTION_BAR_ULTIMATE_SLOT_INDEX do
            local abilityId = GetSlotBoundId(slot, HOTBAR_CATEGORY_COMPANION)
            if abilityId and abilityId > 0 then
                skills[#skills + 1] = {
                    index = #skills + 1,
                    slot = slot,
                    abilityId = abilityId,
                    name = FormatAbilityName(abilityId),
                }
            end
        end

        if #skills > 0 then
            snapshot.skills = skills
        end

        local ultimateAbilityId = GetSlotBoundId(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
        if ultimateAbilityId and ultimateAbilityId > 0 then
            snapshot.ultimate = {
                abilityId = ultimateAbilityId,
                name = FormatAbilityName(ultimateAbilityId),
            }
        end
    end

    if HasActiveCompanion() then
        local gear = {}
        for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN) do
            if equipSlot ~= EQUIP_SLOT_COSTUME then
                local hasItem = GetWornItemInfo(BAG_COMPANION_WORN, equipSlot)
                if hasItem then
                    local itemLink = GetItemLink(BAG_COMPANION_WORN, equipSlot)
                    if itemLink and itemLink ~= "" then
                        gear[equipSlot] = itemLink
                    end
                end
            end
        end

        -- A two-handed main-hand weapon leaves the off-hand slot empty.
        if GetItemEquipType(BAG_COMPANION_WORN, EQUIP_SLOT_MAIN_HAND) == EQUIP_TYPE_TWO_HAND then
            gear[EQUIP_SLOT_OFF_HAND] = nil
        end

        if next(gear) ~= nil then
            snapshot.gear = gear
        end
    end

    local perkAbilityId = GetCompanionPassivePerkAbilityId(companionId)
    if perkAbilityId and perkAbilityId > 0 then
        snapshot.perkAbilityId = perkAbilityId
        snapshot.perkName = FormatAbilityName(perkAbilityId)
    end

    return snapshot
end

local function CaptureActiveCompanion()
    local companionId = GetActiveCompanionDefId()
    if not companionId or companionId == 0 then
        return
    end

    MergeBuild(companionId, BuildLiveCompanionSnapshot(companionId))

    local rapport = GetActiveCompanionRapport()
    if rapport ~= nil then
        MergeRapport(companionId, rapport, GetActiveCompanionRapportLevel())
    end
end

local captureCallId
local function QueueCompanionCapture(delayMs)
    if captureCallId then
        return
    end

    captureCallId = zo_callLater(function()
        captureCallId = nil
        CaptureActiveCompanion()
    end, delayMs or 300)
end

local function QueueInitialCompanionCapture()
    QueueCompanionCapture(1000)

    -- Inventory and skill data can still be initializing when the companion
    -- activation event fires. A second pass catches those late loads.
    zo_callLater(function()
        if GetActiveCompanionDefId() ~= 0 then
            CaptureActiveCompanion()
        end
    end, 4000)
end

local function GetDisplayBuild(companionId, isActive)
    local cached = GetCachedBuild(companionId)
    if not isActive then
        return cached
    end

    local live = BuildLiveCompanionSnapshot(companionId)
    if not cached then
        return live
    end

    local display = {}
    for key, value in pairs(cached) do
        display[key] = value
    end
    for key, value in pairs(live) do
        display[key] = value
    end

    return display
end

local function GetDisplayRapport(companionId, isActive)
    local value
    local level

    if isActive then
        value = GetActiveCompanionRapport()
        level = GetActiveCompanionRapportLevel()
    end

    if value == nil or level == nil then
        local cached = GetCachedRapport(companionId)
        if cached then
            if value == nil then
                value = cached.value
            end
            if level == nil then
                level = cached.level
            end
        end
    end

    return value, level
end

local function FormatGearLine(equipSlot, itemLink)
    local name = GetItemLinkName(itemLink)
    if not name or name == "" then
        return nil
    end

    local slotName = GetEquipSlotName(equipSlot)
    if not slotName or slotName == "" then
        return nil
    end

    local quality = GetItemLinkDisplayQuality(itemLink) or ITEM_DISPLAY_QUALITY_NORMAL
    local qualityColor = GetItemQualityColor(quality) or kpuiConst.Colors.COLOR_WHITE
    local cleanName = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
    local formattedName = qualityColor:Colorize(cleanName)

    local metaParts = {}
    if GetItemLinkItemType(itemLink) == ITEMTYPE_ARMOR then
        local armorType = GetItemLinkArmorType(itemLink)
        if armorType and armorType ~= ARMORTYPE_NONE then
            metaParts[#metaParts + 1] = GetString("SI_ARMORTYPE", armorType)
        end
    end

    local traitType = GetItemLinkTraitInfo(itemLink)
    if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
        local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
        if traitName and traitName ~= "" then
            metaParts[#metaParts + 1] = traitName
        end
    end

    if #metaParts > 0 then
        formattedName = zo_strformat(
            GetString(KELA_COMPANION_TOOLTIP_GEAR_META),
            formattedName,
            table.concat(metaParts, GetString(SI_LIST_COMMA_SEPARATOR))
        )
    end

    return zo_strformat(GetString(KELA_COMPANION_TOOLTIP_GEAR_LINE), slotName, formattedName)
end

local function AddCompanionTooltipSections(tooltip, companionId, isActive)
    local display = GetDisplayBuild(companionId, isActive)
    local hasBuild = display and (display.level ~= nil or display.skills ~= nil or display.ultimate ~= nil or display.gear ~= nil or display.perkAbilityId ~= nil)

    local sectionStyle = tooltip:GetStyle(COMPANION_TOOLTIP_STYLE) or tooltip:GetStyle("bodySection")
    local section = tooltip:AcquireSection(sectionStyle)
    local headerStyle = tooltip:GetStyle("bodyHeader")

    -- Add the line to tell if the companion is active or not
    if isActive then
        section:AddLine(kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(KELA_COMPANION_TOOLTIP_ACTIVE)))
    end

    -- Add Companion Level
    if display and display.level then
        if display.isMaxLevel or display.xpTotal == 0 then
            section:AddLine(kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(zo_strformat(
                GetString(KELA_COMPANION_TOOLTIP_LEVEL_MAX), display.level
            )))
        elseif display.xp ~= nil and display.xpTotal ~= nil then
            section:AddLine(zo_strformat(
                GetString(KELA_COMPANION_TOOLTIP_LEVEL_XP),
                display.level,
                KelaLocalizedFormatNumber(display.xp),
                KelaLocalizedFormatNumber(display.xpTotal)
            ))
        else
            section:AddLine(zo_strformat(GetString(KELA_COMPANION_TOOLTIP_LEVEL), display.level))
        end
    end

    -- Add Companion Rapport Level
    local rapportValue, rapportLevel = GetDisplayRapport(companionId, isActive)
    local rapportTier = rapportLevel and GetString("SI_COMPANIONRAPPORTLEVEL", rapportLevel)
    local maxRapport = GetMaximumRapport()
    if rapportTier and rapportTier ~= "" then
        if rapportValue ~= nil and maxRapport and maxRapport > 0 then
            local percent = zo_floor(rapportValue / maxRapport * 100)
            local rapportDetailsLine = zo_strformat(
                GetString(KELA_COMPANION_TOOLTIP_RAPPORT),
                rapportLevel,
                KelaLocalizedFormatNumber(rapportValue),
                KelaLocalizedFormatNumber(maxRapport),
                percent,
                rapportTier
            )

            if rapportLevel > 6 then
                rapportDetailsLine = kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(rapportDetailsLine)
            end

            section:AddLine(rapportDetailsLine)
        else
            section:AddLine(zo_strformat(GetString(KELA_COMPANION_TOOLTIP_RAPPORT_LEVEL), rapportLevel, rapportTier))
        end
    else
        section:AddLine(kpuiConst.Colors.COLOR_OFF_WHITE:Colorize(GetString(KELA_COMPANION_TOOLTIP_RAPPORT_MISSING)))
    end

    -- Add the Perk section
    local perkAbilityId = display and display.perkAbilityId
    if not perkAbilityId then
        perkAbilityId = GetCompanionPassivePerkAbilityId(companionId)
    end

    local perkName = display and display.perkName
    local livePerkName = FormatAbilityName(perkAbilityId)
    if livePerkName then
        perkName = livePerkName
    end

    if perkName and perkName ~= "" then
        section:AddLine(" ")
        section:AddLine(GetString(KELA_COMPANION_TOOLTIP_PERK), headerStyle)
        section:AddLine(perkName)

        local perkDescription = GetAbilityDescription(perkAbilityId)
        if perkDescription and perkDescription ~= "" then
            section:AddLine(perkDescription)
        end
    end

    -- Add Gear Section
    local gear = display and display.gear
    if gear and next(gear) ~= nil then
        section:AddLine(" ")
        section:AddLine(GetString(KELA_COMPANION_TOOLTIP_GEAR), headerStyle)

        local mainHandLink = gear[EQUIP_SLOT_MAIN_HAND]
        local mainHandIsTwoHanded = mainHandLink and GetItemLinkEquipType(mainHandLink) == EQUIP_TYPE_TWO_HAND

        for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN) do
            if equipSlot ~= EQUIP_SLOT_COSTUME then
                local itemLink = gear[equipSlot]
                if itemLink and not (equipSlot == EQUIP_SLOT_OFF_HAND and mainHandIsTwoHanded) then
                    local gearLine = FormatGearLine(equipSlot, itemLink)
                    if gearLine then
                        section:AddLine(gearLine)
                    end
                end
            end
        end
    end

    -- Slotted skills and the ultimate are still recorded in the snapshot, but
    -- are intentionally not displayed. I feel it's not very useful and take
    -- up too much realestate

    -- If companion info was not recorded, display a note
    if hasBuild then
        -- if not rapportTier then
        --     section:AddLine(kpuiConst.Colors.COLOR_OFF_WHITE:Colorize(GetString(KELA_COMPANION_TOOLTIP_RAPPORT_MISSING)))
        -- end

        if not isActive then
            section:AddLine(kpuiConst.Colors.COLOR_OFF_WHITE:Colorize(GetString(KELA_COMPANION_TOOLTIP_CACHED)))
        end
    elseif not isActive then
        section:AddLine(kpuiConst.Colors.COLOR_OFF_WHITE:Colorize(GetString(KELA_COMPANION_TOOLTIP_SUMMON)))
    end

    if section:HasControls() then
        tooltip:AddSection(section)
    end
end

local function ResolveCollectibleData(data)
    if not data then
        return nil
    end

    local getDataSource = data.GetDataSource
    if type(getDataSource) == "function" then
        local dataSource = getDataSource(data)
        if dataSource then
            data = dataSource
        end
    end

    if data.IsInstanceOf and data:IsInstanceOf(ZO_CollectibleData) then
        return data
    end

    return nil
end

local function AddCompanionDetailsToCollectionsTooltip(_, data)
    local collectibleData = ResolveCollectibleData(data)
    if not collectibleData then
        return
    end

    if collectibleData:GetCategoryType() ~= COLLECTIBLE_CATEGORY_TYPE_COMPANION then
        return
    end

    if not collectibleData:IsUnlocked() then
        return
    end

    local collectibleId = collectibleData:GetId()
    if not collectibleId or collectibleId == 0 then
        return
    end

    local companionId = GetCollectibleReferenceId(collectibleId)
    if not companionId or companionId == 0 then
        return
    end

    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    if not tooltip then
        return
    end

    local isActive = GetActiveCompanionDefId() == companionId
    AddCompanionTooltipSections(tooltip, companionId, isActive)
end

local function OnCompanionActivated(_, companionId)
    if companionId and companionId > 0 then
        QueueInitialCompanionCapture()
    end
end

local function OnActiveCompanionStateChanged(_, newState)
    if newState == COMPANION_STATE_ACTIVE then
        QueueInitialCompanionCapture()
    end
end

local function OnPlayerActivated()
    if HasActiveCompanion() then
        QueueInitialCompanionCapture()
    end
end

local function OnCompanionExperienceGain(_, companionId, _, _, currentExperience)
    if not companionId or companionId == 0 then
        return
    end

    -- The event reports the level before the gain, so read the current level
    -- from the live API instead.
    if GetActiveCompanionDefId() == companionId then
        local level, _, totalXp, isMaxLevel = ZO_COMPANION_MANAGER:GetLevelInfo()
        if level and level > 0 then
            MergeBuild(companionId, {
                level = level,
                xp = currentExperience,
                xpTotal = totalXp or 0,
                isMaxLevel = isMaxLevel or totalXp == 0,
            })
        end
    end

    QueueCompanionCapture(300)
end

local function OnCompanionRapportUpdate(_, companionId, _, currentRapport)
    if not companionId or companionId == 0 then
        return
    end

    MergeRapport(companionId, currentRapport, GetActiveCompanionRapportLevel())
end

local function OnCompanionSkillsUpdated()
    QueueCompanionCapture(300)
end

local function OnCompanionSlotUpdated(hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        QueueCompanionCapture(300)
    end
end

local function OnInventorySlotUpdated(_, bagId)
    if bagId == BAG_COMPANION_WORN and HasActiveCompanion() then
        QueueCompanionCapture(300)
    end
end

local companionCollectionsInitialized = false

function KelaSetupCompanionCollections()
    if companionCollectionsInitialized then
        return
    end
    companionCollectionsInitialized = true

    -- ZO_GamepadCollectionsBook is file-local in collectionsbook_gamepad.lua; the
    -- global singleton is GAMEPAD_COLLECTIONS_BOOK.
    if GAMEPAD_COLLECTIONS_BOOK and GAMEPAD_COLLECTIONS_BOOK.RefreshStandardTooltip then
        SecurePostHook(GAMEPAD_COLLECTIONS_BOOK, "RefreshStandardTooltip", AddCompanionDetailsToCollectionsTooltip)
    end

    EVENT_MANAGER:RegisterForEvent(COMPANION_COLLECTIONS_EVENT_NAMESPACE, EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
    EVENT_MANAGER:RegisterForEvent(COMPANION_COLLECTIONS_EVENT_NAMESPACE, EVENT_ACTIVE_COMPANION_STATE_CHANGED, OnActiveCompanionStateChanged)
    EVENT_MANAGER:RegisterForEvent(COMPANION_COLLECTIONS_EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(COMPANION_COLLECTIONS_EVENT_NAMESPACE, EVENT_COMPANION_EXPERIENCE_GAIN, OnCompanionExperienceGain)
    EVENT_MANAGER:RegisterForEvent(COMPANION_COLLECTIONS_EVENT_NAMESPACE, EVENT_COMPANION_RAPPORT_UPDATE, OnCompanionRapportUpdate)
    EVENT_MANAGER:RegisterForEvent(COMPANION_COLLECTIONS_EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdated)

    if COMPANION_SKILLS_DATA_MANAGER then
        COMPANION_SKILLS_DATA_MANAGER:RegisterCallback("FullSystemUpdated", OnCompanionSkillsUpdated)
    end
    if ACTION_BAR_ASSIGNMENT_MANAGER then
        ACTION_BAR_ASSIGNMENT_MANAGER:RegisterCallback("SlotUpdated", OnCompanionSlotUpdated)
    end
end
