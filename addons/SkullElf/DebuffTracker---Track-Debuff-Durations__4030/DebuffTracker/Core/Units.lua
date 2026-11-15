-- What the addon knows about units: names, the last unit tag each unitId was seen with, which
-- unitId is the player / current target / a boss. Learned passively from effect events (every
-- EVENT_EFFECT_CHANGED carries both a unitTag and a unitId).

local DT = DebuffTracker
local Units = DT.Units

Units.nameOf = {}
Units.rawNameOf = {}    -- the name as the event gave it (cleaned only when it changes: every effect event carries it)
Units.tagOf = {}
Units.bossIds = {}
Units.playerUnitId = nil
Units.reticleUnitId = nil
Units.listeners = {}

local function Notify(event)
    for _, fn in ipairs(Units.listeners) do fn(event) end
end

function Units.OnChange(fn)
    Units.listeners[#Units.listeners + 1] = fn
end

------------------------------------------------------------------------------
-- Enemies you're fighting. The game only tells addons about enemies through events, and an enemy
-- WITHOUT a debuff never produces an effect event -- so "who is missing Major Breach" needs its own
-- list: every unit your side damages (you, your pets, your group), kept for ENGAGE_TIMEOUT seconds
-- after the last hit (its hits on you count too) and dropped on death, when you leave combat, when your
-- target is seen dead, or on zone change. Only registered
-- while some tracker needs it ("All enemies" + "Show while missing"/"Always").
------------------------------------------------------------------------------

Units.engaged = {}          -- [unitId] = time of the last hit
Units.loggedCorpse = {}
local ENGAGE_TIMEOUT = 10
Units.ENGAGE_TIMEOUT = ENGAGE_TIMEOUT
local engagedTracking = false
local NS_ENGAGE = "DebuffTracker5_Engage"

local DAMAGE = {}
for _, name in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK",
        "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
        "ACTION_RESULT_ABSORBED", "ACTION_RESULT_PRECISE_DAMAGE", "ACTION_RESULT_WRECKING_DAMAGE",
        "ACTION_RESULT_FALL_DAMAGE" }) do
    if _G[name] then DAMAGE[_G[name]] = true end
end
local FRIENDLY_TYPE = {}
for _, name in ipairs({ "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_PLAYER_PET", "COMBAT_UNIT_TYPE_GROUP",
        "COMBAT_UNIT_TYPE_PLAYER_COMPANION", "COMBAT_UNIT_TYPE_COMPANION" }) do
    if _G[name] then FRIENDLY_TYPE[_G[name]] = true end
end

local function Engage(unitId, name)
    if not unitId or unitId == 0 then return end
    -- a hit after its death event (the same volley, overkill, a DoT tick) doesn't put a corpse back on
    -- the list ("Off Balance ready" stayed on dead enemies); it's fought again only once it has shown a
    -- new effect well after dying (Effects clears the mark then)
    local died = DT.Effects.died and DT.Effects.died[unitId]
    if died then
        if DT.debug and not Units.loggedCorpse[unitId] then
            Units.loggedCorpse[unitId] = true
            DT.Util.Debug("ignored a hit on %s: it died %.1f s ago", tostring(Units.nameOf[unitId] or name or unitId), DT.Util.Now() - died)
        end
        return
    end
    Units.engaged[unitId] = DT.Util.Now()
    if name and name ~= "" and not Units.nameOf[unitId] then Units.nameOf[unitId] = DT.Util.CleanName(name) end
end

-- our side hit something that isn't on our side
local function OnOutgoing(_, result, isError, _, _, _, _, _, targetName, targetType, _, _, _, _, _, targetUnitId)
    if isError or not DAMAGE[result] or FRIENDLY_TYPE[targetType] then return end
    Engage(targetUnitId, targetName)
end

