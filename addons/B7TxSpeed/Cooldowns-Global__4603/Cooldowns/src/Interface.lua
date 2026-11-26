-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @B7TxSpeed[EU]
-- Created: May 5, 2018
--
-- Interface.lua
-- -----------------------------------------------------------------------------

Cool.UI           = {}
Cool.Controls     = {}
Cool.UI.scaleBase = 100
Cool.UI.showIcons = false

local scaleBase   = Cool.UI.scaleBase
local barMax      = 86
local WM          = WINDOW_MANAGER
local AM          = ANIMATION_MANAGER
local EM          = EVENT_MANAGER
local time        = GetGameTimeMilliseconds

local function SnapToGrid(position, gridSize)
  -- Round down
  position = math.floor(position)

  -- Return value to closest grid point
  if (position % gridSize >= gridSize / 2)
  then return position + (gridSize - (position % gridSize))
  else return position - (position % gridSize) end
end

local function SetPosition(key, left, top)
  Cool:Trace(2, "Setting - Left: " .. left .. " Top: " .. top)
  local context = WM:GetControlByName(key .. "_Container")
  context:ClearAnchors()
  context:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

local function SavePosition(key)
  local context = WM:GetControlByName(key .. "_Container")
  local top     = context:GetTop()
  local left    = context:GetLeft()

  if Cool.preferences.snapToGrid then
    local gridSize = Cool.preferences.gridSize
    top  = SnapToGrid(top, gridSize)
    left = SnapToGrid(left, gridSize)
    SetPosition(key, left, top)
  end

  Cool:Trace(2, "Saving position for <<1>> - Left: <<2>> Top: <<3>>", key, left, top)

  Cool.preferences.sets[key].x = left
  Cool.preferences.sets[key].y = top
end

local function GetBarContraints(key)
  return Cool.UI.GetSavedScaleForControl(key) * (barMax / scaleBase)
end

local function SetActivationTexture(control, settings)
  local c = control --Cool.Controls[key]

  if not c.activation then
    local x = WM:CreateControl(nil, c, CT_TEXTURE)
    x:SetHidden(false)
    x:SetAnchor(CENTER, c, CENTER, 0, 0)
    x:SetDimensions(160, 160)
    x:SetTexture("/esoui/art/crafting/white_burst.dds")
    x:SetColor(unpack(settings.colorDown))
    x:SetDrawLayer(DL_BACKGROUND)
    c.activation = x
  end
end

function Cool.UI.FormatTimerY(y)
  -- to make higher value move the timer up and lower down
  local value
  if      y == 0 then value = 0
  elseif  y  < 0 then value = y + (y * -2)
  elseif  y  > 0 then value = y - (y + y)
  end
  return value
end

function Cool.UI.GetSavedScaleForControl(key)
  local set   = Cool.Data.Sets[key]
  local saved = Cool.preferences.sets[key]
  if not saved.global.size then return saved.size
  else
    if set.showFrame
    then return Cool.preferences.global[set.procType].frame.size
    else return Cool.preferences.global[set.procType].noFrame.size end
  end
end

function Cool.UI.GetSavedTimerPosition(key)
  local x, y  = 0, 0
  local set   = Cool.Data.Sets[key]
  local saved = Cool.preferences.sets[key]
  if saved.global.timer == false then
    x = saved.timer.x
    y = saved.timer.y
  else
    if set.procType ~= "synergy" then
      if set.showFrame then
        x = Cool.preferences.global[set.procType].frame.timer.x
        y = Cool.preferences.global[set.procType].frame.timer.y
      else
        x = Cool.preferences.global[set.procType].noFrame.timer.x
        y = Cool.preferences.global[set.procType].noFrame.timer.y
      end
    else
      if set.showFrame then
        x = Cool.preferences.global[set.procType].frame.x
        y = Cool.preferences.global[set.procType].frame.y
      else
        x = Cool.preferences.global[set.procType].noFrame.x
        y = Cool.preferences.global[set.procType].noFrame.y
      end
    end
  end
  return x, y
end

function Cool.UI.UpdateBarConstraints(key)
  local c = Cool.Controls[key]
  if c then
    c:SetScale(Cool.UI.GetSavedScaleForControl(key) / scaleBase)
    local l = GetBarContraints(key)
    c.bar:SetDimensionConstraints(l, 0, l, l)
  end
