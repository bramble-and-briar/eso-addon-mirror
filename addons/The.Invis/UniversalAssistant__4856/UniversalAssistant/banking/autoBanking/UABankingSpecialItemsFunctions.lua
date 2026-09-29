local ua = UAssistant
local banking = ua.Banking
local autoBanking = ua.Banking.AutoBanking

autoBanking.SpecialItems = autoBanking.SpecialItems or {}
local specialItems = autoBanking.SpecialItems

local KNOWN_ICON = "/esoui/art/miscellaneous/check_icon_64.dds"
local UNKNOWN_ICON = "/esoui/art/inventory/gamepad/gp_inventory_icon_can_learn.dds"
local EQUIPMENT_ICON = "/esoui/art/inventory/inventory_tabicon_all_up.dds"
local SOUL_GEM_ICON = "/esoui/art/icons/soulgem_006_filled.dds"
local OTHER_ICON = "/esoui/art/inventory/inventory_tabicon_misc_up.dds"
local UNDAUNTED_PLUNDER_ITEM_ID = 114427
local DEFAULT_MODE = autoBanking.MODE_NONE
local MAX_AMOUNT = 99999

local FURNISHING_PLAN_TYPES = {
    [SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING] = true,
    [SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING] = true,
    [SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING] = true,
    [SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING] = true,
    [SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING] = true,
    [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING] = true,
    [SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING] = true,
}

local WRIT_ICONS = {
    [CRAFTING_TYPE_BLACKSMITHING] = "/esoui/art/icons/master_writ_blacksmithing.dds",
    [CRAFTING_TYPE_CLOTHIER] = "/esoui/art/icons/master_writ_clothier.dds",
    [CRAFTING_TYPE_WOODWORKING] = "/esoui/art/icons/master_writ_woodworking.dds",
    [CRAFTING_TYPE_JEWELRYCRAFTING] = "/esoui/art/icons/master_writ_jewelry.dds",
    [CRAFTING_TYPE_ALCHEMY] = "/esoui/art/icons/master_writ_alchemy.dds",
    [CRAFTING_TYPE_ENCHANTING] = "/esoui/art/icons/master_writ_enchanting.dds",
    [CRAFTING_TYPE_PROVISIONING] = "/esoui/art/icons/master_writ_provisioning.dds",
}

local WRIT_CRAFTING_TYPES = {
    CRAFTING_TYPE_BLACKSMITHING,
    CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING,
    CRAFTING_TYPE_ALCHEMY,
    CRAFTING_TYPE_ENCHANTING,
    CRAFTING_TYPE_PROVISIONING,
}

local UNKNOWN_WRIT_CRAFTING_TYPES = {
    [217917] = CRAFTING_TYPE_BLACKSMITHING,
    [217918] = CRAFTING_TYPE_CLOTHIER,
    [217919] = CRAFTING_TYPE_WOODWORKING,
    [217920] = CRAFTING_TYPE_ENCHANTING,
    [217921] = CRAFTING_TYPE_PROVISIONING,
    [217922] = CRAFTING_TYPE_ALCHEMY,
    [217923] = CRAFTING_TYPE_JEWELRYCRAFTING,
}

local UNKNOWN_WRIT_ITEM_IDS = {
    [CRAFTING_TYPE_BLACKSMITHING] = 217917,
    [CRAFTING_TYPE_CLOTHIER] = 217918,
    [CRAFTING_TYPE_WOODWORKING] = 217919,
    [CRAFTING_TYPE_ENCHANTING] = 217920,
    [CRAFTING_TYPE_PROVISIONING] = 217921,
    [CRAFTING_TYPE_ALCHEMY] = 217922,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = 217923,
}

local UNKNOWN_WRIT_ICON_ITEM_ID = 217917

local UNIDENTIFIED_SURVEYS = {
    219849,
    219850,
    219851,
    219852,
    219853,
    219854,
}

