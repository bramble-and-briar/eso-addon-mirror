-- MANA Junk by Beardborn
-- Marks unwanted items as junk (on pickup or via "Scan now") and offers to sell
-- the junk at a merchant with a list and a confirmation.
-- UI texts are English; translations live in lang/<language>.lua (see MANAJunk.T).
-- AI disclosure: written with the help of an AI assistant (Claude by Anthropic) from the author's design;
-- tested in game and maintained by the author.

-- The single global MANAJunk is shared with the language files in lang/.
MANAJunk = MANAJunk or {}
local MJ = MANAJunk
local T = MJ.T

MJ.name = "MANAJunk"
MJ.displayName = "MANA Junk"
MJ.version = "1.0.1"
MJ.author = "Beardborn"

local SV_VERSION = 1
local DEFAULTS = {
    autoOnPickup = true,
    sellConfirm = true,
    chat = true,
    respectFCOIS = true,    -- honour FCO ItemSaver protection

    ornate = true,          -- Ornate trait gear (gold pouch icon)
    treasure = true,        -- treasures (not stolen), incl. antiquity treasures
    trash = true,           -- items of type Trash
    knownRecipes = true,    -- already known recipes and blueprints
    lowMaterials = true,    -- crafting materials below the top tier
    foodDrink = true,       -- food and drinks, except player-crafted
    potions = true,         -- potions and poisons, except player-crafted and Crown

    itemRules = {},         -- [itemId] = { stacks = n, name = "...", link = "..." }
    categoryRules = {},     -- [itemType] = n
}

local STACK_CHOICES = { 0, 1, 2, 3, 5, 10 }
local SELL_LIST_MAX_LINES = 20

local sv
local blockers = {}   -- open windows during which pickups are ignored
local panel
local ui = { item = nil, itemStacks = 1, category = nil, catStacks = 1 }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local PREFIX = "|cE0A040[MANA Junk]|r "
local function Say(text) d(PREFIX .. text) end
local function Msg(text) if sv and sv.chat then Say(text) end end

local function StacksText(n)
    if n == 0 then return T"0 (all to junk)" end
    return MJ.STACKS(n)
end

local function ItemName(link) return zo_strformat("<<t:1>>", GetItemLinkName(link)) end

local function Set(names)
    local set = {}
    for _, name in ipairs(names) do
        if _G[name] then set[_G[name]] = true end
    end
    return set
end

