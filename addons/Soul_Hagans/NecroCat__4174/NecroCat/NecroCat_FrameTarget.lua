-- =========================================================
-- NecroCat: Target Frame Module (Фрейм цели)
-- =========================================================

if not NecroCat then NecroCat = {} end
NecroCat.Frames = NecroCat.Frames or {}
local Frames = NecroCat.Frames

local defaultTargetSV = {
    targetEnabled        = false,
    hideDefaultTarget    = true,
    targetFrameStyle     = 1, -- 1: Минимал, 2: Вампир, 3: Кошка, 4: Мыши
    targetStyleColor     = 1, -- 1: Зеленый, 2: Синий
    targetBarTexture     = 1, -- 1: Гладкая, 2: Кровь, 3: Руны
    targetScale          = 100, -- Масштаб в % (70-150)
    targetWidth          = 300,
    targetHeight         = 28,
    targetLeft           = 840,
    targetTop            = 650,
    targetLocked         = false,
    fontSize             = 14,
    topFontSize          = 15,
    topOffsetY           = 2,
    subFontSize          = 14,
    skullSize            = 40,
    skullOffsetY         = -19,
    textMode             = 1,
    healthCenterFill     = false,
    nameFormat           = 3,
    showClass            = true,
    showAlliance         = true,
    classOffsetX         = -6,
    allianceOffsetX      = 5,
    classIconSize        = 38,
    allianceIconSize     = 44,
    levelDisplayMode     = 1,
    showRace             = true,
    showRank             = true,
    showSkull            = true,
    executeEnabled       = true,
    executeThreshold     = 25,
    cpColorMode          = 1,
    customCpColor        = { 1.0, 0.85, 0.2, 1.0 },
    hostileColor         = { 0.76, 0.12, 0.12, 1.0 },
    friendlyColor        = { 0.14, 0.65, 0.22, 1.0 },
    neutralColor         = { 0.85, 0.75, 0.15, 1.0 },
    shieldColor          = { 0.25, 0.75, 0.95, 0.55 },
    textColor            = { 1.0, 1.0, 1.0, 1.0 },
    rankColor            = { 0.90, 0.77, 0.57, 1.0 },
}

-- =========================================================
-- ТАБЛИЦА СТИЛЕЙ ОФОРМЛЕНИЯ ЦЕЛИ (АВТОНОМНАЯ)
-- =========================================================
Frames.TARGET_STYLES = {
    -- 1. СТИЛЬ: ПО УМОЛЧАНИЮ (МИНИМАЛИЗМ БЕЗ РАМОК)
    [1] = {
        id           = 1,
        name         = "SI_NC_LAM_STYLE_DEFAULT",
        hasArt       = false,
        labelPadX    = 8,
        labelOffsetY = 3,
    },

    -- 2. СТИЛЬ: ВАМПИРСКАЯ ГОТИКА
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
        artW         = 360,
        artH         = 116,
        artOffsetX   = 0,
        artOffsetY   = 7,
        barW         = 315,
        barH         = 36,
        insetX       = 0,
        insetY       = 3,
        labelPadX    = 4,
        labelOffsetY = 4,
    },

    -- 3. СТИЛЬ: НЕКРОКОШКА
    [3] = {
        id           = 3,
        name         = "SI_NC_LAM_STYLE_CAT",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_GREEN",
                art  = "NecroCat/imgs/frames/target_backplate_cat_green.dds",
            },
            [2] = {
                name = "SI_NC_LAM_COLOR_BLUE",
                art  = "NecroCat/imgs/frames/target_backplate_cat_blue.dds",
            },
        },
        artW         = 510,
        artH         = 144,
        artOffsetX   = 1,
        artOffsetY   = -24,
        barW         = 380,
        barH         = 43,
        insetX       = 0,
        insetY       = 5,
        labelPadX    = 4,
        labelOffsetY = 4,
    },

    -- 4. СТИЛЬ: ЛЕТУЧИЕ МЫШИ
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
        artW         = 355,
        artH         = 98,
        artOffsetX   = -2,
        artOffsetY   = 0,
        barW         = 315,
        barH         = 36,
        insetX       = 0,
        insetY       = 3,
        labelPadX    = 4,
        labelOffsetY = 4,
    },
        -- 5. СТИЛЬ: НЕКРОКОШКА
    [5] = {
        id           = 5,
        name         = "SI_NC_LAM_STYLE_CAT2",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR",
                art  = "NecroCat/imgs/frames/target_backplate_cat.dds",
            },
        },
        artW         = 375,
        artH         = 66,
        artOffsetX   = 0,
        artOffsetY   = 0,
        barW         = 360,
        barH         = 42,
        insetX       = 0,
        insetY       = 5,
        labelPadX    = 4,
        labelOffsetY = 4,
    },
}