end

function Cool.UI.JorvuldCheck(setKey)
  -- if not Cool.hasJorvuld then return false end

  local set = Cool.Data.Sets[setKey]
  local shouldBuff = false

  if type(set.id) == 'table' then
    for i=1, #set.id do
      if Cool.JorvuldIds[set.id[i]] then
        shouldBuff = true
        break
      end
    end
  else
    if Cool.JorvuldIds[set.id] then
      shouldBuff = true
    end
  end
  return shouldBuff
end

function Cool.UI.IsSetInactive(setKey)
  local set       = Cool.Data.Sets[setKey]
  local now       = time() / 1000
  local upTime    = set.endTime - now
  local downTime  = set.cdEnd   - now

  if (upTime <= 0 and downTime <= 0)
  then return true
  else return false end
end

function Cool.UI.Draw(key)

  local set = Cool.Data.Sets[key];
  if set.noUI then return end

  local container = WM:GetControlByName(key .. "_Container")
  local stacksWithinIcon = Cool.preferences.stacksWithinIcon

  -- Enable display
  if set.enabled then

    local saved = Cool.preferences.sets[key]

    -- Draw UI and create context if it doesn't exist
    if container == nil then
      Cool:Trace(2, "Drawing: <<1>>", key)

      local c = WM:CreateTopLevelWindow(key .. "_Container")
      c:SetClampedToScreen(true)
      c:SetDimensions(scaleBase, scaleBase)
      c:ClearAnchors()
      c:SetMouseEnabled(true)
      c:SetAlpha(1)
      c:SetMovable(Cool.preferences.unlocked)
      c:SetHidden(not Cool.UI.showIcons)
      -- if Cool.inMenu or not Cool.HUDHidden
      -- then c:SetHidden(true)
      -- else c:SetHidden(false) end

      c:SetScale(Cool.UI.GetSavedScaleForControl(key) / scaleBase)
      c:SetHandler("OnMoveStop", function(...) SavePosition(key) end)

      local r = WM:CreateControl(key .. "_Icon", c, CT_TEXTURE)
      r:SetTexture(set.texture)
      r:SetDimensions(scaleBase, scaleBase)
      r:SetAnchor(CENTER, c, CENTER, 0, 0)
      r:SetDrawLevel(3)

      if set.showFrame then
        if not set.procType == "passive" then
          -- Add black 1px border around the icon (not for passive icon)
          local border = WM:CreateControl(key .. "_Border", c, CT_BACKDROP)
          border:SetDimensions(scaleBase, scaleBase)
          border:SetAnchor(CENTER, c, CENTER, 0, 0)
          border:SetCenterColor(0, 0, 0, 0)
          border:SetEdgeColor(0, 0, 0, 1)
          border:SetDrawLevel(4)
          border:SetEdgeTexture("", 1, 1, 1, 1)
        end

        local f = WM:CreateControl(key .. "_Frame", c, CT_TEXTURE)
        if set.procType == "passive" then
          -- Gamepad frame is pretty, but looks bad scaled up
          --f:SetTexture("/esoui/art/miscellaneous/gamepad/gp_passiveframe_128.dds")
          f:SetTexture("/esoui/art/actionbar/passiveabilityframe_round_up.dds")

          -- Add 5 to make the frame sit where it should.
          f:SetDimensions(scaleBase + 5, scaleBase + 5)
        else
          f:SetTexture("/esoui/art/actionbar/gamepad/gp_abilityframe64.dds")
          f:SetDimensions(scaleBase, scaleBase)
        end
        f:SetAnchor(CENTER, c, CENTER, 0, 0)
        f:SetDrawLevel(4)

        c.frame = f
      end

      local font = ZoFontWinH1:GetFontInfo()
      if stacksWithinIcon then
        font = "$(MEDIUM_FONT)"
      end

      if set.stacks ~= nil then

        local s = WM:CreateControl(key .. "_Stacks", c, CT_LABEL)
        s:SetAlpha(1)
        s:SetDrawLevel(5)
        if set.hideTimer then
          s:SetAnchor(CENTER, c, CENTER, 0, 0)
          s:SetFont(font .. "|45|thick-outline")
        elseif stacksWithinIcon then
          s:SetAnchor(BOTTOM, c, TOP, 1, 46)
          s:SetFont(font .. "|40|outline")
        else
          s:SetAnchor(BOTTOM, c, TOP, 0, 0)
          s:SetFont(font .. "|45|thick-outline")
        end

        s:SetColor(unpack(saved.stack.color))

        c.stacks = s
      end

      local l     = WM:CreateControl(key .. "_Label", c, CT_LABEL)
      local x, y  = Cool.UI.GetSavedTimerPosition(key)
      l:SetAlpha(1)
      l:SetDrawLevel(5)
      if stacksWithinIcon then
        l:SetAnchor(CENTER, c, 	CENTER, x + 1, (Cool.UI.FormatTimerY(y) + 16))
      else
        l:SetAnchor(CENTER, c, 	CENTER, x, Cool.UI.FormatTimerY(y))
      end
      if set.hideTimer then
        l:SetHidden(true)
      end

      if set.procCounter then
        local n = WM:CreateControl(key .. "_Counter", c, CT_LABEL)
        n:SetAnchor(TOP, c, BOTTOM, 0, -5)
        n:SetAlpha(1)
        n:SetFont(font .. "|$(KB_30)|thick-outline")
        n:SetDrawLevel(5)
        n:SetHidden(false)
        n:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        c.counter = n
      end

      if set.resource then
        l:SetColor(unpack(saved.colorDown))
        if stacksWithinIcon then
          l:SetFont(font .. "|$(KB_40)|outline")
        else
          l:SetFont(font .. "|$(KB_40)|thick-outline")
        end

        if saved.colorFrame then c.frame:SetColor(unpack(saved.colorDown)) end

        local bg = WM:CreateControl(key .. "_BG", c, CT_BACKDROP)
        bg:SetDimensions(scaleBase, scaleBase)
        bg:SetAnchor(TOP, c, TOP, 0, 0)
        bg:SetCenterColor(0, 0, 0, 0.4)
        bg:SetEdgeColor(0, 0, 0, 1)
        bg:SetDrawLevel(1)

        local color = Cool.Procs[key].powerType == POWERTYPE_STAMINA and saved.stam.barColorDown or saved.mag.barColorDown
        local barConstraints = GetBarContraints(key)
        local bar = WM:CreateControl(key .. "_BAR", c, CT_BACKDROP)

        bar:SetInheritScale(false)
        bar:SetDimensions(barConstraints, barConstraints)
        bar:SetDimensionConstraints(barConstraints, 0, barConstraints, barConstraints)
        bar:SetAnchor(BOTTOM, c, BOTTOM, 0, -7)
        bar:SetCenterColor(unpack(color))
        bar:SetEdgeColor(unpack(color))
        bar:SetAlpha(0.7)
        bar:SetEdgeTexture("", 1, 1, 2, 2)
        bar:SetDrawLevel(2)

        local t = WM:CreateControl(key .. "_Threshold", c, CT_BACKDROP)
        t:SetDimensions(scaleBase, 4)
        t:SetAnchor(CENTER, c, BOTTOM, 0, - set.threshold)
        t:SetCenterColor(0, 0, 0, 1)
        t:SetEdgeColor(0, 0, 0, 1)
        t:SetEdgeTexture("", 1, 1, 0, 0)
        t:SetDrawLevel(2)

        c.bg      = bg
        c.bar     = bar
        c.line    = t

      elseif set.id == 154737 then -- sul-xan

        local b = WM:CreateControl(key .. "_Bar", c, CT_STATUSBAR)
        b:SetAnchor(TOPLEFT,  c, BOTTOMLEFT,  0, 0)
        b:SetAnchor(TOPRIGHT, c, BOTTOMRIGHT, 0, 0)
        b:SetHeight(15)
        b:SetColor(unpack(Cool.preferences.sets[key].colorUp))
	      b:SetTexture([[/esoui/art/miscellaneous/progressbar_genericfill.dds]])
	      b:SetTextureCoords(0, 1, 0, 0.625)
	      b:SetMinMax(0, 1)

        c.bar = b

        l:SetFont(font .. "|$(KB_48)|thick-outline")
        l:SetColor(unpack(Cool.preferences.sets[key].colorUp))

      else
        l:SetFont(font .. "|$(KB_48)|thick-outline")
        l:SetColor(unpack(Cool.preferences.sets[key].colorUp))
      end

      c.icon       = r
      c.label      = l
      c.isUpdating = false
      c.set        = set

      Cool.Controls[key] = c
      SetPosition(key, saved.x, saved.y)

      if key == Cool.spaulderName then
        Cool.Controls[key].activation = nil
        SetActivationTexture(Cool.Controls[key], saved)
      end

    else -- Reuse context
      -- if Cool.inMenu or (not Cool.HUDHidden and Cool.inventoryHidden) then
        container:SetHidden(not Cool.UI.showIcons)
      -- end
    end

    if key == Cool.spaulderName then
      Cool.UI.UpdateToggled(key, Cool.preferences.spaulderActive)
    else

      if set.event == EVENT_POWER_UPDATE then
        current, max, effective = GetUnitPower("player", set.powerType)
        set.currentValue = (current / effective) * 100
        Cool.UI.UpdatePower(key)
      end
    end

    if set.procCounter then Cool.UI.UpdateProcs(key) end

    if set.stacks ~= nil then
      Cool.Tracking.UpdateSetBuffInfo(key)
    end

    -- Disable display
  else
    if container ~= nil then container:SetHidden(true) end
  end
  Cool:Trace(2, "Finished DrawUI()")
