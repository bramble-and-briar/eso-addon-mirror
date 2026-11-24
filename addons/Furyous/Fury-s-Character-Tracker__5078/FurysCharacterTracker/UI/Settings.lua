-- Settings page (Settings > Addons > Fury's Character Tracker), built with LibAddonMenu-2.0.
-- The gear button on the board and /fct settings open it.
local CT = FurysCharacterTracker
local U = CT.Util
local Settings = {}
CT.Settings = Settings

local LAM = LibAddonMenu2

-- Puts every window back in the middle of the screen.
local function ResetWindows()
    CT.sv.window, CT.sv.bragWindow, CT.sv.timersWindow, CT.sv.detailsWindow = nil, nil, nil, nil
    for _, control in ipairs({ FurysCharacterTracker_Window, FurysCharacterTracker_Brag, FurysCharacterTracker_Timers, FurysCharacterTracker_Details }) do
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    U.Print("Windows moved back to the middle of the screen.")
end

function Settings:Build()
    local panel = {
        type = "panel",
        name = "Fury's Character Tracker",
        displayName = "|cA08CFFFury's Character Tracker|r",
        author = "Furyous",
        version = CT.version,
        slashCommand = "/fctsettings",
        registerForRefresh = true,
    }
    local options = {
        { type = "header", name = "Alerts while you play" },
        { type = "checkbox", name = "Research finished",
          tooltip = "A chat line when research finishes on any character, on any account or megaserver saved on this PC.",
          getFunc = function() return CT.sv.alertResearch ~= false end,
          setFunc = function(value) CT.sv.alertResearch = value; CT.Alerts:Restart() end },
        { type = "checkbox", name = "Riding lesson ready",
          tooltip = "A chat line when a character can take its next riding lesson.",
          getFunc = function() return CT.sv.alertRiding ~= false end,
          setFunc = function(value) CT.sv.alertRiding = value; CT.Alerts:Restart() end },
        { type = "checkbox", name = "Summary at login",
          tooltip = "At login, one chat line naming the characters whose research finished or whose riding lesson is ready while you were away.",
          getFunc = function() return CT.sv.loginNotice ~= false end,
          setFunc = function(value) CT.sv.loginNotice = value end },

        { type = "header", name = "Board" },
        { type = "checkbox", name = "Open the board at login",
          getFunc = function() return CT.sv.openAtLogin == true end,
          setFunc = function(value) CT.sv.openAtLogin = value end },
        { type = "button", name = "Reset window positions", width = "half",
          tooltip = "Moves the board, brag card, research timers and details windows back to the middle of the screen.",
          func = ResetWindows },
        { type = "button", name = "Show removed characters", width = "half",
          tooltip = "Puts back every character you removed with right-click > Remove from board.",
          func = function() CT.Roster:ShowAll(); CT.Window:RefreshIfShown() end },
        { type = "description", text = "Key bindings for the board, brag card and research timers: Controls > Keybindings > Fury's Character Tracker." },

        { type = "header", name = "Windows Tools" },
        { type = "description",
          text = "The offline viewer and the Excel export run outside the game, so ESOUI's rules keep them out of the addon download. " ..
                 "They're a separate free zip: unzip it into any folder, for example Documents\\Elder Scrolls Online." },
        { type = "button", name = "Get the Windows Tools",
          tooltip = "Opens the download page on GitHub in your browser. The game asks before it opens.",
          func = function() RequestOpenUnsafeURL(CT.toolsUrl) end },

        { type = "header", name = "Export to Excel (Windows)" },
        { type = "description",
          text = "Needs the Windows Tools (button above). Turn On Auto Export.cmd there starts a small helper. " ..
                 "After that, Export to Excel saves ESO Characters.csv in Documents\\Elder Scrolls Online a few seconds after the UI reloads." },
        { type = "button", name = "Export to Excel now", warning = "Reloads the UI.", func = function() CT.RequestExport() end },

        { type = "header", name = "Offline viewer (Windows)" },
        { type = "description",
          text = "Open Offline Viewer.cmd in the Windows Tools shows everything saved, for every account and megaserver on this PC, in your browser with no game running. " ..
                 "The game saves when you log out or /reloadui; run it again to see new data." },
    }
    self.panel = LAM:RegisterAddonPanel("FurysCharacterTracker_Settings", panel)
    LAM:RegisterOptionControls("FurysCharacterTracker_Settings", options)
end

function Settings:Open()
    -- Close the addon's windows first so they don't sit on top of the settings page.
    for _, control in ipairs({ FurysCharacterTracker_Window, FurysCharacterTracker_Brag, FurysCharacterTracker_Timers, FurysCharacterTracker_Details }) do
        if not control:IsHidden() then SCENE_MANAGER:HideTopLevel(control) end
    end
    LAM:OpenToPanel(self.panel)
end
