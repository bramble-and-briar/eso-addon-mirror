TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Base = TacticalDisplay.Base or {}
local _Base = TacticalDisplay.Base
local _ClearTable = TacticalDisplay.Utilities.ClearTable
local _CountTable = TacticalDisplay.Utilities.CountTable
local _GetAbilityIconCached = TacticalDisplay.Utilities.GetAbilityIconCached
local _LogError = TacticalDisplay.Utilities.LogError
local _LogDebug = TacticalDisplay.Utilities.LogDebug

local _debugLog -- boolean

-- Hidden from current attack report and "recent" update.
-- Can still be tracked if they're also signature abilities.
-- DoTs are listed, though no effect for now (see TRACKED_DOT_ABILITIES).
local HIDDEN_ABILITY_NAMES = {
    ["Absorb Magicka"] = true,
    ["Absorb Stamina"] = true,
    ["Atronach Lightning Storm"] = true,
    ["Avid Boneyard"] = true,
    ["Befouled Weapon"] = true,
    ["Blockade of Frost"] = true,
    ["Blockade of Storms"] = true,
    ["Burning Embers"] = true,
    ["Burning Light"] = true,
    ["Burning"] = true,
    ["Charged Weapon"] = true,
    ["Chilled"] = true,
    ["Combustion"] = true,
    ["Concussed"] = true,
    ["Corrosive Drain"] = true,
    ["Deathbolt"] = true,
    ["Decrease Health"] = true,
    ["Detonating Siphon"] = true,
    ["Direwolf Gnash"] = true,
    ["Direwolf Lunge"] = true,
    ["Diseased"] = true,
    ["Disintegrated Dragonfire"] = true,
    ["Fiery Weapon"] = true,
    ["Forceful"] = true,
    ["Frozen Weapon"] = true,
    ["Hemorrhaging"] = true,
    ["Hurricane"] = true,
    ["Igneous Weapons"] = true,
    ["Leeching Plate"] = true,
    ["Life Drain"] = true,
    ["Molten Armaments"] = true,
    ["Overcharged"] = true,
    ["Poison Injection"] = true,
    ["Poisoned Weapon"] = true,
    ["Poisoned"] = true,
    ["Prismatic Weapon"] = true,
    ["Quick Cloak"] = true,
    ["Razor Caltrops"] = true,
    ["Shared Pain"] = true,
    ["Solar Barrage"] = true,
    ["Soul Shatter"] = true,
    ["Summon Twilight Matriarch"] = true,
    ["Sundered"] = true,
    ["Unstable Clannfear"] = true,
    ["Unstable Core"] = true,
    ["Volatile Familiar"] = true,
}
local _HIDDEN_ABILITIES -- [ability id] = ability name

-- DoT abilities to register for combat events explicitly
-- Because there are very few DoTs to track for now.
-- This might change in future to rely on HIDDEN_ABILITIES.
local TRACKED_DOT_ABILITY_NAMES = {
    ["Corrosive Armor"] = true,
    ["Maarselok"] = true,
    ["Pyrebrand"] = true,
    ["Thrive in Chaos"] = true,
}
local _TRACKED_DOT_ABILITIES -- [ability id] = ability name

