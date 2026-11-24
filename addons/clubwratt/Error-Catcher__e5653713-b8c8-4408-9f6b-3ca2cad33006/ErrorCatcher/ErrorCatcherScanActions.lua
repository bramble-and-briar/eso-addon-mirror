-- ErrorCatcherScanActions.lua: which game functions are untrusted right now
--
-- Once per UI load, a few seconds after the player is in the world: every global game function (ZO_ prefix)
-- and every function member of a game table (ZO_ classes, ALL_CAPS singletons) is asked of
-- IsTrustedFunction. An untrusted one was replaced or wrapped by an add-on. The globals are read in one
-- frame (reading them over several could miss a key added in between); the tables a slice per frame.
local ScanActions = {}

local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils
local ScanUtils = ErrorCatcher.ScanUtils

local UPDATE_NAME = ErrorCatcher.name .. "_Scan"
-- Table entries read per frame.
local ENTRIES_PER_STEP = 4000
local MAX_LINE_CHARS = 220
-- Lines of one listing; a longer one is cut with a count.
local MAX_LISTING_LINES = 60

---Read the globals: the untrusted game functions, and the game tables to read next.
---@param scan ErrorCatcherScan
local function ReadGlobals(scan)
    local tableNames = ErrorCatcher.state.tableNames
    for name, value in zo_insecurePairs(_G) do
        if type(name) == "string" then
            local valueType = type(value)
            if valueType == "function" then
                if ScanUtils.IsGameFunctionName(name) and GameUtils.IsTrusted(value) == false then
                    scan.functions[#scan.functions + 1] = name
                end
            elseif valueType == "table" and value ~= _G and ScanUtils.IsGameTableName(name) then
                if tableNames[value] == nil then
                    tableNames[value] = name
                    scan.tableNames[#scan.tableNames + 1] = name
                    scan.tables[#scan.tables + 1] = value
                end
            end
        end
    end
end

---Whether a table is an instance of a game class: the first function of the class it indexes is trusted.
---A singleton often has no function of its own, so one replaced on it would else pass for an add-on's table.
---@param instance table
---@return boolean
local function HasTrustedClass(instance)
    local metatable = getmetatable(instance)
    local class = type(metatable) == "table" and metatable.__index or nil
    if type(class) ~= "table" then
        return false
    end
    for _, value in zo_insecurePairs(class) do
        if type(value) == "function" then
            return GameUtils.IsTrusted(value) == true
        end
    end
    return false
end

---Read one table's function members.
---@param scan ErrorCatcherScan
---@param name string
---@param gameTable table
---@return number entries Entries read
local function ReadTable(scan, name, gameTable)
    local entries, trustedCount = 0, 0
    local untrusted = nil
    for key, value in zo_insecurePairs(gameTable) do
        entries = entries + 1
        if type(value) == "function" and type(key) == "string" then
            local trusted = GameUtils.IsTrusted(value)
            if trusted then
                trustedCount = trustedCount + 1
            elseif trusted == false then
                untrusted = untrusted or {}
                untrusted[#untrusted + 1] = key
            end
        end
    end
    if untrusted and (ScanUtils.IsGameTable(name, trustedCount) or HasTrustedClass(gameTable)) then
        for _, key in ipairs(untrusted) do
            scan.members[#scan.members + 1] = name .. "." .. key
        end
    end
    return entries
end

---@param lines string[]
local function WriteListing(lines)
    for index = 1, math.min(#lines, MAX_LISTING_LINES) do
        Log.Line("%s", lines[index])
    end
    if #lines > MAX_LISTING_LINES then
        Log.Line("(%d more lines not written)", #lines - MAX_LISTING_LINES)
    end
end

---Word the result, with the hooks seen while add-ons loaded; in full when it differs from the last UI load.
---@param scan ErrorCatcherScan
local function Finish(scan)
    local state = ErrorCatcher.state
    local functions = ScanUtils.SortedUnique(scan.functions)
    local members = ScanUtils.SortedUnique(scan.members)
    local byAddon, addons = ErrorCatcher.HookActions.Summarize()

    local lines = ScanUtils.Pack("untrusted game functions", functions, MAX_LINE_CHARS)
    for _, line in ipairs(ScanUtils.Pack("untrusted members of game tables", members, MAX_LINE_CHARS)) do
        lines[#lines + 1] = line
    end
    local hookCount = 0
    for _, addon in ipairs(addons) do
        local hooks = ScanUtils.SortedUnique(byAddon[addon])
        hookCount = hookCount + #hooks
        for _, line in ipairs(ScanUtils.Pack("hooks by " .. addon, hooks, MAX_LINE_CHARS)) do
            lines[#lines + 1] = line
        end
    end

    local totals = string.format("%d untrusted game functions, %d untrusted members of game tables, %d hooks by %d add-ons loaded after this one%s",
        #functions, #members, hookCount, #addons, scan.globalsRead and "" or " (the globals were not read to the end)")
    local digest = ScanUtils.Digest(lines)
    if digest == state.savedVars.lastScanDigest and not scan.force then
        Log.Line("scan: %s; the same as the last UI load (/ec scan lists them)", totals)
    else
        Log.Line("scan: %s", totals)
        WriteListing(lines)
        state.savedVars.lastScanDigest = digest
    end
    scan.running, scan.done = false, true
    scan.tables, scan.tableNames = {}, {}
end

---Read a slice of the tables; finish when none are left.
local function Step()
    local scan = ErrorCatcher.state.scan
    if not ErrorCatcher.state.trustApi then
        -- The globals were read for the tables' names, which word the hooks; their members cannot be judged.
        scan.next = #scan.tables + 1
    end
    local entries = 0
    while scan.next <= #scan.tables and entries < ENTRIES_PER_STEP do
        entries = entries + 1 + ReadTable(scan, scan.tableNames[scan.next], scan.tables[scan.next])
        scan.next = scan.next + 1
    end
    if scan.next > #scan.tables then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        Finish(scan)
    end
end

---Start a scan. The hooks summary rides on it, so it also runs when the game cannot be asked about trust.
---@param force boolean List everything even when nothing changed since the last UI load
---@return boolean started
function ScanActions.Start(force)
    local state = ErrorCatcher.state
    if state.scan.running then
        return false
    end
    local scan = ErrorCatcher.State.CreateScan()
    scan.running, scan.force = true, force == true
    state.scan = scan
    -- A table is read once per scan, under the first name met.
    state.tableNames = setmetatable({}, { __mode = "k" })
    -- The steps are registered first: should reading the globals be cut short by an error pcall cannot
    -- catch (a private function met on the way), the next frame still finishes with what was read.
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, function()
        local ok, err = pcall(Step)
        if not ok then
            -- A step that raises would raise again every frame.
            EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
            scan.running = false
            Log.Line("scan stopped: %s", tostring(err))
        end
    end)
    if type(zo_insecurePairs) == "function" then
        local ok, err = pcall(ReadGlobals, scan)
        if not ok then
            Log.Line("scan: reading the globals stopped: %s", tostring(err))
        end
        scan.globalsRead = ok
    end
    return true
end

ErrorCatcher.ScanActions = ScanActions
