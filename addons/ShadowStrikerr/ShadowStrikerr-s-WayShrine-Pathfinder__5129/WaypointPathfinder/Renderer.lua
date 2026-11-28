local addon = ShadowStrikerrWaypointPathfinder
local namespace = "ShadowStrikerrWaypointPathfinder"
local arrows, scene, texture, depth = {}
local manager = WINDOW_MANAGER

function addon.GetTrailColor(trail, palette)
    if trail.distance > 500 then return palette.far end
    if trail.distance > 100 then return palette.middle end
    return palette.near
end

function addon.HideGround()
    if scene then scene:SetHidden(true) end
end

function addon.DrawGround(trails, settings)
    if not trails or #trails == 0 then return addon.HideGround() end
    if not scene then
        scene = manager:CreateTopLevelWindow(namespace .. "Ground")
        scene:SetAnchorFill(GuiRoot)
        scene:SetMouseEnabled(false)
        scene:SetDrawTier(DT_LOW)
        scene:SetDrawLayer(DL_BACKGROUND)
    end
    local currentTexture = "WaypointPathfinder/" .. settings.icon .. ".dds"
    local currentDepth = not settings.visibleThroughTerrain
    local used = 0
    for _, trail in ipairs(trails) do
        local color = addon.GetTrailColor(trail, settings.groundColors)
        for _, point in ipairs(trail.points) do
            used = used + 1
            local control = arrows[used]
            if not control then
                control = manager:CreateControl(nil, scene, CT_TEXTURE)
                control:SetMouseEnabled(false)
                control:Create3DRenderSpace()
                control:Set3DLocalDimensions(1.65, 1.65)
                arrows[used] = control
                control:SetTexture(currentTexture)
                control:Set3DRenderSpaceUsesDepthBuffer(currentDepth)
            else
                if texture ~= currentTexture then control:SetTexture(currentTexture) end
                if depth ~= currentDepth then control:Set3DRenderSpaceUsesDepthBuffer(currentDepth) end
            end
            local x, y, z = WorldPositionToGuiRender3DPosition(zo_round(point.x), point.y, zo_round(point.z))
            control:Set3DRenderSpaceOrigin(x, y, z)
            control:Set3DRenderSpaceOrientation(-math.pi / 2, point.yaw or trail.yaw, 0)
            control:SetColor(color[1], color[2], color[3], point.alpha)
            control:SetHidden(false)
        end
    end
    -- Hidden controls can outlive a style change. Keep their appearance current as well.
    for index = used + 1, #arrows do
        local control = arrows[index]
        if texture ~= currentTexture then control:SetTexture(currentTexture) end
        if depth ~= currentDepth then control:Set3DRenderSpaceUsesDepthBuffer(currentDepth) end
        control:SetHidden(true)
    end
    texture, depth = currentTexture, currentDepth
    scene:SetHidden(used == 0)
end
