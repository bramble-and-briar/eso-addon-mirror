-- Starts a boss timer by itself when the player defeats a boss and gets experience from it (see "Spotting a defeated
-- boss" in docs/ARCHITECTURE.md):
--   * Which bosses: those on the boss health bar at the top of the screen (the game's units boss1, boss2 and so on),
--     which covers every world boss and the newer delve and public dungeon bosses. Older delve and public dungeon
--     bosses have no health bar, so in a delve or public dungeon an enemy the player has aimed at also counts when it
--     dies, if the game ranks it above an ordinary enemy: dying while aimed at, or named in the game's combat events.
--   * Where: anywhere except group dungeons, trials, arenas and battlegrounds, where each group has its own copy.
--   * When: the player gets experience for a kill within a few seconds of the boss's death. Grouped players near the
--     boss get the timer without it, as do players at the experience cap, who get no experience.
-- Bosses that die together, such as a world boss with several bosses, share one timer once the last of them dies.
-- Each timer also notes the kind of place the boss died in, for the countdown's icon.
-- Each player's add-on works from what that player's game reports; nothing is sent between players.

local addon = SlayansBossTimer
local Timers = addon.Timers
local Debug = addon.Util.Debug

local Detector = {}
addon.Detector = Detector

local NAME = "SlayansBossTimerDetector"
-- The death and the experience arrive separately, in either order.
Detector.PAIR_WINDOW_MS = 3000
-- Deaths further apart than this belong to different fights.
Detector.ENCOUNTER_GAP_MS = 120000

local KILL_REASONS = {
    [PROGRESS_REASON_KILL] = true,
    [PROGRESS_REASON_OVERLAND_BOSS_KILL] = true, -- A world boss: the game plays its own fanfare for it.
    [PROGRESS_REASON_BOSS_KILL] = true,
}

-- The combat events' results for an enemy's death: with experience for the player, for the player's companion, or
-- none.
local DEATH_RESULTS = { ACTION_RESULT_DIED_XP, ACTION_RESULT_DIED_COMPANION_XP, ACTION_RESULT_DIED }

local lastKillExperienceMs -- When the player last got experience for a kill.
local encounter -- The bosses on the health bar that died in the current fight: { names, lastDeathMs }.
local pending = {} -- Fights that ended without experience yet: { names, zoneId, kind, diedMs }.
-- Enemies the player has aimed at in this zone that could be bosses without a health bar, by name. They are
-- remembered until they die, so a boss that dies while the player looks away still counts.
local aimed = {}
local barDeaths = {} -- When each boss on the health bar last died, by name, so the aimed-at enemy isn't counted twice.

local function Now()
    return GetGameTimeMilliseconds()
end

-- Unit names carry grammar markers for the game's text formatting; this gives the name as the game shows it.
local function FormatName(rawName)
    return zo_strformat(SI_UNIT_NAME, rawName or "")
end

-- Returns "First Boss", "First Boss and Second Boss" or "First Boss and 2 More".
function Detector.FormatNames(names)
    if #names == 1 then
        return names[1]
    elseif #names == 2 then
        return zo_strformat(SI_SBT_BOSS_PAIR, names[1], names[2])
    end
    return zo_strformat(SI_SBT_BOSS_GROUP, names[1], #names - 1)
end

-- False in group dungeons, trials, arenas and the Infinite Archive (instances a group owns) and in battlegrounds.
function Detector.IsTimerArea()
    return not IsActiveWorldGroupOwnable() and not IsActiveWorldBattleground()
        and GetCurrentParticipatingRaidId() == 0
end

local function GetZoneIdHere()
    local zoneIndex = GetUnitZoneIndex("player")
    return zoneIndex and GetZoneId(zoneIndex) or 0
end

-- Players who can't get experience from the boss but still get its timer: grouped players near it (it died where
-- their game could see it), and players at the experience cap.
local function GetsTimerWithoutExperience()
    if IsUnitGrouped("player") then
        return true
    end
    local cap = GetChampionPointsPlayerProgressionCap()
    return type(cap) == "number" and cap > 0 and GetPlayerChampionPointsEarned() >= cap
end

-- The map pins' icons, by the start of their file name, for places the zone guide doesn't list.
local KIND_BY_PIN = {
    { "poi_groupdelve_", "groupDelve" },
    { "poi_delve_", "delve" },
    { "poi_dungeon_", "publicDungeon" },
}

-- Returns the kind of place a map pin stands for, or nil for any other pin. The zone guide's kind comes first, as in
-- the game's own ZO_MapPin:IsDelvePin (ingame/map/mappin.lua), since a delve's pin can also have the public dungeon
-- type; then the pin's icon, which is what the map shows; then its type.
local function GetPinKind(zoneIndex, poiIndex)
    local completionType = GetPOIZoneCompletionType(zoneIndex, poiIndex)
    if completionType == ZONE_COMPLETION_TYPE_GROUP_DELVES then
        return "groupDelve"
    elseif completionType == ZONE_COMPLETION_TYPE_DELVES then
        return "delve"
    elseif completionType == ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS then
        return "publicDungeon"
    end
    local icon = select(4, GetPOIMapInfo(zoneIndex, poiIndex))
    icon = type(icon) == "string" and icon:lower() or ""
    for _, pin in ipairs(KIND_BY_PIN) do
        if icon:find(pin[1], 1, true) then
            return pin[2]
        end
    end
    if GetPOIType(zoneIndex, poiIndex) == POI_TYPE_PUBLIC_DUNGEON then
        return "publicDungeon"
    end
end

-- Names without the game's grammar markers ("^n" and the like) and in lower case, to compare.
local function PlainName(name)
    return (string.gsub(name or "", "%^.*$", "")):lower()
end

-- Returns the kind of place of the pin on the map outside that has this zone's name: a delve or public dungeon is a
-- zone of its own, whose parent is the zone outside. Some, such as Silumm in Glenumbra, give no pin through
-- GetCurrentSubZonePOIIndices.
local function GetKindFromZoneOutside()
    local zoneId = GetZoneIdHere()
    local parentId = zoneId ~= 0 and GetParentZoneId(zoneId) or 0
    if not parentId or parentId == 0 or parentId == zoneId then
        return nil
    end
    local parentIndex, name = GetZoneIndex(parentId), PlainName(GetZoneNameById(zoneId))
    if not parentIndex or name == "" then
        return nil
    end
    for poiIndex = 1, GetNumPOIs(parentIndex) do
        if PlainName((GetPOIInfo(parentIndex, poiIndex))) == name then
            return GetPinKind(parentIndex, poiIndex)
        end
    end
end

-- Returns the kind of place the player is in: "delve", "groupDelve" or "publicDungeon" inside one the map names,
-- "dungeon" anywhere else inside, and "overland" in the open world.
function Detector.GetPlaceKind()
    local zoneIndex, poiIndex = GetCurrentSubZonePOIIndices()
    local kind = zoneIndex and poiIndex and GetPinKind(zoneIndex, poiIndex)
    kind = kind or GetKindFromZoneOutside()
    if kind then
        return kind
    end
    return IsUnitInDungeon("player") and "dungeon" or "overland"
end

local function StartTimer(names, zoneId, kind)
    Debug("Starting a timer: %s.", Detector.FormatNames(names))
    Timers.Start(names, Detector.FormatNames(names), zoneId, kind)
end

-- A fight is over: its bosses get a timer if the player earned it, now or once the experience arrives. Where it was is
-- noted now, in case the player leaves before the experience arrives.
local function OnBossesDefeated(names)
    local now = Now()
    local zoneId, kind = GetZoneIdHere(), Detector.GetPlaceKind()
    if GetsTimerWithoutExperience()
        or (lastKillExperienceMs and now - lastKillExperienceMs <= Detector.PAIR_WINDOW_MS) then
        StartTimer(names, zoneId, kind)
        return
    end
    -- Forget fights that never got their experience.
    for index = #pending, 1, -1 do
        if now - pending[index].diedMs > Detector.PAIR_WINDOW_MS then
            table.remove(pending, index)
        end
    end
    table.insert(pending, { names = names, zoneId = zoneId, kind = kind, diedMs = now })
    Debug("Waiting for experience: %s.", Detector.FormatNames(names))
end

local function OnExperienceGain(_, reason)
    if not KILL_REASONS[reason] then
        return
    end
    local now = Now()
    Debug("Experience for a kill (reason %d).", reason)
    lastKillExperienceMs = now
    local waiting = pending
    pending = {}
    for _, fight in ipairs(waiting) do
        if now - fight.diedMs <= Detector.PAIR_WINDOW_MS then
            StartTimer(fight.names, fight.zoneId, fight.kind)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Bosses on the health bar
---------------------------------------------------------------------------------------------------

-- The boss units, as the game's own boss bar lists them (ingame/unitframes/bossbar.lua).
local function ForEachBossTag(callback)
    for index = BOSS_RANK_ITERATION_BEGIN, BOSS_RANK_ITERATION_END do
        local unitTag = "boss" .. index
        if DoesUnitExist(unitTag) and callback(unitTag) then
            return true
        end
    end
    return false
end

local function IsAnyBossAlive()
    return ForEachBossTag(function(unitTag)
        return not IsUnitDead(unitTag)
    end)
end

local function IsAnyBossOnBar()
    return ForEachBossTag(function()
        return true
    end)
end

local function OnBossDeathStateChanged(_, unitTag, isDead)
    if not isDead or not Detector.IsTimerArea() then
        return
    end
    local name = FormatName(GetUnitName(unitTag))
    if name == "" then
        return
    end
    Debug("Boss on the health bar died: %s (%s).", name, unitTag)
    local now = Now()
    if not encounter or now - encounter.lastDeathMs > Detector.ENCOUNTER_GAP_MS then
        encounter = { names = {} }
    end
    encounter.lastDeathMs = now
    barDeaths[name] = now
    local isNew = true
    for _, known in ipairs(encounter.names) do
        isNew = isNew and known ~= name
    end
    if isNew then
        table.insert(encounter.names, name)
    end
    if not IsAnyBossAlive() then
        local names = encounter.names
        encounter = nil
        OnBossesDefeated(names)
    end
end

---------------------------------------------------------------------------------------------------
-- Bosses without a health bar, in delves and public dungeons
---------------------------------------------------------------------------------------------------

-- An enemy the game ranks above an ordinary one (the target frame's difficulty brackets), in a delve or public
-- dungeon. Read while it is alive, since a dead unit may report less.
local function CouldBeBossWithoutBar(unitTag)
    return DoesUnitExist(unitTag) and not IsUnitDead(unitTag) and not IsUnitPlayer(unitTag)
        and GetUnitReaction(unitTag) == UNIT_REACTION_HOSTILE
        and GetUnitDifficulty(unitTag) >= MONSTER_DIFFICULTY_NORMAL
end

local function OnTargetChanged()
    if CouldBeBossWithoutBar("reticleover") then
        local name = FormatName(GetUnitName("reticleover"))
        if name ~= "" and not aimed[name] then
            Debug("Aiming at a possible boss: %s (difficulty %d).", name, GetUnitDifficulty("reticleover"))
            aimed[name] = true
        end
    end
end

-- An enemy died: it counts once if the player aimed at it before, in a delve or public dungeon.
local function OnEnemyDied(name, message)
    if name == "" or not aimed[name] or not Detector.IsTimerArea() or not IsUnitInDungeon("player") then
        return
    end
    -- A boss on the health bar is counted there.
    local diedOnBar = barDeaths[name] and Now() - barDeaths[name] <= Detector.ENCOUNTER_GAP_MS
    if IsAnyBossOnBar() or diedOnBar then
        return
    end
    Debug(message, name)
    aimed[name] = nil
    OnBossesDefeated({ name })
end

-- The game may already have moved the aim on when this arrives, so the dead enemy is matched by name.
local function OnTargetDeathStateChanged(_, unitTag, isDead)
    if isDead then
        OnEnemyDied(FormatName(GetUnitName(unitTag)), "The enemy aimed at died: %s.")
    end
end

-- The game's combat events report deaths too, naming the enemy at least when the player's own attack killed it
-- (Kyzderp's Derps found), so this catches a boss that dies while the player looks away.
local function OnCombatDeath(_, _, _, _, _, _, _, _, targetName)
    OnEnemyDied(FormatName(targetName), "An enemy aimed at earlier died: %s.")
end

-- A new zone or a loading screen starts afresh.
local function OnPlayerActivated()
    lastKillExperienceMs = nil
    encounter = nil
    aimed = {}
    pending = {}
    barDeaths = {}
end

function Detector.Initialize()
    EVENT_MANAGER:RegisterForEvent(NAME .. "Boss", EVENT_UNIT_DEATH_STATE_CHANGED, OnBossDeathStateChanged)
    EVENT_MANAGER:AddFilterForEvent(NAME .. "Boss", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX,
        "boss")
    EVENT_MANAGER:RegisterForEvent(NAME .. "Target", EVENT_UNIT_DEATH_STATE_CHANGED, OnTargetDeathStateChanged)
    EVENT_MANAGER:AddFilterForEvent(NAME .. "Target", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG,
        "reticleover")
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, OnTargetChanged)
    for _, result in ipairs(DEATH_RESULTS) do
        local name = NAME .. "Death" .. result
        EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnCombatDeath)
        EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_EXPERIENCE_GAIN, OnExperienceGain)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end