-- something hit me: only keeps an enemy you're ALREADY fighting on the list. It never adds one: many
-- incoming hits come from separate units named after their caster (projectiles, ground effects,
-- summoned hazards), which would show up as a second copy of the enemy that never dies.
local function OnIncoming(_, result, isError, _, _, _, sourceName, sourceType, _, _, _, _, _, _, sourceUnitId)
    if isError or not DAMAGE[result] or FRIENDLY_TYPE[sourceType] then return end
    if sourceUnitId and Units.engaged[sourceUnitId] then Engage(sourceUnitId, sourceName) end
end

local ENGAGE_REGS = {
    { "_OutPlayer", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, "COMBAT_UNIT_TYPE_PLAYER", OnOutgoing },
    { "_OutPet", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, "COMBAT_UNIT_TYPE_PLAYER_PET", OnOutgoing },
    { "_OutGroup", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, "COMBAT_UNIT_TYPE_GROUP", OnOutgoing },
    { "_In", REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, "COMBAT_UNIT_TYPE_PLAYER", OnIncoming },
}

function Units.SetEngagedTracking(on)
    on = on == true
    if on == engagedTracking then return end
    engagedTracking = on
    for _, r in ipairs(ENGAGE_REGS) do
        local ns, unitType = NS_ENGAGE .. r[1], _G[r[3]]
        if on and unitType then
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, r[4])
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, r[2], unitType, REGISTER_FILTER_IS_ERROR, false)
        else
            EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
        end
    end
    if not on then Units.engaged = {} end
end

function Units.IsEngagedTracking() return engagedTracking end

function Units.RemoveEngaged(unitId)
    Units.engaged[unitId] = nil
end

-- Out of combat: nothing is being fought any more (a kill's death event can be missed, e.g. far away
-- or killed by someone else).
function Units.ClearEngaged()
    Units.engaged = {}
    Units.loggedCorpse = {}
end

