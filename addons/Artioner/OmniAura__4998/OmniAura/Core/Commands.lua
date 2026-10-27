-- Comandos de chat /omni (y /omniaura).
-- Las palabras clave de los comandos (buff, res, magicka...) son iguales en todos los idiomas.

local OA = OmniAura
local U = OA.Utils
local L = OA.L
local C = {}
OA.Commands = C

local Print = OA.Print

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Refresh()
    OA.Engine.Rebuild()
end

local function RefreshEditor()
    if OA.Editor then OA.Editor.RefreshIfShown() end
end

-- Los comandos se refieren a las auras por su posición en /omni list (1, 2, 3...),
-- no por su id interno, para que no haya huecos al borrar.
local function GetAura(posStr)
    local pos = tonumber(posStr)
    local id = pos and OA.Engine.SortedIds()[pos]
    local aura = id and OA.sv.auras[id]
    if not aura then Print(L.NO_AURA, tostring(posStr)) end
    return aura
end

local function SpellLabel(spells)
    local first = spells[1]
    if type(first) == "number" then return U.AbilityName(first) end
    return tostring(first or "?")
end

local function NewAura(name, triggers, display)
    local aura = OA.Engine.CreateAura(name, triggers, display)
    RefreshEditor()
    Print(L.AURA_CREATED, name)
end

---------------------------------------------------------------------------
-- /omni new <tipo> ...
---------------------------------------------------------------------------
local creators = {}

local function BuffCreator(unit, onlyMine, show)
    return function(rest)
        local spells = U.CommaList(rest)
        if #spells == 0 then
            Print(L.NEED_SPELL)
            return
        end
        local name = SpellLabel(spells)
        if show == "missing" then name = name .. L.MISSING_SUFFIX end
        NewAura(name,
            { { type = "buff", unit = unit, spells = spells, onlyMine = onlyMine, show = show } },
            { type = "icon", size = 48 })
    end
end

creators.buff = BuffCreator("player", false, "active")
creators.debuff = BuffCreator("reticleover", true, "active")
creators.missing = BuffCreator("player", false, "missing")

creators.res = function(rest)
    local power, op, value, pct = rest:match("^(%a+)%s*([<>=~]+)%s*(%d+%.?%d*)%s*(%%?)$")
    if not power or not OA.Triggers.POWER[power] or not OA.Triggers.COMPARE[op] then
        Print(L.USAGE_RES)
        return
    end
    local isPct = pct == "%"
    NewAura(string.format("%s %s %s%s", OA.Triggers.POWER_LABEL[power], op, value, pct),
        { { type = "resource", unit = "player", power = power, op = op, value = tonumber(value), percent = isPct } },
        { type = "bar", width = 200, height = 20, showIcon = false,
          text = "{name}", text2 = isPct and "{percent}%" or "{value}" })
end

