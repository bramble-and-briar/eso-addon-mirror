-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @kabs12[NA]
-- Created: May 5, 2018
--
-- Settings.lua
-- -----------------------------------------------------------------------------

JHSetTrackers.Settings         = {}
JHSetTrackers.Settings.window  = nil
local WM              = WINDOW_MANAGER
local EM              = EVENT_MANAGER
local LAM             = LibAddonMenu2
local LEB             = LibEquipmentBonus
local scaleBase       = JHSetTrackers.UI.scaleBase
local currentSet      = ""
local panelData       = {
  type                  = "panel",
  name                  = "Trackers by JH - Set Trackers",
  displayName           = "Trackers by JH - Set Trackers",
  author                = "|cFFCCCCg4rr3t|r [NA], nogetrandom [EU], |cFF009Bkabs12|r [NA]",
  version               = JHSetTrackers.version,
  registerForRefresh    = true,
}

-- ============================================================================
-- Global Options
-- ============================================================================

local function UpdateVisibilityForMenu()
  for k, v in pairs(JHSetTrackers.Controls) do
    local c = JHSetTrackers.Controls[k]
    if c ~= nil then
      if c.set ~= nil and c.set.enabled == true then
        c:SetHidden(not JHSetTrackers.UI.showIcons)
      end
    end
  end
end

local function HideInMenu(control)
  JHSetTrackers.hideInMenu   = not JHSetTrackers.hideInMenu
  JHSetTrackers.UI.showIcons = not JHSetTrackers.hideInMenu

  UpdateVisibilityForMenu()

  if JHSetTrackers.hideInMenu
  then control:SetText("Show in menu")
  else control:SetText("Hide in menu") end
end

-- Grid Options
local function GetSnapToGrid()
  return JHSetTrackers.preferences.snapToGrid
end

local function SetSnapToGrid(snap)
  JHSetTrackers.preferences.snapToGrid = snap
end

local function GetGridSize()
  return JHSetTrackers.preferences.gridSize
end

local function SetGridSize(gridSize)
  JHSetTrackers.preferences.gridSize = gridSize
end

-- Locked State
local function ToggleLocked(control)
  JHSetTrackers.preferences.unlocked = not JHSetTrackers.preferences.unlocked

  for k, v in pairs(JHSetTrackers.Controls) do
    local c = JHSetTrackers.Controls[k]
    -- Console build: mouse movement disabled; use gamepad move mode.
  end

  if JHSetTrackers.preferences.unlocked
  then control:SetText("Lock All")
  else control:SetText("Unlock All") end
end

-- Combat State Display
local function GetShowOutOfCombat()
  return JHSetTrackers.preferences.showOutsideCombat
end

local function SetShowOutOfCombat(value)
  JHSetTrackers.preferences.showOutsideCombat = value
  JHSetTrackers.UI:SetCombatStateDisplay()

  -- if value then
  --   JHSetTrackers.Tracking.UnregisterCombatEvent()
  -- else
  --   JHSetTrackers.Tracking.RegisterCombatEvent()
  -- end
end

-- Lag Compensation
local function GetLagCompensation()
  return JHSetTrackers.preferences.lagCompensation
end

local function SetLagCompensation(value)
  JHSetTrackers.preferences.lagCompensation = value
end

-- Selection
local default = {
  artifact    = "-- Select an Artifact --",
  monsterSet  = "-- Select a Monster Set --",
  stackSet    = "-- Select a Set --",
  set         = "-- Select a Set --",
  synergy     = "-- Select a Synergy --",
  champion    = "-- Select a CP --",
  passive     = "-- Select a Passive --",
  resource    = "-- Select a Set --"
}

local selected = {
  artifact    = default.artifact,
  monsterSet  = default.monsterSet,
  stackSet    = default.stackSet,
  set         = default.set,
  champion    = default.champion,
  synergy     = default.synergy,
  passive     = default.passive,
  resource    = default.resource
}

local defaultRes = "-- Select a Set --"

local selectedRes = defaultRes

local function GetSelectedRes()
  return selectedRes
end

local function SetSelectedRes(set)
  selected.resource = set
  selectedRes       = set
end

local function HasSelectedRes()
  if selectedRes ~= defaultRes then return true
  else return false end
end

-- Selection
local function GetSelected(procType)
  return selected[procType]
end

local function SetSelected(procType, selection)
  selected[procType] = selection
  currentSet = selection
end

local function HasSelected(procType)
  if selected[procType] ~= default[procType] then return true
  else return false end
end

-- Sizing
local function SetSize(setKey, size)
  local context = JHSetTrackers.Controls[setKey]
  if context ~= nil then
    local set = JHSetTrackers.Data.Sets[setKey]
    if set and (set.id == 147462 or set.id == 193411) then -- pearls and esoteric
      JHSetTrackers.UI.UpdateBarConstraints(setKey)
    else
      context:SetScale(size / scaleBase)
    end

    -- Keep the saved TOPLEFT anchor authoritative. Scaling must never rewrite
    -- position. This mirrors the Landslide move/size behaviour across reloads.
    local saved = JHSetTrackers.preferences and JHSetTrackers.preferences.sets[setKey]
    if saved and saved.x and saved.y then
      context:ClearAnchors()
      context:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    end
    d("Updating Size for:\n|cFFFFFF" .. setKey .. "|r")
  end

  -- Make size changes durable before a console /reloadui.
  local am = GetAddOnManager and GetAddOnManager()
  if am and am.RequestAddOnSavedVariablesPrioritySave then
    am:RequestAddOnSavedVariablesPrioritySave("TrackersByJH")
  end
end

local timerUpdateTime = {}
local function DisplayChangeTimeEnd()
  for i, x in pairs(timerUpdateTime) do
    local set = timerUpdateTime[i]
    local t = GetGameTimeMilliseconds()
    if set.timer - t <= 0 then
      if JHSetTrackers.Data.Sets[set.key].id == 147462 or JHSetTrackers.Data.Sets[setKey].id == 193411 then --pearls and esoteric
        JHSetTrackers.UI.UpdateProcs(set.key)
      elseif set.key == JHSetTrackers.spaulderName then
        JHSetTrackers.UI.UpdateToggled(set.key, JHSetTrackers.preferences.spaulderActive)
      else
        if JHSetTrackers.Data.Sets[set.key].event == EVENT_POWER_UPDATE then
          JHSetTrackers.UI.UpdatePower(set.key)
        else
          JHSetTrackers.UI.Update(set.key)
        end
      end
      table.remove(timerUpdateTime[i])
    end
    if table.getn(timerUpdateTime) < 1 then
      EM:UnregisterForUpdate(JHSetTrackers.name .. "SettingsChange")
    end
  end
end