local GUILD_BANK_WITHDRAW_KEYS = {
    motifUnknown = true,
    recipeUnknown = true,
    furnishingPlanUnknown = true,
    stylePageUnknown = true,
}

local INTRICATE_DEFINITIONS = {
    {
        key = "weaponIntricateMode",
        oldKey = "weaponIntricate",
        nameKey = "WEAPON",
        icon = "/esoui/art/inventory/inventory_tabicon_weapons_up.dds",
        matches = function(itemLink)
            local itemType = GetItemLinkItemType(itemLink)
            local equipType = GetItemLinkEquipType(itemLink)

            return itemType == ITEMTYPE_WEAPON
                or (itemType == ITEMTYPE_ARMOR and equipType == EQUIP_TYPE_OFF_HAND)
        end,
    },
    {
        key = "clothingIntricateMode",
        oldKey = "clothingIntricate",
        nameKey = "CLOTHING",
        icon = "/esoui/art/inventory/inventory_tabicon_armor_up.dds",
        matches = function(itemLink)
            if GetItemLinkItemType(itemLink) ~= ITEMTYPE_ARMOR then
                return false
            end

            local armorType = GetItemLinkArmorType(itemLink)
            local equipType = GetItemLinkEquipType(itemLink)

            return equipType ~= EQUIP_TYPE_OFF_HAND
                and equipType ~= EQUIP_TYPE_RING
                and equipType ~= EQUIP_TYPE_NECK
                and (
                    armorType == ARMORTYPE_LIGHT
                    or armorType == ARMORTYPE_MEDIUM
                    or armorType == ARMORTYPE_HEAVY
                )
        end,
    },
    {
        key = "jewelryIntricateMode",
        oldKey = "jewelryIntricate",
        nameKey = "JEWELRY",
        icon = "/esoui/art/inventory/inventory_tabicon_craftbag_jewelrycrafting_up.dds",
        matches = function(itemLink)
            local equipType = GetItemLinkEquipType(itemLink)

            return equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK
        end,
    },
}

local function L(key)
    return ua.GetString("BANKING_" .. key)
end

local function GetItemTypeName(itemType, fallback)
    return banking.GetItemTypeName(itemType, fallback)
end

local function GetSpecializedItemTypeName(specializedItemType, fallback)
    return banking.GetSpecializedItemTypeName(specializedItemType, fallback)
end

local function CreateItemLink(itemId)
    return string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

local function GetItemDisplayName(itemId)
    local itemLink = CreateItemLink(itemId)
    local name = GetItemLinkName(itemLink)

    if not name or name == "" then
        name = tostring(itemId)
    else
        name = zo_strformat("<<C:1>>", name)

        local quality = GetItemLinkQuality(itemLink)
        local color = GetItemQualityColor(quality)

        if color and color.Colorize then
            name = color:Colorize(name)
        end
    end

    local icon = GetItemLinkIcon(itemLink)

    if icon and icon ~= "" then
        return zo_iconFormat(icon, 24, 24) .. " " .. name
    end

    return name
end

local function IsBookKnown(itemLink)
    return IsItemLinkBook(itemLink) and IsItemLinkBookKnown(itemLink) == true
end

local function IsRecipeKnown(itemLink)
    return IsItemLinkRecipeKnown(itemLink) == true
end

local function IsStylePageKnown(itemLink)
    local collectibleId = GetItemLinkContainerCollectibleId(itemLink)

    return collectibleId
        and collectibleId > 0
        and IsCollectibleValidForPlayer(collectibleId)
        and IsCollectibleUnlocked(collectibleId)
end

local function MatchesItemType(itemLink, expectedItemType)
    return GetItemLinkItemType(itemLink) == expectedItemType
end

local function MatchesSpecializedType(itemLink, expectedSpecializedType)
    local _, specializedItemType = GetItemLinkItemType(itemLink)

    return specializedItemType == expectedSpecializedType
end

