NGear = NGear or {}

local GamepadOptions = {}
NGear.GamepadOptions = GamepadOptions

GamepadOptions.PanelIds = {
    ROOT = 19100,
    STICKER_BOOK = 19101,
    ITEM_LOCATOR = 19102,
    ITEM_CATEGORIES = 19111,
}

local PanelIds = GamepadOptions.PanelIds
local ROOT_PANEL_ID = PanelIds.ROOT
local CATEGORY_NAME_KEY = "ui.addons_menu.ngear_name"
local ADDONS_MENU_ICON = "/esoui/art/options/gamepad/gp_options_addons.dds"
local ADDON_ENTRY_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_collections.dds"
local SHARED_ADDONS_MENU_ENTRY_ID = "LibHarvensAddonSettings"
local FALLBACK_ADDONS_MENU_ENTRY_ID = "NGear_AddonsRoot"
local MAIN_MENU_ENTRY_ID = "NGear_Addons"
local LANGUAGE_RELOAD_DIALOG_NAME = "NGear_LANGUAGE_RELOAD_CONFIRM"
local DEFERRED_SLIDER_APPLY_MS = 150
local Clamp = NGear.Util.Clamp
local panelResetInProgress = {}
local queuedLanguageChoice
local languageDialogRegistered = false
local panelsRegistered = false
local sharedAddonsMenuHookInstalled = false
local mainMenuWatcherInstalled = false
local backOverrideInstalled = false
local headerVersionHooked = false

local SUBPANEL_PARENT_IDS = {
    [PanelIds.STICKER_BOOK] = ROOT_PANEL_ID,
    [PanelIds.ITEM_LOCATOR] = ROOT_PANEL_ID,
    [PanelIds.ITEM_CATEGORIES] = ROOT_PANEL_ID,
}

local PANEL_RESET_PATHS = {
    [ROOT_PANEL_ID] = {},
    [PanelIds.STICKER_BOOK] = { { "collections", "stickerBook" } },
    [PanelIds.ITEM_LOCATOR] = {},
    [PanelIds.ITEM_CATEGORIES] = {},
}

local function ResolveNumericOptionValue(value)
    if type(value) == "function" then
        value = value()
    end
    return tonumber(value)
end

local function ResolveTextEntry(textEntry, control)
    if type(textEntry) == "function" then
        return textEntry(control)
    elseif type(textEntry) == "number" and GetString then
        return GetString(textEntry)
    end
    return textEntry
end

local function GetNumericValueFormat(valueFormat)
    if type(valueFormat) ~= "string" then
        return "%d"
    end
    return string.match(valueFormat, "(%%[%d%.]*[df])") or "%d"
end

local function FormatSliderLabelValue(value, valueFormat)
    return string.format(GetNumericValueFormat(valueFormat), tonumber(value) or 0)
end

local function BuildSliderLabel(label, valueFormat, getFunc)
    return function(control)
        local labelText = ResolveTextEntry(label, control) or ""
        local value = control and control.data and control.data.ngearLabelValueOverride
        if value == nil then
            value = getFunc()
        end
        return labelText .. " (" .. FormatSliderLabelValue(value, valueFormat) .. ")"
    end
end

local function GetSliderStepPercent(minValue, maxValue, stepSize)
    minValue = ResolveNumericOptionValue(minValue) or 0
    maxValue = ResolveNumericOptionValue(maxValue) or minValue
    local range = maxValue - minValue
    stepSize = tonumber(stepSize)
    if not stepSize or stepSize <= 0 or range <= 0 then
        return nil
    end
    return (stepSize / range) * 100
end

local function SetFeaturePreview(panelId)
    local features = NGear.Features or {}
    if NGear.ItemLocator and NGear.ItemLocator.SetSettingsPanelVisible then
        NGear.ItemLocator.SetSettingsPanelVisible(panelId == PanelIds.ITEM_LOCATOR)
    end
    if features.StickerBook then
        features.StickerBook.SetSettingsPanelVisible(panelId == PanelIds.STICKER_BOOK)
    end
end

local function OpenRootPanel()
    if not GAMEPAD_OPTIONS or not SCENE_MANAGER then return end
    GAMEPAD_OPTIONS.currentCategory = ROOT_PANEL_ID
    SetFeaturePreview(nil)
    SCENE_MANAGER:Push("gamepad_options_panel")
