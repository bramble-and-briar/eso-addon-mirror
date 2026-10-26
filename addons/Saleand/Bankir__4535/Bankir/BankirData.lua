Bankir = Bankir or {}
LCK = LibCharacterKnowledge

-- a list of main itemType and it's sub-itemIds that are a part of the itemType. Like ITEMTYPE_BLACKSMITHING_RAW_MATERIAL
-- is a list of specific itemIds of blacksmithing raw materials. So, if the id is this kind of itemtype then
-- it's a parent type that will be followed by children types/ids.
local itemTypeChildrenItemIds = {
	[ITEMTYPE_BLACKSMITHING_MATERIAL] = { 5413, 4487, 23107, 6000, 6001, 46127, 46128, 46129, 46130, 64489 },
	[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = { 808, 5820, 23103, 23104, 23105, 4482, 23133, 23134, 23135, 71198 },
	[ITEMTYPE_BLACKSMITHING_BOOSTER] = { 54170, 54171, 54172, 54173 },
	[ITEMTYPE_CLOTHIER_MATERIAL] = { 811, 4463, 23125, 23126, 23127, 46131, 46132, 46133, 46134, 64504,
		794, 4447, 23099, 23100, 23101, 46135, 46136, 46137, 46138, 64506 }, --leather/fur
	[ITEMTYPE_CLOTHIER_RAW_MATERIAL] = { 812, 4464, 23129, 23130, 23131, 33217, 33218, 33219, 33220, 71200,
		793, 4448, 23095, 6020, 23097, 23142, 23143, 800, 4478, 71239 }, --leather/fur
	[ITEMTYPE_CLOTHIER_BOOSTER] = { 54174, 54175, 54176, 54177 },
	[ITEMTYPE_WOODWORKING_MATERIAL] = { 803, 533, 23121, 23122, 23123, 46139, 46140, 46141, 46142, 64502 },
	[ITEMTYPE_WOODWORKING_RAW_MATERIAL] = { 802, 521, 23117, 23118, 23119, 818, 4439, 23137, 23138, 71199 },
	[ITEMTYPE_WOODWORKING_BOOSTER] = { 54178, 54179, 54180, 54181 },
	[ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = { 135138, 135140, 135142, 135144, 135146 },
	[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = { 135137, 135139, 135141, 135143, 135145 },
	[ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = { 203631, 203632, 203633, 203634 },
	[ITEMTYPE_JEWELRY_RAW_TRAIT] = { 135158, 135159, 135160, 139415, 139416, 139417, 139418, 139419 },
	[ITEMTYPE_POTION_BASE] = { 883, 1187, 4570, 23265, 23266, 23267, 23268, 64500, 64501 },
	[ITEMTYPE_POISON_BASE] = { 75357, 75358, 75359, 75360, 75361, 75362, 75363, 75364, 75365 },
	[ITEMTYPE_ENCHANTING_RUNE_ASPECT] = { 45850, 45851, 45852, 45853, 45854 },
	[ITEMTYPE_FURNISHING_MATERIAL] = { 114889, 114890, 114891, 114892, 114893, 114894, 114895, 135161 },
	[ITEMTYPE_MASTER_WRIT] = { 119563, 119694, 119681, 119564, 119693, 119696, 153739 },
	-- unopened master writs
	["Unopened" .. SPECIALIZED_ITEMTYPE_MASTER_WRIT] = { 217917, 217918, 217919, 217920, 217921, 217922, 217923 },
	[ITEMTYPE_SOUL_GEM] = { 33271, 33265, 61080 }, -- Soul gem, Soulgem (Empty), Crown soul game
}

-- same principle as itemTypeChildrenItemIds, but for sub-specializedItemTypes
local itemTypeChildrenSpecializedTypes = {
	[ITEMTYPE_INGREDIENT] = { SPECIALIZED_ITEMTYPE_INGREDIENT_RARE },
	[ITEMTYPE_FURNISHING] = { SPECIALIZED_ITEMTYPE_FURNISHING_ATTUNABLE_STATION, SPECIALIZED_ITEMTYPE_FURNISHING_CRAFTING_STATION,
		SPECIALIZED_ITEMTYPE_FURNISHING_LIGHT, SPECIALIZED_ITEMTYPE_FURNISHING_SEATING, SPECIALIZED_ITEMTYPE_FURNISHING_TARGET_DUMMY },
	[ITEMTYPE_MASTER_WRIT] = { SPECIALIZED_ITEMTYPE_HOLIDAY_WRIT },
	[ITEMTYPE_FOOD] = { "CapCP" .. ITEMTYPE_FOOD, "Scalable" .. ITEMTYPE_FOOD },
	[ITEMTYPE_DRINK] = { "CapCP" .. ITEMTYPE_DRINK, "Scalable" .. ITEMTYPE_DRINK },
	[ITEMTYPE_POTION] = { "CapCP" .. ITEMTYPE_POTION, "Scalable" .. ITEMTYPE_POTION },
	[ITEMTYPE_POISON] = { "CapCP" .. ITEMTYPE_POISON, "Scalable" .. ITEMTYPE_POISON },
	[ITEMTYPE_CRAFTED_ABILITY_SCRIPT] = { SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_PRIMARY, SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_SECONDARY, SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_TERTIARY },
	["EquipmentAll"] = { "IntricateAll", "ResearchAll", "CompanionAll" },
}

if LCK then
	table.insert(itemTypeChildrenSpecializedTypes["EquipmentAll"], 3, "ResearchOthersAll")
end

for i = 1, EQUIPMENT_FILTER_TYPE_MAX_VALUE do
	-- Equipment (armor and weapon) custom types
	itemTypeChildrenSpecializedTypes["Equipment" .. i] = { "Intricate" .. i, "Research" .. i, "Companion" .. i }
	if LCK then
		table.insert(itemTypeChildrenSpecializedTypes["Equipment" .. i], 3, "ResearchOthers" .. i)
	end
end

-- and for specializedItemTypes that has children ids
local specializedItemTypeChildrenItemIds = {
	-- unopened treasure map
	[SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP] = { 224681 },
	-- unopened survey reports
	["Unopened" .. SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT] = { 219849, 219850, 219851, 219852, 219853, 219854 },
	-- unknown recipes types
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD },
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK },
	[SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING },
	[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK },
	[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER },
	[SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE] = { "RecipeUnknown" .. SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE },
}

local tweens = {
	["itemType"] ={
		["EquipmentAll"] = {},
	},
	["specializedItemType"] = {
		["IntricateAll"] = {},
		["ResearchAll"] = {},
		["CompanionAll"] = {},
	},
	["itemId"] = {
		-- Master writs are a problem. What looks like a purple alchemy master writ may have a bunch
		-- of different itemIds, so here we define a reference itemId of such master writ and a list
		-- of other itemIds which should be treated as the same item. Also, handle blue and gold master
		-- writs same way as purple ones.
		--blacksmithing
		[119563] = { 119680, --purple
			121527, 121529 }, --gold
		--clothing
		[119694] = { 119695, --purple
			121532, 121533 }, --gold
		--woodworking
		[119681] = { 119682, --purple
			121530, 121531 }, --gold
		--enchanting
		[119564] = { --purple
			121528 }, --gold
		--provisioning
		[119693] = {}, --purple
		--alchemy
		[119696] = { 119698, 119699, 119701, 119704, 119818, 119819, 119820 }, --purple
		--jewelry
		[153739] = { --blue
			153737, --purple
			153738 },--gold
		["StyleMaterialRacial"] = { 33150, 33194, 33251, 33252, 33253, 33254, 33255, 33256, 33257, 33258 },
	},
}

if LCK then
	tweens["specializedItemType"]["ResearchOthersAll"] = {}
end

for i = 1, EQUIPMENT_FILTER_TYPE_MAX_VALUE do
	table.insert(tweens["itemType"]["EquipmentAll"], "Equipment" .. i)
	table.insert(tweens["specializedItemType"]["IntricateAll"], "Intricate" .. i)
	table.insert(tweens["specializedItemType"]["ResearchAll"], "Research" .. i)
	table.insert(tweens["specializedItemType"]["CompanionAll"], "Companion" .. i)
	if LCK then
		table.insert(tweens["specializedItemType"]["ResearchAll"], "ResearchBoth" .. i)
		table.insert(tweens["specializedItemType"]["ResearchOthersAll"], "ResearchOthers" .. i)
		table.insert(tweens["specializedItemType"]["ResearchOthersAll"], "ResearchBoth" .. i)
		tweens["specializedItemType"]["Research" .. i] = { "ResearchBoth" .. i }
		tweens["specializedItemType"]["ResearchOthers" .. i] = { "ResearchBoth" .. i }
	end
end

local qualityRuledItemTypes = {
	["itemType"] = {
		ITEMTYPE_GLYPH_ARMOR,
		ITEMTYPE_GLYPH_WEAPON,
		ITEMTYPE_GLYPH_JEWELRY,
		ITEMTYPE_FOOD,
		ITEMTYPE_DRINK,
		ITEMTYPE_POTION,
		ITEMTYPE_POISON,
		"EquipmentAll",
	},
	["specializedItemType"] = {
		"IntricateAll",
		"ResearchAll",
		"CompanionAll",
	},
	["itemId"] = {}
}

-- quality ruled Equipment (armor and weapon) custom types
for i = 1, EQUIPMENT_FILTER_TYPE_MAX_VALUE do
	table.insert(qualityRuledItemTypes["itemType"], "Equipment" .. i)
end

local function isChildOf(id1, id1TypeStr, id2, id2TypeStr)
	local list
	if id1TypeStr == "itemId" and id2TypeStr == "itemType" then
		list = itemTypeChildrenItemIds[id2]
	elseif id1TypeStr == "specializedItemType" and id2TypeStr == "itemType" then
		list = itemTypeChildrenSpecializedTypes[id2]
	elseif id1TypeStr == "itemId" and id2TypeStr == "specializedItemType" then
		list = specializedItemTypeChildrenItemIds[id2]
	end
	
	if list then
		for i = 1, #list do
			if list[i] == id1 then return true end
		end
	end
	return false
end

local function isTweenOf(typeStr, id1, id2)
	local list = tweens[typeStr][id2]
	
	if list then
		for i = 1, #list do
			if list[i] == id1 then return true end
		end
	end
	return false
end

local bankBagNames
local bankBagIds

local function getBankBags()
	bankBagNames = {}
	bankBagIds = {}
	table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_BANK))
	table.insert(bankBagIds, BAG_BANK)
	-- house coffers:
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_ONE)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_ONE))
		table.insert(bankBagIds, BAG_HOUSE_BANK_ONE)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_TWO)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_TWO))
		table.insert(bankBagIds, BAG_HOUSE_BANK_TWO)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_THREE)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_THREE))
		table.insert(bankBagIds, BAG_HOUSE_BANK_THREE)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_FOUR)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_FOUR))
		table.insert(bankBagIds, BAG_HOUSE_BANK_FOUR)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_FIVE)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_FIVE))
		table.insert(bankBagIds, BAG_HOUSE_BANK_FIVE)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_SIX)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_SIX))
		table.insert(bankBagIds, BAG_HOUSE_BANK_SIX)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_SEVEN)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_SEVEN))
		table.insert(bankBagIds, BAG_HOUSE_BANK_SEVEN)
	end
	if IsCollectibleUnlocked(GetCollectibleForBag(BAG_HOUSE_BANK_EIGHT)) then
		table.insert(bankBagNames, Bankir.Functions.getBagName(BAG_HOUSE_BANK_EIGHT))
		table.insert(bankBagIds, BAG_HOUSE_BANK_EIGHT)
	end
	-- guild banks
	for i = 1, GetNumGuilds() do
		local id = GetGuildId(i)
		table.insert(bankBagNames, Bankir.Functions.getBagName("Guild" .. id))
		table.insert(bankBagIds, "Guild" .. id)
	end
	
	Bankir.Data.bankBagNames = bankBagNames
	Bankir.Data.bankBagIds = bankBagIds
