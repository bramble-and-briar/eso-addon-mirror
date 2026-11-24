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
    }
end

---@return ErrorCatcherState
function State.Create()
    return {
        savedVars = {
            lastScanDigest = "",
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
        counters = {
            errors = 0,
            dialogs = 0,
            hooks = 0,
            untrustedButtons = 0,
        },
    }
end

ErrorCatcher.State = State
