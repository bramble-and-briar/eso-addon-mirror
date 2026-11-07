local ADDON_NAME = "EldenRingUI"
local CD_UPDATE_NAME = ADDON_NAME .. "_CDUpdate"
local FONT = "EldenRingUI/Fonts/Vollkorn-Regular_0.slug|%d|soft-shadow-thick"

local SLOT_OFFSETS = {
    [1] = { x = 187, y = -225 },
    [2] = { x = 187, y = -115 },
    [3] = { x = 281, y = -171 },
    [4] = { x = 92,  y = -171 },
}

local BODY_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST,
    EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
    EQUIP_SLOT_HAND, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
}

local WEAPON_SLOTS = {
    EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
}

local TWO_HANDED_WEAPONS = {
    [WEAPONTYPE_TWO_HANDED_SWORD] = true,
    [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_BOW] = true,
    [WEAPONTYPE_FIRE_STAFF] = true,
    [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF] = true,
}

local UI_Container = nil
local IconPool = {}
local TextPool = {}
local CDPool = {}
local SecondaryCDPool = {}
local StackPool = {}

local CurrentDisplayNames = {}

local SetProcTimes = {}
local SetCooldownTimes = {}
local SetStacks = {}
local SecondaryProcTimes = {}
local SecondaryDurations = {}

local RegisteredEvents = {}
local AbilityIdToSetName = {}
local SecondaryAbilityIdToSetName = {}
local EffectIdToSetName = {}
local CooldownTriggerIdToSetName = {}

local SetNameCache = {}
local CachedBodyCounts = {}

local function CreateUI()
    if UI_Container then return end

    UI_Container = WINDOW_MANAGER:CreateTopLevelWindow("ERUI_SetTrackerControl")
    UI_Container:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, 0)
    UI_Container:SetDimensions(70, 70)
    UI_Container:SetDrawLayer(DL_OVERLAY)

    local fragment = ZO_HUDFadeSceneFragment:New(UI_Container)
    if HUD_SCENE then HUD_SCENE:AddFragment(fragment) end
    if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(fragment) end
    if SIEGE_BAR_SCENE then SIEGE_BAR_SCENE:AddFragment(fragment) end
    if LOOT_SCENE then LOOT_SCENE:AddFragment(fragment) end
end

local function CreateLabel(name, fontSize, r, g, b)
    local label = WINDOW_MANAGER:CreateControl(name, UI_Container, CT_LABEL)
    label:SetFont(string.format(FONT, fontSize))
    label:SetColor(r, g, b, 0.9)
    return label
end

local function GetIconControl(index)
    if not IconPool[index] then
        local offset = SLOT_OFFSETS[index]
        local icon = WINDOW_MANAGER:CreateControl("ERUI_SetTrackerIcon" .. index, UI_Container, CT_TEXTURE)
        icon:SetDimensions(70, 70)
        icon:SetAnchor(CENTER, UI_Container, BOTTOMLEFT, offset.x, offset.y)
        IconPool[index] = icon
    end
    return IconPool[index]
end

local function GetTextControl(index)
    if index ~= 1 and index ~= 2 then return nil end

    if not TextPool[index] then
        local icon = GetIconControl(index)
        local label = CreateLabel("ERUI_SetTrackerText" .. index, 22, 0.9, 0.9, 0.9)
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        if index == 1 then
            label:SetAnchor(BOTTOMLEFT, icon, TOPLEFT, -2, -18)
        else
            label:SetAnchor(TOPLEFT, icon, BOTTOMLEFT, -2, 18)
        end

        TextPool[index] = label
    end
    return TextPool[index]
end

local function GetCDControl(index)
    if not CDPool[index] then
        local label = CreateLabel("ERUI_SetTrackerCD" .. index, 24, 0.9, 0.9, 0.9)
        label:SetAnchor(TOPRIGHT, GetIconControl(index), TOPRIGHT, 4, -21)
        label:SetHidden(true)
        CDPool[index] = label
    end
    return CDPool[index]
end

local function GetSecondaryCDControl(index)
    if not SecondaryCDPool[index] then
        local label = CreateLabel("ERUI_SetTrackerSecCD" .. index, 24, 0.1, 0.9, 0.1)
        label:SetAnchor(BOTTOMRIGHT, GetIconControl(index), BOTTOMRIGHT, 4, 14)
        label:SetHidden(true)
        SecondaryCDPool[index] = label
    end
    return SecondaryCDPool[index]
