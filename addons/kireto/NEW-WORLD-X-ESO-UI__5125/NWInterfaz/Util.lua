NWInterfaz = NWInterfaz or {}
local NWUI = NWInterfaz
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

NWUI.name = "NWInterfaz"
NWUI.version = "1.9.7"
NWUI.movables = {}
NWUI.unlocked = false

-- =====================================================================
-- Paleta PLANA (sin degradados). Cambia aquí los colores si quieres.
-- =====================================================================
NWUI.C = {
    panelBg     = {0.071, 0.075, 0.082, 0.96},
    panelBorder = {0.42, 0.36, 0.25, 1},
    headerBg    = {0.086, 0.165, 0.267, 1},
    headerLine  = {0.71, 0.58, 0.33, 1},
    sectionLine = {0.27, 0.27, 0.28, 1},
    text        = {0.90, 0.87, 0.80, 1},
    textDim     = {0.58, 0.56, 0.52, 1},
    gold        = {0.89, 0.74, 0.40, 1},
    slotEmpty   = {0.11, 0.11, 0.12, 1},
    slotBorder  = {0.22, 0.22, 0.23, 1},
    trackBg     = {0.035, 0.035, 0.04, 1},
    capFill     = {0.76, 0.68, 0.53, 1},
    scrollThumb = {0.80, 0.58, 0.16, 1},
    danger      = {0.78, 0.22, 0.18, 1},
    black       = {0, 0, 0, 1},
}

-- Fondo de cada casilla según la calidad del objeto (colores sólidos)
NWUI.QUALITY = {
    [0] = {0.20, 0.19, 0.18}, -- basura
    [1] = {0.27, 0.27, 0.28}, -- normal
    [2] = {0.20, 0.43, 0.15}, -- fino (verde)
    [3] = {0.12, 0.33, 0.55}, -- superior (azul)
    [4] = {0.38, 0.19, 0.53}, -- épico (morado)
    [5] = {0.66, 0.48, 0.12}, -- legendario (dorado)
    [6] = {0.64, 0.33, 0.13}, -- mítico (naranja)
}

NWUI.F = {
    -- Títulos: Trajan del juego (STONE_TABLET_FONT), la letra romana en la que se basa Cinzel
    title    = "$(STONE_TABLET_FONT)|28|soft-shadow-thick",
    cap      = "$(ANTIQUE_FONT)|24|soft-shadow-thin",
    section  = "$(STONE_TABLET_FONT)|18|soft-shadow-thick",
    body     = "$(MEDIUM_FONT)|16|soft-shadow-thin",
    small    = "$(MEDIUM_FONT)|14|soft-shadow-thin",
    tiny     = "$(MEDIUM_FONT)|12|soft-shadow-thin",
    count    = "$(BOLD_FONT)|15|thick-outline",
    key      = "$(BOLD_FONT)|13|soft-shadow-thin",
    big      = "$(ANTIQUE_FONT)|46|soft-shadow-thick",
    barBig   = "$(BOLD_FONT)|15|soft-shadow-thick",
    barSmall = "$(BOLD_FONT)|11|soft-shadow-thin",
    level    = "$(BOLD_FONT)|16|soft-shadow-thick",
    price    = "$(BOLD_FONT)|12|soft-shadow-thin",
    gold     = "$(BOLD_FONT)|20|soft-shadow-thick",
    groupHdr = "$(BOLD_FONT)|18|soft-shadow-thick",
    mundus   = "$(BOLD_FONT)|18|soft-shadow-thick",
    hint     = "$(BOLD_FONT)|16|soft-shadow-thick",
}

-- =====================================================================
-- Ayudantes de controles
-- =====================================================================
local uid = 0
function NWUI.UID(prefix)
    uid = uid + 1
    return (prefix or "NWUI_C") .. uid
end

function NWUI.SetColor(ctrl, c, alpha)
    ctrl:SetColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

-- Píxeles reales: la interfaz de ESO se escala (Ajustes > Escala de la IU),
-- así que 1 unidad no siempre es 1 píxel. Las posiciones que no caen en un
-- píxel entero hacen que las líneas de 1 px desaparezcan.
function NWUI.UIScale()
    local s = (GetUIGlobalScale()) or 1
    if type(s) ~= "number" or s <= 0 then s = 1 end
    return math.min(4, math.max(0.3, s))
