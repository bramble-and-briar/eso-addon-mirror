local AF = {}
AF.name = "AchievementFilter"
AF.refreshDelayMs = 100

AF.REWARD_KEYS = { "TITLE", "DYE", "ITEM", "COLLECTIBLE", "TRIBUTE" }
AF.LABELS = {
    TITLE = "Title",
    DYE = "Dye",
    ITEM = "Item",
    COLLECTIBLE = "Collectible",
    TRIBUTE = "Tribute upgrade",
    MULTIPLE = "Multiple",
    FILTERS = "Reward filters",
    CLEAR = "Clear",
    HEADER = "Filter by reward",
    OPEN_ACHIEVEMENT = "Open achievement",
    PIN_ACHIEVEMENT = "Pin achievement",
    UNPIN_ACHIEVEMENT = "Unpin achievement",
}

ZO_CreateStringId("SI_BINDING_NAME_ACHIEVEMENT_FILTER_TOGGLE", "Toggle Window")

AF.defaults = {
    selectedRewards = {}, -- multi-select OR: if empty, show all
    selectedSources = {},
    selectedPoints = {},  -- multi-select OR: if empty, show all
    earnedFilter = "ALL", -- ALL|EARNED|UNEARNED
    pinnedFilter = "ALL", -- ALL|PINNED|UNPINNED
    pointsMin = nil,
    pointsMax = nil,
    searchTitle = "",
    searchDescription = "",
    searchSource = "",
    searchReward = "",
    dateFrom = nil,         -- numeric key YYYYMMDD (or nil for no lower bound)
    dateTo = nil,           -- numeric key YYYYMMDD (or nil for no upper bound)
    finishedPreset = "ANY", -- ANY, TODAY, LAST_7, LAST_30, THIS_MONTH, LAST_MONTH, THIS_YEAR, LAST_YEAR, OLDER_THAN_YEAR, CUSTOM
    sortKey = "title",      -- current sort column
    sortAscending = true,   -- current sort direction
}

AF.saved = nil
AF.rewardIndex = {}      -- [achievementId] = { TITLE=bool, DYE=bool, ITEM=bool, COLLECTIBLE=bool, TRIBUTE=bool }
AF.lineRewardCache = {}  -- [baseAchievementId] = { ...combined booleans across the line... }
AF.masterList = nil      -- array of entries for our custom panel
AF.sourcesSet = {}       -- set of available sources (category/subcategory)
AF.pointsSet = {}        -- set of available point values
AF.datesSet = {}         -- set of available completion dates (keyed by numeric date key)
AF.ui = {}               -- references to created UI controls
AF.exampleDateText = nil
AF.totalPointsAll = 0    -- absolute total points across all achievements (not filtered)
AF.totalPointsEarned = 0 -- absolute earned points across all completed achievements
AF.totalAchievementsAll = 0
AF.totalAchievementsCompleted = 0

local function GetBaseId(id)
    local base = GetFirstAchievementInLine(id)
    return (base ~= 0) and base or id
end

function AF:ComputeRewardInfo(id)
    local info = self.rewardIndex[id]
    if info then return info end

    local hasItem = select(1, GetAchievementRewardItem(id))
    local hasTitle = select(1, GetAchievementRewardTitle(id))
    local hasDye = select(1, GetAchievementRewardDye(id))
    local hasCollectible = select(1, GetAchievementRewardCollectible(id))
    local hasTribute = select(1, GetAchievementRewardTributeCardUpgradeInfo(id))

    info = {
        TITLE = (hasTitle == true),
        DYE = (hasDye == true),
        ITEM = (hasItem == true),
        COLLECTIBLE = (hasCollectible == true),
        TRIBUTE = (hasTribute == true),
    }
    self.rewardIndex[id] = info
    return info
end

function AF:GetLineRewardInfo(id)
    local base = GetBaseId(id)
    local cached = self.lineRewardCache[base]
    if cached then return cached end

    local combined = { TITLE = false, DYE = false, ITEM = false, COLLECTIBLE = false, TRIBUTE = false }
    local cur = base
    while cur ~= 0 do
        local info = self:ComputeRewardInfo(cur)
        for k, v in pairs(info) do
            if v then combined[k] = true end
        end
        cur = GetNextAchievementInLine(cur)
    end

    self.lineRewardCache[base] = combined
    return combined
end

function AF:IsAnyRewardFilterSelected()
    for _, key in ipairs(self.REWARD_KEYS) do
        if self.saved.selectedRewards[key] then return true end
    end
    return false
end

function AF:ToggleReward(key)
    self.saved.selectedRewards[key] = not self.saved.selectedRewards[key]
    -- Refresh our panel list if open
    if self.ui and self.ui.list then self:RefreshResults() end
    -- Refresh default Achievements list only if that scene is showing and object is valid
    if ACHIEVEMENTS and SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("achievements") and ACHIEVEMENTS.RefreshVisibleCategoryFilter then
        pcall(function() ACHIEVEMENTS:RefreshVisibleCategoryFilter() end)
    end
end

function AF:ClearRewardFilters()
    ZO_ClearTable(self.saved.selectedRewards)
    -- Refresh our panel list if open
    if self.ui and self.ui.list then self:RefreshResults() end
    -- Refresh default Achievements list only if that scene is showing and object is valid
    if ACHIEVEMENTS and SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("achievements") and ACHIEVEMENTS.RefreshVisibleCategoryFilter then
        pcall(function() ACHIEVEMENTS:RefreshVisibleCategoryFilter() end)
    end
end

function AF:ShowRewardMenu(anchor)
    ClearMenu()
    AddCustomMenuItem(self.LABELS.HEADER, function() end, MENU_ADD_OPTION_HEADER)

    for _, key in ipairs(self.REWARD_KEYS) do
        local label = self.LABELS[key]
        local isChecked = self.saved.selectedRewards[key] == true
        local index = AddCustomMenuItem(label, function() self:ToggleReward(key) end, MENU_ADD_OPTION_CHECKBOX)
        if isChecked and ZO_Menu and ZO_Menu.items and ZO_Menu.items[index] and ZO_Menu.items[index].checkbox then
            ZO_CheckButton_SetChecked(ZO_Menu.items[index].checkbox)
        end
    end

    AddCustomMenuItem(self.LABELS.CLEAR, function() self:ClearRewardFilters() end, MENU_ADD_OPTION_LABEL)
    ShowMenu(anchor)
end

function AF:IsAnyPointsFilterSelected()
    for pts, _ in pairs(self.saved.selectedPoints) do
        if self.saved.selectedPoints[pts] then return true end
    end
    return false
end

function AF:TogglePoints(pts)
    self.saved.selectedPoints[pts] = not self.saved.selectedPoints[pts]
    if self.ui and self.ui.list then self:RefreshResults() end
end

function AF:ClearPointsFilters()
    ZO_ClearTable(self.saved.selectedPoints)
    if self.ui and self.ui.list then self:RefreshResults() end
end

function AF:ShowPointsMenu(anchor)
    ClearMenu()
    AddCustomMenuItem("Filter by points", function() end, MENU_ADD_OPTION_HEADER)

    -- Build sorted list of point values
    local pointsList = {}
    for pts, _ in pairs(self.pointsSet) do
        table.insert(pointsList, pts)
    end
    table.sort(pointsList)

    for _, pts in ipairs(pointsList) do
        local label = tostring(pts) .. " pts"
        local isChecked = self.saved.selectedPoints[pts] == true
        local index = AddCustomMenuItem(label, function() self:TogglePoints(pts) end, MENU_ADD_OPTION_CHECKBOX)
        if isChecked and ZO_Menu and ZO_Menu.items and ZO_Menu.items[index] and ZO_Menu.items[index].checkbox then
            ZO_CheckButton_SetChecked(ZO_Menu.items[index].checkbox)
        end
    end

    AddCustomMenuItem("Clear", function() self:ClearPointsFilters() end, MENU_ADD_OPTION_LABEL)
    ShowMenu(anchor)
end

