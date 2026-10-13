if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local tos = tostring
local strfor = string.format

------------------------------------------------------------------------------------------------------------------------
-- Collectibles --
------------------------------------------------------------------------------------------------------------------------

local currentlyOnwedTexture = "/esoui/art/buttons/accept_up.dds"
local currentlyNotOnwedTexture = "/esoui/art/buttons/cancel_up.dds"

local wasCollectibleFragmentsTooltipHooked = false
local function hookCollectibleFragmentsTooltip()
--d("[FCOCS]hookCollectibleFragmentsTooltip-wasCollectibleFragmentsTooltipHooked: " ..tos(wasCollectibleFragmentsTooltipHooked))
	if wasCollectibleFragmentsTooltipHooked then return end

	local function hookCoolectibleTooltip(tooltipControl, gameDataType, ...) --itemTooltipRef, collectibleId, SHOW_NICKNAME, SHOW_PURCHASABLE_HINT, SHOW_BLOCK_REASON
		--d("[FCOCS]ItemTooltip:OnAddGameData-gameDataType: " ..tos(gameDataType))
		--local fragmentsScrollListParentCategory = ZO_CollectionsBook_TopLevelCategoriesScrollChildContainer4
		--[[
			function ZO_CollectibleData:CombinedFragmentUnlocked()
			if self:IsCategoryType(COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT) then
				local unlockedCollectibleId = GetCombinationUnlockedCollectible(self.referenceId)
						-- or does GetCombinationUnlockedCollectible not return the id if not unlocked
				return ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(unlockedCollectibleId):IsUnlocked()
			end
			end
		]]

		--Add at latest
		if gameDataType ~= TOOLTIP_GAME_DATA_MYTHIC_OR_STOLEN then return end
		if not FCOChangeStuff.settingsVars.settings.collectibleTooltipShowFragmentCombinedItem then return end
		local row = moc()
		if not row or not row.dataEntry or not row.dataEntry.data then return end
		--d(">1")
		local collectibleIdOfFragment
		local referenceId
		local collectibleFragmentAtCollectionsFragmentUI = row.dataEntry.data
		if not collectibleFragmentAtCollectionsFragmentUI then return end
		if not collectibleFragmentAtCollectionsFragmentUI.dataSource then
			--Check if we are at the impressaria store
			if collectibleFragmentAtCollectionsFragmentUI.meetsRequirementsToBuy ~= nil and collectibleFragmentAtCollectionsFragmentUI.slotIndex ~= nil then
				local storeItemLink = GetStoreItemLink(collectibleFragmentAtCollectionsFragmentUI.slotIndex)
				--d(">Store item detected: " .. storeItemLink)
				collectibleIdOfFragment = GetCollectibleIdFromLink(storeItemLink)
				referenceId = GetCollectibleReferenceId(collectibleIdOfFragment)
			else
				return
			end
		else
			--local categoryData = collectibleFragmentAtCollectionsFragmentUI.categoryData
			local dataSource = collectibleFragmentAtCollectionsFragmentUI.dataSource
			collectibleIdOfFragment = dataSource.collectibleId
			referenceId = dataSource.referenceId
		end
		--d(">2")
		if not collectibleIdOfFragment then return end
		--d(">3-collectibleId: " ..tos(collectibleIdOfFragment))
		--Fragments category was selected?
		if ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleIdOfFragment):IsCategoryType(COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT) then
			if not referenceId then return end
			--d(">4-referenceId: " ..tos(referenceId))
			local unlockedCollectibleId = GetCombinationUnlockedCollectible(referenceId)
			if unlockedCollectibleId ~= nil and unlockedCollectibleId ~= 0 then
				local collectibleCategoryName = ZO_CachedStrFormat(SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleCategoryNameByCollectibleId(unlockedCollectibleId))
				--d(">5-unlockedCollectibleId: " ..tos(unlockedCollectibleId))
				local name, _, icon, _, unlocked = GetCollectibleInfo(unlockedCollectibleId)
				--local collectibleNameClean = ZO_CachedStrFormat(SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleName(unlockedCollectibleId))
				--local collectibleTexture = GetCollectibleIcon(unlockedCollectibleId)
				local inheritColor = not unlocked
				local collectibleNameClean = ZO_CachedStrFormat(SI_COLLECTIBLE_NAME_FORMATTER, name)
				collectibleNameClean = ((unlocked == true and "|c00FF00") or "|cFF0000") .. collectibleNameClean .. "|r"
				local textureColorDummy = ((unlocked == true and "") or "|c000000|r")
				local textureColorDummyOwned = ((unlocked == true and "|c00FF00:     |r") or "|cFF0000:     |r")
				local collectibleNameWithTextureClean = zo_iconTextFormatNoSpace(icon, 48, 48, textureColorDummy, inheritColor) .. collectibleNameClean
				local collectibleUnlockedStateTexture = zo_iconTextFormatNoSpace((unlocked and currentlyOnwedTexture) or currentlyNotOnwedTexture, 24, 24, textureColorDummyOwned, true)
				local knownText = (unlocked and GetString(SI_COLLECTIBLEUNLOCKSTATE2)) or GetString(SI_COLLECTIBLE_ACTION_COMBINE)
				--d(">is unlocked: " ..tos(unlocked))
				--d(">Found collectible for fragment: " ..tos(collectibleNameClean))
				ItemTooltip:AddLine(knownText .. collectibleUnlockedStateTexture, "ZoFontWinH3", ZO_SELECTED_TEXT:UnpackRGB())
				ItemTooltip:AddLine("["..collectibleCategoryName.."] " .. collectibleNameWithTextureClean, "ZoFontGameMedium", ZO_HIGHLIGHT_TEXT:UnpackRGB())
			end
		end
	end

	--[[
	local SHOW_NICKNAME = true
	local SHOW_PURCHASABLE_HINT = true
	local SHOW_BLOCK_REASON = true
	ItemTooltip:SetCollectible(self.collectibleData:GetId(), SHOW_NICKNAME, SHOW_PURCHASABLE_HINT, SHOW_BLOCK_REASON, self:GetActorCategory())
	]]
	--SecurePostHook(ItemTooltip, "SetCollectible", hookCoolectibleTooltip) --throws table expected got userdata error....
	ZO_PreHookHandler(ItemTooltip, 'OnAddGameData', hookCoolectibleTooltip)

	wasCollectibleFragmentsTooltipHooked = true
