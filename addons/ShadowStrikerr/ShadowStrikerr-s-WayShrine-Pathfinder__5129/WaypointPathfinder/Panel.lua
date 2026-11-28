local addon = ShadowStrikerrWaypointPathfinder
local manager = WINDOW_MANAGER
local namespace = "ShadowStrikerrWaypointPathfinder"
local panel, compact, quick, detail, routeStatus, resume, tooltipOwner, drag, quickCursor
local autoRows, extraHeight = {}, 0
local panelHeight, rowHeight = 86, 20
local dragEvent = namespace .. "Drag"

local function clearTip(control)
    if tooltipOwner and (not control or tooltipOwner == control) then
        ZO_Tooltips_HideTextTooltip()
        tooltipOwner = nil
    end
end

local function hover(control, text)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function()
        ZO_Tooltips_ShowTextTooltip(control, BOTTOM, text)
        tooltipOwner = control
    end)
    control:SetHandler("OnMouseExit", clearTip)
end

local function label(parent, text, font)
    local control = manager:CreateControl(nil, parent, CT_LABEL)
    control:SetFont(font or "ZoFontGame")
    control:SetText(text)
    return control
end

local function buttonBackdrop(control)
    local fill = manager:CreateControl(nil, control, CT_BACKDROP)
    fill:SetAnchorFill(control)
    fill:SetDrawLayer(DL_BACKGROUND)
    fill:SetCenterColor(.13, .21, .28, 1)
    fill:SetEdgeColor(.35, .51, .60, 1)
    fill:SetEdgeTexture(nil, 1, 1, 1)
    fill:SetMouseEnabled(false)
end

local function action(parent, text, tip, x, width, callback)
    local control = label(parent, text, "ZoFontGameOutline")
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDimensions(width, 26)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 5)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    buttonBackdrop(control)
    hover(control, tip)
    control:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
            clearTip(control)
            callback()
        end
    end)
    return control
end

local function window(id, position, x, y, width, height)
    local control = manager:CreateTopLevelWindow(namespace .. id)
    control:SetDrawTier(DT_MEDIUM)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetClampedToScreen(true)
    control:SetMouseEnabled(true)
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x or x, position.y or y)
    control:SetDimensions(position.w or width, position.h or height)
    control:SetHidden(true)

    local backdrop = manager:CreateControl(nil, control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetCenterColor(.025, .055, .075, .94)
    backdrop:SetEdgeTexture(nil, 1, 1, 1)
    backdrop:SetEdgeColor(.26, .49, .56, 1)
    backdrop:SetDrawLayer(DL_BACKGROUND)
    backdrop:SetMouseEnabled(false)
    return control
end

local function stopDrag()
    if not drag then return end
    drag:SetHandler("OnUpdate", nil)
    EVENT_MANAGER:UnregisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP)
    drag = nil
end

local function align(other, control)
    other:ClearAnchors()
    other:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        control:GetLeft() - GuiRoot:GetLeft(), control:GetTop() - GuiRoot:GetTop())
end

local function draggable(handle, control, position, resize, click, companion)
    handle:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        clearTip()
        stopDrag()
        drag = control
        local startX, startY = GetUIMousePosition()
        local left = control:GetLeft() - GuiRoot:GetLeft()
        local top = control:GetTop() - GuiRoot:GetTop()
        local width, height = control:GetWidth(), control:GetHeight()
        local moved = false
        control:SetHandler("OnUpdate", function()
            local mouseX, mouseY = GetUIMousePosition()
            local dx, dy = mouseX - startX, mouseY - startY
            if not moved and dx * dx + dy * dy < 16 then return end
            moved = true
            if resize then
                local maxWidth = math.max(450, math.min(720, GuiRoot:GetWidth() - left))
                local minHeight = panelHeight + extraHeight
                local maxHeight = math.max(minHeight, math.min(300, GuiRoot:GetHeight() - top))
                control:SetDimensions(math.max(450, math.min(maxWidth, width + dx)),
                    math.max(minHeight, math.min(maxHeight, height + dy)))
            else
                control:ClearAnchors()
                control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left + dx, top + dy)
            end
        end)
        EVENT_MANAGER:RegisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP, function(_, released)
            if released ~= MOUSE_BUTTON_INDEX_LEFT then return end
            stopDrag()
            if moved and resize then
                position.w, position.h = control:GetWidth(), control:GetHeight() - extraHeight
            elseif moved then
                position.x = control:GetLeft() - GuiRoot:GetLeft()
                position.y = control:GetTop() - GuiRoot:GetTop()
                if companion then align(companion, control) end
            elseif click and MouseIsOver(handle) then
                click()
            end
        end)
    end)
