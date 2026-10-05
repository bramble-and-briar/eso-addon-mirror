-- Radiant Range
-- Approved non-animated DDS retained; settings are per character and per megaserver.

local ADDON_NAME = "RadiantRange"
local SAVED_VARS_NAME = "RadiantRangeSavedVariables"
local SAVED_VARS_VERSION = 1

local UPDATE_NAME = ADDON_NAME .. "PositionUpdate"
local PLAYER_EVENT = ADDON_NAME .. "PlayerActivated"
local COMBAT_EVENT = ADDON_NAME .. "CombatState"
local UPDATE_MS = 16
local HEIGHT_OFFSET_CM = 8
local GLOW_TEXTURE = "RadiantRange/RadiantRangeCircle.dds"
local STONE_TEXTURE = "RadiantRange/RadiantRangeStone.dds"
local RAW_UNITS_PER_METER = 100
local GROUP_HEARTBEAT_NAME = ADDON_NAME .. "GroupHeartbeat"
local GROUP_HEARTBEAT_MS = 30000
local STARTUP_RETRY_NAME = ADDON_NAME .. "StartupRetry"

local DEFAULTS = {
    enabled = true,
    radius = 12,
    color = { 0.62, 0.48, 1.00 },
    intensity = 0.85,
    showWhen = "Always",
    shareMyRange = true,
    showGroupRanges = true,
    shape = "Circle",
    forwardStartWidth = 3,
    forwardDistance = 20,
    forwardEndWidth = 8,
}

local SHOW_CHOICES = { "Always", "In Combat Only", "Out of Combat Only" }
local SHAPE_CHOICES = { "Circle", "Forward Area" }

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local LAM = LibAddonMenu2
local WorldToRender = WorldPositionToGuiRender3DPosition
local GetRawWorldPosition = GetUnitRawWorldPosition
local rad = math.rad

-- Forward declaration: used by combat/runtime callbacks defined before group sharing setup.
local sendGroupState
local sendGroupHeading

local PGT = {
    root = nil,
    glow = nil,
    fragment = nil,
    sv = nil,
    inCombat = false,
    groupProtocol = nil,
    groupGlows = {},
    groupData = {},
    groupFacingDots = {},
    groupHeading = {},
    facingDots = {},
}

local function copyDefaultsIntoSavedVars()
    PGT.sv.enabled = DEFAULTS.enabled
    PGT.sv.radius = DEFAULTS.radius
    PGT.sv.color = { DEFAULTS.color[1], DEFAULTS.color[2], DEFAULTS.color[3] }
    PGT.sv.intensity = DEFAULTS.intensity
    PGT.sv.showWhen = DEFAULTS.showWhen
    PGT.sv.shareMyRange = DEFAULTS.shareMyRange
    PGT.sv.showGroupRanges = DEFAULTS.showGroupRanges
    PGT.sv.shape = DEFAULTS.shape
    PGT.sv.forwardStartWidth = DEFAULTS.forwardStartWidth
    PGT.sv.forwardDistance = DEFAULTS.forwardDistance
    PGT.sv.forwardEndWidth = DEFAULTS.forwardEndWidth
end

local function shouldShow()
    if not PGT.sv or not PGT.sv.enabled then
        return false
    end

    if PGT.sv.showWhen == "In Combat Only" then
        return PGT.inCombat
    elseif PGT.sv.showWhen == "Out of Combat Only" then
        return not PGT.inCombat
    end

    return true
end

local function stopUpdates()
    EM:UnregisterForUpdate(UPDATE_NAME)
end

local function hideFacingDots()
    for _, dot in ipairs(PGT.facingDots) do
        dot:SetHidden(true)
    end
end