-- БИБЛИОТЕКА ТЕКСТУР ЗАПОЛНЕНИЯ ПОЛОСЫ ЦЕЛИ
Frames.TARGET_BAR_TEXTURES = {
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

-- 1. ФОРМАТИРОВАНИЕ ЧИСЕЛ И ЦВЕТ ЧП
local function FormatValue(value)
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

local function GetCpColorHex(cp, sv)
    if not cp or cp <= 0 then return "ffffff" end
    local mode = sv.cpColorMode or 1
    if mode == 2 then
        return "ffffff"
    elseif mode == 3 then
        return RgbToHex(sv.customCpColor or { 1.0, 0.85, 0.2, 1.0 })
    end
    if cp < 600 then
        return "ffffff"
    elseif cp < 1200 then
        return "2dc50e"
    elseif cp < 1800 then
        return "3a92ff"
    elseif cp < 2400 then
        return "a02ef7"
    elseif cp < 3000 then
        return "eecb32"
    else
        return "ff6a00"
    end
end

local function GetOrCreateChild(parent, name, controlType)
    local child = parent:GetNamedChild(name)
    if child then return child end
    return WINDOW_MANAGER:CreateControl("$(parent)" .. name, parent, controlType)
end

-- 2. СКРЫТИЕ СТАНДАРТНОЙ ЦЕЛИ ESO
function Frames.UpdateDefaultTargetVisibility()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV
    local shouldHide = (sv.targetEnabled ~= false) and (sv.hideDefaultTarget ~= false)

    if ZO_TargetUnitFramereticleover then
        if not Frames.targetHooked then
            ZO_PreHook(ZO_TargetUnitFramereticleover, "SetHidden", function(self, hidden)
                local s = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV
                if (not hidden) and (s.targetEnabled ~= false) and (s.hideDefaultTarget ~= false) then
                    return true
                end
            end)
            Frames.targetHooked = true
        end

        if shouldHide then
            ZO_TargetUnitFramereticleover:SetHidden(true)
        else
            ZO_TargetUnitFramereticleover:SetHidden(not DoesUnitExist("reticleover"))
        end
    end
end

-- 3. ПРИМЕНЕНИЕ ЦВЕТОВ
function Frames.ApplyTargetColors()
    if not Frames.TargetHealthBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV

    local tc = sv.textColor or defaultTargetSV.textColor
    if Frames.TargetLeftLabel then
        Frames.TargetLeftLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.TargetRightLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
    end

    local sc = sv.shieldColor or defaultTargetSV.shieldColor
    if Frames.TargetShieldBar then
        Frames.TargetShieldBar:SetColor(sc[1], sc[2], sc[3], sc[4] or 0.55)
    end

    local rc = sv.rankColor or defaultTargetSV.rankColor or { 0.90, 0.77, 0.57, 1.0 }
    if Frames.TargetRankLabel then
        Frames.TargetRankLabel:SetColor(rc[1], rc[2], rc[3], rc[4] or 1)
    end
end

function Frames.ApplyTargetBarTexture()
    if not Frames.TargetHealthBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV
    local texId = sv.targetBarTexture or 1
    local cfg = Frames.TARGET_BAR_TEXTURES and Frames.TARGET_BAR_TEXTURES[texId]
    if cfg and cfg.path and texId > 1 then
        Frames.TargetHealthBar:SetTexture(cfg.path)
    else
        Frames.TargetHealthBar:SetTexture(nil)
    end
end

-- 4. ПРИМЕНЕНИЕ РАЗМЕРОВ И ПОЗИЦИИ
function Frames.ApplyTargetLayout()
    if not Frames.TargetFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV

    if sv.targetEnabled == false then
        Frames.TargetFrame:SetHidden(true)
        return
    end

    local styleId = (sv and sv.targetFrameStyle) or 1
    local style = (Frames.TARGET_STYLES and Frames.TARGET_STYLES[styleId]) or (Frames.TARGET_STYLES and Frames.TARGET_STYLES[1]) or {}
    local colorId = (sv and sv.targetStyleColor) or 1
    local variant = (style.colorVariants and style.colorVariants[colorId]) or (style.colorVariants and style.colorVariants[1])

    local userW = sv.targetWidth or 300
    local userH = sv.targetHeight or 28
    local barW = (style.hasArt and style.barW) or userW
    local barH = (style.hasArt and style.barH) or userH
    local isUnlocked = (sv.targetLocked == false)

    Frames.TargetFrame:SetDimensions(barW, barH)
    Frames.TargetFrame:SetMovable(isUnlocked)
    Frames.TargetFrame:SetMouseEnabled(isUnlocked)

    Frames.TargetFrame:ClearAnchors()
    Frames.TargetFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.targetLeft or 840, sv.targetTop or 650)

    local scale = (sv.targetScale or 100) / 100
    Frames.TargetFrame:SetScale(scale)

    -- Посадка арт-рамки цели
    if Frames.TargetArtBG then
        if style.hasArt then
            local artTex  = (variant and variant.art) or style.artTexture
            local artW    = style.artW or 410
            local artH    = style.artH or 140
            local artOffX = style.artOffsetX or 0
            local artOffY = style.artOffsetY or 0

            Frames.TargetArtBG:SetHidden(false)
            Frames.TargetArtBG:SetTexture(artTex)
            Frames.TargetArtBG:SetDimensions(artW, artH)
            Frames.TargetArtBG:ClearAnchors()
            Frames.TargetArtBG:SetAnchor(CENTER, Frames.TargetFrame, CENTER, artOffX, artOffY)
            if Frames.TargetBG then Frames.TargetBG:SetHidden(true) end
        else
            Frames.TargetArtBG:SetHidden(true)
            if Frames.TargetBG then Frames.TargetBG:SetHidden(false) end
        end
    end

    local insetX = style.insetX or 1
    local insetY = style.insetY or 1

    if Frames.TargetHealthBar then
        Frames.TargetHealthBar:ClearAnchors()
        Frames.TargetHealthBar:SetAnchor(TOPLEFT, Frames.TargetFrame, TOPLEFT, insetX, insetY)
        Frames.TargetHealthBar:SetAnchor(BOTTOMRIGHT, Frames.TargetFrame, BOTTOMRIGHT, -insetX, -insetY)
    end
    if Frames.TargetShieldBar then
        Frames.TargetShieldBar:ClearAnchors()
        Frames.TargetShieldBar:SetAnchor(TOPLEFT, Frames.TargetFrame, TOPLEFT, insetX, insetY)
        Frames.TargetShieldBar:SetAnchor(BOTTOMRIGHT, Frames.TargetFrame, BOTTOMRIGHT, -insetX, -insetY)
    end

    local barAlign = sv.healthCenterFill and BAR_ALIGNMENT_CENTER or BAR_ALIGNMENT_NORMAL
    Frames.TargetHealthBar:SetBarAlignment(barAlign)

    if Frames.TargetClassIcon then
        local classX = sv.classOffsetX or -4
        local classSize = sv.classIconSize or barH or 28
        Frames.TargetClassIcon:SetDimensions(classSize, classSize)
        Frames.TargetClassIcon:ClearAnchors()
        Frames.TargetClassIcon:SetAnchor(RIGHT, Frames.TargetFrame, LEFT, classX, 0)
    end

    if Frames.TargetAllianceIcon then
        local allianceX = sv.allianceOffsetX or 4
        local allianceSize = sv.allianceIconSize or barH or 28
        Frames.TargetAllianceIcon:SetDimensions(allianceSize, allianceSize)
        Frames.TargetAllianceIcon:ClearAnchors()
        Frames.TargetAllianceIcon:SetAnchor(LEFT, Frames.TargetFrame, RIGHT, allianceX, 0)
    end

    local numFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.fontSize or 14)
    local topFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.topFontSize or 15)
    local subFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.subFontSize or 14)

    Frames.TargetLeftLabel:SetFont(numFont)
    Frames.TargetLeftLabel:SetHeight(barH)
    Frames.TargetLeftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    Frames.TargetRightLabel:SetFont(numFont)
    Frames.TargetRightLabel:SetHeight(barH)
    Frames.TargetRightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    Frames.TargetTopLabel:SetFont(topFont)
    if Frames.TargetTopLevelLabel then
        Frames.TargetTopLevelLabel:SetFont(topFont)
    end
    Frames.TargetSubLabel:SetFont(subFont)
    if Frames.TargetRankLabel then
        Frames.TargetRankLabel:SetFont(subFont)
    end

    local skSize = sv.skullSize or 40
    local skY = sv.skullOffsetY or 4
    Frames.TargetSkullIcon:SetDimensions(skSize, skSize)
    Frames.TargetSkullIcon:ClearAnchors()
    Frames.TargetSkullIcon:SetAnchor(CENTER, Frames.TargetFrame, BOTTOM, 0, skY)

    local mode = sv.textMode or 1
    local padX = style.labelPadX or 8
    local yOffset = style.labelOffsetY or 3
    
    Frames.TargetLeftLabel:ClearAnchors()
    Frames.TargetRightLabel:ClearAnchors()

    if mode == 1 then
        Frames.TargetLeftLabel:SetAnchor(LEFT, Frames.TargetFrame, LEFT, padX, yOffset)
        Frames.TargetLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        Frames.TargetLeftLabel:SetHidden(false)

        Frames.TargetRightLabel:SetAnchor(RIGHT, Frames.TargetFrame, RIGHT, -padX, yOffset)
        Frames.TargetRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        Frames.TargetRightLabel:SetHidden(false)
    elseif mode == 2 or mode == 3 or mode == 4 then
        Frames.TargetLeftLabel:SetHidden(true)
        Frames.TargetRightLabel:SetAnchor(CENTER, Frames.TargetFrame, CENTER, 0, yOffset)
        Frames.TargetRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        Frames.TargetRightLabel:SetHidden(false)
    elseif mode == 5 then
        Frames.TargetLeftLabel:SetHidden(true)
        Frames.TargetRightLabel:SetHidden(true)
    end

    Frames.ApplyTargetColors()
    Frames.ApplyTargetBarTexture()

    -- Управляем присутствием в меню Esc: только когда разблокировано!
    local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if gameMenuScene and Frames.TargetFragment then
        if isUnlocked and (sv.targetEnabled ~= false) then
            if not gameMenuScene:HasFragment(Frames.TargetFragment) then
                gameMenuScene:AddFragment(Frames.TargetFragment)
            end
        else
            if gameMenuScene:HasFragment(Frames.TargetFragment) then
                gameMenuScene:RemoveFragment(Frames.TargetFragment)
            end
        end
    end

    if not DoesUnitExist("reticleover") then
        if isUnlocked then
            Frames.ShowTargetPreview()
        else
            Frames.TargetFrame:SetHidden(true)
        end
    else
        Frames.UpdateTargetData()
    end
