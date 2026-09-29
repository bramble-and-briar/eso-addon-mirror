BSCAAchievemntsInfo = BSCAAchievemntsInfo or {}
local BSCAAI = BSCAAchievemntsInfo

BSCAAI.Name = "BSCs-AdvancedAchievementsInfo"
BSCAAI.NameSpaced = "AdvancedAchievementsInfo"
BSCAAI.Author = "BloodStainChild666"
BSCAAI.Version = 1
BSCAAI.VersionDisplay = "2.0.9"

-- Kategorie IDs
local BSCAAInfo         = 6666
local BSCAAInfo_notD    = 6667
local BSCAAInfo_notD_CH = 6668
local BSCAAInfo_FAV     = 6669
local BSCAAInfo_FAV_ACC = 6670
local BSCAAInfo_FAV_CHAR = 6671

-- Tabellen
local Last50Achievements = {}
local DoneList = {}
local NotDoneList = {}
local NotDoneList_CHAR = {}
local DSUB_CAT_LIST = {}
local DSUB_CAT_IDS = {}
local NSUB_CAT_LIST = {}
local NSUB_CAT_LIST_CHAR = {}
local NotDoneBySubCat_ACC = {}
local NotDoneBySubCat_CHAR = {}
local EMPTY_TABLE = {}

