local O = OneCrosshair
local H = { state = { active = false } }
O.HeavyChannel = H
local data = O.HeavyChannelData

-- Four reference-used result globals are absent from the public enum snapshot.
-- Compare only when present; never invent numeric result values.
local function Result(result, expected) return expected ~= nil and result == expected end
local function Enabled() return H.running and H.settings and H.settings.gcd end
local function Latency() return math.max(0, GetLatency and GetLatency() or 0) end
local function GCD(now)
    local remaining, duration = 0, 0
    for slot = 3, 8 do
        local r, d, global, kind = GetSlotCooldownInfo(slot)
        if global and (kind == ACTION_TYPE_ABILITY or kind == ACTION_TYPE_CRAFTED_ABILITY)
            and d > 0 and r > remaining then remaining, duration = r, d end
    end
    return remaining, duration, now + remaining - duration
end
function H.Stop(keepPending)
    if not keepPending then H.pending = nil end
    if not H.state.active then return end
    H.state.active = false
end
-- A full Heavy may finish by event before the next render update. Preserve
-- its owner for the one completion frame requested by the user; early ends
-- and all cancellation paths still stop immediately.
local function Finish(now, keepPending)
    if not keepPending then H.pending = nil end
    local s = H.state
    if s.active and s.kind == "heavy" and now >= s.endMs and not s.completionShown then return end
    H.Stop(keepPending)
end
local function Description(id, slot)
    local row = O.AbilityTimings.Refresh(id)
    if not row or row.excluded then return nil end
    return { abilityId = id, slot = slot, kind = slot == 2 and "heavy" or (row.channeled and "channel" or "cast"),
        channeled = row.channeled, duration = row.duration }
end
local function Start(timing, start, target)
    local now = GetFrameTimeMilliseconds()
    H.Stop()
    timing.startMs, timing.endMs = start, start + timing.duration
    if timing.endMs <= now then return end
    timing.active, timing.progress = true, O.Clamp((now-start)/timing.duration)
    timing.hotbar = GetActiveHotbarCategory()
    timing.target = target and target > 0 and target or nil
    H.state = timing
end
local function ConfirmPending(now, force, target)
    local p = H.pending
    if not p then return end
    if now >= p.expires then H.pending = nil; return end
    local r, d, start = GCD(now)
    -- Backdating/recency heuristic from the reference. Do not attribute a queued
    -- press to an unchanged old GCD; require a renewed timer or combat evidence.
    local renewed = r > p.remaining or (r > 0 and start >= p.recorded)
    if force or (renewed and r > 0 and start + Latency() >= now) then
        if r <= 0 or start + Latency() < now then start = now end
        if H.state.active and H.state.abilityId == p.abilityId and start <= H.state.startMs then return end
        if p.duration == 0 then H.Stop()
        else Start(p, start, target) end
    end
end
local function SlotUsed(_, slot)
    if not Enabled() or slot < 3 or slot > 8 then return end
    local id = GetSlotBoundId(slot)
    if GetSlotType(slot) == ACTION_TYPE_CRAFTED_ABILITY then id = GetAbilityIdForCraftedAbilityId(id) end
    if IsSlotToggled(slot) then
        if H.state.active and H.state.abilityId == id then H.Stop() end
        return
    end
    local now = GetFrameTimeMilliseconds()
    local p = Description(id, slot)
    if not p and H.state.active then p = { abilityId = id, duration = 0 } end
    if not p then H.pending = nil; return end
    p.recorded, p.remaining = now, GCD(now)
    p.expires = now + math.max(p.duration, 1000)
    H.pending = p
    ConfirmPending(now, false)
end
local function Cooldowns()
    if not Enabled() then return end
    local now, s = GetFrameTimeMilliseconds(), H.state
    if s.active and s.kind == "heavy" then
        local r, _, start = GCD(now)
        local hr, hd, global = GetSlotCooldownInfo(2)
        if r > 0 and start > s.startMs then
            -- Preserve a queued replacement while ending only the old owner.
            H.Stop(true)
        elseif now > s.startMs and not global and type(hr) == "number" and hr == hd then
            -- Reference release/cancel signature, including 0/0. Event-only:
            -- polling idle slot 2 would falsely cancel a charge every frame.
            Finish(now, true)
        end
    end
    ConfirmPending(now, false)
