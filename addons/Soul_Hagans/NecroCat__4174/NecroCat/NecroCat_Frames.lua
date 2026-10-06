-- =========================================================
-- NecroCat: Unit Frames Module (Фреймы игрока, цели и группы)
-- =========================================================

if not NecroCat then NecroCat = {} end
NecroCat.Frames = NecroCat.Frames or {}
local Frames = NecroCat.Frames

local defaultFramesSV = {
    playerEnabled     = false,
    hideDefaultBars   = true, -- Скрывать стандартные полосы игры
    layoutTemplate    = 1, -- 1: Пирамида, 2: Вертикально, 3: Горизонтально, 4: Раздельно
    frameStyle        = 1, -- 1: Минимал (По умолчанию), 2: Вампирская готика
    styleColor        = 1, -- Цветовая схема стиля (1: Изумруд, 2: Сапфир)
    frameScale        = 100, -- Общий масштаб фреймов в % (70-150)
    spacingOffsetX    = 0,   -- Смещение зазора X (0 = авторский по стилю)
    spacingOffsetY    = 0,   -- Смещение зазора Y (0 = авторский по стилю)
    healthBarTexture  = 1, -- Текстура полосы здоровья (1 = Стандартная)
    magickaBarTexture = 1, -- Текстура полосы магии
    staminaBarTexture = 1, -- Текстура полосы стамины
    textMode          = 1, -- 1: Сплит по краям, 2: По центру (все), 3: По центру (цифры), 4: По центру (%), 5: Без текста
    healthCenterFill  = false,
    playerWidth       = 340,
    playerHeight      = 32,
    fontSize          = 22,
    showShieldText    = true,
    showTraumaText    = true,
    playerLeft        = 450,
    playerTop         = 650,
    magLeft           = 347,
    magTop            = 674,
    stamLeft          = 553,
    stamTop           = 674,
    siegeLeft         = 450,
    siegeTop          = 580,
    playerLocked      = true,
    testShield        = false,
    testTrauma        = false,
    testSiege         = false, -- Тестовый режим осадного орудия
    -- Настройки осадки
    siegeEnabled       = true,
    siegeStyle         = 1,     -- 1: Без рамки, 2: Осадный арт 1
    siegeStyleColor    = 1,     -- Расцветка стиля осадки (1: Зеленый, 2: Синий и т.д.)
    siegeWidth         = 300,
    siegeHeight        = 20,
    siegeOffsetY       = -36,
    siegeFontSize      = 13,
    siegeTitleFontSize = 14,
    siegeLabelOffsetY  = 3,  -- Центровка цифр по вертикали
    siegeLabelPadX     = 8,  -- Отступ цифр от боковых краёв
    siegeTextMode      = 1,  -- 1: Сплит, 2: Центр (все), 3: Центр (цифры), 4: Центр (%), 5: Без текста
    siegeBarTexture    = 1,
    siegeTextColor     = { 1.0, 1.0, 1.0, 1.0 },
    -- Цвета текста
    textColor         = { 1.0, 1.0, 1.0, 1.0 },
    shieldTextColor   = { 0.25, 0.85, 1.0, 1.0 },
    traumaTextColor   = { 0.85, 0.35, 0.75, 1.0 },
    -- Цвета полос
    healthColor       = { 0.76, 0.12, 0.12, 1.0 },
    magickaColor      = { 0.12, 0.38, 0.78, 1.0 },
    staminaColor      = { 0.14, 0.58, 0.22, 1.0 },
    shieldColor       = { 0.25, 0.75, 0.95, 0.55 },
    traumaColor       = { 0.58, 0.12, 0.48, 0.75 },
    mountColor        = { 0.08, 0.38, 0.15, 1.0 },
    siegeColor        = { 0.60, 0.62, 0.68, 1.0 },
}

-- =========================================================
-- ТАБЛИЦА СТИЛЕЙ ОФОРМЛЕНИЯ ФРЕЙМОВ
-- =========================================================
Frames.STYLES = {

    -- -----------------------------------------------------
    -- СТИЛЬ 1: ПО УМОЛЧАНИЮ (МИНИМАЛИЗМ БЕЗ РАМОК)
    -- -----------------------------------------------------
    [1] = {
        id               = 1,
        name             = "SI_NC_LAM_STYLE_DEFAULT",
        supportedLayouts = { 1, 2, 3, 4 }, -- Доступен во всех раскладках
        hasArt           = false,          -- Без текстур
        spacingY         = 4,
        health = {
            insetX       = 1,
            insetY       = 1,
            labelPadX    = 8,
            labelOffsetY  = 4,
        },
    },

-- -----------------------------------------------------
    -- СТИЛЬ 2: ВАМПИРСКАЯ ГОТИКА
    -- -----------------------------------------------------
    [2] = {
        id               = 2,
        name             = "SI_NC_LAM_STYLE_VAMPIRE",
        supportedLayouts = { 1, 2, 3, 4 }, -- Доступен во всех раскладках
        hasArt           = true,          -- Стиль использует арт-рамки

        -- Комплекты картинок для этого стиля:
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                hp   = "NecroCat/imgs/frames/hp_backplate.dds",
                mag  = "NecroCat/imgs/frames/two_backplate.dds",
                stam = "NecroCat/imgs/frames/two_backplate.dds",
            },
        },

        -- 1. ЗАЗОРЫ МЕЖДУ ПОЛОСКАМИ (в зависимости от раскладки на экране):
        layouts = {
            -- В Пирамиде: spacingX = зазор между маной и стаминой, spacingY = отступ от ХП вниз
            [1] = { spacingX = 48, spacingY = 14 }, 

            -- В Вертикали (столбик): spacingY = зазор между этажами ХП -> Мана -> Стамина
            [2] = { spacingY = 9 }, 

            -- В Горизонтали (в ряд): spacingX = зазор по бокам от ХП до Магии и Стамины
            [3] = { spacingX = 29, spacingY = -3 }, 
        },

        -- 2. НАСТРОЙКИ ЗДОРОВЬЯ (Только чертеж и размеры):
        health = {
            artW         = 410, -- Ширина картинки рамки
            artH         = 140, -- Высота картинки рамки
            artOffsetX   = 0,   -- Сдвиг рамки по горизонтали
            artOffsetY   = -19, -- Сдвиг рамки по вертикали
            barW         = 330, -- Длина красной полосы
            barH         = 43,  -- Толщина красной полосы
            insetX       = 0,   -- Отступ крови от боковых когтей
            insetY       = 3,   -- Отступ крови сверху и снизу
            labelPadX    = 4,   -- Отступ белых цифр от краев
            labelOffsetY = 4,   -- Положение цифр по высоте
        },

        -- 3. НАСТРОЙКИ МАГИИ (Только чертеж и размеры):
        magicka = {
            artW         = 380, 
            artH         = 132, 
            artOffsetX   = 0, 
            artOffsetY   = 7,
            barW         = 330, 
            barH         = 43, 
            insetX       = 0,   
            insetY       = 3,   
            labelPadX    = 8,   
            labelOffsetY = 4,   
        },

        -- 4. НАСТРОЙКИ СТАМИНЫ (Только чертеж и размеры):
        stamina = {
            artW         = 380, 
            artH         = 132, 
            artOffsetX   = 0, 
            artOffsetY   = 7,
            barW         = 330, 
            barH         = 43,  
            insetX       = 0,   
            insetY       = 3,  
            labelPadX    = 8,  
            labelOffsetY = 4,  
        },
    },

-- -----------------------------------------------------
    -- СТИЛЬ 3: НЕКРОКОШКА
    -- -----------------------------------------------------
    [3] = {
        id               = 3,
        name             = "SI_NC_LAM_STYLE_CAT",
        supportedLayouts = { 1, 2, 3, 4 }, -- Доступен во всех раскладках
        hasArt           = true,

        -- Варианты расцветки для этого стиля:
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_GREEN",
                hp   = "NecroCat/imgs/frames/hp_backplate_cat_green.dds",
                mag  = "NecroCat/imgs/frames/two_backplate_cat_green.dds",
                stam = "NecroCat/imgs/frames/two_backplate_cat_green.dds",
            },
            [2] = {
                name = "SI_NC_LAM_COLOR_BLUE",
                hp   = "NecroCat/imgs/frames/hp_backplate_cat_blue.dds",
                mag  = "NecroCat/imgs/frames/two_backplate_cat_blue.dds",
                stam = "NecroCat/imgs/frames/two_backplate_cat_blue.dds",
            },
        },
        

        -- 1. ЗАЗОРЫ МЕЖДУ ПОЛОСКАМИ (в зависимости от раскладки на экране):
        layouts = {
            -- В Пирамиде: spacingX = зазор между маной и стаминой, spacingY = отступ от ХП вниз
            [1] = { spacingX = 56, spacingY = 2 }, 

            -- В Вертикали (столбик): spacingY = зазор между этажами ХП -> Мана -> Стамина
            [2] = { spacingY = 0 }, 

            -- В Горизонтали (в ряд): spacingX = зазор по бокам от ХП до Магии и Стамины
            [3] = { spacingX = 28, spacingY = 0 }, 
        },

        -- 2. НАСТРОЙКИ ЗДОРОВЬЯ (Только чертеж и размеры):
        health = {
            artW         = 415, -- Ширина картинки рамки
            artH         = 130, -- Высота картинки рамки
            artOffsetX   = 0,   -- Сдвиг рамки по горизонтали
            artOffsetY   = -22, -- Сдвиг рамки по вертикали
            barW         = 330, -- Длина красной полосы
            barH         = 43,  -- Толщина красной полосы
            insetX       = 0,   -- Отступ крови от боковых когтей
            insetY       = 5,   -- Отступ крови сверху и снизу
            labelPadX    = 4,   -- Отступ белых цифр от краев
            labelOffsetY = 4,   -- Положение цифр по высоте
        },

        -- 3. НАСТРОЙКИ МАГИИ (Только чертеж и размеры):
        magicka = {
            artW         = 395, 
            artH         = 132, 
            artOffsetX   = 0, 
            artOffsetY   = -8,
            barW         = 330, 
            barH         = 39, 
            insetX       = 0,   
            insetY       = 3,   
            labelPadX    = 8,   
            labelOffsetY = 4,   
        },

        -- 4. НАСТРОЙКИ СТАМИНЫ (Только чертеж и размеры):
        stamina = {
            artW         = 395, 
            artH         = 132, 
            artOffsetX   = 0, 
            artOffsetY   = -8,
            barW         = 330, 
            barH         = 39, 
            insetX       = 0,   
            insetY       = 3,   
            labelPadX    = 8,   
            labelOffsetY = 4,   
        },
    },

