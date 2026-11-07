--[[
    LibFights - Stats
    Stat snapshots (every GetPlayerStat the client exposes, current/max resources and
    derived values such as crit % and armor mitigation %), plus per-fight stat
    tracking (min / max / average / timeline) while logging.
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Stats = {}
LF.Stats = Stats

local Clamp = Util.Clamp
Stats.current = nil      -- latest snapshot (used by the models in the hot path)

local validated = false
local function ValidateStats()
    if validated then return end
    validated = true
    local opt = STAT_BONUS_OPTION_APPLY_BONUS
    for _, def in ipairs(Const.STATS) do
        local ok, v = pcall(GetPlayerStat, def.id, opt)
        def.ok = ok and type(v) == "number"
    end
end

local function CritPct(rating)
    return (rating or 0) / Const.CRIT_RATING_PER_PERCENT
end
Stats.CritPctFromRating = CritPct

function Stats.ArmorMitigationFromResist(resist, penetration)
    local eff = (resist or 0) - (penetration or 0)
    return Clamp(eff / Const.RESIST_FOR_FULL, 0, Const.MAX_ARMOR_MITIGATION)
end

-- Full snapshot of the player's stats right now.
function Stats.GetSnapshot()
    ValidateStats()
    local s = {}
    local opt = STAT_BONUS_OPTION_APPLY_BONUS
    for _, def in ipairs(Const.STATS) do
        if def.ok then s[def.key] = GetPlayerStat(def.id, opt) end
    end
    local function power(pt, key)
        if pt == nil then return end
        local cur, max, effMax = GetUnitPower("player", pt)
        s[key .. "Current"] = cur or 0
        s[key .. "PowerMax"] = effMax or max or 0
    end
    power(Const.POWER_HEALTH, "health")
    power(Const.POWER_MAGICKA, "magicka")
    power(Const.POWER_STAMINA, "stamina")
    power(Const.POWER_ULTIMATE, "ultimate")

    -- Derived values
    s.spellCritPct = CritPct(s.spellCritical)
    s.weaponCritPct = CritPct(s.weaponCritical)
    s.spellResistPct = Stats.ArmorMitigationFromResist(s.spellResist) * 100
    s.physicalResistPct = Stats.ArmorMitigationFromResist(s.physicalResist) * 100
    s.timestampMs = Util.Now()
    Stats.current = s
    return s
end

function Stats.GetStat(key)
    local s = Stats.current or Stats.GetSnapshot()
    return s[key]
end

function Stats.GetStatLabel(key)
    return Const.STAT_LABEL[key] or key
end

-- Penetration that applies to a damage type
function Stats.GetPenetrationFor(damageType, s)
    s = s or Stats.current or Stats.GetSnapshot()
    local spell, phys = s.spellPenetration or 0, s.physicalPenetration or 0
    if Const.SPELL_DAMAGE_TYPES[damageType] then return spell end
    if Const.PHYSICAL_DAMAGE_TYPES[damageType] then return phys end
    return math.max(spell, phys)
end

-- Player's own armor mitigation vs a damage type (attacker penetration assumed 0)
function Stats.GetArmorMitigation(damageType, s)
    s = s or Stats.current
    if not s then return 0 end
    local resist
    if Const.SPELL_DAMAGE_TYPES[damageType] then
        resist = s.spellResist
    elseif Const.PHYSICAL_DAMAGE_TYPES[damageType] then
        resist = s.physicalResist
    else
        return 0   -- oblivion / generic / fall damage ignore resistances
    end
    return Stats.ArmorMitigationFromResist(resist)
end

-- ---------------------------------------------------------------------------
-- Per-fight tracking
-- ---------------------------------------------------------------------------
local MAX_SAMPLES = 900

function Stats.BeginTracking(fight)
    local snap = Stats.GetSnapshot()
    local st = { start = snap, last = snap, min = {}, max = {}, sum = {}, n = 0, samples = {}, sampleCount = 0 }
    fight.stats = st
    Stats.Sample(fight, snap)
end

function Stats.Sample(fight, snap)
    local st = fight.stats
    if not st then return end
    snap = snap or Stats.GetSnapshot()
    local t = snap.timestampMs - fight.startMs
    local changed, any = {}, false
    for k, v in pairs(snap) do
        if type(v) == "number" and k ~= "timestampMs" then
            if st.min[k] == nil or v < st.min[k] then st.min[k] = v end
            if st.max[k] == nil or v > st.max[k] then st.max[k] = v end
            st.sum[k] = (st.sum[k] or 0) + v
            if st.n == 0 or st.last[k] ~= v then changed[k] = v; any = true end
        end
    end
    st.n = st.n + 1
    if any and st.sampleCount < MAX_SAMPLES then
        changed.t = t
        st.sampleCount = st.sampleCount + 1
        st.samples[st.sampleCount] = changed
    end
    st.last = snap
    return snap
end

function Stats.FinishTracking(fight)
    local st = fight.stats
    if not st then return end
    st.avg = {}
    if st.n > 0 then
        for k, v in pairs(st.sum) do st.avg[k] = v / st.n end
    end
    st["end"] = st.last
end

-- Rebuild the full value of every stat at time t (ms from fight start) from the change log
function Stats.GetValuesAt(fight, tMs)
    local st = fight.stats
    if not st then return nil end
    local values = {}
    for i = 1, #st.samples do
        local s = st.samples[i]
        if s.t > tMs then break end
        for k, v in pairs(s) do if k ~= "t" then values[k] = v end end
    end
    return values
end
