local AE = AtlasAddon
local T = AE.T

local wm = WINDOW_MANAGER
local BLUE_R, BLUE_G, BLUE_B = 0.498, 0.780, 1.000
local GOLD_R, GOLD_G, GOLD_B = 0.847, 0.702, 0.365
local PREFERRED_WIDTH = 820
local PREFERRED_HEIGHT = 820
local MIN_WIDTH = 660
local MIN_HEIGHT = 560
local CONTENT_MARGIN = 50

local function ShowSettingsTooltip(control, text)
    if not text or text == "" or not InformationTooltip then return end

    ClearTooltip(InformationTooltip)

    local settingsWindow = AE.settingsWindow
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

local function AddTooltip(control, textGetter, enableMouse)
    if not control or type(textGetter) ~= "function" then return end
    if enableMouse then control:SetMouseEnabled(true) end

    control:SetHandler("OnMouseEnter", function(self)
        ShowSettingsTooltip(self, tostring(textGetter() or ""))
    end, "AtlasTooltip")
    control:SetHandler("OnMouseExit", function()
        if InformationTooltip then ClearTooltip(InformationTooltip) end
    end, "AtlasTooltip")
end

local function CreateLabel(parent, font, color)
    local label = wm:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetColor(unpack(color or { 0.92, 0.92, 0.92, 1 }))
    return label
end

