-- Rebar: bar controls, layout, theming and the per-frame update.

local R = Rebar
local U = R.util
local WM = WINDOW_MANAGER

local FILL_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericfill.dds"
local INSET = 2                    -- px between frame edge and fill
local REGEN_INTERVAL = 1.0         -- seconds between restore-rate samples
local ORIGINAL_HIDE_INTERVAL = 0.5 -- seconds between stock-bar hide checks
local IDLE_FADE_SPEED = 4

-- Draw levels within a bar, bottom to top.
local LVL = { frame = 1, bg = 2, trail = 3, fill = 4, shield = 5, gloss = 6, marker = 7, text = 8 }

---------------------------------------------------------------------------
-- Control factories
---------------------------------------------------------------------------
local function CreateStatusBar(name, parent, level)
  local bar = WM:CreateControl(name, parent, CT_STATUSBAR)
  bar:SetAnchor(TOPLEFT, parent, TOPLEFT, INSET, INSET)
  bar:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -INSET, -INSET)
  bar:SetTexture(FILL_TEXTURE)
  bar:SetMinMax(0, 1)
  bar:SetValue(1)
  bar:SetDrawLevel(level)
  return bar
end

-- Untextured texture control = solid tinted rectangle (works down to 1px wide).
local function CreateFlatRect(name, parent, level)
  local rect = WM:CreateControl(name, parent, CT_TEXTURE)
  rect:SetColor(1, 1, 1, 1)
  rect:SetDrawLevel(level)
  return rect
end