end

function NWUI.PixelSnap(v)
    local s = NWUI.UIScale()
    return math.floor(v * s + 0.5) / s
end

-- Grosor de línea que nunca baja de 1 píxel real.
function NWUI.LinePx(n)
    n = n or 1
    return math.max(n, n / NWUI.UIScale())
end

function NWUI.Tex(parent, color, drawLevel)
    local t = WM:CreateControl(NWUI.UID("NWUI_T"), parent, CT_TEXTURE)
    if color then NWUI.SetColor(t, color) end
    if drawLevel then t:SetDrawLevel(drawLevel) end
    return t
end

-- Negrita simulada para la letra de los títulos (Trajan no tiene versión
-- bold en el juego): una copia del texto desplazada 1 px a la derecha que
-- sigue siempre al original (texto, color, letra, alineación, recorte).
local BOLD_OFFSET = 1
function NWUI.Embolden(l, font)
    if l.nwGhost then return l.nwGhost end
    local g = WM:CreateControl(NWUI.UID("NWUI_LB"), l, CT_LABEL)
    g:SetAnchor(TOPLEFT, l, TOPLEFT, BOLD_OFFSET, 0)
    g:SetAnchor(BOTTOMRIGHT, l, BOTTOMRIGHT, BOLD_OFFSET, 0)
    g:SetDrawLevel(8)
    l.nwGhost = g
    local function mirror(method)
        local orig = l[method]
        l[method] = function(self, ...)
            orig(self, ...)
            g[method](g, ...)
        end
    end
    for _, m in ipairs({ "SetText", "SetColor", "SetFont", "SetHorizontalAlignment",
                         "SetVerticalAlignment", "SetMaxLineCount", "SetWrapMode", "SetModifyTextType" }) do
        mirror(m)
    end
    -- copiar el estado actual
    g:SetFont(font or NWUI.F.section)
    if l.GetColor then g:SetColor(l:GetColor()) end
    if l.GetText then g:SetText(l:GetText() or "") end
    return g
end

function NWUI.Label(parent, font, color, text)
    local l = WM:CreateControl(NWUI.UID("NWUI_L"), parent, CT_LABEL)
    l:SetFont(font)
    NWUI.SetColor(l, color or NWUI.C.text)
    l:SetDrawLevel(8)
    if text then l:SetText(text) end
    if type(font) == "string" and font:find("STONE_TABLET_FONT", 1, true) then NWUI.Embolden(l, font) end
    return l
end

-- Caja plana: borde sólido + fondo sólido, esquinas rectas.
-- Fondo (puede ser translúcido) con 4 líneas de borde: el borde no se
-- transparenta a través del fondo como en FlatBox.
function NWUI.EdgeBox(parent, bg, edge, size)
    size = size or NWUI.LinePx(1)
    local b = NWUI.Tex(parent, bg, 0)
    b:SetAnchorFill(parent)
    local e = {}
    for i = 1, 4 do e[i] = NWUI.Tex(parent, edge, 1) end
    e[1]:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0);       e[1]:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0);       e[1]:SetHeight(size)
    e[2]:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0); e[2]:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0); e[2]:SetHeight(size)
    e[3]:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0);       e[3]:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0);   e[3]:SetWidth(size)
    e[4]:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0);     e[4]:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0); e[4]:SetWidth(size)
    return b, e
end

function NWUI.FlatBox(parent, bg, border, size)
    size = size or 1
    local b = NWUI.Tex(parent, border, 0)
    b:SetAnchorFill(parent)
    local i = NWUI.Tex(parent, bg, 1)
    i:SetAnchor(TOPLEFT, parent, TOPLEFT, size, size)
    i:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -size, -size)
    return b, i
end

-- Degradado vertical (arriba -> abajo). En ORIENTATION_VERTICAL el color
-- inicial es el de abajo (igual que el selector de color del juego).
function NWUI.Gradient(tex, top, bottom)
    NWUI.SetColor(tex, top)
    tex:SetGradientColors(ORIENTATION_VERTICAL,
        bottom[1], bottom[2], bottom[3], bottom[4] or 1, top[1], top[2], top[3], top[4] or 1)
