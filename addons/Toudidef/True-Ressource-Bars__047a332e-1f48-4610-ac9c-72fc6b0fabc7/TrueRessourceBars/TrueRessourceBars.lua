-- Initialisation de l'addon
local TrueRessourceBars = {
    name = "TrueRessourceBars",
    version = "3.5",
    updateInterval = 50,
    previewMode = false,
    auraStyleVersion = 1,
    targetName = "",
    controls = {
        targetBuffs = {},
        targetDebuffs = {}
    },
    shieldSlots = {
        player = {},
        reticleover = {}
    },
    shieldTotals = {
        player = 0,
        reticleover = 0
    }
}

-- Raccourcis locaux pour limiter les recherches globales dans la boucle
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local string_format = string.format

-- Constantes des attributs de combat ESO
local MECHANIC_HEALTH  = COMBAT_MECHANIC_FLAGS_HEALTH or 1
local MECHANIC_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA or 2
local MECHANIC_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA or 4
local BORDER_SIZE = 3

-- Tables réutilisables (zéro allocation en régime permanent)
local suppressedControls = {}
local reusableBuffList = {}
local reusableDebuffList = {}
local auraEntryPool = {}
local timeStrCache = { [0] = "" }
local stackStrCache = {}

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
    "Gamepad Medium", "Gamepad Bold", "Medium (Default)", "Bold", "Antique", "Stone Tablet", "Chat Font"
}

-- Styles d'ombrage et de contour
local styleMapping = {
    ["Outline"]           = "outline",
    ["Thick Soft Shadow"] = "soft-shadow-thick",
    ["Thin Soft Shadow"]  = "soft-shadow-thin",
    ["Drop Shadow"]       = "shadow",
    ["None"]              = ""
}
local availableStyleChoices = { "Outline", "Thick Soft Shadow", "Thin Soft Shadow", "Drop Shadow", "None" }

-- Emplacements dans les coins
local cornerPositionMapping = {
    ["Top Left"]     = { point = TOPLEFT, relPoint = TOPLEFT, x = 6, y = 2 },
    ["Top Right"]    = { point = TOPRIGHT, relPoint = TOPRIGHT, x = -6, y = 2 },
    ["Bottom Left"]  = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 6, y = -2 },
    ["Bottom Right"] = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = -6, y = -2 },
    ["Left"]         = { point = LEFT, relPoint = LEFT, x = 6, y = 0 },
    ["Right"]        = { point = RIGHT, relPoint = RIGHT, x = -6, y = 0 },
}
local cornerPositionChoices = { "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Left", "Right" }

-- Positions pour le TEMPS des auras
local timerPositionMapping = {
    ["Top Left"]     = { point = TOPLEFT, relPoint = TOPLEFT, x = 0, y = 0 },
    ["Top Right"]    = { point = TOPRIGHT, relPoint = TOPRIGHT, x = 0, y = 0 },
    ["Bottom Left"]  = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 0, y = 0 },
    ["Bottom Right"] = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = 0, y = 0 },
    ["Center"]       = { point = CENTER, relPoint = CENTER, x = 0, y = 0 },
    ["Low Center"]   = { point = BOTTOM, relPoint = BOTTOM, x = 0, y = -3 },
    ["Below Center"] = { point = TOP, relPoint = BOTTOM, x = 0, y = 2 },
    ["Above Center"] = { point = BOTTOM, relPoint = TOP, x = 0, y = -2 },
    ["Left Center"]  = { point = RIGHT, relPoint = LEFT, x = -4, y = 0 },
    ["Right Center"] = { point = LEFT, relPoint = RIGHT, x = 4, y = 0 }
}
local timerPositionChoices = {
    "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center",
    "Low Center", "Below Center", "Above Center", "Left Center", "Right Center"
}

-- Positions pour les STACKS des auras
local stackPositionMapping = {
    ["Top Left"]     = { point = TOPLEFT, relPoint = TOPLEFT, x = 2, y = 2 },
    ["Top Right"]    = { point = TOPRIGHT, relPoint = TOPRIGHT, x = -2, y = 2 },
    ["Bottom Left"]  = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 2, y = -2 },
    ["Bottom Right"] = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = -2, y = -2 },
    ["Center"]       = { point = CENTER, relPoint = CENTER, x = 0, y = 0 }
}
local stackPositionChoices = { "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center" }

local auraOrientationChoices = {
    "Horizontal (Left to Right)", "Horizontal (Right to Left)", "Horizontal (Centered)",
    "Vertical (Top to Bottom)", "Vertical (Bottom to Top)", "Vertical (Centered)"
}

-- Valeurs par défaut sauvegardées
local defaults = {
    bars = {
        health = {
            enabled = "Yes", x = 0, y = 340, width = 360, height = 28,
            color = { r = 0.85, g = 0.15, b = 0.15, a = 1 },
            shieldColor = { r = 0.75, g = 0.25, b = 0.95, a = 0.75 },
            shieldValuePos = "Top Right",
            font = "Gamepad Bold", fontSize = 18, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "Right to Left",
            warningEnabled = true, warningThreshold = 35, warningPulseSpeed = 120,
        },
        magicka = {
            enabled = "Yes", x = -220, y = 380, width = 260, height = 24,
            color = { r = 0.15, g = 0.45, b = 0.95, a = 1 },
            font = "Gamepad Bold", fontSize = 16, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "Right to Left",
            warningEnabled = false, warningThreshold = 25, warningPulseSpeed = 120,
        },
        stamina = {
            enabled = "Yes", x = 220, y = 380, width = 260, height = 24,
            color = { r = 0.15, g = 0.85, b = 0.25, a = 1 },
            font = "Gamepad Bold", fontSize = 16, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "Left to Right",
            warningEnabled = false, warningThreshold = 25, warningPulseSpeed = 120,
        },
        target = {
            enabled = "Yes", x = 0, y = -340, width = 460, height = 32,
            color = { r = 0.85, g = 0.15, b = 0.15, a = 1 },
            shieldColor = { r = 0.75, g = 0.25, b = 0.95, a = 0.75 },
            shieldValuePos = "Top Right",
            targetNamePosition = "Above", targetNameFontSize = 18,
            font = "Gamepad Bold", fontSize = 20, fontStyle = "Outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            textFormat = "Current / Max (Percent)",
            drainDirection = "To Center",
            warningEnabled = false, warningThreshold = 25, warningPulseSpeed = 120,
        }
    },
    targetAuras = {
        buffsEnabled = "Yes", debuffsEnabled = "Yes",
        buffX = 5, buffY = -295, debuffX = 5, debuffY = -385,
        buffDir = "Horizontal (Centered)", debuffDir = "Horizontal (Centered)",
        buffEnableGrid = false, buffMaxPerRow = 8, buffRowDirection = "Below",
        debuffEnableGrid = false, debuffMaxPerRow = 8, debuffRowDirection = "Above",
        iconSize = 38, spacing = 4,
        fontStyle = "Gamepad Medium", fontOutlineStyle = "Outline",
        timerBuffPos = "Low Center", timerDebuffPos = "Low Center",
        timerSize = 16, timerColor = { r = 1, g = 1, b = 1, a = 1 },
        stackBuffPos = "Top Right", stackDebuffPos = "Top Right",
        stackSize = 16, stackColor = { r = 1, g = 0.8, b = 0, a = 1 },
        hidePermanent = false, hideLongBuffs = false, longBuffThreshold = 60
    }
}

