-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- GUI module for GuildStoreWatch add-on
-----------------------------------------------------------

GuildStoreWatchGui = GuildStoreWatchGui or {}
local GSWGui = GuildStoreWatchGui
local GSWGuiControls = GuildStoreWatchGuiControls

GSWGui.PANE_FILTERS = 1
GSWGui.PANE_RESULTS = 2
GSWGui.PROVINCE_DIALOG_NAME = "GSW_PROVINCE_DIALOG"
GSWGui.ALLIANCE_DIALOG_NAME = "GSW_ALLIANCE_DIALOG"
GSWGui.ZONE_DIALOG_NAME = "GSW_ZONE_DIALOG"
GSWGui.SIGN_DIALOG_NAME = "GSW_SIGN_DIALOG"
GSWGui.TRADER_DIALOG_NAME = "GSW_TRADER_DIALOG"
GSWGui.SEARCH_DIALOG_NAME = "GSW_SEARCH_FILTER_DIALOG"
GSWGui.DELETE_SELECTED_ROW_DIALOG_NAME = "GSW_DELETE_SELECTED_ROW_DIALOG"
GSWGui.DELETE_SELECTED_ITEM_DIALOG_NAME = "GSW_DELETE_SELECTED_ITEM_DIALOG"
GSWGui.CLEAR_CURRENT_VIEW_DIALOG_NAME = "GSW_CLEAR_CURRENT_VIEW_DIALOG"
GSWGui.CLEAR_ALL_DIALOG_NAME = "GSW_CLEAR_ALL_DIALOG"

GSWGui.sv = {
    showCheapestItemsOnly = true,
    showUncollectedItemsOnly = false,
    enablePageRotation = true,
    deleteOnConfirmationOnly = true,
    deleteWholeItem = false,
    clearOnConfirmationOnly = true,
    orderedByName = false,

    selectedProvince = "All",
    selectedAlliance = "All",
    selectedZone = "All",
    selectedSign = "All",
    selectedTrader = "All",
}

GSWGui.state = {
    guiRegistered = false,
    dialogsRegistered = false,
    menuEntryAdded = false,

    menuSceneName = "gswMainScene",
    menuPane = nil,

    menuShowExtraItemData = false,

    menuTopLevel = nil,
    filterList = nil,
    resultsList = nil,
}

GSWGui.RC = {
    GetStats = function() return "All", 0, 0, 0, 0, 1, 1 end,
    ClearWholeState = function() end,
    DeleteSelectedRow = function(selectedRow) end,
    DeleteCurrentView = function() end,
    CalculateVisibleRows = function() end,
    GetSelectedRow = function() return nil end,
    RecreateResult = function(selectedRow) return {} end,
    RecheckUncollectedItems = function() end,
    GetProvinces = function() return {} end,
    GetAlliances = function() return {} end,
    GetZones = function() return {} end,
    GetSigns = function() return {} end,
    GetTraders = function() return {} end,
    InvalidateAllTraders = function() end,

    state = {
        searchFilter = "",
        matchingPage = 1,
        matchingTotalPages = 1,
        matchingSelectedRow = nil,
        matchingPageRows = {},
    },

    callbacks = {
        RefreshFull = function() end,
    },
}

function GSWGui.Initialize(sv, ResultsController)
    if GSWGui.guiRegistered then return end

    GSWGui.sv = sv
    GSWGui.RC = ResultsController

    GSWGui.EnsureSavedVariables()
    GSWGui.EnsureState()
    GSWGui.RegisterDialogs()
    GSWGui.CreateLists()
    GSWGui.CreateScene()

    GSWGui.guiRegistered = true
end

function GSWGui.EnsureSavedVariables()
    if type(GSWGui.sv.showCheapestItemsOnly) ~= "boolean" then GSWGui.sv.showCheapestItemsOnly = true end
    if type(GSWGui.sv.showUncollectedItemsOnly) ~= "boolean" then GSWGui.sv.showUncollectedItemsOnly = false end
    if type(GSWGui.sv.enablePageRotation) ~= "boolean" then GSWGui.sv.enablePageRotation = true end
    if type(GSWGui.sv.deleteOnConfirmationOnly) ~= "boolean" then GSWGui.sv.deleteOnConfirmationOnly = true end
    if type(GSWGui.sv.deleteWholeItem) ~= "boolean" then GSWGui.sv.deleteWholeItem = false end
    if type(GSWGui.sv.clearOnConfirmationOnly) ~= "boolean" then GSWGui.sv.clearOnConfirmationOnly = true end
    if type(GSWGui.sv.orderedByName) ~= "boolean" then GSWGui.sv.orderedByName = false end
    if type(GSWGui.sv.selectedProvince) ~= "string" then GSWGui.sv.selectedProvince = "All" end
    if type(GSWGui.sv.selectedAlliance) ~= "string" then GSWGui.sv.selectedAlliance = "All" end
    if type(GSWGui.sv.selectedZone) ~= "string" then GSWGui.sv.selectedZone = "All" end
    if type(GSWGui.sv.selectedSign) ~= "string" then GSWGui.sv.selectedSign = "All" end
    if type(GSWGui.sv.selectedTrader) ~= "string" then GSWGui.sv.selectedTrader = "All" end
