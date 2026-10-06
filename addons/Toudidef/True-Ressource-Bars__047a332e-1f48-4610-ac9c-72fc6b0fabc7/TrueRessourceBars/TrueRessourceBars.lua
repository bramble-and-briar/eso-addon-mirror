-- Initialisation de l'addon
local TrueRessourceBars = {
    name = "TrueRessourceBars",
    version = "3.2",
    updateInterval = 50,
    previewMode = false,
    controls = {
        targetBuffs = {},
        targetDebuffs = {}
    },
    shieldCache = {
        player = 0,
        reticleover = 0
    }
}

-- Constantes des attributs de combat ESO
local MECHANIC_HEALTH  = COMBAT_MECHANIC_FLAGS_HEALTH or 1
local MECHANIC_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA or 2
local MECHANIC_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA or 4

-- Épaisseur de la bordure noire : 3 pixels
local BORDER_SIZE = 3

-- Mapping des polices Gamepad & Natives
local fontMapping = {
    ["Gamepad Medium"]   = "$(GAMEPAD_MEDIUM_FONT)",
    ["Gamepad Bold"]     = "$(GAMEPAD_BOLD_FONT)",
    ["Medium (Default)"] = "$(MEDIUM_FONT)",
    ["Bold"]             = "$(BOLD_FONT)",
    ["Antique"]          = "$(ANTIQUE_FONT)",
    ["Stone Tablet"]     = "$(STONE_TABLET_FONT)",
    ["Chat Font"]        = "$(CHAT_FONT)"
}

local fontChoices = {
    "Gamepad Medium",
    "Gamepad Bold",
    "Medium (Default)",
    "Bold",
    "Antique",
    "Stone Tablet",
    "Chat Font"
}

-- Styles d'ombrage et de contour pour la lisibilité
local AVAILABLE_STYLES = {
    { name = "Outline",           value = FONT_STYLE_OUTLINE or 1 },
    { name = "Thick Soft Shadow", value = FONT_STYLE_SOFT_SHADOW_THICK or 4 },
    { name = "Thin Soft Shadow",  value = FONT_STYLE_SOFT_SHADOW_THIN or 3 },
    { name = "Drop Shadow",       value = FONT_STYLE_SHADOW or 2 },
    { name = "None",              value = FONT_STYLE_NONE or 0 },
}

local styleToStringMapping = {
    [FONT_STYLE_OUTLINE or 1]           = "outline",
    [FONT_STYLE_SOFT_SHADOW_THICK or 4] = "soft-shadow-thick",
    [FONT_STYLE_SOFT_SHADOW_THIN or 3]  = "soft-shadow-thin",
    [FONT_STYLE_SHADOW or 2]            = "shadow",
    [FONT_STYLE_NONE or 0]              = ""
}

local availableStyleChoices = {}
for _, entry in ipairs(AVAILABLE_STYLES) do
    table.insert(availableStyleChoices, entry.name)
end

local function GetStyleDescriptor(selectedStyleName)
    for _, styleEntry in ipairs(AVAILABLE_STYLES) do
        if styleEntry.name == selectedStyleName then
            return styleToStringMapping[styleEntry.value] or "outline"
        end
    end
    return "outline"
end

-- Emplacements dans les coins pour la valeur du bouclier
local cornerPositionMapping = {
    ["Top Left"]     = { point = TOPLEFT, relPoint = TOPLEFT, x = 6, y = 2 },
    ["Top Right"]    = { point = TOPRIGHT, relPoint = TOPRIGHT, x = -6, y = 2 },
    ["Bottom Left"]  = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 6, y = -2 },
    ["Bottom Right"] = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = -6, y = -2 },
    ["Left"]         = { point = LEFT, relPoint = LEFT, x = 6, y = 0 },
    ["Right"]        = { point = RIGHT, relPoint = RIGHT, x = -6, y = 0 },
}

local cornerPositionChoices = {
    "Top Left",
    "Top Right",
    "Bottom Left",
    "Bottom Right",
    "Left",
    "Right"
}

-- Positions pour le TEMPS des auras
local timerPositionMapping = {
    ["Top Left"]      = { point = TOPLEFT, relPoint = TOPLEFT, x = 0, y = 0 },
    ["Top Right"]     = { point = TOPRIGHT, relPoint = TOPRIGHT, x = 0, y = 0 },
    ["Bottom Left"]   = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 0, y = 0 },
    ["Bottom Right"]  = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = 0, y = 0 },
    ["Center"]        = { point = CENTER, relPoint = CENTER, x = 0, y = 0 },
    ["Low Center"]    = { point = BOTTOM, relPoint = BOTTOM, x = 0, y = -3 },
    ["Below Center"]  = { point = TOP, relPoint = BOTTOM, x = 0, y = 2 },
    ["Above Center"]  = { point = BOTTOM, relPoint = TOP, x = 0, y = -2 },
    ["Left Center"]   = { point = RIGHT, relPoint = LEFT, x = -4, y = 0 },
    ["Right Center"]  = { point = LEFT, relPoint = RIGHT, x = 4, y = 0 }
}

local timerPositionChoices = {
    "Top Left",
    "Top Right",
    "Bottom Left",
    "Bottom Right",
    "Center",
    "Low Center",
    "Below Center",
    "Above Center",
    "Left Center",
    "Right Center"
}

-- Positions pour les STACKS des auras
local stackPositionMapping = {
    ["Top Left"]     = { point = TOPLEFT, relPoint = TOPLEFT, x = 2, y = 2 },
    ["Top Right"]    = { point = TOPRIGHT, relPoint = TOPRIGHT, x = -2, y = 2 },
    ["Bottom Left"]  = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 2, y = -2 },
    ["Bottom Right"] = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = -2, y = -2 },
    ["Center"]       = { point = CENTER, relPoint = CENTER, x = 0, y = 0 }
}

local stackPositionChoices = {
    "Top Left",
    "Top Right",
    "Bottom Left",
    "Bottom Right",
    "Center"
}

local auraOrientationChoices = {
    "Horizontal (Left to Right)",
    "Horizontal (Right to Left)",
    "Horizontal (Centered)",
    "Vertical (Top to Bottom)",
    "Vertical (Bottom to Top)",
    "Vertical (Centered)"
}

-- Valeurs par défaut sauvegardées
local defaults = {
    bars = {
        health = {
            enabled = "Yes",
            x = 0, y = 340, width = 360, height = 28,
            color = { r = 0.85, g = 0.15, b = 0.15, a = 1 },
            shieldColor = { r = 0.75, g = 0.25, b = 0.95, a = 0.75 },
            shieldValuePos = "Top Right",
            font = "Gamepad Bold", fontSize = 18, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "Right to Left",
            warningEnabled = true,
            warningThreshold = 35,
            warningPulseSpeed = 120,
        },
        magicka = {
            enabled = "Yes",
            x = -220, y = 380, width = 260, height = 24,
            color = { r = 0.15, g = 0.45, b = 0.95, a = 1 },
            font = "Gamepad Bold", fontSize = 16, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "Right to Left",
            warningEnabled = false,
            warningThreshold = 25,
            warningPulseSpeed = 120,
        },
        stamina = {
            enabled = "Yes",
            x = 220, y = 380, width = 260, height = 24,
            color = { r = 0.15, g = 0.85, b = 0.25, a = 1 },
            font = "Gamepad Bold", fontSize = 16, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "Left to Right",
            warningEnabled = false,
            warningThreshold = 25,
            warningPulseSpeed = 120,
        },
        target = {
            enabled = "Yes",
            x = 0, y = -340, width = 460, height = 32,
            color = { r = 0.85, g = 0.15, b = 0.15, a = 1 },
            shieldColor = { r = 0.75, g = 0.25, b = 0.95, a = 0.75 },
            shieldValuePos = "Top Right",
            targetNamePosition = "Above",
            targetNameFontSize = 18,
            font = "Gamepad Bold", fontSize = 20, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "To Center",
            warningEnabled = false,
            warningThreshold = 25,
            warningPulseSpeed = 120,
        }
    },
    targetAuras = {
        buffsEnabled = "Yes",
        debuffsEnabled = "Yes",
        buffX = 5, buffY = -295,
        debuffX = 5, debuffY = -385,

        buffDir = "Horizontal (Centered)",
        debuffDir = "Horizontal (Centered)",

        buffEnableGrid = false,
        buffMaxPerRow = 8,
        buffRowDirection = "Below",

        debuffEnableGrid = false,
        debuffMaxPerRow = 8,
        debuffRowDirection = "Above",

        iconSize = 38,
        spacing = 4,
        fontStyle = "Gamepad Medium",
        fontOutlineStyle = "Outline",

        timerBuffPos = "Low Center",
        timerDebuffPos = "Low Center",
        timerSize = 16,
        timerColor = { r = 1, g = 1, b = 1, a = 1 },

        stackBuffPos = "Top Right",
        stackDebuffPos = "Top Right",
        stackSize = 16,
        stackColor = { r = 1, g = 0.8, b = 0, a = 1 },

        hidePermanent = false,
        hideLongBuffs = false,
        longBuffThreshold = 60
    }
}

