-- -----------------------------------------------------------------------------
-- HUDitorTools - live HUD editor color picker (cloned ZOS keyboard widgets)
-- -----------------------------------------------------------------------------

local HT = HUDitorTools

local PANEL_TEMPLATE = "HUDitorTools_ColorPickerPanel"
local DEFAULT_ANCHOR_OFFSET_X = 24
local DEFAULT_ANCHOR_OFFSET_Y = -24
local INTERACTABLE_LEVEL = ZO_HUD_EDITOR_KEYBOARD_INFO_BOX_INTERACTABLE_ELEMENT_LEVEL

local SLOT_LABEL_NORMAL = ZO_NORMAL_TEXT
local SLOT_LABEL_SELECTED = ZO_SELECTED_TEXT

local ColorPicker = ZO_InitializingObject:Subclass()

local sharedPicker

local SLOT_DEFINITIONS =
{
    {
        childName = "Grid",
        slotName = HT.COLOR_SLOT_GRID,
        label = GetString(SI_HUDITORTOOLS_GRID_LAM_HEADER),
    },
    {
        childName = "Selected",
        slotName = HT.COLOR_SLOT_SELECTED,
        label = GetString(SI_HUDITORTOOLS_COLOR_SELECTED),
    },
    {
        childName = "Unselected",
        slotName = HT.COLOR_SLOT_UNSELECTED,
        label = GetString(SI_HUDITORTOOLS_COLOR_UNSELECTED),
    },
    {
        childName = "Hidden",
        slotName = HT.COLOR_SLOT_HIDDEN,
        label = GetString(SI_HUDITORTOOLS_COLOR_HIDDEN),
    },
}

local function GetColorTable(slotName)
    return HT.SV and HT.SV[slotName]
end

function ColorPicker:Initialize(control)
    self.control = control
    self.activeSlotName = HT.COLOR_SLOT_GRID
    self.suppressApply = false
    self.isUpdatingColors = false
    self.swatchInterpolator = ZO_SimpleControlScaleInterpolator:New(1.0, ZO_DYEING_SWATCH_SELECTION_SCALE)

    control:SetDrawTier(DT_HIGH)
    control:SetDrawLevel(10)
    control:SetMouseEnabled(true)
    control:SetMovable(true)
    control:SetClampedToScreen(true)
    control:SetHidden(true)

    local titleLabel = control:GetNamedChild("Title")
    titleLabel:SetText(GetString(SI_WINDOW_TITLE_COLOR_PICKER))

    local closeButton = control:GetNamedChild("Close")
    closeButton:SetDrawLevel(INTERACTABLE_LEVEL)
    closeButton:SetHandler("OnClicked", function ()
        HT.SetColorPickerVisible(false)
    end)

    local resetButton = control:GetNamedChild("Reset")
    resetButton:SetText(GetString(SI_GROUP_FINDER_FILTERS_RESET)) --"Reset"
    resetButton:SetHandler("OnClicked", function ()
        self:ResetActiveSlot()
    end)

    control:SetHandler("OnMoveStop", function ()
        self:SaveAnchor()
    end)

    self:InitializeSlots()
    self:InitializePickerWidgets()
    self:ApplySavedAnchor()
end

function ColorPicker:InitializeSlots()
    local slotsControl = self.control:GetNamedChild("Slots")
    self.slotControls = {}

    for _, slotDefinition in ipairs(SLOT_DEFINITIONS) do
        local slotControl = slotsControl:GetNamedChild(slotDefinition.childName)
        local dyeSwatch = slotControl:GetNamedChild("Swatch")
        local nameLabel = slotControl:GetNamedChild("Name")
        nameLabel:SetText(slotDefinition.label)
        dyeSwatch:SetSurfaceHidden(ZO_DYEING_LOCK_INDEX, true)
        dyeSwatch:SetSurfaceHidden(ZO_DYEING_NEW_INDEX, true)
        slotControl.slotName = slotDefinition.slotName
        slotControl.dyeSwatch = dyeSwatch
        slotControl.highlightControl = dyeSwatch:GetNamedChild("Highlight")
        slotControl.nameLabel = nameLabel

        local function OnSlotClicked(_, button, upInside)
            if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
                self:SetActiveSlot(slotDefinition.slotName)
            end
        end
        slotControl:SetHandler("OnMouseUp", OnSlotClicked)
        dyeSwatch:SetHandler("OnMouseUp", OnSlotClicked)
        dyeSwatch:SetHandler("OnMouseEnter", function ()
            self.swatchInterpolator:ScaleUp(dyeSwatch)
        end)
        dyeSwatch:SetHandler("OnMouseExit", function ()
            if slotDefinition.slotName ~= self.activeSlotName then
                self.swatchInterpolator:ScaleDown(dyeSwatch)
            end
        end)
        self.slotControls[slotDefinition.slotName] = slotControl
    end
    self:RefreshSlotSwatches()