-- To identify opponents' builds
local SIGNATURE_ABILITY_NAMES = {
    -- Class: Arcanist: Herald of the Tome
    ["The Tide King's Gaze"] = true,
    ["Exhausting Fatecarver"] = true,
    ["Pragmatic Fatecarver"] = true,
    ["Cephaliarch's Flail"] = true,
    ["Tentacular Dread"] = true,
    -- Class: Dragonknight: Ardent Flame
    ["Lava Whip"] = true,
    ["Flame Lash"] = true,
    ["Molten Whip"] = true,
    -- Class: Dragonknight: Earthen Heart
    ["Corrosive Armor"] = true,
    -- Class: Necromancer: Grave Lord
    ["Glacial Colossus"] = true,
    ["Pestilent Colossus"] = true,
    ["Ricochet Skull"] = true,
    ["Venom Skull"] = true,
    -- Class: Nightblade: Assassination
    ["Concealed Weapon"] = true,
    ["Surprise Attack"] = true,
    ["Merciless Resolve"] = true,
    ["Relentless Focus"] = true,
    -- Class: Sorcerer: Daedric Summoning
    ["Bound Armaments"] = true,
    -- Class: Sorcerer: Dark Magic
    ["Crystal Fragments"] = true,
    -- Class: Sorcerer: Storm Calling
    ["Light Attack (Energy Overload)"] = true,
    ["Light Attack (Power Overload)"] = true,
    ["Streak"] = true,
    -- Class: Templar: Aedric Spear
    ["Aurora Javelin"] = true,
    ["Binding Javelin"] = true,
    ["Toppling Charge"] = true,
    -- Class: Templar: Dawn's Wrath
    ["Radiant Glory"] = true,
    ["Radiant Oppression"] = true,
    -- Class: Warden: Animal Companions
    ["Deep Fissure"] = true,
    ["Subterranean Assault"] = true,
    -- Weapon: Bow
    ["Ballista"] = true,
    ["Toxic Barrage"] = true,
    ["Focused Aim"] = true,
    ["Lethal Arrow"] = true,
    -- Weapon: Dual Wield
    ["Rend"] = true,
    ["Thrive in Chaos"] = true,
    ["Rending Slashes"] = true,
    -- Weapon: One Hand and Shield
    ["Power Slam"] = true,
    ["Reverberating Bash"] = true,
    -- Weapon: Two Handed
    ["Onslaught"] = true,
    ["Dizzying Swing"] = true,
    ["Wrecking Blow"] = true,
    -- World: Vampire
    ["Blood for Blood"] = true,
    -- World: Werewolf
    ["Light Attack (Werewolf)"] = true,
    -- Guild: Fighters Guild
    ["Dawnbreaker of Smiting"] = true,
    ["Flawless Dawnbreaker"] = true,
    -- Guild: Mages Guild
    ["Ice Comet"] = true,
    ["Shooting Star"] = true,
    -- Proc Sets: 5 pieces
    ["Anthelmir's Construct"] = true,
    ["Corpseburster"] = true,
    ["Deadlands Demolisher"] = true,
    ["Eagle's Mark"] = true,
    ["Gorethief"] = true,
    ["Hrothgar's Chill"] = true,
    ["Knight Slayer"] = true,
    ["Pyrebrand"] = true,
    ["Scavenging Maw"] = true,
    ["Sliver Assault"] = true,
    ["Tarnished Nightmare"] = true,
    ["Vicious Death"] = true,
    -- Proc Sets: Monster sets
    ["Maarselok"] = true,
    -- Proc Sets: Arena weapons
    ["Wrath of Elements"] = true,
}
local _SIGNATURE_ABILITIES -- [id] = {"main" = main ability id, "name" = ability name}

-- For mitigation measurement, id to player tooltip damage
local MEASURABLE_PLAYER_ABILITY_NAMES = {
    ["Bash"] = true,
    ["Light Attack (Bow)"] = true,
    ["Light Attack (Dual Wield)"] = true,
    ["Light Attack (Ice)"] = true,
    ["Light Attack (Inferno)"] = true,
    ["Light Attack (Lightning)"] = true,
    ["Light Attack (One Handed)"] = true,
    ["Light Attack (Restoration)"] = true,
    ["Light Attack (Two Handed)"] = true,
    ["Light Attack (Werewolf)"] = true,
}
local _MEASURABLE_PLAYER_ABILITIES -- [ability id] = ability name

local DEAD_ICON_PATH = "/esoui/art/icons/ability_mage_065.dds"

local function IsRealAbility(abilityId)
    if not DoesAbilityExist(abilityId) then
        return false
    end

    local icon = _GetAbilityIconCached(abilityId) or ""
    if icon == DEAD_ICON_PATH then
        return false
    end

    return true
end

local function BuildAbilityNameMap()
    local nameMap = {}
    local numAbilities = 0
    local lastAbilityId = 0
    local lastAbilityName = ""
    for abilityId = 1, 400000 do
        if IsRealAbility(abilityId) then
            local abilityName = GetAbilityName(abilityId, nil)
            local idList = nameMap[abilityName] or {}
            idList[#idList + 1] = abilityId
            nameMap[abilityName] = idList
            numAbilities = numAbilities + 1
            lastAbilityId = abilityId
            lastAbilityName = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("found %d abilities and %d names , last ability is %d %s",
            numAbilities, _CountTable(nameMap), lastAbilityId, lastAbilityName))
    end
    return nameMap
end

-- Find the main ability id we can use for showing a signature ability on UI
-- Need to be usable for tooltips
local function FindMainAbilityId(abilityIdList)
    -- Search from the back for the final/proc version, such as Crystal Fragments
    for index = #abilityIdList, 1, -1 do
        local abilityId = abilityIdList[index]
        local descr = GetAbilityDescription(abilityId, nil, "player")
        -- Reject empty text and templated text such as "... AB_MAGIC_DAMAGE ..."
        if descr ~= "" and not descr:find(" AB_", 1, true) then
            return abilityId
        end
    end
    return abilityIdList[1]
end

local function RebuildAbilityMaps()
    local nameToIdList = BuildAbilityNameMap()

    _ClearTable(_HIDDEN_ABILITIES)
    for abilityName in pairs(HIDDEN_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            _HIDDEN_ABILITIES[abilityId] = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt hidden ability map: %d",
            _CountTable(_HIDDEN_ABILITIES)))
    end

    _ClearTable(_TRACKED_DOT_ABILITIES)
    for abilityName in pairs(TRACKED_DOT_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            _TRACKED_DOT_ABILITIES[abilityId] = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt DoT ability map: %d",
            _CountTable(_TRACKED_DOT_ABILITIES)))
    end

    _ClearTable(_SIGNATURE_ABILITIES)
    for abilityName in pairs(SIGNATURE_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        local mainId = FindMainAbilityId(idList)
        for _, abilityId in ipairs(idList) do
            _SIGNATURE_ABILITIES[abilityId] = {
                ["main"] = mainId,
                ["name"] = abilityName,
            }
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt signature ability map: %d",
            _CountTable(_SIGNATURE_ABILITIES)))
    end

    _ClearTable(_MEASURABLE_PLAYER_ABILITIES)
    for abilityName in pairs(MEASURABLE_PLAYER_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            if GetAbilityDescription(abilityId, nil, "player") ~= "" then
                _MEASURABLE_PLAYER_ABILITIES[abilityId] = abilityName
            end
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt measurable player ability map: %d",
            _CountTable(_MEASURABLE_PLAYER_ABILITIES)))
    end