end

local function icon(parent, tip, callback)
    local control = manager:CreateControl(nil, parent, CT_CONTROL)
    control:SetDimensions(34, 26)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, 3, 4)
    hover(control, tip)
    control:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
            clearTip(control)
            callback()
        end
    end)
    local art = manager:CreateControl(nil, control, CT_TEXTURE)
    art:SetDimensions(23, 23)
    art:SetAnchor(CENTER, control, CENTER)
    art:SetDrawLayer(DL_OVERLAY)
    art:SetDrawLevel(2)
    art:SetTexture("EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds")
    art:SetColor(123 / 255, 230 / 255, 237 / 255, 1)
    art:SetMouseEnabled(false)
    buttonBackdrop(control)
    return control
end

local function createPanel(settings)
    local x = math.max(10, GuiRoot:GetWidth() * .5 + 35)
    panel = window("Panel", settings.panel, x, 135, 460, panelHeight)
    panel:SetWidth(math.max(450, settings.panel.w or 460))
    compact = window("Compact", { x = settings.panel.x, y = settings.panel.y }, x, 135, 40, 34)
    icon(panel, "Collapse the panel and pause guidance.", function() addon.SetCollapsed(true) end)
    local expand = icon(compact, "Click to reopen and resume. Drag to move this icon.", function() end)
    expand:SetHandler("OnMouseUp", nil)
    draggable(expand, compact, settings.panel, false, function() addon.SetCollapsed(false) end, panel)

    local title = label(panel, "|c7be6edWayShrine Pathfinder|r", "ZoFontGameOutline")
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 42, 9)
    hover(title, "Drag to move the distance panel.")
    draggable(title, panel, settings.panel, false, nil, compact)

    local close = action(panel, "×", "Close the distance panel. Guidance continues.", 0, 23, function()
        settings.showPanel = false
        addon.Refresh()
    end)
    close:ClearAnchors()
    close:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -3, 5)

    detail = label(panel, "")
    detail:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 38)
    detail:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -20, 38)
    routeStatus = label(panel, "")
    routeStatus:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 58)
    routeStatus:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -26, 58)
    local grip = label(panel, "//", "ZoFontGameOutline")
    grip:SetColor(.45, .7, .75, 1)
    grip:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    grip:SetDimensions(21, 19)
    grip:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -3, -2)
    hover(grip, "Drag to resize the distance panel.")
    draggable(grip, panel, settings.panel, true)
    local options = action(panel, "Settings", "Open WayShrine Pathfinder settings.", 0, 66, function()
        if addon.OpenSettings then addon.OpenSettings() else addon.ToggleQuickSettings() end
    end)
    options:ClearAnchors()
    options:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -35, 5)
    local auto = action(panel, "Auto Wayshrines", "Clear your personal waypoint and guide to nearby wayshrines.",
        0, 132, addon.UseAutoWayshrines)
    auto:ClearAnchors()
    auto:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -105, 5)
end

function addon.CloseQuickSettings(releaseCursor)
    if not quick or quick:IsHidden() then return end
    clearTip()
    quick:SetHidden(true)
    if releaseCursor and quickCursor and HUD_UI_SCENE:IsShowing() and addon.IsHud() then
        SetGameCameraUIMode(false)
    end
    quickCursor = false
end

function addon.HidePanels()
    clearTip()
    stopDrag()
    if panel then panel:SetHidden(true) end
    if compact then compact:SetHidden(true) end
    addon.CloseQuickSettings(false)
end

local function colorDistance(settings, trail)
    local color = addon.GetTrailColor(trail, settings.groundColors)
    return string.format("|c%02x%02x%02x%.0f m|r",
        zo_round(color[1] * 255), zo_round(color[2] * 255), zo_round(color[3] * 255), trail.distance)
end

local function setText(control, text)
    if control:GetText() ~= text then control:SetText(text) end