local function CreateKnownEntry(key, nounKey, known, baseMatcher, knowledgeMatcher)
    return {
        key = key,
        nounKey = nounKey,
        known = known,
        matches = function(itemLink)
            return baseMatcher(itemLink) and knowledgeMatcher(itemLink) == known
        end,
    }
end

local function BuildSections()
    local motifMatcher = function(itemLink)
        return MatchesItemType(itemLink, ITEMTYPE_RACIAL_STYLE_MOTIF)
    end
    local recipeMatcher = function(itemLink)
        local _, specializedItemType = GetItemLinkItemType(itemLink)

        return specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK
            or specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD
    end
    local furnishingPlanMatcher = function(itemLink)
        local itemType, specializedItemType = GetItemLinkItemType(itemLink)

        if FURNISHING_PLAN_TYPES[specializedItemType] == true then
            return true
        end

        if itemType ~= ITEMTYPE_RECIPE then
            return false
        end

        local resultItemLink = GetItemLinkRecipeResultItemLink(itemLink, LINK_STYLE_DEFAULT)

        return resultItemLink
            and resultItemLink ~= ""
            and IsItemLinkPlaceableFurniture(resultItemLink)
    end
    local stylePageMatcher = function(itemLink)
        return MatchesSpecializedType(itemLink, SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE)
    end
    return {
        {
            key = "motifs",
            nameKey = "MOTIFS",
            icon = "/esoui/art/icons/quest_book_001.dds",
            entries = {
                CreateKnownEntry("motifKnown", "MOTIF", true, motifMatcher, IsBookKnown),
                CreateKnownEntry("motifUnknown", "MOTIF", false, motifMatcher, IsBookKnown),
            },
        },
        {
            key = "recipes",
            nameKey = "RECIPES_FURNISHING_PLAN",
            icon = "/esoui/art/icons/quest_scroll_001.dds",
            entries = {
                CreateKnownEntry("recipeKnown", "RECIPE", true, recipeMatcher, IsRecipeKnown),
                CreateKnownEntry("recipeUnknown", "RECIPE", false, recipeMatcher, IsRecipeKnown),
                CreateKnownEntry(
                    "furnishingPlanKnown",
                    "FURNISHING_PLAN",
                    true,
                    furnishingPlanMatcher,
                    IsRecipeKnown
                ),
                CreateKnownEntry(
                    "furnishingPlanUnknown",
                    "FURNISHING_PLAN",
                    false,
                    furnishingPlanMatcher,
                    IsRecipeKnown
                ),
            },
        },
        {
            key = "stylePages",
            nameKey = "STYLE_PAGE",
            icon = "/esoui/art/icons/quest_summerset_completed_report.dds",
            entries = {
                CreateKnownEntry(
                    "stylePageKnown",
                    "STYLE_PAGE_ITEM",
                    true,
                    stylePageMatcher,
                    IsStylePageKnown
                ),
                CreateKnownEntry(
                    "stylePageUnknown",
                    "STYLE_PAGE_ITEM",
                    false,
                    stylePageMatcher,
                    IsStylePageKnown
                ),
            },
        },
    }
end

local SECTIONS = BuildSections()

