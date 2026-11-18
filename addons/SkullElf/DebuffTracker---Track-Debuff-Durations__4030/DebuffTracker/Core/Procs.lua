-- "My procs": the built-in proc catalogue (Data/Procs.lua) turned into live timers.
--
-- A "My procs" tracker shows every catalogue proc you have right now: gear procs when the FULL set is
-- equipped (both weapon bars count, a two-hander counts as two pieces), and the synergies, class
-- passives and champion skills you picked (champion skills only while slotted). Each entry is an
-- ability timer with an active part, a cooldown and "ready" (Core/Combat.lua does the timing; each
-- entry runs as a light proxy tracker with its own id "<tracker id>#p:<key>").
--
-- Which set is which: LibSets (optional dependency) gives every set's English name by set ID, in any
-- game language. Without LibSets only the sets whose set ID the built-in catalogue knows are recognised
-- (synergies, passives and champion skills always are); the editor says so.

local DT = DebuffTracker
local P = DT.Procs
local U = DT.Util
local C = DT.Const
local G = DT.Gear
local proxies = setmetatable({}, { __mode = "k" })     -- [tracker] = { [entry key] = proxy } (P.Proxy)

P.byKey = {}
P.list = {}
local indexed = false
local version = 0            -- bumped when gear / champion skills / settings change

local function Norm(name)
    name = U.Lower(U.CleanName(name or ""))
    name = name:gsub("\226\128\153", "'")          -- typographic apostrophe
    name = name:gsub("^perfected ", ""):gsub("^perfect ", "")
    return name
end
P.Norm = Norm

local function Index()
    if indexed then return end
    indexed = true
    for i, e in ipairs(DT.ProcData or {}) do
        e.idx = i
        P.byKey[e.k] = e
        P.list[#P.list + 1] = e
        e.norm = Norm(e.name or e.k)      -- the set's real name (a few keys are misspelt in Cooldowns' data)
    end
end

function P.Get(key) Index() return P.byKey[key] end
function P.All() Index() return P.list end

function P.IsGear(e) return C.GEAR_PROC_KINDS[e.t] == true end

function P.HasLibSets()
    local libSets = rawget(_G, "LibSets")
    return type(libSets) == "table" and type(libSets.GetSetName) == "function"
end

local function ClientIsEnglish()
    if type(GetCVar) ~= "function" then return true end
    local lang = GetCVar("language.2")
    return lang == nil or lang == "" or lang == "en"
end

-- English name of a set, normalised (nil without LibSets); cached until the gear changes
local englishCache = {}
local function EnglishName(setId)
    local cached = englishCache[setId]
    if cached ~= nil then return cached or nil end
    local name
    if P.HasLibSets() then
        local ok, n = pcall(LibSets.GetSetName, setId, "en")
        if ok and type(n) == "string" and n ~= "" then name = n end
    end
    englishCache[setId] = name and Norm(name) or false
    return englishCache[setId] or nil
end

-- Is a full set with one of these English names worn? (load condition "only with this set worn")
-- true / false, or nil when it can't be told (a full set is worn whose English name is unknown: no
-- LibSets on a non-English client) -- then the tracker isn't hidden on a guess.
function P.FullSetWornByName(names)
    local want = {}
    for _, n in ipairs(names or {}) do want[Norm(n)] = true end
    local unknown = false
    for setId in pairs(G.max) do
        if G.IsFull(setId) then
            local en = EnglishName(setId)
            if not en and ClientIsEnglish() and G.names[setId] then en = Norm(G.names[setId]) end
            if en then
                if want[en] then return true end
            else
                unknown = true
            end
        end
    end
    if unknown then return nil end
    return false
end

