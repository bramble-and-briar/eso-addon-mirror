-- MatchMonitorDiag v0.1.5
-- Diagnostic add-on (Phase 2). Purpose: find out what the Activity Finder / LFG
-- related API exposes on PS5 / Console, and whether any information about OTHER
-- players' queue state (names, target dungeon, waiting counts) is reachable.
--
-- Rules followed here:
--  * No OnUpdate, no polling. Logging happens only on events, on state change,
--    and on explicit /mmd commands (plus one start-up probe per session).
--  * Nothing is written to chat. Output goes to the in-game log window and to
--    the SavedVariables file (MatchMonitorDiag_SV.log).
--  * Nothing is guessed: every API is existence-checked with rawget + pcall and
--    every return value is logged with its Lua type.
--  * No attempt is made to bypass any game/server restriction.
--
-- STATUS: written without access to a PS5. Nothing in this file has been run on
-- real hardware yet (UNVERIFIED).

MatchMonitorDiag = MatchMonitorDiag or {}
local MMD = MatchMonitorDiag
MMD.name = "MatchMonitorDiag"
MMD.version = "0.1.5"

------------------------------------------------------------------------------
-- Settings / constants
------------------------------------------------------------------------------
local MAX_LINES      = 700   -- ring buffer size (also what is saved)
local LINE_MAX_LEN   = 300   -- stored line length limit
local DISPLAY_LEN    = 150   -- displayed line length limit
local PAGE_SIZE      = 16    -- lines shown in the window
local EVENT_LOG_CAP  = 25    -- per event name; further occurrences are only counted
local CALL_LOG_CAP   = 90    -- cap for the generic getter scan output
local MGR_CALL_CAP   = 40

local SCENARIOS = {
    none = "NONE",
    bg   = "BG",
    rn   = "RANDOM_NORMAL",
    rv   = "RANDOM_VET",
    dn   = "DUNGEON_NORMAL",
    dv   = "DUNGEON_VET",
}

-- Functions the specification asks about + closely related ones. Existence is
-- checked, never assumed.
local KNOWN_FUNCS = {
    "GetActivityFinderStatus",
    "GetLFGSearchTimes",
    "GetNumLFGRequests",
    "GetLFGRequestInfo",
    "GetNumActivityRequests",
    "GetActivityRequestIds",
    "GetCurrentLFGActivityId",
    "GetSelectedLFGRole",
    "GetActivityInfo",
    "GetActivityType",
    "GetActivityGroupType",
    "GetLFGCooldownTimeRemaining",
    "GetLFGReadyCheckNotificationInfo",
    "GetLFGFindReplacementNotificationInfo",
    "GetGroupSize",
    "GetAPIVersion",
}

local KNOWN_EVENTS = {
    "EVENT_ACTIVITY_FINDER_STATUS_UPDATE",
    "EVENT_ACTIVITY_QUEUE_RESULT",
    "EVENT_ACTIVITY_FINDER_COOLDOWNS_UPDATE",
    "EVENT_GROUP_UPDATE",
    "EVENT_GROUP_MEMBER_JOINED",
    "EVENT_GROUP_MEMBER_LEFT",
}

-- Events whose global name contains one of these are logged generically.
local EVENT_PATTERNS = { "ACTIVITY", "LFG", "BATTLEGROUND", "MATCHMAK", "QUEUE", "READY_CHECK" }
-- Extra explicit events (group formation). Only registered if they exist.
local EVENT_EXTRA = {
    "EVENT_GROUP_UPDATE",
    "EVENT_GROUP_MEMBER_JOINED",
    "EVENT_GROUP_MEMBER_LEFT",
    "EVENT_GROUP_MEMBER_ROLE_CHANGED",
}
-- Events that trigger a (debounced, change-only) snapshot.
local TRIGGER_PATTERNS = {
    "ACTIVITY_FINDER_STATUS", "ACTIVITY_QUEUE", "ACTIVITY_FINDER_COOLDOWNS",
    "LFG", "READY_CHECK",
}

