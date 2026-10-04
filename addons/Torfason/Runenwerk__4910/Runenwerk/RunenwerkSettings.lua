-- RunenwerkSettings.lua
-- Dependency-free settings UI and Add-On Manager integration.

local RW = _G.Runenwerk
if not RW then return end

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

    local settingsWindow = RW.settingsWindow
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

function RW:RegisterSettingsRefresher(callback)
    self.settingsRefreshers = self.settingsRefreshers or {}
    self.settingsRefreshers[#self.settingsRefreshers + 1] = callback
end

function RW:RefreshSettingsControls()
    if not self.settingsRefreshers then return end
    for _, callback in ipairs(self.settingsRefreshers) do
        callback()
    end
end

function RW:ResetSettingsToDefaults()
    if not self.saved or not self.defaults then return end

    -- Recipe data are user data, not settings, and must never be reset here.
    self.saved.autoOpenAtStation = self.defaults.autoOpenAtStation
    self.saved.closeAfterInsert = self.defaults.closeAfterInsert
    self.saved.chatMessages = self.defaults.chatMessages
    self.saved.showMainMenuButton = self.defaults.showMainMenuButton
    self.saved.windowLocked = self.defaults.windowLocked
    self.saved.sortColumn = self.defaults.sortColumn
    self.saved.sortAscending = self.defaults.sortAscending

    if self.saved.window then
        self.saved.window.left = nil
        self.saved.window.top = nil
    end

    self:ResetActiveSortToSettings()
    self:RefreshRecipeList()
    self:RefreshWindow()
    self:UpdateWindowPin()
    self:UpdateMainMenuButton()
    self:ResetWindowPosition()
    self:RefreshSettingsControls()

    d("|c7FC7FF" .. self:L("SETTINGS_DEFAULTS_DONE") .. "|r")
end

function RW:ShowSettings(source)
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

function RW:HideSettings()
    ClearTooltip(InformationTooltip)
    if not self.settingsWindow then return end

    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
        SCENE_MANAGER:HideTopLevel(self.settingsWindow)
    else
        self.settingsWindow:SetHidden(true)
    end
end

function RW:ToggleSettings(source)
    self:CreateSettingsWindow()
    if self.settingsWindow:IsHidden() then
        self:ShowSettings(source)
    else
        self:HideSettings()
    end
end

function RW:ToggleRecipeWindowFromSettings()
    if not self.window then return end

    if self.window:IsHidden() then
        self:OpenWindow(true, false)
    else
        self.window:SetHidden(true)
    end
end

function RW:CreateSettingsWindow()
    if self.settingsWindow then return end

    self.settingsRefreshers = {}

    local window = WM:CreateTopLevelWindow("RunenwerkSettingsWindow")
    self.settingsWindow = window
    window:SetDimensions(820, math.min(700, GuiRoot:GetHeight() - 80))
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_MEDIUM)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetMouseEnabled(true)
    window:SetHidden(true)

    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        SCENE_MANAGER:RegisterTopLevel(window, false)
    end

    window:SetHandler("OnHide", function()
        ClearTooltip(InformationTooltip)
        -- A recipe window opened specifically from the settings belongs to this
        -- settings visit and closes together with it.
        if self.openedFromSettings and self.window and not self.window:IsHidden() then
            self.window:SetHidden(true)
        else
            self.openedFromSettings = false
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

    local defaultsButton = WM:CreateControlFromVirtual("RunenwerkSettingsDefaults", window, "ZO_DefaultButton")
    defaultsButton:SetDimensions(190, 30)
    defaultsButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 28, -22)
    defaultsButton:SetText(self:L("SETTINGS_DEFAULTS"))
    AddTooltip(defaultsButton, self:L("SETTINGS_DEFAULTS_TOOLTIP"))
    defaultsButton:SetHandler("OnClicked", function()
        self:ResetSettingsToDefaults()
    end)

    local closeButton = WM:CreateControlFromVirtual("RunenwerkSettingsClose", window, "ZO_DefaultButton")
    closeButton:SetDimensions(150, 30)
    closeButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -28, -22)
    closeButton:SetText(self:L("SETTINGS_CLOSE"))
    closeButton:SetHandler("OnClicked", function()
        self:HideSettings()
    end)

    local scrollContainer = WM:CreateControlFromVirtual("RunenwerkSettingsScroll", window, "ZO_ScrollContainer")
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
        return "RunenwerkSettings" .. prefix .. tostring(controlId)
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
        row:SetDimensions(CONTENT_WIDTH - 16, 38)

        local label = WM:CreateControl(NextName("DropdownLabel"), row, CT_LABEL)
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(430, 30)
        label:SetFont("ZoFontGame")
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetText(text)
        AddTooltip(label, tooltip, true)

        local comboControl = WM:CreateControlFromVirtual(NextName("Dropdown"), row, "ZO_ComboBox")
        comboControl:SetDimensions(220, 30)
        comboControl:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        local combo = ZO_ComboBox_ObjectFromContainer(comboControl)
        combo:SetSortsItems(false)
        combo:SetSelectedItemFont("ZoFontGame")
        combo:SetDropdownFont("ZoFontGame")
        local updating = false

        for _, choice in ipairs(choices) do
            local value = choice.value
            local entry = combo:CreateItemEntry(choice.label, function()
                if updating then return end
                setter(value)
                self:RefreshSettingsControls()
            end)
            combo:AddItem(entry)
        end

        local function Refresh()
            local current = getter()
            updating = true
            for _, choice in ipairs(choices) do
                if choice.value == current then
                    combo:SetSelectedItem(choice.label)
                    break
                end
            end
            updating = false
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
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetText(text)
        AddTooltip(label, tooltip, true)

        local button = WM:CreateControlFromVirtual(NextName("Button"), row, "ZO_DefaultButton")
        button:SetDimensions(220, 28)
        button:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        button:SetText(buttonText)
        button:SetHandler("OnClicked", callback)
        AddTooltip(button, tooltip)

        y = y + 42
        return row
    end

    AddDescription(self:L("PANEL_DESCRIPTION"))

    AddHeader(self:L("SETTINGS_BEHAVIOR_HEADER"))
    AddCheckbox(self:L("SETTINGS_AUTO_OPEN_STATION"),
        function() return self.saved.autoOpenAtStation end,
        function(v) self.saved.autoOpenAtStation = v end,
        self:L("SETTINGS_AUTO_OPEN_STATION_TOOLTIP"))
    AddCheckbox(self:L("SETTINGS_CLOSE_AFTER_INSERT"),
        function() return self.saved.closeAfterInsert end,
        function(v) self.saved.closeAfterInsert = v end,
        self:L("SETTINGS_CLOSE_AFTER_INSERT_TOOLTIP"))
    AddCheckbox(self:L("SETTINGS_CHAT_MESSAGES"),
        function() return self.saved.chatMessages end,
        function(v) self.saved.chatMessages = v end,
        self:L("SETTINGS_CHAT_MESSAGES_TOOLTIP"))

    AddHeader(self:L("SETTINGS_INTERFACE_HEADER"))
    AddCheckbox(self:L("SETTINGS_SHOW_MAIN_MENU_BUTTON"),
        function() return self.saved.showMainMenuButton ~= false end,
        function(v)
            self.saved.showMainMenuButton = v
            self:UpdateMainMenuButton()
            if not v and self.openedFromMainMenu and self.window and not self.window:IsHidden() then
                self.window:SetHidden(true)
            end
        end,
        self:L("SETTINGS_SHOW_MAIN_MENU_BUTTON_TOOLTIP"))

    AddHeader(self:L("SETTINGS_SORT_HEADER"))
    AddDropdown(self:L("SETTINGS_SORT_COLUMN"), {
        { label = self:L("COLUMN_GLYPH"), value = "glyph" },
        { label = self:L("COLUMN_MIN_LEVEL"), value = "level" },
        { label = self:L("COLUMN_RUNES"), value = "runes" },
        { label = self:L("COLUMN_CRAFTED"), value = "crafted" },
        { label = self:L("COLUMN_MATERIAL"), value = "material" },
    },
        function() return self.saved.sortColumn or "glyph" end,
        function(v) self:SetDefaultSort(v, self.saved.sortAscending ~= false) end,
        self:L("SETTINGS_SORT_COLUMN_TOOLTIP"))

    AddDropdown(self:L("SETTINGS_SORT_DIRECTION"), {
        { label = self:L("SORT_ASCENDING"), value = "ascending" },
        { label = self:L("SORT_DESCENDING"), value = "descending" },
    },
        function() return self.saved.sortAscending ~= false and "ascending" or "descending" end,
        function(v) self:SetDefaultSort(self.saved.sortColumn or "glyph", v == "ascending") end,
        self:L("SETTINGS_SORT_DIRECTION_TOOLTIP"))

    AddHeader(self:L("SETTINGS_WINDOW_HEADER"))
    AddButton(self:L("SETTINGS_OPEN_WINDOW"), self:L("SETTINGS_OPEN_WINDOW_BUTTON"), function()
        self:ToggleRecipeWindowFromSettings()
    end, self:L("SETTINGS_OPEN_WINDOW_TOOLTIP"))
    AddButton(self:L("SETTINGS_RESET_WINDOW_POSITION"), self:L("SETTINGS_RESET_WINDOW_POSITION_BUTTON"), function()
        self:ResetWindowPosition()
    end, self:L("SETTINGS_RESET_WINDOW_POSITION_TOOLTIP"))

    scroll:SetHeight(y + 20)