end

function Cool.UI:SetCombatStateDisplay()
  -- Cool:Trace(3, "Setting combat state display, in combat: <<1>>", tostring(Cool.isInCombat))

  if Cool.isInCombat or Cool.preferences.showOutsideCombat and not Cool.isDead then
    Cool.UI.showIcons = Cool.UI.ResolveScene()
  else
    Cool.UI.showIcons = false
    -- Cool.UI.ShowIcon(false)
  end
  Cool.UI.ShowIcon(Cool.UI.showIcons)
end

function Cool.UI:ResetProcs()
		Cool:Trace(2, "Resetting Procs")
		-- if table.getn(Cool.Procs) <= 0 then
		-- 		EM:UnregisterForEvent(Cool.name .. "_Power", EVENT_POWER_UPDATE)
		-- 		return
		-- end

		for k, v in pairs(Cool.Procs) do
				if Cool.Procs[k] then
						local t = Cool.Procs[k].times
						Cool.Procs[k].times = 0
						Cool:Trace(2, "[<<1>>]: times = <<2>>. was <<3>>", k, Cool.Procs[k].times, t)
						Cool.UI.UpdateProcs(k)
				end
		end
end

function Cool.UI.PlaySound(sound)
    if sound.enabled then
        PlaySound(SOUNDS[sound.sound])
    end
