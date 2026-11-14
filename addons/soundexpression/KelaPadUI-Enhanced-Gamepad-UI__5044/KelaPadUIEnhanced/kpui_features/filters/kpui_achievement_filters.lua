-- Session-only gamepad achievement filters.  Keep ESO's earned/unearned mode in
-- sync while filtering the fresh achievement ID lists before the game builds UI.
local DIALOG_NAME = "KELA_ACHIEVEMENT_FILTERS"
local EVENT_NAME = "KelaPadUI_AchievementFilters"
local state = { text = "", mode = SI_ACHIEVEMENT_FILTER_SHOW_ALL, inProgress = false, tracked = false }
local categoryMatches = {}
local initialized = false
local retryRegistered = false
local restoringMode = false

local function HasFilters()
    return state.text ~= "" or state.mode ~= SI_ACHIEVEMENT_FILTER_SHOW_ALL or state.inProgress or state.tracked
end

local function ResetCategoryCache()
    categoryMatches = {}
end

local function IsTrackedInLine(achievementId)
    local trackedId = GetTrackedAchievement()
    if not trackedId or trackedId == 0 then
        return false
    end
    local firstId = GetFirstAchievementInLine(achievementId)
    local id = firstId ~= 0 and firstId or achievementId
    while id and id ~= 0 do
        if id == trackedId then
            return true
        end
        id = GetNextAchievementInLine(id)
    end
    return false
end

local function HasProgress(achievementId)
    if IsAchievementComplete(achievementId) then
        return false
    end
    for index = 1, GetAchievementNumCriteria(achievementId) do
        local _, completed = GetAchievementCriterion(achievementId, index)
        if type(completed) == "number" and completed > 0 then
            return true
        end
    end
    return false
end

local function MatchesAdditionalFilters(achievementId)
    if not achievementId or achievementId == 0 then
        return false
    end
    local displayedId = ZO_GetNextInProgressAchievementInLine(achievementId)
    if not displayedId or displayedId == 0 then
        return false
    end
    if state.text ~= "" then
        local name, description = GetAchievementInfo(displayedId)
        local needle = zo_strlower(state.text)
        local nameMatch = type(name) == "string" and zo_plainstrfind(zo_strlower(name), needle)
        local descriptionMatch = type(description) == "string" and zo_plainstrfind(zo_strlower(description), needle)
        if not nameMatch and not descriptionMatch then
            return false
        end
    end
    if state.inProgress and not HasProgress(displayedId) then
        return false
    end
    if state.tracked and not IsTrackedInLine(achievementId) then
        return false
    end
    return true
end

local function CategoryHasMatches(categoryIndex)
    if categoryMatches[categoryIndex] ~= nil then
        return categoryMatches[categoryIndex]
    end
    local _, numSubcategories, numAchievements = GetAchievementCategoryInfo(categoryIndex)
    local function ListHasMatch(subcategoryIndex, count)
        local ids = ZO_GetAchievementIds(categoryIndex, subcategoryIndex, count or 0)
        for _, id in ipairs(ids) do
            if ZO_ShouldShowAchievement(state.mode, id) and MatchesAdditionalFilters(id) then
                return true
            end
        end
        return false
    end
    local found = ListHasMatch(nil, numAchievements)
    if not found then
        for index = 1, numSubcategories or 0 do
            local _, count = GetAchievementSubCategoryInfo(categoryIndex, index)
            if ListHasMatch(index, count) then
                found = true
                break
            end
        end
    end
    categoryMatches[categoryIndex] = found
    return found
end

local function MakeCheckbox(label, checked, setChecked, header)
    return
    {
        template = "ZO_CheckBoxTemplate_WithoutIndent_Gamepad",
        text = GetString(label),
        header = header and GetString(header) or nil,
        templateData =
        {
            checked = checked,
            setChecked = setChecked,
            setup = ZO_GamepadCheckBoxTemplate_Setup,
            callback = function(dialog)
                local control = dialog.entryList:GetTargetControl()
                if control then
                    ZO_GamepadCheckBoxTemplate_OnClicked(control)
                end
            end,
            narrationText = function(data)
                return ZO_FormatToggleNarrationText(data.text, data.checked(data))
            end,
        },
    }
end

