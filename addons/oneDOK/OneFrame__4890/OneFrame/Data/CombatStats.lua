local A = OneFrame
local C = { damage = 0, healing = 0, retained = {}, retention = 300000 }
A.CombatStats = C
local damageResults = {
    [ACTION_RESULT_DAMAGE] = true, [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true, [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
}
local healResults = {
    [ACTION_RESULT_HEAL] = true, [ACTION_RESULT_CRITICAL_HEAL] = true,
    [ACTION_RESULT_HOT_TICK] = true, [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
}
function C:Reset()
    self.retained = {}
    A.GroupCombat:Reset()
    self.damage, self.healing, self.started, self.finished = 0, 0, nil, nil
end
function C:State(inCombat)
    if inCombat then
        if not self.started or self.finished then
            self:Reset()
            self.started = GetFrameTimeMilliseconds()
        end
    elseif self.started and not self.finished then
        self.finished = GetFrameTimeMilliseconds()
    end
    self:Timer(inCombat or self.finished ~= nil)
end
function C:Timer(active)
    EVENT_MANAGER:UnregisterForUpdate(A.name .. "Stats")
    if active and self.listening then
        EVENT_MANAGER:RegisterForUpdate(A.name .. "Stats", 500, function()
            A.Frames:UpdateStats()
            if self.finished and GetFrameTimeMilliseconds() - self.finished >= self.retention then
                EVENT_MANAGER:UnregisterForUpdate(A.name .. "Stats")
                self.retained = {}
            end
        end)
    end
    if A.Frames then A.Frames:UpdateStats() end
end
function C:Event(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceId, targetId, ...)
    A.GroupCombat:Event(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceId, targetId, ...)
    -- Never map sourceName/sourceUnitId to a remote group member: that stream is incomplete.
    if isError or (sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_GROUP)
        or not hitValue or hitValue <= 0 then return end
    local kind = damageResults[result] and "damage" or (healResults[result] and "healing")
    if not kind then return end
    -- The first attack can arrive before EVENT_PLAYER_COMBAT_STATE.
    if (not self.started or self.finished) and (kind == "damage" or IsUnitInCombat("player")) then
        self:State(true)
    end
    if self.started and not self.finished then
        if sourceType == COMBAT_UNIT_TYPE_PLAYER then self[kind] = self[kind] + hitValue end
    end
end
function C:Values(tag)
    if self.finished and GetFrameTimeMilliseconds() - self.finished >= self.retention then return nil, nil end
    if not DoesUnitExist(tag) or not IsUnitOnline(tag) then return nil, nil end
    local identity = GetUnitDisplayName(tag) .. ":" .. GetUnitName(tag)
    local cached = self.retained[tag]
    if not A.sv.hodor then cached = nil; self.retained[tag] = nil end
    if cached and cached.identity ~= identity then self.retained[tag] = nil; cached = nil end
    local dps, hps = A.SharedStats:Values(tag)
    if AreUnitsEqual(tag, "player") and self.started then
        local seconds = math.max(1, ((self.finished or GetFrameTimeMilliseconds()) - self.started) / 1000)
        dps = dps ~= nil and dps or (self.finished and cached and cached.dps) or self.damage / seconds
        hps = hps ~= nil and hps or (self.finished and cached and cached.hps) or self.healing / seconds
    end
    if self.finished and cached then
        dps = dps ~= nil and dps or cached.dps
        hps = hps ~= nil and hps or cached.hps
    end
    if dps ~= nil or hps ~= nil then self.retained[tag] = {identity=identity, dps=dps, hps=hps} end
    return dps, hps
end
function C:Configure()
    A.SharedStats:Configure()
    A.GroupCombat:Configure(A.active and A.sv.groupDps and GetGroupSize() > 0)
    local wanted = A.active and (GetGroupSize() > 0 or A.sv.dps or A.sv.hps)
    if wanted == self.listening then return end
    self.listening = wanted
    self:Reset()
    local ns = A.name .. "Combat"
    EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(ns, EVENT_PLAYER_COMBAT_STATE)
    if wanted then
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, function(...) self:Event(...) end)
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_PLAYER_COMBAT_STATE, function(_, combat) self:State(combat) end)
        self:State(IsUnitInCombat("player"))
    else
        self:Timer(false)
    end
end
function C:ResetShared()
    self.retained = {}
    A.SharedStats:Reset(true)
end
function C:Ultimate(tag)
    return A.SharedStats:Ultimate(tag)
end

function C:GroupDPS()
    return A.GroupCombat:Value()
end
