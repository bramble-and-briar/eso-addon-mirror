-- =========================================================
-- NecroCat: Boss Frame Module (Фрейм босса)
-- =========================================================

if not NecroCat then NecroCat = {} end
NecroCat.Frames = NecroCat.Frames or {}
local Frames = NecroCat.Frames

local defaultBossSV = {
    bossEnabled          = false,
    hideDefaultBossBar   = true,
    bossPosMode          = 1,     -- 1: Заменять компас, 2: Свободное перемещение
    bossFrameStyle       = 1,     -- 1: Минимал, 2: Вампир, 3: Кошка, 4: Мыши
    bossStyleColor       = 1,     -- 1: Зеленый, 2: Синий
    bossBarTexture       = 1,     -- 1: Гладкая
    bossScale            = 100,   -- Масштаб в % (70-150)
    bossLeft             = 660,
    bossTop              = 120,
    bossWidth            = 780,   -- Монументальный босс-бар по умолчанию
    bossHeight           = 26,
    bossLocked           = true,
    bossTextMode         = 1,     -- 1: Сплит, 2: Центр (все), 3: Центр (цифры), 4: Центр (%), 5: Без текста
    bossHealthCenterFill = false,
    bossShowName         = true,
    bossShowSkull        = true,
    bossSkullSize        = 64,
    bossSkullOffsetY     = -15,
    bossFontSize         = 15,
    bossNameSize         = 16,
    bossExecuteEnabled   = true,
    bossExecuteThreshold = 25,
    bossColor            = { 0.76, 0.12, 0.12, 1.0 },
    bossShieldColor      = { 0.25, 0.75, 0.95, 0.55 },
    bossTextColor        = { 1.0, 1.0, 1.0, 1.0 },
}

-- =========================================================
-- ТАБЛИЦА СТИЛЕЙ ОФОРМЛЕНИЯ БОССА (АВТОНОМНАЯ)
-- =========================================================
Frames.BOSS_STYLES = {
    -- 1. СТИЛЬ: ПО УМОЛЧАНИЮ (МИНИМАЛИЗМ)
    [1] = {
        id           = 1,
        name         = "SI_NC_LAM_STYLE_DEFAULT",
        hasArt       = false,
        labelPadX    = 10,
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
        artW         = 855,
        artH         = 126,
        artOffsetX   = 1,
        artOffsetY   = 7,
        barW         = 755,
        barH         = 36,
        insetX       = 0,
        insetY       = 3,
        labelPadX    = 8,
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
                art  = "NecroCat/imgs/frames/target_backplate_cat.dds",
            },
        },
        artW         = 835,
        artH         = 72,
        artOffsetX   = -2,
        artOffsetY   = 0,
        barW         = 805,
        barH         = 37,
        insetX       = 0,
        insetY       = 3,
        labelPadX    = 8,
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
                art  = "NecroCat/imgs/frames/boss_backplate_bat.dds",
            },
        },
        artW         = 825,
        artH         = 56,
        artOffsetX   = 0,
        artOffsetY   = 0,
        barW         = 805,
        barH         = 36,
        insetX       = 0,
        insetY       = 3,
        labelPadX    = 8,
        labelOffsetY = 4,
    },
}