end

function Cool.UI.Update(setKey)
  local set = Cool.Data.Sets[setKey]

  if set == nil then return end
  if set.event == EVENT_POWER_UPDATE or set.event == EVENT_EFFECT_CHANGED then return end

  -- local container = WM:GetControlByName(setKey .. "_Container")
  -- local icon      = WM:GetControlByName(setKey .. "_Icon")
  -- local label     = WM:GetControlByName(setKey .. "_Label")
  local c      = Cool.Controls[setKey]

  local bonus = 0

  if Cool.hasJorvuld then
    if Cool.UI.JorvuldCheck(setKey) then
      local seconds = set.durationms / 1000
      bonus = seconds * 0.4
    end
  end

  local upTime   = ((set.endTime / 1000) - (time() / 1000)) + bonus
  local downTime = ((set.timeOfProc + set.cooldownDurationMs) / 1000) - (time() / 1000)

  if (upTime <= 0) then
    if (downTime <= 0) then

      c.icon:SetColor(1, 1, 1, 1)

      EM:UnregisterForUpdate(Cool.name .. setKey .. "Count")
      set.onCooldown = false
      c.label:SetText("")
      Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onReady)
    else
      c.label:SetColor(unpack(Cool.preferences.sets[setKey].colorDown))
      c.icon:SetColor(0.5, 0.5, 0.5, 1)
      if (downTime < 2)
      then c.label:SetText(string.format("%.1f", downTime))
      else c.label:SetText(string.format("%.0f", downTime)) end
    end

  else
    c.label:SetColor(unpack(Cool.preferences.sets[setKey].colorUp))
    c.icon:SetColor(1, 1, 1, 1)

    if (upTime < 2)
    then c.label:SetText(string.format("%.1f", upTime))
    else c.label:SetText(string.format("%.0f", upTime)) end
  end
