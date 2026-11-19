-- 1vX Helper - On-screen blips
--  * World blips: a colored marker floating over each pin's real location in the 3D
--    world (visible through walls by default), sized to stay readable at range.
--  * Compass pins: the same pins drawn on the game's compass bar.
--
-- CPU notes:
--  * Pins for the current zone are cached as flat arrays (rebuilt only when pins change
--    or you change zone).
--  * The fast loop only runs while you're on the HUD, at least one of the two features
--    is on and the zone has pins of a shown type. Otherwise a 1s watcher is all that runs.
--  * Controls come from fixed pools; size/color are only re-set when they change.
local addon = OneVXHelper
local BL = {}
addon.Blips = BL

local WM = WINDOW_MANAGER
local NS_FAST, NS_WATCH = "OneVXHelper_BlipsFast", "OneVXHelper_BlipsWatch"
local TEXTURE = "/esoui/art/mappins/ui_worldmap_pin_customdestination.dds"
local PI, TWO_PI = math.pi, 2 * math.pi
local MAX_BLIPS, MAX_COMPASS = 16, 16
local HEIGHT_OFFSET_CM = 250   -- float the blip ~2.5m above where the pin was dropped
local MIN_DIST_CM = 200        -- hide the world blip when you're standing on it

local function S()  return addon.sv.blips end
local function CP() return addon.sv.compass end

-- zone cache -------------------------------------------------------------------
local cacheZone, cacheRev = nil, -1
local cX, cY, cZ, cType = {}, {}, {}, {}
local cCount = 0

local function RebuildCache(zoneId)
    local s = S()
    cCount = 0
    addon.Pins.ForEach(function(e)
        if e.zoneId == zoneId and e.wx and s[e.type] then
            cCount = cCount + 1
            cX[cCount], cY[cCount], cZ[cCount], cType[cCount] = e.wx, e.wy or 0, e.wz, e.type
        end
    end)
    cacheZone, cacheRev = zoneId, addon.Pins.revision
end

local function EnsureCache()
    local zoneId, px, py, pz = addon.Pins.GetPlayerWorldPos()
    if zoneId ~= cacheZone or cacheRev ~= addon.Pins.revision then RebuildCache(zoneId) end
    return px, py, pz
end

-- controls ---------------------------------------------------------------------
local root, blips = nil, {}
local compassLayer, compassIcons = nil, {}
local worldSupported = false
local fastRate = nil

local function TypeColor(t)
    return addon.Pins.TYPES[t].color:UnpackRGBA()
end

local function CreateWorld()
    worldSupported = (WorldPositionToGuiRender3DPosition ~= nil)
    if not worldSupported then return end
    root = WM:CreateTopLevelWindow("OneVXHelper_BlipRoot")
    root:SetDrawLayer(DL_BACKGROUND)
    root:SetDrawTier(DT_LOW)
    root:Create3DRenderSpace()
    root:SetHidden(true)
    for i = 1, MAX_BLIPS do
        local ctrl = WM:CreateControl("OneVXHelper_Blip" .. i, root, CT_CONTROL)
        ctrl:Create3DRenderSpace()
        local tex = WM:CreateControl("OneVXHelper_BlipTex" .. i, ctrl, CT_TEXTURE)
        tex:Create3DRenderSpace()
        tex:SetTexture(TEXTURE)
        tex:Set3DRenderSpaceOrigin(0, 0, 0)
        ctrl:SetHidden(true)
        blips[i] = { ctrl = ctrl, tex = tex, size = nil, type = nil, depth = nil }
    end
end

local function CreateCompass()
    local frame = ZO_CompassFrame or ZO_Compass
    if not frame then return end
    compassLayer = WM:CreateControl("OneVXHelper_CompassLayer", frame, CT_CONTROL)
    compassLayer:SetAnchorFill(frame)
    for i = 1, MAX_COMPASS do
        local tex = WM:CreateControl("OneVXHelper_CompassPin" .. i, compassLayer, CT_TEXTURE)
        tex:SetTexture(TEXTURE)
        tex:SetDrawLevel(5)
        tex:SetHidden(true)
        compassIcons[i] = { tex = tex, size = nil, type = nil }
    end
end

local function HideWorld(from)
    for i = from or 1, MAX_BLIPS do
        local b = blips[i]
        if b and not b.hidden then b.ctrl:SetHidden(true); b.hidden = true end
    end
end

local function HideCompass(from)
    for i = from or 1, MAX_COMPASS do
        local c = compassIcons[i]
        if c and not c.hidden then c.tex:SetHidden(true); c.hidden = true end
    end
end

-- camera orientation for billboarding ------------------------------------------
local function CameraAngles()
    if GetCameraForward then
        local fx, fy, fz = GetCameraForward(SPACE_WORLD)
        return math.atan2(fy, math.sqrt(fx * fx + fz * fz)), math.atan2(fx, fz) - PI
    end
    return 0, GetPlayerCameraHeading()
end

