Bankir = Bankir or {}

--Create an example itemlink of the setItem's itemId (level 50, CP160) using the itemQuality subtype.
--See UESP website for a description of the itemLink: [url]https://en.uesp.net/wiki/Online:Item_Link[/url]
--Example itemLink: "|H0:itemname:5413:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
--The following qualities are available: 357-Trash, 366-Normal, 367-Magic, 368-Arcane, 369-Artifact, 370-Legendary
--> Parameters: itemId number: The item's itemId
-->             itemLvl: The item level. If not set, default is 50
-->             itemQualitySubType number: The itemquality number of ESO, described above (standard value: 366 -> Normal)

--> Returns:    itemLink String: The generated itemLink for the item with the given quality
local function buildItemLink(itemId, itemLvl, itemQualitySubType, isCrafted)
	if itemId == nil or itemId == 0 then return end
	itemLvl = itemLvl or 50
	if not itemQualitySubType then
		if itemLvl < 50 then
			itemQualitySubType = 2 --normal lvl 1-50
		else
			itemQualitySubType = 366 --normal lvl 50 cp 160
		end
	end
	isCrafted = isCrafted or 0
	return string.format("|H1:item:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:0:0:%d:%d:0:0:%d:0|h|h",
		itemId, itemQualitySubType, itemLvl, ITEMSTYLE_NONE, isCrafted, 10000)
end

-- Item link's internalLevel field is weird for Rubedite Ingot.
-- Normally, it's 1, but for Rubedite Ingot that is in guild bank it's 0 for some strange reason.
-- This function is a workaround to fix the problem of comparing item links of Rubedite Ingot
-- stacks, one of which is in bag and the other one is in guild bank and has broken internalLevel.
local function normalizeItemLink(itemLink)
	local parts = {zo_strsplit(':', itemLink)}
	-- parts[1] = "|H0"
	-- parts[2] = "item"
	-- parts[3] = itemId
	-- parts[4] = subType
	-- parts[5] = internalLevel
	if parts[5] == "0" then
		parts[5] = "1"
	end
	return table.concat(parts, ":")
end

local function getNormalizedLink(itemLink)
	local itemId = GetItemLinkItemId(itemLink)
	local level = GetItemLinkRequiredLevel(itemLink)
	local cp = GetItemLinkRequiredChampionPoints(itemLink)
	local quality = GetItemLinkDisplayQuality(itemLink)
	
	return string.format("%d|%d|%d|%d", itemId, level, cp, quality)
end

local function isEqualItemLink(itemLink1, itemLink2)
	if not itemLink1 or not itemLink2 then
		return false
	end
	
	if getNormalizedLink(itemLink1) ~= getNormalizedLink(itemLink2) then
		return false
	end
	
	return true
end

local function isInArray(array, value)
	local isIn = false
	for i = 1, #array do
		if value == array[i] then
			isIn = true
			break
		end
	end
	return isIn
end

local function copyData(data)
	if not data then return nil end
	if type(data) == "table" then
		local newData = {}
		for k, v in pairs(data) do
			newData[k] = copyData(v)
		end
		return newData
	else
		return data
	end
end

local function mergeData(dest, src)
	for k, v in pairs(src) do
		if type(dest[k]) == "table" and type(v) == "table" then
			dest[k] = mergeData(dest[k], v)
		elseif dest[k] == nil or type(dest[k]) ~= type(v) then
			dest[k] = copyData(v)
		end
	end
	return dest
end

