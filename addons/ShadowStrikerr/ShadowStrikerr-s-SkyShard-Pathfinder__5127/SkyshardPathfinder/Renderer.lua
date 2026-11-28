local addon = SkyshardPathfinder
local chevrons = {}
local noGroundPoints = {}
local terrainDepth = false
local trailWindow
local resumeWindow, resumeButton
local resumeDragEvent = "SkyshardPathfinderResumeDrag"
local distanceWindow
local distanceLabel
local headingLabel
local autoButton
local autoButtonEnabled = false
local tooltipOwner
local previousText
local dragOffsetX, dragOffsetY
local resizing
local defaultPanelWidth, minPanelWidth, maxPanelWidth = 460, 445, 1000
local dragEvent = "SkyshardPathfinderPanelDrag"
local skyshardIconTexture = "EsoUI/Art/MapPins/skyshard_seen.dds"
local textures = {
    chevron = "SkyshardPathfinder/Chevron.dds",
    arrowhead = "SkyshardPathfinder/Arrowhead.dds",
    shard = "SkyshardPathfinder/Shard.dds",
    ["flat-chevron"] = "SkyshardPathfinder/FlatChevron.dds",
    ["double-chevron"] = "SkyshardPathfinder/DoubleChevron.dds",
    ["needle-arrow"] = "SkyshardPathfinder/NeedleArrow.dds",
    eso = skyshardIconTexture,
}
local activeTexture = textures.chevron

local function clearPanelTooltip(control)
    if tooltipOwner and (not control or tooltipOwner == control) then
        tooltipOwner = nil
        ZO_Tooltips_HideTextTooltip()
    end
end

local function setPanelTooltip(control, description)
    control:SetHandler("OnMouseEnter", function()
        ZO_Tooltips_ShowTextTooltip(control, BOTTOM, description)
        tooltipOwner = control
    end)
    control:SetHandler("OnMouseExit", clearPanelTooltip)
end

function addon.GetIconTexture(style)
    return textures[style]
end
local function createChevron()
    if not trailWindow then
        trailWindow = WINDOW_MANAGER:CreateTopLevelWindow("SkyshardPathfinderTrail")
        trailWindow:SetAnchorFill(GuiRoot)
        trailWindow:SetMouseEnabled(false)
        trailWindow:SetDrawTier(DT_LOW)
        trailWindow:SetDrawLayer(DL_BACKGROUND)
        trailWindow:SetDrawLevel(0)
    end
    local control = WINDOW_MANAGER:CreateControl(nil, trailWindow, CT_TEXTURE)
    control:SetHidden(true)
    control:SetTexture(activeTexture)
    control:Create3DRenderSpace()
    control:SetDrawLevel(1)
    control:Set3DRenderSpaceUsesDepthBuffer(terrainDepth)
    control:Set3DLocalDimensions(1.65, 1.65)
    return control
end

function addon.SetIconStyle(style)
    local texture = textures[style]
    if not texture then return false end

    activeTexture = texture
    for _, control in ipairs(chevrons) do
        control:SetTexture(activeTexture)
    end
    return true
end

local function stopPanelDrag()
    if not dragOffsetX and not resizing then return end
    distanceWindow:SetHandler("OnUpdate", nil)
    EVENT_MANAGER:UnregisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP)
    dragOffsetX, dragOffsetY, resizing = nil, nil, nil
end

function addon.HideTrail()
    stopPanelDrag()
    clearPanelTooltip()
    if distanceWindow then distanceWindow:SetHidden(true) end
    for _, control in ipairs(chevrons) do
        control:SetHidden(true)
    end
end

function addon.EnablePanelMove()
    if not distanceWindow or distanceWindow:IsHidden() then return false end
    SetGameCameraUIMode(true)
    return true
end

function addon.GetTrailColor(trail, palette)
    local color = palette.near
    if trail.collected then return palette.collected end
    if trail.distance > 500 then return palette.far end
    if trail.distance > 100 then return palette.middle end
    return color
end

local function createPanelButton(name, text, width, offset, description, onClick, parent)
    parent = parent or distanceWindow
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:SetDimensions(width, 26)
    button:SetAnchor(TOPRIGHT, parent, TOPRIGHT, offset, 4)
    button:SetDrawLayer(DL_OVERLAY)
    button:SetFont("ZoFontGameOutline")
    button:SetNormalFontColor(.94, .97, 1, 1)
    button:SetMouseOverFontColor(.58, .95, 1, 1)
    button:SetDisabledFontColor(.66, .73, .80, 1)
    button:SetText(text)
    button:SetMouseEnabled(true)
    setPanelTooltip(button, description)
    button:SetHandler("OnClicked", function()
        clearPanelTooltip(button)
        onClick()
    end)
    local fill = WINDOW_MANAGER:CreateControl(nil, button, CT_BACKDROP)
    fill:SetAnchorFill(button)
    fill:SetDrawLayer(DL_BACKGROUND)
    fill:SetCenterColor(.13, .21, .28, 1)
    fill:SetEdgeColor(.35, .51, .60, 1)
    fill:SetEdgeTexture(nil, 1, 1, 1)
    return button
