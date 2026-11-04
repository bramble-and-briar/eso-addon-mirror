-- Private EOTU settings, adapted from LibAddonMenu-2.0 r44's option data and
-- checkbox value handling. Copyright Ryan Lakanen (Seerah) and contributors.
-- Distributed under the Artistic License 2.0; see third-party/LibAddonMenu-LICENSE.txt.
-- This subset uses ESO's own gamepad templates directly, exposes no LAM globals,
-- and omits the library registry, keyboard window and console library converter.
local C = EOTU_Config or { NAME_SHORT = "EOTU", ADDON_NAME = "EyesOfTheUndaunted" }
local addon = _G[C.NAME_SHORT] or EOTU
local MapPins = addon.internal.mapPins
local SCENE_NAME = "EyesOfTheUndauntedSettings"
local ICON = "EsoUI/Art/WorldMap/map_indexicon_locations_down.dds"
local ADDONS_MENU_ID = "EyesOfTheUndauntedAddons"
local ADDONS_ICON = "EsoUI/Art/Options/Gamepad/gp_options_addons.dds"

function addon:SetPreference(key, value)
    if key == "pinSize" then
        value = tonumber(value)
        if not value or value ~= value or value < 16 or value > 36 or value ~= math.floor(value) then
            self:Print("Pin size must be a whole number from 16 to 36.")
            return false
        end
    elseif (key ~= "showBosses" and key ~= "showImperialCity" and key ~= "showPatrols") or type(value) ~= "boolean" then return false end
    self.savedVars[key] = value
    if key == "pinSize" then MapPins:SetLayoutKey(self.pinType, "size", value) end
    MapPins:RefreshPins(self.pinType)
    if self.settingsUI and self.settingsUI.active then self:RefreshOptions() end
    return true
end

function addon:ResetPreferences()
    for _, key in ipairs({ "showBosses", "showImperialCity", "showPatrols", "pinSize" }) do self.savedVars[key] = self.defaults[key] end
    MapPins:SetLayoutKey(self.pinType, "size", self.savedVars.pinSize)
    MapPins:RefreshPins(self.pinType)
    if self.settingsUI and self.settingsUI.active then self:RefreshOptions() end
end

function addon:BuildOptionRows()
    local rows = {}
    local function toggle(key, label, description)
        rows[#rows + 1] = {
            type = "checkbox", key = key, name = label, tooltip = description,
            getFunc = function() return self.savedVars[key] end,
            setFunc = function(value) self:SetPreference(key, value) end,
        }
    end
    toggle("showBosses", "Boss pins", "Show boss locations in delves, public dungeons, group dungeons and Imperial City.")
    toggle("showImperialCity", "Imperial City", "Include district bosses, sewer champions and the Molag Bal encounter.")
    toggle("showPatrols", "Patrol references", "Show patrol reference points. Bosses move along their routes; pins do not report their live position or availability.")
    rows[#rows + 1] = {
        type = "slider", key = "pinSize", name = "Pin size", min = 16, max = 36, step = 1,
        tooltip = "Adjust the size of boss pins on the map.",
        getFunc = function() return self.savedVars.pinSize end,
        setFunc = function(value) self:SetPreference("pinSize", value) end,
    }
    return rows
end

local function SetRowAppearance(control, row, selected)
    control.data = row
    local label = control:GetNamedChild("Name")
    label:SetText(row.name)
    label:SetColor(ZO_GamepadMenuEntryTemplate_GetLabelColor(selected, false):UnpackRGBA())
    SetMenuEntryFontFace(label, selected)
    control:SetAlpha(ZO_GamepadMenuEntryTemplate_GetAlpha(selected))
end

local function UpdateCheckbox(control, value)
    -- A false value is a write, while nil means read the current preference.
    if value ~= nil then control.data.setFunc(value) else value = control.data.getFunc() end
    ZO_CheckButton_SetCheckState(control:GetNamedChild("Checkbox"), value)
    control:GetNamedChild("On"):SetColor((value and ZO_DEFAULT_ENABLED_COLOR or ZO_DEFAULT_DISABLED_COLOR):UnpackRGBA())
    control:GetNamedChild("Off"):SetColor((value and ZO_DEFAULT_DISABLED_COLOR or ZO_DEFAULT_ENABLED_COLOR):UnpackRGBA())
end

function addon:UpdateSettingsSelection()
    local ui = self.settingsUI
    if not ui or not ui.active then return end
    local control = ui.list:GetSelectedControl()
    local slider = control and control.slider
    if ui.activeSlider and ui.activeSlider ~= slider then ui.activeSlider:Deactivate() end
    ui.activeSlider = slider
    if slider then slider:Activate() end
    local row = ui.list:GetTargetData()
    if row then GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, row.tooltip, "") end
    if ui.keybindsAdded then KEYBIND_STRIP:UpdateKeybindButtonGroup(ui.keybinds) end
end

