-- =============================================================================
-- Under Pressure -- Engine/PullTracker.lua (0.4.2, caster-side route 0.5.11)
-- =============================================================================
-- Detects an incoming pull on the player before it lands and tells
-- UI/PullIndicator how long the warning should stay up. One switch
-- (sv.pull_detect, default OFF) covers every pull this module knows about,
-- including the scribing pull Leashing Burst since 0.5.11 (see
-- CAST_ABILITY_IDS and OnCasterEffect below, and Engine/Allegiance.lua for
-- how a caster with no unit tag is told friend from foe).
--
-- WHAT IS DETECTED, AND HOW (research in Docs/PullDetection-*.md, 2026-10-29):
--
--   RUSH OF AGONY (set). The set stamps a wind-up effect on each enemy it is
--   about to pull, ~0.8 s before the pull. On the victim's client that
--   arrives as an EVENT_COMBAT_EVENT with result ACTION_RESULT_EFFECT_GAINED
--   or _GAINED_DURATION, target = player, source = the wearer, abilityId
--   159279 or 160184, and hitValue = the wind-up in ms. This is exactly how
--   Miat's PvP Alerts raises "BLOCK - AGONY PULL". Those two results are
--   undocumented (see CLAUDE.md, "Combat enums at API 101051") and unverified
--   on console, so EVENT_EFFECT_CHANGED GAINED on the player with the same
--   ids is accepted as a documented fallback, with endTime as the lead.
--
--   DARK CONVERGENCE (set). The area snares on appearance, pulls and stuns
--   1 s later, and deals damage at 4 s. The snare is a debuff on the victim,
--   so it arrives as ACTION_RESULT_SNARED (documented) or as the effect-gained
--   family, with abilityId 159386, 159387, 159391 or 160317 (LuiData's AoE
--   table; which one is the snare is not yet known, so all four are
--   watched). Lead 1 s. STUNNED from the same ids is accepted too: it is the
--   pull itself, and the 1642 damage is still 3 s away.
--
-- Only the pre-pull signals are accepted. Damage results from these ids are
-- ignored on purpose: by then the pull has happened and a warning is noise.
--
-- NOTHING EXTRA IS REGISTERED. The main EVENT_COMBAT_EVENT registration in
-- EventIngest is filtered target = player and carries every result, so the
-- snare/effect events already arrive there; this module is one call in that
-- handler and one in the effect handler, each a fast exit while the switch is
-- off. No ability-id channels, no per-tick work.
--
-- A warning EXTENDS rather than stacks: each accepted event moves the deadline
-- to max(deadline, now + lead), so standing in a Dark Convergence keeps the
-- indicator up while the snare keeps re-applying, and a second Rush of Agony
-- marker simply refreshes it.
-- =============================================================================

UP = UP or {}
UP.Pull = {}

-- ---------------------------------------------------------------------------
-- Sets and ids
-- ---------------------------------------------------------------------------
UP.Pull.SETS = {
    agony       = { name = "Rush of Agony",    leadMs = 800,  match = "agony" },
    convergence = { name = "Dark Convergence", leadMs = 1000, match = "convergence" },
}

UP.Pull.ABILITY_IDS = {
    [159279] = "agony",        -- "Rush Of Agony (New)" in Miat's PvP Alerts
    [160184] = "agony",        -- "Rush Of Agony"
    [159386] = "convergence",  -- LuiData aoePlayerSet, priority 1
    [159387] = "convergence",  -- LuiData aoePlayerSet, priority 1
    [159391] = "convergence",  -- LuiData aoePlayerSet, priority 0 (same source)
    [160317] = "convergence",  -- LuiData aoePlayerSet, priority 0 (same source)
}
UP.Pull.SETS.leash = { name = "Leashing Burst", leadMs = 2000, match = "leashing" }

