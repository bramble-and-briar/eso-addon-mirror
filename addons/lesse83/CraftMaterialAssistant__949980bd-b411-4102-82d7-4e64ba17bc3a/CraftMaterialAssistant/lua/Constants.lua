CraftMaterialAssistant = CraftMaterialAssistant or {
    name = "CraftMaterialAssistant",
    version = "1.0.5",
    savedVarsName = "CraftMaterialAssistantSavedVars",
    variableVersion = 1
}

local CMA = CraftMaterialAssistant

-- choices used for quality dropdowns in settings
CMA.qualityDropdownChoices = {"Grey", "White", "Green", "Blue", "Purple", "Gold", "Orange"}

-- mapping of quality choices to game constants
CMA.qualityMap = {
    ["Grey"] = ITEM_DISPLAY_QUALITY_TRASH,
    ["White"] = ITEM_DISPLAY_QUALITY_NORMAL,
    ["Green"] = ITEM_DISPLAY_QUALITY_MAGIC,
    ["Blue"] = ITEM_DISPLAY_QUALITY_ARCANE,
    ["Purple"] = ITEM_DISPLAY_QUALITY_ARTIFACT,
    ["Gold"] = ITEM_DISPLAY_QUALITY_LEGENDARY,
    ["Orange"] = ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
}

-- choices for other materials
CMA.simpleMaterialChoices = {"Bank", "Sell", "Ignore"}

-- simple material choices mapped to decision values
CMA.simpleMaterialDecisionMap = {
    ["Bank"] = "bank",
    ["Sell"] = "junk",
    ["Ignore"] = "ignore"
}

-- default settings values
CMA.savedVarsDefaults = {
    -- master toggle
    enableAddon = true,
    -- categorie toggles
    bankBlacksmithing = true,
    bankClothing = true,
    bankWoodworking = true,
    bankJewelry = true,
    bankRawJewelryTraits = true,
    bankEnchanting = true,
    bankEssenceRunes = true,
    bankAlchemy = true,
    bankAlchemyReagents = true,
    bankProvisioning = true,
    bankProvisioningKeepWritIngredients = true,
    bankProvisioningKeepOtherIngredients = true,
    bankProvisioningSellKnownRecipe = false,
    bankScribingMaterials = true,
    bankUnknownScripts = true,
    bankUnboundScripts = "Bank",
    bankFurnishingMaterials = "Bank",
    bankBait = "Bank",
    bankInk = "Bank",
    bankRawMaterials = "Bank",
    bankStyleMaterials = "Bank",
    limitStyleMaterialByCount = false,
    bankMinimumNumberStyleMaterial = 190,
    bankTraitMaterials = "Bank",
    limitTraitMaterialByCount = false,
    bankMinimumNumberTraitMaterial = 190,
    bankResearchableItems = false,
    actionKnownTraitItems = "Sell",
    initialDelayInMs = 3000,
    autoSellJunk = true,
    -- quality thresholds
    bankQualityThresholdBlacksmithing = "Grey",
    bankQualityThresholdClothing = "Grey",
    bankQualityThresholdWoodworking = "Grey",
    bankQualityThresholdJewelry = "Grey",
    bankQualityThresholdEnchanting = "Grey",
    bankQualityThresholdProvisioning = "Grey",
    bankQualityThresholdProvisioningRecipe = "Grey",
    -- cp thresholds
    bankTierThresholdBlacksmithing = 1,
    bankTierThresholdClothing = 1,
    bankTierThresholdWoodworking = 1,
    bankTierThresholdJewelry = 1,
    bankImprovementThresholdPotencyRunes = 1,
    bankProficiencyThresholdAlchemyBases = 1,
    -- log toggles
    showBankAlerts = true,
    showJunkAlerts = true,
    showVendorAlerts = true,
    -- toggle: if not selected for banking - vendor
    markAsTrashIfNotBanked = true
}