-----------------------------------------------------------------
-- Hilfsfunktionen
-----------------------------------------------------------------
local function BSC_round(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function GetMonthName(month)
	return zo_strformat("<<1>>", GetString("SI_GREGORIANCALENDARMONTHS", month))
end

local function CalculateTimeStamp(year, month, day, hour, minute, second)
    year   = tonumber(year)
    month  = tonumber(month)
    day    = tonumber(day)
    hour   = tonumber(hour)   or 0
    minute = tonumber(minute) or 0
    second = tonumber(second) or 0

    -- Ungültiges oder nicht vorhandenes Datum
    if not year or year < 1970
        or not month or month < 1 or month > 12
        or not day or day < 1 or day > 31
        or hour < 0 or hour > 23
        or minute < 0 or minute > 59
        or second < 0 or second > 59
    then
        return 0
    end

    return os.time({
        year  = year,
        month = month,
        day   = day,
        hour  = hour,
        min   = minute,
        sec   = second,
    })
end

local function BSC_IsAchievementComplete(id)
    while IsAchievementComplete(id) do
        local nextId = GetNextAchievementInLine(id)
        if nextId == 0 then return true end
        id = nextId
    end
    local totalCompleted, totalRequired = 0, 0
    local numCriteria = GetAchievementNumCriteria(id)
    for crit = 1, numCriteria do
        local _, numCompleted, numRequired = GetAchievementCriterion(id, crit)
        totalCompleted = totalCompleted + numCompleted
        totalRequired  = totalRequired  + numRequired
    end
    return totalCompleted == totalRequired
end
-----------------------------------------------------------------
-- Favoriten
-----------------------------------------------------------------
function BSCAAI:GetTrackingSplit()
    local accountArray = {}
    local charArray = {}

    for id, active in pairs(BSCAAI.TRACKING.Account) do
        if active then
            if not BSC_IsAchievementComplete(id) then
                table.insert(accountArray, id)
            else
                BSCAAI.TRACKING.Account[id] = nil
            end
        end
    end
	 
    local charId = GetCurrentCharacterId()
    local charTracking = BSCAAI.TRACKING.Characters[charId] or {}
    for id, active in pairs(charTracking) do
        if active then
            if not BSC_IsAchievementComplete(id) then
                table.insert(charArray, id)
            else
                charTracking[id] = nil
            end
        end
    end

    return accountArray, charArray
end

-----------------------------------------------------------------
-- Erledigte Achievements nach Datum gruppieren
-----------------------------------------------------------------
local function AddID(id)
    local ts = GetAchievementTimestamp(id)
    if not ts or ts == 0 then return end
    local dt = os.date("*t", ts)
    local y, m, d = dt.year, dt.month, dt.day
    DoneList[y] = DoneList[y] or {}
    DoneList[y][m] = DoneList[y][m] or {}
    DoneList[y][m][d] = DoneList[y][m][d] or {}
    table.insert(DoneList[y][m][d], id)
end

local function GetAchievementByDate(nYear, nMonth, nDay)
    local sumPoints = 0
    local retArray = {}
    if nYear then nYear = tonumber(nYear) end
    if nMonth then nMonth = tonumber(nMonth) end
    if nDay then nDay = tonumber(nDay) end

    for year, months in pairs(DoneList) do
        if not nYear or year == nYear then
            for month, days in pairs(months) do
                if not nMonth or month == nMonth then
                    local sortedDays = {}
                    for day in pairs(days) do table.insert(sortedDays, day) end
                    table.sort(sortedDays, function(a, b) return a < b end)
                    for _, day in ipairs(sortedDays) do
                        if not nDay or day == nDay then
                            for _, id in ipairs(days[day]) do
                                table.insert(retArray, id)
                                local _, _, points = GetAchievementInfo(id)
                                sumPoints = sumPoints + (points or 0)
                            end
                        end
                    end
                end
            end
        end
    end
    return retArray, sumPoints
end

-----------------------------------------------------------------
-- TODO-Funktionen
-----------------------------------------------------------------
local function GetSubCategoryNameForAchievement(id)
    local categoryIndex, subCategoryIndex = GetCategoryInfoFromAchievementId(id)
    local subCategoryName = GetAchievementSubCategoryInfo(categoryIndex, subCategoryIndex)

    if subCategoryIndex == nil or subCategoryIndex == 0 then
        subCategoryName = GetString(SI_JOURNAL_PROGRESS_CATEGORY_GENERAL)
    end

    return subCategoryName or GetString(SI_JOURNAL_PROGRESS_CATEGORY_GENERAL)
end

local function GetAchievementNDoneByCatIDX_ACC(idx)
    local subCategoryName = NSUB_CAT_LIST[idx]
    if not subCategoryName then return EMPTY_TABLE end
    return NotDoneBySubCat_ACC[subCategoryName] or EMPTY_TABLE
end

local function GetAchievementNDoneByCatIDX_CHAR(idx)
    local subCategoryName = NSUB_CAT_LIST_CHAR[idx]
    if not subCategoryName then return EMPTY_TABLE end
    return NotDoneBySubCat_CHAR[subCategoryName] or EMPTY_TABLE
end

-----------------------------------------------------------------
-- Tabellen aufbauen
-----------------------------------------------------------------
local org_ZO_GetAchievementIds

function BSCAAI.CreateTable()
    DoneList = {}
    NotDoneList = {}
    NotDoneList_CHAR = {}
    NotDoneBySubCat_ACC = {}
    NotDoneBySubCat_CHAR = {}
    Last50Achievements = {}
    DSUB_CAT_LIST = {}
    DSUB_CAT_IDS = {}
    NSUB_CAT_LIST = {}
    NSUB_CAT_LIST_CHAR = {}

    local allDone = {}
    local allDoneTimestamps = {}
    local completedMonthPoints = {}

    local function AddNotDoneToCache(achievementId, isChar)
        local subCategoryName = GetSubCategoryNameForAchievement(achievementId)
        local target = isChar and NotDoneBySubCat_CHAR or NotDoneBySubCat_ACC
        target[subCategoryName] = target[subCategoryName] or {}
        table.insert(target[subCategoryName], achievementId)

        if isChar then
            table.insert(NotDoneList_CHAR, achievementId)
        else
            table.insert(NotDoneList, achievementId)
        end
    end

    local function ProcessAchievements(achievementIds)
        if not achievementIds then return end

        for _, achievementId in ipairs(achievementIds) do
            local isChar = GetAchievementPersistenceLevel(achievementId) == ACHIEVEMENT_PERSISTENCE_CHARACTER
            if BSC_IsAchievementComplete(achievementId) then
                local ts = GetAchievementTimestamp(achievementId) or 0
                allDoneTimestamps[achievementId] = ts
                table.insert(allDone, achievementId)

                if ts > 0 then
                    AddID(achievementId)

                    local dt = os.date("*t", ts)
                    completedMonthPoints[dt.year] = completedMonthPoints[dt.year] or {}
                    completedMonthPoints[dt.year][dt.month] = completedMonthPoints[dt.year][dt.month] or { count = 0, points = 0 }
                    completedMonthPoints[dt.year][dt.month].count = completedMonthPoints[dt.year][dt.month].count + 1

                    local _, _, points = GetAchievementInfo(achievementId)
                    completedMonthPoints[dt.year][dt.month].points = completedMonthPoints[dt.year][dt.month].points + (points or 0)
                end
            else
                AddNotDoneToCache(achievementId, isChar)
            end
        end
    end

    for categoryIndex = 1, GetNumAchievementCategories() do
        local _, numSubCategories, numAchievements = GetAchievementCategoryInfo(categoryIndex)
        if numAchievements > 0 then
            ProcessAchievements(org_ZO_GetAchievementIds and org_ZO_GetAchievementIds(categoryIndex, nil, numAchievements, false) or ZO_GetAchievementIds(categoryIndex, nil, numAchievements, false))
        end
        for subCategoryIndex = 1, numSubCategories do
            local _, subNumAchievements = GetAchievementSubCategoryInfo(categoryIndex, subCategoryIndex)
            if subNumAchievements > 0 then
                ProcessAchievements(org_ZO_GetAchievementIds and org_ZO_GetAchievementIds(categoryIndex, subCategoryIndex, subNumAchievements, false) or ZO_GetAchievementIds(categoryIndex, subCategoryIndex, subNumAchievements, false))
            end
        end
    end

    table.sort(allDone, function(a, b)
        return (allDoneTimestamps[a] or 0) > (allDoneTimestamps[b] or 0)
    end)

    for i = 1, math.min(50, #allDone) do
        table.insert(Last50Achievements, allDone[i])
    end

    -- DSUB_CAT_LIST (Completed nach Monat)
    local subcats = {}
    for year, months in pairs(completedMonthPoints) do
        for month, data in pairs(months) do
            local ts = CalculateTimeStamp(year, month, 1)
            table.insert(subcats, {
                year = year,
                month = month,
                ts = ts,
                name = string.format("%d - %s (%d) (%d)", year, GetMonthName(month), data.count or 0, data.points or 0)
            })
        end
    end
    table.sort(subcats, function(a, b) return a.ts < b.ts end)
    for _, entry in ipairs(subcats) do
        table.insert(DSUB_CAT_LIST, entry.name)
        table.insert(DSUB_CAT_IDS, tonumber(string.format("%04d%02d", entry.year, entry.month)))
    end

    -- NSUB_CAT_LIST (Account)
    for subCategoryName in pairs(NotDoneBySubCat_ACC) do
        table.insert(NSUB_CAT_LIST, subCategoryName)
    end
    table.sort(NSUB_CAT_LIST, function(a, b) return a < b end)

    -- NSUB_CAT_LIST_CHAR (Char)
    for subCategoryName in pairs(NotDoneBySubCat_CHAR) do
        table.insert(NSUB_CAT_LIST_CHAR, subCategoryName)
    end
    table.sort(NSUB_CAT_LIST_CHAR, function(a, b) return a < b end)
end

-----------------------------------------------------------------
-- Custom Tabs
-----------------------------------------------------------------
function BSCAAI.CreateCustomTabs()
    local Achievements = getmetatable(ACHIEVEMENTS).__index
    local org_AddTopLevelCategory = Achievements.AddTopLevelCategory

    function Achievements.AddTopLevelCategory(...)
        local self, name = ...
        if name then return org_AddTopLevelCategory(...) end

        local result = org_AddTopLevelCategory(...)
        local lookup, tree = self.nodeLookupData, self.categoryTree

        -- Update 51 replaced the generic ZO_Tree templates used by the
        -- achievement category tree with achievement-specific templates.
        local isUpdate51OrNewer = GetAPIVersion() >= 101051
        local nodeTemplate = isUpdate51OrNewer and "ZO_Achievements_StatusIconHeader" or "ZO_IconHeader"
        local subTemplate  = isUpdate51OrNewer and "ZO_Achievements_SubCategory" or "ZO_TreeLabelSubCategory"

        local normalIcon   = "esoui/art/market/keyboard/giftmessageicon_up.dds"
        local pressedIcon  = "esoui/art/market/keyboard/giftmessageicon_down.dds"
        local mouseoverIcon= "esoui/art/market/keyboard/giftmessageicon_over.dds"

        -- A custom top-level node may be marked as a summary so selecting the
        -- header itself does not query a real achievement category. It must NOT
        -- be marked as a faked subcategory: AddCategory would otherwise store
        -- it under ZO_ACHIEVEMENTS_ROOT_SUBCATEGORY instead of its category ID.
        -- Update 51 iterates nodeLookupData and requires every top-level lookup
        -- entry to contain a valid .node.
        local function AddCustomTopLevel(categoryIndex, name)
            local IS_SUMMARY = true
            local IS_NOT_FAKED_SUBCATEGORY = false
            return self:AddCategory(
                lookup,
                tree,
                nodeTemplate,
                nil,
                categoryIndex,
                name,
                false,
                normalIcon,
                pressedIcon,
                mouseoverIcon,
                IS_SUMMARY,
                IS_NOT_FAKED_SUBCATEGORY
            )
        end

        -- Completed
        local completedNode = AddCustomTopLevel(BSCAAInfo, "Completed LIST")
        self:AddCategory(lookup, tree, subTemplate, completedNode, BSCAAInfo, "Last 50", false)
        for i, name in ipairs(DSUB_CAT_LIST) do
            self:AddCategory(lookup, tree, subTemplate, completedNode, tonumber(DSUB_CAT_IDS[i]), name, true)
        end

        -- Favorites
		local accountTrack, charTrack = BSCAAI:GetTrackingSplit()
		if #accountTrack > 0 or #charTrack > 0 then
			local favNode = AddCustomTopLevel(BSCAAInfo_FAV, "Achievement Tracking")
			if #accountTrack > 0 then
				self:AddCategory(lookup, tree, subTemplate, favNode, BSCAAInfo_FAV_ACC, "Account", false)
			end
			if #charTrack > 0 then
				self:AddCategory(lookup, tree, subTemplate, favNode, BSCAAInfo_FAV_CHAR, "Char", false)
			end
		end
        -- TODO LIST (Account)
		if #NSUB_CAT_LIST > 0 then
			local todoNodeAcc = AddCustomTopLevel(BSCAAInfo_notD, "TODO LIST (Account)")
			for idx, subName in ipairs(NSUB_CAT_LIST) do
				local count = #GetAchievementNDoneByCatIDX_ACC(idx)
				self:AddCategory(lookup, tree, subTemplate, todoNodeAcc, idx, string.format("%s (%d)", subName, count), true)
			end
		end

        -- TODO LIST (Char)
		if #NSUB_CAT_LIST_CHAR > 0 then
			local todoNodeChar = AddCustomTopLevel(BSCAAInfo_notD_CH, "TODO LIST (Char)")
			for idx, subName in ipairs(NSUB_CAT_LIST_CHAR) do
				local count = #GetAchievementNDoneByCatIDX_CHAR(idx)
				self:AddCategory(lookup, tree, subTemplate, todoNodeChar, idx, string.format("%s (%d)", subName, count), true)
			end
		end

        return result
    end
end

-----------------------------------------------------------------
-- ZO_GetAchievementIds Hook
-----------------------------------------------------------------
org_ZO_GetAchievementIds = ZO_GetAchievementIds
function ZO_GetAchievementIds(categoryIndex, subcategoryIndex, numAchievements, considerSearchResults)
    if categoryIndex == BSCAAInfo then
        if subcategoryIndex ~= nil and subcategoryIndex ~= BSCAAInfo then
            local year  = tonumber(string.sub(subcategoryIndex, 1, 4))
            local month = tonumber(string.sub(subcategoryIndex, 5))
            return GetAchievementByDate(year, month, nil)
        end
        return Last50Achievements
    end

    if categoryIndex == BSCAAInfo_FAV then
		local accountTrack, charTrack = BSCAAI:GetTrackingSplit()
		if subcategoryIndex == BSCAAInfo_FAV_ACC then
			return accountTrack
		end		
		if subcategoryIndex == BSCAAInfo_FAV_CHAR then
			return charTrack
		end
    end

    if categoryIndex == BSCAAInfo_notD then
        if subcategoryIndex and NSUB_CAT_LIST[subcategoryIndex] then
            return GetAchievementNDoneByCatIDX_ACC(subcategoryIndex)
        end
        return {}
    end

    if categoryIndex == BSCAAInfo_notD_CH then
        if subcategoryIndex and NSUB_CAT_LIST_CHAR[subcategoryIndex] then
            return GetAchievementNDoneByCatIDX_CHAR(subcategoryIndex)
        end
        return {}
    end

    return org_ZO_GetAchievementIds(categoryIndex, subcategoryIndex, numAchievements, considerSearchResults)
end

-----------------------------------------------------------------
-- Rechtsklick Kontextmenü für Favoriten
-----------------------------------------------------------------
-- Helper: Basis-ID (Anfang der Kette) ermitteln
local function GetBaseAchievementIdSafe(id)
    if ACHIEVEMENTS and ACHIEVEMENTS.GetBaseAchievementId then
        return ACHIEVEMENTS:GetBaseAchievementId(id)
    end
    local first = GetFirstAchievementInLine(id)
    return (first ~= 0) and first or id
end

-- Uses ESO's native context menu API.
-- This removes the old runtime dependency on external context-menu libraries.
local function BSCAAI_AddNativeMenuItem(label, callback)
    if type(AddMenuItem) == "function" then
        AddMenuItem(label, callback)
    end
end

local function BSCAAI_AddToContextMenu(achievementControlOrObject)
    if not achievementControlOrObject or not achievementControlOrObject.GetId then return end
    local shownId = achievementControlOrObject:GetId()
    if not shownId then return end

    local baseId = GetBaseAchievementIdSafe(shownId)
    local isChar = GetAchievementPersistenceLevel(baseId) == ACHIEVEMENT_PERSISTENCE_CHARACTER
    local charId = GetCurrentCharacterId()

    local favs
    if isChar then
        BSCAAI.TRACKING.Characters[charId] = BSCAAI.TRACKING.Characters[charId] or {}
        favs = BSCAAI.TRACKING.Characters[charId]
    else
        favs = BSCAAI.TRACKING.Account
    end

    local isFav = favs[baseId] or favs[shownId]

    if isFav then
        BSCAAI_AddNativeMenuItem("Remove from Tracking", function()
            local id = baseId
            while id ~= 0 do
                favs[id] = nil
                id = GetNextAchievementInLine(id)
            end
			if ACHIEVEMENTS and ACHIEVEMENTS.refreshGroups then
                ACHIEVEMENTS.refreshGroups:RefreshAll("FullUpdate")
            end
            BSCAAI.QueueFavWidgetUpdate(1)
        end)
    else
        BSCAAI_AddNativeMenuItem("Add to Tracking", function()
            if BSC_IsAchievementComplete(baseId) then
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, "Completed achievements cannot be added to tracking.")
                    --"Abgeschlossene Errungenschaften können nicht zu Favoriten hinzugefügt werden.")
                return
            end

            favs[baseId] = true

			if ACHIEVEMENTS and ACHIEVEMENTS.refreshGroups then
                ACHIEVEMENTS.refreshGroups:RefreshAll("FullUpdate")
            end
            BSCAAI.QueueFavWidgetUpdate(1)
        end)
    end
