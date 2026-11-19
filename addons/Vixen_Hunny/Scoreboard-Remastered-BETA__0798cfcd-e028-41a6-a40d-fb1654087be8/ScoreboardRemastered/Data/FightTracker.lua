-- Per-player combat ledger for the whole match.
--
-- Listens to EVENT_COMBAT_EVENT without filters while in a battleground and
-- credits every event the client sends to the players on both ends of it.
-- The client sends events where the source or target is you, your pet or a
-- member of your group, so:
--   you            everything (LibFights' summary is used for your row when present)
--   teammates      their damage/healing out, damage/healing taken, crits, CC,
--                  interrupts, max hit, top abilities (as long as they are in your group)
--   enemies        damage/CC they did to your team, damage/CC they took from your team
--                  (their healing and fights with a third team are not visible)
-- Results are categorised with LibFights.Const when it is installed, so both agree
-- on what counts as damage, healing, CC and so on.
--
-- The ledger lives in match.ledger (SavedVariables), so /reloadui mid-match keeps it.
--
-- Performance: this runs for every combat event in a battleground, often hundreds a
-- second, so it is kept cheap. The event is registered once per result type it uses,
-- so the game only calls into Lua for those results (most combat events are other
-- results). Names are formatted once and cached, and recap entries are reused.
local SBR = ScoreboardRemastered
local FT = { name = "Combat log", active = false }
SBR.FightTracker = FT

local ACTIVE_GAP_MS = 5000 -- gaps longer than this don't count as active time
local RECENT_HITS = 6      -- hits kept per player for death recaps
local TOP_N = 5

-- Category lookup: LibFights' table when available, else our own.
local CATEGORY
local CRIT
local R_KB, R_INTERRUPT, R_BLOCKED

local function BuildCategories()
    local LFC = _G.LibFights and _G.LibFights.Const
    if type(LFC) == "table" and type(LFC.CATEGORY) == "table" then
        CATEGORY, CRIT = LFC.CATEGORY, LFC.CRIT_RESULTS or {}
    else
        CATEGORY = {}
        local function assign(cat, names)
            for _, n in ipairs(names) do
                local v = _G["ACTION_RESULT_" .. n]
                if v ~= nil and CATEGORY[v] == nil then CATEGORY[v] = cat end
            end
        end
        assign("shield", { "DAMAGE_SHIELDED" })
        assign("damage", { "DAMAGE", "CRITICAL_DAMAGE", "DOT_TICK", "DOT_TICK_CRITICAL", "BLOCKED_DAMAGE",
            "FALL_DAMAGE", "PRECISE_DAMAGE", "WRECKING_DAMAGE" })
        assign("heal", { "HEAL", "CRITICAL_HEAL", "HOT_TICK", "HOT_TICK_CRITICAL" })
        assign("cc", { "INTERRUPT", "STUNNED", "KNOCKBACK", "FEARED", "SNARED", "ROOTED", "SILENCED", "STAGGERED",
            "LEVITATED", "DISORIENTED", "OFFBALANCE", "CHARMED" })
        assign("death", { "DIED", "DIED_XP", "KILLING_BLOW" })
        CRIT = SBR.ConstSet({ "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK_CRITICAL",
            "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK_CRITICAL" })
    end
    R_KB = _G.ACTION_RESULT_KILLING_BLOW
    R_INTERRUPT = _G.ACTION_RESULT_INTERRUPT
    R_BLOCKED = _G.ACTION_RESULT_BLOCKED_DAMAGE
end

local function NewUnit()
    return {
        damageDone = 0, damageTaken = 0, healingDone = 0, healingTaken = 0,
        damageShielded = 0, damageBlocked = 0,
        hits = 0, crits = 0, healHits = 0, healCrits = 0,
        maxHit = 0, killingBlows = 0, deaths = 0,
        interrupts = 0, interrupted = 0, ccApplied = 0, ccTaken = 0,
        activeMs = 0,
        abilities = {}, heals = {}, recent = {},
    }
end

local function NewVs()
    return { damageToYou = 0, damageFromYou = 0, healedByYou = 0, healedYou = 0 }
end

-- Attach to the match's ledger (new, or restored after /reloadui).
function FT:Bind(match)
    match.ledger = match.ledger or { units = {}, vs = {} }
    self.ledger = match.ledger
    self.unitNames = {}
    self.lastActive = {}
    self.myName = match.character
    BuildCategories()
end

function FT:Unit(name)
    local units = self.ledger.units
    local u = units[name]
    if not u then
        u = NewUnit()
        units[name] = u
    end
    return u
end

function FT:Vs(name)
    if name == "" or name == self.myName then return nil end
    local vs = self.ledger.vs
    local v = vs[name]
    if not v then
        v = NewVs()
        vs[name] = v
    end
    return v
end

-- zo_strformat is expensive; each raw name / ability is formatted once per match
local cleanNames, abilityNames = {}, {}

local function Clean(raw)
    if raw == nil or raw == "" then return "" end
    local c = cleanNames[raw]
    if c == nil then
        c = SBR.CleanName(raw)
        cleanNames[raw] = c
    end
    return c
end

local function AbilityName(raw, abilityId)
    local key = abilityId or raw
    if key == nil then return "" end
    local c = abilityNames[key]
    if c == nil then
        c = SBR.CleanName(raw)
        abilityNames[key] = c
    end
    return c
end

function FT:ResolveName(name, unitId, unitType)
    if unitType == COMBAT_UNIT_TYPE_PLAYER or unitType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return self.myName -- your pet's damage is yours
    end
    if name ~= nil and name ~= "" then
        local clean = Clean(name)
        if unitId and unitId ~= 0 and self.unitNames[unitId] ~= clean then self.unitNames[unitId] = clean end
        return clean
    end
    return unitId and self.unitNames[unitId] or ""
end

-- ability name -> icon, so every player's top abilities can show icons
function FT:NoteAbility(name, abilityId)
    local icons = self.ledger.icons
    if not icons then
        icons = {}
        self.ledger.icons = icons
    end
    if icons[name] == nil and abilityId then
        icons[name] = SBR.API("GetAbilityIcon", abilityId) or false
    end
end

function FT:MarkActive(u, name, now)
    local last = self.lastActive[name]
    if last and now - last <= ACTIVE_GAP_MS then u.activeMs = u.activeMs + (now - last) end
    self.lastActive[name] = now
end

-- Last RECENT_HITS hits, oldest first; the oldest entry's table is reused.
local function PushRecent(u, now, ability, abilityId, hit, source, crit)
    local r = u.recent
    local e
    if #r >= RECENT_HITS then
        e = table.remove(r, 1)
    else
        e = {}
    end
    e.t, e.ability, e.abilityId, e.hit, e.source, e.crit = now, ability, abilityId, hit, source, crit
    r[#r + 1] = e
end

function FT:OnCombatEvent(result, isError, abilityName, sourceName, sourceType, targetName, targetType, hitValue, sourceUnitId, targetUnitId, abilityId)
    if isError or not self.ledger then return end
    local cat = CATEGORY[result]
    if not cat then return end
    if (cat == "damage" or cat == "heal") and (hitValue or 0) <= 0 then return end

    local srcName = self:ResolveName(sourceName, sourceUnitId, sourceType)
    local tgtName = self:ResolveName(targetName, targetUnitId, targetType)
    local selfTarget = srcName ~= "" and srcName == tgtName
    local src = srcName ~= "" and self:Unit(srcName) or nil
    local tgt = tgtName ~= "" and self:Unit(tgtName) or nil
    local hit = hitValue or 0
    local now = GetGameTimeMilliseconds()
    local me = self.myName

    if cat == "damage" then
        if hit <= 0 then return end
        local ability = AbilityName(abilityName, abilityId)
        if src and not selfTarget then
            src.damageDone = src.damageDone + hit
            src.hits = src.hits + 1
            if CRIT[result] then src.crits = src.crits + 1 end
            if hit > src.maxHit then src.maxHit, src.maxHitAbility = hit, ability end
            if ability ~= "" then
                src.abilities[ability] = (src.abilities[ability] or 0) + hit
                self:NoteAbility(ability, abilityId)
            end
            self:MarkActive(src, srcName, now)
        end
        if tgt then
            tgt.damageTaken = tgt.damageTaken + hit
            if result == R_BLOCKED then tgt.damageBlocked = tgt.damageBlocked + hit end
            PushRecent(tgt, now, ability, abilityId, hit, srcName, CRIT[result] and true or nil)
        end
        if srcName == me and tgtName ~= me then
            local v = self:Vs(tgtName)
            if v then v.damageFromYou = v.damageFromYou + hit end
        elseif tgtName == me and srcName ~= me then
            local v = self:Vs(srcName)
            if v then v.damageToYou = v.damageToYou + hit end
        end
    elseif cat == "heal" then
        if hit <= 0 then return end
        if src then
            local ability = AbilityName(abilityName, abilityId)
            src.healingDone = src.healingDone + hit
            src.healHits = src.healHits + 1
            if CRIT[result] then src.healCrits = src.healCrits + 1 end
            if ability ~= "" then
                src.heals[ability] = (src.heals[ability] or 0) + hit
                self:NoteAbility(ability, abilityId)
            end
            self:MarkActive(src, srcName, now)
        end
        if tgt then tgt.healingTaken = tgt.healingTaken + hit end
        if srcName == me and tgtName ~= me then
            local v = self:Vs(tgtName)
            if v then v.healedByYou = v.healedByYou + hit end
        elseif tgtName == me and srcName ~= me then
            local v = self:Vs(srcName)
            if v then v.healedYou = v.healedYou + hit end
        end
    elseif cat == "shield" then
        if tgt then tgt.damageShielded = tgt.damageShielded + hit end
    elseif cat == "cc" then
        if selfTarget then return end
        if result == R_INTERRUPT then
            if src then src.interrupts = src.interrupts + 1 end
            if tgt then tgt.interrupted = tgt.interrupted + 1 end
        else
            if src then src.ccApplied = src.ccApplied + 1 end
            if tgt then tgt.ccTaken = tgt.ccTaken + 1 end
        end
    elseif cat == "death" then
        if result == R_KB then
            if src and not selfTarget then src.killingBlows = src.killingBlows + 1 end
        elseif tgt then
            tgt.deaths = tgt.deaths + 1
        end
    end
end

local function Top(map, n, icons)
    local list = {}
    for name, total in pairs(map or {}) do
        local icon = icons and icons[name]
        list[#list + 1] = { name = name, damage = total, icon = icon or nil }
    end
    table.sort(list, function(a, b) return a.damage > b.damage end)
    for i = #list, n + 1, -1 do list[i] = nil end
    return list
end

-- Stats for one player, in the same shape as the LibFights summary.
-- isEnemy: their healing isn't visible to the client, so it is left out instead of shown as 0.
function FT:GetPlayerStats(characterName, isEnemy)
    local u = self.ledger and self.ledger.units[characterName]
    if not u then return nil end
    local secs = u.activeMs / 1000
    local s = {}
    for k, v in pairs(u) do
        if type(v) == "number" or type(v) == "string" then s[k] = v end
    end
    s.activeMs = nil
    s.activeTime = secs
    if secs > 0 then
        s.dps = u.damageDone / secs
        s.hps = u.healingDone / secs
    end
    if u.hits > 0 then s.critRate = u.crits / u.hits * 100 end
    if u.healHits > 0 then s.healCritRate = u.healCrits / u.healHits * 100 end
    if u.maxHit == 0 then s.maxHit = nil end
    if isEnemy and u.healingDone == 0 then s.healingDone, s.hps = nil, nil end
    s.topAbilities = Top(u.abilities, TOP_N, self.ledger.icons)
    s.topHeals = Top(u.heals, 3, self.ledger.icons)
    s.source = isEnemy and (FT.name .. ", vs your team") or FT.name
    return s
end

function FT:GetVsStats(characterName)
    local v = self.ledger and self.ledger.vs[characterName]
    return v and SBR.ShallowCopy(v) or nil
end

-- Last hits a player took, oldest first (death recaps in the kill feed).
function FT:GetRecentHits(characterName, withinMs)
    local u = self.ledger and self.ledger.units[characterName]
    if not u then return nil end
    local now = GetGameTimeMilliseconds()
    local out = {}
    for _, h in ipairs(u.recent) do
        if not withinMs or now - h.t <= withinMs then
            out[#out + 1] = { ability = h.ability, abilityId = h.abilityId, hit = h.hit, source = h.source, crit = h.crit }
        end
    end
    return #out > 0 and out or nil
end

function FT:Start(match)
    if not SBR.sv.trackCombat then return end
    self:Bind(match)
    if self.active then return end
    self.active = true
    local function handler(_, result, isError, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, _, _, _, sourceUnitId, targetUnitId, abilityId)
        FT:OnCombatEvent(result, isError, abilityName, sourceName, sourceType, targetName, targetType, hitValue, sourceUnitId, targetUnitId, abilityId)
    end
    -- one registration per result type we count, filtered in the game client, so the
    -- many other combat results (effects, power changes, misses...) never reach Lua
    self.namespaces = {}
    if REGISTER_FILTER_COMBAT_RESULT then
        local USED = { damage = true, heal = true, shield = true, cc = true, death = true }
        for result, cat in pairs(CATEGORY) do
            if USED[cat] and type(result) == "number" then
                local ns = SBR.name .. "_Combat" .. tostring(result)
                EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, handler)
                EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result, REGISTER_FILTER_IS_ERROR, false)
                self.namespaces[#self.namespaces + 1] = ns
            end
        end
    else
        local ns = SBR.name .. "_Combat"
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, handler)
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        self.namespaces[1] = ns
    end
end

function FT:Stop()
    if self.active then
        self.active = false
        for _, ns in ipairs(self.namespaces or {}) do EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT) end
        self.namespaces = nil
    end
    self.ledger = nil
    cleanNames, abilityNames = {}, {}
end
ScoreboardRemastered.Mark("Data/FightTracker.lua")