local function CreateLabel(name, parent, align)
  local label = WM:CreateControl(name, parent, CT_LABEL)
  label:SetHorizontalAlignment(align or TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetDrawLevel(LVL.text)
  return label
end

local function CreateBar(key, root)
  local base = "Rebar" .. R.RESOURCE_INFO[key].label
  local bar = { key = key }

  bar.panel = WM:CreateControl(base, root, CT_CONTROL)

  -- Frame: dark backing plate with a 1px edge that lights up when low.
  bar.frame = WM:CreateControl(base .. "Frame", bar.panel, CT_BACKDROP)
  bar.frame:SetEdgeTexture("", 1, 1, 1)
  bar.frame:SetDrawLevel(LVL.frame)

  bar.bg     = CreateStatusBar(base .. "Bg", bar.frame, LVL.bg)
  bar.trail  = CreateStatusBar(base .. "Trail", bar.frame, LVL.trail)
  bar.fill   = CreateStatusBar(base .. "Fill", bar.frame, LVL.fill)

  -- Shield: a strip along the bottom of the health bar.
  if key == "health" then
    bar.shield = WM:CreateControl(base .. "Shield", bar.frame, CT_STATUSBAR)
    bar.shield:SetTexture(FILL_TEXTURE)
    bar.shield:SetMinMax(0, 1)
    bar.shield:SetValue(0)
    bar.shield:SetDrawLevel(LVL.shield)
  end

  -- Gloss: soft highlight across the top half.
  bar.gloss = CreateFlatRect(base .. "Gloss", bar.frame, LVL.gloss)
  bar.gloss:SetAnchor(TOPLEFT, bar.frame, TOPLEFT, INSET, INSET)
  bar.gloss:SetAnchor(TOPRIGHT, bar.frame, TOPRIGHT, -INSET, INSET)
  bar.gloss:SetColor(1, 1, 1, 0.10)

  -- Threshold marker: thin tick at the low-resource line.
  bar.marker = CreateFlatRect(base .. "Marker", bar.frame, LVL.marker)
  bar.marker:SetWidth(1)
  bar.marker:SetColor(1, 1, 1, 0.35)

  bar.titleLabel   = CreateLabel(base .. "Title", bar.frame, TEXT_ALIGN_LEFT)
  bar.valueLabel   = CreateLabel(base .. "Value", bar.frame, TEXT_ALIGN_CENTER)
  bar.warningLabel = CreateLabel(base .. "Warn", bar.frame, TEXT_ALIGN_RIGHT)
  bar.regenLabel   = CreateLabel(base .. "Regen", bar.panel, TEXT_ALIGN_CENTER)

  bar.titleLabel:SetAnchor(LEFT, bar.frame, LEFT, 7, 0)
  bar.valueLabel:SetAnchor(CENTER, bar.frame, CENTER, 0, 0)
  bar.warningLabel:SetAnchor(RIGHT, bar.frame, RIGHT, -7, 0)
  bar.titleLabel:SetText(R.RESOURCE_INFO[key].title)
  bar.warningLabel:SetText("LOW")
  bar.warningLabel:SetColor(1.00, 0.32, 0.26, 1)

  return bar
end

local function CreateMoverOverlay(root)
  local overlay = WM:CreateControl("RebarMoverOverlay", root, CT_BACKDROP)
  overlay:SetAnchorFill(root)
  overlay:SetEdgeTexture("", 1, 1, 1)
  overlay:SetCenterColor(0.20, 0.55, 1.00, 0.12)
  overlay:SetEdgeColor(0.40, 0.75, 1.00, 0.85)
  overlay:SetDrawLevel(0)

  local hint = WM:CreateControl("RebarMoverHint", overlay, CT_LABEL)
  hint:SetAnchor(BOTTOM, overlay, TOP, 0, -4)
  hint:SetFont("$(BOLD_FONT)|14|soft-shadow-thick")
  hint:SetColor(0.55, 0.82, 1.00, 1)
  hint:SetText("REBAR  -  drag to move  -  /rebar lock")

  return overlay
end

function R.CreateUI()
  if R.ui then return end

  local root = WM:CreateTopLevelWindow("RebarRoot")
  root:SetClampedToScreen(true)
  root:SetDrawTier(DT_HIGH)
  root:SetDrawLayer(DL_OVERLAY)

  root:SetHandler("OnMoveStop", function(self)
    local cx, cy = self:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    R.sv.offsetX = U.Round(cx - gx)
    R.sv.offsetY = U.Round(cy - gy)
    R.Layout()
    if R.lamPanel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", R.lamPanel) end
  end)

  R.ui = {
    root = root,
    overlay = CreateMoverOverlay(root),
    bars = {},
    regen = { rates = {}, samples = {}, time = 0 },
    lastFrame = 0,
    nextHideCheck = 0,
    alpha = 1,
  }

  for _, key in ipairs(R.RESOURCES) do
    R.ui.bars[key] = CreateBar(key, root)
    R.ui.regen.rates[key] = 0
  end

  root:SetHandler("OnUpdate", R.OnFrame)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
function R.GetRegenHeight()
  if not R.sv.showRegen then return 0 end
  return U.Clamp(R.sv.fontSize - 2, 8, 48) + 3
end

function R.GetPanelHeight()
  return R.GetRegenHeight() + R.sv.barHeight
end

function R.Layout()
  local ui, sv = R.ui, R.sv
  if not ui then return end

  local width, height = sv.barWidth, sv.barHeight
  local regenH = R.GetRegenHeight()
  local panelH = regenH + height
  local innerH = math.max(1, height - INSET * 2)

  -- Root is sized to the bounding box of all (scaled) bars plus padding.
  local halfW, halfH = 0, 0
  for _, key in ipairs(R.RESOURCES) do
    local scale = sv[key .. "Scale"] or 1
    halfW = math.max(halfW, math.abs(sv[key .. "OffsetX"]) + width * scale / 2)
    halfH = math.max(halfH, math.abs(sv[key .. "OffsetY"]) + panelH * scale / 2)
  end
  local pad = 10
  ui.root:SetDimensions(math.ceil(halfW * 2 + pad * 2), math.ceil(halfH * 2 + pad * 2))
  ui.root:ClearAnchors()
  ui.root:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX, sv.offsetY)

  for _, key in ipairs(R.RESOURCES) do
    local bar = ui.bars[key]

    bar.panel:ClearAnchors()
    bar.panel:SetAnchor(CENTER, ui.root, CENTER, sv[key .. "OffsetX"], sv[key .. "OffsetY"])
    bar.panel:SetDimensions(width, panelH)

    bar.frame:ClearAnchors()
    bar.frame:SetAnchor(BOTTOMLEFT, bar.panel, BOTTOMLEFT, 0, 0)
    bar.frame:SetDimensions(width, height)

    bar.gloss:SetHeight(math.max(2, math.floor(innerH * 0.45)))
    bar.marker:SetHeight(innerH)

    if bar.shield then
      local shieldH = math.max(2, math.floor(innerH * 0.4))
      bar.shield:ClearAnchors()
      bar.shield:SetAnchor(BOTTOMLEFT, bar.frame, BOTTOMLEFT, INSET, -INSET)
      bar.shield:SetAnchor(BOTTOMRIGHT, bar.frame, BOTTOMRIGHT, -INSET, -INSET)
      bar.shield:SetHeight(shieldH)
    end

    bar.regenAnchorY = 0
    bar.regenLabel:ClearAnchors()
    bar.regenLabel:SetAnchor(BOTTOM, bar.frame, TOP, 0, -1)
  end