-- (No "your target looks dead" clean-up: the game's death events arrive reliably -- an in-game log
-- showed them for every kill -- while guessing which unit a dead reticle target was removed LIVING
-- enemies' effects twice: 5.6.7-5.7.5.)

-- unitIds of enemies fought within the timeout (expired ones are dropped)
function Units.EngagedList(now)
    local list = {}
    for id, last in pairs(Units.engaged) do
        if now - last > ENGAGE_TIMEOUT then Units.engaged[id] = nil else list[#list + 1] = id end
    end
    return list
end

function Units.IsFriendlyTag(tag)
    if not tag or tag == "" then return false end
    if tag == "player" or tag == "companion" then return true end
    local p = tag:sub(1, 5)
    if p == "group" then return true end
    if tag:sub(1, 3) == "pet" then return true end
    return false
end

-- Is this unit tag an enemy (something you can fight)? Players, companions and allied NPCs aren't.
local ALLY_REACTION = {}
for _, n in ipairs({ "UNIT_REACTION_FRIENDLY", "UNIT_REACTION_PLAYER_ALLY", "UNIT_REACTION_NPC_ALLY", "UNIT_REACTION_COMPANION" }) do
    if _G[n] then ALLY_REACTION[_G[n]] = true end
end
function Units.IsEnemyTag(tag)
    if not tag or tag == "" or not DoesUnitExist(tag) then return false end
    if Units.IsFriendlyTag(tag) then return false end
    if type(IsUnitPlayer) == "function" and IsUnitPlayer(tag) and GetUnitReaction(tag) ~= UNIT_REACTION_HOSTILE then return false end
    return not ALLY_REACTION[GetUnitReaction(tag)]
end

function Units.Observe(tag, unitId, unitName)
    if not unitId or unitId == 0 then return end
    if unitName and unitName ~= "" and Units.rawNameOf[unitId] ~= unitName then
        Units.rawNameOf[unitId] = unitName
        Units.nameOf[unitId] = DT.Util.CleanName(unitName)
    end
    if tag and tag ~= "" then
        Units.tagOf[unitId] = tag
        if tag == "player" then
            Units.playerUnitId = unitId
        elseif tag == "reticleover" then
            -- an event tagged "reticleover" names the target's unitId exactly: no deduction needed
            -- (not while the reticle is on a corpse: a late event of another unit must not be adopted)
            if IsUnitDead("reticleover") then return end
            Units.targetCandidates = { [unitId] = true }
            Units.reticleExact = true
            if Units.reticleUnitId ~= unitId then
                Units.reticleUnitId = unitId
                Notify("target")
            end
        elseif tag:sub(1, 4) == "boss" then
            if not Units.bossIds[unitId] then Units.LearnDifficulty(tag) end
            Units.bossIds[unitId] = true
        end
    end
end

------------------------------------------------------------------------------
-- Enemy difficulty (normal 1 .. deadly 4), learned by name per zone whenever an enemy is your target
-- or a boss, and kept across sessions (saved variables). Used by "minimum enemy difficulty".
------------------------------------------------------------------------------

Units.difficulty = {}       -- [zoneId] = { [lowercase name] = difficulty }; points into saved vars

function Units.SetDifficultyStore(store)
    Units.difficulty = type(store) == "table" and store or {}
end

function Units.LearnDifficulty(tag)
    if type(GetUnitDifficulty) ~= "function" or not DoesUnitExist(tag) then return end
    if GetUnitReaction(tag) ~= UNIT_REACTION_HOSTILE then return end
    local name = DT.Util.Lower(DT.Util.CleanName(GetUnitName(tag)))
    if name == "" then return end
    local zoneId = DT.Load.zone.id or 0
    local z = Units.difficulty[zoneId]
    if not z then z = {}; Units.difficulty[zoneId] = z end
    if z[name] == nil then z[name] = GetUnitDifficulty(tag) end
end

function Units.DifficultyOf(unitId)
    local name = Units.nameOf[unitId]
    if not name then return 0 end
    local z = Units.difficulty[DT.Load.zone.id or 0]
    return (z and z[DT.Util.Lower(name)]) or 0
end

-- unitId: the deduced target; candidates: every unit that matched equally well (all get marked)
function Units.SetTarget(unitId, candidates)
    local set = {}
    for _, id in ipairs(candidates or { unitId }) do set[id] = true end
    Units.targetCandidates = set
    Units.reticleExact = false
    if unitId and Units.reticleUnitId ~= unitId then
        Units.reticleUnitId = unitId
        Notify("target")
    end
end

function Units.OnReticleChanged()
    -- The previous id belongs to the previous target; relearned from the next tagged event.
    Units.reticleUnitId = nil
    Units.targetCandidates = nil
    Units.reticleExact = false
    Units.LearnDifficulty("reticleover")
    Notify("target")
end

function Units.Reset()
    Units.nameOf, Units.rawNameOf, Units.tagOf, Units.bossIds = {}, {}, {}, {}
    Units.engaged = {}
    Units.loggedCorpse = {}
    Units.reticleUnitId = nil
    Units.targetCandidates = nil
end

function Units.IsTarget(unitId)
    if unitId == nil then return false end
    if unitId == Units.reticleUnitId then return true end
    return Units.targetCandidates ~= nil and Units.targetCandidates[unitId] == true
end

function Units.IsBoss(unitId)
    return Units.bossIds[unitId] == true
end

local MAX_BOSSES = 12
function Units.BossTags()
    local tags = {}
    for i = 1, MAX_BOSSES do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then tags[#tags + 1] = tag end
    end
    return tags
end

function Units.GroupTags(includePlayerWhenSolo)
    local tags = {}
    local size = GetGroupSize()
    if size and size > 0 then
        for i = 1, size do
            local tag = GetGroupUnitTagByIndex(i)
            if tag and DoesUnitExist(tag) then tags[#tags + 1] = tag end
        end
    elseif includePlayerWhenSolo then
        tags[1] = "player"
    end
    return tags
end

function Units.NameForTag(tag)
    if tag == "player" or (tag and tag:sub(1, 5) == "group" and IsUnitPlayer and IsUnitPlayer(tag)) then
        local display = GetUnitDisplayName(tag)
        local character = DT.Util.CleanName(GetUnitName(tag))
        if character ~= "" then return character end
        return display or tag
    end
    return DT.Util.CleanName(GetUnitName(tag))
end
