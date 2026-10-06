-- =========================================================
-- NecroCat: Companion Frames Module (Фреймы спутников)
-- =========================================================

if not NecroCat then NecroCat = {} end
NecroCat.Companion = NecroCat.Companion or {}
local CF = NecroCat.Companion

local HEADER_HEIGHT      = 18
local BASE_TEXT_OFFSET_Y = 2

-- 1. НАСТРОЙКИ ПО УМОЛЧАНИЮ
local defaultCompanionSV = {
    enabled            = false,
    locked             = false,
    companionScope     = 1,     -- 1: Только мой, 2: Все в группе
    compLeft           = 300,
    compTop            = 700,
    frameScale         = 100,
    frameWidth         = 210,   -- Ширина полоски ХП
    barHeight          = 26,    -- Толщина полоски ХП
    spacingY           = 4,     -- Зазор между спутниками в столбике
    showPortrait       = true,  -- Показывать аватарку лица
    showRapport        = true,  -- Показывать шкалу отношений [+5500]
    frameStyle         = 1,     -- 1: Минимал, 2: Кот, 3: Мыши
    barTexture         = 1,     -- 1: Гладкая, 2: Кровь, 3: Руны
    nameFontSize       = 14,
    healthFontSize     = 14,
    showShieldText     = true,
    testMode           = false,  -- Симуляция для настройки
    attachMode         = 1,     -- 1: Отдельный столбик, 2: В группе (под владельцем)

    -- Цвета
    healthColor        = { 0.16, 0.62, 0.45, 1.0 }, -- Изумрудный спутник
    shieldColor        = { 0.25, 0.75, 0.95, 0.65 },
    textColor          = { 1.0, 1.0, 1.0, 1.0 },
    shieldTextColor    = { 0.35, 0.85, 1.0, 1.0 },
}

-- =========================================================
-- ТАБЛИЦА СТИЛЕЙ ОФОРМЛЕНИЯ СПУТНИКА
-- =========================================================
CF.STYLES = {
    -- 1. СТИЛЬ ПО УМОЛЧАНИЮ (МИНИМАЛИЗМ)
    [1] = {
        id           = 1,
        name         = "SI_NC_LAM_STYLE_DEFAULT",
        hasArt       = false,
        barW         = 210,
        barH         = 26,
        insetX       = 1,
        insetY       = 1,
        labelPadX    = 5,
        labelOffsetY = 0,
    },

    -- 2. ВАМПИРСКАЯ ГОТИКА
    [2] = {
        id           = 2,
        name         = "SI_NC_LAM_STYLE_VAMPIRE",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/two_backplate.dds",
            },
        },
        artW         = 230,
        artH         = 92,
        artOffsetX   = 0,
        artOffsetY   = 5,
        barW         = 205,
        barH         = 29,
        insetX       = 2,
        insetY       = 2,
        labelPadX    = 6,
        labelOffsetY = 0,
    },

    -- 3. НЕКРОКОШКА
    [3] = {
        id           = 3,
        name         = "SI_NC_LAM_STYLE_CAT",
        hasArt       = true,
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
        artW         = 245,
        artH         = 112,
        artOffsetX   = 1,
        artOffsetY   = -9,
        barW         = 205,
        barH         = 29,
        insetX       = 2,
        insetY       = 2,
        labelPadX    = 6,
        labelOffsetY = 0,
    },

    -- 4. ЛЕТУЧИЕ МЫШИ
    [4] = {
        id           = 4,
        name         = "SI_NC_LAM_STYLE_BAT",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/two_backplate_bat.dds",
            },
        },
        artW         = 230,
        artH         = 80,
        artOffsetX   = -1,
        artOffsetY   = 0,
        barW         = 205,
        barH         = 29,
        insetX       = 2,
        insetY       = 2,
        labelPadX    = 6,
        labelOffsetY = 0,
    },
}

