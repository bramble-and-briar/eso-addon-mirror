local LCCC = LibCodesCommonCode
local Internal = LibCharacterKnowledgeInternal
local Public = LibCharacterKnowledge


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- Item categories
Public.ITEM_CATEGORY_NONE = 0
Public.ITEM_CATEGORY_RECIPE = 1
Public.ITEM_CATEGORY_PLAN = 2
Public.ITEM_CATEGORY_MOTIF = 3
Public.ITEM_CATEGORY_SCRIBING = 4
Public.ITEM_CATEGORIES = {
	[Public.ITEM_CATEGORY_RECIPE] = Internal.CategoryLabels[Internal.CATEGORY_RECIPE],
	[Public.ITEM_CATEGORY_PLAN] = Internal.CategoryLabels[Internal.CATEGORY_PLAN],
	[Public.ITEM_CATEGORY_MOTIF] = Internal.CategoryLabels[Internal.CATEGORY_MOTIF],
	[Public.ITEM_CATEGORY_SCRIBING] = Internal.CategoryLabels[Internal.CATEGORY_SCRIBING],
}

-- Knowledge state
Public.KNOWLEDGE_INVALID = Internal.KNOWLEDGE_INVALID -- Not a recipe, furnishing plan, motif, or scribing item
Public.KNOWLEDGE_NODATA = Internal.KNOWLEDGE_NODATA -- No data for this character
Public.KNOWLEDGE_KNOWN = Internal.KNOWLEDGE_KNOWN
Public.KNOWLEDGE_UNKNOWN = Internal.KNOWLEDGE_UNKNOWN

-- Callback events
Public.EVENT_INITIALIZED = 1
Public.EVENT_UPDATE_REFRESH = 2


--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

function Public.GetServerList( )
	-- Get the list of valid servers, with the current server always in the first index
	return LCCC.GetSortedKeys(Internal.characters, Internal.server)
end

function Public.GetFilteredServerList( )
	-- Same as GetServerList, but with "empty" servers filtered out
	if (not Internal.cachedFilteredServerList) then
		Internal.cachedFilteredServerList = { }
		for i, server in ipairs(Public.GetServerList()) do
			-- Filter out empties, but current server must remain even if empty
			if (i == 1 or next(Public.GetCharacterList(server))) then
				table.insert(Internal.cachedFilteredServerList, server)
			end
		end
	end
	return Internal.cachedFilteredServerList
end

function Public.GetCharacterList( server )
	if (not Internal.initialized) then return { } end

	server = server or Internal.server

	-- Get and cache the list of enabled characters
	if (not Internal.cachedCharLists[server]) then
		local results = { }

		if (Internal.characters[server]) then
			local charIds = { }
			for id in pairs(Internal.characters[server]) do
				if (Internal.IsCharacterEnabled(server, id)) then
					table.insert(charIds, id)
				end
			end
			Internal.Sort(server, charIds, true)

			for _, id in ipairs(charIds) do
				local data = Internal.characters[server][id]
				table.insert(results, {
					id = id,
					account = data.account,
					name = data.name,
				})
			end
		end

		Internal.cachedCharLists[server] = results
	end

	return Internal.cachedCharLists[server]
end

function Public.GetCharacterNameAndAccount( server, charId )
	server = server or Internal.server
	charId = charId or Internal.charId
	if (server == Internal.server and charId == Internal.charId) then
		return GetUnitName("player"), Internal.userId
	else
		return Internal.GetCharRawData(server, charId, "name"), Internal.GetCharRawData(server, charId, "account")
	end
end

function Public.GetItemLinkFromItemId( itemId, linkStyle )
	if (linkStyle == LINK_STYLE_BRACKETS) then
		return "|H1:item:" .. itemId .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
	else
		return Internal.GetItemLink(itemId)
	end
end

function Public.GetItemName( item )
	if (type(item) == "number") then
		item = Internal.GetItemLink(item)
	elseif (type(item) ~= "string") then
		return ""
	end
	return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(item))