local function getEquipFilterType(itemLink)
	local armorType = GetItemLinkArmorType(itemLink)
	if armorType ~= ARMORTYPE_NONE then
		return armorType
	end
	local weaponType = GetItemLinkWeaponType(itemLink)
	if weaponType ~= WEAPONTYPE_NONE then
		if weaponType == WEAPONTYPE_BOW then
			return EQUIPMENT_FILTER_TYPE_BOW
		elseif weaponType == WEAPONTYPE_SHIELD then
			return EQUIPMENT_FILTER_TYPE_SHIELD
		elseif weaponType == WEAPONTYPE_HEALING_STAFF then
			return EQUIPMENT_FILTER_TYPE_RESTO_STAFF
		elseif weaponType == WEAPONTYPE_FIRE_STAFF
		or weaponType == WEAPONTYPE_FROST_STAFF
		or weaponType == WEAPONTYPE_LIGHTNING_STAFF then
			return EQUIPMENT_FILTER_TYPE_DESTRO_STAFF
		elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD
		or weaponType == WEAPONTYPE_TWO_HANDED_AXE
		or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then
			return EQUIPMENT_FILTER_TYPE_TWO_HANDED
		elseif weaponType == WEAPONTYPE_AXE
		or weaponType == WEAPONTYPE_DAGGER
		or weaponType == WEAPONTYPE_HAMMER
		or weaponType == WEAPONTYPE_SWORD then
			return EQUIPMENT_FILTER_TYPE_ONE_HANDED
		end
	end
	local equipType = GetItemLinkEquipType(itemLink)
	if equipType == EQUIP_TYPE_NECK then
		return EQUIPMENT_FILTER_TYPE_NECK
	elseif equipType == EQUIP_TYPE_RING then
		return EQUIPMENT_FILTER_TYPE_RING
	end
end

local function canLearnOnOtherCharacters(itemLink)
	if LCK then
		for charId in pairs(Bankir.SVServer.ResearchCharactersList) do
			if LCK.GetItemKnowledgeForCharacter(itemLink, nil, charId) == LCK.KNOWLEDGE_UNKNOWN then
				return true
			end
		end
	end
	return false
end

local function canLearnOnOtherCharacters(itemLink, traitType)
	if LCK then
		for charId in pairs(Bankir.SVServer.ResearchCharactersList) do
			if traitType then
				if LCK.CanItemLinkBeTraitResearchedByCharacter(itemLink, nil, charId) then
					return true
				end
			elseif LCK.GetItemKnowledgeForCharacter(itemLink, nil, charId) == LCK.KNOWLEDGE_UNKNOWN then
				return true
			end
		end
	end
	return false
end

local function setNameOfLearnableTypeId(prefix, suffix, canLearnOnCurrent, canLearnOnOthers)
	local name
	if canLearnOnCurrent and canLearnOnOthers then
		name = prefix .. "UnknownBoth".. suffix
	elseif canLearnOnCurrent then
		name = prefix .. "Unknown" .. suffix
	elseif canLearnOnOthers then
		name = prefix .. "UnknownOthers" .. suffix
	end
	return name
end

local function redefineItemTypes(itemLink)
	local itemType, specializedItemType = GetItemLinkItemType(itemLink)
	local itemId = GetItemLinkItemId(itemLink)
	
	-- redefine the item types for armor/weapon
	if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
		local equipFilterType = getEquipFilterType(itemLink)
		if equipFilterType then
			itemType = "Equipment" .. equipFilterType
			
			local traitInfo = GetItemLinkTraitInfo(itemLink)
			if traitInfo == ITEM_TRAIT_TYPE_ARMOR_INTRICATE
			or traitInfo == ITEM_TRAIT_TYPE_WEAPON_INTRICATE
			or traitInfo == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
			then
				specializedItemType = "Intricate" .. equipFilterType
			elseif GetItemLinkActorCategory(itemLink) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
				specializedItemType = "Companion" .. equipFilterType
			else
				specializedItemType = setNameOfLearnableTypeId("Trait", equipFilterType,
					CanItemLinkBeTraitResearched(itemLink), canLearnOnOtherCharacters(itemLink, true))
					or specializedItemType
			end
		end
	-- redefine the item id for unknown recipes/motifs
	elseif itemType == ITEMTYPE_RECIPE then
		if specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD
		or specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK
		then
			itemType = "RecipeEdible"
		elseif Bankir.Data.furnitureBlueprintsSpecializedTypes[specializedItemType] then
			itemType = "RecipeFurniture"
		end
		specializedItemType = setNameOfLearnableTypeId("Recipe", specializedItemType,
			CanItemLinkBeUsedToLearn(itemLink), canLearnOnOtherCharacters(itemLink))
			or specializedItemType
	elseif specializedItemType == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK
	or specializedItemType == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER
	or specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE
	then
		itemType = "Motif" .. specializedItemType
		specializedItemType = setNameOfLearnableTypeId("Motif", specializedItemType,
			CanItemLinkBeUsedToLearn(itemLink), canLearnOnOtherCharacters(itemLink))
			or specializedItemType
	-- redefine the item type for 150-160CP consumables
	elseif itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK
	or itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON then
		local requiredLevel = GetItemLinkRequiredLevel(itemLink)
		local requiredChampionPoints = GetItemLinkRequiredChampionPoints(itemLink)
		if requiredLevel == 50 and requiredChampionPoints == 150 then
			specializedItemType = "CapCP" .. itemType
		elseif requiredLevel == 1 then
			specializedItemType = "Scalable" .. itemType
		end
	elseif itemType == ITEMTYPE_STYLE_MATERIAL then
		if Bankir.Data.isTweenOf(itemId, "itemId", "StyleMaterialRacial", "specializedItemType") then
			specializedItemType = "StyleMaterialRacial"
		else
			specializedItemType = "StyleMaterialOther"
		end
	end
	
	return itemType, specializedItemType, itemId