end

function Cool.UI.UpdateEffect(setKey)

  local function OnSetInactive(key, control)
    EM:UnregisterForUpdate(Cool.name .. key .. "Count")
    if control ~= nil then
      control.isUpdating = false
      control.label:SetText("")
      control.icon:SetColor(1, 1, 1, 1)
      Cool.UI.PlaySound(Cool.preferences.sets[key].sounds.onReady)
    end
  end

  local set   = Cool.Data.Sets[setKey]
  local c     = WM:GetControlByName(setKey .. "_Container")

  local now         = time() / 1000
  local upTime      = set.endTime - now
  local downTime    = set.cdEnd - now
  local inactive    = (upTime < 0 and downTime < 0) and true or false

  -- if not set.enabled then
  --   if (upTime <= 0 and downTime <= 0) then
  --     EM:UnregisterForUpdate(Cool.name .. setKey .. "Count")
  --     c.label:SetText("")
  --     c.icon:SetColor(1, 1, 1, 1)
  --     if c.stacks then c.stacks:SetText("") end
  --     Cool.Tracking.UpdateTrackingStateForEffect(setKey, false)
  --     return
  --   end
  -- end

  if (upTime > 0) then
    c.icon:SetColor(1, 1, 1, 1)
    c.label:SetColor(unpack(Cool.preferences.sets[setKey].colorUp))
    if (upTime < 2)
    then c.label:SetText(string.format("%.1f", upTime))
    else c.label:SetText(string.format("%.0f", upTime)) end

  else

    if (downTime > 0) then
      c.label:SetColor(unpack(Cool.preferences.sets[setKey].colorDown))
      c.icon:SetColor(0.5, 0.5, 0.5, 1)
      if (downTime < 2)
      then c.label:SetText(string.format("%.1f", downTime))
      else c.label:SetText(string.format("%.0f", downTime)) end
    else
    --   EM:UnregisterForUpdate(Cool.name .. setKey .. "Count")
      c.label:SetText("")
      c.icon:SetColor(1, 1, 1, 1)
    --   Cool.UI.PlaySound(Cool.preferences.sets[setKey].sounds.onReady)
    end
  end

  if c.stacks and set.stacks then
    if set.stacks > 0
    then c.stacks:SetText(set.stacks)
    else c.stacks:SetText("") end
  end
end

-- SetInsets(number left, number top, number right, number bottom)
-- /script local c=Cool.Controls["Pearls of Ehlnofey"] c.bar:SetInsets(2.5, 2.5, 2.5, 2.5)

function Cool.UI.UpdateProcs(setKey)
  local set    = Cool.Procs[setKey]
  local data   = Cool.Data.Sets[setKey]
  local c      = Cool.Controls[setKey]
  local saved  = Cool.preferences.sets[setKey]

  if set == nil or c == nil or c.counter == nil then return end

  -- Multiplier below the icon. showProcs only exists for resource sets.
  local color = saved.colorUp
  if data.resource and Cool.PlayerPower.ult == 100 then color = saved.colorDown end

  if saved.showProcs ~= false and set.times > 0 then
    c.counter:SetText("x" .. set.times)
  else
    c.counter:SetText("")
  end
  c.counter:SetColor(unpack(color))

  -- Everything below is only for the resource bar
  if not data.resource then return end

  local max = GetBarContraints(setKey)
  c.bar:SetHeight(max * (set.current / 100))

    if saved.showPercent then
      local m = set.current <= 99 and string.format("%.0f", set.current) .. "%" or ""
      c.label:SetText(m)
    else
      c.label:SetText("")
    end

    color = set.powerType == POWERTYPE_STAMINA and saved.stam.dividerColor or saved.mag.dividerColor
    c.line:SetCenterColor(unpack(color))
    c.line:SetEdgeColor(unpack(color))

    if set.current < data.threshold then
      c.label:SetColor(unpack(saved.colorUp))

      if saved.colorFrame then
        color = set.powerType == POWERTYPE_STAMINA and saved.stam.frameColorUp or saved.mag.frameColorUp
        c.frame:SetColor(unpack(color))
      else
        c.frame:SetColor(1, 1, 1, 1)
      end

      color = set.powerType == POWERTYPE_STAMINA and saved.stam.barColorUp or saved.mag.barColorUp
      c.bar:SetCenterColor(unpack(color))
      c.bar:SetEdgeColor(unpack(color))
    else
      c.label:SetColor(unpack(saved.colorDown))

      if saved.colorFrame then
        color = set.powerType == POWERTYPE_STAMINA and saved.stam.frameColorDown or saved.mag.frameColorDown
        c.frame:SetColor(unpack(color))
      else
        c.frame:SetColor(1, 1, 1, 1)
      end

      color = set.powerType == POWERTYPE_STAMINA and saved.stam.barColorDown or saved.mag.barColorDown
      c.bar:SetCenterColor(unpack(color))
      c.bar:SetEdgeColor(unpack(color))
    end