-- БИБЛИОТЕКА ТЕКСТУР ЗАПОЛНЕНИЯ ПОЛОСЫ БОССА
Frames.BOSS_BAR_TEXTURES = {
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

-- 1. ФОРМАТИРОВАНИЕ ЧИСЕЛ
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

local function GetOrCreateChild(parent, name, controlType)
    local child = parent:GetNamedChild(name)
    if child then return child end
    return WINDOW_MANAGER:CreateControl("$(parent)" .. name, parent, controlType)
end

-- 2. УПРАВЛЕНИЕ СТАНДАРТНЫМ БОСС-БАРОМ
function Frames.UpdateDefaultBossBarsVisibility()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV
    local shouldHideDefault = (sv.bossEnabled ~= false) and (sv.hideDefaultBossBar ~= false)

    if ZO_BossBar then
        if not Frames.bossBarHooked then
            ZO_PreHook(ZO_BossBar, "SetHidden", function(self, hidden)
                local s = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV
                if (not hidden) and (s.bossEnabled ~= false) and (s.hideDefaultBossBar ~= false) then
                    return true
                end
            end)
            Frames.bossBarHooked = true
        end

        if shouldHideDefault then
            ZO_BossBar:SetHidden(true)
        else
            ZO_BossBar:SetHidden(not DoesUnitExist("boss1"))
        end
    end
end

-- 3. ПРИМЕНЕНИЕ ЦВЕТОВ
function Frames.ApplyBossColors()
    if not Frames.BossHealthBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV

    local bc = sv.bossColor or defaultBossSV.bossColor
    Frames.BossHealthBar:SetColor(bc[1], bc[2], bc[3], bc[4] or 1)

    local tc = sv.bossTextColor or defaultBossSV.bossTextColor
    if Frames.BossLeftLabel then
        Frames.BossLeftLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        Frames.BossRightLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
    end

    local sc = sv.bossShieldColor or defaultBossSV.bossShieldColor
    if Frames.BossShieldBar then
        Frames.BossShieldBar:SetColor(sc[1], sc[2], sc[3], sc[4] or 0.55)
    end
end

function Frames.ApplyBossBarTexture()
    if not Frames.BossHealthBar then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV
    local texId = sv.bossBarTexture or 1
    local cfg = Frames.BOSS_BAR_TEXTURES and Frames.BOSS_BAR_TEXTURES[texId]
    if cfg and cfg.path and texId > 1 then
        Frames.BossHealthBar:SetTexture(cfg.path)
    else
        Frames.BossHealthBar:SetTexture(nil)
    end
end

-- 4. ПРИМЕНЕНИЕ РАЗМЕРОВ, ШРИФТОВ И ПРИВЯЗКИ
function Frames.ApplyBossLayout()
    if not Frames.BossFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV

    if sv.bossEnabled == false then
        Frames.BossFrame:SetHidden(true)
        return
    end

    local styleId = (sv and sv.bossFrameStyle) or 1
    local style = (Frames.BOSS_STYLES and Frames.BOSS_STYLES[styleId]) or (Frames.BOSS_STYLES and Frames.BOSS_STYLES[1]) or {}
    local colorId = (sv and sv.bossStyleColor) or 1
    local variant = (style.colorVariants and style.colorVariants[colorId]) or (style.colorVariants and style.colorVariants[1])

    local userW = sv.bossWidth or 600
    local userH = sv.bossHeight or 26
    local barW = (style.hasArt and (style.barW or userW)) or userW
    local barH = (style.hasArt and (style.barH or userH)) or userH
    local posMode = sv.bossPosMode or 1
    local isUnlocked = (sv.bossLocked == false)

    Frames.BossFrame:SetDimensions(barW, barH)
    Frames.BossFrame:ClearAnchors()

    if posMode == 1 and ZO_CompassFrame then
        Frames.BossFrame:SetAnchor(CENTER, ZO_CompassFrame, CENTER, 0, 0)
        Frames.BossFrame:SetMovable(false)
        Frames.BossFrame:SetMouseEnabled(false)
    else
        Frames.BossFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.bossLeft or 660, sv.bossTop or 120)
        Frames.BossFrame:SetMovable(isUnlocked)
        Frames.BossFrame:SetMouseEnabled(isUnlocked)
    end

    local scale = (sv.bossScale or 100) / 100
    Frames.BossFrame:SetScale(scale)

    -- Посадка арт-рамки босса (растягивается пропорционально выбранной ширине)
    if Frames.BossArtBG then
        if style.hasArt then
            local artTex  = (variant and variant.art) or style.artTexture
            local artW    = style.artW or 360
            local artH    = style.artH or 116
            local artOffX = style.artOffsetX or 0
            local artOffY = style.artOffsetY or 0

            Frames.BossArtBG:SetHidden(false)
            Frames.BossArtBG:SetTexture(artTex)
            Frames.BossArtBG:SetDimensions(artW, artH)
            Frames.BossArtBG:ClearAnchors()
            Frames.BossArtBG:SetAnchor(CENTER, Frames.BossFrame, CENTER, artOffX, artOffY)
            if Frames.BossBG then Frames.BossBG:SetHidden(true) end
        else
            Frames.BossArtBG:SetHidden(true)
            if Frames.BossBG then Frames.BossBG:SetHidden(false) end
        end
    end

    local insetX = style.insetX or 1
    local insetY = style.insetY or 1

    if Frames.BossHealthBar then
        Frames.BossHealthBar:ClearAnchors()
        Frames.BossHealthBar:SetAnchor(TOPLEFT, Frames.BossFrame, TOPLEFT, insetX, insetY)
        Frames.BossHealthBar:SetAnchor(BOTTOMRIGHT, Frames.BossFrame, BOTTOMRIGHT, -insetX, -insetY)
    end
    if Frames.BossShieldBar then
        Frames.BossShieldBar:ClearAnchors()
        Frames.BossShieldBar:SetAnchor(TOPLEFT, Frames.BossFrame, TOPLEFT, insetX, insetY)
        Frames.BossShieldBar:SetAnchor(BOTTOMRIGHT, Frames.BossFrame, BOTTOMRIGHT, -insetX, -insetY)
    end

    local barAlign = sv.bossHealthCenterFill and BAR_ALIGNMENT_CENTER or BAR_ALIGNMENT_NORMAL
    Frames.BossHealthBar:SetBarAlignment(barAlign)

    local numFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.bossFontSize or 15)
    local nameFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.bossNameSize or 16)

    Frames.BossLeftLabel:SetFont(numFont)
    Frames.BossLeftLabel:SetHeight(barH)
    Frames.BossLeftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    Frames.BossRightLabel:SetFont(numFont)
    Frames.BossRightLabel:SetHeight(barH)
    Frames.BossRightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    Frames.BossNameLabel:SetFont(nameFont)

    local skSize = sv.bossSkullSize or 44
    local skY = sv.bossSkullOffsetY or 4
    Frames.BossSkullIcon:SetDimensions(skSize, skSize)
    Frames.BossSkullIcon:ClearAnchors()
    Frames.BossSkullIcon:SetAnchor(CENTER, Frames.BossFrame, BOTTOM, 0, skY)

    local mode = sv.bossTextMode or 1
    local padX = style.labelPadX or 10
    local yOffset = style.labelOffsetY or 3

    Frames.BossLeftLabel:ClearAnchors()
    Frames.BossRightLabel:ClearAnchors()

    if mode == 1 then
        Frames.BossLeftLabel:SetAnchor(LEFT, Frames.BossFrame, LEFT, padX, yOffset)
        Frames.BossLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        Frames.BossLeftLabel:SetHidden(false)

        Frames.BossRightLabel:SetAnchor(RIGHT, Frames.BossFrame, RIGHT, -padX, yOffset)
        Frames.BossRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        Frames.BossRightLabel:SetHidden(false)
    elseif mode == 2 or mode == 3 or mode == 4 then
        Frames.BossLeftLabel:SetHidden(true)
        Frames.BossRightLabel:SetAnchor(CENTER, Frames.BossFrame, CENTER, 0, yOffset)
        Frames.BossRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        Frames.BossRightLabel:SetHidden(false)
    elseif mode == 5 then
        Frames.BossLeftLabel:SetHidden(true)
        Frames.BossRightLabel:SetHidden(true)
    end

    Frames.ApplyBossColors()
    Frames.ApplyBossBarTexture()

    -- Управляем присутствием в меню Esc: только когда разблокировано!
    local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if gameMenuScene and Frames.BossFragment then
        if isUnlocked and (sv.bossEnabled ~= false) then
            if not gameMenuScene:HasFragment(Frames.BossFragment) then
                gameMenuScene:AddFragment(Frames.BossFragment)
            end
        else
            if gameMenuScene:HasFragment(Frames.BossFragment) then
                gameMenuScene:RemoveFragment(Frames.BossFragment)
            end
        end
    end

    if not DoesUnitExist("boss1") then
        if isUnlocked then
            Frames.ShowBossPreview()
        else
            Frames.BossFrame:SetHidden(true)
        end
    else
        Frames.UpdateBossData()
    end
