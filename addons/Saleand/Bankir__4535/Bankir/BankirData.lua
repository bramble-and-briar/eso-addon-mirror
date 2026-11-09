Bankir = Bankir or {}
LCK = LibCharacterKnowledge

local defaultQualityValues = { 1, 2, 3, 4, 5 }

local stringTypeNames = {
	["EquipmentAll"] = GetString(SI_ARMORY_EQUIPMENT_LABEL),
	["IntricateAll"] = GetString(SI_ITEMTRAITTYPE20) .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER), -- "Name of type - All"
	["TraitUnknownAll"] = GetString(SI_ITEMSELLINFORMATION3) .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER), -- "Name of type - All"
	["TraitUnknownOthersAll"] = GetString(SI_ITEMSELLINFORMATION3) .. GetString(BANKIR_MENU_OTHER_CHARACTERS) .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER), -- "Name of type - All"
	["CompanionAll"] = GetString(SI_ITEM_FORMAT_STR_COMPANION) .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER), -- "Name of type - All"
	["RecipeEdible"] = GetString(SI_ITEMTYPEDISPLAYCATEGORY21) .. " (" .. GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES403) .. ")", -- "Recipes (Food & Drinks)"
	["RecipeFurniture"] = GetString(SI_RECIPECRAFTINGSYSTEM6) .. " (" .. GetString(SI_GENERIC_FURNITURE_TEXT) .. ")", -- "Blueprints (Furniture)"
	["StyleMaterialRacial"] = GetString("SI_ITEMTYPE", ITEMTYPE_STYLE_MATERIAL) .. " - " .. GetString(SI_SKILLTYPE7), -- "Style material - Racial"
	["StyleMaterialOther"] = GetString("SI_ITEMTYPE", ITEMTYPE_STYLE_MATERIAL) .. " - " .. GetString(SI_GUILDLANGUAGEATTRIBUTEVALUE32), -- "Style material - Others" SI_GAMEPAD_HOUSING_PERMISSIONS_GUILD_OTHER
	
	["Intricate"] = GetString(SI_ITEMTRAITTYPE20), -- "Intricate"
	["TraitUnknown"] = GetString(SI_ITEMSELLINFORMATION3), -- "Can research"
	["TraitUnknownOthers"] = GetString(SI_ITEMSELLINFORMATION3) .. GetString(BANKIR_MENU_OTHER_CHARACTERS), -- "Can research on Other Characters"
	["Companion"] = GetString(SI_ITEM_FORMAT_STR_COMPANION), -- "Companion Item"
}

local recipeTypeNames = {
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD] =
		GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD),
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK] =
		GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK),
	[SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_ALCHEMY)),
	[SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_BLACKSMITHING)),
	[SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_CLOTHIER)),
	[SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_ENCHANTING)),
	[SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_JEWELRYCRAFTING)),
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_PROVISIONING)),
	[SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING] =
		string.format("%s (%s)", GetString(SI_GENERIC_FURNITURE_TEXT), GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_WOODWORKING)),
	[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK] =
		GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK),
	[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER] =
		GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER),
	[SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE] =
		GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE),
	["Unopened" .. SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT] = 
		string.format("%s (%s)", GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT), GetString(SI_ITEMTYPE75)), -- Survey report (Unopened)
	["Unopened" .. SPECIALIZED_ITEMTYPE_MASTER_WRIT] = 
		string.format("%s (%s)", GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_MASTER_WRIT), GetString(SI_ITEMTYPE75)), -- Master writ (Unopened)
}

local furnitureBlueprintsSpecializedTypes = {
	[SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING] = true,
}

