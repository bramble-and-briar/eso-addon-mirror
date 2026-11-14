-- Set-name search for the gamepad reconstruction and item-set collection books.
-- Each book owns its query and uses its existing pieceFilters pipeline.
local DIALOG_NAME = "KELA_RECONSTRUCT_SEARCH"
local reconstructState = { text = "", needle = "" }
local collectionsState = { text = "", needle = "" }
local dialogRegistered = false
local retryRegistered = false
local RETRY_EVENT_NAME = "KelaPadUI_GamepadFilters"

local function MatchesSetName(state, piece)
    if state.needle == "" then
        return true
    end
    local collection = piece and piece.GetItemSetCollectionData and piece:GetItemSetCollectionData()
    local name = collection and collection.GetFormattedName and collection:GetFormattedName()
    return type(name) == "string" and zo_plainstrfind(zo_strlower(name), state.needle) and true or false
end

local function ApplySearch(state, text)
    local screen = state.screen
    if not screen or not screen.RefreshFilters then
        return
    end
    text = text or ""
    if text == state.text then
        return
    end

    -- A search can remove the current category.  Return to the category list
    -- before its asynchronous refresh so core never rebuilds a missing parent.
    if screen.gridListPanelList and screen.gridListPanelList:IsActive() then
        screen:ExitGridList()
    end
    if screen.categoryListDescriptor then
        screen:ShowListDescriptor(screen.categoryListDescriptor)
    end
    state.text = text
    state.needle = zo_strlower(text)
    screen:RefreshFilters()
end

local function RegisterSearchDialog()
    local dialogControl = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
    local refreshScheduled = false
    local function QueueSearch(state, text)
        state.pendingText = text
        if refreshScheduled then return end
        refreshScheduled = true
        zo_callLater(function()
            refreshScheduled = false
            if state.screen:GetFragment():IsShowing() then
                ApplySearch(state, state.pendingText)
            end
        end, 0)
    end

    local function PrepareBaseChange(state)
        local screen = state.screen
        if screen.gridListPanelList and screen.gridListPanelList:IsActive() then screen:ExitGridList() end
        if screen.categoryListDescriptor then screen:ShowListDescriptor(screen.categoryListDescriptor) end
    end

    local function AddCheckbox(entries, text, header, checked, change)
        table.insert(entries,
        {
            template = "ZO_CheckBoxTemplate_WithoutIndent_Gamepad", text = text, header = header,
            templateData =
            {
                checked = checked,
                setChecked = function(_, value) change(value) end,
                setup = ZO_GamepadCheckBoxTemplate_Setup,
                callback = function(dialog)
                    local control = dialog.entryList:GetTargetControl()
                    if control then ZO_GamepadCheckBoxTemplate_OnClicked(control) end
                end,
                narrationText = function(data) return ZO_FormatToggleNarrationText(data.text, data.checked(data)) end,
            },
        })
    end

    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME,
    {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local entries = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(entries)
            local state = dialog.data.state
            local manager = ITEM_SET_COLLECTIONS_DATA_MANAGER
            table.insert(entries,
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData =
                {
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = function(edit)
                            if dialogControl.data then
                                dialogControl.data.text = edit:GetText()
                                QueueSearch(state, dialogControl.data.text)
                            end
                        end
                        control.editBoxControl:SetMaxInputChars(100)
                        control.editBoxControl:SetDefaultText(GetString(KELA_RECONSTRUCT_SEARCH_HINT))
                        control.editBoxControl:SetText(dialog.data.text or "")
                        data.control = control
                    end,
                    callback = function(activeDialog)
                        local control = activeDialog.entryList:GetTargetControl()
                        if control and control.editBoxControl then control.editBoxControl:TakeFocus() end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            })
            AddCheckbox(entries, GetString(KELA_SET_FILTER_SHOW_LOCKED), GetString(KELA_SET_FILTER_BASE_HEADER),
                function() return manager:GetShowLocked() end,
                function(value) PrepareBaseChange(state); manager:SetShowLocked(value) end)
            local function AddEquipment(options, header)
                for index, filterType in ipairs(options) do
                    local id = filterType
                    AddCheckbox(entries, GetString("SI_EQUIPMENTFILTERTYPE", id), index == 1 and GetString(header) or nil,
                        function()
                            for _, selected in ipairs(manager:GetEquipmentFilterTypes()) do
                                if selected == id then return true end
                            end
                            return false
                        end,
                        function(value)
                            local selected = {}
                            for _, current in ipairs(manager:GetEquipmentFilterTypes()) do
                                if current ~= id then selected[#selected + 1] = current end
                            end
                            if value then selected[#selected + 1] = id end
                            PrepareBaseChange(state)
                            manager:SetEquipmentFilterTypes(selected)
                        end)
                end
            end
            AddEquipment(ZO_ItemSetCollectionsDataManager.GetApparelFilterTypes(), KELA_SET_FILTER_APPAREL)
            AddEquipment(ZO_ItemSetCollectionsDataManager.GetWeaponFilterTypes(), KELA_SET_FILTER_WEAPONS)
            table.insert(entries,
            {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = GetString(KELA_RECONSTRUCT_SEARCH_CLEAR), setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(activeDialog)
                        activeDialog.data.text = ""
                        QueueSearch(state, "")
                        PrepareBaseChange(state)
                        manager:SetShowLocked(true)
                        manager:SetEquipmentFilterTypes({})
                        activeDialog:setupFunc()
                    end,
                },
            })
            dialog:setupFunc()
        end,
        title = { text = KELA_RECONSTRUCT_SEARCH_TITLE },
        parametricList = {},
        blockDialogReleaseOnPress = true,
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then
                        data.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(DIALOG_NAME)
                end,
            },
        },
    })