local function GetSpecialSettings()
    local savedVariables = ua.savedVariables
    savedVariables.banking = savedVariables.banking or {}
    savedVariables.banking.specialItems = savedVariables.banking.specialItems or {}

    local settings = savedVariables.banking.specialItems

    local function MergeLegacyModes(firstMode, secondMode)
        local firstValid = autoBanking.IsValidMode(firstMode)
        local secondValid = autoBanking.IsValidMode(secondMode)

        if firstValid and secondValid and firstMode == secondMode then
            return firstMode
        end

        if firstValid and (not secondValid or secondMode == DEFAULT_MODE) then
            return firstMode
        end

        if secondValid and (not firstValid or firstMode == DEFAULT_MODE) then
            return secondMode
        end

        return DEFAULT_MODE
    end

    if not autoBanking.IsValidMode(settings.recipeKnown) then
        settings.recipeKnown = MergeLegacyModes(settings.drinkRecipeKnown, settings.foodRecipeKnown)
    end

    if not autoBanking.IsValidMode(settings.recipeUnknown) then
        settings.recipeUnknown =
            MergeLegacyModes(settings.drinkRecipeUnknown, settings.foodRecipeUnknown)
    end

    settings.drinkRecipeKnown = nil
    settings.drinkRecipeUnknown = nil
    settings.foodRecipeKnown = nil
    settings.foodRecipeUnknown = nil

    settings.grimoireKnown = nil
    settings.grimoireUnknown = nil
    settings.focusScriptKnown = nil
    settings.focusScriptUnknown = nil
    settings.signatureScriptKnown = nil
    settings.signatureScriptUnknown = nil
    settings.affixScriptKnown = nil
    settings.affixScriptUnknown = nil

    for _, section in ipairs(SECTIONS) do
        for _, entry in ipairs(section.entries) do
            if not autoBanking.IsValidMode(settings[entry.key]) then
                settings[entry.key] = DEFAULT_MODE
            end
        end
    end

    for _, craftingType in ipairs(WRIT_CRAFTING_TYPES) do
        local key = "masterWrit:" .. tostring(craftingType)

        if not autoBanking.IsValidMode(settings[key]) then
            settings[key] = DEFAULT_MODE
        end
    end

    for _, itemId in ipairs(UNIDENTIFIED_SURVEYS) do
        local key = "unidentifiedSurvey:" .. tostring(itemId)

        if not autoBanking.IsValidMode(settings[key]) then
            settings[key] = DEFAULT_MODE
        end
    end

    if not autoBanking.IsValidMode(settings.undauntedPlunderMode) then
        settings.undauntedPlunderMode = DEFAULT_MODE
    end

    if type(settings.soulGems) ~= "table" then
        settings.soulGems = {}
    end

    local soulGems = settings.soulGems
    soulGems.minimum = zo_clamp(zo_floor(tonumber(soulGems.minimum) or 0), 0, MAX_AMOUNT)
    soulGems.maximum = zo_clamp(zo_floor(tonumber(soulGems.maximum) or 0), 0, MAX_AMOUNT)

    if soulGems.maximum < soulGems.minimum then
        soulGems.maximum = soulGems.minimum
    end

    return settings
end

local function GetEquipmentSettings()
    local savedVariables = ua.savedVariables
    savedVariables.banking.equipment = savedVariables.banking.equipment or {}

    local settings = savedVariables.banking.equipment

    for _, definition in ipairs(INTRICATE_DEFINITIONS) do
        local mode = settings[definition.key]

        if not autoBanking.IsValidMode(mode) then
            mode = settings[definition.oldKey] == true and autoBanking.MODE_DEPOSIT or DEFAULT_MODE
        end

        settings[definition.key] = mode
        settings[definition.oldKey] = nil
    end

    return settings
end

function specialItems.IsEnabled()
    return ua.savedVariables.banking and ua.savedVariables.banking.specialItemsEnabled == true
end

local function GetMenuReference(key)
    return "UABankingSpecialItems" .. key
end

local function RefreshMenus()
    local references = {
        GetMenuReference("motifs"),
        GetMenuReference("recipes"),
        GetMenuReference("stylePages"),
        GetMenuReference("potions"),
        GetMenuReference("foodsDrinks"),
        GetMenuReference("masterWrits"),
        GetMenuReference("unidentifiedSurveys"),
        GetMenuReference("intricate"),
        GetMenuReference("other"),
    }

    for _, reference in ipairs(references) do
        local control = _G[reference]

        if control and control.UpdateDisabled then
            control:UpdateDisabled()
        end
    end
end

local function RefreshValue(reference)
    local control = _G[reference]

    if control and control.UpdateValue then
        control:UpdateValue()
    end
end