end

local function getCharactersList()
	local charsList = {}
	for i = 1, GetNumCharacters() do
		local name, _, _, _, _, _, id = GetCharacterInfo(i)
		name = zo_strformat(SI_UNIT_NAME, name)
		table.insert(charsList, { id = id, name = name })
	end
	
	Bankir.Data.charactersList = charsList
end

local function getDefaultProfileSettings()
	local defaults = {}
	
	for i = 1, #bankBagIds do
		defaults[bankBagIds[i]] = {
			byItemType = {},
			bySpecializedItemType = {},
			byItemId = {}
		}
		if bankBagIds[i] == BAG_BANK or string.find(bankBagIds[i], "Guild") then
			defaults[bankBagIds[i]].currency = {
				[CURT_MONEY] = {
					push = false,
					pull = false,
					amount = 0,
				},
				[CURT_ALLIANCE_POINTS] = {
					push = false,
					pull = false,
					amount = 0,
				},
				[CURT_TELVAR_STONES] = {
					push = false,
					pull = false,
					amount = 0,
				},
				[CURT_WRIT_VOUCHERS] = {
					push = false,
					pull = false,
					amount = 0,
				},
			}
		end
	end
	
	return defaults
end

local function getDefaultCommonSettings()
	local defaults = {
		moveLockedItems = false,
		showOperationFailMessages = false,
		bankSlidersMaxValue = 10,
		currencySlidersMaxValue = 100000,
	}

	return defaults
