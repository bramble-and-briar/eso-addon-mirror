-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- GUI module for FurnishThemAll add-on
-----------------------------------------------------------

FurnishThemAllGui = FurnishThemAllGui or {}
local FTAGui = FurnishThemAllGui
local FTAGuiControls = FurnishThemAllGuiControls
local FTAData = FurnishThemAllData

FTAGui.PANE_FILTERS = 1
FTAGui.PANE_RESULTS = 2
FTAGui.SEARCH_DIALOG_NAME = "FTA_SEARCH_FILTER_DIALOG"
FTAGui.CATEGORY_DIALOG_NAME = "FTA_CATEGORY_DIALOG"
FTAGui.SUBCATEGORY_DIALOG_NAME = "FTA_SUBCATEGORY_DIALOG"
FTAGui.SOURCE_DIALOG_NAME = "FTA_SOURCE_DIALOG"
FTAGui.GROUP_DIALOG_NAME = "FTA_GROUP_DIALOG"
FTAGui.TAG_DIALOG_NAME = "FTA_TAG_DIALOG"
FTAGui.INVENTORY_DIALOG_NAME = "FTA_INVENTORY_DIALOG"

FTAGui.sv = {
    showUncollectedItemsOnly = false,
    enablePageRotation = true,
    showIcons = true,

    selectedCategory = "All",
    selectedSubcategory = "All",
    selectedSource = "All",
    selectedGroup = "All",
    selectedTag = "All",
    selectedInventory = "All",
}

FTAGui.state = {
    guiRegistered = false,
    dialogsRegistered = false,
    menuEntryAdded = false,

    menuSceneName = "ftaMainScene",
    menuPane = nil,

    menuShowExtraItemData = false,

    menuTopLevel = nil,
    filterList = nil,
    resultsList = nil,
    categoryDropdown = nil,
}

