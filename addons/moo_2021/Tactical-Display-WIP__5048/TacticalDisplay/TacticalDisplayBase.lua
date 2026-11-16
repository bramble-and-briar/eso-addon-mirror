TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Base = TacticalDisplay.Base or {}
local _Base = TacticalDisplay.Base
local _LogError = TacticalDisplay.Utilities.LogError
local _LogDebug = TacticalDisplay.Utilities.LogDebug

local _debugLog        -- boolean
local _hiddenAbilities -- [ability id] = true
local _hiddenDOTs      -- [ability id] = ability name

local HIDDEN_ABILITIES = {
    -- Status effects
    [17897] = true,  -- "Frozen Weapon"
    [17899] = true,  -- "Charged Weapon"
    [17902] = true,  -- "Poisoned Weapon"
    [17904] = true,  -- "Befouled Weapon"
    [18084] = true,  -- "Burning"
    [20660] = true,  -- "Burning Embers"
    [21481] = true,  -- "Chilled"
    [21487] = true,  -- "Concussed"
    [21734] = true,  -- "Reflective Light" (Tick)
    [21925] = true,  -- "Diseased"
    [21929] = true,  -- "Poisoned"
    [23232] = true,  -- "Hurricane"
    [28919] = true,  -- "Life Drain"
    [31103] = true,  -- "Disintegrated Dragonfire .."
    [44373] = true,  -- "Burning Embers"
    [44549] = true,  -- "Poison Injection"
    [45445] = true,  -- "Forceful"
    [45584] = true,  -- "Soul Shatter"
    [46743] = true,  -- "Absorb Magicka"
    [46746] = true,  -- "Absorb Stamina"
    [46749] = true,  -- "Decrease Health"
    [62529] = true,  -- "Quick Cloak"
    [62951] = true,  -- "Blockage of Frost"
    [80170] = true,  -- "Burning Light"
    [80184] = true,  -- "Direwolf Lunge"
    [80189] = true,  -- "Direwolf Gnash"
    [80190] = true,  -- "Direwolf Gnash"
    [100218] = true, -- "Solar Barrage"
    [117854] = true, -- "Avid Boneyard"
    [118746] = true, -- "Deathbolt"
    [118766] = true, -- "Detonating Siphon"
    [147846] = true, -- "Wrath of Elements"
    [147847] = true, -- "Wrath of Elements"
    [148800] = true, -- "Sundered"
    [148801] = true, -- "Hemorrhaging"
    [148797] = true, -- "Overcharged"
    [215779] = true, -- "Diseased"
    [233041] = true, -- "Shared Pain"
    [258660] = true, -- "Molten Armaments"
    [258665] = true, -- "Igneous Weapons"
}

local VISIBLE_DOT_ABILITIES = {
    [17879] = true,  -- "Corrosive Armor"
    [126941] = true, -- "Maarselok"
    -- [226394] = true, -- "Pyrebrand"
}

local DOT_ACTION_RESULTS = {
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

-- Ability id to player damage value.
-- Value 0 means it needs updating.
-- Only listed abilities are considered measurable.
local _measurablePlayerDamageByAbility = {
    [15435] = 0, -- "Light Attack (One Handed)"
    [16037] = 0, -- "Light Attack (Two Handed)"
    [16145] = 0, -- "Light Attack (Restoration)"
    [16165] = 0, -- "Light Attack (Inferno)"
    [16277] = 0, -- "Light Attack (Ice)"
    [16499] = 0, -- "Light Attack (Dual Wield)"
    [16688] = 0, -- "Light Attack (Bow)"
    [18350] = 0, -- "Light Attack (Lightning)"
    [21970] = 0, -- "Bash"
    [32464] = 0, -- "Light Attack (Werewolf)"
}

local function ShallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

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
    for abl, _ in pairs(_measurablePlayerDamageByAbility) do
        _measurablePlayerDamageByAbility[abl] = 0
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

function _Base.Initialize(savedVars)
    savedVars.base = savedVars.base or {}
    savedVars.base.hiddenDOTs = savedVars.base.hiddenDOTs or {}

    _hiddenAbilities = ShallowCopy(HIDDEN_ABILITIES)
    _hiddenDOTs = savedVars.base.hiddenDOTs
    for abl, _ in pairs(_hiddenDOTs) do
        _hiddenAbilities[abl] = true
    end
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

function _Base.CheckHiddenAbility(actionResult, abilityId, abilityName)
    if _hiddenAbilities[abilityId] then
        return true
    end

    if DOT_ACTION_RESULTS[actionResult] and not VISIBLE_DOT_ABILITIES[abilityId] then
        _hiddenAbilities[abilityId] = true
        _hiddenDOTs[abilityId] = abilityName
        _LogDebug(string.format("Hide new DoT ability %d %s", abilityId, abilityName))
        return true
    end

    return false
end

function _Base.GetMeasurablePlayerDamage(abilityId, abilityName)
    local damage = _measurablePlayerDamageByAbility[abilityId]
    if damage == nil then
        return 0
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
        end
    else
        return damage
    end
end