-- Échantillons factices pour le mode aperçu
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

local function SetHiddenIfChanged(ctrl, hidden)
    if ctrl and ctrl:IsControlHidden() ~= hidden then
        ctrl:SetHidden(hidden)
    end
end

local function InvalidateAuraStyles()
    TrueRessourceBars.auraStyleVersion = TrueRessourceBars.auraStyleVersion + 1
end

local function GetRGBA(c, defR, defG, defB, defA)
    if type(c) ~= "table" then
        return defR or 1, defG or 1, defB or 1, defA or 1
    end
    return c.r or c[1] or defR or 1, c.g or c[2] or defG or 1, c.b or c[3] or defB or 1, c.a or c[4] or defA or 1
end

local function SetBarSolidColor(bar, r, g, b, a)
    if not bar then return end
    bar:SetColor(r, g, b, a)
    bar:SetGradientColors(r, g, b, a, r, g, b, a)
end

local function FormatNumber(value)
    if value >= 1000000 then
        return string_format("%.1fm", value * 0.000001)
    elseif value >= 1000 then
        return string_format("%.1fk", value * 0.001)
    end
    return tostring(math_floor(value))
end

-- Formatage du temps en entiers (secondes, minutes ou heures) avec cache borné
local function GetFormattedTimeAndKey(seconds)
    if seconds <= 0 then return 0, "" end
    local key
    if seconds >= 3600 then
        local h = math_floor(seconds / 3600)
        key = 200000 + h
        if key > 200100 then
            return key, string_format("%dh", h)
        end
        if not timeStrCache[key] then
            timeStrCache[key] = string_format("%dh", h)
        end
    elseif seconds >= 60 then
        local m = math_floor(seconds / 60)
        key = 100000 + m
        if not timeStrCache[key] then
            timeStrCache[key] = string_format("%dm", m)
        end
    else
        -- Arrondi à la seconde supérieure pour éviter d'afficher "0s" avant expiration
        key = math_ceil(seconds)
        if not timeStrCache[key] then
            timeStrCache[key] = string_format("%ds", key)
        end
    end
    return key, timeStrCache[key]
end

local function GetFormattedStack(stackVal)
    if stackVal <= 1 then return "" end
    if stackVal <= 100 then
        local str = stackStrCache[stackVal]
        if not str then
            str = tostring(stackVal)
            stackStrCache[stackVal] = str
        end
        return str
    end
    return tostring(stackVal)
end

-- Gestion des slots de bouclier par unité (sans allocation récurrente)
local function SetUnitShieldSlot(unitTag, statType, attributeType, powerType, value)
    local slots = TrueRessourceBars.shieldSlots[unitTag]
    if not slots then return end

    local foundSlot, freeSlot
    for i = 1, #slots do
        local s = slots[i]
        if s.stat == statType and s.attr == attributeType and s.power == powerType then
            foundSlot = s
            break
        elseif s.val == 0 and not freeSlot then
            freeSlot = s
        end
    end

    local cleanVal = (value and value > 0) and value or 0
    if foundSlot then
        foundSlot.val = cleanVal
    elseif cleanVal > 0 then
        if freeSlot then
            freeSlot.stat, freeSlot.attr, freeSlot.power, freeSlot.val = statType, attributeType, powerType, cleanVal
        else
            slots[#slots + 1] = { stat = statType, attr = attributeType, power = powerType, val = cleanVal }
        end
    end

    local total = 0
    for i = 1, #slots do
        total = total + slots[i].val
    end
    TrueRessourceBars.shieldTotals[unitTag] = total
end

-- Resynchronisation directe via l'API lors d'un changement de cible / zone
local function RefreshUnitShieldCache(unitTag)
    local slots = TrueRessourceBars.shieldSlots[unitTag]
    if not slots then return end

    for i = 1, #slots do slots[i].val = 0 end
    TrueRessourceBars.shieldTotals[unitTag] = 0

    if not DoesUnitExist(unitTag) then return end

    local statMit = STAT_MITIGATION or 2
    local statDef = STAT_DEFENSE or 1
    local healthPower = POWERTYPE_HEALTH or MECHANIC_HEALTH

    local val = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, statMit, ATTRIBUTE_HEALTH, healthPower)
    if val and val > 0 then
        SetUnitShieldSlot(unitTag, statMit, ATTRIBUTE_HEALTH, healthPower, val)
        return
    end
    if healthPower ~= MECHANIC_HEALTH then
        val = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, statMit, ATTRIBUTE_HEALTH, MECHANIC_HEALTH)
        if val and val > 0 then
            SetUnitShieldSlot(unitTag, statMit, ATTRIBUTE_HEALTH, MECHANIC_HEALTH, val)
            return
        end
    end
    val = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, statDef, ATTRIBUTE_HEALTH, healthPower)
    if val and val > 0 then
        SetUnitShieldSlot(unitTag, statDef, ATTRIBUTE_HEALTH, healthPower, val)
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

-- Calcul du double-pulsation
local function GetDoublePulseAlpha(pulseSpeed)
    local p = math_max(40, pulseSpeed or 120)
    local gap = math_floor(p * 0.7)
    local pause = math_floor(p * 2.4)
    local totalCycle = (4 * p) + gap + pause
    local t = GetFrameTimeMilliseconds() % totalCycle

    if t < p then
        return 1.0 - (0.85 * (t / p))
    elseif t < (2 * p) then
        return 0.15 + (0.85 * ((t - p) / p))
    elseif t < (2 * p + gap) then
        return 1.0
    elseif t < (3 * p + gap) then
        return 1.0 - (0.85 * ((t - (2 * p + gap)) / p))
    elseif t < (4 * p + gap) then
        return 0.15 + (0.85 * ((t - (3 * p + gap)) / p))
    end
    return 1.0
end

-- Création d'une barre de ressource
local function CreateBarControl(barKey, config)
    local wm = WINDOW_MANAGER
    local name = TrueRessourceBars.name .. "_" .. barKey
    local halfWidth = config.width * 0.5

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

