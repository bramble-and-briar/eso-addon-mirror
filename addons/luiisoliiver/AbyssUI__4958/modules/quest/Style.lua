-- Общий стиль «плитки»: квадрат с цветной заливкой, тонкой рамкой и значком.
-- Используется для кнопок на экране, колеса, превью в редакторах и сетки значков.
-- Палитра тёмная и плоская, поэтому хорошо смотрится и со стандартным
-- интерфейсом, и с тёмными темами вроде Dark UI.
local QTM = AbyssQuest

local Style = {}
QTM.Style = Style

Style.MISSING_ICON = "/esoui/art/icons/icon_missing.dds"

-- Готовые цвета (r, g, b от 0 до 1)
Style.PALETTE = {
    { r = 0.36, g = 0.76, b = 0.91 }, -- лёд (цвет аддона)
    { r = 0.25, g = 0.55, b = 0.96 }, -- лазурь
    { r = 0.18, g = 0.77, b = 0.71 }, -- бирюза
    { r = 0.30, g = 0.69, b = 0.31 }, -- изумруд
    { r = 0.61, g = 0.77, b = 0.24 }, -- лайм
    { r = 0.90, g = 0.71, b = 0.31 }, -- золото
    { r = 0.94, g = 0.54, b = 0.14 }, -- янтарь
    { r = 0.90, g = 0.28, b = 0.30 }, -- багрянец
    { r = 0.91, g = 0.36, b = 0.60 }, -- роза
    { r = 0.61, g = 0.42, b = 0.94 }, -- фиалка
    { r = 0.56, g = 0.64, b = 0.72 }, -- сталь
    { r = 0.72, g = 0.72, b = 0.72 }, -- пепел
}

Style.DEFAULT_COLOR = Style.PALETTE[1]

local BASE = { r = 0.055, g = 0.060, b = 0.070 }  -- почти чёрный фон
local GREY = { r = 0.45,  g = 0.45,  b = 0.47 }

local function Mix(a, b, t)
    return a + (b - a) * t
end

-- Цвет, «утопленный» в тёмный фон на долю t
function Style.Darken(color, t)
    return Mix(BASE.r, color.r, t), Mix(BASE.g, color.g, t), Mix(BASE.b, color.b, t)
end

-- Цвет, осветлённый к белому на долю t
function Style.Lighten(color, t)
    return Mix(color.r, 1, t), Mix(color.g, 1, t), Mix(color.b, 1, t)
end

function Style.CopyColor(color)
    color = color or Style.DEFAULT_COLOR
    return { r = color.r, g = color.g, b = color.b }
end

function Style.SameColor(a, b)
    return a and b and math.abs(a.r - b.r) < 0.01 and math.abs(a.g - b.g) < 0.01 and math.abs(a.b - b.b) < 0.01
end

-- Значок для слота (кнопки или колеса): свой значок или значок места
function Style.ResolveIcon(item, node)
    if item and item.icon and item.icon ~= "" then return item.icon end
    if node and node.icon and node.icon ~= "" then return node.icon end
    return Style.MISSING_ICON
end

