tim99sColoredLists = tim99sColoredLists or {}
local tcl = tim99sColoredLists

tcl.name    = "tim99sColoredLists"
tcl.author  = "tim99"
tcl.svChar  = {}
tcl.col_tim = ZO_ColorDef:New("9b30ff")

tcl.totalCurrentlyCollected  = 0
tcl.totalPossibleCollected   = 0
tcl.motifsCurrentlyCollected = 0
tcl.motifsPossibleCollected  = 0

tcl.svCharDef = {
	colorDone="66ff66",  --grn
	colorOpen="ff6666",  --red
	colorQueue="9b30ff", --milka
	--
	doLorebooks=true,
	doSetCollection=true,
	doSetCollectHeader=true,
	doAchievements=true,
	doAchievHeader=true,
	doDungeonQueue=true,
	doBlueprints=true,
	doAntiquities=true,
	doAntiquHeader=true,
	--
	showAchieveSums=true,
	showAntiqueSums=true,
	showSetsSums=true,
	--
	collapseSetDone=true,
}
--/script d(ZO_NORMAL_TEXT:UnpackRGB())
--/script d(SCENE_MANAGER:GetCurrentScene():GetName())
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
function tcl:GetTextColor()
	local b,c,d,e=self.normalColor:UnpackRGBA()
	if self.selected then return b,c,d,0.4 elseif self.mouseover then return b,c,d,0.7 end;
	return b,c,d,e 
end;
------------------------------------------------------------------------------------------
function tcl.doMotifs()
	local includeMotifsCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)TCL_IncludeMotifs", LORE_LIBRARY.totalCollectedLabel, "ZO_CheckButton")
	includeMotifsCheckbox:SetAnchor(LEFT, LORE_LIBRARY.totalCollectedLabel, RIGHT, 60, 0)
	ZO_CheckButton_SetLabelText(includeMotifsCheckbox, "include Motifs")
	ZO_CheckButton_SetToggleFunction(includeMotifsCheckbox, function() LORE_LIBRARY:RefreshCollectedInfo() end)
	LORE_LIBRARY.RefreshCollectedInfo = function(library) --dont understand where "library" comes from
		local currentlyCollected = tcl.totalCurrentlyCollected
		local possibleCollected = tcl.totalPossibleCollected
		if not ZO_CheckButton_IsChecked(includeMotifsCheckbox) then
			currentlyCollected = currentlyCollected - tcl.motifsCurrentlyCollected
			possibleCollected = possibleCollected - tcl.motifsPossibleCollected
		end
		library.totalCollectedLabel:SetText(zo_strformat(SI_LORE_LIBRARY_TOTAL_COLLECTED, currentlyCollected, possibleCollected))
	end
end
------------------------------------------------------------------------------------------
function tcl.AchievementSetupFunction(node, control, data, open, userRequested, enabled)
	-- >>> Farbe berechnen
	local numAch, subEarned, subTotal
	local parentData = data.parentData
	if not data.isFakedSubcategory and parentData then
		numAch,subEarned,subTotal = select(2,GetAchievementSubCategoryInfo(parentData.categoryIndex, data.categoryIndex))
	else
		local numSubCat,numAchie,earnedPnt,totalPnt,hidesP = select(2,GetAchievementCategoryInfo(data.categoryIndex))
		if parentData then
			for subCatIndex = 1, numSubCat do
				local subCatEarned,subCatTotal = select(3,GetAchievementSubCategoryInfo(parentData.categoryIndex, subCatIndex))
				earnedPnt = earnedPnt - subCatEarned
				totalPnt = totalPnt - subCatTotal
			end
		end
		subEarned = earnedPnt
		subTotal = totalPnt
	end
	local col = (subEarned == subTotal) and tcl.col_grn or tcl.col_red
	-- Farbe berechnen <<<
	ZO_SelectableLabel_SetNormalColor(control, col)
	if control.GetTextColor ~= tcl.GetTextColor then control.GetTextColor = tcl.GetTextColor end
	control:RefreshTextColor()
	local subMiss = subTotal - subEarned
	if tcl.svChar.showAchieveSums and subMiss > 0 then
		local oldTxt = control:GetText()
		--local newTxt = tcl.col_red:Colorize(string.format("%s", subMiss)) --ZO_WHITE / ZO_OFF_WHITE / ZO_DEFAULT_TEXT / ZO_NORMAL_TEXT
		if (GetCVar('language.2') == 'de') then
			if string.match(oldTxt, "Herausforderungsschwierigkeit") then oldTxt="Herausf.-Schwierigkeit" end --very ugly
		end
		control:SetText(string.format("%s (%s)", tostring(oldTxt), tostring(subMiss)))
	end
