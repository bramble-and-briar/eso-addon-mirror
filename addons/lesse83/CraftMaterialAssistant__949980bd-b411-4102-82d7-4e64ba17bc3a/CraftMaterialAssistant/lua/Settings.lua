local CMA = CraftMaterialAssistant

-- Build the Settings Panel interface via LibAddonMenu-2.0
function CMA:CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        self:SendChatMessage("Missing dependency LibAddonMenu-2.0")
        return
    end
    -- deserialize the stored custom item rules string
    self.customItemRuleTable = self:deserializeCustomItemRuleTable(self.db.serializedCustomItemRules)
    self:updateItemRulesDropdown(nil)

    local customRuleName = ""
    local customRuleItemId = ""
    local customRuleAction = "Ignore"

    local panelData = {
        type = "panel",
        name = "Craft Material Assistant",
        displayName = "|cFFD700Craft Material Assistant|r",
        author = "Lesse83",
        version = self.version,
        registerForRefresh = true
    }
    LAM:RegisterAddonPanel("Craft Material Assistant", panelData)

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable Craft Material Assistant",
            tooltip = "Enable or disable all functionality of this addon.",
            getFunc = function() return self.db.enableAddon end,
            setFunc = function(v) self.db.enableAddon = v end
        },
        {
            type = "checkbox",
            name = "Use character specific settings",
            tooltip = "Turn on for character specific settings. If turned off, it will use the account wide settings.\n\nChanging the state will immediately trigger an UI reload.",
            getFunc = function() return self.dbCharSpecific.useCharacterSettings end,
            setFunc = function(v)
                self.dbCharSpecific.useCharacterSettings = v
                ReloadUI() 
            end
        },
        {
            type = "submenu",
            name = "General Options",
            controls = {
                {
                    type = "checkbox",
                    name = "Vendor not banked materials",
                    tooltip = "Mark all craft materials that are not banked as trash to be vendored.",
                    getFunc = function() return self.db.markAsTrashIfNotBanked end,
                    setFunc = function(v) self.db.markAsTrashIfNotBanked = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "checkbox",
                    name = "Auto sell items marked as junk",
                    tooltip = "Automatically sell all items marked as junk when opening a vendor.",
                    getFunc = function() return self.db.autoSellJunk end,
                    setFunc = function(v) self.db.autoSellJunk = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "checkbox",
                    name = "Show banking message",
                    tooltip = "Toggles chat message when materials are moved to the bank vault.",
                    getFunc = function() return self.db.showBankAlerts end,
                    setFunc = function(v) self.db.showBankAlerts = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "checkbox",
                    name = "Show junked message",
                    tooltip = "Toggles chat message when materials that are not banked are marked as junk.",
                    getFunc = function() return self.db.showJunkAlerts end,
                    setFunc = function(v) self.db.showJunkAlerts = v end,
                    disabled = function() return not self.db.enableAddon end,
                },
                {
                    type = "checkbox",
                    name = "Show Vendor Sales Message",
                    tooltip = "Toggles chat message showing items sold and gold earned. Needs to have 'Auto sell' enabled.",
                    getFunc = function() return self.db.showVendorAlerts end,
                    setFunc = function(v) self.db.showVendorAlerts = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.autoSellJunk) end
                },
                                {
                    type = "editbox",
                    name = "Delay before start (Milliseconds)",
                    tooltip = "To not conflict with other addons doing banking processes the start of the operations can be delayed by the given amount of milliseconds (seconds * 1000).",
                    textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT,
                    maxChars = 5,
                    getFunc = function() return self.db.initialDelayInMs end,
                    setFunc = function(v) self.db.initialDelayInMs = v end,
                    disabled = function() return (not self.db.enableAddon) end
                }
            }
        },
        {
            type = "submenu",
            name = "Blacksmithing",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Blacksmithing materials.",
                    getFunc = function() return self.db.bankBlacksmithing end,
                    setFunc = function(v) self.db.bankBlacksmithing = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "Temper quality threshold",
                    tooltip = "Minimum quality of Blacksmithing Tempers to be banked.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdBlacksmithing end,
                    setFunc = function(v) self.db.bankQualityThresholdBlacksmithing = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankBlacksmithing) end
                },
                {
                    type = "slider",
                    name = "Material tier level",
                    tooltip = "Blacksmithing Ores and Ingots meeting this tier requirement will be banked.\n" .. self.blacksmithingTierInfo,
                    min = 1, max = 11, step = 1,
                    getFunc = function() return self.db.bankTierThresholdBlacksmithing end,
                    setFunc = function(v) self.db.bankTierThresholdBlacksmithing = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankBlacksmithing) end
                }
            }
        },
        {
            type = "submenu",
            name = "Clothing",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Clothing materials.",
                    getFunc = function() return self.db.bankClothing end,
                    setFunc = function(v) self.db.bankClothing = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "Tannin quality threshold",
                    tooltip = "Minimum quality of Clothing Tannins to be banked.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdClothing end,
                    setFunc = function(v) self.db.bankQualityThresholdClothing = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankClothing) end
                },
                {
                    type = "slider",
                    name = "Material tier level",
                    tooltip = "Clothing Materials and Raw Materials meeting this tier requirement will be banked.\n" .. self.clothingTierInfo,
                    min = 1, max = 11, step = 1,
                    getFunc = function() return self.db.bankTierThresholdClothing end,
                    setFunc = function(v) self.db.bankTierThresholdClothing = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankClothing) end
                }
            }
        },
        {
            type = "submenu",
            name = "Woodworking",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Woodworking materials.",
                    getFunc = function() return self.db.bankWoodworking end,
                    setFunc = function(v) self.db.bankWoodworking = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "Resin quality threshold",
                    tooltip = "Minimum quality of Woodworking Resins to be banked.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdWoodworking end,
                    setFunc = function(v) self.db.bankQualityThresholdWoodworking = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankWoodworking) end
                },
                {
                    type = "slider",
                    name = "Material tier level",
                    tooltip = "Rough and Sanded Woodworking materials meeting this tier requirement will be banked.\n" .. self.woodworkingTierInfo,
                    min = 1, max = 11, step = 1,
                    getFunc = function() return self.db.bankTierThresholdWoodworking end,
                    setFunc = function(v) self.db.bankTierThresholdWoodworking = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankWoodworking) end
                }
            }
        },
        {
            type = "submenu",
            name = "Jewelry",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Jewelry materials.",
                    getFunc = function() return self.db.bankJewelry end,
                    setFunc = function(v) self.db.bankJewelry = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "checkbox",
                    name = "Bank Raw Jewelry Traits",
                    tooltip = "Enable banking of Pulverized items (Raw Jewelry Traits)",
                    getFunc = function() return self.db.bankRawJewelryTraits end,
                    setFunc = function(v) self.db.bankRawJewelryTraits = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankJewelry) end
                },
                {
                    type = "dropdown",
                    name = "Plating quality threshold",
                    tooltip = "Minimum quality of Jewelry Platings to be banked.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdJewelry end,
                    setFunc = function(v) self.db.bankQualityThresholdJewelry = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankJewelry) end
                },
                {
                    type = "slider",
                    name = "Material tier level",
                    tooltip = "Jewelry Ounces and Dust meeting this tier requirement will be banked.\n" .. self.jewelryTierInfo,
                    min = 1, max = 6, step = 1,
                    getFunc = function() return self.db.bankTierThresholdJewelry end,
                    setFunc = function(v) self.db.bankTierThresholdJewelry = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankJewelry) end
                }
            }
        },
        {
            type = "submenu",
            name = "Enchanting",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Enchanting materials.",
                    getFunc = function() return self.db.bankEnchanting end,
                    setFunc = function(v) self.db.bankEnchanting = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "Aspect Rune quality threshold",
                    tooltip = "Minimum quality of Aspect Runes to be banked.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdEnchanting end,
                    setFunc = function(v) self.db.bankQualityThresholdEnchanting = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankEnchanting) end
                },
                {
                    type = "slider",
                    name = "Minimum Potency Improvement level",
                    tooltip = "Potency Runes meeting this Improvement level will be banked.\n" .. self.enchantingTierInfo,
                    min = 1, max = 11, step = 1,
                    getFunc = function() return self.db.bankImprovementThresholdPotencyRunes end,
                    setFunc = function(v) self.db.bankImprovementThresholdPotencyRunes = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankEnchanting) end
                },
                {
                    type = "checkbox",
                    name = "Enable banking of Essence Runes",
                    tooltip = "Enable banking of Essence Runes.",
                    getFunc = function() return self.db.bankEssenceRunes end,
                    setFunc = function(v) self.db.bankEssenceRunes = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankEnchanting) end
                }
            }
        },
        {
            type = "submenu",
            name = "Alchemy",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Alchemy materials.",
                    getFunc = function() return self.db.bankAlchemy end,
                    setFunc = function(v) self.db.bankAlchemy = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "slider",
                    name = "Minimum Solvent Proficiency",
                    tooltip = "Solvents meeting this Proficiency level will be banked.\n" .. self.alchemyTierInfo,
                    min = 1, max = 9, step = 1,
                    getFunc = function() return self.db.bankProficiencyThresholdAlchemyBases end,
                    setFunc = function(v) self.db.bankProficiencyThresholdAlchemyBases = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankAlchemy) end
                },
                {
                    type = "checkbox",
                    name = "Enable banking of Reagents",
                    tooltip = "Enable banking of Alchemy Reagents.",
                    getFunc = function() return self.db.bankAlchemyReagents end,
                    setFunc = function(v) self.db.bankAlchemyReagents = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankAlchemy) end
                }
            }
        },
        {
            type = "submenu",
            name = "Provisioning",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Provisioning materials.",
                    getFunc = function() return self.db.bankProvisioning end,
                    setFunc = function(v) self.db.bankProvisioning = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "checkbox",
                    name = "Bank Writ Ingredients",
                    tooltip = "Keep Ingredients needed by top-level Daily Writs.",
                    getFunc = function() return self.db.bankProvisioningKeepWritIngredients end,
                    setFunc = function(v) self.db.bankProvisioningKeepWritIngredients = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankProvisioning) end
                },
                {
                    type = "checkbox",
                    name = "Bank other Ingredients",
                    tooltip = "Keep other Ingredients (those not needed by top-level Daily Writs).",
                    getFunc = function() return self.db.bankProvisioningKeepOtherIngredients end,
                    setFunc = function(v) self.db.bankProvisioningKeepOtherIngredients = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankProvisioning) end
                },
                {
                    type = "dropdown",
                    name = "Rare quality threshold",
                    tooltip = "Minimum quality of Rare Provisioning Ingredients to be banked.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdProvisioning end,
                    setFunc = function(v) self.db.bankQualityThresholdProvisioning = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankProvisioning) end
                },

                {
                    type = "checkbox",
                    name = "Sell known Provisioning Recipes",
                    tooltip = "Sell known Provisioning Recipes which do not meet the defined quality threshold.",
                    getFunc = function() return self.db.bankProvisioningSellKnownRecipe end,
                    setFunc = function(v) self.db.bankProvisioningSellKnownRecipe = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankProvisioning) end
                },
                {
                    type = "dropdown",
                    name = "Recipe sell quality threshold",
                    tooltip = "Only sell Provisioning Recipes if they are below the set threshold quality.",
                    choices = self.qualityDropdownChoices,
                    getFunc = function() return self.db.bankQualityThresholdProvisioningRecipe end,
                    setFunc = function(v) self.db.bankQualityThresholdProvisioningRecipe = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankProvisioning) or (not self.db.bankProvisioningSellKnownRecipe) end
                }

            }
        },
        {
            type = "submenu",
            name = "Scribing",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "Enable banking of Blacksmithing materials.",
                    getFunc = function() return self.db.bankScribingMaterials end,
                    setFunc = function(v) self.db.bankScribingMaterials = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "Banking of Ink",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankInk end,
                    setFunc = function(v) self.db.bankInk = v end,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.bankScribingMaterials) end
                },
                {
                    type = "checkbox",
                    name = "Bank unknown Scripts",
                    tooltip = "REQUIRES LibCharacterKnowledge!\n\nBanks Scripts as long as they are learnable and there are not enough copies for all characters.\n\nOtherwise markes the script as trash to be auto vendored.\n\nAlso writes a chat message who is able to learn it.",
                    getFunc = function() return self.db.bankUnknownScripts end,
                    setFunc = function(v) self.db.bankUnknownScripts = v end,
                    disabled = function() return not (self.db.enableAddon) or not(self.db.bankScribingMaterials) end
                },
                 {
                    type = "dropdown",
                    name = "Banking of Unbound Scripts",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankUnboundScripts end,
                    setFunc = function(v) self.db.bankUnboundScripts = v end,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.bankScribingMaterials) end
                },
            }
        },
        {
            type = "submenu",
            name = "Style Materials",
            controls = {
                {
                    type = "dropdown",
                    name = "Banking of Style Materials",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankStyleMaterials end,
                    setFunc = function(v) self.db.bankStyleMaterials = v end,
                    disabled = function() return (not self.db.enableAddon) end
                },
                {
                    type = "checkbox",
                    name = "Limit banked amount",
                    tooltip = "Limit the banked amount of each Style Material by the number entered in the text control below.",
                    getFunc = function() return self.db.limitStyleMaterialByCount end,
                    setFunc = function(v) self.db.limitStyleMaterialByCount = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankStyleMaterials) end
                },
                {
                    type = "editbox",
                    name = "Bank until number owned",
                    tooltip = "A specific Style Material will be banked until owning that total amount of it (across the bank, craft bag and house banks).",
                    textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT,
                    maxChars = 5,
                    getFunc = function() return self.db.bankMinimumNumberStyleMaterial end,
                    setFunc = function(v) self.db.bankMinimumNumberStyleMaterial = v end,
                    disabled = function() return (not self.db.enableAddon) or (not self.db.bankStyleMaterials) or (not self.db.limitStyleMaterialByCount) end
                }
            }
        },
        {
            type = "submenu",
            name = "Trait Materials",
            controls = {
                {
                    type = "dropdown",
                    name = "Banking of Trait Materials",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankTraitMaterials end,
                    setFunc = function(v) self.db.bankTraitMaterials = v end,
                    disabled = function() return (not self.db.enableAddon) end
                },
                {
                    type = "checkbox",
                    name = "Limit banked amount",
                    tooltip = "Limit the banked amount of each Trait Material by the number entered in the text control below.",
                    getFunc = function() return self.db.limitTraitMaterialByCount end,
                    setFunc = function(v) self.db.limitTraitMaterialByCount = v end,
                    disabled = function() return (not self.db.enableAddon) or (self.db.bankTraitMaterials ~= "Bank") end
                },
                {
                    type = "editbox",
                    name = "Bank until number owned",
                    tooltip = "A specific Trait Material will be banked until owning that total amount of it (across the bank, craft bag and house banks).",
                    textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT,
                    maxChars = 5,
                    getFunc = function() return self.db.bankMinimumNumberTraitMaterial end,
                    setFunc = function(v) self.db.bankMinimumNumberTraitMaterial = v end,
                    disabled = function() return (not self.db.enableAddon) or (self.db.bankTraitMaterials ~= "Bank") or (not self.db.limitTraitMaterialByCount) end
                }
            }
        },
        {
            type = "submenu",
            name = "Other Material Types",
            controls = {
                {
                    type = "dropdown",
                    name = "Banking of Furnishing Materials",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankFurnishingMaterials end,
                    setFunc = function(v) self.db.bankFurnishingMaterials = v end,
                    disabled = function() return (not self.db.enableAddon) end
                },
                {
                    type = "dropdown",
                    name = "Banking of Bait Items",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankBait end,
                    setFunc = function(v) self.db.bankBait = v end,
                    disabled = function() return (not self.db.enableAddon) end
                },
                {
                    type = "dropdown",
                    name = "Banking of Raw Materials",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.bankRawMaterials end,
                    setFunc = function(v) self.db.bankRawMaterials = v end,
                    disabled = function() return (not self.db.enableAddon) end
                }
            }
        },
        {
            type = "submenu",
            name = "Trait Research Gear",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable banking",
                    tooltip = "REQUIRES LibCharacterKnowledge!\n\nEnable banking of UNLOCKED gear having unknown, researchable Traits.\n\nAlso writes a chat message who is able to learn it.",
                    getFunc = function() return self.db.bankResearchableItems end,
                    setFunc = function(v) self.db.bankResearchableItems = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "Handling of researched gear trait",
                    tooltip = "Applied if all characters have researched this trait.\n\nBank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return self.db.actionKnownTraitItems end,
                    setFunc = function(v) self.db.actionKnownTraitItems = v end,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.bankResearchableItems) end
                }
            }
        },
        {
            type = "submenu",
            name = "Custom Rules",
            controls = {
                {
                    type = "description",
                    title = "How it works",
                    text = "The dropdown shows all rules which are active (having highest priority).\nEach rule targets an item by its ItemId and sets if you want to 'Bank', 'Sell' or 'Ignore' the item.\n\n|cff0000IMPORTANT: Due to restrictions updates are only visible after an UI Reload|r."
                },
                {
                    type = "checkbox",
                    name = "Enable custom rules",
                    tooltip = "Master toggle to turn on / off all custom rules.",
                    getFunc = function() return self.db.activateCustomRules end,
                    setFunc = function(v) self.db.activateCustomRules = v end,
                    disabled = function() return not self.db.enableAddon end
                },
                {
                    type = "dropdown",
                    name = "All Active Rules",
                    tooltip = "Here you can see all the currently active rules.\n\nThey are highest priority and thus are carried out before all the other rules.\n\n|cff0000Newly added or removed Rules are only visible after an UI Reload|r",
                    choices = self.customItemRuleDropdownNames,
                    choicesValues = self.customItemRuleDropdownValues,
                    getFunc = function() return self.customItemRuleSelection end,
                    setFunc = function(v) self.customItemRuleSelection = v end,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) end,
                },
                {
                    type = "button",
                    name = "Remove Selected Item",
                    tooltip = "Upon triggering remove the currently active Rule in the 'All Active Rules' dropdown is deleted.\n\n|cff0000Afterwards it needs an UI Reload to be be reflected in the dropdown|r",
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) or self.customItemRuleSelection == nil end,
                    func = function() self:CustomItemRuleRemove(self.customItemRuleSelection) end
                },
                {
                    type = "header",
                    name = "Add New Item Rule",
                    tooltip = "If you want to add a rule, fill out the forms below and click 'Add Item Rule'."
                },
                {
                    type = "editbox",
                    name = "Shown Name",
                    tooltip = "The name of the rule shown in the dropdown.\n\nIts basically only used as a reminder which item it is. The operation itself targets the ItemId entered below.\n\nThe field is limited to 20 characters and must not contain '.', ':' or ';'.",
                    getFunc = function() return customRuleName end,
                    setFunc = function(v) customRuleName = v end,
                    maxChars = 20,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) end,
                    isMultiline = false
                },
                {
                    type = "editbox",
                    name = "Item ID",
                    tooltip = "The unique ESO Item ID.\n\nIf you do not know the Item ID, click the 'List Inventory (Chat)' button below, to print your current inventory in the chat - there you'll find the correct id (if the item is present in your bag).\n\nThe input must be a number.",
                    getFunc = function() return customRuleItemId end,
                    setFunc = function(v) customRuleItemId = v end,
                    maxChars = 6,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) end,
                    isMultiline = false
                },
                {
                    type = "dropdown",
                    name = "Assigned Action",
                    tooltip = "Bank: Move to the bank.\nSell: Mark as junk to be sold at the vendor.\nIgnore: Don't do anything.",
                    choices = self.simpleMaterialChoices,
                    getFunc = function() return customRuleAction end,
                    setFunc = function(v) customRuleAction = v end,
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) end
                },
                {
                    type = "button",
                    name = "Add Item Rule",
                    tooltip = "Adds a rule for the entered Name, Item ID and Action.\n\n|cff0000The rule will only be visible after an UI Reload. You can add more than one before reloading.|r",
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) or (customRuleAction == "" or customRuleItemId == "" or customRuleName == "") end,
                    func = function() customRuleName, customRuleItemId, customRuleAction = self:CustomItemRuleAdd(customRuleName, customRuleItemId, customRuleAction) end
                },
                {
                    type = "header",
                    name = "Other options"
                },
                {
                    type = "button",
                    name = "List Inventory (Chat)",
                    tooltip = "Lists all items currently present in the inventory bag. By doing so you can search for the proper Item Id of the item you want the rule to be for.",
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) end,
                    func = function() self:CustomItemRuleListItems(self.sourceBag) end
                },
                {
                    type = "button",
                    name = "Reload UI",
                    tooltip = "After adding and removing Item Rules the dropdown is not automatically updated. Therfor you need to reload your UI in order to see any changes.",
                    disabled = function() return (not self.db.enableAddon) or not(self.db.activateCustomRules) end,
                    func = function() self:CustomItemRuleReloadUI() end
                },
            }
        },
    }
    LAM:RegisterOptionControls("Craft Material Assistant", optionsData)
end