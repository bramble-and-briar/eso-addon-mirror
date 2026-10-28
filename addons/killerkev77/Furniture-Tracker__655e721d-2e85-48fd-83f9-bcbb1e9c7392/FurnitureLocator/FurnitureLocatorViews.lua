--[[
Furniture Locator - Views (v13)

Every screen is a LibConsoleDialogs dialog, so A selects and B goes back on
every screen. The old custom list screen (FurnitureLocatorScreen) is gone:
its buttons never worked because it wasn't one of the game's own screens.

  Home
    Continue            -> reopens your last list
    Search by name      -> typed search (TEST: needs the console keyboard)
    Jump to letter      -> A-Z, empty letters hidden
    Browse by category  -> categories -> list
    Browse by location  -> houses / storage / characters' bags -> list
    Browse by style     -> styles -> list
  List   (one dialog per page of PAGE_SIZE items)
    Style filter (dropdown, category lists only), Previous / Next page,
    one row per item: icon, name, total count. Highlighting a row shows
    where it is in the side tooltip; A opens the item's details.
  Details
    every location with counts, and how old each house count is.

FurnitureLocatorDialogs.ShowCategoryDialog is kept as a name (the Quickslot
Wheel entry and the keybind call it) and now opens Home.
]]

FurnitureLocatorDialogs = FurnitureLocatorDialogs or {}
local this = FurnitureLocatorDialogs

ZO_CreateStringId("SI_BINDING_NAME_FURNITURE_LOCATOR_TOGGLE", "Open Furniture Locator")

local PAGE_SIZE = 40
local ALL_STYLES = "All styles"

local ST -- LibHarvensAddonSettings setting types, set on first use

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function Items()
    return FurnitureLocator.GetAllOwnedItems()
end

local function TotalCount(item)
    local total = 0
    for _, loc in ipairs(item.locations) do
        total = total + loc.count
    end
    return total
end

local function Icon(item, size)
    if item.icon and item.icon ~= "" then
        return zo_iconFormat(item.icon, size or 32, size or 32) .. " "
    end
    return ""
end

local function Ago(timestamp)
    if not timestamp then return nil end
    local seconds = GetTimeStamp() - timestamp
    if seconds < 0 then seconds = 0 end
    local days = math.floor(seconds / 86400)
    if days == 0 then return "today" end
    if days == 1 then return "yesterday" end
    if days < 14 then return string.format("%d days ago", days) end
    return string.format("%d weeks ago", math.floor(days / 7))
end

