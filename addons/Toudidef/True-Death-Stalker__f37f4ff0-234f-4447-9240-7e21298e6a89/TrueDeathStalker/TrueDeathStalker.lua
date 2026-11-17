-- ============================================================================
-- True Death Stalker
-- Suivi PvP en temps réel (Gamepad uniquement, optimisé mémoire console)
-- ============================================================================

local ADDON_NAME = "TrueDeathStalker"
local ADDON_DISPLAY_NAME = "True Death Stalker"
local SAVED_VARS_NAME = "TrueDeathStalkerSavedVariables"
local SAVED_VARS_VERSION = 2

-- Paramètres des fenêtres glissantes et tampons pré-alloués
local LONG_WINDOW_MS = 3000     -- Fenêtre longue de référence (3s)
local SHORT_WINDOW_MS = 1000    -- Fenêtre courte pour capter les bursts instantanés (1s)
local UPDATE_INTERVAL_MS = 50   -- Fréquence de mise à jour (20 Hz) uniquement quand actif
local MAX_DAMAGE_SAMPLES = 256  -- Taille fixe du tampon circulaire de dégâts
local MAX_HEAL_SAMPLES = 128    -- Taille fixe du tampon circulaire de soins
local MAX_ATTACKERS = 128       -- Nombre maximal d'attaquants suivis simultanément

-- Signe de rotation pour SetTransformRotationZ (-1 ou 1 selon l'orientation en jeu)
local ROTATION_SIGN = -1

-- Taille de base du conteneur du pentagone (en pixels avant scale)
local BASE_BOX_SIZE = 190
local CENTER_XY = 95

-- Couleurs (alpha à 1.0 sur les arêtes pour éviter les surbrillances aux jonctions)
local COLOR_PENTAGON_EDGE = { 0.88, 0.88, 0.94, 1.0 }
local COLOR_TTD_GREEN = { 0.15, 0.92, 0.28, 1.0 }
local COLOR_TTD_YELLOW = { 1.00, 0.84, 0.12, 1.0 }
local COLOR_TTD_RED = { 0.98, 0.16, 0.16, 1.0 }
local COLOR_CORE_WHITE = { 1.00, 0.98, 0.95, 0.90 }

-- Valeurs par défaut des SavedVariables (coordonnées toujours >= 0)
local DEFAULTS = {
    pentagon = {
        posX = 865,
        posY = 445,
        scale = 1.0,
    },
    negate = {
        posX = 890,
        posY = 516,
        scale = 1.0,
    },
    ttd = {
        minDivisorSec = 0.45, -- Plus bas = réagit plus vite sur les bursts soudains
    },
    effects = {
        glowHalo = true,
        brightCore = true,
        pulse = true,
        redFlash = true,
    },
}

-- ============================================================================
-- Table des IDs de Negate ennemie (à compléter ultérieurement)
-- ============================================================================
local NEGATE_ABILITY_IDS = {
    -- [ID_NEGATE_BASE] = true,
    -- [ID_SUPPRESSION_FIELD] = true,
    -- [ID_ABSORPTION_FIELD] = true,
}

-- ============================================================================
-- État interne et tampons pré-alloués (zéro allocation en combat)
-- ============================================================================
local savedVars = nil
local isUpdateRunning = false
local isPreviewPentagon = false
local isPreviewNegate = false
local isNegateActive = false
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
    activeCount = 0,
    pentagonVisible = false,
    negateVisible = false,
}

-- Références aux contrôles UI (créés une seule fois au chargement)
local pentagonWindow = nil
local pentagonCountLabel = nil
local pentagonEdges = {}
local pentagonSegments = {}
local pentagonGlowOuter = {}
local pentagonGlowInner = {}
local pentagonCores = {}
local pentagonFragment = nil

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