local function updateForwardArea(worldX, worldY, worldZ)
    if #PGT.facingDots < 800 then return end

    -- Character-facing forward-area perimeter.
    local zoneId = select(1, GetRawWorldPosition("player"))
    local _, _, heading = GetMapPlayerPosition("player")


    if not zoneId or zoneId == 0 or heading == nil or not GetRawNormalizedWorldPosition then
        hideFacingDots()
        return
    end

    local mx0, mz0 = GetRawNormalizedWorldPosition(zoneId, worldX, worldY, worldZ)
    local mxx, mzx = GetRawNormalizedWorldPosition(zoneId, worldX + RAW_UNITS_PER_METER, worldY, worldZ)
    local mxz, mzz = GetRawNormalizedWorldPosition(zoneId, worldX, worldY, worldZ + RAW_UNITS_PER_METER)
    if not mx0 or not mxx or not mxz then hideFacingDots(); return end

    local ax, az = mxx - mx0, mzx - mz0
    local bx, bz = mxz - mx0, mzz - mz0
    local det = ax * bz - bx * az
    if math.abs(det) < 0.000000000001 then hideFacingDots(); return end

    local mapFX, mapFZ = math.sin(heading), math.cos(heading)
    local rawFX = ( bz * mapFX - bx * mapFZ) / det
    local rawFZ = (-az * mapFX + ax * mapFZ) / det
    local mag = math.sqrt(rawFX * rawFX + rawFZ * rawFZ)
    if mag <= 0 then hideFacingDots(); return end

    rawFX, rawFZ = -(rawFX / mag), -(rawFZ / mag)
    local rawRX, rawRZ = -rawFZ, rawFX

    local startWidth = zo_clamp(tonumber(PGT.sv.forwardStartWidth) or 3, 1, 20)
    local distance = zo_clamp(tonumber(PGT.sv.forwardDistance) or 20, 1, 30)
    local endWidth = zo_clamp(tonumber(PGT.sv.forwardEndWidth) or 8, 1, 20)
    local points = {}

    local function addPoint(forwardM, sideM)
        points[#points + 1] = { forwardM, sideM }
    end

    -- Left/right edges every ~0.15 meter, interpolating width from start to end.
    local STONE_SPACING = 0.15
    local STONE_SIZE = 0.17
    local steps = math.max(1, math.ceil(distance / STONE_SPACING))
    for i = 0, steps do
        local t = i / steps
        local f = distance * t
        local width = startWidth + (endWidth - startWidth) * t
        local half = width * 0.5
        addPoint(f, -half)
        addPoint(f,  half)
    end

    -- Close the near and far edges with the same tiny-stone spacing.
    local function addCrossEdge(forwardM, width)
        local n = math.max(1, math.ceil(width / STONE_SPACING))
        for i = 1, n - 1 do
            addPoint(forwardM, -width * 0.5 + width * (i / n))
        end
    end
    addCrossEdge(0, startWidth)
    addCrossEdge(distance, endWidth)

    for i, dot in ipairs(PGT.facingDots) do
        local pt = points[i]
        if not pt then
            dot:SetHidden(true)
        else
            local f, side = pt[1], pt[2]
            local x = worldX + (rawFX * f + rawRX * side) * RAW_UNITS_PER_METER
            local z = worldZ + (rawFZ * f + rawRZ * side) * RAW_UNITS_PER_METER
            local renderX, renderY, renderZ = WorldToRender(x, worldY + HEIGHT_OFFSET_CM, z)
            if renderX == nil then
                dot:SetHidden(true)
            else
                dot:Set3DLocalDimensions(STONE_SIZE, STONE_SIZE)
                local c = PGT.sv.color or DEFAULTS.color
                dot:SetColor(c[1], c[2], c[3], 1)
                dot:SetAlpha(PGT.sv.intensity or DEFAULTS.intensity)
                dot:Set3DRenderSpaceOrigin(renderX, renderY, renderZ)
                dot:SetHidden(false)
            end
        end
    end
end

local function updatePosition()
    local glow = PGT.glow
    if not glow or not shouldShow() then
        if glow then glow:SetHidden(true) end
        hideFacingDots()
        return
    end

    local zoneId, worldX, worldY, worldZ = GetRawWorldPosition("player")
    if not zoneId or zoneId == 0 or not worldX then
        glow:SetHidden(true)
        hideFacingDots()
        return
    end

    if PGT.sv.shape == "Forward Area" then
        glow:SetHidden(true)

        -- Individual 3D perimeter markers are hidden during translation to keep
        -- the forward area visually stable. Turning in place remains live.
        if IsPlayerMoving and IsPlayerMoving() then
            hideFacingDots()
            return
        end

        updateForwardArea(worldX, worldY, worldZ)
        return
    end

    hideFacingDots()
    local renderX, renderY, renderZ = WorldToRender(worldX, worldY + HEIGHT_OFFSET_CM, worldZ)
    if renderX == nil then
        glow:SetHidden(true)
        return
    end

    glow:Set3DRenderSpaceOrigin(renderX, renderY, renderZ)
    glow:SetHidden(false)
end

local function startUpdates()
    stopUpdates()

    if not shouldShow() then
        if PGT.glow then PGT.glow:SetHidden(true) end
        return
    end

    updatePosition()
    EM:RegisterForUpdate(UPDATE_NAME, UPDATE_MS, updatePosition)
end

local function updateCombatRegistration()
    EM:UnregisterForEvent(COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE)

    if not PGT.sv or not PGT.sv.enabled or PGT.sv.showWhen == "Always" then
        return
    end

    EM:RegisterForEvent(COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        PGT.inCombat = inCombat == true
        startUpdates()
        sendGroupState()
    end)
end

local function applyVisualSettings()
    local glow = PGT.glow
    if not glow or not PGT.sv then return end

    local diameter = PGT.sv.radius * 2
    glow:Set3DLocalDimensions(diameter, diameter)

    local color = PGT.sv.color
    glow:SetColor(color[1], color[2], color[3], 1)
    glow:SetAlpha(PGT.sv.intensity)
end

local function refreshRuntime()
    applyVisualSettings()
    updateCombatRegistration()
    startUpdates()
end

local function createGlow()
    if PGT.root then return end

    local root = WM:CreateTopLevelWindow("RadiantRangeRoot")
    root:SetAnchorFill(GuiRoot)
    root:SetMouseEnabled(false)
    root:SetMovable(false)

    local glow = WM:CreateControl("RadiantRangeGlow", root, CT_TEXTURE)
    glow:Create3DRenderSpace()
    glow:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
    glow:Set3DRenderSpaceUsesDepthBuffer(true)
    glow:SetTexture(GLOW_TEXTURE)
    -- Sample slightly inside the DDS edge to reduce border bleed.
    glow:SetTextureCoords(0.001, 0.999, 0.001, 0.999)
    glow:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)

    -- Verified working ground-plane orientation. Do not change.
    glow:Set3DRenderSpaceOrientation(rad(90), 0, 0)
    glow:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    glow:SetHidden(true)

    -- Pre-create the perimeter markers used by Forward Area.
    for i = 1, 800 do
        local dot = WM:CreateControl("RadiantRangeFacingDot" .. i, root, CT_TEXTURE)
        dot:Create3DRenderSpace()
        dot:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
        dot:Set3DRenderSpaceUsesDepthBuffer(true)
        dot:SetTexture(STONE_TEXTURE)
        dot:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
        dot:Set3DRenderSpaceOrientation(rad(90), 0, 0)
        dot:Set3DLocalDimensions(0.17, 0.17)
        dot:SetColor(1, 0.85, 0.05, 1)
        dot:SetAlpha(1)
        dot:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        dot:SetHidden(true)
        PGT.facingDots[i] = dot
    end

    PGT.root = root
    PGT.glow = glow
