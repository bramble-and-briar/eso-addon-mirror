-- Additional gamepad Antiquities filters.  Filter the journal's transient list;
-- the game's category, visibility and lead logic remain authoritative.
local DIALOG_NAME = "KELA_ANTIQUITY_FILTERS"
local filters = { text = "", difficulty = {}, rarity = {}, type = {}, lead = {}, recovered = {}, codex = {} }
local initialized = false
local RARITY_QUALITIES = { 1, 2, 3, 4, 5 }
local LEAD_EXPIRING_SOON_S = 7 * 24 * 60 * 60

local function AnySelected(values)
    return next(values) ~= nil
end

function KelaAntiquityFiltersActive()
    return filters.text ~= "" or AnySelected(filters.difficulty) or AnySelected(filters.rarity)
        or AnySelected(filters.type) or AnySelected(filters.lead) or AnySelected(filters.recovered)
        or AnySelected(filters.codex)
end

local function MatchesPair(selections, value)
    return not AnySelected(selections) or (value and selections.yes) or (not value and selections.no)
end

local function AnyChild(setData, predicate)
    for _, antiquity in setData:AntiquityIterator({ ZO_Antiquity.IsVisible }) do
        if predicate(antiquity) then return true end
    end
    return false
end

local function NameMatches(item, needle)
    local name = item:GetName()
    return name ~= nil and zo_plainstrfind(zo_strlower(name), needle) ~= nil
end

local function GetRewardType(item)
    if not item:HasReward() then return nil end
    return REWARDS_MANAGER:GetRewardContextualTypeString(item:GetRewardId()) or GetString(SI_ANTIQUITY_TYPE_FALLBACK)
end

local function LeadStatusMatches(item)
    if not AnySelected(filters.lead) then return true end
    if item:HasLead() then
        if filters.lead.acquired then return true end
        if filters.lead.expiring then
            local remaining = item:GetLeadTimeRemainingS()
            return remaining > 0 and remaining <= LEAD_EXPIRING_SOON_S
        end
        return false
    end
    if not item:MeetsLeadRequirements() then return filters.lead.missing == true end
    return filters.lead.always == true
end

-- One visible fragment has to satisfy every active per-fragment filter at once.
local function FragmentMatches(item, needle)
    if needle and not NameMatches(item, needle) then return false end
    if AnySelected(filters.difficulty) and not filters.difficulty[item:GetDifficulty()] then return false end
    return LeadStatusMatches(item)
end

function KelaAntiquityMatchesFilters(antiquityData, setData)
    if not KelaAntiquityFiltersActive() or not IsInGamepadPreferredMode() then return true end
    local target = setData or antiquityData
    if not target then return true end

    local needle = filters.text ~= "" and zo_strlower(filters.text) or nil
    if AnySelected(filters.rarity) and not filters.rarity[target:GetQuality()] then return false end
    if AnySelected(filters.type) then
        local rewardType = GetRewardType(target)
        if not rewardType or not filters.type[rewardType] then return false end
    end
    if not MatchesPair(filters.recovered, target:HasRecovered()) then return false end
    if AnySelected(filters.codex) then
        local total = target:GetNumLoreEntries()
        if not total or total <= 0 then return false end
        if not MatchesPair(filters.codex, target:GetNumUnlockedLoreEntries() >= total) then return false end
    end

    if not setData then
        return FragmentMatches(antiquityData, needle)
    end
    local setTextMatches = needle == nil or NameMatches(setData, needle)
    local needsFragment = AnySelected(filters.difficulty) or AnySelected(filters.lead) or not setTextMatches
    if not needsFragment then return true end
    local fragmentNeedle = needle
    if setTextMatches then fragmentNeedle = nil end
    return AnyChild(setData, function(item) return FragmentMatches(item, fragmentNeedle) end)
end

