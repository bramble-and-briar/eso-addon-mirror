-- Set Hunter: a checklist for the gear sets you are farming or buying.
-- Pick pieces in the gamepad Sticker Book (X). The side panel shows Sticker Book progress,
-- reconstruction cost and what is still needed. Guild trader listings you need are marked.

local ADDON_NAME = "ESOCSetHunter"
local SH = {}
ESOC_SetHunter = SH

local GREEN, GOLD, AMBER, GREY = "66DD66", "E8C866", "F0A040", "A0A0A0"
local function colour(hex, text) return "|c" .. hex .. text .. "|r" end

local DEFAULTS = {
    showPanel = true,
    showAtTrader = true,
    autoLock = true,
    autoBind = false,
    showHere = true,
    side = "right",
    height = 0,
    armorTrait = ITEM_TRAIT_TYPE_ARMOR_DIVINES or 0,
    weaponTrait = 0,
    jewelryTrait = 0,
}

local sv, opts
local charId
local bagCache = {}      -- [bag] = list of owned set pieces
local dirtyBags = {}
local lastStates = {}    -- [pieceId] = last state, used to announce crossed-off pieces
local refreshQueued = false
local panel
local pendingLocks = {}  -- new pieces waiting to be locked
local lockClaimed = {}   -- [pieceId] = true once a new copy has been chosen, until the next refresh

local SCAN_BAGS = { BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
local CHARACTER_BAGS = { [BAG_WORN] = true, [BAG_BACKPACK] = true }

local function activeSets() return sv.builds[sv.activeBuild].sets end

---------------------------------------------------------------------------
-- What is wanted
---------------------------------------------------------------------------
local function traitFor(category)
    if category == ITEM_TRAIT_TYPE_CATEGORY_ARMOR then return opts.armorTrait end
    if category == ITEM_TRAIT_TYPE_CATEGORY_WEAPON then return opts.weaponTrait end
    if category == ITEM_TRAIT_TYPE_CATEGORY_JEWELRY then return opts.jewelryTrait end
    return 0
end

-- A piece can have its own trait; otherwise it uses the default for its category.
local function targetTrait(want)
    if want.trait ~= nil then return want.trait end
    return traitFor(want.category)
end

local function traitName(trait)
    if not trait or trait == 0 then return "any trait" end
    return GetString("SI_ITEMTRAITTYPE", trait)
end

local function linkShape(link)
    return GetItemLinkEquipType(link), GetItemLinkArmorType(link), GetItemLinkWeaponType(link)
end

local function sameShape(want, equip, armor, weapon)
    return want.equip == equip and want.armor == armor and want.weapon == weapon
end

local function setIdOf(link)
    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link)
    if hasSet then return setId end
    return nil
end

function SH.IsWanted(setId, pieceId)
    local goal = activeSets()[setId]
    return goal ~= nil and goal.wants[pieceId] ~= nil
end

function SH.ToggleWanted(setId, pieceId, link)
    local goal = activeSets()[setId]
    if goal and goal.wants[pieceId] then
        goal.wants[pieceId] = nil
        lastStates[pieceId] = nil
        sv.bought[pieceId], sv.boughtBase[pieceId] = nil, nil
        if next(goal.wants) == nil then activeSets()[setId] = nil end
    else
        if not goal then
            goal = { wants = {} }
            activeSets()[setId] = goal
        end
        local equip, armor, weapon = linkShape(link)
        goal.wants[pieceId] = {
            equip = equip, armor = armor, weapon = weapon,
            category = GetItemLinkTraitCategory(link),
            name = zo_strformat("<<t:1>>", GetItemLinkName(link)),
        }
    end
    SH.MarkAllDirty()
    SH.Refresh()
end

function SH.DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = SH.DeepCopy(item) end
    return copy
end

-- Replaces the current list, which is what the panel, stations and Sticker Book work from.
function SH.SetCurrentBuild(build)
    sv.builds[sv.activeBuild] = build
    lastStates = {}
    SH.MarkAllDirty()
    SH.Refresh()
end

-- Empties the current list and returns how many pieces were removed. Saved builds aren't touched.
function SH.ClearActiveSets()
    local count = 0
    for _, goal in pairs(activeSets()) do
        for pieceId in pairs(goal.wants) do
            count = count + 1
            sv.bought[pieceId], sv.boughtBase[pieceId] = nil, nil
        end
    end
    SH.SetCurrentBuild({ sets = {} })
    return count
end