end
------------------------------------------------------------------------------------------
function tcl.ColorAchievementHeader(control, data)
    if not data.categoryIndex then return end
	if tonumber(data.categoryIndex)==nil then return end
    local numSubCat,numAchie,earnedPnt,totalPnt,hidesP = select(2,GetAchievementCategoryInfo(data.categoryIndex))
    local complete = (earnedPnt == totalPnt)

    local col = complete and tcl.col_grn or ZO_NORMAL_TEXT --tcl.col_red
	if control.text then
		ZO_SelectableLabel_SetNormalColor(control.text, col)
		if control.text.GetTextColor ~= tcl.GetTextColor then control.text.GetTextColor = tcl.GetTextColor end
		if control.text.RefreshTextColor then control.text:RefreshTextColor() end
	end
end
------------------------------------------------------------------------------------------
function tcl.RecipeSetupFunction(node, control, data, open, userRequested, enabled)
	tcl.oldRecipeSetupFunction(node,control,data,open,userRequested,enabled)
	local r,g,b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, data.quality)
	ZO_SelectableLabel_SetNormalColor(control, ZO_ColorDef:New(r,g,b))
	if control.GetTextColor ~= tcl.GetTextColor then control.GetTextColor = tcl.GetTextColor end
	control:RefreshTextColor()
end
------------------------------------------------------------------------------------------
function tcl.GetAntiquityLoreProgress(categoryData)
	local maxLoreEntries = 0
	local unlockedLoreEntries = 0
	if categoryData.AntiquityIterator then
		for _, antiquityData in categoryData:AntiquityIterator({ZO_Antiquity.IsVisible}) do
			local antiquityId = antiquityData:GetId()
			local tileData = ANTIQUITY_DATA_MANAGER:GetAntiquityData(antiquityId)
			maxLoreEntries = maxLoreEntries + tileData:GetNumLoreEntries()
			unlockedLoreEntries = unlockedLoreEntries + tileData:GetNumUnlockedLoreEntries()
		end
	end
	if categoryData.SubcategoryIterator then
		for _, subCategoryData in categoryData:SubcategoryIterator() do
			local subUnlocked, subMax = tcl.GetAntiquityLoreProgress(subCategoryData)
			unlockedLoreEntries = unlockedLoreEntries + subUnlocked
			maxLoreEntries = maxLoreEntries + subMax
		end
	end
	return unlockedLoreEntries, maxLoreEntries
end
------------------------------------------------------------------------------------------
function tcl.ColorAntiquityHeader(control, data)
	if not data then return end
	local unlockedLoreEntries, maxLoreEntries = tcl.GetAntiquityLoreProgress(data)
	local col
	if maxLoreEntries == 0 then
		col = ZO_NORMAL_TEXT
	elseif unlockedLoreEntries == maxLoreEntries then
		col = tcl.col_grn
	else
		col = ZO_NORMAL_TEXT
	end
	if control.text then
		ZO_SelectableLabel_SetNormalColor(control.text, col)
		if control.text.GetTextColor ~= tcl.GetTextColor then control.text.GetTextColor = tcl.GetTextColor end
		control.text:RefreshTextColor()
	end
end
------------------------------------------------------------------------------------------
function tcl.CollapseCompletedSets()
	local keyboardBook = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD
	if not keyboardBook or not keyboardBook.collapsedSetIds then return end
	if tcl.completedSetsCollapsed then return end 
	tcl.completedSetsCollapsed = true
	for _, itemSetCollectionData in ITEM_SET_COLLECTIONS_DATA_MANAGER:ItemSetCollectionIterator() do
		local isComplete = itemSetCollectionData:GetNumPieces()	== itemSetCollectionData:GetNumUnlockedPieces()
		keyboardBook.collapsedSetIds[itemSetCollectionData:GetId()] = isComplete
	end
end
------------------------------------------------------------------------------------------	
------------------------------------------------------------------------------------------
local function OnPlayerActivated()
	EVENT_MANAGER:UnregisterForEvent(tcl.name, EVENT_PLAYER_ACTIVATED)

	--Lorebooks
