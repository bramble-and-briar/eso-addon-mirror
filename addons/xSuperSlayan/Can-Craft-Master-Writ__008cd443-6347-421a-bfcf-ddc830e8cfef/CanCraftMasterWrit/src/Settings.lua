-- The player's settings, saved account-wide in CanCraftMasterWritSavedVars (see ## SavedVariables in the manifest).
-- The settings menu (src/Menu.lua) changes them; the evaluator and the tooltip read them.

local addon = CanCraftMasterWrit
local Result = addon.Result

local Settings = {}
addon.Settings = Settings

local SAVED_VARIABLES_NAME = "CanCraftMasterWritSavedVars"
local SAVED_VARIABLES_VERSION = 1

Settings.DEFAULTS = {
    -- Requirements. Turning one off drops its line from the tooltip and from the overall status.
    checkMaterials = true,
    checkSetTraits = true,
    checkTraitResearch = true,
    -- Which lines the tooltip shows. Neither changes the overall status.
    showMissing = true, -- Failed and unknown lines.
    showKnown = true,   -- Passed lines and information such as the runes or reagents to use.
    -- The version whose "What's New" pop-up was last shown, so it appears once per update.
    lastSeenVersion = nil,
}

-- The requirement setting behind each category that can be turned off. Other categories are always checked.
local CATEGORY_SETTING = {
    [Result.CATEGORY_MATERIALS] = "checkMaterials",
    [Result.CATEGORY_SET] = "checkSetTraits",
    [Result.CATEGORY_TRAIT] = "checkTraitResearch",
}

local savedVars

function Settings.Initialize()
    savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES_NAME, SAVED_VARIABLES_VERSION, nil, Settings.DEFAULTS)
end

function Settings.Get(key)
    if savedVars and savedVars[key] ~= nil then
        return savedVars[key]
    end
    return Settings.DEFAULTS[key]
end

function Settings.Set(key, value)
    if savedVars then
        savedVars[key] = value
    end
    -- Cached results were worked out with the old settings.
    addon.Evaluator.ClearCache()
end

-- Returns whether checks in this category count, given the requirement settings.
function Settings.IsCategoryChecked(category)
    local key = CATEGORY_SETTING[category]
    return key == nil or Settings.Get(key) ~= false
end

-- Returns whether the tooltip shows a line in this state, given the display settings.
function Settings.IsStateShown(state)
    if state == Result.STATE_FAIL or state == Result.STATE_UNKNOWN then
        return Settings.Get("showMissing") ~= false
    end
    return Settings.Get("showKnown") ~= false
end
