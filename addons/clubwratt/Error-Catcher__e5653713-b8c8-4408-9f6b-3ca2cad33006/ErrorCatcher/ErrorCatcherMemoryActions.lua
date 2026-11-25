-- ErrorCatcherMemoryActions.lua: how much memory the add-ons take, when it grows and where
--
-- The game gives one figure for every add-on together (the pool) and none per add-on. This reads the pool
-- and the Lua heap at this add-on's own load and at the load event of every add-on after it, which gives
-- those add-ons a figure each, and then every few seconds for as long as the UI lives. Both figures are read
-- live on the console (2026-11-24: a 1.00 MB table moved the pool by 1.02 MB). A figure per load event is
-- what was allocated between the load event before and that one; whether that holds the add-on's files is
-- what LoadActions' "files before events check" says. A reading becomes a line on entering
-- the world, on every zone change, on a new high, and at the game's own low memory warning; every reading
-- goes into the record SessionActions keeps, so the last one saved survives a crash.
local MemoryActions = {}

local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils
local MemoryUtils = ErrorCatcher.MemoryUtils
local ScanUtils = ErrorCatcher.ScanUtils
local SessionActions = ErrorCatcher.SessionActions

local UPDATE_NAME = ErrorCatcher.name .. "_Memory"
local EVENT_NAMESPACE = ErrorCatcher.name .. "_Memory"
local SAMPLE_MS = 5000
-- Memory lines per UI load; past it one notice is written and the readings go to the record only.
local MAX_LINES = 120
-- Add-ons recorded as loading after this one.
local MAX_LOADED = 400
-- A smaller change at an add-on's load event is counted, not named.
local MIN_ADDON_MB = 0.1
local MAX_LINE_CHARS = 220

---Read the game. The one sample table is filled again each time.
---@return ErrorCatcherMemorySample|nil sample nil when the game gives no pool figure
local function Read()
    local memory = ErrorCatcher.state.memory
    local used, capacity = GameUtils.Pool()
    if not used then
        return nil
    end
    local sample = memory.sample
    sample.used, sample.capacity = used, capacity or sample.capacity
    sample.heap = GameUtils.HeapMB()
    sample.pinsActive, sample.pinsBuilt = GameUtils.PinCounts()
    sample.wall, sample.gameClock = GameUtils.WallNow(), GameUtils.GameClock()
    sample.age = math.max(0, math.floor(sample.gameClock - memory.startClock))
    sample.zone, sample.scene = GameUtils.ZoneName(), GameUtils.SceneName()
    sample.rangeLow, sample.rangeHigh, memory.rangeFull = MemoryUtils.Range(memory.ring, used)
    SessionActions.Record(sample)
    return sample
end

---Move the mark to a reading that was just written.
---@param label string
---@param sample ErrorCatcherMemorySample
local function Mark(label, sample)
    local mark = ErrorCatcher.state.memory.mark
    mark.used, mark.age = sample.used, sample.age
    if label == MemoryUtils.REASON_DROP then
        mark.high = sample.rangeHigh
    elseif sample.used > mark.high then
        mark.high = sample.used
    end
    if sample.pinsBuilt then
        mark.pinsBuilt = sample.pinsBuilt
    end
end

---@param label string
---@param sample ErrorCatcherMemorySample
local function Write(label, sample)
    local memory = ErrorCatcher.state.memory
    if memory.lines >= MAX_LINES then
        if memory.lines == MAX_LINES then
            memory.lines = memory.lines + 1
            Log.Line("%d memory lines written this UI load; further readings go to the record only", MAX_LINES)
        end
        Mark(label, sample)
        return
    end
    memory.lines = memory.lines + 1
    Log.Line("%s", MemoryUtils.Line(label, sample, memory.mark.used and memory.mark or nil))
    Mark(label, sample)
    SessionActions.RequestSave()
end

---Write a reading whatever it says.
---@param label string Why
function MemoryActions.Note(label)
    local sample = Read()
    if sample then
        Write(label, sample)
    end
end

---The reading now as a line, written nowhere.
---@param label string
---@return string|nil
function MemoryActions.Describe(label)
    local sample = Read()
    if not sample then
        return nil
    end
    local memory = ErrorCatcher.state.memory
    return MemoryUtils.Line(label, sample, memory.mark.used and memory.mark or nil)
end

local function Tick()
    local sample = Read()
    if not sample then
        return
    end
    local memory = ErrorCatcher.state.memory
    local reason = MemoryUtils.Reason(sample, memory.mark, memory.rangeFull)
    if reason then
        Write(reason, sample)
    end
