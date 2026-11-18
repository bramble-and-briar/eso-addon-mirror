-- The engine: owns the active tracker list, keeps data-source registrations in sync with it, and
-- runs the evaluation tick (load -> trigger -> conditions -> sort -> display) for every tracker.

local DT = DebuffTracker
local Engine = DT.Engine
local U = DT.Util
local C = DT.Const
local T = DT.Triggers
local Cond = DT.Conditions
local Load = DT.Load

local NS = "DebuffTracker5_Engine"
local TICK_MS = 100            -- default; Settings > Performance "Update trackers every" (settings.updateMs)
Engine.MIN_MS, Engine.MAX_MS = 50, 500
local COMBAT_RESET_GAP = 3   -- out of combat this long before uptime counters restart

Engine.trackers = {}
Engine.byId = {}
Engine.runtime = {}
Engine.stats = { avgMs = 0, maxMs = 0, ticks = 0, states = 0, loaded = 0 }

local lastTick = 0
local lastPrune = 0
local lastResolve = 0
local wasInCombat = false
local outOfCombatSince = 0

------------------------------------------------------------------------------
-- Tracker set
------------------------------------------------------------------------------

function Engine.Get(id)
    return Engine.byId[id]
end

function Engine.Runtime(id)
    local rt = Engine.runtime[id]
    if not rt then
        rt = { combatTime = 0, activeTime = 0, uptime = nil, loaded = false, reason = nil, count = 0 }
        Engine.runtime[id] = rt
    end
    return rt
end

