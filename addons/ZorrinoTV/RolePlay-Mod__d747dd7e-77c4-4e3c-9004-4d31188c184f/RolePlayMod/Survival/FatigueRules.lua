if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Elapsed real time: 360-minute base / speed 1.5 = 240 minutes awake by default.
RolePlayNeeds.FatigueRules = {}
local F = RolePlayNeeds.FatigueRules
local LAYER = 'RPNExhaustionSprintLock'
F.active = false
F.state = 'Repos'
local function Maximum() return math.max(1, tonumber(RolePlayNeeds.settings.MAX_FATIGUE) or 2500) end
local function InCombat() return IsUnitInCombat('player') end
function F.GetRate(speed)
    local s = RolePlayNeeds.settings
    if not F.active or not RolePlayMod.Enabled('fatigue') or IsUnitDead('player') then F.state = 'En pause'; return 0 end
    local speedFactor = math.max(0.25,math.min(4,tonumber(RolePlayMod.Options().fatigueSpeed) or 1.5))
    local base = Maximum() * speedFactor / (math.max(1,tonumber(RolePlayMod.Options().fatigueMinutes) or 360) * 60)
    local combat = InCombat()
    if RolePlayNeeds.isResting and speed <= 1 and not combat then
        F.state = 'Repos assis'
        return -Maximum() / (180 * 60)
    end
    if speed > 1 or combat then RolePlayNeeds.isResting = false end
    -- There is no public sprint-state query. World-speed thresholds are estimates,
    -- configurable for speed bonuses. Mounted travel retains the baseline pace.
    local multiplier = 1
    if not IsMounted() then
        local runThreshold = tonumber(s.fatigueRunThreshold) or 350
        local sprintThreshold = math.max(runThreshold + 1, tonumber(s.fatigueSprintThreshold) or 700)
        if speed > sprintThreshold then multiplier = 3; F.state = 'Sprint estimé'
        elseif speed > runThreshold then multiplier = 1.25; F.state = 'Course'
        else F.state = speed > 1 and 'Marche' or 'Éveil' end
    else F.state = 'À monture' end
    if combat then multiplier = multiplier * 2; F.state = F.state .. ' · Combat' end
    return base * multiplier
end
function F.ReleaseSprintLock()
    if F.locked and RemoveActionLayerByName then RemoveActionLayerByName(LAYER) end
    F.locked = false
end
function F.SetActive(active)
    F.active = active
    if not active then F.ReleaseSprintLock() end
end
-- A public stop command can interrupt running without changing walk/run mode.
-- Sampled speed is only an estimate; mounts, swimming and airborne movement
-- must never be treated as an attempt to run on foot.
function F.WarnWalkOnly()
    local now = GetFrameTimeMilliseconds()
    if not F.lastRunWarning or now - F.lastRunWarning >= 5000 then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, 'Vous êtes épuisé : inclinez légèrement le stick gauche pour marcher.')
        F.lastRunWarning = now
    end
end
function F.EnforceWalkOnly(speed)
    F.walkBlocked = false
    local s = RolePlayNeeds.settings
    if not F.active or not RolePlayMod.Enabled('fatigue') or s.fatigueRunLock == false or F.runLockUnavailable then return false end
    if IsUnitDead('player') or IsMounted() then return false end
    if IsUnitSwimming and IsUnitSwimming('player') then return false end
    if IsUnitInAir and IsUnitInAir('player') then return false end
    local scene = SCENE_MANAGER:GetCurrentScene()
    local name = scene and scene:GetName() or ''
    if name ~= 'hud' and name ~= 'hudui' then return false end
    -- Compare fatigue points directly to avoid float noise at exactly 5%.
    if (tonumber(s.fatigueLv) or 0) <= Maximum() * 0.95 then return false end
    if (tonumber(speed) or 0) <= (tonumber(s.fatigueRunThreshold) or 350) then return false end
    if type(StopAllMovement) ~= 'function' then return false end
    local ok = pcall(StopAllMovement)
    if not ok then
        F.runLockUnavailable = true
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, 'Le blocage de course est indisponible dans ce client. Passez en marche manuellement.')
        return false
    end
    F.walkBlocked = true
    F.WarnWalkOnly()
    return true