-- Раскрасить плитку, созданную из шаблона AbyssQuest_Tile.
-- look  = { icon = путь, color = {r,g,b}, tint = true/false }
-- state = { size = px, available = bool, blocked = bool, hover = bool,
--           pressed = bool, selected = bool, label = текст или nil }
function Style.PaintTile(tile, look, state)
    state = state or {}
    local size = state.size or tile:GetWidth()
    if state.size then tile:SetDimensions(size, size) end

    local available = state.available ~= false
    local color = available and (look.color or Style.DEFAULT_COLOR) or GREY

    -- Заливка: цвет, «утопленный» в тёмный фон. Без градиентов: игра сбрасывает
    -- цвета градиента при смене размера, и плитка становилась наполовину белой.
    local fillT = 0.24
    if state.hover or state.selected then fillT = 0.34 end
    if state.pressed then fillT = 0.14 end
    local fr, fg, fb = Style.Darken(color, fillT)
    tile:GetNamedChild("Fill"):SetColor(fr, fg, fb, 0.94)

    -- Светлая верхняя половина и тёмная нижняя — мягкий объём
    local shine = tile:GetNamedChild("Shine")
    shine:SetHeight(zo_floor(size * 0.5))
    shine:SetColor(1, 1, 1, state.pressed and 0.02 or 0.06)
    local shade = tile:GetNamedChild("Shade")
    shade:SetHeight(zo_floor(size * 0.5))
    shade:SetColor(0, 0, 0, 0.22)

    -- Рамка: 1 px, у крупных плиток 2 px
    local thickness = size >= 72 and 2 or 1
    local br, bg, bb = Style.Lighten(color, (state.hover or state.selected) and 0.35 or 0.08)
    local borderAlpha = available and ((state.hover or state.selected) and 1 or 0.78) or 0.45
    for _, side in ipairs({ "BorderTop", "BorderBottom" }) do
        local line = tile:GetNamedChild(side)
        line:SetHeight(thickness)
        line:SetColor(br, bg, bb, borderAlpha)
    end
    for _, side in ipairs({ "BorderLeft", "BorderRight" }) do
        local line = tile:GetNamedChild(side)
        line:SetWidth(thickness)
        line:SetColor(br, bg, bb, borderAlpha)
    end

    -- Мягкое свечение при наведении
    local glow = tile:GetNamedChild("Glow")
    glow:SetDimensions(size * 2, size * 2)
    glow:SetColor(color.r, color.g, color.b, 1)
    glow:SetAlpha((state.hover or state.selected) and available and 0.55 or 0)

    -- Значок
    local icon = tile:GetNamedChild("Icon")
    local iconSize = zo_floor(size * (look.iconScale or 0.70))
    icon:SetDimensions(iconSize, iconSize)
    if look.icon then
        icon:SetHidden(false)
        icon:SetTexture(look.icon)
    else
        icon:SetHidden(true)
    end
    if look.tint and available then
        local tr, tg, tb = Style.Lighten(color, 0.30)
        icon:SetColor(tr, tg, tb, 1)
    else
        icon:SetColor(1, 1, 1, 1)
    end
    icon:SetDesaturation(available and 0 or 1)
    icon:SetAlpha(available and 1 or 0.55)

    -- Подпись под плиткой
    local label = tile:GetNamedChild("Label")
    if state.label and state.label ~= "" then
        label:SetHidden(false)
        label:SetText(state.label)
        label:SetWidth(zo_max(size + 40, 90))
    else
        label:SetHidden(true)
    end

    -- Временно недоступно (бой, перезарядка): чуть приглушаем всю плитку
    tile:SetAlpha(state.blocked and 0.6 or 1)
end