end

---------------------------------------------------------------------------
-- Theme (runs on settings changes, not every frame)
---------------------------------------------------------------------------
local function Mix(a, b, t) return a + (b - a) * t end

function R.ApplyTheme(key)
  local sv, bar = R.sv, R.ui.bars[key]
  local r, g, b = R.GetColor(key)

  bar.panel:SetScale(sv[key .. "Scale"] or 1)
  bar.panel:SetAlpha(sv[key .. "Alpha"] or 1)

  bar.frame:SetCenterColor(0.02, 0.02, 0.02, sv.backgroundAlpha)
  bar.frame:SetEdgeColor(0, 0, 0, U.Clamp(sv.backgroundAlpha + 0.1, 0, 1))

  bar.bg:SetColor(r * 0.16, g * 0.16, b * 0.16, U.Clamp(sv.backgroundAlpha, 0, 0.9))

  bar.fill:SetColor(r, g, b, 1)
  bar.fill:SetGradientColors(r * 0.62, g * 0.62, b * 0.62, 1, r, g, b, 1)

  -- Damage trail: a lighter tint of the bar color that lags behind losses.
  local tr, tg, tb = Mix(r, 1, 0.45), Mix(g, 1, 0.45), Mix(b, 1, 0.45)
  bar.trail:SetColor(tr, tg, tb, 0.75)
  bar.trail:SetGradientColors(tr * 0.8, tg * 0.8, tb * 0.8, 0.75, tr, tg, tb, 0.75)
  bar.trail:SetHidden(not (sv.animateBars and sv.damageTrail))

  if bar.shield then
    local sr, sg, sb = sv.shieldColorR, sv.shieldColorG, sv.shieldColorB
    bar.shield:SetColor(sr, sg, sb, 0.85)
    bar.shield:SetGradientColors(sr * 0.75, sg * 0.75, sb * 0.75, 0.85, sr, sg, sb, 0.85)
  end

  bar.gloss:SetHidden(not sv.showGloss)

  -- Mirroring (magicka drains toward the center in a pyramid layout).
  local reverse = key == "magicka" and sv.mirrorMagicka
  local align = reverse and BAR_ALIGNMENT_REVERSE or BAR_ALIGNMENT_NORMAL
  for _, s in ipairs({ bar.bg, bar.trail, bar.fill, bar.shield }) do
    if s and s.SetBarAlignment then s:SetBarAlignment(align) end
  end

  local innerW = sv.barWidth - INSET * 2
  local markerX = U.Round(innerW * sv.lowResourceThreshold)
  bar.marker:ClearAnchors()
  if reverse then
    bar.marker:SetAnchor(RIGHT, bar.frame, RIGHT, -INSET - markerX, 0)
  else
    bar.marker:SetAnchor(LEFT, bar.frame, LEFT, INSET + markerX, 0)
  end
  bar.marker:SetHidden(not sv.showThresholdMarker)

  local size = sv.fontSize
  local small = U.Clamp(size - 2, 8, 48)
  bar.valueLabel:SetFont(U.Font(size))
  bar.titleLabel:SetFont(U.Font(small))
  bar.warningLabel:SetFont(U.Font(small))
  bar.regenLabel:SetFont(U.Font(small))

  bar.valueLabel:SetColor(1, 1, 1, 1)
  bar.titleLabel:SetColor(1, 1, 1, 0.70)
  bar.titleLabel:SetHidden(not sv.showBarLabels)
  bar.regenLabel:SetHidden(not sv.showRegen)

  -- Force per-frame state to re-evaluate.
  bar.lowState = nil
  bar.valueText = nil
  bar.regenText = nil
end

function R.UpdateMoverState()
  if not R.ui then return end
  local unlocked = R.sv.movable
  R.ui.root:SetMovable(unlocked)
  R.ui.root:SetMouseEnabled(unlocked)
  R.ui.overlay:SetHidden(not unlocked)
end

-- Re-apply everything after a settings change.
function R.Refresh()
  if not R.ui then return end
  R.Layout()
  for _, key in ipairs(R.RESOURCES) do R.ApplyTheme(key) end
  R.UpdateMoverState()
  R.RefreshVisibility()
end