-- indexed map (by itemId) used to store the items and stack size of items in the bank to be able to directly access them
-- due to potentially having multiple items with the same id, we store the data in comma delimited strings
-- [1]: count of slots found, [2] slotIndexes (comma separated)
CMA.cachedBankSlots = {}

-- character used to separate bank slots
CMA.cachedBankSlotSeparator = ","

-- arrays holding the moved, junked, ignored and failed items - used for the final chat messages
CMA.movedItems = {}
CMA.junkedItems = {}
CMA.ignoredItems = {}
CMA.failedItems = {}

-- name of the timeout event which is used during a move process to react to failed and delayed transfers
CMA.initialTimeoutName = "CraftMaterialAssistant.InitialDelayTimeout"

-- max number of items used in a single chat message
CMA.maxChatMessageItems = 20

-- array holdng the slots which have been junked - they are filled during banking and used when vendoring
CMA.junkedIds = {}

-- the item evaluation of the banking routine filtered those items to be moved to the bank
CMA.itemsToMove = {}

-- used as locking mechanism. being true during indicates an active move process and blocks other overlapping moves
CMA.processingMove = false

-- the slot of the item which is currently being transferred to the bank
CMA.processedSlot = nil

-- the uniqueId of the currently processed item
CMA.processedUniqueId = nil

-- number of retries for a item until give up (unless there is no space left)
CMA.numberOfRetriesPerItem = 0

-- table holding the count for failed move attempts per unique item id
CMA.failedItemMoveAttempts = {}

-- name of the timeout event which is used during a move process to react to failed and delayed transfers
CMA.moveTimeoutName = "CraftMaterialAssistant.MoveTimeout"

-- the destination bag (for now only the bank)
CMA.targetBag = BAG_BANK

-- the source bag (for now only the characters backpack)
CMA.sourceBag = BAG_BACKPACK

-- Blacksmithing Material Tiers indexed by ItemId
CMA.blacksmithingTierInfo = "\nTier 1: Gear Level 1\nTier 2: Gear Level 16\nTier 3: Gear Level 26\nTier 4: Gear Level 36\nTier 5: Gear Level 46\nTier 6: Gear Level CP10\nTier 7: Gear Level CP40\nTier 8: Gear Level CP70\nTier 9: Gear Level CP90\nTier 10: Gear Level CP150\n11: Bank none"
CMA.blacksmithingMaterialMap = {
    [808]   = { tier = 1, name = "Iron Ore", levelMin = 1, levelMax = 14, isRefined = false },
    [5413]  = { tier = 1, name = "Iron Ingot", levelMin = 1, levelMax = 14, isRefined = true },
    [5820]  = { tier = 2, name = "High Iron Ore", levelMin = 16, levelMax = 24, isRefined = false },
    [4487]  = { tier = 2, name = "Steel Ingot", levelMin = 16, levelMax = 24, isRefined = true },
    [23103] = { tier = 3, name = "Orichalcum Ore", levelMin = 26, levelMax = 34, isRefined = false },
    [23107] = { tier = 3, name = "Orichalcum Ingot", levelMin = 26, levelMax = 34, isRefined = true },
    [23104] = { tier = 4, name = "Dwarven Ore", levelMin = 36, levelMax = 44, isRefined = false },
    [6000]  = { tier = 4, name = "Dwarven Ingot", levelMin = 36, levelMax = 44, isRefined = true },
    [23105] = { tier = 5, name = "Ebony Ore", levelMin = 46, levelMax = 50, isRefined = false },
    [6001]  = { tier = 5, name = "Ebony Ingot", levelMin = 46, levelMax = 50, isRefined = true },
    [4482]  = { tier = 6, name = "Calcinium Ore", levelMin = 10, levelMax = 30, isRefined = false, isCP = true },
    [46127] = { tier = 6, name = "Calcinium Ingot", levelMin = 10, levelMax = 30, isRefined = true, isCP = true },
    [23133] = { tier = 7, name = "Galatite Ore", levelMin = 40, levelMax = 60, isRefined = false, isCP = true },
    [46128] = { tier = 7, name = "Galatite Ingot", levelMin = 40, levelMax = 60, isRefined = true, isCP = true },
    [23134] = { tier = 8, name = "Quicksilver Ore", levelMin = 70, levelMax = 80, isRefined = false, isCP = true },
    [46129] = { tier = 8, name = "Quicksilver Ingot", levelMin = 70, levelMax = 80, isRefined = true, isCP = true },
    [23135] = { tier = 9, name = "Voidstone Ore", levelMin = 90, levelMax = 140, isRefined = false, isCP = true },
    [46130] = { tier = 9, name = "Voidstone Ingot", levelMin = 90, levelMax = 140, isRefined = true, isCP = true },
    [71198] = { tier = 10, name = "Rubedite Ore", levelMin = 150, levelMax = 160, isRefined = false, isCP = true },
    [64489] = { tier = 10, name = "Rubedite Ingot", levelMin = 150, levelMax = 160, isRefined = true, isCP = true },
}

