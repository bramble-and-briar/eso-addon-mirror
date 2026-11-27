-- Weaving (trigger "Weaving", 5.24.0): how well you weave light attacks between skills. One entry per skill you cast:
-- the time lost between the end of your previous skill and this one (the weave delay), whether a light attack went in
-- between and landed, and whether the skill was bash-cancelled; the fight's average delay with it.
--
-- Built from WeaveDelays 1.1.1 (WeaveDelayLog.lua / WeaveDelays.lua), read line by line; the same measure, so the
-- numbers match what its players know:
--   * presses: EVENT_ACTION_SLOT_ABILITY_USED -- slot 1 a light attack, slots 3-8 skills (ultimate included); slot 2
--     (heavy attack) only matters with "a heavy attack between skills isn't delay" (ours);
--   * a skill's end = its press + the longer of its cast / channel and the 1 s global cooldown. WeaveDelays reads the
--     length as GetAbilityCastInfo's 2nd and 3rd values; the game (abilitytooltips.lua) returns channeled, length -- the
--     2nd value is the length for casts and channels alike. Ours is the global cooldown bar's (Meditate, Fatecarver with
--     its Crux), DT.GlobalCooldown.CastMs;
--   * delay = this skill's press - the previous skill's end (the first skill has none);
--   * its light attack = the first light attack pressed since the previous skill. It landed when your light attack
--     hits or heals (EVENT_COMBAT_EVENT, slot type light attack, DAMAGE / CRITICAL_DAMAGE / HEAL / CRITICAL_HEAL) within
--     1 s of the press (1.6 s with "more latency tolerance"); ACTION_RESULT_QUEUED marks it queued. So each skill shows:
--     no light attack pressed ("M"), pressed but it vanished ("X"), queued but it never landed ("Q"), cancelled with a
--     bash ("B": Bash 21970, slot type block, damage, within 1 s of the skill) -- 0.1 s after the skill (settled);
--   * "only skills that went off": a press counts once the game reports that ability from you (not an error) within
--     the timeout + its cast;
--   * the average: per fight, each delay held to 1-1000 ms, a skill without a light attack counts 1000; it starts with
--     the fight's first light attack, and each one is counted once its light attack had the time to land. A fight keeps
--     the presses of the 5 s before it; presses up to 0.5 s after the last fight ended belong to that fight.
-- Weaving is about fitting as much as possible into each global cooldown (a skill, a light attack in the 0.2 s left,
-- a bash on top, which costs no global cooldown), so it only means something in a fight (Yarden). Out of combat nothing
-- is counted or shown changing: presses are only held for the 5 s window before a fight (the opener), hits are ignored
-- (WeaveDelays ignores them too), and after a fight the strip keeps that fight as it ended -- buffing up or a stray
-- skill doesn't push it off (WeaveDelays went on adding them).
-- Ours besides: switching a toggle off isn't a cast (no global cooldown -- Combat Metronome, Core/GlobalCooldown.lua),
-- so it isn't counted; and, as an option, a heavy attack between two skills starts the count again instead of being
-- delay (heavy-attack builds).
--
-- Pay for what you use: nothing is registered unless a shown tracker uses this trigger.

local DT = DebuffTracker
local W = DT.Weave
local U = DT.Util

