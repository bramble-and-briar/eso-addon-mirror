--------------------------------------------------------------------------------
-- EVENT HANDLERS MODULE
--------------------------------------------------------------------------------
-- This module handles all game event registrations and related logic

local MS = Meterskull

--------------------------------------------------------------------------------
-- RENDER HELPERS
--------------------------------------------------------------------------------
local function RenderAllModules(initial)
    for _, mod in pairs(MS.modules) do
        mod:Render(initial)
    end
end

-- Render tick disable state tracking for penetration module
local targetCooldownDuration = 1000
local penDisableTimestamp = 0

local function ResumeRenderTickForPen()
    penDisableTimestamp = penDisableTimestamp + 1
    local mod = MS.modules.penskull
    if not mod then return end
    mod.renderPaused = false
    mod:UpdateRenderTick()
end

local function DisableRenderTickForPen()
    local mod = MS.modules.penskull
    if not mod or not MS.db.sharedSettings.showPenskull or IsUnitDead("player") then return end
    mod.renderPaused = true
    penDisableTimestamp = penDisableTimestamp + 1
    local myTimestamp = penDisableTimestamp
    mod:UpdateRenderTick()
    zo_callLater(function()
        -- Only re-enable if no newer disable was issued
        if myTimestamp ~= penDisableTimestamp then return end
        ResumeRenderTickForPen()
    end, targetCooldownDuration)
end

--------------------------------------------------------------------------------
-- PLAYER DEATH/ALIVE EVENTS
--------------------------------------------------------------------------------
local function RegisterDeathCheckEvents()
    local function CheckPlayerDeathStatus()
        local playerIsDead = IsUnitDead("player")
        if playerIsDead then
            MS.CancelCombatHideCooldown()
            -- Invalidate pending target cooldowns before updating visibility.
            penDisableTimestamp = penDisableTimestamp + 1
            if MS.modules.penskull then MS.modules.penskull.renderPaused = false end
        end
        for _, mod in pairs(MS.modules) do
            local showKey = "show"..string.gsub(mod.name,"^%l",string.upper)
            local shouldShow = MS.db.sharedSettings[showKey]
            mod:ToggleVisibility(shouldShow)
        end
    end

    EVENT_MANAGER:RegisterForEvent(MS.name .. "DeathCheck", EVENT_PLAYER_ALIVE, CheckPlayerDeathStatus)
    EVENT_MANAGER:RegisterForEvent(MS.name .. "DeathCheck", EVENT_PLAYER_DEAD, CheckPlayerDeathStatus)
end

--------------------------------------------------------------------------------
-- WEAPON SWAP EVENT
--------------------------------------------------------------------------------
local function RegisterWeaponSwapEvent()
    EVENT_MANAGER:RegisterForEvent(MS.name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
        RenderAllModules(true)
    end)
end

--------------------------------------------------------------------------------
-- COMBAT STATE EVENT
--------------------------------------------------------------------------------
local combatHideDelay = 5000
local combatHideUpdateName = MS.name .. "CombatHideCooldown"

function MS.CancelCombatHideCooldown()
    MS.combatHideUntil = nil
    EVENT_MANAGER:UnregisterForUpdate(combatHideUpdateName)
end

local function RegisterCombatStateEvent()
    EVENT_MANAGER:RegisterForEvent(MS.name .. "CombatState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        MS.CancelCombatHideCooldown()
        if not MS.db.sharedSettings.combatOnly then return end

        if not inCombat and not IsUnitDead("player") then
            MS.combatHideUntil = GetGameTimeMilliseconds() + combatHideDelay
            EVENT_MANAGER:RegisterForUpdate(combatHideUpdateName, combatHideDelay, function()
                MS.CancelCombatHideCooldown()
                if _G.Meterskull_UpdateUIVisibility then
                    _G.Meterskull_UpdateUIVisibility()
                end
            end)
        end
        if _G.Meterskull_UpdateUIVisibility then _G.Meterskull_UpdateUIVisibility() end
    end)
end

