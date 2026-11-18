--[[
    Lawful Necromancy Reborn

    Prevents accidental criminal Necromancer spellcasting
    in justice-enabled zones while out of combat.

    Author: O-Range
    Version: 1.1

    Dependencies:
      - LibSkillBlocker
      - LibAddonMenu-2.0

    Changelog

    Version 1.1
    - Added Bone Goliath and morph protection
    - Added Reanimate and morph protection
    - Added Colossus and morph protection
    - Added Skeletal Mage and morph protection
    - Added Spirit Mender and morph protection
    - Verified combat override behavior through testing
    - Verified justice-zone-only operation
    - Standardized addon naming throughout codebase
    - Updated SavedVariables naming for consistency
    - Refined protected ability list based on live testing
    - Removed non-criminal abilities from protection list

    Version 1.0
    - Initial release
    - Added Blastbones and morph protection
    - Added settings panel
    - Added enable/disable toggle
    - Added alert toggle
    - Added justice zone detection
    - Added combat exemption
]]

local ADDON_NAME = "LawfulNecromancyReborn"

local LAM2 = LibAddonMenu2

local LawfulNecromancyReborn = {}

LawfulNecromancyReborn.defaults = {
    enabled = true,
    showAlerts = true,
}

-- Verified criminal Necromancer abilities
local BLOCKED_ABILITIES = {

    --------------------------------------------------------------------
    -- Grave Lord
    --------------------------------------------------------------------

    -- Colossus
    122174,
    122395,
    122388,

    -- Blastbones
    114860,
    117690,
    117749,

    -- Skeletal Mage
    114317,
    118680,
    118726,

    --------------------------------------------------------------------
    -- Bone Tyrant
    --------------------------------------------------------------------

    -- Bone Goliath
    115001,
    118664,
    118279,

    --------------------------------------------------------------------
    -- Living Death
    --------------------------------------------------------------------

    -- Reanimate
    115593,
    115611,
    115626,

    -- Spirit Mender
    115710,
    118912,
    118840,
}

local lastAlertTime = 0
local ALERT_COOLDOWN = 1500

local function ShouldBlockSkills()

    if not LawfulNecromancyReborn.db.enabled then
        return false
    end

    if GetUnitClassId("player") ~= 5 then
        return false
    end

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

    if LawfulNecromancyReborn.db.showAlerts then

        local now = GetGameTimeMilliseconds()

        if now - lastAlertTime >= ALERT_COOLDOWN then

            ZO_Alert(
                UI_ALERT_CATEGORY_ALERT,
                SOUNDS.NEGATIVE_CLICK,
                "Lawful Necromancy Reborn: Criminal Necromancer skill blocked"
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
        name = "Lawful Necromancy Reborn",
        displayName = "Lawful Necromancy Reborn",
        author = "O-Range",
        version = "1.1",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel(
        "LawfulNecromancyRebornSettings",
        panelData
    )

    local optionsData = {

        {
            type = "checkbox",
            name = "Enable Protection",
            tooltip = "Enable or disable criminal skill blocking.",
            getFunc = function()
                return LawfulNecromancyReborn.db.enabled
            end,
            setFunc = function(value)
                LawfulNecromancyReborn.db.enabled = value
            end,
        },

        {
            type = "checkbox",
            name = "Show Alerts",
            tooltip = "Show a notification when a criminal skill is blocked.",
            getFunc = function()
                return LawfulNecromancyReborn.db.showAlerts
            end,
            setFunc = function(value)
                LawfulNecromancyReborn.db.showAlerts = value
            end,
        },
    }

    LAM2:RegisterOptionControls(
        "LawfulNecromancyRebornSettings",
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

    LawfulNecromancyReborn.db = ZO_SavedVars:NewAccountWide(
        "LawfulNecromancyRebornVars",
        1,
        nil,
        LawfulNecromancyReborn.defaults
    )

    CreateSettingsMenu()
    RegisterBlocks()

    if LawfulNecromancyReborn.db.showAlerts then

        ZO_Alert(
            UI_ALERT_CATEGORY_ALERT,
            SOUNDS.NONE,
            "Lawful Necromancy Reborn v1.1 Loaded"
        )
    end
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded
)