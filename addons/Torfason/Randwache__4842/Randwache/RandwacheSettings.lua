-- RandwacheSettings.lua
-- Dependency-free settings UI and Add-On Manager integration.

local Randwache = _G.Randwache
if not Randwache then return end

local WM = WINDOW_MANAGER
local T = Randwache.Translate
local defaults = Randwache.defaults
local BLUE_R, BLUE_G, BLUE_B = 127 / 255, 199 / 255, 1
local CONTENT_WIDTH = 720

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do
        result[key] = DeepCopy(child)
    end
    return result
end

local function ShowSettingsTooltip(control, text)
    if not text or text == "" then return end

    ClearTooltip(InformationTooltip)

    -- Keep Randwache tooltips completely outside the settings window.
    -- This avoids the settings top-level covering part of the tooltip.
    local settingsWindow = Randwache.settingsWindow
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

    -- Keep the global information tooltip above the Randwache settings window.
    if InformationTooltip.SetDrawTier then InformationTooltip:SetDrawTier(DT_HIGH) end
    if InformationTooltip.SetDrawLayer then InformationTooltip:SetDrawLayer(DL_OVERLAY) end
    if InformationTooltip.SetDrawLevel then InformationTooltip:SetDrawLevel(1000) end
    if InformationTooltip.BringWindowToTop then InformationTooltip:BringWindowToTop() end

    SetTooltipText(InformationTooltip, text)
end

local function AddTooltip(control, text, enableMouse)
    if not control or not text or text == "" then return end

    -- IMPORTANT: Do not automatically make whole rows mouse-enabled.
    -- A mouse-enabled row can sit above its checkbox/slider children and
    -- swallow their clicks. Only dedicated label hotspots request this.
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

local function FormatValue(value, suffix)
    if suffix then
        return string.format("%d %s", zo_round(value), suffix)
    end
    return tostring(zo_round(value))
end