-- Met à jour la couleur, la visibilité et les effets des segments selon le niveau (0..3)
local function ApplyTTDVisual(level, forceColorRefresh)
    local fx = savedVars and savedVars.effects or DEFAULTS.effects

    if uiCache.ttdLevel ~= level or forceColorRefresh then
        uiCache.ttdLevel = level

        local color = COLOR_TTD_GREEN
        local activeCount = 0

        if level == 1 then
            -- TTD <= 3s : 1 segment inférieur (vert)
            activeCount = 1
            color = COLOR_TTD_GREEN
        elseif level == 2 then
            -- TTD <= 2s : 3 segments (inférieur + 2 côtés inférieurs, jaune)
            activeCount = 3
            color = COLOR_TTD_YELLOW
        elseif level == 3 then
            -- TTD <= 1s : 5 segments (tous les côtés, rouge)
            activeCount = 5
            color = COLOR_TTD_RED
        end

        uiCache.activeCount = activeCount
        local r, g, b = color[1], color[2], color[3]

        for i = 1, 5 do
            local isActive = (i <= activeCount)
            local seg = pentagonSegments[i]
            local glowIn = pentagonGlowInner[i]
            local glowOut = pentagonGlowOuter[i]
            local core = pentagonCores[i]

            if isActive then
                seg:SetColor(r, g, b, 1.0)
                seg:SetHidden(false)

                if fx.glowHalo then
                    glowIn:SetColor(r, g, b, 0.30)
                    glowOut:SetColor(r, g, b, 0.13)
                    glowIn:SetHidden(false)
                    glowOut:SetHidden(false)
                else
                    glowIn:SetHidden(true)
                    glowOut:SetHidden(true)
                end

                if fx.brightCore then
                    core:SetHidden(false)
                else
                    core:SetHidden(true)
                end
            else
                seg:SetHidden(true)
                glowIn:SetHidden(true)
                glowOut:SetHidden(true)
                core:SetHidden(true)
            end
        end
    end
end

-- Animation légère sans allocation (pulse / flash rouge) sur les segments actifs
local function UpdateSegmentEffects(nowMs)
    if uiCache.activeCount <= 0 then
        return
    end

    local fx = savedVars and savedVars.effects or DEFAULTS.effects
    local segAlpha = 1.0
    local glowMultiplier = 1.0

    if uiCache.ttdLevel == 3 and fx.redFlash then
        -- Flash rapide d'urgence au palier rouge (<= 1s)
        local wave = 0.5 + 0.5 * math.sin(nowMs * 0.018)
        segAlpha = 0.45 + 0.55 * wave
        glowMultiplier = 0.40 + 0.90 * wave
    elseif fx.pulse then
        -- Pulsation douce accélérée selon le danger
        local speed = (uiCache.ttdLevel == 2) and 0.009 or 0.0055
        local wave = 0.5 + 0.5 * math.sin(nowMs * speed)
        segAlpha = 0.65 + 0.35 * wave
        glowMultiplier = 0.55 + 0.65 * wave
    end

    for i = 1, uiCache.activeCount do
        pentagonSegments[i]:SetAlpha(segAlpha)
        if fx.glowHalo then
            pentagonGlowInner[i]:SetAlpha(0.30 * glowMultiplier)
            pentagonGlowOuter[i]:SetAlpha(0.13 * glowMultiplier)
        end
        if fx.brightCore then
            pentagonCores[i]:SetAlpha(0.90 * segAlpha)
        end
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

    if negateWindow then
        negateWindow:ClearAnchors()
        negateWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.negate.posX, savedVars.negate.posY)
        negateWindow:SetScale(savedVars.negate.scale)
    end
end