end

-- 5. ТЕСТОВЫЙ ПРЕДПРОСМОТР
function Frames.ShowTargetPreview()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV
    Frames.TargetFrame:SetHidden(false)

    local baseName = "Алексиус Дрейк"
    local nameMode = sv.nameFormat or 3
    local nameStr = baseName
    if nameMode == 2 then
        nameStr = "@TamrielHero"
    elseif nameMode == 3 then
        nameStr = string.format("%s (@TamrielHero)", baseName)
    end

    if Frames.TargetClassIcon then
        if sv.showClass ~= false then
            Frames.TargetClassIcon:SetTexture("/esoui/art/icons/class/class_dragonknight.dds")
            Frames.TargetClassIcon:SetHidden(false)
        else
            Frames.TargetClassIcon:SetHidden(true)
        end
    end

    if Frames.TargetAllianceIcon then
        if sv.showAlliance ~= false then
            Frames.TargetAllianceIcon:SetTexture(GetAllianceSymbolIcon(ALLIANCE_EBONHEART_PACT))
            Frames.TargetAllianceIcon:SetHidden(false)
        else
            Frames.TargetAllianceIcon:SetHidden(true)
        end
    end

    local cpHex = GetCpColorHex(1600, sv)
    local lvlMode = sv.levelDisplayMode or 1
    local showLvl = (lvlMode ~= 3)
    local topY = sv.topOffsetY or -4

    if Frames.TargetTopLevelLabel then
        Frames.TargetTopLevelLabel:ClearAnchors()
        Frames.TargetTopLevelLabel:SetAnchor(BOTTOMRIGHT, Frames.TargetFrame, TOPRIGHT, 0, topY)
        if showLvl then
            Frames.TargetTopLevelLabel:SetText(string.format("[|c%sCP 1600|r]", cpHex))
            Frames.TargetTopLevelLabel:SetHidden(false)
        else
            Frames.TargetTopLevelLabel:SetHidden(true)
        end
    end

    Frames.TargetTopLabel:ClearAnchors()
    Frames.TargetTopLabel:SetAnchor(BOTTOMLEFT, Frames.TargetFrame, TOPLEFT, 0, topY)
    if showLvl and Frames.TargetTopLevelLabel then
        Frames.TargetTopLabel:SetAnchor(BOTTOMRIGHT, Frames.TargetTopLevelLabel, BOTTOMLEFT, -6, 0)
    else
        Frames.TargetTopLabel:SetAnchor(BOTTOMRIGHT, Frames.TargetFrame, TOPRIGHT, 0, topY)
    end
    Frames.TargetTopLabel:SetText(nameStr)

    if sv.showRace ~= false then
        Frames.TargetSubLabel:ClearAnchors()
        Frames.TargetSubLabel:SetAnchor(TOPLEFT, Frames.TargetFrame, BOTTOMLEFT, 0, 4)
        Frames.TargetSubLabel:SetText(zo_strformat("<<t:1>>", GetRaceName(GENDER_MALE, 1)))
        Frames.TargetSubLabel:SetHidden(false)
    else
        Frames.TargetSubLabel:SetHidden(true)
    end

    if Frames.TargetRankLabel then
        if sv.showRank ~= false then
            Frames.TargetRankLabel:ClearAnchors()
            Frames.TargetRankLabel:SetAnchor(TOPRIGHT, Frames.TargetFrame, BOTTOMRIGHT, 0, 4)
            Frames.TargetRankLabel:SetText("Майор 2-го ранга")
            Frames.TargetRankLabel:SetHidden(false)
        else
            Frames.TargetRankLabel:SetHidden(true)
        end
    end

    local showSk = (sv.showSkull ~= false)
    Frames.TargetSkullIcon:SetHidden(not showSk)
    if showSk then
        if sv.executeEnabled ~= false then
            Frames.TargetSkullIcon:SetTexture("NecroCat/imgs/frames/skull_boss_execute.dds")
        else
            Frames.TargetSkullIcon:SetTexture("NecroCat/imgs/frames/skull_boss.dds")
        end
        Frames.TargetSkullIcon:SetColor(1, 1, 1, 1)
        Frames.TargetExecuteSkull:SetHidden(true)
    else
        Frames.TargetExecuteSkull:SetHidden(sv.executeEnabled == false)
    end

    local hc = sv.hostileColor or defaultTargetSV.hostileColor
    Frames.TargetHealthBar:SetColor(hc[1], hc[2], hc[3], hc[4] or 1)
    Frames.TargetHealthBar:SetMinMax(0, 100)
    Frames.TargetHealthBar:SetValue(100)

    Frames.TargetShieldBar:SetMinMax(0, 100)
    Frames.TargetShieldBar:SetValue(35)
    Frames.TargetShieldBar:SetHidden(false)

    local mode = sv.textMode or 1
    if mode == 1 then
        Frames.TargetLeftLabel:SetText("21.0k")
        Frames.TargetRightLabel:SetText("20%")
    elseif mode == 2 then
        Frames.TargetRightLabel:SetText("21.0k (20%)")
    elseif mode == 3 then
        Frames.TargetRightLabel:SetText("21.0k")
    elseif mode == 4 then
        Frames.TargetRightLabel:SetText("20%")
    end