-- Woodworking Material Tiers indexed by ItemId
CMA.woodworkingTierInfo = "\nTier 1: Gear Level 1\nTier 2: Gear Level 16\nTier 3: Gear Level 26\nTier 4: Gear Level 36\nTier 5: Gear Level 46\nTier 6: Gear Level CP10\nTier 7: Gear Level CP40\nTier 8: Gear Level CP70\nTier 9: Gear Level CP90\nTier 10: Gear Level CP150\n11: Bank none"
CMA.woodworkingMaterialMap = {
    [802]   = { tier = 1, name = "Rough Maple", levelMin = 1, levelMax = 14, isRefined = false },
    [803]   = { tier = 1, name = "Sanded Maple", levelMin = 1, levelMax = 14, isRefined = true },
    [521]   = { tier = 2, name = "Rough Oak", levelMin = 16, levelMax = 24, isRefined = false },
    [533]   = { tier = 2, name = "Sanded Oak", levelMin = 16, levelMax = 24, isRefined = true },
    [23117] = { tier = 3, name = "Rough Beech", levelMin = 26, levelMax = 34, isRefined = false },
    [23121] = { tier = 3, name = "Sanded Beech", levelMin = 26, levelMax = 34, isRefined = true },
    [23118] = { tier = 4, name = "Rough Hickory", levelMin = 36, levelMax = 44, isRefined = false },
    [23122] = { tier = 4, name = "Sanded Hickory", levelMin = 36, levelMax = 44, isRefined = true },
    [23119] = { tier = 5, name = "Rough Yew", levelMin = 46, levelMax = 50, isRefined = false },
    [23123] = { tier = 5, name = "Sanded Yew", levelMin = 46, levelMax = 50, isRefined = true },
    [818]   = { tier = 6, name = "Rough Birch", levelMin = 10, levelMax = 30, isRefined = false, isCP = true },
    [46139] = { tier = 6, name = "Sanded Birch", levelMin = 10, levelMax = 30, isRefined = true, isCP = true },
    [4439]  = { tier = 7, name = "Rough Ash", levelMin = 40, levelMax = 60, isRefined = false, isCP = true },
    [46140] = { tier = 7, name = "Sanded Ash", levelMin = 40, levelMax = 60, isRefined = true, isCP = true },
    [23137] = { tier = 8, name = "Rough Mahogany", levelMin = 70, levelMax = 80, isRefined = false, isCP = true },
    [46141] = { tier = 8, name = "Sanded Mahogany", levelMin = 70, levelMax = 80, isRefined = true, isCP = true },
    [23138] = { tier = 9, name = "Rough Nightwood", levelMin = 90, levelMax = 140, isRefined = false, isCP = true },
    [46142] = { tier = 9, name = "Sanded Nightwood", levelMin = 90, levelMax = 140, isRefined = true, isCP = true },
    [71199] = { tier = 10, name = "Rough Ruby Ash", levelMin = 150, levelMax = 160, isRefined = false, isCP = true },
    [64502] = { tier = 10, name = "Sanded Ruby Ash", levelMin = 150, levelMax = 160, isRefined = true, isCP = true },
}

