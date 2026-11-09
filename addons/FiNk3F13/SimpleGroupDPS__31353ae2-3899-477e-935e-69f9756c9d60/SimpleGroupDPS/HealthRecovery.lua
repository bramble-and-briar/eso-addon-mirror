-- Independent implementation of BattleScrolls combat/health_recovery.lua accounting
-- (ef6d762d48998fa91e302d99fafce334568a3845). No BattleScrolls state is read.
local recovery = {}
SimpleGroupDPS_HealthRecovery = recovery
local active, alive, lastMS, regen, raw, positive, knownHealing, health, maximum
local initialized = false

local function readRegen()
    if GetPlayerStat and STAT_HEALTH_REGEN_COMBAT ~= nil and STAT_BONUS_OPTION_APPLY_BONUS ~= nil then
        return GetPlayerStat(STAT_HEALTH_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS) or 0
    end
    return 0
end

local function readHealth()
    if GetUnitPower and COMBAT_MECHANIC_FLAGS_HEALTH ~= nil then
        local value, cap = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_HEALTH)
        health, maximum = value or 0, cap or 0
    else health, maximum = 0, 0 end
end

local function advance(now)
    if active and now > lastMS then
        if alive then raw = raw + math.max(0, regen) * (now - lastMS) / 2000 end
        lastMS = now
    end
end

function recovery:Start(now)
    active, alive = true, not (IsUnitDead and IsUnitDead('player'))
    lastMS, regen, raw, positive, knownHealing = now, readRegen(), 0, 0, 0
    readHealth()
end

function recovery:Stop() active = false end

function recovery:GetTotals()
    if not active then return 0, 0 end
    advance(GetGameTimeMilliseconds())
    local rounded = math.floor(raw + 0.5)
    return rounded, math.min(rounded, math.max(0, positive - knownHealing))
end

function recovery:OnHealing(value)
    if active and value > 0 then knownHealing = knownHealing + value end
end

function recovery:OnHealth(value, cap)
    if not active then return end
    if value > health and cap == maximum and alive and not (IsUnitDead and IsUnitDead('player')) then
        positive = positive + value - health
    end
    health, maximum = value, cap
end

function recovery:OnStats()
    if not active then return end
    advance(GetGameTimeMilliseconds())
    regen = readRegen()
end

function recovery:OnDeath(dead)
    if not active then return end
    advance(GetGameTimeMilliseconds())
    alive = not dead
    readHealth()
end

function recovery:Initialize()
    if initialized then return end
    initialized = true
    if EVENT_POWER_UPDATE and COMBAT_MECHANIC_FLAGS_HEALTH ~= nil then
        EVENT_MANAGER:RegisterForEvent('SimpleGroupDPSRecoveryPower', EVENT_POWER_UPDATE,
            function(_, tag, _, powerType, value, cap)
                if tag == 'player' and powerType == COMBAT_MECHANIC_FLAGS_HEALTH then self:OnHealth(value, cap) end
            end)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG and REGISTER_FILTER_POWER_TYPE then
            EVENT_MANAGER:AddFilterForEvent('SimpleGroupDPSRecoveryPower', EVENT_POWER_UPDATE,
                REGISTER_FILTER_UNIT_TAG, 'player', REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)
        end
    end
    if EVENT_STATS_UPDATED then
        EVENT_MANAGER:RegisterForEvent('SimpleGroupDPSRecoveryStats', EVENT_STATS_UPDATED, function() self:OnStats() end)
    end
    if EVENT_PLAYER_DEAD then
        EVENT_MANAGER:RegisterForEvent('SimpleGroupDPSRecoveryDead', EVENT_PLAYER_DEAD, function() self:OnDeath(true) end)
    end
    if EVENT_PLAYER_ALIVE then
        EVENT_MANAGER:RegisterForEvent('SimpleGroupDPSRecoveryAlive', EVENT_PLAYER_ALIVE, function() self:OnDeath(false) end)
    end
end