function AF:CanTrackAchievements()
    return type(GetTrackedAchievement) == "function" and type(SetTrackedAchievement) == "function"
end

function AF:SetAchievementPinned(id, pinned)
    if not self:CanTrackAchievements() then return end

    if pinned then
        -- Check current game state: the achievement may have completed while the menu was open.
        if IsAchievementComplete(id) then return end
        SetTrackedAchievement(id)
        if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.SetAssistedAspiration and ZO_HUD_TRACKER_ASPIRATION then
            HUD_TRACKER_MANAGER:SetAssistedAspiration(ZO_HUD_TRACKER_ASPIRATION.ACHIEVEMENT)
        end
    elseif GetTrackedAchievement() == id then
        -- Do not unpin a different achievement selected after this menu was opened.
        SetTrackedAchievement(0)
    end
    self:QueueRefresh()
end

function AF:OpenAchievement(id)
    if ACHIEVEMENTS and ACHIEVEMENTS.ShowAchievement then
        -- The standard UI also handles opening its scene and selecting the correct line stage.
        ACHIEVEMENTS:ShowAchievement(id)
    end
end

function AF:ShowAchievementMenu(anchor, id)
    ClearMenu()
    AddCustomMenuItem(self.LABELS.OPEN_ACHIEVEMENT, function() self:OpenAchievement(id) end, MENU_ADD_OPTION_LABEL)

    if self:CanTrackAchievements() then
        local isPinned = GetTrackedAchievement() == id
        if isPinned or not IsAchievementComplete(id) then
            -- Keep all actions in the add-on's UI language, independent of the game's language.
            local label = isPinned and self.LABELS.UNPIN_ACHIEVEMENT or self.LABELS.PIN_ACHIEVEMENT
            AddCustomMenuItem(label, function() self:SetAchievementPinned(id, not isPinned) end, MENU_ADD_OPTION_LABEL)
        end
    end
    ShowMenu(anchor)
end

function AF:OnRowMouseUp(anchor, data, button, upInside)
    if not upInside or not data then return end
    if button == MOUSE_BUTTON_INDEX_LEFT then
        self:OpenAchievement(data.id)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        self:ShowAchievementMenu(anchor, data.id)
    end
end

-- Simple case-insensitive contains helper
local function AF_StringContains(text, query)
    if not query or query == "" then return true end
    if not text or text == "" then return false end
    return string.find(zo_strlower(text), zo_strlower(query), 1, true) ~= nil
end
-- Grammar-aware format helper that resolves tokens and strips ESO grammar suffixes (^m/^f/^p)
local _AF_FORMAT_CACHE = {}
local function AF_Format(text)
    if not text or text == "" then return text or "" end
    local cached = _AF_FORMAT_CACHE[text]
    if cached then return cached end
    local out = text
    -- First, resolve any embedded tokens in the string itself
    local ok1, tmp = pcall(zo_strformat, out)
    if ok1 and tmp then out = tmp end
    -- Then, normalize and strip grammar markers like ^f/^m/^p using "<<1>>"
    local ok2, stripped = pcall(zo_strformat, "<<1>>", out)
    if ok2 and stripped then out = stripped end
    _AF_FORMAT_CACHE[text] = out
    return out
end

local function AF_ParseDateToKey(dateStr)
    if not dateStr or dateStr == "" then return nil end
    -- Try ISO-like YYYY-MM-DD or YY-MM-DD
    local y, m, d = dateStr:match("^(%d+)%-(%d+)%-(%d+)")
    if y and m and d then
        local yy = tonumber(y)
        local mm = tonumber(m)
        local dd = tonumber(d)
        if not yy or not mm or not dd then return nil end
        if yy < 100 then yy = 2000 + yy end
        return yy * 10000 + mm * 100 + dd
    end
    -- Try European DD.MM.YYYY or DD.MM.YY
    local d2, m2, y2 = dateStr:match("^(%d+)%.(%d+)%.(%d+)")
    if d2 and m2 and y2 then
        local yy = tonumber(y2)
        local mm = tonumber(m2)
        local dd = tonumber(d2)
        if not yy or not mm or not dd then return nil end
        if yy < 100 then yy = 2000 + yy end
        return yy * 10000 + mm * 100 + dd
    end
    -- Try US MM/DD/YYYY or MM/DD/YY
    local m3, d3, y3 = dateStr:match("^(%d+)%/(%d+)%/(%d+)")
    if m3 and d3 and y3 then
        local yy = tonumber(y3)
        local mm = tonumber(m3)
        local dd = tonumber(d3)
        if not yy or not mm or not dd then return nil end
        if yy < 100 then yy = 2000 + yy end
        return yy * 10000 + mm * 100 + dd
    end
    return nil
end

local function AF_DateKeyToYMD(key)
    if not key then return nil end
    local y = math.floor(key / 10000)
    local m = math.floor((key % 10000) / 100)
    local d = key % 100
    return y, m, d
end

local function AF_YMDToDateKey(y, m, d)
    return (y * 10000) + (m * 100) + d
end

local function AF_IsLeapYear(y)
    return (y % 4 == 0) and ((y % 100 ~= 0) or (y % 400 == 0))
end

local function AF_DaysInMonth(y, m)
    if m == 1 or m == 3 or m == 5 or m == 7 or m == 8 or m == 10 or m == 12 then
        return 31
    elseif m == 4 or m == 6 or m == 9 or m == 11 then
        return 30
    elseif m == 2 then
        return AF_IsLeapYear(y) and 29 or 28
    end
    return 30
end

local function AF_AddDays(y, m, d, deltaDays)
    if deltaDays == 0 then return y, m, d end
    local step = deltaDays > 0 and 1 or -1
    local count = math.abs(deltaDays)
    for _ = 1, count do
        d = d + step
        if step > 0 then
            local dim = AF_DaysInMonth(y, m)
            if d > dim then
                d = 1
                m = m + 1
                if m > 12 then
                    m = 1
                    y = y + 1
                end
            end
        else
            if d < 1 then
                m = m - 1
                if m < 1 then
                    m = 12
                    y = y - 1
                end
                d = AF_DaysInMonth(y, m)
            end
        end
    end
    return y, m, d
end

local function AF_GetTodayYMD()
    if type(GetTimeStamp) ~= "function" then return nil end
    local okStamp, stamp = pcall(GetTimeStamp)
    if not okStamp or not stamp or stamp <= 0 then return nil end

    if type(GetDateStringFromTimestamp) == "function" then
        local okDate, dateStr = pcall(GetDateStringFromTimestamp, stamp)
        if okDate and dateStr and dateStr ~= "" then
            local key = AF_ParseDateToKey(dateStr)
            if key then
                return AF_DateKeyToYMD(key)
            end
        end
    end

    return nil
end

local function AF_ComputePresetDateRange(presetKey)
    -- Returns fromKey, toKey (numeric YYYYMMDD) for given preset.
    -- If both values are nil, the date filter will be disabled.
    local todayY, todayM, todayD = AF_GetTodayYMD()
    if not todayY then
        return nil, nil
    end

    if presetKey == "ANY" or presetKey == nil then
        return nil, nil
    elseif presetKey == "TODAY" then
        local key = AF_YMDToDateKey(todayY, todayM, todayD)
        return key, key
    elseif presetKey == "LAST_7" then
        local y2, m2, d2 = AF_AddDays(todayY, todayM, todayD, -6)
        return AF_YMDToDateKey(y2, m2, d2), AF_YMDToDateKey(todayY, todayM, todayD)
    elseif presetKey == "LAST_30" then
        local y2, m2, d2 = AF_AddDays(todayY, todayM, todayD, -29)
        return AF_YMDToDateKey(y2, m2, d2), AF_YMDToDateKey(todayY, todayM, todayD)
    elseif presetKey == "THIS_MONTH" then
        local first = AF_YMDToDateKey(todayY, todayM, 1)
        local lastDay = AF_DaysInMonth(todayY, todayM)
        local last = AF_YMDToDateKey(todayY, todayM, lastDay)
        return first, last
    elseif presetKey == "LAST_MONTH" then
        local year, month = todayY, todayM - 1
        if month <= 0 then
            month = 12
            year = year - 1
        end
        local first = AF_YMDToDateKey(year, month, 1)
        local lastDay = AF_DaysInMonth(year, month)
        local last = AF_YMDToDateKey(year, month, lastDay)
        return first, last
    elseif presetKey == "THIS_YEAR" then
        return AF_YMDToDateKey(todayY, 1, 1), AF_YMDToDateKey(todayY, 12, 31)
    elseif presetKey == "LAST_YEAR" then
        local year = todayY - 1
        return AF_YMDToDateKey(year, 1, 1), AF_YMDToDateKey(year, 12, 31)
    elseif presetKey == "OLDER_THAN_YEAR" then
        local y2, m2, d2 = AF_AddDays(todayY, todayM, todayD, -365)
        return nil, AF_YMDToDateKey(y2, m2, d2)
    end

    return nil, nil