FTAGui.RC = {
    GetStats = function() return 0, 0, 0, 0, 1, 1, 0 end,
    CalculateVisibleRows = function() end,
    GetSelectedRow = function() return nil end,
    RecreateResult = function(selectedRow) return {} end,
    RecheckUncollectedItems = function() end,
    GetOrderedByLabel = function() return "" end,
    NextOrderedBy = function() end,
    GetSources = function() return {} end,
    GetGroups = function() return {} end,
    GetTags = function() return {} end,
    GetInventories = function() return {} end,
    Build = function(forced) end,

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

function FTAGui.Initialize(sv, ResultsController)
    if FTAGui.guiRegistered then return end

    FTAGui.sv = sv
    FTAGui.RC = ResultsController

    FTAGui.EnsureSavedVariables()
    FTAGui.EnsureState()
    FTAGui.RegisterDialogs()
    FTAGui.CreateLists()
    FTAGui.CreateScene()

    FTAGui.guiRegistered = true
end

function FTAGui.EnsureSavedVariables()
    if type(FTAGui.sv.showUncollectedItemsOnly) ~= "boolean" then FTAGui.sv.showUncollectedItemsOnly = false end
    if type(FTAGui.sv.enablePageRotation) ~= "boolean" then FTAGui.sv.enablePageRotation = true end
    if type(FTAGui.sv.showIcons) ~= "boolean" then FTAGui.sv.showIcons = true end
    if type(FTAGui.sv.selectedCategory) ~= "string" then FTAGui.sv.selectedCategory = "All" end
    if type(FTAGui.sv.selectedSubcategory) ~= "string" then FTAGui.sv.selectedSubcategory = "All" end
    if type(FTAGui.sv.selectedSource) ~= "string" then FTAGui.sv.selectedSource = "All" end
    if type(FTAGui.sv.selectedGroup) ~= "string" then FTAGui.sv.selectedGroup = "All" end
    if type(FTAGui.sv.selectedTag) ~= "string" then FTAGui.sv.selectedTag = "All" end
    if type(FTAGui.sv.selectedInventory) ~= "string" then FTAGui.sv.selectedInventory = "All" end
end

function FTAGui.EnsureState()
    FTAGui.state.guiRegistered = FTAGui.state.guiRegistered or false
    FTAGui.state.dialogsRegistered = FTAGui.state.dialogsRegistered or false
    FTAGui.state.menuEntryAdded = FTAGui.state.menuEntryAdded or false

    FTAGui.state.menuSceneName = FTAGui.state.menuSceneName or "ftaMainScene"
    FTAGui.state.menuPane = FTAGui.state.menuPane or FTAGui.PANE_RESULTS

    FTAGui.state.menuShowExtraItemData = FTAGui.state.menuShowExtraItemData or false
end

function FTAGui.RefreshAll()
    if not FTAGui.guiRegistered or not SCENE_MANAGER:IsShowing(FTAGui.state.menuSceneName) then return end

    FTAGui.RC.CalculateVisibleRows()
    local matching, total, collectedMatching, collectedTotal, page, totalPages, neededTradeBars = FTAGui.RC.GetStats()

    FTAGuiControls.UpdateHeader(matching, total, collectedMatching, collectedTotal, page, totalPages, neededTradeBars)
    FTAGui.RefreshFilterList()
    FTAGui.RefreshResultsList()
    FTAGuiControls.SetPaneVisuals(FTAGui.state.menuPane)
    FTAGui.RefreshKeybindings()
end



----------------
-- Keybindings
----------------

FTAGui.menuKeybindStripDescriptor = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = function()
            return (FTAGui.state.menuPane == FTAGui.PANE_FILTERS) and "Results Pane" or "Filters Pane"
        end,
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        sound = SOUNDS.GAMEPAD_MENU_BACK,
        callback = function()
            FTAGui.MovePane(-1)
        end,
    },
    {
        name = function()
            return (FTAGui.state.menuPane == FTAGui.PANE_FILTERS) and "Results Pane" or "Filters Pane"
        end,
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        sound = SOUNDS.GAMEPAD_MENU_FORWARD,
        callback = function()
            FTAGui.MovePane(1)
        end,
    },
    {
        name = function()
            return (FTAGui.sv.enablePageRotation and FTAGui.RC.state.matchingPage == 1) and "Last Page" or "Prev Page"
        end,
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        sound = SOUNDS.GAMEPAD_PAGE_BACK,
        callback = function()
            if FTAGui.RC.state.matchingPage > 1 then
                FTAGui.RC.state.matchingPage = FTAGui.RC.state.matchingPage - 1
                FTAGui.RC.state.matchingSelectedRow = nil
                FTAGui.RefreshAll()
            elseif FTAGui.sv.enablePageRotation and FTAGui.RC.state.matchingPage == 1 then
                FTAGui.RC.state.matchingPage = FTAGui.RC.state.matchingTotalPages
                FTAGui.RC.state.matchingSelectedRow = nil
                FTAGui.RefreshAll()
            end
        end,
        enabled = function()
            return FTAGui.RC.state.matchingPage > 1 or FTAGui.sv.enablePageRotation
        end,
    },
    {
        name = function()
            return (FTAGui.sv.enablePageRotation and FTAGui.RC.state.matchingPage == FTAGui.RC.state.matchingTotalPages) and "First Page" or "Next Page"
        end,
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        sound = SOUNDS.GAMEPAD_PAGE_FORWARD,
        callback = function()
            if FTAGui.RC.state.matchingPage < FTAGui.RC.state.matchingTotalPages then
                FTAGui.RC.state.matchingPage = FTAGui.RC.state.matchingPage + 1
                FTAGui.RC.state.matchingSelectedRow = nil
                FTAGui.RefreshAll()
            elseif FTAGui.sv.enablePageRotation and FTAGui.RC.state.matchingPage == FTAGui.RC.state.matchingTotalPages then
                FTAGui.RC.state.matchingPage = 1
                FTAGui.RC.state.matchingSelectedRow = nil
                FTAGui.RefreshAll()
            end
        end,
        enabled = function()
            return FTAGui.RC.state.matchingPage < FTAGui.RC.state.matchingTotalPages or FTAGui.sv.enablePageRotation
        end,
    },
    {
        name = function()
            if FTAGui.state.menuPane == FTAGui.PANE_FILTERS then
                return "Activate"
            elseif FTAGui.state.menuPane == FTAGui.PANE_RESULTS and FTAGui.RC.GetSelectedRow() ~= nil then
                return FTAGui.state.menuShowExtraItemData and "Less Info" or "More Info"
            end
            return nil
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        visible = function()
            if FTAGui.state.menuPane == FTAGui.PANE_FILTERS then
                return true
            end
            return FTAGui.state.menuPane == FTAGui.PANE_RESULTS and FTAGui.RC.GetSelectedRow() ~= nil
        end,
        callback = function()
            if FTAGui.state.menuPane == FTAGui.PANE_FILTERS then
                FTAGui.ActivateCurrentFilter()
            elseif FTAGui.state.menuPane == FTAGui.PANE_RESULTS and FTAGui.RC.GetSelectedRow() ~= nil then
                FTAGui.ToggleExtraItemDataDetail()
            end
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

function FTAGui.AddKeybindings()
    if KEYBIND_STRIP and FTAGui.menuKeybindStripDescriptor then
        KEYBIND_STRIP:AddKeybindButtonGroup(FTAGui.menuKeybindStripDescriptor)
    end
end

function FTAGui.RefreshKeybindings()
    if KEYBIND_STRIP and FTAGui.menuKeybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(FTAGui.menuKeybindStripDescriptor)
    end
end

function FTAGui.RemoveKeybindings()
    if KEYBIND_STRIP and FTAGui.menuKeybindStripDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(FTAGui.menuKeybindStripDescriptor)
    end
end



-----------------
-- Filters Menu
-----------------

function FTAGui.GetFilters()
    local searchText = SPFLibUtils.SafeText(FTAGui.RC.state.searchFilter)
    if searchText == "" then searchText = "All" end

    return {
        {
            text = string.format("Category: %s", FTAGui.sv.selectedCategory),
            callback = function()
                FTAGui.OpenCategoryDialog()
            end,
        },
        {
            text = string.format("Subcategory: %s", FTAGui.sv.selectedSubcategory),
            callback = function()
                FTAGui.OpenSubategoryDialog()
            end,
        },
        {
            text = string.format("Source: %s", FTAGui.sv.selectedSource),
            callback = function()
                FTAGui.OpenSourceDialog()
            end,
        },
        {
            text = string.format("Group: %s", FTAGui.sv.selectedGroup),
            callback = function()
                FTAGui.OpenGroupDialog()
            end,
        },
        -- TODO: unused in the end
        --[[ {
            text = string.format("Tag: %s", FTAGui.sv.selectedTag),
            callback = function()
                FTAGui.OpenTagDialog()
            end,
        }, ]]
        {
            text = string.format("Inventory: %s", FTAGui.sv.selectedInventory),
            callback = function()
                FTAGui.OpenInventoryDialog()
            end,
        },
        {
            text = string.format("Search Filter: %s", searchText),
            callback = function()
                FTAGui.OpenSearchFilterDialog()
            end,
        },
        {
            text = string.format("Collected Items: %s", FTAGui.sv.showUncollectedItemsOnly and "Hide" or "Show"),
            callback = function()
                FTAGui.sv.showUncollectedItemsOnly = not FTAGui.sv.showUncollectedItemsOnly
                FTAGui.RC.state.matchingPage = 1
                FTAGui.PlayClickSound()
                FTAGui.RC.callbacks.RefreshFull()
            end,
        },
        {
            text = string.format("Ordered by: %s", FTAGui.RC.GetOrderedByLabel()),
            callback = function()
                FTAGui.RC.NextOrderedBy()
                FTAGui.RC.state.matchingPage = 1
                FTAGui.PlayClickSound()
                FTAGui.RC.callbacks.RefreshFull()
            end,
        },
        {
            text = string.format("Rows Per Page: %d", FTAGui.RC.state.matchingPageSize),
            callback = function()
                local newSize = FTAGui.RC.state.matchingPageSize == 50 and 100 or 50
                FTAGui.RC.state.matchingPageSize = newSize
                FTAGui.RC.state.matchingPage = 1
                FTAGui.PlayClickSound()
                FTAGui.RefreshAll()
            end,
        },
        {
            text = "Recheck Uncollected Items",
            callback = function()
                FTAGui.PlayClickSound()
                FTAGui.RC.RecheckUncollectedItems()
            end,
        },
        {
            text = "Rebuild saved results",
            callback = function()
                FTAGui.PlayClickSound()
                FTAGui.RC.Build(true)
            end,
        },
    }
end



------------
-- Changes
------------

function FTAGui.ToggleExtraItemDataDetail()
    if FTAGui.state.menuPane ~= FTAGui.PANE_RESULTS then
        return
    end

    local selectedRow = FTAGui.RC.GetSelectedRow()
    if selectedRow == nil then
        return
    end

    FTAGui.state.menuShowExtraItemData = not FTAGui.state.menuShowExtraItemData
    FTAGuiControls.RefreshDetailPanel(FTAGui.RC.RecreateResult(selectedRow), FTAGui.state.menuShowExtraItemData)
    FTAGui.RefreshKeybindings()
end

function FTAGui.ActivateCurrentFilter()
    if not FTAGui.state.filterList then return end
    local selected = FTAGui.state.filterList:GetTargetData()
    if selected and selected.filterCallback then
        selected.filterCallback()
    end
end

function FTAGui.SetActivePane(pane)
    if pane ~= FTAGui.PANE_FILTERS and pane ~= FTAGui.PANE_RESULTS then
        pane = FTAGui.PANE_RESULTS
    end
    FTAGui.state.menuPane = pane

    if FTAGui.state.filterList and FTAGui.state.resultsList then
        if pane == FTAGui.PANE_FILTERS then
            if FTAGui.state.resultsList.Deactivate then FTAGui.state.resultsList:Deactivate() end
            if FTAGui.state.filterList.Activate then FTAGui.state.filterList:Activate() end
        else
            if FTAGui.state.filterList.Deactivate then FTAGui.state.filterList:Deactivate() end
            if FTAGui.state.resultsList.Activate then FTAGui.state.resultsList:Activate() end
        end
    end

    FTAGuiControls.SetPaneVisuals(pane == FTAGui.PANE_FILTERS, pane == FTAGui.PANE_RESULTS)
    FTAGui.RefreshKeybindings()
end

function FTAGui.MovePane(delta)
    local pane = FTAGui.state.menuPane or FTAGui.PANE_RESULTS
    pane = pane + delta
    if pane < FTAGui.PANE_FILTERS then pane = FTAGui.PANE_RESULTS end
    if pane > FTAGui.PANE_RESULTS then pane = FTAGui.PANE_FILTERS end
    FTAGui.SetActivePane(pane)
end

function FTAGui.PlayClickSound()
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

function FTAGui.CreateLists()
    local leftPaneList = FTAGuiControls.GetLeftPaneList()
    if not leftPaneList then return end
    FTAGui.state.filterList = ZO_GamepadVerticalItemParametricScrollList:New(leftPaneList)
    FTAGui.state.filterList:AddDataTemplate("FTAFilterRowTemplate", FTAGuiControls.FilterEntrySetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    FTAGui.state.filterList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        FTAGui.RefreshKeybindings()
    end)

    local centerPaneList = FTAGuiControls.GetCenterPaneList()
    if not centerPaneList then return end
    FTAGui.state.resultsList = ZO_GamepadVerticalItemParametricScrollList:New(centerPaneList)
    FTAGui.state.resultsList:AddDataTemplate("FTAResultRowTemplate", FTAGuiControls.ResultEntrySetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    FTAGui.state.resultsList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if selectedData and selectedData.row then
            FTAGui.RC.state.matchingSelectedRow = selectedData.row
            FTAGuiControls.RefreshDetailPanel(FTAGui.RC.RecreateResult(selectedData.row), FTAGui.state.menuShowExtraItemData)
        else
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGuiControls.RefreshDetailPanel(nil, FTAGui.state.menuShowExtraItemData)
        end
        FTAGui.RefreshKeybindings()
    end)
end

function FTAGui.CreateScene()
    local root = FTAGuiControls.GetRoot()
    if not root then return end

    local scene = SCENE_MANAGER:GetScene(FTAGui.state.menuSceneName)
    if not scene then
        scene = ZO_Scene:New(FTAGui.state.menuSceneName, SCENE_MANAGER)
    end

    local fragment = ZO_FadeSceneFragment:New(root)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(fragment)

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            FTAGui.RefreshAll()
            FTAGui.AddKeybindings()
            FTAGui.SetActivePane(FTAGui.state.menuPane or FTAGui.PANE_RESULTS)
        elseif newState == SCENE_HIDDEN then
            if FTAGui.state.filterList and FTAGui.state.filterList.Deactivate then FTAGui.state.filterList:Deactivate() end
            if FTAGui.state.resultsList and FTAGui.state.resultsList.Deactivate then FTAGui.state.resultsList:Deactivate() end
            FTAGui.RemoveKeybindings()
        end
    end)

    FTAGui.state.menuScene = scene
    FTAGui.state.menuTopLevel = root
