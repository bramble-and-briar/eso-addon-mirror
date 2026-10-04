-- WegesruheSettings.lua
-- Dependency-free settings UI based on the shared Randwache settings layout.

local WR = Wegesruhe
if not WR then return end

local WM = WINDOW_MANAGER
local BLUE_R, BLUE_G, BLUE_B = 127 / 255, 199 / 255, 1
local CONTENT_WIDTH = 720

local function ShowSettingsTooltip(control, text)
    if not text or text == "" then return end

    ClearTooltip(InformationTooltip)

    -- Keep tooltips completely outside the settings window, matching Randwache.
    local settingsWindow = WR.settingsWindow
    if settingsWindow and not settingsWindow:IsHidden() then
        local rootWidth = GuiRoot:GetWidth()
        local leftSpace = settingsWindow:GetLeft() or 0
        local rightEdge = settingsWindow:GetRight() or rootWidth
        local rightSpace = rootWidth - rightEdge

        if rightSpace >= leftSpace then
            InitializeTooltip(InformationTooltip, settingsWindow, TOPLEFT, 12, 4, TOPRIGHT)
        else
            InitializeTooltip(InformationTooltip, settingsWindow, TOPRIGHT, -12, 4, TOPLEFT)
        end
    else
        InitializeTooltip(InformationTooltip, control, TOPLEFT, 8, 0, TOPRIGHT)
    end

    if InformationTooltip.SetDrawTier then InformationTooltip:SetDrawTier(DT_HIGH) end
    if InformationTooltip.SetDrawLayer then InformationTooltip:SetDrawLayer(DL_OVERLAY) end
    if InformationTooltip.SetDrawLevel then InformationTooltip:SetDrawLevel(1000) end
    if InformationTooltip.BringWindowToTop then InformationTooltip:BringWindowToTop() end

    SetTooltipText(InformationTooltip, text)
end

local function AddTooltip(control, text, enableMouse)
    if not control or not text or text == "" then return end

    -- Do not make whole rows mouse-enabled: they can otherwise swallow child clicks.
    if enableMouse then
        control:SetMouseEnabled(true)
    end

    control:SetHandler("OnMouseEnter", function(self)
        ShowSettingsTooltip(self, text)
    end)
    control:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
end

local function SetControlEnabled(control, enabled)
    if not control then return end
    if control.SetEnabled then control:SetEnabled(enabled) end
    if control.SetMouseEnabled then control:SetMouseEnabled(enabled) end
    control:SetAlpha(enabled and 1 or 0.35)
end