-- Application des styles visuels d'une barre (appelée uniquement sur modification)
local function ApplyBarVisuals(barKey)
    local ui = TrueRessourceBars.bars[barKey]
    local cfg = TrueRessourceBars.savedVars.bars[barKey]
    if not ui or not cfg then return end

    -- Invalidation des caches de la barre pour forcer le rafraîchissement
    ui.lastMainVal, ui.lastGhostVal, ui.lastEffectiveMax = nil, nil, nil
    ui.lastCurrent, ui.lastTextMax, ui.lastTargetName = nil, nil, nil
    ui.lastShieldVal, ui.lastShieldMax, ui.lastShieldW, ui.lastShieldDir = nil, nil, nil, nil
    ui.lastAlpha = 1.0

    if cfg.enabled == "No" then
        SetHiddenIfChanged(ui.container, true)
        return
    end

    ui.container:ClearAnchors()
    ui.container:SetAnchor(CENTER, GuiRoot, CENTER, cfg.x, cfg.y)
    ui.container:SetDimensions(cfg.width, cfg.height)
    ui.container:SetAlpha(1.0)

    local r, g, b, a = GetRGBA(cfg.color, 1, 1, 1, 1)
    SetBarSolidColor(ui.barNormal, r, g, b, a)
    SetBarSolidColor(ui.barCenterL, r, g, b, a)
    SetBarSolidColor(ui.barCenterR, r, g, b, a)

    local lr, lg, lb = math_min(1, r + 0.35), math_min(1, g + 0.35), math_min(1, b + 0.35)
    SetBarSolidColor(ui.lossBarNormal, lr, lg, lb, 0.65)
    SetBarSolidColor(ui.lossCenterL, lr, lg, lb, 0.65)
    SetBarSolidColor(ui.lossCenterR, lr, lg, lb, 0.65)

    if cfg.shieldColor then
        local sr, sg, sb, sa = GetRGBA(cfg.shieldColor, 0.75, 0.25, 0.95, 0.75)
        SetBarSolidColor(ui.shieldBar, sr, sg, sb, sa)
    end

    local isCenter = (cfg.drainDirection == "To Center")
    ui.barNormal:SetHidden(isCenter)
    ui.lossBarNormal:SetHidden(isCenter)
    ui.barCenterL:SetHidden(not isCenter)
    ui.barCenterR:SetHidden(not isCenter)
    ui.lossCenterL:SetHidden(not isCenter)
    ui.lossCenterR:SetHidden(not isCenter)

    if isCenter then
        local halfW = cfg.width * 0.5
        ui.barCenterL:SetDimensions(halfW, cfg.height)
        ui.barCenterR:SetDimensions(halfW, cfg.height)
        ui.lossCenterL:SetDimensions(halfW, cfg.height)
        ui.lossCenterR:SetDimensions(halfW, cfg.height)
    else
        local align = (cfg.drainDirection == "Left to Right") and BAR_ALIGNMENT_REVERSE or BAR_ALIGNMENT_NORMAL
        ui.barNormal:SetBarAlignment(align)
        ui.lossBarNormal:SetBarAlignment(align)
    end

    local fontPath = fontMapping[cfg.font] or "$(GAMEPAD_BOLD_FONT)"
    local outline = styleMapping[cfg.fontStyle] or "outline"
    local fontFmt = (outline ~= "") and string_format("%s|%d|%s", fontPath, cfg.fontSize or 18, outline)
                                    or string_format("%s|%d", fontPath, cfg.fontSize or 18)
    ui.label:SetFont(fontFmt)

    local tr, tg, tb, ta = GetRGBA(cfg.textColor, 1, 1, 1, 1)
    ui.label:SetColor(tr, tg, tb, ta)

    local posData = cornerPositionMapping[cfg.shieldValuePos or "Top Right"] or cornerPositionMapping["Top Right"]
    ui.shieldLabel:ClearAnchors()
    ui.shieldLabel:SetAnchor(posData.point, ui.container, posData.relPoint, posData.x, posData.y)
    ui.shieldLabel:SetFont(string_format("%s|%d|%s", fontPath, math_max(10, (cfg.fontSize or 18) - 3), outline))
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
        ui.targetNameLabel:SetFont(string_format("%s|%d|%s", fontPath, cfg.targetNameFontSize or 18, outline))
        ui.targetNameLabel:SetColor(tr, tg, tb, ta)
    end
end

-- Création ou réutilisation d'une icône d'aura (style appliqué uniquement si version modifiée)
local function GetOrCreateTargetAuraIcon(poolType, index)
    local pool = TrueRessourceBars.controls[poolType]
    local ctrl = pool[index]

    if not ctrl then
        local parentFrame = (poolType == "targetBuffs") and TrueRessourceBars.targetBuffFrame or TrueRessourceBars.targetDebuffFrame
        ctrl = WINDOW_MANAGER:CreateControl(TrueRessourceBars.name .. poolType .. index, parentFrame, CT_TEXTURE)

        local timerLabel = WINDOW_MANAGER:CreateControl(TrueRessourceBars.name .. poolType .. "Timer" .. index, ctrl, CT_LABEL)
        timerLabel:SetDrawLayer(DL_OVERLAY)
        timerLabel:SetDrawTier(DT_HIGH)
        ctrl.timerLabel = timerLabel

        local stackLabel = WINDOW_MANAGER:CreateControl(TrueRessourceBars.name .. poolType .. "Stack" .. index, ctrl, CT_LABEL)
        stackLabel:SetDrawLayer(DL_OVERLAY)
        stackLabel:SetDrawTier(DT_HIGH)
        ctrl.stackLabel = stackLabel

        ctrl.appliedStyleVersion = 0
        pool[index] = ctrl
    end

    if ctrl.appliedStyleVersion ~= TrueRessourceBars.auraStyleVersion then
        local settings = TrueRessourceBars.savedVars.targetAuras
        local selectedFont = fontMapping[settings.fontStyle] or "$(GAMEPAD_MEDIUM_FONT)"
        local styleDesc = styleMapping[settings.fontOutlineStyle] or "outline"

        ctrl:SetDimensions(settings.iconSize, settings.iconSize)

        local tFont = (styleDesc ~= "") and string_format("%s|%d|%s", selectedFont, settings.timerSize, styleDesc)
                                         or string_format("%s|%d", selectedFont, settings.timerSize)
        ctrl.timerLabel:SetFont(tFont)
        local tr, tg, tb, ta = GetRGBA(settings.timerColor, 1, 1, 1, 1)
        ctrl.timerLabel:SetColor(tr, tg, tb, ta)
        ctrl.timerLabel:ClearAnchors()
        local tPos = timerPositionMapping[(poolType == "targetBuffs") and settings.timerBuffPos or settings.timerDebuffPos]
        if tPos then
            ctrl.timerLabel:SetAnchor(tPos.point, ctrl, tPos.relPoint, tPos.x, tPos.y)
        end

        local sFont = (styleDesc ~= "") and string_format("%s|%d|%s", selectedFont, settings.stackSize, styleDesc)
                                         or string_format("%s|%d", selectedFont, settings.stackSize)
        ctrl.stackLabel:SetFont(sFont)
        local sr, sg, sb, sa = GetRGBA(settings.stackColor, 1, 0.8, 0, 1)
        ctrl.stackLabel:SetColor(sr, sg, sb, sa)
        ctrl.stackLabel:ClearAnchors()
        local sPos = stackPositionMapping[(poolType == "targetBuffs") and settings.stackBuffPos or settings.stackDebuffPos]
        if sPos then
            ctrl.stackLabel:SetAnchor(sPos.point, ctrl, sPos.relPoint, sPos.x, sPos.y)
        end

        ctrl.appliedStyleVersion = TrueRessourceBars.auraStyleVersion
    end

    SetHiddenIfChanged(ctrl, false)
    return ctrl