-- =========================================================
-- БИБЛИОТЕКА ТЕКСТУР ЗАПОЛНЕНИЯ ПОЛОС СПУТНИКА
-- =========================================================
CF.BAR_TEXTURES = {
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

function CF.GetBarTextureChoices()
    local names, ids = {}, {}
    for id = 1, #CF.BAR_TEXTURES do
        local tex = CF.BAR_TEXTURES[id]
        if tex then
            local str = GetString(_G[tex.name] or tex.name)
            table.insert(names, str)
            table.insert(ids, id)
        end
    end
    return names, ids
end

-- Карта официальных ачивок с лицами от ZOS
CF.COMPANION_ACHIEVEMENTS = {
    [1]  = 3067, -- Бастиан Галликс
    [2]  = 3068, -- Мирри Элендис
    [5]  = 3263, -- Эмбер
    [6]  = 3266, -- Изобель Велуаз
    [8]  = 3690, -- Ясный-как-Ночь
    [9]  = 3693, -- Азандар аль-Кибиадес
    [12] = 4244, -- Танлорин
    [13] = 4247, -- Зерит-вар
}

-- Таблица персональных портретов спутников по DefId
--/script d("Новый спутник:", GetActiveCompanionDefId(), GetUnitName("companion"))
CF.COMPANION_PORTRAITS = {
    --[1]  = "NecroCat/imgs/companions/bastian.dds",
    --[2]  = "NecroCat/imgs/companions/mirri.dds",
    --[5]  = "NecroCat/imgs/companions/ember.dds",
    --[6]  = "NecroCat/imgs/companions/isobel.dds",
    --[8]  = "NecroCat/imgs/companions/sharp.dds",
    --[9]  = "NecroCat/imgs/companions/azandar.dds",
    --[12] = "NecroCat/imgs/companions/tanlorin.dds",
    --[13] = "NecroCat/imgs/companions/zerith.dds",
}

CF.FALLBACK_PORTRAIT = "EsoUI/Art/Icons/icon_companion.dds"

local function GetCompanionStyleChoices()
    local names, ids = {}, {}
    for id, st in ipairs(CF.STYLES) do
        local str = GetString(_G[st.name] or st.name)
        table.insert(names, str)
        table.insert(ids, id)
    end
    return names, ids
end

local function GetOrCreateChild(parent, name, controlType)
    local child = parent:GetNamedChild(name)
    if child then return child end
    return WINDOW_MANAGER:CreateControl("$(parent)" .. name, parent, controlType)
end

local function GetCompanionDefIdByName(name)
    if not name or name == "" then return 0 end
    -- Отрезаем суффиксы рода/падежей (^Fx, ^M и т.д.) до значка ^
    local cleanTarget = zo_strlower(zo_strtrim(name:match("^([^^]+)") or name))
    for defId in pairs(CF.COMPANION_ACHIEVEMENTS) do
        local cName = GetCompanionName(defId)
        if cName and cName ~= "" then
            local cleanComp = zo_strlower(zo_strtrim(cName:match("^([^^]+)") or cName))
            if cleanComp == cleanTarget then
                return defId
            end
        end
    end
    return 0
end

function CF.GetCompanionPortrait(defId)
    local custom = CF.COMPANION_PORTRAITS and CF.COMPANION_PORTRAITS[defId]
    if custom and custom ~= "" then return custom end

    local achId = CF.COMPANION_ACHIEVEMENTS[defId]
    if achId then
        local _, _, _, icon = GetAchievementInfo(achId)
        if icon and icon ~= "" and icon ~= "/esoui/art/icons/icon_missing.dds" then
            return icon
        end
    end
    return CF.FALLBACK_PORTRAIT
end

local function FormatValueNumber(value)
    if not value then return "0" end
    if value >= 1000000 then return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then return string.format("%.1fk", value / 1000)
    else return ZO_LocalizeDecimalNumber(value) end
end

local function RgbToHex(c)
    if not c then return "ffffff" end
    local r = zo_clamp(math.floor((c[1] or 1) * 255), 0, 255)
    local g = zo_clamp(math.floor((c[2] or 1) * 255), 0, 255)
    local b = zo_clamp(math.floor((c[3] or 1) * 255), 0, 255)
    return string.format("%02x%02x%02x", r, g, b)
end

-- Короткое имя спутника + ник владельца на первом месте (в группе — только имя)
local function FormatCompanionDisplay(ownerId, compName, isDocked)
    if isDocked then
        return compName or "Спутник"
    end
    local shortName = compName and compName:match("^(%S+)") or compName or "Спутник"
    if ownerId and ownerId ~= "" then
        return string.format("%s (%s)", ownerId, shortName)
    end
    return shortName
end

local function GetRapportColor(val)
    if val >= 1500 then return "44ff77"
    elseif val <= -1500 then return "ff4433"
    else return "e0e0e0" end
end

-- =========================================================
-- 2. СОЗДАНИЕ ПУЛА ИЗ 12 ПЛАШЕК СПУТНИКОВ
-- =========================================================
CF.framePool = {}
CF.rootFrame = nil

function CF.CreateFramePool()
    if CF.rootFrame then return end

    local sv = (NecroCat.savedVars and NecroCat.savedVars.companion) or defaultCompanionSV
    local styleId = sv.frameStyle or 1
    local style   = CF.STYLES[styleId] or CF.STYLES[1]

    local bHeight = (style.hasArt and style.barH) or sv.barHeight or 26
    local totalH  = HEADER_HEIGHT + bHeight
    local fWidth  = (style.hasArt and style.barW) or sv.frameWidth or 210

    local root = _G["NecroCat_CompRoot"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_CompRoot")
    root:SetDimensions(totalH + 6 + fWidth, totalH)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.compLeft or 300, sv.compTop or 650)
    root:SetMovable(not sv.locked)
    root:SetMouseEnabled(not sv.locked)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_HIGH)

    root:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.companion then
            NecroCat.savedVars.companion.compLeft = self:GetLeft()
            NecroCat.savedVars.companion.compTop  = self:GetTop()
        end
    end)

    CF.rootFrame = root

    local function BindDrag(ctrl)
        ctrl:SetMouseEnabled(true)
        ctrl:SetHandler("OnMouseDown", function(self, button)
            local s = NecroCat and NecroCat.savedVars and NecroCat.savedVars.companion
            if button == 1 and s and not s.locked and CF.rootFrame then
                CF.rootFrame:StartMoving()
            end
        end)
        ctrl:SetHandler("OnMouseUp", function(self, button)
            local s = NecroCat and NecroCat.savedVars and NecroCat.savedVars.companion
            if button == 1 and s and not s.locked and CF.rootFrame then
                CF.rootFrame:StopMovingOrResizing()
                CF.rootFrame:ClearAnchors()
                CF.rootFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CF.rootFrame:GetLeft(), CF.rootFrame:GetTop())
                s.compLeft = CF.rootFrame:GetLeft()
                s.compTop  = CF.rootFrame:GetTop()
            end
        end)
    end

    BindDrag(root)

    for i = 1, 12 do
        local frame = _G["NecroCat_CompFrame_" .. i] or WINDOW_MANAGER:CreateControl("NecroCat_CompFrame_" .. i, root, CT_CONTROL)
        frame:SetDimensions(totalH + 6 + fWidth, totalH)
        frame:SetHidden(true)

        -- 1. Портрет лица (идеальный квадрат во всю высоту)
        local portrait = GetOrCreateChild(frame, "Portrait", CT_TEXTURE)
        portrait:SetDimensions(totalH, totalH)
        portrait:ClearAnchors()
        portrait:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
        portrait:SetDrawLayer(DL_CONTROLS)
        portrait:SetDrawLevel(2)

        -- 2. Контейнер шапки и бара
        local body = GetOrCreateChild(frame, "Body", CT_CONTROL)
        body:SetDimensions(fWidth, totalH)
        body:ClearAnchors()
        body:SetAnchor(TOPLEFT, portrait, TOPRIGHT, 6, 0)

        local nameLabel = GetOrCreateChild(body, "Name", CT_LABEL)
        nameLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.nameFontSize or 14))
        nameLabel:SetAnchor(TOPLEFT, body, TOPLEFT, 2, 0)
        nameLabel:SetColor(1, 1, 1, 1)

        local levelLabel = GetOrCreateChild(body, "Level", CT_LABEL)
        levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", math.max(10, (sv.nameFontSize or 14) - 2)))
        levelLabel:SetAnchor(TOPRIGHT, body, TOPRIGHT, -2, 0)
        levelLabel:SetColor(0.85, 0.85, 0.85, 1)

        nameLabel:SetAnchor(RIGHT, levelLabel, LEFT, -4, 0)
        nameLabel:SetMaxLineCount(1)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        local barContainer = GetOrCreateChild(body, "BarContainer", CT_CONTROL)
        barContainer:SetAnchor(TOPLEFT, body, TOPLEFT, 0, HEADER_HEIGHT)
        barContainer:SetDimensions(fWidth, bHeight)

        local bg = GetOrCreateChild(barContainer, "BG", CT_BACKDROP)
        bg:SetAnchorFill(barContainer)
        bg:SetCenterColor(0.04, 0.04, 0.04, 0.92)
        bg:SetEdgeColor(0.18, 0.18, 0.18, 1.0)
        bg:SetEdgeTexture("", 8, 1, 1)
        bg:SetDrawLayer(DL_BACKGROUND)
        bg:SetDrawLevel(1)

        local artBG = GetOrCreateChild(barContainer, "ArtBG", CT_TEXTURE)
        artBG:SetDrawLayer(DL_BACKGROUND)
        artBG:SetDrawLevel(2)
        artBG:SetHidden(true)

        local healthBar = GetOrCreateChild(barContainer, "HealthBar", CT_STATUSBAR)
        healthBar:ClearAnchors()
        healthBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 1, 1)
        healthBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -1, -1)
        healthBar:SetDrawLayer(DL_CONTROLS)
        healthBar:SetDrawLevel(1)

        local shieldBar = GetOrCreateChild(barContainer, "ShieldBar", CT_STATUSBAR)
        shieldBar:ClearAnchors()
        shieldBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 1, 1)
        shieldBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -1, -1)
        shieldBar:SetDrawLayer(DL_CONTROLS)
        shieldBar:SetDrawLevel(2)
        shieldBar:SetHidden(true)

        local traumaBar = GetOrCreateChild(barContainer, "TraumaBar", CT_STATUSBAR)
        traumaBar:ClearAnchors()
        traumaBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 1, 1)
        traumaBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -1, -1)
        traumaBar:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
        traumaBar:SetDrawLayer(DL_CONTROLS)
        traumaBar:SetDrawLevel(3)
        traumaBar:SetHidden(true)

        local hpLeftLabel = GetOrCreateChild(barContainer, "HPLeft", CT_LABEL)
        hpLeftLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.healthFontSize or 14))
        hpLeftLabel:SetAnchor(LEFT, barContainer, LEFT, 5, 2)
        hpLeftLabel:SetDrawLayer(DL_OVERLAY)
        hpLeftLabel:SetDrawLevel(4)

        local hpRightLabel = GetOrCreateChild(barContainer, "HPRight", CT_LABEL)
        hpRightLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.healthFontSize or 14))
        hpRightLabel:SetAnchor(RIGHT, barContainer, RIGHT, -5, 2)
        hpRightLabel:SetDrawLayer(DL_OVERLAY)
        hpRightLabel:SetDrawLevel(4)

        local statusLabel = GetOrCreateChild(barContainer, "StatusLabel", CT_LABEL)
        statusLabel:SetFont(string.format("$(BOLD_FONT)|14|thick-outline"))
        statusLabel:SetAnchor(CENTER, barContainer, CENTER, 0, 2)
        statusLabel:SetDrawLayer(DL_OVERLAY)
        statusLabel:SetDrawLevel(5)
        statusLabel:SetHidden(true)

        BindDrag(frame)
        BindDrag(portrait)
        BindDrag(body)
        BindDrag(barContainer)

        frame.portrait     = portrait
        frame.body         = body
        frame.nameLabel    = nameLabel
        frame.levelLabel   = levelLabel
        frame.barContainer = barContainer
        frame.bg           = bg
        frame.artBG        = artBG
        frame.healthBar    = healthBar
        frame.shieldBar    = shieldBar
        frame.traumaBar    = traumaBar
        frame.hpLeftLabel  = hpLeftLabel
        frame.hpRightLabel = hpRightLabel
        frame.statusLabel  = statusLabel

        CF.framePool[i] = frame
    end

    CF.CompanionFragment = ZO_SimpleSceneFragment:New(root)
    CF.ApplySettings()
    CF.UpdateVisibility()
