-- =============================================================================
-- Ability Icons Framework (AIF) - Core Configuration, Constants & Paths
-- =============================================================================
-- Central repository of global constants, asset path resolvers, and precomputed
-- caches. This is where file paths live so we don't have to write out
-- "/esoui/art/icons/" fifty times in every other file.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

--------------------------------------------------------------------------------
-- SavedVariables Version
--------------------------------------------------------------------------------

-- Bumped only when underlying SavedVariables schemas undergo breaking migrations
AbilityIconsFramework.SAVEDVARIABLES_VERSION = 1.5

--------------------------------------------------------------------------------
-- Engine Constants & Slot Indices
--------------------------------------------------------------------------------

-- In ESO's internal action bar architecture, slots 1 and 2 are secretly reserved
-- by the engine for Light Attack and Heavy Attack. Therefore, player-slotted
-- abilities always occupy index 3 (Ability 1) through index 8 (Ultimate).
AbilityIconsFramework.MIN_INDEX = 3                  -- First ability index on ESO action bars (Slot 1 = key 3)
AbilityIconsFramework.MAX_INDEX = 8                  -- Last regular ability: 7 (Slot 5), Ultimate: 8

-- Meta-key used in CUSTOM_ABILITY_ICONS tables to store the numeric craftedAbilityId
AbilityIconsFramework.SCRIBING_ID_KEY = "craftedAbilityId"

-- FancyActionBar and FancyActionBar+ map backbar abilities to physical indices 23-28
-- (standard slot index 3-8 + offset 20) to avoid colliding with active bar buttons.
AbilityIconsFramework.SLOT_INDEX_OFFSET = 20         -- Offset for FancyActionBar backbar ability indices (23-28)

-- Offset reserved for companion ultimate slotting
AbilityIconsFramework.COMPANION_INDEX_OFFSET = 30    -- Offset for companion ultimate slotting

--------------------------------------------------------------------------------
-- State Tables
--------------------------------------------------------------------------------

-- Map of registered external icon packs: [packDirectory] = { "icon1.dds", "icon2.dds", ... }
AbilityIconsFramework.ENABLED_ICON_PACKS = {}

-- Master lookup dictionary of base-game icons to replace: [esoIconPath] = replacementIconPath
AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE = {}

-- Master metadata table for Scribing abilities: [defaultGrimoireIcon] = { [SCRIBING_ID_KEY] = id, [EFFECT.X] = path, ... }
AbilityIconsFramework.CUSTOM_ABILITY_ICONS = {}

--------------------------------------------------------------------------------
-- Path Shortcuts & Resolvers
--------------------------------------------------------------------------------

local ESO_ROOT = "/esoui/art/icons/"
local ADDON_ROOT = "/AbilityIconsFramework/icons/"
local baseIconsPath = "/AbilityIconsFramework/icons/256/"

--- Resolves a texture filename into ESO's internal base-game art path.
--- @param name string The filename of the icon (e.g., "ability_mage_001.dds").
--- @return string fullPath The absolute ESO texture path ("/esoui/art/icons/...").
function AbilityIconsFramework.esoIcon(name)
    return ESO_ROOT .. name
end

--- Resolves a texture filename into this framework's high-res asset folder.
--- @param name string The filename of the icon.
--- @return string fullPath The absolute path inside the active resolution folder.
function AbilityIconsFramework.addonIcon(name)
    return baseIconsPath .. name
end

-- Precomputed cache of base game icon replacements for the active session resolution: { [esoIcon] = addonIcon }
AbilityIconsFramework.PRECOMPUTED_BASE_ICONS = nil

--- Updates the internal asset directory string based on the user's resolution choice (64, 128, or 256).
function AbilityIconsFramework.InitBaseIconsPath()
    local res = AbilityIconsFramework.GetSettings() and AbilityIconsFramework.GetSettings().resolution or 256
    baseIconsPath = ADDON_ROOT .. tostring(res) .. "/"
end

--- Returns the pre-computed base icon replacement map for the active session resolution.
---
--- Because resolution changes require a UI reload in ESO's C++ engine, precomputing
--- this flat table once per session eliminates nearly two thousand string concatenations
--- whenever icon packs are re-sorted or re-applied.
---
--- @return table<string, string> baseIconsMap Map of vanilla icon path -> high-res addon icon path.
function AbilityIconsFramework.GetPrecomputedBaseIcons()
    if AbilityIconsFramework.PRECOMPUTED_BASE_ICONS then
        return AbilityIconsFramework.PRECOMPUTED_BASE_ICONS
    end

    local settings = AbilityIconsFramework.GetSettings()
    local res = tostring(settings and settings.resolution or 256)
    local resPath = ADDON_ROOT .. res .. "/"
    local replacementIcons = AbilityIconsFramework.REPLACEMENT_ICONS or {}

    local cached = {}
    for _, icon in ipairs(replacementIcons) do
        cached[ESO_ROOT .. icon] = resPath .. icon
    end
    AbilityIconsFramework.PRECOMPUTED_BASE_ICONS = cached
    return cached
end

--------------------------------------------------------------------------------
-- Default Addon Configuration
--------------------------------------------------------------------------------

--- Default account-wide configuration bucket for master settings.
AbilityIconsFramework.DEFAULT_ADDON_CONFIG = {
    version = AbilityIconsFramework.SAVEDVARIABLES_VERSION,
    saveSettingsGlobally = true,
}