local function SetMinimum(profile, value)
    profile.minimum = zo_clamp(zo_floor(tonumber(value) or profile.minimum or 0), 0, MAX_AMOUNT)

    if profile.maximum < profile.minimum then
        profile.maximum = profile.minimum
    end
end

local function SetMaximum(profile, value)
    profile.maximum = zo_clamp(zo_floor(tonumber(value) or profile.maximum or 0), 0, MAX_AMOUNT)

    if profile.minimum > profile.maximum then
        profile.minimum = profile.maximum
    end
end

function specialItems.CreateEnableControl()
    return {
        type = "checkbox",
        name = L("ENABLE_SPECIAL_ITEMS"),
        tooltip = L("ENABLE_SPECIAL_ITEMS_TOOLTIP"),
        getFunc = function()
            return specialItems.IsEnabled()
        end,
        setFunc = function(value)
            ua.savedVariables.banking.specialItemsEnabled = value
            RefreshMenus()
        end,
        default = false,
    }
end

local function RegisterModeRule(ruleId, settings, key, matcher, allowGuildBankWithdraw)
    autoBanking.RegisterRule(ruleId, function()
        if not specialItems.IsEnabled() then
            return autoBanking.MODE_NONE
        end

        local mode = settings[key]

        if autoBanking.IsValidMode(mode) then
            return mode
        end

        return DEFAULT_MODE
    end, matcher, nil, allowGuildBankWithdraw)
end

local function IsMasterWritFor(itemLink, craftingType)
    local unknownWritCraftingType = UNKNOWN_WRIT_CRAFTING_TYPES[GetItemLinkItemId(itemLink)]

    if unknownWritCraftingType then
        return unknownWritCraftingType == craftingType
    end

    local itemType, specializedItemType = GetItemLinkItemType(itemLink)

    if
        itemType ~= ITEMTYPE_MASTER_WRIT
        or specializedItemType ~= SPECIALIZED_ITEMTYPE_MASTER_WRIT
    then
        return false
    end

    local icon = GetItemLinkInfo(itemLink)

    return icon == WRIT_ICONS[craftingType]
end

local function IsIntricate(itemLink)
    local traitType = GetItemLinkTraitType(itemLink)
    local traitInformation = GetItemTraitInformationFromItemLink(itemLink)

    return traitInformation == ITEM_TRAIT_INFORMATION_INTRICATE
        or traitType == ITEM_TRAIT_TYPE_WEAPON_INTRICATE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_INTRICATE
        or traitType == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
end

local function IsStandardFilledSoulGem(itemLink, bagId, slotIndex)
    if
        bagId == nil
        or slotIndex == nil
        or not IsItemSoulGem(SOUL_GEM_TYPE_FILLED, bagId, slotIndex)
    then
        return false
    end

    local tier = select(1, GetSoulGemItemInfo(bagId, slotIndex)) or 0
    local isCrown = IsItemFromCrownStore and IsItemFromCrownStore(bagId, slotIndex)

    return not isCrown and tier > 0
end

local function CountStandardFilledSoulGems(bagId)
    local amount = 0

    for slotIndex = 0, GetBagSize(bagId) - 1 do
        local itemLink = GetItemLink(bagId, slotIndex)

        if IsStandardFilledSoulGem(itemLink, bagId, slotIndex) then
            amount = amount + (GetSlotStackSize(bagId, slotIndex) or 0)
        end
    end

    return amount
end