end

local function GetStackControl(index)
    if not StackPool[index] then
        local label = CreateLabel("ERUI_SetTrackerStack" .. index, 24, 0.1, 0.9, 0.1)
        label:SetAnchor(BOTTOMRIGHT, GetIconControl(index), BOTTOMRIGHT, 4, 14)
        label:SetHidden(true)
        StackPool[index] = label
    end
    return StackPool[index]
end

local function MatchTrackedSet(itemLink)
    local hasSet, setName = GetItemLinkSetInfo(itemLink, false)
    if not hasSet or not setName then return nil end

    local matchedConfig = SetNameCache[setName]
    if matchedConfig == nil then
        matchedConfig = false
        for configName in pairs(EldenRingUI.TRACKED_SETS) do
            if string.find(setName, configName, 1, true) then
                matchedConfig = configName
                break
            end
        end
        SetNameCache[setName] = matchedConfig
    end

    return matchedConfig or nil
end

local function ScanBodyGear()
    CachedBodyCounts = {}
    if not EldenRingUI or not EldenRingUI.TRACKED_SETS then return end

    for _, slotIndex in ipairs(BODY_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, slotIndex)
        if itemLink and itemLink ~= "" then
            local configName = MatchTrackedSet(itemLink)
            if configName then
                CachedBodyCounts[configName] = (CachedBodyCounts[configName] or 0) + 1
            end
        end
    end
end

local function ScanGear()
    local setCounts = {}
    for configName, count in pairs(CachedBodyCounts) do
        setCounts[configName] = count
    end

    if not EldenRingUI or not EldenRingUI.TRACKED_SETS then return setCounts end

    for _, slotIndex in ipairs(WEAPON_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, slotIndex)
        if itemLink and itemLink ~= "" then
            local configName = MatchTrackedSet(itemLink)
            if configName then
                local isMainHand = (slotIndex == EQUIP_SLOT_MAIN_HAND or slotIndex == EQUIP_SLOT_BACKUP_MAIN)
                local count = (isMainHand and TWO_HANDED_WEAPONS[GetItemLinkWeaponType(itemLink)]) and 2 or 1
                setCounts[configName] = (setCounts[configName] or 0) + count
            end
        end
    end

    return setCounts
end

local function GetPrimaryTimer(setName, cdData, now)
    local cdEndTime = SetCooldownTimes[setName] or 0
    if cdEndTime > now then
        return true, cdEndTime - now, true
    end

    local procTime = SetProcTimes[setName] or 0

    if cdData.isEffectChanged then
        if procTime > now then
            return true, procTime - now, false
        end
        return false
    end

    local remaining = (procTime + (cdData.cooldownMs or 0)) - now
    if remaining <= 0 then
        return false
    end

    if cdData.buffMs and now < procTime + cdData.buffMs then
        return true, (procTime + cdData.buffMs) - now, false
    end

    return true, remaining, cdData.isCooldown == true
end

local function UpdateCooldownUI()
    local now = GetGameTimeMilliseconds()
    local anyActive = false

    for i = 1, 4 do
        local cdCtrl = GetCDControl(i)
        local secCtrl = GetSecondaryCDControl(i)
        local stackCtrl = GetStackControl(i)

        local setName = CurrentDisplayNames[i]
        local cdData = setName and EldenRingUI.COOLDOWN_DATA and EldenRingUI.COOLDOWN_DATA[setName]

        if not cdData then
            cdCtrl:SetHidden(true)
            secCtrl:SetHidden(true)
            stackCtrl:SetHidden(true)
        else
            local showTimer, displayTime, isRed = GetPrimaryTimer(setName, cdData, now)
            if showTimer then
                anyActive = true
                cdCtrl:SetText(tostring(math.ceil(displayTime / 1000)))
                if isRed then
                    cdCtrl:SetColor(0.9, 0.1, 0.1, 0.9)
                else
                    cdCtrl:SetColor(0.9, 0.9, 0.9, 0.9)
                end
                cdCtrl:SetHidden(false)
            else
                cdCtrl:SetHidden(true)
            end

            local stacks = SetStacks[setName] or 0
            if stacks > 0 then
                stackCtrl:SetText(tostring(stacks))
                stackCtrl:SetHidden(false)
            else
                stackCtrl:SetHidden(true)
            end

            local secRemaining = 0
            if cdData.secondary then
                local secProcTime = SecondaryProcTimes[setName] or 0
                local secDuration = SecondaryDurations[setName] or cdData.secondary.fallbackMs
                secRemaining = (secProcTime + secDuration) - now
            end

            if secRemaining > 0 then
                anyActive = true
                secCtrl:SetText(tostring(math.ceil(secRemaining / 1000)))
                secCtrl:SetHidden(false)
            else
                secCtrl:SetHidden(true)
            end
        end
    end

    if not anyActive then
        EVENT_MANAGER:UnregisterForUpdate(CD_UPDATE_NAME)
    end