end

-- Calcul des ancrages d'auras avec diffing
local function ApplyAuraAnchors(poolType, count, spacing, iconSize, direction, enableGrid, maxPerRow, vDir)
    if count == 0 then return end
    local pool = TrueRessourceBars.controls[poolType]
    local parent = (poolType == "targetBuffs") and TrueRessourceBars.targetBuffFrame or TrueRessourceBars.targetDebuffFrame
    if direction == "Horizontal" then direction = "Horizontal (Left to Right)" end

    local limit = enableGrid and math_max(1, maxPerRow or 1) or count
    local step = iconSize + spacing

    for i = 1, count do
        local ctrl = pool[i]
        local point, relPoint, xOffset, yOffset

        if direction == "Horizontal (Left to Right)" then
            local col = (i - 1) % limit
            local row = math_floor((i - 1) / limit)
            xOffset = col * step
            yOffset = (vDir == "Above") and -(row * step) or (row * step)
            point, relPoint = TOPLEFT, TOPLEFT
        elseif direction == "Horizontal (Right to Left)" then
            local col = (i - 1) % limit
            local row = math_floor((i - 1) / limit)
            xOffset = -(col * step)
            yOffset = (vDir == "Above") and -(row * step) or (row * step)
            point, relPoint = TOPRIGHT, TOPLEFT
        elseif direction == "Horizontal (Centered)" then
            local row = math_floor((i - 1) / limit)
            local countInRow = math_min(count, (row + 1) * limit) - (row * limit)
            local rowSpan = (countInRow * iconSize) + ((countInRow - 1) * spacing)
            local col = (i - 1) % limit
            xOffset = -(rowSpan * 0.5) + (col * step) + (iconSize * 0.5)
            yOffset = (vDir == "Above") and -(row * step) or (row * step)
            point, relPoint = CENTER, CENTER
        elseif direction == "Vertical (Top to Bottom)" then
            local row = (i - 1) % limit
            local col = math_floor((i - 1) / limit)
            xOffset, yOffset = col * step, row * step
            point, relPoint = TOPLEFT, TOPLEFT
        elseif direction == "Vertical (Bottom to Top)" then
            local row = (i - 1) % limit
            local col = math_floor((i - 1) / limit)
            xOffset, yOffset = col * step, -(row * step)
            point, relPoint = BOTTOMLEFT, TOPLEFT
        elseif direction == "Vertical (Centered)" then
            local col = math_floor((i - 1) / limit)
            local countInCol = math_min(count, (col + 1) * limit) - (col * limit)
            local colSpan = (countInCol * iconSize) + ((countInCol - 1) * spacing)
            local row = (i - 1) % limit
            xOffset = col * step
            yOffset = -(colSpan * 0.5) + row * step
            point, relPoint = TOPLEFT, TOPLEFT
        end

        if ctrl.lastAnchorPoint ~= point or ctrl.lastAnchorRelPoint ~= relPoint
            or ctrl.lastAnchorX ~= xOffset or ctrl.lastAnchorY ~= yOffset then
            ctrl:ClearAnchors()
            ctrl:SetAnchor(point, parent, relPoint, xOffset, yOffset)
            ctrl.lastAnchorPoint, ctrl.lastAnchorRelPoint = point, relPoint
            ctrl.lastAnchorX, ctrl.lastAnchorY = xOffset, yOffset
        end
    end
end

-- Formatage du texte des barres
local function BuildDisplayText(formatType, current, max, percent, extraPrefix)
    local result
    if formatType == "Current / Max (Percent)" then
        result = string_format("%s / %s (%d%%)", FormatNumber(current), FormatNumber(max), percent)
    elseif formatType == "Current / Max" then
        result = string_format("%s / %s", FormatNumber(current), FormatNumber(max))
    elseif formatType == "Current (Percent)" then
        result = string_format("%s (%d%%)", FormatNumber(current), percent)
    elseif formatType == "Current" then
        result = FormatNumber(current)
    elseif formatType == "Percent" then
        result = string_format("%d%%", percent)
    else
        result = ""
    end

    if extraPrefix and extraPrefix ~= "" then
        return extraPrefix .. " : " .. result
    end
    return result
end