-- Met à jour la visibilité et les valeurs en mode normal ou aperçu
local function RefreshDisplay()
    if not pentagonWindow then
        return
    end

    if not IsGamepadOnlyActive() then
        if uiCache.pentagonVisible then
            pentagonWindow:SetHidden(true)
            uiCache.pentagonVisible = false
        end
        if negateWindow and uiCache.negateVisible then
            negateWindow:SetHidden(true)
            uiCache.negateVisible = false
        end
        return
    end

    local nowMs = GetGameTimeMilliseconds()

    -- Gestion de l'alerte Negate
    if negateWindow then
        local showNegate = isPreviewNegate or isNegateActive
        if uiCache.negateVisible ~= showNegate then
            negateWindow:SetHidden(not showNegate)
            uiCache.negateVisible = showNegate
        end
    end

    -- Mode aperçu pour le positionnement dans LibAddonMenu
    if isPreviewPentagon then
        if not uiCache.pentagonVisible then
            pentagonWindow:SetHidden(false)
            uiCache.pentagonVisible = true
        end
        if uiCache.countText ~= "5" then
            pentagonCountLabel:SetText("5")
            uiCache.countText = "5"
        end
        ApplyTTDVisual(3, false)
        UpdateSegmentEffects(nowMs)
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

    if not hasActivity then
        if uiCache.pentagonVisible then
            pentagonWindow:SetHidden(true)
            uiCache.pentagonVisible = false
        end
        ApplyTTDVisual(0, false)

        -- Arrêt du timer si plus aucune donnée active et hors combat
        if isUpdateRunning and not IsUnitInCombat("player") then
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Tick")
            isUpdateRunning = false
        end
        return
    end

    -- Affichage du pentagone
    if not uiCache.pentagonVisible then
        pentagonWindow:SetHidden(false)
        uiCache.pentagonVisible = true
    end

    -- Mise à jour du compteur (0..99 ou 99+) sans allocation
    local displayText = (attackerCount > 99) and COUNT_OVERFLOW_STR or COUNT_STRINGS[attackerCount]
    if uiCache.countText ~= displayText then
        pentagonCountLabel:SetText(displayText)
        uiCache.countText = displayText
    end

    -- Calcul du TTD avec diviseur adaptatif pour éviter le retard sur les bursts soudains
    local minDiv = (savedVars and savedVars.ttd and savedVars.ttd.minDivisorSec) or DEFAULTS.ttd.minDivisorSec
    local elapsedShortSec = ((nowMs - oldestShortDmgTime) / 1000) + 0.15
    local elapsedLongSec = ((nowMs - oldestLongDmgTime) / 1000) + 0.15

    if elapsedShortSec < minDiv then elapsedShortSec = minDiv end
    if elapsedShortSec > 1.0 then elapsedShortSec = 1.0 end

    if elapsedLongSec < minDiv then elapsedLongSec = minDiv end
    if elapsedLongSec > 3.0 then elapsedLongSec = 3.0 end

    local netDpsShort = (shortDamage - shortHeal) / elapsedShortSec
    local netDpsLong = (longDamage - longHeal) / elapsedLongSec
    local netDps = (netDpsShort > netDpsLong) and netDpsShort or netDpsLong

    local ttdLevel = 0
    if netDps > 0 and longDamage > 0 then
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

    ApplyTTDVisual(ttdLevel, false)
    UpdateSegmentEffects(nowMs)
end

local function EnsureUpdateRunning()
    if not isUpdateRunning then
        isUpdateRunning = true
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Tick", UPDATE_INTERVAL_MS, RefreshDisplay)
    end
end

-- ============================================================================
-- Gestionnaires d'événements de combat
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
        -- Exclusion de soi-même, de son propre familier, du groupe et des mannequins
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

        -- Rafraîchissement immédiat sur le premier coup puis boucle à 50ms
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
    else
        RefreshDisplay()
    end
end

