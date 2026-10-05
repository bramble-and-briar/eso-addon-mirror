-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @kabs12[NA]
-- Created: May 5, 2018
--
-- Interface.lua
-- -----------------------------------------------------------------------------

JHSetTrackers.UI           = {}
JHSetTrackers.Controls     = {}
JHSetTrackers.UI.scaleBase = 100
JHSetTrackers.UI.showIcons = false

local scaleBase   = JHSetTrackers.UI.scaleBase
local barMax      = 86
local WM          = WINDOW_MANAGER
local AM          = ANIMATION_MANAGER
local EM          = EVENT_MANAGER
local SDM         = SKILLS_DATA_MANAGER
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
  JHSetTrackers:Trace(2, "Setting - Left: " .. left .. " Top: " .. top)
  local context = WM:GetControlByName(key .. "_Container")
  context:ClearAnchors()
  context:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

local function SavePosition(key)
  local context = WM:GetControlByName(key .. "_Container")
  local top     = context:GetTop()
  local left    = context:GetLeft()

  if JHSetTrackers.preferences.snapToGrid then
    local gridSize = JHSetTrackers.preferences.gridSize
    top  = SnapToGrid(top, gridSize)
    left = SnapToGrid(left, gridSize)
    SetPosition(key, left, top)
  end

  JHSetTrackers:Trace(2, "Saving position for <<1>> - Left: <<2>> Top: <<3>>", key, left, top)

  JHSetTrackers.preferences.sets[key].x = left
  JHSetTrackers.preferences.sets[key].y = top
end

local function GetBarContraints(key)
  return JHSetTrackers.UI.GetSavedScaleForControl(key) * (barMax / scaleBase)
end

local function SetActivationTexture(control, settings)
  local c = control --JHSetTrackers.Controls[key]

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

function JHSetTrackers.UI.FormatTimerY(y)
  -- to make higher value move the timer up and lower down
  local value
  if      y == 0 then value = 0
  elseif  y  < 0 then value = y + (y * -2)
  elseif  y  > 0 then value = y - (y + y)
  end
  return value
end

function JHSetTrackers.UI.GetSavedScaleForControl(key)
  local set   = JHSetTrackers.Data.Sets[key]
  local saved = JHSetTrackers.preferences.sets[key]
  if not saved.global.size then return saved.size
  else
    if set.showFrame
    then return JHSetTrackers.preferences.global[set.procType].frame.size
    else return JHSetTrackers.preferences.global[set.procType].noFrame.size end
  end
end

function JHSetTrackers.UI.GetSavedTimerPosition(key)
  local x, y  = 0, 0
  local set   = JHSetTrackers.Data.Sets[key]
  local saved = JHSetTrackers.preferences.sets[key]
  if saved.global.timer == false then
    x = saved.timer.x
    y = saved.timer.y
  else
    if set.procType ~= "synergy" then
      if set.showFrame then
        x = JHSetTrackers.preferences.global[set.procType].frame.timer.x
        y = JHSetTrackers.preferences.global[set.procType].frame.timer.y
      else
        x = JHSetTrackers.preferences.global[set.procType].noFrame.timer.x
        y = JHSetTrackers.preferences.global[set.procType].noFrame.timer.y
      end
    else
      if set.showFrame then
        x = JHSetTrackers.preferences.global[set.procType].frame.x
        y = JHSetTrackers.preferences.global[set.procType].frame.y
      else
        x = JHSetTrackers.preferences.global[set.procType].noFrame.x
        y = JHSetTrackers.preferences.global[set.procType].noFrame.y
      end
    end
  end
  return x, y
end

function JHSetTrackers.UI.UpdateBarConstraints(key)
  local c = JHSetTrackers.Controls[key]
  if c then
    c:SetScale(JHSetTrackers.UI.GetSavedScaleForControl(key) / scaleBase)
    local l = GetBarContraints(key)
    c.bar:SetDimensionConstraints(l, 0, l, l)
  end
end

function JHSetTrackers.UI.JorvuldCheck(setKey)
  -- if not JHSetTrackers.hasJorvuld then return false end

  local set = JHSetTrackers.Data.Sets[setKey]
  local shouldBuff = false

  if type(set.id) == 'table' then
    for i=1, #set.id do
      if JHSetTrackers.JorvuldIds[set.id[i]] then
        shouldBuff = true
        break
      end
    end
  else
    if JHSetTrackers.JorvuldIds[set.id] then
      shouldBuff = true
    end
  end
  return shouldBuff
