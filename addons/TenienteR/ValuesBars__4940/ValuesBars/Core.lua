--[[
    Core.lua
    Motor del addon: registro de fuentes, creación de etiquetas, eventos y arranque.

    Cada archivo de fuentes (PlayerBars, Target, Boss, Experience...) llama a
    VB.RegisterSource con una tabla que puede tener estos campos:

      id        : identificador único (obligatorio)
      controls  : lista de nombres de control a probar, en orden (obligatorio)
      values    : función que devuelve (actual, máximo) (obligatorio)
      prefix    : (opcional) función que devuelve un texto antes del valor
      unitTags  : (opcional) unidades cuyo EVENT_POWER_UPDATE actualiza esta fuente
      unitTagPrefix : (opcional) prefijo de unidades (ej. "boss" cubre boss1..bossN)
      powerType : (opcional) tipo de poder asociado a unitTags
      events    : (opcional) otros eventos que fuerzan la actualización
      positionable : (opcional) true si el usuario puede elegir poner el valor encima de la barra
      format    : (opcional) función (actual, máximo) que devuelve el texto; por defecto VB.FormatText
      applyPosition : (opcional) función (label) que coloca la etiqueta, sustituye a la colocación general
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

VB.sources = {}

---------------------------------------------------------------------------
-- Registro de fuentes
---------------------------------------------------------------------------

function VB.RegisterSource(def)
    assert(type(def) == "table" and def.id and def.controls and def.values,
        "ValuesBars: una fuente necesita id, controls y values")

    for _, existing in ipairs(VB.sources) do
        assert(existing.id ~= def.id, "ValuesBars: fuente duplicada '" .. def.id .. "'")
    end

    -- Conjunto para comprobar rápido si una unidad pertenece a la fuente
    def.unitTagSet = {}
    for _, unitTag in ipairs(def.unitTags or {}) do
        def.unitTagSet[unitTag] = true
    end

    VB.sources[#VB.sources + 1] = def
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------

local function RefreshSource(src)
    if not src.label or not VB.sv.enabled then return end

    -- pcall: si una función de la API cambia o desaparece, solo falla esa fuente
    -- local ok, current, max = pcall(src.values)
    -- local text = ok and VB.FormatText(current, max) or ""
    local ok, current, max = pcall(src.values)
    local formatter = src.format or VB.FormatText
    local text = ok and formatter(current, max) or ""

    if text ~= "" and src.prefix then
        local okPrefix, prefix = pcall(src.prefix)
        if okPrefix and prefix then
            text = prefix .. "  " .. text
        end
    end

    src.label:SetText(text)
end

local function RefreshAll()
    for _, src in ipairs(VB.sources) do
        RefreshSource(src)
    end
end

VB.RefreshAll = RefreshAll

-- Muestra u oculta todas las etiquetas según la opción "enabled".
-- Con el addon desactivado, RefreshSource no hace nada, así que no gasta recursos.
function VB.ApplyEnabled()
    local enabled = VB.sv.enabled
    for _, src in ipairs(VB.sources) do
        if src.label then
            src.label:SetHidden(not enabled)
        end
    end
    if enabled then RefreshAll() end
end

-- Aplica la fuente actual a todas las etiquetas
function VB.ApplyFont()
    local font = VB.BuildFont()

    for _, src in ipairs(VB.sources) do
        if src.label then
            src.label:SetFont(font)
        end
    end
    VB.ApplyPosition()
end

-- local ABOVE_OFFSET_Y = -2 -- separación entre el texto y el borde superior de la barra
-- local BELOW_OFFSET_Y = 2  -- separación entre el texto y el borde inferior de la barra
-- Algunos estilos de fuente reservan más espacio bajo el texto y lo hacen verse más arriba.
-- Valores positivos bajan el texto.
local STYLE_OFFSET_Y = {
    ["thick-outline"] = { inside = 4, above = 5, below = 2 },
}
VB.STYLE_OFFSET_Y = STYLE_OFFSET_Y
-- Márgen horizontal entre el texto y el borde de la barra al alinear a un lado
local ALIGN_PADDING_INSIDE = 4  -- texto dentro de la barra
local ALIGN_PADDING_OUTSIDE = 0 -- texto encima o debajo (pegado al borde de la barra)

-- Barras que permiten elegir alineación y la clave de SavedVariables de cada una
local ALIGN_KEYS = {
    magicka = "magickaAlign",
    stamina = "staminaAlign",
    xp = "xpAlign",
}

-- Punto de anclaje según la fila (arriba, medio, abajo) y la alineación
local ANCHOR_POINTS = {
    top    = { left = TOPLEFT, center = TOP, right = TOPRIGHT },
    middle = { left = LEFT, center = CENTER, right = RIGHT },
    bottom = { left = BOTTOMLEFT, center = BOTTOM, right = BOTTOMRIGHT },
}

function VB.ApplyPosition()
    local position = VB.sv.playerBarsPosition
    local gap = VB.sv.textGap
    local offsets = STYLE_OFFSET_Y[VB.sv.fontStyle] or {}

    for _, src in ipairs(VB.sources) do
        local label = src.label
        if label then
            local parent = label:GetParent()
            local align = ALIGN_KEYS[src.id] and VB.sv[ALIGN_KEYS[src.id]] or "center"
            local outside = src.positionable and (position == "above" or position == "below")
            local pad = outside and ALIGN_PADDING_OUTSIDE or ALIGN_PADDING_INSIDE
            local x = 0
            if align == "left" then x = pad elseif align == "right" then x = -pad end

            label:ClearAnchors()

            if outside and position == "above" then
                label:SetAnchor(ANCHOR_POINTS.bottom[align], parent, ANCHOR_POINTS.top[align], x,
                    -gap + (offsets.above or 0))
            elseif outside then
                label:SetAnchor(ANCHOR_POINTS.top[align], parent, ANCHOR_POINTS.bottom[align], x,
                    gap + (offsets.below or 0))
            else
                label:SetAnchor(ANCHOR_POINTS.middle[align], parent, ANCHOR_POINTS.middle[align], x, offsets.inside or 0)
            end
        end
    end
    -- Fuentes con colocación propia (por ejemplo la habilidad máxima)
    for _, src in ipairs(VB.sources) do
        if src.label and src.applyPosition then
            src.applyPosition(src.label)
        end
    end
end

---------------------------------------------------------------------------
-- Creación de etiquetas
---------------------------------------------------------------------------

local function CreateLabels()
    local sv = VB.sv

    for _, src in ipairs(VB.sources) do
        local parent = VB.FindControl(src.controls)
        if parent then
            local label = WINDOW_MANAGER:CreateControl(VB.name .. "_Label_" .. src.id, parent, CT_LABEL)
            label:SetFont(VB.BuildFont())
            label:SetColor(sv.color.r, sv.color.g, sv.color.b, sv.color.a)
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetMouseEnabled(false)
            label:SetDrawTier(DT_HIGH) -- por encima de las superposiciones del juego (p. ej. invulnerabilidad)
            label:SetDrawLayer(DL_TEXT)
            label:SetDrawLevel(1)
            label:SetAnchor(CENTER, parent, CENTER, 0, 0)
            src.label = label
        end
    end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

-- Indica si una unidad pertenece a la fuente (por unidad exacta o por prefijo)
local function MatchesUnit(src, unitTag)
    if src.unitTagSet[unitTag] then
        return true
    end
    local prefix = src.unitTagPrefix
    return prefix ~= nil and unitTag:sub(1, #prefix) == prefix
end

local function OnPowerUpdate(_, unitTag, _, powerType)
    for _, src in ipairs(VB.sources) do
        if src.powerType == powerType and MatchesUnit(src, unitTag) then
            RefreshSource(src)
        end
    end
end

local function RegisterEvents()
    -- Un namespace por unidad o prefijo, porque cada filtro es independiente
    local registered = {}

    local function RegisterPowerFilter(key, filterType, filterValue)
        if registered[key] then return end
        registered[key] = true
        local namespace = VB.name .. "_power_" .. key
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_POWER_UPDATE, filterType, filterValue)
    end

    for _, src in ipairs(VB.sources) do
        for _, unitTag in ipairs(src.unitTags or {}) do
            RegisterPowerFilter(unitTag, REGISTER_FILTER_UNIT_TAG, unitTag)
        end
        if src.unitTagPrefix then
            -- Un solo filtro por prefijo (por ejemplo "boss") cubre boss1..bossN
            RegisterPowerFilter("prefix_" .. src.unitTagPrefix, REGISTER_FILTER_UNIT_TAG_PREFIX, src.unitTagPrefix)
        end
    end

    -- Eventos propios de cada fuente (cambio de target, experiencia, jefes...)
    for _, src in ipairs(VB.sources) do
        if src.events then
            for _, event in ipairs(src.events) do
                EVENT_MANAGER:RegisterForEvent(VB.name .. "_" .. src.id, event, function() RefreshSource(src) end)
            end
        end
    end

    EVENT_MANAGER:RegisterForEvent(VB.name, EVENT_PLAYER_ACTIVATED, RefreshAll)
end

---------------------------------------------------------------------------
-- Arranque (se ejecuta cuando ya se cargaron todos los archivos del addon)
---------------------------------------------------------------------------

-- Hasta la 1.0.0 los ajustes se guardaban bajo el perfil "Default", compartido por todos los
-- servidores (NA, EU, PTS). Desde la 1.0.1 cada servidor tiene su propio perfil (GetWorldName()).
-- Si el servidor actual aún no tiene ajustes, se copian los antiguos una sola vez. Los antiguos
-- no se borran, así otro servidor también puede migrarlos.
local function MigrateLegacySavedVars(svName, world)
    local raw = _G[svName]
    if type(raw) ~= "table" then return end

    local account = GetDisplayName()
    local legacy = raw.Default and raw.Default[account] and raw.Default[account]["$AccountWide"]
    if type(legacy) ~= "table" then return end

    raw[world] = raw[world] or {}
    raw[world][account] = raw[world][account] or {}
    if raw[world][account]["$AccountWide"] == nil then
        raw[world][account]["$AccountWide"] = ZO_DeepTableCopy(legacy)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= VB.name and addonName ~= VB.name .. "Dev" then return end
    EVENT_MANAGER:UnregisterForEvent(VB.name, EVENT_ADD_ON_LOADED)

    -- La versión de desarrollo (carpeta ValuesBarsDev) usa su propia variable para no mezclar
    -- sus ajustes con los de la versión instalada.
    local svName = (addonName == VB.name) and "ValuesBars_SV" or "ValuesBarsDev_SV"
    local world = GetWorldName()
    MigrateLegacySavedVars(svName, world)

    ---@diagnostic disable-next-line: undefined-field
    VB.sv = ZO_SavedVars:NewAccountWide(svName, VB.svVersion, nil, VB.defaults, world)

    CreateLabels()
    VB.ApplyPosition()
    RegisterEvents()
    VB.ApplyEnabled()

    -- El menú es opcional: solo existe si LibAddonMenu-2.0 está instalada
    if VB.InitMenu then
        VB.InitMenu()
    end
end

EVENT_MANAGER:RegisterForEvent(VB.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