end

-- =========================================================
-- 3. МАТЕМАТИКА ВЕРТИКАЛЬНОГО СТОЛБИКА СПУТНИКОВ
-- =========================================================
function CF.LayoutColumn(activeCount)
    if not CF.rootFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.companion) or defaultCompanionSV
    local styleId = sv.frameStyle or 1
    local style   = CF.STYLES[styleId] or CF.STYLES[1]

    local count = activeCount or 0
    if count == 0 then
        for i = 1, 12 do CF.framePool[i]:SetHidden(true) end
        return
    end

    local fWidth  = (style.hasArt and style.barW) or sv.frameWidth or 210
    local bHeight = (style.hasArt and style.barH) or sv.barHeight or 26
    local totalH  = HEADER_HEIGHT + bHeight
    local spY     = sv.spacingY or 4
    local totalW  = (sv.showPortrait ~= false) and (totalH + 6 + fWidth) or fWidth

    CF.rootFrame:SetDimensions(totalW, totalH * count + spY * (count - 1))

    for i = 1, 12 do
        local f = CF.framePool[i]
        if i <= count then
            f:SetDimensions(totalW, totalH)
            f:ClearAnchors()
            local offsetY = (i - 1) * (totalH + spY)
            f:SetAnchor(TOPLEFT, CF.rootFrame, TOPLEFT, 0, offsetY)
            f:SetHidden(false)
        else
            f:SetHidden(true)
        end
    end
