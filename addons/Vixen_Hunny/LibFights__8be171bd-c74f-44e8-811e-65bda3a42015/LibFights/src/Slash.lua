--[[
    LibFights - Slash commands (PC/Mac; harmless on console where chat commands may be limited)
      /libfights start | stop | split | status | last | all | abilities | heals | taken
                 targets | procs | sets | buffs | debuffs | stats | power | build | models
                 search <query> | ability <id|name> | set <id|name> | scan | hud | export
]]

local LF = LibFights
local Slash = {}
LF.Slash = Slash

local function last() return LF.Logger.GetLastFight() end

local function printFight(fn, ...)
    local f = last()
    if not f then LF.Print("No fight data yet.") return end
    LF.PrintLines(fn(f, ...))
end

local commands = {
    start = function() Start_Logging() end,
    stop = function() Stop_Logging() end,
    split = function() LF.Logger.SplitFight() end,
    status = function() LF.Print("Logging %s, %d fights in memory, %d saved.", LF.Logger.IsLogging() and "ON" or "OFF", #LF.Logger.GetFights(), LF.Storage.GetSavedFightCount()) end,
    last = function() printFight(LF.Report.FightSummaryLines) end,
    all = function() printFight(LF.Report.AllFightLines) end,
    abilities = function() printFight(LF.Report.AbilityLines, "damageOut", 15) end,
    heals = function() printFight(LF.Report.AbilityLines, "healOut", 15) end,
    taken = function() printFight(LF.Report.AbilityLines, "damageIn", 15) end,
    targets = function() printFight(LF.Report.TargetLines, 10) end,
    procs = function() printFight(LF.Report.ProcLines, 20) end,
    sets = function() printFight(LF.Report.SetLines) end,
    buffs = function() printFight(LF.Report.EffectLines, "player", 20) end,
    debuffs = function() printFight(LF.Report.EffectLines, "target", 20) end,
    stats = function() LF.PrintLines(LF.Report.StatLines(last())) end,
    power = function() printFight(LF.Report.PowerLines) end,
    build = function() LF.PrintLines(LF.Report.BuildLines()) end,
    models = function() LF.PrintLines(LF.Report.ModelLines()) end,
    export = function() local f = last(); LF.Print(f and LF.Report.Export(f) or "No fight.") end,
    hud = function() LF.HUD.SetShown(not LF.GetSettings().showHUD) end,
    scan = function()
        LF.Abilities.StartScan({
            onProgress = function(p) LF.Print("Ability scan %.0f%%", p.pct * 100) end,
            onDone = function(p) LF.Print("Ability scan done: %d indexed.", p.indexed) end,
        })
    end,
    search = function(arg)
        local results = LF.Search(arg, { limit = 25 })
        if #results == 0 then LF.Print("No results for '%s'.", arg) return end
        for _, r in ipairs(results) do d(LF.SearchFormatResult(r)) end
    end,
    ability = function(arg)
        local id = tonumber(arg)
        if id then LF.PrintLines(LF.Report.AbilityInfoLines(id)) return end
        for _, info in ipairs(LF.Abilities.Search(arg, 20)) do
            d(string.format("%s %s [%d]", LF.Util.IconMarkup(info.icon, 18), info.name, info.id))
        end
    end,
    set = function(arg)
        local id = tonumber(arg)
        if id then LF.PrintLines(LF.Report.SetInfoLines(id)) return end
        for _, info in ipairs(LF.Sets.Search(arg, 20)) do
            d(string.format("%s [%d]", info.name, info.setId))
        end
    end,
}

local function Handler(text)
    text = LF.Util.Trim(text or "")
    local cmd, arg = text:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    local fn = commands[cmd]
    if fn then
        fn(arg or "")
    else
        LF.Print("Commands: start, stop, split, status, last, all, abilities, heals, taken, targets, procs, sets, buffs, debuffs, stats, power, build, models, export, hud, scan, search <q>, ability <id|name>, set <id|name>")
    end
end

function Slash.Init()
    if type(SLASH_COMMANDS) ~= "table" then return end
    SLASH_COMMANDS["/libfights"] = Handler
    if SLASH_COMMANDS["/lfights"] == nil then SLASH_COMMANDS["/lfights"] = Handler end
end
