local O = OneCrosshair
O.CombatFeedback = {}
function O.CombatFeedback.Initialize(settings, crosshair)
    local pending, pendingWeapon, lastPulse = {}, nil, -1000
    EVENT_MANAGER:RegisterForEvent(O.name .. "Action", EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
        local now = GetFrameTimeMilliseconds()
        for id, expiry in pairs(pending) do if expiry < now then pending[id] = nil end end
        local id = GetSlotBoundId(slot)
        if id and id > 0 then pending[id] = now + 1500 end
        if slot <= ACTION_BAR_FIRST_NORMAL_SLOT_INDEX then pendingWeapon = now + 1500 end
    end)
    EVENT_MANAGER:RegisterForEvent(O.name .. "Feedback", EVENT_COMBAT_EVENT,
        function(_, result, isError, _, _, actionType, _, sourceType, _, targetType,
            _, _, _, _, _, _, abilityId)
            if not settings.combatFeedback or isError or sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
            if targetType == COMBAT_UNIT_TYPE_NONE then return end
            local direct = result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE
                or result == ACTION_RESULT_DAMAGE_SHIELDED or result == ACTION_RESULT_BLOCKED_DAMAGE
            if not direct then return end -- excludes DoT, HoT, incoming, failed actions
            local now = GetFrameTimeMilliseconds()
            local weapon = actionType == ACTION_SLOT_TYPE_LIGHT_ATTACK or actionType == ACTION_SLOT_TYPE_HEAVY_ATTACK
            local ability = pending[abilityId] and pending[abilityId] >= now
            if not ability and not (weapon and pendingWeapon and pendingWeapon >= now) then return end
            pending[abilityId] = nil -- consume once; do not pulse for multi-hit ticks
            if weapon then pendingWeapon = nil end
            if now - lastPulse < 130 then return end
            lastPulse = now
            O.CrosshairController.Pulse(crosshair, now)
        end)
    EVENT_MANAGER:AddFilterForEvent(O.name .. "Feedback", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end