end

-- Высота плашки спутника для расчёта зазоров группы
function CF.GetTotalHeight()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.companion) or defaultCompanionSV
    local styleId = sv.frameStyle or 1
    local style   = CF.STYLES[styleId] or CF.STYLES[1]
    local bHeight = (style.hasArt and style.barH) or sv.barHeight or 26
    return HEADER_HEIGHT + bHeight
end

-- Проверка, есть ли у юнита активный спутник для отображения в группе
function CF.HasCompanionForUnit(unitTag)
    local sv = NecroCat.savedVars and NecroCat.savedVars.companion
    if not (sv and sv.enabled and sv.attachMode == 2) then return false end
    if AreUnitsEqual(unitTag, "player") then
        return HasActiveCompanion()
    elseif sv.companionScope == 2 and GetCompanionUnitTagByGroupUnitTag then
        local cTag = GetCompanionUnitTagByGroupUnitTag(unitTag)
        return cTag ~= nil and DoesUnitExist(cTag)
    end
    return false
end

-- =========================================================
-- 4. ЖИВОЕ ПРИМЕНЕНИЕ НАСТРОЕК
-- =========================================================
function CF.ApplySettings()
    if not CF.rootFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.companion) or defaultCompanionSV
    local styleId = sv.frameStyle or 1
    local style   = CF.STYLES[styleId] or CF.STYLES[1]

    -- Находим картинку из выбранного комплекта расцветки:
    local colorId = sv.styleColor or 1
    local variant = (style.colorVariants and style.colorVariants[colorId]) or (style.colorVariants and style.colorVariants[1])
    local artTex  = (variant and variant.art) or style.artTexture

    local isUnlocked = not sv.locked
    CF.rootFrame:SetMovable(isUnlocked)
    CF.rootFrame:SetMouseEnabled(isUnlocked)
    
    -- Масштаб всего столбика спутников (70-150%)
    local scale = (sv.frameScale or 100) / 100
    CF.rootFrame:SetScale(scale)

    local inGroup    = IsUnitGrouped("player") or (GetGroupSize() > 0)
    local isDocked   = (sv.attachMode == 2) and inGroup

    local fWidth     = (style.hasArt and style.barW) or sv.frameWidth or 210
    local bHeight    = (style.hasArt and style.barH) or sv.barHeight or 26
    local totalH     = HEADER_HEIGHT + bHeight
    local textOffY   = BASE_TEXT_OFFSET_Y + (sv.textOffsetY or 0) + (style.labelOffsetY or 0)
    local padX       = style.labelPadX or 5
    local texCfg     = CF.BAR_TEXTURES[sv.barTexture or 1] or CF.BAR_TEXTURES[1]
    local barTexPath = texCfg and texCfg.path

    for i = 1, 12 do
        local f = CF.framePool[i]
        if f then
            f.barContainer:SetDimensions(fWidth, bHeight)
            f.body:SetDimensions(fWidth, totalH)

            if isDocked then
                -- РЕЖИМ В ГРУППЕ: мини-аватарка 16х16 в шапке рядом с именем
                local iconSize = 16
                f:SetDimensions(fWidth, totalH)

                f.body:ClearAnchors()
                f.body:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0)

                f.nameLabel:ClearAnchors()
                if sv.showPortrait ~= false then
                    f.portrait:SetDimensions(iconSize, iconSize)
                    f.portrait:ClearAnchors()
                    f.portrait:SetAnchor(TOPLEFT, f.body, TOPLEFT, 2, 1)
                    f.portrait:SetHidden(false)

                    f.nameLabel:SetAnchor(TOPLEFT, f.body, TOPLEFT, iconSize + 6, 0)
                else
                    f.portrait:SetHidden(true)
                    f.nameLabel:SetAnchor(TOPLEFT, f.body, TOPLEFT, 2, 0)
                end
                f.nameLabel:SetAnchor(RIGHT, f.levelLabel, LEFT, -4, 0)
            else
                -- РЕЖИМ ОТДЕЛЬНО: большой квадратный портрет во всю высоту сбоку
                f.portrait:SetDimensions(totalH, totalH)
                f.portrait:ClearAnchors()
                f.portrait:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0)

                f.nameLabel:ClearAnchors()
                f.nameLabel:SetAnchor(TOPLEFT, f.body, TOPLEFT, 2, 0)
                f.nameLabel:SetAnchor(RIGHT, f.levelLabel, LEFT, -4, 0)

                if sv.showPortrait ~= false then
                    f.portrait:SetHidden(false)
                    f.body:ClearAnchors()
                    f.body:SetAnchor(TOPLEFT, f.portrait, TOPRIGHT, 6, 0)
                    f:SetDimensions(totalH + 6 + fWidth, totalH)
                else
                    f.portrait:SetHidden(true)
                    f.body:ClearAnchors()
                    f.body:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0)
                    f:SetDimensions(fWidth, totalH)
                end
            end

            -- Рамка стиля
            if style.hasArt and artTex and artTex ~= "" then
                f.artBG:SetHidden(false)
                f.artBG:SetTexture(artTex)
                f.artBG:SetDimensions(style.artW or fWidth, style.artH or bHeight)
                f.artBG:ClearAnchors()
                f.artBG:SetAnchor(CENTER, f.barContainer, CENTER, style.artOffsetX or 0, style.artOffsetY or 0)
                f.bg:SetHidden(true)
            else
                f.artBG:SetHidden(true)
                f.bg:SetHidden(false)
            end

            -- Отступы полоски внутри желоба
            local inX = style.insetX or 1
            local inY = style.insetY or 1

            f.healthBar:ClearAnchors()
            f.healthBar:SetAnchor(TOPLEFT, f.barContainer, TOPLEFT, inX, inY)
            f.healthBar:SetAnchor(BOTTOMRIGHT, f.barContainer, BOTTOMRIGHT, -inX, -inY)

            f.shieldBar:ClearAnchors()
            f.shieldBar:SetAnchor(TOPLEFT, f.barContainer, TOPLEFT, inX, inY)
            f.shieldBar:SetAnchor(BOTTOMRIGHT, f.barContainer, BOTTOMRIGHT, -inX, -inY)

            f.traumaBar:ClearAnchors()
            f.traumaBar:SetAnchor(TOPLEFT, f.barContainer, TOPLEFT, inX, inY)
            f.traumaBar:SetAnchor(BOTTOMRIGHT, f.barContainer, BOTTOMRIGHT, -inX, -inY)

            -- Текстура полосы
            if sv.barTexture and sv.barTexture > 1 then
                f.healthBar:SetTexture(barTexPath)
            else
                f.healthBar:SetTexture(nil)
            end

            -- Шрифты
            local nameFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.nameFontSize or 14)
            local hpFont   = string.format("$(BOLD_FONT)|%d|thick-outline", sv.healthFontSize or 14)

            f.nameLabel:SetFont(nameFont)
            f.levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", math.max(10, (sv.nameFontSize or 14) - 2)))
            f.hpLeftLabel:SetFont(hpFont)
            f.hpRightLabel:SetFont(hpFont)

            local textMode = sv.textMode or 1
            f.hpLeftLabel:ClearAnchors()
            f.hpRightLabel:ClearAnchors()

            if textMode == 1 then
                f.hpLeftLabel:SetAnchor(LEFT, f.barContainer, LEFT, padX, textOffY)
                f.hpLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                f.hpLeftLabel:SetHidden(false)

                f.hpRightLabel:SetAnchor(RIGHT, f.barContainer, RIGHT, -padX, textOffY)
                f.hpRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                f.hpRightLabel:SetHidden(false)
            elseif textMode == 2 or textMode == 3 or textMode == 4 then
                f.hpLeftLabel:SetHidden(true)
                f.hpRightLabel:SetAnchor(CENTER, f.barContainer, CENTER, 0, textOffY)
                f.hpRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                f.hpRightLabel:SetHidden(false)
            elseif textMode == 5 then
                f.hpLeftLabel:SetHidden(true)
                f.hpRightLabel:SetHidden(true)
            end
        end
    end

    CF.Update()