end

local function getDefaultServerSettings()
	local defaults = {
		["Integrations"] = {
			-- LibCharacterKnowledge
			["LCK"] = {
				["CharactersList"] = {}
			}
		}
	}
	
	return defaults
end

-- update LCK saved vars list of characters to remove non-existing (deleted) characters
local function cleanUpLCKList()
	local LCKList = Bankir.savedVarsServer.Integrations.LCK.CharactersList
	for id in pairs(LCKList) do
		local isCharExists = false
		for i = 1, #Bankir.Data.charactersList do
			if Bankir.Data.charactersList[i].id == id then
				isCharExists = true
				break
			end
		end
		if not isCharExists then
			Bankir.savedVarsServer.Integrations.LCK.CharactersList[id] = nil
		end
	end
end

Bankir.Data = {
	itemTypeChildrenItemIds = itemTypeChildrenItemIds,
	itemTypeChildrenSpecializedTypes = itemTypeChildrenSpecializedTypes,
	specializedItemTypeChildrenItemIds = specializedItemTypeChildrenItemIds,
	tweens = tweens,
	qualityRuledItemTypes = qualityRuledItemTypes,
	isChildOf = isChildOf,
	isTweenOf = isTweenOf,
	getBankBags = getBankBags,
	getCharactersList = getCharactersList,
	getDefaultProfileSettings = getDefaultProfileSettings,
	getDefaultCommonSettings = getDefaultCommonSettings,
	getDefaultServerSettings = getDefaultServerSettings,
	cleanUpLCKList = cleanUpLCKList,
}