-- Before 2.5.0 every build was live, so editing one changed it. Each build with anything in it
-- now becomes a saved copy, and the build you were on becomes the current list.
local CURRENT_KEY = "My Build"
function SH.MigrateBuilds()
    if sv.savedBuilds then return end
    sv.savedBuilds = {}
    for name, build in pairs(sv.builds) do
        if next(build.sets) then sv.savedBuilds[name] = SH.DeepCopy(build) end
    end
    local current = sv.builds[sv.activeBuild] or { sets = {} }
    sv.loadedBuild = sv.savedBuilds[sv.activeBuild] and sv.activeBuild or nil
    sv.builds = { [CURRENT_KEY] = current }
    sv.activeBuild = CURRENT_KEY
end

---------------------------------------------------------------------------
-- What you own
---------------------------------------------------------------------------
local function scanBag(bag)
    local found = {}
    for slot = 0, GetBagSize(bag) - 1 do
        if GetItemId(bag, slot) ~= 0 then
            local link = GetItemLink(bag, slot)
            local setId = setIdOf(link)
            if setId and activeSets()[setId] then
                local equip, armor, weapon = linkShape(link)
                found[#found + 1] = {
                    setId = setId, equip = equip, armor = armor, weapon = weapon,
                    trait = GetItemLinkTraitType(link), bound = IsItemBound(bag, slot),
                }
            end
        end
    end
    return found
end

function SH.MarkAllDirty()
    for _, bag in ipairs(SCAN_BAGS) do dirtyBags[bag] = true end
end

