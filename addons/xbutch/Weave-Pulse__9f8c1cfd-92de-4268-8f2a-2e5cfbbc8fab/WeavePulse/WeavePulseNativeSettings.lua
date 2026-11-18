-- Private native gamepad settings. Checkbox/slider setup adapted from the
-- EyesOfTheUndaunted private LAM subset, originally Ryan Lakanen (Seerah) and
-- contributors, Artistic License 2.0. See third-party/LibAddonMenu-LICENSE.txt.
local W, S = WeavePulse, WeavePulse.Settings
local SCENE, MENU_ID = "WeavePulseSettings", "WeavePulseAddons"
local ICON = "esoui/art/icons/ability_dualwield_002_b.dds"
S.panels, S.path = {}, {}

local function Value(item)
    if type(item) == "function" then return item() end
    return item
end
local function Disabled(row)
    return Value(row.disabled) == true or (row.parent and Disabled(row.parent)) or false
end
local function Label(row)
    return tostring(Value(row.name) or Value(row.title) or Value(row.text) or "")
end
local function Option(data) return data and (data.option or data) end

function S:RegisterAddonPanel(id, metadata)
    local key = id:match("^WeavePulse(.-)Options$")
    local panel = { key = key, metadata = metadata, controlsToRefresh = {} }
    function panel:RefreshPanel() S:Refresh() end
    self.panels[key] = panel
    return panel
end