end

function JHSetTrackers.UI.IsSetInactive(setKey)
  local set       = JHSetTrackers.Data.Sets[setKey]
  local now       = time() / 1000
  local upTime    = set.endTime - now
  local downTime  = set.cdEnd   - now

  if (upTime <= 0 and downTime <= 0)
  then return true
  else return false end
end

function JHSetTrackers.UI.Draw(key)

  local set = JHSetTrackers.Data.Sets[key];
  if set.noUI then return end

  local container = WM:GetControlByName(key .. "_Container")

  -- Enable display
  if set.enabled then

    local saved = JHSetTrackers.preferences.sets[key]

    -- Draw UI and create context if it doesn't exist
    if container == nil then
      JHSetTrackers:Trace(2, "Drawing: <<1>>", key)

      local c = WM:CreateTopLevelWindow(key .. "_Container")
      c:SetClampedToScreen(true)
      c:SetDimensions(scaleBase, scaleBase)
      c:ClearAnchors()
      c:SetAlpha(1)
      c:SetHidden(not JHSetTrackers.UI.showIcons)
      -- if JHSetTrackers.inMenu or not JHSetTrackers.HUDHidden
      -- then c:SetHidden(true)
      -- else c:SetHidden(false) end

      c:SetScale(JHSetTrackers.UI.GetSavedScaleForControl(key) / scaleBase)

      local r = WM:CreateControl(key .. "_Icon", c, CT_TEXTURE)
      r:SetTexture(set.texture)
      r:SetDimensions(scaleBase, scaleBase)
      r:SetAnchor(CENTER, c, CENTER, 0, 0)
      r:SetDrawLevel(3)

      if set.showFrame then
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

      local font = "$(BOLD_FONT)" -- console-safe; ZoFontWinH1 is not available on PS5

      if set.stacks ~= nil then

        local s = WM:CreateControl(key .. "_Stacks", c, CT_LABEL)
        s:SetAlpha(1)
        s:SetDrawLevel(5)
        if key == "Death Dealer's Fete" then
          -- DDF: stack number belongs in the center of the icon and is intentionally
          -- smaller than the generic stack label. Parent scaling still scales both.
          s:SetAnchor(CENTER, c, CENTER, 0, 0)
          s:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
          s:SetVerticalAlignment(TEXT_ALIGN_CENTER)
          s:SetDimensions(64, 64)
          s:SetFont(font .. "|37|thick-outline")
        else
          s:SetAnchor(BOTTOM, c, TOP, 0, 0)
          s:SetFont(font .. "|45|thick-outline")
        end

        s:SetColor(unpack(saved.stack.color))

        c.stacks = s
      end

      local l     = WM:CreateControl(key .. "_Label", c, CT_LABEL)
      local x, y  = JHSetTrackers.UI.GetSavedTimerPosition(key)
      l:SetAlpha(1)
      l:SetDrawLevel(5)
      l:SetAnchor(CENTER, c, 	CENTER, x, JHSetTrackers.UI.FormatTimerY(y))

      if set.id == 147462 or set.id == 193411 then -- pearls and esoteric
        l:SetColor(unpack(saved.colorDown))
        l:SetFont(font .. "|$(KB_40)|thick-outline")

        if saved.colorFrame then c.frame:SetColor(unpack(saved.colorDown)) end

        local n = WM:CreateControl(key .. "_Counter", c, CT_LABEL)
        n:SetAnchor(TOP, c, BOTTOM, 0, -5)
        n:SetAlpha(1)
        n:SetFont(font .. "|$(KB_30)|thick-outline")
        n:SetDrawLevel(5)
        n:SetHidden(false)
        n:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        local bg = WM:CreateControl(key .. "_BG", c, CT_BACKDROP)
        bg:SetDimensions(scaleBase, scaleBase)
        bg:SetAnchor(TOP, c, TOP, 0, 0)
        bg:SetCenterColor(0, 0, 0, 0.4)
        bg:SetEdgeColor(0, 0, 0, 1)
        bg:SetDrawLevel(1)

        local color = JHSetTrackers.Procs[key].powerType == POWERTYPE_STAMINA and saved.stam.barColorDown or saved.mag.barColorDown
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

        c.counter = n
        c.bg      = bg
        c.bar     = bar
        c.line    = t

      elseif set.id == 154737 then -- sul-xan

        local b = WM:CreateControl(key .. "_Bar", c, CT_STATUSBAR)
        b:SetAnchor(TOPLEFT,  c, BOTTOMLEFT,  0, 0)
        b:SetAnchor(TOPRIGHT, c, BOTTOMRIGHT, 0, 0)
        b:SetHeight(15)
        b:SetColor(unpack(JHSetTrackers.preferences.sets[key].colorUp))
	      b:SetTexture([[/esoui/art/miscellaneous/progressbar_genericfill.dds]])
	      b:SetTextureCoords(0, 1, 0, 0.625)
	      b:SetMinMax(0, 1)

        c.bar = b

        l:SetFont(font .. "|$(KB_48)|thick-outline")
        l:SetColor(unpack(JHSetTrackers.preferences.sets[key].colorUp))

      else
        l:SetFont(font .. "|$(KB_48)|thick-outline")
        l:SetColor(unpack(JHSetTrackers.preferences.sets[key].colorUp))
      end

      c.icon       = r
      c.label      = l
      c.isUpdating = false
      c.set        = set

      JHSetTrackers.Controls[key] = c
      SetPosition(key, saved.x, saved.y)

      if key == JHSetTrackers.spaulderName then
        JHSetTrackers.Controls[key].activation = nil
        SetActivationTexture(JHSetTrackers.Controls[key], saved)
      end

    else -- Reuse context
      -- if JHSetTrackers.inMenu or (not JHSetTrackers.HUDHidden and JHSetTrackers.inventoryHidden) then
        container:SetHidden(not JHSetTrackers.UI.showIcons)
      -- end
    end

    if key == JHSetTrackers.spaulderName then
      JHSetTrackers.UI.UpdateToggled(key, JHSetTrackers.preferences.spaulderActive)
    else

      if set.event == EVENT_POWER_UPDATE then
        if set.id == 147462 or set.id == 193411 then
          JHSetTrackers.UI.UpdateProcs(key)
        else
          current, max, effective = GetUnitPower("player", set.powerType)
          set.currentValue = (current / effective) * 100
          JHSetTrackers.UI.UpdatePower(key)
        end
      end
    end

    if set.stacks ~= nil then JHSetTrackers.Tracking.UpdateSetBuffInfo(key) end


    -- Disable display
  else
    if container ~= nil then container:SetHidden(true) end
  end
  JHSetTrackers:Trace(2, "Finished DrawUI()")