--------------------------------------------------------------------------------
-- TARGET CHANGE EVENT
--------------------------------------------------------------------------------
local function RegisterTargetChangeEvent()
    EVENT_MANAGER:RegisterForEvent(MS.name, EVENT_RETICLE_TARGET_CHANGED, function()
        if MS.modules.critskull then MS.modules.critskull:Render() end
        if (not DoesUnitExist('reticleover') or IsUnitPlayer('reticleover')) and IsUnitInCombat('player') then
            DisableRenderTickForPen()
        else
            if MS.modules.penskull and MS.modules.penskull.renderPaused then
                ResumeRenderTickForPen()
            end
            if MS.modules.penskull then MS.modules.penskull:Render() end
        end
    end)
end

--------------------------------------------------------------------------------
-- BLOCK STATE EVENT
--------------------------------------------------------------------------------
local function RegisterBlockStateEvent()
    local function GetVisualBlockState()
        local currentTime = GetGameTimeMilliseconds()
        local isDodging = currentTime <= MS.blockTracking.dodgeStartTime + 600
        
        if isDodging then
            return false
        end
        
        return MS.IsReallyBlocking()
    end
    
    local wasApiBlocking = IsBlockActive()
    local wasVisualBlocking = GetVisualBlockState()
    
    EVENT_MANAGER:RegisterForUpdate(MS.name .. "BlockCheck", 100, function()
        local nowApiBlocking = IsBlockActive()
        local nowVisualBlocking = GetVisualBlockState()
        
        if (nowApiBlocking ~= wasApiBlocking) or (nowVisualBlocking ~= wasVisualBlocking) then
            if MS.modules.magskull then MS.modules.magskull:Render() end
            if MS.modules.stamskull then MS.modules.stamskull:Render() end
            if MS.modules.critresiskull then MS.modules.critresiskull:Render() end
        end
        
        wasApiBlocking = nowApiBlocking
        wasVisualBlocking = nowVisualBlocking
    end)
end

--------------------------------------------------------------------------------
-- DODGE ROLL EVENT
--------------------------------------------------------------------------------
local function RegisterDodgeEvent()
    EVENT_MANAGER:RegisterForEvent(MS.name .. "DodgeDetection", EVENT_COMBAT_EVENT, function(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
        if abilityId == 28549 then
            MS.blockTracking.dodgeStartTime = GetGameTimeMilliseconds()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(MS.name .. "DodgeDetection", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:AddFilterForEvent(MS.name .. "DodgeDetection", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
    EVENT_MANAGER:AddFilterForEvent(MS.name .. "DodgeDetection", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 28549)
end

--------------------------------------------------------------------------------
-- SHIELD WALL EVENT
--------------------------------------------------------------------------------
local function RegisterShieldWallEvent()
    EVENT_MANAGER:RegisterForEvent(MS.name .. "ShieldWall", EVENT_EFFECT_CHANGED, function(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)
        if changeType == EFFECT_RESULT_GAINED and (abilityId == 83272 or abilityId == 83292 or abilityId == 83310) then
            MS.blockTracking.shieldWallEndTime = GetGameTimeMilliseconds() + (endTime - beginTime) * 1000
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(MS.name .. "ShieldWall", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end

--------------------------------------------------------------------------------
-- SPRINT EVENT
--------------------------------------------------------------------------------
local function RegisterSprintEvent()
    local lastStaminaRecovery = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
    
    EVENT_MANAGER:RegisterForUpdate(MS.name .. "SprintCheck", 50, function()
        local currentStaminaRecovery = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
        
        if currentStaminaRecovery ~= lastStaminaRecovery then
            if MS.modules.stamskull then MS.modules.stamskull:Render() end
            if MS.modules.magskull then MS.modules.magskull:Render() end
        end
        
        lastStaminaRecovery = currentStaminaRecovery
    end)
end

--------------------------------------------------------------------------------
-- MAIN EVENT REGISTRATION
--------------------------------------------------------------------------------
-- Register all game events (called after modules are initialized)
function MS.RegisterGameEvents()
    RegisterDeathCheckEvents()
    RegisterCombatStateEvent()
    RegisterWeaponSwapEvent()
    RegisterTargetChangeEvent()
    RegisterBlockStateEvent()
    RegisterDodgeEvent()
    RegisterShieldWallEvent()
    RegisterSprintEvent()
end
