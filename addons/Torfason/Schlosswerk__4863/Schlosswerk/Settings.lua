-- Settings.lua
-- Dependency-free settings UI and Add-On Manager integration.

local SW = Schlosswerk
if not SW then return end

local WM = WINDOW_MANAGER
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

    local settingsWindow = SW.settingsWindow
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
    if enableMouse then control:SetMouseEnabled(true) end

    control:SetHandler("OnMouseEnter", function(self)
        ShowSettingsTooltip(self, text)
    end)
    control:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
end

function SW:RegisterSettingsRefresher(callback)
    self.settingsRefreshers = self.settingsRefreshers or {}
    self.settingsRefreshers[#self.settingsRefreshers + 1] = callback
end

function SW:RefreshSettingsControls()
    if not self.settingsRefreshers then return end
    for _, callback in ipairs(self.settingsRefreshers) do
        callback()
    end
end

function SW:GetModeChoicesForSettings()
    return {
        { name = self:L("MODE_FIXED"), value = "fixed" },
        { name = self:L("MODE_RANDOM"), value = "random" },
    }
end

function SW:GetStyleChoicesForSettings()
    local choices = {}
    for _, styleId in ipairs(self.styleOrder) do
        choices[#choices + 1] = {
            name = self:GetStyleName(styleId),
            value = styleId,
        }
    end
    return choices
end

function SW:CreateSettingsWindow()
    if self.settingsWindow then return end

    self.settingsRefreshers = {}

    local window = WM:CreateTopLevelWindow("SchlosswerkSettingsWindow")
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
    title:SetText(self:L("SETTINGS_TITLE"))

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

    local defaultsButton = WM:CreateControlFromVirtual("SchlosswerkSettingsDefaults", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton:SetText(self:L("SETTINGS_DEFAULTS"))
    AddTooltip(defaultsButton, self:L("SETTINGS_DEFAULTS_TT"))
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetSettingsToDefaults()
    end)

    local closeButton = WM:CreateControlFromVirtual("SchlosswerkSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(self:L("SETTINGS_CLOSE"))
    closeButton:SetHandler("OnClicked", function()
        self:HideSettings()
    end)

    local scrollContainer = WM:CreateControlFromVirtual("SchlosswerkSettingsScroll", window, "ZO_ScrollContainer")
    scrollContainer:SetAnchor(TOPLEFT, window, TOPLEFT, 32, 68)
    scrollContainer:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -32, -66)
    ZO_Scroll_SetUseFadeGradient(scrollContainer, false)
    local scroll = GetControl(scrollContainer, "ScrollChild")
    self.settingsScroll = scroll
    scroll:SetWidth(CONTENT_WIDTH)

    local y = 0
    local controlId = 0
    local pendingDropdowns = {}
    local function NextName(prefix)
        controlId = controlId + 1
        return "SchlosswerkSettings" .. prefix .. tostring(controlId)
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

    local function AddCheckbox(text, getter, setter, tooltip, disabled)
        local row = WM:CreateControl(NextName("CheckboxRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 32)

        local checkbox = WM:CreateControlFromVirtual(NextName("Checkbox"), row, "ZO_CheckButton")
        checkbox:SetAnchor(LEFT, row, LEFT, 0, 0)
        checkbox:SetMouseEnabled(true)
        ZO_CheckButton_SetLabelText(checkbox, text)
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
            if disabled and disabled() then return end
            setter(checked)
            self:RefreshSettingsControls()
        end)
        local checkboxLabel = GetControl(checkbox, "Label")
        AddTooltip(checkboxLabel or checkbox, tooltip, checkboxLabel ~= nil)

        local function Refresh()
            ZO_CheckButton_SetCheckState(checkbox, not not getter())
            local isDisabled = disabled and disabled() or false
            if ZO_CheckButton_SetEnableState then
                ZO_CheckButton_SetEnableState(checkbox, not isDisabled)
            else
                checkbox:SetMouseEnabled(not isDisabled)
                checkbox:SetAlpha(isDisabled and 0.4 or 1)
            end
            if checkboxLabel then checkboxLabel:SetAlpha(isDisabled and 0.45 or 1) end
        end
        self:RegisterSettingsRefresher(Refresh)
        Refresh()
        y = y + 34
        return row
    end

    local function AddDropdown(text, choicesGetter, getter, setter, tooltip, disabled)
        local row = WM:CreateControl(NextName("DropdownRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 42)

        local label = WM:CreateControl(NextName("DropdownLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(360, 30)
        label:SetFont("ZoFontGame")
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetText(text)
        AddTooltip(label, tooltip, true)

        -- Create combo boxes only after the rest of the scroll content exists.
        -- ESO can otherwise draw later-created controls over an open dropdown.
        pendingDropdowns[#pendingDropdowns + 1] = {
            row = row,
            label = label,
            choicesGetter = choicesGetter,
            getter = getter,
            setter = setter,
            tooltip = tooltip,
            disabled = disabled,
        }

        y = y + 46
        return row
    end

    local function CreatePendingDropdowns()
        local function CreateOneDropdown(spec)
            local dropdown = WM:CreateControlFromVirtual(NextName("Dropdown"), spec.row, "ZO_ComboBox")
            dropdown:SetDimensions(300, 32)
            dropdown:SetAnchor(RIGHT, spec.row, RIGHT, 0, 0)
            local comboBox = ZO_ComboBox_ObjectFromContainer(dropdown)
            if comboBox.SetSortsItems then comboBox:SetSortsItems(false) end

            local rebuilding = false
            local function Refresh()
                local choices = spec.choicesGetter()
                local current = spec.getter()
                local selectedIndex = nil

                rebuilding = true
                comboBox:ClearItems()
                for index, choice in ipairs(choices) do
                    local function AddChoice(choiceData, choiceIndex)
                        local choiceValue = choiceData.value
                        local entry = comboBox:CreateItemEntry(choiceData.name, function()
                            if rebuilding then return end
                            spec.setter(choiceValue)
                            self:RefreshSettingsControls()
                        end)
                        comboBox:AddItem(entry)
                        if choiceValue == current then selectedIndex = choiceIndex end
                    end
                    AddChoice(choice, index)
                end
                if selectedIndex then
                    comboBox:SelectItemByIndex(selectedIndex, true)
                elseif #choices > 0 then
                    comboBox:SelectItemByIndex(1, true)
                end
                rebuilding = false

                local isDisabled = spec.disabled and spec.disabled() or false
                if comboBox.SetEnabled then comboBox:SetEnabled(not isDisabled) end
                dropdown:SetMouseEnabled(not isDisabled)
                dropdown:SetAlpha(isDisabled and 0.35 or 1)
                spec.label:SetAlpha(isDisabled and 0.45 or 1)
            end

            self:RegisterSettingsRefresher(Refresh)
            Refresh()
        end

        for _, spec in ipairs(pendingDropdowns) do
            CreateOneDropdown(spec)
        end
    end

    AddDescription(self:L("PANEL_DESCRIPTION"))

    AddHeader(self:L("HEADER_GENERAL"))
    AddDropdown(
        self:L("MODE"),
        function() return self:GetModeChoicesForSettings() end,
        function() return self.db.selectionMode end,
        function(value) self.db.selectionMode = value end,
        self:L("MODE_TT")
    )
    AddDropdown(
        self:L("FIXED_STYLE"),
        function() return self:GetStyleChoicesForSettings() end,
        function() return self.db.fixedStyle end,
        function(value) self.db.fixedStyle = value end,
        self:L("FIXED_STYLE_TT"),
        function() return self.db.selectionMode ~= "fixed" end
    )
    AddDescription(self:L("ORIGINAL_NOTE"))

    AddHeader(self:L("HEADER_APPEARANCE"))
    AddCheckbox(
        self:L("PIN_LIGHTS"),
        function() return self.db.pinLights end,
        function(value) self.db.pinLights = value end,
        self:L("PIN_LIGHTS_TT")
    )
    AddDescription(self:L("CHANGES_NEXT_ATTEMPT"))

    AddHeader(self:L("HEADER_RANDOM"))
    AddCheckbox(
        self:L("AVOID_REPEAT"),
        function() return self.db.avoidImmediateRepeat end,
        function(value) self.db.avoidImmediateRepeat = value end,
        self:L("AVOID_REPEAT_TT"),
        function() return self.db.selectionMode ~= "random" end
    )
    AddDescription(self:L("RANDOM_POOL_TT"))

    local function AddRandomStyleCheckbox(styleId)
        AddCheckbox(
            self:GetStyleName(styleId),
            function() return self.db.randomPool[styleId] end,
            function(value) self.db.randomPool[styleId] = value end,
            nil,
            function() return self.db.selectionMode ~= "random" end
        )
    end

    for _, styleId in ipairs(self.styleOrder) do
        AddRandomStyleCheckbox(styleId)
    end

    CreatePendingDropdowns()
    scroll:SetHeight(y + 20)
end

function SW:ResetSettingsToDefaults()
    for key, value in pairs(self.defaultSettings) do
        self.db[key] = DeepCopy(value)
    end
    self:SanitizeSettings()
    self:RefreshSettingsControls()
    self:Print(self:L("SETTINGS_DEFAULTS_DONE"))
end

function SW:ShowSettings(source)
    if self:IsLockpickSceneShowing() then
        self:Print(self:L("CHAT_BLOCKED"))
        return
    end

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

function SW:HideSettings()
    ClearTooltip(InformationTooltip)
    if not self.settingsWindow then return end

    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

function SW:ToggleSettings(source)
    if self:IsLockpickSceneShowing() then
        self:Print(self:L("CHAT_BLOCKED"))
        return
    end

    self:CreateSettingsWindow()
    if self.settingsWindow:IsHidden() then
        self:ShowSettings(source)
    else
        self:HideSettings()
    end
end

function SW:OpenSettings()
    self:ShowSettings("slash")
end

function SW:SetupAddonManagerGear(control, data)
    if not control or not data then return end

    local isSchlosswerk = data.addOnFileName == self.name
    local gear = control.schlosswerkSettingsGear

    if not gear and isSchlosswerk then
        gear = WM:CreateControl(nil, control, CT_BUTTON)
        control.schlosswerkSettingsGear = gear
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetClickSound("Click")

        local icon = WM:CreateControl(nil, gear, CT_TEXTURE)
        gear.schlosswerkSettingsIcon = icon
        icon:SetDimensions(20, 20)
        icon:SetAnchor(CENTER, gear, CENTER, 0, 0)
        icon:SetTexture("Schlosswerk/Textures/settings_gear.dds")
        icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        icon:SetMouseEnabled(false)

        gear:SetHandler("OnClicked", function()
            self:ShowSettings("addonManager")
        end)
        gear:SetHandler("OnMouseEnter", function(selfControl)
            icon:SetColor(1, 1, 1, 1)
            InitializeTooltip(InformationTooltip, selfControl, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, self:L("SETTINGS_GEAR_TT"))
        end)
        gear:SetHandler("OnMouseExit", function()
            icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            ClearTooltip(InformationTooltip)
        end)
    end

    if gear then gear:SetHidden(not isSchlosswerk) end
end

function SW:PatchAddonManagerDataTypes()
    local manager = _G.ADD_ON_MANAGER
    if not manager or not manager.list or not ZO_ScrollList_GetDataTypeTable then return false end

    for typeId = 1, 64 do
        local dataType = ZO_ScrollList_GetDataTypeTable(manager.list, typeId)
        if dataType and dataType.setupCallback and not dataType.schlosswerkSettingsPatched then
            local originalSetup = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                originalSetup(control, data, ...)
                pcall(function()
                    if data and data.addOnFileName then
                        self:SetupAddonManagerGear(control, data)
                    elseif control and control.schlosswerkSettingsGear then
                        control.schlosswerkSettingsGear:SetHidden(true)
                    end
                end)
            end
            dataType.schlosswerkSettingsPatched = true
        end
    end
    return true
end

function SW:InstallAddonManagerGear()
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

function SW:InstallSettingsCloseBehavior()
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

function SW:RegisterSettings()
    self:InstallAddonManagerGear()
    self:InstallSettingsCloseBehavior()
end