end

-- =========================================================
-- 5. ОБНОВЛЕНИЕ ДАННЫХ И СТОЛБИКА
-- =========================================================
local MOCK_COMPANIONS = {
    [1] = { name = "Изобель Велуаз", owner = "@IronWall",  defId = 6, lvl = 20, cur = 26000, max = 30000, shield = 8000, rap = 5500 },
    [2] = { name = "Эмбер",          owner = "@HolyLight", defId = 5, lvl = 20, cur = 28000, max = 28000, shield = 0,    rap = 4200 },
    [3] = { name = "Ясный-как-Ночь", owner = "@BloodMage", defId = 8, lvl = 20, cur = 12000, max = 30000, shield = 0,    rap = 2800 },
}

function CF.Update()
    if not CF.rootFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.companion) or defaultCompanionSV

    if not sv.enabled then
        CF.rootFrame:SetHidden(true)
        return
    end

    local isTest = sv.testMode
    local inGroup = IsUnitGrouped("player") or (GetGroupSize() > 0) or isTest
    local isDocked = (sv.attachMode == 2) and inGroup

    -- Если статус группы изменился (соло <-> группа) — мгновенно перестраиваем форму плашки
    if CF.lastDockedState ~= isDocked then
        CF.lastDockedState = isDocked
        CF.ApplySettings()
        return
    end

    -- Тестовая симуляция столбика спутников
    if isTest then
        local testCount = (sv.companionScope == 2) and 3 or 1

        CF.rootFrame:SetHidden(false)
        CF.LayoutColumn(testCount)

        for i = 1, testCount do
            local f = CF.framePool[i]
            local m = MOCK_COMPANIONS[i]
            if f and m then
                f:SetAlpha(1.0)
                f.nameLabel:SetText(FormatCompanionDisplay(m.owner, m.name, isDocked))
                local pTex = CF.GetCompanionPortrait(m.defId)
                f.portrait:SetTexture(pTex)

                if sv.showRapport ~= false then
                    local rapHex = GetRapportColor(m.rap)
                    f.levelLabel:SetText(string.format("ур. %d |c%s[%+d]|r", m.lvl, rapHex, m.rap))
                else
                    f.levelLabel:SetText(string.format("ур. %d", m.lvl))
                end

                local hc = sv.healthColor or defaultCompanionSV.healthColor
                f.healthBar:SetColor(hc[1], hc[2], hc[3], hc[4] or 1)
                f.healthBar:SetMinMax(0, m.max)
                f.healthBar:SetValue(m.cur)
                f.healthBar:SetHidden(false)
                f.statusLabel:SetHidden(true)

                if m.shield > 0 then
                    local sc = sv.shieldColor or defaultCompanionSV.shieldColor
                    f.shieldBar:SetColor(sc[1], sc[2], sc[3], sc[4])
                    f.shieldBar:SetMinMax(0, m.max)
                    f.shieldBar:SetValue(m.shield)
                    f.shieldBar:SetHidden(false)
                else
                    f.shieldBar:SetHidden(true)
                end

                f:SetAlpha(1.0)
                local textMode = sv.textMode or 1
                if textMode == 5 then
                    f.hpLeftLabel:SetHidden(true)
                    f.hpRightLabel:SetHidden(true)
                else
                    local pct = math.floor((m.cur / m.max) * 100)
                    local shieldHex = RgbToHex(sv.shieldTextColor or defaultCompanionSV.shieldTextColor)
                    local extra = ""
                    if m.shield > 0 and sv.showShieldText ~= false then
                        extra = extra .. string.format(" |c%s[+%s]|r", shieldHex, FormatValueNumber(m.shield))
                    end

                    if textMode == 1 then
                        f.hpLeftLabel:SetHidden(false)
                        f.hpRightLabel:SetHidden(false)
                        f.hpLeftLabel:SetText(string.format("%s%s", FormatValueNumber(m.cur), extra))
                        f.hpRightLabel:SetText(string.format("%d%%", pct))
                    elseif textMode == 2 then
                        f.hpLeftLabel:SetHidden(true)
                        f.hpRightLabel:SetHidden(false)
                        f.hpRightLabel:SetText(string.format("%s%s (%d%%)", FormatValueNumber(m.cur), extra, pct))
                    elseif textMode == 3 then
                        f.hpLeftLabel:SetHidden(true)
                        f.hpRightLabel:SetHidden(false)
                        f.hpRightLabel:SetText(string.format("%s%s", FormatValueNumber(m.cur), extra))
                    elseif textMode == 4 then
                        f.hpLeftLabel:SetHidden(true)
                        f.hpRightLabel:SetHidden(false)
                        f.hpRightLabel:SetText(string.format("%d%%%s", pct, extra))
                    end
                end
            end
        end
        return
    end

    -- Сбор всех спутников (своего + группы)
    local compList = {}

    -- 1. Свой личный спутник
    if HasActiveCompanion() then
        table.insert(compList, {
            unitTag  = "companion",
            ownerTag = "player",
            owner    = GetUnitDisplayName("player"),
            defId    = (GetActiveCompanionDefId and GetActiveCompanionDefId()) or 0,
            isOwn    = true,
        })
    end

    -- 2. Спутники сопартийцев (если включен режим «Всех в группе»)
    if sv.companionScope == 2 and GetGroupSize() > 0 and GetCompanionUnitTagByGroupUnitTag then
        for i = 1, 24 do
            local gTag = "group" .. i
            if DoesUnitExist(gTag) and not AreUnitsEqual(gTag, "player") then
                local cTag = GetCompanionUnitTagByGroupUnitTag(gTag)
                if cTag and DoesUnitExist(cTag) then
                    local realName = GetRawUnitName(cTag)
                    if not realName or realName == "" then realName = GetUnitName(cTag) end
                    table.insert(compList, {
                        unitTag  = cTag,
                        ownerTag = gTag,
                        owner    = GetUnitDisplayName(gTag),
                        defId    = GetCompanionDefIdByName(realName),
                        isOwn    = false,
                    })
                end
            end
        end
    end

    local activeCount = #compList

    -- Если спутников нет вообще — намертво гасим всё окно и все 12 плашек
    if activeCount == 0 then
        CF.rootFrame:SetHidden(true)
        for i = 1, 12 do
            local f = CF.framePool[i]
            if f then f:SetHidden(true) end
        end
        CF.LayoutColumn(0)
        return
    end

    CF.rootFrame:SetHidden(false)
    if isDocked then
        CF.rootFrame:SetMovable(false)
        CF.rootFrame:SetMouseEnabled(false)
    else
        CF.LayoutColumn(activeCount)
    end

    for i = 1, 12 do
        local f = CF.framePool[i]
        if f then
            if i <= activeCount then
                local data = compList[i]
                if data then
                    f.unitTag = data.unitTag
    local rawName = GetRawUnitName(data.unitTag)
    if not rawName or rawName == "" then rawName = GetUnitName(data.unitTag) or "Спутник" end
    rawName = rawName:match("^([^^]+)") or rawName
    f.nameLabel:SetText(FormatCompanionDisplay(data.owner, rawName, isDocked))

                    local pTex = (data.defId > 0 and CF.GetCompanionPortrait(data.defId)) or CF.FALLBACK_PORTRAIT
                    f.portrait:SetTexture(pTex)

                    local levelStr = string.format("ур. %d", GetUnitLevel(data.unitTag) or 20)
                    if data.isOwn and sv.showRapport ~= false then
                        local rap = (GetActiveCompanionRapport and GetActiveCompanionRapport()) or 0
                        f.levelLabel:SetText(string.format("%s |c%s[%+d]|r", levelStr, GetRapportColor(rap), rap))
                    else
                        f.levelLabel:SetText(levelStr)
                    end

                    -- Прикрепление под плашку владельца в группе
                    if isDocked and data.ownerTag then
                        local gf = NecroCat.GroupFrames and NecroCat.GroupFrames.unitToFrame
                        local ownerFrame = gf and (gf[data.ownerTag] or (AreUnitsEqual(data.ownerTag, "player") and gf["player"]))
                        if ownerFrame then
                            f:ClearAnchors()
                            local compSpY = sv.spacingY or 2
                            f:SetAnchor(TOPLEFT, ownerFrame, BOTTOMLEFT, 0, compSpY)
                            f:SetHidden(false)
                        else
                            f:SetHidden(true)
                        end
                    end

                    local isDead = IsUnitDead(data.unitTag)
                    local curHealth, maxHealth = GetUnitPower(data.unitTag, POWERTYPE_HEALTH)
                    if maxHealth <= 0 then maxHealth = 1 end

                    local hc = sv.healthColor or defaultCompanionSV.healthColor
                    f.healthBar:SetColor(hc[1], hc[2], hc[3], hc[4] or 1)

                    if isDead then
                        f.healthBar:SetHidden(true); f.shieldBar:SetHidden(true)
                        f.hpLeftLabel:SetHidden(true); f.hpRightLabel:SetHidden(true)
                        f.statusLabel:SetText("МЁРТВ"); f.statusLabel:SetColor(0.9, 0.2, 0.2, 1)
                        f.statusLabel:SetHidden(false)
                    else
                        f.statusLabel:SetHidden(true); f.healthBar:SetHidden(false)
                        f.hpLeftLabel:SetHidden(false); f.hpRightLabel:SetHidden(false)
                        f.healthBar:SetMinMax(0, maxHealth); f.healthBar:SetValue(curHealth)

                        local inRange = IsUnitInGroupSupportRange(data.unitTag)
                        f:SetAlpha(inRange and 1.0 or (sv.outOfRangeAlpha or 0.60))

                        local shieldVal = 0
                        if GetUnitAttributeVisualizerEffectInfo then
                            shieldVal = GetUnitAttributeVisualizerEffectInfo(data.unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
                        end

                        if shieldVal > 0 then
                            local sc = sv.shieldColor or defaultCompanionSV.shieldColor
                            f.shieldBar:SetColor(sc[1], sc[2], sc[3], sc[4])
                            f.shieldBar:SetMinMax(0, maxHealth); f.shieldBar:SetValue(shieldVal)
                            f.shieldBar:SetHidden(false)
                        else
                            f.shieldBar:SetHidden(true)
                        end

                        local pct = math.floor((curHealth / maxHealth) * 100)
                        local shieldHex = RgbToHex(sv.shieldTextColor or defaultCompanionSV.shieldTextColor)
                        local extra = ""
                        if shieldVal > 0 and sv.showShieldText ~= false then
                            extra = extra .. string.format(" |c%s[+%s]|r", shieldHex, FormatValueNumber(shieldVal))
                        end

                        f.hpLeftLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extra))
                        f.hpRightLabel:SetText(string.format("%d%%", pct))
                    end
                end
            else
                -- Если спутников меньше, чем слотов — принудительно скрываем пустые плашки
                f:SetHidden(true)
            end
        end
    end