end

function ColorPicker:InitializePickerWidgets()
    local content = self.control:GetNamedChild("Content")
    self.content = content

    self.colorSelect = content:GetNamedChild("ColorSelect")
    self.colorSelectThumb = self.colorSelect:GetNamedChild("Thumb")
    self.colorSelect:SetColorWheelThumbTextureControl(self.colorSelectThumb)
    self.colorSelect:SetHandler("OnColorSelected", function (_, r, g, b)
        self:OnColorSet(r, g, b)
    end)

    self.valueSlider = content:GetNamedChild("Value")
    self.valueSlider:GetThumbTextureControl():SetDrawLayer(3)
    self.valueTexture = self.valueSlider:GetNamedChild("Texture")
    self.valueSlider:SetHandler("OnValueChanged", function (_, value)
        self:OnValueSet(1 - value)
    end)

    self.alphaLabel = content:GetNamedChild("AlphaLabel")
    self.alphaSlider = content:GetNamedChild("Alpha")
    local alphaThumbTexture = self.alphaSlider:GetThumbTextureControl()
    alphaThumbTexture:SetTextureRotation(ZO_HALF_PI)
    alphaThumbTexture:SetDrawLayer(3)
    self.alphaTexture = self.alphaSlider:GetNamedChild("Texture")
    self.alphaSlider:SetHandler("OnValueChanged", function (_, value)
        self:OnAlphaSet(value)
    end)

    local previewControl = content:GetNamedChild("Preview")
    self.previewInitialTexture = previewControl:GetNamedChild("TextureBottom")
    self.previewCurrentTexture = previewControl:GetNamedChild("TextureTop")

    local function SetColorFromSpinner(r, g, b, a)
        if not self.isUpdatingColors then
            self:SetColor(r, g, b, a)
        end
    end

    local spinners = content:GetNamedChild("Spinners")
    self.redSpinner = ZO_Spinner:New(spinners:GetNamedChild("Red"), 0, 255)
    self.redSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(value / 255, self.greenSpinner:GetValue() / 255, self.blueSpinner:GetValue() / 255, self.alphaSpinner:GetValue() / 255)
    end)
    self.redSpinner:SetNormalColor(ZO_ColorDef:New(1, .2, .2, 1))

    self.greenSpinner = ZO_Spinner:New(spinners:GetNamedChild("Green"), 0, 255)
    self.greenSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(self.redSpinner:GetValue() / 255, value / 255, self.blueSpinner:GetValue() / 255, self.alphaSpinner:GetValue() / 255)
    end)
    self.greenSpinner:SetNormalColor(ZO_ColorDef:New(.2, 1, .2, 1))

    self.blueSpinner = ZO_Spinner:New(spinners:GetNamedChild("Blue"), 0, 255)
    self.blueSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(self.redSpinner:GetValue() / 255, self.greenSpinner:GetValue() / 255, value / 255, self.alphaSpinner:GetValue() / 255)
    end)
    self.blueSpinner:SetNormalColor(ZO_ColorDef:New(.2, .2, 1, 1))

    self.alphaSpinner = ZO_Spinner:New(spinners:GetNamedChild("Alpha"), 0, 255)
    self.alphaSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(self.redSpinner:GetValue() / 255, self.greenSpinner:GetValue() / 255, self.blueSpinner:GetValue() / 255, value / 255)
    end)
end

function ColorPicker:UpdateColors(r, g, b, a)
    self.isUpdatingColors = true

    local fullR, fullG, fullB = self.colorSelect:GetFullValuedColorAsRGB()
    self.valueTexture:SetGradientColors(ORIENTATION_VERTICAL, 0, 0, 0, 1, fullR, fullG, fullB, 1)
    self.previewCurrentTexture:SetColor(r, g, b, a)
    self.alphaTexture:SetGradientColors(ORIENTATION_HORIZONTAL, r, g, b, 0, r, g, b, .85)

    self.redSpinner:SetValue(r * 255)
    self.greenSpinner:SetValue(g * 255)
    self.blueSpinner:SetValue(b * 255)
    self.alphaSpinner:SetValue(a * 255)

    self.isUpdatingColors = false

    if not self.suppressApply then
        self:ApplyLiveColor(r, g, b, a)
    end
end

function ColorPicker:OnColorSet(r, g, b)
    self:UpdateColors(r, g, b, self.alphaSlider:GetValue())
end

function ColorPicker:OnValueSet(value)
    self.colorSelect:SetValue(value)
end

function ColorPicker:OnAlphaSet(value)
    local r, g, b = self.colorSelect:GetColorAsRGB()
    self:UpdateColors(r, g, b, value)
