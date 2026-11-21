local ME = MyExtras
local QoL = ME.QualityOfLife
local DNL = {}
ME.DoNotLearn = DNL

--------------------------------------------------
-- Config
--------------------------------------------------
local LEARN_ANYWAY = "Learn Anyway"

local DEFAULTS = {
    dnlRecipes     = true,
    dnlFurnishings = true,
    dnlMotifs      = true,
    dnlScribing    = true,
    dnlCollectible = false,
    dnlRunebox     = false,
}
QoL:AddDefaults(DEFAULTS)

DNL.blockChoices = {
    { name = "Recipes",           value = "dnlRecipes"     },
    { name = "Furnishing Plans",  value = "dnlFurnishings" },
    { name = "Motifs",            value = "dnlMotifs"      },
    { name = "Scribing",          value = "dnlScribing"    },
    { name = "Collectible Items", value = "dnlCollectible" },
    { name = "Runeboxes",         value = "dnlRunebox"     },
}

local BLOCK_TEXT = {
    dnlRecipes     = "Recipe",
    dnlFurnishings = "Furnishing plan",
    dnlMotifs      = "Motif",
    dnlScribing    = "Scribing",
    dnlCollectible = "Collectible",
    dnlRunebox     = "Runebox",
}

local RUNEBOX_ICONS = {
    ["/esoui/art/icons/container_sealed_polymorph_001.dds"] = true,
    ["/esoui/art/icons/item_collectible_runebound_tome.dds"] = true,
}

local FURNISHING_TYPES = {
    "SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING",
}

local FOOD_TYPES = {
    "SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD",
    "SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK",
}

local SCRIBING_TYPES = {
    "ITEMTYPE_CRAFTED_ABILITY",
    "ITEMTYPE_CRAFTED_ABILITY_SCRIPT",
}

local hooked = false
local typeSets

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return QoL:Settings()
end

local function Set(names)
    local set = {}
    for i = 1, #names do
        local value = rawget(_G, names[i])
        if value ~= nil then set[value] = true end
    end
    return set
end

local function TypeSets()
    if not typeSets then
        typeSets = {
            furnishing = Set(FURNISHING_TYPES),
            food       = Set(FOOD_TYPES),
            scribing   = Set(SCRIBING_TYPES),
        }
    end
    return typeSets
end

local function CollectibleKnown(itemLink)
    if IsItemLinkSetCollectionPiece(itemLink) then
        return IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))
    end
    local id = GetItemLinkContainerCollectibleId(itemLink)
    if not id or id == 0 then return nil end
    if IsCollectibleOwnedByDefId(id) then return true end
    if GetCollectibleCategoryType(id) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
        and not CanCombinationFragmentBeUnlocked(id) then
        return true
    end
    return false
end

local function IsRunebox(bagId, slotIndex, itemLink)
    local icon = GetItemInfo(bagId, slotIndex)
    if type(icon) == "string" and RUNEBOX_ICONS[icon:lower()] then return true end
    local id = GetItemLinkContainerCollectibleId(itemLink)
    return id ~= nil and id > 0
end

local function LearnKey(bagId, slotIndex)
    local itemType, specializedType = GetItemType(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex)
    local sets = TypeSets()

    if itemType == ITEMTYPE_RECIPE then
        if sets.food[specializedType] then
            if IsItemLinkRecipeKnown(itemLink) then return nil end
            return "dnlRecipes"
        elseif sets.furnishing[specializedType] then
            if IsItemLinkRecipeKnown(itemLink) then return nil end
            return "dnlFurnishings"
        end
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        if IsItemLinkBookKnown(itemLink) then return nil end
        return "dnlMotifs"
    elseif sets.scribing[itemType] then
        if IsItemLinkBookKnown(itemLink) then return nil end
        return "dnlScribing"
    elseif itemType == ITEMTYPE_COLLECTIBLE then
        if CollectibleKnown(itemLink) ~= false then return nil end
        return "dnlCollectible"
    elseif itemType == ITEMTYPE_CONTAINER then
        if not IsRunebox(bagId, slotIndex, itemLink) then return nil end
        if CollectibleKnown(itemLink) ~= false then return nil end
        return "dnlRunebox"
    end
    return nil
