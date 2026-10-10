-- VaultTracker Addon
VaultTracker = {}
VaultTracker.name           = "VaultTracker"
VaultTracker.version        = "2.0.0"
VaultTracker.author         = "Awh_Lina"
VaultTracker.settingsVersion = 1
VaultTracker.addonName      = "VaultTracker"

-- Default settings
VaultTracker.defaultSettings = {
    showCost    = true,
    showStacks  = true,
    showAbility = true,
    showNotif   = true,
    fontSize    = 33,
    fontColor   = "FFFFFF",
    posX        = 500,
    posY        = 520,
}

-- Runtime state
VaultTracker.db             = nil
VaultTracker.currentCost    = 0
VaultTracker.currentStacks  = 0
VaultTracker.currentAbility = ""
VaultTracker.vaultType      = ""      -- "vault" | "fatigue" | ""
VaultTracker.notifActive    = false
VaultTracker.notifStartTime = 0
VaultTracker.notifTimer     = 4000   -- ms – notification banner display time
VaultTracker.nextCost       = 0
VaultTracker.activeVaultId      = nil
VaultTracker.baseVaultId        = nil    -- ability ID of the main vault morph (detected at runtime)
VaultTracker.fatigueEndTime     = 0      -- absolute game-ms when fatigue expires
VaultTracker.currentIconTexture = ""     -- icon path for the active vault ability

---------------------------------
-- Vault Name Detection
-- Matches any ability whose name ends in "Vault" (base + morphs)
-- or ends in "Vault Fatigue" (fatigue + morph fatigue variants)
---------------------------------
local function GetVaultType(abilityId, effectName)
    local name = GetAbilityName(abilityId)
    if (not name or name == "") and effectName and effectName ~= "" then
        name = effectName
    end
    if not name or name == "" then return nil end
    local lowered = zo_strlower(name)
    local fatigueLen = #"vault fatigue"
    local vaultLen   = #"vault"
    local fatigue_name = lowered:sub(-fatigueLen)
    local vault_name   = lowered:sub(-vaultLen)
    
    if fatigue_name == "vault fatigue" then return "fatigue" end
    if vault_name   == "vault"         then return "vault"   end
    return nil
end

---------------------------------
-- Cost Calculation
---------------------------------
local function CalculateNextCost(baseCost, stacks)
    return math.ceil(baseCost * (1.33 ^ stacks))
end

---------------------------------
-- GUI Creation
---------------------------------
function VaultTrackerCreateGUI()
    VaultTracker.control = WINDOW_MANAGER:CreateControlFromVirtual(
        "VaultTrackerContainer", GuiRoot, "VaultTrackerContainer")

    VaultTracker.costLabel    = VaultTracker.control:GetNamedChild("CostLabel")
    VaultTracker.stackLabel   = VaultTracker.control:GetNamedChild("StackLabel")
    VaultTracker.abilityLabel = VaultTracker.control:GetNamedChild("AbilityLabel")
    VaultTracker.abilityIcon  = VaultTracker.control:GetNamedChild("AbilityIcon")
    VaultTracker.notifLabel   = VaultTracker.control:GetNamedChild("NotifLabel")
    VaultTracker.timerLabel   = VaultTracker.control:GetNamedChild("TimerLabel")

    VaultTracker:ApplySettings()

    VaultTracker.control:ClearAnchors()
    VaultTracker.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        VaultTracker.db.posX, VaultTracker.db.posY)
end

function VaultTracker:ApplySettings()
    local fontString = string.format(
        "/esoui/common/fonts/univers67.otf|%d|soft-shadow-thick",
        VaultTracker.db.fontSize)
    local r, g, b, a = ZO_ColorDef:New(VaultTracker.db.fontColor):UnpackRGBA()

    local entries = {
        { label = VaultTracker.costLabel,    visible = VaultTracker.db.showCost    },
        { label = VaultTracker.stackLabel,   visible = VaultTracker.db.showStacks  },
        { label = VaultTracker.abilityLabel, visible = VaultTracker.db.showAbility },
        { label = VaultTracker.notifLabel,   visible = false                        },
        { label = VaultTracker.timerLabel,   visible = false                        },
    }
    for _, e in ipairs(entries) do
        if e.label then
            e.label:SetFont(fontString)
            e.label:SetColor(r, g, b, a)
            e.label:SetHidden(not e.visible)
        end
    end
    -- icon visibility tracks showAbility; only show when an icon is actually set
    if VaultTracker.abilityIcon then
        local showIcon = VaultTracker.db.showAbility and VaultTracker.currentIconTexture ~= ""
        VaultTracker.abilityIcon:SetHidden(not showIcon)
    end
end

