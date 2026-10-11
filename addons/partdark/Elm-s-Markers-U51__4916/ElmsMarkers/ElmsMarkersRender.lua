-- Renderer abstraction for ElmsMarkers.
--
-- Selects the 3D icon renderer depending on which supporting addon is installed:
--   1. Own (built-in, priority) - world space API renderer, no external libraries.
--      Each marker is a regular 2D control (background texture + text label) placed
--      into the 3D world via SetSpace(SPACE_WORLD): the ENGINE does the projection,
--      the position is set once at creation. A lightweight per-frame tick rotates
--      and culls camera-facing markers (1 native call each, only for visible ones;
--      the tick is unregistered entirely while no markers exist). Numbers (1..12)
--      and letters (A..Z) are rendered as real font text.
--   2. LibImplex - modern renderer based on the 3D render space API (optional).
--   3. OdySupportIcons - legacy screen-space projection renderer (optional).
--
-- Selection rules:
--   - "Own" / "Auto" : the built-in renderer (always available, priority choice).
--   - "LibImplex"    : used when installed, otherwise falls back to Own.
--   - "OdySupportIcons": used when installed, otherwise falls back to Own.
--
-- All marker code in the addon uses this module instead of calling OSI directly.

ElmsMarkers = ElmsMarkers or { }
ElmsMarkers.Render = { }
local Render = ElmsMarkers.Render

local ANIM_HANDLER = (ElmsMarkers.name or "ElmsMarkers") .. "RenderAnim"
local LIBIMPLEX_TICK_HANDLER = (ElmsMarkers.name or "ElmsMarkers") .. "RenderTick"
local OWN_ROTATION_HANDLER = (ElmsMarkers.name or "ElmsMarkers") .. "RenderRotation"
local OWN_CULL_HANDLER = (ElmsMarkers.name or "ElmsMarkers") .. "RenderCull"

-- Icons with a per-frame update callback (OSI-style contract: callback(icon) sets
-- icon.offset in meters, shifting the icon upward). Only used by the rendezvous arrow.
local animatedIcons = { }

local function IsAnimationRegistered(icon)
  return animatedIcons[icon] ~= nil
end

local function EnsureAnimationTicker()
  if not Render.animTickerRegistered then
    EVENT_MANAGER:RegisterForUpdate(ANIM_HANDLER, 0, function()
      for animIcon, callback in pairs(animatedIcons) do
        callback(animIcon) -- sets animIcon.offset
        animIcon.marker:SetPosition(animIcon.x, animIcon.y + (animIcon.offset or 0), animIcon.z)
      end
    end)
    Render.animTickerRegistered = true
  end
end

local function StopAnimation(icon)
  if animatedIcons[icon] then
    animatedIcons[icon] = nil
    if not next(animatedIcons) and Render.animTickerRegistered then
      EVENT_MANAGER:UnregisterForUpdate(ANIM_HANDLER)
      Render.animTickerRegistered = false
    end
  end
end

--------------------------------------------------------------------------------
-- Own world-space backend (no external libraries)
--------------------------------------------------------------------------------

local helperControl
local wsRoot
local wsFreeControls = { }
local wsFacingIcons = { }
local wsRenderTickRegistered = false
local wsNextId = 0

-- Forward declaration: EnsureRenderTick (below) registers this callback, but the
-- function body is defined further down. Without the forward declaration the
-- reference inside EnsureRenderTick resolves to a nil global, which makes
-- EVENT_MANAGER:RegisterForUpdate fail with
-- "Checking type on argument callback failed".
local OwnRenderTick

-- Cull markers farther than this from the player (raw world units; 1 m = 100 units).
local WS_CULL_DISTANCE_SQ = 20000 * 20000 -- 200 m

-- View-cone threshold: cos^2 of a 75deg half-angle. Markers deviating more than 75deg
-- (horizontally) from the view direction are off-screen for ANY in-game FOV setting,
-- so they can be hidden without rotating them. Squared math only - no sqrt per marker.
local WS_FOV_COS_SQ = 0.067

