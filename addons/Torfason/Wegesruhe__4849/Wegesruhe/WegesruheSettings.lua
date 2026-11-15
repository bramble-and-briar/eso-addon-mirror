-- WegesruheSettings.lua
-- Dependency-free settings UI based on the shared Randwache settings layout.

local WR = Wegesruhe
if not WR then return end

local WM = WINDOW_MANAGER
local BLUE_R, BLUE_G, BLUE_B = 127 / 255, 199 / 255, 1
local CONTENT_WIDTH = 720

-- Every visible label looks up the CURRENT language rather than a copy made
-- when the settings panel was first opened.
local function LocalizedText(key)
    if type(key) ~= "string" then return "" end
    return (WR.L and WR.L[key]) or key
end

local function MaxTranslationTextHeight(control, key)
    -- Reserve adequate vertical space even when the user switches from a
    -- short translation to a longer one without reconstructing the window.
    local tallest = control:GetTextHeight() or 0
    for _, language in pairs(WR.Localization or {}) do
        if type(language) == "table" then
            local translated = language[key] or (WR.Localization.en and WR.Localization.en[key])
            if translated then
                control:SetText(translated)
                tallest = math.max(tallest, control:GetTextHeight() or 0)
            end
        end
    end
    control:SetText(LocalizedText(key))
    return tallest
end

local function ShowSettingsTooltip(control, key)
    local text = LocalizedText(key)
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