end

function FCOChangeStuff.collectibleChanges()
	if FCOChangeStuff.settingsVars.settings.collectibleTooltipShowFragmentCombinedItem then
		hookCollectibleFragmentsTooltip()
	end
end


--======================================================================================================================

--Favorite mounts
local lockedMountNamePattern = "|cFF0000%s|r"
local collectibleMountTilesHooked = false
local mountCategories = {}

-- Mount favorites LibShifterBox for excluded mount collectibleIds
FCOChangeStuff.excludedMountIdsShifterBoxControl = nil

FCOChangeStuff.LSB = LibShifterBox

---Disable sunds LibShifterBox settings and style
local excludedMountIdsLibShifterBoxSettings = {
    --[[
    callbackRegister = {
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_CREATED]            = function()
            d("LSB: Event left list created")
        end,
        [FCOChangeStuff.LSB.EVENT_RIGHT_LIST_CREATED]           = function()
            d("LSB: Event right list created")
        end,
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_ROW_ON_MOUSE_ENTER] = function()
            d("[FCOCS]LSB event left list row on mouse enter")
        end,
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_ROW_ON_MOUSE_EXIT]  = function()
            d("[FCOCS]LSB event left list row on mouse exit")
        end,
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_ROW_ON_DRAG_START]  = function()
            d("[FCOCS]LSB event left list row on drag start")
        end,
        [FCOChangeStuff.LSB.EVENT_RIGHT_LIST_ROW_ON_DRAG_END]   = function()
            d("[FCOCS]LSB event right list row on drag end")
        end,
    },
    rowOnMouseEnter = function(rowControl)
        local data = ZO_ScrollList_GetData(rowControl)
        d("LSB: OnMouseEnter: " ..tostring(data.tooltipText))
    end,
    rowOnMouseExit = function(rowControl) d("LSB: OnMouseExit")  end,
    rowOnMouseRightClick = function(rowControl, data) d("LSB: OnMouseRightClick") end,
    rowSetupCallback = function(rowControl, data)
        d("LSB: SetupCallback -> Calls self:SetupRowEntry, then this function, finally ZO_SortFilterList.SetupRow")
        data.tooltipText = "Hello world"
    end,
    rowDataTypeSelectSound = "ACTIVE_SKILL_RESPEC_MORPH_CHOSEN",
    rowResetControlCallback = function() d("LSB: ResetControlCallback")  end,
    rowSetupAdditionalDataCallback = function(rowControl, data)
        d("LSB: SetupAdditionalDataCallback")
            data.tooltipText = data.value
        return rowControl, data
    end,
    ]]
    leftList = {
        title = "Available mounts",
    },
    rightList = {
        title = "Excluded mounts",
        buttonTemplates = {
            moveButton = {
                normalTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_up.dds",
                mouseOverTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_over.dds",
                pressedTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_down.dds",
                disabledTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_disabled.dds",
                anchors = {
                    [1] = { BOTTOMRIGHT, "$(parent)List", BOTTOMLEFT, -2, 0 },
                },
                dimensions = { x=20, y=20 }
            },
            moveAllButton = {
                normalTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                mouseOverTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                pressedTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                disabledTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                anchors = {
                    [1] = { BOTTOM , "$(parent)Button", TOP, 0, -2 },
                },
                dimensions = { x=20, y=20 }
            },
            searchButton = {
                normalTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                mouseOverTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                pressedTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                disabledTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                anchors = {
                    [1] = { RIGHT, "$(parent)", RIGHT, -60, 0 },
                },
                dimensions = { x=60, y=60 }
            }
        }
    },
    search = {
            enabled = true,
            --searchFunc = function(shifterBox, entry, searchStr) return findMe(entry, searchStr)  end
    },
}
local excludedMountIdsLibShifterBoxStyle    = {
    width       = 600,
    height      = 200,
}