-- Mise à jour unitaire d'une barre
local function UpdateSingleBar(barKey, unitTag, mechanicType)
    local ui = TrueRessourceBars.bars[barKey]
    local cfg = TrueRessourceBars.savedVars.bars[barKey]
    if not ui or not cfg then return end

    if cfg.enabled == "No" then
        SetHiddenIfChanged(ui.container, true)
        return
    end

    local current, effectiveMax
    local targetName = ""
    local isDummyTarget = (barKey == "target" and TrueRessourceBars.previewMode and not DoesUnitExist(unitTag))

    if isDummyTarget then
        SetHiddenIfChanged(ui.container, false)
        current = 75000
        effectiveMax = 100000
        targetName = "Target Dummy"
    else
        if not DoesUnitExist(unitTag) then
            SetHiddenIfChanged(ui.container, true)
            return
        end
        SetHiddenIfChanged(ui.container, false)
        local cur, max, eff = GetUnitPower(unitTag, mechanicType)
        current = cur or 0
        effectiveMax = (eff and eff > 0) and eff or (max and max > 0 and max or 1)
        if barKey == "target" then
            targetName = TrueRessourceBars.targetName
        end
    end

    local percent = effectiveMax > 0 and math_floor((current / effectiveMax) * 100) or 0

    if not ui.animValue then
        ui.animValue = current
    elseif ui.animValue ~= current then
        ui.animValue = ui.animValue + (current - ui.animValue) * 0.45
        if math_abs(ui.animValue - current) < 1.5 then
            ui.animValue = current
        end
    end

    local mainVal, ghostVal
    if ui.animValue > current then
        mainVal, ghostVal = current, ui.animValue
    else
        mainVal, ghostVal = ui.animValue, current
    end

    -- Mise à jour des jauges uniquement si les valeurs ont bougé
    if ui.lastMainVal ~= mainVal or ui.lastGhostVal ~= ghostVal or ui.lastEffectiveMax ~= effectiveMax then
        ui.lastMainVal, ui.lastGhostVal, ui.lastEffectiveMax = mainVal, ghostVal, effectiveMax

        if cfg.drainDirection == "To Center" then
            local halfMax, halfMain, halfGhost = effectiveMax * 0.5, mainVal * 0.5, ghostVal * 0.5
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
    end

    -- Mise à jour des textes uniquement si nécessaire
    if ui.lastCurrent ~= current or ui.lastTextMax ~= effectiveMax or ui.lastTargetName ~= targetName then
        ui.lastCurrent, ui.lastTextMax, ui.lastTargetName = current, effectiveMax, targetName

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
    end

    -- Mise à jour du bouclier uniquement sur changement
    if mechanicType == MECHANIC_HEALTH then
        local shieldVal = isDummyTarget and 20000 or (TrueRessourceBars.shieldTotals[unitTag] or 0)
        if shieldVal > 0 then
            if ui.lastShieldVal ~= shieldVal or ui.lastShieldMax ~= effectiveMax or ui.lastShieldDir ~= cfg.drainDirection then
                local shieldW = math_max(1, math_floor(math_min(1, shieldVal / effectiveMax) * cfg.width))

                if ui.lastShieldDir ~= cfg.drainDirection then
                    ui.shieldBar:ClearAnchors()
                    if cfg.drainDirection == "To Center" then
                        ui.shieldBar:SetAnchor(CENTER, ui.container, CENTER, 0, 0)
                    elseif cfg.drainDirection == "Left to Right" then
                        ui.shieldBar:SetAnchor(RIGHT, ui.container, RIGHT, 0, 0)
                    else
                        ui.shieldBar:SetAnchor(LEFT, ui.container, LEFT, 0, 0)
                    end
                    ui.lastShieldDir = cfg.drainDirection
                end

                if ui.lastShieldW ~= shieldW then
                    ui.shieldBar:SetDimensions(shieldW, cfg.height)
                    ui.shieldBar:SetMinMax(0, 1)
                    ui.shieldBar:SetValue(1)
                    ui.lastShieldW = shieldW
                end

                SetHiddenIfChanged(ui.shieldBar, false)
                if ui.lastShieldVal ~= shieldVal then
                    ui.shieldLabel:SetText(string_format("[%s]", FormatNumber(shieldVal)))
                end

                ui.lastShieldVal, ui.lastShieldMax = shieldVal, effectiveMax
            end
        elseif ui.lastShieldVal ~= 0 then
            SetHiddenIfChanged(ui.shieldBar, true)
            ui.shieldLabel:SetText("")
            ui.lastShieldVal, ui.lastShieldW = 0, 0
        end
    end

    if cfg.warningEnabled and percent <= cfg.warningThreshold and percent > 0 then
        local alpha = GetDoublePulseAlpha(cfg.warningPulseSpeed or 120)
        ui.container:SetAlpha(alpha)
        ui.lastAlpha = alpha
    elseif ui.lastAlpha ~= 1.0 then
        ui.container:SetAlpha(1.0)
        ui.lastAlpha = 1.0
    end
end

-- Rendu factorisé d'un pool d'auras (Buffs ou Debuffs)
local function RenderAuraPool(poolType, list, count, settings, dir, enableGrid, maxPerRow, rowDir)
    for i = 1, count do
        local data = list[i]
        local ctrl = GetOrCreateTargetAuraIcon(poolType, i)

        if ctrl.lastIcon ~= data.icon then
            ctrl:SetTexture(data.icon)
            ctrl.lastIcon = data.icon
        end

        if data.isPermanent then
            if ctrl.lastTimerKey ~= -1 then
                ctrl.lastTimerKey = -1
                ctrl.timerLabel:SetText("")
            end
        else
            local timeKey, timeStr = GetFormattedTimeAndKey(data.timeLeft)
            if ctrl.lastTimerKey ~= timeKey then
                ctrl.lastTimerKey = timeKey
                ctrl.timerLabel:SetText(timeStr)
            end
        end

        local stackVal = (data.stackCount > 1) and data.stackCount or 0
        if ctrl.lastStackVal ~= stackVal then
            ctrl.lastStackVal = stackVal
            ctrl.stackLabel:SetText(GetFormattedStack(stackVal))
        end
    end

    ApplyAuraAnchors(poolType, count, settings.spacing, settings.iconSize, dir, enableGrid, maxPerRow, rowDir)

    local pool = TrueRessourceBars.controls[poolType]
    for i = count + 1, #pool do
        SetHiddenIfChanged(pool[i], true)
    end
end