-- CASTER-SIDE ids (0.5.11). Leashing Burst (Soul Burst + the Pull focus
-- script) puts a 2.0 s buff on its CASTER, and the client delivers that buff
-- to every nearby client through EVENT_EFFECT_CHANGED with an EMPTY unit tag
-- and the caster's name (Matt's recording, Cyrodiil, 2026-11-01; see
-- Docs/PullDetection-LeashingBurst.md). EventIngest registers one
-- EVENT_EFFECT_CHANGED per id here, filtered by REGISTER_FILTER_ABILITY_ID
-- only, while the switch is on. Kept apart from ABILITY_IDS so the player's
-- OWN Leashing Burst (unit tag "player") never reaches OnEffect.
UP.Pull.CAST_ABILITY_IDS = {
    [217979] = "leash",        -- "Leashing Burst" buff on the caster, 2.0 s
}

-- A lead carried by the event (Rush of Agony's hitValue, or an effect's
-- endTime) is trusted only inside this window; anything else uses the set's
-- default. Miat's uses the same bounds.
local LEAD_MIN_MS, LEAD_MAX_MS = 200, 5000

-- ---------------------------------------------------------------------------
-- Constants, nil-safe (console drops aliases; the effect family is undocumented)
-- ---------------------------------------------------------------------------
local UNIT_PLAYER = (type(COMBAT_UNIT_TYPE_PLAYER) == "number") and COMBAT_UNIT_TYPE_PLAYER or 1

-- Sources that cannot be pulling us.
local FRIENDLY = {}
for _, v in ipairs({ COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP,
                     COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_PLAYER_COMPANION }) do
    if type(v) == "number" then FRIENDLY[v] = true end
end
if next(FRIENDLY) == nil then FRIENDLY[UNIT_PLAYER] = true end

local EFFECT_RESULTS = {}
for _, v in ipairs({ ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_GAINED_DURATION }) do
    if type(v) == "number" then EFFECT_RESULTS[v] = true end
end

-- Pre-pull results accepted per set. Rush of Agony has only its marker;
-- Dark Convergence also has the documented snare, and the stun (the pull
-- itself, still 3 s ahead of the damage).
local ACCEPTED = { agony = {}, convergence = {} }
for r in pairs(EFFECT_RESULTS) do ACCEPTED.agony[r] = true; ACCEPTED.convergence[r] = true end
for _, v in ipairs({ ACTION_RESULT_SNARED, ACTION_RESULT_STUNNED }) do
    if type(v) == "number" then ACCEPTED.convergence[v] = true end
end

local GAINED = (type(EFFECT_RESULT_GAINED) == "number") and EFFECT_RESULT_GAINED or 1
local UPDATED = (type(EFFECT_RESULT_UPDATED) == "number") and EFFECT_RESULT_UPDATED or 3

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local untilMs = 0          -- warning deadline (GetGameTimeMilliseconds clock), 0 = none
local activeSet = nil      -- "agony" / "convergence" while a warning is up
local activeSource = nil   -- wearer's name when the event carried one
local triggerCount = 0
-- Caster-side channel (0.5.11): how it is registered, and what it has seen.
local castChannel = "off"  -- "abilityId" | "unavailable" | "off"; set by EventIngest
local castSeen, castWarned, castAllied, castPvE = 0, 0, 0, 0

-- Where another player can be hostile (0.5.12): Cyrodiil and Imperial City
-- (IsPlayerInAvAWorld) or a battleground. Everywhere else every player is
-- an ally, the allegiance table has nothing to learn from (no kill feed),
-- and a Leashing Burst cast by a friendly player at a world boss would be a
-- false warning; Matt saw exactly that. Duels in PvE zones are the one gap.
local function inPvPArea()
    if type(IsPlayerInAvAWorld) == "function" then
        local ok, v = pcall(IsPlayerInAvAWorld)
        if ok and v then return true end
    end
    if type(IsActiveWorldBattleground) == "function" then
        local ok, v = pcall(IsActiveWorldBattleground)
        if ok and v then return true end
    end
    return false
end
UP.Pull.InPvPArea = inPvPArea

local function nowMs()
    return GetGameTimeMilliseconds()
end

local function enabled()
    return UP.sv ~= nil and UP.sv.pull_detect == true
