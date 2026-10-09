-- =====================================================================
-- LibTeamShadows 1.3.3
-- Author: teamfky
-- Lightweight group communication + world markers for the Team Shadows
-- addons, built on LibGroupBroadcast by sirinsidiator:
--   https://www.esoui.com/downloads/info1337-LibGroupBroadcastformerlyLibGroupSocket.html
--
-- CREDITS
-- ---------------------------------------------------------------------
-- The world-marker concept was inspired by OdySupportIcons (OSI) by
-- Odylon, maintained by ExoY:
--   https://www.esoui.com/downloads/info2834-OdySupportIcons-GroupRoleIconsMore.html
-- As of 1.1.0 the rendering was rewritten from scratch on the game's
-- native 3D render space API (Create3DRenderSpace /
-- Set3DRenderSpaceOrigin / WorldPositionToGuiRender3DPosition), the way
-- ZOS positions its own in-world UI (housing editor gizmos, crown
-- crates). No OSI-derived code or assets remain in this library.
-- Thanks to ExoY for pointing out that the legacy screen-projection
-- approach should not be used in new addons anymore.
-- =====================================================================

LibTeamShadows = LibTeamShadows or {}

local LTS = LibTeamShadows

LTS.name = "LibTeamShadows"
LTS.version = "1.3.3"

-- =====================================================================
-- LibGroupBroadcast PROTOCOL IDS
-- ---------------------------------------------------------------------
-- Protocol ids and names MUST be globally unique across all addons and
-- are reserved on the ESOUI wiki, as required by LibGroupBroadcast:
--   https://wiki.esoui.com/LibGroupBroadcast_IDs
-- Reserved for the Team Shadows addons: range 440-449, handler name
-- "LibTeamShadows".
--   440 = "TeamShadowsPull"
--   441 = "TeamShadowsMarker"
--   442-449 = kept for future Team Shadows protocols.
-- The ids used before 1.1.0 (507 / 508) belonged to other addons and
-- broke them (reported by ExoY on ESOUI) -- never reuse them.
-- =====================================================================
LTS.PROTOCOL_ID_PULL = 440   -- "TeamShadowsPull" on the wiki
LTS.PROTOCOL_ID_MARKER = 441 -- "TeamShadowsMarker" on the wiki

LTS.handlers = LTS.handlers or {}
LTS.lastBroadcastMs = LTS.lastBroadcastMs or 0
LTS.minBroadcastIntervalMs = 900
LTS.worldIcons = LTS.worldIcons or {}
LTS.iconPool = LTS.iconPool or {}
LTS.lastMarkerPingMs = LTS.lastMarkerPingMs or 0
LTS.markerPingIntervalMs = 2000
LTS.defaultMarkerTexture = "TeamShadowsManager/icons/markers/square_red.dds"
LTS.directMarkerSharingEnabled = false
LTS.defaultMarkerSize = 64
LTS.defaultMarkerHeight = -6
LTS.defaultMarkerDurationMs = 8000
LTS.rendezvousOptIn = true
LTS.acceptLeadOnly = true
LTS.markerTextures = {
    [1] = "TeamShadowsManager/icons/markers/square_red.dds",
    [2] = "TeamShadowsManager/icons/markers/square_blue.dds",
    [3] = "TeamShadowsManager/icons/markers/square_yellow.dds",
    [4] = "TeamShadowsManager/icons/markers/square_green.dds",
    [5] = "TeamShadowsManager/icons/markers/square_orange.dds",
    [6] = "TeamShadowsManager/icons/markers/square_pink.dds",
    [7] = "TeamShadowsManager/icons/markers/marker_lightblue.dds",
    [8] = "TeamShadowsManager/icons/markers/square_red_MT.dds",
    [9] = "TeamShadowsManager/icons/markers/square_orange_OT.dds",
    [10] = "TeamShadowsManager/icons/markers/arrow.dds",
    [11] = "TeamShadowsManager/icons/markers/green_arrow.dds",
    [12] = "TeamShadowsManager/icons/custom/Eyr0nShadowIcon.dds",
    [13] = "TeamShadowsManager/icons/custom/roster/buche.dds",
    [14] = "TeamShadowsManager/icons/custom/roster/fish.dds",
    [15] = "TeamShadowsManager/icons/custom/roster/hyxtra02.dds",
    [16] = "TeamShadowsManager/icons/custom/roster/lexi.dds",
    [17] = "TeamShadowsManager/icons/custom/roster/og.dds",
    [18] = "TeamShadowsManager/icons/custom/roster/ogu.dds",
    [19] = "TeamShadowsManager/icons/custom/roster/ray_me.dds",
    [20] = "TeamShadowsManager/icons/custom/roster/ronce.dds",
    [21] = "TeamShadowsManager/icons/custom/roster/selegnar.dds",
    [22] = "TeamShadowsManager/icons/custom/roster/sla_anesh.dds",
    [23] = "TeamShadowsManager/icons/custom/roster/tim.dds",
}
LTS.markerTextureColors = {
    [1] = { 0.82, 0.11, 0.11 },
    [2] = { 0.1, 0.22, 0.95 },
    [3] = { 0.95, 0.78, 0.08 },
    [4] = { 0.05, 0.75, 0.15 },
    [5] = { 1, 0.5, 0.05 },
    [6] = { 1, 0.15, 0.75 },
    [7] = { 0.45, 0.85, 1 },
    [8] = { 0.82, 0.11, 0.11 },
    [9] = { 1, 0.5, 0.05 },
    [10] = { 1, 1, 1 },
    [11] = { 0.05, 0.75, 0.15 },
    [12] = { 1, 1, 1 },
    [13] = { 1, 1, 1 },
    [14] = { 1, 1, 1 },
    [15] = { 1, 1, 1 },
    [16] = { 1, 1, 1 },
    [17] = { 1, 1, 1 },
    [18] = { 1, 1, 1 },
    [19] = { 1, 1, 1 },
    [20] = { 1, 1, 1 },
    [21] = { 1, 1, 1 },
    [22] = { 1, 1, 1 },
    [23] = { 1, 1, 1 },
}
LTS.markerLabels = LTS.markerLabels or {
    [1] = "1",
    [2] = "2",
    [3] = "3",
    [4] = "4",
    [5] = "5",
    [6] = "6",
    [7] = "7",
    [8] = "8",
    [9] = "9",
    [10] = "10",
    [11] = "H1",
    [12] = "H2",
    [13] = "MT",
    [14] = "OT",
}