local function UpdateTimerPosition(setKey)

  if JHSetTrackers.Data.Sets[setKey] and JHSetTrackers.Data.Sets[setKey].noUI then return end

  local c = JHSetTrackers.Controls[setKey] -- WM:GetControlByName(setKey .. "_Container")

  if c ~= nil then
    local l     = c.label -- WM:GetControlByName(setKey .. "_Label")
    local i     = c.icon -- WM:GetControlByName(setKey .. "_Icon")
    local x, y  = JHSetTrackers.UI.GetSavedTimerPosition(setKey)
    local set   = JHSetTrackers.Data.Sets[setKey]

    l:ClearAnchors()
    l:SetAnchor(CENTER, c, CENTER, x, JHSetTrackers.UI.FormatTimerY(y))

    if not JHSetTrackers.hideInMenu then
      if set.id == 147462 or set.id == 193411 then -- pearls and esoteric
        if l:GetText() == "" then
          l:SetText("69%")
          l:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorDown))
        end
      elseif setKey == JHSetTrackers.spaulderName then
        if set.count ~= nil then
          if set.count > 0
          then l:SetText("0")
          else l:SetText(set.count) end
        end
      else
        if set.event == EVENT_POWER_UPDATE then
          i:SetColor(1, 1, 1, 1)
          l:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorUp))
          l:SetText("6%")
        elseif set.result == ACTION_RESULT_POWER_ENERGIZE then
          i:SetColor(1, 1, 1, 1)
          l:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorUp))
          l:SetText("15")
        else
          if set.durationms > 0 then
            i:SetColor(1, 1, 1, 1)
            l:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorUp))
            l:SetText("1.9")
          else
            i:SetColor(0.5, 0.5, 0.5, 1)
            l:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorDown))
            l:SetText("0.9")
          end
        end
      end

      l:SetHidden(false)

      local hide = 0
      -- if setKey ~= JHSetTrackers.spaulderName then
        hide = GetGameTimeMilliseconds() + 3000
      -- end

      local setDisplay = {key = setKey, timer = hide}
      table.insert(timerUpdateTime, setDisplay)
      EM:UnregisterForUpdate(JHSetTrackers.name .. "SettingsChange")
      EM:RegisterForUpdate(JHSetTrackers.name .. "SettingsChange", 1000, DisplayChangeTimeEnd)
    end
  end
end

-- ============================================================================
-- Sets
-- ============================================================================

-- Enabled
local function GetSelectedEnabled(procType)
  if HasSelected(procType) then return JHSetTrackers.character[procType][selected[procType]]
  else return false end
end

local function SetSelectedEnabled(procType, state)
  if procType == "set" then
    if JHSetTrackers.character[procType][selected[procType]] == false and state == true then
      -- A set was forced disable, now it's on
      -- Notify player to re-equip
      JHSetTrackers:Trace(0, 'Re-enabling <<1>>. You may need to take off and re-equip this set to resume tracking.', selected[procType])
      JHSetTrackers.character[procType][selected[procType]] = true
      return
    elseif state == false then
      JHSetTrackers:Trace(0, 'Forcing tracking off for <<1>>. It will not be tracked until you enable it again.', selected[procType])
    else
      JHSetTrackers:Trace(1, 'Setting <<1>> to <<2>>', selected[procType], tostring(state))
    end
  end

  JHSetTrackers.character[procType][selected[procType]] = state

  if LEB.sets[selected[procType]] then -- Won't apply to synergies and passives
    -- Don't display if not equipped when enabled in settings
    if not LEB.sets[selected[procType]].equippedMax then return end
  end

  JHSetTrackers.Tracking.EnableTrackingForSet(selected[procType], state)
end

-- Size
local function ExportSize(setKey, size)
  local source  = JHSetTrackers.Data.Sets[setKey]
  local type    = source.procType
  local frame   = source.showFrame

  local msg = "Updating Global Size for:\n|cFFFFFF" .. setKey .. "|r"

  for key in pairs(JHSetTrackers.Controls) do
    local set = JHSetTrackers.Data.Sets[key]
    local sv  = JHSetTrackers.preferences.sets[key]
    if set ~= nil and key ~= setKey then
      if sv.global.size and set.showFrame == source.showFrame then
        if set.procType == type then
          msg = msg .. ", |cFFFFFF" .. key .. "|r"
          SetSize(key, size)
        end
      end
    end
  end
  d(msg)
end

local function GetSelectedSize(procType)
  if HasSelected(procType) then
    return JHSetTrackers.UI.GetSavedScaleForControl(selected[procType])
  else
    return 64
  end
end

local function SetSelectedSize(procType, size)
  if JHSetTrackers.preferences.sets[selected[procType]].global.size == true then
    local set = JHSetTrackers.Data.Sets[selected[procType]]
    local type = set.procType
    if set.showFrame
    then JHSetTrackers.preferences.global[type].frame.size   = size
    else JHSetTrackers.preferences.global[type].noFrame.size = size end
    SetSize(selected[procType], size)
    -- update size of all exsiting displays with global size enabled
    ExportSize(selected[procType], size)
  else
    JHSetTrackers.preferences.sets[selected[procType]].size = size
    SetSize(selected[procType], size)
  end
end

local function GetSelectedGlobalSizeSetting(procType)
  if HasSelected(procType) then
    return JHSetTrackers.preferences.sets[selected[procType]].global.size
  else
    return false
  end
end

local function SetSelectedGlobalSizeSetting(procType, value)
  JHSetTrackers.preferences.sets[selected[procType]].global.size = value
  SetSize(selected[procType], JHSetTrackers.UI.GetSavedScaleForControl(selected[procType]))
end

local function GetSizeTooltip(procType)
  local tooltip = ""
  if HasSelected(procType) then
    if JHSetTrackers.preferences.sets[selected[procType]].global.size then
      local text = "This will change the size of any "
      local typeSpecific = {
        artifact    = "artifact with their Use Shared Size setting enabled.",
        monsterSet  = "monster set with their Use Shared Size setting enabled.",
        stackSet    = "set if their Use Shared Size setting enabled.",
        set         = "set if their Use Shared Size setting enabled.",
        champion    = "cp with their Use Shared Size setting enabled.",
        synergy     = "synergy with their Use Shared Size setting enabled.",
        passive     = "passive with their Use Shared Size setting enabled.",
      }
      tooltip = text .. typeSpecific[procType]
    end
  end
  return tooltip
end

-- Timer Position
-- Export
local function ExportTimerPosition(setKey)
  local source  = JHSetTrackers.Data.Sets[setKey]
  local type    = source.event == EVENT_POWER_UPDATE and "resource" or source.procType
  local frame   = source.showFrame

  local msg = "Updating Global Timer Position for:\n|cFFFFFF" .. setKey .. "|r"

  for key in pairs(JHSetTrackers.Controls) do
    local set = JHSetTrackers.Data.Sets[key]
    local sv  = JHSetTrackers.preferences.sets[key]
    if set ~= nil and key ~= setKey then
      if sv.global.size and set.showFrame == source.showFrame then
        if set.event == EVENT_POWER_UPDATE then
          if type == "resource" then
            msg = msg .. ", |cFFFFFF" .. key .. "|r"
            UpdateTimerPosition(key)
          end
        else
          if set.procType == type then
            msg = msg .. ", |cFFFFFF" .. key .. "|r"
            UpdateTimerPosition(key)
          end
        end
      end
    end
  end
  d(msg)
