-- FurnishingCatalogEditorUtils.lua: pure helpers for the shopping-list filter of the housing
-- editor's Place tab (no game calls).
local FC = FurnishingCatalog

local EditorUtils = {}

EditorUtils.BUTTON_NAME = "Shopping Lists"
EditorUtils.SHOW_ALL_LABEL = "All Furnishings"

---The furnishings on a list, as a set of item ids.
---@param list FurnishingCatalogShoppingList
---@return table<integer, boolean>
function EditorUtils.IdSet(list)
    local ids = {}
    for _, itemId in ipairs(list.items) do
        ids[itemId] = true
    end
    return ids
end

---How many of a list's furnishings are among the ones held.
---@param list FurnishingCatalogShoppingList
---@param heldIds table<integer, boolean> item ids of the furnishings the player has to place
---@return integer
function EditorUtils.NumHeld(list, heldIds)
    local numHeld = 0
    for _, itemId in ipairs(list.items) do
        if heldIds[itemId] then
            numHeld = numHeld + 1
        end
    end
    return numHeld
end

---A list's contents as one comparable value: it changes when a furnishing is put on the list
---or taken off it. No list has no signature, which differs from an empty list's.
---@param list FurnishingCatalogShoppingList|nil
---@return string|nil
function EditorUtils.Signature(list)
    if not list then
        return nil
    end
    return table.concat(list.items, ",")
end

---What the button on the Place tab reads: the list being shown, or what it opens.
---@param activeList FurnishingCatalogShoppingList|nil
---@return string
function EditorUtils.ButtonName(activeList)
    if activeList then
        return "List: " .. activeList.name
    end
    return EditorUtils.BUTTON_NAME
end

---The rows of the "show which list" prompt. While a list is being shown the first row shows
---everything again; then the lists as created, each with how many of its furnishings are held.
---@param store FurnishingCatalogShoppingStore
---@param activeListId integer|nil the list being shown
---@param heldIds table<integer, boolean>
---@return { label: string, list: FurnishingCatalogShoppingList|nil, showAll: boolean|nil }[]
function EditorUtils.Rows(store, activeListId, heldIds)
    local rows = {}
    if activeListId then
        rows[#rows + 1] = { label = EditorUtils.SHOW_ALL_LABEL, showAll = true }
    end
    for _, list in ipairs(store.lists) do
        local label = string.format("%s (%d of %d)", list.name, EditorUtils.NumHeld(list, heldIds), #list.items)
        if list.id == activeListId then
            label = label .. "  (showing)"
        end
        rows[#rows + 1] = { label = label, list = list }
    end
    return rows
end

---The test a furnishing has to pass while a list is being shown: it is on the list, and it
---passes whatever test was there already.
---@param listedIds table<integer, boolean>
---@param itemIdOf fun(furniture: any): integer|nil
---@param inner (fun(furniture: any): boolean)|nil
---@return fun(furniture: any): boolean
function EditorUtils.ComposeFilter(listedIds, itemIdOf, inner)
    return function(furniture)
        local itemId = itemIdOf(furniture)
        if not (itemId and listedIds[itemId]) then
            return false
        end
        if inner then
            return inner(furniture)
        end
        return true
    end
end

FC.EditorUtils = EditorUtils
