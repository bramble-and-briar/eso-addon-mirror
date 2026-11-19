-- Reads everything the native battleground scoreboard exposes.
local SBR = ScoreboardRemastered
local BG = {}
SBR.Battleground = BG

-- Column order, short labels and table priority for every SCORE_TRACKER_TYPE_* in
-- API 101051. Priority decides what stays in the PC table when it has to shrink to
-- fit the screen (1 = always, 2 = objectives, 3 = extras); everything is still in
-- the details pane. Only these are read: scanning _G for unknown
-- SCORE_TRACKER_TYPE_* constants cost a large frame spike on load.
local PRIORITY = {
    { "SCORE", "Score", 1 },
    { "KILL", "Kills", 1 },
    { "DEATH", "Deaths", 1 },
    { "ASSISTS", "Assists", 1 },
    { "DAMAGE_DONE", "Damage", 1 },
    { "HEALING_DONE", "Healing", 1 },
    { "FLAG_CAPTURED", "Flags", 2 },
    { "KILLED_FLAG_CARRIER", "FC kills", 2 },
    { "FLAG_CARRIED_TIME", "Carried", 2 },
    { "CAPTURE_DEFENSE_POINTS", "Def pts", 2 },
    { "KILL_STREAK", "Streak", 3 },
    { "DAMAGE_TAKEN", "Dmg taken", 3 },
    { "DAMAGED_FLAG_CARRIER", "FC dmg", 3 },
    { "HEALED_FLAG_CARRIER", "FC heal", 3 },
    { "CAPTURE_KILLED_ATTACKER", "Atk kills", 3 },
    { "CAPTURE_KILLED_DEFENDER", "Def kills", 3 },
    { "HEALING_DEFENDERS", "Def heal", 3 },
    { "DAMAGE_SHIELDS_GRANTED", "Shields", 3 },
    { "BUFFS_GRANTED", "Buffs", 3 },
    { "DEBUFFS_GRANTED", "Debuffs", 3 },
    -- older names, kept in case a client still defines them
    { "FLAG_RETURNED", "Returns", 2 },
    { "RELIC_CAPTURED", "Relics", 2 },
    { "CAPTURE_POINT", "Captures", 2 },
}


local FALLBACK_TEAM_COLORS = { "F0723C", "6BC26B", "A77BE0" } -- drakes, daemons, storm lords