end

local function StartCooldownUpdates()
    EVENT_MANAGER:RegisterForUpdate(CD_UPDATE_NAME, 100, UpdateCooldownUI)
end

local function OnSetProc(_, result, _, _, _, _, _, _, _, _, hitValue, _, _, _, _, _, abilityId)
    local setName = AbilityIdToSetName[abilityId]
    if not setName then return end

    local cdData = EldenRingUI.COOLDOWN_DATA[setName]
    if not cdData or result ~= cdData.result then return end

    SetProcTimes[setName] = GetGameTimeMilliseconds()

    if hitValue and hitValue > 100 then
        cdData.cooldownMs = hitValue
    end

    if cdData.secondary then
        SecondaryProcTimes[setName] = 0
    end

    StartCooldownUpdates()
end

local function OnSecondarySetProc(_, result, _, _, _, _, _, _, _, _, hitValue, _, _, _, _, _, abilityId)
    local setName = SecondaryAbilityIdToSetName[abilityId]
    if not setName then return end

    local cdData = EldenRingUI.COOLDOWN_DATA[setName]
    if not cdData or not cdData.secondary or result ~= cdData.secondary.result then return end

    SecondaryProcTimes[setName] = GetGameTimeMilliseconds()

    if hitValue and hitValue > 0 then
        SecondaryDurations[setName] = hitValue
    else
        SecondaryDurations[setName] = cdData.secondary.fallbackMs
    end

    StartCooldownUpdates()
end

local function OnCooldownTriggerProc(_, result, _, _, _, _, _, _, _, _, hitValue, _, _, _, _, _, abilityId)
    local setName = CooldownTriggerIdToSetName[abilityId]
    if not setName then return end

    local cdData = EldenRingUI.COOLDOWN_DATA[setName]
    if not cdData or not cdData.cooldownTrigger or result ~= cdData.cooldownTrigger.result then return end

    local cdDuration = cdData.cooldownTrigger.cooldownMs
    if hitValue and hitValue > 100 then
        cdDuration = hitValue
    end

    SetCooldownTimes[setName] = GetGameTimeMilliseconds() + cdDuration
    StartCooldownUpdates()
end

local function OnEffectChanged(_, changeType, _, _, _, _, endTime, stackCount, _, _, _, _, _, _, _, abilityId)
    local setName = EffectIdToSetName[abilityId]
    if not setName then return end

    if changeType == EFFECT_RESULT_FADED then
        SetStacks[setName] = 0
        SetProcTimes[setName] = 0
        StartCooldownUpdates()
    elseif changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        SetProcTimes[setName] = endTime * 1000
        SetStacks[setName] = stackCount
        StartCooldownUpdates()
    end
end

local function RegisterCombatEvent(name, abilityId, callback)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, callback)
    EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID, abilityId,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end

