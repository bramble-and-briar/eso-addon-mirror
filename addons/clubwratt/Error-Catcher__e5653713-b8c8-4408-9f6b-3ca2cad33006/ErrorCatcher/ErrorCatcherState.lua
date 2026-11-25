-- ErrorCatcherState.lua: Pure data initialization
local State = {}

---@return ErrorCatcherScan
function State.CreateScan()
    return {
        running = false,
        done = false,
        force = false,
        globalsRead = false,
        functions = {},
        members = {},
        tableNames = {},
        tables = {},
        next = 1,
        ownMB = 0,
    }
end

---@return ErrorCatcherState
function State.Create()
    return {
        savedVars = {
            scanDigests = {},
            watchNames = {},
        },
        trustApi = false,
        checkedCallbacks = setmetatable({}, { __mode = "k" }),
        poolConfirmed = false,
        loggedKeys = {},
        loggedCount = 0,
        hooks = {},
        hooksSummarized = false,
        tableNames = setmetatable({}, { __mode = "k" }),
        scan = State.CreateScan(),
        load = {
            after = {},
            previous = nil,
            enabled = nil,
            pending = {},
            watched = {},
            following = false,
            groups = {},
            listNumber = {},
            early = {},
            previousOrder = nil,
        },
        memory = {
            startClock = 0,
            atFileScope = nil,
            heapAtFileScope = nil,
            loadPool = nil,
            loadHeap = nil,
            byHeap = false,
            byAddon = {},
            worldSeen = false,
            sample = {},
            ring = { values = {}, next = 1 },
            rangeFull = false,
            mark = { high = 0, used = nil, age = 0, pinsBuilt = 0 },
            lines = 0,
            noticed = {},
        },
        session = {
            record = nil,
            saveAskedAt = nil,
            saveCallFailed = false,
            saveStartedAt = nil,
            slowSaves = 0,
            saveErrors = 0,
            forceDisabled = "",
        },
        wrappedBeforeLoad = {},
        hookersByFn = {},
        lastDialogShow = nil,
        counters = {
            errors = 0,
            dialogs = 0,
            hooks = 0,
            untrustedButtons = 0,
        },
    }
end

ErrorCatcher.State = State
