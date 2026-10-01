-- OneFrame GroupCombat: reduced, modified extraction of LibCombat v89 by Solinur.
-- Derived from UnitHandler/CheckUnit, onCombatEventDmgGrp, UpdateGrpStats and
-- UpdateStats. Artistic License 2.0; see licenses/LibCombat-LICENSE.md and NOTICE.md.
-- No LibCombat globals, callbacks or registration names are installed/replaced.
local A = OneFrame
local G = { units = {} }
A.GroupCombat = G
local damageResults = {
    [ACTION_RESULT_DAMAGE] = true, [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true, [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_BLOCKED_DAMAGE] = true, [ACTION_RESULT_DAMAGE_SHIELDED] = true,
}
local healResults = {
    [ACTION_RESULT_HEAL] = true, [ACTION_RESULT_CRITICAL_HEAL] = true,
    [ACTION_RESULT_HOT_TICK] = true, [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
}
local function isFriendly(unitType)
    return unitType == COMBAT_UNIT_TYPE_PLAYER or unitType == COMBAT_UNIT_TYPE_GROUP
        or unitType == COMBAT_UNIT_TYPE_PLAYER_PET
end
local function validId(id)
    return type(id) == "number" and id > 0
end
function G:Configure(enabled)
    if self.enabled ~= enabled then
        self.enabled = enabled
        self:Reset()
    end
end
function G:Reset()
    self.units = {}
    self.localStart, self.localEnd = nil, nil
end
function G:Unit(id)
    if not validId(id) then return nil end
    local unit = self.units[id]
    if not unit then
        unit = {damage = 0}
        self.units[id] = unit
    end
    return unit
end
function G:Event(_, result, isError, _, _, _, _, sourceType, _, targetType, hitValue,
                 _, _, _, sourceId, targetId)
    if not self.enabled then return end
    local damage, healing = damageResults[result], healResults[result]
    if isError or not (damage or healing) or type(hitValue) ~= "number"
        or hitValue ~= hitValue or hitValue <= 0 or hitValue == math.huge
        or not validId(targetId) then return end
    local sourceFriendly, targetFriendly = isFriendly(sourceType), isFriendly(targetType)
    local combat = A.CombatStats
    if not combat.started or combat.finished then
        -- Do not let ambient events or lingering DoTs start another encounter.
        local direct = damage and result ~= ACTION_RESULT_DOT_TICK
            and result ~= ACTION_RESULT_DOT_TICK_CRITICAL
        if IsUnitInCombat("player") or (direct and (sourceFriendly or targetFriendly)) then
            combat:State(true)
        else return end
    end
    local source, target = self:Unit(sourceId), self:Unit(targetId)
    if source and sourceFriendly then source.friendly = true end
    if targetFriendly then target.friendly = true end
    -- Anonymous group events identify only their target. Keep these totals until
    -- an outgoing/incoming event identifies that target; never assume every NPC
    -- is hostile. A later friendly classification removes it from the total.
    if damage then
        if sourceFriendly and not targetFriendly and target.friendly ~= true then target.friendly = false end
        if targetFriendly and source and not sourceFriendly and source.friendly ~= true then source.friendly = false end
    elseif sourceFriendly then
        target.friendly = true
    end
    if not damage or targetType == COMBAT_UNIT_TYPE_PLAYER_PET then return end
    local now = GetFrameTimeMilliseconds()
    if result ~= ACTION_RESULT_DAMAGE_SHIELDED
        and (sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET)
        and target.friendly == false then
        self.localStart, self.localEnd = self.localStart or now, now
    end
    -- Preserve LibCombat's group-event filters (including its outlier guard).
    if hitValue < 2 or hitValue > 200000 then return end
    target.damage = target.damage + hitValue
    target.first, target.last = target.first or now, now
end
function G:Value()
    if not self.enabled then return nil end
    local total, first, last = 0, nil, nil
    for _, unit in pairs(self.units) do
        if unit.friendly == false and unit.damage > 0 then
            total = total + unit.damage
            first = first and math.min(first, unit.first) or unit.first
            last = last and math.max(last, unit.last) or unit.last
        end
    end
    if not first then return nil end
    -- LibCombat uses the local outgoing-damage window. If a healer/tank has not
    -- dealt damage, use the observed group window instead of a one-second spike.
    local startTime, endTime = self.localStart or first, self.localEnd or last
    local seconds = math.max((endTime - startTime) / 1000, 1)
    return math.floor(total / seconds + 0.5)
end