end

-- =========================================================
-- 6. УПРАВЛЕНИЕ ВИДИМОСТЬЮ В СЦЕНАХ
-- =========================================================
function CF.UpdateVisibility()
    if not CF.CompanionFragment then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.companion) or defaultCompanionSV
    local isEnabled = (sv.enabled ~= false)
    local shouldShowInMenu = sv.testMode or (not sv.locked)
    local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")

    if isEnabled then
        if not HUD_SCENE:HasFragment(CF.CompanionFragment) then
            HUD_SCENE:AddFragment(CF.CompanionFragment)
            HUD_UI_SCENE:AddFragment(CF.CompanionFragment)
        end

        if gameMenuScene then
            if shouldShowInMenu then
                if not gameMenuScene:HasFragment(CF.CompanionFragment) then
                    gameMenuScene:AddFragment(CF.CompanionFragment)
                end
                if CF.rootFrame then CF.rootFrame:SetHidden(false) end
            else
                gameMenuScene:RemoveFragment(CF.CompanionFragment)
                if CF.rootFrame and SCENE_MANAGER:IsShowing("gameMenuInGame") then
                    CF.rootFrame:SetHidden(true)
                end
            end
        end
    else
        HUD_SCENE:RemoveFragment(CF.CompanionFragment)
        HUD_UI_SCENE:RemoveFragment(CF.CompanionFragment)
        if gameMenuScene then gameMenuScene:RemoveFragment(CF.CompanionFragment) end
        if CF.rootFrame then CF.rootFrame:SetHidden(true) end
    end
