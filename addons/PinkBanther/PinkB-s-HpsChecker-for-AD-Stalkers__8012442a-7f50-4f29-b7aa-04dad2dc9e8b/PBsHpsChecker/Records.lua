PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- Records: what the player healed, whom, with what, and how fast
--
-- Every heal the player does is one EVENT_COMBAT_EVENT with the player as the source. It is
-- counted three ways at once:
--
--   * under the day it happened (sv.days), which is what the statistics are read from;
--   * in the fight it belongs to (records.fight), which is what the HUD shows while it goes on;
--   * as a share of "who was healed": the party, everybody else, or the player themself.
--
-- The kind of target comes from the event itself (targetType): COMBAT_UNIT_TYPE_GROUP is a member
-- of the player's group, COMBAT_UNIT_TYPE_PLAYER is the player, and anything else is somebody
-- outside the group.
--
--   sv.days["<day>"] = {
--       heal, over, hits, crits, ticks   amount healed, overheal, number of heals, crits, HoT ticks
--       group, other, self               amount healed, by who was healed
--       secs, fights                     time spent healing, number of fights
--       bestHps, bestHeal                best fight HPS (fights of MIN_BEST_SECS or more), biggest heal
--       targets = { amount = {}, count = {}, group = {} }   who was healed (never the player); group[name] is
--                                                           the part of it healed while the target was in the party
--       skills  = { amount = {}, count = {} }               with which ability, keyed by ability id
--       recv = { amount = {}, count = {} }                  what OTHER healers healed party members for, by
--                                                           member (heals the player cast are not in it)
--       recvOthers, recvHits             the same, in total: amount and number of heals
--       dropped                          amount healed to players who fell off the target list
--   }
--   sv.names["<ability id>"] = "ability name"
--   sv.fights = { { day, clock, secs, heal, over, hps, people, top, group, other, self }, ... }
--
-- HPS is the amount healed over the time spent healing: from a fight's first heal to its last,
-- plus one second so that a fight of a single heal does not divide by nothing. A fight ends when
-- no heal has come for sv.gapSec seconds.
---------------------------------------------------------------------------------------------------

local records = {}
ADDON.records = records

-- Days kept. Older ones are dropped at login, so the saved file cannot grow for ever.
local RETAIN_DAYS = 60
-- Targets and skills kept per day. A day's list is cut back to its largest entries when it grows
-- past these; what was cut is still in the day's totals and in `dropped`.
local MAX_TARGETS_PER_DAY = 60
local MAX_SKILLS_PER_DAY = 40
-- Party members listed under what other healers did for them: a party is at most a couple of dozen,
-- but a day can have several.
local MAX_RECV_PER_DAY = 100
local PRUNE_KEEP = 0.8
local MAX_FIGHTS = 40
-- The HUD's short-term HPS looks back this many seconds.
local RING_SECONDS = 10
-- A fight shorter than this is not a candidate for "best HPS": one big heal is not a rate.
local MIN_BEST_SECS = 10
local DAY_CACHE_MS = 5000
local PRUNE_EVERY_MS = 60000

local KIND_GROUP, KIND_OTHER, KIND_SELF = "group", "other", "self"
records.KIND_GROUP, records.KIND_OTHER, records.KIND_SELF = KIND_GROUP, KIND_OTHER, KIND_SELF
records.MIN_BEST_SECS = MIN_BEST_SECS
records.RING_SECONDS = RING_SECONDS
records.RETAIN_DAYS = RETAIN_DAYS

local sv
local names

-- What a ranking calls a player. The character name is all the heal events give; Names.lua replaces
-- this with one that knows the PSN IDs it has learned. onClear is run when the records are cleared.
records.DisplayName = function(name)
    return name
end
records.onClear = nil

local function L(id)
    return GetString(id)
end

---------------------------------------------------------------------------------------------------
-- Which day it is
--
-- Taken from PB's KillLog (Records.lua), which has it from PB's Omikuji: this client has no
-- GetDate(), only GetTimeStamp() (UTC) and GetSecondsSinceMidnight() (local wall time). Dividing the
-- timestamp by 86400 would roll the day over at 09:00 in Japan, in the middle of an evening's play,
-- so the day number is chosen by asking which timezone offset the two clocks imply.
---------------------------------------------------------------------------------------------------

local SECONDS_PER_DAY = 86400
local SNAP = 900
local OFFSET_MAX = 13 * 3600
local OFFSET_MIN = -11 * 3600