-- Clothing Material Tiers indexed by ItemId
CMA.clothingTierInfo = "\nTier 1: Gear Level 1\nTier 2: Gear Level 16\nTier 3: Gear Level 26\nTier 4: Gear Level 36\nTier 5: Gear Level 46\nTier 6: Gear Level CP10\nTier 7: Gear Level CP40\nTier 8: Gear Level CP70\nTier 9: Gear Level CP90\nTier 10: Gear Level CP150\n11: Bank none"
CMA.clothingMaterialMap = {
    [812]   = { tier = 1, subType = "Light", name = "Raw Jute", levelMin = 1, levelMax = 14, isRefined = false },
    [811]   = { tier = 1, subType = "Light", name = "Jute", levelMin = 1, levelMax = 14, isRefined = true },
    [4464]  = { tier = 2, subType = "Light", name = "Raw Flax", levelMin = 16, levelMax = 24, isRefined = false },
    [4463]  = { tier = 2, subType = "Light", name = "Flax", levelMin = 16, levelMax = 24, isRefined = true },
    [23129] = { tier = 3, subType = "Light", name = "Raw Cotton", levelMin = 26, levelMax = 34, isRefined = false },
    [23125] = { tier = 3, subType = "Light", name = "Cotton", levelMin = 26, levelMax = 34, isRefined = true },
    [23130] = { tier = 4, subType = "Light", name = "Raw Spidersilk", levelMin = 36, levelMax = 44, isRefined = false },
    [23126] = { tier = 4, subType = "Light", name = "Spidersilk", levelMin = 36, levelMax = 44, isRefined = true },
    [23131] = { tier = 5, subType = "Light", name = "Raw Ebonthread", levelMin = 46, levelMax = 50, isRefined = false },
    [23127] = { tier = 5, subType = "Light", name = "Ebonthread", levelMin = 46, levelMax = 50, isRefined = true },
    [33217] = { tier = 6, subType = "Light", name = "Raw Kresh Fibre", levelMin = 10, levelMax = 30, isRefined = false, isCP = true },
    [46131] = { tier = 6, subType = "Light", name = "Kresh Cloth", levelMin = 10, levelMax = 30, isRefined = true, isCP = true },
    [33218] = { tier = 7, subType = "Light", name = "Raw Ironthread", levelMin = 40, levelMax = 60, isRefined = false, isCP = true },
    [46132] = { tier = 7, subType = "Light", name = "Ironthread", levelMin = 40, levelMax = 60, isRefined = true, isCP = true },
    [33219] = { tier = 8, subType = "Light", name = "Raw Silverweave", levelMin = 70, levelMax = 80, isRefined = false, isCP = true },
    [46133] = { tier = 8, subType = "Light", name = "Silverweave", levelMin = 70, levelMax = 80, isRefined = true, isCP = true },
    [33220] = { tier = 9, subType = "Light", name = "Raw Void Bloom", levelMin = 90, levelMax = 140, isRefined = false, isCP = true },
    [46134] = { tier = 9, subType = "Light", name = "Void Cloth", levelMin = 90, levelMax = 140, isRefined = true, isCP = true },
    [71200] = { tier = 10, subType = "Light", name = "Raw Ancestor Silk", levelMin = 150, levelMax = 160, isRefined = false, isCP = true },
    [64504] = { tier = 10, subType = "Light", name = "Ancestor Silk", levelMin = 150, levelMax = 160, isRefined = true, isCP = true },
    [793]   = { tier = 1, subType = "Medium", name = "Rawhide Scraps", levelMin = 1, levelMax = 14, isRefined = false },
    [794]   = { tier = 1, subType = "Medium", name = "Rawhide", levelMin = 1, levelMax = 14, isRefined = true },
    [4448]  = { tier = 2, subType = "Medium", name = "Hide Scraps", levelMin = 16, levelMax = 24, isRefined = false },
    [4447]  = { tier = 2, subType = "Medium", name = "Hide", levelMin = 16, levelMax = 24, isRefined = true },
    [23095] = { tier = 3, subType = "Medium", name = "Leather Scraps", levelMin = 26, levelMax = 34, isRefined = false },
    [23099] = { tier = 3, subType = "Medium", name = "Leather", levelMin = 26, levelMax = 34, isRefined = true },
    [6020]  = { tier = 4, subType = "Medium", name = "Thick Leather Scraps", levelMin = 36, levelMax = 44, isRefined = false },
    [23100] = { tier = 4, subType = "Medium", name = "Thick Leather", levelMin = 36, levelMax = 44, isRefined = true },
    [23097] = { tier = 5, subType = "Medium", name = "Fell Hide Scraps", levelMin = 46, levelMax = 50, isRefined = false },
    [23101] = { tier = 5, subType = "Medium", name = "Fell Hide", levelMin = 46, levelMax = 50, isRefined = true },
    [23142] = { tier = 6, subType = "Medium", name = "Topgrain Hide Scraps", levelMin = 10, levelMax = 30, isRefined = false, isCP = true },
    [46135] = { tier = 6, subType = "Medium", name = "Topgrain Leather", levelMin = 10, levelMax = 30, isRefined = true, isCP = true },
    [23143] = { tier = 7, subType = "Medium", name = "Iron Hide Scraps", levelMin = 40, levelMax = 60, isRefined = false, isCP = true },
    [46136] = { tier = 7, subType = "Medium", name = "Iron Leather", levelMin = 40, levelMax = 60, isRefined = true, isCP = true },
    [800]   = { tier = 8, subType = "Medium", name = "Superb Hide Scraps", levelMin = 70, levelMax = 80, isRefined = false, isCP = true },
    [46137] = { tier = 8, subType = "Medium", name = "Superb Leather", levelMin = 70, levelMax = 80, isRefined = true, isCP = true },
    [4478]  = { tier = 9, subType = "Medium", name = "Shadowhide Scraps", levelMin = 90, levelMax = 140, isRefined = false, isCP = true },
    [46138] = { tier = 9, subType = "Medium", name = "Shadow Leather", levelMin = 90, levelMax = 140, isRefined = true, isCP = true },
    [71239] = { tier = 10, subType = "Medium", name = "Rubedo Hide Scraps", levelMin = 150, levelMax = 160, isRefined = false, isCP = true },
    [64506] = { tier = 10, subType = "Medium", name = "Rubedo Leather", levelMin = 150, levelMax = 160, isRefined = true, isCP = true },
}