-- Échantillons factices pour l'aperçu
local dummyBuffData = {
    { icon = "/esoui/art/icons/ability_warrior_010.dds", time = 25 },
    { icon = "/esoui/art/icons/ability_rogue_038.dds", time = 120 },
    { icon = "/esoui/art/icons/icon_experience_scroll.dds", time = 3600 },
    { icon = "/esoui/art/icons/ability_mage_065.dds", time = 8 },
    { icon = "/esoui/art/icons/ability_healer_018.dds", time = 45 },
    { icon = "/esoui/art/icons/ability_warden_001.dds", time = 90 },
    { icon = "/esoui/art/icons/ability_sorcerer_thunderous_strike.dds", time = 15 },
    { icon = "/esoui/art/icons/ability_restorationstaff_001.dds", time = 5 },
    { icon = "/esoui/art/icons/ability_templar_sun_shield.dds", time = 60 },
    { icon = "/esoui/art/icons/ability_dragonknight_004.dds", time = 180 }
}

local dummyDebuffData = {
    { icon = "/esoui/art/icons/ability_debuff_snare.dds", time = 6 },
    { icon = "/esoui/art/icons/ability_debuff_disease.dds", time = 20 },
    { icon = "/esoui/art/icons/ability_debuff_minor_vulnerability.dds", time = 12 },
    { icon = "/esoui/art/icons/ability_debuff_minor_breach.dds", time = 30 },
    { icon = "/esoui/art/icons/ability_debuff_major_breach.dds", time = 4 }
}

-- Extraction sécurisée des composantes RVBA
local function GetRGBA(c, defR, defG, defB, defA)
    if type(c) ~= "table" then
        return defR or 1, defG or 1, defB or 1, defA or 1
    end
    local r = c.r or c[1] or defR or 1
    local g = c.g or c[2] or defG or 1
    local b = c.b or c[3] or defB or 1
    local a = c.a or c[4] or defA or 1
    return r, g, b, a
end

-- Application uniforme de la couleur unie
local function SetBarColor(bar, colorTable, alphaOverride)
    if not bar then return end
    local r, g, b, a = GetRGBA(colorTable, 1, 1, 1, 1)
    if alphaOverride then a = alphaOverride end
    bar:SetColor(r, g, b, a)
    bar:SetGradientColors(r, g, b, a, r, g, b, a)
end

-- Récupération sécurisée des ressources
local function GetPower(unitTag, mechanicType)
    local cur, max, eff = GetUnitPower(unitTag, mechanicType)
    if (not eff or eff == 0) and (not cur or cur == 0) then
        if mechanicType == MECHANIC_HEALTH then
            cur, max, eff = GetUnitPower(unitTag, 1)
        elseif mechanicType == MECHANIC_MAGICKA then
            cur, max, eff = GetUnitPower(unitTag, 2)
        elseif mechanicType == MECHANIC_STAMINA then
            cur, max, eff = GetUnitPower(unitTag, 4)
        end
    end
    return cur or 0, max or 0, (eff and eff > 0) and eff or (max or 1)
end

local function FormatNumber(value)
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    else
        return tostring(math.floor(value))
    end
end

-- Formatage du temps en texte lisible
local function FormatTime(seconds)
    if seconds <= 0 then return "" end
    if seconds > 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds > 60 then
        return string.format("%dm", math.floor(seconds / 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

-- Récupération du bouclier (Damage Shield)
local function GetShieldValue(unitTag)
    if TrueRessourceBars.shieldCache[unitTag] and TrueRessourceBars.shieldCache[unitTag] > 0 then
        return TrueRessourceBars.shieldCache[unitTag]
    end

    local value = GetUnitAttributeVisualizerEffectInfo(
        unitTag,
        ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION or 2,
        ATTRIBUTE_HEALTH,
        MECHANIC_HEALTH
    )
    if value and value > 0 then return value end

    local valueDef = GetUnitAttributeVisualizerEffectInfo(
        unitTag,
        ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_DEFENSE or 1,
        ATTRIBUTE_HEALTH,
        MECHANIC_HEALTH
    )
    if valueDef and valueDef > 0 then return valueDef end

    return 0
end

-- Calcul mathématique du double-pulsation
local function GetDoublePulseAlpha(pulseSpeed)
    local p = math.max(40, pulseSpeed or 120)
    local gap = math.floor(p * 0.7)
    local pause = math.floor(p * 2.4)
    local totalCycle = (4 * p) + gap + pause

    local now = GetFrameTimeMilliseconds()
    local t = now % totalCycle

    if t < p then
        return 1.0 - (0.85 * (t / p))
    elseif t < (2 * p) then
        return 0.15 + (0.85 * ((t - p) / p))
    elseif t < (2 * p + gap) then
        return 1.0
    elseif t < (3 * p + gap) then
        local elapsed = t - (2 * p + gap)
        return 1.0 - (0.85 * (elapsed / p))
    elseif t < (4 * p + gap) then
        local elapsed = t - (3 * p + gap)
        return 0.15 + (0.85 * (elapsed / p))
    else
        return 1.0
    end
end

-- Création d'une barre unie
local function CreateBarControl(barKey, config)
    local wm = WINDOW_MANAGER
    local name = TrueRessourceBars.name .. "_" .. barKey

    local container = wm:CreateControl(name .. "Container", TrueRessourceBars.root, CT_CONTROL)
    container:SetDimensions(config.width, config.height)
    container:SetAnchor(CENTER, GuiRoot, CENTER, config.x, config.y)

    local border = wm:CreateControl(name .. "Border", container, CT_TEXTURE)
    border:SetAnchor(TOPLEFT, container, TOPLEFT, -BORDER_SIZE, -BORDER_SIZE)
    border:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, BORDER_SIZE, BORDER_SIZE)
    border:SetColor(0, 0, 0, 1)
    border:SetDrawTier(DT_LOW)

    local bg = wm:CreateControl(name .. "BG", container, CT_TEXTURE)
    bg:SetAnchorFill()
    bg:SetColor(0.04, 0.04, 0.05, 0.95)
    bg:SetDrawTier(DT_LOW)

    local lossBarNormal = wm:CreateControl(name .. "LossNormal", container, CT_STATUSBAR)
    lossBarNormal:SetAnchorFill()
    lossBarNormal:SetDrawTier(DT_MEDIUM)

    local barNormal = wm:CreateControl(name .. "BarNormal", container, CT_STATUSBAR)
    barNormal:SetAnchorFill()
    barNormal:SetDrawTier(DT_HIGH)

    local halfWidth = config.width / 2

    local lossCenterL = wm:CreateControl(name .. "LossCenterL", container, CT_STATUSBAR)
    lossCenterL:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    lossCenterL:SetDimensions(halfWidth, config.height)
    lossCenterL:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
    lossCenterL:SetDrawTier(DT_MEDIUM)

    local lossCenterR = wm:CreateControl(name .. "LossCenterR", container, CT_STATUSBAR)
    lossCenterR:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, 0)
    lossCenterR:SetDimensions(halfWidth, config.height)
    lossCenterR:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    lossCenterR:SetDrawTier(DT_MEDIUM)

    local barCenterL = wm:CreateControl(name .. "BarCenterL", container, CT_STATUSBAR)
    barCenterL:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    barCenterL:SetDimensions(halfWidth, config.height)
    barCenterL:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
    barCenterL:SetDrawTier(DT_HIGH)

    local barCenterR = wm:CreateControl(name .. "BarCenterR", container, CT_STATUSBAR)
    barCenterR:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, 0)
    barCenterR:SetDimensions(halfWidth, config.height)
    barCenterR:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    barCenterR:SetDrawTier(DT_HIGH)

    local shieldBar = wm:CreateControl(name .. "ShieldBar", container, CT_STATUSBAR)
    shieldBar:SetDrawTier(DT_HIGH)
    shieldBar:SetHidden(true)

    local label = wm:CreateControl(name .. "Label", container, CT_LABEL)
    label:SetAnchor(CENTER, container, CENTER, 0, 0)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawTier(DT_HIGH)

    local shieldLabel = wm:CreateControl(name .. "ShieldLabel", container, CT_LABEL)
    shieldLabel:SetDrawLayer(DL_OVERLAY)
    shieldLabel:SetDrawTier(DT_HIGH)

    local targetNameLabel = nil
    if barKey == "target" then
        targetNameLabel = wm:CreateControl(name .. "TargetNameLabel", container, CT_LABEL)
        targetNameLabel:SetDrawLayer(DL_OVERLAY)
        targetNameLabel:SetDrawTier(DT_HIGH)
    end

    return {
        container = container,
        border = border,
        bg = bg,
        barNormal = barNormal,
        lossBarNormal = lossBarNormal,
        barCenterL = barCenterL,
        barCenterR = barCenterR,
        lossCenterL = lossCenterL,
        lossCenterR = lossCenterR,
        shieldBar = shieldBar,
        label = label,
        shieldLabel = shieldLabel,
        targetNameLabel = targetNameLabel,
        animValue = nil
    }