end

function GSWGui.EnsureState()
    GSWGui.state.guiRegistered = GSWGui.state.guiRegistered or false
    GSWGui.state.dialogsRegistered = GSWGui.state.dialogsRegistered or false
    GSWGui.state.menuEntryAdded = GSWGui.state.menuEntryAdded or false

    GSWGui.state.menuSceneName = GSWGui.state.menuSceneName or "gswMainScene"
    GSWGui.state.menuPane = GSWGui.state.menuPane or GSWGui.PANE_RESULTS

    GSWGui.state.menuShowExtraItemData = GSWGui.state.menuShowExtraItemData or false
end

function GSWGui.RefreshAll()
    if not GSWGui.guiRegistered or not SCENE_MANAGER:IsShowing(GSWGui.state.menuSceneName) then return end

    GSWGui.RC.CalculateVisibleRows()
    local viewMode, matching, stored, matchingGold, storedGold, page, totalPages = GSWGui.RC.GetStats()

    GSWGuiControls.UpdateHeader(viewMode, matching, stored, matchingGold, storedGold, page, totalPages)
    GSWGui.RefreshFilterList()
    GSWGui.RefreshResultsList()
    GSWGuiControls.SetPaneVisuals(GSWGui.state.menuPane)
    GSWGui.RefreshKeybindings()
end



----------------
-- Keybindings
----------------

GSWGui.menuKeybindStripDescriptor = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = function()
            return (GSWGui.state.menuPane == GSWGui.PANE_FILTERS) and "Results Pane" or "Filters Pane"
        end,
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        sound = SOUNDS.GAMEPAD_MENU_BACK,
        callback = function()
            GSWGui.MovePane(-1)
        end,
    },
    {
        name = function()
            return (GSWGui.state.menuPane == GSWGui.PANE_FILTERS) and "Results Pane" or "Filters Pane"
        end,
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        sound = SOUNDS.GAMEPAD_MENU_FORWARD,
        callback = function()
            GSWGui.MovePane(1)
        end,
    },
    {
        name = function()
            return (GSWGui.sv.enablePageRotation and GSWGui.RC.state.matchingPage == 1) and "Last Page" or "Prev Page"
        end,
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        sound = SOUNDS.GAMEPAD_PAGE_BACK,
        callback = function()
            if GSWGui.RC.state.matchingPage > 1 then
                GSWGui.RC.state.matchingPage = GSWGui.RC.state.matchingPage - 1
                GSWGui.RC.state.matchingSelectedRow = nil
                GSWGui.RefreshAll()
            elseif GSWGui.sv.enablePageRotation and GSWGui.RC.state.matchingPage == 1 then
                GSWGui.RC.state.matchingPage = GSWGui.RC.state.matchingTotalPages
                GSWGui.RC.state.matchingSelectedRow = nil
                GSWGui.RefreshAll()
            end
        end,
        enabled = function()
            return GSWGui.RC.state.matchingPage > 1 or GSWGui.sv.enablePageRotation
        end,
    },
    {
        name = function()
            return (GSWGui.sv.enablePageRotation and GSWGui.RC.state.matchingPage == GSWGui.RC.state.matchingTotalPages) and "First Page" or "Next Page"
        end,
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        sound = SOUNDS.GAMEPAD_PAGE_FORWARD,
        callback = function()
            if GSWGui.RC.state.matchingPage < GSWGui.RC.state.matchingTotalPages then
                GSWGui.RC.state.matchingPage = GSWGui.RC.state.matchingPage + 1
                GSWGui.RC.state.matchingSelectedRow = nil
                GSWGui.RefreshAll()
            elseif GSWGui.sv.enablePageRotation and GSWGui.RC.state.matchingPage == GSWGui.RC.state.matchingTotalPages then
                GSWGui.RC.state.matchingPage = 1
                GSWGui.RC.state.matchingSelectedRow = nil
                GSWGui.RefreshAll()
            end
        end,
        enabled = function()
            return GSWGui.RC.state.matchingPage < GSWGui.RC.state.matchingTotalPages or GSWGui.sv.enablePageRotation
        end,
    },
    {
        name = function()
            if GSWGui.state.menuPane == GSWGui.PANE_FILTERS then
                return "Activate"
            elseif GSWGui.state.menuPane == GSWGui.PANE_RESULTS and GSWGui.RC.GetSelectedRow() ~= nil then
                return GSWGui.state.menuShowExtraItemData and "Less Info" or "More Info"
            end
            return nil
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        visible = function()
            if GSWGui.state.menuPane == GSWGui.PANE_FILTERS then
                return true
            end
            return GSWGui.state.menuPane == GSWGui.PANE_RESULTS and GSWGui.RC.GetSelectedRow() ~= nil
        end,
        callback = function()
            if GSWGui.state.menuPane == GSWGui.PANE_FILTERS then
                GSWGui.ActivateCurrentFilter()
            elseif GSWGui.state.menuPane == GSWGui.PANE_RESULTS and GSWGui.RC.GetSelectedRow() ~= nil then
                GSWGui.ToggleExtraItemDataDetail()
            end
        end,
    },
    {
        name = function()
            if GSWGui.sv.deleteWholeItem then
                return "Delete Whole Item"
            end
            return "Delete Row"
        end,
        keybind = "UI_SHORTCUT_TERTIARY",
        visible = function()
            return GSWGui.state.menuPane == GSWGui.PANE_RESULTS and GSWGui.RC.GetSelectedRow() ~= nil
        end,
        callback = function()
            GSWGui.RequestDeleteSelectedRow()
        end,
    },
    {
        name = "Clear View",
        keybind = "UI_SHORTCUT_SECONDARY",
        visible = function()
            return true
        end,
        callback = function()
            GSWGui.RequestClearCurrentMenuViewRows()
        end,
    },
    {
        name = GetString(SI_GAMEPAD_BACK_OPTION),
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = function()
            SCENE_MANAGER:HideCurrentScene()
        end,
    },
}

