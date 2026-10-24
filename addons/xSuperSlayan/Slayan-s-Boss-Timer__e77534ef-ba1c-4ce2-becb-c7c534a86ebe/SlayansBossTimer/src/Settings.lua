-- The player's settings, saved account-wide in SlayansBossTimerSavedVars (see ## SavedVariables in the manifest).
-- The settings menu (src/Menu.lua) changes them; the rest of the add-on reads them.

local addon = SlayansBossTimer

local Settings = {}
addon.Settings = Settings

local SAVED_VARIABLES_NAME = "SlayansBossTimerSavedVars"
local SAVED_VARIABLES_VERSION = 1

-- The boss timers themselves are saved here too, under "timers" (src/Timers.lua), with no default: a default table
-- would be shared rather than copied.
Settings.DEFAULTS = {
    -- The version whose "What's New" pop-up was last shown, so it appears once per update.
    lastSeenVersion = nil,

    -- Timer Settings.
    showCountdown = true,
    showAlert = true,
    playSound = true,
    showChat = true,
    -- The countdown's text size: "small", "medium", "large" or "xLarge" (see src/Countdown.lua).
    fontSize = "medium",
    -- Where the countdown sits: next to a part of the game's screen ("topLeft", "questTracker" for Top Right, or
    -- "center"), or "free" for Custom (see src/Countdown.lua).
    countdownPosition = "questTracker",
    -- Its place for Custom, as a share of the screen (0 to 100) from the left and from the top.
    countdownX = 75,
    countdownY = 40,
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
end
