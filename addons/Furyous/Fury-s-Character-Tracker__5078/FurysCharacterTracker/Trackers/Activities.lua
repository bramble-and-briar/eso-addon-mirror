-- shared
-- Daily and weekly things outside crafting: the once-a-day reward of the dungeon finder,
-- battlegrounds and Tales of Tribute, trial quests handed in, and the account's Challenges.
--   c.rewardAt = { dungeon =, battleground =, tribute = }   when each daily reward can be earned again
--                                                           (0 = it is waiting now)
--   c.trials = { "when;quest name", ... }                   trial quests handed in, newest last
--   account.challenges = { daily = "done;total;resets at", weekly = "..." }
local CT = FurysCharacterTracker
local U = CT.Util

local REWARDS = {
    { id = "dungeon", title = "Dungeon", what = "random dungeon",
      bonus = "The first random dungeon of the day, normal or veteran, pays a large XP bonus on top of the reward." },
    { id = "battleground", title = "Battleground", what = "battleground",
      bonus = "The first battleground of the day pays a large XP bonus on top of the reward." },
    { id = "tribute", title = "Tribute", what = "Tales of Tribute match" },
}
local TRIAL_DAYS = 7
local TRIALS_KEPT = 20

-- Seconds until a daily reward can be earned again: 0 = waiting now, nil = never read.
local function RewardIn(c, id, now)
    local at = (c.rewardAt or {})[id]
    if not at then return nil end
    return math.max(0, at - (now or GetTimeStamp()))
end

