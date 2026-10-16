local ua = UAssistant

local function CreateDeconstructProfile()
    return {
        enabled = false,
        maxQuality = ITEM_QUALITY_NORMAL,

        noTrait = false,
        crafted = false,
        ornate = false,
        intricate = false,
        reconstructed = false,
        tradable = false,
        fromBank = false,
        nirnhoned = false,

        researchMode = "none",
    }
end

local function CreateMerchantEquipmentProfile()
    return {
        enabled = false,
        maxQuality = ITEM_QUALITY_NORMAL,
        noTrait = false,
        ornate = false,
        intricate = false,
        tradable = false,
        researchMode = "none",
        traitMaterialsEnabled = false,
        traitMaterials = {},
    }
end

local function CreateMerchantEnchantingProfile()
    return {
        enabled = false,
        maxQuality = ITEM_QUALITY_NORMAL,
        potencyRunesEnabled = false,
        potencyRunes = {},
        essenceRunesEnabled = false,
        essenceRunes = {},
        aspectRunesEnabled = false,
        aspectRunes = {},
    }
end

local function CreateMerchantConsumablesProfile()
    return {
        enabled = false,
        foodDrinkEnabled = false,
        foodDrinkMaxQuality = ITEM_QUALITY_NORMAL,
        excludeFoodDrinkCP150 = false,
        nonCraftedFoodDrink = false,

        potionPoisonEnabled = false,
        excludePotionPoisonCP150 = false,
        nonCraftedPotionPoison = false,

        knownRecipesEnabled = false,
        recipeMaxQuality = ITEM_QUALITY_NORMAL,

        knownHousingPatternsEnabled = false,
        housingPatternMaxQuality = ITEM_QUALITY_NORMAL,
    }
end

local function CreateMerchantMaterialsProfile()
    return {
        blacksmithingEnabled = false,
        blacksmithingRawEnabled = false,
        clothingMaterialsEnabled = false,
        clothingRawMaterialsEnabled = false,
        leatherMaterialsEnabled = false,
        leatherRawMaterialsEnabled = false,
        woodworkingEnabled = false,
        woodworkingRawEnabled = false,
        jewelryMaterialsEnabled = false,
        jewelryRawMaterialsEnabled = false,
        rawMaterials = {},
        rawMaterialsMigrated = false,
        rawMaterialMaximumsMigrated = false,
        furnishingMaterialsEnabled = false,
        furnishingMaterials = {},
        styleMaterialsEnabled = false,
        styleMaterials = {},
    }
end

local function CreateMerchantResourcesProfile()
    return {
        provisioningEnabled = false,
        provisioningIngredients = {},
        alchemyEnabled = false,
        alchemyIngredients = {},
        alchemySolventsEnabled = false,
        alchemySolvents = {},
    }
end

local function CreateMerchantOtherProfile()
    return {
        emptySoulGemsEnabled = false,
        undauntedPlunderEnabled = false,
        treasuresEnabled = false,
        trashEnabled = false,
        monsterTrophiesEnabled = false,
        fishingBaitEnabled = false,
        trophyFishEnabled = false,
    }
end

local function CreateMerchantAutoPurchaseProfile()
    return {
        items = {
            soulGem = {
                enabled = false,
                target = 1,
            },
            repairKit = {
                enabled = false,
                target = 1,
            },
            triRestorationPotion = {
                enabled = false,
                target = 1,
            },
            cyrodiilRepairKit = {
                enabled = false,
                target = 1,
                priority = "ap_first",
            },
            flamingOil = {
                enabled = false,
                target = 1,
            },
            forwardCamp = {
                enabled = false,
                target = 1,
            },
            ballista = {
                enabled = false,
                target = 1,
            },
            meatbagCatapult = {
                enabled = false,
                target = 1,
            },
            batteringRam = {
                enabled = false,
                target = 1,
            },
            keepRecallStone = {
                enabled = false,
                target = 1,
            },
            sigilOfImperialRetreat = {
                enabled = false,
                target = 1,
            },
        },
    }
end