local function RegisterSetEvents(setName, cdData)
    if cdData.isEffectChanged then
        local name = ADDON_NAME .. "_Effect_" .. setName
        EVENT_MANAGER:RegisterForEvent(name, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(name, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID, cdData.abilityId,
            REGISTER_FILTER_UNIT_TAG, "player")
    else
        RegisterCombatEvent(ADDON_NAME .. "_Proc_" .. setName, cdData.abilityId, OnSetProc)
    end

    if cdData.cooldownTrigger then
        RegisterCombatEvent(ADDON_NAME .. "_CDTrig_" .. setName, cdData.cooldownTrigger.abilityId, OnCooldownTriggerProc)
    end

    if cdData.secondary then
        RegisterCombatEvent(ADDON_NAME .. "_SecProc_" .. setName, cdData.secondary.abilityId, OnSecondarySetProc)
    end
end

local function UnregisterSetEvents(setName, cdData)
    if cdData.isEffectChanged then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Effect_" .. setName, EVENT_EFFECT_CHANGED)
    else
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Proc_" .. setName, EVENT_COMBAT_EVENT)
    end

    if cdData.cooldownTrigger then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_CDTrig_" .. setName, EVENT_COMBAT_EVENT)
    end

    if cdData.secondary then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_SecProc_" .. setName, EVENT_COMBAT_EVENT)
    end
end

local function UpdateSetEvents(counts)
    if not EldenRingUI or not EldenRingUI.COOLDOWN_DATA then return end

    for setName, cdData in pairs(EldenRingUI.COOLDOWN_DATA) do
        local trackedData = EldenRingUI.TRACKED_SETS and EldenRingUI.TRACKED_SETS[setName]
        local reqPieces = trackedData and trackedData.pieces or 5
        local isEquipped = counts[setName] and counts[setName] >= reqPieces

        if isEquipped and not RegisteredEvents[setName] then
            RegisterSetEvents(setName, cdData)
            RegisteredEvents[setName] = true
        elseif not isEquipped and RegisteredEvents[setName] then
            UnregisterSetEvents(setName, cdData)
            RegisteredEvents[setName] = false
        end
    end
end

local function AssignSlots(counts)
    local displaySlots = {}
    local displayNames = {}
    local overflow = {}

    for configName, count in pairs(counts) do
        local data = EldenRingUI.TRACKED_SETS[configName]
        if data and data.icon and count >= (data.pieces or 5) then
            local pref = data.preferredSlot
            if pref and pref >= 1 and pref <= 4 and not displaySlots[pref] then
                displaySlots[pref] = data.icon
                displayNames[pref] = configName
            else
                table.insert(overflow, { icon = data.icon, name = configName })
            end
        end
    end

    for _, item in ipairs(overflow) do
        for i = 1, 4 do
            if not displaySlots[i] then
                displaySlots[i] = item.icon
                displayNames[i] = item.name
                break
            end
        end
    end

    return displaySlots, displayNames
end

local function UpdateUI()
    local counts = ScanGear()
    UpdateSetEvents(counts)

    local displaySlots, displayNames = AssignSlots(counts)
    CurrentDisplayNames = displayNames

    for i = 1, 4 do
        local iconCtrl = GetIconControl(i)
        if displaySlots[i] then
            iconCtrl:SetTexture(displaySlots[i])
            iconCtrl:SetHidden(false)
        else
            iconCtrl:SetHidden(true)
            GetCDControl(i):SetHidden(true)
            GetSecondaryCDControl(i):SetHidden(true)
            GetStackControl(i):SetHidden(true)
        end

        local textCtrl = GetTextControl(i)
        if textCtrl then
            if displaySlots[i] and displayNames[i] then
                textCtrl:SetText(displayNames[i])
                textCtrl:SetHidden(false)
            else
                textCtrl:SetHidden(true)
            end
        end
    end

    UpdateCooldownUI()
end

local function BuildAbilityMaps()
    if not EldenRingUI or not EldenRingUI.COOLDOWN_DATA then return end

    for setName, data in pairs(EldenRingUI.COOLDOWN_DATA) do
        if data.isEffectChanged then
            EffectIdToSetName[data.abilityId] = setName
        else
            AbilityIdToSetName[data.abilityId] = setName
        end

        if data.secondary then
            SecondaryAbilityIdToSetName[data.secondary.abilityId] = setName
        end

        if data.cooldownTrigger then
            CooldownTriggerIdToSetName[data.cooldownTrigger.abilityId] = setName
        end
    end
end

local function OnGearChanged()
    ScanBodyGear()
    UpdateUI()
end

local function OnInitialize(event, addonName)
    if event == EVENT_ADD_ON_LOADED and addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_InitPlayer", EVENT_PLAYER_ACTIVATED)

    if UI_Container then return end

    BuildAbilityMaps()
    ScanBodyGear()
    CreateUI()
    UpdateUI()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnGearChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_WORN,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_InitAddon", EVENT_ADD_ON_LOADED, OnInitialize)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_InitPlayer", EVENT_PLAYER_ACTIVATED, OnInitialize)