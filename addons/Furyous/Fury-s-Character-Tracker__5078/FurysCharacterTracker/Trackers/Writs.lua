-- shared
-- Daily crafting writs per character: started, ready to deliver, done today.
--   c.writs[craft] = { state =, at = }   craft = the game's craft number; at = when it got that state
--   c.writCrafts = "1,2,6"              the crafts this character is certified for (can take writs for)
-- The daily reset is 10:00 UTC on NA and 03:00 UTC on EU (since Update 37).
--
-- Which craft a writ is for is found without reading its name, so it works on every game language:
-- the quest's own "craft this" steps say which craft they need. The quest's ID is remembered with
-- its craft (data.writQuestIds), because a writ that is ready to deliver has no such step left.
-- On an English client the quest's name comes first (1.8.5), because it is never wrong.
local CT = FurysCharacterTracker
local U = CT.Util
local Daily = {}
CT.Daily = Daily

-- Order on the board. `match` finds the craft in the writ's English quest name.
Daily.CRAFTS = {
    { craft = CRAFTING_TYPE_BLACKSMITHING, short = "Smith", match = "blacksmith" },
    { craft = CRAFTING_TYPE_CLOTHIER, short = "Cloth", match = "clothier" },
    { craft = CRAFTING_TYPE_WOODWORKING, short = "Wood", match = "woodworker" },
    { craft = CRAFTING_TYPE_JEWELRYCRAFTING, short = "Jewelry", match = "jewelry" },
    { craft = CRAFTING_TYPE_ALCHEMY, short = "Alchemy", match = "alchemist" },
    { craft = CRAFTING_TYPE_ENCHANTING, short = "Enchant", match = "enchanter" },
    { craft = CRAFTING_TYPE_PROVISIONING, short = "Provis", match = "provisioner" },
}
local IS_WRIT_CRAFT = {}
for _, def in ipairs(Daily.CRAFTS) do IS_WRIT_CRAFT[def.craft] = true end

Daily.NONE, Daily.STARTED, Daily.DELIVER, Daily.DONE = 0, 1, 2, 3
Daily.LABEL = { [0] = "-", [1] = "Started", [2] = "Deliver", [3] = "Done" }

-- When today's reset happened on a megaserver.
function Daily.LastReset(world, now)
    now = now or GetTimeStamp()
    local hour = string.find(world or "", "EU", 1, true) and 3 or 10
    local reset = now - now % 86400 + hour * 3600
    if reset > now then reset = reset - 86400 end
    return reset
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

-- Writs done today, in hand (started or ready to deliver) and ready to deliver, for one character.
function Daily.Count(c, world, now)
    local done, inHand, deliver = 0, 0, 0
    for _, def in ipairs(Daily.CRAFTS) do
        local state = Daily.State(c, def.craft, world, now)
        if state == Daily.DONE then done = done + 1 elseif state ~= Daily.NONE then inHand = inHand + 1 end
        if state == Daily.DELIVER then deliver = deliver + 1 end
    end
    return done, inHand, deliver
end

-- The crafts a character is certified for, as a set, or nil if 1.5.2 has not read it yet.
function Daily.Certified(c)
    if not c.writCrafts then return nil end
    local set = {}
    for craft in string.gmatch(c.writCrafts, "%d+") do set[tonumber(craft)] = true end
    return set
end

-- Game only ---------------------------------------------------------------------------------

local function CraftFromName(questName, word)
    local name = zo_strlower(U.Plain(questName))
    if not string.find(name, word or "writ", 1, true) then return nil end
    for _, def in ipairs(Daily.CRAFTS) do
        if string.find(name, def.match, 1, true) then return def.craft end
    end
end

local function IsDailyWrit(journalIndex)
    return GetJournalQuestType(journalIndex) == QUEST_TYPE_CRAFTING and GetJournalQuestRepeatType(journalIndex) == QUEST_REPEAT_DAILY
end

