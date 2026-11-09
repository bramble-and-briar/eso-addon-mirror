-- Lethal PVP Insights - Real Death Recap
-- While switched on (Settings, off by default) and in a PvP area it remembers the damage you take. When you die it shows the
-- 5 sources (skill + player) that hurt you most in that fight and the last 10 hits before death.
local PDI = PVPDataInsight
local Recap = {}
PDI.Recap = Recap

local EM = EVENT_MANAGER
local NS = PDI.name .. "_Recap"
local KEEP_MS = 120000          -- keep 2 minutes of damage taken
local MAX_ENTRIES = 800
local FIGHT_GAP_MS = 2000       -- hits up to this long before "in combat" started belong to the fight
local TOP_N, LAST_N = 5, 10

local DAMAGE = {}
for _, k in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK",
                     "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
                     "ACTION_RESULT_KILLING_BLOW", "ACTION_RESULT_FALL_DAMAGE", "ACTION_RESULT_PRECISE_DAMAGE",
                     "ACTION_RESULT_WRECKING_DAMAGE" }) do
    local r = _G[k]
    if r then DAMAGE[r] = k end
end
local CRIT = {}
for _, k in ipairs({ "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK_CRITICAL" }) do
    if _G[k] then CRIT[_G[k]] = true end
end

-- DAMAGE_SHIELDED: an attack your damage shield absorbed - it names the attacker's skill, like Combat Metrics
-- ("hits you with X for 0 (Absorbed: N)"); listed with the absorbed amount
local hits, fightStart, registered = {}, nil, false

local function nowMs() return GetGameTimeMilliseconds() end

function Recap:IsOn()
    return PDI.sv and PDI.sv.settings and PDI.sv.settings.deathRecap == true
end

