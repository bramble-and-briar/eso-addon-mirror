-- =============================================================================
-- Under Pressure -- Engine/Allegiance.lua (0.5.11)
-- =============================================================================
-- Answers one question for the pull tracker: is the player named in an event
-- a friend or a foe? The question arises because an enemy's Leashing Burst
-- cast is visible to this client as an EVENT_EFFECT_CHANGED on a unit that
-- has NO unit tag (Docs/PullDetection-LeashingBurst.md, field result of
-- 2026-11-01). Without a tag there is no GetUnitAlliance / GetUnitReaction,
-- and no native in the API takes a unitId, so the answer has to be assembled
-- from what the client does say about people, keyed by character name:
--
--   kill feed   EVENT_PVP_KILL_FEED_DEATH names killer and victim WITH their
--               alliance, for every player kill near you in Cyrodiil. In a
--               fight this fills the table within seconds.
--   reticle     EVENT_RETICLE_TARGET_PLAYER_CHANGED: whoever the reticle
--               crosses has a tag for that moment, so GetUnitAlliance works.
--   group       groupmates are friends; their names are read from the group
--               tags, and the tracker also sees COMBAT_UNIT_TYPE_GROUP on the
--               event itself.
--   actions     anyone whose damage lands on you is a foe; anyone whose heal
--               lands on you is a friend. Both come free from the combat
--               events the add-on already receives.
--
-- (This is the same approach Miat's PvP Alerts takes with its name-keyed
-- players database; read for the facts only, its licence states no terms.)
--
-- The verdict for a name nobody has told us about is "unknown", and the
-- tracker warns on unknown: an ally's Leashing Burst cannot pull you, so a
-- warning about an ally is a false alarm, while silence about an enemy is a
-- missed pull. The table empties itself past a cap rather than growing for a
-- whole evening; alliances do not change, so nothing is expired by time.
--
-- Names are compared with the gender suffix stripped ("Name^Mx" -> "Name"),
-- because the kill feed, the group tags and the effect events do not all
-- agree on whether they carry it.
-- =============================================================================

UP = UP or {}
UP.Allegiance = {}
local A = UP.Allegiance

local MAX_NAMES = 600

-- [cleanName] = { alliance = ALLIANCE_* or nil, hostile = true/false/nil }
local known = {}
local count = 0
local ownAlliance = nil

-- Sources the tracker already treats as friendly; recorded here too so the
-- verdict is the same whichever module asks.
local FRIENDLY_TYPES = {}
for _, v in ipairs({ COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP,
                     COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_PLAYER_COMPANION }) do
    if type(v) == "number" then FRIENDLY_TYPES[v] = true end
end

local HEAL_RESULTS = {}
for _, v in ipairs({ ACTION_RESULT_HEAL, ACTION_RESULT_CRITICAL_HEAL,
                     ACTION_RESULT_HOT_TICK, ACTION_RESULT_HOT_TICK_CRITICAL }) do
    if type(v) == "number" then HEAL_RESULTS[v] = true end
end

