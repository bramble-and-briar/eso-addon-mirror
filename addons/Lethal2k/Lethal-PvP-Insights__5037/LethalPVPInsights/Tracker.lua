-- Lethal PVP Insights - event tracking (kill feed, combat events, reticle scans)
local PDI = PVPDataInsight
local Tracker = {}
PDI.Tracker = Tracker

local EM = EVENT_MANAGER
local NS = PDI.name .. "_Tracker"
local HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH

local recentDamaged = {}   -- [victimChar] = { t = ms, player = bool }
local recorded      = {}   -- [dedupeKey] = ms
local deaths        = {}   -- [char or @account] = { t=, field=, feed=, entry= } (see recordMine)
local myAccount, myChar

local function nowMs() return GetGameTimeMilliseconds() end
local noteStatus

local function wasRecorded(key)
    local t = recorded[key]
    return t ~= nil and (nowMs() - t) < PDI.DEDUPE_WINDOW_MS
end

local function markRecorded(key) recorded[key] = nowMs() end

local function cleanup()
    local now = nowMs()
    for k, t in pairs(recorded) do if now - t > 60000 then recorded[k] = nil end end
    for k, d in pairs(deaths) do if now - d.t > 60000 then deaths[k] = nil end end
    for k, e in pairs(recentDamaged) do if now - e.t > PDI.ASSIST_WINDOW_MS * 2 then recentDamaged[k] = nil end end
    if noteStatus then noteStatus() end      -- (no name: only forgets old Burning / Chilled / Concussion)
end

-- Current group roster (character names), kept up to date regardless of zone
local groupChars = {}
local function rebuildGroupChars()
    groupChars = {}
    if not IsUnitGrouped("player") then return end
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            local c = PDI.CleanName(GetUnitName(tag))
            if c then groupChars[c] = true end
        end
    end
end
function Tracker:IsGroupMember(char) return char ~= nil and groupChars[char] == true end

-- Is this player someone we may record as an opponent right now?
local function isEnemyCandidate(char)
    if not char or char == myChar or groupChars[char] then return false end
    local ctx, duelPartner = PDI.OpponentContext()
    if not ctx then return false end
    if ctx == "duel" then return char == duelPartner end
    -- in Cyrodiil / Imperial City your own alliance can't be an enemy (Battlegrounds mix alliances)
    if IsPlayerInAvAWorld and IsPlayerInAvAWorld() then
        local al = PDI.Data:GetAlliance(char)
        if al and al ~= 0 and al == GetUnitAlliance("player") then return false end
    end
    return true
end
Tracker.IsEnemyCandidate = function(_, char) return isEnemyCandidate(char) end

local function isKnownPlayer(char)
    return char ~= nil and PDI.sv.names[char] ~= nil
end

local function refreshUI()
    if PDI.UI and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
end

---------------------------------------------------------------------------
-- Result classification
---------------------------------------------------------------------------
local INCOMING = {}
local function map(list, ty) for _, r in ipairs(list) do if r then INCOMING[r] = ty end end end
map({ ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_BLOCKED_DAMAGE,
      ACTION_RESULT_ABSORBED }, "dmg")
map({ ACTION_RESULT_DAMAGE_SHIELDED }, "eff")   -- a shield soaking damage isn't damage dealt by that "ability"
map({ ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL }, "dot")
map({ ACTION_RESULT_KILLING_BLOW }, "kb")
map({ ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_GAINED_DURATION }, "eff")
map({ ACTION_RESULT_STUNNED, ACTION_RESULT_ROOTED, ACTION_RESULT_SNARED, ACTION_RESULT_KNOCKBACK,
      ACTION_RESULT_FEARED, ACTION_RESULT_SILENCED, ACTION_RESULT_OFFBALANCE,
      ACTION_RESULT_DISORIENTED, ACTION_RESULT_LEVITATED, ACTION_RESULT_STAGGERED }, "cc")

local OUTGOING_DAMAGE = {}
for _, r in ipairs({ ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_DOT_TICK,
                     ACTION_RESULT_DOT_TICK_CRITICAL, ACTION_RESULT_BLOCKED_DAMAGE,
                     ACTION_RESULT_DAMAGE_SHIELDED, ACTION_RESULT_KILLING_BLOW }) do
    if r then OUTGOING_DAMAGE[r] = true end
end