-- Rafraîchissement des auras de la cible (scan unique + pool d'entrées réutilisable)
local function UpdateTargetAuras()
    local unitTag = "reticleover"
    local hasTarget = DoesUnitExist(unitTag) and not IsReticleHidden()
    local settings = TrueRessourceBars.savedVars.targetAuras
    local showBuffs = (settings.buffsEnabled ~= "No")
    local showDebuffs = (settings.debuffsEnabled ~= "No")

    if (not hasTarget and not TrueRessourceBars.previewMode) or (not showBuffs and not showDebuffs) then
        SetHiddenIfChanged(TrueRessourceBars.targetBuffFrame, true)
        SetHiddenIfChanged(TrueRessourceBars.targetDebuffFrame, true)
        return
    end

    SetHiddenIfChanged(TrueRessourceBars.targetBuffFrame, not showBuffs)
    SetHiddenIfChanged(TrueRessourceBars.targetDebuffFrame, not showDebuffs)

    local buffCount, debuffCount, poolIdx = 0, 0, 0

    if TrueRessourceBars.previewMode and not hasTarget then
        if showBuffs then
            for i, item in ipairs(dummyBuffData) do
                poolIdx = poolIdx + 1
                local entry = auraEntryPool[poolIdx]
                if not entry then entry = {}; auraEntryPool[poolIdx] = entry end
                entry.icon, entry.timeLeft, entry.isPermanent = item.icon, item.time, false
                entry.stackCount, entry.name = (i % 2 == 0) and 3 or 0, "PreviewBuff" .. i
                buffCount = buffCount + 1
                reusableBuffList[buffCount] = entry
            end
        end
        if showDebuffs then
            for i, item in ipairs(dummyDebuffData) do
                poolIdx = poolIdx + 1
                local entry = auraEntryPool[poolIdx]
                if not entry then entry = {}; auraEntryPool[poolIdx] = entry end
                entry.icon, entry.timeLeft, entry.isPermanent = item.icon, item.time, false
                entry.stackCount, entry.name = 0, "PreviewDebuff" .. i
                debuffCount = debuffCount + 1
                reusableDebuffList[debuffCount] = entry
            end
        end
    else
        local currentTime = GetFrameTimeSeconds()
        local longLimit = (settings.longBuffThreshold or 60) * 60
        local numBuffs = GetNumBuffs(unitTag)

        for i = 1, numBuffs do
            local buffName, timeStarted, timeEnding, _, stackCount, iconFilename, _, effectType = GetUnitBuffInfo(unitTag, i)
            if buffName and buffName ~= "" then
                local isPermanent = (timeStarted == timeEnding) or (timeEnding == 0)
                local timeLeft = isPermanent and 0 or (timeEnding - currentTime)

                local skip = (settings.hidePermanent and isPermanent)
                          or (settings.hideLongBuffs and not isPermanent and timeLeft > longLimit)

                if not skip then
                    local isDebuff = (effectType == BUFF_EFFECT_TYPE_DEBUFF)
                    if (isDebuff and showDebuffs) or (not isDebuff and showBuffs) then
                        poolIdx = poolIdx + 1
                        local entry = auraEntryPool[poolIdx]
                        if not entry then entry = {}; auraEntryPool[poolIdx] = entry end
                        entry.name, entry.icon = buffName, iconFilename
                        entry.stackCount, entry.isPermanent, entry.timeLeft = stackCount or 0, isPermanent, timeLeft

                        if isDebuff then
                            debuffCount = debuffCount + 1
                            reusableDebuffList[debuffCount] = entry
                        else
                            buffCount = buffCount + 1
                            reusableBuffList[buffCount] = entry
                        end
                    end
                end
            end
        end
    end

    for i = buffCount + 1, #reusableBuffList do reusableBuffList[i] = nil end
    for i = debuffCount + 1, #reusableDebuffList do reusableDebuffList[i] = nil end

    if buffCount > 1 then table.sort(reusableBuffList, CompareEffectsDescending) end
    if debuffCount > 1 then table.sort(reusableDebuffList, CompareEffectsDescending) end

    if showBuffs then
        RenderAuraPool("targetBuffs", reusableBuffList, buffCount, settings, settings.buffDir, settings.buffEnableGrid, settings.buffMaxPerRow, settings.buffRowDirection)
    end
    if showDebuffs then
        RenderAuraPool("targetDebuffs", reusableDebuffList, debuffCount, settings, settings.debuffDir, settings.debuffEnableGrid, settings.debuffMaxPerRow, settings.debuffRowDirection)
    end
end

-- Neutralisation propre et conforme à la Sandbox Console
local function SuppressControl(ctrl)
    if not ctrl then return end
    ctrl:SetHidden(true)
    ctrl:SetAlpha(0)
    if not suppressedControls[ctrl] then
        ZO_PreHookHandler(ctrl, "OnShow", function(self)
            self:SetHidden(true)
            self:SetAlpha(0)
            return true
        end)
        suppressedControls[ctrl] = true
    end
end

local function CleanGamepadUI()
    local playerFrag = PLAYER_ATTRIBUTE_BARS_FRAGMENT or (PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.fragment)
    local targetFrag = (GAMEPAD_TARGET_UNIT_FRAME and GAMEPAD_TARGET_UNIT_FRAME.fragment) or TARGET_UNIT_FRAME_FRAGMENT
    local fragmentsToDrop = { playerFrag, targetFrag }

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

    SuppressControl(ZO_PlayerAttributeContainerGamepad or (PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.control))
    SuppressControl(ZO_PlayerAttribute)
    if GAMEPAD_TARGET_UNIT_FRAME then
        SuppressControl(GAMEPAD_TARGET_UNIT_FRAME.control)
        SuppressControl(GAMEPAD_TARGET_UNIT_FRAME.frame)
    end
    SuppressControl(ZO_GamepadTargetUnitFrame)
    SuppressControl(ZO_GamepadTargetUnitFrameBuffs)
    SuppressControl(ZO_GamepadTargetUnitFrameDebuffs)
end

-- Détection des menus et du tableau des scores
local function ShouldHideAllUI()
    if TrueRessourceBars.previewMode then return false end
    if IsReticleHidden() then return true end

    if SCENE_MANAGER then
        if SCENE_MANAGER:IsShowing("battleground_scoreboard") then return true end
        if not SCENE_MANAGER:IsShowing("hud")
            and not SCENE_MANAGER:IsShowing("gamepad_hud")
            and not SCENE_MANAGER:IsShowing("gamepad_hud_scene") then
            return true
        end
    end
    return false
end

-- Événements boucliers (7e arg sur ADDED = value ; 8e arg sur UPDATED = newValue)
local function OnVisualAdded(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, value)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and (unitTag == "player" or unitTag == "reticleover") then
        SetUnitShieldSlot(unitTag, statType, attributeType, powerType, value or 0)
    end
end

local function OnVisualUpdated(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, oldValue, newValue)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and (unitTag == "player" or unitTag == "reticleover") then
        SetUnitShieldSlot(unitTag, statType, attributeType, powerType, newValue or 0)
    end
end

local function OnVisualRemoved(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and (unitTag == "player" or unitTag == "reticleover") then
        SetUnitShieldSlot(unitTag, statType, attributeType, powerType, 0)
    end
end

local function OnReticleTargetChanged()
    RefreshUnitShieldCache("reticleover")
    TrueRessourceBars.targetName = DoesUnitExist("reticleover") and GetUnitName("reticleover") or ""
end

-- Boucle générale de mise à jour
local function MasterUpdateLoop()
    local hideUI = ShouldHideAllUI()
    SetHiddenIfChanged(TrueRessourceBars.root, hideUI)

    if hideUI then
        SetHiddenIfChanged(TrueRessourceBars.targetBuffFrame, true)
        SetHiddenIfChanged(TrueRessourceBars.targetDebuffFrame, true)
        return
    end

    UpdateSingleBar("health", "player", MECHANIC_HEALTH)
    UpdateSingleBar("magicka", "player", MECHANIC_MAGICKA)
    UpdateSingleBar("stamina", "player", MECHANIC_STAMINA)
    UpdateSingleBar("target", "reticleover", MECHANIC_HEALTH)
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

    LAM:RegisterAddonPanel("TrueRessourceBarsOptions", {
        type = "panel",
        name = "True Ressource Bars",
        displayName = "|cff5900True Ressource Bars|r",
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = TrueRessourceBars.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local drainChoices = { "Right to Left", "Left to Right", "To Center" }
    local formatChoices = { "Current / Max (Percent)", "Current / Max", "Current (Percent)", "Current", "Percent" }

    local function CreateBarSubmenu(title, barKey, isHealth)
        local controls = {
            {
                type = "dropdown", name = "Active", tooltip = "Enable or disable this resource bar.",
                choices = { "Yes", "No" },
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].enabled or "Yes" end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].enabled = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider", name = "Position X", min = -1500, max = 1500, step = 5,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].x end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].x = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider", name = "Position Y", min = -1000, max = 1000, step = 5,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].y end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].y = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider", name = "Width", min = 50, max = 1000, step = 2,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].width end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].width = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider", name = "Height", min = 10, max = 150, step = 2,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].height end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].height = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "colorpicker", name = "Bar Color",
                getFunc = function() return GetRGBA(TrueRessourceBars.savedVars.bars[barKey].color, 1, 1, 1, 1) end,
                setFunc = function(r, g, b, a) TrueRessourceBars.savedVars.bars[barKey].color = { r = r, g = g, b = b, a = a }; ApplyBarVisuals(barKey) end,
            },
            {
                type = "dropdown", name = "Drain Direction", choices = drainChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].drainDirection end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].drainDirection = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "dropdown", name = "Text Format", choices = formatChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].textFormat end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].textFormat = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "dropdown", name = "Font Family", choices = fontChoices,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].font end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].font = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "slider", name = "Font Size", min = 10, max = 40, step = 1,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].fontSize end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].fontSize = v; ApplyBarVisuals(barKey) end,
            },
            {
                type = "colorpicker", name = "Font Color",
                getFunc = function() return GetRGBA(TrueRessourceBars.savedVars.bars[barKey].textColor, 1, 1, 1, 1) end,
                setFunc = function(r, g, b, a) TrueRessourceBars.savedVars.bars[barKey].textColor = { r = r, g = g, b = b, a = a }; ApplyBarVisuals(barKey) end,
            },
            { type = "header", name = "Warning Settings (Double Pulse)" },
            {
                type = "checkbox", name = "Enable Warning Mode (Double Pulse)",
                tooltip = "Makes the bar pulse twice in a heartbeat rhythm whenever health/resource drops below the set threshold.",
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].warningEnabled end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].warningEnabled = v end,
            },
            {
                type = "slider", name = "Warning Threshold (%)", min = 1, max = 85, step = 1,
                disabled = function() return not TrueRessourceBars.savedVars.bars[barKey].warningEnabled end,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].warningThreshold end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].warningThreshold = v end,
            },
            {
                type = "slider", name = "Pulse Speed (ms)", min = 50, max = 300, step = 10,
                tooltip = "Adjusts the tempo of each pulsation in the sequence (smaller values mean faster pulses).",
                disabled = function() return not TrueRessourceBars.savedVars.bars[barKey].warningEnabled end,
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].warningPulseSpeed or 120 end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].warningPulseSpeed = v; ApplyBarVisuals(barKey) end,
            }
        }

        if barKey == "target" then
            table.insert(controls, { type = "header", name = "Enemy Target Name Display" })
            table.insert(controls, {
                type = "dropdown", name = "Target Name Position",
                tooltip = "Choose where to display the target enemy name relative to the center of the bar.",
                choices = { "Above", "Below", "Inside Bar", "Hidden" },
                getFunc = function() return TrueRessourceBars.savedVars.bars.target.targetNamePosition or "Above" end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars.target.targetNamePosition = v; ApplyBarVisuals("target") end,
            })
            table.insert(controls, {
                type = "slider", name = "Target Name Font Size", min = 10, max = 36, step = 1,
                disabled = function()
                    local pos = TrueRessourceBars.savedVars.bars.target.targetNamePosition or "Above"
                    return pos == "Hidden" or pos == "Inside Bar"
                end,
                getFunc = function() return TrueRessourceBars.savedVars.bars.target.targetNameFontSize or 18 end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars.target.targetNameFontSize = v; ApplyBarVisuals("target") end,
            })
        end

        if isHealth then
            table.insert(controls, { type = "header", name = "Shields Configuration" })
            table.insert(controls, {
                type = "dropdown", name = "Shield Value Position", choices = cornerPositionChoices,
                tooltip = "Choose which corner of the bar will display the shield numerical value.",
                getFunc = function() return TrueRessourceBars.savedVars.bars[barKey].shieldValuePos or "Top Right" end,
                setFunc = function(v) TrueRessourceBars.savedVars.bars[barKey].shieldValuePos = v; ApplyBarVisuals(barKey) end,
            })
            table.insert(controls, {
                type = "colorpicker", name = "Shield Overlay Color",
                getFunc = function() return GetRGBA(TrueRessourceBars.savedVars.bars[barKey].shieldColor, 0.75, 0.25, 0.95, 0.75) end,
                setFunc = function(r, g, b, a) TrueRessourceBars.savedVars.bars[barKey].shieldColor = { r = r, g = g, b = b, a = a }; ApplyBarVisuals(barKey) end,
            })
        end

        return { type = "submenu", name = title, controls = controls }
    end

    -- Factorisation des sous-menus Buffs / Débuffs de la cible
    local function CreateAuraSubmenu(title, labelPrefix, enabledKey, xKey, yKey, dirKey, gridKey, maxKey, rowDirKey, frameRefName)
        return {
            type = "submenu",
            name = title,
            tooltip = string_format("Positions, orientation, and multiple row/column settings for target %s.", string.lower(labelPrefix)),
            controls = {
                {
                    type = "dropdown", name = "Active", choices = { "Yes", "No" },
                    tooltip = string_format("Enable or disable the target %s bar.", string.lower(labelPrefix)),
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[enabledKey] or "Yes" end,
                    setFunc = function(v)
                        TrueRessourceBars.savedVars.targetAuras[enabledKey] = v
                        if v == "No" then SetHiddenIfChanged(TrueRessourceBars[frameRefName], true) end
                    end,
                },
                {
                    type = "slider", name = labelPrefix .. " Position (X)", min = -1500, max = 1500, step = 5,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[xKey] end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras[xKey] = v; UpdateAuraPositions() end,
                },
                {
                    type = "slider", name = labelPrefix .. " Position (Y)", min = -1000, max = 1000, step = 5,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[yKey] end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras[yKey] = v; UpdateAuraPositions() end,
                },
                {
                    type = "dropdown", name = labelPrefix .. " Orientation", choices = auraOrientationChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[dirKey] end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras[dirKey] = v end,
                },
                {
                    type = "checkbox", name = "Enable Multiple Rows / Columns",
                    tooltip = "Enable this to allow icons to wrap onto new rows/columns once the limit per line is reached.",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[gridKey] end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras[gridKey] = v end,
                },
                {
                    type = "slider", name = "Max " .. labelPrefix .. " Per Line", min = 1, max = 30, step = 1,
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras[gridKey] end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[maxKey] end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras[maxKey] = v end,
                },
                {
                    type = "dropdown", name = "New Row Direction", choices = { "Below", "Above" },
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras[gridKey] end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras[rowDirKey] end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras[rowDirKey] = v end,
                },
            }
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
        {
            type = "submenu",
            name = "Target Auras Filters",
            tooltip = "Filter out permanent effects or long duration buffs on target.",
            controls = {
                {
                    type = "checkbox", name = "Hide Permanent Effects",
                    tooltip = "Hides passives, mundus stones, and infinite buffs.",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.hidePermanent end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.hidePermanent = v end,
                },
                {
                    type = "checkbox", name = "Hide Long Duration Effects",
                    tooltip = "Hides buffs that have a long timer (e.g. food).",
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.hideLongBuffs end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.hideLongBuffs = v end,
                },
                {
                    type = "slider", name = "Long Duration Threshold (Minutes)", min = 1, max = 120, step = 1,
                    disabled = function() return not TrueRessourceBars.savedVars.targetAuras.hideLongBuffs end,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.longBuffThreshold end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.longBuffThreshold = v end,
                },
            }
        },
        CreateAuraSubmenu("Target Buffs Bar Configuration", "Buffs", "buffsEnabled", "buffX", "buffY", "buffDir", "buffEnableGrid", "buffMaxPerRow", "buffRowDirection", "targetBuffFrame"),
        CreateAuraSubmenu("Target Debuffs Bar Configuration", "Debuffs", "debuffsEnabled", "debuffX", "debuffY", "debuffDir", "debuffEnableGrid", "debuffMaxPerRow", "debuffRowDirection", "targetDebuffFrame"),
        {
            type = "submenu",
            name = "Target Auras Appearance & Sizing",
            tooltip = "Adjust sizes, spacing, and typography readability for target auras.",
            controls = {
                {
                    type = "slider", name = "Icons Size", min = 20, max = 100, step = 2,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.iconSize end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.iconSize = v; InvalidateAuraStyles() end,
                },
                {
                    type = "slider", name = "Spacing", min = 0, max = 50, step = 1,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.spacing end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.spacing = v end,
                },
                {
                    type = "dropdown", name = "Font Family", choices = fontChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.fontStyle end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.fontStyle = v; InvalidateAuraStyles() end,
                },
                {
                    type = "dropdown", name = "Font Outline / Shadow Style", choices = availableStyleChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.fontOutlineStyle end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.fontOutlineStyle = v; InvalidateAuraStyles() end,
                },
            }
        },
        {
            type = "submenu",
            name = "Target Timers Display (Duration)",
            tooltip = "Position, size, and color of duration labels on target auras.",
            controls = {
                {
                    type = "dropdown", name = "Buffs Timer Position", choices = timerPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.timerBuffPos end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.timerBuffPos = v; InvalidateAuraStyles() end,
                },
                {
                    type = "dropdown", name = "Debuffs Timer Position", choices = timerPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.timerDebuffPos end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.timerDebuffPos = v; InvalidateAuraStyles() end,
                },
                {
                    type = "slider", name = "Timer Text Size", min = 10, max = 40, step = 1,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.timerSize end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.timerSize = v; InvalidateAuraStyles() end,
                },
                {
                    type = "colorpicker", name = "Timer Color",
                    getFunc = function() return GetRGBA(TrueRessourceBars.savedVars.targetAuras.timerColor, 1, 1, 1, 1) end,
                    setFunc = function(r, g, b, a) TrueRessourceBars.savedVars.targetAuras.timerColor = { r = r, g = g, b = b, a = a }; InvalidateAuraStyles() end,
                },
            }
        },
        {
            type = "submenu",
            name = "Target Stacks Display (Charges)",
            tooltip = "Position, size, and color of stack counters on target auras.",
            controls = {
                {
                    type = "dropdown", name = "Buffs Stack Position", choices = stackPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.stackBuffPos end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.stackBuffPos = v; InvalidateAuraStyles() end,
                },
                {
                    type = "dropdown", name = "Debuffs Stack Position", choices = stackPositionChoices,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.stackDebuffPos end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.stackDebuffPos = v; InvalidateAuraStyles() end,
                },
                {
                    type = "slider", name = "Stack Text Size", min = 10, max = 40, step = 1,
                    getFunc = function() return TrueRessourceBars.savedVars.targetAuras.stackSize end,
                    setFunc = function(v) TrueRessourceBars.savedVars.targetAuras.stackSize = v; InvalidateAuraStyles() end,
                },
                {
                    type = "colorpicker", name = "Stack Color",
                    getFunc = function() return GetRGBA(TrueRessourceBars.savedVars.targetAuras.stackColor, 1, 0.8, 0, 1) end,
                    setFunc = function(r, g, b, a) TrueRessourceBars.savedVars.targetAuras.stackColor = { r = r, g = g, b = b, a = a }; InvalidateAuraStyles() end,
                },
            }
        }
    }

    LAM:RegisterOptionControls("TrueRessourceBarsOptions", options)
