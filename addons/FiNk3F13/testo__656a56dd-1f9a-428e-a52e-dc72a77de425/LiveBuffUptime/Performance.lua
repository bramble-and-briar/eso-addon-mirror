local Perf = { active = false }
LiveBuffUptimePerformance = Perf
local state, frameControl, depth, childTime = nil, nil, 0, {}
local unpack = unpack
local function pack(...) return { n = select("#", ...), ... } end

function Perf.Wrap(category, callback)
    return function(...)
        if not Perf.active then return callback(...) end
        local args = pack(...)
        local started = GetGameTimeMilliseconds()
        local frame = GetFrameTimeSeconds()
        depth = depth + 1
        local level = depth
        childTime[level] = 0
        local result = pack(xpcall(function() return callback(unpack(args, 1, args.n)) end,
            function(err) return err end))
        local elapsed = math.max(0, GetGameTimeMilliseconds() - started)
        local exclusive = math.max(0, elapsed - childTime[level])
        childTime[level] = nil
        depth = depth - 1
        if depth > 0 then childTime[depth] = childTime[depth] + elapsed end
        local stats = state.categories[category]
        if not stats then
            stats = { calls = 0, total = 0, max = 0, slow = 0, errors = 0 }
            state.categories[category] = stats
        end
        stats.calls = stats.calls + 1
        stats.total = stats.total + elapsed
        stats.max = math.max(stats.max, elapsed)
        if elapsed >= 5 then stats.slow = stats.slow + 1 end
        if not result[1] then stats.errors = stats.errors + 1 end
        state.work = state.work + exclusive
        state.frameWork[frame] = (state.frameWork[frame] or 0) + exclusive
        if not result[1] then error(result[2], 0) end
        return unpack(result, 2, result.n)
    end
end

local function sampleFrame()
    if not Perf.active then return end
    local now = GetFrameTimeSeconds()
    local previous = state.lastFrame
    if previous and now > previous then
        local elapsed = (now - previous) * 1000
        state.frames = state.frames + 1
        state.frameTotal = state.frameTotal + elapsed
        state.frameMax = math.max(state.frameMax, elapsed)
        if elapsed >= 50 then
            state.stutters = state.stutters + 1
            if (state.frameWork[previous] or 0) >= 5 then state.correlated = state.correlated + 1 end
        end
    end
    state.lastFrame = now
    -- Keep only current-frame work, including callbacks that ran before OnUpdate.
    local current = state.frameWork[now]
    state.frameWork = current and { [now] = current } or {}
end

function Perf.Start()
    if Perf.active then return false, "Performance-Debug laeuft bereits." end
    if not GetGameTimeMilliseconds then return false, "Laufzeituhr nicht verfuegbar." end
    state = { started = GetGameTimeMilliseconds(), categories = {}, work = 0, frameWork = {},
        frames = 0, frameTotal = 0, frameMax = 0, stutters = 0, correlated = 0 }
    depth, childTime = 0, {}
    if not frameControl then
        frameControl = WINDOW_MANAGER:CreateTopLevelWindow("LiveBuffUptimePerformanceFrames")
        frameControl:SetDimensions(1, 1)
        frameControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        frameControl:SetMouseEnabled(false)
    end
    Perf.active = true
    frameControl:SetHidden(false)
    frameControl:SetHandler("OnUpdate", sampleFrame)
    return true
end

function Perf.Stop()
    if not Perf.active then return false end
    state.stopped = GetGameTimeMilliseconds()
    Perf.active = false
    frameControl:SetHandler("OnUpdate", nil)
    frameControl:SetHidden(true)
    return true
end

function Perf.Report()
    if not state then d("LiveBuffUptime: Zuerst /lbu perf start ausfuehren."); return end
    local duration = math.max(0, (state.stopped or GetGameTimeMilliseconds()) - state.started)
    d(string.format("LiveBuffUptime Performance: %s | %.1fs | eigene Arbeit %.2fms (%.2f%% der Messzeit)",
        Perf.active and "laeuft" or "gestoppt", duration / 1000, state.work,
        duration > 0 and state.work / duration * 100 or 0))
    for _, category in ipairs({ "Live-Update", "ESO-Ereignisse", "Bibliotheks-Ereignisse" }) do
        local stats = state.categories[category] or { calls = 0, total = 0, max = 0, slow = 0, errors = 0 }
        d(string.format("%s: %d Aufrufe | Mittel %.3fms | Max %.2fms | ab 5ms: %d | Fehler: %d",
            category, stats.calls, stats.calls > 0 and stats.total / stats.calls or 0, stats.max, stats.slow, stats.errors))
    end
    local mean = state.frames > 0 and state.frameTotal / state.frames or 0
    d(string.format("Bildzeiten: Mittel %.2fms (~%.1f FPS) | Max %.2fms | ab 50ms: %d | davon mit >=5ms eigener Arbeit im vorherigen Frame: %d",
        mean, mean > 0 and 1000 / mean or 0, state.frameMax, state.stutters, state.correlated))
    d("Nur unsere Callback-Laufzeiten; keine gesamte Bibliotheks-/Spiel-/GPU-/GC-Zeit. Zeitgleich ist kein Ursachenbeweis. Vergleich mit deaktiviertem Addon noetig; Debug selbst erzeugt Messaufwand.")
end