end

function RW:SetupAddonManagerGear(control, data)
    if not control or not data then return end

    local isRunenwerk = data.addOnFileName == self.name
    local gear = control.runenwerkSettingsGear

    if not gear and isRunenwerk then
        gear = WM:CreateControl(nil, control, CT_BUTTON)
        control.runenwerkSettingsGear = gear
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetClickSound("Click")

        local icon = WM:CreateControl(nil, gear, CT_TEXTURE)
        gear.runenwerkSettingsIcon = icon
        icon:SetDimensions(20, 20)
        icon:SetAnchor(CENTER, gear, CENTER, 0, 0)
        icon:SetTexture("Runenwerk/art/settings_gear.dds")
        icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        icon:SetMouseEnabled(false)

        gear:SetHandler("OnClicked", function()
            self:ShowSettings("addonManager")
        end)
        gear:SetHandler("OnMouseEnter", function(selfControl)
            icon:SetColor(1, 1, 1, 1)
            InitializeTooltip(InformationTooltip, selfControl, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, self:L("SETTINGS_GEAR_TOOLTIP"))
        end)
        gear:SetHandler("OnMouseExit", function()
            icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            ClearTooltip(InformationTooltip)
        end)
    end

    if gear then
        gear:SetHidden(not isRunenwerk)
    end