function KelaFilterAntiquityScrollData(listObject)
    if not KelaAntiquityFiltersActive() or not IsInGamepadPreferredMode() then return end
    local listControl = listObject:GetListControl()
    if not listControl then return end
    local scrollData = ZO_ScrollList_GetDataList(listControl)
    if not scrollData or #scrollData == 0 then return end
    local remove, heading, headingHasMatches = {}, nil, false
    local function FinishHeading()
        if heading and not headingHasMatches then remove[#remove + 1] = heading end
    end
    for index = 1, #scrollData do
        local entry = scrollData[index].data
        local source = entry and entry.dataSource
        if source then
            local kind = source.GetType and source:GetType()
            local matches = true
            if kind == ZO_ANTIQUITY_TYPE_SET then matches = KelaAntiquityMatchesFilters(nil, source)
            elseif kind == ZO_ANTIQUITY_TYPE_INDIVIDUAL then matches = KelaAntiquityMatchesFilters(source) end
            if matches then headingHasMatches = true else remove[#remove + 1] = index end
        elseif entry and entry.label ~= nil then
            FinishHeading(); heading = index; headingHasMatches = false
        else
            headingHasMatches = true
        end
    end
    FinishHeading()
    table.sort(remove)
    for index = #remove, 1, -1 do table.remove(scrollData, remove[index]) end
    if #remove > 0 then ZO_ScrollList_SetAutoSelectToMatchingDataEntry(listObject.list, listObject.lastSelectedData) end
end

local function Refresh()
    local fragment = ZO_ANTIQUITY_JOURNAL_LIST_GAMEPAD_FRAGMENT
    if ANTIQUITY_JOURNAL_GAMEPAD and fragment and not fragment:IsHidden() then
        ANTIQUITY_JOURNAL_GAMEPAD:RefreshAntiquityList()
    end
end

local function AddCheckbox(entries, label, header, values, key, narrationLabel)
    table.insert(entries,
    {
        template = "ZO_CheckBoxTemplate_WithoutIndent_Gamepad", text = label, header = header,
        templateData =
        {
            checked = function() return values[key] == true end,
            setChecked = function(_, checked) values[key] = checked and true or nil; Refresh() end,
            setup = ZO_GamepadCheckBoxTemplate_Setup,
            callback = function(dialog)
                local control = dialog.entryList:GetTargetControl()
                if control then ZO_GamepadCheckBoxTemplate_OnClicked(control) end
            end,
            narrationText = function(data) return ZO_FormatToggleNarrationText(narrationLabel or data.text, data.checked(data)) end,
        },
    })
end

local function GetAvailableDifficulties()
    local seen, difficulties = {}, {}
    for _, antiquity in ANTIQUITY_DATA_MANAGER:AntiquityIterator({ ZO_Antiquity.IsVisible }) do
        local difficulty = antiquity:GetDifficulty()
        if difficulty and difficulty >= 1 and difficulty <= 5 and not seen[difficulty] then
            seen[difficulty] = true
            difficulties[#difficulties + 1] = difficulty
        end
    end
    if #difficulties == 0 then
        for difficulty = 1, 5 do difficulties[#difficulties + 1] = difficulty end
    end
    table.sort(difficulties)
    return difficulties
end

local function GetAvailableTypes()
    local seen, types = {}, {}
    for _, antiquity in ANTIQUITY_DATA_MANAGER:AntiquityIterator({ ZO_Antiquity.IsVisible }) do
        local rewardType = GetRewardType(antiquity:GetAntiquitySetData() or antiquity)
        if rewardType and not seen[rewardType] then
            seen[rewardType] = true
            types[#types + 1] = rewardType
        end
    end
    table.sort(types)
    return types
end

local function RegisterDialog()
    local dialogControl = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME,
    {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = KELA_ANTIQUITY_FILTER_TITLE },
        setup = function(dialog)
            local entries = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(entries)
            table.insert(entries,
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData =
                {
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = function(edit)
                            if dialogControl.data then
                                local text = edit:GetText()
                                if filters.text ~= text then filters.text = text; Refresh() end
                            end
                        end
                        control.editBoxControl:SetMaxInputChars(100)
                        control.editBoxControl:SetDefaultText(GetString(KELA_ANTIQUITY_FILTER_SEARCH_HINT))
                        control.editBoxControl:SetText(filters.text)
                        data.control = control
                    end,
                    callback = function(activeDialog)
                        local control = activeDialog.entryList:GetTargetControl()
                        if control and control.editBoxControl then control.editBoxControl:TakeFocus() end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            })
            
            -- Add Recovered Status Filter Options
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_STATUS_RECOVERED), GetString(KELA_ANTIQUITY_FILTER_RECOVERY), filters.recovered, "yes")
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_STATUS_NOT_RECOVERED), nil, filters.recovered, "no")
            -- Add Lead Status Filter Options
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_STATUS_LEAD_ACQUIRED), GetString(KELA_ANTIQUITY_FILTER_LEAD), filters.lead, "acquired")
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_STATUS_NO_LEAD), nil, filters.lead, "missing")
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_STATUS_ALWAYS_AVAILABLE), nil, filters.lead, "always")
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_STATUS_EXPIRING_SOON), nil, filters.lead, "expiring")
            -- Add Codex Filter Options
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_CODEX_COMPLETED), GetString(KELA_ANTIQUITY_FILTER_CODEX), filters.codex, "yes")
            AddCheckbox(entries, GetString(KELA_ANTIQUITY_FILTER_CODEX_NOT_COMPLETED), nil, filters.codex, "no")
            -- Determine which difficulties are seen to only show relevant ones
            local difficulties = GetAvailableDifficulties()
            local available = {}
            for _, difficulty in ipairs(difficulties) do available[difficulty] = true end
            for difficulty in pairs(filters.difficulty) do
                if not available[difficulty] then filters.difficulty[difficulty] = nil end
            end
            -- Add Difficulty Filter Options
            for index, difficulty in ipairs(difficulties) do
                AddCheckbox(entries, GetString("SI_ANTIQUITYDIFFICULTY", difficulty),
                    index == 1 and GetString(KELA_ANTIQUITY_FILTER_DIFFICULTY) or nil, filters.difficulty, difficulty)
            end
            -- Add Quality Filter Options
            for index, quality in ipairs(RARITY_QUALITIES) do
                local name = GetString("SI_ITEMDISPLAYQUALITY", quality + 1)
                local coloredName = GetAntiquityQualityColor(quality):Colorize(name)
                AddCheckbox(entries, coloredName,
                    index == 1 and GetString(KELA_ANTIQUITY_FILTER_RARITY) or nil, filters.rarity, quality, name)
            end
            -- Add Type Filter Options
            local types = GetAvailableTypes()
            local availableTypes = {}
            for _, rewardType in ipairs(types) do availableTypes[rewardType] = true end
            for rewardType in pairs(filters.type) do
                if not availableTypes[rewardType] then filters.type[rewardType] = nil end
            end
            for index, rewardType in ipairs(types) do
                AddCheckbox(entries, rewardType,
                    index == 1 and GetString(KELA_ANTIQUITY_FILTER_TYPE) or nil, filters.type, rewardType)
            end
            
            table.insert(entries,
            {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = GetString(KELA_ANTIQUITY_FILTER_CLEAR), setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(activeDialog)
                        filters.text = ""
                        ZO_ClearTable(filters.difficulty); ZO_ClearTable(filters.rarity); ZO_ClearTable(filters.type)
                        ZO_ClearTable(filters.lead); ZO_ClearTable(filters.recovered); ZO_ClearTable(filters.codex)
                        if ANTIQUITY_JOURNAL_GAMEPAD then ANTIQUITY_JOURNAL_GAMEPAD.currentFilter = ANTIQUITY_FILTER_SHOW_ALL end
                        Refresh()
                        activeDialog:setupFunc()
                    end,
                },
            })
            dialog:setupFunc()
        end,
        parametricList = {}, blockDialogReleaseOnPress = true,
        buttons =
        {
            { keybind = "DIALOG_PRIMARY", text = SI_GAMEPAD_SELECT_OPTION, callback = function(dialog)
                local data = dialog.entryList:GetTargetData()
                if data and data.callback then data.callback(dialog) end
            end },
            { keybind = "DIALOG_NEGATIVE", text = SI_GAMEPAD_BACK_OPTION, callback = function()
                ZO_Dialogs_ReleaseDialogOnButtonPress(DIALOG_NAME)
            end },
        },
    })
