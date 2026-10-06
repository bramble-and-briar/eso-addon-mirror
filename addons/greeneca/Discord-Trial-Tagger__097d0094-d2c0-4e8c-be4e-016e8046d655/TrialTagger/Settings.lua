-- Trial Tagger: the entry in the game's Settings menu.
--
-- This is the normal way to open the panel, and on console it is the only one.
-- There are deliberately no keybinds: a binding does nothing until the player
-- finds the controls screen and assigns it, which is a poor first run when the
-- addon has exactly one thing to do.
--
-- LibAddonMenu-2.0 is an *optional* dependency. On console the library hands
-- its panels to LibHarvensAddonSettings to draw, and that library has been
-- pulled from the store before; a hard dependency would mean the addon fails
-- to load at all rather than falling back to the slash command.

TrialTagger = TrialTagger or {}
local TT = TrialTagger
local Settings = {}
TT.Settings = Settings

local PANEL_ID = "TrialTaggerOptions"

--- Register the settings panel. Returns false when the library is absent.
function Settings.Register()
    local LAM = LibAddonMenu2
    if not LAM or not LAM.RegisterAddonPanel then
        return false
    end

    LAM:RegisterAddonPanel(PANEL_ID, {
        type = "panel",
        name = "Trial Tagger",
        displayName = "Trial Tagger",
        author = "Trial Tagger",
        version = TT.version,
        registerForRefresh = true,
    })

    LAM:RegisterOptionControls(PANEL_ID, {
        {
            type = "description",
            text = "Show the proof panel, take a screenshot of it, then post that " ..
                   "screenshot in Discord and tag the bot. The code is rebuilt every " ..
                   "time the panel opens and expires, so always take a fresh shot.",
        },
        {
            type = "button",
            name = "Show proof panel",
            tooltip = "Closes this menu and draws the panel over the world, ready to screenshot.",
            func = function() TT.UI.ShowFromMenu() end,
            width = "half",
        },
        {
            type = "button",
            name = "Hide proof panel",
            tooltip = "Hides the panel. It also hides itself as soon as you open any menu.",
            func = function() TT.UI.Hide() end,
            width = "half",
        },
        {
            type = "description",
            title = "Setup tools",
            text = "Only needed by whoever maintains the Discord bot's achievement list.",
        },
        {
            type = "button",
            name = "Browse achievement IDs",
            tooltip = "Lists every achievement and its id, to be copied into the bot's " ..
                      "catalog. Scroll it with the mouse wheel.",
            func = function() TT.UI.ShowHarvestFromMenu() end,
            width = "half",
        },
    })

    return true
end