function GSWGui.AddKeybindings()
    if KEYBIND_STRIP and GSWGui.menuKeybindStripDescriptor then
        KEYBIND_STRIP:AddKeybindButtonGroup(GSWGui.menuKeybindStripDescriptor)
    end
end

function GSWGui.RefreshKeybindings()
    if KEYBIND_STRIP and GSWGui.menuKeybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(GSWGui.menuKeybindStripDescriptor)
    end
end

function GSWGui.RemoveKeybindings()
    if KEYBIND_STRIP and GSWGui.menuKeybindStripDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(GSWGui.menuKeybindStripDescriptor)
    end
end



-----------------
-- Filters Menu
-----------------

function GSWGui.GetFilters()
    local searchText = SPFLibUtils.SafeText(GSWGui.RC.state.searchFilter)
    if searchText == "" then searchText = "All" end

    return {
        {
            text = string.format("Province: %s", GSWGui.sv.selectedProvince),
            callback = function()
                GSWGui.OpenProvinceDialog()
            end,
        },
        {
            text = string.format("Alliance: %s", GSWGui.sv.selectedAlliance),
            callback = function()
                GSWGui.OpenAllianceDialog()
            end,
        },
        {
            text = string.format("Zone: %s", GSWGui.sv.selectedZone),
            callback = function()
                GSWGui.OpenZoneDialog()
            end,
        },
        {
            text = string.format("Sign: %s", GSWGui.sv.selectedSign),
            callback = function()
                GSWGui.OpenSignDialog()
            end,
        },
        {
            text = string.format("Trader: %s", GSWGui.sv.selectedTrader),
            callback = function()
                GSWGui.OpenTraderDialog()
            end,
        },
        {
            text = string.format("Search Filter: %s", searchText),
            callback = function()
                GSWGui.OpenSearchFilterDialog()
            end,
        },
        {
            text = string.format("View Mode: %s", GSWGui.sv.showCheapestItemsOnly and "Cheapest Only" or "All Rows"),
            callback = function()
                GSWGui.sv.showCheapestItemsOnly = not GSWGui.sv.showCheapestItemsOnly
                GSWGui.RC.state.matchingPage = 1
                GSWGui.PlayClickSound()
                GSWGui.RC.callbacks.RefreshFull()
            end,
        },
        {
            text = string.format("Collected Items: %s", GSWGui.sv.showUncollectedItemsOnly and "Hide" or "Show"),
            callback = function()
                GSWGui.sv.showUncollectedItemsOnly = not GSWGui.sv.showUncollectedItemsOnly
                GSWGui.RC.state.matchingPage = 1
                GSWGui.PlayClickSound()
                GSWGui.RC.callbacks.RefreshFull()
            end,
        },
        {
            text = string.format("Ordered by name: %s", GSWGui.sv.orderedByName == true and "Yes" or "No"),
            callback = function()
                GSWGui.sv.orderedByName = not GSWGui.sv.orderedByName
                GSWGui.RC.state.matchingPage = 1
                GSWGui.PlayClickSound()
                GSWGui.RC.callbacks.RefreshFull()
            end,
        },
        {
            text = string.format("Rows Per Page: %d", GSWGui.RC.state.matchingPageSize),
            callback = function()
                local newSize = GSWGui.RC.state.matchingPageSize == 50 and 100 or 50
                GSWGui.RC.state.matchingPageSize = newSize
                GSWGui.RC.state.matchingPage = 1
                GSWGui.PlayClickSound()
                GSWGui.RefreshAll()
            end,
        },
        {
            text = string.format("Delete Whole Item: %s", GSWGui.sv.deleteWholeItem == true and "Yes" or "No"),
            callback = function()
                GSWGui.sv.deleteWholeItem = not GSWGui.sv.deleteWholeItem
                GSWGui.PlayClickSound()
                GSWGui.RefreshAll()
            end,
        },
        --[[ {
            text = string.format("Previous Page (%d/%d)", page, totalPages),
            callback = function()
                GSWGui.PlayClickSound()
                if GSWGui.RC.state.matchingPage > 1 then
                    GSWGui.RC.state.matchingPage = GSWGui.RC.state.matchingPage - 1
                    GSWGui.RC.state.matchingSelectedRow = nil
                    GSWGui.RefreshAll()
                end
            end,
        },
        {
            text = string.format("Next Page (%d/%d)", page, totalPages),
            callback = function()
                GSWGui.PlayClickSound()
                if GSWGui.RC.state.matchingPage < totalPages then
                    GSWGui.RC.state.matchingPage = GSWGui.RC.state.matchingPage + 1
                    GSWGui.RC.state.matchingSelectedRow = nil
                    GSWGui.RefreshAll()
                end
            end,
        }, ]]
        {
            text = "Reset traders status",
            callback = function()
                GSWGui.PlayClickSound()
                GSWGui.RC.InvalidateAllTraders()
            end,
        },
        {
            text = "Recheck Uncollected Items",
            callback = function()
                GSWGui.PlayClickSound()
                GSWGui.RC.RecheckUncollectedItems()
            end,
        },
        {
            text = "Clear Current View",
            callback = function()
                GSWGui.RequestClearCurrentMenuViewRows()
            end,
        },
        {
            text = "Clear All",
            callback = function()
                GSWGui.RequestClearAllRows()
            end,
        },
    }