end

local function setupHudFragment()
    if PGT.fragment or not PGT.root then return end
    if not SCENE_MANAGER or not HUD_SCENE or not HUD_UI_SCENE then return end

    -- Scene objects are intentionally touched only after player activation.
    local fragment = ZO_SimpleSceneFragment:New(PGT.root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    PGT.fragment = fragment
end


-- Group sharing.
-- Uses LibGroupBroadcast only for grouped players who also run Radiant Range.
-- Protocol ID 190 and handler RadiantRangeSharing are the registered Radiant Range identities.

local function hideGroupFacingDots(unitTag)
    local dots = PGT.groupFacingDots[unitTag]
    if not dots then return end
    for _, dot in ipairs(dots) do dot:SetHidden(true) end
end

local function hideAllGroupFacingDots()
    for unitTag in pairs(PGT.groupFacingDots) do hideGroupFacingDots(unitTag) end
end

local function getGroupFacingDots(unitTag)
    local dots = PGT.groupFacingDots[unitTag]
    if dots then return dots end
    if not PGT.root then return nil end
    dots = {}
    local safeTag = string.gsub(unitTag or "unknown", "[^%w]", "")
    for i = 1, 800 do
        local dot = WM:CreateControl("RadiantRangeGroupFacingDot" .. safeTag .. i, PGT.root, CT_TEXTURE)
        dot:Create3DRenderSpace()
        dot:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
        dot:Set3DRenderSpaceUsesDepthBuffer(true)
        dot:SetTexture(STONE_TEXTURE)
        dot:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
        dot:Set3DRenderSpaceOrientation(rad(90), 0, 0)
        dot:Set3DLocalDimensions(0.17, 0.17)
        dot:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        dot:SetHidden(true)
        dots[i] = dot
    end
    PGT.groupFacingDots[unitTag] = dots
    return dots
end

local function updateGroupForwardArea(unitTag, data, worldX, worldY, worldZ)
    local dots = getGroupFacingDots(unitTag)
    if not dots then return end
    local zoneId = select(1, GetRawWorldPosition(unitTag))
    local _, _, apiHeading = GetMapPlayerPosition(unitTag)
    local heading = (PGT.groupHeading and PGT.groupHeading[unitTag]) or apiHeading
    if not zoneId or zoneId == 0 or heading == nil or not GetRawNormalizedWorldPosition then
        hideGroupFacingDots(unitTag); return
    end

    local mx0, mz0 = GetRawNormalizedWorldPosition(zoneId, worldX, worldY, worldZ)
    local mxx, mzx = GetRawNormalizedWorldPosition(zoneId, worldX + RAW_UNITS_PER_METER, worldY, worldZ)
    local mxz, mzz = GetRawNormalizedWorldPosition(zoneId, worldX, worldY, worldZ + RAW_UNITS_PER_METER)
    if not mx0 or not mxx or not mxz then hideGroupFacingDots(unitTag); return end
    local ax, az = mxx - mx0, mzx - mz0
    local bx, bz = mxz - mx0, mzz - mz0
    local det = ax * bz - bx * az
    if math.abs(det) < 0.000000000001 then hideGroupFacingDots(unitTag); return end

    local mapFX, mapFZ = math.sin(heading), math.cos(heading)
    local rawFX = ( bz * mapFX - bx * mapFZ) / det
    local rawFZ = (-az * mapFX + ax * mapFZ) / det
    local mag = math.sqrt(rawFX * rawFX + rawFZ * rawFZ)
    if mag <= 0 then hideGroupFacingDots(unitTag); return end
    rawFX, rawFZ = -(rawFX / mag), -(rawFZ / mag)
    local rawRX, rawRZ = -rawFZ, rawFX

    local startWidth = zo_clamp(tonumber(data.forwardStartWidth) or 3, 1, 20)
    local distance = zo_clamp(tonumber(data.forwardDistance) or 20, 1, 30)
    local endWidth = zo_clamp(tonumber(data.forwardEndWidth) or 8, 1, 20)
    local points = {}
    local function addPoint(f, side) points[#points + 1] = {f, side} end
    local spacing = 0.15
    local steps = math.max(1, math.ceil(distance / spacing))
    for i = 0, steps do
        local t = i / steps
        local f = distance * t
        local width = startWidth + (endWidth - startWidth) * t
        addPoint(f, -width * 0.5); addPoint(f, width * 0.5)
    end
    local function addCrossEdge(f, width)
        local n = math.max(1, math.ceil(width / spacing))
        for i = 1, n - 1 do addPoint(f, -width * 0.5 + width * (i / n)) end
    end
    addCrossEdge(0, startWidth); addCrossEdge(distance, endWidth)

    local r = zo_clamp((tonumber(data.red) or 62) / 100, 0, 1)
    local g = zo_clamp((tonumber(data.green) or 48) / 100, 0, 1)
    local b = zo_clamp((tonumber(data.blue) or 100) / 100, 0, 1)
    local alpha = zo_clamp((tonumber(data.intensity) or 85) / 100, 0.10, 1)
    for i, dot in ipairs(dots) do
        local pt = points[i]
        if not pt then dot:SetHidden(true) else
            local f, side = pt[1], pt[2]
            local x = worldX + (rawFX * f + rawRX * side) * RAW_UNITS_PER_METER
            local z = worldZ + (rawFZ * f + rawRZ * side) * RAW_UNITS_PER_METER
            local renderX, renderY, renderZ = WorldToRender(x, worldY + HEIGHT_OFFSET_CM, z)
            if renderX == nil then dot:SetHidden(true) else
                dot:SetColor(r, g, b, 1); dot:SetAlpha(alpha)
                dot:Set3DRenderSpaceOrigin(renderX, renderY, renderZ); dot:SetHidden(false)
            end
        end
    end
end

local function hideAllGroupGlows()
    for _, glow in pairs(PGT.groupGlows) do
        glow:SetHidden(true)
    end
end

local function getGroupGlow(unitTag)
    local glow = PGT.groupGlows[unitTag]
    if glow then return glow end
    if not PGT.root then return nil end

    local safeTag = string.gsub(unitTag or "unknown", "[^%w]", "")
    glow = WM:CreateControl("RadiantRangeGroupGlow" .. safeTag, PGT.root, CT_TEXTURE)
    glow:Create3DRenderSpace()
    glow:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
    glow:Set3DRenderSpaceUsesDepthBuffer(true)
    glow:SetTexture(GLOW_TEXTURE)
    -- Sample slightly inside the DDS edge to reduce border bleed.
    glow:SetTextureCoords(0.001, 0.999, 0.001, 0.999)
    glow:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
    -- Same verified ground-plane orientation as the player's own circle.
    glow:Set3DRenderSpaceOrientation(rad(90), 0, 0)
    glow:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    glow:SetHidden(true)

    PGT.groupGlows[unitTag] = glow
    return glow
end

local function applyGroupVisual(unitTag, data)
    if AreUnitsEqual and AreUnitsEqual(unitTag, "player") then
        local ownGlow = PGT.groupGlows[unitTag]
        if ownGlow then ownGlow:SetHidden(true) end
        return
    end

    local glow = getGroupGlow(unitTag)
    if not glow or not data then return end

    local radius = zo_clamp(tonumber(data.radius) or 12, 1, 30)
    glow:Set3DLocalDimensions(radius * 2, radius * 2)

    local r = zo_clamp((tonumber(data.red) or 62) / 100, 0, 1)
    local g = zo_clamp((tonumber(data.green) or 48) / 100, 0, 1)
    local b = zo_clamp((tonumber(data.blue) or 100) / 100, 0, 1)
    glow:SetColor(r, g, b, 1)
    glow:SetAlpha(zo_clamp((tonumber(data.intensity) or 85) / 100, 0.10, 1))
end

local function updateGroupPositions()
    if not PGT.sv or not PGT.sv.enabled or not PGT.sv.showGroupRanges or not IsUnitGrouped("player") then
        hideAllGroupGlows()
        hideAllGroupFacingDots()
        return
    end

    for unitTag, data in pairs(PGT.groupData) do
        local glow = PGT.groupGlows[unitTag]
        local isSelf = AreUnitsEqual and AreUnitsEqual(unitTag, "player")
        local choseForwardArea = data.forwardArea == true
        if isSelf or not DoesUnitExist(unitTag) or not data.visible then
            if glow then glow:SetHidden(true) end
            hideGroupFacingDots(unitTag)
        else
            local zoneId, worldX, worldY, worldZ = GetRawWorldPosition(unitTag)
            if not zoneId or zoneId == 0 or not worldX then
                if glow then glow:SetHidden(true) end
                hideGroupFacingDots(unitTag)
            elseif choseForwardArea then
                if glow then glow:SetHidden(true) end
                updateGroupForwardArea(unitTag, data, worldX, worldY, worldZ)
            else
                hideGroupFacingDots(unitTag)
                local renderX, renderY, renderZ = WorldToRender(worldX, worldY + HEIGHT_OFFSET_CM, worldZ)
                if renderX == nil then
                    if glow then glow:SetHidden(true) end
                else
                    glow = glow or getGroupGlow(unitTag)
                    applyGroupVisual(unitTag, data)
                    glow:Set3DRenderSpaceOrigin(renderX, renderY, renderZ)
                    glow:SetHidden(false)
                end
            end
        end
    end
end

sendGroupState = function(syncRequest, forceHidden)
    if not PGT.groupProtocol or not PGT.sv or not PGT.sv.shareMyRange or not IsUnitGrouped("player") then
        return
    end

    -- Master OFF is a true kill switch. Allow only one forced hidden packet
    -- when switching OFF so peers can immediately remove our old circle.
    if not PGT.sv.enabled and not forceHidden then
        return
    end

    local c = PGT.sv.color
    PGT.groupProtocol:Send({
        radius = zo_clamp(zo_round(PGT.sv.radius), 1, 30),
        red = zo_clamp(zo_round(c[1] * 100), 0, 100),
        green = zo_clamp(zo_round(c[2] * 100), 0, 100),
        blue = zo_clamp(zo_round(c[3] * 100), 0, 100),
        intensity = zo_clamp(zo_round(PGT.sv.intensity * 100), 10, 100),
        visible = forceHidden and false or shouldShow(),
        forwardArea = PGT.sv.shape == "Forward Area",
        forwardStartWidth = zo_clamp(zo_round(PGT.sv.forwardStartWidth), 1, 20),
        forwardDistance = zo_clamp(zo_round(PGT.sv.forwardDistance), 1, 30),
        forwardEndWidth = zo_clamp(zo_round(PGT.sv.forwardEndWidth), 1, 20),
        syncRequest = syncRequest == true,
    })
end


sendGroupHeading = function()
    if not PGT.groupHeadingProtocol or not PGT.sv or not PGT.sv.shareMyRange
        or not PGT.sv.enabled or PGT.sv.shape ~= "Forward Area"
        or not IsUnitGrouped("player") then
        return
    end
    local _, _, heading = GetMapPlayerPosition("player")
    if heading == nil then return end
    -- Quantize radians 0..2pi into 0..4095 (12 bits).
    local q = zo_clamp(zo_round((heading % (2 * math.pi)) * 4095 / (2 * math.pi)), 0, 4095)
    PGT.groupHeadingProtocol:Send({ heading = q })
end

local function setupGroupSharing()
    local LGB = LibGroupBroadcast
    if not LGB then
        d("|cFF5555Radiant Range: LibGroupBroadcast is required for Group Sharing.|r")
        return
    end

    local handler = LGB:RegisterHandler(ADDON_NAME, "RadiantRangeSharing")
    if not handler then
        d("|cFF5555Radiant Range: Group Sharing could not register with LibGroupBroadcast.|r")
        return
    end

    local protocol = handler:DeclareProtocol(190, "RadiantRangeGroupState")
    protocol:AddField(LGB.CreateNumericField("radius", { minValue = 1, maxValue = 30 }))
    protocol:AddField(LGB.CreateNumericField("red", { minValue = 0, maxValue = 100 }))
    protocol:AddField(LGB.CreateNumericField("green", { minValue = 0, maxValue = 100 }))
    protocol:AddField(LGB.CreateNumericField("blue", { minValue = 0, maxValue = 100 }))
    protocol:AddField(LGB.CreateNumericField("intensity", { minValue = 10, maxValue = 100 }))
    protocol:AddField(LGB.CreateFlagField("visible"))
    protocol:AddField(LGB.CreateFlagField("forwardArea"))
    protocol:AddField(LGB.CreateNumericField("forwardStartWidth", { minValue = 1, maxValue = 20 }))
    protocol:AddField(LGB.CreateNumericField("forwardDistance", { minValue = 1, maxValue = 30 }))
    protocol:AddField(LGB.CreateNumericField("forwardEndWidth", { minValue = 1, maxValue = 20 }))
    protocol:AddField(LGB.CreateFlagField("syncRequest"))

    protocol:OnData(function(unitTag, data)
        if not unitTag or unitTag == "player" or (AreUnitsEqual and AreUnitsEqual(unitTag, "player")) then return end
        -- Master OFF ignores incoming RR sharing completely.
        if not PGT.sv or not PGT.sv.enabled then return end
        PGT.groupData[unitTag] = data
        applyGroupVisual(unitTag, data)
        updateGroupPositions()

        -- "REMEMBER ME" handshake:
        -- a freshly activated/reloaded RR client requests current state;
        -- peers answer once with a normal state packet, preventing ping-pong.
        if data.syncRequest then
            zo_callLater(function()
                sendGroupState(false)
            end, 250)
        end
    end)

    protocol:Finalize({
        isRelevantInCombat = true,
        replaceQueuedMessages = true,
    })

    PGT.groupProtocol = protocol

    -- Protocol 191 is owned by Radiant Range and carries ONLY remote cone facing.
    -- Protocol 190 remains byte-for-byte compatible with the existing live state packet.
    local headingProtocol = handler:DeclareProtocol(191, "RadiantRangeConeHeading")
    headingProtocol:AddField(LGB.CreateNumericField("heading", { minValue = 0, maxValue = 4095 }))
    headingProtocol:OnData(function(unitTag, data)
        if not unitTag or unitTag == "player" or (AreUnitsEqual and AreUnitsEqual(unitTag, "player")) then return end
        if not PGT.sv or not PGT.sv.enabled then return end
        PGT.groupHeading = PGT.groupHeading or {}
        PGT.groupHeading[unitTag] = (tonumber(data.heading) or 0) * (2 * math.pi) / 4095
        local state = PGT.groupData and PGT.groupData[unitTag]
        if state and state.forwardArea then
            updateGroupPositions()
        end
    end)
    headingProtocol:Finalize({
        isRelevantInCombat = true,
        replaceQueuedMessages = true,
    })
    PGT.groupHeadingProtocol = headingProtocol

    -- Keep remote facing current while grouped; 190 remains the slower full-state heartbeat.
    EM:RegisterForUpdate(ADDON_NAME .. "GroupHeadingUpdate", 250, function()
        sendGroupHeading()
    end)

    -- Position updates are local only. Never erase valid received group state
    -- just because ESO fires EVENT_GROUP_UPDATE.
    EM:RegisterForUpdate(ADDON_NAME .. "GroupPositionUpdate", UPDATE_MS, updateGroupPositions)

    EM:RegisterForEvent(ADDON_NAME .. "GroupUpdate", EVENT_GROUP_UPDATE, function()
        if IsUnitGrouped("player") then
            zo_callLater(function()
                sendGroupState(true)
            end, 500)
        else
            -- We only clear everything when WE are no longer grouped.
            PGT.groupData = {}
            PGT.groupHeading = {}
            hideAllGroupGlows()
            hideAllGroupFacingDots()
        end
    end)

    -- Quiet safety rebroadcast. This is state only; no position is transmitted.
    EM:UnregisterForUpdate(GROUP_HEARTBEAT_NAME)
    EM:RegisterForUpdate(GROUP_HEARTBEAT_NAME, GROUP_HEARTBEAT_MS, function()
        sendGroupState(false)
    end)
end

local function createSettings()
    local panelData = {
        type = "panel",
        name = "Radiant Range |t22:22:RadiantRange/star.dds|t",
        displayName = "Radiant Range |t22:22:RadiantRange/star.dds|t",
        author = "WifeyRytic",
        version = "1.0.5",
        registerForRefresh = true,
        registerForDefaults = false,
    }

    local panel = LAM:RegisterAddonPanel(ADDON_NAME .. "Options", panelData)

    local options = {
        {
            type = "checkbox",
            name = "Enable Radiant Range",
            tooltip = "Turns the floor circle on or off for this character.",
            getFunc = function() return PGT.sv.enabled end,
            setFunc = function(value)
                if value then
                    PGT.sv.enabled = true
                    refreshRuntime()
                    -- Restore the saved sharing choices and request fresh peer state.
                    sendGroupState(true)
                else
                    PGT.sv.enabled = false
                    refreshRuntime()
                    hideAllGroupGlows()
                    hideAllGroupFacingDots()
                    PGT.groupData = {}
                    -- One final hidden state removes our circle from peers; after this,
                    -- master OFF prevents all normal RR broadcasts and receives.
                    sendGroupState(false, true)
                end
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Shape",
            tooltip = "Choose the standard range circle or a forward-facing measured area.",
            choices = SHAPE_CHOICES,
            getFunc = function() return PGT.sv.shape or "Circle" end,
            setFunc = function(value)
                PGT.sv.shape = value
                startUpdates()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Forward Start Width",
            tooltip = "Width in meters at your character. Default 3m.",
            min = 1, max = 20, step = 1,
            getFunc = function() return PGT.sv.forwardStartWidth or 3 end,
            setFunc = function(value) PGT.sv.forwardStartWidth = value; updatePosition() end,
            width = "full",
        },
        {
            type = "slider",
            name = "Forward Distance",
            tooltip = "How many meters the shape extends in front of you.",
            min = 1, max = 30, step = 1,
            getFunc = function() return PGT.sv.forwardDistance or 20 end,
            setFunc = function(value) PGT.sv.forwardDistance = value; updatePosition() end,
            width = "full",
        },
        {
            type = "slider",
            name = "Forward End Width",
            tooltip = "Width in meters across the far end of the shape.",
            min = 1, max = 20, step = 1,
            getFunc = function() return PGT.sv.forwardEndWidth or 8 end,
            setFunc = function(value) PGT.sv.forwardEndWidth = value; updatePosition() end,
            width = "full",
        },
        {
            type = "description",
            text = "Forward Area default: Start 3m / Distance 20m / End 8m. Set Start and End to the same width for a rectangular area.",
            width = "full",
        },
        {
            type = "slider",
            name = "Radius",
            tooltip = "Distance in meters from you to the outer glowing edge.",
            min = 1,
            max = 30,
            step = 1,
            getFunc = function() return PGT.sv.radius end,
            setFunc = function(value)
                PGT.sv.radius = value
                applyVisualSettings()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "description",
            text = "The selected radius is the distance from you to the outer glowing edge. 12m means a 12-meter radius, not a 12-meter-wide circle.",
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Color",
            tooltip = "Choose the circle color for this character.",
            getFunc = function()
                local c = PGT.sv.color
                return c[1], c[2], c[3], 1
            end,
            setFunc = function(r, g, b)
                PGT.sv.color = { r, g, b }
                applyVisualSettings()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Brightness / Intensity",
            tooltip = "Makes the approved glow duller or brighter without changing its design.",
            min = 10,
            max = 100,
            step = 5,
            getFunc = function() return zo_round(PGT.sv.intensity * 100) end,
            setFunc = function(value)
                PGT.sv.intensity = value / 100
                applyVisualSettings()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Show When",
            tooltip = "Choose when this character's circle should be visible.",
            choices = SHOW_CHOICES,
            getFunc = function() return PGT.sv.showWhen end,
            setFunc = function(value)
                PGT.sv.showWhen = value
                updateCombatRegistration()
                startUpdates()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "GROUP SHARING",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Share My Radiant Range",
            tooltip = "Allows group members who also have Radiant Range installed to see your circle.",
            getFunc = function() return PGT.sv.shareMyRange end,
            setFunc = function(value)
                PGT.sv.shareMyRange = value
                if value then
                    sendGroupState()
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Group Radiant Ranges",
            tooltip = "Shows circles from group members who also have Radiant Range installed and have sharing enabled.",
            getFunc = function() return PGT.sv.showGroupRanges end,
            setFunc = function(value)
                PGT.sv.showGroupRanges = value
                if not value then
                    hideAllGroupGlows()
                else
                    updateGroupPositions()
                end
            end,
            width = "full",
        },
        {
            type = "description",
            text = "Both players must have Radiant Range installed for sharing to work.",
            width = "full",
        },
        {
            type = "button",
            name = "Reset This Character",
            tooltip = "Restores only this character to the default 12m purple circle and default brightness.",
            func = function()
                copyDefaultsIntoSavedVars()
                refreshRuntime()
                sendGroupState()
                CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
            end,
            width = "half",
        },
    }

    LAM:RegisterOptionControls(ADDON_NAME .. "Options", options)
end

local function onPlayerActivated()
    setupHudFragment()
    PGT.inCombat = IsUnitInCombat("player")
    refreshRuntime()

    -- Retry local runtime after the world/HUD has settled. This is intentionally
    -- local-only startup insurance for fresh login/reload timing.
    EM:UnregisterForUpdate(STARTUP_RETRY_NAME)
    zo_callLater(function()
        PGT.inCombat = IsUnitInCombat("player")
        refreshRuntime()
    end, 750)

    -- Announce/recover automatically after login, reload, or zoning.
    zo_callLater(function()
        sendGroupState(true)
    end, 1000)
end

local function onAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- CharacterID settings, separated by megaserver so NA/EU/PTS do not overwrite each other.
    PGT.sv = ZO_SavedVars:NewCharacterIdSettings(
        SAVED_VARS_NAME,
        SAVED_VARS_VERSION,
        GetWorldName(),
        DEFAULTS
    )

    createGlow()
    applyVisualSettings()
    createSettings()
    setupGroupSharing()

    EM:RegisterForEvent(PLAYER_EVENT, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