end

function GamepadOptions.ResetSettingToDefault(_, settingData)
    if settingData then
        GamepadOptions.ResetPanelOptionsToDefaults(settingData.panel)
    end
end

function GamepadOptions.ResetPanelOptionsToDefaults(panelId)
    if panelResetInProgress[panelId] then return end
    panelResetInProgress[panelId] = true

    for _, path in ipairs(PANEL_RESET_PATHS[panelId] or {}) do
        NGear.Settings.ResetPath(path)
    end
    if panelId == PanelIds.ITEM_CATEGORIES and NGear.ItemLocator then
        NGear.ItemLocator.ResetCategoryVisibility()
    elseif panelId == PanelIds.ITEM_LOCATOR and NGear.ItemLocator then
        NGear.ItemLocator.ResetDisplaySettings()
    end
    GamepadOptions.ApplyPanelOptions(panelId)
    panelResetInProgress[panelId] = nil
end

function GamepadOptions.ResetAllPanelsToDefaults()
    -- Stop tracking before resetting preferences so pending inventory changes
    -- are flushed and event handlers are removed through the normal lifecycle.
    if NGear.ItemLocator then
        NGear.ItemLocator.SetEnabled(false)
    end
    -- Saved-variable defaults also contain collected indexes. Only reset the
    -- preferences explicitly owned by each panel, never entire saved scopes.
    for _, panelId in pairs(PanelIds) do
        GamepadOptions.ResetPanelOptionsToDefaults(panelId)
    end
    GamepadOptions.RefreshCurrentOptionsList()
end

function GamepadOptions.AttachPanelReset(optionsData, panelId)
    if not optionsData or #optionsData == 0 then return end
    if panelId == ROOT_PANEL_ID then
        optionsData[1].customResetToDefaultsFunction = GamepadOptions.ResetAllPanelsToDefaults
    elseif PANEL_RESET_PATHS[panelId] then
        optionsData[1].customResetToDefaultsFunction = function()
            GamepadOptions.ResetPanelOptionsToDefaults(panelId)
        end
    end
end

function GamepadOptions.ApplyPanelOptions(panelId)
    local panelSettings = GAMEPAD_SETTINGS_DATA and GAMEPAD_SETTINGS_DATA[panelId]
    if not panelSettings or not GAMEPAD_OPTIONS or not GAMEPAD_OPTIONS.GetSettingsData then return end
    for _, setting in ipairs(panelSettings) do
        local settingData = GAMEPAD_OPTIONS:GetSettingsData(setting.panel, setting.system, setting.settingId)
        if settingData and settingData.GetSettingOverride and settingData.SetSettingOverride then
            settingData.SetSettingOverride(nil, settingData.GetSettingOverride())
        end
    end
end

function GamepadOptions.IsSubpanel(panelId)
    return SUBPANEL_PARENT_IDS[panelId] ~= nil
end

function GamepadOptions.ReplaceSubpanelBackKeybind()
    GAMEPAD_OPTIONS:ReplaceBackKeybind(function()
        local childPanelId = GAMEPAD_OPTIONS.currentCategory
        GamepadOptions.ShowPanel(ROOT_PANEL_ID, GamepadOptions.parentSelectionByChildPanel[childPanelId])
    end)
end

function GamepadOptions.ShowPanel(panelId, selectedIndex)
    local currentPanelId = GAMEPAD_OPTIONS.currentCategory
    if SUBPANEL_PARENT_IDS[panelId] == currentPanelId then
        local optionsList = GAMEPAD_OPTIONS.optionsList
        if optionsList and optionsList.GetSelectedIndex then
            GamepadOptions.parentSelectionByChildPanel[panelId] = optionsList:GetSelectedIndex()
        end
    end

    if GAMEPAD_OPTIONS.optionsList and GAMEPAD_OPTIONS.DeactivateSelectedControl then
        GAMEPAD_OPTIONS:DeactivateSelectedControl()
    end
    GAMEPAD_OPTIONS.currentCategory = panelId
    GAMEPAD_OPTIONS:RefreshHeader()
    GAMEPAD_OPTIONS:RefreshOptionsList()

    local optionsList = GAMEPAD_OPTIONS.optionsList
    if optionsList and selectedIndex then
        if optionsList.SetSelectedIndexWithoutAnimation then
            optionsList:SetSelectedIndexWithoutAnimation(selectedIndex, true)
        elseif optionsList.SetSelectedIndex then
            optionsList:SetSelectedIndex(selectedIndex, true)
        end
    end

    SetFeaturePreview(panelId)
    if GamepadOptions.IsSubpanel(panelId) then
        GamepadOptions.ReplaceSubpanelBackKeybind()
    else
        GAMEPAD_OPTIONS:RevertBackKeybind()
    end