end

function RW:PatchAddonManagerDataTypes()
    local manager = _G.ADD_ON_MANAGER
    if not manager or not manager.list or not ZO_ScrollList_GetDataTypeTable then return false end

    for typeId = 1, 64 do
        local dataType = ZO_ScrollList_GetDataTypeTable(manager.list, typeId)
        if dataType and dataType.setupCallback and not dataType.runenwerkSettingsPatched then
            local originalSetup = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                originalSetup(control, data, ...)
                pcall(function()
                    if data and data.addOnFileName then
                        self:SetupAddonManagerGear(control, data)
                    elseif control and control.runenwerkSettingsGear then
                        control.runenwerkSettingsGear:SetHidden(true)
                    end
                end)
            end
            dataType.runenwerkSettingsPatched = true
        end
    end
    return true
end

function RW:InstallAddonManagerGear()
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

function RW:InstallSettingsCloseBehavior()
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

function RW:BuildSettings()
    -- Keep /runenwerk for the recipe book. The settings window has dedicated
    -- fallback slash commands so Add-On Manager integration is never required.
    SLASH_COMMANDS["/runenwerkeinstellungen"] = function()
        self:ToggleSettings("slash")
    end
    SLASH_COMMANDS["/runenwerksettings"] = function()
        self:ToggleSettings("slash")
    end

    self:InstallAddonManagerGear()
    self:InstallSettingsCloseBehavior()
end
