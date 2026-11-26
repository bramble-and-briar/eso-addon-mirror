-- shared
-- The weekly leaderboards: the weekly trial, the weekly arena challenge, Infinite
-- Archive (solo and duo), the battleground leaderboard, and the Cyrodiil campaign reward tier.
-- Since Update 48 a leaderboard holds one entry per ACCOUNT (its best score) and 500 places, so the
-- score and place are saved for the account, and each character only keeps whether it ran it.
-- Everything is saved with the moment its week ends, so it empties by itself at the turnover:
--   account.weekly = { trial = "ends at;score;place;state;credited;name", arena =,
--                      archiveSolo =, archiveDuo =, battleground = }       place 0 = not on the leaderboard
--   c.weekly = { the same texts as read on this character: only state is used (0 = not started,
--                1 = started, 2 = completed), and cyrodiil = "ends at;tier;progress;needed;0;campaign" }
local CT = FurysCharacterTracker
local U = CT.Util

-- `named`: the game picks a different one each week, and the column title is its name.
local BOARDS = {
    { id = "trial", title = "Weekly trial", width = 190, what = "the weekly trial (a trial, or some weeks a group arena)", named = true },
    { id = "arena", title = "Weekly arena", width = 190, what = "the weekly arena challenge", named = true },
    { id = "archiveSolo", title = "Archive solo", width = 150, what = "Infinite Archive, solo" },
    { id = "archiveDuo", title = "Archive duo", width = 150, what = "Infinite Archive, duo" },
    { id = "battleground", title = "Battlegrounds", width = 150, what = "the battleground leaderboard", noRun = true },
}
local STARTED, COMPLETED = 1, 2
-- The leaderboard rewards are mailed to the accounts on the final standings, and a leaderboard
-- holds this many places (Update 48). A place past it, or no place, needs a better run.
local REWARD_PLACES = 500
local AMBER = "|cFFC857"

-- One saved board: nil when never read, { over = true } when its week has ended since the read,
-- else { endsAt =, score =, place =, state =, credited =, name = }.
local function Parse(text, now)
    if not text then return nil end
    local p = U.Split(text, ";")
    local endsAt = tonumber(p[1]) or 0
    if endsAt <= (now or GetTimeStamp()) then return { over = true } end
    return { endsAt = endsAt, score = tonumber(p[2]) or 0, place = tonumber(p[3]) or 0, state = tonumber(p[4]) or 0,
             credited = p[5] == "1", name = p[6] or "" }
end
local function Board(c, id, now) return Parse((c.weekly or {})[id], now) end
local function AccountBoard(id, now) return Parse(((CT.Data().account or {}).weekly or {})[id], now) end

-- What a board is called: this week's name for the two the game rotates, once it has been read.
local function Title(def)
    if def.named then
        local board = AccountBoard(def.id)
        if board and not board.over and board.name ~= "" then return board.name end
    end
    return def.title
end

-- A score that earns no leaderboard reward as it stands.
local function NeedsBetterRun(board)
    return board ~= nil and not board.over and board.score > 0 and (board.place == 0 or board.place > REWARD_PLACES)
end

-- "187,654  #42" for the account, or "-".
local function ScoreText(board)
    if not board or board.over or board.score == 0 then return "-" end
    return U.Comma(board.score) .. (board.place > 0 and ("  #" .. board.place) or "  no place")
end

local function StateText(board, def)
    if not board or board.over or def.noRun then return "-" end
    if board.state == COMPLETED then return "Done" end
    if board.state == STARTED then return "Started" end
    return "-"
end

