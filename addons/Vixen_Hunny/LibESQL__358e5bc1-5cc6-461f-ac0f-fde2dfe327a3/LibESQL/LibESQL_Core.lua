-- LibESQL core: namespace, printing, safe calls, callbacks, cooperative jobs.
--
-- Long work (ability-id scans, big queries) runs inside coroutines. Code calls
-- LibESQL.Tick() in its loops; when the per-frame budget is used up the coroutine
-- yields and resumes on the next frame, so the game never hitches.
-- Never call Tick() inside pcall, a metamethod or a table.sort comparator:
-- Lua 5.1 cannot yield across those boundaries.

LibESQL = LibESQL or {}
local E = LibESQL

E.name = "LibESQL"
E.version = "1.0.0"
E.versionNumber = 10000
E.isConsole = type(IsConsoleUI) == "function" and IsConsoleUI() or false

-- Operations per frame before a job yields. Console gets a smaller slice.
E.budget = E.isConsole and 700 or 3000

local insert, concat = table.insert, table.concat
local format, gsub = string.format, string.gsub

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
local PREFIX = "|c4FC3F7[ESQL]|r "

function E.Print(fmt, ...)
    local msg = select("#", ...) > 0 and format(fmt, ...) or tostring(fmt)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(PREFIX .. msg)
    elseif d then
        d(PREFIX .. msg)
    else
        print("[ESQL] " .. msg)
    end
end

function E.Debug(fmt, ...)
    if E.sv and E.sv.debug then E.Print("|c888888" .. format(fmt, ...) .. "|r") end
end

---------------------------------------------------------------------------
-- Callbacks: ScanProgress(tableName, fraction, idsFound), ScanDone(tableName, count),
-- Loaded(), UserTableCreated(name), UserTableDropped(name)
---------------------------------------------------------------------------
local callbacks = {}

