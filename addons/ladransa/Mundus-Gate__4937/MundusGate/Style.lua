-- Общий стиль «плитки»: квадрат с цветной заливкой, тонкой рамкой и значком.
-- Используется для кнопок на экране, колеса, превью в редакторах и сетки значков.
-- Палитра тёмная и плоская, поэтому хорошо смотрится и со стандартным
-- интерфейсом, и с тёмными темами вроде Dark UI.
local QTM = MundusGate

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

-- Раскрасить плитку, созданную из шаблона MundusGate_Tile.
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
