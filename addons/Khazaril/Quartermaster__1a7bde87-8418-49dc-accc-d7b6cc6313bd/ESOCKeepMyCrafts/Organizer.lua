-- Organizer: a catalog of everything you own, search, a job for each house chest, a cleanup report,
-- and a stack button at the bank.
--
-- Catalog: the game only lets an add-on read a character's bags while you're on that character, and
-- a house chest while it's open, so each is recorded when you're there and shows when it was last seen.
-- The bank and craft bag can be read from anywhere.
--
-- Report: Settings > Add-Ons > Quartermaster > Full Inventory. Surveys ready to run, what your main
-- crafter can learn, what can go, and a page listing each chest. It only suggests. Locked items,
-- things your characters crafted, Armory build pieces, gear with a kept trait and anything worn are
-- never suggested, and gear in a character's bags is never suggested as a Sticker Book spare.
--
-- Search: Settings > Add-Ons > Quartermaster > Search items finds names, sets and traits everywhere.
--
-- Chest plan: off by default, because how you store things is personal. To use it, give your chests
-- these exact names: Surveys, Gear 1, Gear 2, Gear 3, Master Writs, Mythics, Purple Companion, Monster Gear.
-- A panel then shows what doesn't belong in an open chest and where it goes.
--
-- Organize: optional. With the plan on, X at the bank or a named chest sorts it; Settings shows a preview. One character carries
-- items between chests, one press of X per chest. It never sells, deletes, opens or binds anything.
--
-- Stack: at the bank, on the Withdraw tab, X stacks the bank when the chest plan is off.

ESOC_Organizer = ESOC_Organizer or {}
local Org = ESOC_Organizer

local MAX_LINES_PER_SECTION = 30
local LINES_PER_PAGE = 16
local CHARS_PER_LINE = 76
local COLUMN_CHARS = 46 -- the report screens show two columns side by side
local COLUMN_ROWS = 19
local MAX_SEARCH_RESULTS = 60
local MAX_PANEL_LINES = 8
local SURVEY_RUN_AT = 5 -- a zone is worth a trip at this many gold-material surveys
local SCENE_NAME = "ESOCQuartermasterReport"
local SCAN_ITEMS_PER_STEP = 25 -- the Xbox ends an add-on that works for a full second in one frame
local SCAN_GAP_MS = 30

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

local FURNISHING_RECIPES = {
    "SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING", "SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING", "SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING", "SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING",
}

-- "Blacksmith Survey: Craglorn II" gives the craft and the zone (without the number).
local SURVEY_CRAFTS = {
    ["blacksmith"] = { "Blacksmithing", true }, ["clothier"] = { "Clothing", true }, ["woodworker"] = { "Woodworking", true },
    ["jewelry crafting"] = { "Jewelry", true }, ["jewelry crafter"] = { "Jewelry", true },
    ["alchemist"] = { "Alchemy", false }, ["enchanter"] = { "Enchanting", false },
}

function Org.ParseSurvey(name)
    local craftWord, zone = string.match(name or "", "^(.-) Survey: (.+)$")
    local craft = craftWord and SURVEY_CRAFTS[string.lower(craftWord)]
    if not craft then return nil end
    zone = string.gsub(zone, "%s+[IVX]+$", "")
    return craft[1], zone, craft[2]
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
    if typeIs(itemType, "ITEMTYPE_RECIPE") then
        local _, specialized = safe(GetItemType, bag, slot)
        for _, name in ipairs(FURNISHING_RECIPES) do
            if _G[name] ~= nil and specialized == _G[name] then return "plan" end
        end
        return "recipe"
    end
    if typeIs(itemType, "ITEMTYPE_TRASH", "ITEMTYPE_TREASURE") then return "clutter" end
    return "other"
end

function Org.IsUnidentifiedSurvey(name)
    local lowered = string.lower(name or "")
    return string.find(lowered, "unidentified", 1, true) ~= nil and string.find(lowered, "survey", 1, true) ~= nil
end

-- What kind of item this is, for the chest plan.
local function kindOf(bag, slot, link, itemType, specialized, name, category)
    if Org.IsUnidentifiedSurvey(name) then return "unidentifiedSurveys" end
    if SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT ~= nil and specialized == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
        local craft, _, goldMaterials = Org.ParseSurvey(name)
        return (craft and not goldMaterials) and "surveysOther" or "surveysGold"
    end
    if typeIs(itemType, "ITEMTYPE_MASTER_WRIT") then return "masterWrits" end
    local quality = safe(GetItemDisplayQuality, bag, slot)
    if GAMEPLAY_ACTOR_CATEGORY_COMPANION ~= nil and safe(GetItemActorCategory, bag, slot) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        if quality and ITEM_DISPLAY_QUALITY_ARTIFACT and quality >= ITEM_DISPLAY_QUALITY_ARTIFACT then return "companionPurple" end
        return "companionOther"
    end
    if typeIs(itemType, "ITEMTYPE_WEAPON", "ITEMTYPE_ARMOR") then
        if ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE ~= nil and quality == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then return "mythics" end
        -- Anything below level 50 is levelling gear for new characters.
        local level = safe(GetItemLinkRequiredLevel, link)
        if level and level > 0 and level < 50 then return "training" end
        local hasSet, _, _, _, maxEquipped, setId = safe(GetItemLinkSetInfo, link)
        if setId and ITEM_SET_TYPE_MONSTER ~= nil and safe(GetItemSetType, setId) == ITEM_SET_TYPE_MONSTER then return "monster" end
        -- A two-piece set worn on the head or shoulders is a monster set, whatever the game labels it.
        if hasSet and maxEquipped == 2 and typeIs(itemType, "ITEMTYPE_ARMOR") then
            local worn = safe(GetItemLinkEquipType, link)
            if worn ~= nil and (worn == EQUIP_TYPE_HEAD or worn == EQUIP_TYPE_SHOULDERS) then return "monster" end
        end
    end
    if typeIs(itemType, "ITEMTYPE_WEAPON") then return "weapons" end
    if typeIs(itemType, "ITEMTYPE_ARMOR") then
        local equipType = safe(GetItemLinkEquipType, link)
        if equipType ~= nil and (equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING) then return "jewelry" end
        return "armor"
    end
    if category == "plan" then return "plans" end
    if typeIs(itemType, "ITEMTYPE_RACIAL_STYLE_MOTIF", "ITEMTYPE_RECIPE") then return "motifs" end
    if specialized ~= nil and (specialized == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE
        or specialized == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE) then
        return "motifs"
    end
    if typeIs(itemType, "ITEMTYPE_TRASH", "ITEMTYPE_TREASURE") then return "clutter" end
    if typeIs(itemType, "ITEMTYPE_POTION", "ITEMTYPE_POISON") then return "consumables" end
    if typeIs(itemType, "ITEMTYPE_FOOD", "ITEMTYPE_DRINK", "ITEMTYPE_SOUL_GEM", "ITEMTYPE_TOOL") then return "foodTools" end
    if category == "material" then return "materials" end
    if category == "saved" or category == "container" then return "containers" end
    return "other"
end

local function uniqueKey(bag, slot)
    local id = safe(GetItemUniqueId, bag, slot)
    if not id then return nil end
    return safe(Id64ToString, id) or tostring(id)
end

-- Armory builds belong to one character, so each character's pieces are remembered for the others.
local function inAnyArmory(bag, slot)
    if safe(IsItemInArmory, bag, slot) then return true end
    local unique = catalog and catalog.armory and uniqueKey(bag, slot)
    if unique then
        for _, pieces in pairs(catalog.armory) do
            if pieces[unique] then return true end
        end
    end
    return false
end

-- Things the report must never suggest getting rid of.
local function isKept(bag, slot)
    if safe(IsItemPlayerLocked, bag, slot) then return true end
    if inAnyArmory(bag, slot) then return true end
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
-- "Chest", "Ring", "Inferno Staff": how a piece is shown in a Gear chest's list.
local function pieceName(link, itemType)
    if type(GetString) ~= "function" then return "" end
    if typeIs(itemType, "ITEMTYPE_WEAPON") then
        local weapon = safe(GetItemLinkWeaponType, link)
        return weapon and plain(safe(GetString, "SI_WEAPONTYPE", weapon) or "") or ""
    end
    local equip = safe(GetItemLinkEquipType, link)
    return equip and plain(safe(GetString, "SI_EQUIPTYPE", equip) or "") or ""
end

local function addRow(rows, bag, slot)
    local id = safe(GetItemId, bag, slot) or 0
    if id == 0 then return end
    local _, count = safe(GetItemInfo, bag, slot)
    if not count or count < 1 then return end
    local link = safe(GetItemLink, bag, slot) or ""
    local itemType, specialized = safe(GetItemType, bag, slot)
    local trait = safe(GetItemTrait, bag, slot) or 0
    -- Quality is part of the key: the same item can be green or purple. "AK" marks an Armory piece.
    local creator = safe(GetItemCreatorName, bag, slot)
    local suffix = inAnyArmory(bag, slot) and "AK" or ((creator and creator ~= "") and "CK" or (isKept(bag, slot) and "K" or ""))
    local key = id .. "_" .. trait .. "_" .. (safe(GetItemDisplayQuality, bag, slot) or 0) .. suffix
    rows[key] = (rows[key] or 0) + count
    -- Entries from older versions are filled in again when they're next seen.
    local _, tabs = string.gsub(catalog.defs[key] or "", "\t", "")
    if tabs < 8 then -- 8 marks an entry sorted by the current monster gear rule
        local name = plain(safe(GetItemName, bag, slot))
        local category = bag == BAG_VIRTUAL and "material" or classify(bag, slot, link, itemType)
        local _, setName = safe(GetItemLinkSetInfo, link)
        local traitName = ""
        if trait ~= 0 and type(GetString) == "function" then traitName = safe(GetString, "SI_ITEMTRAITTYPE", trait) or "" end
        local home = bag == BAG_VIRTUAL and "materials" or kindOf(bag, slot, link, itemType, specialized, name, category)
        local craft, zone
        if SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT ~= nil and specialized == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
            craft, zone = Org.ParseSurvey(name)
        end
        catalog.defs[key] = table.concat({ name, category, type(setName) == "string" and plain(setName) or "",
            plain(traitName), home, craft or "", zone or "", pieceName(link, itemType), "2" }, "\t")
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

local gearCache = nil
local gearFrozen = false -- where each set goes is decided once per chest visit

local function store(key, kind, name, rows, size)
    if not gearFrozen then gearCache = nil end
    local used = 0
    for _ in pairs(rows) do used = used + 1 end
    catalog.locs[key] = { kind = kind, name = name, seen = safe(GetTimeStamp) or 0, items = encode(rows), size = size, used = used }
end

-- Each saved entry is only taken apart once: the Xbox stops an add-on that works too long in one frame.
local parsedDefs = {}

