-- Organizer: a catalog of everything you own, a cleanup report, and a stack button at the bank.
--
-- Catalog: the game only lets an add-on read a character's bags while you're on that character, and
-- a house chest while it's open, so each is recorded when you're there and shows when it was last seen.
-- The bank and craft bag can be read from anywhere.
--
-- Report: Settings > Add-Ons > Quartermaster > Open item report. It only suggests. Locked items,
-- things your characters crafted, gear with a kept trait and what you're wearing are never suggested.
--
-- Stack: at the bank, on the Withdraw tab, X stacks the bank. Nothing is moved between bags, sold,
-- deleted, opened or bound.

ESOC_Organizer = ESOC_Organizer or {}
local Org = ESOC_Organizer

local MAX_LINES_PER_SECTION = 30
local LINES_PER_PAGE = 16
local SCENE_NAME = "ESOCQuartermasterReport"

local catalog

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    return nil
end

local function say(text) pcall(d, "[Quartermaster] " .. text) end

local function plain(name)
    local ok, result = pcall(zo_strformat, "<<1>>", name or "")
    return ok and result or tostring(name or "")
end

---------------------------------------------------------------------------
-- What is this item?
---------------------------------------------------------------------------
local function typeIs(itemType, ...)
    for _, name in ipairs({ ... }) do
        local value = _G[name]
        if value ~= nil and itemType == value then return true end
    end
    return false
end

local function classify(bag, slot, link, itemType)
    if typeIs(itemType, "ITEMTYPE_CONTAINER", "ITEMTYPE_CONTAINER_CURRENCY", "ITEMTYPE_CONTAINER_STACKABLE") then
        local QM = ESOC_Quartermaster
        local kind = QM and QM.ContainerKind and safe(QM.ContainerKind, bag, slot)
        if kind == "worthy" or kind == "gear" or kind == "writ" then return "saved" end
        return "container"
    end
    if safe(CanItemBeVirtual, bag, slot) then return "material" end
    if safe(IsItemLinkSetCollectionPiece, link) then return "set" end
    if typeIs(itemType, "ITEMTYPE_ARMOR", "ITEMTYPE_WEAPON") then return "gear" end
    if typeIs(itemType, "ITEMTYPE_RACIAL_STYLE_MOTIF") then return "motif" end
    if typeIs(itemType, "ITEMTYPE_RECIPE") then return "recipe" end
    if typeIs(itemType, "ITEMTYPE_TRASH", "ITEMTYPE_TREASURE") then return "clutter" end
    return "other"
end

-- Things the report must never suggest getting rid of.
local function isKept(bag, slot)
    if safe(IsItemPlayerLocked, bag, slot) then return true end
    local creator = safe(GetItemCreatorName, bag, slot)
    if creator and creator ~= "" then return true end
    if safe(IsItemFromCrownStore, bag, slot) or safe(IsItemFromCrownCrate, bag, slot) then return true end
    local QM = ESOC_Quartermaster
    local options = QM and QM.Options and safe(QM.Options)
    local trait = safe(GetItemTrait, bag, slot)
    if options and options.keepTraits and trait then
        for constant, wanted in pairs(options.keepTraits) do
            if wanted and _G[constant] == trait then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Catalog
---------------------------------------------------------------------------
local function addRow(rows, bag, slot)
    local id = safe(GetItemId, bag, slot) or 0
    if id == 0 then return end
    local _, count = safe(GetItemInfo, bag, slot)
    if not count or count < 1 then return end
    local link = safe(GetItemLink, bag, slot) or ""
    local itemType = safe(GetItemType, bag, slot)
    local key = id .. "_" .. (safe(GetItemTrait, bag, slot) or 0) .. (isKept(bag, slot) and "K" or "")
    rows[key] = (rows[key] or 0) + count
    if not catalog.defs[key] then
        local category = bag == BAG_VIRTUAL and "material" or classify(bag, slot, link, itemType)
        catalog.defs[key] = plain(safe(GetItemName, bag, slot)) .. "\t" .. category
    end