function BG:DiscoverScoreTypes()
    local list, seenKey, seenId = {}, {}, {}

    local function add(suffix, label, priority)
        if seenKey[suffix] then return end
        local id = _G["SCORE_TRACKER_TYPE_" .. suffix]
        if type(id) ~= "number" or seenId[id] then return end
        seenKey[suffix], seenId[id] = true, true
        list[#list + 1] = { key = suffix, id = id, label = label or SBR.Prettify(suffix), priority = priority or 3 }
    end

    for _, entry in ipairs(PRIORITY) do add(entry[1], entry[2], entry[3]) end

    self.scoreTypes = list
    return list
end

function BG:IsInBattleground()
    if SBR.HasAPI("IsActiveWorldBattleground") then
        return SBR.API("IsActiveWorldBattleground") == true
    end
    local id = SBR.API("GetCurrentBattlegroundId")
    return type(id) == "number" and id ~= 0
end

function BG:GetTeamRange()
    local first = SBR.Const("BATTLEGROUND_TEAM_ITERATION_BEGIN", "BATTLEGROUND_ALLIANCE_ITERATION_BEGIN")
    local last = SBR.Const("BATTLEGROUND_TEAM_ITERATION_END", "BATTLEGROUND_ALLIANCE_ITERATION_END")
    return first or 1, last or 3
end

function BG:GetTeamName(team)
    local name = SBR.API("GetBattlegroundTeamName", team)
    if type(name) == "string" and name ~= "" then return SBR.CleanName(name) end
    for _, prefix in ipairs({ "SI_BATTLEGROUNDTEAM", "SI_BATTLEGROUNDALLIANCE" }) do
        local ok, s = pcall(GetString, prefix, team)
        if ok and s and s ~= "" then return s end
    end
    return "Team " .. tostring(team)
end

function BG:GetTeamColorHex(team)
    for _, fnName in ipairs({ "GetBattlegroundTeamColor", "GetBattlegroundAllianceColor" }) do
        local color = SBR.API(fnName, team)
        if type(color) == "table" and color.ToHex then
            local hex = SBR.SafeCall(color.ToHex, color)
            if hex then return hex end
        end
    end
    return FALLBACK_TEAM_COLORS[team] or "FFFFFF"
end

function BG:GetLocalTeam()
    return SBR.API("GetUnitBattlegroundTeam", "player") or SBR.API("GetUnitBattlegroundAlliance", "player")
end

function BG:GetRoundIndex()
    return SBR.API("GetCurrentBattlegroundRoundIndex")
end

function BG:GetStateName(state)
    if state == nil then return "Unknown" end
    local names = {
        BATTLEGROUND_STATE_NONE = "None",
        BATTLEGROUND_STATE_PREROUND = "Round starting",
        BATTLEGROUND_STATE_STARTING = "Starting",
        BATTLEGROUND_STATE_RUNNING = "Running",
        BATTLEGROUND_STATE_POSTROUND = "Round over",
        BATTLEGROUND_STATE_FINISHED = "Finished",
    }
    for constName, label in pairs(names) do
        if _G[constName] == state then return label end
    end
    return tostring(state)
end

function BG:IsPostGame(state)
    return state ~= nil and (state == _G.BATTLEGROUND_STATE_POSTGAME or state == _G.BATTLEGROUND_STATE_FINISHED)
end

function BG:IsRunning(state)
    return state ~= nil and state == _G.BATTLEGROUND_STATE_RUNNING
end

-- Match-level info: id, name, game type, state, teams and team scores.
function BG:ReadMatchInfo()
    local info = {}
    info.battlegroundId = SBR.API("GetCurrentBattlegroundId")
    if info.battlegroundId then
        info.name = SBR.API("GetBattlegroundName", info.battlegroundId)
        info.gameType = SBR.API("GetCurrentBattlegroundGameType", self:GetRoundIndex())
            or SBR.API("GetBattlegroundGameType", info.battlegroundId, self:GetRoundIndex())
        if info.gameType then
            local ok, s = pcall(GetString, "SI_BATTLEGROUNDGAMETYPE", info.gameType)
            info.gameTypeName = ok and s ~= "" and s or nil
        end
        info.teamSize = SBR.API("GetBattlegroundTeamSize", info.battlegroundId)
        info.numTeams = SBR.API("GetBattlegroundNumTeams", info.battlegroundId)
        info.numRounds = SBR.API("GetBattlegroundNumRounds", info.battlegroundId)
        info.limitedLives = SBR.API("DoesBattlegroundHaveLimitedPlayerLives", info.battlegroundId) == true
    end
    info.zoneName = SBR.API("GetUnitZone", "player")
    info.state = SBR.API("GetCurrentBattlegroundState")
    info.stateName = self:GetStateName(info.state)
    info.roundIndex = self:GetRoundIndex()
    info.localTeam = self:GetLocalTeam()
    info.shutdownTimer = SBR.API("GetCurrentBattlegroundShutdownTimer")

    -- GetCurrentBattlegroundScore(roundIndex, team): the score of the current round,
    -- the same call the native scoreboard makes. Multi-round modes also record rounds won.
    info.teams = {}
    local first, last = self:GetTeamRange()
    local round = info.roundIndex or 1
    for team = first, last do
        info.teams[team] = {
            id = team,
            name = self:GetTeamName(team),
            color = self:GetTeamColorHex(team),
            score = SBR.API("GetCurrentBattlegroundScore", round, team),
            roundsWon = (info.numRounds or 1) > 1 and SBR.API("GetCurrentBattlegroundRoundsWonByTeam", team) or nil,
        }
    end
    return info
end

-- Info that never changes during a session, looked up once.
local classInfo, medalInfo, entryNames = {}, {}, {}

local function ClassInfo(classId)
    local c = classInfo[classId]
    if not c then
        local className = SBR.API("GetClassName", GENDER_MALE or 1, classId)
        -- ZO_GetClassIcon is the real function; GetClassIcon is only a PC compatibility alias
        c = { name = className and SBR.CleanName(className) or nil,
              icon = SBR.API("ZO_GetClassIcon", classId) or SBR.API("GetClassIcon", classId) }
        classInfo[classId] = c
    end
    return c
end

local function MedalInfo(medalId)
    local m = medalInfo[medalId]
    if not m then
        local name, icon, condition, scoreReward = SBR.API("GetMedalInfo", medalId)
        m = { name = name and SBR.CleanName(name) or ("Medal " .. medalId), icon = icon, condition = condition,
              scoreReward = scoreReward }
        medalInfo[medalId] = m
    end
    return m
end

local function EntryName(raw)
    if raw == nil or raw == "" then return "" end
    local c = entryNames[raw]
    if not c then
        c = SBR.CleanName(raw)
        entryNames[raw] = c
    end
    return c
end

-- Mirrors ZO_BattlegroundMedalInfo (battlegroundmedalinfo_shared.lua): a nil round
-- index means the whole match, read through the cumulative medal API; a round
-- index reads that round. Both walk medal ids with a "next id" iterator.
local function MedalIterator(entryIndex, roundIndex)
    if roundIndex == nil and SBR.HasAPI("GenerateCumulativeMedalInfoForScoreboardEntry") then
        GenerateCumulativeMedalInfoForScoreboardEntry(entryIndex, BG:GetRoundIndex())
        return GetNextBattlegroundCumulativeMedalId, GetBattlegroundCumulativeNumEarnedMedalsById
    end
    if not SBR.HasAPI("GetNextScoreboardEntryMedalId") then
        return function() return nil end, function() return 0 end
    end
    return function(last) return GetNextScoreboardEntryMedalId(entryIndex, roundIndex, last) end,
           function(id) return GetScoreboardEntryNumEarnedMedalsById(entryIndex, id, roundIndex) end
end

local function ReadMedals(entryIndex, roundIndex)
    local medals = {}
    local nextId, countOf = MedalIterator(entryIndex, roundIndex)
    local medalId = nextId(nil)
    local guard = 0
    while medalId and guard < 64 do
        guard = guard + 1
        local medalCount = countOf(medalId)
        local info = MedalInfo(medalId)
        medals[#medals + 1] = { id = medalId, count = medalCount or 1, name = info.name, icon = info.icon }
        medalId = nextId(medalId)
    end
    table.sort(medals, function(a, b) return (a.count or 0) > (b.count or 0) end)
    return medals
end

-- Like ESO's own scoreboard (RebuildPlayerData in battlegroundscoreboard.lua): the
-- entries of the current round, with whole-match totals in multi-round modes
-- (Elimination and other round-based modes) and the lives each player has left
-- where lives are limited. Without the round index, round-based modes report the
-- wrong round and the board never moves.
local function ReadEntriesUnprotected(self, roundIndex)
    local types = self.scoreTypes or self:DiscoverScoreTypes()
    roundIndex = roundIndex or (GetCurrentBattlegroundRoundIndex and GetCurrentBattlegroundRoundIndex()) or nil
    local bgId = GetCurrentBattlegroundId and GetCurrentBattlegroundId()
    local rounds = bgId and GetBattlegroundNumRounds and GetBattlegroundNumRounds(bgId) or 1
    local cumulative = (rounds or 1) > 1 and type(GetBattlegroundCumulativeScoreForScoreboardEntryByType) == "function"
    local limitedLives = bgId and type(DoesBattlegroundHaveLimitedPlayerLives) == "function" and DoesBattlegroundHaveLimitedPlayerLives(bgId)
    local GetLives = limitedLives and GetScoreboardEntryNumLivesRemaining or nil
    local GetInfo, GetClassId = GetScoreboardEntryInfo, GetScoreboardEntryClassId
    local GetScore = cumulative and GetBattlegroundCumulativeScoreForScoreboardEntryByType or GetScoreboardEntryScoreByType
    local entries = {}
    local n = GetNumScoreboardEntries(roundIndex) or 0
    for i = 1, n do
        local characterName, displayName, team, isLocal = GetInfo(i, roundIndex)
        if characterName or displayName then
            local e = {
                characterName = EntryName(characterName),
                displayName = displayName or "",
                team = team,
                isLocal = isLocal == true,
                scores = {},
            }
            e.classId = GetClassId and GetClassId(i, roundIndex) or nil
            if e.classId then
                local c = ClassInfo(e.classId)
                e.className, e.classIcon = c.name, c.icon
            end
            local scores = e.scores
            for _, st in ipairs(types) do
                local v = GetScore(i, st.id, roundIndex)
                if type(v) == "number" then scores[st.key] = v end
            end
            if GetLives then e.lives = GetLives(i, roundIndex) end
            -- medals: whole match (the cumulative medal API, like the native medal panel)
            e.medals = ReadMedals(i, nil)
            local medalTotal = 0
            for _, m in ipairs(e.medals) do medalTotal = medalTotal + (m.count or 1) end
            e.medalCount = medalTotal
            entries[#entries + 1] = e
        end
    end
    return entries
end

-- Every row the native scoreboard shows, with every score type it tracks.
-- Runs every snapshot, so the game functions are called directly inside a single
-- pcall (not one protected call each: a snapshot reads ~500 values).
function BG:ReadEntries(roundIndex)
    local ok, entries = pcall(ReadEntriesUnprotected, self, roundIndex)
    if ok then return entries end
    SBR.Debug("reading the scoreboard failed: %s", tostring(entries))
    return {}
end

function BG:EntryKey(e)
    if e.displayName and e.displayName ~= "" then return e.displayName end
    return e.characterName
end
ScoreboardRemastered.Mark("Data/Battleground.lua")