local function GetSavedVariableDefaults()
    local defaults = ua.GetAccountDefaults()
    local savedRoot = _G["UAssistantSavedVariables"]

    if not savedRoot then
        return defaults
    end

    local displayName = GetDisplayName()
    local worldName = GetWorldName()
    local profileData = savedRoot["Default"]
    local displayData = profileData and profileData[displayName]
    local accountData = displayData and displayData["$AccountWide"]
    local currentSettings = accountData and accountData[worldName]

    if currentSettings then
        return defaults
    end

    local oldSettings = accountData

    if not oldSettings then
        return defaults
    end

    local migratedDefaults = defaults
    local migratableKeys = {
        "language",
        "showWelcome",
        "accountWide",
        "bankingEnabled",
        "repairEnabled",
        "undauntedPledgesEnabled",
        "deconstructEnabled",
        "merchantEnabled",
        "merchantChatMessages",
        "merchantPurchaseChatMessages",
        "merchantChatMode",
        "deconstructChatMessages",
        "repairAndRecharge",
        "banking",
        "deconstructProfiles",
        "merchantProfiles",
    }

    for _, key in ipairs(migratableKeys) do
        local value = rawget(oldSettings, key)

        if value ~= nil then
            if type(value) == "table" then
                migratedDefaults[key] = ZO_DeepTableCopy(value)
            else
                migratedDefaults[key] = value
            end
        end
    end

    return migratedDefaults
end

function ua.Initialize()
    local hadProfileSystem = ua.Profiles.HasStoredProfileSystem()

    ua.profileStorage = ZO_SavedVars:NewAccountWide(
        "UAssistantSavedVariables",
        1,
        GetWorldName(),
        GetSavedVariableDefaults()
    )

    ua.Profiles.Initialize(hadProfileSystem)

    if not ua.profileStorage.language then
        ua.profileStorage.language = ua.GetLanguageCode()
    end

    SafeAddString(SI_UA_ADDON_NAME, ua.GetString("ADDON_NAME"), 1)
    SafeAddString(SI_BINDING_NAME_UA_DECONSTRUCT, ua.GetString("MASS_DECONSTRUCT"), 1)

    ua.RegisterWelcome()
    ua.LoadModules()
    ua.CreateSettings()
end

function ua.GetAccountDefaults()
    return {
        language = ua.Localization.defaultLanguage,
        showWelcome = false,
        accountWide = true,
        profileSystemVersion = 1,
        characterProfiles = {},

        bankingEnabled = false,
        repairEnabled = false,
        undauntedPledgesEnabled = false,
        deconstructEnabled = false,
        merchantEnabled = false,
        merchantChatMessages = false,
        merchantPurchaseChatMessages = false,
        merchantChatMode = "summary",
        deconstructChatMessages = false,

        banking = {
            craftingItemsEnabled = false,
            specialItemsEnabled = false,
            pvpEnabled = false,
            stackBankOnOpen = false,
            stackBackpackOnOpen = false,
            chatReportMode = "none",
            currencies = {
                gold = {
                    enabled = false,
                    minimum = 1000,
                    maximum = 5000,
                },
                alliancePoints = {
                    enabled = false,
                    minimum = 1000,
                    maximum = 5000,
                },
                telVarStones = {
                    enabled = false,
                    minimum = 1000,
                    maximum = 5000,
                },
                writVouchers = {
                    enabled = false,
                    minimum = 10,
                    maximum = 100,
                },
            },
            equipment = {
                weaponIntricateMode = "none",
                clothingIntricateMode = "none",
                jewelryIntricateMode = "none",
            },
            craftingItems = {
                stackPlacement = {
                    mode = "none",
                    bankStackCount = 1,
                    guildId = 0,
                    houseBankBagId = 0,
                },
            },
            specialItems = {
                potions = {},
                foodsDrinks = {},
                undauntedPlunderMode = "none",
                soulGems = {
                    minimum = 0,
                    maximum = 0,
                },
            },
            pvp = {},
        },

        repairAndRecharge = {
            autoRepair = false,
            repairThreshold = 10,
            useCrownRepairKitsFirst = false,
            repairInCombat = false,
            repairResourceTracking = false,
            repairResourceThreshold = 10,
            repairChatMessages = false,

            autoRecharge = false,
            rechargeThreshold = 10,
            useCrownSoulGemsFirst = false,
            rechargeInCombat = false,
            rechargeResourceTracking = false,
            rechargeResourceThreshold = 10,
            rechargeChatMessages = false,
            researchChatMessages = false,

            research = {
                blacksmithing = {
                    lines = {},
                    priority = "sequence",
                },
                clothing = {
                    lines = {},
                    priority = "sequence",
                },
                woodworking = {
                    lines = {},
                    priority = "sequence",
                },
                jewelry = {
                    lines = {},
                    priority = "sequence",
                },
            },
        },

        deconstructProfiles = {
            weapon = CreateDeconstructProfile(),
            clothing = CreateDeconstructProfile(),
            jewelry = CreateDeconstructProfile(),
            enchanting = CreateDeconstructProfile(),
        },

        merchantProfiles = {
            weapon = CreateMerchantEquipmentProfile(),
            clothing = CreateMerchantEquipmentProfile(),
            jewelry = CreateMerchantEquipmentProfile(),
            enchanting = CreateMerchantEnchantingProfile(),
            consumables = CreateMerchantConsumablesProfile(),
            resources = CreateMerchantResourcesProfile(),
            materials = CreateMerchantMaterialsProfile(),
            other = CreateMerchantOtherProfile(),
            junk = { sellEnabled = false, rememberEnabled = false, items = {}, ignored = {} },
            autoPurchase = CreateMerchantAutoPurchaseProfile(),
        },
    }