local function EnsureHelperControl()
  if helperControl then return end

  -- Hidden camera measurement helper: refreshed every frame via
  -- Set3DRenderSpaceToCurrentCamera to read camera position and orientation.
  helperControl = WINDOW_MANAGER:CreateTopLevelWindow("ElmsMarkers_3DRS")
  helperControl:Create3DRenderSpace()

  -- Root window that all world-space marker controls are parented to. World-space
  -- controls only render when their top-level window is attached to the active
  -- scene, so register it on the HUD scenes (same approach as M0RMarkers / Lib3D).
  wsRoot = WINDOW_MANAGER:CreateTopLevelWindow("ElmsMarkers_WSRoot")
  wsRoot:SetMouseEnabled(false)
  wsRoot:SetDrawLayer(DL_BACKGROUND)
  local fragment = ZO_HUDFadeSceneFragment:New(wsRoot)
  HUD_SCENE:AddFragment(fragment)
  HUD_UI_SCENE:AddFragment(fragment)
  GAME_MENU_SCENE:AddFragment(fragment)
end

local function EnsureRenderTick()
  if not wsRenderTickRegistered then
    EVENT_MANAGER:RegisterForUpdate(OWN_ROTATION_HANDLER, 0, OwnRenderTick)
    wsRenderTickRegistered = true
  end
end

local function CreateMarkerControl()
  wsNextId = wsNextId + 1
  local control = WINDOW_MANAGER:CreateControl("ElmsMarkers_WS_" .. wsNextId, wsRoot, CT_CONTROL)

  control:SetDimensions(100, 100) -- container units (container scale 1/100 -> 1x1 world unit)

  -- Background texture layer for regular image markers.
  local bg = WINDOW_MANAGER:CreateControl("ElmsMarkers_WS_" .. wsNextId .. "_BG", control, CT_TEXTURE)
  bg:SetAnchor(CENTER, control, CENTER)
  bg:SetDimensions(100, 100)
  bg:SetHidden(true)
  control.bg = bg

  -- Font text layer for number (1..12) and letter (A..Z) markers: real font text
  -- instead of a scaled image - the standard CT_LABEL API equivalent of LibImplex'
  -- 3D text (same technique as M0RMarkers' text layer).
  local label = WINDOW_MANAGER:CreateControl("ElmsMarkers_WS_" .. wsNextId .. "_Text", control, CT_LABEL)
  label:SetAnchor(CENTER, control, CENTER)
  label:SetDimensions(200, 100)
  label:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_20)|thick-outline")
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetScale(4) -- ~0.8 m glyph height inside the 1 m marker box
  label:SetHidden(true)
  control.label = label

  return control
end

local function AcquireMarkerControl()
  local control = table.remove(wsFreeControls) or CreateMarkerControl()
  -- Re-applying here: releasing a control clears anchors/space.
  control:SetHidden(false)
  control:SetSpace(SPACE_WORLD)
  control:SetAnchor(CENTER, GuiRoot, CENTER)
  control:SetScale(1 / 100) -- 1 m
  control:SetTransformNormalizedOriginPoint(0.5, 0.5)
  return control
end