end

function Cool.UI.UpdateToggled(setKey, active)
  local set    = Cool.Data.Sets[setKey]
  local c      = Cool.Controls[setKey]
  local saved  = Cool.preferences.sets[setKey]

  if active ~= nil then
    if set.active ~= active then
      if active == true
      then Cool.UI.PlaySound(saved.sounds.onProc)
      else Cool.UI.PlaySound(saved.sounds.onReady) end
    end
    set.active = active
  end

  if set.active == false then
    c.icon:SetColor(0.5, 0.5, 0.5, 1)
    c.activation:SetColor(unpack(saved.colorDown))
    -- c.label:SetColor(unpack(saved.colorDown))
    c.label:SetText("")
  else
    c.icon:SetColor(1, 1, 1, 1)
    c.label:SetColor(unpack(saved.colorUp))
    c.activation:SetColor(unpack(saved.colorUp))
    if set.count > 0 then
      -- c.activation:SetHidden(false)
      if set.count > 6
      then c.label:SetText("6")
      else c.label:SetText(set.count) end
    else
      c.label:SetText("")
    end
  end

  Cool.preferences.spaulderActive = set.active
  -- local state = set.active and "Activated" or "Deactivated"
  -- Cool:Trace(1, "Spaulder: <<1>>", state)
end

local function RoundDown(v)
  local r = 0
  if v >= 1 and v < 2 then r = 1
  elseif v >=  1 and v <  2 then r =  1
  elseif v >=  2 and v <  3 then r =  2
  elseif v >=  3 and v <  4 then r =  3
  elseif v >=  4 and v <  5 then r =  4
  elseif v >=  5 and v <  6 then r =  5
  elseif v >=  6 and v <  7 then r =  6
  elseif v >=  7 and v <  8 then r =  7
  elseif v >=  8 and v <  9 then r =  8
  elseif v >=  9 and v < 10 then r =  9
  elseif v >= 10 and v < 11 then r = 10
  elseif v >= 11 and v < 12 then r = 11
  elseif v >= 12 and v < 13 then r = 12
  elseif v >= 13 and v < 14 then r = 13
  elseif v >= 14 and v < 15 then r = 14
  elseif v >= 15 then r = v end
  local roundedDown = string.format("%.0f", r)
  if roundedDown == "0" then roundedDown = "" end
  return roundedDown
end

function Cool.UI.UpdatePower(setKey)
  local set = Cool.Data.Sets[setKey]
  local label = WM:GetControlByName(setKey .. "_Label")

  label:SetColor(unpack(Cool.preferences.sets[setKey].colorUp))

  local bonus = 1

  if Cool.hasJorvuld then
    bonus = Cool.UI.JorvuldCheck(setKey) and 1.4 or 1
  end

  bonus = Cool.UI.JorvuldCheck(setKey) and 1.4 or 1
  if set.scaling ~= nil then
      if type(set.scaling) == "table" then
        local a = set.scaling.scalar / set.scaling.start
        local b = set.scaling.start - set.currentValue
        local c = set.scaling.start - set.scaling.max
        if b >= c and not Cool.isDead then
          local n = a * c
          local N = RoundDown(n)
          if N ~= "" then
            label:SetText(N .. "")
          else
            label:SetText("")
          end
        else
          local n = a * b
          local N = RoundDown(n)
          if N ~= "" then
            label:SetText(N .. "")
          else
            label:SetText("")
          end
        end
  
      elseif set.scaling then
        local value = (set.currentValue / set.scaling) * bonus
        if value >= 1
        then label:SetText(string.format("%.1f", value))
        else label:SetText("") end
      end
    else
      label:SetText(set.currentValue)
    end
