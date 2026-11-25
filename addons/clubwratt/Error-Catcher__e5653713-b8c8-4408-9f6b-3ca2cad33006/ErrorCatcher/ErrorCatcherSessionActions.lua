-- ErrorCatcherSessionActions.lua: a record of this UI load kept in the saved variables, and what the game
-- says about saving and about disabling add-ons
--
-- A crash leaves nothing behind but the saved variables as last written. This keeps one small record there
-- (who, where, when, the memory figures, whether a logout or a reload was asked for), updated in place, and
-- at the next UI load words what it finds: where the UI load before stood at its last save and how it
-- ended. It also asks the game to write this add-on's and the logger's saved variables first when it next
-- saves, so that a save outside a loading screen carries the newest lines.
local SessionActions = {}

local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils
local SessionUtils = ErrorCatcher.SessionUtils
local MemoryUtils = ErrorCatcher.MemoryUtils
local ScanUtils = ErrorCatcher.ScanUtils

local EVENT_NAMESPACE = ErrorCatcher.name .. "_Session"
-- The saved variables asked to be written first: the record, and the log itself.
local SAVE_FIRST = { ErrorCatcher.name, "LibConsoleLogger" }
-- A priority save is asked for at most this often.
local SAVE_REQUEST_SECONDS = 60
-- A save data write that takes this long is a line.
local SLOW_SAVE_SECONDS = 5
-- A logout or reload asked for longer ago than this did not happen.
local ASKED_SECONDS = 45
local MAX_SLOW_SAVE_LINES = 10
local MAX_SAVE_ERROR_LINES = 10
local MAX_LINE_CHARS = 220
-- Add-ons named for their saved variables on disk.
local MAX_DISK_NAMES = 8
local MIN_DISK_MB = 0.05

---@return ErrorCatcherSessionRecord|nil
local function Record()
    return ErrorCatcher.state.session.record
end

---@return number seconds Since this UI load began
local function Age()
    return math.max(0, math.floor(GameUtils.GameClock() - ErrorCatcher.state.memory.startClock))
end

---@param title string
---@param names string[]
local function WriteNames(title, names)
    for _, line in ipairs(ScanUtils.Pack(title, names, MAX_LINE_CHARS)) do
        Log.Line("%s", line)
    end
end

-- ------------------------------------------------------------------ the record

---Take a memory reading into the record.
---@param sample ErrorCatcherMemorySample
function SessionActions.Record(sample)
    local record = Record()
    if not record then
        return
    end
    record.wall, record.gameClock, record.age = sample.wall, sample.gameClock, sample.age
    record.used, record.capacity, record.heap = sample.used, sample.capacity, sample.heap
    record.pinsActive, record.pinsBuilt = sample.pinsActive, sample.pinsBuilt
    record.zone = sample.zone
    if not record.high or sample.used > record.high then
        record.high = sample.used
    end
    -- A logout or reload that was asked for ends the UI load within seconds; one still here after this long
    -- was called off, and what ends the UI load later is something else.
    if record.logoutWall and sample.wall - record.logoutWall > ASKED_SECONDS then
        record.logoutWall, record.logoutQuit = nil, nil
    end
    if record.reloadWall and sample.wall - record.reloadWall > ASKED_SECONDS then
        record.reloadWall = nil
    end
end

---Ask the game to write the record and the log first at its next save. Whether a console saves outside a
---loading screen at all shows after a crash: the record then says when it was last saved.
function SessionActions.RequestSave()
    local state = ErrorCatcher.state
    local session = state.session
    local sv = state.savedVars
    if sv.prioritySave == false or session.saveCallFailed then
        return
    end
    local clock = GameUtils.GameClock()
    if session.saveAskedAt and clock - session.saveAskedAt < SAVE_REQUEST_SECONDS then
        return
    end
    session.saveAskedAt = clock
    local manager = GameUtils.AddOnManager()
    if not manager then
        return
    end
    -- Marked before the call and cleared after: a call that raises past pcall is then not made again.
    if sv.prioritySaveTrying then
        session.saveCallFailed = true
        Log.Once("save:failed", "priority save: the last call did not return, so none is made (/ec save on tries again)")
        return
    end
    sv.prioritySaveTrying = true
    local asked = true
    for _, name in ipairs(SAVE_FIRST) do
        local ok = pcall(function()
            manager:RequestAddOnSavedVariablesPrioritySave(name)
        end)
        asked = asked and ok
    end
    sv.prioritySaveTrying = nil
    if asked then
        Log.Once("save:asked", "priority save asked for %s, again at most every %d s (/ec save off stops it)",
            table.concat(SAVE_FIRST, " and "), SAVE_REQUEST_SECONDS)
    else
        session.saveCallFailed = true
        Log.Once("save:failed", "priority save: the game has no such call here")
    end