end

function GamepadOptions.AddChevron(control)
    if control.NGearChevron then
        control.NGearChevron:SetHidden(false)
        return
    end
    local chevron = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    chevron:SetDimensions(24, 24)
    chevron:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_menu_rightArrow.dds")
    chevron:SetAnchor(RIGHT, control, RIGHT, -8, 0)
    control.NGearChevron = chevron
end

function GamepadOptions.HideDivider(control)
    if control.NGearDivider then
        control.NGearDivider:SetHidden(true)
    end
end

function GamepadOptions.InitializeNavigationEntry(control)
    GamepadOptions.HideDivider(control)
    GamepadOptions.AddChevron(control)
end

function GamepadOptions.RefreshCurrentOptionsList()
    if GAMEPAD_OPTIONS and GAMEPAD_OPTIONS.RefreshOptionsList then
        GAMEPAD_OPTIONS:RefreshOptionsList()
    end
end

function GamepadOptions.AddHeader(optionData, text)
    optionData.header = function() return text end
    return optionData
end

function GamepadOptions.GetSelectedLanguagePreference()
    return queuedLanguageChoice or NGear.Lexicon.GetLanguagePreference()
end

function GamepadOptions.SelectLanguagePreference(value)
    if not NGear.Lexicon.IsLanguagePreference(value) then return end

    local preference = NGear.Lexicon.NormalizeLanguagePreference(value)
    queuedLanguageChoice = preference ~= NGear.Lexicon.GetLanguagePreference() and preference or nil
end

local function EnsureLanguageDialog()
    if languageDialogRegistered or not ZO_Dialogs_RegisterCustomDialog then return end

    ZO_Dialogs_RegisterCustomDialog(LANGUAGE_RELOAD_DIALOG_NAME, {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = NGear.L("dialogs.language_reload.title"),
        },
        mainText = {
            text = NGear.L("dialogs.language_reload.message"),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_YES,
                callback = function(dialog)
                    local preference = dialog and dialog.data and dialog.data.preference
                    if NGear.Lexicon.IsLanguagePreference(preference)
                        and NGear.Lexicon.SetLanguagePreference(preference) then
                        ReloadUI("ingame")
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_NO,
            },
        },
    })
    languageDialogRegistered = true
end

local function ShowLanguageDialog(preference)
    EnsureLanguageDialog()
    if not languageDialogRegistered then return end

    local dialogData = { preference = preference }
    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(LANGUAGE_RELOAD_DIALOG_NAME, dialogData)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(LANGUAGE_RELOAD_DIALOG_NAME, dialogData)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(LANGUAGE_RELOAD_DIALOG_NAME, dialogData)
    end
end

function GamepadOptions.ConfirmQueuedLanguageChange()
    local preference = queuedLanguageChoice
    queuedLanguageChoice = nil
    if not preference or preference == NGear.Lexicon.GetLanguagePreference() then return false end

    local showConfirmation = function() ShowLanguageDialog(preference) end
    if zo_callLater then
        zo_callLater(showConfirmation, 1)
    else
        showConfirmation()
    end
    return true
end

function GamepadOptions.IsOptionControl(control)
    local data = control and control.data
    return data and data.ngearOption == true and data.SetSettingOverride ~= nil
end

function GamepadOptions.ApplySetting(control, value)
    if not GamepadOptions.IsOptionControl(control) then return false end
    local data = control.data
    data.SetSettingOverride(control, value)
    data.ngearUpdatingControl = true
    ZO_Options_UpdateOption(control)
    data.ngearUpdatingControl = nil
    GamepadOptions.SetOptionControlHandler(control)
    return true
end