-- Days since 1970-01-01, on the player's own clock.
function records:DayKey()
    local stamp = GetTimeStamp and GetTimeStamp() or 0
    local sinceMidnight = GetSecondsSinceMidnight and GetSecondsSinceMidnight() or 0
    if type(stamp) ~= "number" or type(sinceMidnight) ~= "number" then
        return 0
    end

    local day = math.floor(stamp / SECONDS_PER_DAY)
    local offset = sinceMidnight - (stamp % SECONDS_PER_DAY)
    offset = math.floor(offset / SNAP + 0.5) * SNAP

    if offset <= OFFSET_MIN then
        day = day + 1
    elseif offset > OFFSET_MAX then
        day = day - 1
    end
    return day
end

-- Howard Hinnant's civil-from-days. z is days since 1970-01-01; returns year, month, day.
function records:CivilFromDays(z)
    z = math.floor(z) + 719468
    local era = math.floor(z / 146097)
    local dayOfEra = z - era * 146097
    local yearOfEra = math.floor((dayOfEra
        - math.floor(dayOfEra / 1460)
        + math.floor(dayOfEra / 36524)
        - math.floor(dayOfEra / 146096)) / 365)
    local year = yearOfEra + era * 400
    local dayOfYear = dayOfEra - (365 * yearOfEra
        + math.floor(yearOfEra / 4)
        - math.floor(yearOfEra / 100))
    local monthPrime = math.floor((5 * dayOfYear + 2) / 153)
    local day = dayOfYear - math.floor((153 * monthPrime + 2) / 5) + 1
    local month = monthPrime + (monthPrime < 10 and 3 or -9)
    if month <= 2 then
        year = year + 1
    end
    return year, month, day
end