end

function addon.ShowResumeIcon(show, position)
    if show and not resumeWindow then
        resumeWindow = WINDOW_MANAGER:CreateTopLevelWindow("SkyshardPathfinderPaused")
        resumeWindow:SetDimensions(40, 34)
        resumeWindow:SetDrawTier(DT_MEDIUM)
        resumeWindow:SetClampedToScreen(true)
        local moved
        resumeButton = createPanelButton("SkyshardPathfinderResume", "", 34, -3,
            "Click to reopen the distance panel. Drag to move it.", function()
            if not moved then addon.SetCollapsed(false) end
        end, resumeWindow)
        resumeButton:SetHandler("OnMouseDown", function(_, button)
            if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            clearPanelTooltip(resumeButton)
            moved = false
            local startX, startY = GetUIMousePosition()
            local left = resumeWindow:GetLeft() - GuiRoot:GetLeft()
            local top = resumeWindow:GetTop() - GuiRoot:GetTop()
            resumeWindow:SetHandler("OnUpdate", function()
                local x, y = GetUIMousePosition()
                local dx, dy = x - startX, y - startY
                if not moved and dx * dx + dy * dy < 16 then return end
                moved = true
                resumeWindow:ClearAnchors()
                resumeWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left + dx, top + dy)
            end)
            EVENT_MANAGER:RegisterForEvent(resumeDragEvent, EVENT_GLOBAL_MOUSE_UP, function(_, released)
                if released ~= MOUSE_BUTTON_INDEX_LEFT then return end
                resumeWindow:SetHandler("OnUpdate", nil)
                EVENT_MANAGER:UnregisterForEvent(resumeDragEvent, EVENT_GLOBAL_MOUSE_UP)
                if moved then
                    position.x = resumeWindow:GetLeft() - GuiRoot:GetLeft()
                    position.y = resumeWindow:GetTop() - GuiRoot:GetTop()
                    if distanceWindow then
                        distanceWindow:ClearAnchors()
                        distanceWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)
                    end
                end
            end)
        end)
        local icon = WINDOW_MANAGER:CreateControl(nil, resumeButton, CT_TEXTURE)
        icon:SetDimensions(23, 23)
        icon:SetAnchor(CENTER, resumeButton, CENTER)
        icon:SetDrawLayer(DL_OVERLAY)
        icon:SetTexture(skyshardIconTexture)
        icon:SetMouseEnabled(false)
        local fragment = ZO_SimpleSceneFragment:New(resumeWindow)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
    end
    if not resumeWindow then return end
    if show then
        resumeWindow:ClearAnchors()
        if position.x and position.y then
            resumeWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)
        else
            resumeWindow:SetAnchor(TOPRIGHT, GuiRoot, TOP, -35, 135)
        end
    end
    if not show then
        clearPanelTooltip(resumeButton)
        resumeWindow:SetHandler("OnUpdate", nil)
        EVENT_MANAGER:UnregisterForEvent(resumeDragEvent, EVENT_GLOBAL_MOUSE_UP)
    end
    resumeButton:SetHidden(not show)
end