function GamepadOptions.RefreshControlLabel(control)
    local data = control and control.data
    if not data or not data.ngearRefreshLabelOnChange then return end
    local labelControl = control.label or control:GetNamedChild("Name") or control:GetNamedChild("Label")
    if not labelControl then return end
    local text = ResolveTextEntry(data.gamepadTextOverride or data.text, control)
    if type(text) == "string" then labelControl:SetText(text) end
end

function GamepadOptions.ApplySliderSetting(control, value)
    if not GamepadOptions.IsOptionControl(control) then return false end
    local data = control.data
    local valueFormat = data.valueFormat or "%d"
    local valueLabelControl = control:GetNamedChild("ValueLabel")
    if data.showValue and valueLabelControl and ZO_Options_GetFormattedSliderValues then
        valueLabelControl:SetText(ZO_Options_GetFormattedSliderValues(data, string.format(valueFormat, value)))
    end

    if data.deferredApply then
        data.ngearDeferredSliderSerial = (data.ngearDeferredSliderSerial or 0) + 1
        local serial = data.ngearDeferredSliderSerial
        zo_callLater(function()
            if data.ngearDeferredSliderSerial == serial then
                data.SetSettingOverride(control, value)
            end
        end, data.deferredApplyDelayMs or DEFERRED_SLIDER_APPLY_MS)
    else
        data.SetSettingOverride(control, value)
    end

    data.ngearLabelValueOverride = value
    GamepadOptions.RefreshControlLabel(control)
    data.ngearLabelValueOverride = nil
    return true
end

function GamepadOptions.OnScrollListSelectionChanged(selectedData, oldData, reselectingDuringRebuild)
    local parentControl = selectedData and selectedData.parentControl
    if parentControl and parentControl.data and parentControl.data.enabled == false then return end
    if oldData ~= nil and reselectingDuringRebuild ~= true and parentControl then
        GamepadOptions.ApplySetting(parentControl, selectedData.value)
    end
end

function GamepadOptions.SetOptionControlHandler(control)
    if not GamepadOptions.IsOptionControl(control) then return end
    local data = control.data
    if data.controlType == OPTIONS_FINITE_LIST and control.horizontalListObject then
        control.horizontalListObject:SetOnSelectedDataChangedCallback(GamepadOptions.OnScrollListSelectionChanged)
    elseif data.controlType == OPTIONS_CHECKBOX then
        local checkBoxControl = control:GetNamedChild("Checkbox")
        if checkBoxControl then
            ZO_CheckButton_SetToggleFunction(checkBoxControl, function(_, checked)
                GamepadOptions.ApplySetting(control, checked)
            end)
        end
    elseif data.controlType == OPTIONS_SLIDER then
        local sliderControl = control:GetNamedChild("Slider")
        if sliderControl then
            sliderControl:SetHandler("OnValueChanged", function(_, value)
                if not data.ngearUpdatingControl then
                    GamepadOptions.ApplySliderSetting(control, value)
                end
            end)
        end
    end
end

function GamepadOptions.RunOptionInitialize(control, isKeyboardControl, initializeFunc)
    GamepadOptions.SetOptionControlHandler(control)
    if initializeFunc then initializeFunc(control, isKeyboardControl) end
    local data = control and control.data
    zo_callLater(function()
        if control and control.data == data then
            GamepadOptions.SetOptionControlHandler(control)
            GamepadOptions.RefreshControlLabel(control)
        end
    end, 0)
end

function GamepadOptions.BuildSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, stepPercent, deferredApply, defaultValue)
    local sliderLabel = BuildSliderLabel(label, valueFormat, getFunc)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        ngearOption = true,
        controlType = OPTIONS_SLIDER,
        text = sliderLabel,
        gamepadTextOverride = sliderLabel,
        tooltipText = tooltip,
        minValue = minValue,
        maxValue = maxValue,
        valueFormat = valueFormat,
        showValue = true,
        showValueMin = minValue,
        showValueMax = maxValue,
        gamepadValueStepPercent = stepPercent,
        deferredApply = deferredApply == true,
        default = defaultValue,
        ngearRefreshLabelOnChange = true,
        customResetToDefaultsFunction = GamepadOptions.ResetSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function() return getFunc() end,
        SetSettingOverride = function(_, value) setFunc(value) end,
    }
end

