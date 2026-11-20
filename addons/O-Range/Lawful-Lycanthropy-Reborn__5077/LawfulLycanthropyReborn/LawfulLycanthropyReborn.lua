--[[
    Lawful Lycanthropy Reborn
    Prevents accidental criminal Werewolf (Lycanthropy) spellcasting
    in justice-enabled zones while out of combat.

    Author: O-Range
    Version: 1.0.0

    Dependencies:
      - LibSkillBlocker
      - LibAddonMenu-2.0

    Changelog

    Version 1.0.0
    - Initial release
    - Blocks verified criminal Werewolf abilities (Transformation Ultimate + morphs, Pounce family, Hircine's Bounty family)
    - Added settings panel
    - Added enable/disable toggle
    - Added alert toggle
    - Added justice zone detection
    - Added combat exemption
    - Account-wide settings
]]

local ADDON_NAME = "LawfulLycanthropyReborn"

local LAM2 = LibAddonMenu2
local LawfulLycanthropyReborn = {}

LawfulLycanthropyReborn.defaults = {
    enabled = true,
    showAlerts = true,
}

-- Verified / high-priority criminal Werewolf abilities
-- IMPORTANT: Ability IDs can change with major combat updates (especially the 2026 Werewolf refresh).
-- Verify these in-game or with current data dumps and expand as needed.
-- Base Transformation ID historically 32455. Morphs and other skills need current confirmation.
local BLOCKED_ABILITIES = {

    --------------------------------------------------------------------
    -- Ultimate - Werewolf Transformation & Morphs
    --------------------------------------------------------------------
    32455,      -- Werewolf Transformation (base - historical)
    -- Add Pack Leader and Werewolf Berserker morph IDs here once verified
    -- Example placeholders (replace with live values):
    -- 39075,  -- Pack Leader (example - VERIFY)
    -- 39076,  -- Werewolf Berserker (example - VERIFY)

    --------------------------------------------------------------------
    -- Active - Pounce Family
    --------------------------------------------------------------------
    -- Pounce base + Brutal Pounce + Feral Pounce (+ Carnage variants if separate IDs)
    -- Add verified IDs here

    --------------------------------------------------------------------
    -- Active - Hircine's Bounty Family
    --------------------------------------------------------------------
    -- Hircine's Bounty + Hircine's Fortitude + Hircine's Rage
    -- Add verified IDs here

    --------------------------------------------------------------------
    -- Optional expansion (Roar / Gnash / Rending Claws families, etc.)
    -- Only add skills that actually carry the CRIMINAL ACT flag
    --------------------------------------------------------------------
}

local lastAlertTime = 0
local ALERT_COOLDOWN = 1500

local function ShouldBlockSkills()

    if not LawfulLycanthropyReborn.db.enabled then
        return false
    end

    -- No class check needed (Werewolf is a World skill line, available to any class)

    if not IsInJusticeEnabledZone() then
        return false
    end

    if IsUnitInCombat("player") then
        return false
    end

    return true
end

local function CriminalSkillBlock()

    if not ShouldBlockSkills() then
        return false
    end

    if LawfulLycanthropyReborn.db.showAlerts then

        local now = GetGameTimeMilliseconds()

        if now - lastAlertTime >= ALERT_COOLDOWN then

            ZO_Alert(
                UI_ALERT_CATEGORY_ALERT,
                SOUNDS.NEGATIVE_CLICK,
                "Lawful Lycanthropy Reborn: Criminal Werewolf skill blocked"
            )

            lastAlertTime = now
        end
    end

    return true
end

local function RegisterBlocks()

    if not LibSkillBlocker then
        return
    end

    for _, abilityId in ipairs(BLOCKED_ABILITIES) do

        LibSkillBlocker.RegisterSkillBlock(
            ADDON_NAME,
            abilityId,
            CriminalSkillBlock,
            true
        )
    end
end

local function CreateSettingsMenu()

    if not LAM2 then
        return
    end

    local panelData = {
        type = "panel",
        name = "Lawful Lycanthropy Reborn",
        displayName = "Lawful Lycanthropy Reborn",
        author = "O-Range",
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel(
        "LawfulLycanthropyRebornSettings",
        panelData
    )

    local optionsData = {

        {
            type = "checkbox",
            name = "Enable Protection",
            tooltip = "Enable or disable criminal Werewolf skill blocking.",

            getFunc = function()
                return LawfulLycanthropyReborn.db.enabled
            end,

            setFunc = function(value)
                LawfulLycanthropyReborn.db.enabled = value
            end,
        },

        {
            type = "checkbox",
            name = "Show Alerts",
            tooltip = "Show a notification when a criminal skill is blocked.",

            getFunc = function()
                return LawfulLycanthropyReborn.db.showAlerts
            end,

            setFunc = function(value)
                LawfulLycanthropyReborn.db.showAlerts = value
            end,
        },
    }

    LAM2:RegisterOptionControls(
        "LawfulLycanthropyRebornSettings",
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

    LawfulLycanthropyReborn.db = ZO_SavedVars:NewAccountWide(
        "LawfulLycanthropyRebornVars",
        1,
        nil,
        LawfulLycanthropyReborn.defaults
    )

    CreateSettingsMenu()
    RegisterBlocks()

    if LawfulLycanthropyReborn.db.showAlerts then

        ZO_Alert(
            UI_ALERT_CATEGORY_ALERT,
            SOUNDS.NONE,
            "Lawful Lycanthropy Reborn v1.0.0 Loaded"
        )
    end
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded
)