-- -----------------------------------------------------
    -- СТИЛЬ 4: ЛЕТУЧИЕ МЫШИ
    -- -----------------------------------------------------
    [4] = {
        id               = 4,
        name             = "SI_NC_LAM_STYLE_BAT",
        supportedLayouts = { 1, 2, 3, 4 }, -- Доступен во всех раскладках
        hasArt           = true,          -- Стиль использует арт-рамки

        -- Комплекты картинок для этого стиля:
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT", -- Базовый комплект
                hp   = "NecroCat/imgs/frames/hp_backplate_bat.dds",
                mag  = "NecroCat/imgs/frames/two_backplate_bat.dds",
                stam = "NecroCat/imgs/frames/two_backplate_bat.dds",
            },
        },

        -- 1. ЗАЗОРЫ МЕЖДУ ПОЛОСКАМИ (в зависимости от раскладки на экране):
        layouts = {
            -- В Пирамиде: spacingX = зазор между маной и стаминой, spacingY = отступ от ХП вниз
            [1] = { spacingX = 39, spacingY = 23 }, 

            -- В Вертикали (столбик): spacingY = зазор между этажами ХП -> Мана -> Стамина
            [2] = { spacingY = 9 }, 

            -- В Горизонтали (в ряд): spacingX = зазор по бокам от ХП до Магии и Стамины
            [3] = { spacingX = 80, spacingY = 0 }, 
        },

        -- 2. НАСТРОЙКИ ЗДОРОВЬЯ (Только чертеж и размеры):
        health = {
            artW         = 490, -- Ширина картинки рамки
            artH         = 144, -- Высота картинки рамки
            artOffsetX   = 0,   -- Сдвиг рамки по горизонтали
            artOffsetY   = -5,  -- Сдвиг рамки по вертикали
            barW         = 330, -- Длина красной полосы
            barH         = 43,  -- Толщина красной полосы
            insetX       = 0,   -- Отступ крови от боковых когтей
            insetY       = 3,   -- Отступ крови сверху и снизу
            labelPadX    = 4,   -- Отступ белых цифр от краев
            labelOffsetY = 4,   -- Положение цифр по высоте
        },

        -- 3. НАСТРОЙКИ МАГИИ (Только чертеж и размеры):
        magicka = {
            artW         = 375, 
            artH         = 120, 
            artOffsetX   = -2, 
            artOffsetY   = 1,
            barW         = 335, 
            barH         = 44, 
            insetX       = 0,   
            insetY       = 3,   
            labelPadX    = 8,   
            labelOffsetY = 4,   
        },

        -- 4. НАСТРОЙКИ СТАМИНЫ (Только чертеж и размеры):
        stamina = {
            artW         = 375, 
            artH         = 120, 
            artOffsetX   = -2, 
            artOffsetY   = 1,
            barW         = 335, 
            barH         = 44, 
            insetX       = 0,   
            insetY       = 3,   
            labelPadX    = 8,   
            labelOffsetY = 4,   
        },
    },
    
}

-- =========================================================
-- ТАБЛИЦА СТИЛЕЙ ОСАДНОГО ОРУДИЯ
-- =========================================================
Frames.SIEGE_STYLES = {
    -- 1. Без рамки (Минимализм)
    [1] = {
        id     = 1,
        name   = "SI_NC_LAM_STYLE_DEFAULT",
        hasArt = false,
    },

    -- 2. Вампирская готика
    [2] = {
        id         = 2,
        name       = "SI_NC_LAM_STYLE_VAMPIRE",
        hasArt     = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/two_backplate.dds",
            },
        },
        artW       = 380,
        artH       = 132,
        artOffsetX = 0,
        artOffsetY = 7,
        barW       = 330,
        barH       = 43,
        insetX     = 0,
        insetY     = 3,
    },
    
    -- 3. Некрокошка
    [3] = {
        id         = 3,
        name       = "SI_NC_LAM_STYLE_CAT",
        hasArt     = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_GREEN",
                art  = "NecroCat/imgs/frames/two_backplate_cat_green.dds",
            },
            [2] = {
                name = "SI_NC_LAM_COLOR_BLUE",
                art  = "NecroCat/imgs/frames/two_backplate_cat_blue.dds",
            },
        },
        artW       = 395,
        artH       = 132,
        artOffsetX = 0,
        artOffsetY = -8,
        barW       = 330,
        barH       = 39,
        insetX     = 0,
        insetY     = 3,
    },

    -- 4. Летучие мыши
    [4] = {
        id         = 4,
        name       = "SI_NC_LAM_STYLE_BAT",
        hasArt     = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/two_backplate_bat.dds",
            },
        },
        artW       = 375,
        artH       = 120,
        artOffsetX = -2,
        artOffsetY = 1,
        barW       = 335,
        barH       = 44,
        insetX     = 0,
        insetY     = 3,
    },
    -- 5. Обычная
    [5] = {
        id         = 5,
        name       = "SI_NC_LAM_STYLE_SIEGE",
        hasArt     = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/siege_backplate.dds",
            },
        },
        artW       = 360,
        artH       = 56,
        artOffsetX = 0,
        artOffsetY = 1,
        barW       = 335,
        barH       = 44,
        insetX     = 0,
        insetY     = 3,
    },
    
}

function Frames.GetSiegeStyleChoices()
    local names, ids = {}, {}
    for id = 1, #Frames.SIEGE_STYLES do
        local s = Frames.SIEGE_STYLES[id]
        if s then
            local str = GetString(_G[s.name] or s.name)
            table.insert(names, str)
            table.insert(ids, id)
        end
    end
    return names, ids
end

-- =========================================================
-- БИБЛИОТЕКА ТЕКСТУР ЗАПОЛНЕНИЯ ПОЛОС
-- =========================================================
Frames.BAR_TEXTURES = {
    -- 1. Стандартная гладкая заливка игры (работает прямо сейчас)
    [1] = {
        id   = 1,
        name = "SI_NC_LAM_TEX_DEFAULT",
        path = "EsoUI/Art/Miscellaneous/progressbar_genericfiller.dds",
    },
    [2] = {
        id   = 2,
        name = "SI_NC_LAM_TEX_NECRO",
        path = "NecroCat/imgs/frames/necrofactura.dds",
    },
    [3] = {
        id   = 3,
        name = "SI_NC_LAM_TEX_BAT",
        path = "NecroCat/imgs/frames/batfactura.dds",
    },
    [4] = {
        id   = 4,
        name = "SI_NC_LAM_TEX_GRASS",
        path = "NecroCat/imgs/frames/Grass.dds",
    },
    [5] = {
        id   = 5,
        name = "SI_NC_LAM_TEX_GREY",
        path = "NecroCat/imgs/frames/Grey.dds",
    },
    [6] = {
        id   = 6,
        name = "SI_NC_LAM_TEX_MARBLE",
        path = "NecroCat/imgs/frames/Marble.dds",
    },
    [7] = {
        id   = 7,
        name = "SI_NC_LAM_TEX_ORNAMENT",
        path = "NecroCat/imgs/frames/Ornament.dds",
    },
    [8] = {
        id   = 8,
        name = "SI_NC_LAM_TEX_FABRIC",
        path = "NecroCat/imgs/frames/Fabric.dds",
    },
    [9] = {
        id   = 9,
        name = "SI_NC_LAM_TEX_ROAD",
        path = "NecroCat/imgs/frames/Road.dds",
    },
    [10] = {
        id   = 10,
        name = "SI_NC_LAM_TEX_ROCK",
        path = "NecroCat/imgs/frames/Rock.dds",
    },
}

-- Вспомогательная функция для получения списков текстур в меню
function Frames.GetBarTextureChoices()
    local names, ids = {}, {}
    for id = 1, #Frames.BAR_TEXTURES do
        local tex = Frames.BAR_TEXTURES[id]
        if tex then
            local str = GetString(_G[tex.name] or tex.name)
            table.insert(names, str)
            table.insert(ids, id)
        end
    end
    return names, ids
end

local function IsStyleSupported(styleId, layoutId)
    local style = Frames.STYLES[styleId]
    if not style or not style.supportedLayouts then return true end
    for _, id in ipairs(style.supportedLayouts) do
        if id == layoutId then return true end
    end
    return false
end

local function GetAvailableStylesForLayout(layoutId)
    local names, ids = {}, {}
    for id = 1, #Frames.STYLES do
        local style = Frames.STYLES[id]
        if style and IsStyleSupported(id, layoutId) then
            local str = GetString(_G[style.name] or style.name)
            table.insert(names, str)
            table.insert(ids, id)
        end
    end
    return names, ids
end

-- 1. ФОРМАТИРОВАНИЕ ЧИСЕЛ
local function FormatValueNumber(value)
    if not value then return "0" end
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 10000 then
        return string.format("%.1fk", value / 1000)
    else
        return ZO_LocalizeDecimalNumber(value)
    end
end

local function RgbToHex(c)
    if not c then return "ffffff" end
    local r = zo_clamp(math.floor((c[1] or 1) * 255), 0, 255)
    local g = zo_clamp(math.floor((c[2] or 1) * 255), 0, 255)
    local b = zo_clamp(math.floor((c[3] or 1) * 255), 0, 255)
    return string.format("%02x%02x%02x", r, g, b)
end

-- 2. ПРИМЕНЕНИЕ ЦВЕТОВ
function Frames.ApplyColors()
    if not Frames.PlayerHealthBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV

    local hc = sv.healthColor or defaultFramesSV.healthColor
    Frames.PlayerHealthBar:SetColor(hc[1], hc[2], hc[3], hc[4] or 1)

    local sc = sv.shieldColor or defaultFramesSV.shieldColor
    Frames.PlayerShieldBar:SetColor(sc[1], sc[2], sc[3], sc[4] or 0.55)

    local trc = sv.traumaColor or defaultFramesSV.traumaColor
    if Frames.PlayerTraumaBar then
        Frames.PlayerTraumaBar:SetColor(trc[1], trc[2], trc[3], trc[4] or 0.75)
    end

    local mc = sv.magickaColor or defaultFramesSV.magickaColor
    Frames.PlayerMagBar:SetColor(mc[1], mc[2], mc[3], mc[4] or 1)

    local stc = sv.staminaColor or defaultFramesSV.staminaColor
    Frames.PlayerStamBar:SetColor(stc[1], stc[2], stc[3], stc[4] or 1)

    if Frames.PlayerMountBar then
        local mc = sv.mountColor or defaultFramesSV.mountColor or { 0.08, 0.38, 0.15, 1.0 }
        Frames.PlayerMountBar:SetColor(mc[1], mc[2], mc[3], mc[4] or 1)
    end

    if Frames.PlayerSiegeBar then
        local sgc = sv.siegeColor or defaultFramesSV.siegeColor or { 0.60, 0.62, 0.68, 1.0 }
        Frames.PlayerSiegeBar:SetColor(sgc[1], sgc[2], sgc[3], sgc[4] or 1)
    end

    local stc = sv.siegeTextColor or defaultFramesSV.siegeTextColor or { 1.0, 1.0, 1.0, 1.0 }
    if Frames.SiegeTitleLabel then
        Frames.SiegeTitleLabel:SetColor(stc[1], stc[2], stc[3], stc[4] or 1)
    end
    if Frames.SiegeLeftLabel then
        Frames.SiegeLeftLabel:SetColor(stc[1], stc[2], stc[3], stc[4] or 1)
    end
    if Frames.SiegeRightLabel then
        Frames.SiegeRightLabel:SetColor(stc[1], stc[2], stc[3], stc[4] or 1)
    end

    local tc = sv.textColor or defaultFramesSV.textColor
    if Frames.PlayerHealthLeftLabel then
        Frames.PlayerHealthLeftLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.PlayerHealthRightLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.PlayerMagLeftLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.PlayerMagRightLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.PlayerStamLeftLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.PlayerStamRightLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
    end