end

-- Application dynamique des styles visuels
local function ApplyBarVisuals(barKey)
    local ui = TrueRessourceBars.bars[barKey]
    local cfg = TrueRessourceBars.savedVars.bars[barKey]
    if not ui or not cfg then return end

    if cfg.enabled == "No" then
        ui.container:SetHidden(true)
        return
    end

    ui.container:ClearAnchors()
    ui.container:SetAnchor(CENTER, GuiRoot, CENTER, cfg.x, cfg.y)
    ui.container:SetDimensions(cfg.width, cfg.height)
    ui.container:SetAlpha(1.0)

    SetBarColor(ui.barNormal, cfg.color)
    SetBarColor(ui.barCenterL, cfg.color)
    SetBarColor(ui.barCenterR, cfg.color)

    local r, g, b = GetRGBA(cfg.color, 1, 1, 1, 1)
    local animColor = {
        r = math.min(1, r + 0.35),
        g = math.min(1, g + 0.35),
        b = math.min(1, b + 0.35),
        a = 0.65
    }
    SetBarColor(ui.lossBarNormal, animColor)
    SetBarColor(ui.lossCenterL, animColor)
    SetBarColor(ui.lossCenterR, animColor)

    if cfg.shieldColor then
        SetBarColor(ui.shieldBar, cfg.shieldColor)
    end

    if cfg.drainDirection == "To Center" then
        ui.barNormal:SetHidden(true)
        ui.lossBarNormal:SetHidden(true)
        ui.barCenterL:SetHidden(false)
        ui.barCenterR:SetHidden(false)
        ui.lossCenterL:SetHidden(false)
        ui.lossCenterR:SetHidden(false)

        local halfW = cfg.width / 2
        ui.barCenterL:SetDimensions(halfW, cfg.height)
        ui.barCenterR:SetDimensions(halfW, cfg.height)
        ui.lossCenterL:SetDimensions(halfW, cfg.height)
        ui.lossCenterR:SetDimensions(halfW, cfg.height)
    elseif cfg.drainDirection == "Left to Right" then
        ui.barNormal:SetHidden(false)
        ui.lossBarNormal:SetHidden(false)
        ui.barCenterL:SetHidden(true)
        ui.barCenterR:SetHidden(true)
        ui.lossCenterL:SetHidden(true)
        ui.lossCenterR:SetHidden(true)

        ui.barNormal:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
        ui.lossBarNormal:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
    else
        ui.barNormal:SetHidden(false)
        ui.lossBarNormal:SetHidden(false)
        ui.barCenterL:SetHidden(true)
        ui.barCenterR:SetHidden(true)
        ui.lossCenterL:SetHidden(true)
        ui.lossCenterR:SetHidden(true)

        ui.barNormal:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
        ui.lossBarNormal:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    end

    local fontPath = fontMapping[cfg.font] or "$(GAMEPAD_BOLD_FONT)"
    local outline = GetStyleDescriptor(cfg.fontStyle)
    local fontString = string.format("%s|%d|%s", fontPath, cfg.fontSize or 18, outline)

    ui.label:SetFont(fontString)
    local tr, tg, tb, ta = GetRGBA(cfg.textColor, 1, 1, 1, 1)
    ui.label:SetColor(tr, tg, tb, ta)

    local shieldPos = cfg.shieldValuePos or "Top Right"
    local posData = cornerPositionMapping[shieldPos] or cornerPositionMapping["Top Right"]
    ui.shieldLabel:ClearAnchors()
    ui.shieldLabel:SetAnchor(posData.point, ui.container, posData.relPoint, posData.x, posData.y)
    ui.shieldLabel:SetFont(string.format("%s|%d|%s", fontPath, math.max(10, (cfg.fontSize or 18) - 3), outline))
    if cfg.shieldColor then
        local sr, sg, sb = GetRGBA(cfg.shieldColor, 1, 1, 1, 1)
        ui.shieldLabel:SetColor(sr, sg, sb, 1)
    end

    if ui.targetNameLabel then
        local namePos = cfg.targetNamePosition or "Above"
        ui.targetNameLabel:ClearAnchors()
        if namePos == "Above" then
            ui.targetNameLabel:SetAnchor(BOTTOM, ui.container, TOP, 0, -3)
            ui.targetNameLabel:SetHidden(false)
        elseif namePos == "Below" then
            ui.targetNameLabel:SetAnchor(TOP, ui.container, BOTTOM, 0, 3)
            ui.targetNameLabel:SetHidden(false)
        else
            ui.targetNameLabel:SetHidden(true)
        end

        local nameFontSize = cfg.targetNameFontSize or 18
        ui.targetNameLabel:SetFont(string.format("%s|%d|%s", fontPath, nameFontSize, outline))
        ui.targetNameLabel:SetColor(tr, tg, tb, ta)
    end
end

