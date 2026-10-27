local ADDON_NAME = "LykeionsGroupBanisher"
local SV_NAME = 'LGB_VARS'
local VALID_THRESHOLD = 10800
local WIPE_TIMEOUT = 1814400
local db

local validList = {}
local defaults = {
    cachedList = {},

}

local function sameGroupExistInCache(newGroup)
    for _, cachedGroup in ipairs(db.cachedList) do
        if cachedGroup.category == newGroup.category and cachedGroup.title == newGroup.title and cachedGroup.displayName == newGroup.displayName and cachedGroup.description == newGroup.description then
            return cachedGroup
        end
    end
    return false
end

-- Override the ingame function
function ZO_GroupFinder_SearchResultsList_Keyboard:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    for _, data in ipairs(self.masterList) do
        local index = data:GetListingIndex()
        local category = GetGroupFinderSearchListingCategoryByIndex(index)
        local title = GetGroupFinderSearchListingTitleByIndex(index)
        local displayName = GetGroupFinderSearchListingLeaderDisplayNameByIndex(index)
        local description = GetGroupFinderSearchListingDescriptionByIndex(index)
        local currentTime = GetTimeStamp()
        local newGroup = {category = category, title = title, displayName = displayName, description = description, timestamp = currentTime}
        local cachedGroup = sameGroupExistInCache(newGroup)

        if not sameGroupExistInCache(newGroup) then
            table.insert(db.cachedList, newGroup)
            if not data:IsActiveApplication() then
                table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, ZO_EntryData:New(data)))
            end
        else
            if currentTime - cachedGroup.timestamp <= VALID_THRESHOLD then
                if not data:IsActiveApplication() then
                    table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, ZO_EntryData:New(data)))
                end
            else
            end
        end
    end
    if scrollData ~= nil and #scrollData > 0 then
        ZO_GroupFinder_SearchResultsListRow:AttachToList(scrollData)
    end
    self:RefreshSearchState()
end

function ZO_GroupFinder_SearchResultsList_Gamepad:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    for _, data in ipairs(self.masterList) do
        local index = data:GetListingIndex()
        local category = GetGroupFinderSearchListingCategoryByIndex(index)
        local title = GetGroupFinderSearchListingTitleByIndex(index)
        local displayName = GetGroupFinderSearchListingLeaderDisplayNameByIndex(index)
        local description = GetGroupFinderSearchListingDescriptionByIndex(index)
        local currentTime = GetTimeStamp()
        local newGroup = {category = category, title = title, displayName = displayName, description = description, timestamp = currentTime}
        local cachedGroup = sameGroupExistInCache(newGroup)

        if not sameGroupExistInCache(newGroup) then
            table.insert(db.cachedList, newGroup)
            if not data:IsActiveApplication() then
                table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, ZO_EntryData:New(data)))
            end
        else
            if currentTime - cachedGroup.timestamp <= VALID_THRESHOLD then
                if not data:IsActiveApplication() then
                    table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, ZO_EntryData:New(data)))
                end
            else
            end
        end
    end
    if scrollData ~= nil and #scrollData > 0 then
        ZO_GroupFinder_SearchResultsListRow:AttachToList(scrollData)
    end
    self:RefreshSearchState()
end

function LykeionsGroupBanisher_HandleSlashCommand(command)
    if (command == "wipe") then
        db.cachedList = {}
    else
    end
end

local function ClearCache()
    local currentTime = GetTimeStamp()
    for i = #db.cachedList, 1, -1 do 
        if currentTime - db.cachedList[i].timestamp >= WIPE_TIMEOUT then
            table.remove(db.cachedList, i)
        end
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName == ADDON_NAME then
        db = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, defaults)
        SLASH_COMMANDS["/lgb"] = LykeionsGroupBanisher_HandleSlashCommand
    end

end

-- Initialize
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, ClearCache)