end

-- Применение выбранных текстур заполнения к полосам
function Frames.ApplyBarTextures()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV

    local function ApplyTex(bar, texId)
        if not bar then return end
        local id = texId or 1
        local cfg = Frames.BAR_TEXTURES[id]
        -- Ставим кастомную текстуру только если выбран ID больше 1
        if cfg and cfg.path and id > 1 then
            bar:SetTexture(cfg.path)
        else
            bar:SetTexture(nil) -- Возвращаем родную гладкую заливку ESO
        end
    end

    ApplyTex(Frames.PlayerHealthBar, sv.healthBarTexture)
    ApplyTex(Frames.PlayerMagBar, sv.magickaBarTexture)
    ApplyTex(Frames.PlayerStamBar, sv.staminaBarTexture)
    ApplyTex(Frames.PlayerSiegeBar, sv.siegeBarTexture)
end

-- Управление видимостью стандартных полос ESO
function Frames.UpdateDefaultBarsVisibility()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV
    local shouldHide = (sv.playerEnabled ~= false) and (sv.hideDefaultBars ~= false)

    -- 1. Полное отключение через системный фрагмент сцены
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        if PLAYER_ATTRIBUTE_BARS_FRAGMENT.SetHiddenForReason then
            PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason("NecroCat", shouldHide)
        else
            if shouldHide then
                HUD_SCENE:RemoveFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)
                HUD_UI_SCENE:RemoveFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)
            else
                HUD_SCENE:AddFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)
                HUD_UI_SCENE:AddFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)
            end
        end
    end

    -- 2. Скрытие главного родительского контейнера полос
    if PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.control then
        PLAYER_ATTRIBUTE_BARS.control:SetHidden(shouldHide)
    end
end