end

function JHSetTrackers.UI:SetCombatStateDisplay()
  -- JHSetTrackers:Trace(3, "Setting combat state display, in combat: <<1>>", tostring(JHSetTrackers.isInCombat))

  if JHSetTrackers.isInCombat or JHSetTrackers.preferences.showOutsideCombat and not JHSetTrackers.isDead then
    JHSetTrackers.UI.showIcons = JHSetTrackers.UI.ResolveScene()
  else
    JHSetTrackers.UI.showIcons = false
    -- JHSetTrackers.UI.ShowIcon(false)
  end
  JHSetTrackers.UI.ShowIcon(JHSetTrackers.UI.showIcons)
end

function JHSetTrackers.UI:ResetProcs()
		JHSetTrackers:Trace(2, "Resetting Procs")
		-- if table.getn(JHSetTrackers.Procs) <= 0 then
		-- 		EM:UnregisterForEvent(JHSetTrackers.name .. "_Power", EVENT_POWER_UPDATE)
		-- 		return
		-- end

		for k, v in pairs(JHSetTrackers.Procs) do
				if JHSetTrackers.Procs[k] then
						local t = JHSetTrackers.Procs[k].times
						JHSetTrackers.Procs[k].times = 0
						JHSetTrackers:Trace(2, "[<<1>>]: times = <<2>>. was <<3>>", k, JHSetTrackers.Procs[k].times, t)
						JHSetTrackers.Controls[k].counter:SetText("")
						JHSetTrackers.UI.UpdateProcs(k)
				end
		end
end