local function readDef(key)
    local raw = catalog.defs[key] or "Unknown item\tother"
    local def = parsedDefs[raw]
    if def then return def end
    local fields = {}
    for field in string.gmatch(raw .. "\t", "(.-)\t") do fields[#fields + 1] = field end
    local fresh = #fields >= 7 -- older entries don't know the current chest jobs yet
    def = { name = fields[1] or "Unknown item", category = fields[2] or "other", set = fields[3] or "",
        trait = fields[4] or "", home = fresh and fields[5] or nil, craft = fresh and fields[6] or "",
        zone = fresh and fields[7] or "", piece = fields[8] or "", fresh = fresh }
    parsedDefs[raw] = def
    return def
end

---------------------------------------------------------------------------
-- Chest jobs
---------------------------------------------------------------------------
local LEAVE, BANK = "Leave alone", "Bank"
local LARGE_SIZE = 60

Org.KINDS = {
    { "surveysGold", "Gold-material surveys" }, { "surveysOther", "Alchemy and enchanting surveys" },
    { "masterWrits", "Master writs" }, { "monster", "Monster gear" }, { "mythics", "Mythics" }, { "armor", "Armor" }, { "weapons", "Weapons" },
    { "jewelry", "Jewelry" }, { "companionPurple", "Purple companion gear" }, { "companionOther", "Other companion gear" }, { "training", "Training gear" },
    { "consumables", "Potions and poisons" }, { "foodTools", "Food, drink and tools" }, { "materials", "Crafting materials" },
    { "motifs", "Motifs and recipes" }, { "plans", "Furnishing plans" }, { "clutter", "Treasure and trash" },
    { "containers", "Coffers and containers" }, { "other", "Everything else" },
}

local PLANS = {
    crafter = {
        label = "On",
        alphabetical = { "Gear 1", "Gear 2", "Gear 3" },
        large = { "Surveys", "Gear 1", "Gear 2", "Gear 3" },
        small = { "Master Writs", "Mythics", "Purple Companion", "Monster Gear" },
        rules = {
            surveysGold = BANK, surveysOther = "Surveys", masterWrits = "Master Writs",
            monster = "Monster Gear", mythics = "Mythics", armor = BANK, weapons = BANK, jewelry = BANK,
            companionPurple = "Purple Companion", companionOther = BANK, training = BANK, consumables = BANK,
            foodTools = LEAVE, materials = LEAVE, motifs = LEAVE, plans = LEAVE, clutter = LEAVE, containers = LEAVE, other = LEAVE,
        },
    },
}
Org.PLAN_ORDER = { "off", "crafter" }
local PLAN_LABELS = { off = "Off", crafter = "On" }
local CHEST_CONTENTS = {
    ["Surveys"] = "Alchemy and enchanting surveys", ["Gear 1"] = "Sets, pieces kept together", ["Gear 2"] = "Sets, pieces kept together",
    ["Gear 3"] = "Sets, pieces kept together", ["Master Writs"] = "Master writs", ["Mythics"] = "Mythic items",
    ["Purple Companion"] = "Purple companion gear", ["Monster Gear"] = "Monster helmets and shoulders",
}

local function chestBagNamed(name)
    for bag, job in pairs(catalog.jobs) do
        if job == name then return tonumber(bag) end
    end
    return nil
end

local GEAR_KINDS = { armor = true, weapons = true, jewelry = true }

local function gearChests()
    local plan = PLANS[catalog and catalog.plan or "off"]
    return plan and plan.alphabetical or nil
end

local function isGearChest(name)
    for _, gear in ipairs(gearChests() or {}) do
        if gear == name then return true end
    end
    return false
end

local function sortName(setName)
    local name = string.lower(setName or "")
    name = string.gsub(name, "^perfected%s+", "")
    name = string.gsub(name, "^perfect%s+", "")
    name = string.gsub(name, "^the%s+", "")
    return name
end

local function gearRoom(name)
    local bag = chestBagNamed(name)
    local loc = bag and catalog.locs["chest:" .. bag]
    if not loc then return 0 end
    return (loc.size or 0) - (loc.used or 0)
end

-- Keeps each set together and fills Gear 1, then Gear 2, then Gear 3. A set belongs in the Gear chest
-- holding most of it, unless all of it fits in an earlier one. A new set takes the first with room.
local function gearLayout()
    if gearCache then return gearCache end
    local result = { chestFor = {} }
    gearCache = result
    local list = gearChests()
    if not list then return result end
    local totals, inChest, fixed = {}, {}, {}
    for key, loc in pairs(catalog.locs) do
        if loc.kind == "chest" or loc.kind == "bank" then
            local here = loc.kind == "chest" and catalog.jobs[string.match(key, "^chest:(%d+)") or ""] or nil
            for itemKey, count in pairs(decode(loc.items)) do
                local def = readDef(itemKey)
                local armory, crafted = string.find(itemKey, "AK$") ~= nil, string.find(itemKey, "CK$") ~= nil
                if def.fresh and not armory and GEAR_KINDS[def.home] and def.set ~= "" and not (crafted and loc.kind == "bank") then
                    totals[def.set] = (totals[def.set] or 0) + count
                    if here and isGearChest(here) then
                        inChest[def.set] = inChest[def.set] or {}
                        inChest[def.set][here] = (inChest[def.set][here] or 0) + count
                    end
                elseif here and isGearChest(here) and (armory or not def.fresh or Org.RuleFor(def.home) == LEAVE) then
                    -- It won't be leaving this chest, so its slots aren't available.
                    fixed[here] = (fixed[here] or 0) + (armory and count or 1)
                end
            end
        end
    end
    for _, entry in pairs(catalog.carrying and catalog.carrying.items or {}) do
        if entry.set and entry.set ~= "" then
            totals[entry.set] = (totals[entry.set] or 0) + (entry.count or 0)
            -- Pieces on their way count as already there, so a set can't change its mind mid-move.
            if isGearChest(entry.to) then
                inChest[entry.set] = inChest[entry.set] or {}
                inChest[entry.set][entry.to] = (inChest[entry.set][entry.to] or 0) + (entry.count or 0)
            end
        end
    end
    local function heldIn(setName, name) return inChest[setName] and inChest[setName][name] or 0 end
    local free, rank = {}, {}
    for index, name in ipairs(list) do
        rank[name] = index
        local bag = chestBagNamed(name)
        local loc = bag and catalog.locs["chest:" .. bag]
        free[name] = loc and (loc.size or 0) - (fixed[name] or 0) or 0
    end
    local function byName(a, b)
        local sa, sb = sortName(a), sortName(b)
        if sa ~= sb then return sa < sb end
        return a < b
    end
    local newSets, placed, homes = {}, {}, {}
    for setName, total in pairs(totals) do
        local home, most = nil, 0
        for _, name in ipairs(list) do
            local held = heldIn(setName, name)
            if held > most then home, most = name, held end
        end
        if home then
            homes[setName] = home
            placed[#placed + 1] = setName
            for _, name in ipairs(list) do
                free[name] = free[name] - (name == home and total or heldIn(setName, name))
            end
        else
            newSets[#newSets + 1] = setName
        end
    end
    table.sort(placed, byName)
    -- Fill the earlier chests with whole sets from the later ones.
    for index = 1, #list - 1 do
        local target = list[index]
        for _, setName in ipairs(placed) do
            local home, total, held = homes[setName], totals[setName], heldIn(setName, target)
            if rank[home] > index and total <= free[target] + held then
                free[target] = free[target] + held - total
                free[home] = free[home] + total
                homes[setName] = target
            end
        end
    end
    for setName, home in pairs(homes) do result.chestFor[setName] = home end
    table.sort(newSets, byName)
    for _, setName in ipairs(newSets) do
        local need, chosen, roomiest = totals[setName], nil, nil
        for _, name in ipairs(list) do
            if not chosen and free[name] >= need then chosen = name end
            if free[name] > 0 and (not roomiest or free[name] > free[roomiest]) then roomiest = name end
        end
        chosen = chosen or roomiest
        if chosen then
            result.chestFor[setName] = chosen
            free[chosen] = free[chosen] - need
        end
    end
    return result
end

function Org.GearChestFor(setName)
    return gearLayout().chestFor[setName]
end

-- Where the current plan sends an item, allowing for sets kept together in the Gear chests.
local function destinationFor(kind, setName)
    if gearChests() and GEAR_KINDS[kind] and setName and setName ~= "" then
        return Org.GearChestFor(setName) or LEAVE
    end
    return Org.RuleFor(kind)
end

-- One line per set: "Noble Duelist's Silks: Head, Chest, Ring".
local function gearSetLines(items)
    local sets, others = {}, {}
    for key, count in pairs(decode(items)) do
        local def = readDef(key)
        if def.set ~= "" then
            sets[def.set] = sets[def.set] or {}
            local piece = def.piece ~= "" and def.piece or def.name
            if count > 1 then piece = piece .. " x" .. count end
            table.insert(sets[def.set], piece)
        else
            others[#others + 1] = def.name .. (count > 1 and (" x" .. count) or "")
        end
    end
    local names = {}
    for name in pairs(sets) do names[#names + 1] = name end
    table.sort(names, function(a, b) return sortName(a) < sortName(b) end)
    local lines = {}
    for _, name in ipairs(names) do
        table.sort(sets[name])
        lines[#lines + 1] = name .. ": " .. table.concat(sets[name], ", ")
    end
    table.sort(others)
    for _, line in ipairs(others) do lines[#lines + 1] = line end
    return lines
end

local function gearHeading(name, loc)
    local used, size = loc.used or 0, loc.size or 0
    return string.format("%s (%d of %d, %d free)", name, used, size, size - used)
end

function Org.Plan() return catalog and catalog.plan or "off" end
function Org.PlanLabel(id) return PLAN_LABELS[id or Org.Plan()] or "Off" end
function Org.PlanLabels()
    local labels = {}
    for _, id in ipairs(Org.PLAN_ORDER) do labels[#labels + 1] = { name = PLAN_LABELS[id], data = id } end
    return labels
end

-- Where the current plan sends this kind of item, or nil with the plan off.
function Org.RuleFor(kind)
    local plan = Org.Plan()
    if plan == "off" or not kind then return nil end
    return PLANS[plan].rules[kind] or LEAVE
end

-- The chest's own name in the game, and the name you gave it if you renamed it.
local function gameNames(bag)
    local id = safe(GetCollectibleForBag, bag)
    if not id or id == 0 then return nil, "House storage", false end
    local nickname = safe(GetCollectibleNickname, id)
    local default = safe(GetCollectibleDefaultNickname, id)
    if not default or default == "" then default = safe(GetCollectibleName, id) end
    local custom = nickname and nickname ~= "" and nickname ~= default and plain(nickname) or nil
    return custom, plain(default or "House storage"), nickname ~= nil and nickname ~= ""
end

local function chestTitle(bag)
    local custom, base = gameNames(bag)
    if Org.Plan() == "off" then return custom or base end
    return catalog.jobs[tostring(bag)] or custom or base
end

local function refreshChestNames()
    for key, loc in pairs(catalog.locs) do
        local bag = tonumber(string.match(key, "^chest:(%d+)"))
        if bag then loc.name = chestTitle(bag) end
    end
end

-- Close enough to mean the same chest.
local NAME_ALIASES = {
    ["master writ"] = "Master Writs",
    ["monster"] = "Monster Gear", ["monsters"] = "Monster Gear", ["monster set"] = "Monster Gear", ["monster sets"] = "Monster Gear",
    ["monster helm"] = "Monster Gear", ["monster helms"] = "Monster Gear", ["monster helmets"] = "Monster Gear",
}

-- A chest is in the plan if it has one of the plan's names (capital letters don't matter).
local function planNameFor(name)
    if not name then return nil end
    local wanted = string.lower(string.match(name, "^%s*(.-)%s*$") or "")
    if NAME_ALIASES[wanted] then return NAME_ALIASES[wanted] end
    local plan = PLANS.crafter
    for _, list in ipairs({ plan.large, plan.small }) do
        for _, chest in ipairs(list) do
            if string.lower(chest) == wanted then return chest end
        end
    end
    return nil
end

local duplicateNames = {}

function Org.RefreshChestJobs()
    if not catalog or not BAG_HOUSE_BANK_ONE or not BAG_HOUSE_BANK_TEN then return end
    local jobs, used, unreadable = {}, {}, {}
    duplicateNames = {}
    for bag = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        local custom, _, readable = gameNames(bag)
        if readable then
            local job = planNameFor(custom)
            if job and used[job] then
                duplicateNames[job] = true
            elseif job then
                jobs[tostring(bag)] = job
                used[job] = true
            end
        else
            unreadable[#unreadable + 1] = tostring(bag)
        end
    end
    -- The game can't always report a chest's name (away from home, say): keep the one we knew.
    for _, bag in ipairs(unreadable) do
        local known = catalog.jobs[bag]
        if known and not used[known] then
            jobs[bag] = known
            used[known] = true
        end
    end
    catalog.jobs = jobs
    gearCache = nil
    refreshChestNames()
end

function Org.SetPlan(id)
    if not catalog or not PLAN_LABELS[id] then return end
    catalog.plan = id
    Org.RefreshChestJobs()
    refreshChestNames()
end

function Org.MissingChests()
    local missing = {}
    local plan = PLANS.crafter
    for _, list in ipairs({ plan.large, plan.small }) do
        for _, name in ipairs(list) do
            if not chestBagNamed(name) then missing[#missing + 1] = name end
        end
    end
    return missing
end

-- Where this item should go instead, or nil if it's fine here.
local function belongsElsewhere(chestName, def)
    if not chestName or not def.home then return nil end
    local destination = destinationFor(def.home, def.set)
    if not destination or destination == LEAVE or destination == chestName then return nil end
    -- A piece in one Gear chest stays put if the rest of its set's chest is full.
    if isGearChest(chestName) and isGearChest(destination) and gearRoom(destination) <= 0 then return nil end
    return destination
end

-- What's in this chest that belongs somewhere else.
function Org.Misplaced(bag)
    local loc = catalog and catalog.locs["chest:" .. bag]
    local result = {}
    if not loc or Org.Plan() == "off" then return result end
    local name = catalog.jobs[tostring(bag)]
    for key in pairs(decode(loc.items)) do
        local def = readDef(key)
        local destination = belongsElsewhere(name, def)
        if destination then result[#result + 1] = { name = def.name, to = destination } end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Org.ChestPanelText(bag)
    local loc = catalog and catalog.locs["chest:" .. bag]
    if not loc or Org.Plan() == "off" then return "" end
    local name = catalog.jobs[tostring(bag)]
    local lines = { string.format("%s: %d of %d slots", chestTitle(bag), loc.used or 0, loc.size or 0) }
    if name and isGearChest(name) then
        lines[1] = gearHeading(name, loc)
        local sets = gearSetLines(loc.items)
        for index = 1, math.min(#sets, MAX_PANEL_LINES) do lines[#lines + 1] = sets[index] end
        if #sets > MAX_PANEL_LINES then lines[#lines + 1] = "...and " .. (#sets - MAX_PANEL_LINES) .. " more (see Full Inventory)" end
    end
    if not name then
        lines[#lines + 1] = "Not in the chest plan."
        local missing = Org.MissingChests()
        if #missing > 0 then lines[#lines + 1] = "To use it, rename it with X to: " .. table.concat(missing, ", ") end
        return table.concat(lines, "\n")
    end
    local misplaced = Org.Misplaced(bag)
    if #misplaced > 0 then
        lines[#lines + 1] = "Belongs elsewhere:"
        for index = 1, math.min(#misplaced, MAX_PANEL_LINES) do
            lines[#lines + 1] = misplaced[index].name .. " > " .. misplaced[index].to
        end
        if #misplaced > MAX_PANEL_LINES then lines[#lines + 1] = "...and " .. (#misplaced - MAX_PANEL_LINES) .. " more" end
    else
        lines[#lines + 1] = "Everything here belongs."
    end
    return table.concat(lines, "\n")
end

local function characterName()
    return plain(safe(GetUnitName, "player") or "This character")
end

-- The game only says what the logged-in character knows, so we note it while on your crafter.
function Org.CheckCrafterKnowledge(done)
    local function finish() if done then done() end end
    if not catalog or not catalog.crafter or catalog.crafter ~= characterName() then return finish() end
    catalog.known = catalog.known or {}
    local keys = {}
    for key in pairs(catalog.defs) do keys[#keys + 1] = key end
    local index = 1
    local function step()
        local stop = math.min(index + SCAN_ITEMS_PER_STEP - 1, #keys)
        for at = index, stop do
            local def = readDef(keys[at])
            local category = def.fresh and def.category or ""
            if category == "motif" or category == "recipe" then
                local id = tonumber(string.match(keys[at], "^(%d+)"))
                local link = "|H1:item:" .. tostring(id) .. ":1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
                local known
                if category == "motif" then known = safe(IsItemLinkBookKnown, link)
                else known = safe(IsItemLinkRecipeKnown, link) end
                if known ~= nil then catalog.known[tostring(id)] = known and 1 or 0 end
            end
        end
        index = stop + 1
        if index <= #keys then zo_callLater(step, SCAN_GAP_MS) else finish() end
    end
    step()
end

function Org.Crafter() return catalog and catalog.crafter end

function Org.SetCrafter(name)
    if not catalog then return end
    if catalog.crafter ~= name then catalog.known = {} end
    catalog.crafter = name
    pcall(Org.CheckCrafterKnowledge)
end

function Org.CharacterNames()
    local names = {}
    for index = 1, safe(GetNumCharacters) or 0 do
        local name = plain((safe(GetCharacterInfo, index)))
        if name ~= "" then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function Org.ScanChest(bag)
    if not catalog or not bag or not safe(IsHouseBankBag, bag) then return end
    pcall(Org.RefreshChestJobs)
    local rows = {}
    local size = safe(GetBagSize, bag) or 0
    if size == 0 then return end -- not readable right now: keep what we last saw
    for slot = 0, size - 1 do addRow(rows, bag, slot) end
    store("chest:" .. bag, "chest", chestTitle(bag), rows, size)
    -- Identical pieces share one row, so ask the game how many slots are really in use.
    local usedSlots = safe(GetNumBagUsedSlots, bag)
    if usedSlots then catalog.locs["chest:" .. bag].used = usedSlots end
end

-- Reads your bags a few slots at a time, then calls done. With bankOnly it just re-reads the bank.
local scanning, scanAgain, scanWaiting = false, false, {}

function Org.ScanAll(done, bankOnly)
    if not catalog then
        if done then done() end
        return
    end
    if done then scanWaiting[#scanWaiting + 1] = done end
    if scanning then
        if not bankOnly then scanAgain = true end
        return
    end
    scanning = true
    pcall(Org.RefreshChestJobs)
    local id, who = tostring(safe(GetCurrentCharacterId) or characterName()), characterName()
    local targets = {}
    local function add(key, kind, name, bag)
        if bag then targets[#targets + 1] = { key = key, kind = kind, name = name, bag = bag } end
    end
    if not bankOnly then
        add("bag:" .. id, "backpack", who, BAG_BACKPACK)
        add("worn:" .. id, "worn", who .. " (worn)", BAG_WORN)
    end
    add("bank", "bank", "Bank", BAG_BANK)
    add("plusbank", "bank", "ESO Plus bank", BAG_SUBSCRIBER_BANK)
    if not bankOnly and BAG_VIRTUAL and type(GetNextVirtualBagSlotId) == "function" then
        add("craft", "craft", "Craft bag", BAG_VIRTUAL)
    end
    local index, slot, rows, pieces = 1, nil, {}, {}
    local function finished()
        scanning = false
        local waiting = scanWaiting
        scanWaiting = {}
        for _, callback in ipairs(waiting) do pcall(callback) end
        if scanAgain then
            scanAgain = false
            Org.ScanAll()
        end
    end
    local function step()
        local left = SCAN_ITEMS_PER_STEP
        while index <= #targets and left > 0 do
            local target = targets[index]
            local current
            if target.bag == BAG_VIRTUAL then
                current = safe(GetNextVirtualBagSlotId, slot)
            else
                local following = slot == nil and 0 or slot + 1
                if following < (safe(GetBagSize, target.bag) or 0) then current = following end
            end
            if current == nil then
                store(target.key, target.kind, target.name, rows)
                index, slot, rows = index + 1, nil, {}
            else
                slot, left = current, left - 1
                if target.bag ~= BAG_VIRTUAL and (safe(GetItemId, target.bag, current) or 0) ~= 0
                    and type(IsItemInArmory) == "function" and safe(IsItemInArmory, target.bag, current) then
                    local unique = uniqueKey(target.bag, current)
                    if unique then pieces[unique] = true end
                end
                pcall(addRow, rows, target.bag, current)
            end
        end
        if index <= #targets then return zo_callLater(step, SCAN_GAP_MS) end
        if bankOnly then return finished() end
        catalog.armory = catalog.armory or {}
        catalog.armory[id] = pieces
        Org.CheckCrafterKnowledge(finished)
    end
    step()
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
local function allItems()
    local items = {}
    for _, loc in pairs(catalog and catalog.locs or {}) do
        for key, count in pairs(decode(loc.items)) do
            local def = readDef(key)
            local entry = items[key]
            if not entry then
                entry = { key = key, id = tonumber(string.match(key, "^(%d+)")), name = def.name, category = def.category,
                    set = def.set, trait = def.trait, fresh = def.fresh, kept = string.sub(key, -1) == "K", total = 0, places = {}, worn = false }
                items[key] = entry
            end
            entry.total = entry.total + count
            entry.places[#entry.places + 1] = { name = loc.name, kind = loc.kind, count = count, seen = loc.seen }
            if loc.kind == "worn" then entry.worn = true end
        end
    end
    return items
end

-- Every word must appear in the item's name, set or trait.
function Org.SearchLines(query)
    local words = {}
    for word in string.gmatch(string.lower(query or ""), "%S+") do words[#words + 1] = word end
    local lines = {}
    if #words == 0 then return lines end
    for _, entry in pairs(allItems()) do
        local haystack = string.lower(entry.name .. " " .. entry.set .. " " .. entry.trait)
        local matches = true
        for _, word in ipairs(words) do
            if not string.find(haystack, word, 1, true) then matches = false; break end
        end
        if matches then
            local places = {}
            for _, place in ipairs(entry.places) do
                local text = place.name .. " x" .. place.count
                if place.kind == "chest" or place.kind == "backpack" or place.kind == "worn" then
                    text = text .. " (" .. dateText(place.seen) .. ")"
                end
                places[#places + 1] = text
            end
            table.sort(places)
            local label = entry.name
            if entry.trait ~= "" then label = label .. " (" .. entry.trait .. ")" end
            lines[#lines + 1] = label .. ": " .. table.concat(places, ", ")
        end
    end
    table.sort(lines)
    return lines
end

function Org.SearchText(query)
    local lines = Org.SearchLines(query)
    if #lines == 0 then return 'Nothing found for "' .. query .. '".\n\nCharacters and chests are only searched once they have been recorded.' end
    local out = { string.format('%d result%s for "%s"', #lines, #lines == 1 and "" or "s", query), "" }
    for index = 1, math.min(#lines, MAX_SEARCH_RESULTS) do out[#out + 1] = lines[index] end
    if #lines > MAX_SEARCH_RESULTS then out[#out + 1] = "...and " .. (#lines - MAX_SEARCH_RESULTS) .. " more. Try more words." end
    return table.concat(out, "\n")
end

function Org.Summary()
    local items = allItems()
    local result = { collected = {}, learnable = {}, knownSell = {}, unchecked = 0, clutter = {}, saved = {} }
    local known = catalog.known or {}
    for _, entry in pairs(items) do
        local line = entry.name .. ": " .. placesText(entry.places)
        if entry.category == "saved" then result.saved[#result.saved + 1] = line end
        if not entry.kept and not entry.worn then
            if entry.category == "set" and safe(IsItemSetCollectionPieceUnlocked, entry.id) then
                -- Gear on a character may be a second build, so only storage is suggested.
                local stored = {}
                for _, place in ipairs(entry.places) do
                    if place.kind ~= "backpack" then stored[#stored + 1] = place end
                end
                if #stored > 0 then result.collected[#result.collected + 1] = entry.name .. ": " .. placesText(stored) end
            elseif entry.fresh and (entry.category == "motif" or entry.category == "recipe") then
                local state = known[tostring(entry.id)]
                if state == 0 then result.learnable[#result.learnable + 1] = line
                elseif state == 1 then result.knownSell[#result.knownSell + 1] = line
                else result.unchecked = result.unchecked + 1 end
            elseif entry.category == "clutter" then
                result.clutter[#result.clutter + 1] = line
            end
        end
    end
    return result
end

-- Zones with gold-material surveys, most first. Counts every place they're stored.
function Org.SurveyZones()
    local zones = {}
    for _, loc in pairs(catalog and catalog.locs or {}) do
        for key, count in pairs(decode(loc.items)) do
            local def = readDef(key)
            if def.zone ~= "" and def.home == "surveysGold" then
                local zone = zones[def.zone]
                if not zone then
                    zone = { name = def.zone, total = 0, crafts = {} }
                    zones[def.zone] = zone
                end
                zone.total = zone.total + count
                zone.crafts[def.craft] = (zone.crafts[def.craft] or 0) + count
            end
        end
    end
    local list = {}
    for _, zone in pairs(zones) do list[#list + 1] = zone end
    table.sort(list, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    return list
end

local function surveySection(out)
    local zones = Org.SurveyZones()
    if #zones == 0 then return end
    local ready, waiting, waitingCount = {}, 0, 0
    for _, zone in ipairs(zones) do
        if zone.total >= SURVEY_RUN_AT then
            local crafts = {}
            for craft, count in pairs(zone.crafts) do crafts[#crafts + 1] = craft .. " " .. count end
            table.sort(crafts)
            ready[#ready + 1] = string.format("  %s: %d (%s)", zone.name, zone.total, table.concat(crafts, ", "))
        else
            waiting, waitingCount = waiting + 1, waitingCount + zone.total
        end
    end
    out[#out + 1] = ""
    out[#out + 1] = string.format("Surveys ready to run (%d or more in a zone)", SURVEY_RUN_AT)
    if #ready == 0 then out[#out + 1] = "  No zone has enough yet." end
    for _, line in ipairs(ready) do out[#out + 1] = line end
    if waiting > 0 then
        out[#out + 1] = string.format("  Still building: %d surveys across %d zone%s", waitingCount, waiting, waiting == 1 and "" or "s")
    end
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

local function chestLocations()
    local chests, rank = {}, {}
    local plan = PLANS[Org.Plan()]
    if plan then
        for _, list in ipairs({ plan.large, plan.small }) do
            for _, name in ipairs(list) do rank[name] = #rank + 1; rank[#rank + 1] = name end
        end
    end
    for key, loc in pairs(catalog.locs) do
        if loc.kind == "chest" then
            local bag = tonumber(string.match(key, "^chest:(%d+)"))
            local job = catalog.jobs[tostring(bag)]
            chests[#chests + 1] = { bag = bag, loc = loc, job = job, title = chestTitle(bag) }
        end
    end
    table.sort(chests, function(a, b)
        local rankA, rankB = rank[a.title] or 99, rank[b.title] or 99
        if rankA ~= rankB then return rankA < rankB end
        return a.title < b.title
    end)
    return chests
end

-- One page per chest: its name, then everything in it.
local function chestPage(chest)
    local job = chest.job
    local lines = {}
    for key, count in pairs(decode(chest.loc.items)) do
        local def = readDef(key)
        local line = "  " .. def.name
        if def.trait ~= "" then line = line .. " (" .. def.trait .. ")" end
        if count > 1 then line = line .. " x" .. count end
        local destination = Org.Plan() ~= "off" and belongsElsewhere(job, def)
        if destination then line = line .. "  > " .. destination end
        lines[#lines + 1] = line
    end
    table.sort(lines)
    local heading = string.format("%s: %d of %d slots", chest.title, chest.loc.used or 0, chest.loc.size or 0)
    if job and isGearChest(job) then
        heading = gearHeading(job, chest.loc)
        lines = {}
        for _, line in ipairs(gearSetLines(chest.loc.items)) do lines[#lines + 1] = "  " .. line end
    end
    if #lines == 0 then lines[1] = "  Empty" end
    return heading .. "\n" .. table.concat(lines, "\n")
end

function Org.ReportText()
    local out = {}
    if Org.Plan() == "off" then
        out[#out + 1] = "Chest plan: Off. Choose one in Settings if you want sorting advice."
    else
        out[#out + 1] = "Chest plan: " .. Org.PlanLabel()
    end
    local missing = Org.MissingCharacters()
    if #missing > 0 then
        out[#out + 1] = "Not cataloged yet (log in once): " .. table.concat(missing, ", ")
    end
    surveySection(out)
    local summary = Org.Summary()
    if catalog.crafter then
        section(out, catalog.crafter .. " can learn these", summary.learnable)
        section(out, catalog.crafter .. " already knows these: sell them", summary.knownSell)
        if summary.unchecked > 0 then
            out[#out + 1] = ""
            out[#out + 1] = string.format("Log in on %s to check %d more motif%s and recipe%s.", catalog.crafter,
                summary.unchecked, summary.unchecked == 1 and "" or "s", summary.unchecked == 1 and "" or "s")
        end
    else
        out[#out + 1] = ""
        out[#out + 1] = "Choose your Main crafter in Settings to see which motifs and recipes to learn or sell."
    end
    section(out, "Already in your Sticker Book: keep, sell or deconstruct", summary.collected)
    section(out, "Clutter worth selling", summary.clutter)
    section(out, "Saved coffers (open one a day where they apply)", summary.saved)
    local chests = chestLocations()
    if #chests > 0 then
        local index = {}
        for _, chest in ipairs(chests) do
            local misplaced = Org.Misplaced(chest.bag)
            local line = string.format("  %s: %d of %d slots", chest.title, chest.loc.used or 0, chest.loc.size or 0)
            if #misplaced > 0 then line = line .. ", " .. #misplaced .. " in the wrong place" end
            if (chest.loc.size or 0) > 0 and (chest.loc.used or 0) / chest.loc.size >= 0.9 then line = line .. " - NEARLY FULL" end
            index[#index + 1] = line
        end
        out[#out + 1] = ""
        out[#out + 1] = "Your chests (each has its own page next)"
        for _, line in ipairs(index) do out[#out + 1] = line end
        if #chests < 8 then out[#out + 1] = "  Open your other chests once to add them." end
    end
    local text = table.concat(out, "\n")
    for _, chest in ipairs(chests) do text = text .. "\f" .. chestPage(chest) end
    return text
end

---------------------------------------------------------------------------
-- Report screen (large text, LB and RB turn the page)
---------------------------------------------------------------------------
local scene, titleLabel, bodyLabel, rightLabel, pageLabel, keybinds
local pages, pageIndex = { { left = "", right = "" } }, 1
local screenTitle = "Quartermaster: Full Inventory"
local screenActions = nil

local function paginateBlock(text, perPage, chars)
    chars = chars or CHARS_PER_LINE
    local result, current, used = {}, {}, 0
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        -- A long line wraps on screen, so it takes up more than one row.
        local need = math.max(1, math.ceil(#line / chars))
        if #current > 0 and used + need > perPage then
            result[#result + 1] = table.concat(current, "\n")
            current, used = {}, 0
        end
        if #current > 0 or line ~= "" then
            current[#current + 1] = line
            used = used + need
        end
    end
    if #current > 0 then result[#result + 1] = table.concat(current, "\n") end
    return result
end

-- A form feed starts a new page. A section that runs on repeats its heading on each page.
function Org.Paginate(text, perPage)
    perPage = perPage or LINES_PER_PAGE
    local result, first = {}, true
    for part in string.gmatch(text .. "\f", "(.-)\f") do
        if first then
            for _, page in ipairs(paginateBlock(part, perPage)) do result[#result + 1] = page end
            first = false
        else
            local heading, body = string.match(part, "^([^\n]*)\n?(.*)$")
            for index, page in ipairs(paginateBlock(body, perPage - 1)) do
                result[#result + 1] = heading .. (index > 1 and " (continued)" or "") .. "\n" .. page
            end
        end
    end
    if #result == 0 then result[1] = "" end
    return result
end

-- Screens of two columns. A form feed starts a new screen; a section that runs on repeats its heading.
function Org.Screens(text)
    local screens, first = {}, true
    local function addColumns(columns)
        for index = 1, #columns, 2 do
            screens[#screens + 1] = { left = columns[index], right = columns[index + 1] or "" }
        end
    end
    for part in string.gmatch(text .. "\f", "(.-)\f") do
        local leftColumn, rightColumn = string.match(part, "^(.-)\v(.*)$")
        if leftColumn then -- a screen laid out by hand
            screens[#screens + 1] = { left = leftColumn, right = rightColumn }
            first = false
        elseif first then
            addColumns(paginateBlock(part, COLUMN_ROWS, COLUMN_CHARS))
            first = false
        else
            local heading, body = string.match(part, "^([^\n]*)\n?(.*)$")
            local columns = paginateBlock(body, COLUMN_ROWS - 1, COLUMN_CHARS)
            for index, column in ipairs(columns) do
                if index == 1 then
                    columns[index] = heading .. "\n" .. column
                elseif index % 2 == 1 then
                    columns[index] = heading .. " (continued)\n" .. column
                end
            end
            if #columns == 0 then columns[1] = heading end
            addColumns(columns)
        end
    end
    if #screens == 0 then screens[1] = { left = "", right = "" } end
    return screens
end

local function showPage()
    if not bodyLabel then return end
    pageIndex = math.max(1, math.min(pageIndex, #pages))
    titleLabel:SetText(screenTitle)
    local screen = pages[pageIndex] or { left = "", right = "" }
    bodyLabel:SetText(screen.left)
    rightLabel:SetText(screen.right)
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
    pageLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    pageLabel:SetFont("ZoFontGamepad34")
    pageLabel:SetColor(0.8, 0.8, 0.8, 1)
    pageLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PADDING, 24)
    bodyLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    local GAP = 40
    local columnWidth = (WIDTH - PADDING * 2 - GAP) / 2
    bodyLabel:SetFont("ZoFontGamepad27")
    bodyLabel:SetColor(0.96, 0.94, 0.86, 1)
    bodyLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, 90)
    bodyLabel:SetDimensions(columnWidth, HEIGHT - 110)
    rightLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    rightLabel:SetFont("ZoFontGamepad27")
    rightLabel:SetColor(0.96, 0.94, 0.86, 1)
    rightLabel:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING + columnWidth + GAP, 90)
    rightLabel:SetDimensions(columnWidth, HEIGHT - 110)
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
        { name = function() return screenActions and screenActions.primaryName() or "" end, keybind = "UI_SHORTCUT_PRIMARY",
          visible = function() return screenActions ~= nil and screenActions.primaryVisible() end,
          callback = function() screenActions.primary(); screenActions.refresh(); showPage() end },
        { name = "Clear carried list", keybind = "UI_SHORTCUT_SECONDARY",
          visible = function() return screenActions ~= nil and screenActions.secondaryVisible() end,
          callback = function() screenActions.secondary(); screenActions.refresh(); showPage() end },
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

local function openScreen(title, build, actions)
    local ok, text = pcall(build)
    if not ok then return say("couldn't build that screen: " .. tostring(text)) end
    screenTitle = title
    screenActions = actions
    pages, pageIndex = Org.Screens(text), 1
    pcall(function() SCENE_MANAGER:ShowBaseScene() end)
    zo_callLater(function()
        local shown, err = pcall(function()
            if not scene then createScene() end
            SCENE_MANAGER:Show(SCENE_NAME)
        end)
        if not shown then say("couldn't open that screen: " .. tostring(err)) end
        pcall(showPage)
    end, 300)
end

-- Reads your items first, a few at a time, so the screen itself has little to do.
local function openAfterScan(title, build, actions)
    say("Reading your items...")
    Org.ScanAll(function() openScreen(title, build, actions) end)
end

function Org.OpenReport()
    openAfterScan("Quartermaster: Full Inventory", Org.ReportText)
end

function Org.OpenOrganize()
    local actions = {
        primaryName = function() return "Stop organizing" end,
        primaryVisible = function() return Org.OrganizeActive() end,
        primary = function() Org.SetOrganizing(false) end,
        secondaryVisible = function() return Org.CarriedKinds() > 0 end,
        secondary = function() Org.ClearCarried() end,
        refresh = function()
            local ok, text = pcall(Org.OrganizeText)
            if ok then pages = Org.Screens(text) end
        end,
    }
    openAfterScan("Quartermaster: What Will Move", Org.OrganizeText, actions)
end

function Org.Search(query)
    query = string.match(query or "", "^%s*(.-)%s*$")
    if not query or query == "" then return end
    openAfterScan("Quartermaster: Search", function() return Org.SearchText(query) end)
end

---------------------------------------------------------------------------
-- Panel shown while a house chest is open
---------------------------------------------------------------------------
local panel, panelLabel
local showPanel

showPanel = function(bag)
    if not WINDOW_MANAGER or Org.Plan() == "off" then return end
    Org.RefreshPanel = showPanel
    if not panel then
        panel = WINDOW_MANAGER:CreateTopLevelWindow("ESOCQuartermasterChestPanel")
        panel:SetDimensions(620, 430)
        -- Stops short of the right-hand area, where the game shows item details.
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, (ZO_GAMEPAD_QUADRANT_4_LEFT_OFFSET or -526) - 20, 60)
        local background = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
        background:SetAnchorFill(panel)
        background:SetColor(0, 0, 0, 0.8)
        panelLabel = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        panelLabel:SetFont("ZoFontGamepad27")
        panelLabel:SetColor(0.96, 0.94, 0.86, 1)
        panelLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 16, 12)
        panelLabel:SetWidth(588)
    end
    local text = Org.OrganizePanelText(bag) or ""
    local contents = Org.ChestPanelText(bag)
    if contents ~= "" then text = text == "" and contents or (text .. "\n\n" .. contents) end
    if text == "" then return panel:SetHidden(true) end
    panelLabel:SetText(text)
    panel:SetHeight(panelLabel:GetTextHeight() + 24)
    panel:SetHidden(false)
end

local function hidePanel()
    if panel then panel:SetHidden(true) end
end

---------------------------------------------------------------------------
-- Organize mode: one character carries items between your chests
---------------------------------------------------------------------------
-- It only ever puts down what it picked up, counted per item. Selling and
-- container opening pause while it's on or while it's still carrying anything.
local KEEP_FREE_SLOTS = 2
local OPEN_SURVEYS = "Open" -- carried unidentified surveys wait to be opened, not put down
local OPEN_POLL_MS = 200
local OPEN_POLLS = 15
local OPEN_GAP_MS = 1200 -- the game ignores a second container used too soon after the last
local OPEN_RETRIES = 4
local OPEN_RETRY_MS = 1500
local OPEN_WAITS = 60
local MOVE_POLL_MS = 150
local MOVE_POLLS = 8
local MOVE_GAP_MS = 250
local MAX_MOVES = 300
local organizing, moving = false, false
local onButtonChange

local function buttonChanged()
    if onButtonChange then pcall(onButtonChange) end
end

local function thisCharacter()
    return tostring(safe(GetCurrentCharacterId) or characterName())
end

local function carrying()
    catalog.carrying = catalog.carrying or { items = {} }
    catalog.carrying.items = catalog.carrying.items or {}
    return catalog.carrying
end

local function slotKey(bag, slot)
    return (safe(GetItemId, bag, slot) or 0) .. "_" .. (safe(GetItemTrait, bag, slot) or 0) .. "_" .. (safe(GetItemDisplayQuality, bag, slot) or 0)
end

local function backpackCounts()
    local counts = {}
    for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
        if (safe(GetItemId, BAG_BACKPACK, slot) or 0) ~= 0 then
            local _, count = safe(GetItemInfo, BAG_BACKPACK, slot)
            local key = slotKey(BAG_BACKPACK, slot)
            counts[key] = (counts[key] or 0) + (count or 0)
        end
    end
    return counts
end

local function carriedHere()
    local state = carrying()
    return state.char == thisCharacter() and state.items or {}
end

function Org.CarriedKinds()
    if not catalog then return 0 end
    local total = 0
    for _ in pairs(carriedHere()) do total = total + 1 end
    return total
end

function Org.IsOrganizing()
    return organizing or Org.CarriedKinds() > 0
end

function Org.OrganizeActive() return organizing end

-- If something carried was moved by hand, stop counting it.
local function reconcile()
    local state = carrying()
    if state.char ~= thisCharacter() then return end
    local counts = backpackCounts()
    for key, entry in pairs(state.items) do
        entry.count = math.min(entry.count, counts[key] or 0)
        if entry.count <= 0 then state.items[key] = nil end
    end
    if next(state.items) == nil then state.char = nil end
end

local function placeName(bag)
    if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK then return BANK end
    return catalog.jobs[tostring(bag)]
end

local function destinationOf(bag, slot)
    local itemType, specialized = safe(GetItemType, bag, slot)
    local link = safe(GetItemLink, bag, slot) or ""
    local name = plain(safe(GetItemName, bag, slot))
    local category = classify(bag, slot, link, itemType)
    if category == "material" then return nil end -- ESO Plus and other add-ons handle these
    local _, setName = safe(GetItemLinkSetInfo, link)
    setName = type(setName) == "string" and plain(setName) or ""
    local kind = kindOf(bag, slot, link, itemType, specialized, name, category)
    return destinationFor(kind, setName), GEAR_KINDS[kind] and setName or ""
end

local function roomAt(destination)
    if destination == BANK then
        return (safe(GetNumBagFreeSlots, BAG_BANK) or 0) + (BAG_SUBSCRIBER_BANK and safe(GetNumBagFreeSlots, BAG_SUBSCRIBER_BANK) or 0)
    end
    local bag = chestBagNamed(destination)
    local loc = bag and catalog.locs["chest:" .. bag]
    if not loc then return 0 end
    return (loc.size or 0) - (loc.used or 0)
end

local function stacksHeadedFor(destination)
    local total = 0
    for _, entry in pairs(carriedHere()) do
        if entry.to == destination then total = total + (entry.stacks or 1) end
    end
    return total
end

local function canPickUp(bag, slot, here, counts)
    if (safe(GetItemId, bag, slot) or 0) == 0 then return nil end
    if safe(IsItemStolen, bag, slot) or inAnyArmory(bag, slot) then return nil end
    if here == BANK then
        -- Crafted gear in the bank is usually waiting for another character to collect it.
        local creator = safe(GetItemCreatorName, bag, slot)
        if creator and creator ~= "" then return nil end
    end
    local destination, setName = destinationOf(bag, slot)
    if not destination or destination == LEAVE or destination == here then return nil end
    if destination ~= BANK and not chestBagNamed(destination) then return nil end
    -- A stack would merge with the carrier's own, so it's left for an emptier character.
    local key = slotKey(bag, slot)
    local carried = carriedHere()[key]
    if (counts[key] or 0) - (carried and carried.count or 0) > 0 then return nil, "this character already carries one" end
    if roomAt(destination) - stacksHeadedFor(destination) <= 0 then
        -- Its chest is full. A piece already in a Gear chest stays; set pieces try the next Gear chest;
        -- anything else overflows to the bank, and what's already in the bank waits there for room.
        if isGearChest(destination) and isGearChest(here) then return nil end
        local overflow
        if isGearChest(destination) then
            for _, name in ipairs(gearChests()) do
                if chestBagNamed(name) and roomAt(name) - stacksHeadedFor(name) > 0 then overflow = name; break end
            end
        end
        if not overflow and here ~= BANK and roomAt(BANK) - stacksHeadedFor(BANK) > 0 then overflow = BANK end
        if not overflow then return nil, destination .. " is full" end
        destination = overflow
    end
    return destination, setName
end

-- Where this chest visit has got to, so each step only looks at a few slots.
local stopCursor

local function searchSlots(cursor, sources, test)
    local left = SCAN_ITEMS_PER_STEP
    while cursor.source <= #sources do
        local source = sources[cursor.source]
        if cursor.slot >= (safe(GetBagSize, source) or 0) then
            cursor.source, cursor.slot = cursor.source + 1, 0
        else
            local slot = cursor.slot
            cursor.slot = slot + 1
            local action = test(source, slot)
            if action then return action end
            left = left - 1
            if left <= 0 then return { kind = "wait" } end
        end
    end
    return nil
end

local function nextAction(bag)
    local here = placeName(bag)
    if not here then return nil end
    local cursor = stopCursor
    local carried = carriedHere()
    cursor.counts = cursor.counts or backpackCounts()
    local counts = cursor.counts
    if not cursor.putsDone then
        local putBag = bag
        if not safe(FindFirstEmptySlotInBag, putBag) and bag == BAG_BANK and BAG_SUBSCRIBER_BANK then putBag = BAG_SUBSCRIBER_BANK end
        if safe(FindFirstEmptySlotInBag, putBag) then
            local left = {}
            for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
                if (safe(GetItemId, BAG_BACKPACK, slot) or 0) ~= 0 then
                    local key = slotKey(BAG_BACKPACK, slot)
                    local entry = carried[key]
                    if entry and entry.to == here then
                        if left[key] == nil then left[key] = entry.count end
                        local _, count = safe(GetItemInfo, BAG_BACKPACK, slot)
                        if left[key] > 0 then
                            return { kind = "put", slot = slot, key = key, quantity = math.min(count or 0, left[key]), toBag = putBag }
                        end
                    end
                end
            end
        end
        cursor.putsDone = true
    end
    local sources = { bag }
    if bag == BAG_BANK and BAG_SUBSCRIBER_BANK then sources[2] = BAG_SUBSCRIBER_BANK end
    if bag == BAG_BANK and not cursor.surveysDone then
        -- Unidentified surveys come out first. Each may open into its own stack, so leave a slot for each.
        local waiting = 0
        for _, entry in pairs(carried) do
            if entry.to == OPEN_SURVEYS then waiting = waiting + entry.count end
        end
        local room = (safe(GetNumBagFreeSlots, BAG_BACKPACK) or 0) - KEEP_FREE_SLOTS - waiting
        local action
        if room > 0 then
            action = searchSlots(cursor, sources, function(source, slot)
                if (safe(GetItemId, source, slot) or 0) == 0 then return nil end
                local name = plain(safe(GetItemName, source, slot))
                if not Org.IsUnidentifiedSurvey(name) or safe(IsItemPlayerLocked, source, slot) then return nil end
                local key = slotKey(source, slot)
                local mine = (counts[key] or 0) - (carried[key] and carried[key].count or 0)
                if mine > 0 then return nil end
                local _, count = safe(GetItemInfo, source, slot)
                return { kind = "pick", fromBag = source, slot = slot, key = key,
                    quantity = math.min(count or 1, room), to = OPEN_SURVEYS, set = "", name = name }
            end)
        end
        if action then return action end
        cursor.surveysDone, cursor.source, cursor.slot = true, 1, 0
    end
    if (safe(GetNumBagFreeSlots, BAG_BACKPACK) or 0) <= KEEP_FREE_SLOTS then
        cursor.outOfRoom = true
        return nil
    end
    return searchSlots(cursor, sources, function(source, slot)
        local destination, setName = canPickUp(source, slot, here, counts)
        if not destination then
            if setName then -- why it can't move
                cursor.blocked = cursor.blocked or {}
                table.insert(cursor.blocked, plain(safe(GetItemName, source, slot)) .. " (" .. setName .. ")")
            end
            return nil
        end
        local _, count = safe(GetItemInfo, source, slot)
        return { kind = "pick", fromBag = source, slot = slot, key = slotKey(source, slot), quantity = count or 1,
            to = destination, set = setName, name = plain(safe(GetItemName, source, slot)) }
    end)
end

local function callGame(name, ...)
    local isProtected = rawget(_G, "IsProtectedFunction")
    if isProtected and isProtected(name) then
        local ok, allowed = pcall(CallSecureProtected, name, ...)
        return ok and allowed ~= false
    end
    return (pcall(_G[name], ...))
end

local function moveItem(fromBag, fromSlot, toBag, toSlot, quantity, done)
    local id = safe(GetItemId, fromBag, fromSlot)
    local _, before = safe(GetItemInfo, fromBag, fromSlot)
    before = before or 0
    local function landed()
        if safe(GetItemId, fromBag, fromSlot) ~= id then return true end
        local _, now = safe(GetItemInfo, fromBag, fromSlot)
        return (now or 0) <= before - quantity
    end
    local attempts = {
        function()
            if callGame("PickupInventoryItem", fromBag, fromSlot, quantity) then
                callGame("PlaceInInventory", toBag, toSlot)
            end
            pcall(ClearCursor)
        end,
    }
    -- The second way is only safe for a whole stack, so a late first move can't move extra.
    if quantity >= before then
        attempts[2] = function() callGame("RequestMoveItem", fromBag, fromSlot, toBag, toSlot, quantity) end
    end
    local function attempt(index)
        if not moving then return done(false) end
        if not attempts[index] then return done(false) end
        attempts[index]()
        local polls = MOVE_POLLS
        local function check()
            zo_callLater(function()
                if landed() then return done(true) end
                if polls > 1 then
                    polls = polls - 1
                    check()
                else
                    attempt(index + 1)
                end
            end, MOVE_POLL_MS)
        end
        check()
    end
    attempt(1)
end

function Org.NextStop()
    local totals, toOpen = {}, 0
    for _, entry in pairs(carriedHere()) do
        if entry.to == OPEN_SURVEYS then
            toOpen = toOpen + entry.count
        else
            totals[entry.to] = (totals[entry.to] or 0) + (entry.stacks or 1)
        end
    end
    if toOpen > 0 then return "Close this menu", "opens " .. toOpen .. " unidentified surveys" end
    local best, bestCount
    for name, count in pairs(totals) do
        if not bestCount or count > bestCount or (count == bestCount and name < best) then best, bestCount = name, count end
    end
    if best then return best, "put down " .. bestCount end
    for _, chest in ipairs(Org.OrganizePlan().chests) do
        if #chest.out > 0 then return chest.title, "take out " .. #chest.out end
    end
    local plan = Org.OrganizePlan()
    if #plan.bankOut > 0 then return BANK, "take out " .. #plan.bankOut end
    local unidentified = Org.UnidentifiedInBank()
    if unidentified > 0 then return BANK, "take out " .. unidentified .. " unidentified surveys" end
    return nil
end

-- A stop that has been searched item by item isn't sent back to until its contents change, even if
-- the saved list still says something should come out of it.
local checkedStops = {}

local function bankContents()
    local bank, plus = catalog.locs.bank, catalog.locs.plusbank
    return (bank and bank.items or "") .. "|" .. (plus and plus.items or "")
end

local function markStopChecked(bag)
    if bag == BAG_BANK then
        checkedStops.bank = bankContents()
    else
        local loc = catalog.locs["chest:" .. bag]
        checkedStops[bag] = loc and loc.items or nil
    end
end

-- With nothing left in the bags, selling and container opening carry on as normal.
local function endIfNothingCarried()
    if Org.CarriedKinds() == 0 then organizing = false end
end

local function finishStop(bag, put, picked, problem)
    local cursor = stopCursor or {}
    moving = false
    gearFrozen = false
    pcall(StackBag, bag)
    if bag == BAG_BANK and BAG_SUBSCRIBER_BANK then pcall(StackBag, BAG_SUBSCRIBER_BANK) end
    pcall(reconcile)
    local function announce()
        gearCache = nil
        if not problem and not cursor.outOfRoom then markStopChecked(bag) end
        local text = string.format("Organize: put down %d, picked up %d.", put, picked)
        if problem then text = text .. " Stopped: " .. problem end
        if cursor.outOfRoom then text = text .. " Your bags are full, so put these down and come back." end
        local blocked = cursor.blocked
        if blocked and #blocked > 0 then
            local shown = {}
            for index = 1, math.min(#blocked, 3) do shown[index] = blocked[index] end
            text = text .. " Left here: " .. table.concat(shown, ", ")
            if #blocked > 3 then text = text .. " and " .. (#blocked - 3) .. " more" end
            text = text .. "."
        end
        local stop, detail = Org.NextStop()
        if stop then
            text = text .. " Next: " .. stop .. " (" .. detail .. ")."
        else
            text = text .. " Everything is sorted."
        end
        endIfNothingCarried()
        say(text)
        buttonChanged()
        if safe(GetBankingBag) == bag then pcall(Org.RefreshPanel, bag) end
    end
    if safe(IsHouseBankBag, bag) then
        if safe(GetBankingBag) == bag then pcall(Org.ScanChest, bag) end
        announce()
    else
        Org.ScanAll(announce, true)
    end
end

local function runStop(bag, put, picked, movesLeft)
    if not moving then return end
    if movesLeft <= 0 then return finishStop(bag, put, picked, "too many moves in one go; press X again") end
    local action = nextAction(bag)
    if not action then return finishStop(bag, put, picked) end
    if action.kind == "wait" then
        return zo_callLater(function() runStop(bag, put, picked, movesLeft) end, SCAN_GAP_MS)
    end
    local fromBag, toBag = BAG_BACKPACK, action.toBag
    if action.kind == "pick" then fromBag, toBag = action.fromBag, BAG_BACKPACK end
    local toSlot = safe(FindFirstEmptySlotInBag, toBag)
    if not toSlot then return finishStop(bag, put, picked, "no free slot") end
    moveItem(fromBag, action.slot, toBag, toSlot, action.quantity, function(ok)
        if not moving then return finishStop(bag, put, picked, "the chest closed") end
        if not ok then return finishStop(bag, put, picked, "the game didn't move an item") end
        stopCursor.counts = nil
        local state = carrying()
        if action.kind == "pick" then
            state.char = thisCharacter()
            state.name = characterName()
            local entry = state.items[action.key]
            if not entry then
                entry = { name = action.name, to = action.to, set = action.set, count = 0, stacks = 0 }
                state.items[action.key] = entry
            end
            entry.count = entry.count + action.quantity
            entry.stacks = entry.stacks + 1
            picked = picked + 1
        else
            local entry = state.items[action.key]
            if entry then
                entry.count = entry.count - action.quantity
                entry.stacks = math.max((entry.stacks or 1) - 1, 0)
                if entry.count <= 0 then state.items[action.key] = nil end
            end
            if next(state.items) == nil then state.char = nil end
            put = put + 1
        end
        if safe(IsHouseBankBag, bag) then pcall(Org.ScanChest, bag) end
        zo_callLater(function() runStop(bag, put, picked, movesLeft - 1) end, MOVE_GAP_MS)
    end)
end

function Org.UnidentifiedInBank()
    local total = 0
    for _, locKey in ipairs({ "bank", "plusbank" }) do
        local loc = catalog and catalog.locs[locKey]
        for key, count in pairs(decode(loc and loc.items)) do
            if Org.IsUnidentifiedSurvey(readDef(key).name) and not string.find(key, "K$") then total = total + count end
        end
    end
    return total
end

-- Opening needs the normal game view, so it happens once the bank is closed.
local openingSurveys, surveysOpened = false, 0

local function identifiedSurveys()
    local found = {}
    for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
        if (safe(GetItemId, BAG_BACKPACK, slot) or 0) ~= 0 then
            local _, specialized = safe(GetItemType, BAG_BACKPACK, slot)
            local name = plain(safe(GetItemName, BAG_BACKPACK, slot))
            if specialized == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT and not Org.IsUnidentifiedSurvey(name) then
                local key = slotKey(BAG_BACKPACK, slot)
                local _, count = safe(GetItemInfo, BAG_BACKPACK, slot)
                local entry = found[key] or { count = 0, name = name, to = destinationOf(BAG_BACKPACK, slot) }
                entry.count = entry.count + (count or 0)
                found[key] = entry
            end
        end
    end
    return found
end

local function nextSurveyToOpen()
    local carried = carriedHere()
    for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
        if (safe(GetItemId, BAG_BACKPACK, slot) or 0) ~= 0 then
            local key = slotKey(BAG_BACKPACK, slot)
            if carried[key] and carried[key].to == OPEN_SURVEYS and carried[key].count > 0 then return slot, key end
        end
    end
    return nil
end

local function endOpening(problem)
    openingSurveys = false
    if ESOC_Quartermaster then ESOC_Quartermaster.externalOpening = false end
    pcall(reconcile)
    local text = string.format("Organize: opened %d unidentified survey%s.", surveysOpened, surveysOpened == 1 and "" or "s")
    if problem then text = text .. " Stopped: " .. problem end
    local stop, detail = Org.NextStop()
    if stop then text = text .. " Next: " .. stop .. " (" .. detail .. ")." end
    surveysOpened = 0
    endIfNothingCarried()
    say(text)
    buttonChanged()
end

local function openNextSurvey(waits, tries)
    tries = tries or 0
    if not organizing then
        if openingSurveys then endOpening("Organize mode was turned off") end
        return
    end
    local slot, key = nextSurveyToOpen()
    if not slot then
        if openingSurveys then endOpening() end
        return
    end
    local ready = not safe(IsUnitInCombat, "player") and not safe(IsUnitDead, "player")
    if SCENE_MANAGER and SCENE_MANAGER.IsShowingBaseScene then ready = ready and safe(SCENE_MANAGER.IsShowingBaseScene, SCENE_MANAGER) == true end
    -- The last survey's loot has to be finished, and its cooldown over, before the next will open.
    if ready and safe(IsLooting) then
        ready = false
        pcall(LootAll, true)
        if waits < OPEN_WAITS - 3 then pcall(EndLooting) end
    end
    if ready then
        local remaining = safe(GetItemCooldownInfo, BAG_BACKPACK, slot)
        if type(remaining) == "number" and remaining > 0 then ready = false end
    end
    if not ready then
        if waits <= 0 then
            if openingSurveys then endOpening("waiting too long for the menu or combat to end") end
            return
        end
        return zo_callLater(function() openNextSurvey(waits - 1, tries) end, 1000)
    end
    if (safe(GetNumBagFreeSlots, BAG_BACKPACK) or 0) < 1 then return endOpening("your bags are full") end
    openingSurveys = true
    if ESOC_Quartermaster then ESOC_Quartermaster.externalOpening = true end
    local before = identifiedSurveys()
    local id = safe(GetItemId, BAG_BACKPACK, slot)
    local _, countBefore = safe(GetItemInfo, BAG_BACKPACK, slot)
    local function tryAgain()
        if tries + 1 >= OPEN_RETRIES then return endOpening("the game didn't open it") end
        zo_callLater(function() openNextSurvey(OPEN_WAITS, tries + 1) end, OPEN_RETRY_MS)
    end
    local ok, allowed = pcall(CallSecureProtected, "UseItem", BAG_BACKPACK, slot)
    if not ok or allowed == false then return tryAgain() end
    local polls = OPEN_POLLS
    local function check()
        zo_callLater(function()
            local _, countNow = safe(GetItemInfo, BAG_BACKPACK, slot)
            local used = safe(GetItemId, BAG_BACKPACK, slot) ~= id or (countNow or 0) < (countBefore or 0)
            local after = identifiedSurveys()
            local arrived = false
            for itemKey, entry in pairs(after) do
                if entry.count > (before[itemKey] and before[itemKey].count or 0) then arrived = true end
            end
            if used and arrived then
                local state = carrying()
                local source = state.items[key]
                if source then
                    -- A retry can catch a late first use, so count what actually left the stack.
                    local gone = safe(GetItemId, BAG_BACKPACK, slot) ~= id and (countBefore or 1) or ((countBefore or 0) - (countNow or 0))
                    source.count = source.count - math.max(gone, 1)
                    if source.count <= 0 then state.items[key] = nil end
                end
                for itemKey, entry in pairs(after) do
                    local gained = entry.count - (before[itemKey] and before[itemKey].count or 0)
                    if gained > 0 and entry.to and entry.to ~= LEAVE then
                        local carriedEntry = state.items[itemKey]
                        if not carriedEntry then
                            carriedEntry = { name = entry.name, to = entry.to, set = "", count = 0, stacks = 1 }
                            state.items[itemKey] = carriedEntry
                        end
                        carriedEntry.count = carriedEntry.count + gained
                    end
                end
                surveysOpened = surveysOpened + 1
                zo_callLater(function() openNextSurvey(OPEN_WAITS) end, OPEN_GAP_MS)
            elseif polls > 1 then
                polls = polls - 1
                check()
            elseif used then
                endOpening("one opened but no survey appeared in your bags, so it stopped to be safe")
            else
                tryAgain()
            end
        end, OPEN_POLL_MS)
    end
    check()
end

function Org.OpenCarriedSurveys()
    if not organizing or openingSurveys or not nextSurveyToOpen() then return end
    surveysOpened = 0
    openNextSurvey(OPEN_WAITS)
end

-- With the plan on, X sorts any chest that has a plan name. At the bank it's on the Withdraw tab,
-- because X on the Deposit tab shows or hides crafted gear. Unnamed chests keep the game's Rename.
function Org.OrganizeButtonVisible(onDepositTab)
    if not catalog or Org.Plan() == "off" then return false end
    local bag = safe(GetBankingBag)
    if not bag then return false end
    if bag == BAG_BANK then return organizing or not onDepositTab end
    return safe(IsHouseBankBag, bag) == true and placeName(bag) ~= nil
end

function Org.OrganizeButtonName()
    if moving then return "Moving..." end
    return safe(GetBankingBag) == BAG_BANK and "Organize bank" or "Organize this chest"
end

function Org.PressOrganize()
    if moving or not catalog or Org.Plan() == "off" then return end
    local bag = safe(GetBankingBag)
    if not bag then return end
    pcall(Org.RefreshChestJobs)
    if not placeName(bag) then return end
    if not organizing and not Org.SetOrganizing(true, true) then return end
    pcall(reconcile)
    moving = true
    buttonChanged()
    if safe(IsHouseBankBag, bag) then pcall(Org.ScanChest, bag) end
    local function go()
        if not moving then return end
        gearCache = nil
        pcall(gearLayout)
        gearFrozen = true
        stopCursor = { source = 1, slot = 0 }
        runStop(bag, 0, 0, MAX_MOVES)
    end
    if bag == BAG_BANK then Org.ScanAll(go, true) else go() end
end

function Org.StopMoving()
    moving = false
end

function Org.SetOrganizing(on, quiet)
    if not catalog then return false end
    if not on then
        organizing, moving = false, false
        local kinds = Org.CarriedKinds()
        if kinds > 0 then
            say(string.format("Organize mode off. Still carrying %d kind%s of item; selling and container opening stay paused until they're put away or you clear the list.", kinds, kinds == 1 and "" or "s"))
        else
            say("Organize mode off.")
        end
        buttonChanged()
        return true
    end
    if Org.Plan() == "off" then
        say("Turn the plan on in Chest setup first.")
        return false
    end
    local state = carrying()
    if state.char and state.char ~= thisCharacter() then
        say("Log in on " .. tostring(state.name) .. " first: they're still carrying items from the last run.")
        return false
    end
    pcall(reconcile)
    organizing = true
    if not quiet then say("Go to the bank and press X.") end
    buttonChanged()
    pcall(Org.OpenCarriedSurveys)
    return true
end

-- Forget the carried list. Items stay in the bags, and now count as this character's own.
function Org.ClearCarried()
    local state = carrying()
    if state.char == thisCharacter() then
        state.items, state.char, state.name = {}, nil, nil
        say("Carried list cleared. Those items stay in this character's bags.")
    end
end

-- What the plan would move, chest by chest, from what was last seen in each one.
function Org.OrganizePlan()
    local result = { chests = {}, outdated = 0, bankOut = {}, toBank = {} }
    if not catalog or Org.Plan() == "off" then return result end
    local incoming = {}
    for _, chest in ipairs(chestLocations()) do
        chest.out = {}
        if chest.job and checkedStops[chest.bag] ~= chest.loc.items then
            for key, count in pairs(decode(chest.loc.items)) do
                local def = readDef(key)
                if not def.fresh then
                    result.outdated = result.outdated + 1
                elseif not string.find(key, "AK$") and def.home ~= "materials" then
                    local destination = destinationFor(def.home, def.set)
                    if destination and destination ~= LEAVE and destination ~= chest.job
                        and (destination == BANK or chestBagNamed(destination))
                        and not (isGearChest(chest.job) and isGearChest(destination) and gearRoom(destination) <= 0) then
                        local label = def.name .. (count > 1 and (" x" .. count) or "")
                        chest.out[#chest.out + 1] = label .. " > " .. destination
                        incoming[destination] = incoming[destination] or {}
                        table.insert(incoming[destination], label .. " from " .. chest.title)
                    end
                end
            end
        end
        table.sort(chest.out)
        result.chests[#result.chests + 1] = chest
    end
    -- The bank is the inbox: anything with a chest goes there, except crafted gear and Armory pieces.
    result.bankOut = {}
    local bankChecked = checkedStops.bank == bankContents()
    for _, locKey in ipairs({ "bank", "plusbank" }) do
        local loc = catalog.locs[locKey]
        for key, count in pairs(decode(not bankChecked and loc and loc.items or nil)) do
            local def = readDef(key)
            if def.fresh and not string.find(key, "[AC]K$") and def.home ~= "materials" then
                local destination = destinationFor(def.home, def.set)
                if destination and destination ~= LEAVE and destination ~= BANK and chestBagNamed(destination) then
                    local label = def.name .. (count > 1 and (" x" .. count) or "")
                    result.bankOut[#result.bankOut + 1] = label .. " > " .. destination
                    incoming[destination] = incoming[destination] or {}
                    table.insert(incoming[destination], label .. " from Bank")
                end
            end
        end
    end
    table.sort(result.bankOut)
    for _, chest in ipairs(result.chests) do
        chest.incoming = incoming[chest.title] or {}
        table.sort(chest.incoming)
    end
    result.toBank = incoming[BANK] or {}
    table.sort(result.toBank)
    return result
end

function Org.OrganizeText()
    pcall(reconcile)
    local out = {
        "WARNING: X at the bank or a named chest moves your items.",
        "The next pages show every move.",
        "It empties the bank into your chests, except crafted gear and Armory pieces.",
        "It never sells or deletes anything.",
        "",
        "Chest plan: " .. Org.PlanLabel(),
    }
    if Org.Plan() == "off" then
        out[#out + 1] = "Turn the plan on in Chest setup before you can use this."
        return table.concat(out, "\n")
    end
    local free = safe(GetNumBagFreeSlots, BAG_BACKPACK) or 0
    out[#out + 1] = string.format("Carrier: %s, %d free bag slots", characterName(), free)
    local unnamed = Org.MissingChests()
    if #unnamed > 0 then out[#out + 1] = "No chest named yet: " .. table.concat(unnamed, ", ") end
    if free < 20 then out[#out + 1] = "This character is short on space. An emptier one will need fewer trips." end
    local state = carrying()
    if state.char and state.char ~= thisCharacter() then
        out[#out + 1] = tostring(state.name) .. " is still carrying items from the last run. Log in on them to finish."
    end
    local carried = {}
    for _, entry in pairs(carriedHere()) do carried[#carried + 1] = entry.name .. " x" .. entry.count .. " > " .. entry.to end
    table.sort(carried)
    if #carried > 0 then
        out[#out + 1] = "\f" .. "Still carrying from the last run\n" .. table.concat(carried, "\n")
    end
    local unidentified = Org.UnidentifiedInBank()
    if unidentified > 0 then
        out[#out + 1] = string.format("It will OPEN %d unidentified survey%s from the bank. This can't be undone, and opened surveys can't be sold at guild traders.", unidentified, unidentified == 1 and "" or "s")
    end
    local plan = Org.OrganizePlan()
    if plan.outdated > 0 then
        out[#out + 1] = "\f" .. "Open your chests first\n" .. plan.outdated .. " items were recorded by an older version. Open each chest once so this preview is complete."
    end
    local text = table.concat(out, "\n")
    local any = false
    for _, chest in ipairs(plan.chests) do
        if #chest.out > 0 or #chest.incoming > 0 then
            any = true
            local lines = { string.format("%s: take out %d, put in %d", chest.title, #chest.out, #chest.incoming) }
            for _, line in ipairs(chest.out) do lines[#lines + 1] = "  Out: " .. line end
            for _, line in ipairs(chest.incoming) do lines[#lines + 1] = "  In: " .. line end
            text = text .. "\f" .. table.concat(lines, "\n")
        end
    end
    if #plan.toBank > 0 or #plan.bankOut > 0 then
        local lines = { string.format("Bank: take out %d, put in %d", #plan.bankOut, #plan.toBank) }
        for _, line in ipairs(plan.bankOut) do lines[#lines + 1] = "  Out: " .. line end
        for _, line in ipairs(plan.toBank) do lines[#lines + 1] = "  In: " .. line end
        text = text .. "\f" .. table.concat(lines, "\n")
    end
    if not any and #plan.toBank == 0 and #plan.bankOut == 0 then text = text .. "\n\nNothing needs moving right now." end
    return text
end

function Org.OrganizePanelText(bag)
    if not catalog or Org.Plan() == "off" then return nil end
    local here = placeName(bag)
    if not here then return nil end
    if moving then return "Moving items..." end
    local putCount = 0
    for _, entry in pairs(carriedHere()) do
        if entry.to == here then putCount = putCount + (entry.stacks or 1) end
    end
    local plan = Org.OrganizePlan()
    local takeCount = #plan.bankOut
    if here ~= BANK then
        takeCount = 0
        for _, chest in ipairs(plan.chests) do
            if chest.job == here then takeCount = #chest.out end
        end
    end
    local lines = {}
    if putCount > 0 or takeCount > 0 then
        lines[1] = string.format("Press X to sort: put in %d, take out %d", putCount, takeCount)
    else
        lines[1] = "Nothing to move here."
    end
    local stop, detail = Org.NextStop()
    if stop and stop ~= here then lines[#lines + 1] = "Next: " .. stop .. " (" .. detail .. ")" end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- What goes where: one page per chest plan
---------------------------------------------------------------------------
function Org.PlanGuideText()
    pcall(Org.RefreshChestJobs)
    local isOn = Org.Plan() ~= "off"
    local missing, repeated = Org.MissingChests(), {}
    for name in pairs(duplicateNames) do repeated[#repeated + 1] = name end
    table.sort(repeated)
    local left = { "Chest plan: " .. (isOn and "ON" or "OFF"), "", "WHAT TO DO NEXT" }
    local function add(line) left[#left + 1] = line end
    if #repeated > 0 then
        add("Two chests have the same name: " .. table.concat(repeated, ", ") .. ".")
        if isOn then add("1. Press A to turn the plan off.") end
        add((isOn and "2. " or "1. ") .. "Open one of them, press X, and give it a missing name.")
    elseif #missing > 0 then
        add("Name your 4 large chests:")
        for _, name in ipairs(PLANS.crafter.large) do add("  " .. name) end
        add("Name your 4 small chests:")
        for _, name in ipairs(PLANS.crafter.small) do add("  " .. name) end
        add("")
        add("Open a chest, press X, type its name.")
    elseif not isOn then
        add("All 8 chests are ready.")
        add("Press A to turn the plan on.")
        add("Then X at the bank or a chest moves items.")
    else
        add("1. Use a character with empty bag slots.")
        add("2. At the bank, on Withdraw, press X.")
        add("3. Chat names the next chest. Open it, press X.")
        add("4. Repeat until chat says Everything is sorted.")
    end
    local right = {}
    local plan = PLANS.crafter
    local function list(title, names)
        right[#right + 1] = title
        for _, name in ipairs(names) do
            local status = chestBagNamed(name) and "Ready" or "NOT NAMED YET"
            if duplicateNames[name] then status = "TWO CHESTS HAVE THIS NAME" end
            right[#right + 1] = string.format("  %s: %s - %s", name, CHEST_CONTENTS[name], status)
        end
    end
    list("Large chests (60 slots)", plan.large)
    list("Small chests (30 slots)", plan.small)
    right[#right + 1] = "Everything else stays in the bank."
    return table.concat(left, "\n") .. "\v" .. table.concat(right, "\n")
end

function Org.OpenPlanGuide()
    local actions = {
        primaryName = function() return Org.Plan() == "off" and "Turn plan on" or "Turn plan off" end,
        primaryVisible = function() return true end,
        primary = function()
            if Org.Plan() == "off" then
                Org.SetPlan("crafter")
                say("Chest plan on.")
            else
                if Org.OrganizeActive() then Org.SetOrganizing(false) end
                Org.SetPlan("off")
                say("Chest plan off.")
            end
        end,
        secondaryVisible = function() return false end,
        secondary = function() end,
        refresh = function()
            local ok, text = pcall(Org.PlanGuideText)
            if ok then pages = Org.Screens(text) end
        end,
    }
    openScreen("Quartermaster: Chest Setup", Org.PlanGuideText, actions)
end

---------------------------------------------------------------------------
-- Stack at the bank
---------------------------------------------------------------------------
function Org.ButtonName()
    return "Stack bank"
end

function Org.PressTidy()
    if BAG_BANK then pcall(StackBag, BAG_BANK) end
    if BAG_SUBSCRIBER_BANK then pcall(StackBag, BAG_SUBSCRIBER_BANK) end
    say("Bank stacked.")
    zo_callLater(function() pcall(Org.ScanAll) end, 1000)
end

function Org.SetButtonCallback(callback) onButtonChange = callback end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
function Org.Init(saved)
    saved.catalog = saved.catalog or { version = 2, defs = {}, locs = {} }
    catalog = saved.catalog
    catalog.jobs = catalog.jobs or {}
    if (catalog.version or 1) < 5 then
        -- Simple, By gear type and Custom are gone; anyone on one goes back to Off.
        if catalog.plan ~= "crafter" then catalog.plan = "off" end
        catalog.custom, catalog.customEdited, catalog.organizeBank = nil, nil, nil
        catalog.version = 5
    end
    pcall(Org.RefreshChestJobs)
    if not EVENT_MANAGER then return end
    local name = "ESOC_QuartermasterOrganizer"
    local openChest
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
            zo_callLater(function()
                Org.ScanAll()
                pcall(reconcile)
                local kinds = Org.CarriedKinds()
                if kinds > 0 then
                    say(string.format("This character is still carrying %d kind%s of item from Organize mode. Selling and container opening are paused. Press X at the bank or a chest to finish.", kinds, kinds == 1 and "" or "s"))
                end
            end, 3000)
        end)
    end
    if EVENT_OPEN_BANK then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_BANK, function(_, bag)
            bag = bag or safe(GetBankingBag)
            if bag and safe(IsHouseBankBag, bag) then
                openChest = bag
                pcall(Org.ScanChest, bag)
                pcall(showPanel, bag)
            elseif bag == BAG_BANK then
                pcall(showPanel, bag)
            end
            buttonChanged()
        end)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        local refreshing = false
        EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
            if bagId ~= openChest or refreshing or moving then return end
            refreshing = true
            zo_callLater(function()
                refreshing = false
                if openChest then
                    pcall(Org.ScanChest, openChest)
                    pcall(showPanel, openChest)
                end
            end, 400)
        end)
    end
    if EVENT_LOOT_UPDATED then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_LOOT_UPDATED, function()
            if openingSurveys and LootAll then pcall(LootAll, true) end
        end)
    end
    if EVENT_CLOSE_BANK then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_BANK, function()
            if openChest then pcall(Org.ScanChest, openChest) end
            openChest = nil
            moving = false
            gearFrozen = false
            zo_callLater(function() pcall(Org.OpenCarriedSurveys) end, 800)
            pcall(hidePanel)
            pcall(Org.ScanAll)
        end)
    end
end