local EM = EVENT_MANAGER

local function NowMs()
    if GetFrameTimeMilliseconds then
        return GetFrameTimeMilliseconds()
    end
    return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or (GetTimeStamp() * 1000)
end

local function IsGrouped()
    return IsUnitGrouped and IsUnitGrouped("player")
end

-- ---------------------------------------------------------------------
-- Inter-addon dispatch (used by TeamShadowsManager & co)
-- ---------------------------------------------------------------------

function LTS.RegisterHandler(addonName, callback)
    if type(addonName) ~= "string" or addonName == "" or type(callback) ~= "function" then
        return false
    end

    LTS.handlers[addonName] = callback
    return true
end

function LTS.UnregisterHandler(addonName)
    if type(addonName) ~= "string" then return end
    LTS.handlers[addonName] = nil
end

local function DispatchGroupPull(seconds, senderTag)
    local handler = LTS.handlers.TeamShadowsManager
    if handler then
        handler("pull", { seconds = zo_clamp(tonumber(seconds) or 0, 0, 20) }, senderTag)
    end
end

-- ---------------------------------------------------------------------
-- LibGroupBroadcast protocols
-- All group communication goes through LibGroupBroadcast. The legacy
-- transports (chat channel messages and LibDataShare map pings) were
-- removed in 1.1.0: LibDataShare relies on a deprecated game API, is no
-- longer supported, and its map slots conflict with other addons.
-- ---------------------------------------------------------------------

local function OnMarkerData(unitTag, data)
    if not data then return end
    -- the sender already placed the marker locally
    if AreUnitsEqual and AreUnitsEqual(unitTag, "player") then return end
    if not LTS.directMarkerSharingEnabled or LTS.rendezvousOptIn == false then return end
    if LTS.acceptLeadOnly ~= false and IsUnitGroupLeader and not IsUnitGroupLeader(unitTag) then return end

    LTS.PlaceWorldMarker({
        zone = data.zone,
        x = data.x,
        y = data.y,
        z = data.z,
        textureId = data.textureId,
        labelId = data.labelId,
    }, {
        durationMs = (tonumber(data.durationS) or 8) * 1000,
        size = data.size or LTS.defaultMarkerSize,
        heightOffset = LTS.defaultMarkerHeight,
        labelId = data.labelId,
    })
end

