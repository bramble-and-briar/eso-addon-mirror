-- Every achievement that rewards a title, found by walking the achievement categories once per
-- session. Auto zone mode, title envy and next titles all read it.
local FT = Flexatron
local TitleIndex = {}
FT.TitleIndex = TitleIndex

local MAX_LINE = 60 -- safety cap when following one achievement line

local entries -- { { id = achievementId, title = titleName }, ... }
local byKey   -- [comparable title text] = { achievementId, ... }

-- Title text in a form both sides can compare: grammar marks gone, trimmed, lower case.
local function Key(text)
    text = text:gsub("%^%a*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(text)
end

local function AddKey(key, id)
    if key == "" then
        return
    end
    local ids = byKey[key]
    if not ids then
        ids = {}
        byKey[key] = ids
    end
    for _, known in ipairs(ids) do
        if known == id then
            return
        end
    end
    ids[#ids + 1] = id
end

local function Consider(id, seen)
    if seen[id] then
        return
    end
    seen[id] = true
    local hasTitle, titleName = GetAchievementRewardTitle(id)
    if hasTitle and titleName and titleName ~= "" then
        entries[#entries + 1] = { id = id, title = titleName }
        -- the title as it reads for each gender, and for this character
        AddKey(Key(titleName), id)
        AddKey(Key(zo_strformat(titleName, "A^Mx")), id)
        AddKey(Key(zo_strformat(titleName, "A^Fx")), id)
        AddKey(Key(zo_strformat(titleName, GetRawUnitName("player"))), id)
    end
end

-- Achievement lists only show one rank of each line, so follow the whole line.
local function ConsiderLine(id, seen)
    if not id or id == 0 then
        return
    end
    local current = GetFirstAchievementInLine(id)
    if not current or current == 0 then
        current = id
    end
    for _ = 1, MAX_LINE do
        Consider(current, seen)
        local nextId = GetNextAchievementInLine(current)
        if not nextId or nextId == 0 or seen[nextId] then
            break
        end
        current = nextId
    end
    Consider(id, seen)
end

function TitleIndex.Build()
    entries, byKey = {}, {}
    local seen = {}
    for top = 1, GetNumAchievementCategories() do
        local _, numSubCategories, numAchievements = GetAchievementCategoryInfo(top)
        for a = 1, numAchievements or 0 do
            ConsiderLine(GetAchievementId(top, nil, a), seen)
        end
        for sub = 1, numSubCategories or 0 do
            local _, count = GetAchievementSubCategoryInfo(top, sub)
            for a = 1, count or 0 do
                ConsiderLine(GetAchievementId(top, sub, a), seen)
            end
        end
    end
end

local function Ensure()
    if not entries then
        TitleIndex.Build()
    end
end

-- Build it during the first loading screen rather than the first time someone is aimed at.
function TitleIndex.Warm()
    if FT.sv.autoMode or FT.sv.titleEnvy then
        Ensure()
    end
end

-- Every title achievement: { { id, title }, ... }.
function TitleIndex.Entries()
    Ensure()
    return entries
end

-- Achievement ids that grant a title shown as this text (e.g. another player's title), or nil.
function TitleIndex.Lookup(displayTitle)
    if not displayTitle or displayTitle == "" then
        return nil
    end
    Ensure()
    return byKey[Key(displayTitle)]
end

-- ---- Kinds of title, for the quick picks in settings. Read from the achievement's English text:
-- a hard mode says "hard mode" (newer dungeons: "Challenge Banner"; older dungeons name it
-- "... Challenger"), and a trifecta is a hard mode done without a death and within a time limit in
-- one run (or says "trifecta").

local function Mentions(text, words)
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then
            return true
        end
    end
    return false
end

local HARD = { "hard mode", "hardmode", "challenge banner" }
local NO_DEATH = { "without suffering a group member death", "without dying", "without any group member dying",
    "without a group member dying", "without a death", "without anyone dying" }
local TIME_LIMIT = { "minute", "time limit" }

local function KindOfAchievement(id)
    local name, description = GetAchievementInfo(id)
    name, description = string.lower(name or ""), string.lower(description or "")
    local text = name .. " " .. description
    if string.find(text, "trifecta", 1, true) then
        return "trifecta"
    end
    local hard = Mentions(text, HARD) or string.find(name, "challenger", 1, true) ~= nil
    if hard and Mentions(description, NO_DEATH) and Mentions(description, TIME_LIMIT) then
        return "trifecta"
    end
    return hard and "hard" or nil
end

local kinds = {} -- [title name] = "trifecta", "hard" or false

-- "trifecta", "hard" or nil for a title, from the achievements that grant it (the best one wins).
function TitleIndex.KindOf(titleName)
    if kinds[titleName] == nil then
        local kind = false
        for _, id in ipairs(TitleIndex.Lookup(titleName) or {}) do
            local found = KindOfAchievement(id)
            if found == "trifecta" or (found == "hard" and not kind) then
                kind = found
            end
        end
        kinds[titleName] = kind
    end
    return kinds[titleName] or nil
end

-- True if the player completed any achievement that grants this title.
function TitleIndex.Owns(ids)
    for _, id in ipairs(ids) do
        if IsAchievementComplete(id) then
            return true
        end
    end
    return false
end