end

-- Up / Down
local function GetSelectedTimerY(procType)
  if HasSelected(procType) then
    local _, y = JHSetTrackers.UI.GetSavedTimerPosition(selected[procType])
    return y
  else
    return 0
  end
end

local function SetSelectedTimerY(procType, y)
  if JHSetTrackers.preferences.sets[selected[procType]].global.timer == true then
    local set   = JHSetTrackers.Data.Sets[selected[procType]]
    local type = set.procType
    if type ~= "synergy" then
      if set.showFrame then
        JHSetTrackers.preferences.global[type].frame.timer.y = y
      else
        JHSetTrackers.preferences.global[type].noFrame.timer.y = y
      end
    else
      if set.showFrame then
        JHSetTrackers.preferences.global[type].frame.y = y
      else
        JHSetTrackers.preferences.global[type].noFrame.y = y
      end
    end
    UpdateTimerPosition(selected[procType])
    -- update timer position for all existing displays with global timer enabled
    ExportTimerPosition(selected[procType])
  else
    JHSetTrackers.preferences.sets[selected[procType]].timer.y = y
    UpdateTimerPosition(selected[procType])
  end
end

-- Left / right
local function GetSelectedTimerX(procType)
  if HasSelected(procType) then
    local x, _ = JHSetTrackers.UI.GetSavedTimerPosition(selected[procType])
    return x
  else
    return 0
  end
end

local function SetSelectedTimerX(procType, x)
  if JHSetTrackers.preferences.sets[selected[procType]].global.timer == true then
    local set = JHSetTrackers.Data.Sets[selected[procType]]
    local type = set.procType
    if type ~= "synergy" then
      if set.showFrame then
        JHSetTrackers.preferences.global[type].frame.timer.x = x
      else
        JHSetTrackers.preferences.global[type].noFrame.timer.x = x
      end
    else
      if set.showFrame then
        JHSetTrackers.preferences.global[type].frame.x = x
      else
        JHSetTrackers.preferences.global[type].noFrame.x = x
      end
    end
    UpdateTimerPosition(selected[procType])
    -- update timer position for all existing displays with global timer enabled
    ExportTimerPosition(selected[procType])
  else
    JHSetTrackers.preferences.sets[selected[procType]].timer.x = x
    UpdateTimerPosition(selected[procType])
  end
end

local function GetSelectedGlobalTimerSetting(procType)
  if HasSelected(procType) then
    return JHSetTrackers.preferences.sets[selected[procType]].global.timer
  else
    return false
  end
end

local function SetSelectedGlobalTimerSetting(procType, value)
  JHSetTrackers.preferences.sets[selected[procType]].global.timer = value
  UpdateTimerPosition(selected[procType])
end

local function GetTimerTooltip(procType)
  local tooltip = ""
  if HasSelected(procType) then
    if JHSetTrackers.preferences.sets[selected[procType]].global.timer then
      local text = "This will change the timer position any "
      local typeSpecific = {
        artifact    = "artifact with their Use Shared Position setting enabled.",
        monsterSet  = "monster set with their Use Shared Position setting enabled.",
        stackSet    = "set with their Use Shared Position setting enabled.",
        set         = "set with their Use Shared Position setting enabled.",
        champion    = "CP with their Use Shared Position setting enabled.",
        synergy     = "synergy with their Use Shared Position setting enabled.",
        passive     = "passive with their Use Shared Position setting enabled.",
      }
      tooltip = text .. typeSpecific[procType]
    end
  end
  return tooltip
end

-- Timer Color
local function GetSelectedUptimeColor(procType)
  if HasSelected(procType)
  then return JHSetTrackers.preferences.sets[selected[procType]].colorUp
  else return JHSetTrackers.preferences.colorUp end
end

local function SetSelectedUptimeColor(procType, color)
  JHSetTrackers.preferences.sets[selected[procType]].colorUp = color
  -- display the change
  UpdateTimerPosition(selected[procType])
end

local function GetSelectedDowntimeColor(procType)
  if HasSelected(procType)
  then return JHSetTrackers.preferences.sets[selected[procType]].colorDown
  else return JHSetTrackers.preferences.colorDown end
end

local function SetSelectedDowntimeColor(procType, color)
  JHSetTrackers.preferences.sets[selected[procType]].colorDown = color
  -- display the change
  UpdateTimerPosition(selected[procType])
end

-- Resource Options:
-- % Label
local function GetSelectedLabelOption(set)
  if HasSelectedRes(set)
  then return JHSetTrackers.preferences.sets[set].showPercent
  else return JHSetTrackers.Defaults.GetDefaultResourceOption(1) end
end

local function SetSelectedLabelOption(set, value)
  JHSetTrackers.preferences.sets[set].showPercent = value
  JHSetTrackers.UI.UpdateProcs(set)
end

-- Proc Counter
local function GetSelectedProcOption(set)
  if HasSelectedRes()
  then return JHSetTrackers.preferences.sets[set].showProcs
  else return JHSetTrackers.Defaults.GetDefaultResourceOption(2) end
end

local function SetSelectedProcOption(set, value)
  JHSetTrackers.preferences.sets[set].showProcs = value
  JHSetTrackers.UI.UpdateProcs(set)
end

-- Frame Color: On / Off
local function GetSelectedFrameColorEnabled(set)
  if HasSelectedRes()
  then return JHSetTrackers.preferences.sets[set].colorFrame
  else return JHSetTrackers.Defaults.GetDefaultResourceOption(3) end
end

local function SetSelectedFrameColorEnabled(set, value)
  JHSetTrackers.preferences.sets[set].colorFrame = value
  JHSetTrackers.UI.UpdateProcs(set)
end

-- Frame Color
local function GetSelectedFrameColor(set, type, value)
  if HasSelectedRes() then
    if     (type == 1 and value == 1) then
      return JHSetTrackers.preferences.sets[set].mag.frameColorUp
    elseif (type == 1 and value == 2) then
      return JHSetTrackers.preferences.sets[set].mag.frameColorDown
    elseif (type == 2 and value == 1) then
      return JHSetTrackers.preferences.sets[set].stam.frameColorUp
    elseif (type == 2 and value == 2) then
      return JHSetTrackers.preferences.sets[set].stam.frameColorDown
    end
  else
    local s
    if     (type == 1 and value == 1) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(4)
    elseif (type == 1 and value == 2) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(5)
    elseif (type == 2 and value == 1) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(9)
    elseif (type == 2 and value == 2) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(10)
    end
    return s
  end
end

local function SetSelectedFrameColor(set, type, value, color)
  if     (type == 1 and value == 1) then
    JHSetTrackers.preferences.sets[set].mag.frameColorUp    = color
  elseif (type == 1 and value == 2) then
    JHSetTrackers.preferences.sets[set].mag.frameColorDown  = color
  elseif (type == 2 and value == 1) then
    JHSetTrackers.preferences.sets[set].stam.frameColorUp   = color
  elseif (type == 2 and value == 2) then
    JHSetTrackers.preferences.sets[set].stam.frameColorDown = color
  end
  JHSetTrackers.UI.UpdateProcs(set)