end

do
	local TRANSLATE_CATEGORY = {
		[Internal.CATEGORY_RECIPE] = Public.ITEM_CATEGORY_RECIPE,
		[Internal.CATEGORY_PLAN] = Public.ITEM_CATEGORY_PLAN,
		[Internal.CATEGORY_MOTIF] = Public.ITEM_CATEGORY_MOTIF,
		[Internal.CATEGORY_SCRIBING] = Public.ITEM_CATEGORY_SCRIBING,
	}

	function Public.GetItemCategory( item )
		local category = Internal.GetItemCategoryAndQuality(item)

		if (category) then
			return TRANSLATE_CATEGORY[category]
		else
			return Public.ITEM_CATEGORY_NONE
		end
	end
end

function Public.GetItemKnowledgeForCharacter( item, server, charId )
	local category = Internal.GetItemCategoryAndQuality(item)
	if (not Internal.initialized) then return Public[category and "KNOWLEDGE_NODATA" or "KNOWLEDGE_INVALID"] end
	return Internal.GetItemKnowledge(server or Internal.server, charId or Internal.charId, category, Internal.TranslateItem(item))
end

function Public.GetItemKnowledgeList( item, server, includedCharIds, accountFilter )
	local results = { }

	local category, quality = Internal.GetItemCategoryAndQuality(item)

	if (category) then
		server = server or Internal.server
		local itemId, itemLink, styleId = Internal.TranslateItem(item)

		-- There is no item quality with scribing, just a binary on/off
		if (category == Internal.CATEGORY_SCRIBING) then
			quality = 1
		end

		-- Get the data for each qualified character
		for _, character in ipairs(Public.GetCharacterList(server)) do
			if ((includedCharIds and includedCharIds[character.id]) or (Internal.AccountFilter(accountFilter, character) and Internal.GetEffectiveParameterValue(server, character.id, category) > quality)) then
				table.insert(results, {
					id = character.id,
					account = character.account,
					name = character.name,
					knowledge = Internal.GetItemKnowledge(server, character.id, category, itemId, itemLink, styleId),
				})
			end
		end
	end

	return results
end

function Public.IsKnowledgeUsable( knowledge )
	return knowledge == Public.KNOWLEDGE_KNOWN or knowledge == Public.KNOWLEDGE_UNKNOWN
end

function Public.GetItemIdsForCategory( category )
	if (not Internal.initialized) then return { } end

	category = category and Internal.IndexedCategories[category]

	if (category) then
		local ids = Internal.idsPublic[category]
		if (not ids) then
			ids = { }
			local blacklist = Internal.InvalidIds
			for _, id in ipairs(Internal.ids[category]) do
				if (not blacklist[id]) then
					table.insert(ids, id)
				end
			end
			Internal.idsPublic[category] = ids
		end
		return ids
	else
		return { }
	end
end

function Public.GetSourceItemIdFromResultItem( resultItem )
	if (not Internal.initialized) then return 0 end

	if (not Internal.cachedResultIds) then
		local results = { }
		for _, category in ipairs({ Public.ITEM_CATEGORY_RECIPE, Public.ITEM_CATEGORY_PLAN }) do
			for _, itemId in ipairs(Public.GetItemIdsForCategory(category)) do
				local resultId = GetItemLinkItemId(GetItemLinkRecipeResultItemLink(Internal.GetItemLink(itemId)))
				if (resultId > 0 and not results[resultId]) then
					results[resultId] = itemId
				end
			end
		end
		Internal.cachedResultIds = results
	end
	return Internal.cachedResultIds[(type(resultItem) == "number") and resultItem or GetItemLinkItemId(resultItem)] or 0
end

function Public.GetLastScanTime( server, charId )
	server = server or Internal.server
	charId = charId or Internal.charId
	return Internal.GetCharRawData(server, charId, "timestamp") or 0
end

