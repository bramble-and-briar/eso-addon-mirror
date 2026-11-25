-- Skill Point Finder: start-up, saved data and shared helpers.

ESOC_SkillPointFinder = ESOC_SkillPointFinder or {}
local SP = ESOC_SkillPointFinder

SP.NAME = "ESOCSkillPointFinder"
SP.TITLE = "Skill Point Finder"

local DEFAULTS = {
    characters = {},
    options = {
        showPanel = true,
        panelSeconds = 15,
        hidePvP = true,
        hideLocked = true,
        missingOnly = true,
    },
}

-- Calls a game function without letting an error stop the add-on.
function SP.Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, ...) }
    if not result[1] then return nil end
    return unpack(result, 2)
end

-- Whether an achievement is earned, the way the game's own Achievements screen decides it
-- (the "completed" value of GetAchievementInfo). For character achievements, such as the
-- group events, this is the character you're playing.
function SP.AchievementEarned(achievementId)
    if not achievementId or achievementId == 0 then return false end
    local ok, _, _, _, _, completed = pcall(GetAchievementInfo, achievementId)
    return ok and completed == true
end

-- Removes the game's grammar codes ("^n", "^F") from names.
function SP.Clean(text)
    if text == nil or text == "" then return "" end
    local ok, cleaned = pcall(zo_strformat, "<<1>>", text)
    return ok and cleaned or tostring(text)
end

function SP.Key(text)
    return string.lower(SP.Clean(text))
end

-- A looser key for matching names from different sources: no leading "The", plain apostrophes.
-- Kept cheap (no zo_strformat): it runs on thousands of quest and achievement names.
function SP.Loose(text)
    if text == nil then return "" end
    local key = string.lower(tostring(text))
    local caret = string.find(key, "^", 1, true)
    if caret then key = string.sub(key, 1, caret - 1) end
    key = string.gsub(key, "\226\128\153", "'")
    key = string.gsub(key, "%s+", " ")
    key = string.gsub(key, "^ ", "")
    key = string.gsub(key, " $", "")
    key = string.gsub(key, "^the ", "")
    return key
end

-- The important words of a name, without punctuation or filler words, for fuzzy matching.
local FILLER = { ["the"] = true, ["of"] = true, ["a"] = true, ["group"] = true, ["event"] = true }
function SP.Words(text)
    local words, count = {}, 0
    local plain = string.gsub(SP.Loose(text), "'", "")
    for word in string.gmatch(plain, "[%w%-]+") do
        if not FILLER[word] then
            words[word] = true
            count = count + 1
        end
    end
    return words, count
end

-- True when every important word of one name is in the other ("Na-Totambu" and "Lost City of the Na-Totambu").
function SP.WordsMatch(a, b)
    local wordsA, countA = SP.Words(a)
    local wordsB, countB = SP.Words(b)
    if countA == 0 or countB == 0 then return false end
    local small, large = wordsA, wordsB
    if countA > countB then small, large = wordsB, wordsA end
    for word in pairs(small) do
        if not large[word] then return false end
    end
    return true
end

function SP.Colour(hex, text)
    return "|c" .. hex .. text .. "|r"
end
SP.GREEN, SP.RED, SP.YELLOW, SP.GREY, SP.GOLD = "60d060", "ff7070", "ffd060", "a0a0a0", "f2cc66"

function SP.Alert(text)
    pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, SP.TITLE .. ": " .. text)
end

-- Skyshards found inside a delve or public dungeon are counted in the zone it sits in.
function SP.RootZone(zoneId)
    if not zoneId or zoneId == 0 then return 0 end
    local story = SP.Safe(GetZoneStoryZoneIdForZoneId, zoneId)
    if story and story ~= 0 then return story end
    local parent = SP.Safe(GetParentZoneId, zoneId)
    if parent and parent ~= 0 then return parent end
    return zoneId
end

function SP.PlayerZoneId()
    local index = SP.Safe(GetUnitZoneIndex, "player")
    return index and SP.Safe(GetZoneId, index) or 0
end

-- Dungeon quests finished while this add-on watched, by dungeon zone id. Kept per character.
local function onQuestComplete(_, _, _, _, _, _, questType)
    if questType ~= QUEST_TYPE_DUNGEON or not SP.character then return end
    local zoneId = SP.PlayerZoneId()
    if zoneId ~= 0 then SP.character.dungeonQuests[zoneId] = true end
    SP.MarkDirty()
end

local function onLoaded(_, addonName)
    if addonName ~= SP.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(SP.NAME, EVENT_ADD_ON_LOADED)
    SP.sv = ZO_SavedVars:NewAccountWide("ESOCSkillPointFinder_SV", 1, nil, DEFAULTS)
    local charId = GetCurrentCharacterId()
    SP.sv.characters[charId] = SP.sv.characters[charId] or {}
    SP.character = SP.sv.characters[charId]
    SP.character.overrides = SP.character.overrides or {}
    SP.character.dungeonQuests = SP.character.dungeonQuests or {}

    SP.Settings.Install()
    local function dirty() SP.MarkDirty() end
    EVENT_MANAGER:RegisterForEvent(SP.NAME, EVENT_PLAYER_ACTIVATED, function()
        SP.MarkDirty()
        SP.Scan.StartIndex()
        SP.Panel.OnZone()
    end)
    EVENT_MANAGER:RegisterForEvent(SP.NAME, EVENT_QUEST_COMPLETE, onQuestComplete)
    EVENT_MANAGER:RegisterForEvent(SP.NAME, EVENT_QUEST_ADDED, dirty)
    EVENT_MANAGER:RegisterForEvent(SP.NAME, EVENT_QUEST_REMOVED, dirty)
    EVENT_MANAGER:RegisterForEvent(SP.NAME, EVENT_SKILL_POINTS_CHANGED, dirty)
end

EVENT_MANAGER:RegisterForEvent(SP.NAME, EVENT_ADD_ON_LOADED, onLoaded)