function JHSetTrackers.UI.PlaySound(sound)
    if sound.enabled then
        PlaySound(SOUNDS[sound.sound])
    end
end

function JHSetTrackers.UI.UpdateDDFStacks(stacks)
  local key = "Death Dealer's Fete"
  local c = JHSetTrackers.Controls[key] or WM:GetControlByName(key .. "_Container")
  if not c then return end
  stacks = tonumber(stacks) or 0
  if stacks <= 0 then
    c:SetHidden(true)
    if c.stacks then c.stacks:SetText("") end
    if c.label then c.label:SetText("") end
    return
  end
  c:SetHidden(false)
  if c.label then c.label:SetText("") end
  if c.stacks then
    -- Re-assert DDF presentation in case an old control survived a UI refresh.
    c.stacks:ClearAnchors()
    c.stacks:SetAnchor(CENTER, c, CENTER, 0, 0)
    c.stacks:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.stacks:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c.stacks:SetDimensions(64, 64)
    c.stacks:SetFont("$(BOLD_FONT)|37|thick-outline")
    c.stacks:SetText(tostring(stacks))
    local r,g,b
    if stacks <= 15 then
      local t = (stacks - 1) / 14
      r = 1
      g = 0.5 * t
      b = 0
    else
      local t = (stacks - 15) / 15
      r = 1 - t
      g = 0.5 + 0.5 * t
      b = 0
    end
    c.stacks:SetColor(r,g,b,1)
  end
end

function JHSetTrackers.UI.Update(setKey)
  local set = JHSetTrackers.Data.Sets[setKey]
  if set == nil then return end
  if set.event == EVENT_POWER_UPDATE or set.event == EVENT_EFFECT_CHANGED then return end

  -- Console safety: combat events can arrive before the tracker control or
  -- saved per-set options have been fully materialized.
  local c = JHSetTrackers.Controls[setKey]
  if c == nil and set.enabled then
    JHSetTrackers.UI.Draw(setKey)
    c = JHSetTrackers.Controls[setKey]
  end
  if c == nil or c.label == nil then return end

  local pref = JHSetTrackers.preferences
    and JHSetTrackers.preferences.sets
    and JHSetTrackers.preferences.sets[setKey]
  local colorUp = (pref and pref.colorUp) or {0, 1, 0}
  local colorDown = (pref and pref.colorDown) or {1, 0, 0}
  local onReady = pref and pref.sounds and pref.sounds.onReady

  local endTime = tonumber(set.endTime) or 0
  local timeOfProc = tonumber(set.timeOfProc) or 0
  local cooldown = tonumber(set.cooldownDurationMs) or 0
  local duration = tonumber(set.durationms) or 0
  local now = GetGameTimeMilliseconds()
  local bonusMs = 0

  if JHSetTrackers.hasJorvuld and JHSetTrackers.UI.JorvuldCheck(setKey) then
    bonusMs = duration * 0.4
  end

  local upTime = (endTime + bonusMs - now) / 1000
  local downTime = (timeOfProc + cooldown - now) / 1000

  if upTime <= 0 then
    if downTime <= 0 then
      if c.icon then c.icon:SetColor(1, 1, 1, 1) end
      EM:UnregisterForUpdate(JHSetTrackers.name .. setKey .. "Count")
      set.onCooldown = false
      c.label:SetText("")
      if onReady then JHSetTrackers.UI.PlaySound(onReady) end
      if set.ps5HideAfterCooldown or set.ps5HideAfterActive then
        set.ps5HideAfterCooldown = nil
        set.ps5HideAfterActive = nil
        if not set.enabled then c:SetHidden(true) end
      end
    else
      c.label:SetColor(unpack(colorDown))
      if c.icon then c.icon:SetColor(0.5, 0.5, 0.5, 1) end
      if downTime < 2 then c.label:SetText(string.format("%.1f", downTime))
      else c.label:SetText(string.format("%.0f", downTime)) end
    end
  else
    c.label:SetColor(unpack(colorUp))
    if c.icon then c.icon:SetColor(1, 1, 1, 1) end
    if upTime < 2 then c.label:SetText(string.format("%.1f", upTime))
    else c.label:SetText(string.format("%.0f", upTime)) end
  end
end