function Public.GetRawCharacterSettings( server, charId )
	server = server or Internal.server
	charId = charId or Internal.charId
	return Internal.GetCharacterParams(server, charId)
end


--------------------------------------------------------------------------------
-- Motifs
--------------------------------------------------------------------------------

Public.GetMotifStyles = Internal.GetStyleIds

function Public.GetStyleAndChapterFromMotif( item )
	return Internal.GetMotifStyleAndChapter(Internal.TranslateItem(item))
end

do
	local bookIds = nil
	function Public.GetStyleAndChapterFromBookId( bookId )
		if (not bookIds) then
			bookIds = { }
			for _, styleId in ipairs(Public.GetMotifStyles()) do
				local items = Public.GetMotifItemsFromStyle(styleId)
				for chapterId, bookId in pairs(items.bookIds) do
					bookIds[bookId] = styleId + BitLShift(chapterId, 16)
				end
			end
		end
		local styleIdAndChapterId = bookIds[bookId]
		if (styleIdAndChapterId) then
			return styleIdAndChapterId % 0x10000, BitRShift(styleIdAndChapterId, 16)
		else
			return 0, 0
		end
	end
end

Public.GetMotifItemsFromStyle = Internal.GetStyleMotifItems

do
	local chapters = nil
	function Public.GetMotifChapterNames( )
		-- Get a list of the the IDs and names of possible motif chapter types, sorted by chapter name
		if (not chapters) then
			chapters = { }
			for _, chapterId in ipairs(Internal.MotifAchievementCriterionIndexToChapterId) do
				table.insert(chapters, {
					id = chapterId,
					name = zo_strformat("<<m:1>>", GetString("SI_ITEMSTYLECHAPTER", chapterId), 2),
				})
			end
		end
		return chapters
	end
end

function Public.GetMotifStyleQuality( styleId )
	return Internal.GetStyleQuality(styleId) + 2
end

function Public.GetMotifKnowledgeForCharacter( styleId, chapterId, ... )
	chapterId = chapterId or ITEM_STYLE_CHAPTER_ALL

	local items = Public.GetMotifItemsFromStyle(styleId)

	if (type(items) == "table") then
		if (chapterId == ITEM_STYLE_CHAPTER_ALL or not items.chapters[chapterId]) then
			return Public.GetItemKnowledgeForCharacter(items.books[1], ...)
		else
			return Public.GetItemKnowledgeForCharacter(items.chapters[chapterId], ...)
		end
	else
		return Internal.KNOWLEDGE_INVALID
	end
end

function Public.IsBookIdKnownByCurrentCharacter( bookId )
	local known, bookId2 = select(3, GetLoreBookInfo(GetLoreBookIndicesFromBookId(bookId)))
	return bookId == bookId2 and known
end


--------------------------------------------------------------------------------
-- Scribing
--------------------------------------------------------------------------------

function Public.IsCraftedAbilityUnlockedByCharacter( craftedAbilityId, server, charId )
	return Internal.ScribingGetKnowledge(server, charId, Internal.SCRIBE_GRIMOIRE, craftedAbilityId)
end

function Public.IsCraftedAbilityScriptUnlockedByCharacter( craftedAbilityScriptId, server, charId )
	return Internal.ScribingGetKnowledge(server, charId, Internal.SCRIBE_SCRIPT, craftedAbilityScriptId)
end

function Public.GetMaxCraftedAbilityId( )
	return Internal.maxIds[Internal.SCRIBE_GRIMOIRE] or GetNumCraftedAbilities()
end

function Public.GetMaxCraftedAbilityScriptId( )
	return Internal.maxIds[Internal.SCRIBE_SCRIPT] or 0
end

function Public.GetItemForCraftedAbility( craftedAbilityId )
	local ids = Internal.ids[Internal.SCRIBE_GRIMOIRE]
	return ids and ids[craftedAbilityId] or 0
end

