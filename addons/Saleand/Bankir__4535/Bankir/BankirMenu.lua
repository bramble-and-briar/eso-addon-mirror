Bankir = Bankir or {}
Bankir.Menu = Bankir.Menu or {}

function Bankir.createSettingsMenu(name, author, version)
	local BMBF = Bankir.MenuBuildFunctions
	local LAM = LibAddonMenu2
	
	Bankir.Menu.selectedBankIndex = 1
	Bankir.Menu.selectedBankId = Bankir.Data.bankBagIds[1]
	
	-- Register the Options panel with LAM
	local panelData =
	{
		type = "panel",
		name = name,
		author = author,
		version = version,
		registerForRefresh = true,
	}
	local addonPanel = LAM:RegisterAddonPanel("Bankir_Settings", panelData)
	
	local blacksmithingTabsData = {
		buttonType = "icon",
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_BLACKSMITHING_RAW_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_rawmats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_rawmats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_BLACKSMITHING_RAW_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_BLACKSMITHING_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_mats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_mats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_BLACKSMITHING_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_BLACKSMITHING_BOOSTER),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_temper_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_temper_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_BLACKSMITHING_BOOSTER, idTypeStr = "itemType" }
				}
			),
		},
	}
	
	local clothingTabsData = {
		buttonType = "icon",
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_CLOTHIER_RAW_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_rawmats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_rawmats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_CLOTHIER_RAW_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_CLOTHIER_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_mats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_mats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_CLOTHIER_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_CLOTHIER_BOOSTER),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_tannin_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_tannin_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_CLOTHIER_BOOSTER, idTypeStr = "itemType" }
				}
			),
		},
	}
	
	local woodworkingTabsData = {
		buttonType = "icon",
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_WOODWORKING_RAW_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_rawmats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_rawmats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_WOODWORKING_RAW_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_WOODWORKING_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_mats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_mats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_WOODWORKING_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_WOODWORKING_BOOSTER),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_resin_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_resin_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_WOODWORKING_BOOSTER, idTypeStr = "itemType" }
				}
			),
		},
	}
	
	local jewelrycraftingTabsData = {
		buttonType = "icon",
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_rawmats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_rawmats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_JEWELRYCRAFTING_MATERIAL),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_mats_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_mats_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_JEWELRYCRAFTING_MATERIAL, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_JEWELRYCRAFTING_BOOSTER),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_plating_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_plating_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_JEWELRYCRAFTING_BOOSTER, idTypeStr = "itemType" }
				}
			),
		},
	}
	
	local craftingTabsData = {
		buttonType = "icon",
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_BLACKSMITHING),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_down.dds",
			subTabs = blacksmithingTabsData,
		},
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_CLOTHIER),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_clothing_down.dds",
			subTabs = clothingTabsData,
		},
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_WOODWORKING),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_woodworking_down.dds",
			subTabs = woodworkingTabsData,
		},
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_ENCHANTING),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_enchanting_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_enchanting_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_ENCHANTING_RUNE_ASPECT, idTypeStr = "itemType" },
					{ id = ITEMTYPE_ENCHANTING_RUNE_ESSENCE, idTypeStr = "itemType" },
					{ id = ITEMTYPE_ENCHANTING_RUNE_POTENCY, idTypeStr = "itemType" },
					{ id = ITEMTYPE_ENCHANTMENT_BOOSTER, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_PROVISIONING),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_provisioning_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_provisioning_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_INGREDIENT, idTypeStr = "itemType" },
					{ id = ITEMTYPE_FLAVORING, idTypeStr = "itemType" },
					{ id = ITEMTYPE_SPICE, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_ALCHEMY),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_alchemy_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_alchemy_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_REAGENT, idTypeStr = "itemType" },
					{ id = ITEMTYPE_POTION_BASE, idTypeStr = "itemType" },
					{ id = ITEMTYPE_POISON_BASE, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_JEWELRYCRAFTING),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_jewelrycrafting_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_jewelrycrafting_down.dds",
			subTabs = jewelrycraftingTabsData,
		},
		{
			title = GetString(SI_SCRIBING_TITLE),
			iconNormal = "/esoui/art/crafting/scribing_tabicon_scribing_up.dds",
			iconPressed = "/esoui/art/crafting/scribing_tabicon_scribing_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_SCRIBING_INK, idTypeStr = "itemType" },
					{ id = ITEMTYPE_CRAFTED_ABILITY_SCRIPT, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_FURNISHING),
			iconNormal = "/esoui/art/crafting/provisioner_indexicon_furnishings_up.dds",
			iconPressed = "/esoui/art/crafting/provisioner_indexicon_furnishings_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_FURNISHING_MATERIAL, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_TRAIT_ITEMS),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_itemtrait_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_itemtrait_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_WEAPON_TRAIT, idTypeStr = "itemType" },
					{ id = ITEMTYPE_ARMOR_TRAIT, idTypeStr = "itemType" },
					{ id = ITEMTYPE_JEWELRY_TRAIT, idTypeStr = "itemType" },
					{ id = ITEMTYPE_JEWELRY_RAW_TRAIT, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_STYLE_MATERIALS),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_craftbag_stylematerial_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_craftbag_stylematerial_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "StyleMaterialRacial", idTypeStr = "itemType" },
					{ id = "StyleMaterialOther", idTypeStr = "itemType" },
					{ id = ITEMTYPE_RAW_MATERIAL, idTypeStr = "itemType" },
				--ITEMTYPE_STYLE_MATERIAL,
				}
			),
		},
	}
	
	local equipmentTabsData = {
		buttonType = "icon",
		{
			title = GetString(SI_ARMORY_EQUIPMENT_LABEL) .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER), -- "Equipment - All"
			iconNormal = "/esoui/art/inventory/inventory_tabicon_all_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_all_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "EquipmentAll", idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_LIGHT),
			iconNormal = "esoui/art/icons/progression_tabicon_armorlight_up.dds",
			iconPressed = "esoui/art/icons/progression_tabicon_armorlight_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_LIGHT, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_MEDIUM),
			iconNormal = "esoui/art/icons/progression_tabicon_armormedium_up.dds",
			iconPressed = "esoui/art/icons/progression_tabicon_armormedium_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_MEDIUM, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_HEAVY),
			iconNormal = "esoui/art/icons/progression_tabicon_armorheavy_up.dds",
			iconPressed = "esoui/art/icons/progression_tabicon_armorheavy_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_HEAVY, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_NECK),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_necklace_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_necklace_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_NECK, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_RING),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_ring_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_ring_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_RING, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_ONE_HANDED),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_weapons_1h_dagger_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_weapons_1h_dagger_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_ONE_HANDED, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_TWO_HANDED),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_weapons_2h_sword_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_weapons_2h_sword_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_TWO_HANDED, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_BOW),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_bow_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_bow_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_BOW, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_RESTO_STAFF),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_weapons_staff_lightning_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_weapons_staff_lightning_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_RESTO_STAFF, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_DESTRO_STAFF),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_weapons_staff_flame_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_weapons_staff_flame_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_DESTRO_STAFF, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = GetString("SI_EQUIPMENTFILTERTYPE", EQUIPMENT_FILTER_TYPE_SHIELD),
			iconNormal = "/esoui/art/inventory/inventory_tabicon_shield_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_shield_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Equipment" .. EQUIPMENT_FILTER_TYPE_SHIELD, idTypeStr = "itemType" }
				}
			),
		},
	}
	
	local masterWritsTabsData = {
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_MASTER_WRIT),
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_MASTER_WRIT, idTypeStr = "itemType" }
				}
			),
		},
		{
			title = zo_strformat(GetString(SI_ALCHEMY_UNKNOWN_RESULT), GetString("SI_ITEMTYPE", ITEMTYPE_MASTER_WRIT)),
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = "Unopened" .. SPECIALIZED_ITEMTYPE_MASTER_WRIT, idTypeStr = "itemType" }
				}
			),
		},
	}
	
	local consumablesTabsData = {
		buttonType = "icon",
		{
			title = GetString(SI_BUFFS_OPTIONS_SECTION_TITLE), -- "Buffs & Debuffs"
			iconNormal = "/esoui/art/inventory/inventory_tabicon_consumables_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_consumables_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_FOOD, idTypeStr = "itemType" },
					{ id = ITEMTYPE_DRINK, idTypeStr = "itemType" },
					{ id = ITEMTYPE_POTION, idTypeStr = "itemType" },
					{ id = ITEMTYPE_POISON, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString(SI_ITEMTYPEDISPLAYCATEGORY27), -- "Repair items"
			iconNormal = "/esoui/art/inventory/inventory_tabicon_repair_up.dds",
			iconPressed = "/esoui/art/inventory/inventory_tabicon_repair_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = 44879, idTypeStr = "itemId" }, -- Equipment repair kit
					{ id = ITEMTYPE_CROWN_REPAIR, idTypeStr = "itemType" },
					{ id = ITEMTYPE_GROUP_REPAIR, idTypeStr = "itemType" },
					{ id = ITEMTYPE_SOUL_GEM, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString(SI_CAMPAIGNRULESETTYPE1), -- "Cyrodiil"
			iconNormal = "/esoui/art/mainmenu/menubar_ava_up.dds",
			iconPressed = "/esoui/art/mainmenu/menubar_ava_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_AVA_REPAIR, idTypeStr = "itemType" },
					{ id = ITEMTYPE_SIEGE, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString(SI_MAP_INFO_MODE_LOCATIONS),
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_trophy_treasure_map_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_trophy_treasure_map_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT, idTypeStr = "specializedItemType" },
					{ id = "Unopened" .. SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT, idTypeStr = "specializedItemType" },
				}
			),
		},
		{
			title = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES212), -- "Writs"
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_master_writ_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_master_writ_down.dds",
			subTabs = masterWritsTabsData,
		},
		{
			title = GetString(SI_ITEMTYPEDISPLAYCATEGORY21), -- "Recipes"
			iconNormal = "/esoui/art/tradinghouse/tradinghouse_trophy_recipe_fragment_up.dds",
			iconPressed = "/esoui/art/tradinghouse/tradinghouse_trophy_recipe_fragment_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT, idTypeStr = "specializedItemType" },
				}
			),
		},
		{
			title = GetString(SI_RECIPECRAFTINGSYSTEM6), -- "Blueprints"
			iconNormal = "/esoui/art/crafting/provisioner_indexicon_furnishings_up.dds",
			iconPressed = "/esoui/art/crafting/provisioner_indexicon_furnishings_down.dds",
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING, idTypeStr = "specializedItemType" },
				}
			),
		},
	}
	
	local miscTabsData = {
		{
			title = GetString(SI_GAMEPADITEMCATEGORY13), -- "Glyphs"
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_GLYPH_ARMOR, idTypeStr = "itemType" },
					{ id = ITEMTYPE_GLYPH_WEAPON, idTypeStr = "itemType" },
					{ id = ITEMTYPE_GLYPH_JEWELRY, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString(SI_GAMEPADITEMCATEGORY31), -- "Trophy"
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_KEY_FRAGMENT, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_UPGRADE_FRAGMENT, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_MUSEUM_PIECE, idTypeStr = "specializedItemType" },
				}
			),
		},
		{
			title = GetString(SI_SPECIALIZEDITEMTYPE850), -- "Container"
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_CONTAINER, idTypeStr = "itemType" },
					{ id = ITEMTYPE_CONTAINER_CURRENCY, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString("SI_ITEMTYPE", ITEMTYPE_FURNISHING),
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = ITEMTYPE_FURNISHING, idTypeStr = "itemType" },
				}
			),
		},
		{
			title = GetString(SI_ITEMTYPE48), -- "Trash"
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_TREASURE, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TROPHY_TOY, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_TRASH, idTypeStr = "specializedItemType" },
				}
			),
		},
		{
			title = GetString(SI_ITEMFILTERTYPE5), -- "Miscellanous"
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_CROWN_ITEM, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_LOCKPICK, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_LURE, idTypeStr = "specializedItemType" },
				}
			),
		},
	}
	
	local rulesPanelTabsData = {
		{
			title = GetString(SI_CURRENCY_TYPE_NAME), -- "Currency"
			widgets = BMBF.makeCurrencyTab({
				CURT_MONEY,
				CURT_ALLIANCE_POINTS,
				CURT_TELVAR_STONES,
				CURT_WRIT_VOUCHERS,
			}),
		},
		{
			title = GetString(SI_ITEMFILTERTYPE4), -- "Materials"
			subTabs = craftingTabsData,
		},
		{
			title = GetString(SI_ARMORY_EQUIPMENT_LABEL), -- "Equipment"
			subTabs = equipmentTabsData,
		},
		{
			title = GetString(SI_ITEMTYPEDISPLAYCATEGORY24), -- "Style Motifs"
			widgets = BMBF.makeWidgetsForTypes(
				{
					{ id = SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER, idTypeStr = "specializedItemType" },
					{ id = SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE, idTypeStr = "specializedItemType" },
				}
			),
		},
		{
			title = GetString(SI_TRADINGHOUSECATEGORYHEADER3), -- "Consumables"
			subTabs = consumablesTabsData,
		},
		{
			title = GetString(SI_ITEMFILTERTYPE5), -- "Miscellanous"
			subTabs = miscTabsData,
		},
	}
	
	local settingsTabsData = {
		{
			title = GetString(SI_GAME_MENU_SETTINGS) .. " " .. name, -- "Settings Bankir"
			widgets = BMBF.makeSettingsMenu(),
		},
		{
			title = GetString(BANKIR_MENU_INTEGRATIONS),
			widgets = BMBF.makeLCKSettings(),
		},
	}
	
	local mainTabsData = {
		{
			title = GetString(SI_CAMPAIGN_BROWSER_RULES_HEADER), -- "Rules"
			widgets = {
				BMBF.makeSelectedProfileLabel(),
				BMBF.dividerSmall,
				BMBF.makeBankSelector(),
			},
			subTabs = rulesPanelTabsData,
		},
		{
			title = GetString(SI_GAME_MENU_SETTINGS),
			subTabs = settingsTabsData,
		},
	}
	
	local function onPanelCreated(panel)
		if (panel ~= addonPanel) then return end -- only proceed if this is our settings panel

		local mainPanel = _G["BankirMenuCustomPanel"]
		local panelWidth = addonPanel:GetWidth()
		mainPanel:SetWidth(panelWidth)
		Bankir.createTabs(mainPanel, mainTabsData)
	end
	
	local optionsData = {
		{
			type = "custom",
			reference = "BankirMenuCustomPanel",
		},
	}
	
	LAM:RegisterOptionControls("Bankir_Settings", optionsData)
	
	CALLBACK_MANAGER:RegisterCallback('LAM-PanelControlsCreated', onPanelCreated)
end
