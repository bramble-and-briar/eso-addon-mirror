local CS = ClearSight

local TWO_PI = math.pi * 2
local PI = math.pi

local function NormalizeRadians(value)
    while value > PI do value = value - TWO_PI end
    while value < -PI do value = value + TWO_PI end
    return value
end

local function Degrees(value)
    return math.abs(value * 180 / PI)
end

local function SetSolidColor(control, color, alpha)
    control:SetCenterColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function IsStockHudVisible()
    -- The reticle is hidden for menus, interaction cameras and most non-gameplay
    -- scenes. Use it as the first stock HUD signal.
    if IsReticleHidden and IsReticleHidden() then
        return false
    end

    -- Mirror the compass itself as well. IsControlHidden includes inherited
    -- visibility from scene fragments, which is exactly what ClearSight needs.
    local compass = ZO_Compass or ZO_CompassFrame
    if compass then
        if compass.IsControlHidden and compass:IsControlHidden() then
            return false
        end
        if compass.GetAlpha and compass:GetAlpha() <= 0.01 then
            return false
        end
    end

    return true
end

local function GetPlayerWaypointColor(self)
    if not GetSetting
        or not SETTING_TYPE_ACCESSIBILITY
        or not ACCESSIBILITY_SETTING_PLAYER_WAYPOINT_ICON_COLOR
        or not ZO_ColorDef then
        return nil
    end

    local settingValue = GetSetting(SETTING_TYPE_ACCESSIBILITY, ACCESSIBILITY_SETTING_PLAYER_WAYPOINT_ICON_COLOR)
    if not settingValue or settingValue == "" then
        return nil
    end

    -- Avoid rebuilding the colour object every 100ms while still reacting if the
    -- player changes their Accessibility > Player Waypoint colour in settings.
    if self.cachedWaypointColorSetting ~= settingValue then
        local color = ZO_ColorDef:New(settingValue)
        if color then
            local r, g, b = color:UnpackRGB()
            self.cachedWaypointColor = { r, g, b, 1 }
            self.cachedWaypointColorSetting = settingValue
        end
    end

    return self.cachedWaypointColor
end


local function IsCompassDistanceTrackingEnabled()
    if not SETTING_TYPE_UI or not UI_SETTING_COMPASS_DISTANCE_TRACKING then
        return false
    end

    if GetSetting_Bool then
        return GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_COMPASS_DISTANCE_TRACKING)
    end

    if GetSetting then
        return tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_COMPASS_DISTANCE_TRACKING)) ~= 0
    end

    return false
end

local function GetStockWaypointPinState()
    if not IsCompassDistanceTrackingEnabled() then
        return nil
    end

    -- ZO_CompassContainer is ESO's native CompassDisplayControl. Keep the stock
    -- Compass object's container as a fallback in case the XML global changes.
    local container = ZO_CompassContainer or (COMPASS and COMPASS.container)
    if not container or not container.GetNumCenterOveredPins then
        return nil
    end

    for index = 1, container:GetNumCenterOveredPins() do
        local description, pinType, distanceFromPlayerCM, suppressed
        local drawLayer, drawLevel

        if container.GetCenterOveredPinInfo then
            description, pinType, distanceFromPlayerCM, drawLayer, drawLevel, suppressed =
                container:GetCenterOveredPinInfo(index)
        else
            description = container:GetCenterOveredPinDescription(index)
            pinType = container:GetCenterOveredPinType(index)
            distanceFromPlayerCM = container.GetCenterOveredPinDistance
                and container:GetCenterOveredPinDistance(index)
                or nil
            suppressed = container.IsCenterOveredPinSuppressed
                and container:IsCenterOveredPinSuppressed(index)
                or false
        end

        if pinType == MAP_PIN_TYPE_PLAYER_WAYPOINT and not suppressed then
            return {
                trackerVisible = description ~= nil and description ~= "",
                distanceCM = distanceFromPlayerCM,
            }
        end
    end

    return nil
end

local function ResetStockWaypointArrivalState(self)
    self.stockWaypointArrivalX = nil
    self.stockWaypointArrivalZ = nil
    self.stockWaypointTrackerWasVisible = nil
    self.stockWaypointLastSeenDistanceCM = nil
    self.stockWaypointArrivalStartedAtMs = nil
end

local function ResetStockWaypointArrivalHold(self)
    self.stockWaypointArrivalStartedAtMs = nil
end

local function GetArrivalClockMilliseconds()
    if GetFrameTimeMilliseconds then
        return GetFrameTimeMilliseconds()
    end
    if GetGameTimeMilliseconds then
        return GetGameTimeMilliseconds()
    end
    return 0
end