local function showDistances(lines, settings, hasTarget)
    local position = settings.distancePanelPosition
    if #lines == 0 or settings.showDistancePanel == false then
        stopPanelDrag()
        if distanceWindow and not distanceWindow:IsHidden() then clearPanelTooltip() end
        if distanceWindow then distanceWindow:SetHidden(true) end
        return
    end
    if not distanceLabel then
        distanceWindow = WINDOW_MANAGER:CreateTopLevelWindow("SkyshardPathfinderDistances")
        if position.x and position.y then
            distanceWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)
        else
            distanceWindow:SetAnchor(TOPRIGHT, GuiRoot, TOP, -35, 135)
        end
        distanceWindow:SetDrawTier(DT_MEDIUM)
        distanceWindow:SetDrawLayer(DL_OVERLAY)
        distanceWindow:SetMouseEnabled(true)
        distanceWindow:SetClampedToScreen(true)
        distanceWindow:SetDimensions(math.max(minPanelWidth, position.width or defaultPanelWidth), 58)

        local background = WINDOW_MANAGER:CreateControl(nil, distanceWindow, CT_BACKDROP)
        background:SetAnchorFill(distanceWindow)
        background:SetCenterColor(.025, .055, .075, .94)
        background:SetEdgeColor(.26, .49, .56, 1)
        background:SetEdgeTexture(nil, 1, 1, 1)
        background:SetDrawLayer(DL_BACKGROUND)
        background:SetMouseEnabled(false)

        local header = WINDOW_MANAGER:CreateControl(nil, distanceWindow, CT_CONTROL)
        header:SetAnchor(TOPLEFT, distanceWindow, TOPLEFT)
        header:SetAnchor(TOPRIGHT, distanceWindow, TOPRIGHT)
        header:SetHeight(33)
        header:SetMouseEnabled(true)
        header:SetHandler("OnMouseDown", function(_, button)
            if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            stopPanelDrag()
            local mouseX, mouseY = GetUIMousePosition()
            dragOffsetX = distanceWindow:GetLeft() - mouseX
            dragOffsetY = distanceWindow:GetTop() - mouseY
            distanceWindow:SetHandler("OnUpdate", function()
                local x, y = GetUIMousePosition()
                distanceWindow:ClearAnchors()
                distanceWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
                    x + dragOffsetX - GuiRoot:GetLeft(), y + dragOffsetY - GuiRoot:GetTop())
            end)
            EVENT_MANAGER:RegisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP, function(_, released)
                if released ~= MOUSE_BUTTON_INDEX_LEFT then return end
                position.x = distanceWindow:GetLeft() - GuiRoot:GetLeft()
                position.y = distanceWindow:GetTop() - GuiRoot:GetTop()
                stopPanelDrag()
            end)
        end)

        local collapseButton = createPanelButton("SkyshardPathfinderCollapse", "", 34, 0,
            "Collapse the distance panel and pause SkyShard guidance.", function()
            addon.SetCollapsed(true)
        end, header)
        collapseButton:ClearAnchors()
        collapseButton:SetAnchor(TOPLEFT, header, TOPLEFT, 3, 4)
        local headingIcon = WINDOW_MANAGER:CreateControl("SkyshardPathfinderHeadingIcon", collapseButton, CT_TEXTURE)
        headingIcon:SetDimensions(23, 23)
        headingIcon:SetAnchor(CENTER, collapseButton, CENTER)
        headingIcon:SetDrawLayer(DL_OVERLAY)
        headingIcon:SetTexture(skyshardIconTexture)
        headingIcon:SetColor(123 / 255, 230 / 255, 237 / 255, 1)
        headingIcon:SetMouseEnabled(false)

        headingLabel = WINDOW_MANAGER:CreateControl(nil, header, CT_LABEL)
        headingLabel:SetFont("ZoFontGameOutline")
        headingLabel:SetAnchor(LEFT, collapseButton, RIGHT, 5, 0)
        headingLabel:SetMouseEnabled(false)
        distanceLabel = WINDOW_MANAGER:CreateControl(nil, distanceWindow, CT_LABEL)
        distanceLabel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 12, 2)
        distanceLabel:SetFont("ZoFontGame")
        distanceLabel:SetWidth((math.max(minPanelWidth, position.width or defaultPanelWidth)) - 24)
        distanceLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        distanceLabel:SetColor(1, 1, 1, 1)
        distanceLabel:SetMouseEnabled(false)

        autoButton = createPanelButton("SkyshardPathfinderDistanceAutoButton",
            "Auto SkyShards", 122, -104, "Clear the selected SkyShard and resume automatic guidance.",
            function() addon.ClearSelectedShard() end)
        autoButton:SetEnabled(false)
        createPanelButton("SkyshardPathfinderDistanceSettingsButton", "Settings", 66, -35,
            "Open SkyShard Pathfinder settings.", function()
            if addon.OpenSettings then
                addon.OpenSettings()
            else
                d("[SkyShard Pathfinder] Settings requires LibAddonMenu-2.0.")
            end
        end)

        createPanelButton("SkyshardPathfinderDistanceCloseButton", "\195\151", 26, -6,
            "Close the distance panel. Turn it back on in settings.", function()
            settings.showDistancePanel = false
            stopPanelDrag()
            distanceWindow:SetHidden(true)
        end)

        local grip = WINDOW_MANAGER:CreateControl("SkyshardPathfinderResizeGrip", distanceWindow, CT_LABEL)
        grip:SetDimensions(21, 19)
        grip:SetAnchor(BOTTOMRIGHT, distanceWindow, BOTTOMRIGHT, -3, -1)
        grip:SetFont("ZoFontGameOutline")
        grip:SetText("//")
        grip:SetColor(.45, .7, .75, 1)
        grip:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        grip:SetMouseEnabled(true)
        setPanelTooltip(grip, "Drag to resize the distance panel.")
        grip:SetHandler("OnMouseDown", function(_, button)
            if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            clearPanelTooltip(grip)
            stopPanelDrag()
            resizing = true
            local startX = GetUIMousePosition()
            local startWidth = math.max(minPanelWidth, position.width or defaultPanelWidth)
            position.x = distanceWindow:GetLeft() - GuiRoot:GetLeft()
            position.y = distanceWindow:GetTop() - GuiRoot:GetTop()
            distanceWindow:ClearAnchors()
            distanceWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)
            local available = GuiRoot:GetWidth() - position.x
            local limit = math.max(minPanelWidth, math.min(maxPanelWidth, available))
            distanceWindow:SetHandler("OnUpdate", function()
                local mouseX = GetUIMousePosition()
                local width = math.floor(math.max(minPanelWidth, math.min(limit, startWidth + mouseX - startX)))
                if width == position.width then return end
                position.width = width
                distanceWindow:SetWidth(width)
                distanceLabel:SetWidth(width - 24)
                distanceWindow:SetHeight(distanceLabel:GetTextHeight() + 46)
            end)
            EVENT_MANAGER:RegisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP, function(_, released)
                if released == MOUSE_BUTTON_INDEX_LEFT then stopPanelDrag() end
            end)
        end)
    end
    local heading = "|c7be6edSkyShard Pathfinder|r"
    if heading ~= headingLabel:GetText() then headingLabel:SetText(heading) end
    local label = table.concat(lines, "\n")
    if settings.includeCollectedInTrails and not hasTarget then
        label = "|cf5d179Includes collected|r\n" .. label
    end
    local enableAuto = hasTarget == true
    if enableAuto ~= autoButtonEnabled then
        autoButtonEnabled = enableAuto
        autoButton:SetEnabled(enableAuto)
    end
    if label ~= previousText then
        distanceLabel:SetText(label)
        distanceWindow:SetHeight(distanceLabel:GetTextHeight() + 46)
        previousText = label
    end
    distanceWindow:SetHidden(false)
