-- =============================================================================
-- Ability Icons Framework (AIF) - Settings, SavedVariables & LibAddonMenu UI
-- =============================================================================
-- Manages the configuration lifecycle across account-wide and per-character
-- SavedVariables buckets, provides safe schema pruning for deprecated keys,
-- rescues legacy data structures, and wires up the in-game LibAddonMenu2 panel
-- (including the drag-and-drop pack priority reorder widget).
--
-- Why three SavedVariables buckets? Because some players want every alt to share
-- the exact same HD setup, while others want their Sorcerer to use one pack and
-- their Necromancer to use another. We cater to both without melting the disk.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

local pairs                 = pairs
local tostring              = tostring
local GetDisplayName        = GetDisplayName
local GetCurrentCharacterId = GetCurrentCharacterId

--------------------------------------------------------------------------------
-- Default Configuration Schemas
--------------------------------------------------------------------------------

--- Default settings template applied when a user first launches the addon or
--- resets their settings to factory defaults.
AbilityIconsFramework.DEFAULT_SETTINGS = {
    version                    = AbilityIconsFramework.SAVEDVARIABLES_VERSION,
    showCustomScribeIcons      = true,  -- Swap generic grimoire textures for Focus-specific art
    replaceMismatchedBaseIcons = true,  -- Swap blurry vanilla 64px textures for clean HD versions
    enableHeroismPotionIcons   = true,  -- Distinct glowing purple art for Major/Minor Heroism pots
    iconPacksData              = {},    -- Saved load order and metadata per registered external pack
    resolution                 = 256    -- Active icon texture resolution (64, 128, or 256)
}

--- Supported texture asset resolutions bundled with the framework.
AbilityIconsFramework.resolutionChoices = {
    64,
    128,
    256
}

-- Tracks the resolution loaded during the current game session.
-- If the player picks a different resolution in the dropdown, we disable the
-- "Reload UI" button until they pick something that actually requires a reload.
local currentIconsResolution = 256

--------------------------------------------------------------------------------
-- Initialization & Menu Registration
--------------------------------------------------------------------------------