-- a list of main itemType and it's sub-itemIds that are a part of the itemType. Like ITEMTYPE_BLACKSMITHING_RAW_MATERIAL
-- is a list of specific itemIds of blacksmithing raw materials. So, if the id is this kind of itemtype then
-- it's a parent type that will be followed by children types/ids.
local childrenTable = {
	itemType = {
		[ITEMTYPE_BLACKSMITHING_MATERIAL] = {
			itemId = { 5413, 4487, 23107, 6000, 6001, 46127, 46128, 46129, 46130, 64489 },
		},
		[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = {
			itemId = { 808, 5820, 23103, 23104, 23105, 4482, 23133, 23134, 23135, 71198 },
		},
		[ITEMTYPE_BLACKSMITHING_BOOSTER] = {
			itemId = { 54170, 54171, 54172, 54173 },
		},
		[ITEMTYPE_CLOTHIER_MATERIAL] = {
			itemId = { 811, 4463, 23125, 23126, 23127, 46131, 46132, 46133, 46134, 64504,
					794, 4447, 23099, 23100, 23101, 46135, 46136, 46137, 46138, 64506 }, --leather/fur
		},
		[ITEMTYPE_CLOTHIER_RAW_MATERIAL] = {
			itemId = { 812, 4464, 23129, 23130, 23131, 33217, 33218, 33219, 33220, 71200,
					793, 4448, 23095, 6020, 23097, 23142, 23143, 800, 4478, 71239 }, --leather/fur
		},
		[ITEMTYPE_CLOTHIER_BOOSTER] = {
			itemId = { 54174, 54175, 54176, 54177 },
		},
		[ITEMTYPE_WOODWORKING_MATERIAL] = {
			itemId = { 803, 533, 23121, 23122, 23123, 46139, 46140, 46141, 46142, 64502 },
		},
		[ITEMTYPE_WOODWORKING_RAW_MATERIAL] = {
			itemId = { 802, 521, 23117, 23118, 23119, 818, 4439, 23137, 23138, 71199 },
		},
		[ITEMTYPE_WOODWORKING_BOOSTER] = {
			itemId = { 54178, 54179, 54180, 54181 },
		},
		[ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = {
			itemId = { 135138, 135140, 135142, 135144, 135146 },
		},
		[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = {
			itemId = { 135137, 135139, 135141, 135143, 135145 },
		},
		[ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = {
			itemId = { 203631, 203632, 203633, 203634 },
		},
		[ITEMTYPE_JEWELRY_RAW_TRAIT] = {
			itemId = { 135158, 135159, 135160, 139415, 139416, 139417, 139418, 139419 },
		},
		[ITEMTYPE_POTION_BASE] = {
			itemId = { 883, 1187, 4570, 23265, 23266, 23267, 23268, 64500, 64501 },
		},
		[ITEMTYPE_POISON_BASE] = {
			itemId = { 75357, 75358, 75359, 75360, 75361, 75362, 75363, 75364, 75365 },
		},
		[ITEMTYPE_ENCHANTING_RUNE_ASPECT] = {
			itemId = { 45850, 45851, 45852, 45853, 45854 },
		},
		[ITEMTYPE_FURNISHING_MATERIAL] = {
			itemId = { 114889, 114890, 114891, 114892, 114893, 114894, 114895, 135161 },
		},
		[ITEMTYPE_MASTER_WRIT] = {
			itemId = { 119563, 119694, 119681, 119564, 119693, 119696, 153739 },
			specializedItemType = { SPECIALIZED_ITEMTYPE_HOLIDAY_WRIT },
		},
		[ITEMTYPE_SOUL_GEM] = {
			itemId = { 33271, 33265, 61080 }, -- Soul gem, Soulgem (Empty), Crown soul game
		},
		[ITEMTYPE_INGREDIENT] = {
			specializedItemType = { SPECIALIZED_ITEMTYPE_INGREDIENT_RARE },
		},
		[ITEMTYPE_FURNISHING] = {
			specializedItemType = {
				SPECIALIZED_ITEMTYPE_FURNISHING_ATTUNABLE_STATION, SPECIALIZED_ITEMTYPE_FURNISHING_CRAFTING_STATION,
				SPECIALIZED_ITEMTYPE_FURNISHING_LIGHT, SPECIALIZED_ITEMTYPE_FURNISHING_SEATING, SPECIALIZED_ITEMTYPE_FURNISHING_TARGET_DUMMY
			},
		},
		[ITEMTYPE_FOOD] = {
			specializedItemType = { "CapCP" .. ITEMTYPE_FOOD, "Scalable" .. ITEMTYPE_FOOD },
		},
		[ITEMTYPE_DRINK] = {
			specializedItemType = { "CapCP" .. ITEMTYPE_DRINK, "Scalable" .. ITEMTYPE_DRINK },
		},
		[ITEMTYPE_POTION] = {
			specializedItemType = { "CapCP" .. ITEMTYPE_POTION, "Scalable" .. ITEMTYPE_POTION },
		},
		[ITEMTYPE_POISON] = {
			specializedItemType = { "CapCP" .. ITEMTYPE_POISON, "Scalable" .. ITEMTYPE_POISON },
		},
		[ITEMTYPE_CRAFTED_ABILITY_SCRIPT] = {
			specializedItemType = { SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_PRIMARY, SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_SECONDARY, SPECIALIZED_ITEMTYPE_CRAFTED_ABILITY_SCRIPT_TERTIARY },
		},
		[ITEMTYPE_STYLE_MATERIAL] = {
			specializedItemType = { "StyleMaterialRacial", "StyleMaterialOther" },
		},
		["EquipmentAll"] = {
			specializedItemType = { "IntricateAll", "TraitUnknownAll", "TraitUnknownOthersAll", "CompanionAll" },
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_LIGHT] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"Companion" .. EQUIPMENT_FILTER_TYPE_LIGHT,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_MEDIUM] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"Companion" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_HEAVY] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"Companion" .. EQUIPMENT_FILTER_TYPE_HEAVY,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_BOW] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_BOW,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_BOW,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_BOW,
				"Companion" .. EQUIPMENT_FILTER_TYPE_BOW,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_SHIELD] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"Companion" .. EQUIPMENT_FILTER_TYPE_SHIELD,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"Companion" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"Companion" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"Companion" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"Companion" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_NECK] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_NECK,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_NECK,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_NECK,
				"Companion" .. EQUIPMENT_FILTER_TYPE_NECK,
			},
		},
		["Equipment" .. EQUIPMENT_FILTER_TYPE_RING] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_RING,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_RING,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_RING,
				"Companion" .. EQUIPMENT_FILTER_TYPE_RING,
			},
		},
		["RecipeEdible"] = {
			specializedItemType = {
				SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD,
				SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK,
			},
		},
		["RecipeFurniture"] = {
			specializedItemType = {
				SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING,
				SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING,
				SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING,
				SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING,
				SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING,
				SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING,
				SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING,
			},
		},
	},
	specializedItemType = {
		[SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP] = {
			itemId = { 224681 },
		},
		-- unopened master writs
		["Unopened" .. SPECIALIZED_ITEMTYPE_MASTER_WRIT] = {
			itemId = { 217917, 217918, 217919, 217920, 217921, 217922, 217923 },
		},
		-- unopened survey reports
		["Unopened" .. SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT] = {
			itemId = { 219849, 219850, 219851, 219852, 219853, 219854 },
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING] = {
			specializedItemType = {
				"RecipeUnknown" .. SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING,
				"RecipeUnknownOthers" .. SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING
			},
		},
		[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK] = {
			specializedItemType = {
				"MotifUnknown" .. SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK,
				"MotifUnknownOthers" .. SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK
			},
		},
		[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER] = {
			specializedItemType = {
				"MotifUnknown" .. SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER,
				"MotifUnknownOthers" .. SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER
			},
		},
		[SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE] = {
			specializedItemType = {
				"MotifUnknown" .. SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE,
				"MotifUnknownOthers" .. SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE
			},
		},
	},
	itemId = {},
}