end

-- 5. ТЕСТОВЫЙ ПРЕДПРОСМОТР
function Frames.ShowBossPreview()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV
    Frames.BossFrame:SetHidden(false)

    if sv.bossShowName ~= false then
        Frames.BossNameLabel:SetText(GetString(SI_NC_BOSS_PREVIEW_NAME))
        Frames.BossNameLabel:SetHidden(false)
    else
        Frames.BossNameLabel:SetHidden(true)
    end

    local showSk = (sv.bossShowSkull ~= false)
    Frames.BossSkullIcon:SetHidden(not showSk)
    if showSk then
        if sv.bossExecuteEnabled ~= false then
            Frames.BossSkullIcon:SetTexture("NecroCat/imgs/frames/skull_boss_execute.dds")
        else
            Frames.BossSkullIcon:SetTexture("NecroCat/imgs/frames/skull_boss.dds")
        end
        Frames.BossSkullIcon:SetColor(1, 1, 1, 1)
        if Frames.BossExecuteSkull then Frames.BossExecuteSkull:SetHidden(true) end
    else
        if Frames.BossExecuteSkull then Frames.BossExecuteSkull:SetHidden(sv.bossExecuteEnabled == false) end
    end

    local bc = sv.bossColor or defaultBossSV.bossColor
    Frames.BossHealthBar:SetColor(bc[1], bc[2], bc[3], bc[4] or 1)
    Frames.BossHealthBar:SetMinMax(0, 100)
    Frames.BossHealthBar:SetValue(100)

    Frames.BossShieldBar:SetMinMax(0, 100)
    Frames.BossShieldBar:SetValue(30)
    Frames.BossShieldBar:SetHidden(false)

    local mode = sv.bossTextMode or 1
    if mode == 1 then
        Frames.BossLeftLabel:SetText("2.4m")
        Frames.BossRightLabel:SetText("100%")
    elseif mode == 2 then
        Frames.BossRightLabel:SetText("2.4m (100%)")
    elseif mode == 3 then
        Frames.BossRightLabel:SetText("2.4m")
    elseif mode == 4 then
        Frames.BossRightLabel:SetText("100%")
    end