-- Jewelcrafting Material Tiers indexed by ItemId
CMA.jewelryTierInfo = "\nTier 1: Gear Level 1\nTier 2: Gear Level 26\nTier 3: Gear Level CP10\nTier 4: Gear Level CP70\nTier 5: Gear Level CP150\n6: Bank none"
CMA.jewelryMaterialMap = {
    [135137] = { tier = 1, name = "Pewter Dust", levelMin = 1, levelMax = 25, isRefined = false },
    [135138] = { tier = 1, name = "Pewter Ounce", levelMin = 1, levelMax = 25, isRefined = true },
    [135139] = { tier = 2, name = "Copper Dust", levelMin = 26, levelMax = 50, isRefined = false },
    [135140] = { tier = 2, name = "Copper Ounce", levelMin = 26, levelMax = 50, isRefined = true },
    [135141] = { tier = 3, name = "Silver Dust", levelMin = 10, levelMax = 60, isRefined = false, isCP = true },
    [135142] = { tier = 3, name = "Silver Ounce", levelMin = 10, levelMax = 60, isRefined = true, isCP = true },
    [135143] = { tier = 4, name = "Electrum Dust", levelMin = 70, levelMax = 140, isRefined = false, isCP = true },
    [135144] = { tier = 4, name = "Electrum Ounce", levelMin = 70, levelMax = 140, isRefined = true, isCP = true },
    [135145] = { tier = 5, name = "Platinum Dust", levelMin = 150, levelMax = 160, isRefined = false, isCP = true },
    [135146] = { tier = 5, name = "Platinum Ounce", levelMin = 150, levelMax = 160, isRefined = true, isCP = true },
}