end

function ColorPicker:SetColor(r, g, b, a)
    self.colorSelect:SetColorAsRGB(r, g, b)
    self.valueSlider:SetValue(1 - self.colorSelect:GetValue())
    self.alphaSlider:SetValue(a or 1)
    self:UpdateColors(r, g, b, a or 1)
end

function ColorPicker:ApplyLiveColor(r, g, b, a)
    local colorTable = GetColorTable(self.activeSlotName)
    if colorTable == nil then
        return
    end
    colorTable.r = r
    colorTable.g = g
    colorTable.b = b
    colorTable.a = a
    HT.HUDUI_UpdateColor(self.activeSlotName)
    self:RefreshSlotSwatches()
end

function ColorPicker:RefreshSlotSwatches()
    for slotName, slotControl in pairs(self.slotControls) do
        local colorTable = GetColorTable(slotName)
        if colorTable then
            slotControl.dyeSwatch:SetColor(ZO_DYEING_SWATCH_INDEX, colorTable.r, colorTable.g, colorTable.b, colorTable.a)
        end
        local isActiveSlot = slotName == self.activeSlotName
        slotControl.highlightControl:SetHidden(not isActiveSlot)
        if isActiveSlot then
            slotControl.nameLabel:SetColor(SLOT_LABEL_SELECTED:UnpackRGBA())
            self.swatchInterpolator:ResetToMax(slotControl.dyeSwatch)
        else
            slotControl.nameLabel:SetColor(SLOT_LABEL_NORMAL:UnpackRGBA())
            self.swatchInterpolator:ResetToMin(slotControl.dyeSwatch)
        end
    end
end

function ColorPicker:SetActiveSlot(slotName)
    if HT.SV[slotName] == nil then
        return
    end
    local slotChanged = self.activeSlotName ~= slotName
    self.activeSlotName = slotName
    if slotChanged then
        PlaySound(SOUNDS.DYEING_SWATCH_SELECTED)
    end
    self:LoadActiveSlot()
end

function ColorPicker:LoadActiveSlot()
    local colorTable = GetColorTable(self.activeSlotName)
    if colorTable == nil then
        return
    end
    self.suppressApply = true
    self:SetColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    self.previewInitialTexture:SetColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    self.suppressApply = false
    self:RefreshSlotSwatches()
end

function ColorPicker:ResetActiveSlot()
    HT.ResetSavedColor(self.activeSlotName)
    self:LoadActiveSlot()
end

function ColorPicker:ApplySavedAnchor()
    local control = self.control
    local savedVariables = HT.SV
    control:ClearAnchors()
    if type(savedVariables.colorPickerOffsetX) == "number" and type(savedVariables.colorPickerOffsetY) == "number" then
        control:SetAnchor(TOPLEFT, control:GetParent(), TOPLEFT, savedVariables.colorPickerOffsetX, savedVariables.colorPickerOffsetY)
    else
        control:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, DEFAULT_ANCHOR_OFFSET_X, DEFAULT_ANCHOR_OFFSET_Y)
    end
end

function ColorPicker:SaveAnchor()
    local control = self.control
    local parentControl = control:GetParent()
    HT.SV.colorPickerOffsetX = control:GetLeft() - parentControl:GetLeft()
    HT.SV.colorPickerOffsetY = control:GetTop() - parentControl:GetTop()
end

function ColorPicker:SetHidden(hidden)
    self.control:SetHidden(hidden)
    if not hidden then
        self:LoadActiveSlot()
    end
end

local function GetPicker()
    return sharedPicker
end

function HT.InstallColorPicker()
    if sharedPicker then
        return
    end
    local parentControl = HUD_EDITOR_KEYBOARD.control
    local control = CreateControlFromVirtual(parentControl:GetName() .. "HUDitorToolsColorPicker", parentControl, PANEL_TEMPLATE)
    sharedPicker = ColorPicker:New(control)
    HT.RefreshColorPickerVisibility()
end

function HT.RefreshColorPickerVisibility()
    local picker = GetPicker()
    if not picker then
        return
    end
    local shouldShow = HT.IsEditorShowing() and HT.SV.showColorPicker
    picker:SetHidden(not shouldShow)
end

function HT.SetColorPickerVisible(visible)
    HT.SV.showColorPicker = visible and true or false
    HT.RefreshColorPickerVisibility()
    HT.UpdateInfoBoxSectionVisibility()
end

function HT.ShowColorPickerForSlot(slotName)
    HT.SV.showColorPicker = true
    local picker = GetPicker()
    if picker then
        picker:SetActiveSlot(slotName)
    end
    HT.RefreshColorPickerVisibility()
    HT.UpdateInfoBoxSectionVisibility()
end
