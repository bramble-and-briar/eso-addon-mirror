local CS = ClearSight

function CS:CreateWingedWayfinder(name, parent)
    local root = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    root:SetMouseEnabled(false)
    root.wings = {}
    local points = {
        {{.5,0},{.5,.65},{0,1}},
        {{.5,0},{1,1},{.5,.65}},
    }
    for i = 1, 2 do
        local wing = WINDOW_MANAGER:CreateControl(name .. i, root, CT_POLYGON)
        wing:SetAnchorFill(root)
        wing:SetDrawLayer(DL_OVERLAY)
        wing:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
        for _, point in ipairs(points[i]) do wing:AddPoint(point[1],point[2]) end
        wing:SetCenterColor(1,1,1,1)
        wing:SetBorderDirection(POLYGON_BORDER_DIRECTION_OUT)
        wing:SetBorderThickness(1,1,1)
        root.wings[i] = wing
    end
    root:SetHidden(true)
    return root
end

function CS:DrawWingedWayfinder(root, x, y, size, rotation, relative, baseColor)
    local s = self.saved.waypoint
    local left, right = baseColor, baseColor
    if math.abs(relative*180/math.pi) > s.amberThresholdDegrees then
        -- The relative bearing used by reticle navigation is positive left.
        if relative > 0 then left = s.amberColor else right = s.amberColor end
    end
    root:ClearAnchors()
    root:SetAnchor(CENTER, root:GetParent(), CENTER, x, y)
    root:SetDimensions(size,size)
    root:SetTransformRotationZ(rotation)
    for i, color in ipairs({left,right}) do
        local wing = root.wings[i]
        wing:SetCenterColor(color[1],color[2],color[3],s.opacity or color[4] or 1)
        local edge = color[1]+color[2]+color[3] < .5 and 1 or 0
        wing:SetBorderColor(edge,edge,edge,1)
    end
    root:SetHidden(false)
end