end

local function getNameOfType(itemType, idTypeStr)
	local s
	if idTypeStr == "specializedItemType" then
		s = Bankir.Data.recipeTypeNames[itemType]
	end
	if not s then
		if type(itemType) == "string" then
			if not s then
				local name = string.match(itemType, "^(%D+)") -- get starting word
				local id = tonumber(string.match(itemType, "(%d+)$")) -- get ending number
				if not id then
					s = Bankir.Data.stringTypeNames[itemType]
				else
					if name == "Equipment" then
						s = GetString("SI_EQUIPMENTFILTERTYPE", id)
					elseif name == "CapCP" then
						s = string.format("%s (%s %s)", GetString("SI_ITEMTYPE", id), zo_iconTextFormatNoSpace(ZO_GetGamepadChampionPointsIcon(), 18, 18, GetString(SI_ITEM_FORMAT_STR_CHAMPION)), "150-160") -- "Food (CP150-160)"
					elseif name == "Scalable" then
						s = string.format("%s (%s)", GetString("SI_ITEMTYPE", id), GetString(SI_STATS_SCALED_LEVEL)) -- "Food (Scaled level)"
					elseif idTypeStr == "specializedItemType" then
						s = Bankir.Data.recipeTypeNames[id]
						if s then
							if string.find(name, "Unknown") then
								s = zo_strformat(GetString(SI_ALCHEMY_UNKNOWN_RESULT), s) -- e.g., "Food recipe (unknown)"
							end
							if string.find(name, "Others") then
								s = s .. GetString(BANKIR_MENU_OTHER_CHARACTERS) -- "Food recipe (unknown) on Other Characters"
							end
						end
					end
				end
			end
		elseif type(itemType) == "number" then
			if idTypeStr == "itemId" then
				local itemLink = buildItemLink(itemType)
				s = GetItemLinkName(itemLink)
			elseif idTypeStr == "itemType" then
				s = GetString("SI_ITEMTYPE", itemType)
			elseif idTypeStr == "specializedItemType" then
				s = GetString("SI_SPECIALIZEDITEMTYPE", itemType)
			end
		end
	end
	return s
end