function S:RegisterOptionControls(id, options)
    local panel = self.panels[id:match("^WeavePulse(.-)Options$")]
    panel.options = options
    local function index(rows, parent)
        for _, row in ipairs(rows) do
            row.parent = parent
            local model = { data = row }
            function model:UpdateChoices() end -- Choices remain live in the model.
            function model:UpdateValue() S:Refresh() end
            panel.controlsToRefresh[#panel.controlsToRefresh + 1] = model
            if row.controls then index(row.controls, row) end
        end
    end
    index(options)
end

function S:EnsureModel()
    if self.modelReady then return end
    self.modelReady = true
    W:BuildMenu()
    W:CustomizeSettings()
end

function S:CurrentPage()
    return self.path[#self.path]
end
function S:Refresh()
    if self.ui and self.ui.active then
        self.ui.list:RefreshVisible()
        self:UpdateSelection()
    end
end
function S:AfterChange()
    W:ApplyPreferences()
    self:Refresh()
end

function S:RowsFor(row)
    if row.type == "colorpicker" then
        local rows = {}
        for channel, name in ipairs({ "Red", "Green", "Blue", "Opacity" }) do
            local index = channel
            rows[#rows + 1] = {
                type = "slider", name = name, min = 0, max = 1, step = .01, decimals = 2,
                tooltip = "Adjust the " .. name:lower() .. " channel.", parent = row,
                getFunc = function() return ({ row.getFunc() })[index] or 1 end,
                setFunc = function(value)
                    local color = { row.getFunc() }
                    color[index] = value
                    row.setFunc(unpack(color))
                end,
            }
        end
        return rows
    elseif row.type == "dropdown" then
        local rows, choices = {}, Value(row.choices) or {}
        for index, choice in ipairs(choices) do
            local value = row.choicesValues and row.choicesValues[index] or choice
            rows[#rows + 1] = { type = "button", name = choice, parent = row,
                func = function()
                    row.setFunc(value)
                    self:Back()
                end,
            }
        end
        return rows
    end
    return row.controls or {}
end

function S:BuildPage()
    local ui, page = self.ui, self:CurrentPage()
    if ui.activeSlider then ui.activeSlider:Deactivate(); ui.activeSlider = nil end
    ui.list:Clear()
    ZO_GamepadGenericHeader_RefreshData(ui.header, {
        titleText = "WeavePulse", subtitleText = page and page.title or "Settings",
    })
    local rows = page and page.rows or {}
    for _, row in ipairs(rows) do
        if row.type ~= "divider" then
            local data = ZO_GamepadEntryData:New(Label(row))
            data.option = row
            local template = row.type == "checkbox" and "ZO_GamepadOptionsCheckboxRow"
                or row.type == "slider" and "WeavePulseGamepadSlider"
                or "ZO_GamepadMenuEntryTemplate"
            ui.list:AddEntry(template, data)
        end
    end
    ui.list:Commit()
    if page and page.selected and ui.list.SetSelectedIndex then ui.list:SetSelectedIndex(page.selected) end
    self:UpdateSelection()
end
function S:Push(title, rows)
    local page = self:CurrentPage()
    if page and self.ui.list.GetSelectedIndex then page.selected = self.ui.list:GetSelectedIndex() end
    self.path[#self.path + 1] = { title = title, rows = rows }
    self:BuildPage()
end
function S:Back()
    if #self.path > 1 then table.remove(self.path); self:BuildPage()
    else SCENE_MANAGER:Hide(SCENE) end
end

function S:ActivateRow()
    local row = Option(self.ui.list:GetTargetData())
    if not row or Disabled(row) then return end
    if row.type == "checkbox" then
        row.setFunc(not row.getFunc())
        self:AfterChange()
    elseif row.type == "submenu" or row.type == "dropdown" or row.type == "colorpicker" then
        self:Push(Label(row), self:RowsFor(row))
    elseif row.type == "button" and row.func then
        row.func()
        self:AfterChange()
    elseif row.type == "editbox" then
        self:EditText(row)
    end
end

function S:UpdateSelection()
    local ui = self.ui
    if not ui or not ui.active then return end
    local control = ui.list:GetSelectedControl()
    local row = Option(ui.list:GetTargetData())
    local slider = control and control.slider
    if row and Disabled(row) then slider = nil end
    if ui.activeSlider and ui.activeSlider ~= slider then ui.activeSlider:Deactivate() end
    ui.activeSlider = slider
    if slider and row and not Disabled(row) then slider:Activate() end
    if row then
        local description = Value(row.tooltip) or Value(row.text) or Label(row)
        if row.warning then description = description .. "\n\n" .. tostring(Value(row.warning)) end
        GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, description, "")
    end
    if ui.keybindsAdded then KEYBIND_STRIP:UpdateKeybindButtonGroup(ui.keybinds) end
end

local function Appearance(control, row, selected)
    control.data = row
    local label = control:GetNamedChild("Name")
    if label then
        label:SetText(Label(row))
        label:SetColor(ZO_GamepadMenuEntryTemplate_GetLabelColor(selected, Disabled(row)):UnpackRGBA())
        SetMenuEntryFontFace(label, selected)
    end
    control:SetAlpha(Disabled(row) and .45 or ZO_GamepadMenuEntryTemplate_GetAlpha(selected))
end
local function Checkbox(control, row, selected)
    row = Option(row)
    Appearance(control, row, selected)
    local button, checked = control:GetNamedChild("Checkbox"), row.getFunc() == true
    button.checkedText, button.uncheckedText = "", ""
    button:SetText("")
    button.selected = selected
    ZO_CheckButton_SetToggleFunction(button, nil)
    ZO_CheckButton_SetCheckState(button, checked)
    control:GetNamedChild("On"):SetColor((checked and ZO_DEFAULT_ENABLED_COLOR or ZO_DEFAULT_DISABLED_COLOR):UnpackRGBA())
    control:GetNamedChild("Off"):SetColor((checked and ZO_DEFAULT_DISABLED_COLOR or ZO_DEFAULT_ENABLED_COLOR):UnpackRGBA())
    ZO_CheckButton_SetToggleFunction(button, function(_, value)
        if not Disabled(row) then row.setFunc(value); S:AfterChange() end
    end)
end
local function Slider(control, row, selected)
    row = Option(row)
    Appearance(control, row, selected)
    local slider = control.slider
    slider:SetHandler("OnValueChanged", nil)
    local minimum, maximum = Value(row.min) or 0, Value(row.max) or 100
    maximum = math.max(minimum, maximum)
    slider:SetMinMax(minimum, maximum)
    slider:SetValueStep(row.step or 1)
    slider:SetValue(row.getFunc() or minimum)
    control:GetNamedChild("ValueLabel"):SetText(string.format("%." .. tostring(row.decimals or 0) .. "f", row.getFunc() or minimum))
    slider:SetHandler("OnValueChanged", function(_, value)
        if Disabled(row) then return end
        local step = row.step or 1
        value = math.max(minimum, math.min(maximum, minimum + math.floor((value - minimum) / step + .5) * step))
        row.setFunc(value)
        S:AfterChange()
    end)
end

function S:CreateUI()
    if self.ui then return end
    self:EnsureModel()
    local window = WeavePulseGamepad
    local container = window:GetNamedChild("MaskContainer")
    local header = container:GetNamedChild("HeaderContainer").header
    ZO_GamepadGenericHeader_Initialize(header, false)
    local list = ZO_GamepadVerticalItemParametricScrollList:New(container:GetNamedChild("List"))
    self.ui = { window = window, header = header, list = list }
    list:SetAlignToScreenCenter(true)
    list:AddDataTemplate("ZO_GamepadOptionsCheckboxRow", Checkbox, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplate("WeavePulseGamepadSlider", Slider, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:SetDataTemplateReleaseFunction("WeavePulseGamepadSlider", function(control)
        control.slider:Deactivate()
        control.slider:SetHandler("OnValueChanged", nil)
    end)
    list:AddDataTemplate("ZO_GamepadMenuEntryTemplate", function(control, data, selected, reselecting, enabled, active)
        local row = Option(data)
        local text = Label(row)
        if row.type == "dropdown" or row.type == "editbox" then text = text .. ": " .. tostring(row.getFunc() or "") end
        data:SetText(text)
        data:SetEnabled(not Disabled(row))
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselecting, not Disabled(row), active)
    end, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:SetOnSelectedDataChangedCallback(function() self:UpdateSelection() end)
    list:SetOnTargetDataChangedCallback(function() self:UpdateSelection() end)
    self.ui.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { keybind = "UI_SHORTCUT_PRIMARY", name = GetString(SI_GAMEPAD_SELECT_OPTION),
            callback = function() self:ActivateRow() end,
            enabled = function()
                local row = Option(list:GetTargetData())
                return row and row.type ~= "header" and row.type ~= "description" and not Disabled(row)
            end },
        { keybind = "UI_SHORTCUT_SECONDARY", name = GetString(SI_OPTIONS_DEFAULTS),
            callback = function() W:ResetPreferences(); self:Refresh() end },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.ui.keybinds, GAME_NAVIGATION_TYPE_BUTTON, function() self:Back() end)
end

function S:Open(panel)
    if self.scene:IsShowing() then
        if panel then self:ShowPanel(panel) end
        return
    end
    self.pendingPanel = panel
    SCENE_MANAGER:Push(SCENE)
end
function S:ShowPanel(key)
    self.path = {}
    local rows = {}
    for _, panelKey in ipairs({ "General", "Progressbar", "Resources", "StackTracker", "LATracker" }) do
        local panel = self.panels[panelKey]
        rows[#rows + 1] = { type = "submenu", name = panel.metadata.name, controls = panel.options }
    end
    self:Push("Settings", rows)
    if key and self.panels[key] then self:Push(self.panels[key].metadata.name, self.panels[key].options) end
end

function S:EditText(row)
    local dialogName = "WEAVEPULSE_TEXT_INPUT"
    if not self.textDialogRegistered then
        self.textDialogRegistered = true
        ZO_Dialogs_RegisterCustomDialog(dialogName, {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC }, canQueue = true,
            setup = function(dialog) dialog:setupFunc() end,
            title = { text = function(dialog) return Label(dialog.data.row) end },
            parametricList = {
                { template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem", templateData = {
                    nameField = true,
                    setup = function(control, data, selected)
                        local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl:SetMaxInputChars(120)
                        control.editBoxControl.textChangedCallback = function(edit) dialog.data.value = edit:GetText() end
                        control.editBoxControl:SetText(dialog.data.value or "")
                        data.control = control
                    end,
                    callback = function(dialog) dialog.entryList:GetTargetData().control.editBoxControl:TakeFocus() end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                } },
                { template = "ZO_GamepadTextFieldSubmitItem", templateData = {
                    text = GetString(SI_DIALOG_ACCEPT), setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(dialog)
                        dialog.data.row.setFunc(dialog.data.value or "")
                        self:AfterChange()
                        ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
                    end,
                } },
            },
            blockDialogReleaseOnPress = true,
            buttons = {
                { keybind = "DIALOG_PRIMARY", text = SI_GAMEPAD_SELECT_OPTION, callback = function(dialog)
                    local target = dialog.entryList:GetTargetData()
                    if target and target.callback then target.callback(dialog) end
                end },
                { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL,
                    callback = function() ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName) end },
            },
        })
    end
    ZO_Dialogs_ShowGamepadDialog(dialogName, { row = row, value = tostring(row.getFunc() or "") })
end

-- Reconcile only our entry with categories that other add-ons initialize lazily.
function S:RegisterMenu()
    if not self.watchingMenu and MAIN_MENU_GAMEPAD_SCENE then
        self.watchingMenu = true
        MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then self:RegisterMenu() end
        end)
    end
    if not MAIN_MENU_GAMEPAD or type(ZO_MENU_ENTRIES) ~= "table" then return false end
    local function entry(id, data)
        local value = ZO_GamepadEntryData:New(data.name, data.icon)
        value.id, value.data = id, data
        value:SetIconTintOnSelection(true)
        value:SetIconDisabledTintOnSelection(true)
        return value
    end
    local title, root = GetString(SI_GAME_MENU_ADDONS)
    for _, value in ipairs(ZO_MENU_ENTRIES) do
        if value.id ~= MENU_ID and type(value.subMenu) == "table" and value.data and type(value.data.subMenu) == "table"
            and (value.id == "LibHarvensAddonSettings" or value.data.name == title) then root = value; break end
    end
    local changed = false
    for index = #ZO_MENU_ENTRIES, 1, -1 do
        local value = ZO_MENU_ENTRIES[index]
        if value.id == W.name then table.remove(ZO_MENU_ENTRIES, index); changed = true
        elseif value.id == MENU_ID and root then
            -- Preserve any other add-on that joined our fallback category.
            for _, child in ipairs(value.subMenu or {}) do
                local found = false
                for _, existing in ipairs(root.subMenu) do if existing.id == child.id then found = true; break end end
                if not found then
                    root.subMenu[#root.subMenu + 1] = child
                    root.data.subMenu[#root.data.subMenu + 1] = child.data
                end
            end
            table.remove(ZO_MENU_ENTRIES, index); changed = true
        elseif value.id == MENU_ID then root = value end
    end
    if not root then
        root = entry(MENU_ID, { name = title, icon = "EsoUI/Art/Options/Gamepad/gp_options_addons.dds",
            customTemplate = "ZO_GamepadMenuEntryTemplateWithArrow", subMenu = {} })
        root.subMenu = {}
        ZO_MENU_ENTRIES[#ZO_MENU_ENTRIES + 1] = root
        changed = true
    end
    local found = false
    for _, child in ipairs(root.subMenu) do if child.id == W.name then found = true; break end end
    if not found then
        local child = entry(W.name, { name = "WeavePulse", icon = ICON, scene = SCENE })
        local position = #root.subMenu + 1
        for index, other in ipairs(root.subMenu) do
            if other.data and type(other.data.name) == "string" and other.data.name > "WeavePulse" then position = index; break end
        end
        table.insert(root.subMenu, position, child)
        table.insert(root.data.subMenu, position, child.data)
        changed = true
    end
    if changed then MAIN_MENU_GAMEPAD:RefreshMainList() end
    return true
end

function S:Initialize()
    self.scene = ZO_Scene:New(SCENE, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
    self.scene:AddFragment(FRAME_EMOTE_FRAGMENT_SYSTEM)
    self.scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    self.scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    self.scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    self.scene:AddFragment(ZO_FadeSceneFragment:New(WeavePulseGamepad))
    self.scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            self:CreateUI()
            self.ui.active = true
            self:ShowPanel(self.pendingPanel)
            self.pendingPanel = nil
            self.ui.list:Activate()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.ui.keybinds)
            self.ui.keybindsAdded = true
            self:UpdateSelection()
        elseif state == SCENE_HIDING and self.ui then
            self.ui.active = false
            if self.ui.activeSlider then self.ui.activeSlider:Deactivate(); self.ui.activeSlider = nil end
            self.ui.list:Deactivate()
            if self.ui.keybindsAdded then KEYBIND_STRIP:RemoveKeybindButtonGroup(self.ui.keybinds) end
            self.ui.keybindsAdded = false
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            W:ClearPreviews()
        end
    end)
    local commands = { ["/wp"] = "General", ["/weavepulse"] = "General", ["/wpp"] = "Progressbar",
        ["/wpr"] = "Resources", ["/wpstacks"] = "StackTracker", ["/wpla"] = "LATracker" }
    for command, key in pairs(commands) do
        local panelKey = key
        SLASH_COMMANDS[command] = function() self:Open(panelKey) end
    end
    self:RegisterMenu()
end