end

---@param enabled boolean
function SessionActions.SetPrioritySave(enabled)
    local state = ErrorCatcher.state
    state.savedVars.prioritySave = enabled
    state.savedVars.prioritySaveTrying = nil
    state.session.saveCallFailed = false
    state.session.saveAskedAt = nil
    if enabled then
        SessionActions.RequestSave()
    end
end

---At this add-on's own load event, once its saved variables are attached: word the record the UI load before
---left, then begin this one's.
function SessionActions.Start()
    local state = ErrorCatcher.state
    local sv = state.savedVars
    local now = { wall = GameUtils.WallNow(), gameClock = GameUtils.GameClock() }
    for _, line in ipairs(SessionUtils.Previous(sv.session, now, GameUtils.WallClock)) do
        Log.Line("%s", line)
    end
    local number = (type(sv.loadCount) == "number" and sv.loadCount or 0) + 1
    sv.loadCount = number
    local record = {
        loadNumber = number,
        version = ErrorCatcher.version,
        character = GameUtils.CharacterName(),
        zone = GameUtils.ZoneName(),
        loadWall = now.wall,
        wall = now.wall,
        gameClock = now.gameClock,
        age = Age(),
        savesStarted = 0,
        savesCompleted = 0,
    }
    sv.session = record
    state.session.record = record
    Log.Line("this UI load: #%d on record, %s, %s (game clock %.1f s)", number, record.character,
        GameUtils.WallClock(now.wall), now.gameClock)
end

-- ------------------------------------------------------------------ how a UI load ends

local function OnActivated()
    local record = Record()
    if record then
        record.activatedWall = GameUtils.WallNow()
        record.wall, record.gameClock = record.activatedWall, GameUtils.GameClock()
        record.zone = GameUtils.ZoneName()
        record.character = GameUtils.CharacterName()
    end
end

local function OnDeactivated()
    local record = Record()
    if record then
        record.deactivatedWall = GameUtils.WallNow()
        record.wall, record.gameClock, record.age = record.deactivatedWall, GameUtils.GameClock(), Age()
    end
end

---@param quit any
local function NoteLogout(quit)
    local record = Record()
    if record then
        record.logoutWall = GameUtils.WallNow()
        record.logoutQuit = quit == true
        record.wall, record.gameClock, record.age = record.logoutWall, GameUtils.GameClock(), Age()
    end
end

local function NoteReload()
    local record = Record()
    if record then
        record.reloadWall = GameUtils.WallNow()
        record.wall, record.gameClock, record.age = record.reloadWall, GameUtils.GameClock(), Age()
    end
end

-- ------------------------------------------------------------------ saving

local function OnSaveStart()
    local session = ErrorCatcher.state.session
    session.saveStartedAt = GameUtils.GameClock()
    local record = Record()
    if record then
        record.savesStarted = (record.savesStarted or 0) + 1
    end
    Log.Once("save:first", "save data: the first write of this UI load began %d s after it (the console's autosave; counted from here on)", Age())
end

local function OnSaveComplete()
    local session = ErrorCatcher.state.session
    local record = Record()
    if record then
        record.savesCompleted = (record.savesCompleted or 0) + 1
    end
    local startedAt = session.saveStartedAt
    session.saveStartedAt = nil
    if startedAt then
        local took = GameUtils.GameClock() - startedAt
        if took >= SLOW_SAVE_SECONDS and session.slowSaves < MAX_SLOW_SAVE_LINES then
            session.slowSaves = session.slowSaves + 1
            Log.Line("save data: a write took %.1f s, %d s after UI load", took, Age())
        end
    end
end

---@return string
local function SaveCounts()
    local session = ErrorCatcher.state.session
    local record = Record()
    local started, completed = record and record.savesStarted or 0, record and record.savesCompleted or 0
    if session.saveStartedAt then
        return string.format("save data writes this UI load: %d started / %d completed, one under way for %.1f s",
            started, completed, GameUtils.GameClock() - session.saveStartedAt)
    end
    return string.format("save data writes this UI load: %d started / %d completed", started, completed)