function addon:RefreshOptions()
    local ui = self.settingsUI
    if not ui then return end
    -- Values change in place, so adjusting the slider keeps its input focus.
    ui.list:RefreshVisible()
    self:UpdateSettingsSelection()
end

function addon:CreateSettingsUI()
    if self.settingsUI then return end
    local window = EyesOfTheUndauntedGamepad
    local container = window:GetNamedChild("MaskContainer")
    local header = container:GetNamedChild("HeaderContainer").header
    ZO_GamepadGenericHeader_Initialize(header, false)
    ZO_GamepadGenericHeader_RefreshData(header, { titleText = "Eyes of the Undaunted", subtitleText = C.VERSION })
    local list = ZO_GamepadVerticalItemParametricScrollList:New(container:GetNamedChild("List"))
    local ui = { window = window, header = header, list = list }
    self.settingsUI = ui
    list:SetAlignToScreenCenter(true)
    list:AddDataTemplate("ZO_GamepadOptionsCheckboxRow", function(control, row, selected)
        SetRowAppearance(control, row, selected)
        local checkbox = control:GetNamedChild("Checkbox")
        -- The row already has separate On/Off labels. Keep its inherited text
        -- button blank, including subsequent native checked-state updates.
        checkbox.checkedText, checkbox.uncheckedText = "", ""
        checkbox:SetText("")
        checkbox.selected = selected
        ZO_CheckButton_SetToggleFunction(checkbox, nil)
        UpdateCheckbox(control)
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, value) UpdateCheckbox(control, value) end)
    end, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplate("EyesOfTheUndauntedGamepadSlider", function(control, row, selected)
        SetRowAppearance(control, row, selected)
        local slider = control.slider
        slider:SetHandler("OnValueChanged", nil)
        slider:SetMinMax(row.min, row.max)
        slider:SetValueStep(row.step)
        slider:SetValue(row.getFunc())
        control:GetNamedChild("ValueLabel"):SetText(row.getFunc())
        slider:SetHandler("OnValueChanged", function(_, value)
            row.setFunc(math.floor(value + .5))
        end)
    end, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:SetDataTemplateReleaseFunction("EyesOfTheUndauntedGamepadSlider", function(control)
        control.slider:Deactivate()
        control.slider:SetHandler("OnValueChanged", nil)
    end)
    list:SetOnSelectedDataChangedCallback(function() self:UpdateSettingsSelection() end)
    list:SetOnTargetDataChangedCallback(function() self:UpdateSettingsSelection() end)
    ui.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { keybind = "UI_SHORTCUT_PRIMARY", name = GetString(SI_GAMEPAD_TOGGLE_OPTION), visible = function()
            local row = list:GetTargetData()
            return row and row.type == "checkbox"
        end, callback = function()
            local control = list:GetSelectedControl()
            if control and control.data.type == "checkbox" then ZO_CheckButton_OnClicked(control:GetNamedChild("Checkbox")) end
        end },
        { keybind = "UI_SHORTCUT_SECONDARY", name = GetString(SI_OPTIONS_DEFAULTS), callback = function() self:ResetPreferences() end },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(ui.keybinds, GAME_NAVIGATION_TYPE_BUTTON, function() SCENE_MANAGER:Hide(SCENE_NAME) end)
    for _, row in ipairs(self:BuildOptionRows()) do
        list:AddEntry(row.type == "checkbox" and "ZO_GamepadOptionsCheckboxRow" or "EyesOfTheUndauntedGamepadSlider", row)
    end
    list:Commit()
end

function addon:OpenOptions()
    if self.settingsScene:IsShowing() then SCENE_MANAGER:Hide(SCENE_NAME)
    else SCENE_MANAGER:Push(SCENE_NAME) end
end

function addon:RegisterGamepadMenu()
    if not self.menuWatcherRegistered and MAIN_MENU_GAMEPAD_SCENE then
        self.menuWatcherRegistered = true
        MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then self:RegisterGamepadMenu() end
        end)
    end
    if type(ZO_MENU_ENTRIES) ~= "table" or not MAIN_MENU_GAMEPAD then return false end
    local function CreateEntry(id, data)
        local entry = ZO_GamepadEntryData:New(data.name, data.icon)
        entry:SetIconTintOnSelection(true)
        entry:SetIconDisabledTintOnSelection(true)
        entry.id, entry.data = id, data
        return entry
    end
    local title, root = GetString(SI_GAME_MENU_ADDONS)
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.id ~= ADDONS_MENU_ID and type(entry.subMenu) == "table" and entry.data and type(entry.data.subMenu) == "table"
            and (entry.id == "LibHarvensAddonSettings" or entry.data.name == title) then root = entry; break end
    end
    local changed = false
    -- A common Add-ons menu may be created lazily on its first showing. Move
    -- only our entry into it, preserving its other addons and native callbacks.
    for index = #ZO_MENU_ENTRIES, 1, -1 do
        local entry = ZO_MENU_ENTRIES[index]
        if entry.id == C.ADDON_NAME or (entry.id == ADDONS_MENU_ID and root) then
            table.remove(ZO_MENU_ENTRIES, index); changed = true
        elseif entry.id == ADDONS_MENU_ID then root = entry end
    end
    if not root then
        root = CreateEntry(ADDONS_MENU_ID, { name = title, icon = ADDONS_ICON,
            customTemplate = "ZO_GamepadMenuEntryTemplateWithArrow", subMenu = {} })
        root.subMenu = {}
        local position = #ZO_MENU_ENTRIES + 1
        for index, entry in ipairs(ZO_MENU_ENTRIES) do
            if ZO_MENU_MAIN_ENTRIES and entry.id == ZO_MENU_MAIN_ENTRIES.ACTIVITY_FINDER then position = index; break end
        end
        table.insert(ZO_MENU_ENTRIES, position, root); changed = true
    end
    local exists = false
    for _, entry in ipairs(root.subMenu) do if entry.id == C.ADDON_NAME then exists = true; break end end
    if not exists then
        local entry = CreateEntry(C.ADDON_NAME, { name = "Eyes of the Undaunted", icon = ICON, scene = SCENE_NAME })
        local position = #root.subMenu + 1
        for index, other in ipairs(root.subMenu) do
            local name = other.data and other.data.name
            if type(name) == "string" and name > entry.data.name then position = index; break end
        end
        table.insert(root.subMenu, position, entry)
        table.insert(root.data.subMenu, position, entry.data)
        changed = true
    end
    if changed then MAIN_MENU_GAMEPAD:RefreshMainList() end
    return true