function GamepadOptions.BuildValueStepSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, valueStep, deferredApply, defaultValue)
    return GamepadOptions.BuildSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, GetSliderStepPercent(minValue, maxValue, valueStep), deferredApply, defaultValue)
end

function GamepadOptions.BuildPositionSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, deferredApply, defaultValue)
    minValue = ResolveNumericOptionValue(minValue) or 0
    maxValue = ResolveNumericOptionValue(maxValue) or minValue
    if valueFormat == "%.0f" then valueFormat = "%.2f" end
    return GamepadOptions.BuildSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, GetSliderStepPercent(minValue, maxValue, 1), deferredApply, defaultValue)
end

function GamepadOptions.BuildCheckboxOption(panelId, settingId, label, tooltip, getFunc, setFunc, enabledFunc, defaultValue)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        ngearOption = true,
        controlType = OPTIONS_CHECKBOX,
        text = label,
        gamepadTextOverride = label,
        tooltipText = tooltip,
        enabled = enabledFunc,
        default = defaultValue,
        customResetToDefaultsFunction = GamepadOptions.ResetSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function() return getFunc() end,
        SetSettingOverride = function(_, value) setFunc(value) end,
    }
end

function GamepadOptions.BuildFiniteListOption(panelId, settingId, label, tooltip, choices, choiceNames, getFunc, setFunc, defaultValue)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        ngearOption = true,
        controlType = OPTIONS_FINITE_LIST,
        text = label,
        gamepadTextOverride = label,
        tooltipText = tooltip,
        valid = choices,
        itemText = choiceNames,
        default = defaultValue,
        customResetToDefaultsFunction = GamepadOptions.ResetSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function() return getFunc() end,
        SetSettingOverride = function(_, value) setFunc(value) end,
    }
end

function GamepadOptions.BuildActionOption(panelId, settingId, label, tooltip, callback)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = label,
        gamepadTextOverride = label,
        tooltipText = tooltip,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        callback = callback,
    }
end

function GamepadOptions.RegisterSharedOptions(panelId, optionsData)
    if not ZO_SharedOptions or not ZO_SharedOptions.AddTableToPanel then return end
    local sharedOptions = { [panelId] = {} }
    for _, optionData in ipairs(optionsData) do
        sharedOptions[panelId][optionData.settingId] = ZO_ShallowTableCopy(optionData)
    end
    ZO_SharedOptions.AddTableToPanel(panelId, sharedOptions)
end

function GamepadOptions.RegisterPanel(panelId, optionsData)
    GamepadOptions.AttachPanelReset(optionsData, panelId)
    local isRegistered = GAMEPAD_SETTINGS_DATA[panelId] ~= nil
    GAMEPAD_SETTINGS_DATA[panelId] = optionsData
    if not isRegistered then
        GamepadOptions.RegisterSharedOptions(panelId, optionsData)
    end
end

function GamepadOptions.ReplacePanel(panelId, optionsData)
    GamepadOptions.AttachPanelReset(optionsData, panelId)
    GAMEPAD_SETTINGS_DATA[panelId] = optionsData
    if ZO_SharedOptions_SettingsData then ZO_SharedOptions_SettingsData[panelId] = nil end
    GamepadOptions.RegisterSharedOptions(panelId, optionsData)
end

function GamepadOptions.RegisterPanelHeaderStrings()
    local headers = {
        [ROOT_PANEL_ID] = "NGear",
        [PanelIds.STICKER_BOOK] = NGear.L("ui.navigation.sticker_book"),
        [PanelIds.ITEM_LOCATOR] = NGear.L("ui.navigation.item_locator"),
        [PanelIds.ITEM_CATEGORIES] = NGear.L("ui.navigation.item_categories"),
    }
    for panelId, title in pairs(headers) do
        ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. panelId, title)
        SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. panelId, 1)
    end
end

function GamepadOptions.ApplyHeaderVersionSubtitle()
    if not GAMEPAD_OPTIONS or not GAMEPAD_OPTIONS.header or not GAMEPAD_OPTIONS.headerData
        or not ZO_GamepadGenericHeader_RefreshData then return end
    local version = NGear.version
    GAMEPAD_OPTIONS.headerData.subtitleText = GAMEPAD_OPTIONS.currentCategory == ROOT_PANEL_ID
        and version and version ~= 0 and ("v" .. tostring(version)) or nil
    ZO_GamepadGenericHeader_RefreshData(GAMEPAD_OPTIONS.header, GAMEPAD_OPTIONS.headerData)