end

function FTAGui.RefreshFilterList()
    if not FTAGui.state.filterList then return end
    FTAGui.state.filterList:Clear()

    local filters = FTAGui.GetFilters()

    for _, filter in ipairs(filters) do
        local entry = ZO_GamepadEntryData:New(filter.text)
        entry.filterCallback = filter.callback
        FTAGui.state.filterList:AddEntry("FTAFilterRowTemplate", entry)
    end

    FTAGui.state.filterList:Commit()
end

local function Mem(label)
    d(string.format("[FTA]: %s: %.1f KB", label, collectgarbage("count")))
end

function FTAGui.RefreshResultsList()
    if not FTAGui.state.resultsList then return end

    -- Mem("Mem before clear")
    FTAGui.state.resultsList:Clear()
    -- more collectgarbage calls can help, because some objects become garbage during previous pass
    collectgarbage("collect")
    -- collectgarbage("collect")
    -- collectgarbage("collect")
    -- Mem("Mem after clear")

    for _, row in ipairs(FTAGui.RC.state.matchingPageRows) do
        local result = FTAGui.RC.RecreateResult(row)

        local type = SPFLibUtils.SafeText(result.typeName)
        local category = SPFLibUtils.SafeText(result.categoryName)
        local subcategory = SPFLibUtils.SafeText(result.subcategoryName)
        local categorySubcategoryName = category
        if subcategory ~= "" then
            categorySubcategoryName = string.format("%s - %s", category, subcategory)
        end

        local entry = ZO_GamepadEntryData:New("")
        entry.furnishingText = result.furnishingName
        entry.categoryText = category
        entry.subcategoryText = subcategory
        entry.categorySubcategoryText = categorySubcategoryName
        entry.typeText = type
        entry.furnishingId = result.furnishingId
        entry.itemId = result.itemId
        entry.row = row
        entry.showLearnIcon = result.isUncollected
        entry.showItemIcon = FTAGui.sv.showIcons

        FTAGui.state.resultsList:AddEntry("FTAResultRowTemplate", entry)
    end

    FTAGui.state.resultsList:Commit()

    local row = FTAGui.RC.GetSelectedRow()
    if not row and FTAGui.RC.state.matchingPageRows[1] then
        row = FTAGui.RC.state.matchingPageRows[1]
        
    end
    FTAGui.RC.state.matchingSelectedRow = row
    FTAGuiControls.RefreshDetailPanel(FTAGui.RC.RecreateResult(row), FTAGui.state.menuShowExtraItemData)
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