end

-- =========================================================
-- 7. СКРЫТИЕ СТАНДАРТНОЙ ПОЛОСКИ СПУТНИКА ESO
-- =========================================================
function CF.HideDefaultCompanionBar()
    if ZO_CompanionUnitFramecompanion then
        ZO_CompanionUnitFramecompanion:SetHidden(true)
        ZO_PreHook(ZO_CompanionUnitFramecompanion, "SetHidden", function(self, hidden)
            local sv = NecroCat and NecroCat.savedVars and NecroCat.savedVars.companion
            if sv and sv.enabled and not hidden then return true end
        end)
    end
end

-- =========================================================
-- 8. МЕНЮ НАСТРОЕК LAM ДЛЯ СПУТНИКОВ
-- =========================================================
function CF.GetMenuOptions()
    local styleNames, styleIds = GetCompanionStyleChoices()

    return {
        type = "submenu",
        name = "|c66f2ff" .. GetString(SI_NC_LAM_COMP_SUB) .. "|r",
        tooltip = GetString(SI_NC_LAM_COMP_SUB_TT),
        controls = {
            { type = "header", name = GetString(SI_NC_LAM_COMP_ENABLE) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_COMP_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.enabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.enabled = v
                        CF.ApplySettings()
                        CF.UpdateVisibility()
                        CF.HideDefaultCompanionBar()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_COMP_UNLOCK),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.locked == false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.locked = not v
                        CF.ApplySettings()
                        CF.UpdateVisibility()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_COMP_TEST),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.testMode end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.testMode = v
                        CF.ApplySettings()
                        CF.UpdateVisibility()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_COMP_SCOPE),
                choices = { GetString(SI_NC_LAM_COMP_SCOPE_MINE), GetString(SI_NC_LAM_COMP_SCOPE_ALL) },
                choicesValues = { 1, 2 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.companionScope) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.companionScope = v
                        CF.Update()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_COMP_ATTACH_MODE),
                tooltip = GetString(SI_NC_LAM_COMP_ATTACH_MODE_TT),
                choices = { GetString(SI_NC_LAM_COMP_ATTACH_MODE_SEPARATE), GetString(SI_NC_LAM_COMP_ATTACH_MODE_GROUP) },
                choicesValues = { 1, 2 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.attachMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.attachMode = v
                        CF.ApplySettings()
                        if NecroCat.GroupFrames and NecroCat.GroupFrames.UpdateRoster then
                            NecroCat.GroupFrames.UpdateRoster()
                        end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_COMP_SHOW_RAPPORT),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.showRapport ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.showRapport = v
                        CF.Update()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_COMP_SHOW_PORTRAIT),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.showPortrait ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.showPortrait = v
                        CF.ApplySettings()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_TEXT_MODE),
                choices = { GetString(SI_NC_LAM_TEXT_SPLIT), GetString(SI_NC_LAM_TEXT_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_CENTER_VAL), GetString(SI_NC_LAM_TEXT_CENTER_PCT), GetString(SI_NC_LAM_TEXT_NONE) },
                choicesValues = { 1, 2, 3, 4, 5 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.textMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.textMode = v
                        CF.ApplySettings()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_GROUP_SHOW_SHIELD),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.showShieldText ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.showShieldText = v
                        CF.Update()
                    end
                end,
            },
            { type = "header", name = "Стиль и оформление" },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_STYLE),
                choices = styleNames,
                choicesValues = styleIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.frameStyle) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.frameStyle = v
                        CF.ApplySettings()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_TEXTURE),
                choices = { "Стандартная (Гладкая)", "Кровь", "Руны" },
                choicesValues = { 1, 2, 3 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.barTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.barTexture = v
                        CF.ApplySettings()
                    end
                end,
            },

            { type = "header", name = "Размеры и зазоры" },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_COMP_WIDTH),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.companion
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = CF.STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.companion
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = CF.STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 150, max = 320, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.frameWidth) or 210 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.frameWidth = v
                        CF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_COMP_BAR_HEIGHT),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.companion
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = CF.STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.companion
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = CF.STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 14, max = 50, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.barHeight) or 26 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.barHeight = v
                        CF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_COMP_SPACING_Y),
                min = 0, max = 30, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.spacingY) or 4 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.spacingY = v
                        CF.ApplySettings()
                    end
                end,
            },

            { type = "header", name = "Цвета оформления" },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_COMP_COLOR_HEALTH),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.companion and NecroCat.savedVars.companion.healthColor) or defaultCompanionSV.healthColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.companion then
                        NecroCat.savedVars.companion.healthColor = { r, g, b, a }
                        CF.Update()
                    end
                end,
            },
        },
    }