end
SessionActions.SaveCounts = SaveCounts

---@param manager any
---@return string|nil
local function DiskTotals(manager)
    local used = GameUtils.ManagerRead(manager, "GetTotalUserAddOnSavedVariablesDiskUsageMB")
    local capacity = GameUtils.ManagerRead(manager, "GetTotalUserAddOnSavedVariablesDiskCapacityMB")
    if type(used) ~= "number" then
        return nil
    end
    local text = string.format("saved variables on disk: %.2f/%s MB", used, type(capacity) == "number" and string.format("%d", capacity) or "?")
    local unused = GameUtils.ManagerRead(manager, "GetTotalUnusedAddOnSavedVariablesDiskUsageMB")
    if type(unused) == "number" and unused >= MIN_DISK_MB then
        text = text .. string.format(", %.2f of it left by add-ons no longer installed", unused)
    end
    return text
end

---@param errorType any
---@param note fun(label: string) Writes a memory reading under a label
local function OnSaveLoadError(errorType, note)
    local session = ErrorCatcher.state.session
    session.saveErrors = session.saveErrors + 1
    if session.saveErrors > MAX_SAVE_ERROR_LINES then
        return
    end
    -- The line first: what is read after it could fail, and this is the one that matters.
    Log.Line("SAVE/LOAD ERROR from the game: %s, %d s after UI load; %s",
        SessionUtils.SaveLoadErrorName(errorType, _G), Age(), SaveCounts())
    note("save/load error")
    local manager = GameUtils.AddOnManager()
    local disk = manager and DiskTotals(manager) or nil
    if disk then
        Log.Line("at the save/load error: %s", disk)
    end
end

-- ------------------------------------------------------------------ add-ons the game disabled