end

function BSCAAI:ShowAchieve(link)
	local aid = GetAchievementIdFromLink(link)
	if select(1,GetCategoryInfoFromAchievementId(aid)) ~= nil then
		SCENE_MANAGER:ShowBaseScene()
		ACHIEVEMENTS:ShowAchievement(aid)
	else
		CHAT_SYSTEM:AddMessage("|cA00000This achievement is not visible in the achievements tab of the quest journal.|r")
	end	
end
function BSCAAI:OverWriteLinkMouseUpHandler()
    local base = ZO_LinkHandler_OnLinkMouseUp
    ZO_LinkHandler_OnLinkMouseUp = function(link, button, control)
        base(link, button, control)
        if button ~= MOUSE_BUTTON_INDEX_RIGHT or GetLinkType(link) ~= LINK_TYPE_ACHIEVEMENT then
            return
        end
		AddMenuItem("Show in Achievements", function() BSCAAI:ShowAchieve(link) end)
        ShowMenu(control)
    end
end

function BSCAAI:InstallFavoriteMenuHooks()
    local AchievementClass

    local orgFactory = ACHIEVEMENTS.achievementPool.m_Factory
    ACHIEVEMENTS.achievementPool.m_Factory = function(...)
        local control = orgFactory(...)
        if not AchievementClass and control then
            AchievementClass = getmetatable(control).__index

            local orgOnClicked = AchievementClass.OnClicked
            function AchievementClass:OnClicked(button, ...)
                if button == MOUSE_BUTTON_INDEX_RIGHT and IsChatSystemAvailableForCurrentPlatform() then
                    local achObj = self
                    local orgShowMenu = ShowMenu
                    function ShowMenu(...)
                        ShowMenu = orgShowMenu
                        if not ACHIEVEMENTS.control:IsHidden() then
                            BSCAAI_AddToContextMenu(achObj)
                        end
                        return ShowMenu(...)
                    end
                end
                return orgOnClicked(self, button, ...)
            end
        end
        return control
    end