local function EnsureGroupBroadcastProtocols()
    if not LibGroupBroadcast then return false end
    if not LibGroupBroadcast.RegisterHandler or not LibGroupBroadcast.CreateNumericField then return false end

    if not LTS.PROTOCOL_ID_PULL or not LTS.PROTOCOL_ID_MARKER then
        if not LTS.missingIdWarned then
            LTS.missingIdWarned = true
            d("|cff6600LibTeamShadows:|r LibGroupBroadcast protocol ids are not configured (see the header of LibTeamShadows.lua). Group broadcasting is disabled.")
        end
        return false
    end

    if LTS.pullProtocol and LTS.markerProtocol then return true end

    if not LTS.lgbHandler then
        local ok, handler = pcall(function()
            return LibGroupBroadcast:RegisterHandler(LTS.name)
        end)
        if not ok or not handler then return false end

        if handler.SetDisplayName then handler:SetDisplayName("LibTeamShadows") end
        if handler.SetDescription then handler:SetDescription("Group signals for the Team Shadows addons (pull countdown, shared markers).") end
        LTS.lgbHandler = handler
    end

    if not LTS.pullProtocol then
        local ok, protocol = pcall(function()
            local p = LTS.lgbHandler:DeclareProtocol(LTS.PROTOCOL_ID_PULL, "TeamShadowsPull")
            p:AddField(LibGroupBroadcast.CreateNumericField("seconds", {
                minValue = 0,
                maxValue = 20,
            }))
            p:OnData(function(unitTag, data)
                if LTS.acceptLeadOnly ~= false and IsUnitGroupLeader and not IsUnitGroupLeader(unitTag) then return end
                DispatchGroupPull(data and data.seconds or 0, unitTag)
            end)
            p:Finalize({
                isRelevantInCombat = false,
                replaceQueuedMessages = true,
            })
            return p
        end)
        if ok and protocol then LTS.pullProtocol = protocol end
    end

    if not LTS.markerProtocol and LibGroupBroadcast.CreateFlagField then
        local ok, protocol = pcall(function()
            local p = LTS.lgbHandler:DeclareProtocol(LTS.PROTOCOL_ID_MARKER, "TeamShadowsMarker")
            p:AddField(LibGroupBroadcast.CreateNumericField("zone", { minValue = 0, maxValue = 4095 }))
            p:AddField(LibGroupBroadcast.CreateNumericField("x", { minValue = 0, maxValue = 4194303 }))
            p:AddField(LibGroupBroadcast.CreateNumericField("y", { minValue = -131072, maxValue = 4063231 }))
            p:AddField(LibGroupBroadcast.CreateNumericField("z", { minValue = 0, maxValue = 4194303 }))
            p:AddField(LibGroupBroadcast.CreateNumericField("textureId", { minValue = 1, maxValue = 31, trimValues = true }))
            p:AddField(LibGroupBroadcast.CreateNumericField("labelId", { minValue = 0, maxValue = 15, trimValues = true }))
            p:AddField(LibGroupBroadcast.CreateNumericField("size", { minValue = 24, maxValue = 160, trimValues = true }))
            p:AddField(LibGroupBroadcast.CreateNumericField("durationS", { minValue = 1, maxValue = 60, trimValues = true }))
            p:AddField(LibGroupBroadcast.CreateFlagField("isRendezvous"))
            p:OnData(OnMarkerData)
            p:Finalize({
                isRelevantInCombat = false,
                replaceQueuedMessages = true,
            })
            return p
        end)
        if ok and protocol then LTS.markerProtocol = protocol end
    end

    return LTS.pullProtocol ~= nil
end

local function SendProtocol(protocol, values)
    if not protocol then return false end
    if protocol.IsEnabled and not protocol:IsEnabled() then return false end

    local ok, sent = pcall(function()
        return protocol:Send(values)
    end)
    return ok and sent == true
end

-- ---------------------------------------------------------------------
-- Marker helpers
-- ---------------------------------------------------------------------

local function CanSendMarker()
    if not IsGrouped() then return false end

    local nowMs = NowMs()
    if nowMs - (LTS.lastMarkerPingMs or 0) < LTS.markerPingIntervalMs then
        return false
    end

    LTS.lastMarkerPingMs = nowMs
    return true
end

local function BuildMarkerLocation(textureId)
    if not GetUnitRawWorldPosition then return nil end

    local zone, wX, wY, wZ = GetUnitRawWorldPosition("player")
    if not zone or not wX or not wY or not wZ then return nil end

    return {
        zone = zone,
        x = wX,
        y = wY,
        z = wZ,
        textureId = tonumber(textureId) or 1,
    }
end

function LTS.GetMarkerTexture(textureId)
    return LTS.markerTextures[tonumber(textureId) or 1] or LTS.defaultMarkerTexture
end

local function GetDefaultMarkerColor(textureId)
    return LTS.markerTextureColors[tonumber(textureId) or 1] or LTS.markerTextureColors[1]
end

local function TextureHasNativeText(textureId)
    textureId = tonumber(textureId) or 0
    return textureId >= 8
end

-- Labels with a pre-rendered glyph texture, baked into the marker
-- plane as a badge quad: numbers 1-10, H1/H2/MT/OT/FV and single
-- letters A-Z. Free text falls back to the projected 2D label.
local BAKED_LABELS = {}
for i = 1, 10 do BAKED_LABELS[tostring(i)] = true end
for _, key in ipairs({ "h1", "h2", "mt", "ot", "fv" }) do BAKED_LABELS[key] = true end
for c = string.byte("a"), string.byte("z") do BAKED_LABELS[string.char(c)] = true end

