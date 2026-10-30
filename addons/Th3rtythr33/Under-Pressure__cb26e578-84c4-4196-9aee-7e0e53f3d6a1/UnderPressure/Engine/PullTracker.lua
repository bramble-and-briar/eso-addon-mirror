-- =============================================================================
-- Under Pressure -- Engine/PullTracker.lua (0.4.2)
-- =============================================================================
-- Detects an incoming pull on the player before it lands and tells
-- UI/PullIndicator how long the warning should stay up. One switch
-- (sv.pull_detect, default OFF) covers every pull this module knows about;
-- scribing pulls (Soul Burst + Pull) join the same switch once the field test
-- in Docs/PullDetection-LeashingBurst.md shows they are visible at all.
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

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local untilMs = 0          -- warning deadline (GetGameTimeMilliseconds clock), 0 = none
local activeSet = nil      -- "agony" / "convergence" while a warning is up
local activeSource = nil   -- wearer's name when the event carried one
local triggerCount = 0

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

local function trigger(setKey, sourceName, leadMs, t)
    triggerCount = triggerCount + 1
    local deadline = t + leadMs
    if deadline > untilMs then untilMs = deadline end
    activeSet = setKey
    if sourceName and sourceName ~= "" then activeSource = sourceName end
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
    trigger(setKey, sourceName, lead, t or nowMs())
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
    trigger(setKey, nil, lead, t)
    logDebug(setKey, "effect", nil, lead, abilityId)
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
    return { untilMs = untilMs, set = activeSet, source = activeSource, triggers = triggerCount }
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

-- true when every id's live name contains its set's keyword; false when any
-- does not (ids drifted); nil when the API is unavailable. detail lists them.
function UP.Pull.VerifyIds()
    if type(GetAbilityName) ~= "function" then return nil, "GetAbilityName unavailable" end
    local good, parts = true, {}
    local ids = {}
    for id in pairs(UP.Pull.ABILITY_IDS) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local setKey = UP.Pull.ABILITY_IDS[id]
        local ok, name = pcall(GetAbilityName, id)
        local shown = ok and abilityDisplay(name) or "?"
        if not shown:lower():find(UP.Pull.SETS[setKey].match, 1, true) then good = false end
        parts[#parts + 1] = ("%d=%q"):format(id, shown)
    end
    return good, table.concat(parts, " ")
end

function UP.Pull.Init()
    untilMs, activeSet, activeSource, triggerCount = 0, nil, nil, 0
    local ok, detail = UP.Pull.VerifyIds()
    if ok == false and UP.Note then
        UP.Note("Pull ability IDs no longer all resolve to their set names (" .. tostring(detail)
                .. "); pull detection may miss or misname a pull.")
    end
end

-- Test hook: run the expiry check without zo_callLater.
function UP.Pull._ExpireNow() expireCheck() end