local function HasStockWaypointReachedArrival(self, waypointX, waypointZ)
    if not IsCompassDistanceTrackingEnabled() then
        ResetStockWaypointArrivalState(self)
        return false
    end

    if self.stockWaypointArrivalX ~= waypointX or self.stockWaypointArrivalZ ~= waypointZ then
        self.stockWaypointArrivalX = waypointX
        self.stockWaypointArrivalZ = waypointZ
        self.stockWaypointTrackerWasVisible = nil
        self.stockWaypointLastSeenDistanceCM = nil
        ResetStockWaypointArrivalHold(self)
    end

    local pinState = GetStockWaypointPinState()
    local inNativeArrivalState = false

    if pinState then
        if pinState.distanceCM ~= nil then
            self.stockWaypointLastSeenDistanceCM = pinState.distanceCM
        end

        if pinState.trackerVisible then
            self.stockWaypointTrackerWasVisible = true
            ResetStockWaypointArrivalHold(self)
            return false
        end

        -- ESO restores its distance tracker after moving back out to roughly 11m.
        -- If the native pin still exists and reports that distance, this is not a
        -- stable arrival and any drive-by hold must be cancelled immediately.
        if pinState.distanceCM ~= nil and pinState.distanceCM >= 1100 then
            ResetStockWaypointArrivalHold(self)
            return false
        end

        inNativeArrivalState = self.stockWaypointTrackerWasVisible
            or (pinState.distanceCM ~= nil and pinState.distanceCM <= 1000)
    else
        -- At the native arrival threshold ESO can remove the player waypoint from
        -- the compass control's centre-overed pin list at the same moment it hides
        -- the distance text. The previous build treated that as a lost target and
        -- reset forever. Continue the hold only when the last native reading had
        -- already placed this same waypoint inside the 11m hysteresis boundary.
        local lastDistanceCM = self.stockWaypointLastSeenDistanceCM
        inNativeArrivalState = self.stockWaypointTrackerWasVisible
            and lastDistanceCM ~= nil
            and lastDistanceCM < 1100
    end

    if not inNativeArrivalState then
        ResetStockWaypointArrivalHold(self)
        return false
    end

    -- Drive-by prevention: the stock arrived state must remain continuously true
    -- for 1.5 seconds. If the native pin/distance tracker reappears as the player
    -- rides away, the visible or >=11m branches above cancel this hold.
    local nowMs = GetArrivalClockMilliseconds()
    if not self.stockWaypointArrivalStartedAtMs then
        self.stockWaypointArrivalStartedAtMs = nowMs
        return false
    end

    return (nowMs - self.stockWaypointArrivalStartedAtMs) >= 1500
end

local function RemoveStockPlayerWaypoint()
    -- Match the exact R3 "Remove Destination" path used by ESO's gamepad map.
    -- The wrapper removes the waypoint and also clears the map pin's hover state.
    if ZO_WorldMap_RemovePlayerWaypoint then
        ZO_WorldMap_RemovePlayerWaypoint()
        return true
    end

    -- Fallback for unusual load orders where the stock world-map wrapper has not
    -- been created, while retaining compatibility with the public API function.
    if RemovePlayerWaypoint then
        RemovePlayerWaypoint()
        return true
    end

    return false
end

function CS:InitializeWaypoint()
    -- Preserve the stock PLAYER_WAYPOINT compass pin because ESO owns its
    -- distance readout. ClearSight acts as an adaptive high-visibility layer
    -- at longer range, then hands navigation back to ESO near the destination.

    local root = WINDOW_MANAGER:CreateTopLevelWindow("ClearSightWaypointOverlay")
    root:SetDimensions(600, 80)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)

    if ZO_Compass then
        root:SetAnchor(CENTER, ZO_Compass, CENTER, 0, 0)
    elseif ZO_CompassFrame then
        root:SetAnchor(CENTER, ZO_CompassFrame, CENTER, 0, 0)
    else
        root:SetAnchor(TOP, GuiRoot, TOP, 0, 28)
    end

    local marker = WINDOW_MANAGER:CreateControl("ClearSightWaypointMarker", root, CT_BACKDROP)
    marker:SetAnchor(CENTER, root, CENTER, 0, 0)
    marker:SetCenterColor(0.1, 1, 0.2, 1)
    marker:SetEdgeColor(0, 0, 0, 1)

    local edge = WINDOW_MANAGER:CreateControl("ClearSightWaypointOutline", root, CT_BACKDROP)
    edge:SetDrawLayer(DL_BACKGROUND)
    edge:SetEdgeColor(0, 0, 0, 0)
    marker:SetDrawLayer(DL_OVERLAY)
    self.mainWayfinder = self:CreateWingedWayfinder("ClearSightMainWayfinder", root)
    self.waypointOutline = edge
    self.waypointRoot = root
    self.waypointMarker = marker
end