-- Trial quests handed in during the last week: { { at =, name = }, ... }, newest first.
local function RecentTrials(c, now)
    local list, cutoff = {}, (now or GetTimeStamp()) - TRIAL_DAYS * 86400
    for index = #(c.trials or {}), 1, -1 do
        local text = c.trials[index]
        local at = string.find(text, ";", 1, true)
        local when = tonumber(string.sub(text, 1, (at or 1) - 1)) or 0
        if when >= cutoff then list[#list + 1] = { at = when, name = string.sub(text, (at or 0) + 1) } end
    end
    return list
end

-- The account's Challenges as text for the Daily tab's top line, or nil when never read.
local function ChallengeText(data, now)
    local saved = (data.account or {}).challenges
    if not saved then return nil end
    local parts = {}
    for _, kind in ipairs({ "daily", "weekly" }) do
        local p = U.Split(saved[kind] or "", ";")
        local done, total, resetAt = tonumber(p[1]), tonumber(p[2]), tonumber(p[3]) or 0
        if total and total > 0 then
            if resetAt > 0 and resetAt <= now then
                parts[#parts + 1] = kind .. " challenges have reset since the last read"
            else
                parts[#parts + 1] = string.format("%s challenges %d of %d done", kind, done, total)
            end
        end
    end
    return #parts > 0 and table.concat(parts, "  ·  ") or nil
end
CT.ChallengeText = ChallengeText

local function RewardColumn(def)
    return { key = "reward." .. def.id, title = def.title, width = 96,
             head = string.format("Today's reward for a %s from the group finder.%s\nDone = earned, with the time until it can be earned again. Ready = waiting to be earned.",
                                  def.what, def.bonus and ("\n" .. def.bonus) or ""),
             value = function(e) return RewardIn(e.c, def.id) or -1 end,
             display = function(v) return v < 0 and "-" or (v == 0 and "Ready" or "Done") end,
             dim = function(v) return v < 0 end, gold = function(v) return v > 0 end,
             tip = function(e)
                 local left = RewardIn(e.c, def.id)
                 if not left then return "Not read yet: log in on this character once." end
                 if left == 0 then
                     return string.format("The daily %s reward is waiting%s.", def.what, def.bonus and ", with its large XP bonus" or "")
                 end
                 return string.format("Daily %s reward earned. The next one is ready in %s.", def.what, U.Duration(left))
             end }
end

-- Game only ---------------------------------------------------------------------------------

local function Read(c, account)
    local now = GetTimeStamp()
    c.rewardAt = c.rewardAt or {}
    local cooldowns = { dungeon = LFG_COOLDOWN_DUNGEON_REWARD_GRANTED, battleground = LFG_COOLDOWN_BATTLEGROUND_REWARD_GRANTED,
                        tribute = LFG_COOLDOWN_TRIBUTE_REWARD_GRANTED }
    for id, cooldown in pairs(cooldowns) do
        local left = GetLFGCooldownTimeRemainingSeconds(cooldown)
        c.rewardAt[id] = left > 0 and (now + left) or 0
    end
    if IsTimedActivitySystemAvailable() then
        local count = { [TIMED_ACTIVITY_TYPE_DAILY] = { 0, 0 }, [TIMED_ACTIVITY_TYPE_WEEKLY] = { 0, 0 } }
        for index = 1, GetNumTimedActivities() do
            local tally = count[GetTimedActivityType(index)]
            if tally then
                tally[2] = tally[2] + 1
                if GetTimedActivityProgress(index) >= GetTimedActivityMaxProgress(index) then tally[1] = tally[1] + 1 end
            end
        end
        local daily, weekly = count[TIMED_ACTIVITY_TYPE_DAILY], count[TIMED_ACTIVITY_TYPE_WEEKLY]
        account.challenges = {
            daily = table.concat({ daily[1], daily[2], GetTimedActivityTypeResetTimeS(TIMED_ACTIVITY_TYPE_DAILY) }, ";"),
            weekly = table.concat({ weekly[1], weekly[2], GetTimedActivityTypeResetTimeS(TIMED_ACTIVITY_TYPE_WEEKLY) }, ";"),
        }
    end
end

local function Start(queue, current)
    EVENT_MANAGER:RegisterForEvent(CT.name .. "Trial", EVENT_QUEST_COMPLETE, function(_, questName, _, _, _, _, questType)
        local c = current()
        if questType ~= QUEST_TYPE_RAID or not c then return end
        c.trials = c.trials or {}
        c.trials[#c.trials + 1] = GetTimeStamp() .. ";" .. U.Clean(U.Plain(questName))
        if #c.trials > TRIALS_KEPT then table.remove(c.trials, 1) end
        queue()
    end)
end

local columns = {}
for _, def in ipairs(REWARDS) do columns[#columns + 1] = RewardColumn(def) end
columns[#columns + 1] = {
    key = "trials", title = "Trials", width = 96,
    head = "Trials: trial quests this character handed in during the last 7 days.\nCounted from the day you started using this version.",
    value = function(e) return #RecentTrials(e.c) end,
    display = function(v) return v == 0 and "-" or U.Whole(v) end, dim = function(v) return v == 0 end,
    tip = function(e)
        local list = RecentTrials(e.c)
        if #list == 0 then return "No trial quest handed in during the last 7 days." end
        local lines = { "Trial quests handed in, last 7 days" }
        for _, trial in ipairs(list) do lines[#lines + 1] = string.format("  %s  (%s)", trial.name, U.DayTime(trial.at)) end
        return table.concat(lines, "\n")
    end }

CT.Track({
    id = "activities",
    read = Read,
    start = Start,
    events = { EVENT_ACTIVITY_FINDER_COOLDOWNS_UPDATE, EVENT_TIMED_ACTIVITIES_UPDATED, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED },
    columns = columns,
    sections = function(e)
        local items, now = {}, GetTimeStamp()
        for _, def in ipairs(REWARDS) do
            local left = RewardIn(e.c, def.id, now)
            if left then
                items[#items + 1] = { "Daily " .. def.what .. (def.bonus and " reward and XP bonus" or " reward"),
                                      left == 0 and "Ready" or "Done", done = left > 0 }
            end
        end
        local trials = #RecentTrials(e.c, now)
        if trials > 0 then items[#items + 1] = { "Trial quests, last 7 days", U.Whole(trials) } end
        if #items == 0 then return nil end
        return { { id = "daily", title = "Daily", items = items } }
    end,
})
