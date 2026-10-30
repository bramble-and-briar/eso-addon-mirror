PBsKillLog = PBsKillLog or {}
local ADDON = PBsKillLog
local L = ADDON.L

---------------------------------------------------------------------------------------------------
-- Daily records and ranks
--
-- Every kill the player gets and every time the player is killed -- as the kill feed reports them in
-- Cyrodiil and the Imperial City, so duplicates are already gone and nothing from a Battleground is
-- in it -- is counted under the day it happened, with the attack that did it when
-- the client says which one, and the player on the other side.
--
--   sv.records["<day>"] = {
--       kills = n, deaths = n,
--       killedWith     = { ["<abilityId>"] = { name = "...", count = n } },  skills the player killed with
--       diedTo         = { ["<abilityId>"] = { name = "...", count = n } },  skills that killed the player
--       killedPlayers  = { ["<@account>"]  = { name, display, char, count = n } },  players the player killed
--       diedToPlayers  = { ["<@account>"]  = { name, display, char, count = n } },  players who killed the player
--   }
--   sv.totals = { kills = n, deaths = n }
--
-- The totals are kept apart from the days on purpose: clearing the daily records, which is what
-- the player does when they pile up, must not take the ranks with it. The ranks are worked out
-- from the totals.
---------------------------------------------------------------------------------------------------

local records = {}
ADDON.records = records

local NAMESPACE = ADDON.name .. "Records"

-- A combat event and the kill feed line it belongs to arrive within moments of each other, in
-- either order.
local PAIRING_WINDOW_MS = 3000

-- The client reads its own death recap 2000 ms after EVENT_PLAYER_DEAD (DEATH_RECAP_DELAY in
-- deathrecap.lua); a little later than that is safe.
local DEATH_RECAP_DELAY_MS = 2200

-- A death is only given an attack if the recap is read soon after the feed line counted it.
local DEATH_PENDING_MS = 15000

local sv