function CS:GetWaypointNavigationData()
    if not GetMapPlayerWaypoint or not GetMapPlayerPosition or not GetPlayerCameraHeading then
        return nil
    end

    local wx, wz = GetMapPlayerWaypoint()
    if not wx or not wz or (wx == 0 and wz == 0) then
        return nil
    end

    local px, pz, _, shown = GetMapPlayerPosition("player")
    if not shown then
        return nil
    end

    local dx = wx - px
    local dz = wz - pz
    local distance = math.sqrt((dx * dx) + (dz * dz))

    if distance < 0.000001 then
        return 0, 0, wx, wz
    end

    local waypointBearing = math.atan2(dx, dz)
    local cameraHeading = GetPlayerCameraHeading()

    -- ESO's normalized map axes and compass heading run in opposite orientation
    -- for this bearing calculation. Rotate the calculated bearing by 180 degrees
    -- so ClearSight follows the same destination direction as the stock waypoint.
    local relative = NormalizeRadians(waypointBearing - cameraHeading + PI)

    return relative, distance, wx, wz
end

function CS:UpdateWaypoint()
    if not self.waypointRoot or not self.waypointMarker then return end

    local s = self.saved.waypoint
    if not s.enabled or not IsStockHudVisible() then
        self.waypointRoot:SetHidden(true)
        ResetStockWaypointArrivalState(self)
        return
    end

    local relative, distance, waypointX, waypointZ = self:GetWaypointNavigationData()
    if relative == nil then
        self.waypointRoot:SetHidden(true)
        ResetStockWaypointArrivalState(self)
        return
    end

    -- Piggyback ESO's own compass-distance arrival state. When Interface >
    -- Compass Distance Tracking is enabled, the stock waypoint distance text
    -- disappears at the game's native arrival threshold (observed at 10m).
    -- ClearSight starts a 1.5-second continuous-arrival hold at that same
    -- transition, then removes the custom waypoint if the state remains stable.
    if HasStockWaypointReachedArrival(self, waypointX, waypointZ) then
        if RemoveStockPlayerWaypoint() then
            ResetStockWaypointArrivalState(self)
            self.waypointRoot:SetHidden(true)
            return
        end
    end

    -- Handoff to ESO's stock waypoint close to the destination. The normalized
    -- thresholds are based on the same console calibration used by the previous
    -- close/arrival behaviour: ~0.006 corresponded to roughly 100m.
    local hideOverlayDistance = s.hideOverlayDistance or 0.0090
    local waypointColorDistance = math.max(s.waypointColorDistance or 0.0180, hideOverlayDistance + 0.0001)

    -- At roughly 150m, remove ClearSight's diamond completely. This leaves one
    -- unambiguous icon to follow and prevents the player chasing two nearby pins.
    if distance <= hideOverlayDistance then
        self.waypointRoot:SetHidden(true)
        return
    end

    if s.location == "Reticle" then
        self.waypointRoot:SetHidden(true)
        return
    end
    self.waypointRoot:SetHidden(false)

    -- Match the actual compass width where possible. This reduces the visual
    -- separation between ClearSight's accessibility layer and ESO's stock pin.
    local compassWidth = nil
    if ZO_Compass and ZO_Compass.GetWidth then
        compassWidth = ZO_Compass:GetWidth()
    elseif ZO_CompassFrame and ZO_CompassFrame.GetWidth then
        compassWidth = ZO_CompassFrame:GetWidth()
    end
    if compassWidth and compassWidth > 100 then
        self.waypointRoot:SetWidth(compassWidth)
    end

    local degrees = Degrees(relative)
    local targetSize, targetColor
    if degrees <= s.greenThresholdDegrees then
        targetSize, targetColor = s.baseSize, s.greenColor
    elseif degrees <= s.amberThresholdDegrees then
        targetSize, targetColor = s.amberSize, s.amberColor
    else
        targetSize, targetColor = s.redSize, s.redColor
    end

    targetColor = self:GetWaypointGuidanceColor(relative)

    -- Near roughly 300m, stop changing the diamond's colour by heading error and
    -- adopt the player's own Accessibility waypoint colour. Size and position still
    -- communicate course correction until the overlay disappears around 150m.
    if distance <= waypointColorDistance then
        targetColor = GetPlayerWaypointColor(self) or targetColor
    end

    local visibleHalfAngle = math.rad(90)
    local normalized = zo_clamp(relative / visibleHalfAngle, -1, 1)

    local halfWidth = (self.waypointRoot:GetWidth() / 2) - (targetSize / 2)
    local x = normalized * halfWidth

    self.waypointMarker:SetHidden(true)
    self.waypointOutline:SetHidden(true)
    self:DrawWingedWayfinder(self.mainWayfinder,x,0,self.saved.reticle.wayfinderSize or 40,0,relative,targetColor)

end


function CS:GetWaypointGuidanceColor(relative)
    local s = self.saved.waypoint
    local degrees = math.abs(relative * 180 / math.pi)
    if degrees <= s.greenThresholdDegrees then return s.greenColor end
    if degrees <= s.amberThresholdDegrees then return s.amberColor end
    return s.redColor
end