--	if tcl.svChar.doLorebooks then
--		SecurePostHook(LORE_LIBRARY.navigationTree.templateInfo.ZO_LoreLibraryNavigationEntry, "setupFunction", function(h,i,j,k,l,m)
--			local c = j.totalBooks == j.numKnownBooks and tcl.col_grn or tcl.col_red;
--			ZO_SelectableLabel_SetNormalColor(i, c)
--			if i.GetTextColor ~= tcl.GetTextColor then i.GetTextColor = tcl.GetTextColor end;
--			i:RefreshTextColor()
--			tcl.totalCurrentlyCollected = tcl.totalCurrentlyCollected + j.numKnownBooks
--			tcl.totalPossibleCollected = tcl.totalPossibleCollected + j.totalBooks
--			if j.categoryIndex == 2 then --Motifs
--			  tcl.motifsCurrentlyCollected = tcl.motifsCurrentlyCollected + j.numKnownBooks
--			  tcl.motifsPossibleCollected = tcl.motifsPossibleCollected + j.totalBooks
--			end			
--		end)		
--	end
	
	--Lorebooks neu
	if tcl.svChar.doLorebooks then
		SecurePostHook(
			LORE_LIBRARY.navigationTree.templateInfo.ZO_LoreLibraryNavigationEntry, "setupFunction", function(h, i, j, k, l, m)
				local knownBooks = j.numKnownBooks or j.numUnlocked
				local totalBooks = j.totalBooks or j.total
				if knownBooks ~= nil and totalBooks ~= nil then
					local c
					if totalBooks == 0 then c = ZO_NORMAL_TEXT            -- Keine Einträge vorhanden
					elseif knownBooks == totalBooks then c = tcl.col_grn  -- Vollständig
					else c = tcl.col_red                                  -- Unvollständig
					end
					ZO_SelectableLabel_SetNormalColor(i, c)
					if i.GetTextColor ~= tcl.GetTextColor then i.GetTextColor = tcl.GetTextColor end
					i:RefreshTextColor()
					tcl.totalCurrentlyCollected = tcl.totalCurrentlyCollected + knownBooks
					tcl.totalPossibleCollected = tcl.totalPossibleCollected + totalBooks
					if j.categoryIndex == 2 then -- Motifs
						tcl.motifsCurrentlyCollected = tcl.motifsCurrentlyCollected + knownBooks
						tcl.motifsPossibleCollected = tcl.motifsPossibleCollected + totalBooks
					end
				end
			end
		)
		ZO_PreHook(LORE_LIBRARY, "BuildCategoryList", function()
			tcl.totalCurrentlyCollected  = 0
			tcl.totalPossibleCollected   = 0
			tcl.motifsCurrentlyCollected = 0
			tcl.motifsPossibleCollected  = 0
		end)
	end
	
	--SetCollection
	if tcl.svChar.doSetCollection then
		SecurePostHook(ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.categoryTree.templateInfo.ZO_TreeStatusLabelSubCategory, "setupFunction", function(h,i,j,k,l,m)
			local o, p = j:GetNumUnlockedAndTotalPieces()
			local c = o == p and tcl.col_grn or tcl.col_red
			ZO_SelectableLabel_SetNormalColor(i, c)
			if i.GetTextColor ~= tcl.GetTextColor then i.GetTextColor = tcl.GetTextColor end
			i:RefreshTextColor()
			local miss = p - o
			if tcl.svChar.showSetsSums and miss > 0 then
				local oldTxt = i:GetText()
				if (GetCVar('language.2') == 'de') then
					if string.match(oldTxt, "Abgeschiedenen") then oldTxt="Schanze d.Abgeschiedenen" end --very ugly
				end
				i:SetText(string.format("%s (%s)", tostring(oldTxt), tostring(miss)))
			end
		end)
		ZO_PostHook(ZO_ItemSetsBook_Keyboard,"RefreshCategoryProgress",function(self) local itemSetCollectionCategoryData=self:GetSelectedCategory()
			if itemSetCollectionCategoryData then if self:IsReconstructing()==false then local numUnlockedPieces,numPieces=itemSetCollectionCategoryData:GetNumUnlockedAndTotalPieces()
				self.categoryProgressLabel:SetText(zo_strformat(SI_ITEM_SETS_BOOK_CATEGORY_PROGRESS,numUnlockedPieces,numPieces).."  ("..tostring(math.floor((numUnlockedPieces/numPieces)*100)).."%)") end
			end
		end)
		ZO_PostHook(ZO_ItemSetsBook_Keyboard,"SetupGridHeaderEntry",function(self,control,data,selected) local itemSetHeaderData=data.header
			local progressBarLabel=control.progressBar:GetNamedChild("Progress") local numUnlockedPieces=itemSetHeaderData:GetNumUnlockedPieces() local numPieces=itemSetHeaderData:GetNumPieces()
			progressBarLabel:SetText(zo_strformat(SI_ITEM_SETS_BOOK_CATEGORY_PROGRESS,numUnlockedPieces,numPieces).."  (".. tostring(math.floor((numUnlockedPieces/numPieces)*100)).."%)")
		end)
	end
	
	--SetCollection Header
	if tcl.svChar.doSetCollectHeader then
		SecurePostHook(ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.categoryTree.templateInfo.ZO_StatusIconHeader, "setupFunction", function(node, control, data, open, userRequested, enabled)
			if not data.dataSource then return end
			local unlocked, total = data.dataSource:GetNumUnlockedAndTotalPieces()
			local col =	(unlocked == total)	and tcl.col_grn	or ZO_NORMAL_TEXT
			if control.text then
				ZO_SelectableLabel_SetNormalColor(control.text, col)
				if control.text.GetTextColor ~= tcl.GetTextColor then control.text.GetTextColor = tcl.GetTextColor end
				control.text:RefreshTextColor()
			end
		end)
	end
	
	--Achievements
	if tcl.svChar.doAchievements or tcl.svChar.doAchievHeader then
		SecurePostHook(ACHIEVEMENTS, "OnDeferredInitialize", function()
			--Unterbäume
			if tcl.svChar.doAchievements then
				SecurePostHook(ACHIEVEMENTS.categoryTree.templateInfo.ZO_Achievements_SubCategory, "setupFunction",	function(node, control, data, open, userRequested, enabled)
					tcl.AchievementSetupFunction(node, control, data, open, userRequested, enabled)
				end)
			end
			--Header mit Childs und ohne Childs
			if tcl.svChar.doAchievHeader then
				SecurePostHook(ACHIEVEMENTS.categoryTree.templateInfo.ZO_Achievements_StatusIconHeader, "setupFunction", function(node, control, data, open, userRequested, enabled)
					tcl.ColorAchievementHeader(control, data)
				end)
				SecurePostHook(ACHIEVEMENTS.categoryTree.templateInfo.ZO_Achievements_StatusIconChildlessHeader, "setupFunction", function(node, control, data, open, userRequested, enabled)
					tcl.ColorAchievementHeader(control, data)
				end)
			end
			ACHIEVEMENTS.refreshGroups:RefreshAll("FullUpdate")
		end)	
	end
	
	--Antiquities
	if tcl.svChar.doAntiquities or tcl.svChar.doAntiquHeader then
		SecurePostHook(ANTIQUITY_JOURNAL_KEYBOARD, "OnDeferredInitialize", function()
			--Unterbäume
			if tcl.svChar.doAntiquities then
				SecurePostHook(ANTIQUITY_JOURNAL_KEYBOARD.categoryTree.templateInfo.ZO_AntiquityJournal_SubCategory, "setupFunction", function(node,control,data,open,userRequested,enabled)
					local maxLoreEntries = 0
					local unlockedLoreEntries = 0
					for _, antiquityData in data:AntiquityIterator({ZO_Antiquity.IsVisible}) do
						local antiquityId = antiquityData:GetId()
						local myTileData = ANTIQUITY_DATA_MANAGER:GetAntiquityData(antiquityId)
						maxLoreEntries = maxLoreEntries + myTileData:GetNumLoreEntries()
						unlockedLoreEntries = unlockedLoreEntries + myTileData:GetNumUnlockedLoreEntries()
					end	
					local col = (maxLoreEntries == unlockedLoreEntries) and tcl.col_grn or tcl.col_red
					ZO_SelectableLabel_SetNormalColor(control, col)
					if control.GetTextColor ~= tcl.GetTextColor then control.GetTextColor = tcl.GetTextColor end
					control:RefreshTextColor()
					local miss = maxLoreEntries - unlockedLoreEntries
					if tcl.svChar.showAntiqueSums and miss > 0 then
						local oldTxt = control:GetText()
						if (GetCVar('language.2') == 'de') then
							if string.match(oldTxt, "Himmelsrand") then oldTxt="Westl. Himmelrand" end --very ugly
							if string.match(oldTxt, "Sonnenwende") then oldTxt="Westl. Sonnenwende" end --very ugly
						end
						control:SetText(string.format("%s (%s)", tostring(oldTxt), tostring(miss)))
					end
				end)
			end
			--Header mit Childs und ohne Childs
			if tcl.svChar.doAntiquHeader then
				SecurePostHook(ANTIQUITY_JOURNAL_KEYBOARD.categoryTree.templateInfo.ZO_AntiquityJournal_StatusIconHeader, "setupFunction", function(node,control,data,open,userRequested,enabled)
					tcl.ColorAntiquityHeader(control, data)
				end)
				SecurePostHook(ANTIQUITY_JOURNAL_KEYBOARD.categoryTree.templateInfo.ZO_AntiquityJournal_StatusIconChildlessHeader, "setupFunction", function(node,control,data,open,userRequested,enabled)
					tcl.ColorAntiquityHeader(control, data)
				end)
			end
		end)
	end

	--DungeonQueue
	if tcl.svChar.doDungeonQueue then
		SecurePostHook(DUNGEON_FINDER_KEYBOARD.navigationTree.templateInfo.ZO_ActivityFinderTemplateNavigationEntry_Keyboard, "setupFunction", function(h,i,j,k,l,m)
			local c = j.isSelected and tcl.col_pur or ZO_NORMAL_TEXT;
			ZO_SelectableLabel_SetNormalColor(i.text, c)
			if i.text.GetTextColor~=tcl.GetTextColor then i.text.GetTextColor=tcl.GetTextColor end;
			i.text:RefreshTextColor()
		end)
		SecurePostHook("ZO_ActivityFinderTemplateNavigationEntryKeyboard_OnClicked", function(control, button)
			ZO_SelectableLabel_SetNormalColor(control.text, control.node.data.isSelected and tcl.col_pur or ZO_NORMAL_TEXT)
			control.text:RefreshTextColor()
		end)
	end

	--Blueprints
	if tcl.svChar.doBlueprints then
		EVENT_MANAGER:RegisterForEvent(tcl.name, EVENT_CRAFTING_STATION_INTERACT, function(eventCode,craftingType)
			if GetDisplayName()=="@tïm'99" then zo_callLater(function() CHAT_SYSTEM:Maximize() end,100) end
			if tcl.oldRecipeSetupFunction==nil then
				tcl.oldRecipeSetupFunction=PROVISIONER.recipeTree.templateInfo.ZO_ProvisionerNavigationEntry.setupFunction
				PROVISIONER.recipeTree.templateInfo.ZO_ProvisionerNavigationEntry.setupFunction = tcl.RecipeSetupFunction
			end	
		end)
	end
