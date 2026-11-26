-- The reader. Reads the character you are logged in on, one tracked thing at a time (the files in
-- Trackers/). Everything is read once at login. After that each thing is read again only when one
-- of its own game events fires (a rank up reads skills, a recipe reads recipes...), a few seconds
-- later and never in combat.
local CT = FurysCharacterTracker
local U = CT.Util
local Scan = {}
CT.Scan = Scan

local SCAN_DELAY_MS = 3000   -- many events can arrive together (a stack of recipes): read once, when they settle
local SOON_MS = 400          -- for things you are looking at while they change (a writ handed in)

function Scan.CurrentName()
    return U.Plain(GetUnitName("player"))
end

-- The saved table of the character you are on, or nil before its first read.
function Scan.Current()
    return CT.sv.characters[GetCurrentCharacterId()]
end

-- Queue -------------------------------------------------------------------------------------

local waiting = {}        -- [part id] = true: parts to read at the next quiet moment
local waitingAll = false

function Scan:Queue(partId, soon)
    if partId then waiting[partId] = true else waitingAll = true end
    local key = CT.name .. "Scan"
    EVENT_MANAGER:UnregisterForUpdate(key)
    EVENT_MANAGER:RegisterForUpdate(key, soon and SOON_MS or SCAN_DELAY_MS, function()
        if IsUnitInCombat("player") then return end   -- try again in a moment
        EVENT_MANAGER:UnregisterForUpdate(key)
        local parts = (not waitingAll) and waiting or nil
        waiting, waitingAll = {}, false
        self:Run(parts)
    end)
end

function Scan:Start()
    -- Wait a few seconds after login: the game builds its skill data at the same moment.
    self:Queue()
    for _, tracker in ipairs(CT.Trackers.list) do
        if tracker.read then
            local function queue(soon) self:Queue(tracker.id, soon == true) end
            for index, event in ipairs(tracker.events or {}) do
                EVENT_MANAGER:RegisterForEvent(CT.name .. "Scan_" .. tracker.id .. index, event, queue)
            end
            if tracker.start then tracker.start(queue, Scan.Current) end
        end
    end
    -- On the way out (logout, /reloadui, a loading screen): time played only moves while you play,
    -- and the rows for the Excel export are written once here instead of after every read.
    EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_PLAYER_DEACTIVATED, function()
        CT.Roster:UpdatePlayed(GetCurrentCharacterId(), GetSecondsPlayed())
        CT.Roster:BuildExportRows()
    end)
end

-- Reads the parts named in `parts` ({ [part id] = true }), or every part when it is nil. A character
-- with nothing saved yet is always read in full.
function Scan:Run(parts)
    local sv, id = CT.sv, GetCurrentCharacterId()
    local c = sv.characters[id]
    if not c or c.source ~= "live" then
        c, parts = { source = "live" }, nil
    end
    sv.account = sv.account or {}
    for _, tracker in ipairs(CT.Trackers.list) do
        if tracker.read and (not parts or parts[tracker.id]) then tracker.read(c, sv.account) end
    end
    c.lastScan = GetTimeStamp()
    if not parts then c.v = CT.READ_VERSION end
    CT.Roster:Store(id, c)
    CT.Refresh()
end

-- /fct ids: prints the language-neutral IDs of every tracked skill line and companion intro quest
-- this character has, ready to paste into Data/Lines.lua. Run it on an English client.
function Scan:PrintIds()
    local lineIds, questIds = {}, {}
    for _, skillType in ipairs({ SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_WORLD, SKILL_TYPE_GUILD, SKILL_TYPE_AVA, SKILL_TYPE_TRADESKILL }) do
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local lineId = GetSkillLineId(skillType, lineIndex)
            local name = U.Plain(GetSkillLineNameById(lineId))
            if CT.LINE_BY_NAME[name] then lineIds[#lineIds + 1] = string.format("[%d] = \"%s\"", lineId, name) end
        end
    end
    local questId = GetNextCompletedQuestId()
    while questId do
        local companion = CT.INTRO_QUEST_NAMES[zo_strlower(U.Plain(GetCompletedQuestInfo(questId)))]
        if companion then questIds[#questIds + 1] = string.format("[%d] = \"%s\"", questId, companion) end
        questId = GetNextCompletedQuestId(questId)
    end
    table.sort(lineIds); table.sort(questIds)
    U.Print("Skill line IDs (%d): %s", #lineIds, table.concat(lineIds, ", "))
    U.Print("Companion quest IDs (%d): %s", #questIds, table.concat(questIds, ", "))
    CT.sv.ids = { lines = lineIds, quests = questIds }   -- also saved, so they can be read from the file
end