end

function addon.RenderTrails(trails, settings, unavailableTarget, idleMessage)
    local inDungeon = (IsUnitInDungeon and IsUnitInDungeon("player"))
        or (GetMapContentType and GetMapContentType() == MAP_CONTENT_DUNGEON)
    local useDepth = settings.visibleThroughTerrain == false
    if useDepth ~= terrainDepth then
        terrainDepth = useDepth
        for _, control in ipairs(chevrons) do
            control:Set3DRenderSpaceUsesDepthBuffer(terrainDepth)
        end
    end
    local used, lines = 0, {}
    for _, trail in ipairs(trails) do
        local color = addon.GetTrailColor(trail, settings.groundColors)
        if not settings.arrowsOnly then
            local indicator = trail.collected and "Collected" or string.format("%.0f m", trail.distance)
            lines[#lines + 1] = string.format("|c%02x%02x%02x%s|r  %s%s",
                zo_round(color[1] * 255), zo_round(color[2] * 255), zo_round(color[3] * 255),
                indicator, trail.hint or (trail.collected and "SkyShard" or "Test point"),
                trail.alreadyCollected and not trail.collected and "  |c9db9c4[Done]|r" or "")
            if trail.selected then
                lines[#lines] = lines[#lines] .. "  |cf5d179[Following]|r"
                local detail = trail.target and trail.target.detail
                if detail and detail ~= "" then
                    lines[#lines + 1] = "    |cbfdfe6" .. detail .. "|r"
                end
            end
            if trail.routeNote then lines[#lines + 1] = "    |c9db9c4" .. trail.routeNote .. "|r" end
        end
        for _, point in ipairs(inDungeon and noGroundPoints or trail.points) do
            used = used + 1
            local control = chevrons[used]
            if not control then
                control = createChevron()
                chevrons[used] = control
            end
            local x, y, z = WorldPositionToGuiRender3DPosition(
                zo_round(point.x), point.y, zo_round(point.z))
            control:Set3DRenderSpaceOrigin(x, y, z)
            control:Set3DRenderSpaceOrientation(-math.pi / 2, point.yaw or trail.yaw, 0)
            local size = trail.secondary and 1.25 or 1.65
            control:Set3DLocalDimensions(size, size)
            control:SetColor(color[1], color[2], color[3], point.alpha * (trail.secondary and .75 or 1))
            control:SetHidden(false)
        end
    end

    for index = used + 1, #chevrons do
        chevrons[index]:SetHidden(true)
    end
    if #lines == 0 and not settings.arrowsOnly then
        if unavailableTarget then
            lines[1] = "Selected SkyShard is unavailable on this map."
        elseif idleMessage then
            lines[1] = idleMessage
        end
    end
    local hasTarget = unavailableTarget or (trails[1] and trails[1].selected)
    showDistances(lines, settings, hasTarget)
end