function specialItems.Initialize()
    local settings = GetSpecialSettings()
    local equipmentSettings = GetEquipmentSettings()

    for _, section in ipairs(SECTIONS) do
        for _, entry in ipairs(section.entries) do
            local currentEntry = entry

            RegisterModeRule(
                "special:" .. currentEntry.key,
                settings,
                currentEntry.key,
                currentEntry.matches,
                GUILD_BANK_WITHDRAW_KEYS[currentEntry.key] == true
            )
        end
    end

    for _, craftingType in ipairs(WRIT_CRAFTING_TYPES) do
        local currentCraftingType = craftingType
        local key = "masterWrit:" .. tostring(currentCraftingType)

        RegisterModeRule("special:" .. key, settings, key, function(itemLink)
            return IsMasterWritFor(itemLink, currentCraftingType)
        end)
    end

    for _, itemId in ipairs(UNIDENTIFIED_SURVEYS) do
        local currentItemId = itemId
        local key = "unidentifiedSurvey:" .. tostring(currentItemId)

        RegisterModeRule("special:" .. key, settings, key, function(itemLink)
            return GetItemLinkItemId(itemLink) == currentItemId
        end)
    end

    RegisterModeRule(
        "special:undauntedPlunder",
        settings,
        "undauntedPlunderMode",
        function(itemLink)
            return GetItemLinkItemId(itemLink) == UNDAUNTED_PLUNDER_ITEM_ID
        end
    )

    local soulGems = settings.soulGems

    autoBanking.RegisterRule(
        "special:soulGems",
        function()
            if
                not specialItems.IsEnabled()
                or (soulGems.minimum == 0 and soulGems.maximum == 0)
            then
                return autoBanking.MODE_NONE
            end

            local currentAmount = CountStandardFilledSoulGems(BAG_BACKPACK)

            if currentAmount < soulGems.minimum then
                return autoBanking.MODE_WITHDRAW
            end

            if currentAmount > soulGems.maximum then
                return autoBanking.MODE_DEPOSIT
            end

            return autoBanking.MODE_NONE
        end,
        IsStandardFilledSoulGem,
        function(mode, proposedAmount)
            local currentAmount = CountStandardFilledSoulGems(BAG_BACKPACK)
            local requestedAmount = mode == autoBanking.MODE_DEPOSIT
                    and currentAmount - soulGems.maximum
                or soulGems.minimum - currentAmount

            return math.min(proposedAmount, math.max(0, requestedAmount))
        end
    )

    for _, definition in ipairs(INTRICATE_DEFINITIONS) do
        local currentDefinition = definition

        RegisterModeRule(
            "special:intricate:" .. currentDefinition.key,
            equipmentSettings,
            currentDefinition.key,
            function(itemLink)
                return IsIntricate(itemLink) and currentDefinition.matches(itemLink)
            end
        )
    end
end

local NOUN_GAME_NAMES = {
    MOTIF = function()
        return GetItemTypeName(ITEMTYPE_RACIAL_STYLE_MOTIF, L("MOTIF"))
    end,
    RECIPE = function()
        return GetItemTypeName(ITEMTYPE_RECIPE, L("RECIPE"))
    end,
    STYLE_PAGE_ITEM = function()
        return GetSpecializedItemTypeName(
            SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE,
            L("STYLE_PAGE_ITEM")
        )
    end,
}

local function GetNounName(entry)
    local getter = NOUN_GAME_NAMES[entry.nounKey]

    if getter then
        return getter()
    end

    return L(entry.nounKey)
end

local function GetKnownLabel(entry)
    local icon = entry.known and KNOWN_ICON or UNKNOWN_ICON
    local template = entry.known and L("KNOWN_ITEM") or L("UNKNOWN_ITEM")

    return zo_iconFormat(icon, 24, 24) .. " " .. string.format(template, GetNounName(entry))
end

local function CreateDropdown(name, tooltip, settings, key)
    return {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = banking.GetBankModeChoices(),
        choicesValues = {
            autoBanking.MODE_NONE,
            autoBanking.MODE_DEPOSIT,
            autoBanking.MODE_WITHDRAW,
        },
        getFunc = function()
            local mode = settings[key]

            if autoBanking.IsValidMode(mode) then
                return mode
            end

            return DEFAULT_MODE
        end,
        setFunc = function(value)
            settings[key] = value
        end,
        default = DEFAULT_MODE,
    }
end

