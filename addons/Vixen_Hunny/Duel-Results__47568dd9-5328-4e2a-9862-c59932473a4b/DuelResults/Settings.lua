--[[
    Duel Results - settings panel (LibAddonMenu-2.0, optional)
]]

local DR = DuelResults
local Settings = {}
DR.Settings = Settings

local function Checkbox(key, name, tooltip, onChange)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return DR.sv[key] end,
        setFunc = function(v)
            DR.sv[key] = v
            if onChange then onChange(v) end
        end,
        default = DR.defaults[key],
    }
end

function Settings.Init()
    local LAM = LibAddonMenu2
    if not LAM then
        DR.UI.settingsButton:SetHidden(true)
        return
    end

    local panelData = {
        type = "panel",
        name = DR.displayName,
        displayName = DR.COLORS.gold:Colorize(DR.displayName),
        author = DR.author,
        version = DR.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    Settings.panel = LAM:RegisterAddonPanel("DuelResultsPanel", panelData)

    local options = {
        {
            type = "description",
            text = "Open the window with |cC5A15A/duelresults|r or bind a key under Controls → Keybindings → Duel Results.",
        },
        {
            type = "button",
            name = "Open Window",
            func = function() DR.UI.Show(true) end,
            width = "half",
        },
        {
            type = "button",
            name = "Print Last Duel",
            func = function() DR.PrintSummary(DR.Tracker.current or DR.sv.history[1]) end,
            width = "half",
        },

        { type = "header", name = "Window" },
        Checkbox("autoShowOnStart", "Show when a duel starts", "Open the window automatically when a tracked duel begins."),
        Checkbox("autoShowOnEnd", "Show when a duel ends", "Open the window automatically when a tracked duel finishes."),
        Checkbox("locked", "Lock window position", nil, function() DR.UI.ApplySettings() end),
        {
            type = "slider",
            name = "Window scale",
            min = 70, max = 130, step = 5,
            getFunc = function() return zo_round((DR.sv.scale or 1) * 100) end,
            setFunc = function(v)
                DR.sv.scale = v / 100
                DR.UI.ApplySettings()
            end,
            default = DR.defaults.scale * 100,
        },
        {
            type = "button",
            name = "Reset Position",
            func = function() DR.UI.ResetPosition() end,
            width = "half",
        },

        { type = "header", name = "Tracking" },
        Checkbox("trackGroupDuels", "Track group members' duels",
            "Watch for two PvP-flagged group members and track them as a duel. The game only reports part of other players' combat, so these numbers are less complete than your own duels."),
        Checkbox("hidePermanent", "Hide permanent effects", "Ignore passives and other effects with no duration in the Effects tab."),
        Checkbox("printOnEnd", "Print summary to chat", "Print a short summary to chat when a duel ends."),

        { type = "header", name = "History" },
        {
            type = "slider",
            name = "Duels to keep",
            min = 5, max = 50, step = 1,
            getFunc = function() return DR.sv.maxHistory end,
            setFunc = function(v)
                DR.sv.maxHistory = v
                local h = DR.sv.history
                while #h > v do table.remove(h) end
            end,
            default = DR.defaults.maxHistory,
        },
        {
            type = "button",
            name = "Clear History",
            func = function()
                ZO_ClearNumericallyIndexedTable(DR.sv.history)
                DR.UI.viewFight = nil
                DR.UI.Refresh()
            end,
            width = "half",
            isDangerous = true,
            warning = "Deletes every saved duel. This can't be undone.",
        },
    }
    LAM:RegisterOptionControls("DuelResultsPanel", options)
end
