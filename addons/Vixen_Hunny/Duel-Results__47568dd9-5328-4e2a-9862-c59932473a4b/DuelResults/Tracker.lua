--[[
    Duel Results - tracker
    Detects duels (your own via duel events, group members' via PvP flag polling),
    and records damage, healing, defensive stats, ability breakdowns and effect uptimes.
]]

local DR = DuelResults
local Tracker = {}
DR.Tracker = Tracker

Tracker.current = nil

local EM = EVENT_MANAGER
local GetGameTimeMilliseconds = GetGameTimeMilliseconds

local DAMAGE_RESULTS = {
    [ACTION_RESULT_DAMAGE]            = true,
    [ACTION_RESULT_CRITICAL_DAMAGE]   = true,
    [ACTION_RESULT_DOT_TICK]          = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_BLOCKED_DAMAGE]    = true,
    [ACTION_RESULT_DAMAGE_SHIELDED]   = true,
}

local HEAL_RESULTS = {
    [ACTION_RESULT_HEAL]              = true,
    [ACTION_RESULT_CRITICAL_HEAL]     = true,
    [ACTION_RESULT_HOT_TICK]          = true,
    [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
}

local CRIT_RESULTS = {
    [ACTION_RESULT_CRITICAL_DAMAGE]   = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_CRITICAL_HEAL]     = true,
    [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
}

------------------------------------------------------------------------------------------
-- Name handling
------------------------------------------------------------------------------------------
local nameCache = {}
local function Norm(name)
    if type(name) ~= "string" or name == "" then return "" end
    local n = nameCache[name]
    if not n then
        n = zo_strformat(SI_UNIT_NAME, name)
        nameCache[name] = n
    end
    return n
end
DR.NormalizeName = Norm

local function FindGroupTag(charName, displayName)
    if not IsUnitGrouped("player") then return nil end
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            if (charName ~= "" and Norm(GetUnitName(tag)) == charName)
                or (displayName ~= "" and GetUnitDisplayName(tag) == displayName) then
                return tag
            end
        end
    end
    return nil
end

------------------------------------------------------------------------------------------
-- Data model
------------------------------------------------------------------------------------------
local function NewPlayer(charName, displayName, unitTag)
    return {
        charName = charName or "", displayName = displayName or "", unitTag = unitTag,
        damage = 0, hits = 0, crits = 0, biggest = 0, biggestAbility = "",
        healing = 0, overheal = 0,
        blocked = 0, dodged = 0, absorbed = 0,
        abilities = {}, effects = {},
    }
end

local function Resolve(f, unitId, name)
    if unitId and unitId ~= 0 then
        local idx = f.idMap[unitId]
        if idx then return idx end
    end
    if name and name ~= "" then
        local n = Norm(name)
        for i, p in ipairs(f.players) do
            if (p.charName ~= "" and n == p.charName) or (p.displayName ~= "" and n == p.displayName) then
                if unitId and unitId ~= 0 then f.idMap[unitId] = i end
                return i
            end
        end
    end
    return nil
end

local function AddAbility(p, abilityId, abilityName, dmg, heal, crit, countHit)
    local a = p.abilities[abilityId]
    if not a then
        local name = (abilityName and abilityName ~= "") and abilityName or GetAbilityName(abilityId)
        a = {
            name = zo_strformat(SI_ABILITY_NAME, name),
            icon = GetAbilityIcon(abilityId),
            damage = 0, healing = 0, hits = 0, crits = 0,
        }
        p.abilities[abilityId] = a
    end
    a.damage = a.damage + dmg
    a.healing = a.healing + heal
    if countHit then
        a.hits = a.hits + 1
        if crit then a.crits = a.crits + 1 end
    end
end

------------------------------------------------------------------------------------------
-- Effects (uptime tracked per effect name; multiple slots of the same name merge)
------------------------------------------------------------------------------------------
local function GetEffect(p, name, icon, isDebuff, create)
    local e = p.effects[name]
    if not e and create then
        e = { name = name, icon = icon, debuff = isDebuff == true, upMs = 0, slots = {} }
        p.effects[name] = e
    end
    return e
end

local function SetEffectUp(e, slot, up, now)
    local wasUp = next(e.slots) ~= nil
    e.slots[slot] = up or nil
    local isUp = next(e.slots) ~= nil
    if isUp and not wasUp then
        e.since = now
    elseif wasUp and not isUp then
        e.upMs = e.upMs + (now - (e.since or now))
        e.since = nil
    end
end

local function SeedEffects(p, now)
    local tag = p.unitTag
    if not tag or not DoesUnitExist(tag) then return end
    for i = 1, GetNumBuffs(tag) do
        local buffName, timeStarted, timeEnding, buffSlot, _, iconFile, _, effectType = GetUnitBuffInfo(tag, i)
        if buffName and buffName ~= "" and not (DR.sv.hidePermanent and timeStarted == timeEnding) then
            local e = GetEffect(p, zo_strformat(SI_ABILITY_NAME, buffName), iconFile, effectType == BUFF_EFFECT_TYPE_DEBUFF, true)
            SetEffectUp(e, buffSlot, true, now)
        end
    end
end

------------------------------------------------------------------------------------------
-- Fight lifecycle
------------------------------------------------------------------------------------------
local function Snapshot(f)
    local s = {
        mode = f.mode, startMs = f.startMs, endMs = f.endMs, timestamp = f.timestamp,
        zone = f.zone, winner = f.winner, reason = f.reason, players = {},
    }
    for i, p in ipairs(f.players) do
        local sp = {}
        for k, v in pairs(p) do
            if type(v) ~= "table" and k ~= "unitTag" then sp[k] = v end
        end
        sp.abilities = {}
        for id, a in pairs(p.abilities) do sp.abilities[id] = ZO_ShallowTableCopy(a) end
        sp.effects = {}
        for name, e in pairs(p.effects) do
            sp.effects[name] = { name = e.name, icon = e.icon, debuff = e.debuff, upMs = e.upMs }
        end
        s.players[i] = sp
    end
    return s
end

local function HasActivity(f)
    for _, p in ipairs(f.players) do
        if p.damage > 0 or p.healing > 0 then return true end
    end
    return false
end

function Tracker:Start(mode, p1, p2)
    if self.current and not self.current.endMs then
        self:Finish(nil, "Interrupted")
    end
    ZO_ClearTable(nameCache)

    local now = GetGameTimeMilliseconds()
    local f = {
        mode = mode, startMs = now, timestamp = GetTimeStamp(),
        zone = zo_strformat(SI_ZONE_NAME, GetUnitZone("player")),
        players = { p1, p2 }, idMap = {},
    }
    self.current = f
    SeedEffects(p1, now)
    SeedEffects(p2, now)
    DR.UI.OnFightStarted(f)
end

function Tracker:Finish(winner, reason)
    local f = self.current
    if not f or f.endMs then return end

    local now = GetGameTimeMilliseconds()
    f.endMs = now
    f.winner = winner
    f.reason = reason or "Ended"

    for _, p in ipairs(f.players) do
        for _, e in pairs(p.effects) do
            if e.since then
                e.upMs = e.upMs + (now - e.since)
                e.since = nil
            end
            ZO_ClearTable(e.slots)
        end
    end

    if HasActivity(f) then
        local history = DR.sv.history
        table.insert(history, 1, Snapshot(f))
        while #history > DR.sv.maxHistory do table.remove(history) end
    end

    DR.UI.OnFightFinished(f)
end

function Tracker:Reset()
    local f = self.current
    self.current = nil
    if f and not f.endMs then
        -- Restart measurement for the duel in progress.
        local a, b = f.players[1], f.players[2]
        self:Start(f.mode, NewPlayer(a.charName, a.displayName, a.unitTag), NewPlayer(b.charName, b.displayName, b.unitTag))
    else
        DR.UI.OnFightReset()
    end
end

function Tracker:IsLive()
    return self.current ~= nil and self.current.endMs == nil
end

------------------------------------------------------------------------------------------
-- Event handlers
------------------------------------------------------------------------------------------
local function OnCombatEvent(_, result, isError, abilityName, _, _, sourceName, sourceType, targetName, _,
                             hitValue, _, _, _, sourceUnitId, targetUnitId, abilityId, overflow)
    local f = Tracker.current
    if isError or not f or f.endMs then return end

    local isDamage, isHeal = DAMAGE_RESULTS[result], HEAL_RESULTS[result]
    if not (isDamage or isHeal or result == ACTION_RESULT_DODGED) then return end

    local src = Resolve(f, sourceUnitId, sourceName)
    if not src and f.mode == "self" and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
        src = 1 -- your own pets count towards you
    end
    if not src then return end

    local tgt = Resolve(f, targetUnitId, targetName)
    local p = f.players[src]
    local crit = CRIT_RESULTS[result] == true
    hitValue = hitValue or 0

    if isDamage then
        if not tgt or tgt == src then return end -- only damage dealt to the opponent
        local t = f.players[tgt]
        p.damage = p.damage + hitValue

        local countHit = false
        if result == ACTION_RESULT_DAMAGE_SHIELDED then
            t.absorbed = t.absorbed + hitValue
        elseif hitValue > 0 or result == ACTION_RESULT_BLOCKED_DAMAGE then
            countHit = true
            p.hits = p.hits + 1
            if crit then p.crits = p.crits + 1 end
            if result == ACTION_RESULT_BLOCKED_DAMAGE then t.blocked = t.blocked + 1 end
            if hitValue > p.biggest then
                p.biggest = hitValue
                p.biggestAbility = zo_strformat(SI_ABILITY_NAME, abilityName or "")
            end
        end
        AddAbility(p, abilityId, abilityName, hitValue, 0, crit, countHit)

    elseif isHeal then
        if tgt and tgt ~= src then return end
        p.healing = p.healing + hitValue
        p.overheal = p.overheal + (overflow or 0)
        AddAbility(p, abilityId, abilityName, 0, hitValue, crit, true)

    elseif tgt and tgt ~= src then -- dodged
        f.players[tgt].dodged = f.players[tgt].dodged + 1
    end
end

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, _, iconName,
                               _, effectType, _, _, unitName, unitId)
    local f = Tracker.current
    if not f or f.endMs then return end

    local idx = Resolve(f, unitId, unitName)
    if not idx then return end
    local p = f.players[idx]
    local name = zo_strformat(SI_ABILITY_NAME, effectName)
    local now = GetGameTimeMilliseconds()

    if changeType == EFFECT_RESULT_FADED then
        local e = GetEffect(p, name)
        if e then SetEffectUp(e, effectSlot, false, now) end
    else
        if DR.sv.hidePermanent and beginTime == endTime then return end
        local e = GetEffect(p, name, iconName, effectType == BUFF_EFFECT_TYPE_DEBUFF, true)
        SetEffectUp(e, effectSlot, true, now)
    end