end

function UP.Pull.Enabled() return enabled() end

local function publish()
    if UP.PullIndicator and UP.PullIndicator.SetActive then
        UP.PullIndicator.SetActive(untilMs > 0, activeSet)
    end
end

local function expireCheck()
    if untilMs > 0 and nowMs() >= untilMs then
        untilMs, activeSet, activeSource = 0, nil, nil
        publish()
    end
end

local function logDebug(setKey, viaWhat, sourceName, leadMs, abilityId)
    if UP.Debug and UP.Debug.Log then
        UP.Debug.Log(("pull %s via %s from=%s lead=%dms id=%s"):format(
            setKey, viaWhat, tostring(sourceName or "?"), leadMs, tostring(abilityId)))
    end
end

local function trigger(setKey, sourceName, leadMs, t, detail)
    triggerCount = triggerCount + 1
    local deadline = t + leadMs
    if deadline > untilMs then untilMs = deadline end
    activeSet = setKey
    if sourceName and sourceName ~= "" then activeSource = sourceName end
    -- History (0.5.12): every warning records why it fired. Resolved at call
    -- time because Record is defined further down the file.
    if UP.Pull.Record then UP.Pull.Record(setKey, sourceName, leadMs, detail) end
    publish()
    -- +50 ms guards an early callback; a surplus callback finds nothing to do.
    if type(zo_callLater) == "function" then
        zo_callLater(expireCheck, leadMs + 50)
    end
end

local function clampLead(candidate, fallback)
    if type(candidate) == "number" and candidate >= LEAD_MIN_MS and candidate <= LEAD_MAX_MS then
        return candidate
    end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Inputs
-- ---------------------------------------------------------------------------
-- From EventIngest's main EVENT_COMBAT_EVENT handler (target = player). The
-- first line is the fast exit normal play pays while the switch is off.
function UP.Pull.OnCombat(result, abilityId, sourceName, sourceType, targetType, hitValue, t)
    if not enabled() then return end
    local setKey = UP.Pull.ABILITY_IDS[abilityId]
    if not setKey then return end
    if targetType ~= nil and targetType ~= UNIT_PLAYER then return end
    if FRIENDLY[sourceType] then return end
    if not ACCEPTED[setKey][result] then return end
    local lead = UP.Pull.SETS[setKey].leadMs
    if EFFECT_RESULTS[result] then
        -- Rush of Agony reports its wind-up here; Dark Convergence's snare
        -- carries its duration, which is longer than the pull lead, so only
        -- the marker's value is taken.
        if setKey == "agony" then lead = clampLead(hitValue, lead) end
    end
    trigger(setKey, sourceName, lead, t or nowMs(), {
        route = "combat", result = result, abilityId = abilityId,
        sourceType = sourceType, targetType = targetType, hitValue = hitValue,
    })
    logDebug(setKey, "combat r=" .. tostring(result), sourceName, lead, abilityId)
end

-- From EventIngest's EVENT_EFFECT_CHANGED handler (unitTag = player). The
-- documented route: works without the effect-gained combat results, at the
-- cost of the wearer's name.
function UP.Pull.OnEffect(changeType, abilityId, endTimeMs, t)
    if not enabled() then return end
    if changeType ~= GAINED then return end
    local setKey = UP.Pull.ABILITY_IDS[abilityId]
    if not setKey then return end
    t = t or nowMs()
    local lead = UP.Pull.SETS[setKey].leadMs
    if setKey == "agony" and type(endTimeMs) == "number" and endTimeMs > t then
        lead = clampLead(endTimeMs - t, lead)
    end
    trigger(setKey, nil, lead, t, {
        route = "effect", changeType = changeType, abilityId = abilityId, endTimeMs = endTimeMs,
    })
    logDebug(setKey, "effect", nil, lead, abilityId)
end