-- Explicit constant names for readable status/type labels. Used even when the
-- global scan fails (v0.1.3 PS5 screenshot: scan failed, labels showed "?").
-- Each name is existence-checked with rawget; nothing is assumed.
local STATUS_CONST_NAMES = {
    "ACTIVITY_FINDER_STATUS_NONE", "ACTIVITY_FINDER_STATUS_QUEUED",
    "ACTIVITY_FINDER_STATUS_READY_CHECK", "ACTIVITY_FINDER_STATUS_COMPLETE",
    "ACTIVITY_FINDER_STATUS_FORMING_GROUP", "ACTIVITY_FINDER_STATUS_IN_PROGRESS",
}
local TYPE_CONST_NAMES = {
    "LFG_ACTIVITY_DUNGEON", "LFG_ACTIVITY_MASTER_DUNGEON", "LFG_ACTIVITY_AVA",
    "LFG_ACTIVITY_BATTLE_GROUND_CHAMPION", "LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION",
    "LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL", "LFG_ACTIVITY_HOME_SHOW",
    "LFG_ACTIVITY_TRIBUTE_COMPETITIVE", "LFG_ACTIVITY_TRIBUTE_CASUAL",
}

-- Global function name patterns for the discovery scan.
local FN_PATTERNS = { "Activity", "LFG", "Battleground", "BattleGround", "Queue", "Matchmak", "GroupFinder", "ReadyCheck" }
-- Names containing these are flagged with * as "might expose other players / queue-wide data".
local STAR_PATTERNS = { "Wait", "Queue", "Population", "Applicant", "Player", "Estimated", "Average", "Search", "Others", "Request", "Member" }

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------
local sv
local buf = {}
local scenario = "NONE"
local viewOffset = 0
local snapPending = false
local refreshPending = false
local lastSnapSig = nil
local statusNames = {}
local activityTypeNames = {}
local eventCounts = {}
local registeredEvents = {}
local ui = {}
local booted = false
local lastIds = {}
local refreshUI -- forward declaration

MMD.statusText = "status=?"

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------
local function fmtTime()
    local ms = 0
    if GetGameTimeMilliseconds then ms = GetGameTimeMilliseconds() end
    return string.format("%d.%03d", math.floor(ms / 1000), ms % 1000)
end

local function requestRefresh()
    if refreshPending then return end
    refreshPending = true
    zo_callLater(function()
        refreshPending = false
        if refreshUI then refreshUI() end
    end, 100)
end