creators.proc = function(rest)
    local idList, duration = rest:match("^(%S+)%s+(%d+%.?%d*)$")
    local spells = {}
    for _, v in ipairs(U.CommaList(idList)) do
        if type(v) == "number" then spells[#spells + 1] = v end
    end
    if #spells == 0 then
        Print(L.USAGE_PROC)
        return
    end
    NewAura(SpellLabel(spells),
        { { type = "proc", spells = spells, duration = tonumber(duration), source = "player" } },
        { type = "icon", size = 48 })
end

creators.combat = function(rest)
    local state = (U.Trim(rest) == "out") and "out" or "in"
    NewAura(state == "out" and L.OUT_OF_COMBAT or L.IN_COMBAT,
        { { type = "combat", state = state } },
        { type = "text", size = 26, text = "{name}", textColor = { 1, 0.3, 0.3, 1 } })
end

---------------------------------------------------------------------------
-- Registro de IDs (/omni log)
---------------------------------------------------------------------------
local LOG_NS = "OmniAura_Log"
local LOG_THROTTLE = 10
local logEnabled = false
local logLast = {}

local function OnLogEvent(_, result, isError, abilityName, abilityGraphic, actionSlotType,
                          sourceName, sourceType, targetName, targetType, hitValue, powerType,
                          damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError or not abilityId or abilityId == 0 then return end
    local now = GetFrameTimeSeconds()
    if logLast[abilityId] and now - logLast[abilityId] < LOG_THROTTLE then return end
    logLast[abilityId] = now
    Print("|c88FF88%d|r %s |c888888(result %d)|r", abilityId, U.FormatName(abilityName), result)
end

local function SetLogging(on)
    logEnabled = on
    if on then
        logLast = {}
        EVENT_MANAGER:RegisterForEvent(LOG_NS, EVENT_COMBAT_EVENT, OnLogEvent)
        EVENT_MANAGER:AddFilterForEvent(LOG_NS, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    else
        EVENT_MANAGER:UnregisterForEvent(LOG_NS, EVENT_COMBAT_EVENT)
    end
end

---------------------------------------------------------------------------
-- Manejadores
---------------------------------------------------------------------------
local handlers = {}

function handlers.help()
    Print(L.HELP_HEADER, OA.version)
    if type(L.HELP) == "table" then
        for _, line in ipairs(L.HELP) do OA.Chat(line) end
    end
end

function handlers.list()
    local ids = OA.Engine.SortedIds()
    if #ids == 0 then
        Print(L.NO_AURAS)
        return
    end
    for pos, id in ipairs(ids) do
        local aura = OA.sv.auras[id]
        local types = {}
        for i, trig in ipairs(aura.triggers or {}) do types[i] = tostring(trig.type) end
        OA.Chat(string.format("  |cFFFF00%d.|r %s %s |c888888[%s → %s]|r",
            pos,
            aura.enabled ~= false and "|c00FF00on|r " or "|cFF4444off|r",
            aura.name or "?",
            table.concat(types, "+"),
            tostring(aura.display and aura.display.type or "icon")))
    end
end

function handlers.new(rest)
    local kind, args = rest:match("^(%S*)%s*(.-)$")
    local fn = creators[zo_strlower(kind or "")]
    if not fn then
        Print(L.NEW_TYPES)
        return
    end
    fn(args)
end

function handlers.show(rest)
    local aura = GetAura(rest)
    if not aura then return end
    Print(L.AURA_HEADER, aura.name or "?")
    for _, line in ipairs(U.Flatten(aura)) do
        if not line:find("^id =") and not line:find("^autoName =") then OA.Chat("  " .. line) end
    end
end

function handlers.set(rest)
    local idStr, path, value = rest:match("^(%S+)%s+(%S+)%s*(.-)$")
    if not idStr then
        Print(L.USAGE_SET)
        return
    end
    local aura = GetAura(idStr)
    if not aura then return end

    -- Atajos: t1.x -> triggers.1.x, trigger.x -> triggers.x, d.x -> display.x
    path = path:gsub("^t(%d)", "triggers.%1"):gsub("^trigger%.", "triggers."):gsub("^d%.", "display.")
    if path == "id" then
        Print(L.ID_READONLY)
        return
    end

    local parsed = U.ParseValue(value)
    if not U.SetPath(aura, path, parsed) then
        Print(L.INVALID_PATH, path)
        return
    end
    Refresh()
    RefreshEditor()
    Print("%s: %s = %s", aura.name or "?", path, U.ValueToString(parsed))
end

local function SetEnabled(rest, enabled)
    local aura = GetAura(rest)
    if not aura then return end
    aura.enabled = enabled
    Refresh()
    RefreshEditor()
    Print(enabled and L.AURA_ENABLED or L.AURA_DISABLED, aura.name or "?")
end

function handlers.on(rest) SetEnabled(rest, true) end
function handlers.off(rest) SetEnabled(rest, false) end

function handlers.del(rest)
    local aura = GetAura(rest)
    if not aura then return end
    OA.Engine.DeleteAura(aura.id)
    RefreshEditor()
    Print(L.AURA_DELETED, aura.name or "?")
end

function handlers.copy(rest)
    local aura = GetAura(rest)
    if not aura then return end
    local copy = OA.Engine.DuplicateAura(aura.id)
    RefreshEditor()
    Print(L.AURA_COPIED, copy.name or "?")
end

local function EditorAvailable()
    if OA.Editor then return true end
    Print(L.EDITOR_NOT_LOADED)
    return false
end

-- "Ubicar auras": coloca todas las auras sobre la interfaz de juego (ver Editor).
function handlers.unlock()
    if not EditorAvailable() then return end
    OA.Editor.StartMoveMode()
end

function handlers.lock()
    if not EditorAvailable() then return end
    OA.Editor.EndMoveMode(false)
end

function handlers.editor()
    if not EditorAvailable() then return end
    OA.Editor.Toggle()
end

function handlers.scan(rest)
    rest = U.Trim(rest)
    local unit = (rest == "" and "player") or (rest == "target" and "reticleover") or rest
    if not DoesUnitExist(unit) then
        Print(L.UNIT_NOT_FOUND, unit)
        return
    end
    local now = GetFrameTimeSeconds()
    local list = OA.Triggers.NewContext(now):GetBuffs(unit)
    Print(L.SCAN_HEADER, #list, unit)
    for _, b in ipairs(list) do
        local remaining = b.ending - now
        OA.Chat(string.format("  |c88FF88%d|r %s %s%s%s",
            b.abilityId or 0, b.name,
            remaining > 0 and string.format("|c888888%.0fs|r ", remaining) or "",
            b.stacks > 1 and string.format("x%d ", b.stacks) or "",
            b.mine and ("|c00C8FF" .. L.SCAN_MINE .. "|r") or ""))
    end
end

function handlers.log()
    SetLogging(not logEnabled)
    Print(logEnabled and L.LOG_ON or L.LOG_OFF)
end

function handlers.reset(rest)
    if U.Trim(rest) ~= "confirm" then
        Print(L.RESET_CONFIRM)
        return
    end
    OA.sv.auras = {}
    OA.sv.nextId = 1
    OA.previewId = nil
    Refresh()
    RefreshEditor()
    Print(L.RESET_DONE)
end

handlers[""] = handlers.editor

function C.Handle(args)
    local cmd, rest = U.Trim(args):match("^(%S*)%s*(.-)$")
    local handler = handlers[zo_strlower(cmd or "")] or handlers.help
    handler(rest or "")
end

function C.Init()
    SLASH_COMMANDS["/omni"] = C.Handle
    SLASH_COMMANDS["/omniaura"] = C.Handle
end