end

-- Bar Color
local function GetSelectedBarColor(set, type, value)
  if HasSelectedRes() then
    if     (type == 1 and value == 1) then
      return JHSetTrackers.preferences.sets[set].mag.barColorUp
    elseif (type == 1 and value == 2) then
      return JHSetTrackers.preferences.sets[set].mag.barColorDown
    elseif (type == 2 and value == 1) then
      return JHSetTrackers.preferences.sets[set].stam.barColorUp
    elseif (type == 2 and value == 2) then
      return JHSetTrackers.preferences.sets[set].stam.barColorDown
    end
  else
    local s
    if     (type == 1 and value == 1) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(6)
    elseif (type == 1 and value == 2) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(7)
    elseif (type == 2 and value == 1) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(11)
    elseif (type == 2 and value == 2) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(12)
    end
    return s
  end
end

local function SetSelectedBarColor(set, type, value, color)
  if     (type == 1 and value == 1) then
    JHSetTrackers.preferences.sets[set].mag.barColorUp    = color
  elseif (type == 1 and value == 2) then
    JHSetTrackers.preferences.sets[set].mag.barColorDown  = color
  elseif (type == 2 and value == 1) then
    JHSetTrackers.preferences.sets[set].stam.barColorUp   = color
  elseif (type == 2 and value == 2) then
    JHSetTrackers.preferences.sets[set].stam.barColorDown = color
  end
  JHSetTrackers.UI.UpdateProcs(set)
end

-- Threshold Indicator Color
local function GetSelectedThresholdColor(set, type)
  if HasSelectedRes() then
    if     (type == 1) then
      return JHSetTrackers.preferences.sets[set].mag.dividerColor
    elseif (type == 2) then
      return JHSetTrackers.preferences.sets[set].stam.dividerColor
    end
  else
    local s
    if     (type == 1) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(8)
    elseif (type == 2) then
      s = JHSetTrackers.Defaults.GetDefaultResourceOption(13)
    end
    return s
  end
end

local function SetSelectedTresholdColor(set, type, color)
  if     (type == 1) then
    JHSetTrackers.preferences.sets[set].mag.dividerColor   = color
  elseif (type == 2) then
    JHSetTrackers.preferences.sets[set].stam.dividerColor  = color
  end
  JHSetTrackers.UI.UpdateProcs(set)
end

-- Sounds
local function GetSelectedSoundOnProcEnabled(procType)
  if HasSelected(procType) then
    return JHSetTrackers.preferences.sets[selected[procType]].sounds.onProc.enabled
  else
    return JHSetTrackers.preferences.sounds.onProc.enabled
  end
end

local function SetSelectedSoundOnProcEnabled(procType, enabled)
  JHSetTrackers.preferences.sets[selected[procType]].sounds.onProc.enabled = enabled
end

local function GetSelectedSoundOnReadyEnabled(procType)
  if HasSelected(procType)
  then return JHSetTrackers.preferences.sets[selected[procType]].sounds.onReady.enabled
  else return JHSetTrackers.preferences.sounds.onReady.enabled end
end

local function SetSelectedSoundOnReadyEnabled(procType, enabled)
  JHSetTrackers.preferences.sets[selected[procType]].sounds.onReady.enabled = enabled
end

local function GetSelectedSoundOnProc(procType)
  if HasSelected(procType)
  then return JHSetTrackers.preferences.sets[selected[procType]].sounds.onProc.sound
  else return JHSetTrackers.preferences.sounds.onProc.sound end
end

local function SetSelectedSoundOnProc(procType, sound)
  JHSetTrackers.preferences.sets[selected[procType]].sounds.onProc.sound = sound
end

local function GetSelectedSoundOnReady(procType)
  if HasSelected(procType)
  then return JHSetTrackers.preferences.sets[selected[procType]].sounds.onReady.sound
  else return JHSetTrackers.preferences.sounds.onReady.sound end
end

local function SetSelectedSoundOnReady(procType, sound)
  JHSetTrackers.preferences.sets[selected[procType]].sounds.onReady.sound = sound
end

-- Test Sound
local function PlaySelectedTestSound(procType, condition)
  local sound = JHSetTrackers.preferences.sets[selected[procType]].sounds[condition]

  JHSetTrackers:Trace(2, "Testing sound <<1>>", sound)

  JHSetTrackers.UI.PlaySound(sound)
end

-- Disabled Controls
local function ShouldOptionBeDisabled(procType, consider)

  -- Nothing selected, always disable
  if not HasSelected(procType) then
    return true

    -- Something selected
  else

    -- If disabled, disable all fields
    if not GetSelectedEnabled(procType) then
      return true
    end

    -- If our other consideration says to disable, do it
    if consider ~= nil and not consider then
      return true
    end
  end
end

local function DisableResourceOptions()
  if JHSetTrackers.resTrackerOn then return false end
  return true
end

local function DisableResourceFrameOptions(set)
  if HasSelectedRes()
  then return not JHSetTrackers.preferences.sets[set].colorFrame
  else return true end
end

-- ============================================================================
-- Create Menu
-- ============================================================================