end

local function InitializeBook(state, screen, scene)
    if state.screen then
        return true
    end
    if not screen or not scene or not screen.RefreshPieceFilters
        or not screen.categoryKeybindStripDescriptor or not screen.subcategoryKeybindStripDescriptor
        or not screen.gridKeybindStripDescriptor then
        return false
    end
    state.screen = screen
    if not dialogRegistered then
        RegisterSearchDialog()
        dialogRegistered = true
    end

    SecurePostHook(screen, "RefreshPieceFilters", function()
        if state.needle ~= "" then
            table.insert(screen.pieceFilters, function(piece) return MatchesSetName(state, piece) end)
        end
    end)

    local searchKeybind =
    {
        name = function()
            if state.text ~= "" then
                return zo_strformat(GetString(KELA_RECONSTRUCT_SEARCH_ACTIVE), state.text)
            end
            return GetString(KELA_RECONSTRUCT_SEARCH_TITLE)
        end,
        keybind = kpuiConst.GamepadFilterKeybind,
        callback = function()
            ZO_Dialogs_ShowGamepadDialog(DIALOG_NAME, { text = state.text, state = state })
        end,
    }
    table.insert(screen.categoryKeybindStripDescriptor, searchKeybind)
    table.insert(screen.subcategoryKeybindStripDescriptor, searchKeybind)
    table.insert(screen.gridKeybindStripDescriptor, searchKeybind)

    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDING and state.text ~= "" then
            state.text = ""
            state.needle = ""
            screen:RefreshFilters()
        end
    end)
    return true
end

function KelaSetupMenuFilters()
    local reconstructReady = InitializeBook(reconstructState, ZO_RETRAIT_STATION_RECONSTRUCT_GAMEPAD, GAMEPAD_RECONSTRUCT_SCENE)
    local collectionsReady = InitializeBook(collectionsState, GAMEPAD_ITEM_SETS_BOOK, GAMEPAD_ITEM_SETS_BOOK_SCENE)
    if reconstructReady and collectionsReady then
        if retryRegistered then
            EVENT_MANAGER:UnregisterForEvent(RETRY_EVENT_NAME, EVENT_PLAYER_ACTIVATED)
            EVENT_MANAGER:UnregisterForEvent(RETRY_EVENT_NAME, EVENT_RETRAIT_STATION_INTERACT_START)
            retryRegistered = false
        end
    elseif not retryRegistered then
        -- Retry when entering the world or a station if a core screen was not
        -- created yet at add-on load.  Each book is installed only once.
        retryRegistered = true
        local function RetrySetup()
            zo_callLater(KelaSetupMenuFilters, 0)
        end
        EVENT_MANAGER:RegisterForEvent(RETRY_EVENT_NAME, EVENT_PLAYER_ACTIVATED, RetrySetup)
        EVENT_MANAGER:RegisterForEvent(RETRY_EVENT_NAME, EVENT_RETRAIT_STATION_INTERACT_START, RetrySetup)
    end
end