---------------------------------------------------------------------------
-- Цветовая тема аддона (3.2.0)
--
-- Все цвета интерфейса берутся из общих таблиц ниже. Файлы аддона держат на
-- них ссылки (local GOLD = Style.GOLD и т. п.), поэтому при смене темы таблицы
-- меняются на месте — и следующая перерисовка уже в новых цветах.
-- Тексты и линии из AbyssQuest.xml отмечаются ролью (Style.Themed) и
-- перекрашиваются сразу; фон панелей и окон — оттенок и прозрачность.
---------------------------------------------------------------------------
Style.THEME_DEFAULTS = {
    accent        = { r = 0.36, g = 0.76, b = 0.91 },  -- акцент: вкладки, перемещение, выделение
    title         = { r = 0.90, g = 0.85, b = 0.66 },  -- заголовки и главное задание
    text          = { r = 1.00, g = 1.00, b = 1.00 },  -- основной текст
    muted         = { r = 0.60, g = 0.60, b = 0.60 },  -- второстепенный текст
    panelTint     = { r = 1.00, g = 1.00, b = 1.00 },  -- оттенок фона панелей и окон
    panelAlpha    = 1.00,                              -- непрозрачность панелей у карты
    windowAlpha   = 1.00,                              -- непрозрачность окон аддона
    rowAlpha      = 0.75,                              -- непрозрачность карточек в списках
    quest         = { r = 0.86, g = 0.74, b = 0.42 },  -- полоска заданий
    pursuit       = { r = 0.95, g = 0.62, b = 0.25 },  -- полоска Золотых стремлений
    tome          = { r = 0.60, g = 0.62, b = 0.98 },  -- полоска Фолиантов
    trackerBg     = { r = 0.03, g = 0.03, b = 0.04 },  -- фон панели заданий на экране
    trackerBgAlpha       = 0.55,                       -- подробная панель
    trackerSimpleBgAlpha = 0.00,                       -- простая панель
    trackerCardAlpha     = 0.55,                       -- карточки заданий (подробная панель)
    trackerAlpha         = 1.00,                       -- непрозрачность текста и значков панели
    buttonsAlpha         = 1.00,                       -- непрозрачность кнопок на экране
}

-- Готовые темы: только то, что отличается от темы по умолчанию
Style.THEME_PRESETS = {
    { key = "default" },
    { key = "gold",    accent = { r = 0.90, g = 0.71, b = 0.31 }, title = { r = 0.96, g = 0.88, b = 0.62 },
                       panelTint = { r = 1.00, g = 0.93, b = 0.82 } },
    { key = "emerald", accent = { r = 0.33, g = 0.82, b = 0.55 }, title = { r = 0.78, g = 0.92, b = 0.74 },
                       panelTint = { r = 0.80, g = 1.00, b = 0.88 }, quest = { r = 0.45, g = 0.82, b = 0.55 } },
    { key = "violet",  accent = { r = 0.70, g = 0.52, b = 0.98 }, title = { r = 0.88, g = 0.80, b = 0.98 },
                       panelTint = { r = 0.88, g = 0.82, b = 1.00 }, quest = { r = 0.76, g = 0.62, b = 0.98 } },
    { key = "crimson", accent = { r = 0.94, g = 0.36, b = 0.36 }, title = { r = 0.96, g = 0.80, b = 0.70 },
                       panelTint = { r = 1.00, g = 0.82, b = 0.80 }, quest = { r = 0.92, g = 0.48, b = 0.40 } },
    { key = "mono",    accent = { r = 0.85, g = 0.85, b = 0.85 }, title = { r = 0.95, g = 0.95, b = 0.95 },
                       muted = { r = 0.55, g = 0.55, b = 0.55 }, panelTint = { r = 0.75, g = 0.75, b = 0.75 },
                       quest = { r = 0.80, g = 0.80, b = 0.80 }, pursuit = { r = 0.65, g = 0.65, b = 0.65 },
                       tome = { r = 0.55, g = 0.55, b = 0.55 } },
    { key = "glass",   panelAlpha = 0.55, windowAlpha = 0.75, rowAlpha = 0.45,
                       trackerBgAlpha = 0.25, trackerCardAlpha = 0.30 },
}