-- Création ou réutilisation d'un contrôle d'icône d'aura
local function GetOrCreateTargetAuraIcon(poolType, index)
    local pool = TrueRessourceBars.controls[poolType]
    local parentFrame = (poolType == "targetBuffs") and TrueRessourceBars.targetBuffFrame or TrueRessourceBars.targetDebuffFrame

    if not pool[index] then
        local ctrl = WINDOW_MANAGER:CreateControl(TrueRessourceBars.name .. poolType .. index, parentFrame, CT_TEXTURE)

        local timerLabel = WINDOW_MANAGER:CreateControl(TrueRessourceBars.name .. poolType .. "Timer" .. index, ctrl, CT_LABEL)
        timerLabel:SetDrawLayer(DL_OVERLAY)
        timerLabel:SetDrawTier(DT_HIGH)
        ctrl.timerLabel = timerLabel

        local stackLabel = WINDOW_MANAGER:CreateControl(TrueRessourceBars.name .. poolType .. "Stack" .. index, ctrl, CT_LABEL)
        stackLabel:SetDrawLayer(DL_OVERLAY)
        stackLabel:SetDrawTier(DT_HIGH)
        ctrl.stackLabel = stackLabel

        pool[index] = ctrl
    end

    local ctrl = pool[index]
    local settings = TrueRessourceBars.savedVars.targetAuras
    local selectedFont = fontMapping[settings.fontStyle] or "$(GAMEPAD_MEDIUM_FONT)"
    local styleDesc = GetStyleDescriptor(settings.fontOutlineStyle)

    ctrl:SetDimensions(settings.iconSize, settings.iconSize)

    local tFont
    if styleDesc and styleDesc ~= "" then
        tFont = string.format("%s|%d|%s", selectedFont, settings.timerSize, styleDesc)
    else
        tFont = string.format("%s|%d", selectedFont, settings.timerSize)
    end
    ctrl.timerLabel:SetFont(tFont)
    local tr, tg, tb, ta = GetRGBA(settings.timerColor, 1, 1, 1, 1)
    ctrl.timerLabel:SetColor(tr, tg, tb, ta)
    ctrl.timerLabel:ClearAnchors()

    local tPosSetting = (poolType == "targetBuffs") and settings.timerBuffPos or settings.timerDebuffPos
    local tPos = timerPositionMapping[tPosSetting]
    if tPos then
        ctrl.timerLabel:SetAnchor(tPos.point, ctrl, tPos.relPoint, tPos.x, tPos.y)
    end

    local sFont
    if styleDesc and styleDesc ~= "" then
        sFont = string.format("%s|%d|%s", selectedFont, settings.stackSize, styleDesc)
    else
        sFont = string.format("%s|%d", selectedFont, settings.stackSize)
    end
    ctrl.stackLabel:SetFont(sFont)
    local sr, sg, sb, sa = GetRGBA(settings.stackColor, 1, 0.8, 0, 1)
    ctrl.stackLabel:SetColor(sr, sg, sb, sa)
    ctrl.stackLabel:ClearAnchors()

    local sPosSetting = (poolType == "targetBuffs") and settings.stackBuffPos or settings.stackDebuffPos
    local sPos = stackPositionMapping[sPosSetting]
    if sPos then
        ctrl.stackLabel:SetAnchor(sPos.point, ctrl, sPos.relPoint, sPos.x, sPos.y)
    end

    ctrl:SetHidden(false)
    return ctrl
end

