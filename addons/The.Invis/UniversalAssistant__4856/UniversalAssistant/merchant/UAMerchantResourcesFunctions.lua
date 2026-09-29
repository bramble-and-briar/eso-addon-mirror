local ua = UAssistant
local merchant = ua.Merchant

merchant.resourceIngredientDefinitions = {
    provisioning = {

        { itemId = 64222, quality = ITEM_QUALITY_LEGENDARY },
        { itemId = 120894, quality = ITEM_QUALITY_LEGENDARY },
        { itemId = 115026, quality = ITEM_QUALITY_LEGENDARY },
        { itemId = 120078, quality = ITEM_QUALITY_LEGENDARY },
        { itemId = 171326, quality = ITEM_QUALITY_LEGENDARY },
        { itemId = 171328, quality = ITEM_QUALITY_LEGENDARY },
        { itemId = 171433, quality = ITEM_QUALITY_LEGENDARY },

        { itemId = 26802, quality = ITEM_QUALITY_ARTIFACT },
        { itemId = 27059, quality = ITEM_QUALITY_ARTIFACT },
        { itemId = 225210, quality = ITEM_QUALITY_ARTIFACT },
        { itemId = 224836, quality = ITEM_QUALITY_ARTIFACT },
        { itemId = 224837, quality = ITEM_QUALITY_ARTIFACT },
        { itemId = 224838, quality = ITEM_QUALITY_ARTIFACT },

        { itemId = 33753 },
        { itemId = 28609 },
        { itemId = 34321 },
        { itemId = 33752 },
        { itemId = 33756 },
        { itemId = 33754 },
        { itemId = 34311 },
        { itemId = 33755 },
        { itemId = 28610 },
        { itemId = 34308 },
        { itemId = 34305 },
        { itemId = 28603 },
        { itemId = 34309 },
        { itemId = 34324 },
        { itemId = 34323 },
        { itemId = 28604 },
        { itemId = 33758 },
        { itemId = 34307 },
        { itemId = 27057 },
        { itemId = 27100 },
        { itemId = 26954 },
        { itemId = 27064 },
        { itemId = 27063 },
        { itemId = 27058 },

        { itemId = 34329 },
        { itemId = 29030 },
        { itemId = 28639 },
        { itemId = 34345 },
        { itemId = 34348 },
        { itemId = 33774 },
        { itemId = 34334 },
        { itemId = 33768 },
        { itemId = 33771 },
        { itemId = 34330 },
        { itemId = 33773 },
        { itemId = 28636 },
        { itemId = 34349 },
        { itemId = 33772 },
        { itemId = 34346 },
        { itemId = 34347 },
        { itemId = 34333 },
        { itemId = 34335 },
        { itemId = 27052 },
        { itemId = 27043 },
        { itemId = 27035 },
        { itemId = 27049 },
        { itemId = 27048 },
        { itemId = 28666 },
    },
    alchemy = {
        { itemId = 77583 },
        { itemId = 30157 },
        { itemId = 30148 },
        { itemId = 30160 },
        { itemId = 77585 },
        { itemId = 150669 },
        { itemId = 139020 },
        { itemId = 30164 },
        { itemId = 30161 },
        { itemId = 150672 },
        { itemId = 224357 },
        { itemId = 224358 },
        { itemId = 150789 },
        { itemId = 150731 },
        { itemId = 150671 },
        { itemId = 30162 },
        { itemId = 30151 },
        { itemId = 77587 },
        { itemId = 224359 },
        { itemId = 30156 },
        { itemId = 30158 },
        { itemId = 30155 },
        { itemId = 30163 },
        { itemId = 77591 },
        { itemId = 30153 },
        { itemId = 77590 },
        { itemId = 30165 },
        { itemId = 139019 },
        { itemId = 77589 },
        { itemId = 77584 },
        { itemId = 30149 },
        { itemId = 77581 },
        { itemId = 150670 },
        { itemId = 30152 },
        { itemId = 30166 },
        { itemId = 30154 },
        { itemId = 224360 },
        { itemId = 30159 },
    },
}

merchant.resourceIngredientGroupsByItemId = {}

for groupName, definitions in pairs(merchant.resourceIngredientDefinitions) do
    for _, definition in ipairs(definitions) do
        merchant.resourceIngredientGroupsByItemId[definition.itemId] = groupName
    end
end

merchant.alchemySolventDefinitions = {
    { itemId = 883, level = "3" },
    { itemId = 75357, level = "3" },
    { itemId = 1187, level = "10" },
    { itemId = 75358, level = "10" },
    { itemId = 4570, level = "20" },
    { itemId = 75359, level = "20" },
    { itemId = 23265, level = "30" },
    { itemId = 75360, level = "30" },
    { itemId = 23266, level = "40" },
    { itemId = 75361, level = "40" },
    { itemId = 23267, level = "CP 10" },
    { itemId = 75362, level = "CP 10" },
    { itemId = 23268, level = "CP 50" },
    { itemId = 75363, level = "CP 50" },
    { itemId = 64500, level = "CP 100" },
    { itemId = 75364, level = "CP 100" },
    { itemId = 64501, level = "CP 150" },
    { itemId = 75365, level = "CP 150" },
}

merchant.alchemySolventItemIds = {}

for _, definition in ipairs(merchant.alchemySolventDefinitions) do
    merchant.alchemySolventItemIds[definition.itemId] = true
end

local function CreateDefaults()
    return {
        provisioningEnabled = false,
        provisioningIngredients = {},
        alchemyEnabled = false,
        alchemyIngredients = {},
        alchemySolventsEnabled = false,
        alchemySolvents = {},
    }
end

local function InitializeProfile(profile)
    for groupName, definitions in pairs(merchant.resourceIngredientDefinitions) do
        local field = groupName .. "Ingredients"
        if type(profile[field]) ~= "table" then
            profile[field] = {}
        end
        for _, definition in ipairs(definitions) do
            if profile[field][definition.itemId] == nil then
                profile[field][definition.itemId] = false
            end
        end
    end
    if type(profile.alchemySolvents) ~= "table" then
        profile.alchemySolvents = {}
    end
    for _, definition in ipairs(merchant.alchemySolventDefinitions) do
        if profile.alchemySolvents[definition.itemId] == nil then
            profile.alchemySolvents[definition.itemId] = false
        end
    end
end

local function IsSelectedIngredient(profile, itemLink)
    local itemId = GetItemLinkItemId(itemLink)
    local groupName = merchant.resourceIngredientGroupsByItemId[itemId]
    if not groupName then
        return false
    end
    local enabledField = groupName .. "Enabled"
    local selectionField = groupName .. "Ingredients"
    local selected = profile[selectionField]
    return profile[enabledField] == true and type(selected) == "table" and selected[itemId] == true
end

local function IsSelectedSolvent(profile, itemLink)
    if not profile.alchemySolventsEnabled or type(profile.alchemySolvents) ~= "table" then
        return false
    end
    local itemId = GetItemLinkItemId(itemLink)
    return merchant.alchemySolventItemIds[itemId] == true
        and profile.alchemySolvents[itemId] == true
end

merchant.RegisterProfile("resources", CreateDefaults, InitializeProfile)

merchant.RegisterCategory("resources", function(profile, bagId, slotIndex, itemLink)
    return IsSelectedIngredient(profile, itemLink) or IsSelectedSolvent(profile, itemLink)
end)