end

-------------------------------------------------------------------------------
-- Measure player damage abilities for calculating opponent mitigations
-------------------------------------------------------------------------------

-- Ability id to player damage value.
-- Value 0 means it needs updating.
-- Only listed abilities are considered measurable.
local _measurablePlayerDamageByAbility = {}

local function ExtractDamageFromAbilityDescription(description)
    if description == nil then
        return nil
    end

    local numberText = description:match("%d+")
    if numberText == nil then
        return nil
    end

    return tonumber(numberText)
end

local function ResetMeasurablePlayerDamage()
    _ClearTable(_measurablePlayerDamageByAbility)
    for abilityId in pairs(_MEASURABLE_PLAYER_ABILITIES) do
        _measurablePlayerDamageByAbility[abilityId] = 0
    end
end

local REG_PLAYER_ACTIVATED = "TacticalDisplay_Base_PlayerActivated"
local REG_BAR_SWAPPED = "TacticalDisplay_Base_BarSwapped"

local function RegisterPlayerUpdate()
    EVENT_MANAGER:RegisterForEvent(REG_PLAYER_ACTIVATED, EVENT_PLAYER_ACTIVATED, ResetMeasurablePlayerDamage)
    EVENT_MANAGER:RegisterForEvent(REG_BAR_SWAPPED, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, ResetMeasurablePlayerDamage)
end

local function UnregisterPlayerUpdate()
    EVENT_MANAGER:UnregisterForEvent(REG_PLAYER_ACTIVATED, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(REG_BAR_SWAPPED, EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
end

function _Base.GetMeasurablePlayerDamage(abilityId, abilityName)
    local damage = _measurablePlayerDamageByAbility[abilityId]
    if damage == nil then
        return nil
    elseif damage == 0 then
        local descr = GetAbilityDescription(abilityId, nil, "player")
        local newDamage = ExtractDamageFromAbilityDescription(descr)
        if newDamage ~= nil and newDamage > 0 then
            _measurablePlayerDamageByAbility[abilityId] = newDamage
            if _debugLog then
                _LogDebug(string.format("Refresh player ability %d %s = %d from: %s",
                    abilityId, abilityName, newDamage, descr))
            end
            return newDamage
        else
            _LogError(string.format("Failed to refresh player ability %d %s from: %s",
                abilityId, abilityName, descr))
            return nil
        end
    else
        return damage
    end
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Base.Initialize(savedVars)
    local serverName = GetWorldName()
    savedVars.base = savedVars.base or {}
    savedVars.base[serverName] = savedVars.base[serverName] or {}
    local db = savedVars.base[serverName]

    db.HIDDEN_ABILITIES = db.HIDDEN_ABILITIES or {}
    _HIDDEN_ABILITIES = db.HIDDEN_ABILITIES
    _Base.HIDDEN_ABILITIES = db.HIDDEN_ABILITIES

    db.TRACKED_DOT_ABILITIES = db.TRACKED_DOT_ABILITIES or {}
    _TRACKED_DOT_ABILITIES = db.TRACKED_DOT_ABILITIES
    _Base.TRACKED_DOT_ABILITIES = db.TRACKED_DOT_ABILITIES

    db.SIGNATURE_ABILITIES = db.SIGNATURE_ABILITIES or {}
    _SIGNATURE_ABILITIES = db.SIGNATURE_ABILITIES
    _Base.SIGNATURE_ABILITIES = db.SIGNATURE_ABILITIES

    db.MEASURABLE_PLAYER_ABILITIES = db.MEASURABLE_PLAYER_ABILITIES or {}
    _MEASURABLE_PLAYER_ABILITIES = db.MEASURABLE_PLAYER_ABILITIES
    _Base.MEASURABLE_PLAYER_ABILITIES = db.MEASURABLE_PLAYER_ABILITIES
end

local _enabled = false

function _Base.Enable()
    if _enabled then
        return
    end
    RegisterPlayerUpdate()
    _enabled = true
end

function _Base.Disable()
    if not _enabled then
        return
    end
    UnregisterPlayerUpdate()
    _enabled = false
end

function _Base.UpdateParameters(debug)
    _debugLog = debug
end

function _Base.RebuildDB()
    RebuildAbilityMaps()
    ResetMeasurablePlayerDamage()
end