local function RegisterDialog(screen)
    local dialogControl = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
    local refreshScheduled = false
    local function Refresh()
        ResetCategoryCache()
        if refreshScheduled then return end
        refreshScheduled = true
        zo_callLater(function()
            refreshScheduled = false
            if ACHIEVEMENTS_GAMEPAD_SCENE:IsShowing() then
                restoringMode = true
                screen:SwitchToFilterMode(state.mode)
                restoringMode = false
                screen:Update()
            end
        end, 0)
    end
    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME,
    {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = KELA_ACHIEVEMENT_FILTER_TITLE },
        setup = function(dialog)
            local entries = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(entries)
            local draft = dialog.data
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
                                Refresh()
                            end
                        end
                        control.editBoxControl:SetMaxInputChars(100)
                        control.editBoxControl:SetDefaultText(GetString(KELA_ACHIEVEMENT_FILTER_SEARCH_HINT))
                        control.editBoxControl:SetText(draft.text or "")
                        data.control = control
                    end,
                    callback = function(activeDialog)
                        local control = activeDialog.entryList:GetTargetControl()
                        if control and control.editBoxControl then
                            control.editBoxControl:TakeFocus()
                        end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            })
            local modes =
            {
                { id = SI_ACHIEVEMENT_FILTER_SHOW_ALL, label = KELA_ACHIEVEMENT_FILTER_ALL },
                { id = SI_ACHIEVEMENT_FILTER_SHOW_EARNED, label = KELA_ACHIEVEMENT_FILTER_EARNED },
                { id = SI_ACHIEVEMENT_FILTER_SHOW_UNEARNED, label = KELA_ACHIEVEMENT_FILTER_UNEARNED },
            }
            for index, option in ipairs(modes) do
                local mode = option.id
                table.insert(entries, MakeCheckbox(option.label,
                    function() return draft.mode == mode end,
                    function(_, checked)
                        draft.mode = checked and mode or SI_ACHIEVEMENT_FILTER_SHOW_ALL
                        dialog.entryList:RefreshVisible()
                        Refresh()
                    end,
                    index == 1 and KELA_ACHIEVEMENT_FILTER_STATUS or nil))
            end
            table.insert(entries, MakeCheckbox(KELA_ACHIEVEMENT_FILTER_IN_PROGRESS,
                function() return draft.inProgress end,
                function(_, checked) draft.inProgress = checked; Refresh() end,
                KELA_ACHIEVEMENT_FILTER_EXTRA))
            table.insert(entries, MakeCheckbox(KELA_ACHIEVEMENT_FILTER_TRACKED,
                function() return draft.tracked end,
                function(_, checked) draft.tracked = checked; Refresh() end))
            table.insert(entries,
            {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = GetString(KELA_ACHIEVEMENT_FILTER_CLEAR),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(activeDialog)
                        activeDialog.data.text = ""
                        activeDialog.data.mode = SI_ACHIEVEMENT_FILTER_SHOW_ALL
                        activeDialog.data.inProgress = false
                        activeDialog.data.tracked = false
                        Refresh()
                        activeDialog:setupFunc()
                    end,
                },
            })
            dialog:setupFunc()
        end,
        parametricList = {},
        blockDialogReleaseOnPress = true,
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY", text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then data.callback(dialog) end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE", text = SI_GAMEPAD_BACK_OPTION,
                callback = function() ZO_Dialogs_ReleaseDialogOnButtonPress(DIALOG_NAME) end,
            },
        },
    })
end

function KelaSetupAchievementFilters()
    if initialized then return end
    local screen = ACHIEVEMENTS_GAMEPAD
    local scene = ACHIEVEMENTS_GAMEPAD_SCENE
    if not screen or not scene or not screen.itemList or not screen.keybindStripDescriptor then
        if not retryRegistered then
            retryRegistered = true
            EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED, function()
                zo_callLater(KelaSetupAchievementFilters, 0)
            end)
        end
        return
    end
    initialized = true
    if retryRegistered then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED)
        retryRegistered = false
    end
    RegisterDialog(screen)

    -- These hooks only filter data being assembled for this screen.  The core
    -- achievement list, chains, selection, and native status filter remain in use.
    ZO_PreHook(screen, "AddAchievements", function(_, _, _, _, achievementIds)
        for index = #achievementIds, 1, -1 do
            if not MatchesAdditionalFilters(achievementIds[index]) then
                table.remove(achievementIds, index)
            end
        end
        return false
    end)
    ZO_PreHook(screen.itemList, "AddEntry", function(_, _, data)
        if HasFilters() and not screen.visibleCategoryId and data and data.categoryIndex and not data.achievementId then
            return not CategoryHasMatches(data.categoryIndex)
        end
        return false
    end)
    SecurePostHook(screen, "SwitchToFilterMode", function(_, mode)
        -- OnShowing resets the native filter to All; do not mistake that reset
        -- for a user choice.  Other native changes stay synchronized with ours.
        if not restoringMode and scene:GetState() == SCENE_SHOWN and state.mode ~= mode then
            state.mode = mode
            ResetCategoryCache()
            screen:Update()
        end
    end)
    SecurePostHook(screen, "OnShowing", function()
        ResetCategoryCache()
        restoringMode = true
        screen:SwitchToFilterMode(state.mode)
        restoringMode = false
        if HasFilters() then screen:Update() end
    end)
    table.insert(screen.keybindStripDescriptor,
    {
        keybind = kpuiConst.GamepadFilterKeybind,
        name = function()
            local label = GetString(KELA_ACHIEVEMENT_FILTER_TITLE)
            return HasFilters() and (label .. " *") or label
        end,
        callback = function()
            ZO_Dialogs_ShowGamepadDialog(DIALOG_NAME, state)
        end,
    })
    local function OnAchievementDataChanged()
        ResetCategoryCache()
        if HasFilters() and scene:IsShowing() then
            screen:Update()
        end
    end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ACHIEVEMENTS_UPDATED, OnAchievementDataChanged)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ACHIEVEMENT_UPDATED, OnAchievementDataChanged)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ACHIEVEMENT_AWARDED, OnAchievementDataChanged)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ACHIEVEMENT_TRACKING_UPDATE, OnAchievementDataChanged)
end