--- Initializes SavedVariables buckets and configures their LibAddonMenu2 panel.
---
--- Storage architecture uses 3 distinct ZO_SavedVars containers:
---   1. CONFIG: Purely account-wide, holds the meta-toggle (saveSettingsGlobally).
---   2. GLOBALSETTINGS: Account-wide icon preferences shared by all characters.
---   3. CHARACTERSETTINGS: Character-specific preferences keyed by Character ID.
---
--- Character IDs (numeric strings) are used rather than character names so that
--- paid name-changes or server transfers never corrupt or orphan player settings.
function AbilityIconsFramework.InitializeSettings()
    -- 1. Base Configuration (Account-Wide)
    AbilityIconsFramework.CONFIG = ZO_SavedVars:NewAccountWide("AbilityIconsFramework_SavedVariables", AbilityIconsFramework.SAVEDVARIABLES_VERSION, "config", AbilityIconsFramework.DEFAULT_ADDON_CONFIG)
    AbilityIconsFramework.CleanupAccountWideSettings(AbilityIconsFramework_SavedVariables, AbilityIconsFramework.DEFAULT_ADDON_CONFIG, "config")

    -- 2. Global Settings (Account-Wide)
    AbilityIconsFramework.GLOBALSETTINGS = ZO_SavedVars:NewAccountWide("AbilityIconsFramework_SavedVariables", AbilityIconsFramework.SAVEDVARIABLES_VERSION, "global_settings", AbilityIconsFramework.DEFAULT_SETTINGS)
    AbilityIconsFramework.CleanupAccountWideSettings(AbilityIconsFramework_SavedVariables, AbilityIconsFramework.DEFAULT_SETTINGS, "global_settings")

    -- 3. Character Settings (Per-Character by ID)
    AbilityIconsFramework.CHARACTERSETTINGS = ZO_SavedVars:NewCharacterIdSettings("AbilityIconsFramework_SavedVariables", AbilityIconsFramework.SAVEDVARIABLES_VERSION, "character_settings", AbilityIconsFramework.DEFAULT_SETTINGS)
    AbilityIconsFramework.CleanupCharacterIdSettings(AbilityIconsFramework_SavedVariables, AbilityIconsFramework.DEFAULT_SETTINGS, "character_settings")

    -- Migrate legacy separate SV tables if present from ancient AIF v1.x installs
    if AbilityIconsFramework_Globals and AbilityIconsFramework_Globals["Default"] and AbilityIconsFramework_Globals["Default"][GetDisplayName()] then
        local oldGlobals = AbilityIconsFramework_Globals["Default"][GetDisplayName()]["$AccountWide"]
        if oldGlobals and oldGlobals["global_settings"] and not AbilityIconsFramework.GLOBALSETTINGS._migrated then
            for k, v in pairs(oldGlobals["global_settings"]) do
                if AbilityIconsFramework.GLOBALSETTINGS[k] == nil then
                    AbilityIconsFramework.GLOBALSETTINGS[k] = v
                end
            end
            AbilityIconsFramework.GLOBALSETTINGS._migrated = true
        end
    end

    currentIconsResolution = AbilityIconsFramework.GetSettings().resolution

    AbilityIconsFramework.InitBaseIconsPath()

    -- LibAddonMenu-2.0 is guaranteed by manifest dependency
    local LAM2 = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = GetString(SI_AIF_PANEL_NAME),
        displayName = "|c66b2b2Ability|r |cffbf00Icons|r |c6C3BAAFramework|r " .. AbilityIconsFramework.version,
        author = "|ce6202dKwiebe-Kwibus|r & Asquart",
        version = AbilityIconsFramework.version,
        website = "https://www.esoui.com/downloads/info4061-AbilityIconsFramework.html",
        slashCommand = "/aifgb",
        registerForRefresh = true,
        registerForDefaults = true
    }

    LAM2:RegisterAddonPanel("AbilityIconsFramework_Panel", panelData)

    local optionsData = {
        {
            type = "header",
            name = GetString(SI_AIF_SETTINGS_HEADER),
        },
        {
            type = "checkbox",
            name = GetString(SI_AIF_GLOBAL_SETTINGS),
            getFunc = function()
                return AbilityIconsFramework.CONFIG.saveSettingsGlobally
            end,
            setFunc = AbilityIconsFramework.SetOptionGlobalIcons
        },
        {
            type = "checkbox",
            name = GetString(SI_AIF_SCRIBING_ICONS),
            getFunc = function()
                return AbilityIconsFramework.GetSettings().showCustomScribeIcons
            end,
            setFunc = AbilityIconsFramework.SetOptionCustomIcons
        },
        {
            type = "checkbox",
            name = GetString(SI_AIF_BASE_GAME_ICONS),
            getFunc = function()
                return AbilityIconsFramework.GetSettings().replaceMismatchedBaseIcons
            end,
            setFunc = AbilityIconsFramework.SetOptionMismatchedIcons
        },
        {
            type = "checkbox",
            name = GetString(SI_AIF_HEROISM_POTIONS),
            getFunc = function()
                return AbilityIconsFramework.GetSettings().enableHeroismPotionIcons
            end,
            setFunc = AbilityIconsFramework.SetHeroismPotionIconsEnabled
        },
        {
            type = "dropdown",
            name = GetString(SI_AIF_RESOLUTION),
            tooltip = GetString(SI_AIF_RESOLUTION_TIP),
            choices = AbilityIconsFramework.resolutionChoices,
            scrollable = false,
            getFunc = function() return AbilityIconsFramework.GetSettings().resolution end,
            setFunc = function(selected)
                AbilityIconsFramework.GetSettings().resolution = selected
            end,
            default = AbilityIconsFramework.GetSettings().resolution,
            warning = GetString(SI_AIF_RESOLUTION_WARN),
        },
        {
            type = "button",
            name = GetString(SI_AIF_RELOAD_UI),
            width = "full",
            func = function() ReloadUI("ingame") end,
            disabled = function() return AbilityIconsFramework.GetSettings().resolution == currentIconsResolution end
        },
        {
            type = "submenu",
            name = GetString(SI_AIF_PACK_ORDER_SUBMENU),
            controls = {
                {
                    -- Interactive drag-and-drop orderlistbox control provided by LibAddonMenuOrderListBox.
                    -- Allows users to visually reorder registered icon packs to resolve priority conflicts.
                    type = "orderlistbox",
                    name = GetString(SI_AIF_PACK_PRIORITY),
                    listEntries = AbilityIconsFramework.packSortOrderEntries,
                    disableDrag = false,
                    disableButtons = true,
                    showPosition = true,
                    getFunc = function() return AbilityIconsFramework.packSortOrderEntries end,
                    setFunc = function(sortedSortListEntries)
                        AbilityIconsFramework.packSortOrderEntries = sortedSortListEntries
                        AbilityIconsFramework.UpdatePackLoadOrderFromSortEntries()
                        AbilityIconsFramework.ApplyPackLoadOrderChanges()
                    end,
                    width = "full",
                    isExtraWide = true,
                    rowFont = "ZoFontWinH1",
                    minHeight = 250,
                    maxHeight = 400,
                    rowHeight = 45,
                    showRemoveEntryButton = false,
                },
            }
        },
    }

    LAM2:RegisterOptionControls("AbilityIconsFramework_Panel", optionsData)
end

--------------------------------------------------------------------------------
-- Settings Accessor & Schema Cleanup
--------------------------------------------------------------------------------

--- Retrieves the active settings table (either Account-Wide or Character-Specific),
--- dynamically switching based on the user's `saveSettingsGlobally` choice.
--- Returns nil if invoked before SavedVariables initialization finishes.
--- @return table? activeSettings
function AbilityIconsFramework.GetSettings()
    if AbilityIconsFramework.GLOBALSETTINGS == nil and AbilityIconsFramework.CHARACTERSETTINGS == nil then
        return nil
    end

    if AbilityIconsFramework.CONFIG and AbilityIconsFramework.CONFIG.saveSettingsGlobally then
        return AbilityIconsFramework.GLOBALSETTINGS or AbilityIconsFramework.DEFAULT_SETTINGS
    else
        return AbilityIconsFramework.CHARACTERSETTINGS or AbilityIconsFramework.DEFAULT_SETTINGS
    end
