-- A full-width LibAddonMenu row reusing its native dropdown and value handling.
local M = MountSwap
local function alignToggle(control)
    local lastWidth
    local function layout()
        local width = control:GetWidth()
        if width <= 0 or width == lastWidth then return end
        lastWidth = width
        control:SetHeight(32)
        local label, container = control.label, control.container
        label:ClearAnchors()
        label:SetDimensions(math.max(100, width - 300), 28)
        label:SetAnchor(LEFT, control, LEFT, 0, 0)
        container:ClearAnchors()
        container:SetDimensions(70, 28)
        container:SetAnchor(LEFT, control, LEFT, width - 280, 0)
    end
    layout()
    ZO_PostHookHandler(control, 'OnEffectivelyShown', layout)
    ZO_PostHookHandler(control, 'OnRectChanged', layout)
end

function M:RegisterFavoriteWidget(library)
    local create = LAMCreateControl -- Framework registry exists only after LibAddonMenu loads.
    if self.favoriteWidgetRegistered then return end
    if not library:RegisterWidget('mountswapfavorite', 1) then
        self.favoriteWidgetRegistered = true
        return
    end
    create.mountswapfavorite = function(parent, data, controlName)
        local control = create.dropdown(parent, data, controlName)
        local use = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, 'ZO_DefaultButton')
        use:SetDimensions(90, 28)
        use:SetAnchor(RIGHT, control, RIGHT, 0, 0)
        use:SetText(data.useName)
        M:FitLocalizedButton(use)
        use:SetHandler('OnClicked', function() data.useFunc() end)
        control.mountSwapUseButton = use
        local lastWidth
        local function layout()
            local width = control:GetWidth()
            if width <= 0 or width == lastWidth then return end
            lastWidth = width
            local dropdownWidth = math.max(120, width - 56 - 102)
            local label, container, combobox, dropdown = control.label, control.container, control.combobox, control.dropdown
            control:SetHeight(32)
            label:ClearAnchors()
            label:SetDimensions(44, 28)
            label:SetAnchor(LEFT, control, LEFT, 0, 0)
            container:ClearAnchors()
            container:SetDimensions(dropdownWidth, 28)
            container:SetAnchor(LEFT, control, LEFT, 56, 0)
            combobox:SetDimensions(dropdownWidth, 28)
            dropdown.m_containerWidth = dropdownWidth
        end
        layout()
        ZO_PostHookHandler(control, 'OnEffectivelyShown', layout)
        ZO_PostHookHandler(control, 'OnRectChanged', layout)
        return control
    end
    self.favoriteWidgetRegistered = true
end

function M:RegisterDashboardWidget(library)
    local create = LAMCreateControl
    if self.dashboardWidgetRegistered then return end
    if library:RegisterWidget('mountswapdashboard', 1) then
        create.mountswapdashboard = function(parent, data, controlName)
            local control = create.checkbox(parent, data, controlName)
            local open = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, 'ZO_DefaultButton')
            control.mountSwapOpenButton = open
            open:SetDimensions(180, 28)
            open:SetAnchor(RIGHT, control, RIGHT, 0, 0)
            open:SetText(M.L('Open Dashboard'))
            M:FitLocalizedButton(open)
            local toggle = control:GetHandler('OnMouseUp')
            if toggle then
                control:SetHandler('OnMouseUp', function(row, ...)
                    if not MouseIsOver(open, 0, 0, 0, 0) then toggle(row, ...) end
                end)
            end
            open:SetHandler('OnClicked', function()
                if data.getFunc() then data.openFunc() end
            end)
            local update = control.UpdateValue
            control.UpdateValue = function(self, ...)
                update(self, ...)
                open:SetEnabled(data.getFunc())
            end
            alignToggle(control)
            control:UpdateValue()
            return control
        end
    end
    self.dashboardWidgetRegistered = true
end

function M:RegisterSettingsLayoutWidgets(library)
    local create = LAMCreateControl
    if self.settingsLayoutWidgetsRegistered then return end
    if library:RegisterWidget('mountswapchattoggle', 1) then
        create.mountswapchattoggle = function(parent, data, controlName)
            local control = create.checkbox(parent, data, controlName)
            alignToggle(control)
            return control
        end
    end
    if library:RegisterWidget('mountswaprightbutton', 1) then
        create.mountswaprightbutton = function(parent, data, controlName)
            local control = create.button(parent, data, controlName)
            control:SetHeight(32)
            control.button:ClearAnchors()
            control.button:SetDimensions(180, 28)
            control.button:SetAnchor(RIGHT, control, RIGHT, 0, 0)
            M:FitLocalizedButton(control.button)
            return control
        end
    end
    self.settingsLayoutWidgetsRegistered = true
end