local function BoardTip(c, def)
    local mine, account = Board(c, def.id), AccountBoard(def.id)
    local live = (account and not account.over) and account or nil
    local name = (def.named and live and live.name ~= "") and live.name or nil
    local lines = { name and string.format("%s: %s", def.title, name) or (string.gsub(def.what, "^%l", string.upper)) }
    if not def.noRun then
        if not mine then
            lines[#lines + 1] = "This character: not read yet. Log in on it once."
        elseif mine.over then
            lines[#lines + 1] = "This character: not read since the new week started."
        else
            lines[#lines + 1] = "This character: " .. (mine.state == COMPLETED and "completed it this week." or (mine.state == STARTED and "started it this week, not completed." or "not run this week."))
        end
    end
    if not live or live.score == 0 then
        lines[#lines + 1] = "This account: no score this week."
    else
        lines[#lines + 1] = string.format("This account: best score %s, %s.", U.Comma(live.score), live.place > 0 and ("place " .. live.place) or "no place on the leaderboard")
        if NeedsBetterRun(live) then
            lines[#lines + 1] = string.format("The leaderboard rewards go to the top %d accounts, so this needs a better run.", REWARD_PLACES)
        else
            lines[#lines + 1] = string.format("Inside the top %d, where the leaderboard rewards go. The place can move while others play.", REWARD_PLACES)
        end
    end
    if live then lines[#lines + 1] = "The week ends in " .. U.Duration(live.endsAt - GetTimeStamp()) .. "." end
    lines[#lines + 1] = "A leaderboard keeps one entry per account: its best score. It is on the bottom row."
    return table.concat(lines, "\n")
end

local function BoardColumn(def)
    return { key = "weekly." .. def.id, title = function() return Title(def) end, width = def.width, bar = false,
             head = string.format("%s, this week.\nEach row: whether that character has run it (Done or Started).\nBottom row: this account's best score and place. A leaderboard keeps one entry per account, and its rewards go to the top %d.\nAmber = a score outside the top %d, or with no place: it needs a better run.",
                                  (string.gsub(def.what, "^%l", string.upper)), REWARD_PLACES, REWARD_PLACES),
             value = function(e)
                 local board = Board(e.c, def.id)
                 return (board and not board.over and not def.noRun) and board.state or 0
             end,
             display = function(_, e) return StateText(Board(e.c, def.id), def) end,
             dim = function(v) return v == 0 end,
             gold = function(v) return v == COMPLETED end,
             foot = function()
                 local board = AccountBoard(def.id)
                 local text = ScoreText(board)
                 return NeedsBetterRun(board) and (AMBER .. text .. "|r") or text
             end,
             tip = function(e) return BoardTip(e.c, def) end }
end

-- The line above the columns of the Weekly tab: this week's trial and arena, when the week ends,
-- and the boards that need a better run.
function CT.WeeklySummary(now)
    local parts, soonest, redo = {}, nil, {}
    for _, def in ipairs(BOARDS) do
        local board = AccountBoard(def.id, now)
        if board and not board.over then
            if not soonest or board.endsAt < soonest then soonest = board.endsAt end
            if NeedsBetterRun(board) then redo[#redo + 1] = Title(def) end
        end
    end
    if not soonest then return "Nothing read for this week yet: log in on a character of this account" end
    parts[#parts + 1] = "the week ends in " .. U.Duration(soonest - now)
    parts[#parts + 1] = "bottom row = this account's best score and place"
    if #redo > 0 then parts[#parts + 1] = AMBER .. "needs a better run for the rewards: " .. table.concat(redo, ", ") .. "|r" end
    return table.concat(parts, "  ·  ")
end

-- Game only ---------------------------------------------------------------------------------

-- The game only knows a leaderboard after it has been asked for (its own leaderboard window does
-- the same when you open it): before that the name is empty and the score and place are 0.
-- `ready[id]` is set once the answer for that board is in, and only then is a read trusted.
local ready = {}

local function Pack(endsIn, score, place, started, completed, credited, name)
    local state = completed and COMPLETED or (started and STARTED or 0)
    return table.concat({ GetTimeStamp() + endsIn, score, place, state, credited and 1 or 0, U.Clean(U.Plain(name or "")) }, ";")
end

local function Read(c, account)
    local weekly, before, now = {}, c.weekly or {}, GetTimeStamp()
    local sharedBefore = account.weekly or {}
    local raidEndsIn = GetRaidOfTheWeekTimes()
    if raidEndsIn > 0 then
        for id, category in pairs({ trial = RAID_CATEGORY_TRIAL, arena = RAID_CATEGORY_CHALLENGE }) do
            local _, hasWeekly = GetNumRaidLeaderboards(category)
            if hasWeekly then
                local name = GetRaidOfTheWeekLeaderboardInfo(category)
                local place, score = GetRaidOfTheWeekLeaderboardLocalPlayerInfo(category)
                local _, credited = GetPlayerRaidOfTheWeekParticipationInfo(category)
                local started, completed = GetPlayerRaidOfTheWeekProgressInfo(category)
                weekly[id] = Pack(raidEndsIn, score, place, started, completed, credited, name)
            end
        end
    end
    local archiveEndsIn = GetEndlessDungeonOfTheWeekTimes()
    if archiveEndsIn > 0 then
        for id, groupType in pairs({ archiveSolo = ENDLESS_DUNGEON_GROUP_TYPE_SOLO, archiveDuo = ENDLESS_DUNGEON_GROUP_TYPE_DUO }) do
            local place, score = GetEndlessDungeonOfTheWeekLeaderboardLocalPlayerInfo(groupType)
            local _, credited = GetPlayerEndlessDungeonOfTheWeekParticipationInfo(groupType)
            local started, completed = GetPlayerEndlessDungeonOfTheWeekProgressInfo(groupType)
            weekly[id] = Pack(archiveEndsIn, score, place, started, completed, credited, "")
        end
    end
    -- Battlegrounds: the board this character scored highest on.
    local names = { [BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE] = "Competitive", [BATTLEGROUND_LEADERBOARD_TYPE_DEATHMATCH] = "Deathmatch",
                    [BATTLEGROUND_LEADERBOARD_TYPE_FLAG_GAMES] = "Flag games", [BATTLEGROUND_LEADERBOARD_TYPE_LAND_GRAB] = "Land grab" }
    local boardType = GetNextBattlegroundLeaderboardType()
    local best
    while boardType do
        if ShouldShowLeaderboardForBattlegroundLeaderboardType(boardType) then
            local place, score = GetBattlegroundLeaderboardLocalPlayerInfo(boardType)
            local endsIn = GetBattlegroundLeaderboardsSchedule(boardType)
            if endsIn > 0 and (not best or score > best.score) then
                best = { score = score, place = place, endsIn = endsIn, name = names[boardType] or "" }
            end
        end
        boardType = GetNextBattlegroundLeaderboardType(boardType)
    end
    if best then weekly.battleground = Pack(best.endsIn, best.score, best.place, false, false, false, best.name) end
    -- Cyrodiil: the reward tier earned in the home campaign.
    local campaignId = GetAssignedCampaignId()
    if campaignId ~= 0 then
        local endsIn = GetSecondsUntilCampaignEnd(campaignId)
        if endsIn > 0 then
            local tier, progress, needed = GetPlayerCampaignRewardTierInfo(campaignId)
            weekly.cyrodiil = table.concat({ GetTimeStamp() + endsIn, tier, progress, needed, 0, U.Clean(U.Plain(GetCampaignName(campaignId))) }, ";")
        end
    end
    -- The scores and places belong to the account: the newest read is the one that counts.
    -- A board the game has not answered for yet keeps what was saved for this week, if anything.
    local shared = {}
    for _, def in ipairs(BOARDS) do
        local id = def.id
        if not ready[id] then
            local mine, ours = Parse(before[id], now), Parse(sharedBefore[id], now)
            if mine and not mine.over then weekly[id] = before[id] end
            if ours and not ours.over then shared[id] = sharedBefore[id] end
        end
        if not shared[id] then shared[id] = weekly[id] end
    end
    c.weekly, c.weeklyOther = weekly, nil
    account.weekly = shared
end

-- Asks the game for this week's leaderboards, one at a time, two seconds apart, and reads
-- again once they have all been asked for (and for any answer that comes in later).
-- Once after logging in, and again after the weekly turnover.
local REQUEST_GAP_MS = 2000
local function Start(queue)
    local asking = false
    local function Got(id)
        ready[id] = true
        if not asking then queue() end
    end
    local function Ask()
        local steps = {}
        for id, category in pairs({ trial = RAID_CATEGORY_TRIAL, arena = RAID_CATEGORY_CHALLENGE }) do
            steps[#steps + 1] = function()
                if QueryRaidLeaderboardData(category, 0) == LEADERBOARD_DATA_READY then Got(id) end
            end
        end
        for id, groupType in pairs({ archiveSolo = ENDLESS_DUNGEON_GROUP_TYPE_SOLO, archiveDuo = ENDLESS_DUNGEON_GROUP_TYPE_DUO }) do
            steps[#steps + 1] = function()
                if QueryEndlessDungeonLeaderboardData(groupType, 0) == LEADERBOARD_DATA_READY then Got(id) end
            end
        end
        local boardType = GetNextBattlegroundLeaderboardType()
        while boardType do
            local thisType = boardType
            if ShouldShowLeaderboardForBattlegroundLeaderboardType(thisType) then
                steps[#steps + 1] = function()
                    if QueryBattlegroundLeaderboardData(thisType) == LEADERBOARD_DATA_READY then Got("battleground") end
                end
            end
            boardType = GetNextBattlegroundLeaderboardType(boardType)
        end
        asking = true
        for i, step in ipairs(steps) do zo_callLater(step, i * REQUEST_GAP_MS) end
        zo_callLater(function()
            asking = false
            queue()
        end, (#steps + 1) * REQUEST_GAP_MS)
    end
    local name = CT.name .. "Weekly"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_RAID_LEADERBOARD_DATA_RECEIVED, function(_, category)
        Got(category == RAID_CATEGORY_TRIAL and "trial" or "arena")
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ENDLESS_DUNGEON_LEADERBOARD_DATA_RECEIVED, function(_, groupType)
        Got(groupType == ENDLESS_DUNGEON_GROUP_TYPE_SOLO and "archiveSolo" or "archiveDuo")
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_BATTLEGROUND_LEADERBOARD_DATA_RECEIVED, function() Got("battleground") end)
    local function Turnover()
        ready = {}
        zo_callLater(Ask, 30000)
    end
    EVENT_MANAGER:RegisterForEvent(name, EVENT_RAID_OF_THE_WEEK_TURNOVER, Turnover)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ENDLESS_DUNGEON_OF_THE_WEEK_TURNOVER, Turnover)
    Ask()
end

-- Columns -----------------------------------------------------------------------------------

local columns = {}
for _, def in ipairs(BOARDS) do columns[#columns + 1] = BoardColumn(def) end

-- The saved campaign of a character: nil, { over = true }, or { endsAt =, tier =, progress =, needed =, name = }.
local function Campaign(c, now)
    local text = (c.weekly or {}).cyrodiil
    if not text then return nil end
    local p = U.Split(text, ";")
    local endsAt = tonumber(p[1]) or 0
    if endsAt <= (now or GetTimeStamp()) then return { over = true } end
    return { endsAt = endsAt, tier = tonumber(p[2]) or 0, progress = tonumber(p[3]) or 0, needed = tonumber(p[4]) or 0, name = p[6] or "" }
end

columns[#columns + 1] = {
    key = "weekly.cyrodiil", title = "Cyrodiil", width = 96, bar = false,
    head = "Cyrodiil: the reward tier this character has earned in its home campaign.\nThe rewards are mailed when the campaign ends. A campaign lasts 7 or 30 days: hover a cell for which one and when it ends.",
    value = function(e)
        local campaign = Campaign(e.c)
        return (campaign and not campaign.over) and campaign.tier or 0
    end,
    display = function(v) return v > 0 and ("Tier " .. v) or "-" end,
    dim = function(v) return v == 0 end,
    tip = function(e)
        local campaign = Campaign(e.c)
        if not campaign then return "No home campaign, or not read yet: log in on this character once." end
        if campaign.over then return "The campaign has ended since this character was last read." end
        local lines = { "Home campaign: " .. campaign.name, campaign.tier > 0 and ("Reward tier earned: " .. campaign.tier) or "No reward tier earned yet." }
        if campaign.needed > 0 then
            lines[#lines + 1] = string.format("Next tier: %s of %s Alliance Points", U.Comma(campaign.progress), U.Comma(campaign.needed))
        end
        lines[#lines + 1] = "The campaign ends in " .. U.Duration(campaign.endsAt - GetTimeStamp()) .. "."
        return table.concat(lines, "\n")
    end }

CT.Track({
    id = "weekly",
    read = Read,
    events = { EVENT_RAID_LEADERBOARD_PLAYER_DATA_CHANGED, EVENT_RAID_OF_THE_WEEK_TURNOVER, EVENT_RAID_TRIAL_COMPLETE,
               EVENT_RAID_TRIAL_NEW_BEST_SCORE, EVENT_ENDLESS_DUNGEON_LEADERBOARD_PLAYER_DATA_CHANGED,
               EVENT_ENDLESS_DUNGEON_OF_THE_WEEK_TURNOVER, EVENT_ENDLESS_DUNGEON_NEW_BEST_SCORE,
               EVENT_ASSIGNED_CAMPAIGN_CHANGED },
    start = Start,
    columns = columns,
    sections = function(e)
        local items, now = {}, GetTimeStamp()
        for _, def in ipairs(BOARDS) do
            local text = StateText(Board(e.c, def.id, now), def)
            if text ~= "-" then
                local account = AccountBoard(def.id, now)
                local name = Title(def)
                items[#items + 1] = { name, text, done = text == "Done" }
            end
        end
        local campaign = Campaign(e.c, now)
        if campaign and not campaign.over and campaign.tier > 0 then items[#items + 1] = { "Cyrodiil: " .. campaign.name, "Tier " .. campaign.tier } end
        if #items == 0 then return nil end
        return { { id = "weekly", title = "This week", items = items } }
    end,
})