function Public.GetItemForCraftedAbilityScript( craftedAbilityScriptId )
	local ids = Internal.ids[Internal.SCRIBE_SCRIPT]
	return ids and ids[craftedAbilityScriptId] or 0
end

function Public.GetCraftedAbilityScriptDescriptions( craftedAbilityScriptId )
	local results = { }

	local slot = GetCraftedAbilityScriptScribingSlot(craftedAbilityScriptId)
	if (slot ~= SCRIBING_SLOT_NONE) then
		local param = function(pos) return (pos == slot) and craftedAbilityScriptId or nil end
		for id = 1, Public.GetMaxCraftedAbilityId() do
			if (IsCraftedAbilityScriptCompatibleWithSelections(craftedAbilityScriptId, id)) then
				ResetCraftedAbilityScriptSelectionOverride()
				SetCraftedAbilityScriptSelectionOverride(id, param(1), param(2), param(3))
				table.insert(results, { zo_strformat(SI_CRAFTED_ABILITY_NAME_FORMATTER, GetCraftedAbilityDisplayName(id)), GetCraftedAbilityScriptDescription(id, craftedAbilityScriptId), id })
			end
		end
		table.sort(results, function(a, b) return a[1] < b[1] end)
	end

	return results
end


--------------------------------------------------------------------------------
-- Research: Analogues
--------------------------------------------------------------------------------

function Public.GetMaxSimultaneousSmithingResearchForCharacter( craftingSkillType, server, charId )
	return Internal.ResearchGetMaxSlots(server, charId, craftingSkillType)
end

function Public.GetSmithingResearchLineTraitInfoForCharacter( craftingSkillType, researchLineIndex, traitIndex, server, charId )
	local traitType, traitDescription = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	local knowledge = Internal.ResearchGetTraitKnowledge(server, charId, craftingSkillType, researchLineIndex, traitIndex)
	if (knowledge == Internal.KNOWLEDGE_UNKNOWN) then
		local remaining = select(2, Internal.ResearchGetTime(server, charId, craftingSkillType, researchLineIndex, traitIndex))
		if (remaining and remaining <= 0) then
			knowledge = Internal.KNOWLEDGE_KNOWN
		end
	end
	return traitType, traitDescription, knowledge == Internal.KNOWLEDGE_KNOWN
end

function Public.GetSmithingResearchLineTraitTimesForCharacter( craftingSkillType, researchLineIndex, traitIndex, server, charId )
	return Internal.ResearchGetTime(server, charId, craftingSkillType, researchLineIndex, traitIndex)
end

function Public.CanItemLinkBeTraitResearchedByCharacter( itemLink, server, charId )
	local craftingSkillType, researchLineIndex, traitIndex = Public.GetSmithingResearchFromItemLink(itemLink)
	if (craftingSkillType) then
		return Internal.ResearchGetResearchability(server, charId, craftingSkillType, researchLineIndex, traitIndex, false)
	else
		return false
	end
end


--------------------------------------------------------------------------------
-- Research: Other
--------------------------------------------------------------------------------

do
	local traitTable
	local function GetTraitTable( )
		if (not traitTable) then
			traitTable = { }
			for traitItemIndex = 1, GetNumSmithingTraitItems() do
				local traitType, itemName, icon = GetSmithingTraitItemInfo(traitItemIndex)
				if (traitType) then
					traitTable[traitType] = {
						traitType = traitType,
						traitTypeCategory = GetItemTraitTypeCategory(traitType),
						traitItemIndex = traitItemIndex,
						itemName = itemName,
						icon = icon,
						name = GetString("SI_ITEMTRAITTYPE", traitType),
					}
				end
			end
		end
		return traitTable
	end

	function Public.GetTraitInfo( traitType, researchLineIndex, traitIndex )
		if (researchLineIndex and traitIndex) then
			traitType = GetSmithingResearchLineTraitInfo(traitType, researchLineIndex, traitIndex)
		end
		return GetTraitTable()[traitType]
	end

	function Public.GetTraitList( )
		return LCCC.MergeTables(nil, GetTraitTable())
	end