-- ---------------------------------------------------------------------------
-- Names
-- ---------------------------------------------------------------------------
local function clean(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local s = raw:gsub("%^.*$", "")
    if s == "" then return nil end
    return s
end
A.CleanName = clean

local function record(name)
    local r = known[name]
    if not r then
        if count >= MAX_NAMES then
            known, count = {}, 0
        end
        r = {}
        known[name] = r
        count = count + 1
    end
    return r
end

-- ---------------------------------------------------------------------------
-- Own alliance
-- ---------------------------------------------------------------------------
function A.RefreshOwnAlliance()
    if type(GetUnitAlliance) == "function" then
        local ok, v = pcall(GetUnitAlliance, "player")
        if ok and type(v) == "number" and v > 0 then ownAlliance = v end
    end
    return ownAlliance
end

function A.OwnAlliance() return ownAlliance end

-- ---------------------------------------------------------------------------
-- Feeds
-- ---------------------------------------------------------------------------
function A.NoteAlliance(rawName, alliance)
    local name = clean(rawName)
    if not name or type(alliance) ~= "number" or alliance <= 0 then return end
    record(name).alliance = alliance
end

function A.NoteHostile(rawName)
    local name = clean(rawName)
    if not name then return end
    record(name).hostile = true
end

function A.NoteFriendly(rawName)
    local name = clean(rawName)
    if not name then return end
    local r = record(name)
    -- Damage already seen from this name outranks a heal: there is no
    -- friendly fire in ESO, so damage is the stronger fact.
    if r.hostile == nil then r.hostile = false end
end

-- From EventIngest's EVENT_COMBAT_EVENT handler, only for events whose
-- target is the player. isHostile is the ingest's own damage verdict.
function A.OnCombat(isHostile, result, sourceName, sourceType)
    if FRIENDLY_TYPES[sourceType] then return end
    if isHostile then
        A.NoteHostile(sourceName)
    elseif HEAL_RESULTS[result] then
        A.NoteFriendly(sourceName)
    end
end

-- EVENT_PVP_KILL_FEED_DEATH (killLocation, killerDisplay, killerCharacter,
-- killerAlliance, killerRank, victimDisplay, victimCharacter, victimAlliance,
-- victimRank, isKillLocation).
function A.OnKillFeed(eventCode, killLocation, killerDisplay, killerCharacter, killerAlliance,
                      killerRank, victimDisplay, victimCharacter, victimAlliance)
    A.NoteAlliance(killerCharacter, killerAlliance)
    A.NoteAlliance(victimCharacter, victimAlliance)
end

-- EVENT_RETICLE_TARGET_PLAYER_CHANGED: the unit under the reticle has a tag
-- for as long as it is there, so its alliance is readable.
function A.OnReticlePlayer()
    if type(IsUnitPlayer) ~= "function" or type(GetUnitAlliance) ~= "function" then return end
    local ok, isPlayer = pcall(IsUnitPlayer, "reticleover")
    if not ok or not isPlayer then return end
    local name = (type(GetRawUnitName) == "function") and GetRawUnitName("reticleover")
                 or (type(GetUnitName) == "function" and GetUnitName("reticleover")) or nil
    local okA, alliance = pcall(GetUnitAlliance, "reticleover")
    if okA then A.NoteAlliance(name, alliance) end
end

-- Group tags: every member is a friend. Called on group changes and after a
-- load screen.
function A.ResyncGroup()
    if type(GetGroupSize) ~= "function" or type(GetUnitName) ~= "function" then return end
    local n = GetGroupSize() or 0
    for i = 1, n do
        local tag = (type(GetGroupUnitTagByIndex) == "function") and GetGroupUnitTagByIndex(i) or ("group" .. i)
        if tag and not (type(AreUnitsEqual) == "function" and AreUnitsEqual("player", tag)) then
            local name = GetUnitName(tag)
            if name and name ~= "" then
                A.NoteFriendly(name)
                if type(GetUnitAlliance) == "function" then
                    local ok, alliance = pcall(GetUnitAlliance, tag)
                    if ok then A.NoteAlliance(name, alliance) end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The verdict
-- ---------------------------------------------------------------------------
-- "friend" | "foe" | "unknown". sourceType is optional and decides first: a
-- GROUP / PLAYER / pet / companion source is a friend whatever the table says.
function A.Classify(rawName, sourceType)
    if sourceType ~= nil and FRIENDLY_TYPES[sourceType] then return "friend" end
    local name = clean(rawName)
    if not name then return "unknown" end
    local r = known[name]
    if not r then return "unknown" end
    if r.alliance and ownAlliance then
        return (r.alliance == ownAlliance) and "friend" or "foe"
    end
    if r.hostile == true then return "foe" end
    if r.hostile == false then return "friend" end
    return "unknown"
end

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------
function A.Count() return count end

-- "allegiance own=2 names=14 friends=9 foes=5" for the debug overlay. Walks the
-- table, which is bounded by MAX_NAMES, and only when the overlay redraws.
function A.Summary()
    local friends, foes = 0, 0
    for name in pairs(known) do
        local v = A.Classify(name)
        if v == "friend" then friends = friends + 1 elseif v == "foe" then foes = foes + 1 end
    end
    return ("allegiance own=%s names=%d friends=%d foes=%d"):format(
        tostring(ownAlliance or "?"), count, friends, foes)
end

function A.Reset()
    known, count = {}, 0
end

function A.Init()
    A.Reset()
    A.RefreshOwnAlliance()
end

-- Test hook.
function A._Known(rawName)
    local name = clean(rawName)
    return name and known[name] or nil
end