local function LocationsText(item)
    local lines = {}
    local oldestHouse = nil
    for _, loc in ipairs(item.locations) do
        lines[#lines + 1] = string.format("%d in %s", loc.count, loc.name)
        if loc.type == "House" and loc.lastScanned and (not oldestHouse or loc.lastScanned < oldestHouse) then
            oldestHouse = loc.lastScanned
        end
    end
    if oldestHouse then
        lines[#lines + 1] = "|c9e9a8eHouse counts from your last visit, " .. Ago(oldestHouse) .. "|r"
    end
    return table.concat(lines, "\n")
end

local function Dialog(title)
    ST = ST or LibHarvensAddonSettings
    return LibConsoleDialogs:Create(title)
end

local function Button(dialog, label, tooltip, handler)
    dialog:AddSetting({
        type = ST.ST_BUTTON,
        label = label,
        buttonText = "Open",
        tooltip = tooltip,
        clickHandler = handler,
    })
end

local function Section(dialog, label)
    dialog:AddSetting({ type = ST.ST_SECTION, label = label })
end

local function Guard(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            d("Furniture Locator: " .. name .. " ERROR: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Lists. A "spec" describes what a list shows, so it can be reopened from
-- Continue: { kind = "category"|"location"|"style"|"letter"|"search", value, style }
-- ---------------------------------------------------------------------------

local function Matches(item, spec)
    local kind, value = spec.kind, spec.value
    if kind == "category" then
        if item.category ~= value then return false end
        return spec.style == nil or item.theme == spec.style
    elseif kind == "style" then
        return item.theme == value
    elseif kind == "letter" then
        local first = zo_strupper(string.sub(tostring(item.name), 1, 1))
        return first == value
    elseif kind == "search" then
        return string.find(zo_strlower(tostring(item.name)), zo_strlower(value), 1, true) ~= nil
    elseif kind == "location" then
        for _, loc in ipairs(item.locations) do
            if loc.key == value then return true end
        end
        return false
    end
    return false
end

local function SpecTitle(spec)
    if spec.kind == "category" then
        return spec.value .. (spec.style and (" - " .. spec.style) or "")
    elseif spec.kind == "letter" then
        return "Starting with " .. spec.value
    elseif spec.kind == "search" then
        return "Search: " .. spec.value
    end
    return spec.label or tostring(spec.value)
end

local ShowList, ShowDetails -- forward declarations

ShowDetails = Guard("details", function(item)
    local dialog = Dialog(item.name)
    dialog:AddSetting({
        type = ST.ST_LABEL,
        label = string.format("%s%s\n%s · %s · you own %d", Icon(item, 48), item.name, item.category, item.theme, TotalCount(item)),
    })
    Section(dialog, "Where they are")
    for _, loc in ipairs(item.locations) do
        local text = string.format("%d in %s", loc.count, loc.name)
        if loc.type == "House" and loc.lastScanned then
            text = text .. "  |c9e9a8e(visited " .. Ago(loc.lastScanned) .. ")|r"
        end
        dialog:AddSetting({ type = ST.ST_LABEL, label = text })
    end
    dialog:Show()
end)

ShowList = Guard("list", function(spec, page)
    page = page or 1
    FurnitureLocator.settings.lastList = { kind = spec.kind, value = spec.value, style = spec.style, label = spec.label }

    local all = Items()
    local matches = {}
    local styles, styleSeen = {}, {}
    for _, item in ipairs(all) do
        if spec.kind == "category" and item.category == spec.value and not styleSeen[item.theme] then
            styleSeen[item.theme] = true
            styles[#styles + 1] = item.theme
        end
        if Matches(item, spec) then
            matches[#matches + 1] = item
        end
    end
    table.sort(styles)

    local pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
    if page > pages then page = pages end
    local title = SpecTitle(spec)
    if pages > 1 then
        title = string.format("%s (%d/%d)", title, page, pages)
    end
    local dialog = Dialog(title)

    if spec.kind == "category" and #styles > 1 then
        local choices = { ALL_STYLES }
        for _, s in ipairs(styles) do choices[#choices + 1] = s end
        dialog:AddSetting({
            type = ST.ST_DROPDOWN,
            label = "Style",
            tooltip = "Show only one style within this category.",
            items = (function()
                local list = {}
                for _, name in ipairs(choices) do list[#list + 1] = { name = name, data = name } end
                return list
            end)(),
            getFunction = function() return spec.style or ALL_STYLES end,
            setFunction = function(_, name)
                local newStyle = (name ~= ALL_STYLES) and name or nil
                if newStyle ~= spec.style then
                    LibConsoleDialogs:Close()
                    zo_callLater(function()
                        ShowList({ kind = "category", value = spec.value, style = newStyle }, 1)
                    end, 100)
                end
            end,
            default = ALL_STYLES,
        })
    end

    dialog:AddSetting({
        type = ST.ST_LABEL,
        label = string.format("|c9e9a8e%d item%s · highlight one to see where it is, A for details|r", #matches, #matches == 1 and "" or "s"),
    })

    if page > 1 then
        Button(dialog, "< Previous page", nil, function()
            LibConsoleDialogs:Close()
            zo_callLater(function() ShowList(spec, page - 1) end, 100)
        end)
    end

    local first = (page - 1) * PAGE_SIZE + 1
    local last = math.min(page * PAGE_SIZE, #matches)
    for i = first, last do
        local item = matches[i]
        Button(dialog,
            string.format("%s%s  |c9e9a8e×%d|r", Icon(item), item.name, TotalCount(item)),
            LocationsText(item),
            function() ShowDetails(item) end)
    end

    if page < pages then
        Button(dialog, "Next page >", nil, function()
            LibConsoleDialogs:Close()
            zo_callLater(function() ShowList(spec, page + 1) end, 100)
        end)
    end

    dialog:Show()
end)

-- ---------------------------------------------------------------------------
-- Pickers
-- ---------------------------------------------------------------------------

local function CountBy(field)
    local counts, names = {}, {}
    for _, item in ipairs(Items()) do
        local key = item[field]
        if not counts[key] then names[#names + 1] = key end
        counts[key] = (counts[key] or 0) + 1
    end
    table.sort(names)
    return names, counts
end

local ShowCategories = Guard("categories", function()
    local names, counts = CountBy("category")
    local dialog = Dialog("Browse by category")
    for _, name in ipairs(names) do
        local captured = name
        Button(dialog, string.format("%s  |c9e9a8e%d|r", name, counts[name]), nil, function()
            ShowList({ kind = "category", value = captured })
        end)
    end
    dialog:Show()
end)

local ShowStyles = Guard("styles", function()
    local names, counts = CountBy("theme")
    local dialog = Dialog("Browse by style")
    for _, name in ipairs(names) do
        local captured = name
        Button(dialog, string.format("%s  |c9e9a8e%d|r", name, counts[name]), nil, function()
            ShowList({ kind = "style", value = captured })
        end)
    end
    dialog:Show()
end)

local ShowLetters = Guard("letters", function()
    local counts = {}
    for _, item in ipairs(Items()) do
        local first = zo_strupper(string.sub(tostring(item.name), 1, 1))
        counts[first] = (counts[first] or 0) + 1
    end
    local letters = {}
    for letter in pairs(counts) do letters[#letters + 1] = letter end
    table.sort(letters)
    local dialog = Dialog("Jump to letter")
    for _, letter in ipairs(letters) do
        local captured = letter
        Button(dialog, string.format("%s  |c9e9a8e%d|r", letter, counts[letter]), nil, function()
            ShowList({ kind = "letter", value = captured })
        end)
    end
    dialog:Show()
end)

local ShowLocations = Guard("locations", function()
    local groups = FurnitureLocator.GetLocationGroups()
    local dialog = Dialog("Browse by location")
    for _, group in ipairs(groups) do
        if #group.entries > 0 then
            Section(dialog, group.name)
            for _, entry in ipairs(group.entries) do
                local captured = entry
                local label = string.format("%s  |c9e9a8e%d|r", entry.name, entry.count)
                local tooltip = entry.lastScanned and ("Last visited " .. Ago(entry.lastScanned)) or nil
                Button(dialog, label, tooltip, function()
                    ShowList({ kind = "location", value = captured.key, label = captured.name })
                end)
            end
        end
    end
    dialog:Show()
end)

-- ---------------------------------------------------------------------------
-- Home
-- ---------------------------------------------------------------------------

local searchText = ""

function this.ShowHome()
    Guard("home", function()
        local all = Items()
        local dialog = Dialog(string.format("Furniture Locator - %d furnishings", #all))

        local last = FurnitureLocator.settings.lastList
        if last and last.kind then
            Section(dialog, "Continue")
            Button(dialog, SpecTitle(last), "Reopen the list you were last looking at.", function()
                ShowList(last)
            end)
        end

        Section(dialog, "Find")
        -- TEST: typed search. If the console keyboard opens and accepts text here,
        -- this stays; if not, Jump to letter below is the fallback.
        dialog:AddSetting({
            type = ST.ST_EDIT,
            label = "Search by name",
            tooltip = "Type part of a name, then confirm. (Test: needs the console on-screen keyboard.)",
            getFunction = function() return searchText end,
            setFunction = function(value)
                searchText = value or ""
                if searchText ~= "" then
                    zo_callLater(function() ShowList({ kind = "search", value = searchText }) end, 100)
                end
            end,
            default = "",
        })
        Button(dialog, "Jump to letter", "Pick the first letter of the furnishing's name.", ShowLetters)
        Button(dialog, "Browse by category", nil, ShowCategories)
        Button(dialog, "Browse by location", "Houses, storage, vault, bank and each character's bags.", ShowLocations)
        Button(dialog, "Browse by style", nil, ShowStyles)

        dialog:Show()
    end)()
end

-- Kept for the Quickslot Wheel entry and the keybind
this.ShowCategoryDialog = this.ShowHome