-- 1970-01-01 was a Thursday, so day 0 is index 4 counting Sunday as 0.
function records:WeekdayName(dayKey)
    local list = {}
    for name in tostring(L(SI_PBSHPS_WEEKDAYS)):gmatch("[^,]+") do
        list[#list + 1] = name
    end
    return list[(math.floor(dayKey) + 4) % 7 + 1] or ""
end

function records:DateText(dayKey)
    local year, month, day = self:CivilFromDays(dayKey)
    return string.format("%04d/%02d/%02d(%s)", year, month, day, self:WeekdayName(dayKey))
end

-- A month as one number, 202610 for October 2026.
function records:MonthKey(dayKey)
    local year, month = self:CivilFromDays(dayKey)
    return year * 100 + month
end

function records:MonthText(monthKey)
    return string.format(L(SI_PBSHPS_MONTH_FORMAT), math.floor(monthKey / 100), monthKey % 100)
end

---------------------------------------------------------------------------------------------------
-- Numbers as text
---------------------------------------------------------------------------------------------------

local function Commas(number)
    local text = string.format("%d", math.floor((number or 0) + 0.5))
    local replaced
    repeat
        text, replaced = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until replaced == 0
    return text
end
records.Commas = Commas

-- fraction is 0 to 1. One decimal, so that the three shares of "who was healed" read as the ratio
-- they are; a share that is not zero is never shown as 0.
local function Percent(fraction, decimals)
    if not fraction then
        return "-"
    end
    decimals = decimals or 0
    local text = string.format("%." .. decimals .. "f", fraction * 100)
    if fraction > 0 and tonumber(text) == 0 then
        return "<" .. string.format("%." .. decimals .. "f", 10 ^ -decimals) .. "%"
    end
    return text .. "%"
end
records.Percent = Percent

local function Duration(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
    end
    return string.format("%d:%02d", minutes, seconds % 60)
end
records.Duration = Duration

-- "Name^Mx" (the raw form, with its gender mark) and "Name" are the same player.
local function Plain(name)
    return (tostring(name or ""):gsub("%^.*$", ""))
end

---------------------------------------------------------------------------------------------------
-- Tallies: how much, and how many times, per key
---------------------------------------------------------------------------------------------------

local function NewTally(withGroup)
    local tally = { amount = {}, count = {} }
    if withGroup then
        tally.group = {}
    end
    return tally
end

-- Returns true when the key was not in the tally yet.
local function TallyAdd(tally, key, amount)
    local current = tally.amount[key]
    tally.amount[key] = (current or 0) + amount
    tally.count[key] = (tally.count[key] or 0) + 1
    return current == nil
end

local function TallySize(tally)
    local size = 0
    for _ in pairs(tally.amount) do
        size = size + 1
    end
    return size
end

-- Cuts a tally that has grown past max back to PRUNE_KEEP of max, dropping the smallest entries
-- (cutting to exactly max would cut again after every heal). Returns the amount that was dropped.
local function TallyPrune(tally, max)
    if TallySize(tally) <= max then
        return 0
    end
    local keys = {}
    for key in pairs(tally.amount) do
        keys[#keys + 1] = key
    end
    local amount = tally.amount
    table.sort(keys, function(a, b)
        if amount[a] ~= amount[b] then
            return amount[a] < amount[b]
        end
        return tostring(a) < tostring(b)
    end)
    local dropped = 0
    for index = 1, #keys - math.floor(max * PRUNE_KEEP) do
        local key = keys[index]
        dropped = dropped + amount[key]
        amount[key] = nil
        tally.count[key] = nil
        if tally.group then
            tally.group[key] = nil
        end
    end
    return dropped
end

---------------------------------------------------------------------------------------------------
-- The data
---------------------------------------------------------------------------------------------------

local NUMBER_FIELDS = { "heal", "over", "hits", "crits", "ticks", "group", "other", "self", "secs", "fights", "bestHps", "bestHeal", "dropped", "recvOthers", "recvHits" }

local function NewDay()
    local day = { targets = NewTally(true), skills = NewTally(false), recv = NewTally(false) }
    for _, field in ipairs(NUMBER_FIELDS) do
        day[field] = 0
    end
    return day
end

local function NormalizeTally(tally, withGroup)
    if type(tally) ~= "table" then
        return NewTally(withGroup)
    end
    for _, part in ipairs({ "amount", "count" }) do
        if type(tally[part]) ~= "table" then
            tally[part] = {}
        end
    end
    if withGroup and type(tally.group) ~= "table" then
        tally.group = {}
    end
    return tally
end

-- Saved data that is missing a piece, or was edited by hand, must not be able to break the panel.
local function NormalizeDay(day)
    for _, field in ipairs(NUMBER_FIELDS) do
        day[field] = tonumber(day[field]) or 0
    end
    day.targets = NormalizeTally(day.targets, true)
    day.skills = NormalizeTally(day.skills, false)
    day.recv = NormalizeTally(day.recv, false)
    -- group[name] used to be a flag; it is the amount healed as a party member now.
    for name, value in pairs(day.targets.group) do
        if type(value) ~= "number" then
            day.targets.group[name] = day.targets.amount[name]
        end
    end
end

local currentKey, currentDay, currentAt

function records:Day(dayKey, create)
    local key = tostring(dayKey)
    local day = sv.days[key]
    if not day and create then
        day = NewDay()
        sv.days[key] = day
    end
    return day
end

-- The recorded days, newest first, as numbers.
function records:DayKeys()
    local keys = {}
    for key in pairs(sv.days) do
        local number = tonumber(key)
        if number then
            keys[#keys + 1] = number
        end
    end
    table.sort(keys, function(a, b) return a > b end)
    return keys
end

-- Today's record, created if need be. The day is looked up again every few seconds, not on every
-- heal: it can only change at midnight.
local function Today(nowMs)
    if not currentDay or nowMs < currentAt or nowMs - currentAt >= DAY_CACHE_MS then
        currentAt = nowMs
        local key = records:DayKey()
        if key ~= currentKey or not currentDay or sv.days[tostring(key)] ~= currentDay then
            currentKey = key
            currentDay = records:Day(key, true)
        end
    end
    return currentDay, currentKey
end

---------------------------------------------------------------------------------------------------
-- Fights
---------------------------------------------------------------------------------------------------

-- The fight that is going on, and the last one that ended.
records.fight = nil
records.lastFight = nil

-- Keeps one day's lists short. Returns nothing; what falls off the target list is added to `dropped`.
local function PruneDay(day)
    day.dropped = day.dropped + TallyPrune(day.targets, MAX_TARGETS_PER_DAY)
    TallyPrune(day.skills, MAX_SKILLS_PER_DAY)
    TallyPrune(day.recv, MAX_RECV_PER_DAY)
end

local function GapMs()
    return (tonumber(sv and sv.gapSec) or 10) * 1000
end

local function NewFight(nowMs, dayKey)
    return {
        first = nowMs,
        last = nowMs,
        dayKey = dayKey,
        secs = 1,
        heal = 0, over = 0, hits = 0, crits = 0,
        group = 0, other = 0, self = 0,
        recvOthers = 0, recvHits = 0,
        people = 0,
        targets = NewTally(false),
        ringSec = {},
        ringAmount = {},
    }
end

-- hit and over are what the event says; the two meanings are decided here and only here. UNMEASURED
-- on console: hitValue is taken as what the heal did and overflow as what it would have healed beyond
-- full health. /hps debug prints both numbers for every heal, which is how to settle it.
function records.ReadAmounts(hitValue, overflow)
    return tonumber(hitValue) or 0, tonumber(overflow) or 0
end

function records:CloseFight(nowMs)
    local fight = self.fight
    if not fight then
        return
    end
    self.fight = nil
    fight.closedMs = nowMs or fight.last
    fight.hps = fight.heal / math.max(1, fight.secs)

    local day = self:Day(fight.dayKey, true)
    if fight.secs >= MIN_BEST_SECS and fight.hps > day.bestHps then
        day.bestHps = fight.hps
    end
    PruneDay(day)

    local top, topAmount
    for name, amount in pairs(fight.targets.amount) do
        if not topAmount or amount > topAmount or (amount == topAmount and name < top) then
            top, topAmount = name, amount
        end
    end
    local clock = ((GetSecondsSinceMidnight and GetSecondsSinceMidnight() or 0) - ((fight.closedMs - fight.last) / 1000)) % SECONDS_PER_DAY
    sv.fights[#sv.fights + 1] = {
        day = fight.dayKey,
        clock = math.floor(clock),
        secs = fight.secs,
        heal = fight.heal,
        over = fight.over,
        hps = fight.hps,
        people = fight.people,
        top = top,
        group = fight.group,
        other = fight.other,
        self = fight.self,
    }
    while #sv.fights > MAX_FIGHTS do
        table.remove(sv.fights, 1)
    end
    self.lastFight = fight
end

-- Called about once a second: ends a fight that has gone quiet, and keeps today's lists short even
-- in a fight that does not end for an hour.
local lastPruneAt = 0
function records:Tick(nowMs)
    local fight = self.fight
    if not fight then
        return
    end
    if nowMs - fight.last > GapMs() then
        self:CloseFight(nowMs)
    elseif nowMs - lastPruneAt >= PRUNE_EVERY_MS then
        lastPruneAt = nowMs
        local day = self:Day(fight.dayKey, true)
        PruneDay(day)
    end
end

-- Zone change, logout: the fight is over whether or not the gap has passed.
function records:Flush(nowMs)
    self:CloseFight(nowMs)
end

---------------------------------------------------------------------------------------------------
-- Recording a heal
---------------------------------------------------------------------------------------------------

-- kind is KIND_GROUP, KIND_OTHER or KIND_SELF. Returns true if the heal was counted.
function records:RecordHeal(nowMs, kind, targetName, abilityId, abilityName, hit, over, crit, tick)
    if hit <= 0 and over <= 0 then
        return false
    end
    local day, dayKey = Today(nowMs)

    local fight = self.fight
    if fight and nowMs - fight.last > GapMs() then
        self:CloseFight(nowMs)
        fight = nil
    end
    if not fight then
        fight = NewFight(nowMs, dayKey)
        self.fight = fight
        day.fights = day.fights + 1
        day.secs = day.secs + fight.secs
    else
        local seconds = math.max(0, nowMs - fight.last) / 1000
        fight.secs = fight.secs + seconds
        day.secs = day.secs + seconds
        fight.last = nowMs
        fight.dayKey = dayKey
    end

    day.heal = day.heal + hit
    day.over = day.over + over
    day.hits = day.hits + 1
    day[kind] = day[kind] + hit
    fight.heal = fight.heal + hit
    fight.over = fight.over + over
    fight.hits = fight.hits + 1
    fight[kind] = fight[kind] + hit
    if crit then
        day.crits = day.crits + 1
        fight.crits = fight.crits + 1
    end
    if tick then
        day.ticks = day.ticks + 1
    end
    if hit > day.bestHeal then
        day.bestHeal = hit
    end

    if kind ~= KIND_SELF then
        local name = Plain(targetName)
        if name == "" then
            name = "?"
        end
        TallyAdd(day.targets, name, hit)
        if kind == KIND_GROUP then
            day.targets.group[name] = (day.targets.group[name] or 0) + hit
        end
        if TallyAdd(fight.targets, name, hit) then
            fight.people = fight.people + 1
        end
    end

    local skillKey = tostring(abilityId or 0)
    TallyAdd(day.skills, skillKey, hit)
    if abilityName and abilityName ~= "" then
        names[skillKey] = Plain(abilityName)
    end

    local second = math.floor(nowMs / 1000)
    local slot = second % RING_SECONDS + 1
    if fight.ringSec[slot] ~= second then
        fight.ringSec[slot] = second
        fight.ringAmount[slot] = 0
    end
    fight.ringAmount[slot] = fight.ringAmount[slot] + hit
    return true
end

-- A heal somebody ELSE did to a party member, as the engine delivers it (target type GROUP, source
-- not the player). It is kept apart from the player's own heals, which are never in here, so that
-- "the player's share of what a party member received" is hers / (hers + this). It does not open or
-- extend a fight: the player's HPS is about the player's healing. Returns true if it was counted.
function records:RecordReceived(nowMs, targetName, hit)
    if hit <= 0 then
        return false
    end
    local day = Today(nowMs)
    local name = Plain(targetName)
    if name == "" then
        name = "?"
    end
    TallyAdd(day.recv, name, hit)
    day.recvOthers = day.recvOthers + hit
    day.recvHits = day.recvHits + 1
    local fight = self.fight
    if fight then
        fight.recvOthers = fight.recvOthers + hit
        fight.recvHits = fight.recvHits + 1
    end
    return true
end

-- The player's share of what party members received, 0 to 1: hers over hers plus everybody else's that
-- reached the add-on. When none of anybody else's has reached it that is all of it, 100% (it was first
-- "unknown" in that case, so that a game that sends nothing could not read as "all of it was hers";
-- PB chose 100%, and /hps status shows whether other healers' heals arrive at all). nil only when no
-- party member was healed by anybody, which has no share.
function records.PartyShare(group, recvOthers)
    local total = group + recvOthers
    if total <= 0 then
        return nil
    end
    return group / total
end

-- The fight's HPS over its whole length, and over the last RING_SECONDS.
function records:FightHps(fight)
    return fight.heal / math.max(1, fight.secs)
end

function records:RecentHps(fight, nowMs)
    local second = math.floor(nowMs / 1000)
    local sum = 0
    for slot = 1, RING_SECONDS do
        local when = fight.ringSec[slot]
        if when and when > second - RING_SECONDS and when <= second then
            sum = sum + fight.ringAmount[slot]
        end
    end
    local span = math.min(RING_SECONDS, math.max(1, (nowMs - fight.first) / 1000))
    return sum / span
end

---------------------------------------------------------------------------------------------------
-- Periods
--
-- A period ("scope") is what a statistic is taken over:
--   "today"      the day it is when the question is asked
--   "thismonth"  every recorded day of this month
--   "all"        every recorded day (RETAIN_DAYS of them, at most)
--   a day number the day (a string of digits works too)
--   "m202610"    every recorded day of that month
---------------------------------------------------------------------------------------------------

function records:ScopeDays(scope)
    local days = {}
    scope = scope or "all"
    if scope == "all" then
        for _, day in pairs(sv.days) do
            days[#days + 1] = day
        end
    elseif scope == "today" then
        local day = sv.days[tostring(self:DayKey())]
        if day then
            days[1] = day
        end
    elseif scope == "thismonth" or tostring(scope):match("^m%d+$") then
        local month = scope == "thismonth" and self:MonthKey(self:DayKey()) or tonumber(tostring(scope):sub(2))
        for key, day in pairs(sv.days) do
            local number = tonumber(key)
            if number and self:MonthKey(number) == month then
                days[#days + 1] = day
            end
        end
    else
        local day = sv.days[tostring(scope)]
        if day then
            days[1] = day
        end
    end
    return days
end

-- The periods that can be chosen, in the order a list shows them.
local MAX_LISTED_DAYS = 30

function records:ScopeList(maxDays)
    maxDays = maxDays or MAX_LISTED_DAYS
    local list = { "today", "thismonth", "all" }
    local todayKey = self:DayKey()
    local thisMonth = self:MonthKey(todayKey)
    local keys = self:DayKeys()
    local seenMonth = {}
    for _, key in ipairs(keys) do
        local month = self:MonthKey(key)
        if month ~= thisMonth and not seenMonth[month] then
            seenMonth[month] = true
            list[#list + 1] = "m" .. month
        end
    end
    local listed = 0
    for _, key in ipairs(keys) do
        if key ~= todayKey and listed < maxDays then
            listed = listed + 1
            list[#list + 1] = key
        end
    end
    return list
end

function records:ScopeText(scope)
    if scope == "today" then
        return L(SI_PBSHPS_SCOPE_TODAY)
    elseif scope == "thismonth" then
        return L(SI_PBSHPS_SCOPE_THISMONTH)
    elseif scope == "all" or scope == nil then
        return string.format(L(SI_PBSHPS_SCOPE_ALL), RETAIN_DAYS)
    elseif tostring(scope):match("^m%d+$") then
        return self:MonthText(tonumber(tostring(scope):sub(2)))
    end
    return self:DateText(tonumber(scope) or 0)
end

---------------------------------------------------------------------------------------------------
-- Statistics
---------------------------------------------------------------------------------------------------

-- Scratch tables for Top, reused so that the statistics screen, which asks every few seconds, does
-- not leave a table per player behind each time.
local scratchAmount, scratchCount, scratchGroup, scratchRecv = {}, {}, {}, {}

local function Clear(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function Beats(amount, name, entry)
    return amount > entry.amount or (amount == entry.amount and name < entry.name)
end

-- Adds up one kind of tally ("targets" or "skills") over the days of a period into the scratch
-- tables (for "targets", also what other healers did for each party member). Returns the amount healed to players who fell off the days' target lists.
local function Collect(kind, days)
    Clear(scratchAmount)
    Clear(scratchCount)
    Clear(scratchGroup)
    Clear(scratchRecv)
    local dropped = 0
    for _, day in ipairs(days) do
        local tally = day[kind]
        for key, value in pairs(tally.amount) do
            scratchAmount[key] = (scratchAmount[key] or 0) + value
            scratchCount[key] = (scratchCount[key] or 0) + (tally.count[key] or 0)
            if tally.group and tally.group[key] then
                -- the part of it healed while the target was in the party
                scratchGroup[key] = (scratchGroup[key] or 0) + tally.group[key]
            end
        end
        if kind == "targets" then
            for key, value in pairs(day.recv.amount) do
                scratchRecv[key] = (scratchRecv[key] or 0) + value
            end
        end
        dropped = dropped + day.dropped
    end
    return dropped
end

-- Adds up the days of a period: the amounts, the time, the shares. Cheap, and what a list of periods
-- is made of. Returns the totals and the days they were made from.
function records:Totals(scope)
    local total = {}
    for _, field in ipairs(NUMBER_FIELDS) do
        total[field] = 0
    end
    local days = self:ScopeDays(scope)
    for _, day in ipairs(days) do
        for _, field in ipairs(NUMBER_FIELDS) do
            if field == "bestHps" or field == "bestHeal" then
                total[field] = math.max(total[field], day[field])
            else
                total[field] = total[field] + day[field]
            end
        end
    end
    total.days = #days
    total.hps = total.secs > 0 and total.heal / total.secs or 0
    -- The shares of the amount healed: who it went to.
    if total.heal > 0 then
        total.groupShare = total.group / total.heal
        total.otherShare = total.other / total.heal
        total.selfShare = total.self / total.heal
    end
    -- The player's share of everything party members received.
    total.partyShare = records.PartyShare(total.group, total.recvOthers)
    -- Overheal as a share of everything the heals would have done.
    local potential = total.heal + total.over
    total.overShare = potential > 0 and total.over / potential or nil
    total.critShare = total.hits > 0 and total.crits / total.hits or nil
    return total, days
end

-- The totals, and how many different players the amount went to, inside the party and outside it.
function records:Summary(scope)
    local total, days = self:Totals(scope)
    -- Only the players still on a day's list are known, so `outsideCut` says that the number outside the
    -- party is a floor (the party is at most a couple of dozen and always among the biggest, so never cut).
    Collect("targets", days)
    total.groupPeople, total.otherPeople = 0, 0
    for key in pairs(scratchAmount) do
        if scratchGroup[key] then
            total.groupPeople = total.groupPeople + 1
        else
            total.otherPeople = total.otherPeople + 1
        end
    end
    total.outsideCut = total.dropped > 0
    return total
end

-- The largest `limit` entries of a kind ("targets" or "skills") over a period, as
-- { name, amount, count, group, partyAmount, recvAmount }, largest first. Also returns the amount healed to players that fell
-- off the days' target lists, and how many distinct entries there were.
function records:Top(kind, scope, limit)
    limit = limit or 10
    local dropped = Collect(kind, self:ScopeDays(scope))

    local top, size = {}, 0
    for key, value in pairs(scratchAmount) do
        size = size + 1
        local name = key
        if kind == "skills" then
            name = names[key] or key
        end
        if #top < limit or Beats(value, name, top[#top]) then
            local position = #top + 1
            while position > 1 and Beats(value, name, top[position - 1]) do
                position = position - 1
            end
            table.insert(top, position, {
                name = name, amount = value, count = scratchCount[key],
                group = scratchGroup[key] ~= nil, partyAmount = scratchGroup[key] or 0, recvAmount = scratchRecv[key] or 0,
            })
            if #top > limit then
                top[#top] = nil
            end
        end
    end
    return top, dropped, size
end

---------------------------------------------------------------------------------------------------
-- Statistics as lines of text
---------------------------------------------------------------------------------------------------

local function Row(id, ...)
    return string.format(L(id), ...)
end

-- The summary block: ten rows at most. Returns nothing but the "no records" row when the period
-- has no heals in it.
function records:SummaryLines(scope)
    local s = self:Summary(scope)
    if s.heal <= 0 and s.over <= 0 then
        return { L(SI_PBSHPS_NONE) }
    end
    local lines = {
        Row(SI_PBSHPS_ROW_HEAL, Commas(s.heal)),
        Row(SI_PBSHPS_ROW_HPS, Commas(s.hps)),
        Row(SI_PBSHPS_ROW_FIGHTS, Commas(s.fights), Duration(s.secs)),
        Row(SI_PBSHPS_ROW_BEST, s.bestHps > 0 and Commas(s.bestHps) or "-", Commas(s.bestHeal)),
        Row(SI_PBSHPS_ROW_CRIT, Percent(s.critShare, 1)),
        Row(SI_PBSHPS_ROW_OVER, Commas(s.over), Percent(s.overShare, 1)),
    }
    -- The party, everybody else, the player: three shares that add up to the whole.
    lines[#lines + 1] = Row(SI_PBSHPS_ROW_GROUP, Percent(s.groupShare, 1), Commas(s.group), tostring(s.groupPeople))
    lines[#lines + 1] = Row(SI_PBSHPS_ROW_OTHER, Percent(s.otherShare, 1), Commas(s.other),
        s.otherPeople .. (s.outsideCut and "+" or ""))
    lines[#lines + 1] = Row(SI_PBSHPS_ROW_SELF, Percent(s.selfShare, 1), Commas(s.self))
    -- Of what party members received from every healer, how much was the player's; "-" when no party
    -- member was healed at all.
    lines[#lines + 1] = s.partyShare and Row(SI_PBSHPS_ROW_PT_SHARE, Percent(s.partyShare, 1))
        or Row(SI_PBSHPS_ROW_PT_SHARE, L(SI_PBSHPS_PT_UNKNOWN))
    return lines
end

-- "1. Name  amount  [PT 72%]  share". The share at the end is of what went to others (not to the
-- player), for people, and of everything for skills. The tag is only on party members; its percentage
-- is the player's share of what that member received from every healer, and is left out when no
-- heal of anybody else's has reached the add-on. The least important part is last, because a long
-- name is cut short from the right.
function records:TopLines(kind, scope, limit)
    local top, dropped = self:Top(kind, scope, limit)
    if #top == 0 then
        return { L(SI_PBSHPS_NONE) }
    end
    local s = self:Summary(scope)
    local base = kind == "targets" and (s.group + s.other) or s.heal
    local lines = {}
    for index, entry in ipairs(top) do
        local tag = ""
        if kind == "targets" and entry.group then
            local share = records.PartyShare(entry.partyAmount, entry.recvAmount)
            tag = "  " .. (share and string.format(L(SI_PBSHPS_TAG_PARTY_SHARE), Percent(share, 0)) or L(SI_PBSHPS_TAG_PARTY))
        end
        local shown = kind == "targets" and records.DisplayName(entry.name) or entry.name
        lines[index] = string.format("%d. %s  %s%s  %s", index, shown, Commas(entry.amount), tag,
            Percent(base > 0 and entry.amount / base or nil, 1))
    end
    return lines
end

-- One row of the list of periods: the period, the amount, HPS, fights, time healing, how much of it
-- went to the party, and the player's share of what party members received (a dash where there is
-- nothing to share).
function records:PeriodColumns(scope)
    local total = self:Totals(scope)
    local healed = total.heal > 0
    return {
        self:ScopeText(scope),
        Commas(total.heal),
        Commas(total.hps),
        Commas(total.fights),
        Duration(total.secs),
        healed and Percent(total.groupShare, 1) or "-",
        total.partyShare and Percent(total.partyShare, 1) or "-",
    }
end

function records:FightCount()
    return #sv.fights
end

-- One row of the list of fights, 1 being the newest: when, how long, HPS, the amount, how many players,
-- how much of it went to the party, and the player healed most. nil past the end.
function records:FightColumns(index)
    local fight = sv.fights[#sv.fights - index + 1]
    if not fight then
        return nil
    end
    local _, month, day = self:CivilFromDays(fight.day or 0)
    local clock = fight.clock or 0
    local heal = fight.heal or 0
    return {
        string.format("%02d/%02d %02d:%02d", month, day, math.floor(clock / 3600), math.floor((clock % 3600) / 60)),
        Duration(fight.secs),
        Commas(fight.hps),
        Commas(heal),
        tostring(fight.people or 0),
        heal > 0 and Percent((fight.group or 0) / heal, 1) or "-",
        fight.top and records.DisplayName(fight.top) or "-",
    }
end

-- The longest each kind of row can get -- the biggest numbers, a long name, the longest wording --
-- for the statistics screen to measure against its column. A font is only used if all of these fit.
function records:WorstCaseLines()
    local share = string.format(L(SI_PBSHPS_TAG_PARTY_SHARE), "100%")
    return {
        Row(SI_PBSHPS_ROW_HEAL, "999,999,999"),
        Row(SI_PBSHPS_ROW_HPS, "99,999"),
        Row(SI_PBSHPS_ROW_FIGHTS, "999", "99:59:59"),
        Row(SI_PBSHPS_ROW_BEST, "99,999", "999,999"),
        Row(SI_PBSHPS_ROW_CRIT, "100.0%"),
        Row(SI_PBSHPS_ROW_OVER, "999,999,999", "100.0%"),
        Row(SI_PBSHPS_ROW_GROUP, "100.0%", "999,999,999", "24"),
        Row(SI_PBSHPS_ROW_OTHER, "100.0%", "999,999,999", "999+"),
        Row(SI_PBSHPS_ROW_SELF, "100.0%", "999,999,999"),
        Row(SI_PBSHPS_ROW_PT_SHARE, "100.0%"),
        Row(SI_PBSHPS_ROW_PT_SHARE, L(SI_PBSHPS_PT_UNKNOWN)),
        string.format("10. %s  %s  %s  %s", "Abcdefghijklmnopqr", "99,999,999", share, "100.0%"),
        string.format("10. %s  %s  %s", "Radiating Regeneration", "999,999,999", "100.0%"),
        "11/03 12:00  9:59:59  99,999 HPS  99,999,999",
    }
end

-- The most recent fights, newest first. Not tied to a period.
function records:FightLines(limit)
    local list = sv.fights
    if #list == 0 then
        return { L(SI_PBSHPS_NONE) }
    end
    local lines = {}
    for index = #list, math.max(1, #list - limit + 1), -1 do
        local fight = list[index]
        local _, month, day = self:CivilFromDays(fight.day or 0)
        local clock = fight.clock or 0
        lines[#lines + 1] = string.format("%02d/%02d %02d:%02d  %s  %s HPS  %s",
            month, day, math.floor(clock / 3600), math.floor((clock % 3600) / 60),
            Duration(fight.secs), Commas(fight.hps), Commas(fight.heal))
    end
    return lines
end

---------------------------------------------------------------------------------------------------
-- Clearing
---------------------------------------------------------------------------------------------------

-- The character names the days still have in their lists of players healed, as a set.
function records:TargetNames()
    local set = {}
    for _, day in pairs(sv.days) do
        for name in pairs(day.targets.amount) do
            set[name] = true
        end
    end
    return set
end

function records:ClearAll()
    if self.onClear then
        self.onClear()
    end
    self.fight = nil
    self.lastFight = nil
    currentDay, currentKey = nil, nil
    sv.days = {}
    sv.fights = {}
    sv.names = {}
    names = sv.names
end

-- Deleting the records cannot be undone, so it is asked about first, with the same kind of dialog
-- PB's KillLog uses: registered once, shown through ZO_Dialogs_ShowPlatformDialog so the keyboard
-- and gamepad versions are one.
local DIALOG = "PBsHpsChecker_ClearAll"

local function RegisterDialog()
    if not ESO_Dialogs or ESO_Dialogs[DIALOG] then
        return
    end
    ESO_Dialogs[DIALOG] = {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC or nil,
        },
        title = { text = L(SI_PBSHPS_DIALOG_CLEAR_TITLE) },
        mainText = { text = L(SI_PBSHPS_DIALOG_CLEAR_TEXT) },
        buttons = {
            [1] = {
                text = SI_DIALOG_ACCEPT,
                callback = function(dialog)
                    dialog.data.callback()
                end,
            },
            [2] = {
                text = SI_DIALOG_CANCEL,
            },
        },
    }
end

-- Asks, and clears only if the answer is yes. Returns false when there is no way to ask, in which
-- case nothing is deleted.
function records:ConfirmClear(onDone)
    RegisterDialog()
    if not (ESO_Dialogs and ESO_Dialogs[DIALOG] and ZO_Dialogs_ShowPlatformDialog) then
        return false
    end
    ZO_Dialogs_ShowPlatformDialog(DIALOG, {
        callback = function()
            records:ClearAll()
            if onDone then
                onDone()
            end
        end,
    })
    return true
end

---------------------------------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------------------------------

function records:Initialize(savedVars)
    sv = savedVars
    if type(sv.days) ~= "table" then
        sv.days = {}
    end
    if type(sv.fights) ~= "table" then
        sv.fights = {}
    end
    if type(sv.names) ~= "table" then
        sv.names = {}
    end
    names = sv.names

    local oldest = self:DayKey() - RETAIN_DAYS
    for key, day in pairs(sv.days) do
        local number = tonumber(key)
        if type(day) ~= "table" or not number or number < oldest then
            sv.days[key] = nil
        else
            NormalizeDay(day)
            PruneDay(day)
        end
    end

    -- Ability names that no day refers to any more.
    local used = {}
    for _, day in pairs(sv.days) do
        for key in pairs(day.skills.amount) do
            used[key] = true
        end
    end
    for key in pairs(names) do
        if not used[key] then
            names[key] = nil
        end
    end

    for index = #sv.fights, 1, -1 do
        if type(sv.fights[index]) ~= "table" then
            table.remove(sv.fights, index)
        end
    end
    while #sv.fights > MAX_FIGHTS do
        table.remove(sv.fights, 1)
    end
end
