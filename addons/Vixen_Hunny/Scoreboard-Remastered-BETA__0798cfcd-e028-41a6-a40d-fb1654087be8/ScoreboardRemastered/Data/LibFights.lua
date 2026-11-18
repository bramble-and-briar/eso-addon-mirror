-- LibFights integration (https://github.com/0xsint/LibFights).
--
-- LibFights logs nothing until Start_Logging() is called, and splits combat
-- into separate fights. For each battleground match this module:
--   * starts logging when the match begins, unless something else already has.
--     Only logging we started is stopped again.
--   * collects every fight that ends during the match (FIGHT_ENDED), plus the
--     fight still running at each snapshot (GetCurrentFight).
--   * sums those fights into per-player data for the scoreboard:
--       you       -> the full FightSummary, added up across fights
--       everyone  -> damage you dealt them (f:GetTargets()), damage they dealt
--                    you (f:GetSources()), healing you gave them (f.healTargets)
--   Other players' own stats come from the combat ledger (FightTracker.lua).
--   * keeps your death recaps (DEATH callback) and a list of the match's fights.
local SBR = ScoreboardRemastered
local LFI = { weStarted = false }
SBR.LibFights = LFI

local MAX_DEATHS = 20
local RECAP_HITS = 6
local TOP_ABILITIES = 8

-- Fields summed across fights for the local player: our key -> FightSummary key.
local SUMMARY_FIELDS = {
    damageDone = "damage", healingDone = "healing", damageTaken = "damageTaken", healingTaken = "healingTaken",
    killingBlows = "killingBlows", deaths = "deaths", interrupts = "interruptsOut", interrupted = "interruptsIn",
    ccApplied = "ccOut", ccTaken = "ccIn", damageShielded = "shield", mitigated = "mitigated",
    overheal = "overheal", selfHealing = "selfHealing", hits = "hits", crits = "crits",
    lightAttacks = "lightAttacks", heavyAttacks = "heavyAttacks", skillCasts = "skillCasts",
    ultimates = "ultimates", weaves = "weaves", barSwaps = "barSwaps",
    enemyShieldAbsorbed = "damageShielded", -- your damage soaked by enemy shields
}

local function Lib()
    local lf = _G.LibFights
    if type(lf) == "table" and type(lf.GetCurrentFight) == "function" then return lf end
    return nil
end

function LFI:IsAvailable()
    return Lib() ~= nil
end

function LFI:IsEnabled()
    return SBR.sv.useLibFights and self:IsAvailable()
end

function LFI:IsLogging()
    local lf = Lib()
    return lf and SBR.SafeCall(lf.Is_Logging) == true or false
end

function LFI:Init()
    local lf = Lib()
    if not lf or self.callbacksRegistered then return end
    if type(lf.RegisterCallback) ~= "function" or type(lf.EVENTS) ~= "table" then return end
    if lf.EVENTS.FIGHT_ENDED then
        lf.RegisterCallback(lf.EVENTS.FIGHT_ENDED, function(fight, reason) LFI:OnFightEnded(fight, reason) end)
    end
    if lf.EVENTS.DEATH then
        lf.RegisterCallback(lf.EVENTS.DEATH, function(fight, death) LFI:OnDeath(fight, death) end)
    end
    self.callbacksRegistered = true
end

---------------------------------------------------------------------------
-- Match lifecycle
---------------------------------------------------------------------------

-- Called on match start and again after /reloadui mid-match.
function LFI:Attach(match)
    if not self:IsEnabled() then return false end
    self:Init()
    match.lf = match.lf or { fights = {}, deaths = {} }
    local lf = Lib()
    if SBR.SafeCall(lf.Is_Logging) then
        match.lf.sharedSession = true -- another add-on or the user owns this logging session
    else
        local ok = SBR.SafeCall(lf.Start_Logging, {
            rawEvents = false,             -- not needed here; keeps memory down in long matches
            saveFights = SBR.sv.lfSaveFights,
        })
        self.weStarted = ok == true
    end
    SBR.Debug("LibFights attached (we started: %s)", tostring(self.weStarted))
    return true
end

-- Called before the final snapshot. Stopping logging ends the running fight,
-- and FIGHT_ENDED fires synchronously, so that fight is still counted.
function LFI:Detach(match)
    local lf = Lib()
    if not lf or not match.lf then return end
    if self.weStarted then
        self.weStarted = false
        SBR.SafeCall(lf.Stop_Logging)
    else
        local cur = SBR.SafeCall(lf.GetCurrentFight)
        if cur then self:StoreFight(match, cur) end
    end
end

-- After the final snapshot the per-fight breakdowns are already summed into the
-- players. Keep only a compact list so SavedVariables stay small.
function LFI:Compact(match)
    if not match.lf or not match.lf.fights then return end
    local list = {}
    for _, e in pairs(match.lf.fights) do
        list[#list + 1] = {
            id = e.id, title = e.title, startTimestamp = e.startTimestamp, durationSec = e.durationSec,
            activeSec = e.activeSec, endReason = e.endReason, dps = e.dps,
            damage = e.me.damageDone, healing = e.me.healingDone, damageTaken = e.me.damageTaken,
            killingBlows = e.me.killingBlows, deaths = e.me.deaths,
        }
    end
    table.sort(list, function(a, b) return (a.startTimestamp or 0) < (b.startTimestamp or 0) end)
    match.lf.fightList = list
    match.lf.fights = nil
end

---------------------------------------------------------------------------
-- Reading fights
---------------------------------------------------------------------------
local function Num(v) return type(v) == "number" and v or 0 end

local function Extract(f)
    local s = SBR.SafeCall(f.GetSummary, f) or f.summary or {}
    local T = f.totals or {}
    local e = {
        id = f.id,
        title = SBR.SafeCall(f.GetTitle, f) or s.title,
        startTimestamp = f.startTimestamp or s.startTimestamp,
        durationSec = s.durationSec,
        activeSec = s.activeSec,
        endReason = f.endReason,
        dps = s.dps,
        me = {},
    }
    for ours, theirs in pairs(SUMMARY_FIELDS) do
        if type(s[theirs]) == "number" then e.me[ours] = s[theirs] end
    end
    e.me.damageBlocked = T.blockedDamageIn
    e.me.maxHit = s.maxHit
    e.me.maxHitAbility = s.maxHitAbility and SBR.CleanName(s.maxHitAbility) or nil

    e.targets = {}
    for _, t in ipairs(SBR.SafeCall(f.GetTargets, f) or {}) do
        local n = SBR.CleanName(t.name)
        if n ~= "" then
            local x = e.targets[n] or { damage = 0, killed = 0 }
            x.damage = x.damage + Num(t.damage)
            if t.killed then x.killed = x.killed + 1 end
            e.targets[n] = x
        end
    end

    e.sources = {}
    for _, src in ipairs(SBR.SafeCall(f.GetSources, f) or {}) do
        local n = SBR.CleanName(src.name)
        if n ~= "" then e.sources[n] = (e.sources[n] or 0) + Num(src.damage) end
    end

    e.heals = {}
    for unitId, amount in pairs(f.healTargets or {}) do
        local n = SBR.CleanName(SBR.SafeCall(f.GetUnitName, f, unitId) or "")
        if n ~= "" then e.heals[n] = (e.heals[n] or 0) + Num(amount) end
    end

    e.abilities = {}
    for _, a in ipairs(SBR.SafeCall(f.GetAbilityBreakdown, f, "damageOut", "total", TOP_ABILITIES) or {}) do
        e.abilities[#e.abilities + 1] = { id = a.id, name = SBR.CleanName(a.name), icon = a.icon, total = a.total, hits = a.hits, crits = a.crits }
    end
    e.healAbilities = {}
    for _, a in ipairs(SBR.SafeCall(f.GetAbilityBreakdown, f, "healOut", "total", TOP_ABILITIES) or {}) do
        e.healAbilities[#e.healAbilities + 1] = { id = a.id, name = SBR.CleanName(a.name), icon = a.icon, total = a.total }
    end
    return e
end

local function InMatch(match, f)
    -- In a shared logging session, ignore fights that began before the match did.
    return type(f.startTimestamp) ~= "number" or f.startTimestamp >= (match.startedAt or 0) - 5
end

function LFI:StoreFight(match, f)
    if not match.lf or type(f) ~= "table" or f.id == nil or not InMatch(match, f) then return end
    local ok, e = pcall(Extract, f)
    if not ok then
        SBR.Debug("LibFights extract failed: %s", tostring(e))
        return
    end
    match.lf.fights = match.lf.fights or {}
    match.lf.fights[tostring(f.id)] = e
end

function LFI:OnFightEnded(fight, reason)
    local match = SBR.MatchLog:GetCurrent()
    if not match or not match.lf then return end
    self:StoreFight(match, fight)
    SBR.MatchLog:RequestSnapshot()
end

function LFI:OnDeath(fight, death)
    local match = SBR.MatchLog:GetCurrent()
    if not match or not match.lf or type(death) ~= "table" or death.unitTag ~= "player" then return end
    local hits = {}
    local recap = death.recap or {}
    for i = math.max(1, #recap - RECAP_HITS + 1), #recap do
        local h = recap[i]
        hits[#hits + 1] = {
            abilityId = h.abilityId,
            ability = SBR.CleanName((h.abilityName ~= nil and h.abilityName ~= "") and h.abilityName
                or (h.abilityId and SBR.API("GetAbilityName", h.abilityId)) or ""),
            hit = h.hit, overflow = h.overflow,
            source = SBR.CleanName(h.source or ""), result = h.resultName,
        }
    end
    local deaths = match.lf.deaths
    deaths[#deaths + 1] = {
        at = SBR.Now(),
        t = match.startedMs and (GetGameTimeMilliseconds() - match.startedMs) / 1000 or nil,
        fight = fight and SBR.SafeCall(fight.GetTitle, fight) or nil,
        killer = hits[#hits] and hits[#hits].source or nil,
        hits = hits,
    }
    while #deaths > MAX_DEATHS do table.remove(deaths, 1) end
end

---------------------------------------------------------------------------
-- Aggregation (rebuilt on every snapshot from stored fights + the live one)
---------------------------------------------------------------------------
local function MergeAbilities(into, list)
    for _, a in ipairs(list or {}) do
        local key = a.id or a.name
        if key then
            local x = into[key] or { id = a.id, name = a.name, icon = a.icon, total = 0, hits = 0, crits = 0 }
            x.total = x.total + Num(a.total)
            x.hits = x.hits + Num(a.hits)
            x.crits = x.crits + Num(a.crits)
            into[key] = x
        end
    end
end

local function TopList(map, n)
    local list = {}
    for _, v in pairs(map) do list[#list + 1] = v end
    table.sort(list, function(a, b) return a.total > b.total end)
    for i = #list, n + 1, -1 do list[i] = nil end
    return list
end

function LFI:BuildAggregate(match)
    if not match.lf or not match.lf.fights then return nil end
    local fights = {}
    for _, e in pairs(match.lf.fights) do fights[#fights + 1] = e end
    local lf = Lib()
    local cur = lf and SBR.SafeCall(lf.GetCurrentFight)
    if cur and cur.id ~= nil and not match.lf.fights[tostring(cur.id)] and InMatch(match, cur) then
        local ok, e = pcall(Extract, cur)
        if ok then fights[#fights + 1] = e end
    end
    if #fights == 0 then return nil end

    local agg = { me = {}, targets = {}, sources = {}, heals = {}, activeSec = 0, fights = #fights }
    local abilities, healAbilities = {}, {}
    for _, e in ipairs(fights) do
        agg.activeSec = agg.activeSec + Num(e.activeSec)
        for k, v in pairs(e.me) do
            if k == "maxHit" then
                if v > Num(agg.me.maxHit) then
                    agg.me.maxHit, agg.me.maxHitAbility = v, e.me.maxHitAbility
                end
            elseif type(v) == "number" then
                agg.me[k] = Num(agg.me[k]) + v
            end
        end
        for n, t in pairs(e.targets) do
            local x = agg.targets[n] or { damage = 0, killed = 0 }
            x.damage, x.killed = x.damage + t.damage, x.killed + t.killed
            agg.targets[n] = x
        end
        for n, v in pairs(e.sources) do agg.sources[n] = Num(agg.sources[n]) + v end
        for n, v in pairs(e.heals) do agg.heals[n] = Num(agg.heals[n]) + v end
        MergeAbilities(abilities, e.abilities)
        MergeAbilities(healAbilities, e.healAbilities)
    end

    local me, secs = agg.me, agg.activeSec
    me.activeTime = secs
    me.fights = agg.fights
    if secs > 0 then
        me.dps = Num(me.damageDone) / secs
        me.hps = Num(me.healingDone) / secs
    end
    if Num(me.hits) > 0 then me.critRate = Num(me.crits) / me.hits * 100 end
    me.topAbilities = {}
    for _, a in ipairs(TopList(abilities, 5)) do
        me.topAbilities[#me.topAbilities + 1] = { name = a.name, damage = a.total, icon = a.icon }
    end
    me.topHeals = {}
    for _, a in ipairs(TopList(healAbilities, 3)) do
        me.topHeals[#me.topHeals + 1] = { name = a.name, damage = a.total, icon = a.icon }
    end
    me.source = "LibFights"
    return agg
end

-- LibFights only logs your own fights, so this is your row only.
function LFI:GetPlayerStats(agg, p)
    if not agg or not p.isLocal then return nil end
    return agg.me
end

function LFI:GetVsStats(agg, characterName)
    if not agg then return nil end
    local t, src, heal = agg.targets[characterName], agg.sources[characterName], agg.heals[characterName]
    if not t and not src and not heal then return nil end
    return {
        damageFromYou = t and t.damage or 0,
        damageToYou = src or 0,
        healedByYou = heal or 0,
    }
end

function LFI:StatusText()
    if not self:IsAvailable() then return "LibFights not installed" end
    if not SBR.sv.useLibFights then return "LibFights disabled in settings" end
    local parts = { self:IsLogging() and "logging" or "idle" }
    if self.weStarted then parts[#parts + 1] = "started by us" end
    return "LibFights " .. (Lib().version or "") .. " (" .. table.concat(parts, ", ") .. ")"
end
