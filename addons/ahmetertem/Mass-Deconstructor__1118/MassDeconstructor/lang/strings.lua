local strings = {
    SI_MASSDECON_ACCOUNT_SETTINGS =			"Account Settings",
    SI_MASSDECON_ACCOUNT_WIDE =				"Account Wide",
    SI_MASSDECON_ACCOUNT_WIDE_DESC =		"Use account-wide (ON) or character-specific (OFF) addon settings.",

	SI_MASSDECON_REFINEMENT_SETTINGS =		"Refinement Settings",
	SI_MASSDECON_REFINE_ENTIRE_STACK =		"Refine full stacks",
	SI_MASSDECON_REFINE_STACK_DESC =		"Refine entire stacks (ON - for faster refinement) or refine stacks of 10 at a time (OFF - to keep original behaviour, this is also much slower).",

	SI_MASSDECON_DECON_SETTINGS	=			"Deconstruction Settings",
	SI_MASSDECON_DECON_PROTECTION =			"TTC average listing price protection ( 0 = OFF )",--<<@sinnereso
	SI_MASSDECON_DECON_BANKED =				"Deconstruct banked items",--<<@sinnereso
	SI_MASSDECON_DECON_BOP_TRADEABLE =		"Deconstruct BOP tradeable items",--<<@sinnereso
	SI_MASSDECON_DECON_TRAITLESS = 			"Deconstruct items with no trait",
	SI_MASSDECON_DECON_BOUND = 				"Deconstruct bound items",
	SI_MASSDECON_DECON_SET_PIECES = 		"Deconstruct set pieces",
	SI_MASSDECON_DECON_RETRAITED = 			"Deconstruct re-traited items",
	SI_MASSDECON_DECON_RECONSTRUCTED = 		"Deconstruct reconstructed items",
	SI_MASSDECON_DECON_RESEARCHABLE = 		"Deconstruct researchable items",
	SI_MASSDECON_DECON_RESEARCH_TIP = 		"Deconstruct items which can be researched on this character.",
	SI_MASSDECON_DECON_CRAFTED = 			"Deconstruct crafted items",

	SI_MASSDECON_LIST_ITEMS = 				"List items before starting work",
	SI_MASSDECON_DEBUG = 					"Debug",	-- Outputs debug spam in chat
	SI_MASSDECON_CHAT_NO_ITEMS =			"No items in deconstruction queue.",
	SI_MASSDECON_CHAT_LIST_ITEM =			"Mass Deconstruct will destroy %d item:",
	SI_MASSDECON_CHAT_LIST_ITEMS =			"Mass Deconstruct will destroy %d items:",
	-- %d is the quantity, %s is singular "item" or plural "items"
	-- Mass Deconstruct will destroy 1 item:
	-- Mass Deconstruct will destroy 2 items:
	-- Mass Deconstruct wird 1 Gegendstand zerstören:
	-- Mass Deconstruct wird 2 Gegenstände zerstören: 
	
	SI_MASSDECON_CHAT_DECONSTRUCTING =		"Deconstructing: ",
	SI_MASSDECON_CHAT_QUEUE_LEN =			"Queue length: ",
	SI_MASSDECON_CHAT_ITEM_IN_SLOT_ERR =	"Extracting item already in deconstruction slot",
	SI_MASSDECON_CHAT_CHECKING_CRAFT_BAG =	"Checking crafting bag for refinable items",
	SI_MASSDECON_CHAT_NO_CRAFT_BAG =		"This account doesn't have a crafting bag",
	SI_MASSDECON_CHAT_ITEM_TO_EXTRACT =		"Selecting item to extract",
	SI_MASSDECON_CHAT_NOTHING_LEFT_REFINE =	"Nothing left to refine",
	SI_MASSDECON_CHAT_REFINE_MODE =			"Setting refining mode",
	SI_MASSDECON_CHAT_STATION_TYPE =		"Checking station type",

	SI_MASSDECON_CHAT_EXTRACT_MODE =		"Setting extraction mode",
	SI_MASSDECON_CHAT_DECON_MODE =			"Setting deconstruction mode",

	SI_MASSDECON_CHAT_DECON_FINISHED =		"Deconstruction finished.",
	
	SI_MASSDECON_TOGGLE_ALL_TRAITS =		"Toggle all traits",
	SI_MASSDECON_TOGGLE_ALL_TRAITS_TIP =	"Toggle all traits ON or OFF.\n\nThis is determined by how many options are already on or off. If there are more options off than there are on, then they will all be toggled on.",

	SI_MASSDECON_LEGACY_HEADER = 			"Legacy Settings",
	SI_MASSDECON_LEGACY_DESC = 				"These settings are provided to more closely resemble the original behaviour, in which there is less micromanaging traits.\n\n"..
											"Mass Deconstruct will deconstruct any trait with the exception of those listed below, if those options are set, and the trait-specific options in the sub-categories below will be disabled.\n\n"..
											"Note: settings to allow or prohibit deconstruction of craft lines as well as the option for maximum quality will still accept user input and should be set accordingly.",
	SI_MASSDECON_USE_LEGACY = 				"Deconstruct all traits",
	SI_MASSDECON_USE_LEGACY_INTRICATE = 	"Deconstruct Intricate",
	SI_MASSDECON_USE_LEGACY_ORNATE = 		"Deconstruct Ornate",
	SI_MASSDECON_USE_LEGACY_NIRN = 			"Deconstruct Nirnhoned",

	SI_MASSDECON_DECON_HEADER = 			"Deconstruct by Category & Trait",
	SI_MASSDECON_ENCHANTMENT_OPTIONS = 		"Enchanting Options",
	SI_MASSDECON_CLOTHING_OPTIONS = 		"Clothing Options",
	SI_MASSDECON_BLACKSMITH_OPTIONS = 		"Blacksmithing Options",
	SI_MASSDECON_WOODWORK_OPTIONS = 		"Woodworking Options",
	SI_MASSDECON_JEWELLERY_OPTIONS = 		"Jewellery Crafting Options",

	SI_MASSDECON_ALLOW_DECON = 				"Allow deconstruction",
	SI_MASSDECON_MAX_QUALITY = 				"Maximum item quality to deconstruct",
	SI_MASSDECON_QUALITY_DESC =				"Maximum quality at which items will be destroyed.",

	--[[
	We'll use internal IDs:
		SI_ITEMQUALITY1
		SI_ITEMQUALITY2
		SI_ITEMQUALITY3
		SI_ITEMQUALITY4
		SI_ITEMQUALITY5
	]]--

	SI_MASSDECON_ARMOUR_TRAITS = 			"Armour Traits",
	SI_MASSDECON_WEAPON_TRAITS = 			"Weapon Traits",
	SI_MASSDECON_JEWELLERY_TRAITS = 		"Jewellery Traits",
	-- We'll use internal string IDs for the trait localisation, same as quality
	
	SI_MASSDECON_DECON_ALL =				"Mass Decon",--<<@sinnereso
	SI_MASSDECON_REFINE_ALL =				"Mass Refine",
	
	SI_MASSDECON_TYPE_UNIVERSAL = 			"Deconstruction Assistants",
	SI_MASSDECON_TYPE_CLOTHING = 			"Clothing Station",
	SI_MASSDECON_TYPE_ENCHANTING = 			"Enchanting Table",
	SI_MASSDECON_TYPE_BLACKSMITHING = 		"Blacksmithing Station",
	SI_MASSDECON_TYPE_WOODWORKING = 		"Woodworking Station",
	SI_MASSDECON_TYPE_JEWELLERY = 			"Jewellery Crafting Station",

	SI_MASSDECON_CP_SLOTTED_WARNING = 		"Warning",
	SI_MASSDECON_CP_SLOTTED_CONFIRM = 		"Meticulous Disassembly CP is not unlocked, are you sure you want to continue?",--<<@sinnereso
	SI_MASSDECON_CP_SLOTTED_WARN = 			"Meticulous Disassembly Warning",
	
	

--[[
	"Deconstruction Assistants"
	"Verwertergehilfen"
	"Assistants de déconstruction"
	"解体助手"
	"Разборщики"

	"Clothing Station"
	"Schneidertisch"
	"Atelier de couture"
	"仕立台"
	"Портняжный станок"

	"Enchanting Table"
	"Verzauberungstisch"
	"Table d'enchantement"
	"付呪台"
	"Стол зачарователя"

	"Blacksmithing Station"
	"Schmiedestelle"
	"Atelier de forge"
	"鍛冶台"
	"Кузница"

	"Woodworking Station"
	"Schreinerbank"
	"Atelier de travail du bois"
	"木工台"
	"Столярный верстак"
	
	"Jewelry Crafting Station"
	"Schmuckhandwerkstisch"
	"Atelier de joaillerie"
	"宝飾台"
	"Стол ювелира"

]]--
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(stringId, 1)
end