local function GetLearnableSectionName(section)
    if section.key == "motifs" then
        return GetItemTypeName(ITEMTYPE_RACIAL_STYLE_MOTIF, L(section.nameKey))
    end

    if section.key == "stylePages" then
        return GetSpecializedItemTypeName(
            SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE,
            L(section.nameKey)
        )
    end

    return L(section.nameKey)
end

local function CreateLearnableMenu(section, settings)
    local controls = {}

    for _, entry in ipairs(section.entries) do
        local label = GetKnownLabel(entry)

        table.insert(
            controls,
            CreateDropdown(
                label,
                string.format(L("SPECIAL_ITEM_MODE_TOOLTIP"), label),
                settings,
                entry.key
            )
        )
    end

    return {
        type = "submenu",
        name = zo_iconFormat(section.icon, 32, 32) .. " " .. GetLearnableSectionName(section),
        disabled = function()
            return not specialItems.IsEnabled()
        end,
        reference = GetMenuReference(section.key),
        controls = controls,
    }
end

local function CreateMasterWritMenu(settings)
    local controls = {}

    for _, craftingType in ipairs(WRIT_CRAFTING_TYPES) do
        local key = "masterWrit:" .. tostring(craftingType)
        local itemId = UNKNOWN_WRIT_ITEM_IDS[craftingType]
        local name = GetItemDisplayName(itemId)

        table.insert(
            controls,
            CreateDropdown(name, string.format(L("MASTER_WRIT_MODE_TOOLTIP"), name), settings, key)
        )
    end

    local icon = GetItemLinkIcon(CreateItemLink(UNKNOWN_WRIT_ICON_ITEM_ID))

    if not icon or icon == "" then
        icon = WRIT_ICONS[CRAFTING_TYPE_BLACKSMITHING]
    end

    return {
        type = "submenu",
        name = zo_iconFormat(icon, 32, 32)
            .. " "
            .. GetItemTypeName(ITEMTYPE_MASTER_WRIT, L("MASTER_WRITS")),
        disabled = function()
            return not specialItems.IsEnabled()
        end,
        reference = GetMenuReference("masterWrits"),
        controls = controls,
    }
end

local function CreateUnidentifiedSurveyMenu(settings)
    local controls = {}

    for _, itemId in ipairs(UNIDENTIFIED_SURVEYS) do
        local currentItemId = itemId
        local key = "unidentifiedSurvey:" .. tostring(currentItemId)
        local itemName = GetItemDisplayName(currentItemId)

        table.insert(
            controls,
            CreateDropdown(
                itemName,
                string.format(L("UNIDENTIFIED_SURVEY_MODE_TOOLTIP"), itemName),
                settings,
                key
            )
        )
    end

    local icon = GetItemLinkIcon(CreateItemLink(UNIDENTIFIED_SURVEYS[1]))

    if not icon or icon == "" then
        icon = "/esoui/art/icons/quest_scroll_001.dds"
    end

    return {
        type = "submenu",
        name = zo_iconFormat(icon, 32, 32) .. " " .. L("UNIDENTIFIED_SURVEYS"),
        disabled = function()
            return not specialItems.IsEnabled()
        end,
        reference = GetMenuReference("unidentifiedSurveys"),
        controls = controls,
    }
end

local function GetIntricateName()
    local name = GetString("SI_ITEMTRAITTYPE", ITEM_TRAIT_TYPE_WEAPON_INTRICATE)

    if not name or name == "" then
        return L("INTRICATE")
    end

    return zo_strformat("<<C:1>>", name)
end

local function GetEquipmentCategoryName(definition)
    if definition.key == "weaponIntricateMode" then
        return GetItemTypeName(ITEMTYPE_WEAPON, L(definition.nameKey))
    end

    if definition.key == "clothingIntricateMode" then
        return L(definition.nameKey)
    end

    return banking.GetGameString(SI_ITEMFILTERTYPE24, L(definition.nameKey))
end