-- Общие цвета ({ r, g, b } по номерам — так их уже используют файлы аддона)
Style.GOLD    = { 0.90, 0.85, 0.66 }  -- заголовки
Style.CAPTION = { 0.77, 0.76, 0.62 }  -- подписи разделов (чуть темнее заголовков)
Style.ICE     = { 0.36, 0.76, 0.91 }  -- акцент
Style.TEXT    = { 1.00, 1.00, 1.00 }  -- основной текст
Style.INFO    = { 0.60, 0.60, 0.60 }  -- второстепенный текст
Style.DETAIL  = { 0.78, 0.78, 0.78 }  -- условия заданий
Style.MUTED   = { 0.54, 0.54, 0.54 }  -- неактивное
Style.GROUP   = { 0.56, 0.72, 0.79 }  -- подзаголовки (локация, кампания)
-- То же в виде { r, g, b } по именам
Style.ICE_RGB  = { r = 0.36, g = 0.76, b = 0.91 }
Style.GOLD_RGB = { r = 0.90, g = 0.85, b = 0.66 }
Style.KIND_COLORS = {
    q = { r = 0.86, g = 0.74, b = 0.42 },
    p = { r = 0.95, g = 0.62, b = 0.25 },
    t = { r = 0.60, g = 0.62, b = 0.98 },
}

-- Текущие значения темы (до загрузки настроек — по умолчанию)
Style.T = {}

local function CopyRGB(c)
    return { r = c.r, g = c.g, b = c.b }
end

local function SetArray(target, r, g, b)
    target[1], target[2], target[3] = r, g, b
end

local function SetRGB(target, c)
    target.r, target.g, target.b = c.r, c.g, c.b
end

-- Сохранённая тема: sv.theme хранит только изменённые значения
function Style.GetThemeStore()
    local sv = AbyssQuest.sv
    if not sv then return nil end
    if type(sv.theme) ~= "table" then sv.theme = {} end
    return sv.theme
end

function Style.GetThemeValue(key)
    local store = Style.GetThemeStore()
    local value = store and store[key]
    if value == nil then value = Style.THEME_DEFAULTS[key] end
    return value
end

-- Для LibAddonMenu: цвет как r, g, b
function Style.GetThemeColor(key)
    local c = Style.GetThemeValue(key)
    return c.r, c.g, c.b
end

function Style.SetThemeValue(key, value)
    local store = Style.GetThemeStore()
    if not store then return end
    if type(value) == "table" then value = CopyRGB(value) end
    store[key] = value
    Style.ApplyTheme()
end

function Style.SetThemeColor(key, r, g, b)
    Style.SetThemeValue(key, { r = r, g = g, b = b })
end

function Style.ResetTheme()
    local sv = AbyssQuest.sv
    if sv then sv.theme = {} end
    Style.ApplyTheme()
end

function Style.ApplyPreset(key)
    local sv = AbyssQuest.sv
    if not sv then return end
    sv.theme = {}
    for _, preset in ipairs(Style.THEME_PRESETS) do
        if preset.key == key then
            for name, value in pairs(preset) do
                if name ~= "key" then sv.theme[name] = type(value) == "table" and CopyRGB(value) or value end
            end
        end
    end
    sv.themePreset = key
    Style.ApplyTheme()
end

-- Непрозрачность карточки строки (наведение — плотнее)
function Style.RowAlpha(hover)
    local alpha = Style.T.rowAlpha or 0.75
    if hover then return zo_min(1, alpha + 0.2) end
    return alpha
end

---------------------------------------------------------------------------
-- Элементы из AbyssQuest.xml с ролью: перекрашиваются при смене темы.
-- Роль задаётся в XML: <OnInitialized>AbyssQuest.Style.Themed(self, "title")</OnInitialized>
---------------------------------------------------------------------------
local themed = setmetatable({}, { __mode = "k" })

local ROLE_COLORS = {
    title   = Style.GOLD,
    caption = Style.CAPTION,
    text    = Style.TEXT,
    info    = Style.INFO,
    detail  = Style.DETAIL,
    accent  = Style.ICE,
    group   = Style.GROUP,
}

local function PaintThemed(control, spec)
    if spec.role == "panel" or spec.role == "window" then
        local tint = Style.T.panelTint or Style.THEME_DEFAULTS.panelTint
        local alpha = spec.role == "panel" and (Style.T.panelAlpha or 1) or (Style.T.windowAlpha or 1)
        if control.SetCenterColor then control:SetCenterColor(tint.r, tint.g, tint.b, alpha) end
        if control.SetEdgeColor then control:SetEdgeColor(tint.r, tint.g, tint.b, alpha) end
        return
    end
    local color = ROLE_COLORS[spec.role]
    if color and control.SetColor then
        control:SetColor(color[1], color[2], color[3], spec.alpha or 1)
    end