end

-- =========================================================
-- 9. ИНИЦИАЛИЗАЦИЯ И СОБЫТИЯ
-- =========================================================
local function OnPlayerActivated()
    if not (NecroCat.savedVars and NecroCat.savedVars.companion) then
        if NecroCat.savedVars then
            NecroCat.savedVars.companion = ZO_ShallowTableCopy(defaultCompanionSV)
        end
    end

    CF.CreateFramePool()
    CF.HideDefaultCompanionBar()
    CF.ApplySettings()
    CF.UpdateVisibility()
end

EVENT_MANAGER:RegisterForEvent("NecroCat_CF_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

local function OnCompanionStateChanged()
    zo_callLater(function()
        CF.Update()
        if NecroCat.GroupFrames and NecroCat.GroupFrames.UpdateRoster then
            NecroCat.GroupFrames.UpdateRoster()
        end
    end, 100)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_CF_CompAct",       EVENT_COMPANION_ACTIVATED,      OnCompanionStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_CF_CompDeact",     EVENT_COMPANION_DEACTIVATED,    OnCompanionStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_CF_RapportUpdate", EVENT_COMPANION_RAPPORT_UPDATE, CF.Update)

EVENT_MANAGER:RegisterForEvent("NecroCat_CF_Power", EVENT_POWER_UPDATE, function(event, unitTag, powerIndex, powerType)
    if unitTag and string.match(unitTag, "companion") and powerType == POWERTYPE_HEALTH then
        CF.Update()
    end
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_CF_Death", EVENT_UNIT_DEATH_STATE_CHANGED, function(event, unitTag)
    if unitTag and string.match(unitTag, "companion") then
        CF.Update()
    end
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_CF_GroupUpd", EVENT_GROUP_UPDATE, function()
    zo_callLater(CF.Update, 200)
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_CF_GroupLeft", EVENT_GROUP_MEMBER_LEFT, function()
    zo_callLater(CF.Update, 350)
end)