-- 3. ПРИМЕНЕНИЕ РАЗМЕРОВ, ШАБЛОНОВ И ФОРМАТА ТЕКСТА
function Frames.ApplyLayout()
    if not Frames.HealthFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV

    local styleId = sv.frameStyle or 1
    local style = Frames.STYLES[styleId] or Frames.STYLES[1]

    -- Считываем цветовую схему стиля (если у стиля есть варианты расцветки):
    local colorId = sv.styleColor or 1
    local variant = (style.colorVariants and style.colorVariants[colorId]) or (style.colorVariants and style.colorVariants[1])

    -- Считываем настройки для каждого из 3 ресурсов:
    local hCfg = style.health  or { insetX = 1, insetY = 1, labelPadX = 8, labelOffsetY = 4 }
    local mCfg = style.magicka or { insetX = 1, insetY = 1, labelPadX = 6, labelOffsetY = 4 }
    local sCfg = style.stamina or { insetX = 1, insetY = 1, labelPadX = 6, labelOffsetY = 4 }

    local template = sv.layoutTemplate or 1
    local mode = sv.textMode or 1
    local barW = sv.playerWidth or 200
    local barH = sv.playerHeight or 20

    -- Размеры каждой полоски (из паспорта стиля или от игрока):
    local hpW   = (style.hasArt and hCfg and hCfg.barW) or barW
    local hpH   = (style.hasArt and hCfg and hCfg.barH) or barH
    local magW  = (style.hasArt and mCfg and mCfg.barW) or barW
    local magH  = (style.hasArt and mCfg and mCfg.barH) or barH
    local stamW = (style.hasArt and sCfg and sCfg.barW) or barW
    local stamH = (style.hasArt and sCfg and sCfg.barH) or barH

    -- Считываем настройки зазоров (авторская база стиля + пользовательское смещение):
    local lCfg = (style.layouts and style.layouts[template]) or {}
    local baseSpacingX = lCfg.spacingX or style.spacingX or 6
    local baseSpacingY = lCfg.spacingY or style.spacingY or 4
    local spacingX = baseSpacingX + (sv.spacingOffsetX or 0)
    local spacingY = baseSpacingY + (sv.spacingOffsetY or 0)
    local isUnlocked = (not sv.playerLocked)

    -- 1. Размеры окон фреймов
    Frames.HealthFrame:SetDimensions(hpW, hpH)
    Frames.HealthFrame:SetMovable(isUnlocked)
    Frames.HealthFrame:SetMouseEnabled(isUnlocked)

    Frames.MagFrame:SetDimensions(magW, magH)
    Frames.MagFrame:SetMovable(isUnlocked and template == 4)
    Frames.MagFrame:SetMouseEnabled(isUnlocked and template == 4)

    Frames.StamFrame:SetDimensions(stamW, stamH)
    Frames.StamFrame:SetMovable(isUnlocked and template == 4)
    Frames.StamFrame:SetMouseEnabled(isUnlocked and template == 4)
    
    -- Общий масштаб фреймов
    local scale = (sv.frameScale or 100) / 100
    Frames.HealthFrame:SetScale(scale)
    Frames.MagFrame:SetScale(scale)
    Frames.StamFrame:SetScale(scale)

    -- 2. Привязка позиции Здоровья
    Frames.HealthFrame:ClearAnchors()
    Frames.HealthFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.playerLeft or 450, sv.playerTop or 650)

    -- 3. Расположение Магии и Стамины по шаблону
    Frames.MagFrame:ClearAnchors()
    Frames.StamFrame:ClearAnchors()

    if template == 1 then
        -- Пирамида: ХП вверху, Магия и Стамина внизу симметрично
        Frames.MagFrame:SetAnchor(TOPRIGHT, Frames.HealthFrame, BOTTOM, -spacingX / 2, spacingY)
        Frames.StamFrame:SetAnchor(TOPLEFT, Frames.HealthFrame, BOTTOM, spacingX / 2, spacingY)
    elseif template == 2 then
        -- Вертикально: ХП -> Магия -> Стамина
        Frames.MagFrame:SetAnchor(TOPLEFT, Frames.HealthFrame, BOTTOMLEFT, 0, spacingY)
        Frames.StamFrame:SetAnchor(TOPLEFT, Frames.MagFrame, BOTTOMLEFT, 0, spacingY)
    elseif template == 3 then
        -- Горизонтально: Магия -> Здоровье -> Стамина (spacingY выравнивает горизонт!)
        Frames.MagFrame:SetAnchor(RIGHT, Frames.HealthFrame, LEFT, -spacingX, spacingY)
        Frames.StamFrame:SetAnchor(LEFT, Frames.HealthFrame, RIGHT, spacingX, spacingY)
    elseif template == 4 then
        -- Раздельно: свободное независимое перемещение
        Frames.MagFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.magLeft or (sv.playerLeft - barW - 10), sv.magTop or sv.playerTop)
        Frames.StamFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.stamLeft or (sv.playerLeft + barW + 10), sv.stamTop or sv.playerTop)
    end

    -- 4. Рамки и отступы полос внутри желобов
    -- ЗДОРОВЬЕ:
    if Frames.PlayerHealthArtBG then
        if style.hasArt then
            local artTex = (variant and variant.hp) or (hCfg and hCfg.artTexture) or style.artTexture
            local artW    = (hCfg and hCfg.artW) or style.artW or 480
            local artH    = (hCfg and hCfg.artH) or style.artH or 110
            local artOffX = (hCfg and hCfg.artOffsetX) or style.artOffsetX or 2
            local artOffY = (hCfg and hCfg.artOffsetY) or style.artOffsetY or 0

            Frames.PlayerHealthArtBG:SetHidden(false)
            Frames.PlayerHealthArtBG:SetTexture(artTex)
            Frames.PlayerHealthArtBG:SetDimensions(artW, artH)
            Frames.PlayerHealthArtBG:ClearAnchors()
            Frames.PlayerHealthArtBG:SetAnchor(CENTER, Frames.HealthFrame, CENTER, artOffX, artOffY)
            if Frames.PlayerHealthBG then Frames.PlayerHealthBG:SetHidden(true) end
        else
            Frames.PlayerHealthArtBG:SetHidden(true)
            if Frames.PlayerHealthBG then Frames.PlayerHealthBG:SetHidden(false) end
        end
    end
    if Frames.PlayerHealthBar then
        Frames.PlayerHealthBar:ClearAnchors()
        Frames.PlayerHealthBar:SetAnchor(TOPLEFT, Frames.HealthFrame, TOPLEFT, hCfg.insetX or 1, hCfg.insetY or 1)
        Frames.PlayerHealthBar:SetAnchor(BOTTOMRIGHT, Frames.HealthFrame, BOTTOMRIGHT, -(hCfg.insetX or 1), -(hCfg.insetY or 1))
    end
    if Frames.PlayerShieldBar then
        Frames.PlayerShieldBar:ClearAnchors()
        Frames.PlayerShieldBar:SetAnchor(TOPLEFT, Frames.HealthFrame, TOPLEFT, hCfg.insetX or 1, hCfg.insetY or 1)
        Frames.PlayerShieldBar:SetAnchor(BOTTOMRIGHT, Frames.HealthFrame, BOTTOMRIGHT, -(hCfg.insetX or 1), -(hCfg.insetY or 1))
    end
    if Frames.PlayerTraumaBar then
        Frames.PlayerTraumaBar:ClearAnchors()
        Frames.PlayerTraumaBar:SetAnchor(TOPLEFT, Frames.HealthFrame, TOPLEFT, hCfg.insetX or 1, hCfg.insetY or 1)
        Frames.PlayerTraumaBar:SetAnchor(BOTTOMRIGHT, Frames.HealthFrame, BOTTOMRIGHT, -(hCfg.insetX or 1), -(hCfg.insetY or 1))
    end

    -- МАГИЯ:
    if Frames.PlayerMagArtBG then
        local magTex = (variant and variant.mag) or (mCfg and mCfg.artTexture)
        if magTex and magTex ~= "" then
            Frames.PlayerMagArtBG:SetHidden(false)
            Frames.PlayerMagArtBG:SetTexture(magTex)
            Frames.PlayerMagArtBG:SetDimensions(mCfg.artW or magW, mCfg.artH or magH)
            Frames.PlayerMagArtBG:ClearAnchors()
            Frames.PlayerMagArtBG:SetAnchor(CENTER, Frames.MagFrame, CENTER, mCfg.artOffsetX or 0, mCfg.artOffsetY or 0)
            if Frames.PlayerMagBG then Frames.PlayerMagBG:SetHidden(true) end
        else
            Frames.PlayerMagArtBG:SetHidden(true)
            if Frames.PlayerMagBG then Frames.PlayerMagBG:SetHidden(false) end
        end
    end
    if Frames.PlayerMagBar then
        Frames.PlayerMagBar:ClearAnchors()
        Frames.PlayerMagBar:SetAnchor(TOPLEFT, Frames.MagFrame, TOPLEFT, mCfg.insetX or 1, mCfg.insetY or 1)
        Frames.PlayerMagBar:SetAnchor(BOTTOMRIGHT, Frames.MagFrame, BOTTOMRIGHT, -(mCfg.insetX or 1), -(mCfg.insetY or 1))
    end

    -- СТАМИНА:
    if Frames.PlayerStamArtBG then
        local stamTex = (variant and variant.stam) or (sCfg and sCfg.artTexture)
        if stamTex and stamTex ~= "" then
            Frames.PlayerStamArtBG:SetHidden(false)
            Frames.PlayerStamArtBG:SetTexture(stamTex)
            Frames.PlayerStamArtBG:SetDimensions(sCfg.artW or stamW, sCfg.artH or stamH)
            Frames.PlayerStamArtBG:ClearAnchors()
            Frames.PlayerStamArtBG:SetAnchor(CENTER, Frames.StamFrame, CENTER, sCfg.artOffsetX or 0, sCfg.artOffsetY or 0)
            if Frames.PlayerStamBG then Frames.PlayerStamBG:SetHidden(true) end
        else
            Frames.PlayerStamArtBG:SetHidden(true)
            if Frames.PlayerStamBG then Frames.PlayerStamBG:SetHidden(false) end
        end
    end
    if Frames.PlayerStamBar then
        Frames.PlayerStamBar:ClearAnchors()
        Frames.PlayerStamBar:SetAnchor(TOPLEFT, Frames.StamFrame, TOPLEFT, sCfg.insetX or 1, sCfg.insetY or 1)
        Frames.PlayerStamBar:SetAnchor(BOTTOMRIGHT, Frames.StamFrame, BOTTOMRIGHT, -(sCfg.insetX or 1), -(sCfg.insetY or 1))
    end

    -- 5. Направление полосы ХП (из центра или слева направо)
    local healthAlign = sv.healthCenterFill and BAR_ALIGNMENT_CENTER or BAR_ALIGNMENT_NORMAL
    Frames.PlayerHealthBar:SetBarAlignment(healthAlign)

    -- 6. Шрифты и позиционирование текста по режимам
    local fSize = sv.fontSize or 14
    local subFSize = math.max(10, fSize - 1)
    local fontStr = string.format("$(BOLD_FONT)|%d|thick-outline", fSize)
    local subFontStr = string.format("$(BOLD_FONT)|%d|thick-outline", subFSize)

    Frames.PlayerHealthLeftLabel:SetFont(fontStr)
    Frames.PlayerHealthRightLabel:SetFont(fontStr)
    Frames.PlayerMagLeftLabel:SetFont(subFontStr)
    Frames.PlayerMagRightLabel:SetFont(subFontStr)
    Frames.PlayerStamLeftLabel:SetFont(subFontStr)
    Frames.PlayerStamRightLabel:SetFont(subFontStr)

    Frames.PlayerHealthLeftLabel:ClearAnchors()
    Frames.PlayerHealthRightLabel:ClearAnchors()
    Frames.PlayerMagLeftLabel:ClearAnchors()
    Frames.PlayerMagRightLabel:ClearAnchors()
    Frames.PlayerStamLeftLabel:ClearAnchors()
    Frames.PlayerStamRightLabel:ClearAnchors()

    if mode == 1 then
        -- Сплит по краям (Слева цифры, Справа %)
        Frames.PlayerHealthLeftLabel:SetAnchor(LEFT, Frames.HealthFrame, LEFT, hCfg.labelPadX or 8, hCfg.labelOffsetY or 4)
        Frames.PlayerHealthLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        Frames.PlayerHealthLeftLabel:SetHidden(false)

        Frames.PlayerHealthRightLabel:SetAnchor(RIGHT, Frames.HealthFrame, RIGHT, -(hCfg.labelPadX or 8), hCfg.labelOffsetY or 4)
        Frames.PlayerHealthRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        Frames.PlayerHealthRightLabel:SetHidden(false)

        Frames.PlayerMagLeftLabel:SetAnchor(LEFT, Frames.MagFrame, LEFT, mCfg.labelPadX or 6, mCfg.labelOffsetY or 4)
        Frames.PlayerMagLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        Frames.PlayerMagLeftLabel:SetHidden(false)

        Frames.PlayerMagRightLabel:SetAnchor(RIGHT, Frames.MagFrame, RIGHT, -(mCfg.labelPadX or 6), mCfg.labelOffsetY or 4)
        Frames.PlayerMagRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        Frames.PlayerMagRightLabel:SetHidden(false)

        Frames.PlayerStamLeftLabel:SetAnchor(LEFT, Frames.StamFrame, LEFT, sCfg.labelPadX or 6, sCfg.labelOffsetY or 4)
        Frames.PlayerStamLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        Frames.PlayerStamLeftLabel:SetHidden(false)

        Frames.PlayerStamRightLabel:SetAnchor(RIGHT, Frames.StamFrame, RIGHT, -(sCfg.labelPadX or 6), sCfg.labelOffsetY or 4)
        Frames.PlayerStamRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        Frames.PlayerStamRightLabel:SetHidden(false)
    elseif mode == 2 or mode == 3 or mode == 4 then
        -- По центру
        Frames.PlayerHealthLeftLabel:SetHidden(true)
        Frames.PlayerHealthRightLabel:SetAnchor(CENTER, Frames.HealthFrame, CENTER, 0, hCfg.labelOffsetY or 4)
        Frames.PlayerHealthRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        Frames.PlayerHealthRightLabel:SetHidden(false)

        Frames.PlayerMagLeftLabel:SetHidden(true)
        Frames.PlayerMagRightLabel:SetAnchor(CENTER, Frames.MagFrame, CENTER, 0, mCfg.labelOffsetY or 4)
        Frames.PlayerMagRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        Frames.PlayerMagRightLabel:SetHidden(false)

        Frames.PlayerStamLeftLabel:SetHidden(true)
        Frames.PlayerStamRightLabel:SetAnchor(CENTER, Frames.StamFrame, CENTER, 0, sCfg.labelOffsetY or 4)
        Frames.PlayerStamRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        Frames.PlayerStamRightLabel:SetHidden(false)
    elseif mode == 5 then
        -- Без текста (Чистые полосы)
        Frames.PlayerHealthLeftLabel:SetHidden(true)
        Frames.PlayerHealthRightLabel:SetHidden(true)
        Frames.PlayerMagLeftLabel:SetHidden(true)
        Frames.PlayerMagRightLabel:SetHidden(true)
        Frames.PlayerStamLeftLabel:SetHidden(true)
        Frames.PlayerStamRightLabel:SetHidden(true)
    end

    -- Применение геометрии осадного фрейма
    if Frames.SiegeFrame then
        local siegeStyleId = sv.siegeStyle or 1
        local siegeStyle   = Frames.SIEGE_STYLES[siegeStyleId] or Frames.SIEGE_STYLES[1]
        local hasArt       = siegeStyle and siegeStyle.hasArt

        -- Находим картинку из выбранного комплекта расцветки:
        local siegeColorId = sv.siegeStyleColor or 1
        local sVariant = (siegeStyle.colorVariants and siegeStyle.colorVariants[siegeColorId]) or (siegeStyle.colorVariants and siegeStyle.colorVariants[1])
        local sArtTex  = (sVariant and sVariant.art) or siegeStyle.artTexture

        local sWidth   = (hasArt and siegeStyle.barW) or sv.siegeWidth or 300
        local sHeight  = (hasArt and siegeStyle.barH) or sv.siegeHeight or 20

        Frames.SiegeFrame:SetDimensions(sWidth, sHeight)
        Frames.SiegeFrame:SetMovable(isUnlocked)
        Frames.SiegeFrame:SetMouseEnabled(isUnlocked)
        Frames.SiegeFrame:SetScale(scale)

        Frames.SiegeFrame:ClearAnchors()
        Frames.SiegeFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.siegeLeft or 450, sv.siegeTop or 580)

        -- Рамка осадки
        if Frames.SiegeArtBG then
            if hasArt and sArtTex then
                Frames.SiegeArtBG:SetHidden(false)
                Frames.SiegeArtBG:SetTexture(sArtTex)
                Frames.SiegeArtBG:SetDimensions(siegeStyle.artW or sWidth, siegeStyle.artH or sHeight)
                Frames.SiegeArtBG:ClearAnchors()
                Frames.SiegeArtBG:SetAnchor(CENTER, Frames.SiegeFrame, CENTER, siegeStyle.artOffsetX or 0, siegeStyle.artOffsetY or 0)
                if Frames.SiegeBG then Frames.SiegeBG:SetHidden(true) end

                if Frames.PlayerSiegeBar then
                    Frames.PlayerSiegeBar:ClearAnchors()
                    Frames.PlayerSiegeBar:SetAnchor(TOPLEFT, Frames.SiegeFrame, TOPLEFT, siegeStyle.insetX or 0, siegeStyle.insetY or 3)
                    Frames.PlayerSiegeBar:SetAnchor(BOTTOMRIGHT, Frames.SiegeFrame, BOTTOMRIGHT, -(siegeStyle.insetX or 0), -(siegeStyle.insetY or 3))
                end
            else
                Frames.SiegeArtBG:SetHidden(true)
                if Frames.SiegeBG then Frames.SiegeBG:SetHidden(false) end

                if Frames.PlayerSiegeBar then
                    Frames.PlayerSiegeBar:ClearAnchors()
                    Frames.PlayerSiegeBar:SetAnchor(TOPLEFT, Frames.SiegeFrame, TOPLEFT, 1, 1)
                    Frames.PlayerSiegeBar:SetAnchor(BOTTOMRIGHT, Frames.SiegeFrame, BOTTOMRIGHT, -1, -1)
                end
            end
        end

        local sTitleSize = sv.siegeTitleFontSize or 14
        local sValSize   = sv.siegeFontSize or 13
        local sLabelOffY = sv.siegeLabelOffsetY or 0
        local sPadX      = sv.siegeLabelPadX or 8
        local sMode      = sv.siegeTextMode or 1
        local valFont    = string.format("$(BOLD_FONT)|%d|thick-outline", sValSize)

        if Frames.SiegeTitleLabel then
            Frames.SiegeTitleLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sTitleSize))
        end

        if Frames.SiegeLeftLabel and Frames.SiegeRightLabel then
            Frames.SiegeLeftLabel:SetFont(valFont)
            Frames.SiegeRightLabel:SetFont(valFont)
            Frames.SiegeLeftLabel:ClearAnchors()
            Frames.SiegeRightLabel:ClearAnchors()

            if sMode == 1 then
                -- Сплит по краям (Слева цифры, Справа %)
                Frames.SiegeLeftLabel:SetAnchor(LEFT, Frames.SiegeFrame, LEFT, sPadX, sLabelOffY)
                Frames.SiegeLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                Frames.SiegeLeftLabel:SetHidden(false)

                Frames.SiegeRightLabel:SetAnchor(RIGHT, Frames.SiegeFrame, RIGHT, -sPadX, sLabelOffY)
                Frames.SiegeRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                Frames.SiegeRightLabel:SetHidden(false)
            elseif sMode == 2 or sMode == 3 or sMode == 4 then
                -- По центру
                Frames.SiegeLeftLabel:SetHidden(true)
                Frames.SiegeRightLabel:SetAnchor(CENTER, Frames.SiegeFrame, CENTER, 0, sLabelOffY)
                Frames.SiegeRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                Frames.SiegeRightLabel:SetHidden(false)
            elseif sMode == 5 then
                -- Без текста
                Frames.SiegeLeftLabel:SetHidden(true)
                Frames.SiegeRightLabel:SetHidden(true)
            end
        end
    end

    Frames.ApplyBarTextures()
    Frames.ApplyColors()
    Frames.UpdatePlayerHealth()
    Frames.UpdatePlayerMagicka()
    Frames.UpdatePlayerStamina()
    Frames.UpdateSiegeBar()