local function updateBags()
    local characterChanged = false
    for _, bag in ipairs(SCAN_BAGS) do
        if dirtyBags[bag] or not bagCache[bag] then
            bagCache[bag] = scanBag(bag)
            dirtyBags[bag] = nil
            if CHARACTER_BAGS[bag] then characterChanged = true end
        end
    end
    if characterChanged then
        local mine = {}
        for bag in pairs(CHARACTER_BAGS) do
            for _, entry in ipairs(bagCache[bag]) do mine[#mine + 1] = entry end
        end
        sv.characters[charId] = mine
    end
end

local function eachOwned(fn)
    for id, list in pairs(sv.characters) do
        if id ~= charId then
            for _, entry in ipairs(list) do fn(entry) end
        end
    end
    for _, bag in ipairs(SCAN_BAGS) do
        for _, entry in ipairs(bagCache[bag] or {}) do fn(entry) end
    end
end

---------------------------------------------------------------------------
-- Status of each wanted piece
---------------------------------------------------------------------------
-- done: have it in the right trait. bind: have it, but it must be bound to fill the Sticker Book.
-- reconstruct: unlocked, can be made with crystals. wrong: owned in another trait, not unlocked.
-- need: nothing yet.
-- Returns the state, copies you have (capped at the number wanted), copies wanted, and copies found.
local function pieceStatus(setId, pieceId, want)
    local target = targetTrait(want)
    local count = want.count or 1
    local unlocked = IsItemSetCollectionPieceUnlocked(pieceId)
    local have, wrong = 0, false
    eachOwned(function(entry)
        if entry.setId == setId and sameShape(want, entry.equip, entry.armor, entry.weapon) then
            if target == 0 or entry.trait == target then have = have + 1 else wrong = true end
        end
    end)
    local found = have
    local bought = sv.bought[pieceId]
    if bought then
        if found > (sv.boughtBase[pieceId] or 0) then
            sv.bought[pieceId], sv.boughtBase[pieceId] = nil, nil
        elseif target == 0 or bought == target then
            have = have + 1
        end
    end
    local state
    if have >= count then
        state = unlocked and "done" or "bind"
    elseif unlocked then
        state = "reconstruct"
    elseif wrong then
        state = "wrong"
    else
        state = "need"
    end
    return state, math.min(have, count), count, found
end

local function pieceState(setId, pieceId, want)
    return (pieceStatus(setId, pieceId, want))
end

local function crystalCost(setId)
    if not CURT_CHAOTIC_CREATIA then return nil end
    local ok, cost = pcall(GetItemReconstructionCurrencyOptionCost, setId, CURT_CHAOTIC_CREATIA)
    if ok and cost and cost > 0 then return cost end
    return nil
end

local ROW = {
    done = function(label) return colour(GREEN, "[x] " .. label) end,
    bind = function(label) return colour(GREEN, "[x] " .. label) .. colour(AMBER, " (bind it)") end,
    reconstruct = function(label) return colour(GOLD, "[  ] " .. label) .. colour(GREY, " (reconstruct)") end,
    wrong = function(label) return colour(AMBER, "[  ] " .. label) .. colour(GREY, " (wrong trait)") end,
    need = function(label) return "[  ] " .. label end,
}

---------------------------------------------------------------------------
-- Short piece names and where pieces come from
---------------------------------------------------------------------------
local SLOTS = {
    { EQUIP_TYPE_HEAD, "Head" }, { EQUIP_TYPE_SHOULDERS, "Shoulders" }, { EQUIP_TYPE_CHEST, "Chest" },
    { EQUIP_TYPE_HAND, "Hands" }, { EQUIP_TYPE_WAIST, "Waist" }, { EQUIP_TYPE_LEGS, "Legs" },
    { EQUIP_TYPE_FEET, "Feet" }, { EQUIP_TYPE_NECK, "Neck" }, { EQUIP_TYPE_RING, "Ring" },
}
local WEAPONS = {
    { WEAPONTYPE_SWORD, "Sword" }, { WEAPONTYPE_AXE, "Axe" }, { WEAPONTYPE_HAMMER, "Mace" },
    { WEAPONTYPE_DAGGER, "Dagger" }, { WEAPONTYPE_TWO_HANDED_SWORD, "Greatsword" },
    { WEAPONTYPE_TWO_HANDED_AXE, "Battle Axe" }, { WEAPONTYPE_TWO_HANDED_HAMMER, "Maul" },
    { WEAPONTYPE_BOW, "Bow" }, { WEAPONTYPE_FIRE_STAFF, "Inferno Staff" }, { WEAPONTYPE_FROST_STAFF, "Ice Staff" },
    { WEAPONTYPE_LIGHTNING_STAFF, "Lightning Staff" }, { WEAPONTYPE_HEALING_STAFF, "Restoration Staff" },
    { WEAPONTYPE_SHIELD, "Shield" },
}
local WEIGHTS = { { ARMORTYPE_LIGHT, "Light" }, { ARMORTYPE_MEDIUM, "Medium" }, { ARMORTYPE_HEAVY, "Heavy" } }

local slotName, slotOrder, weaponName, weaponOrder, weightName = {}, {}, {}, {}, {}
for index, slot in ipairs(SLOTS) do
    if slot[1] then slotName[slot[1]] = slot[2]; slotOrder[slot[1]] = index end
end
for index, weapon in ipairs(WEAPONS) do
    if weapon[1] then weaponName[weapon[1]] = weapon[2]; weaponOrder[weapon[1]] = index end
end
for _, weight in ipairs(WEIGHTS) do
    if weight[1] then weightName[weight[1]] = weight[2] end
end

local function isWeapon(want)
    return want.weapon ~= nil and want.weapon ~= (WEAPONTYPE_NONE or 0)
end

local function shortName(want)
    if isWeapon(want) then return weaponName[want.weapon] or want.name end
    return slotName[want.equip] or want.name
end

local function pieceOrder(want)
    if isWeapon(want) then return 100 + (weaponOrder[want.weapon] or 50) end
    return slotOrder[want.equip] or 99
end

-- Overland drop rules (UESP, Online:Overland Sets).
local DROP_SOURCES = { "World bosses", "Public dungeon bosses", "Delve bosses" }

-- Each zone's repeatable world event (UESP, Online:World Events). Jewelry comes from these and
-- from treasure chests. Zones not listed here, such as Wrothgar, only get "Treasure chests".
local ZONE_EVENTS = {}
local function addZones(event, zones)
    for _, zone in ipairs(zones) do ZONE_EVENTS[zone] = event end
end
addZones("Dark Anchors", {
    "glenumbra", "stormhaven", "rivenspire", "alikr desert", "bangkorai", "stonefalls", "deshaan", "shadowfen",
    "eastmarch", "rift", "auridon", "grahtwood", "greenshade", "malabal tor", "reapers march", "cyrodiil",
})
addZones("Abyssal Geysers", { "summerset" })
addZones("Dragonscours", { "northern elsweyr", "southern elsweyr" })
addZones("Harrowstorms", { "western skyrim", "blackreach greymoor caverns", "reach" })
addZones("Oblivion Portals", { "blackwood", "deadlands" })
addZones("Edifices", { "telvanni peninsula", "apocrypha" })
addZones("Volcanic Vents", { "high isle", "galen" })
addZones("Siege Camps", { "western solstice" })
addZones("Mirrormoor Incursions", { "west weald" })

local function jewelrySource(zone)
    local key = string.lower(zone or "")
    key = string.gsub(key, "[^%a ]", "")
    key = string.gsub(key, "^the ", "")
    local event = ZONE_EVENTS[key]
    if event then return event .. ", chests" end
    return "Treasure chests"
end

local function dropSources(want, jewelryLabel)
    if isWeapon(want) then return { "World bosses", "Public dungeon bosses" } end
    local equip = want.equip
    if equip == EQUIP_TYPE_HEAD or equip == EQUIP_TYPE_CHEST or equip == EQUIP_TYPE_LEGS then return { "World bosses" } end
    if equip == EQUIP_TYPE_SHOULDERS or equip == EQUIP_TYPE_HAND then return { "Public dungeon bosses" } end
    if equip == EQUIP_TYPE_WAIST or equip == EQUIP_TYPE_FEET then return { "Delve bosses" } end
    if equip == EQUIP_TYPE_NECK or equip == EQUIP_TYPE_RING then return { jewelryLabel } end
    return {}
end

-- The Sticker Book's own category, for example "Dungeons: Fungal Grotto I".
local function setLocation(setId)
    local categoryId = GetItemSetCollectionCategoryId(setId)
    if not categoryId or categoryId == 0 then return nil, false, nil end
    local name = zo_strformat("<<t:1>>", GetItemSetCollectionCategoryName(categoryId))
    local parentId = GetItemSetCollectionCategoryParentId(categoryId)
    if not parentId or parentId == 0 then
        return name, string.find(string.lower(name), "overland", 1, true) ~= nil, name
    end
    local parent = zo_strformat("<<t:1>>", GetItemSetCollectionCategoryName(parentId))
    return parent .. ": " .. name, string.find(string.lower(parent), "overland", 1, true) ~= nil, name
end

function SH.BuildPanelText()
    local ids = {}
    for setId in pairs(activeSets()) do ids[#ids + 1] = setId end
    table.sort(ids, function(a, b) return GetItemSetName(a) < GetItemSetName(b) end)

    local lines = {}
    for _, setId in ipairs(ids) do
        local goal = activeSets()[setId]
        local rows, have, total = {}, 0, 0
        local pieces = {}
        for pieceId, want in pairs(goal.wants) do pieces[#pieces + 1] = { id = pieceId, want = want } end
        table.sort(pieces, function(a, b)
            local orderA, orderB = pieceOrder(a.want), pieceOrder(b.want)
            if orderA ~= orderB then return orderA < orderB end
            if (a.want.armor or 0) ~= (b.want.armor or 0) then return (a.want.armor or 0) < (b.want.armor or 0) end
            return a.id < b.id
        end)

        -- Only name the weight when the list has the same slot in two weights
        local weightsBySlot = {}
        for _, piece in ipairs(pieces) do
            local base = shortName(piece.want)
            weightsBySlot[base] = weightsBySlot[base] or {}
            weightsBySlot[base][piece.want.armor or 0] = true
        end

        local location, isOverland, zone = setLocation(setId)
        local jewelryLabel = jewelrySource(zone)
        local missingBySource = {}
        for _, piece in ipairs(pieces) do
            local state, pieceHave, pieceCount = pieceStatus(setId, piece.id, piece.want)
            local label = shortName(piece.want)
            local weightCount = 0
            for _ in pairs(weightsBySlot[label]) do weightCount = weightCount + 1 end
            if weightCount > 1 and weightName[piece.want.armor] then
                label = label .. " (" .. weightName[piece.want.armor] .. ")"
            end
            total = total + pieceCount
            have = have + pieceHave
            if pieceCount > 1 then label = label .. " " .. pieceHave .. "/" .. pieceCount end
            if state ~= "done" and state ~= "bind" then
                for _, source in ipairs(dropSources(piece.want, jewelryLabel)) do
                    missingBySource[source] = missingBySource[source] or {}
                    local names = missingBySource[source]
                    names[#names + 1] = label
                end
            end
            rows[#rows + 1] = ROW[state](label)
            local previous = lastStates[piece.id]
            if previous and previous ~= "done" and previous ~= "bind" and (state == "done" or state == "bind") then
                pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: " .. label .. " crossed off")
            end
            lastStates[piece.id] = state
        end
        lines[#lines + 1] = colour(GOLD, zo_strformat("<<t:1>>", GetItemSetName(setId))) .. "  " .. have .. "/" .. total
            .. colour(GREY, "  Book " .. GetNumItemSetCollectionSlotsUnlocked(setId) .. "/" .. GetNumItemSetCollectionPieces(setId))
        if location then lines[#lines + 1] = colour(GREY, location) end
        for _, row in ipairs(rows) do lines[#lines + 1] = row end
        if isOverland then
            for _, source in ipairs(DROP_SOURCES) do
                if missingBySource[source] then
                    lines[#lines + 1] = colour(GREY, source .. ": " .. table.concat(missingBySource[source], ", "))
                end
            end
            if missingBySource[jewelryLabel] then
                lines[#lines + 1] = colour(GREY, jewelryLabel .. ": " .. table.concat(missingBySource[jewelryLabel], ", "))
            end
        end
        lines[#lines + 1] = ""
    end
    while lines[#lines] == "" do lines[#lines] = nil end
    if #lines > 0 and SH.Workshop then
        for _, line in ipairs(SH.Workshop.PanelLines()) do lines[#lines + 1] = line end
        local title = SH.Workshop.PanelTitle()
        if title then table.insert(lines, 1, colour(GREEN, title)) end
    end
    if SH.Training then
        local kitLines = SH.Training.PanelLines()
        if #kitLines > 0 and #lines > 0 then lines[#lines + 1] = "" end
        for _, line in ipairs(kitLines) do lines[#lines + 1] = line end
    end
    if SH.Here then
        local hereLines = SH.Here.PanelLines()
        if #hereLines > 0 and #lines > 0 then lines[#lines + 1] = "" end
        for _, line in ipairs(hereLines) do lines[#lines + 1] = line end
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Side panel
---------------------------------------------------------------------------
local PANEL_WIDTH, MIN_PANEL_WIDTH, PADDING = 360, 220, 14

local function placePanel()
    if not panel then return end
    panel.window:ClearAnchors()
    if opts.side == "left" then
        panel.window:SetAnchor(LEFT, GuiRoot, LEFT, 24, opts.height)
    else
        panel.window:SetAnchor(RIGHT, GuiRoot, RIGHT, -24, opts.height)
    end
end

local function createPanel()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCSetHunterPanel")
    window:SetDimensions(PANEL_WIDTH, 100)
    window:SetMouseEnabled(false)
    window:SetHidden(true) -- the scene fragment shows it on the game view and at traders

    local root = WINDOW_MANAGER:CreateControl("ESOCSetHunterPanelRoot", window, CT_CONTROL)
    root:SetAnchorFill(window)

    local background = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
    background:SetAnchorFill(root)
    background:SetColor(0, 0, 0, 0.55)

    local label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    label:SetFont("ZoFontGamepad22")
    label:SetColor(0.93, 0.93, 0.9, 1)
    label:SetAnchor(TOPLEFT, root, TOPLEFT, PADDING, PADDING)
    label:SetWidth(PANEL_WIDTH - PADDING * 2)

    panel = { window = window, root = root, label = label }
    panel.fragment = ZO_SimpleSceneFragment:New(window)
    if HUD_SCENE then HUD_SCENE:AddFragment(panel.fragment) end
    if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(panel.fragment) end
    SH.UpdateTraderScene()
    placePanel()
end

function SH.UpdateTraderScene()
    if not panel or not TRADING_HOUSE_GAMEPAD_SCENE then return end
    if opts.showAtTrader and not panel.onTrader then
        TRADING_HOUSE_GAMEPAD_SCENE:AddFragment(panel.fragment)
        panel.onTrader = true
    elseif not opts.showAtTrader and panel.onTrader then
        TRADING_HOUSE_GAMEPAD_SCENE:RemoveFragment(panel.fragment)
        panel.onTrader = false
    end
end

function SH.Refresh()
    updateBags()
    lockClaimed = {}
    local text = SH.BuildPanelText()
    if not panel then return end
    local show = opts.showPanel and text ~= ""
    panel.root:SetHidden(not show)
    if show then
        -- Fit the panel to its text, up to the maximum width (longer lines wrap)
        local maxTextWidth = PANEL_WIDTH - PADDING * 2
        panel.label:SetWidth(maxTextWidth)
        panel.label:SetText(text)
        local textWidth = math.ceil(panel.label:GetTextWidth()) + 2
        textWidth = math.max(MIN_PANEL_WIDTH - PADDING * 2, math.min(textWidth, maxTextWidth))
        panel.label:SetWidth(textWidth)
        panel.window:SetDimensions(textWidth + PADDING * 2, panel.label:GetTextHeight() + PADDING * 2)
    end
end

local function queueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    zo_callLater(function()
        refreshQueued = false
        local ok, err = pcall(SH.Refresh)
        if not ok then pcall(d, "[Set Hunter] " .. tostring(err)) end
    end, 500)
end

---------------------------------------------------------------------------
-- Sticker Book button (X on a highlighted piece)
---------------------------------------------------------------------------
local function selectedPiece()
    local book = GAMEPAD_ITEM_SETS_BOOK
    if not book or not book.gridListPanelList or not book.gridListPanelList:IsActive() then return nil end
    local data = book.gridListPanelList:GetSelectedData()
    if not data or data.isEmptyCell or not data.GetItemLink then return nil end
    return data
end

local function hookStickerBook()
    local book = GAMEPAD_ITEM_SETS_BOOK
    if SH.bookHooked or not book or not book.gridKeybindStripDescriptor then return end
    SH.bookHooked = true
    local descriptor = book.gridKeybindStripDescriptor
    descriptor[#descriptor + 1] = {
        keybind = "UI_SHORTCUT_SECONDARY",
        name = function()
            local data = selectedPiece()
            if data and SH.IsWanted(data:GetSetId(), data:GetId()) then return "Remove from Set Hunter" end
            return "Add to Set Hunter"
        end,
        visible = function() return selectedPiece() ~= nil end,
        callback = function()
            local data = selectedPiece()
            if not data then return end
            SH.ToggleWanted(data:GetSetId(), data:GetId(), data:GetItemLink())
            KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
        end,
    }
    if SH.AutoBind then SH.AutoBind.AddBookKeys(descriptor, selectedPiece) end
end

---------------------------------------------------------------------------
-- Guild trader
---------------------------------------------------------------------------
-- Returns "need", "sticker" or nil for a listing, plus the matching piece id.
function SH.ClassifyListing(link)
    if not link or link == "" then return nil end
    local setId = setIdOf(link)
    local goal = setId and activeSets()[setId]
    if not goal then return nil end
    local equip, armor, weapon = linkShape(link)
    local trait = GetItemLinkTraitType(link)
    local sticker
    for pieceId, want in pairs(goal.wants) do
        if sameShape(want, equip, armor, weapon) then
            local state = pieceState(setId, pieceId, want)
            if state ~= "done" and state ~= "bind" then
                local target = targetTrait(want)
                if target == 0 or trait == target then return "need", pieceId end
                if state == "need" or state == "wrong" then sticker = pieceId end
            end
        end
    end
    if sticker then return "sticker", sticker end
    return nil
end

local function hookTrader()
    local results = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS
    if SH.traderHooked or not results then return end
    SH.traderHooked = true

    local setupRow = results.SetupResultItemRow
    results.SetupResultItemRow = function(self, control, itemData, ...)
        setupRow(self, control, itemData, ...)
        pcall(function()
            if itemData.isGuildSpecificItem then return end
            local kind = SH.ClassifyListing(itemData.itemLink)
            if kind == "need" then
                control.nameLabel:SetText(colour(GREEN, "NEED ") .. control.nameLabel:GetText())
            elseif kind == "sticker" then
                control.nameLabel:SetText(colour(AMBER, "STICKER ") .. control.nameLabel:GetText())
            end
        end)
    end

    local confirm = results.ShowPurchaseItemConfirmation
    results.ShowPurchaseItemConfirmation = function(self, selectedData, ...)
        SH.pendingLink = selectedData and not selectedData.isGuildSpecificItem and selectedData.itemLink or nil
        return confirm(self, selectedData, ...)
    end
end

---------------------------------------------------------------------------
-- Lock a needed piece when it arrives. Only new pickups are locked, so a piece
-- you unlock yourself stays unlocked, and spare copies are left alone.
---------------------------------------------------------------------------
local function pieceToLock(link)
    local kind, pieceId = SH.ClassifyListing(link)
    if kind == "need" then return pieceId end
    -- A guild trader purchase is already crossed off by the time it reaches the bag
    local setId = setIdOf(link)
    local goal = setId and activeSets()[setId]
    if not goal then return nil end
    local equip, armor, weapon = linkShape(link)
    local trait = GetItemLinkTraitType(link)
    for id, want in pairs(goal.wants) do
        if sv.bought[id] == trait and sameShape(want, equip, armor, weapon) then return id end
    end
    return nil
end

local function lockItem(bag, slot)
    if IsProtectedFunction and IsProtectedFunction("SetItemIsPlayerLocked") then
        return pcall(CallSecureProtected, "SetItemIsPlayerLocked", bag, slot, true)
    end
    return pcall(SetItemIsPlayerLocked, bag, slot, true)
end

function SH.FlushLocks()
    if IsUnitInCombat("player") then return end
    local waiting = pendingLocks
    pendingLocks = {}
    for _, entry in ipairs(waiting) do
        if GetItemLink(entry.bag, entry.slot) == entry.link
            and CanItemBePlayerLocked(entry.bag, entry.slot)
            and not IsItemPlayerLocked(entry.bag, entry.slot) then
            local ok, result = lockItem(entry.bag, entry.slot)
            if not ok or result == false then
                pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: couldn't lock a new piece, so lock it yourself")
            end
        end
    end
end

function SH.OnNewItem(bag, slot)
    if not opts.autoLock or bag ~= BAG_BACKPACK then return end
    local link = GetItemLink(bag, slot)
    if not link or link == "" then return end
    local pieceId = pieceToLock(link)
    if not pieceId then return end
    -- Lock as many copies as the build wants, such as two matching rings
    local setId = setIdOf(link)
    local _, have, count = pieceStatus(setId, pieceId, activeSets()[setId].wants[pieceId])
    if sv.bought[pieceId] then have = have - 1 end
    local claimed = lockClaimed[pieceId] or 0
    if have + claimed >= count then return end
    lockClaimed[pieceId] = claimed + 1
    pendingLocks[#pendingLocks + 1] = { bag = bag, slot = slot, link = link }
    SH.FlushLocks()
end

function SH.OnTraderResponse(responseType, result)
    if responseType ~= TRADING_HOUSE_RESULT_PURCHASE_PENDING then return end
    local link = SH.pendingLink
    SH.pendingLink = nil
    if result ~= TRADING_HOUSE_RESULT_SUCCESS or not link then return end
    local kind, pieceId = SH.ClassifyListing(link)
    if kind == "need" then
        local setId = setIdOf(link)
        local _, _, _, found = pieceStatus(setId, pieceId, activeSets()[setId].wants[pieceId])
        sv.bought[pieceId], sv.boughtBase[pieceId] = GetItemLinkTraitType(link), found
        SH.Refresh()
    end
end

---------------------------------------------------------------------------
-- Settings: Settings > Add-Ons > Set Hunter
---------------------------------------------------------------------------
local TRAITS = {
    armorTrait = { "STURDY", "IMPENETRABLE", "REINFORCED", "WELL_FITTED", "TRAINING", "INFUSED", "PROSPEROUS", "DIVINES", "NIRNHONED" },
    weaponTrait = { "POWERED", "CHARGED", "PRECISE", "INFUSED", "DEFENDING", "TRAINING", "SHARPENED", "DECISIVE", "NIRNHONED" },
    jewelryTrait = { "ARCANE", "HEALTHY", "ROBUST", "TRIUNE", "INFUSED", "PROTECTIVE", "SWIFT", "HARMONY", "BLOODTHIRSTY" },
}
local PREFIX = { armorTrait = "ITEM_TRAIT_TYPE_ARMOR_", weaponTrait = "ITEM_TRAIT_TYPE_WEAPON_", jewelryTrait = "ITEM_TRAIT_TYPE_JEWELRY_" }

-- Console LibHarvensAddonSettings passes the whole { name, data } item; other versions pass the data.
local function dropdownValue(item, fallback)
    if type(item) == "table" then item = item.data end
    if item == nil then return fallback end
    return item
end

local function createSettings()
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then return end
    local settings = LHAS:AddAddon("Set Hunter", { allowDefaults = true, allowRefresh = true })

    local function check(label, tooltip, name, after)
        return {
            type = LHAS.ST_CHECKBOX, label = label, tooltip = tooltip, default = DEFAULTS[name],
            getFunction = function() return opts[name] end,
            setFunction = function(v) opts[name] = v; if after then after() end; SH.Refresh() end,
        }
    end
    local sides = { { name = "Right", data = "right" }, { name = "Left", data = "left" } }

    settings:AddSettings({
        { type = LHAS.ST_SECTION, label = "Your list" },
        {
            type = LHAS.ST_BUTTON, label = "Clear all sets", buttonText = "Clear all",
            tooltip = "Empties your current list in one go. Saved builds and your items aren't touched, and pieces already locked stay locked.",
            disable = function() return not SH.Workshop or not SH.Workshop.HasSets() end,
            clickHandler = function()
                SH.Workshop.OfferClearSets(function() pcall(function() settings:UpdateControls() end) end)
            end,
        },
        { type = LHAS.ST_SECTION, label = "Side panel" },
        check("Show the panel", "Show your checklist on the side of the screen.", "showPanel"),
        check("Show at guild traders", "Keep the checklist on screen while you browse a guild trader.", "showAtTrader", SH.UpdateTraderScene),
        check("Show what's needed here", "Lists the Sticker Book pieces you're missing from the zone, dungeon or trial you're in.", "showHere", function() SH.Refresh() end),
        { type = LHAS.ST_LABEL, label = function() return SH.Here and SH.Here.StatusText() or "" end },
        {
            type = LHAS.ST_DROPDOWN, label = "Screen side", items = sides, default = "Right",
            getFunction = function() return opts.side == "left" and "Left" or "Right" end,
            setFunction = function(_, _, item) opts.side = dropdownValue(item, opts.side); placePanel() end,
        },
        {
            type = LHAS.ST_SLIDER, label = "Move up or down", min = -400, max = 400, step = 10, format = "%d", default = 0,
            getFunction = function() return opts.height end,
            setFunction = function(v) opts.height = tonumber(v) or 0; placePanel() end,
        },
        { type = LHAS.ST_SECTION, label = "Protection" },
        check("Lock pieces you need", "When you pick up or buy a piece on your list in the right trait, lock it so it can't be sold, destroyed or deconstructed by accident. Spare copies aren't locked.", "autoLock"),
        check("Auto-bind new pieces", "When you loot a bind-on-equip piece that's missing from your Sticker Book, bind it. Binding can't be undone. Trader purchases, mail and trades are never bound. In the Sticker Book, press L3 to skip a piece or R3 to skip a whole set.", "autoBind", function()
            pcall(function() settings:UpdateControls() end)
        end),
        { type = LHAS.ST_LABEL, label = function() return SH.AutoBind and SH.AutoBind.StatusText() or "" end },
        {
            type = LHAS.ST_BUTTON, label = "Clear auto-bind exceptions", buttonText = "Clear",
            tooltip = function() return SH.AutoBind and SH.internal and SH.AutoBind.ExceptionsText() or "" end,
            disable = function() return not SH.AutoBind or not SH.AutoBind.HasExceptions() end,
            clickHandler = function()
                SH.AutoBind.OfferClear(function() pcall(function() settings:UpdateControls() end) end)
            end,
        },
    })
end

---------------------------------------------------------------------------
-- Start up
---------------------------------------------------------------------------
local function onPlayerActivated()
    hookStickerBook()
    hookTrader()
    SH.UpdateTraderScene()
    SH.MarkAllDirty()
    queueRefresh()
end

local function onLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("ESOCSetHunter_SV", 1, nil, { characters = {}, bought = {}, options = {} })
    sv.characters, sv.bought, sv.options = sv.characters or {}, sv.bought or {}, sv.options or {}
    sv.boughtBase = sv.boughtBase or {}
    -- Version 1 kept one list; it becomes the first named build
    if not sv.builds then
        sv.builds = { ["My Build"] = { sets = sv.sets or {} } }
        sv.activeBuild = "My Build"
        sv.sets = nil
    end
    if not sv.builds[sv.activeBuild] then sv.activeBuild = next(sv.builds) end
    SH.MigrateBuilds()
    opts = sv.options
    for key, value in pairs(DEFAULTS) do
        if opts[key] == nil then opts[key] = value end
    end
    charId = GetCurrentCharacterId()
    SH.MarkAllDirty()

    SH.internal = {
        sv = sv, opts = opts, ActiveSets = activeSets, TargetTrait = targetTrait, TraitName = traitName,
        PieceState = pieceState, PieceStatus = pieceStatus, DEFAULTS = DEFAULTS, ShortName = shortName, PieceOrder = pieceOrder, IsWeapon = isWeapon,
        SetIdOf = setIdOf, LinkShape = linkShape, SameShape = sameShape, CrystalCost = crystalCost,
        DropdownValue = dropdownValue, Colour = colour, TRAITS = TRAITS, PREFIX = PREFIX,
    }
    createPanel()
    createSettings()
    if SH.Workshop then SH.Workshop.Init() end
    if SH.AutoBind then SH.AutoBind.Init() end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_OPEN_TRADING_HOUSE, function() hookTrader(); SH.UpdateTraderScene() end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
        pcall(SH.OnTraderResponse, responseType, result)
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId, slotIndex, isNewItem)
        if isNewItem then pcall(SH.OnNewItem, bagId, slotIndex) end
        dirtyBags[bagId] = true
        queueRefresh()
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then
            pcall(SH.FlushLocks)
            if SH.AutoBind then pcall(SH.AutoBind.Flush) end
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ITEM_SET_COLLECTION_UPDATED, queueRefresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ITEM_SET_COLLECTIONS_UPDATED, queueRefresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED, queueRefresh)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onLoaded)
