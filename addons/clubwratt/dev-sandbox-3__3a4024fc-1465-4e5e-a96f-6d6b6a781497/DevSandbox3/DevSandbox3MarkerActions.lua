-- DevSandbox3MarkerActions.lua: dots in the 3D world (the 0.8 renderer, known to work on console)
--
-- Every 100 ms while the HUD is up: judge the slots around the player, then draw
--   orange  dot 1.5 m above every empty harvestable slot in Cyrodiil      (war torte)
--   purple  dot 1.5 m above every empty enchanting slot anywhere           (psijic)
--   yellow  dot 1.5 m above every uncovered slot beyond the confirmed distance (unknown yet)
--   pale blue (translucent) instead of any of the above for a slot the player has been within checkedM of recently
--   cyan    dot above every known node when debugNodes is on (must sit on real nodes). Same size as the other dots,
--           1.5 m above the nearest known location's ground height (nodes carry no height), else player height.
-- CT_TEXTURE controls with a render space, billboarded, constant apparent size (optional far shrink). Each dot has a
-- black outline: a second texture 30 % larger drawn just behind it (one draw level lower).
-- No per-tick allocation: fixed pools of MAX controls are repositioned in place.
local Markers = {}

local Utils = DevSandbox3.MarkerUtils
local SlotActions = DevSandbox3.SlotActions

local MAX = 128
local TEXTURE = "DevSandbox3/textures/dot_plain.dds"
local DOT_HEIGHT_M = 1.5
local OUTLINE_SCALE = 1.3

Markers.pool = {}
Markers.outlines = {}
Markers.shown = 0
Markers.drawn = { empty = 0, unknown = 0, checked = 0 }   -- last tick, by state
local lastSummaryMs = 0
local SUMMARY_MS = 5000

local function S() return DevSandbox3.state.savedVars.settings end

local function EnsureControls()
    if Markers.tl then return end
    local tl = WINDOW_MANAGER:CreateTopLevelWindow(DevSandbox3.name .. "_MarkersTL")
    tl:SetDrawLayer(DL_BACKGROUND)
    tl:SetMouseEnabled(false)
    local probe = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_MarkersProbe", tl, CT_CONTROL)
    probe:Create3DRenderSpace()
    for i = 1, MAX do
        local m = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_Marker" .. i, tl, CT_TEXTURE)
        m:Create3DRenderSpace()
        m:SetTexture(TEXTURE)
        m:SetHidden(true)
        Markers.pool[i] = m
        local o = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_Outline" .. i, tl, CT_TEXTURE)
        o:Create3DRenderSpace()
        o:SetTexture(TEXTURE)
        o:SetHidden(true)
        Markers.outlines[i] = o
    end
    local fragment = ZO_HUDFadeSceneFragment:New(tl)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    Markers.tl, Markers.probe = tl, probe
end

local function HideFrom(i)
    local pool, outlines = Markers.pool, Markers.outlines
    for j = i, Markers.shown do pool[j]:SetHidden(true); outlines[j]:SetHidden(true) end
    if Markers.shown >= i then Markers.shown = i - 1 end
end

-- per-tick state (set in Update, read by Place)
local camX, camY, camZ, pitch, yaw, nextIndex, dotSizeM, farScale, farScaleM, outline

---Place the next pooled dot at HarvestMap-frame (x, z, h) with colour (r, g, b).
local function Place(x, z, h, r, g, b, a)
    if nextIndex > MAX then return end
    local mx, my, mz = WorldPositionToGuiRender3DPosition(x * 100, h * 100, z * 100)
    local dx, dy, dz = mx - camX, my - camY, mz - camZ
    local camDist = math.sqrt(dx * dx + dy * dy + dz * dz)
    local size = Utils.BillboardSize(dotSizeM, camDist) * Utils.DistanceScale(camDist, farScaleM, farScale)
    local level = -math.floor(camDist * 100)
    local m = Markers.pool[nextIndex]
    m:Set3DRenderSpaceOrigin(mx, my, mz)
    m:Set3DLocalDimensions(size, size)
    m:Set3DRenderSpaceOrientation(pitch, yaw, 0)
    m:SetColor(r, g, b, a)
    m:SetDrawLevel(level)
    m:SetHidden(false)
    local o = Markers.outlines[nextIndex]
    if outline then
        local osize = size * OUTLINE_SCALE
        o:Set3DRenderSpaceOrigin(mx, my, mz)
        o:Set3DLocalDimensions(osize, osize)
        o:Set3DRenderSpaceOrientation(pitch, yaw, 0)
        o:SetColor(0, 0, 0, a)
        o:SetDrawLevel(level - 1)
        o:SetHidden(false)
    else
        o:SetHidden(true)
    end
    nextIndex = nextIndex + 1