-- From EventIngest's caster-side EVENT_EFFECT_CHANGED registration (0.5.11):
-- a buff gained by SOMEONE ELSE that announces a pull they are about to do.
-- The unit tag is normally empty (a stranger has none); "player" or a group
-- tag means it is us or a groupmate casting, which cannot pull us. For
-- everyone else the allegiance table decides: a known friend is ignored, a
-- known foe or an unknown warns, because an ally's cast is a false alarm at
-- worst and an enemy's is the whole point. endTime (ms) carries the real
-- lead when it is sane; the set default otherwise. Outside Cyrodiil,
-- Imperial City and battlegrounds nothing warns (0.5.12, see inPvPArea).
function UP.Pull.OnCasterEffect(changeType, abilityId, unitTag, unitName, sourceType, endTimeMs, t)
    if not enabled() then return end
    local setKey = UP.Pull.CAST_ABILITY_IDS[abilityId]
    if not setKey then return end
    if changeType ~= GAINED and changeType ~= UPDATED then return end
    castSeen = castSeen + 1
    if not inPvPArea() then
        castPvE = castPvE + 1
        return
    end
    if unitTag == "player" or FRIENDLY[sourceType]
       or (type(unitTag) == "string" and unitTag:sub(1, 5) == "group") then
        castAllied = castAllied + 1
        return
    end
    local verdict = "unknown"
    if UP.Allegiance and UP.Allegiance.Classify then
        verdict = UP.Allegiance.Classify(unitName, sourceType)
    end
    local shown = (UP.Allegiance and UP.Allegiance.CleanName and UP.Allegiance.CleanName(unitName)) or unitName
    if verdict == "friend" then
        castAllied = castAllied + 1
        if UP.Debug and UP.Debug.Log then
            UP.Debug.Log(("pull %s cast by ally %s ignored"):format(setKey, tostring(shown or "?")))
        end
        return
    end
    t = t or nowMs()
    local lead = UP.Pull.SETS[setKey].leadMs
    if type(endTimeMs) == "number" and endTimeMs > t then
        lead = clampLead(endTimeMs - t, lead)
    end
    castWarned = castWarned + 1
    trigger(setKey, shown, lead, t, {
        route = "cast", verdict = verdict, changeType = changeType, abilityId = abilityId,
        sourceType = sourceType, unitTag = unitTag, endTimeMs = endTimeMs,
    })
    logDebug(setKey, "cast(" .. verdict .. ")", shown, lead, abilityId)
end

function UP.Pull.SetCastChannel(mode) castChannel = mode or "off" end
function UP.Pull.CastChannel() return castChannel end

-- One overlay line: the channel, the counts, and the allegiance table's state.
function UP.Pull.CastSummary()
    local a = (UP.Allegiance and UP.Allegiance.Summary) and UP.Allegiance.Summary() or ""
    return ("pullCast=%s seen=%d warned=%d allies=%d pve=%d %s  %s"):format(
        castChannel, castSeen, castWarned, castAllied, castPvE,
        inPvPArea() and "[pvp area]" or "[pve area]", a)
end

-- Death, zone change, anything that makes a pending warning meaningless.
function UP.Pull.Clear()
    untilMs, activeSet, activeSource = 0, nil, nil
    publish()
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------
function UP.Pull.IsActive(t)
    return untilMs > 0 and (t or nowMs()) < untilMs
end

function UP.Pull.RemainingMs(t)
    if untilMs <= 0 then return 0 end
    local r = untilMs - (t or nowMs())
    if r < 0 then return 0 end
    return r
end

function UP.Pull.ActiveSet() return activeSet end
function UP.Pull.ActiveSource() return activeSource end

function UP.Pull.Snapshot()
    return { untilMs = untilMs, set = activeSet, source = activeSource, triggers = triggerCount,
             castChannel = castChannel, castSeen = castSeen, castWarned = castWarned,
             castAllied = castAllied, castPvE = castPvE }
end

-- Are the pre-pull combat results for Rush of Agony present at all? (On
-- console they may not be; the effect-changed fallback then carries it.)
function UP.Pull.AgonyResultsAvailable()
    return next(EFFECT_RESULTS) ~= nil
end

