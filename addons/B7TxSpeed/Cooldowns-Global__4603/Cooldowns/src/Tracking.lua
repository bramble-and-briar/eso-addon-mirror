-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @B7TxSpeed[EU]
-- Created: May 5, 2018
--
-- Tracking.lua
-- -----------------------------------------------------------------------------

Cool.Tracking           = {}
Cool.Procs              = {}
Cool.MajorMinorSets     = {}
Cool.AdditionalIds      = {}
Cool.PlayerPower        = {
	mag  = { current = 0, max = 0 },
	stam = { current = 0, max = 0 },
	ult  = 0,
  sets = {},
}
Cool.SpaulderIds        = {
  [163357] = true,
  [163359] = true,
  [163401] = true,
  [163404] = true,
}
Cool.SpaulderActive     = false
Cool.spaulderName       = "Spaulder of Ruin"
Cool.map                = ""
Cool.ghostTime          = 0
local SUL_XAN_NAME      = "Sul-Xan's Torment"
local SUL_XAN_ID        = 154737 --154737 buff --157738 soul
local GHOST_ID          = 157738 --154737 buff --157738 soul
local ZEN_ID            = 126597
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

  local set = Cool.Data.Sets[setKey]

  -- Ignore if set is on cooldown
  if set.onCooldown == true then return end

  set.timeOfProc = GetGameTimeMilliseconds()

  -- Delay proc time by the current frame duration if lag compensation is enabled
  -- This helps mitigate false procs when the set is seen as off cooldown,
  -- but the COOLDOWN_UPDATED event is still being called.
  -- This delay aims to let COOLDOWN_UPDATED finish, which can vary depending
  -- on lag conditions, before deeming the set as off cooldown.
  if Cool.preferences.lagCompensation then
    -- Add current frame delta - does NOT account for wide variances/spikes
    set.timeOfProc = set.timeOfProc + GetFrameDeltaTimeMilliseconds()
  end

  if set.cooldownDurationMs ~= 0 then set.onCooldown = true end
  Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onProc)
  EM:RegisterForUpdate(Cool.name .. setKey .. "Count", updateIntervalMs, function(...) Cool.UI.Update(setKey) return end)

  Cool:Trace(1, "Cooldown proc for <<1>> (<<2>>)", setKey, abilityId)
end

local function OnCombatEvent(setKey, _, result, _, abilityName, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)

  local set = Cool.Data.Sets[setKey]

  if Cool.AdditionalIds[setKey] then
    if abilityId == Cool.AdditionalIds[setKey][2] then
      local a = Cool.Data.ReleaseTriggers[setKey]

      if result ~= a.result then return end

      set.endTime = GetGameTimeMilliseconds()

      EM:UnregisterForUpdate( Cool.name .. setKey .. "Count")
      EM:RegisterForUpdate(   Cool.name .. setKey .. "Count", updateIntervalMs, function(...) Cool.UI.Update(setKey) return end)
      Cool.UI.Update(setKey)

      Cool:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>>. secondary set id.", abilityName, abilityId, result)
      return
    end
  end

  if Cool.SpaulderIds[abilityId] then -- Spaulder of Ruin
    Cool:Trace(1, "Spaulder: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)
    return
  end

  if result == ACTION_RESULT_ABILITY_ON_COOLDOWN then
    Cool:Trace(1, "<<1>> (<<2>>) on Cooldown", abilityName, abilityId)
  elseif result == set.result or (type(set.result) == "table" and Cool.HasValue(set.result, result)) then
    if set.procCounter and Cool.Procs[setKey] then
      Cool.Procs[setKey].times = Cool.Procs[setKey].times + 1
      Cool.UI.UpdateProcs(setKey)

      -- Without a timer to display, there is nothing else to do
      if set.resource or (set.durationms or 0) == 0 then
        Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onProc)
        Cool:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)
        return
      end
    end

    Cool:Trace(1, "(+)Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)

    if (set.cooldownDurationMs or 0) ~= 0 then set.onCooldown = true end

    set.timeOfProc = GetGameTimeMilliseconds()
    set.endTime    = set.timeOfProc + set.durationms
    Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onProc)
    EM:UnregisterForUpdate( Cool.name .. setKey .. "Count")
    EM:RegisterForUpdate(   Cool.name .. setKey .. "Count", updateIntervalMs, function(...) Cool.UI.Update(setKey) return end)
    Cool.UI.Update(setKey)
  else
    Cool:Trace(1, "(-)Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result)
  end
end

local function UpdateEffectState(setKey, onCooldown)

end

local function OnEffectChanged(setKey, _, change, _, effectName, unitTag, beginTime, endTime, stackCount, _, _, _, _, _, _, _, abilityId)

  local set = Cool.Data.Sets[setKey]

  if set == nil then return end

  local c   = WM:GetControlByName(setKey .. "_Container")
  -- local ec  = ""

  if change == EFFECT_RESULT_FADED then
    stackCount = 0
    Cool:Trace(1, "<<1>> (<<2>>): Faded", effectName, abilityId)

    -- set.endTime = time() / 1000

  elseif change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then

    local dur = string.format("%.1f", endTime - beginTime)

    if change == EFFECT_RESULT_GAINED then
      Cool:Trace(1, "<<1>> (<<2>>): Gained => <<3>> (<<4>>)", effectName, abilityId, dur, stackCount)
    else
      Cool:Trace(1, "<<1>> (<<2>>): Updated => <<3>> (<<4>>)", effectName, abilityId, dur, stackCount)
    end

    if set.onCooldown and set.onCooldown == true then
      set.onCooldown = false
      Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onProc)
    end
    set.timeOfProc = time()

    if set.durationms > 0 then
      -- Set endTime to currentTime + durationms if endTime is not provided by the event.
      if (endTime or 0) == 0 then
        endTime = (time() + set.durationms) / 1000
      end
      set.endTime = endTime
      -- if not c.isUpdating then
        -- c.isUpdating = true
        EM:RegisterForUpdate(Cool.name .. setKey .. "Count", updateIntervalMs, function(...) Cool.UI.UpdateEffect(setKey) end)
      -- end
    end
    Cool.UI.UpdateEffect(setKey)
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

  local set = Cool.Data.Sets[setKey]

  Cool:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>>, hit value <<4>>. <<5>> => <<6>>", abilityName, abilityId, result, hitValue, sourceType, targetType)

  if set == nil then return end

  if abilityId == set.cooldownTrigger.id then
    if result == set.cooldownTrigger.result then
      set.cdStart     = time()
      set.cdEnd       = (time() + hitValue) / 1000
      set.onCooldown  = true
      Cool.UI.UpdateEffect(setKey)
    elseif result == ACTION_RESULT_EFFECT_FADED then
      -- set.onCooldown  = false
      Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onReady)
      set.cdStart     = 0
      set.cdEnd       = 0
      Cool.UI.UpdateEffect(setKey)
    end
  end