end

-- Remember who we invited / who invited us as a fallback for the partner's name.
local pendingPartner = { char = "", display = "" }

local function OnDuelInvite(_, charName, displayName)
    pendingPartner.char = Norm(charName)
    pendingPartner.display = displayName or ""
end

local function OnDuelStarted()
    local _, partnerChar, partnerDisplay = GetDuelInfo()
    partnerChar = Norm(partnerChar)
    if type(partnerDisplay) ~= "string" then partnerDisplay = "" end
    if partnerChar == "" then partnerChar = pendingPartner.char end
    if partnerDisplay == "" then partnerDisplay = pendingPartner.display end

    local me = NewPlayer(Norm(GetUnitName("player")), GetDisplayName(), "player")
    local opp = NewPlayer(partnerChar, partnerDisplay, FindGroupTag(partnerChar, partnerDisplay))
    Tracker:Start("self", me, opp)
end

local function OnDuelFinished(_, result, wasLocalPlayersResult, opponentCharacterName, opponentDisplayName)
    local f = Tracker.current
    if not f or f.mode ~= "self" or f.endMs then return end

    local opp = f.players[2]
    if opp.charName == "" then opp.charName = Norm(opponentCharacterName) end
    if opp.displayName == "" and type(opponentDisplayName) == "string" then opp.displayName = opponentDisplayName end

    local winner, reason
    if result == DUEL_RESULT_WON then
        winner = wasLocalPlayersResult and 1 or 2
        reason = "Victory"
    elseif result == DUEL_RESULT_FORFEIT then
        winner = wasLocalPlayersResult and 2 or 1
        reason = "Forfeit"
    end
    Tracker:Finish(winner, reason or "Ended")