local function OnDamage(_, result, isError, abilityName, _, _, sourceName, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
    if isError or not DAMAGE[result] or (hitValue or 0) <= 0 then return end
    if not PDI.InPvPArea() then return end      -- PvP areas only (Cyrodiil, Imperial City, Battlegrounds)
    local now = nowMs()
    local src = PDI.CleanName(sourceName)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then src = nil end     -- yourself (fall damage, own effects)
    local skill = PDI.CleanName(abilityName)
    if (not skill or skill == "") and abilityId and abilityId > 0 then skill = PDI.CleanName(GetAbilityName(abilityId)) end
    hits[#hits + 1] = {
        t = now, src = src, skill = skill or "?", id = abilityId, v = hitValue,
        crit = CRIT[result] or nil, kb = (result == ACTION_RESULT_KILLING_BLOW) or nil,
        shield = (result == ACTION_RESULT_DAMAGE_SHIELDED) or nil, block = (result == ACTION_RESULT_BLOCKED_DAMAGE) or nil,
    }
    -- forget what is older than KEEP_MS (and never keep more than MAX_ENTRIES)
    local cut = now - KEEP_MS
    local first = 1
    while hits[first] and (hits[first].t < cut or #hits - first + 1 > MAX_ENTRIES) do first = first + 1 end
    if first > 1 then
        local keep = {}
        for i = first, #hits do keep[#keep + 1] = hits[i] end
        hits = keep
    end
end

local function whoText(src)
    if not src then return "|c999999you / environment|r" end
    local acct = PDI.Data:GetAccount(src)
    return acct and (acct .. " |c999999" .. src .. "|r") or src
end

-- The recap of the fight that just ended in death
function Recap:Build()
    local now = nowMs()
    local from = fightStart and (fightStart - FIGHT_GAP_MS) or (now - 60000)
    local fight = {}
    for _, h in ipairs(hits) do if h.t >= from then fight[#fight + 1] = h end end
    if #fight == 0 then return nil end
    local total, by, order, absorbed = 0, {}, {}, 0
    for _, h in ipairs(fight) do
        total = total + h.v
        local key = (h.skill or "?") .. "|" .. (h.src or "")
        local e = by[key]
        if not e then e = { skill = h.skill, src = h.src, id = h.id, v = 0, n = 0, abs = 0 }; by[key] = e; order[#order + 1] = e end
        e.v = e.v + h.v; e.n = e.n + 1
        if h.shield then e.abs = e.abs + h.v; absorbed = absorbed + h.v end
    end
    -- top 5: an attack's absorbed part counts with it (Molten Whip 7k to health + 3k absorbed = 10k), but a skill
    -- that never reached your health (only absorbed hits, e.g. Calculated Defense) is left out; the last 10 keep all
    local ranked = {}
    for _, e in ipairs(order) do if e.v > e.abs then ranked[#ranked + 1] = e end end
    table.sort(ranked, function(a, b) return a.v > b.v end)
    local rankedTotal = 0
    for _, e in ipairs(ranked) do rankedTotal = rankedTotal + e.v end
    local top = {}
    for i = 1, math.min(TOP_N, #ranked) do
        local e = ranked[i]
        local skill = e.skill
        if e.abs > 0 then skill = string.format("%s |c66CCFF(%s absorbed)|r", skill, PDI.Num and PDI.Num(e.abs) or e.abs) end
        top[#top + 1] = { skill = skill, who = whoText(e.src), id = e.id, v = e.v, n = e.n,
                          pct = rankedTotal > 0 and math.floor(100 * e.v / rankedTotal + 0.5) or 0 }
    end
    local last = {}
    for i = math.max(1, #fight - LAST_N + 1), #fight do
        local h = fight[i]
        local note = h.kb and " |cFF6655killing blow|r" or (h.crit and " |cFFCC66crit|r" or "")
            .. (h.shield and " |c66CCFF(absorbed by shield)|r" or "") .. (h.block and " |c999999(blocked)|r" or "")
        last[#last + 1] = { tm = string.format("-%.1fs", math.max(0, now - h.t) / 1000), skill = h.skill,
                            who = whoText(h.src), id = h.id, v = h.v, note = note }
    end
    local killer
    for i = #fight, 1, -1 do if fight[i].kb or fight[i].src then killer = whoText(fight[i].src); break end end
    return { t = PDI.Now(), total = total, absorbed = absorbed, hits = #fight, secs = (fight[#fight].t - fight[1].t) / 1000,
             killer = killer, top = top, last = last }
end

local function OnDead()
    if not Recap:IsOn() then return end
    if not PDI.InPvPArea() then hits, fightStart = {}, nil; return end
    local r = Recap:Build()
    hits, fightStart = {}, nil
    if not r then return end
    Recap.last = r
    PDI.sv.lastRecap = r
    zo_callLater(function() if PDI.UI and PDI.UI.ShowRecap then PDI.UI:ShowRecap(r) end end, 600)
end

local function OnCombatState(_, inCombat)
    if inCombat then fightStart = nowMs() end
end

function Recap:Register(on)
    if on == registered then return end
    registered = on
    if on then
        EM:RegisterForEvent(NS, EVENT_COMBAT_EVENT, OnDamage)
        EM:AddFilterForEvent(NS, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        EM:RegisterForEvent(NS .. "Dead", EVENT_PLAYER_DEAD, OnDead)
        EM:RegisterForEvent(NS .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        fightStart = IsUnitInCombat and IsUnitInCombat("player") and nowMs() or nil
    else
        EM:UnregisterForEvent(NS, EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(NS .. "Dead", EVENT_PLAYER_DEAD)
        EM:UnregisterForEvent(NS .. "Combat", EVENT_PLAYER_COMBAT_STATE)
        hits, fightStart = {}, nil
    end
end

-- Settings checkbox
function Recap:SetOn(on)
    PDI.sv.settings.deathRecap = on and true or false
    self:Register(self:IsOn())
end

function Recap:Init()
    self.last = PDI.sv.lastRecap
    self:Register(self:IsOn())
end

-- for tests
Recap._OnDamage, Recap._OnDead, Recap._OnCombatState = OnDamage, OnDead, OnCombatState