-- Initialize
function JHSetTrackers.Settings.Init()

  -- Copy key/value table to index/value table
  local settingsBreakout = {
    set         = {
      name        = "|cCD5031Sets|r",
      data        = { default.set },
      description = { "Select a set to customize." },
      index       = 1
    },
    monsterSet  = {
      name        = "|cCC66FFMonster Sets & Arena Weapons|r",
      data        = { default.monsterSet },
      description = { "Select a monster set to customize." },
      index       = 2
    },
    stackSet    = {
      name        = "|c996633Stacking Buff Sets|r",
      data        = { default.set },
      description = { "Select a set to customize." },
      index       = 3
    },
    artifact    = {
      name        = "|cCCFF00Artifacts|r",
      data        = { default.artifact },
      description = { "Select an artifact to customize." },
      index       = 4
    },
    synergy     = {
      name        = "|c92C843Synergies|r",
      data        = { default.synergy },
      description = { "Select a synergy to customize." },
      index       = 5
    },
    passive     = {
      name        = "|c3A97CFPassives|r",
      data        = { default.passive },
      description = { "Select a passive to customize." },
      index       = 6
    },
    resource    = {
      name        = "Resource Tracker Options",
      data        = { default.resource },
      description = { "Select a set to customize." },
      index       = 8
    },
    champion    = {
      name        = "|c92C847Champion|r |c92C847Slotables|r",
      data        = { default.champion },
      description = { "Select a CP to customize." },
      index       = 7
    }
  }

  for key, set in pairs(JHSetTrackers.Data.Sets) do
    if JHSetTrackers.resourceSets[key] then
      table.insert(settingsBreakout.resource.data, key)
      table.insert(settingsBreakout.resource.description, JHSetTrackers.resourceSets[key].description)
    end

    if set.procType == "artifact" then
      table.insert(settingsBreakout.artifact.data, key)
      table.insert(settingsBreakout.artifact.description, set.description)
    elseif set.procType == "monsterSet" then
      table.insert(settingsBreakout.monsterSet.data, key)
      table.insert(settingsBreakout.monsterSet.description, set.description)
    elseif set.procType == "stackSet" then
      table.insert(settingsBreakout.stackSet.data, key)
      table.insert(settingsBreakout.stackSet.description, set.description)
    elseif set.procType == "set" then
      if set.noUI == nil or set.noUI and set.noUI == false then
        table.insert(settingsBreakout.set.data, key)
        table.insert(settingsBreakout.set.description, set.description)
      end
    elseif set.procType == "synergy" then
      table.insert(settingsBreakout.synergy.data, key)
      table.insert(settingsBreakout.synergy.description, set.description)
    elseif set.procType == "champion" then
      table.insert(settingsBreakout.champion.data, key)
      table.insert(settingsBreakout.champion.description, set.description)
    elseif set.procType == "passive" then
      table.insert(settingsBreakout.passive.data, key)
      table.insert(settingsBreakout.passive.description, set.description)
    else
      JHSetTrackers:Trace(1, "Invalid procType: <<1>>", set.procType)
    end
  end

  optionsTable = {
      {		type = "header",   name  = "Global Settings",
          width = "full"
      },
      {		type = "button",   name  = function() if JHSetTrackers.hideInMenu then return "Show in menu" else return "Hide in menu" end end,
          tooltip = "Show or hide all enabled trackers while in this settings menu.",
          func = function(control) HideInMenu(control) end,
          width = "half"
      },
      {		type = "button",   name  = function() if JHSetTrackers.preferences.unlocked then return "Lock All" else return "Unlock All" end end,
          tooltip = "Toggle locked/unlocked state.",
          func = function(control) ToggleLocked(control) end,
          width = "half"
      },
      {		type = "checkbox", name  = "Lag Compensation",
          tooltip = "Attempt to adjust proc timing based on lag conditions. Set to ON if you are falsely seeing back-to-back procs and set to OFF if procs in close proximity to being ready are being missed.",
          getFunc = function() return GetLagCompensation() end,
          setFunc = function(value) SetLagCompensation(value) end,
          width = "full"
      },
      {		type = "checkbox", name  = "Show Outside of Combat",
          tooltip = "Set to ON to show while out of combat and OFF to only show while in combat.",
          getFunc = function() return GetShowOutOfCombat() end,
          setFunc = function(value) SetShowOutOfCombat(value) end,
          width = "full"
      },
      {		type = "checkbox", name  = "Snap to Grid",
          tooltip = "Set to ON to snap position to the specified grid.",
          getFunc = function() return GetSnapToGrid() end,
          setFunc = function(value) SetSnapToGrid(value) end,
          width = "full"
      },
      {		type = "slider",   name  = "Grid Size",
          tooltip = "Grid dimensions to snap positioning of display elements to.",
          getFunc = function() return GetGridSize() end,
          setFunc = function(size) SetGridSize(size) end,
          min = 1,
          max = 100,
          step = 1,
          clampInput = true,
          decimals = 0,
          width = "full",
          disabled = function() return not GetSnapToGrid() end,
      },
      {		type = "divider",  width = "full",
          height = 16,
          alpha = 0.25
      }
  }

  local typeSubmenus = {}

  for procType, options in pairs(settingsBreakout) do

    local typeSettings = {}

    if procType == "resource" then
      typeSettings = {
        type = "submenu",    name = options.name,
        disabled = function() return DisableResourceOptions() end,
        controls = {
          { type = "dropdown",    name = "Set",
            choices = options.data,  --JHSetTrackers.resSets,
            getFunc = function() return GetSelectedRes() end,
            setFunc = function(set) SetSelectedRes(set) end,
            choicesTooltips = options.description,
            sort = "name-up",
            width = "full",
            scrollable = true
          },
          { type = "checkbox",    name = "Resource % label",
            -- tooltip = "Set to ON to enable tracking. Note: Sets will still disable automatically when not worn.",
            getFunc = function() return GetSelectedLabelOption(selected[procType]) end,
            setFunc = function(value) SetSelectedLabelOption(selected[procType], value) end,
            width = "full",
            disabled = function() return not HasSelectedRes() end
          },
          {	type = "checkbox",	  name = "Show number of procs gained",
            -- tooltip = "Set to ON to enable tracking. Note: Sets will still disable automatically when not worn.",
            getFunc = function() return GetSelectedProcOption(selected[procType]) end,
            setFunc = function(value) SetSelectedProcOption(selected[procType], value) end,
            width = "full",
            disabled = function() return not HasSelectedRes() end
          },
          {	type = "checkbox",	  name = "Change frame color",
            -- tooltip = "Set to ON to enable tracking. Note: Sets will still disable automatically when not worn.",
            getFunc = function() return GetSelectedFrameColorEnabled(selected[procType]) end,
            setFunc = function(value) SetSelectedFrameColorEnabled(selected[procType], value) end,
            width = "full",
            disabled = function() return not HasSelectedRes() end
          },
          { type = "submenu",     name = "Magicka Colors",
            disabled = function() return not HasSelectedRes() end,
            controls = {
              {	type = "colorpicker", name = "Frame color: Can proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(4))),
                getFunc = function() return unpack(GetSelectedFrameColor(selected[procType], 1, 1)) end,
                setFunc = function(r, g, b)
                  local color = {r, g, b}
                  SetSelectedFrameColor(selected[procType], 1, 1, color)
                end,
                disabled = function() return DisableResourceFrameOptions(selected[procType]) end,
                width = "half"
              },
              {	type = "colorpicker", name = "Frame color: Can't proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(5))),
                getFunc = function() return unpack(GetSelectedFrameColor(selected[procType], 1, 2)) end,
                setFunc = function(r, g, b)
                  local color = {r, g, b}
                  SetSelectedFrameColor(selected[procType], 1, 2, color)
                end,
                disabled = function() return DisableResourceFrameOptions(selected[procType]) end,
                width = "half"
              },
              { type = "divider",  width = "full",
                height = 16,
                alpha = 0.25
              },
              {	type = "colorpicker", name = "Bar color: Can proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(6))),
                getFunc = function() return unpack(GetSelectedBarColor(selected[procType], 1, 1)) end,
                setFunc = function(r, g, b, a)
                  local color = {r, g, b, a}
                  SetSelectedBarColor(selected[procType], 1, 1, color)
                end,
                disabled = function() return not HasSelectedRes() end,
                width = "half"
              },
              {	type = "colorpicker", name = "Bar color: Can't proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(7))),
                getFunc = function() return unpack(GetSelectedBarColor(selected[procType], 1, 2)) end,
                setFunc = function(r, g, b, a)
                  local color = {r, g, b, a}
                  SetSelectedBarColor(selected[procType], 1, 2, color)
                end,
                disabled = function() return not HasSelectedRes() end,
                width = "half"
              },
              { type = "divider",  width = "full",
                height = 16,
                alpha = 0.25
              },
              {	type = "colorpicker", name = "Threshold line color",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(8))),
                getFunc = function() return unpack(GetSelectedThresholdColor(selected[procType], 1)) end,
                setFunc = function(r, g, b)
                  local color = {r, g, b}
                  SetSelectedTresholdColor(selected[procType], 1, color)
                end,
                disabled = function() return not HasSelectedRes() end,
                width = "full"
              }
            }
          },
          { type = "submenu",     name = "Stamina Colors",
            disabled = function() return not HasSelectedRes() end,
            controls = {
              {	type = "colorpicker", name = "Frame color: Can proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(9))),
                getFunc = function() return unpack(GetSelectedFrameColor(selected[procType], 2, 1)) end,
                setFunc = function(r, g, b)
                  local color = {r, g, b}
                  SetSelectedFrameColor(selected[procType], 2, 1, color)
                end,
                disabled = function() return DisableResourceFrameOptions(selected[procType]) end,
                width = "half"
              },
              {	type = "colorpicker", name = "Frame color: Can't proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(10))),
                getFunc = function() return unpack(GetSelectedFrameColor(selected[procType], 2, 2)) end,
                setFunc = function(r, g, b)
                  local color = {r, g, b}
                  SetSelectedFrameColor(selected[procType], 2, 2, color)
                end,
                disabled = function() return DisableResourceFrameOptions(selected[procType]) end,
                width = "half"
              },
              { type = "divider",  width = "full",
                height = 16,
                alpha = 0.25
              },
              {	type = "colorpicker", name = "Bar color: Can proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(11))),
                getFunc = function() return unpack(GetSelectedBarColor(selected[procType], 2, 1)) end,
                setFunc = function(r, g, b, a)
                  local color = {r, g, b, a}
                  SetSelectedBarColor(selected[procType], 2, 1, color)
                end,
                disabled = function() return not HasSelectedRes() end,
                width = "half"
              },
              {	type = "colorpicker", name = "Bar color: Can't proc",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(12))),
                getFunc = function() return unpack(GetSelectedBarColor(selected[procType], 2, 2)) end,
                setFunc = function(r, g, b, a)
                  local color = {r, g, b, a}
                  SetSelectedBarColor(selected[procType], 2, 2, color)
                end,
                disabled = function() return not HasSelectedRes() end,
                width = "half"
              },
              { type = "divider",  width = "full",
                height = 16,
                alpha = 0.25
              },
              {	type = "colorpicker", name = "Threshold line color",
                default = ZO_ColorDef:New(unpack(JHSetTrackers.Defaults.GetDefaultResourceOption(13))),
                getFunc = function() return unpack(GetSelectedThresholdColor(selected[procType], 2)) end,
                setFunc = function(r, g, b)
                  local color = {r, g, b}
                  SetSelectedTresholdColor(selected[procType], 2, color)
                end,
                disabled = function() return not HasSelectedRes() end,
                width = "full"
              }
            }
          }
        }
      }

    else
      typeSettings = {
        type = "submenu",		name = options.name,
        controls = {
          {	type = "dropdown",    name = "Selection",
            choices = options.data,
            getFunc = function() return GetSelected(procType) end,
            setFunc = function(set) SetSelected(procType, set) end,
            choicesTooltips = options.description,
            sort = "name-up",
            width = "full",
            scrollable = true
          },
          {	type = "checkbox",    name = "Enable Tracking",
            tooltip = "Set to ON to enable tracking. Note: Sets will still disable automatically when not worn.",
            getFunc = function() return GetSelectedEnabled(procType) end,
            setFunc = function(value) SetSelectedEnabled(procType, value) end,
            width = "full",
            disabled = function() return not HasSelected(procType) end
          },
          {	type = "description",
            text = "Setting ON or OFF is per-character. All other settings (such as size, color, sounds, and position) apply account-wide.",
            width = "full"
          },
          {	type = "slider",      name = "Size",
            getFunc = function() return GetSelectedSize(procType) end,
            setFunc = function(size) SetSelectedSize(procType, size) end,
            tooltip = function() return GetSizeTooltip(procType) end,
            min = 32,
            max = 300,
            step = 1,
            clampInput = true,
            decimals = 0,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType) end
          },
          {	type = "checkbox",    name = "Use Shared Size",
            tooltip = "If enabled; the display will use the global size for trackers of this type.\nThis will also allow you to change the global size by using this size slider, which will then apply to all displays of the same kind with this setting enabled.\nIf disabled; the display will use the size set specifically for this tracker, which will be saved separately if this setting is enabled later.",
            getFunc = function() return GetSelectedGlobalSizeSetting(procType) end,
            setFunc = function(value) SetSelectedGlobalSizeSetting(procType, value) end,
            width = "half",
            disabled = function() return not HasSelected(procType) end
          },
          {	type = "slider",      name = "Timer Position Up / Down",
            getFunc = function() return GetSelectedTimerY(procType) end,
            setFunc = function(y) SetSelectedTimerY(procType, y) end,
            tooltip = function() return GetTimerTooltip(procType) end,
            min = -60,
            max = 60,
            step = 1,
            clampInput = true,
            decimals = 0,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType) end
          },
          {	type = "slider",      name = "Timer Position Left / Right",
            getFunc = function() return GetSelectedTimerX(procType) end,
            setFunc = function(x) SetSelectedTimerX(procType, x) end,
            tooltip = function() return GetTimerTooltip(procType) end,
            min = -60,
            max = 60,
            step = 1,
            clampInput = true,
            decimals = 0,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType) end
          },
          -- {	type = "description",
          -- 	text = "",
          -- 	width = "half",
          -- },
          {	type = "checkbox",    name = "Use Shared Position",
            tooltip = "If enabled; the timer will use the global position for trackers of this type.\nThis will also allow you to change the global position by using the controls of the selected tracker, which will then apply to all displays of the same kind with this setting enabled.\nIf disabled; the timer will use the position set specifically for this tracker, which will be saved separately if this setting is enabled later.",
            getFunc = function() return GetSelectedGlobalTimerSetting(procType) end,
            setFunc = function(value) SetSelectedGlobalTimerSetting(procType, value) end,
            width = "full",
            disabled = function() return not HasSelected(procType) end
          },
          {	type = "colorpicker", name = "Active buff timer color",
            default = ZO_ColorDef:New(unpack(JHSetTrackers.preferences.colorUp)),
            getFunc = function() return unpack(GetSelectedUptimeColor(procType)) end,
            setFunc = function(r, g, b)
              local color = {r, g, b}
              SetSelectedUptimeColor(procType, color)
            end,
            width = "half"
          },
          {	type = "colorpicker", name = "Cooldown timer color",
            default = ZO_ColorDef:New(unpack(JHSetTrackers.preferences.colorDown)),
            getFunc = function() return unpack(GetSelectedDowntimeColor(procType)) end,
            setFunc = function(r, g, b)
              local color = {r, g, b}
              SetSelectedDowntimeColor(procType, color)
            end,
            width = "half"
          },
          {	type = "checkbox",    name = "Play Sound On Proc",
            tooltip = "Set to ON to play a sound when the set procs.",
            getFunc = function() return GetSelectedSoundOnProcEnabled(procType) end,
            setFunc = function(value) SetSelectedSoundOnProcEnabled(procType, value) end,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType) end
          },
          {	type = "dropdown",    name = "Sound On Proc",
            choices = JHSetTrackers.Sounds.names,
            choicesValues = JHSetTrackers.Sounds.options,
            getFunc = function() return GetSelectedSoundOnProc(procType) end,
            setFunc = function(value) SetSelectedSoundOnProc(procType, value) end,
            tooltip = "Sound volume based on Interface volume setting.",
            sort = "name-up",
            width = "full",
            scrollable = true,
            disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnProcEnabled(procType)) end
          },
          {	type = "button",      name = "Test Sound",
            func = function() return end,
            func = function() PlaySelectedTestSound(procType, "onProc") end,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnProcEnabled(procType)) end
          },
          {	type = "checkbox",    name = "Play Sound On Ready",
            tooltip = "Set to ON to play a sound when the set is off cooldown and ready to proc again.",
            getFunc = function() return GetSelectedSoundOnReadyEnabled(procType) end,
            setFunc = function(value) SetSelectedSoundOnReadyEnabled(procType, value) end,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType) end
          },
          {	type = "dropdown",    name = "Sound On Ready",
            choices = JHSetTrackers.Sounds.names,
            choicesValues = JHSetTrackers.Sounds.options,
            getFunc = function() return GetSelectedSoundOnReady(procType) end,
            setFunc = function(value) SetSelectedSoundOnReady(procType, value) end,
            tooltip = "Sound volume based on game interface volume setting.",
            sort = "name-up",
            width = "full",
            scrollable = true,
            disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnReadyEnabled(procType)) end
          },
          {	type = "button",      name = "Test Sound",
            func = function() PlaySelectedTestSound(procType, "onReady") end,
            width = "full",
            disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnReadyEnabled(procType)) end
          }
        }
      }

    end

    typeSubmenus[options.index] = typeSettings
  end

  for i = 1, 8 do table.insert(optionsTable, typeSubmenus[i]) end

  local CD_SettingsPanel = LAM:RegisterAddonPanel(JHSetTrackers.name, panelData)
  JHSetTrackers.Settings.window   = CD_SettingsPanel

  LAM:RegisterOptionControls(JHSetTrackers.name, optionsTable)

  local function ShowInMenu()


    UpdateVisibilityForMenu()

    -- for key, set in pairs(JHSetTrackers.Data.Sets) do
    --   local context = WM:GetControlByName(key .. "_Container")
    --   if context ~= nil and set.noUI == nil then
    --     if show then
    --       if set.enabled then
    --         context:SetHidden(false)
    --       end
    --     else
    --
    --       -- if set.procType == "artifact" then return end
    --
    --       if JHSetTrackers.Procs[key] then
    --         JHSetTrackers.UI.UpdateProcs(key)
    --         return
    --       end
    --
    --       if set.event == EVENT_POWER_UPDATE then
    --         JHSetTrackers.UI.UpdatePower(key)
    --
    --       elseif set.event == EVENT_EFFECT_CHANGED then
    --         JHSetTrackers.UI.UpdateEffect(key)
    --
    --       else
    --         JHSetTrackers.UI.Update(key)
    --       end
    --     end
    --   end
    -- end
  end

  CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
    if panel ~= CD_SettingsPanel then return end
    JHSetTrackers.inMenu = true
    JHSetTrackers.UI.showIcons = not JHSetTrackers.hideInMenu
    ShowInMenu()
  end)

  CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
    if panel ~= CD_SettingsPanel then return end
    JHSetTrackers.inMenu = false
    ShowInMenu()
    JHSetTrackers.UI:SetCombatStateDisplay()
  end)
  JHSetTrackers:Trace(2, "Finished InitSettings()")
