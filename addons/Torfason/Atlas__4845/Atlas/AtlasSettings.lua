local AE = AtlasAddon
local T = AE.T

local wm = WINDOW_MANAGER
local BLUE_R, BLUE_G, BLUE_B = 0.498, 0.780, 1.000
local GOLD_R, GOLD_G, GOLD_B = 0.847, 0.702, 0.365
local PREFERRED_WIDTH = 820
local PREFERRED_HEIGHT = 820
local CONTENT_MARGIN = 50
local DIALOG_ID = "ATLAS_CONFIRM_CLEAR_MAP"

-- Anchor tooltips to the actual hovered control, not to the top of Atlas.
-- ESO's tooltip system handles the final screen-edge adjustment.
local function ShowSettingsTooltip(control, text)
    if not text or text == "" or not InformationTooltip then return end
    ClearTooltip(InformationTooltip)

    local screenW, screenH = GuiRoot:GetDimensions()
    local leftSpace = math.max(0, control:GetLeft() or 0)
    local rightSpace = math.max(0, (screenW or 1920) - (control:GetRight() or 0))
    local belowMiddle = (control:GetTop() or 0) > (screenH or 1080) / 2

    if rightSpace >= leftSpace then
        if belowMiddle then
            InitializeTooltip(InformationTooltip, control, BOTTOMLEFT, 12, 0, BOTTOMRIGHT)
        else
            InitializeTooltip(InformationTooltip, control, TOPLEFT, 12, 0, TOPRIGHT)
        end
    elseif belowMiddle then
        InitializeTooltip(InformationTooltip, control, BOTTOMRIGHT, -12, 0, BOTTOMLEFT)
    else
        InitializeTooltip(InformationTooltip, control, TOPRIGHT, -12, 0, TOPLEFT)
    end

    if InformationTooltip.SetDrawTier then InformationTooltip:SetDrawTier(DT_HIGH) end
    if InformationTooltip.SetDrawLayer then InformationTooltip:SetDrawLayer(DL_OVERLAY) end
    if InformationTooltip.SetDrawLevel then InformationTooltip:SetDrawLevel(1000) end
    if InformationTooltip.BringWindowToTop then InformationTooltip:BringWindowToTop() end
    SetTooltipText(InformationTooltip, text)
end

