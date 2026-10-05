-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @kabs12[NA]
-- Created: May 5, 2018
--
-- Tracking.lua
-- -----------------------------------------------------------------------------

JHSetTrackers.Tracking           = {}
JHSetTrackers.Procs              = {}
JHSetTrackers.MajorMinorSets     = {}
JHSetTrackers.AdditionalIds      = {}
JHSetTrackers.PlayerPower        = {
	mag  = { current = 0, max = 0 },
	stam = { current = 0, max = 0 },
	ult  = 0,
  sets = {},
}
JHSetTrackers.SpaulderIds        = {
  [163357] = true,
  [163359] = true,
  [163401] = true,
  [163404] = true,
}
JHSetTrackers.SpaulderActive     = false
JHSetTrackers.spaulderName       = "Spaulder of Ruin"
JHSetTrackers.map                = ""
JHSetTrackers.ghostTime          = 0
local SUL_XAN_NAME      = "Sul-Xan's Torment"
local SUL_XAN_ID        = 154737 --154737 buff --157738 soul
local GHOST_ID          = 157738 --154737 buff --157738 soul
local EM                = EVENT_MANAGER
local updateIntervalMs  = 100
local time              = GetGameTimeMilliseconds
local WM                = GetWindowManager()
local LEB               = LibEquipmentBonus

-- ----------------------------------------------------------------------------
-- Callback Functions
-- ----------------------------------------------------------------------------

local function OnCooldownUpdated(setKey, eventCode, abilityId)
  -- When cooldown of this ability occurs, this function is continually called
  -- until the set is off cooldown.
  -- We can use the first call of this function to detect a proc state.

  local set = JHSetTrackers.Data.Sets[setKey]

  -- Ignore if set is on cooldown
  if set.onCooldown == true then return end

  set.timeOfProc = GetGameTimeMilliseconds()

  -- Delay proc time by the current frame duration if lag compensation is enabled
  -- This helps mitigate false procs when the set is seen as off cooldown,
  -- but the COOLDOWN_UPDATED event is still being called.
  -- This delay aims to let COOLDOWN_UPDATED finish, which can vary depending
  -- on lag conditions, before deeming the set as off cooldown.
  if JHSetTrackers.preferences.lagCompensation then
    -- Add current frame delta - does NOT account for wide variances/spikes
    set.timeOfProc = set.timeOfProc + GetFrameDeltaTimeMilliseconds()
  end

  if set.cooldownDurationMs ~= 0 then set.onCooldown = true end
  do local p = JHSetTrackers.preferences and JHSetTrackers.preferences.sets and JHSetTrackers.preferences.sets[setKey]; if p and p.sounds and p.sounds.onProc then JHSetTrackers.UI.PlaySound(p.sounds.onProc) end end
  EM:RegisterForUpdate(JHSetTrackers.name .. setKey .. "Count", updateIntervalMs, function(...) JHSetTrackers.UI.Update(setKey) return end)

  JHSetTrackers:Trace(1, "Cooldown proc for <<1>> (<<2>>)", setKey, abilityId)
end