-- per-frame update --------------------------------------------------------------
local function UpdateWorld(px, py, pz)
    local s = S()
    local maxD2 = (s.maxRange * 100) ^ 2
    local minD2 = MIN_DIST_CM * MIN_DIST_CM
    local pitch, yaw = CameraAngles()
    local depth = not s.throughWalls
    local n = 0
    for i = 1, cCount do
        if n >= MAX_BLIPS then break end
        local dx, dz = cX[i] - px, cZ[i] - pz
        local d2 = dx * dx + dz * dz
        if d2 <= maxD2 and d2 >= minD2 then
            n = n + 1
            local b = blips[n]
            b.ctrl:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(cX[i], cY[i] + HEIGHT_OFFSET_CM, cZ[i]))
            b.ctrl:Set3DRenderSpaceOrientation(pitch, yaw, 0)

            local size = s.size
            if s.keepReadable then
                local distM = math.sqrt(d2) / 100
                size = size * math.max(1, distM / 25)
                size = zo_round(size * 10) / 10 -- avoid re-setting for tiny changes
            end
            if size ~= b.size then b.size = size; b.tex:Set3DLocalDimensions(size, size) end
            if cType[i] ~= b.type then b.type = cType[i]; b.tex:SetColor(TypeColor(cType[i])) end
            if depth ~= b.depth then b.depth = depth; b.tex:Set3DRenderSpaceUsesDepthBuffer(depth) end
            if b.hidden ~= false then b.ctrl:SetHidden(false); b.hidden = false end
        end
    end
    HideWorld(n + 1)
end

local function UpdateCompass(px, pz)
    local c = CP()
    local maxD2 = (c.maxRange * 100) ^ 2
    local half = math.rad(c.fov) / 2
    local halfW = compassLayer:GetWidth() / 2
    local facing = TWO_PI - GetPlayerCameraHeading()
    local flip = addon.sv.tracker.flipDirection
    local n = 0
    for i = 1, cCount do
        if n >= MAX_COMPASS then break end
        local dx, dz = cX[i] - px, cZ[i] - pz
        local d2 = dx * dx + dz * dz
        if d2 <= maxD2 then
            local rel = math.atan2(dx, -dz) - facing
            if flip then rel = -rel end
            rel = (rel + PI) % TWO_PI - PI
            if math.abs(rel) <= half then
                n = n + 1
                local ic = compassIcons[n]
                ic.tex:ClearAnchors()
                ic.tex:SetAnchor(CENTER, compassLayer, CENTER, rel / half * halfW, 0)
                if c.size ~= ic.size then ic.size = c.size; ic.tex:SetDimensions(c.size, c.size) end
                if cType[i] ~= ic.type then ic.type = cType[i]; ic.tex:SetColor(TypeColor(cType[i])) end
                -- closer pins are brighter
                ic.tex:SetAlpha(1 - 0.6 * math.sqrt(d2 / maxD2))
                if ic.hidden ~= false then ic.tex:SetHidden(false); ic.hidden = false end
            end
        end
    end
    HideCompass(n + 1)
end

local function FastTick()
    local px, py, pz = EnsureCache()
    local worldOn = worldSupported and S().enabled
    local compassOn = compassLayer and CP().enabled
    if worldOn then UpdateWorld(px, py, pz) end
    if compassOn then UpdateCompass(px, pz) end
end

-- run control -------------------------------------------------------------------
local function SetFast(rate)
    if fastRate == rate then return end
    if fastRate then EVENT_MANAGER:UnregisterForUpdate(NS_FAST) end
    fastRate = rate
    if rate then EVENT_MANAGER:RegisterForUpdate(NS_FAST, rate, FastTick) end
end

local function Evaluate()
    if not addon.sv then return end
    EnsureCache()
    local worldOn = worldSupported and S().enabled
    local compassOn = compassLayer ~= nil and CP().enabled
    local run = (worldOn or compassOn) and cCount > 0 and addon.UI.IsHudShowing()

    if root then root:SetHidden(not (run and worldOn)) end
    if not (run and worldOn) then HideWorld() end
    if not (run and compassOn) then HideCompass() end

    if run then
        SetFast(S().updateRate)
        FastTick()
    else
        SetFast(nil)
    end
end

function BL.Apply()
    cacheRev = -1  -- shown types may have changed
    for _, b in ipairs(blips) do b.size, b.depth, b.type = nil, nil, nil end
    for _, c in ipairs(compassIcons) do c.size, c.type = nil, nil end
    SetFast(nil)  -- pick up a changed refresh rate
    Evaluate()
end

function BL.Init()
    CreateWorld()
    CreateCompass()
    if not worldSupported and S().enabled then
        addon.Print("World blips need a newer game version (3D render API missing); compass pins still work.")
    end
    -- slow watcher: zone changes, newly placed pins, HUD visibility
    EVENT_MANAGER:RegisterForUpdate(NS_WATCH, 1000, Evaluate)
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", Evaluate)
    Evaluate()
end