end

function Public.GetSmithingResearchTradeskillTypes( )
	return LCCC.MergeTables(nil, Internal.TRADESKILL_TYPES)
end

Public.GetSmithingResearchFromItemLink = Internal.ResearchGetIndicesFromItemLink

function Public.GetSmithingResearchStatusForCharacter( craftingSkillType, researchLineIndex, traitIndex, server, charId )
	return Internal.ResearchGetTraitKnowledge(server, charId, craftingSkillType, researchLineIndex, traitIndex),
		select(2, Internal.ResearchGetTime(server, charId, craftingSkillType, researchLineIndex, traitIndex))
end

function Public.GetSmithingResearchStatusForCharacters( craftingSkillType, researchLineIndex, traitIndex, server, includedCharIds, accountFilter )
	local results = { }

	if (craftingSkillType and researchLineIndex and traitIndex) then
		server = server or Internal.server

		for _, character in ipairs(Public.GetCharacterList(server)) do
			if ((includedCharIds and includedCharIds[character.id]) or (Internal.AccountFilter(accountFilter, character) and Internal.GetEffectiveParameterValue(server, character.id, Internal.CATEGORY_RESEARCH) > 1)) then
				table.insert(results, {
					id = character.id,
					account = character.account,
					name = character.name,
					knowledge = Internal.ResearchGetTraitKnowledge(server, character.id, craftingSkillType, researchLineIndex, traitIndex),
					remaining = select(2, Internal.ResearchGetTime(server, character.id, craftingSkillType, researchLineIndex, traitIndex)),
				})
			end
		end
	end

	return results
end

function Public.GetSmithingResearchLineKnownTraitCountForCharacter( craftingSkillType, researchLineIndex, server, charId )
	local count = 0
	for traitIndex = 1, select(3, GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)) do
		if (select(3, Public.GetSmithingResearchLineTraitInfoForCharacter(craftingSkillType, researchLineIndex, traitIndex, server, charId))) then
			count = count + 1
		end
	end
	return count
end

function Public.CanTraitBeImmediatelyResearchedByCharacter( craftingSkillType, researchLineIndex, traitIndex, server, charId )
	return Internal.ResearchGetResearchability(server, charId, craftingSkillType, researchLineIndex, traitIndex, true)
end

function Public.GetAllActiveResearchItemsList( )
	local results = { }
	for _, server in ipairs(Public.GetServerList()) do
		for _, character in ipairs(Public.GetCharacterList(server)) do
			if (Internal.GetEffectiveParameterValue(server, character.id, Internal.CATEGORY_RESEARCH) > 1) then
				for _, item in ipairs(Internal.ReadResearchTimes(server, character.id)) do
					item.server = server
					table.insert(results, LCCC.MergeTables(item, character))
				end
			end
		end
	end
	table.sort(results, function( a, b )
		return a.remaining < b.remaining
	end)
	return results
end


--------------------------------------------------------------------------------
-- Callbacks
--------------------------------------------------------------------------------

Internal.callbacks = {
	[Public.EVENT_INITIALIZED] = { },
	[Public.EVENT_UPDATE_REFRESH] = { },
}

function Public.RegisterForCallback( name, eventCode, callback )
	if (type(name) == "string" and type(eventCode) == "number" and type(callback) == "function" and Internal.callbacks[eventCode]) then
		Internal.callbacks[eventCode][name] = callback
		return true
	end
	return false
end

function Public.UnregisterForCallback( name, eventCode )
	if (type(name) == "string" and type(eventCode) == "number" and Internal.callbacks[eventCode]) then
		Internal.callbacks[eventCode][name] = nil
		return true
	end
	return false
end

function Internal.FireCallbacks( eventCode, ... )
	for _, callback in pairs(Internal.callbacks[eventCode]) do
		callback(eventCode, ...)
	end
end