end
function F.UpdateRestrictions()
    local s = RolePlayNeeds.settings
    local scene = SCENE_MANAGER:GetCurrentScene()
    local name = scene and scene:GetName() or ''
    local inWorld = name == 'hud' or name == 'hudui'
    local reserve = 1 - math.max(0, math.min(Maximum(), tonumber(s.fatigueLv) or 0)) / Maximum()
    local enabled = F.active and RolePlayMod.Enabled('fatigue') and not IsUnitDead('player')
    local mounted = IsMounted()
    local shouldLock = enabled and not mounted and inWorld and s.fatigueSprintLock ~= false and reserve < 0.30
    if shouldLock and not F.locked and PushActionLayerByName then
        PushActionLayerByName(LAYER)
        F.locked = true
    elseif not shouldLock then F.ReleaseSprintLock() end
    local critical = enabled and not mounted and (tonumber(s.fatigueLv) or 0) > Maximum() * 0.95
    if critical and not F.wasCritical and inWorld then
        F.WarnWalkOnly()
        F.wasCritical = true
    elseif not critical then F.wasCritical = false end
end
function F.Initialize()
    if F.initialized then return end
    F.initialized = true
    local s = RolePlayNeeds.settings
    if s.fatigueSprintLock == nil then s.fatigueSprintLock = true end
    if s.fatigueRunLock == nil then s.fatigueRunLock = true end
    -- Start accumulating only once the character is actually in the world.
    EVENT_MANAGER:RegisterForEvent('RPNFatigueActive', EVENT_PLAYER_ACTIVATED, function() F.SetActive(true) end)
    EVENT_MANAGER:RegisterForEvent('RPNFatigueInactive', EVENT_PLAYER_DEACTIVATED, function() F.SetActive(false) end)
    if EVENT_MOUNTED_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent('RPNFatigueMounted', EVENT_MOUNTED_STATE_CHANGED, F.UpdateRestrictions)
    end
    EVENT_MANAGER:RegisterForUpdate('RPNFatigueRestrictions', 250, F.UpdateRestrictions)
end
function F.AddOptions(options)
    options[#options + 1] = {type = 'header', name = 'Cycle de fatigue et épuisement'}
    options[#options + 1] = {type = 'description', text = 'Par défaut : 240 minutes au calme, 192 minutes de course normale ou 80 minutes de sprint continu estimé. La durée de base est divisée par la vitesse de fatigue. Le combat double le rythme. Debout : aucune récupération ; assis : récupération lente. Deux repos partiels à 50 % ; auberge : 100 % et remise à deux repos. Sous 5 %, la course détectée est interrompue : passez en marche pour repartir. La vitesse est estimée et peut nécessiter un ajustement selon vos bonus.'}
    options[#options + 1] = {type = 'checkbox', name = 'Bloquer le sprint sous 30 % de repos', default = true,
        tooltip = 'Blocage temporaire de l’action de sprint uniquement à pied. Le sprint de la monture reste disponible. Aucun raccourci enregistré n’est modifié. À confirmer dans le client ESO.',
        getFunc = function() return RolePlayNeeds.settings.fatigueSprintLock ~= false end,
        setFunc = function(value) RolePlayNeeds.settings.fatigueSprintLock = value; F.UpdateRestrictions() end}
    options[#options + 1] = {type = 'checkbox', name = 'Interrompre la course sous 5 % de repos', default = true,
        tooltip = 'Arrête le déplacement si sa vitesse dépasse le seuil de course. La marche reste possible. Sans effet à monture, dans les menus, en nageant ou en l’air. À confirmer en jeu ; désactivez cette option si la détection ne convient pas à vos bonus de vitesse.',
        getFunc = function() return RolePlayNeeds.settings.fatigueRunLock ~= false end,
        setFunc = function(value) RolePlayNeeds.settings.fatigueRunLock = value; F.walkBlocked = false; F.runLockUnavailable = false end}
    options[#options + 1] = {type = 'slider', name = 'Seuil de course estimée', min = 200, max = 650, step = 25, default = 350,
        tooltip = 'Vitesse mesurée en unités du monde par seconde. À ajuster si votre personnage possède des bonus de vitesse.',
        getFunc = function() return RolePlayNeeds.settings.fatigueRunThreshold or 350 end,
        setFunc = function(v) RolePlayNeeds.settings.fatigueRunThreshold = v end}
    options[#options + 1] = {type = 'slider', name = 'Seuil de sprint estimé', min = 400, max = 2000, step = 25, default = 700,
        tooltip = 'La détection du sprint est une estimation par la vitesse. Ce réglage ne change pas votre vitesse réelle.',
        getFunc = function() return RolePlayNeeds.settings.fatigueSprintThreshold or 700 end,
        setFunc = function(v) RolePlayNeeds.settings.fatigueSprintThreshold = v end}
end
