-- ============================================================================
-- True Death Stalker
-- Suivi PvP en temps réel (optimisé mémoire console)
-- ============================================================================

local ADDON_NAME = "TrueDeathStalker"
local ADDON_DISPLAY_NAME = "True Death Stalker"
local SAVED_VARS_NAME = "TrueDeathStalkerSavedVariables"
local SAVED_VARS_VERSION = 3

-- Paramètres des fenêtres glissantes et tampons pré-alloués
local LONG_WINDOW_MS = 3000        -- Fenêtre longue de référence (3s)
local SHORT_WINDOW_MS = 1000       -- Fenêtre courte pour capter les bursts instantanés (1s)
local MIN_BURST_DIVISOR_SEC = 0.25 -- Réactivité fixe sur les bursts soudains
local UPDATE_INTERVAL_MS = 50      -- Fréquence de mise à jour (20 Hz) uniquement quand actif
local MAX_DAMAGE_SAMPLES = 256     -- Taille fixe du tampon circulaire de dégâts
local MAX_HEAL_SAMPLES = 128       -- Taille fixe du tampon circulaire de soins
local MAX_ATTACKERS = 128          -- Nombre maximal d'attaquants suivis simultanément

-- Signe de rotation pour SetTransformRotationZ (-1 ou 1 selon l'orientation en jeu)
local ROTATION_SIGN = -1

-- Opacité de base par bande (calibrée pour un halo visible et translucide)
local GLOW_INNER_ALPHA = 0.13
local GLOW_OUTER_ALPHA = 0.065
local CORE_ALPHA = 0.90

-- Constantes géométriques du Pentagone
local BASE_BOX_SIZE = 190
local CENTER_XY = 95

-- Constantes géométriques de la Jauge rectangulaire (ratios verrouillés anti-chevauchement)
local GAUGE_BORDER = 3             -- Bordure noire exacte de 3 pixels
local GAUGE_PAD = 6                -- Marge intérieure (supérieure à l'extension du halo de 3.5 px)
local GAUGE_BAR_THICK = 14         -- Épaisseur de chaque barrette
local GAUGE_BAR_GAP = 9            -- Espace entre barrettes (supérieur à 2 * 3.5 px = 7.0 px)
local GAUGE_BAR_SPAN = 44          -- Longueur de chaque barrette
local GAUGE_STEP = GAUGE_BAR_THICK + GAUGE_BAR_GAP -- 23 px par barrette
local GAUGE_FILL_LEN = (6 * GAUGE_BAR_THICK) + (5 * GAUGE_BAR_GAP) + (2 * GAUGE_PAD) + (2 * GAUGE_BORDER) -- 147 px
local GAUGE_SPAN_LEN = GAUGE_BAR_SPAN + (2 * GAUGE_PAD) + (2 * GAUGE_BORDER) -- 62 px
local GAUGE_COUNTER_V_H = 38       -- Hauteur réservée au compteur au-dessus en vertical
local GAUGE_COUNTER_H_W = 46       -- Largeur réservée au compteur à gauche en horizontal

-- Couleurs
local COLOR_PENTAGON_EDGE = { 0.88, 0.88, 0.94, 1.0 }
local COLOR_TTD_GREEN = { 0.15, 0.92, 0.28, 1.0 }
local COLOR_TTD_YELLOW = { 1.00, 0.84, 0.12, 1.0 }
local COLOR_TTD_ORANGE = { 1.00, 0.50, 0.05, 1.0 }
local COLOR_TTD_RED = { 0.98, 0.16, 0.16, 1.0 }

-- Valeurs par défaut des SavedVariables (coordonnées toujours >= 0)
local DEFAULTS = {
    displayMode = "pentagon",  -- "pentagon" ou "gauge"
    showOnlyInCombat = "yes",  -- "yes" = uniquement en combat, "no" = toujours affiché
    pentagon = {
        posX = 865,
        posY = 445,
        scale = 1.0,
    },
    gauge = {
        posX = 930,
        posY = 460,
        scale = 1.0,
        direction = "bottom_to_top", -- "bottom_to_top", "top_to_bottom", "left_to_right", "right_to_left"
        showCounter = true,
        bgAlpha = 0.70,
    },
    negate = {
        enabled = true,
        posX = 990,
        posY = 750,
        scale = 1.0,
    },
    effects = {
        glowHalo = true,
        glowIntensity = 1.0,
        brightCore = true,
        redFlash = true,
    },
}

-- ============================================================================
-- IDs de Negate ennemie (base + morphs + effets associés)
-- ============================================================================
local NEGATE_ABILITY_IDS = {
    [51894] = true,
    [29824] = true,
    [47160] = true,
    [47168] = true,
}

-- Suivi pré-alloué par ID pour éviter qu'une fin d'effet coupe l'alerte trop tôt
local activeNegateEffects = {
    [51894] = false,
    [29824] = false,
    [47160] = false,
    [47168] = false,
}

-- ============================================================================
-- État interne et tampons pré-alloués (zéro allocation en combat)
-- ============================================================================
local savedVars = nil
local isUpdateRunning = false
local isPreviewDisplay = false
local isPreviewNegate = false
local isNegateActive = false
local hudScene = nil
local hudSceneHooked = false

-- Pré-cache des chaînes "0" à "99" et "99+" pour éviter toute allocation en combat
local COUNT_STRINGS = {}
for i = 0, 99 do
    COUNT_STRINGS[i] = tostring(i)
end
local COUNT_OVERFLOW_STR = "99+"

-- Tampons circulaires pré-alloués
local damageRing = {}
local damageHead = 1
for i = 1, MAX_DAMAGE_SAMPLES do
    damageRing[i] = { time = 0, value = 0 }
end

local healRing = {}
local healHead = 1
for i = 1, MAX_HEAL_SAMPLES do
    healRing[i] = { time = 0, value = 0 }
end

-- Pool fixe des attaquants uniques
local attackersPool = {}
for i = 1, MAX_ATTACKERS do
    attackersPool[i] = { id = 0, lastHit = 0 }
end

-- Cache d'état UI (dirty flags)
local uiCache = {
    countText = "",
    ttdLevel = -1,
    activePentagonCount = 0,
    activeGaugeCount = 0,
    pentagonVisible = false,
    gaugeVisible = false,
    negateVisible = false,
}

-- Contrôles Pentagone
local pentagonWindow = nil
local pentagonCountLabel = nil
local pentagonEdges = {}
local pentagonSegments = {}
local pentagonGlowOuter = {}
local pentagonGlowInner = {}
local pentagonCores = {}
local pentagonFragment = nil

-- Contrôles Jauge rectangulaire
local gaugeWindow = nil
local gaugeCountLabel = nil
local gaugeBg = nil
local gaugeBorders = {} -- top, bottom, left, right (3px noir)
local gaugeBars = {}    -- 6 barrettes
local gaugeGlowInner = {}
local gaugeGlowOuter = {}
local gaugeCores = {}
local gaugeFragment = nil

-- Contrôles Alerte Negate
local negateWindow = nil
local negateFragment = nil

-- Tables de lookup des résultats de combat
local DAMAGE_RESULTS = {
    [ACTION_RESULT_DAMAGE] = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
    [ACTION_RESULT_DAMAGE_SHIELDED] = true,
}

local HEAL_RESULTS = {
    [ACTION_RESULT_HEAL] = true,
    [ACTION_RESULT_CRITICAL_HEAL] = true,
    [ACTION_RESULT_HOT_TICK] = true,
    [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
}

-- ============================================================================
-- Fonctions utilitaires
-- ============================================================================

local function IsGamepadOnlyActive()
    return IsInGamepadPreferredMode()
end

-- Vérifie que l'on est bien en jeu (et non dans un menu, carte, inventaire, etc.)
local function IsInGameHudVisible()
    if not IsGamepadOnlyActive() then
        return false
    end
    if not hudScene then
        return false
    end
    return hudScene:IsShowing()
end

-- Calcule les longueurs d'adoucissement proportionnelles à la largeur de l'élément
local function GetProportionalBarLengths(length, thickness)
    local taperOuter = math.min(thickness * 0.65, length * 0.16)
    local taperMid = taperOuter * 0.42
    local bodyLen = math.max(2, length - taperOuter)
    local shoulderLen = math.max(2, length - taperMid)
    return bodyLen, shoulderLen, length
end

-- Calcule les alphas actuels des halos en fonction du slider Glow Intensity
local function GetGlowAlphas()
    local intensity = (savedVars and savedVars.effects and savedVars.effects.glowIntensity) or 1.0
    local inAlpha = math.min(0.35, GLOW_INNER_ALPHA * intensity)
    local outAlpha = math.min(0.25, GLOW_OUTER_ALPHA * intensity)
    return inAlpha, outAlpha
end

-- Utilitaires pour manipuler uniformément les barres arrondies à 3 bandes
local function SetRoundedBarColor(barSet, r, g, b, a)
    barSet[1]:SetColor(r, g, b, a)
    barSet[2]:SetColor(r, g, b, a)
    barSet[3]:SetColor(r, g, b, a)
end

local function SetRoundedBarAlpha(barSet, alpha)
    barSet[1]:SetAlpha(alpha)
    barSet[2]:SetAlpha(alpha)
    barSet[3]:SetAlpha(alpha)
end

local function SetRoundedBarHidden(barSet, hidden)
    barSet[1]:SetHidden(hidden)
    barSet[2]:SetHidden(hidden)
    barSet[3]:SetHidden(hidden)
end

-- Ajuste la géométrie (orientée horizontalement ou verticalement) d'une barre arrondie sans rotation
local function LayoutAxisRoundedBar(barSet, parent, cx, cy, length, thickness, isHorizontalBar)
    local bodyLen, shoulderLen, fullLen = GetProportionalBarLengths(length, thickness)

    if isHorizontalBar then
        barSet[1]:SetDimensions(bodyLen, thickness)
        barSet[2]:SetDimensions(shoulderLen, thickness * 0.78)
        barSet[3]:SetDimensions(fullLen, thickness * 0.45)
    else
        barSet[1]:SetDimensions(thickness, bodyLen)
        barSet[2]:SetDimensions(thickness * 0.78, shoulderLen)
        barSet[3]:SetDimensions(thickness * 0.45, fullLen)
    end

    for k = 1, 3 do
        barSet[k]:ClearAnchors()
        barSet[k]:SetAnchor(CENTER, parent, TOPLEFT, cx, cy)
    end
end

-- Récupère le bouclier actif sur le joueur
local function GetPlayerShield()
    local value = GetUnitAttributeVisualizerEffectInfo(
        "player",
        ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION,
        ATTRIBUTE_HEALTH,
        COMBAT_MECHANIC_FLAGS_HEALTH
    )
    return value or 0
end

-- Enregistre un attaquant dans le pool fixe sans allouer de table
local function RecordAttacker(sourceUnitId, nowMs)
    if not sourceUnitId or sourceUnitId == 0 then
        return
    end

    local freeIndex = 0
    for i = 1, MAX_ATTACKERS do
        local slot = attackersPool[i]
        if slot.id == sourceUnitId then
            slot.lastHit = nowMs
            return
        elseif freeIndex == 0 and (slot.id == 0 or (nowMs - slot.lastHit) > LONG_WINDOW_MS) then
            freeIndex = i
        end
    end

    if freeIndex > 0 then
        attackersPool[freeIndex].id = sourceUnitId
        attackersPool[freeIndex].lastHit = nowMs
    end
end

-- ============================================================================
-- Mise à jour visuelle (Pentagone ou Jauge)
-- ============================================================================

local function ApplyTTDVisual(level, forceColorRefresh)
    local fx = savedVars and savedVars.effects or DEFAULTS.effects
    local mode = savedVars and savedVars.displayMode or DEFAULTS.displayMode

    if uiCache.ttdLevel == level and not forceColorRefresh then
        return
    end
    uiCache.ttdLevel = level

    local glowInAlpha, glowOutAlpha = GetGlowAlphas()

    if mode == "pentagon" then
        uiCache.activeGaugeCount = 0
        local color = COLOR_TTD_GREEN
        local activeCount = 0

        if level == 1 then
            activeCount = 1
            color = COLOR_TTD_GREEN
        elseif level == 2 then
            activeCount = 3
            color = COLOR_TTD_YELLOW
        elseif level == 3 then
            activeCount = 5
            color = COLOR_TTD_RED
        end

        uiCache.activePentagonCount = activeCount
        local r, g, b = color[1], color[2], color[3]

        for i = 1, 5 do
            local isActive = (i <= activeCount)
            local seg = pentagonSegments[i]
            local glowIn = pentagonGlowInner[i]
            local glowOut = pentagonGlowOuter[i]
            local core = pentagonCores[i]

            if isActive then
                SetRoundedBarColor(seg, r, g, b, 1.0)
                SetRoundedBarAlpha(seg, 1.0)
                SetRoundedBarHidden(seg, false)

                if fx.glowHalo then
                    SetRoundedBarColor(glowIn, r, g, b, glowInAlpha)
                    SetRoundedBarColor(glowOut, r, g, b, glowOutAlpha)
                    SetRoundedBarAlpha(glowIn, glowInAlpha)
                    SetRoundedBarAlpha(glowOut, glowOutAlpha)
                    SetRoundedBarHidden(glowIn, false)
                    SetRoundedBarHidden(glowOut, false)
                else
                    SetRoundedBarHidden(glowIn, true)
                    SetRoundedBarHidden(glowOut, true)
                end

                if fx.brightCore then
                    SetRoundedBarAlpha(core, CORE_ALPHA)
                    SetRoundedBarHidden(core, false)
                else
                    SetRoundedBarHidden(core, true)
                end
            else
                SetRoundedBarHidden(seg, true)
                SetRoundedBarHidden(glowIn, true)
                SetRoundedBarHidden(glowOut, true)
                SetRoundedBarHidden(core, true)
            end
        end
    else
        -- Mode Jauge rectangulaire (6 barrettes : 1 verte -> 3 orange -> 6 rouges)
        uiCache.activePentagonCount = 0
        local color = COLOR_TTD_GREEN
        local activeCount = 0

        if level == 1 then
            activeCount = 1
            color = COLOR_TTD_GREEN
        elseif level == 2 then
            activeCount = 3
            color = COLOR_TTD_ORANGE
        elseif level == 3 then
            activeCount = 6
            color = COLOR_TTD_RED
        end

        uiCache.activeGaugeCount = activeCount
        local r, g, b = color[1], color[2], color[3]

        for i = 1, 6 do
            local isActive = (i <= activeCount)
            local bar = gaugeBars[i]
            local glowIn = gaugeGlowInner[i]
            local glowOut = gaugeGlowOuter[i]
            local core = gaugeCores[i]

            if isActive then
                SetRoundedBarColor(bar, r, g, b, 1.0)
                SetRoundedBarAlpha(bar, 1.0)
                SetRoundedBarHidden(bar, false)

                if fx.glowHalo then
                    SetRoundedBarColor(glowIn, r, g, b, glowInAlpha)
                    SetRoundedBarColor(glowOut, r, g, b, glowOutAlpha)
                    SetRoundedBarAlpha(glowIn, glowInAlpha)
                    SetRoundedBarAlpha(glowOut, glowOutAlpha)
                    SetRoundedBarHidden(glowIn, false)
                    SetRoundedBarHidden(glowOut, false)
                else
                    SetRoundedBarHidden(glowIn, true)
                    SetRoundedBarHidden(glowOut, true)
                end

                if fx.brightCore then
                    SetRoundedBarAlpha(core, CORE_ALPHA)
                    SetRoundedBarHidden(core, false)
                else
                    SetRoundedBarHidden(core, true)
                end
            else
                SetRoundedBarHidden(bar, true)
                SetRoundedBarHidden(glowIn, true)
                SetRoundedBarHidden(glowOut, true)
                SetRoundedBarHidden(core, true)
            end
        end
    end
end

-- Gestion du flash critique au palier rouge uniquement (multiplie l'alpha de base de chaque couche)
local function UpdateSegmentEffects(nowMs)
    local fx = savedVars and savedVars.effects or DEFAULTS.effects
    local mode = savedVars and savedVars.displayMode or DEFAULTS.displayMode
    local activeCount = (mode == "pentagon") and uiCache.activePentagonCount or uiCache.activeGaugeCount

    if activeCount <= 0 then
        return
    end

    local mult = 1.0
    if uiCache.ttdLevel == 3 and fx.redFlash then
        local wave = 0.5 + 0.5 * math.sin(nowMs * 0.018)
        mult = 0.35 + 0.65 * wave
    end

    local glowInAlpha, glowOutAlpha = GetGlowAlphas()

    if mode == "pentagon" then
        for i = 1, activeCount do
            SetRoundedBarAlpha(pentagonSegments[i], 1.0 * mult)
            if fx.glowHalo then
                SetRoundedBarAlpha(pentagonGlowInner[i], glowInAlpha * mult)
                SetRoundedBarAlpha(pentagonGlowOuter[i], glowOutAlpha * mult)
            end
            if fx.brightCore then
                SetRoundedBarAlpha(pentagonCores[i], CORE_ALPHA * mult)
            end
        end
    else
        for i = 1, activeCount do
            SetRoundedBarAlpha(gaugeBars[i], 1.0 * mult)
            if fx.glowHalo then
                SetRoundedBarAlpha(gaugeGlowInner[i], glowInAlpha * mult)
                SetRoundedBarAlpha(gaugeGlowOuter[i], glowOutAlpha * mult)
            end
            if fx.brightCore then
                SetRoundedBarAlpha(gaugeCores[i], CORE_ALPHA * mult)
            end
        end
    end
end

-- Reconstruit la disposition de la jauge (uniquement hors combat lors d'un changement d'option)
local function RebuildGaugeLayout()
    if not gaugeWindow or not savedVars then
        return
    end

    local gSettings = savedVars.gauge
    local dir = gSettings.direction
    local isVertical = (dir == "bottom_to_top" or dir == "top_to_bottom")
    local showCounter = gSettings.showCounter

    local gw = isVertical and GAUGE_SPAN_LEN or GAUGE_FILL_LEN
    local gh = isVertical and GAUGE_FILL_LEN or GAUGE_SPAN_LEN

    local gx, gy = 0, 0
    local totalW, totalH = gw, gh

    if showCounter then
        if isVertical then
            gy = GAUGE_COUNTER_V_H
            totalH = gh + GAUGE_COUNTER_V_H
            gaugeCountLabel:ClearAnchors()
            gaugeCountLabel:SetAnchor(CENTER, gaugeWindow, TOPLEFT, gw * 0.5, GAUGE_COUNTER_V_H * 0.5 - 2)
        else
            gx = GAUGE_COUNTER_H_W
            totalW = gw + GAUGE_COUNTER_H_W
            gaugeCountLabel:ClearAnchors()
            gaugeCountLabel:SetAnchor(CENTER, gaugeWindow, TOPLEFT, GAUGE_COUNTER_H_W * 0.5 - 2, gh * 0.5)
        end
        gaugeCountLabel:SetHidden(false)
    else
        gaugeCountLabel:SetHidden(true)
    end

    gaugeWindow:SetDimensions(totalW, totalH)

    gaugeBg:SetDimensions(gw - (2 * GAUGE_BORDER), gh - (2 * GAUGE_BORDER))
    gaugeBg:SetColor(0.05, 0.05, 0.07, gSettings.bgAlpha)
    gaugeBg:ClearAnchors()
    gaugeBg:SetAnchor(TOPLEFT, gaugeWindow, TOPLEFT, gx + GAUGE_BORDER, gy + GAUGE_BORDER)

    -- 4 bordures noires de 3 pixels exacts
    gaugeBorders[1]:SetDimensions(gw, GAUGE_BORDER)
    gaugeBorders[1]:ClearAnchors()
    gaugeBorders[1]:SetAnchor(TOPLEFT, gaugeWindow, TOPLEFT, gx, gy)

    gaugeBorders[2]:SetDimensions(gw, GAUGE_BORDER)
    gaugeBorders[2]:ClearAnchors()
    gaugeBorders[2]:SetAnchor(TOPLEFT, gaugeWindow, TOPLEFT, gx, gy + gh - GAUGE_BORDER)

    gaugeBorders[3]:SetDimensions(GAUGE_BORDER, gh)
    gaugeBorders[3]:ClearAnchors()
    gaugeBorders[3]:SetAnchor(TOPLEFT, gaugeWindow, TOPLEFT, gx, gy)

    gaugeBorders[4]:SetDimensions(GAUGE_BORDER, gh)
    gaugeBorders[4]:ClearAnchors()
    gaugeBorders[4]:SetAnchor(TOPLEFT, gaugeWindow, TOPLEFT, gx + gw - GAUGE_BORDER, gy)

    -- Dimensions proportionnelles des halos sans chevauchement (max +3.5 px par côté)
    local startCenter = GAUGE_BORDER + GAUGE_PAD + (GAUGE_BAR_THICK * 0.5)
    local isHorizontalBar = isVertical

    local glowInThick = GAUGE_BAR_THICK * 1.24   -- ~17.36 px (+1.68 px/côté)
    local glowOutThick = GAUGE_BAR_THICK * 1.50  -- 21.0 px (+3.5 px/côté < 4.5 px demi-espace)
    local glowInSpan = GAUGE_BAR_SPAN * 1.07     -- ~47.08 px
    local glowOutSpan = GAUGE_BAR_SPAN * 1.14    -- ~50.16 px (< 56 px largeur intérieure)

    for i = 1, 6 do
        local idxOffset
        if dir == "bottom_to_top" or dir == "right_to_left" then
            idxOffset = (6 - i) * GAUGE_STEP
        else
            idxOffset = (i - 1) * GAUGE_STEP
        end

        local cx, cy
        if isVertical then
            cx = gx + (gw * 0.5)
            cy = gy + startCenter + idxOffset
        else
            cx = gx + startCenter + idxOffset
            cy = gy + (gh * 0.5)
        end

        LayoutAxisRoundedBar(gaugeGlowOuter[i], gaugeWindow, cx, cy, glowOutSpan, glowOutThick, isHorizontalBar)
        LayoutAxisRoundedBar(gaugeGlowInner[i], gaugeWindow, cx, cy, glowInSpan, glowInThick, isHorizontalBar)
        LayoutAxisRoundedBar(gaugeBars[i], gaugeWindow, cx, cy, GAUGE_BAR_SPAN, GAUGE_BAR_THICK, isHorizontalBar)
        LayoutAxisRoundedBar(gaugeCores[i], gaugeWindow, cx, cy, GAUGE_BAR_SPAN * 0.86, GAUGE_BAR_THICK * 0.28, isHorizontalBar)
    end
end

-- Applique les réglages de position (coordonnées >= 0) et de taille
local function ApplyLayoutSettings()
    if not savedVars then
        return
    end

    if pentagonWindow then
        pentagonWindow:ClearAnchors()
        pentagonWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.pentagon.posX, savedVars.pentagon.posY)
        pentagonWindow:SetScale(savedVars.pentagon.scale)
    end

    if gaugeWindow then
        gaugeWindow:ClearAnchors()
        gaugeWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.gauge.posX, savedVars.gauge.posY)
        gaugeWindow:SetScale(savedVars.gauge.scale)
    end

    if negateWindow then
        negateWindow:ClearAnchors()
        negateWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.negate.posX, savedVars.negate.posY)
        negateWindow:SetScale(savedVars.negate.scale)
    end
end

-- Met à jour la visibilité de la fenêtre active selon le mode choisi
local function SetActiveThreatVisible(visible)
    local mode = savedVars and savedVars.displayMode or DEFAULTS.displayMode
    local showPentagon = visible and (mode == "pentagon")
    local showGauge = visible and (mode == "gauge")

    if showPentagon then
        pentagonWindow:SetAlpha(1)
    end
    if showGauge then
        gaugeWindow:SetAlpha(1)
    end

    if uiCache.pentagonVisible ~= showPentagon then
        pentagonWindow:SetHidden(not showPentagon)
        uiCache.pentagonVisible = showPentagon
    end

    if uiCache.gaugeVisible ~= showGauge then
        gaugeWindow:SetHidden(not showGauge)
        uiCache.gaugeVisible = showGauge
    end
end

-- Met à jour le texte du compteur sur le mode actif sans allocation
local function SetActiveCountText(text)
    if uiCache.countText == text then
        return
    end
    uiCache.countText = text
    pentagonCountLabel:SetText(text)
    gaugeCountLabel:SetText(text)
end

-- Met à jour la visibilité et les valeurs en mode normal ou aperçu
local function RefreshDisplay()
    if not pentagonWindow or not gaugeWindow then
        return
    end

    if not IsGamepadOnlyActive() then
        SetActiveThreatVisible(false)
        if negateWindow and uiCache.negateVisible then
            negateWindow:SetHidden(true)
            uiCache.negateVisible = false
        end
        return
    end

    local nowMs = GetGameTimeMilliseconds()
    local inGameHud = IsInGameHudVisible()

    -- 1. Gestion de l'alerte Negate (exception pour le Preview dans les menus)
    if negateWindow then
        local negateEnabled = savedVars and savedVars.negate and savedVars.negate.enabled
        local showNegate = negateEnabled and (isPreviewNegate or (inGameHud and isNegateActive))
        if showNegate then
            negateWindow:SetAlpha(1)
        end
        if uiCache.negateVisible ~= showNegate then
            negateWindow:SetHidden(not showNegate)
            uiCache.negateVisible = showNegate
        end
    end

    -- 2. Mode Preview TTD (exception : autorisé dans les menus pour voir ses réglages en direct)
    if isPreviewDisplay then
        SetActiveThreatVisible(true)
        SetActiveCountText("5")
        ApplyTTDVisual(3, false)
        UpdateSegmentEffects(nowMs)
        return
    end

    -- 3. Hors jeu (menus, carte, inventaire...) : masquage strict du TTD normal
    if not inGameHud then
        SetActiveThreatVisible(false)
        if isUpdateRunning and not IsUnitInCombat("player") then
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Tick")
            isUpdateRunning = false
        end
        return
    end

    local inCombat = IsUnitInCombat("player")
    local onlyInCombat = (savedVars and savedVars.showOnlyInCombat or DEFAULTS.showOnlyInCombat) == "yes"

    -- Si "Show only in combat = Yes" et hors combat, on masque immédiatement l'indicateur
    if onlyInCombat and not inCombat then
        SetActiveThreatVisible(false)
        ApplyTTDVisual(0, false)
        if isUpdateRunning then
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Tick")
            isUpdateRunning = false
        end
        return
    end

    -- Compte des attaquants actifs dans la fenêtre de 3s
    local attackerCount = 0
    for i = 1, MAX_ATTACKERS do
        local slot = attackersPool[i]
        if slot.id ~= 0 then
            if (nowMs - slot.lastHit) <= LONG_WINDOW_MS then
                attackerCount = attackerCount + 1
            else
                slot.id = 0
            end
        end
    end

    -- Somme des dégâts sur fenêtre courte (1s) et longue (3s) en une seule passe
    local longDamage = 0
    local shortDamage = 0
    local oldestLongDmgTime = nowMs
    local oldestShortDmgTime = nowMs

    for i = 1, MAX_DAMAGE_SAMPLES do
        local sample = damageRing[i]
        if sample.value > 0 then
            local age = nowMs - sample.time
            if age <= LONG_WINDOW_MS then
                longDamage = longDamage + sample.value
                if sample.time < oldestLongDmgTime then
                    oldestLongDmgTime = sample.time
                end
                if age <= SHORT_WINDOW_MS then
                    shortDamage = shortDamage + sample.value
                    if sample.time < oldestShortDmgTime then
                        oldestShortDmgTime = sample.time
                    end
                end
            end
        end
    end

    -- Somme des soins sur fenêtre courte (1s) et longue (3s)
    local longHeal = 0
    local shortHeal = 0
    for i = 1, MAX_HEAL_SAMPLES do
        local sample = healRing[i]
        if sample.value > 0 then
            local age = nowMs - sample.time
            if age <= LONG_WINDOW_MS then
                longHeal = longHeal + sample.value
                if age <= SHORT_WINDOW_MS then
                    shortHeal = shortHeal + sample.value
                end
            end
        end
    end

    local hasActivity = (attackerCount > 0) or (longDamage > 0)

    -- Affichage actif en jeu
    SetActiveThreatVisible(true)

    local displayText = (attackerCount > 99) and COUNT_OVERFLOW_STR or COUNT_STRINGS[attackerCount]
    SetActiveCountText(displayText)

    -- Calcul du TTD avec diviseur adaptatif (plancher fixe à 0.25s)
    local ttdLevel = 0
    if longDamage > 0 then
        local elapsedShortSec = ((nowMs - oldestShortDmgTime) / 1000) + 0.15
        local elapsedLongSec = ((nowMs - oldestLongDmgTime) / 1000) + 0.15

        if elapsedShortSec < MIN_BURST_DIVISOR_SEC then elapsedShortSec = MIN_BURST_DIVISOR_SEC end
        if elapsedShortSec > 1.0 then elapsedShortSec = 1.0 end

        if elapsedLongSec < MIN_BURST_DIVISOR_SEC then elapsedLongSec = MIN_BURST_DIVISOR_SEC end
        if elapsedLongSec > 3.0 then elapsedLongSec = 3.0 end

        local netDpsShort = (shortDamage - shortHeal) / elapsedShortSec
        local netDpsLong = (longDamage - longHeal) / elapsedLongSec
        local netDps = (netDpsShort > netDpsLong) and netDpsShort or netDpsLong

        if netDps > 0 then
            local currentHealth = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH) or 0
            local currentShield = GetPlayerShield()
            local effectiveHealth = currentHealth + currentShield
            local ttd = effectiveHealth / netDps

            if ttd <= 1.0 then
                ttdLevel = 3
            elseif ttd <= 2.0 then
                ttdLevel = 2
            elseif ttd <= 3.0 then
                ttdLevel = 1
            end
        end
    end

    ApplyTTDVisual(ttdLevel, false)
    UpdateSegmentEffects(nowMs)

    -- Arrêt du timer si hors combat et aucune activité récente (même si toujours affiché)
    if isUpdateRunning and not inCombat and not hasActivity then
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Tick")
        isUpdateRunning = false
    end