end



------------
-- Changes
------------

function GSWGui.ToggleExtraItemDataDetail()
    if GSWGui.state.menuPane ~= GSWGui.PANE_RESULTS then
        return
    end

    local selectedRow = GSWGui.RC.GetSelectedRow()
    if selectedRow == nil then
        return
    end

    GSWGui.state.menuShowExtraItemData = not GSWGui.state.menuShowExtraItemData
    GSWGuiControls.RefreshDetailPanel(GSWGui.RC.RecreateResult(selectedRow), GSWGui.state.menuShowExtraItemData)
    GSWGui.RefreshKeybindings()
end

function GSWGui.ActivateCurrentFilter()
    if not GSWGui.state.filterList then return end
    local selected = GSWGui.state.filterList:GetTargetData()
    if selected and selected.filterCallback then
        selected.filterCallback()
    end
end

function GSWGui.SetActivePane(pane)
    if pane ~= GSWGui.PANE_FILTERS and pane ~= GSWGui.PANE_RESULTS then
        pane = GSWGui.PANE_RESULTS
    end
    GSWGui.state.menuPane = pane

    if GSWGui.state.filterList and GSWGui.state.resultsList then
        if pane == GSWGui.PANE_FILTERS then
            if GSWGui.state.resultsList.Deactivate then GSWGui.state.resultsList:Deactivate() end
            if GSWGui.state.filterList.Activate then GSWGui.state.filterList:Activate() end
        else
            if GSWGui.state.filterList.Deactivate then GSWGui.state.filterList:Deactivate() end
            if GSWGui.state.resultsList.Activate then GSWGui.state.resultsList:Activate() end
        end
    end

    GSWGuiControls.SetPaneVisuals(pane == GSWGui.PANE_FILTERS, pane == GSWGui.PANE_RESULTS)
    GSWGui.RefreshKeybindings()
end

function GSWGui.MovePane(delta)
    local pane = GSWGui.state.menuPane or GSWGui.PANE_RESULTS
    pane = pane + delta
    if pane < GSWGui.PANE_FILTERS then pane = GSWGui.PANE_RESULTS end
    if pane > GSWGui.PANE_RESULTS then pane = GSWGui.PANE_FILTERS end
    GSWGui.SetActivePane(pane)
end

function GSWGui.PlayClickSound()
	if PlaySound == nil then return end
	if SOUNDS ~= nil then
		if SOUNDS.DEFAULT_CLICK ~= nil then
			PlaySound(SOUNDS.DEFAULT_CLICK)
			return
		end
	end
end



-------------
-- Controls
-------------

function GSWGui.CreateLists()
    local leftPaneList = GSWGuiControls.GetLeftPaneList()
    if not leftPaneList then return end
    GSWGui.state.filterList = ZO_GamepadVerticalItemParametricScrollList:New(leftPaneList)
    GSWGui.state.filterList:AddDataTemplate("GSWFilterRowTemplate", GSWGuiControls.FilterEntrySetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    GSWGui.state.filterList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        GSWGui.RefreshKeybindings()
    end)

    local centerPaneList = GSWGuiControls.GetCenterPaneList()
    if not centerPaneList then return end
    GSWGui.state.resultsList = ZO_GamepadVerticalItemParametricScrollList:New(centerPaneList)
    GSWGui.state.resultsList:AddDataTemplate("GSWResultRowTemplate", GSWGuiControls.ResultEntrySetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    GSWGui.state.resultsList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if selectedData and selectedData.row then
            GSWGui.RC.state.matchingSelectedRow = selectedData.row
            GSWGuiControls.RefreshDetailPanel(GSWGui.RC.RecreateResult(selectedData.row), GSWGui.state.menuShowExtraItemData)
        else
            GSWGui.RC.state.matchingSelectedRow = nil
            GSWGuiControls.RefreshDetailPanel(nil, GSWGui.state.menuShowExtraItemData)
        end
        GSWGui.RefreshKeybindings()
    end)