end

local function setVisible(control, show)
    if control:IsHidden() == show then
        if not show then
            clearTip()
            if drag == control then stopDrag() end
        end
        control:SetHidden(not show)
    end
end

function addon.DrawPanel(settings, status, distance, destinationName, autoMode, trails)
    if not panel and not settings.showPanel and not (settings.collapsed and settings.showCompact) then return end
    if not panel then createPanel(settings) end
    if settings.collapsed and not panel:IsHidden() then
        align(compact, panel)
    end
    setVisible(panel, settings.showPanel and not settings.collapsed)
    setVisible(compact, settings.showCompact and settings.collapsed)
    if not panel:IsHidden() then
        local count = autoMode and trails and #trails or 0
        local height = math.max(0, count - 1) * rowHeight
        if height ~= extraHeight then
            extraHeight = height
            panel:SetHeight(math.max(panelHeight, settings.panel.h or panelHeight) + height)
            routeStatus:ClearAnchors()
            routeStatus:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 58 + height)
            routeStatus:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -26, 58 + height)
        end
        if count > 0 then
            for index, trail in ipairs(trails) do
                local row = index == 1 and detail or autoRows[index]
                if not row then
                    row = label(panel, "")
                    local offset = 38 + (index - 1) * rowHeight
                    row:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, offset)
                    row:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -26, offset)
                    autoRows[index] = row
                end
                row:SetHidden(false)
                local routeType = trail.waypoints and "Recorded path" or "Direct (unverified)"
                setText(row, colorDistance(settings, trail) .. "  " .. trail.target.name .. "  |c9db9c4" .. routeType .. "|r")
            end
        else
            local meters = distance and "  " .. colorDistance(settings, { distance = distance }) or ""
            local following = distance and status ~= "Guidance paused" and status ~= "Arrived"
            local title = autoMode and "Auto Wayshrines" or destinationName or "Personal waypoint"
            setText(detail, title .. meters .. (following and "  |cf5d179[Following]|r" or ""))
        end
        for index, row in pairs(autoRows) do
            row:SetHidden(index > count)
        end
        setText(routeStatus, "|cbfdfe6" .. status .. "|r")
    end
    if quick and not quick:IsHidden() then
        resume:SetText((settings.paused or settings.collapsed) and "Resume" or "Pause")
    end
end

function addon.ToggleQuickSettings()
    local settings = addon.settings
    if not settings or not addon.IsHud() then return end
    if quick and not quick:IsHidden() then return addon.CloseQuickSettings(true) end
    if not quick then
        quick = window("Quick", {}, math.max(10, GuiRoot:GetWidth() * .5 - 150), 230, 300, 106)
        quick:SetDrawTier(DT_HIGH)
        local title = label(quick, "|c78eef0WayShrine Pathfinder|r", "ZoFontGameBold")
        title:SetAnchor(TOPLEFT, quick, TOPLEFT, 12, 9)
        action(quick, "×", "Close quick settings.", 272, 23, function() addon.CloseQuickSettings(true) end)
        resume = action(quick, "", "Pause or resume waypoint guidance.", 10, 76, addon.ToggleGuidance)
        resume:ClearAnchors()
        resume:SetAnchor(TOPLEFT, quick, TOPLEFT, 10, 34)
        local visibility = action(quick, "Show panel", "Open the expanded distance panel.", 90, 92, function()
            settings.showPanel = true
            addon.SetCollapsed(false)
        end)
        visibility:ClearAnchors()
        visibility:SetAnchor(TOPLEFT, quick, TOPLEFT, 90, 34)
        local lam = LibAddonMenu2
        if lam and addon.settingsPanel then
            local button = action(quick, "AddOn settings", "Open colors, arrow styles and display options.", 10, 112,
                function()
                    addon.CloseQuickSettings(false)
                    lam:OpenToPanel(addon.settingsPanel)
                end)
            button:ClearAnchors()
            button:SetAnchor(TOPLEFT, quick, TOPLEFT, 10, 66)
        end
    end
    quickCursor = not HUD_UI_SCENE:IsShowing()
    if quickCursor then SetGameCameraUIMode(true) end
    quick:SetHidden(false)
    resume:SetText((settings.paused or settings.collapsed) and "Resume" or "Pause")
end

