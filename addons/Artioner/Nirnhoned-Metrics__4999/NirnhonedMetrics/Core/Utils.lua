-- Utilidades: formato de números y tiempo, colores, iconos de clase.

local NM = NirnhonedMetrics
local U = {}
NM.Utils = U

local floor = math.floor

function U.Trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

-- 4430000 -> "4.43M", 53400 -> "53.4K", 950 -> "950"
function U.FormatNumber(n)
    n = n or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e5 then return string.format("%dK", floor(n / 1e3 + 0.5)) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(floor(n + 0.5))
end

function U.FormatPercent(p)
    return string.format("%.1f%%", (p or 0) * 100)
end

-- Segundos -> "1:23"
function U.FormatDuration(sec)
    sec = floor(sec or 0)
    if sec >= 3600 then
        return string.format("%d:%02d:%02d", floor(sec / 3600), floor(sec % 3600 / 60), sec % 60)
    end
    return string.format("%d:%02d", floor(sec / 60), sec % 60)
end

function U.FormatName(name)
    if not name or name == "" then return "" end
    return zo_strformat("<<1>>", name)
end

-- Nombre de habilidad con la primera letra en mayúscula (algunos idiomas del cliente,
-- como el español, los dan en minúscula: "pulso de fuerza").
function U.AbilityName(name)
    if not name or name == "" then return "" end
    return zo_strformat(SI_ABILITY_NAME, name)
end

function U.Color(c, default)
    c = c or default
    if type(c) ~= "table" then return 1, 1, 1, 1 end
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
end

---------------------------------------------------------------------------
-- Clases: icono y nombre por classId (GetClassInfo devuelve el icono en 7.º lugar).
---------------------------------------------------------------------------
local classIcons, classNames

local function LoadClasses()
    classIcons, classNames = {}, {}
    for i = 1, GetNumClasses() do
        local id, _, _, _, _, _, icon = GetClassInfo(i)
        if id then
            classIcons[id] = icon
            classNames[id] = U.FormatName(GetClassName(GENDER_MALE, id))
        end
    end
end

function U.ClassIcon(classId)
    if not classIcons then LoadClasses() end
    return classId and classIcons[classId]
end

function U.ClassName(classId)
    if not classNames then LoadClasses() end
    return classId and classNames[classId] or tostring(classId)
end

---------------------------------------------------------------------------
-- Colores por tipo de daño (modo "tus habilidades").
---------------------------------------------------------------------------
local DAMAGE_TYPE_COLORS = {}
local function DT(constName, r, g, b)
    local id = _G[constName]
    if id then DAMAGE_TYPE_COLORS[id] = { r, g, b, 1 } end
end
DT("DAMAGE_TYPE_PHYSICAL", 0.72, 0.66, 0.55)
DT("DAMAGE_TYPE_FIRE", 0.95, 0.45, 0.15)
DT("DAMAGE_TYPE_SHOCK", 0.62, 0.48, 1.00)
DT("DAMAGE_TYPE_COLD", 0.45, 0.75, 1.00)
DT("DAMAGE_TYPE_POISON", 0.45, 0.80, 0.25)
DT("DAMAGE_TYPE_DISEASE", 0.62, 0.66, 0.30)
DT("DAMAGE_TYPE_MAGIC", 0.30, 0.50, 1.00)
DT("DAMAGE_TYPE_BLEED", 0.80, 0.15, 0.15)
DT("DAMAGE_TYPE_OBLIVION", 0.72, 0.30, 0.82)
local DAMAGE_TYPE_DEFAULT = { 0.6, 0.6, 0.6, 1 }

function U.DamageTypeColor(damageType)
    return DAMAGE_TYPE_COLORS[damageType] or DAMAGE_TYPE_DEFAULT
end