end

function GSWGui.CreateScene()
    local root = GSWGuiControls.GetRoot()
    if not root then return end

    local scene = SCENE_MANAGER:GetScene(GSWGui.state.menuSceneName)
    if not scene then
        scene = ZO_Scene:New(GSWGui.state.menuSceneName, SCENE_MANAGER)
    end

    local fragment = ZO_FadeSceneFragment:New(root)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(fragment)

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            GSWGui.RefreshAll()
            GSWGui.AddKeybindings()
            GSWGui.SetActivePane(GSWGui.state.menuPane or GSWGui.PANE_RESULTS)
        elseif newState == SCENE_HIDDEN then
            if GSWGui.state.filterList and GSWGui.state.filterList.Deactivate then GSWGui.state.filterList:Deactivate() end
            if GSWGui.state.resultsList and GSWGui.state.resultsList.Deactivate then GSWGui.state.resultsList:Deactivate() end
            GSWGui.RemoveKeybindings()
        end
    end)

    GSWGui.state.menuScene = scene
    GSWGui.state.menuTopLevel = root
end

function GSWGui.RefreshFilterList()
    if not GSWGui.state.filterList then return end
    GSWGui.state.filterList:Clear()

    local filters = GSWGui.GetFilters()

    for _, filter in ipairs(filters) do
        local entry = ZO_GamepadEntryData:New(filter.text)
        entry.filterCallback = filter.callback
        GSWGui.state.filterList:AddEntry("GSWFilterRowTemplate", entry)
    end

    GSWGui.state.filterList:Commit()
end

function GSWGui.RefreshResultsList()
    if not GSWGui.state.resultsList then return end
    GSWGui.state.resultsList:Clear()

    for _, row in ipairs(GSWGui.RC.state.matchingPageRows) do
        local result = GSWGui.RC.RecreateResult(row)

        local zone = SPFLibUtils.SafeText(result.traderZone)
        local trader = SPFLibUtils.SafeText(result.traderName)
        local guild = SPFLibUtils.SafeText(result.guildName)
        local priceText = SPFLibUtils.FormatGoldAmount(result.itemData.purchasePricePerUnit or result.itemData.purchasePrice or 0)
        local traderGuildText = trader
        if guild ~= "" then
            traderGuildText = string.format("%s (%s)", trader, guild)
        end

        local entry = ZO_GamepadEntryData:New("")
        entry.mainText = result.itemData.itemLink
        entry.itemData = result.itemData
        entry.priceText = priceText
        entry.zoneText = zone
        entry.traderGuildText = traderGuildText
        entry.row = row
        entry.showLearnIcon = result.isUncollected

        GSWGui.state.resultsList:AddEntry("GSWResultRowTemplate", entry)
    end

    GSWGui.state.resultsList:Commit()

    local row = GSWGui.RC.GetSelectedRow()
    if not row and GSWGui.RC.state.matchingPageRows[1] then
        row = GSWGui.RC.state.matchingPageRows[1]
        
    end
    GSWGui.RC.state.matchingSelectedRow = row
    GSWGuiControls.RefreshDetailPanel(GSWGui.RC.RecreateResult(row), GSWGui.state.menuShowExtraItemData)
end



------------
-- Dialogs
------------

local function ReleaseDialog(dialogName)
    if ZO_Dialogs_ReleaseDialogOnButtonPress then
        ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
    end
end

local function SetupRequestEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
    if ZO_SharedGamepadEntry_OnSetup then
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    end
end

function GSWGui.RegisterSearchDialog()
    -- local parametricDialog = ZO_GenericGamepadDialog_GetControl and ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC) or nil
    ZO_Dialogs_RegisterCustomDialog(GSWGui.SEARCH_DIALOG_NAME,
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title =
        {
            text = "Search Filter",
        },
        setup = function(dialog)
            dialog.info.parametricList =
            {
                {
                    template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                    templateData = {
                        nameField = true,
                        textChangedCallback = function(control)
                            if dialog.data then
                                dialog.data.filterText = control:GetText()
                            end
                        end,
                        setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                            control.highlight:SetHidden(not selected)
                            control.editBoxControl.textChangedCallback = data.textChangedCallback
                            if control.editBoxControl.SetMaxInputChars then
                                control.editBoxControl:SetMaxInputChars(100)
                            end
                            if control.editBoxControl.SetDefaultText then
                                control.editBoxControl:SetDefaultText("All")
                            end
                            control.editBoxControl:SetText((dialog.data and dialog.data.filterText) or "")
                            data.control = control
                        end,
                        callback = function(dialogRef)
                            local targetData = dialogRef.entryList:GetTargetData()
                            if targetData and targetData.control and targetData.control.editBoxControl and targetData.control.editBoxControl.TakeFocus then
                                targetData.control.editBoxControl:TakeFocus()
                            end
                        end,
                        narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = "Apply Filter",
                        setup = SetupRequestEntry,
                        callback = function(dialogRef)
                            GSWGui.RC.state.searchFilter = SPFLibUtils.SafeText(dialogRef.data and dialogRef.data.filterText)
                            GSWGui.RC.state.matchingPage = 1
                            GSWGui.RC.state.matchingSelectedRow = nil
                            GSWGui.RefreshAll()
                            ReleaseDialog(GSWGui.SEARCH_DIALOG_NAME)
                        end,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = "Clear Filter",
                        setup = SetupRequestEntry,
                        callback = function(dialogRef)
                            GSWGui.RC.state.searchFilter = ""
                            GSWGui.RC.state.matchingPage = 1
                            GSWGui.RC.state.matchingSelectedRow = nil
                            GSWGui.RefreshAll()
                            ReleaseDialog(GSWGui.SEARCH_DIALOG_NAME)
                        end,
                    },
                },
            }
            dialog:setupFunc()
        end,
        blockDialogReleaseOnPress = true,
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local targetData = dialog.entryList:GetTargetData()
                    if targetData and targetData.callback then
                        targetData.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function()
                    ReleaseDialog(GSWGui.SEARCH_DIALOG_NAME)
                end,
            },
        },
    })