end

local function OnPowerUpdate(setKey, eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
  local set = Cool.Data.Sets[setKey]
  local percent = (powerValue / powerEffectiveMax) * 100

  if powerType == POWERTYPE_MAGICKA then
    Cool.PlayerPower.mag.max = powerEffectiveMax
    Cool.PlayerPower.mag.current = percent
  elseif powerType == POWERTYPE_STAMINA then
    Cool.PlayerPower.stam.max = powerEffectiveMax
    Cool.PlayerPower.stam.current = percent
  elseif powerType == POWERTYPE_ULTIMATE then
    Cool.PlayerPower.ult = percent
  end

  if powerType == set.powerType then
    set.currentValue = percent
    Cool.UI.UpdatePower(setKey)
  end
end

local function OnPowerUpdateForProcs(_, _, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
  if powerType == POWERTYPE_MAGICKA then
    Cool.PlayerPower.mag.max = powerEffectiveMax
    Cool.PlayerPower.mag.current = (powerValue / powerEffectiveMax) * 100
  elseif powerType == POWERTYPE_STAMINA then
    Cool.PlayerPower.stam.max = powerEffectiveMax
    Cool.PlayerPower.stam.current = (powerValue / powerEffectiveMax) * 100
  elseif powerType == POWERTYPE_ULTIMATE then
    Cool.PlayerPower.ult = (powerValue / powerEffectiveMax) * 100
  end

  for i, x in pairs(Cool.Procs) do
    local set      = Cool.Procs[i]
    local resource = Cool.Data.Sets[i].resource
    if set and resource then
      local wanted = resource
      if resource == "highest" then
        wanted = Cool.PlayerPower.mag.max < Cool.PlayerPower.stam.max and POWERTYPE_STAMINA or POWERTYPE_MAGICKA
      end

      local power = wanted == POWERTYPE_STAMINA and Cool.PlayerPower.stam or Cool.PlayerPower.mag
      set.powerType = wanted
      set.current   = power.current
      set.max       = power.max
      Cool.UI.UpdateProcs(i)
    end
  end
end

local function OnCombatEnd()
  if IsUnitInCombat("player") then
    Cool:Trace(2, "Waiting for Combat to end")
    return
  end

  if (not IsUnitInCombat("player") and not Cool.isInCombat) then
    EM:UnregisterForUpdate(Cool.name .. "CombatEnded")
    zo_callLater(function()
      if IsUnitInCombat("player") then
        EM:RegisterForUpdate(Cool.name .. "CombatEnded", 2000, OnCombatEnd)
        return
      end

      Cool.UI:ResetProcs()
      Cool:Trace(2, "Combat End.")
    end, 3000)
  end
end

local function IsInCombat(_, inCombat)
  Cool.isInCombat = inCombat
  Cool:Trace(2, "In Combat: <<1>>", tostring(inCombat))
  Cool.UI:SetCombatStateDisplay()
  if IsUnitInCombat("player") then
    zo_callLater(function()
      EM:UnregisterForUpdate(Cool.name .. "CombatEnded")
      EM:RegisterForUpdate(Cool.name .. "CombatEnded", 3000, OnCombatEnd)
    end, 1000)
  end
end

local function OnAlive()
  Cool.isDead = false
  Cool.UI:SetCombatStateDisplay()
end

local function OnDeath()
  Cool.isDead = true
  Cool.UI:SetCombatStateDisplay()
end

local function OnPlayerActivated(_, initial)

  if not initial then
    local cs, stam, _ = GetUnitPower("player", POWERTYPE_STAMINA)
    local cm,  mag, _ = GetUnitPower("player", POWERTYPE_MAGICKA)
    local um,  ult, _ = GetUnitPower("player", POWERTYPE_ULTIMATE)

    Cool.PlayerPower.stam.max     = stam
    Cool.PlayerPower.mag.max      = mag
    Cool.PlayerPower.ult          = (um / ult)  * 100
    Cool.PlayerPower.stam.current = (cs / stam) * 100
    Cool.PlayerPower.mag.current  = (cm / mag)  * 100

    for key in pairs(Cool.MajorMinorSets) do
      local set = Cool.Data.Sets[key]
      if set ~= nil and Cool.Data.Sets[key].enabled then
        if set.powerType == POWERTYPE_STAMINA then
          set.currentValue = Cool.PlayerPower.stam.current
        elseif set.powerType == POWERTYPE_MAGICKA then
          set.currentValue = Cool.PlayerPower.mag.current
        elseif set.powerType == POWERTYPE_ULTIMATE then
          set.currentValue = Cool.PlayerPower.ult
        end

				Cool.UI.UpdatePower(key)
      end
    end
  end
end

local function OnJorvuld()
  for i, x in pairs(Cool.MajorMinorSets) do
    local set = Cool.MajorMinorSets[i]
    if set then
      current, max, effective = GetUnitPower("player", Cool.Data.Sets[i].powerType)
      Cool.Data.Sets[i].currentValue = (current / effective) * 100
      Cool.UI.UpdatePower(i)
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

  Cool:Trace(1, "<<1>> (<<2>>) with result <<3>>, hit value <<4>>", abilityName, abilityId, result, hitValue)
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

  Cool:Trace(1, "<<1>> (<<2>>) with change type <<3>> by <<4>>\n<<5>>", effectName, abilityId, changeType, sourceType, iconName)
end

-- ----------------------------------------------------------------------------
-- Event Register/Unregister
-- ----------------------------------------------------------------------------
function Cool.Tracking.RegisterUnfiltered()
  --EM:RegisterForEvent(Cool.name .. "_UnfilteredEffect", EVENT_EFFECT_CHANGED, OnEffectChangedUnfiltered)
  --EM:AddFilterForEvent(Cool.name .. "_UnfilteredEffect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  EM:RegisterForEvent(Cool.name .. "_Unfiltered", EVENT_COMBAT_EVENT, OnCombatEventUnfiltered)
  EM:AddFilterForEvent(Cool.name .. "_Unfiltered", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  Cool:Trace(1, "Registered Unfiltered Events")
end

function Cool.Tracking.UnregisterUnfiltered()
  EM:UnregisterForEvent(Cool.name .. "_Unfiltered", EVENT_COMBAT_EVENT)
  Cool:Trace(1, "Unregistered Unfiltered Events")
end

function Cool.Tracking.RegisterEvents()
  EM:RegisterForEvent(Cool.name, EVENT_PLAYER_ALIVE, OnAlive)
  EM:RegisterForEvent(Cool.name, EVENT_PLAYER_DEAD, OnDeath)

  EM:RegisterForEvent(Cool.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

  Cool.Tracking.RegisterCombatEvent()

  Cool:Trace(2, "Registered Events")
end

function Cool.Tracking.UnregisterEvents()
  EM:UnregisterForEvent(Cool.name, EVENT_PLAYER_ALIVE)
  EM:UnregisterForEvent(Cool.name, EVENT_PLAYER_DEAD)
  Cool:Trace(2, "Unregistered Events")
end

function Cool.Tracking.RegisterCombatEvent()
  EM:RegisterForEvent(Cool.name .. "COMBAT", EVENT_PLAYER_COMBAT_STATE, IsInCombat)
  Cool:Trace(2, "Registered combat events")
end

function Cool.Tracking.UnregisterCombatEvent()
  EM:UnregisterForEvent(Cool.name .. "COMBAT", EVENT_PLAYER_COMBAT_STATE)
  Cool:Trace(2, "Unregistered combat events")
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
  local c = Cool.Controls[setKey]
  local s = Cool.Data.Sets[setKey]
  if not s.units[id] then return end
  local t = s.units[id]
  local T = time() - t

  if (T < 2100) then return end

  s.units[id] = nil
  s.count = s.count - 1

  if s.count < 0 then set.count = 0 end

  Cool.UI.UpdateToggled(setKey, nil)

  Cool:Trace(2, "Spaulder Units(<<1>>) faded #<<2>>.", id, s.count)
end

local function OnSpaulder(setKey, _, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, sourceId, targetId, abilityId)

  local isActive

  if targetType == COMBAT_UNIT_TYPE_PLAYER then
    Cool.playerID = targetId
  end

  local isSource = sourceId == Cool.playerID and true or false
  local isTarget = targetId == Cool.playerID and true or false

  if (abilityId == spaulder.proc --[[or abilityId == spaulder.price]]) then

    local r
    if resultNames[result] then r = resultNames[result] else r = tostring(result) end

    local state = Cool.Data.Sets[setKey].active

    if (isTarget and result == ACTION_RESULT_EFFECT_FADED) then
      isActive = false
      Cool.UI.UpdateToggled(setKey, false)
      Cool:Trace(2, "Spaulder (<<1>>): <<2>> -> <<3>>. source: <<4>>. target: <<5>>", abilityId, activeNames[result], r, sourceId, targetId)

    elseif (isSource and result == ACTION_RESULT_EFFECT_GAINED) then
      isActive = true
      Cool.UI.UpdateToggled(setKey, true)
      Cool:Trace(2, "Spaulder (<<1>>): <<2>> -> <<3>>. source: <<4>>. target: <<5>>", abilityId, activeNames[result], r, sourceId, targetId)

    else return end

  elseif (abilityId == spaulder.aura and not isTarget) then

    local set = Cool.Data.Sets[setKey]

    if result == ACTION_RESULT_EFFECT_FADED then

      if (isSource and set.units[targetId]) then
        ClearSpaulderUnit(setKey, targetId)
        Cool.UI.UpdateToggled(setKey, nil)
      end

    elseif (result == ACTION_RESULT_EFFECT_GAINED) then
      if isSource then
        if not set.units[targetId] then
          set.units[targetId] = 0
          set.count = set.count + 1
          Cool.UI.UpdateToggled(setKey, true)
          Cool:Trace(2, "Spaulder Units(<<1>>) gained #<<3>>.", targetId, set.count)
        end
        set.units[targetId] = time()

      else
        if set.units[targetId] then
          ClearSpaulderUnit(setKey, targetId)
        end
        Cool:Trace(2, 'Spaulder(' .. abilityId .. ') result(' .. tostring(result) .. ') on: ' .. targetName .. '(' .. targetId .. ') from: ' .. sourceName .. '(' .. sourceId .. ')')
      end
    end
  end
end

local function ShouldUseLastState(set)
  local sameState   = false
  local sameFactors = 0

  local m = GetMapName()
  local n = GetUnitName("player")

  if m == Cool.preferences.map            then sameFactors = sameFactors + 1 end
  if n == Cool.preferences.lastCharacter  then sameFactors = sameFactors + 1 end

  if sameFactors == 2 then sameState = true end

  Cool.preferences.map            = m
  Cool.preferences.lastCharacter  = n
  return sameState
end

function Cool.Tracking.TrackSpaulder(track)

  local state = "Off"

  -- unregister events
  for k, v in pairs(spaulder) do
    EM:UnregisterForEvent(Cool.name .. "_Spaulder" .. v, EVENT_COMBAT_EVENT)
  end

  EM:UnregisterForEvent(Cool.name .. "_SpaulderActivated", EVENT_PLAYER_ACTIVATED)
  EM:UnregisterForUpdate(Cool.name .. "_SpaulderUnitCheck")

  -- reset units being buffed by player.
  local set = Cool.Data.Sets[Cool.spaulderName]
  set.units = {}
  set.count = 0

  -- refresh events
  if track then

    state = "On"

    -- check if player traveled, in which case the game would deactivate the set.
    EM:RegisterForEvent(Cool.name .. "_SpaulderActivated", EVENT_PLAYER_ACTIVATED, function(eventCode, initial)
      if initial then
        Cool.preferences.spaulderActive = false
        Cool.preferences.map            = GetMapName()
        Cool.preferences.lastCharacter  = GetUnitName("player")
      else
        if not ShouldUseLastState(set) then Cool.preferences.spaulderActive = false end
        set.units = {}
        set.count = 0
      end
      Cool.UI.UpdateToggled(Cool.spaulderName, Cool.preferences.spaulderActive)
    end)

    -- check for events with id's of: set toggled on, buff gained and recovery debuff from units being buffed.
    for k, v in pairs(spaulder) do
      EM:RegisterForEvent(Cool.name .. "_Spaulder" .. v, EVENT_COMBAT_EVENT, function(...) OnSpaulder(Cool.spaulderName, ...) end)
      EM:AddFilterForEvent(Cool.name .. "_Spaulder" .. v,
        REGISTER_FILTER_ABILITY_ID, v,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
      )
    end

    EM:RegisterForUpdate(Cool.name .. "_SpaulderUnitCheck", 2000, function()
      if set.count > 0 then
        for unit in pairs(set.units) do
          if unit then ClearSpaulderUnit(Cool.spaulderName, unit) end
        end
      end
    end)

  else

    -- Cool.preferences.spaulderActive = false

  end

  Cool:Trace(1, "Tracking for Spaulder: <<1>>", state)
end

local function OnSoulSpawn(setKey, _, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId, abilityId)

  if result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == GHOST_ID and sourceType == COMBAT_UNIT_TYPE_PLAYER then
    Cool.ghostTime = time() + hitValue
  end
end

local function TrackSoulSpawn(track, key)

  EM:UnregisterForEvent(Cool.name .. "_SoulSpawn", EVENT_COMBAT_EVENT)
  EM:UnregisterForUpdate(Cool.name .. "_SoulTimer")

  if track then

    local set = Cool.Data.Sets[key]

    if set.id == SUL_XAN_ID then SUL_XAN_NAME = key end

    EM:RegisterForEvent(  Cool.name .. "_SoulSpawn", EVENT_COMBAT_EVENT, function( ... ) OnSoulSpawn( SUL_XAN_NAME, ... ) end )
    EM:AddFilterForEvent( Cool.name .. "_SoulSpawn",
      REGISTER_FILTER_ABILITY_ID, GHOST_ID,
      REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
    )

    EM:RegisterForUpdate(Cool.name .. "_SoulTimer", 50, function()

      local set = Cool.Data.Sets[SUL_XAN_NAME]
      local c   = Cool.Controls[SUL_XAN_NAME]
      local bar = c.bar
      local t   = Cool.ghostTime - time()

      if set.timeOfProc > (Cool.ghostTime - 6600) then
        bar:SetHidden(true)
      else
        bar:SetHidden(false)
        bar:SetValue(t / 6600)
      end
    end )
  end
end

function Cool.Tracking.GetActiveBuffs()
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

function Cool.Tracking.UpdateSetBuffInfo(key)
  local set = Cool.Data.Sets[key]

  if set == nil then return end

  local c       = Cool.Controls[key]
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
    EM:UnregisterForUpdate(Cool.name .. key .. "Count")
    if hasBuff then
      -- if not c.isUpdating then
        c.isUpdating = true
        EM:RegisterForUpdate(Cool.name .. key .. "Count", 100, function(...) Cool.UI.UpdateEffect(key) end)
      -- end
      Cool.UI.UpdateEffect(key)
    else
      -- set.endTime = 0
      if c.label then c.label:SetText("") end
    end
    if c.stacks then
      set.stacks = stacks
      if set.stacks > 0
      then c.stacks:SetText(set.stacks)
      else c.stacks:SetText("") end
    end
  end
end

local pendingInactive = {}
function Cool.Tracking.UpdateTrackingStateForEffect(setKey, enabled)

  local set = Cool.Data.Sets[setKey]

  EM:UnregisterForEvent(Cool.name .. "_" .. set.id, set.event)

  -- local oldState = ""
  -- if pendingInactive[setKey] then
  --   pendingInactive[setKey] = nil
  --   oldState = "On"
  -- else
  --   oldState = "Off"
  -- end

  if enabled then
    local procFunction = OnEffectChanged
    EM:RegisterForEvent(  Cool.name .. "_" .. set.id, set.event, function(...) procFunction(setKey, ...) end)
    EM:AddFilterForEvent( Cool.name .. "_" .. set.id, set.event,
    REGISTER_FILTER_ABILITY_ID, set.id,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    set.enabled = true
    Cool.UI.Draw(setKey)

  else
    -- if Cool.UI.IsSetInactive(setKey) then
      -- local c   = WM:GetControlByName(setKey .. "_Container")
      -- c.isUpdating = false
      Cool.UI.Draw(setKey)
    -- end
  end

  Cool.Tracking.UpdateSetBuffInfo(setKey)

  if set.cooldownTrigger then
    local cdFunction = nil
    local cd = set.cooldownTrigger

    if cd.event == EVENT_EFFECT_CHANGED
    then cdFunction = OnEffectCooldownChanged
    else cdFunction = OnCombatCooldownEvent end

    EM:UnregisterForEvent(Cool.name .. "_" .. cd.id, cd.event)

    if enabled then
      EM:RegisterForEvent(Cool.name .. "_" .. cd.id, cd.event, function(...) cdFunction(setKey, ...) end)
      EM:AddFilterForEvent(Cool.name .. "_" .. cd.id, cd.event,
      REGISTER_FILTER_ABILITY_ID, cd.id,
      REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
  end

  -- local newState = ""
  -- if enabled then newState = "On" else newState = "Off" end
  -- d(setKey .. ": " .. oldState .. " => " .. newState)
end

function Cool.Tracking.HideTrackerWhenInactive(setKey)

  if Cool.UI.IsSetInactive(setKey) then
    Cool.Tracking.UpdateTrackingStateForEffect(setKey, false)
  else

    -- Cool.Tracking.UpdateSetBuffInfo(setKey)

    EM:RegisterForUpdate(Cool.name .. "Status" .. setKey, 500, function()

      if Cool.Data.Sets[setKey].enabled then
        EM:UnregisterForUpdate(Cool.name .. "Status" .. setKey)
        return
      end

      if Cool.UI.IsSetInactive(setKey) then
        EM:UnregisterForUpdate(Cool.name .. "Status" .. setKey)
        Cool.Tracking.UpdateTrackingStateForEffect(setKey, false)
      end
    end)
  end
end

local function CountPlayerDOTsOnTarget(targetUnitTag)
    local dotCount = 0
    for i = 1, GetNumBuffs(targetUnitTag) do
        local _, _, _, _, _, _, _, _, abilityType, _, abilityId, _, castByPlayer = GetUnitBuffInfo(targetUnitTag, i)
        if castByPlayer and abilityType == ABILITY_TYPE_DAMAGE then
            dotCount = dotCount + 1
        end
    end
    return dotCount
end

function Cool.Tracking.TrackZenDOTs(setKey)
  local set = Cool.Data.Sets[setKey]

  if set.id == ZEN_ID then
    local dots = CountPlayerDOTsOnTarget("reticleover")
    local c = WM:GetControlByName(setKey .. "_Container")
    
    -- Update stacks with number of Zen DOTs
    set.stacks = dots
    
    if c.stacks then
      if set.stacks > 0 then c.stacks:SetText(set.stacks) else c.stacks:SetText("") end
    end
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
    Cool:Trace(3, "Perfect suspect, string matches: <<1>>", isPerfect)

    -- Normalize Perfect and Non-Perfect variant names
    for _, perfectString in ipairs(Cool.Data.PerfectString) do

      -- Find strings related to being Perfect
      local newSetKey, count = string.gsub(setKey, perfectString, "")

      -- Update name if a perfect version is detected
      if count > 0 then
        Cool:Trace(1, "Found <<1>> version of <<2>>", perfectString, newSetKey)
        return newSetKey
      end

      Cool:Trace(3, "Perfect suspect, but no match for \"<<1>>\"", perfectString)
    end
  end

  -- Return unmodified if perfect could not be matched
  return setKey
end

local function UpdateCurrentResources()
  local cs, stam, _ = GetUnitPower("player", POWERTYPE_STAMINA)
  local cm,  mag, _ = GetUnitPower("player", POWERTYPE_MAGICKA)
  local um,  ult, _ = GetUnitPower("player", POWERTYPE_ULTIMATE)
  Cool.PlayerPower.stam.max     = stam
  Cool.PlayerPower.mag.max      = mag
  Cool.PlayerPower.ult          = (um / ult)  * 100
  Cool.PlayerPower.stam.current = (cs / stam) * 100
  Cool.PlayerPower.mag.current  = (cm / mag)  * 100
end

function Cool.Tracking.EnableSynergiesFromPrefs()
  for key, enable in pairs(Cool.character.synergy) do
    if enable == true then Cool.Tracking.EnableTrackingForSet(key, true, nil) end
  end
end

function Cool.Tracking.EnablePassivesFromPrefs()
  for key, enable in pairs(Cool.character.passive) do
    if enable == true then Cool.Tracking.EnableTrackingForSet(key, true, nil) end
  end
end

function Cool.Tracking.EnableCPFromPrefs()
  for key, enable in pairs(Cool.character.champion) do
    if enable == true then Cool.Tracking.EnableTrackingForSet(key, true, nil) end
  end
  return false
end
function Cool.HasValue (table, val)
  for index, value in ipairs(table) do
      if value == val then
          return true
      end
  end
  return false
end

function Cool.Tracking.EnablePowerUpdatesForProcSet(setKey)
  local set = Cool.Data.Sets[setKey]

  UpdateCurrentResources()

  local wanted = set.resource
  if wanted == "highest" then
    wanted = Cool.PlayerPower.stam.max > Cool.PlayerPower.mag.max and POWERTYPE_STAMINA or POWERTYPE_MAGICKA
  end

  local power = wanted == POWERTYPE_STAMINA and Cool.PlayerPower.stam or Cool.PlayerPower.mag
  Cool.Procs[setKey] = { id = set.id, times = 0, powerType = wanted, current = power.current, max = power.max }

  EM:UnregisterForEvent(Cool.name .. "_PowerStam", EVENT_POWER_UPDATE)
  EM:RegisterForEvent(  Cool.name .. "_PowerStam", EVENT_POWER_UPDATE, OnPowerUpdateForProcs)
  EM:AddFilterForEvent( Cool.name .. "_PowerStam", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_STAMINA, REGISTER_FILTER_UNIT_TAG, 'player')

  EM:UnregisterForEvent(Cool.name .. "_PowerMag", EVENT_POWER_UPDATE)
  EM:RegisterForEvent(  Cool.name .. "_PowerMag", EVENT_POWER_UPDATE, OnPowerUpdateForProcs)
  EM:AddFilterForEvent( Cool.name .. "_PowerMag", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_MAGICKA, REGISTER_FILTER_UNIT_TAG, 'player')

  EM:UnregisterForEvent(Cool.name .. "_PowerUlt", EVENT_POWER_UPDATE)
  EM:RegisterForEvent(  Cool.name .. "_PowerUlt", EVENT_POWER_UPDATE, OnPowerUpdateForProcs)
  EM:AddFilterForEvent( Cool.name .. "_PowerUlt", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE, REGISTER_FILTER_UNIT_TAG, 'player')
end

function Cool.Tracking.EnableTrackingForCP(cps)
  for cpName, enabled in pairs(Cool.character["champion"]) do
    if cps[cpName] == nil then
      Cool.Tracking.EnableTrackingForSet(cpName, false, nil)
    else
      d(string.format("cpName: %s, enabled: %s", cpName, tostring(Cool.character["champion"][cpName])))
      Cool.Tracking.EnableTrackingForSet(cpName, true, nil)
    end
  end
end

function Cool.Tracking.EnableTrackingForSet(setKey, enabled, setId)

  -- if enabled and not LEB:IsSetEquipped(setKey) then
  --   if setKey == Cool.spaulderName then Cool.preferences.spaulderActive = false end
  --   return
  -- end

  if setId ~= nil then
    setKey = LibSets.GetSetName(setId, "en")
  end

  setKey = RenameWhenPerfectSet(setKey);
  local set = Cool.Data.Sets[setKey]

  -- Ignore sets not in our table
  if set == nil then return end

  -- Full bonus active
  if enabled then

    if set.endTime == nil then set.endTime = 0 end

    -- Check manual disable first
    if Cool.character[set.procType][setKey] ~= nil and Cool.character[set.procType][setKey] == false then
      -- Skip enabling set
      Cool:Trace(1, "Force disabled <<1>>, skipping enable", setKey)
      return
    end

    -- Don't enable if already enabled
    if not set.enabled then
      Cool:Trace(1, "Full set for: <<1>>, registering events", setKey)

      if set.noUI then
        Cool.hasJorvuld = true
        set.enabled = true
        OnJorvuld()
        return
      end

      -- Set callback based on event
      local procFunction  = nil

      if Cool.Data.ReleaseTriggers[setKey] then -- for sets with additional effects that updates the timer (Turning Tide)
        local a = Cool.Data.ReleaseTriggers[setKey]

        Cool.AdditionalIds[setKey] = {
          [1] = set.id,
          [2] = a.id
        }

        local procFunction2 = OnCombatEvent

        EM:RegisterForEvent(  Cool.name .. "_" .. a.id, a.event, function(...) procFunction2(setKey, ...) end)
        EM:AddFilterForEvent( Cool.name .. "_" .. a.id, a.event,
        REGISTER_FILTER_ABILITY_ID, a.id,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
      end

      if set.event == EVENT_ABILITY_COOLDOWN_UPDATED then
        procFunction = OnCooldownUpdated

      elseif set.event == EVENT_POWER_UPDATE then
        procFunction = OnPowerUpdate
        EM:RegisterForEvent(Cool.name .. "_" .. set.id, set.event, function(...) procFunction(setKey, ...) end)
        EM:AddFilterForEvent(Cool.name .. "_" .. set.id, set.event,
        REGISTER_FILTER_POWER_TYPE, set.powerType,
        REGISTER_FILTER_UNIT_TAG, 'player')

        -- Only needed for this kind of sets
        if Cool.UI.JorvuldCheck(setKey) then Cool.MajorMinorSets[setKey] = true end

        set.enabled = true
        Cool.UI.Draw(setKey)
        return

      elseif set.event == EVENT_EFFECT_CHANGED then

        Cool.Tracking.UpdateTrackingStateForEffect(setKey, true)
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
        --   EM:RegisterForEvent(Cool.name .. "_" .. cd.id, cd.event, function(...) cdFunction(setKey, ...) end)
        --   EM:AddFilterForEvent(Cool.name .. "_" .. cd.id, cd.event,
        --   REGISTER_FILTER_ABILITY_ID, cd.id,
        --   REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        -- end
      else
        procFunction = OnCombatEvent
      end
      -- Register events
      if type(set.id) == "table" then
        if set.texture == "/esoui/art/icons/gear_razorhorndaedric_shoulder_a.dds" then
          Cool.spaulderName = setKey
          Cool.Tracking.TrackSpaulder(true)
        else
          for i=1, #set.id do
            EM:RegisterForEvent(  Cool.name .. "_" .. set.id[i], set.event, function(...) procFunction(setKey, ...) end)
            EM:AddFilterForEvent( Cool.name .. "_" .. set.id[i], set.event,
            REGISTER_FILTER_ABILITY_ID, set.id[i],
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
          end
        end
      else
        EM:RegisterForEvent(  Cool.name .. "_" .. set.id, set.event, function(...) procFunction(setKey, ...) end)
        if set.targetTracking ~= nil and set.targetTracking == true then
          EM:AddFilterForEvent( Cool.name .. "_" .. set.id, set.event,
          REGISTER_FILTER_ABILITY_ID, set.id,
          REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        else
          EM:AddFilterForEvent( Cool.name .. "_" .. set.id, set.event,
          REGISTER_FILTER_ABILITY_ID, set.id,
          REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
      end

      if set.procCounter then
        if set.resource then
          Cool.Tracking.EnablePowerUpdatesForProcSet(setKey)
          Cool.resTrackerOn = true
        else
          Cool.Procs[setKey] = { id = set.id, times = 0 }
        end
      end

      if set.id == 154737 then -- sul-xan
        TrackSoulSpawn(true, setKey)
      elseif set.id == ZEN_ID then
        EM:RegisterForUpdate(Cool.name .. "_" .. "TrackZenDOTs", 500, function() Cool.Tracking.TrackZenDOTs(setKey) end)
      end

      set.enabled = true
      Cool.UI.Draw(setKey)
    else
      Cool:Trace(2, "Set already enabled for: <<1>>", setKey)
    end
    -- Full bonus not active
  else

    -- Don't disable if already disabled
    if set.enabled then
      Cool:Trace(1, "Not active for: <<1>>, unregistering events", setKey)

      if set.noUI then
        Cool.hasJorvuld = false
        set.enabled = false
        OnJorvuld()
        return
      end

      if set.event == EVENT_EFFECT_CHANGED then
        -- EM:UnregisterForUpdate(Cool.name .. setKey .. "Count")
      --   set.enabled = false
      --   pendingInactive[setKey] = true
      --   Cool.Tracking.HideTrackerWhenInactive(setKey)
      --   return
      end

      if Cool.Procs[setKey] then
        local c = Cool.Controls[setKey]
        if c and c.counter then c.counter:SetText("") end
        Cool.Procs[setKey] = nil
        local hasResourceSet = false
        for key in pairs(Cool.Procs) do
          if Cool.Data.Sets[key].resource then hasResourceSet = true end
        end
        if not hasResourceSet then
          Cool.resTrackerOn = false
          EM:UnregisterForEvent(Cool.name .. "_PowerMag", EVENT_POWER_UPDATE)
          EM:UnregisterForEvent(Cool.name .. "_PowerStam", EVENT_POWER_UPDATE)
          EM:UnregisterForEvent(Cool.name .. "_PowerUlt", EVENT_POWER_UPDATE)
        end
      end

      if set.id == 154737 then -- sul-xan
        TrackSoulSpawn(false, setKey)
      elseif set.id == ZEN_ID then
        EM:UnregisterForUpdate(Cool.name .. "_" .. "TrackZenDOTs")
      end

      if type(set.id) == 'table' then
        if set.texture == "/esoui/art/icons/gear_razorhorndaedric_shoulder_a.dds" then
          Cool.Tracking.TrackSpaulder(false)
          Cool.preferences.spaulderActive = false
        else
          for i=1, #set.id do EM:UnregisterForEvent(Cool.name .. "_" .. set.id[i], set.event) end
        end
      else
        EM:UnregisterForEvent(Cool.name .. "_" .. set.id, set.event)
      end

      if Cool.Data.ReleaseTriggers[setKey] then
        local a = Cool.Data.ReleaseTriggers[setKey]
        EM:UnregisterForEvent(Cool.name .. "_" .. a.id, a.event)
      end

      set.enabled = false

      if Cool.MajorMinorSets[setKey] then Cool.MajorMinorSets[setKey] = nil end

      Cool.UI.Draw(setKey)
    else
      Cool:Trace(2, "Set already disabled for: <<1>>", setKey)
    end
  end
end