end


function AF:CreatePanelUI()
    if self.ui.window then return end
    local wm = WINDOW_MANAGER

    local wnd = wm:CreateTopLevelWindow("AchievementFilter_Window")
    wnd:SetHidden(true)
    wnd:SetDimensions(1600, 750)
    wnd:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    wnd:SetMovable(true)
    wnd:SetMouseEnabled(true)
    wnd:SetClampedToScreen(true)

    -- Simple backdrop so the window isn't transparent
    local bg = CreateControlFromVirtual("$(parent)BG", wnd, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(wnd)

    local title = wm:CreateControl("$(parent)Title", wnd, CT_LABEL)
    title:SetFont("ZoFontWinH1")
    title:SetText("Achievement Filter")
    title:SetAnchor(TOPLEFT, wnd, TOPLEFT, 16, 12)

    local close = CreateControlFromVirtual("$(parent)Close", wnd, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, wnd, TOPRIGHT, -8, 8)
    close:SetHandler("OnClicked", function()
        if self.scene and SCENE_MANAGER then
            SCENE_MANAGER:Hide("achievementFilterScene")
        else
            wnd:SetHidden(true)
        end
    end)

    -- Filters container
    local filters = wm:CreateControl("$(parent)Filters", wnd, CT_CONTROL)
    filters:SetAnchor(TOPLEFT, wnd, TOPLEFT, 16, 50)
    filters:SetAnchor(TOPRIGHT, wnd, TOPRIGHT, -16, 50)
    filters:SetHeight(110)

    -- Row 1: Reward, earned, pinned, points and date filters, plus Clear.
    local rewardBtn = CreateControlFromVirtual("$(parent)RewardBtn", filters, "ZO_DefaultButton")
    rewardBtn:SetDimensions(160, 26)
    rewardBtn:SetAnchor(TOPLEFT, filters, TOPLEFT, 0, 0)
    rewardBtn:SetText(self.LABELS.FILTERS)
    rewardBtn:SetHandler("OnClicked", function(btn)
        self:ShowRewardMenu(btn); self:RefreshResults()
    end)

    local earnedBoxContainer = CreateControlFromVirtual("$(parent)Earned", filters, "ZO_ComboBox")
    earnedBoxContainer:SetDimensions(160, 26)
    earnedBoxContainer:SetAnchor(TOPLEFT, rewardBtn, TOPRIGHT, 8, 0)
    local earnedCombo = ZO_ComboBox_ObjectFromContainer(earnedBoxContainer)
    earnedCombo:SetSortsItems(false)
    local function MakeEarnedItem(text, key)
        local entry = ZO_ComboBox:CreateItemEntry(text, function()
            self.saved.earnedFilter = key
            self:RefreshResults()
        end)
        earnedCombo:AddItem(entry)
        if self.saved.earnedFilter == key then
            earnedCombo:SelectItem(entry)
        end
    end
    MakeEarnedItem("All", "ALL")
    MakeEarnedItem("Earned", "EARNED")
    MakeEarnedItem("Unearned", "UNEARNED")

    local pinnedBoxContainer = CreateControlFromVirtual("$(parent)Pinned", filters, "ZO_ComboBox")
    pinnedBoxContainer:SetDimensions(180, 26)
    pinnedBoxContainer:SetAnchor(TOPLEFT, earnedBoxContainer, TOPRIGHT, 8, 0)
    local pinnedCombo = ZO_ComboBox_ObjectFromContainer(pinnedBoxContainer)
    pinnedCombo:SetSortsItems(false)
    local function MakePinnedItem(text, key)
        local entry = ZO_ComboBox:CreateItemEntry(text, function()
            self.saved.pinnedFilter = key
            self:RefreshResults()
        end)
        pinnedCombo:AddItem(entry)
        if (self.saved.pinnedFilter or "ALL") == key then
            pinnedCombo:SelectItem(entry)
        end
    end
    MakePinnedItem("Any pin status", "ALL")
    MakePinnedItem("Pinned only", "PINNED")
    MakePinnedItem("Not pinned", "UNPINNED")

    -- Points filter button
    local pointsBtn = CreateControlFromVirtual("$(parent)PointsBtn", filters, "ZO_DefaultButton")
    pointsBtn:SetDimensions(140, 26)
    pointsBtn:SetAnchor(TOPLEFT, pinnedBoxContainer, TOPRIGHT, 8, 0)
    pointsBtn:SetText("Points")
    pointsBtn:SetHandler("OnClicked", function(btn)
        self:ShowPointsMenu(btn)
        self:RefreshResults()
    end)

    local clearBtn = CreateControlFromVirtual("$(parent)ClearBtn", filters, "ZO_DefaultButton")
    clearBtn:SetDimensions(120, 26)
    -- Move clear button to the right edge of the filters row
    clearBtn:SetAnchor(TOPRIGHT, filters, TOPRIGHT, 0, 0)
    clearBtn:SetText(self.LABELS.CLEAR)
    clearBtn:SetHandler("OnClicked", function()
        ZO_ClearTable(self.saved.selectedRewards)
        ZO_ClearTable(self.saved.selectedPoints)
        self.saved.earnedFilter = "ALL"
        self.saved.pinnedFilter = "ALL"
        self.saved.searchTitle = ""
        self.saved.searchDescription = ""
        self.saved.searchSource = ""
        self.saved.searchReward = ""
        self.saved.dateFrom = nil
        self.saved.dateTo = nil
        self.saved.finishedPreset = "ANY"
        self:RefreshResults()
        -- Reset UI fields
        if self.ui.titleEdit then self.ui.titleEdit:SetText("") end
        if self.ui.sourceEdit then self.ui.sourceEdit:SetText("") end
        if self.ui.descEdit then self.ui.descEdit:SetText("") end
        if self.ui.rewardEdit then self.ui.rewardEdit:SetText("") end
        if earnedCombo then earnedCombo:SelectItemByIndex(1) end
        if pinnedCombo then pinnedCombo:SelectItemByIndex(1) end
        if self.ui.finishedCombo then self.ui.finishedCombo:SelectItemByIndex(1) end
        if self.ui.customDateFromEdit then
            self.ui.customDateFromEdit:SetText("")
            self.ui.customDateFromEdit:SetColor(1, 1, 1, 1)
        end
        if self.ui.customDateToEdit then
            self.ui.customDateToEdit:SetText("")
            self.ui.customDateToEdit:SetColor(1, 1, 1, 1)
        end
        if self.ui.customDateFromBg then self.ui.customDateFromBg:SetHidden(true) end
        if self.ui.customDateToBg then self.ui.customDateToBg:SetHidden(true) end
    end)

    -- Finished presets dropdown and optional custom range fields
    local finishedContainer = CreateControlFromVirtual("$(parent)Finished", filters, "ZO_ComboBox")
    finishedContainer:SetDimensions(200, 26)
    -- Anchor the finished presets next to the points button
    finishedContainer:SetAnchor(TOPLEFT, pointsBtn, TOPRIGHT, 8, 0)
    local finishedCombo = ZO_ComboBox_ObjectFromContainer(finishedContainer)
    finishedCombo:SetSortsItems(false)

    local function AddFinishedItem(label, presetKey)
        local entry = ZO_ComboBox:CreateItemEntry(label, function()
            self:OnFinishedPresetSelected(presetKey)
        end)
        finishedCombo:AddItem(entry)
        if self.saved.finishedPreset == presetKey then
            finishedCombo:SelectItem(entry)
        end
    end

    AddFinishedItem("Any time", "ANY")
    AddFinishedItem("Today", "TODAY")
    AddFinishedItem("Last 7 days", "LAST_7")
    AddFinishedItem("Last 30 days", "LAST_30")
    AddFinishedItem("This month", "THIS_MONTH")
    AddFinishedItem("Last month", "LAST_MONTH")
    AddFinishedItem("This year", "THIS_YEAR")
    AddFinishedItem("Last year", "LAST_YEAR")
    AddFinishedItem("Older than 1 year", "OLDER_THAN_YEAR")
    AddFinishedItem("Custom range...", "CUSTOM")

    -- Custom range date edits (hidden unless "Custom range..." is selected)
    local customDateFromBg = CreateControlFromVirtual("$(parent)CustomDateFromBG", filters, "ZO_EditBackdrop")
    customDateFromBg:SetDimensions(160, 26)
    customDateFromBg:SetAnchor(TOPLEFT, finishedContainer, TOPRIGHT, 8, 0)
    customDateFromBg:SetHidden(true)
    local customDateFromEdit = CreateControlFromVirtual("$(parent)CustomDateFromEdit", customDateFromBg,
        "ZO_DefaultEditForBackdrop")
    customDateFromEdit:SetAnchorFill(customDateFromBg)
    customDateFromEdit:SetMaxInputChars(20)

    local customDateToBg = CreateControlFromVirtual("$(parent)CustomDateToBG", filters, "ZO_EditBackdrop")
    customDateToBg:SetDimensions(160, 26)
    customDateToBg:SetAnchor(TOPLEFT, customDateFromBg, TOPRIGHT, 8, 0)
    customDateToBg:SetHidden(true)
    local customDateToEdit = CreateControlFromVirtual("$(parent)CustomDateToEdit", customDateToBg,
        "ZO_DefaultEditForBackdrop")
    customDateToEdit:SetAnchorFill(customDateToBg)
    customDateToEdit:SetMaxInputChars(20)

    local function ShowDateTooltip(control)
        InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, -2)
        SetTooltipText(InformationTooltip, "Accepted formats: 2025-10-30, 30.10.2025, 10/30/2025")
    end
    local function HideDateTooltip()
        ClearTooltip(InformationTooltip)
    end

    customDateFromEdit:SetHandler("OnMouseEnter", function(control) ShowDateTooltip(control) end)
    customDateFromEdit:SetHandler("OnMouseExit", function() HideDateTooltip() end)
    customDateToEdit:SetHandler("OnMouseEnter", function(control) ShowDateTooltip(control) end)
    customDateToEdit:SetHandler("OnMouseExit", function() HideDateTooltip() end)

    customDateFromEdit:SetHandler("OnTextChanged", function(edit)
        self:OnCustomDateTextChanged(edit, true)
    end)
    customDateToEdit:SetHandler("OnTextChanged", function(edit)
        self:OnCustomDateTextChanged(edit, false)
    end)

    -- Allow TAB in the "from" date field to jump to the "to" date field
    customDateFromEdit:SetHandler("OnTab", function(control)
        if self.ui and self.ui.customDateToEdit and not IsShiftKeyDown() then
            self.ui.customDateToEdit:TakeFocus()
        end
    end)

    -- Allow Shift+TAB in the "to" date field to jump back to the "from" date field
    customDateToEdit:SetHandler("OnTab", function(control)
        if self.ui and self.ui.customDateFromEdit and IsShiftKeyDown() then
            self.ui.customDateFromEdit:TakeFocus()
        end
    end)

    -- Row 2: Title, Source, Description, Reward text search edits
    -- Add a backdrop to make the Title search box more visible
    local titleBg = CreateControlFromVirtual("$(parent)TitleEditBG", filters, "ZO_EditBackdrop")
    titleBg:SetDimensions(260, 26)
    titleBg:SetAnchor(TOPLEFT, filters, TOPLEFT, 0, 36)
    local titleEdit = CreateControlFromVirtual("$(parent)TitleEdit", titleBg, "ZO_DefaultEditForBackdrop")
    titleEdit:SetAnchorFill(titleBg)
    titleEdit:SetMaxInputChars(100)
    titleEdit:SetText(self.saved.searchTitle or "")
    titleEdit:SetDefaultText("Title")
    titleEdit:SetHandler("OnTextChanged", function(c)
        self.saved.searchTitle = c:GetText()
        self:RefreshResults()
    end)
    -- TAB navigation: Title -> Source
    titleEdit:SetHandler("OnTab", function(control)
        if self.ui and self.ui.sourceEdit and not IsShiftKeyDown() then
            self.ui.sourceEdit:TakeFocus()
        end
    end)

    -- Source search box
    local sourceBg = CreateControlFromVirtual("$(parent)SourceEditBG", filters, "ZO_EditBackdrop")
    sourceBg:SetDimensions(260, 26)
    sourceBg:SetAnchor(TOPLEFT, titleBg, TOPRIGHT, 8, 0)
    local sourceEdit = CreateControlFromVirtual("$(parent)SourceEdit", sourceBg, "ZO_DefaultEditForBackdrop")
    sourceEdit:SetAnchorFill(sourceBg)
    sourceEdit:SetMaxInputChars(200)
    sourceEdit:SetText(self.saved.searchSource or "")
    sourceEdit:SetDefaultText("Source")
    sourceEdit:SetHandler("OnTextChanged", function(c)
        self.saved.searchSource = c:GetText()
        self:RefreshResults()
    end)
    -- TAB navigation: Title <-> Source <-> Description
    sourceEdit:SetHandler("OnTab", function(control)
        if IsShiftKeyDown() then
            if self.ui and self.ui.titleEdit then
                self.ui.titleEdit:TakeFocus()
            end
        else
            if self.ui and self.ui.descEdit then
                self.ui.descEdit:TakeFocus()
            end
        end
    end)

    -- Add a backdrop to make the Description search box more visible
    local descBg = CreateControlFromVirtual("$(parent)DescEditBG", filters, "ZO_EditBackdrop")
    descBg:SetDimensions(260, 26)
    descBg:SetAnchor(TOPLEFT, sourceBg, TOPRIGHT, 8, 0)
    local descEdit = CreateControlFromVirtual("$(parent)DescEdit", descBg, "ZO_DefaultEditForBackdrop")
    descEdit:SetAnchorFill(descBg)
    descEdit:SetMaxInputChars(200)
    descEdit:SetText(self.saved.searchDescription or "")
    descEdit:SetDefaultText("Description")
    descEdit:SetHandler("OnTextChanged", function(c)
        self.saved.searchDescription = c:GetText()
        self:RefreshResults()
    end)
    descEdit:SetHandler("OnTab", function(control)
        if IsShiftKeyDown() then
            if self.ui and self.ui.sourceEdit then
                self.ui.sourceEdit:TakeFocus()
            end
        else
            if self.ui and self.ui.rewardEdit then
                self.ui.rewardEdit:TakeFocus()
            end
        end
    end)

    -- Add a backdrop to make the Reward search box more visible
    local rewardBg = CreateControlFromVirtual("$(parent)RewardEditBG", filters, "ZO_EditBackdrop")
    rewardBg:SetDimensions(260, 26)
    rewardBg:SetAnchor(TOPLEFT, descBg, TOPRIGHT, 8, 0)
    local rewardEdit = CreateControlFromVirtual("$(parent)RewardEdit", rewardBg, "ZO_DefaultEditForBackdrop")
    rewardEdit:SetAnchorFill(rewardBg)
    rewardEdit:SetMaxInputChars(100)
    rewardEdit:SetText(self.saved.searchReward or "")
    rewardEdit:SetDefaultText("Reward")
    rewardEdit:SetHandler("OnTextChanged", function(c)
        self.saved.searchReward = c:GetText()
        self:RefreshResults()
    end)
    rewardEdit:SetHandler("OnTab", function(control)
        if IsShiftKeyDown() then
            if self.ui and self.ui.descEdit then
                self.ui.descEdit:TakeFocus()
            end
        end
    end)

    -- Total points label (absolute, not affected by filters)
    local totalPointsLabel = wm:CreateControl("$(parent)TotalPointsLabel", wnd, CT_LABEL)
    totalPointsLabel:SetFont("ZoFontGame")
    totalPointsLabel:SetDimensions(360, 26)
    totalPointsLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    totalPointsLabel:SetAnchor(TOPRIGHT, filters, TOPRIGHT, 0, 36)

    -- Result count label
    local countLabel = wm:CreateControl("$(parent)CountLabel", wnd, CT_LABEL)
    countLabel:SetFont("ZoFontGame")
    countLabel:SetDimensions(120, 26)
    countLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    countLabel:SetAnchor(TOPRIGHT, totalPointsLabel, TOPLEFT, -16, 0)

    -- Table header (labels)
    local header = wm:CreateControl("$(parent)Header", wnd, CT_CONTROL)
    header:SetAnchor(TOPLEFT, filters, BOTTOMLEFT, 0, 12)
    header:SetAnchor(TOPRIGHT, filters, BOTTOMRIGHT, -16, 12)
    header:SetHeight(24)
    -- Column x positions tuned for 1600px-wide window
    local xTitle, xSource, xType, xName, xPoints, xProg, xStatus = 36, 390, 700, 820, 1250, 1310, 1470
    local function MakeHdr(name, text, x, w, sortKey, alignRight)
        local lbl = wm:CreateControl("$(parent)" .. name, header, CT_LABEL)
        lbl:SetFont("ZoFontGameBold")
        lbl:SetText(text)
        lbl:SetAnchor(TOPLEFT, header, TOPLEFT, x, 0)
        lbl:SetDimensions(w, 24)
        if alignRight then lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
        if sortKey then
            lbl:SetMouseEnabled(true)
            lbl:SetHandler("OnMouseUp", function(_, button, upInside)
                if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
                    self:SetSort(sortKey)
                end
            end)
        end
        return lbl
    end
    MakeHdr("TitleH", "Title", xTitle, 350, "title")
    MakeHdr("SourceH", "Source", xSource, 300, "source")
    MakeHdr("TypeH", "Reward Type", xType, 110, "rewardType")
    MakeHdr("NameH", "Reward Name", xName, 420, "rewardName")
    MakeHdr("PointsH", "Pts", xPoints, 50, "points", true)
    MakeHdr("ProgH", "Prog", xProg, 130, "progress")
    MakeHdr("StatusH", "Finished", xStatus, 90, "finished")

    -- Permanent description area for the row currently under the mouse cursor
    local descriptionPanel = wm:CreateControl("$(parent)DescriptionPanel", wnd, CT_CONTROL)
    descriptionPanel:SetAnchor(BOTTOMLEFT, wnd, BOTTOMLEFT, 16, -16)
    descriptionPanel:SetAnchor(BOTTOMRIGHT, wnd, BOTTOMRIGHT, -16, -16)
    descriptionPanel:SetHeight(96)

    local descriptionBg = CreateControlFromVirtual("$(parent)BG", descriptionPanel, "ZO_DefaultBackdrop")
    descriptionBg:SetAnchorFill(descriptionPanel)

    local descriptionLabel = wm:CreateControl("$(parent)DescriptionText", descriptionPanel, CT_LABEL)
    descriptionLabel:SetFont("ZoFontGame")
    descriptionLabel:SetColor(0.86, 0.82, 0.72, 1)
    descriptionLabel:SetMaxLineCount(3)
    descriptionLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    descriptionLabel:SetAnchor(TOPLEFT, descriptionPanel, TOPLEFT, 8, 6)
    descriptionLabel:SetAnchor(BOTTOMRIGHT, descriptionPanel, BOTTOMRIGHT, -8, -6)
    local rowHint = "Left-click to open an achievement. Right-click to pin or unpin it on the HUD."
    descriptionLabel:SetText(rowHint)

    -- Results table list
    local list = CreateControlFromVirtual("$(parent)List", wnd, "ZO_ScrollList")
    list:ClearAnchors()
    list:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 6)
    list:SetAnchor(BOTTOMRIGHT, descriptionPanel, TOPRIGHT, 0, -8)
    local function SetRowHover(control, data, isHovered)
        local hover = control:GetNamedChild("Hover")
        if hover then
            hover:SetHidden(not isHovered)
        end

        if isHovered then
            if self.ui.hoveredRow and self.ui.hoveredRow ~= control then
                local oldHover = self.ui.hoveredRow:GetNamedChild("Hover")
                if oldHover then
                    oldHover:SetHidden(true)
                end
            end
            self.ui.hoveredRow = control
            descriptionLabel:SetText(data.description or "")
        elseif self.ui.hoveredRow == control then
            self.ui.hoveredRow = nil
            descriptionLabel:SetText(rowHint)
        end
    end

    -- Row height increased to 40 to allow multiple lines in the reward name column
    ZO_ScrollList_AddDataType(list, 2, "AchievementFilterTableRow", 40, function(control, data)
        local hover = control:GetNamedChild("Hover")
        if hover then
            hover:SetColor(1, 1, 1, 0.25)
            hover:SetDrawLayer(DL_BACKGROUND)
            hover:SetHidden(true)
        end

        local icon = control:GetNamedChild("Icon")
        if icon and data.icon then icon:SetTexture(data.icon) end
        local titleCtrl = control:GetNamedChild("Title"); if titleCtrl then titleCtrl:SetText(data.title or "") end
        local src = control:GetNamedChild("Source"); if src then src:SetText(data.source or "") end
        local rtype = control:GetNamedChild("RewardType"); if rtype then rtype:SetText(data.rewardType or "") end
        local rname = control:GetNamedChild("RewardName")
        if rname then
            rname:SetMaxLineCount(1)
            rname:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            rname:SetText(data.rewardName or "")
            rname:SetMouseEnabled(true)

            -- Show full reward details in a tooltip when there are multiple rewards
            rname:SetHandler("OnMouseEnter", function(ctrl)
                SetRowHover(control, data, true)
                if data.rewardTooltip and data.rewardTooltip ~= "" and data.rewardTooltip ~= data.rewardName then
                    -- Anchor the tooltip based on the panel top-left + Reward Name column x offset
                    local offsetY = ctrl:GetTop() - header:GetTop()
                    InitializeTooltip(InformationTooltip, header, TOPLEFT, xName + 70, offsetY - 2, TOPLEFT)
                    SetTooltipText(InformationTooltip, data.rewardTooltip)
                end
            end)
            rname:SetHandler("OnMouseExit", function()
                ClearTooltip(InformationTooltip)
                if not MouseIsOver(control) then
                    SetRowHover(control, data, false)
                end
            end)

            -- Both mouse actions also work directly on the reward name.
            rname:SetHandler("OnMouseUp", function(ctrl, button, upInside)
                self:OnRowMouseUp(ctrl, control.data, button, upInside)
            end)
        end
        local pts = control:GetNamedChild("Points"); if pts then pts:SetText(tostring(data.points or "")) end
        local prog = control:GetNamedChild("Progress"); if prog then prog:SetText(data.progress or "") end
        local status = control:GetNamedChild("Status"); if status then status:SetText(data.status or "") end
        control.data = data
        control:SetHandler("OnMouseEnter", function(ctrl)
            SetRowHover(ctrl, ctrl.data, true)
        end)
        control:SetHandler("OnMouseExit", function(ctrl)
            if not MouseIsOver(ctrl) then
                SetRowHover(ctrl, ctrl.data, false)
            end
        end)
        control:SetHandler("OnMouseUp", function(ctrl, button, upInside)
            self:OnRowMouseUp(ctrl, ctrl.data, button, upInside)
        end)
        if MouseIsOver(control) then
            SetRowHover(control, data, true)
        end
    end)
    self.ui.header = header

    -- Save references
    self.ui.window = wnd
    self.ui.filters = filters
    self.ui.rewardBtn = rewardBtn
    self.ui.earnedCombo = earnedCombo
    self.ui.pinnedCombo = pinnedCombo
    self.ui.finishedCombo = finishedCombo
    self.ui.customDateFromBg = customDateFromBg
    self.ui.customDateFromEdit = customDateFromEdit
    self.ui.customDateToBg = customDateToBg
    self.ui.customDateToEdit = customDateToEdit
    self.ui.titleEdit = titleEdit
    self.ui.sourceEdit = sourceEdit
    self.ui.descEdit = descEdit
    self.ui.rewardEdit = rewardEdit
    self.ui.countLabel = countLabel
    self.ui.totalPointsLabel = totalPointsLabel
    self.ui.descriptionPanel = descriptionPanel
    self.ui.descriptionLabel = descriptionLabel
    self.ui.rowHint = rowHint
    self.ui.list = list

    -- Apply the saved "Finished" preset and update custom range UI
    self:OnFinishedPresetSelected(self.saved.finishedPreset or "ANY")
    -- Scene & fragment so the panel behaves like a proper window and closes with ESC
    local fragment = ZO_FadeSceneFragment:New(wnd)
    local scene = ZO_Scene:New("achievementFilterScene", SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
    scene:AddFragment(fragment)
    self.scene = scene
    self.sceneFragment = fragment
end

function AF:EnsureMasterList()
    if self.masterList then return end
    local ok, err = pcall(function() self:BuildMasterList() end)
    if not ok then
        d("AchievementFilter: failed to build list: " .. tostring(err))
        self.masterList = {}
    end
end

function AF:BuildMasterList()
    local list = {}
    local entriesById = {}
    local totalPoints = 0
    local totalPointsEarned = 0
    local totalAchievements = 0
    local totalAchievementsCompleted = 0
    -- Clear and rebuild derived sets
    ZO_ClearTable(self.pointsSet)
    ZO_ClearTable(self.datesSet)

    local function addEntry(id, sourcePath)
        sourcePath = sourcePath or ""

        local existing = entriesById[id]
        if existing then
            local sourceKey = zo_strlower(sourcePath)
            if sourcePath ~= "" and not existing.sourcePathsByLower[sourceKey] then
                existing.sourcePathsByLower[sourceKey] = true
                if existing.sourcePath ~= "" then
                    existing.sourcePath = string.format("%s; %s", existing.sourcePath, sourcePath)
                else
                    existing.sourcePath = sourcePath
                end
                existing.sourceLower = zo_strlower(existing.sourcePath)
            end
            return
        end

        local name, desc, points, icon, completed = GetAchievementInfo(id)
        name = AF_Format(name)
        desc = AF_Format(desc)
        totalAchievements = totalAchievements + 1
        if completed then
            totalAchievementsCompleted = totalAchievementsCompleted + 1
        end

        -- Track unique point values and totals
        if points and points > 0 then
            self.pointsSet[points] = true
            totalPoints = totalPoints + points
            if completed then
                totalPointsEarned = totalPointsEarned + points
            end
        end
        -- Build reward names and types separately
        local rewardNameParts, rewardTypeParts = {}, {}

        -- Title reward
        local hasTitle, titleName = GetAchievementRewardTitle(id)
        if hasTitle and titleName and titleName ~= "" then
            local formatted = AF_Format(titleName)
            table.insert(rewardNameParts, string.format("%s: %s", self.LABELS.TITLE, formatted))
            table.insert(rewardTypeParts, self.LABELS.TITLE)
        end

        -- Item reward
        local hasItem, itemName = GetAchievementRewardItem(id)
        if hasItem and itemName and itemName ~= "" then
            local formatted = AF_Format(itemName)
            table.insert(rewardNameParts, string.format("%s: %s", self.LABELS.ITEM, formatted))
            table.insert(rewardTypeParts, self.LABELS.ITEM)
        end

        -- Collectible reward (e.g., mounts/pets) with category label like "Reittier"
        local hasCollectible, collectibleId = GetAchievementRewardCollectible(id)
        if hasCollectible and collectibleId and collectibleId ~= 0 then
            local collName = select(1, GetCollectibleInfo(collectibleId))
            local categoryType = GetCollectibleCategoryType(collectibleId)
            local categoryLabel
            if categoryType ~= nil and type(categoryType) == "number" then
                categoryLabel = GetString("SI_COLLECTIBLECATEGORYTYPE", categoryType)
            end
            local namePart = (collName and collName ~= "") and AF_Format(collName) or self.LABELS.COLLECTIBLE
            local prefix = (categoryLabel and categoryLabel ~= "") and AF_Format(categoryLabel) or
                self.LABELS.COLLECTIBLE
            table.insert(rewardNameParts, string.format("%s: %s", prefix, namePart))
            table.insert(rewardTypeParts, self.LABELS.COLLECTIBLE)
        end

        -- Dyes: try to resolve the dye name if the API is available; otherwise fall back to generic text
        local hasDye, dyeId = GetAchievementRewardDye(id)
        if hasDye then
            local dyeName
            if dyeId and dyeId ~= 0 then
                if type(GetDyeInfoById) == "function" then
                    local ok, n = pcall(function() return select(1, GetDyeInfoById(dyeId)) end)
                    if ok and n and n ~= "" then dyeName = n end
                end
                if not dyeName and type(GetDyeNameById) == "function" then
                    local ok2, n2 = pcall(GetDyeNameById, dyeId)
                    if ok2 and n2 and n2 ~= "" then dyeName = n2 end
                end
            end
            local formatted = AF_Format(dyeName or self.LABELS.DYE)
            table.insert(rewardNameParts, string.format("%s: %s", self.LABELS.DYE, formatted))
            table.insert(rewardTypeParts, self.LABELS.DYE)
        end

        -- Tribute card upgrades: show a generic label (API names vary by game version)
        local hasTribute = select(1, GetAchievementRewardTributeCardUpgradeInfo(id))
        if hasTribute then
            table.insert(rewardTypeParts, self.LABELS.TRIBUTE)
            table.insert(rewardNameParts, self.LABELS.TRIBUTE)
        end
        local numRewards = #rewardNameParts

        -- Reward name column: show a short label in the table, full details in tooltip/search
        local rewardNamesText = table.concat(rewardNameParts, "\n")
        local rewardTypesText = table.concat(rewardTypeParts, ", ")
        local rewardDisplayText
        if numRewards <= 1 then
            rewardDisplayText = rewardNamesText
        elseif numRewards > 1 then
            rewardDisplayText = self.LABELS.MULTIPLE or rewardNamesText
        end




        -- Compute progress across criteria and flatten criterion names into the displayed description
        local criteriaTextParts = {}
        local criteriaTextByLower = {}
        local nameLower = zo_strlower(name or "")
        local descLower = zo_strlower(desc or "")
        local progressText = ""
        local progressValue = 0
        local numCrit = GetAchievementNumCriteria(id)
        if numCrit and numCrit > 0 then
            local cur, max = 0, 0
            for idx = 1, numCrit do
                local criterionText, numCompleted, numRequired = GetAchievementCriterion(id, idx)
                criterionText = AF_Format(criterionText)
                if criterionText and criterionText ~= "" then
                    local criterionLower = zo_strlower(criterionText)
                    if criterionLower ~= descLower and criterionLower ~= nameLower and not criteriaTextByLower[criterionLower] then
                        criteriaTextByLower[criterionLower] = true
                        table.insert(criteriaTextParts, criterionText)
                    end
                end
                numCompleted = tonumber(numCompleted) or 0
                numRequired = tonumber(numRequired) or 0
                if numRequired > 0 then
                    cur = cur + math.min(numCompleted, numRequired)
                    max = max + numRequired
                else
                    max = max + 1
                    if numCompleted > 0 then cur = cur + 1 end
                end
            end
            if max > 0 then
                progressValue = cur / max
                local pct = math.floor(progressValue * 100 + 0.5)
                progressText = string.format("%d/%d (%d%%)", cur, max, pct)
            end
        end
        local displayDesc = desc or ""
        if #criteriaTextParts > 0 then
            local criteriaText = table.concat(criteriaTextParts, ", ")
            if displayDesc ~= "" then
                displayDesc = string.format("%s %s", displayDesc, criteriaText)
            else
                displayDesc = criteriaText
            end
        end

        -- Status: show date/time when completed (blank if open)
        local _, _, _, _, comp, dateStr = GetAchievementInfo(id)
        local statusText = ""
        local completionDateKey = nil
        if comp then
            statusText = AF_Format(dateStr or "")
            completionDateKey = AF_ParseDateToKey(dateStr)
            if completionDateKey then
                self.datesSet[completionDateKey] = statusText
                if not self.exampleDateText and dateStr and dateStr ~= "" then
                    local ex
                    local y1, m1, d1 = dateStr:match("^(%d+)%-(%d+)%-(%d+)")
                    if y1 and m1 and d1 then
                        ex = string.format("%s-%s-%s", y1, m1, d1)
                    else
                        local d2, m2, y2 = dateStr:match("^(%d+)%.(%d+)%.(%d+)")
                        if d2 and m2 and y2 then
                            ex = string.format("%s.%s.%s", d2, m2, y2)
                        else
                            local m3, d3, y3 = dateStr:match("^(%d+)%/(%d+)%/(%d+)")
                            if m3 and d3 and y3 then
                                ex = string.format("%s/%s/%s", m3, d3, y3)
                            end
                        end
                    end
                    self.exampleDateText = ex
                end
            end
        end

        local rewardText = rewardNamesText
        local entry = {
            id = id,
            name = name or "",
            nameLower = zo_strlower(name or ""),
            desc = displayDesc,
            descLower = zo_strlower(displayDesc or ""),
            points = points or 0,
            icon = icon,
            completed = completed == true,
            sourcePath = sourcePath,
            sourceLower = zo_strlower(sourcePath),
            sourcePathsByLower = { [zo_strlower(sourcePath)] = true },
            rewardText = rewardText,
            rewardTextLower = zo_strlower(rewardText or ""),
            rewardNamesText = rewardNamesText,
            rewardTypesText = rewardTypesText,
            rewardDisplayText = rewardDisplayText or rewardNamesText,
            rewardTooltipText = rewardNamesText,
            progressText = progressText,
            progressValue = progressValue,
            statusText = statusText,
            completionDateKey = completionDateKey,
        }
        table.insert(list, entry)
        entriesById[id] = entry
    end

    local numCats = GetNumAchievementCategories()
    for c = 1, numCats do
        local categoryName, numSub, numAch = GetAchievementCategoryInfo(c)
        categoryName = AF_Format(categoryName or ("Category " .. tostring(c)))
        numSub = numSub or 0
        numAch = numAch or 0
        for i = 1, numAch do
            local id = GetAchievementId(c, 0, i)
            if id and id > 0 then addEntry(id, categoryName) end
        end
        for s = 1, numSub do
            -- API uses SubCategory (capital C)
            local subName, numSubAch = GetAchievementSubCategoryInfo(c, s)
            local path = string.format("%s / %s", categoryName, AF_Format(subName or ("Sub " .. tostring(s))))
            numSubAch = numSubAch or 0
            for j = 1, numSubAch do
                local id = GetAchievementId(c, s, j)
                if id and id > 0 then addEntry(id, path) end
            end
        end
    end

    self.masterList = list
    self.totalPointsAll = totalPoints
    self.totalPointsEarned = totalPointsEarned
    self.totalAchievementsAll = totalAchievements
    self.totalAchievementsCompleted = totalAchievementsCompleted

    -- Update custom date placeholders now that we may know the player's date style
    self:UpdateCustomDatePlaceholders()
    self:UpdateTotalPointsLabel()
end

function AF:UpdateCustomDatePlaceholders()
    if not self.ui or not self.ui.customDateFromEdit or not self.ui.customDateToEdit then return end

    local example = self.exampleDateText or "YYYY-MM-DD"
    self.ui.customDateFromEdit:SetDefaultText(example)
    self.ui.customDateToEdit:SetDefaultText(example)
end

function AF:UpdateTotalPointsLabel()
    if self.ui and self.ui.totalPointsLabel and self.totalPointsAll then
        local earned = self.totalPointsEarned or 0
        local achievementsDone = self.totalAchievementsCompleted or 0
        local achievementsTotal = self.totalAchievementsAll or 0
        self.ui.totalPointsLabel:SetText(string.format("Done: %d/%d  Pts: %d/%d",
            achievementsDone, achievementsTotal, earned, self.totalPointsAll))
    end
end

function AF:OnFinishedPresetSelected(presetKey)
    self.saved.finishedPreset = presetKey

    if not self.ui then
        -- Still store the preset/date range even if UI is not ready yet.
        local fromKey, toKey = AF_ComputePresetDateRange(presetKey)
        self.saved.dateFrom = fromKey
        self.saved.dateTo = toKey
        return
    end

    local showCustom = (presetKey == "CUSTOM")

    if self.ui.customDateFromBg then
        self.ui.customDateFromBg:SetHidden(not showCustom)
    end
    if self.ui.customDateToBg then
        self.ui.customDateToBg:SetHidden(not showCustom)
    end

    if showCustom then
        self:UpdateCustomDatePlaceholders()

        if self.ui.customDateFromEdit then
            if self.saved.dateFrom then
                local y, m, d = AF_DateKeyToYMD(self.saved.dateFrom)
                if y and m and d then
                    self.ui.customDateFromEdit:SetText(string.format("%04d-%02d-%02d", y, m, d))
                else
                    self.ui.customDateFromEdit:SetText("")
                end
            else
                self.ui.customDateFromEdit:SetText("")
            end
            self.ui.customDateFromEdit:SetColor(1, 1, 1, 1)
        end

        if self.ui.customDateToEdit then
            if self.saved.dateTo then
                local y, m, d = AF_DateKeyToYMD(self.saved.dateTo)
                if y and m and d then
                    self.ui.customDateToEdit:SetText(string.format("%04d-%02d-%02d", y, m, d))
                else
                    self.ui.customDateToEdit:SetText("")
                end
            else
                self.ui.customDateToEdit:SetText("")
            end
            self.ui.customDateToEdit:SetColor(1, 1, 1, 1)
        end
    else
        local fromKey, toKey = AF_ComputePresetDateRange(presetKey)
        self.saved.dateFrom = fromKey
        self.saved.dateTo = toKey

        if self.ui.customDateFromEdit then
            self.ui.customDateFromEdit:SetText("")
            self.ui.customDateFromEdit:SetColor(1, 1, 1, 1)
        end
        if self.ui.customDateToEdit then
            self.ui.customDateToEdit:SetText("")
            self.ui.customDateToEdit:SetColor(1, 1, 1, 1)
        end
    end

    self:RefreshResults()
end

function AF:OnCustomDateTextChanged(edit, isFrom)
    if not edit then return end

    local text = edit:GetText()
    if text then
        text = text:match("^%s*(.-)%s*$")
    end
    if text == nil then text = "" end

    if text == "" then
        edit:SetColor(1, 1, 1, 1)
        if isFrom then
            self.saved.dateFrom = nil
        else
            self.saved.dateTo = nil
        end
        self:RefreshResults()
        return
    end

    local key = AF_ParseDateToKey(text)
    if key then
        edit:SetColor(1, 1, 1, 1)
        if isFrom then
            self.saved.dateFrom = key
        else
            self.saved.dateTo = key
        end
        self:RefreshResults()
    else
        -- Invalid input: mark in red and do not change the active filter.
        edit:SetColor(1, 0, 0, 1)
    end
end

function AF:PassesPanelFilters(entry, trackedId)
    -- The tracker ID is read once per refresh, so all rows use the same current state.
    local isPinned = entry.id == trackedId
    if self.saved.pinnedFilter == "PINNED" and not isPinned then return false end
    if self.saved.pinnedFilter == "UNPINNED" and isPinned then return false end

    -- Earned filter
    if self.saved.earnedFilter == "EARNED" and not entry.completed then return false end
    if self.saved.earnedFilter == "UNEARNED" and entry.completed then return false end

    -- Date range filter (only applies to completed achievements with a known date key)
    local fromKey = self.saved.dateFrom
    local toKey = self.saved.dateTo
    if (fromKey or toKey) then
        local k = entry.completionDateKey
        if not k then return false end
        if fromKey and k < fromKey then return false end
        if toKey and k > toKey then return false end
    end

    -- Text filters
    if not AF_StringContains(entry.nameLower, self.saved.searchTitle) then return false end
    if not AF_StringContains(entry.sourceLower, self.saved.searchSource) then return false end
    if not AF_StringContains(entry.descLower, self.saved.searchDescription) then return false end
    if not AF_StringContains(entry.rewardTextLower, self.saved.searchReward) then return false end

    -- Reward types OR logic across the achievement line
    if self:IsAnyRewardFilterSelected() then
        local info = self:GetLineRewardInfo(entry.id)
        local match = false
        for _, key in ipairs(self.REWARD_KEYS) do
            if self.saved.selectedRewards[key] and info[key] then
                match = true
                break
            end
        end
        if not match then return false end
    end

    -- Points filter OR logic
    if self:IsAnyPointsFilterSelected() then
        if not self.saved.selectedPoints[entry.points] then
            return false
        end
    end

    return true
end

function AF:SetSort(sortKey)
    if not self.saved then return end

    if self.saved.sortKey == sortKey then
        self.saved.sortAscending = not self.saved.sortAscending
    else
        self.saved.sortKey = sortKey
        self.saved.sortAscending = true
    end

    if self.ui and self.ui.list then
        self:RefreshResults()
    end
end

function AF:SortEntries(entries)
    if not self.saved or not entries or #entries <= 1 then return end

    local key = self.saved.sortKey or "title"
    local asc = (self.saved.sortAscending ~= false)

    local function ToLowerSafe(s)
        if not s or s == "" then return "" end
        return zo_strlower(s)
    end

    table.sort(entries, function(a, b)
        local av, bv

        if key == "title" then
            av, bv = a.nameLower, b.nameLower
        elseif key == "source" then
            av, bv = a.sourceLower, b.sourceLower
        elseif key == "rewardType" then
            av, bv = ToLowerSafe(a.rewardTypesText), ToLowerSafe(b.rewardTypesText)
        elseif key == "rewardName" then
            av, bv = a.rewardTextLower, b.rewardTextLower
        elseif key == "points" then
            av, bv = a.points or 0, b.points or 0
        elseif key == "progress" then
            av, bv = a.progressValue or 0, b.progressValue or 0
        elseif key == "finished" then
            -- Use a large sentinel so uncompleted achievements sort after completed ones in ascending order
            av = a.completionDateKey or 99999999
            bv = b.completionDateKey or 99999999
        else
            av, bv = a.id or 0, b.id or 0
        end

        if av == bv then
            return (a.id or 0) < (b.id or 0)
        end

        if asc then
            return av < bv
        else
            return av > bv
        end
    end)
end

function AF:RefreshResults()
    if not self.ui.list then return end
    -- Relative date filters follow the current day, including when reopening after midnight.
    if self.saved.finishedPreset ~= "CUSTOM" then
        self.saved.dateFrom, self.saved.dateTo = AF_ComputePresetDateRange(self.saved.finishedPreset)
    end
    self:EnsureMasterList()

    -- Clear list before repopulating to ensure rows are rebuilt
    ZO_ScrollList_Clear(self.ui.list)
    self.ui.hoveredRow = nil
    if self.ui.descriptionLabel then
        self.ui.descriptionLabel:SetText(self.ui.rowHint or "")
    end

    local dataList = ZO_ScrollList_GetDataList(self.ui.list)
    ZO_ClearNumericallyIndexedTable(dataList)

    -- Collect filtered entries first so we can apply sorting
    local trackedId = self:CanTrackAchievements() and GetTrackedAchievement() or 0
    local filtered = {}
    for _, entry in ipairs(self.masterList) do
        if self:PassesPanelFilters(entry, trackedId) then
            table.insert(filtered, entry)
        end
    end

    if #filtered > 1 then
        self:SortEntries(filtered)
    end

    local count = 0
    for _, entry in ipairs(filtered) do
        local rowData = {
            id = entry.id,
            icon = entry.icon,
            title = entry.name,
            source = entry.sourcePath or "",
            rewardType = entry.rewardTypesText or "",
            rewardName = entry.rewardDisplayText or entry.rewardNamesText or "",
            points = entry.points or 0,
            progress = entry.progressText or "",
            status = entry.statusText or "",
            description = entry.desc or "",
            rewardTooltip = entry.rewardTooltipText or entry.rewardNamesText or "",
        }
        table.insert(dataList, ZO_ScrollList_CreateDataEntry(2, rowData))
        count = count + 1
    end

    if self.ui.countLabel then
        self.ui.countLabel:SetText(string.format("%d results", count))
    end

    ZO_ScrollList_Commit(self.ui.list)
end

function AF:ShowWindow()
    self:CreatePanelUI()
    self:EnsureMasterList()
    self:RefreshResults()
    if self.scene and SCENE_MANAGER then
        SCENE_MANAGER:Show("achievementFilterScene")
    elseif self.ui.window then
        self.ui.window:SetHidden(false)
    end
end

function AF:IsWindowShowing()
    return self.ui.window and not self.ui.window:IsHidden()
end

function AF:QueueRefresh()
    if self.refreshQueued or not self:IsWindowShowing() then return end
    self.refreshQueued = true
    local updateName = self.name .. "_Refresh"
    -- One refresh per burst of criteria, award and tracking events.
    EVENT_MANAGER:RegisterForUpdate(updateName, self.refreshDelayMs, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        self.refreshQueued = false
        if self:IsWindowShowing() then self:RefreshResults() end
    end)
end

function AF:OnAchievementUpdated(id)
    if id and id > 0 then
        self.rewardIndex[id] = nil
        self.lineRewardCache[GetBaseId(id)] = nil
    else
        ZO_ClearTable(self.rewardIndex)
        ZO_ClearTable(self.lineRewardCache)
    end
    -- Invalidate while hidden as well, so the next opening uses current progress and totals.
    self.masterList = nil
    self:QueueRefresh()
end

function AF:OnPlayerActivated()
    -- No longer injecting into the default Achievements panel
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ACHIEVEMENT_UPDATED,
        function(_, achievementId) self:OnAchievementUpdated(achievementId) end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ACHIEVEMENT_AWARDED,
        function(_, name, points, achievementId) self:OnAchievementUpdated(achievementId) end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ACHIEVEMENTS_UPDATED,
        function() self:OnAchievementUpdated() end)
    if EVENT_ACHIEVEMENT_TRACKING_UPDATE then
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ACHIEVEMENT_TRACKING_UPDATE,
            function() self:QueueRefresh() end)
    end
    self:OnAchievementUpdated()
end

function AF:OnAddOnLoaded(event, addonName)
    if addonName ~= self.name then return end

    self.saved = ZO_SavedVars:NewAccountWide("AchievementFilter_SavedVariables", 1, nil, self.defaults)

    -- Slash command to open our panel
    SLASH_COMMANDS["/af"] = function()
        AF:ShowWindow()
    end

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function(...) self:OnPlayerActivated(...) end)
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(AF.name, EVENT_ADD_ON_LOADED, function(...) AF:OnAddOnLoaded(...) end)

function AchievementFilter_Toggle()
    if AF.scene and AF.scene:IsShowing() then
        SCENE_MANAGER:Hide("achievementFilterScene")
    else
        AF:ShowWindow()
    end
end