local function AddLayoutEntry(entry)
    AE.settingsLayoutEntries[#AE.settingsLayoutEntries + 1] = entry
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
    AddLayoutEntry({ kind = "section", control = label })
    return y + 38
end

local function CreateDescription(parent, y, textKey, minimumHeight)
    local label = CreateLabel(parent, "ZoFontGame", { 0.85, 0.85, 0.85, 1 })
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 8, y)
    label:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -8, y)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label.atlasTextKey = textKey
    -- Reserve enough vertical space for the longest of the seven languages.
    -- Static anchors are used by the 2.0 UI; without this, switching to a
    -- longer translation could cause the next section to overlap the text.
    local h = minimumHeight or 42
    for _, translation in pairs(AE.Translations or {}) do
        local sample = translation[textKey]
        if type(sample) == "string" and sample ~= "" then
            label:SetText(sample)
            h = math.max(h, label:GetTextHeight() + 10)
        end
    end
    label:SetText(T[textKey] or "")
    h = math.max(h, label:GetTextHeight() + 10)
    label:SetHeight(h)
    AE.settingsLocalizedLabels[#AE.settingsLocalizedLabels + 1] = label
    AddLayoutEntry({ kind = "description", control = label, minimumHeight = minimumHeight or 42 })
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
    AddLayoutEntry({ kind = "checkbox", control = row, label = checkboxLabel, textKey = textKey })
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
    AddLayoutEntry({ kind = "slider", control = holder, label = label })
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

-- Native ESO combo box: changes only Atlas' SavedVariables, never ESO's CVar.
local function CreateLanguageDropdown(parent, y)
    local holder = wm:CreateControl("AtlasSettingsLanguageRow", parent, CT_CONTROL)
    holder:SetAnchor(TOPLEFT, parent, TOPLEFT, 8, y)
    holder:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -8, y)
    holder:SetHeight(52)

    local label = CreateLabel(holder, "ZoFontGame", { 0.92, 0.92, 0.92, 1 })
    label:SetAnchor(TOPLEFT, holder, TOPLEFT, 0, 2)
    label:SetDimensions(260, 26)
    label.atlasTextKey = "OPTION_LANGUAGE"
    label:SetText(T.OPTION_LANGUAGE or "Language")
    AE.settingsLocalizedLabels[#AE.settingsLocalizedLabels + 1] = label
    AddTooltip(label, function() return T.OPTION_LANGUAGE_TT end, true)

    local container = wm:CreateControlFromVirtual("AtlasSettingsLanguageCombo", holder, "ZO_ComboBox")
    container:SetAnchor(TOPRIGHT, holder, TOPRIGHT, 0, 0)
    container:SetDimensions(290, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    AE.settingsLanguageCombo = combo
    AE.settingsLanguageContainer = container
    AddTooltip(container, function() return T.OPTION_LANGUAGE_TT end)
    AE:RefreshLanguageDropdown()
    AddLayoutEntry({ kind = "language", control = holder, label = label, combo = container })
    return y + 57
end

function AE:RefreshLanguageDropdown()
    local combo = self.settingsLanguageCombo
    if not combo then return end
    local selected = self.settings and self:NormalizeLanguageSetting(self.settings.language) or "auto"
    combo:ClearItems()
    local selectedIndex = 1
    for index, item in ipairs(self.LanguageChoices) do
        local code = item.code
        if code == selected then selectedIndex = index end
        local entry = combo:CreateItemEntry(self:GetLanguageChoiceLabel(code), function()
            -- Rebuilding an open combo box inside its selection callback can
            -- disrupt the ESO dropdown. Refresh it after the click has ended.
            AE.languageDropdownSelecting = true
            AE:SetAddonLanguage(code)
            AE.languageDropdownSelecting = false
            if zo_callLater then
                zo_callLater(function() AE:RefreshLanguageDropdown() end, 1)
            end
        end)
        combo:AddItem(entry)
    end
    -- Suppress the selection callback: rebuilding the menu must never
    -- overwrite a preference, nor trigger recursively another refresh.
    combo:SelectItemByIndex(selectedIndex, true)
end

-- Lay out controls vertically with a responsive preview grid and button rows.
-- Recalculated on screen resize and when translations change their text length.
function AE:LayoutSettingsContent()
    local child = self.settingsScrollChild
    if not child or not self.settingsLayoutEntries then return end
    local available = child:GetWidth()
    if not available or available <= 0 then return end

    local y = 0
    local innerWidth = math.max(120, available - 16)
    local gap = 14
    for _, entry in ipairs(self.settingsLayoutEntries) do
        local c = entry.control
        local kind = entry.kind
        if kind == "section" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 0, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, 0, y)
            c:SetHeight(32)
            y = y + 38
        elseif kind == "description" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
            -- Preserve at least the original space. Longer translations can
            -- grow without covering the next control.
            local h = entry.minimumHeight
            for _, translation in pairs(self.Translations or {}) do
                local sample = translation[c.atlasTextKey]
                if type(sample) == "string" and sample ~= "" then
                    c:SetText(sample)
                    h = math.max(h, c:GetTextHeight() + 10)
                end
            end
            c:SetText(T[c.atlasTextKey] or "")
            h = math.max(h, c:GetTextHeight() + 10)
            c:SetHeight(h)
            y = y + h + 6
        elseif kind == "checkbox" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
            -- Give longer localized checkbox labels room to wrap.
            local rowHeight = 34
            if entry.label then
                entry.label:SetWidth(math.max(90, innerWidth - 44))
                for _, translation in pairs(self.Translations or {}) do
                    local sample = translation[entry.textKey]
                    if type(sample) == "string" and sample ~= "" then
                        entry.label:SetText(sample)
                        rowHeight = math.max(rowHeight, entry.label:GetTextHeight() + 8)
                    end
                end
                entry.label:SetText(T[entry.textKey] or "")
            end
            c:SetHeight(rowHeight)
            y = y + rowHeight + 6
        elseif kind == "language" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
            if innerWidth < 320 then
                entry.combo:ClearAnchors()
                entry.combo:SetAnchor(TOPLEFT, c, TOPLEFT, 0, 29)
                entry.combo:SetWidth(innerWidth)
                entry.label:SetWidth(innerWidth)
                c:SetHeight(66)
                y = y + 71
            else
                entry.combo:ClearAnchors()
                entry.combo:SetAnchor(TOPRIGHT, c, TOPRIGHT, 0, 0)
                local comboW = math.min(290, math.floor(innerWidth * 0.53))
                entry.combo:SetWidth(comboW)
                entry.label:SetWidth(innerWidth - comboW - 12)
                c:SetHeight(44)
                y = y + 49
            end
        elseif kind == "simple" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
            c:SetHeight(26)
            y = y + 30
        elseif kind == "previews" then
            local columns = math.min(3, math.max(1, math.floor((innerWidth + gap) / (190 + gap))))
            local buttonW = math.floor((innerWidth - (columns - 1) * gap) / columns)
            local buttonH, gapY = 116, 12
            for index, item in ipairs(entry.buttons) do
                local col = (index - 1) % columns
                local row = math.floor((index - 1) / columns)
                local button = item.button
                button:ClearAnchors()
                button:SetAnchor(TOPLEFT, child, TOPLEFT, 8 + col * (buttonW + gap), y + row * (buttonH + gapY))
                button:SetDimensions(buttonW, buttonH)
                item.nameLabel:SetWidth(buttonW - 22)
            end
            local rows = math.ceil(#entry.buttons / columns)
            y = y + rows * buttonH + (rows - 1) * gapY + 10
        elseif kind == "selected" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
            c:SetHeight(26)
            y = y + 32
        elseif kind == "slider" then
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
            c:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
            c:SetHeight(59)
            entry.label:SetWidth(math.max(100, innerWidth - 160))
            y = y + 61
        elseif kind == "actions" then
            local stacked = innerWidth < 680
            for i, button in ipairs(entry.buttons) do
                button:ClearAnchors()
                if stacked then
                    button:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y + (i - 1) * 38)
                    button:SetDimensions(innerWidth, 30)
                else
                    local half = math.floor((innerWidth - 12) / 2)
                    button:SetAnchor(TOPLEFT, child, TOPLEFT, 8 + (i - 1) * (half + 12), y)
                    button:SetDimensions(half, 30)
                end
            end
            y = y + (stacked and 82 or 42)
        end
    end
    child:SetHeight(y + 20)
end

function AE:LayoutSettingsWindow()
    if not self.settingsWindow then return end
    local rootW, rootH = GuiRoot:GetDimensions()
    rootW = rootW or 1920
    rootH = rootH or 1080
    local width = math.min(PREFERRED_WIDTH, math.max(240, rootW - 48))
    local height = math.min(PREFERRED_HEIGHT, math.max(280, rootH - 64))
    self.settingsWindow:SetDimensions(width, height)

    if self.settingsTitleLabel then
        self.settingsTitleLabel:SetWidth(math.max(90, width - 240))
    end
    if self.settingsDefaultsButton and self.settingsCloseButton then
        local buttonW = math.min(190, math.max(90, math.floor((width - 80) / 2)))
        self.settingsDefaultsButton:SetWidth(buttonW)
        self.settingsCloseButton:SetWidth(buttonW)
    end
    if self.settingsScrollChild then
        self.settingsScrollChild:SetWidth(math.max(170, width - CONTENT_MARGIN * 2))
        self:LayoutSettingsContent()
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
    if not self.languageDropdownSelecting then self:RefreshLanguageDropdown() end
    self:RefreshSettingsControls()
    self:LayoutSettingsWindow()
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
    self.settings.language = d.language
    self.settings.enabled = d.enabled
    self.settings.style = d.style
    self.settings.opacity = d.opacity
    self.settings.radius = d.radius
    self.settings.subzoneRadius = d.subzoneRadius
    self.settings.exploreSubzones = d.exploreSubzones
    self:RefreshOverlay(true)
    self:SetAddonLanguage(self.settings.language)
end

function AE:CreateSettingsWindow()
    if self.settingsWindow or not wm then return end

    self.settingsLocalizedLabels = {}
    self.settingsLocalizedButtons = {}
    self.settingsCheckboxes = {}
    self.settingsSliders = {}
    self.settingsStyleButtons = {}
    self.settingsLayoutEntries = {}

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
    self.settingsDefaultsButton = defaultsButton

    local closeButton = wm:CreateControlFromVirtual("AtlasSettingsCloseButton", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton.atlasTextKey = "SETTINGS_CLOSE"
    closeButton:SetText(T.SETTINGS_CLOSE or "Close")
    closeButton:SetHandler("OnClicked", function() AE:CloseSettings() end)
    self.settingsLocalizedButtons[#self.settingsLocalizedButtons + 1] = closeButton
    self.settingsCloseButton = closeButton

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
    y = CreateLanguageDropdown(child, y)
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
    AddLayoutEntry({ kind = "simple", control = styleLabel })
    y = y + 30

    -- Die Vorschaukarten erhalten einen eigenen, gut lesbaren Namensbereich.
    -- Text und Namensfeld liegen bewusst über Rahmen und Textur, damit ESO den
    -- unteren Rand nicht durch das Label zeichnet bzw. abschneidet.
    local buttonW, buttonH, gapX, gapY = 220, 116, 18, 12
    local startX = 8
    local styleLayout = { kind = "previews", buttons = {} }
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
        styleLayout.buttons[#styleLayout.buttons + 1] = { button = button, nameLabel = styleName }
        self.settingsStyleButtons[style] = {
            button = button,
            border = border,
            texture = texture,
            nameLabel = styleName,
            index = index,
            style = style,
        }
    end
    AddLayoutEntry(styleLayout)
    y = y + (buttonH * 2) + gapY + 10

    local selected = CreateLabel(child, "ZoFontGameBold", { BLUE_R, BLUE_G, BLUE_B, 1 })
    selected:SetAnchor(TOPLEFT, child, TOPLEFT, 8, y)
    selected:SetAnchor(TOPRIGHT, child, TOPRIGHT, -8, y)
    selected:SetHeight(24)
    self.settingsSelectedStyleLabel = selected
    AddLayoutEntry({ kind = "selected", control = selected })
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
    local reveal = CreateActionButton(child, 8, y, 330, "OPTION_REVEAL", "OPTION_REVEAL_TT", function() AE:RevealCurrentMapFully() end)
    local forget = CreateActionButton(child, 358, y, 330, "OPTION_CLEAR", "OPTION_CLEAR_TT", function() AE:ClearCurrentMap() end)
    AddLayoutEntry({ kind = "actions", buttons = { reveal, forget } })
    y = y + 42

    y = CreateSection(child, y, "OPTION_IMPORT_HEADER")
    y = CreateDescription(child, y, "OPTION_IMPORT_DESC", 74)
    local importOne = CreateActionButton(child, 8, y, 330, "OPTION_IMPORT_CURRENT", "OPTION_IMPORT_CURRENT_TT", function() AE:ImportTrueExploration(false) end)
    local importAll = CreateActionButton(child, 358, y, 330, "OPTION_IMPORT_ALL", "OPTION_IMPORT_ALL_TT", function() AE:ImportTrueExploration(true) end)
    AddLayoutEntry({ kind = "actions", buttons = { importOne, importAll } })
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

-- Restore the Atlas panel only if the scene in which it was opened still
-- exists. Leaving the game menu while a dialog is open must not reopen Atlas.
local function MayRestoreSettingsAfterDialog(data)
    if not data or not data.reopenSettings then return false end
    local oldScene = data.settingsScene
    if oldScene and SCENE_MANAGER then
        if SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() ~= oldScene then
            return false
        end
        if oldScene.GetState then
            local state = oldScene:GetState()
            if state == SCENE_HIDING or state == SCENE_HIDDEN then return false end
        end
    end
    return true
end

-- ESO-native confirmation, no additional library required.
function AE:RegisterClearConfirmationDialog()
    if self.clearDialogRegistered then return end
    if not ZO_Dialogs_RegisterCustomDialog then return end

    ZO_Dialogs_RegisterCustomDialog(DIALOG_ID, {
        title = { text = function() return T.CONFIRM_CLEAR_TITLE end },
        mainText = { text = function() return T.CONFIRM_CLEAR_TEXT end },
        buttons = {
            [1] = {
                text = function() return T.CONFIRM_CLEAR_ACCEPT end,
                callback = function(dialog)
                    local data = dialog and dialog.data
                    if not data then return end
                    AE:ClearConfirmedMap(data.mapKey, data.archiveMap, data.archiveName)
                end,
            },
            [2] = { text = function() return T.CONFIRM_CLEAR_CANCEL end },
        },
        -- Called after the native dialog has actually closed (also on ESC).
        -- This avoids the dialog appearing behind Atlas' own settings panel.
        finishedCallback = function(dialog)
            local data = dialog and dialog.data
            if MayRestoreSettingsAfterDialog(data) then
                AE:OpenSettings(data.settingsSource)
            end
            AE:RestoreArchiveAfterDialog(data)
        end,
    })
    self.clearDialogRegistered = true
end

-- The same native confirmation is used by Current map and the Archive.
-- Archive deletion receives both the immutable map key and the exact original
-- map table. The latter prevents a replaced entry being deleted by mistake.
function AE:RestoreArchiveAfterDialog(data)
    if not data or not data.reopenArchive or not self.archivePanel then return end
    if data.archiveScene and SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene
        and SCENE_MANAGER:GetCurrentScene() ~= data.archiveScene then return end
    if data.archiveScene and data.archiveScene.GetState then
        local state = data.archiveScene:GetState()
        if state == SCENE_HIDDEN or state == SCENE_HIDING then return end
    end
    if ZO_WorldMap_IsWorldMapShowing and not ZO_WorldMap_IsWorldMapShowing() then return end
    self.archivePanel:SetHidden(false)
    self:RefreshArchiveList()
end

function AE:ConfirmClearMapByKey(mapKey, mapName, archiveMap)
    if type(mapKey) ~= "string" or mapKey == "" then self:Msg(T.NO_MAP) return end
    if archiveMap then
        if not self.progress or not self.progress.maps
            or self.progress.maps[mapKey] ~= archiveMap
            or self:CountMapCells(archiveMap) < 1 then
            -- An old row selection must never act on a newer archive entry.
            if self.RefreshArchiveList then self:RefreshArchiveList() end
            return
        end
    end
    if not self.clearDialogRegistered or not ZO_Dialogs_ShowDialog
        or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog()) then
        self:Msg(T.CONFIRM_CLEAR_UNAVAILABLE)
        return
    end

    if InformationTooltip then ClearTooltip(InformationTooltip) end
    local data = { mapKey = mapKey }
    if archiveMap then
        data.archiveMap = archiveMap
        data.archiveName = mapName
        if self.archivePanel and not self.archivePanel:IsHidden() then
            data.reopenArchive = true
            if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
                data.archiveScene = SCENE_MANAGER:GetCurrentScene()
            end
            -- The world-map info panel must not cover ESO's modal dialog.
            self.archivePanel:SetHidden(true)
        end
    elseif self.settingsWindow and not self.settingsWindow:IsHidden() then
        data.reopenSettings = true
        data.settingsSource = self.settingsOpenSource
        if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
            data.settingsScene = SCENE_MANAGER:GetCurrentScene()
        end
        self:CloseSettings()
    end

    local dialog = ZO_Dialogs_ShowDialog(DIALOG_ID, data, { mainTextParams = { mapName } })
    if not dialog then
        if ZO_Dialogs_ReleaseAllDialogsOfName then
            ZO_Dialogs_ReleaseAllDialogsOfName(DIALOG_ID)
        end
        if MayRestoreSettingsAfterDialog(data) then
            self:OpenSettings(data.settingsSource)
        end
        self:RestoreArchiveAfterDialog(data)
        self:Msg(T.CONFIRM_CLEAR_UNAVAILABLE)
    end
end

function AE:ConfirmClearCurrentMap()
    local key = self:GetCurrentMapPath()
    if not key then self:Msg(T.NO_MAP) return end
    local name = (GetMapName and GetMapName()) or ""
    if name == "" then name = key end
    self:ConfirmClearMapByKey(key, name)
end

function AE:ConfirmClearArchivedMap(entry)
    if not entry or type(entry.key) ~= "string" or type(entry.map) ~= "table" then return end
    self:ConfirmClearMapByKey(entry.key, entry.name or entry.key, entry.map)
end
function AE:SetupSettings()
    self:RegisterClearConfirmationDialog()
    self:CreateSettingsWindow()
    self:InstallSettingsCloseBehavior()
    EVENT_MANAGER:RegisterForEvent("AtlasSettingsScreenResize", EVENT_SCREEN_RESIZED, function()
        AE:LayoutSettingsWindow()
    end)
end