-- return rule from the ruleset (as copy table). If no rule found, returns rule with default values. If rule has missing values, they also become defaults.
local function getEffectiveRule(id, idTypeStr, bankBagId, itemQuality, itemStackSize)
	local rule = {}
	
	-- special case for items with types like 'ResearchBoth', 'MotifUnknownBoth'
	-- a combination of their respective 'Research' and 'ResearchOthers'
	local bothStart = string.find(id, "Both")
	if bothStart then
		local typeS = string.sub(id, 1, bothStart - 1) -- substring before the 'Both', e.g. 'Research'
		local typeO = typeS .. "Others" -- e.g., 'ResearchOthers'
		local id = string.match(id, "(%d+)$") -- get ending number
		local ruleS = getEffectiveRule(typeS .. id, idTypeStr, bankBagId, itemQuality, itemStackSize)
		local ruleO = getEffectiveRule(typeO .. id, idTypeStr, bankBagId, itemQuality, itemStackSize)
		
		rule.push = math.max(ruleS.push, ruleO.push)
		if ruleS and ruleS.pullInStacks then
			ruleS.pull = ruleS.pull * itemStackSize
		end
		if ruleO and ruleO.pullInStacks then
			ruleO.pull = ruleO.pull * itemStackSize
		end
		rule.pull = math.max(ruleS.pull, ruleO.pull)
		rule.pullInStacks = false
	else
		rule = copyData(Bankir.SVProfile[bankBagId][idTypeStr][id]) or {}
		
		if itemQuality and rule.quality and not isInArray(rule.quality, itemQuality) then
			rule = {}
		end
		
		rule.push = rule.push or 0
		rule.pull = rule.pull or 0
		rule.pullInStacks = rule.pullInStacks or false
		rule.quality = rule.quality or Bankir.Data.defaultQualityValues
	end
	
	return rule
end

local function getHouseBankName(bagId)
	local name
	local collectibleId = GetCollectibleForBag(bagId)
	if collectibleId ~= 0 then
		local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
		if collectibleData then
			name = collectibleData:GetNickname()
			if name == "" then
				name = collectibleData:GetFormattedName()
			end
		end
	end
	return name
end

local function getGuildIndexFromId(guildId)
	for i = 1, GetNumGuilds() do
		local id = GetGuildId(i)
		if id == guildId then
			return i
		end
	end
end

local function getGuildNameFromString(guildString)
	local guildId = string.match(guildString, "(%d+)$")
	local guildName = GetGuildName(tonumber(guildId))
	if not guildName or guildName == "" then
		guildName = "Guild" .. getGuildIndexFromId(guildId)
	end
	return guildName
end

local function getBagName(bagId)
	if bagId == BAG_BACKPACK then
		return GetString(SI_BAG1)
	elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
		return GetString(SI_BAG2)
	elseif string.find(bagId, "Guild") then
		return getGuildNameFromString(bagId)
	elseif bagId == BAG_GUILDBANK then
		local guildId = GetSelectedGuildBankId()
		return GetGuildName(guildId)
	elseif IsHouseBankBag(bagId) then
		return getHouseBankName(bagId)
	end
end

local function checkItemForQuests(bagId, slotId)
	--DoesItemFulfillJournalQuestCondition(bagId, slotId, journalQuestIndex, stepIndex, conditionIndex)
	local result = 0
	local quests = QUEST_JOURNAL_MANAGER:GetQuestList()
	for i, questInfo in pairs(quests) do
		if questInfo.questType == QUEST_TYPE_CRAFTING then
			for conditionIndex = 1, select(5, GetJournalQuestStepInfo(questInfo.questIndex, QUEST_MAIN_STEP_INDEX)) do
				--local conditionType = select(8, GetJournalQuestConditionInfo(questInfo.questIndex, QUEST_MAIN_STEP_INDEX, conditionIndex))
				local _, current, required = GetJournalQuestConditionInfo(questInfo.questIndex, QUEST_MAIN_STEP_INDEX, conditionIndex)
				if current and required then
					if DoesItemFulfillJournalQuestCondition(bagId, slotId, questInfo.questIndex, QUEST_MAIN_STEP_INDEX, conditionIndex) then
						result = result + required
					end
				end
			end
		end
	end
	return result
end

Bankir.Functions = {
	buildItemLink = buildItemLink,
	normalizeItemLink = normalizeItemLink,
	getNormalizedLink = getNormalizedLink,
	isEqualItemLink = isEqualItemLink,
	copyData = copyData,
	mergeData = mergeData,
	isInArray = isInArray,
	getEquipFilterType = getEquipFilterType,
	redefineItemTypes = redefineItemTypes,
	getNameOfType = getNameOfType,
	getSavedVarForIdType = getSavedVarForIdType,
	getEffectiveRule = getEffectiveRule,
	getHouseBankName = getHouseBankName,
	getGuildIndexFromId = getGuildIndexFromId,
	getGuildNameFromString = getGuildNameFromString,
	getBagName = getBagName,
	checkItemForQuests = checkItemForQuests,
}