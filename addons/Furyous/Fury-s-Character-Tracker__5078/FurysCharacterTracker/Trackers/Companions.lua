-- shared
-- Companions. The collectible is account-wide, but each character has to finish a companion's
-- intro quest before it can summon them. So a companion counts for a character when the intro
-- quest is done on it, or when you have summoned that companion on it (which also covers characters
-- that skip the quest after you have unlocked a companion on three others).
--   c.companions, c.companionsTotal   short names this character can summon, and how many exist
--   data.companionSeen[id][name]      companions summoned on that character
--   account.companions[name]          "level;rapport;top rapport;when": read while that companion is out
-- A companion's level and rapport are the same on every character, and the game only tells them
-- for the companion that is out, so they fill in as you play with each one.
local CT = FurysCharacterTracker
local U = CT.Util

local NOT_READ = "Not read yet: log in on this character once."

-- Level and rapport of one companion on the account being viewed, or nil.
local function Level(name, data)
    local text = (((data or CT.Data()).account or {}).companions or {})[name]
    if not text then return nil end
    local p = U.Split(text, ";")
    return { level = tonumber(p[1]) or 0, rapport = tonumber(p[2]) or 0, rapportMax = tonumber(p[3]) or 0 }
end

local function WithLevel(name)
    local info = Level(name)
    return info and string.format("%s (level %d)", name, info.level) or name
end

-- Game only ---------------------------------------------------------------------------------

-- "Sharp-as-Night" -> "Sharp", "Azandar al-Cybiades" -> "Azandar": short names for the board.
local function ShortName(name)
    return name:match("^[^%s%-]+") or name
end

local INTRO_QUEST_BY_COMPANION = {}
for questId, companion in pairs(CT.INTRO_QUEST_IDS) do INTRO_QUEST_BY_COMPANION[companion] = questId end

-- English quest names: what /fct ids matches, and a second way to spot an intro quest whose ID is
-- not in Data/Lines.lua.
local INTRO_QUESTS = {
    ["competition and contracts"] = "Bastian", ["shattered and scattered"] = "Mirri",
    ["tower full of trouble"] = "Ember", ["tournament of the heart"] = "Isobel",
    ["the double edge"] = "Sharp", ["the fateweaver key"] = "Azandar",
    ["the garland ring"] = "Tanlorin", ["a moonlit shadow"] = "Zerith", ["a moonlight shadow"] = "Zerith",
}
CT.INTRO_QUEST_NAMES = INTRO_QUESTS

-- The intro quest of a companion, by its collectible: the IDs this version knows, else the game's
-- own answer for a companion added since.
local function IntroQuestId(collectibleId, name)
    local known = INTRO_QUEST_BY_COMPANION[name]
    if known then return known end
    local companionId = GetCollectibleReferenceId(collectibleId)
    if companionId and companionId ~= 0 and GetCompanionCollectibleId(companionId) == collectibleId then
        local questId = GetCompanionIntroQuestId(companionId)
        if questId and questId ~= 0 then return questId end
    end
end

-- Intro quests found by name instead of by ID. Walking every finished quest is slow, so it is done
-- at most once per login, and only when a companion you own is not accounted for by ID.
local doneByName
local function DoneByName(name)
    if not doneByName then
        doneByName = {}
        local questId = GetNextCompletedQuestId()
        while questId do
            if not CT.INTRO_QUEST_IDS[questId] then
                local companion = INTRO_QUESTS[zo_strlower(U.Plain(GetCompletedQuestInfo(questId)))]
                if companion then doneByName[companion] = true end
            end
            questId = GetNextCompletedQuestId(questId)
        end
    end
    return doneByName[name] == true
end

local function ActiveName()
    if not HasActiveCompanion() then return nil end
    local collectibleId = GetCompanionCollectibleId(GetActiveCompanionDefId())
    if not collectibleId or collectibleId == 0 then return nil end
    return ShortName(U.Plain(GetCollectibleName(collectibleId)))
end