-- Calcul des ancrages
local function ApplyAuraAnchors(poolType, count, spacing, iconSize, direction, enableGrid, maxPerRow, vDir)
    if count == 0 then return end
    local pool = TrueRessourceBars.controls[poolType]
    local parent = (poolType == "targetBuffs") and TrueRessourceBars.targetBuffFrame or TrueRessourceBars.targetDebuffFrame

    if direction == "Horizontal" then direction = "Horizontal (Left to Right)" end

    local limit = enableGrid and math.max(1, maxPerRow or 1) or count

    for i = 1, count do
        local ctrl = pool[i]
        ctrl:ClearAnchors()

        if direction == "Horizontal (Left to Right)" then
            local col = (i - 1) % limit
            local row = math.floor((i - 1) / limit)
            local xOffset = col * (iconSize + spacing)
            local yOffset = (vDir == "Above") and -(row * (iconSize + spacing)) or (row * (iconSize + spacing))
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Horizontal (Right to Left)" then
            local col = (i - 1) % limit
            local row = math.floor((i - 1) / limit)
            local xOffset = -(col * (iconSize + spacing))
            local yOffset = (vDir == "Above") and -(row * (iconSize + spacing)) or (row * (iconSize + spacing))
            ctrl:SetAnchor(TOPRIGHT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Horizontal (Centered)" then
            local row = math.floor((i - 1) / limit)
            local rowStart = row * limit + 1
            local rowEnd = math.min(count, (row + 1) * limit)
            local countInRow = rowEnd - rowStart + 1
            local rowSpan = (countInRow * iconSize) + ((countInRow - 1) * spacing)
            local col = (i - 1) % limit

            local xOffset = -(rowSpan / 2) + (col * (iconSize + spacing)) + (iconSize / 2)
            local yOffset = (vDir == "Above") and -(row * (iconSize + spacing)) or (row * (iconSize + spacing))
            ctrl:SetAnchor(CENTER, parent, CENTER, xOffset, yOffset)

        elseif direction == "Vertical (Top to Bottom)" then
            local row = (i - 1) % limit
            local col = math.floor((i - 1) / limit)
            local yOffset = row * (iconSize + spacing)
            local xOffset = col * (iconSize + spacing)
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Vertical (Bottom to Top)" then
            local row = (i - 1) % limit
            local col = math.floor((i - 1) / limit)
            local yOffset = -(row * (iconSize + spacing))
            local xOffset = col * (iconSize + spacing)
            ctrl:SetAnchor(BOTTOMLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Vertical (Centered)" then
            local col = math.floor((i - 1) / limit)
            local colStart = col * limit + 1
            local colEnd = math.min(count, (col + 1) * limit)
            local countInCol = colEnd - colStart + 1
            local colSpan = (countInCol * iconSize) + ((countInCol - 1) * spacing)
            local row = (i - 1) % limit
            local yOffset = -(colSpan / 2) + row * (iconSize + spacing)
            local xOffset = col * (iconSize + spacing)
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)
        end
    end
end

-- Tri décroissant par durée restante
local function CompareEffectsDescending(a, b)
    local timeA = a.isPermanent and -1 or a.timeLeft
    local timeB = b.isPermanent and -1 or b.timeLeft

    if timeA ~= timeB then
        return timeA > timeB
    end
    return a.name < b.name
end

-- Calcul des chaînes de texte
local function BuildDisplayText(formatType, current, max, percent, extraPrefix)
    local curStr = FormatNumber(current)
    local maxStr = FormatNumber(max)
    local result = ""

    if formatType == "Current / Max (Percent)" then
        result = string.format("%s / %s (%d%%)", curStr, maxStr, percent)
    elseif formatType == "Current / Max" then
        result = string.format("%s / %s", curStr, maxStr)
    elseif formatType == "Current (Percent)" then
        result = string.format("%s (%d%%)", curStr, percent)
    elseif formatType == "Current" then
        result = curStr
    elseif formatType == "Percent" then
        result = string.format("%d%%", percent)
    end

    if extraPrefix and extraPrefix ~= "" then
        result = extraPrefix .. " : " .. result
    end
    return result
end

-- Interpolation fluide
local function LerpValue(currentVal, targetVal, speed)
    return currentVal + (targetVal - currentVal) * speed
end

-- Mise à jour unitaire d'une barre
local function UpdateSingleBar(barKey, unitTag, mechanicType)
    local ui = TrueRessourceBars.bars[barKey]
    local cfg = TrueRessourceBars.savedVars.bars[barKey]
    if not ui or not cfg then return end

    if cfg.enabled == "No" then
        ui.container:SetHidden(true)
        return
    end

    local current, max, effectiveMax
    local targetName = ""
    local isDummyTarget = (barKey == "target" and TrueRessourceBars.previewMode and not DoesUnitExist(unitTag))

    if isDummyTarget then
        ui.container:SetHidden(false)
        current = 75000
        effectiveMax = 100000
        targetName = "Target Dummy"
    else
        if not DoesUnitExist(unitTag) then
            ui.container:SetHidden(true)
            return
        end
        ui.container:SetHidden(false)
        current, max, effectiveMax = GetPower(unitTag, mechanicType)
        targetName = (unitTag == "reticleover") and GetUnitName(unitTag) or ""
    end

    local percent = effectiveMax > 0 and math.floor((current / effectiveMax) * 100) or 0

    if not ui.animValue then
        ui.animValue = current
    end

    ui.animValue = LerpValue(ui.animValue, current, 0.45)
    if math.abs(ui.animValue - current) < 1.5 then
        ui.animValue = current
    end

    local mainVal, ghostVal
    if ui.animValue > current then
        mainVal = current
        ghostVal = ui.animValue
    else
        mainVal = ui.animValue
        ghostVal = current
    end

    if cfg.drainDirection == "To Center" then
        local halfMax = effectiveMax / 2
        local halfMain = mainVal / 2
        local halfGhost = ghostVal / 2

        ui.barCenterL:SetMinMax(0, halfMax)
        ui.barCenterL:SetValue(halfMain)
        ui.barCenterR:SetMinMax(0, halfMax)
        ui.barCenterR:SetValue(halfMain)

        ui.lossCenterL:SetMinMax(0, halfMax)
        ui.lossCenterL:SetValue(halfGhost)
        ui.lossCenterR:SetMinMax(0, halfMax)
        ui.lossCenterR:SetValue(halfGhost)
    else
        ui.barNormal:SetMinMax(0, effectiveMax)
        ui.barNormal:SetValue(mainVal)

        ui.lossBarNormal:SetMinMax(0, effectiveMax)
        ui.lossBarNormal:SetValue(ghostVal)
    end

    if barKey == "target" then
        local namePos = cfg.targetNamePosition or "Above"
        if ui.targetNameLabel and (namePos == "Above" or namePos == "Below") then
            ui.targetNameLabel:SetText(targetName)
            ui.label:SetText(BuildDisplayText(cfg.textFormat, current, effectiveMax, percent, nil))
        elseif namePos == "Inside Bar" then
            if ui.targetNameLabel then ui.targetNameLabel:SetText("") end
            ui.label:SetText(BuildDisplayText(cfg.textFormat, current, effectiveMax, percent, targetName))
        else
            if ui.targetNameLabel then ui.targetNameLabel:SetText("") end
            ui.label:SetText(BuildDisplayText(cfg.textFormat, current, effectiveMax, percent, nil))
        end
    else
        ui.label:SetText(BuildDisplayText(cfg.textFormat, current, effectiveMax, percent, nil))
    end

    if mechanicType == MECHANIC_HEALTH then
        local shieldVal = isDummyTarget and 20000 or GetShieldValue(unitTag)
        if shieldVal > 0 then
            local shieldPct = math.min(1, shieldVal / effectiveMax)
            local shieldW = math.max(1, math.floor(shieldPct * cfg.width))

            ui.shieldBar:ClearAnchors()
            if cfg.drainDirection == "To Center" then
                ui.shieldBar:SetAnchor(CENTER, ui.container, CENTER, 0, 0)
            elseif cfg.drainDirection == "Left to Right" then
                ui.shieldBar:SetAnchor(RIGHT, ui.container, RIGHT, 0, 0)
            else
                ui.shieldBar:SetAnchor(LEFT, ui.container, LEFT, 0, 0)
            end

            ui.shieldBar:SetDimensions(shieldW, cfg.height)
            ui.shieldBar:SetMinMax(0, 1)
            ui.shieldBar:SetValue(1)
            ui.shieldBar:SetHidden(false)
            ui.shieldLabel:SetText(string.format("[%s]", FormatNumber(shieldVal)))
        else
            ui.shieldBar:SetHidden(true)
            ui.shieldLabel:SetText("")
        end
    else
        ui.shieldBar:SetHidden(true)
        ui.shieldLabel:SetText("")
    end

    if cfg.warningEnabled and percent <= cfg.warningThreshold and percent > 0 then
        local alpha = GetDoublePulseAlpha(cfg.warningPulseSpeed or 120)
        ui.container:SetAlpha(alpha)
    else
        ui.container:SetAlpha(1.0)
    end
end

-- Rafraîchissement des auras
local function UpdateTargetAuras()
    local unitTag = "reticleover"
    local hasTarget = DoesUnitExist(unitTag) and not IsReticleHidden()
    local settings = TrueRessourceBars.savedVars.targetAuras

    if not hasTarget and not TrueRessourceBars.previewMode then
        TrueRessourceBars.targetBuffFrame:SetHidden(true)
        TrueRessourceBars.targetDebuffFrame:SetHidden(true)
        return
    end

    local showBuffs = (settings.buffsEnabled ~= "No")
    local showDebuffs = (settings.debuffsEnabled ~= "No")

    TrueRessourceBars.targetBuffFrame:SetHidden(not showBuffs)
    TrueRessourceBars.targetDebuffFrame:SetHidden(not showDebuffs)

    if not showBuffs and not showDebuffs then return end

    local currentTime = GetFrameTimeSeconds()
    local buffsList = {}
    local debuffsList = {}

    if TrueRessourceBars.previewMode then
        if showBuffs then
            for i, item in ipairs(dummyBuffData) do
                table.insert(buffsList, {
                    icon = item.icon,
                    timeLeft = item.time,
                    isPermanent = false,
                    stackCount = (i % 2 == 0) and 3 or 0,
                    name = "PreviewBuff" .. i
                })
            end
        end
        if showDebuffs then
            for i, item in ipairs(dummyDebuffData) do
                table.insert(debuffsList, {
                    icon = item.icon,
                    timeLeft = item.time,
                    isPermanent = false,
                    stackCount = 0,
                    name = "PreviewDebuff" .. i
                })
            end
        end
    else
        for i = 1, GetNumBuffs(unitTag) do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType = GetUnitBuffInfo(unitTag, i)

            if buffName and buffName ~= "" then
                local isPermanent = (timeStarted == timeEnding) or (timeEnding == 0)
                local timeLeft = isPermanent and 0 or (timeEnding - currentTime)

                local skipEffect = false
                if settings.hidePermanent and isPermanent then skipEffect = true end
                if settings.hideLongBuffs and not isPermanent and (timeLeft > (settings.longBuffThreshold * 60)) then skipEffect = true end

                if not skipEffect then
                    local effectEntry = {
                        name = buffName,
                        icon = iconFilename,
                        stackCount = stackCount,
                        isPermanent = isPermanent,
                        timeLeft = timeLeft
                    }

                    if effectType == BUFF_EFFECT_TYPE_DEBUFF and showDebuffs then
                        table.insert(debuffsList, effectEntry)
                    elseif effectType ~= BUFF_EFFECT_TYPE_DEBUFF and showBuffs then
                        table.insert(buffsList, effectEntry)
                    end
                end
            end
        end
    end

    table.sort(buffsList, CompareEffectsDescending)
    table.sort(debuffsList, CompareEffectsDescending)

    local buffCount = #buffsList
    for i, data in ipairs(buffsList) do
        local ctrl = GetOrCreateTargetAuraIcon("targetBuffs", i)
        ctrl:SetTexture(data.icon)
        ctrl.timerLabel:SetText(not data.isPermanent and FormatTime(data.timeLeft) or "")
        ctrl.stackLabel:SetText(data.stackCount > 1 and tostring(data.stackCount) or "")
    end

    local debuffCount = #debuffsList
    for i, data in ipairs(debuffsList) do
        local ctrl = GetOrCreateTargetAuraIcon("targetDebuffs", i)
        ctrl:SetTexture(data.icon)
        ctrl.timerLabel:SetText(not data.isPermanent and FormatTime(data.timeLeft) or "")
        ctrl.stackLabel:SetText(data.stackCount > 1 and tostring(data.stackCount) or "")
    end

    ApplyAuraAnchors("targetBuffs", buffCount, settings.spacing, settings.iconSize, settings.buffDir, settings.buffEnableGrid, settings.buffMaxPerRow, settings.buffRowDirection)
    ApplyAuraAnchors("targetDebuffs", debuffCount, settings.spacing, settings.iconSize, settings.debuffDir, settings.debuffEnableGrid, settings.debuffMaxPerRow, settings.debuffRowDirection)

    for i = buffCount + 1, #TrueRessourceBars.controls.targetBuffs do
        TrueRessourceBars.controls.targetBuffs[i]:SetHidden(true)
    end
    for i = debuffCount + 1, #TrueRessourceBars.controls.targetDebuffs do
        TrueRessourceBars.controls.targetDebuffs[i]:SetHidden(true)
    end
end

-- Neutralisation propre, officielle et conforme à la Sandbox Console
local function SuppressControl(ctrl)
    if not ctrl then return end
    ctrl:SetHidden(true)
    ctrl:SetAlpha(0)
    if not ctrl._hookedOnShow then
        ZO_PreHookHandler(ctrl, "OnShow", function(self)
            self:SetHidden(true)
            self:SetAlpha(0)
            return true
        end)
        ctrl._hookedOnShow = true
    end
end

local function CleanGamepadUI()
    -- 1. Récupération des fragments réels du joueur et de la cible
    local playerFrag = PLAYER_ATTRIBUTE_BARS_FRAGMENT or (PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.fragment)
    local targetFrag = (GAMEPAD_TARGET_UNIT_FRAME and GAMEPAD_TARGET_UNIT_FRAME.fragment) or TARGET_UNIT_FRAME_FRAGMENT

    local fragmentsToDrop = {
        playerFrag,
        targetFrag,
    }

    -- 2. Nettoyage sur l'ensemble des scènes de HUD Gamepad et Standard
    local scenesToClean = {
        HUD_SCENE,
        HUD_UI_SCENE,
        SCENE_MANAGER:GetScene("gamepad_hud_scene"),
        SCENE_MANAGER:GetScene("gamepad_hud_ui_scene"),
        SCENE_MANAGER:GetScene("hud"),
        SCENE_MANAGER:GetScene("hudui"),
    }

    for _, scene in ipairs(scenesToClean) do
        if scene then
            for _, frag in ipairs(fragmentsToDrop) do
                if frag and scene:HasFragment(frag) then
                    scene:RemoveFragment(frag)
                end
            end
        end
    end

    -- 3. Neutralisation du conteneur des barres de ressources joueur (Gamepad & Clavier)
    local playerGamepadContainer = ZO_PlayerAttributeContainerGamepad or (PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.control)
    if playerGamepadContainer then
        SuppressControl(playerGamepadContainer)
    end
    if ZO_PlayerAttribute then
        SuppressControl(ZO_PlayerAttribute)
    end

    -- 4. Neutralisation de la barre de cible Gamepad (Contrôle et Frame interne)
    if GAMEPAD_TARGET_UNIT_FRAME then
        if GAMEPAD_TARGET_UNIT_FRAME.control then
            SuppressControl(GAMEPAD_TARGET_UNIT_FRAME.control)
        end
        if GAMEPAD_TARGET_UNIT_FRAME.frame then
            SuppressControl(GAMEPAD_TARGET_UNIT_FRAME.frame)
        end
    end
    if ZO_GamepadTargetUnitFrame then
        SuppressControl(ZO_GamepadTargetUnitFrame)
    end

    -- 5. Neutralisation des auras natives de la cible Gamepad
    local targetAuraControls = {
        ZO_GamepadTargetUnitFrameBuffs,
        ZO_GamepadTargetUnitFrameDebuffs,
    }
    for _, ctrl in ipairs(targetAuraControls) do
        if ctrl then
            SuppressControl(ctrl)
        end
    end
end

-- Détection des menus, discussions et tableau des scores (BG Scoreboard)
local function ShouldHideAllUI()
    if TrueRessourceBars.previewMode then
        return false
    end

    if IsReticleHidden() then
        return true
    end

    if SCENE_MANAGER then
        if SCENE_MANAGER:IsShowing("battleground_scoreboard") then
            return true
        end
        if not SCENE_MANAGER:IsShowing("hud") and not SCENE_MANAGER:IsShowing("gamepad_hud") then
            return true
        end
    end

    return false
end

-- Événements des effets visuels (Détection instantanée des boucliers)
local function OnVisualAddedOrUpdated(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, value)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
        if unitTag == "player" or unitTag == "reticleover" then
            TrueRessourceBars.shieldCache[unitTag] = value or 0
        end
    end
end

local function OnVisualRemoved(eventCode, unitTag, unitAttributeVisual)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
        if unitTag == "player" or unitTag == "reticleover" then
            TrueRessourceBars.shieldCache[unitTag] = 0
        end
    end
end

local function OnReticleTargetChanged()
    TrueRessourceBars.shieldCache["reticleover"] = 0
end

-- Boucle générale de mise à jour
local function MasterUpdateLoop()
    local hideUI = ShouldHideAllUI()

    TrueRessourceBars.root:SetHidden(hideUI)
    TrueRessourceBars.targetBuffFrame:SetHidden(hideUI)
    TrueRessourceBars.targetDebuffFrame:SetHidden(hideUI)

    if hideUI then return end

    UpdateSingleBar("health", "player", MECHANIC_HEALTH)
    UpdateSingleBar("magicka", "player", MECHANIC_MAGICKA)
    UpdateSingleBar("stamina", "player", MECHANIC_STAMINA)

    if DoesUnitExist("reticleover") or TrueRessourceBars.previewMode then
        UpdateSingleBar("target", "reticleover", MECHANIC_HEALTH)
    else
        TrueRessourceBars.bars.target.container:SetHidden(true)
    end

    UpdateTargetAuras()
end

local function UpdateAuraPositions()
    local cfg = TrueRessourceBars.savedVars.targetAuras
    TrueRessourceBars.targetBuffFrame:ClearAnchors()
    TrueRessourceBars.targetBuffFrame:SetAnchor(CENTER, GuiRoot, CENTER, cfg.buffX, cfg.buffY)

    TrueRessourceBars.targetDebuffFrame:ClearAnchors()
    TrueRessourceBars.targetDebuffFrame:SetAnchor(CENTER, GuiRoot, CENTER, cfg.debuffX, cfg.debuffY)
end

-- Menu de configuration LibAddonMenu-2.0
local function BuildSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "True Ressource Bars",
        displayName = "|cff5900True Ressource Bars|r",
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = TrueRessourceBars.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel("TrueRessourceBarsOptions", panelData)

    local drainChoices = { "Right to Left", "Left to Right", "To Center" }
    local formatChoices = { "Current / Max (Percent)", "Current / Max", "Current (Percent)", "Current", "Percent" }

    local function CreateBarSubmenu(title, barKey, isHealth)
        local controls = {
            {
                type = "dropdown",
                name = "Active",
                tooltip = "Enable or disable this resource bar.",
                choices = { "Yes", "No" },
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].enabled or "Yes" end,
                setFunc = function(v)
                    TrueRessourceBars.savedVars.bars[barKey].enabled = v
                    ApplyBarVisuals(barKey)
                end,
            },
            {
                type = "slider",
                name = "Position X",
                min = -1500, max = 1500, step = 5,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].x end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].x = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider",
                name = "Position Y",
                min = -1000, max = 1000, step = 5,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].y end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].y = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider",
                name = "Width",
                min = 50, max = 1000, step = 2,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].width end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].width = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider",
                name = "Height",
                min = 10, max = 150, step = 2,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].height end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].height = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "colorpicker",
                name = "Bar Color",
                getFunc = function()
                    local r, g, b, a = GetRGBA(TrueRessourceBars.savedVars.bars[barKey].color, 1, 1, 1, 1)
                    return r, g, b, a
                end,
                setFunc = function(r, g, b, a)
                    TrueRessourceBars.savedVars.bars[barKey].color = { r = r, g = g, b = b, a = a }
                    ApplyBarVisuals(barKey)
                end,
            },
            {
                type = "dropdown",
                name = "Drain Direction",
                choices = drainChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].drainDirection end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].drainDirection = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "dropdown",
                name = "Text Format",
                choices = formatChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].textFormat end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].textFormat = v end,
            },
            {
                type = "dropdown",
                name = "Font Family",
                choices = fontChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].font end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].font = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider",
                name = "Font Size",
                min = 10, max = 40, step = 1,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].fontSize end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].fontSize = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "colorpicker",
                name = "Font Color",
                getFunc = function()
                    local r, g, b, a = GetRGBA(TrueRessourceBars.savedVars.bars[barKey].textColor, 1, 1, 1, 1)
                    return r, g, b, a
                end,
                setFunc = function(r, g, b, a)
                    TrueRessourceBars.savedVars.bars[barKey].textColor = { r = r, g = g, b = b, a = a }
                    ApplyBarVisuals(barKey)
                end,
            },
            {
                type = "header",
                name = "Warning Settings (Double Pulse)",
            },
            {
                type = "checkbox",
                name = "Enable Warning Mode (Double Pulse)",
                tooltip = "Makes the bar pulse twice in a heartbeat rhythm whenever health/resource drops below the set threshold.",
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].warningEnabled end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].warningEnabled = v end,
            },
            {
                type = "slider",
                name = "Warning Threshold (%)",
                min = 1, max = 85, step = 1,
                disabled = function() return not TrueRessourceBars.savedVars.bars[barKey].warningEnabled end,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].warningThreshold end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].warningThreshold = v end,
            },
            {
                type = "slider",
                name = "Pulse Speed (ms)",
                tooltip = "Adjusts the tempo of each pulsation in the sequence (smaller values mean faster pulses).",
                min = 50, max = 300, step = 10,
                disabled = function() return not TrueRessourceBars.savedVars.bars[barKey].warningEnabled end,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].warningPulseSpeed or 120 end,
                setFunc = function(v)
                    TrueRessourceBars.savedVars.bars[barKey].warningPulseSpeed = v
                    ApplyBarVisuals(barKey)
                end,
            }
        }

        if barKey == "target" then
            table.insert(controls, {
                type = "header",
                name = "Enemy Target Name Display",
            })
            table.insert(controls, {
                type = "dropdown",
                name = "Target Name Position",
                tooltip = "Choose where to display the target enemy name relative to the center of the bar.",
                choices = { "Above", "Below", "Inside Bar", "Hidden" },
                getFunc = function() return TrueRessourceBars.savedVars.bars.target.targetNamePosition or "Above" end,
                setFunc = function(v)
                    TrueRessourceBars.savedVars.bars.target.targetNamePosition = v
                    ApplyBarVisuals("target")
                end,
            })
            table.insert(controls, {
                type = "slider",
                name = "Target Name Font Size",
                min = 10, max = 36, step = 1,
                disabled = function()
                    local pos = TrueRessourceBars.savedVars.bars.target.targetNamePosition or "Above"
                    return pos == "Hidden" or pos == "Inside Bar"
                end,
                getFunc = function() return TrueRessourceBars.savedVars.bars.target.targetNameFontSize or 18 end,
                setFunc = function(v)
                    TrueRessourceBars.savedVars.bars.target.targetNameFontSize = v
                    ApplyBarVisuals("target")
                end,
            })
        end

        if isHealth then
            table.insert(controls, {
                type = "header",
                name = "Shields Configuration",
            })
            table.insert(controls, {
                type = "dropdown",
                name = "Shield Value Position",
                tooltip = "Choose which corner of the bar will display the shield numerical value.",
                choices = cornerPositionChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].shieldValuePos or "Top Right" end,
                setFunc = function(v)
                    TrueRessourceBars.savedVars.bars[barKey].shieldValuePos = v
                    ApplyBarVisuals(barKey)
                end,
            })
            table.insert(controls, {
                type = "colorpicker",
                name = "Shield Overlay Color",
                getFunc = function()
                    local r, g, b, a = GetRGBA(TrueRessourceBars.savedVars.bars[barKey].shieldColor, 0.75, 0.25, 0.95, 0.75)
                    return r, g, b, a
                end,
                setFunc = function(r, g, b, a)
                    TrueRessourceBars.savedVars.bars[barKey].shieldColor = { r = r, g = g, b = b, a = a }
                    ApplyBarVisuals(barKey)
                end,
            })
        end

        return {
            type = "submenu",
            name = title,
            controls = controls
        }
    end

    local options = {
        {
            type = "checkbox",
            name = "|c00FF00Preview Mode (Test Target & Bars)|r",
            tooltip = "Shows dummy target bars and dummy auras to adjust positions easily.",
            getFunc = function() return TrueRessourceBars.previewMode end,
            setFunc = function(v) TrueRessourceBars.previewMode = v end,
        },
        CreateBarSubmenu("Player Health Bar", "health", true),
        CreateBarSubmenu("Player Magicka Bar", "magicka", false),
        CreateBarSubmenu("Player Stamina Bar", "stamina", false),
        CreateBarSubmenu("Target Health Bar", "target", true),

        -- Sous-menu : Filtres des Auras
        {
            type = "submenu",
            name = "Target Auras Filters",
            tooltip = "Filter out permanent effects or long duration buffs on target.",
            controls = {
                {
                    type = "checkbox",
                    name = "Hide Permanent Effects",
                    tooltip = "Hides passives, mundus stones, and infinite buffs.",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.hidePermanent end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.hidePermanent = value end,
                },
                {
                    type = "checkbox",
                    name = "Hide Long Duration Effects",
                    tooltip = "Hides buffs that have a long timer (e.g. food).",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.hideLongBuffs end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.hideLongBuffs = value end,
                },
                {
                    type = "slider",
                    name = "Long Duration Threshold (Minutes)",
                    tooltip = "Any effect longer than this will be hidden.",
                    min = 1, max = 120, step = 1,
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras.hideLongBuffs end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.longBuffThreshold end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.longBuffThreshold = value end,
                },
            }
        },

        -- Sous-menu : Configuration des Buffs de la Cible
        {
            type = "submenu",
            name = "Target Buffs Bar Configuration",
            tooltip = "Positions, orientation, and multiple row/column settings for target buffs.",
            controls = {
                {
                    type = "dropdown",
                    name = "Active",
                    tooltip = "Enable or disable the target buffs bar.",
                    choices = { "Yes", "No" },
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffsEnabled or "Yes" end,
                    setFunc = function(v)
                        TrueRessourceBars.savedVars.targetAuras.buffsEnabled = v
                        if v == "No" then
                            TrueRessourceBars.targetBuffFrame:SetHidden(true)
                        end
                    end,
                },
                {
                    type = "slider",
                    name = "Buffs Position (X)",
                    min = -1500, max = 1500, step = 5,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffX end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.buffX = v; UpdateAuraPositions() end,
                },
                {
                    type = "slider",
                    name = "Buffs Position (Y)",
                    min = -1000, max = 1000, step = 5,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffY end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.buffY = v; UpdateAuraPositions() end,
                },
                {
                    type = "dropdown",
                    name = "Buffs Orientation",
                    choices = auraOrientationChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffDir end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.buffDir = value end,
                },
                {
                    type = "checkbox",
                    name = "Enable Multiple Rows / Columns",
                    tooltip = "Enable this to allow buffs to wrap onto new rows/columns once the limit per line is reached.",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffEnableGrid end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.buffEnableGrid = value end,
                },
                {
                    type = "slider",
                    name = "Max Buffs Per Line",
                    tooltip = "Maximum number of buffs displayed per line before creating a new row/column.",
                    min = 1, max = 30, step = 1,
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras.buffEnableGrid end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffMaxPerRow end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.buffMaxPerRow = value end,
                },
                {
                    type = "dropdown",
                    name = "New Row Direction",
                    tooltip = "Controls if new rows appear above or below the initial line.",
                    choices = {"Below", "Above"},
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras.buffEnableGrid end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.buffRowDirection end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.buffRowDirection = value end,
                },
            }
        },

        -- Sous-menu : Configuration des Débuffs de la Cible
        {
            type = "submenu",
            name = "Target Debuffs Bar Configuration",
            tooltip = "Positions, orientation, and multiple row/column settings for target debuffs.",
            controls = {
                {
                    type = "dropdown",
                    name = "Active",
                    tooltip = "Enable or disable the target debuffs bar.",
                    choices = { "Yes", "No" },
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffsEnabled or "Yes" end,
                    setFunc = function(v)
                        TrueRessourceBars.savedVars.targetAuras.debuffsEnabled = v
                        if v == "No" then
                            TrueRessourceBars.targetDebuffFrame:SetHidden(true)
                        end
                    end,
                },
                {
                    type = "slider",
                    name = "Debuffs Position (X)",
                    min = -1500, max = 1500, step = 5,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffX end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.debuffX = v; UpdateAuraPositions() end,
                },
                {
                    type = "slider",
                    name = "Debuffs Position (Y)",
                    min = -1000, max = 1000, step = 5,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffY end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.debuffY = v; UpdateAuraPositions() end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Orientation",
                    choices = auraOrientationChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffDir end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.debuffDir = value end,
                },
                {
                    type = "checkbox",
                    name = "Enable Multiple Rows / Columns",
                    tooltip = "Enable this to allow debuffs to wrap onto new rows/columns once the limit per line is reached.",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffEnableGrid end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.debuffEnableGrid = value end,
                },
                {
                    type = "slider",
                    name = "Max Debuffs Per Line",
                    tooltip = "Maximum number of debuffs displayed per line before creating a new row/column.",
                    min = 1, max = 30, step = 1,
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras.debuffEnableGrid end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffMaxPerRow end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.debuffMaxPerRow = value end,
                },
                {
                    type = "dropdown",
                    name = "New Row Direction",
                    tooltip = "Controls if new rows appear above or below the initial line.",
                    choices = {"Below", "Above"},
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras.debuffEnableGrid end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.debuffRowDirection end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.debuffRowDirection = value end,
                },
            }
        },

        -- Sous-menu : Apparence & Lisibilité
        {
            type = "submenu",
            name = "Target Auras Appearance & Sizing",
            tooltip = "Adjust sizes, spacing, and typography readability for target auras.",
            controls = {
                {
                    type = "slider",
                    name = "Icons Size",
                    min = 20, max = 100, step = 2,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.iconSize end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.iconSize = value end,
                },
                {
                    type = "slider",
                    name = "Spacing",
                    min = 0, max = 50, step = 1,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.spacing end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.spacing = value end,
                },
                {
                    type = "dropdown",
                    name = "Font Family",
                    choices = fontChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.fontStyle end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.fontStyle = value end,
                },
                {
                    type = "dropdown",
                    name = "Font Outline / Shadow Style",
                    tooltip = "Choose an outline or shadow style to maximize text readability over any background.",
                    choices = availableStyleChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.fontOutlineStyle end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.fontOutlineStyle = value end,
                },
            }
        },

        -- Sous-menu : Minuteurs des Auras (Timers)
        {
            type = "submenu",
            name = "Target Timers Display (Duration)",
            tooltip = "Position, size, and color of duration labels on target auras.",
            controls = {
                {
                    type = "dropdown",
                    name = "Buffs Timer Position",
                    choices = timerPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.timerBuffPos end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.timerBuffPos = value end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Timer Position",
                    choices = timerPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.timerDebuffPos end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.timerDebuffPos = value end,
                },
                {
                    type = "slider",
                    name = "Timer Text Size",
                    min = 10, max = 40, step = 1,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.timerSize end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.timerSize = value end,
                },
                {
                    type = "colorpicker",
                    name = "Timer Color",
                    getFunc = function()
                        local r, g, b, a = GetRGBA(TrueRessourceBars.savedVars.targetAuras.timerColor, 1, 1, 1, 1)
                        return r, g, b, a
                    end,
                    setFunc = function(r, g, b, a)
                        TrueRessourceBars.savedVars.targetAuras.timerColor = { r = r, g = g, b = b, a = a }
                    end,
                },
            }
        },

        -- Sous-menu : Compteurs de charges des Auras (Stacks)
        {
            type = "submenu",
            name = "Target Stacks Display (Charges)",
            tooltip = "Position, size, and color of stack counters on target auras.",
            controls = {
                {
                    type = "dropdown",
                    name = "Buffs Stack Position",
                    choices = stackPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.stackBuffPos end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.stackBuffPos = value end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Stack Position",
                    choices = stackPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.stackDebuffPos end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.stackDebuffPos = value end,
                },
                {
                    type = "slider",
                    name = "Stack Text Size",
                    min = 10, max = 40, step = 1,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.stackSize end,
                    setFunc = function(value) TrueRessourceBars.savedVars.targetAuras.stackSize = value end,
                },
                {
                    type = "colorpicker",
                    name = "Stack Color",
                    getFunc = function()
                        local r, g, b, a = GetRGBA(TrueRessourceBars.savedVars.targetAuras.stackColor, 1, 0.8, 0, 1)
                        return r, g, b, a
                    end,
                    setFunc = function(r, g, b, a)
                        TrueRessourceBars.savedVars.targetAuras.stackColor = { r = r, g = g, b = b, a = a }
                    end,
                },
            }
        }
    }

    LAM:RegisterOptionControls("TrueRessourceBarsOptions", options)