end

-- 6. ОБНОВЛЕНИЕ ЗДОРОВЬЯ ЦЕЛИ
function Frames.UpdateTargetHealth()
    if not Frames.TargetFrame or not DoesUnitExist("reticleover") then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV

    local curHealth, maxHealth = GetUnitPower("reticleover", POWERTYPE_HEALTH)
    if maxHealth <= 0 then maxHealth = 1 end

    local react = GetUnitReaction("reticleover")
    local isAttackable = IsUnitAttackable("reticleover")
    local unitType = GetUnitType and GetUnitType("reticleover")
    local isDummy = (unitType == 12) or (unitType == UNIT_TYPE_TARGET_DUMMY)
    local isGuard = IsUnitJusticeGuard and IsUnitJusticeGuard("reticleover")

    local isPlayer = IsUnitPlayer("reticleover")

    -- В бою скрываем павших монстров (но оставляем павших игроков)
    if IsUnitInCombat("player") and (not isPlayer) and (curHealth <= 0 or IsUnitDead("reticleover")) then
        Frames.TargetFrame:SetHidden(true)
        return
    end

    local barColor = sv.hostileColor or defaultTargetSV.hostileColor

    if isPlayer then
        -- Все живые игроки -> всегда боевой КРАСНЫЙ
        barColor = sv.hostileColor or defaultTargetSV.hostileColor
    elseif not isAttackable then
        -- Неуязвимые мирные NPC (квестодатели, торговцы, Вара-Зин) -> ЗЕЛЕНЫЙ
        barColor = sv.friendlyColor or defaultTargetSV.friendlyColor
    elseif isDummy then
        -- Тренировочные манекены -> всегда КРАСНЫЙ
        barColor = sv.hostileColor or defaultTargetSV.hostileColor
    elseif react == UNIT_REACTION_NEUTRAL and (not isGuard) then
        -- Смертные нейтральные граждане (которых можно атаковать) -> ЖЕЛТЫЙ
        barColor = sv.neutralColor or defaultTargetSV.neutralColor
    end

    Frames.TargetHealthBar:SetColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
    Frames.TargetHealthBar:SetMinMax(0, maxHealth)
    Frames.TargetHealthBar:SetValue(curHealth)

    local shieldVal = 0
    if GetUnitAttributeVisualizerEffectInfo then
        shieldVal = GetUnitAttributeVisualizerEffectInfo("reticleover", ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
    end

    if shieldVal > 0 then
        Frames.TargetShieldBar:SetMinMax(0, maxHealth)
        Frames.TargetShieldBar:SetValue(shieldVal)
        Frames.TargetShieldBar:SetHidden(false)
    else
        Frames.TargetShieldBar:SetHidden(true)
    end

    local pct = math.floor((curHealth / maxHealth) * 100)
    local diff = GetUnitDifficulty("reticleover")
    local isBoss = (diff and diff >= 4)
    local hasSkull = isAttackable and (not isPlayer) and (not isGuard) and (sv.showSkull ~= false) and diff and (diff >= 2)
    local isExecute = (sv.executeEnabled ~= false) and isAttackable and (curHealth > 0) and (pct <= (sv.executeThreshold or 25))

    if hasSkull then
        Frames.TargetExecuteSkull:SetHidden(true)
        local tex
        if isBoss then
            tex = isExecute and "NecroCat/imgs/frames/skull_boss_execute.dds" or "NecroCat/imgs/frames/skull_boss.dds"
        else
            tex = isExecute and "NecroCat/imgs/frames/skull_elite_execute.dds" or "NecroCat/imgs/frames/skull_elite.dds"
        end
        Frames.TargetSkullIcon:SetTexture(tex)
        Frames.TargetSkullIcon:SetColor(1, 1, 1, 1)
        Frames.TargetSkullIcon:SetHidden(false)
    else
        Frames.TargetSkullIcon:SetHidden(true)
        Frames.TargetExecuteSkull:SetHidden(not isExecute)
    end

    local mode = sv.textMode or 1
    if mode == 5 then return end

    local curStr = FormatValue(curHealth)
    if mode == 1 then
        Frames.TargetLeftLabel:SetText(curStr)
        Frames.TargetRightLabel:SetText(string.format("%d%%", pct))
    elseif mode == 2 then
        Frames.TargetRightLabel:SetText(string.format("%s (%d%%)", curStr, pct))
    elseif mode == 3 then
        Frames.TargetRightLabel:SetText(curStr)
    elseif mode == 4 then
        Frames.TargetRightLabel:SetText(string.format("%d%%", pct))
    end
end

-- 7. ПОЛНОЕ ОБНОВЛЕНИЕ ДАННЫХ ЦЕЛИ
function Frames.UpdateTargetData()
    if not Frames.TargetFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV

    if sv.targetEnabled == false then
        Frames.TargetFrame:SetHidden(true)
        return
    end

    if not DoesUnitExist("reticleover") then
        if sv.targetLocked == false then
            Frames.ShowTargetPreview()
        else
            Frames.TargetFrame:SetHidden(true)
        end
        return
    end

    -- В бою не показываем фрейм при наведении на мертвого моба
    if IsUnitInCombat("player") and (not IsUnitPlayer("reticleover")) and IsUnitDead("reticleover") then
        Frames.TargetFrame:SetHidden(true)
        return
    end

    Frames.TargetFrame:SetHidden(false)

    local rawName = GetUnitName("reticleover")
    local charName = zo_strformat("<<t:1>>", rawName)
    local displayName = GetUnitDisplayName("reticleover")
    local nameMode = sv.nameFormat or 3
    local nameStr = charName

    if IsUnitPlayer("reticleover") and displayName and displayName ~= "" then
        if nameMode == 2 then
            nameStr = displayName
        elseif nameMode == 3 then
            nameStr = string.format("%s (%s)", charName, displayName)
        end
    end

    local levelStr = ""
    local lvlMode = sv.levelDisplayMode or 1
    local isPlayer = IsUnitPlayer("reticleover")
    local shouldShowLevel = (lvlMode == 2) or (lvlMode == 1 and isPlayer)

    if shouldShowLevel then
        local level = GetUnitLevel("reticleover")
        local cp = GetUnitChampionPoints("reticleover")
        if cp and cp > 0 then
            local cpHex = GetCpColorHex(cp, sv)
            levelStr = string.format("[|c%sCP %d|r]", cpHex, cp)
        else
            levelStr = string.format("[%s]", string.format(GetString(SI_NC_TARGET_LVL_FORMAT), level))
        end
    end

    if Frames.TargetClassIcon then
        if sv.showClass ~= false and IsUnitPlayer("reticleover") then
            local classId = GetUnitClassId("reticleover")
            local iconPath = GetPlatformClassIcon(classId)
            if iconPath and iconPath ~= "" then
                Frames.TargetClassIcon:SetTexture(iconPath)
                Frames.TargetClassIcon:SetHidden(false)
            else
                Frames.TargetClassIcon:SetHidden(true)
            end
        else
            Frames.TargetClassIcon:SetHidden(true)
        end
    end

    if Frames.TargetAllianceIcon then
        if sv.showAlliance ~= false and IsUnitPlayer("reticleover") then
            local alliance = GetUnitAlliance("reticleover")
            local iconPath = GetAllianceSymbolIcon(alliance)
            if iconPath and iconPath ~= "" then
                Frames.TargetAllianceIcon:SetTexture(iconPath)
                Frames.TargetAllianceIcon:SetHidden(false)
            else
                Frames.TargetAllianceIcon:SetHidden(true)
            end
        else
            Frames.TargetAllianceIcon:SetHidden(true)
        end
    end

    local topY = sv.topOffsetY or -4

    if Frames.TargetTopLevelLabel then
        Frames.TargetTopLevelLabel:ClearAnchors()
        Frames.TargetTopLevelLabel:SetAnchor(BOTTOMRIGHT, Frames.TargetFrame, TOPRIGHT, 0, topY)
        if shouldShowLevel and levelStr ~= "" then
            Frames.TargetTopLevelLabel:SetText(levelStr)
            Frames.TargetTopLevelLabel:SetHidden(false)
        else
            Frames.TargetTopLevelLabel:SetHidden(true)
        end
    end

    Frames.TargetTopLabel:ClearAnchors()
    Frames.TargetTopLabel:SetAnchor(BOTTOMLEFT, Frames.TargetFrame, TOPLEFT, 0, topY)
    if shouldShowLevel and levelStr ~= "" and Frames.TargetTopLevelLabel then
        Frames.TargetTopLabel:SetAnchor(BOTTOMRIGHT, Frames.TargetTopLevelLabel, BOTTOMLEFT, -6, 0)
    else
        Frames.TargetTopLabel:SetAnchor(BOTTOMRIGHT, Frames.TargetFrame, TOPRIGHT, 0, topY)
    end
    Frames.TargetTopLabel:SetText(nameStr)

    if IsUnitPlayer("reticleover") then
        Frames.TargetSkullIcon:SetHidden(true)
        if sv.showRace ~= false then
            local race = GetUnitRace("reticleover")
            if race and race ~= "" then
                Frames.TargetSubLabel:ClearAnchors()
                Frames.TargetSubLabel:SetAnchor(TOPLEFT, Frames.TargetFrame, BOTTOMLEFT, 0, 4)
                Frames.TargetSubLabel:SetText(zo_strformat("<<t:1>>", race))
                Frames.TargetSubLabel:SetHidden(false)
            else
                Frames.TargetSubLabel:SetHidden(true)
            end
        else
            Frames.TargetSubLabel:SetHidden(true)
        end

        if Frames.TargetRankLabel then
            if sv.showRank ~= false then
                local rank = GetUnitAvARank("reticleover")
                if rank and rank > 0 then
                    local gender = GetUnitGender("reticleover")
                    local rankName = GetAvARankName(gender, rank)
                    Frames.TargetRankLabel:ClearAnchors()
                    Frames.TargetRankLabel:SetAnchor(TOPRIGHT, Frames.TargetFrame, BOTTOMRIGHT, 0, 4)
                    Frames.TargetRankLabel:SetText(zo_strformat("<<t:1>>", rankName))
                    Frames.TargetRankLabel:SetHidden(false)
                else
                    Frames.TargetRankLabel:SetHidden(true)
                end
            else
                Frames.TargetRankLabel:SetHidden(true)
            end
        end
    else
        Frames.TargetSubLabel:SetHidden(true)
        if Frames.TargetRankLabel then
            Frames.TargetRankLabel:SetHidden(true)
        end
    end

    Frames.UpdateTargetHealth()
end

-- 8. СОЗДАНИЕ UI ФРЕЙМА ЦЕЛИ
function Frames.CreateTargetFrame()
    if Frames.TargetFrame then return end

    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV
    local barW = sv.targetWidth or 240
    local barH = sv.targetHeight or 22
    local isUnlocked = (sv.targetLocked == false)

    local targetFrame = _G["NecroCat_TargetFrame"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_TargetFrame")
    targetFrame:SetDimensions(barW, barH)
    targetFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.targetLeft or 840, sv.targetTop or 650)
    targetFrame:SetMovable(isUnlocked)
    targetFrame:SetMouseEnabled(isUnlocked)
    targetFrame:SetClampedToScreen(true)
    targetFrame:SetDrawTier(DT_HIGH)
    targetFrame:SetHidden(true)

    local targetBG = GetOrCreateChild(targetFrame, "BG", CT_BACKDROP)
    targetBG:SetAnchorFill(targetFrame)
    targetBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    targetBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    targetBG:SetEdgeTexture("", 8, 1, 1)

    local targetArtBG = GetOrCreateChild(targetFrame, "ArtBG", CT_TEXTURE)
    targetArtBG:SetDrawLayer(DL_BACKGROUND)
    targetArtBG:SetDrawLevel(2)
    targetArtBG:SetHidden(true)

    local healthBar = GetOrCreateChild(targetFrame, "Bar", CT_STATUSBAR)
    healthBar:ClearAnchors()
    healthBar:SetAnchor(TOPLEFT, targetFrame, TOPLEFT, 1, 1)
    healthBar:SetAnchor(BOTTOMRIGHT, targetFrame, BOTTOMRIGHT, -1, -1)
    healthBar:SetDrawLayer(DL_CONTROLS)
    healthBar:SetDrawLevel(1)
    healthBar:SetColor(0.76, 0.12, 0.12, 1)

    local shieldBar = GetOrCreateChild(targetFrame, "Shield", CT_STATUSBAR)
    shieldBar:ClearAnchors()
    shieldBar:SetAnchor(TOPLEFT, targetFrame, TOPLEFT, 1, 1)
    shieldBar:SetAnchor(BOTTOMRIGHT, targetFrame, BOTTOMRIGHT, -1, -1)
    shieldBar:SetColor(0.25, 0.75, 0.95, 0.55)
    shieldBar:SetDrawLayer(DL_CONTROLS)
    shieldBar:SetDrawLevel(2)
    shieldBar:SetHidden(true)

    local executeSkull = GetOrCreateChild(targetFrame, "ExecuteSkull", CT_TEXTURE)
    executeSkull:SetDimensions(28, 28)
    executeSkull:SetAnchor(CENTER, targetFrame, CENTER, 0, 0)
    executeSkull:SetTexture("/esoui/art/deathrecap/deathrecap_killingblow_icon.dds")
    executeSkull:SetColor(1.0, 0.55, 0.0, 1.0)
    executeSkull:SetDrawLayer(DL_OVERLAY)
    executeSkull:SetDrawLevel(5)
    executeSkull:SetHidden(true)
    
    local classIcon = GetOrCreateChild(targetFrame, "ClassIcon", CT_TEXTURE)
    classIcon:SetDimensions(barH, barH)
    classIcon:SetAnchor(RIGHT, targetFrame, LEFT, -4, 0)
    classIcon:SetDrawLayer(DL_OVERLAY)
    classIcon:SetDrawLevel(2)
    classIcon:SetHidden(true)

    local allianceIcon = GetOrCreateChild(targetFrame, "AllianceIcon", CT_TEXTURE)
    allianceIcon:SetDimensions(barH, barH)
    allianceIcon:SetAnchor(LEFT, targetFrame, RIGHT, 4, 0)
    allianceIcon:SetDrawLayer(DL_OVERLAY)
    allianceIcon:SetDrawLevel(2)
    allianceIcon:SetHidden(true)

    local numFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.fontSize or 14)

    local leftLabel = GetOrCreateChild(targetFrame, "LeftLabel", CT_LABEL)
    leftLabel:SetFont(numFont)
    leftLabel:SetHeight(barH)
    leftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    leftLabel:SetAnchor(LEFT, targetFrame, LEFT, 8, 3)
    leftLabel:SetDrawLayer(DL_OVERLAY)
    leftLabel:SetDrawLevel(3)

    local rightLabel = GetOrCreateChild(targetFrame, "RightLabel", CT_LABEL)
    rightLabel:SetFont(numFont)
    rightLabel:SetHeight(barH)
    rightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rightLabel:SetAnchor(RIGHT, targetFrame, RIGHT, -8, 3)
    rightLabel:SetDrawLayer(DL_OVERLAY)
    rightLabel:SetDrawLevel(3)

    local topLabel = GetOrCreateChild(targetFrame, "TopLabel", CT_LABEL)
    topLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.topFontSize or 15))
    topLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    topLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    topLabel:SetMaxLineCount(1)
    topLabel:SetDrawLayer(DL_OVERLAY)

    local topLevelLabel = GetOrCreateChild(targetFrame, "TopLevelLabel", CT_LABEL)
    topLevelLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.topFontSize or 15))
    topLevelLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    topLevelLabel:SetMaxLineCount(1)
    topLevelLabel:SetDrawLayer(DL_OVERLAY)

    local skullIcon = GetOrCreateChild(targetFrame, "Skull", CT_TEXTURE)
    skullIcon:SetDimensions(sv.skullSize or 40, sv.skullSize or 40)
    skullIcon:SetAnchor(CENTER, targetFrame, BOTTOM, 0, sv.skullOffsetY or 4)
    skullIcon:SetDrawLayer(DL_OVERLAY)
    skullIcon:SetDrawLevel(4)
    skullIcon:SetHidden(true)

    local subLabel = GetOrCreateChild(targetFrame, "SubLabel", CT_LABEL)
    subLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.subFontSize or 14))
    subLabel:SetAnchor(TOPLEFT, targetFrame, BOTTOMLEFT, 0, 4)
    subLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    subLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    subLabel:SetMaxLineCount(1)
    subLabel:SetColor(0.8, 0.8, 0.8, 1)
    subLabel:SetDrawLayer(DL_OVERLAY)
    subLabel:SetHidden(true)

    local rankLabel = GetOrCreateChild(targetFrame, "RankLabel", CT_LABEL)
    rankLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.subFontSize or 14))
    rankLabel:SetAnchor(TOPRIGHT, targetFrame, BOTTOMRIGHT, 0, 4)
    rankLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    rankLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    rankLabel:SetMaxLineCount(1)
    rankLabel:SetColor(0.90, 0.77, 0.57, 1) 
    rankLabel:SetDrawLayer(DL_OVERLAY)
    rankLabel:SetHidden(true)

    targetFrame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.frames then
            NecroCat.savedVars.frames.targetLeft = self:GetLeft()
            NecroCat.savedVars.frames.targetTop = self:GetTop()
        end
    end)

    Frames.TargetFrame        = targetFrame
    Frames.TargetBG           = targetBG
    Frames.TargetArtBG        = targetArtBG
    Frames.TargetHealthBar    = healthBar
    Frames.TargetShieldBar    = shieldBar
    Frames.TargetClassIcon    = classIcon
    Frames.TargetAllianceIcon = allianceIcon
    Frames.TargetExecuteSkull = executeSkull
    Frames.TargetLeftLabel    = leftLabel
    Frames.TargetRightLabel   = rightLabel
    Frames.TargetTopLabel     = topLabel
    Frames.TargetTopLevelLabel = topLevelLabel
    Frames.TargetSkullIcon    = skullIcon
    Frames.TargetSubLabel     = subLabel
    Frames.TargetRankLabel    = rankLabel

    local targetFragment = ZO_SimpleSceneFragment:New(targetFrame)
    function targetFragment:Show()
        local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultTargetSV
        local isUnlocked = (sv.targetLocked == false)
        if isUnlocked then
            Frames.ShowTargetPreview()
        elseif DoesUnitExist("reticleover") then
            Frames.UpdateTargetData()
        else
            self.control:SetHidden(true)
        end
        self:OnShown()
    end

    Frames.TargetFragment = targetFragment
    HUD_SCENE:AddFragment(targetFragment)
    HUD_UI_SCENE:AddFragment(targetFragment)

    Frames.ApplyTargetLayout()
    Frames.UpdateDefaultTargetVisibility()