local function CreateIntricateMenu(settings)
    local controls = {}

    for _, definition in ipairs(INTRICATE_DEFINITIONS) do
        local categoryName = GetEquipmentCategoryName(definition)

        table.insert(
            controls,
            CreateDropdown(
                zo_iconFormat(definition.icon, 24, 24) .. " " .. categoryName,
                string.format(L("INTRICATE_MODE_TOOLTIP"), categoryName, GetIntricateName()),
                settings,
                definition.key
            )
        )
    end

    return {
        type = "submenu",
        name = zo_iconFormat(EQUIPMENT_ICON, 32, 32)
            .. " "
            .. string.format(L("EQUIPMENT_INTRICATE"), GetIntricateName()),
        tooltip = string.format(L("EQUIPMENT_INTRICATE_TOOLTIP"), GetIntricateName()),
        disabled = function()
            return not specialItems.IsEnabled()
        end,
        reference = GetMenuReference("intricate"),
        controls = controls,
    }
end

local function CreateOtherMenu(settings)
    local profile = settings.soulGems
    local undauntedPlunderName = GetItemDisplayName(UNDAUNTED_PLUNDER_ITEM_ID)
    local soulGemName = GetItemTypeName(ITEMTYPE_SOUL_GEM, L("SOUL_GEMS"))
    local itemName = zo_iconFormat(SOUL_GEM_ICON, 28, 28) .. " " .. soulGemName
    local minimumReference = "UABankingSpecialItemsSoulGemsMinimum"
    local maximumReference = "UABankingSpecialItemsSoulGemsMaximum"

    return {
        type = "submenu",
        name = zo_iconFormat(OTHER_ICON, 32, 32)
            .. " "
            .. banking.GetGameString(SI_ITEMTYPEDISPLAYCATEGORY7, L("OTHER")),
        disabled = function()
            return not specialItems.IsEnabled()
        end,
        reference = GetMenuReference("other"),
        controls = {
            CreateDropdown(
                undauntedPlunderName,
                string.format(L("SPECIAL_ITEM_MODE_TOOLTIP"), undauntedPlunderName),
                settings,
                "undauntedPlunderMode"
            ),
            {
                type = "description",
                text = itemName,
            },
            {
                type = "editbox",
                name = L("MINIMUM_TO_KEEP"),
                tooltip = string.format(L("MINIMUM_TO_KEEP_TOOLTIP"), soulGemName),
                width = "half",
                maxChars = 5,
                textType = TEXT_TYPE_NUMERIC,
                getFunc = function()
                    return tostring(profile.minimum)
                end,
                setFunc = function(value)
                    SetMinimum(profile, value)
                    RefreshValue(maximumReference)
                end,
                default = "0",
                reference = minimumReference,
            },
            {
                type = "editbox",
                name = L("MAXIMUM_TO_KEEP"),
                tooltip = string.format(L("MAXIMUM_TO_KEEP_TOOLTIP"), soulGemName),
                width = "half",
                maxChars = 5,
                textType = TEXT_TYPE_NUMERIC,
                getFunc = function()
                    return tostring(profile.maximum)
                end,
                setFunc = function(value)
                    SetMaximum(profile, value)
                    RefreshValue(minimumReference)
                end,
                default = "0",
                reference = maximumReference,
            },
        },
    }
end

function specialItems.CreateMenuControls()
    local settings = GetSpecialSettings()
    local controls = {}

    table.insert(controls, CreateLearnableMenu(SECTIONS[1], settings))
    table.insert(controls, CreateLearnableMenu(SECTIONS[2], settings))
    table.insert(controls, CreateLearnableMenu(SECTIONS[3], settings))
    table.insert(controls, autoBanking.Potions.CreateMenuControl())
    table.insert(controls, autoBanking.FoodDrinks.CreateMenuControl())
    table.insert(controls, CreateMasterWritMenu(settings))
    table.insert(controls, CreateUnidentifiedSurveyMenu(settings))
    table.insert(controls, CreateIntricateMenu(GetEquipmentSettings()))
    table.insert(controls, CreateOtherMenu(settings))

    return controls
end