end

function BSCAAI.OnPlayerActivated()
    BSCAAI.PrintInfo()
    BSCAAI.QueueFavWidgetUpdate(500)
end

function BSCAAI:CreateAchievementUICheckbox()
    if BSCAAI.AchievementUICheckbox then return end

    local parent = ZO_Achievements
    if not parent then return end

    -- Checkbox aus ESO-Template
    local cb = CreateControlFromVirtual("BSCAAI_EnableCheckbox", parent, "ZO_CheckButton")
    cb:ClearAnchors()
    cb:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 12, 30)

    -- Kein eigenes OnClicked setzen! Stattdessen ToggleFunction:
    ZO_CheckButton_SetToggleFunction(cb, function(button, checked)
        BSCAAI:SetTrackingWindowEnabled(checked)
    end)

    -- Initialen Zustand setzen
    ZO_CheckButton_SetCheckState(cb, BSCAAI.SV_CHAR.UI_ENABLE and true or false)

    -- Label daneben (optional mit Klick zum Toggeln)
    local lbl = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    lbl:SetFont("ZoFontGame")
    lbl:SetText("Tracking UI")
    lbl:SetAnchor(LEFT, cb, RIGHT, 8, 0)
    lbl:SetMouseEnabled(true)
    lbl:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            -- Label-Klick toggelt Checkbox mit Template-Handler
            ZO_CheckButton_OnClicked(cb)
        end
    end)
	
	-- Tooltip hinzufügen
	cb:SetHandler("OnMouseEnter", function(self)
		InitializeTooltip(InformationTooltip, self, TOP, 0, 0)
		SetTooltipText(InformationTooltip, "Show/Hide Tracking UI")
	end)

	cb:SetHandler("OnMouseExit", function()
		ClearTooltip(InformationTooltip)
	end)
	
	lbl:SetHandler("OnMouseEnter", function(self)
		InitializeTooltip(InformationTooltip, self, TOP, 0, 0)
		SetTooltipText(InformationTooltip, "Show/Hide Tracking UI")
	end)

	lbl:SetHandler("OnMouseExit", function()
		ClearTooltip(InformationTooltip)
	end)

    BSCAAI.AchievementUICheckbox = cb