-- Item types offered as categories, with our own labels (the game uses the same
-- word "Material" for several types). Constants unknown to the game version are skipped.
local CATEGORY_DEFS = {
    { "ITEMTYPE_STYLE_MATERIAL",                T"Style Materials" },
    { "ITEMTYPE_RAW_MATERIAL",                  T"Raw Materials (other)" },
    { "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",    T"Blacksmithing: Ore" },
    { "ITEMTYPE_BLACKSMITHING_MATERIAL",        T"Blacksmithing: Ingots" },
    { "ITEMTYPE_BLACKSMITHING_BOOSTER",         T"Blacksmithing: Tempers" },
    { "ITEMTYPE_CLOTHIER_RAW_MATERIAL",         T"Clothing: Raw Materials" },
    { "ITEMTYPE_CLOTHIER_MATERIAL",             T"Clothing: Cloth & Leather" },
    { "ITEMTYPE_CLOTHIER_BOOSTER",              T"Clothing: Tannins" },
    { "ITEMTYPE_WOODWORKING_RAW_MATERIAL",      T"Woodworking: Raw Wood" },
    { "ITEMTYPE_WOODWORKING_MATERIAL",          T"Woodworking: Sanded Wood" },
    { "ITEMTYPE_WOODWORKING_BOOSTER",           T"Woodworking: Resins" },
    { "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",  T"Jewelry: Dust" },
    { "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",      T"Jewelry: Ounces" },
    { "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER",   T"Jewelry: Raw Platings" },
    { "ITEMTYPE_JEWELRYCRAFTING_BOOSTER",       T"Jewelry: Platings" },
    { "ITEMTYPE_JEWELRY_RAW_TRAIT",             T"Jewelry: Raw Trait Gems" },
    { "ITEMTYPE_JEWELRY_TRAIT",                 T"Jewelry: Trait Gems" },
    { "ITEMTYPE_ARMOR_TRAIT",                   T"Armor Trait Stones" },
    { "ITEMTYPE_WEAPON_TRAIT",                  T"Weapon Trait Stones" },
    { "ITEMTYPE_ENCHANTING_RUNE_ASPECT",        T"Enchanting: Aspect Runes" },
    { "ITEMTYPE_ENCHANTING_RUNE_ESSENCE",       T"Enchanting: Essence Runes" },
    { "ITEMTYPE_ENCHANTING_RUNE_POTENCY",       T"Enchanting: Potency Runes" },
    { "ITEMTYPE_ENCHANTMENT_BOOSTER",           T"Enchanting: Boosters" },
    { "ITEMTYPE_INGREDIENT",                    T"Provisioning: Ingredients" },
    { "ITEMTYPE_REAGENT",                       T"Alchemy: Reagents" },
    { "ITEMTYPE_POTION_BASE",                   T"Alchemy: Potion Solvents" },
    { "ITEMTYPE_POISON_BASE",                   T"Alchemy: Poison Solvents" },
    { "ITEMTYPE_FURNISHING_MATERIAL",           T"Furnishing Materials" },
    { "ITEMTYPE_GLYPH_ARMOR",                   T"Armor Glyphs" },
    { "ITEMTYPE_GLYPH_WEAPON",                  T"Weapon Glyphs" },
    { "ITEMTYPE_GLYPH_JEWELRY",                 T"Jewelry Glyphs" },
    { "ITEMTYPE_FOOD",                          T"Food" },
    { "ITEMTYPE_DRINK",                         T"Drinks" },
    { "ITEMTYPE_POTION",                        T"Potions" },
    { "ITEMTYPE_POISON",                        T"Poisons" },
    { "ITEMTYPE_RECIPE",                        T"Recipes & Blueprints" },
    { "ITEMTYPE_RACIAL_STYLE_MOTIF",            T"Motifs" },
    { "ITEMTYPE_SOUL_GEM",                      T"Soul Gems" },
    { "ITEMTYPE_LURE",                          T"Bait" },
    { "ITEMTYPE_FISH",                          T"Fish" },
    { "ITEMTYPE_TROPHY",                        T"Trophies" },
    { "ITEMTYPE_TREASURE",                      T"Treasures" },
    { "ITEMTYPE_TRASH",                         T"Trash" },
    { "ITEMTYPE_CONTAINER",                     T"Containers" },
    { "ITEMTYPE_FURNISHING",                    T"Furnishings" },
    { "ITEMTYPE_DYE_STAMP",                     T"Dye Stamps" },
    { "ITEMTYPE_MASTER_WRIT",                   T"Master Writs" },
    { "ITEMTYPE_SCRIBING_INK",                  T"Scribing Ink" },
    { "ITEMTYPE_TOOL",                          T"Tools (Repair Kits)" },
    { "ITEMTYPE_AVA_REPAIR",                    T"Cyrodiil Repair Kits" },
    { "ITEMTYPE_SIEGE",                         T"Siege Weapons" },
    { "ITEMTYPE_COSTUME",                       T"Costumes" },
    { "ITEMTYPE_DISGUISE",                      T"Disguises" },
    { "ITEMTYPE_ARMOR",                         T"Armor" },
    { "ITEMTYPE_WEAPON",                        T"Weapons" },
}

local categoryLabels -- [itemType] = label

function MJ.GetCategoryName(itemType)
    if categoryLabels and categoryLabels[itemType] then return categoryLabels[itemType] end
    local name = GetString("SI_ITEMTYPE", itemType)
    if not name or name == "" then return T"Type " .. tostring(itemType) end
    return zo_strformat("<<1>>", name)
end

local function BuildCategoryList()
    local list = {}
    categoryLabels = {}
    for _, def in ipairs(CATEGORY_DEFS) do
        local itemType = _G[def[1]]
        if itemType and not categoryLabels[itemType] then
            categoryLabels[itemType] = def[2]
            list[#list + 1] = { itemType = itemType, name = def[2] }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local ORNATE_TRAITS = Set({ "ITEM_TRAIT_TYPE_ARMOR_ORNATE", "ITEM_TRAIT_TYPE_WEAPON_ORNATE",
                            "ITEM_TRAIT_TYPE_JEWELRY_ORNATE" })

local MATERIAL_TYPES = Set({
    "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_BLACKSMITHING_MATERIAL",
    "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL",
    "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
})

---------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------

-- Items the add-on never marks.
-- FCO ItemSaver: use its dedicated API for the exact action (not the generic FCOIS.IsLocked,
-- which depends on the currently open panel). If a function is missing, fall back to
-- "marked with any icon" so that items are rather kept than destroyed.
local FCOIS_API = {
    junk = { "IsJunkLocked", "IsVendorSellLocked" },
}