local tweensTable = {
	itemType = {
		["EquipmentAll"] = {
			itemType = {
				"Equipment" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_BOW,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_NECK,
				"Equipment" .. EQUIPMENT_FILTER_TYPE_RING,
			},
		},
	},
	specializedItemType = {
		["IntricateAll"] = {
			specializedItemType = {
				"Intricate" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_BOW,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_NECK,
				"Intricate" .. EQUIPMENT_FILTER_TYPE_RING,
			},
		},
		["TraitUnknownAll"] = {
			specializedItemType = {
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_BOW,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_NECK,
				"TraitUnknown" .. EQUIPMENT_FILTER_TYPE_RING,
			},
		},
		["TraitUnknownOthersAll"] = {
			specializedItemType = {
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_BOW,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_NECK,
				"TraitUnknownOthers" .. EQUIPMENT_FILTER_TYPE_RING,
			},
		},
		["CompanionAll"] = {
			specializedItemType = {
				"Companion" .. EQUIPMENT_FILTER_TYPE_LIGHT,
				"Companion" .. EQUIPMENT_FILTER_TYPE_MEDIUM,
				"Companion" .. EQUIPMENT_FILTER_TYPE_HEAVY,
				"Companion" .. EQUIPMENT_FILTER_TYPE_BOW,
				"Companion" .. EQUIPMENT_FILTER_TYPE_SHIELD,
				"Companion" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF,
				"Companion" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF,
				"Companion" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED,
				"Companion" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED,
				"Companion" .. EQUIPMENT_FILTER_TYPE_NECK,
				"Companion" .. EQUIPMENT_FILTER_TYPE_RING,
			},
		},
		["StyleMaterialRacial"] = {
			itemId = { 33150, 33194, 33251, 33252, 33253, 33254, 33255, 33256, 33257, 33258 },
		},
	},
	itemId = {
		-- Master writs are a problem. What looks like a purple alchemy master writ may have a bunch
		-- of different itemIds, so here we define a reference itemId of such master writ and a list
		-- of other itemIds which should be treated as the same item. Also, handle blue and gold master
		-- writs same way as purple ones.
		[119563] = { -- blacksmithing
			itemId = {
				119680, --purple
				121527, 121529, --gold
			},
		},
		[119694] = { -- clothing
			itemId = {
				119695, --purple
				121532, 121533, --gold
			},
		},
		[119681] = { -- woodworking
			itemId = {
				119682, --purple
				121530, 121531, --gold
			},
		},
		[119564] = { -- enchanting
			itemId = {
				121528, --gold
			},
		},
		[119693] = { -- provisioning
		},
		[119696] = { -- alchemy
			itemId = {
				119698, 119699, 119701, 119704, 119818, 119819, 119820, --purple
			},
		},
		[153739] = { -- jewelry
			itemId = {
				153737, --purple
				153738,--gold
			},
		},
	},
}

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
		SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD,
		SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK,
		
		SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING,
	},
	["itemId"] = {}
}