end
------------------------------------------------------------------------------------------
function tcl.addonLoaded(event, addonName)
	if addonName ~= tcl.name then return end
	EVENT_MANAGER:UnregisterForEvent(tcl.name, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(tcl.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	
	tcl.svChar = ZO_SavedVars:NewAccountWide("Tim99sColoredLists", 1, nil, tcl.svCharDef, GetWorldName())
	tcl.col_grn = ZO_ColorDef:New(tcl.svChar.colorDone)
	tcl.col_red = ZO_ColorDef:New(tcl.svChar.colorOpen)
	tcl.col_pur = ZO_ColorDef:New(tcl.svChar.colorQueue)
	
	tcl.initMenu() --LibAddonMenu2
	
	--komplette Sets im Stickerbuch zuklappen (im OnPlayerActivated() ists zu spät)
	if tcl.svChar.collapseSetDone then
		ZO_PreHook(ITEM_SET_COLLECTIONS_DATA_MANAGER, "SortTopLevelCategories", function()
			tcl.completedSetsCollapsed = false
			tcl.CollapseCompletedSets()
		end)
		SCENE_MANAGER:GetScene("itemSetsBook"):RegisterCallback("StateChange", function(oldState, newState)
			if newState == SCENE_SHOWING then
				tcl.CollapseCompletedSets()
			end
		end)
	end

	if GetDisplayName()=="@tïm'99" and not LoreBooks then
		--copied parts of RefreshCollectedInfo/XML from LoreBooks, ask for permission before publishing
		tcl.doMotifs()
	end

end
------------------------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(tcl.name, EVENT_ADD_ON_LOADED, tcl.addonLoaded)