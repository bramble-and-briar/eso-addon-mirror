-- Daily: crafting writs per character (started, ready to deliver, done today) and the riding lesson
-- timer. The daily reset is 10:00 UTC on NA and 03:00 UTC on EU (since Update 37).
local CT = FurysCharacterTracker
local U = CT.Util
local Daily = {}
CT.Daily = Daily

-- Order on the board. `match` finds the craft in the writ's quest name (English client).
Daily.CRAFTS = {
    { craft = CRAFTING_TYPE_BLACKSMITHING, short = "Smith", match = "blacksmith" },
    { craft = CRAFTING_TYPE_CLOTHIER, short = "Cloth", match = "clothier" },
    { craft = CRAFTING_TYPE_WOODWORKING, short = "Wood", match = "woodworker" },
    { craft = CRAFTING_TYPE_JEWELRYCRAFTING, short = "Jewelry", match = "jewelry" },
    { craft = CRAFTING_TYPE_ALCHEMY, short = "Alchemy", match = "alchemist" },
    { craft = CRAFTING_TYPE_ENCHANTING, short = "Enchant", match = "enchanter" },
    { craft = CRAFTING_TYPE_PROVISIONING, short = "Provis", match = "provisioner" },
}

Daily.NONE, Daily.STARTED, Daily.DELIVER, Daily.DONE = 0, 1, 2, 3
Daily.LABEL = { [0] = "-", [1] = "Started", [2] = "Deliver", [3] = "Done" }

-- When today's reset happened on a megaserver.
function Daily.LastReset(world, now)
    now = now or GetTimeStamp()
    local hour = (world or ""):find("EU") and 3 or 10
    local reset = now - now % 86400 + hour * 3600
    if reset > now then reset = reset - 86400 end
    return reset
end

-- The craft a daily writ quest is for, or nil if it is not one.
local function WritCraft(questName)
    local name = zo_strlower(U.Plain(questName))
    if not name:find("writ") then return nil end
    for _, def in ipairs(Daily.CRAFTS) do
        if name:find(def.match, 1, true) then return def.craft end
    end
end
Daily.WritCraft = WritCraft

local function IsDailyWrit(journalIndex)
    local _, _, _, _, _, _, _, _, _, questType = GetJournalQuestInfo(journalIndex)
    return questType == QUEST_TYPE_CRAFTING and GetJournalQuestRepeatType(journalIndex) == QUEST_REPEAT_DAILY
end

-- Started, or ready to hand in (the step asks you to deliver).
local function JournalState(journalIndex)
    for condition = 1, GetJournalQuestNumConditions(journalIndex, QUEST_MAIN_STEP_INDEX) do
        local text = GetJournalQuestConditionInfo(journalIndex, QUEST_MAIN_STEP_INDEX, condition)
        if zo_strlower(U.Plain(text)):find("deliver", 1, true) then return Daily.DELIVER end
    end
    return Daily.STARTED
end

-- Writ states for the character you are on: what is in the journal now, plus writs finished
-- earlier (kept until they are from before today's reset).
function Daily.ReadWrits(previous)
    local writs, inJournal = {}, {}
    for journalIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(journalIndex) and IsDailyWrit(journalIndex) then
            local craft = WritCraft(GetJournalQuestName(journalIndex))
            if craft then
                local old = previous and previous[craft]
                local state = JournalState(journalIndex)
                writs[craft] = { state = state, at = (old and old.state == state and old.at) or GetTimeStamp() }
                inJournal[craft] = true
            end
        end
    end
    for craft, entry in pairs(previous or {}) do
        if not inJournal[craft] and entry.state == Daily.DONE then writs[craft] = entry end
    end
    return writs
end

-- What the board shows for one craft: started and deliver as they are, done only if it was today.
function Daily.State(c, craft, world, now)
    local entry = (c.writs or {})[craft]
    if not entry then return Daily.NONE end
    if entry.state == Daily.DONE then
        return entry.at >= Daily.LastReset(world, now) and Daily.DONE or Daily.NONE
    end
    return entry.state
end

-- Event handlers: keep the current character's writs up to date as you play.
local function Current() return CT.sv.characters[CT.Scan.CurrentName()] end

local function Changed()
    CT.Window:RefreshIfShown()
end

local function OnQuestChanged(_, journalIndex)
    local c = Current()
    if not c then return end
    c.writs = Daily.ReadWrits(c.writs)
    Changed()
end

local function OnQuestComplete(_, questName)
    local craft = WritCraft(questName)
    local c = Current()
    if not craft or not c then return end
    c.writs = c.writs or {}
    c.writs[craft] = { state = Daily.DONE, at = GetTimeStamp() }
    Changed()
end

local function OnQuestRemoved(_, isCompleted, _, questName)
    local craft = WritCraft(questName)
    local c = Current()
    if not craft or not c or isCompleted then return end   -- completed: handled by OnQuestComplete
    c.writs = c.writs or {}
    c.writs[craft] = nil                                    -- abandoned
    Changed()
end

-- Riding lesson: the moment the next one can be taken (0 = now), nil once riding is maxed.
function Daily.RidingReadyAt(riding, ridingMax)
    if riding >= ridingMax then return nil end
    local ms = GetTimeUntilCanBeTrained() or 0
    return ms > 0 and (GetTimeStamp() + math.ceil(ms / 1000)) or 0
end

function Daily:Start()
    EVENT_MANAGER:RegisterForEvent(CT.name .. "WritAdded", EVENT_QUEST_ADDED, OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(CT.name .. "WritAdvanced", EVENT_QUEST_ADVANCED, OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(CT.name .. "WritCounter", EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(CT.name .. "WritComplete", EVENT_QUEST_COMPLETE, OnQuestComplete)
    EVENT_MANAGER:RegisterForEvent(CT.name .. "WritRemoved", EVENT_QUEST_REMOVED, OnQuestRemoved)
end
