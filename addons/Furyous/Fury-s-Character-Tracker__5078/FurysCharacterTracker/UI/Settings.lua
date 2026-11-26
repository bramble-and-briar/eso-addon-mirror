-- Settings page (Settings > Addons > Fury's Character Tracker), built with LibAddonMenu-2.0.
-- The gear button on the board and /fct settings open it.
local CT = FurysCharacterTracker
local U = CT.Util
local Settings = {}
CT.Settings = Settings

local LAM = LibAddonMenu2

-- Puts every window back in the middle of the screen.
local function ResetWindows()
    local sv = CT.sv
    sv.window, sv.bragWindow, sv.timersWindow, sv.detailsWindow = nil, nil, nil, nil
    for _, window in ipairs(CT.Windows()) do
        window[1]:ClearAnchors()
        window[1]:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    U.Print("Windows moved back to the middle of the screen.")
end

local function ShowRemoved()
    CT.Roster:ShowAll()
    CT.Refresh()
end

-- One checkbox per switch of the Start here page (Data/Text.lua), so the two cannot disagree.
local function Checkbox(switch)
    local function Get() return CT.Pages.SwitchOn(switch) end
    local function Set(value) CT.SetSwitch(switch, value) end
    return { type = "checkbox", name = switch.label, tooltip = "Turned on: " .. switch.about, getFunc = Get, setFunc = Set }
end

function Settings:Build()
    local panel = {
        type = "panel",
        name = "Fury's Character Tracker",
        displayName = "|cA08CFFFury's Character Tracker|r",
        author = "Furyous",
        version = CT.version,
        website = "https://www.esoui.com/downloads/info5078.html",
        slashCommand = "/fctsettings",
        registerForRefresh = true,
    }
    local options = {
        { type = "description",
          text = "New here? The Start here page explains the whole board in one page. " ..
                 "Everything below starts turned off on a new install." },
        { type = "button", name = "Open Start here", width = "half",
          tooltip = "One page on how the board works: getting your characters on it, the colors, the tabs and the alert switches.\n(also /fct start)",
          func = function() CT.Details:ShowStart() end },
        { type = "button", name = "Open the board", width = "half", tooltip = "Opens the character board.\n(also /fct, or a key you bind)",
          func = function() CT.Window:Show() end },
        { type = "header", name = "Alerts while you play" },
    }
    local boardSwitches = {}
    for _, switch in ipairs(CT.TEXT.SWITCHES) do
        if switch.field == "openAtLogin" then boardSwitches[#boardSwitches + 1] = Checkbox(switch) else options[#options + 1] = Checkbox(switch) end
    end
    local rest = {
        { type = "header", name = "Board" },
        boardSwitches[1],
        { type = "button", name = "Reset window positions", width = "half",
          tooltip = "Moves every window of the addon back to the middle of the screen.",
          func = ResetWindows },
        { type = "button", name = "Show removed characters", width = "half",
          tooltip = "Puts back every character you removed with right-click > Remove from board.",
          func = ShowRemoved },
        { type = "description",
          text = "Key bindings for the board, the brag card and research timers: Controls > Keybindings > Fury's Character Tracker." },

        { type = "header", name = "Windows Tools" },
        { type = "description",
          text = "The offline viewer and the Excel export run outside the game, so ESOUI's rules keep them out of the addon download. " ..
                 "They're a separate free zip: unzip it into any folder, for example Documents\\Elder Scrolls Online." },
        { type = "button", name = "Get the Windows Tools",
          tooltip = "Opens the download page on GitHub in your browser. The game asks before it opens.",
          func = function() RequestOpenUnsafeURL(CT.toolsUrl) end },

        { type = "header", name = "Export to Excel (Windows)" },
        { type = "description",
          text = "Needs the Windows Tools (button above). The easy way: open the offline viewer and click Save for Excel there. Nothing to set up, no reload. " ..
                 "The other way: double-click Turn On Auto Export.cmd in the Windows Tools folder once (a file there, not a setting here). It starts a small helper, and after that Export to Excel here or on the board saves " ..
                 "ESO Characters.csv in Documents\\Elder Scrolls Online a few seconds after the UI reloads." },
        { type = "button", name = "Export to Excel now", tooltip = "Saves the board for the Windows Tools and reloads the UI. It asks first, and you can cancel.",
          func = function() CT.ConfirmExport() end },

        { type = "header", name = "Offline viewer (Windows)" },
        { type = "description",
          text = "Open Offline Viewer.cmd in the Windows Tools shows everything saved, for every account and megaserver on this PC, in your browser with no game running. " ..
                 "It has its own Start here page and a Save for Excel button. The game saves when you log out or /reloadui; run it again to see new data." },
    }
    for _, option in ipairs(rest) do options[#options + 1] = option end
    CT.Theme.MoreOptions(options)   -- 1.5.7: the other Fury addons, at the very end
    self.panel = LAM:RegisterAddonPanel("FurysCharacterTracker_Settings", panel)
    LAM:RegisterOptionControls("FurysCharacterTracker_Settings", options)
end

function Settings:Open()
    -- Close the addon's windows first so they don't sit on top of the settings page.
    for _, window in ipairs(CT.Windows()) do
        if not window[1]:IsHidden() then SCENE_MANAGER:HideTopLevel(window[1]) end
    end
    LAM:OpenToPanel(self.panel)
end
