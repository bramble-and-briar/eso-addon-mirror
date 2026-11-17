-- FurnishingCatalogShoppingUtils.lua: pure helpers for the shopping lists (no game calls).
--
-- The store is a plain table kept in saved variables:
--   { nextId = 2, lastUsedId = 1, lists = { { id = 1, name = "Default", items = { itemId, ... } }, ... } }
-- The list with DEFAULT_ID always exists and cannot be deleted. Items are unique within a list
-- and keep the order they were added in.
local FC = FurnishingCatalog

local ShoppingUtils = {}

ShoppingUtils.DEFAULT_ID = 1
ShoppingUtils.DEFAULT_NAME = "Default"
ShoppingUtils.MAX_NAME_LENGTH = 30
ShoppingUtils.MAX_LISTS = 25

---Bring whatever was saved into the store's shape, with the default list present.
---@param store any
---@return FurnishingCatalogShoppingStore
function ShoppingUtils.Normalize(store)
    if type(store) ~= "table" then
        store = {}
    end
    if type(store.lists) ~= "table" then
        store.lists = {}
    end
    local hasDefault = false
    local highestId = ShoppingUtils.DEFAULT_ID
    for _, list in ipairs(store.lists) do
        if type(list.items) ~= "table" then
            list.items = {}
        end
        if list.id == ShoppingUtils.DEFAULT_ID then
            hasDefault = true
        end
        if type(list.id) == "number" and list.id > highestId then
            highestId = list.id
        end
    end
    if not hasDefault then
        table.insert(store.lists, 1, { id = ShoppingUtils.DEFAULT_ID, name = ShoppingUtils.DEFAULT_NAME, items = {} })
    end
    if type(store.nextId) ~= "number" or store.nextId <= highestId then
        store.nextId = highestId + 1
    end
    return store
end

---@param store FurnishingCatalogShoppingStore
---@param listId integer|nil
---@return FurnishingCatalogShoppingList|nil list
---@return integer|nil index
function ShoppingUtils.Find(store, listId)
    for index, list in ipairs(store.lists) do
        if list.id == listId then
            return list, index
        end
    end
    return nil, nil
end

---Check a list name: trimmed, 1 to MAX_NAME_LENGTH characters, not the name of another list
---(compared without case).
---@param store FurnishingCatalogShoppingStore
---@param name any
---@param exceptId integer|nil the list being renamed, which may keep its own name
---@return string|nil cleanName
---@return string|nil reason "empty", "long" or "taken"
function ShoppingUtils.ValidateName(store, name, exceptId)
    local clean = string.gsub(string.gsub(tostring(name or ""), "^%s+", ""), "%s+$", "")
    if clean == "" then
        return nil, "empty"
    end
    if #clean > ShoppingUtils.MAX_NAME_LENGTH then
        return nil, "long"
    end
    local lowered = string.lower(clean)
    for _, list in ipairs(store.lists) do
        if list.id ~= exceptId and string.lower(list.name) == lowered then
            return nil, "taken"
        end
    end
    return clean, nil
end

---What to tell the player about a name that did not pass.
---@param reason string|nil
---@return string
function ShoppingUtils.ReasonText(reason)
    if reason == "empty" then
        return "Give the list a name."
    elseif reason == "long" then
        return string.format("A list name can be up to %d characters.", ShoppingUtils.MAX_NAME_LENGTH)
    elseif reason == "taken" then
        return "Another list already has that name."
    elseif reason == "full" then
        return string.format("There can be up to %d lists.", ShoppingUtils.MAX_LISTS)
    elseif reason == "default" then
        return "The default list stays."
    end
    return "That did not work."
end

---@param store FurnishingCatalogShoppingStore
---@param name any
---@return FurnishingCatalogShoppingList|nil list
---@return string|nil reason "empty", "long", "taken" or "full"
function ShoppingUtils.Create(store, name)
    if #store.lists >= ShoppingUtils.MAX_LISTS then
        return nil, "full"
    end
    local clean, reason = ShoppingUtils.ValidateName(store, name, nil)
    if not clean then
        return nil, reason
    end
    local list = { id = store.nextId, name = clean, items = {} }
    store.nextId = store.nextId + 1
    store.lists[#store.lists + 1] = list
    return list, nil
end

---@param store FurnishingCatalogShoppingStore
---@param listId integer
---@param name any
---@return FurnishingCatalogShoppingList|nil list
---@return string|nil reason
function ShoppingUtils.Rename(store, listId, name)
    local list = ShoppingUtils.Find(store, listId)
    if not list then
        return nil, "missing"
    end
    local clean, reason = ShoppingUtils.ValidateName(store, name, listId)
    if not clean then
        return nil, reason
    end
    list.name = clean
    return list, nil
end

---@param store FurnishingCatalogShoppingStore
---@param listId integer
---@return boolean deleted
---@return string|nil reason "default" or "missing"
function ShoppingUtils.Delete(store, listId)
    if listId == ShoppingUtils.DEFAULT_ID then
        return false, "default"
    end
    local _, index = ShoppingUtils.Find(store, listId)
    if not index then
        return false, "missing"
    end
    table.remove(store.lists, index)
    if store.lastUsedId == listId then
        store.lastUsedId = ShoppingUtils.DEFAULT_ID
    end
    return true, nil
end

---@param list FurnishingCatalogShoppingList
---@param itemId integer
---@return integer|nil index
function ShoppingUtils.IndexOf(list, itemId)
    for index, listedId in ipairs(list.items) do
        if listedId == itemId then
            return index
        end
    end
    return nil
end

---@param list FurnishingCatalogShoppingList
---@param itemId integer
---@return boolean added false when the item was on the list already
function ShoppingUtils.Add(list, itemId)
    if ShoppingUtils.IndexOf(list, itemId) then
        return false
    end
    list.items[#list.items + 1] = itemId
    return true
end

---@param list FurnishingCatalogShoppingList
---@param itemId integer
---@return boolean removed
function ShoppingUtils.Remove(list, itemId)
    local index = ShoppingUtils.IndexOf(list, itemId)
    if not index then
        return false
    end
    table.remove(list.items, index)
    return true
end

---The lists in the order the "add to" prompt offers them: the one used last first, then the
---rest as created.
---@param store FurnishingCatalogShoppingStore
---@return FurnishingCatalogShoppingList[]
function ShoppingUtils.OfferOrder(store)
    local ordered = {}
    local lastUsed = ShoppingUtils.Find(store, store.lastUsedId)
    if lastUsed then
        ordered[1] = lastUsed
    end
    for _, list in ipairs(store.lists) do
        if list ~= lastUsed then
            ordered[#ordered + 1] = list
        end
    end
    return ordered
end

FC.ShoppingUtils = ShoppingUtils