local function OnCombatEvent(setKey, _, result, _, abilityName, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)

  local set = JHSetTrackers.Data.Sets[setKey]

  if JHSetTrackers.AdditionalIds[setKey] then
    if abilityId == JHSetTrackers.AdditionalIds[setKey][2] then
      local a = JHSetTrackers.Data.ReleaseTriggers[setKey]

      if result ~= a.result then return end

      set.endTime = GetGameTimeMilliseconds()

      EM:UnregisterForUpdate( JHSetTrackers.name .. setKey .. "Count")
      EM:RegisterForUpdate(   JHSetTrackers.name .. setKey .. "Count", updateIntervalMs, function(...) JHSetTrackers.UI.Update(setKey) return end)
      JHSetTrackers.UI.Update(setKey)

      JHSetTrackers:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>>. secondary set id.", abilityName, abilityId, result)
      return
    end
  end

  if JHSetTrackers.SpaulderIds[abilityId] then -- Spaulder of Ruin
    JHSetTrackers:Trace(1, "Spaulder: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)
    return
  end

  if result == ACTION_RESULT_ABILITY_ON_COOLDOWN then
    JHSetTrackers:Trace(1, "<<1>> (<<2>>) on Cooldown", abilityName, abilityId)
  elseif result == set.result or (type(set.result) == "table" and JHSetTrackers.HasValue(set.result, result)) then
    -- Arkasis-style duplicate trigger guard.
    if set.onCooldown and set.cooldownDurationMs and set.cooldownDurationMs > 0 then
      local elapsed = GetGameTimeMilliseconds() - (set.timeOfProc or 0)
      if elapsed >= 0 and elapsed < set.cooldownDurationMs then return end
    end
    if set.id == 147462 or set.id == 193411 then -- Pearls and esoteric
      JHSetTrackers.Procs[setKey].times = JHSetTrackers.Procs[setKey].times + 1
      JHSetTrackers.UI.UpdateProcs(setKey)
      do local p = JHSetTrackers.preferences and JHSetTrackers.preferences.sets and JHSetTrackers.preferences.sets[setKey]; if p and p.sounds and p.sounds.onProc then JHSetTrackers.UI.PlaySound(p.sounds.onProc) end end
      JHSetTrackers:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)
      return
    end

    JHSetTrackers:Trace(1, "(+)Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)

    if set.cooldownDurationMs ~= 0 then set.onCooldown = true end

    set.timeOfProc = GetGameTimeMilliseconds()
    set.endTime    = set.timeOfProc + set.durationms
    do local p = JHSetTrackers.preferences and JHSetTrackers.preferences.sets and JHSetTrackers.preferences.sets[setKey]; if p and p.sounds and p.sounds.onProc then JHSetTrackers.UI.PlaySound(p.sounds.onProc) end end
    EM:UnregisterForUpdate( JHSetTrackers.name .. setKey .. "Count")
    EM:RegisterForUpdate(   JHSetTrackers.name .. setKey .. "Count", updateIntervalMs, function(...) JHSetTrackers.UI.Update(setKey) return end)
    JHSetTrackers.UI.Update(setKey)
  else
    JHSetTrackers:Trace(1, "(-)Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)
  end
end

local function UpdateEffectState(setKey, onCooldown)

end

local function OnEffectChanged(setKey, _, change, _, effectName, unitTag, beginTime, endTime, stackCount, _, _, _, _, _, _, _, abilityId)

  local set = JHSetTrackers.Data.Sets[setKey]

  if set == nil then return end

  local c   = WM:GetControlByName(setKey .. "_Container")
  -- local ec  = ""

  if change == EFFECT_RESULT_FADED then
    stackCount = 0
    JHSetTrackers:Trace(1, "<<1>> (<<2>>): Faded", effectName, abilityId)

    -- set.endTime = time() / 1000

  elseif change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then

    local dur = string.format("%.1f", endTime - beginTime)

    if change == EFFECT_RESULT_GAINED then
      JHSetTrackers:Trace(1, "<<1>> (<<2>>): Gained => <<3>> (<<4>>)", effectName, abilityId, dur, stackCount)
    else
      JHSetTrackers:Trace(1, "<<1>> (<<2>>): Updated => <<3>> (<<4>>)", effectName, abilityId, dur, stackCount)
    end

    if set.onCooldown and set.onCooldown == true then
      set.onCooldown = false
      do local p = JHSetTrackers.preferences and JHSetTrackers.preferences.sets and JHSetTrackers.preferences.sets[setKey]; if p and p.sounds and p.sounds.onProc then JHSetTrackers.UI.PlaySound(p.sounds.onProc) end end
    end
    set.timeOfProc = time()

    -- Death Dealer's Fete is stacks-only: never enter the generic effect timer path.
    if setKey == "Death Dealer's Fete" then
      set.stacks = stackCount or 0
      JHSetTrackers.UI.UpdateDDFStacks(set.stacks)
      return
    end

    if set.durationms > 0 then
      set.endTime = endTime
      EM:RegisterForUpdate(JHSetTrackers.name .. setKey .. "Count", updateIntervalMs, function(...) JHSetTrackers.UI.UpdateEffect(setKey) end)
    end
    JHSetTrackers.UI.UpdateEffect(setKey)
  end

  set.stacks = stackCount
  if c.stacks then
    if set.stacks > 0
    then c.stacks:SetText(set.stacks)
    else c.stacks:SetText("") end
  end
end

-- (eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
local function OnCombatCooldownEvent(setKey, _, result, _, abilityName, _, _, _, sourceType, _, targetType, hitValue, _, _, _, _, _, abilityId)

  local set = JHSetTrackers.Data.Sets[setKey]

  JHSetTrackers:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>>, hit value <<4>>. <<5>> => <<6>>", abilityName, abilityId, result, hitValue, sourceType, targetType)

  if set == nil then return end

  if abilityId == set.cooldownTrigger.id then
    if result == set.cooldownTrigger.result then
      set.cdStart     = time()
      set.cdEnd       = (time() + hitValue) / 1000
      set.onCooldown  = true
      JHSetTrackers.UI.UpdateEffect(setKey)
    elseif result == ACTION_RESULT_EFFECT_FADED then
      -- set.onCooldown  = false
      JHSetTrackers.UI.PlaySound(JHSetTrackers.preferences.sets[setKey].sounds.onReady)
      set.cdStart     = 0
      set.cdEnd       = 0
      JHSetTrackers.UI.UpdateEffect(setKey)
    end
  end
end

local function OnPowerUpdate(setKey, eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
  local set = JHSetTrackers.Data.Sets[setKey]
  local percent = (powerValue / powerEffectiveMax) * 100

  if powerType == POWERTYPE_MAGICKA then
    JHSetTrackers.PlayerPower.mag.max = powerEffectiveMax
    JHSetTrackers.PlayerPower.mag.current = percent
  elseif powerType == POWERTYPE_STAMINA then
    JHSetTrackers.PlayerPower.stam.max = powerEffectiveMax
    JHSetTrackers.PlayerPower.stam.current = percent
  elseif powerType == POWERTYPE_ULTIMATE then
    JHSetTrackers.PlayerPower.ult = percent
  end

  if powerType == set.powerType then
    set.currentValue = percent
    JHSetTrackers.UI.UpdatePower(setKey)
  end
end

local function OnPowerUpdateForProcs(_, _, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
  if powerType == POWERTYPE_MAGICKA then
    JHSetTrackers.PlayerPower.mag.max = powerEffectiveMax
    JHSetTrackers.PlayerPower.mag.current = (powerValue / powerEffectiveMax) * 100
  elseif powerType == POWERTYPE_STAMINA then
    JHSetTrackers.PlayerPower.stam.max = powerEffectiveMax
    JHSetTrackers.PlayerPower.stam.current = (powerValue / powerEffectiveMax) * 100
  elseif powerType == POWERTYPE_ULTIMATE then
    JHSetTrackers.PlayerPower.ult = (powerValue / powerEffectiveMax) * 100
  end

  for i, x in pairs(JHSetTrackers.Procs) do
    local set = JHSetTrackers.Procs[i]
    if set then
      if set.id == 147462 then
        if JHSetTrackers.PlayerPower.mag.max < JHSetTrackers.PlayerPower.stam.max then
          set.powerType = POWERTYPE_STAMINA
          set.current   = JHSetTrackers.PlayerPower.stam.current
          set.max       = JHSetTrackers.PlayerPower.stam.max
        else
          set.powerType = POWERTYPE_MAGICKA
          set.current   = JHSetTrackers.PlayerPower.mag.current
          set.max       = JHSetTrackers.PlayerPower.mag.max
        end
        if set.powerType == powerType then
          set.current = (powerValue / powerEffectiveMax) * 100
          set.max = powerEffectiveMax
        end
      end
      if set.id == 193411 then
          set.powerType = POWERTYPE_STAMINA
          set.current   = JHSetTrackers.PlayerPower.stam.current
          set.max       = JHSetTrackers.PlayerPower.stam.max
        if set.powerType == powerType then
          set.current = (powerValue / powerEffectiveMax) * 100
          set.max = powerEffectiveMax
        end
      end
      JHSetTrackers.UI.UpdateProcs(i)
    end
  end
end

local function OnCombatEnd()
  if IsUnitInCombat("player") then
    JHSetTrackers:Trace(2, "Waiting for Combat to end")
    return
  end

  if (not IsUnitInCombat("player") and not JHSetTrackers.isInCombat) then
    EM:UnregisterForUpdate(JHSetTrackers.name .. "CombatEnded")
    zo_callLater(function()
      if IsUnitInCombat("player") then
        EM:RegisterForUpdate(JHSetTrackers.name .. "CombatEnded", 2000, OnCombatEnd)
        return
      end

      JHSetTrackers.UI:ResetProcs()
      JHSetTrackers:Trace(2, "Combat End.")
    end, 3000)
  end
end

local function IsInCombat(_, inCombat)
  JHSetTrackers.isInCombat = inCombat
  JHSetTrackers:Trace(2, "In Combat: <<1>>", tostring(inCombat))
  JHSetTrackers.UI:SetCombatStateDisplay()
  if IsUnitInCombat("player") then
    zo_callLater(function()
      EM:UnregisterForUpdate(JHSetTrackers.name .. "CombatEnded")
      EM:RegisterForUpdate(JHSetTrackers.name .. "CombatEnded", 3000, OnCombatEnd)
    end, 1000)
  end
end

local function OnAlive()
  JHSetTrackers.isDead = false
  JHSetTrackers.UI:SetCombatStateDisplay()
end

local function OnDeath()
  JHSetTrackers.isDead = true
  JHSetTrackers.UI:SetCombatStateDisplay()
end

local function OnPlayerActivated(_, initial)

  if not initial then
    local cs, stam, _ = GetUnitPower("player", POWERTYPE_STAMINA)
    local cm,  mag, _ = GetUnitPower("player", POWERTYPE_MAGICKA)
    local um,  ult, _ = GetUnitPower("player", POWERTYPE_ULTIMATE)

    JHSetTrackers.PlayerPower.stam.max     = stam
    JHSetTrackers.PlayerPower.mag.max      = mag
    JHSetTrackers.PlayerPower.ult          = (um / ult)  * 100
    JHSetTrackers.PlayerPower.stam.current = (cs / stam) * 100
    JHSetTrackers.PlayerPower.mag.current  = (cm / mag)  * 100

    for key in pairs(JHSetTrackers.MajorMinorSets) do
      local set = JHSetTrackers.Data.Sets[key]
      if set ~= nil and JHSetTrackers.Data.Sets[key].enabled then
        if set.powerType == POWERTYPE_STAMINA then
          set.currentValue = JHSetTrackers.PlayerPower.stam.current
        elseif set.powerType == POWERTYPE_MAGICKA then
          set.currentValue = JHSetTrackers.PlayerPower.mag.current
        elseif set.powerType == POWERTYPE_ULTIMATE then
          set.currentValue = JHSetTrackers.PlayerPower.ult
        end

				JHSetTrackers.UI.UpdatePower(key)
      end
    end
  end
end

local function OnJorvuld()
  for i, x in pairs(JHSetTrackers.MajorMinorSets) do
    local set = JHSetTrackers.MajorMinorSets[i]
    if set then
      current, max, effective = GetUnitPower("player", JHSetTrackers.Data.Sets[i].powerType)
      JHSetTrackers.Data.Sets[i].currentValue = (current / effective) * 100
      JHSetTrackers.UI.UpdatePower(i)
    end
  end
end

local function OnCombatEventUnfiltered(_, result, _, abilityName, _, _, _, _, _, hitValue, _, _, _, _, _, _, abilityId)
  -- Exclude common unnecessary abilities

  -- if GetAbilityDuration(abilityId) == 0 then return end

  local ignoreList = {
    sprint          = 973,
    sprintDrain     = 15356,
    interrupt       = 55146,
    roll            = 28549,
    immov           = 29721,
    phase           = 98294,
    dodgeFatigue    = 69143,
    sneak           = 20299,
    hide            = 20307, -- trying to hide
    hidden          = 20309,
    clairvoyanceFx  = 76463,
    -- LongShots       = 30937,
    -- Accuracy        = 30930,
    -- Accuracy2       = 45492,
    -- Ranger          = 30942,
    -- Ranger2         = 45493,
    -- HawkEye         = 30936,
    -- HawkEye2        = 45497,
    -- LongShots       = 45494,
    -- HastyRetreat    = 30923,
    -- HastyRetreat2   = 45498,
    -- LightAttackBow  = 16688
    -- DualWieldExpert = 30873,
    -- DualWieldExpert2  = 45477,
    -- Slaughter       = 18929,
    -- ControlledFury  = 30872,
    -- Ruffian         = 21114,
    -- Gryphon's Reprisal (167041) with result 2240, hit value 1

    -- Gryphon's Reprisal (167043) with result 2240, hit value 0
    -- Gryphon's Reprisal (167043) with result 2245, hit value 0

    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2245, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Flowing Water (167350) with result 2240, hit value 1
    -- Flowing Water (167350) with result 2245, hit value 1

    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Bash (21970) with result 2, hit value 0

    -- Turning Tide (167062) with result 1, hit value 0
    -- Major Vulnerability (167061) with result 2240, hit value 0
    -- Major Vulnerability (106754) with result 2240, hit value 0
    -- Major Vulnerability (167061) with result 2245, hit value 0
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
    -- Gryphon's Reprisal (167042) with result 2240, hit value 1

    -- Gryphon's Reprisal (167042) with result 2240, hit value 1

    -- Gryphon's Reprisal (167042) with result 2240, hit value 1

    -- Gryphon's Reprisal (167042) with result 2240, hit value 1
  }

  for index, value in pairs(ignoreList) do
    if abilityId == value then return end
  end

  -- if abilityId < 92700 or abilityId > 93000 then return end

  JHSetTrackers:Trace(1, "<<1>> (<<2>>) with result <<3>>, hit value <<4>>", abilityName, abilityId, result, hitValue)
end

local function OnEffectChangedUnfiltered(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
  -- Exclude common unnecessary abilities
  local ignoreList = {
    sprint          = 973,
    sprintDrain     = 15356,
    interrupt       = 55146,
    roll            = 28549,
    immov           = 29721,
    phase           = 98294,
    dodgeFatigue    = 69143,
    sneak           = 20299,
    hide            = 20307, -- trying to hide
    hidden          = 20309,
    clairvoyanceFx  = 76463,
  }

  for index, value in pairs(ignoreList) do
    if abilityId == value then return end
  end

  JHSetTrackers:Trace(1, "<<1>> (<<2>>) with change type <<3>> by <<4>>\n<<5>>", effectName, abilityId, changeType, sourceType, iconName)
end

-- ----------------------------------------------------------------------------
-- Event Register/Unregister
-- ----------------------------------------------------------------------------
function JHSetTrackers.Tracking.RegisterUnfiltered()
  --EM:RegisterForEvent(JHSetTrackers.name .. "_UnfilteredEffect", EVENT_EFFECT_CHANGED, OnEffectChangedUnfiltered)
  --EM:AddFilterForEvent(JHSetTrackers.name .. "_UnfilteredEffect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  EM:RegisterForEvent(JHSetTrackers.name .. "_Unfiltered", EVENT_COMBAT_EVENT, OnCombatEventUnfiltered)
  EM:AddFilterForEvent(JHSetTrackers.name .. "_Unfiltered", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  JHSetTrackers:Trace(1, "Registered Unfiltered Events")
end

function JHSetTrackers.Tracking.UnregisterUnfiltered()
  EM:UnregisterForEvent(JHSetTrackers.name .. "_Unfiltered", EVENT_COMBAT_EVENT)
  JHSetTrackers:Trace(1, "Unregistered Unfiltered Events")
end

function JHSetTrackers.Tracking.RegisterEvents()
  EM:RegisterForEvent(JHSetTrackers.name, EVENT_PLAYER_ALIVE, OnAlive)
  EM:RegisterForEvent(JHSetTrackers.name, EVENT_PLAYER_DEAD, OnDeath)

  EM:RegisterForEvent(JHSetTrackers.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

  JHSetTrackers.Tracking.RegisterCombatEvent()

  JHSetTrackers:Trace(2, "Registered Events")
end

function JHSetTrackers.Tracking.UnregisterEvents()
  EM:UnregisterForEvent(JHSetTrackers.name, EVENT_PLAYER_ALIVE)
  EM:UnregisterForEvent(JHSetTrackers.name, EVENT_PLAYER_DEAD)
  JHSetTrackers:Trace(2, "Unregistered Events")
end

function JHSetTrackers.Tracking.RegisterCombatEvent()
  EM:RegisterForEvent(JHSetTrackers.name .. "COMBAT", EVENT_PLAYER_COMBAT_STATE, IsInCombat)
  JHSetTrackers:Trace(2, "Registered combat events")
end

function JHSetTrackers.Tracking.UnregisterCombatEvent()
  EM:UnregisterForEvent(JHSetTrackers.name .. "COMBAT", EVENT_PLAYER_COMBAT_STATE)
  JHSetTrackers:Trace(2, "Unregistered combat events")
end

local spaulder    = {
  proc  = 163359, -- Aura of Pride
  aura  = 163401, -- Aura of Pride
  -- price = 163404, -- price of pride
  -- [163357] = true, -- Spaulder of Ruin
}
local resultNames = {
  [ACTION_RESULT_EFFECT_GAINED]           = "Gained",
  [ACTION_RESULT_EFFECT_GAINED_DURATION]  = "Gained Duration",
  [ACTION_RESULT_EFFECT_FADED]            = "Faded",
}
local activeNames = {
  [ACTION_RESULT_EFFECT_GAINED] = "Active",
  [ACTION_RESULT_EFFECT_FADED]  = "Inactive"
}

local function ClearSpaulderUnit(setKey, id)
  local c = JHSetTrackers.Controls[setKey]
  local s = JHSetTrackers.Data.Sets[setKey]
  if not s.units[id] then return end
  local t = s.units[id]
  local T = time() - t

  if (T < 2100) then return end

  s.units[id] = nil
  s.count = s.count - 1

  if s.count < 0 then set.count = 0 end

  JHSetTrackers.UI.UpdateToggled(setKey, nil)

  JHSetTrackers:Trace(2, "Spaulder Units(<<1>>) faded #<<2>>.", id, s.count)
end

local function OnSpaulder(setKey, _, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, sourceId, targetId, abilityId)

  local isActive

  if targetType == COMBAT_UNIT_TYPE_PLAYER then
    JHSetTrackers.playerID = targetId
  end

  local isSource = sourceId == JHSetTrackers.playerID and true or false
  local isTarget = targetId == JHSetTrackers.playerID and true or false

  if (abilityId == spaulder.proc --[[or abilityId == spaulder.price]]) then

    local r
    if resultNames[result] then r = resultNames[result] else r = tostring(result) end

    local state = JHSetTrackers.Data.Sets[setKey].active

    if (isTarget and result == ACTION_RESULT_EFFECT_FADED) then
      isActive = false
      JHSetTrackers.UI.UpdateToggled(setKey, false)
      JHSetTrackers:Trace(2, "Spaulder (<<1>>): <<2>> -> <<3>>. source: <<4>>. target: <<5>>", abilityId, activeNames[result], r, sourceId, targetId)

    elseif (isSource and result == ACTION_RESULT_EFFECT_GAINED) then
      isActive = true
      JHSetTrackers.UI.UpdateToggled(setKey, true)
      JHSetTrackers:Trace(2, "Spaulder (<<1>>): <<2>> -> <<3>>. source: <<4>>. target: <<5>>", abilityId, activeNames[result], r, sourceId, targetId)

    else return end

  elseif (abilityId == spaulder.aura and not isTarget) then

    local set = JHSetTrackers.Data.Sets[setKey]

    if result == ACTION_RESULT_EFFECT_FADED then

      if (isSource and set.units[targetId]) then
        ClearSpaulderUnit(setKey, targetId)
        JHSetTrackers.UI.UpdateToggled(setKey, nil)
      end

    elseif (result == ACTION_RESULT_EFFECT_GAINED) then
      if isSource then
        if not set.units[targetId] then
          set.units[targetId] = 0
          set.count = set.count + 1
          JHSetTrackers.UI.UpdateToggled(setKey, true)
          JHSetTrackers:Trace(2, "Spaulder Units(<<1>>) gained #<<3>>.", targetId, set.count)
        end
        set.units[targetId] = time()

      else
        if set.units[targetId] then
          ClearSpaulderUnit(setKey, targetId)
        end
        JHSetTrackers:Trace(2, 'Spaulder(' .. abilityId .. ') result(' .. tostring(result) .. ') on: ' .. targetName .. '(' .. targetId .. ') from: ' .. sourceName .. '(' .. sourceId .. ')')
      end
    end
  end
end

local function ShouldUseLastState(set)
  local sameState   = false
  local sameFactors = 0

  local m = GetMapName()
  local n = GetUnitName("player")

  if m == JHSetTrackers.preferences.map            then sameFactors = sameFactors + 1 end
  if n == JHSetTrackers.preferences.lastCharacter  then sameFactors = sameFactors + 1 end

  if sameFactors == 2 then sameState = true end

  JHSetTrackers.preferences.map            = m
  JHSetTrackers.preferences.lastCharacter  = n
  return sameState
end

function JHSetTrackers.Tracking.TrackSpaulder(track)

  local state = "Off"

  -- unregister events
  for k, v in pairs(spaulder) do
    EM:UnregisterForEvent(JHSetTrackers.name .. "_Spaulder" .. v, EVENT_COMBAT_EVENT)
  end

  EM:UnregisterForEvent(JHSetTrackers.name .. "_SpaulderActivated", EVENT_PLAYER_ACTIVATED)
  EM:UnregisterForUpdate(JHSetTrackers.name .. "_SpaulderUnitCheck")

  -- reset units being buffed by player.
  local set = JHSetTrackers.Data.Sets[JHSetTrackers.spaulderName]
  set.units = {}
  set.count = 0

  -- refresh events
  if track then

    state = "On"

    -- check if player traveled, in which case the game would deactivate the set.
    EM:RegisterForEvent(JHSetTrackers.name .. "_SpaulderActivated", EVENT_PLAYER_ACTIVATED, function(eventCode, initial)
      if initial then
        JHSetTrackers.preferences.spaulderActive = false
        JHSetTrackers.preferences.map            = GetMapName()
        JHSetTrackers.preferences.lastCharacter  = GetUnitName("player")
      else
        if not ShouldUseLastState(set) then JHSetTrackers.preferences.spaulderActive = false end
        set.units = {}
        set.count = 0
      end
      JHSetTrackers.UI.UpdateToggled(JHSetTrackers.spaulderName, JHSetTrackers.preferences.spaulderActive)
    end)

    -- check for events with id's of: set toggled on, buff gained and recovery debuff from units being buffed.
    for k, v in pairs(spaulder) do
      EM:RegisterForEvent(JHSetTrackers.name .. "_Spaulder" .. v, EVENT_COMBAT_EVENT, function(...) OnSpaulder(JHSetTrackers.spaulderName, ...) end)
      EM:AddFilterForEvent(JHSetTrackers.name .. "_Spaulder" .. v,
        REGISTER_FILTER_ABILITY_ID, v,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
      )
    end

    EM:RegisterForUpdate(JHSetTrackers.name .. "_SpaulderUnitCheck", 2000, function()
      if set.count > 0 then
        for unit in pairs(set.units) do
          if unit then ClearSpaulderUnit(JHSetTrackers.spaulderName, unit) end
        end
      end
    end)

  else

    -- JHSetTrackers.preferences.spaulderActive = false

  end

  JHSetTrackers:Trace(1, "Tracking for Spaulder: <<1>>", state)
end

local function OnSoulSpawn(setKey, _, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId, abilityId)

  if result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == GHOST_ID and sourceType == COMBAT_UNIT_TYPE_PLAYER then
    JHSetTrackers.ghostTime = time() + hitValue
  end
end

local function TrackSoulSpawn(track, key)

  EM:UnregisterForEvent(JHSetTrackers.name .. "_SoulSpawn", EVENT_COMBAT_EVENT)
  EM:UnregisterForUpdate(JHSetTrackers.name .. "_SoulTimer")

  if track then

    local set = JHSetTrackers.Data.Sets[key]

    if set.id == SUL_XAN_ID then SUL_XAN_NAME = key end

    EM:RegisterForEvent(  JHSetTrackers.name .. "_SoulSpawn", EVENT_COMBAT_EVENT, function( ... ) OnSoulSpawn( SUL_XAN_NAME, ... ) end )
    EM:AddFilterForEvent( JHSetTrackers.name .. "_SoulSpawn",
      REGISTER_FILTER_ABILITY_ID, GHOST_ID,
      REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
    )

    EM:RegisterForUpdate(JHSetTrackers.name .. "_SoulTimer", 50, function()

      local set = JHSetTrackers.Data.Sets[SUL_XAN_NAME]
      local c   = JHSetTrackers.Controls[SUL_XAN_NAME]
      if set == nil or c == nil or c.bar == nil or JHSetTrackers.ghostTime == nil then return end
      local bar = c.bar
      local t   = JHSetTrackers.ghostTime - time()

      if set.timeOfProc > (JHSetTrackers.ghostTime - 6600) then
        bar:SetHidden(true)
      else
        bar:SetHidden(false)
        bar:SetValue(t / 6600)
      end
    end )
  end
end

function JHSetTrackers.Tracking.GetActiveBuffs()
  local buffs = GetNumBuffs('player')
  local ts    = tostring

  if buffs > 0 then

    for i = 1, buffs do
      local name, startTime, endTime, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, id, canClickOff, castByPlayer = GetUnitBuffInfo('player', i)
      d(name .. " (" .. id .. ")" .. ": " .. endTime - startTime)
    end
  else
    d("No active Buffs")
  end
end

function JHSetTrackers.Tracking.UpdateSetBuffInfo(key)
  local set = JHSetTrackers.Data.Sets[key]

  if set == nil then return end

  local c       = JHSetTrackers.Controls[key]
  local hasBuff = false
  local stacks  = 0

  for i = 1, GetNumBuffs('player') do
    local name, startTime, endTime, _, stackCount, _, _, _, _, _, id, _, _ = GetUnitBuffInfo('player', i)
    if id == set.id then
      set.endTime = endTime
      stacks      = stackCount or 0
      hasBuff     = true
      break
    end
  end

  if c ~= nil then
    EM:UnregisterForUpdate(JHSetTrackers.name .. key .. "Count")
    if hasBuff then
      -- if not c.isUpdating then
        c.isUpdating = true
        EM:RegisterForUpdate(JHSetTrackers.name .. key .. "Count", 100, function(...) JHSetTrackers.UI.UpdateEffect(key) end)
      -- end
      JHSetTrackers.UI.UpdateEffect(key)
    else
      -- set.endTime = 0
      if c.label then c.label:SetText("") end
    end
    if c.stacks then
      set.stacks = stacks
      if key == "Death Dealer's Fete" then
        JHSetTrackers.UI.UpdateDDFStacks(set.stacks)
      elseif set.stacks > 0 then
        c.stacks:SetText(set.stacks)
      else
        c.stacks:SetText("")
      end
    end
  end
end

local pendingInactive = {}
function JHSetTrackers.Tracking.UpdateTrackingStateForEffect(setKey, enabled)

  local set = JHSetTrackers.Data.Sets[setKey]

  EM:UnregisterForEvent(JHSetTrackers.name .. "_" .. set.id, set.event)

  -- local oldState = ""
  -- if pendingInactive[setKey] then
  --   pendingInactive[setKey] = nil
  --   oldState = "On"
  -- else
  --   oldState = "Off"
  -- end

  if enabled then
    local procFunction = OnEffectChanged
    EM:RegisterForEvent(  JHSetTrackers.name .. "_" .. set.id, set.event, function(...) procFunction(setKey, ...) end)
    EM:AddFilterForEvent( JHSetTrackers.name .. "_" .. set.id, set.event,
    REGISTER_FILTER_ABILITY_ID, set.id,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    set.enabled = true
    JHSetTrackers.UI.Draw(setKey)

  else
    -- if JHSetTrackers.UI.IsSetInactive(setKey) then
      -- local c   = WM:GetControlByName(setKey .. "_Container")
      -- c.isUpdating = false
      JHSetTrackers.UI.Draw(setKey)
    -- end
  end

  JHSetTrackers.Tracking.UpdateSetBuffInfo(setKey)

  if set.cooldownTrigger then
    local cdFunction = nil
    local cd = set.cooldownTrigger

    if cd.event == EVENT_EFFECT_CHANGED
    then cdFunction = OnEffectCooldownChanged
    else cdFunction = OnCombatCooldownEvent end

    EM:UnregisterForEvent(JHSetTrackers.name .. "_" .. cd.id, cd.event)

    if enabled then
      EM:RegisterForEvent(JHSetTrackers.name .. "_" .. cd.id, cd.event, function(...) cdFunction(setKey, ...) end)
      EM:AddFilterForEvent(JHSetTrackers.name .. "_" .. cd.id, cd.event,
      REGISTER_FILTER_ABILITY_ID, cd.id,
      REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
  end

  -- local newState = ""
  -- if enabled then newState = "On" else newState = "Off" end
  -- d(setKey .. ": " .. oldState .. " => " .. newState)
end

function JHSetTrackers.Tracking.HideTrackerWhenInactive(setKey)

  if JHSetTrackers.UI.IsSetInactive(setKey) then
    JHSetTrackers.Tracking.UpdateTrackingStateForEffect(setKey, false)
  else

    -- JHSetTrackers.Tracking.UpdateSetBuffInfo(setKey)

    EM:RegisterForUpdate(JHSetTrackers.name .. "Status" .. setKey, 500, function()

      if JHSetTrackers.Data.Sets[setKey].enabled then
        EM:UnregisterForUpdate(JHSetTrackers.name .. "Status" .. setKey)
        return
      end

      if JHSetTrackers.UI.IsSetInactive(setKey) then
        EM:UnregisterForUpdate(JHSetTrackers.name .. "Status" .. setKey)
        JHSetTrackers.Tracking.UpdateTrackingStateForEffect(setKey, false)
      end
    end)
  end
end

-- ----------------------------------------------------------------------------
-- Utility Functions
-- ----------------------------------------------------------------------------

local function RenameWhenPerfectSet(setKey)
  -- Check for Perfect/Perfected
  local isPerfect = string.find(setKey, "Perfect")

  -- Only if a perfect set is suspect do we run through
  -- our table of "Perfect" strings to replace
  if isPerfect ~= nil and isPerfect > 0 then
    JHSetTrackers:Trace(3, "Perfect suspect, string matches: <<1>>", isPerfect)

    -- Normalize Perfect and Non-Perfect variant names
    for _, perfectString in ipairs(JHSetTrackers.Data.PerfectString) do

      -- Find strings related to being Perfect
      local newSetKey, count = string.gsub(setKey, perfectString, "")

      -- Update name if a perfect version is detected
      if count > 0 then
        JHSetTrackers:Trace(1, "Found <<1>> version of <<2>>", perfectString, newSetKey)
        return newSetKey
      end

      JHSetTrackers:Trace(3, "Perfect suspect, but no match for \"<<1>>\"", perfectString)
    end
  end

  -- Return unmodified if perfect could not be matched
  return setKey
end

local function UpdateCurrentResources()
  local cs, stam, _ = GetUnitPower("player", POWERTYPE_STAMINA)
  local cm,  mag, _ = GetUnitPower("player", POWERTYPE_MAGICKA)
  local um,  ult, _ = GetUnitPower("player", POWERTYPE_ULTIMATE)
  JHSetTrackers.PlayerPower.stam.max     = stam
  JHSetTrackers.PlayerPower.mag.max      = mag
  JHSetTrackers.PlayerPower.ult          = (um / ult)  * 100
  JHSetTrackers.PlayerPower.stam.current = (cs / stam) * 100
  JHSetTrackers.PlayerPower.mag.current  = (cm / mag)  * 100
end

function JHSetTrackers.Tracking.EnableSynergiesFromPrefs()
  for key, enable in pairs(JHSetTrackers.character.synergy) do
    if enable == true then JHSetTrackers.Tracking.EnableTrackingForSet(key, true) end
  end
end

function JHSetTrackers.Tracking.EnablePassivesFromPrefs()
  for key, enable in pairs(JHSetTrackers.character.passive) do
    if enable == true then JHSetTrackers.Tracking.EnableTrackingForSet(key, true) end
  end
end

function JHSetTrackers.Tracking.EnableCPFromPrefs()
  for key, enable in pairs(JHSetTrackers.character.champion) do
    if enable == true then JHSetTrackers.Tracking.EnableTrackingForSet(key, true) end
  end
  return false
end
function JHSetTrackers.HasValue (table, val)
  for index, value in ipairs(table) do
      if value == val then
          return true
      end
  end
  return false
end

function JHSetTrackers.Tracking.EnablePowerUpdatesForProcSet(setKey)
  local set = JHSetTrackers.Data.Sets[setKey]

  UpdateCurrentResources()

  -- currently only for tracking Pearls of Ehlnofey and Esoteric Environment Greaves
  if set.id == 147462 then
    local p, c, m

    if JHSetTrackers.PlayerPower.stam.max > JHSetTrackers.PlayerPower.mag.max then
      p = POWERTYPE_STAMINA
      c = JHSetTrackers.PlayerPower.stam.current
      m = JHSetTrackers.PlayerPower.stam.max
    else
      p = POWERTYPE_MAGICKA
      c = JHSetTrackers.PlayerPower.mag.current
      m = JHSetTrackers.PlayerPower.mag.max
    end

    local x = { id = set.id, times = 0, powerType = p, current = c, max = m }
    JHSetTrackers.Procs[setKey] = x
  end
  
  if set.id == 193411 then
    local p, c, m
    p = POWERTYPE_STAMINA
    c = JHSetTrackers.PlayerPower.stam.current
    m = JHSetTrackers.PlayerPower.stam.max
    local x = { id = set.id, times = 0, powerType = p, current = c, max = m }
    JHSetTrackers.Procs[setKey] = x
  end

  EM:UnregisterForEvent(JHSetTrackers.name .. "_PowerStam", EVENT_POWER_UPDATE)
  EM:RegisterForEvent(  JHSetTrackers.name .. "_PowerStam", EVENT_POWER_UPDATE, OnPowerUpdateForProcs)
  EM:AddFilterForEvent( JHSetTrackers.name .. "_PowerStam", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_STAMINA, REGISTER_FILTER_UNIT_TAG, 'player')

  EM:UnregisterForEvent(JHSetTrackers.name .. "_PowerMag", EVENT_POWER_UPDATE)
  EM:RegisterForEvent(  JHSetTrackers.name .. "_PowerMag", EVENT_POWER_UPDATE, OnPowerUpdateForProcs)
  EM:AddFilterForEvent( JHSetTrackers.name .. "_PowerMag", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_MAGICKA, REGISTER_FILTER_UNIT_TAG, 'player')

  EM:UnregisterForEvent(JHSetTrackers.name .. "_PowerUlt", EVENT_POWER_UPDATE)
  EM:RegisterForEvent(  JHSetTrackers.name .. "_PowerUlt", EVENT_POWER_UPDATE, OnPowerUpdateForProcs)
  EM:AddFilterForEvent( JHSetTrackers.name .. "_PowerUlt", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE, REGISTER_FILTER_UNIT_TAG, 'player')
end

function JHSetTrackers.Tracking.EnableTrackingForCP(cps)
  for cpName, enabled in pairs(JHSetTrackers.character["champion"]) do
    if cps[cpName] == nil then
      JHSetTrackers.Tracking.EnableTrackingForSet(cpName, false)
    else
      d(string.format("cpName: %s, enabled: %s", cpName, tostring(JHSetTrackers.character["champion"][cpName])))
      JHSetTrackers.Tracking.EnableTrackingForSet(cpName, true)
    end
  end
end

function JHSetTrackers.Tracking.EnableTrackingForSet(setKey, enabled)

  -- if enabled and not LEB:IsSetEquipped(setKey) then
  --   if setKey == JHSetTrackers.spaulderName then JHSetTrackers.preferences.spaulderActive = false end
  --   return
  -- end

  setKey = RenameWhenPerfectSet(setKey);
  local set = JHSetTrackers.Data.Sets[setKey]

  -- Ignore sets not in our table
  if set == nil then return end

  -- Full bonus active
  if enabled then

    set.ps5HideAfterCooldown = nil
    set.ps5HideAfterActive = nil
    if set.endTime == nil then set.endTime = 0 end

    -- Check manual disable first
    if JHSetTrackers.character[set.procType][setKey] ~= nil and JHSetTrackers.character[set.procType][setKey] == false then
      -- Skip enabling set
      JHSetTrackers:Trace(1, "Force disabled <<1>>, skipping enable", setKey)
      return
    end

    -- Don't enable if already enabled
    if not set.enabled then
      JHSetTrackers:Trace(1, "Full set for: <<1>>, registering events", setKey)

      if set.noUI then
        JHSetTrackers.hasJorvuld = true
        set.enabled = true
        OnJorvuld()
        return
      end

      -- Set callback based on event
      local procFunction  = nil

      if JHSetTrackers.Data.ReleaseTriggers[setKey] then -- for sets with additional effects that updates the timer (Turning Tide)
        local a = JHSetTrackers.Data.ReleaseTriggers[setKey]

        JHSetTrackers.AdditionalIds[setKey] = {
          [1] = set.id,
          [2] = a.id
        }

        local procFunction2 = OnCombatEvent

        EM:RegisterForEvent(  JHSetTrackers.name .. "_" .. a.id, a.event, function(...) procFunction2(setKey, ...) end)
        EM:AddFilterForEvent( JHSetTrackers.name .. "_" .. a.id, a.event,
        REGISTER_FILTER_ABILITY_ID, a.id,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
      end

      if set.event == EVENT_ABILITY_COOLDOWN_UPDATED then
        procFunction = OnCooldownUpdated

      elseif set.event == EVENT_POWER_UPDATE then
        procFunction = OnPowerUpdate
        EM:RegisterForEvent(JHSetTrackers.name .. "_" .. set.id, set.event, function(...) procFunction(setKey, ...) end)
        EM:AddFilterForEvent(JHSetTrackers.name .. "_" .. set.id, set.event,
        REGISTER_FILTER_POWER_TYPE, set.powerType,
        REGISTER_FILTER_UNIT_TAG, 'player')

        -- Only needed for this kind of sets
        if JHSetTrackers.UI.JorvuldCheck(setKey) then JHSetTrackers.MajorMinorSets[setKey] = true end

        set.enabled = true
        JHSetTrackers.UI.Draw(setKey)
        return

      elseif set.event == EVENT_EFFECT_CHANGED then

        JHSetTrackers.Tracking.UpdateTrackingStateForEffect(setKey, true)
        return

        -- procFunction = OnEffectChanged
        -- if set.cooldownTrigger then
        --   local cd = set.cooldownTrigger
        --   local cdFunction = nil
        --
        --   if cd.event == EVENT_EFFECT_CHANGED
        --   then cdFunction = OnEffectCooldownChanged
        --   else cdFunction = OnCombatCooldownEvent end
        --
        --   EM:RegisterForEvent(JHSetTrackers.name .. "_" .. cd.id, cd.event, function(...) cdFunction(setKey, ...) end)
        --   EM:AddFilterForEvent(JHSetTrackers.name .. "_" .. cd.id, cd.event,
        --   REGISTER_FILTER_ABILITY_ID, cd.id,
        --   REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        -- end
      else
        procFunction = OnCombatEvent
      end
      -- Register events
      if type(set.id) == "table" then
        if set.texture == "/esoui/art/icons/gear_razorhorndaedric_shoulder_a.dds" then
          JHSetTrackers.spaulderName = setKey
          JHSetTrackers.Tracking.TrackSpaulder(true)
        else
          for i=1, #set.id do
            EM:RegisterForEvent(  JHSetTrackers.name .. "_" .. set.id[i], set.event, function(...) procFunction(setKey, ...) end)
            EM:AddFilterForEvent( JHSetTrackers.name .. "_" .. set.id[i], set.event,
            REGISTER_FILTER_ABILITY_ID, set.id[i],
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
          end
        end
      else
        EM:RegisterForEvent(  JHSetTrackers.name .. "_" .. set.id, set.event, function(...) procFunction(setKey, ...) end)
        EM:AddFilterForEvent( JHSetTrackers.name .. "_" .. set.id, set.event,
        REGISTER_FILTER_ABILITY_ID, set.id,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
      end

      -- Build the control before any special update loop can fire on console.
      set.enabled = true
      JHSetTrackers.UI.Draw(setKey)

      if set.id == 147462 or set.id == 193411 then -- pearls and esoteric
        JHSetTrackers.Tracking.EnablePowerUpdatesForProcSet(setKey)
        JHSetTrackers.resTrackerOn = true
      elseif set.id == 154737 then -- sul-xan
        TrackSoulSpawn(true, setKey)
      end
    else
      JHSetTrackers:Trace(2, "Set already enabled for: <<1>>", setKey)
    end
    -- Full bonus not active
  else

    -- Don't disable if already disabled
    if set.enabled then
      JHSetTrackers:Trace(1, "Not active for: <<1>>, unregistering events", setKey)

      if set.noUI then
        JHSetTrackers.hasJorvuld = false
        set.enabled = false
        OnJorvuld()
        return
      end

      if set.event == EVENT_EFFECT_CHANGED then
        -- EM:UnregisterForUpdate(JHSetTrackers.name .. setKey .. "Count")
      --   set.enabled = false
      --   pendingInactive[setKey] = true
      --   JHSetTrackers.Tracking.HideTrackerWhenInactive(setKey)
      --   return
      end

      if JHSetTrackers.Procs[setKey] then
        JHSetTrackers.Procs[setKey] = nil
        if JHSetTrackers.Procs == {} then
          JHSetTrackers.resTrackerOn = false
          EM:UnregisterForEvent(JHSetTrackers.name .. "_PowerMag", EVENT_POWER_UPDATE)
          EM:UnregisterForEvent(JHSetTrackers.name .. "_PowerStam", EVENT_POWER_UPDATE)
        end
      end

      if set.id == 154737 then -- sul-xan
        TrackSoulSpawn(false, setKey)
      end

      if type(set.id) == 'table' then
        if set.texture == "/esoui/art/icons/gear_razorhorndaedric_shoulder_a.dds" then
          JHSetTrackers.Tracking.TrackSpaulder(false)
          JHSetTrackers.preferences.spaulderActive = false
        else
          for i=1, #set.id do EM:UnregisterForEvent(JHSetTrackers.name .. "_" .. set.id[i], set.event) end
        end
      else
        EM:UnregisterForEvent(JHSetTrackers.name .. "_" .. set.id, set.event)
      end

      if JHSetTrackers.Data.ReleaseTriggers[setKey] then
        local a = JHSetTrackers.Data.ReleaseTriggers[setKey]
        EM:UnregisterForEvent(JHSetTrackers.name .. "_" .. a.id, a.event)
      end

      set.enabled = false

      if JHSetTrackers.MajorMinorSets[setKey] then JHSetTrackers.MajorMinorSets[setKey] = nil end

      -- Console/JH behavior: if the set is removed while a proc is active,
      -- keep the tracker visible until BOTH its buff and cooldown have ended.
      local nowMs = GetGameTimeMilliseconds()
      local cooldownRemaining = 0
      local buffRemaining = 0
      if set.onCooldown and set.cooldownDurationMs and set.cooldownDurationMs > 0 and set.timeOfProc then
        cooldownRemaining = (set.timeOfProc + set.cooldownDurationMs) - nowMs
      end
      if set.durationms and set.durationms > 0 and set.endTime then
        if set.event == EVENT_EFFECT_CHANGED then
          buffRemaining = (set.endTime - (time() / 1000)) * 1000
        else
          buffRemaining = set.endTime - nowMs
        end
      end
      if cooldownRemaining > 0 or buffRemaining > 0 then
        set.ps5HideAfterActive = true
        set.ps5HideAfterCooldown = cooldownRemaining > 0 and true or nil
        local control = JHSetTrackers.Controls[setKey]
        if control then control:SetHidden(false) end
      else
        set.ps5HideAfterActive = nil
        set.ps5HideAfterCooldown = nil
        JHSetTrackers.UI.Draw(setKey)
      end
    else
      JHSetTrackers:Trace(2, "Set already disabled for: <<1>>", setKey)
    end
  end
end