end

-- 4. ОБНОВЛЕНИЕ ЗДОРОВЬЯ, ЩИТА И ТРАВМЫ
function Frames.UpdatePlayerHealth()
    if not Frames.HealthFrame or not Frames.PlayerHealthBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV
    local mode = sv.textMode or 1

    local curHealth, maxHealth = GetUnitPower("player", POWERTYPE_HEALTH)
    if maxHealth <= 0 then maxHealth = 1 end

    local shieldVal = 0
    local traumaVal = 0

    -- Симуляция в тестах или реальные эффекты
    if sv.testShield then
        shieldVal = math.floor(maxHealth * 0.45)
    elseif GetUnitAttributeVisualizerEffectInfo then
        shieldVal = GetUnitAttributeVisualizerEffectInfo("player", ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
    end

    if sv.testTrauma then
        traumaVal = math.floor(maxHealth * 0.25)
    elseif GetUnitAttributeVisualizerEffectInfo then
        traumaVal = GetUnitAttributeVisualizerEffectInfo("player", ATTRIBUTE_VISUAL_TRAUMA, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
    end

    -- Заполнение полосок
    Frames.PlayerHealthBar:SetMinMax(0, maxHealth)
    Frames.PlayerHealthBar:SetValue(curHealth)

    -- Щит
    if shieldVal > 0 then
        Frames.PlayerShieldBar:SetMinMax(0, maxHealth)
        Frames.PlayerShieldBar:SetValue(shieldVal)
        Frames.PlayerShieldBar:SetHidden(false)
    else
        Frames.PlayerShieldBar:SetHidden(true)
    end

    -- Травма
    if Frames.PlayerTraumaBar then
        if traumaVal > 0 then
            Frames.PlayerTraumaBar:SetMinMax(0, maxHealth)
            Frames.PlayerTraumaBar:SetValue(traumaVal)
            Frames.PlayerTraumaBar:SetHidden(false)
        else
            Frames.PlayerTraumaBar:SetHidden(true)
        end
    end

    -- Форматирование текста
    if mode == 5 then return end

    local pct = math.floor((curHealth / maxHealth) * 100)
    local shieldHex = RgbToHex(sv.shieldTextColor or defaultFramesSV.shieldTextColor)
    local traumaHex = RgbToHex(sv.traumaTextColor or defaultFramesSV.traumaTextColor)

    local extraText = ""
    if shieldVal > 0 and sv.showShieldText ~= false then
        extraText = extraText .. string.format(" |c%s[+%s]|r", shieldHex, FormatValueNumber(shieldVal))
    end
    if traumaVal > 0 and sv.showTraumaText ~= false then
        extraText = extraText .. string.format(" |c%s[-%s]|r", traumaHex, FormatValueNumber(traumaVal))
    end

    if mode == 1 then
        -- Сплит: слева цифры (+ приписки), справа %
        Frames.PlayerHealthLeftLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extraText))
        Frames.PlayerHealthRightLabel:SetText(string.format("%d%%", pct))
    elseif mode == 2 then
        -- Центр: цифры (+ приписки) и %
        Frames.PlayerHealthRightLabel:SetText(string.format("%s%s (%d%%)", FormatValueNumber(curHealth), extraText, pct))
    elseif mode == 3 then
        -- Центр: только цифры (+ приписки)
        Frames.PlayerHealthRightLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extraText))
    elseif mode == 4 then
        -- Центр: только %
        Frames.PlayerHealthRightLabel:SetText(string.format("%d%%%s", pct, extraText))
    end
end

-- 5. ОБНОВЛЕНИЕ МАГИИ
function Frames.UpdatePlayerMagicka()
    if not Frames.PlayerMagBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV
    local mode = sv.textMode or 1

    local curMag, maxMag = GetUnitPower("player", POWERTYPE_MAGICKA)
    if maxMag <= 0 then maxMag = 1 end

    Frames.PlayerMagBar:SetMinMax(0, maxMag)
    Frames.PlayerMagBar:SetValue(curMag)

    if mode == 5 then return end

    local pct = math.floor((curMag / maxMag) * 100)

    if mode == 1 then
        Frames.PlayerMagLeftLabel:SetText(FormatValueNumber(curMag))
        Frames.PlayerMagRightLabel:SetText(string.format("%d%%", pct))
    elseif mode == 2 then
        Frames.PlayerMagRightLabel:SetText(string.format("%s (%d%%)", FormatValueNumber(curMag), pct))
    elseif mode == 3 then
        Frames.PlayerMagRightLabel:SetText(FormatValueNumber(curMag))
    elseif mode == 4 then
        Frames.PlayerMagRightLabel:SetText(string.format("%d%%", pct))
    end
end

-- 6. ОБНОВЛЕНИЕ СТАМИНЫ
function Frames.UpdatePlayerStamina()
    if not Frames.PlayerStamBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV
    local mode = sv.textMode or 1

    local curStam, maxStam = GetUnitPower("player", POWERTYPE_STAMINA)
    if maxStam <= 0 then maxStam = 1 end

    Frames.PlayerStamBar:SetMinMax(0, maxStam)
    Frames.PlayerStamBar:SetValue(curStam)

    if mode == 5 then return end

    local pct = math.floor((curStam / maxStam) * 100)

    if mode == 1 then
        Frames.PlayerStamLeftLabel:SetText(FormatValueNumber(curStam))
        Frames.PlayerStamRightLabel:SetText(string.format("%d%%", pct))
    elseif mode == 2 then
        Frames.PlayerStamRightLabel:SetText(string.format("%s (%d%%)", FormatValueNumber(curStam), pct))
    elseif mode == 3 then
        Frames.PlayerStamRightLabel:SetText(FormatValueNumber(curStam))
    elseif mode == 4 then
        Frames.PlayerStamRightLabel:SetText(string.format("%d%%", pct))
    end
end

local function GetOrCreateChild(parent, name, controlType)
    local child = parent:GetNamedChild(name)
    if child then return child end
    return WINDOW_MANAGER:CreateControl("$(parent)" .. name, parent, controlType)
end

-- 6.1 ОБНОВЛЕНИЕ СТАМИНЫ МАУНТА
function Frames.UpdateMountStamina()
    if not Frames.MountFrame or not Frames.PlayerMountBar then return end

    if not IsMounted() then
        Frames.MountFrame:SetHidden(true)
        return
    end

    local cur, max = GetUnitPower("player", POWERTYPE_MOUNT_STAMINA)
    if max <= 0 then max = 1 end

    Frames.PlayerMountBar:SetMinMax(0, max)
    Frames.PlayerMountBar:SetValue(cur)
    Frames.MountFrame:SetHidden(false)
end

-- 6.2 ОБНОВЛЕНИЕ ОСАДНОГО ОРУДИЯ
function Frames.UpdateSiegeBar()
    if not Frames.SiegeFrame or not Frames.PlayerSiegeBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV

    if sv.siegeEnabled == false then
        Frames.SiegeFrame:SetHidden(true)
        return
    end

    local unitTag       = "controlledsiege"
    local isControlling = DoesUnitExist(unitTag) and IsPlayerControllingSiegeWeapon()
    local isTesting     = (sv.testSiege == true)
    local isMoving      = (sv.playerLocked == false)

    -- Если не на осадке, тест выключен и фреймы заблокированы — прячем намертво
    if not (isControlling or isTesting or isMoving) then
        Frames.SiegeFrame:SetHidden(true)
        return
    end

    local cur, max = 100000, 100000
    local name = "Баллиста Пакта"

    if sv.testSiege and not DoesUnitExist(unitTag) then
        cur = 100000
        max = 100000
        name = "Осадное орудие (Тест)"
    else
        cur, max = GetUnitPower(unitTag, POWERTYPE_HEALTH)
        if max <= 0 then max = 1 end
        name = GetUnitName(unitTag)
    end

    Frames.PlayerSiegeBar:SetMinMax(0, max)
    Frames.PlayerSiegeBar:SetValue(cur)

    if Frames.SiegeTitleLabel then
        Frames.SiegeTitleLabel:SetText(name)
    end

    local mode = sv.siegeTextMode or 1
    local pct = math.floor((cur / max) * 100)

    if Frames.SiegeLeftLabel and Frames.SiegeRightLabel then
        if mode == 1 then
            -- Сплит: Слева прочность, Справа %
            Frames.SiegeLeftLabel:SetText(string.format("%s / %s", FormatValueNumber(cur), FormatValueNumber(max)))
            Frames.SiegeRightLabel:SetText(string.format("%d%%", pct))
        elseif mode == 2 then
            -- По центру: цифры и %
            Frames.SiegeRightLabel:SetText(string.format("%s / %s (%d%%)", FormatValueNumber(cur), FormatValueNumber(max), pct))
        elseif mode == 3 then
            -- По центру: только цифры
            Frames.SiegeRightLabel:SetText(string.format("%s / %s", FormatValueNumber(cur), FormatValueNumber(max)))
        elseif mode == 4 then
            -- По центру: только %
            Frames.SiegeRightLabel:SetText(string.format("%d%%", pct))
        end
    end

    Frames.SiegeFrame:SetHidden(false)