end

---The game's low memory notice arrives as a Lua error without a trace.
---@param text any
---@return boolean taken The text was that notice
function MemoryActions.OnNotice(text)
    local used, capacity = MemoryUtils.ParseNotice(text)
    if not used then
        return false
    end
    local noticed = ErrorCatcher.state.memory.noticed
    if not noticed[used] then
        noticed[used] = true
        MemoryActions.Note(string.format("the game's low memory warning at %d/%d MB", used, capacity or 0))
    end
    return true
end

---At file scope, before anything else of this add-on runs: when this UI load began, and what was loaded
---before this add-on takes.
function MemoryActions.Begin()
    local memory = ErrorCatcher.state.memory
    memory.startClock = GameUtils.GameClock()
    memory.atFileScope = GameUtils.Pool()
    memory.heapAtFileScope = GameUtils.HeapMB()
end

---What each add-on loaded after this one added, as lines; once, when the world is entered.
local function WriteByAddon()
    local memory = ErrorCatcher.state.memory
    if #memory.byAddon == 0 then
        return
    end
    local names, restCount, restMB = MemoryUtils.ByAddon(memory.byAddon, MIN_ADDON_MB)
    local title = string.format("%s by add-on loaded after this one, MB (gained between the load event before and its own)",
        memory.byHeap and "Lua heap" or "add-on pool")
    for _, line in ipairs(ScanUtils.Pack(title, names, MAX_LINE_CHARS)) do
        Log.Line("%s", line)
    end
    if restCount > 0 then
        Log.Line("by add-on loaded after this one: %d more under %.1f MB each, %s%.1f MB together",
            restCount, MIN_ADDON_MB, restMB >= 0 and "+" or "", restMB)
    end
    local heap, pool = 0, 0
    for _, entry in ipairs(memory.byAddon) do
        heap, pool = heap + (entry.heap or 0), pool + entry.pool
    end
    Log.Line("over the %d add-ons loaded after this one: Lua heap %s%.1f MB, add-on pool figure %s%.1f MB",
        #memory.byAddon, heap >= 0 and "+" or "", heap, pool >= 0 and "+" or "", pool)
end

local function OnActivated()
    local memory = ErrorCatcher.state.memory
    if not memory.worldSeen then
        memory.worldSeen = true
        WriteByAddon()
        MemoryActions.Note("world entered")
    else
        MemoryActions.Note("zone change")
    end
end

---At this add-on's own load event: the pool so far, then a reading every few seconds.
function MemoryActions.Start()
    local memory = ErrorCatcher.state.memory
    local sample = Read()
    if not sample then
        Log.Line("memory: the game gives no add-on pool figure here; nothing is followed")
        return
    end
    Log.Line("memory at load: add-on pool %s/%s MB when this add-on's files ran, %.1f at its load event%s",
        memory.atFileScope and string.format("%.1f", memory.atFileScope) or "?",
        sample.capacity and string.format("%d", sample.capacity) or "?", sample.used,
        sample.heap and string.format("; Lua heap %s -> %.1f MB over the same (the game's own UI included)",
            memory.heapAtFileScope and string.format("%.1f", memory.heapAtFileScope) or "?", sample.heap) or "")
    Mark("load", sample)
    memory.loadPool, memory.loadHeap = sample.used, sample.heap
    memory.byHeap = memory.loadHeap ~= nil

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, SAMPLE_MS, GameUtils.Guard("Memory.Tick", Tick))
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, GameUtils.Guard("Memory.OnActivated", OnActivated))
end

---At the load event of an add-on after this one: what the Lua heap and the pool gained since the event before.
---@param addonName any
function MemoryActions.OnOtherLoaded(addonName)
    local memory = ErrorCatcher.state.memory
    local used, heap = GameUtils.Pool(), GameUtils.HeapMB()
    if not used or not memory.loadPool then
        return
    end
    local poolDelta = used - memory.loadPool
    local heapDelta = heap and memory.loadHeap and (heap - memory.loadHeap) or nil
    if #memory.byAddon < MAX_LOADED then
        memory.byAddon[#memory.byAddon + 1] = {
            name = tostring(addonName),
            delta = memory.byHeap and heapDelta or poolDelta,
            heap = heapDelta,
            pool = poolDelta,
        }
    end
    memory.loadPool, memory.loadHeap = used, heap
end

ErrorCatcher.MemoryActions = MemoryActions
