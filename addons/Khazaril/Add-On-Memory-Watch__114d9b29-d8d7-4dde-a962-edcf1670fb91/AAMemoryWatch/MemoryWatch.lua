-- Add-On Memory Watch
-- Works out which add-on is using the shared add-on memory (100 MB on console) or throwing errors.
--
--  1. Load cost: the memory in use is read as each add-on finishes loading, so the growth between two
--     add-ons is what the second one cost to load. (Add-ons that loaded before this one can't be timed.)
--  2. Data held: every few minutes the tables each add-on keeps are walked, a few thousand entries per
--     frame, and their size estimated. Globals are matched to add-ons by watching which add-on was loading
--     when each global was created, or else by name.
--  3. Saved data: the game's own size for each add-on's saved variables file.
--  4. Errors: every Lua error is tallied against the add-on whose file it came from.
--  5. A log of the session (memory every minute, the last measurements) is saved, so after the game turns
--     add-ons off you can turn them back on and see what happened just before.

local NAME = "AAMemoryWatch"
local TITLE = "Add-On Memory Watch"
local MW = {}
AAMemoryWatch = MW

local EM = EVENT_MANAGER
local now = GetTimeStamp

-- ---------------------------------------------------------------------------------------------------
-- Reading memory
-- ---------------------------------------------------------------------------------------------------
local hasPool = type(GetTotalUserAddOnMemoryPoolUsageMB) == "function"

--- Add-on memory in MB: the console pool if there is one, else the whole Lua heap (PC).
local function memMB()
    if hasPool then
        local mb = GetTotalUserAddOnMemoryPoolUsageMB()
        if mb and mb > 0 then return mb end
    end
    return collectgarbage("count") / 1024
end
MW.memMB = memMB

local function capMB()
    if type(GetTotalUserAddOnMemoryPoolCapacityMB) == "function" then
        local c = GetTotalUserAddOnMemoryPoolCapacityMB()
        if c and c > 0 then return c end
    end
    return nil
end

local function isPool()
    return hasPool and (GetTotalUserAddOnMemoryPoolUsageMB() or 0) > 0
end

-- ---------------------------------------------------------------------------------------------------
-- 1. Load cost, and which add-on created each global
-- ---------------------------------------------------------------------------------------------------
local loadMB = {}        -- add-on name -> MB used while loading
local loadOrder = {}     -- names in the order they loaded (after this one)
local owner = {}         -- global name -> add-on name that was loading when it was created
local pending = {}       -- globals created since the last add-on finished loading
local lastMB = memMB()   -- memory when the last add-on finished loading
local startMB = nil      -- memory when the next add-on's first global appeared (its files had started)
local loadedBeforeUs = lastMB
local allLoaded = false

local oldMT = getmetatable(_G)
local hooked = false
do
    local ok = pcall(function()
        local oldNewIndex = oldMT and oldMT.__newindex
        local mt = {}
        if oldMT then for k, v in pairs(oldMT) do mt[k] = v end end
        mt.__newindex = function(t, k, v)
            if type(oldNewIndex) == "function" then oldNewIndex(t, k, v)
            elseif type(oldNewIndex) == "table" then oldNewIndex[k] = v
            else rawset(t, k, v) end
            if not allLoaded and type(k) == "string" then
                if startMB == nil then startMB = memMB() end
                pending[#pending + 1] = k
            end
        end
        setmetatable(_G, mt)
    end)
    hooked = ok
end

local function unhook()
    if hooked then
        pcall(setmetatable, _G, oldMT)
        hooked = false
    end
end

local function onAddOnLoaded(_, name)
    if allLoaded then return end
    local m = memMB()
    local prev = loadOrder[#loadOrder]
    if name ~= NAME then
        -- What happened before this add-on's files started (the previous add-on's start-up) is the
        -- previous add-on's; the rest is this one's.
        local split = startMB or lastMB
        if prev then loadMB[prev] = (loadMB[prev] or 0) + math.max(0, split - lastMB) end
        loadMB[name] = (loadMB[name] or 0) + math.max(0, m - split)
        loadOrder[#loadOrder + 1] = name
    end
    for i = 1, #pending do
        local k = pending[i]
        if owner[k] == nil then owner[k] = name end
    end
    pending = {}
    startMB = nil
    lastMB = m
end

-- ---------------------------------------------------------------------------------------------------
-- Add-on list
-- ---------------------------------------------------------------------------------------------------
local addons = {}     -- name -> { name, title, index, isLibrary, dir, svMB }
local byDir = {}      -- lower-case root folder name -> add-on name
local byNorm = {}     -- normalised name -> add-on name, for matching globals by name

local function stripMarkup(s)
    s = tostring(s or "")
    s = s:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")
    return s
end

local function norm(s)
    s = s:lower():gsub("[^%w]", "")
    s = s:gsub("%d+$", "")
    return s
end

local function readAddOns()
    local am = GetAddOnManager()
    addons, byDir, byNorm = {}, {}, {}
    for i = 1, am:GetNumAddOns() do
        local name, title, _, _, enabled, _, _, isLibrary = am:GetAddOnInfo(i)
        if enabled then
            local a = { name = name, title = stripMarkup(title ~= "" and title or name), index = i, isLibrary = isLibrary == true }
            local ok, dir = pcall(am.GetAddOnRootDirectoryPath, am, i)
            if ok and type(dir) == "string" then
                a.dir = dir:match("[Aa]dd[Oo]ns/([^/]+)/?$") or dir:match("([^/]+)/?$")
            end
            if am.GetUserAddOnSavedVariablesDiskUsageMB then
                local ok2, sv = pcall(am.GetUserAddOnSavedVariablesDiskUsageMB, am, i)
                a.svMB = ok2 and tonumber(sv) or 0
            end
            addons[name] = a
            byDir[(a.dir or name):lower()] = name
            byDir[name:lower()] = byDir[name:lower()] or name
            local n = norm(name)
            if #n >= 4 then byNorm[n] = name end
        end
    end
end

local function titleOf(name)
    local a = addons[name]
    return a and a.title or name
end

local SUFFIXES = { "savedvariables", "savedvars", "settings", "options", "globals", "global", "data", "vars", "sv", "db" }

--- Which add-on a global left over from before this add-on loaded probably belongs to, by its name.
local function matchByName(k)
    if k:sub(1, 3) == "ZO_" or k:sub(1, 3) == "SI_" then return nil end
    local n = norm(k)
    if #n < 4 then return nil end
    if byNorm[n] then return byNorm[n] end
    for i = 1, #SUFFIXES do
        local s = SUFFIXES[i]
        if #n > #s + 3 and n:sub(-#s) == s then
            local base = n:sub(1, -#s - 1)
            if byNorm[base] then return byNorm[base] end
        end
    end
    local head = k:match("^([%w]+)_")
    if head then
        head = norm(head)
        if #head >= 4 and byNorm[head] then return byNorm[head] end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------------
-- Saved log
-- ---------------------------------------------------------------------------------------------------
local sv
local session        -- this session's log (sv.sessions[1])
local previous       -- the session before this one
local MAX_SESSIONS = 5
local MAX_SAMPLES = 240      -- one a minute: 4 hours
local MAX_ERRORS = 12
local TOP_SAVED = 40

local function prioritySave()
    pcall(function() GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(NAME) end)
end

local lastSaveRequest = 0
local function saveSoon(force)
    local t = GetGameTimeMilliseconds()
    if force or t - lastSaveRequest > 60000 then
        lastSaveRequest = t
        prioritySave()
    end
end

local function round1(x) return math.floor(x * 10 + 0.5) / 10 end
local function round2(x) return math.floor(x * 100 + 0.5) / 100 end

-- ---------------------------------------------------------------------------------------------------
-- 2. Estimating the data each add-on holds
-- ---------------------------------------------------------------------------------------------------
-- Rough Lua 5.1 sizes (64-bit): a table 56 bytes, a hash entry 40, an array slot 16, a string 25 + length.
-- Short strings are left out (Lua keeps one copy of each, and they are mostly shared keys), functions
-- count as a small closure, and the game's own tables are never walked into.
local T_TABLE, T_HASH, T_ARRAY, T_FUNC = 56, 40, 16, 40
local LONG_STRING = 16
local BUDGET = 3000          -- table entries looked at per frame
local SAFETY_MB = 6          -- stop measuring when memory gets this close to the limit

local scan = nil             -- the measurement in progress
MW.lastScan = nil            -- { t, mb, rows = { {name, bytes, tables} }, stopped }
MW.firstScan = nil           -- the first measurement this session, for growth

local function scanProgressText()
    if not scan then return nil end
    return string.format("Measuring... %d add-ons left", math.max(0, #scan.roots - scan.rootIndex + 1))
end

local function finishScan(stopped)
    local s = scan
    scan = nil
    EM:UnregisterForUpdate(NAME .. "Scan")
    if not s then return end
    local rows = {}
    for name, r in pairs(s.result) do
        rows[#rows + 1] = { name = name, bytes = r.bytes, tables = r.tables }
    end
    table.sort(rows, function(a, b) return a.bytes > b.bytes end)
    local result = { t = now(), mb = memMB(), rows = rows, stopped = stopped, ms = GetGameTimeMilliseconds() - s.startMs }
    MW.lastScan = result
    if not MW.firstScan and not stopped then MW.firstScan = result end
    if session then
        local top = {}
        for i = 1, math.min(TOP_SAVED, #rows) do
            top[i] = { n = rows[i].name, kb = math.floor(rows[i].bytes / 1024 + 0.5) }
        end
        local saved = { t = result.t, mb = round2(result.mb), top = top, stopped = stopped or nil }
        session.scanFirst = session.scanFirst or saved
        session.scanLast = saved
        saveSoon(true)
    end
    if MW.onChange then MW.onChange() end
end

local function startScan()
    if scan then return false end
    readAddOns()
    local cap = capMB()
    if cap and memMB() > cap - SAFETY_MB then
        MW.lastScan = { t = now(), mb = memMB(), rows = (MW.lastScan and MW.lastScan.rows) or {}, stopped = "full" }
        if MW.onChange then MW.onChange() end
        return false
    end
    scan = {
        startMs = GetGameTimeMilliseconds(),
        phase = 1, gKey = nil,        -- phase 1: go through the globals
        roots = {}, rootIndex = 1,     -- phase 2: walk each add-on's tables
        stop = {}, visited = {}, seenString = {},
        result = {},
        stackT = {}, stackK = {}, top = 0,
        current = nil,
    }
    EM:RegisterForUpdate(NAME .. "Scan", 0, function()
        -- Never let a problem here turn into an error every frame.
        local ok = pcall(MW.scanStep)
        if not ok then finishScan("error") end
    end)
    if MW.onChange then MW.onChange() end
    return true
end
MW.startScan = startScan

local function ownerOf(k)
    local o = owner[k]
    if o and addons[o] then return o end
    if o == nil then
        o = matchByName(k)
        if o then return o end
    end
    return nil
end

local function push(s, t)
    s.top = s.top + 1
    s.stackT[s.top] = t
    s.stackK[s.top] = nil
end

--- One frame of measuring.
function MW.scanStep()
    local s = scan
    if not s then return end
    local cap = capMB()
    if cap and memMB() > cap - SAFETY_MB then
        finishScan("full")
        return
    end
    local budget = BUDGET

    if s.phase == 1 then
        while budget > 0 do
            local ok, k, v = pcall(next, _G, s.gKey)
            if not ok then
                -- The globals changed under us; start the list again (already found roots are kept).
                s.gKey = nil
                s.restarts = (s.restarts or 0) + 1
                if s.restarts > 3 then k = nil else return end
            end
            if k == nil then
                s.phase = 2
                -- Add-ons first, libraries last, so data an add-on registers with a library counts as the
                -- add-on's.
                table.sort(s.roots, function(a, b)
                    local la, lb = addons[a.name].isLibrary, addons[b.name].isLibrary
                    if la ~= lb then return lb end
                    return a.name < b.name
                end)
                break
            end
            s.gKey = k
            budget = budget - 1
            if type(k) == "string" and k ~= "AAMemoryWatch" and k ~= "AAMemoryWatch_SV" then
                local o = ownerOf(k)
                local tv = type(v)
                if o then
                    if tv == "table" then
                        s.roots[#s.roots + 1] = { name = o, t = v }
                    else
                        local r = s.result[o] or { bytes = 0, tables = 0 }
                        s.result[o] = r
                        if tv == "function" then r.bytes = r.bytes + T_FUNC
                        elseif tv == "string" then r.bytes = r.bytes + 25 + #v end
                    end
                elseif tv == "table" then
                    s.stop[v] = true   -- the game's own tables, and anything we can't place
                end
            end
        end
        return
    end

    -- Phase 2: walk the add-ons' tables.
    while budget > 0 do
        if s.top == 0 then
            local root = s.roots[s.rootIndex]
            if not root then
                finishScan(false)
                return
            end
            s.rootIndex = s.rootIndex + 1
            s.current = s.result[root.name] or { bytes = 0, tables = 0 }
            s.result[root.name] = s.current
            if not s.visited[root.t] then
                s.visited[root.t] = true
                s.current.tables = s.current.tables + 1
                s.current.bytes = s.current.bytes + T_TABLE
                push(s, root.t)
            end
        else
            local t = s.stackT[s.top]
            local ok, k, v = pcall(next, t, s.stackK[s.top])
            if not ok or k == nil then
                s.stackT[s.top] = nil
                s.stackK[s.top] = nil
                s.top = s.top - 1
            else
                s.stackK[s.top] = k
                budget = budget - 1
                local r = s.current
                if type(k) == "number" and k >= 1 and k % 1 == 0 then
                    r.bytes = r.bytes + T_ARRAY
                else
                    r.bytes = r.bytes + T_HASH
                end
                local tv = type(v)
                if tv == "table" then
                    if not s.visited[v] and not s.stop[v] then
                        s.visited[v] = true
                        r.tables = r.tables + 1
                        r.bytes = r.bytes + T_TABLE
                        push(s, v)
                    end
                elseif tv == "string" then
                    local n = #v
                    if n >= LONG_STRING and not s.seenString[v] then
                        s.seenString[v] = true
                        r.bytes = r.bytes + 25 + n
                    end
                elseif tv == "function" then
                    r.bytes = r.bytes + T_FUNC
                end
                if type(k) == "string" and #k >= LONG_STRING and not s.seenString[k] then
                    s.seenString[k] = true
                    r.bytes = r.bytes + 25 + #k
                elseif type(k) == "table" and not s.visited[k] and not s.stop[k] then
                    s.visited[k] = true
                    r.tables = r.tables + 1
                    r.bytes = r.bytes + T_TABLE
                    push(s, k)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------------
-- 4. Errors
-- ---------------------------------------------------------------------------------------------------
MW.errors = {}       -- add-on name (or "?") -> { count, last, lastT, calledFrom }

--- The add-on whose file an error happened in, and the next add-on further up the call stack.
local function addonsInError(err)
    local first, second
    for folder in err:gmatch("[Aa]dd[Oo]ns/([^/]+)/") do
        local name = byDir[folder:lower()] or folder
        if name ~= NAME then
            if not first then first = name
            elseif name ~= first then second = name; break end
        end
    end
    return first, second
end
MW.addonsInError = addonsInError

local function onLuaError(_, err, code)
    pcall(function()
        err = tostring(err or "")
        local name, from = addonsInError(err)
        name = name or "?"
        local e = MW.errors[name]
        if not e then
            e = { count = 0 }
            MW.errors[name] = e
        end
        e.count = e.count + 1
        local t = now()
        -- Keep the text of the first error and then one every 30 seconds, so an error that repeats every
        -- frame doesn't itself use up memory.
        if not e.last or t - (e.lastT or 0) >= 30 then
            local line = stripMarkup(err):gsub("<Locals>.-</Locals>", ""):match("^[^\n]*") or ""
            e.last = line:sub(1, 240)
            e.lastT = t
            e.calledFrom = from
            if session then
                session.errors = session.errors or {}
                local list = session.errors
                table.insert(list, 1, { t = t, n = name, msg = e.last, from = from, code = code })
                while #list > MAX_ERRORS do table.remove(list) end
            end
            saveSoon(false)
        end
        if session then
            session.errorCounts = session.errorCounts or {}
            session.errorCounts[name] = (session.errorCounts[name] or 0) + 1
        end
    end)
end

-- ---------------------------------------------------------------------------------------------------
-- 5. Session log
-- ---------------------------------------------------------------------------------------------------
local function sample()
    if not session then return end
    local m = memMB()
    local t = now()
    session.lastMB, session.lastT = round2(m), t
    if m > (session.peakMB or 0) then session.peakMB, session.peakT = round2(m), t end
    local s = session.samples
    s[#s + 1] = { t, round1(m) }
    while #s > MAX_SAMPLES do table.remove(s, 1) end
    local cap = capMB()
    -- Save more often as memory gets close to the limit, so the log survives the reset.
    saveSoon(cap and m > cap * 0.8)
end

local function onMemoryLimit()
    if session then
        session.limitT = now()
        session.limitMB = round2(memMB())
    end
    saveSoon(true)
end

local function startSession()
    sv.sessions = sv.sessions or {}
    previous = sv.sessions[1]
    local loads = {}
    local list = {}
    for name, mb in pairs(loadMB) do list[#list + 1] = { name, mb } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(TOP_SAVED, #list) do loads[list[i][1]] = round2(list[i][2]) end
    local disabled = {}
    pcall(function()
        local am = GetAddOnManager()
        for i = 1, am:GetNumForceDisabledAddOns() do
            local addonName, _, addonTitle = am:GetForceDisabledAddOnInfo(i)
            disabled[#disabled + 1] = stripMarkup(addonTitle ~= "" and addonTitle or addonName)
        end
    end)
    session = {
        start = now(),
        char = GetUnitName and GetUnitName("player") or "",
        cap = capMB(),
        pool = isPool(),
        beforeUsMB = round2(loadedBeforeUs),
        loadedMB = round2(memMB()),
        loads = loads,
        samples = {},
        disabled = #disabled > 0 and disabled or nil,
    }
    table.insert(sv.sessions, 1, session)
    while #sv.sessions > MAX_SESSIONS do table.remove(sv.sessions) end
    MW.disabled = disabled
end

-- ---------------------------------------------------------------------------------------------------
-- Report text
-- ---------------------------------------------------------------------------------------------------
local function mbText(mb)
    if mb >= 10 then return string.format("%.0f MB", mb) end
    if mb >= 0.1 then return string.format("%.1f MB", mb) end
    return string.format("%.0f KB", mb * 1024)
end
MW.mbText = mbText

local function ago(t)
    local d = math.max(0, now() - (t or 0))
    if d < 90 then return "just now" end
    if d < 3600 then return string.format("%d min ago", math.floor(d / 60 + 0.5)) end
    if d < 86400 then return string.format("%dh %dm ago", math.floor(d / 3600), math.floor(d % 3600 / 60)) end
    return string.format("%d days ago", math.floor(d / 86400))
end

local function duration(sec)
    sec = math.max(0, sec or 0)
    if sec < 3600 then return string.format("%d min", math.floor(sec / 60 + 0.5)) end
    return string.format("%dh %02dm", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end

--- Per add-on figures, biggest first: { name, title, loadMB, dataMB, growMB, svMB, errors, best }.
function MW.ranking()
    local rows, seen = {}, {}
    local function row(name)
        local r = seen[name]
        if not r then
            local a = addons[name]
            r = { name = name, title = titleOf(name), loadMB = loadMB[name], svMB = a and a.svMB or 0,
                  isLibrary = a and a.isLibrary, errors = MW.errors[name] and MW.errors[name].count or 0 }
            seen[name] = r
            rows[#rows + 1] = r
        end
        return r
    end
    for name in pairs(loadMB) do if addons[name] then row(name) end end
    local first = {}
    if MW.firstScan and MW.firstScan ~= MW.lastScan then
        for _, x in ipairs(MW.firstScan.rows) do first[x.name] = x.bytes end
    end
    if MW.lastScan then
        for _, x in ipairs(MW.lastScan.rows) do
            local r = row(x.name)
            r.dataMB = x.bytes / 1048576
            if first[x.name] then r.growMB = (x.bytes - first[x.name]) / 1048576 end
        end
    end
    for name, a in pairs(addons) do
        if (a.svMB or 0) >= 0.05 then row(name) end
    end
    for _, r in ipairs(rows) do
        r.best = math.max(r.loadMB or 0, (r.dataMB or 0) + 0, (r.svMB or 0))
    end
    table.sort(rows, function(a, b) return a.best > b.best end)
    -- Leave out the ones too small to matter.
    local out = {}
    for _, r in ipairs(rows) do if r.best >= 0.05 then out[#out + 1] = r end end
    return out
end

function MW.rowDetail(r)
    local lines = {}
    if r.loadMB and r.loadMB < 0.01 then
        lines[#lines + 1] = "Used almost nothing while loading."
    elseif r.loadMB then
        lines[#lines + 1] = "Used " .. mbText(r.loadMB) .. " while loading."
    else
        lines[#lines + 1] = "Loaded before Add-On Memory Watch, so its loading couldn't be measured."
    end
    if r.dataMB then
        lines[#lines + 1] = "Holds about " .. mbText(r.dataMB) .. " of data now."
    end
    if r.growMB and math.abs(r.growMB) >= 0.05 then
        lines[#lines + 1] = (r.growMB > 0 and "Grown by " or "Shrunk by ") .. mbText(math.abs(r.growMB)) .. " since the first measurement."
    end
    if (r.svMB or 0) > 0 then
        lines[#lines + 1] = "Saved data file: " .. mbText(r.svMB) .. ". It is read into memory at every login and reload, and memory use is usually larger than the file."
    end
    if r.errors > 0 then
        lines[#lines + 1] = string.format("%d error%s this session.", r.errors, r.errors == 1 and "" or "s")
    end
    if r.isLibrary then lines[#lines + 1] = "This is a library other add-ons use." end
    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------------------------------
-- Settings panel (Settings > Add-Ons > Add-On Memory Watch)
-- ---------------------------------------------------------------------------------------------------
local panel
local ROWS = 15

local function nowText()
    local m = memMB()
    local cap = capMB()
    local peak = session and session.peakMB or m
    if cap then
        return string.format("%.1f of %d MB in use (highest this session %.1f MB)", m, cap, math.max(peak, m))
    end
    return string.format("%.1f MB of Lua memory in use (PC: this includes the game's own interface)", m)
end

local function scanStatusText()
    local p = scanProgressText()
    if p then return p end
    local s = MW.lastScan
    if not s then return "Not measured yet. It measures 2 minutes after you log in and then every 5 minutes." end
    if s.stopped == "error" then
        return "Measuring stopped part way. Figures may be incomplete."
    end
    if s.stopped == "full" then
        return "Measuring was stopped because memory was within " .. SAFETY_MB .. " MB of the limit. Figures may be from earlier."
    end
    return "Measured " .. ago(s.t) .. string.format(" at %.1f MB, taking %.1f seconds.", s.mb, (s.ms or 0) / 1000)
end

local function buildPanel(redraw)
    local LHAS = LibHarvensAddonSettings
    if not panel or not LHAS then return end
    panel:Clear()
    local list = {}
    local function add(x) list[#list + 1] = x end

    add({ type = LHAS.ST_SECTION, label = "Right now" })
    add({ type = LHAS.ST_LABEL, label = nowText,
          tooltip = "All add-ons share this memory. The game warns when it gets close to full and turns every add-on off when it runs out, which reloads the interface." })
    add({ type = LHAS.ST_BUTTON, label = "Measure each add-on", buttonText = "Measure",
          tooltip = "Estimate the data each add-on is holding now. It takes a few seconds, spread out so the game doesn't stutter. Come back to this page to see the results.",
          clickHandler = function() startScan() end })
    if ADD_ON_MEMORY_DISPLAY and ADD_ON_MEMORY_DISPLAY.Toggle then
        add({ type = LHAS.ST_CHECKBOX, label = "Show the game's memory meter", default = false,
              tooltip = "The game's own add-on memory readout, shown on screen while you play.",
              getFunction = function() return ADD_ON_MEMORY_DISPLAY.savedVars and ADD_ON_MEMORY_DISPLAY.savedVars.isVisible == true end,
              setFunction = function(v)
                  local vis = ADD_ON_MEMORY_DISPLAY.savedVars and ADD_ON_MEMORY_DISPLAY.savedVars.isVisible == true
                  if (v and true or false) ~= vis then ADD_ON_MEMORY_DISPLAY:Toggle() end
              end })
    end

    -- Biggest add-ons
    add({ type = LHAS.ST_SECTION, label = "Biggest add-ons" })
    add({ type = LHAS.ST_LABEL, label = scanStatusText })
    local rows = MW.ranking()
    for i = 1, math.min(ROWS, #rows) do
        local r = rows[i]
        local tag = r.growMB and r.growMB >= 0.5 and string.format("  (growing +%s)", mbText(r.growMB)) or ""
        add({ type = LHAS.ST_LABEL, label = string.format("%d. %s  %s%s", i, r.title, mbText(r.best), tag),
              tooltip = MW.rowDetail(r) })
    end
    if #rows == 0 then
        add({ type = LHAS.ST_LABEL, label = "No figures yet." })
    end
    if session then
        add({ type = LHAS.ST_LABEL,
              label = string.format("Add-ons that loaded before this one used %s together. All add-ons had used %s by the end of loading.",
                  mbText(session.beforeUsMB or 0), mbText(session.loadedMB or 0)) })
    end

    -- Growing
    local growing = {}
    for _, r in ipairs(rows) do if r.growMB and r.growMB >= 0.2 then growing[#growing + 1] = r end end
    table.sort(growing, function(a, b) return a.growMB > b.growMB end)
    if #growing > 0 then
        add({ type = LHAS.ST_SECTION, label = "Growing since you logged in" })
        for i = 1, math.min(5, #growing) do
            local r = growing[i]
            add({ type = LHAS.ST_LABEL, label = string.format("%s  +%s", r.title, mbText(r.growMB)),
                  tooltip = "An add-on that keeps growing while you play is the usual cause of running out of memory.\n\n" .. MW.rowDetail(r) })
        end
    end

    -- Errors
    add({ type = LHAS.ST_SECTION, label = "Errors this session" })
    local errs = {}
    for name, e in pairs(MW.errors) do errs[#errs + 1] = { name = name, e = e } end
    table.sort(errs, function(a, b) return a.e.count > b.e.count end)
    if #errs == 0 then
        add({ type = LHAS.ST_LABEL, label = "None so far." })
    end
    for i = 1, math.min(8, #errs) do
        local x = errs[i]
        local title = x.name == "?" and "Not from an add-on file" or titleOf(x.name)
        local tip = "Latest: " .. (x.e.last or "")
        if x.e.calledFrom then tip = tip .. "\n\nCalled from " .. titleOf(x.e.calledFrom) .. "." end
        add({ type = LHAS.ST_LABEL, label = string.format("%s  %d", title, x.e.count), tooltip = tip })
    end

    -- Last session
    if previous then
        add({ type = LHAS.ST_SECTION, label = "Last session" })
        local p = previous
        local cap = p.cap or capMB()
        local endTxt = string.format("Ended at %.1f MB%s, %s, after %s.",
            p.lastMB or 0, cap and (" of " .. cap) or "", ago(p.lastT), duration((p.lastT or p.start) - p.start))
        local peakTxt = p.peakMB and string.format(" Highest: %.1f MB.", p.peakMB) or ""
        add({ type = LHAS.ST_LABEL, label = endTxt .. peakTxt })
        if p.limitT then
            add({ type = LHAS.ST_LABEL, label = string.format("The game ran out of add-on memory (%.1f MB), %s.", p.limitMB or 0, ago(p.limitT)) })
        elseif cap and (p.lastMB or 0) >= cap * 0.9 then
            add({ type = LHAS.ST_LABEL, label = "Memory was nearly full when it ended, so the game probably turned add-ons off." })
        end
        local function topOf(scanRec, n)
            local out = {}
            if scanRec and scanRec.top then
                for i = 1, math.min(n, #scanRec.top) do out[i] = scanRec.top[i] end
            end
            return out
        end
        local firstKB = {}
        if p.scanFirst and p.scanFirst ~= p.scanLast then
            for _, x in ipairs(p.scanFirst.top or {}) do firstKB[x.n] = x.kb end
        end
        local last = topOf(p.scanLast, 6)
        if #last > 0 then
            add({ type = LHAS.ST_LABEL, label = "Biggest data at its last measurement, " .. ago(p.scanLast.t) .. ":" })
            for _, x in ipairs(last) do
                local grow = firstKB[x.n] and (x.kb - firstKB[x.n]) / 1024 or nil
                local g = grow and grow >= 0.2 and string.format("  (grew +%s)", mbText(grow)) or ""
                add({ type = LHAS.ST_LABEL, label = "   " .. titleOf(x.n) .. "  " .. mbText(x.kb / 1024) .. g })
            end
        end
        if p.errorCounts then
            local worst, wn = nil, 0
            for n, c in pairs(p.errorCounts) do if c > wn then worst, wn = n, c end end
            if worst then
                add({ type = LHAS.ST_LABEL, label = string.format("Most errors: %s (%d).", worst == "?" and "not from an add-on file" or titleOf(worst), wn) })
            end
        end
    end

    -- Turned off by the game
    if MW.disabled and #MW.disabled > 0 then
        add({ type = LHAS.ST_SECTION, label = "Turned off by the game" })
        for _, t in ipairs(MW.disabled) do
            add({ type = LHAS.ST_LABEL, label = t, tooltip = "The game turned this add-on off on its own. It is the first one to look at." })
        end
    end

    -- Saved data
    local am = GetAddOnManager()
    if am.GetTotalUserAddOnSavedVariablesDiskUsageMB then
        add({ type = LHAS.ST_SECTION, label = "Saved data" })
        local okU, used = pcall(am.GetTotalUserAddOnSavedVariablesDiskUsageMB, am)
        local okC, capS = pcall(am.GetTotalUserAddOnSavedVariablesDiskCapacityMB, am)
        if okU and used then
            add({ type = LHAS.ST_LABEL, label = string.format("Add-on saved data uses %s%s.", mbText(used),
                okC and capS and capS > 0 and (" of " .. mbText(capS)) or ""),
                tooltip = "Each add-on's saved data is loaded into add-on memory at every login and reload. A large file is a common reason memory starts out high." })
        end
        local svRows = {}
        for _, a in pairs(addons) do if (a.svMB or 0) > 0 then svRows[#svRows + 1] = a end end
        table.sort(svRows, function(a, b) return a.svMB > b.svMB end)
        for i = 1, math.min(5, #svRows) do
            add({ type = LHAS.ST_LABEL, label = string.format("   %s  %s", svRows[i].title, mbText(svRows[i].svMB)) })
        end
    end

    add({ type = LHAS.ST_SECTION, label = "About these figures" })
    add({ type = LHAS.ST_LABEL, label = "Each add-on's figure is the largest of what it used while loading, the data it holds now and its saved data file. They are estimates: add-ons share memory, and memory that is no longer needed is only cleared now and then." })

    panel:AddSettings(list)
    -- Redraw if the page is open right now (console settings list).
    if redraw and panel.selected and IsConsoleUI and IsConsoleUI() and panel.CreateControls then
        pcall(panel.CreateControls, panel)
    end
end
MW.buildPanel = buildPanel

local function createPanel()
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then return end
    panel = LHAS:AddAddon(TITLE, { allowDefaults = false })
    -- Refresh the figures each time the page is opened.
    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, selected)
            if selected == panel and not MW.building then
                MW.building = true
                readAddOns()
                pcall(buildPanel)
                -- The library may already have drawn the old rows; draw the new ones (console list).
                if IsConsoleUI and IsConsoleUI() and panel.CreateControls then pcall(panel.CreateControls, panel) end
                MW.building = false
            end
        end)
    end
    buildPanel()
end

-- ---------------------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------------------
local SCAN_FIRST_MS = 120000
local SCAN_EVERY_MS = 300000

local function onAllLoaded()
    if allLoaded then return end
    -- The last add-on's own start-up ran after its load event.
    local m = memMB()
    local last = loadOrder[#loadOrder]
    if last then loadMB[last] = (loadMB[last] or 0) + math.max(0, m - lastMB) end
    for i = 1, #pending do owner[pending[i]] = owner[pending[i]] or false end
    pending = {}
    allLoaded = true
    unhook()

    readAddOns()
    sv = ZO_SavedVars:NewAccountWide("AAMemoryWatch_SV", 1, nil, {})
    startSession()
    createPanel()

    sample()
    EM:RegisterForUpdate(NAME .. "Sample", 60000, function() pcall(sample) end)
    zo_callLater(function()
        startScan()
        EM:RegisterForUpdate(NAME .. "AutoScan", SCAN_EVERY_MS, function()
            local cap = capMB()
            if not cap or memMB() < cap - 10 then startScan() end
        end)
    end, SCAN_FIRST_MS)
end

EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
EM:RegisterForEvent(NAME, EVENT_ADD_ONS_LOADED, onAllLoaded)
EM:RegisterForEvent(NAME, EVENT_LUA_ERROR, onLuaError)
if EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED then
    EM:RegisterForEvent(NAME, EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED, onMemoryLimit)
end

MW.onChange = function()
    if panel and not MW.building then
        MW.building = true
        pcall(buildPanel, true)
        MW.building = false
    end
end

-- For testing outside the game.
MW._test = { loadMB = loadMB, owner = owner, addons = function() return addons end, session = function() return session end,
             previous = function() return previous end, isScanning = function() return scan ~= nil end }