local function log(msg)
    msg = tostring(msg)
    if #msg > LINE_MAX_LEN then msg = string.sub(msg, 1, LINE_MAX_LEN) .. "~" end
    buf[#buf + 1] = string.format("[%s][%s] %s", fmtTime(), scenario, msg)
    if #buf > MAX_LINES then table.remove(buf, 1) end
    requestRefresh()
end

local function fmtVal(v, mask)
    local t = type(v)
    if t == "string" then
        if mask then return string.format("string(len=%d)", #v) end
        local s = v
        if #s > 60 then s = string.sub(s, 1, 60) .. "~" end
        return "string:\"" .. s .. "\""
    elseif t == "number" or t == "boolean" then
        return t .. ":" .. tostring(v)
    elseif t == "nil" then
        return "nil"
    elseif t == "table" then
        local c = 0
        for _ in pairs(v) do
            c = c + 1
            if c >= 200 then break end
        end
        return "table(n=" .. c .. ")"
    end
    return t
end

local function fmtList(mask, ...)
    local n = select('#', ...)
    local args = { ... }
    local out = {}
    local shown = math.min(n, 12)
    for i = 1, shown do
        out[#out + 1] = fmtVal(args[i], mask)
    end
    if n > shown then out[#out + 1] = "...(+" .. (n - shown) .. ")" end
    return n, table.concat(out, ", ")
end

-- pcall wrapper that returns ok, count, packedTable
local function pack2(ok, ...)
    return ok, select('#', ...), { ... }
end

local function safeCall(f, ...)
    return pack2(pcall(f, ...))
end

local function hasAny(name, pats)
    for _, p in ipairs(pats) do
        if string.find(name, p, 1, true) then return true end
    end
    return false
end

local function addName(map, value, name)
    if map[value] then
        if string.find("|" .. map[value] .. "|", "|" .. name .. "|", 1, true) then return end
        map[value] = map[value] .. "|" .. name
    else
        map[value] = name
    end
end

local function nameOf(map, value)
    if type(value) ~= "number" then return "?" end
    return map[value] or "?"
end

local function logChunks(prefix, items, maxLen)
    local line = prefix
    for _, it in ipairs(items) do
        if #line + #it + 1 > maxLen and line ~= prefix then
            log(line)
            line = prefix
        end
        line = line .. " " .. it
    end
    if line ~= prefix then log(line) end
end

-- Iterate the global table. v0.1.3 on PS5: plain pairs(_G) failed part-way, so
-- fall back to zo_insecurePairs if it exists. visit() must be idempotent because
-- a second pass may repeat entries seen before a failure.
-- Returns: method ("pairs" / "zo_insecurePairs" / nil) and the first error text.
local function scanGlobals(visit)
    local ok, err = pcall(function()
        for k, v in pairs(_G) do visit(k, v) end
    end)
    if ok then return "pairs", nil end
    local firstErr = string.sub(tostring(err), 1, 100)
    local ip = rawget(_G, "zo_insecurePairs")
    if type(ip) == "function" then
        local ok2 = pcall(function()
            for k, v in ip(_G) do visit(k, v) end
        end)
        if ok2 then return "zo_insecurePairs", firstErr end
    end
    return nil, firstErr
end

local function buildConstMaps()
    -- 1) explicit names (works even if the scan fails)
    for _, name in ipairs(STATUS_CONST_NAMES) do
        local v = rawget(_G, name)
        if type(v) == "number" then addName(statusNames, v, name) end
    end
    for _, name in ipairs(TYPE_CONST_NAMES) do
        local v = rawget(_G, name)
        if type(v) == "number" then addName(activityTypeNames, v, name) end
    end
    -- 2) scan for any additional matching constants
    local method, err = scanGlobals(function(k, v)
        if type(k) == "string" and type(v) == "number" then
            if string.find(k, "^ACTIVITY_FINDER_STATUS_") then
                addName(statusNames, v, k)
            elseif string.find(k, "^LFG_ACTIVITY_") then
                addName(activityTypeNames, v, k)
            end
        end
    end)
    if not method then
        log("WARN: constant scan failed: " .. tostring(err))
    elseif err then
        log("NOTE: pairs(_G) failed (" .. tostring(err) .. "); constant scan used " .. method)
    end
end

------------------------------------------------------------------------------
-- Snapshot (own Activity Finder state). Logs only when something changed.
------------------------------------------------------------------------------
local function takeSnapshot(reason, force)
    local parts = {}
    local lines = {}

    local fStatus = rawget(_G, "GetActivityFinderStatus")
    if type(fStatus) == "function" then
        local ok, n, r = safeCall(fStatus)
        if ok and n > 0 then
            local stTxt = "status=" .. fmtVal(r[1], not sv.showNames) .. "(" .. nameOf(statusNames, r[1]) .. ")"
            parts[#parts + 1] = stTxt
            MMD.statusText = stTxt
        else
            parts[#parts + 1] = "status=ERR_OR_NONE"
        end
    else
        parts[#parts + 1] = "status=API_MISSING"
    end

    local ids = {}
    local seen = {}
    local function addId(v)
        if type(v) == "number" and not seen[v] then
            seen[v] = true
            ids[#ids + 1] = v
        end
    end

    local fNum = rawget(_G, "GetNumActivityRequests")
    local numReq = nil
    if type(fNum) == "function" then
        local ok, n, r = safeCall(fNum)
        if ok and n > 0 then
            numReq = r[1]
            parts[#parts + 1] = "numReq=" .. fmtVal(r[1], not sv.showNames)
        else
            parts[#parts + 1] = "numReq=ERR"
        end
    else
        parts[#parts + 1] = "numReq=API_MISSING"
    end

    local fIds = rawget(_G, "GetActivityRequestIds")
    if type(fIds) == "function" then
        -- Form A: no argument
        local okA, nA, rA = safeCall(fIds)
        if okA then
            local _, sA = fmtList(not sv.showNames, unpack(rA, 1, nA))
            parts[#parts + 1] = "idsNoArg(" .. nA .. ")=[" .. sA .. "]"
            for i = 1, nA do addId(rA[i]) end
        else
            parts[#parts + 1] = "idsNoArg=ERR"
        end
        -- Form B: index argument
        if type(numReq) == "number" and numReq > 0 then
            for i = 1, math.min(numReq, 8) do
                local okB, nB, rB = safeCall(fIds, i)
                if okB then
                    local _, sB = fmtList(not sv.showNames, unpack(rB, 1, nB))
                    parts[#parts + 1] = "ids[" .. i .. "](" .. nB .. ")=[" .. sB .. "]"
                    for j = 1, nB do addId(rB[j]) end
                else
                    parts[#parts + 1] = "ids[" .. i .. "]=ERR"
                end
            end
        end
    else
        parts[#parts + 1] = "idsFn=API_MISSING"
    end

    local fCur = rawget(_G, "GetCurrentLFGActivityId")
    if type(fCur) == "function" then
        local ok, n, r = safeCall(fCur)
        if ok and n > 0 then
            parts[#parts + 1] = "curActivity=" .. fmtVal(r[1], not sv.showNames)
            addId(r[1])
        end
    end

    local fRole = rawget(_G, "GetSelectedLFGRole")
    if type(fRole) == "function" then
        local ok, n, r = safeCall(fRole)
        if ok and n > 0 then parts[#parts + 1] = "role=" .. fmtVal(r[1], not sv.showNames) end
    end

    local fGrp = rawget(_G, "GetGroupSize")
    if type(fGrp) == "function" then
        local ok, n, r = safeCall(fGrp)
        if ok and n > 0 then parts[#parts + 1] = "groupSize=" .. fmtVal(r[1], not sv.showNames) end
    end

    lastIds = ids

    for _, id in ipairs(ids) do
        local seg = {}
        local infoSeg = nil
        local fInfo = rawget(_G, "GetActivityInfo")
        if type(fInfo) == "function" then
            local ok, n, r = safeCall(fInfo, id)
            if ok then
                local _, s = fmtList(not sv.showNames, unpack(r, 1, n))
                infoSeg = "info(" .. n .. ")=[" .. s .. "]"
            else
                infoSeg = "info=ERR"
            end
        end
        local fType = rawget(_G, "GetActivityType")
        if type(fType) == "function" then
            local ok, n, r = safeCall(fType, id)
            if ok and n > 0 then
                seg[#seg + 1] = "type=" .. fmtVal(r[1], not sv.showNames) .. "(" .. nameOf(activityTypeNames, r[1]) .. ")"
            else
                seg[#seg + 1] = "type=ERR"
            end
        end
        local fGT = rawget(_G, "GetActivityGroupType")
        if type(fGT) == "function" then
            local ok, n, r = safeCall(fGT, id)
            if ok and n > 0 then seg[#seg + 1] = "groupType=" .. fmtVal(r[1], not sv.showNames) else seg[#seg + 1] = "groupType=ERR" end
        end
        -- type/groupType first, the long info(...) last, so the window's width
        -- limit cuts info() and not type (v0.1.4 screenshot cut off type=).
        if infoSeg then seg[#seg + 1] = infoSeg end
        lines[#lines + 1] = "  id " .. id .. ": " .. table.concat(seg, " ")
    end

    local sig = table.concat(parts, ";") .. "|" .. table.concat(lines, "|")
    if (not force) and sig == lastSnapSig then return end
    lastSnapSig = sig

    log("SNAP[" .. tostring(reason) .. "] " .. table.concat(parts, " "))
    for _, l in ipairs(lines) do log(l) end
end

local function scheduleSnapshot(reason)
    if snapPending then return end
    snapPending = true
    zo_callLater(function()
        snapPending = false
        takeSnapshot(reason, false)
    end, 250)
end

------------------------------------------------------------------------------
-- Generic event logging (event name, arg count, arg values with types)
------------------------------------------------------------------------------
local function onGenericEvent(eventName, ...)
    local c = (eventCounts[eventName] or 0) + 1
    eventCounts[eventName] = c
    if c <= EVENT_LOG_CAP then
        local n, s = fmtList(not sv.showNames, ...)
        log(string.format("EVT %s #%d n=%d args=[%s]", eventName, c, n, s))
    elseif c == EVENT_LOG_CAP + 1 then
        log("EVT " .. eventName .. " cap reached; further occurrences counted only")
    end
    if hasAny(eventName, TRIGGER_PATTERNS) then
        scheduleSnapshot("evt:" .. eventName)
    end
end

local function registerEvents()
    local names = {}
    local picked = {}
    -- Explicit events first: these must be registered even when the global scan
    -- fails (v0.1.3 on PS5 registered only 4 events because the scan failed).
    for _, k in ipairs(KNOWN_EVENTS) do
        local v = rawget(_G, k)
        if type(v) == "number" then picked[k] = v end
    end
    for _, k in ipairs(EVENT_EXTRA) do
        local v = rawget(_G, k)
        if type(v) == "number" then picked[k] = v end
    end
    local method, err = scanGlobals(function(k, v)
        if type(k) == "string" and type(v) == "number" and string.sub(k, 1, 6) == "EVENT_" then
            if hasAny(k, EVENT_PATTERNS) then
                picked[k] = v
            end
        end
    end)
    if not method then
        log("WARN: event scan failed: " .. tostring(err) .. " (explicit events only)")
    elseif err then
        log("NOTE: pairs(_G) failed (" .. tostring(err) .. "); event scan used " .. method)
    end
    for k, v in pairs(picked) do
        names[#names + 1] = k
        EVENT_MANAGER:RegisterForEvent(MMD.name .. "_" .. k, v, function(code, ...)
            onGenericEvent(k, code, ...)
        end)
        registeredEvents[k] = v
    end
    table.sort(names)
    MMD.registeredCount = #names
    log("Registered " .. #names .. " events for generic logging (cap " .. EVENT_LOG_CAP .. " lines each)")
    local short = {}
    for _, n in ipairs(names) do short[#short + 1] = (string.gsub(n, "^EVENT_", "")) end
    logChunks("EVTNAMES:", short, 120)
    if sv then
        sv.probe = sv.probe or {}
        sv.probe.registeredEvents = names
    end
end

------------------------------------------------------------------------------
-- Probe (existence / discovery). Runs in small steps to avoid a frame hitch.
------------------------------------------------------------------------------
local function probeExistence()
    log("PROBE 1/4 existence check (rawget + type)")
    local found, total = 0, 0
    for _, name in ipairs(KNOWN_FUNCS) do
        total = total + 1
        local v = rawget(_G, name)
        local res
        if type(v) == "function" then
            res = "EXISTS(function)"
            found = found + 1
        elseif v == nil then
            res = "MISSING"
        else
            res = "OTHER:" .. type(v)
        end
        log("  FN " .. name .. " : " .. res)
    end
    for _, name in ipairs(KNOWN_EVENTS) do
        total = total + 1
        local v = rawget(_G, name)
        local res
        if type(v) == "number" then
            res = "EXISTS(number)"
            found = found + 1
        elseif v == nil then
            res = "MISSING"
        else
            res = "OTHER:" .. type(v)
        end
        log("  EV " .. name .. " : " .. res)
    end
    local mgr = rawget(_G, "ACTIVITY_FINDER_ROOT_MANAGER")
    log("  OBJ ACTIVITY_FINDER_ROOT_MANAGER : " .. type(mgr))
    local cls = rawget(_G, "ZO_ActivityFinderRoot_Manager")
    log("  OBJ ZO_ActivityFinderRoot_Manager : " .. type(cls))
    MMD.existSummary = found .. "/" .. total
end

local function probeFunctionScan()
    log("PROBE 2/4 discovery scan of global functions")
    local names = {}
    local set = {}
    local starCount = 0
    local method, err = scanGlobals(function(k, v)
        if type(k) == "string" and type(v) == "function" and hasAny(k, FN_PATTERNS) then
            set[k] = true
        end
    end)
    for k in pairs(set) do names[#names + 1] = k end
    if not method then
        log("WARN: function scan failed: " .. tostring(err) .. " (list may be partial)")
    elseif err then
        log("NOTE: pairs(_G) failed (" .. tostring(err) .. "); function scan used " .. method)
    end
    table.sort(names)
    MMD.fnNames = names
    local shown = {}
    for _, n in ipairs(names) do
        if hasAny(n, STAR_PATTERNS) then
            shown[#shown + 1] = "*" .. n
            starCount = starCount + 1
        else
            shown[#shown + 1] = n
        end
    end
    MMD.fnCount = #names
    MMD.starCount = starCount
    log("  matched " .. #names .. " functions (scan=" .. tostring(method) .. "); * = name suggests queue/other-player data (" .. starCount .. ")")
    logChunks("FN:", shown, 120)
    if sv then
        sv.probe = sv.probe or {}
        sv.probe.functions = names
    end
end

local function probeGetterCalls()
    log("PROBE 3/4 calling matched zero-arg getters (Get/Is/Has/Can/Does only)")
    local names = MMD.fnNames or {}
    local logged, errors, empty = 0, 0, 0
    local mask = not sv.showNames
    local firstId = lastIds[1]
    for _, name in ipairs(names) do
        if string.find(name, "^Get") or string.find(name, "^Is") or string.find(name, "^Has")
           or string.find(name, "^Can") or string.find(name, "^Does") then
            local f = rawget(_G, name)
            if type(f) == "function" then
                local ok, n, r = safeCall(f)
                local usedArg = ""
                if (not ok) and firstId then
                    ok, n, r = safeCall(f, firstId)
                    usedArg = "(id)"
                end
                if ok and n > 0 then
                    if logged < CALL_LOG_CAP then
                        local _, s = fmtList(mask, unpack(r, 1, n))
                        local star = hasAny(name, STAR_PATTERNS) and "*" or ""
                        log("  " .. star .. name .. usedArg .. " -> " .. n .. ": " .. s)
                    end
                    logged = logged + 1
                elseif ok then
                    empty = empty + 1
                else
                    errors = errors + 1
                end
            end
        end
    end
    log(string.format("  getter scan: returned values=%d (log cap %d), no-return=%d, errored/needs-args=%d", logged, CALL_LOG_CAP, empty, errors))
    MMD.getterSummary = logged .. " returned / " .. errors .. " need args"
end

local function collectMethods(obj)
    local names, seen = {}, {}
    local c = getmetatable(obj)
    local depth = 0
    while type(c) == "table" and depth < 5 do
        local idx = c.__index
        if type(idx) ~= "table" then break end
        for k, v in pairs(idx) do
            if type(v) == "function" and type(k) == "string" and not seen[k] then
                seen[k] = true
                names[#names + 1] = k
            end
        end
        c = getmetatable(idx)
        depth = depth + 1
    end
    table.sort(names)
    return names
end

local function probeManager()
    log("PROBE 4/4 ACTIVITY_FINDER_ROOT_MANAGER inspection")
    local m = rawget(_G, "ACTIVITY_FINDER_ROOT_MANAGER")
    if type(m) ~= "table" then
        log("  ACTIVITY_FINDER_ROOT_MANAGER is not a table (" .. type(m) .. "); skipped")
        return
    end
    local fields = {}
    for k, v in pairs(m) do
        local t = type(v)
        if t == "table" then
            local c = 0
            for _ in pairs(v) do
                c = c + 1
                if c >= 500 then break end
            end
            t = "table(n=" .. c .. ")"
        end
        fields[#fields + 1] = tostring(k) .. ":" .. t
    end
    table.sort(fields)
    log("  manager fields: " .. #fields)
    logChunks("MGRF:", fields, 120)

    local okM, methods = pcall(collectMethods, m)
    if not okM then
        log("  could not enumerate methods")
        return
    end
    log("  manager methods: " .. #methods)
    logChunks("MGRM:", methods, 120)
    if sv then
        sv.probe = sv.probe or {}
        sv.probe.managerFields = fields
        sv.probe.managerMethods = methods
    end

    local KW = { "Request", "Queue", "Status", "Role", "Search", "Locked", "Cooldown", "Num", "Count", "Applicant", "Wait", "Player", "Member" }
    local mask = not sv.showNames
    local called, errs = 0, 0
    for _, name in ipairs(methods) do
        if (string.find(name, "^Get") or string.find(name, "^Is") or string.find(name, "^Has")
            or string.find(name, "^Can") or string.find(name, "^Does")) and hasAny(name, KW) then
            if called < MGR_CALL_CAP then
                local f = m[name]
                if type(f) == "function" then
                    local ok, n, r = safeCall(f, m)
                    if ok and n > 0 then
                        local _, s = fmtList(mask, unpack(r, 1, n))
                        log("  mgr:" .. name .. "() -> " .. n .. ": " .. s)
                        called = called + 1
                    elseif not ok then
                        errs = errs + 1
                    end
                end
            end
        end
    end
    log("  manager zero-arg calls logged=" .. called .. " errored/needs-args=" .. errs)
end

local function probeSummary()
    log("PROBE DONE. exist=" .. tostring(MMD.existSummary) .. " fnMatched=" .. tostring(MMD.fnCount)
        .. " star=" .. tostring(MMD.starCount) .. " events=" .. tostring(MMD.registeredCount)
        .. " getters=" .. tostring(MMD.getterSummary))
    log("NEXT: queue up per scenario (/mmd s bg|rn|rv|dn|dv) and watch EVT/SNAP lines. See README.")
    takeSnapshot("probe", true)
end

local function runProbe()
    probeExistence()
    zo_callLater(function()
        probeFunctionScan()
        zo_callLater(function()
            probeGetterCalls()
            zo_callLater(function()
                probeManager()
                zo_callLater(probeSummary, 150)
            end, 150)
        end, 150)
    end, 150)
end

------------------------------------------------------------------------------
-- UI (simple log window, no per-frame updates)
------------------------------------------------------------------------------
local function buildUI()
    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow("MatchMonitorDiagWindow")
    win:SetDimensions(960, 380)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 40, 80)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetHidden(false)

    local bg = wm:CreateControl("MatchMonitorDiagBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, 0.7)
    bg:SetEdgeColor(0, 0, 0, 0)

    local head = wm:CreateControl("MatchMonitorDiagHead", win, CT_LABEL)
    head:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 8)
    head:SetDimensions(936, 28)
    head:SetColor(1, 0.85, 0.3, 1)

    local body = wm:CreateControl("MatchMonitorDiagBody", win, CT_LABEL)
    body:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 40)
    body:SetDimensions(936, 330)
    body:SetColor(1, 1, 1, 1)

    -- Fonts: try gamepad font first, then fall back. Missing fonts must not break loading.
    local fonts = { "ZoFontGamepad18", "ZoFontGame" }
    for _, fnt in ipairs(fonts) do
        local ok = pcall(function()
            head:SetFont(fnt)
            body:SetFont(fnt)
        end)
        if ok then break end
    end

    ui.win, ui.head, ui.body = win, head, body
end

refreshUI = function()
    if not ui.win or ui.win:IsHidden() then return end
    local total = #buf
    local maxOffset = math.max(0, total - PAGE_SIZE)
    if viewOffset > maxOffset then viewOffset = maxOffset end
    if viewOffset < 0 then viewOffset = 0 end
    local last = total - viewOffset
    local first = math.max(1, last - PAGE_SIZE + 1)
    local lines = {}
    for i = first, last do
        lines[#lines + 1] = string.sub(buf[i], 1, DISPLAY_LEN)
    end
    ui.body:SetText(table.concat(lines, "\n"))
    ui.head:SetText(string.format("MatchMonitorDiag v%s  scn=%s  %s  [%d-%d/%d]",
        MMD.version, scenario, MMD.statusText, first, last, total))
end

------------------------------------------------------------------------------
-- Slash command  /mmd ...   (output goes to the log window, not to chat)
------------------------------------------------------------------------------
local function showHelp()
    log("HELP /mmd show|hide  s <bg|rn|rv|dn|dv|none> [text]  note <text>")
    log("HELP /mmd snap  probe  names on|off  auto on|off  up|down|bottom  clear")
end

local function onSlash(text)
    text = text or ""
    local cmd, rest = string.match(text, "^%s*(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")
    rest = rest or ""

    if cmd == "" or cmd == "help" then
        showHelp()
    elseif cmd == "show" then
        if ui.win then ui.win:SetHidden(false) end
        requestRefresh()
    elseif cmd == "hide" then
        if ui.win then ui.win:SetHidden(true) end
    elseif cmd == "s" then
        local code, extra = string.match(rest, "^(%S*)%s*(.*)$")
        code = string.lower(code or "")
        local label = SCENARIOS[code]
        if not label then
            log("scenario unknown: use bg rn rv dn dv none")
        else
            if extra and extra ~= "" then label = label .. ":" .. string.sub(extra, 1, 30) end
            scenario = label
            log("SCENARIO set -> " .. label)
            takeSnapshot("scenario", true)
        end
    elseif cmd == "note" then
        log("NOTE " .. string.sub(rest, 1, 120))
    elseif cmd == "snap" then
        takeSnapshot("manual", true)
    elseif cmd == "probe" then
        runProbe()
    elseif cmd == "names" then
        local v = string.lower(rest)
        if v == "on" then
            sv.showNames = true
            log("names ON: string args/returns of events and probes are logged in clear text (local only)")
        else
            sv.showNames = false
            log("names OFF: strings are logged as string(len=N)")
        end
    elseif cmd == "auto" then
        sv.autoProbe = (string.lower(rest) ~= "off")
        log("autoProbe at start-up = " .. tostring(sv.autoProbe))
    elseif cmd == "up" then
        viewOffset = viewOffset + PAGE_SIZE
        requestRefresh()
    elseif cmd == "down" then
        viewOffset = math.max(0, viewOffset - PAGE_SIZE)
        requestRefresh()
    elseif cmd == "bottom" then
        viewOffset = 0
        requestRefresh()
    elseif cmd == "clear" then
        for i = #buf, 1, -1 do buf[i] = nil end
        lastSnapSig = nil
        viewOffset = 0
        log("log cleared")
    else
        showHelp()
    end
end

------------------------------------------------------------------------------
-- Initialisation
------------------------------------------------------------------------------
local function onPlayerActivated()
    if booted then return end
    booted = true
    local apiv = "?"
    if type(rawget(_G, "GetAPIVersion")) == "function" then
        local ok, v = pcall(GetAPIVersion)
        if ok then apiv = fmtVal(v, not sv.showNames) end
    end
    local ts = "?"
    if type(rawget(_G, "GetTimeStamp")) == "function" then
        local ok, v = pcall(GetTimeStamp)
        if ok then ts = fmtVal(v, not sv.showNames) end
    end
    log("SESSION START v" .. MMD.version .. " APIVersion=" .. apiv .. " ts=" .. ts .. " (UNVERIFIED on PS5 until confirmed)")
    log("names=" .. (sv.showNames and "ON" or "OFF") .. " autoProbe=" .. tostring(sv.autoProbe))
    takeSnapshot("boot", true)
    if sv.autoProbe then
        zo_callLater(runProbe, 1500)
    end
end

local function onAddOnLoaded(_, addonName)
    if addonName ~= MMD.name then return end
    EVENT_MANAGER:UnregisterForEvent(MMD.name, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("MatchMonitorDiag_SV", 1, nil, { showNames = false, autoProbe = true })
    if type(sv.log) ~= "table" then sv.log = {} end
    buf = sv.log

    buildConstMaps()
    local okUI, err = pcall(buildUI)
    if not okUI then
        log("WARN: UI creation failed (" .. tostring(err) .. "); logging to SavedVariables only")
    end
    registerEvents()

    if SLASH_COMMANDS then SLASH_COMMANDS["/mmd"] = onSlash end
    EVENT_MANAGER:RegisterForEvent(MMD.name .. "_Activated", EVENT_PLAYER_ACTIVATED, onPlayerActivated)
    requestRefresh()
end

EVENT_MANAGER:RegisterForEvent(MMD.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)