function R.ResetAnimationState()
  if not R.ui then return end
  R.ui.regen.time = 0
  R.ui.lastFrame = 0
  for _, key in ipairs(R.RESOURCES) do
    local bar = R.ui.bars[key]
    bar.displayValue, bar.trailValue = nil, nil
    bar.regenAnimStart, bar.regenAnimDir = 0, 0
  end
end

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local resources = {}
for _, key in ipairs(R.RESOURCES) do resources[key] = { current = 0, max = 0, percent = 0 } end

local function ReadResources()
  for _, key in ipairs(R.RESOURCES) do
    local cur, max = GetUnitPower("player", R.RESOURCE_INFO[key].power)
    local res = resources[key]
    res.current = cur or 0
    res.max = max or 0
    res.percent = res.max > 0 and U.Clamp(res.current / res.max, 0, 1) or 0
  end
  return resources
end

local function SampleRegen(res, now)
  local regen = R.ui.regen
  local elapsed = now - regen.time

  -- First sample, or we were hidden for a while: start a fresh window.
  if regen.time == 0 or elapsed > REGEN_INTERVAL * 3 then
    regen.time = now
    for _, key in ipairs(R.RESOURCES) do
      regen.samples[key] = res[key].current
      regen.rates[key] = 0
    end
    return
  end

  if elapsed < REGEN_INTERVAL then return end

  for _, key in ipairs(R.RESOURCES) do
    local delta = res[key].current - regen.samples[key]
    regen.rates[key] = delta
    regen.samples[key] = res[key].current
    if delta ~= 0 then
      local bar = R.ui.bars[key]
      bar.regenAnimStart = now
      bar.regenAnimDir = delta > 0 and 1 or -1
    end
  end
  regen.time = now
end

local function AnimateBar(bar, res, dt)
  local sv = R.sv
  local max = res.max > 0 and res.max or 1
  local target = U.Clamp(res.current, 0, max)

  if bar.displayValue == nil then bar.displayValue = target end
  if bar.trailValue == nil then bar.trailValue = target end

  if sv.animateBars then
    local losing = target < bar.displayValue
    local speed = losing and sv.animationLossSpeed or sv.animationGainSpeed
    if losing then
      -- Big hits catch up faster so the bar never feels laggy.
      speed = speed + U.Clamp((bar.displayValue - target) / max, 0, 1) * 6
    end
    bar.displayValue = U.Smooth(bar.displayValue, target, speed, dt)

    if sv.damageTrail and target < bar.trailValue then
      bar.trailValue = U.Smooth(bar.trailValue, target, sv.damageTrailSpeed, dt)
    else
      bar.trailValue = target
    end
  else
    bar.displayValue = target
    bar.trailValue = target
  end

  local shown = U.Clamp(bar.displayValue, 0, max)
  local trail = math.max(U.Clamp(bar.trailValue, 0, max), shown)

  if bar.max ~= max then
    bar.max = max
    bar.bg:SetMinMax(0, max); bar.bg:SetValue(max)
    bar.trail:SetMinMax(0, max)
    bar.fill:SetMinMax(0, max)
    if bar.shield then bar.shield:SetMinMax(0, max) end
  end
  bar.trail:SetValue(trail)
  bar.fill:SetValue(shown)

  if bar.shield then
    local showShield = sv.showShield and R.shield > 0
    bar.shield:SetHidden(not showShield)
    if showShield then bar.shield:SetValue(math.min(R.shield, max)) end
  end
end

local function UpdateLowState(key, bar, res, now)
  local sv = R.sv
  local low = res.max > 0 and res.percent <= sv.lowResourceThreshold

  if low then
    local r, g, b = R.GetColor(key)
    local glow = 1
    if sv.lowResourcePulse then
      glow = 0.35 + 0.65 * (math.sin(now * 7) + 1) * 0.5
    end
    bar.frame:SetEdgeColor(U.Clamp(r * 1.2, 0, 1), U.Clamp(g * 1.2, 0, 1), U.Clamp(b * 1.2, 0, 1), glow)
    bar.warningLabel:SetAlpha(0.55 + 0.45 * glow)
  elseif bar.lowState ~= false then
    bar.frame:SetEdgeColor(0, 0, 0, U.Clamp(sv.backgroundAlpha + 0.1, 0, 1))
  end

  if bar.lowState ~= low then
    bar.lowState = low
    bar.warningLabel:SetHidden(not low)
  end
end

