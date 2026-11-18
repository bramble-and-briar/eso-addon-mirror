-- Settings panel. One option list, rendered with LibHarvensAddonSettings
-- (gamepad / console, preferred there) or LibAddonMenu-2.0 (PC). On console there
-- are no slash commands, so the panel also has an "Open Scoreboard Remastered" button.
local SBR = ScoreboardRemastered
local Settings = {}
SBR.Settings = Settings

local function Options()
    local sv = SBR.sv
    local function refresh() SBR.Window:Refresh() end
    local openKeyChoices, openKeyValues = {}, {}
    for _, id in ipairs({ "right_stick", "left_stick", "quaternary" }) do
        openKeyChoices[#openKeyChoices + 1] = SBR.Gamepad.OPEN_KEYS[id].label
        openKeyValues[#openKeyValues + 1] = id
    end
    return {
        { type = "button", name = "Open Scoreboard Remastered", func = function() SBR.Window:Show(true) end },
        { type = "button", name = "Open battleground records", func = function() SBR.MatchBrowser:Open() end },
        { type = "header", name = "Inventory" },
        { type = "checkbox", name = "Battleground records in the inventory",
          tooltip = "A button on the PC inventory window, and an entry on the gamepad inventory's button bar. Takes effect after /reloadui.",
          get = function() return sv.inventoryButton end, set = function(v) sv.inventoryButton = v end },
        { type = "dropdown", name = "Gamepad inventory button",
          choices = openKeyChoices, values = openKeyValues,
          get = function() return sv.inventoryKey end, set = function(v) sv.inventoryKey = v end },
        { type = "header", name = "Display" },
        { type = "checkbox", name = "Open with the native scoreboard (mouse)", pcOnly = true,
          tooltip = "In keyboard mode the panel opens and closes with the battleground scoreboard.",
          get = function() return sv.autoShowWithScoreboard end, set = function(v) sv.autoShowWithScoreboard = v end },
        { type = "dropdown", name = "Gamepad: button to open from the scoreboard",
          tooltip = "Shown on the native battleground scoreboard's button bar in gamepad mode.",
          choices = openKeyChoices, values = openKeyValues,
          get = function() return sv.gamepadOpenKey end,
          set = function(v) sv.gamepadOpenKey = v; SBR.Gamepad:RemoveOpenKeybind() end },
        { type = "dropdown", name = "Gamepad: scoreboard layout",
          tooltip = "Table: the same table as on PC, with the selected player's details beside it. List: ESO's gamepad list screen with tabs.",
          choices = { "Table (like PC)", "List" }, values = { "table", "list" },
          get = function() return sv.consoleLayout end,
          set = function(v) sv.consoleLayout = v end },
        { type = "dropdown", name = "Attach position", pcOnly = true,
          tooltip = "Over: centred above the native scoreboard on a dimmed backdrop (the panel is wider than the space beside the board). Right / Left / Below: next to the native board, kept on screen.",
          choices = { "Over the scoreboard", "Right", "Left", "Below", "Free" }, values = { "over", "right", "left", "below", "free" },
          get = function() return sv.attach end,
          set = function(v) sv.attach = v; SBR.Window:ResetPosition() end },
        { type = "button", name = "Reset position", pcOnly = true, func = function() SBR.Window:ResetPosition() end },
        { type = "slider", name = "Scale (mouse UI)", pcOnly = true, min = 60, max = 150, step = 5,
          get = function() return math.floor((sv.scale or 1) * 100) end,
          set = function(v)
              sv.scale = v / 100
              if SBR.Window.control and SBR.Window.mode == "keyboard" then SBR.Window.control:SetScale(sv.scale) end
          end },
        { type = "checkbox", name = "Group rows by team",
          get = function() return sv.groupByTeam end, set = function(v) sv.groupByTeam = v; refresh() end },
        { type = "checkbox", name = "Hide columns that are all zero",
          get = function() return sv.hideEmptyColumns end, set = function(v) sv.hideEmptyColumns = v; refresh() end },
        { type = "checkbox", name = "Show fight columns",
          get = function() return sv.showFightColumns end, set = function(v) sv.showFightColumns = v; refresh() end },
        { type = "checkbox", name = "Show 'you vs them' columns (mouse UI)", pcOnly = true,
          tooltip = "In gamepad mode these are in the details pane.",
          get = function() return sv.showVsColumns end, set = function(v) sv.showVsColumns = v; refresh() end },
        { type = "header", name = "LibFights" },
        { type = "checkbox", name = "Use LibFights",
          tooltip = "Starts LibFights logging for each battleground (unless it's already running) and stops it again afterwards.",
          get = function() return sv.useLibFights end, set = function(v) sv.useLibFights = v end },
        { type = "checkbox", name = "Also save fights in LibFights' SavedVariables",
          get = function() return sv.lfSaveFights end, set = function(v) sv.lfSaveFights = v end },
        { type = "header", name = "Logging" },
        { type = "checkbox", name = "Fight stats for every player (combat ledger)",
          tooltip = "Reads every combat event the client sends during a battleground: full stats for your group, and what enemies did to and took from your team.",
          get = function() return sv.trackCombat end, set = function(v) sv.trackCombat = v end },
        { type = "checkbox", name = "Print match summary to chat",
          get = function() return sv.chatSummary end, set = function(v) sv.chatSummary = v end },
        { type = "slider", name = "Matches kept in history", min = 5, max = SBR.IsConsole() and 25 or 200, step = 5,
          get = function() return sv.maxHistory end, set = function(v) sv.maxHistory = v end },
        { type = "slider", name = "Match database records", min = 50, max = SBR.IsConsole() and 300 or 1000, step = 50,
          tooltip = "Compact summaries for the match database and lifetime stats. Kept far longer than full scoreboards.",
          get = function() return sv.maxRecords end, set = function(v) sv.maxRecords = v end },
        { type = "button", name = "Clear history", dangerous = true, func = function() SBR.MatchLog:ClearHistory() end },
        { type = "button", name = "Clear match database", dangerous = true,
          func = function() ZO_ClearNumericallyIndexedTable(SBR.MatchDB:GetRecords()) end },
        { type = "checkbox", name = "Debug output",
          get = function() return sv.debug end, set = function(v) sv.debug = v end },
    }
end

local function IndexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return 1
end

local function CreateHarvens(LHAS)
    local panel = LHAS:AddAddon("Scoreboard Remastered", { allowDefaults = false, allowRefresh = true })
    if not panel then return false end
    for _, o in ipairs(Options()) do
        if not (o.pcOnly and SBR.IsConsole()) then
            local s
            if o.type == "header" then
                s = { type = LHAS.ST_SECTION, label = o.name }
            elseif o.type == "checkbox" then
                s = { type = LHAS.ST_CHECKBOX, label = o.name, tooltip = o.tooltip,
                      getFunction = o.get, setFunction = o.set }
            elseif o.type == "slider" then
                s = { type = LHAS.ST_SLIDER, label = o.name, tooltip = o.tooltip, min = o.min, max = o.max, step = o.step,
                      format = "%d", getFunction = o.get, setFunction = o.set }
            elseif o.type == "dropdown" then
                local items = {}
                for i, label in ipairs(o.choices) do items[i] = { name = label, data = o.values[i] } end
                s = { type = LHAS.ST_DROPDOWN, label = o.name, tooltip = o.tooltip, items = items,
                      getFunction = function() return o.choices[IndexOf(o.values, o.get())] end,
                      setFunction = function(_, _, item) o.set(item.data) end }
            elseif o.type == "button" then
                s = { type = LHAS.ST_BUTTON, label = o.name, buttonText = o.name, clickHandler = o.func }
            end
            if s and s.type ~= nil then SBR.SafeCall(panel.AddSetting, panel, s) end
        end
    end
    return true
end

local function CreateLAM(LAM)
    LAM:RegisterAddonPanel("ScoreboardRemasteredOptions", {
        type = "panel",
        name = "Scoreboard Remastered",
        displayName = SBR.displayName,
        version = SBR.version,
        registerForRefresh = true,
    })
    local controls = {}
    for _, o in ipairs(Options()) do
        local c
        if o.type == "header" then
            c = { type = "header", name = o.name }
        elseif o.type == "checkbox" or o.type == "slider" then
            c = { type = o.type, name = o.name, tooltip = o.tooltip, min = o.min, max = o.max, step = o.step,
                  getFunc = o.get, setFunc = o.set }
        elseif o.type == "dropdown" then
            c = { type = "dropdown", name = o.name, tooltip = o.tooltip, choices = o.choices, choicesValues = o.values,
                  getFunc = o.get, setFunc = o.set }
        elseif o.type == "button" then
            c = { type = "button", name = o.name, func = o.func, isDangerous = o.dangerous,
                  warning = o.dangerous and "Deletes all saved matches." or nil }
        end
        controls[#controls + 1] = c
    end
    LAM:RegisterOptionControls("ScoreboardRemasteredOptions", controls)
    return true
end

function Settings:Create()
    local LHAS = _G.LibHarvensAddonSettings
    local LAM = _G.LibAddonMenu2 or (LibStub and LibStub("LibAddonMenu-2.0", true))
    -- console / gamepad: LibHarvensAddonSettings first, like LibFights does
    if LHAS and (SBR.IsGamepad() or not LAM) then
        if SBR.SafeCall(CreateHarvens, LHAS) then return end
    end
    if LAM then SBR.SafeCall(CreateLAM, LAM) end
end