--[[
local function getLeftListEntriesFull(shifterBox)
    if not shifterBox then return end
    return shifterBox:GetLeftListEntriesFull()
end

local function getRightListEntriesFull(shifterBox)
    if not shifterBox then return end
    return shifterBox:GetRightListEntriesFull()
end
]]

local function getAllMountCollectibleIds(onlyUnlocked, categoryId)
	onlyUnlocked = onlyUnlocked or false

	local doDebug = false --todo 20251011 Remove after testing
	local mountCollectibleIds = {}

	--Instead of hardcoding the categories of mounts above in table mountCategories:
	--Loop all categories, get category data and check if you can select mounts in it
	mountCategories = {}
	if categoryId ~= nil then
		local categoryData = ZO_COLLECTIBLE_DATA_MANAGER.collectibleCategoryIdToDataMap[categoryId]
		if categoryData ~= nil then
			local selectableCategoryTypes = categoryData:GetCollectibleCategoryTypesInCategory()
			if selectableCategoryTypes[COLLECTIBLE_CATEGORY_TYPE_MOUNT] == true then
				mountCategories[#mountCategories + 1] = categoryId
				if doDebug then d("[FCOS]Found mount category " ..tos(categoryId)) end
			end
		end
	else
		for categoryId, categoryData in pairs(ZO_COLLECTIBLE_DATA_MANAGER.collectibleCategoryIdToDataMap) do
			local selectableCategoryTypes = categoryData:GetCollectibleCategoryTypesInCategory()
			if selectableCategoryTypes[COLLECTIBLE_CATEGORY_TYPE_MOUNT] == true then
				mountCategories[#mountCategories + 1] = categoryId
				if doDebug then d("[FCOS]Found mount category " ..tos(categoryId)) end
			end
		end
	end

	if #mountCategories == 0 then return nil end

	--How to loop all collectibles of the type mount? -> and get it'S collectibleData
	for _, mountCategoryId in ipairs(mountCategories) do
		local collectiblesData = ZO_COLLECTIBLE_DATA_MANAGER:GetCategoryDataById(mountCategoryId)
		if collectiblesData and collectiblesData.orderedCollectibles then
			for idx, collectibleData in ipairs(collectiblesData.orderedCollectibles) do
				local collectibleId = collectibleData.collectibleId
				if collectibleId ~= nil and collectibleId ~= 0 then
					if collectibleData and collectibleData:GetCategoryType() == COLLECTIBLE_CATEGORY_TYPE_MOUNT then
						local isFavoritable = collectibleData:IsFavoritable()
						local isUnlocked = collectibleData:IsUnlocked()
						if not onlyUnlocked or (onlyUnlocked == true and isUnlocked == true) then
							mountCollectibleIds[collectibleId] = {
								categoryId = mountCategoryId,
								collectibleId = collectibleId,
								name = zo_strformat(SI_UNIT_NAME, collectibleData:GetName()),
								isUnlocked = isUnlocked,
								isFavoritable = isFavoritable,
								isFavorite = collectibleData:IsFavorite(),
							}
							if doDebug then
								local collectibleDataAdded = mountCollectibleIds[collectibleId]
								d(">Added mount collectibleId " ..tos(collectibleId) .. ": " ..tos(collectibleDataAdded.name) .. "; unlocked: " ..tos(collectibleDataAdded.isUnlocked) .. "; isFavoritable: " .. tos(collectibleDataAdded.isFavoritable) .. "; isFavorite: " .. tos(collectibleDataAdded.isFavorite))
							end
						end
					end
				end
			end
		end
	end

	--FCOCS._mountsCollectibleIds = mountCollectibleIds
	--FCOCS._mountCategories = mountCategories

	return mountCollectibleIds
end

--todo 20251011 how to detect if the current mount category got any favorites, or not?
local function isAnyMountAFavoriteAtThisCategory(categoryId)
	local categoryData = ZO_COLLECTIBLE_DATA_MANAGER.collectibleCategoryIdToDataMap[categoryId]
	if categoryData ~= nil then
		local selectableCategoryTypes = categoryData:GetCollectibleCategoryTypesInCategory()
		if selectableCategoryTypes[COLLECTIBLE_CATEGORY_TYPE_MOUNT] == true then
			--Get all collectibleIds which are unlocked and check their favorite state
			local orderedCollectibles = categoryData.orderedCollectibles
			if not ZO_IsTableEmpty(orderedCollectibles) then
				for idx, collectibleData in pairs(orderedCollectibles) do
					if collectibleData.collectibleId then
						if collectibleData:IsUnlocked() == true and collectibleData:IsFavorite() then
							return true
						end
					end
				end
			end
		end
	end
	return false
end


function FCOChangeStuff.setExcludedMountIdsState()
	--local isDisableSoundLSBEnabled            = FCOChangeStuff.settingsVars.settings.favoriteMountsContextMenu
	local leftListMountIdsWithoutExcludedOnes = {}
	local excludedMountIdsFromSV              = FCOChangeStuff.settingsVars.settings.excludedMountCollectionIdsEntries
	local mountsCollectibleIds = getAllMountCollectibleIds(false, nil)

	if NonContiguousCount(mountsCollectibleIds) == 0 then return end

	for k,v in pairs(mountsCollectibleIds) do
		--Non-excluded mount collectileIds from the SavedVariables?
		if excludedMountIdsFromSV[k] == nil then
			--Add the sound entry to the left list (non disabled)
			local mountName = v.name
			if not v.isUnlocked then
				mountName = strfor(lockedMountNamePattern, mountName) --color the mountName red if not unlocked
			end
			leftListMountIdsWithoutExcludedOnes[k] = mountName
		else
			local mountName = zo_strformat(SI_UNIT_NAME, GetCollectibleName(k))
			if not v.isUnlocked then
				excludedMountIdsFromSV[k] = strfor(lockedMountNamePattern, mountName)
			else
				excludedMountIdsFromSV[k] = mountName
			end
		end
	end
	return leftListMountIdsWithoutExcludedOnes, excludedMountIdsFromSV
end
local setExcludedMountIdsLibShifterBoxState = FCOChangeStuff.setExcludedMountIdsState

function FCOChangeStuff.updateExcludedMountIdsLibShifterBoxEntries(shifterBox)
    if not shifterBox then return end
    local leftListMountIdsWithoutExcludedOnes, excludedMountIdsFromSV = setExcludedMountIdsLibShifterBoxState()

    shifterBox:ClearLeftList()
    shifterBox:AddEntriesToLeftList(leftListMountIdsWithoutExcludedOnes)

    shifterBox:ClearRightList()
    shifterBox:AddEntriesToRightList(excludedMountIdsFromSV)
end

local function myShifterBoxEventEntryMovedCallbackFunction(shifterBox, key, value, categoryId, isDestListLeftList, fromList, toList)
--d("[FCOCS]myShifterBoxEventEntryMovedCallbackFunction - key: " ..tostring(key) .. ", isDestListLeftList:  "..tostring(isDestListLeftList))
    if not shifterBox or not key then return end
	local settings = FCOChangeStuff.settingsVars.settings
    if not settings.favoriteMountsContextMenu then return end

    --Moved to the left?
    if isDestListLeftList == true then
        settings.excludedMountCollectionIdsEntries[key] = nil
    else
        --Moved to the right?
        settings.excludedMountCollectionIdsEntries[key] = value
    end

end

local function myShifterBoxEventEntryHighlightedCallbackFunction(control, shifterBox, key, value, categoryId, isLeftList)
    if not shifterBox or not key then return end
    if not FCOChangeStuff.settingsVars.settings.favoriteMountsContextMenu then return end

    if isLeftList == true then
    else
    end
end

local function updateExcludedMountIdsShifterBox(parentCtrl)
    local excludedMountIdsShifterBoxControl = FCOChangeStuff.excludedMountIdsShifterBoxControl
    if not excludedMountIdsShifterBoxControl or not parentCtrl then return end
    parentCtrl:SetResizeToFitDescendents(true)

    excludedMountIdsShifterBoxControl:SetAnchor(TOPLEFT, parentCtrl, TOPLEFT, 0, 0) -- will automatically call ClearAnchors
    excludedMountIdsShifterBoxControl:SetDimensions(excludedMountIdsLibShifterBoxStyle.width, excludedMountIdsLibShifterBoxStyle.height)

    FCOChangeStuff.updateExcludedMountIdsLibShifterBoxEntries(excludedMountIdsShifterBoxControl)
    FCOChangeStuff.updateExcludedMountIdsLibShifterBoxState(parentCtrl, excludedMountIdsShifterBoxControl)

    --Add the callback function to the entry was moved event
    excludedMountIdsShifterBoxControl:RegisterCallback(FCOChangeStuff.LSB.EVENT_ENTRY_MOVED, myShifterBoxEventEntryMovedCallbackFunction)
    --Add the callback for the PlaySound as an entry was highlighted at the left side
    excludedMountIdsShifterBoxControl:RegisterCallback(FCOChangeStuff.LSB.EVENT_ENTRY_HIGHLIGHTED, myShifterBoxEventEntryHighlightedCallbackFunction)
end

function FCOChangeStuff.updateExcludedMountIdsLibShifterBoxState(parentCtrl, excludedMountIdsShifterBox)
    excludedMountIdsShifterBox = excludedMountIdsShifterBox or FCOChangeStuff.excludedMountIdsShifterBoxControl
    if not parentCtrl or not excludedMountIdsShifterBox then return end
    local isExcludeMountIdsLSBEnabled = FCOChangeStuff.settingsVars.settings.favoriteMountsContextMenu
    parentCtrl:SetHidden(false)
    parentCtrl:SetMouseEnabled(isExcludeMountIdsLSBEnabled)
    excludedMountIdsShifterBox:SetHidden(false)
    excludedMountIdsShifterBox:SetEnabled(isExcludeMountIdsLSBEnabled)
end

function FCOChangeStuff.buildExcludedMountIdsLibShifterBox(parentCtrl)
    if parentCtrl == nil then return end
    local addonName = FCOChangeStuff.addonVars.addonName

    FCOChangeStuff.LSB = LibShifterBox
    local excludedMountIdsShifterBox              = FCOChangeStuff.LSB(addonName, "FCOCHANGESTUFF_LAM_MOUNT_FAVORITES_EXCLUDE_PARENT_LSB", parentCtrl, excludedMountIdsLibShifterBoxSettings)
    FCOChangeStuff.excludedMountIdsShifterBoxControl = excludedMountIdsShifterBox
    updateExcludedMountIdsShifterBox(parentCtrl)
end

function FCOChangeStuff.getExcludedMountIdsLibShifterBox(parentCtrl)
    if parentCtrl == nil then return end
    FCOChangeStuff.updateExcludedMountIdsLibShifterBox(parentCtrl)
    return FCOChangeStuff.excludedMountIdsShifterBoxControl
end

function FCOChangeStuff.updateExcludedMountIdsLibShifterBox(parentCtrl)
    if parentCtrl == nil then return end
	if FCOChangeStuff.excludedMountIdsShifterBoxControl == nil then
		FCOChangeStuff.buildExcludedMountIdsLibShifterBox(parentCtrl)
	else
		updateExcludedMountIdsShifterBox(parentCtrl)
	end
end



-- Mount favorites context menu etc.
local function changeMountFavorites(doAdd, categoryId)
--d("[FCOCS]changeMountFavorites, doAdd: " .. tos(doAdd) .. ", categoryId: " .. tos(categoryId))
	local excludedMountCollectionIds = FCOChangeStuff.settingsVars.settings.excludedMountCollectionIdsEntries
	local counter = 0

	--Get all favoritable mount collectibleIds of all categories
	local mountsCollectibleIds = getAllMountCollectibleIds(true, categoryId)
	if NonContiguousCount(mountsCollectibleIds) == 0 then return end

	for collectibleId, collectibleData in pairs(mountsCollectibleIds) do
		if collectibleId ~= nil and collectibleId ~= 0 then
			if categoryId == nil or (categoryId ~= nil and categoryId == collectibleData.categoryId) then
				if collectibleData.isUnlocked and collectibleData.isFavoritable then
					local setCollectibleNow = false
					local isFavorite = collectibleData.isFavorite
					if (doAdd == true and not isFavorite) and not excludedMountCollectionIds[collectibleId] then
						counter = counter + 1
						setCollectibleNow = true
					elseif doAdd == false and isFavorite == true then
						counter = counter + 1
						setCollectibleNow = true
					end
					if setCollectibleNow == true then
						SetOrClearCollectibleUserFlag(collectibleData.collectibleId, COLLECTIBLE_USER_FLAG_FAVORITE, doAdd)
						d(((doAdd == true and "!> Added to") or "<! Removed from") .." favorite mounts - #" .. tos(counter) ..": " .. tos(collectibleData.name) .. " [Category/Collectible ID: " .. tos(zo_strformat(SI_UNIT_NAME, GetCollectibleCategoryNameByCollectibleId(collectibleId))) .. "/" .. tos(collectibleId) .."]")
					end
				end
			end
		end
	end
end

local colorRed = ZO_ColorDef:New(1, 0, 0, 1)
local favoritesExcludedListStatusIcon = "/esoui/art/buttons/cancel_down.dds"
local favoritesExcludedListStatusIconText = zo_iconTextFormatNoSpace(favoritesExcludedListStatusIcon, 24, 24, "excluded list", true)

local function updateCollectibleStatusTexture(control, clearStatus, collectibleData, selfVar) --ZO_CollectionsBook_TopLevelListContainerListContents1Control2Status
	if control == nil then return end
	local statusCtrl = control:GetNamedChild("Status") or control
	if statusCtrl == nil or statusCtrl.ClearIcons == nil then return end


	statusCtrl:ClearIcons()
	local actorCategory = selfVar:GetActorCategory()
	if collectibleData:IsActive(actorCategory) and not collectibleData:ShouldSuppressActiveState(actorCategory) then
		statusCtrl:AddIcon(ZO_CHECK_ICON)

		if collectibleData:WouldBeHidden(actorCategory) then
			statusCtrl:AddIcon("EsoUI/Art/Inventory/inventory_icon_hiddenBy.dds")
		end
	end
	if collectibleData:IsNew() then
		statusCtrl:AddIcon(ZO_KEYBOARD_NEW_ICON)
	end
	if not clearStatus then
		statusCtrl:AddIcon(favoritesExcludedListStatusIcon, colorRed)
	end
	statusCtrl:Show()
end

function FCOChangeStuff.BuildFavoriteMountsContextMenu()
	if not FCOChangeStuff.settingsVars.settings.favoriteMountsContextMenu then return end

	if collectibleMountTilesHooked then return end

	--ZO_CollectibleTile_Keyboard:LayoutPlatform(data)
	ZO_PostHook(ZO_CollectibleTile_Keyboard, "LayoutPlatform", function(selfVar, data)
		if not FCOChangeStuff.settingsVars.settings.favoriteMountsContextMenu then return end
		local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(data.collectibleId)
		if collectibleData:IsUnlocked() then
			--Is this a mount?
			local categoryId = collectibleData:GetCategoryId()
			local categoryData = (categoryId ~= nil and ZO_COLLECTIBLE_DATA_MANAGER.collectibleCategoryIdToDataMap[categoryId]) or nil
			if categoryData ~= nil then
				local selectableCategoryTypes = categoryData:GetCollectibleCategoryTypesInCategory()
				if selectableCategoryTypes[COLLECTIBLE_CATEGORY_TYPE_MOUNT] == true then
					local statusMultiIcon = selfVar.statusMultiIcon
					if statusMultiIcon == nil then return end

					local excludedMountCollectionIds = FCOChangeStuff.settingsVars.settings.excludedMountCollectionIdsEntries
					local collectibleId = collectibleData.collectibleId
					local clearStatus = (excludedMountCollectionIds[collectibleId] == nil and true) or false
					updateCollectibleStatusTexture(statusMultiIcon, clearStatus, collectibleData, selfVar)
				end
			end
		end
	end)

	--ZO_CollectibleTile_Keyboard:AddMenuOptions()
	ZO_PostHook(ZO_CollectibleTile_Keyboard, "AddMenuOptions", function(selfVar)
		if not FCOChangeStuff.settingsVars.settings.favoriteMountsContextMenu then return end
		if not ZO_CollectibleDataManager:HasAnyUnlockedMounts() then return end
		local mocCtrl = GetMenuOwner() or moc()
--d(">mocCtrl: " .. tos(mocCtrl:GetName()))

		local excludedMountCollectionIds = FCOChangeStuff.settingsVars.settings.excludedMountCollectionIdsEntries

		local collectibleData = selfVar.collectibleData
		local collectibleId = collectibleData.collectibleId
		local collectibleName = zo_strformat(SI_UNIT_NAME, collectibleData:GetName())
		local categoryName = zo_strformat(SI_UNIT_NAME, collectibleData:GetCategoryName()) or "n/a"
		local categoryId = collectibleData:GetCategoryId()
		local isFavorite = collectibleData:IsFavorite()

		if collectibleData:GetCategoryType() == COLLECTIBLE_CATEGORY_TYPE_MOUNT and collectibleData:IsUnlocked() then

			AddCustomMenuItem("[FCOChangeStuff] Mount favorites", function()  end, MENU_ADD_OPTION_HEADER)
			AddCustomMenuItem("|c00FF00Add|r category \'".. categoryName .. "\' to favorites", function()
				changeMountFavorites(true, categoryId)
			end)
			AddCustomMenuItem("|c00FF00Add all|r mounts to favorites", function()
				changeMountFavorites(true)
			end)
			if ZO_CollectibleDataManager:HasAnyFavoriteMounts() then
				AddCustomMenuItem("-")
				local anyFavoriteAtThisCategory = isFavorite == true or isAnyMountAFavoriteAtThisCategory(categoryId)
				if anyFavoriteAtThisCategory then
					AddCustomMenuItem("[|cFF0000Remove|r category \'".. categoryName .. "\' from favorites", function()
						changeMountFavorites(false, categoryId)
					end)
				end
				AddCustomMenuItem("|cFF0000Remove all|r mounts from favorites", function()
					changeMountFavorites(false)
				end)
			end
			AddCustomMenuItem("Mount favorites |cFF0000" .. favoritesExcludedListStatusIconText ..  "|r", function()  end, MENU_ADD_OPTION_HEADER)
			if not excludedMountCollectionIds[collectibleId] then
				AddCustomMenuItem(">|c00FF00Add|r mount to list", function()
					if isFavorite == true then
						SetOrClearCollectibleUserFlag(collectibleId, COLLECTIBLE_USER_FLAG_FAVORITE, false)
						d("<! Removed from favorite mounts: " .. tos(collectibleName) .. " [Category/Collectible ID: " .. tos(zo_strformat(SI_UNIT_NAME, GetCollectibleCategoryNameByCollectibleId(collectibleId))) .. "/" .. tos(collectibleId) .."]")
					end
					excludedMountCollectionIds[collectibleId] = collectibleName
					updateCollectibleStatusTexture(mocCtrl, false, collectibleData, selfVar)
				end)
			else
				AddCustomMenuItem("<|cFF0000Remove|r mount from list", function()
					excludedMountCollectionIds[collectibleId] = nil
					updateCollectibleStatusTexture(mocCtrl, true, collectibleData, selfVar)
				end)
			end
			if NonContiguousCount(excludedMountCollectionIds) > 0 then
				AddCustomMenuItem("<|cFF0000Remove all|r mounts from list", function()
					--todo Show dialog to ask before removing all?
					FCOChangeStuff.settingsVars.settings.excludedMountCollectionIdsEntries = {}
					updateCollectibleStatusTexture(mocCtrl, true, collectibleData, selfVar)
					--Update the currently shown tiles at the mount category, all of them
					--ZO_CollectionsBook:UpdateCollectionVisualLayer()
					COLLECTIONS_BOOK:UpdateCollectionVisualLayer()
				end)
			end
			ShowMenu()
		end
	end)
	collectibleMountTilesHooked = true
end


function FCOChangeStuff.favoriteMountChanges()
	FCOChangeStuff.setExcludedMountIdsState()
	FCOChangeStuff.BuildFavoriteMountsContextMenu()
end