end

-- 6. ОБНОВЛЕНИЕ ЗДОРОВЬЯ БОССА
function Frames.UpdateBossHealth()
    if not Frames.BossFrame or not DoesUnitExist("boss1") then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV

    local curHealth, maxHealth = GetUnitPower("boss1", POWERTYPE_HEALTH)
    if curHealth <= 0 or IsUnitDead("boss1") then
        Frames.UpdateBossData()
        return
    end

    if maxHealth <= 0 then maxHealth = 1 end

    Frames.BossHealthBar:SetMinMax(0, maxHealth)
    Frames.BossHealthBar:SetValue(curHealth)

    local shieldVal = 0
    if GetUnitAttributeVisualizerEffectInfo then
        shieldVal = GetUnitAttributeVisualizerEffectInfo("boss1", ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
    end

    if shieldVal > 0 then
        Frames.BossShieldBar:SetMinMax(0, maxHealth)
        Frames.BossShieldBar:SetValue(shieldVal)
        Frames.BossShieldBar:SetHidden(false)
    else
        Frames.BossShieldBar:SetHidden(true)
    end

    local pct = math.floor((curHealth / maxHealth) * 100)
    local isExecute = (sv.bossExecuteEnabled ~= false) and (curHealth > 0) and (pct <= (sv.bossExecuteThreshold or 25))

    local showSk = (sv.bossShowSkull ~= false)
    if showSk then
        local diff = GetUnitDifficulty("boss1")
        local isBoss = (not diff) or (diff >= 4)
        local tex
        if isBoss then
            tex = isExecute and "NecroCat/imgs/frames/skull_boss_execute.dds" or "NecroCat/imgs/frames/skull_boss.dds"
        else
            tex = isExecute and "NecroCat/imgs/frames/skull_elite_execute.dds" or "NecroCat/imgs/frames/skull_elite.dds"
        end

        Frames.BossSkullIcon:SetTexture(tex)
        Frames.BossSkullIcon:SetColor(1, 1, 1, 1)
        Frames.BossSkullIcon:SetHidden(false)
        if Frames.BossExecuteSkull then Frames.BossExecuteSkull:SetHidden(true) end
    else
        Frames.BossSkullIcon:SetHidden(true)
        if Frames.BossExecuteSkull then Frames.BossExecuteSkull:SetHidden(not isExecute) end
    end

    local mode = sv.bossTextMode or 1
    if mode == 5 then return end

    local curStr = FormatValue(curHealth)
    if mode == 1 then
        Frames.BossLeftLabel:SetText(curStr)
        Frames.BossRightLabel:SetText(string.format("%d%%", pct))
    elseif mode == 2 then
        Frames.BossRightLabel:SetText(string.format("%s (%d%%)", curStr, pct))
    elseif mode == 3 then
        Frames.BossRightLabel:SetText(curStr)
    elseif mode == 4 then
        Frames.BossRightLabel:SetText(string.format("%d%%", pct))
    end
end

-- 7. ОБНОВЛЕНИЕ ДАННЫХ БОССА
function Frames.UpdateBossData()
    if not Frames.BossFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV

    if sv.bossEnabled == false then
        Frames.BossFrame:SetHidden(true)
        return
    end

    local isDead = (not DoesUnitExist("boss1")) or IsUnitDead("boss1") or (GetUnitPower("boss1", POWERTYPE_HEALTH) <= 0)
    if isDead then
        if sv.bossLocked == false then
            Frames.ShowBossPreview()
        else
            Frames.BossFrame:SetHidden(true)
        end
        return
    end

    Frames.BossFrame:SetHidden(false)

    if sv.bossShowName ~= false then
        local rawName = GetUnitName("boss1")
        Frames.BossNameLabel:SetText(zo_strformat("<<t:1>>", rawName))
        Frames.BossNameLabel:SetHidden(false)
    else
        Frames.BossNameLabel:SetHidden(true)
    end

    if sv.bossShowSkull ~= false then
        Frames.BossSkullIcon:SetColor(1, 1, 1, 1)
    end

    Frames.UpdateBossHealth()
end

-- 8. СОЗДАНИЕ UI ФРЕЙМА БОССА
function Frames.CreateBossFrame()
    if Frames.BossFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.frames) or defaultBossSV
    local barW = sv.bossWidth or 600
    local barH = sv.bossHeight or 26

    local bossFrame = _G["NecroCat_BossFrame"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_BossFrame")
    bossFrame:SetDimensions(barW, barH)
    bossFrame:SetClampedToScreen(true)
    bossFrame:SetDrawTier(DT_HIGH)
    bossFrame:SetHidden(true)

    local bossBG = GetOrCreateChild(bossFrame, "BG", CT_BACKDROP)
    bossBG:SetAnchorFill(bossFrame)
    bossBG:SetCenterColor(0.06, 0.06, 0.06, 0.92)
    bossBG:SetEdgeColor(0.2, 0.2, 0.2, 1)
    bossBG:SetEdgeTexture("", 8, 1, 1)

    local bossArtBG = GetOrCreateChild(bossFrame, "ArtBG", CT_TEXTURE)
    bossArtBG:SetDrawLayer(DL_BACKGROUND)
    bossArtBG:SetDrawLevel(2)
    bossArtBG:SetHidden(true)

    local healthBar = GetOrCreateChild(bossFrame, "Bar", CT_STATUSBAR)
    healthBar:ClearAnchors()
    healthBar:SetAnchor(TOPLEFT, bossFrame, TOPLEFT, 1, 1)
    healthBar:SetAnchor(BOTTOMRIGHT, bossFrame, BOTTOMRIGHT, -1, -1)
    healthBar:SetDrawLayer(DL_CONTROLS)
    healthBar:SetDrawLevel(1)

    local shieldBar = GetOrCreateChild(bossFrame, "Shield", CT_STATUSBAR)
    shieldBar:ClearAnchors()
    shieldBar:SetAnchor(TOPLEFT, bossFrame, TOPLEFT, 1, 1)
    shieldBar:SetAnchor(BOTTOMRIGHT, bossFrame, BOTTOMRIGHT, -1, -1)
    shieldBar:SetDrawLayer(DL_CONTROLS)
    shieldBar:SetDrawLevel(2)
    shieldBar:SetHidden(true)

    local executeSkull = GetOrCreateChild(bossFrame, "ExecuteSkull", CT_TEXTURE)
    executeSkull:SetDimensions(30, 30)
    executeSkull:SetAnchor(CENTER, bossFrame, CENTER, 0, 0)
    executeSkull:SetTexture("/esoui/art/deathrecap/deathrecap_killingblow_icon.dds")
    executeSkull:SetColor(1.0, 0.55, 0.0, 1.0)
    executeSkull:SetDrawLayer(DL_OVERLAY)
    executeSkull:SetDrawLevel(5)
    executeSkull:SetHidden(true)

    local numFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.bossFontSize or 15)

    local leftLabel = GetOrCreateChild(bossFrame, "LeftLabel", CT_LABEL)
    leftLabel:SetFont(numFont)
    leftLabel:SetHeight(barH)
    leftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    leftLabel:SetAnchor(LEFT, bossFrame, LEFT, 10, 3)
    leftLabel:SetDrawLayer(DL_OVERLAY)
    leftLabel:SetDrawLevel(3)

    local rightLabel = GetOrCreateChild(bossFrame, "RightLabel", CT_LABEL)
    rightLabel:SetFont(numFont)
    rightLabel:SetHeight(barH)
    rightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rightLabel:SetAnchor(RIGHT, bossFrame, RIGHT, -10, 3)
    rightLabel:SetDrawLayer(DL_OVERLAY)
    rightLabel:SetDrawLevel(3)

    local nameLabel = GetOrCreateChild(bossFrame, "NameLabel", CT_LABEL)
    nameLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.bossNameSize or 16))
    nameLabel:SetAnchor(BOTTOM, bossFrame, TOP, 0, -4)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetDrawLayer(DL_OVERLAY)

    local skullIcon = GetOrCreateChild(bossFrame, "Skull", CT_TEXTURE)
    skullIcon:SetDimensions(sv.bossSkullSize or 44, sv.bossSkullSize or 44)
    skullIcon:SetAnchor(CENTER, bossFrame, BOTTOM, 0, sv.bossSkullOffsetY or 4)
    skullIcon:SetDrawLayer(DL_OVERLAY)
    skullIcon:SetDrawLevel(4)
    skullIcon:SetHidden(true)

    bossFrame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.frames then
            NecroCat.savedVars.frames.bossLeft = self:GetLeft()
            NecroCat.savedVars.frames.bossTop  = self:GetTop()
        end
    end)

    Frames.BossFrame        = bossFrame
    Frames.BossBG           = bossBG
    Frames.BossArtBG        = bossArtBG
    Frames.BossHealthBar    = healthBar
    Frames.BossShieldBar    = shieldBar
    Frames.BossExecuteSkull = executeSkull
    Frames.BossLeftLabel    = leftLabel
    Frames.BossRightLabel   = rightLabel
    Frames.BossNameLabel    = nameLabel
    Frames.BossSkullIcon    = skullIcon

    Frames.BossFragment = ZO_SimpleSceneFragment:New(bossFrame)

    Frames.ApplyBossLayout()
    Frames.UpdateDefaultBossBarsVisibility()
