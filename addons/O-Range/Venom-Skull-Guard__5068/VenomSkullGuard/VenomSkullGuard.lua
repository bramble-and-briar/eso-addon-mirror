--[[
    Venom Skull Guard

    Protects the Venom Skull morph using configurable stamina and stack
    thresholds, and optionally blocks Render Flesh and its morphs above
    a configurable health threshold.

    Author: O-Range
    Version: 1.6.0

    Dependencies:
      - LibSkillBlocker
      - LibAddonMenu-2.0
]]

local ADDON_NAME = "VenomSkullGuard"
local ADDON_VERSION = "1.6.0"

local LAM2 = LibAddonMenu2

local VenomSkullGuard = {}

VenomSkullGuard.defaults = {
    enabled = true,

    -- Venom Skull protection
    enableStaminaProtection = true,
    threshold = 25,

    enableStackProtection = false,
    minimumStacks = 2,

    -- Render Flesh protection
    enableFleshProtection = false,
    fleshThreshold = 70,

    -- Shared alerts
    showAlerts = false,
}

local VENOM_SKULL_IDS = {
    117624,
    123699,
    123704,
}

local VENOM_SKULL_STACK_BUFF = 117625

-- Render Flesh + morphs
local RENDER_FLESH_IDS = {
    114196, -- Render Flesh
    117883, -- Resistant Flesh
    117888, -- Blood Sacrifice
}

local lastVenomAlertTime = 0
local lastFleshAlertTime = 0
local ALERT_COOLDOWN = 1500 -- ms

local function GetStaminaPercent()
    local current, max = GetUnitPower("player", POWERTYPE_STAMINA)

    if not max or max <= 0 then
        return 0
    end

    return (current / max) * 100
end

local function GetHealthPercent()
    local current, maximum = GetUnitPower("player", POWERTYPE_HEALTH)

    if not maximum or maximum <= 0 then
        return 100
    end

    return (current / maximum) * 100
end

local function GetVenomSkullStacks()
    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, _, _, stackCount, _, _, _, _, _, buffAbilityId =
            GetUnitBuffInfo("player", buffIndex)

        if buffAbilityId == VENOM_SKULL_STACK_BUFF then
            return stackCount
        end
    end

    return 0
end

local function ShowBlockAlert(message, alertType)
    if not VenomSkullGuard.db or not VenomSkullGuard.db.showAlerts then
        return
    end

    local now = GetGameTimeMilliseconds()

    if alertType == "flesh" then
        if now - lastFleshAlertTime < ALERT_COOLDOWN then
            return
        end
        lastFleshAlertTime = now
    else
        if now - lastVenomAlertTime < ALERT_COOLDOWN then
            return
        end
        lastVenomAlertTime = now
    end

    ZO_Alert(
        UI_ALERT_CATEGORY_ALERT,
        SOUNDS.NEGATIVE_CLICK,
        message
    )
end

-- LibSkillBlocker callback for Venom Skull
-- Return true = block, false = allow
local function VenomSkullBlock(slotNum, abilityId, lastTrigger)
    local db = VenomSkullGuard.db

    if not db or not db.enabled then
        return false
    end

    local failedStamina = false
    local failedStacks = false

    local staminaPercent = GetStaminaPercent()
    local currentStacks = GetVenomSkullStacks()

    if db.enableStaminaProtection then
        if staminaPercent < db.threshold then
            failedStamina = true
        end
    end

    if db.enableStackProtection then
        if currentStacks < db.minimumStacks then
            failedStacks = true
        end
    end

    if failedStamina or failedStacks then
        if failedStamina and failedStacks then
            ShowBlockAlert(
                string.format(
                    "VENOM SKULL BLOCKED (%d%% < %d%% / %d Stack%s < %d)",
                    math.floor(staminaPercent + 0.5),
                    db.threshold,
                    currentStacks,
                    currentStacks == 1 and "" or "s",
                    db.minimumStacks
                ),
                "venom"
            )
        elseif failedStamina then
            ShowBlockAlert(
                string.format(
                    "VENOM SKULL BLOCKED (%d%% < %d%%)",
                    math.floor(staminaPercent + 0.5),
                    db.threshold
                ),
                "venom"
            )
        elseif failedStacks then
            ShowBlockAlert(
                string.format(
                    "VENOM SKULL BLOCKED (%d Stack%s < %d)",
                    currentStacks,
                    currentStacks == 1 and "" or "s",
                    db.minimumStacks
                ),
                "venom"
            )
        end

        return true
    end

    return false
end

-- LibSkillBlocker callback for Render Flesh and morphs
-- Return true = block, false = allow
local function FleshGuardBlock(slotNum, abilityId, lastTrigger)
    local db = VenomSkullGuard.db

    if not db or not db.enabled or not db.enableFleshProtection then
        return false
    end

    local healthPercent = GetHealthPercent()

    if healthPercent > db.fleshThreshold then
        ShowBlockAlert(
            string.format(
                "RENDER FLESH BLOCKED (%d%% > %d%%)",
                math.floor(healthPercent + 0.5),
                db.fleshThreshold
            ),
            "flesh"
        )
        return true
    end

    return false