end

local function CreateLable()
	local fontSize = 22
	local fontStyle = ZoFontGame:GetFontInfo()
	local fontWeight = "soft-shadow-thin"
	local font = string.format("%s|$(KB_%s)|%s", fontStyle, fontSize, fontWeight)	
	local parent = ZO_AchievementsContentsSummaryInsetProgressBarsScrollChild	
	BSCAAI.achievementLabel = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
	BSCAAI.achievementLabel:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -50, -3) 
	BSCAAI.achievementLabel:SetFont(font)
	local parentSearch = ZO_AchievementsContentsSearch
	BSCAAI.ButtonClearF = WINDOW_MANAGER:CreateControlFromVirtual(nil, parentSearch, "ZO_DefaultButton")
    BSCAAI.ButtonClearF:SetAnchor(BOTTOMLEFT, parentSearch, TOPRIGHT, 0, 0)
    BSCAAI.ButtonClearF:SetWidth(100)
    BSCAAI.ButtonClearF:SetText("Clear Filter")
    BSCAAI.ButtonClearF:SetHandler("OnClicked", function() 
		ACHIEVEMENTS.contentSearchEditBox:SetText("")
	end)			
	BSCAAI.ButtonSearch = WINDOW_MANAGER:CreateControlFromVirtual(nil, parentSearch, "ZO_DefaultButton")
    BSCAAI.ButtonSearch:SetAnchor(LEFT, parentSearch, RIGHT, 0, 0)
    BSCAAI.ButtonSearch:SetWidth(100)
    BSCAAI.ButtonSearch:SetText("Search Zone")
    BSCAAI.ButtonSearch:SetHandler("OnClicked", function() 			
		local zoneId = GetUnitWorldPosition("player") 	
		ACHIEVEMENTS.contentSearchEditBox:SetText(zo_strformat("<<1>>", GetZoneNameById(zoneId)))
	end)	
	BSCAAI.ButtonSearchB = WINDOW_MANAGER:CreateControlFromVirtual(nil, parentSearch, "ZO_DefaultButton")
    BSCAAI.ButtonSearchB:SetAnchor(TOPLEFT, parentSearch, BOTTOMRIGHT, 0, 0)
    BSCAAI.ButtonSearchB:SetWidth(100)
    BSCAAI.ButtonSearchB:SetText("Search Boss")
    BSCAAI.ButtonSearchB:SetHandler("OnClicked", function() 		
		if DoesUnitExist('boss1')  then		
			ACHIEVEMENTS.contentSearchEditBox:SetText(zo_strformat("<<1>>", GetUnitName('boss1')))
		end
	end)	