---------------------------------
-- Label Updates
---------------------------------
local function UpdateLabels()
    local col = VaultTracker.db.fontColor
    if VaultTracker.costLabel then
        VaultTracker.costLabel:SetText(string.format(
            "|c%sNext Cost: %d|r", col, VaultTracker.nextCost))
    end
    if VaultTracker.stackLabel then
        VaultTracker.stackLabel:SetText(string.format(
            "|c%sStacks: %d|r", col, VaultTracker.currentStacks))
    end
    if VaultTracker.abilityLabel then
        VaultTracker.abilityLabel:SetText(string.format(
            "|c%sAbility: %s|r", col, VaultTracker.currentAbility))
    end
    if VaultTracker.abilityIcon then
        local hasIcon = VaultTracker.currentIconTexture ~= ""
        VaultTracker.abilityIcon:SetHidden(not (hasIcon and VaultTracker.db.showAbility))
        if hasIcon then
            VaultTracker.abilityIcon:SetTexture(VaultTracker.currentIconTexture)
        end
    end
end

---------------------------------
-- Fatigue Countdown Timer
-- endTime from EVENT_EFFECT_CHANGED is an absolute timestamp in ms
---------------------------------
local function UpdateFatigueTimer()
    local remaining = (VaultTracker.fatigueEndTime - GetGameTimeMilliseconds()) / 1000
    if remaining <= 0 then
        VaultTracker.timerLabel:SetHidden(true)
        EVENT_MANAGER:UnregisterForUpdate("VaultTrackerFatigueTimer")
        return
    end
    VaultTracker.timerLabel:SetHidden(false)
    VaultTracker.timerLabel:SetText(string.format(
        "|c%sFatigue: %.1fs|r", VaultTracker.db.fontColor, remaining))
end

local function StartFatigueTimer(endTime)
    VaultTracker.fatigueEndTime = endTime
    EVENT_MANAGER:UnregisterForUpdate("VaultTrackerFatigueTimer")
    EVENT_MANAGER:RegisterForUpdate("VaultTrackerFatigueTimer", 100, UpdateFatigueTimer)
end

local function StopFatigueTimer()
    EVENT_MANAGER:UnregisterForUpdate("VaultTrackerFatigueTimer")
    if VaultTracker.timerLabel then
        VaultTracker.timerLabel:SetHidden(true)
    end
end

---------------------------------
-- Notification Banner (auto-hides after notifTimer ms)
---------------------------------
local function ShowNotif(text)
    if not VaultTracker.db.showNotif then return end
    VaultTracker.notifLabel:SetText(text)
    VaultTracker.notifLabel:SetHidden(false)
    VaultTracker.notifActive    = true
    VaultTracker.notifStartTime = GetGameTimeMilliseconds()
    EVENT_MANAGER:UnregisterForUpdate("VaultTrackerNotifTimer")
    EVENT_MANAGER:RegisterForUpdate("VaultTrackerNotifTimer", 100, function()
        if GetGameTimeMilliseconds() - VaultTracker.notifStartTime >= VaultTracker.notifTimer then
            VaultTracker.notifLabel:SetHidden(true)
            VaultTracker.notifActive = false
            EVENT_MANAGER:UnregisterForUpdate("VaultTrackerNotifTimer")
        end
    end)
end

---------------------------------
-- Effect Event Handler
---------------------------------
local function OnEffectChanged(eventCode, result, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName,
    effectbuffType, effectBuffTypeUndep, abilityType,
    statusEffectType, unitName, unitId, abilityId, sourceType)

    if unitTag ~= "player" then return end

    local vaultType = GetVaultType(abilityId, effectName)
    if not vaultType then return end

    local gained = (result == EFFECT_RESULT_GAINED or result == EFFECT_RESULT_FULL_REFRESH)
    local updated = (result == EFFECT_RESULT_UPDATED)
    local faded  = (result == EFFECT_RESULT_FADED)

    if gained then
        VaultTracker.activeVaultId      = abilityId
        VaultTracker.vaultType          = vaultType
        VaultTracker.currentAbility     = GetAbilityName(abilityId)
        VaultTracker.currentIconTexture = GetAbilityIcon(abilityId)

        if vaultType == "vault" then
            VaultTracker.baseVaultId   = abilityId
            VaultTracker.currentCost   = GetAbilityCost(abilityId)
            VaultTracker.currentStacks = stackCount
            VaultTracker.nextCost      = CalculateNextCost(VaultTracker.currentCost, stackCount)
            StopFatigueTimer()
        elseif vaultType == "fatigue" then
            local baseId = VaultTracker.baseVaultId or abilityId
            VaultTracker.currentCost   = GetAbilityCost(baseId)
            VaultTracker.currentStacks = 0
            VaultTracker.nextCost      = VaultTracker.currentCost
            StartFatigueTimer(endTime)
        end

        UpdateLabels()
        ShowNotif(string.format("Activated: %s", VaultTracker.currentAbility))

    elseif updated then
        if vaultType == "vault" then
            VaultTracker.activeVaultId      = abilityId
            VaultTracker.vaultType          = vaultType
            VaultTracker.currentAbility     = GetAbilityName(abilityId)
            VaultTracker.currentIconTexture = GetAbilityIcon(abilityId)
            VaultTracker.baseVaultId        = abilityId
            VaultTracker.currentCost        = GetAbilityCost(abilityId)
            VaultTracker.currentStacks      = stackCount
            VaultTracker.nextCost           = CalculateNextCost(VaultTracker.currentCost, stackCount)
            UpdateLabels()
        elseif vaultType == "fatigue" then
            VaultTracker.activeVaultId      = abilityId
            VaultTracker.vaultType          = vaultType
            VaultTracker.currentAbility     = GetAbilityName(abilityId)
            VaultTracker.currentIconTexture = GetAbilityIcon(abilityId)
            StartFatigueTimer(endTime)
            UpdateLabels()
        end

    elseif faded then
        if abilityId ~= VaultTracker.activeVaultId then return end

        VaultTracker.activeVaultId      = nil
        VaultTracker.currentAbility     = ""
        VaultTracker.currentIconTexture = ""

        if vaultType == "fatigue" then
            local baseId = VaultTracker.baseVaultId
            VaultTracker.currentCost   = baseId and GetAbilityCost(baseId) or 0
            VaultTracker.nextCost      = VaultTracker.currentCost
            VaultTracker.currentStacks = 0
            StopFatigueTimer()
            ShowNotif("Vault Fatigue ended")
        elseif vaultType == "vault" then
            VaultTracker.currentStacks = 0
            VaultTracker.nextCost      = VaultTracker.currentCost
            ShowNotif("Vault faded")
        end

        UpdateLabels()
    end
