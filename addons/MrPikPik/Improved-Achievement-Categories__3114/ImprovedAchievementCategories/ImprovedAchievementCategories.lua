local name = "ImprovedAchievementCategories"

local function AddTopLevelCategory(self, categoryIndex, name, numSubCategories, hidesUnearned, normalIcon, pressedIcon, mouseoverIcon)
    if categoryIndex == nil then return false end -- Summary has categoryIndex set to nil
    
    for sub = 1, numSubCategories do
        local ids = ZO_GetAchievementIds(categoryIndex, sub, 99, true)
        
        for i = 1, #ids do
            if ZO_ShouldShowAchievement(self.categoryFilter.filterType, ids[i]) then
                return false
            end
        end
        
        ids = ZO_GetAchievementIds(categoryIndex, nil, 99, true)
        for i = 1, #ids do
            if ZO_ShouldShowAchievement(self.categoryFilter.filterType, ids[i]) then
                return false
            end
        end
    end 
    return true
end

local function AddCategory(self, lookup, tree, nodeTemplate, parent, categoryIndex, name, hidesUnearned, normalIcon, pressedIcon, mouseoverIcon, isSummary, isFakedSubcategory)
    if nodeTemplate ~= "ZO_Achievements_SubCategory" then return false end
    
    local ids
    if isFakedSubcategory then
        ids = ZO_GetAchievementIds(parent.data.categoryIndex, nil, 99, true)
    else
        ids = ZO_GetAchievementIds(parent.data.categoryIndex, categoryIndex, 99, true)
    end
    
    for i = 1, #ids do
        if ZO_ShouldShowAchievement(self.categoryFilter.filterType, ids[i]) then
            return false
        end
    end
    return true
end

-- We need to override this for the categories to refresh once a different filter has been selected
local filterData = {SI_ACHIEVEMENT_FILTER_SHOW_ALL, SI_ACHIEVEMENT_FILTER_SHOW_EARNED, SI_ACHIEVEMENT_FILTER_SHOW_UNEARNED}
local function InitializeFilters(self) -- Also gets "filterData" usually as a parameter
    local comboBox = ZO_ComboBox_ObjectFromContainer(self.categoryFilter)
    comboBox:ClearItems()
    
    local function OnFilterChanged(comboBox, entryText, entry)
        self.categoryFilter.filterType = entry.filterType
        self:BuildCategories()
        self:RefreshVisibleCategoryFilter()
    end

    for i, stringId in ipairs(filterData) do
        local entry = comboBox:CreateItemEntry(GetString(stringId), OnFilterChanged)
        entry.filterType = stringId
        comboBox:AddItem(entry)
    end

    comboBox:SelectItemByIndex(#filterData) -- Select "Show unearned" by default
	return true
end


-- Patch to check if a category is completed
local SUMMARY_CATEGORY_BAR_HEIGHT = 16
local SUMMARY_CATEGORY_PADDING = 50
local FORCE_HIDE_PROGRESS_TEXT = true
local function UpdateSummary(self)
    self.summaryStatusBarPool:ReleaseAllObjects()

    self:UpdateStatusBar(self.summaryTotal, nil, GetEarnedAchievementPoints(), GetTotalAchievementPoints(), 0, nil, FORCE_HIDE_PROGRESS_TEXT)

    local numCategories = GetNumAchievementCategories()
    local yOffset = SUMMARY_CATEGORY_PADDING
    local categoryIndex = 1
    for i = 1, numCategories do
        local name, _, numAchievements, earnedPoints, totalPoints, hidesPoints = GetAchievementCategoryInfo(i)
        if totalPoints > 0 and earnedPoints ~= totalPoints then -- <- Added check here
            local statusBar = self.summaryStatusBarPool:AcquireObject()
            self:UpdateStatusBar(statusBar, name, earnedPoints, totalPoints, numAchievements, hidesPoints, FORCE_HIDE_PROGRESS_TEXT)
            statusBar:ClearAnchors()

            if categoryIndex % 2 == 0 then
                statusBar:SetAnchor(TOPRIGHT, self.summaryTotal, BOTTOMRIGHT, 0, yOffset)
                yOffset = yOffset + SUMMARY_CATEGORY_PADDING + SUMMARY_CATEGORY_BAR_HEIGHT
            else
                statusBar:SetAnchor(TOPLEFT, self.summaryTotal, BOTTOMLEFT, 0, yOffset)
            end
            categoryIndex = categoryIndex + 1
        end
    end
end


local function OnAddonLoaded(event, addonName)
    if addonName ~= name then return end
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED) 
    
    ZO_PreHook(ACHIEVEMENTS, "AddTopLevelCategory", AddTopLevelCategory)
    ZO_PreHook(ACHIEVEMENTS, "AddCategory", AddCategory)
    ZO_PreHook(ACHIEVEMENTS, "InitializeFilters", InitializeFilters)
    
    -- Patch summary modification in
    local mt = getmetatable(ACHIEVEMENTS)
    mt.UpdateSummary = UpdateSummary
    setmetatable(ACHIEVEMENTS, mt)
end
EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, OnAddonLoaded)