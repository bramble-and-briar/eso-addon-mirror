local ME = MyExtras
local TL = {}
ME.TitleLoop = TL

--------------------------------------------------
-- Config
--------------------------------------------------
TL.name = "MyExtras_TitleLoop"
TL.updateNamespace = "MyExtras_TitleLoop_Rotation"

TL.timerValues = { 1, 5, 10, 15, 30, 60 }
TL.specialTitleNames = {
    random = "Random Favorite Title",
    cycle = "Cycle Favorite Title",
}
TL.loopDefaults = {
    favorites = {},
    enabled = false,
    timerIndex = 4,
    timerUnit = "minutes",
    mode = "cycle",
}
TL.charDefaults = {
    titleLoop = TL.loopDefaults,
}

TL.savedVars = nil
TL.hookState = {}
TL.firstActivationHandled = false
TL.currentDropdown = nil
TL.favoritePrefix = "|t24:24:EsoUI/Art/Collections/Favorite_StarOnly.dds|t "

local function IsTable(value)
    return type(value) == "table"
end

local function SafeTitleName(titleInfo)
    if not titleInfo then
        return ""
    end

    return tostring(titleInfo.name or "")
end

--------------------------------------------------
-- Normalize Settings
--------------------------------------------------
function TL:NormalizeSettings()
    local saved = self.savedVars
    if not IsTable(saved) then
        return
    end

    if not IsTable(saved.favorites) then
        saved.favorites = {}
    end

    if type(saved.enabled) ~= "boolean" then
        saved.enabled = false
    end

    local timerIndex = tonumber(saved.timerIndex) or self.loopDefaults.timerIndex
    timerIndex = zo_clamp and zo_clamp(timerIndex, 1, #self.timerValues)
        or math.max(1, math.min(#self.timerValues, timerIndex))
    saved.timerIndex = timerIndex

    if saved.timerUnit ~= "seconds"
        and saved.timerUnit ~= "minutes"
    then

        saved.timerUnit = "minutes"
    end

    if saved.mode ~= "cycle" and saved.mode ~= "random" then
        saved.mode = "cycle"
    end
end

--------------------------------------------------
-- Timer
--------------------------------------------------
function TL:GetTimerValue()
    if not self.savedVars then
        return self.timerValues[self.loopDefaults.timerIndex]
    end

    return self.timerValues[self.savedVars.timerIndex]
        or self.timerValues[self.loopDefaults.timerIndex]
end

function TL:GetTimerUnit()
    if not self.savedVars then
        return self.loopDefaults.timerUnit
    end

    return self.savedVars.timerUnit == "seconds"
        and "seconds"
        or "minutes"
end

function TL:GetTimerSuffix()
    return self:GetTimerUnit() == "seconds" and "s" or "m"
end

function TL:GetTimerText()
    return string.format(
        "%d%s",
        self:GetTimerValue(),
        self:GetTimerSuffix()
    )
end

function TL:GetTimerIntervalMs()
    local multiplier = self:GetTimerUnit() == "seconds"
        and 1000
        or 60 * 1000

    return self:GetTimerValue() * multiplier
end

--------------------------------------------------
-- Favorites
--------------------------------------------------
function TL:IsFavorite(titleInfo)
    if not self.savedVars or not titleInfo then
        return false
    end

    local titleName = SafeTitleName(titleInfo)
    return titleName ~= ""
        and self.savedVars.favorites[titleName] == true
end

function TL:SetFavorite(titleInfo, isFavorite)
    if not self.savedVars or not titleInfo then
        return false
    end

    local titleName = SafeTitleName(titleInfo)
    if titleName == "" then
        return false
    end

    if isFavorite then
        self.savedVars.favorites[titleName] = true
    else
        self.savedVars.favorites[titleName] = nil
    end

    if self:GetFavoriteCount() == 0 then
        self.savedVars.enabled = false
    end

    self:RestartRotationTimer()
    return true
end

function TL:ToggleFavorite(titleInfo)
    return self:SetFavorite(
        titleInfo,
        not self:IsFavorite(titleInfo)
    )
end

function TL:GetSortedTitles()
    if not TITLE_MANAGER
        or type(TITLE_MANAGER.GetSortedTitles) ~= "function"
    then
        return {}
    end

    local sortType = ZO_SORT_BY_NAME
    local sortOrder = ZO_SORT_ORDER_UP
    local dropdown = self.currentDropdown

    if dropdown then
        sortType = dropdown.m_sortType or sortType
        sortOrder = dropdown.m_sortOrder or sortOrder
    end

    local titles = TITLE_MANAGER:GetSortedTitles(
        sortType,
        sortOrder
    )

    return IsTable(titles) and titles or {}
end

function TL:GetFavoriteTitles()
    local result = {}

    if not self.savedVars then
        return result
    end

    local titles = self:GetSortedTitles()

    for index = 1, #titles do
        local titleInfo = titles[index]

        if self:IsFavorite(titleInfo) then
            result[#result + 1] = titleInfo
        end
    end

    return result
end

function TL:GetFavoriteCount()
    return #self:GetFavoriteTitles()
end

function TL:GetCurrentTitleName(favoriteTitles)
    if type(GetCurrentTitleIndex) ~= "function" then
        return nil
    end

    local currentTitleIndex = GetCurrentTitleIndex()
    if currentTitleIndex == nil then
        return nil
    end

    local titles = favoriteTitles or self:GetSortedTitles()

    for index = 1, #titles do
        local titleInfo = titles[index]

        if titleInfo.index == currentTitleIndex then
            return SafeTitleName(titleInfo)
        end
    end

    if favoriteTitles then
        titles = self:GetSortedTitles()

        for index = 1, #titles do
            local titleInfo = titles[index]

            if titleInfo.index == currentTitleIndex then
                return SafeTitleName(titleInfo)
            end
        end
    end

    return nil
end

function TL:ChooseCycleTitle(favoriteTitles)
    local currentName = self:GetCurrentTitleName(favoriteTitles)

    if not currentName then
        return favoriteTitles[1]
    end

    for index = 1, #favoriteTitles do
        if SafeTitleName(favoriteTitles[index]) == currentName then
            local nextIndex = index + 1

            if nextIndex > #favoriteTitles then
                nextIndex = 1
            end

            return favoriteTitles[nextIndex]
        end
    end

    return favoriteTitles[1]
end

function TL:ChooseRandomTitle(favoriteTitles)
    local currentName = self:GetCurrentTitleName(favoriteTitles)
    local candidates = {}

    for index = 1, #favoriteTitles do
        local titleInfo = favoriteTitles[index]

        if SafeTitleName(titleInfo) ~= currentName then
            candidates[#candidates + 1] = titleInfo
        end
    end

    if #candidates == 0 then
        return nil
    end

    return candidates[math.random(1, #candidates)]
end

--------------------------------------------------
-- Rotation
--------------------------------------------------
function TL:SelectTitleInternal(titleIndex)
    if titleIndex == nil or type(SelectTitle) ~= "function" then
        return false
    end

    SelectTitle(titleIndex)
    return true
end

function TL:SelectNextFavorite()
    local favorites = self:GetFavoriteTitles()

    if #favorites < 2 then
        self:RestartRotationTimer()
        return false
    end

    local nextTitle

    if self.savedVars.mode == "random" then
        nextTitle = self:ChooseRandomTitle(favorites)
    else
        nextTitle = self:ChooseCycleTitle(favorites)
    end

    if not nextTitle
        or nextTitle.index == nil
        or not self:SelectTitleInternal(nextTitle.index)
    then
        self:RestartRotationTimer()
        return false
    end

    self:RestartRotationTimer()
    return true
end

function TL:UnregisterRotationTimer()
    if EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(
            self.updateNamespace
        )
    end
end

function TL:RestartRotationTimer()
    self:UnregisterRotationTimer()

    if not self.savedVars
        or not self.savedVars.enabled
        or self:GetFavoriteCount() < 2
        or not EVENT_MANAGER
    then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(
        self.updateNamespace,
        self:GetTimerIntervalMs(),
        function()
            TL:SelectNextFavorite()
        end
    )
end

function TL:StopRotation()
    if not self.savedVars then
        return
    end

    self.savedVars.enabled = false
    self:UnregisterRotationTimer()
    self:RefreshDropdownKeybinds(self.currentDropdown)
end

function TL:ActivateRotationMode(mode, dropdown)
    if not self.savedVars
        or (mode ~= "cycle" and mode ~= "random")
    then
        return false
    end

    local favorites = self:GetFavoriteTitles()

    if #favorites == 0 then
        self.savedVars.enabled = false
        self:UnregisterRotationTimer()
        self:ScheduleSelectedDisplayRefresh(dropdown)
        return false
    end

    self.savedVars.mode = mode
    self.savedVars.enabled = true

    local nextTitle

    if #favorites == 1 then
        nextTitle = favorites[1]
    elseif mode == "random" then
        nextTitle = self:ChooseRandomTitle(favorites)
    else
        nextTitle = self:ChooseCycleTitle(favorites)
    end

    if nextTitle and nextTitle.index ~= nil then
        self:SelectTitleInternal(nextTitle.index)
    end

    self:RestartRotationTimer()
    self:ScheduleSelectedDisplayRefresh(dropdown)
    self:RefreshDropdownKeybinds(dropdown)
    return nextTitle ~= nil
end

function TL:CycleTimer()
    if not self.savedVars then
        return
    end

    local nextIndex = self.savedVars.timerIndex + 1

    if nextIndex > #self.timerValues then
        nextIndex = 1
    end

    self.savedVars.timerIndex = nextIndex
    self:RestartRotationTimer()
    self:RefreshDropdownKeybinds(self.currentDropdown)
end

function TL:ToggleTimerUnit()
    if not self.savedVars then
        return
    end

    self.savedVars.timerUnit = self:GetTimerUnit() == "seconds"
        and "minutes"
        or "seconds"

    self:RestartRotationTimer()
    self:RefreshDropdownKeybinds(self.currentDropdown)
end

--------------------------------------------------
-- Dropdown
--------------------------------------------------
function TL:IsSpecialData(data)
    return data ~= nil
        and (data.titleLoopSpecialMode == "random"
            or data.titleLoopSpecialMode == "cycle")
end

function TL:GetSpecialTitleName(mode)
    return self.specialTitleNames[mode] or ""
end

function TL:GetNativeSelectedTitleText()
    if type(GetCurrentTitleIndex) == "function" then
        local currentTitleIndex = GetCurrentTitleIndex()

        if currentTitleIndex ~= nil then
            local titles = self:GetSortedTitles()

            for index = 1, #titles do
                local titleInfo = titles[index]

                if titleInfo.index == currentTitleIndex then
                    return self:BuildTitleDisplayName(
                        titleInfo,
                        false
                    )
                end
            end
        end
    end

    if type(GetString) == "function" and SI_STATS_NO_TITLE then
        return GetString(SI_STATS_NO_TITLE)
    end

    return "No Title"
end

function TL:RefreshSelectedDisplay(dropdown)
    if not dropdown
        or type(dropdown.SetSelectedItemText) ~= "function"
    then
        return
    end

    if self.savedVars and self.savedVars.enabled then
        dropdown:SetSelectedItemText(
            self:GetSpecialTitleName(self.savedVars.mode)
        )
    else
        dropdown:SetSelectedItemText(
            self:GetNativeSelectedTitleText()
        )
    end
end

function TL:ScheduleSelectedDisplayRefresh(dropdown)
    if not dropdown then
        return
    end

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            TL:RefreshSelectedDisplay(dropdown)
        end, 0)
    else
        self:RefreshSelectedDisplay(dropdown)
    end
end

function TL:CreateSpecialEntry(dropdown, mode)
    local name = self:GetSpecialTitleName(mode)
    local entry

    if type(dropdown.CreateItemEntry) == "function" then
        entry = dropdown:CreateItemEntry(
            name,
            function()
                TL:ActivateRotationMode(mode, dropdown)
            end
        )
    elseif ZO_ComboBox
        and type(ZO_ComboBox.CreateItemEntry) == "function"
    then
        entry = ZO_ComboBox:CreateItemEntry(
            name,
            function()
                TL:ActivateRotationMode(mode, dropdown)
            end
        )
    end

    if not entry then
        return nil
    end

    entry.titleLoopSpecialMode = mode
    entry.name = name
    return entry
end

function TL:EnsureSpecialEntries(dropdown)
    if not dropdown
        or type(dropdown.GetItems) ~= "function"
        or type(dropdown.ClearItems) ~= "function"
        or type(dropdown.AddItem) ~= "function"
    then
        return false
    end

    local items = dropdown:GetItems()

    if not IsTable(items) then
        return false
    end

    local specialCount = 0

    for index = 1, #items do
        if self:IsSpecialData(items[index]) then
            specialCount = specialCount + 1
        end
    end

    if specialCount == 2
        and items[1]
        and items[1].titleLoopSpecialMode == "random"
        and items[2]
        and items[2].titleLoopSpecialMode == "cycle"
    then
        return true
    end

    local nativeItems = {}

    for index = 1, #items do
        local data = items[index]

        if not self:IsSpecialData(data) then
            nativeItems[#nativeItems + 1] = data
        end
    end

    local randomEntry = self:CreateSpecialEntry(
        dropdown,
        "random"
    )
    local cycleEntry = self:CreateSpecialEntry(
        dropdown,
        "cycle"
    )

    if not randomEntry or not cycleEntry then
        return false
    end

    if type(dropdown.SetSortsItems) == "function" then

        dropdown:SetSortsItems(false)
    end

    dropdown:ClearItems()

    local suppressUpdate = ZO_COMBOBOX_SUPPRESS_UPDATE
        or ZO_COMBOBOX_SUPRESS_UPDATE

    dropdown:AddItem(randomEntry, suppressUpdate)
    dropdown:AddItem(cycleEntry, suppressUpdate)

    for index = 1, #nativeItems do
        dropdown:AddItem(nativeItems[index], suppressUpdate)
    end

    if type(dropdown.UpdateItems) == "function" then
        dropdown:UpdateItems()
    end

    return true
end

function TL:WrapNativeSelectionCallback(data)
    if not data
        or self:IsSpecialData(data)
        or data.titleLoopSelectionWrapped
        or type(data.callback) ~= "function"
    then
        return
    end

    local originalCallback = data.callback

    data.callback = function(...)
        TL:StopRotation()
        return originalCallback(...)
    end
    data.titleLoopSelectionWrapped = true
end

function TL:BuildTitleDisplayName(titleInfo, includeNewIcon)
    local titleName = SafeTitleName(titleInfo)

    if titleName == "" then
        return ""
    end

    if includeNewIcon ~= false
        and titleInfo.isNew
        and type(zo_iconTextFormat) == "function"
    then
        titleName = zo_iconTextFormat(
            "EsoUI/Art/Inventory/newItem_icon.dds",
            "100%",
            "100%",
            titleName
        )
    end

    if type(zo_strformat) == "function" then
        titleName = zo_strformat(
            titleName,
            GetRawUnitName and GetRawUnitName("player") or ""
        )
    end

    if self:IsFavorite(titleInfo) then
        titleName = self.favoritePrefix .. titleName
    end

    return titleName
end

function TL:GetHighlightedData(dropdown)
    if not dropdown then
        return nil
    end

    if dropdown.m_currentData then
        return dropdown.m_currentData
    end

    local focus = dropdown.m_focus

    if focus and type(focus.GetFocusItem) == "function" then
        local focusItem = focus:GetFocusItem()
        return focusItem and focusItem.data or nil
    end

    return nil
end

function TL:UpdateVisibleDropdownItem(
    dropdown,
    data,
    includeNewIcon
)
    if not dropdown or not data or not data.titleInfo then
        return
    end

    data.name = self:BuildTitleDisplayName(
        data.titleInfo,
        includeNewIcon
    )

    local focus = dropdown.m_focus

    if focus and type(focus.GetFocusItem) == "function" then
        local focusItem = focus:GetFocusItem()

        if focusItem
            and focusItem.data == data
            and focusItem.control
            and focusItem.control.nameControl
        then
            focusItem.control.nameControl:SetText(data.name)
        end
    end

    if type(dropdown.GetSelectedItemData) == "function"
        and dropdown:GetSelectedItemData() == data
        and type(dropdown.SetSelectedItemText) == "function"
    then
        dropdown:SetSelectedItemText(data.name)
    end
end

function TL:DecorateDropdown(dropdown)
    if not dropdown
        or type(dropdown.GetItems) ~= "function"
    then
        return
    end

    self:EnsureSpecialEntries(dropdown)

    local items = dropdown:GetItems()

    for index = 1, #items do
        local data = items[index]

        if self:IsSpecialData(data) then
            data.name = self:GetSpecialTitleName(
                data.titleLoopSpecialMode
            )
        else
            self:WrapNativeSelectionCallback(data)

            if data.titleInfo then
                data.name = self:BuildTitleDisplayName(
                    data.titleInfo,
                    true
                )
            end
        end
    end

    self:RefreshSelectedDisplay(dropdown)
end

function TL:RefreshDropdownKeybinds(dropdown)
    if not dropdown
        or not KEYBIND_STRIP
        or type(KEYBIND_STRIP.UpdateKeybindButtonGroup)
            ~= "function"
    then
        return
    end

    if type(dropdown.IsActive) == "function"
        and dropdown:IsActive()
    then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(
            dropdown.keybindStripDescriptor,
            dropdown.m_keybindState
        )
    end
end

function TL:ToggleHighlightedFavorite(dropdown)
    local data = self:GetHighlightedData(dropdown)

    if not data or not data.titleInfo then
        return
    end

    if self:ToggleFavorite(data.titleInfo) then
        self:UpdateVisibleDropdownItem(
            dropdown,
            data,
            true
        )
        self:RefreshSelectedDisplay(dropdown)
        self:RefreshDropdownKeybinds(dropdown)
    end
end

function TL:AddDropdownKeybinds(dropdown)
    local descriptors = dropdown.keybindStripDescriptor

    if not IsTable(descriptors) then
        return false
    end

    descriptors[#descriptors + 1] = {
        keybind = "UI_SHORTCUT_SECONDARY",
        order = 100,
        disabledDuringSceneHiding = true,
        name = function()
            local data = TL:GetHighlightedData(dropdown)

            if data and data.titleInfo
                and TL:IsFavorite(data.titleInfo)
            then
                return "Unfavorite"
            end

            return "Favorite"
        end,
        visible = function()
            local data = TL:GetHighlightedData(dropdown)
            return data ~= nil and data.titleInfo ~= nil
        end,
        callback = function()
            TL:ToggleHighlightedFavorite(dropdown)
        end,
    }

    descriptors[#descriptors + 1] = {
        keybind = "UI_SHORTCUT_TERTIARY",
        order = 200,
        disabledDuringSceneHiding = true,
        name = function()
            return string.format(
                "Timer: %s",
                TL:GetTimerText()
            )
        end,
        callback = function()
            TL:CycleTimer()
        end,
    }

    descriptors[#descriptors + 1] = {
        keybind = "UI_SHORTCUT_QUINARY",
        order = 210,
        disabledDuringSceneHiding = true,
        name = function()
            return TL:GetTimerUnit() == "seconds"
                and "Unit: Seconds"
                or "Unit: Minutes"
        end,
        callback = function()
            TL:ToggleTimerUnit()
        end,
    }

    return true
end

function TL:AttachToDropdown(dropdown)
    if not dropdown
        or not dropdown.keybindStripDescriptor
    then
        return false
    end

    self.currentDropdown = dropdown
    self:DecorateDropdown(dropdown)

    if dropdown.titleLoopInstalled then
        self:RefreshSelectedDisplay(dropdown)
        self:RefreshDropdownKeybinds(dropdown)
        return true
    end

    if not self:AddDropdownKeybinds(dropdown) then
        return false
    end

    if type(dropdown.RegisterCallback) == "function" then
        dropdown:RegisterCallback(
            "OnItemSelected",
            function(control, data)
                TL.currentDropdown = dropdown
                TL:RefreshDropdownKeybinds(dropdown)
            end
        )

        dropdown:RegisterCallback(
            "OnItemDeselected",
            function(control, data)
                if not data or not data.titleInfo then
                    return
                end

                zo_callLater(function()
                    if not data or not data.titleInfo then
                        return
                    end

                    data.name = TL:BuildTitleDisplayName(
                        data.titleInfo,
                        false
                    )

                    if control and control.nameControl then
                        control.nameControl:SetText(data.name)
                    end
                end, 0)
            end
        )

        dropdown:RegisterCallback(
            "OnHideDropdown",
            function()
                if TL.currentDropdown == dropdown then
                    TL.currentDropdown = nil
                end
            end
        )
    end

    dropdown.titleLoopInstalled = true
    self:RefreshSelectedDisplay(dropdown)
    self:RefreshDropdownKeybinds(dropdown)
    return true
end

--------------------------------------------------
-- Hooks
--------------------------------------------------
function TL:InstallHooks()
    if type(SecurePostHook) ~= "function" then
        return false
    end

    if not self.hookState.setCurrentTitleDropdown
        and ZO_GamepadStats
        and type(ZO_GamepadStats.SetCurrentTitleDropdown)
            == "function"
    then
        local ok = pcall(
            SecurePostHook,
            ZO_GamepadStats,
            "SetCurrentTitleDropdown",
            function(statsObject, dropdown)
                TL:AttachToDropdown(dropdown)
            end
        )

        self.hookState.setCurrentTitleDropdown = ok
    end

    if not self.hookState.titleRefresh
        and ZO_Stats_Common
        and type(ZO_Stats_Common.UpdateTitleDropdownTitles)
            == "function"
    then
        local ok = pcall(
            SecurePostHook,
            ZO_Stats_Common,
            "UpdateTitleDropdownTitles",
            function(statsObject, dropdown)
                TL:AttachToDropdown(dropdown)
            end
        )

        self.hookState.titleRefresh = ok
    end

    if not self.hookState.activateTitleDropdown
        and ZO_GamepadStats
        and type(ZO_GamepadStats.ActivateTitleDropdown)
            == "function"
    then
        local ok = pcall(
            SecurePostHook,
            ZO_GamepadStats,
            "ActivateTitleDropdown",
            function(statsObject)
                local dropdown = statsObject
                    and statsObject.currentTitleDropdown

                if TL:AttachToDropdown(dropdown) then
                    TL:RefreshDropdownKeybinds(dropdown)
                end
            end
        )

        self.hookState.activateTitleDropdown = ok
    end

    if not self.hookState.titleRow
        and type(ZO_GamepadStatTitleRow_Setup)
            == "function"
    then
        local ok = pcall(
            SecurePostHook,
            "ZO_GamepadStatTitleRow_Setup",
            function(control)
                TL:AttachToDropdown(
                    control and control.dropdown
                )
            end
        )

        self.hookState.titleRow = ok
    end

    return self.hookState.setCurrentTitleDropdown == true
        or self.hookState.titleRefresh == true
        or self.hookState.activateTitleDropdown == true
        or self.hookState.titleRow == true
end

function TL:ScheduleHookRetries()
    local delays = { 0, 100, 500, 1000 }

    for index = 1, #delays do
        zo_callLater(function()
            TL:InstallHooks()
        end, delays[index])
    end
end

function TL:OnPlayerActivated()
    self:ScheduleHookRetries()

    if self.firstActivationHandled then
        return
    end

    self.firstActivationHandled = true
    self:RestartRotationTimer()
end

function TL:OnTitleUpdated()

    self:RestartRotationTimer()
    self:ScheduleSelectedDisplayRefresh(self.currentDropdown)
end

--------------------------------------------------
-- Take Me There
--------------------------------------------------
local STATS_SCENE = "gamepad_stats_root"

function TL:SelectTitleRow()
    local stats = GAMEPAD_STATS
    if not (stats and stats.mainList and stats.titleEntry) then
        return
    end

    local index = stats.mainList:GetIndexForData(nil, stats.titleEntry)

    if index then
        stats.mainList:SetSelectedIndex(index)
    end
end

function TL:HookStatsScene()
    if self.statsSceneHooked or not SCENE_MANAGER then
        return
    end

    local scene = SCENE_MANAGER:GetScene(STATS_SCENE)
    if not scene then
        return
    end

    self.statsSceneHooked = true

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState ~= SCENE_SHOWN or not TL.pendingTitleRow then
            return
        end

        TL.pendingTitleRow = false
        zo_callLater(function()
            TL:SelectTitleRow()
        end, 50)
    end)
end

function TL:TakeMeThere()
    self:HookStatsScene()
    self.pendingTitleRow = true

    if MAIN_MENU_GAMEPAD and type(MAIN_MENU_GAMEPAD.ShowScene) == "function" then
        MAIN_MENU_GAMEPAD:ShowScene(STATS_SCENE)
    else
        SCENE_MANAGER:Show(STATS_SCENE)
    end
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function TL:GetOptions()
    return {
        {
            type          = "submenu",
            name          = "Title Loop",
            icon          = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_character.dds",
            tooltip       = "Changes your title to your favorite titles on a timer.\n\n"
                         .. "Take Me There just shows you where Title Loop is: the title list on your Character screen. "
                         .. "You don't need to come back here each time. Open that list from your Character screen whenever you want to use it.\n\n"
                         .. ME.SAVED_CHARACTER_TIP,
            options       = {
                {
                    type    = "button",
                    name    = "Take Me There",
                    tooltip = "Opens the title list on your Character screen. From there you can Favorite titles, "
                           .. "set the Timer, and pick Cycle Favorite Title or Random Favorite Title to start the loop.",
                    func    = function() TL:TakeMeThere() end,
                },
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function TL:Init()
    local charVars = ME.charVariables
    if not IsTable(charVars.titleLoop) then
        charVars.titleLoop = {}
    end
    self.savedVars = charVars.titleLoop

    self:NormalizeSettings()
    self:InstallHooks()
    self:ScheduleHookRetries()

    EVENT_MANAGER:RegisterForEvent(self.name .. "_TitleUpdate", EVENT_TITLE_UPDATE, function()
        TL:OnTitleUpdated()
    end)
    if REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(self.name .. "_TitleUpdate", EVENT_TITLE_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    end
end

function TL:OnReset()
    local saved = self.savedVars
    if not IsTable(saved) then
        return
    end

    self:StopRotation()

    saved.favorites  = {}
    saved.enabled    = false
    saved.timerIndex = self.loopDefaults.timerIndex
    saved.timerUnit  = self.loopDefaults.timerUnit
    saved.mode       = self.loopDefaults.mode

    self:NormalizeSettings()
    self:RefreshDropdownKeybinds(self.currentDropdown)
end

ME:RegisterFeature(TL)
