--[[
    Venom Skull Guard

    Protects the Venom Skull morph using configurable
    stamina and stack thresholds.

    Author: O-Range
    Version: 1.5.1

    Dependencies:
      - LibSkillBlocker
      - LibAddonMenu-2.0

    Changelog

    Version 1.5.1
    - Added explicit dependency version requirements
    - Updated documentation
    - Fixed version consistency across files and settings panel

    Version 1.5
    - Rebranded from Necro Stamina Guard
    - Updated naming throughout addon
    - Updated documentation
    - Added Venom Skull specific descriptions

    Version 1.4
    - Added optional Venom Skull stack protection
    - Added configurable minimum stack threshold
    - Added separate stamina protection toggle
    - Added combined stamina and stack blocking logic
    - Added stack-based alert messages

    Version 1.3
    - Added toggle to suppress all addon alerts
    - Uses precise stamina percentage for threshold comparisons
    - Added defensive SavedVariables checks
    - Updated settings panel version and tooltips

    Version 1.2
    - Added Enable/Disable toggle
    - Added safer library checks
    - Improved alert messages

    Version 1.1
    - Added settings panel
    - Added configurable threshold slider
    - Added SavedVariables
    - Added alert cooldown
    - Added dependency checking

    Version 1.0
    - Initial release
    - Blocks Venom Skull variants below stamina threshold
]]

local ADDON_NAME = "VenomSkullGuard"

local LAM2 = LibAddonMenu2

local VenomSkullGuard = {}

VenomSkullGuard.defaults = {
    enabled = true,

    enableStaminaProtection = true,
    threshold = 25,

    enableStackProtection = false,
    minimumStacks = 2,

    showAlerts = false,
}

local VENOM_SKULL_IDS = {
    117624,
    123699,
    123704,
}

local VENOM_SKULL_STACK_BUFF = 117625

local lastAlertTime = 0
local ALERT_COOLDOWN = 1500

local function GetStaminaPercent()
    local current, max = GetUnitPower("player", POWERTYPE_STAMINA)

    if max <= 0 then
        return 0
    end

    return (current / max) * 100
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

local function ShowBlockAlert(message)
    if not VenomSkullGuard.db.showAlerts then
        return
    end

    local now = GetGameTimeMilliseconds()

    if now - lastAlertTime >= ALERT_COOLDOWN then
        ZO_Alert(
            UI_ALERT_CATEGORY_ALERT,
            SOUNDS.NEGATIVE_CLICK,
            message
        )

        lastAlertTime = now
    end
end

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
                )
            )

        elseif failedStamina then

            ShowBlockAlert(
                string.format(
                    "VENOM SKULL BLOCKED (%d%% < %d%%)",
                    math.floor(staminaPercent + 0.5),
                    db.threshold
                )
            )

        elseif failedStacks then

            ShowBlockAlert(
                string.format(
                    "VENOM SKULL BLOCKED (%d Stack%s < %d)",
                    currentStacks,
                    currentStacks == 1 and "" or "s",
                    db.minimumStacks
                )
            )

        end

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
        version = "1.5.1",
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

    if VenomSkullGuard.db.enabled and VenomSkullGuard.db.showAlerts then
        ZO_Alert(
            UI_ALERT_CATEGORY_ALERT,
            SOUNDS.NONE,
            "Venom Skull Guard v1.5.1 Loaded"
        )
    end
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded
)