end

function Style.Themed(control, role, alpha)
    local spec = { role = role, alpha = alpha }
    themed[control] = spec
    PaintThemed(control, spec)
end

---------------------------------------------------------------------------
-- Применить тему: обновить общие цвета, перекрасить отмеченные элементы
-- и перерисовать всё, что рисуется из кода
---------------------------------------------------------------------------
local function Mix(a, b, t)
    return a + (b - a) * t
end

function Style.ApplyTheme()
    local T = Style.T
    for key, default in pairs(Style.THEME_DEFAULTS) do
        local value = Style.GetThemeValue(key)
        if value == nil then value = default end
        T[key] = type(value) == "table" and CopyRGB(value) or value
    end

    local accent, title, text, muted = T.accent, T.title, T.text, T.muted
    SetArray(Style.GOLD, title.r, title.g, title.b)
    SetArray(Style.CAPTION, title.r * 0.86, title.g * 0.89, title.b * 0.94)
    SetArray(Style.ICE, accent.r, accent.g, accent.b)
    SetArray(Style.TEXT, text.r, text.g, text.b)
    SetArray(Style.INFO, muted.r, muted.g, muted.b)
    SetArray(Style.DETAIL, Mix(muted.r, text.r, 0.45), Mix(muted.g, text.g, 0.45), Mix(muted.b, text.b, 0.45))
    SetArray(Style.MUTED, muted.r * 0.9, muted.g * 0.9, muted.b * 0.9)
    SetArray(Style.GROUP, Mix(accent.r, muted.r, 0.45), Mix(accent.g, muted.g, 0.45), Mix(accent.b, muted.b, 0.45))
    SetRGB(Style.ICE_RGB, accent)
    SetRGB(Style.GOLD_RGB, title)
    SetRGB(Style.KIND_COLORS.q, T.quest)
    SetRGB(Style.KIND_COLORS.p, T.pursuit)
    SetRGB(Style.KIND_COLORS.t, T.tome)
    Style.DEFAULT_COLOR = Style.PALETTE[1]

    for control, spec in pairs(themed) do
        PaintThemed(control, spec)
    end

    -- Всё, что красится из кода (до загрузки аддона ничего ещё нет)
    local QTM = AbyssQuest
    if not QTM.sv then return end
    if QTM.MapPanel and QTM.MapPanel.OnThemeChanged then QTM.MapPanel:OnThemeChanged() end
    if QTM.InfoPanel and QTM.InfoPanel.OnThemeChanged then QTM.InfoPanel:OnThemeChanged() end
    if QTM.QuestTracker and QTM.QuestTracker.ApplyTheme then QTM.QuestTracker:ApplyTheme() end
    if QTM.ZoomBar and QTM.ZoomBar.ApplyTheme then QTM.ZoomBar:ApplyTheme() end
    if QTM.QuestDrag and QTM.QuestDrag.ApplyTheme then QTM.QuestDrag:ApplyTheme() end
    if QTM.Buttons and QTM.Buttons.container then QTM.Buttons:UpdateVisibility() end
    if QTM.Preview and QTM.Preview.Refresh then QTM.Preview:Refresh() end
end

-- Значения по умолчанию до загрузки настроек
Style.ApplyTheme()

-- Цвет для вставки в текст: "|c" .. Style.Hex(Style.ICE) .. "текст|r"
function Style.Hex(color)
    return string.format("%02X%02X%02X",
        zo_floor(color[1] * 255 + 0.5), zo_floor(color[2] * 255 + 0.5), zo_floor(color[3] * 255 + 0.5))
end