end

-- 7. СОЗДАНИЕ UI ФРЕЙМОВ
function Frames.CreatePlayerFrame()
    if Frames.HealthFrame then return end

    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV
    local barW = sv.playerWidth or 200
    local barH = sv.playerHeight or 20

    -- 1. ОКНО ЗДОРОВЬЯ
    local healthFrame = _G["NecroCat_HealthFrame"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_HealthFrame")
    healthFrame:SetDimensions(barW, barH)
    healthFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.playerLeft or 450, sv.playerTop or 650)
    healthFrame:SetMovable(not sv.playerLocked)
    healthFrame:SetMouseEnabled(not sv.playerLocked)
    healthFrame:SetClampedToScreen(true)
    healthFrame:SetDrawTier(DT_HIGH)

    local healthBG = GetOrCreateChild(healthFrame, "BG", CT_BACKDROP)
    healthBG:SetAnchorFill(healthFrame)
    healthBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    healthBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    healthBG:SetEdgeTexture("", 8, 1, 1)
    local healthArtBG = GetOrCreateChild(healthFrame, "ArtBG", CT_TEXTURE)
    healthArtBG:SetDrawLayer(DL_BACKGROUND)
    healthArtBG:SetDrawLevel(2)

    local healthBar = GetOrCreateChild(healthFrame, "Bar", CT_STATUSBAR)
    healthBar:ClearAnchors()
    healthBar:SetAnchor(TOPLEFT, healthFrame, TOPLEFT, 1, 1)
    healthBar:SetAnchor(BOTTOMRIGHT, healthFrame, BOTTOMRIGHT, -1, -1)
    healthBar:SetDrawLayer(DL_CONTROLS)
    healthBar:SetDrawLevel(1)

    -- Щит (из центра)
    local shieldBar = GetOrCreateChild(healthFrame, "Shield", CT_STATUSBAR)
    shieldBar:ClearAnchors()
    shieldBar:SetAnchor(TOPLEFT, healthFrame, TOPLEFT, 1, 1)
    shieldBar:SetAnchor(BOTTOMRIGHT, healthFrame, BOTTOMRIGHT, -1, -1)
    shieldBar:SetBarAlignment(BAR_ALIGNMENT_CENTER)
    shieldBar:SetDrawLayer(DL_CONTROLS)
    shieldBar:SetDrawLevel(2)
    shieldBar:SetHidden(true)

    -- Травма (справа налево)
    local traumaBar = GetOrCreateChild(healthFrame, "Trauma", CT_STATUSBAR)
    traumaBar:ClearAnchors()
    traumaBar:SetAnchor(TOPLEFT, healthFrame, TOPLEFT, 1, 1)
    traumaBar:SetAnchor(BOTTOMRIGHT, healthFrame, BOTTOMRIGHT, -1, -1)
    traumaBar:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
    traumaBar:SetDrawLayer(DL_CONTROLS)
    traumaBar:SetDrawLevel(3)
    traumaBar:SetHidden(true)

    local healthLeftLabel = GetOrCreateChild(healthFrame, "LeftLabel", CT_LABEL)
    healthLeftLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.fontSize or 14))
    healthLeftLabel:SetDrawLayer(DL_OVERLAY)
    healthLeftLabel:SetDrawLevel(4)

    local healthRightLabel = GetOrCreateChild(healthFrame, "RightLabel", CT_LABEL)
    healthRightLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.fontSize or 14))
    healthRightLabel:SetDrawLayer(DL_OVERLAY)
    healthRightLabel:SetDrawLevel(4)

    healthFrame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.frames then
            NecroCat.savedVars.frames.playerLeft = self:GetLeft()
            NecroCat.savedVars.frames.playerTop = self:GetTop()
        end
    end)

    -- 2. ОКНО МАГИИ
    local magFrame = _G["NecroCat_MagFrame"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_MagFrame")
    magFrame:SetDimensions(barW, barH)
    magFrame:SetClampedToScreen(true)
    magFrame:SetDrawTier(DT_HIGH)

    local magBG = GetOrCreateChild(magFrame, "BG", CT_BACKDROP)
    magBG:SetAnchorFill(magFrame)
    magBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    magBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    magBG:SetEdgeTexture("", 8, 1, 1)
    local magArtBG = GetOrCreateChild(magFrame, "ArtBG", CT_TEXTURE)
    magArtBG:SetDrawLayer(DL_BACKGROUND)
    magArtBG:SetDrawLevel(2)

    local magBar = GetOrCreateChild(magFrame, "Bar", CT_STATUSBAR)
    magBar:ClearAnchors()
    magBar:SetAnchor(TOPLEFT, magFrame, TOPLEFT, 1, 1)
    magBar:SetAnchor(BOTTOMRIGHT, magFrame, BOTTOMRIGHT, -1, -1)
    magBar:SetDrawLayer(DL_CONTROLS)

    local subFSize = math.max(10, (sv.fontSize or 14) - 1)
    local magLeftLabel = GetOrCreateChild(magFrame, "LeftLabel", CT_LABEL)
    magLeftLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", subFSize))
    magLeftLabel:SetDrawLayer(DL_OVERLAY)
    magLeftLabel:SetDrawLevel(3)

    local magRightLabel = GetOrCreateChild(magFrame, "RightLabel", CT_LABEL)
    magRightLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", subFSize))
    magRightLabel:SetDrawLayer(DL_OVERLAY)
    magRightLabel:SetDrawLevel(3)

    magFrame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.frames then
            NecroCat.savedVars.frames.magLeft = self:GetLeft()
            NecroCat.savedVars.frames.magTop = self:GetTop()
        end
    end)

    -- 3. ОКНО СТАМИНЫ
    local stamFrame = _G["NecroCat_StamFrame"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_StamFrame")
    stamFrame:SetDimensions(barW, barH)
    stamFrame:SetClampedToScreen(true)
    stamFrame:SetDrawTier(DT_HIGH)

    local stamBG = GetOrCreateChild(stamFrame, "BG", CT_BACKDROP)
    stamBG:SetAnchorFill(stamFrame)
    stamBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    stamBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    stamBG:SetEdgeTexture("", 8, 1, 1)
    local stamArtBG = GetOrCreateChild(stamFrame, "ArtBG", CT_TEXTURE)
    stamArtBG:SetDrawLayer(DL_BACKGROUND)
    stamArtBG:SetDrawLevel(2)

    local stamBar = GetOrCreateChild(stamFrame, "Bar", CT_STATUSBAR)
    stamBar:ClearAnchors()
    stamBar:SetAnchor(TOPLEFT, stamFrame, TOPLEFT, 1, 1)
    stamBar:SetAnchor(BOTTOMRIGHT, stamFrame, BOTTOMRIGHT, -1, -1)
    stamBar:SetDrawLayer(DL_CONTROLS)

    local stamLeftLabel = GetOrCreateChild(stamFrame, "LeftLabel", CT_LABEL)
    stamLeftLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", subFSize))
    stamLeftLabel:SetDrawLayer(DL_OVERLAY)
    stamLeftLabel:SetDrawLevel(3)

    local stamRightLabel = GetOrCreateChild(stamFrame, "RightLabel", CT_LABEL)
    stamRightLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", subFSize))
    stamRightLabel:SetDrawLayer(DL_OVERLAY)
    stamRightLabel:SetDrawLevel(3)

    stamFrame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.frames then
            NecroCat.savedVars.frames.stamLeft = self:GetLeft()
            NecroCat.savedVars.frames.stamTop = self:GetTop()
        end
    end)

    Frames.HealthFrame            = healthFrame
    Frames.PlayerHealthBG         = healthBG
    Frames.PlayerHealthArtBG      = healthArtBG
    Frames.PlayerHealthBar        = healthBar
    Frames.PlayerShieldBar        = shieldBar
    Frames.PlayerTraumaBar        = traumaBar
    Frames.PlayerHealthLeftLabel  = healthLeftLabel
    Frames.PlayerHealthRightLabel = healthRightLabel

    -- 4. ОКНО ОСАДНОГО ОРУДИЯ (НЕЗАВИСИМОЕ)
    local siegeFrame = _G["NecroCat_SiegeFrame"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_SiegeFrame")
    siegeFrame:SetDimensions(300, 20)
    siegeFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.siegeLeft or 450, sv.siegeTop or 580)
    siegeFrame:SetMovable(not sv.playerLocked)
    siegeFrame:SetMouseEnabled(not sv.playerLocked)
    siegeFrame:SetClampedToScreen(true)
    siegeFrame:SetDrawTier(DT_HIGH)

    siegeFrame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.frames then
            NecroCat.savedVars.frames.siegeLeft = self:GetLeft()
            NecroCat.savedVars.frames.siegeTop  = self:GetTop()
        end
    end)

    local siegeBG = GetOrCreateChild(siegeFrame, "BG", CT_BACKDROP)
    siegeBG:SetAnchorFill(siegeFrame)
    siegeBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    siegeBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    siegeBG:SetEdgeTexture("", 8, 1, 1)

    local siegeArtBG = GetOrCreateChild(siegeFrame, "ArtBG", CT_TEXTURE)
    siegeArtBG:SetDrawLayer(DL_BACKGROUND)
    siegeArtBG:SetDrawLevel(2)

    local siegeBar = GetOrCreateChild(siegeFrame, "Bar", CT_STATUSBAR)
    siegeBar:ClearAnchors()
    siegeBar:SetAnchor(TOPLEFT, siegeFrame, TOPLEFT, 1, 1)
    siegeBar:SetAnchor(BOTTOMRIGHT, siegeFrame, BOTTOMRIGHT, -1, -1)
    siegeBar:SetDrawLayer(DL_CONTROLS)

    local siegeTitleLabel = GetOrCreateChild(siegeFrame, "TitleLabel", CT_LABEL)
    siegeTitleLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", 14))
    siegeTitleLabel:ClearAnchors()
    siegeTitleLabel:SetAnchor(BOTTOM, siegeFrame, TOP, 0, -3)
    siegeTitleLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    siegeTitleLabel:SetDrawLayer(DL_OVERLAY)

    local siegeLeftLabel = GetOrCreateChild(siegeFrame, "LeftLabel", CT_LABEL)
    siegeLeftLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", 13))
    siegeLeftLabel:SetDrawLayer(DL_OVERLAY)
    siegeLeftLabel:SetDrawLevel(4)

    local siegeRightLabel = GetOrCreateChild(siegeFrame, "RightLabel", CT_LABEL)
    siegeRightLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", 13))
    siegeRightLabel:SetDrawLayer(DL_OVERLAY)
    siegeRightLabel:SetDrawLevel(4)

    siegeFrame:SetHidden(true)

    Frames.SiegeFrame       = siegeFrame
    Frames.SiegeBG          = siegeBG
    Frames.SiegeArtBG       = siegeArtBG
    Frames.PlayerSiegeBar   = siegeBar
    Frames.SiegeTitleLabel  = siegeTitleLabel
    Frames.SiegeLeftLabel   = siegeLeftLabel
    Frames.SiegeRightLabel  = siegeRightLabel

    Frames.MagFrame               = magFrame
    Frames.PlayerMagBG            = magBG
    Frames.PlayerMagArtBG         = magArtBG
    Frames.PlayerMagBar           = magBar
    Frames.PlayerMagLeftLabel     = magLeftLabel
    Frames.PlayerMagRightLabel    = magRightLabel

    -- Полоска маунта (дочерняя к фрейму стамины, толщина 5px)
    local mountFrame = GetOrCreateChild(stamFrame, "MountFrame", CT_CONTROL)
    mountFrame:ClearAnchors()
    mountFrame:SetAnchor(TOPLEFT, stamFrame, BOTTOMLEFT, 0, 2)
    mountFrame:SetAnchor(TOPRIGHT, stamFrame, BOTTOMRIGHT, 0, 2)
    mountFrame:SetHeight(5)

    local mountBG = GetOrCreateChild(mountFrame, "BG", CT_BACKDROP)
    mountBG:SetAnchorFill(mountFrame)
    mountBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    mountBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    mountBG:SetEdgeTexture("", 8, 1, 1)

    local mountBar = GetOrCreateChild(mountFrame, "Bar", CT_STATUSBAR)
    mountBar:ClearAnchors()
    mountBar:SetAnchor(TOPLEFT, mountFrame, TOPLEFT, 1, 1)
    mountBar:SetAnchor(BOTTOMRIGHT, mountFrame, BOTTOMRIGHT, -1, -1)
    mountBar:SetDrawLayer(DL_CONTROLS)

    mountFrame:SetHidden(true)

    Frames.MountFrame             = mountFrame
    Frames.PlayerMountBar         = mountBar

    Frames.StamFrame              = stamFrame
    Frames.PlayerStamBG           = stamBG
    Frames.PlayerStamArtBG        = stamArtBG
    Frames.PlayerStamBar          = stamBar
    Frames.PlayerStamLeftLabel    = stamLeftLabel
    Frames.PlayerStamRightLabel   = stamRightLabel

    Frames.HealthFragment = ZO_SimpleSceneFragment:New(healthFrame)
    Frames.MagFragment    = ZO_SimpleSceneFragment:New(magFrame)
    Frames.StamFragment   = ZO_SimpleSceneFragment:New(stamFrame)
    Frames.SiegeFragment  = ZO_SimpleSceneFragment:New(siegeFrame)

    Frames.UpdateVisibility()
    Frames.ApplyLayout()
    Frames.UpdateDefaultBarsVisibility()
    Frames.UpdateMountStamina()
    Frames.UpdateSiegeBar()