-- ============================================================================
-- Alerte Negate (commentée tant que les abilityId ne sont pas renseignés)
-- ============================================================================
--[[
local function OnEffectChanged(_, changeType, _, _, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or not NEGATE_ABILITY_IDS[abilityId] then
        return
    end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        isNegateActive = true
    elseif changeType == EFFECT_RESULT_FADED then
        isNegateActive = false
    end

    RefreshDisplay()
end
--]]

-- ============================================================================
-- Création unique des visuels au chargement
-- ============================================================================

local function CreateRotatedBar(parent, name, centerOffsetX, centerOffsetY, length, thickness, angleRad, color)
    local bar = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    bar:SetDimensions(length, thickness)
    bar:SetColor(color[1], color[2], color[3], color[4])
    bar:SetAnchor(CENTER, parent, TOPLEFT, CENTER_XY + centerOffsetX, CENTER_XY + centerOffsetY)
    bar:SetTransformNormalizedOriginPoint(0.5, 0.5)
    bar:SetTransformRotationZ(angleRad * ROTATION_SIGN)
    return bar
end

local function CreateUI()
    -- 1. Fenêtre principale du Pentagone + Segments TTD
    pentagonWindow = WINDOW_MANAGER:CreateTopLevelWindow("TrueDeathStalkerPentagonTLW")
    pentagonWindow:SetDimensions(BASE_BOX_SIZE, BASE_BOX_SIZE)
    pentagonWindow:SetMouseEnabled(false)
    pentagonWindow:SetMovable(false)
    pentagonWindow:SetClampedToScreen(true)
    pentagonWindow:SetHidden(true)

    -- Géométrie d'un pentagone régulier à base inférieure horizontale
    -- Longueur exacte d'onglet = 2 * R * sin(36°) + épaisseur * tan(36°)
    -- pour que les bords extérieurs se rejoignent proprement sans cornes aux angles
    local edgeRadius = 42
    local edgeThickness = 3.5
    local tan36 = math.tan(math.rad(36))
    local sin36 = math.sin(math.rad(36))
    local cos36 = math.cos(math.rad(36))

    local edgeApothem = edgeRadius * cos36
    local edgeLength = (2 * edgeRadius * sin36) + (edgeThickness * tan36)

    local edgeSpecs = {
        -- { angleMilieuDeg, angleBarreDeg }
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

        local edge = CreateRotatedBar(
            pentagonWindow,
            "TrueDeathStalkerEdge" .. i,
            mx, my,
            edgeLength, edgeThickness,
            barRad,
            COLOR_PENTAGON_EDGE
        )
        edge:SetDrawLayer(DL_CONTROLS)
        edge:SetDrawLevel(2)
        pentagonEdges[i] = edge
    end

    -- Segments TTD extérieurs + couches d'effets pré-créées
    local segApothem = edgeApothem + 14
    local segLength = (2 * edgeRadius * sin36) - 2

    for i = 1, 5 do
        local midRad = math.rad(edgeSpecs[i][1])
        local barRad = math.rad(edgeSpecs[i][2])
        local mx = segApothem * math.cos(midRad)
        local my = segApothem * math.sin(midRad)

        -- Halo externe doux
        local glowOut = CreateRotatedBar(
            pentagonWindow,
            "TrueDeathStalkerSegGlowOut" .. i,
            mx, my,
            segLength + 12, 16,
            barRad,
            COLOR_TTD_GREEN
        )
        glowOut:SetDrawLayer(DL_BACKGROUND)
        glowOut:SetDrawLevel(0)
        glowOut:SetHidden(true)
        pentagonGlowOuter[i] = glowOut

        -- Halo interne lumineux
        local glowIn = CreateRotatedBar(
            pentagonWindow,
            "TrueDeathStalkerSegGlowIn" .. i,
            mx, my,
            segLength + 6, 10,
            barRad,
            COLOR_TTD_GREEN
        )
        glowIn:SetDrawLayer(DL_BACKGROUND)
        glowIn:SetDrawLevel(1)
        glowIn:SetHidden(true)
        pentagonGlowInner[i] = glowIn

        -- Segment principal
        local seg = CreateRotatedBar(
            pentagonWindow,
            "TrueDeathStalkerSegment" .. i,
            mx, my,
            segLength, 5,
            barRad,
            COLOR_TTD_GREEN
        )
        seg:SetDrawLayer(DL_CONTROLS)
        seg:SetDrawLevel(3)
        seg:SetHidden(true)
        pentagonSegments[i] = seg

        -- Cœur fin lumineux
        local core = CreateRotatedBar(
            pentagonWindow,
            "TrueDeathStalkerSegCore" .. i,
            mx, my,
            segLength - 4, 1.5,
            barRad,
            COLOR_CORE_WHITE
        )
        core:SetDrawLayer(DL_CONTROLS)
        core:SetDrawLevel(4)
        core:SetHidden(true)
        pentagonCores[i] = core
    end

    -- Compteur de joueurs au centre du pentagone
    pentagonCountLabel = WINDOW_MANAGER:CreateControl("TrueDeathStalkerCountLabel", pentagonWindow, CT_LABEL)
    pentagonCountLabel:SetFont("ZoFontGamepad42")
    pentagonCountLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pentagonCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    pentagonCountLabel:SetColor(1, 1, 1, 1)
    pentagonCountLabel:SetAnchor(CENTER, pentagonWindow, TOPLEFT, CENTER_XY, CENTER_XY)
    pentagonCountLabel:SetText("0")

    -- 2. Fenêtre compacte de l'alerte Negate ("Negate" uniquement)
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

    ApplyLayoutSettings()
end

-- Attache les fragments uniquement à la scène gamepad_hud_scene
local function AttachToGamepadHudScene()
    if hudSceneHooked then
        return
    end

    local scene = SCENE_MANAGER:GetScene("gamepad_hud_scene")
    if not scene then
        return
    end

    hudSceneHooked = true

    pentagonFragment = ZO_HUDFadeSceneFragment:New(pentagonWindow)
    negateFragment = ZO_HUDFadeSceneFragment:New(negateWindow)

    -- Utilisation de ZO_PreHookHandler sur OnShow conformément aux règles console
    ZO_PreHookHandler(pentagonWindow, "OnShow", function()
        if not IsGamepadOnlyActive() or (not isPreviewPentagon and not uiCache.pentagonVisible) then
            return true
        end
        return false
    end)

    ZO_PreHookHandler(negateWindow, "OnShow", function()
        if not IsGamepadOnlyActive() or (not isPreviewNegate and not isNegateActive) then
            return true
        end
        return false
    end)

    scene:AddFragment(pentagonFragment)
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

    local optionsData = {
        {
            type = "description",
            text = "Real-time PvP incoming damage, Time-To-Death (TTD), attacker counter and enemy Negate alert (Gamepad HUD only).",
        },
        {
            type = "submenu",
            name = "Pentagon & TTD Indicator",
            controls = {
                {
                    type = "checkbox",
                    name = "Preview Pentagon",
                    tooltip = "Show a sample pentagon and TTD segments while adjusting position, size and effects.",
                    getFunc = function() return isPreviewPentagon end,
                    setFunc = function(value)
                        isPreviewPentagon = value
                        if value then
                            EnsureUpdateRunning()
                        end
                        RefreshDisplay()
                    end,
                },
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
                {
                    type = "slider",
                    name = "Burst Reactivity (Min Window Sec)",
                    tooltip = "Lower values make TTD bars react faster to sudden heavy bursts.",
                    min = 0.25,
                    max = 1.00,
                    step = 0.05,
                    decimals = 2,
                    default = DEFAULTS.ttd.minDivisorSec,
                    getFunc = function() return savedVars.ttd.minDivisorSec end,
                    setFunc = function(value)
                        savedVars.ttd.minDivisorSec = value
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
                    tooltip = "Add a soft colored glow around TTD bars.",
                    default = DEFAULTS.effects.glowHalo,
                    getFunc = function() return savedVars.effects.glowHalo end,
                    setFunc = function(value)
                        savedVars.effects.glowHalo = value
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
                    name = "Pulse Animation",
                    tooltip = "Smoothly pulse TTD bars based on danger level.",
                    default = DEFAULTS.effects.pulse,
                    getFunc = function() return savedVars.effects.pulse end,
                    setFunc = function(value)
                        savedVars.effects.pulse = value
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
                    type = "description",
                    text = "Negate detection is currently disabled until enemy Negate ability IDs are added.",
                },
                {
                    type = "checkbox",
                    name = "Preview Negate Alert",
                    tooltip = "Show the Negate alert on screen while adjusting position and size.",
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

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- À décommenter une fois NEGATE_ABILITY_IDS rempli :
    -- EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    -- EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)