end

-- 9. МЕНЮ НАСТРОЕК ЦЕЛИ (LAM)
function Frames.GetTargetMenuOptions()
    local styleNames, styleIds = {}, {}
    if Frames.TARGET_STYLES then
        for id = 1, #Frames.TARGET_STYLES do
            local st = Frames.TARGET_STYLES[id]
            if st then
                local str = GetString(_G[st.name] or st.name)
                table.insert(styleNames, str)
                table.insert(styleIds, id)
            end
        end
    end

    local texNames, texIds = {}, {}
    if Frames.TARGET_BAR_TEXTURES then
        for id = 1, #Frames.TARGET_BAR_TEXTURES do
            local tex = Frames.TARGET_BAR_TEXTURES[id]
            if tex then
                local str = GetString(_G[tex.name] or tex.name)
                table.insert(texNames, str)
                table.insert(texIds, id)
            end
        end
    end

    return {
        type = "submenu",
        name = GetString(SI_NC_LAM_TARGET_HDR_MAIN),
        controls = {
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetEnabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetEnabled = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                        if Frames.UpdateDefaultTargetVisibility then Frames.UpdateDefaultTargetVisibility() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_HIDE_DEFAULT),
                disabled = function() return not (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetEnabled ~= false) end,
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.hideDefaultTarget ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.hideDefaultTarget = v
                        if Frames.UpdateDefaultTargetVisibility then Frames.UpdateDefaultTargetVisibility() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_UNLOCK),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetLocked == false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetLocked = not v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TARGET_STYLE),
                tooltip = GetString(SI_NC_LAM_TARGET_STYLE_TT),
                choices = styleNames,
                choicesValues = styleIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetFrameStyle) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetFrameStyle = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TARGET_STYLE_COLOR),
                choices = { GetString(SI_NC_LAM_COLOR_GREEN), GetString(SI_NC_LAM_COLOR_BLUE) },
                choicesValues = { 1, 2 },
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.targetFrameStyle) or 1
                    local style = Frames.TARGET_STYLES and Frames.TARGET_STYLES[styleId]
                    return not (style and style.colorVariants)
                end,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetStyleColor) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetStyleColor = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TARGET_TEX_BAR),
                choices = texNames,
                choicesValues = texIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetBarTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetBarTexture = v
                        if Frames.ApplyTargetBarTexture then Frames.ApplyTargetBarTexture() end
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
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TARGET_NAME_FORMAT),
                choices = { GetString(SI_NC_LAM_TARGET_NAME_CHAR), GetString(SI_NC_LAM_TARGET_NAME_ID), GetString(SI_NC_LAM_TARGET_NAME_BOTH) },
                choicesValues = { 1, 2, 3 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.nameFormat) or 3 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.nameFormat = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_SHOW_CLASS),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showClass ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showClass = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_SHOW_ALLIANCE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showAlliance ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showAlliance = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TARGET_LEVEL_MODE),
                choices = { GetString(SI_NC_LAM_TARGET_LEVEL_MODE_PLAYERS), GetString(SI_NC_LAM_TARGET_LEVEL_MODE_ALL), GetString(SI_NC_LAM_TARGET_LEVEL_MODE_NONE) },
                choicesValues = { 1, 2, 3 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.levelDisplayMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.levelDisplayMode = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_TARGET_CP_COLOR_MODE),
                choices = { GetString(SI_NC_LAM_TARGET_CP_MODE_TIERS), GetString(SI_NC_LAM_TARGET_CP_MODE_WHITE), GetString(SI_NC_LAM_TARGET_CP_MODE_CUSTOM) },
                choicesValues = { 1, 2, 3 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.cpColorMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.cpColorMode = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_CP_COLOR_CUSTOM),
                disabled = function() return ((NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.cpColorMode) or 1) ~= 3 end,
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.customCpColor) or { 1.0, 0.85, 0.2, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.customCpColor = { r, g, b, a }
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_SHOW_RACE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showRace ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showRace = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_SHOW_RANK),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showRank ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showRank = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_SHOW_SKULL),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.showSkull ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.showSkull = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },

            -- Добивание
            { type = "header", name = GetString(SI_NC_LAM_TARGET_HDR_EXECUTE) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_EXECUTE_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.executeEnabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.executeEnabled = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_EXECUTE_THRESHOLD),
                min = 15, max = 50, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.executeThreshold) or 25 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.executeThreshold = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },

            -- Размеры и шрифты
            { type = "header", name = GetString(SI_NC_LAM_HDR_SIZES) },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_SCALE),
                min = 70, max = 150, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetScale) or 100 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetScale = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_WIDTH),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.targetFrameStyle) or 1
                    local style = Frames.TARGET_STYLES and Frames.TARGET_STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.targetFrameStyle) or 1
                    local style = Frames.TARGET_STYLES and Frames.TARGET_STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 160, max = 360, step = 10,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetWidth) or 240 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetWidth = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_HEIGHT),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.targetFrameStyle) or 1
                    local style = Frames.TARGET_STYLES and Frames.TARGET_STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.frames
                    local styleId = (sv and sv.targetFrameStyle) or 1
                    local style = Frames.TARGET_STYLES and Frames.TARGET_STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 16, max = 36, step = 2,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetHeight) or 22 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetHeight = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_FONT_SIZE),
                min = 10, max = 22, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.fontSize) or 14 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.fontSize = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_TOP_FONT_SIZE),
                min = 12, max = 22, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.topFontSize) or 15 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.topFontSize = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_TOP_OFFSET_Y),
                min = -40, max = 10, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.topOffsetY) or -4 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.topOffsetY = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_SUB_FONT_SIZE),
                min = 10, max = 20, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.subFontSize) or 14 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.subFontSize = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_SKULL_SIZE),
                min = 16, max = 100, step = 2,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.skullSize) or 40 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.skullSize = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_SKULL_Y),
                min = -60, max = 40, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.skullOffsetY) or 4 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.skullOffsetY = v
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "button",
                name = GetString(SI_NC_LAM_TARGET_RESET_POS),
                func = function()
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetLeft = 840
                        NecroCat.savedVars.frames.targetTop  = 650
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },

            -- Цвета
            { type = "header", name = GetString(SI_NC_LAM_TARGET_HDR_COLORS) },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_HOSTILE),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.hostileColor) or { 0.76, 0.12, 0.12, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.hostileColor = { r, g, b, a }
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_NEUTRAL),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.neutralColor) or { 0.85, 0.75, 0.15, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.neutralColor = { r, g, b, a }
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_FRIENDLY),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.friendlyColor) or { 0.14, 0.65, 0.22, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.friendlyColor = { r, g, b, a }
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_SHIELD),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetShieldColor) or { 0.25, 0.75, 0.95, 0.55 }
                    return c[1], c[2], c[3], c[4] or 0.55
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetShieldColor = { r, g, b, a }
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_TEXT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.targetTextColor) or { 1.0, 1.0, 1.0, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.targetTextColor = { r, g, b, a }
                        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_RANK),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.rankColor) or defaultTargetSV.rankColor or { 0.90, 0.77, 0.57, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.rankColor = { r, g, b, a }
                        if Frames.ApplyTargetColors then Frames.ApplyTargetColors() end
                    end
                end,
            },
        },
    }
