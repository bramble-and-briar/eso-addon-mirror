-- OmniAura: punto de entrada, espacio de nombres y SavedVariables.

OmniAura = OmniAura or {}
local OA = OmniAura

OA.name = "OmniAura"
OA.version = "1.0.0"
OA.svVersion = 1
OA.author = "@Artioner"
OA.authorServer = "EU Megaserver"   -- el correo (donaciones) solo llega dentro del mismo megaservidor
OA.unlocked = false
-- Textos: se rellenan en lang/en.lua y lang/<idioma del cliente>.lua.
-- Si falta una clave se muestra su nombre en vez de fallar.
OA.L = setmetatable({}, { __index = function(_, key) return key end })

local WELCOME_DELAY_MS = 3000

OA.defaults = {
    auras = {},   -- [id] = aura
    nextId = 1,
}

-- Se usa el canal de sistema (no d(), que es de depuración): addons de chat como pChat
-- solo muestran los mensajes de sistema.
function OA.Chat(msg)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(msg)
    else
        d(msg)
    end
end

function OA.Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    OA.Chat("|c00C8FF[OmniAura]|r " .. msg)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= OA.name then return end
    EVENT_MANAGER:UnregisterForEvent(OA.name, EVENT_ADD_ON_LOADED)

    OA.sv = ZO_SavedVars:NewAccountWide("OmniAura_SV", OA.svVersion, nil, OA.defaults)

    OA.Display.Init()
    OA.Engine.Init()
    OA.Commands.Init()
    if OA.Recent then OA.Recent.Init() end
    -- El juego solo relee el manifiesto (.txt) al arrancar: si se añadieron archivos
    -- nuevos y solo se hizo /reloadui, estos módulos no existen todavía.
    if OA.Editor then OA.Editor.Init() end
    if OA.Settings then OA.Settings.Init() end

    -- Ventana de bienvenida/novedades (solo al instalar o actualizar). Se retrasa unos
    -- segundos para que no coincida con la carga de la interfaz al entrar al mundo.
    EVENT_MANAGER:RegisterForEvent(OA.name .. "_Welcome", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(OA.name .. "_Welcome", EVENT_PLAYER_ACTIVATED)
        zo_callLater(function()
            if OA.Settings then OA.Settings.ShowWelcomeIfNeeded() end
        end, WELCOME_DELAY_MS)
    end)
end

EVENT_MANAGER:RegisterForEvent(OA.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