end

-- 9. МЕНЮ НАСТРОЕК БОССА (LAM)
function Frames.GetBossMenuOptions()
    return {
        type = "submenu",
        name = GetString(SI_NC_LAM_BOSS_HDR_MAIN),
        controls = {
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_BOSS_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossEnabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossEnabled = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                        if Frames.UpdateDefaultBossBarsVisibility then Frames.UpdateDefaultBossBarsVisibility() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_BOSS_UNLOCK),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossLocked == false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossLocked = not v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_BOSS_HIDE_DEFAULT),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.hideDefaultBossBar ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.hideDefaultBossBar = v
                        if Frames.UpdateDefaultBossBarsVisibility then Frames.UpdateDefaultBossBarsVisibility() end
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_BOSS_POS_MODE),
                choices = { GetString(SI_NC_LAM_BOSS_POS_COMPASS), GetString(SI_NC_LAM_BOSS_POS_CUSTOM) },
                choicesValues = { 1, 2 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossPosMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossPosMode = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_HEALTH_CENTER_FILL),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossHealthCenterFill end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossHealthCenterFill = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_BOSS_SHOW_NAME),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossShowName ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossShowName = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_BOSS_SHOW_SKULL),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossShowSkull ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossShowSkull = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },

            -- Добивание
            { type = "header", name = GetString(SI_NC_LAM_TARGET_HDR_EXECUTE) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_TARGET_EXECUTE_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossExecuteEnabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossExecuteEnabled = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_EXECUTE_THRESHOLD),
                min = 15, max = 50, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossExecuteThreshold) or 25 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossExecuteThreshold = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },

            -- Размеры и шрифты
            { type = "header", name = GetString(SI_NC_LAM_HDR_SIZES) },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_BOSS_WIDTH),
                min = 260, max = 900, step = 10,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossWidth) or 600 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossWidth = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_BOSS_HEIGHT),
                min = 18, max = 46, step = 2,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossHeight) or 26 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossHeight = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_BOSS_FONT_SIZE),
                min = 10, max = 24, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossFontSize) or 15 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossFontSize = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_BOSS_NAME_SIZE),
                min = 12, max = 26, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossNameSize) or 16 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossNameSize = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_SKULL_SIZE),
                min = 20, max = 100, step = 2,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossSkullSize) or 44 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossSkullSize = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_TARGET_SKULL_Y),
                min = -60, max = 25, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossSkullOffsetY) or 4 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossSkullOffsetY = v
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "button",
                name = GetString(SI_NC_LAM_BOSS_RESET_POS),
                func = function()
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossLeft = 660
                        NecroCat.savedVars.frames.bossTop  = 120
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },

            -- Цвета
            { type = "header", name = GetString(SI_NC_LAM_TARGET_HDR_COLORS) },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_HOSTILE),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossColor) or { 0.76, 0.12, 0.12, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossColor = { r, g, b, a }
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_SHIELD),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossShieldColor) or { 0.25, 0.75, 0.95, 0.55 }
                    return c[1], c[2], c[3], c[4] or 0.55
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossShieldColor = { r, g, b, a }
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = GetString(SI_NC_LAM_TARGET_COLOR_TEXT),
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.frames and NecroCat.savedVars.frames.bossTextColor) or { 1.0, 1.0, 1.0, 1.0 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.frames then
                        NecroCat.savedVars.frames.bossTextColor = { r, g, b, a }
                        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
            },
        },
    }