end

function addon:RegisterRadial()
    if self.radialRegistered then return true end
    local radial = LibRadialMenu
    if not radial or type(radial.RegisterAddon) ~= "function" or type(radial.RegisterEntry) ~= "function" then return false end
    radial:RegisterAddon(C.ADDON_NAME, "Eyes of the Undaunted")
    radial:RegisterEntry(C.ADDON_NAME, "Open controls", "controls", ICON, function() self:OpenOptions() end,
        "Open Eyes of the Undaunted's native gamepad controls.")
    radial:RegisterEntry(C.ADDON_NAME, "Toggle boss pins", "toggle", ICON,
        function() self:SetPreference("showBosses", not self.savedVars.showBosses) end, "Show or hide all Eyes of the Undaunted boss pins.")
    self.radialRegistered = true
    return true
end

function addon:CreateOptions()
    if self.settingsScene then return end
    self.settingsScene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    self.settingsScene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    self.settingsScene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
    self.settingsScene:AddFragment(FRAME_EMOTE_FRAGMENT_SYSTEM)
    self.settingsScene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    self.settingsScene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    self.settingsScene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    self.settingsScene:AddFragment(ZO_FadeSceneFragment:New(EyesOfTheUndauntedGamepad))
    self.settingsScene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            self:CreateSettingsUI()
            self.settingsUI.active = true
            self.settingsUI.list:Activate()
            self:RefreshOptions()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.settingsUI.keybinds)
            self.settingsUI.keybindsAdded = true
        elseif state == SCENE_HIDING and self.settingsUI then
            self.settingsUI.active = false
            if self.settingsUI.activeSlider then self.settingsUI.activeSlider:Deactivate(); self.settingsUI.activeSlider = nil end
            self.settingsUI.list:Deactivate()
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.settingsUI.keybinds)
            self.settingsUI.keybindsAdded = false
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
    end)
    SLASH_COMMANDS[C.COMMAND or "/eotu"] = function(command)
        local verb, argument = tostring(command or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
        if verb == "" or verb == "settings" then self:OpenOptions()
        elseif verb == "show" then self:SetPreference("showBosses", true)
        elseif verb == "hide" then self:SetPreference("showBosses", false)
        elseif verb == "toggle" then self:SetPreference("showBosses", not self.savedVars.showBosses)
        elseif verb == "size" then self:SetPreference("pinSize", argument)
        elseif (verb == "patrols" or verb == "imperial") and (argument == "on" or argument == "off") then
            self:SetPreference(verb == "patrols" and "showPatrols" or "showImperialCity", argument == "on")
        elseif verb == "defaults" then self:ResetPreferences()
        elseif verb == "debug" then SLASH_COMMANDS[C.SLASH or "/eotu_debug"]()
        else self:Print("/eotu: settings, show, hide, toggle, size 16-36, imperial on/off, patrols on/off, defaults, debug.") end
    end
    self:RegisterGamepadMenu()
    self:RegisterRadial()
    if not self.radialRegistered then
        EVENT_MANAGER:RegisterForEvent(C.ADDON_NAME .. "Radial", EVENT_ADD_ON_LOADED, function()
            if self:RegisterRadial() then EVENT_MANAGER:UnregisterForEvent(C.ADDON_NAME .. "Radial", EVENT_ADD_ON_LOADED) end
        end)
    end
end