---------------------------------------------------------------------------
-- Recording a kill / assist (shared by kill feed and fallback paths)
---------------------------------------------------------------------------
-- One record per victim death. The same death can reach us up to three ways (kill feed, our own
-- KILLING_BLOW combat event, the victim's DIED event), in any order, with the character name or the
-- @account. All of them share one record; the kill feed has the final word on kill vs assist.

local function findDeath(keys)
    local now = nowMs()
    for _, k in ipairs(keys) do
        local d = deaths[k]
        if d and now - d.t < PDI.DEDUPE_WINDOW_MS then return d end
    end
end

local function notifyMine(who, field, corrected)
    if not (who and PDI.sv.settings.chatNotify) then return end
    local today = PDI.Data:GetPeriod("my", "today")[who]
    local label = field == "k" and "Killing blow" or "Assist"
    if corrected then label = label .. " |c999999(corrected)|r" end
    PDI.Msg(string.format("%s: %s  |c999999(today vs them: %d KB / %d A)|r",
        label, who, today and today.k or 0, today and today.a or 0))
end

-- Every kill / assist counted in the last 45 seconds, matched loosely (character name or @account, any
-- case): a kill and an assist on the same victim that close together are the same death, whatever order
-- the kill feed and combat events came in and whichever name each of them used.
local recentMine = {}
local MINE_WINDOW_MS = 45000     -- a player can't die, respawn and die again that fast
-- combat events (death / killing blow) can arrive 30+ seconds after the kill feed line: an assist
-- guessed from them is checked against a longer window
local GUESS_WINDOW_MS = 120000
local function lowerKeys(char, acct)
    local out = {}
    if char then out[string.lower(char)] = true end
    acct = acct or (char and PDI.Data:GetAccount(char))
    if acct then out[string.lower(acct)] = true end
    return out
end
local function sameVictim(m, keys)
    for k in pairs(keys) do if m.keys[k] then return true end end
    return false
end
local function noteMine(char, acct, field, entry)
    local now = nowMs()
    for i = #recentMine, 1, -1 do if now - recentMine[i].t > GUESS_WINDOW_MS then table.remove(recentMine, i) end end
    recentMine[#recentMine + 1] = { t = now, keys = lowerKeys(char, acct), field = field, entry = entry }
end
local function recentKillOf(char, acct, window)
    local keys, now = lowerKeys(char, acct), nowMs()
    for _, m in ipairs(recentMine) do
        if m.field == "k" and now - m.t <= (window or MINE_WINDOW_MS) and sameVictim(m, keys) then return true end
    end
    return false
end
-- a kill just came in: an assist counted for the same victim a moment ago was that same death
local function undoRecentAssists(char, acct)
    local keys, now, undone = lowerKeys(char, acct), nowMs(), false
    for i = #recentMine, 1, -1 do
        local m = recentMine[i]
        if m.field == "a" and now - m.t <= MINE_WINDOW_MS and sameVictim(m, keys) then
            PDI.Data:UndoMyKill(m.entry)
            table.remove(recentMine, i)
            undone = true
        end
    end
    return undone
end

-- small log of every kill / assist decision (SavedVariables mineLog, last 100) to find wrong counts
local function logMine(field, fromFeed, char, acct, what, src)
    local sv = PDI.sv
    if not sv then return end
    sv.mineLog = sv.mineLog or {}
    local l = sv.mineLog
    l[#l + 1] = { t = PDI.Now(), ms = nowMs(), f = field, feed = fromFeed and true or nil, c = char, a = acct, r = what, src = src }
    while #l > 100 do table.remove(l, 1) end
end

local function recordMine(victimChar, victimAcct, victimAl, field, fromFeed, src)
    local acct = PDI.NormalizeAccount(victimAcct) or PDI.Data:GetAccount(victimChar)
    -- never a kill and an assist for the same death
    local window = fromFeed and MINE_WINDOW_MS or GUESS_WINDOW_MS
    if field == "a" and recentKillOf(victimChar, acct, window) then
        logMine(field, fromFeed, victimChar, acct, "skip: kill on them moments ago", src)
        return
    end
    local keys = {}
    if victimChar then keys[#keys + 1] = victimChar end
    if acct then keys[#keys + 1] = acct end
    if #keys == 0 then return end
    if field == "k" and not fromFeed then return end   -- kills come only from the kill feed (or a won duel)

    local d = findDeath(keys)
    local corrected, rekeyOnly = false, false
    if d then
        for _, k in ipairs(keys) do deaths[k] = d end
        if d.feed and not fromFeed then return end      -- the kill feed already settled it
        -- one death can come with several kill feed lines (different killers): your kill always wins
        if d.feed and fromFeed and d.field == "k" and field == "a" then return end
        local sameWho = not acct or (d.entry and d.entry.who == acct)
        if d.field == field and (sameWho or not fromFeed) then d.feed = d.feed or fromFeed; return end
        if not fromFeed and field == "a" then return end -- a guessed assist never replaces a kill
        PDI.Data:UndoMyKill(d.entry)                      -- replace the earlier guess
        for i = #recentMine, 1, -1 do if recentMine[i].entry == d.entry then table.remove(recentMine, i) end end
        corrected = d.field ~= field
        rekeyOnly = not corrected                         -- same result, now under the @account
    else
        -- no death record matched by exact name, but an assist on the same player (character or
        -- @account, any case) was counted moments ago: that is this same death, never a second assist
        if field == "a" then
            local vkeys, now = lowerKeys(victimChar, acct), nowMs()
            for i = #recentMine, 1, -1 do
                local m = recentMine[i]
                if m.field == "a" and now - m.t <= window and sameVictim(m, vkeys) then
                    for _, k in ipairs(keys) do if not deaths[k] then deaths[k] = { t = m.t, field = "a", entry = m.entry, feed = fromFeed } end end
                    logMine(field, fromFeed, victimChar, acct, "skip: assist on them moments ago", src)
                    return
                end
            end
        end
        d = { t = nowMs() }
        for _, k in ipairs(keys) do deaths[k] = d end
    end
    if field == "k" and undoRecentAssists(victimChar, acct) then
        corrected = true
        logMine(field, fromFeed, victimChar, acct, "undid an assist on them moments ago", src)
    end
    local who, entry = PDI.Data:AddMyKill(victimChar, acct, victimAl, field)
    d.field, d.entry, d.feed = field, entry, d.feed or fromFeed
    noteMine(victimChar, acct, field, entry)
    logMine(field, fromFeed, victimChar, acct, corrected and "added (corrected)" or (rekeyOnly and "rekeyed" or "added"), src)
    if not rekeyOnly then notifyMine(who, field, corrected) end
    refreshUI()
end

local function hasDeath(victimChar)
    return findDeath({ victimChar, PDI.Data:GetAccount(victimChar) }) ~= nil
end

-- Every victim the kill feed reported recently (any killer), matched by character name or @account,
-- case-insensitively. A guessed assist from combat events only counts when the kill feed said nothing
-- about that victim around the time of death.
local feedVictims = {}   -- { t = ms, c = lower char, a = lower @account }
local function noteFeedVictim(char, acct)
    feedVictims[#feedVictims + 1] = { t = nowMs(), c = char and string.lower(char), a = acct and string.lower(acct) }
    while #feedVictims > 200 do table.remove(feedVictims, 1) end
end

local function feedSawVictim(char, since)
    local c = char and string.lower(char)
    local a = PDI.Data:GetAccount(char)
    a = a and string.lower(a)
    for i = #feedVictims, 1, -1 do
        local f = feedVictims[i]
        if f.t < since then break end
        if (c and f.c == c) or (a and f.a == a) then return true end
    end
    return false
end

-- Combat events saw a player we damaged die: wait for the kill feed, and only when it stays silent
-- about them count it as an assist (no chance of a kill + assist for the same death).
local GUESS_WAIT_MS = 20000
local function guessAssist(victim)
    local diedAt = nowMs()
    zo_callLater(function()
        if feedSawVictim(victim, diedAt - 60000) then return end   -- the feed line can come well before the combat events
        if not hasDeath(victim) then recordMine(victim, nil, nil, "a", false, "guess") end
    end, GUESS_WAIT_MS)
end

local function recordDeath(killerChar, killerAcct, killerAl)
    local key = "death:" .. (killerChar or killerAcct or "?")
    if wasRecorded(key) then return end
    markRecorded(key)
    PDI.Data:RecordKilledBy(killerChar, killerAcct, killerAl)
    refreshUI()
end

---------------------------------------------------------------------------
-- Kill feed (the same data the game prints to chat as PvP kill messages)
---------------------------------------------------------------------------
local function OnKillFeed(_, killLocation, killerDisplay, killerChar, killerAl, killerRank,
                          victimDisplay, victimChar, victimAl, victimRank, isKillLocation)
    killerChar = PDI.CleanName(killerChar)
    victimChar = PDI.CleanName(victimChar)
    killerDisplay = PDI.NormalizeAccount(killerDisplay)
    victimDisplay = PDI.NormalizeAccount(victimDisplay)

    PDI.Data:LearnName(killerChar, killerDisplay, killerAl)
    PDI.Data:LearnName(victimChar, victimDisplay, victimAl)

    -- Feature 2: everyone's kills
    local feedKey = "feed:" .. tostring(killerChar or killerDisplay) .. ">" .. tostring(victimChar or victimDisplay)
    noteFeedVictim(victimChar, victimDisplay)
    if not wasRecorded(feedKey) then
        markRecorded(feedKey)
        PDI.Data:AddFeedKill(killerChar, killerDisplay, killerAl)
        -- full event record (time, campaign, place, both players) for matching across players later
        PDI.Data:AddKillEvent({
            loc = PDI.CleanName(killLocation) or killLocation, here = isKillLocation and true or nil,
            ka = killerDisplay, kc = killerChar, kal = killerAl, kr = killerRank,
            va = victimDisplay, vc = victimChar, val = victimAl, vr = victimRank,
        })
    end

    local iAmKiller = (killerDisplay and killerDisplay == myAccount) or (killerChar and killerChar == myChar)
    local iAmVictim = (victimDisplay and victimDisplay == myAccount) or (victimChar and victimChar == myChar)

    if iAmKiller then
        recordMine(victimChar, victimDisplay, victimAl, "k", true, "feed-me")
    elseif iAmVictim then
        recordDeath(killerChar, killerDisplay, killerAl)
    elseif victimChar then
        local dmg = recentDamaged[victimChar]
        if (dmg and nowMs() - dmg.t <= PDI.ASSIST_WINDOW_MS) or hasDeath(victimChar) then
            recordMine(victimChar, victimDisplay, victimAl, "a", true, "feed-other:" .. tostring(killerDisplay or killerChar))
        end
    end
    refreshUI()
end

---------------------------------------------------------------------------
-- Combat events
---------------------------------------------------------------------------
-- Outgoing: remember who we damaged (for assists); fallback killing blows if kill feed is off
local function OnOutgoing(_, result, isError, abilityName, _, _, sourceName, sourceType,
                          targetName, targetType, hitValue)
    if isError or not PDI.ShouldTrack() then return end
    if not OUTGOING_DAMAGE[result] then return end
    local victim = PDI.CleanName(targetName)
    if not victim or victim == myChar then return end
    local isPlayer = PDI.LooksLikePlayerRaw(targetName) or isKnownPlayer(victim)
    recentDamaged[victim] = { t = nowMs(), player = isPlayer }

    if result == ACTION_RESULT_KILLING_BLOW and isPlayer then
        -- Kills are only ever taken from the kill feed ("killed by you"). Our own KILLING_BLOW result
        -- also fires when a group member's hit actually got the kill, so here it's an assist at most;
        -- the kill feed upgrades it to a kill when it names you as the killer.
        guessAssist(victim)
    end
end

-- Burning + Chilled + Concussion from one player at the same time = Elemental Susceptibility
-- (the Destruction Staff skill applies all three together)
local STATUS = { burning = "b", chilled = "c", concussion = "z", concussed = "z" }
local statusSeen = {}
local ES_WINDOW_MS = 1500
noteStatus = function(attacker, abilityName, abilityId)
    if not attacker then statusSeen = {}; return end
    local name = PDI.CleanName(abilityName)
    if (not name or name == "") and abilityId and abilityId > 0 then name = PDI.CleanName(GetAbilityName(abilityId)) end
    local k = name and STATUS[string.lower(name)]
    if not k then return end
    local now = nowMs()
    local e = statusSeen[attacker]
    if not e then e = {}; statusSeen[attacker] = e end
    for kk, t in pairs(e) do if now - t > ES_WINDOW_MS then e[kk] = nil end end
    e[k] = now
    if e.b and e.c and e.z and now - math.min(e.b, e.c, e.z) <= ES_WINDOW_MS then
        statusSeen[attacker] = nil
        PDI.Data:RecordIncoming(attacker, nil, "Elemental Susceptibility", "eff", 0)
    end
end

-- Incoming: what enemy players use against you (feature 3)
local function OnIncoming(_, result, isError, abilityName, _, _, sourceName, sourceType,
                          targetName, targetType, hitValue, _, _, _, _, _, abilityId)
    if isError then return end
    local ty = INCOMING[result]
    if not ty then return end
    if sourceType ~= COMBAT_UNIT_TYPE_OTHER then return end -- ignore self, group, pets of ours
    local attacker = PDI.CleanName(sourceName)
    if not attacker or attacker == myChar then return end
    if not (PDI.LooksLikePlayerRaw(sourceName) or isKnownPlayer(attacker)) then return end
    if not isEnemyCandidate(attacker) then return end
    -- buffs/debuff "effects" can come from friendly players (heals, Major buffs on you); only keep
    -- them from someone who has already damaged / crowd-controlled you
    if ty == "eff" and not PDI.Data:IsHostile(attacker) then return end

    PDI.Data:RecordIncoming(attacker, abilityId, abilityName, ty, hitValue)
    noteStatus(attacker, abilityName, abilityId)

    if ty == "kb" then
        zo_callLater(function()
            local acct = PDI.Data:GetAccount(attacker)
            if not wasRecorded("death:" .. attacker) and not (acct and wasRecorded("death:" .. acct)) then
                recordDeath(attacker, acct, nil)
            end
        end, PDI.FALLBACK_DELAY_MS)
    end
end

-- Deaths near you: fallback assist detection when the kill feed is disabled
local function OnDied(_, result, isError, _, _, _, _, _, targetName)
    if isError or not PDI.ShouldTrack() then return end
    local victim = PDI.CleanName(targetName)
    if not victim then return end
    local dmg = recentDamaged[victim]
    if not dmg or not dmg.player or nowMs() - dmg.t > PDI.ASSIST_WINDOW_MS then return end
    guessAssist(victim)
end

-- Duels: the loser never really dies and the kill feed doesn't report it, so the duel result
-- decides. Winning counts as a kill (it replaces any assist guessed from combat events), losing
-- counts as being killed by them. A forfeit counts as neither.
local function OnDuelFinished(_, duelResult, wasLocalPlayersResult, oppChar, oppDisplay, oppAl)
    if duelResult ~= DUEL_RESULT_WON then return end
    oppChar = PDI.CleanName(oppChar)
    oppDisplay = PDI.NormalizeAccount(oppDisplay)
    if not (oppChar or oppDisplay) then return end
    PDI.Data:LearnName(oppChar, oppDisplay, oppAl)
    if wasLocalPlayersResult then
        recordMine(oppChar, oppDisplay, oppAl, "k", true, "duel")
        -- kept in the kill event log too (marked as a duel: never counted in public stats, only used to
        -- check that your own kill counts match your events)
        PDI.Data:AddKillEvent({
            duel = true, ka = PDI.NormalizeAccount(GetDisplayName()), kc = PDI.CleanName(GetUnitName("player")),
            kal = GetUnitAlliance("player"), va = oppDisplay, vc = oppChar, val = oppAl,
        })
    else
        recordDeath(oppChar, oppDisplay, oppAl)
    end
end

---------------------------------------------------------------------------
-- Reticle scan: @account, faction, class, max health, mundus
---------------------------------------------------------------------------
local function scanMundus(unit)
    local list = {}
    for i = 1, GetNumBuffs(unit) do
        local buffName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unit, i)
        local m = PDI.MUNDUS_IDS[abilityId]
        if not m and buffName and buffName:find("^Boon") then
            m = zo_strformat("<<1>>", buffName):gsub("^Boon:%s*", "")
        end
        if m then list[#list + 1] = m end
    end
    return list
end

-- The effects of the Monomyth Reforged ring (a mythic with no buff of its own): the ring shows as one of
-- two sets of 3 Major/Minor effects. Recorded apart from the buffs (those skip Major/Minor and debuffs).
local function scanMonomyth(unit)
    local out
    for i = 1, GetNumBuffs(unit) do
        local name, started, ending = GetUnitBuffInfo(unit, i)
        local n = name and name ~= "" and zo_strformat("<<1>>", name)
        if n and PDI.Skills.MONOMYTH_EFFECTS[n] then
            out = out or {}
            out[n] = ((ending or 0) - (started or 0)) <= 0     -- true = permanent
        end
    end
    return out
end

-- Buffs worth showing: no mundus (shown separately), no Minor/Major buffs, no debuffs
local function scanBuffs(unit)
    local buffs = {}
    for i = 1, GetNumBuffs(unit) do
        local name, started, ending, _, _, _, _, effectType, _, _, abilityId = GetUnitBuffInfo(unit, i)
        if name and name ~= "" and not PDI.MUNDUS_IDS[abilityId] and not name:find("^Boon")
            and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
            local n = zo_strformat("<<1>>", name)
            if not n:find("^Minor ") and not n:find("^Major ") then
                buffs[n] = { id = abilityId, perm = ((ending or 0) - (started or 0)) <= 0 }
            end
        end
    end
    return buffs
end

local function readHealth(unit)
    local _, maxHp = GetUnitPower(unit, HEALTH)
    return maxHp
end

local function ScanReticle()
    local unit = "reticleover"
    if not DoesUnitExist(unit) or not IsUnitPlayer(unit) then return end
    if AreUnitsEqual and AreUnitsEqual(unit, "player") then return end
    local char = PDI.CleanName(GetUnitName(unit))
    local acct = PDI.NormalizeAccount(GetUnitDisplayName(unit))
    if not char then return end
    local al = GetUnitAlliance(unit)
    PDI.Data:LearnName(char, acct, al)

    -- profile for anyone you target, friend or foe (used by Kill Feed / My Kills details)
    if PDI.ShouldTrack() or PDI.InPvPArea() then
        local race = GetUnitRace and GetUnitRace(unit)
        PDI.Data:RecordPlayerProfile(char, acct, {
            al = al, cls = GetUnitClassId(unit), race = race and zo_strformat("<<1>>", race) or nil,
            cp = GetUnitChampionPoints and GetUnitChampionPoints(unit) or nil,
            hp = readHealth(unit), mundus = scanMundus(unit), buffs = scanBuffs(unit), mm = scanMonomyth(unit),
        })
    end

    local enemy = IsUnitAttackable(unit) and isEnemyCandidate(char)
    if enemy then
        PDI.Data:RecordProfile(char, acct, al, GetUnitClassId(unit), readHealth(unit), scanMundus(unit))
    end
    -- read health once more a moment later, when the target's stats have synced
    zo_callLater(function()
        if DoesUnitExist(unit) and PDI.CleanName(GetUnitName(unit)) == char then
            local hp2 = readHealth(unit)
            PDI.Data:RecordPlayerProfile(char, acct, { hp = hp2 })
            if enemy then PDI.Data:RecordProfile(char, acct, al, nil, hp2, nil) end
        end
    end, 400)
end

local function OnPowerUpdate(_, unitTag, _, powerType, _, powerMax)
    if unitTag ~= "reticleover" or powerType ~= HEALTH then return end
    if not IsUnitPlayer(unitTag) or not IsUnitAttackable(unitTag) then return end
    local char = PDI.CleanName(GetUnitName(unitTag))
    if not isEnemyCandidate(char) then return end
    PDI.Data:RecordProfile(char, GetUnitDisplayName(unitTag), GetUnitAlliance(unitTag), nil, powerMax, nil)
end

---------------------------------------------------------------------------
function Tracker:Init()
    myAccount = PDI.NormalizeAccount(GetDisplayName())
    myChar = PDI.CleanName(GetUnitName("player"))

    if EVENT_PVP_KILL_FEED_DEATH then
        EM:RegisterForEvent(NS .. "KillFeed", EVENT_PVP_KILL_FEED_DEATH, OnKillFeed)
    else
        PDI.Msg("Kill feed API not found - using combat-event fallback only.")
    end

    EM:RegisterForEvent(NS .. "Out", EVENT_COMBAT_EVENT, OnOutgoing)
    EM:AddFilterForEvent(NS .. "Out", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NS .. "In", EVENT_COMBAT_EVENT, OnIncoming)
    EM:AddFilterForEvent(NS .. "In", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    for i, r in ipairs({ ACTION_RESULT_DIED, ACTION_RESULT_DIED_XP }) do
        EM:RegisterForEvent(NS .. "Died" .. i, EVENT_COMBAT_EVENT, OnDied)
        EM:AddFilterForEvent(NS .. "Died" .. i, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, r)
    end

    EM:RegisterForEvent(NS .. "Reticle", EVENT_RETICLE_TARGET_CHANGED, ScanReticle)
    if EVENT_DUEL_FINISHED then EM:RegisterForEvent(NS .. "Duel", EVENT_DUEL_FINISHED, OnDuelFinished) end
    -- (health is read when you target someone; continuous power updates gave inflated values)

    EM:RegisterForUpdate(NS .. "Cleanup", 30000, cleanup)

    rebuildGroupChars()
    for _, ev in ipairs({ EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT, EVENT_GROUP_UPDATE, EVENT_PLAYER_ACTIVATED }) do
        EM:RegisterForEvent(NS .. "Roster" .. ev, ev, function() zo_callLater(rebuildGroupChars, 500) end)
    end
end
