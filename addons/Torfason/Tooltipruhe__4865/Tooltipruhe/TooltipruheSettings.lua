-- TooltipruheSettings.lua
-- Dependency-free settings UI and Add-On Manager integration.
-- Window structure intentionally mirrors Randwache 2.0.0.

local TR = _G.Tooltipruhe
if not TR then return end

local WM = WINDOW_MANAGER
local L = TR.L or {}
local BLUE_R, BLUE_G, BLUE_B = 127 / 255, 199 / 255, 1
local CONTENT_WIDTH = 720

local function T(key)
    return L[key] or key
end

local function ShowSettingsTooltip(control, text)
    if not text or text == "" then return end

    ClearTooltip(InformationTooltip)

    -- Match Randwache: keep setting tooltips completely outside the window.
    local settingsWindow = TR.settingsWindow
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

function TR:RegisterSettingsRefresher(callback)
    self.settingsRefreshers = self.settingsRefreshers or {}
    self.settingsRefreshers[#self.settingsRefreshers + 1] = callback
end

function TR:RefreshSettingsControls()
    if not self.settingsRefreshers then return end
    for _, callback in ipairs(self.settingsRefreshers) do
        callback()
    end
end

function TR:CreateSettingsWindow()
    if self.settingsWindow then return end

    self.settingsRefreshers = {}

    local window = WM:CreateTopLevelWindow("TooltipruheSettingsWindow")
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
    -- ESC can hide registered top-level windows directly. Tooltipruhe additionally
    -- needs to leave position-edit mode cleanly when that happens.
    window:SetHandler("OnHide", function()
        ClearTooltip(InformationTooltip)
        if self.editMode then
            self:SetEditMode(false, true)
        end
    end)

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

    local defaultsButton = WM:CreateControlFromVirtual("TooltipruheSettingsDefaults", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton:SetText(T("DEFAULTS"))
    AddTooltip(defaultsButton, T("DEFAULTS_TT"))
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetSettingsToDefaults()
    end)

    local closeButton = WM:CreateControlFromVirtual("TooltipruheSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(T("CLOSE"))
    closeButton:SetHandler("OnClicked", function()
        self:HideSettings()
    end)

    local scrollContainer = WM:CreateControlFromVirtual("TooltipruheSettingsScroll", window, "ZO_ScrollContainer")
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
        return "TooltipruheSettings" .. prefix .. tostring(controlId)
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

    local function AddButton(text, buttonText, callback, tooltip, disabled)
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

        if disabled then
            local function Refresh()
                local isDisabled = disabled() == true
                button:SetEnabled(not isDisabled)
                label:SetColor(isDisabled and 0.45 or 1, isDisabled and 0.45 or 1, isDisabled and 0.45 or 1, 1)
            end
            self:RegisterSettingsRefresher(Refresh)
            Refresh()
        end

        y = y + 42
        return row, button
    end

    AddDescription(T("SETTINGS_DESCRIPTION"))

    AddHeader(T("SECTION_DISPLAY"))
    AddCheckbox(T("NORMAL_BEHAVIOR"),
        function() return self.savedVariables.permanentEnabled == true end,
        function(v) self:SetPermanentEnabled(v) end,
        T("NORMAL_BEHAVIOR_TT"))
    AddCheckbox(T("CHAT_MESSAGES"),
        function() return self.savedVariables.chatMessages ~= false end,
        function(v) self.savedVariables.chatMessages = v == true end,
        T("CHAT_MESSAGES_TT"))

    AddHeader(T("SECTION_POSITION"))
    AddCheckbox(T("USE_POSITIONING"),
        function() return self.savedVariables.usePositioning ~= false end,
        function(v) self:SetUsePositioning(v) end,
        T("USE_POSITIONING_TT"))
    AddButton(T("EDIT_POSITIONS_LABEL"), T("EDIT_POSITIONS"),
        function()
            self:ToggleEditMode()
            self:RefreshSettingsControls()
        end,
        T("EDIT_POSITIONS_TT"),
        function() return self.savedVariables.usePositioning == false end)
    AddButton(T("RESET_POSITIONS_LABEL"), T("RESET_POSITIONS"),
        function()
            self:ResetPositions()
            self:RefreshSettingsControls()
        end,
        T("RESET_POSITIONS_TT"),
        function() return self.savedVariables.usePositioning == false end)

    AddHeader(T("SECTION_PRESETS"))
    AddDescription(T("PRESETS_HELP"))
    AddButton(T("PRESET_TOP_LEFT_LABEL"), T("PRESET_TOP_LEFT"),
        function() self:ApplyCornerPreset("left", "top") end,
        nil,
        function() return self.savedVariables.usePositioning == false end)
    AddButton(T("PRESET_TOP_RIGHT_LABEL"), T("PRESET_TOP_RIGHT"),
        function() self:ApplyCornerPreset("right", "top") end,
        nil,
        function() return self.savedVariables.usePositioning == false end)
    AddButton(T("PRESET_BOTTOM_LEFT_LABEL"), T("PRESET_BOTTOM_LEFT"),
        function() self:ApplyCornerPreset("left", "bottom") end,
        nil,
        function() return self.savedVariables.usePositioning == false end)
    AddButton(T("PRESET_BOTTOM_RIGHT_LABEL"), T("PRESET_BOTTOM_RIGHT"),
        function() self:ApplyCornerPreset("right", "bottom") end,
        nil,
        function() return self.savedVariables.usePositioning == false end)

    AddHeader(T("SECTION_KEYS"))
    AddDescription(T("KEYS_HELP"))

    scroll:SetHeight(y + 20)
end

function TR:ResetSettingsToDefaults()
    if self.editMode then
        self:SetEditMode(false, true)
    end
    self.savedVariables.permanentEnabled = false
    self.savedVariables.chatMessages = true
    self.savedVariables.usePositioning = true
    self:SetTooltipsEnabled(false, false, false)
    self:ApplyAllPositions()
    self:RefreshSettingsControls()
    self:Message(T("DEFAULTS_DONE"))
end

function TR:ShowSettings(source)
    self:CreateSettingsWindow()
    self.settingsOpenSource = source
    self:RefreshSettingsControls()
    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then
        SCENE_MANAGER:ShowTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(false)
    end
    if self.settingsWindow.BringWindowToTop then
        self.settingsWindow:BringWindowToTop()
    end
end

function TR:OpenSettings(source)
    self:ShowSettings(source or "slash")
end

function TR:HideSettings()
    ClearTooltip(InformationTooltip)
    if self.editMode then
        self:SetEditMode(false, true)
    end
    if not self.settingsWindow then return end
    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

function TR:HideSettingsWindow()
    self:HideSettings()
end

function TR:CloseSettings()
    self:HideSettings()
end

function TR:ToggleSettings(source)
    self:CreateSettingsWindow()
    if self.settingsWindow:IsHidden() then
        self:ShowSettings(source)
    else
        self:HideSettings()
    end
end

function TR:SetupAddonManagerGear(control, data)
    if not control or not data then return end

    local fileName = data.addOnFileName or data.addonFileName
    local isTooltipruhe = fileName == self.name
    local gear = control.tooltipruheSettingsGear

    if not gear and isTooltipruhe then
        gear = WM:CreateControl(nil, control, CT_BUTTON)
        control.tooltipruheSettingsGear = gear
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetClickSound("Click")

        local icon = WM:CreateControl(nil, gear, CT_TEXTURE)
        gear.tooltipruheSettingsIcon = icon
        icon:SetDimensions(20, 20)
        icon:SetAnchor(CENTER, gear, CENTER, 0, 0)
        icon:SetTexture("Tooltipruhe/textures/settings_gear.dds")
        icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        icon:SetMouseEnabled(false)

        gear:SetHandler("OnClicked", function()
            self:ShowSettings("addonManager")
        end)
        gear:SetHandler("OnMouseEnter", function(selfControl)
            icon:SetColor(1, 1, 1, 1)
            InitializeTooltip(InformationTooltip, selfControl, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, T("GEAR_TOOLTIP"))
        end)
        gear:SetHandler("OnMouseExit", function()
            icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            ClearTooltip(InformationTooltip)
        end)
    end

    if gear then
        gear:SetHidden(not isTooltipruhe)
    end
end

function TR:PatchAddonManagerDataTypes()
    local manager = _G.ADD_ON_MANAGER
    if not manager or not manager.list or not ZO_ScrollList_GetDataTypeTable then return false end

    for typeId = 1, 64 do
        local dataType = ZO_ScrollList_GetDataTypeTable(manager.list, typeId)
        if dataType and dataType.setupCallback and not dataType.tooltipruheSettingsPatched then
            local originalSetup = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                originalSetup(control, data, ...)
                pcall(function()
                    local rowFileName = data and (data.addOnFileName or data.addonFileName)
                    if rowFileName then
                        self:SetupAddonManagerGear(control, data)
                    elseif control and control.tooltipruheSettingsGear then
                        control.tooltipruheSettingsGear:SetHidden(true)
                    end
                end)
            end
            dataType.tooltipruheSettingsPatched = true
        end
    end
    return true
end

function TR:InstallAddonManagerGear()
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

function TR:InstallSettingsCloseBehavior()
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