-- Enchanting Potency Runes Indexed by ItemId
CMA.enchantingTierInfo = "\nTier 1: Improvement Level 1\nTier 2: Improvement Level 1\nTier 3: Improvement Level 3\nTier 4: Improvement Level 4\nTier 5: Improvement Level 5\nTier 6: Improvement Level 6\nTier 7: Improvement Level 7\nTier 8: Improvement Level 8\nTier 9: Improvement Level 9\nTier 10: Improvement Level 10\nTier 11: Bank none"
CMA.enchantingMaterialMap = {
    [45855] = { tier = 1, name = "Jora", direction = "Additive", levelMin = 1, levelMax = 10, isCP = false },
    [45856] = { tier = 1, name = "Porade", direction = "Additive", levelMin = 5, levelMax = 15, isCP = false },
    [45857] = { tier = 2, name = "Jera", direction = "Additive", levelMin = 10, levelMax = 20, isCP = false },
    [45806] = { tier = 2, name = "Jejora", direction = "Additive", levelMin = 15, levelMax = 25, isCP = false },
    [45807] = { tier = 3, name = "Odra", direction = "Additive", levelMin = 20, levelMax = 30, isCP = false },
    [45808] = { tier = 3, name = "Pojora", direction = "Additive", levelMin = 25, levelMax = 35, isCP = false },
    [45809] = { tier = 4, name = "Edora", direction = "Additive", levelMin = 30, levelMax = 40, isCP = false },
    [45810] = { tier = 4, name = "Jaera", direction = "Additive", levelMin = 35, levelMax = 45, isCP = false },
    [45811] = { tier = 5, name = "Pora", direction = "Additive", levelMin = 40, levelMax = 50, isCP = false },
    [45812] = { tier = 5, name = "Denara", direction = "Additive", levelMin = 10, levelMax = 30, isCP = true },
    [45813] = { tier = 6, name = "Rera", direction = "Additive", levelMin = 30, levelMax = 50, isCP = true },
    [45814] = { tier = 7, name = "Derado", direction = "Additive", levelMin = 50, levelMax = 70, isCP = true },
    [45815] = { tier = 8, name = "Rekura", direction = "Additive", levelMin = 70, levelMax = 90, isCP = true },
    [45816] = { tier = 9, name = "Kura", direction = "Additive", levelMin = 100, levelMax = 140, isCP = true },
    [64509] = { tier = 10, name = "Rejera", direction = "Additive", levelMin = 150, levelMax = 150, isCP = true },
    [68341] = { tier = 10, name = "Repora", direction = "Additive", levelMin = 160, levelMax = 160, isCP = true },
    [45817] = { tier = 1, name = "Jode", direction = "Subtractive", levelMin = 1, levelMax = 10, isCP = false },
    [45818] = { tier = 1, name = "Notade", direction = "Subtractive", levelMin = 5, levelMax = 15, isCP = false },
    [45819] = { tier = 2, name = "Ode", direction = "Subtractive", levelMin = 10, levelMax = 20, isCP = false },
    [45820] = { tier = 2, name = "Tade", direction = "Subtractive", levelMin = 15, levelMax = 25, isCP = false },
    [45821] = { tier = 3, name = "Jayde", direction = "Subtractive", levelMin = 20, levelMax = 30, isCP = false },
    [45822] = { tier = 3, name = "Edode", direction = "Subtractive", levelMin = 25, levelMax = 35, isCP = false },
    [45823] = { tier = 4, name = "Pojode", direction = "Subtractive", levelMin = 30, levelMax = 40, isCP = false },
    [45824] = { tier = 4, name = "Rekude", direction = "Subtractive", levelMin = 35, levelMax = 45, isCP = false },
    [45825] = { tier = 5, name = "Hade", direction = "Subtractive", levelMin = 40, levelMax = 50, isCP = false },
    [45826] = { tier = 5, name = "Idode", direction = "Subtractive", levelMin = 10, levelMax = 30, isCP = true },
    [45827] = { tier = 6, name = "Pode", direction = "Subtractive", levelMin = 30, levelMax = 50, isCP = true },
    [45828] = { tier = 7, name = "Kedeko", direction = "Subtractive", levelMin = 50, levelMax = 70, isCP = true },
    [45829] = { tier = 8, name = "Rede", direction = "Subtractive", levelMin = 70, levelMax = 90, isCP = true },
    [45830] = { tier = 9, name = "Kude", direction = "Subtractive", levelMin = 100, levelMax = 140, isCP = true },
    [64508] = { tier = 10, name = "Jehade", direction = "Subtractive", levelMin = 150, levelMax = 150, isCP = true },
    [68340] = { tier = 10, name = "Itade", direction = "Subtractive", levelMin = 160, levelMax = 160, isCP = true }
}