-- The craft named by the quest's own "craft this" steps, or nil when it has none (ready to deliver).
local function CraftFromSteps(journalIndex)
    for condition = 1, GetJournalQuestNumConditions(journalIndex, QUEST_MAIN_STEP_INDEX) do
        local _, _, craft = GetQuestConditionItemInfo(journalIndex, QUEST_MAIN_STEP_INDEX, condition)
        if IS_WRIT_CRAFT[craft] then return craft end
    end
end

local function SaysDeliver(journalIndex)
    for condition = 1, GetJournalQuestNumConditions(journalIndex, QUEST_MAIN_STEP_INDEX) do
        local text = GetJournalQuestConditionInfo(journalIndex, QUEST_MAIN_STEP_INDEX, condition)
        if string.find(zo_strlower(U.Plain(text)), "deliver", 1, true) then return true end
    end
    return false
end

-- The craft and state of the daily writ at one journal slot, or nil if it cannot be told yet.
local function ReadWrit(journalIndex)
    local sv = CT.sv
    sv.writQuestIds = sv.writQuestIds or {}
    local questId = GetJournalQuestId(journalIndex)
    local fromSteps = CraftFromSteps(journalIndex)
    if fromSteps then sv.writBySteps = true end
    -- 1.8.5: on an English client the quest's name is the surest sign (the steps of an alchemy
    -- writ can point at another craft), then the steps, then the quest's ID as learned before.
    local craft = CraftFromName(GetJournalQuestName(journalIndex)) or fromSteps or sv.writQuestIds[questId]
    if not craft then return nil end
    sv.writQuestIds[questId] = craft
    local state = Daily.STARTED
    if GetJournalQuestIsComplete(journalIndex) or SaysDeliver(journalIndex) then
        state = Daily.DELIVER
    elseif not fromSteps and sv.writBySteps then
        -- The steps name the craft on this client, and this writ has none left: all that remains is the hand-in.
        state = Daily.DELIVER
    end
    return craft, state
end