function FTAGui.RegisterSearchDialog()
    -- local parametricDialog = ZO_GenericGamepadDialog_GetControl and ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC) or nil
    ZO_Dialogs_RegisterCustomDialog(FTAGui.SEARCH_DIALOG_NAME,
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
                            FTAGui.RC.state.searchFilter = SPFLibUtils.SafeText(dialogRef.data and dialogRef.data.filterText)
                            FTAGui.RC.state.matchingPage = 1
                            FTAGui.RC.state.matchingSelectedRow = nil
                            FTAGui.RefreshAll()
                            ReleaseDialog(FTAGui.SEARCH_DIALOG_NAME)
                        end,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = "Clear Filter",
                        setup = SetupRequestEntry,
                        callback = function(dialogRef)
                            FTAGui.RC.state.searchFilter = ""
                            FTAGui.RC.state.matchingPage = 1
                            FTAGui.RC.state.matchingSelectedRow = nil
                            FTAGui.RefreshAll()
                            ReleaseDialog(FTAGui.SEARCH_DIALOG_NAME)
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
                    ReleaseDialog(FTAGui.SEARCH_DIALOG_NAME)
                end,
            },
        },
    })
end

function FTAGui.RegisterSingleSelectDialog(dialogName)
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

                table.insert(dialog.info.parametricList,
                {
                    template = "ZO_GamepadMenuEntryTemplate",
                    templateData =
                    {
                        text = option.name,
                        baseText = option.name,
                        value = option.value,
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

function FTAGui.RegisterInventoryDialog(dialogName)
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
                        houseId = option.houseId,
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
            {
                keybind = "DIALOG_TERTIARY",
                text = function(dialog)
                    local targetData = dialog.entryList:GetTargetData()
                    if targetData and targetData.houseId ~= nil and targetData.houseId > 0 then
                        local primaryResidance = GetHousingPrimaryHouse()
                        if targetData.houseId == primaryResidance then
                            return "Travel to Primary House"
                        end
                    end
                    return GetString(SI_GAMEPAD_HOUSING_LINK_KEYBIND)
                end,
                callback = function(dialog)
                    local targetData = dialog.entryList:GetTargetData()
                    if targetData and targetData.houseId ~= nil and targetData.houseId > 0 then
                        ReleaseDialog(dialogName)
                        local collectibleData = {
                            GetReferenceId = function() return targetData.houseId end,
                        }
                        zo_callLater(function()
                            ZO_Dialogs_ShowGamepadDialog("GAMEPAD_TRAVEL_TO_HOUSE_OPTIONS_DIALOG", collectibleData)
                        end, 400)
                    end
                end,
                visible = function(dialog)
                    local targetData = dialog.entryList:GetTargetData()
                    return targetData and targetData.houseId ~= nil and targetData.houseId > 0
                end,
            },
        },
    })