end

-- "INVENTARIO" -> "I N V E N T A R I O" (respeta acentos UTF-8)
-- Separa un texto UTF-8 en caracteres recorriendo los bytes (sin patrones,
-- que en el juego no manejan bien las letras acentuadas como Í o É).
local function Utf8Chars(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local b = s:byte(i)
        local len = 1
        if b >= 240 then len = 4 elseif b >= 224 then len = 3 elseif b >= 192 then len = 2 end
        out[#out + 1] = s:sub(i, i + len - 1)
        i = i + len
    end
    return out
end
NWUI.Utf8Chars = Utf8Chars

function NWUI.Spaced(s)
    return table.concat(Utf8Chars(s), " ")
end

-- Obtiene una función global del juego SIN tocar las privadas.
-- (Leer una función privada desde un addon provoca "Attempt to access a private function".)
function NWUI.SafeGet(fnName)
    if IsPrivateFunction(fnName) then return nil end
    local fn = _G[fnName]
    if type(fn) == "function" then return fn end
    return nil
end

-- Títulos de cabecera (INVENTARIO, BANCO, MONEDA...):
--  · TODOS con el mismo tamaño de letra (NWUI.titleSize, el mayor con el que
--    cabe el título más largo);
--  · cada letra es una etiqueta propia; la separación entre letras se ajusta
--    al espacio de cada título (máx. TITLE_TRACK_MAX, mín. TITLE_TRACK_MIN),
--    así los cortos quedan aireados y los largos no chocan con el candado.
local TITLE_TRACK_MAX = 5
local TITLE_TRACK_MIN = 1
NWUI.titleSize = 24

local function TitleFont(size) return "$(STONE_TABLET_FONT)|" .. size .. "|soft-shadow-thick" end

local measurer, widthCache = nil, {}
local function CharWidth(ch, size)
    local key = size .. "|" .. ch
    local w = widthCache[key]
    if w then return w end
    if not measurer then
        measurer = WM:CreateControl("NWUI_TitleMeasure", GuiRoot, CT_LABEL)
        measurer:SetHidden(true)
    end
    measurer:SetFont(TitleFont(size))
    measurer:SetText(ch)
    w = measurer.GetTextWidth and measurer:GetTextWidth()
    if type(w) ~= "number" or w <= 0 then w = size * 0.72 end
    widthCache[key] = w
    return w
end

-- Ancho del título con una separación dada (para elegir tamaño)
function NWUI.TitleWidth(title, size, track, word)
    local chars = Utf8Chars(title or "")
    local total, prevLetter = 0, false
    for _, ch in ipairs(chars) do
        if ch == " " then
            total = total + word
            prevLetter = false
        else
            if prevLetter then total = total + track end
            total = total + CharWidth(ch, size)
            prevLetter = true
        end
    end
    return total
end

local function WordGap(size, track) return math.max(size * 0.33, track * 2.4) end

-- Elige el tamaño común: el mayor con el que TODOS los títulos caben en maxW
function NWUI.FitTitleSize(titles, maxW)
    for size = 26, 14, -1 do
        local ok = true
        for _, t in ipairs(titles) do
            if NWUI.TitleWidth(t, size, TITLE_TRACK_MIN, WordGap(size, TITLE_TRACK_MIN)) > maxW then ok = false; break end
        end
        if ok then return size end
    end
    return 14
end

local function TitleChars(label)
    local list = label.nwChars
    if type(list) ~= "table" then list = {}; label.nwChars = list end
    return list
end

function NWUI.LayoutTitle(label)
    local title = label.nwTitle
    if type(title) ~= "string" then title = "" end
    local maxW = label.nwMaxW
    if type(maxW) ~= "number" or maxW <= 0 then maxW = nil end
    local size = NWUI.titleSize
    local chars = Utf8Chars(title)
    local list = TitleChars(label)
    for i = #list + 1, #chars do
        list[i] = NWUI.Label(label, TitleFont(size), NWUI.C.text, "")
    end
    -- separación: la máxima que quepa
    local track = TITLE_TRACK_MAX
    if maxW then
        while track > TITLE_TRACK_MIN and NWUI.TitleWidth(title, size, track, WordGap(size, track)) > maxW do
            track = track - 0.5
        end
    end
    local word = WordGap(size, track)
    local color = (type(label.nwColor) == "table") and label.nwColor or NWUI.C.text
    local font = TitleFont(size)
    local x, prevLetter = 0, false
    for i, l in ipairs(list) do
        l:ClearAnchors()
        local ch = chars[i]
        if ch then
            l:SetHidden(false)
            l:SetFont(font)
            NWUI.SetColor(l, color)
            if ch == " " then
                l:SetText("")
                x = x + word
                prevLetter = false
            else
                if prevLetter then x = x + track end
                l:SetText(ch)
                l:SetAnchor(BOTTOMLEFT, label, BOTTOMLEFT, NWUI.PixelSnap(x), 0)
                x = x + CharWidth(ch, size)
                prevLetter = true
            end
        else
            l:SetHidden(true)
        end
    end
    label:SetText("")
    label:SetDimensions(math.max(1, x), 34)
    label.nwTitleW = x
    label.nwTitleSize = size
    label.nwTrack = track
end

-- Reduce la letra de un título de sección hasta que quepa en maxW
-- (para textos más largos en otros idiomas). Devuelve el tamaño usado.
function NWUI.FitLabel(label, maxW, maxSize, minSize)
    maxSize, minSize = maxSize or 18, minSize or 13
    for size = maxSize, minSize, -1 do
        label:SetFont("$(STONE_TABLET_FONT)|" .. size .. "|soft-shadow-thick")
        local w = label.GetTextWidth and label:GetTextWidth()
        if type(w) ~= "number" or not maxW or w <= maxW then return size end
    end
    return minSize
end

function NWUI.SetTitle(label, title, maxW)
    label.nwTitle = title or ""
    if maxW then label.nwMaxW = maxW end
    NWUI.LayoutTitle(label)
end

-- Llama una función del juego; usa CallSecureProtected si está protegida.
-- Devuelve false si la función es privada (los addons no pueden usarla).
function NWUI.Call(fnName, ...)
    if IsProtectedFunction(fnName) then
        return CallSecureProtected(fnName, ...)
    end
    local fn = NWUI.SafeGet(fnName)
    if not fn then return false end
    return true, fn(...)
end

function NWUI.Throttle(key, ms, fn)
    EM:UnregisterForUpdate(key)
    EM:RegisterForUpdate(key, ms, function()
        EM:UnregisterForUpdate(key)
        fn()
    end)
end

-- Fragmento de escena SEGURO para las ventanas del addon.
-- Los fragmentos con animación (ZO_FadeSceneFragment / ZO_HUDFadeSceneFragment)
-- creados por un addon terminan su animación desde código "no confiable" y es
-- esa animación la que da paso a la siguiente escena: el juego entonces bloquea
-- funciones privadas de esa escena (p. ej. "QuerySkuCatalog" al abrir los Tomos
-- de Tamriel o la Tienda de Coronas). ZO_SimpleSceneFragment se muestra y oculta
-- al instante, dentro del propio flujo del juego; el fundido de entrada lo hace
-- el addon por su cuenta, sin intervenir en el cambio de escena.
local fadeN = 0
function NWUI.SafeFragment(control, fadeMs)
    local f = ZO_SimpleSceneFragment:New(control)
    fadeMs = fadeMs or 150
    fadeN = fadeN + 1
    local key = "NWUI_FragFade" .. fadeN
    f:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            local t0 = (GetFrameTimeMilliseconds()) or 0
            control:SetAlpha(0)
            EM:RegisterForUpdate(key, 0, function()
                local now = (GetFrameTimeMilliseconds()) or (t0 + fadeMs)
                local p = math.min(1, (now - t0) / fadeMs)
                control:SetAlpha(p)
                if p >= 1 then EM:UnregisterForUpdate(key) end
            end)
        elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
            EM:UnregisterForUpdate(key)
            control:SetAlpha(1)
        end
    end)
    return f
end

-- Parpadeo suave (se enciende y se apaga) para las marcas de "nuevo".
-- Un único bucle para todas las marcas visibles; se detiene si no hay ninguna.
local pulsing = setmetatable({}, { __mode = "k" })
local PULSE_MS = 1100
local function PulseStep()
    local now = (GetFrameTimeMilliseconds()) or 0
    local a = 0.20 + 0.80 * (0.5 + 0.5 * math.cos(2 * math.pi * (now % PULSE_MS) / PULSE_MS))
    local any = false
    for tex in pairs(pulsing) do
        -- una marca oculta por sí misma (no por su ventana) deja de parpadear
        local own = tex.IsControlHidden and tex:IsControlHidden()
        if own == true then
            pulsing[tex] = nil
            tex:SetAlpha(1)
        else
            any = true
            if tex.SetAlpha then tex:SetAlpha(a) end
        end
    end
    if not any then EM:UnregisterForUpdate("NWUI_Pulse"); NWUI.pulseOn = false end
end
function NWUI.Pulse(tex, on)
    if not tex then return end
    if on then
        pulsing[tex] = true
        if not NWUI.pulseOn then
            NWUI.pulseOn = true
            EM:RegisterForUpdate("NWUI_Pulse", 0, PulseStep)
        end
    else
        pulsing[tex] = nil
        if tex.SetAlpha then tex:SetAlpha(1) end
    end
end

-- Registra un evento solo si existe en esta versión del juego.
function NWUI.On(ns, evName, fn, filterType, filterValue)
    local ev = _G[evName]
    if not ev then return false end
    EM:RegisterForEvent(ns, ev, fn)
    if filterType ~= nil and filterValue ~= nil then
        EM:AddFilterForEvent(ns, ev, filterType, filterValue)
    end
    return true
end

-- Guardar / restaurar anclas de controles del juego
function NWUI.SaveAnchors(c)
    local anchors = {}
    for i = 0, 1 do
        local valid, point, rel, relPoint, x, y, constrains = c:GetAnchor(i)
        if valid then anchors[#anchors + 1] = { point, rel, relPoint, x or 0, y or 0, constrains } end
    end
    return anchors
end

function NWUI.RestoreAnchors(c, anchors)
    c:ClearAnchors()
    for _, a in ipairs(anchors) do
        c:SetAnchor(a[1], a[2], a[3], a[4], a[5], a[6])
    end
end

-- ¿Está oculto el control o alguno de sus padres?
function NWUI.IsReallyHidden(c)
    if not c then return true end
    return c:IsControlHidden()
end

-- =====================================================================
-- Modo edición: mover, cambiar tamaño (rueda) y cuadrícula
-- =====================================================================
local function Snap(v, center)
    if not (NWUI.unlocked and NWUI.sv.snap) then return v end
    local s = NWUI.sv.gridSize or 20
    return center + math.floor((v - center) / s + 0.5) * s
end

function NWUI.ApplyPosition(m)
    local p = NWUI.sv.positions[m.key]
    -- Posición guardada fuera de la pantalla: se descarta y se usa la de fábrica.
    if p then
        local W, H = GuiRoot:GetWidth(), GuiRoot:GetHeight()
        if type(p.x) ~= "number" or type(p.y) ~= "number"
            or p.x < -40 or p.y < -40 or (W > 0 and p.x > W - 40) or (H > 0 and p.y > H - 40) then
            NWUI.sv.positions[m.key] = nil
            p = nil
        end
    end
    m.control:ClearAnchors()
    if p then
        m.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, p.x, p.y)
    elseif m.default then
        m.default(m.control)
    end
end

-- onWheel(delta, shift): cambia el tamaño del elemento en modo edición
function NWUI.RegisterMovable(control, key, defaultFn, title, always, onWheel)
    local m = { control = control, key = key, default = defaultFn, always = always, onWheel = onWheel }
    m.overlay = NWUI.Tex(control, {0.90, 0.70, 0.25, 0.22}, 60)
    m.overlay:SetAnchorFill(control)
    m.overlay:SetHidden(true)
    m.overlayEdge = NWUI.Tex(control, {0.95, 0.75, 0.30, 0.9}, 59)
    m.overlayEdge:SetAnchor(TOPLEFT, control, TOPLEFT, -1, -1)
    m.overlayEdge:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 1, 1)
    m.overlayEdge:SetHidden(true)
    m.overlayEdge:SetAlpha(0.35)
    m.overlayLabel = NWUI.Label(control, NWUI.F.small, NWUI.C.text,
        (title or key) .. (onWheel and ("\n|c999999" .. NWUI.T("wheel_size") .. "|r") or ""))
    m.overlayLabel:SetDrawLevel(61)
    m.overlayLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    m.overlayLabel:SetAnchor(CENTER, control, CENTER, 0, 0)
    m.overlayLabel:SetHidden(true)

    control:SetHandler("OnMoveStop", function(self)
        local x = Snap(self:GetLeft(), GuiRoot:GetWidth() / 2)
        local y = Snap(self:GetTop(), GuiRoot:GetHeight() / 2)
        NWUI.sv.positions[m.key] = { x = x, y = y }
        NWUI.ApplyPosition(m)
    end)
    control:SetHandler("OnMouseWheel", function(_, delta)
        if NWUI.unlocked and m.onWheel then m.onWheel(delta, IsShiftKeyDown()) end
    end)
    if always then
        control:SetMovable(true)
        control:SetMouseEnabled(true)
    end
    NWUI.movables[#NWUI.movables + 1] = m
    NWUI.ApplyPosition(m)
    return m
end

local function GridLine(n, vertical, pos, kind)
    local g = NWUI.gridTLW
    local t = NWUI.gridLines[n]
    if not t then
        t = NWUI.Tex(g, nil, 1)
        NWUI.gridLines[n] = t
    end
    t:ClearAnchors()
    t:SetHidden(false)
    if kind == "c" then
        t:SetColor(0.89, 0.74, 0.40, 0.55)
    elseif kind == "M" then
        t:SetColor(1, 1, 1, 0.16)
    else
        t:SetColor(1, 1, 1, 0.06)
    end
    if vertical then
        t:SetAnchor(TOPLEFT, g, TOPLEFT, pos, 0)
        t:SetDimensions(1, GuiRoot:GetHeight())
    else
        t:SetAnchor(TOPLEFT, g, TOPLEFT, 0, pos)
        t:SetDimensions(GuiRoot:GetWidth(), 1)
    end
end

function NWUI.BuildGrid()
    if not NWUI.gridTLW then
        local g = WM:CreateTopLevelWindow("NWUI_Grid")
        g:SetAnchorFill(GuiRoot)
        g:SetMouseEnabled(false)
        g:SetDrawTier(DT_MEDIUM)
        g:SetHidden(true)
        NWUI.gridTLW = g
        NWUI.gridLines = {}
        NWUI.gridHint = NWUI.Label(g, NWUI.F.body, NWUI.C.gold,
            NWUI.T("edit_bar"))
        NWUI.gridHint:SetAnchor(TOP, g, TOP, 0, 70)
        local hb = NWUI.Tex(g, {0, 0, 0, 0.75}, 0)
        hb:SetAnchor(TOPLEFT, NWUI.gridHint, TOPLEFT, -12, -6)
        hb:SetAnchor(BOTTOMRIGHT, NWUI.gridHint, BOTTOMRIGHT, 12, 6)
    end
    for _, t in ipairs(NWUI.gridLines) do t:SetHidden(true) end
    local step = math.max(8, NWUI.sv.gridSize or 20)
    local W, H = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local cx, cy = W / 2, H / 2
    local n, i = 0, 0
    for x = cx, W, step do n = n + 1; GridLine(n, true, x, i == 0 and "c" or (i % 5 == 0 and "M" or "m")); i = i + 1 end
    i = 1
    for x = cx - step, 0, -step do n = n + 1; GridLine(n, true, x, i % 5 == 0 and "M" or "m"); i = i + 1 end
    i = 0
    for y = cy, H, step do n = n + 1; GridLine(n, false, y, i == 0 and "c" or (i % 5 == 0 and "M" or "m")); i = i + 1 end
    i = 1
    for y = cy - step, 0, -step do n = n + 1; GridLine(n, false, y, i % 5 == 0 and "M" or "m"); i = i + 1 end
end

function NWUI.SetUnlocked(state)
    NWUI.unlocked = state and true or false
    for _, m in ipairs(NWUI.movables) do
        if not m.always then
            m.control:SetMovable(NWUI.unlocked)
            m.control:SetMouseEnabled(NWUI.unlocked)
        end
        m.overlay:SetHidden(not NWUI.unlocked)
        m.overlayEdge:SetHidden(not NWUI.unlocked)
        m.overlayLabel:SetHidden(not NWUI.unlocked)
    end
    if NWUI.unlocked and NWUI.sv.showGrid then NWUI.BuildGrid() end
    if NWUI.gridTLW then NWUI.gridTLW:SetHidden(not (NWUI.unlocked and NWUI.sv.showGrid)) end
    if NWUI.HUD and NWUI.HUD.SetUnlocked then NWUI.HUD.SetUnlocked(NWUI.unlocked) end
    if NWUI.Equipment and NWUI.Equipment.SetUnlocked then NWUI.Equipment.SetUnlocked(NWUI.unlocked) end
    if NWUI.Inventory and NWUI.Inventory.ApplyLocks then NWUI.Inventory.ApplyLocks() end
    if NWUI.unlocked then
        d("|cC9A35E[NW Interfaz]|r " .. NWUI.T("edit_on"))
    else
        d("|cC9A35E[NW Interfaz]|r " .. NWUI.T("edit_saved"))
    end
end

function NWUI.ResetPositions()
    NWUI.sv.positions = {}
    for _, m in ipairs(NWUI.movables) do NWUI.ApplyPosition(m) end
    if NWUI.HUD and NWUI.HUD.LayoutAll then NWUI.HUD.LayoutAll() end
    d("|cC9A35E[NW Interfaz]|r " .. NWUI.T("edit_reset"))
end

-- =====================================================================
-- Acciones de objetos (equipar, mover entre bolsas, gremio)
-- =====================================================================
local function Hint(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, text)
end

function NWUI.Equip(bag, slot, equipSlot)
    if NWUI.Call("EquipItem", bag, slot, equipSlot) then return true end
    if NWUI.Call("RequestEquipItem", bag, slot, BAG_WORN, equipSlot) then return true end
    Hint(NWUI.T("hint_equip"))
    return false
end

function NWUI.Unequip(equipSlot)
    if NWUI.Call("UnequipItem", equipSlot) then return true end
    if NWUI.Call("RequestUnequipItem", BAG_WORN, equipSlot) then return true end
    Hint(NWUI.T("hint_unequip"))
    return false
end

function NWUI.BankTargets()
    local b = (GetBankingBag()) or BAG_BANK
    if b == BAG_BANK then
        return { BAG_BANK, BAG_SUBSCRIBER_BANK }
    end
    return { b }
end

local function NoSpace()
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, NWUI.T("no_space"))
end

