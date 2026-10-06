-- Trial Tagger: entry point, settings registration and slash commands.

TrialTagger = TrialTagger or {}
local TT = TrialTagger

TT.name = "TrialTagger"
TT.version = "0.1.0"

local DEFAULTS = {
    harvest = nil,
    harvestedAt = 0,
}

local function message(text)
    d("|c3498db[Trial Tagger]|r " .. text)
end

-- A fallback, not the main route: the panel is opened from the Settings menu,
-- which is the only thing a console player can reach. These exist so the addon
-- still works when LibAddonMenu-2.0 is missing, and because typing is faster
-- than three menus when you are filling in the catalog.
local function onSlashCommand(argument)
    argument = string.lower(argument or "")

    if argument == "harvest" then
        TT.UI.ToggleHarvest()
    elseif argument == "next" then
        TT.UI.StepHarvest(1)
    elseif argument == "prev" or argument == "previous" then
        TT.UI.StepHarvest(-1)
    elseif argument == "dump" then
        -- PC only: SavedVariables are written to disk on logout/reload, which
        -- is far faster than transcribing ids off the harvest screen.
        local dump = TT.Scanner.DumpToSavedVars(TT.sv)
        local count = 0
        for _ in pairs(dump) do count = count + 1 end
        message(string.format(
            "dumped %d achievement categories to SavedVariables. Type /reloadui, then read " ..
            "live/SavedVariables/TrialTagger.lua.", count
        ))
    elseif argument == "help" then
        message("/trialtag          show or hide the proof panel")
        message("/trialtag harvest  browse achievement ids on screen")
        message("/trialtag next     id browser: next page")
        message("/trialtag prev     id browser: previous page")
        message("/trialtag dump     write all achievement ids to SavedVariables (PC only)")
    else
        TT.UI.Toggle()
    end
end

local function onAddOnLoaded(_, addOnName)
    if addOnName ~= TT.name then return end
    EVENT_MANAGER:UnregisterForEvent(TT.name, EVENT_ADD_ON_LOADED)

    TT.sv = ZO_SavedVars:NewAccountWide("TrialTaggerSV", 1, nil, DEFAULTS)

    TT.UI.BuildPanel()

    SLASH_COMMANDS["/trialtag"] = onSlashCommand
    SLASH_COMMANDS["/trialtagger"] = onSlashCommand

    if not TT.Settings.Register() then
        -- Say so once. Otherwise the addon looks installed but inert: there is
        -- no keybind to find and no menu entry to click.
        message(
            "loaded, but LibAddonMenu-2.0 is not installed, so there is no " ..
            "Settings entry. Type |cffffff/trialtag|r to show the proof panel."
        )
    end
end

EVENT_MANAGER:RegisterForEvent(TT.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)