-- Alchemy Bases Indexed by ItemId
CMA.alchemyTierInfo = "\nTier 1: Proficiency Level 1\nTier 2: Proficiency Level 1\nTier 3: Proficiency Level 3\nTier 4: Proficiency Level 4\nTier 5: Proficiency Level 5\nTier 6: Proficiency Level 6\nTier 7: Proficiency Level 7\nTier 8: Proficiency Level 8\nTier 9: Bank none"
CMA.alchemyMaterialMap = {
    [883]   = { name = "Natural Water", tier = 1, levelMin = 3, levelMax = 3, isCP = false, isPoison = false },
    [1187]  = { name = "Clear Water", tier = 1, levelMin = 10, levelMax = 10, isCP = false, isPoison = false },
    [4570]  = { name = "Pristine Water", tier = 2, levelMin = 20, levelMax = 20, isCP = false, isPoison = false },
    [23265] = { name = "Cleansed Water", tier = 3, levelMin = 30, levelMax = 30, isCP = false, isPoison = false },
    [23266] = { name = "Filtered Water", tier = 4, levelMin = 40, levelMax = 40, isCP = false, isPoison = false },
    [23267] = { name = "Purified Water", tier = 5, levelMin = 10, levelMax = 10, isCP = true, isPoison = false },
    [23268] = { name = "Cloud Mist", tier = 6, levelMin = 50, levelMax = 50, isCP = true, isPoison = false },
    [64500] = { name = "Star Dew", tier = 7, levelMin = 100, levelMax = 100, isCP = true, isPoison = false },
    [64501] = { name = "Lorkhan's Tears", tier = 8, levelMin = 150, levelMax = 160, isCP = true, isPoison = false },
    [75357] = { name = "Grease", tier = 1, levelMin = 3, levelMax = 3, isCP = false, isPoison = true },
    [75358] = { name = "Ichor", tier = 1, levelMin = 10, levelMax = 10, isCP = false, isPoison = true },
    [75359] = { name = "Slime", tier = 2, levelMin = 20, levelMax = 20, isCP = false, isPoison = true },
    [75360] = { name = "Gall", tier = 3, levelMin = 30, levelMax = 30, isCP = false, isPoison = true },
    [75361] = { name = "Terebinthine", tier = 4, levelMin = 40, levelMax = 40, isCP = false, isPoison = true },
    [75362] = { name = "Pitch-Bile", tier = 5, levelMin = 10, levelMax = 10, isCP = true, isPoison = true },
    [75363] = { name = "Tarblack", tier = 6, levelMin = 50, levelMax = 50, isCP = true, isPoison = true },
    [75364] = { name = "Night-Oil", tier = 7, levelMin = 100, levelMax = 100, isCP = true, isPoison = true },
    [75365] = { name = "Alkahest", tier = 8, levelMin = 150, levelMax = 160, isCP = true, isPoison = true },
}