local function isChildOf(id1, id1TypeStr, id2, id2TypeStr)
	local list
	if childrenTable[id2TypeStr][id2] then
		list = childrenTable[id2TypeStr][id2][id1TypeStr]
	end
	if list then
		for i = 1, #list do
			if list[i] == id1 then return true end
		end
	end
	return false
end

local function isTweenOf(id1, id1TypeStr, id2, id2TypeStr)
	if tweensTable[id2TypeStr][id2] then
		list = tweensTable[id2TypeStr][id2][id1TypeStr]
	end
	
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
			itemType = {},
			specializedItemType = {},
			itemId = {}
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
		["ResearchCharactersList"] = {},
	}
	return defaults
end

-- update saved vars list of characters to remove non-existing (deleted) ones
local function cleanUpResearchCharactersList()
	local list = Bankir.savedVarsServer.ResearchCharactersList
	for id in pairs(list) do
		local isCharExists = false
		for i = 1, #Bankir.Data.charactersList do
			if Bankir.Data.charactersList[i].id == id then
				isCharExists = true
				break
			end
		end
		if not isCharExists then
			Bankir.savedVarsServer.ResearchCharactersList[id] = nil
		end
	end
end

Bankir.Data = {
	defaultQualityValues = defaultQualityValues,
	stringTypeNames = stringTypeNames,
	recipeTypeNames = recipeTypeNames,
	furnitureBlueprintsSpecializedTypes = furnitureBlueprintsSpecializedTypes,
	childrenTable = childrenTable,
	tweensTable = tweensTable,
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
	cleanUpResearchCharactersList = cleanUpResearchCharactersList,
}