end
local function Combat(_, result, isError, _, _, actionType, _, sourceType, _, targetType,
    _, _, _, _, _, targetId, abilityId)
    if not Enabled() then return end
    local now, s = GetFrameTimeMilliseconds(), H.state
    local player = sourceType == COMBAT_UNIT_TYPE_PLAYER
    if targetType == COMBAT_UNIT_TYPE_PLAYER and data.controlLoss[result] then
        H.Stop(); return
    end
    if player and abilityId == data.dodgeId and Result(result, ACTION_RESULT_EFFECT_GAINED) then
        H.Stop(); return
    end
    if s.active and s.target and s.target == targetId
        and (result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP) then
        H.Stop(); return
    end
    local matches = s.active and s.abilityId == abilityId
    if matches and player and not s.target and targetType ~= COMBAT_UNIT_TYPE_PLAYER and targetId and targetId > 0 then
        s.target = targetId
    end
    if (player or targetType == COMBAT_UNIT_TYPE_PLAYER) and matches then
        if isError or data.failures[result] then
            -- A failed later repeat is not evidence that the accepted cast ended.
            local laterPress = H.pending and H.pending.abilityId == abilityId
                and H.pending.recorded > (s.recorded or s.startMs)
            if laterPress then H.pending = nil; return end
            if result == ACTION_RESULT_ABILITY_ON_COOLDOWN
                and now - (s.recorded or s.startMs) >= data.errorGraceMs then return end
            H.Stop(); return
        end
        if Result(result, ACTION_RESULT_EFFECT_FADED) and not data.beams[abilityId]
            and now > s.startMs and (not s.target or s.target == targetId or targetType == COMBAT_UNIT_TYPE_PLAYER) then
            Finish(now); return
        end
    end
    if not player then return end
    if isError or data.failures[result] then
        if H.pending and H.pending.abilityId == abilityId then H.pending = nil end
        return
    end
    local begin = Result(result, ACTION_RESULT_BEGIN) or Result(result, ACTION_RESULT_BEGIN_CHANNEL)
    if actionType == ACTION_SLOT_TYPE_HEAVY_ATTACK and begin and abilityId == GetSlotBoundId(2) then
        if matches and now < s.endMs then return end -- ignore duplicates, allow the next charge after completion
        local timing = Description(abilityId, 2)
        if timing then Start(timing, now, targetId) end
        return
    end
    if H.pending and H.pending.abilityId == abilityId
        and (begin or Result(result, ACTION_RESULT_EFFECT_GAINED)) then
        ConfirmPending(now, true, targetId)
    end
    -- Direct hit indicates release for non-channeled Heavy only. Channeled
    -- lightning/restoration ticks must not end their own charge prematurely.
    if matches and s.kind == "heavy" and not s.channeled and data.directHit[result] then
        Finish(now)
    end
end
local function Effect(_, change, _, _, _, beginTime, _, _, _, _, _, _, _, _, unitId, abilityId, source)
    local s = H.state
    if not Enabled() or not s.active or not data.beams[abilityId] or s.abilityId ~= abilityId
        or source ~= COMBAT_UNIT_TYPE_PLAYER then return end
    -- Bind a fade to this cast's effect epoch, not a previous beam on the target.
    if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        if beginTime * 1000 >= s.startMs and (not s.target or s.target == unitId) then
            s.effectBegin, s.effectTarget = beginTime, unitId
        end
    elseif change == EFFECT_RESULT_FADED and s.effectBegin == beginTime and s.effectTarget == unitId then
        H.Stop()
    end
end
function H.Initialize(settings)
    H.settings, H.running = settings, false
    local function Event(suffix, event, fn) EVENT_MANAGER:RegisterForEvent(O.name .. "Timing" .. suffix, event, fn) end
    Event("Slot", EVENT_ACTION_SLOT_ABILITY_USED, SlotUsed)
    Event("Cooldown", EVENT_ACTION_UPDATE_COOLDOWNS, Cooldowns)
    Event("Combat", EVENT_COMBAT_EVENT, Combat)
    Event("Effect", EVENT_EFFECT_CHANGED, Effect)
    Event("Swap", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function(_, changed)
        if changed then H.Stop() end
    end)
    Event("Lock", EVENT_WEAPON_PAIR_LOCK_CHANGED, function(_, locked)
        local s, now = H.state, GetFrameTimeMilliseconds()
        if not locked and s.active and s.kind == "cast" and now > s.startMs then H.Stop() end
    end)
    Event("Death", EVENT_PLAYER_DEAD, function() H.Stop() end)
    Event("Mount", EVENT_MOUNTED_STATE_CHANGED, function(_, mounted)
        if mounted then H.Stop() end
    end)
    Event("Activate", EVENT_PLAYER_ACTIVATED, function() H.running = true end)
    Event("Deactivate", EVENT_PLAYER_DEACTIVATED, function()
        H.running = false; H.Stop()
    end)
end
function H.Read(enabled, now, showCompletion)
    -- Retain the existing optional provider seam for contract tests/integrations.
    if H.provider then
        if not enabled then return nil end
        local timing = H.provider.Read(now)
        if not timing or not timing.active or timing.endMs <= timing.startMs or now >= timing.endMs then return nil end
        return O.Clamp((now - timing.startMs) / (timing.endMs - timing.startMs))
    end
    if not enabled then H.Stop(); return nil end
    if not H.running then return nil end
    if IsUnitDead("player") then H.Stop()
    elseif IsBlockActive() then H.Stop()
    elseif IsMounted() or ArePlayerWeaponsSheathed() then H.Stop()
    else
        if H.pending then ConfirmPending(now, false) end
        local s = H.state
        if s.active then
            if s.hotbar ~= GetActiveHotbarCategory() then H.Stop()
            elseif s.kind == "heavy" and s.abilityId ~= GetSlotBoundId(2) then H.Stop()
            elseif now >= s.endMs then
                if s.kind == "heavy" and showCompletion ~= false and not s.completionShown then
                    s.completionShown, s.progress = true, 1
                    return 1 -- one observed frame, never extend the timing interval
                end
                H.Stop(true)
            else
                s.progress = O.Clamp((now - s.startMs) / s.duration)
                -- Same capped ping-zone heuristic as normal GCD. A short cast
                -- cannot cue LA before the underlying global cooldown allows it.
                if s.kind ~= "heavy" then
                    s.ready = s.ready or math.max(s.endMs - now, (GCD(now))) <= math.min(Latency(), 150)
                end
                return s.progress, s.ready
            end
        end
    end
    return nil
end

function H.Presentation(progress, ready)
    if progress == nil then return nil end
    if ready or progress >= 1 then return 1, O.GCD.readyColor, 1 end
    return progress, O.GCD.idleColor, 1
end