end

function GamepadOptions.HookHeaderVersionSubtitle()
    if headerVersionHooked or not GAMEPAD_OPTIONS or type(ZO_PostHook) ~= "function" then return end
    headerVersionHooked = true
    ZO_PostHook(GAMEPAD_OPTIONS, "RefreshHeader", GamepadOptions.ApplyHeaderVersionSubtitle)
end

function GamepadOptions.RegisterPanels()
    if panelsRegistered then return true end
    if not GAMEPAD_OPTIONS or not GAMEPAD_SETTINGS_DATA or not ZO_GamepadEntryData then return false end

    GamepadOptions.HookHeaderVersionSubtitle()
    GamepadOptions.RegisterPanelHeaderStrings()
    GamepadOptions.RegisterPanel(ROOT_PANEL_ID, GamepadOptions.BuildRootOptionsData())
    GamepadOptions.RegisterPanel(PanelIds.STICKER_BOOK, GamepadOptions.BuildStickerBookOptionsData())
    GamepadOptions.RegisterPanel(PanelIds.ITEM_LOCATOR, GamepadOptions.BuildItemLocatorOptionsData())
    -- Category construction decodes the complete account item index. Register an
    -- empty shell at login and populate it only when the player opens the panel.
    GamepadOptions.RegisterPanel(PanelIds.ITEM_CATEGORIES, {})

    panelsRegistered = true
    return true
end

local function CreateMainMenuEntry(name, icon, id, activatedCallback)
    local entryData = {
        name = name,
        icon = icon,
        activatedCallback = activatedCallback,
    }
    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.data = entryData
    entry.id = id
    return entry
end

local function FindMenuEntry(entries, entryId)
    for index, entry in ipairs(entries or {}) do
        if entry.id == entryId then return entry, index end
    end
    return nil, nil
end

local function GetMenuEntryName(entry)
    local name = entry and entry.data and entry.data.name
    if type(name) == "function" then name = name() end
    if name == nil and entry then name = entry.text end
    return tostring(name or "")
end

local function GetMenuEntrySortName(entry)
    local name = GetMenuEntryName(entry)
    name = string.gsub(name, "|[Cc]%x%x%x%x%x%x", "")
    name = string.gsub(name, "|[Rr]", "")
    return NGear.Util.Lower(name)
end

local function InsertSortedMenuEntry(entries, entry)
    local entryName = GetMenuEntrySortName(entry)
    local insertIndex = #entries + 1
    for index, existingEntry in ipairs(entries) do
        if entryName < GetMenuEntrySortName(existingEntry) then
            insertIndex = index
            break
        end
    end
    table.insert(entries, insertIndex, entry)
end

local function RefreshMainMenu()
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.UpdateEntryEnabledStates then
        MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
    elseif MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshMainList then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end
end

local function AddNGearEntry(addonsEntry)
    if not addonsEntry.subMenu then addonsEntry.subMenu = {} end
    if FindMenuEntry(addonsEntry.subMenu, MAIN_MENU_ENTRY_ID) then return false end

    local entry = CreateMainMenuEntry(
        NGear.L(CATEGORY_NAME_KEY),
        ADDON_ENTRY_ICON,
        MAIN_MENU_ENTRY_ID,
        OpenRootPanel
    )
    InsertSortedMenuEntry(addonsEntry.subMenu, entry)
    return true
end