end

local function EnsureUpdateRunning()
    if not isUpdateRunning then
        isUpdateRunning = true
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Tick", UPDATE_INTERVAL_MS, RefreshDisplay)
    end
end

-- ============================================================================
-- Gestionnaires d'événements de combat et d'effets
-- ============================================================================

local function OnCombatEvent(
    _, result, isError, _, _, _,
    _, sourceType, _, targetType, hitValue,
    _, _, _, sourceUnitId, _, _
)
    if isError or not IsGamepadOnlyActive() then
        return
    end

    if targetType ~= COMBAT_UNIT_TYPE_PLAYER or not hitValue or hitValue <= 0 then
        return
    end

    local nowMs = GetGameTimeMilliseconds()

    if DAMAGE_RESULTS[result] then
        if sourceType == COMBAT_UNIT_TYPE_PLAYER
            or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
            or sourceType == COMBAT_UNIT_TYPE_GROUP
            or sourceType == COMBAT_UNIT_TYPE_TARGET_DUMMY
        then
            return
        end

        local slot = damageRing[damageHead]
        slot.time = nowMs
        slot.value = hitValue
        damageHead = (damageHead % MAX_DAMAGE_SAMPLES) + 1

        RecordAttacker(sourceUnitId, nowMs)

        local wasRunning = isUpdateRunning
        EnsureUpdateRunning()
        if not wasRunning then
            RefreshDisplay()
        end
    elseif HEAL_RESULTS[result] then
        local slot = healRing[healHead]
        slot.time = nowMs
        slot.value = hitValue
        healHead = (healHead % MAX_HEAL_SAMPLES) + 1

        EnsureUpdateRunning()
    end