local function IsFCOISProtected(bagId, slotIndex, action)
    if not sv.respectFCOIS or not FCOIS then return false end
    for _, fnName in ipairs(FCOIS_API[action] or {}) do
        local fn = FCOIS[fnName]
        if fn then
            local ok, locked
            if fnName == "IsDeconstructionLocked" then
                ok, locked = pcall(fn, bagId, slotIndex, nil)  -- nil: FCOIS also checks jewelry itself
            else
                ok, locked = pcall(fn, bagId, slotIndex)
            end
            return ok and locked == true
        end
    end
    if FCOIS.IsMarked then
        local ok, marked = pcall(FCOIS.IsMarked, bagId, slotIndex, -1)
        return ok and marked == true
    end
    return false
end

-- Items the add-on never marks.
local function IsProtected(bagId, slotIndex)
    if IsItemPlayerLocked(bagId, slotIndex) then return true end
    if IsFCOISProtected(bagId, slotIndex, "junk") then return true end
    if IsItemStolen(bagId, slotIndex) then return true end  -- stolen goods are sold to a fence, not a merchant
    if not CanItemBeMarkedAsJunk(bagId, slotIndex) then return true end
    return false
end

local function IsFromCrown(bagId, slotIndex)
    if IsItemFromCrownStore and IsItemFromCrownStore(bagId, slotIndex) then return true end
    if IsItemFromCrownCrate and IsItemFromCrownCrate(bagId, slotIndex) then return true end
    return false
end

-- Craft and tier (rank) of a material according to the game.
-- Raw materials (ore, dust...) are rated by the material they refine into:
-- e.g. jewelry dust reports tier 1, while its ounce reports the real tier.
local function GetRefinedLink(link)
    if not GetItemLinkRefinedMaterialItemLink then return nil end
    local ok, refined = pcall(GetItemLinkRefinedMaterialItemLink, link)
    if ok and refined and refined ~= "" then return refined end
    return nil
end

local function GetMaterialTier(link)
    if not (GetItemLinkCraftingSkillType and GetItemLinkRequiredCraftingSkillRank) then return nil end
    link = GetRefinedLink(link) or link
    local ok1, craftType = pcall(GetItemLinkCraftingSkillType, link)
    local ok2, rank = pcall(GetItemLinkRequiredCraftingSkillRank, link)
    if not ok1 or not ok2 or not craftType or not rank then return nil end
    return craftType, rank
end

-- The top tier for each craft is taken from what is actually
-- in the inventory and bank. Only materials below the highest tier
-- of the same craft count as old. If there are no other tiers, nothing is touched.
local materialTopCache = nil

local function BuildMaterialTop()
    local top = {}
    for _, bag in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        if bag then
            for slot in ZO_IterateBagSlots(bag) do
                if MATERIAL_TYPES[GetItemType(bag, slot)] then
                    local craftType, rank = GetMaterialTier(GetItemLink(bag, slot))
                    if craftType and rank and rank > (top[craftType] or 0) then
                        top[craftType] = rank
                    end
                end
            end
        end
    end
    return top
end

local function IsLowLevelMaterial(link)
    local craftType, rank = GetMaterialTier(link)
    if not craftType or not rank or rank <= 0 then return false end
    materialTopCache = materialTopCache or BuildMaterialTop()
    local top = materialTopCache[craftType]
    return top ~= nil and rank < top
end

-- Reason why an item is junk by the checkbox categories, or nil.
function MJ.GetCategoryReason(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex)

    if sv.ornate and (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON)
        and ORNATE_TRAITS[GetItemTrait(bagId, slotIndex)] then
        return T"for sale (ornate)"
    end
    if sv.treasure and itemType == ITEMTYPE_TREASURE then
        return T"treasure"
    end
    if sv.trash and ITEMTYPE_TRASH and itemType == ITEMTYPE_TRASH then
        return T"trash"
    end
    if sv.knownRecipes and itemType == ITEMTYPE_RECIPE and IsItemLinkRecipeKnown(link) then
        return T"recipe already known"
    end
    if sv.lowMaterials and MATERIAL_TYPES[itemType] and IsLowLevelMaterial(link) then
        return T"lower-tier material"
    end
    if sv.foodDrink and (itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK)
        and not IsItemLinkCrafted(link) then
        return T"food/drink"
    end
    if sv.potions and (itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON)
        and not IsItemLinkCrafted(link) and not IsFromCrown(bagId, slotIndex) then
        return T"potion/poison"
    end
    return nil