end

local function encode(rows)
    local parts = {}
    for key, count in pairs(rows) do parts[#parts + 1] = key .. "*" .. count end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function decode(text)
    local rows = {}
    for key, count in string.gmatch(text or "", "([^;*]+)%*(%d+)") do rows[key] = tonumber(count) end
    return rows
end

local function store(key, kind, name, rows)
    catalog.locs[key] = { kind = kind, name = name, seen = safe(GetTimeStamp) or 0, items = encode(rows) }
end

local function scanBag(key, kind, name, bag)
    local rows = {}
    for slot = 0, (safe(GetBagSize, bag) or 0) - 1 do addRow(rows, bag, slot) end
    store(key, kind, name, rows)
end

local function scanCraftBag()
    if not BAG_VIRTUAL or type(GetNextVirtualBagSlotId) ~= "function" then return end
    local rows = {}
    local slot = safe(GetNextVirtualBagSlotId, nil)
    while slot do
        addRow(rows, BAG_VIRTUAL, slot)
        slot = safe(GetNextVirtualBagSlotId, slot)
    end
    store("craft", "craft", "Craft bag", rows)
end

local function characterName()
    return plain(safe(GetUnitName, "player") or "This character")
end

function Org.ScanCharacter()
    if not catalog then return end
    local id = tostring(safe(GetCurrentCharacterId) or characterName())
    scanBag("bag:" .. id, "backpack", characterName(), BAG_BACKPACK)
    if BAG_WORN then scanBag("worn:" .. id, "worn", characterName() .. " (worn)", BAG_WORN) end
end

function Org.ScanShared()
    if not catalog then return end
    if BAG_BANK then scanBag("bank", "bank", "Bank", BAG_BANK) end
    if BAG_SUBSCRIBER_BANK then scanBag("plusbank", "bank", "ESO Plus bank", BAG_SUBSCRIBER_BANK) end
    scanCraftBag()
end

function Org.ScanChest(bag)
    if not catalog or not bag or not safe(IsHouseBankBag, bag) then return end
    local name
    local collectibleId = safe(GetCollectibleForHouseBankBag, bag)
    if collectibleId and collectibleId ~= 0 then
        local nickname = safe(GetCollectibleNickname, collectibleId)
        name = (nickname and nickname ~= "") and nickname or safe(GetCollectibleName, collectibleId)
    end
    if not name or name == "" then name = "House chest " .. (bag - (BAG_HOUSE_BANK_ONE or 0) + 1) end
    scanBag("chest:" .. bag, "chest", plain(name), bag)
end

function Org.ScanAll()
    pcall(Org.ScanCharacter)
    pcall(Org.ScanShared)
end

---------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------
local function genericLink(id)
    return "|H1:item:" .. id .. ":1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

local function dateText(stamp)
    if not stamp or stamp == 0 then return "never" end
    local now = safe(GetTimeStamp) or stamp
    local days = math.floor((now - stamp) / 86400)
    if days <= 0 then return "today" end
    if days == 1 then return "yesterday" end
    return days .. " days ago"
end

local function section(out, title, lines)
    if #lines == 0 then return end
    table.sort(lines)
    out[#out + 1] = ""
    out[#out + 1] = title .. " (" .. #lines .. ")"
    for index = 1, math.min(#lines, MAX_LINES_PER_SECTION) do out[#out + 1] = "  " .. lines[index] end
    if #lines > MAX_LINES_PER_SECTION then
        out[#out + 1] = "  ...and " .. (#lines - MAX_LINES_PER_SECTION) .. " more"
    end
end

local function placesText(places)
    local names = {}
    for _, place in ipairs(places) do names[#names + 1] = place.name .. " x" .. place.count end
    table.sort(names)
    return table.concat(names, ", ")
end

-- Pulls the catalog together: one entry per item, with every place it is.
function Org.Summary()
    local items = {}
    for _, loc in pairs(catalog and catalog.locs or {}) do
        for key, count in pairs(decode(loc.items)) do
            local def = catalog.defs[key] or "Unknown item\tother"
            local name, category = string.match(def, "^(.-)\t(.*)$")
            local entry = items[key]
            if not entry then
                entry = { key = key, id = tonumber(string.match(key, "^(%d+)")), name = name, category = category,
                    kept = string.sub(key, -1) == "K", total = 0, places = {}, worn = false }
                items[key] = entry
            end
            entry.total = entry.total + count
            entry.places[#entry.places + 1] = { name = loc.name, kind = loc.kind, count = count }
            if loc.kind == "worn" then entry.worn = true end
        end
    end
    local result = { spread = {}, collected = {}, learnable = {}, clutter = {}, saved = {} }
    for _, entry in pairs(items) do
        local line = entry.name .. ": " .. placesText(entry.places)
        if entry.category == "saved" then result.saved[#result.saved + 1] = line end
        if not entry.kept and not entry.worn then
            if entry.category ~= "material" then
                if #entry.places > 1 and entry.category ~= "saved" then result.spread[#result.spread + 1] = line end
                if entry.category == "set" and safe(IsItemSetCollectionPieceUnlocked, entry.id) then
                    result.collected[#result.collected + 1] = line
                elseif entry.category == "motif" and safe(IsItemLinkBookKnown, genericLink(entry.id)) == false then
                    result.learnable[#result.learnable + 1] = line
                elseif entry.category == "recipe" and safe(IsItemLinkRecipeKnown, genericLink(entry.id)) == false then
                    result.learnable[#result.learnable + 1] = line
                elseif entry.category == "clutter" then
                    result.clutter[#result.clutter + 1] = line
                end
            end
        end
    end
    return result
end

function Org.MissingCharacters()
    local seen, missing = {}, {}
    for key, loc in pairs(catalog and catalog.locs or {}) do
        if string.sub(key, 1, 4) == "bag:" then seen[loc.name] = true end
    end
    for index = 1, safe(GetNumCharacters) or 0 do
        local name = plain((safe(GetCharacterInfo, index)))
        if name ~= "" and not seen[name] then missing[#missing + 1] = name end
    end
    table.sort(missing)
    return missing
end

function Org.ReportText()
    Org.ScanAll()
    local out = { "Where your items are" }
    local locations = {}
    for _, loc in pairs(catalog.locs) do
        local kinds, stacks = 0, 0
        for _, count in pairs(decode(loc.items)) do kinds = kinds + 1; stacks = stacks + count end
        locations[#locations + 1] = string.format("  %s: %d kinds, %d items, seen %s", loc.name, kinds, stacks, dateText(loc.seen))
    end
    table.sort(locations)
    for _, line in ipairs(locations) do out[#out + 1] = line end
    local missing = Org.MissingCharacters()
    if #missing > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "Not cataloged yet (log in once): " .. table.concat(missing, ", ")
    end
    local summary = Org.Summary()
    section(out, "Can be learned by this character", summary.learnable)
    section(out, "Already in your Sticker Book: keep, sell or deconstruct", summary.collected)
    section(out, "Same item in several places", summary.spread)
    section(out, "Clutter worth selling", summary.clutter)
    section(out, "Saved coffers (open one a day where they apply)", summary.saved)
    out[#out + 1] = ""
    out[#out + 1] = "Locked, crafted, kept-trait and worn items are never suggested."
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Report screen (large text, LB and RB turn the page)
---------------------------------------------------------------------------
local scene, titleLabel, bodyLabel, pageLabel, keybinds
local pages, pageIndex = { "" }, 1

function Org.Paginate(text, perPage)
    perPage = perPage or LINES_PER_PAGE
    local result, current = {}, {}
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        if #current >= perPage then
            result[#result + 1] = table.concat(current, "\n")
            current = {}
        end
        if #current > 0 or line ~= "" then current[#current + 1] = line end
    end
    if #current > 0 then result[#result + 1] = table.concat(current, "\n") end
    if #result == 0 then result[1] = "" end
    return result
end

local function showPage()
    if not bodyLabel then return end
    pageIndex = math.max(1, math.min(pageIndex, #pages))
    bodyLabel:SetText(pages[pageIndex])
    pageLabel:SetText("Page " .. pageIndex .. " of " .. #pages)
    if keybinds then pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds) end) end
end

local function createScene()
    local WIDTH, HEIGHT, PADDING = 1640, 850, 30
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCQuartermasterReportWindow")
    window:SetDimensions(WIDTH, HEIGHT)
    window:SetAnchor(TOP, GuiRoot, TOP, 0, 60)
    window:SetHidden(true)
    local background = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    background:SetAnchorFill(window)
    background:SetColor(0, 0, 0, 0.88)
    titleLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    titleLabel:SetFont("ZoFontGamepad42")
    titleLabel:SetColor(0.95, 0.8, 0.4, 1)
    titleLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 18)
    titleLabel:SetText("Quartermaster: Your Items")
    pageLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    pageLabel:SetFont("ZoFontGamepad34")
    pageLabel:SetColor(0.8, 0.8, 0.8, 1)
    pageLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PADDING, 24)
    bodyLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    bodyLabel:SetFont("ZoFontGamepad34")
    bodyLabel:SetColor(0.96, 0.94, 0.86, 1)
    bodyLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 90)
    bodyLabel:SetDimensions(WIDTH - PADDING * 2, HEIGHT - 110)
    bodyLabel:SetMaxLineCount(LINES_PER_PAGE)
    bodyLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(ZO_SimpleSceneFragment:New(window))
    keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
        { name = "Previous page", keybind = "UI_SHORTCUT_LEFT_SHOULDER",
          visible = function() return pageIndex > 1 end,
          callback = function() pageIndex = pageIndex - 1; showPage() end },
        { name = "Next page", keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
          visible = function() return pageIndex < #pages end,
          callback = function() pageIndex = pageIndex + 1; showPage() end },
    }
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
            showPage()
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
        end
    end)
end

function Org.OpenReport()
    local ok, text = pcall(Org.ReportText)
    if not ok then return say("couldn't build the item report: " .. tostring(text)) end
    pages, pageIndex = Org.Paginate(text), 1
    pcall(function() SCENE_MANAGER:ShowBaseScene() end)
    zo_callLater(function()
        local shown, err = pcall(function()
            if not scene then createScene() end
            SCENE_MANAGER:Show(SCENE_NAME)
        end)
        if not shown then say("couldn't open the item report: " .. tostring(err)) end
    end, 300)
end

---------------------------------------------------------------------------
-- Stack at the bank
---------------------------------------------------------------------------
-- Items are never moved between bags. ESO Plus already sends materials to the craft bag, Gold Digger
-- takes some back out to sell, and some coffers can't leave the character.
function Org.ButtonName()
    return "Stack bank"
end

function Org.PressTidy()
    if BAG_BANK then pcall(StackBag, BAG_BANK) end
    if BAG_SUBSCRIBER_BANK then pcall(StackBag, BAG_SUBSCRIBER_BANK) end
    say("Bank stacked.")
    zo_callLater(function() pcall(Org.ScanAll) end, 1000)
end

function Org.SetButtonCallback() end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
function Org.Init(saved)
    saved.catalog = saved.catalog or { version = 1, defs = {}, locs = {} }
    catalog = saved.catalog
    if not EVENT_MANAGER then return end
    local name = "ESOC_QuartermasterOrganizer"
    local openChest
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
            zo_callLater(function() pcall(Org.ScanAll) end, 3000)
        end)
    end
    if EVENT_OPEN_BANK then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_BANK, function(_, bag)
            bag = bag or safe(GetBankingBag)
            if bag and safe(IsHouseBankBag, bag) then
                openChest = bag
                pcall(Org.ScanChest, bag)
            end
        end)
    end
    if EVENT_CLOSE_BANK then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_BANK, function()
            if openChest then pcall(Org.ScanChest, openChest) end
            openChest = nil
            pcall(Org.ScanAll)
        end)
    end
end