end

local function Update()
    if IsReticleHidden() then HideFrom(1) return end
    local s = S()
    local _, prx, pry, prz = GetUnitRawWorldPosition("player")
    local px, ph, pz = prx / 100, pry / 100, prz / 100
    SlotActions.Judge(px, pz)

    local probe = Markers.probe
    Set3DRenderSpaceToCurrentCamera(probe:GetName())
    camX, camY, camZ = probe:Get3DRenderSpaceOrigin()
    local fx, fy, fz = probe:Get3DRenderSpaceForward()
    pitch, yaw = Utils.BillboardEuler(fx, fy, fz)
    nextIndex = 1
    dotSizeM = s.dotSizeCm / 100
    farScale, farScaleM = s.farScalePct / 100, s.farScaleM
    outline = s.outline
    local wt, ps, un, ck = s.warTorteColor, s.psijicColor, s.unknownColor, s.checkedColor
    local showUnknown = s.markUnknown

    local nEmpty, nUnknown, nChecked = 0, 0, 0
    local inRange, empty, unknown = SlotActions.inRange, SlotActions.empty, SlotActions.unknown
    for i = 1, SlotActions.inRangeCount do
        local slot = inRange[i]
        local state = empty[slot] and "empty" or (showUnknown and unknown[slot] and "unknown") or nil
        if state then
            local kind = SlotActions.MarkerKind(slot)
            if kind then
                local h = slot.h + DOT_HEIGHT_M
                if SlotActions.IsChecked(slot) then Place(slot.x, slot.z, h, ck.r, ck.g, ck.b, ck.a); nChecked = nChecked + 1
                elseif state == "unknown" then Place(slot.x, slot.z, h, un.r, un.g, un.b, un.a); nUnknown = nUnknown + 1
                elseif kind == "psijic" then Place(slot.x, slot.z, h, ps.r, ps.g, ps.b, ps.a); nEmpty = nEmpty + 1
                else Place(slot.x, slot.z, h, wt.r, wt.g, wt.b, wt.a); nEmpty = nEmpty + 1 end
            end
        end
    end
    local drawn = Markers.drawn
    drawn.empty, drawn.unknown, drawn.checked = nEmpty, nUnknown, nChecked
    -- every 5 s: one summary line for the export (chat too when debug is on)
    local now = GetFrameTimeMilliseconds()
    if now - lastSummaryMs >= SUMMARY_MS then
        lastSummaryMs = now
        local D = DevSandbox3.Detection
        local far = 0
        for _, node in pairs(D.located) do
            local dx, dz = node.x - px, node.z - pz
            local d2 = dx * dx + dz * dz
            if d2 > far then far = d2 end
        end
        local nUnk = 0
        for _ in pairs(SlotActions.unknown) do nUnk = nUnk + 1 end
        DevSandbox3.LogUtils.Debug("state: pins %d located %d farthest %dm confirmed %dm | in range %d: drawn empty %d, unknown %d (of %d, shown=%s), checked %d",
            D.liveCount, D.locatedCount, math.floor(math.sqrt(far) + 0.5), math.floor(SlotActions.confirmedM + 0.5),
            SlotActions.inRangeCount, nEmpty, nUnknown, nUnk, tostring(showUnknown), nChecked)
    end
    if s.debugNodes then
        local D = DevSandbox3.Detection
        for _, node in pairs(D.located) do Place(node.x, node.z, SlotActions.GroundHeight(node.x, node.z, ph) + DOT_HEIGHT_M, 0.0, 1.0, 1.0, 0.9) end
        for node in pairs(D.lingering) do Place(node.x, node.z, SlotActions.GroundHeight(node.x, node.z, ph) + DOT_HEIGHT_M, 0.0, 1.0, 1.0, 0.9) end
    end
    HideFrom(nextIndex)
    Markers.shown = nextIndex - 1
end

function Markers.Initialize()
    EnsureControls()
    EVENT_MANAGER:RegisterForUpdate(DevSandbox3.name .. "_Markers", 100, Update)
end

DevSandbox3.Markers = Markers