end

function BSCAAI.PrintInfo()
	local earned = GetEarnedAchievementPoints()
	local max_points = GetTotalAchievementPoints()
	local percent = BSC_round((earned/max_points)*100, 4)
	BSCAAI.achievementLabel:SetText("|cd5b526" ..  percent .. "%")
end

local function CheckFavorites()
    for id in pairs(BSCAAI.TRACKING.Account) do
        if BSC_IsAchievementComplete(id) then
            BSCAAI.TRACKING.Account[id] = nil
        end
    end
	
    local charId = GetCurrentCharacterId()
    if charId and BSCAAI.TRACKING.Characters[charId] then
        for id in pairs(BSCAAI.TRACKING.Characters[charId]) do
            if BSC_IsAchievementComplete(id) then
                BSCAAI.TRACKING.Characters[charId][id] = nil
            end
        end
    end
end

function BSCAAI.QueueFavWidgetUpdate(delay)
    if BSCAAI._favUpdateQueued then return end
    BSCAAI._favUpdateQueued = true

    zo_callLater(function()
        BSCAAI._favUpdateQueued = false

        if not BSCAAI.SV_CHAR then return end
        if not BSCAAI.SV_CHAR.UI_ENABLE and not BSCAAI._menuPanelOpen then return end
        if not BSCAAI.UpdateFavWidget then return end

        BSCAAI.UpdateFavWidget()
    end, delay or 500)