function WR:RegisterSettingsRefresher(callback)
    self.settingsRefreshers = self.settingsRefreshers or {}
    self.settingsRefreshers[#self.settingsRefreshers + 1] = callback
end

function WR:RefreshSettingsControls()
    if not self.settingsRefreshers then return end
    for _, callback in ipairs(self.settingsRefreshers) do
        callback()
    end
end

-- Compatibility aliases for existing internal calls.
function WR:AddSettingsRefresh(callback)
    self:RegisterSettingsRefresher(callback)
end

function WR:RefreshSettingsWindow()
    self:RefreshSettingsControls()
end

function WR:CreateSettingsWindow()
    if self.settingsWindow then return end

    local L = self.L
    self.settingsRefreshers = {}

    local window = WM:CreateTopLevelWindow("WegesruheSettingsWindow")
    self.settingsWindow = window
    window:SetDimensions(820, math.min(820, GuiRoot:GetHeight() - 80))
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_MEDIUM)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetMouseEnabled(true)
    window:SetHidden(true)

    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        SCENE_MANAGER:RegisterTopLevel(window, false)
    end

    -- Same opaque ESO backdrop and blue border as Randwache.
    local backdrop = WM:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    backdrop:SetInsets(12, 12, -12, -12)
    backdrop:SetCenterColor(0.018, 0.024, 0.035, 1)
    backdrop:SetEdgeColor(BLUE_R, BLUE_G, BLUE_B, 0.95)

    local title = WM:CreateControl(nil, window, CT_LABEL)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 30, 20)
    title:SetFont("ZoFontWinH1")
    title:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
    title:SetText(L.ADDON_NAME .. " - " .. L.SETTINGS_WINDOW_TITLE)

    local version = WM:CreateControl(nil, window, CT_LABEL)
    version:SetAnchor(TOPRIGHT, window, TOPRIGHT, -30, 28)
    version:SetFont("ZoFontGameSmall")
    version:SetColor(0.72, 0.72, 0.72, 1)
    version:SetText("v" .. tostring(self.version))

    local divider = WM:CreateControl(nil, window, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    divider:SetAnchor(TOPRIGHT, window, TOPRIGHT, -30, 56)
    divider:SetHeight(2)
    divider:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")
    divider:SetColor(BLUE_R, BLUE_G, BLUE_B, 0.65)

    local defaultsButton = WM:CreateControlFromVirtual("WegesruheSettingsDefaults", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton:SetText(L.DEFAULTS_BUTTON)
    AddTooltip(defaultsButton, L.DEFAULTS_TOOLTIP)
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetDefaults()
        self:RefreshSettingsControls()
    end)

    local closeButton = WM:CreateControlFromVirtual("WegesruheSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(L.CLOSE_BUTTON)
    closeButton:SetHandler("OnClicked", function()
        self:HideSettings()
    end)

    local scrollContainer = WM:CreateControlFromVirtual("WegesruheSettingsScroll", window, "ZO_ScrollContainer")
    scrollContainer:SetAnchor(TOPLEFT, window, TOPLEFT, 32, 68)
    scrollContainer:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -32, -66)
    ZO_Scroll_SetUseFadeGradient(scrollContainer, false)

    local scroll = GetControl(scrollContainer, "ScrollChild")
    self.settingsScroll = scroll
    scroll:SetWidth(CONTENT_WIDTH)

    local y = 0
    local controlId = 0
    local function NextName(prefix)
        controlId = controlId + 1
        return "WegesruheSettings" .. prefix .. tostring(controlId)
    end

    local function AddHeader(text)
        local label = WM:CreateControl(NextName("Header"), scroll, CT_LABEL)
        label:SetAnchor(TOPLEFT, scroll, TOPLEFT, 0, y)
        label:SetDimensions(CONTENT_WIDTH, 32)
        label:SetFont("ZoFontWinH2")
        label:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        label:SetText(text)
        y = y + 38
        return label
    end

    local function AddDescription(text, small)
        local label = WM:CreateControl(NextName("Description"), scroll, CT_LABEL)
        label:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        label:SetWidth(CONTENT_WIDTH - 16)
        label:SetFont(small and "ZoFontGameSmall" or "ZoFontGame")
        if small then
            label:SetColor(0.72, 0.72, 0.72, 1)
        else
            label:SetColor(0.85, 0.85, 0.85, 1)
        end
        label:SetText(text or "")
        local h = math.max(small and 28 or 42, (label:GetTextHeight() or 20) + 10)
        label:SetHeight(h)
        y = y + h + 6
        return label
    end

    local function AddCheckbox(text, getter, setter, tooltip)
        local row = WM:CreateControl(NextName("CheckboxRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 32)

        local checkbox = WM:CreateControlFromVirtual(NextName("Checkbox"), row, "ZO_CheckButton")
        checkbox:SetAnchor(LEFT, row, LEFT, 0, 0)
        checkbox:SetMouseEnabled(true)
        ZO_CheckButton_SetLabelText(checkbox, text)
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
            setter(checked)
            self:RefreshSettingsControls()
        end)

        local checkboxLabel = GetControl(checkbox, "Label")
        AddTooltip(checkboxLabel or checkbox, tooltip, checkboxLabel ~= nil)

        local function Refresh()
            ZO_CheckButton_SetCheckState(checkbox, not not getter())
        end
        self:RegisterSettingsRefresher(Refresh)
        Refresh()

        y = y + 34
        return row
    end

    local function AddDropdown(text, choices, getter, setter, tooltip, disabledFunc)
        local row = WM:CreateControl(NextName("DropdownRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 38)

        local label = WM:CreateControl(NextName("DropdownLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(430, 30)
        label:SetFont("ZoFontGame")
        label:SetText(text)

        local button = WM:CreateControl(NextName("DropdownButton"), row, CT_BUTTON)
        button:SetDimensions(240, 28)
        button:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        button:SetMouseEnabled(true)

        local backdrop = WM:CreateControl(nil, button, CT_BACKDROP)
        backdrop:SetAnchorFill(button)
        backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.92)
        backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 64, 8)
        backdrop:SetEdgeColor(0.72, 0.66, 0.45, 0.95)
        backdrop:SetInsets(2, 2, -2, -2)
        backdrop:SetMouseEnabled(false)

        local divider = WM:CreateControl(nil, button, CT_TEXTURE)
        divider:SetDimensions(1, 20)
        divider:SetAnchor(RIGHT, button, RIGHT, -26, 0)
        divider:SetColor(0.72, 0.66, 0.45, 0.65)
        divider:SetTexture("EsoUI/Art/Inventory/inventory_sortdivider.dds")
        divider:SetMouseEnabled(false)

        local valueLabel = WM:CreateControl(nil, button, CT_LABEL)
        valueLabel:SetAnchor(LEFT, button, LEFT, 10, 0)
        valueLabel:SetAnchor(RIGHT, button, RIGHT, -34, 0)
        valueLabel:SetHeight(28)
        valueLabel:SetFont("ZoFontGame")
        valueLabel:SetColor(0.95, 0.92, 0.82, 1)
        valueLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        valueLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        valueLabel:SetMouseEnabled(false)

        local arrow = WM:CreateControl(nil, button, CT_TEXTURE)
        arrow:SetDimensions(16, 16)
        arrow:SetAnchor(RIGHT, button, RIGHT, -8, 0)
        arrow:SetTexture("EsoUI/Art/Buttons/dropbox_arrow_normal.dds")
        arrow:SetMouseEnabled(false)

        local function DisplayForValue(value)
            for _, choice in ipairs(choices) do
                if choice.value == value then return choice.label end
            end
            return L.DROPDOWN_FALLBACK or tostring(value or "")
        end

        local function IsDisabled()
            return disabledFunc and disabledFunc() == true
        end

        local function Refresh()
            valueLabel:SetText(DisplayForValue(getter()))
            local enabled = not IsDisabled()
            SetControlEnabled(button, enabled)
            label:SetAlpha(enabled and 1 or 0.45)
            backdrop:SetEdgeColor(0.72, 0.66, 0.45, enabled and 0.95 or 0.45)
            valueLabel:SetAlpha(enabled and 1 or 0.55)
            arrow:SetAlpha(enabled and 1 or 0.45)
        end
        self:RegisterSettingsRefresher(Refresh)
        Refresh()

        local function ShowChoices()
            if IsDisabled() then return end

            if type(ClearMenu) == "function" and type(AddMenuItem) == "function" and type(ShowMenu) == "function" then
                ClearMenu()
                if type(SetMenuMinimumWidth) == "function" then
                    SetMenuMinimumWidth(button:GetWidth())
                end
                for _, choice in ipairs(choices) do
                    local selectedChoice = choice
                    AddMenuItem(selectedChoice.label, function()
                        setter(selectedChoice.value)
                        self:RefreshSettingsControls()
                    end)
                end
                ShowMenu(button)
                if type(AnchorMenu) == "function" then
                    AnchorMenu(button, 0)
                end
            else
                local current = getter()
                local nextIndex = 1
                for index, choice in ipairs(choices) do
                    if choice.value == current then
                        nextIndex = index % #choices + 1
                        break
                    end
                end
                setter(choices[nextIndex].value)
                self:RefreshSettingsControls()
            end
        end

        button:SetHandler("OnClicked", ShowChoices)

        AddTooltip(label, tooltip, true)
        AddTooltip(button, tooltip)

        y = y + 42
        return row
    end

    local function AddCheckboxColumns(definitions, valueGetter, valueSetter, tooltip, columns)
        columns = columns or 2
        local columnGap = 18
        local availableWidth = CONTENT_WIDTH - 16
        local columnWidth = math.floor((availableWidth - ((columns - 1) * columnGap)) / columns)
        local startX = 8
        local startY = y
        local index = 0

        for _, definition in ipairs(definitions or {}) do
            local key = definition.key
            local column = index % columns
            local rowIndex = math.floor(index / columns)

            local row = WM:CreateControl(NextName("CheckboxGridRow"), scroll, CT_CONTROL)
            row:SetAnchor(TOPLEFT, scroll, TOPLEFT, startX + (column * (columnWidth + columnGap)), startY + (rowIndex * 34))
            row:SetDimensions(columnWidth, 32)

            local checkbox = WM:CreateControlFromVirtual(NextName("CheckboxGrid"), row, "ZO_CheckButton")
            checkbox:SetAnchor(LEFT, row, LEFT, 0, 0)
            checkbox:SetMouseEnabled(true)
            ZO_CheckButton_SetLabelText(checkbox, L[definition.label] or definition.constant)
            ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
                valueSetter(key, checked)
                self:RefreshSettingsControls()
            end)

            local checkboxLabel = GetControl(checkbox, "Label")
            if checkboxLabel then
                checkboxLabel:SetWidth(columnWidth - 34)
            end
            AddTooltip(checkboxLabel or checkbox, tooltip, checkboxLabel ~= nil)

            local function Refresh()
                ZO_CheckButton_SetCheckState(checkbox, not not valueGetter(key))
            end
            self:RegisterSettingsRefresher(Refresh)
            Refresh()

            index = index + 1
        end

        local rows = zo_max(1, math.ceil(index / columns))
        y = startY + (rows * 34)
    end

    local function AddSmallButton(text, callback, tooltip, x, width)
        local button = WM:CreateControlFromVirtual(NextName("SmallButton"), scroll, "ZO_DefaultButton")
        button:SetDimensions(width or 190, 28)
        button:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8 + (x or 0), y)
        button:SetText(text)
        button:SetHandler("OnClicked", callback)
        AddTooltip(button, tooltip)
        return button
    end

    AddDescription(L.PANEL_DESCRIPTION or L.ADDON_SHORT_DESCRIPTION)

    AddHeader(L.SETTINGS_SCOPE_HEADER)
    AddDropdown(L.SETTINGS_SCOPE, {
        { label = L.SETTINGS_SCOPE_ACCOUNT, value = "account" },
        { label = L.SETTINGS_SCOPE_CHARACTER, value = "character" },
    }, function()
        return self:GetSettingsScope()
    end, function(value)
        self:SetSettingsScope(value)
        self:RefreshSettingsControls()
    end, L.SETTINGS_SCOPE_TOOLTIP)
    AddDescription(L.SETTINGS_SCOPE_INFO, true)

    AddHeader(L.SETTINGS_GENERAL_HEADER)
    AddCheckbox(L.ENABLED,
        function() return self.settings.enabled end,
        function(value) self:SetEnabled(value, false) end,
        L.ENABLED_TOOLTIP)

    AddDropdown(L.PRESET, {
        { label = L.PRESET_NORMAL, value = "normal" },
        { label = L.PRESET_GENTLE, value = "gentle" },
        { label = L.PRESET_EXPLORER, value = "explorer" },
        { label = L.PRESET_HARDCORE, value = "hardcore" },
        { label = L.PRESET_CUSTOM, value = "custom" },
    }, function()
        return self.settings.preset
    end, function(value)
        if value == "custom" then
            self.settings.preset = "custom"
        else
            self:ApplyPreset(value)
        end
    end, L.PRESET_TOOLTIP)

    AddHeader(L.PVP_HEADER)
    AddCheckbox(L.PVP_OVERRIDE,
        function() return self.settings.pvpOverride end,
        function(value)
            self.settings.pvpOverride = value
            self:RefreshAll()
        end,
        L.PVP_OVERRIDE_TOOLTIP)

    AddDropdown(L.PVP_PRESET, {
        { label = L.PRESET_OFF, value = "off" },
        { label = L.PRESET_NORMAL, value = "normal" },
        { label = L.PRESET_GENTLE, value = "gentle" },
        { label = L.PRESET_EXPLORER, value = "explorer" },
        { label = L.PRESET_HARDCORE, value = "hardcore" },
    }, function()
        return self.settings.pvpPreset
    end, function(value)
        self.settings.pvpPreset = value
        self:RefreshAll()
    end, L.PVP_PRESET_TOOLTIP, function()
        return not self.settings.pvpOverride
    end)

    AddHeader(L.KEYBIND_HEADER)
    AddDescription(L.KEYBIND_INFO, true)

    AddHeader(L.MAP_HEADER)
    AddCheckbox(L.MAP_QUESTS,
        function() return self.settings.mapQuestPins end,
        function(value)
            self.settings.mapQuestPins = value
            self:MarkCustom()
            self:RefreshAll(true)
        end,
        L.MAP_QUESTS_TOOLTIP)

    AddHeader(L.QUEST_FILTERS_HEADER)
    AddDescription(L.QUEST_FILTERS_DESCRIPTION, true)

    local function SetAll(definitions, target, value)
        for _, definition in ipairs(definitions or {}) do
            target[definition.key] = value
        end
        self:MarkCustom()
        self:RefreshAll(true)
        self:RefreshSettingsControls()
    end

    AddHeader(L.QUEST_TYPES_HEADER)
    AddDescription(L.QUEST_TYPES_DESCRIPTION, true)
    AddSmallButton(L.ENABLE_ALL_SHORT, function()
        SetAll(self.questTypeDefinitions, self.settings.questTypes, true)
    end, L.ALL_ENABLE_QUEST_TYPES_TOOLTIP, 0, 190)
    AddSmallButton(L.DISABLE_ALL_SHORT, function()
        SetAll(self.questTypeDefinitions, self.settings.questTypes, false)
    end, L.ALL_DISABLE_QUEST_TYPES_TOOLTIP, 200, 190)
    y = y + 34

    AddCheckboxColumns(self.questTypeDefinitions,
        function(key)
            return self.settings.questTypes[key] ~= false
        end,
        function(key, value)
            self.settings.questTypes[key] = value
            self:MarkCustom()
            self:RefreshAll(true)
        end,
        L.QUEST_FILTER_TOOLTIP,
        2)

    AddHeader(L.REPEAT_TYPES_HEADER)
    AddDescription(L.REPEAT_TYPES_DESCRIPTION, true)
    AddSmallButton(L.ENABLE_ALL_SHORT, function()
        SetAll(self.repeatTypeDefinitions, self.settings.repeatTypes, true)
    end, L.ALL_ENABLE_REPEAT_TYPES_TOOLTIP, 0, 190)
    AddSmallButton(L.DISABLE_ALL_SHORT, function()
        SetAll(self.repeatTypeDefinitions, self.settings.repeatTypes, false)
    end, L.ALL_DISABLE_REPEAT_TYPES_TOOLTIP, 200, 190)
    y = y + 34

    AddCheckboxColumns(self.repeatTypeDefinitions,
        function(key)
            return self.settings.repeatTypes[key] ~= false
        end,
        function(key, value)
            self.settings.repeatTypes[key] = value
            self:MarkCustom()
            self:RefreshAll(true)
        end,
        L.QUEST_FILTER_TOOLTIP,
        2)

    AddHeader(L.COMPASS_HEADER)
    local compassRows = {
        { L.COMPASS_QUEST_OFFERS, L.COMPASS_GENERIC_TOOLTIP, "questOffers" },
        { L.COMPASS_ASSISTED, L.COMPASS_GENERIC_TOOLTIP, "assistedObjectives" },
        { L.COMPASS_SECONDARY, L.COMPASS_GENERIC_TOOLTIP, "secondaryObjectives" },
        { L.COMPASS_POI_SEEN, L.COMPASS_GENERIC_TOOLTIP, "poiSeen" },
        { L.COMPASS_POI_COMPLETE, L.COMPASS_GENERIC_TOOLTIP, "poiComplete" },
        { L.COMPASS_AREAS, L.COMPASS_AREAS_TOOLTIP, "questAreas" },
    }
    for _, rowData in ipairs(compassRows) do
        local key = rowData[3]
        AddCheckbox(rowData[1],
            function() return self.settings.compass[key] end,
            function(value)
                self.settings.compass[key] = value
                self:MarkCustom()
                self:RefreshAll()
            end,
            rowData[2])
    end

    AddHeader(L.WORLD_HEADER)
    AddDescription(L.WORLD_SAFETY_INFO, true)
    local worldRows = {
        { L.WORLD_QUEST_OFFERS, L.WORLD_GENERIC_TOOLTIP, "questOffers" },
        { L.WORLD_ASSISTED, L.WORLD_GENERIC_TOOLTIP, "assistedObjectives" },
        { L.WORLD_SECONDARY, L.WORLD_GENERIC_TOOLTIP, "secondaryObjectives" },
        { L.WORLD_BREADCRUMBS, L.WORLD_BREADCRUMBS_TOOLTIP, "breadcrumbs" },
    }
    for _, rowData in ipairs(worldRows) do
        local key = rowData[3]
        AddCheckbox(rowData[1],
            function() return self.settings.world[key] end,
            function(value)
                self.settings.world[key] = value
                self:MarkCustom()
                self:RefreshAll()
            end,
            rowData[2])
    end

    scroll:SetHeight(y + 20)
end

function WR:ShowSettings(source)
    self:CreateSettingsWindow()
    self.settingsOpenSource = source
    self:RefreshSettingsControls()

    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then
        SCENE_MANAGER:ShowTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(false)
    end

    self.settingsWindow:BringWindowToTop()
end

function WR:HideSettings()
    ClearTooltip(InformationTooltip)
    if not self.settingsWindow then return end

    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

-- Compatibility names used by Wegesruhe's slash command and gear integration.
function WR:OpenSettings(source)
    self:ShowSettings(source)
end

function WR:CloseSettings()
    self:HideSettings()
end

function WR:ToggleSettings(source)
    self:CreateSettingsWindow()
    if self.settingsWindow:IsHidden() then
        self:ShowSettings(source)
    else
        self:HideSettings()
    end
end

function WR:InstallSettingsCloseBehavior()
    if self.settingsCloseBehaviorInstalled then return end
    self.settingsCloseBehaviorInstalled = true

    if SCENE_MANAGER and SCENE_MANAGER.GetScene then
        local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
        if gameMenuScene and gameMenuScene.RegisterCallback then
            gameMenuScene:RegisterCallback("StateChange", function(_, newState)
                if (newState == SCENE_HIDING or newState == SCENE_HIDDEN)
                    and self.settingsWindow and not self.settingsWindow:IsHidden() then
                    self:HideSettings()
                end
            end)
        end
    end
end

function WR:InitializeSettings()
    -- Like Randwache, create the window lazily and let ESO manage ESC/top-level behavior.
    self:InstallSettingsCloseBehavior()
end