end

-- 10. СОБЫТИЯ ЦЕЛИ
local function OnTargetChanged()
    Frames.UpdateTargetData()
end

local function OnTargetPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if unitTag == "reticleover" and powerType == POWERTYPE_HEALTH then
        Frames.UpdateTargetHealth()
    end
end

local function OnTargetVisualChanged(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, value, maxValue, sequenceId)
    if unitTag == "reticleover" and unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
        Frames.UpdateTargetHealth()
    end
end

local function OnTargetPlayerActivated()
    Frames.CreateTargetFrame()
    Frames.UpdateTargetData() -- Принудительно гасим цель при входе в зону, если в прицеле никого нет
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Target_Activated", EVENT_PLAYER_ACTIVATED, OnTargetPlayerActivated)
EVENT_MANAGER:RegisterForEvent("NecroCat_Target_Changed", EVENT_RETICLE_TARGET_CHANGED, OnTargetChanged)

EVENT_MANAGER:RegisterForEvent("NecroCat_Target_Power", EVENT_POWER_UPDATE, OnTargetPowerUpdate)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Target_Power", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "reticleover")

EVENT_MANAGER:RegisterForEvent("NecroCat_Target_VisualAdd", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnTargetVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Target_VisualAdd", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "reticleover")

EVENT_MANAGER:RegisterForEvent("NecroCat_Target_VisualUpd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnTargetVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Target_VisualUpd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "reticleover")

EVENT_MANAGER:RegisterForEvent("NecroCat_Target_VisualRem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnTargetVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Target_VisualRem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "reticleover")