function Randwache:RegisterSettingsRefresher(callback)
    self.settingsRefreshers = self.settingsRefreshers or {}
    self.settingsRefreshers[#self.settingsRefreshers + 1] = callback
end

function Randwache:RefreshSettingsControls()
    if not self.settingsRefreshers then return end
    for _, callback in ipairs(self.settingsRefreshers) do
        callback()
    end
end

function Randwache:CreateSettingsWindow()
    if self.settingsWindow then return end

    self.settingsRefreshers = {}

    local window = WM:CreateTopLevelWindow("RandwacheSettingsWindow")
    self.settingsWindow = window
    window:SetDimensions(820, math.min(820, GuiRoot:GetHeight() - 80))
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    -- Keep the settings below ESO modal dialogs (for example the color picker).
    -- InformationTooltip is raised separately when needed.
    window:SetDrawTier(DT_MEDIUM)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetMouseEnabled(true)
    window:SetHidden(true)
    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        -- Do not lock UI mode. ESO can then close this top-level window with ESC
        -- through its normal HideTopLevels() path.
        SCENE_MANAGER:RegisterTopLevel(window, false)
    end

    local backdrop = WM:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    -- A plain backdrop center is intentionally used instead of ESO's semi-transparent
    -- tooltip texture. This keeps the settings readable over the game menu/world.
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    backdrop:SetInsets(12, 12, -12, -12)
    backdrop:SetCenterColor(0.018, 0.024, 0.035, 1)
    backdrop:SetEdgeColor(BLUE_R, BLUE_G, BLUE_B, 0.95)

    local title = WM:CreateControl(nil, window, CT_LABEL)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 30, 20)
    title:SetFont("ZoFontWinH1")
    title:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
    title:SetText(T("SETTINGS_TITLE"))

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

    local defaultsButton = WM:CreateControlFromVirtual("RandwacheSettingsDefaults", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton:SetText(T("SETTINGS_DEFAULTS"))
    AddTooltip(defaultsButton, T("SETTINGS_DEFAULTS_TT"))
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetSettingsToDefaults()
    end)

    local closeButton = WM:CreateControlFromVirtual("RandwacheSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(T("SETTINGS_CLOSE"))
    closeButton:SetHandler("OnClicked", function()
        self:HideSettings()
    end)

    local scrollContainer = WM:CreateControlFromVirtual("RandwacheSettingsScroll", window, "ZO_ScrollContainer")
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
        return "RandwacheSettings" .. prefix .. tostring(controlId)
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

    local function AddDescription(text)
        local label = WM:CreateControl(NextName("Description"), scroll, CT_LABEL)
        label:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        label:SetWidth(CONTENT_WIDTH - 16)
        label:SetFont("ZoFontGame")
        label:SetColor(0.85, 0.85, 0.85, 1)
        label:SetText(text)
        local h = math.max(42, label:GetTextHeight() + 10)
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

    local function AddSlider(text, minimum, maximum, step, getter, setter, tooltip, suffix, disabled)
        local row = WM:CreateControl(NextName("SliderRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 55)

        local label = WM:CreateControl(NextName("SliderLabel"), row, CT_LABEL)
        label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        label:SetDimensions(500, 20)
        label:SetFont("ZoFontGame")
        label:SetText(text)

        local valueLabel = WM:CreateControl(NextName("SliderValue"), row, CT_LABEL)
        valueLabel:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
        valueLabel:SetDimensions(150, 20)
        valueLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        valueLabel:SetFont("ZoFontGame")

        -- Use a native CT_SLIDER directly instead of the ZO_Options_Slider template.
        -- The latter expects ESO's OptionsWindow initialization and therefore did
        -- not receive mouse input reliably inside our independent settings window.
        local slider = WM:CreateControl(NextName("Slider"), row, CT_SLIDER)
        slider:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 27)
        slider:SetDimensions(CONTENT_WIDTH - 16, 16)
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
        slider:SetValueStep(step)
        if slider.SetAllowDraggingFromThumb then
            slider:SetAllowDraggingFromThumb(true)
        end

        local sliderBackground = WM:CreateControl(NextName("SliderBackground"), slider, CT_BACKDROP)
        sliderBackground:SetAnchor(TOPLEFT, slider, TOPLEFT, 0, 4)
        sliderBackground:SetAnchor(BOTTOMRIGHT, slider, BOTTOMRIGHT, 0, -4)
        sliderBackground:SetCenterColor(0, 0, 0, 0.8)
        sliderBackground:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 32, 4)
        sliderBackground:SetEdgeColor(0.45, 0.45, 0.45, 0.9)
        sliderBackground:SetMouseEnabled(false)

        local updating = false
        slider:SetHandler("OnValueChanged", function(_, value)
            if updating then return end
            local snapped = minimum + zo_round((value - minimum) / step) * step
            if snapped < minimum then snapped = minimum end
            if snapped > maximum then snapped = maximum end
            valueLabel:SetText(FormatValue(snapped, suffix))
        end)
        slider:SetHandler("OnSliderReleased", function(_, value)
            local snapped = minimum + zo_round((value - minimum) / step) * step
            if snapped < minimum then snapped = minimum end
            if snapped > maximum then snapped = maximum end
            slider:SetValue(snapped)
            setter(snapped)
            self:RefreshSettingsControls()
        end)

        AddTooltip(label, tooltip, true)
        AddTooltip(slider, tooltip)

        local function Refresh()
            local value = tonumber(getter()) or minimum
            if value < minimum then value = minimum end
            if value > maximum then value = maximum end
            updating = true
            slider:SetValue(value)
            updating = false
            valueLabel:SetText(FormatValue(value, suffix))
            local isDisabled = disabled and disabled() or false
            if slider.SetEnabled then slider:SetEnabled(not isDisabled) end
            slider:SetMouseEnabled(not isDisabled)
            slider:SetAlpha(isDisabled and 0.35 or 1)
            label:SetAlpha(isDisabled and 0.45 or 1)
            valueLabel:SetAlpha(isDisabled and 0.45 or 1)
        end
        self:RegisterSettingsRefresher(Refresh)
        Refresh()
        y = y + 59
        return row
    end

    local function AddColorPicker(text, getter, setter, tooltip)
        local row = WM:CreateControl(NextName("ColorRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 38)
        row:SetMouseEnabled(true)

        local label = WM:CreateControl(NextName("ColorLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(500, 30)
        label:SetFont("ZoFontGame")
        label:SetText(text)

        local swatch = WM:CreateControl(NextName("ColorSwatch"), row, CT_TEXTURE)
        swatch:SetDimensions(38, 20)
        swatch:SetAnchor(RIGHT, row, RIGHT, -4, 0)

        local border = WM:CreateControl(NextName("ColorBorder"), row, CT_TEXTURE)
        border:SetTexture("EsoUI/Art/ChatWindow/chatOptions_bgColSwatch_frame.dds")
        border:SetTextureCoords(0, 0.625, 0, 0.8125)
        border:SetDimensions(42, 24)
        border:SetAnchor(CENTER, swatch, CENTER, 0, 0)

        local reopenSettingsAfterPicker = false
        local callback = function(r, g, b, a)
            setter(r, g, b, a or 1)
            swatch:SetColor(r, g, b, a or 1)

            -- Randwache is temporarily hidden while ESO's native color picker is
            -- open. Restore it only after ESO confirms or cancels the picker.
            -- This is more robust than trying to compete with the dialog's draw
            -- tier/level, which can differ between ESO UI versions.
            if reopenSettingsAfterPicker then
                reopenSettingsAfterPicker = false
                self:ShowSettings(self.settingsOpenSource)
            end
        end
        row:SetHandler("OnMouseUp", function(_, button, upInside)
            if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then return end
            local r, g, b, a = getter()
            local picker = IsInGamepadPreferredMode() and COLOR_PICKER_GAMEPAD or COLOR_PICKER
            if picker then
                -- ESO's keyboard color picker can otherwise be drawn behind a
                -- custom top-level window. Hide only Randwache's settings for the
                -- lifetime of the picker; its scroll position and controls stay intact.
                reopenSettingsAfterPicker = self.settingsWindow and not self.settingsWindow:IsHidden()
                if reopenSettingsAfterPicker then
                    self:HideSettings()
                end
                picker:Show(callback, r, g, b, a, text)
            end
        end)
        AddTooltip(row, tooltip)

        local function Refresh()
            local r, g, b, a = getter()
            swatch:SetColor(r, g, b, a or 1)
        end
        self:RegisterSettingsRefresher(Refresh)
        Refresh()
        y = y + 42
        return row
    end

    local function AddButton(text, buttonText, callback, tooltip)
        local row = WM:CreateControl(NextName("ButtonRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 38)

        local label = WM:CreateControl(NextName("ButtonLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(430, 30)
        label:SetFont("ZoFontGame")
        label:SetText(text)

        local button = WM:CreateControlFromVirtual(NextName("Button"), row, "ZO_DefaultButton")
        button:SetDimensions(220, 28)
        button:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        button:SetText(buttonText)
        button:SetHandler("OnClicked", callback)
        AddTooltip(button, tooltip)
        y = y + 42
        return row
    end

    AddDescription(T("PANEL_DESCRIPTION"))
    AddCheckbox(T("ENABLE_ADDON"),
        function() return self.sv.enabled end,
        function(v) self.sv.enabled = v self:UpdateAll() end)

    AddHeader(T("HEALTH_HEADER"))
    AddCheckbox(T("HEALTH_ENABLE"),
        function() return self.sv.health.enabled end,
        function(v) self.sv.health.enabled = v self:UpdateAll() end)
    AddSlider(T("HEALTH_THRESHOLD"), 5, 90, 1,
        function() return self.sv.health.threshold end,
        function(v) self.sv.health.threshold = v self:UpdateAll() end,
        nil, "%")
    AddSlider(T("HEALTH_INTENSITY"), 20, 100, 5,
        function() return self.sv.health.intensity or defaults.health.intensity end,
        function(v) self.sv.health.intensity = v self:StartTest("health") end,
        T("HEALTH_INTENSITY_TT"), "%")
    AddColorPicker(T("HEALTH_COLOR"),
        function()
            local c = self.sv.health.color or defaults.health.color
            return tonumber(c.r) or defaults.health.color.r, tonumber(c.g) or defaults.health.color.g, tonumber(c.b) or defaults.health.color.b, tonumber(c.a) or defaults.health.color.a
        end,
        function(r, g, b, a)
            self.sv.health.color = { r = r, g = g, b = b, a = a }
            self:StartTest("health")
        end)
    AddCheckbox(T("HEALTH_RANDOMIZE"),
        function() return self.sv.health.randomize end,
        function(v) self.sv.health.randomize = v if v then self:StartTest("health") end end,
        T("HEALTH_RANDOMIZE_TT"))
    AddCheckbox(T("HEALTH_SPATTERS"),
        function() return self.sv.health.extraSpatters end,
        function(v) self.sv.health.extraSpatters = v self:StartTest("health") end,
        T("HEALTH_SPATTERS_TT"))
    AddCheckbox(T("HEALTH_AFTERBLEED"),
        function() return self.sv.health.afterBleed end,
        function(v)
            self.sv.health.afterBleed = v
            if not v then
                self:HideControls(self.afterBleedSpots)
                self.afterBleedStage = 0
            end
            self:StartTest("health")
        end,
        T("HEALTH_AFTERBLEED_TT"))
    AddSlider(T("HEALTH_AFTERBLEED_INTENSITY"), 20, 100, 5,
        function() return self.sv.health.afterBleedIntensity or defaults.health.afterBleedIntensity end,
        function(v) self.sv.health.afterBleedIntensity = v self:StartTest("health") end,
        T("HEALTH_AFTERBLEED_INTENSITY_TT"), "%",
        function() return not self.sv.health.afterBleed end)
    AddCheckbox(T("HEALTH_PULSE"),
        function() return self.sv.health.pulse end,
        function(v) self.sv.health.pulse = v self:UpdateAll() end)
    AddButton(T("HEALTH_TEST"), T("HEALTH_TEST_BUTTON"), function() self:StartTest("health") end)
    AddButton(T("HEALTH_REROLL"), T("HEALTH_REROLL_BUTTON"), function() self:StartTest("health") end)

    AddHeader(T("MAGICKA_HEADER"))
    AddDescription(T("MAGICKA_DESCRIPTION"))
    AddCheckbox(T("MAGICKA_ENABLE"),
        function() return self.sv.magicka.enabled end,
        function(v) self.sv.magicka.enabled = v self:UpdateAll() end)
    AddSlider(T("MAGICKA_THRESHOLD"), 5, 90, 1,
        function() return self.sv.magicka.threshold end,
        function(v) self.sv.magicka.threshold = v self:UpdateAll() end,
        nil, "%")
    AddSlider(T("MAGICKA_INTENSITY"), 20, 150, 5,
        function() return self.sv.magicka.intensity or defaults.magicka.intensity end,
        function(v) self.sv.magicka.intensity = v self:StartTest("magicka") end,
        nil, "%")
    AddColorPicker(T("MAGICKA_COLOR"),
        function()
            local c = self.sv.magicka.color or defaults.magicka.color
            return tonumber(c.r) or defaults.magicka.color.r, tonumber(c.g) or defaults.magicka.color.g, tonumber(c.b) or defaults.magicka.color.b, tonumber(c.a) or defaults.magicka.color.a
        end,
        function(r, g, b, a)
            self.sv.magicka.color = { r = r, g = g, b = b, a = a }
            self:StartTest("magicka")
        end)
    AddCheckbox(T("MAGICKA_RANDOMIZE"),
        function() return self.sv.magicka.randomize end,
        function(v) self.sv.magicka.randomize = v if v then self:StartTest("magicka") end end)
    AddCheckbox(T("MAGICKA_EXTRA"),
        function() return self.sv.magicka.extraSurges end,
        function(v) self.sv.magicka.extraSurges = v self:StartTest("magicka") end)
    AddCheckbox(T("MAGICKA_DEEPEN"),
        function() return self.sv.magicka.deepen end,
        function(v) self.sv.magicka.deepen = v self:StartTest("magicka") end)
    AddSlider(T("DEEPEN_INTENSITY"), 20, 100, 5,
        function() return self.sv.magicka.deepenIntensity or defaults.magicka.deepenIntensity end,
        function(v) self.sv.magicka.deepenIntensity = v self:StartTest("magicka") end,
        nil, "%", function() return not self.sv.magicka.deepen end)
    AddButton(T("MAGICKA_TEST"), T("MAGICKA_TEST_BUTTON"), function() self:StartTest("magicka") end)

    AddHeader(T("STAMINA_HEADER"))
    AddDescription(T("STAMINA_DESCRIPTION"))
    AddCheckbox(T("STAMINA_ENABLE"),
        function() return self.sv.stamina.enabled end,
        function(v) self.sv.stamina.enabled = v self:UpdateAll() end)
    AddSlider(T("STAMINA_THRESHOLD"), 5, 90, 1,
        function() return self.sv.stamina.threshold end,
        function(v) self.sv.stamina.threshold = v self:UpdateAll() end,
        nil, "%")
    AddSlider(T("STAMINA_INTENSITY"), 20, 150, 5,
        function() return self.sv.stamina.intensity or defaults.stamina.intensity end,
        function(v) self.sv.stamina.intensity = v self:StartTest("stamina") end,
        nil, "%")
    AddColorPicker(T("STAMINA_COLOR"),
        function()
            local c = self.sv.stamina.color or defaults.stamina.color
            return tonumber(c.r) or defaults.stamina.color.r, tonumber(c.g) or defaults.stamina.color.g, tonumber(c.b) or defaults.stamina.color.b, tonumber(c.a) or defaults.stamina.color.a
        end,
        function(r, g, b, a)
            self.sv.stamina.color = { r = r, g = g, b = b, a = a }
            self:StartTest("stamina")
        end)
    AddCheckbox(T("STAMINA_RANDOMIZE"),
        function() return self.sv.stamina.randomize end,
        function(v) self.sv.stamina.randomize = v if v then self:StartTest("stamina") end end)
    AddCheckbox(T("STAMINA_EXTRA"),
        function() return self.sv.stamina.extraClouds end,
        function(v) self.sv.stamina.extraClouds = v self:StartTest("stamina") end)
    AddCheckbox(T("STAMINA_DEEPEN"),
        function() return self.sv.stamina.deepen end,
        function(v) self.sv.stamina.deepen = v self:StartTest("stamina") end)
    AddSlider(T("DEEPEN_INTENSITY"), 20, 100, 5,
        function() return self.sv.stamina.deepenIntensity or defaults.stamina.deepenIntensity end,
        function(v) self.sv.stamina.deepenIntensity = v self:StartTest("stamina") end,
        nil, "%", function() return not self.sv.stamina.deepen end)
    AddButton(T("STAMINA_TEST"), T("STAMINA_TEST_BUTTON"), function() self:StartTest("stamina") end)

    AddHeader(T("DEATH_HEADER"))
    AddDescription(T("DEATH_DESCRIPTION"))
    AddCheckbox(T("DEATH_ENABLE"),
        function() return self.sv.death.enabled end,
        function(v)
            self.sv.death.enabled = v
            self.playerWithoutLife = nil
            self:UpdateDeathState()
        end)
    AddSlider(T("DEATH_DARKNESS"), 70, 100, 1,
        function() return self.sv.death.darkness end,
        function(v)
            self.sv.death.darkness = v
            if self:IsPlayerWithoutLife() then self:StartDeathCloak(true, true) end
        end,
        T("DEATH_DARKNESS_TT"), "%")
    AddSlider(T("DEATH_FADE"), 0, 2000, 100,
        function() return self.sv.death.fadeMs end,
        function(v) self.sv.death.fadeMs = v end,
        T("DEATH_FADE_TT"), "ms")
    AddSlider(T("DEATH_RETURN"), 500, 5000, 100,
        function() return self.sv.death.returnFadeMs end,
        function(v) self.sv.death.returnFadeMs = v end,
        T("DEATH_RETURN_TT"), "ms")
    AddButton(T("DEATH_TEST"), T("DEATH_TEST_BUTTON"), function() self:StartDeathTest() end)

    AddHeader(T("TEST_HEADER"))
    AddButton(T("TEST_ALL"), T("TEST_ALL_BUTTON"), function() self:StartTest("all") end)

    scroll:SetHeight(y + 20)
end

function Randwache:StartDeathTest()
    local oldEnabled = self.sv.death.enabled
    self.deathTestToken = (self.deathTestToken or 0) + 1
    local token = self.deathTestToken

    self.deathTestActive = true
    self.sv.death.enabled = true
    self.deathCloakProgress = 0
    self.deathCloakFrom = 0
    self.deathCloakTo = 1
    self:StartDeathCloak(true, false)

    zo_callLater(function()
        if self.deathTestToken ~= token then return end
        self:StartDeathCloak(false, false)

        zo_callLater(function()
            if self.deathTestToken ~= token then return end
            self.sv.death.enabled = oldEnabled
            self.deathTestActive = false
            self.playerWithoutLife = nil
            self:UpdateDeathState()
            self:RefreshSettingsControls()
        end, math.max(300, tonumber(self.sv.death.returnFadeMs) or 2800) + 150)
    end, math.max(250, tonumber(self.sv.death.fadeMs) or 1250) + 1800)
end

function Randwache:ResetSettingsToDefaults()
    local migrated = self.sv.serverScopeMigrated
    for _, key in ipairs({ "enabled", "death", "health", "magicka", "stamina" }) do
        self.sv[key] = DeepCopy(defaults[key])
    end
    self.sv.serverScopeMigrated = migrated
    self.playerWithoutLife = nil
    self:RandomizeBloodPattern()
    self:RandomizeResourcePattern("magicka")
    self:RandomizeResourcePattern("stamina")
    self:UpdateDeathState()
    self:UpdateAll()
    self:RefreshSettingsControls()
    d("|c7FC7FF" .. T("SETTINGS_DEFAULTS_DONE") .. "|r")
end

function Randwache:ShowSettings(source)
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

function Randwache:HideSettings()
    ClearTooltip(InformationTooltip)
    if not self.settingsWindow then return end
    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

function Randwache:ToggleSettings(source)
    self:CreateSettingsWindow()
    if self.settingsWindow:IsHidden() then
        self:ShowSettings(source)
    else
        self:HideSettings()
    end
end

function Randwache:SetupAddonManagerGear(control, data)
    if not control or not data then return end

    local isRandwache = data.addOnFileName == self.name
    local gear = control.randwacheSettingsGear

    if not gear and isRandwache then
        gear = WM:CreateControl(nil, control, CT_BUTTON)
        control.randwacheSettingsGear = gear
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetClickSound("Click")

        -- Do not use a Unicode gear glyph here: ESO's UI font does not contain it
        -- reliably. The bundled DXT5 texture renders independently of the font.
        local icon = WM:CreateControl(nil, gear, CT_TEXTURE)
        gear.randwacheSettingsIcon = icon
        icon:SetDimensions(20, 20)
        icon:SetAnchor(CENTER, gear, CENTER, 0, 0)
        icon:SetTexture("Randwache/textures/settings_gear.dds")
        icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        icon:SetMouseEnabled(false)

        gear:SetHandler("OnClicked", function()
            self:ShowSettings("addonManager")
        end)
        gear:SetHandler("OnMouseEnter", function(selfControl)
            icon:SetColor(1, 1, 1, 1)
            InitializeTooltip(InformationTooltip, selfControl, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, T("SETTINGS_GEAR_TT"))
        end)
        gear:SetHandler("OnMouseExit", function()
            icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            ClearTooltip(InformationTooltip)
        end)
    end

    if gear then
        gear:SetHidden(not isRandwache)
    end
end

function Randwache:PatchAddonManagerDataTypes()
    local manager = _G.ADD_ON_MANAGER
    if not manager or not manager.list or not ZO_ScrollList_GetDataTypeTable then return false end

    -- Type 1 is the regular row. Expanded rows receive dynamically allocated
    -- type IDs, so scan a modest range and patch whichever tables exist.
    for typeId = 1, 64 do
        local dataType = ZO_ScrollList_GetDataTypeTable(manager.list, typeId)
        if dataType and dataType.setupCallback and not dataType.randwacheSettingsPatched then
            local originalSetup = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                originalSetup(control, data, ...)
                -- Gear integration must never be able to break ESO's add-on list.
                pcall(function()
                    if data and data.addOnFileName then
                        self:SetupAddonManagerGear(control, data)
                    elseif control and control.randwacheSettingsGear then
                        control.randwacheSettingsGear:SetHidden(true)
                    end
                end)
            end
            dataType.randwacheSettingsPatched = true
        end
    end
    return true
end

function Randwache:InstallAddonManagerGear()
    if self.addonManagerGearInstalled then return end
    self.addonManagerGearInstalled = true

    local managerClass = _G.ZO_AddOnManager
    if managerClass and ZO_PostHook then
        ZO_PostHook(managerClass, "SetupTypeId", function()
            pcall(function() self:PatchAddonManagerDataTypes() end)
        end)
        ZO_PostHook(managerClass, "OnShow", function(manager)
            pcall(function()
                self:PatchAddonManagerDataTypes()
                if manager and manager.list and ZO_ScrollList_RefreshVisible then
                    ZO_ScrollList_RefreshVisible(manager.list)
                end
            end)
        end)
    end

    pcall(function() self:PatchAddonManagerDataTypes() end)
end

function Randwache:InstallSettingsCloseBehavior()
    if self.settingsCloseBehaviorInstalled then return end
    self.settingsCloseBehaviorInstalled = true

    -- "Weiterspielen" hides the game-menu scene directly. Since Randwache's
    -- settings are an independent top-level window, close them along with it.
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

function Randwache:BuildSettings()
    -- The settings window is created lazily on first use.
    -- This keeps startup light and makes the Add-On Manager gear optional:
    -- if ESO changes that list in a future update, /randwache remains usable.
    SLASH_COMMANDS["/randwache"] = function()
        self:ToggleSettings("slash")
    end

    self:InstallAddonManagerGear()
    self:InstallSettingsCloseBehavior()
end