end


function JHSetTrackers.Settings.Upgrade()
  -- v1.1.0 changes setKey names, restore previous user settings
  if JHSetTrackers.preferences.upgradedv110  == nil or not JHSetTrackers.preferences.upgradedv110 then
    local previousSetKeys = {
      ["Lich"]      = "Shroud of the Lich",
      ["Olorime"]   = "Vestment of Olorime",
      ["Trappings"] = "Trappings of Invigoration",
      ["Warlock"]   = "Vestments of the Warlock",
      ["Wyrd"]      = "Wyrd Tree's Blessing",
      ["BSW"]       = "Burning Spellweave"
      --["Slippery"]  = "Dauntless Combatant"
    }

    for previous, new in pairs(previousSetKeys) do
      if JHSetTrackers.preferences.sets[previous] ~= nil then
        JHSetTrackers.preferences.sets[new] = JHSetTrackers.preferences.sets[previous]
        JHSetTrackers.preferences.sets[previous] = nil
      end
    end

    d("[Cooldowns] Upgraded settings to v1.1.0")
    JHSetTrackers.preferences.upgradedv110 = true
  end

  -- v1.6.0 changes character settings, migrate
  if JHSetTrackers.character.upgradedv154    == nil or not JHSetTrackers.character.upgradedv154   then

    for key, set in pairs(JHSetTrackers.Data.Sets) do
      if JHSetTrackers.character[key] ~= nil then

        if set.procType == "artifact" then
          JHSetTrackers.character.artifact[key] = JHSetTrackers.character[key]
        elseif set.procType == "synergy" then
          JHSetTrackers.character.synergy[key] = JHSetTrackers.character[key]
        elseif set.procType == "champion" then
          JHSetTrackers.character.champion[key] = JHSetTrackers.character[key]  
        elseif set.procType == "passive" then
          JHSetTrackers.character.passive[key] = JHSetTrackers.character[key]
        elseif set.procType == "set" and set.noUI == nil then
          JHSetTrackers.character.set[key] = true
        else
          -- Unsupported procType
        end

        JHSetTrackers.character[key] = nil
      end
    end

    JHSetTrackers:Trace(0, "Upgraded character settings to v1.6.0")
    JHSetTrackers.character.upgradedv154 = true
  end

  if JHSetTrackers.preferences.upgradedv190  == nil or not JHSetTrackers.preferences.upgradedv190 then

    if JHSetTrackers.preferences.globalTimer ~= nil then
      if type(JHSetTrackers.preferences.globalTimer) == "table" then
        for type, data in pairs(JHSetTrackers.preferences.globalTimer) do
          if JHSetTrackers.preferences.global[type] then
            if type == "resource" then
              JHSetTrackers.preferences.global[type].x = data.x
              JHSetTrackers.preferences.global[type].y = data.y
            else
              JHSetTrackers.preferences.global[type].frame.x    = data.frame.x
              JHSetTrackers.preferences.global[type].frame.y    = data.frame.y
              JHSetTrackers.preferences.global[type].noFrame.x  = data.noFrame.x
              JHSetTrackers.preferences.global[type].noFrame.y  = data.noFrame.y
            end
          end
        end
      end
      JHSetTrackers.preferences.globalTimer = nil
    end

    if JHSetTrackers.preferences.globalSize ~= nil then
      if type(JHSetTrackers.preferences.globalSize) == "table" then
        for type, data in pairs(JHSetTrackers.preferences.globalSize) do
          if JHSetTrackers.preferences.global[type] then
            if type == "resource" then
              JHSetTrackers.preferences.global[type].size = data.size
            else
              JHSetTrackers.preferences.global[type].frame.size    = data.frame.size
              JHSetTrackers.preferences.global[type].noFrame.size  = data.noFrame.size
            end
          end
        end
      end
      JHSetTrackers.preferences.globalSize = nil
    end

    for key, set in pairs(JHSetTrackers.preferences.sets) do

      if set.globalSize ~= nil then
        if type(set.globalSize) == "boolean" then
          set.global.size = set.globalSize
        end
        set.globalSize = nil
      end

      if set.globalTimer ~= nil then
        if type(set.globalTimer) == "boolean" then
          set.global.timer = set.globalTimer
        end
        set.globalTimer = nil
      end
    end

    for key, set in pairs(JHSetTrackers.Data.Sets) do
      if JHSetTrackers.character.set[key] ~= nil then

        if set.procType == "artifact" then
          JHSetTrackers.character.artifact[key] = JHSetTrackers.character.set[key]
          JHSetTrackers.character.set[key] = nil
        elseif set.procType == "monsterSet" then
          JHSetTrackers.character.monsterSet[key] = JHSetTrackers.character.set[key]
          JHSetTrackers.character.set[key] = nil
        end
      end
    end

    JHSetTrackers:Trace(0, "Upgraded character settings to v1.9.0")
    JHSetTrackers.preferences.upgradedv190 = true
  end

  if JHSetTrackers.preferences.upgradedv200  == nil or not JHSetTrackers.preferences.upgradedv200 then
    local updatedSets = {
      ["Arms of Relequen"]  = true,
      ["Baron Zaudrus"]  = true,
      ["Belharza's Band"]  = true,
      ["Berserking Warrior"]  = true,
      ["Chaotic Whirlwind"]  = true,
      ["Death Dealer's Fete"]  = true,
      ["Dov-rha Sabatons"]  = true,
      ["Dragonguard Elite"]  = true,
      ["Frenzied Momentum"]  = true,
      ["Harpooner's Wading Kilt"]  = true,
      ["Hex Siphon"]  = true,
      ["Kinras's Wrath"]  = true,
      ["Kjalnar's Nightmare"]  = true,
      ["Mantle of Siroria"]  = true,
      ["Mechanical Acuity"]   = true,
      ["Seething Fury"]  = true,
      ["Sergeant's Mail"]  = true,
      ["Spriggan's Vigor"]  = true,
      ["Stonekeeper"]  = true,
      ["Thrassian Stranglers"]  = true,
      ["Tzogvin's Warband"]  = true,
      ["Voidcaller"]  = true,
      ["Warrior's Fury"]  = true,
      ["Yandir's Might"]  = true,
    }

    for key in pairs(updatedSets) do
      if JHSetTrackers.character.set[key] ~= nil then
        JHSetTrackers.character.stackSet[key] = JHSetTrackers.character.set[key]
        JHSetTrackers.character.set[key] = nil
      end
    end
    JHSetTrackers:Trace(0, "Upgraded character settings to v2.0.0")
    JHSetTrackers.preferences.upgradedv200 = true
  end

  if JHSetTrackers.preferences.upgradedv210  == nil or not JHSetTrackers.preferences.upgradedv210 then
    for type, data in pairs(JHSetTrackers.preferences.global) do
      if type ~= "resource" then
        local X, Y = 0, 0
        if data.frame.x then
          X = data.frame.x
          data.frame.x = nil
        end
        if data.frame.y then
          Y = data.frame.y
          data.frame.y = nil
        end

        if data.frame.timer == nil then data.frame.timer = { x = X, y = Y}
        else
          if X ~= 0 and data.frame.timer.x ~= X or data.frame.timer.x == nil then data.frame.timer.x = X end
          if Y ~= 0 and data.frame.timer.y ~= Y or data.frame.timer.y == nil then data.frame.timer.y = Y end
        end

        if data.frame.stack == nil then data.frame.stack = { x = 0, y = 0 }
        else
          if data.frame.stack.x == nil then data.frame.stack.x = 0 end
          if data.frame.stack.y == nil then data.frame.stack.y = 0 end
        end

        X, Y = 0, 0

        if data.noFrame.x then
          X = data.noFrame.x
          data.noFrame.x = nil
        end
        if data.noFrame.y then
          Y = data.noFrame.y
          data.noFrame.y = nil
        end

        if data.noFrame.timer == nil then data.noFrame.timer = { x = X, y = Y}
        else
          if X ~= 0 and data.noFrame.timer.x ~= X or data.noFrame.timer.x == nil then data.noFrame.timer.x = X end
          if Y ~= 0 and data.noFrame.timer.y ~= Y or data.noFrame.timer.y == nil then data.noFrame.timer.y = Y end
        end

        if data.noFrame.stack == nil then data.noFrame.stack = { x = 0, y = 0 }
        else
          if data.noFrame.stack.x == nil then data.noFrame.stack.x = 0 end
          if data.noFrame.stack.y == nil then data.noFrame.stack.y = 0 end
        end
      end
    end

    for key, set in pairs(JHSetTrackers.preferences.sets) do
      if JHSetTrackers.Data.Sets[key] ~= nil then

        if set.timerX       then set.timerX       = nil end
        if set.timerY       then set.timerY       = nil end
        if set.stackColor   then set.stackColor   = nil end
        if set.colorUp.r    then set.colorUp.r    = nil end
        if set.colorUp.g    then set.colorUp.g    = nil end
        if set.colorUp.b    then set.colorUp.b    = nil end
        if set.colorUp.a    then set.colorUp.a    = nil end
        if set.colorDown.r  then set.colorDown.r  = nil end
        if set.colorDown.g  then set.colorDown.g  = nil end
        if set.colorDown.b  then set.colorDown.b  = nil end
        if set.colorDown.a  then set.colorDown.a  = nil end

        if JHSetTrackers.Data.Sets[key].stacks ~= nil then

          if set.stack == nil then set.stack = JHSetTrackers.Defaults.GetDefaultStackVariables(key)
          else
            if set.stack.color  == nil then set.stack.color = { 1, 0.8, 0 } end
            if set.stack.x      == nil then set.stack.x     = 0             end
            if set.stack.y      == nil then set.stack.y     = 0             end
          end
        end
      else JHSetTrackers.preferences.sets[key] = nil end
    end

    JHSetTrackers:Trace(0, "Upgraded character settings to v2.1.0")
    JHSetTrackers.preferences.upgradedv210 = true
  end
end