end

local function HealthPct(tag)
    local cur, max = GetUnitPower(tag, COMBAT_MECHANIC_FLAGS_HEALTH)
    return (max and max > 0) and (cur / max) or 0
end

-- Spectator mode: two PvP-flagged group members (other than you) are assumed to be dueling.
local function PollGroupDuels()
    local f = Tracker.current
    local live = f and not f.endMs

    if live and f.mode == "group" then
        local t1, t2 = f.players[1].unitTag, f.players[2].unitTag
        local ok1 = DoesUnitExist(t1) and IsUnitPvPFlagged(t1)
        local ok2 = DoesUnitExist(t2) and IsUnitPvPFlagged(t2)
        if not (ok1 and ok2) then
            local h1 = DoesUnitExist(t1) and HealthPct(t1) or 0
            local h2 = DoesUnitExist(t2) and HealthPct(t2) or 0
            local winner = (h1 > h2 and 1) or (h2 > h1 and 2) or nil
            Tracker:Finish(winner, winner and "Ended" or "No result")
        end
        return
    end

    if live or not DR.sv.trackGroupDuels then return end
    if not IsUnitGrouped("player") or IsPlayerInAvAWorld() or IsActiveWorldBattleground() then return end

    local flagged = {}
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) and not AreUnitsEqual(tag, "player") and IsUnitPvPFlagged(tag) then
            flagged[#flagged + 1] = tag
        end
    end

    if #flagged == 2 then
        local a, b = flagged[1], flagged[2]
        Tracker:Start("group",
            NewPlayer(Norm(GetUnitName(a)), GetUnitDisplayName(a), a),
            NewPlayer(Norm(GetUnitName(b)), GetUnitDisplayName(b), b))
    end
end

------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------
function Tracker.Init()
    local n = DR.name
    EM:RegisterForEvent(n .. "Combat", EVENT_COMBAT_EVENT, OnCombatEvent)
    EM:AddFilterForEvent(n .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
    EM:RegisterForEvent(n .. "Effects", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:RegisterForEvent(n .. "DuelInviteSent", EVENT_DUEL_INVITE_SENT, OnDuelInvite)
    EM:RegisterForEvent(n .. "DuelInviteReceived", EVENT_DUEL_INVITE_RECEIVED, OnDuelInvite)
    EM:RegisterForEvent(n .. "DuelStarted", EVENT_DUEL_STARTED, OnDuelStarted)
    EM:RegisterForEvent(n .. "DuelFinished", EVENT_DUEL_FINISHED, OnDuelFinished)
    EM:RegisterForUpdate(n .. "GroupPoll", 1000, PollGroupDuels)
end