local function CreateSection(parent, y, textKey)
    local label = CreateLabel(parent, "ZoFontWinH2", { BLUE_R, BLUE_G, BLUE_B, 1 })
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    label:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y)
    label:SetHeight(32)
    label.atlasTextKey = textKey
    label:SetText(T[textKey] or textKey)
    AE.settingsLocalizedLabels[#AE.settingsLocalizedLabels + 1] = label
    return y + 38
end

local function CreateDescription(parent, y, textKey, minimumHeight)
    local label = CreateLabel(parent, "ZoFontGame", { 0.85, 0.85, 0.85, 1 })
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 8, y)
    label:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -8, y)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label.atlasTextKey = textKey
    label:SetText(T[textKey] or "")
    local h = math.max(minimumHeight or 42, label:GetTextHeight() + 10)
    label:SetHeight(h)
    AE.settingsLocalizedLabels[#AE.settingsLocalizedLabels + 1] = label
    return y + h + 6
end

local function CreateCheckbox(parent, y, textKey, tooltipKey, getFunc, setFunc)
    local index = #AE.settingsCheckboxes + 1
    local row = wm:CreateControl("AtlasSettingsCheckboxRow" .. tostring(index), parent, CT_CONTROL)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 8, y)
    row:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -8, y)
    row:SetHeight(32)

    local checkboxName = "AtlasSettingsCheckbox" .. tostring(index)
    local checkbox = wm:CreateControlFromVirtual(checkboxName, row, "ZO_CheckButton")
    checkbox:SetAnchor(LEFT, row, LEFT, 0, 0)
    checkbox:SetMouseEnabled(true)
    ZO_CheckButton_SetLabelText(checkbox, T[textKey] or textKey)
    checkbox.atlasTextKey = textKey
    checkbox.atlasGetFunc = getFunc
    checkbox.atlasSetFunc = setFunc
    checkbox.atlasTooltipKey = tooltipKey
    ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
        setFunc(checked)
        AE:RefreshSettingsControls()
    end)
    ZO_CheckButton_SetCheckState(checkbox, not not getFunc())

    local checkboxLabel = GetControl(checkbox, "Label")
    AddTooltip(checkboxLabel or checkbox, function() return T[tooltipKey] end, checkboxLabel ~= nil)

    AE.settingsCheckboxes[#AE.settingsCheckboxes + 1] = checkbox
    return y + 34
end

local function CreateSlider(parent, y, textKey, tooltipKey, minimum, maximum, step, getFunc, setFunc, suffix)
    local index = #AE.settingsSliders + 1
    local holder = wm:CreateControl("AtlasSettingsSliderRow" .. tostring(index), parent, CT_CONTROL)
    holder:SetAnchor(TOPLEFT, parent, TOPLEFT, 8, y)
    holder:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -8, y)
    holder:SetHeight(55)

    local label = CreateLabel(holder, "ZoFontGame", { 0.92, 0.92, 0.92, 1 })
    label:SetAnchor(TOPLEFT, holder, TOPLEFT, 0, 0)
    label:SetDimensions(500, 20)
    label.atlasTextKey = textKey
    label:SetText(T[textKey] or textKey)
    AE.settingsLocalizedLabels[#AE.settingsLocalizedLabels + 1] = label

    local valueLabel = CreateLabel(holder, "ZoFontGame", { 0.92, 0.92, 0.92, 1 })
    valueLabel:SetAnchor(TOPRIGHT, holder, TOPRIGHT, 0, 0)
    valueLabel:SetDimensions(150, 20)
    valueLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local slider = wm:CreateControl("AtlasSettingsSlider" .. tostring(index), holder, CT_SLIDER)
    slider:SetAnchor(TOPLEFT, holder, TOPLEFT, 0, 27)
    slider:SetAnchor(TOPRIGHT, holder, TOPRIGHT, 0, 27)
    slider:SetHeight(16)
    slider:SetMouseEnabled(true)
    slider:SetOrientation(ORIENTATION_HORIZONTAL)
    slider:SetThumbTexture(
        "EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds",
        nil,
        8,
        16
    )
    slider:SetMinMax(minimum, maximum)
    slider:SetValueStep(step or 1)
    if slider.SetAllowDraggingFromThumb then slider:SetAllowDraggingFromThumb(true) end

    local bg = wm:CreateControl("AtlasSettingsSliderBackground" .. tostring(index), slider, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, slider, TOPLEFT, 0, 4)
    bg:SetAnchor(BOTTOMRIGHT, slider, BOTTOMRIGHT, 0, -4)
    bg:SetCenterColor(0, 0, 0, 0.8)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 32, 4)
    bg:SetEdgeColor(0.45, 0.45, 0.45, 0.9)
    bg:SetMouseEnabled(false)

    slider.atlasGetFunc = getFunc
    slider.atlasSetFunc = setFunc
    slider.atlasValueLabel = valueLabel
    slider.atlasHolder = holder
    slider.atlasSuffix = suffix or ""

    local updating = false
    local function Snap(value)
        local unit = step or 1
        local rounded = minimum + zo_round((value - minimum) / unit) * unit
        if rounded < minimum then rounded = minimum end
        if rounded > maximum then rounded = maximum end
        return rounded
    end

    slider:SetHandler("OnValueChanged", function(_, value)
        if updating then return end
        local rounded = Snap(value)
        valueLabel:SetText(tostring(rounded) .. (suffix or ""))
    end)
    slider:SetHandler("OnSliderReleased", function(_, value)
        local rounded = Snap(value)
        updating = true
        slider:SetValue(rounded)
        updating = false
        setFunc(rounded)
        AE:RefreshSettingsControls()
    end)

    AddTooltip(label, function() return T[tooltipKey] end, true)
    AddTooltip(slider, function() return T[tooltipKey] end)

    slider:SetValue(getFunc())
    valueLabel:SetText(tostring(getFunc()) .. (suffix or ""))
    AE.settingsSliders[#AE.settingsSliders + 1] = slider
    return y + 59
end

local function CreateActionButton(parent, x, y, width, textKey, tooltipKey, callback)
    local buttonName = "AtlasSettingsActionButton" .. tostring(#AE.settingsLocalizedButtons + 1)
    local button = wm:CreateControlFromVirtual(buttonName, parent, "ZO_DefaultButton")
    button:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    button:SetDimensions(width, 30)
    button.atlasTextKey = textKey
    button:SetText(T[textKey] or textKey)
    button:SetHandler("OnClicked", callback)
    AddTooltip(button, function() return T[tooltipKey] end)
    AE.settingsLocalizedButtons[#AE.settingsLocalizedButtons + 1] = button
    return button
end

function AE:LayoutSettingsWindow()
    if not self.settingsWindow then return end

    local rootW, rootH = GuiRoot:GetDimensions()
    rootW = rootW or 1920
    rootH = rootH or 1080

    local width = math.min(PREFERRED_WIDTH, math.max(MIN_WIDTH, rootW - 80))
    local height = math.min(PREFERRED_HEIGHT, math.max(MIN_HEIGHT, rootH - 80))
    self.settingsWindow:SetDimensions(width, height)

    if self.settingsScrollChild then
        self.settingsScrollChild:SetWidth(math.max(560, width - (CONTENT_MARGIN * 2)))
    end
end

function AE:RefreshSettingsLocalization()
    for _, label in ipairs(self.settingsLocalizedLabels or {}) do
        if label.atlasTextKey then label:SetText(T[label.atlasTextKey] or label.atlasTextKey) end
    end
    for _, button in ipairs(self.settingsLocalizedButtons or {}) do
        if button.atlasTextKey then button:SetText(T[button.atlasTextKey] or button.atlasTextKey) end
    end
    if self.settingsTitleLabel then self.settingsTitleLabel:SetText(T.SETTINGS_TITLE or ((T.NAME or "Atlas") .. " - Settings")) end
    if self.settingsVersionLabel then self.settingsVersionLabel:SetText("v" .. tostring(self.version)) end
    if self.settingsSelectedStyleLabel then
        self.settingsSelectedStyleLabel:SetText(string.format(T.SETTINGS_SELECTED_STYLE or "%s: %s", T.OPTION_SELECTED or "Selected", self:GetStyleName()))
    end
    for _, entry in pairs(self.settingsStyleButtons or {}) do
        if entry.nameLabel and entry.index then
            entry.nameLabel:SetText((T.STYLE_NAMES or {})[entry.index] or entry.style or "")
        end
    end
    self:RefreshSettingsControls()
    if self.RefreshArchiveLocalization then self:RefreshArchiveLocalization() end
end

function AE:RefreshSettingsControls()
    if not self.settings then return end

    for _, checkbox in ipairs(self.settingsCheckboxes or {}) do
        if checkbox.atlasTextKey then ZO_CheckButton_SetLabelText(checkbox, T[checkbox.atlasTextKey] or checkbox.atlasTextKey) end
        if checkbox.atlasGetFunc then ZO_CheckButton_SetCheckState(checkbox, checkbox.atlasGetFunc()) end
    end

    for _, slider in ipairs(self.settingsSliders or {}) do
        if slider.atlasGetFunc then
            local value = slider.atlasGetFunc()
            slider:SetValue(value)
            if slider.atlasValueLabel then slider.atlasValueLabel:SetText(tostring(value) .. (slider.atlasSuffix or "")) end
        end
    end

    if self.settingsSubzoneRadiusSlider then
        local enabled = self.settings.exploreSubzones == true
        self.settingsSubzoneRadiusSlider:SetEnabled(enabled)
        if self.settingsSubzoneRadiusSlider.atlasHolder then
            self.settingsSubzoneRadiusSlider.atlasHolder:SetAlpha(enabled and 1 or 0.45)
        else
            self.settingsSubzoneRadiusSlider:SetAlpha(enabled and 1 or 0.45)
        end
    end

    for style, entry in pairs(self.settingsStyleButtons or {}) do
        local selected = style == (self.settings.style or self.defaultsSettings.style)
        if entry.border then
            if selected then entry.border:SetEdgeColor(BLUE_R, BLUE_G, BLUE_B, 1)
            else entry.border:SetEdgeColor(0.33, 0.31, 0.27, 0.9) end
        end
        if entry.nameLabel then
            if selected then entry.nameLabel:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            else entry.nameLabel:SetColor(0.90, 0.90, 0.90, 1) end
        end
    end

    if self.settingsSelectedStyleLabel then
        self.settingsSelectedStyleLabel:SetText(string.format(T.SETTINGS_SELECTED_STYLE or "%s: %s", T.OPTION_SELECTED or "Selected", self:GetStyleName()))
    end
end

function AE:ResetSettingsToDefaults()
    local d = self.defaultsSettings
    self.settings.enabled = d.enabled
    self.settings.style = d.style
    self.settings.opacity = d.opacity
    self.settings.radius = d.radius
    self.settings.subzoneRadius = d.subzoneRadius
    self.settings.exploreSubzones = d.exploreSubzones
    self:RefreshOverlay(true)
    self:RefreshSettingsLocalization()
end

function AE:CreateSettingsWindow()
    if self.settingsWindow or not wm then return end

    self.settingsLocalizedLabels = {}
    self.settingsLocalizedButtons = {}
    self.settingsCheckboxes = {}
    self.settingsSliders = {}
    self.settingsStyleButtons = {}

    local window = wm:CreateTopLevelWindow("AtlasSettingsWindow")
    self.settingsWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(false)
    window:SetDrawTier(DT_MEDIUM)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetHidden(true)

    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        SCENE_MANAGER:RegisterTopLevel(window, false)
    end

    local backdrop = wm:CreateControl("AtlasSettingsBackdrop", window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    backdrop:SetInsets(12, 12, -12, -12)
    backdrop:SetCenterColor(0.018, 0.024, 0.035, 1)
    backdrop:SetEdgeColor(BLUE_R, BLUE_G, BLUE_B, 0.95)
    self.settingsBackdrop = backdrop

    local title = CreateLabel(window, "ZoFontWinH1", { BLUE_R, BLUE_G, BLUE_B, 1 })
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 30, 20)
    title:SetDimensions(590, 34)
    title:SetText(T.SETTINGS_TITLE or "Atlas - Settings")
    self.settingsTitleLabel = title

    local version = CreateLabel(window, "ZoFontGameSmall", { 0.72, 0.72, 0.72, 1 })
    version:SetAnchor(TOPRIGHT, window, TOPRIGHT, -30, 28)
    version:SetDimensions(150, 20)
    version:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    version:SetText("v" .. tostring(self.version))
    self.settingsVersionLabel = version

    local divider = wm:CreateControl("AtlasSettingsHeaderDivider", window, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    divider:SetAnchor(TOPRIGHT, window, TOPRIGHT, -30, 56)
    divider:SetHeight(2)
    divider:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")
    divider:SetColor(BLUE_R, BLUE_G, BLUE_B, 0.65)

    local defaultsButton = wm:CreateControlFromVirtual("AtlasSettingsDefaultsButton", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton.atlasTextKey = "SETTINGS_DEFAULTS"
    defaultsButton:SetText(T.SETTINGS_DEFAULTS or "Defaults")
    defaultsButton:SetHandler("OnClicked", function() AE:ResetSettingsToDefaults() end)
    AddTooltip(defaultsButton, function() return T.SETTINGS_DEFAULTS_TT end)
    self.settingsLocalizedButtons[#self.settingsLocalizedButtons + 1] = defaultsButton

    local closeButton = wm:CreateControlFromVirtual("AtlasSettingsCloseButton", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton.atlasTextKey = "SETTINGS_CLOSE"
    closeButton:SetText(T.SETTINGS_CLOSE or "Close")
    closeButton:SetHandler("OnClicked", function() AE:CloseSettings() end)
    self.settingsLocalizedButtons[#self.settingsLocalizedButtons + 1] = closeButton

    local scroll = wm:CreateControlFromVirtual("AtlasSettingsScroll", window, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, window, TOPLEFT, 32, 68)
    scroll:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -32, -66)
    if ZO_Scroll_SetUseFadeGradient then ZO_Scroll_SetUseFadeGradient(scroll, false) end
    self.settingsScroll = scroll
    local child = GetControl(scroll, "ScrollChild") or scroll:GetNamedChild("ScrollChild")
    self.settingsScrollChild = child

    self:LayoutSettingsWindow()

    local y = 0
    y = CreateDescription(child, y, "OPTION_DESCRIPTION", 42)

    y = CreateSection(child, y, "SETTINGS_GENERAL_HEADER")
    y = CreateCheckbox(child, y, "OPTION_ENABLED", "OPTION_ENABLED_TT",
        function() return AE.settings.enabled end,
        function(value)
            AE.settings.enabled = value
            AE:RefreshOverlay(true)
        end)

    y = CreateSection(child, y, "SETTINGS_APPEARANCE_HEADER")

    local styleLabel = CreateLabel(child, "ZoFontGame", { 0.92, 0.92, 0.92, 1 })
    styleLabel:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
    styleLabel:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
    styleLabel:SetHeight(24)
    styleLabel.atlasTextKey = "OPTION_STYLE"
    styleLabel:SetText(T.OPTION_STYLE)
    self.settingsLocalizedLabels[#self.settingsLocalizedLabels + 1] = styleLabel
    AddTooltip(styleLabel, function() return T.OPTION_STYLE_TT end, true)
    y = y + 30

    -- Die Vorschaukarten erhalten einen eigenen, gut lesbaren Namensbereich.
    -- Text und Namensfeld liegen bewusst über Rahmen und Textur, damit ESO den
    -- unteren Rand nicht durch das Label zeichnet bzw. abschneidet.
    local buttonW, buttonH, gapX, gapY = 220, 116, 18, 12
    local startX = 8
    for index, style in ipairs(self.LanguageStyleValues or {}) do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        local x = startX + column * (buttonW + gapX)
        local button = wm:CreateControl("AtlasSettingsStyleButton" .. tostring(index), child, CT_BUTTON)
        button:SetAnchor(TOPLEFT, child, TOPLEFT, x, y + row * (buttonH + gapY))
        button:SetDimensions(buttonW, buttonH)
        button.styleValue = style

        local border = wm:CreateControl("AtlasSettingsStyleBorder" .. tostring(index), button, CT_BACKDROP)
        border:SetAnchorFill(button)
        -- Der Backdrop dient hier nur als Rahmen. Ein deckendes Center würde
        -- die eigentliche Stil-Vorschautextur überzeichnen.
        border:SetCenterColor(0, 0, 0, 0)
        border:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
        border:SetInsets(8, 8, -8, -8)
        border:SetEdgeColor(0.33, 0.31, 0.27, 0.9)
        if border.SetDrawLayer and _G.DL_CONTROLS then border:SetDrawLayer(DL_CONTROLS) end
        if border.SetDrawLevel then border:SetDrawLevel(1) end
        border:SetMouseEnabled(false)

        local texture = wm:CreateControl("AtlasSettingsStyleTexture" .. tostring(index), button, CT_TEXTURE)
        texture:SetAnchor(TOPLEFT, button, TOPLEFT, 7, 7)
        texture:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -7, -35)
        texture:SetTexture(self:GetStyleTextureFor(style))
        texture:SetTextureCoords(0, 1, 0, 1)
        texture:SetColor(1, 1, 1, 1)
        texture:SetAlpha(1)
        if texture.SetDrawLayer and _G.DL_CONTROLS then texture:SetDrawLayer(DL_CONTROLS) end
        if texture.SetDrawLevel then texture:SetDrawLevel(1) end
        texture:SetMouseEnabled(false)

        local nameBackground = wm:CreateControl("AtlasSettingsStyleNameBackground" .. tostring(index), button, CT_BACKDROP)
        nameBackground:SetAnchor(BOTTOMLEFT, button, BOTTOMLEFT, 7, -7)
        nameBackground:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -7, -7)
        nameBackground:SetHeight(29)
        nameBackground:SetCenterColor(0, 0, 0, 0.92)
        if nameBackground.SetDrawLayer and _G.DL_OVERLAY then nameBackground:SetDrawLayer(DL_OVERLAY) end
        if nameBackground.SetDrawLevel then nameBackground:SetDrawLevel(4) end
        nameBackground:SetMouseEnabled(false)

        local styleName = CreateLabel(button, "ZoFontGame", { 0.95, 0.95, 0.95, 1 })
        styleName:SetAnchor(CENTER, nameBackground, CENTER, 0, 0)
        styleName:SetDimensions(buttonW - 22, 24)
        styleName:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        styleName:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if styleName.SetDrawLayer and _G.DL_OVERLAY then styleName:SetDrawLayer(DL_OVERLAY) end
        if styleName.SetDrawLevel then styleName:SetDrawLevel(6) end
        styleName:SetText((T.STYLE_NAMES or {})[index] or style)
        styleName:SetMouseEnabled(false)

        button:SetHandler("OnClicked", function()
            AE.settings.style = style
            AE:RefreshOverlay(true)
            AE:RefreshSettingsControls()
        end)
        AddTooltip(button, function()
            local names = T.STYLE_NAMES or {}
            local tips = T.STYLE_TOOLTIPS or {}
            return (names[index] or style) .. "\n" .. (tips[index] or "")
        end)
        self.settingsStyleButtons[style] = {
            button = button,
            border = border,
            texture = texture,
            nameLabel = styleName,
            index = index,
            style = style,
        }
    end
    y = y + (buttonH * 2) + gapY + 10

    local selected = CreateLabel(child, "ZoFontGameBold", { BLUE_R, BLUE_G, BLUE_B, 1 })
    selected:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
    selected:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
    selected:SetHeight(24)
    self.settingsSelectedStyleLabel = selected
    y = y + 32

    y = CreateSlider(child, y, "OPTION_OPACITY", "OPTION_OPACITY_TT", 10, 100, 1,
        function() return math.floor((AE.settings.opacity or 1) * 100 + 0.5) end,
        function(value)
            AE.settings.opacity = value / 100
            AE:RefreshOverlay(true)
        end,
        "%")

    y = CreateSection(child, y, "SETTINGS_EXPLORATION_HEADER")
    y = CreateSlider(child, y, "OPTION_RADIUS", "OPTION_RADIUS_TT", 1, 8, 1,
        function() return AE.settings.radius or AE.defaultsSettings.radius end,
        function(value) AE.settings.radius = value end)

    y = CreateCheckbox(child, y, "OPTION_SUBZONES", "OPTION_SUBZONES_TT",
        function() return AE.settings.exploreSubzones end,
        function(value)
            AE.settings.exploreSubzones = value
            AE:RefreshOverlay(true)
        end)

    local beforeSub = #self.settingsSliders
    y = CreateSlider(child, y, "OPTION_SUBRADIUS", "OPTION_SUBRADIUS_TT", 1, 8, 1,
        function() return AE.settings.subzoneRadius or AE.defaultsSettings.subzoneRadius end,
        function(value) AE.settings.subzoneRadius = value end)
    self.settingsSubzoneRadiusSlider = self.settingsSliders[beforeSub + 1]

    y = CreateSection(child, y, "OPTION_CURRENT_HEADER")
    CreateActionButton(child, 8, y, 330, "OPTION_REVEAL", "OPTION_REVEAL_TT", function() AE:RevealCurrentMapFully() end)
    CreateActionButton(child, 358, y, 330, "OPTION_CLEAR", "OPTION_CLEAR_TT", function() AE:ClearCurrentMap() end)
    y = y + 42

    y = CreateSection(child, y, "OPTION_IMPORT_HEADER")
    y = CreateDescription(child, y, "OPTION_IMPORT_DESC", 74)
    CreateActionButton(child, 8, y, 330, "OPTION_IMPORT_CURRENT", "OPTION_IMPORT_CURRENT_TT", function() AE:ImportTrueExploration(false) end)
    CreateActionButton(child, 358, y, 330, "OPTION_IMPORT_ALL", "OPTION_IMPORT_ALL_TT", function() AE:ImportTrueExploration(true) end)
    y = y + 42

    y = CreateSection(child, y, "OPTION_COMMANDS_HEADER")
    y = CreateDescription(child, y, "OPTION_COMMANDS", 52)

    child:SetHeight(y + 20)
    self:RefreshSettingsLocalization()
end

function AE:OpenSettings(source)
    if not self.settingsWindow then self:CreateSettingsWindow() end
    if not self.settingsWindow then return end
    self.settingsOpenSource = source
    self:RefreshSettingsLocalization()
    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then
        SCENE_MANAGER:ShowTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(false)
    end
    if self.settingsWindow.BringWindowToTop then self.settingsWindow:BringWindowToTop() end
end

function AE:CloseSettings()
    if InformationTooltip then ClearTooltip(InformationTooltip) end
    if not self.settingsWindow then return end
    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

function AE:InstallSettingsCloseBehavior()
    if self.settingsCloseBehaviorInstalled then return end
    self.settingsCloseBehaviorInstalled = true

    if SCENE_MANAGER and SCENE_MANAGER.GetScene then
        local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
        if gameMenuScene and gameMenuScene.RegisterCallback then
            gameMenuScene:RegisterCallback("StateChange", function(_, newState)
                if (newState == SCENE_HIDING or newState == SCENE_HIDDEN)
                    and self.settingsWindow and not self.settingsWindow:IsHidden() then
                    self:CloseSettings()
                end
            end)
        end
    end
end

function AE:SetupSettings()
    self:CreateSettingsWindow()
    self:InstallSettingsCloseBehavior()
    EVENT_MANAGER:RegisterForEvent("AtlasSettingsScreenResize", EVENT_SCREEN_RESIZED, function()
        AE:LayoutSettingsWindow()
    end)
end

