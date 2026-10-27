-- Comandos de chat /nm (y /nirnmetrics) y funciones de las teclas (Bindings.xml).
-- Las palabras clave de los comandos son iguales en todos los idiomas.

local NM = NirnhonedMetrics
local U = NM.Utils
local L = NM.L
local C = {}
NM.Commands = C

local Print = NM.Print
local Meter = NM.Meter

ZO_CreateStringId("SI_BINDING_NAME_NIRNHONEDMETRICS_TOGGLE", L.BINDING_TOGGLE)
ZO_CreateStringId("SI_BINDING_NAME_NIRNHONEDMETRICS_METRIC", L.BINDING_METRIC)
ZO_CreateStringId("SI_BINDING_NAME_NIRNHONEDMETRICS_MODE", L.BINDING_MODE)
ZO_CreateStringId("SI_BINDING_NAME_NIRNHONEDMETRICS_RESET", L.BINDING_RESET)

local handlers = {}

function handlers.help()
    Print(L.HELP_HEADER, NM.version)
    if type(L.HELP) == "table" then
        for _, line in ipairs(L.HELP) do NM.Chat(line) end
    end
end

function handlers.toggle()
    Meter.Toggle()
end

function handlers.show()
    Meter.SetShown(true)
end

function handlers.hide()
    Meter.SetShown(false)
end

function handlers.lock()
    Meter.SetLocked(true)
    Print(L.LOCKED)
end

function handlers.unlock()
    Meter.SetLocked(false)
    Print(L.UNLOCKED)
end

function handlers.reset()
    NM.Fight.Reset()
    Print(L.RESET_DONE)
end

function handlers.mode(rest)
    rest = zo_strlower(U.Trim(rest))
    local mode
    if rest == "group" or rest == "g" then
        mode = "group"
    elseif rest == "abilities" or rest == "a" then
        mode = "abilities"
    else
        mode = NM.sv.mode == "group" and "abilities" or "group"
    end
    Meter.SetMode(mode)
    Print(L.MODE_SET, mode == "group" and L.MODE_GROUP or L.MODE_ABILITIES)
end

function handlers.damage()
    Meter.SetMetric("damage")
    Print(L.METRIC_SET, L.METRIC_DAMAGE)
end

function handlers.healing()
    Meter.SetMetric("healing")
    Print(L.METRIC_SET, L.METRIC_HEALING)
end
handlers.heal = handlers.healing

function handlers.settings()
    NM.Settings.Open()
end
handlers.config = handlers.settings

function handlers.resetpos()
    Meter.SetShown(true)
    Meter.ResetPosition()
    Print(L.POSITION_RESET)
end

handlers[""] = handlers.toggle

function C.Handle(args)
    local cmd, rest = U.Trim(args):match("^(%S*)%s*(.-)$")
    local handler = handlers[zo_strlower(cmd or "")] or handlers.help
    handler(rest or "")
end

function C.Init()
    SLASH_COMMANDS["/nm"] = C.Handle
    SLASH_COMMANDS["/nirnmetrics"] = C.Handle
end

-- Teclas (Controles → Nirnhoned Metrics)
function NirnhonedMetrics_Toggle() Meter.Toggle() end
function NirnhonedMetrics_SwitchMetric()
    if NM.sv.metric == "healing" then handlers.damage() else handlers.healing() end
end
function NirnhonedMetrics_SwitchMode() handlers.mode("") end
function NirnhonedMetrics_Reset() NM.Fight.Reset() end