end

function Cool.UI.ResolveScene()
  if not SCENE_MANAGER.currentScene then return false end
  local scene = SCENE_MANAGER.currentScene:GetName()

  local show = false

  -- if scene == "hud" or scene == "hudui" then
  if not Cool.HUDHidden then
    -- Cool.HUDHidden = false
    show = true
    -- d("1")
  elseif scene == "gameMenuInGame" and Cool.Settings.window ~= nil then
    if not Cool.Settings.window:IsHidden() then
      show = not Cool.hideInmenu
      -- d("2")
    end
  else
    Cool.HUDHidden = true

    if scene == "inventory" then
      Cool.inventoryHidden = false
    end
  end
  -- d(tostring(show))
  return show
end

function Cool.UI.ToggleHUD()
  local hud   = SCENE_MANAGER:GetScene("hud")
  local hudUI = SCENE_MANAGER:GetScene("hudui")
  local inv   = SCENE_MANAGER:GetScene("inventory")

  local function OnStateChanged(old, new)
    if new == SCENE_SHOWN then
      Cool.HUDHidden    = false
      -- Cool.UI.showIcons = true
    else
      Cool.HUDHidden    = true
    end

    Cool.UI:SetCombatStateDisplay()
  end

  hud:RegisterCallback("StateChange", OnStateChanged)
  hudUI:RegisterCallback("StateChange", OnStateChanged)

  local function inventoryState(old, new)
    if new == SCENE_SHOWN then
      Cool.inventoryHidden  = false
      -- Cool.UI.showIcons     = false
    else
      Cool.inventoryHidden  = true
    end
    Cool.UI:SetCombatStateDisplay()
  end

  inv:RegisterCallback("StateChange", inventoryState)

  Cool.UI.showIcons = Cool.UI.ResolveScene()

  Cool:Trace(2, "Finished ToggleHUD()")
end

function Cool.UI.ShowIcon(shouldShow)

  for k, v in pairs(Cool.Controls) do
    local c = Cool.Controls[k]

    if c ~= nil then
      local set = Cool.Data.Sets[k]

      if set ~= nil then
        if (shouldShow and set.enabled)
        then c:SetHidden(false)
        else c:SetHidden(true) end
      end
    end
  end

  -- for key, set in pairs(Cool.Data.Sets) do
  --   local c = WM:GetControlByName(key .. "_Container")
  --   if c ~= nil and set.event ~= "Amp" then
  --     if (shouldShow and set.enabled)
  --     then c:SetHidden(false)
  --     else c:SetHidden(true) end
  --   end
  -- end
end

function Cool.UI.SlashCommand(command)
  -- Debug Options ----------------------------------------------------------
  if command == "debug 0" then
    d(Cool.prefix .. "Setting debug level to 0 (Off)")
    Cool.debugMode = 0
    Cool.preferences.debugMode = 0
  elseif command == "debug 1" then
    d(Cool.prefix .. "Setting debug level to 1 (Low)")
    Cool.debugMode = 1
    Cool.preferences.debugMode = 1
  elseif command == "debug 2" then
    d(Cool.prefix .. "Setting debug level to 2 (Medium)")
    Cool.debugMode = 2
    Cool.preferences.debugMode = 2
  elseif command == "debug 3" then
    d(Cool.prefix .. "Setting debug level to 3 (High)")
    Cool.debugMode = 3
    Cool.preferences.debugMode = 3

    -- Unfiltered Events
  elseif command == "all on" then
    d(Cool.prefix .. "Registering unfiltered events, setting debug mode to 1")
    Cool.debugMode = 1
    Cool.preferences.debugMode = 1
    Cool.Tracking.RegisterUnfiltered()
  elseif command == "all off" then
    d(Cool.prefix .. "Unregistering unfiltered events, setting debug mode to 0")
    Cool.Tracking.UnregisterUnfiltered()
    Cool.debugMode = 0
    Cool.preferences.debugMode = 0

  elseif command == "spaulder" then
    Cool.spaulderTrack = not Cool.spaulderTrack
    Cool.Tracking.TrackSpaulder(Cool.spaulderTrack)

  elseif command == "buffs" then
    Cool.Tracking.GetActiveBuffs()

    -- Default ----------------------------------------------------------------
  else
    d(Cool.prefix .. "Command not recognized!")
  end
end