---------------------------------------------------------------------------------------------------
-- Which day it is
--
-- Taken from PB's Omikuji (Draw.lua), which works it out and tests it: this client has no
-- GetDate(), only GetTimeStamp() (UTC) and GetSecondsSinceMidnight() (local wall time). Dividing
-- the timestamp by 86400 would roll the day over at 09:00 in Japan, in the middle of an evening's
-- play, so the day number is chosen instead by asking which timezone offset the two clocks imply
-- and stepping the UTC day until that offset is one somebody could live in.
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
    local names = {}
    for name in tostring(L("WEEKDAYS")):gmatch("[^,]+") do
        names[#names + 1] = name
    end
    return names[(math.floor(dayKey) + 4) % 7 + 1] or ""
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
    return string.format(L("MONTH_FORMAT"), math.floor(monthKey / 100), monthKey % 100)
end

---------------------------------------------------------------------------------------------------
-- Ranks
--
-- One rank, an army rank from private to marshal (eighteen of them), worked out from two numbers:
-- the lifetime number of battles (kills + deaths) and the win rate (kills / battles).
--
--     points = battles x (0.5 + win rate)
--
-- Every battle counts, and the better it went the more it counts: at a 0% win rate a battle is
-- worth half a point, at 50% one point, at 100% a point and a half. So the rank climbs with the
-- number of fights and faster with the share of them that were won. The ranks are thresholds on
-- those points.
---------------------------------------------------------------------------------------------------

local RANK_THRESHOLDS = { 0, 5, 15, 30, 60, 100, 160, 240, 350, 500, 700, 1000, 1400, 2000, 3000, 4500, 7000, 10000 }

-- What an average battle is worth at a win rate of zero; the win rate adds to it.
local BASE_POINTS_PER_BATTLE = 0.5

records.RANK_THRESHOLDS = RANK_THRESHOLDS
records.NUM_RANKS = #RANK_THRESHOLDS
records.BASE_POINTS_PER_BATTLE = BASE_POINTS_PER_BATTLE

function records:Battles(kills, deaths)
    return kills + deaths
end

-- The share of the battles that were kills, 0 to 1; nil before the first battle.
function records:WinRate(kills, deaths)
    local battles = self:Battles(kills, deaths)
    if battles == 0 then
        return nil
    end
    return kills / battles
end

-- battles x (0.5 + win rate). Since the win rate is kills / battles that is the same as
-- kills + battles / 2, and that is what is computed: it is exact, so a threshold is never missed
-- by a rounding error in a division.
function records:RankPoints(kills, deaths)
    return kills + self:Battles(kills, deaths) * BASE_POINTS_PER_BATTLE
end

-- The rank a number of points earns: its index, and the points the next rank starts at (nil at
-- the top).
function records:RankOf(points)
    local index = 1
    for i, threshold in ipairs(RANK_THRESHOLDS) do
        if points >= threshold then
            index = i
        else
            break
        end
    end
    return index, RANK_THRESHOLDS[index + 1]
end

-- How many more battles it takes to reach the next rank if the win rate stays where it is (50%
-- before the first battle, when there is none); nil at the top rank.
function records:BattlesToNextRank(kills, deaths)
    local _, nextThreshold = self:RankOf(self:RankPoints(kills, deaths))
    if not nextThreshold then
        return nil
    end
    local winRate = self:WinRate(kills, deaths) or 0.5
    local pointsPerBattle = BASE_POINTS_PER_BATTLE + winRate
    -- the small subtraction keeps a division that lands exactly on a whole number from rounding up
    return math.max(1, math.ceil((nextThreshold - self:RankPoints(kills, deaths)) / pointsPerBattle - 1e-9))
end

function records:RankName(index)
    return L("RANK_" .. index)
end

---------------------------------------------------------------------------------------------------
-- The data
---------------------------------------------------------------------------------------------------

-- "Name^Mx" (the raw form, with its gender mark) and "Name" are the same person.
local function Plain(name)
    return (tostring(name or ""):gsub("%^.*$", ""))
end

local BUCKETS = { "killedWith", "diedTo", "killedPlayers", "diedToPlayers" }

local function NewDay()
    return { kills = 0, deaths = 0, killedWith = {}, diedTo = {}, killedPlayers = {}, diedToPlayers = {} }
end

-- Saved data that is missing a piece, or was edited by hand, must not be able to break the panel.
local function Normalize(day)
    day.kills = tonumber(day.kills) or 0
    day.deaths = tonumber(day.deaths) or 0
    for _, bucket in ipairs(BUCKETS) do
        if type(day[bucket]) ~= "table" then
            day[bucket] = {}
        end
    end
end

function records:Day(dayKey, create)
    local key = tostring(dayKey)
    local day = sv.records[key]
    if not day and create then
        day = NewDay()
        sv.records[key] = day
    end
    return day
end

-- The recorded days, newest first, as numbers.
function records:DayKeys()
    local keys = {}
    for key in pairs(sv.records) do
        local number = tonumber(key)
        if number then
            keys[#keys + 1] = number
        end
    end
    table.sort(keys, function(a, b) return a > b end)
    return keys
end

function records:Totals()
    return sv.totals.kills, sv.totals.deaths
end

---------------------------------------------------------------------------------------------------
-- Periods
--
-- A period ("scope") is what a ranking or a count is taken over:
--   "all"            every recorded day
--   a day number     that day (a string of digits works too)
--   "m202610"        every recorded day of that month
--   "today"          the day it is when the question is asked
--   "thismonth"      the month it is when the question is asked
-- "today" and "thismonth" are worked out each time, so a window left up past midnight follows the
-- clock.
---------------------------------------------------------------------------------------------------

function records:ResolveScope(scope)
    if scope == "today" then
        return self:DayKey()
    elseif scope == "thismonth" then
        return "m" .. self:MonthKey(self:DayKey())
    end
    return scope
end

local function IsMonthScope(scope)
    return type(scope) == "string" and scope:sub(1, 1) == "m"
end

-- The day records a period covers.
function records:ScopeDays(scope)
    scope = self:ResolveScope(scope)
    local days = {}
    if scope == nil or scope == "all" then
        for _, day in pairs(sv.records) do
            days[#days + 1] = day
        end
    elseif IsMonthScope(scope) then
        local month = tonumber(scope:sub(2))
        for key, day in pairs(sv.records) do
            local number = tonumber(key)
            if number and self:MonthKey(number) == month then
                days[#days + 1] = day
            end
        end
    else
        local day = sv.records[tostring(scope)]
        if day then
            days[1] = day
        end
    end
    return days
end

-- "All time", "Day: 2026/10/19(Mon)", "Month: 2026/10"; today and this month say so.
function records:ScopeText(scope)
    local resolved = self:ResolveScope(scope)
    if resolved == nil or resolved == "all" then
        return L("SCOPE_ALL_SHORT")
    end
    if IsMonthScope(resolved) then
        local text = self:MonthText(tonumber(resolved:sub(2)))
        return string.format(L(scope == "thismonth" and "SCOPE_THIS_MONTH" or "SCOPE_MONTH"), text)
    end
    local text = self:DateText(tonumber(resolved))
    return string.format(L(scope == "today" and "SCOPE_TODAY" or "SCOPE_DAY"), text)
end

-- The periods a ranking can be shown for, in the order a menu lists them: all time, today, this
-- month, then the other months and the other days that have records, newest first.
function records:RankingScopes()
    local MAX_MONTHS, MAX_DAYS = 12, 30
    local scopes = { "all", "today", "thismonth" }
    local today = self:DayKey()
    local thisMonth = self:MonthKey(today)

    local months, seenMonths = {}, {}
    local days = self:DayKeys()
    for _, day in ipairs(days) do
        local month = self:MonthKey(day)
        if month ~= thisMonth and not seenMonths[month] then
            seenMonths[month] = true
            months[#months + 1] = month
        end
    end
    for index = 1, math.min(#months, MAX_MONTHS) do
        scopes[#scopes + 1] = "m" .. months[index]
    end
    local count = 0
    for _, day in ipairs(days) do
        if day ~= today and count < MAX_DAYS then
            scopes[#scopes + 1] = day
            count = count + 1
        end
    end
    return scopes
end

-- Kills and deaths over a period.
function records:Counts(scope)
    local kills, deaths = 0, 0
    for _, day in ipairs(self:ScopeDays(scope)) do
        kills = kills + day.kills
        deaths = deaths + day.deaths
    end
    return kills, deaths
end

function records:AddAbility(bucket, abilityId, name)
    name = name or ""
    local key = (type(abilityId) == "number" and abilityId > 0) and tostring(abilityId) or ("n:" .. name)
    local entry = bucket[key]
    if not entry then
        entry = { name = name, count = 0 }
        bucket[key] = entry
    end
    entry.count = entry.count + 1
    if name ~= "" then
        entry.name = name
    end
end

-- A player on the other side of a kill. Keyed by the account name, which does not change when a
-- character is renamed; the character name stands in when the feed gave no account name. Both
-- names are kept so the player's own "primary name" setting picks which one is shown.
function records:AddPlayer(bucket, displayName, characterName)
    displayName = displayName or ""
    characterName = characterName or ""
    if displayName == "" and characterName == "" then
        return
    end
    local key = displayName ~= "" and displayName or ("c:" .. characterName)
    local entry = bucket[key]
    if not entry then
        entry = { name = "", display = "", char = "", count = 0 }
        bucket[key] = entry
    end
    entry.count = entry.count + 1
    entry.display = displayName
    entry.char = characterName
    entry.name = displayName ~= "" and displayName or Plain(characterName)
end

-- The most used entries of one list, most first. kind is "killedWith" (skills the player killed
-- with), "diedTo" (skills that killed the player), "killedPlayers" or "diedToPlayers"; scope is a
-- period (see above).
function records:Top(kind, scope, limit)
    local bucketName = kind
    local merged = {}
    local function Add(day)
        for key, entry in pairs(day[bucketName]) do
            local into = merged[key]
            if into then
                into.count = into.count + entry.count
            else
                merged[key] = { name = entry.name or "", display = entry.display, char = entry.char, count = entry.count }
            end
        end
    end
    for _, day in ipairs(self:ScopeDays(scope)) do
        Add(day)
    end

    local list = {}
    for _, entry in pairs(merged) do
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name < b.name
    end)
    while limit and #list > limit do
        table.remove(list)
    end
    return list
end

function records:ClearDays()
    sv.records = {}
    self.pendingKill, self.pendingDeath, self.lastBlow = nil, nil, nil
end

-- Everything, the totals and so the ranks too.
function records:ResetAll()
    self:ClearDays()
    sv.totals = { kills = 0, deaths = 0 }
end

---------------------------------------------------------------------------------------------------
-- Text for the panel and /pbkl stats
---------------------------------------------------------------------------------------------------

local function KillDeathRatio(kills, deaths)
    if deaths == 0 then
        return "-"
    end
    return string.format("%.2f", kills / deaths)
end

-- The rank, and how far it is to the next one.
function records:RankLine()
    local kills, deaths = self:Totals()
    local index = self:RankOf(self:RankPoints(kills, deaths))
    local name = self:RankName(index)
    local battlesLeft = self:BattlesToNextRank(kills, deaths)
    if battlesLeft then
        return string.format(L("RANK_ROW"), name, battlesLeft)
    end
    return string.format(L("RANK_ROW_MAX"), name)
end

-- What the rank is made from: the battles, the win rate, and the kills and deaths behind them.
function records:StatsLine()
    local kills, deaths = self:Totals()
    local winRate = self:WinRate(kills, deaths)
    local winRateText = winRate and string.format("%.1f%%", winRate * 100) or L("NONE_ROW")
    return string.format(L("RANK_STATS_ROW"), self:Battles(kills, deaths), winRateText, kills, deaths)
end

function records:TodayLine()
    local dayKey = self:DayKey()
    local kills, deaths = self:Counts(dayKey)
    return string.format(L("TODAY_ROW"), self:DateText(dayKey), kills, deaths, KillDeathRatio(kills, deaths))
end

function records:DayLine(dayKey)
    local kills, deaths = self:Counts(dayKey)
    return string.format(L("DAY_ROW"), self:DateText(dayKey), kills, deaths)
end

-- A player is shown the way the kill log shows them: by the name the player prefers.
local function PlayerText(entry)
    if ZO_GetPrimaryPlayerName then
        local text = ZO_GetPrimaryPlayerName(entry.display or "", entry.char or "")
        if text and text ~= "" then
            return text
        end
    end
    return entry.name or ""
end

-- One row of a list: "3. Name x12", or a dash where there is nothing.
function records:EntryLine(kind, rank, entry)
    if not entry then
        return L("NONE_ROW")
    end
    local text
    if kind == "killedPlayers" or kind == "diedToPlayers" then
        text = PlayerText(entry)
    else
        text = entry.name ~= "" and entry.name or L("UNKNOWN_ATTACK")
    end
    return string.format(L("ABILITY_ROW"), rank, text, entry.count)
end

-- The lines of a ranking over a period (all time if none is given), without padding.
function records:RankingLines(kind, limit, scope)
    local lines = {}
    for rank, entry in ipairs(self:Top(kind, scope or "all", limit)) do
        lines[rank] = self:EntryLine(kind, rank, entry)
    end
    return lines
end

function records:SummaryLines()
    return {
        self:TodayLine(),
        self:RankLine(),
        self:StatsLine(),
    }
end

---------------------------------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------------------------------

local function SameName(a, b)
    return a == "" or b == "" or a == b
end

local function AbilityText(name)
    name = name or ""
    if ZO_CachedStrFormat and SI_ABILITY_NAME then
        return ZO_CachedStrFormat(SI_ABILITY_NAME, name)
    end
    return name
end

-- The ranking window, if it is up, shows the new count.
local function RefreshRanking()
    if ADDON.ranking then
        ADDON.ranking:Refresh()
    end
end

function records:AttributeKill(pending, blow)
    self:AddAbility(self:Day(pending.day, true).killedWith, blow.id, blow.name)
    pending.done = true
    RefreshRanking()
end

-- The player got a kill (the kill feed's victim is somebody else). The names are the victim's, as
-- the feed gives them.
function records:OnKill(victimDisplayName, victimCharacterName)
    local dayKey = self:DayKey()
    local day = self:Day(dayKey, true)
    day.kills = day.kills + 1
    sv.totals.kills = sv.totals.kills + 1
    self:AddPlayer(day.killedPlayers, victimDisplayName, victimCharacterName)

    local now = GetFrameTimeMilliseconds()
    local pending = { day = dayKey, time = now, victim = Plain(victimCharacterName), done = false }
    self.pendingKill = pending

    -- The combat event may have come first.
    local blow = self.lastBlow
    if blow and now - blow.time <= PAIRING_WINDOW_MS and SameName(blow.target, pending.victim) then
        self:AttributeKill(pending, blow)
        self.lastBlow = nil
    end
    RefreshRanking()
end

-- The player was killed, by the player with these names.
function records:OnDeath(killerDisplayName, killerCharacterName)
    local dayKey = self:DayKey()
    local day = self:Day(dayKey, true)
    day.deaths = day.deaths + 1
    sv.totals.deaths = sv.totals.deaths + 1
    self:AddPlayer(day.diedToPlayers, killerDisplayName, killerCharacterName)
    self.pendingDeath = { day = dayKey, time = GetFrameTimeMilliseconds(), done = false }
    RefreshRanking()
end

-- EVENT_COMBAT_EVENT, already narrowed by the engine to the player's own killing blows.
local function OnKillingBlow(_, result, isError, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, _, _, abilityId)
    local now = GetFrameTimeMilliseconds()
    local blow = { time = now, target = Plain(targetName), id = abilityId, name = AbilityText(abilityName) }

    -- The kill feed line may have come first.
    local pending = records.pendingKill
    if pending and not pending.done and now - pending.time <= PAIRING_WINDOW_MS and SameName(pending.victim, blow.target) then
        records:AttributeKill(pending, blow)
        return
    end
    records.lastBlow = blow
end

-- The client's own death recap names the attack that killed the player, but only a moment after
-- the death, so it is read on a short delay, the way the client reads it.
local function ReadDeathRecap()
    local pending = records.pendingDeath
    if not pending or pending.done then
        return
    end
    if GetFrameTimeMilliseconds() - pending.time > DEATH_PENDING_MS then
        return
    end
    for index = 1, GetNumKillingAttacks() do
        local attackName, _, _, wasKillingBlow, _, _, _, abilityId = GetKillingAttackInfo(index)
        if wasKillingBlow then
            records:AddAbility(records:Day(pending.day, true).diedTo, abilityId, AbilityText(attackName))
            pending.done = true
            RefreshRanking()
            return
        end
    end
end

local function OnPlayerDead()
    zo_callLater(ReadDeathRecap, DEATH_RECAP_DELAY_MS)
end

function records:Initialize(savedVars)
    sv = savedVars
    if type(sv.records) ~= "table" then
        sv.records = {}
    end
    if type(sv.totals) ~= "table" then
        sv.totals = {}
    end
    sv.totals.kills = tonumber(sv.totals.kills) or 0
    sv.totals.deaths = tonumber(sv.totals.deaths) or 0
    for key, day in pairs(sv.records) do
        if type(day) == "table" then
            Normalize(day)
        else
            sv.records[key] = nil
        end
    end

    -- Only the player's own killing blows reach OnKillingBlow: the engine drops everything else.
    EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "Blow", EVENT_COMBAT_EVENT, OnKillingBlow)
    EVENT_MANAGER:AddFilterForEvent(NAMESPACE .. "Blow", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "Dead", EVENT_PLAYER_DEAD, OnPlayerDead)
end

---------------------------------------------------------------------------------------------------
-- Clearing
--
-- Deleting the records cannot be undone, so it is asked about first, with the same kind of
-- dialog PB's MailerExtension asks "delete this draft?" with: registered once, shown through
-- ZO_Dialogs_ShowPlatformDialog so the keyboard and gamepad versions are one.
---------------------------------------------------------------------------------------------------

local CONFIRMATIONS = {
    days = {
        dialog = ADDON.name .. "_ClearDays",
        titleKey = "DIALOG_CLEAR_DAYS_TITLE",
        textKey = "DIALOG_CLEAR_DAYS_TEXT",
        action = function() records:ClearDays() end,
    },
    all = {
        dialog = ADDON.name .. "_ResetAll",
        titleKey = "DIALOG_RESET_ALL_TITLE",
        textKey = "DIALOG_RESET_ALL_TEXT",
        action = function() records:ResetAll() end,
    },
}

local function RegisterDialog(confirmation)
    if not ESO_Dialogs or ESO_Dialogs[confirmation.dialog] then
        return
    end
    ESO_Dialogs[confirmation.dialog] = {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC or nil,
        },
        title = { text = L(confirmation.titleKey) },
        mainText = { text = L(confirmation.textKey) },
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

-- Asks, and clears only if the answer is yes. kind is "days" (the daily records; the totals and
-- ranks stay) or "all". Returns false when there is no way to ask, in which case nothing is
-- deleted: better to do nothing than to throw the records away silently.
function records:ConfirmClear(kind, onDone)
    local confirmation = CONFIRMATIONS[kind]
    if not confirmation then
        return false
    end
    RegisterDialog(confirmation)
    if not (ESO_Dialogs and ESO_Dialogs[confirmation.dialog] and ZO_Dialogs_ShowPlatformDialog) then
        return false
    end
    ZO_Dialogs_ShowPlatformDialog(confirmation.dialog, {
        callback = function()
            confirmation.action()
            if onDone then
                onDone()
            end
        end,
    })
    return true
end
