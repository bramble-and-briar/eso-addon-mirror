local A = OneCraft.Enchanting
local I = {}
A.Inventory = I

function I.Usable(bag, slot, id)
    if bag == nil or slot == nil or GetItemId(bag, slot) ~= id or IsItemPlayerLocked(bag, slot) then return false end
    if ZO_CraftingInventory.IsLocked(ENCHANTING.inventory, bag, slot) then return false end
    return select(2, GetItemInfo(bag, slot)) > 0
end

function I.Scan()
    A.inventory = {}
    A.unknownRunes = false
    local function read(bag, slot)
        local crafting, _, runeType, rank, rarity = GetItemCraftingInfo(bag, slot)
        if crafting ~= CRAFTING_TYPE_ENCHANTING or not runeType or runeType == 0 then return end
        local id = GetItemId(bag, slot)
        if not I.Usable(bag, slot, id) then return end
        if not A.runeTypes[id] then A.unknownRunes = true; return end
        if A.runeTypes[id] ~= runeType then A.invalidData = true; return end
        local icon, count = GetItemInfo(bag, slot)
        local old = A.inventory[id]
        if old then
            old.count = old.count + count
            -- Prefer the largest unlocked stack. Crafting is capped to the
            -- selected physical stacks, so a batch cannot spill into locked ones.
            if count > old.stackCount then
                old.bag, old.slot, old.stackCount = bag, slot, count
            end
        else
            A.inventory[id] = {bag = bag, slot = slot, count = count, stackCount = count, icon = icon,
                runeType = runeType, rank = rank or 0, rarity = rarity or 0}
        end
    end
    for _, bag in ipairs({BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK}) do
        for slot = 0, GetBagSize(bag) - 1 do read(bag, slot) end
    end
    local slot = GetNextVirtualBagSlotId(nil)
    while slot do read(BAG_VIRTUAL, slot); slot = GetNextVirtualBagSlotId(slot) end
end