end

-- Управление видимостью и привязкой к сценам
function Frames.UpdateVisibility()
    if not Frames.HealthFragment then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultFramesSV
    local isEnabled = (sv.playerEnabled ~= false)
    local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    local siegeScene    = SCENE_MANAGER:GetScene("siegeBar")

    if isEnabled then
        HUD_SCENE:AddFragment(Frames.HealthFragment)
        HUD_SCENE:AddFragment(Frames.MagFragment)
        HUD_SCENE:AddFragment(Frames.StamFragment)

        HUD_UI_SCENE:AddFragment(Frames.HealthFragment)
        HUD_UI_SCENE:AddFragment(Frames.MagFragment)
        HUD_UI_SCENE:AddFragment(Frames.StamFragment)

        -- Осадка активна только на осадной сцене боя!
        if siegeScene then
            siegeScene:AddFragment(Frames.HealthFragment)
            siegeScene:AddFragment(Frames.MagFragment)
            siegeScene:AddFragment(Frames.StamFragment)
            if Frames.SiegeFragment then siegeScene:AddFragment(Frames.SiegeFragment) end
        end

        -- Показываем в меню Esc только если включен режим перетаскивания!
        local isUnlocked = (not sv.playerLocked)
        if gameMenuScene then
            if isUnlocked then
                if not gameMenuScene:HasFragment(Frames.HealthFragment) then
                    gameMenuScene:AddFragment(Frames.HealthFragment)
                    gameMenuScene:AddFragment(Frames.MagFragment)
                    gameMenuScene:AddFragment(Frames.StamFragment)
                    if Frames.SiegeFragment then gameMenuScene:AddFragment(Frames.SiegeFragment) end
                end
            else
                gameMenuScene:RemoveFragment(Frames.HealthFragment)
                gameMenuScene:RemoveFragment(Frames.MagFragment)
                gameMenuScene:RemoveFragment(Frames.StamFragment)
                if Frames.SiegeFragment then gameMenuScene:RemoveFragment(Frames.SiegeFragment) end
            end
        end
    else
        HUD_SCENE:RemoveFragment(Frames.HealthFragment)
        HUD_SCENE:RemoveFragment(Frames.MagFragment)
        HUD_SCENE:RemoveFragment(Frames.StamFragment)
        if Frames.SiegeFragment then HUD_SCENE:RemoveFragment(Frames.SiegeFragment) end

        HUD_UI_SCENE:RemoveFragment(Frames.HealthFragment)
        HUD_UI_SCENE:RemoveFragment(Frames.MagFragment)
        HUD_UI_SCENE:RemoveFragment(Frames.StamFragment)
        if Frames.SiegeFragment then HUD_UI_SCENE:RemoveFragment(Frames.SiegeFragment) end

        if siegeScene then
            siegeScene:RemoveFragment(Frames.HealthFragment)
            siegeScene:RemoveFragment(Frames.MagFragment)
            siegeScene:RemoveFragment(Frames.StamFragment)
            if Frames.SiegeFragment then siegeScene:RemoveFragment(Frames.SiegeFragment) end
        end

        if gameMenuScene then
            gameMenuScene:RemoveFragment(Frames.HealthFragment)
            gameMenuScene:RemoveFragment(Frames.MagFragment)
            gameMenuScene:RemoveFragment(Frames.StamFragment)
            if Frames.SiegeFragment then gameMenuScene:RemoveFragment(Frames.SiegeFragment) end
        end

        if Frames.HealthFrame then Frames.HealthFrame:SetHidden(true) end
        if Frames.MagFrame then Frames.MagFrame:SetHidden(true) end
        if Frames.StamFrame then Frames.StamFrame:SetHidden(true) end
        if Frames.SiegeFrame then Frames.SiegeFrame:SetHidden(true) end
    end
end