end

local function BlockedKey(bagId, slotIndex)
    local ok, key = pcall(LearnKey, bagId, slotIndex)
    if not ok or not key then return nil end
    if SV()[key] then return key end
    return nil
end

--------------------------------------------------
-- Hooks
--------------------------------------------------
local function OnUseItem(bagId, slotIndex)
    local usable, onlyFromActionSlot = IsItemUsable(bagId, slotIndex)
    if not usable or onlyFromActionSlot then return false end
    local key = BlockedKey(bagId, slotIndex)
    if not key then return false end
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
        BLOCK_TEXT[key] .. " blocked. Use " .. LEARN_ANYWAY .. " to learn it.")
    return true
end

local function LearnAnyway(bagId, slotIndex)
    CallSecureProtected("UseItem", bagId, slotIndex)
end

local function AddLearnAnyway(inventorySlot, slotActions)
    if not (inventorySlot and inventorySlot.dataSource and slotActions) then return end
    if IsBankOpen() or IsGuildBankOpen() then return end
    local bagId = inventorySlot.dataSource.bagId
    local slotIndex = inventorySlot.dataSource.slotIndex
    if not (bagId and slotIndex) then return end
    if not BlockedKey(bagId, slotIndex) then return end
    slotActions:AddSlotAction(SI_MYEXTRAS_LEARN_ANYWAY, function() LearnAnyway(bagId, slotIndex) end, "keybind3")
end

local function Hook()
    if hooked then return end
    if not rawget(_G, "SI_MYEXTRAS_LEARN_ANYWAY") then ZO_CreateStringId("SI_MYEXTRAS_LEARN_ANYWAY", LEARN_ANYWAY) end
    if not IsProtectedFunction("UseItem") then return end
    hooked = true
    local function UseItemHooked(...)
        if OnUseItem(...) then return end
        return CallSecureProtected("UseItem", ...)
    end
    _G.UseItem = UseItemHooked
    SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", AddLearnAnyway)
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function DNL:SubmenuOption()
    local defaultValues = {}
    for i = 1, #self.blockChoices do
        local key = self.blockChoices[i].value
        if DEFAULTS[key] then defaultValues[#defaultValues + 1] = key end
    end
    return {
        type    = "submenu",
        name    = "Do Not Learn",
        tooltip = "Stops you from learning things by accident.",
        options = {
            {
                type    = "checklist",
                name    = "Block",
                choices = self.blockChoices,
                default = defaultValues,
                tooltip = "Stops you from learning these when you use them. "
                       .. "To learn one anyway, highlight it in your inventory and pick " .. LEARN_ANYWAY .. ".\n\n"
                       .. "Recipes: food and drink recipes.\n"
                       .. "Furnishing Plans: plans for furniture.\n"
                       .. "Motifs: style books and chapters.\n"
                       .. "Scribing: grimoires and scripts.\n"
                       .. "Collectible Items: style pages and other items that unlock a collectible, like pets and mounts.\n"
                       .. "Runeboxes: boxes that unlock a collectible.",
                getFunc = function()
                    local sv = SV()
                    local values = {}
                    for i = 1, #DNL.blockChoices do
                        local key = DNL.blockChoices[i].value
                        if sv[key] then values[#values + 1] = key end
                    end
                    return values
                end,
                setFunc = function(values)
                    local sv = SV()
                    local set = {}
                    if type(values) == "table" then
                        for i = 1, #values do set[values[i]] = true end
                    end
                    for i = 1, #DNL.blockChoices do
                        local key = DNL.blockChoices[i].value
                        sv[key] = set[key] == true
                    end
                end,
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function DNL:Init()
    Hook()
end

function DNL:OnPlayerActivated()
    Hook()
end

ME:RegisterFeature(DNL)