end

-- 10. СОБЫТИЯ БОССА
local function OnBossesChanged()
    Frames.UpdateBossData()
end

local function OnBossPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if unitTag == "boss1" and powerType == POWERTYPE_HEALTH then
        Frames.UpdateBossHealth()
    end
end

local function OnBossVisualChanged(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, value, maxValue, sequenceId)
    if unitTag == "boss1" and unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
        Frames.UpdateBossHealth()
    end
end

local function OnBossPlayerActivated()
    Frames.CreateBossFrame()
    Frames.UpdateBossData() -- Принудительно проверяем босса при каждой смене зоны/данжа
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Boss_Activated", EVENT_PLAYER_ACTIVATED, OnBossPlayerActivated)
EVENT_MANAGER:RegisterForEvent("NecroCat_Bosses_Changed", EVENT_BOSSES_CHANGED, OnBossesChanged)

EVENT_MANAGER:RegisterForEvent("NecroCat_Boss_Power", EVENT_POWER_UPDATE, OnBossPowerUpdate)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Boss_Power", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "boss1")

EVENT_MANAGER:RegisterForEvent("NecroCat_Boss_VisualAdd", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnBossVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Boss_VisualAdd", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "boss1")

EVENT_MANAGER:RegisterForEvent("NecroCat_Boss_VisualUpd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnBossVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Boss_VisualUpd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "boss1")

EVENT_MANAGER:RegisterForEvent("NecroCat_Boss_VisualRem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnBossVisualChanged)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Boss_VisualRem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "boss1")