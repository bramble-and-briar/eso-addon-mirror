-- FurnishingCatalogBrowseUtils.lua: pure helpers for the catalog screen (no game calls).
local FC = FurnishingCatalog

local BrowseUtils = {}

-- The group mode (the Sort button): the order of the furnishings within each subcategory of a
-- long list, and what an expanded long list cuts each subcategory by ("Doorways - Orc").
-- "plan" reads the built-in list of plans; the rest read the game.
BrowseUtils.GROUP_MODES = { "name", "style", "quality", "plan" }
BrowseUtils.DEFAULT_GROUP_MODE = "name"

local GROUP_MODE_LABELS = {
    name = "A-Z",
    style = "Style",
    quality = "Quality",
    plan = "Plan",
}

---@param mode any
---@return boolean
function BrowseUtils.IsGroupMode(mode)
    for _, candidate in ipairs(BrowseUtils.GROUP_MODES) do
        if candidate == mode then
            return true
        end
    end
    return false
end

---@param mode any a saved mode, possibly one an earlier version offered
---@return string mode a mode on offer
function BrowseUtils.ValidGroupMode(mode)
    if BrowseUtils.IsGroupMode(mode) then
        return mode
    end
    return BrowseUtils.DEFAULT_GROUP_MODE
end

---@param mode string
---@return string
function BrowseUtils.GroupModeLabel(mode)
    return GROUP_MODE_LABELS[mode] or GROUP_MODE_LABELS[BrowseUtils.DEFAULT_GROUP_MODE]
end