local function GetBakedLabelTexture(labelText)
    if type(labelText) ~= "string" then return nil end
    local key = labelText:lower()
    if BAKED_LABELS[key] then
        return "LibTeamShadows/textures/labels/" .. key .. ".dds"
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Marker rendering -- native 3D render spaces (original code)
-- Markers are FLAT ground markers: each marker root is a world-anchored
-- 3D render space laid horizontal (pitch 90, the orientation ZOS uses
-- for the top/bottom faces of the crown crate boxes), origin re-set
-- every frame from WorldPositionToGuiRender3DPosition because the
-- GuiRender3D origin shifts as the player travels. The texture control
-- uses the depth buffer so characters and world geometry occlude the
-- marker instead of the marker drawing over them -- players can stand
-- ON the marker and it never hides AoE telegraphs or combat info.
-- A camera-synced render space (Set3DRenderSpaceToCurrentCamera) is
-- kept only to read the camera position/basis for the depth gate and
-- the 2D label projection (the public getters ZO_HousingEditorHud
-- uses, already proven by the previous in-game version).
-- ---------------------------------------------------------------------

local METERS_PER_64PX = 0.9   -- world size of a 64px marker, in meters
-- Flat marker orientation, calibrated in-game (2026-07-08): pitch -90
-- lays the quad flat with its FRONT face up (+90 showed the BACK face,
-- mirroring the glyphs), and with the front face up no yaw offset is
-- needed for the bottom of the icon to face the camera. Runtime-tunable
-- via LTS.SetMarkerFlatOrientation if render space conventions change.
LTS.markerFlatPitch = LTS.markerFlatPitch or math.rad(-90)
LTS.markerYawOffset = LTS.markerYawOffset or 0

local function EnsureMarkerRenderer()
    if LTS.markerWindow and LTS.markerCameraSpace then return true end
    if not WINDOW_MANAGER or not GuiRoot then return false end
    if not Set3DRenderSpaceToCurrentCamera or not WorldPositionToGuiRender3DPosition then return false end

    local wm = WINDOW_MANAGER

    LTS.markerWindow = wm:CreateTopLevelWindow("LibTeamShadowsMarkerWindow")
    LTS.markerWindow:SetAnchorFill(GuiRoot)
    LTS.markerWindow:SetMouseEnabled(false)
    LTS.markerWindow:SetMovable(false)
    LTS.markerWindow:SetDrawLayer(DL_BACKGROUND)
    LTS.markerWindow:SetHidden(false)

    -- camera space: synced to the camera every frame, used only as a
    -- camera position/basis probe for the depth gate and the 2D label
    -- projection. It has no texture and hosts no marker.
    LTS.markerCameraSpace = wm:CreateControl("LibTeamShadowsCameraSpace", LTS.markerWindow, CT_CONTROL)
    LTS.markerCameraSpace:Create3DRenderSpace()
    LTS.markerCameraSpace:SetHidden(false)

    if ZO_HUDFadeSceneFragment then
        LTS.markerFragment = ZO_HUDFadeSceneFragment:New(LTS.markerWindow)
        if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(LTS.markerFragment) end
        if HUD_SCENE then HUD_SCENE:AddFragment(LTS.markerFragment) end
        if LOOT_SCENE then LOOT_SCENE:AddFragment(LTS.markerFragment) end
    end

    return true
end