---@param manager any
---@return string[] names
local function ForceDisabled(manager)
    local names = {}
    local count = GameUtils.ManagerRead(manager, "GetNumForceDisabledAddOns")
    for index = 1, type(count) == "number" and count or 0 do
        local name, _shouldNotify, title = GameUtils.ManagerRead(manager, "GetForceDisabledAddOnInfo", index)
        names[#names + 1] = tostring(type(name) == "string" and name ~= "" and name or title)
    end
    table.sort(names)
    return names
end

---Write the add-ons the game has force-disabled, when the list differs from the last one written.
local function WriteForceDisabled()
    local manager = GameUtils.AddOnManager()
    if not manager then
        return
    end
    local names = ForceDisabled(manager)
    local joined = table.concat(names, ", ")
    local session = ErrorCatcher.state.session
    if joined == session.forceDisabled then
        return
    end
    session.forceDisabled = joined
    if #names == 0 then
        Log.Line("add-ons the game force-disabled: none any more")
    else
        WriteNames(string.format("add-ons the game force-disabled (%d)", #names), names)
    end
end

---Which add-ons are enabled, against the UI load before; the saved variables on disk; what the game has
---disabled. Run in a queued step of its own, after the add-on list was read.
function SessionActions.ReadAddOns()
    local state = ErrorCatcher.state
    local sv = state.savedVars
    local enabled = state.load.enabled
    local character = GameUtils.CharacterName()
    if enabled then
        local before = type(sv.enabled) == "table" and sv.enabled or nil
        local added, removed = SessionUtils.EnabledDiff(before and before.names, enabled)
        Log.Line("%s", SessionUtils.EnabledHeading(#enabled, character, before, #added + #removed > 0))
        if before then
            WriteNames("enabled now, not on the UI load before", added)
            WriteNames("enabled on the UI load before, not now", removed)
        end
        local names = {}
        for index, name in ipairs(enabled) do
            names[index] = name
        end
        sv.enabled = { character = character, names = names }
    end

    -- From here in the order of what matters most: a call the game refuses outright ends the step.
    if GameUtils.Read("ShouldWarnConsoleAddOnMemoryLimit") == true then
        Log.Line("the game holds a notice: add-ons ran out of their memory and were disabled")
    end
    if GameUtils.Read("ShouldWarnConsoleAddOnSavedVariableLimit") == true then
        Log.Line("the game holds a notice: saved variables failed to save for lack of disk space")
    end
    WriteForceDisabled()

    local manager = GameUtils.AddOnManager()
    if not manager then
        return
    end
    local totals = DiskTotals(manager)
    if totals then
        Log.Line("%s", totals)
        local uses = {}
        local count = GameUtils.ManagerRead(manager, "GetNumAddOns")
        for index = 1, type(count) == "number" and count or 0 do
            local megabytes = GameUtils.ManagerRead(manager, "GetUserAddOnSavedVariablesDiskUsageMB", index)
            if type(megabytes) == "number" and megabytes >= MIN_DISK_MB then
                local name = GameUtils.ManagerRead(manager, "GetAddOnInfo", index)
                uses[#uses + 1] = { name = tostring(name), megabytes = megabytes }
            end
        end
        WriteNames("largest saved variables, MB", MemoryUtils.Largest(uses, MAX_DISK_NAMES, MIN_DISK_MB))
    end
end

-- ------------------------------------------------------------------ wiring

---Follow the calls that end a UI load. At file scope, with the other hooks.
---@return string[] installed Names of the functions followed
function SessionActions.Install()
    local installed = {}
    if GameUtils.SecureHookGlobal("ReloadUI", "Session.ReloadUI", NoteReload) then
        installed[#installed + 1] = "ReloadUI"
    end
    if GameUtils.SecureHookGlobal("Logout", "Session.Logout", function() NoteLogout(false) end) then
        installed[#installed + 1] = "Logout"
    end
    if GameUtils.SecureHookGlobal("Quit", "Session.Quit", function() NoteLogout(true) end) then
        installed[#installed + 1] = "Quit"
    end
    return installed
end

---@param note fun(label: string) Writes a memory reading under a label
function SessionActions.Register(note)
    local function On(eventName, label, handler)
        -- An event this client lacks reads nil and is left out.
        local event = _G[eventName]
        if event ~= nil then
            EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, event, GameUtils.Guard(label, handler))
        end
    end
    On("EVENT_PLAYER_ACTIVATED", "Session.OnActivated", OnActivated)
    On("EVENT_PLAYER_DEACTIVATED", "Session.OnDeactivated", OnDeactivated)
    On("EVENT_LOGOUT_DEFERRED", "Session.OnLogoutDeferred", function(_event, _deferMilliseconds, quit)
        NoteLogout(quit)
    end)
    On("EVENT_LOGOUT_DISALLOWED", "Session.OnLogoutDisallowed", function()
        local record = Record()
        if record then
            record.logoutWall, record.logoutQuit = nil, nil
        end
    end)
    On("EVENT_SAVE_DATA_START", "Session.OnSaveStart", OnSaveStart)
    On("EVENT_SAVE_DATA_COMPLETE", "Session.OnSaveComplete", OnSaveComplete)
    On("EVENT_SLD_SAVE_LOAD_ERROR", "Session.OnSaveLoadError", function(_event, errorType)
        OnSaveLoadError(errorType, note)
    end)
    On("EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED", "Session.OnMemoryLimit", function()
        Log.Line("the game says add-ons ran out of their memory: it disables them now, %d s after UI load", Age())
        note("add-on memory limit reached")
    end)
    On("EVENT_CONSOLE_ADD_ONS_SAVED_VARIABLES_LIMIT_REACHED", "Session.OnSavedVariablesLimit", function()
        Log.Line("the game says saved variables failed to save for lack of disk space, %d s after UI load", Age())
        local manager = GameUtils.AddOnManager()
        local disk = manager and DiskTotals(manager) or nil
        if disk then
            Log.Line("at that notice: %s", disk)
        end
    end)
    On("EVENT_ADDONS_DISABLED_STATE_CHANGED", "Session.OnDisabledState", function(_event, forceDisabled)
        Log.Once("disabled:" .. tostring(forceDisabled), "the game changed whether add-ons are disabled: force-disabled=%s, %d s after UI load",
            tostring(forceDisabled), Age())
    end)
    On("EVENT_CONSOLE_ADDONS_DISABLED_STATE_CHANGED", "Session.OnConsoleDisabledState", function(_event, disabled)
        Log.Once("consoleDisabled:" .. tostring(disabled), "the game changed whether console add-ons are disabled: disabled=%s, %d s after UI load",
            tostring(disabled), Age())
    end)
    On("EVENT_FORCE_DISABLED_ADDONS_UPDATED", "Session.OnForceDisabled", WriteForceDisabled)
end

ErrorCatcher.SessionActions = SessionActions