---@param mode string
---@return string next mode in the cycle
function BrowseUtils.NextGroupMode(mode)
    local modes = BrowseUtils.GROUP_MODES
    for index, candidate in ipairs(modes) do
        if candidate == mode then
            return modes[index % #modes + 1]
        end
    end
    return BrowseUtils.DEFAULT_GROUP_MODE
end

---The words of a search, from text that is already lower-case. All of them have to appear in a
---name for it to match, in any order.
---@param loweredText string|nil
---@return string[]|nil words nil when the text holds none
function BrowseUtils.SearchWords(loweredText)
    local words = {}
    for word in string.gmatch(loweredText or "", "%S+") do
        words[#words + 1] = word
    end
    if #words == 0 then
        return nil
    end
    return words
end

---@param loweredName string
---@param words string[]
---@return boolean
function BrowseUtils.MatchesAll(loweredName, words)
    for _, word in ipairs(words) do
        if not string.find(loweredName, word, 1, true) then
            return false
        end
    end
    return true
end

---Section title for the A-Z mode: the name's first letter, "#" for anything that is not one.
---A multi-byte (UTF-8) first character is kept whole.
---@param name string
---@return string
function BrowseUtils.FirstLetter(name)
    local byte = name and string.byte(name, 1)
    if not byte then
        return "#"
    end
    if byte < 0x80 then
        local letter = string.upper(string.char(byte))
        if letter:match("%a") then
            return letter
        end
        return "#"
    end
    local length = byte >= 0xF0 and 4 or byte >= 0xE0 and 3 or byte >= 0xC0 and 2 or 1
    return string.sub(name, 1, length)
end

---Section order: quality best first, plan by its state (not known, known, none); the rest by title.
---@param item FurnishingCatalogItem
---@param mode string
---@return number
local function GroupOrder(item, mode)
    if mode == "quality" then
        return -(item.quality or 0)
    elseif mode == "plan" then
        return item.planState or 0
    end
    return 0
end

---By the mode's group (its order, then its title), then by name.
local function CompareItems(a, b)
    if a.groupOrder ~= b.groupOrder then
        return a.groupOrder < b.groupOrder
    end
    if a.groupName ~= b.groupName then
        return a.groupName < b.groupName
    end
    if a.sortName ~= b.sortName then
        return a.sortName < b.sortName
    end
    return a.id < b.id
end

---By the section an item came with (its subcategory), then as CompareItems.
local function CompareItemsBySection(a, b)
    if a.sectionIndex ~= b.sectionIndex then
        return a.sectionIndex < b.sectionIndex
    end
    return CompareItems(a, b)
end

---The key of the mode's group an item falls in (after BrowseUtils.Arrange).
---@param item FurnishingCatalogItem
---@return string
function BrowseUtils.GroupKey(item)
    return tostring(item.groupOrder) .. ":" .. tostring(item.groupName)
end

-- How far a long list is expanded:
--   PLAIN - a header per section (subcategory): "Doorways";
--   FINE  - each section cut by the mode's groups: "Doorways - Orc";
--   FLAT  - no headers and no sections: one list in the mode's order.
BrowseUtils.DETAIL_PLAIN = 0
BrowseUtils.DETAIL_FINE = 1
BrowseUtils.DETAIL_FLAT = 2

---Order the items of a long list (in place) and give the first item under each header its
---header. PLAIN and FINE go by the section each item came with, then by the mode's group, then
---by name; FLAT by the mode's group, then by name, across the whole list.
---@param items FurnishingCatalogItem[] each with its sectionIndex and sectionName
---@param mode string a group mode (the caller has checked it is on offer)
---@param groupNameOf fun(item: FurnishingCatalogItem, mode: string): string|nil group title for every mode but A-Z
---@param detail integer a BrowseUtils.DETAIL_*
---@return FurnishingCatalogItem[] items the same table, sorted
---@return integer numHeaders
function BrowseUtils.Arrange(items, mode, groupNameOf, detail)
    mode = BrowseUtils.ValidGroupMode(mode)
    for _, item in ipairs(items) do
        local groupName
        if mode == "name" then
            groupName = BrowseUtils.FirstLetter(item.sortName)
        else
            groupName = groupNameOf(item, mode)
        end
        if groupName == nil or groupName == "" then
            groupName = "Other"
        end
        item.groupName = groupName
        item.groupOrder = GroupOrder(item, mode)
    end
    local flat = detail == BrowseUtils.DETAIL_FLAT
    local fine = detail == BrowseUtils.DETAIL_FINE
    table.sort(items, flat and CompareItems or CompareItemsBySection)
    local numHeaders = 0
    local previousIndex, previousGroup = nil, nil
    for _, item in ipairs(items) do
        local group = fine and BrowseUtils.GroupKey(item) or nil
        if not flat and (item.sectionIndex ~= previousIndex or group ~= previousGroup) then
            item.header = fine and (item.sectionName .. " - " .. item.groupName) or item.sectionName
            numHeaders = numHeaders + 1
        else
            item.header = nil
        end
        previousIndex, previousGroup = item.sectionIndex, group
    end
    return items, numHeaders
end

---What to remember of the row the cursor is on. On a row inside a folder: the row and its
---folder. On a folder's own row: the folder, and the row remembered inside it, if any, so that
---folding and unfolding again returns to that row.
---@param anchor { rowKey: any, folderKey: any }|nil what was remembered so far
---@param row { rowKey: any, folderKey: any } the row the cursor is on
---@return { rowKey: any, folderKey: any }
function BrowseUtils.NextAnchor(anchor, row)
    if row.rowKey ~= row.folderKey then
        return { rowKey = row.rowKey, folderKey = row.folderKey }
    end
    if anchor and anchor.folderKey == row.folderKey then
        return anchor
    end
    return { rowKey = nil, folderKey = row.folderKey }
end

---Where the cursor goes in a rebuilt list: on the row it was on, else on the first row of the
---folder it was in, else nil (the caller's default).
---@param rows { rowKey: any, folderKey: any }[] one per row: what the row is, and the folder it is or is in
---@param anchor { rowKey: any, folderKey: any }|nil what the cursor was on
---@return integer|nil index
function BrowseUtils.AnchorIndex(rows, anchor)
    if not anchor then
        return nil
    end
    local folderIndex = nil
    for index, row in ipairs(rows) do
        if anchor.rowKey ~= nil and row.rowKey == anchor.rowKey then
            return index
        end
        if not folderIndex and anchor.folderKey ~= nil and row.folderKey == anchor.folderKey then
            folderIndex = index
        end
    end
    return folderIndex
end

---@param items FurnishingCatalogItem[]
---@param itemId integer|nil
---@return integer|nil index
function BrowseUtils.IndexOfId(items, itemId)
    if itemId == nil then
        return nil
    end
    for index, item in ipairs(items) do
        if item.id == itemId then
            return index
        end
    end
    return nil
end

---The name as ESO-Hub writes it in a furnishing's page address: lower case, apostrophes dropped,
---every other run of non-alphanumerics a hyphen ("Hlaalu Desk, Scholar's" -> "hlaalu-desk-scholars").
---The site does not publish the rule; this one found every page it was tried on.
---@param name string|nil
---@return string slug "" when the name holds nothing usable
function BrowseUtils.WebSlug(name)
    local slug = string.lower(tostring(name or ""))
    slug = string.gsub(slug, "'", "")
    slug = string.gsub(slug, "\226\128\153", "") -- the curly apostrophe (U+2019)
    slug = string.gsub(slug, "[^a-z0-9]+", "-")
    slug = string.gsub(slug, "^%-+", "")
    slug = string.gsub(slug, "%-+$", "")
    return slug
end

---Address of a furnishing's page on ESO-Hub: where it comes from, its plan and materials, recent sales.
---@param name string|nil the furnishing's English name
---@return string|nil url nil when the name gives no address
function BrowseUtils.WebUrl(name)
    local slug = BrowseUtils.WebSlug(name)
    if slug == "" then
        return nil
    end
    return "https://eso-hub.com/en/furniture/" .. slug
end

---A chat message with a link added: after what is already written, a space between. A link the
---message already holds is not added twice.
---@param existing string|nil what the message box holds
---@param link string
---@param maxLength integer the most the message box takes
---@return string|nil text the message to put in the box; nil when the link does not fit
function BrowseUtils.ChatText(existing, link, maxLength)
    existing = existing or ""
    if existing:find(link, 1, true) then
        return existing
    end
    local text = link
    if existing ~= "" then
        text = existing .. (existing:find("%s$") and "" or " ") .. link
    end
    if #text > maxLength then
        return nil
    end
    return text
end

---By name, any case; the ones the game gave no name (unnamed) after the named; ties by id.
---@param a { id: any, name: string, unnamed: boolean|nil }
---@param b { id: any, name: string, unnamed: boolean|nil }
---@return boolean
function BrowseUtils.CompareByName(a, b)
    if (a.unnamed == true) ~= (b.unnamed == true) then
        return b.unnamed == true
    end
    local nameA, nameB = string.lower(a.name), string.lower(b.name)
    if nameA ~= nameB then
        return nameA < nameB
    end
    return tostring(a.id) < tostring(b.id)
end

---Sort the categories, and the subcategories of each, alphabetically (in place).
---@param categories FurnishingCatalogCategory[]
---@return FurnishingCatalogCategory[] categories the same table
function BrowseUtils.SortCategories(categories)
    for _, category in ipairs(categories) do
        table.sort(category.subcategories, BrowseUtils.CompareByName)
    end
    table.sort(categories, BrowseUtils.CompareByName)
    return categories
end

---@param name string
---@param count integer
---@return string
function BrowseUtils.CountLabel(name, count)
    return string.format("%s (%d)", tostring(name), count)
end

FC.BrowseUtils = BrowseUtils