local function AddTooltip(control, key, enableMouse)
    if not control or not key or key == "" then return end

    -- Do not make whole rows mouse-enabled: they can otherwise swallow child clicks.
    if enableMouse then
        control:SetMouseEnabled(true)
    end

    control:SetHandler("OnMouseEnter", function(self)
        ShowSettingsTooltip(self, key)
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

function WR:RegisterSettingsLanguageRefresher(callback)
    self.settingsLanguageRefreshers = self.settingsLanguageRefreshers or {}
    self.settingsLanguageRefreshers[#self.settingsLanguageRefreshers + 1] = callback
end

function WR:RefreshSettingsLanguage()
    if not self.settingsLanguageRefreshers then return end
    ClearTooltip(InformationTooltip)
    for _, callback in ipairs(self.settingsLanguageRefreshers) do
        callback()
    end
    -- Refresh dropdown values, too: their choice labels are localized lazily.
    self:RefreshSettingsControls()
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

    self.settingsRefreshers = {}
    self.settingsLanguageRefreshers = {}

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
    self:RegisterSettingsLanguageRefresher(function()
        title:SetText(LocalizedText("ADDON_NAME") .. " - " .. LocalizedText("SETTINGS_WINDOW_TITLE"))
    end)
    title:SetText(LocalizedText("ADDON_NAME") .. " - " .. LocalizedText("SETTINGS_WINDOW_TITLE"))

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
    defaultsButton:SetText(LocalizedText("DEFAULTS_BUTTON"))
    self:RegisterSettingsLanguageRefresher(function()
        defaultsButton:SetText(LocalizedText("DEFAULTS_BUTTON"))
    end)
    AddTooltip(defaultsButton, "DEFAULTS_TOOLTIP")
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetDefaults()
        self:RefreshSettingsControls()
    end)

    local closeButton = WM:CreateControlFromVirtual("WegesruheSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(LocalizedText("CLOSE_BUTTON"))
    self:RegisterSettingsLanguageRefresher(function()
        closeButton:SetText(LocalizedText("CLOSE_BUTTON"))
    end)
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
    -- The main section headings stay flush left; their options are inset.
    -- Quest-type and repeat-type filters sit one level deeper beneath Quest Filters.
    local SECTION_INDENT = 20
    local SUBSECTION_INDENT = 40
    local optionIndent = 0
    local controlId = 0
    local function NextName(prefix)
        controlId = controlId + 1
        return "WegesruheSettings" .. prefix .. tostring(controlId)
    end

    local function AddHeader(textKey)
        optionIndent = SECTION_INDENT
        local label = WM:CreateControl(NextName("Header"), scroll, CT_LABEL)
        label:SetAnchor(TOPLEFT, scroll, TOPLEFT, 0, y)
        label:SetDimensions(CONTENT_WIDTH, 32)
        label:SetFont("ZoFontWinH2")
        label:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        label:SetText(LocalizedText(textKey))
        self:RegisterSettingsLanguageRefresher(function()
            label:SetText(LocalizedText(textKey))
        end)
        y = y + 38
        return label
    end

    local function AddSubheader(textKey)
        -- A subordinate heading only groups controls visually; it never changes options.
        optionIndent = SUBSECTION_INDENT
        local label = WM:CreateControl(NextName("Subheader"), scroll, CT_LABEL)
        label:SetAnchor(TOPLEFT, scroll, TOPLEFT, SECTION_INDENT, y)
        label:SetDimensions(CONTENT_WIDTH - SECTION_INDENT, 28)
        label:SetFont("ZoFontGameBold")
        label:SetColor(0.78, 0.86, 0.92, 1)
        label:SetText(LocalizedText(textKey))
        self:RegisterSettingsLanguageRefresher(function()
            label:SetText(LocalizedText(textKey))
        end)
        y = y + 32
        return label
    end

    local function AddDescription(textKey, small)
        local label = WM:CreateControl(NextName("Description"), scroll, CT_LABEL)
        label:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8 + optionIndent, y)
        label:SetWidth(CONTENT_WIDTH - 16 - optionIndent)
        label:SetFont(small and "ZoFontGameSmall" or "ZoFontGame")
        if small then
            label:SetColor(0.72, 0.72, 0.72, 1)
        else
            label:SetColor(0.85, 0.85, 0.85, 1)
        end
        label:SetText(LocalizedText(textKey))
        local h = math.max(small and 28 or 42, MaxTranslationTextHeight(label, textKey) + 10)
        self:RegisterSettingsLanguageRefresher(function()
            label:SetText(LocalizedText(textKey))
        end)
        label:SetHeight(h)
        y = y + h + 6
        return label
    end

    local function AddCheckbox(textKey, getter, setter, tooltipKey, disabledFunc)
        local row = WM:CreateControl(NextName("CheckboxRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8 + optionIndent, y)
        row:SetDimensions(CONTENT_WIDTH - 16 - optionIndent, 32)

        local checkbox = WM:CreateControlFromVirtual(NextName("Checkbox"), row, "ZO_CheckButton")
        checkbox:SetAnchor(LEFT, row, LEFT, 0, 0)
        checkbox:SetMouseEnabled(true)
        ZO_CheckButton_SetLabelText(checkbox, LocalizedText(textKey))
        self:RegisterSettingsLanguageRefresher(function()
            ZO_CheckButton_SetLabelText(checkbox, LocalizedText(textKey))
        end)
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
            if disabledFunc and disabledFunc() then return end
            setter(checked)
            self:RefreshSettingsControls()
        end)

        local checkboxLabel = GetControl(checkbox, "Label")
        AddTooltip(checkboxLabel or checkbox, tooltipKey, checkboxLabel ~= nil)

        local function Refresh()
            ZO_CheckButton_SetCheckState(checkbox, not not getter())
            -- ZO_CheckButton manages its own enabled/click state. Do NOT call
            -- SetEnabled on every refresh: Test 7 broke checkbox interaction.
            -- Only subordinate options need mouse suppression when disabled.
            if disabledFunc then
                local enabled = not disabledFunc()
                checkbox:SetMouseEnabled(enabled)
                checkbox:SetAlpha(enabled and 1 or 0.35)
            end
        end
        self:RegisterSettingsRefresher(Refresh)
        Refresh()

        y = y + 34
        return row
    end

    local function AddDropdown(textKey, choices, getter, setter, tooltipKey, disabledFunc)
        local row = WM:CreateControl(NextName("DropdownRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8 + optionIndent, y)
        row:SetDimensions(CONTENT_WIDTH - 16 - optionIndent, 38)

        local label = WM:CreateControl(NextName("DropdownLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(430, 30)
        label:SetFont("ZoFontGame")
        label:SetText(LocalizedText(textKey))
        self:RegisterSettingsLanguageRefresher(function()
            label:SetText(LocalizedText(textKey))
        end)

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

        local function ChoiceLabel(choice)
            return choice.key and LocalizedText(choice.key) or choice.label
        end

        local function DisplayForValue(value)
            for _, choice in ipairs(choices) do
                if choice.value == value then return ChoiceLabel(choice) end
            end
            return LocalizedText("DROPDOWN_FALLBACK")
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
                    AddMenuItem(ChoiceLabel(selectedChoice), function()
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

        AddTooltip(label, tooltipKey, true)
        AddTooltip(button, tooltipKey)

        y = y + 42
        return row
    end

    local function AddCheckboxColumns(definitions, valueGetter, valueSetter, tooltipKey, columns, disabledFunc)
        columns = columns or 2
        local columnGap = 18
        local availableWidth = CONTENT_WIDTH - 16 - optionIndent
        local columnWidth = math.floor((availableWidth - ((columns - 1) * columnGap)) / columns)
        local startX = 8 + optionIndent
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
            local function GridLabel()
                return (self.L and self.L[definition.label]) or definition.constant or definition.label
            end
            ZO_CheckButton_SetLabelText(checkbox, GridLabel())
            self:RegisterSettingsLanguageRefresher(function()
                ZO_CheckButton_SetLabelText(checkbox, GridLabel())
            end)
            ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
                if disabledFunc and disabledFunc() then return end
                valueSetter(key, checked)
                self:RefreshSettingsControls()
            end)

            local checkboxLabel = GetControl(checkbox, "Label")
            if checkboxLabel then
                checkboxLabel:SetWidth(columnWidth - 34)
            end
            AddTooltip(checkboxLabel or checkbox, tooltipKey, checkboxLabel ~= nil)

            local function Refresh()
                ZO_CheckButton_SetCheckState(checkbox, not not valueGetter(key))
                -- Keep the known-good CheckButton behavior for normal options.
                if disabledFunc then
                    local enabled = not disabledFunc()
                    checkbox:SetMouseEnabled(enabled)
                    checkbox:SetAlpha(enabled and 1 or 0.35)
                end
            end
            self:RegisterSettingsRefresher(Refresh)
            Refresh()

            index = index + 1
        end

        local rows = zo_max(1, math.ceil(index / columns))
        y = startY + (rows * 34)
    end

    local function AddSmallButton(textKey, callback, tooltipKey, x, width, disabledFunc)
        local button = WM:CreateControlFromVirtual(NextName("SmallButton"), scroll, "ZO_DefaultButton")
        button:SetDimensions(width or 190, 28)
        button:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8 + optionIndent + (x or 0), y)
        button:SetText(LocalizedText(textKey))
        self:RegisterSettingsLanguageRefresher(function()
            button:SetText(LocalizedText(textKey))
        end)
        button:SetHandler("OnClicked", function()
            if disabledFunc and disabledFunc() then return end
            callback()
        end)
        if disabledFunc then
            self:RegisterSettingsRefresher(function()
                SetControlEnabled(button, not disabledFunc())
            end)
        end
        AddTooltip(button, tooltipKey)
        return button
    end

    AddDescription("PANEL_DESCRIPTION")

    AddHeader("SETTINGS_SCOPE_HEADER")
    AddDropdown("SETTINGS_SCOPE", {
        { key = "SETTINGS_SCOPE_ACCOUNT", value = "account" },
        { key = "SETTINGS_SCOPE_CHARACTER", value = "character" },
    }, function()
        return self:GetSettingsScope()
    end, function(value)
        self:SetSettingsScope(value)
        self:RefreshSettingsControls()
    end, "SETTINGS_SCOPE_TOOLTIP")
    AddDescription("SETTINGS_SCOPE_INFO", true)

    AddHeader("LANGUAGE_HEADER")
    AddDropdown("LANGUAGE", {
        { key = "LANGUAGE_AUTO", value = "auto" },
        { label = "Deutsch", value = "de" },
        { label = "English", value = "en" },
        { label = "Français", value = "fr" },
        { label = "Español", value = "es" },
        { label = "Русский", value = "ru" },
        { label = "简体中文", value = "zh" },
        { label = "日本語", value = "jp" },
    }, function()
        return self.storage.language or "auto"
    end, function(value)
        self:SetLanguagePreference(value)
    end, "LANGUAGE_TOOLTIP")

    AddHeader("SETTINGS_GENERAL_HEADER")
    AddCheckbox("ENABLED",
        function() return self.settings.enabled end,
        function(value) self:SetEnabled(value, false) end,
        "ENABLED_TOOLTIP")

    AddDropdown("PRESET", {
        { key = "PRESET_NORMAL", value = "normal" },
        { key = "PRESET_GENTLE", value = "gentle" },
        { key = "PRESET_EXPLORER", value = "explorer" },
        { key = "PRESET_HARDCORE", value = "hardcore" },
        { key = "PRESET_CUSTOM", value = "custom" },
    }, function()
        return self.settings.preset
    end, function(value)
        if value == "custom" then
            self.settings.preset = "custom"
        else
            self:ApplyPreset(value)
        end
    end, "PRESET_TOOLTIP")

    AddHeader("PVP_HEADER")
    AddCheckbox("PVP_OVERRIDE",
        function() return self.settings.pvpOverride end,
        function(value)
            self.settings.pvpOverride = value
            self:RefreshAll()
        end,
        "PVP_OVERRIDE_TOOLTIP")

    -- PvP preset belongs to the switch directly above it.
    optionIndent = SUBSECTION_INDENT
    AddDropdown("PVP_PRESET", {
        { key = "PRESET_OFF", value = "off" },
        { key = "PRESET_NORMAL", value = "normal" },
        { key = "PRESET_GENTLE", value = "gentle" },
        { key = "PRESET_EXPLORER", value = "explorer" },
        { key = "PRESET_HARDCORE", value = "hardcore" },
    }, function()
        return self.settings.pvpPreset
    end, function(value)
        self.settings.pvpPreset = value
        self:RefreshAll()
    end, "PVP_PRESET_TOOLTIP", function()
        return not self.settings.pvpOverride
    end)

    AddHeader("KEYBIND_HEADER")
    AddDescription("KEYBIND_INFO", true)

    AddHeader("MAP_HEADER")
    AddCheckbox("MAP_QUESTS",
        function() return self.settings.mapQuestPins end,
        function(value)
            self.settings.mapQuestPins = value
            self:MarkCustom()
            self:RefreshAll(true)
        end,
        "MAP_QUESTS_TOOLTIP")

    -- Quest category filters under World Map apply ONLY to the world map.
    -- When the map quest-pin master is off, these options have no map effect.
    -- Keep their saved values while showing them visibly inactive.
    local function IsMapQuestPinsOff()
        return self.settings.mapQuestPins == false
    end

    local function DimWhenDisabled(control, disabledFunc)
        self:RegisterSettingsRefresher(function()
            control:SetAlpha(disabledFunc() and 0.40 or 1)
        end)
    end

    DimWhenDisabled(AddDescription("MAP_FILTERS_DESCRIPTION", true), IsMapQuestPinsOff)

    local function RefreshSurface(surface)
        if surface == "compass" then
            self:RefreshCompass()
        else
            self:RefreshMap(true)
        end
    end

    local function SetAll(definitions, target, value, surface)
        for _, definition in ipairs(definitions or {}) do
            target[definition.key] = value
        end
        self:MarkCustom()
        RefreshSurface(surface)
        self:RefreshSettingsControls()
    end

    DimWhenDisabled(AddSubheader("QUEST_TYPES_HEADER"), IsMapQuestPinsOff)
    DimWhenDisabled(AddDescription("QUEST_TYPES_DESCRIPTION", true), IsMapQuestPinsOff)
    AddSmallButton("ENABLE_ALL_SHORT", function()
        SetAll(self.questTypeDefinitions, self.settings.questTypes, true, "map")
    end, "ALL_ENABLE_QUEST_TYPES_TOOLTIP", 0, 190, IsMapQuestPinsOff)
    AddSmallButton("DISABLE_ALL_SHORT", function()
        SetAll(self.questTypeDefinitions, self.settings.questTypes, false, "map")
    end, "ALL_DISABLE_QUEST_TYPES_TOOLTIP", 200, 190, IsMapQuestPinsOff)
    y = y + 34

    AddCheckboxColumns(self.questTypeDefinitions,
        function(key)
            return self.settings.questTypes[key] ~= false
        end,
        function(key, value)
            self.settings.questTypes[key] = value
            self:MarkCustom()
            RefreshSurface("map")
        end,
        "MAP_QUEST_FILTER_TOOLTIP",
        2, IsMapQuestPinsOff)

    DimWhenDisabled(AddSubheader("REPEAT_TYPES_HEADER"), IsMapQuestPinsOff)
    DimWhenDisabled(AddDescription("REPEAT_TYPES_DESCRIPTION", true), IsMapQuestPinsOff)
    AddSmallButton("ENABLE_ALL_SHORT", function()
        SetAll(self.repeatTypeDefinitions, self.settings.repeatTypes, true, "map")
    end, "ALL_ENABLE_REPEAT_TYPES_TOOLTIP", 0, 190, IsMapQuestPinsOff)
    AddSmallButton("DISABLE_ALL_SHORT", function()
        SetAll(self.repeatTypeDefinitions, self.settings.repeatTypes, false, "map")
    end, "ALL_DISABLE_REPEAT_TYPES_TOOLTIP", 200, 190, IsMapQuestPinsOff)
    y = y + 34

    AddCheckboxColumns(self.repeatTypeDefinitions,
        function(key)
            return self.settings.repeatTypes[key] ~= false
        end,
        function(key, value)
            self.settings.repeatTypes[key] = value
            self:MarkCustom()
            RefreshSurface("map")
        end,
        "MAP_QUEST_FILTER_TOOLTIP",
        2, IsMapQuestPinsOff)

    AddHeader("COMPASS_HEADER")
    AddCheckbox("COMPASS_PINS",
        function() return self.settings.compassPins ~= false end,
        function(value)
            self.settings.compassPins = value
            self:MarkCustom()
            self:RefreshCompass()
        end,
        "COMPASS_PINS_TOOLTIP")

    local function IsCompassMarkersOff()
        return self.settings.compassPins == false
    end

    local compassRows = {
        { "COMPASS_QUEST_OFFERS", "COMPASS_GENERIC_TOOLTIP", "questOffers" },
        { "COMPASS_ASSISTED", "COMPASS_GENERIC_TOOLTIP", "assistedObjectives" },
        { "COMPASS_SECONDARY", "COMPASS_GENERIC_TOOLTIP", "secondaryObjectives" },
        { "COMPASS_POI_SEEN", "COMPASS_POI_SEEN_TOOLTIP", "poiSeen" },
        { "COMPASS_POI_COMPLETE", "COMPASS_POI_COMPLETE_TOOLTIP", "poiComplete" },
        { "COMPASS_AREAS", "COMPASS_AREAS_TOOLTIP", "questAreas" },
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
            rowData[2], IsCompassMarkersOff)
    end

    -- The compass owns its OWN quest-type/repeat-type filters. They are
    -- initialized from legacy filters during migration, then independent.
    AddDescription("COMPASS_FILTERS_DESCRIPTION", true)
    AddSubheader("QUEST_TYPES_HEADER")
    AddDescription("QUEST_TYPES_DESCRIPTION", true)
    AddSmallButton("ENABLE_ALL_SHORT", function()
        SetAll(self.questTypeDefinitions, self.settings.compassQuestTypes, true, "compass")
    end, "ALL_ENABLE_QUEST_TYPES_TOOLTIP", 0, 190, IsCompassMarkersOff)
    AddSmallButton("DISABLE_ALL_SHORT", function()
        SetAll(self.questTypeDefinitions, self.settings.compassQuestTypes, false, "compass")
    end, "ALL_DISABLE_QUEST_TYPES_TOOLTIP", 200, 190, IsCompassMarkersOff)
    y = y + 34

    AddCheckboxColumns(self.questTypeDefinitions,
        function(key)
            return self.settings.compassQuestTypes[key] ~= false
        end,
        function(key, value)
            self.settings.compassQuestTypes[key] = value
            self:MarkCustom()
            RefreshSurface("compass")
        end,
        "COMPASS_QUEST_FILTER_TOOLTIP",
        2, IsCompassMarkersOff)

    AddSubheader("REPEAT_TYPES_HEADER")
    AddDescription("REPEAT_TYPES_DESCRIPTION", true)
    AddSmallButton("ENABLE_ALL_SHORT", function()
        SetAll(self.repeatTypeDefinitions, self.settings.compassRepeatTypes, true, "compass")
    end, "ALL_ENABLE_REPEAT_TYPES_TOOLTIP", 0, 190, IsCompassMarkersOff)
    AddSmallButton("DISABLE_ALL_SHORT", function()
        SetAll(self.repeatTypeDefinitions, self.settings.compassRepeatTypes, false, "compass")
    end, "ALL_DISABLE_REPEAT_TYPES_TOOLTIP", 200, 190, IsCompassMarkersOff)
    y = y + 34

    AddCheckboxColumns(self.repeatTypeDefinitions,
        function(key)
            return self.settings.compassRepeatTypes[key] ~= false
        end,
        function(key, value)
            self.settings.compassRepeatTypes[key] = value
            self:MarkCustom()
            RefreshSurface("compass")
        end,
        "COMPASS_QUEST_FILTER_TOOLTIP",
        2, IsCompassMarkersOff)

    AddHeader("WORLD_HEADER")
    AddDescription("WORLD_SAFETY_INFO", true)
    local worldRows = {
        { "WORLD_QUEST_OFFERS", "WORLD_GENERIC_TOOLTIP", "questOffers" },
        { "WORLD_ASSISTED", "WORLD_GENERIC_TOOLTIP", "assistedObjectives" },
        { "WORLD_SECONDARY", "WORLD_GENERIC_TOOLTIP", "secondaryObjectives" },
        { "WORLD_BREADCRUMBS", "WORLD_BREADCRUMBS_TOOLTIP", "breadcrumbs" },
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
    -- A key-up can be swallowed when entering a menu. Clear a stale
    -- hold-to-show navigation state so the next press remains usable.
    if self.helpHeld then self:SetHelpMode(false) end
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
    -- Also guard the reverse transition (menu -> game).
    if self.helpHeld then self:SetHelpMode(false) end
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