local function ReleaseMarkerControl(control)
  control:SetHidden(true)
  wsFreeControls[#wsFreeControls + 1] = control
end

-- Per-frame updater: culls invisible markers and rotates visible ones to face the
-- camera. Runs once per frame; per-marker work only happens for markers that are
-- actually visible (no allocations, no draw level churn).
--
-- Billboard rotation follows the proven M0RMarkers approach: compute yaw/pitch from
-- GetCameraForward and apply SetTransformRotation to each marker. (Set3DRenderSpace*
-- calls only work on controls with their own 3D render space and would silently do
-- nothing on plain transform-space controls.)
OwnRenderTick = function()
  Set3DRenderSpaceToCurrentCamera("ElmsMarkers_3DRS")

  -- The helper's 3D render space is aligned to the current camera, so its origin is
  -- the camera position and its forward vector IS the camera forward in world space.
  -- Deriving yaw/pitch from it avoids a redundant GetCameraForward call every frame.
  local cX, cY, cZ = GuiRender3DPositionToWorldPosition(helperControl:Get3DRenderSpaceOrigin())
  local fX, fY, fZ = helperControl:Get3DRenderSpaceForward()

  local yaw = zo_atan2(fX, fZ) - math.pi
  local pitch = zo_atan2(fY, zo_sqrt(fX * fX + fZ * fZ))

  -- Cone culling is skipped when looking straight up/down (horizontal forward ~ 0).
  local fH2 = fX * fX + fZ * fZ
  local coneLimit = fH2 > 0.001 and WS_FOV_COS_SQ * fH2 or nil

  for i = 1, #wsFacingIcons do
    local icon = wsFacingIcons[i]
    local dx, dy, dz = icon.x - cX, icon.y - cY, icon.z - cZ
    local depth = fX * dx + fY * dy + fZ * dz
    local shouldHide = depth < 0 or (dx * dx + dy * dy + dz * dz) > WS_CULL_DISTANCE_SQ

    if not shouldHide and coneLimit then
      -- In front of the camera, but outside the view cone -> definitely off-screen.
      local dotH = dx * fX + dz * fZ
      local dH2 = dx * dx + dz * dz
      if dH2 > 1 and dotH * dotH < coneLimit * dH2 then
        shouldHide = true
      end
    end

    if shouldHide then
      if not icon.hidden then
        icon.hidden = true
        icon.control:SetHidden(true)
      end
    else
      if icon.hidden then
        icon.hidden = false
        icon.control:SetHidden(false)
      end
      icon.control:SetTransformRotation(pitch, yaw, 0)
    end
  end
end

-- Number (1..12) and letter (a..z) icon textures are rendered as real font text
-- instead of scaled images.
local function GetTextForTexture(texture)
  local name = texture:match("([%w]+)%.dds$")
  if not name then return nil end

  if name:match("^%d+$") and tonumber(name) <= 12 then
    return name -- numbers 1..12
  end
  if #name == 1 and name:match("%a") then
    return name:upper() -- letters a..z -> A..Z
  end
  return nil
end

local function CreateIconOwn(wX, wY, wZ, texture, size, color, weight, updateCallback)
  EnsureHelperControl()
  EnsureRenderTick()

  local control = AcquireMarkerControl()
  control:SetTransformScale(size)

  local r = color and color[1] or 1
  local g = color and color[2] or 1
  local b = color and color[3] or 1

  if GetTextForTexture(texture) then
    -- Numbers/letters: render as real font text (crisper than a scaled image).
    control.bg:SetHidden(true)
    control.label:SetHidden(false)
    control.label:SetText(GetTextForTexture(texture))
    control.label:SetColor(r, g, b, 1)
  else
    -- Regular image marker.
    control.label:SetHidden(true)
    control.bg:SetHidden(false)
    control.bg:SetTexture(texture)
    control.bg:SetColor(r, g, b, 1)
  end

  local rx, ry, rz = WorldPositionToGuiRender3DPosition(wX, wY, wZ)
  control:SetTransformOffset(rx, ry, rz)

  local icon = {
    x = wX, y = wY, z = wZ,
    control = control,
    hidden = false,
    -- Wrapper so the shared animation ticker works unchanged.
    marker = {
      SetPosition = function(_, x, y, z)
        local ox, oy, oz = WorldPositionToGuiRender3DPosition(x, y, z)
        control:SetTransformOffset(ox, oy, oz)
      end,
    },
    offset = 0,
  }
  wsFacingIcons[#wsFacingIcons + 1] = icon

  if updateCallback then
    animatedIcons[icon] = updateCallback
    EnsureAnimationTicker()
  end

  return icon
end

local function DiscardIconOwn(icon)
  if not icon then return end

  StopAnimation(icon)

  for i = #wsFacingIcons, 1, -1 do
    if wsFacingIcons[i] == icon then
      table.remove(wsFacingIcons, i)
      break
    end
  end

  -- Stop the per-frame tick entirely while the last marker is gone - zero
  -- constant per-frame overhead when the addon has nothing to render.
  if #wsFacingIcons == 0 and wsRenderTickRegistered then
    EVENT_MANAGER:UnregisterForUpdate(OWN_ROTATION_HANDLER)
    wsRenderTickRegistered = false
  end

  if icon.control then
    ReleaseMarkerControl(icon.control)
    icon.control = nil
  end
  icon.marker = nil
end

local function SetBackendOwn()
  Render.backend = "Own"
  EnsureHelperControl()
  Render.CreatePositionIcon = CreateIconOwn
  Render.DiscardPositionIcon = DiscardIconOwn
  Render.GetIconSize = function() return 1 end
end

--------------------------------------------------------------------------------
-- LibImplex backend (v2 object API: LibImplex.Objects)
--------------------------------------------------------------------------------

local renderIcons = { }
local renderTickRegistered = false
local helperControl

-- Cull markers farther than this from the camera (raw world units; 1 m = 100 units).
local LIBIMPLEX_CULL_DISTANCE_SQ = 20000 * 20000 -- 200 m

-- View-cone threshold: cos^2 of a 75deg half-angle (see WS_FOV_COS_SQ above).
local LIBIMPLEX_FOV_COS_SQ = 0.067

local function EnsureHelperControl()
  if helperControl then return end
  helperControl = WINDOW_MANAGER:CreateTopLevelWindow("ElmsMarkers_RenderCameraHelper")
  helperControl:Create3DRenderSpace()
end

-- Number (1..12) and letter (a..z) icon textures can be rendered as native LibImplex
-- 3D text (font glyphs) instead of scaled images - much crisper at any distance.
local function GetTextForTextureLibImplex(texture)
  local name = texture:match("([%w]+)%.dds$")
  if not name then return nil end

  if name:match("^%d+$") and tonumber(name) <= 12 then
    return name -- numbers 1..12
  end
  if #name == 1 and name:match("%a") then
    return name:upper() -- letters a..z -> A..Z
  end
  return nil
end

-- Custom glyph factory for LibImplex' text renderer: creates glyph objects in our own
-- object pool (so .control is accessible) as STATIC objects - LibImplex' update loop
-- does not process them; our single updater handles rotation and culling instead.
local function CreateTextGlyphObject()
  return Render.libImplexObjects._3DStatic()
end

-- Collects the glyph controls of a rendered text object.
local function CollectTextControls(textObject, controls)
  for r = 1, #textObject.rows do
    local objects = textObject.rows[r].objects
    for o = 1, #objects do
      if objects[o].control then
        controls[#controls + 1] = objects[o].control
      end
    end
  end
end

-- Per-frame updater: culls invisible markers and rotates visible ones to face the
-- camera. Runs once per frame; per-marker work only happens for markers that are
-- actually visible (no allocations, no draw level churn).
local function LibImplexRenderTick()
  Set3DRenderSpaceToCurrentCamera("ElmsMarkers_RenderCameraHelper")

  local cX, cY, cZ = GuiRender3DPositionToWorldPosition(helperControl:Get3DRenderSpaceOrigin())
  local fX, fY, fZ = helperControl:Get3DRenderSpaceForward()
  local rX, rY, rZ = helperControl:Get3DRenderSpaceRight()

  -- Cone culling is skipped when looking straight up/down (horizontal forward ~ 0).
  local fH2 = fX * fX + fZ * fZ
  local coneLimit = fH2 > 0.001 and LIBIMPLEX_FOV_COS_SQ * fH2 or nil

  for i = 1, #renderIcons do
    local icon = renderIcons[i]
    local dx, dy, dz = icon.px - cX, icon.py - cY, icon.pz - cZ
    local depth = fX * dx + fY * dy + fZ * dz
    local shouldHide = depth < 0 or (dx * dx + dy * dy + dz * dz) > LIBIMPLEX_CULL_DISTANCE_SQ

    if not shouldHide and coneLimit then
      -- In front of the camera, but outside the view cone -> definitely off-screen.
      local dotH = dx * fX + dz * fZ
      local dH2 = dx * dx + dz * dz
      if dH2 > 1 and dotH * dotH < coneLimit * dH2 then
        shouldHide = true
      end
    end

    if shouldHide then
      if not icon.hidden then
        icon.hidden = true
        local controls = icon.controls
        for c = 1, #controls do
          controls[c]:SetHidden(true)
        end
      end
    else
      local controls = icon.controls
      if icon.hidden then
        icon.hidden = false
        for c = 1, #controls do
          controls[c]:SetHidden(false)
        end
      end

      for c = 1, #controls do
        local control = controls[c]
        control:Set3DRenderSpaceForward(fX, fY, fZ)
        control:Set3DRenderSpaceRight(rX, rY, rZ)
      end
    end
  end
end

local function EnsureLibImplexTick()
  if not renderTickRegistered then
    EVENT_MANAGER:RegisterForUpdate(LIBIMPLEX_TICK_HANDLER, 0, LibImplexRenderTick)
    renderTickRegistered = true
  end
end

local function CreateIconLibImplex(wX, wY, wZ, texture, size, color, weight, updateCallback)
  EnsureHelperControl()
  EnsureLibImplexTick()

  local text = GetTextForTextureLibImplex(texture)
  local controls = { }
  local marker, textObject

  if text then
    -- Render numbers/letters as native LibImplex 3D text, centered on the position.
    textObject = LibImplex.Text(
      text,
      CENTER,
      LibImplex.Vector({ wX, wY, wZ }),
      { 0, 0, 0 }, -- orientation (no depth buffer, like the icons)
      size,        -- letter height in meters
      color or { 1, 1, 1 },
      nil,         -- maxWidth
      false,       -- outline
      CreateTextGlyphObject
    )
    textObject:Render()
    CollectTextControls(textObject, controls)
  else
    -- Static marker: LibImplex' update loop does not process it at all; our updater
    -- handles the camera-facing rotation and culling.
    marker = Render.libImplexObjects._3DStatic()
    marker:SetPosition(wX, wY, wZ)
    marker:SetTexture(texture)
    marker:SetDimensions(size, size)
    marker:SetColor(color and color[1] or 1, color and color[2] or 1, color and color[3] or 1, 1)
    controls[1] = marker.control
  end

  local icon = {
    x = wX, y = wY, z = wZ,
    px = wX, py = wY, pz = wZ,
    marker = marker,
    textObject = textObject,
    controls = controls,
    hidden = false,
    offset = 0,
  }
  renderIcons[#renderIcons + 1] = icon

  if updateCallback then
    animatedIcons[icon] = updateCallback
    EnsureAnimationTicker()
  end

  return icon
end

local function DiscardIconLibImplex(icon)
  if not icon then return end

  StopAnimation(icon)

  for i = #renderIcons, 1, -1 do
    if renderIcons[i] == icon then
      table.remove(renderIcons, i)
      break
    end
  end

  -- Stop the per-frame tick entirely while the last marker is gone.
  if #renderIcons == 0 and renderTickRegistered then
    EVENT_MANAGER:UnregisterForUpdate(LIBIMPLEX_TICK_HANDLER)
    renderTickRegistered = false
  end

  if icon.textObject then
    icon.textObject:Wipe()
    icon.textObject = nil
  elseif icon.marker then
    icon.marker:Delete()
    icon.marker = nil
  end
  icon.controls = nil
end

local function SetBackendLibImplex()
  Render.backend = "LibImplex"
  -- Own object pool: static objects created through it are NOT processed by
  -- LibImplex' per-frame update loop (zero library overhead for our markers).
  Render.libImplexObjects = LibImplex.Objects("ElmsMarkers")
  Render.CreatePositionIcon = CreateIconLibImplex
  Render.DiscardPositionIcon = DiscardIconLibImplex
  Render.GetIconSize = function() return 1 end

  -- LibImplex' "Show on HUD scene only" option (enabled by default) attaches its
  -- canvas to HUD_SCENE only, so markers disappear whenever the mouse cursor is
  -- shown (the game switches to HUD_UI_SCENE, e.g. during marker placement).
  -- Register our own fragment for that scene as well to keep markers visible.
  pcall(function()
    HUD_UI_SCENE:AddFragment(ZO_HUDFadeSceneFragment:New(IMP_LibImplex_Canvas))
    HUD_UI_SCENE:AddFragment(ZO_HUDFadeSceneFragment:New(IMP_LibImplex_SecondCanvas))
  end)
end

--------------------------------------------------------------------------------
-- OdySupportIcons backend (legacy)
--------------------------------------------------------------------------------

local function SetBackendOdySupportIcons()
  Render.backend = "OdySupportIcons"
  Render.CreatePositionIcon = function(wX, wY, wZ, texture, size, color, weight, updateCallback)
    return OSI.CreatePositionIcon(wX, wY, wZ, texture, size, color, weight, updateCallback)
  end
  Render.DiscardPositionIcon = function(icon) return OSI.DiscardPositionIcon(icon) end
  Render.GetIconSize = function() return OSI.GetIconSize() end
end

--------------------------------------------------------------------------------
-- Backend selection and public API
--------------------------------------------------------------------------------

-- Creates a 3D world icon. Returns an icon object exposing .x/.y/.z world coordinates
-- (compatible with the previous OdySupportIcons-based code paths).
-- Optional arguments color, weight and updateCallback mirror the OSI API; the callback
-- (if provided) is called every frame with the icon table and may set icon.offset.
function Render.CreatePositionIcon(wX, wY, wZ, texture, size, color, weight, updateCallback)
  return { x = wX, y = wY, z = wZ } -- replaced by Initialize()
end

function Render.DiscardPositionIcon(icon)
end

-- Global renderer scale factor (previously delegated to OSI.GetIconSize()).
function Render.GetIconSize()
  return 1
end

-- True when at least one renderer backend is available (the own built-in renderer
-- has no dependencies, so this is always true).
function Render.IsAvailable()
  return Render.backend ~= "none"
end

-- LibImplex is available when its v2 object API is loaded.
function Render.IsLibImplexAvailable()
  return LibImplex and LibImplex.Objects ~= nil
end

-- OdySupportIcons is available when its global API is loaded.
function Render.IsOdySupportIconsAvailable()
  return OSI and OSI.CreatePositionIcon ~= nil
end

-- The own built-in renderer has no dependencies - always available.
function Render.IsOwnAvailable()
  return true
end

-- Detects which renderer to use. Called from ElmsMarkers.OnAddOnLoaded, after the
-- optional dependency addons (LibImplex / OdySupportIcons) have been loaded.
function Render.Initialize()
  local preferred = ElmsMarkers.savedVars and ElmsMarkers.savedVars.preferredRenderer or "own"
  local canLibImplex = Render.IsLibImplexAvailable()
  local canOsi = Render.IsOdySupportIconsAvailable()

  if preferred == "libimplex" then
    if canLibImplex then
      SetBackendLibImplex()
    else
      SetBackendOwn()
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Preferred renderer LibImplex is not installed - using the built-in renderer.")
    end
  elseif preferred == "osi" then
    if canOsi then
      SetBackendOdySupportIcons()
    else
      SetBackendOwn()
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Preferred renderer OdySupportIcons is not installed - using the built-in renderer.")
    end
  else
    -- "own" and legacy "auto": the built-in renderer is the priority choice.
    SetBackendOwn()
  end

  CHAT_SYSTEM:AddMessage("[ElmsMarkers] Icon renderer: " .. Render.backend .. ".")
end