-- Is this gear proc's full set worn? Returns true + set ID, or false (always false without LibSets).
-- Normal and perfected versions are different set IDs with the same name ("Perfected " ignored).
function P.HasFull(e)
    -- set IDs known (from ExoY's ProcSet Timer, which matches gear by set ID): no LibSets needed, any language
    if e.sets then
        for _, setId in ipairs(e.sets) do
            if G.IsFull(setId) then return true, setId end
        end
        if not P.HasLibSets() then return false end
    end
    if not P.HasLibSets() then return false end
    for setId in pairs(G.max) do
        if G.IsFull(setId) and EnglishName(setId) == e.norm then return true, setId end
    end
    return false
end

-- Is the worn full set of this gear proc the Perfected version? (different numbers, e.g. Bahsei's
-- Mania: up to 15% normal, 12% perfected)
function P.IsPerfected(e)
    local full, setId = P.HasFull(e)
    if not full then return false end
    if e.perfSets then
        for _, id in ipairs(e.perfSets) do if id == setId then return true end end
        if e.sets then for _, id in ipairs(e.sets) do if id == setId then return false end end end
    end
    if not P.HasLibSets() then return false end
    local ok, n = pcall(LibSets.GetSetName, setId, "en")
    return ok and type(n) == "string" and U.Lower(n):find("^perfect") ~= nil
end

-- A proc's buff on you and on your group (Roaring Opportunist's Major Slayer): seconds left on you
-- (nil when you don't have it) and how many OTHER group members have it from you.
function P.BuffInfo(ids, now)
    local want = {}
    for _, id in ipairs(ids) do want[id] = true end
    local left
    for _, x in ipairs(DT.Effects.Scan("player", now)) do
        if (want[x.abilityId] or want[x.baseId]) and x.finish > now then
            left = math.max(left or 0, x.finish - now)
        end
    end
    local allies = 0
    for _, tag in ipairs(DT.Units.GroupTags(false)) do
        if not AreUnitsEqual(tag, "player") then
            for _, x in ipairs(DT.Effects.Scan(tag, now)) do
                if x.mine and (want[x.abilityId] or want[x.baseId]) and (x.finish <= x.begin or x.finish > now) then
                    allies = allies + 1
                    break
                end
            end
        end
    end
    return left, allies
end

-- Jorvuld's Guidance (full set): +40% to several Major / Minor buff durations
function P.HasJorvuld()
    local j = DT.ProcJorvuld
    if not j then return false end
    -- by set ID first (ExoY's InitiateJorvulds checks set 346), then by name through LibSets
    for _, setId in ipairs(j.sets or { 346 }) do
        if G.IsFull(setId) then return true end
    end
    if not P.HasLibSets() then return false end
    local norm = Norm(j.name)
    for setId in pairs(G.max) do
        if EnglishName(setId) == norm and G.IsFull(setId) then return true end
    end
    return false
end

function P.DisplayName(e)
    if P.IsGear(e) then
        local _, setId = P.HasFull(e)
        if setId and G.names[setId] and not ClientIsEnglish() then
            -- a second entry of the same set (Sul-Xan's soul): the set name + the effect's own name
            if e.label then return G.names[setId] .. ": " .. U.CleanName(GetAbilityName(e.ids[1]) or "") end
            return G.names[setId]
        end
        return e.label or e.name or e.k
    end
    if ClientIsEnglish() then return e.k end
    local n = U.CleanName(GetAbilityName(e.ids[1]) or "")
    return n ~= "" and n or e.k
end

-- setIcon (gear procs): the set's own icon (its head piece / weapon). Sets without a look of their
-- own (crafted / overland: only a default racial piece) use the piece you're wearing, which shows
-- your style. Otherwise the proc's effect icon.
function P.Icon(e, setIcon)
    if setIcon and P.IsGear(e) then
        if e.setIcon and not e.setIconGeneric then return e.setIcon end
        local full, setId = P.HasFull(e)
        if full and G.icons[setId] then return G.icons[setId] end
        if e.setIcon then return e.setIcon end
    end
    if e.icon and e.icon ~= "" then return e.icon end
    local icon = e.ids[1] and GetAbilityIcon(e.ids[1])
    return (icon and icon ~= "") and icon or C.DEFAULT_ICON
end

------------------------------------------------------------------------------
-- Calculated values ("seconds of Major Slayer from your ultimate", "weapon damage from missing
-- stamina"). mode "missing": scalar / start * min(start - pct, start - cap), never below 0.
-- mode "divide": pct / div (x scale).
------------------------------------------------------------------------------

function P.Calc(mode, pct, a)
    if mode == "missing" then
        local start, cap, scalar = a.start or 100, a.cap or 0, a.scalar or 0
        local missing = math.min(start - pct, start - cap)
        return math.max(0, scalar / start * missing)
    elseif mode == "divide" then
        return pct / math.max(0.01, a.div or 1) * (a.scale or 1)
    end
    return pct
end

function P.CalcText(mode, value, decimals)
    if mode == "divide" then
        if value < 1 then return "" end
        return string.format("%." .. (decimals or 1) .. "f", value)
    end
    return tostring(math.floor(value))
end

------------------------------------------------------------------------------
-- Which catalogue entries a "My procs" tracker has right now
------------------------------------------------------------------------------

local function ListSet(list)
    local s = {}
    for _, k in ipairs(list or {}) do s[k] = true end
    return s
end

-- returns { {entry = e, available = true} ... } (what the tracker shows right now)
local candCache = setmetatable({}, { __mode = "k" })
function P.Candidates(tr)
    local cached = candCache[tr]
    if cached and cached.version == version and cached.gear == G.version then return cached.list end
    local hidden, picked, off = ListSet(tr.procHidden), ListSet(tr.procPicked), ListSet(tr.procKindsOff)
    local only = #tr.procOnly > 0 and ListSet(tr.procOnly) or nil
    if only then hidden, picked, off = {}, only, {} end
    local slottedCp = DT.Load.ChampionSlotted()
    local out = {}
    for _, e in ipairs(P.All()) do
        if not hidden[e.k] and (not only or only[e.k]) then
            if P.IsGear(e) then
                if not off[e.t] and P.HasFull(e) then out[#out + 1] = { entry = e, available = true } end
            elseif picked[e.k] then
                if e.t ~= "champion" or (e.cp and slottedCp[e.cp]) then
                    out[#out + 1] = { entry = e, available = true }
                end
            end
        end
    end
    candCache[tr] = { version = version, gear = G.version, list = out }
    return out
end

function P.Invalidate() version = version + 1 end

-- Trigger of the ability timer that runs one catalogue entry.
-- gameDur: the active part is the buff's duration in the game (GetAbilityDuration), like ExoY's ProcSet
-- Timer -- always for entries taken from ExoY (gd), for every timed entry with "Buff times from the game".
function P.GameDuration(e)
    if e.on == "effect" or e.count or e.on == "power" or type(GetAbilityDuration) ~= "function" then return 0 end
    local ms = tonumber(GetAbilityDuration((e.ids or {})[1] or 0)) or 0
    return ms > 0 and ms / 1000 or 0
end

function P.TimerTrigger(e, gameDur)
    local d, cd = e.d or 0, e.cd or 0
    if (e.gd or gameDur) and not e.untilFaded then
        local g = P.GameDuration(e)
        if g > 0 then d = g end
    end
    if d <= 0 and cd <= 0 and e.on ~= "effect" and not e.count then d = 1 end
    -- Cooldowns shows a buff's cooldown only from its cooldown event (cooldownTrigger), never cooldownDurationMs
    local cdShown = e.on == "effect" and 0 or cd
    return {
        type = "combat", abilityIds = e.ids, names = {},
        combatSource = e.src or "me", combatResult = e.r or (e.gd and "proc") or "gained",   -- (ExoY: effect or direct hit)
        duration = d, cooldown = cdShown, startOn = e.on == "effect" and "effect" or "combat",
        cooldownIds = e.cdIds or {}, endIds = e.endIds or {},
        perTarget = false, restartOnRefresh = true, minInterval = 0.5, showReady = true,
        -- Cooldowns restarts a proc on every new event, also during its cooldown; only `lock` entries ignore events
        -- while their cooldown runs (Combat.lua: Pillager's late group events are the same proc)
        cdLock = (e.lock and cd > 0) or nil,
        endResult = e.endResult,
        count = e.count or nil,
        durationFromHit = e.hitDuration or nil,
        burst = e.burst or nil,
        untilFaded = e.untilFaded or nil,
    }
end

------------------------------------------------------------------------------
-- Players who have a proc's buff from you right now -- you included, like ExoY's ProcSet Timer counts
-- "affected" players: effect events filtered to YOU as the source (the way Fancy Action Bar+ counts
-- Echoing Vigor targets), one entry per unit, dropped when it fades or runs out. Catalogue field `targets` = the buff's ability IDs (Roaring Opportunist's Major
-- Slayer is 135923 -- LuiExtended lists it as Major Slayer).
------------------------------------------------------------------------------
P.targets = {}          -- [abilityId] = { [unitId] = end time (s) }
-- A catalogue entry with startFromTargets also STARTS its timer when you give one of its target buffs to
-- someone (Pillager's Profit: the Ultimate it hands out to your group, 172055 -- HodorReflexes tracks it that
-- way; the 172056 combat event Cooldowns / ExoY wait for never came in game).
local function StartFromTarget(e, abilityId)
    local Engine = DT.Engine
    for _, t in ipairs(Engine.trackers or {}) do
        if t.enabled and t.trigger and t.trigger.type == "procs" then
            local p = proxies[t] and proxies[t][e.k]
            if p then DT.Combat.Fire(p.id, abilityId) end
        end
    end
end

-- The listeners only exist while a "My procs" tracker does (5.14.4: nothing registered for a feature
-- nobody uses). InitTargets only prepares them.
local targetIds, starters, targetsOn = {}, {}, false
local allyIds = {}      -- [abilityId] = ttl (s): catalogue `allies` (Spaulder of Ruin's aura)
function P.InitTargets()
    targetIds, starters, allyIds = {}, {}, {}
    for _, e in ipairs(P.All()) do
        for _, id in ipairs(e.targets or {}) do
            targetIds[id] = true
            if e.startFromTargets then starters[id] = starters[id] or {}; table.insert(starters[id], e) end
        end
        if e.allies then allyIds[e.allies.id] = e.allies.ttl or 2.1 end
    end
    if targetsOn then targetsOn = false; P.SetTargetWatching(true) end
end

-- Allies you're giving a pulsing aura to (Cooldowns' Spaulder of Ruin, Tracking.lua OnSpaulder): every combat event
-- of the aura from you on someone else counts them for ttl s after it (Cooldowns: 2.1 s, swept every 2 s). Events
-- on you don't count. Only listened to while a "My procs" tracker exists, like the targets above.
P.allies = {}           -- [abilityId] = { [unitId] = until (s) }
local function SetAllyWatching(on)
    for id in pairs(allyIds) do
        local ns = "DebuffTracker5_Allies_" .. id
        EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
        if on then
            local ttl = allyIds[id]
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT,
                function(_, result, isError, _, _, _, _, _, _, targetType, _, _, _, _, _, targetUnitId)
                    if isError or not targetUnitId or targetUnitId == 0 then return end
                    if targetType == COMBAT_UNIT_TYPE_PLAYER then return end
                    if result ~= ACTION_RESULT_EFFECT_GAINED and result ~= ACTION_RESULT_EFFECT_GAINED_DURATION then return end
                    local list = P.allies[id]
                    if not list then list = {}; P.allies[id] = list end
                    list[targetUnitId] = U.Now() + ttl
                    if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
                end)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
    end
    if not on then P.allies = {} end
end

function P.AllyCount(a, now)
    local list = P.allies[a.id]
    local n = 0
    if not list then return 0 end
    for unitId, untilT in pairs(list) do
        if untilT > now then n = n + 1 else list[unitId] = nil end
    end
    return math.min(n, a.max or n)
end

-- A loading screen to another map turns a toggled aura off in game (Cooldowns: Spaulder's EVENT_PLAYER_ACTIVATED --
-- off unless the map and the character are the same; ExoY: off on any zone change). Entries with offOnTravel end.
local lastMap, lastChar
function P.OnActivated()
    local map = type(GetMapName) == "function" and GetMapName() or ""
    local char = type(GetUnitName) == "function" and GetUnitName("player") or ""
    local same = lastMap ~= nil and map == lastMap and char == lastChar
    lastMap, lastChar = map, char
    if same then return end
    P.allies = {}
    local Engine = DT.Engine
    for _, t in ipairs((Engine and Engine.trackers) or {}) do
        local list = proxies[t]
        if list then
            for _, p in pairs(list) do
                if p.entry and p.entry.offOnTravel then
                    local timers = DT.Combat.timers[p.id]
                    if timers then timers[0] = nil end
                end
            end
        end
    end
    if Engine and Engine.RequestUpdate then Engine.RequestUpdate() end
end

function P.SetTargetWatching(on)
    on = on == true
    if on == targetsOn then return end
    targetsOn = on
    for id in pairs(targetIds) do
        local ns = "DebuffTracker5_Targets_" .. id
        EVENT_MANAGER:UnregisterForEvent(ns, EVENT_EFFECT_CHANGED)
        if on then
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_EFFECT_CHANGED,
                function(_, change, _, _, unitTag, _, endTime, _, _, _, _, _, _, _, unitId, abilityId)
                    if not unitId or unitId == 0 then return end
                    local list = P.targets[id]
                    if not list then list = {}; P.targets[id] = list end
                    if change == EFFECT_RESULT_FADED then
                        list[unitId] = nil
                    else
                        list[unitId] = (tonumber(endTime) or 0) > 0 and endTime or (U.Now() + 30)
                        if change == EFFECT_RESULT_GAINED and starters[id] then
                            for _, e in ipairs(starters[id]) do StartFromTarget(e, abilityId or id) end
                        end
                    end
                    if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
                end)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
    end
    if not on then P.targets = {} end
    SetAllyWatching(on)
end

function P.TargetCount(ids, now)
    local seen, n = {}, 0
    for _, id in ipairs(ids) do
        for unitId, finish in pairs(P.targets[id] or {}) do
            if finish > now then
                if not seen[unitId] then seen[unitId] = true; n = n + 1 end
            else
                P.targets[id][unitId] = nil
            end
        end
    end
    return n
end

-- Roaring Opportunist: how long Major Slayer would last if it procced now -- 1 s per 600 Spell Damage or
-- per 6300 Magicka (whichever gives more), at most 12 s; Jorvuld's Guidance makes it 40% longer.
-- How long Major Slayer would last if Roaring Opportunist procced now. The GAME computes it from your
-- stats: GetAbilityDuration(135923) (ms) -- that's what ExoY's ProcSet Timer shows (special/opportunist.lua).
-- Jorvuld's Guidance isn't in that number any more (ExoY's own note), so x1.4 is added here. Fallback
-- without the API: the tooltip formula (1 s per 600 Spell Damage or 6300 Magicka, max 12 s).
-- Recomputed at most every 2 seconds (Tony: no need to do it every frame).
local slayerCache = { at = -1000, value = nil, full = false }
function P.SlayerDuration(e)
    local f = e.slayer
    if not f then return nil end
    local now = U.Now()
    if now - slayerCache.at < 2 and slayerCache.value then return slayerCache.value, slayerCache.full end
    local base
    if type(GetAbilityDuration) == "function" then
        local ms = tonumber(GetAbilityDuration(f.id or e.ids[1])) or 0
        if ms > 0 then base = ms / 1000 end
    end
    if not base then
        local sd = (type(GetPlayerStat) == "function" and STAT_SPELL_POWER) and (GetPlayerStat(STAT_SPELL_POWER) or 0) or 0
        local _, mag = GetUnitPower("player", POWERTYPE_MAGICKA)
        base = math.min(f.cap, math.max(sd / f.sd, (mag or 0) / f.mag))
    end
    local full = base >= f.cap - 0.05
    local v = base * (P.HasJorvuld() and 1.4 or 1)
    slayerCache.at, slayerCache.value, slayerCache.full = now, v, full
    return v, full
end

-- Proxy trackers (one per timed entry) for Combat.SetRequirements; stable ids keep running timers.
function P.Proxy(tracker, e)
    local list = proxies[tracker]
    if not list then list = {}; proxies[tracker] = list end
    local p = list[e.k]
    local gameDur = tracker.trigger and tracker.trigger.procGameDurations == true or false
    if not p or p.gameDur ~= gameDur then
        p = { id = tracker.id .. "#p:" .. e.k, trigger = P.TimerTrigger(e, gameDur), entry = e, gameDur = gameDur }
        list[e.k] = p
    end
    p.durationScale = (e.jorvuld and P.HasJorvuld()) and 1.4 or 1
    return p
end

function P.Proxies(tracker)
    local out = {}
    for _, c in ipairs(P.Candidates(tracker.trigger)) do
        if c.entry.on ~= "power" then out[#out + 1] = P.Proxy(tracker, c.entry) end
    end
    return out
end

-- Gear or champion skills changed: re-check what every "My procs" tracker has.
function P.OnLoadoutChanged()
    version = version + 1
    englishCache = {}
    if DT.Engine.RefreshCombat then DT.Engine.RefreshCombat() end
end

------------------------------------------------------------------------------
-- Catalogue entry -> tracker settings (editor: "Own tracker", "Fill from the proc catalogue")
------------------------------------------------------------------------------

-- Copy an entry's timing into an ability-timer trigger (in place).
function P.FillTrigger(tr, e)
    local src = P.TimerTrigger(e)
    tr.type = "combat"
    tr.abilityIds = U.Copy(e.ids)
    tr.combatSource, tr.combatResult = src.combatSource, src.combatResult
    tr.duration, tr.cooldown, tr.startOn = src.duration, src.cooldown, src.startOn
    tr.cooldownIds, tr.endIds = U.Copy(src.cooldownIds), U.Copy(src.endIds)
    tr.count = e.count == true
    tr.durationFromHit = e.hitDuration == true
    tr.perTarget, tr.restartOnRefresh, tr.minInterval, tr.showReady = false, true, 0.5, true
    return tr
end

-- A standalone tracker for one catalogue entry: a "My procs" tracker limited to that entry, so it
-- keeps everything the catalogue does (full-set detection, Jorvuld's Guidance, calculated values,
-- champion skill slotted). Same look as `display`.
function P.TrackerFor(e, display)
    local t = { name = P.DisplayName(e), iconOverride = P.Icon(e), display = U.Copy(display or { type = "icons" }), load = {} }
    t.display.title = ""
    t.display.showHeader = false
    t.trigger = { type = "procs", procOnly = { e.k } }
    return t
end

-- Search the catalogue by name (case-insensitive, any part); `max` results.
function P.Search(text, max)
    local q = Norm(text)
    local out = {}
    for _, e in ipairs(P.All()) do
        if q == "" or e.norm:find(q, 1, true) or U.Lower(P.DisplayName(e)):find(q, 1, true) then
            out[#out + 1] = e
            if max and #out >= max then break end
        end
    end
    return out
end