end

-- Réactivation et masquage lors du changement de zone
local function OnPlayerActivated()
    CleanGamepadUI()
end

-- Chargement de l'addon
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= TrueRessourceBars.name then return end
    EVENT_MANAGER:UnregisterForEvent(TrueRessourceBars.name, EVENT_ADD_ON_LOADED)

    -- Maintien strict de la version 9 des SavedVariables
    TrueRessourceBars.savedVars = ZO_SavedVars:NewAccountWide("TrueRessourceBarsSV", 9, nil, defaults)

    local wm = WINDOW_MANAGER
    TrueRessourceBars.root = wm:CreateTopLevelWindow("TrueRessourceBarsRoot")
    TrueRessourceBars.root:SetAnchorFill()

    -- Construction des 4 barres de ressource
    TrueRessourceBars.bars = {
        health = CreateBarControl("health", TrueRessourceBars.savedVars.bars.health),
        magicka = CreateBarControl("magicka", TrueRessourceBars.savedVars.bars.magicka),
        stamina = CreateBarControl("stamina", TrueRessourceBars.savedVars.bars.stamina),
        target = CreateBarControl("target", TrueRessourceBars.savedVars.bars.target)
    }

    TrueRessourceBars.targetBuffFrame = wm:CreateTopLevelWindow(TrueRessourceBars.name .. "TargetBuffFrame")
    TrueRessourceBars.targetDebuffFrame = wm:CreateTopLevelWindow(TrueRessourceBars.name .. "TargetDebuffFrame")
    TrueRessourceBars.targetBuffFrame:SetDrawTier(DT_HIGH)
    TrueRessourceBars.targetDebuffFrame:SetDrawTier(DT_HIGH)

    for key in pairs(TrueRessourceBars.bars) do
        ApplyBarVisuals(key)
    end
    UpdateAuraPositions()

    CleanGamepadUI()
    BuildSettingsMenu()

    -- Enregistrement des événements de détection des boucliers et cible
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnVisualAddedOrUpdated)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualAddedOrUpdated)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualRemoved)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)

    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForUpdate(TrueRessourceBars.name .. "Loop", TrueRessourceBars.updateInterval, MasterUpdateLoop)
end

EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)