function JHSetTrackers.UI.UpdateEffect(setKey)

  local function OnSetInactive(key, control)
    EM:UnregisterForUpdate(JHSetTrackers.name .. key .. "Count")
    if control ~= nil then
      control.isUpdating = false
      control.label:SetText("")
      control.icon:SetColor(1, 1, 1, 1)
      JHSetTrackers.UI.PlaySound(JHSetTrackers.preferences.sets[key].sounds.onReady)
    end
  end

  local set   = JHSetTrackers.Data.Sets[setKey]
  local c     = WM:GetControlByName(setKey .. "_Container")

  local now         = time() / 1000
  local upTime      = (tonumber(set.endTime) or 0) - now
  local downTime    = (tonumber(set.cdEnd) or 0) - now
  local inactive    = (upTime < 0 and downTime < 0) and true or false

  -- if not set.enabled then
  --   if (upTime <= 0 and downTime <= 0) then
  --     EM:UnregisterForUpdate(JHSetTrackers.name .. setKey .. "Count")
  --     c.label:SetText("")
  --     if c.icon then c.icon:SetColor(1, 1, 1, 1) end
  --     if c.stacks then c.stacks:SetText("") end
  --     JHSetTrackers.Tracking.UpdateTrackingStateForEffect(setKey, false)
  --     return
  --   end
  -- end

  if (upTime > 0) then
    if c.icon then c.icon:SetColor(1, 1, 1, 1) end
    c.label:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorUp))
    if (upTime < 2)
    then c.label:SetText(string.format("%.1f", upTime))
    else c.label:SetText(string.format("%.0f", upTime)) end

  else

    if (downTime > 0) then
      c.label:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorDown))
      if c.icon then c.icon:SetColor(0.5, 0.5, 0.5, 1) end
      if (downTime < 2)
      then c.label:SetText(string.format("%.1f", downTime))
      else c.label:SetText(string.format("%.0f", downTime)) end
    else
      c.label:SetText("")
      if c.icon then c.icon:SetColor(1, 1, 1, 1) end
      if set.ps5HideAfterActive and not set.enabled then
        set.ps5HideAfterActive = nil
        set.ps5HideAfterCooldown = nil
        c:SetHidden(true)
        EM:UnregisterForUpdate(JHSetTrackers.name .. setKey .. "Count")
      end
    end
  end

  if c.stacks and set.stacks then
    if set.stacks > 0
    then c.stacks:SetText(set.stacks)
    else c.stacks:SetText("") end
  end
end

-- SetInsets(number left, number top, number right, number bottom)
-- /script local c=JHSetTrackers.Controls["Pearls of Ehlnofey"] c.bar:SetInsets(2.5, 2.5, 2.5, 2.5)

function JHSetTrackers.UI.UpdateProcs(setKey)
  local set    = JHSetTrackers.Procs[setKey]
  local c      = JHSetTrackers.Controls[setKey]
  local saved  = JHSetTrackers.preferences.sets[setKey]
  local max    = GetBarContraints(setKey)
  local h      = max * (set.current / 100)
  local color

  c.bar:SetHeight(h)

  if set.id == 147462 or set.id == 193411 then
    if saved.showProcs then
      local n = set.times > 0 and "x" ..  set.times or ""
      color = JHSetTrackers.PlayerPower.ult == 100 and saved.colorDown or saved.colorUp
      c.counter:SetText(n)
      c.counter:SetColor(unpack(color))
    else
      c.counter:SetText("")
    end

    if saved.showPercent then
      local m = set.current <= 99 and string.format("%.0f", set.current) .. "%" or ""
      c.label:SetText(m)
    else
      c.label:SetText("")
    end

    color = set.powerType == POWERTYPE_STAMINA and saved.stam.dividerColor or saved.mag.dividerColor
    c.line:SetCenterColor(unpack(color))
    c.line:SetEdgeColor(unpack(color))

    if set.current < JHSetTrackers.Data.Sets[setKey].threshold then
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
  else
    if set.current < JHSetTrackers.Data.Sets[setKey].threshold then
      if saved.colorFrame then
        color = set.powerType == POWERTYPE_STAMINA and saved.stam.frameColorUp or saved.mag.frameColorUp
        c.frame:SetColor(unpack(color))
      else
        c.frame:SetColor(1, 1, 1, 1)
      end

      color = set.powerType == POWERTYPE_STAMINA and saved.stam.barColorUp or saved.mag.barColorUp
      c.bar:SetCenterColor(unpack(color))
    else
      if saved.colorFrame then
        color = set.powerType == POWERTYPE_STAMINA and saved.stam.frameColorDown or saved.mag.frameColorDown
        c.frame:SetColor(unpack(color))
      else
        c.frame:SetColor(1, 1, 1, 1)
      end

      color = set.powerType == POWERTYPE_STAMINA and saved.stam.barColorDown or saved.mag.barColorDown
      c.bar:SetCenterColor(unpack(color))
    end
  end