end

function GSWGui.RegisterConfirmationDialog(name, title, description)
    ZO_Dialogs_RegisterCustomDialog(name,
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title =
        {
            text = title,
        },
        mainText =
        {
            text = description,
        },
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_DIALOG_CONFIRM),
                callback = function(dialog)
                    if dialog.data and dialog.data.onConfirm then
                        dialog.data.onConfirm()
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
        },
    })
end

function GSWGui.RegisterSingleSelectDialog(dialogName)
    ZO_Dialogs_RegisterCustomDialog(dialogName,
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title =
        {
            text = "",
        },
        setup = function(dialog)
            local data = dialog.data or {}
            local selectedValue = data.selectedValue
            local selectedIndex = 1
            local options = data.options or {}

            if dialog.info and dialog.info.title then
                dialog.info.title.text = data.title or "Select"
            end

            dialog.info.parametricList = {}

            for i, option in ipairs(options) do
                local isCurrent = (option.value == selectedValue)

                if isCurrent then
                    selectedIndex = i
                end

                local selectedColor = nil
                local unselectedColor = nil
                if option.color then
                    selectedColor = option.color
                    unselectedColor = option.color:GetDim()
                end

                table.insert(dialog.info.parametricList,
                {
                    template = "ZO_GamepadMenuEntryTemplate",
                    templateData =
                    {
                        text = option.name,
                        baseText = option.name,
                        value = option.value,
                        selectedNameColor = selectedColor,
                        unselectedNameColor = unselectedColor,
                        isCurrent = isCurrent,
                        setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                            ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)

                            local label = control.label or (control.GetNamedChild and control:GetNamedChild("Label"))
                            if not label then return end

                            local text = data.baseText or data.text or ""

                            if data.isCurrent then
                                text = zo_iconTextFormat("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds", 24, 24, text)
                            end

                            label:SetText(text)
                        end,
                        callback = function(dialogRef)
                            if data.onSelect then
                                data.onSelect(option, dialogRef)
                            end
                            ReleaseDialog(dialogName)
                        end,
                    },
                })
            end

            dialog:setupFunc()

            if dialog.entryList then
                if dialog.entryList.SetTargetIndex then
                    dialog.entryList:SetTargetIndex(selectedIndex)
                elseif dialog.entryList.SetSelectedIndexWithoutAnimation then
                    dialog.entryList:SetSelectedIndexWithoutAnimation(selectedIndex)
                end
            end
        end,
        blockDialogReleaseOnPress = true,
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local targetData = dialog.entryList:GetTargetData()
                    if targetData and targetData.callback then
                        targetData.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function()
                    ReleaseDialog(dialogName)
                end,
            },
        },
    })
end

function GSWGui.RegisterDialogs()
    if GSWGui.state.dialogsRegistered then return end
    GSWGui.state.dialogsRegistered = true

    GSWGui.RegisterSearchDialog()
    GSWGui.RegisterSingleSelectDialog(GSWGui.PROVINCE_DIALOG_NAME)
    GSWGui.RegisterSingleSelectDialog(GSWGui.ALLIANCE_DIALOG_NAME)
    GSWGui.RegisterSingleSelectDialog(GSWGui.ZONE_DIALOG_NAME)
    GSWGui.RegisterSingleSelectDialog(GSWGui.SIGN_DIALOG_NAME)
    GSWGui.RegisterSingleSelectDialog(GSWGui.TRADER_DIALOG_NAME)
    GSWGui.RegisterConfirmationDialog(GSWGui.DELETE_SELECTED_ROW_DIALOG_NAME, "Delete Row", "Remove currently selected row?")
    GSWGui.RegisterConfirmationDialog(GSWGui.DELETE_SELECTED_ITEM_DIALOG_NAME, "Delete Whole Item", "Remove currently selected item?")
    GSWGui.RegisterConfirmationDialog(GSWGui.CLEAR_CURRENT_VIEW_DIALOG_NAME, "Clear Current View", "Remove all currently visible rows?")
    GSWGui.RegisterConfirmationDialog(GSWGui.CLEAR_ALL_DIALOG_NAME, "Clear All", "Remove all saved rows?")
