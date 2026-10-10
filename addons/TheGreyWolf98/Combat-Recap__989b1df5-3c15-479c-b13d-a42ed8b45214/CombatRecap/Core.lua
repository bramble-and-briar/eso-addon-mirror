-- Combat Recap: bounded, API-independent encounter aggregation.
CombatRecap = CombatRecap or {}
local C = CombatRecap
C.VERSION = "1.0.1"
C.LIMITS = { history = 20, abilities = 256, targets = 64, effects = 128 }

local function entry(map, key, name, count, limit, fight)
    local e = map[key]
    if e then return e, count end
    if count >= limit then fight.truncated = true; return nil, count end
    e = { name = name, damage = 0, hits = 0, crits = 0, max = 0, dot = 0 }
    map[key] = e
    return e, count + 1
end

local function addHit(e, amount, crit, dot)
    if not e then return end
    e.damage = e.damage + amount; e.hits = e.hits + 1
    e.max = math.max(e.max, amount)
    if crit then e.crits = e.crits + 1 end
    if dot then e.dot = e.dot + amount end
end

function C.NewFight(now, meta)
    return {
        startMs = now, lastMs = now, timestamp = meta.timestamp,
        character = meta.character, zone = meta.zone,
        damage = 0, hits = 0, crits = 0, dot = 0, petDamage = 0,
        laDamage = 0, laHits = 0, haDamage = 0,
        abilities = {}, targets = {}, effects = {},
        abilityCount = 0, targetCount = 0, effectCount = 0,
        weave = { laInputs = 0, skills = 0, ultimates = 0, heavyInputs = 0,
            intervals = 0, single = 0, zero = 0, multiple = 0,
            excluded = 0, delaySum = 0, delaySquares = 0, delayCount = 0,
            gapLA = 0, gapHA = false },
    }
end

function C.RecordDamage(f, now, abilityKey, abilityName, targetKey, targetName, amount, crit, dot, pet, attack)
    if amount <= 0 then return end
    f.lastMs = math.max(f.lastMs, now)
    f.damage = f.damage + amount
    f.hits = f.hits + 1
    if crit then f.crits = f.crits + 1 end
    if dot then f.dot = f.dot + amount end
    if pet then f.petDamage = f.petDamage + amount end
    if attack == "light" then f.laDamage = f.laDamage + amount; f.laHits = f.laHits + 1 end
    if attack == "heavy" then f.haDamage = f.haDamage + amount end
    local a, t
    a, f.abilityCount = entry(f.abilities, abilityKey, abilityName, f.abilityCount, C.LIMITS.abilities, f)
    t, f.targetCount = entry(f.targets, targetKey, targetName, f.targetCount, C.LIMITS.targets, f)
    addHit(a, amount, crit, dot)
    addHit(t, amount, crit, dot)
end

-- Input observations, not a verdict about successful/missed attack execution.
function C.RecordInput(f, now, kind, durationMs)
    local w = f.weave
    if kind == "light" then
        w.laInputs = w.laInputs + 1; w.gapLA = w.gapLA + 1
    elseif kind == "heavy" then
        w.heavyInputs = w.heavyInputs + 1; w.gapHA = true
    elseif kind == "ultimate" then
        w.ultimates = w.ultimates + 1
        w.lastSkill = nil; w.gapLA = 0; w.gapHA = false
    elseif kind == "skill" then
        w.skills = w.skills + 1
        if w.lastSkill then
            local delta = now - w.lastSkill
            if delta >= 750 and delta <= 3000 and not w.gapHA and (w.lastDuration or 0) <= 1000 then
                w.intervals = w.intervals + 1
                if w.gapLA == 0 then w.zero = w.zero + 1
                elseif w.gapLA == 1 then w.single = w.single + 1
                else w.multiple = w.multiple + 1 end
                w.delaySum = w.delaySum + delta
                w.delaySquares = w.delaySquares + delta * delta
                w.delayCount = w.delayCount + 1
            else w.excluded = w.excluded + 1 end
        end
        w.lastSkill = now; w.lastDuration = durationMs or 0
        w.gapLA = 0; w.gapHA = false
    end
end

-- Effect instances keyed by effect slot. Union intervals prevent double-counting
-- simultaneous sources, refreshes and changing stacks of the same ability.
function C.EffectChange(f, now, slot, abilityId, name, kind, present)
    f.activeSlots = f.activeSlots or {}
    local old = f.activeSlots[slot]
    if old and (not present or old ~= abilityId) then
        local e = f.effects[old]
        if e then
            e.refs = math.max(0, (e.refs or 0) - 1)
            if e.refs == 0 and e.since then
                if #e.spans < 64 then e.spans[#e.spans + 1] = { e.since, now }
                else f.truncated = true end
                e.since = nil
            end
        end
        f.activeSlots[slot] = nil
    end
    if not present or f.activeSlots[slot] == abilityId then return end
    local e = f.effects[abilityId]
    if not e then
        if f.effectCount >= C.LIMITS.effects then f.truncated = true; return end
        e = { name = name, kind = kind, refs = 0, uptimeMs = 0, spans = {} }
        f.effects[abilityId] = e; f.effectCount = f.effectCount + 1
    end
    if e.refs == 0 then e.since = math.max(now, f.startMs) end
    e.refs = e.refs + 1
    f.activeSlots[slot] = abilityId
end

function C.FinishFight(f, reason)
    -- Damage-window timing: first to last personal damage. Includes gaps within
    -- that window; combat exit/grace delays do not dilute DPS.
    f.duration = math.max(1, (f.lastMs - f.startMs) / 1000)
    f.reason = reason
    local windowMs = math.max(0, f.lastMs - f.startMs)
    for _, e in pairs(f.effects) do
        for _, span in ipairs(e.spans) do
            e.uptimeMs = e.uptimeMs + math.max(0, math.min(span[2], f.lastMs) - math.max(span[1], f.startMs))
        end
        if e.since then e.uptimeMs = e.uptimeMs + math.max(0, f.lastMs - math.max(e.since, f.startMs)) end
        e.uptimeMs = math.min(windowMs, e.uptimeMs)
        e.refs = nil; e.since = nil; e.spans = nil
    end
    f.activeSlots = nil
    f.weave.lastSkill = nil; f.weave.lastDuration = nil
    f.weave.gapLA = nil; f.weave.gapHA = nil
    f.startMs = nil; f.lastMs = nil
    return f
end

function C.SaveFight(history, f)
    table.insert(history, 1, f)
    while #history > C.LIMITS.history do table.remove(history) end
end

function C.Sorted(map, field)
    local rows = {}
    for _, e in pairs(map or {}) do rows[#rows + 1] = e end
    table.sort(rows, function(a, b)
        if a[field] == b[field] then return a.name < b.name end
        return (a[field] or 0) > (b[field] or 0)
    end)
    return rows
end