end

local function RefreshAchievementTree()
    if ACHIEVEMENTS and ACHIEVEMENTS.control and not ACHIEVEMENTS.control:IsHidden() and ACHIEVEMENTS.refreshGroups then
        ACHIEVEMENTS.refreshGroups:RefreshAll("FullUpdate")
    end
end

function BSCAAI.QueueFullAchievementRebuild(delay)
    if BSCAAI._fullRebuildQueued then return end
    BSCAAI._fullRebuildQueued = true

    zo_callLater(function()
        BSCAAI._fullRebuildQueued = false

        BSCAAI.PrintInfo()
        CheckFavorites()
        BSCAAI.CreateTable()
        RefreshAchievementTree()
        BSCAAI.QueueFavWidgetUpdate(1)
    end, delay or 750)
end

local defaults_acc = {
    Tracking = {
        Account = {},
        Characters = {},
    },
}

local defaults_char = {
	PRINT_INFO = false,
    UI_ENABLE = false,
    UI_X = nil,
    UI_Y = nil,
	UI_WIDTH = 400,
	UI_HEIGHT = 300,
	UI_HIDE_COMPLETED_CRITERIA = true,
	UI_FONT_SIZE = 18,
    Version = 1,	
}

function BSCAAI.init(_, addonName)
	if addonName ~= BSCAAI.Name then return end
	EVENT_MANAGER:UnregisterForEvent(BSCAAI.Name, EVENT_ADD_ON_LOADED)
	
	BSCAAI.SV_ACC = ZO_SavedVars:NewAccountWide("BSCAAIS", 1, nil, defaults_acc)
	BSCAAI.SV_CHAR = ZO_SavedVars:NewCharacterNameSettings("BSCAAIS", 1, nil, defaults_char)
	if BSCAAI.SV_CHAR.UI_HIDE_COMPLETED_CRITERIA == nil then
		BSCAAI.SV_CHAR.UI_HIDE_COMPLETED_CRITERIA = true
	end
	BSCAAI.SV_CHAR.UI_FONT_SIZE = math.floor(zo_clamp(tonumber(BSCAAI.SV_CHAR.UI_FONT_SIZE) or defaults_char.UI_FONT_SIZE, 12, 54) + 0.5)
	if BSCAAI.FontCheck then
		BSCAAI.SV_CHAR.UI_FONT_SIZE = BSCAAI.FontCheck(BSCAAI.SV_CHAR.UI_FONT_SIZE)
	end
	BSCAAI.TRACKING = BSCAAI.SV_ACC.Tracking
		
	BSCAAI:OverWriteLinkMouseUpHandler()
	CreateLable()
	BSCAAI.CreateTable()
	BSCAAI.CreateCustomTabs()
	
	BSCAAI:InstallFavoriteMenuHooks()
	CheckFavorites()
	BSCAAI:InitTrackingUI()
	BSCAAI:InitMenu()
	
	BSCAAI:CreateAchievementUICheckbox()

	EVENT_MANAGER:RegisterForEvent(BSCAAI.Name, EVENT_PLAYER_ACTIVATED, BSCAAI.OnPlayerActivated)
	EVENT_MANAGER:RegisterForEvent(BSCAAI.Name, EVENT_ACHIEVEMENT_AWARDED, function()
		BSCAAI.QueueFullAchievementRebuild(750)
	end)
	EVENT_MANAGER:RegisterForEvent(BSCAAI.Name, EVENT_ACHIEVEMENTS_UPDATED, function()
		BSCAAI.QueueFavWidgetUpdate(500)
	end)
	EVENT_MANAGER:RegisterForEvent(BSCAAI.Name, EVENT_ACHIEVEMENT_UPDATED, function()
		BSCAAI.QueueFavWidgetUpdate(500)
	end)
end

EVENT_MANAGER:RegisterForEvent(BSCAAI.Name, EVENT_ADD_ON_LOADED, BSCAAI.init)