local function GetFreeIcon()
    if not EnsureMarkerRenderer() then return nil end

    for _, icon in ipairs(LTS.iconPool) do
        if not icon.use then
            icon.use = true
            return icon
        end
    end

    local wm = WINDOW_MANAGER

    -- root: world-anchored render space laid FLAT on the ground.
    -- No longer a child of the camera space: billboards inherited the
    -- camera orientation and visually drifted with every camera move,
    -- which made precise stacking on a marker impossible. Pitch 90 is
    -- the same orientation ZOS uses for the horizontal top/bottom faces
    -- of the crown crate boxes (crowncratespackchoosing.lua).
    -- ZXY rotation order (same as the housing editor window): pitch
    -- lays the quad flat, then yaw -- applied around world Y -- spins
    -- it in the ground plane to face the camera each frame.
    local root = wm:CreateControl(nil, LTS.markerWindow, CT_CONTROL)
    root:Create3DRenderSpace()
    if root.Set3DRenderSpaceAxisRotationOrder and AXIS_ROTATION_ORDER_ZXY then
        root:Set3DRenderSpaceAxisRotationOrder(AXIS_ROTATION_ORDER_ZXY)
    end
    root:Set3DRenderSpaceOrientation(LTS.markerFlatPitch, LTS.markerYawOffset, 0)
    root:SetHidden(true)

    -- texture: own render space, sized in meters at placement.
    -- Depth buffer is OPT-IN (LTS.SetMarkerUseDepthBuffer): ZOS only
    -- uses it in controlled scenes (crown crates, housing) and in the
    -- open world the depth test can fail permanently, leaving the
    -- texture invisible. Default is off; markers stay non-intrusive
    -- through flat ground placement + semi-transparency instead.
    local ctrl = wm:CreateControl(nil, root, CT_TEXTURE)
    ctrl:Create3DRenderSpace()
    ctrl:SetPixelRoundingEnabled(false)
    if ctrl.Set3DRenderSpaceUsesDepthBuffer then
        ctrl:Set3DRenderSpaceUsesDepthBuffer(LTS.markerUseDepthBuffer == true)
    end

    -- badge: the marker number/letter baked INTO the marker plane. A
    -- small overlay quad in the same render space, sitting 2 cm above
    -- the marker (-Z in the pitched root's local frame = world up), so
    -- the label is part of the icon, in perspective, and rotates with
    -- it -- no separate floating 2D digit.
    local badge = wm:CreateControl(nil, root, CT_TEXTURE)
    badge:Create3DRenderSpace()
    badge:SetPixelRoundingEnabled(false)
    if badge.Set3DRenderSpaceUsesDepthBuffer then
        badge:Set3DRenderSpaceUsesDepthBuffer(LTS.markerUseDepthBuffer == true)
    end
    if badge.Set3DRenderSpaceOrigin then
        badge:Set3DRenderSpaceOrigin(0, 0, -0.02)
    end
    badge:SetHidden(true)

    -- label: plain 2D control, positioned by projection each frame.
    -- Only used as a fallback for free-text labels that have no baked
    -- glyph texture.
    local label = wm:CreateControl(nil, LTS.markerWindow, CT_LABEL)
    label:SetDimensions(200, 64)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetFont("$(BOLD_FONT)|32|soft-shadow-thick")
    label:SetHidden(true)

    local icon = {
        use = true,
        root = root,
        ctrl = ctrl,
        badge = badge,
        label = label,
    }
    LTS.iconPool[#LTS.iconPool + 1] = icon
    return icon
end

local function UpdateMarkerRenderer()
    local camSpace = LTS.markerCameraSpace
    if not camSpace then return end

    Set3DRenderSpaceToCurrentCamera(camSpace:GetName())

    -- camera position/basis (world space) for the depth gate and the 2D
    -- label projection -- getters proven by the previous in-game version
    local fX, fY, fZ = camSpace:Get3DRenderSpaceForward()
    local camWX, camWY, camWZ, rgX, rgY, rgZ, upX, upY, upZ, uiW, uiH
    local canProject = fX ~= nil and GuiRender3DPositionToWorldPosition ~= nil and GetWorldDimensionsOfViewFrustumAtDepth ~= nil
    if canProject then
        camWX, camWY, camWZ = GuiRender3DPositionToWorldPosition(camSpace:Get3DRenderSpaceOrigin())
        rgX, rgY, rgZ = camSpace:Get3DRenderSpaceRight()
        upX, upY, upZ = camSpace:Get3DRenderSpaceUp()
        uiW, uiH = GuiRoot:GetDimensions()
        canProject = camWX ~= nil and rgX ~= nil and upX ~= nil and uiW ~= nil
    end

    local currentZone, playerX, playerZ = nil, nil, nil
    if GetUnitRawWorldPosition then
        local zone, pX, _, pZ = GetUnitRawWorldPosition("player")
        currentZone, playerX, playerZ = zone, pX, pZ
    end

    -- camera heading: the flat markers spin in the ground plane every
    -- frame so the bottom of the icon always points toward the camera
    local camHeading = (GetPlayerCameraHeading and GetPlayerCameraHeading()) or 0
    local baseAlpha = LTS.markerAlpha or 0.75

    for _, icon in ipairs(LTS.iconPool) do
        if icon.use and icon.x and icon.y and icon.z then
            local wY = icon.y + ((tonumber(icon.heightOffset) or 0) * 100)
            local hidden = true
            local depth = nil

            if not (icon.zone and currentZone and icon.zone ~= currentZone) then
                if canProject then
                    depth = ((icon.x - camWX) * fX) + ((wY - camWY) * fY) + ((icon.z - camWZ) * fZ)
                end
                -- hide markers behind the camera (depth in cm)
                if depth == nil or depth > 50 then
                    -- Raw world positions are in CENTIMETERS while the 3D
                    -- render space API works in GuiRender3D coordinates
                    -- (METERS, 1:100 scale, different shifting origin).
                    -- The root is world-anchored, so its origin is simply
                    -- the converted world position -- re-set every frame
                    -- because the GuiRender3D origin shifts as the player
                    -- travels. +8 cm lift avoids z-fighting with the
                    -- ground now that the marker lies flat on it.
                    local gx, gy, gz = WorldPositionToGuiRender3DPosition(zo_round(icon.x), zo_round(wY + 8), zo_round(icon.z))
                    if gx then
                        icon.root:Set3DRenderSpaceOrigin(gx, gy, gz)
                        -- pitch keeps the marker flat, yaw follows the
                        -- camera so the icon reads upright from the
                        -- player's point of view
                        icon.root:Set3DRenderSpaceOrientation(LTS.markerFlatPitch, camHeading + LTS.markerYawOffset, 0)

                        -- proximity fade: when the local player stands
                        -- on/near the marker, it fades out so it never
                        -- covers the character, nameplates or AoE info
                        local alpha = baseAlpha
                        if playerX then
                            local dx, dz = icon.x - playerX, icon.z - playerZ
                            local dist = math.sqrt((dx * dx) + (dz * dz))
                            if dist < 300 then
                                local t = dist / 300
                                alpha = 0.15 + ((baseAlpha - 0.15) * t)
                            end
                        end
                        icon.ctrl:SetColor(1, 1, 1, alpha)
                        if icon.hasBadge and icon.badge then
                            icon.badge:SetColor(1, 1, 1, alpha)
                        end

                        hidden = false
                    end
                end
            end
            icon.root:SetHidden(hidden)

            local labelVisible = false
            if not hidden and canProject and depth and depth > 50 and icon.labelText and icon.labelText ~= "" then
                local w, h = GetWorldDimensionsOfViewFrustumAtDepth(depth)
                if w and h and w > 0 and h > 0 then
                    -- label projected at the marker position: the digit
                    -- sits visually ON the flat marker
                    local dX, dY, dZ = icon.x - camWX, wY - camWY, icon.z - camWZ
                    local sx = ((dX * rgX) + (dY * rgY) + (dZ * rgZ)) * uiW / w
                    local sy = ((dX * upX) + (dY * upY) + (dZ * upZ)) * uiH / h
                    icon.label:ClearAnchors()
                    icon.label:SetAnchor(CENTER, LTS.markerWindow, CENTER, sx, -sy)
                    labelVisible = true
                end
            end
            icon.label:SetHidden(not labelVisible)
        end
    end
end

local function StartMarkerRenderer()
    if not EnsureMarkerRenderer() then return end
    EM:RegisterForUpdate(LTS.name .. "MarkerRenderer", 16, UpdateMarkerRenderer)
end

local function StopMarkerRendererIfIdle()
    for _, icon in ipairs(LTS.iconPool) do
        if icon.use then return end
    end
    EM:UnregisterForUpdate(LTS.name .. "MarkerRenderer")
end

-- ---------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------

function LTS.SetRendezvousOptIn(value)
    LTS.rendezvousOptIn = value ~= false
end

function LTS.SetAcceptLeadOnly(value)
    LTS.acceptLeadOnly = value ~= false
end

function LTS.SetMarkerSize(size)
    LTS.defaultMarkerSize = zo_clamp(tonumber(size) or LTS.defaultMarkerSize, 24, 160)
end

function LTS.SetMarkerHeight(height)
    LTS.defaultMarkerHeight = zo_clamp(tonumber(height) or LTS.defaultMarkerHeight, -40, 80)
end

-- Opt-in world occlusion. Applies live to pooled markers so it can be
-- toggled in-game for testing:
--   /script LibTeamShadows.SetMarkerUseDepthBuffer(true)
function LTS.SetMarkerUseDepthBuffer(enabled)
    LTS.markerUseDepthBuffer = enabled == true
    for _, icon in ipairs(LTS.iconPool or {}) do
        if icon.ctrl and icon.ctrl.Set3DRenderSpaceUsesDepthBuffer then
            icon.ctrl:Set3DRenderSpaceUsesDepthBuffer(LTS.markerUseDepthBuffer)
        end
        if icon.badge and icon.badge.Set3DRenderSpaceUsesDepthBuffer then
            icon.badge:Set3DRenderSpaceUsesDepthBuffer(LTS.markerUseDepthBuffer)
        end
    end
end

-- Marker texture opacity (0.2 - 1). The update loop reapplies it every
-- frame (combined with the player proximity fade), so setting the
-- value is enough for it to take effect immediately.
function LTS.SetMarkerAlpha(alpha)
    LTS.markerAlpha = zo_clamp(tonumber(alpha) or 0.75, 0.2, 1)
end

-- In-game calibration of the flat marker orientation, in DEGREES.
-- Takes effect on the next frame, no reload needed. Default (-90, 0)
-- was validated on live (2026-07-08). Alternatives if glyphs ever
-- render wrong after an API change:
--   /script LibTeamShadows.SetMarkerFlatOrientation(-90, 180) -- upside down
--   /script LibTeamShadows.SetMarkerFlatOrientation(90, 0)    -- mirrored
--   /script LibTeamShadows.SetMarkerFlatOrientation(90, 180)  -- mirrored + upside down
function LTS.SetMarkerFlatOrientation(pitchDegrees, yawOffsetDegrees)
    LTS.markerFlatPitch = math.rad(tonumber(pitchDegrees) or -90)
    LTS.markerYawOffset = math.rad(tonumber(yawOffsetDegrees) or 0)
end

function LTS.SetMarkerDuration(durationMs)
    LTS.defaultMarkerDurationMs = zo_clamp(tonumber(durationMs) or LTS.defaultMarkerDurationMs, 1000, 60000)
end

function LTS.GetMarkerLabel(labelId)
    return LTS.markerLabels[tonumber(labelId) or 0]
end

-- ---------------------------------------------------------------------
-- Marker placement (local rendering)
-- ---------------------------------------------------------------------

function LTS.PlaceWorldMarker(location, options)
    if not location then return nil end
    if not EnsureMarkerRenderer() then return nil end

    options = options or {}
    local texture = options.texture or LTS.GetMarkerTexture(location.textureId)
    local size = tonumber(options.size) or LTS.defaultMarkerSize
    local durationMs = tonumber(options.durationMs) or LTS.defaultMarkerDurationMs
    local rawColor = options.color or location.color or GetDefaultMarkerColor(location.textureId)
    local labelColor = { rawColor.r or rawColor[1] or 1, rawColor.g or rawColor[2] or 1, rawColor.b or rawColor[3] or 1 }
    local labelText = nil
    if not TextureHasNativeText(location.textureId) then
        labelText = options.labelText or options.customLabel or location.customLabel or LTS.GetMarkerLabel(options.labelId or location.labelId)
    end
    local height = zo_clamp(tonumber(options.heightOffset) or LTS.defaultMarkerHeight, -40, 80)
    local badgeTexture = GetBakedLabelTexture(labelText)
    if badgeTexture then
        -- glyph baked into the marker plane: no 2D fallback label
        labelText = nil
    end

    local icon = GetFreeIcon()

    if icon then
        icon.x = tonumber(location.x)
        icon.y = tonumber(location.y)
        icon.z = tonumber(location.z)
        icon.zone = tonumber(location.zone)
        icon.texture = texture
        icon.size = size
        icon.heightOffset = height
        icon.labelText = labelText
        icon.hasBadge = badgeTexture ~= nil

        -- static setup happens once at placement; the update loop only
        -- moves/orients the root render space afterwards
        local ok, setupError = pcall(function()
            icon.ctrl:SetTexture(texture or LTS.defaultMarkerTexture)
            -- semi-transparent so a flat marker never hides AoE
            -- telegraphs or ground effects drawn underneath it
            icon.ctrl:SetColor(1, 1, 1, LTS.markerAlpha or 0.75)
            local meters = (size / 64) * METERS_PER_64PX
            icon.ctrl:Set3DLocalDimensions(meters, meters)
            -- identity is the default; only set explicitly when available
            if icon.ctrl.Set3DRenderSpaceOrigin then icon.ctrl:Set3DRenderSpaceOrigin(0, 0, 0) end
            if icon.ctrl.Set3DRenderSpaceOrientation then icon.ctrl:Set3DRenderSpaceOrientation(0, 0, 0) end
            if icon.badge then
                if badgeTexture then
                    icon.badge:SetTexture(badgeTexture)
                    local badgeMeters = meters * 0.55
                    icon.badge:Set3DLocalDimensions(badgeMeters, badgeMeters)
                    icon.badge:SetColor(1, 1, 1, 1)
                    icon.badge:SetHidden(false)
                else
                    icon.badge:SetHidden(true)
                end
            end
        end)
        if not ok then
            icon.use = false
            if not LTS.markerSetupWarned then
                LTS.markerSetupWarned = true
                d("|cff6600LibTeamShadows:|r marker setup failed, markers disabled (" .. tostring(setupError) .. ")")
            end
            return nil
        end

        if labelText and labelText ~= "" then
            local luminance = (labelColor[1] * 0.299) + (labelColor[2] * 0.587) + (labelColor[3] * 0.114)
            if luminance > 0.5 then
                icon.label:SetColor(0, 0, 0, 1)
            else
                icon.label:SetColor(1, 1, 1, 1)
            end
            icon.label:SetText(labelText)
        else
            icon.label:SetText("")
        end
        icon.label:SetHidden(true)

        -- stays hidden until the first update positions it correctly
        icon.root:SetHidden(true)

        table.insert(LTS.worldIcons, icon)
        StartMarkerRenderer()
        if not options.persistent then
            zo_callLater(function()
                LTS.DiscardWorldMarker(icon)
            end, durationMs)
        end
    end

    return icon
end

function LTS.DiscardWorldMarker(icon)
    if not icon then return end
    icon.use = false
    icon.x, icon.y, icon.z, icon.zone = nil, nil, nil, nil
    icon.labelText = nil
    if icon.root then icon.root:SetHidden(true) end
    if icon.label then
        icon.label:SetText("")
        icon.label:SetHidden(true)
    end
    StopMarkerRendererIfIdle()
end

function LTS.PlaceLocalRendezvous(textureId, options)
    local location = BuildMarkerLocation(textureId)
    if not location then return false end

    options = options or {}
    location.labelId = tonumber(options.labelId) or 0

    return LTS.PlaceWorldMarker(location, {
        texture = options.texture,
        durationMs = tonumber(options.durationMs) or LTS.defaultMarkerDurationMs,
        size = tonumber(options.size) or LTS.defaultMarkerSize,
        heightOffset = tonumber(options.heightOffset) or LTS.defaultMarkerHeight,
        labelId = location.labelId,
        persistent = options.persistent,
    }) ~= nil
end

-- ---------------------------------------------------------------------
-- Group broadcasting (LibGroupBroadcast only)
-- ---------------------------------------------------------------------

local function SendMarker(location, options)
    if not EnsureGroupBroadcastProtocols() or not LTS.markerProtocol then return false end

    options = options or {}

    return SendProtocol(LTS.markerProtocol, {
        zone = tonumber(location.zone) or 0,
        x = zo_round(tonumber(location.x) or 0),
        y = zo_round(tonumber(location.y) or 0),
        z = zo_round(tonumber(location.z) or 0),
        textureId = tonumber(location.textureId) or 1,
        labelId = tonumber(options.labelId) or tonumber(location.labelId) or 0,
        size = zo_round(tonumber(options.size) or LTS.defaultMarkerSize),
        durationS = zo_clamp(zo_round((tonumber(options.durationMs) or LTS.defaultMarkerDurationMs) / 1000), 1, 60),
        isRendezvous = true,
    })
end

function LTS.BroadcastPull(seconds)
    if not IsGrouped() then return false end

    local nowMs = NowMs()
    if nowMs - (LTS.lastBroadcastMs or 0) < LTS.minBroadcastIntervalMs then
        return false
    end

    LTS.lastBroadcastMs = nowMs
    seconds = zo_clamp(tonumber(seconds) or 0, 0, 20)

    if not EnsureGroupBroadcastProtocols() then return false end
    return SendProtocol(LTS.pullProtocol, { seconds = seconds })
end

function LTS.BroadcastRendezvous(textureId, options)
    if not LTS.directMarkerSharingEnabled then return false end
    if not CanSendMarker() then return false end

    local location = BuildMarkerLocation(textureId)
    if not location then return false end

    options = options or {}
    location.labelId = tonumber(options.labelId) or 0

    if not options.noLocal then
        LTS.PlaceWorldMarker(location, {
            durationMs = tonumber(options.durationMs) or LTS.defaultMarkerDurationMs,
            size = tonumber(options.size) or LTS.defaultMarkerSize,
            heightOffset = tonumber(options.heightOffset) or LTS.defaultMarkerHeight,
            labelId = location.labelId,
            persistent = options.persistent,
        })
    end

    return SendMarker(location, options)
end

function LTS.BroadcastMarkerLocation(location, options)
    if not LTS.directMarkerSharingEnabled then return false end
    if not CanSendMarker() then return false end
    if not location or not location.zone or not location.x or not location.y or not location.z then return false end

    options = options or {}
    location.textureId = tonumber(location.textureId) or tonumber(options.textureId) or 1
    location.labelId = tonumber(options.labelId) or tonumber(location.labelId) or 0

    if not options.noLocal then
        LTS.PlaceWorldMarker(location, {
            durationMs = tonumber(options.durationMs) or LTS.defaultMarkerDurationMs,
            size = tonumber(options.size) or LTS.defaultMarkerSize,
            heightOffset = tonumber(options.heightOffset) or LTS.defaultMarkerHeight,
            labelId = location.labelId,
            persistent = options.persistent,
        })
    end

    return SendMarker(location, options)
end

-- ---------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------

local function OnAddonLoaded(_, addonName)
    if addonName ~= LTS.name then return end

    EM:UnregisterForEvent(LTS.name, EVENT_ADD_ON_LOADED)
    EnsureGroupBroadcastProtocols()
end

EM:RegisterForEvent(LTS.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