end

-- Resynchronisation lors du chargement de zone
local function OnPlayerActivated()
    RefreshUnitShieldCache("player")
    OnReticleTargetChanged()
    CleanGamepadUI()
end

-- Chargement initial de l'addon
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= TrueRessourceBars.name then return end
    EVENT_MANAGER:UnregisterForEvent(TrueRessourceBars.name, EVENT_ADD_ON_LOADED)

    -- Maintien strict de la version 9 des SavedVariables
    TrueRessourceBars.savedVars = ZO_SavedVars:NewAccountWide("TrueRessourceBarsSV", 9, nil, defaults)

    local wm = WINDOW_MANAGER
    TrueRessourceBars.root = wm:CreateTopLevelWindow("TrueRessourceBarsRoot")
    TrueRessourceBars.root:SetAnchorFill()

    TrueRessourceBars.bars = {
        health  = CreateBarControl("health", TrueRessourceBars.savedVars.bars.health),
        magicka = CreateBarControl("magicka", TrueRessourceBars.savedVars.bars.magicka),
        stamina = CreateBarControl("stamina", TrueRessourceBars.savedVars.bars.stamina),
        target  = CreateBarControl("target", TrueRessourceBars.savedVars.bars.target)
    }

    TrueRessourceBars.targetBuffFrame = wm:CreateTopLevelWindow(TrueRessourceBars.name .. "TargetBuffFrame")
    TrueRessourceBars.targetDebuffFrame = wm:CreateTopLevelWindow(TrueRessourceBars.name .. "TargetDebuffFrame")
    TrueRessourceBars.targetBuffFrame:SetDrawTier(DT_HIGH)
    TrueRessourceBars.targetDebuffFrame:SetDrawTier(DT_HIGH)

    for key in pairs(TrueRessourceBars.bars) do
        ApplyBarVisuals(key)
    end
    UpdateAuraPositions()

    RefreshUnitShieldCache("player")
    CleanGamepadUI()
    BuildSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnVisualAdded)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualUpdated)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualRemoved)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
    EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForUpdate(TrueRessourceBars.name .. "Loop", TrueRessourceBars.updateInterval, MasterUpdateLoop)
end

EVENT_MANAGER:RegisterForEvent(TrueRessourceBars.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)