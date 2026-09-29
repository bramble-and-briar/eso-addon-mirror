-- SetHunter_XP.lua : live XP info for the XP farming tab: your level / CP progress, a
-- session tracker (XP gained, XP per hour, time to the next level), the daily bonus
-- checklist (daily random rewards from the Activity Finder) and active XP buffs.

local S = SetHunter
local L = S.L

-- ---------------------------------------------------------------------------
-- Progress: level XP below max level, Champion XP after (like the game's own XP bar)
-- ---------------------------------------------------------------------------
local function Champion()
    return CanUnitGainChampionPoints and CanUnitGainChampionPoints("player")
end

-- how much XP one rank (a level, or a champion point) takes
local function RankSize(champion, rank)
    if champion then return GetNumChampionXPInChampionPoint(rank) or 0 end
    return GetNumExperiencePointsInLevel(rank) or 0
end

-- { champion, rank, xp, size }: where you are now
function S.XPState()
    local champion = Champion()
    local rank, xp
    if champion then
        rank, xp = GetPlayerChampionPointsEarned(), GetPlayerChampionXP()
    else
        rank, xp = GetUnitLevel("player"), GetUnitXP("player")
    end
    return { champion = champion, rank = rank, xp = xp, size = RankSize(champion, rank) }
end

-- XP earned between two states (ranks gained in between count in full)
local function Gained(prev, cur)
    if not prev or prev.champion ~= cur.champion then return 0 end
    if cur.rank == prev.rank then return zo_max(0, cur.xp - prev.xp) end
    if cur.rank < prev.rank then return 0 end
    local sum = zo_max(0, prev.size - prev.xp)
    for rank = prev.rank + 1, cur.rank - 1 do sum = sum + RankSize(cur.champion, rank) end
    return sum + cur.xp
end

-- ---------------------------------------------------------------------------
-- Session: from logging in (a /reloadui or a short break keeps the same session)
-- ---------------------------------------------------------------------------
local SESSION_GAP = 15 * 60   -- away longer than this: a new session starts
local last                   -- the XP state at the last update

function S.ResetXPSession()
    local cur = S.XPState()
    S.sv.xpSession = {
        char = GetCurrentCharacterId(), start = GetTimeStamp(), seen = GetTimeStamp(),
        gained = 0, ranks = 0, champion = cur.champion,
    }
    last = cur
end

local function OnXPUpdate()
    local session = S.sv.xpSession
    if not session then return end
    local cur = S.XPState()
    local gained = Gained(last, cur)
    if gained > 0 then
        session.gained = session.gained + gained
        if last and cur.rank > last.rank and cur.champion == last.champion then
            session.ranks = session.ranks + (cur.rank - last.rank)
        end
    end
    session.champion = cur.champion
    session.seen = GetTimeStamp()
    last = cur
    if S.RefreshXPPages then S.RefreshXPPages() end
end

-- { seconds, gained, perHour, ranks, champion, toNext (seconds or nil) }
function S.XPSessionStats()
    local session = S.sv.xpSession
    if not session then return nil end
    local seconds = zo_max(1, GetDiffBetweenTimeStamps(GetTimeStamp(), session.start))
    local perHour = session.gained / seconds * 3600
    local cur = S.XPState()
    local toNext
    if perHour > 0 and cur.size > 0 then toNext = (cur.size - cur.xp) / perHour * 3600 end
    return {
        seconds = seconds, gained = session.gained, perHour = perHour,
        ranks = session.ranks, champion = cur.champion, toNext = toNext,
    }
end

-- "42 min", "1 h 5 min"
function S.FormatDuration(seconds)
    seconds = zo_floor(seconds or 0)
    local hours, minutes = zo_floor(seconds / 3600), zo_floor((seconds % 3600) / 60)
    if hours > 0 then return L("DURATION_HM", hours, minutes) end
    if minutes > 0 then return L("DURATION_M", minutes) end
    return L("DURATION_LT_MIN")
end

-- ---------------------------------------------------------------------------
-- Daily bonuses: every Activity Finder activity set with a reward (random dungeons,
-- random battlegrounds, Tales of Tribute...), whether today's first-time reward is
-- still open, and how much XP it gives. All from the game, in any language.
-- ---------------------------------------------------------------------------
local BATTLEGROUND_TYPES = {}
for _, name in ipairs({ "LFG_ACTIVITY_BATTLE_GROUND_CHAMPION", "LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION",
    "LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL" }) do
    if _G[name] then BATTLEGROUND_TYPES[_G[name]] = true end
end

-- { { name, open (reward still available today), xp, action ("RANDOM" / "BATTLEGROUNDS" / nil) }, ... }
function S.DailyRewards()
    local list = {}
    if not LFG_ACTIVITY_ITERATION_BEGIN or not GetNumActivitySetsByType or not IsActivityEligibleForDailyReward then
        return list
    end
    for activityType = LFG_ACTIVITY_ITERATION_BEGIN, LFG_ACTIVITY_ITERATION_END do
        for i = 1, GetNumActivitySetsByType(activityType) do
            local setId = GetActivitySetIdByTypeAndIndex(activityType, i)
            if setId and DoesActivitySetHaveRewardData and DoesActivitySetHaveRewardData(setId) then
                local name = GetActivitySetInfo(setId)
                local _, xp = GetActivitySetRewardData(setId)
                local action
                if activityType == LFG_ACTIVITY_DUNGEON or activityType == LFG_ACTIVITY_MASTER_DUNGEON then
                    action = "RANDOM"
                elseif BATTLEGROUND_TYPES[activityType] then
                    action = "BATTLEGROUNDS"
                end
                list[#list + 1] = {
                    name = zo_strformat("<<1>>", name or ""),
                    open = IsActivityEligibleForDailyReward(activityType),
                    xp = xp or 0,
                    action = action,
                }
            end
        end
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Active XP buff (Experience Scroll, Ambrosia, event boosts): found by buff name,
-- per game language. Returns the name and seconds left, or nil.
-- ---------------------------------------------------------------------------
local XP_BUFF_WORDS = {
    en = { "experience" }, de = { "erfahrung" }, fr = { "expérience", "experience" }, es = { "experiencia" },
}

function S.ActiveXPBuff()
    local lang = GetCVar and GetCVar("language.2") or "en"
    local words = XP_BUFF_WORDS[lang] or XP_BUFF_WORDS.en
    local now = GetFrameTimeSeconds()
    for i = 1, GetNumBuffs("player") do
        local name, _, timeEnding = GetUnitBuffInfo("player", i)
        local lower = zo_strlower(name or "")
        for _, word in ipairs(words) do
            if lower:find(word, 1, true) then
                local left = (timeEnding and timeEnding > now) and (timeEnding - now) or nil
                return zo_strformat("<<1>>", name), left
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
function S.InitXP()
    EVENT_MANAGER:RegisterForEvent("SetHunter_XP", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent("SetHunter_XP", EVENT_PLAYER_ACTIVATED)
        local session = S.sv.xpSession
        local now = GetTimeStamp()
        -- same character, back within a few minutes (a /reloadui): keep counting
        if session and session.char == GetCurrentCharacterId()
            and GetDiffBetweenTimeStamps(now, session.seen or 0) < SESSION_GAP then
            last = S.XPState()
        else
            S.ResetXPSession()
        end
    end)
    EVENT_MANAGER:RegisterForEvent("SetHunter_XP", EVENT_EXPERIENCE_UPDATE, function(_, unitTag)
        if unitTag == "player" then OnXPUpdate() end
    end)
    EVENT_MANAGER:AddFilterForEvent("SetHunter_XP", EVENT_EXPERIENCE_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    -- keep "seen" fresh while you're online without earning XP (standing in town)
    EVENT_MANAGER:RegisterForUpdate("SetHunter_XPSeen", 60000, function()
        if S.sv.xpSession then S.sv.xpSession.seen = GetTimeStamp() end
    end)
end