local function Read(c, account)
    local unlocked, total = {}, 0
    local seen = (CT.sv.companionSeen or {})[GetCurrentCharacterId()] or {}
    local categoryType = COLLECTIBLE_CATEGORY_TYPE_COMPANION
    for index = 1, GetTotalCollectiblesByCategoryType(categoryType) do
        local collectibleId = GetCollectibleIdFromType(categoryType, index)
        local name = ShortName(U.Plain(GetCollectibleName(collectibleId)))
        total = total + 1
        if IsCollectibleUnlocked(collectibleId) then
            local questId = IntroQuestId(collectibleId, name)
            if seen[name] or (questId and HasCompletedQuest(questId)) or DoneByName(name) then
                unlocked[#unlocked + 1] = name
            end
        end
    end
    table.sort(unlocked)
    c.companions, c.companionsTotal = unlocked, total
    -- The companion that is out right now: its level and rapport, for every character's board.
    local active = ActiveName()
    if active then
        local level = GetActiveCompanionLevelInfo()
        account.companions = account.companions or {}
        account.companions[active] = table.concat({ level, GetActiveCompanionRapport(), GetMaximumRapport(), GetTimeStamp() }, ";")
    end
end

local function Start(queue)
    local function Register(suffix, event, fn) EVENT_MANAGER:RegisterForEvent(CT.name .. "Companion" .. suffix, event, fn) end
    -- Summoning a companion proves this character has it.
    Register("State", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
        local name = ActiveName()
        if not name then return end
        local sv, id = CT.sv, GetCurrentCharacterId()
        sv.companionSeen = sv.companionSeen or {}
        sv.companionSeen[id] = sv.companionSeen[id] or {}
        sv.companionSeen[id][name] = true
        queue()
    end)
    -- A finished quest matters only when it is a companion's intro quest.
    Register("Quest", EVENT_QUEST_REMOVED, function(_, isCompleted, _, questName, _, _, questId)
        if not isCompleted then return end
        local companion = CT.INTRO_QUEST_IDS[questId] or INTRO_QUESTS[zo_strlower(U.Plain(questName))]
        if not companion then return end
        if doneByName then doneByName[companion] = true end
        queue()
    end)
    -- Collectibles change for many reasons (a pet summoned, a hat hidden): only companions matter here.
    Register("Collectible", EVENT_COLLECTIBLE_UPDATED, function(_, collectibleId)
        if GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_COMPANION then queue() end
    end)
    Register("Unlocks", EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, queue)
    Register("Rapport", EVENT_COMPANION_RAPPORT_UPDATE, queue)
    Register("Level", EVENT_COMPANION_EXPERIENCE_GAIN, function(_, _, level)
        -- Experience comes in with every fight: only a new level is worth a read.
        local name = ActiveName()
        local saved = name and Level(name, CT.sv)
        if not saved or saved.level ~= level then queue() end
    end)
end

CT.Track({
    id = "companions",
    read = Read,
    start = Start,
    columns = {
        { key = "companions", title = "Companions", width = 100, max = function(e) return e.c.companionsTotal or CT.COMPANION_TOTAL end,
          head = "Companions this character can summon.\nEach character has to finish a companion's first quest before it can use them.\nHover a cell for their names and levels.",
          value = function(e) return #(e.c.companions or {}) end,
          display = function(v, e) return U.Of(v, e.c.companionsTotal or CT.COMPANION_TOTAL) end,
          tip = function(e)
              local list = e.c.companions or {}
              if #list == 0 then return "No companions unlocked" end
              local names = {}
              for i, name in ipairs(list) do names[i] = WithLevel(name) end
              return "Unlocked: " .. table.concat(names, ", ")
          end },
    },
    summary = function(e)
        return { CT.Trackers.Progress("Companions", #(e.c.companions or {}), e.c.companionsTotal or CT.COMPANION_TOTAL) }
    end,
    sections = function(e)
        local list = e.c.companions or {}
        if #list == 0 then return nil end
        local items, lines = {}, {}
        for _, name in ipairs(list) do
            local info = Level(name)
            if info then
                items[#items + 1] = { name, "Level " .. U.Whole(info.level), done = info.level >= CT.COMPANION_LEVEL_MAX }
                lines[#lines + 1] = string.format("%s %s of %s", name, U.Comma(info.rapport), U.Comma(info.rapportMax))
            else
                items[#items + 1] = { name, "unlocked", dim = true }
            end
        end
        local section = { title = "Companions", items = items, lines = {} }
        if #lines > 0 then section.lines[1] = "Rapport: " .. table.concat(lines, "  ·  ") end
        if #lines < #list then section.lines[#section.lines + 1] = "A companion's level shows here after you have had them out once with this version." end
        return { section }
    end,
    export = {
        { "Companions", function(e) return #(e.c.companions or {}) end },
        { "Companion names", function(e) return table.concat(e.c.companions or {}, ", ") end },
    },
})
