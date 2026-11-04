-- Vigilant: punto de entrada, espacio de nombres y SavedVariables.

Vigilant = Vigilant or {}
local VG = Vigilant

VG.name = "Vigilant"
VG.COLOR = "F2B33D"
VG.title = "|c" .. VG.COLOR .. "Vigilant|r"
VG.version = "1.0.0"
VG.svVersion = 1
VG.author = "@Artioner"
-- Textos: se rellenan en lang/en.lua y lang/<idioma del cliente>.lua.
-- Si falta una clave se muestra su nombre en vez de fallar.
VG.L = setmetatable({}, { __index = function(_, key) return key end })

VG.defaults = {
    window = {
        shown = true,
        locked = false,           -- desbloqueada: se ve siempre (para colocarla) y se arrastra
        x = nil, y = nil,         -- esquina superior izquierda; nil = posición inicial
        width = 390,              -- tamaño elegido al redimensionar; los iconos se ajustan a él
        height = 180,
    },
    layout = "grid",              -- "grid" (miembros x bufos) | "summary" (un bufo por fila: n/total)
    nameWidth = 110,
    bgOpacity = 0.85,
    showTimers = true,
    warnSeconds = 3,              -- el tiempo restante se pinta en naranja por debajo de esto
    showRoles = true,
    sortByRole = true,            -- tanques, sanadores y luego DPS
    nameFormat = "character",     -- "character" | "account"
    missingStyle = "dim",         -- "dim" (icono apagado) | "red" (además, fondo rojo)
    showUptime = true,            -- pie con la duración del combate y el uptime de cada bufo
    uptimeScope = "fight",        -- "fight" (cada combate) | "run" (todos los combates hasta cambiar de zona)
    onlyInGroup = false,
    onlyInCombat = false,

    -- [clave del catálogo] = true/false. Sin valor se usa el "on" del catálogo.
    tracked = {},
    -- Bufos añadidos a mano: { id = 12345 } (solo ese ID) o { name = "Texto" } (cualquier ID con ese nombre).
    custom = {},
    -- Orden de las columnas: lista de claves (ver Catalog.GetColumns). Vacía = orden del catálogo.
    order = {},
}

-- Se usa el canal de sistema (no d(), que es de depuración): addons de chat como pChat
-- solo muestran los mensajes de sistema.
function VG.Chat(msg)
    CHAT_ROUTER:AddSystemMessage(msg)
end

function VG.Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    VG.Chat("|c" .. VG.COLOR .. "[Vigilant]|r " .. msg)
end

---------------------------------------------------------------------------
-- Ajustes de cuenta o de personaje
-- Cada personaje elige si usa los ajustes de la cuenta (por defecto) o los suyos. La
-- elección se guarda en el personaje, junto a sus ajustes propios. Los de la cuenta
-- son comunes a todos los megaservidores a propósito: solo guardan la posición y el
-- aspecto del panel y qué bufos seguir, que no dependen del servidor. Los de personaje
-- ya van separados por servidor (el ID de personaje es distinto en cada uno).
-- Cambiar de uno a otro necesita /reloadui: VG.sv se elige al cargar.
---------------------------------------------------------------------------
local function LoadSettings()
    VG.accountSV = ZO_SavedVars:NewAccountWide("Vigilant_SV", VG.svVersion, nil, VG.defaults)
    local charDefaults = ZO_ShallowTableCopy(VG.defaults)
    charDefaults.useAccountWide = true
    VG.charSV = ZO_SavedVars:NewCharacterIdSettings("Vigilant_SV", VG.svVersion, nil, charDefaults)
    VG.sv = VG.charSV.useAccountWide and VG.accountSV or VG.charSV
end

function VG.UsesAccountSettings()
    return VG.charSV.useAccountWide
end

-- La primera vez que un personaje pasa a tener sus propios ajustes, empieza con una copia
-- de los de la cuenta en vez de con los de por defecto.
function VG.SetUseAccountSettings(useAccount)
    local char = VG.charSV
    char.useAccountWide = useAccount
    if useAccount or char.copiedFromAccount then return end
    char.copiedFromAccount = true
    for key in pairs(VG.defaults) do
        local value = VG.accountSV[key]
        char[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= VG.name then return end
    EVENT_MANAGER:UnregisterForEvent(VG.name, EVENT_ADD_ON_LOADED)

    LoadSettings()

    VG.Catalog.Init()
    VG.Tracker.Init()
    VG.Panel.Init()
    VG.Settings.Init()
    VG.Commands.Init()
end

EVENT_MANAGER:RegisterForEvent(VG.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