function GamepadOptions.EnsureMainMenuEntry(createFallback)
    if not ZO_MENU_ENTRIES or not ZO_MENU_MAIN_ENTRIES or not ZO_GamepadEntryData
        or not SCENE_MANAGER then return false end

    local sharedAddonsEntry = FindMenuEntry(ZO_MENU_ENTRIES, SHARED_ADDONS_MENU_ENTRY_ID)
    local fallbackAddonsEntry, fallbackIndex = FindMenuEntry(ZO_MENU_ENTRIES, FALLBACK_ADDONS_MENU_ENTRY_ID)

    if sharedAddonsEntry then
        local changed = AddNGearEntry(sharedAddonsEntry)
        if fallbackIndex then
            table.remove(ZO_MENU_ENTRIES, fallbackIndex)
            changed = true
        end
        if changed then RefreshMainMenu() end
        return true
    end

    if fallbackAddonsEntry then
        if AddNGearEntry(fallbackAddonsEntry) then RefreshMainMenu() end
        return true
    end

    if not createFallback then return false end

    local subMenu = {}
    local entryData = {
        name = GetString(SI_GAME_MENU_ADDONS),
        icon = ADDONS_MENU_ICON,
        customTemplate = "ZO_GamepadMenuEntryTemplateWithArrow",
        subMenu = subMenu,
    }
    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.data = entryData
    entry.id = FALLBACK_ADDONS_MENU_ENTRY_ID
    entry.subMenu = subMenu
    AddNGearEntry(entry)

    local _, activityFinderIndex = FindMenuEntry(ZO_MENU_ENTRIES, ZO_MENU_MAIN_ENTRIES.ACTIVITY_FINDER)
    if activityFinderIndex then
        table.insert(ZO_MENU_ENTRIES, activityFinderIndex, entry)
    else
        table.insert(ZO_MENU_ENTRIES, entry)
    end

    RefreshMainMenu()
    return true
end

function GamepadOptions.InstallSharedAddonsMenuHook()
    if sharedAddonsMenuHookInstalled then return true end
    if not LibHarvensAddonSettings
        or type(LibHarvensAddonSettings.CreateAddonSettingsPanel) ~= "function"
        or type(ZO_PostHook) ~= "function" then return false end

    ZO_PostHook(LibHarvensAddonSettings, "CreateAddonSettingsPanel", function()
        GamepadOptions.EnsureMainMenuEntry(false)
    end)
    sharedAddonsMenuHookInstalled = true
    GamepadOptions.EnsureMainMenuEntry(false)
    return true
end

function GamepadOptions.InstallMainMenuWatcher()
    if mainMenuWatcherInstalled then return true end
    if not MAIN_MENU_GAMEPAD_SCENE or not MAIN_MENU_GAMEPAD_SCENE.RegisterCallback
        or type(zo_callLater) ~= "function" then return false end

    MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState ~= SCENE_SHOWING and newState ~= "showing" then return end
        zo_callLater(function() GamepadOptions.EnsureMainMenuEntry(true) end, 0)
    end)
    mainMenuWatcherInstalled = true
    if MAIN_MENU_GAMEPAD_SCENE.IsShowing and MAIN_MENU_GAMEPAD_SCENE:IsShowing() then
        zo_callLater(function() GamepadOptions.EnsureMainMenuEntry(true) end, 0)
    end
    return true
end

function GamepadOptions.InstallSubpanelBackOverride()
    if backOverrideInstalled or not SCENE_MANAGER then return end
    local panelScene = SCENE_MANAGER:GetScene("gamepad_options_panel")
    if not panelScene then return end
    panelScene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING or newState == "showing" then
            if GAMEPAD_OPTIONS and GamepadOptions.IsSubpanel(GAMEPAD_OPTIONS.currentCategory) then
                GamepadOptions.ReplaceSubpanelBackKeybind()
            end
        elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN or newState == "hiding" or newState == "hidden" then
            SetFeaturePreview(nil)
            if GAMEPAD_OPTIONS then GAMEPAD_OPTIONS:RevertBackKeybind() end
            if newState == SCENE_HIDDEN or newState == "hidden" then
                GamepadOptions.ConfirmQueuedLanguageChange()
            end
        end
    end)
    backOverrideInstalled = true
end

function GamepadOptions.Initialize()
    GamepadOptions.InstallSubpanelBackOverride()
    local attempts = 0
    local function TryRegister()
        local panelsReady = GamepadOptions.RegisterPanels()
        GamepadOptions.InstallSharedAddonsMenuHook()
        GamepadOptions.EnsureMainMenuEntry(false)
        local mainMenuWatcherReady = GamepadOptions.InstallMainMenuWatcher()
        if panelsReady and mainMenuWatcherReady then return end
        attempts = attempts + 1
        if attempts < 10 then zo_callLater(TryRegister, 1000) end
    end
    TryRegister()
end

GamepadOptions.parentSelectionByChildPanel = {}
