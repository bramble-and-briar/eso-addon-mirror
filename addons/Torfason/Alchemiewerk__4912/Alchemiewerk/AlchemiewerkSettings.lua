-- AlchemiewerkSettings.lua
-- Dependency-free settings UI based on the shared Randwache settings window.

local Alchemiewerk = _G.Alchemiewerk
if not Alchemiewerk then return end

local WM = WINDOW_MANAGER
local BLUE_R, BLUE_G, BLUE_B = 127 / 255, 199 / 255, 1
local CONTENT_WIDTH = 720

local function S(id, ...)
    local value = GetString(id)
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

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

    local settingsWindow = Alchemiewerk.settingsWindow
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

function Alchemiewerk:RegisterSettingsRefresher(callback)
    self.settingsRefreshers = self.settingsRefreshers or {}
    self.settingsRefreshers[#self.settingsRefreshers + 1] = callback
end

function Alchemiewerk:RefreshSettingsControls()
    if not self.settingsRefreshers then return end
    for _, callback in ipairs(self.settingsRefreshers) do
        callback()
    end
end

function Alchemiewerk:CreateSettingsWindow()
    if self.settingsWindow then return end

    self.settingsRefreshers = {}

    local window = WM:CreateTopLevelWindow("AlchemiewerkSettingsWindow")
    self.settingsWindow = window
    window:SetDimensions(820, math.min(720, GuiRoot:GetHeight() - 80))
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
    title:SetText(S(SI_AW_TITLE))

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

    local defaultsButton = WM:CreateControlFromVirtual("AlchemiewerkSettingsDefaults", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton:SetText(S(SI_AW_SETTINGS_DEFAULTS))
    AddTooltip(defaultsButton, S(SI_AW_SETTINGS_DEFAULTS_TT))
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetSettingsToDefaults()
    end)

    local closeButton = WM:CreateControlFromVirtual("AlchemiewerkSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(S(SI_AW_SETTINGS_CLOSE))
    closeButton:SetHandler("OnClicked", function()
        self:HideSettings()
    end)

    local scrollContainer = WM:CreateControlFromVirtual("AlchemiewerkSettingsScroll", window, "ZO_ScrollContainer")
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
        return "AlchemiewerkSettings" .. prefix .. tostring(controlId)
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

    local function AddDropdown(text, choices, getter, setter, tooltip)
        local row = WM:CreateControl(NextName("DropdownRow"), scroll, CT_CONTROL)
        row:SetAnchor(TOPLEFT, scroll, TOPLEFT, 8, y)
        row:SetDimensions(CONTENT_WIDTH - 16, 42)

        local label = WM:CreateControl(NextName("DropdownLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(390, 30)
        label:SetFont("ZoFontGame")
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetText(text)
        AddTooltip(label, tooltip, true)

        local control = WM:CreateControlFromVirtual(NextName("Dropdown"), row, "ZO_ComboBox")
        control:SetDimensions(260, 30)
        control:SetAnchor(RIGHT, row, RIGHT, 0, 0)

        local comboBox = ZO_ComboBox_ObjectFromContainer(control)
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        local updating = false
        for _, choice in ipairs(choices) do
            local choiceLabel = choice.label
            local choiceValue = choice.value
            local entry = comboBox:CreateItemEntry(choiceLabel, function()
                if updating then return end
                setter(choiceValue)
                self:RefreshSettingsControls()
            end)
            comboBox:AddItem(entry)
        end

        local function Refresh()
            local current = getter()
            local selectedLabel = choices[1] and choices[1].label or ""
            for _, choice in ipairs(choices) do
                if choice.value == current then
                    selectedLabel = choice.label
                    break
                end
            end
            updating = true
            comboBox:SetSelectedItem(selectedLabel)
            updating = false
        end

        self:RegisterSettingsRefresher(Refresh)
        Refresh()

        y = y + 46
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
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
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

    AddDescription(S(SI_AW_DESCRIPTION))

    AddHeader(S(SI_AW_SETTINGS_BEHAVIOR))
    AddCheckbox(
        S(SI_AW_SETTINGS_AUTO_OPEN),
        function() return self.sv.settings.autoOpen end,
        function(value) self.sv.settings.autoOpen = value end,
        S(SI_AW_SETTINGS_AUTO_OPEN_TT)
    )
    AddCheckbox(
        S(SI_AW_SETTINGS_CLOSE_AFTER_INSERT),
        function() return self.sv.settings.closeAfterInsert end,
        function(value) self.sv.settings.closeAfterInsert = value end,
        S(SI_AW_SETTINGS_CLOSE_AFTER_INSERT_TT)
    )
    AddCheckbox(
        S(SI_AW_SETTINGS_CHAT),
        function() return self.sv.settings.chatMessages end,
        function(value) self.sv.settings.chatMessages = value end,
        S(SI_AW_SETTINGS_CHAT_TT)
    )
    AddCheckbox(
        S(SI_AW_SETTINGS_MAIN_MENU),
        function() return self.sv.settings.showMainMenuIcon end,
        function(value)
            self.sv.settings.showMainMenuIcon = value
            self:TryInitializeMainMenu(1)
            self:RefreshMainMenu()
        end,
        S(SI_AW_SETTINGS_MAIN_MENU_TT)
    )

    AddHeader(S(SI_AW_SETTINGS_SORTING))
    AddDropdown(
        S(SI_AW_SETTINGS_DEFAULT_SORT),
        {
            { label = S(SI_AW_SORT_RESULT), value = "name" },
            { label = S(SI_AW_SORT_LEVEL), value = "level" },
            { label = S(SI_AW_SORT_INGREDIENTS), value = "ingredients" },
            { label = S(SI_AW_SORT_CRAFTED), value = "crafted" },
            { label = S(SI_AW_SORT_MATERIAL), value = "material" },
        },
        function() return self.sv.settings.defaultSortColumn end,
        function(value) self.sv.settings.defaultSortColumn = value end,
        S(SI_AW_SETTINGS_DEFAULT_SORT_TT)
    )
    AddDropdown(
        S(SI_AW_SETTINGS_DIRECTION),
        {
            { label = S(SI_AW_SETTINGS_ASC), value = true },
            { label = S(SI_AW_SETTINGS_DESC), value = false },
        },
        function() return self.sv.settings.defaultSortAscending ~= false end,
        function(value) self.sv.settings.defaultSortAscending = value end,
        S(SI_AW_SETTINGS_DIRECTION_TT)
    )

    AddHeader(S(SI_AW_SETTINGS_WINDOW))
    AddCheckbox(
        S(SI_AW_SETTINGS_LOCK_WINDOW),
        function() return self:IsWindowLocked() end,
        function(value) self:SetWindowLocked(value) end,
        S(SI_AW_SETTINGS_LOCK_WINDOW_TT)
    )
    AddButton(
        S(SI_AW_SETTINGS_RECIPE_WINDOW),
        S(SI_AW_SETTINGS_TOGGLE_BUTTON),
        function() self:ToggleWindow("settings") end,
        S(SI_AW_SETTINGS_OPEN_TT)
    )
    AddButton(
        S(SI_AW_SETTINGS_POSITION),
        S(SI_AW_SETTINGS_RESET_BUTTON),
        function() self:ResetWindowPosition() end,
        S(SI_AW_SETTINGS_RESET_POSITION_TT)
    )

    scroll:SetHeight(y + 20)
end

function Alchemiewerk:ResetSettingsToDefaults()
    if not self.defaults or not self.defaults.settings then return end

    self.sv.settings = DeepCopy(self.defaults.settings)
    self:SetWindowLocked(self.defaults.window and self.defaults.window.locked or false)
    self:ResetSortToDefault()
    self:TryInitializeMainMenu(1)
    self:RefreshMainMenu()

    if self.window and not self.window:IsHidden() then
        self:RefreshList()
    end

    self:RefreshSettingsControls()
    d("|c7FC7FF" .. S(SI_AW_SETTINGS_DEFAULTS_DONE) .. "|r")
end

function Alchemiewerk:ShowSettings(source)
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

function Alchemiewerk:HideSettings()
    ClearTooltip(InformationTooltip)

    if self.openedFromSettings and self.window and not self.window:IsHidden() then
        self:HideWindow()
    end

    if not self.settingsWindow then return end
    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

function Alchemiewerk:ToggleSettings(source)
    self:CreateSettingsWindow()
    if self.settingsWindow:IsHidden() then
        self:ShowSettings(source)
    else
        self:HideSettings()
    end
end

function Alchemiewerk:SetupAddonManagerGear(control, data)
    if not control or not data then return end

    local isAlchemiewerk = data.addOnFileName == self.name
    local gear = control.alchemiewerkSettingsGear

    if not gear and isAlchemiewerk then
        gear = WM:CreateControl(nil, control, CT_BUTTON)
        control.alchemiewerkSettingsGear = gear
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetClickSound("Click")

        local icon = WM:CreateControl(nil, gear, CT_TEXTURE)
        gear.alchemiewerkSettingsIcon = icon
        icon:SetDimensions(20, 20)
        icon:SetAnchor(CENTER, gear, CENTER, 0, 0)
        icon:SetTexture("Alchemiewerk/art/settings_gear.dds")
        icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        icon:SetMouseEnabled(false)

        gear:SetHandler("OnClicked", function()
            self:ShowSettings("addonManager")
        end)
        gear:SetHandler("OnMouseEnter", function(selfControl)
            icon:SetColor(1, 1, 1, 1)
            InitializeTooltip(InformationTooltip, selfControl, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, S(SI_AW_SETTINGS_GEAR_TT))
        end)
        gear:SetHandler("OnMouseExit", function()
            icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            ClearTooltip(InformationTooltip)
        end)
    end

    if gear then
        gear:SetHidden(not isAlchemiewerk)
    end
end

function Alchemiewerk:PatchAddonManagerDataTypes()
    local manager = _G.ADD_ON_MANAGER
    if not manager or not manager.list or not ZO_ScrollList_GetDataTypeTable then return false end

    for typeId = 1, 64 do
        local dataType = ZO_ScrollList_GetDataTypeTable(manager.list, typeId)
        if dataType and dataType.setupCallback and not dataType.alchemiewerkSettingsPatched then
            local originalSetup = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                originalSetup(control, data, ...)
                pcall(function()
                    if data and data.addOnFileName then
                        self:SetupAddonManagerGear(control, data)
                    elseif control and control.alchemiewerkSettingsGear then
                        control.alchemiewerkSettingsGear:SetHidden(true)
                    end
                end)
            end
            dataType.alchemiewerkSettingsPatched = true
        end
    end

    return true
end

function Alchemiewerk:InstallAddonManagerGear()
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

function Alchemiewerk:InstallSettingsCloseBehavior()
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

function Alchemiewerk:BuildSettings()
    SLASH_COMMANDS["/awsettings"] = function()
        self:ToggleSettings("slash")
    end
    SLASH_COMMANDS["/alchemiewerksettings"] = function()
        self:ToggleSettings("slash")
    end

    self:InstallAddonManagerGear()
    self:InstallSettingsCloseBehavior()
end