-- Call after ANY change to trackers (add/remove/edit/profile switch).
function Engine.Rebuild()
    local trackers = DT.Profiles.ActiveTrackers()
    Engine.trackers = trackers
    Engine.byId = {}
    for _, t in ipairs(trackers) do Engine.byId[t.id] = t end
    T.ClearCache()
    DT.Procs.Invalidate()

    local ids, names, scopes, combat = {}, {}, {}, {}
    local toggleGroups = {}
    local hasProcs = false
    local needEngaged, myDots = false, false
    -- group-scope abilities (nil = some group tracker needs every effect: names, "my DoTs", empty list)
    local groupIds, groupAll, groupNames, groupEvery = {}, false, {}, false
    -- "my target" trackers: what they look for (listened to on a locked tab target, see DT.TabTarget)
    local targetIds, targetNames, targetAll, hasTarget = {}, {}, false, false
    for _, tracker in ipairs(trackers) do
        if tracker.enabled then
          for _, t in ipairs(T.AllTriggers(tracker)) do     -- the main trigger + extra triggers
            local tr = t.trigger
            if tr.type == "effect" then
                if tr.stacksFrom == "mydots" and not C.TAGGED_SCOPES[tr.scope] then myDots = true end
                if tr.scope == "target" then
                    hasTarget = true
                    for _, id in ipairs(T.AllIds(tr)) do targetIds[id] = true end
                    for _, n in ipairs(tr.names) do targetNames[n] = true end
                    if #tr.names == 0 and #tr.abilityIds == 0 then targetAll = true end
                end
                if C.TAGGED_SCOPES[tr.scope] then
                    scopes[tr.scope] = true
                    if tr.scope == "group" then
                        for _, id in ipairs(T.AllIds(tr)) do groupIds[id] = true end
                        for _, n in ipairs(tr.names) do groupNames[n] = true end
                        if #tr.names > 0 or #tr.abilityIds == 0 or tr.stacksFrom == "mydots" then groupAll = true end
                        if (#tr.names == 0 and #tr.abilityIds == 0) or tr.stacksFrom == "mydots" then groupEvery = true end
                    end
                else
                    if tr.mode ~= "present" then needEngaged = true end
                    for _, id in ipairs(T.AllIds(tr)) do ids[id] = true end
                    for _, n in ipairs(tr.names) do names[n] = true end
                end
            elseif tr.type == "combat" then
                combat[#combat + 1] = t
            elseif tr.type == "procs" then
                hasProcs = true
                for _, p in ipairs(DT.Procs.Proxies(t)) do combat[#combat + 1] = p end
            elseif tr.type == "toggle" then
                for _, g in ipairs(T.Compile(t).groups) do toggleGroups[#toggleGroups + 1] = g end
            elseif tr.type == "stat" and (tr.stat == "penTarget" or tr.stat == "critTarget") then
                scopes.target = true            -- the debuffs on your target, read as they change
            end
          end
          -- rules on "my penetration / crit damage vs. the enemy" read your target's debuffs too
          for _, rule in ipairs(tracker.conditions) do
              if not rule.disabled and (Cond.Uses(rule, "penTarget") or Cond.Uses(rule, "penMissing") or Cond.Uses(rule, "penOver") or Cond.Uses(rule, "critTarget")) then
                  scopes.target = true
              end
          end
        end
    end
    DT.Toggles.SetWatched(toggleGroups)
    DT.Procs.SetTargetWatching(hasProcs)
    -- names that effect triggers match (any scope, enabled or not): their icons are remembered
    local iconNames = {}
    for _, tracker in ipairs(trackers) do
        for _, t in ipairs(T.AllTriggers(tracker)) do
            if t.trigger.type == "effect" then for _, n in ipairs(t.trigger.names or {}) do iconNames[n] = true end end
        end
    end
    if DT.Effects.SetIconNames then DT.Effects.SetIconNames(iconNames) end
    DT.Effects.SetRequirements({ ids = ids, names = names, scopes = scopes, myDots = myDots,
        enemies = (next(ids) ~= nil or next(names) ~= nil or needEngaged or myDots) or nil,
        groupIds = not groupAll and groupIds or nil,
        targetIds = targetIds, targetNames = targetNames, targetAll = targetAll,
        -- what a change on a group member must be about to need a rescan of that member's buffs
        groupWant = { ids = groupIds, names = groupNames, all = groupEvery } })
    DT.Units.SetEngagedTracking(needEngaged)
    local st = DT.Profiles.Settings and DT.Profiles.Settings()
    DT.TabTarget.SetWatched(hasTarget and not (st and st.followTabTarget == false))
    -- "Select quickslot" rules: the quickslot event only while one exists
    local quickslot = false
    for _, tracker in ipairs(trackers) do
        if tracker.enabled then
            for _, rule in ipairs(tracker.conditions) do
                if not rule.disabled and rule.action == "quickslot" then quickslot = true end
            end
        end
    end
    DT.Quickslot.SetWatched(quickslot)
    -- what's on the bars (chaining skills like Stone Giant change in their slot): only when something looks at it
    local bars = false
    for _, tracker in ipairs(trackers) do
        if tracker.enabled then
            local ld = tracker.load
            if #(ld.skills or {}) > 0 or #(ld.skillNames or {}) > 0 then bars = true end
            for _, rule in ipairs(tracker.conditions) do
                if not rule.disabled and Cond.Uses(rule, "onBar") then bars = true end
            end
        end
    end
    DT.Load.SetChainWatch(bars)
    -- "Resource tick" trackers: the power updates of the resources they show; dodge fatigue while a rule reads it
    local tickRes, fatigueOn = {}, false
    for _, tracker in ipairs(trackers) do
        if tracker.enabled then
            for _, t in ipairs(T.AllTriggers(tracker)) do
                if t.trigger.type == "tick" then tickRes[t.trigger.powerType] = true end
            end
            for _, rule in ipairs(tracker.conditions) do
                if not rule.disabled and Cond.Uses(rule, "dodgeFatigue") then fatigueOn = true end
            end
        end
    end
    DT.Ticks.SetWatched(tickRes, fatigueOn)
    -- "Global cooldown" trackers: the action bar / your combat events (the first one's options)
    local gcdOpts
    for _, tracker in ipairs(trackers) do
        if tracker.enabled and not gcdOpts then
            for _, t in ipairs(T.AllTriggers(tracker)) do
                local tr = t.trigger
                if tr.type == "gcd" and not gcdOpts then gcdOpts = tr end
            end
        end
    end
    DT.GlobalCooldown.SetWatched(gcdOpts)
    DT.Combat.SetRequirements(combat)

    for id in pairs(Engine.runtime) do
        if not Engine.byId[id] then Engine.runtime[id] = nil; Cond.Reset(id) end
    end
    DT.Displays.Sync(trackers)
    Engine.RequestUpdate()
end

-- Ability timers only (gear / champion skills changed: "My procs" trackers have other procs now).
function Engine.RefreshCombat()
    local combat = {}
    for _, tracker in ipairs(Engine.trackers) do
        if tracker.enabled then
            for _, t in ipairs(T.AllTriggers(tracker)) do
                if t.trigger.type == "combat" then combat[#combat + 1] = t
                elseif t.trigger.type == "procs" then
                    for _, p in ipairs(DT.Procs.Proxies(t)) do combat[#combat + 1] = p end
                end
            end
        end
    end
    DT.Combat.SetRequirements(combat)
    Engine.RequestUpdate()
end

------------------------------------------------------------------------------
-- Sorting
------------------------------------------------------------------------------

local HUGE = 1e12

-- Sort keys are computed once per state (a tracker over a big pull can hold hundreds of states;
-- recomputing inside the comparator dominated the tick). Comparators are static: no closures per tick.
local function Remaining(s, now)
    if not s.active then return HUGE * 2 end
    if s.expire and s.expire > 0 then return s.expire - now end
    return HUGE
end

local function Tie(a, b)
    local oa, ob = a.order or 0, b.order or 0
    if oa ~= ob then return oa < ob end
    local ka, kb = a.key, b.key
    if type(ka) ~= "string" then ka = tostring(ka) end
    if type(kb) ~= "string" then kb = tostring(kb) end
    return ka < kb
end

local COMPARE = {
    expiry = function(a, b)
        if a.active ~= b.active then return a.active == true end
        if a._rem ~= b._rem then return a._rem < b._rem end
        return Tie(a, b)
    end,
    expiryDesc = function(a, b)
        if a.active ~= b.active then return a.active == true end
        if a._rem ~= b._rem then return a._rem > b._rem end
        return Tie(a, b)
    end,
    name = function(a, b)
        if a.active ~= b.active then return a.active == true end
        if a._sk ~= b._sk then return a._sk < b._sk end
        return Tie(a, b)
    end,
    order = function(a, b)
        if a.active ~= b.active then return a.active == true end
        return Tie(a, b)
    end,
}
COMPARE.unit = COMPARE.name
-- one icon for "my Stagger": the target's if it has it, else the one applied last (most time left)
COMPARE.target = function(a, b)
    if a.active ~= b.active then return a.active == true end
    if (a.isTarget == true) ~= (b.isTarget == true) then return a.isTarget == true end
    if a._rem ~= b._rem then return a._rem > b._rem end
    return Tie(a, b)
end
-- every entry keeps its place whatever its state: by unit, then by its place in the tracker's ability
-- list (proc grids: catalogue order) -- not by time left, so icons and bars don't jump around
-- (a plain lexicographic key, so mixed lists -- buffs plus an ability timer -- still sort consistently;
-- entries without a slot -- procs, timers, resources -- keep their own order)
COMPARE.fixed = function(a, b)
    -- the group cycle (BuffTheGroup): group order, whatever the names
    local pa, pb = a.fixedPos, b.fixedPos
    if pa and pb and pa ~= pb then return pa < pb end
    local ua, ub = a.slot and (a.unitName or "") or "", b.slot and (b.unitName or "") or ""
    if ua ~= ub then return ua < ub end
    local sa, sb = a.slot or 0, b.slot or 0
    if sa ~= sb then return sa < sb end
    return Tie(a, b)
end

local function PrepareKeys(states, mode, now)
    if mode == "name" then
        for _, s in ipairs(states) do s._sk = U.Lower(s.name or "") end
    elseif mode == "unit" then
        for _, s in ipairs(states) do s._sk = U.Lower(s.unitName or "") end
    else
        for _, s in ipairs(states) do s._rem = Remaining(s, now) end
    end
end

local function SortStates(states, mode, now)
    PrepareKeys(states, mode, now)
    table.sort(states, COMPARE[mode] or COMPARE.expiry)
end
Engine.SortStates = SortStates

-- Sound / screen-alert rules must see every state (they fire per state); otherwise only the states
-- that can still make it on screen are evaluated.
local function HasOneShotRules(tracker)
    for _, rule in ipairs(tracker.conditions) do
        if not rule.disabled and (rule.action == "sound" or rule.action == "alert" or rule.action == "quickslot") then return true end
    end
    return false
end

------------------------------------------------------------------------------
-- Tick
------------------------------------------------------------------------------

local countsPending = false
local function UpdateCombat(ctx, now, dt)
    if ctx.inCombat and not wasInCombat then
        if now - outOfCombatSince >= COMBAT_RESET_GAP then
            for _, rt in pairs(Engine.runtime) do rt.combatTime, rt.activeTime = 0, 0 end
        end
    elseif not ctx.inCombat and wasInCombat then
        outOfCombatSince = now
    end
    -- proc counters (Pearls, Esoteric Greaves) count per fight and clear 3 s after it ends -- the game's combat state,
    -- like Cooldowns' OnCombatEnd -> ResetProcs (before 5.21.24 they stayed up until the next fight began)
    if IsUnitInCombat("player") then
        countsPending = true
    elseif countsPending and DT.Load.SinceCombat() >= COMBAT_RESET_GAP then
        countsPending = false
        DT.Combat.ResetCounts()
        Engine.RequestUpdate()
    end
    wasInCombat = ctx.inCombat
end

function Engine.EvaluateTracker(tracker, now, ctx, test)
    local states = test and T.TestStates(tracker, now) or T.Build(tracker, now)
    local mode = tracker.display.sort
    local cmp = COMPARE[mode] or COMPARE.expiry
    local dtype = tracker.display.type
    local max = dtype == "alert" and 1 or tracker.display.maxShown
    -- above heads: maxShown is per person (applied when placing); keep every person's entries here
    if dtype == "heads" then max = math.max(#states, 1) end
    local shown, n = {}, 0
    if #states <= max * 3 then
        -- few states: sort, then evaluate rules only until the display is full
        PrepareKeys(states, mode, now)
        table.sort(states, cmp)
        local evaluateAll = not test and HasOneShotRules(tracker)
        for _, s in ipairs(states) do
            if n >= max and not evaluateAll then break end
            local look = Cond.Evaluate(tracker, s, now, ctx, test)
            if not (look and look.hide) and n < max then
                s.look = look
                n = n + 1
                shown[n] = s
            end
        end
    else
        -- many states (big pulls): keep only the best `max` with a bounded insertion instead of
        -- sorting hundreds of entries every tick
        PrepareKeys(states, mode, now)
        for _, s in ipairs(states) do
            local look = Cond.Evaluate(tracker, s, now, ctx, test)
            if not (look and look.hide) and (n < max or cmp(s, shown[n])) then
                s.look = look
                if n < max then n = n + 1 end
                local i = n
                shown[i] = s
                while i > 1 and cmp(shown[i], shown[i - 1]) do
                    shown[i], shown[i - 1] = shown[i - 1], shown[i]
                    i = i - 1
                end
            end
        end
    end
    Cond.EndTracker(tracker.id)
    return shown, #states
end

function Engine.Tick()
    if not DT.ready then return end
    local t0 = GetGameTimeMilliseconds()
    local now = U.Now()
    -- target not identified yet (e.g. its effects were applied before we looked at it): retry
    if not DT.Units.reticleUnitId and now - lastResolve > 0.5 and DoesUnitExist("reticleover") then
        lastResolve = now
        DT.Effects.ResolveTarget()
    end
    DT.TabTarget.Poll(now)
    local dt = lastTick > 0 and math.min(now - lastTick, 1) or 0
    lastTick = now
    local ctx = Load.Context()
    UpdateCombat(ctx, now, dt)
    if now - lastPrune > 1 then
        lastPrune = now
        DT.Effects.Prune(now)
    end
    Cond.BeginTick()
    DT.Quickslot.BeginTick()

    local test = DT.testMode or DT.unlocked or DT.editorPreview
    local totalStates, loadedCount = 0, 0
    for _, tracker in ipairs(Engine.trackers) do
        local rt = Engine.Runtime(tracker.id)
        local display = DT.Displays.Get(tracker.id)
        local loaded, reason
        if test then
            loaded = tracker.enabled
            reason = not loaded and DT.L("Disabled") or nil
            local headsProblem = loaded and Load.HeadsProblem(tracker)
            if headsProblem then loaded, reason = false, headsProblem end
        else
            loaded, reason = Load.Check(tracker, ctx)
        end
        if DT.debug and not test and rt.loaded ~= nil and rt.loaded ~= loaded then
            U.Debug("tracker '%s' %s", tracker.name, loaded and "shown (load conditions met)" or ("hidden: " .. tostring(reason)))
        end
        rt.loaded, rt.reason = loaded, reason
        -- what would happen without sample data (the editor's list shows this, not the preview state)
        if test then rt.realLoaded, rt.realReason = Load.Check(tracker, ctx)
        else rt.realLoaded, rt.realReason = loaded, reason end
        if not loaded then
            rt.count = 0
            if display then display:Hide() end
        else
            loadedCount = loadedCount + 1
            if rt.labelFor ~= tracker.name then rt.labelFor, rt.label = tracker.name, "tracker '" .. tracker.name .. "'" end
            local shown = U.SafeCall(rt.label, Engine.EvaluateTracker, tracker, now, ctx, test) or {}
            rt.count = #shown
            totalStates = totalStates + #shown
            if ctx.inCombat and not test then
                rt.combatTime = rt.combatTime + dt
                for _, s in ipairs(shown) do
                    -- a cooldown isn't uptime (the effect itself is over)
                    if s.active and not s.cooldown then rt.activeTime = rt.activeTime + dt; break end
                end
            end
            rt.uptime = rt.combatTime > 0 and (rt.activeTime / rt.combatTime * 100) or nil
            if display then display:Render(tracker, shown, now, ctx, rt, test) end
        end
    end

    T.EndUpdate()
    DT.Quickslot.Apply(now)
    local ms = GetGameTimeMilliseconds() - t0
    local st = Engine.stats
    st.ticks = st.ticks + 1
    st.avgMs = st.avgMs * 0.95 + ms * 0.05
    if ms > st.maxMs then st.maxMs = ms end
    st.states, st.loaded = totalStates, loadedCount
end

-- Run a tick on the next frame (after a burst of events or an edit) instead of waiting up to 100ms.
local updateQueued = false
function Engine.RequestUpdate()
    if updateQueued then return end
    updateQueued = true
    EVENT_MANAGER:RegisterForUpdate(NS .. "_Soon", 0, function()
        EVENT_MANAGER:UnregisterForUpdate(NS .. "_Soon")
        updateQueued = false
        Engine.Tick()
    end)
end

function Engine.RequestRebuildLoad()
    Engine.RequestUpdate()
end

-- How often the engine re-evaluates every tracker (load conditions, rules, which entries show). Bars and timer
-- numbers move every frame on their own (Display:Animate) unless "smooth" is off; game events still update at once
-- (RequestUpdate). Matthis (5.21.23) asked about the "ms per update": slower updates = less CPU per second.
function Engine.UpdateMs()
    local ms = tonumber(DT.Profiles.Settings().updateMs) or TICK_MS
    return math.max(Engine.MIN_MS, math.min(Engine.MAX_MS, math.floor(ms + 0.5)))
end

function Engine.Start()
    -- Always registered (an unloaded tracker returns early); never toggled with combat state.
    EVENT_MANAGER:UnregisterForUpdate(NS)
    EVENT_MANAGER:RegisterForUpdate(NS, Engine.UpdateMs(), Engine.Tick)
end
Engine.SetUpdateRate = Engine.Start

function Engine.ResetStats()
    Engine.stats.maxMs = 0
end
