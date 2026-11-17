-- FurnishingCatalogBrowseUtils.lua: pure helpers for the catalog screen (no game calls).
local FC = FurnishingCatalog

local BrowseUtils = {}

-- How the item list of a subcategory is cut into sections. The triggers jump a section at a time.
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

---Sort the items into sections (in place) and mark the first item of each section.
---@param items FurnishingCatalogItem[]
---@param mode string a group mode (the caller has checked it is on offer)
---@param groupNameOf fun(item: FurnishingCatalogItem, mode: string): string|nil section title for every mode but A-Z
---@return FurnishingCatalogItem[] items the same table, sorted
---@return integer numGroups
function BrowseUtils.SortAndGroup(items, mode, groupNameOf)
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
    table.sort(items, CompareItems)
    local numGroups = 0
    local previousName, previousOrder
    for index, item in ipairs(items) do
        local startsGroup = index == 1 or item.groupName ~= previousName or item.groupOrder ~= previousOrder
        item.startsGroup = startsGroup
        if startsGroup then
            numGroups = numGroups + 1
        end
        previousName, previousOrder = item.groupName, item.groupOrder
    end
    return items, numGroups
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

---By name, any case; the ones the game gave no name (unnamed) after the named; ties by id.
local function CompareByName(a, b)
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
        table.sort(category.subcategories, CompareByName)
    end
    table.sort(categories, CompareByName)
    return categories
end

---@param name string
---@param count integer
---@return string
function BrowseUtils.CountLabel(name, count)
    return string.format("%s (%d)", tostring(name), count)
end

---Key under which a subcategory's list position is remembered for a group mode.
---@param categoryId integer
---@param subcategoryId integer
---@param mode string
---@return string
function BrowseUtils.PositionKey(categoryId, subcategoryId, mode)
    return tostring(categoryId) .. ":" .. tostring(subcategoryId) .. ":" .. tostring(mode)
end

FC.BrowseUtils = BrowseUtils