end

--- The Marie Kondo helper for SavedVariables:
--- If an existing key in SavedVariables doesn't exist in the current defaultConfig schema,
--- we discard it. This keeps SV clean, prevents phantom settings from sticking around
--- across major addon versions, and reduces SavedVariables file bloat on disk.
local function PruneStaleKeys(currentConfig, defaultConfig)
    if not (currentConfig and defaultConfig) then return end
    for key in pairs(currentConfig) do
        if key ~= "version" and defaultConfig[key] == nil then
            currentConfig[key] = nil
        end
    end
end

--- Safely cleans up stale keys from account-wide SavedVariables tables.
--- @param savedVars table The raw account-wide SavedVariables table.
--- @param defaultConfig table The default configuration schema.
--- @param namespace string? Optional sub-table namespace within accountData.
function AbilityIconsFramework.CleanupAccountWideSettings(savedVars, defaultConfig, namespace)
    local displayName = GetDisplayName()
    if not (savedVars and savedVars["Default"] and savedVars["Default"][displayName]) then return end
    local accountData = savedVars["Default"][displayName]["$AccountWide"]
    if not accountData then return end
    local currentConfig = namespace and accountData[namespace] or accountData
    PruneStaleKeys(currentConfig, defaultConfig)
end

--- Safely cleans up stale keys from character-specific SavedVariables tables.
--- @param savedVars table The raw character-specific SavedVariables table.
--- @param defaultConfig table The default configuration schema.
--- @param namespace string? Optional sub-table namespace within charData.
function AbilityIconsFramework.CleanupCharacterIdSettings(savedVars, defaultConfig, namespace)
    local displayName = GetDisplayName()
    if not (savedVars and savedVars["Default"] and savedVars["Default"][displayName]) then return end
    local charData = savedVars["Default"][displayName][GetCurrentCharacterId()]
    if not charData then return end
    local currentConfig = namespace and charData[namespace] or charData
    PruneStaleKeys(currentConfig, defaultConfig)
end

--------------------------------------------------------------------------------
-- Settings Mutation Handlers (SetFuncs)
--------------------------------------------------------------------------------

--- Toggles account-wide versus per-character icon configurations.
--- Synchronizes critical options from the previous profile to the newly selected profile
--- so the player's preferences don't vanish into the Void during the transition.
--- @param value boolean True for account-wide, false for per-character.
function AbilityIconsFramework.SetOptionGlobalIcons(value)
    local oldSettings = AbilityIconsFramework.GetSettings()
    AbilityIconsFramework.CONFIG.saveSettingsGlobally = value
    local newSettings = AbilityIconsFramework.GetSettings()
    if oldSettings and newSettings then
        newSettings.showCustomScribeIcons = oldSettings.showCustomScribeIcons
        newSettings.replaceMismatchedBaseIcons = oldSettings.replaceMismatchedBaseIcons
        newSettings.enableHeroismPotionIcons = oldSettings.enableHeroismPotionIcons
        newSettings.resolution = oldSettings.resolution
    end
    AbilityIconsFramework.InitializeSortOrderEntries()
    AbilityIconsFramework.ApplyPackLoadOrderChanges()
end

--- Toggles custom Focus-Script-based icons for Scribed Grimoires.
--- @param value boolean True to enable dynamic scribed icons, false for vanilla icons.
function AbilityIconsFramework.SetOptionCustomIcons(value)
    AbilityIconsFramework.GetSettings().showCustomScribeIcons = value
    AbilityIconsFramework.UpdateDefaultScribingIcons()
    AbilityIconsFramework.UpdateAllSlots()
end

--- Toggles high-resolution replacements for blurry vanilla base-game icons.
--- @param value boolean True to enable HD replacements, false for vanilla.
function AbilityIconsFramework.SetOptionMismatchedIcons(value)
    AbilityIconsFramework.GetSettings().replaceMismatchedBaseIcons = value
    AbilityIconsFramework.ReplaceMismatchedIcons()
    AbilityIconsFramework.UpdateAllSlots()
end

--- Toggles custom glowing purple icons and colorized tooltips for Heroism potions.
--- Immediately refreshes bag slot caches to reflect the change.
--- @param value boolean True to enable heroism potion overrides, false for vanilla.
function AbilityIconsFramework.SetHeroismPotionIconsEnabled(value)
    AbilityIconsFramework.GetSettings().enableHeroismPotionIcons = value
    if AbilityIconsFramework.RefreshInventoryHeroismPotions then
        AbilityIconsFramework.RefreshInventoryHeroismPotions()
    end
    AbilityIconsFramework.UpdateAllSlots()
end