-- ---------------------------------------------------------------------------
-- Id verification (reporting only, like the plague tracker's)
-- ---------------------------------------------------------------------------
local function abilityDisplay(name)
    if type(zo_strformat) == "function" and SI_ABILITY_NAME then
        local ok, s = pcall(zo_strformat, SI_ABILITY_NAME, name)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return tostring(name or "?")
end

-- ---------------------------------------------------------------------------
-- History (0.5.12): why each warning fired, last 20, newest first
-- ---------------------------------------------------------------------------
-- Matt saw the indicator fire in PvE and wanted to know why. Every accepted
-- event records a row in sv.pull_history: the set, the route it came in on
-- (combat result, effect on us, or a caster's buff and how the caster was
-- judged), the source's name and unit type, the ability id and its live
-- name, the lead, and the zone. The Settings panel shows the rows at the
-- bottom of the Pull Indicator page, newest first, with a Clear button, the
-- same way the Plague Indicator page shows its reports.
UP.Pull.HISTORY_MAX = 20

-- Names for the numbers in a row, nil-safe; a value with no name shows as
-- the number alone. Known names are indexed, never walked (no pairs(_G)).
local RESULT_NAMES = {}
for _, n in ipairs({ "ACTION_RESULT_EFFECT_GAINED", "ACTION_RESULT_EFFECT_GAINED_DURATION",
                     "ACTION_RESULT_SNARED", "ACTION_RESULT_STUNNED" }) do
    if type(_G[n]) == "number" then RESULT_NAMES[_G[n]] = n:sub(15) end
end
local UNIT_TYPE_NAMES = {}
for _, n in ipairs({ "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_GROUP", "COMBAT_UNIT_TYPE_OTHER",
                     "COMBAT_UNIT_TYPE_PLAYER_PET", "COMBAT_UNIT_TYPE_PLAYER_COMPANION",
                     "COMBAT_UNIT_TYPE_TARGET_DUMMY", "COMBAT_UNIT_TYPE_NONE" }) do
    if type(_G[n]) == "number" then UNIT_TYPE_NAMES[_G[n]] = n:sub(18):lower() end
end
local CHANGE_NAMES = {}
for _, n in ipairs({ "EFFECT_RESULT_GAINED", "EFFECT_RESULT_UPDATED", "EFFECT_RESULT_FADED" }) do
    if type(_G[n]) == "number" then CHANGE_NAMES[_G[n]] = n:sub(15):lower() end
end

local function named(v, names)
    if v == nil then return "?" end
    local n = names[v]
    return n and (tostring(v) .. " " .. n) or tostring(v)
end

local function zoneName()
    if type(GetPlayerActiveZoneName) == "function" then
        local ok, z = pcall(GetPlayerActiveZoneName)
        if ok and type(z) == "string" and z ~= "" then return z end
    end
    if type(GetUnitZone) == "function" then
        local ok, z = pcall(GetUnitZone, "player")
        if ok and type(z) == "string" and z ~= "" then return z end
    end
    return "?"
end

local function liveAbilityName(abilityId)
    if type(abilityId) ~= "number" or type(GetAbilityName) ~= "function" then return "?" end
    local ok, name = pcall(GetAbilityName, abilityId)
    if ok and type(name) == "string" and name ~= "" then return abilityDisplay(name) end
    return "?"
end

function UP.Pull.History()
    local sv = UP.sv
    if sv and type(sv.pull_history) == "table" then return sv.pull_history end
    return {}
end

local function markHistoryDirty()
    if UP.Settings and UP.Settings.MarkPullHistoryDirty then UP.Settings.MarkPullHistoryDirty() end
end

-- Called by trigger(). detail is the input's own description of the event.
function UP.Pull.Record(setKey, sourceName, leadMs, detail)
    local sv = UP.sv
    if not sv then return end
    detail = detail or {}
    local set = UP.Pull.SETS[setKey]
    local setName = set and set.name or tostring(setKey)
    local who = (type(sourceName) == "string" and sourceName ~= "") and sourceName or "unknown source"
    local abilityId = detail.abilityId
    local abilityName = liveAbilityName(abilityId)

    local routeShort, routeLong
    if detail.route == "combat" then
        routeShort = "combat r=" .. tostring(detail.result)
        routeLong  = "combat event on you, result " .. named(detail.result, RESULT_NAMES)
                     .. ((type(detail.hitValue) == "number") and (", hitValue " .. tostring(detail.hitValue)) or "")
    elseif detail.route == "effect" then
        routeShort = "effect"
        routeLong  = "effect on you, change " .. named(detail.changeType, CHANGE_NAMES)
    elseif detail.route == "cast" then
        routeShort = "cast(" .. tostring(detail.verdict or "unknown") .. ")"
        routeLong  = "the caster's own buff was seen (unit tag "
                     .. ((detail.unitTag ~= nil and detail.unitTag ~= "") and ('"' .. tostring(detail.unitTag) .. '"') or "empty")
                     .. "), caster judged " .. tostring(detail.verdict or "unknown")
                     .. ", change " .. named(detail.changeType, CHANGE_NAMES)
    else
        routeShort = tostring(detail.route or "?")
        routeLong  = routeShort
    end

    local lines = {
        setName .. " warning",
        "Route: " .. routeLong,
        "From: " .. who .. ((detail.sourceType ~= nil) and (" (source type " .. named(detail.sourceType, UNIT_TYPE_NAMES) .. ")") or ""),
        "Ability: " .. tostring(abilityId or "?") .. " " .. abilityName,
        ("Lead: %d ms"):format(leadMs or 0),
    }
    if detail.targetType ~= nil then
        lines[#lines + 1] = "Target type: " .. named(detail.targetType, UNIT_TYPE_NAMES)
    end
    lines[#lines + 1] = "Zone: " .. zoneName()

    if type(sv.pull_history) ~= "table" then sv.pull_history = {} end
    local h = sv.pull_history
    table.insert(h, 1, {
        stamp = (type(GetTimeStamp) == "function") and GetTimeStamp() or 0,
        time  = (type(GetTimeString) == "function") and GetTimeString() or nil,
        set   = setKey,
        short = ("%s from %s via %s, %.1f s lead"):format(setName, who, routeShort, (leadMs or 0) / 1000),
        text  = table.concat(lines, "\n"),
    })
    while #h > UP.Pull.HISTORY_MAX do table.remove(h) end
    markHistoryDirty()
end

function UP.Pull.ClearHistory()
    if UP.sv then UP.sv.pull_history = {} end
    markHistoryDirty()
end

-- true when every id's live name contains its set's keyword; false when any
-- does not (ids drifted); nil when the API is unavailable. detail lists them.
function UP.Pull.VerifyIds()
    if type(GetAbilityName) ~= "function" then return nil, "GetAbilityName unavailable" end
    local good, parts = true, {}
    local ids = {}
    for id in pairs(UP.Pull.ABILITY_IDS) do ids[#ids + 1] = id end
    for id in pairs(UP.Pull.CAST_ABILITY_IDS) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local setKey = UP.Pull.ABILITY_IDS[id] or UP.Pull.CAST_ABILITY_IDS[id]
        local ok, name = pcall(GetAbilityName, id)
        local shown = ok and abilityDisplay(name) or "?"
        if not shown:lower():find(UP.Pull.SETS[setKey].match, 1, true) then good = false end
        parts[#parts + 1] = ("%d=%q"):format(id, shown)
    end
    return good, table.concat(parts, " ")
end

function UP.Pull.Init()
    untilMs, activeSet, activeSource, triggerCount = 0, nil, nil, 0
    castSeen, castWarned, castAllied, castPvE = 0, 0, 0, 0
    local ok, detail = UP.Pull.VerifyIds()
    if ok == false and UP.Note then
        UP.Note("Pull ability IDs no longer all resolve to their set names (" .. tostring(detail)
                .. "); pull detection may miss or misname a pull.")
    end
end

-- Test hook: run the expiry check without zo_callLater.
function UP.Pull._ExpireNow() expireCheck() end