end

function JHSetTrackers.UI.UpdateToggled(setKey, active)
  local set    = JHSetTrackers.Data.Sets[setKey]
  local c      = JHSetTrackers.Controls[setKey]
  local saved  = JHSetTrackers.preferences.sets[setKey]

  if active ~= nil then
    if set.active ~= active then
      if active == true
      then JHSetTrackers.UI.PlaySound(saved.sounds.onProc)
      else JHSetTrackers.UI.PlaySound(saved.sounds.onReady) end
    end
    set.active = active
  end

  if set.active == false then
    c.icon:SetColor(0.5, 0.5, 0.5, 1)
    c.activation:SetColor(unpack(saved.colorDown))
    -- c.label:SetColor(unpack(saved.colorDown))
    c.label:SetText("")
  else
    if c.icon then c.icon:SetColor(1, 1, 1, 1) end
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

  JHSetTrackers.preferences.spaulderActive = set.active
  -- local state = set.active and "Activated" or "Deactivated"
  -- JHSetTrackers:Trace(1, "Spaulder: <<1>>", state)
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

function JHSetTrackers.UI.UpdatePower(setKey)
  local set = JHSetTrackers.Data.Sets[setKey]
  local label = WM:GetControlByName(setKey .. "_Label")

  label:SetColor(unpack(JHSetTrackers.preferences.sets[setKey].colorUp))

  local bonus = 1

  if JHSetTrackers.hasJorvuld then
    bonus = JHSetTrackers.UI.JorvuldCheck(setKey) and 1.4 or 1
  end

  bonus = JHSetTrackers.UI.JorvuldCheck(setKey) and 1.4 or 1
  if set.scaling ~= nil then
      if type(set.scaling) == "table" then
        local a = set.scaling.scalar / set.scaling.start
        local b = set.scaling.start - set.currentValue
        local c = set.scaling.start - set.scaling.max
        if b >= c and not JHSetTrackers.isDead then
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

function JHSetTrackers.UI.ResolveScene()
  if not SCENE_MANAGER.currentScene then return false end
  local scene = SCENE_MANAGER.currentScene:GetName()

  local show = false

  -- if scene == "hud" or scene == "hudui" then
  if not JHSetTrackers.HUDHidden then
    -- JHSetTrackers.HUDHidden = false
    show = true
    -- d("1")
  elseif scene == "gameMenuInGame" and JHSetTrackers.Settings.window ~= nil then
    if not JHSetTrackers.Settings.window:IsHidden() then
      show = not JHSetTrackers.hideInmenu
      -- d("2")
    end
  else
    JHSetTrackers.HUDHidden = true

    if scene == "inventory" then
      JHSetTrackers.inventoryHidden = false
    end
  end
  -- d(tostring(show))
  return show
end

function JHSetTrackers.UI.ToggleHUD()
  local hud   = SCENE_MANAGER:GetScene("hud")
  local hudUI = SCENE_MANAGER:GetScene("hudui")
  local inv   = SCENE_MANAGER:GetScene("inventory")

  local function OnStateChanged(old, new)
    if new == SCENE_SHOWN then
      JHSetTrackers.HUDHidden    = false
      -- JHSetTrackers.UI.showIcons = true
    else
      JHSetTrackers.HUDHidden    = true
    end

    JHSetTrackers.UI:SetCombatStateDisplay()
  end

  -- Console does not expose every keyboard scene (for example inventory).
  -- Register only scenes that exist so initialization can continue into tracking.
  if hud then hud:RegisterCallback("StateChange", OnStateChanged) end
  if hudUI then hudUI:RegisterCallback("StateChange", OnStateChanged) end

  local function inventoryState(old, new)
    if new == SCENE_SHOWN then
      JHSetTrackers.inventoryHidden  = false
      -- JHSetTrackers.UI.showIcons     = false
    else
      JHSetTrackers.inventoryHidden  = true
    end
    JHSetTrackers.UI:SetCombatStateDisplay()
  end

  if inv then inv:RegisterCallback("StateChange", inventoryState) end

  JHSetTrackers.UI.showIcons = JHSetTrackers.UI.ResolveScene()

  JHSetTrackers:Trace(2, "Finished ToggleHUD()")