end

function GSWGui.GetColoredOptions(values)
    local options = {
        { name = "All", value = "All" },
    }
    for _, value in ipairs(values) do
        options[#options + 1] = { name = value.name, value = value.id, color = value.color }
    end
    return options
end

function GSWGui.GetSimpleOptions(values)
    local options = {
        { name = "All", value = "All" },
    }
    for _, value in ipairs(values) do
        options[#options + 1] = { name = value, value = value }
    end
    return options
end

function GSWGui.OpenProvinceDialog()
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.PROVINCE_DIALOG_NAME, {
        title = "Province",
        selectedValue = GSWGui.sv.selectedProvince,
        options = GSWGui.GetColoredOptions(GSWGui.RC.GetProvinces()),
        onSelect = function(option)
            GSWGui.sv.selectedProvince = option.value
            GSWGui.sv.selectedZone = "All"
            GSWGui.sv.selectedTrader = "All"
            GSWGui.RC.state.matchingPage = 1
            GSWGui.RC.state.matchingSelectedRow = nil
            GSWGui.RefreshAll()
        end,
    })
end

function GSWGui.OpenAllianceDialog()
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.ALLIANCE_DIALOG_NAME, {
        title = "Alliance",
        selectedValue = GSWGui.sv.selectedAlliance,
        options = GSWGui.GetColoredOptions(GSWGui.RC.GetAlliances()),
        onSelect = function(option)
            GSWGui.sv.selectedAlliance = option.value
            GSWGui.sv.selectedZone = "All"
            GSWGui.sv.selectedTrader = "All"
            GSWGui.RC.state.matchingPage = 1
            GSWGui.RC.state.matchingSelectedRow = nil
            GSWGui.RefreshAll()
        end,
    })
end

function GSWGui.OpenZoneDialog()
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.ZONE_DIALOG_NAME, {
        title = "Zone",
        selectedValue = GSWGui.sv.selectedZone,
        options = GSWGui.GetColoredOptions(GSWGui.RC.GetZones()),
        onSelect = function(option)
            GSWGui.sv.selectedZone = option.value
            GSWGui.sv.selectedTrader = "All"
            GSWGui.RC.state.matchingPage = 1
            GSWGui.RC.state.matchingSelectedRow = nil
            GSWGui.RefreshAll()
        end,
    })
end

function GSWGui.OpenSignDialog()
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.SIGN_DIALOG_NAME, {
        title = "Sign",
        selectedValue = GSWGui.sv.selectedSign,
        options = GSWGui.GetColoredOptions(GSWGui.RC.GetSigns()),
        onSelect = function(option)
            GSWGui.sv.selectedSign = option.value
            GSWGui.sv.selectedTrader = "All"
            GSWGui.RC.state.matchingPage = 1
            GSWGui.RC.state.matchingSelectedRow = nil
            GSWGui.RefreshAll()
        end,
    })
end

function GSWGui.OpenTraderDialog()
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.TRADER_DIALOG_NAME, {
        title = "Inventory",
        selectedValue = GSWGui.sv.selectedTrader,
        options = GSWGui.GetColoredOptions(GSWGui.RC.GetTraders()),
        onSelect = function(option)
            GSWGui.sv.selectedTrader = option.value
            GSWGui.RC.state.matchingPage = 1
            GSWGui.RC.state.matchingSelectedRow = nil
            GSWGui.RefreshAll()
        end,
    })
end

function GSWGui.OpenSearchFilterDialog()
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.SEARCH_DIALOG_NAME, { filterText = SPFLibUtils.SafeText(GSWGui.RC.state.searchFilter) })
end

function GSWGui.ShowDeleteSelectedItemConfirmation(onConfirm)
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.DELETE_SELECTED_ITEM_DIALOG_NAME, { onConfirm = onConfirm })
end

function GSWGui.ShowDeleteSelectedRowConfirmation(onConfirm)
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.DELETE_SELECTED_ROW_DIALOG_NAME, { onConfirm = onConfirm })
end

function GSWGui.ShowClearCurrentViewConfirmation(onConfirm)
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.CLEAR_CURRENT_VIEW_DIALOG_NAME, { onConfirm = onConfirm })
end

function GSWGui.ShowClearAllConfirmation(onConfirm)
    GSWGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(GSWGui.CLEAR_ALL_DIALOG_NAME, { onConfirm = onConfirm })
end

function GSWGui.GetSelectedRowFromUI()
    -- TODO: check resultsList
    if GSWGui.resultsList and GSWGui.resultsList.GetTargetData then
        local selected = GSWGui.resultsList:GetTargetData()
        if selected and selected.row then
            return selected.row
        end
    end
    return nil
end