end

---------------------------------
-- LibAddonMenu2 Setup
---------------------------------
local function SetupAddonMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    LAM:RegisterAddonPanel("VaultTrackerSettingsPanel", {
        type                = "panel",
        name                = VaultTracker.name,
        displayName         = VaultTracker.name,
        author              = VaultTracker.author,
        version             = VaultTracker.version,
        registerForRefresh  = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls("VaultTrackerSettingsPanel", {
        {
            type    = "checkbox",
            name    = "Show Cost",
            getFunc = function() return VaultTracker.db.showCost end,
            setFunc = function(v) VaultTracker.db.showCost = v; VaultTracker:ApplySettings() end,
            default = VaultTracker.defaultSettings.showCost,
        },
        {
            type    = "checkbox",
            name    = "Show Stacks",
            getFunc = function() return VaultTracker.db.showStacks end,
            setFunc = function(v) VaultTracker.db.showStacks = v; VaultTracker:ApplySettings() end,
            default = VaultTracker.defaultSettings.showStacks,
        },
        {
            type    = "checkbox",
            name    = "Show Ability",
            getFunc = function() return VaultTracker.db.showAbility end,
            setFunc = function(v) VaultTracker.db.showAbility = v; VaultTracker:ApplySettings() end,
            default = VaultTracker.defaultSettings.showAbility,
        },
        {
            type    = "checkbox",
            name    = "Show Notification",
            getFunc = function() return VaultTracker.db.showNotif end,
            setFunc = function(v) VaultTracker.db.showNotif = v end,
            default = VaultTracker.defaultSettings.showNotif,
        },
        {
            type    = "slider",
            name    = "Font Size",
            min = 1, max = 90, step = 1,
            getFunc = function() return VaultTracker.db.fontSize end,
            setFunc = function(v) VaultTracker.db.fontSize = v; VaultTracker:ApplySettings() end,
            default = VaultTracker.defaultSettings.fontSize,
        },
        {
            type    = "editbox",
            name    = "Font Color (hex RRGGBB)",
            getFunc = function() return VaultTracker.db.fontColor end,
            setFunc = function(v) VaultTracker.db.fontColor = v; VaultTracker:ApplySettings() end,
            default = VaultTracker.defaultSettings.fontColor,
        },
        {
            type    = "slider",
            name    = "Position X",
            min = 0, max = 1980, step = 10,
            getFunc = function() return VaultTracker.db.posX end,
            setFunc = function(v)
                VaultTracker.db.posX = v
                VaultTracker.control:ClearAnchors()
                VaultTracker.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, v, VaultTracker.db.posY)
            end,
            default = VaultTracker.defaultSettings.posX,
        },
        {
            type    = "slider",
            name    = "Position Y",
            min = 0, max = 1080, step = 10,
            getFunc = function() return VaultTracker.db.posY end,
            setFunc = function(v)
                VaultTracker.db.posY = v
                VaultTracker.control:ClearAnchors()
                VaultTracker.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, VaultTracker.db.posX, v)
            end,
            default = VaultTracker.defaultSettings.posY,
        },
    })
end

---------------------------------
-- Addon Loaded Handler
---------------------------------
local function Initialize(eventCode, addonName)
    if addonName ~= VaultTracker.addonName then return end

    VaultTracker.db = ZO_SavedVars:NewAccountWide(
        "VaultTrackerSettings", VaultTracker.settingsVersion,
        nil, VaultTracker.defaultSettings)

    VaultTrackerCreateGUI()

    EVENT_MANAGER:RegisterForEvent(
        VaultTracker.addonName, EVENT_EFFECT_CHANGED, OnEffectChanged)

    EVENT_MANAGER:AddFilterForEvent(
        VaultTracker.addonName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    SetupAddonMenu()
end

EVENT_MANAGER:RegisterForEvent(VaultTracker.addonName, EVENT_ADD_ON_LOADED, Initialize)