end

function FTAGui.RegisterDialogs()
    if FTAGui.state.dialogsRegistered then return end
    FTAGui.state.dialogsRegistered = true

    FTAGui.RegisterSearchDialog()
    FTAGui.RegisterSingleSelectDialog(FTAGui.CATEGORY_DIALOG_NAME)
    FTAGui.RegisterSingleSelectDialog(FTAGui.SUBCATEGORY_DIALOG_NAME)
    FTAGui.RegisterSingleSelectDialog(FTAGui.SOURCE_DIALOG_NAME)
    FTAGui.RegisterSingleSelectDialog(FTAGui.GROUP_DIALOG_NAME)
    FTAGui.RegisterSingleSelectDialog(FTAGui.TAG_DIALOG_NAME)
    FTAGui.RegisterInventoryDialog(FTAGui.INVENTORY_DIALOG_NAME)
end

function FTAGui.OpenSearchFilterDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.SEARCH_DIALOG_NAME, { filterText = SPFLibUtils.SafeText(FTAGui.RC.state.searchFilter) })
end

function FTAGui.IsIgnoredCategory(category)
    for _, ignoredCategory in ipairs(FTAData.ignoredCategories) do
        if category == ignoredCategory then
            return true
        end
    end
    return false
end

function FTAGui.GetAvailableCategories()
    local options = {
        { name = "All", value = "All" },
    }
    for categoryIndex = 1, GetNumFurnitureCategories() do
        local categoryId = GetFurnitureCategoryId(categoryIndex)
        local nameC = GetFurnitureCategoryName(categoryId)
        if not FTAGui.IsIgnoredCategory(nameC) then
            options[#options + 1] = { name = nameC, value = nameC }
        end
    end
    return options
end

function FTAGui.GetAvailableSubcategories()
    local options = {
        { name = "All", value = "All" },
    }
    for categoryIndex = 1, GetNumFurnitureCategories() do
        local categoryId = GetFurnitureCategoryId(categoryIndex)
        local nameC = GetFurnitureCategoryName(categoryId)
        if nameC == FTAGui.sv.selectedCategory then
            for subcategoryIndex = 1, GetNumFurnitureSubcategories(categoryIndex) do
                local subcategoryId = GetFurnitureSubcategoryId(categoryIndex, subcategoryIndex)
                local nameSC = GetFurnitureCategoryName(subcategoryId)
                if not FTAGui.IsIgnoredCategory(nameSC) then
                    options[#options + 1] = { name = nameSC, value = nameSC }
                end
            end
            if nameC == FTAData.servicesCategory then
                local nameSC = FTAData.attunableCraftingStationsCategory
                options[#options + 1] = { name = nameSC, value = nameSC }
            end
        end
    end
    return options
end

function FTAGui.GetAvailableInventories()
    local options = {
        { name = "All", value = "All" },
    }
    for _, inventory in ipairs(FTAGui.RC.GetInventories()) do
        options[#options + 1] = { name = inventory.name, value = inventory.name, color = inventory.color, houseId = inventory.houseId }
    end
    return options
end

function FTAGui.GetSimpleOptions(values)
    local options = {
        { name = "All", value = "All" },
    }
    for _, value in ipairs(values) do
        options[#options + 1] = { name = value, value = value }
    end
    return options
end

function FTAGui.OpenCategoryDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.CATEGORY_DIALOG_NAME, {
        title = "Category",
        selectedValue = FTAGui.sv.selectedCategory,
        options = FTAGui.GetAvailableCategories(),
        onSelect = function(option)
            FTAGui.sv.selectedCategory = option.value
            FTAGui.sv.selectedSubcategory = "All"
            FTAGui.RC.state.matchingPage = 1
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGui.RefreshAll()
        end,
    })
end

function FTAGui.OpenSubategoryDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.SUBCATEGORY_DIALOG_NAME, {
        title = "Subcategory",
        selectedValue = FTAGui.sv.selectedSubcategory,
        options = FTAGui.GetAvailableSubcategories(),
        onSelect = function(option)
            FTAGui.sv.selectedSubcategory = option.value
            FTAGui.RC.state.matchingPage = 1
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGui.RefreshAll()
        end,
    })
end

function FTAGui.OpenSourceDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.SOURCE_DIALOG_NAME, {
        title = "Source",
        selectedValue = FTAGui.sv.selectedSource,
        options = FTAGui.GetSimpleOptions(FTAGui.RC.GetSources()),
        onSelect = function(option)
            FTAGui.sv.selectedSource = option.value
            FTAGui.sv.selectedGroup = "All"
            FTAGui.RC.state.matchingPage = 1
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGui.RefreshAll()
        end,
    })
end

function FTAGui.OpenGroupDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.GROUP_DIALOG_NAME, {
        title = "Group",
        selectedValue = FTAGui.sv.selectedGroup,
        options = FTAGui.GetSimpleOptions(FTAGui.RC.GetGroups()),
        onSelect = function(option)
            FTAGui.sv.selectedGroup = option.value
            FTAGui.RC.state.matchingPage = 1
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGui.RefreshAll()
        end,
    })
end

function FTAGui.OpenTagDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.TAG_DIALOG_NAME, {
        title = "Tag",
        selectedValue = FTAGui.sv.selectedTag,
        options = FTAGui.GetSimpleOptions(FTAGui.RC.GetTags()),
        onSelect = function(option)
            FTAGui.sv.selectedTag = option.value
            FTAGui.RC.state.matchingPage = 1
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGui.RefreshAll()
        end,
    })
end

function FTAGui.OpenInventoryDialog()
    FTAGui.RegisterDialogs()
    ZO_Dialogs_ShowGamepadDialog(FTAGui.INVENTORY_DIALOG_NAME, {
        title = "Inventory",
        selectedValue = FTAGui.sv.selectedInventory,
        options = FTAGui.GetAvailableInventories(),
        onSelect = function(option)
            FTAGui.sv.selectedInventory = option.value
            FTAGui.RC.state.matchingPage = 1
            FTAGui.RC.state.matchingSelectedRow = nil
            FTAGui.RefreshAll()
        end,
    })
end

function FTAGui.GetSelectedRowFromUI()
    -- TODO: check resultsList
    if FTAGui.resultsList and FTAGui.resultsList.GetTargetData then
        local selected = FTAGui.resultsList:GetTargetData()
        if selected and selected.row then
            return selected.row
        end
    end
    return nil
end