local NS = "DebuffTracker5_Weave"
local SLOT_LA, SLOT_HEAVY, SLOT_FIRST_SKILL, SLOT_LAST_SKILL = 1, 2, 3, 8
W.GCD_MS = 1000
W.TIMEOUT_MS, W.TIMEOUT_HIGH_MS = 1000, 1600
W.MISSED_MS = 1000          -- the average counts a skill without a light attack as this
W.SETTLE_MS = 100           -- a skill's light attack is judged 0.1 s after it
W.PRE_COMBAT_MS = 5000
W.END_GRACE_MS = 500
W.BASH = 21970
local MAX_ACTIONS = 400     -- presses kept between fights
-- icons the game gets wrong for these (WeaveDelays' textureCache fixes): Crystal Fragments' proc, Assassin's Will
W.ICONS = {
    [114716] = "/esoui/art/icons/ability_sorcerer_thunderstomp_proc.dds",
    [61930] = "/esoui/art/icons/ability_rogue_058.dds",
}
local MAX_COMBOS = 80

local o = { timeout = W.TIMEOUT_MS, confirm = false, heavyBreaks = false }
local actions, pending, combos = {}, {}, {}
local byId = {}             -- combos by their skill press's id
local prevEnd, pendingLA, heavyBetween
local endMarker, endTime = -1, -1
local avgSum, avgCount, avgPending, avgFirstLA = 0, 0, {}, false
local seq = 0
local watching, inCombat = false, false
W.hidden = false            -- "/dt weave": hide / show the weaving trackers (WeaveDelays' key)

local function Now() return GetGameTimeMilliseconds() end
local function Changed() if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end end

------------------------------------------------------------------------------
-- The model
------------------------------------------------------------------------------

local function ResetAverage()
    avgSum, avgCount, avgPending, avgFirstLA = 0, 0, {}, false
end

local function SettleAverage(now)
    while avgPending[1] and now - avgPending[1].la.time > o.timeout do
        local c = table.remove(avgPending, 1)
        if c.la.confirmed then avgSum = avgSum + U.Clamp(c.delay, 1, 1000) else avgSum = avgSum + W.MISSED_MS end
        avgCount = avgCount + 1
    end
end

local function Track(a)
    if a.slot >= SLOT_FIRST_SKILL then
        local measured = prevEnd ~= nil and not (o.heavyBreaks and heavyBetween)
        local c = { id = a.id, skill = a, la = pendingLA, delay = measured and (a.time - prevEnd) or 0, measured = measured }
        combos[#combos + 1] = c
        byId[a.id] = c
        if #combos > MAX_COMBOS then
            local old = table.remove(combos, 1)
            byId[old.id] = nil
        end
        prevEnd = a.time + math.max(a.castMs or 0, W.GCD_MS)
        pendingLA, heavyBetween = nil, nil
        return c
    elseif a.slot == SLOT_LA then
        if not pendingLA then pendingLA = a end
    elseif a.slot == SLOT_HEAVY then
        heavyBetween = true
    end
    return nil
end

-- (only presses that belong to a fight: pressed in it, or in the 5 s before it once it started)
local function Rebuild()
    combos, byId = {}, {}
    prevEnd, pendingLA, heavyBetween = nil, nil, nil
    for _, a in ipairs(actions) do if a.fight then Track(a) end end
end

function W.Register(a)
    -- (a confirmed skill arrives after later presses: kept in time order, and the list rebuilt)
    local idx = #actions + 1
    while idx > 1 and actions[idx - 1].time > a.time do idx = idx - 1 end
    table.insert(actions, idx, a)
    if idx <= endMarker then endMarker = endMarker + 1 end
    if not a.fight then
        -- out of combat: held for the next fight's opener, nothing counted
    elseif idx == #actions then
        local c = Track(a)
        SettleAverage(a.time)
        if c and c.measured and avgFirstLA then
            if not c.la then avgSum, avgCount = avgSum + W.MISSED_MS, avgCount + 1
            else avgPending[#avgPending + 1] = c end
        end
        if a.slot == SLOT_LA then avgFirstLA = true end
    else
        Rebuild()
    end
    -- between fights only the last presses are kept (a fight keeps its 5 s before anyway)
    if not inCombat and #actions > MAX_ACTIONS then
        local drop = #actions - MAX_ACTIONS
        for _ = 1, drop do table.remove(actions, 1) end
        endMarker = math.max(-1, endMarker - drop)
    end
end

function W.StartCombat(now)
    now = now or Now()
    local cutoff = now - W.PRE_COMBAT_MS
    local keep = {}
    for i, a in ipairs(actions) do
        if i > endMarker and a.time >= cutoff and (endTime < 0 or a.time > endTime + W.END_GRACE_MS) then
            a.fight = true          -- the opener: part of this fight now
            keep[#keep + 1] = a
        end
    end
    actions = keep
    endMarker, endTime = -1, -1
    local p = {}
    for _, a in ipairs(pending) do if a.time >= cutoff then p[#p + 1] = a end end
    pending = p
    Rebuild()
    ResetAverage()
end

function W.EndCombat(now)
    endMarker = #actions
    endTime = now or Now()
end

function W.Reset()
    actions, pending = {}, {}
    endMarker, endTime = -1, -1
    Rebuild()
    ResetAverage()
    Changed()
end

-- the newest light attack press still waiting (within the timeout)
local function RecentLA(now)
    for i = #actions, 1, -1 do
        local a = actions[i]
        if now - a.time > o.timeout then return nil end
        if a.slot == SLOT_LA then return a end
    end
end

function W.OnSlotUsed(slot, now)
    slot = tonumber(slot) or 0
    if slot < SLOT_LA or slot > SLOT_LAST_SKILL then return end
    now = now or Now()
    seq = seq + 1
    local a = { id = seq, time = now, slot = slot, confirmed = false, queued = false, bashed = false, fight = inCombat }
    if slot >= SLOT_FIRST_SKILL then
        local bar = type(GetActiveHotbarCategory) == "function" and GetActiveHotbarCategory() or nil
        if type(IsSlotToggled) == "function" and IsSlotToggled(slot, bar) then return end     -- a toggle switched off
        local id = DT.GlobalCooldown.SlotAbility(slot, bar)
        if not id or id == 0 then return end
        a.abilityId = id
        a.castMs = DT.GlobalCooldown.CastMs(id)
        if o.confirm then pending[#pending + 1] = a; return end
    end
    W.Register(a)
    if inCombat then Changed() end
end

function W.LightAttackLanded(now)
    local a = RecentLA(now or Now())
    if a then a.confirmed = true; Changed() end
end

function W.LightAttackQueued(now)
    local a = RecentLA(now or Now())
    if a then a.queued = true end
end

function W.Bashed(now)
    now = now or Now()
    for i = #actions, 1, -1 do
        local a = actions[i]
        if now - a.time > o.timeout then return end
        if a.slot >= SLOT_FIRST_SKILL then a.bashed = true; Changed(); return end
    end
end

-- "only skills that went off": the game reported this ability from you
function W.SkillWentOff(abilityId, isError, now)
    now = now or Now()
    local i = 1
    while i <= #pending do
        local p = pending[i]
        if now - p.time > o.timeout + (p.castMs or 0) then
            table.remove(pending, i)
        elseif p.abilityId == abilityId then
            table.remove(pending, i)
            if not isError then W.Register(p); Changed() end
            return true
        else
            i = i + 1
        end
    end
    return false
end

function W.Average(now)
    SettleAverage(now or Now())
    if avgCount == 0 then return nil end
    return avgSum / avgCount
end

function W.Combos() return combos end

-- what a combo shows: delay (ms, held to 1..950; nil when no light attack landed), light attack "ok" / "missed" (not
-- pressed) / "vanished" / "queued" / "" (not judged yet), bashed
function W.Judge(c, now)
    local settled = now - c.skill.time > W.SETTLE_MS
    local la, state = c.la, ""
    if settled then
        if not la then state = "missed"
        elseif la.confirmed then state = "ok"
        elseif la.queued then state = "queued"
        else state = "vanished" end
    end
    local landed = la ~= nil and la.confirmed
    return state, settled, (landed and c.measured) and U.Clamp(c.delay, 1, 950) or nil
end

------------------------------------------------------------------------------
-- Entries
------------------------------------------------------------------------------

local function Letter(tr, state, bashed)
    if state == "ok" then return bashed and tr.weaveTextBashed or "" end
    if state == "missed" then return tr.weaveTextMissed end
    if state == "queued" then return tr.weaveTextQueued end
    if state == "vanished" then return tr.weaveTextVanished end
    return ""
end
W.Letter = Letter

local function Describe(c)
    local a = c.skill
    if not a.name then
        a.name = U.CleanName(GetAbilityName(a.abilityId) or "")
        a.icon = W.ICONS[a.abilityId] or GetAbilityIcon(a.abilityId)
    end
    return a.name, a.icon
end

local function Entry(tr, c, now, avg, pos)
    local state, settled, delay = W.Judge(c, now)
    local id = c.skill.abilityId
    local name, icon = Describe(c)
    return {
        key = "weave:" .. c.id, name = name, unitName = "", icon = icon,
        abilityId = id, start = 0, expire = 0, duration = 0, stacks = 0, active = true, mine = true, order = pos, fixedPos = pos,
        weave = true, weaveDelay = delay, weaveRaw = c.measured and c.delay or nil, weaveLight = state, weaveSettled = settled,
        weaveBash = c.skill.bashed == true, weaveMeasured = c.measured, weaveAvg = avg,
        weaveLetter = settled and Letter(tr, state, c.skill.bashed) or "",
        text = settled and Letter(tr, state, c.skill.bashed) or "",
    }
end

-- The last skills, oldest first (the newest at the end: the strip's right end). A Weave strip shows every slot,
-- empty ones too.
function W.States(tracker, out)
    if W.hidden then return out end
    -- nothing cast yet (this fight): nothing shown -- not an empty panel (Yarden: "???")
    if #combos == 0 then return out end
    local tr, ds = tracker.trigger, tracker.display
    local n = ds.type == "weave" and math.max(1, ds.columns * math.max(1, ds.weaveRows or 1)) or ds.maxShown
    local now = Now()
    local avg = W.Average(now)
    local first = math.max(1, #combos - n + 1)
    local shown = #combos - first + 1
    local pos = 0
    if ds.type == "weave" then
        for i = 1, n - shown do
            pos = pos + 1
            out[#out + 1] = { key = "weave:empty" .. i, name = "", unitName = "", start = 0, expire = 0, duration = 0, stacks = 0,
                active = false, weave = true, weaveEmpty = true, weaveLight = "", weaveAvg = avg, order = pos, fixedPos = pos, text = "" }
        end
    end
    for i = first, #combos do
        pos = pos + 1
        out[#out + 1] = Entry(tr, combos[i], now, avg, pos)
    end
    return out
end

-- The editor's sample: a strip from early (-50 ms) to late (450 ms), like WeaveDelays' colour test, with each letter.
function W.SampleStates(tracker, now)
    local tr, ds = tracker.trigger, tracker.display
    local n = ds.type == "weave" and math.max(1, ds.columns * math.max(1, ds.weaveRows or 1)) or math.min(ds.maxShown, 10)
    local ids = {}
    for slot = 3, 8 do
        local id = GetSlotBoundId(slot)
        if id and id ~= 0 then ids[#ids + 1] = id end
    end
    local out = {}
    for i = 1, n do
        local t = -50 + (i - 1) * (n > 1 and 500 / (n - 1) or 0)
        local state = "ok"
        if i == n - 2 then state = "missed" elseif i == n - 4 then state = "queued" elseif i == n - 6 then state = "vanished" end
        local bashed = i == 2
        local id = ids[(i - 1) % math.max(1, #ids) + 1]
        out[#out + 1] = {
            key = "weave:sample" .. i, name = id and U.CleanName(GetAbilityName(id) or "") or "", unitName = "",
            icon = id and (W.ICONS[id] or GetAbilityIcon(id)) or nil, start = 0, expire = 0, duration = 0, stacks = 0, active = true, mine = true,
            order = i, fixedPos = i, weave = true, weaveDelay = state == "ok" and U.Clamp(t, 1, 950) or nil, weaveRaw = t,
            weaveLight = state, weaveSettled = true, weaveBash = bashed, weaveMeasured = true, weaveAvg = 150, preview = true,
            weaveLetter = Letter(tr, state, bashed), text = Letter(tr, state, bashed),
        }
    end
    return out
end

------------------------------------------------------------------------------
-- Game events (only while a weaving tracker is shown)
------------------------------------------------------------------------------

-- the game's constants, read once when listening starts (not on every combat event)
local K = {}
local function ReadConstants()
    for _, name in ipairs({ "ACTION_SLOT_TYPE_LIGHT_ATTACK", "ACTION_SLOT_TYPE_BLOCK", "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE",
            "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_QUEUED" }) do
        K[name] = rawget(_G, name) or false
    end
end

local function OnCombat(_, result, isError, _, _, slotType, _, _, _, _, _, _, _, _, _, _, abilityId)
    if not inCombat then return end         -- (WeaveDelays: the same)
    local now = Now()
    local damage = result == K.ACTION_RESULT_DAMAGE or result == K.ACTION_RESULT_CRITICAL_DAMAGE
    if slotType == K.ACTION_SLOT_TYPE_LIGHT_ATTACK then
        if damage or result == K.ACTION_RESULT_HEAL or result == K.ACTION_RESULT_CRITICAL_HEAL then
            W.LightAttackLanded(now)
        elseif result == K.ACTION_RESULT_QUEUED then
            W.LightAttackQueued(now)
        end
    end
    if slotType == K.ACTION_SLOT_TYPE_BLOCK and abilityId == W.BASH and damage then
        W.Bashed(now)
    end
    if #pending > 0 then W.SkillWentOff(abilityId, isError, now) end
end

local function OnCombatState(_, combat)
    combat = combat == true
    if combat == inCombat then return end
    inCombat = combat
    if combat then W.StartCombat() else W.EndCombat() end
    -- hidden with the key: a strip shown only in fights comes back with the next fight (WeaveDelays' enterCombat)
    if combat and W.hidden then
        for _, t in ipairs(DT.Engine.trackers or {}) do
            if t.enabled and t.load.combat == "in" then
                for _, x in ipairs(DT.Triggers.AllTriggers(t)) do if x.trigger.type == "weave" then W.hidden = false end end
            end
        end
    end
    Changed()
end

local REGS = {
    { "_Slot", "EVENT_ACTION_SLOT_ABILITY_USED", function(_, slot) W.OnSlotUsed(slot) end },
    { "_Combat", "EVENT_COMBAT_EVENT", OnCombat, true },
    { "_State", "EVENT_PLAYER_COMBAT_STATE", OnCombatState },
}

local function Register()
    ReadConstants()
    for _, r in ipairs(REGS) do
        local ev = rawget(_G, r[2])
        if ev then
            EVENT_MANAGER:RegisterForEvent(NS .. r[1], ev, r[3])
            -- your own combat events only (WeaveDelays' filter): light attacks, bashes, skills going off
            if r[4] and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
                EVENT_MANAGER:AddFilterForEvent(NS .. r[1], ev, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
            end
        end
    end
end

local function Unregister()
    for _, r in ipairs(REGS) do
        local ev = rawget(_G, r[2])
        if ev then EVENT_MANAGER:UnregisterForEvent(NS .. r[1], ev) end
    end
end

-- tr = the first shown weaving tracker's trigger (its options), nil = none
function W.SetWatch(tr)
    if tr then
        o.timeout = tr.weaveLatency and W.TIMEOUT_HIGH_MS or W.TIMEOUT_MS
        o.confirm = tr.weaveConfirm == true
        local heavy = tr.weaveHeavyBreaks == true
        if heavy ~= o.heavyBreaks then o.heavyBreaks = heavy; Rebuild() end
    end
    local on = tr ~= nil
    if on == watching then return end
    watching = on
    if on then
        inCombat = IsUnitInCombat("player") == true
        Register()
    else
        Unregister()
    end
end
function W.IsWatched() return watching end

function W.Toggle()
    W.hidden = not W.hidden
    Changed()
    return W.hidden
end