function E.RegisterCallback(event, fn)
    local list = callbacks[event]
    if not list then list = {}; callbacks[event] = list end
    for _, f in ipairs(list) do if f == fn then return end end
    list[#list + 1] = fn
end

function E.UnregisterCallback(event, fn)
    local list = callbacks[event]
    if not list then return end
    for i = #list, 1, -1 do if list[i] == fn then table.remove(list, i) end end
end

function E.FireCallbacks(event, ...)
    local list = callbacks[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then E.Print("|cFF5555callback %s failed:|r %s", event, tostring(err)) end
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Game names carry grammar suffixes ("Fire Rune^n", "Bal^M"). Strip them.
function E.CleanName(s)
    if type(s) ~= "string" then return s end
    local caret = s:find("^", 1, true)
    if caret then s = s:sub(1, caret - 1) end
    return s
end

-- Strip colour codes, textures and links for plain-text output.
function E.StripMarkup(s)
    if type(s) ~= "string" then return s end
    s = gsub(s, "|[cC]%x%x%x%x%x%x", "")
    s = gsub(s, "|[rR]", "")
    s = gsub(s, "|t[^|]*|t", "")
    s = gsub(s, "|H[^|]*|h([^|]*)|h", "%1")
    return s
end

-- Call an API function; nil on error or if it does not exist.
local function passResults(ok, ...)
    if not ok then return nil end
    return ...
end

-- (keeps every return value, including nils in the middle)
function E.Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    return passResults(pcall(fn, ...))
end

function E.NowMs()
    if GetGameTimeMilliseconds then return GetGameTimeMilliseconds() end
    return math.floor(os.clock() * 1000)
end

function E.ShallowCopy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Turn a sorted list of ids into {start1, end1, start2, end2, ...}.
function E.EncodeRanges(ids)
    local out, s, p = {}, nil, nil
    for i = 1, #ids do
        local id = ids[i]
        if s == nil then
            s, p = id, id
        elseif id == p + 1 then
            p = id
        else
            out[#out + 1] = s; out[#out + 1] = p
            s, p = id, id
        end
    end
    if s then out[#out + 1] = s; out[#out + 1] = p end
    return out
end

function E.CountRanges(ranges)
    local n = 0
    for i = 1, #ranges, 2 do n = n + ranges[i + 1] - ranges[i] + 1 end
    return n
end

---------------------------------------------------------------------------
-- Enum names: ENUM("BUFF_EFFECT_TYPE_", 1) -> "BUFF_EFFECT_TYPE_BUFF"
---------------------------------------------------------------------------
local enumCache = {}
local numericGlobals

-- Iterate _G safely: plain pairs() errors on the game's private functions
-- ("Attempt to access a private function ... from insecure code").
function E.GlobalPairs()
    return (zo_insecurePairs or pairs)(_G)
end

-- every upper-case numeric global, read once: { {name, value}, ... }
local function getNumericGlobals()
    if not numericGlobals then
        numericGlobals = {}
        for k, v in E.GlobalPairs() do
            if type(v) == "number" and type(k) == "string" and k:find("^[A-Z]") then
                numericGlobals[#numericGlobals + 1] = { k, v }
            end
        end
    end
    return numericGlobals
end

function E.EnumName(prefix, value)
    if value == nil or prefix == nil then return nil end
    local map = enumCache[prefix]
    if not map then
        map = {}
        local plen = #prefix
        for _, kv in ipairs(getNumericGlobals()) do
            local k, v = kv[1], kv[2]
            if k:sub(1, plen) == prefix then
                local suffix = k:sub(plen + 1)
                -- skip the bounds helpers, keep the first real name per value
                if suffix ~= "MIN_VALUE" and suffix ~= "MAX_VALUE" and suffix ~= "ITERATION_BEGIN"
                    and suffix ~= "ITERATION_END" then
                    local cur = map[v]
                    if cur == nil or #k < #cur then map[v] = k end
                end
            end
        end
        enumCache[prefix] = map
    end
    return map[value]
end

-- Enum name without its prefix, lower-cased: ("BUFF_EFFECT_TYPE_", 1) -> "buff"
function E.EnumShort(prefix, value)
    local n = E.EnumName(prefix, value)
    if not n then return nil end
    return n:sub(#prefix + 1):lower()
end

-- MIN..MAX bounds of an enum family if the game defines them.
function E.EnumRange(prefix, fallbackMin, fallbackMax)
    local lo = _G[prefix .. "MIN_VALUE"] or _G[prefix .. "ITERATION_BEGIN"] or fallbackMin
    local hi = _G[prefix .. "MAX_VALUE"] or _G[prefix .. "ITERATION_END"] or fallbackMax
    return lo, hi
end

---------------------------------------------------------------------------
-- Cooperative jobs
---------------------------------------------------------------------------
local jobs = {}
local ops = 0
local syncDepth = 0

-- Count one unit of work and yield if the frame budget is spent.
function E.Tick(n)
    ops = ops + (n or 1)
    if ops >= E.budget then
        ops = 0
        if syncDepth == 0 and coroutine.running() then
            coroutine.yield()
        end
    end
end

local function step()
    local start = E.NowMs()
    local i = 1
    while i <= #jobs do
        local job = jobs[i]
        ops = 0
        local ok, err = coroutine.resume(job.co)
        if coroutine.status(job.co) == "dead" then
            table.remove(jobs, i)
            if job.onDone then
                local done = job.onDone
                if ok then
                    done(true, job.result)
                else
                    done(false, err)
                end
            elseif not ok then
                E.Print("|cFF5555Error:|r %s", tostring(err))
            end
        else
            i = i + 1
        end
        -- keep the frame light even with several jobs queued
        if E.NowMs() - start > 8 then break end
    end
    if #jobs == 0 and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate("LibESQL_Jobs")
    end
end

-- Run fn(job) in the background. onDone(ok, resultOrError) is called when done.
function E.RunAsync(fn, onDone, label)
    local job = { onDone = onDone, label = label }
    job.co = coroutine.create(function()
        job.result = fn(job)
    end)
    jobs[#jobs + 1] = job
    if EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate("LibESQL_Jobs")
        EVENT_MANAGER:RegisterForUpdate("LibESQL_Jobs", 0, step)
    else
        -- outside the game (tests): just run to completion
        while #jobs > 0 do step() end
    end
    return job
end

-- Run fn now, ignoring Tick() yields. Returns ok, result.
function E.RunSync(fn)
    syncDepth = syncDepth + 1
    local res = { pcall(fn) }
    syncDepth = syncDepth - 1
    return unpack(res)
end

function E.HasJobs() return #jobs > 0 end

-- Stop one job from RunAsync / QueryAsync / Scan. Its callback is not called.
-- Returns true if the job was still queued.
function E.CancelJob(job)
    for i = #jobs, 1, -1 do
        if jobs[i] == job then
            table.remove(jobs, i)
            if #jobs == 0 and EVENT_MANAGER then EVENT_MANAGER:UnregisterForUpdate("LibESQL_Jobs") end
            E.ResetScanFlags()
            return true
        end
    end
    return false
end

function E.CancelJobs()
    jobs = {}
    if EVENT_MANAGER then EVENT_MANAGER:UnregisterForUpdate("LibESQL_Jobs") end
end