local function FormatValue(key, res)
  local sv = R.sv
  local fmt = sv.textFormat
  if fmt == "none" then return "" end

  local abbr = sv.abbreviateNumbers
  local cur, max = U.FormatNumber(res.current, abbr), U.FormatNumber(res.max, abbr)
  local pct = string.format("%d%%", U.Round(res.percent * 100))

  local text
  if fmt == "cur" then text = cur
  elseif fmt == "pct" then text = pct
  elseif fmt == "cur_pct" then text = cur .. "  " .. pct
  elseif fmt == "cur_max_pct" then text = cur .. " / " .. max .. "  " .. pct
  else text = cur .. " / " .. max
  end

  if key == "health" and sv.showShield and R.shield > 0 then
    local hex = U.ColorHex(sv.shieldColorR, sv.shieldColorG, sv.shieldColorB)
    text = string.format("%s  |c%s[%s]|r", text, hex, U.FormatNumber(R.shield, abbr))
  end
  return text
end

local function UpdateValueText(key, bar, res)
  local text = FormatValue(key, res)
  if bar.valueText ~= text then
    bar.valueText = text
    bar.valueLabel:SetText(text)
  end
end

local function UpdateRegenLabel(key, bar, now)
  local sv = R.sv
  if not sv.showRegen then return end

  local rate = R.ui.regen.rates[key] or 0
  local text = U.FormatSigned(rate, sv.abbreviateNumbers) .. "/s"
  if bar.regenText ~= text then
    bar.regenText = text
    bar.regenLabel:SetText(text)
  end

  local hidden = sv.hideZeroRegen and rate == 0
  bar.regenLabel:SetHidden(hidden)
  if hidden then return end

  local r, g, b, a, scale, yOffset = 0.85, 0.85, 0.85, 0.80, 1, 0
  local dir = bar.regenAnimDir or 0
  local duration = U.Clamp(sv.restoreAnimDuration, 0.10, 2.00)
  local elapsed = now - (bar.regenAnimStart or 0)

  if sv.animateRestoreText and dir ~= 0 and elapsed >= 0 and elapsed < duration then
    local pulse = math.sin((elapsed / duration) * math.pi)
    scale = 1 + pulse * U.Clamp(sv.restoreAnimScale, 0, 0.8)
    yOffset = -U.Round(4 * pulse)
    a = U.Clamp(a + 0.2 * pulse, 0, 1)
    if dir > 0 then
      local cr, cg, cb = R.GetColor(key)
      r, g, b = U.Clamp(Mix(cr, 1, 0.35), 0, 1), U.Clamp(Mix(cg, 1, 0.35), 0, 1), U.Clamp(Mix(cb, 1, 0.35), 0, 1)
    else
      r, g, b = 1.00, 0.42, 0.36
    end
  end

  if bar.regenAnchorY ~= yOffset then
    bar.regenAnchorY = yOffset
    bar.regenLabel:ClearAnchors()
    bar.regenLabel:SetAnchor(BOTTOM, bar.frame, TOP, 0, yOffset - 1)
  end
  bar.regenLabel:SetScale(scale)
  bar.regenLabel:SetColor(r, g, b, a)
end

local function UpdateIdleFade(allFull, dt)
  local sv, ui = R.sv, R.ui
  local idle = sv.fadeWhenIdle and allFull and R.shield <= 0
    and not IsUnitInCombat("player") and not sv.movable and not R.previewing
  local target = idle and sv.idleAlpha or 1
  if ui.alpha ~= target then
    ui.alpha = U.Smooth(ui.alpha, target, IDLE_FADE_SPEED, dt)
    if math.abs(ui.alpha - target) < 0.01 then ui.alpha = target end
    ui.root:SetAlpha(ui.alpha)
  end
end

function R.OnFrame()
  local ui = R.ui
  local now = GetFrameTimeSeconds()
  local dt = ui.lastFrame > 0 and U.Clamp(now - ui.lastFrame, 0, 0.25) or 0
  ui.lastFrame = now

  if now >= ui.nextHideCheck then
    ui.nextHideCheck = now + ORIGINAL_HIDE_INTERVAL
    R.HideOriginalBars()
  end

  local res = ReadResources()
  SampleRegen(res, now)

  local allFull = true
  for _, key in ipairs(R.RESOURCES) do
    local bar, r = ui.bars[key], res[key]
    AnimateBar(bar, r, dt)
    UpdateLowState(key, bar, r, now)
    UpdateValueText(key, bar, r)
    UpdateRegenLabel(key, bar, now)
    if r.percent < 0.999 then allFull = false end
  end

  UpdateIdleFade(allFull, dt)
end
