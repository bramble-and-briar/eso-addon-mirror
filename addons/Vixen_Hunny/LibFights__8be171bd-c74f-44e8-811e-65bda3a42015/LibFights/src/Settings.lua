--[[
    LibFights - Settings / in-game test panel
    One control list rendered with LibAddonMenu-2.0 (PC default) or
    LibHarvensAddonSettings (console default / fallback). Both are optional.

    The panel lets you test everything in game: start/stop logging, live and last
    fight data, every breakdown, build reader, model predictions, unified search,
    ability-ID lookup and scanner, set lookup and set logging, saved data.
    All output also goes to chat.
]]

local LF = LibFights
local Util = LF.Util
local UI = {}
LF.SettingsUI = UI

local function S() return LF.GetSettings() end

local outputs = {
    live = "Press 'Refresh'.", build = "Press 'Read build'.", models = "Press 'Show predictions'.",
    search = "Type a query and press Enter.", ability = "Type an ability id or name.",
    scan = "Not scanned yet.", set = "Type a set id or name.",
}
local inputs = { search = "", ability = "", set = "", setLog = "" }
local refreshers = {}
UI.usedLibrary = nil

local function Lines(t, maxLines)
    if type(t) ~= "table" then return tostring(t) end
    local out = {}
    for i = 1, math.min(#t, maxLines or 40) do out[i] = t[i] end
    if #t > (maxLines or 40) then out[#out + 1] = string.format("... %d more (see chat)", #t - (maxLines or 40)) end
    return table.concat(out, "\n")
end

function UI.Refresh()
    for _, fn in ipairs(refreshers) do pcall(fn) end
end

function UI.SetOutput(key, text, printLines)
    outputs[key] = type(text) == "table" and Lines(text) or tostring(text)
    if printLines and type(text) == "table" then LF.PrintLines(text) end
    UI.Refresh()
end

local function StatusText()
    local logging = LF.Logger.IsLogging()
    local cur = LF.Logger.GetCurrentFight()
    return string.format("Logging: %s | in fight: %s | fights in memory: %d | saved: %d\nPlatform: %s | UI lib: %s | API %s | v%s",
        logging and "|c00FF00ON|r" or "|cFF6060OFF|r", cur and ("#" .. cur.id) or "no",
        #LF.Logger.GetFights(), LF.Storage.GetSavedFightCount(),
        LF.isConsole and "console" or "PC/Mac", tostring(UI.usedLibrary), tostring(GetAPIVersion()), LF.version)
end

local function LastFight() return LF.Logger.GetLastFight() end

local function PrintFight(fn, ...)
    local f = LastFight()
    if not f then LF.Print("No fight data yet.") return end
    LF.PrintLines(fn(f, ...))
end

-- ---------------------------------------------------------------------------
-- Control specification (library independent)
-- ---------------------------------------------------------------------------
local function BuildSpec()
    local spec = {}
    local function add(e) spec[#spec + 1] = e end

    add({ type = "header", name = "Logging" })
    add({ type = "text", key = "status", fn = StatusText })
    add({ type = "button", name = "Start_Logging()", tooltip = "Registers combat events and starts collecting fight data.", func = function() Start_Logging(); UI.Refresh() end })
    add({ type = "button", name = "Stop_Logging()", tooltip = "Ends the current fight and unregisters every combat event.", func = function() Stop_Logging(); UI.Refresh() end })
    add({ type = "button", name = "Split fight", tooltip = "Ends the current fight and starts a new one.", func = function() LF.Logger.SplitFight(); UI.Refresh() end })
    add({ type = "checkbox", name = "Raw event log", tooltip = "Keep every combat event of a fight (needed for event search).", get = function() return S().rawEvents end, set = function(v) S().rawEvents = v end, default = true })
    add({ type = "slider", name = "Raw events per fight", min = 1000, max = 50000, step = 1000, get = function() return S().rawEventCap end, set = function(v) S().rawEventCap = v end, default = 20000 })
    add({ type = "checkbox", name = "Group mode", tooltip = "Also record group members' damage and healing. Takes effect on next Start_Logging().", get = function() return S().groupMode end, set = function(v) S().groupMode = v end, default = false })
    add({ type = "checkbox", name = "Track debuffs on targets", get = function() return S().trackTargetEffects end, set = function(v) S().trackTargetEffects = v end, default = true })
    add({ type = "checkbox", name = "Track casts / weaving", get = function() return S().trackCasts end, set = function(v) S().trackCasts = v end, default = true })
    add({ type = "checkbox", name = "Track resources", get = function() return S().trackPower end, set = function(v) S().trackPower = v end, default = true })
    add({ type = "slider", name = "Stat sample interval (ms)", min = 250, max = 5000, step = 250, get = function() return S().statSampleMs end, set = function(v) S().statSampleMs = v end, default = 1000 })
    add({ type = "slider", name = "Combat end grace (ms)", min = 0, max = 15000, step = 500, get = function() return S().combatEndGraceMs end, set = function(v) S().combatEndGraceMs = v end, default = 3000 })
    add({ type = "slider", name = "Minimum fight length (s)", min = 0, max = 30, step = 1, get = function() return S().minFightSeconds end, set = function(v) S().minFightSeconds = v end, default = 2 })
    add({ type = "checkbox", name = "Print summary when a fight ends", get = function() return S().printFightSummary end, set = function(v) S().printFightSummary = v end, default = false })
    add({ type = "checkbox", name = "Show live HUD", tooltip = "Fight rundown window: tiles, boss / time to kill, top abilities and a fight log. Does not start logging.", get = function() return S().showHUD end, set = function(v) LF.HUD.SetShown(v) end, default = false })
    add({ type = "checkbox", name = "Lock HUD", get = function() return S().hudLocked end, set = function(v) LF.HUD.SetLocked(v) end, default = false })
    add({ type = "slider", name = "HUD update interval (ms)", min = 100, max = 2000, step = 100, get = function() return S().hudUpdateMs or 500 end, set = function(v) S().hudUpdateMs = v end, default = 500 })
    add({ type = "button", name = "Reset HUD position", func = function() LF.HUD.ResetPosition() end })
    add({ type = "button", name = "Clear HUD fight log", func = function() LF.HUD.ClearLog() end })
    add({ type = "checkbox", name = "Debug messages", get = function() return S().debug end, set = function(v) S().debug = v end, default = false })

    add({ type = "header", name = "Fight data" })
    add({ type = "text", key = "live", fn = function() return outputs.live end })
    add({ type = "button", name = "Refresh", func = function() UI.SetOutput("live", LF.Report.FightSummaryLines(LastFight())) end })
    add({ type = "button", name = "Print everything", tooltip = "Prints all data of the last fight to chat.", func = function() PrintFight(LF.Report.AllFightLines) end })
    add({ type = "button", name = "Damage abilities", func = function() PrintFight(LF.Report.AbilityLines, "damageOut", 15) end })
    add({ type = "button", name = "Healing abilities", func = function() PrintFight(LF.Report.AbilityLines, "healOut", 15) end })
    add({ type = "button", name = "Damage taken", func = function() PrintFight(LF.Report.AbilityLines, "damageIn", 15) end })
    add({ type = "button", name = "Targets", func = function() PrintFight(LF.Report.TargetLines, 10) end })
    add({ type = "button", name = "Procs", func = function() PrintFight(LF.Report.ProcLines, 20) end })
    add({ type = "button", name = "Sets", func = function() PrintFight(LF.Report.SetLines) end })
    add({ type = "button", name = "Buff uptimes", func = function() PrintFight(LF.Report.EffectLines, "player", 20) end })
    add({ type = "button", name = "Debuff uptimes", func = function() PrintFight(LF.Report.EffectLines, "target", 20) end })
    add({ type = "button", name = "Stats", func = function() PrintFight(LF.Report.StatLines) end })
    add({ type = "button", name = "Resources & deaths", func = function()
        PrintFight(LF.Report.PowerLines); PrintFight(LF.Report.DeathLines)
    end })
    add({ type = "button", name = "Export line", tooltip = "Prints a compact one-line export of the last fight.", func = function()
        local f = LastFight(); LF.Print(f and LF.Report.Export(f) or "No fight.")
    end })

    add({ type = "header", name = "Build" })
    add({ type = "text", key = "build", fn = function() return outputs.build end })
    add({ type = "button", name = "Read build", func = function() UI.SetOutput("build", LF.Report.BuildLines(LF.Build.Read("basic")), true) end })

    add({ type = "header", name = "Models (predictions)" })
    add({ type = "text", key = "models", fn = function() return outputs.models end })
    add({ type = "button", name = "Show predictions", func = function() UI.SetOutput("models", LF.Report.ModelLines(), true) end })
    add({ type = "checkbox", name = "Enable models", get = function() return S().modelsEnabled end, set = function(v) S().modelsEnabled = v end, default = true })
    add({ type = "slider", name = "Reference target resistance", tooltip = "Resistance of the calibration target (trial dummies: 18200).", min = 0, max = 40000, step = 100, get = function() return S().referenceResistance end, set = function(v) S().referenceResistance = v end, default = 18200 })
    add({ type = "edit", name = "Reference target names", tooltip = "Comma separated name fragments of calibration targets.", get = function() return S().referenceTargetPatterns end, set = function(v) S().referenceTargetPatterns = v end })
    add({ type = "checkbox", name = "Keep model training between sessions", tooltip = "Stores trained models in SavedVariables (larger file).", get = function() return S().persistModels end, set = function(v) S().persistModels = v end, default = false })
    add({ type = "button", name = "Reset models", func = function() LF.Models.Reset(); UI.SetOutput("models", "Models reset.") end })

    add({ type = "header", name = "Search" })
    add({ type = "edit", name = "Search", tooltip = "Text, or filters like in:set, in:ability, in:event, id:12345, fight:3", get = function() return inputs.search end, set = function(v)
        inputs.search = v or ""
        local lines = {}
        for _, r in ipairs(LF.Search(inputs.search, { limit = 30 })) do lines[#lines + 1] = LF.SearchFormatResult(r) end
        if #lines == 0 then lines[1] = "No results." end
        UI.SetOutput("search", lines, true)
    end })
    add({ type = "text", key = "search", fn = function() return outputs.search end })

    add({ type = "header", name = "Abilities & IDs" })
    add({ type = "edit", name = "Ability id or name", get = function() return inputs.ability end, set = function(v)
        inputs.ability = v or ""
        local id = tonumber(inputs.ability)
        if id then
            UI.SetOutput("ability", LF.Report.AbilityInfoLines(id), true)
        else
            local lines = {}
            for _, info in ipairs(LF.Abilities.Search(inputs.ability, 25)) do
                lines[#lines + 1] = string.format("%s %s [%d]", Util.IconMarkup(info.icon, 20), info.name, info.id)
            end
            if #lines == 0 then lines[1] = "No match. Run the ID scan or index your skills first." end
            UI.SetOutput("ability", lines, true)
        end
    end })
    add({ type = "text", key = "ability", fn = function() return outputs.ability end })
    add({ type = "button", name = "Index my skills", func = function()
        local n = LF.Abilities.IndexPlayerSkills()
        UI.SetOutput("scan", string.format("Indexed %d skills (index size %d).", n, LF.Abilities.GetIndexCount()))
    end })
    add({ type = "button", name = "Scan all ability IDs", tooltip = "Indexes every ability id (takes a while, spread over frames).", func = function()
        local ok = LF.Abilities.StartScan({
            onProgress = function(p) UI.SetOutput("scan", string.format("Scanning... %.0f%% (%d found)", p.pct * 100, p.found)) end,
            onDone = function(p) UI.SetOutput("scan", string.format("Scan done: %d abilities indexed in %.1fs.", p.indexed, p.elapsedMs / 1000)) end,
        })
        if not ok then UI.SetOutput("scan", "Scan already running.") end
    end })
    add({ type = "button", name = "Stop scan", func = function() LF.Abilities.StopScan() end })
    add({ type = "text", key = "scan", fn = function() return outputs.scan end })

    add({ type = "header", name = "Sets" })
    add({ type = "checkbox", name = "Log every set", tooltip = "When off, only sets added below are tracked in fights.", get = function() return S().logAllSets end, set = function(v) LF.Sets.SetLogAllSets(v) end, default = true })
    add({ type = "edit", name = "Set id or name", get = function() return inputs.set end, set = function(v)
        inputs.set = v or ""
        local id = tonumber(inputs.set)
        if id then
            UI.SetOutput("set", LF.Report.SetInfoLines(id), true)
        else
            local lines = {}
            for _, info in ipairs(LF.Sets.Search(inputs.set, 20)) do
                lines[#lines + 1] = string.format("%s [%d] %s", info.name, info.setId, tostring(info.setTypeName or ""))
            end
            if #lines == 0 then lines[1] = "No set found." end
            UI.SetOutput("set", lines, true)
        end
    end })
    add({ type = "text", key = "set", fn = function() return outputs.set end })
    add({ type = "edit", name = "Toggle logging for set id", tooltip = "Enter a set id to add/remove it from the logged sets list.", get = function() return inputs.setLog end, set = function(v)
        inputs.setLog = v or ""
        local id = tonumber(inputs.setLog)
        if id then
            LF.Sets.SetSetLogged(id, not (S().loggedSets and S().loggedSets[id]))
            UI.SetOutput("set", string.format("Set %d (%s) in logged list: %s%s", id, LF.Sets.GetSetName(id),
                tostring(S().loggedSets[id] == true), S().logAllSets and " (note: 'Log every set' is on, so all sets are logged)" or ""), true)
        end
    end })
    add({ type = "button", name = "Equipped sets", func = function()
        local lines = {}
        for _, s in pairs(LF.Sets.GetEquippedSets()) do
            lines[#lines + 1] = string.format("%s [%d] %d/%d%s", s.name, s.setId, s.equipped, s.maxEquipped, s.fullBonus and " (full)" or "")
            for _, b in ipairs(s.activeBonuses) do lines[#lines + 1] = "   + " .. b.description end
        end
        if #lines == 0 then lines[1] = "No sets equipped." end
        UI.SetOutput("set", lines, true)
    end })
    add({ type = "button", name = "Count all sets", func = function()
        UI.SetOutput("set", string.format("%d sets known to the game.", #LF.Sets.GetAllSetIds(true)), true)
    end })

    add({ type = "header", name = "Saved data" })
    add({ type = "checkbox", name = "Save fights to SavedVariables", get = function() return S().saveFights end, set = function(v) S().saveFights = v end, default = false })
    add({ type = "slider", name = "Max saved fights", min = 1, max = LF.isConsole and 5 or 50, step = 1, get = function() return S().maxSavedFights end, set = function(v) S().maxSavedFights = v end, default = LF.isConsole and 3 or 10 })
    add({ type = "checkbox", name = "Include raw events when saving", tooltip = "Makes SavedVariables much larger. Not recommended on console.", get = function() return S().saveRawEvents end, set = function(v) S().saveRawEvents = v end, default = false })
    add({ type = "button", name = "Clear fights in memory", func = function() LF.Logger.ClearFights(); UI.Refresh() end })
    add({ type = "button", name = "Clear saved fights", func = function() LF.Storage.ClearSavedFights(); UI.Refresh() end })
    return spec
end

-- ---------------------------------------------------------------------------
-- LibAddonMenu-2.0 renderer
-- ---------------------------------------------------------------------------
local function BuildLAM(spec)
    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel", name = "LibFights", displayName = "|c66CCFFLibFights|r test panel",
        author = "LibFights", version = LF.version, registerForRefresh = true, registerForDefaults = true,
    }
    local panel = LAM:RegisterAddonPanel("LibFightsPanel", panelData)
    local options = {}
    for i, e in ipairs(spec) do
        if e.type == "header" then
            options[#options + 1] = { type = "header", name = e.name }
        elseif e.type == "text" then
            local ref = "LibFightsLAMText_" .. e.key .. "_" .. i
            options[#options + 1] = { type = "description", text = tostring(e.fn() or ""), reference = ref }
            refreshers[#refreshers + 1] = function()
                local c = _G[ref]
                if c and c.desc then c.desc:SetText(tostring(e.fn() or "")) end
            end
        elseif e.type == "button" then
            options[#options + 1] = { type = "button", name = e.name, tooltip = e.tooltip, func = e.func, width = "half" }
        elseif e.type == "checkbox" then
            options[#options + 1] = { type = "checkbox", name = e.name, tooltip = e.tooltip, getFunc = e.get, setFunc = e.set, default = e.default }
        elseif e.type == "slider" then
            options[#options + 1] = { type = "slider", name = e.name, tooltip = e.tooltip, min = e.min, max = e.max, step = e.step, getFunc = e.get, setFunc = e.set, default = e.default }
        elseif e.type == "edit" then
            options[#options + 1] = { type = "editbox", name = e.name, tooltip = e.tooltip, getFunc = e.get, setFunc = e.set, isMultiline = false, width = "full" }
        end
    end
    LAM:RegisterOptionControls("LibFightsPanel", options)
    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(p) if p == panel then UI.Refresh() end end)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(p) if p == panel then UI.Refresh() end end)
    end
    UI.panel = panel
    UI.usedLibrary = "LibAddonMenu-2.0"
end

-- ---------------------------------------------------------------------------
-- LibHarvensAddonSettings renderer (gamepad / console friendly)
-- ---------------------------------------------------------------------------
local function BuildLHAS(spec)
    local LHAS = LibHarvensAddonSettings
    local addon = LHAS:AddAddon("LibFights", { allowDefaults = true, allowRefresh = true })
    if not addon then return end
    local list = {}
    for _, e in ipairs(spec) do
        if e.type == "header" then
            list[#list + 1] = { type = LHAS.ST_SECTION, label = e.name }
        elseif e.type == "text" then
            list[#list + 1] = { type = LHAS.ST_LABEL, label = function() return tostring(e.fn() or "") end }
        elseif e.type == "button" then
            list[#list + 1] = { type = LHAS.ST_BUTTON, label = e.name, tooltip = e.tooltip, buttonText = e.name, clickHandler = function() e.func() end }
        elseif e.type == "checkbox" then
            list[#list + 1] = { type = LHAS.ST_CHECKBOX, label = e.name, tooltip = e.tooltip, default = e.default,
                getFunction = e.get, setFunction = function(v) e.set(v) end }
        elseif e.type == "slider" then
            list[#list + 1] = { type = LHAS.ST_SLIDER, label = e.name, tooltip = e.tooltip, min = e.min, max = e.max, step = e.step,
                default = e.default, format = "%d", getFunction = e.get, setFunction = function(v) e.set(v) end }
        elseif e.type == "edit" then
            list[#list + 1] = { type = LHAS.ST_EDIT, label = e.name, tooltip = e.tooltip, textType = TEXT_TYPE_ALL, maxChars = 200,
                getFunction = e.get, setFunction = function(v) e.set(v) end }
        end
    end
    if addon.AddSettings then
        addon:AddSettings(list)
    else
        for _, s in ipairs(list) do addon:AddSetting(s) end
    end
    refreshers[#refreshers + 1] = function()
        if addon.UpdateControls then addon:UpdateControls() end
    end
    UI.lhasAddon = addon
    UI.usedLibrary = "LibHarvensAddonSettings"
end

function UI.Init()
    local spec = BuildSpec()
    local hasLAM = LibAddonMenu2 ~= nil and type(LibAddonMenu2.RegisterAddonPanel) == "function"
    local hasLHAS = LibHarvensAddonSettings ~= nil and type(LibHarvensAddonSettings.AddAddon) == "function"
    local ok, err
    if LF.isConsole and hasLHAS then
        ok, err = pcall(BuildLHAS, spec)
    elseif hasLAM then
        ok, err = pcall(BuildLAM, spec)
    elseif hasLHAS then
        ok, err = pcall(BuildLHAS, spec)
    else
        UI.usedLibrary = "none (install LibAddonMenu-2.0 or LibHarvensAddonSettings)"
        return
    end
    if not ok then
        UI.usedLibrary = "error"
        LF.Print("Settings panel failed: %s", tostring(err))
    end
    LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(f)
        outputs.live = Lines(LF.Report.FightSummaryLines(f))
        UI.Refresh()
    end)
    LF.RegisterCallback(LF.EVENTS.LOGGING_STARTED, UI.Refresh)
    LF.RegisterCallback(LF.EVENTS.LOGGING_STOPPED, UI.Refresh)
end

LF.SearchFormatResult = function(r) return LF.Search_.FormatResult(r) end
