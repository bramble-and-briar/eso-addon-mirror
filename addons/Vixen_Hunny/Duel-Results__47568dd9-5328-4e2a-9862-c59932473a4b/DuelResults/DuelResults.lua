--[[
    Duel Results - core
    Namespace, saved variables, shared helpers, chat output and slash commands.
]]

DuelResults = DuelResults or {}
local DR = DuelResults

DR.name        = "DuelResults"
DR.displayName = "Duel Results"
DR.author      = "Vixen Hunny"
DR.version     = "3.0.0"

DR.COLORS = {
    p1    = ZO_ColorDef:New("3FA9F5"),
    p2    = ZO_ColorDef:New("F5563F"),
    gold  = ZO_ColorDef:New("C5A15A"),
    live  = ZO_ColorDef:New("4FC36A"),
    dim   = ZO_ColorDef:New("8A8A8A"),
    white = ZO_ColorDef:New("FFFFFF"),
    buff  = ZO_ColorDef:New("4FC36A"),
    debuff = ZO_ColorDef:New("A35BD9"),
    heal  = ZO_ColorDef:New("4FC36A"),
}

DR.defaults = {
    autoShowOnStart = true,
    autoShowOnEnd   = true,
    printOnEnd      = false,
    trackGroupDuels = true,
    hidePermanent   = true,
    locked          = false,
    scale           = 1,
    maxHistory      = 20,
    window          = nil, -- { left = x, top = y }
    history         = {},
}

ZO_CreateStringId("SI_BINDING_NAME_DUELRESULTS_TOGGLE", "Toggle Duel Results window")

local PREFIX = DR.COLORS.gold:Colorize("[Duel Results]")

------------------------------------------------------------------------------------------
-- Formatting helpers
------------------------------------------------------------------------------------------
function DR.FormatNumber(n)
    n = n or 0
    if n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e4 then
        return string.format("%.1fk", n / 1e3)
    elseif n >= 1e3 then
        return string.format("%.2fk", n / 1e3)
    end
    return string.format("%d", zo_round(n))
end

function DR.FormatInt(n)
    return string.format("%d", zo_round(n or 0))
end

function DR.FormatPercent(n)
    return string.format("%.1f%%", n or 0)
end

function DR.FormatDuration(ms)
    local s = math.floor((ms or 0) / 1000)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function DR.PlayerLabel(p)
    if not p then return "?" end
    if p.displayName and p.displayName ~= "" then return p.displayName end
    if p.charName and p.charName ~= "" then return p.charName end
    return "Unknown"
end

------------------------------------------------------------------------------------------
-- Fight helpers (work for both live fights and history snapshots)
------------------------------------------------------------------------------------------
function DR.GetFightDuration(f)
    return math.max(1, (f.endMs or GetGameTimeMilliseconds()) - f.startMs)
end

function DR.GetEffectUptime(e, now)
    return e.upMs + (e.since and (now - e.since) or 0)
end

function DR.GetSortedEffects(f, p)
    local now = f.endMs or GetGameTimeMilliseconds()
    local dur = DR.GetFightDuration(f)
    local list = {}
    for _, e in pairs(p.effects) do
        local up = DR.GetEffectUptime(e, now)
        list[#list + 1] = {
            name = e.name, icon = e.icon, debuff = e.debuff == true,
            upMs = up, pct = zo_clamp(up / dur * 100, 0, 100),
        }
    end
    table.sort(list, function(a, b)
        if a.debuff ~= b.debuff then return not a.debuff end
        if a.pct ~= b.pct then return a.pct > b.pct end
        return a.name < b.name
    end)
    return list
end

function DR.GetSortedAbilities(p)
    local list = {}
    for id, a in pairs(p.abilities) do
        list[#list + 1] = {
            id = id, name = a.name, icon = a.icon, damage = a.damage, healing = a.healing,
            hits = a.hits, crits = a.crits, total = a.damage + a.healing,
        }
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

------------------------------------------------------------------------------------------
-- Chat output
------------------------------------------------------------------------------------------
function DR.PrintSummary(f)
    if not f then
        d(PREFIX .. " No duel data yet.")
        return
    end
    local C = DR.COLORS
    local durMs = DR.GetFightDuration(f)
    local sec = durMs / 1000
    local p1, p2 = f.players[1], f.players[2]

    local line = string.format("%s %s vs %s  |c9A9A9A(%s)|r", PREFIX,
        C.p1:Colorize(DR.PlayerLabel(p1)), C.p2:Colorize(DR.PlayerLabel(p2)), DR.FormatDuration(durMs))
    if not f.endMs then
        line = line .. "  " .. C.live:Colorize("LIVE")
    elseif f.winner then
        line = line .. "  Winner: " .. C.gold:Colorize(DR.PlayerLabel(f.players[f.winner])) .. " (" .. (f.reason or "") .. ")"
    end
    d(line)

    for i, p in ipairs(f.players) do
        local critRate = p.hits > 0 and (p.crits / p.hits * 100) or 0
        d(string.format("  %s  DPS |cFFFFFF%s|r · Dmg |cFFFFFF%s|r · HPS |cFFFFFF%s|r · Crit |cFFFFFF%.0f%%|r · Blocked |cFFFFFF%d|r · Dodged |cFFFFFF%d|r",
            C["p" .. i]:Colorize(DR.PlayerLabel(p)),
            DR.FormatNumber(p.damage / sec), DR.FormatNumber(p.damage),
            DR.FormatNumber(p.healing / sec), critRate, p.blocked, p.dodged))

        local effects = DR.GetSortedEffects(f, p)
        local parts = {}
        for _, e in ipairs(effects) do
            if not e.debuff then
                parts[#parts + 1] = string.format("%s %.0f%%", e.name, e.pct)
                if #parts >= 6 then break end
            end
        end
        if #parts > 0 then
            d("    |c9A9A9ABuffs:|r " .. table.concat(parts, ", "))
        end
    end
end

------------------------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------------------------
local function HandleSlash(arg)
    arg = zo_strlower(zo_strtrim(arg or ""))
    if arg == "print" then
        DR.PrintSummary(DR.UI.GetFight() or DR.sv.history[1])
    elseif arg == "reset" then
        DR.Tracker:Reset()
    elseif arg == "help" then
        d(PREFIX .. " /duelresults — toggle window · /duelresults print — print to chat · /duelresults reset — reset current duel")
    else
        DR.UI.Toggle()
    end
end

------------------------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= DR.name then return end
    EVENT_MANAGER:UnregisterForEvent(DR.name, EVENT_ADD_ON_LOADED)

    DR.sv = ZO_SavedVars:NewAccountWide("DuelResultsSV", 1, nil, DR.defaults)

    DR.Tracker.Init()
    DR.UI.Init()
    DR.Settings.Init()

    SLASH_COMMANDS["/duelresults"] = HandleSlash
    SLASH_COMMANDS["/dres"] = HandleSlash
end

EVENT_MANAGER:RegisterForEvent(DR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