end

-- Rule for a slot: item rule first, then category rule.
-- Returns the number of stacks and a chat label, or nil.
local function GetRule(bagId, slotIndex)
    local rule = sv.itemRules[GetItemId(bagId, slotIndex)]
    if rule then return rule.stacks, T"over the rule limit (" .. StacksText(rule.stacks) .. ")" end
    local itemType = GetItemType(bagId, slotIndex)
    local stacks = sv.categoryRules[itemType]
    if stacks ~= nil then
        return stacks, T"over the category rule “" .. MJ.GetCategoryName(itemType) .. T"” (" .. StacksText(stacks) .. ")"
    end
    return nil
end

-- For an item with a rule: which inventory slots are excess.
-- Keep the fullest stacks while within the limit, the rest goes to junk.
local function SlotsOverRule(itemId, stacks)
    local slots, maxStack = {}, 1
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if GetItemId(BAG_BACKPACK, slot) == itemId and not IsItemJunk(BAG_BACKPACK, slot) then
            local count, max = GetSlotStackSize(BAG_BACKPACK, slot)
            if max > maxStack then maxStack = max end
            slots[#slots + 1] = { slot = slot, count = count }
        end
    end
    table.sort(slots, function(a, b) return a.count > b.count end)
    local limit, kept, over = stacks * maxStack, 0, {}
    for _, s in ipairs(slots) do
        if kept + s.count <= limit then
            kept = kept + s.count
        else
            over[#over + 1] = s.slot
        end
    end
    return over
end

-- Collects everything to mark: { { slot = , reason = }, ... }
function MJ.CollectJunk()
    materialTopCache = nil
    local result, seenRule = {}, {}
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if not IsItemJunk(BAG_BACKPACK, slot) and not IsProtected(BAG_BACKPACK, slot) then
            local itemId = GetItemId(BAG_BACKPACK, slot)
            local stacks, label = GetRule(BAG_BACKPACK, slot)
            if stacks ~= nil then
                if not seenRule[itemId] then
                    seenRule[itemId] = true
                    for _, overSlot in ipairs(SlotsOverRule(itemId, stacks)) do
                        if not IsProtected(BAG_BACKPACK, overSlot) then
                            result[#result + 1] = { slot = overSlot, reason = label }
                        end
                    end
                end
            else
                local reason = MJ.GetCategoryReason(BAG_BACKPACK, slot)
                if reason then result[#result + 1] = { slot = slot, reason = reason } end
            end
        end
    end
    return result
end

local function MarkList(list)
    local count = 0
    for _, entry in ipairs(list) do
        local link = GetItemLink(BAG_BACKPACK, entry.slot)
        SetItemIsJunk(BAG_BACKPACK, entry.slot, true)
        count = count + 1
        Msg(T"Junk: " .. link .. " — " .. entry.reason)
    end
    return count
end

---------------------------------------------------------------------------
-- Pickups
---------------------------------------------------------------------------

local function ProcessPickedSlot(slotIndex)
    materialTopCache = nil
    if not GetItemId(BAG_BACKPACK, slotIndex) or GetItemId(BAG_BACKPACK, slotIndex) == 0 then return end
    if IsItemJunk(BAG_BACKPACK, slotIndex) or IsProtected(BAG_BACKPACK, slotIndex) then return end

    local itemId = GetItemId(BAG_BACKPACK, slotIndex)
    local stacks, label = GetRule(BAG_BACKPACK, slotIndex)
    local list = {}
    if stacks ~= nil then
        for _, overSlot in ipairs(SlotsOverRule(itemId, stacks)) do
            if not IsProtected(BAG_BACKPACK, overSlot) then
                list[#list + 1] = { slot = overSlot, reason = label }
            end
        end
    else
        local reason = MJ.GetCategoryReason(BAG_BACKPACK, slotIndex)
        if reason then list[1] = { slot = slotIndex, reason = reason } end
    end
    MarkList(list)
end

local function IsBlocked()
    for _, open in pairs(blockers) do
        if open then return true end
    end
    return false
end

local function OnSlotUpdate(_, bagId, slotIndex, isNewItem, _, updateReason, stackCountChange)
    if not sv.autoOnPickup or IsBlocked() then return end
    if updateReason ~= nil and updateReason ~= INVENTORY_UPDATE_REASON_DEFAULT then return end
    if not isNewItem and not (stackCountChange and stackCountChange > 0) then return end
    zo_callLater(function() ProcessPickedSlot(slotIndex) end, 200)
end

local function Blocker(key, value)
    return function() blockers[key] = value end
end

---------------------------------------------------------------------------
-- Scan and preview
---------------------------------------------------------------------------

function MJ.Scan()
    local count = MarkList(MJ.CollectJunk())
    Say(count > 0 and (T"Marked as junk: " .. count .. ".") or T"Nothing to mark.")
end

-- Diagnostics: what the game reports about materials in the inventory.
function MJ.MaterialsInfo()
    materialTopCache = BuildMaterialTop()
    Say(T"Materials in the inventory (craft / tier / highest found):")
    local any = false
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if MATERIAL_TYPES[GetItemType(BAG_BACKPACK, slot)] then
            local link = GetItemLink(BAG_BACKPACK, slot)
            local craftType, rank = GetMaterialTier(link)
            d(string.format(T"  %s — craft %s, tier %s, highest %s%s", link, tostring(craftType),
                tostring(rank), tostring(craftType and materialTopCache[craftType]),
                IsLowLevelMaterial(link) and T" → junk" or ""))
            any = true
        end
    end
    if not any then d(T"  no crafting materials") end
end

function MJ.Preview()
    local list = MJ.CollectJunk()
    Say(T"Will be marked as junk: " .. #list)
    for _, entry in ipairs(list) do
        d("  " .. GetItemLink(BAG_BACKPACK, entry.slot) .. " — " .. entry.reason)
    end
end

---------------------------------------------------------------------------
-- Selling at merchants
---------------------------------------------------------------------------

local function CollectJunkForSale()
    local items, total = {}, 0
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if IsItemJunk(BAG_BACKPACK, slot) and not IsItemStolen(BAG_BACKPACK, slot) then
            local _, stack, sellPrice = GetItemInfo(BAG_BACKPACK, slot)
            local value = (sellPrice or 0) * (stack or 1)
            total = total + value
            local quality = (GetItemDisplayQuality and GetItemDisplayQuality(BAG_BACKPACK, slot))
                or (GetItemFunctionalQuality and GetItemFunctionalQuality(BAG_BACKPACK, slot))
                or GetItemQuality(BAG_BACKPACK, slot) or 0
            items[#items + 1] = { link = GetItemLink(BAG_BACKPACK, slot), stack = stack or 1,
                                  value = value, quality = quality }
        end
    end
    -- Rarest quality first; within a quality, most expensive first.
    table.sort(items, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.value > b.value
    end)
    return items, total
end

local function BuildSaleText(items, total)
    local lines = {}
    for i, item in ipairs(items) do
        if i > SELL_LIST_MAX_LINES then
            lines[#lines + 1] = T"…and " .. (#items - SELL_LIST_MAX_LINES)
            break
        end
        local qty = item.stack > 1 and (" x" .. item.stack) or ""
        lines[#lines + 1] = item.link .. qty .. " — " .. ZO_CommaDelimitNumber(item.value)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = T"Total: " .. #items .. T" items, " .. ZO_CommaDelimitNumber(total) .. T" gold"
    return table.concat(lines, "\n")
end

local function SellNow(count, total)
    SellAllJunk()
    Msg(T"Sold: " .. count .. T" items for " .. ZO_CommaDelimitNumber(total) .. T" gold.")
end

local function RegisterSellDialog()
    ZO_Dialogs_RegisterCustomDialog("MANAJUNK_SELL_CONFIRM", {
        title = { text = T"MANA Junk — sell junk?" },
        mainText = { text = "<<1>>" },
        buttons = {
            { text = T"Sell", callback = function(dialog) SellNow(dialog.data.count, dialog.data.total) end },
            { text = T"Cancel" },
        },
    })
end

local function OnOpenStore()
    if not sv.sellConfirm then return end
    zo_callLater(function()
        local items, total = CollectJunkForSale()
        if #items == 0 then return end
        ZO_Dialogs_ShowDialog("MANAJUNK_SELL_CONFIRM",
            { count = #items, total = total },
            { mainTextParams = { BuildSaleText(items, total) } })
    end, 300)
end

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------

function MJ.SetItemRule(itemId, stacks, link)
    sv.itemRules[itemId] = { stacks = stacks, name = ItemName(link), link = link }
    Say(link .. T": keep in the inventory " .. StacksText(stacks) .. T", the rest to junk")
    MJ.RefreshSettings()
    local list = {}
    for _, overSlot in ipairs(SlotsOverRule(itemId, stacks)) do
        if not IsProtected(BAG_BACKPACK, overSlot) then
            list[#list + 1] = { slot = overSlot, reason = T"over the rule limit (" .. StacksText(stacks) .. ")" }
        end
    end
    MarkList(list)
end

function MJ.RemoveItemRule(itemId)
    local rule = sv.itemRules[itemId]
    sv.itemRules[itemId] = nil
    if rule then Say(T"Rule removed: " .. (rule.link or rule.name)) end
    MJ.RefreshSettings()
end

function MJ.SetCategoryRule(itemType, stacks)
    sv.categoryRules[itemType] = stacks
    Say(T"Category “" .. MJ.GetCategoryName(itemType) .. T"”: keep in the inventory " .. StacksText(stacks) .. T" of each item, the rest to junk")
    MJ.RefreshSettings()
    MarkList(MJ.CollectJunk())
end

function MJ.RemoveCategoryRule(itemType)
    if sv.categoryRules[itemType] == nil then return end
    sv.categoryRules[itemType] = nil
    Say(T"Rule removed: category “" .. MJ.GetCategoryName(itemType) .. T"”")
    MJ.RefreshSettings()
end

---------------------------------------------------------------------------
-- Context menu
---------------------------------------------------------------------------

local function BuildStackEntries(current, onPick, onRemove)
    local entries = {}
    for _, n in ipairs(STACK_CHOICES) do
        local label = StacksText(n)
        if n == current then label = "» " .. label end
        entries[#entries + 1] = { label = label, callback = function() onPick(n) end }
    end
    if current ~= nil then
        entries[#entries + 1] = { label = T"Remove rule", callback = onRemove }
    end
    return entries
end

local function AddContextMenu(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_BANK then return end
    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId == 0 then return end
    local link = GetItemLink(bagId, slotIndex)

    local rule = sv.itemRules[itemId]
    local current = rule and rule.stacks
    local title = T"Junk: keep in the inventory"
    if current then title = title .. " (" .. StacksText(current) .. ")" end

    AddCustomSubMenuItem(title, BuildStackEntries(current,
        function(n) MJ.SetItemRule(itemId, n, link) end,
        function() MJ.RemoveItemRule(itemId) end))

    local itemType = GetItemType(bagId, slotIndex)
    if itemType and itemType ~= ITEMTYPE_NONE then
        local catCurrent = sv.categoryRules[itemType]
        local catTitle = T"Junk: category “" .. MJ.GetCategoryName(itemType) .. T"”"
        if catCurrent then catTitle = catTitle .. " (" .. StacksText(catCurrent) .. ")" end
        AddCustomSubMenuItem(catTitle, BuildStackEntries(catCurrent,
            function(n) MJ.SetCategoryRule(itemType, n) end,
            function() MJ.RemoveCategoryRule(itemType) end))
    end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function CategoryRulesText()
    local lines = {}
    for itemType, stacks in pairs(sv.categoryRules) do
        lines[#lines + 1] = MJ.GetCategoryName(itemType) .. ": " .. StacksText(stacks)
    end
    if #lines == 0 then return T"No rules yet." end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function ItemRulesText()
    local lines = {}
    for _, rule in pairs(sv.itemRules) do
        lines[#lines + 1] = (rule.name or "?") .. ": " .. StacksText(rule.stacks)
    end
    if #lines == 0 then return T"No rules yet. Add them by right-clicking an item." end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function ItemChoices()
    local ids = {}
    for id in pairs(sv.itemRules) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return (sv.itemRules[a].name or "") < (sv.itemRules[b].name or "") end)
    local names, values = {}, {}
    for _, id in ipairs(ids) do
        names[#names + 1] = sv.itemRules[id].name or tostring(id)
        values[#values + 1] = id
    end
    if #names == 0 then names[1] = "—"; values[1] = 0 end
    return names, values
end

function MJ.RefreshSettings()
    if ui.item and not sv.itemRules[ui.item] then ui.item = nil end
    local dropdown = _G["MANAJunk_ItemDropdown"]
    if dropdown and dropdown.UpdateChoices then dropdown:UpdateChoices(ItemChoices()) end
    for ref, textFn in pairs({ MANAJunk_ItemList = ItemRulesText, MANAJunk_CategoryList = CategoryRulesText }) do
        local ctrl = _G[ref]
        if ctrl then
            local text = textFn()
            if ctrl.data then ctrl.data.text = text end
            if ctrl.desc then ctrl.desc:SetText(text) end
        end
    end
    if panel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end
end

local function Checkbox(key, name, tooltip)
    return { type = "checkbox", name = name, tooltip = tooltip,
             getFunc = function() return sv[key] end,
             setFunc = function(v) sv[key] = v end }
end

local function CreateSettings()
    local LAM = LibAddonMenu2
    local itemNames, itemValues = ItemChoices()
    local catNames, catValues = {}, {}
    for _, c in ipairs(BuildCategoryList()) do
        catNames[#catNames + 1] = c.name
        catValues[#catValues + 1] = c.itemType
    end
    ui.category = catValues[1]

    panel = LAM:RegisterAddonPanel("MANAJunk_Panel", {
        type = "panel", name = MJ.displayName, displayName = MJ.displayName,
        author = MJ.author, version = MJ.version,
        slashCommand = "/manajunksettings", registerForRefresh = true,
    })

    LAM:RegisterOptionControls("MANAJunk_Panel", {
        { type = "description",
          text = T"Marks unwanted items as junk when you pick them up. At a merchant it shows the junk list and sells it after you confirm. Locked and stolen items are never touched." },

        { type = "header", name = T"General" },
        Checkbox("autoOnPickup", T"Check items on pickup"),
        Checkbox("sellConfirm", T"Offer to sell junk at merchants",
                 T"Opening a merchant shows a window with the junk list and the total."),
        Checkbox("chat", T"Chat messages"),
        Checkbox("respectFCOIS", T"Respect FCO ItemSaver protection",
                 T"Items protected in FCO ItemSaver against junk/selling are never marked as junk."),
        { type = "button", name = T"Scan now",
          tooltip = T"Check the whole inventory now and mark matching items as junk.",
          func = function() MJ.Scan() end },

        { type = "header", name = T"What counts as junk" },
        Checkbox("ornate", T"Items for sale (Ornate)",
                 T"Gear with the Ornate trait (gold pouch icon)."),
        Checkbox("treasure", T"Treasures",
                 T"Items of type Treasure, including antiquity treasures. Stolen items are not touched."),
        Checkbox("trash", T"Trash", T"Items of type Trash — they are only good for selling."),
        Checkbox("knownRecipes", T"Known recipes and blueprints"),
        Checkbox("lowMaterials", T"Lower-tier raw and refined materials",
                 T"Ore, ingots, cloth, leather, wood and jewelry materials below the highest tier of the same craft found in your inventory or bank."),
        Checkbox("foodDrink", T"Food and drinks", T"Except player-crafted ones."),
        Checkbox("potions", T"Potions and poisons", T"Except player-crafted and Crown Store ones."),

        { type = "header", name = T"Category rules" },
        { type = "description",
          text = T"How many stacks of each item of a category to keep in the inventory; everything above goes to junk. A category rule overrides the checkboxes above, and an item rule overrides a category rule." },
        { type = "dropdown", name = T"Category", scrollable = true,
          choices = catNames, choicesValues = catValues,
          getFunc = function() return ui.category end,
          setFunc = function(v)
              ui.category = v
              if sv.categoryRules[v] ~= nil then ui.catStacks = sv.categoryRules[v] end
          end },
        { type = "slider", name = T"Stacks in the inventory", min = 0, max = 20, step = 1,
          tooltip = T"0 — everything to junk.",
          getFunc = function() return ui.catStacks end,
          setFunc = function(v) ui.catStacks = v end },
        { type = "button", name = T"Save", width = "half",
          func = function() if ui.category then MJ.SetCategoryRule(ui.category, ui.catStacks) end end },
        { type = "button", name = T"Delete", width = "half",
          func = function() if ui.category then MJ.RemoveCategoryRule(ui.category) end end },
        { type = "description", title = T"Current category rules", text = CategoryRulesText(), reference = "MANAJunk_CategoryList" },

        { type = "header", name = T"Item rules" },
        { type = "description",
          text = T"How many stacks to keep in the inventory; everything above goes to junk. Add rules by right-clicking an item. An item rule overrides category rules and the checkboxes above." },
        { type = "dropdown", name = T"Item", scrollable = true,
          choices = itemNames, choicesValues = itemValues, reference = "MANAJunk_ItemDropdown",
          getFunc = function() return ui.item or 0 end,
          setFunc = function(v)
              if v ~= 0 and sv.itemRules[v] then
                  ui.item = v
                  ui.itemStacks = sv.itemRules[v].stacks
              else
                  ui.item = nil
              end
          end },
        { type = "slider", name = T"Stacks in the inventory", min = 0, max = 20, step = 1,
          tooltip = T"0 — everything to junk.",
          disabled = function() return ui.item == nil end,
          getFunc = function() return ui.itemStacks end,
          setFunc = function(v) ui.itemStacks = v end },
        { type = "button", name = T"Save", width = "half",
          func = function()
              local rule = ui.item and sv.itemRules[ui.item]
              if rule then MJ.SetItemRule(ui.item, ui.itemStacks, rule.link) end
          end },
        { type = "button", name = T"Delete", width = "half",
          func = function() if ui.item then MJ.RemoveItemRule(ui.item) end end },
        { type = "description", title = T"Current rules", text = ItemRulesText(), reference = "MANAJunk_ItemList" },
    })

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(created)
        if created == panel then MJ.RefreshSettings() end
    end)
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

-- Server-dependent account-wide settings (EU and NA have different banks and items).
-- Settings saved by earlier versions (not server dependent) are copied to each server once.
local function LoadSavedVars(svName, version, defaults)
    local displayName = GetDisplayName()
    local raw = _G[svName]
    local old = raw and raw["Default"] and raw["Default"][displayName] and raw["Default"][displayName]["$AccountWide"]
    local saved = ZO_SavedVars:NewAccountWide(svName, version, nil, defaults, GetWorldName())
    -- Copy (not move), so every server you play on gets the old settings once.
    if old and not saved.copiedFromDefault then
        for key, value in pairs(old) do
            if key ~= "version" then
                saved[key] = (type(value) == "table") and ZO_DeepTableCopy(value) or value
            end
        end
        saved.copiedFromDefault = true
    end
    return saved
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= MJ.name then return end
    EVENT_MANAGER:UnregisterForEvent(MJ.name, EVENT_ADD_ON_LOADED)

    sv = LoadSavedVars("MANAJunk_SV", SV_VERSION, DEFAULTS)
    sv.itemRules = sv.itemRules or {}
    sv.categoryRules = sv.categoryRules or {}

    local em = EVENT_MANAGER
    em:RegisterForEvent(MJ.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    em:AddFilterForEvent(MJ.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

    -- While these windows are open, new items are not checked (buying, bank, trade).
    em:RegisterForEvent(MJ.name .. "_StoreOpen", EVENT_OPEN_STORE, function()
        blockers.store = true
        OnOpenStore()
    end)
    em:RegisterForEvent(MJ.name .. "_StoreClose", EVENT_CLOSE_STORE, Blocker("store", false))
    em:RegisterForEvent(MJ.name .. "_BankOpen", EVENT_OPEN_BANK, Blocker("bank", true))
    em:RegisterForEvent(MJ.name .. "_BankClose", EVENT_CLOSE_BANK, Blocker("bank", false))
    em:RegisterForEvent(MJ.name .. "_GBankOpen", EVENT_OPEN_GUILD_BANK, Blocker("guildBank", true))
    em:RegisterForEvent(MJ.name .. "_GBankClose", EVENT_CLOSE_GUILD_BANK, Blocker("guildBank", false))
    em:RegisterForEvent(MJ.name .. "_TradeOpen", EVENT_TRADE_INVITE_ACCEPTED, Blocker("trade", true))
    em:RegisterForEvent(MJ.name .. "_TradeClose", EVENT_TRADE_CANCELED, Blocker("trade", false))
    em:RegisterForEvent(MJ.name .. "_TradeDone", EVENT_TRADE_SUCCEEDED, Blocker("trade", false))

    if LibCustomMenu then
        LibCustomMenu:RegisterContextMenu(AddContextMenu, LibCustomMenu.CATEGORY_LATE)
    end

    BuildCategoryList()
    RegisterSellDialog()
    CreateSettings()

    SLASH_COMMANDS["/manajunk"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "scan" then
            MJ.Scan()
        elseif arg == "preview" then
            MJ.Preview()
        elseif arg == "materials" then
            MJ.MaterialsInfo()
        else
            Say(T"/manajunk preview — show what would be marked as junk (changes nothing)")
            Say(T"/manajunk scan — check the inventory and mark junk")
            Say(T"/manajunk materials — material tier diagnostics")
            Say(T"/manajunksettings — settings")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(MJ.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