end

local function OnPlayerCombatState(_, inCombat)
    if inCombat and IsGamepadOnlyActive() then
        EnsureUpdateRunning()
    end
    RefreshDisplay()
end

-- Suivi des Negates ennemies sur le joueur
local function OnEffectChanged(_, changeType, _, _, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or not NEGATE_ABILITY_IDS[abilityId] then
        return
    end

    if not (savedVars and savedVars.negate and savedVars.negate.enabled) then
        return
    end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        activeNegateEffects[abilityId] = true
    elseif changeType == EFFECT_RESULT_FADED then
        activeNegateEffects[abilityId] = false
    end

    isNegateActive = activeNegateEffects[51894]
        or activeNegateEffects[29824]
        or activeNegateEffects[47160]
        or activeNegateEffects[47168]

    RefreshDisplay()
end

-- Réinitialisation de l'alerte Negate si le joueur meurt
local function OnPlayerDead()
    activeNegateEffects[51894] = false
    activeNegateEffects[29824] = false
    activeNegateEffects[47160] = false
    activeNegateEffects[47168] = false
    isNegateActive = false
    RefreshDisplay()
end

-- ============================================================================
-- Création unique des visuels au chargement
-- ============================================================================

local function CreateRotatedBar(parent, name, centerOffsetX, centerOffsetY, length, thickness, angleRad, color, drawLayer, drawLevel)
    local bar = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    bar:SetDimensions(length, thickness)
    bar:SetColor(color[1], color[2], color[3], color[4])
    bar:SetAlpha(color[4])
    bar:SetAnchor(CENTER, parent, TOPLEFT, CENTER_XY + centerOffsetX, CENTER_XY + centerOffsetY)
    bar:SetTransformNormalizedOriginPoint(0.5, 0.5)
    bar:SetTransformRotationZ(angleRad * ROTATION_SIGN)
    bar:SetDrawLayer(drawLayer)
    bar:SetDrawLevel(drawLevel)
    return bar
end

-- Construit une barre arrondie à 3 bandes avec adoucissement proportionnel (Pentagone)
local function CreateRoundedBar(parent, baseName, centerOffsetX, centerOffsetY, length, thickness, angleRad, color, drawLayer, drawLevel)
    local bodyLen, shoulderLen, fullLen = GetProportionalBarLengths(length, thickness)

    local s1 = CreateRotatedBar(parent, baseName .. "_S1", centerOffsetX, centerOffsetY, bodyLen, thickness, angleRad, color, drawLayer, drawLevel)
    local s2 = CreateRotatedBar(parent, baseName .. "_S2", centerOffsetX, centerOffsetY, shoulderLen, thickness * 0.78, angleRad, color, drawLayer, drawLevel)
    local s3 = CreateRotatedBar(parent, baseName .. "_S3", centerOffsetX, centerOffsetY, fullLen, thickness * 0.45, angleRad, color, drawLayer, drawLevel)

    return { s1, s2, s3 }
end

-- Construit une barre arrondie à 3 bandes sans rotation (Jauge rectangulaire)
local function CreateAxisRoundedBar(parent, baseName, color, drawLayer, drawLevel)
    local set = {}
    for k = 1, 3 do
        local tex = WINDOW_MANAGER:CreateControl(baseName .. "_S" .. k, parent, CT_TEXTURE)
        tex:SetColor(color[1], color[2], color[3], color[4])
        tex:SetAlpha(color[4])
        tex:SetDrawLayer(drawLayer)
        tex:SetDrawLevel(drawLevel)
        tex:SetHidden(true)
        set[k] = tex
    end
    return set
end

local function CreateUI()
    -- 1. Fenêtre Pentagone + Segments TTD
    pentagonWindow = WINDOW_MANAGER:CreateTopLevelWindow("TrueDeathStalkerPentagonTLW")
    pentagonWindow:SetDimensions(BASE_BOX_SIZE, BASE_BOX_SIZE)
    pentagonWindow:SetMouseEnabled(false)
    pentagonWindow:SetMovable(false)
    pentagonWindow:SetClampedToScreen(true)
    pentagonWindow:SetHidden(true)

    local edgeRadius = 42
    local edgeThickness = 3.5
    local tan36 = math.tan(math.rad(36))
    local sin36 = math.sin(math.rad(36))
    local cos36 = math.cos(math.rad(36))

    local edgeApothem = edgeRadius * cos36
    local edgeLength = (2 * edgeRadius * sin36) + (edgeThickness * tan36)

    local edgeSpecs = {
        {  90,   0 }, -- Bord inférieur (horizontal)
        {  18, -72 }, -- Côté inférieur droit
        { 162,  72 }, -- Côté inférieur gauche
        { -54,  36 }, -- Côté supérieur droit
        {-126, -36 }, -- Côté supérieur gauche
    }

    for i = 1, 5 do
        local midRad = math.rad(edgeSpecs[i][1])
        local barRad = math.rad(edgeSpecs[i][2])
        local mx = edgeApothem * math.cos(midRad)
        local my = edgeApothem * math.sin(midRad)

        pentagonEdges[i] = CreateRotatedBar(
            pentagonWindow,
            "TrueDeathStalkerEdge" .. i,
            mx, my,
            edgeLength, edgeThickness,
            barRad,
            COLOR_PENTAGON_EDGE,
            DL_CONTROLS, 2
        )
    end

    local segApothem = edgeApothem + 15
    local segLength = (2 * edgeRadius * sin36) - 2
    local segThick = 6

    for i = 1, 5 do
        local midRad = math.rad(edgeSpecs[i][1])
        local barRad = math.rad(edgeSpecs[i][2])
        local mx = segApothem * math.cos(midRad)
        local my = segApothem * math.sin(midRad)

        -- Halo externe doux et translucide (proportionnel à l'élément)
        local glowOut = CreateRoundedBar(
            pentagonWindow,
            "TrueDeathStalkerSegGlowOut" .. i,
            mx, my,
            segLength * 1.14, segThick * 1.95,
            barRad,
            { COLOR_TTD_GREEN[1], COLOR_TTD_GREEN[2], COLOR_TTD_GREEN[3], GLOW_OUTER_ALPHA },
            DL_BACKGROUND, 0
        )
        SetRoundedBarHidden(glowOut, true)
        pentagonGlowOuter[i] = glowOut

        -- Halo interne translucide
        local glowIn = CreateRoundedBar(
            pentagonWindow,
            "TrueDeathStalkerSegGlowIn" .. i,
            mx, my,
            segLength * 1.07, segThick * 1.45,
            barRad,
            { COLOR_TTD_GREEN[1], COLOR_TTD_GREEN[2], COLOR_TTD_GREEN[3], GLOW_INNER_ALPHA },
            DL_BACKGROUND, 1
        )
        SetRoundedBarHidden(glowIn, true)
        pentagonGlowInner[i] = glowIn

        local seg = CreateRoundedBar(
            pentagonWindow,
            "TrueDeathStalkerSegment" .. i,
            mx, my,
            segLength, segThick,
            barRad,
            COLOR_TTD_GREEN,
            DL_CONTROLS, 3
        )
        SetRoundedBarHidden(seg, true)
        pentagonSegments[i] = seg

        local core = CreateRoundedBar(
            pentagonWindow,
            "TrueDeathStalkerSegCore" .. i,
            mx, my,
            segLength * 0.90, segThick * 0.34,
            barRad,
            { 1.0, 0.98, 0.95, CORE_ALPHA },
            DL_CONTROLS, 4
        )
        SetRoundedBarHidden(core, true)
        pentagonCores[i] = core
    end

    pentagonCountLabel = WINDOW_MANAGER:CreateControl("TrueDeathStalkerCountLabel", pentagonWindow, CT_LABEL)
    pentagonCountLabel:SetFont("ZoFontGamepad42")
    pentagonCountLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pentagonCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    pentagonCountLabel:SetColor(1, 1, 1, 1)
    pentagonCountLabel:SetAnchor(CENTER, pentagonWindow, TOPLEFT, CENTER_XY, CENTER_XY)
    pentagonCountLabel:SetText("0")

    -- 2. Fenêtre Jauge rectangulaire (6 barrettes + bordure noire 3 px)
    gaugeWindow = WINDOW_MANAGER:CreateTopLevelWindow("TrueDeathStalkerGaugeTLW")
    gaugeWindow:SetDimensions(GAUGE_SPAN_LEN, GAUGE_FILL_LEN)
    gaugeWindow:SetMouseEnabled(false)
    gaugeWindow:SetMovable(false)
    gaugeWindow:SetClampedToScreen(true)
    gaugeWindow:SetHidden(true)

    gaugeBg = WINDOW_MANAGER:CreateControl("TrueDeathStalkerGaugeBg", gaugeWindow, CT_TEXTURE)
    gaugeBg:SetColor(0.05, 0.05, 0.07, 0.70)
    gaugeBg:SetDrawLayer(DL_BACKGROUND)
    gaugeBg:SetDrawLevel(0)

    for b = 1, 4 do
        local border = WINDOW_MANAGER:CreateControl("TrueDeathStalkerGaugeBorder" .. b, gaugeWindow, CT_TEXTURE)
        border:SetColor(0, 0, 0, 1)
        border:SetDrawLayer(DL_CONTROLS)
        border:SetDrawLevel(5)
        gaugeBorders[b] = border
    end

    for i = 1, 6 do
        gaugeGlowOuter[i] = CreateAxisRoundedBar(gaugeWindow, "TrueDeathStalkerGaugeGlowOut" .. i, { COLOR_TTD_GREEN[1], COLOR_TTD_GREEN[2], COLOR_TTD_GREEN[3], GLOW_OUTER_ALPHA }, DL_BACKGROUND, 1)
        gaugeGlowInner[i] = CreateAxisRoundedBar(gaugeWindow, "TrueDeathStalkerGaugeGlowIn" .. i, { COLOR_TTD_GREEN[1], COLOR_TTD_GREEN[2], COLOR_TTD_GREEN[3], GLOW_INNER_ALPHA }, DL_BACKGROUND, 2)
        gaugeBars[i] = CreateAxisRoundedBar(gaugeWindow, "TrueDeathStalkerGaugeBar" .. i, COLOR_TTD_GREEN, DL_CONTROLS, 3)
        gaugeCores[i] = CreateAxisRoundedBar(gaugeWindow, "TrueDeathStalkerGaugeCore" .. i, { 1.0, 0.98, 0.95, CORE_ALPHA }, DL_CONTROLS, 4)
    end

    gaugeCountLabel = WINDOW_MANAGER:CreateControl("TrueDeathStalkerGaugeCountLabel", gaugeWindow, CT_LABEL)
    gaugeCountLabel:SetFont("ZoFontGamepad34")
    gaugeCountLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    gaugeCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    gaugeCountLabel:SetColor(1, 1, 1, 1)
    gaugeCountLabel:SetText("0")

    -- 3. Fenêtre compacte de l'alerte Negate
    negateWindow = WINDOW_MANAGER:CreateTopLevelWindow("TrueDeathStalkerNegateTLW")
    negateWindow:SetDimensions(140, 48)
    negateWindow:SetMouseEnabled(false)
    negateWindow:SetMovable(false)
    negateWindow:SetClampedToScreen(true)
    negateWindow:SetHidden(true)

    local negateBg = WINDOW_MANAGER:CreateControl("TrueDeathStalkerNegateBg", negateWindow, CT_BACKDROP)
    negateBg:SetAnchorFill(negateWindow)
    negateBg:SetCenterColor(0.35, 0.02, 0.25, 0.85)
    negateBg:SetEdgeColor(1.0, 0.15, 0.35, 1.0)
    negateBg:SetEdgeTexture(nil, 2, 2, 2, 0)

    local negateLabel = WINDOW_MANAGER:CreateControl("TrueDeathStalkerNegateLabel", negateWindow, CT_LABEL)
    negateLabel:SetFont("ZoFontGamepad34")
    negateLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    negateLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    negateLabel:SetColor(1, 0.90, 0.94, 1)
    negateLabel:SetAnchor(CENTER, negateWindow, TOPLEFT, 70, 24)
    negateLabel:SetText("Negate")

    RebuildGaugeLayout()
    ApplyLayoutSettings()
end

-- Récupère la scène HUD active (avec repli sécurisé si "gamepad_hud_scene" n'est pas défini)
local function ResolveHudScene()
    return GAMEPAD_HUD_SCENE
        or SCENE_MANAGER:GetScene("gamepad_hud_scene")
        or SCENE_MANAGER:GetScene("gamepad_hud")
        or HUD_SCENE
        or SCENE_MANAGER:GetScene("hud")
end

-- Attache les fragments uniquement à la scène du HUD en jeu
local function AttachToGamepadHudScene()
    if hudSceneHooked then
        return
    end

    local scene = ResolveHudScene()
    if not scene then
        return
    end

    hudScene = scene
    hudSceneHooked = true

    pentagonFragment = ZO_HUDFadeSceneFragment:New(pentagonWindow)
    gaugeFragment = ZO_HUDFadeSceneFragment:New(gaugeWindow)
    negateFragment = ZO_HUDFadeSceneFragment:New(negateWindow)

    -- Utilisation de ZO_PreHookHandler sur OnShow conformément aux règles console
    -- Exception explicite autorisée pour le mode Preview dans les menus
    ZO_PreHookHandler(pentagonWindow, "OnShow", function(ctrl)
        if not IsGamepadOnlyActive() or savedVars.displayMode ~= "pentagon" then
            ctrl:SetHidden(true)
            return true
        end
        if not isPreviewDisplay and (not IsInGameHudVisible() or not uiCache.pentagonVisible) then
            ctrl:SetHidden(true)
            return true
        end
        ctrl:SetAlpha(1)
        return false
    end)

    ZO_PreHookHandler(gaugeWindow, "OnShow", function(ctrl)
        if not IsGamepadOnlyActive() or savedVars.displayMode ~= "gauge" then
            ctrl:SetHidden(true)
            return true
        end
        if not isPreviewDisplay and (not IsInGameHudVisible() or not uiCache.gaugeVisible) then
            ctrl:SetHidden(true)
            return true
        end
        ctrl:SetAlpha(1)
        return false
    end)

    ZO_PreHookHandler(negateWindow, "OnShow", function(ctrl)
        local negateEnabled = savedVars and savedVars.negate and savedVars.negate.enabled
        if not IsGamepadOnlyActive() or not negateEnabled then
            ctrl:SetHidden(true)
            return true
        end
        if not isPreviewNegate and (not IsInGameHudVisible() or not isNegateActive) then
            ctrl:SetHidden(true)
            return true
        end
        ctrl:SetAlpha(1)
        return false
    end)

    -- Masque immédiatement à l'ouverture d'un menu, et réaffiche au retour en jeu
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDING or newState == SCENE_HIDDEN or newState == SCENE_SHOWING or newState == SCENE_SHOWN then
            RefreshDisplay()
        end
    end)

    scene:AddFragment(pentagonFragment)
    scene:AddFragment(gaugeFragment)
    scene:AddFragment(negateFragment)
end

-- ============================================================================
-- Configuration LibAddonMenu-2.0
-- ============================================================================

local function BuildSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local panelData = {
        type = "panel",
        name = ADDON_DISPLAY_NAME,
        displayName = ADDON_DISPLAY_NAME,
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = "1.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel(ADDON_NAME .. "_Menu", panelData)

    local function IsNegateDisabled()
        return not savedVars.negate.enabled
    end

    local optionsData = {
        {
            type = "description",
            text = "Real-time PvP incoming damage, Time-To-Death (TTD), attacker counter and enemy Negate alert.",
        },
        {
            type = "dropdown",
            name = "Display Mode",
            tooltip = "Choose between the Pentagon HUD indicator or the 6-bar Rectangular Gauge.",
            choices = { "Pentagon", "Rectangular Gauge" },
            choicesValues = { "pentagon", "gauge" },
            default = DEFAULTS.displayMode,
            getFunc = function() return savedVars.displayMode end,
            setFunc = function(value)
                savedVars.displayMode = value
                ApplyTTDVisual(uiCache.ttdLevel, true)
                RefreshDisplay()
            end,
        },
        {
            type = "dropdown",
            name = "Show only in combat",
            tooltip = "Yes: display only when combat starts. No: always keep the TTD indicator visible on screen.",
            choices = { "Yes", "No" },
            choicesValues = { "yes", "no" },
            default = DEFAULTS.showOnlyInCombat,
            getFunc = function() return savedVars.showOnlyInCombat end,
            setFunc = function(value)
                savedVars.showOnlyInCombat = value
                RefreshDisplay()
            end,
        },
        {
            type = "checkbox",
            name = "Preview TTD Display",
            tooltip = "Show the active display mode (Pentagon or Gauge) on screen while adjusting settings.",
            getFunc = function() return isPreviewDisplay end,
            setFunc = function(value)
                isPreviewDisplay = value
                if value then
                    EnsureUpdateRunning()
                end
                RefreshDisplay()
            end,
        },
        {
            type = "submenu",
            name = "Pentagon Settings",
            controls = {
                {
                    type = "slider",
                    name = "Position X",
                    min = 0,
                    max = 1920,
                    step = 5,
                    default = DEFAULTS.pentagon.posX,
                    getFunc = function() return savedVars.pentagon.posX end,
                    setFunc = function(value)
                        savedVars.pentagon.posX = value
                        ApplyLayoutSettings()
                    end,
                },
                {
                    type = "slider",
                    name = "Position Y",
                    min = 0,
                    max = 1080,
                    step = 5,
                    default = DEFAULTS.pentagon.posY,
                    getFunc = function() return savedVars.pentagon.posY end,
                    setFunc = function(value)
                        savedVars.pentagon.posY = value
                        ApplyLayoutSettings()
                    end,
                },
                {
                    type = "slider",
                    name = "Size (Scale)",
                    min = 0.5,
                    max = 2.5,
                    step = 0.05,
                    decimals = 2,
                    default = DEFAULTS.pentagon.scale,
                    getFunc = function() return savedVars.pentagon.scale end,
                    setFunc = function(value)
                        savedVars.pentagon.scale = value
                        ApplyLayoutSettings()
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Rectangular Gauge Settings",
            controls = {
                {
                    type = "dropdown",
                    name = "Gauge Fill Direction",
                    choices = { "Bottom to Top", "Top to Bottom", "Left to Right", "Right to Left" },
                    choicesValues = { "bottom_to_top", "top_to_bottom", "left_to_right", "right_to_left" },
                    default = DEFAULTS.gauge.direction,
                    getFunc = function() return savedVars.gauge.direction end,
                    setFunc = function(value)
                        savedVars.gauge.direction = value
                        RebuildGaugeLayout()
                        RefreshDisplay()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Attacker Counter",
                    tooltip = "Display the number of active attackers next to the gauge.",
                    default = DEFAULTS.gauge.showCounter,
                    getFunc = function() return savedVars.gauge.showCounter end,
                    setFunc = function(value)
                        savedVars.gauge.showCounter = value
                        RebuildGaugeLayout()
                        RefreshDisplay()
                    end,
                },
                {
                    type = "slider",
                    name = "Background Opacity",
                    min = 0,
                    max = 0.95,
                    step = 0.05,
                    decimals = 2,
                    default = DEFAULTS.gauge.bgAlpha,
                    getFunc = function() return savedVars.gauge.bgAlpha end,
                    setFunc = function(value)
                        savedVars.gauge.bgAlpha = value
                        RebuildGaugeLayout()
                    end,
                },
                {
                    type = "slider",
                    name = "Position X",
                    min = 0,
                    max = 1920,
                    step = 5,
                    default = DEFAULTS.gauge.posX,
                    getFunc = function() return savedVars.gauge.posX end,
                    setFunc = function(value)
                        savedVars.gauge.posX = value
                        ApplyLayoutSettings()
                    end,
                },
                {
                    type = "slider",
                    name = "Position Y",
                    min = 0,
                    max = 1080,
                    step = 5,
                    default = DEFAULTS.gauge.posY,
                    getFunc = function() return savedVars.gauge.posY end,
                    setFunc = function(value)
                        savedVars.gauge.posY = value
                        ApplyLayoutSettings()
                    end,
                },
                {
                    type = "slider",
                    name = "Size (Scale)",
                    min = 0.5,
                    max = 2.5,
                    step = 0.05,
                    decimals = 2,
                    default = DEFAULTS.gauge.scale,
                    getFunc = function() return savedVars.gauge.scale end,
                    setFunc = function(value)
                        savedVars.gauge.scale = value
                        ApplyLayoutSettings()
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "TTD Visual Effects",
            controls = {
                {
                    type = "checkbox",
                    name = "Glow Halo",
                    tooltip = "Add a soft translucent colored glow around TTD bars.",
                    default = DEFAULTS.effects.glowHalo,
                    getFunc = function() return savedVars.effects.glowHalo end,
                    setFunc = function(value)
                        savedVars.effects.glowHalo = value
                        ApplyTTDVisual(uiCache.ttdLevel, true)
                    end,
                },
                {
                    type = "slider",
                    name = "Glow Intensity",
                    tooltip = "Adjust the translucency strength of the Glow Halo.",
                    min = 0.3,
                    max = 2.0,
                    step = 0.1,
                    decimals = 1,
                    default = DEFAULTS.effects.glowIntensity,
                    getFunc = function() return savedVars.effects.glowIntensity end,
                    setFunc = function(value)
                        savedVars.effects.glowIntensity = value
                        ApplyTTDVisual(uiCache.ttdLevel, true)
                    end,
                },
                {
                    type = "checkbox",
                    name = "Bright Core",
                    tooltip = "Add a thin luminous inner core inside each TTD bar.",
                    default = DEFAULTS.effects.brightCore,
                    getFunc = function() return savedVars.effects.brightCore end,
                    setFunc = function(value)
                        savedVars.effects.brightCore = value
                        ApplyTTDVisual(uiCache.ttdLevel, true)
                    end,
                },
                {
                    type = "checkbox",
                    name = "Critical Red Flash",
                    tooltip = "Fast urgency flash when TTD drops to 1 second or less.",
                    default = DEFAULTS.effects.redFlash,
                    getFunc = function() return savedVars.effects.redFlash end,
                    setFunc = function(value)
                        savedVars.effects.redFlash = value
                        ApplyTTDVisual(uiCache.ttdLevel, true)
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Negate / Silence Alert",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Negate Alert",
                    tooltip = "Show an alert when standing inside an enemy Negate.",
                    default = DEFAULTS.negate.enabled,
                    getFunc = function() return savedVars.negate.enabled end,
                    setFunc = function(value)
                        savedVars.negate.enabled = value
                        if not value then
                            OnPlayerDead()
                        else
                            RefreshDisplay()
                        end
                    end,
                },
                {
                    type = "checkbox",
                    name = "Preview Negate Alert",
                    tooltip = "Show the Negate alert on screen while adjusting position and size.",
                    disabled = IsNegateDisabled,
                    getFunc = function() return isPreviewNegate end,
                    setFunc = function(value)
                        isPreviewNegate = value
                        RefreshDisplay()
                    end,
                },
                {
                    type = "slider",
                    name = "Position X",
                    min = 0,
                    max = 1920,
                    step = 5,
                    disabled = IsNegateDisabled,
                    default = DEFAULTS.negate.posX,
                    getFunc = function() return savedVars.negate.posX end,
                    setFunc = function(value)
                        savedVars.negate.posX = value
                        ApplyLayoutSettings()
                    end,
                },
                {
                    type = "slider",
                    name = "Position Y",
                    min = 0,
                    max = 1080,
                    step = 5,
                    disabled = IsNegateDisabled,
                    default = DEFAULTS.negate.posY,
                    getFunc = function() return savedVars.negate.posY end,
                    setFunc = function(value)
                        savedVars.negate.posY = value
                        ApplyLayoutSettings()
                    end,
                },
                {
                    type = "slider",
                    name = "Size (Scale)",
                    min = 0.5,
                    max = 2.5,
                    step = 0.05,
                    decimals = 2,
                    disabled = IsNegateDisabled,
                    default = DEFAULTS.negate.scale,
                    getFunc = function() return savedVars.negate.scale end,
                    setFunc = function(value)
                        savedVars.negate.scale = value
                        ApplyLayoutSettings()
                    end,
                },
            },
        },
    }

    LAM:RegisterOptionControls(ADDON_NAME .. "_Menu", optionsData)
end

-- ============================================================================
-- Initialisation
-- ============================================================================

local function OnPlayerActivated()
    AttachToGamepadHudScene()
    RefreshDisplay()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, DEFAULTS)

    CreateUI()
    AttachToGamepadHudScene()
    BuildSettingsMenu()

    -- Événements filtrés côté moteur pour limiter le coût CPU
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_DEAD, OnPlayerDead)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)