-- Which crafts this character is certified for. The game has no direct answer, so it is read from
-- the quests the character has finished: a crafting quest that is a known daily writ (by quest
-- ID, any language) or, on an English client, is named as a craft's certification or writ. Any
-- writ seen in the journal counts too. Walking every finished quest is slow: once per login.
local certifiedByQuests
local function ReadCertified(c)
    if not certifiedByQuests then
        certifiedByQuests = {}
        local known = CT.sv.writQuestIds or {}
        local questId = GetNextCompletedQuestId()
        while questId do
            local name, questType = GetCompletedQuestInfo(questId)
            if questType == QUEST_TYPE_CRAFTING then
                local craft = known[questId] or CraftFromName(name, "certification") or CraftFromName(name)
                if craft then certifiedByQuests[craft] = true end
            end
            questId = GetNextCompletedQuestId(questId)
        end
    end
    local have = Daily.Certified(c) or {}
    local list = {}
    for _, def in ipairs(Daily.CRAFTS) do
        if have[def.craft] or certifiedByQuests[def.craft] or (c.writs or {})[def.craft] then list[#list + 1] = def.craft end
    end
    c.writCrafts = table.concat(list, ",")
end

-- Writ states for the character you are on: what is in the journal now, plus writs finished
-- earlier (kept until they are from before today's reset).
local function Read(c)
    local previous, writs, inJournal = c.writs, {}, {}
    for journalIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(journalIndex) and IsDailyWrit(journalIndex) then
            local craft, state = ReadWrit(journalIndex)
            if craft then
                local old = previous and previous[craft]
                writs[craft] = { state = state, at = (old and old.state == state and old.at) or GetTimeStamp() }
                inJournal[craft] = true
            end
        end
    end
    -- 1.8.5: a writ of today that was in the journal and is gone was handed in, even when the game's
    -- "quest removed" event was missed (an abandoned writ is cleared by that event, below).
    local today = Daily.LastReset(CT.home and CT.home.world)
    for craft, entry in pairs(previous or {}) do
        if not inJournal[craft] then
            if entry.state == Daily.DONE then
                writs[craft] = entry
            elseif entry.at >= today then
                writs[craft] = { state = Daily.DONE, at = GetTimeStamp() }
            end
        end
    end
    c.writs = writs
    ReadCertified(c)
end

local function Start(queue, current)
    local function Register(suffix, event, fn) EVENT_MANAGER:RegisterForEvent(CT.name .. "Writ" .. suffix, event, fn) end
    -- Fires for every quest, on every objective tick: only a daily crafting writ is worth a look.
    local function OnQuestChanged(_, journalIndex)
        if IsValidQuestIndex(journalIndex) and IsDailyWrit(journalIndex) then queue(true) end
    end
    Register("Added", EVENT_QUEST_ADDED, OnQuestChanged)
    Register("Advanced", EVENT_QUEST_ADVANCED, OnQuestChanged)
    Register("Counter", EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnQuestChanged)
    -- Handed in (done today) or abandoned (gone).
    Register("Removed", EVENT_QUEST_REMOVED, function(_, isCompleted, _, questName, _, _, questId)
        local craft = CraftFromName(questName) or (CT.sv.writQuestIds or {})[questId]
        local c = current()
        if not craft or not c then return end
        c.writs = c.writs or {}
        c.writs[craft] = isCompleted and { state = Daily.DONE, at = GetTimeStamp() } or nil
        queue(true)
    end)
    -- 1.8.5: read the writs again whenever any quest is finished or removed, and once more on the
    -- way out (logout, character switch, reload), so a hand-in is never missed.
    Register("Complete", EVENT_QUEST_COMPLETE, function() queue(true) end)
    EVENT_MANAGER:RegisterForEvent(CT.name .. "WritOut", EVENT_PLAYER_DEACTIVATED, function()
        local c = current()
        if c then Read(c) end
    end)
end

-- Columns --------------------------------------------------------------------------------------

local columns = {}
for _, def in ipairs(Daily.CRAFTS) do
    columns[#columns + 1] = {
        key = "writ." .. def.short, title = def.short, width = 74, max = Daily.DONE, bar = false,
        head = function() return U.CraftName(def.craft) .. " writ today: - not taken, Started, Deliver (ready to hand in) or Done." end,
        value = function(e) return Daily.State(e.c, def.craft, CT.view.world) end,
        display = function(v) return Daily.LABEL[v] end,
        tip = function(e)
            local world = CT.view.world
            local entry, state = (e.c.writs or {})[def.craft], Daily.State(e.c, def.craft, world)
            local craft = U.CraftName(def.craft)
            local text = state == Daily.NONE and (craft .. " writ: not taken today")
                or string.format("%s writ: %s (%s)", craft, ({ "started", "ready to deliver", "done today" })[state], U.DayTime(entry.at))
            return text .. "\nWrits reset daily at " .. os.date("%I:%M %p", Daily.LastReset(world) + 86400) .. " your time."
        end }
end
columns[#columns + 1] = {
    key = "writsDone", title = "Done", width = 64, max = #Daily.CRAFTS,
    head = "Done: crafting writs turned in since today's reset, out of 7.",
    value = function(e) return (Daily.Count(e.c, CT.view.world)) end,
    display = function(v) return U.Of(v, #Daily.CRAFTS) end,
    tip = "Crafting writs turned in since today's reset" }

CT.Track({
    id = "writs",
    read = Read,
    start = Start,
    columns = columns,
    sections = function(e)
        local world, now = CT.view.world, GetTimeStamp()
        local items = {}
        for _, def in ipairs(Daily.CRAFTS) do
            local state = Daily.State(e.c, def.craft, world, now)
            items[#items + 1] = { U.CraftName(def.craft) .. " writ", Daily.LABEL[state], done = state == Daily.DONE, dim = state == Daily.NONE }
        end
        return { { title = "Daily", id = "daily", items = items } }
    end,
})
