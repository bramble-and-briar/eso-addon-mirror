-- HUD adapter only. The bundled private LibCombat owns all combat calculations.
local meter = {}
SimpleGroupDPS_DamageMeter = meter
local LC = SimpleGroupDPSCombat
local MODEL = "LibCombat89"
local active, syncing, finishing, stopping, suspended = false, false, false, false, false
local currentFight, finishedFight, combatStartMS, lastDamageMS, completedAt
local damageEvents, personalEvents, otherEvents = 0, 0, 0
local last = {total = 0, dps = 0, durationMS = 0, measurementModel = MODEL}
local subscriptions = {}

local function now() return GetGameTimeMilliseconds() end
local function soloDead()
    return not IsUnitGrouped("player") and
        ((IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player"))
            or (IsUnitDead and IsUnitDead("player")))
end
local function startFight(fight, timeMS)
    if suspended or finishing or fight == finishedFight then return false end
    if active and currentFight == fight then return true end
    currentFight, active, completedAt = fight, true, nil
    combatStartMS = fight and fight.prepared and fight.combatstart or timeMS or now()
    lastDamageMS = nil
    damageEvents, personalEvents, otherEvents = 0, 0, 0
    last = {total = 0, dps = 0, durationMS = 0, measurementModel = MODEL}
    if meter.onStarted then meter.onStarted() end
    return true
end
local function readOffsets(fight)
    if not fight or not active then return end
    local base = fight.prepared and fight.combatstart or combatStartMS
    if type(base) ~= "number" then return end
    combatStartMS = base
    last.dpsStartOffsetMS = fight.dpsstart and fight.dpsstart - base
    last.dpsEndOffsetMS = fight.dpsend and fight.dpsend - base
    local first, final
    for _, unit in pairs(fight.units or {}) do
        if unit.bossId ~= nil and (unit.damageOutTotal or 0) > 0 then
            if unit.dpsstart then first = math.min(first or unit.dpsstart, unit.dpsstart) end
            if unit.dpsend then final = math.max(final or unit.dpsend, unit.dpsend) end
        end
    end
    last.bossStartOffsetMS = first and first - base
    last.bossEndOffsetMS = final and final - base
    last.bossClockFallback = first ~= nil and first == final
    -- Display combat duration independently of the library's damage/healing windows.
    -- LibCombat owns both boundaries; its final combatend excludes the summary delay.
    local ended = LC.data.inCombat == false and (fight.combatend or 0) > 0
    local endpoint = ended and fight.combatend or now()
    last.durationMS = math.max(0, endpoint - base)
end
local function onRecap(_, data)
    if suspended or finishing or (soloDead() and not stopping) then return end
    local fight = LC:GetMeterFight()
    if not startFight(fight, now()) then return end
    -- These fields are the library's final values, not locally recalculated rates.
    last.total = data.damageOutTotal or 0
    last.dps = data.DPSOut or 0
    last.dpsDurationMS = (data.dpstime or 0) * 1000
    last.groupTotal = data.damageOutTotalGroup
    last.groupDPS = data.groupDPSOut
    local boss = data.bossfight == true and (data.bossDamageTotal or 0) > 0
    last.bossTotal = boss and data.bossDamageTotal or nil
    last.bossDPS = boss and data.bossDPSOut or nil
    last.bossDurationMS = boss and (data.bossTime or 0) * 1000 or nil
    last.groupBossTotal = boss and data.bossDamageTotalGroup or nil
    last.groupBossDPS = boss and data.bossDPSOutGroup or nil
    last.bossClockModel = MODEL
    last.rawHealingTotal = data.overHealingOutTotal or 0
    last.effectiveHealingTotal = data.healingOutTotal or 0
    last.rawHPS = data.HPSAOut or data.OHPSOut or 0
    last.effectiveHPS = data.HPSOut or 0
    last.healingDurationMS = (data.hpstime or 0) * 1000
    last.measurementModel = MODEL
    readOffsets(fight)
end
local function sync()
    if syncing or finishing or suspended then return end
    syncing = true
    local ok, fight = pcall(function()
        if active and not stopping then LC:FinishUnenteredMeterFight(lastDamageMS) end
        return LC:RefreshMeterFight()
    end)
    syncing = false
    if not ok then error(fight) end
    readOffsets(fight)
end
local function finish()
    if not active or finishing then return end
    finishing = true
    if SimpleGroupDPS_CombatAnalysis then
        SimpleGroupDPS_CombatAnalysis:FinishFight(currentFight, now(), soloDead() and "Solo-Tod" or "Kampfende")
    end
    last.durationMS = last.durationMS or 0
    active, completedAt, finishedFight = false, now(), currentFight
    if meter.onFinished then meter.onFinished(last) end
    finishing = false
end
local function enableSubscriptions(enabled)
    for event, callback in pairs(subscriptions) do
        if enabled then LC:RegisterForCombatEvent("SimpleGroupDPSMeter", event, callback)
        else LC:UnregisterForCombatEvent("SimpleGroupDPSMeter", event) end
    end
end
function meter:CheckSoloDeath()
    if suspended or finishing or stopping or syncing or not soloDead() then return false end
    stopping = true
    sync()
    stopping = false
    finish()
    suspended = true
    enableSubscriptions(false)
    if SimpleGroupDPS_CombatAnalysis then SimpleGroupDPS_CombatAnalysis:SetPaused(true) end
    LC:DiscardMeterFight()
    return true
end
function meter:CheckRevival()
    -- PLAYER_ALIVE can arrive before the dead/reincarnating query updates, or be
    -- absent on a particular respawn path. The regular HUD tick also checks state.
    if not suspended or finishing or stopping or syncing or soloDead() then return false end
    LC:DiscardMeterFight()
    suspended, currentFight, finishedFight = false, nil, nil
    enableSubscriptions(true)
    if SimpleGroupDPS_CombatAnalysis then SimpleGroupDPS_CombatAnalysis:SetPaused(false) end
    return true
end
function meter:GetStats()
    self:CheckRevival()
    self:CheckSoloDeath()
    sync()
    return last
end
function meter:IsActive() return active end
function meter:ClearResult()
    if active then return false end
    last = {total = 0, dps = 0, durationMS = 0, measurementModel = MODEL}
    completedAt = nil
    return true
end
function meter:GetDiagnostics()
    local stats = self:GetStats()
    return {
        active = active, suspended = suspended, inCombat = IsUnitInCombat("player"),
        durationMS = stats.durationMS or 0, dps = stats.dps or 0, total = stats.total or 0,
        dpsDurationMS = stats.dpsDurationMS, dpsStartOffsetMS = stats.dpsStartOffsetMS, dpsEndOffsetMS = stats.dpsEndOffsetMS,
        bossTotal = stats.bossTotal, bossDPS = stats.bossDPS, bossDurationMS = stats.bossDurationMS,
        bossStartOffsetMS = stats.bossStartOffsetMS, bossEndOffsetMS = stats.bossEndOffsetMS,
        bossClockFallback = stats.bossClockFallback, measurementModel = MODEL,
        damageAgeMS = lastDamageMS and math.max(0, now() - lastDamageMS),
        finishedAgeMS = completedAt and math.max(0, now() - completedAt),
        damageEvents = damageEvents, personalEvents = personalEvents, otherEvents = otherEvents,
    }
end
function meter:Initialize(saved)
    -- Do not mix a retained result from the old collector with this engine.
    -- All layout and display preferences remain in the existing saved namespace.
    if type(saved) == "table" and saved.measurementModel == MODEL then
        last = {
            total = saved.damageTotal or 0, dps = saved.dps or 0, durationMS = saved.damageDurationMS or 0,
            dpsDurationMS = saved.dpsDurationMS, dpsStartOffsetMS = saved.dpsStartOffsetMS, dpsEndOffsetMS = saved.dpsEndOffsetMS,
            bossTotal = saved.bossDamageTotal, bossDPS = saved.bossDPS, bossDurationMS = saved.bossDurationMS,
            bossStartOffsetMS = saved.bossStartOffsetMS, bossEndOffsetMS = saved.bossEndOffsetMS,
            bossClockFallback = saved.bossClockFallback, bossClockModel = MODEL,
            groupTotal = saved.groupDamageTotal, groupDPS = saved.groupDPS,
            groupBossTotal = saved.groupBossDamageTotal, groupBossDPS = saved.groupBossDPS,
            rawHealingTotal = saved.rawHealingTotal, effectiveHealingTotal = saved.effectiveHealingTotal,
            rawHPS = saved.rawHPS, effectiveHPS = saved.effectiveHPS, healingDurationMS = saved.healingDurationMS,
            measurementModel = MODEL,
        }
    end
    subscriptions[SGD_LIBCOMBAT_EVENT_FIGHTRECAP] = onRecap
    subscriptions[SGD_LIBCOMBAT_EVENT_FIGHTSUMMARY] = function(_, fight)
        if suspended or finishing or fight == finishedFight then return end
        readOffsets(fight)
        finish()
    end
    subscriptions[SGD_LIBCOMBAT_EVENT_MESSAGES] = function(_, timeMS, message)
        if message == SGD_LIBCOMBAT_MESSAGE_COMBATSTART and not soloDead() then
            startFight(LC:GetMeterFight(), timeMS)
        end
    end
    local function damage(event, timeMS)
        if suspended or finishing then return end
        if soloDead() then self:CheckSoloDeath(); return end
        if not startFight(LC:GetMeterFight(), timeMS) then return end
        lastDamageMS = timeMS
        damageEvents = damageEvents + 1
        if event == SGD_LIBCOMBAT_EVENT_DAMAGE_OUT or event == SGD_LIBCOMBAT_EVENT_DAMAGE_SELF then personalEvents = personalEvents + 1
        else otherEvents = otherEvents + 1 end
    end
    subscriptions[SGD_LIBCOMBAT_EVENT_DAMAGE_OUT] = damage
    subscriptions[SGD_LIBCOMBAT_EVENT_DAMAGE_IN] = damage
    subscriptions[SGD_LIBCOMBAT_EVENT_DAMAGE_SELF] = damage
    enableSubscriptions(true)
    local function onDeath(_, tag, dead)
        if (tag == nil or tag == "player") and dead == false then self:CheckRevival(); return end
        if suspended or finishing then return end
        if (tag == nil or tag == "player") and dead ~= false and not IsUnitGrouped("player") then
            -- UNIT_DEATH_STATE_CHANGED can precede the separate dead-state query.
            stopping = true; sync(); stopping = false
            finish(); suspended = true
            enableSubscriptions(false)
            if SimpleGroupDPS_CombatAnalysis then SimpleGroupDPS_CombatAnalysis:SetPaused(true) end
            LC:DiscardMeterFight()
        end
    end
    if EVENT_PLAYER_DEAD then EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSLibCombatDeath", EVENT_PLAYER_DEAD, function() onDeath() end) end
    if EVENT_UNIT_DEATH_STATE_CHANGED then EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSLibCombatDeathState", EVENT_UNIT_DEATH_STATE_CHANGED, onDeath) end
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSLibCombatAlive", EVENT_PLAYER_ALIVE, function()
        self:CheckRevival()
    end)
    if EVENT_PLAYER_REINCARNATED then
        EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSLibCombatReincarnated", EVENT_PLAYER_REINCARNATED, function() self:CheckRevival() end)
    end
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSLibCombatActivated", EVENT_PLAYER_ACTIVATED, function() self:CheckRevival() end)
    self:CheckSoloDeath()
end
