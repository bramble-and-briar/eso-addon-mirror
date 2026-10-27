-- Nirnhoned Metrics: punto de entrada, espacio de nombres y SavedVariables.

NirnhonedMetrics = NirnhonedMetrics or {}
local NM = NirnhonedMetrics

NM.name = "NirnhonedMetrics"
NM.COLOR = "D42F2F"            -- rojo Nirnhoned (como el rasgo del juego)
NM.title = "|c" .. NM.COLOR .. "Nirnhoned|r Metrics"
NM.version = "1.0.0"
NM.svVersion = 3
NM.author = "@Artioner"
NM.authorServer = "EU Megaserver"   -- el correo (donaciones) solo llega dentro del mismo megaservidor
-- Textos: se rellenan en lang/en.lua y lang/<idioma del cliente>.lua.
-- Si falta una clave se muestra su nombre en vez de fallar.
NM.L = setmetatable({}, { __index = function(_, key) return key end })

local WELCOME_DELAY_MS = 3000

-- Colores por clase (classId del juego). Se pueden cambiar en Ajustes.
NM.CLASS_IDS = { 1, 2, 3, 4, 5, 6, 117 }

NM.defaults = {
    window = {
        shown = true,
        locked = false,
        x = nil, y = nil,         -- esquina superior izquierda; nil = posición inicial
        width = 390,
        height = 250,
    },
    metric = "damage",            -- "damage" | "healing"
    mode = "group",               -- "group" (miembros del grupo) | "abilities" (tus habilidades)
    rowHeight = 24,               -- mínimo; crece si el texto no cabe
    rowSpacing = 1,
    fontSize = 16,
    titleFontSize = 18,
    bgAlpha = 0.55,
    barAlpha = 0.9,
    hideOutOfCombat = false,
    hideInPvP = false,            -- ocultar en Cyrodiil, Ciudad Imperial y campos de batalla

    barStyle = "progress",        -- "progress" (borde, brillo y sombra) | "flat"
    colorMode = "class",          -- "class" | "single"
    barColor = { 0.25, 0.55, 0.95, 1 },
    abilityColorMode = "damageType", -- "damageType" | "single"
    highlightSelf = true,
    classColors = {
        [1]   = { 0.90, 0.40, 0.15, 1 },  -- Caballero dragón
        [2]   = { 0.58, 0.42, 0.95, 1 },  -- Hechicero
        [3]   = { 0.78, 0.16, 0.26, 1 },  -- Hoja de la noche
        [4]   = { 0.30, 0.68, 0.32, 1 },  -- Custodio
        [5]   = { 0.47, 0.58, 0.70, 1 },  -- Nigromante
        [6]   = { 0.95, 0.80, 0.30, 1 },  -- Templario
        [117] = { 0.20, 0.80, 0.72, 1 },  -- Arcanista
    },

    showRank = true,
    showIcon = true,
    showTotal = true,
    showDps = true,
    showPercent = true,
    nameFormat = "character",     -- "character" | "account"

    includePets = true,
    combatEndDelay = 3,           -- segundos fuera de combate antes de cerrar el combate
    historySize = 10,
    showRest = true,              -- barra estimada "Resto del grupo" en combates de jefe
    shareDps = true,              -- compartir tu DPS y HPS con el grupo (LibGroupCombatStats)
}

-- Se usa el canal de sistema (no d(), que es de depuración): addons de chat como pChat
-- solo muestran los mensajes de sistema.
function NM.Chat(msg)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(msg)
    else
        d(msg)
    end
end

function NM.Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    NM.Chat("|c" .. NM.COLOR .. "[Nirnhoned Metrics]|r " .. msg)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= NM.name then return end
    EVENT_MANAGER:UnregisterForEvent(NM.name, EVENT_ADD_ON_LOADED)

    NM.sv = ZO_SavedVars:NewAccountWide("NirnhonedMetrics_SV", NM.svVersion, nil, NM.defaults)

    NM.Fight.Init()
    NM.Group.Init()
    NM.Meter.Init()
    NM.Settings.Init()
    NM.Commands.Init()

    -- Ventana de bienvenida/novedades (solo al instalar o actualizar). Se retrasa unos
    -- segundos para que no coincida con la carga de la interfaz al entrar al mundo.
    EVENT_MANAGER:RegisterForEvent(NM.name .. "_Welcome", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(NM.name .. "_Welcome", EVENT_PLAYER_ACTIVATED)
        zo_callLater(function() NM.Settings.ShowWelcomeIfNeeded() end, WELCOME_DELAY_MS)
    end)
end

EVENT_MANAGER:RegisterForEvent(NM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