end

local function AddKeybind(descriptor)
    if not descriptor or descriptor.kelaAntiquityFilterKeybindAdded then return end
    table.insert(descriptor,
    {
        order = 40, keybind = kpuiConst.GamepadFilterKeybind,
        name = function()
            local label = GetString(KELA_ANTIQUITY_FILTER_TITLE)
            return KelaAntiquityFiltersActive() and (label .. " *") or label
        end,
        callback = function()
            -- The journal's native selector is an additional AND filter applied
            -- while the list is built, so reset it and let our filters decide.
            local journal = ANTIQUITY_JOURNAL_GAMEPAD
            if journal and journal.currentFilter ~= ANTIQUITY_FILTER_SHOW_ALL then
                journal.currentFilter = ANTIQUITY_FILTER_SHOW_ALL
                Refresh()
            end
            ZO_Dialogs_ShowGamepadDialog(DIALOG_NAME, {})
        end,
    })
    descriptor.kelaAntiquityFilterKeybindAdded = true
end

local function AddCategoryKeybinds(screen)
    if not screen then return end
    AddKeybind(screen.categoryList and screen.categoryList.keybindStripDescriptor)
    AddKeybind(screen.subcategoryList and screen.subcategoryList.keybindStripDescriptor)
end

function KelaSetupAntiquityFilters()
    if initialized or not ANTIQUITY_DATA_MANAGER or not ZO_AntiquityJournalGamepad or not ZO_AntiquityJournalListGamepad then return end
    initialized = true
    ZO_PreHook(ZO_AntiquityJournalListGamepad, "CommitScrollList", KelaFilterAntiquityScrollData)
    ZO_PostHook(ZO_AntiquityJournalGamepad, "InitializeLists", AddCategoryKeybinds)
    ZO_PostHook(ZO_AntiquityJournalListGamepad, "InitializeLists", function(listObject) AddKeybind(listObject.keybindStripDescriptor) end)
    AddCategoryKeybinds(ANTIQUITY_JOURNAL_GAMEPAD)
    if ANTIQUITY_JOURNAL_LIST_GAMEPAD then AddKeybind(ANTIQUITY_JOURNAL_LIST_GAMEPAD.keybindStripDescriptor) end
    RegisterDialog()
end
