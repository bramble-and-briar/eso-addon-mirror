local A = OneMap
local PAUSE_MS, INPUT_GAP_MS = 200, 900
local FADE_OUT_MS, FADE_IN_MS = 120, 160

function A:CancelSmoothScroll()
    local wasFading = self.scrollFade ~= nil
    self.scrollBoundary, self.scrollFade = nil, nil
    EVENT_MANAGER:UnregisterForUpdate("OneMapScrollFade")
    if wasFading then ZO_WorldMapContainer:SetAlpha(1) end
end

function A:GetScrollTarget()
    local x, y = NormalizeMousePositionToControl(ZO_WorldMapContainer)
    local canEnter, mapIndex = WouldProcessMapClick(x, y)
    if canEnter and mapIndex then return GetMapIdByIndex(mapIndex) end
    -- City/subzone overlays may expose a map ID without a map-list index.
    local name, _, _, _, _, _, mapId = GetMapMouseoverInfo(x, y)
    if name and name ~= "" and mapId and mapId > 0 and mapId ~= GetCurrentMapId() then
        local _, mapType = GetMapInfoById(mapId)
        if mapType == MAPTYPE_SUBZONE then return mapId end
    end
end

function A:CanContinueScroll(state)
    return self.saved.smoothScroll and self:CanUseMap() and MouseIsOver(ZO_WorldMapScroll)
        and GetCurrentMapId() == state.mapId
        and not (IsControlKeyDown() or IsAltKeyDown())
        and WORLD_MAP_MANAGER:IsMapChangingAllowed(state.direction)
        and (state.direction > 0 or self:CanScrollOut())
        and (state.direction < 0 or self:GetScrollTarget() == state.target)
end

function A:CanScrollOut()
    return GetMapType() ~= MAPTYPE_COSMIC
end

function A:StartScrollTransition(boundary)
    self.scrollBoundary = nil
    self.scrollFade = { mapId = boundary.mapId, direction = boundary.direction,
        target = boundary.target, started = GetFrameTimeMilliseconds() }
    EVENT_MANAGER:RegisterForUpdate("OneMapScrollFade", 16, function() self:UpdateScrollTransition() end)
end

function A:UpdateScrollTransition()
    local state = self.scrollFade
    if not state then return end
    local elapsed = GetFrameTimeMilliseconds() - state.started
    if not state.switched then
        -- Revalidate the map under the cursor before native map navigation.
        -- No pin handler or travel action is invoked here.
        if not self:CanContinueScroll(state) then self:CancelSmoothScroll(); return end
        if elapsed < FADE_OUT_MS then
            ZO_WorldMapContainer:SetAlpha(1 - elapsed / FADE_OUT_MS)
            return
        end
        self.scrollChangingMap = true
        if state.direction > 0 then
            WORLD_MAP_MANAGER:SetMapById(state.target)
        else
            ZO_WorldMap_MouseUp(ZO_WorldMapContainer, MOUSE_BUTTON_INDEX_RIGHT, true)
        end
        self.scrollChangingMap = false
        if GetCurrentMapId() == state.mapId then self:CancelSmoothScroll(); return end
        state.mapId, state.switched, state.started = GetCurrentMapId(), true, GetFrameTimeMilliseconds()
        ZO_WorldMapContainer:SetAlpha(0)
    else
        if not self.saved.smoothScroll or not self:IsKeyboardMap() or GetCurrentMapId() ~= state.mapId then
            self:CancelSmoothScroll(); return
        end
        if elapsed >= FADE_IN_MS then self:CancelSmoothScroll()
        else ZO_WorldMapContainer:SetAlpha(elapsed / FADE_IN_MS) end
    end
end

function A:HandleSmoothScroll(delta)
    if not self.saved.smoothScroll or not self:CanUseMap() or not MouseIsOver(ZO_WorldMapScroll)
        or delta == 0 or IsControlKeyDown() or IsAltKeyDown() then
        self:CancelSmoothScroll()
        return
    end
    if self.scrollFade then return true end
    local direction = delta > 0 and 1 or -1
    if not WORLD_MAP_MANAGER:IsMapChangingAllowed(direction) then self.scrollBoundary = nil; return true end
    local zoom = ZO_WorldMap_GetPanAndZoom()
    local minimum, maximum = zoom:GetZoomMinMax()
    local hasZoomRange = zoom:CanMapZoom() and maximum > minimum + 0.001
    -- Native zoom approaches its target asymptotically. Waiting for the rendered
    -- position to settle adds seconds, especially when zooming in. Start the
    -- same boundary pause in either direction as soon as the requested zoom
    -- reaches its limit, while the native interpolation continues rendering.
    local position = zoom.targetNormalizedZoom or zoom:GetCurrentNormalizedZoom()
    local atBoundary = not hasZoomRange
        or (direction > 0 and position >= 0.999 or direction < 0 and position <= 0.001)
    if not atBoundary then
        self.scrollBoundary = nil
        return -- Native AddZoomDelta already uses smooth, cursor-locked interpolation.
    end
    if direction < 0 and not self:CanScrollOut() then
        self.scrollBoundary = nil
        return true -- The cosmic map has no outward transition or fade.
    end
    local target = direction > 0 and self:GetScrollTarget() or nil
    if direction > 0 and not target then self.scrollBoundary = nil; return true end
    local now, mapId = GetFrameTimeMilliseconds(), GetCurrentMapId()
    local boundary = self.scrollBoundary
    if not boundary or boundary.direction ~= direction or boundary.target ~= target
        or boundary.mapId ~= mapId or now - boundary.lastInput > INPUT_GAP_MS then
        self.scrollBoundary = { direction = direction, target = target, mapId = mapId, started = now, lastInput = now }
    else
        boundary.lastInput = now
        if now - boundary.started >= PAUSE_MS then self:StartScrollTransition(boundary) end
    end
    return true
end

function A:InitializeScroll()
    ZO_PreHook("ZO_WorldMap_MouseWheel", function(delta) return self:HandleSmoothScroll(delta) end)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        if not self.scrollChangingMap then self:CancelSmoothScroll() end
    end)
    SCENE_MANAGER:GetScene("worldMap"):RegisterCallback("StateChange", function()
        if not self:IsKeyboardMap() then self:CancelSmoothScroll() end
    end)
end