end

function JHSetTrackers.UI.ShowIcon(shouldShow)
  local skillLines = {}

  skillLines[1] = SKILLS_DATA_MANAGER:GetActiveClassSkillLine(1)
  skillLines[2] = SKILLS_DATA_MANAGER:GetActiveClassSkillLine(2)
  skillLines[3] = SKILLS_DATA_MANAGER:GetActiveClassSkillLine(3)

  local function hasRequiredSkillLine(skillLineId)
    return (
      (skillLines[1] and skillLines[1].id == skillLineId) or
      (skillLines[2] and skillLines[2].id == skillLineId) or
      (skillLines[3] and skillLines[3].id == skillLineId)
    )
  end

  for k, v in pairs(JHSetTrackers.Controls) do
    local c = JHSetTrackers.Controls[k]

    if c ~= nil then
      local set = JHSetTrackers.Data.Sets[k]

      if set ~= nil then
        if (shouldShow and set.enabled) then
          if set.procType == "passive" then
            -- Hide passives when the necessary skill line isn't unlocked
            if set.skillLine ~= nil then
              if hasRequiredSkillLine(set.skillLine) then
                c:SetHidden(false)
              else
                c:SetHidden(true)
              end
            else
              c:SetHidden(false)
            end
          else
            c:SetHidden(false)
          end
        else
          c:SetHidden(true)
        end
      end
    end
  end

end

function JHSetTrackers.UI.SlashCommand(command)
  -- Debug Options ----------------------------------------------------------
  if command == "debug 0" then
    d(JHSetTrackers.prefix .. "Setting debug level to 0 (Off)")
    JHSetTrackers.debugMode = 0
    JHSetTrackers.preferences.debugMode = 0
  elseif command == "debug 1" then
    d(JHSetTrackers.prefix .. "Setting debug level to 1 (Low)")
    JHSetTrackers.debugMode = 1
    JHSetTrackers.preferences.debugMode = 1
  elseif command == "debug 2" then
    d(JHSetTrackers.prefix .. "Setting debug level to 2 (Medium)")
    JHSetTrackers.debugMode = 2
    JHSetTrackers.preferences.debugMode = 2
  elseif command == "debug 3" then
    d(JHSetTrackers.prefix .. "Setting debug level to 3 (High)")
    JHSetTrackers.debugMode = 3
    JHSetTrackers.preferences.debugMode = 3

    -- Unfiltered Events
  elseif command == "all on" then
    d(JHSetTrackers.prefix .. "Registering unfiltered events, setting debug mode to 1")
    JHSetTrackers.debugMode = 1
    JHSetTrackers.preferences.debugMode = 1
    JHSetTrackers.Tracking.RegisterUnfiltered()
  elseif command == "all off" then
    d(JHSetTrackers.prefix .. "Unregistering unfiltered events, setting debug mode to 0")
    JHSetTrackers.Tracking.UnregisterUnfiltered()
    JHSetTrackers.debugMode = 0
    JHSetTrackers.preferences.debugMode = 0

  elseif command == "spaulder" then
    JHSetTrackers.spaulderTrack = not JHSetTrackers.spaulderTrack
    JHSetTrackers.Tracking.TrackSpaulder(JHSetTrackers.spaulderTrack)

  elseif command == "buffs" then
    JHSetTrackers.Tracking.GetActiveBuffs()

    -- Default ----------------------------------------------------------------
  else
    d(JHSetTrackers.prefix .. "Command not recognized!")
  end
end

-- Track skill line changes
EM:RegisterForEvent(JHSetTrackers.name .. "_SkillLines", EVENT_SKILLS_FULL_UPDATE, function() JHSetTrackers.UI.ShowIcon(JHSetTrackers.UI.showIcons) end)