end

local function ResetTableToDefaults(target, defaults)
    for key in pairs(target) do
        if defaults[key] == nil then
            target[key] = nil
        end
    end

    for key, defaultValue in pairs(defaults) do
        if type(defaultValue) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            ResetTableToDefaults(target[key], defaultValue)
        else
            target[key] = defaultValue
        end
    end
end

function ua.ResetAllSettings()
    ua.Profiles.ResetActiveSettings()
end

function ua.ResetBankingSettings()
    local defaults = ua.GetAccountDefaults()
    ua.savedVariables.banking = ua.savedVariables.banking or {}

    ResetTableToDefaults(ua.savedVariables.banking, defaults.banking)
end

function ua.ResetDeconstructSettings()
    local defaults = ua.GetAccountDefaults()
    ua.savedVariables.deconstructProfiles = ua.savedVariables.deconstructProfiles or {}

    ResetTableToDefaults(ua.savedVariables.deconstructProfiles, defaults.deconstructProfiles)

    ua.savedVariables.deconstructChatMessages = defaults.deconstructChatMessages
end

function ua.ResetMerchantSettings()
    local defaults = ua.GetAccountDefaults()
    ua.savedVariables.merchantProfiles = ua.savedVariables.merchantProfiles or {}

    ResetTableToDefaults(ua.savedVariables.merchantProfiles, defaults.merchantProfiles)

    ua.savedVariables.merchantChatMessages = defaults.merchantChatMessages
    ua.savedVariables.merchantPurchaseChatMessages = defaults.merchantPurchaseChatMessages
    ua.savedVariables.merchantChatMode = defaults.merchantChatMode
end

function ua.ResetRepairSettings()
    local defaults = ua.GetAccountDefaults()
    ua.savedVariables.repairAndRecharge = ua.savedVariables.repairAndRecharge or {}

    ResetTableToDefaults(ua.savedVariables.repairAndRecharge, defaults.repairAndRecharge)
end

function ua.RegisterWelcome()
    local eventName = ua.addonName .. "Welcome"

    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)

        if not ua.profileStorage.showWelcome then
            return
        end

        local message = ua.GetString("WELCOME_MESSAGE")

        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(message)
        else
            d(message)
        end
    end)
end

function ua.LoadModules()
    local savedVariables = ua.savedVariables

    if savedVariables.undauntedPledgesEnabled then
        ua.UndauntedPledges.Initialize()
    end

    if savedVariables.bankingEnabled then
        ua.Banking.Initialize()
        ua.Banking.CreateSettings()
    end

    if savedVariables.repairEnabled then
        ua.Repair.Initialize()
        ua.Repair.CreateSettings()
    end

    if savedVariables.deconstructEnabled then
        ua.Deconstruct.Initialize()
        ua.Deconstruct.CreateSettings()
    end

    if savedVariables.merchantEnabled then
        ua.Merchant.Initialize()
        ua.Merchant.CreateSettings()
    end
end