end

local function CreateSettingsMenu()
    if not LAM2 then
        return
    end

    local panelData = {
        type = "panel",
        name = "Venom Skull Guard",
        displayName = "Venom Skull Guard",
        author = "O-Range",
        version = ADDON_VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel(
        "VenomSkullGuardSettings",
        panelData
    )

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable Blocker",
            tooltip = "Enable or disable Venom Skull Guard.",
            default = true,
            getFunc = function()
                return VenomSkullGuard.db.enabled
            end,
            setFunc = function(value)
                VenomSkullGuard.db.enabled = value
            end,
        },

        {
            type = "header",
            name = "Stamina Protection",
        },
        {
            type = "checkbox",
            name = "Enable Stamina Protection",
            default = true,
            getFunc = function()
                return VenomSkullGuard.db.enableStaminaProtection
            end,
            setFunc = function(value)
                VenomSkullGuard.db.enableStaminaProtection = value
            end,
        },
        {
            type = "slider",
            name = "Minimum Stamina %",
            min = 0,
            max = 100,
            step = 1,
            default = 25,
            getFunc = function()
                return VenomSkullGuard.db.threshold
            end,
            setFunc = function(value)
                VenomSkullGuard.db.threshold = value
            end,
        },

        {
            type = "header",
            name = "Stack Protection",
        },
        {
            type = "checkbox",
            name = "Enable Stack Protection",
            default = false,
            getFunc = function()
                return VenomSkullGuard.db.enableStackProtection
            end,
            setFunc = function(value)
                VenomSkullGuard.db.enableStackProtection = value
            end,
        },
        {
            type = "slider",
            name = "Minimum Venom Skull Stacks",
            tooltip = "Block Venom Skull when current stacks are below this value.",
            min = 0,
            max = 3,
            step = 1,
            default = 2,
            getFunc = function()
                return VenomSkullGuard.db.minimumStacks
            end,
            setFunc = function(value)
                VenomSkullGuard.db.minimumStacks = value
            end,
        },

        {
            type = "header",
            name = "Render Flesh Protection",
        },
        {
            type = "checkbox",
            name = "Enable Render Flesh Protection",
            tooltip = "When enabled, Render Flesh and its morphs are blocked above the health threshold.",
            default = false,
            getFunc = function()
                return VenomSkullGuard.db.enableFleshProtection
            end,
            setFunc = function(value)
                VenomSkullGuard.db.enableFleshProtection = value
            end,
        },
        {
            type = "slider",
            name = "Block Above Health %",
            tooltip = "Blocks Render Flesh and its morphs while your health is above this percentage.",
            min = 0,
            max = 100,
            step = 1,
            default = 70,
            getFunc = function()
                return VenomSkullGuard.db.fleshThreshold
            end,
            setFunc = function(value)
                VenomSkullGuard.db.fleshThreshold = value
            end,
        },

        {
            type = "header",
            name = "Alerts",
        },
        {
            type = "checkbox",
            name = "Enable Alerts",
            default = false,
            getFunc = function()
                return VenomSkullGuard.db.showAlerts
            end,
            setFunc = function(value)
                VenomSkullGuard.db.showAlerts = value
            end,
        },
    }

    LAM2:RegisterOptionControls(
        "VenomSkullGuardSettings",
        optionsData
    )
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(
        ADDON_NAME,
        EVENT_ADD_ON_LOADED
    )

    VenomSkullGuard.db = ZO_SavedVars:NewAccountWide(
        "VenomSkullGuardVars",
        1,
        nil,
        VenomSkullGuard.defaults
    )

    CreateSettingsMenu()

    if not LibSkillBlocker then
        if VenomSkullGuard.db.showAlerts then
            ZO_Alert(
                UI_ALERT_CATEGORY_ERROR,
                SOUNDS.NEGATIVE_CLICK,
                "VenomSkullGuard: LibSkillBlocker is required!"
            )
        end

        return
    end

    for _, id in ipairs(VENOM_SKULL_IDS) do
        LibSkillBlocker.RegisterSkillBlock(
            ADDON_NAME,
            id,
            VenomSkullBlock,
            true
        )
    end

    for _, abilityId in ipairs(RENDER_FLESH_IDS) do
        LibSkillBlocker.RegisterSkillBlock(
            ADDON_NAME,
            abilityId,
            FleshGuardBlock,
            true
        )
    end

    if VenomSkullGuard.db.enabled and VenomSkullGuard.db.showAlerts then
        ZO_Alert(
            UI_ALERT_CATEGORY_ALERT,
            SOUNDS.NONE,
            "Venom Skull Guard v" .. ADDON_VERSION .. " Loaded"
        )
    end
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded
)