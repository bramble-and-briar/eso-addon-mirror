-- Match lifecycle + persistent log (SavedVariables).
local SBR = ScoreboardRemastered
local ML = {}
SBR.MatchLog = ML

-- EVENT_BATTLEGROUND_SCOREBOARD_UPDATED fires about every second during a match.
-- Snapshots are throttled: often while something of ours (or the native board) is on
-- screen, rarely otherwise. The final snapshot at the end of the match is always taken.
local SNAPSHOT_THROTTLE_VISIBLE_MS = 1000
local SNAPSHOT_THROTTLE_HIDDEN_MS = 4000
local PERIODIC_MS = 15000

-- SavedVariables can only hold plain data; strip anything else and cap depth.
local function Sanitize(v, depth)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then return v end
    if t ~= "table" or depth > 6 then return nil end
    local out = {}
    for k, val in pairs(v) do
        if type(k) == "string" or type(k) == "number" then
            out[k] = Sanitize(val, depth + 1)
        end
    end
    return out
end

function ML:Init(sv)
    self.sv = sv
    sv.history = sv.history or {}
end

function ML:GetCurrent()
    return self.sv.current
end

function ML:GetHistory()
    return self.sv.history
end

-- The match the live view should show: in-progress first, else the last finished one.
function ML:GetLive()
    return self.sv.current or self.sv.history[#self.sv.history]
end

function ML:Begin(info)
    local now = SBR.Now()
    local match = {
        version = 1,
        id = string.format("%d-%s", now, tostring(info.battlegroundId or 0)),
        battlegroundId = info.battlegroundId,
        startedAt = now,
        startedMs = GetGameTimeMilliseconds(),
        character = SBR.CleanName(GetUnitName("player")),
        account = GetUnitDisplayName("player"),
        players = {},
        killFeed = {},
        myMedals = {},
        rounds = {},
        columnsSeen = {},
    }
    self.sv.current = match
    self:StartTracking(match)
    SBR.Debug("match begin %s", match.id)
    return match
end

-- LibFights for your own fights, plus the per-player combat ledger for everyone.
function ML:StartTracking(match)
    SBR.LibFights:Attach(match)
    SBR.FightTracker:Start(match)
    self:StartPeriodic()
end

-- Your row: LibFights' summary, with anything it lacks filled from the ledger.
-- Everyone else: the ledger.
local function PlayerFightStats(match, agg, p)
    local FT = SBR.FightTracker
    local ledger = FT.ledger and FT:GetPlayerStats(p.characterName, match.localTeam ~= nil and p.team ~= match.localTeam)
    if not p.isLocal then return ledger end
    local lf = SBR.LibFights:GetPlayerStats(agg, p)
    if not lf then return ledger end
    if ledger then
        lf = SBR.ShallowCopy(lf)
        for k, v in pairs(ledger) do
            if lf[k] == nil then lf[k] = v end
        end
        lf.source = "LibFights"
    end
    return lf
end

-- Kills and deaths between you and each player, from the battleground kill feed.
local function KillFeedVs(match)
    local vs = {}
    local function get(n) vs[n] = vs[n] or { killedByYou = 0, killedYou = 0 } return vs[n] end
    local me = match.character
    for _, k in ipairs(match.killFeed or {}) do
        if k.killer == me and k.victim and k.victim ~= "" then get(k.victim).killedByYou = get(k.victim).killedByYou + 1 end
        if k.victim == me and k.killer and k.killer ~= "" then get(k.killer).killedYou = get(k.killer).killedYou + 1 end
    end
    return vs
end

function ML:ApplyInfo(match, info)
    match.battlegroundId = info.battlegroundId or match.battlegroundId
    match.name = info.name or match.name
    match.zoneName = info.zoneName or match.zoneName
    match.gameType = info.gameType or match.gameType
    match.gameTypeName = info.gameTypeName or match.gameTypeName
    match.teamSize = info.teamSize or match.teamSize
    match.numTeams = info.numTeams or match.numTeams
    match.numRounds = info.numRounds or match.numRounds
    match.state = info.state
    match.stateName = info.stateName
    match.localTeam = info.localTeam or match.localTeam
    match.roundIndex = info.roundIndex or match.roundIndex
    match.teams = match.teams or {}
    for id, t in pairs(info.teams) do
        local existing = match.teams[id] or {}
        existing.id, existing.name, existing.color = id, t.name, t.color
        if t.score ~= nil then existing.score = t.score end
        if t.roundsWon ~= nil then existing.roundsWon = t.roundsWon end
        match.teams[id] = existing
    end
    if SBR.Battleground:IsRunning(info.state) and not match.runningSince then
        match.runningSince = SBR.Now()
    end
end

function ML:Snapshot()
    local match = self.sv.current
    if not match then return end
    local BG = SBR.Battleground
    local info = BG:ReadMatchInfo()
    self:ApplyInfo(match, info)

    local agg = SBR.LibFights:BuildAggregate(match)
    local killVs = KillFeedVs(match)
    local present = {}
    for _, e in ipairs(BG:ReadEntries()) do
        local key = BG:EntryKey(e)
        present[key] = true
        local p = match.players[key] or { firstSeen = SBR.Now() }
        p.characterName = e.characterName ~= "" and e.characterName or p.characterName
        p.displayName = e.displayName ~= "" and e.displayName or p.displayName
        p.team = e.team or p.team
        p.isLocal = e.isLocal or p.isLocal
        p.classId, p.className, p.classIcon = e.classId or p.classId, e.className or p.className, e.classIcon or p.classIcon
        p.scores = e.scores
        p.medals = e.medals
        p.medalCount = e.medalCount
        p.left = nil
        for k in pairs(e.scores) do match.columnsSeen[k] = true end

        local fight = PlayerFightStats(match, agg, p)
        if fight or match.lf or match.ledger then
            -- Overwrite with nil too: a live LibFights fight it later discards
            -- (shorter than its minFightSeconds) must drop out again.
            -- the ledger's stats are fresh plain tables; only LibFights' need cleaning
            p.fight = fight and (p.isLocal and Sanitize(fight, 0) or fight) or nil
        end
        if not p.isLocal then
            local vs = (SBR.FightTracker.ledger and SBR.FightTracker:GetVsStats(p.characterName))
                or SBR.LibFights:GetVsStats(agg, p.characterName)
            local kv = killVs[p.characterName]
            if kv then
                vs = vs or {}
                vs.killedByYou, vs.killedYou = kv.killedByYou, kv.killedYou
            end
            if vs then p.vs = vs end
        end

        match.players[key] = p
    end
    for key, p in pairs(match.players) do
        if not present[key] then p.left = true end
    end

    match.lastSnapshot = SBR.Now()
    match.elapsed = (GetGameTimeMilliseconds() - (match.startedMs or GetGameTimeMilliseconds())) / 1000

    -- Per-round snapshot of team scores so multi-round modes keep their history.
    if match.roundIndex then
        local r = match.rounds[match.roundIndex] or {}
        r.teams = {}
        for id, t in pairs(match.teams) do r.teams[id] = t.score end
        match.rounds[match.roundIndex] = r
    end

    SBR.Window:OnDataChanged()
end

function ML:RequestSnapshot()
    if not self.sv.current or self.snapshotPending then return end
    -- Throttle, not debounce: a burst of updates yields one snapshot within 500ms
    -- instead of postponing it forever.
    self.snapshotPending = true
    local ns = SBR.name .. "_Snapshot"
    EVENT_MANAGER:RegisterForUpdate(ns, self:IsAnythingShowing() and SNAPSHOT_THROTTLE_VISIBLE_MS or SNAPSHOT_THROTTLE_HIDDEN_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(ns)
        ML.snapshotPending = false
        ML:Snapshot()
    end)
end

function ML:IsAnythingShowing()
    local W, GP, Hook = SBR.Window, SBR.Gamepad, SBR.Hook
    if W and W.control and not W.control:IsHidden() then return true end
    if GP and GP:IsShowing() then return true end
    if Hook and Hook.IsNativeVisible and Hook:IsNativeVisible() then return true end
    return false
end

function ML:StartPeriodic()
    EVENT_MANAGER:RegisterForUpdate(SBR.name .. "_Periodic", PERIODIC_MS, function() ML:Snapshot() end)
end

function ML:StopPeriodic()
    EVENT_MANAGER:UnregisterForUpdate(SBR.name .. "_Periodic")
end

local function DetermineResult(match)
    -- multi-round modes are decided by rounds won, everything else by score
    local useRounds = false
    for _, t in pairs(match.teams or {}) do
        if type(t.roundsWon) == "number" and t.roundsWon > 0 then useRounds = true end
    end
    local function value(t) if useRounds then return t.roundsWon else return t.score end end
    local best, bestTeam, tie = nil, nil, false
    for id, t in pairs(match.teams or {}) do
        local v = value(t)
        if type(v) == "number" then
            if best == nil or v > best then
                best, bestTeam, tie = v, id, false
            elseif v == best then
                tie = true
            end
        end
    end
    match.winner = (not tie) and bestTeam or nil
    if not match.localTeam or best == nil then return "unknown" end
    local mine = match.teams[match.localTeam]
    if tie and mine and value(mine) == best then return "tie" end
    return match.winner == match.localTeam and "won" or "lost"
end

-- reason: "finished" (post-game reached), "left" (zoned out early), "reload" (stale on login)
function ML:Finalize(reason)
    local match = self.sv.current
    if not match then return end
    if reason ~= "reload" then
        SBR.LibFights:Detach(match) -- closes the running LibFights fight first
        self:Snapshot()
    end
    SBR.LibFights:Compact(match)
    match.ledger = nil -- every player's row already holds their ledger stats
    self:StopPeriodic()
    SBR.FightTracker:Stop()

    match.endedAt = SBR.Now()
    match.duration = match.endedAt - (match.runningSince or match.startedAt)
    match.endReason = reason
    match.result = reason == "finished" and DetermineResult(match) or (reason == "left" and "left" or "unknown")
    match.startedMs = nil

    table.insert(self.sv.history, match)
    if reason ~= "reload" or next(match.players or {}) then SBR.MatchDB:Add(match) end
    local max = self.sv.maxHistory or 50
    while #self.sv.history > max do table.remove(self.sv.history, 1) end
    self.sv.current = nil

    if SBR.sv.chatSummary and reason ~= "reload" then self:PrintSummary(match) end
    SBR.Window:OnDataChanged()
    SBR.Debug("match finalized (%s)", reason)
end

function ML:FindLocalPlayer(match)
    for _, p in pairs(match.players or {}) do
        if p.isLocal then return p end
    end
end

function ML:PrintSummary(match)
    local me = self:FindLocalPlayer(match)
    local resultText = ({ won = "|c66FF66Victory|r", lost = "|cFF6666Defeat|r", tie = "Tie", left = "Left early" })[match.result] or "Ended"
    local s = me and me.scores or {}
    local f = me and me.fight or {}
    SBR.Print("%s - %s (%s) | K/D/A %s/%s/%s | Dmg %s | Heal %s | Medals %s | /sbr to view",
        resultText, match.name or "Battleground", SBR.FormatDuration(match.duration),
        tostring(s.KILL or "-"), tostring(s.DEATH or "-"), tostring(s.ASSISTS or "-"),
        SBR.FormatNumber(s.DAMAGE_DONE or f.damageDone), SBR.FormatNumber(s.HEALING_DONE or f.healingDone),
        tostring(me and me.medalCount or 0))
end

-- Zone change: start, resume or close a match.
function ML:OnPlayerActivated()
    local BG = SBR.Battleground
    local inBG = BG:IsInBattleground()
    local current = self.sv.current
    local bgId = SBR.API("GetCurrentBattlegroundId")

    if current and (not inBG or (bgId and current.battlegroundId and bgId ~= current.battlegroundId)) then
        self:Finalize(self.loggedIn and "left" or "reload")
        current = nil
    end
    self.loggedIn = true

    if inBG then
        if current then
            -- /reloadui mid-match: keep the log, restart live tracking.
            self:StartTracking(current)
        else
            self:Begin(BG:ReadMatchInfo())
        end
        self:RequestSnapshot()
    end
end

function ML:OnStateChanged(previousState, currentState)
    local BG = SBR.Battleground
    if not self.sv.current and BG:IsInBattleground() then
        self:Begin(BG:ReadMatchInfo())
    end
    local match = self.sv.current
    if not match then return end
    match.stateLog = match.stateLog or {}
    table.insert(match.stateLog, { at = SBR.Now(), state = currentState, name = BG:GetStateName(currentState) })

    if BG:IsPostGame(currentState) then
        self:Finalize("finished")
    else
        self:RequestSnapshot()
    end
end

function ML:OnKill(...)
    local match = self.sv.current
    if not match then return end
    local victimChar, victimDisplay, victimTeam, killerChar, killerDisplay, killerTeam, killType, abilityId = ...
    local entry = {
        at = SBR.Now(),
        t = match.startedMs and (GetGameTimeMilliseconds() - match.startedMs) / 1000 or nil,
        victim = SBR.CleanName(victimChar), victimAccount = victimDisplay, victimTeam = victimTeam,
        killer = SBR.CleanName(killerChar), killerAccount = killerDisplay, killerTeam = killerTeam,
        killType = killType,
        abilityId = type(abilityId) == "number" and abilityId or nil,
    }
    if entry.abilityId then entry.ability = SBR.CleanName(SBR.API("GetAbilityName", entry.abilityId) or "") end
    -- Death recap for any player whose last hits the client saw (you and your group's fights).
    if SBR.FightTracker.ledger and entry.victim ~= "" then
        entry.recap = SBR.FightTracker:GetRecentHits(entry.victim, 15000)
    end
    table.insert(match.killFeed, entry)
    self:RequestSnapshot()
end

function ML:OnMedal(medalId, name, icon, value)
    local match = self.sv.current
    if not match then return end
    table.insert(match.myMedals, { at = SBR.Now(), id = medalId, name = SBR.CleanName(name), icon = icon, value = value })
end

function ML:ClearHistory()
    ZO_ClearNumericallyIndexedTable(self.sv.history)
    SBR.Window:OnDataChanged()
end