function GSWGui.RequestClearAllRows()
    if GSWGui.sv.clearOnConfirmationOnly then
        GSWGui.ShowClearAllConfirmation(function()
            GSWGui.RC.ClearWholeState()
        end)
        return
    end
    GSWGui.RC.ClearWholeState()
end

function GSWGui.RequestDeleteSelectedRow()
    if GSWGui.sv.deleteOnConfirmationOnly then
        if GSWGui.sv.deleteWholeItem then
            GSWGui.ShowDeleteSelectedItemConfirmation(function()
                GSWGui.RC.DeleteSelectedRow(GSWGui.GetSelectedRowFromUI())
            end)
            return
        else
            GSWGui.ShowDeleteSelectedRowConfirmation(function()
                GSWGui.RC.DeleteSelectedRow(GSWGui.GetSelectedRowFromUI())
            end)
            return
        end
    end
    GSWGui.RC.DeleteSelectedRow(GSWGui.GetSelectedRowFromUI())
end

function GSWGui.RequestClearCurrentMenuViewRows()
    if GSWGui.sv.clearOnConfirmationOnly then
        GSWGui.ShowClearCurrentViewConfirmation(function()
            GSWGui.RC.DeleteCurrentView()
        end)
        return
    end
    GSWGui.RC.DeleteCurrentView()
end



--------------------
-- Main Menu Entry - backup
--------------------

function GSWGui.CreateMainMenuEntry(data)
    local entry = ZO_GamepadEntryData:New("", data.icon, nil, nil, data.isNewCallback)
    if entry.SetIconTintOnSelection then entry:SetIconTintOnSelection(true) end
    if entry.SetIconDisabledTintOnSelection then entry:SetIconDisabledTintOnSelection(true) end
    if data.header and entry.SetHeader then entry:SetHeader(data.header) end
    entry.data = data
    entry.name = data.name
    entry.icon = data.icon
    entry.scene = data.scene
    entry.callback = data.callback
    entry.id = data.id
    return entry
end

function GSWGui.TryAddMainMenuEntryLater(attempt)
    attempt = (attempt or 0) + 1
    if GSWGui.state.menuEntryAdded then return end

    if MAIN_MENU_GAMEPAD and ZO_MENU_ENTRIES then
        GSWGui.AddMainMenuEntry(true)
        return
    end

    if attempt <= 20 then
        zo_callLater(function()
            GSWGui.TryAddMainMenuEntryLater(attempt)
        end, 500)
    else
        d("[GSW] DEBUG: Main menu not ready, failed to add menu entry.")
    end
end

function GSWGui.AddMainMenuEntry(skipRetry)
    if GSWGui.state.menuEntryAdded then return end

    if not MAIN_MENU_GAMEPAD or not ZO_MENU_ENTRIES then
        if not skipRetry then
            GSWGui.TryAddMainMenuEntryLater()
        end
        return
    end

    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        local sceneName = entry.scene or (entry.data and entry.data.scene)
        if sceneName == GSWGui.state.menuSceneName then
            GSWGui.state.menuEntryAdded = true
            return
        end
    end

    local entryData = {
        name = function() return "Guild Store Watch" end,
        icon = "EsoUI/Art/Icons/mapkey/mapkey_guildkiosk.dds",
        scene = GSWGui.state.menuSceneName,
        callback = function()
            SCENE_MANAGER:Show(GSWGui.state.menuSceneName)
        end,
    }

    local newEntry = GSWGui.CreateMainMenuEntry(entryData)
    local newId = 1
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry and entry.id and entry.id >= newId then
            newId = entry.id + 1
        end
    end
    newEntry.id = newId

    local insertIndex = nil
    for i, entry in ipairs(ZO_MENU_ENTRIES) do
        local entryId = entry and entry.id or nil
        local sceneName = nil
        local name = nil
        if entry and entry.data then
            sceneName = entry.data.scene
            if type(entry.data.name) == "function" then
                name = entry.data.name()
            else
                name = entry.data.name
            end
        else
            sceneName = entry and entry.scene
            if type(entry and entry.name) == "function" then
                name = entry.name()
            else
                name = entry and entry.name
            end
        end
        if entryId == ZO_MENU_MAIN_ENTRIES.ACTIVITY_FINDER
            or sceneName == "gamepadActivityFinder"
            or name == GetString(SI_MAIN_MENU_ACTIVITY_FINDER) then
            insertIndex = i
            break
        end
    end

    if insertIndex then
        table.insert(ZO_MENU_ENTRIES, insertIndex, newEntry)
    else
        table.insert(ZO_MENU_ENTRIES, newEntry)
    end

    GSWGui.state.menuEntryAdded = true

    if MAIN_MENU_GAMEPAD.RefreshMainList then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    elseif MAIN_MENU_GAMEPAD.RefreshLists then
        MAIN_MENU_GAMEPAD:RefreshLists()
    end
end

--[[ zo_callLater(function()
    -- TODO: try to call this without zo_callLater
    GSWGui.AddMainMenuEntry()
    d("GSW Initialized.")
end, 1000) ]]