-- family: "backpack" | "bank" | "guild"
function NWUI.MoveItem(fromBag, fromSlot, family)
    if fromBag == BAG_GUILDBANK then
        if family == "backpack" then NWUI.Call("TransferFromGuildBank", fromSlot) end
        return
    end
    if family == "guild" then
        NWUI.Call("TransferToGuildBank", fromBag, fromSlot)
        return
    end
    local targets = (family == "backpack") and { BAG_BACKPACK } or NWUI.BankTargets()
    for _, t in ipairs(targets) do
        if t == fromBag then return end
    end
    local stack, maxStack = GetSlotStackSize(fromBag, fromSlot)
    if maxStack and maxStack > 0 and stack > maxStack then stack = maxStack end
    for _, t in ipairs(targets) do
        local empty = FindFirstEmptySlotInBag(t)
        if empty then
            NWUI.Call("RequestMoveItem", fromBag, fromSlot, t, empty, stack)
            return
        end
    end
    NoSpace()
end

-- Soltar lo que está en el cursor sobre un panel o una casilla de equipo
function NWUI.DropOnto(family, equipSlot)
    if GetCursorContentType() == MOUSE_CONTENT_EMPTY then return end
    local fromBag, fromSlot = GetCursorBagId(), GetCursorSlotIndex()
    ClearCursor()
    if fromBag == nil or fromSlot == nil then return end
    if family == "worn" then
        if fromBag ~= BAG_WORN then NWUI.Equip(fromBag, fromSlot, equipSlot) end
        return
    end
    if fromBag == BAG_WORN then
        if family == "backpack" then NWUI.Unequip(fromSlot) end
        return
    end
    NWUI.MoveItem(fromBag, fromSlot, family)
end