-- 8. МЕНЮ НАСТРОЕК LAM (АВТОНОМНОЕ)
function Frames.GetMenuOptions()
    local texNames, texIds = Frames.GetBarTextureChoices()
    local curLayout = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.layoutTemplate) or 1
    local styleNames, styleIds = GetAvailableStylesForLayout(curLayout)
    local siegeStyleNames, siegeStyleIds = Frames.GetSiegeStyleChoices()

    return {
        type = "submenu",
        name = GetString(SI_NC_LAM_FRAMES_SUB),
        tooltip = GetString(SI_NC_LAM_FRAMES_SUB_TT),
        controls = {
            { type = "header", name = GetString(SI_NC_LAM_PLAYER_ENABLE) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_PLAYER_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.playerEnabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.playerEnabled = v
                        Frames.UpdateVisibility()
                        Frames.UpdateDefaultBarsVisibility()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_PLAYER_UNLOCK),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.playerLocked == false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.playerLocked = not v
                        Frames.ApplyLayout()
                        Frames.UpdateVisibility() -- Моментально прячет или показывает в Esc!
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_HIDE_DEFAULT_BARS),
                disabled = function() return not (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.playerEnabled ~= false) end,
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.hideDefaultBars ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.hideDefaultBars = v
                        Frames.UpdateDefaultBarsVisibility()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_FRAMES_LAYOUT),
                choices = { GetString(SI_NC_LAM_LAYOUT_PYRAMID), GetString(SI_NC_LAM_LAYOUT_VERTICAL), GetString(SI_NC_LAM_LAYOUT_HORIZONTAL), GetString(SI_NC_LAM_LAYOUT_SEPARATE) },
                choicesValues = { 1, 2, 3, 4 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.layoutTemplate) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.layoutTemplate = v
                        -- Если текущий стиль не поддерживается новой раскладкой — сброс на Минимал
                        local curStyle = NecroCat.savedVars.frames.frameStyle or 1
                        if not IsStyleSupported(curStyle, v) then
                            NecroCat.savedVars.frames.frameStyle = 1
                        end
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_FRAME_STYLE),
                tooltip = GetString(SI_NC_LAM_FRAME_STYLE_TT),
                choices = styleNames,
                choicesValues = styleIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.frameStyle) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.frameStyle = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_STYLE_COLOR),
                tooltip = GetString(SI_NC_LAM_STYLE_COLOR_TT),
                choices = { GetString(SI_NC_LAM_COLOR_GREEN), GetString(SI_NC_LAM_COLOR_BLUE) },
                choicesValues = { 1, 2 },
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = Frames.STYLES[styleId]
                    -- Включаем выбор, только если вариантов расцветки БОЛЬШЕ 1:
                    return not (style and style.colorVariants and #style.colorVariants > 1)
                end,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.styleColor) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.styleColor = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_HEALTH_CENTER_FILL),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.healthCenterFill end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.healthCenterFill = v
                        Frames.ApplyLayout()
                    end
                end,
            },

            { type = "header", name = GetString(SI_NC_LAM_TEXT_MODE) },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TEXT_MODE),
                choices = { GetString(SI_NC_LAM_TEXT_MODE_SPLIT), GetString(SI_NC_LAM_TEXT_MODE_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_MODE_CENTER_VAL), GetString(SI_NC_LAM_TEXT_MODE_CENTER_PCT), GetString(SI_NC_LAM_TEXT_MODE_NONE) },
                choicesValues = { 1, 2, 3, 4, 5 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.textMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.textMode = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_SHOW_SHIELD_NUM),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showShieldText ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showShieldText = v
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_SHOW_TRAUMA_NUM),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showTraumaText ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showTraumaText = v
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },

            { type = "header", name = GetString(SI_NC_LAM_HDR_SIZES) },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_FRAME_SCALE),
                tooltip = GetString(SI_NC_LAM_FRAME_SCALE_TT),
                min = 70, max = 150, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.frameScale) or 100 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.frameScale = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_PLAYER_WIDTH),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = Frames.STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = Frames.STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 140, max = 360, step = 10,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.playerWidth) or 200 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.playerWidth = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_PLAYER_HEIGHT),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = Frames.STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = Frames.STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 14, max = 40, step = 2,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.playerHeight) or 20 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.playerHeight = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TEXT_SIZE),
                min = 10, max = 30, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.fontSize) or 14 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.fontSize = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SPACING_X),
                tooltip = GetString(SI_NC_LAM_SPACING_X_TT),
                min = -40, max = 40, step = 1,
                default = 0,
                getFunc = function()
                    return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.spacingOffsetX) or 0
                end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.spacingOffsetX = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SPACING_Y),
                tooltip = GetString(SI_NC_LAM_SPACING_Y_TT),
                min = -40, max = 40, step = 1,
                default = 0,
                getFunc = function()
                    return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.spacingOffsetY) or 0
                end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.spacingOffsetY = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "button",
                name = GetString(SI_NC_LAM_RESET_POS),
                func = function()
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.playerLeft = 450
                        NecroCat.savedVars.frames.playerTop  = 650
                        NecroCat.savedVars.frames.magLeft    = 347
                        NecroCat.savedVars.frames.magTop     = 674
                        NecroCat.savedVars.frames.stamLeft   = 553
                        NecroCat.savedVars.frames.stamTop    = 674
                        NecroCat.savedVars.frames.siegeLeft  = 450
                        NecroCat.savedVars.frames.siegeTop   = 580
                        -- Сбрасываем смещение зазоров в 0:
                        NecroCat.savedVars.frames.spacingOffsetX = 0
                        NecroCat.savedVars.frames.spacingOffsetY = 0
                        Frames.ApplyLayout()
                    end
                end,
            },

            { type = "header", name = GetString(SI_NC_LAM_HDR_SIEGE) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_SIEGE_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeEnabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeEnabled = v
                        Frames.UpdateSiegeBar()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_SIEGE_STYLE),
                tooltip = GetString(SI_NC_LAM_SIEGE_STYLE_TT),
                choices = siegeStyleNames,
                choicesValues = siegeStyleIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeStyle) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeStyle = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_STYLE_COLOR),
                tooltip = GetString(SI_NC_LAM_STYLE_COLOR_TT),
                choices = { GetString(SI_NC_LAM_COLOR_GREEN), GetString(SI_NC_LAM_COLOR_BLUE) },
                choicesValues = { 1, 2 },
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local sId = (sv and sv.siegeStyle) or 1
                    local sStyle = Frames.SIEGE_STYLES[sId]
                    return not (sStyle and sStyle.colorVariants and #sStyle.colorVariants > 1)
                end,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeStyleColor) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeStyleColor = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SIEGE_WIDTH),
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local sId = (sv and sv.siegeStyle) or 1
                    local sStyle = Frames.SIEGE_STYLES[sId]
                    return sStyle and sStyle.hasArt
                end,
                min = 160, max = 500, step = 10,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeWidth) or 300 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeWidth = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SIEGE_HEIGHT),
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local sId = (sv and sv.siegeStyle) or 1
                    local sStyle = Frames.SIEGE_STYLES[sId]
                    return sStyle and sStyle.hasArt
                end,
                min = 10, max = 40, step = 2,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeHeight) or 20 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeHeight = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SIEGE_TITLE_SIZE),
                min = 10, max = 24, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeTitleFontSize) or 14 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeTitleFontSize = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SIEGE_FONT_SIZE),
                min = 10, max = 24, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeFontSize) or 13 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeFontSize = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_SIEGE_TEXT_OFFSET_Y),
                tooltip = GetString(SI_NC_LAM_SIEGE_TEXT_OFFSET_Y_TT),
                min = -10, max = 10, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeLabelOffsetY) or 0 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeLabelOffsetY = v
                        Frames.ApplyLayout()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_SIEGE_TEXT_MODE),
                choices = { GetString(SI_NC_LAM_TEXT_MODE_SPLIT), GetString(SI_NC_LAM_TEXT_MODE_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_MODE_CENTER_VAL), GetString(SI_NC_LAM_TEXT_MODE_CENTER_PCT), GetString(SI_NC_LAM_TEXT_MODE_NONE) },
                choicesValues = { 1, 2, 3, 4, 5 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeTextMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeTextMode = v
                        Frames.ApplyLayout()
                    end
                end,
            },

            { type = "header", name = GetString(SI_NC_LAM_HDR_TEST_SIM) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TEST_SIEGE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.testSiege end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.testSiege = v
                        Frames.UpdateSiegeBar()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TEST_SHIELD),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.testShield end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.testShield = v
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TEST_TRAUMA),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.testTrauma end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.testTrauma = v
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },
            { type = "header", name = GetString(SI_NC_LAM_HDR_BAR_TEXTURES) },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TEX_HEALTH),
                tooltip = GetString(SI_NC_LAM_TEX_HEALTH_TT),
                choices = texNames,
                choicesValues = texIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.healthBarTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.healthBarTexture = v
                        Frames.ApplyBarTextures()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TEX_MAGICKA),
                tooltip = GetString(SI_NC_LAM_TEX_MAGICKA_TT),
                choices = texNames,
                choicesValues = texIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.magickaBarTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.magickaBarTexture = v
                        Frames.ApplyBarTextures()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TEX_STAMINA),
                tooltip = GetString(SI_NC_LAM_TEX_STAMINA_TT),
                choices = texNames,
                choicesValues = texIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.staminaBarTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.staminaBarTexture = v
                        Frames.ApplyBarTextures()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TEX_SIEGE),
                choices = texNames,
                choicesValues = texIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeBarTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeBarTexture = v
                        Frames.ApplyBarTextures()
                    end
                end,
            },
            { type = "header", name = GetString(SI_NC_LAM_HDR_COLORS) },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_TEXT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.textColor) or defaultFramesSV.textColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.textColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_SHIELD_TEXT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.shieldTextColor) or defaultFramesSV.shieldTextColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.shieldTextColor = { r, g, b, a }
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_TRAUMA_TEXT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.traumaTextColor) or defaultFramesSV.traumaTextColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.traumaTextColor = { r, g, b, a }
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_HEALTH),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.healthColor) or defaultFramesSV.healthColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.healthColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_SHIELD),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.shieldColor) or defaultFramesSV.shieldColor
                    return c[1], c[2], c[3], c[4] or 0.55
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.shieldColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_TRAUMA),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.traumaColor) or defaultFramesSV.traumaColor
                    return c[1], c[2], c[3], c[4] or 0.75
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.traumaColor = { r, g, b, a }
                        Frames.ApplyColors()
                        Frames.UpdatePlayerHealth()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_MAGICKA),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.magickaColor) or defaultFramesSV.magickaColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.magickaColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_STAMINA),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.staminaColor) or defaultFramesSV.staminaColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.staminaColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_MOUNT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.mountColor) or defaultFramesSV.mountColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.mountColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_SIEGE),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeColor) or defaultFramesSV.siegeColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COLOR_SIEGE_TEXT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.siegeTextColor) or defaultFramesSV.siegeTextColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.siegeTextColor = { r, g, b, a }
                        Frames.ApplyColors()
                    end
                end,
            },
        },
    }
end

-- 9. СОБЫТИЯ
local function OnPlayerActivated()
    if not (NecroCat.savedVars and NecroCat.savedVars.frames) then
        if NecroCat.savedVars then
            NecroCat.savedVars.frames = ZO_ShallowTableCopy(defaultFramesSV)
        end
    end

    -- Удаляем старый мусор из файла сохранений
    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
    if sv then
        sv.spacingX = nil
        sv.spacingY = nil
    end

    Frames.CreatePlayerFrame()
    Frames.ApplyLayout()
    Frames.UpdateDefaultBarsVisibility()
    Frames.UpdateSiegeBar()
end

local function OnPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if unitTag ~= "player" then return end

    if powerType == POWERTYPE_HEALTH then
        Frames.UpdatePlayerHealth()
    elseif powerType == POWERTYPE_MAGICKA then
        Frames.UpdatePlayerMagicka()
    elseif powerType == POWERTYPE_STAMINA then
        Frames.UpdatePlayerStamina()
    elseif powerType == POWERTYPE_MOUNT_STAMINA then
        Frames.UpdateMountStamina()
    end
end

local function OnVisualChanged(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, value, maxValue, sequenceId)
    if unitTag == "player" and (unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA) then
        Frames.UpdatePlayerHealth()
    end
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_Power", EVENT_POWER_UPDATE, OnPowerUpdate)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Frames_Power", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_VisualAdd", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Frames_VisualAdd", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_VisualUpd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Frames_VisualUpd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_VisualRem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Frames_VisualRem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_Mounted", EVENT_MOUNTED_STATE_CHANGED, function()
    Frames.UpdateMountStamina()
end)

-- События осадного орудия
EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_SiegeBegin", EVENT_BEGIN_SIEGE_CONTROL, function()
    Frames.UpdateSiegeBar()
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_SiegeEnd", EVENT_END_SIEGE_CONTROL, function()
    if Frames.SiegeFrame then
        Frames.SiegeFrame:SetHidden(true)
    end
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_Frames_SiegePower", EVENT_POWER_UPDATE, function(eventCode, unitTag, powerIndex, powerType)
    if powerType == POWERTYPE_HEALTH then
        Frames.UpdateSiegeBar()
    end
end)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Frames_SiegePower", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "controlledsiege")