-- itemIds of top level writ ingredients
CMA.provisioningTopLevelWritIngredientsMap = {
    [34324] = { name = "Carrots"},
    [27063] = { name = "Saltrice"},
    [34311] = { name = "Apples"},
    [27057] = { name = "Cheese"},
    [33756] = { name = "Small Game"},
    [33753] = { name = "Fish"}, -- 42866
    [26954] = { name = "Garlic"},
    [28610] = { name = "Jazbay Grapes"},
    [34345] = { name = "Surilie Grapes"},
    [27049] = { name = "Lemon "},
    [33771] = { name = "Jasmine"},
    [27043] = { name = "Honey"},
    [34334] = { name = "Bittergreen"},
    [27048] = { name = "Metheglin"},
    [27052] = { name = "Ginger"},
    [34329] = { name = "Barley"},
    [34346] = { name = "Ginkgo"}
}

-- traitType index lookup map
CMA.traitTypeIndexMap = {
    [ITEM_TRAIT_TYPE_WEAPON_POWERED] = 1,
    [ITEM_TRAIT_TYPE_WEAPON_CHARGED] = 2,
    [ITEM_TRAIT_TYPE_WEAPON_PRECISE] = 3,
    [ITEM_TRAIT_TYPE_WEAPON_INFUSED] = 4,
    [ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = 5,
    [ITEM_TRAIT_TYPE_WEAPON_TRAINING] = 6,
    [ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = 7,
    [ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = 8,
    [ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = 9,
    [ITEM_TRAIT_TYPE_ARMOR_STURDY] = 1,
    [ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = 2,
    [ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = 3,
    [ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = 4,
    [ITEM_TRAIT_TYPE_ARMOR_TRAINING] = 5,
    [ITEM_TRAIT_TYPE_ARMOR_INFUSED] = 6,
    [ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = 7,
    [ITEM_TRAIT_TYPE_ARMOR_DIVINES] = 8,
    [ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = 9,
    [ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = 1,
    [ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = 2,
    [ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = 3,
    [ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = 4,
    [ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = 6,
    [ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = 7,
    [ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = 8,
    [ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = 9
}

-- mapping equipType to research line index
-- due to clothing stations featuring light & medium armor, light armor indexes are decreased by 7 (1-7 are for light armor)
CMA.researchLineIndexEquipTypeMap = {
    [EQUIP_TYPE_CHEST] = 8,
    [EQUIP_TYPE_FEET] = 9,
    [EQUIP_TYPE_HAND] = 10,
    [EQUIP_TYPE_HEAD] = 11,
    [EQUIP_TYPE_LEGS] = 12,
    [EQUIP_TYPE_SHOULDERS] = 13,
    [EQUIP_TYPE_WAIST] = 14,
    [EQUIP_TYPE_NECK] = 1,
    [EQUIP_TYPE_RING] = 2
}

-- mapping weaponType to research line index
CMA.researchLineIndexWeaponTypeMap = {
    [WEAPONTYPE_AXE] = 1,
    [WEAPONTYPE_HAMMER] = 2,
    [WEAPONTYPE_SWORD] = 3,
    [WEAPONTYPE_TWO_HANDED_AXE] = 4,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = 5,
    [WEAPONTYPE_TWO_HANDED_SWORD] = 6,
    [WEAPONTYPE_DAGGER] = 7,
    [WEAPONTYPE_BOW] = 1,
    [WEAPONTYPE_FIRE_STAFF] = 2,
    [WEAPONTYPE_FROST_STAFF] = 3,
    [WEAPONTYPE_LIGHTNING_STAFF] = 4,
    [WEAPONTYPE_HEALING_STAFF] = 5
}