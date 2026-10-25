GridPadInventory = GridPadInventory or {}

local GPI = GridPadInventory
local ADDON_NAME = "GridPadInventory"

-- ESO look-and-feel constants. Colors sampled from the gamepad UI: near-black
-- blue interior, muted steel edges, and the signature ZOS gold for headers/selection.
local ESO = {
    -- interior fills
    bgR = 0.055, bgG = 0.065, bgB = 0.085, bgA = 0.94,        -- window background
    panelR = 0.075, panelG = 0.085, panelB = 0.11, panelA = 0.96, -- panels
    cellR = 0.11, cellG = 0.12, cellB = 0.145, cellA = 0.95,  -- grid cells
    -- edges
    edgeR = 0.42, edgeG = 0.36, edgeB = 0.24, edgeA = 1,      -- muted gold-steel edge
    edgeDimR = 0.24, edgeDimG = 0.26, edgeDimB = 0.30, edgeDimA = 1,
    -- text
    goldR = 1.00, goldG = 0.79, goldB = 0.30,                 -- ZOS gold (headers/selection)
    textR = 0.86, textG = 0.86, textB = 0.82,                 -- normal body text
    dimR = 0.55, dimG = 0.57, dimB = 0.60,                    -- muted/secondary
}

GPI.version = "1.45.0"
GPI.addOnVersion = 164 -- keep in step with ## AddOnVersion in GridPadInventory.txt
GPI.zoning = false -- true between PLAYER_DEACTIVATED and PLAYER_ACTIVATED (load screen)
GPI.cols = 10
GPI.rows = 6
GPI.pageSize = GPI.cols * GPI.rows
GPI.cellSize = 72
GPI.cellGap = 8
GPI.maxCells = 12 * 10 -- allocate enough cells for the densest preset
GPI.selectedIndex = 1
GPI.simpleView = false -- compact icon-only grid, panels hidden, filter icon bar
-- Geometry presets. "full" is the classic layout; "simple" is denser and panel-free.
GPI.layoutFull = { cols = 10, rows = 6, cellSize = 72, cellGap = 8, gridX = 426, gridY = 150 }
GPI.layoutSimple = { cols = 12, rows = 10, cellSize = 52, cellGap = 4, gridX = 0, gridY = 120, rightPin = true, marginRight = 8, marginTop = 70, rightShift = 0 }
GPI.selZone = "grid" -- "grid" (backpack) or "doll" (character panel)
GPI.dollIndex = 1
GPI.showItemInfo = false -- LT: swap the tooltip for the item-info + character-stats panel
GPI.currentPage = 0
GPI.items = {}
GPI.allItems = {}
GPI.craftBagItems = nil   -- lazily built on first craft bag visit
GPI.craftBagDirty = true
GPI.craftBagStackCount = 0
GPI.bagMode = "inventory" -- "inventory" (backpack + worn) or "craft" (BAG_VIRTUAL)
GPI.craftFilterIndex = 1  -- craft bag remembers its own tab independently
GPI.filterIndex = 1
GPI.keybindsAdded = false
GPI.pendingRefresh = false
GPI.initialized = false
GPI.sceneHooksInstalled = false
GPI.inputHookInstalled = false
GPI.lastInputAction = nil
GPI.lastInputAt = 0
GPI.inputDebounceMs = 85
GPI.lastEquipAttempt = nil
GPI.lastEquipTargetSlot = nil
GPI.openedFromInventoryScene = false
GPI.autoReplaceGamepadInventory = true
GPI.showEquippedSection = true
GPI.showEquippedInGrid = false
GPI.equipLog = {}
GPI.equipInFlight = false
GPI.equipStartedAt = 0
GPI.debugMode = false
GPI.tipScale = 1.1
GPI.tipWidth = 416
GPI.tipPad = 26 -- extra gold-box margin per side; text wrap width stays ZOS-native
GPI.compareOpen = false
GPI.backpackItemCount = 0
GPI.equippedItemCount = 0
GPI.coverNativeInventory = true
GPI.showKeybindStrip = true
GPI.useNativeTooltip = true
GPI.hideNativeControls = true
GPI.nativeControlsHidden = false
GPI.nativeControlStates = {}

local INVENTORY_SCENE_NAMES = {
    "gamepad_inventory_root", -- current ZOS gamepad inventory root scene name used by gamepad inventory replacements
    "gamepad_inventory",      -- fallback for older/newer naming
}

-- These are best-effort native gamepad inventory/control names seen across ESO UI builds.
-- If ZOS renames one, the full-screen modal cover still hides the native UI.
local NATIVE_INVENTORY_CONTROL_NAMES = {
    "ZO_GamepadTooltipTopLevel", -- quadrant tooltip backgrounds (the vertical bars)
    "ZO_GamepadInventory",
    "ZO_GamepadInventoryTopLevel",
    "ZO_GamepadInventoryRoot",
    "ZO_GamepadInventoryPanel",
    "ZO_GamepadInventoryMenu",
    "ZO_GamepadInventoryCategories",
    "ZO_GamepadInventoryCategoryList",
    "ZO_GamepadInventoryList",
    "ZO_GamepadInventoryItemList",
    "ZO_GamepadInventoryBackpack",
    "ZO_GamepadInventoryHeader",
    "ZO_GamepadInventoryInfo",
}

-- Native gamepad banking scene roots (verified from the live client XML). Hidden
-- while our two-pane bank is up so the native list/tooltip don't bleed through.
local NATIVE_BANKING_CONTROL_NAMES = {
    "ZO_GamepadBankingTopLevel",
    "ZO_GamepadBankingBuyBankSpaceTopLevel",
    "ZO_GamepadBanking",
}

local NATIVE_KEYBIND_CONTROL_NAMES = {
    "ZO_KeybindStripControl",
    "ZO_KeybindStripControlContainer",
    "ZO_GamepadKeybindStripControl",
}

local EQUIPPED_SLOT_DEFS = {
    { var = "EQUIP_SLOT_HEAD", name = "Head" },
    { var = "EQUIP_SLOT_SHOULDERS", name = "Shoulders" },
    { var = "EQUIP_SLOT_CHEST", name = "Chest" },
    { var = "EQUIP_SLOT_HAND", name = "Hands" },
    { var = "EQUIP_SLOT_WAIST", name = "Waist" },
    { var = "EQUIP_SLOT_LEGS", name = "Legs" },
    { var = "EQUIP_SLOT_FEET", name = "Feet" },
    { var = "EQUIP_SLOT_NECK", name = "Neck" },
    { var = "EQUIP_SLOT_RING1", name = "Ring 1" },
    { var = "EQUIP_SLOT_RING2", name = "Ring 2" },
    { var = "EQUIP_SLOT_COSTUME", name = "Costume" },
    { var = "EQUIP_SLOT_MAIN_HAND", name = "Main Hand" },
    { var = "EQUIP_SLOT_OFF_HAND", name = "Off Hand" },
    { var = "EQUIP_SLOT_POISON", name = "Poison" },
    { var = "EQUIP_SLOT_BACKUP_MAIN", name = "Backup Main" },
    { var = "EQUIP_SLOT_BACKUP_OFF", name = "Backup Off" },
    { var = "EQUIP_SLOT_BACKUP_POISON", name = "Backup Poison" },
}

local EQUIPPED_SLOT_INFOS = nil
local function GetEquippedSlotInfos()
    if EQUIPPED_SLOT_INFOS then return EQUIPPED_SLOT_INFOS end
    EQUIPPED_SLOT_INFOS = {}
    for i = 1, #EQUIPPED_SLOT_DEFS do
        local def = EQUIPPED_SLOT_DEFS[i]
        local slotId = _G and _G[def.var]
        if slotId ~= nil then
            table.insert(EQUIPPED_SLOT_INFOS, { slotId = slotId, name = def.name })
        end
    end
    return EQUIPPED_SLOT_INFOS
end

local function IsEquipTypeUsable(equipType)
    if equipType == nil then return false end
    if EQUIP_TYPE_INVALID ~= nil and equipType == EQUIP_TYPE_INVALID then return false end
    if equipType == 0 then return false end
    return true
end


-- GridPad filters now mirror the default gamepad inventory categories as closely as possible
-- inside a modal/grid layout. ESO's native gamepad inventory builds a category list with
-- Supplies, Materials, Consumables, Furnishing, Companion Items, Quest Items, then equipment
-- slots grouped under visual categories. GridPad keeps All/Junk/Worn as convenience filters too.
local FILTER_DEFS = {
    { key = "all", label = "All", mode = "all" },
    { key = "new", label = "New", mode = "new" },
    { key = "supplies", label = "Supplies", mode = "supplies", stringId = "SI_INVENTORY_SUPPLIES" },
    { key = "materials", label = "Materials", mode = "itemFilterType", itemFilterTypeVar = "ITEMFILTERTYPE_CRAFTING" },
    { key = "consumables", label = "Consumables", mode = "itemFilterType", itemFilterTypeVar = "ITEMFILTERTYPE_QUICKSLOT" },
    { key = "furnishings", label = "Furnishings", mode = "itemFilterType", itemFilterTypeVar = "ITEMFILTERTYPE_FURNISHING" },
    { key = "glyphs", label = "Glyphs", mode = "glyphs" },
    { key = "companion", label = "Companion Items", mode = "itemFilterType", itemFilterTypeVar = "ITEMFILTERTYPE_COMPANION" },
    { key = "quest", label = "Quest Items", mode = "itemFilterType", itemFilterTypeVar = "ITEMFILTERTYPE_QUEST", quest = true },
    { key = "weapons", label = "Weapons", mode = "visual", visual = "weapons" },
    { key = "apparel", label = "Apparel", mode = "visual", visual = "apparel" },
    { key = "accessories", label = "Accessories", mode = "visual", visual = "accessories" },
    { key = "mainhand", label = "Main Hand", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_MAIN_HAND" },
    { key = "offhand", label = "Off Hand", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_OFF_HAND" },
    { key = "backupmain", label = "Backup Main", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_BACKUP_MAIN" },
    { key = "backupoff", label = "Backup Off", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_BACKUP_OFF" },
    { key = "head", label = "Head", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_HEAD" },
    { key = "shoulders", label = "Shoulders", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_SHOULDERS" },
    { key = "chest", label = "Chest", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_CHEST" },
    { key = "hands", label = "Hands", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_HAND" },
    { key = "waist", label = "Waist", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_WAIST" },
    { key = "legs", label = "Legs", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_LEGS" },
    { key = "feet", label = "Feet", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_FEET" },
    { key = "neck", label = "Neck", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_NECK" },
    { key = "ring1", label = "Ring 1", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_RING1" },
    { key = "ring2", label = "Ring 2", mode = "equipSlot", equipSlotVar = "EQUIP_SLOT_RING2" },
    { key = "junk", label = "Junk", mode = "junk" },
    { key = "worn", label = "Equipped", mode = "worn" },
}

-- Main-category filter icons for the simple-view top bar. `key` matches a
-- FILTER_DEFS entry; textures are ESO's own gamepad inventory category icons.
-- Uses ESO's keyboard inventory tab-icon set (the same icons shown across the top of
-- the default inventory), which has a complete, verified texture for every category
-- including jewelry and junk, which the gamepad icon set does not provide.
-- Filter bar icons. Six use ESO's keyboard inventory tab-icon set; jewelry,
-- furnishings, and quest have no keyboard tab icon in this client, so they use the
-- verified gamepad icons (which render correctly, with slightly different shading).
local FILTER_ICON_BAR = {
    { key = "all",         icon = "EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds" },
    -- Same "!" star the grid draws on new items (already proven by the cell badge).
    { key = "new",         icon = "EsoUI/Art/Inventory/newItem_icon.dds" },
    { key = "weapons",     icon = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds" },
    { key = "apparel",     icon = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds" },
    { key = "accessories", icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds" },
    { key = "consumables", icon = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds" },
    { key = "materials",   icon = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds" },
    { key = "glyphs",      icon = "EsoUI/Art/Crafting/crafting_enchanting_glyphSlot_pentagon.dds" },
    { key = "furnishings", icon = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_furnishings.dds" },
    { key = "quest",       icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quest.dds" },
    { key = "worn",        icon = "EsoUI/Art/Inventory/inventory_icon_equipped.dds" },
    { key = "junk",        icon = "EsoUI/Art/Inventory/inventory_tabIcon_junk_up.dds" },
}

-- Craft bag tab set (BAG_VIRTUAL). Selected via the Bag Type button, not the main
-- filter row -- the craft bag is a separate bag, not a category of the backpack.
-- Every entry carries craftBag = true so ItemMatchesFilter can keep the backpack and
-- craft bag universes from ever bleeding into each other.
local CRAFT_FILTER_DEFS = {
    { key = "cb_all",         label = "All",                 mode = "all",            craftBag = true },
    { key = "cb_blacksmith",  label = "Blacksmithing",       mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_BLACKSMITHING",        craftGroup = "blacksmith" },
    { key = "cb_clothing",    label = "Clothing",            mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_CLOTHING",             craftGroup = "clothing" },
    { key = "cb_woodworking", label = "Woodworking",         mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_WOODWORKING",          craftGroup = "woodworking" },
    { key = "cb_jewelry",     label = "Jewelry Crafting",    mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_JEWELRYCRAFTING",      craftGroup = "jewelry" },
    { key = "cb_alchemy",     label = "Alchemy",             mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_ALCHEMY",              craftGroup = "alchemy" },
    { key = "cb_enchanting",  label = "Enchanting",          mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_ENCHANTING",           craftGroup = "enchanting" },
    { key = "cb_provisioning",label = "Provisioning",        mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_PROVISIONING",         craftGroup = "provisioning" },
    { key = "cb_style",       label = "Style Materials",     mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_STYLE_MATERIALS",      craftGroup = "style" },
    { key = "cb_traits",      label = "Trait Items",         mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_TRAIT_ITEMS",          craftGroup = "traits" },
    { key = "cb_furnishing",  label = "Furnishing Materials",mode = "itemFilterType", craftBag = true, itemFilterTypeVar = "ITEMFILTERTYPE_FURNISHING_MATERIALS", craftGroup = "furnishing" },
}

-- Icon row for the craft bag tabs. ESO ships a craft bag tab-icon set at
-- inventory_tabIcon_Craftbag_<category>_up.dds; the seven station icons there are
-- confirmed in use by AdvancedFilters, and inventory_tabIcon_all_up.dds plus
-- gp_crafting_menuIcon_furnishings.dds are already proven by GridPad's own inventory row.
--
-- A tab with NO `icon` is deliberately drawn as its two-letter `abbr` instead. That is
-- not a failure path: ESO renders a WRONG texture path as a white box rather than
-- nothing, so there is no reliable way to detect a bad guess at runtime -- probing
-- GetTextureFileDimensions reports success for the placeholder. Guessing therefore
-- produces white squares, which is worse than an honest text tab. Jewelry Crafting and
-- Trait Items have no path I can confirm (AdvancedFilters shipped its own art for
-- traits, which suggests ESO has none), so they stay as text until a path is verified
-- in-game via /gpi icons.
local CB_ICON = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_%s_up.dds"
local CRAFT_FILTER_ICON_BAR = {
    { key = "cb_all",          abbr = "ALL", icon = "EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds" },
    { key = "cb_blacksmith",   abbr = "BS",  icon = string.format(CB_ICON, "blacksmithing") },
    { key = "cb_clothing",     abbr = "CL",  icon = string.format(CB_ICON, "clothing") },
    { key = "cb_woodworking",  abbr = "WW",  icon = string.format(CB_ICON, "woodworking") },
    { key = "cb_jewelry",      abbr = "JW",  candidates = { string.format(CB_ICON, "jewelrycrafting"), string.format(CB_ICON, "jewelry") } },
    { key = "cb_alchemy",      abbr = "AL",  icon = string.format(CB_ICON, "alchemy") },
    { key = "cb_enchanting",   abbr = "EN",  icon = string.format(CB_ICON, "enchanting") },
    { key = "cb_provisioning", abbr = "PR",  icon = string.format(CB_ICON, "provisioning") },
    { key = "cb_style",        abbr = "ST",  icon = string.format(CB_ICON, "styleMaterial") },
    { key = "cb_traits",       abbr = "TR",  candidates = { string.format(CB_ICON, "trait"), string.format(CB_ICON, "traitItems") } },
    { key = "cb_furnishing",   abbr = "FN",  icon = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_furnishings.dds" },
}

-- Resolve a row entry to the texture it should draw, honouring any saved override
-- from /gpi icon. Returns nil when the tab should draw its text abbreviation.
local function ResolvedIconPath(sv, entry)
    if not entry then return nil end
    local override = sv and sv.iconOverrides and sv.iconOverrides[entry.key]
    if type(override) == "string" and override ~= "" then
        -- Second return means "letters were asked for explicitly", which must beat the
        -- representative-item fallback -- otherwise /gpi icon <key> text does nothing.
        if override == "text" then return nil, true end
        return override
    end
    return entry.icon
end

local BOTTOM_BUTTON_UPGRADE, BOTTOM_BUTTON_BAGTYPE, BOTTOM_BUTTON_SORT = 1, 2, 3
local BOTTOM_BUTTON_COUNT = 3

-- Enumerate global NAMES matching any pattern, without ever touching their values.
-- Touching a protected global (SelectSlotItem, RequestMoveItem, ...) raises, so the
-- whole walk is pcall-wrapped and value reads are deferred to SafeGlobalKind below.
local function ScanGlobalNames(patterns)
    local out = {}
    local ok = pcall(function()
        for k in pairs(_G) do
            local ks = tostring(k)
            for i = 1, #patterns do
                if ks:find(patterns[i]) then
                    out[#out + 1] = ks
                    break
                end
            end
        end
    end)
    table.sort(out)
    return out, ok
end

-- Classify a single global by name without letting a protected read escape.
local function SafeGlobalKind(name)
    local ok, kind = pcall(function() return type(rawget(_G, name)) end)
    if not ok then return "protected" end
    if kind == "nil" then
        ok, kind = pcall(function() return type(_G[name]) end)
        if not ok then return "protected" end
    end
    return kind
end

-- Numeric value of a global, or nil if it is not a plain number (or is protected).
local function SafeGlobalNumber(name)
    local ok, v = pcall(function() return rawget(_G, name) end)
    if not ok or type(v) ~= "number" then return nil end
    return v
end

-- Hotbar categories, probed by name. pairs(_G) returns nothing useful in ESO -- the
-- globals sit behind a proxy __index -- so scanning found "0 related constants" on a
-- client that plainly has them. Direct lookup is the only thing that works.
local KNOWN_HOTBAR_CATEGORIES = {
    "HOTBAR_CATEGORY_QUICKSLOT_WHEEL",
    "HOTBAR_CATEGORY_QUICKSLOT_WHEEL_SUPPLIES",
    "HOTBAR_CATEGORY_QUICKSLOT_WHEEL_QUEST_ITEMS",
    "HOTBAR_CATEGORY_QUICKSLOT_WHEEL_ALLY",
    "HOTBAR_CATEGORY_QUICKSLOT_WHEEL_EMOTE",
    "HOTBAR_CATEGORY_QUICKSLOT_WHEEL_TOOL",
    "HOTBAR_CATEGORY_PRIMARY",
    "HOTBAR_CATEGORY_BACKUP",
    "HOTBAR_CATEGORY_OVERRIDE",
    "HOTBAR_CATEGORY_WEREWOLF",
    "HOTBAR_CATEGORY_TEMPORARY",
    "HOTBAR_CATEGORY_COMPANION",
    "HOTBAR_CATEGORY_ASSISTANT",
}

local function ConstantValue(name)
    if _G then return _G[name] end
    return nil
end

local function ValueMatchesAnyConstant(value, names)
    if value == nil then return false end
    for i = 1, #names do
        local constant = ConstantValue(names[i])
        if constant ~= nil and value == constant then return true end
    end
    return false
end

local function IsJewelryEquipType(equipType)
    return ValueMatchesAnyConstant(equipType, { "EQUIP_TYPE_NECK", "EQUIP_TYPE_RING" })
end

local function IsGlyphItemType(itemType)
    return ValueMatchesAnyConstant(itemType, {
        "ITEMTYPE_GLYPH_WEAPON",
        "ITEMTYPE_GLYPH_ARMOR",
        "ITEMTYPE_GLYPH_JEWELRY",
    })
end

local function IsConsumableItemType(itemType)
    return ValueMatchesAnyConstant(itemType, {
        "ITEMTYPE_POTION",
        "ITEMTYPE_POISON",
        "ITEMTYPE_FOOD",
        "ITEMTYPE_DRINK",
        "ITEMTYPE_RECIPE",
        "ITEMTYPE_RACIAL_STYLE_MOTIF",
        "ITEMTYPE_MASTER_WRIT",
        "ITEMTYPE_CONTAINER",
        "ITEMTYPE_CROWN_ITEM",
        "ITEMTYPE_AVA_REPAIR",
        "ITEMTYPE_SIEGE",
    })
end

local function IsMaterialItemType(itemType)
    return ValueMatchesAnyConstant(itemType, {
        "ITEMTYPE_BLACKSMITHING_BOOSTER",
        "ITEMTYPE_BLACKSMITHING_MATERIAL",
        "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",
        "ITEMTYPE_CLOTHIER_BOOSTER",
        "ITEMTYPE_CLOTHIER_MATERIAL",
        "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
        "ITEMTYPE_WOODWORKING_BOOSTER",
        "ITEMTYPE_WOODWORKING_MATERIAL",
        "ITEMTYPE_WOODWORKING_RAW_MATERIAL",
        "ITEMTYPE_JEWELRYCRAFTING_BOOSTER",
        "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
        "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER",
        "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",
        "ITEMTYPE_ENCHANTING_RUNE_ASPECT",
        "ITEMTYPE_ENCHANTING_RUNE_ESSENCE",
        "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
        "ITEMTYPE_INGREDIENT",
        "ITEMTYPE_RAW_MATERIAL",
        "ITEMTYPE_STYLE_MATERIAL",
        "ITEMTYPE_WEAPON_BOOSTER",
        "ITEMTYPE_ARMOR_BOOSTER",
        "ITEMTYPE_FURNISHING_MATERIAL",
    })
end

local function IsFurnishingItemType(itemType)
    return ValueMatchesAnyConstant(itemType, {
        "ITEMTYPE_FURNISHING",
        "ITEMTYPE_FURNISHING_MATERIAL",
    })
end

local function SafeCallMulti(fn, ...)
    if type(fn) ~= "function" then return end
    local packed = { pcall(fn, ...) }
    if packed[1] then
        return unpack(packed, 2)
    end
    return
end

-- Lua 5.1-safe packed call: returns a table of the function's return values and the
-- accurate count (select("#") preserves interior/trailing nils; table.pack is 5.2+).
local function SafeCallPacked(fn, ...)
    if type(fn) ~= "function" then return {}, 0 end
    local function collect(ok, ...)
        if not ok then return {}, 0 end
        return { ... }, select("#", ...)
    end
    return collect(pcall(fn, ...))
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result1, result2, result3, result4, result5, result6, result7, result8, result9, result10 = pcall(fn, ...)
    if ok then
        return result1, result2, result3, result4, result5, result6, result7, result8, result9, result10
    end
    return nil
end

local function GetFilterConstant(def)
    if not def then return nil end
    if def.itemFilterTypeVar then return ConstantValue(def.itemFilterTypeVar) end
    return nil
end

local function GetEquipSlotFromDef(def)
    if not def then return nil end
    if def.equipSlot ~= nil then return def.equipSlot end
    if def.equipSlotVar then return ConstantValue(def.equipSlotVar) end
    return nil
end

local function GetFilterLabel(def)
    if not def then return "All" end

    local filterType = GetFilterConstant(def)
    if filterType ~= nil and GetString then
        local localized = SafeCall(GetString, "SI_ITEMFILTERTYPE", filterType)
        if localized and localized ~= "" then return localized end
    end

    local equipSlot = GetEquipSlotFromDef(def)
    if equipSlot ~= nil and GetString then
        local equipName = SafeCall(GetString, "SI_EQUIPSLOT", equipSlot)
        if equipName and equipName ~= "" then return equipName end
    end

    if def.stringId and GetString then
        local localized = SafeCall(GetString, _G and _G[def.stringId] or def.stringId)
        if localized and localized ~= "" then return localized end
    end

    return def.label or def.key or "Filter"
end

-- Where an item can LEGALLY sit. This table is authoritative for every slot it lists.
--
-- v1.45: ZO_Character_DoesEquipSlotUseEquipType is NOT a legality check. It answers
-- "which worn slots does equipping this displace?", so it says a TWO-HANDED weapon
-- "uses" the OFF-HAND slot (equipping a staff empties your off-hand). Trusting it made
-- GridPad treat the off-hand as an empty slot a staff fits -- whenever a two-hander was
-- already equipped the off-hand reads empty, so it was even the PREFERRED target. The
-- staff was then fed into CompareBagItemToCurrentlyEquipped / RequestEquipItem against
-- EQUIP_SLOT_OFF_HAND, which leaves the client showing a two-hander in the off-hand
-- ("IF EQUIPPED: Off Hand", a staff in the off-hand doll slot) and crashes the client
-- the next time the character model is rebuilt -- e.g. summoning a companion.
-- The ZO helper is now only consulted for slots this table does not cover.
local LEGAL_SLOT_EQUIP_TYPES = {
    { slot = "EQUIP_SLOT_HEAD", equipTypes = { "EQUIP_TYPE_HEAD" } },
    { slot = "EQUIP_SLOT_SHOULDERS", equipTypes = { "EQUIP_TYPE_SHOULDERS", "EQUIP_TYPE_SHOULDER" } },
    { slot = "EQUIP_SLOT_CHEST", equipTypes = { "EQUIP_TYPE_CHEST" } },
    { slot = "EQUIP_SLOT_HAND", equipTypes = { "EQUIP_TYPE_HAND" } },
    { slot = "EQUIP_SLOT_WAIST", equipTypes = { "EQUIP_TYPE_WAIST" } },
    { slot = "EQUIP_SLOT_LEGS", equipTypes = { "EQUIP_TYPE_LEGS" } },
    { slot = "EQUIP_SLOT_FEET", equipTypes = { "EQUIP_TYPE_FEET" } },
    { slot = "EQUIP_SLOT_NECK", equipTypes = { "EQUIP_TYPE_NECK" } },
    { slot = "EQUIP_SLOT_RING1", equipTypes = { "EQUIP_TYPE_RING" } },
    { slot = "EQUIP_SLOT_RING2", equipTypes = { "EQUIP_TYPE_RING" } },
    { slot = "EQUIP_SLOT_COSTUME", equipTypes = { "EQUIP_TYPE_COSTUME" } },
    { slot = "EQUIP_SLOT_MAIN_HAND", equipTypes = { "EQUIP_TYPE_ONE_HAND", "EQUIP_TYPE_TWO_HAND", "EQUIP_TYPE_MAIN_HAND" } },
    { slot = "EQUIP_SLOT_BACKUP_MAIN", equipTypes = { "EQUIP_TYPE_ONE_HAND", "EQUIP_TYPE_TWO_HAND", "EQUIP_TYPE_MAIN_HAND" } },
    -- No TWO_HAND here, ever: a two-hander lives in the main-hand slot only.
    { slot = "EQUIP_SLOT_OFF_HAND", equipTypes = { "EQUIP_TYPE_ONE_HAND", "EQUIP_TYPE_OFF_HAND", "EQUIP_TYPE_SHIELD" } },
    { slot = "EQUIP_SLOT_BACKUP_OFF", equipTypes = { "EQUIP_TYPE_ONE_HAND", "EQUIP_TYPE_OFF_HAND", "EQUIP_TYPE_SHIELD" } },
    { slot = "EQUIP_SLOT_POISON", equipTypes = { "EQUIP_TYPE_POISON" } },
    { slot = "EQUIP_SLOT_BACKUP_POISON", equipTypes = { "EQUIP_TYPE_POISON" } },
}

local function DoesEquipSlotUseItem(equipSlot, item)
    if equipSlot == nil or not item then return false end
    if type(equipSlot) == "number" and equipSlot < 0 then return false end

    if item.bagId == BAG_WORN and item.slotIndex == equipSlot then
        return true
    end

    -- Belt and braces for the crash above: a two-hander is never legal outside the
    -- two main-hand slots, whatever any table or helper claims.
    if ValueMatchesAnyConstant(item.equipType, { "EQUIP_TYPE_TWO_HAND" })
        and not ValueMatchesAnyConstant(equipSlot, { "EQUIP_SLOT_MAIN_HAND", "EQUIP_SLOT_BACKUP_MAIN" }) then
        return false
    end

    for i = 1, #LEGAL_SLOT_EQUIP_TYPES do
        local rule = LEGAL_SLOT_EQUIP_TYPES[i]
        if ConstantValue(rule.slot) == equipSlot then
            return ValueMatchesAnyConstant(item.equipType, rule.equipTypes)
        end
    end

    -- Slot not in the table (a future slot type): fall back to the ZO helper.
    if ZO_Character_DoesEquipSlotUseEquipType and item.equipType ~= nil then
        local matches = SafeCall(ZO_Character_DoesEquipSlotUseEquipType, equipSlot, item.equipType)
        if matches ~= nil then return matches == true end
    end

    return false
end

local function DoesItemMatchNativeItemFilter(item, filterType)
    if not item or filterType == nil then return false end

    -- Mirror the native gamepad inventory first: native itemData has filterData,
    -- and ZO_InventoryUtils_DoesNewItemMatchFilterType keys off that data.
    if item.filterData then
        for i = 1, #item.filterData do
            if item.filterData[i] == filterType then return true end
        end
    end

    if ZO_InventoryUtils_DoesNewItemMatchFilterType then
        local matches = SafeCall(ZO_InventoryUtils_DoesNewItemMatchFilterType, item, filterType)
        if matches ~= nil then return matches == true end
    end

    if filterType == ConstantValue("ITEMFILTERTYPE_CRAFTING") then return IsMaterialItemType(item.itemType) end
    if filterType == ConstantValue("ITEMFILTERTYPE_QUICKSLOT") then return IsConsumableItemType(item.itemType) end
    if filterType == ConstantValue("ITEMFILTERTYPE_FURNISHING") then return IsFurnishingItemType(item.itemType) end
    if filterType == ConstantValue("ITEMFILTERTYPE_COMPANION") then
        return item.actorCategory ~= nil and ConstantValue("GAMEPLAY_ACTOR_CATEGORY_COMPANION") ~= nil and item.actorCategory == ConstantValue("GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    end
    if filterType == ConstantValue("ITEMFILTERTYPE_QUEST") then return item.isQuest == true end

    return false
end

-- Fallback classification for the craft bag tabs. Preferred path is the native filter
-- metadata (filterData); this table is the safety net for clients where a virtual-bag
-- slot reports no craft-bag subcategory. Unknown constants resolve to nil and are
-- skipped, so a renamed/removed ITEMTYPE never errors -- it just stops matching.
local CRAFT_GROUP_ITEMTYPES = {
    blacksmith   = { "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER" },
    clothing     = { "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_BOOSTER" },
    woodworking  = { "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_WOODWORKING_BOOSTER" },
    jewelry      = { "ITEMTYPE_JEWELRYCRAFTING_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_JEWELRY_RAW_TRAIT", "ITEMTYPE_JEWELRY_TRAIT" },
    alchemy      = { "ITEMTYPE_REAGENT", "ITEMTYPE_POTION_BASE", "ITEMTYPE_POISON_BASE", "ITEMTYPE_ALCHEMY_BASE" },
    enchanting   = { "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY" },
    provisioning = { "ITEMTYPE_INGREDIENT", "ITEMTYPE_RECIPE" },
    style        = { "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_MATERIAL" },
    traits       = { "ITEMTYPE_ARMOR_TRAIT", "ITEMTYPE_WEAPON_TRAIT", "ITEMTYPE_JEWELRY_TRAIT" },
    furnishing   = { "ITEMTYPE_FURNISHING_MATERIAL" },
}

local function DoesCraftItemMatchGroup(item, craftGroup)
    local names = craftGroup and CRAFT_GROUP_ITEMTYPES[craftGroup]
    if not names then return false end
    return ValueMatchesAnyConstant(item.itemType, names)
end

local function IsSuppliesItem(item)
    if not item or item.isEquipped then return false end
    if ZO_InventoryUtils_DoesNewItemMatchSupplies then
        local matches = SafeCall(ZO_InventoryUtils_DoesNewItemMatchSupplies, item)
        if matches ~= nil then return matches == true end
    end

    -- Fallback: supplies are the default game's catch-all for backpack items that are
    -- not equipment and do not belong to material/consumable/furnishing/companion/quest filters.
    if item.isEquippable then return false end
    if IsMaterialItemType(item.itemType) then return false end
    if IsConsumableItemType(item.itemType) then return false end
    if IsFurnishingItemType(item.itemType) then return false end
    if item.isQuest then return false end
    return true
end

-- Filter keys are unique across both tab sets, so a key resolves to exactly one def.
-- Searching only FILTER_DEFS would make every craft key fall back to the backpack
-- "All" def, which rejects craft bag items outright.
local function FindFilterDef(filterKey)
    for i = 1, #FILTER_DEFS do
        if FILTER_DEFS[i].key == filterKey then return FILTER_DEFS[i] end
    end
    for i = 1, #CRAFT_FILTER_DEFS do
        if CRAFT_FILTER_DEFS[i].key == filterKey then return CRAFT_FILTER_DEFS[i] end
    end
    return nil
end

local function ItemMatchesFilter(item, filterKey)
    if not item then return false end

    local def = FindFilterDef(filterKey) or FILTER_DEFS[1]

    -- Two separate universes. Craft bag tabs only ever match craft bag items, and
    -- backpack tabs only ever match backpack/worn items -- so a craft material can
    -- never surface under Materials, and a backpack ore can never surface under
    -- Blacksmithing.
    if def.craftBag then
        if not item.isCraftBag then return false end
        if def.mode == "all" then return true end
        if def.mode == "itemFilterType" then
            local filterType = GetFilterConstant(def)
            if filterType ~= nil and DoesItemMatchNativeItemFilter(item, filterType) then return true end
            return DoesCraftItemMatchGroup(item, def.craftGroup)
        end
        return true
    end
    if item.isCraftBag then return false end

    -- Live junk behavior: once a backpack item is marked junk it disappears from every
    -- non-junk filter immediately and only shows in the Junk filter.
    if item.isJunk and def.mode ~= "junk" then return false end

    -- Worn gear lives in the character panel now. Inside the grid it only appears
    -- under the dedicated Worn filter (or everywhere if /gpi equipped is toggled on).
    if item.isEquipped and def.mode ~= "worn" and not GPI.showEquippedInGrid then return false end

    if def.mode == "all" then return true end
    if def.mode == "new" then
        -- Items you have just looked at stay on the tab until you leave it, so the
        -- grid doesn't reshuffle under the cursor while you dismiss them one by one.
        return item.isNew == true or (GPI.newSeenKeys ~= nil and GPI.newSeenKeys[GPI:GetNewKey(item)] == true)
    end
    if def.mode == "junk" then return item.isJunk == true end
    if def.mode == "worn" then return item.isEquipped == true end
    if def.mode == "supplies" then return IsSuppliesItem(item) end
    if def.mode == "glyphs" then return IsGlyphItemType(item.itemType) end
    if def.mode == "itemFilterType" then return DoesItemMatchNativeItemFilter(item, GetFilterConstant(def)) end
    if def.mode == "equipSlot" then return DoesEquipSlotUseItem(GetEquipSlotFromDef(def), item) end

    if def.mode == "visual" then
        if def.visual == "weapons" then return ValueMatchesAnyConstant(item.itemType, { "ITEMTYPE_WEAPON" }) end
        if def.visual == "apparel" then return ValueMatchesAnyConstant(item.itemType, { "ITEMTYPE_ARMOR" }) and not IsJewelryEquipType(item.equipType) end
        if def.visual == "accessories" then return IsJewelryEquipType(item.equipType) end
    end

    return true
end

local function NowMs()
    if GetGameTimeMilliseconds then
        return SafeCall(GetGameTimeMilliseconds) or 0
    end
    if GetFrameTimeMilliseconds then
        return SafeCall(GetFrameTimeMilliseconds) or 0
    end
    if GetTimeStamp then
        return (SafeCall(GetTimeStamp) or 0) * 1000
    end
    return 0
end

local function IsDebouncedAction(action)
    -- PRIMARY/SECONDARY/TERTIARY are debounced because a single physical button press
    -- can reach GridPad through more than one input path (OnKeyDown key codes AND the
    -- keybind-strip prehook) in the same frame; the debounce collapses them to one.
    -- NEGATIVE is debounced too: B arrives via BOTH the raw key code and the
    -- keybind strip in the same frame. Without the debounce, the first call would
    -- close a popup (e.g. the Buy Bank Space confirm) and the second would fall
    -- through to the default B handler and close the whole window.
    return action == "NEGATIVE"
        or action == "LEFT" or action == "RIGHT" or action == "UP" or action == "DOWN"
        or action == "PAGE_PREV" or action == "PAGE_NEXT"
        or action == "FILTER_PREV" or action == "FILTER_NEXT"
        or action == "PRIMARY" or action == "SECONDARY" or action == "TERTIARY"
        or action == "PAGE_CYCLE" or action == "COMPARE" or action == "INFO"
        or action == "SORT_TOGGLE" or action == "BUY_BANK_SPACE"
        or action == "BAG_TYPE_TOGGLE" or action == "BAG_TYPE_OR_BANK"
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function AddChatMessage(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage("|c318ACBGrid Pad|r: " .. tostring(message))
    end
end

-- On-screen equip log. Gamepad mode usually hides the chat window entirely, so chat
-- diagnostics are invisible to controller players. Everything important is mirrored
-- to a debug label INSIDE the modal and to the top-right alert area (ZO_Alert), both
-- of which are visible in gamepad mode.
function GPI:LogEquip(message)
    self.equipLog = self.equipLog or {}
    table.insert(self.equipLog, tostring(message))
    while #self.equipLog > 30 do table.remove(self.equipLog, 1) end
    if self.debugMode then
        AddChatMessage(message)
        self:UpdateDebugLabel()
    end
end

-- User-facing result: one concise line on screen + chat + top-right alert.
-- The full step trace is always kept in the log (/gpi log, or /gpi debug for live view).
function GPI:Verdict(isError, message)
    self:LogEquip(message)
    if not self.debugMode then
        AddChatMessage(message)
        if self.debugLabel then self.debugLabel:SetText(tostring(message)) end
    end
    self:Alert(isError, message)
end

function GPI:UpdateDebugLabel()
    if not self.debugLabel then return end
    local log = self.equipLog or {}
    local lines = {}
    local first = math.max(1, #log - 2)
    for i = first, #log do table.insert(lines, log[i]) end
    self.debugLabel:SetText(table.concat(lines, "\n"))
end

function GPI:Alert(isError, message)
    local category = isError and UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT
    local sound = SOUNDS and (isError and SOUNDS.NEGATIVE_CLICK or SOUNDS.POSITIVE_CLICK) or nil
    if ZO_Alert and category ~= nil then
        pcall(ZO_Alert, category, sound, "GridPad: " .. tostring(message))
    end
end

local function SetLabelText(label, text)
    if label then label:SetText(text or "") end
end

local function GetNamedControl(name)
    if _G and _G[name] then return _G[name] end
    if WINDOW_MANAGER and WINDOW_MANAGER.GetControlByName then
        return SafeCall(function() return WINDOW_MANAGER:GetControlByName(name) end)
    end
    return nil
end

local function GetQualityColor(quality)
    if GetItemQualityColor then
        local color = GetItemQualityColor(quality or ITEM_FUNCTIONAL_QUALITY_NORMAL)
        if color and color.UnpackRGBA then
            return color:UnpackRGBA()
        end
    end

    if quality == ITEM_FUNCTIONAL_QUALITY_MAGIC then return 0.20, 0.55, 1.00, 1 end
    if quality == ITEM_FUNCTIONAL_QUALITY_ARCANE then return 0.65, 0.28, 1.00, 1 end
    if quality == ITEM_FUNCTIONAL_QUALITY_ARTIFACT then return 0.95, 0.75, 0.18, 1 end
    if quality == ITEM_FUNCTIONAL_QUALITY_LEGENDARY then return 1.00, 0.48, 0.10, 1 end
    return 0.75, 0.75, 0.75, 1
end

local function GetBagItemData(bagId, slotIndex, source, equippedSlotName)
    local icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, quality = SafeCall(GetItemInfo, bagId, slotIndex)
    if not icon or icon == "" or not stack or stack <= 0 then
        return nil
    end

    local itemType, specializedItemType = nil, nil
    if GetItemType then
        itemType, specializedItemType = SafeCall(GetItemType, bagId, slotIndex)
    end

    local name = SafeCall(GetItemName, bagId, slotIndex) or "Item"
    local link = SafeCall(GetItemLink, bagId, slotIndex, LINK_STYLE_BRACKETS) or name
    local isJunk = false
    if bagId == BAG_BACKPACK and IsItemJunk then
        isJunk = SafeCall(IsItemJunk, bagId, slotIndex) or false
    end

    local uniqueId = nil
    if GetItemUniqueId then
        uniqueId = SafeCall(GetItemUniqueId, bagId, slotIndex)
    end

    local instanceId = nil
    if GetItemInstanceId then
        instanceId = SafeCall(GetItemInstanceId, bagId, slotIndex)
    end

    local actorCategory = nil
    if GetItemActorCategory then
        actorCategory = SafeCall(GetItemActorCategory, bagId, slotIndex)
    end

    -- Craft bag items need filter metadata for the craft subcategory tabs, but only via
    -- the cheap GetItemFilterTypeInfo C call below. GenerateSingleSlotData is the
    -- expensive part and is skipped, which keeps a 300+ stack craft bag scan fast.
    local isCraftBag = (BAG_VIRTUAL ~= nil and bagId == BAG_VIRTUAL)

    -- Pull the same filter metadata ZOS uses for the native gamepad inventory when it is available.
    -- GridPad falls back to item/equip type checks below if this metadata is not present yet.
    local filterData = nil
    if not isCraftBag and SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData then
        local sharedData = SafeCall(function() return SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex) end)
        if sharedData then
            filterData = sharedData.filterData
            if sharedData.equipType ~= nil then equipType = sharedData.equipType end
            if sharedData.itemType ~= nil then itemType = sharedData.itemType end
            if sharedData.specializedItemType ~= nil then specializedItemType = sharedData.specializedItemType end
            if sharedData.actorCategory ~= nil then actorCategory = sharedData.actorCategory end
        end
    end

    if not filterData and GetItemFilterTypeInfo then
        local f1, f2, f3, f4, f5, f6 = SafeCall(GetItemFilterTypeInfo, bagId, slotIndex)
        filterData = {}
        if f1 ~= nil then table.insert(filterData, f1) end
        if f2 ~= nil then table.insert(filterData, f2) end
        if f3 ~= nil then table.insert(filterData, f3) end
        if f4 ~= nil then table.insert(filterData, f4) end
        if f5 ~= nil then table.insert(filterData, f5) end
        if f6 ~= nil then table.insert(filterData, f6) end
        if #filterData == 0 then filterData = nil end
    end

    -- Native inventory uses GetItemEquipType for equip behavior. Use it when available
    -- instead of relying only on the GetItemInfo tuple.
    if GetItemEquipType then
        local nativeEquipType = SafeCall(GetItemEquipType, bagId, slotIndex)
        if nativeEquipType ~= nil then equipType = nativeEquipType end
    end

    return {
        bagId = bagId,
        slotIndex = slotIndex,
        source = source or "backpack",
        icon = icon,
        iconFile = icon,
        stack = stack,
        sellPrice = sellPrice or 0,
        name = name,
        link = link,
        locked = locked,
        equipType = equipType,
        itemType = itemType,
        specializedItemType = specializedItemType,
        actorCategory = actorCategory,
        filterData = filterData,
        quality = quality or ITEM_FUNCTIONAL_QUALITY_NORMAL,
        meetsUsageRequirement = meetsUsageRequirement ~= false,
        isJunk = isJunk,
        isPlayerLocked = (IsItemPlayerLocked and SafeCall(IsItemPlayerLocked, bagId, slotIndex)) == true,
        isNew = source ~= "equipped" and SHARED_INVENTORY ~= nil and SHARED_INVENTORY.IsItemNew ~= nil
            and SafeCall(SHARED_INVENTORY.IsItemNew, SHARED_INVENTORY, bagId, slotIndex) == true,
        isEquipped = source == "equipped",
        isCraftBag = isCraftBag,
        equippedSlotName = equippedSlotName,
        isEquippable = IsEquipTypeUsable(equipType),
        uniqueId = uniqueId,
        instanceId = instanceId,
    }
end

function GPI:IsShowing()
    return self.window and not self.window:IsHidden()
end

-- DIAGNOSTIC KILL-SWITCH (/gpi diag N). Persisted; takes full effect after /reloadui.
--   0 = normal.
--   1 = engine-safe mode: no scene forcing, no native-chrome suppression,
--       no raw input capture. GridPad still opens/works, may look rougher.
--   2 = level 1 + zoning handlers reduced to the bare minimum.
function GPI:DiagLevel()
    return (self.sv and tonumber(self.sv.diagLevel)) or 0
end

-- The modal and window are keyboard-enabled TopLevels at drawLevel 200000+, so
-- the ENGINE routes raw key/gamepad-button events to them first while GridPad is
-- up. Native gamepad dialogs (Buy Bank Space, and modal tutorials like the
-- POISONS explainer, which is the UI_TUTORIAL_GAMEPAD ZO_Dialog) bind their
-- CONTINUE/confirm as ethereal DIALOG_PRIMARY keybinds on the "Dialogs" action
-- layer -- BELOW raw window input. Merely ignoring the input in Lua is not
-- enough: the press never reaches the action layer and the player is deadlocked
-- in front of a dialog that cannot be advanced. While a native dialog is
-- showing, keyboard capture must be released entirely.
function GPI:SetInputCaptureEnabled(enabled)
    enabled = enabled and true or false
    if self.inputCaptureEnabled == enabled then return end
    self.inputCaptureEnabled = enabled
    if self.modal and self.modal.SetKeyboardEnabled then
        SafeCall(function() self.modal:SetKeyboardEnabled(enabled) end)
    end
    if self.window and self.window.SetKeyboardEnabled then
        SafeCall(function() self.window:SetKeyboardEnabled(enabled) end)
    end
end

-- Not every native dialog draws above GridPad: CENTERED gamepad dialogs (the
-- POISONS tutorial) do, but BASIC ones (the Destroy Item confirmation) render
-- in nav quadrant 1 at ordinary scene depth -- UNDER GridPad's DT_HIGH windows,
-- leaving the player squinting at a ghost prompt behind the doll panel. While a
-- native dialog is up in inventory mode, GridPad fades itself to alpha 0 so the
-- dialog is fully readable. Alpha is used instead of SetHidden so IsShowing()
-- stays true and the DialogWatch keeps ticking to restore everything. Bank mode
-- is exempt: its dialogs (Buy Bank Space) already render correctly over the
-- grid and that flow deliberately keeps GridPad visible.
function GPI:SetFadedForDialog(faded)
    faded = faded and true or false
    if self.fadedForDialog == faded then return end
    self.fadedForDialog = faded
    local a = faded and 0 or 1
    if self.window and self.window.SetAlpha then
        SafeCall(function() self.window:SetAlpha(a) end)
    end
    if self.modal and self.modal.SetAlpha then
        SafeCall(function() self.modal:SetAlpha(a) end)
    end
end

function GPI:CreateBackdrop(name, parent, centerR, centerG, centerB, centerA, edgeR, edgeG, edgeB, edgeA)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    control:SetCenterColor(centerR, centerG, centerB, centerA)
    control:SetEdgeColor(edgeR, edgeG, edgeB, edgeA)
    return control
end

-- ESO-styled backdrop: dark ZOS interior + the gamepad ornate edge texture when
-- available (falls back to a colored 1px edge). Use for the main framed surfaces.
function GPI:CreateFramedBackdrop(name, parent, kind)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    local cr, cg, cb, ca
    if kind == "window" then
        cr, cg, cb, ca = ESO.bgR, ESO.bgG, ESO.bgB, ESO.bgA
    elseif kind == "cell" then
        cr, cg, cb, ca = ESO.cellR, ESO.cellG, ESO.cellB, ESO.cellA
    else
        cr, cg, cb, ca = ESO.panelR, ESO.panelG, ESO.panelB, ESO.panelA
    end
    control:SetCenterColor(cr, cg, cb, ca)
    -- Cells get a dimmer edge so the grid reads as a unit; framed surfaces get the
    -- muted ESO gold-steel border.
    if kind == "cell" then
        control:SetEdgeColor(ESO.edgeDimR, ESO.edgeDimG, ESO.edgeDimB, ESO.edgeDimA)
    else
        control:SetEdgeColor(ESO.edgeR, ESO.edgeG, ESO.edgeB, ESO.edgeA)
    end
    return control
end

function GPI:CreateLabel(name, parent, font, colorR, colorG, colorB, colorA)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(colorR, colorG, colorB, colorA)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

function GPI:CreateUI()
    if self.window then return end

    local wm = WINDOW_MANAGER

    self.modal = wm:CreateTopLevelWindow("GridPadInventoryModal")
    self.modal:SetAnchorFill(GuiRoot)
    self.modal:SetHidden(true)
    self.modal:SetMouseEnabled(true)
    self.modal:SetDrawTier(DT_HIGH)
    self.modal:SetDrawLayer(DL_OVERLAY)
    self.modal:SetDrawLevel(200000)
    self.modal:SetKeyboardEnabled(true)
    self.inputCaptureEnabled = true -- mirrors SetKeyboardEnabled on modal+window

    self.modal:SetHandler("OnKeyDown", function(_, keyCode)
        if self:HandleKeyCode(keyCode) then
            return true
        end
    end)

    self.modal:SetHandler("OnKeyUp", function(_, keyCode)
        if self:HandleKeyUp(keyCode) then
            return true
        end
    end)

    self.modalBackdrop = self:CreateBackdrop(nil, self.modal, 0.0, 0.0, 0.0, 0.965, 0.0, 0.0, 0.0, 0.0)
    self.modalBackdrop:SetAnchorFill(self.modal)
    self.modalBackdrop:SetMouseEnabled(true)

    self.window = wm:CreateTopLevelWindow("GridPadInventoryWindow")
    self.window:SetDimensions(1950, 1050)
    self.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    self.window:SetHidden(true)
    self.window:SetMouseEnabled(true)
    self.window:SetMovable(false)
    self.window:SetClampedToScreen(true)
    self.window:SetDrawTier(DT_HIGH)
    self.window:SetDrawLayer(DL_OVERLAY)
    self.window:SetDrawLevel(200100)
    self.window:SetKeyboardEnabled(true)

    self.window:SetHandler("OnKeyDown", function(_, keyCode)
        if self:HandleKeyCode(keyCode) then
            return true
        end
    end)

    self.window:SetHandler("OnKeyUp", function(_, keyCode)
        if self:HandleKeyUp(keyCode) then
            return true
        end
    end)

    self.background = self:CreateFramedBackdrop(nil, self.window, "window")
    self.background:SetAnchorFill(self.window)

    self.title = self:CreateLabel(nil, self.window, "ZoFontGamepadBold42", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.title:SetAnchor(TOPLEFT, self.window, TOPLEFT, 26, 22)
    self.title:SetDimensions(820, 46)
    self.title:SetText("Grid Pad")

    -- In-UI toggle: switch between full and simple (compact, panel-free) views.
    self.viewToggle = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.viewToggle:SetDimensions(210, 40)
    self.viewToggle:SetAnchor(TOPLEFT, self.window, TOPLEFT, 26, 78)
    self.viewToggle:SetMouseEnabled(true)
    self.viewToggle:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:ToggleSimpleView() end
    end)
    self.viewToggleText = self:CreateLabel(nil, self.viewToggle, "ZoFontGamepad27", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.viewToggleText:SetAnchorFill(self.viewToggle)
    self.viewToggleText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.viewToggleText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.viewToggleText:SetText("View: Full")


    self.filterInfo = self:CreateLabel(nil, self.window, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.filterInfo:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -30, 26)
    self.filterInfo:SetDimensions(700, 42)
    self.filterInfo:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.filterInfo:SetMouseEnabled(true)
    self.filterInfo:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            self:CycleFilter(-1)
        else
            self:CycleFilter(1)
        end
    end)

    self.help = self:CreateLabel(nil, self.window, "ZoFontGamepad22", 0.70, 0.72, 0.76, 1)
    self.help:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, 426, -92)
    self.help:SetDimensions(780, 42)
    self.help:SetText("D-pad/stick: move \226\128\162 A: use/equip \226\128\162 X: junk \226\128\162 Y: link \226\128\162 B: close \226\128\162 LB/RB: filter \226\128\162 LT: info \226\128\162 RT: compare \226\128\162 LEFT past column 1: character gear \226\128\162 UP past top row: View toggle")

    -- Currency bar across the bottom of the window (v1.5.0): 7 columns x 2 rows of
    -- compact "LABEL: value <icon>" entries, plus bag/bank slot counts.
    self.currencyBar = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.currencyBar:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, 14, -10)
    self.currencyBar:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -14, -10)
    self.currencyBar:SetHeight(68)
    self.curLabels = {}
    do
        local colW = math.floor((1950 - 28 - 24) / 7)
        for c = 1, 7 do
            for r = 1, 2 do
                local lbl = self:CreateLabel(nil, self.currencyBar, "ZoFontGamepad27", 0.75, 0.78, 0.83, 1)
                lbl:SetAnchor(TOPLEFT, self.currencyBar, TOPLEFT, 18 + (c - 1) * colW, r == 1 and 5 or 34)
                lbl:SetDimensions(colW - 10, 30)
                self.curLabels[(c - 1) * 2 + r] = lbl
            end
        end
        -- The BAG readout (column 1, row 1) doubles as the Upgrade Bag Space
        -- trigger: click it to buy the next backpack upgrade (Update 49 API).
        local bagLbl = self.curLabels[1]
        if bagLbl then
            bagLbl:SetMouseEnabled(true)
            bagLbl:SetHandler("OnMouseUp", function(_, mb)
                if mb == MOUSE_BUTTON_INDEX_LEFT then self:ShowBagUpgradeConfirm() end
            end)
        end
    end

    -- Character panel: WoW-style paperdoll. Armor slots down the left edge, jewelry
    -- and costume down the right edge, weapon bars centered at the bottom, with a
    -- name/level/class header. Slot borders take the equipped item's quality color,
    -- and the number beside each slot is the item's CP (or level) requirement.
    self.charPanel = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.charPanel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 26, 148)
    self.charPanel:SetDimensions(380, 815)

    self.charName = self:CreateLabel(nil, self.charPanel, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.charName:SetAnchor(TOPLEFT, self.charPanel, TOPLEFT, 14, 8)
    self.charName:SetAnchor(TOPRIGHT, self.charPanel, TOPRIGHT, -14, 8)
    self.charName:SetHeight(36)
    self.charName:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.charName:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    self.charSub = self:CreateLabel(nil, self.charPanel, "ZoFontGamepad22", 0.62, 0.74, 1.00, 1)
    self.charSub:SetAnchor(TOPLEFT, self.charName, BOTTOMLEFT, 0, 0)
    self.charSub:SetAnchor(TOPRIGHT, self.charName, BOTTOMRIGHT, 0, 0)
    self.charSub:SetHeight(26)
    self.charSub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Current title, centered under the level line.
    self.charTitle = self:CreateLabel(nil, self.charPanel, "ZoFontGamepad22", 0.80, 0.72, 0.48, 1)
    self.charTitle:SetAnchor(TOPLEFT, self.charSub, BOTTOMLEFT, 0, 0)
    self.charTitle:SetAnchor(TOPRIGHT, self.charSub, BOTTOMRIGHT, 0, 0)
    self.charTitle:SetHeight(22)
    self.charTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Bottom stack (anchored to the panel bottom, full width): attributes, mundus,
    -- challenge difficulty (clickable), and bag usage.
    self.charAttrs = self:CreateLabel(nil, self.charPanel, "ZoFontGamepad25", 0.9, 0.9, 0.9, 1)
    self.charAttrs:SetAnchor(BOTTOMLEFT, self.charPanel, BOTTOMLEFT, 14, -104)
    self.charAttrs:SetAnchor(BOTTOMRIGHT, self.charPanel, BOTTOMRIGHT, -14, -104)
    self.charAttrs:SetHeight(27)
    self.charAttrs:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.charMundus = self:CreateLabel(nil, self.charPanel, "ZoFontGamepad22", 0.72, 0.80, 0.95, 1)
    self.charMundus:SetAnchor(BOTTOMLEFT, self.charPanel, BOTTOMLEFT, 14, -78)
    self.charMundus:SetAnchor(BOTTOMRIGHT, self.charPanel, BOTTOMRIGHT, -14, -78)
    self.charMundus:SetHeight(22)
    self.charMundus:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.charDiff = self:CreateBackdrop(nil, self.charPanel, 0.05, 0.06, 0.08, 0.95, 0.30, 0.33, 0.40, 1)
    self.charDiff:SetDimensions(250, 33)
    self.charDiff:SetAnchor(BOTTOM, self.charPanel, BOTTOM, 0, -42)
    self.charDiff:SetMouseEnabled(true)
    self.charDiffText = self:CreateLabel(nil, self.charDiff, "ZoFontGamepad22", 0.9, 0.9, 0.9, 1)
    self.charDiffText:SetAnchorFill(self.charDiff)
    self.charDiffText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.charDiffText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.charDiff:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:CycleChallengeDifficulty(1) end
    end)

    -- Bag usage readout doubles as the Upgrade Bag Space trigger (Update 49 API):
    -- click it with the mouse, or on gamepad walk DOWN past Challenge Difficulty.
    self.charBagBtn = self:CreateBackdrop(nil, self.charPanel, 0, 0, 0, 0, 0, 0, 0, 0)
    self.charBagBtn:SetAnchor(BOTTOMLEFT, self.charPanel, BOTTOMLEFT, 14, -8)
    self.charBagBtn:SetAnchor(BOTTOMRIGHT, self.charPanel, BOTTOMRIGHT, -14, -8)
    self.charBagBtn:SetHeight(26)
    self.charBagBtn:SetMouseEnabled(true)
    self.charBagBtn:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:ShowBagUpgradeConfirm() end
    end)
    self.charBag = self:CreateLabel(nil, self.charBagBtn, "ZoFontGamepad22", 0.75, 0.78, 0.82, 1)
    self.charBag:SetAnchorFill(self.charBagBtn)
    self.charBag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.charBag:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local BOX, GAP, COL_TOP = 54, 9, 96
    local function CreateCharSlot(equipSlotVar, x, y, numberSide)
        local slot = {}
        slot.equipSlotVar = equipSlotVar
        slot.box = self:CreateBackdrop(nil, self.charPanel, 0.07, 0.08, 0.10, 0.96, 0.30, 0.32, 0.36, 1)
        slot.box:SetAnchor(TOPLEFT, self.charPanel, TOPLEFT, x, y)
        slot.box:SetDimensions(BOX, BOX)

        slot.icon = wm:CreateControl(nil, slot.box, CT_TEXTURE)
        slot.icon:SetAnchor(TOPLEFT, slot.box, TOPLEFT, 3, 3)
        slot.icon:SetAnchor(BOTTOMRIGHT, slot.box, BOTTOMRIGHT, -3, -3)

        slot.box:SetMouseEnabled(true)
        slot.box:SetHandler("OnMouseEnter", function()
            local slotId = ConstantValue(slot.equipSlotVar)
            if slotId ~= nil and BAG_WORN ~= nil and GetItemName then
                local itemName = SafeCall(GetItemName, BAG_WORN, slotId)
                if itemName and itemName ~= "" then
                    self:ShowHoverTooltip(slot.box, BAG_WORN, slotId)
                end
            end
        end)
        slot.box:SetHandler("OnMouseExit", function()
            self:HideHoverTooltip()
        end)

        if numberSide then
            slot.number = self:CreateLabel(nil, self.charPanel, "ZoFontGamepad25", 0.50, 0.53, 0.58, 1)
            slot.number:SetDimensions(62, 26)
            slot.number:SetAnchor(numberSide == "right" and LEFT or RIGHT, slot.box, numberSide == "right" and RIGHT or LEFT, numberSide == "right" and 8 or -8, 0)
            slot.number:SetHorizontalAlignment(numberSide == "right" and TEXT_ALIGN_LEFT or TEXT_ALIGN_RIGHT)
        end

        table.insert(self.charSlots, slot)
        return slot
    end

    self.charSlots = {}
    local leftSlots = { "EQUIP_SLOT_HEAD", "EQUIP_SLOT_SHOULDERS", "EQUIP_SLOT_CHEST", "EQUIP_SLOT_HAND", "EQUIP_SLOT_WAIST", "EQUIP_SLOT_LEGS", "EQUIP_SLOT_FEET" }
    local rightSlots = { "EQUIP_SLOT_NECK", "EQUIP_SLOT_RING1", "EQUIP_SLOT_RING2", "EQUIP_SLOT_COSTUME" }
    local weaponRows = {
        { "EQUIP_SLOT_MAIN_HAND", "EQUIP_SLOT_OFF_HAND", "EQUIP_SLOT_POISON" },
        { "EQUIP_SLOT_BACKUP_MAIN", "EQUIP_SLOT_BACKUP_OFF", "EQUIP_SLOT_BACKUP_POISON" },
    }

    for i = 1, #leftSlots do
        CreateCharSlot(leftSlots[i], 16, COL_TOP + (i - 1) * (BOX + GAP), "right")
    end
    for i = 1, #rightSlots do
        CreateCharSlot(rightSlots[i], 380 - 16 - BOX, COL_TOP + (i - 1) * (BOX + GAP), "left")
    end

    local weaponsTop = COL_TOP + 7 * (BOX + GAP) + 12
    for r = 1, #weaponRows do
        local row = weaponRows[r]
        local rowWidth = #row * BOX + (#row - 1) * GAP
        local rowX = math.floor((380 - rowWidth) / 2)
        for c = 1, #row do
            CreateCharSlot(row[c], rowX + (c - 1) * (BOX + GAP), weaponsTop + (r - 1) * (BOX + GAP), nil)
        end
    end

    -- Framed backing panel behind the grid (shown in simple view to echo ESO's
    -- bordered inventory block). Positioned/sized in ApplyLayout.
    self.gridFrame = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.gridFrame:SetHidden(true)

    self.grid = wm:CreateControl(nil, self.window, CT_CONTROL)
    self.grid:SetAnchor(TOPLEFT, self.window, TOPLEFT, 426, 150)
    self.grid:SetDimensions((self.cellSize + self.cellGap) * self.cols - self.cellGap, (self.cellSize + self.cellGap) * self.rows - self.cellGap)

    -- Live equip diagnostics, visible in gamepad mode (chat usually is not).
    self.debugLabel = self:CreateLabel(nil, self.window, "ZoFontGamepad22", 1.00, 0.78, 0.45, 1)
    self.debugLabel:SetAnchor(TOPLEFT, self.grid, BOTTOMLEFT, 0, 10)
    self.debugLabel:SetDimensions(792, 78)
    self.debugLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)

    self.details = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.details:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -26, 150)
    self.details:SetDimensions(640, 810)

    self.detailsIcon = wm:CreateControl(nil, self.details, CT_TEXTURE)
    self.detailsIcon:SetAnchor(TOPLEFT, self.details, TOPLEFT, 18, 18)
    self.detailsIcon:SetDimensions(64, 64)

    self.detailsName = self:CreateLabel(nil, self.details, "ZoFontGamepadBold34", 1, 1, 1, 1)
    self.detailsName:SetAnchor(TOPLEFT, self.detailsIcon, TOPRIGHT, 14, 0)
    self.detailsName:SetDimensions(520, 76)
    self.detailsName:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    self.detailsMeta = self:CreateLabel(nil, self.details, "ZoFontGamepad27", 0.80, 0.84, 0.90, 1)
    self.detailsMeta:SetAnchor(TOPLEFT, self.detailsIcon, BOTTOMLEFT, 0, 18)
    self.detailsMeta:SetDimensions(600, 190)

    self.detailsLink = self:CreateLabel(nil, self.details, "ZoFontGamepad22", 0.65, 0.75, 1, 1)
    self.detailsLink:SetAnchor(TOPLEFT, self.detailsMeta, BOTTOMLEFT, 0, 18)
    self.detailsLink:SetDimensions(600, 80)
    self.detailsLink:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)


    -- Embedded native item tooltip: a private instance of ESO's own ZO_ItemIconTooltip
    -- virtual template, parented inside this panel. SetBagItem() makes the GAME render
    -- the item card, so it shows everything the standard UI shows (armor/damage, traits,
    -- enchantments, set bonuses with equipped counts, style, flavor text, value) with
    -- perfect fidelity -- and it stays correct when ZOS changes tooltip content.
    self.itemTooltip = nil
    do
        local okTip, tip = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER, "GridPadInventoryItemTooltip", self.details, "ZO_ItemIconTooltip")
        if not (okTip and tip) then
            okTip, tip = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER, "GridPadInventoryItemTooltip", self.details, "ItemTooltipBase")
        end
        if okTip and tip then
            self.itemTooltip = tip
            self:ApplyTooltipChrome(tip)
            -- CRITICAL: the ZO_IconTooltip_Base template SHIPS with a built-in
            -- <Anchor point="BOTTOM" offsetY="-245"/>. Setting our TOPLEFT anchor
            -- without clearing that one left the control pinned at BOTH ends -- a
            -- forced height. The native background drew at that forced rectangle
            -- while the content lines overflowed out the bottom of it (the exact
            -- "box ends early, text keeps going" defect). ClearAnchors() first.
            self:ApplyTooltipLayout()
            tip:SetHidden(true)
            if tip.SetMouseEnabled then tip:SetMouseEnabled(false) end
        end
    end

    -- Hover popup: a second private native-tooltip instance that follows the mouse
    -- across grid cells and paperdoll slots, standard tooltip size.
    self.hoverTooltip = nil
    do
        local okTip, tip = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER, "GridPadInventoryHoverTooltip", self.window, "ZO_ItemIconTooltip")
        if okTip and tip then
            self.hoverTooltip = tip
            self:ApplyTooltipChrome(tip)
            tip:ClearAnchors() -- drop the template's built-in BOTTOM anchor
            tip:SetScale(1.0)
            tip:SetHidden(true)
            tip:SetClampedToScreen(true)
            if tip.SetDrawLevel then tip:SetDrawLevel(5000) end
            if tip.SetMouseEnabled then tip:SetMouseEnabled(false) end
        end
    end

    -- Compare popup (RT): equipped gear vs the selected item, side by side, using
    -- embedded instances of ESO's real item tooltip for each card.
    self.compareFrame = self:CreateBackdrop(nil, self.window, 0.025, 0.03, 0.045, 0.985, 0.35, 0.75, 0.95, 1)
    self.compareFrame:SetAnchor(CENTER, self.window, CENTER, 0, 16)
    self.compareFrame:SetHidden(true)
    self.compareFrame:SetMouseEnabled(true)
    if self.compareFrame.SetDrawTier and DT_HIGH then self.compareFrame:SetDrawTier(DT_HIGH) end
    if self.compareFrame.SetDrawLevel then self.compareFrame:SetDrawLevel(100) end

    self.compareTitle = self:CreateLabel(nil, self.compareFrame, "ZoFontGamepadBold34", 0.55, 0.90, 1.00, 1)
    self.compareTitle:SetAnchor(TOP, self.compareFrame, TOP, 0, 14)
    self.compareTitle:SetDimensions(1240, 40)
    self.compareTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.compareTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    self.compareHint = self:CreateLabel(nil, self.compareFrame, "ZoFontGamepad22", 0.62, 0.66, 0.72, 1)
    self.compareHint:SetAnchor(BOTTOM, self.compareFrame, BOTTOM, 0, -10)
    self.compareHint:SetDimensions(1240, 26)
    self.compareHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.compareHint:SetText("RT or B: close \226\128\162 move the selection to compare another item \226\128\162 LT: full stat sheet \226\128\162 A still equips")

    self.compareTips, self.compareHeads, self.compareEmpties = {}, {}, {}
    for i = 1, 3 do
        local okTip, ctip = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER, "GridPadInventoryCompareTooltip" .. i, self.compareFrame, "ZO_ItemIconTooltip")
        if okTip and ctip then
            self:ApplyTooltipChrome(ctip)
            ctip:ClearAnchors() -- drop the template's built-in BOTTOM anchor
            ctip:SetScale(1.0)
            ctip:SetHidden(true)
            if ctip.SetMouseEnabled then ctip:SetMouseEnabled(false) end
            if ctip.SetDrawTier and DT_HIGH then ctip:SetDrawTier(DT_HIGH) end
            if ctip.SetDrawLevel then ctip:SetDrawLevel(300) end
            -- The tooltip's own auto-sizing backdrop is stripped; a uniform framed box
            -- (below) provides the card chrome so all cards share identical dimensions.
            self:HideTooltipBackdrop(ctip)
            self.compareTips[i] = ctip
        end

        -- Uniform card box: identical dimensions for every card, ESO panel styling.
        self.compareCardBGs = self.compareCardBGs or {}
        local cbg = self:CreateFramedBackdrop(nil, self.compareFrame, "panel")
        cbg:SetHidden(true)
        cbg:SetMouseEnabled(false)
        if cbg.SetDrawLevel then cbg:SetDrawLevel(120) end
        self.compareCardBGs[i] = cbg

        local head = self:CreateLabel(nil, self.compareFrame, "ZoFontGamepadBold27", 1, 1, 1, 1)
        head:SetDimensions(430, 30)
        head:SetHidden(true)
        if head.SetDrawLevel then head:SetDrawLevel(400) end
        self.compareHeads[i] = head

        local emptyLbl = self:CreateLabel(nil, self.compareFrame, "ZoFontGamepad27", 0.55, 0.58, 0.64, 1)
        emptyLbl:SetDimensions(430, 60)
        emptyLbl:SetHidden(true)
        self.compareEmpties[i] = emptyLbl
    end

    -- "If equipped" stat-swing panel, pinned to the bottom of the SELECTED card so the
    -- point gain/loss sits directly under the item it belongs to.
    self.compareDeltaBG = self:CreateFramedBackdrop(nil, self.compareFrame, "panel")
    self.compareDeltaBG:SetHidden(true)
    self.compareDeltaBG:SetMouseEnabled(false)
    if self.compareDeltaBG.SetDrawLevel then self.compareDeltaBG:SetDrawLevel(310) end

    self.compareDeltaHead = self:CreateLabel(nil, self.compareFrame, "ZoFontGamepadBold22", 1.00, 0.79, 0.30, 1)
    self.compareDeltaHead:SetHidden(true)
    self.compareDeltaHead:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    if self.compareDeltaHead.SetDrawLevel then self.compareDeltaHead:SetDrawLevel(320) end

    self.compareDeltaText = self:CreateLabel(nil, self.compareFrame, "ZoFontGamepad22", 0.86, 0.86, 0.82, 1)
    self.compareDeltaText:SetHidden(true)
    self.compareDeltaText:SetVerticalAlignment(TEXT_ALIGN_TOP)
    if self.compareDeltaText.SetDrawLevel then self.compareDeltaText:SetDrawLevel(320) end

    -- LT info popup (used in simple view, where there is no side details panel):
    -- a framed overlay with the native item tooltip on the left and the item-info +
    -- character-stat comparison text on the right.
    -- Left-edge vertical panel styled like ESO's native Currencies panel: a tall,
    -- narrow framed column pinned to the left of the screen, with a gold title and an
    -- underline rule at the top. LT cycles its content: Item Details -> Stat
    -- Comparison -> closed. Anchored to GuiRoot so it hugs the true screen edge.
    local PANEL_W = 470
    -- Semi-transparent framed column (matches the see-through grid/currency surfaces).
    -- Parented to self.window (the exact v1.8.9/v1.9.0 configuration that renders
    -- correctly on-screen). A bare GuiRoot child does not reliably participate in the
    -- render order -- that reparenting is what made the panel invisible. Anchors still
    -- reference GuiRoot so the panel tracks true screen coordinates.
    self.infoPopup = self:CreateBackdrop(nil, self.window, ESO.panelR, ESO.panelG, ESO.panelB, 0.55, ESO.edgeR, ESO.edgeG, ESO.edgeB, 1)
    self.infoPopup:SetWidth(PANEL_W)
    self.infoPopup:SetAnchor(RIGHT, GuiRoot, RIGHT, -700, 0)
    self.infoPopup:SetHidden(true)
    self.infoPopup:SetMouseEnabled(true)
    -- DT_MEDIUM sandwiches the panel: above the native quadrant bars (DT_LOW), below
    -- the game's control strip (DT_HIGH). (DT_LOW/DL_BACKGROUND made it invisible --
    -- it rendered BEHIND the native panels.)
    if self.infoPopup.SetDrawTier and DT_MEDIUM then self.infoPopup:SetDrawTier(DT_MEDIUM) end
    if self.infoPopup.SetDrawLevel then self.infoPopup:SetDrawLevel(40) end

    -- Frost layer: a dark translucent fill just inside the panel that softens/darkens
    -- whatever shows through, approximating the native panel's frosted-blur look. Its
    -- opacity is the "frost" setting. Sits above the panel backdrop, below the text.
    self.infoPopupFrost = self:CreateBackdrop(nil, self.infoPopup, 0.02, 0.025, 0.04, 0.0, 0, 0, 0, 0)
    self.infoPopupFrost:SetAnchorFill(self.infoPopup)
    if self.infoPopupFrost.SetDrawLevel then self.infoPopupFrost:SetDrawLevel(41) end

    -- Gold header (mode label: "Item Details" / "Stat Comparison").
    self.infoPopupTitle = self:CreateLabel(nil, self.infoPopup, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.infoPopupTitle:SetAnchor(TOPLEFT, self.infoPopup, TOPLEFT, 28, 22)
    self.infoPopupTitle:SetDimensions(PANEL_W - 56, 40)
    self.infoPopupTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.infoPopupTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    -- Underline rule beneath the header, like the native panel.
    self.infoPopupRule = self:CreateBackdrop(nil, self.infoPopup, ESO.goldR, ESO.goldG, ESO.goldB, 0.55, 0, 0, 0, 0)
    self.infoPopupRule:SetAnchor(TOPLEFT, self.infoPopup, TOPLEFT, 26, 66)
    self.infoPopupRule:SetDimensions(PANEL_W - 52, 2)

    -- Item name subheader.
    self.infoPopupHint = self:CreateLabel(nil, self.infoPopup, "ZoFontGamepad22", ESO.dimR, ESO.dimG, ESO.dimB, 1)
    self.infoPopupHint:SetAnchor(BOTTOM, self.infoPopup, BOTTOM, 0, -96)
    self.infoPopupHint:SetDimensions(PANEL_W - 40, 24)
    self.infoPopupHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.infoPopupHint:SetText("LT: details/stats")

    -- Native tooltip card (Item Details mode). Anchored below the subheader.
    do
        local okTip, tip = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER, "GridPadInventoryInfoPopupTooltip", self.infoPopup, "ZO_ItemIconTooltip")
        if okTip and tip then
            self:ApplyTooltipChrome(tip)
            tip:ClearAnchors()
            tip:SetScale(1.0)
            tip:SetHidden(true)
            if tip.SetMouseEnabled then tip:SetMouseEnabled(false) end
            if tip.SetDrawTier and DT_MEDIUM then tip:SetDrawTier(DT_MEDIUM) end
            if tip.SetDrawLevel then tip:SetDrawLevel(60) end
            self:HideTooltipBackdrop(tip)
            self.infoPopupTooltip = tip
        end
    end

    -- Item-info + character-stat text (Stat Comparison mode). Anchored top+bottom so it
    -- fills whatever height the panel is given in RenderInfoPopup.
    self.infoPopupText = self:CreateLabel(nil, self.infoPopup, "ZoFontGamepad27", 0.75, 0.78, 0.83, 1)
    self.infoPopupText:SetAnchor(TOPLEFT, self.infoPopup, TOPLEFT, 28, 84)
    self.infoPopupText:SetAnchor(BOTTOMRIGHT, self.infoPopup, BOTTOMRIGHT, -28, -126)
    self.infoPopupText:SetVerticalAlignment(TEXT_ALIGN_TOP)

    self.cells = {}
    for i = 1, self.maxCells do
        local cell = self:CreateFramedBackdrop(nil, self.grid, "cell")
        cell:SetDimensions(self.cellSize, self.cellSize)
        cell:SetMouseEnabled(true)

        cell.icon = wm:CreateControl(nil, cell, CT_TEXTURE)
        cell.icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 5, 5)
        cell.icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -5, -5)

        cell.stack = self:CreateLabel(nil, cell, "ZoFontGamepad22", 1, 1, 1, 1)
        cell.stack:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -6, -4)
        cell.stack:SetDimensions(56, 22)
        cell.stack:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        cell.stack:SetDrawLevel(3)

        -- Equipped indicator: the game's own "equipped" icon, sized to fit the compact
        -- simple-view cells (the old 78px WORN badge was wider than a 52px cell).
        cell.equippedBadge = wm:CreateControl(nil, cell, CT_TEXTURE)
        cell.equippedBadge:SetDimensions(20, 20)
        cell.equippedBadge:SetAnchor(TOPLEFT, cell, TOPLEFT, 2, 2)
        cell.equippedBadge:SetTexture(_G["ZO_KEYBOARD_IS_EQUIPPED_ICON"] or "EsoUI/Art/Inventory/inventory_icon_equipped.dds")
        cell.equippedBadge:SetMouseEnabled(false)
        cell.equippedBadge:SetDrawLevel(3)

        -- Brand-new indicator: the game's own new-item star.
        cell.newBadge = wm:CreateControl(nil, cell, CT_TEXTURE)
        cell.newBadge:SetDimensions(20, 20)
        cell.newBadge:SetAnchor(TOPLEFT, cell, TOPLEFT, 2, 2)
        cell.newBadge:SetTexture("EsoUI/Art/Inventory/newItem_icon.dds")
        cell.newBadge:SetMouseEnabled(false)
        cell.newBadge:SetDrawLevel(3)
        cell.newBadge:SetHidden(true)

        cell.junkBadge = self:CreateBackdrop(nil, cell, 0.34, 0.15, 0.00, 0.95, 1.00, 0.62, 0.08, 1)
        cell.junkBadge:SetAnchor(BOTTOMLEFT, cell, BOTTOMLEFT, 3, -3)
        cell.junkBadge:SetDimensions(66, 19)
        cell.junkBadge:SetMouseEnabled(false)
        cell.junkBadge:SetDrawLevel(3)

        cell.junkText = self:CreateLabel(nil, cell.junkBadge, "ZoFontGamepad18", 1.00, 0.86, 0.34, 1)
        cell.junkText:SetAnchorFill(cell.junkBadge)
        cell.junkText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        cell.junkText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        cell.junkText:SetText("JUNK")

        -- Lock indicator: the game's padlock icon (same one item tooltips use).
        cell.locked = wm:CreateControl(nil, cell, CT_TEXTURE)
        cell.locked:SetDimensions(18, 18)
        cell.locked:SetAnchor(TOPRIGHT, cell, TOPRIGHT, -2, 2)
        cell.locked:SetTexture("EsoUI/Art/Tooltips/icon_lock.dds")
        cell.locked:SetMouseEnabled(false)
        cell.locked:SetDrawLevel(3)

        cell.selection = self:CreateBackdrop(nil, cell, 0.05, 0.85, 1.00, 0.26, 1.00, 1.00, 1.00, 1)
        cell.selection:SetDrawLevel(4)
        cell.selection:SetAnchorFill(cell)
        cell.selection:SetMouseEnabled(false)
        cell.selection:SetHidden(true)

        cell:SetHandler("OnMouseEnter", function()
            local globalIndex = self.currentPage * self.pageSize + i
            local hoveredItem = self.items[globalIndex]
            if hoveredItem then
                self.selectedIndex = globalIndex
                self:Render()
                self:ShowHoverTooltip(cell, hoveredItem.bagId, hoveredItem.slotIndex)
            end
        end)

        cell:SetHandler("OnMouseExit", function()
            self:HideHoverTooltip()
        end)

        cell:SetHandler("OnMouseUp", function(_, button)
            local globalIndex = self.currentPage * self.pageSize + i
            if self.items[globalIndex] then
                self.selectedIndex = globalIndex
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    self:UseSelected("mouse")
                else
                    self:Render()
                end
            end
        end)

        self.cells[i] = cell
    end

    self.selectionHalo = self:CreateBackdrop(nil, self.grid, 0.06, 0.80, 1.00, 0.22, 1.00, 1.00, 1.00, 1)
    self.selectionHalo:SetDimensions(self.cellSize + 18, self.cellSize + 18)
    self.selectionHalo:SetMouseEnabled(false)
    self.selectionHalo:SetHidden(true)
    if self.selectionHalo.SetDrawLevel then self.selectionHalo:SetDrawLevel(1000) end

    self.selectionBadge = self:CreateBackdrop(nil, self.grid, 0.00, 0.54, 0.88, 0.98, 1.00, 1.00, 1.00, 1)
    self.selectionBadge:SetDimensions(self.cellSize + 18, 26)
    self.selectionBadge:SetMouseEnabled(false)
    self.selectionBadge:SetHidden(true)
    if self.selectionBadge.SetDrawLevel then self.selectionBadge:SetDrawLevel(1001) end

    self.selectionBadgeText = self:CreateLabel(nil, self.selectionBadge, "ZoFontGamepad18", 1, 1, 1, 1)
    self.selectionBadgeText:SetAnchorFill(self.selectionBadge)
    self.selectionBadgeText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.selectionBadgeText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.selectionBadgeText:SetText("SELECTED")

    -- Simple-view filter icon bar (hidden in full view). One clickable icon per main
    -- category; the active one is highlighted. LB/RB still cycle the full filter list.
    self.filterBar = wm:CreateControl(nil, self.window, CT_CONTROL)
    self.filterBar:SetAnchor(TOPLEFT, self.window, TOPLEFT, 40, 96)
    -- Enough buttons for whichever tab set is longer; UpdateFilterBar re-points the
    -- texture/key of each and hides the spares when the active set is shorter.
    local maxIcons = math.max(#FILTER_ICON_BAR, #CRAFT_FILTER_ICON_BAR)
    self.filterBar:SetDimensions(maxIcons * 48 - 4, 44)
    self.filterBar:SetHidden(true)
    self.filterIcons = {}
    do
        local ICON, GAP = 44, 4
        for i = 1, maxIcons do
            local entry = FILTER_ICON_BAR[i] or CRAFT_FILTER_ICON_BAR[i]
            local btn = self:CreateBackdrop(nil, self.filterBar, 0.04, 0.05, 0.07, 0.95, 0.30, 0.33, 0.40, 1)
            btn:SetDimensions(ICON, ICON)
            btn:SetAnchor(TOPLEFT, self.filterBar, TOPLEFT, (i - 1) * (ICON + GAP), 0)
            btn:SetMouseEnabled(true)

            local tex = wm:CreateControl(nil, btn, CT_TEXTURE)
            tex:SetAnchor(TOPLEFT, btn, TOPLEFT, 5, 5)
            tex:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, -5, -5)
            tex:SetTexture(entry.icon)
            btn:SetDrawLevel(2)
            tex:SetDrawLevel(2)
            btn.tex = tex
            btn.filterKey = entry.key

            -- Shown only when no candidate texture resolves, so a tab is never blank.
            local fb = self:CreateLabel(nil, btn, "ZoFontGamepadBold22", 1, 1, 1, 1)
            fb:SetAnchorFill(btn)
            fb:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            fb:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            fb:SetMouseEnabled(false)
            fb:SetDrawLevel(3)
            fb:SetHidden(true)
            btn.fallback = fb

            btn:SetHandler("OnMouseUp", function(_, mb)
                -- Read the live key: these buttons are re-pointed when Bag Type flips.
                if mb == MOUSE_BUTTON_INDEX_LEFT and btn.filterKey then self:SetFilterByKey(btn.filterKey) end
            end)
            self.filterIcons[i] = btn
        end
    end

    -- GridList-style active-filter name, shown left of the grid top while the bare
    -- icon bar sits right-aligned above the grid.
    self.filterNameLabel = self:CreateLabel(nil, self.window, "ZoFontGamepad27", 0.95, 0.95, 0.95, 1)
    self.filterNameLabel:SetHidden(true)
    self.filterNameLabel:SetDrawLevel(2)

    -- Backing strip behind the filter name + icons so they read over the game world,
    -- matching the grid's own frame style.
    self.filterBarBG = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.filterBarBG:SetHidden(true)

    -- Simple-view sort button, anchored under the bottom-left of the grid.
    self.sortButton = self:CreateBackdrop(nil, self.window, 0.04, 0.05, 0.07, 0.95, 0.30, 0.33, 0.40, 1)
    self.sortButton:SetDimensions(170, 32)
    self.sortButton:SetHidden(true)
    self.sortButton:SetMouseEnabled(true)
    if self.sortButton.SetDrawLevel then self.sortButton:SetDrawLevel(6) end
    self.sortButtonText = self:CreateLabel(nil, self.sortButton, "ZoFontGamepad22", 0.90, 0.90, 0.90, 1)
    self.sortButtonText:SetAnchorFill(self.sortButton)
    self.sortButtonText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.sortButtonText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.sortButtonText:SetMouseEnabled(false)
    if self.sortButtonText.SetDrawLevel then self.sortButtonText:SetDrawLevel(7) end
    self.sortButton:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:ToggleSortByType() end
    end)
    -- Bag Type button: Inventory <-> Craft. Sits immediately left of Sort so the two
    -- grid-scope controls read as a pair.
    self.bagTypeButton = self:CreateBackdrop(nil, self.window, 0.04, 0.05, 0.07, 0.95, 0.30, 0.33, 0.40, 1)
    self.bagTypeButton:SetDimensions(200, 32)
    self.bagTypeButton:SetHidden(true)
    self.bagTypeButton:SetMouseEnabled(true)
    if self.bagTypeButton.SetDrawLevel then self.bagTypeButton:SetDrawLevel(6) end
    self.bagTypeButtonText = self:CreateLabel(nil, self.bagTypeButton, "ZoFontGamepad22", 0.90, 0.90, 0.90, 1)
    self.bagTypeButtonText:SetAnchorFill(self.bagTypeButton)
    self.bagTypeButtonText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.bagTypeButtonText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.bagTypeButtonText:SetMouseEnabled(false)
    if self.bagTypeButtonText.SetDrawLevel then self.bagTypeButtonText:SetDrawLevel(7) end
    self.bagTypeButton:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:ToggleBagType() end
    end)

    -- Upgrade Bag button: simple view's d-pad path to Upgrade Bag Space (the
    -- character panel -- and its bag stop -- doesn't exist in simple view).
    -- Sits left of Bag Type; hidden once the bag is maxed, like native.
    self.bagUpgradeButton = self:CreateBackdrop(nil, self.window, 0.04, 0.05, 0.07, 0.95, 0.30, 0.33, 0.40, 1)
    self.bagUpgradeButton:SetDimensions(200, 32)
    self.bagUpgradeButton:SetHidden(true)
    self.bagUpgradeButton:SetMouseEnabled(true)
    if self.bagUpgradeButton.SetDrawLevel then self.bagUpgradeButton:SetDrawLevel(6) end
    self.bagUpgradeButtonText = self:CreateLabel(nil, self.bagUpgradeButton, "ZoFontGamepad22", 0.90, 0.90, 0.90, 1)
    self.bagUpgradeButtonText:SetAnchorFill(self.bagUpgradeButton)
    self.bagUpgradeButtonText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.bagUpgradeButtonText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.bagUpgradeButtonText:SetMouseEnabled(false)
    if self.bagUpgradeButtonText.SetDrawLevel then self.bagUpgradeButtonText:SetDrawLevel(7) end
    self.bagUpgradeButtonText:SetText("Upgrade Bag |cFFD700[+]|r")
    self.bagUpgradeButton:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:ShowBagUpgradeConfirm() end
    end)

    self:UpdateSortButtonLabel()

    -- Bank mode button (visible only at a banker): shows the current direction,
    -- click or A toggles Withdraw <-> Deposit. X does the same from anywhere.
    self.bankButton = self:CreateBackdrop(nil, self.window, 0.04, 0.05, 0.07, 0.95, 0.30, 0.33, 0.40, 1)
    self.bankButton:SetDimensions(200, 32)
    self.bankButton:SetAnchor(TOPLEFT, self.sortButton, TOPRIGHT, 10, 0)
    self.bankButton:SetHidden(true)
    self.bankButton:SetMouseEnabled(true)
    self.bankButtonText = self:CreateLabel(nil, self.bankButton, "ZoFontGamepad22", 0.9, 0.9, 0.9, 1)
    self.bankButtonText:SetAnchorFill(self.bankButton)
    self.bankButtonText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.bankButtonText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.bankButton:SetHandler("OnMouseUp", function(_, mb)
        if mb == MOUSE_BUTTON_INDEX_LEFT then self:SwitchBankPane() end
    end)

    -- Apply the initial layout (full view) now that grid, cells, and bar exist.
    self:ApplyLayout()
end

function GPI:CreateKeybindStrip()
    if self.keybindStrip then return end

    self.keybindStrip = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            -- Live label: advertises the ring hold while a ring is selected.
            name = function()
                if self:IsCraftBagMode() then
                    return "Withdraw"
                end
                if self:RingHoldEligible() then
                    return "Equip (Hold: Ring 2)"
                end
                if self:QuickslotHoldEligible() then
                    return "Use (Hold: Quickslot)"
                end
                return "Use / Equip"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() self:RunInputAction("PRIMARY", "keybind") end,
        },
        {
            name = "Mark Junk",
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function() self:RunInputAction("SECONDARY", "keybind") end,
            -- Junk does not apply to craft bag materials.
            visible = function() return not self:IsCraftBagMode() end,
        },
        {
            name = "Item Options",
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function() self:RunInputAction("TERTIARY", "keybind") end,
        },
        {
            name = "Close",
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function() self:RunInputAction("NEGATIVE", "keybind") end,
        },
        {
            name = "Prev Filter",
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            callback = function() self:RunInputAction("FILTER_PREV", "keybind") end,
        },
        {
            name = "Next Filter",
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function() self:RunInputAction("FILTER_NEXT", "keybind") end,
        },
        {
            name = "Item Info",
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            callback = function() self:RunInputAction("INFO", "keybind") end,
        },
        {
            name = "Compare",
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            callback = function() self:RunInputAction("COMPARE", "keybind") end,
        },
        {
            -- Overrides the native "Stack All" L3 bind (label AND behavior) while
            -- GridPad is up, matching the raw-keycode mapping.
            name = "Filter / Sort",
            keybind = "UI_SHORTCUT_LEFT_STICK",
            callback = function() self:RunInputAction("SORT_TOGGLE", "keybind") end,
        },
        {
            -- R3, matching the raw-keycode mapping. Live label so the schema always
            -- names the bag you would switch TO.
            name = function()
                if self.bankMode then return "Buy Bank Space" end
                return self:IsCraftBagMode() and "Bag: Inventory" or "Bag: Craft Bag"
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function() self:RunInputAction("BAG_TYPE_OR_BANK", "keybind") end,
        },
    }
end

function GPI:AddKeybindStrip()
    if not KEYBIND_STRIP or self.keybindsAdded then return end
    self:CreateKeybindStrip()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStrip)
    self.keybindsAdded = true
end

-- Dynamic keybind labels (Use/Equip vs Withdraw, Mark Junk visibility) only
-- re-evaluate when the strip is told to refresh, so filter changes call this.
function GPI:RefreshKeybindStrip()
    if not KEYBIND_STRIP or not self.keybindsAdded or not self.keybindStrip then return end
    SafeCall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStrip) end)
end

function GPI:RemoveKeybindStrip()
    if not KEYBIND_STRIP or not self.keybindsAdded then return end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStrip)
    self.keybindsAdded = false
    self.ringHintShown = nil -- resync the live label cache on next add
end

function GPI:IsCraftBagMode()
    return self.bagMode == "craft"
end

-- The two bags each have their own tab set, their own icon row, and their own
-- remembered tab index, so switching Bag Type never disturbs the other side.
function GPI:GetActiveFilterDefs()
    if self:IsCraftBagMode() then return CRAFT_FILTER_DEFS end
    return FILTER_DEFS
end

function GPI:GetActiveIconBar()
    if self:IsCraftBagMode() then return CRAFT_FILTER_ICON_BAR end
    return FILTER_ICON_BAR
end

function GPI:GetActiveFilterIndex()
    if self:IsCraftBagMode() then return self.craftFilterIndex or 1 end
    return self.filterIndex or 1
end

function GPI:SetActiveFilterIndex(index)
    if self:IsCraftBagMode() then self.craftFilterIndex = index else self.filterIndex = index end
    -- Leaving the New tab is what finally drops the items you already looked at.
    local def = self:GetCurrentFilter()
    if not def or def.key ~= "new" then self.newSeenKeys = nil end
end

-- Identity for the New tab's "seen this visit" list (bag slot + the item's unique id,
-- so a different item landing in the same slot is never mistaken for a seen one).
function GPI:GetNewKey(item)
    if not item then return "" end
    return tostring(item.bagId or "") .. ":" .. tostring(item.slotIndex or "") .. ":" .. tostring(item.uniqueId or item.instanceId or "")
end

function GPI:CountNewItems()
    local n = 0
    for i = 1, #(self.allItems or {}) do
        if self.allItems[i].isNew then n = n + 1 end
    end
    return n
end

-- Clear the "!" from every new backpack item at once.
function GPI:DismissAllNew()
    if not (SHARED_INVENTORY and SHARED_INVENTORY.ClearNewStatus) then
        self:Verdict(true, "This client can't clear new-item markers.")
        return
    end
    local cleared = 0
    for i = 1, #(self.allItems or {}) do
        local it = self.allItems[i]
        if it.isNew then
            pcall(function() SHARED_INVENTORY:ClearNewStatus(it.bagId, it.slotIndex) end)
            it.isNew = false
            cleared = cleared + 1
        end
    end
    self.newSeenKeys = nil -- "dismiss all" empties the New tab immediately
    if cleared == 0 then
        self:Verdict(false, "No new items to dismiss.")
    else
        self:Verdict(false, string.format("Marked %d new item%s as seen.", cleared, cleared == 1 and "" or "s"))
    end
    if self:IsShowing() then
        self:ApplyCurrentFilter(nil)
        self:Render()
    end
end

function GPI:GetCurrentFilter()
    local defs = self:GetActiveFilterDefs()
    return defs[self:GetActiveFilterIndex()] or defs[1]
end

function GPI:GetItemKey(item)
    if not item then return nil end
    return tostring(item.bagId or "") .. ":" .. tostring(item.slotIndex or "") .. ":" .. tostring(item.uniqueId or item.instanceId or "") .. ":" .. tostring(item.source or "")
end

function GPI:UpdateBankButton()
    if not self.bankButton then return end
    self.bankButton:SetHidden(true) -- superseded by the two-pane bank layout
    if true then return end
    if not self.bankMode then return end
    local focused = false
    self.bankButtonText:SetText(self.bankMode == "withdraw" and "Bank: Withdraw" or "Bank: Deposit")
    if focused then
        self.bankButton:SetCenterColor(0.10, 0.42, 0.55, 1)
        self.bankButton:SetEdgeColor(0.45, 0.95, 1.00, 1)
    else
        self.bankButton:SetCenterColor(0.04, 0.05, 0.07, 0.95)
        self.bankButton:SetEdgeColor(0.30, 0.33, 0.40, 1)
    end
end

function GPI:UpdateSortButtonLabel()
    if not self.sortButtonText then return end
    self:UpdateBankButton()
    self:UpdateBagTypeButtonLabel()
    self:UpdateBagUpgradeButtonLabel()
    local on = self.sv and self.sv.sortByType
    self.sortButtonText:SetText(on and "Sort: Item Type" or "Sort: Bag Order")
    if self.sortButton then
        if self.selZone == "bottombar" and (self.bottomIndex or BOTTOM_BUTTON_SORT) == BOTTOM_BUTTON_SORT then
            self.sortButton:SetCenterColor(0.10, 0.42, 0.55, 1)
            self.sortButton:SetEdgeColor(0.45, 0.95, 1.00, 1)
        else
            self.sortButton:SetCenterColor(0.04, 0.05, 0.07, 0.95)
            self.sortButton:SetEdgeColor(0.30, 0.33, 0.40, 1)
        end
    end
end

function GPI:UpdateBagUpgradeButtonLabel()
    if not self.bagUpgradeButton then return end
    self.bagUpgradeButton:SetHidden(not self.simpleView or not self:BagUpgradeRemaining())
    if self.selZone == "bottombar" and (self.bottomIndex or BOTTOM_BUTTON_SORT) == BOTTOM_BUTTON_UPGRADE then
        self.bagUpgradeButton:SetCenterColor(0.10, 0.42, 0.55, 1)
        self.bagUpgradeButton:SetEdgeColor(0.45, 0.95, 1.00, 1)
    else
        self.bagUpgradeButton:SetCenterColor(0.04, 0.05, 0.07, 0.95)
        self.bagUpgradeButton:SetEdgeColor(0.30, 0.33, 0.40, 1)
    end
end

function GPI:UpdateBagTypeButtonLabel()
    if not self.bagTypeButtonText then return end
    self.bagTypeButtonText:SetText(self:IsCraftBagMode() and "Bag Type: Craft" or "Bag Type: Inventory")
    if self.bagTypeButton then
        if self.selZone == "bottombar" and (self.bottomIndex or BOTTOM_BUTTON_SORT) == BOTTOM_BUTTON_BAGTYPE then
            self.bagTypeButton:SetCenterColor(0.10, 0.42, 0.55, 1)
            self.bagTypeButton:SetEdgeColor(0.45, 0.95, 1.00, 1)
        elseif self:IsCraftBagMode() then
            -- Standing highlight so it is obvious the grid is showing a different bag.
            self.bagTypeButton:SetCenterColor(0.10, 0.28, 0.16, 1)
            self.bagTypeButton:SetEdgeColor(0.35, 0.85, 0.50, 1)
        else
            self.bagTypeButton:SetCenterColor(0.04, 0.05, 0.07, 0.95)
            self.bagTypeButton:SetEdgeColor(0.30, 0.33, 0.40, 1)
        end
    end
end

-- Flip between the backpack and the craft bag. Each bag keeps its own tab, and paging
-- and selection restart at the top so the new grid never opens mid-list.
function GPI:SetBagType(mode, silent)
    mode = (mode == "craft") and "craft" or "inventory"
    if self.bagMode == mode then return end

    if mode == "craft" and BAG_VIRTUAL == nil then
        self:Verdict(true, "This client does not expose a craft bag.")
        return
    end

    self.bagMode = mode
    self.currentPage = 0
    self.selectedIndex = 1
    if self.selZone == "doll" then self.selZone = "grid" end

    if mode == "craft" then self:InvalidateCraftBag() end
    self:ApplyCurrentFilter(nil)
    self:UpdateBagTypeButtonLabel()
    self:RefreshKeybindStrip()
    self:Render()

    if not silent then
        if mode == "craft" then
            local n = #(self.items or {})
            local msg = "Craft Bag: " .. tostring(n) .. " stack" .. (n == 1 and "" or "s") .. "."
            if not self:HasCraftBagAccess() then msg = msg .. " ESO Plus inactive -- withdraw only." end
            self:Verdict(false, msg)
        else
            self:Verdict(false, "Inventory.")
        end
    end
end

function GPI:ToggleBagType()
    self:SetBagType(self:IsCraftBagMode() and "inventory" or "craft")
end

function GPI:ToggleSortByType()
    if not self.sv then return end
    self.sv.sortByType = not self.sv.sortByType
    self:UpdateSortButtonLabel()
    local keepKey = self:GetItemKey(self:GetSelectedItem())
    self:ApplyCurrentFilter(keepKey)
    self:Render()
end

function GPI:ApplyCurrentFilter(keepItemKey)
    self.items = {}
    local filter = self:GetCurrentFilter()
    local filterKey = filter and filter.key or "all"

    -- Craft bag mode draws from its own cached list; inventory mode draws from the
    -- worn+backpack list, which never contains craft bag items.
    local sourceItems = self.allItems or {}
    if self:IsCraftBagMode() then sourceItems = self:GetCraftBagItems() end

    for i = 1, #sourceItems do
        local item = sourceItems[i]
        if ItemMatchesFilter(item, filterKey) then
            table.insert(self.items, item)
        end
    end

    -- Simple-view sort button: group by item type (then name), with bag order as a
    -- stable tiebreak. Off = natural bag-slot order, exactly as before.
    if self.sv and self.sv.sortByType then
        table.sort(self.items, function(a, b)
            local ta, tb = a.itemType or 0, b.itemType or 0
            if ta ~= tb then return ta < tb end
            local na, nb = a.name or "", b.name or ""
            if na ~= nb then return na < nb end
            if (a.bagId or 0) ~= (b.bagId or 0) then return (a.bagId or 0) < (b.bagId or 0) end
            return (a.slotIndex or 0) < (b.slotIndex or 0)
        end)
    end

    if self.bankMode and self.bankAllItems then self:ApplyBankFilter() end

    if #self.items == 0 then
        self.selectedIndex = 1
        self.currentPage = 0
        return
    end

    local selected = nil
    if keepItemKey then
        for i = 1, #self.items do
            if self:GetItemKey(self.items[i]) == keepItemKey then
                selected = i
                break
            end
        end
    end

    if not selected then
        selected = Clamp(self.selectedIndex or 1, 1, #self.items)
    end

    self.selectedIndex = selected
    self.currentPage = Clamp(math.floor((self.selectedIndex - 1) / self.pageSize), 0, math.max(0, math.ceil(#self.items / self.pageSize) - 1))
end

function GPI:SetFilter(filterText)
    filterText = string.lower(tostring(filterText or ""))
    if filterText == "" then
        self:CycleFilter(1)
        return
    end

    local defs = self:GetActiveFilterDefs()
    local newIndex = nil
    for i = 1, #defs do
        local def = defs[i]
        if filterText == string.lower(def.key) or filterText == string.lower(def.label or "") or filterText == string.lower(GetFilterLabel(def) or "") then
            newIndex = i
            break
        end
    end

    if not newIndex then
        AddChatMessage("Unknown filter '" .. tostring(filterText) .. "'. Use /gpi filters to list filters.")
        return
    end

    local keepKey = self:GetItemKey(self:GetSelectedItem())
    self:SetActiveFilterIndex(newIndex)
    self.currentPage = 0
    self:ApplyCurrentFilter(keepKey)
    self:Render()
    AddChatMessage("filter set to " .. GetFilterLabel(self:GetCurrentFilter()) .. ".")
end

-- Same filter (and sort) as the backpack grid, applied to the bank pane. Selection
-- and page are NOT reset here -- inventory refreshes run this constantly; the render
-- pass clamps out-of-range positions. Filter CHANGES reset via CycleFilter below.
function GPI:ApplyBankFilter()
    self.bankItems = {}
    -- The bank never holds craft bag materials, so while the grid is in craft mode the
    -- bank pane falls back to the inventory "All" tab rather than filtering to nothing.
    local filter = self:GetCurrentFilter()
    if self:IsCraftBagMode() then filter = FILTER_DEFS[1] end
    local filterKey = filter and filter.key or "all"
    for i = 1, #(self.bankAllItems or {}) do
        local item = self.bankAllItems[i]
        if ItemMatchesFilter(item, filterKey) then
            table.insert(self.bankItems, item)
        end
    end
    if self.sv and self.sv.sortByType then
        table.sort(self.bankItems, function(a, b)
            local ta, tb = a.itemType or 0, b.itemType or 0
            if ta ~= tb then return ta < tb end
            local na, nb = a.name or "", b.name or ""
            if na ~= nb then return na < nb end
            if (a.bagId or 0) ~= (b.bagId or 0) then return (a.bagId or 0) < (b.bagId or 0) end
            return (a.slotIndex or 0) < (b.slotIndex or 0)
        end)
    end
end

function GPI:CycleFilter(delta)
    if self.bankMode then
        self.bankPage = 0
        self.bankIndex = 1
    end
    local defs = self:GetActiveFilterDefs()
    local bar = self:GetActiveIconBar()
    if #defs == 0 then return end
    local keepKey = self:GetItemKey(self:GetSelectedItem())

    -- In simple view, LB/RB steps through the on-screen icon bar in its exact order
    -- so the highlight moves one icon at a time. In full view, it cycles the complete
    -- filter list. Either way it stays inside the active bag's own tab set.
    if self.simpleView and bar and #bar > 0 then
        local currentKey = self:GetCurrentFilter().key
        local barPos = 1
        for i = 1, #bar do
            if bar[i].key == currentKey then barPos = i break end
        end
        local nextPos = ((barPos - 1 + delta) % #bar) + 1
        local nextKey = bar[nextPos].key
        for i = 1, #defs do
            if defs[i].key == nextKey then self:SetActiveFilterIndex(i) break end
        end
    else
        self:SetActiveFilterIndex(((self:GetActiveFilterIndex() - 1 + delta) % #defs) + 1)
    end

    -- Changing tabs restarts paging from the top of the new list.
    self.currentPage = 0
    self:ApplyCurrentFilter(keepKey)
    self:Render()
end

function GPI:SetFilterByKey(key)
    local defs = self:GetActiveFilterDefs()
    for i = 1, #defs do
        if defs[i].key == key then
            local keepKey = self:GetItemKey(self:GetSelectedItem())
            self:SetActiveFilterIndex(i)
            self.currentPage = 0
            self:ApplyCurrentFilter(keepKey)
            self:Render()
            return true
        end
    end
    return false
end

-- Highlight the icon whose filter is active (and dim the rest). Called from Render.
function GPI:UpdateToggleChrome()
    if not self.viewToggle then return end
    local base = self.simpleView and "View: Simple" or "View: Full"
    if self.selZone == "toggle" then
        self.viewToggle:SetCenterColor(0.10, 0.42, 0.55, 1)
        self.viewToggle:SetEdgeColor(0.45, 0.95, 1.00, 1)
        if self.viewToggleText then
            self.viewToggleText:SetColor(1, 1, 1, 1)
            self.viewToggleText:SetText("> " .. base .. " <")
        end
    else
        self.viewToggle:SetCenterColor(ESO.panelR, ESO.panelG, ESO.panelB, ESO.panelA)
        self.viewToggle:SetEdgeColor(ESO.edgeR, ESO.edgeG, ESO.edgeB, ESO.edgeA)
        if self.viewToggleText then
            self.viewToggleText:SetColor(ESO.goldR, ESO.goldG, ESO.goldB, 1)
            self.viewToggleText:SetText(base)
        end
    end
end

-- GridList-style bar: bare icons (no boxes) -- the active one is bright white, the
-- rest are dim gray -- with the active filter's name spelled out on the left.
-- Draw an icon when the entry has a trusted (or user-verified) path, otherwise draw the
-- two-letter abbreviation. No runtime probing: a wrong path yields ESO's white-box
-- placeholder, which probes as valid, so the only reliable signal is a path we trust.
-- Borrow an icon from the first item that actually lives in this tab. Cached per tab
-- and cleared whenever the craft bag is invalidated.
function GPI:GetRepresentativeIcon(entry)
    if not entry or not entry.key then return nil end
    self._repIcons = self._repIcons or {}
    local cached = self._repIcons[entry.key]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    -- Only craft tabs need this, and only while the craft bag is the active bag, so the
    -- lookup can never force a craft bag scan from the inventory grid.
    if not self:IsCraftBagMode() then return nil end

    local items = self:GetCraftBagItems()
    for i = 1, #items do
        local it = items[i]
        if it.icon and it.icon ~= "" and ItemMatchesFilter(it, entry.key) then
            self._repIcons[entry.key] = it.icon
            return it.icon
        end
    end

    self._repIcons[entry.key] = false -- tab is empty; nothing to borrow
    return nil
end

function GPI:ApplyFilterIcon(btn, entry)
    local path, forcedText = ResolvedIconPath(self.sv, entry)
    btn.iconDerived = false
    if not forcedText and (type(path) ~= "string" or path == "") then
        -- No trusted tab art: use a representative item's own icon before falling all
        -- the way back to letters.
        path = self:GetRepresentativeIcon(entry)
        btn.iconDerived = (path ~= nil)
    end
    local ok = (type(path) == "string" and path ~= "")
    if ok and btn.tex then btn.tex:SetTexture(path) end
    if btn.tex then btn.tex:SetHidden(not ok) end
    if btn.fallback then
        btn.fallback:SetText(ok and "" or tostring(entry.abbr or string.sub(entry.key or "?", 1, 2)))
        btn.fallback:SetHidden(ok)
    end
    btn.iconResolved = ok
    btn.iconPath = path
    return ok
end

function GPI:UpdateFilterBar()
    if not self.filterIcons then return end
    local bar = self:GetActiveIconBar()
    local active = self:GetCurrentFilter()
    local activeKey = active.key
    local ICON, GAP = 44, 4

    for i = 1, #self.filterIcons do
        local btn = self.filterIcons[i]
        local entry = bar[i]
        if not entry then
            btn:SetHidden(true)
        else
            -- Re-point this button at the active set's entry for this position.
            if btn.filterKey ~= entry.key or btn.iconResolved == nil or self._iconsDirty then
                btn.filterKey = entry.key
                self:ApplyFilterIcon(btn, entry)
            end
            btn:ClearAnchors()
            btn:SetAnchor(TOPLEFT, self.filterBar, TOPLEFT, (i - 1) * (ICON + GAP), 0)
            btn:SetHidden(false)
            btn:SetCenterColor(0, 0, 0, 0)
            btn:SetEdgeColor(0, 0, 0, 0)
            local on = (entry.key == activeKey)
            if btn.tex then
                if on then btn.tex:SetColor(1, 1, 1, 1) else btn.tex:SetColor(0.52, 0.55, 0.60, 0.9) end
            end
            if btn.fallback and not btn.fallback:IsHidden() then
                -- Text tabs get the same active/inactive treatment as icon tabs, plus a
                -- visible frame so they still read as buttons.
                if on then
                    btn.fallback:SetColor(1, 1, 1, 1)
                    btn:SetEdgeColor(1.00, 0.79, 0.30, 1)
                else
                    btn.fallback:SetColor(0.52, 0.55, 0.60, 0.9)
                    btn:SetEdgeColor(0.30, 0.33, 0.40, 1)
                end
            end
        end
    end

    -- Keep the bar's own width honest so it stays flush-right above the grid.
    self._iconsDirty = nil
    local barW = math.max(1, #bar * (ICON + GAP) - GAP)
    if self.filterBar then self.filterBar:SetWidth(barW) end

    if self.filterNameLabel then
        -- No bag prefix here: the Bag Type button already spells out which bag is
        -- showing, and craft tab names are long enough ("FURNISHING MATERIALS") that
        -- the extra text ran underneath the icon row.
        self.filterNameLabel:SetText(string.upper(active.label or activeKey or ""))

        -- The label is left-anchored and the icon row is right-anchored on the SAME
        -- line, so the label must fit in whatever the row leaves behind. Eleven icons
        -- eat ~524px, which on a 12-column grid leaves too little for a name like
        -- "FURNISHING MATERIALS" -- and a label with no explicit width auto-sizes to its
        -- text and slides straight under the icons.
        --
        -- So: size it to the gap when there is room, and hide it outright when there
        -- isn't. Nothing is lost when it hides -- the header above the grid already
        -- spells out the active tab in full (plus the stack count), and the icon row
        -- highlights it. Better an absent label than a truncated one under the icons.
        local gridW = (self.grid and self.grid.GetWidth and self.grid:GetWidth()) or 0
        local avail = gridW - barW - 28 -- 28 = breathing room between text and icons
        if gridW <= 0 then
            self.filterNameLabel:SetHidden(not self.simpleView)
        elseif avail < 150 then
            self.filterNameLabel:SetHidden(true)
        else
            self.filterNameLabel:SetDimensions(avail, 30)
            self.filterNameLabel:SetHidden(not self.simpleView)
        end
    end
end

-- Position and size the grid + cells for the active layout preset, and show/hide
-- the side panels and filter bar accordingly.
function GPI:ApplyLayout()
    local preset = self.simpleView and self.layoutSimple or self.layoutFull
    -- Simple view: semi-transparent grid surfaces so the game shows through.
    local baseA = (self.sv and self.sv.simpleOpacity) or 0.85
    local frameA = self.simpleView and baseA or ESO.panelA
    local cellA = self.simpleView and math.min(1.0, baseA + 0.10) or ESO.cellA
    self.cols = preset.cols
    self.rows = preset.rows
    self.cellSize = preset.cellSize
    self.cellGap = preset.cellGap
    self.pageSize = self.cols * self.rows
    if self.pageSize > self.maxCells then self.pageSize = self.maxCells end

    -- Grid size, and position.
    local gw = (self.cellSize + self.cellGap) * self.cols - self.cellGap
    local gh = (self.cellSize + self.cellGap) * self.rows - self.cellGap
    if self.grid then
        self.grid:ClearAnchors()
        if self.simpleView and preset.rightPin then
            -- Anchor to GuiRoot (the true screen edge), not the window. The window is
            -- only 1950 wide and centered, so on wider screens it does not reach the
            -- edge; anchoring to GuiRoot lets the grid pin flush right. The vertical
            -- position (upper / center / lower right) comes from the saved setting.
            local rm = preset.marginRight or 8
            local vm = preset.marginTop or 70   -- top/bottom margin for the edge positions
            local pos = (self.sv and self.sv.simplePosition) or "center"
            if pos == "top" then
                self.grid:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -rm, vm)
            elseif pos == "bottom" then
                self.grid:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -rm, -vm)
            else -- "center"
                self.grid:SetAnchor(RIGHT, GuiRoot, RIGHT, -rm, 0)
            end
        else
            self.grid:SetAnchor(TOPLEFT, self.window, TOPLEFT, preset.gridX, preset.gridY)
        end
        self.grid:SetDimensions(gw, gh)
    end

    -- Reflow every allocated cell; hide the ones beyond this preset's page size.
    if self.cells then
        for i = 1, #self.cells do
            local cell = self.cells[i]
            if i <= self.pageSize then
                local col = (i - 1) % self.cols
                local row = math.floor((i - 1) / self.cols)
                cell:ClearAnchors()
                cell:SetDimensions(self.cellSize, self.cellSize)
                cell:SetAnchor(TOPLEFT, self.grid, TOPLEFT, col * (self.cellSize + self.cellGap), row * (self.cellSize + self.cellGap))
                cell:SetCenterColor(ESO.cellR, ESO.cellG, ESO.cellB, cellA)
                cell:SetHidden(false)
            else
                cell:SetHidden(true)
            end
        end
    end

    -- Selection chrome scales with the cell size.
    if self.selectionHalo then self.selectionHalo:SetDimensions(self.cellSize + 18, self.cellSize + 18) end
    if self.selectionBadge then self.selectionBadge:SetDimensions(self.cellSize + 18, 26) end

    local simple = self.simpleView

    -- In simple view, EVERYTHING except the grid, the filter icon bar, and the view
    -- toggle is hidden, and the full-screen window background goes transparent so the
    -- center of the screen is not obscured. Full view restores all chrome.
    if self.charPanel then
        local hiddenBySetting = self.sv and self.sv.hideCharacterPanel
        -- The paperdoll now lives in both views: full view keeps its fixed spot;
        -- simple view snaps it into the first native bar (positioned in Render,
        -- where the bar rect is measured live).
        self.charPanel:SetHidden(hiddenBySetting == true)
        if not simple then
            self.charPanel:ClearAnchors()
            self.charPanel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 26, 148)
            self.charPanel:SetDimensions(380, 815)
            self:LayoutDollSlots(380)
            -- (native currency restore is deferred to Hide; doing it while open
            -- re-shows the native quadrant tooltip background bars.)
        end
    end
    if self.details then self.details:SetHidden(simple) end
    if self.itemTooltip and simple then self.itemTooltip:SetHidden(true) end
    if self.title then self.title:SetHidden(simple) end
    if self.help then self.help:SetHidden(simple) end
    if self.debugLabel and simple then self.debugLabel:SetHidden(true) end
    -- currencyBar dual-homes; laid out after the grid frame below (needs gw).
    if self.filterInfo then self.filterInfo:SetHidden(simple) end

    -- Full-screen scrim: opaque in full view (covers native inventory), fully
    -- transparent in simple view (game shows through, nothing dimmed).
    if self.modalBackdrop then
        if simple then
            self.modalBackdrop:SetCenterColor(0, 0, 0, 0)
        else
            self.modalBackdrop:SetCenterColor(0, 0, 0, 0.965)
        end
    end

    -- Window background: solid framed panel in full view, invisible in simple view.
    if self.background then
        if simple then
            self.background:SetCenterColor(0, 0, 0, 0)
            self.background:SetEdgeColor(0, 0, 0, 0)
        else
            self.background:SetCenterColor(ESO.bgR, ESO.bgG, ESO.bgB, ESO.bgA)
            self.background:SetEdgeColor(ESO.edgeR, ESO.edgeG, ESO.edgeB, ESO.edgeA)
        end
    end

    -- Filter icon bar: shown only in simple view, on one row just above the grid,
    -- left-aligned to the grid. The View toggle shares this row at the right end.
    if self.sortButton then
        self.sortButton:SetHidden(not simple)
        if simple and self.grid then
            self.sortButton:ClearAnchors()
            if self.filterBarBG then
                -- Top-right of the grid block, floating just above the filter strip.
                self.sortButton:SetAnchor(BOTTOMRIGHT, self.filterBarBG, TOPRIGHT, 0, -6)
            else
                self.sortButton:SetAnchor(BOTTOMRIGHT, self.grid, TOPRIGHT, 8, -66)
            end
        end
        self:UpdateSortButtonLabel()
    end
    if self.bagTypeButton then
        self.bagTypeButton:SetHidden(not simple)
        if simple and self.sortButton then
            self.bagTypeButton:ClearAnchors()
            self.bagTypeButton:SetAnchor(TOPRIGHT, self.sortButton, TOPLEFT, -10, 0)
        end
        self:UpdateBagTypeButtonLabel()
    end
    if self.bagUpgradeButton then
        -- Only in simple view, and only while upgrades remain.
        self.bagUpgradeButton:SetHidden(not simple or not self:BagUpgradeRemaining())
        if simple and self.bagTypeButton then
            self.bagUpgradeButton:ClearAnchors()
            self.bagUpgradeButton:SetAnchor(TOPRIGHT, self.bagTypeButton, TOPLEFT, -10, 0)
        end
        self:UpdateBagUpgradeButtonLabel()
    end
    if self.filterBarBG then
        self.filterBarBG:SetHidden(not simple)
        if simple then
            self.filterBarBG:ClearAnchors()
            self.filterBarBG:SetAnchor(BOTTOMLEFT, self.grid, TOPLEFT, -8, -4)
            self.filterBarBG:SetAnchor(BOTTOMRIGHT, self.grid, TOPRIGHT, 8, -4)
            self.filterBarBG:SetHeight(58)
        end
    end
    if self.filterNameLabel then
        self.filterNameLabel:SetHidden(not simple)
        if simple then
            self.filterNameLabel:ClearAnchors()
            self.filterNameLabel:SetAnchor(BOTTOMLEFT, self.grid, TOPLEFT, 2, -22)
        end
    end
    if self.filterBar then
        self.filterBar:SetHidden(not simple)
        if simple then
            self.filterBar:ClearAnchors()
            self.filterBar:SetHeight(44)
            -- Flush to the grid's right edge; the active-tab name occupies the left of
            -- the same line and is width-capped in UpdateFilterBar so they never meet.
            self.filterBar:SetAnchor(BOTTOMRIGHT, self.grid, TOPRIGHT, 0, -12)
        end
    end

    -- Grid backing frame: wrap the grid with a small margin (simple view only).
    if self.gridFrame then
        if simple then
            local M = 12
            self.gridFrame:ClearAnchors()
            self.gridFrame:SetAnchor(TOPLEFT, self.grid, TOPLEFT, -M, -M)
            self.gridFrame:SetDimensions(gw + M * 2, gh + M * 2)
            self.gridFrame:SetCenterColor(ESO.panelR, ESO.panelG, ESO.panelB, frameA)
            self.gridFrame:SetHidden(false)
        else
            self.gridFrame:SetHidden(true)
        end
    end

    -- Currency card (v1.9.2): full view keeps the original full-width bottom bar;
    -- simple view snaps a compact 4-column card under the grid frame, clearing the
    -- sort chip, with labels reflowed and a smaller font to fit the narrower width.
    if self.currencyBar and self.curLabels then
        self.currencyBar:SetHidden(false)
        self.currencyBar:ClearAnchors()
        if simple then
            local M = 12
            local barW = gw + M * 2
            self.currencyBar:SetAnchor(TOPLEFT, self.gridFrame or self.grid, BOTTOMLEFT, 0, -2)
            self.currencyBar:SetDimensions(barW, 128)
            local colW = math.floor((barW - 24) / 4)
            for i = 1, #self.curLabels do
                local lbl = self.curLabels[i]
                local col = (i - 1) % 4
                local row = math.floor((i - 1) / 4)
                lbl:ClearAnchors()
                lbl:SetAnchor(TOPLEFT, self.currencyBar, TOPLEFT, 14 + col * colW, 8 + row * 29)
                lbl:SetDimensions(colW - 8, 26)
                if lbl.SetFont then lbl:SetFont("ZoFontGamepad22") end
            end
        else
            self.currencyBar:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, 14, -10)
            self.currencyBar:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -14, -10)
            self.currencyBar:SetHeight(68)
            local colW = math.floor((1950 - 28 - 24) / 7)
            for i = 1, #self.curLabels do
                local lbl = self.curLabels[i]
                local c = math.floor((i - 1) / 2) + 1
                local r = ((i - 1) % 2) + 1
                lbl:ClearAnchors()
                lbl:SetAnchor(TOPLEFT, self.currencyBar, TOPLEFT, 18 + (c - 1) * colW, r == 1 and 5 or 34)
                lbl:SetDimensions(colW - 10, 30)
                if lbl.SetFont then lbl:SetFont("ZoFontGamepad27") end
            end
        end
    end

    -- View toggle: in simple view, float it just above the filter bar, right-aligned
    -- to the grid block so it stays reachable (press UP from the top row).
    if self.viewToggle then
        -- Simple view is the standard view now; the toggle button is retired from
        -- the UI (full view remains reachable via /gpi view or the settings panel).
        self.viewToggle:SetHidden(true)
    end

    -- Simple view has no character panel; keep the selector in the grid/toggle zones.
    if simple and self.selZone == "doll" then self.selZone = "grid" end

    -- Keep the selection valid within the new page size.
    if self.selectedIndex then
        self.currentPage = math.floor((self.selectedIndex - 1) / self.pageSize)
    end
end

function GPI:SetSimpleView(on)
    on = on == true
    if self.simpleView == on then return end
    self.simpleView = on
    if self.sv then self.sv.simpleView = on end

    -- Entering simple view always starts on the first icon ("all"), and if the
    -- current filter is not one of the icon-bar categories, snap to "all" too.
    if on then
        local currentKey = self:GetCurrentFilter().key
        local inBar = false
        for i = 1, #FILTER_ICON_BAR do
            if FILTER_ICON_BAR[i].key == currentKey then inBar = true break end
        end
        if not inBar then self:SetFilterByKey("all") end
    end

    self:ApplyLayout()
    if self:IsShowing() then self:Render() end
end

function GPI:ToggleSimpleView()
    self:SetSimpleView(not self.simpleView)
end

function GPI:GetFilterListText()
    local defs = self:GetActiveFilterDefs()
    local names = {}
    for i = 1, #defs do
        table.insert(names, defs[i].key .. "=" .. GetFilterLabel(defs[i]))
    end
    return table.concat(names, ", ")
end

local CHAR_SLOT_SHORT = {
    EQUIP_SLOT_HEAD = "Head",
    EQUIP_SLOT_SHOULDERS = "Shldr",
    EQUIP_SLOT_CHEST = "Chest",
    EQUIP_SLOT_HAND = "Hands",
    EQUIP_SLOT_WAIST = "Waist",
    EQUIP_SLOT_LEGS = "Legs",
    EQUIP_SLOT_FEET = "Feet",
    EQUIP_SLOT_NECK = "Neck",
    EQUIP_SLOT_RING1 = "Ring1",
    EQUIP_SLOT_RING2 = "Ring2",
    EQUIP_SLOT_COSTUME = "Cost.",
}

local function AbbrevNumber(n)
    n = tonumber(n) or 0
    if n >= 1000000 then
        local v = n / 1000000
        if v >= 100 then return string.format("%.0fM", v) elseif v >= 10 then return string.format("%.1fM", v) end
        return string.format("%.2fM", v)
    elseif n >= 1000 then
        local v = n / 1000
        if v >= 100 then return string.format("%.0fK", v) elseif v >= 10 then return string.format("%.1fK", v) end
        return string.format("%.2fK", v)
    end
    return tostring(n)
end

-- Bar layout: { column, row, label, currency var or special kind }
local CURRENCY_BAR_DEFS = {
    { c = 1, r = 1, label = "BAG",      kind = "bag" },
    { c = 1, r = 2, label = "BANK",     kind = "bank" },
    { c = 2, r = 1, label = "GOLD",     var = "CURT_MONEY" },
    { c = 2, r = 2, label = "AP",       var = "CURT_ALLIANCE_POINTS" },
    { c = 3, r = 1, label = "TEL VAR",  var = "CURT_TELVAR_STONES" },
    { c = 3, r = 2, label = "KEYS",     var = "CURT_UNDAUNTED_KEYS" },
    { c = 4, r = 1, label = "CRYSTALS", var = "CURT_CHAOTIC_CREATIA" },
    { c = 4, r = 2, label = "CROWNS",   var = "CURT_CROWNS" },
    { c = 5, r = 1, label = "GEMS",     var = "CURT_CROWN_GEMS" },
    { c = 5, r = 2, label = "WRITS",    var = "CURT_WRIT_VOUCHERS" },
    { c = 6, r = 1, label = "SEALS",    var = "CURT_ENDEAVOR_SEALS" },
    { c = 6, r = 2, label = "FORTUNES", var = "CURT_ARCHIVAL_FORTUNES" },
    { c = 7, r = 1, label = "TICKETS",  var = "CURT_EVENT_TICKETS" },
    { c = 7, r = 2, label = "OUTFIT",   var = "CURT_STYLE_STONES" },
}

local function BagUsage(bagVar)
    local bagId = ConstantValue(bagVar)
    if bagId == nil or not GetBagSize then return nil, nil end
    return SafeCall(GetNumBagUsedSlots, bagId), SafeCall(GetBagSize, bagId)
end

function GPI:UpdateCurrencies()
    if not self.curLabels then return end
    for i = 1, #CURRENCY_BAR_DEFS do
        local def = CURRENCY_BAR_DEFS[i]
        local lbl = self.curLabels[(def.c - 1) * 2 + def.r]
        if lbl then
            local text = nil
            if def.kind == "bag" then
                local used, size = BagUsage("BAG_BACKPACK")
                if size then text = tostring(used or "?") .. "/" .. tostring(size) end
                -- Gold [+] marks the readout as the Upgrade Bag Space button
                -- while upgrades remain; it vanishes at max size, like native.
                if text and self:BagUpgradeRemaining() then text = text .. " |cFFD700[+]|r" end
            elseif def.kind == "bank" then
                local used, size = BagUsage("BAG_BANK")
                local used2, size2 = BagUsage("BAG_SUBSCRIBER_BANK")
                if size then
                    text = tostring((used or 0) + (used2 or 0)) .. "/" .. tostring(size + (size2 or 0))
                end
            else
                local curt = ConstantValue(def.var)
                if curt ~= nil and GetCurrencyAmount then
                    local location = (GetCurrencyPlayerStoredLocation and SafeCall(GetCurrencyPlayerStoredLocation, curt)) or ConstantValue("CURRENCY_LOCATION_CHARACTER")
                    local amount = location ~= nil and SafeCall(GetCurrencyAmount, curt, location) or nil
                    if amount ~= nil then
                        text = AbbrevNumber(amount)
                        if ZO_Currency_GetKeyboardCurrencyIcon then
                            local icon = SafeCall(ZO_Currency_GetKeyboardCurrencyIcon, curt)
                            if icon and icon ~= "" then text = text .. " |t26:26:" .. icon .. "|t" end
                        end
                    end
                end
            end
            if text then
                lbl:SetText("|cAEB4BE" .. def.label .. ":|r |c4FE07A" .. text .. "|r")
                lbl:SetHidden(false)
            else
                lbl:SetText("")
            end
        end
    end
end

-- Simple view: park the paperdoll in the first native bar area, compare-card style
-- (bar top down to the controller schema), centered horizontally in the bar.
-- Re-anchor the paperdoll slots for a given panel width: armor column pinned left,
-- jewelry column pinned right, weapon rows centered. (Creation order: 1-7 left,
-- 8-11 right, 12+ weapons in rows of three.) The stat-number labels are anchored
-- to their boxes, so they follow automatically.
function GPI:LayoutDollSlots(width)
    if not self.charSlots or self._dollLayoutW == width then return end
    self._dollLayoutW = width
    local BOX, GAP, COL_TOP = 54, 9, 96
    for i = 1, #self.charSlots do
        local slot = self.charSlots[i]
        local x, y
        if i <= 7 then
            x, y = 16, COL_TOP + (i - 1) * (BOX + GAP)
        elseif i <= 11 then
            x, y = width - 16 - BOX, COL_TOP + (i - 8) * (BOX + GAP)
        else
            local wi = i - 12
            local r = math.floor(wi / 3)
            local c = wi % 3
            local rowWidth = 3 * BOX + 2 * GAP
            x = math.floor((width - rowWidth) / 2) + c * (BOX + GAP)
            y = COL_TOP + 7 * (BOX + GAP) + 12 + r * (BOX + GAP)
        end
        slot.box:ClearAnchors()
        slot.box:SetAnchor(TOPLEFT, self.charPanel, TOPLEFT, x, y)
    end
end

function GPI:PositionSimpleDoll()
    if not self.charPanel or not self.simpleView then return end
    local hiddenBySetting = self.sv and self.sv.hideCharacterPanel
    local show = not hiddenBySetting and not self.compareOpen and not self.bankMode
    self.charPanel:SetHidden(not show)
    if not show then return end

    local screenH = GuiRoot:GetHeight()
    local topY, leftX, barW = 72, 64, 555
    local q1 = self:GetNativeBarRects()
    if q1 then topY, leftX, barW = q1.top, q1.left, q1.width end
    local stripTop
    local ksc = _G["ZO_KeybindStripControl"]
    if ksc and ksc.GetTop then
        local okS, t = pcall(function() return ksc:GetTop() end)
        if okS and type(t) == "number" and t > screenH * 0.5 and t < screenH then stripTop = t end
    end
    local bottomY = (stripTop and (stripTop - 35)) or (screenH - ((self.sv and self.sv.cmpBottomGap) or 96))

    local dollW = barW - 24 -- same inset as the compare cards
    self.charPanel:ClearAnchors()
    self.charPanel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, math.floor(leftX + 12), topY)
    self.charPanel:SetDimensions(dollW, math.floor(bottomY - topY))
    self:LayoutDollSlots(dollW)

    -- The native Currencies text renders in this same bar; clear it while the
    -- paperdoll owns the space (restored on close or when switching to full view).
    if not self.dollCurrenciesCleared and GAMEPAD_TOOLTIPS and GAMEPAD_LEFT_TOOLTIP then
        if pcall(function() GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP) end) then
            self.dollCurrenciesCleared = true
        end
    end
end

function GPI:UpdateCharacterPanel()
    if not self.charSlots then return end

    self:UpdateCurrencies()

    if self.charName and GetUnitName then
        self.charName:SetText(SafeCall(GetUnitName, "player") or "")
    end
    if self.charSub then
        local parts = {}
        local level = GetUnitLevel and SafeCall(GetUnitLevel, "player")
        local cp = GetUnitChampionPoints and SafeCall(GetUnitChampionPoints, "player")
        local class = GetUnitClass and SafeCall(GetUnitClass, "player")
        if level then table.insert(parts, "Level " .. tostring(level)) end
        if cp and cp > 0 then table.insert(parts, "CP " .. tostring(cp)) end
        if class and class ~= "" then table.insert(parts, tostring(class)) end
        self.charSub:SetText(table.concat(parts, " \226\128\162 "))
    end

    if self.charTitle then
        local title = GetUnitTitle and SafeCall(GetUnitTitle, "player")
        self.charTitle:SetText((title and title ~= "") and title or "")
    end

    if self.charAttrs then
        local function maxStat(name)
            local id = ConstantValue(name)
            local bonus = ConstantValue("STAT_BONUS_OPTION_APPLY_BONUS")
            if id ~= nil and GetPlayerStat then return SafeCall(GetPlayerStat, id, bonus) end
        end
        local function fmt(n)
            if not n then return "?" end
            if ZO_CommaDelimitNumber then local ok, s = pcall(ZO_CommaDelimitNumber, n); if ok and s then return s end end
            return tostring(n)
        end
        local m = maxStat("STAT_MAGICKA_MAX")
        local h = maxStat("STAT_HEALTH_MAX")
        local st = maxStat("STAT_STAMINA_MAX")
        self.charAttrs:SetText(string.format("|c7fb2ff%s|r   |cff7f7f%s|r   |c7fd67f%s|r", fmt(m), fmt(h), fmt(st)))
    end

    if self.charMundus then
        local boons = {}
        if GetNumBuffs and GetUnitBuffInfo then
            local n = SafeCall(GetNumBuffs, "player") or 0
            for bi = 1, n do
                local buffName = SafeCall(GetUnitBuffInfo, "player", bi)
                if type(buffName) == "string" then
                    local boon = buffName:match("^Boon:%s*(.+)$")
                    if boon then table.insert(boons, boon) end
                end
            end
        end
        self.charMundus:SetText(#boons > 0 and ("Boon: " .. table.concat(boons, ", ")) or "Boon: none")
    end

    if self.charDiff then
        if self.selZone == "doll" and self.dollOnDiff then
            self.charDiff:SetCenterColor(0.10, 0.42, 0.55, 1)
            self.charDiff:SetEdgeColor(0.45, 0.95, 1.00, 1)
        else
            self.charDiff:SetCenterColor(0.05, 0.06, 0.08, 0.95)
            self.charDiff:SetEdgeColor(0.30, 0.33, 0.40, 1)
        end
    end
    if self.charDiffText then
        local name = self:GetChallengeDifficultyName()
        if name then
            local focused = self.selZone == "doll" and self.dollOnDiff
            self.charDiffText:SetText(focused and ("\226\151\128 " .. name .. " \226\151\130") or ("Difficulty: " .. name))
            self.charDiffText:SetColor(0.94, 0.86, 0.60, 1)
        else
            self.charDiffText:SetText("Difficulty: --")
            self.charDiffText:SetColor(0.55, 0.58, 0.62, 1)
        end
    end

    if self.charBag and BAG_BACKPACK ~= nil then
        local size = SafeCall(GetBagSize, BAG_BACKPACK) or 0
        local used = (GetNumBagUsedSlots and SafeCall(GetNumBagUsedSlots, BAG_BACKPACK)) or 0
        local free = (GetNumBagFreeSlots and SafeCall(GetNumBagFreeSlots, BAG_BACKPACK)) or (size - used)
        local baseText = string.format("Bag: %d / %d \226\128\162 %d free", used, size, free)
        local canUpgrade = self:BagUpgradeRemaining() ~= nil
        local focused = self.selZone == "doll" and self.dollOnBag
        if focused then
            self.charBag:SetText(baseText .. (canUpgrade and " \226\128\162 A: Upgrade" or ""))
            self.charBag:SetColor(0.94, 0.86, 0.60, 1)
        else
            self.charBag:SetText(canUpgrade and (baseText .. " |cFFD700[+]|r") or baseText)
            self.charBag:SetColor(0.75, 0.78, 0.82, 1)
        end
        if self.charBagBtn then
            if focused then
                self.charBagBtn:SetCenterColor(0.10, 0.42, 0.55, 1)
                self.charBagBtn:SetEdgeColor(0.45, 0.95, 1.00, 1)
            else
                self.charBagBtn:SetCenterColor(0, 0, 0, 0)
                self.charBagBtn:SetEdgeColor(0, 0, 0, 0)
            end
        end
    end

    for i = 1, #self.charSlots do
        local slot = self.charSlots[i]
        local slotId = ConstantValue(slot.equipSlotVar)
        if slotId == nil or BAG_WORN == nil then
            slot.box:SetHidden(true)
            if slot.number then slot.number:SetHidden(true) end
        else
            slot.box:SetHidden(false)
            if slot.number then slot.number:SetHidden(false) end

            local item = GetBagItemData(BAG_WORN, slotId, "equipped", nil)
            if item then
                slot.icon:SetHidden(false)
                if item.icon then slot.icon:SetTexture(item.icon) end

                local r, g, b = 1, 1, 1
                if GetItemQualityColor then
                    local color = SafeCall(GetItemQualityColor, item.quality)
                    if color and color.UnpackRGB then
                        local cr, cg, cb = color:UnpackRGB()
                        if cr then r, g, b = cr, cg, cb end
                    end
                end
                slot.box:SetEdgeColor(r, g, b, 1)

                if slot.number then
                    -- Show the item's primary stat (Damage for weapons, Armor for armor).
                    -- Jewelry/costume have neither, so fall back to the level/CP requirement.
                    local primary = self:GetItemPrimaryStat(BAG_WORN, slotId)
                    if primary then
                        slot.number:SetText(tostring(primary))
                    else
                        local cpReq = GetItemRequiredChampionPoints and SafeCall(GetItemRequiredChampionPoints, BAG_WORN, slotId)
                        local lvlReq = GetItemRequiredLevel and SafeCall(GetItemRequiredLevel, BAG_WORN, slotId)
                        local num = (cpReq and cpReq > 0) and cpReq or lvlReq
                        slot.number:SetText(num and tostring(num) or "")
                    end
                    slot.number:SetColor(r, g, b, 1)
                end
            else
                slot.icon:SetHidden(true)
                slot.box:SetEdgeColor(0.28, 0.30, 0.34, 1)
                if slot.number then
                    slot.number:SetText(CHAR_SLOT_SHORT[slot.equipSlotVar] or "")
                    slot.number:SetColor(0.40, 0.43, 0.48, 1)
                end
            end

            -- Selector highlight when navigating the character panel.
            if self.selZone == "doll" and i == self.dollIndex and not self.dollOnDiff and not self.dollOnBag then
                slot.box:SetEdgeColor(0.30, 0.90, 1.00, 1)
            end
        end
    end
end

-- ============================== Craft Bag (BAG_VIRTUAL) ==============================
-- The craft bag is a VIRTUAL bag: its slot ids are sparse, so GetBagSize/0..n-1 does
-- not enumerate it. ZOS's own iterator is GetNextVirtualBagSlotId(previousSlotId),
-- which returns nil when the walk is done. The result is cached and only rebuilt when
-- a BAG_VIRTUAL slot update marks it dirty, so opening the tab on a full craft bag
-- costs one scan rather than one per inventory event.

function GPI:HasCraftBagAccess()
    -- Non-subscribers keep whatever is already stored (they can withdraw but not
    -- deposit), so an inaccessible craft bag is still worth showing.
    if HasCraftBagAccess then
        local ok = SafeCall(HasCraftBagAccess)
        if ok ~= nil then return ok == true end
    end
    if IsESOPlusSubscriber then
        local ok = SafeCall(IsESOPlusSubscriber)
        if ok ~= nil then return ok == true end
    end
    return true
end

function GPI:InvalidateCraftBag()
    self.craftBagDirty = true
    self._repIcons = nil   -- representative tab icons are derived from bag contents
    self._iconsDirty = true
end

function GPI:RefreshCraftBagItems()
    self.craftBagItems = {}
    self.craftBagDirty = false
    self.craftBagStackCount = 0

    if BAG_VIRTUAL == nil or GetNextVirtualBagSlotId == nil then return self.craftBagItems end

    local slotIndex = SafeCall(GetNextVirtualBagSlotId, nil)
    local guard = 0
    while slotIndex ~= nil and guard < 5000 do
        guard = guard + 1
        local item = GetBagItemData(BAG_VIRTUAL, slotIndex, "craftbag")
        if item then
            self.craftBagStackCount = self.craftBagStackCount + 1
            table.insert(self.craftBagItems, item)
        end
        slotIndex = SafeCall(GetNextVirtualBagSlotId, slotIndex)
    end

    return self.craftBagItems
end

function GPI:GetCraftBagItems()
    if self.craftBagDirty or self.craftBagItems == nil then
        self:RefreshCraftBagItems()
    end
    return self.craftBagItems or {}
end

-- Full stack, capped by what a single backpack slot can actually hold. GetSlotStackSize
-- returns (stackSize, maxStackSize); the 200 fallback is ESO's usual material cap.
function GPI:GetCraftBagWithdrawAmount(item)
    local stack = item.stack or 1
    if GetSlotStackSize then
        local size, maxStack = SafeCall(GetSlotStackSize, item.bagId, item.slotIndex)
        if type(size) == "number" and size > 0 then stack = size end
        if type(maxStack) == "number" and maxStack > 0 and maxStack < stack then return maxStack end
    end
    if stack > 200 then return 200 end
    return stack
end

function GPI:WithdrawFromCraftBag(item)
    if not item or not item.isCraftBag then return end

    local free = FindFirstEmptySlotInBag and SafeCall(FindFirstEmptySlotInBag, BAG_BACKPACK)
    if free == nil then
        self:Verdict(true, "Your backpack is full -- free a slot before withdrawing.")
        return
    end

    local amount = self:GetCraftBagWithdrawAmount(item)
    -- Same secure bridge the bank pane uses: RequestMoveItem is protected, so it must
    -- go through CallSecureProtected, and it only refuses during combat lockdown.
    local ok = CallSecureProtected ~= nil and pcall(function()
        CallSecureProtected("RequestMoveItem", BAG_VIRTUAL, item.slotIndex, BAG_BACKPACK, free, amount)
    end)

    if ok then
        self:Verdict(false, "Withdrew " .. tostring(amount) .. "x " .. tostring(item.name or "material") .. ".")
        self:InvalidateCraftBag()
        self:ScheduleRefresh()
        zo_callLater(function() self:InvalidateCraftBag() if self:IsShowing() then self:Refresh() end end, 300)
    else
        self:Verdict(true, "Couldn't withdraw that material (action blocked).")
    end
end

function GPI:Refresh()
    -- Zoning gate: a full refresh scans bags, generates ZOS slot data, and touches
    -- controls -- none of that is safe mid-load-screen. Deferred timers (post-equip
    -- 250/900ms, junk 150ms, ScheduleRefresh 100ms) all funnel through here, so this
    -- one guard covers every stale-callback path. Hidden windows never need it either.
    if self.zoning then return end
    if not self:IsShowing() then return end
    local keepKey = self:GetItemKey(self:GetSelectedItem())
    self.items = {}
    self.allItems = {}
    self.backpackItemCount = 0
    self.equippedItemCount = 0

    if self.showEquippedSection and BAG_WORN ~= nil then
        local equippedSlots = GetEquippedSlotInfos()
        for i = 1, #equippedSlots do
            local slotInfo = equippedSlots[i]
            local item = GetBagItemData(BAG_WORN, slotInfo.slotId, "equipped", slotInfo.name)
            if item then
                self.equippedItemCount = self.equippedItemCount + 1
                table.insert(self.allItems, item)
            end
        end
    end

    local bagSize = SafeCall(GetBagSize, BAG_BACKPACK) or 0
    for slotIndex = 0, bagSize - 1 do
        local item = GetBagItemData(BAG_BACKPACK, slotIndex, "backpack")
        if item then
            self.backpackItemCount = self.backpackItemCount + 1
            table.insert(self.allItems, item)
        end
    end

    -- At a banker, also (re)collect the bank pane's contents so both grids stay live.
    if self.bankMode then self:RefreshBankItems() end

    self:ApplyCurrentFilter(keepKey)
    self:UpdateCharacterPanel()
    self:Render()
end

function GPI:ScheduleRefresh()
    if not self:IsShowing() then return end
    if self.pendingRefresh then return end
    self.pendingRefresh = true

    zo_callLater(function()
        self.pendingRefresh = false
        self:Refresh()
    end, 100)
end

function GPI:GetSelectedItem()
    return self.items[self.selectedIndex]
end

-- How many grid positions represent something real on the current tab: items plus, on
-- the inventory All tab only, the bag's free capacity. Filtered tabs are subsets and
-- the craft bag is a virtual bag, so neither gets capacity padding.
function GPI:GetDisplaySlotCount()
    local n = #(self.items or {})
    if not self:IsCraftBagMode() then
        local f = self:GetCurrentFilter()
        if f and f.key == "all" then
            local bagSize = SafeCall(GetBagSize, BAG_BACKPACK) or 0
            local used = SafeCall(GetNumBagUsedSlots, BAG_BACKPACK) or 0
            -- Worn gear also occupies grid cells on All but not backpack capacity.
            local wornOnGrid = 0
            for i = 1, n do
                if self.items[i].isEquipped then wornOnGrid = wornOnGrid + 1 end
            end
            return n + math.max(0, bagSize - used), math.max(0, bagSize - used)
        end
    end
    return n, 0
end

function GPI:RenderCell(cell, item, globalIndex)
    if not item then
        cell.icon:SetHidden(true)
        cell.stack:SetText("")
        cell.equippedBadge:SetHidden(true)
        if cell.newBadge then cell.newBadge:SetHidden(true) end
        cell.junkBadge:SetHidden(true)
        cell.locked:SetHidden(true)
        cell.selection:SetHidden(true)
        if globalIndex ~= nil and globalIndex <= (self.displaySlotCount or 0) then
            -- A real free bag slot: clearly present, clearly open.
            cell:SetCenterColor(0.045, 0.05, 0.06, 0.70)
            cell:SetEdgeColor(0.24, 0.26, 0.30, 1)
        else
            -- Past the end of the bag: nearly invisible, so capacity reads at a glance.
            cell:SetCenterColor(0.02, 0.022, 0.028, 0.28)
            cell:SetEdgeColor(0.055, 0.06, 0.07, 0.55)
        end
        return
    end

    cell.icon:SetHidden(false)
    cell.icon:SetTexture(item.icon)

    -- GridList-style focus zoom: the selected item's icon grows past the cell edge.
    do
        local sel = (globalIndex == self.selectedIndex) and self.selZone ~= "doll" and self.selZone ~= "bottombar" and self.selZone ~= "bankgrid"
        local inset = sel and -6 or 5
        cell.icon:ClearAnchors()
        cell.icon:SetAnchor(TOPLEFT, cell, TOPLEFT, inset, inset)
        cell.icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -inset, -inset)
        -- Raise the icon itself (a cell-level raise would put the cell's opaque
        -- center fill above its own children and hide every icon).
        cell.icon:SetDrawLevel(sel and 2 or 0)
    end

    if item.stack and item.stack > 1 and not item.isEquipped then
        -- Craft bag stacks reach five figures; abbreviate so the badge stays readable.
        cell.stack:SetText(item.stack >= 10000 and AbbrevNumber(item.stack) or tostring(item.stack))
    else
        cell.stack:SetText("")
    end

    local isSelected = (globalIndex == self.selectedIndex) and self.selZone ~= "doll" and self.selZone ~= "bottombar" and self.selZone ~= "bankgrid"
    cell.equippedBadge:SetHidden(not item.isEquipped)
    if cell.newBadge then cell.newBadge:SetHidden(not (item.isNew and not item.isEquipped)) end
    cell.junkBadge:SetHidden(not item.isJunk)
    cell.locked:SetHidden(not (item.isPlayerLocked or item.locked))
    cell.selection:SetHidden(not isSelected)

    -- GridList-style quality edges: trash and normal quality are subdued to dark
    -- grays so that Fine/Superior/Epic/Legendary color tints actually pop.
    local r, g, b = GetQualityColor(item.quality)
    local q = item.quality or 1
    if item.isEquipped then
        cell:SetCenterColor(0.015, 0.13, 0.07, 0.98)
        cell:SetEdgeColor(0.20, 1.00, 0.45, 1)
    elseif item.isJunk then
        cell:SetCenterColor(0.18, 0.09, 0.01, 0.98)
        cell:SetEdgeColor(1.00, 0.58, 0.08, 1)
    else
        cell:SetCenterColor(0.075, 0.08, 0.09, 0.96)
        if q <= 0 then
            cell:SetEdgeColor(0.12, 0.12, 0.12, 0.6)
        elseif q == 1 then
            cell:SetEdgeColor(0.31, 0.31, 0.31, 0.6)
        else
            cell:SetEdgeColor(r, g, b, 0.9)
        end
    end

    if isSelected then
        cell:SetEdgeColor(1.00, 1.00, 1.00, 1)
        if item.isEquipped then
            cell.selection:SetCenterColor(0.15, 1.00, 0.35, 0.30)
            cell.selection:SetEdgeColor(0.80, 1.00, 0.82, 1)
        elseif item.isJunk then
            cell.selection:SetCenterColor(1.00, 0.72, 0.10, 0.30)
            cell.selection:SetEdgeColor(1.00, 0.95, 0.50, 1)
        else
            cell.selection:SetCenterColor(0.08, 0.85, 1.00, 0.30)
            cell.selection:SetEdgeColor(1.00, 1.00, 1.00, 1)
        end
    end
end

function GPI:EnforceInventoryTooltipHost()
    if not self.nativeControlsHidden or self.bankMode then return end
    -- Quiet period, not just "dialog showing now": confirming Destroy fires a
    -- slot update that triggers a render WHILE the dialog is tearing down, and
    -- re-hiding the tooltip host mid-teardown crashes the client (the same
    -- lesson the bank chrome learned; see EnforceBankChromeHidden). The quiet
    -- period keeps hands off for ~800ms after the dialog was last seen.
    if self:InDialogQuietPeriod() then return end
    local host = GetNamedControl("ZO_GamepadTooltipTopLevel")
    if host and host.GetAlpha and (SafeCall(function() return host:GetAlpha() end) or 0) > 0 then
        self:SetNativeControlHidden(host, true)
    end
end

function GPI:UpdateSelectionChrome()
    self:UpdateRingHoldHint()
    self:EnforceInventoryTooltipHost()
    if not self.selectionHalo or not self.selectionBadge then return end

    local item = self:GetSelectedItem()
    local pageIndex = self.selectedIndex - (self.currentPage * self.pageSize)
    local cell = self.cells and self.cells[pageIndex]

    if not item or not cell or self.selZone ~= "grid" then
        self.selectionHalo:SetHidden(true)
        self.selectionBadge:SetHidden(true)
        return
    end

    self.selectionHalo:ClearAnchors()
    self.selectionHalo:SetAnchor(CENTER, cell, CENTER, 0, 0)
    self.selectionHalo:SetHidden(false)

    self.selectionBadge:ClearAnchors()
    self.selectionBadge:SetAnchor(BOTTOM, cell, TOP, 0, -1)
    self.selectionBadge:SetHidden(false)

    if item.isEquipped then
        self.selectionHalo:SetCenterColor(0.08, 1.00, 0.25, 0.20)
        self.selectionHalo:SetEdgeColor(0.78, 1.00, 0.78, 1)
        self.selectionBadge:SetCenterColor(0.00, 0.58, 0.20, 0.98)
        self.selectionBadge:SetEdgeColor(0.85, 1.00, 0.85, 1)
    elseif item.isJunk then
        self.selectionHalo:SetCenterColor(1.00, 0.60, 0.08, 0.22)
        self.selectionHalo:SetEdgeColor(1.00, 0.95, 0.50, 1)
        self.selectionBadge:SetCenterColor(0.95, 0.42, 0.00, 0.98)
        self.selectionBadge:SetEdgeColor(1.00, 0.95, 0.50, 1)
    else
        self.selectionHalo:SetCenterColor(0.06, 0.80, 1.00, 0.22)
        self.selectionHalo:SetEdgeColor(1.00, 1.00, 1.00, 1)
        self.selectionBadge:SetCenterColor(0.00, 0.54, 0.88, 0.98)
        self.selectionBadge:SetEdgeColor(1.00, 1.00, 1.00, 1)
    end
end

-- ZOS locks the item tooltip to exactly 416 units wide (DimensionConstraints in
-- tooltip.xml); height auto-grows with content. This positions the tooltip so the
-- SCALED footprint (416 * tipScale) is centered in the details panel, after clearing
-- the template's built-in BOTTOM anchor (see the note at creation).
-- The keyboard tooltip's gold border is drawn by the C control at exactly the
-- control rect, and long centered lines can overhang it by a few units. Fix per
-- DCW's suggestion: widen the box itself. Raising the width constraint and the
-- ResizeToFitPadding by the SAME amount keeps the text wrap width ZOS-native
-- (416 - 32 = 384) while pushing the border outward around it.
function GPI:HideTooltipBackdrop(tip)
    if not tip then return end
    -- The ZO_Tooltip control draws its own gold NineTile frame. When we embed the
    -- tooltip inside our own panel, that frame shows as a second box behind ours, so
    -- hide it. The frame is a named child; try the known variants defensively.
    local name = tip.GetName and tip:GetName() or nil
    if name and _G[name .. "NineTile"] then
        pcall(function() _G[name .. "NineTile"]:SetHidden(true) end)
    end
    for _, suffix in ipairs({ "NineTile", "BG", "Backdrop", "Background" }) do
        local child = tip.GetNamedChild and tip:GetNamedChild(suffix) or nil
        if child and child.SetHidden then pcall(function() child:SetHidden(true) end) end
    end
    -- Some tooltip types expose a background control accessor.
    pcall(function() if tip.SetBackgroundHidden then tip:SetBackgroundHidden(true) end end)
end

function GPI:ApplyTooltipChrome(tip)
    if not tip then return end
    local pad = self.tipPad or 26
    local w = (self.tipWidth or 416) + 2 * pad
    pcall(function()
        tip:SetDimensionConstraints(w, 0, w, 0)
        tip:SetResizeToFitPadding(32 + 2 * pad, 57)
    end)
end

function GPI:ApplyTooltipLayout(scaleOverride)
    local tip = self.itemTooltip
    if not tip then return end
    local scale = scaleOverride or self.tipScale or 1.1
    local width = (self.tipWidth or 416) + 2 * (self.tipPad or 26)
    tip:ClearAnchors()
    tip:SetScale(scale)
    tip:SetAnchor(TOPLEFT, self.details, TOPLEFT, math.floor(math.max(8, (640 - width * scale) / 2)), 16)
end

-- Guaranteed height fit: measure the populated tooltip and, if the rendered card
-- (height x scale) would overflow the panel's tooltip area, shrink the scale for
-- THIS item only. Small tooltips render at the user's preferred /gpi tipscale.
function GPI:AutoFitTooltip()
    local tip = self.itemTooltip
    if not tip then return end
    local userScale = self.tipScale or 1.1
    local availableHeight = 810 - 16 - 20 -- panel height minus paddings
    local scale = userScale
    local contentHeight = (tip.GetHeight and tip:GetHeight()) or 0
    if contentHeight > 0 and (contentHeight * userScale) > availableHeight then
        scale = math.max(0.8, availableHeight / contentHeight)
    end
    self:ApplyTooltipLayout(scale)
end

-- Read the screen rect of a global control (by name), or nil if unavailable.
function GPI:GetControlRect(name)
    local c = _G[name]
    if not c or not c.GetLeft then return nil end
    local ok, l, t, w, h = pcall(function() return c:GetLeft(), c:GetTop(), c:GetWidth(), c:GetHeight() end)
    if not ok or not l or not w or w < 100 or not h or h < 100 then return nil end
    return { left = l, top = t, width = w, height = h }
end

-- The two native gamepad nav quadrant backgrounds ARE the vertical bars on screen.
-- Reading their live rects lets the ESO-style compare cards overlay them exactly.
function GPI:GetNativeBarRects()
    local q1 = self:GetControlRect("ZO_SharedGamepadNavQuadrant_1_Background")
    local q2 = self:GetControlRect("ZO_SharedGamepadNavQuadrant_2_Background")
    if q1 and q2 and q2.left > q1.left then return q1, q2 end
    return nil, nil
end

function GPI:PopulateCompareTip(tip, bagId, slotIndex, x, y, availH, centerW, centerVert)
    if not tip then return false end
    local ok = pcall(function()
        tip:ClearLines()
        tip:SetBagItem(bagId, slotIndex)
    end)
    if not ok then return false end
    -- Remember this card's slot geometry, lay out conservatively now, and let the
    -- deferred refit (next frame, when the tooltip's height is real) apply the exact
    -- scale and centering. Tooltips re-flow one frame after SetBagItem, so a same-frame
    -- GetHeight can be stale -- trusting it was what let text float low and overflow.
    tip._fit = { x = x, y = y, availH = availH, centerW = centerW, centerVert = centerVert and true or false }
    self:FitCompareTip(tip, true)
    return true
end

function GPI:FitCompareTip(tip, firstPass)
    local f = tip and tip._fit
    if not f then return end
    local baseW = self.compareTipW or ((self.tipWidth or 416) + 2 * (self.tipPad or 26))
    local h = (tip.GetHeight and tip:GetHeight()) or 0
    -- On the first pass, distrust small/zero heights: assume tall so the initial frame
    -- can never overflow. The refit pass measures for real.
    if firstPass and h < 300 then h = 1200 end
    if h <= 0 then h = 1200 end

    local scale = 1.0
    if h > f.availH then scale = f.availH / h end
    -- Never bleed over the card sides: cap the scale by the slot width too.
    if f.centerW then
        local maxW = f.centerW - 16
        if baseW * scale > maxW then scale = maxW / baseW end
    end

    local x = f.x
    if f.centerW then
        x = f.x + math.max(0, math.floor((f.centerW - baseW * scale) / 2))
    end
    local y = f.y
    if f.centerVert then
        local rh = h * scale
        y = f.y + math.max(0, math.floor((f.availH - rh) / 2))
    end
    tip:ClearAnchors()
    tip:SetScale(scale)
    tip:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x, y)
end

function GPI:RefitCompareTips()
    if not self.compareOpen or not self.compareTips then return end
    for i = 1, 3 do
        local tip = self.compareTips[i]
        if tip and tip._fit and (not tip.IsHidden or not tip:IsHidden()) then
            self:FitCompareTip(tip, false)
        end
    end
end

function GPI:ToggleCompare()
    if self.compareOpen then self:HideCompare() else self:ShowCompare(false) end
end

function GPI:HideInfoPopup()
    self.infoPopupOpen = false
    self.infoPopupMode = nil
    if self.infoPopup then self.infoPopup:SetHidden(true) end
    if self.infoPopupTooltip then pcall(function() self.infoPopupTooltip:ClearLines() end); self.infoPopupTooltip:SetHidden(true) end
end

-- Render the panel for the current mode: "details" (native tooltip) or "stats"
-- (item-info + character-stat comparison). Both share the currency-style column.
-- The item the details card describes: the focused paperdoll slot when the doll
-- has focus, otherwise the grid selection.
function GPI:GetInfoPopupItem()
    if self.bankMode and self.selZone == "bankgrid" then
        return self:GetBankSelectedItem()
    end
    if self.selZone == "doll" and BAG_WORN ~= nil then
        local slotId = self:GetDollSlotInfo()
        if slotId ~= nil then
            local item = GetBagItemData(BAG_WORN, slotId, "equipped", nil)
            if item then return item end
        end
        return nil -- empty doll slot: nothing to describe
    end
    return self:GetSelectedItem()
end

function GPI:RenderInfoPopup()
    -- While the Y item menu (or its Equip To submenu) is up, the details card is
    -- suppressed; a background refresh must not pop it back over the menu.
    if self.menuDetailsSnapshot then return end
    local item = self:GetInfoPopupItem()
    if not self.infoPopup then return end
    if not item then self:HideInfoPopup() return end

    local mode = self.infoPopupMode or "details"

    -- Middle column: right edge just left of the grid, but full SCREEN height (like the
    -- native Currencies panel) so the currency-sized font fits without clipping. The
    -- horizontal position tracks the grid; the vertical span is tied to GuiRoot.
    if self.grid then
        -- Anchor the panel to GuiRoot for a FIXED on-screen column (top-margin to
        -- bottom-margin) so its top can never be pushed off-screen, regardless of the
        -- grid's position. The horizontal position tracks the grid: the panel's right
        -- edge is 24px left of the grid's on-screen left edge.
        -- Align with the controller schema exactly like the compare cards do:
        -- top edge at the native bar top, bottom edge just above the keybind strip.
        local screenH = GuiRoot:GetHeight()
        local topMargin, bottomMargin = 70, 12
        do
            local q1 = self.GetNativeBarRects and select(1, self:GetNativeBarRects())
            if q1 and q1.top then topMargin = q1.top end
            local ksc = _G["ZO_KeybindStripControl"]
            if ksc and ksc.GetTop then
                local okS, t = pcall(function() return ksc:GetTop() end)
                if okS and type(t) == "number" and t > screenH * 0.5 and t < screenH then
                    bottomMargin = screenH - (t - 35)
                end
            end
            if bottomMargin == 12 then bottomMargin = (self.sv and self.sv.cmpBottomGap) or 96 end
        end
        local screenW = GuiRoot:GetWidth()
        local gridLeft = (self.grid.GetLeft and self.grid:GetLeft()) or 0
        -- If the grid has not been laid out yet (GetLeft ~ 0), fall back to a position
        -- just left of where a right-pinned grid would sit.
        if not gridLeft or gridLeft < 100 then
            local gw = (self.cellSize + self.cellGap) * self.cols - self.cellGap
            gridLeft = screenW - gw - 8
        end
        local rightX = gridLeft - 24                    -- panel right edge, screen X
        self.infoPopup:ClearAnchors()
        self.infoPopup:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, rightX, topMargin)
        self.infoPopup:SetAnchor(BOTTOMRIGHT, GuiRoot, TOPLEFT, rightX, GuiRoot:GetHeight() - bottomMargin)
    end
    local baseA = (self.sv and self.sv.simpleOpacity) or 0.85
    self.infoPopup:SetCenterColor(ESO.panelR, ESO.panelG, ESO.panelB, baseA)

    -- Frost: darken/soften the panel interior per the frost setting. A true blur-behind
    -- is a scene feature not available to addon controls, so this uses a dark underlay
    -- (and a light Gaussian blur on that layer where supported) to approximate it.
    local frost = (self.sv and self.sv.simpleFrost) or 0.35
    if self.infoPopupFrost then
        self.infoPopupFrost:SetCenterColor(0.02, 0.025, 0.04, frost)
        if self.infoPopupFrost.SetGaussianBlur then
            local k = math.max(0, math.floor(frost * 8))
            pcall(function() self.infoPopupFrost:SetGaussianBlur(k, frost) end)
        end
    end

    local tip = self.infoPopupText and nil -- (no-op placeholder for clarity)
    local ntip = self.infoPopupTooltip

    if mode == "details" then
        SetLabelText(self.infoPopupTitle, "Item Details")
        -- Show the native tooltip, hide the stat text.
        if self.infoPopupText then self.infoPopupText:SetHidden(true) end
        if ntip then
            local ok = pcall(function()
                ntip:ClearLines()
                ntip:SetBagItem(item.bagId, item.slotIndex)
            end)
            if ok then
                ntip:ClearAnchors()
                local panelH = (self.infoPopup.GetHeight and self.infoPopup:GetHeight()) or 900
                local availH = panelH - 84 - 126
                local h = (ntip.GetHeight and ntip:GetHeight()) or 0
                local scale = 1.0
                if h > 0 and h > availH then scale = math.max(0.7, availH / h) end
                ntip:SetScale(scale)
                ntip:SetAnchor(TOPLEFT, self.infoPopup, TOPLEFT, 28, 84)
                ntip:SetHidden(false)
            else
                ntip:SetHidden(true)
            end
        end
    else -- "stats"
        SetLabelText(self.infoPopupTitle, "Stat Comparison")
        if ntip then ntip:SetHidden(true); pcall(function() ntip:ClearLines() end) end
        if self.infoPopupText and self.BuildItemInfoText then
            SetLabelText(self.infoPopupText, self:BuildItemInfoText(item))
            self.infoPopupText:SetHidden(false)
        end
    end

    self.infoPopup:SetHidden(false)
end

function GPI:ShowInfoPopup(mode)
    -- The panel normally lives at DT_MEDIUM (above the native bars, below the strip).
    -- The bank pane is window-tier (DT_HIGH), so while banking the card is promoted
    -- to DT_HIGH -- its level 40 beats the pane's level 0 and the cells' 0-4 -- and
    -- demoted back afterwards. Internal levels are untouched, preserving its layout.
    if self.infoPopup and self.infoPopup.SetDrawTier and DT_HIGH and DT_MEDIUM then
        local tier = self.bankMode and DT_HIGH or DT_MEDIUM
        self.infoPopup:SetDrawTier(tier)
        if self.infoPopupTooltip and self.infoPopupTooltip.SetDrawTier then
            self.infoPopupTooltip:SetDrawTier(tier)
        end
    end
    local item = self:GetInfoPopupItem()
    if not self.infoPopup or not item then self:HideInfoPopup() return end
    self.infoPopupOpen = true
    self.infoPopupMode = mode or self.infoPopupMode or "details"
    self:RenderInfoPopup()
end

-- Simple view: the Item Details panel is always visible for the selected item
-- (GridList-style), so LT just flips between Details and Stat Comparison.
-- Full view keeps the original three-state cycle: closed -> Details -> Stats -> closed.
function GPI:ToggleInfoPopup()
    if self.simpleView then
        if self.bankMode then
            -- Three-state cycle at the bank: off -> details -> stats -> off. The bank
            -- pane shrinks to the first card area while the card borrows the second.
            if not self.infoPopupOpen then
                self:ShowInfoPopup("details")
            elseif self.infoPopupMode ~= "stats" then
                self:ShowInfoPopup("stats")
            else
                self:HideInfoPopup()
            end
            self:Render()
            return
        end
        local nextMode = (self.infoPopupMode == "stats") and "details" or "stats"
        self:ShowInfoPopup(nextMode)
        return
    end
    if not self.infoPopupOpen then
        self.infoPopupMode = "details"
        self:ShowInfoPopup("details")
    elseif self.infoPopupMode == "details" then
        self.infoPopupMode = "stats"
        self:RenderInfoPopup()
    else
        self:HideInfoPopup()
    end
end

function GPI:HideCompare()
    local wasOpen = self.compareOpen
    self.compareOpen = false
    if self.compareFrame then self.compareFrame:SetHidden(true) end
    if self.compareDeltaBG then self.compareDeltaBG:SetHidden(true) end
    if self.compareDeltaHead then self.compareDeltaHead:SetHidden(true) end
    if self.compareDeltaText then self.compareDeltaText:SetHidden(true) end
    if self.compareTips then
        for i = 1, 3 do
            local ctip = self.compareTips[i]
            if ctip then pcall(function() ctip:ClearLines() end); ctip:SetHidden(true) end
        end
    end
    -- Restore the first native bar if the ESO-style compare hid it.
    if self.quadrant1Hidden then
        self.quadrant1Hidden = nil
        local q1c = _G["ZO_SharedGamepadNavQuadrant_1_Background"]
        if q1c and q1c.SetHidden then pcall(function() q1c:SetHidden(false) end) end
    end
    -- Native Currencies restore is deferred to Hide (see there); restoring while
    -- Grid Pad is open re-shows the native quadrant tooltip background bars.
    if wasOpen and self:IsShowing() then self:Render() end -- restore the details panel
end

-- Draw the "if equipped" swing panel inside the selected compare card. Two columns
-- of stat rows when the list is long, one when it is short, so a five-stat swing does
-- not need a tall panel.
function GPI:RenderCompareDeltaPanel(x, y, w, h, lines, gained, lost, slotName, headH, pad, rowH)
    if not self.compareDeltaBG or not self.compareDeltaText or not lines then return end

    self.compareDeltaBG:ClearAnchors()
    self.compareDeltaBG:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x + 8, y)
    self.compareDeltaBG:SetDimensions(w - 16, h)
    self.compareDeltaBG:SetHidden(false)

    local tally = {}
    if gained and gained > 0 then table.insert(tally, "|c4FE07A" .. gained .. " up|r") end
    if lost and lost > 0 then table.insert(tally, "|cE0705A" .. lost .. " down|r") end
    local headText = "IF EQUIPPED"
    if slotName then headText = headText .. ": " .. tostring(slotName) end
    if #tally > 0 then headText = headText .. "   |cAEB4BE(" .. table.concat(tally, "|r|cAEB4BE, ") .. ")|r" end

    self.compareDeltaHead:ClearAnchors()
    self.compareDeltaHead:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x + 8, y + math.floor(pad / 2))
    self.compareDeltaHead:SetDimensions(w - 16, headH)
    self.compareDeltaHead:SetText(headText)
    self.compareDeltaHead:SetHidden(false)

    -- Only as many rows as the reserved height can actually show; the remainder is
    -- reported as a count rather than silently clipped.
    local bodyH = h - headH - pad
    local maxRows = math.max(1, math.floor(bodyH / rowH))
    local shown = math.min(#lines, maxRows)
    local body = {}
    for i = 1, shown do table.insert(body, lines[i]) end
    if #lines > shown then
        body[shown] = "|cAEB4BE... and " .. tostring(#lines - shown + 1) .. " more (LT for the full list)|r"
    end

    self.compareDeltaText:ClearAnchors()
    self.compareDeltaText:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x + 22, y + headH + math.floor(pad / 2))
    self.compareDeltaText:SetDimensions(w - 44, bodyH)
    self.compareDeltaText:SetText(table.concat(body, "\n"))
    self.compareDeltaText:SetHidden(false)
end

function GPI:ShowCompare(silent)
    local item = self:GetSelectedItem()
    if not self.compareFrame or not self.compareTips then
        if not silent then self:Verdict(true, "Compare UI is unavailable in this client.") end
        return
    end
    if not item or not item.isEquippable or item.isEquipped then
        if silent then self:HideCompare() else
            self:Verdict(true, item and item.isEquipped and "That item is already equipped." or "Compare works on unequipped gear -- select a weapon, armor, or jewelry piece.")
        end
        return
    end

    -- The ambient details panel and the simple-view paperdoll yield the screen
    -- while compare is open; Render restores both as soon as compare closes.
    if self.infoPopupOpen then self:HideInfoPopup() end
    if self.simpleView and self.charPanel then self.charPanel:SetHidden(true) end

    -- The game itself knows which worn slot(s) this item compares against
    -- (handles rings, two-handers, and backup-bar weapons correctly).
    local slot1, slot2
    if GetItemComparisonEquipSlots then
        slot1, slot2 = SafeCall(GetItemComparisonEquipSlots, item.bagId, item.slotIndex)
    end
    -- The game returns -1 (EQUIP_SLOT_NONE) for "no second slot"; treat any negative
    -- slot as absent so armor shows exactly two cards and rings/weapons show three.
    if slot1 ~= nil and slot1 < 0 then slot1 = nil end
    if slot2 ~= nil and slot2 < 0 then slot2 = nil end
    if slot1 == nil and slot2 == nil then
        slot1 = SafeCall(self.GetTargetEquipSlotForItem, self, item)
        if slot1 ~= nil and slot1 < 0 then slot1 = nil end
    end
    -- v1.45: for a two-hander the game also returns the OFF hand, because equipping
    -- it bumps whatever is there. That card is only useful when something actually
    -- sits in the off hand; an empty one read as "the staff goes in your off hand".
    local function keepCard(es)
        if es == nil then return false end
        if DoesEquipSlotUseItem(es, item) then return true end
        return self:DoesWornSlotHaveItem(es)
    end
    if not keepCard(slot1) then slot1 = nil end
    if not keepCard(slot2) then slot2 = nil end
    if slot1 == nil and slot2 ~= nil then slot1, slot2 = slot2, nil end

    local cards = {}
    if slot1 ~= nil then table.insert(cards, { kind = "worn", equipSlot = slot1, displaced = not DoesEquipSlotUseItem(slot1, item) }) end
    if slot2 ~= nil and slot2 ~= slot1 then table.insert(cards, { kind = "worn", equipSlot = slot2, displaced = not DoesEquipSlotUseItem(slot2, item) }) end
    table.insert(cards, { kind = "selected" })

    -- ONE pipeline, two skins. "ESO Style" hides the big frame + title and spreads the
    -- SAME three tooltip cards (which carry ESO's native tooltip backdrop) across the
    -- screen columns set by /gpi cmp. Default keeps the framed centered window.
    local esoStyle = (self.sv and self.sv.esoStyleCompare == true)
    local sv = self.sv or {}
    local screenW, screenH = GuiRoot:GetWidth(), GuiRoot:GetHeight()

    -- UNIFORM CARDS: every card is the same framed box (same W x H); the tooltip
    -- content is scaled and centered inside. Vertically, the boxes are centered on the
    -- inventory grid so the compare reads as level with the inventory UI.
    local boxXs, boxW, boxY, boxH
    self.compareFrame:ClearAnchors()
    if esoStyle then
        -- Invisible full-screen holder; the uniform boxes are the visible cards.
        self.compareFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        self.compareFrame:SetDimensions(screenW, screenH)
        self.compareFrame:SetCenterColor(0, 0, 0, 0)
        if self.compareFrame.SetEdgeColor then self.compareFrame:SetEdgeColor(0, 0, 0, 0) end
        self.compareTitle:SetHidden(true)

        -- Columns from the game's own bars (fallback: /gpi cmp values).
        local q1, q2 = self:GetNativeBarRects()
        local barTop
        if q1 and q2 then
            local stride = q2.left - q1.left
            local inset = 12 -- slimmer inset = wider cards = wider text = less height
            boxW = q2.width - 2 * inset
            boxXs = { q1.left + inset, q2.left + inset, q2.left + stride + inset }
            barTop = q1.top
            local q1c = _G["ZO_SharedGamepadNavQuadrant_1_Background"]
            if q1c and q1c.SetHidden and not self.quadrant1Hidden then
                if pcall(function() q1c:SetHidden(true) end) then self.quadrant1Hidden = true end
            end
        else
            boxW = sv.cmpColW or 540
            local gap = sv.cmpColGap or 8
            local x1 = sv.cmpColX or 60
            boxXs = { x1, x1 + boxW + gap, x1 + 2 * (boxW + gap) }
        end

        -- Vertical: the cards always run from the native bar top down to the controller
        -- schema, regardless of where the inventory grid sits. The schema's own control
        -- (ZO_KeybindStripControl) is measured live; the text is centered within the
        -- card, so nothing depends on the grid position anymore.
        local stripTop
        do
            local ksc = _G["ZO_KeybindStripControl"]
            if ksc and ksc.GetTop then
                local okS, t = pcall(function() return ksc:GetTop() end)
                if okS and type(t) == "number" and t > screenH * 0.5 and t < screenH then stripTop = t end
            end
        end
        local bottomLimit = (stripTop and (stripTop - 35)) or (screenH - (sv.cmpBottomGap or 96))
        boxY = barTop or sv.cmpTopY or 72
        boxH = math.floor(bottomLimit - boxY)

        -- Hide the Currencies text behind the cards while open (restored on close).
        if GAMEPAD_TOOLTIPS and GAMEPAD_LEFT_TOOLTIP then
            if pcall(function() GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP) end) then
                self.currenciesCleared = true
            end
        end

        self.compareHint:ClearAnchors()
        self.compareHint:SetAnchor(BOTTOM, self.compareFrame, BOTTOM, 0, -(screenH - bottomLimit) - 12)
    else
        -- Centered framed window; the uniform boxes sit inside it.
        local frameH = math.max(640, math.min(1000, screenH - 240))
        local GAP, PAD = 36, 36
        local CARD_W = (self.tipWidth or 416) + 2 * (self.tipPad or 26) + 14
        local frameW = #cards * CARD_W + (#cards - 1) * GAP + PAD * 2
        self.compareFrame:SetAnchor(CENTER, self.window, CENTER, 0, 16)
        self.compareFrame:SetDimensions(frameW, frameH)
        self.compareFrame:SetCenterColor(0.020, 0.024, 0.034, 1.0)
        if self.compareFrame.SetEdgeColor then self.compareFrame:SetEdgeColor(0.35, 0.75, 0.95, 1) end
        self.compareTitle:SetHidden(false)
        SetLabelText(self.compareTitle, "COMPARE: " .. tostring(item.name or "selected item"))
        boxW = CARD_W - 14
        boxXs = {}
        for i = 1, 3 do boxXs[i] = PAD + (i - 1) * (CARD_W + GAP) end
        boxY = 60
        boxH = frameH - 60 - 44
        self.compareHint:ClearAnchors()
        self.compareHint:SetAnchor(BOTTOM, self.compareFrame, BOTTOM, 0, -10)
    end
    self.compareFrame:SetAlpha(1)

    -- Widen the tooltip text column to the card's usable width: wider text wraps to
    -- fewer lines, so tall items need less vertical space. The fit scale is still
    -- capped by the card width, so content can never bleed over the sides.
    self.compareTipW = math.max(360, boxW - 28)
    for i = 1, 3 do
        local ct = self.compareTips[i]
        if ct and ct.SetDimensionConstraints then
            pcall(function() ct:SetDimensionConstraints(self.compareTipW, 0, self.compareTipW, 0) end)
        end
    end

    -- Content band inside each uniform box: header strip on top, tooltip centered in
    -- the remainder. Identical for every card.
    local headInsetY = 18
    local tipBandY = boxY + 62
    local tipBandH = boxH - 62 - 44

    -- Measure the "if equipped" swing up front: the selected card gives up the bottom
    -- of its tooltip band to it, so the panel never overlaps the tooltip text.
    local deltaLines, deltaGained, deltaLost, deltaSlotName = self:BuildStatDeltaLines(item, { showResult = false })
    local hasDeltas = deltaLines ~= nil
    local deltaRows = hasDeltas and #deltaLines or 0
    local DELTA_ROW_H, DELTA_HEAD_H, DELTA_PAD = 26, 28, 14
    local deltaH = 0
    if hasDeltas then
        -- Cap the panel at 40% of the card so a heavily-affixed piece cannot squeeze
        -- the tooltip out; overflow rows are summarised instead of dropped.
        local wanted = DELTA_HEAD_H + math.max(1, deltaRows) * DELTA_ROW_H + DELTA_PAD * 2
        deltaH = math.min(wanted, math.floor(boxH * 0.40))
    end

    -- Singleton panel: hide it before the pass so moving the selection onto an item
    -- with no stat change does not leave the previous item's swing on screen.
    if self.compareDeltaBG then self.compareDeltaBG:SetHidden(true) end
    if self.compareDeltaHead then self.compareDeltaHead:SetHidden(true) end
    if self.compareDeltaText then self.compareDeltaText:SetHidden(true) end

    for i = 1, 3 do
        local ctip, head, emptyLbl = self.compareTips[i], self.compareHeads[i], self.compareEmpties[i]
        local cbg = self.compareCardBGs and self.compareCardBGs[i] or nil
        local card = cards[i]
        if ctip then ctip:SetHidden(true) end
        if cbg then cbg:SetHidden(true) end
        head:SetHidden(true)
        emptyLbl:SetHidden(true)

        if card then
            local x = boxXs[i]

            -- The uniform card box: same W x H for every card, always.
            if cbg then
                cbg:ClearAnchors()
                cbg:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x, boxY)
                cbg:SetDimensions(boxW, boxH)
                cbg:SetHidden(false)
            end

            -- Header centered in the box's top strip.
            head:ClearAnchors()
            head:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x + math.max(0, math.floor((boxW - 430) / 2)), boxY + headInsetY)
            if head.SetHorizontalAlignment then head:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
            head:SetHidden(false)

            if card.kind == "selected" then
                head:SetText("SELECTED")
                head:SetColor(0.35, 0.85, 1.00, 1)
                local selTipH = tipBandH - deltaH
                if selTipH < 120 then selTipH = tipBandH deltaH = 0 end -- never starve the tooltip
                if self:PopulateCompareTip(ctip, item.bagId, item.slotIndex, x, tipBandY, selTipH, boxW, true) then
                    ctip:SetHidden(false)
                end
                if hasDeltas and deltaH > 0 then
                    self:RenderCompareDeltaPanel(x, tipBandY + selTipH, boxW, deltaH,
                        deltaLines, deltaGained, deltaLost, deltaSlotName, DELTA_HEAD_H, DELTA_PAD, DELTA_ROW_H)
                end
            else
                local slotName = self:GetEquipSlotName(card.equipSlot) or "slot"
                head:SetText((card.displaced and "ALSO REPLACES: " or "EQUIPPED: ") .. slotName)
                head:SetColor(1.00, 0.86, 0.45, 1)
                if self:DoesWornSlotHaveItem(card.equipSlot) and self:PopulateCompareTip(ctip, BAG_WORN, card.equipSlot, x, tipBandY, tipBandH, boxW, true) then
                    ctip:SetHidden(false)
                else
                    emptyLbl:ClearAnchors()
                    emptyLbl:SetAnchor(TOPLEFT, self.compareFrame, TOPLEFT, x + math.max(0, math.floor((boxW - 430) / 2)), boxY + math.floor(boxH / 2) - 30)
                    emptyLbl:SetText("(Nothing equipped in " .. slotName .. ")")
                    emptyLbl:SetHidden(false)
                end
            end
        end
    end

    self.compareOpen = true
    self.compareFrame:SetHidden(false)

    -- Tooltips re-flow one frame after SetBagItem; refit with real heights shortly
    -- after (twice, in case the first tick lands before the reflow).
    zo_callLater(function() if self.compareOpen then self:RefitCompareTips() end end, 30)
    zo_callLater(function() if self.compareOpen then self:RefitCompareTips() end end, 130)
end

function GPI:ShowHoverTooltip(anchorControl, bagId, slotIndex)
    local tip = self.hoverTooltip
    if not tip or not anchorControl or bagId == nil or slotIndex == nil then return end

    local ok = pcall(function()
        tip:ClearLines()
        tip:SetBagItem(bagId, slotIndex)
    end)
    if not ok then tip:SetHidden(true) return end

    tip:ClearAnchors()
    local rootWidth = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or 1920
    local centerX = anchorControl.GetCenter and anchorControl:GetCenter() or 0
    if centerX > rootWidth / 2 then
        tip:SetAnchor(RIGHT, anchorControl, LEFT, -14, 0)
    else
        tip:SetAnchor(LEFT, anchorControl, RIGHT, 14, 0)
    end
    tip:SetHidden(false)
end

function GPI:HideHoverTooltip()
    if self.hoverTooltip then
        pcall(function() self.hoverTooltip:ClearLines() end)
        self.hoverTooltip:SetHidden(true)
    end
end

-- ================= LT item-info panel (v1.5.0) =================
local INFO_STAT_DEFS = {
    { var = "STAT_MAGICKA_MAX", label = "Maximum Magicka" },
    { var = "STAT_MAGICKA_REGEN_COMBAT", label = "Magicka Recovery" },
    { var = "STAT_HEALTH_MAX", label = "Maximum Health" },
    { var = "STAT_HEALTH_REGEN_COMBAT", label = "Health Recovery" },
    { var = "STAT_STAMINA_MAX", label = "Maximum Stamina" },
    { var = "STAT_STAMINA_REGEN_COMBAT", label = "Stamina Recovery" },
    { var = "STAT_SPELL_POWER", label = "Spell Damage" },
    { var = "STAT_SPELL_CRITICAL", label = "Spell Critical" },
    { var = "STAT_SPELL_PENETRATION", label = "Spell Penetration" },
    { var = "STAT_POWER", label = "Weapon Damage" },
    { var = "STAT_CRITICAL_STRIKE", label = "Weapon Critical" },
    { var = "STAT_PHYSICAL_PENETRATION", label = "Physical Penetration" },
    { var = "STAT_SPELL_RESIST", label = "Spell Resistance" },
    { var = "STAT_PHYSICAL_RESIST", label = "Physical Resistance" },
    { var = "STAT_CRITICAL_RESISTANCE", label = "Critical Resistance" },
}

function GPI:GetItemPrimaryStat(bagId, slotIndex, link)
    link = link or (GetItemLink and SafeCall(GetItemLink, bagId, slotIndex))
    if not link then return nil end
    local equipType = GetItemLinkEquipType and SafeCall(GetItemLinkEquipType, link)
    local armorTypes = {}
    for _, k in ipairs({ "EQUIP_TYPE_HEAD", "EQUIP_TYPE_CHEST", "EQUIP_TYPE_SHOULDERS", "EQUIP_TYPE_HAND", "EQUIP_TYPE_WAIST", "EQUIP_TYPE_LEGS", "EQUIP_TYPE_FEET" }) do
        local cv = ConstantValue(k)
        if cv ~= nil then armorTypes[cv] = true end
    end
    if equipType ~= nil and armorTypes[equipType] and GetItemLinkArmorRating then
        local v = SafeCall(GetItemLinkArmorRating, link, true)
        if v and v > 0 then return v, "Armor" end
    end
    if GetItemLinkWeaponPower then
        local v = SafeCall(GetItemLinkWeaponPower, link)
        if v and v > 0 then return v, "Damage" end
    end
    return nil
end

function GPI:GetItemPrimaryStatComparison(item)
    local value, statLabel = self:GetItemPrimaryStat(item.bagId, item.slotIndex, item.link)
    if not value then return nil end

    -- Find the worn slot(s) this item compares against and take the best worn stat.
    local slot1, slot2
    if GetItemComparisonEquipSlots then
        slot1, slot2 = SafeCall(GetItemComparisonEquipSlots, item.bagId, item.slotIndex)
    end
    if slot1 == nil then slot1 = SafeCall(self.GetTargetEquipSlotForItem, self, item) end

    local wornBest = nil
    for _, es in ipairs({ slot1, slot2 }) do
        if es ~= nil and self:DoesWornSlotHaveItem(es) then
            local wv = self:GetItemPrimaryStat(BAG_WORN, es)
            if wv and (not wornBest or wv > wornBest) then wornBest = wv end
        end
    end
    return value, wornBest, statLabel
end

-- ZOS's own unpacker: CompareBagItemToCurrentlyEquipped returns a flat
-- (stat, delta, stat, delta, ...) list; fold it into a [DerivedStat] = delta table.
local function StatDeltaLookupFromPacked(packed, n)
    local t = {}
    for i = 1, n - 1, 2 do
        local stat = packed[i]
        local delta = packed[i + 1]
        if stat ~= nil then t[stat] = delta end
    end
    return t
end

-- Compute the stat deltas ESO would apply if this item were equipped, using the
-- same native call that drives the character window's green/red comparison arrows.
--
-- Returns: deltaLookup, equipSlot, slotName
-- The slot matters: a ring or a backup-bar weapon has two candidate slots with
-- different worn items, so "+120 Spell Damage" is only meaningful alongside the slot
-- it applies to. GridPad reports the slot it would ACTUALLY equip into when A is
-- pressed (GetTargetEquipSlotForItem), so the projection matches the outcome.
function GPI:GetEquipStatDeltas(item)
    if not item or item.isEquipped or not item.isEquippable then return nil end
    if not CompareBagItemToCurrentlyEquipped then return nil end

    local slot1, slot2
    if GetItemComparisonEquipSlots then
        slot1, slot2 = SafeCall(GetItemComparisonEquipSlots, item.bagId, item.slotIndex)
    end
    -- EQUIP_SLOT_NONE comes back as -1; treat any negative slot as absent.
    if slot1 ~= nil and slot1 < 0 then slot1 = nil end
    if slot2 ~= nil and slot2 < 0 then slot2 = nil end

    -- Put the slot GridPad targets first so it wins ties.
    local target = SafeCall(self.GetTargetEquipSlotForItem, self, item)
    if target ~= nil and target < 0 then target = nil end
    -- v1.45: GetItemComparisonEquipSlots lists DISPLACED slots, not legal ones (a
    -- two-hander returns main hand AND off hand). CompareBagItemToCurrentlyEquipped
    -- simulates the item sitting in the slot it is given, and simulating a staff in
    -- the off hand corrupts the client's worn-gear state (crash on companion summon).
    -- Only ever simulate slots the item can legally occupy.
    local order = {}
    local function addSlot(es)
        if es == nil or es < 0 then return end
        for i = 1, #order do if order[i] == es then return end end
        if DoesEquipSlotUseItem(es, item) then table.insert(order, es) end
    end
    addSlot(target)
    addSlot(slot1)
    addSlot(slot2)
    if #order == 0 then return nil end

    local best, bestSlot, bestCount = nil, nil, 0
    for i = 1, #order do
        local es = order[i]
        local packed, n = SafeCallPacked(CompareBagItemToCurrentlyEquipped, item.bagId, item.slotIndex, es)
        local lookup = StatDeltaLookupFromPacked(packed, n + 1)
        local count = 0
        for _, v in pairs(lookup) do
            if type(v) == "number" and v ~= 0 then count = count + 1 end
        end
        -- Strictly greater, so the first entry (the real target slot) keeps priority.
        if count > bestCount then best, bestSlot, bestCount = lookup, es, count end
    end

    -- No stat actually moves (identical piece): still return the target slot's lookup
    -- so callers can say "no change" rather than "unknown".
    if best == nil then
        local packed, n = SafeCallPacked(CompareBagItemToCurrentlyEquipped, item.bagId, item.slotIndex, order[1])
        best, bestSlot = StatDeltaLookupFromPacked(packed, n + 1), order[1]
    end

    return best, bestSlot, bestSlot ~= nil and self:GetEquipSlotName(bestSlot) or nil
end

-- Format a signed number with thousands separators: 1234 -> "+1,234".
local function SignedNumber(n)
    local abs = math.abs(n)
    local pretty = (ZO_CommaDelimitNumber and SafeCall(ZO_CommaDelimitNumber, abs)) or tostring(abs)
    return (n > 0 and "+" or "-") .. tostring(pretty)
end

local DELTA_UP_COLOR = "|c4FE07A"
local DELTA_DOWN_COLOR = "|cE0705A"

-- The shared body of every "if you equip this" readout: one line per stat that
-- actually changes, showing the point swing and the resulting value.
-- Returns: linesTable, gainedCount, lostCount
function GPI:BuildStatDeltaLines(item, opts)
    opts = opts or {}
    local deltas, equipSlot, slotName = self:GetEquipStatDeltas(item)
    if not deltas then return nil, 0, 0 end

    local lines, gained, lost = {}, 0, 0
    for i = 1, #INFO_STAT_DEFS do
        local def = INFO_STAT_DEFS[i]
        local stat = ConstantValue(def.var)
        local delta = stat ~= nil and deltas[stat] or nil
        if type(delta) == "number" and delta ~= 0 then
            if delta > 0 then gained = gained + 1 else lost = lost + 1 end
            local color = delta > 0 and DELTA_UP_COLOR or DELTA_DOWN_COLOR
            local text = color .. SignedNumber(delta) .. "|r  |cBFC7D1" .. def.label .. "|r"
            if opts.showResult and GetPlayerStat then
                local current = SafeCall(GetPlayerStat, stat)
                if type(current) == "number" then
                    local after = current + delta
                    local prettyNow = (ZO_CommaDelimitNumber and SafeCall(ZO_CommaDelimitNumber, current)) or tostring(current)
                    local prettyAfter = (ZO_CommaDelimitNumber and SafeCall(ZO_CommaDelimitNumber, after)) or tostring(after)
                    text = text .. "  |cAEB4BE(" .. tostring(prettyNow) .. " -> " .. color .. tostring(prettyAfter) .. "|r|cAEB4BE)|r"
                end
            end
            table.insert(lines, text)
        end
    end

    return lines, gained, lost, slotName, equipSlot
end

function GPI:BuildItemInfoText(item)
    local lines = {}
    local link = item.link or (GetItemLink and SafeCall(GetItemLink, item.bagId, item.slotIndex))

    if not item.isEquipped then
        local val, worn, statLabel = self:GetItemPrimaryStatComparison(item)
        if val and statLabel then
            local text = statLabel .. ": " .. tostring(val)
            if worn then
                if val ~= worn then
                    local color = val > worn and DELTA_UP_COLOR or DELTA_DOWN_COLOR
                    text = statLabel .. ": " .. tostring(val) .. "  " .. color
                        .. SignedNumber(val - worn) .. " vs equipped|r"
                else
                    text = statLabel .. ": " .. tostring(val) .. "  |cAEB4BE(same as equipped)|r"
                end
            end
            table.insert(lines, text)
        end
    end

    local flags = {}
    if IsItemBound and SafeCall(IsItemBound, item.bagId, item.slotIndex) then table.insert(flags, "Bound") end
    if IsItemStolen and SafeCall(IsItemStolen, item.bagId, item.slotIndex) then table.insert(flags, "|cFF6050STOLEN|r") end
    if link and IsItemLinkCrafted and SafeCall(IsItemLinkCrafted, link) then table.insert(flags, "Crafted") end
    if item.isEquipped then table.insert(flags, "Equipped" .. (item.equippedSlotName and (": " .. item.equippedSlotName) or "")) end
    if item.isJunk then table.insert(flags, "Junk") end
    if #flags > 0 then table.insert(lines, table.concat(flags, "  ")) end

    local traitType = GetItemTrait and SafeCall(GetItemTrait, item.bagId, item.slotIndex)
    if traitType and traitType ~= 0 and GetString then
        local traitName = SafeCall(GetString, "SI_ITEMTRAITTYPE", traitType)
        local research = ""
        if GetItemTraitInformation then
            local info = SafeCall(GetItemTraitInformation, item.bagId, item.slotIndex)
            if info and info ~= 0 then
                local rname = SafeCall(GetString, "SI_ITEMTRAITINFORMATION", info)
                if rname and rname ~= "" then research = "  |c70E080(" .. rname .. ")|r" end
            end
        end
        if traitName and traitName ~= "" then table.insert(lines, "Trait: " .. traitName .. research) end
    end

    if link and GetItemLinkSetInfo then
        local hasSet, setName, _, numEquipped, maxEquipped = SafeCall(GetItemLinkSetInfo, link, true)
        if hasSet and setName and setName ~= "" then
            local counts = (numEquipped and maxEquipped) and string.format("  (%d/%d equipped)", numEquipped, maxEquipped) or ""
            table.insert(lines, "Set: " .. tostring(setName) .. counts)
        end
    end

    local cpReq = GetItemRequiredChampionPoints and SafeCall(GetItemRequiredChampionPoints, item.bagId, item.slotIndex)
    local lvlReq = GetItemRequiredLevel and SafeCall(GetItemRequiredLevel, item.bagId, item.slotIndex)
    if cpReq and cpReq > 0 then table.insert(lines, "Requires: CP " .. tostring(cpReq))
    elseif lvlReq and lvlReq > 0 then table.insert(lines, "Requires: Level " .. tostring(lvlReq)) end

    if link and GetItemLinkItemStyle and GetItemStyleName then
        local styleId = SafeCall(GetItemLinkItemStyle, link)
        if styleId and styleId ~= 0 then
            local styleName = SafeCall(GetItemStyleName, styleId)
            if styleName and styleName ~= "" then table.insert(lines, "Style: " .. tostring(styleName)) end
        end
    end

    local sell = GetItemSellValueWithBonuses and SafeCall(GetItemSellValueWithBonuses, item.bagId, item.slotIndex)
    if sell and sell > 0 then
        local stack = item.stack or 1
        table.insert(lines, "Sell: " .. tostring(sell) .. "g" .. (stack > 1 and (" each  (" .. tostring(sell * stack) .. "g stack)") or ""))
    end

    -- "If you equip this" block: the actual point swing per stat, not just an arrow.
    local deltas, deltaSlot, deltaSlotName = self:GetEquipStatDeltas(item)
    if deltas then
        local deltaLines, gained, lost = self:BuildStatDeltaLines(item, { showResult = true })
        table.insert(lines, "")
        local header = "|cFFC94DIF EQUIPPED"
        if deltaSlotName then header = header .. " (" .. tostring(deltaSlotName) .. ")" end
        header = header .. "|r"
        table.insert(lines, header)
        if deltaLines and #deltaLines > 0 then
            local tally = {}
            if gained > 0 then table.insert(tally, "|c4FE07A" .. gained .. " up|r") end
            if lost > 0 then table.insert(tally, "|cE0705A" .. lost .. " down|r") end
            if #tally > 0 then table.insert(lines, "|cAEB4BE" .. table.concat(tally, "  |r|cAEB4BE/  ") .. "|r") end
            for i = 1, #deltaLines do table.insert(lines, deltaLines[i]) end
        else
            table.insert(lines, "|cAEB4BENo net stat change vs what you have equipped.|r")
        end
    end

    table.insert(lines, "")
    local header = "|cFFC94DYOUR CHARACTER|r"
    if deltas then header = header .. "  |cAEB4BE(swing shown if equipped)|r" end
    table.insert(lines, header)
    for i = 1, #INFO_STAT_DEFS do
        local def = INFO_STAT_DEFS[i]
        local stat = ConstantValue(def.var)
        if stat ~= nil and GetPlayerStat then
            local v = SafeCall(GetPlayerStat, stat)
            if v ~= nil then
                local pretty = (ZO_CommaDelimitNumber and SafeCall(ZO_CommaDelimitNumber, v)) or tostring(v)
                local valueText = tostring(pretty)
                local delta = deltas and deltas[stat] or nil
                if type(delta) == "number" and delta > 0 then
                    valueText = tostring(pretty) .. "  " .. DELTA_UP_COLOR .. SignedNumber(delta) .. "|r"
                elseif type(delta) == "number" and delta < 0 then
                    valueText = tostring(pretty) .. "  " .. DELTA_DOWN_COLOR .. SignedNumber(delta) .. "|r"
                end
                table.insert(lines, "|cBFC7D1" .. def.label .. ":|r  " .. valueText)
            end
        end
    end

    return table.concat(lines, "\n")
end

function GPI:RenderDetails(item)
    local tip = (self.useNativeTooltip and self.itemTooltip) or nil

    -- While the compare popup is open it owns the tooltip real estate; the details
    -- tooltip would draw on the same high tier and bleed through the cards.
    if self.compareOpen then
        if self.itemTooltip then self.itemTooltip:SetHidden(true) end
        self.detailsIcon:SetHidden(true)
        self.detailsName:SetHidden(true)
        self.detailsMeta:SetHidden(true)
        self.detailsLink:SetHidden(true)
        return
    end
    local function ShowCustom(shown)
        self.detailsIcon:SetHidden(not shown)
        self.detailsName:SetHidden(not shown)
        self.detailsMeta:SetHidden(not shown)
        self.detailsLink:SetHidden(not shown)
    end

    -- Character-panel selection: show the worn item, or name the empty slot.
    if self.selZone == "doll" then
        local slotId, slotName = self:GetDollSlotInfo()
        local wornItem = (slotId ~= nil and BAG_WORN ~= nil) and GetBagItemData(BAG_WORN, slotId, "equipped", slotName) or nil
        if wornItem then
            item = wornItem
        else
            if tip then pcall(function() tip:ClearLines() end); tip:SetHidden(true) end
            ShowCustom(true)
            self.detailsIcon:SetHidden(true)
            self.detailsName:SetColor(0.78, 0.82, 0.90, 1)
            SetLabelText(self.detailsName, tostring(slotName or "Gear slot"))
            SetLabelText(self.detailsMeta, "EMPTY GEAR SLOT\n\nNothing is equipped in the " .. tostring(slotName or "selected") .. " slot.\nPress RIGHT to jump back to the grid and equip something.")
            SetLabelText(self.detailsLink, "")
            return
        end
    end

    self.detailsMeta:SetFont("ZoFontGamepad27")
    self.detailsMeta:SetHeight(190)
    self.detailsMeta:SetVerticalAlignment(TEXT_ALIGN_TOP)

    if not item then
        if tip then pcall(function() tip:ClearLines() end); tip:SetHidden(true) end
        ShowCustom(true)
        self.detailsIcon:SetHidden(true)
        SetLabelText(self.detailsName, "No matching items")
        if self:IsCraftBagMode() then
            local msg = "Nothing in this craft bag tab."
            if not self:HasCraftBagAccess() then
                msg = msg .. "\n\nESO Plus is inactive, so new materials go to your backpack instead of the craft bag. Anything already stored stays withdrawable."
            else
                msg = msg .. "\n\nCrafting materials you loot are deposited here automatically."
            end
            SetLabelText(self.detailsMeta, msg)
        else
            SetLabelText(self.detailsMeta, "No items match the current filter: " .. tostring(GetFilterLabel(self:GetCurrentFilter())))
        end
        SetLabelText(self.detailsLink, "")
        return
    end

    -- LT info mode: the tooltip yields to item metadata + your character sheet.
    if self.showItemInfo then
        if tip then pcall(function() tip:ClearLines() end); tip:SetHidden(true) end
        ShowCustom(true)
        self.detailsIcon:SetHidden(false)
        self.detailsIcon:SetTexture(item.icon)
        local r, g, b, a = GetQualityColor(item.quality)
        self.detailsName:SetColor(r, g, b, a)
        self.detailsName:SetText(item.name or "Item")
        self.detailsMeta:SetFont("ZoFontGamepad22")
        self.detailsMeta:SetHeight(650)
        SetLabelText(self.detailsMeta, self:BuildItemInfoText(item))
        SetLabelText(self.detailsLink, "")
        return
    end

    if tip then
        local ok = pcall(function()
            tip:ClearLines()
            tip:SetBagItem(item.bagId, item.slotIndex)
        end)
        if ok then
            self:AutoFitTooltip()
            tip:SetHidden(false)
            ShowCustom(false)
            -- Tooltip height can finalize a frame late; re-measure once settled.
            zo_callLater(function()
                if self:IsShowing() and self.itemTooltip and not self.itemTooltip:IsHidden() then
                    self:AutoFitTooltip()
                end
            end, 60)
            return
        end
        tip:SetHidden(true)
    end

    -- Fallback: GridPad's own compact summary (also used when /gpi tooltip is off).
    ShowCustom(true)
    self.detailsIcon:SetHidden(false)
    self.detailsIcon:SetTexture(item.icon)

    local r, g, b, a = GetQualityColor(item.quality)
    self.detailsName:SetColor(r, g, b, a)
    self.detailsName:SetText(item.name or "Item")

    local lines = { "SELECTED ITEM" }
    if item.isEquipped then
        table.insert(lines, "Status: EQUIPPED")
        if item.equippedSlotName then table.insert(lines, "Gear Slot: " .. tostring(item.equippedSlotName)) end
    elseif item.isEquippable then
        table.insert(lines, "Action: A equips this item")
    else
        table.insert(lines, "Action: A uses this item when usable")
    end
    table.insert(lines, "Bag: " .. (item.isEquipped and "Worn Gear" or "Backpack"))
    if not item.isEquipped then table.insert(lines, "Stack: " .. tostring(item.stack or 1)) end
    if item.isJunk then table.insert(lines, "Marked: JUNK") end
    if item.locked then table.insert(lines, "Locked") end
    if item.meetsUsageRequirement == false then table.insert(lines, "Cannot use yet") end
    SetLabelText(self.detailsMeta, table.concat(lines, "\n"))
    SetLabelText(self.detailsLink, item.link or item.name or "")
end

function GPI:Render()
    if not self.window then return end
    if self.zoning then return end

    local bagSize = SafeCall(GetBagSize, BAG_BACKPACK) or 0
    local shownSlots = #self.items
    local allSlots = #(self.allItems or {})
    local freeSlots = math.max(0, bagSize - (self.backpackItemCount or 0))
    local pageNumber = self.currentPage + 1
    -- Pages cover capacity, not just items, so free slots at the tail are reachable.
    local displayCount = select(1, self:GetDisplaySlotCount())
    local pageCount = math.max(1, math.ceil(math.max(shownSlots, displayCount) / self.pageSize))
    local filter = self:GetCurrentFilter()

    local filterText = string.format("LB/RB  <  %s  >", GetFilterLabel(filter))
    if not self:IsCraftBagMode() and bagSize > 0 then
        local used = SafeCall(GetNumBagUsedSlots, BAG_BACKPACK) or 0
        local free = math.max(0, bagSize - used)
        local color = free <= 5 and "|cE0705A" or (free <= 15 and "|cE0A050" or "|cAEB4BE")
        filterText = filterText .. string.format("   %s%d/%d slots|r", color, used, bagSize)
    end
    if self:IsCraftBagMode() then
        filterText = filterText .. string.format("   |cAEB4BE%d stacks|r", #self.items)
        if not self:HasCraftBagAccess() then
            filterText = filterText .. "   |cE0A050(ESO Plus inactive: withdraw only)|r"
        end
    end
    SetLabelText(self.filterInfo, filterText)

    -- The A/X keybind labels differ inside the craft bag; refresh the strip only when
    -- that state actually flips so normal renders stay cheap.
    do
        local craftBagNow = self:IsCraftBagMode()
        if self._craftBagStripState ~= craftBagNow then
            self._craftBagStripState = craftBagNow
            self:RefreshKeybindStrip()
        end
    end

    -- Free-capacity cells participate in the visual grid so the bag's true size reads
    -- directly off the page: bright frames are open slots, near-invisible cells are
    -- beyond the bag.
    self.displaySlotCount = self:GetDisplaySlotCount()

    for i = 1, self.pageSize do
        local globalIndex = self.currentPage * self.pageSize + i
        self:RenderCell(self.cells[i], self.items[globalIndex], globalIndex)
    end

    self:UpdateSelectionChrome()
    self:UpdateCharacterPanel()
    self:UpdateFilterBar()
    self:UpdateSortButtonLabel()
    self:PositionSimpleDoll()
    self:RenderBankGrid()

    do
        local selItem = self:GetSelectedItem()
        if selItem and selItem.isNew and SHARED_INVENTORY and SHARED_INVENTORY.ClearNewStatus then
            local key = tostring(selItem.bagId) .. ":" .. tostring(selItem.slotIndex)
            self.pendingNewClear = self.pendingNewClear or {}
            if not self.pendingNewClear[key] then
                self.pendingNewClear[key] = true
                local bagId, slotIndex = selItem.bagId, selItem.slotIndex
                local newKey = self:GetNewKey(selItem)
                zo_callLater(function()
                    self.pendingNewClear[key] = nil
                    if self.zoning then return end -- ZOS-side state mutation is unsafe mid-load
                    -- Keep it visible on the New tab until the player leaves the tab.
                    self.newSeenKeys = self.newSeenKeys or {}
                    self.newSeenKeys[newKey] = true
                    pcall(function() SHARED_INVENTORY:ClearNewStatus(bagId, slotIndex) end)
                    for i = 1, #(self.allItems or {}) do
                        local it = self.allItems[i]
                        if it.bagId == bagId and it.slotIndex == slotIndex then it.isNew = false end
                    end
                    if self:IsShowing() then self:Render() end
                end, 1200)
            end
        end
    end
    self:UpdateToggleChrome()
    -- Simple view auto-popup: the details panel follows the selection on its own.
    if self.simpleView and self.bagConfirmOpen then
        -- The Upgrade Bag Space confirm owns the stage: no ambient details
        -- panel underneath (or on top of) it.
        self:HideInfoPopup()
    elseif self.simpleView and not self.compareOpen and (not self.bankMode or self.infoPopupOpen) and self:GetInfoPopupItem() then
        if not self.infoPopupOpen then self.infoPopupMode = self.infoPopupMode or "details" end
        self.infoPopupOpen = true
    elseif self.simpleView and not self:GetInfoPopupItem() then
        self:HideInfoPopup()
    end
    if self.infoPopupOpen then self:RenderInfoPopup() end
    self:RenderDetails(self:GetSelectedItem())
end

-- v1.40: ALPHA-ONLY suppression, same fix as the v1.39 bank chrome change and for
-- the same reason: SetHidden on live native scene controls (inventory chrome,
-- keybind strip, ZO_GamepadTooltipTopLevel) desyncs the fragment/scene state
-- machine, and the corruption detonates as a client AppHang at a later load
-- screen. Alpha 0 is visually identical while the engine keeps believing its own
-- visibility state. nativeControlStates now stores the ORIGINAL ALPHA (number),
-- not a hidden flag. Do not reintroduce SetHidden here.
function GPI:SetNativeControlHidden(control, hidden)
    if not control or not control.SetAlpha or not control.GetAlpha then return end
    if self.nativeControlStates[control] == nil then
        self.nativeControlStates[control] = SafeCall(function() return control:GetAlpha() end) or 1
    end
    if hidden then
        SafeCall(function() control:SetAlpha(0) end)
    else
        SafeCall(function() control:SetAlpha(self.nativeControlStates[control]) end)
    end
end

-- Bank-chrome suppression keeps its OWN bookkeeping (separate from the inventory
-- chrome states) so groups can be released independently -- e.g. while a native
-- dialog (Buy Bank Space) is up, its tooltip card and quadrant background must show.
function GPI:SuppressBankControl(c)
    if not c then return end
    self.bankChromeSuppressed = self.bankChromeSuppressed or {}
    if not self.bankChromeSuppressed[c] then
        self.bankChromeSuppressed[c] = {
            alpha = (c.GetAlpha and SafeCall(function() return c:GetAlpha() end)) or 1,
        }
    end
    -- v1.39: ALPHA-ONLY suppression. SetHidden on live banking-scene roots and the
    -- gamepad tooltip toplevels desyncs the fragment/scene state machine; the
    -- corruption then detonates as a client AppHang (hard freeze, no Lua error) at
    -- the NEXT load screen -- field-confirmed Jul 2026, the same mechanism as the
    -- v1.38 forced-scene-hide fix. Alpha 0 gives the identical visual result while
    -- the engine keeps believing its own visibility state. Do not reintroduce
    -- SetHidden here. (This is the same technique SetFadedForDialog already uses,
    -- and for the same reason.)
    if c.SetAlpha then SafeCall(function() c:SetAlpha(0) end) end
end

function GPI:ReleaseBankControl(c)
    local st = self.bankChromeSuppressed and self.bankChromeSuppressed[c]
    if not st then return end
    if c.SetAlpha then SafeCall(function() c:SetAlpha(st.alpha) end) end
    self.bankChromeSuppressed[c] = nil
end

function GPI:RestoreBankChrome()
    local list = {}
    for c in pairs(self.bankChromeSuppressed or {}) do table.insert(list, c) end
    for i = 1, #list do self:ReleaseBankControl(list[i]) end
    self.bankChromeSuppressed = {}
end

-- Modal tutorial popups (e.g. the POISONS explainer on first poison equip) are
-- NOT ZO_Dialogs: the tutorial system draws its own window with its own CONTINUE
-- keybind. If GridPad fails to recognize one, its keybind prehook eats A/B and
-- the player is locked in front of a tutorial that never advances.
local TUTORIAL_MODAL_CONTROL_NAMES = {
    "ZO_UiInfoBoxTutorial",
    "ZO_UiInfoBoxTutorialGamepad",
    "ZO_UiInfoBoxTutorialDialog",
    "ZO_TutorialDialog",
    "ZO_TutorialDialogGamepad",
}
local TUTORIAL_HANDLER_CONTROL_FIELDS = { "tutorial", "dialog", "control", "dialogControl", "tutorialDialog" }

function GPI:IsNativeDialogShowing()
    if ZO_Dialogs_IsShowingDialog ~= nil
        and SafeCall(ZO_Dialogs_IsShowingDialog) == true then
        return true
    end

    -- Known tutorial window names across client builds.
    for i = 1, #TUTORIAL_MODAL_CONTROL_NAMES do
        local c = GetNamedControl(TUTORIAL_MODAL_CONTROL_NAMES[i])
        if c and c.IsHidden and SafeCall(function() return c:IsHidden() end) == false then
            return true
        end
    end

    -- Backstop: probe the tutorial manager's UI-info-box handler directly. Only
    -- the modal info-box type gates input; brief HUD toasts must not freeze the
    -- grid. Everything is pcall-guarded -- internals shift between builds.
    if TUTORIAL_SYSTEM and type(TUTORIAL_SYSTEM.tutorialHandlers) == "table"
        and TUTORIAL_TYPE_UI_INFO_BOX ~= nil then
        local handler = TUTORIAL_SYSTEM.tutorialHandlers[TUTORIAL_TYPE_UI_INFO_BOX]
        if type(handler) == "table" then
            for i = 1, #TUTORIAL_HANDLER_CONTROL_FIELDS do
                local c = handler[TUTORIAL_HANDLER_CONTROL_FIELDS[i]]
                if type(c) == "userdata" and c.IsHidden
                    and SafeCall(function() return c:IsHidden() end) == false then
                    return true
                end
            end
        end
    end

    return false
end

function GPI:InDialogQuietPeriod()
    local now = NowMs()
    if self:IsNativeDialogShowing() then
        self.bankDialogSeenAt = now
        return true
    end
    return self.bankDialogSeenAt ~= nil and now > 0
        and (now - self.bankDialogSeenAt) < 800
end

function GPI:EnforceBankChromeHidden()
    if self.zoning then return end -- native chrome is hands-off mid-load-screen
    if self.safeBankChrome then return end
    -- Near dialogs, only the FRAGILE group (backgrounds/tooltips -- the controls
    -- dialogs actually animate) goes hands-off. The banking scene ROOTS are ours
    -- to suppress unconditionally: no dialog animates them, and skipping them let
    -- the native header/list flicker back in as phantom cards.
    local quiet = self:InDialogQuietPeriod()

    -- The banking scene roots stay suppressed always.
    for i = 1, #NATIVE_BANKING_CONTROL_NAMES do
        self:SuppressBankControl(GetNamedControl(NATIVE_BANKING_CONTROL_NAMES[i]))
    end

    -- Backgrounds and tooltip containers are "fragile": the native list re-shows
    -- them via fragments (so we re-suppress every render), but native DIALOGS
    -- legitimately use them for their card -- release while a dialog is up.
    local fragile = {}
    do
        local tipHost = (GetControl and SafeCall(GetControl, "ZO_GamepadTooltipTopLevel"))
            or _G["ZO_GamepadTooltipTopLevel"]
        if tipHost and tipHost.SetHidden then
            table.insert(fragile, tipHost)
        end
    end
    local bgFragments = {
        "GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT",
        "GAMEPAD_NAV_QUADRANT_2_BACKGROUND_FRAGMENT",
        "GAMEPAD_NAV_QUADRANT_3_BACKGROUND_FRAGMENT",
        "GAMEPAD_NAV_QUADRANT_4_BACKGROUND_FRAGMENT",
        "GAMEPAD_NAV_QUADRANT_1_2_BACKGROUND_FRAGMENT",
        "GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT",
        "GAMEPAD_NAV_QUADRANT_1_2_3_BACKGROUND_FRAGMENT",
    }
    for i = 1, #bgFragments do
        local frag = _G[bgFragments[i]]
        if frag and frag.GetControl then
            local c = SafeCall(function() return frag:GetControl() end)
            if c then table.insert(fragile, c) end
        end
    end
    -- NOTE: the dialog tooltip (GAMEPAD_LEFT_DIALOG_TOOLTIP) is deliberately NOT
    -- listed -- it belongs to the dialog system, the bank list never uses it, and
    -- touching it during dialog teardown can crash the client. Likewise, no
    -- GAMEPAD_TOOLTIPS:Reset() calls here: hiding the containers is sufficient and
    -- Reset fires ZOS-side cleanup that is unsafe mid-transition.
    local tooltipTypes = {
        "GAMEPAD_LEFT_TOOLTIP", "GAMEPAD_RIGHT_TOOLTIP", "GAMEPAD_MOVABLE_TOOLTIP",
        "GAMEPAD_QUAD3_TOOLTIP", "GAMEPAD_QUAD_2_3_TOOLTIP",
    }
    if GAMEPAD_TOOLTIPS then
        for i = 1, #tooltipTypes do
            local tt = _G[tooltipTypes[i]]
            if tt ~= nil then
                local cont
                if GAMEPAD_TOOLTIPS.GetTooltipContainer then
                    cont = SafeCall(function() return GAMEPAD_TOOLTIPS:GetTooltipContainer(tt) end)
                end
                if not cont and GAMEPAD_TOOLTIPS.GetTooltip then
                    local tip = SafeCall(function() return GAMEPAD_TOOLTIPS:GetTooltip(tt) end)
                    if tip and tip.GetParent then
                        cont = SafeCall(function() return tip:GetParent() end)
                    end
                end
                if cont then table.insert(fragile, cont) end
            end
        end
    end

    -- Grace period: while a dialog is up we release the fragile group; after it
    -- closes we leave the group completely untouched for 600ms so the dialog's
    -- hide animations finish before we re-suppress (touching those controls
    -- mid-teardown crashed the client).
    for i = 1, #fragile do
        if quiet then
            self:ReleaseBankControl(fragile[i])
        else
            self:SuppressBankControl(fragile[i])
        end
    end

    -- (v1.9) The geometric sweep is retired: its catch log identified the band's
    -- real host, and it was over-matching idle-but-unhidden containers, including
    -- other addons' UI and the native dialog tooltip pane (crash-fragile).
end

function GPI:HideNativeInventoryChrome(forceAdditionalPass)
    if self.zoning then return end -- never suppress native chrome during a load screen
    if not self.hideNativeControls then return end
    if self.nativeControlsHidden and not forceAdditionalPass then return end
    if not self.nativeControlsHidden then
        self.nativeControlStates = {}
    end

    for i = 1, #NATIVE_INVENTORY_CONTROL_NAMES do
        self:SetNativeControlHidden(GetNamedControl(NATIVE_INVENTORY_CONTROL_NAMES[i]), true)
    end

    if self.bankMode then
        self:EnforceBankChromeHidden()
    end

    if not self.showKeybindStrip then
        for i = 1, #NATIVE_KEYBIND_CONTROL_NAMES do
            self:SetNativeControlHidden(GetNamedControl(NATIVE_KEYBIND_CONTROL_NAMES[i]), true)
        end
    end

    self.nativeControlsHidden = true
end

function GPI:RestoreNativeInventoryChrome()
    if not self.nativeControlsHidden then return end

    for control, origAlpha in pairs(self.nativeControlStates or {}) do
        if control and control.SetAlpha then
            SafeCall(function() control:SetAlpha(tonumber(origAlpha) or 1) end)
        end
    end

    self:RestoreBankChrome()

    self.nativeControlStates = {}
    self.nativeControlsHidden = false
end

function GPI:Show(openedFromInventoryScene)
    if self.zoning then return end
    self:CreateUI()
    -- Fresh opens always start on the All filter (never remember the last one).
    -- Internal re-shows (e.g. the bank-upgrade retake) keep the session's filter.
    if not self:IsShowing() and not self.suppressFilterReset then
        self.bagMode = "inventory"
        self.filterIndex = 1
        self.craftFilterIndex = 1
        self.currentPage = 0
        self.selectedIndex = 1
        self.bankPage, self.bankIndex = 0, 1
        self.newSeenKeys = nil
    end
    self.suppressFilterReset = nil
    self.openedFromInventoryScene = openedFromInventoryScene == true
    self.selZone = "grid"
    -- Cheap insurance: a fresh open always rescans the craft bag on first visit to
    -- that tab, in case a slot update was missed while the window was closed.
    self:InvalidateCraftBag()

    if self.modal then
        self.modal:SetHidden(not self.coverNativeInventory)
    end

    self:HideNativeInventoryChrome()
    zo_callLater(function()
        if self:IsShowing() then
            self:HideNativeInventoryChrome(true)
        end
    end, 100)

    if GAMEPAD_TOOLTIPS and GAMEPAD_RIGHT_TOOLTIP then
        SafeCall(function() GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP) end)
    end

    self.window:SetHidden(false)
    -- A previous session may have been hidden mid-dialog with capture released
    -- or the windows faded; a fresh open must hear and show everything again.
    self:SetInputCaptureEnabled(true)
    self:SetFadedForDialog(false)
    self:StartDialogWatch()

    -- Keep GridPad's keybind group active even when the visual keybind strip is hidden.
    -- Protected actions like UseItem are much more reliable when they originate from a keybind callback.
    self:AddKeybindStrip()
    if not self.showKeybindStrip then
        self:HideNativeInventoryChrome(true)
        zo_callLater(function()
            if self:IsShowing() then self:HideNativeInventoryChrome(true) end
        end, 50)
    end

    self:Refresh()
end

function GPI:Hide(fromScene)
    if not self.window then return end
    self:StopDialogWatch()
    self:SetInputCaptureEnabled(true) -- windows are hidden; leave the flags clean
    self:SetFadedForDialog(false)
    self:RestoreDetailsAfterMenu() -- clear any menu/dialog suppression snapshot
    self.window:SetHidden(true)
    self:RestoreNativeInventoryChrome()
    if self.modal then
        self.modal:SetHidden(true)
    end
    self:HideHoverTooltip()
    self:HideCompare()
    self:HideInfoPopup()
    self:HideDiffPick()
    self:HideBagConfirm()
    if self.HideCurrencyPanel then self:HideCurrencyPanel() end
    if self.dollCurrenciesCleared or self.currenciesCleared then
        self.dollCurrenciesCleared = nil
        self.currenciesCleared = nil
        if self.zoning then
            -- Native tooltip relayout mid-load-screen is crash-fragile; do it after.
            self.deferredCurrencyRestore = true
        elseif GAMEPAD_TOOLTIPS and GAMEPAD_LEFT_TOOLTIP then
            pcall(function() GAMEPAD_TOOLTIPS:LayoutCurrencies(GAMEPAD_LEFT_TOOLTIP) end)
        end
    end
    self:RemoveKeybindStrip()
    if not self.zoning and GAMEPAD_TOOLTIPS and GAMEPAD_RIGHT_TOOLTIP then
        SafeCall(function() GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP) end)
    end
    if fromScene then
        self.openedFromInventoryScene = false
    end
end

function GPI:Close()
    if self.bankMode then
        self.bankMode = nil
        self:StopBankChromeBeat()
        self:RemoveBankKeybinds()
        self:HideBankConfirm()
        if self.selZone == "bankgrid" then self.selZone = "grid" end
        if self.bankFrame then self.bankFrame:SetHidden(true) end
        self:RestoreBankChrome()
        -- Standard scene exit stays at every diag level; without it the client is
        -- left inside the banking scene and chat/Escape stop responding.
        if SCENE_MANAGER then SafeCall(function() SCENE_MANAGER:HideCurrentScene() end) end
    end
    if self.openedFromInventoryScene and SCENE_MANAGER then
        -- v1.38: HideCurrentScene alone is the correct scene exit. The former extra
        -- forced Hide("gamepad_inventory_root")/Hide("gamepad_inventory") calls
        -- corrupted the scene stack; the damage then detonated as a client-side
        -- AppHang (hard freeze, no Lua error) at the NEXT load screen when the UI
        -- was torn down against the inconsistent state. Confirmed by field testing
        -- Jul 2026: zone-change freezes stopped the moment these were removed.
        -- Do not reintroduce them.
        SafeCall(function() SCENE_MANAGER:HideCurrentScene() end)
        return
    end
    self:Hide(false)
end

function GPI:ToggleWindow()
    if not self:IsShowing() then
        self:Show(false)
    else
        self:Hide(false)
    end
end

function GPI:Move(delta)
    if not self:IsShowing() then return end
    if #self.items == 0 then return end
    self.selectedIndex = Clamp(self.selectedIndex + delta, 1, #self.items)
    self.currentPage = math.floor((self.selectedIndex - 1) / self.pageSize)
    self:Render()
end

function GPI:Page(delta)
    if not self:IsShowing() then return end
    if #self.items == 0 then return end

    local pageCount = math.max(1, math.ceil(#self.items / self.pageSize))
    self.currentPage = Clamp(self.currentPage + delta, 0, pageCount - 1)
    self.selectedIndex = Clamp(self.currentPage * self.pageSize + 1, 1, #self.items)
    self:Render()
end

function GPI:GetCurrentFilterEquipSlot()
    return GetEquipSlotFromDef(self:GetCurrentFilter())
end

function GPI:GetOrderedEquipSlots()
    local slots = {}

    if ZO_Character_EnumerateOrderedEquipSlots then
        for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots() do
            if equipSlot ~= nil then table.insert(slots, equipSlot) end
        end
    end

    if #slots == 0 then
        local equippedSlots = GetEquippedSlotInfos()
        for i = 1, #equippedSlots do
            table.insert(slots, equippedSlots[i].slotId)
        end
    end

    return slots
end

function GPI:DoesWornSlotHaveItem(equipSlot)
    if not equipSlot or not GetWornItemInfo then return false end
    local hasItem = SafeCall(GetWornItemInfo, BAG_WORN, equipSlot)
    return hasItem == true
end

function GPI:GetEquipSlotName(equipSlot)
    if equipSlot ~= nil and GetString then
        local name = SafeCall(GetString, "SI_EQUIPSLOT", equipSlot)
        if name and name ~= "" then return name end
    end
    for i = 1, #EQUIPPED_SLOT_DEFS do
        local def = EQUIPPED_SLOT_DEFS[i]
        if ConstantValue(def.var) == equipSlot then return def.name end
    end
    return tostring(equipSlot or "unknown slot")
end

function GPI:GetTargetEquipSlotForItem(item)
    if not item or not item.isEquippable then return nil end

    -- An explicit slot request wins outright when compatible: either a direct
    -- slot value (Equip To... menu) or a named constant (ring hold-to-equip).
    local forced = self.forceEquipSlotValue
    if forced == nil and self.forceEquipSlotVar then
        forced = ConstantValue(self.forceEquipSlotVar)
    end
    if forced ~= nil and DoesEquipSlotUseItem
        and SafeCall(DoesEquipSlotUseItem, forced, item) == true then
        return forced
    end

    local companionCategory = ConstantValue("GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    if companionCategory ~= nil and item.actorCategory == companionCategory then
        return nil, "companion gear cannot be equipped by the player from this modal"
    end

    local currentFilterSlot = self:GetCurrentFilterEquipSlot()
    if currentFilterSlot and DoesEquipSlotUseItem(currentFilterSlot, item) then
        return currentFilterSlot
    end

    local candidates = {}
    local orderedSlots = self:GetOrderedEquipSlots()
    for i = 1, #orderedSlots do
        local equipSlot = orderedSlots[i]
        if DoesEquipSlotUseItem(equipSlot, item) then
            table.insert(candidates, equipSlot)
        end
    end

    if #candidates == 0 then
        return nil, "no compatible worn slot was found"
    end

    -- Prefer an empty compatible slot, e.g. empty Ring 2 or empty off-hand.
    for i = 1, #candidates do
        if not self:DoesWornSlotHaveItem(candidates[i]) then
            return candidates[i]
        end
    end

    -- Otherwise replace the first compatible slot, matching ESO's category-list behavior.
    return candidates[1]
end

function GPI:CallPossiblyProtected(functionName, directFunction, ...)
    -- ESO's rule for protected functions (stated by ZOS): they can only be invoked
    -- through CallSecureProtected, and they only fail while the player is in combat
    -- lockdown. There is NO WoW-style "must originate from a hardware event" rule.
    -- Important: CallSecureProtected must be called DIRECTLY, not wrapped in pcall/
    -- SafeCall. On success it returns (true, <function returns>); on failure it
    -- returns (false, "reason") -- both are normal returns, so we surface them as-is.
    local isProtected = IsProtectedFunction and IsProtectedFunction(functionName)

    if isProtected then
        return CallSecureProtected(functionName, ...)
    end

    -- Not flagged protected: call the plain global if we have it.
    if type(directFunction) == "function" then
        directFunction(...)
        return true
    end

    -- Last resort: some clients still route it through the secure bridge.
    if CallSecureProtected then
        return CallSecureProtected(functionName, ...)
    end

    return false, tostring(functionName) .. " is unavailable in this client"
end

-- ============================== Equip engine (v0.9.3) ==============================
-- Verified facts (ZOS source tags pts11.3/pts12.0 + ESOUIDocumentation.txt):
--   * RequestEquipItem(bagId, slotIndex, wornBagId[, equipSlot]) is the current equip
--     function. It is PUBLIC (no *protected*/*private* marker): call it directly.
--     CallSecureProtected REJECTS non-protected functions, so never route it there.
--   * ZOS's own TryEquipItem: IsEquipable() -> ClearCursor() -> RequestEquipItem(3-arg).
-- Because equips have failed silently across several builds, this engine now:
--   (a) logs every step to the on-screen debug line inside the modal,
--   (b) VERIFIES ~600ms after each attempt that the item actually left the backpack
--       slot (via GetItemUniqueId), and
--   (c) automatically falls through a ladder of alternate equip calls if the game
--       ignored the previous one, reporting exactly which one worked or that all failed.

local function GetUidString(bagId, slotIndex)
    if not GetItemUniqueId then return nil end
    local ok, uid = pcall(GetItemUniqueId, bagId, slotIndex)
    if not ok or uid == nil then return nil end
    if Id64ToString then
        local ok2, str = pcall(Id64ToString, uid)
        if ok2 and str then return str end
    end
    return tostring(uid)
end

function GPI:FindWornSlotName(wornBag, uidStr)
    if not uidStr or wornBag == nil then return nil end
    local slotInfos = GetEquippedSlotInfos()
    for i = 1, #slotInfos do
        if GetUidString(wornBag, slotInfos[i].slotId) == uidStr then
            return slotInfos[i].name
        end
    end
    return nil
end

function GPI:RunEquipStrategies(item, wornBag, uidStr, srcLink, strategies, index)
    local strat = strategies[index]
    if not strat then
        self.equipInFlight = false
        self:Verdict(true, "Could not equip " .. tostring(item.name or "item") .. " -- the game ignored every method (/gpi log for the trace).")
        return
    end

    self:LogEquip("Attempt " .. index .. "/" .. #strategies .. ": " .. strat.label)
    local calledOk, detail = strat.call()
    if not calledOk then
        self:LogEquip("  -> could not call: " .. tostring(detail))
        return self:RunEquipStrategies(item, wornBag, uidStr, srcLink, strategies, index + 1)
    end

    local function ItemStillInSourceSlot()
        if uidStr then
            return GetUidString(item.bagId, item.slotIndex) == uidStr
        end
        if srcLink and GetItemLink then
            local ok, nowLink = pcall(GetItemLink, item.bagId, item.slotIndex)
            return ok and nowLink == srcLink and nowLink ~= nil and nowLink ~= ""
        end
        return false -- no way to verify; assume it worked
    end

    local function Verify()
        if ItemStillInSourceSlot() then
            self:LogEquip("  -> the game ignored this call (item is still in the backpack).")
            self:RunEquipStrategies(item, wornBag, uidStr, srcLink, strategies, index + 1)
        else
            self.equipInFlight = false
            local wornName = self:FindWornSlotName(wornBag, uidStr)
            self:Verdict(false, "Equipped " .. tostring(item.name or "item") .. (wornName and (" -> " .. wornName) or "") .. ".")
            self:HideCompare()
            self:Refresh()
        end
    end

    zo_callLater(Verify, 600)
end

function GPI:RequestEquipSelectedItem(item, source)
    if not item then return false end
    local name = tostring(item.name or "selected item")

    if self.equipInFlight then
        if NowMs() - (self.equipStartedAt or 0) > 4000 then
            self.equipInFlight = false -- previous attempt never resolved; unwedge
        else
            self:LogEquip("An equip attempt is already in progress; wait a moment.")
            return false
        end
    end

    -- Sanity: equip type must be valid (same idea as ZOS's CanEquipItem).
    if not item.isEquippable then
        self:Verdict(true, "Cannot equip " .. name .. ": not equippable gear.")
        return false
    end

    -- Actor category / worn bag routing (companion gear only inside the companion menu).
    local playerCategory = ConstantValue("GAMEPLAY_ACTOR_CATEGORY_PLAYER")
    local companionCategory = ConstantValue("GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    local wornBag = BAG_WORN
    if companionCategory ~= nil and item.actorCategory == companionCategory then
        if GetInteractionType and ConstantValue("INTERACTION_COMPANION_MENU") ~= nil and SafeCall(GetInteractionType) == ConstantValue("INTERACTION_COMPANION_MENU") and BAG_COMPANION_WORN ~= nil then
            wornBag = BAG_COMPANION_WORN
            self:LogEquip("Companion gear detected; using the companion worn bag.")
        else
            self:Verdict(true, "Companion gear can only be equipped in the companion menu.")
            return false
        end
    end

    -- ZOS-style pre-check with the game's own reason on failure.
    if IsEquipable then
        local ok, equipSucceeds, possibleError = pcall(IsEquipable, item.bagId, item.slotIndex)
        if not ok then
            self:LogEquip("IsEquipable errored (" .. tostring(equipSucceeds) .. "); continuing anyway.")
        elseif not equipSucceeds then
            local reason = possibleError
            if type(possibleError) == "number" and GetString then
                local localized = SafeCall(GetString, possibleError)
                if localized and localized ~= "" then reason = localized end
            end
            self:Verdict(true, "Cannot equip " .. name .. ": " .. tostring(reason or "the game says it is not equipable") .. ".")
            return false
        else
            self:LogEquip("IsEquipable: yes")
        end
    else
        self:LogEquip("IsEquipable API missing; continuing.")
    end

    local bindsOnEquip = ZO_InventorySlot_WillItemBecomeBoundOnEquip and SafeCall(ZO_InventorySlot_WillItemBecomeBoundOnEquip, item.bagId, item.slotIndex)
    if bindsOnEquip then
        self:LogEquip("Note: this item binds on equip. Equipping without the native confirm dialog (it can render invisibly under this modal).")
    end

    -- Snapshot identity for post-call verification.
    local uidStr = GetUidString(item.bagId, item.slotIndex)
    local srcLink = nil
    if GetItemLink then
        local ok, link = pcall(GetItemLink, item.bagId, item.slotIndex)
        if ok then srcLink = link end
    end

    -- Optional explicit worn slot (never let resolution errors kill the equip).
    local resolvedSlot = nil
    do
        local ok, slotOrErr = pcall(self.GetTargetEquipSlotForItem, self, item)
        if ok then
            resolvedSlot = slotOrErr
        else
            self:LogEquip("(slot resolution errored: " .. tostring(slotOrErr) .. "; using game default)")
        end
    end
    -- Final gate: never hand the game a slot this item can't legally occupy.
    if resolvedSlot ~= nil and not DoesEquipSlotUseItem(resolvedSlot, item) then
        self:LogEquip("Ignoring illegal target slot " .. tostring(self:GetEquipSlotName(resolvedSlot)) .. "; letting the game pick.")
        resolvedSlot = nil
    end

    ClearCursor()

    -- Build the strategy ladder. The 3-arg "game picks slot" call never errors, so
    -- whichever RequestEquipItem strategy sits first is the one that decides the
    -- slot. Normally that should be the game's pick -- but when a slot was FORCED
    -- (ring hold-to-equip), the explicit-slot call must go first or the force is
    -- dead code. Game-pick stays behind it as the fallback.
    local strategies = {}
    if type(RequestEquipItem) == "function" then
        local gamePicks = {
            label = "RequestEquipItem (game picks slot)",
            call = function()
                local ok, err = pcall(RequestEquipItem, item.bagId, item.slotIndex, wornBag)
                if not ok then return false, err end
                return true
            end,
        }
        local explicit = nil
        if resolvedSlot ~= nil then
            explicit = {
                label = "RequestEquipItem -> " .. tostring(self:GetEquipSlotName(resolvedSlot)),
                call = function()
                    local ok, err = pcall(RequestEquipItem, item.bagId, item.slotIndex, wornBag, resolvedSlot)
                    if not ok then return false, err end
                    return true
                end,
            }
        end
        if explicit and (self.forceEquipSlotVar or self.forceEquipSlotValue) then
            table.insert(strategies, explicit)
            table.insert(strategies, gamePicks)
        else
            table.insert(strategies, gamePicks)
            if explicit then table.insert(strategies, explicit) end
        end
    else
        self:LogEquip("RequestEquipItem is MISSING from this client (unexpected).")
    end
    if type(EquipItem) == "function" then
        table.insert(strategies, {
            label = "EquipItem (legacy direct)",
            call = function()
                local ok, err = pcall(EquipItem, item.bagId, item.slotIndex, resolvedSlot)
                if not ok then return false, err end
                return true
            end,
        })
    elseif IsProtectedFunction and CallSecureProtected and SafeCall(IsProtectedFunction, "EquipItem") then
        table.insert(strategies, {
            label = "EquipItem (legacy, secure bridge)",
            call = function()
                local ok, cspOk, cspErr = pcall(CallSecureProtected, "EquipItem", item.bagId, item.slotIndex)
                if not ok then return false, cspOk end
                if cspOk == false then return false, tostring(cspErr) end
                return true
            end,
        })
    end
    -- v1.45: the old last-resort "RequestMoveItem straight into a worn slot" strategy
    -- is gone. It bypassed every equip rule the game enforces in RequestEquipItem, so
    -- a wrong target slot (see DoesEquipSlotUseItem) could physically drop a weapon
    -- into a slot it does not belong in.

    if #strategies == 0 then
        self:LogEquip("No equip API exists in this client at all; cannot equip.")
        self:Alert(true, "No equip API available")
        return false
    end

    self.equipInFlight = true
    self.equipStartedAt = NowMs()
    self:RunEquipStrategies(item, wornBag, uidStr, srcLink, strategies, 1)
    return true
end

function GPI:UseSelected(source)
    -- A press that could mean something different when HELD (Ring 2 for rings, quickslot
    -- assignment for consumables) opens a hold session instead of acting immediately.
    -- A quick release still falls through to the normal use/equip via HandleKeyUp.
    if source ~= "ringtap" and source ~= "ringhold" and source ~= "quickslothold"
        and (self:RingHoldEligible() or self:QuickslotHoldEligible()) then
        if not self.ringHold then
            self:BeginRingHold() -- first arrival of this press opens the session
        end
        return -- duplicates of the same press (other ingress paths) are swallowed
    end
    -- Fresh log per press so the on-screen debug line shows exactly what this press did.
    self.equipLog = {}
    self:UpdateDebugLabel()

    local item = self:GetSelectedItem()
    if not item then
        self:LogEquip("A/use fired (" .. tostring(source) .. ") but nothing is selected.")
        return
    end

    self:LogEquip("A/use fired (" .. tostring(source) .. "): " .. tostring(item.name or "?")
        .. " [equippable=" .. tostring(item.isEquippable)
        .. " equipType=" .. tostring(item.equipType)
        .. " bag=" .. tostring(item.bagId) .. "/" .. tostring(item.slotIndex) .. "]")

    if item.isCraftBag then
        self:LogEquip("Craft bag material: routing to withdraw.")
        self:WithdrawFromCraftBag(item)
        return
    end

    if item.isQuest then
        self:Verdict(true, "Quest items are view-only in GridPad right now.")
        return
    end

    if item.isEquipped then
        self:Verdict(false, "Already equipped" .. (item.equippedSlotName and (" in " .. item.equippedSlotName) or "") .. ".")
        return
    end

    local actionText = item.isEquippable and "equip" or "use"
    if item.meetsUsageRequirement == false then
        self:Verdict(true, "Cannot use this item yet (level/CP requirement).")
        return
    end

    if IsUnitInCombat and SafeCall(IsUnitInCombat, "player") then
        self:Verdict(true, "Cannot " .. actionText .. " during combat.")
        return
    end

    if item.isEquippable and item.bagId == BAG_BACKPACK then
        self:LogEquip("Routing to equip engine.")
        self:RequestEquipSelectedItem(item, source)
        return
    end

    -- Non-equipment: ZOS reclassified UseItem as PRIVATE (docs still say protected),
    -- so no addon call can use an item directly anymore. The one sanctioned door is
    -- InitiateConfirmUseInventoryItem (still protected): it starts the game's own
    -- confirm-use flow, and the accept press runs in ZOS's secure context where
    -- UseItem is legal -- the same trusted-trampoline pattern as Buy Bank Space.
    self:LogEquip("Treating as USABLE item (not gear).")

    do -- Friendly gate: don't send unusable items into the engine flow.
        local ok, usable, onlyFromActionSlot = pcall(IsItemUsable, item.bagId, item.slotIndex)
        if ok and usable == false then
            self:Verdict(true, "That item cannot be used right now.")
            return
        elseif ok and onlyFromActionSlot == true then
            self:Verdict(true, "That item can only be used from a quickslot.")
            return
        end
    end
    ClearCursor()

    local worked, errorText
    if IsProtectedFunction("UseItem") then
        -- Future-proofing: if ZOS ever restores UseItem to protected, use it directly
        -- through the bridge (no confirmation step). Never direct-call it.
        self:LogEquip("UseItem is protected here: secure bridge, immediate use.")
        worked, errorText = self:CallPossiblyProtected("UseItem", nil, item.bagId, item.slotIndex)
        if worked ~= false and source ~= "silent" then
            self:Verdict(false, "Used " .. tostring(item.name or "selected item") .. ".")
        end
    else
        self:LogEquip("UseItem is private: initiating the native confirm-use flow.")
        worked, errorText = self:CallPossiblyProtected("InitiateConfirmUseInventoryItem", nil, item.bagId, item.slotIndex)
    end
    if worked == false then
        self:Verdict(true, "Could not " .. actionText .. ": " .. tostring(errorText or "the game refused the request"))
        return
    end

    self:ScheduleRefresh()
    zo_callLater(function() self:Refresh() end, 250)
    zo_callLater(function() self:Refresh() end, 900)
end

function GPI:ToggleJunkSelected()
    local item = self:GetSelectedItem()
    if not item then return end

    if item.bagId ~= BAG_BACKPACK then
        AddChatMessage("Only backpack items can be marked as junk.")
        return
    end

    if IsItemJunk and SetItemIsJunk then
        local previousIndex = self.selectedIndex or 1
        local isJunk = SafeCall(IsItemJunk, item.bagId, item.slotIndex) or false
        local worked, errorText = self:CallPossiblyProtected("SetItemIsJunk", SetItemIsJunk, item.bagId, item.slotIndex, not isJunk)
        if worked == false then
            AddChatMessage("Could not toggle junk: " .. tostring(errorText or "protected call failed"))
            return
        end

        -- Live junk behavior: refresh immediately. Junked items disappear from the current
        -- non-Junk filter and become visible under the Junk filter without closing the modal.
        self.selectedIndex = previousIndex
        self:Refresh()
        if #self.items > 0 then
            self.selectedIndex = Clamp(previousIndex, 1, #self.items)
            self.currentPage = math.floor((self.selectedIndex - 1) / self.pageSize)
            self:Render()
        end
        zo_callLater(function() self:Refresh() end, 150)
    else
        AddChatMessage("Junk toggling is not available in this UI state.")
    end
end

-- ================= Character-panel selector (v1.4.0) =================
-- charSlots creation order: 1-7 left armor column (Head..Feet), 8-11 right column
-- (Neck, Ring1, Ring2, Costume), 12-14 weapons (Main/Off/Poison), 15-17 backup bar.
-- "gridN" targets exit to backpack-grid row N (0-based).
local DOLL_NAV = {
    [1]  = { up = 1,  down = 2,  left = 1,  right = 8 },
    [2]  = { up = 1,  down = 3,  left = 2,  right = 9 },
    [3]  = { up = 2,  down = 4,  left = 3,  right = 10 },
    [4]  = { up = 3,  down = 5,  left = 4,  right = 11 },
    [5]  = { up = 4,  down = 6,  left = 5,  right = 11 },
    [6]  = { up = 5,  down = 7,  left = 6,  right = 11 },
    [7]  = { up = 6,  down = 12, left = 7,  right = 11 },
    [8]  = { up = 8,  down = 9,  left = 1,  right = "grid0" },
    [9]  = { up = 8,  down = 10, left = 2,  right = "grid1" },
    [10] = { up = 9,  down = 11, left = 3,  right = "grid2" },
    [11] = { up = 10, down = 13, left = 4,  right = "grid3" },
    [12] = { up = 7,  down = 15, left = 7,  right = 13 },
    [13] = { up = 11, down = 16, left = 12, right = 14 },
    [14] = { up = 11, down = 17, left = 13, right = "grid4" },
    [15] = { up = 12, down = 15, left = 15, right = 16 },
    [16] = { up = 13, down = 16, left = 15, right = 17 },
    [17] = { up = 14, down = 17, left = 16, right = "grid5" },
}

function GPI:GetGridRow()
    local pageIndex = self.selectedIndex - (self.currentPage * self.pageSize)
    return math.max(0, math.floor((pageIndex - 1) / self.cols))
end

function GPI:IsGridLeftEdge()
    if #self.items == 0 then return true end
    local pageIndex = self.selectedIndex - (self.currentPage * self.pageSize)
    return ((pageIndex - 1) % self.cols) == 0
end

function GPI:GetDollSlotInfo()
    local slot = self.charSlots and self.charSlots[self.dollIndex or 0]
    if not slot then return nil, nil end
    local slotId = ConstantValue(slot.equipSlotVar)
    return slotId, self:GetEquipSlotName(slotId)
end

function GPI:IsGridBottomRow()
    local shown = math.min(#self.items - self.currentPage * self.pageSize, self.pageSize)
    if shown <= 0 then return true end
    local maxRow = math.floor((shown - 1) / self.cols)
    return self:GetGridRow() >= maxRow
end

function GPI:BottomMinIndex()
    -- The Upgrade Bag button is the leftmost strip stop -- but only while it's
    -- actually shown (upgrades remaining). Maxed bag: the strip starts at Bag Type.
    if self:BagUpgradeRemaining() then return BOTTOM_BUTTON_UPGRADE end
    return BOTTOM_BUTTON_BAGTYPE
end

function GPI:EnterBottomZone(preferredIndex)
    self.selZone = "bottombar"
    local want = preferredIndex or self.bottomIndex or BOTTOM_BUTTON_SORT
    self.bottomIndex = Clamp(want, self:BottomMinIndex(), BOTTOM_BUTTON_COUNT)
    self:HideHoverTooltip()
    self:Render()
end

function GPI:ExitBottomZone()
    self.selZone = "grid"
    self:Render()
end

function GPI:EnterToggleZone()
    self.selZone = "toggle"
    self:HideHoverTooltip()
    self:Render()
end

function GPI:ExitToggleZone()
    self.selZone = "grid"
    self:Render()
end

function GPI:EnterDollZone(gridRow)
    if not self.charSlots or #self.charSlots == 0 then return end
    if self.sv and self.sv.hideCharacterPanel then return end
    local rowMap = { [0] = 8, [1] = 9, [2] = 10, [3] = 11, [4] = 14, [5] = 17 }
    self.selZone = "doll"
    self.dollOnDiff = nil
    self.dollOnBag = nil
    self.dollIndex = math.min(rowMap[gridRow] or 8, #self.charSlots)
    self:HideHoverTooltip()
    self:HideCompare()
    self:Render()
end

function GPI:ExitDollZone(gridRow)
    self.selZone = "grid"
    self.dollOnDiff = nil
    self.dollOnBag = nil
    if #self.items > 0 then
        local target = self.currentPage * self.pageSize + gridRow * self.cols + 1
        self.selectedIndex = Clamp(target, 1, #self.items)
    end
    self:Render()
end

-- Challenge (overland) difficulty: the Adventurer/Seasoned/Master/Vestige system
-- from the native character sheet. API names taken from the live client source:
-- GetOverlandDifficulty, RequestChangePlayerOverlandDifficulty, the
-- OVERLAND_DIFFICULTY_TYPE iteration range, and localized names via GetString.
function GPI:GetChallengeDifficultyName()
    if GetOverlandDifficulty and GetString then
        local cur = SafeCall(GetOverlandDifficulty)
        if cur ~= nil then
            local name = SafeCall(GetString, "SI_OVERLANDDIFFICULTYTYPE", cur)
            if name and name ~= "" then return name end
            return tostring(cur)
        end
    end
    if IsUnitUsingVeteranDifficulty then -- older-client fallback
        local vet = SafeCall(IsUnitUsingVeteranDifficulty, "player")
        return vet and "Veteran" or "Normal"
    end
    return nil
end

-- Difficulty pick list (v1.11): A on the Challenge Difficulty box opens a small
-- popup listing every overland difficulty; UP/DOWN moves, A confirms (requests
-- the change), B cancels. LEFT/RIGHT quick-cycling on the box still works.
-- NOTE: the overland-difficulty API family is newer than the public API doc dumps
-- (names validated against the live esoui source). The guards below are deliberate
-- version tolerance, not existence-check boilerplate: older clients fall back to
-- the veteran toggle.
function GPI:GetDifficultyOptions()
    if not (GetOverlandDifficulty and OVERLAND_DIFFICULTY_TYPE_ITERATION_BEGIN ~= nil
        and OVERLAND_DIFFICULTY_TYPE_ITERATION_END ~= nil) then
        return nil
    end
    local opts = {}
    for t = OVERLAND_DIFFICULTY_TYPE_ITERATION_BEGIN, OVERLAND_DIFFICULTY_TYPE_ITERATION_END do
        local name = SafeCall(GetString, "SI_OVERLANDDIFFICULTYTYPE", t)
        table.insert(opts, { value = t, name = (name and name ~= "" and name) or tostring(t) })
    end
    return (#opts > 0) and opts or nil
end

function GPI:DifficultyChangeBlockedReason()
    if GetOverlandDifficultyDisabledReason and OVERLAND_DIFFICULTY_DISABLED_REASON_NONE ~= nil then
        local reason = SafeCall(GetOverlandDifficultyDisabledReason)
        if reason ~= nil and reason ~= OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then
            local msg = SafeCall(GetString, "SI_OVERLANDDIFFICULTYDISABLEDREASON", reason)
            return (msg and msg ~= "") and msg or "Challenge difficulty can't be changed right now."
        end
    end
    return nil
end

-- RequestChangePlayerOverlandDifficulty is a server round-trip: the new value is
-- NOT readable immediately after the call. Re-read shortly after (and once more
-- for slow trips) so the paperdoll label reflects the actual result.
function GPI:ScheduleDifficultyRefresh()
    for _, delay in ipairs({ 250, 1000 }) do
        zo_callLater(function()
            if self:IsShowing() then self:UpdateCharacterPanel() end
        end, delay)
    end
end

function GPI:OpenDiffPick()
    local blocked = self:DifficultyChangeBlockedReason()
    if blocked then
        self:Verdict(true, blocked)
        return
    end
    local opts = self:GetDifficultyOptions()
    if not opts then
        self:CycleChallengeDifficulty(1) -- older clients: keep the simple toggle
        return
    end
    self.diffPickOptions = opts
    local cur = SafeCall(GetOverlandDifficulty)
    self.diffPickIndex = 1
    for i, o in ipairs(opts) do
        if o.value == cur then self.diffPickIndex = i end
    end

    if not self.diffPick then
        self.diffPick = self:CreateFramedBackdrop("GridPadInventoryDiffPick", self.window, "window")
        self.diffPick:SetDrawTier(DT_HIGH)
        self.diffPickRows = {}
    end
    local rowH, pad, w = 40, 12, 300
    -- Reset any native-menu styling left over from the item actions list; the
    -- modal control is shared.
    self.diffPick:SetCenterColor(ESO.bgR, ESO.bgG, ESO.bgB, ESO.bgA)
    self.diffPick:SetEdgeColor(ESO.edgeR, ESO.edgeG, ESO.edgeB, ESO.edgeA)
    if self.diffPickTitle then self.diffPickTitle:SetHidden(true) end
    if self.diffPickDivider then self.diffPickDivider:SetHidden(true) end
    self.diffPick:ClearAnchors()
    local anchorTo = self.charDiffBG or self.charDiffText or self.charPanel or self.window
    self.diffPick:SetAnchor(BOTTOMLEFT, anchorTo, TOPLEFT, -8, -8)
    self.diffPick:SetDimensions(w, pad * 2 + rowH * #opts)
    for i = 1, math.max(#opts, #self.diffPickRows) do
        local row = self.diffPickRows[i]
        if not row and i <= #opts then
            row = self:CreateLabel("GridPadInventoryDiffPickRow" .. i, self.diffPick,
                "ZoFontGamepad27", 0.77, 0.76, 0.62, 1)
            self.diffPickRows[i] = row
        end
        if row then
            if i <= #opts then
                row:ClearAnchors()
                row:SetAnchor(TOPLEFT, self.diffPick, TOPLEFT, 16, pad + (i - 1) * rowH)
                row:SetDimensions(w - 32, rowH - 6)
            end
            row:SetHidden(i > #opts)
        end
    end
    self.diffPickKind = "difficulty"
    self.diffPickOpen = true
    self.diffPick:SetHidden(false)
    self:RenderDiffPick()
end

-- Shared entry point: build the same modal for any list of {name=, value=} options.
-- Callers set self.diffPickKind first so ConfirmDiffPick knows where to dispatch.
-- Item-action kinds ("itemactions"/"equipto") render in the native gamepad look:
-- near-black surface, item-name header over a divider, selected row large + white.
function GPI:OpenPickList(opts, title)
    if not opts or #opts == 0 then return end
    self.diffPickOptions = opts
    self.diffPickIndex = 1

    if not self.diffPick then
        self.diffPick = self:CreateFramedBackdrop("GridPadInventoryDiffPick", self.window, "window")
        self.diffPick:SetDrawTier(DT_HIGH)
        self.diffPickRows = {}
    end
    local nativeStyle = (self.diffPickKind == "itemactions" or self.diffPickKind == "equipto")
    local rowH, pad, w = 40, 12, nativeStyle and 470 or 340

    -- Header (created lazily, shown only when a title is passed).
    if not self.diffPickTitle then
        self.diffPickTitle = self:CreateLabel("GridPadInventoryDiffPickTitle", self.diffPick,
            "ZoFontGamepadBold34", 1, 1, 1, 1)
        self.diffPickDivider = self:CreateBackdrop("GridPadInventoryDiffPickDivider", self.diffPick,
            0.55, 0.51, 0.40, 0.9, 0, 0, 0, 0)
        self.diffPickDivider:SetHeight(2)
    end
    local headerH = 0
    if title and title ~= "" then
        headerH = 58
        self.diffPickTitle:ClearAnchors()
        self.diffPickTitle:SetAnchor(TOPLEFT, self.diffPick, TOPLEFT, 16, 14)
        self.diffPickTitle:SetDimensions(w - 32, 38)
        self.diffPickTitle:SetText(title)
        self.diffPickTitle:SetHidden(false)
        self.diffPickDivider:ClearAnchors()
        self.diffPickDivider:SetAnchor(TOPLEFT, self.diffPick, TOPLEFT, 12, 54)
        self.diffPickDivider:SetWidth(w - 24)
        self.diffPickDivider:SetHidden(false)
    else
        self.diffPickTitle:SetHidden(true)
        self.diffPickDivider:SetHidden(true)
    end

    -- Surface: item-action menus go near-black like the vanilla gamepad dialogs;
    -- everything else keeps the standard GridPad framed-window tint.
    if nativeStyle then
        self.diffPick:SetCenterColor(0.03, 0.03, 0.03, 0.94)
        self.diffPick:SetEdgeColor(0.36, 0.34, 0.27, 0.9)
    else
        self.diffPick:SetCenterColor(ESO.bgR, ESO.bgG, ESO.bgB, ESO.bgA)
        self.diffPick:SetEdgeColor(ESO.edgeR, ESO.edgeG, ESO.edgeB, ESO.edgeA)
    end

    self.diffPick:ClearAnchors()
    self.diffPick:SetAnchor(CENTER, self.window, CENTER, 0, 0)
    self.diffPick:SetDimensions(w, headerH + pad * 2 + rowH * #opts)
    for i = 1, math.max(#opts, #self.diffPickRows) do
        local row = self.diffPickRows[i]
        if not row and i <= #opts then
            row = self:CreateLabel("GridPadInventoryDiffPickRow" .. i, self.diffPick,
                "ZoFontGamepad27", 0.77, 0.76, 0.62, 1)
            self.diffPickRows[i] = row
        end
        if row then
            if i <= #opts then
                -- Re-anchor every open: the header offset varies by kind, and rows
                -- are shared with the difficulty picker which uses no header.
                row:ClearAnchors()
                row:SetAnchor(TOPLEFT, self.diffPick, TOPLEFT, 16, headerH + pad + (i - 1) * rowH)
                row:SetDimensions(w - 32, rowH - 6)
            end
            row:SetHidden(i > #opts)
        end
    end
    self.diffPickOpen = true
    self.diffPick:SetHidden(false)
    self:RenderDiffPick()
end

function GPI:RenderDiffPick()
    if not self.diffPickOpen or not self.diffPickOptions then return end
    local nativeStyle = (self.diffPickKind == "itemactions" or self.diffPickKind == "equipto")
    -- Only the difficulty list has a "current" value to mark.
    local cur = (self.diffPickKind ~= "quickslot" and not nativeStyle)
        and SafeCall(GetOverlandDifficulty) or nil
    for i, o in ipairs(self.diffPickOptions) do
        local row = self.diffPickRows[i]
        if row then
            if nativeStyle then
                -- Vanilla gamepad list emphasis: the selected entry grows and turns
                -- white; the rest sit smaller and gray. No markers, no gold.
                if i == self.diffPickIndex then
                    row:SetFont("ZoFontGamepad34")
                    row:SetColor(1, 1, 1, 1)
                else
                    row:SetFont("ZoFontGamepad27")
                    row:SetColor(0.58, 0.58, 0.58, 1)
                end
                row:SetText(o.name)
            else
                -- Rows are shared with the item-actions menu: reset font/color.
                row:SetFont("ZoFontGamepad27")
                row:SetColor(0.77, 0.76, 0.62, 1)
                local text = o.name .. (o.value == cur and "  |c8F8F6D(current)|r" or "")
                if i == self.diffPickIndex then
                    row:SetText("|cFFD700\226\150\182 " .. text .. "|r")
                else
                    row:SetText("|cC5C29E   " .. text .. "|r")
                end
            end
        end
    end
end

function GPI:HideDiffPick()
    self.diffPickOpen = nil
    self.diffPickKind = nil
    self:HideQuickslotWheel()
    if self.diffPick then self.diffPick:SetHidden(true) end
    -- If a native dialog/tutorial appeared while the menu was up (poison equip ->
    -- POISONS tutorial), keep the details cards hidden and let the dialog watcher
    -- restore them once the dialog is dismissed.
    if self.menuDetailsSnapshot and self:IsNativeDialogShowing() then
        self.menuDetailsSnapshotReason = "dialog"
    else
        self:RestoreDetailsAfterMenu()
    end
end

function GPI:ConfirmDiffPick()
    local opt = self.diffPickOptions and self.diffPickOptions[self.diffPickIndex]
    local kind = self.diffPickKind
    self:HideDiffPick()
    if kind == "quickslot" then
        self:ConfirmQuickslotPick(opt)
        return
    end
    if kind == "itemactions" then
        if opt and opt.run then
            local ok = pcall(opt.run)
            if not ok then
                self:Verdict(true, "That action couldn't run here.")
            end
            -- Equip To... reopens the modal as a submenu: refreshing under it
            -- would fight the suppressed details card, so skip until it closes.
            if not self.diffPickOpen then
                self:ScheduleRefresh()
                self:UpdateCharacterPanel()
            end
        end
        return
    end
    if kind == "equipto" then
        local item = self.equipToItem
        self.equipToItem = nil
        if opt and opt.value ~= nil and item then
            -- Force the chosen worn slot: resolution happens synchronously inside
            -- RequestEquipSelectedItem, so the override is cleared right after.
            self.forceEquipSlotValue = opt.value
            local ok = pcall(function() self:RequestEquipSelectedItem(item, "menu") end)
            self.forceEquipSlotValue = nil
            if not ok then self:Verdict(true, "Couldn't start that equip.") end
            self:ScheduleRefresh()
            self:UpdateCharacterPanel()
        end
        return
    end
    if not opt then return end
    local blocked = self:DifficultyChangeBlockedReason()
    if blocked then
        self:Verdict(true, blocked)
        return
    end
    if RequestChangePlayerOverlandDifficulty then
        pcall(function() RequestChangePlayerOverlandDifficulty(opt.value) end)
        self:Verdict(false, "Challenge difficulty: " .. opt.name .. ".")
    end
    self:UpdateCharacterPanel()
    self:ScheduleDifficultyRefresh()
end

function GPI:CycleChallengeDifficulty(delta)
    delta = delta or 1
    if GetOverlandDifficulty and RequestChangePlayerOverlandDifficulty
        and OVERLAND_DIFFICULTY_TYPE_ITERATION_BEGIN ~= nil and OVERLAND_DIFFICULTY_TYPE_ITERATION_END ~= nil then
        -- Respect the game's own lock (e.g. mid-combat or in restricted content).
        if GetOverlandDifficultyDisabledReason and OVERLAND_DIFFICULTY_DISABLED_REASON_NONE ~= nil then
            local reason = SafeCall(GetOverlandDifficultyDisabledReason)
            if reason ~= nil and reason ~= OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then
                local msg = SafeCall(GetString, "SI_OVERLANDDIFFICULTYDISABLEDREASON", reason)
                self:Verdict(true, (msg and msg ~= "") and msg or "Challenge difficulty can't be changed right now.")
                return
            end
        end
        local beginT, endT = OVERLAND_DIFFICULTY_TYPE_ITERATION_BEGIN, OVERLAND_DIFFICULTY_TYPE_ITERATION_END
        local cur = SafeCall(GetOverlandDifficulty) or beginT
        local span = endT - beginT + 1
        local nxt = beginT + ((cur - beginT + delta) % span)
        pcall(function() RequestChangePlayerOverlandDifficulty(nxt) end)
        self:UpdateCharacterPanel()
        self:ScheduleDifficultyRefresh()
        return
    end
    if SetVeteranDifficulty then -- older-client fallback
        local vet = IsUnitUsingVeteranDifficulty and SafeCall(IsUnitUsingVeteranDifficulty, "player")
        pcall(function() SetVeteranDifficulty(not vet) end)
        self:UpdateCharacterPanel()
    end
end

function GPI:MoveDoll(action)
    -- The Challenge Difficulty button is a virtual node below the paperdoll:
    -- pressing DOWN from any slot with no downward neighbor focuses it; UP returns.
    if self.dollOnBag then
        -- The bag-usage line is the LAST virtual node: UP returns to Difficulty,
        -- everything else stays put (A is handled in RunInputAction).
        if action == "UP" then
            self.dollOnBag = nil
            self.dollOnDiff = true
            self:Render()
        end
        return
    end
    if self.dollOnDiff then
        if action == "UP" then
            self.dollOnDiff = nil
            self:Render()
        elseif action == "LEFT" then
            self:CycleChallengeDifficulty(-1)
        elseif action == "RIGHT" then
            self:CycleChallengeDifficulty(1)
        elseif action == "DOWN" and self:BagUpgradeRemaining() then
            -- One stop further down: the bag-usage line / Upgrade Bag Space.
            self.dollOnDiff = nil
            self.dollOnBag = true
            self:Render()
        end
        return
    end
    local nav = DOLL_NAV[self.dollIndex or 1]
    if not nav then
        self.dollIndex = 1
        self:Render()
        return
    end
    local target
    if action == "LEFT" then target = nav.left
    elseif action == "RIGHT" then target = nav.right
    elseif action == "UP" then target = nav.up
    elseif action == "DOWN" then target = nav.down end

    if type(target) == "string" then
        local row = tonumber(target:match("^grid(%d+)$")) or 0
        self:ExitDollZone(math.min(row, self.rows - 1))
        return
    end
    -- Bottom of the doll: the nav table marks "no downward neighbor" either by
    -- omitting down or by pointing a slot at itself (weapon row: 15->15, 16->16,
    -- 17->17). Both mean the next stop is the Challenge Difficulty button.
    if action == "DOWN" and (target == nil or target == (self.dollIndex or 1)) then
        self.dollOnDiff = true
        self:Render()
        return
    end
    if type(target) == "number" then
        self.dollIndex = Clamp(target, 1, math.max(1, #(self.charSlots or {})))
        self:Render()
    end
end

function GPI:LinkSelected()
    local item = self:GetSelectedItem()
    if not item then return end

    local link = SafeCall(GetItemLink, item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
    if link and ZO_LinkHandler_InsertLink then
        ZO_LinkHandler_InsertLink(link)
    else
        AddChatMessage(item.link or item.name or "Selected item")
    end
end

-- Y opens the full native action list for the selected item: everything the vanilla
-- gamepad inventory would offer (Use/Equip, Enchant, Charge, Repair, Split Stack,
-- Destroy, Link in Chat, ...). The list is DISCOVERED, not hardcoded: a minimal
-- gamepad-style slot table (bagId/slotIndex/slotType) is run through the same
-- ZO_InventorySlot_DiscoverSlotActionsFromActionList the native UI uses, so every
-- option is context-correct (Charge only on depleted weapons, Sell only at a
-- vendor, Enchant only on enchantable gear) and each callback is the exact native
-- implementation -- confirmation dialogs and glyph/soul-gem pickers included.
function GPI:BuildItemActionOptions(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then return nil end
    if not (ZO_InventorySlotActions and ZO_InventorySlot_DiscoverSlotActionsFromActionList) then return nil end

    local slot = { bagId = bagId, slotIndex = slotIndex }
    if ZO_InventorySlot_SetType and SLOT_TYPE_GAMEPAD_INVENTORY_ITEM ~= nil then
        pcall(function() ZO_InventorySlot_SetType(slot, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM) end)
    end
    if slot.slotType == nil then
        slot.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM or SLOT_TYPE_ITEM
    end

    local slotActions
    local okNew = pcall(function()
        slotActions = ZO_InventorySlotActions:New(INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU)
    end)
    if not okNew or not slotActions then return nil end
    if slotActions.SetInventorySlot then
        pcall(function() slotActions:SetInventorySlot(slot) end)
    end

    local okDiscover = pcall(function()
        ZO_InventorySlot_DiscoverSlotActionsFromActionList(slot, slotActions)
    end)
    if not okDiscover then return nil end

    -- m_slotActions entries are { name, callback, actionType, ... } in every API
    -- version to date; GetNumSlotActions/GetRawActionName are preferred where
    -- present, with the raw table as the fallback so one renamed method can't
    -- kill the whole menu.
    local raw = slotActions.m_slotActions
    local count = 0
    if slotActions.GetNumSlotActions then
        count = SafeCall(function() return slotActions:GetNumSlotActions() end) or 0
    end
    if count == 0 and type(raw) == "table" then count = #raw end

    local opts, haveLink = {}, false
    local linkName = SI_ITEM_ACTION_LINK_TO_CHAT and SafeCall(GetString, SI_ITEM_ACTION_LINK_TO_CHAT) or nil
    for i = 1, count do
        local entry = (type(raw) == "table") and raw[i] or nil
        local name
        if slotActions.GetRawActionName then
            name = SafeCall(function() return slotActions:GetRawActionName(i) end)
        end
        if (name == nil or name == "") and entry then name = entry[1] end
        if type(name) == "number" then name = SafeCall(GetString, name) end
        local callback = entry and entry[2]
        -- Destroy's native callback (ZO_InventorySlot_InitiateDestroyItem) calls
        -- PickupInventoryItem + PlaceInWorldLeftClick, both PROTECTED functions:
        -- run raw from addon code they're blocked, pcall eats the error, and the
        -- menu option is silently dead. Mirror the native flow through
        -- CallSecureProtected (works from addon code outside combat); the native
        -- destroy confirmation dialog then appears as usual.
        local destroyName = SI_ITEM_ACTION_DESTROY and SafeCall(GetString, SI_ITEM_ACTION_DESTROY) or nil
        if destroyName and name == destroyName and CallSecureProtected then
            callback = function()
                if IsUnitInCombat and SafeCall(IsUnitInCombat, "player") == true then
                    self:Verdict(true, "Can't destroy items while in combat.")
                    return
                end
                SafeCall(SetCursorItemSoundsEnabled, false)
                local picked = CallSecureProtected("PickupInventoryItem", bagId, slotIndex)
                SafeCall(SetCursorItemSoundsEnabled, true)
                if picked then
                    -- Fires the destruction request; the native confirm dialog
                    -- takes over (input capture releases for it via DialogWatch).
                    if not CallSecureProtected("PlaceInWorldLeftClick") then
                        SafeCall(ClearCursor)
                        self:Verdict(true, "Couldn't start the destroy here.")
                    end
                else
                    SafeCall(ClearCursor)
                    self:Verdict(true, "Couldn't start the destroy here.")
                end
            end
        end
        if type(name) == "string" and name ~= "" and type(callback) == "function" then
            opts[#opts + 1] = { name = name, run = callback }
            if linkName and name == linkName then haveLink = true end
        end
    end

    -- Guarantee Link in Chat is always on the menu even if discovery skipped it
    -- (it can be filtered out in some interaction contexts).
    if not haveLink then
        opts[#opts + 1] = {
            name = "Link in Chat",
            run = function()
                local link = SafeCall(GetItemLink, bagId, slotIndex, LINK_STYLE_BRACKETS)
                if link and link ~= "" and ZO_LinkHandler_InsertLink then
                    ZO_LinkHandler_InsertLink(link)
                end
            end,
        }
    end

    if #opts == 0 then return nil end
    return opts
end

-- While an item menu is up, the details surfaces (full-view details panel and
-- the LT info card) are hidden so the menu reads like the vanilla actions
-- dialog. Their visibility is snapshotted and restored when the menu closes.
function GPI:SuppressDetailsForMenu(reason)
    if self.menuDetailsSnapshot then return end
    self.menuDetailsSnapshotReason = reason or "menu"
    local snap = {}
    local function stash(key, c)
        if c and c.IsHidden and c.SetHidden then
            snap[key] = c:IsHidden()
            c:SetHidden(true)
        end
    end
    stash("details", self.details)
    stash("infoPopup", self.infoPopup)
    stash("infoPopupTooltip", self.infoPopupTooltip)
    self.menuDetailsSnapshot = snap
end

function GPI:RestoreDetailsAfterMenu()
    local snap = self.menuDetailsSnapshot
    if not snap then return end
    self.menuDetailsSnapshot = nil
    self.menuDetailsSnapshotReason = nil
    if self.details and snap.details ~= nil then self.details:SetHidden(snap.details) end
    if self.infoPopup and snap.infoPopup ~= nil then self.infoPopup:SetHidden(snap.infoPopup) end
    if self.infoPopupTooltip and snap.infoPopupTooltip ~= nil then self.infoPopupTooltip:SetHidden(snap.infoPopupTooltip) end
    -- The ambient card in simple view follows the selection; re-render it so it
    -- reflects whatever the menu action just did (junked, equipped, destroyed).
    if self.infoPopupOpen then self:RenderInfoPopup() end
end

-- While GridPad is on screen, poll for native dialogs/tutorials. The moment one
-- appears, GridPad's overlay cards (details panel, LT info card, compare tips)
-- get out of its way; they come back when the dialog is dismissed. This is what
-- keeps a surprise tutorial (first poison equip) readable and dismissable.
function GPI:StartDialogWatch()
    if self.dialogWatchOn or not EVENT_MANAGER then return end
    self.dialogWatchOn = true
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "DialogWatch", 150, function()
        if not self:IsShowing() then return end
        if self:IsNativeDialogShowing() then
            -- Release raw input capture: the dialog's CONTINUE/confirm keybinds
            -- live on the "Dialogs" action layer, which our keyboard-enabled
            -- windows would otherwise starve (see SetInputCaptureEnabled).
            self:SetInputCaptureEnabled(false)
            -- BASIC dialogs render UNDER GridPad; get out of the way visually
            -- (see SetFadedForDialog). Bank mode keeps its designed layering.
            if not self.bankMode then self:SetFadedForDialog(true) end
            if not self.menuDetailsSnapshot then
                self:SuppressDetailsForMenu("dialog")
            end
            if self.compareOpen then self:HideCompare() end
        else
            self:SetInputCaptureEnabled(true)
            self:SetFadedForDialog(false)
            if self.menuDetailsSnapshotReason == "dialog" then
                self:RestoreDetailsAfterMenu()
            end
        end
    end)
end

function GPI:StopDialogWatch()
    if not self.dialogWatchOn then return end
    self.dialogWatchOn = false
    if EVENT_MANAGER then EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "DialogWatch") end
end

-- Quality-colored display name for the menu header, e.g. a purple item name.
function GPI:GetItemMenuTitle(bagId, slotIndex, link)
    local rawName = SafeCall(GetItemName, bagId, slotIndex)
    if not rawName or rawName == "" then return nil end
    local title = rawName
    if zo_strformat then
        local formatted = SafeCall(zo_strformat, "<<t:1>>", rawName)
        if formatted and formatted ~= "" then title = formatted end
    end
    local quality = (GetItemLinkDisplayQuality and SafeCall(GetItemLinkDisplayQuality, link))
        or (GetItemLinkQuality and SafeCall(GetItemLinkQuality, link))
    if quality and GetItemQualityColor then
        local color = SafeCall(GetItemQualityColor, quality)
        if color and color.Colorize then
            local ok, colored = pcall(function() return color:Colorize(title) end)
            if ok and colored and colored ~= "" then title = colored end
        end
    end
    return title
end

-- Every worn slot this item could legally occupy, labeled with the current
-- occupant. Returns nil unless there is a real choice (2+ compatible slots):
-- with a single compatible slot, A/Equip already goes exactly there.
function GPI:GetEquipToChoices(item)
    if not item or not item.isEquippable then return nil end
    if item.bagId ~= BAG_BACKPACK then return nil end
    local choices = {}
    local orderedSlots = self:GetOrderedEquipSlots()
    for i = 1, #orderedSlots do
        local equipSlot = orderedSlots[i]
        if DoesEquipSlotUseItem(equipSlot, item) then
            local label = self:GetEquipSlotName(equipSlot)
            if self:DoesWornSlotHaveItem(equipSlot) then
                local occupant = SafeCall(GetItemName, BAG_WORN, equipSlot)
                if occupant and occupant ~= "" and zo_strformat then
                    occupant = SafeCall(zo_strformat, "<<t:1>>", occupant) or occupant
                end
                if occupant and occupant ~= "" then
                    label = label .. "  |c8F8F6D-- " .. occupant .. "|r"
                end
            else
                label = label .. "  |c8F8F6D(empty)|r"
            end
            choices[#choices + 1] = { name = label, value = equipSlot }
        end
    end
    if #choices < 2 then return nil end
    return choices
end

function GPI:OpenEquipToMenu(item, choices)
    choices = choices or self:GetEquipToChoices(item)
    if not item or not choices then return end
    self.equipToItem = item
    self:SuppressDetailsForMenu()
    self.diffPickKind = "equipto"
    self:OpenPickList(choices, "Equip To")
end

-- Resolve whatever is currently highlighted (backpack/craft-bag grid, bank pane,
-- or a worn slot on the paperdoll) and open the actions menu for it.
function GPI:OpenItemActionsMenu()
    local bagId, slotIndex, gridItem
    if self.selZone == "doll" then
        local slotId = self:GetDollSlotInfo()
        if slotId == nil then return end
        bagId, slotIndex = BAG_WORN, slotId
    elseif self.bankMode and self.selZone == "bankgrid" then
        local item = self:GetBankSelectedItem()
        if not item then return end
        bagId, slotIndex = item.bagId, item.slotIndex
    else
        local item = self:GetSelectedItem()
        if not item then return end
        gridItem = item
        bagId, slotIndex = item.bagId, item.slotIndex
    end

    local link = SafeCall(GetItemLink, bagId, slotIndex, LINK_STYLE_DEFAULT)
    if not link or link == "" then
        self:Verdict(true, "Nothing to act on here.")
        return
    end

    local opts = self:BuildItemActionOptions(bagId, slotIndex)
    if not opts then
        -- Discovery unavailable on this client: Y falls back to its old Link
        -- behavior so the button is never dead.
        self:LinkSelected()
        return
    end

    -- Equip To...: slotted right under the primary action when the item has a
    -- real destination choice (1H weapons, rings, poisons, front/back bar).
    local equipChoices = gridItem and self:GetEquipToChoices(gridItem) or nil
    if equipChoices then
        local capturedItem = gridItem
        table.insert(opts, math.min(2, #opts + 1), {
            name = "Equip To...",
            run = function() self:OpenEquipToMenu(capturedItem, equipChoices) end,
        })
    end

    -- Assign to Quickslot: the native gamepad UI exposes assignment as a tab
    -- keybind rather than a slot action, so discovery never returns it. Surface
    -- it in the Y menu for consumables (potions, food, siege, ...); it runs the
    -- exact same in-addon wheel picker as the hold-A gesture. (See the NOTE above
    -- BeginQuickslotAssignment for why the native gamepad_quickslot scene handoff
    -- must never be used here.)
    if gridItem and self:IsQuickslottableItem(gridItem) then
        local capturedItem = gridItem
        table.insert(opts, math.min(equipChoices and 3 or 2, #opts + 1), {
            name = "Assign to Quickslot",
            run = function() self:BeginQuickslotAssignment(capturedItem) end,
        })
    end

    -- On the New tab, Y also offers a one-press "dismiss every !" option.
    if gridItem and not self:IsCraftBagMode() then
        local f = self:GetCurrentFilter()
        if f and f.key == "new" and self:CountNewItems() > 0 then
            table.insert(opts, {
                name = "Mark All New Items as Seen",
                run = function() self:DismissAllNew() end,
            })
        end
    end

    self:SuppressDetailsForMenu()
    self.diffPickKind = "itemactions"
    self:OpenPickList(opts, self:GetItemMenuTitle(bagId, slotIndex, link))
end

-- Bank mode: A transfers the selected stack across (withdraw -> backpack,
-- deposit -> bank, overflowing into the subscriber bank when needed). The move
-- API is protected, so it goes through CallSecureProtected like every banking UI.
function GPI:BankTransferSelected()
    local withdraw = self.selZone == "bankgrid"
    local item = withdraw and self:GetBankSelectedItem() or self:GetSelectedItem()
    if not item then return end
    if item.isCraftBag then
        self:Verdict(true, "Craft bag materials are already stored account-wide -- press A to withdraw instead.")
        return
    end
    local dst = withdraw and BAG_BACKPACK or BAG_BANK
    local free = FindFirstEmptySlotInBag and SafeCall(FindFirstEmptySlotInBag, dst)
    if free == nil and not withdraw and BAG_SUBSCRIBER_BANK ~= nil then
        dst = BAG_SUBSCRIBER_BANK
        free = SafeCall(FindFirstEmptySlotInBag, dst)
    end
    if free == nil then
        self:Verdict(true, withdraw and "Your backpack is full." or "Your bank is full.")
        return
    end
    local count = item.stack or 1
    if GetSlotStackSize then
        local s = SafeCall(GetSlotStackSize, item.bagId, item.slotIndex)
        if type(s) == "number" and s > 0 then count = s end
    end
    local ok = CallSecureProtected ~= nil and pcall(function()
        CallSecureProtected("RequestMoveItem", item.bagId, item.slotIndex, dst, free, count)
    end)
    if ok then
        self:Verdict(false, (withdraw and "Withdrew " or "Deposited ") .. (item.name or "item") .. ".")
    else
        self:Verdict(true, "Couldn't move the item (action blocked).")
    end
end

function GPI:GetBankSelectedItem()
    if not self.bankItems then return nil end
    local idx = (self.bankPage or 0) * (self.bankPageSize or 1) + (self.bankIndex or 1)
    return self.bankItems[idx]
end

function GPI:RefreshBankItems()
    self.bankAllItems = {}
    local bankBags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
    for b = 1, #bankBags do
        local bankBagId = bankBags[b]
        if bankBagId ~= nil then
            local size = SafeCall(GetBagSize, bankBagId) or 0
            for slotIndex = 0, size - 1 do
                local item = GetBagItemData(bankBagId, slotIndex, "bank")
                if item then table.insert(self.bankAllItems, item) end
            end
        end
    end
    self:ApplyBankFilter()
end

-- ================== Bank currency deposit / withdraw (v1.44) ==================
-- Native gamepad banking exposes Deposit/Withdraw Currency as list entries;
-- GridPad's equivalent is a currency strip across the top of the bank pane.
-- UP from the bank grid's top row focuses it, LEFT/RIGHT picks a currency, and
-- A opens a transfer panel: X flips Deposit <-> Withdraw, d-pad LEFT/RIGHT picks
-- a digit, UP/DOWN adjusts it, Y fills in the maximum, A confirms, B cancels.
-- The move runs through TransferCurrency() (plain call first, then the
-- CallSecureProtected retry, same as every other guarded API here), and success
-- is only announced once the destination balance is OBSERVED to grow.

-- Candidate list; GetBankableCurrencies filters it live against the client's own
-- CanCurrencyBeStoredInLocation so future bankable currencies appear on their own.
GPI.bankCurrencyDefs = {
    { var = "CURT_MONEY",           label = "Gold" },
    { var = "CURT_TELVAR_STONES",   label = "Tel Var" },
    { var = "CURT_ALLIANCE_POINTS", label = "Alliance Points" },
    { var = "CURT_WRIT_VOUCHERS",   label = "Writ Vouchers" },
}

function GPI:GetBankableCurrencies()
    local out = {}
    local bankLoc = ConstantValue("CURRENCY_LOCATION_BANK")
    for i = 1, #self.bankCurrencyDefs do
        local def = self.bankCurrencyDefs[i]
        local curt = ConstantValue(def.var)
        if curt ~= nil then
            local ok = true
            if CanCurrencyBeStoredInLocation and bankLoc ~= nil then
                ok = SafeCall(CanCurrencyBeStoredInLocation, curt, bankLoc) == true
            end
            if ok then table.insert(out, { curt = curt, label = def.label }) end
        end
    end
    return out
end

-- Largest amount that can move in the given direction: limited by what the source
-- holds AND by any cap on the destination (bank cap on deposit, wallet cap on
-- withdraw), so the panel's Max is always an amount the server will accept.
function GPI:CurrencyTransferMax(curt, dir)
    local charLoc = ConstantValue("CURRENCY_LOCATION_CHARACTER")
    local bankLoc = ConstantValue("CURRENCY_LOCATION_BANK")
    local carried = (charLoc ~= nil and SafeCall(GetCurrencyAmount, curt, charLoc)) or 0
    local banked  = (bankLoc ~= nil and SafeCall(GetCurrencyAmount, curt, bankLoc)) or 0
    local maxMove
    if dir == "deposit" then
        maxMove = carried
        if GetMaxPossibleCurrency and bankLoc ~= nil then
            local cap = SafeCall(GetMaxPossibleCurrency, curt, bankLoc)
            if type(cap) == "number" then maxMove = math.min(maxMove, math.max(0, cap - banked)) end
        end
    else
        maxMove = banked
        if GetMaxPossibleCurrency and charLoc ~= nil then
            local cap = SafeCall(GetMaxPossibleCurrency, curt, charLoc)
            if type(cap) == "number" then maxMove = math.min(maxMove, math.max(0, cap - carried)) end
        end
    end
    return maxMove, carried, banked
end

local function PrettyAmount(n)
    if ZO_CommaDelimitNumber then
        local ok, s = pcall(ZO_CommaDelimitNumber, n)
        if ok and s then return s end
    end
    return tostring(n)
end

-- ---- The strip: one chip per bankable currency, across the top of the pane ----
function GPI:EnsureBankCurrencyStrip()
    if self.bankCurChips or not self.bankFrame then return end
    self.bankCurChips = {}
    for i = 1, 4 do
        local chip = self:CreateBackdrop(nil, self.bankFrame, 0.04, 0.05, 0.07, 0.95, 0.30, 0.33, 0.40, 1)
        chip:SetHeight(34)
        chip:SetMouseEnabled(true)
        chip.text = self:CreateLabel(nil, chip, "ZoFontGamepad22", 0.9, 0.9, 0.9, 1)
        chip.text:SetAnchorFill(chip)
        chip.text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        chip.text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        chip:SetHandler("OnMouseUp", function(_, mb)
            if mb == MOUSE_BUTTON_INDEX_LEFT and self.bankMode then
                local list = self:GetBankableCurrencies()
                if list[i] then
                    self.selZone = "bankcurrency"
                    self.bankCurIndex = i
                    self:ShowCurrencyPanel(list[i])
                    self:Render()
                end
            end
        end)
        chip:SetHidden(true)
        self.bankCurChips[i] = chip
    end
end

function GPI:RenderBankCurrencyStrip(paneWidth)
    self:EnsureBankCurrencyStrip()
    if not self.bankCurChips then return end
    local list = self:GetBankableCurrencies()
    local n = #list
    if (self.bankCurIndex or 1) > math.max(1, n) then self.bankCurIndex = math.max(1, n) end
    local GAP = 8
    local chipW = n > 0 and math.floor((paneWidth - 28 - (n - 1) * GAP) / n) or 0
    for i = 1, #self.bankCurChips do
        local chip = self.bankCurChips[i]
        local def = list[i]
        if def and chipW > 0 then
            chip:ClearAnchors()
            chip:SetAnchor(TOPLEFT, self.bankFrame, TOPLEFT, 14 + (i - 1) * (chipW + GAP), 44)
            chip:SetWidth(chipW)
            local _, carried, banked = self:CurrencyTransferMax(def.curt, "deposit")
            chip.text:SetText(string.format("|cAEB4BE%s:|r |c4FE07A%s|r |cAEB4BE/ bank|r |c4FE07A%s|r",
                def.label, AbbrevNumber(carried), AbbrevNumber(banked)))
            if self.selZone == "bankcurrency" and i == (self.bankCurIndex or 1) then
                chip:SetCenterColor(0.10, 0.42, 0.55, 1)
                chip:SetEdgeColor(0.45, 0.95, 1.00, 1)
            else
                chip:SetCenterColor(0.04, 0.05, 0.07, 0.95)
                chip:SetEdgeColor(0.30, 0.33, 0.40, 1)
            end
            chip:SetHidden(false)
        else
            chip:SetHidden(true)
        end
    end
end

-- ---- The transfer panel: modal amount entry, same family as the confirms ----
local CUR_PANEL_DIGITS = 9 -- up to 999,999,999 per transfer; clamped to Max anyway

function GPI:EnsureCurrencyPanel()
    if self.curPanel then return end
    self.curPanel = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.curPanel:SetDimensions(640, 300)
    self.curPanel:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
    -- The bank pane is window-tier: like the compare frame and the pick list,
    -- this popup must be promoted to DT_HIGH or the pane's cell icons and stack
    -- labels draw straight through it. Fully opaque surface for the same reason.
    if self.curPanel.SetDrawTier and DT_HIGH then self.curPanel:SetDrawTier(DT_HIGH) end
    if self.curPanel.SetDrawLevel then self.curPanel:SetDrawLevel(90) end
    self.curPanel:SetCenterColor(0.05, 0.06, 0.08, 1)
    self.curPanel:SetHidden(true)

    -- Children carry their own draw order in ESO: without an explicit level the
    -- panel's text loses to the bank cells' stack labels (level 3) and selection
    -- overlays (level 4). Everything on the panel rides at 95, above the surface.
    local function Lift(c)
        if c and c.SetDrawTier and DT_HIGH then c:SetDrawTier(DT_HIGH) end
        if c and c.SetDrawLevel then c:SetDrawLevel(95) end
        return c
    end

    self.curPanelTitle = Lift(self:CreateLabel(nil, self.curPanel, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1))
    self.curPanelTitle:SetAnchor(TOP, self.curPanel, TOP, 0, 18)

    self.curPanelBalances = Lift(self:CreateLabel(nil, self.curPanel, "ZoFontGamepad22", 0.75, 0.78, 0.83, 1))
    self.curPanelBalances:SetAnchor(TOP, self.curPanel, TOP, 0, 62)
    self.curPanelBalances:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.curPanelAmount = Lift(self:CreateLabel(nil, self.curPanel, "ZoFontGamepadBold48", 0.9, 0.9, 0.9, 1))
    self.curPanelAmount:SetAnchor(TOP, self.curPanel, TOP, 0, 108)
    self.curPanelAmount:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.curPanelMaxLine = Lift(self:CreateLabel(nil, self.curPanel, "ZoFontGamepad22", 0.75, 0.78, 0.83, 1))
    self.curPanelMaxLine:SetAnchor(TOP, self.curPanel, TOP, 0, 176)
    self.curPanelMaxLine:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.curPanelHint = Lift(self:CreateLabel(nil, self.curPanel, "ZoFontGamepad22", ESO.dimR, ESO.dimG, ESO.dimB, 1))
    self.curPanelHint:SetAnchor(BOTTOM, self.curPanel, BOTTOM, 0, -16)
    self.curPanelHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.curPanelHint:SetText("D-Pad: set amount    X: direction    Y: max    A: confirm    B: cancel")
end

function GPI:ShowCurrencyPanel(def)
    if not (def and def.curt ~= nil) then return end
    self:EnsureCurrencyPanel()
    self:HideInfoPopup()
    self:HideCompare()
    self:HideHoverTooltip()
    local _, carried, banked = self:CurrencyTransferMax(def.curt, "deposit")
    self.curPanelState = {
        curt = def.curt,
        label = def.label,
        dir = (carried > 0 or banked == 0) and "deposit" or "withdraw",
        amount = 0,
        digit = CUR_PANEL_DIGITS, -- start on the ones place
    }
    self.curPanelOpen = true
    self:RenderCurrencyPanel()
    self.curPanel:SetHidden(false)
end

function GPI:HideCurrencyPanel()
    local wasOpen = self.curPanelOpen
    self.curPanelOpen = false
    self.curPanelState = nil
    if self.curPanel then self.curPanel:SetHidden(true) end
    if wasOpen and self:IsShowing() then self:Render() end
end

function GPI:RenderCurrencyPanel()
    local st = self.curPanelState
    if not (st and self.curPanel) then return end
    local maxMove, carried, banked = self:CurrencyTransferMax(st.curt, st.dir)
    if (st.amount or 0) > maxMove then st.amount = maxMove end

    self.curPanelTitle:SetText(string.format("%s %s",
        st.dir == "deposit" and "DEPOSIT" or "WITHDRAW", string.upper(st.label)))
    self.curPanelBalances:SetText(string.format("Carried: %s        Banked: %s",
        PrettyAmount(carried), PrettyAmount(banked)))

    -- Fixed-width digit readout: leading zeros dim, the active digit gold, commas
    -- between groups. UP/DOWN adjusts the highlighted place value directly.
    local raw = string.format("%0" .. CUR_PANEL_DIGITS .. "d", st.amount or 0)
    local firstSig = CUR_PANEL_DIGITS - math.max(1, tostring(st.amount or 0):len()) + 1
    local parts = {}
    for i = 1, CUR_PANEL_DIGITS do
        local ch = raw:sub(i, i)
        local color
        if i == st.digit then color = "FFD700"
        elseif i < firstSig then color = "4A4F58"
        else color = "E6E6E6" end
        table.insert(parts, "|c" .. color .. ch .. "|r")
        if i < CUR_PANEL_DIGITS and (CUR_PANEL_DIGITS - i) % 3 == 0 then
            table.insert(parts, "|c4A4F58,|r")
        end
    end
    self.curPanelAmount:SetText(table.concat(parts))

    if maxMove <= 0 then
        self.curPanelMaxLine:SetColor(0.95, 0.35, 0.30, 1)
        self.curPanelMaxLine:SetText(st.dir == "deposit"
            and "Nothing to deposit (or the bank is at its cap)."
            or "Nothing to withdraw (or your wallet is at its cap).")
    else
        self.curPanelMaxLine:SetColor(0.75, 0.78, 0.83, 1)
        self.curPanelMaxLine:SetText(string.format("Max: %s", PrettyAmount(maxMove)))
    end
end

function GPI:AdjustCurrencyPanel(action)
    local st = self.curPanelState
    if not st then return end
    if action == "LEFT" then
        st.digit = math.max(1, (st.digit or CUR_PANEL_DIGITS) - 1)
    elseif action == "RIGHT" then
        st.digit = math.min(CUR_PANEL_DIGITS, (st.digit or CUR_PANEL_DIGITS) + 1)
    elseif action == "UP" or action == "DOWN" then
        local place = 10 ^ (CUR_PANEL_DIGITS - (st.digit or CUR_PANEL_DIGITS))
        local maxMove = self:CurrencyTransferMax(st.curt, st.dir)
        local newAmount = (st.amount or 0) + (action == "UP" and place or -place)
        if newAmount < 0 then newAmount = 0 end
        if newAmount > maxMove then newAmount = maxMove end
        st.amount = newAmount
    elseif action == "SECONDARY" then
        st.dir = st.dir == "deposit" and "withdraw" or "deposit"
        st.amount = math.min(st.amount or 0, self:CurrencyTransferMax(st.curt, st.dir))
    elseif action == "TERTIARY" then
        st.amount = self:CurrencyTransferMax(st.curt, st.dir)
    end
    self:RenderCurrencyPanel()
end

function GPI:ConfirmCurrencyTransfer()
    local st = self.curPanelState
    if not st then self:HideCurrencyPanel() return end
    local maxMove = self:CurrencyTransferMax(st.curt, st.dir)
    local amount = math.min(st.amount or 0, maxMove)
    if amount <= 0 then
        self:Verdict(true, "Enter an amount above zero first (Y fills in the maximum).")
        return
    end
    if not TransferCurrency and not DepositCurrencyIntoBank and not WithdrawCurrencyFromBank then
        self:Verdict(true, "This client can't transfer currency (no currency transfer API).")
        self:HideCurrencyPanel()
        return
    end
    local charLoc = ConstantValue("CURRENCY_LOCATION_CHARACTER")
    local bankLoc = ConstantValue("CURRENCY_LOCATION_BANK")
    if charLoc == nil or bankLoc == nil then
        self:Verdict(true, "Currency locations unavailable on this client.")
        self:HideCurrencyPanel()
        return
    end
    local fromLoc = st.dir == "deposit" and charLoc or bankLoc
    local toLoc   = st.dir == "deposit" and bankLoc or charLoc
    local curt, label, dir = st.curt, st.label, st.dir
    local before = SafeCall(GetCurrencyAmount, curt, toLoc) or 0
    self:HideCurrencyPanel()

    -- Plain call first; if the client flags it protected the pcall fails
    -- instantly and we retry through CallSecureProtected (RequestMoveItem pattern).
    -- v1.45: if TransferCurrency is missing or refused, fall back to the dedicated
    -- bank calls the native banking UI has always used.
    local sent = false
    if TransferCurrency then
        sent = pcall(TransferCurrency, curt, amount, fromLoc, toLoc)
        if not sent and CallSecureProtected then
            sent = pcall(function() CallSecureProtected("TransferCurrency", curt, amount, fromLoc, toLoc) end)
        end
    end
    if not sent then
        local fnName = (dir == "deposit") and "DepositCurrencyIntoBank" or "WithdrawCurrencyFromBank"
        local fn = _G[fnName]
        if type(fn) == "function" then
            sent = pcall(fn, curt, amount)
            if not sent and CallSecureProtected then
                pcall(function() CallSecureProtected(fnName, curt, amount) end)
            end
        end
    end

    -- Only report success once the destination balance is OBSERVED to grow.
    local attempts = 0
    local function check()
        attempts = attempts + 1
        local now = SafeCall(GetCurrencyAmount, curt, toLoc) or 0
        if now > before then
            self:Verdict(false, string.format("%s %s %s.",
                dir == "deposit" and "Deposited" or "Withdrew", PrettyAmount(now - before), label))
            if self:IsShowing() then self:Render() end
        elseif attempts < 5 and zo_callLater then
            zo_callLater(check, 350)
        else
            self:Verdict(true, "The transfer didn't go through -- the game refused it.")
        end
    end
    if zo_callLater then zo_callLater(check, 300) end
end

-- The bank pane: a second grid spanning the two native bar areas on the left
-- (where the paperdoll and details card live outside of banking), so the bank's
-- contents and your backpack are visible side by side while items move between.
function GPI:EnsureBankGrid()
    if self.bankFrame then return end
    local wm = WINDOW_MANAGER or GetWindowManager()
    if not wm or not self.window then return end

    self.bankFrame = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.bankFrame:SetHidden(true)

    self.bankTitle = self:CreateLabel(nil, self.bankFrame, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.bankTitle:SetAnchor(TOPLEFT, self.bankFrame, TOPLEFT, 14, 8)
    self.bankTitle:SetAnchor(TOPRIGHT, self.bankFrame, TOPRIGHT, -14, 8)
    self.bankTitle:SetHeight(34)
    self.bankTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.bankTitle:SetText("BANK")

    self.bankFooter = self:CreateLabel(nil, self.bankFrame, "ZoFontGamepad22", 0.75, 0.78, 0.82, 1)
    self.bankFooter:SetAnchor(BOTTOMLEFT, self.bankFrame, BOTTOMLEFT, 14, -8)
    self.bankFooter:SetAnchor(BOTTOMRIGHT, self.bankFrame, BOTTOMRIGHT, -14, -8)
    self.bankFooter:SetHeight(24)
    self.bankFooter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.bankCells = {}
end

function GPI:EnsureBankCell(i)
    local cell = self.bankCells[i]
    if cell then return cell end
    local wm = WINDOW_MANAGER or GetWindowManager()
    cell = self:CreateBackdrop(nil, self.bankFrame, 0.075, 0.08, 0.09, 0.96, 0.31, 0.31, 0.31, 0.6)
    cell:SetDimensions(self.cellSize or 52, self.cellSize or 52)
    cell.icon = wm:CreateControl(nil, cell, CT_TEXTURE)
    cell.icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 5, 5)
    cell.icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -5, -5)
    cell.stack = self:CreateLabel(nil, cell, "ZoFontGamepad18", 1, 1, 1, 1)
    cell.stack:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -3, -2)
    cell.stack:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    cell.stack:SetDrawLevel(3)
    cell.selection = self:CreateBackdrop(nil, cell, 0.05, 0.85, 1.00, 0.26, 1.00, 1.00, 1.00, 1)
    cell.selection:SetAnchorFill(cell)
    cell.selection:SetDrawLevel(4)
    cell.selection:SetHidden(true)
    self.bankCells[i] = cell
    return cell
end

function GPI:RenderBankGrid()
    if not self.bankMode then
        if self.bankFrame then self.bankFrame:SetHidden(true) end
        return
    end
    self:EnsureBankGrid()
    if not self.bankFrame then return end
    if self.compareOpen then self.bankFrame:SetHidden(true) return end

    -- Span the two native bar areas, top to schema, like the other cards.
    local screenH, screenW = GuiRoot:GetHeight(), GuiRoot:GetWidth()
    local left, top, right = 76, 72, 1170
    local q1, q2 = self:GetNativeBarRects()
    local dialogUp = self:IsNativeDialogShowing()
    if dialogUp and not self.bankChromeReleased then
        self.bankChromeReleased = true
        self:RestoreBankChrome()
    elseif not dialogUp and self.bankChromeReleased and not self:InDialogQuietPeriod() then
        self.bankChromeReleased = nil
    end
    if q1 and q2 then
        -- While a native dialog (e.g. Buy Bank Space) shows its card in the first
        -- quadrant, the bank slides right to the second card area to make room,
        -- and slides back when the dialog closes (see the poll below).
        local leftRect = dialogUp and q2 or q1
        left, top = leftRect.left + 12, q1.top
        right = q2.left + q2.width - 12
    elseif dialogUp then
        left = 640
    end
    if dialogUp and zo_callLater and not self.bankDialogPoll then
        self.bankDialogPoll = true
        local function poll()
            self.bankDialogPoll = nil
            if not (self.bankMode and self:IsShowing()) then return end
            self:Render()
            local now = NowMs()
            local inGrace = self.bankDialogSeenAt and now > 0 and (now - self.bankDialogSeenAt) < 900
            if self:IsNativeDialogShowing() or inGrace then
                self.bankDialogPoll = true
                zo_callLater(poll, 350)
            end
        end
        zo_callLater(poll, 250)
    end
    local stripTop
    local ksc = _G["ZO_KeybindStripControl"]
    if ksc and ksc.GetTop then
        local okS, t = pcall(function() return ksc:GetTop() end)
        if okS and type(t) == "number" and t > screenH * 0.5 and t < screenH then stripTop = t end
    end
    local bottom = (stripTop and (stripTop - 35)) or (screenH - ((self.sv and self.sv.cmpBottomGap) or 96))
    local w, h = right - left, bottom - top

    self.bankFrame:ClearAnchors()
    self.bankFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    self.bankFrame:SetDimensions(w, h)
    self.bankFrame:SetHidden(false)

    -- Currency strip across the top of the pane (deposit/withdraw entry point).
    self:RenderBankCurrencyStrip(w)

    local CELL, GAP = self.cellSize or 52, self.cellGap or 6
    local stride = CELL + GAP
    local cols = math.max(1, math.floor((w - 28) / stride))
    -- 100 top: title (44) + currency strip (34) + gap; 36 bottom: footer.
    local rows = math.max(1, math.floor((h - 100 - 36) / stride))
    self.bankCols, self.bankRows = cols, rows
    self.bankPageSize = cols * rows

    local total = #(self.bankItems or {})
    local maxPage = math.max(0, math.ceil(total / self.bankPageSize) - 1)
    if (self.bankPage or 0) > maxPage then self.bankPage = maxPage end
    local base = (self.bankPage or 0) * self.bankPageSize
    local shown = math.min(total - base, self.bankPageSize)
    if shown < 0 then shown = 0 end
    if (self.bankIndex or 1) > math.max(1, shown) then self.bankIndex = math.max(1, shown) end

    local x0 = math.floor((w - (cols * stride - GAP)) / 2)
    for i = 1, self.bankPageSize do
        local cell = self:EnsureBankCell(i)
        local r, c = math.floor((i - 1) / cols), (i - 1) % cols
        cell:ClearAnchors()
        cell:SetAnchor(TOPLEFT, self.bankFrame, TOPLEFT, x0 + c * stride, 94 + r * stride)
        local item = self.bankItems and self.bankItems[base + i]
        if item then
            cell:SetHidden(false)
            cell.icon:SetHidden(false)
            cell.icon:SetTexture(item.icon)
            cell.stack:SetText((item.stack or 1) > 1 and tostring(item.stack) or "")
            local rq, gq, bq = GetQualityColor(item.quality)
            local q = item.quality or 1
            if q <= 0 then cell:SetEdgeColor(0.12, 0.12, 0.12, 0.6)
            elseif q == 1 then cell:SetEdgeColor(0.31, 0.31, 0.31, 0.6)
            else cell:SetEdgeColor(rq, gq, bq, 0.9) end
            cell.selection:SetHidden(not (self.selZone == "bankgrid" and i == (self.bankIndex or 1)))
        else
            cell:SetHidden(i > shown and i > self.bankPageSize and true or false)
            cell.icon:SetHidden(true)
            cell.stack:SetText("")
            cell:SetEdgeColor(0.14, 0.15, 0.17, 1)
            cell.selection:SetHidden(true)
        end
    end
    -- Hide any leftover cells from a larger previous layout.
    for i = self.bankPageSize + 1, #self.bankCells do
        self.bankCells[i]:SetHidden(true)
        self.bankCells[i].selection:SetHidden(true)
    end

    local used = #(self.bankItems or {})
    local size = self:BankTotalSlots()
    local pageNote = maxPage > 0 and string.format("  \226\128\162  page %d/%d", (self.bankPage or 0) + 1, maxPage + 1) or ""
    self.bankFooter:SetText(string.format("Bank: %d / %d%s  \226\128\162  Gold & currencies: UP from the bank's top row, then A", used, size, pageNote))

    -- The native scene's fragments re-show its chrome after one-shot hides (the
    -- item-dependent card behind the pane). Re-suppress every render, plus one
    -- deferred pass to win any same-frame ordering race with native re-layouts.
    self.dollCurrenciesCleared = true
    self:EnforceBankChromeHidden()
    if zo_callLater and not self.bankChromeDeferred then
        self.bankChromeDeferred = true
        zo_callLater(function()
            self.bankChromeDeferred = nil
            if self.bankMode and self:IsShowing() then self:EnforceBankChromeHidden() end
        end, 80)
    end
end

-- Buy Bank Space, GridPad-style: our OWN confirmation panel (no native dialog --
-- the native one's close transition crashes the client while a custom UI is up),
-- confirming straight into the public BuyBankSpace() API.
function GPI:StopBankChromeBeat()
    do
        SafeCall(function() EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "BankChromeBeat") end)
    end
end

function GPI:AddBankKeybinds()
    if not KEYBIND_STRIP or self.bankKeybindsAdded then return end
    self.bankKeybindStrip = self.bankKeybindStrip or {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        {
            name = "Buy Bank Space",
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function() self:RunInputAction("BUY_BANK_SPACE", "keybind") end,
        },
    }
    SafeCall(function() KEYBIND_STRIP:AddKeybindButtonGroup(self.bankKeybindStrip) end)
    self.bankKeybindsAdded = true
end

function GPI:RemoveBankKeybinds()
    if not KEYBIND_STRIP or not self.bankKeybindsAdded then return end
    SafeCall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(self.bankKeybindStrip) end)
    self.bankKeybindsAdded = false
end

function GPI:EnsureBankConfirm()
    if self.bankConfirm then return end
    self.bankConfirm = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.bankConfirm:SetDimensions(600, 240)
    self.bankConfirm:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
    if self.bankConfirm.SetDrawLevel then self.bankConfirm:SetDrawLevel(80) end
    self.bankConfirm:SetHidden(true)

    self.bankConfirmTitle = self:CreateLabel(nil, self.bankConfirm, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.bankConfirmTitle:SetAnchor(TOP, self.bankConfirm, TOP, 0, 20)
    self.bankConfirmTitle:SetText("BUY BANK SPACE")

    self.bankConfirmBody = self:CreateLabel(nil, self.bankConfirm, "ZoFontGamepad25", 0.9, 0.9, 0.9, 1)
    self.bankConfirmBody:SetAnchor(TOP, self.bankConfirm, TOP, 0, 74)
    self.bankConfirmBody:SetDimensions(540, 90)
    self.bankConfirmBody:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.bankConfirmHint = self:CreateLabel(nil, self.bankConfirm, "ZoFontGamepad22", ESO.dimR, ESO.dimG, ESO.dimB, 1)
    self.bankConfirmHint:SetAnchor(BOTTOM, self.bankConfirm, BOTTOM, 0, -18)
    self.bankConfirmHint:SetText("A: Buy    B: Cancel")
end

function GPI:ShowBankConfirm()
    if not IsBankUpgradeAvailable() then
        self:Verdict(true, "Your bank is already at maximum size.")
        return
    end
    self:EnsureBankConfirm()
    local price = GetNextBankUpgradePrice() or 0
    local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    self.bankConfirmPrice = price
    self.bankConfirmBody:SetText(string.format(
        "Increase your bank size by 10 slots?\n\nCost: %d gold    (you have %d)", price, gold))
    if gold < price then
        self.bankConfirmBody:SetColor(0.95, 0.35, 0.30, 1)
        self.bankConfirmHint:SetText("Not enough gold    B: Cancel")
    else
        self.bankConfirmBody:SetColor(0.9, 0.9, 0.9, 1)
        self.bankConfirmHint:SetText("A: Buy    B: Cancel")
    end
    self.bankConfirmGold = gold
    self.bankConfirm:SetHidden(false)
    self.bankConfirmOpen = true
end

function GPI:HideBankConfirm()
    self.bankConfirmOpen = false
    if self.bankConfirm then self.bankConfirm:SetHidden(true) end
end

-- BuyBankSpace() only works from ZOS's secure dialog callback (confirmed in the
-- live source: the gamepad flow is DisplayBankUpgrade() -> scene
-- "gamepad_buy_bank_space" -> dialog BUY_BANK_SPACE_GAMEPAD -> its accept button
-- calls BuyBankSpace() from secure context). So: hand the screen back to the
-- vanilla flow untouched -- GridPad fully hidden, chrome fully restored -- and
-- retake the bank when the native scene finishes. The old crash came from our
-- suppression fighting that scene's transitions; with us gone, it's just vanilla.
function GPI:BankTotalSlots()
    return (GetBagSize(BAG_BANK) or 0) + (GetBagSize(BAG_SUBSCRIBER_BANK) or 0)
end

function GPI:BeginBankUpgradeHandoff()
    if not self.bankMode or self.bankHandoff then return end
    if IsBankUpgradeAvailable and SafeCall(IsBankUpgradeAvailable) ~= true then
        self:Verdict(true, "Your bank is already at maximum size.")
        return
    end
    local price = (GetNextBankUpgradePrice and SafeCall(GetNextBankUpgradePrice)) or 0
    local gold = 0
    gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    if gold < price then
        self:Verdict(true, string.format("Not enough gold: the upgrade costs %d, you have %d.", price, gold))
        return
    end
    self.bankHandoff = true
    local sizeBefore = self:BankTotalSlots()
    self:StopBankChromeBeat()
    self:RemoveBankKeybinds()
    self:HideBankConfirm()
    self:RestoreBankChrome()
    self:Hide(true) -- GridPad fully away; the native bank UI is back, pristine
    SafeCall(DisplayBankUpgrade)

    local checks = 0
    local sawFlow = false
    local function NativeFlowActive()
        if self:IsNativeDialogShowing() then return true end
        if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
            local ok, showing = pcall(function() return SCENE_MANAGER:IsShowing("gamepad_buy_bank_space") end)
            if ok and showing then return true end
        end
        return false
    end
    local function watch()
        if not self.bankHandoff then return end -- bank closed meanwhile
        checks = checks + 1
        local active = NativeFlowActive()
        if active then sawFlow = true end
        if active and checks < 960 then
            zo_callLater(watch, 125) -- flow still up (user reading the dialog)
        elseif not active and (sawFlow or checks >= 3) then
            -- Flow finished (or never opened): settle, then retake the bank.
            zo_callLater(function()
                if not self.bankHandoff then return end
                self.bankHandoff = nil
                self.bankMode = true
                self.bankIndex, self.bankPage = 1, 0
                self.suppressFilterReset = true
                self:Show(false)
                self:AddBankKeybinds()
                do
                    SafeCall(function()
                        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "BankChromeBeat", 125, function()
                            if GPI.bankMode and GPI:IsShowing() then GPI:EnforceBankChromeHidden() end
                        end)
                    end)
                end
                self:HideNativeInventoryChrome(true)
                self:Refresh()
                local sizeNow = self:BankTotalSlots()
                if sizeNow > sizeBefore then
                    self:Verdict(false, string.format("Bank upgraded to %d slots.", sizeNow))
                end
            end, 300)
        elseif checks < 960 then
            zo_callLater(watch, 125)
        else
            self.bankHandoff = nil
        end
    end
    zo_callLater(watch, 200)
end

function GPI:ConfirmBuyBankSpace()
    local price = self.bankConfirmPrice or 0
    if (self.bankConfirmGold or 0) < price then
        self:Verdict(true, "Not enough gold for the bank upgrade.")
        return
    end
    self:HideBankConfirm()
    if not BuyBankSpace then
        self:Verdict(true, "Bank upgrade unavailable.")
        return
    end

    local sizeBefore = self:BankTotalSlots()

    -- Try the plain call; if the function is protected the pcall fails instantly,
    -- and we retry through CallSecureProtected (the RequestMoveItem pattern).
    local okDirect = pcall(BuyBankSpace)
    if not okDirect and CallSecureProtected then
        pcall(function() CallSecureProtected("BuyBankSpace") end)
    end

    -- Only report success once the bank size is OBSERVED to grow. No more
    -- claiming a purchase the game silently refused.
    local attempts = 0
    local function check()
        attempts = attempts + 1
        local sizeNow = self:BankTotalSlots()
        if sizeNow > sizeBefore then
            self:Verdict(false, string.format("Bank upgraded to %d slots (paid %d gold).", sizeNow, price))
            if self.bankMode and self:IsShowing() then self:Refresh() end
        elseif attempts < 5 and zo_callLater then
            zo_callLater(check, 400)
        else
            self:Verdict(true, "The bank upgrade didn't go through -- the game refused the purchase.")
        end
    end
    zo_callLater(check, 350)
end

-- ====================== Upgrade Bag Space (Update 49) ======================
-- Update 49 added BuyBagSpaceFromInventory(): unlike BuyBankSpace() (banker
-- interaction only -- hence the bank handoff dance above) and the old
-- BuyBagSpace() (pack merchant interaction only), the server accepts it with
-- NO NPC interaction at all. It's exactly what the native inventory's own
-- "Upgrade Bag Space" entry calls (confirmed in the live 12.0.7 source:
-- dialog BUY_BAG_SPACE_FROM_INVENTORY_GAMEPAD's accept button). So no scene
-- handoff: GridPad's own confirm panel calls the API directly, and success is
-- announced by EVENT_INVENTORY_BOUGHT_BAG_SPACE, not assumed.
function GPI:BagUpgradeRemaining()
    -- Returns the number of upgrades left, or nil when maxed / API missing.
    if not (GetCurrentBackpackUpgrade and GetMaxBackpackUpgrade) then return nil end
    local cur = SafeCall(GetCurrentBackpackUpgrade)
    local max = SafeCall(GetMaxBackpackUpgrade)
    if type(cur) ~= "number" or type(max) ~= "number" then return nil end
    if cur >= max then return nil end
    return max - cur
end

function GPI:EnsureBagConfirm()
    if self.bagConfirm then return end
    self.bagConfirm = self:CreateFramedBackdrop(nil, self.window, "panel")
    self.bagConfirm:SetDimensions(600, 260)
    self.bagConfirm:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
    if self.bagConfirm.SetDrawLevel then self.bagConfirm:SetDrawLevel(80) end
    self.bagConfirm:SetHidden(true)

    self.bagConfirmTitle = self:CreateLabel(nil, self.bagConfirm, "ZoFontGamepadBold34", ESO.goldR, ESO.goldG, ESO.goldB, 1)
    self.bagConfirmTitle:SetAnchor(TOP, self.bagConfirm, TOP, 0, 20)
    self.bagConfirmTitle:SetText("UPGRADE BAG SPACE")

    self.bagConfirmBody = self:CreateLabel(nil, self.bagConfirm, "ZoFontGamepad25", 0.9, 0.9, 0.9, 1)
    self.bagConfirmBody:SetAnchor(TOP, self.bagConfirm, TOP, 0, 74)
    self.bagConfirmBody:SetDimensions(540, 120)
    self.bagConfirmBody:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.bagConfirmHint = self:CreateLabel(nil, self.bagConfirm, "ZoFontGamepad22", ESO.dimR, ESO.dimG, ESO.dimB, 1)
    self.bagConfirmHint:SetAnchor(BOTTOM, self.bagConfirm, BOTTOM, 0, -18)
    self.bagConfirmHint:SetText("A: Buy    B: Cancel")
end

function GPI:ShowBagUpgradeConfirm()
    local remaining = self:BagUpgradeRemaining()
    if not remaining then
        self:Verdict(true, "Your bag is already at maximum size.")
        return
    end
    if not BuyBagSpaceFromInventory then
        self:Verdict(true, "This client can't buy bag upgrades from the inventory (needs Update 49+).")
        return
    end
    self:EnsureBagConfirm()
    -- The confirm gets a clear stage: the LT details panel (ambient in simple
    -- view) and the compare popup both drop while it's up, and Render() keeps
    -- the ambient panel suppressed until the confirm closes.
    self:HideInfoPopup()
    self:HideCompare()
    self:HideHoverTooltip()
    local price = (GetNextBackpackUpgradePrice and SafeCall(GetNextBackpackUpgradePrice)) or 0
    local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    local perUpgrade = (type(NUM_BACKPACK_SLOTS_PER_UPGRADE) == "number" and NUM_BACKPACK_SLOTS_PER_UPGRADE) or 10
    self.bagConfirmPrice = price
    self.bagConfirmGold = gold
    self.bagConfirmBody:SetText(string.format(
        "Increase your bag size by %d slots?\n\nCost: %d gold    (you have %d)\n%d upgrade%s remaining",
        perUpgrade, price, gold, remaining, remaining == 1 and "" or "s"))
    if gold < price then
        self.bagConfirmBody:SetColor(0.95, 0.35, 0.30, 1)
        self.bagConfirmHint:SetText("Not enough gold    B: Cancel")
    else
        self.bagConfirmBody:SetColor(0.9, 0.9, 0.9, 1)
        self.bagConfirmHint:SetText("A: Buy    B: Cancel")
    end
    self.bagConfirm:SetHidden(false)
    self.bagConfirmOpen = true
end

function GPI:HideBagConfirm()
    local wasOpen = self.bagConfirmOpen
    self.bagConfirmOpen = false
    if self.bagConfirm then self.bagConfirm:SetHidden(true) end
    -- Re-render so the ambient details panel (suppressed while the confirm was
    -- up) returns. Skipped when the whole window is hiding.
    if wasOpen and self:IsShowing() then self:Render() end
end

function GPI:ConfirmBuyBagSpace()
    local price = self.bagConfirmPrice or 0
    if (self.bagConfirmGold or 0) < price then
        self:Verdict(true, "Not enough gold for the bag upgrade.")
        return
    end
    self:HideBagConfirm()
    if not BuyBagSpaceFromInventory then
        self:Verdict(true, "Bag upgrade unavailable.")
        return
    end

    local sizeBefore = SafeCall(GetBagSize, BAG_BACKPACK) or 0

    -- Plain call first; if the client flags it protected the pcall fails
    -- instantly and we retry through CallSecureProtected (RequestMoveItem pattern).
    local okDirect = pcall(BuyBagSpaceFromInventory)
    if not okDirect and CallSecureProtected then
        pcall(function() CallSecureProtected("BuyBagSpaceFromInventory") end)
    end

    -- EVENT_INVENTORY_BOUGHT_BAG_SPACE announces success (see registration in
    -- Initialize); this poll only reports the FAILURE case, where the bag size
    -- never grew. No claiming a purchase the game silently refused.
    local attempts = 0
    local function check()
        attempts = attempts + 1
        local sizeNow = SafeCall(GetBagSize, BAG_BACKPACK) or 0
        if sizeNow > sizeBefore then
            return -- success; the event handler already announced it
        elseif attempts < 5 and zo_callLater then
            zo_callLater(check, 400)
        else
            self:Verdict(true, "The bag upgrade didn't go through -- the game refused the purchase.")
        end
    end
    if zo_callLater then zo_callLater(check, 350) end
end

function GPI:SwitchBankPane()
    self:RefreshKeybindStrip()
    if not self.bankMode then return end
    if self.selZone == "bankgrid" then
        self.selZone = "grid"
    else
        self.selZone = "bankgrid"
        self.bankIndex = self.bankIndex or 1
    end
    self:Render()
end

function GPI:RunInputAction(action, source)
    if not self:IsShowing() or not action then return false end

    -- A native dialog (e.g. Buy Bank Space) owns the controller while it's up.
    -- Without this, B would decline the dialog AND close our window in the same
    -- press, stranding the player on the suppressed native scene.
    if self:IsNativeDialogShowing() then
        -- This press reached us before the DialogWatch tick could release
        -- capture; release now so the NEXT press lands on the dialog's own
        -- keybinds instead of dying at our keyboard-enabled window.
        self:SetInputCaptureEnabled(false)
        return false
    end

    -- v1.0.1: PRIMARY runs from EVERY input source. The old code blocked A from raw
    -- key codes and the keybind prehook, waiting for a KEYBIND_STRIP "secure callback"
    -- that never fires for this custom modal -- which is why the A button did nothing.
    -- The premise was wrong anyway: RequestEquipItem is a public function (works from
    -- any context; proven via /gpi test), and UseItem goes through CallSecureProtected,
    -- which works from any addon code outside combat.

    if IsDebouncedAction(action) then
        local now = NowMs()
        if self.lastInputAction == action and now > 0 and self.lastInputAt and (now - self.lastInputAt) < (self.inputDebounceMs or 85) then
            return true
        end
        self.lastInputAction = action
        self.lastInputAt = now
    end

    -- The difficulty pick list owns the controller while open.
    if self.diffPickOpen then
        local n = #(self.diffPickOptions or {})
        if self.qsWheelMode and n > 0
            and (action == "UP" or action == "DOWN" or action == "LEFT" or action == "RIGHT") then
            -- Wheel navigation (v1.43, by request):
            --   RIGHT = rotate selection one slot CLOCKWISE on screen
            --   LEFT  = rotate one slot COUNTER-CLOCKWISE
            --   UP    = jump to the TOP slot (nearest 90 degrees)
            --   DOWN  = jump to the BOTTOM slot (nearest 270 degrees)
            -- Layout dir is -1 when successive indices are laid out clockwise, so a
            -- clockwise step is index + (-dir); counter-clockwise is index + dir.
            if action == "LEFT" or action == "RIGHT" then
                local _, dir = self:GetWheelLayout()
                local step = (action == "RIGHT") and -dir or dir
                self.diffPickIndex = ((self.diffPickIndex - 1 + step) % n) + 1
            else
                local want = (action == "UP") and 90 or 270
                local best, bestDiff = self.diffPickIndex, 361
                for i = 1, n do
                    local deg = math.deg(self:WheelSlotAngle(i, n)) % 360
                    local diff = math.abs(((deg - want) + 180) % 360 - 180)
                    if diff < bestDiff then best, bestDiff = i, diff end
                end
                self.diffPickIndex = best -- already at top/bottom: press is a no-op
            end
            self:RenderQuickslotWheel()
            return true
        end
        if action == "UP" or action == "DOWN" then
            if n > 0 then
                local step = (action == "UP") and -1 or 1
                self.diffPickIndex = ((self.diffPickIndex - 1 + step) % n) + 1
                self:RenderDiffPick()
            end
        elseif action == "PRIMARY" then
            self:ConfirmDiffPick()
        elseif action == "NEGATIVE" then
            self:HideDiffPick()
        end
        return true -- swallow everything else while the picker is up
    end

    -- GridPad's own Upgrade Bag Space confirmation is modal while open. Checked
    -- BEFORE the doll zone: the confirm can be opened from the doll's bag stop,
    -- and a second A there must confirm, not re-open.
    if self.bagConfirmOpen then
        if action == "PRIMARY" then
            self:ConfirmBuyBagSpace()
        elseif action == "NEGATIVE" or action == "SECONDARY" then
            self:HideBagConfirm()
        end
        return true
    end

    -- The currency transfer panel is modal while open: d-pad edits the amount,
    -- X flips direction, Y maxes, A confirms, B cancels. Everything else is
    -- swallowed so a stray press can't act on the grids underneath.
    if self.curPanelOpen then
        if action == "LEFT" or action == "RIGHT" or action == "UP" or action == "DOWN"
            or action == "SECONDARY" or action == "TERTIARY" then
            self:AdjustCurrencyPanel(action)
        elseif action == "PRIMARY" then
            self:ConfirmCurrencyTransfer()
        elseif action == "NEGATIVE" then
            self:HideCurrencyPanel()
        end
        return true
    end

    -- B closes the compare popup first; a second press closes the window.
    if action == "NEGATIVE" and self.infoPopupOpen and not self.simpleView then
        self:HideInfoPopup()
        return true
    end
    if action == "NEGATIVE" and self.compareOpen then
        self:HideCompare()
        return true
    end

    -- Full view only: while the LT panel is open it captures input (LT advances the
    -- cycle, B closes it, movement falls through). In simple view the panel is
    -- ambient -- always open, following the selection -- so it must never swallow
    -- item actions like A/X/Y/RT.
    if self.infoPopupOpen and not self.simpleView then
        if action == "INFO" then
            self:ToggleInfoPopup()
            return true
        elseif action == "LEFT" or action == "RIGHT" or action == "UP" or action == "DOWN"
            or action == "PAGE_PREV" or action == "PAGE_NEXT" or action == "PAGE_CYCLE"
            or action == "FILTER_PREV" or action == "FILTER_NEXT" then
            -- fall through to normal handling below, then refresh the panel
        else
            return true
        end
    end

    -- Character-panel zone: item actions belong to the grid; Y links the worn item.
    if self.selZone == "doll" then
        if action == "PRIMARY" and self.dollOnDiff then
            self:OpenDiffPick()
            return true
        end
        if action == "PRIMARY" and self.dollOnBag then
            self:ShowBagUpgradeConfirm()
            return true
        end
        if action == "PRIMARY" or action == "SECONDARY" or action == "COMPARE" then
            self:Verdict(false, "Backpack actions run from the grid -- press RIGHT to jump back.")
            return true
        elseif action == "TERTIARY" then
            -- Y on worn gear opens the full native action list: Enchant, Charge,
            -- Unequip, Repair, Link in Chat -- whatever applies to that piece.
            self:OpenItemActionsMenu()
            return true
        end
    end

    -- Toggle-focus zone: the View button is highlighted; A flips it, DOWN/B returns.
    if self.selZone == "toggle" then
        if action == "PRIMARY" then
            self:ToggleSimpleView()
            self:ExitToggleZone()
            return true
        elseif action == "DOWN" or action == "NEGATIVE" then
            self:ExitToggleZone()
            return true
        elseif action == "UP" or action == "LEFT" or action == "RIGHT" then
            return true -- stay on the toggle
        elseif action == "SECONDARY" or action == "TERTIARY" or action == "COMPARE" or action == "INFO" then
            return true -- swallow item actions while focused on the toggle
        end
    end

    -- GridPad's own Buy Bank Space confirmation is modal while open.
    if self.bankConfirmOpen then
        if action == "PRIMARY" then
            self:ConfirmBuyBankSpace()
        elseif action == "NEGATIVE" or action == "SECONDARY" then
            self:HideBankConfirm()
        end
        return true
    end

    -- R3 at a banker hands off to the vanilla buy-bank-space flow (the only
    -- context the purchase API accepts), then GridPad retakes the bank after.
    if action == "BAG_TYPE_OR_BANK" then
        action = self.bankMode and "BUY_BANK_SPACE" or "BAG_TYPE_TOGGLE"
    end

    if action == "BUY_BANK_SPACE" then
        if self.bankMode then self:BeginBankUpgradeHandoff() end
        return true
    end

    -- L3 toggles the sort mode anywhere (mirrors the native FILTER/SORT bind).
    if action == "SORT_TOGGLE" then
        self:ToggleSortByType()
        return true
    end

    -- R3 flips Inventory <-> Craft Bag from anywhere, the same way L3 flips sort.
    -- At a banker R3 keeps its buy-bank-space meaning (handled just above).
    if action == "BAG_TYPE_TOGGLE" then
        self:ToggleBagType()
        return true
    end

    -- Currency strip focus (top of the bank pane): LEFT/RIGHT picks a currency,
    -- A opens the transfer panel, DOWN or B drops back into the bank grid, X hops
    -- to the backpack grid. Item actions are swallowed -- chips aren't items.
    if self.bankMode and self.selZone == "bankcurrency" then
        local list = self:GetBankableCurrencies()
        local n = #list
        local idx = self.bankCurIndex or 1
        if action == "LEFT" then
            if idx > 1 then self.bankCurIndex = idx - 1 self:Render() end
            return true
        elseif action == "RIGHT" then
            if idx < n then self.bankCurIndex = idx + 1 self:Render() end
            return true
        elseif action == "DOWN" or action == "NEGATIVE" then
            self.selZone = "bankgrid"
            self:Render()
            return true
        elseif action == "PRIMARY" then
            if list[idx] then self:ShowCurrencyPanel(list[idx]) end
            return true
        elseif action == "SECONDARY" then
            self.selZone = "grid"
            self:Render()
            return true
        elseif action == "FILTER_PREV" then
            self:CycleFilter(-1)
            return true
        elseif action == "FILTER_NEXT" then
            self:CycleFilter(1)
            return true
        else
            return true
        end
    end

    -- Bank pane focus: full grid navigation, LB/RB pages, A withdraws, X hops back.
    if self.bankMode and self.selZone == "bankgrid" then
        local cols = self.bankCols or 1
        local base = (self.bankPage or 0) * (self.bankPageSize or 1)
        local shown = math.min(#(self.bankItems or {}) - base, self.bankPageSize or 1)
        if shown < 1 then shown = 1 end
        local idx = self.bankIndex or 1
        if action == "LEFT" then
            if idx % cols ~= 1 and cols > 1 then self.bankIndex = idx - 1 self:Render() end
            return true
        elseif action == "RIGHT" then
            if cols == 1 or idx % cols == 0 or idx >= shown then
                self.selZone = "grid" -- rightmost column: hop to the backpack grid
                self:Render()
            else
                self.bankIndex = idx + 1
                self:Render()
            end
            return true
        elseif action == "UP" then
            if idx > cols then
                self.bankIndex = idx - cols
                self:Render()
            elseif (self.bankPage or 0) > 0 then
                -- Top row: page back, landing at the same column's bottom row.
                self.bankPage = self.bankPage - 1
                self.bankIndex = ((self.bankRows or 1) - 1) * cols + ((idx - 1) % cols) + 1
                self:Render()
            else
                -- Top row of page 1: climb onto the currency strip.
                self.selZone = "bankcurrency"
                self.bankCurIndex = self.bankCurIndex or 1
                self:Render()
            end
            return true
        elseif action == "DOWN" then
            local maxPage = math.max(0, math.ceil(#(self.bankItems or {}) / (self.bankPageSize or 1)) - 1)
            if idx + cols <= shown then
                self.bankIndex = idx + cols
                self:Render()
            elseif (self.bankPage or 0) < maxPage then
                -- Bottom row: page forward, landing at the same column's top row.
                self.bankPage = self.bankPage + 1
                self.bankIndex = ((idx - 1) % cols) + 1
                self:Render()
            end
            return true
        elseif action == "FILTER_PREV" then
            self:CycleFilter(-1)
            return true
        elseif action == "FILTER_NEXT" then
            self:CycleFilter(1)
            return true
        elseif action == "PRIMARY" then
            self:BankTransferSelected()
            return true
        elseif action == "SECONDARY" then
            self:SwitchBankPane()
            return true
        elseif action == "TERTIARY" then
            self:OpenItemActionsMenu()
            return true
        elseif action == "COMPARE"
            or action == "PAGE_PREV" or action == "PAGE_NEXT" or action == "PAGE_CYCLE" then
            return true
        end
    end

    -- Bank mode: A on a backpack item deposits it; X hops focus to the bank pane.
    if self.bankMode and self.selZone == "grid" then
        if action == "PRIMARY" then
            -- Craft bag mode: A means "withdraw this material", not "deposit to bank".
            if self:IsCraftBagMode() then self:UseSelected(source) else self:BankTransferSelected() end
            return true
        elseif action == "SECONDARY" then
            self:SwitchBankPane()
            return true
        end
    end

    -- Bottom-bar zone: Sort and View buttons under the grid. LEFT/RIGHT moves
    -- between them, A activates, UP or B returns to the grid.
    if self.selZone == "bottombar" then
        local idx = self.bottomIndex or BOTTOM_BUTTON_SORT
        if action == "PRIMARY" then
            if idx == BOTTOM_BUTTON_UPGRADE then self:ShowBagUpgradeConfirm()
            elseif idx == BOTTOM_BUTTON_BAGTYPE then self:ToggleBagType()
            else self:ToggleSortByType() end
            return true
        elseif action == "LEFT" then
            self.bottomIndex = math.max(self:BottomMinIndex(), idx - 1)
            self:Render()
            return true
        elseif action == "RIGHT" then
            self.bottomIndex = math.min(BOTTOM_BUTTON_COUNT, idx + 1)
            self:Render()
            return true
        elseif action == "DOWN" or action == "NEGATIVE" then
            -- The grid sits below the strip, so DOWN is the way back into it.
            self:ExitBottomZone()
            return true
        elseif action == "UP" then
            return true
        elseif action == "SECONDARY" or action == "TERTIARY" or action == "COMPARE" or action == "INFO" then
            return true
        end
    end

    -- Craft bag paging is VERTICAL: the tab is one long list you walk down, and the
    -- bottom row rolls to the next page. LEFT/RIGHT never leave the current row, so
    -- moving right can't skip a page the way it does in the backpack grid.
    if self:IsCraftBagMode() and self.selZone == "grid" then
        local cols = self.cols or 1
        local pageIndex = self.selectedIndex - (self.currentPage * self.pageSize)
        local shown = math.min(#self.items - self.currentPage * self.pageSize, self.pageSize)
        local maxPage = math.max(0, math.ceil(#self.items / self.pageSize) - 1)
        local col = (pageIndex - 1) % cols

        if action == "RIGHT" then
            -- Stop at the row's last populated cell.
            if col < cols - 1 and pageIndex < shown then self:Move(1) end
            return true
        elseif action == "LEFT" then
            if col > 0 then self:Move(-1) end
            return true
        elseif action == "DOWN" then
            if pageIndex + cols <= shown then
                self:Move(cols)
            elseif self.currentPage < maxPage then
                -- Roll to the next page, keeping the column and landing on row 0.
                self.currentPage = self.currentPage + 1
                local target = self.currentPage * self.pageSize + col + 1
                local lastOnPage = math.min(#self.items, (self.currentPage + 1) * self.pageSize)
                self.selectedIndex = Clamp(target, self.currentPage * self.pageSize + 1, lastOnPage)
                self:Render()
            elseif self.simpleView then
                -- End of the last page: fall through to the button strip as usual.
                self:EnterBottomZone()
            end
            return true
        elseif action == "UP" then
            if pageIndex > cols then
                self:Move(-cols)
            elseif self.currentPage > 0 then
                -- Roll back a page, keeping the column and landing on the last row.
                self.currentPage = self.currentPage - 1
                local prevShown = math.min(#self.items - self.currentPage * self.pageSize, self.pageSize)
                local lastRow = math.floor((prevShown - 1) / cols)
                local target = self.currentPage * self.pageSize + lastRow * cols + col + 1
                local lastOnPage = self.currentPage * self.pageSize + prevShown
                self.selectedIndex = Clamp(target, self.currentPage * self.pageSize + 1, lastOnPage)
                self:Render()
            elseif self.simpleView then
                -- Top row of the FIRST page: there is nowhere further up inside the
                -- grid, so UP must hand off to the Bag Type / Sort strip above it --
                -- otherwise this branch swallows the press and the craft bag becomes a
                -- one-way trip (Bag Type unreachable, no way back to Inventory).
                self:EnterBottomZone(BOTTOM_BUTTON_BAGTYPE)
            end
            return true
        end
    end

    if action == "LEFT" then
        if self.selZone == "doll" then self:MoveDoll("LEFT")
        elseif self:IsGridLeftEdge() and self.bankMode then
            -- Hop into the bank pane at the matching row's rightmost column.
            local cols = self.bankCols or 1
            local base = (self.bankPage or 0) * (self.bankPageSize or 1)
            local shown = math.min(#(self.bankItems or {}) - base, self.bankPageSize or 1)
            local row = math.min(self:GetGridRow(), math.max(0, (self.bankRows or 1) - 1))
            local target = math.min(row * cols + cols, math.max(1, shown))
            self.selZone = "bankgrid"
            self.bankIndex = math.max(1, target)
            self:Render()
        elseif self:IsGridLeftEdge() then self:EnterDollZone(self:GetGridRow())
        else self:Move(-1) end
    elseif action == "RIGHT" then
        if self.selZone == "doll" then self:MoveDoll("RIGHT") else self:Move(1) end
    elseif action == "UP" then
        if self.selZone == "doll" then self:MoveDoll("UP")
        elseif self.selZone == "toggle" then -- already there; stay
        elseif self:GetGridRow() == 0 then
            -- The Bag Type / Sort strip is rendered ABOVE the grid, so UP from the top
            -- row is how you reach it. (DOWN from the bottom row still works as well.)
            if self.simpleView then self:EnterBottomZone(BOTTOM_BUTTON_BAGTYPE) end
        else self:Move(-self.cols) end
    elseif action == "DOWN" then
        if self.selZone == "doll" then self:MoveDoll("DOWN")
        elseif self.selZone == "grid" and self.simpleView and self:IsGridBottomRow() then self:EnterBottomZone()
        else self:Move(self.cols) end
    elseif action == "PAGE_PREV" then self:Page(-1)
    elseif action == "PAGE_NEXT" then self:Page(1)
    elseif action == "PAGE_CYCLE" then
        local pageCount = math.max(1, math.ceil(#self.items / self.pageSize))
        self.currentPage = (self.currentPage + 1) % pageCount
        self.selectedIndex = Clamp(self.currentPage * self.pageSize + 1, 1, math.max(1, #self.items))
        self:Render()
    elseif action == "FILTER_PREV" then self:CycleFilter(-1)
    elseif action == "FILTER_NEXT" then self:CycleFilter(1)
    elseif action == "PRIMARY" then self:UseSelected(source)
    elseif action == "SECONDARY" then self:ToggleJunkSelected()
    elseif action == "TERTIARY" then self:OpenItemActionsMenu()
    elseif action == "INFO" then
        if self.simpleView then
            self:ToggleInfoPopup()
        else
            self.showItemInfo = not self.showItemInfo
            self:Render()
        end
    elseif action == "COMPARE" then self:ToggleCompare()
    elseif action == "NEGATIVE" then self:Close()
    else return false end

    -- Compare popup follows the selection live.
    if self.compareOpen and self.selZone ~= "doll" and self.selZone ~= "bottombar" and self.selZone ~= "bankgrid" and action ~= "COMPARE" and action ~= "NEGATIVE" and action ~= "PRIMARY" and action ~= "INFO" then
        self:ShowCompare(true)
    end

    return true
end

local function ShortcutMatches(keybind, aliases)
    for i = 1, #aliases do
        if keybind == aliases[i] then return true end
    end
    return false
end

function GPI:HandleShortcut(keybind)
    if not self:IsShowing() or not keybind then return false end

    if ShortcutMatches(keybind, {"UI_SHORTCUT_LEFT", "UI_SHORTCUT_INPUT_LEFT", "UI_SHORTCUT_LEFT_STICK_LEFT"}) then
        return self:RunInputAction("LEFT", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_RIGHT", "UI_SHORTCUT_INPUT_RIGHT", "UI_SHORTCUT_LEFT_STICK_RIGHT"}) then
        return self:RunInputAction("RIGHT", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_UP", "UI_SHORTCUT_INPUT_UP", "UI_SHORTCUT_LEFT_STICK_UP"}) then
        return self:RunInputAction("UP", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_DOWN", "UI_SHORTCUT_INPUT_DOWN", "UI_SHORTCUT_LEFT_STICK_DOWN"}) then
        return self:RunInputAction("DOWN", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_LEFT_SHOULDER", "UI_SHORTCUT_INPUT_LEFT_SHOULDER"}) then
        return self:RunInputAction("FILTER_PREV", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_RIGHT_SHOULDER", "UI_SHORTCUT_INPUT_RIGHT_SHOULDER"}) then
        return self:RunInputAction("FILTER_NEXT", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_LEFT_TRIGGER", "UI_SHORTCUT_INPUT_LEFT_TRIGGER"}) then
        return self:RunInputAction("INFO", "shortcut")
    elseif ShortcutMatches(keybind, {"UI_SHORTCUT_RIGHT_TRIGGER", "UI_SHORTCUT_INPUT_RIGHT_TRIGGER"}) then
        return self:RunInputAction("COMPARE", "shortcut")
    elseif keybind == "UI_SHORTCUT_PRIMARY" then
        return self:RunInputAction("PRIMARY", "shortcut")
    elseif keybind == "UI_SHORTCUT_SECONDARY" then
        return self:RunInputAction("SECONDARY", "shortcut")
    elseif keybind == "UI_SHORTCUT_TERTIARY" then
        return self:RunInputAction("TERTIARY", "shortcut")
    elseif keybind == "UI_SHORTCUT_NEGATIVE" then
        return self:RunInputAction("NEGATIVE", "shortcut")
    end

    return false
end

local KEYCODE_ACTIONS = nil
local function AddKeyCodeAction(keyCode, action)
    if keyCode then KEYCODE_ACTIONS[keyCode] = action end
end

function GPI:BuildKeyCodeActions()
    if KEYCODE_ACTIONS then return end
    KEYCODE_ACTIONS = {}

    AddKeyCodeAction(KEY_GAMEPAD_DPAD_LEFT, "LEFT")
    AddKeyCodeAction(KEY_GAMEPAD_DPAD_RIGHT, "RIGHT")
    AddKeyCodeAction(KEY_GAMEPAD_DPAD_UP, "UP")
    AddKeyCodeAction(KEY_GAMEPAD_DPAD_DOWN, "DOWN")
    AddKeyCodeAction(KEY_GAMEPAD_LEFT_SHOULDER, "FILTER_PREV")
    AddKeyCodeAction(KEY_GAMEPAD_RIGHT_SHOULDER, "FILTER_NEXT")
    AddKeyCodeAction(KEY_GAMEPAD_LEFT_TRIGGER, "INFO")
    AddKeyCodeAction(KEY_GAMEPAD_RIGHT_TRIGGER, "COMPARE")
    AddKeyCodeAction(KEY_GAMEPAD_BUTTON_1, "PRIMARY") -- the A button (was never mapped!)
    AddKeyCodeAction(KEY_GAMEPAD_BUTTON_2, "NEGATIVE")
    AddKeyCodeAction(KEY_GAMEPAD_BUTTON_3, "SECONDARY")
    AddKeyCodeAction(KEY_GAMEPAD_LEFT_STICK, "SORT_TOGGLE")     -- L3: filter/sort
    -- R3 is context-sensitive: at a banker it buys bank space (its only use there),
    -- everywhere else it flips Bag Type. Resolved in HandleKeyCode via BAG_TYPE_OR_BANK.
    AddKeyCodeAction(KEY_GAMEPAD_RIGHT_STICK, "BAG_TYPE_OR_BANK")

    AddKeyCodeAction(KEY_GAMEPAD_BUTTON_4, "TERTIARY")

    AddKeyCodeAction(KEY_LEFTARROW, "LEFT")
    AddKeyCodeAction(KEY_RIGHTARROW, "RIGHT")
    AddKeyCodeAction(KEY_UPARROW, "UP")
    AddKeyCodeAction(KEY_DOWNARROW, "DOWN")
    AddKeyCodeAction(KEY_ESCAPE, "NEGATIVE")
    AddKeyCodeAction(KEY_ENTER, "PRIMARY")
    AddKeyCodeAction(KEY_SPACEBAR, "PRIMARY")
end

-- Ring hold-to-equip (v1.10): with a ring selected in the grid, tapping A equips
-- normally (empty slot preferred), while HOLDING A (~430ms) forces Ring 2. The raw
-- key down starts a session and is consumed; release before the threshold taps,
-- the timer firing first holds. The keybind-strip PRIMARY defers to an active
-- session so the same press never equips twice.
local RING_HOLD_MS = 430

function GPI:UpdateRingHoldHint()
    local elig = (self:RingHoldEligible() or self:QuickslotHoldEligible()) and true or false
    if elig == self.ringHintShown then return end
    self.ringHintShown = elig
    if KEYBIND_STRIP and KEYBIND_STRIP.UpdateKeybindButtonGroup
        and self.keybindStrip and self.keybindsAdded then
        pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStrip) end)
    end
end

-- ===================== Quickslot assignment (hold A) =====================
-- ESO's quickslot range is the utility section of the action bar. Both constants are
-- read defensively: if the client does not expose them there is no safe way to
-- enumerate slots, and GridPad says so rather than guessing indices.
-- Which hotbar the quickslot wheel lives on, when the client exposes categories.
-- Diagnostics write to chat AND to SavedVariables, because a long report cannot be
-- copied out of the ESO chat window. After running one, /reloadui flushes
-- GridPadInventory.lua in the SavedVariables folder, which can then be sent as a file.
function GPI:DiagLine(msg)
    AddChatMessage(msg)
    if self.sv then
        self.sv.lastReport = self.sv.lastReport or {}
        self.sv.lastReport[#self.sv.lastReport + 1] = tostring(msg)
    end
end

function GPI:BeginReport(title)
    if self.sv then self.sv.lastReport = {} end
    self:DiagLine("[GridPad] ==== " .. tostring(title) .. " ====")
end

function GPI:EndReport()
    self:DiagLine("[GridPad] ==== end ====")
    AddChatMessage("[GridPad] Screenshot lines 1-5 above -- that is all that is needed.")
end

function GPI:RunDiagnostic(lower)
    -- Print the running build first: several reports so far have come from a stale copy.
    AddChatMessage("[GridPad] build v" .. tostring(GPI.version) .. " (AddOnVersion " .. tostring(GPI.addOnVersion) .. ")")
    -- /gpi quickslot -- dump what this client actually exposes, so the quickslot
    -- wiring can be based on real constant names instead of guessed ones.
    if lower:match("^%s*quickslots?%s*$") then
        self._qsRange = nil -- always re-discover for a fresh report
        self:BeginReport("quickslot report")

        -- === SUMMARY: five lines, screenshot-sized. Read this, ignore the rest. ===
        do
            local f = self:DiscoverQuickslotBar()
            local a, b, hb = self:GetQuickslotRange()
            self:DiagLine("1) bar=" .. tostring(f and f.name or "NONE FOUND")
                .. " hotbar=" .. tostring(f and f.hotbar))
            self:DiagLine("2) occupied=" .. tostring(f and f.occupied or 0)
                .. " range=" .. (a and (a .. "-" .. b) or "none"))
            local names = {}
            for slot = (a or 1), (b or 0) do
                if self:SlotLooksOccupied(slot, hb) then
                    names[#names + 1] = slot .. ":" .. tostring(self:ProbeSlot(slot, hb))
                end
            end
            self:DiagLine("3) filled=" .. (#names > 0 and table.concat(names, " ") or "(none)"))
            local cl = {}
            for _, c in ipairs(self:GetKnownHotbarCategories()) do
                cl[#cl + 1] = c.name:gsub("^HOTBAR_CATEGORY_", "") .. "=" .. tostring(c.hotbar)
            end
            self:DiagLine("3b) cats=" .. (#cl > 0 and table.concat(cl, ",") or "NONE"))
            self:DiagLine("4) secure=" .. SafeGlobalKind("CallSecureProtected")
                .. " gpQS=" .. SafeGlobalKind("GAMEPAD_QUICKSLOT"))
            self:DiagLine("5) lastAssign=" .. tostring(self.sv and self.sv.lastAssign or "none"))
            self:DiagLine("---- detail below, only line 1-5 matter ----")
        end

        local found = self:DiscoverQuickslotBar()
        if found then
            self:DiagLine(string.format("bar: %s (hotbar=%s) with %d occupied slot(s), last=%s",
                tostring(found.name), tostring(found.hotbar), found.occupied, tostring(found.last)))
        else
            self:DiagLine("bar: NO hotbar had any occupied slot")
        end

        local first, last, hotbar = self:GetQuickslotRange()
        self:DiagLine("range: " .. (first and (first .. "-" .. last) or "NOT FOUND")
            .. "  hotbar=" .. tostring(hotbar))
        if first then
            for slot = first, last do
                local occ = self:SlotLooksOccupied(slot, hotbar)
                self:DiagLine(string.format("  slot %d = %s%s", slot,
                    self:ProbeSlot(slot, hotbar), occ and "" or " (empty)"))
            end
        end

        -- Per-hotbar occupancy, so a wrong pick is visible in the report.
        for _, n in ipairs(ScanGlobalNames({ "^HOTBAR_CATEGORY_" })) do
            local v = SafeGlobalNumber(n)
            if v ~= nil then
                local c = 0
                for i = 1, 24 do if self:SlotLooksOccupied(i, v) then c = c + 1 end end
                self:DiagLine(string.format("  %s=%d -> %d occupied", n, v, c))
            end
        end

        for _, n in ipairs({ "ACTION_BAR_FIRST_UTILITY_BAR_SLOT", "ACTION_BAR_UTILITY_BAR_SIZE",
                             "ACTION_TYPE_ITEM", "ACTION_TYPE_ABILITY", "ACTION_TYPE_NOTHING" }) do
            self:DiagLine("  " .. n .. "=" .. tostring(ConstantValue(n)))
        end
        for _, n in ipairs({ "GetSlotType", "GetSlotItemLink", "GetSlotName", "SelectSlotItem",
                             "GetMaxQuickslots", "SetSlotItem" }) do
            self:DiagLine("  " .. n .. " [" .. SafeGlobalKind(n) .. "]")
        end
        self:DiagLine("last assign attempt: " ..
            tostring(self.sv and self.sv.lastAssign or "none this session"))
        local gq = _G["GAMEPAD_QUICKSLOT"]
        if type(gq) == "table" then
            local ms = {}
            pcall(function()
                for k, v in pairs(gq) do
                    if type(v) == "function" then ms[#ms + 1] = tostring(k) end
                end
            end)
            table.sort(ms)
            self:DiagLine("GAMEPAD_QUICKSLOT methods (" .. #ms .. "):")
            for i = 1, math.min(#ms, 40) do self:DiagLine("  ." .. ms[i]) end
        end
        self:DiagLine("GAMEPAD_QUICKSLOT: " .. SafeGlobalKind("GAMEPAD_QUICKSLOT"))
        self:DiagLine("CallSecureProtected: " .. SafeGlobalKind("CallSecureProtected"))
        self:EndReport()
        return
    end

    -- /gpi lam -- report the AddOnVersion of the LibAddonMenu-2.0 actually installed.
    -- The manifest's DependsOn number must be <= this, and the only trustworthy
    -- source for it is the client: LAM's public source ships a @BUILD_NUMBER@
    -- placeholder, and its git tag number is NOT necessarily the built AddOnVersion.
    if lower:match("^%s*lam%s*$") then
        local mgr = GetAddOnManager and SafeCall(GetAddOnManager)
        if not mgr or not mgr.GetNumAddOns then
            AddChatMessage("[GridPad] Add-on manager unavailable in this client.")
            return
        end
        local total = SafeCall(function() return mgr:GetNumAddOns() end) or 0
        local hits = 0
        for i = 1, total do
            local name = SafeCall(function() return mgr:GetAddOnInfo(i) end)
            if type(name) == "string" and name:lower():find("libaddonmenu") then
                hits = hits + 1
                local ver = mgr.GetAddOnVersion and SafeCall(function() return mgr:GetAddOnVersion(i) end)
                AddChatMessage(string.format("[GridPad] %s -- AddOnVersion: %s",
                    name, ver ~= nil and tostring(ver) or "not reported"))
                if type(ver) == "number" and ver > 0 then
                    AddChatMessage("[GridPad] Manifest line to use:  ## DependsOn: "
                        .. name .. ">=" .. tostring(ver))
                end
            end
        end
        if hits == 0 then
            AddChatMessage("[GridPad] No LibAddonMenu-2.0 found in the add-on list.")
        end
        local lam = _G["LibAddonMenu2"]
        AddChatMessage("[GridPad] LibAddonMenu2 global is " .. (lam and "loaded." or "NOT loaded."))
        return
    end

    -- /gpi icons -- report every tab in the active row: ICON + path, or TEXT.
    if lower:match("^%s*icons%s*$") then
        local bar = self:GetActiveIconBar()
        AddChatMessage((self:IsCraftBagMode() and "Craft Bag" or "Inventory")
            .. " filter row -- " .. tostring(#bar) .. " tabs:")
        for i = 1, #bar do
            local e = bar[i]
            local path, forcedText = ResolvedIconPath(self.sv, e)
            if forcedText then
                AddChatMessage(string.format("  %2d. %-16s TEXT '%s'  (forced via /gpi icon)", i, e.key, tostring(e.abbr)))
            elseif path then
                AddChatMessage(string.format("  %2d. %-16s ICON  %s", i, e.key, path))
            elseif not forcedText and self:GetRepresentativeIcon(e) then
                AddChatMessage(string.format("  %2d. %-16s ITEM  %s", i, e.key, self:GetRepresentativeIcon(e)))
            else
                local cands = e.candidates and (" (untested: " .. table.concat(e.candidates, " , ") .. ")") or ""
                AddChatMessage(string.format("  %2d. %-16s TEXT '%s'%s", i, e.key, tostring(e.abbr), cands))
            end
        end
        AddChatMessage("ICON = ESO tab art, ITEM = borrowed from a material in that tab, TEXT = letters.")
        AddChatMessage("A white/blank square means a bad path -- set one with:")
        AddChatMessage("  /gpi icon <key> <texture path>    (or '/gpi icon <key> text' to force text)")
        return
    end
end

function GPI:GetQuickslotHotbar()
    for _, n in ipairs({ "HOTBAR_CATEGORY_QUICKSLOT_WHEEL", "HOTBAR_CATEGORY_QUICKSLOT" }) do
        local v = ConstantValue(n)
        if type(v) == "number" then return v, n end
    end
    return nil
end

-- Does this slot hold an ITEM? Abilities live on the weapon bars and must not count --
-- scoring "anything present" is what made the skill bar win over an empty wheel.
function GPI:SlotHoldsItem(slot, hotbar)
    local itemType = ConstantValue("ACTION_TYPE_ITEM")
    local st
    if GetSlotType then
        st = (hotbar ~= nil) and SafeCall(GetSlotType, slot, hotbar) or SafeCall(GetSlotType, slot)
    end
    if itemType ~= nil and type(st) == "number" then return st == itemType end

    -- No ACTION_TYPE_ITEM to compare against: fall back to an item link, which an
    -- ability slot does not produce.
    local link
    if GetSlotItemLink then
        link = (hotbar ~= nil) and SafeCall(GetSlotItemLink, slot, hotbar)
                                or SafeCall(GetSlotItemLink, slot)
    end
    return type(link) == "string" and link ~= ""
end

-- Kept for the report: anything at all in the slot, ability or item.
function GPI:SlotLooksOccupied(slot, hotbar)
    if self:SlotHoldsItem(slot, hotbar) then return true end
    local st
    if GetSlotType then
        st = (hotbar ~= nil) and SafeCall(GetSlotType, slot, hotbar) or SafeCall(GetSlotType, slot)
    end
    local nothing = ConstantValue("ACTION_TYPE_NOTHING") or 0
    return type(st) == "number" and st ~= nothing
end

-- Human-readable contents of a slot, for the picker rows.
function GPI:ProbeSlot(slotIndex, hotbar)
    if self:SlotLooksOccupied(slotIndex, hotbar) then
        local link
        if GetSlotItemLink then
            link = (hotbar ~= nil) and SafeCall(GetSlotItemLink, slotIndex, hotbar)
                                    or SafeCall(GetSlotItemLink, slotIndex)
        end
        if type(link) == "string" and link ~= "" and GetItemLinkName then
            local n = SafeCall(GetItemLinkName, link)
            if type(n) == "string" and n ~= "" then return n end
        end
        local n
        if GetSlotName then
            n = (hotbar ~= nil) and SafeCall(GetSlotName, slotIndex, hotbar)
                                 or SafeCall(GetSlotName, slotIndex)
        end
        if type(n) == "string" and n ~= "" then return n end
        return "(in use)"
    end
    return ""
end

-- Identify the quickslot bar.
--
-- Naming wins over occupancy: an empty quickslot wheel is the normal state for someone
-- about to slot their first potion, so requiring contents rejected the very bar we want
-- and handed the win to the always-full skill bar. Occupancy is only a tiebreak, and it
-- counts ITEMS, never abilities.
-- Every known hotbar category this client actually defines, by direct name lookup.
function GPI:GetKnownHotbarCategories()
    local out = {}
    for _, n in ipairs(KNOWN_HOTBAR_CATEGORIES) do
        local v = ConstantValue(n)
        if type(v) == "number" then out[#out + 1] = { hotbar = v, name = n } end
    end
    return out
end

function GPI:DiscoverQuickslotBar()
    local cats = self:GetKnownHotbarCategories()

    local function measure(c)
        local items, last = 0, nil
        for i = 1, 24 do
            if self:SlotHoldsItem(i, c.hotbar) then items = items + 1 last = i end
        end
        return { hotbar = c.hotbar, name = c.name, occupied = items, last = last }
    end

    -- 1. A category whose name says quickslot, regardless of whether anything is in it.
    for _, c in ipairs(cats) do
        if tostring(c.name):find("QUICKSLOT") then
            local m = measure(c)
            m.reason = "named"
            return m
        end
    end

    -- 2. Otherwise the bar holding the most ITEMS. Weapon bars hold abilities and score
    --    zero here, so they can no longer be mistaken for the wheel.
    local best
    for _, c in ipairs(cats) do
        local m = measure(c)
        if m.occupied > 0 and (best == nil or m.occupied > best.occupied) then best = m end
    end
    local noCat = measure({ hotbar = nil, name = "(no category)" })
    if noCat.occupied > 0 and (best == nil or noCat.occupied > best.occupied) then best = noCat end
    if best then best.reason = "items" end
    return best
end

-- Resolve the quickslot index range. Named constants when the client has them,
-- otherwise evidence-based discovery. A range is never accepted on the strength of
-- "the API didn't complain" -- that is what produced the bogus 1-24 of empties.
function GPI:GetQuickslotRange()
    if self._qsRange ~= nil then
        if self._qsRange == false then return nil end
        return self._qsRange[1], self._qsRange[2], self._qsRange[3]
    end

    local first = ConstantValue("ACTION_BAR_FIRST_UTILITY_BAR_SLOT")
    local size = ConstantValue("ACTION_BAR_UTILITY_BAR_SIZE")
    if type(first) == "number" and type(size) == "number" and size > 0 then
        local hotbar = self:GetQuickslotHotbar()
        self._qsRange = { first + 1, first + size, hotbar }
        return first + 1, first + size, hotbar
    end

    local found = self:DiscoverQuickslotBar()
    if found then
        -- Slots at or below the last occupied one are known-good. Show at least 8, the
        -- standard wheel size, so empty slots are still assignable targets.
        local last = math.max(found.last or 0, 8) -- standard wheel is 8; empty is fine
        self._qsRange = { 1, last, found.hotbar }
        self._qsBarName = found.name
        return 1, last, found.hotbar
    end

    self._qsRange = false
    return nil
end

-- Quickslottable == what ESO's own ITEMFILTERTYPE_QUICKSLOT tab accepts, which is the
-- same predicate already backing GridPad's Consumables tab.
function GPI:IsQuickslottableItem(item)
    if not item or item.isCraftBag or item.isEquipped then return false end
    if item.bagId ~= BAG_BACKPACK then return false end
    return IsConsumableItemType(item.itemType) == true
end

function GPI:QuickslotHoldEligible()
    if self.bankMode or self.selZone ~= "grid" then return false end
    local item = self:GetSelectedItem()
    if not self:IsQuickslottableItem(item) then return false end
    return true, item
end

-- NOTE deliberately absent: a TryNativeQuickslotUI handoff used to live here. Pushing
-- ESO's gamepad_quickslot scene from addon code taints the keybind closures the scene
-- creates, so the native Assign button fails with "callstack became untrusted 1 stack
-- frame(s) from the top" (seen live, AssignableUtilityWheel_Gamepad.lua:310). Do not
-- bring it back -- the in-addon picker + CallSecureProtected is the only path that works.

function GPI:BeginQuickslotAssignment(item)
    if not item then return end
    local first, last, hotbar = self:GetQuickslotRange()
    if not first then
        self:Verdict(true, "Can't find the quickslot bar -- run /gpi quickslot and send me the output.")
        return
    end

    -- Native UI unavailable: use GridPad's own picker. This is also the safer route for
    -- the actual assignment -- SelectSlotItem is a protected function, and picking a row
    -- puts the call inside a real button press rather than the hold timer.
    local opts = {}
    for slot = first, last do
        -- rawName + iconPath: the wheel draws the icon in position and reads the name
        -- out above on selection, matching the game's modal.
        table.insert(opts, { rawName = self:ProbeSlot(slot, hotbar),
                             iconPath = self:SlotIcon(slot, hotbar),
                             value = slot, quickslot = true })
    end
    if #opts == 0 then
        self:Verdict(true, "No quickslots available to assign to.")
        return
    end

    self.diffPickItem = item
    self:OpenQuickslotWheel(opts)
end

-- ===================== Radial quickslot wheel =====================
-- Replicates the shape of ESO's utility wheel so a slot's on-screen position matches
-- where it lives on the real wheel, instead of a numbered list the player has to map in
-- their head.
--
-- Slot angles: ESO's gamepad wheel puts slot 1 at the LEFT (9 o'clock) and advances
-- CLOCKWISE (up-left next, then up, and so on). I have not verified that convention in
-- the current client, so it is a saved-variables setting rather than a constant:
--   /gpi wheel start <left|top|right|bottom>   /gpi wheel dir <cw|ccw>
-- rotate the layout live with no rebuild. Filled slots draw their item name, so a
-- mismatch is visible at a glance against the real wheel.
local WHEEL_START_ANGLES = { left = 180, top = 90, right = 0, bottom = 270 }

function GPI:GetWheelLayout()
    local sv = self.sv or {}
    local start = WHEEL_START_ANGLES[sv.wheelStart or "left"] or 180
    local dir = (sv.wheelDir == "ccw") and 1 or -1  -- screen y grows downward; -1 = clockwise
    return start, dir
end

function GPI:WheelSlotAngle(i, count)
    local start, dir = self:GetWheelLayout()
    return math.rad(start + dir * (i - 1) * (360 / count))
end

function GPI:SlotIcon(slot, hotbar)
    local link
    if GetSlotItemLink then
        link = (hotbar ~= nil) and SafeCall(GetSlotItemLink, slot, hotbar)
                                or SafeCall(GetSlotItemLink, slot)
    end
    if type(link) == "string" and link ~= "" and GetItemLinkIcon then
        local icon = SafeCall(GetItemLinkIcon, link)
        if type(icon) == "string" and icon ~= "" then return icon end
    end
    if GetSlotTexture then
        local icon = (hotbar ~= nil) and SafeCall(GetSlotTexture, slot, hotbar)
                                      or SafeCall(GetSlotTexture, slot)
        if type(icon) == "string" and icon ~= "" then return icon end
    end
    return nil
end

function GPI:OpenQuickslotWheel(opts)
    self.diffPickOptions = opts
    self.diffPickIndex = 1
    self.diffPickKind = "quickslot"

    local R, NODE = 150, 64
    local W = R * 2 + NODE + 90
    local H = R * 2 + NODE + 140

    if not self.qsWheel then
        self.qsWheel = self:CreateFramedBackdrop("GridPadInventoryQSWheel", self.window, "window")
        self.qsWheel:SetDrawTier(DT_HIGH)
        self.qsWheelNodes = {}
        self.qsWheelTitle = self:CreateLabel("GridPadInventoryQSWheelTitle", self.qsWheel,
            "ZoFontGamepadBold27", 1.00, 0.79, 0.30, 1)
        self.qsWheelTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        -- Selected slot's contents, spelled out above the wheel like the game's modal.
        self.qsWheelName = self:CreateLabel("GridPadInventoryQSWheelName", self.qsWheel,
            "ZoFontGamepad27", 0.95, 0.93, 0.80, 1)
        self.qsWheelName:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end

    self.qsWheel:ClearAnchors()
    self.qsWheel:SetAnchor(CENTER, self.window, CENTER, 0, 0)
    self.qsWheel:SetDimensions(W, H)

    self.qsWheelTitle:ClearAnchors()
    self.qsWheelTitle:SetAnchor(TOP, self.qsWheel, TOP, 0, 14)
    self.qsWheelTitle:SetDimensions(W - 40, 30)
    self.qsWheelTitle:SetText("ASSIGN TO QUICKSLOT")

    self.qsWheelName:ClearAnchors()
    self.qsWheelName:SetAnchor(TOP, self.qsWheel, TOP, 0, 46)
    self.qsWheelName:SetDimensions(W - 40, 30)

    local cy = 34 -- wheel center sits below the two text lines
    for i = 1, math.max(#opts, #self.qsWheelNodes) do
        local node = self.qsWheelNodes[i]
        if not node and i <= #opts then
            node = self:CreateFramedBackdrop("GridPadInventoryQSWheelNode" .. i, self.qsWheel, "panel")
            local tex = WINDOW_MANAGER:CreateControl(nil, node, CT_TEXTURE)
            tex:SetAnchor(TOPLEFT, node, TOPLEFT, 6, 6)
            tex:SetAnchor(BOTTOMRIGHT, node, BOTTOMRIGHT, -6, -6)
            if tex.SetDrawLevel then tex:SetDrawLevel(2) end
            node.icon = tex
            self.qsWheelNodes[i] = node
        end
        if node then
            if i <= #opts then
                local ang = self:WheelSlotAngle(i, #opts)
                node:ClearAnchors()
                node:SetAnchor(CENTER, self.qsWheel, CENTER,
                    math.floor(R * math.cos(ang) + 0.5),
                    cy - math.floor(R * math.sin(ang) + 0.5))
                node:SetDimensions(NODE, NODE)
                node:SetHidden(false)
            else
                node:SetHidden(true)
            end
        end
    end

    self.diffPickOpen = true
    self.qsWheelMode = true
    self.qsWheel:SetHidden(false)
    self:RenderQuickslotWheel()
end

function GPI:RenderQuickslotWheel()
    if not self.qsWheelMode or not self.diffPickOptions then return end
    for i, o in ipairs(self.diffPickOptions) do
        local node = self.qsWheelNodes[i]
        if node then
            local sel = (i == self.diffPickIndex)
            local hasIcon = (type(o.iconPath) == "string" and o.iconPath ~= "")
            if node.icon then
                if hasIcon then
                    node.icon:SetTexture(o.iconPath)
                    node.icon:SetHidden(false)
                    -- Selected: full colour. Unselected: dimmed, like the game's wheel.
                    if sel then node.icon:SetColor(1, 1, 1, 1) else node.icon:SetColor(0.62, 0.65, 0.70, 0.95) end
                else
                    node.icon:SetHidden(true) -- empty slot: frame only, no guessed texture
                end
            end
            if sel then
                node:SetCenterColor(0.13, 0.24, 0.33, 1)
                node:SetEdgeColor(0.45, 0.95, 1.00, 1)
            else
                node:SetCenterColor(0.05, 0.06, 0.08, 0.95)
                node:SetEdgeColor(hasIcon and 0.38 or 0.24, hasIcon and 0.41 or 0.26, hasIcon and 0.48 or 0.31, 1)
            end
        end
    end
    local cur = self.diffPickOptions[self.diffPickIndex]
    local what = (cur and cur.rawName and cur.rawName ~= "") and cur.rawName or "Empty Slot"
    self.qsWheelName:SetText("|cAEB4BE" .. tostring(what) .. "|r")
end

function GPI:HideQuickslotWheel()
    self.qsWheelMode = nil
    if self.qsWheel then self.qsWheel:SetHidden(true) end
end

function GPI:ConfirmQuickslotPick(opt)
    local item = self.diffPickItem
    self.diffPickItem = nil
    if not opt or not item then return end
    local _, _, hotbar = self:GetQuickslotRange()
    if SafeGlobalKind("CallSecureProtected") ~= "function" then
        self:Verdict(true, "This client has no secure bridge, so add-ons cannot set quickslots.")
        return
    end

    local attempts, ok, err = {}, false, nil
    local function try(label, ...)
        if ok then return end
        local args = { ... }
        local good, e = pcall(function() CallSecureProtected("SelectSlotItem", unpack(args)) end)
        attempts[#attempts + 1] = label .. "=" .. (good and "ok" or tostring(e))
        if good then ok = true else err = e end
    end

    if hotbar ~= nil then
        try("withHotbar", item.bagId, item.slotIndex, opt.value, hotbar)
    end
    try("noHotbar", item.bagId, item.slotIndex, opt.value)

    -- Record the outcome so /gpi quickslot's saved report shows whether the assignment
    -- path works on this client, without the player transcribing an error.
    if self.sv then
        self.sv.lastAssign = string.format("slot=%s hotbar=%s ok=%s [%s]",
            tostring(opt.value), tostring(hotbar), tostring(ok), table.concat(attempts, " | "))
    end

    if ok then
        self:Verdict(false, "Quickslotted " .. tostring(item.name or "item") .. ".")
        return
    end

    -- A protected-function refusal is a different problem from a bad slot, and the
    -- player should be told which so the next step is obvious.
    if type(err) == "string" and err:find("private function") then
        self:Verdict(true, "ESO blocked the quickslot call (protected). /gpi quickslot has details.")
    else
        self:Verdict(true, "Quickslot failed: " .. table.concat(attempts, " | "))
    end
end

function GPI:RingHoldEligible()
    if self.bankMode or self.selZone ~= "grid" then return false end
    local item = self:GetSelectedItem()
    if not item or not item.isEquippable then return false end
    local ring2 = ConstantValue("EQUIP_SLOT_RING2")
    if ring2 == nil or not DoesEquipSlotUseItem then return false end
    return SafeCall(DoesEquipSlotUseItem, ring2, item) == true, item
end

function GPI:BeginRingHold()
    local token = (self.ringHoldToken or 0) + 1
    self.ringHoldToken = token
    self.ringHold = { token = token, fired = false }
    zo_callLater(function()
            local s = self.ringHold
            if s and s.token == token and not s.fired then
                s.fired = true
                if self:RingHoldEligible() then
                    self.forceEquipSlotVar = "EQUIP_SLOT_RING2"
                    self:UseSelected("ringhold")
                    self.forceEquipSlotVar = nil
                elseif self:QuickslotHoldEligible() then
                    self.quickslotHoldFired = true
                    self:BeginQuickslotAssignment(self:GetSelectedItem())
                end
                self.ringHold = nil
            end
        end, RING_HOLD_MS)
end

function GPI:HandleKeyUp(keyCode)
    if not self:IsShowing() then return false end
    if self:IsNativeDialogShowing() then
        self:SetInputCaptureEnabled(false)
        return false
    end
    self:BuildKeyCodeActions()
    if KEYCODE_ACTIONS[keyCode] ~= "PRIMARY" then return false end
    local s = self.ringHold
    if s and not s.fired then
        self.ringHold = nil
        self:UseSelected("ringtap") -- released early: normal tap equip
        return true
    elseif s then
        self.ringHold = nil -- hold already equipped Ring 2; swallow the release
        return true
    end
    return false
end

function GPI:HandleKeyCode(keyCode)
    if not self:IsShowing() then return false end
    self:BuildKeyCodeActions()
    local action = KEYCODE_ACTIONS[keyCode]
    if not action then return false end

    return self:RunInputAction(action, "keycode")
end

function GPI:InstallInputHook()
    if self.inputHookInstalled then return end
    self.inputHookInstalled = true

    if ZO_PreHook and ZO_KeybindStrip_HandleKeybindDown then
        ZO_PreHook("ZO_KeybindStrip_HandleKeybindDown", function(...)
            local argCount = select("#", ...)
            for i = 1, argCount do
                local value = select(i, ...)
                if type(value) == "string" and self:HandleShortcut(value) then
                    return true
                end
            end
            return false
        end)
    end
end

function GPI:InstallSceneHooks()
    if self.sceneHooksInstalled then return end
    if not SCENE_MANAGER or not SCENE_MANAGER.GetScene then return end

    local hooked = false
    for i = 1, #INVENTORY_SCENE_NAMES do
        local sceneName = INVENTORY_SCENE_NAMES[i]
        local scene = SafeCall(function() return SCENE_MANAGER:GetScene(sceneName) end)
        if scene and scene.RegisterCallback then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING then
                    if self.autoReplaceGamepadInventory then
                        self:Show(true)
                    end
                elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    if self.openedFromInventoryScene then
                        self:Hide(true)
                    end
                end
            end)
            hooked = true
        end
    end

    self.sceneHooksInstalled = hooked
    if not hooked and zo_callLater then
        zo_callLater(function()
            self.sceneHooksInstalled = false
            self:InstallSceneHooks()
        end, 1500)
    end
end

function GPI:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:CreateUI()
    self:InstallInputHook()
    self:InstallSceneHooks()

    -- Load saved variables now so the first inventory open reflects them. The LAM
    -- settings-menu panel registers separately on a deferred event (settings file),
    -- since LibAddonMenu must be fully initialized before we register with it.
    if self.InitSettings then self:InitSettings() end

    SLASH_COMMANDS["/gpi"] = function(arg)
        local lower = (arg or ""):lower()

        do
            local bankArg = lower:match("^%s*bank%s+(%a+)%s*$")
            if bankArg == "off" or bankArg == "on" then
                if not self.sv then self:InitSettings() end
                self.sv.bankTakeoverDisabled = (bankArg == "off") or nil
                AddChatMessage("[GridPad] bank takeover " .. (bankArg == "off" and "DISABLED -- native bank UI will be used at bankers." or "enabled.") .. " Type /reloadui to apply cleanly.")
                return
            elseif lower:match("^%s*bank%s*$") then
                AddChatMessage("[GridPad] bank takeover is " .. ((self.sv and self.sv.bankTakeoverDisabled) and "OFF (native bank UI)" or "ON") .. ". Usage: /gpi bank <on|off> then /reloadui.")
                return
            end
        end

        do
            local lvl = lower:match("^%s*diag%s+(%d)%s*$")
            if lvl then
                if not self.sv then self:InitSettings() end
                self.sv.diagLevel = tonumber(lvl)
                AddChatMessage("[GridPad] diagnostic level set to " .. lvl .. ". Type /reloadui to apply it fully.")
                return
            elseif lower:match("^%s*diag%s*$") then
                AddChatMessage("[GridPad] diag level is " .. tostring(self:DiagLevel()) .. ". Usage: /gpi diag <0|1|2> then /reloadui. 0/1=normal (the Jul 2026 scene-hide fix is permanent), 2=minimal zoning handlers (diagnostic only).")
                return
            end
        end

        -- /gpi wheel start <left|top|right|bottom> / dir <cw|ccw> -- rotate the wheel
        -- layout live if the default (slot 1 left, clockwise) is wrong on this client.
        do
            local k, v = (arg or ""):match("^%s*wheel%s+(%S+)%s+(%S+)%s*$")
            if k == "start" and WHEEL_START_ANGLES[v] then
                if not self.sv then self:InitSettings() end
                self.sv.wheelStart = v
                AddChatMessage("[GridPad] wheel slot 1 now at: " .. v)
                return
            elseif k == "dir" and (v == "cw" or v == "ccw") then
                if not self.sv then self:InitSettings() end
                self.sv.wheelDir = v
                AddChatMessage("[GridPad] wheel direction: " .. v)
                return
            elseif (arg or ""):match("^%s*wheel") then
                AddChatMessage("[GridPad] /gpi wheel start <left|top|right|bottom>  |  /gpi wheel dir <cw|ccw>")
                return
            end
        end

        -- Diagnostics inspect globals that may be protected, so a failure here must
        -- surface as a message rather than a Lua traceback in the user's face.
        if lower:match("^%s*quickslots?%s*$") or lower:match("^%s*lam%s*$")
            or lower:match("^%s*icons%s*$") then
            local ok, err = pcall(function() self:RunDiagnostic(lower) end)
            if not ok then
                AddChatMessage("[GridPad] Diagnostic failed: " .. tostring(err))
            end
            return
        end

        -- /gpi icon <key> <path|text> -- try a path live; the choice persists.
        do
            local key, value = (arg or ""):match("^%s*icon%s+(%S+)%s+(%S+)%s*$")
            if key and value then
                local bar, found = self:GetActiveIconBar(), false
                for i = 1, #bar do if bar[i].key == key then found = true break end end
                if not found then
                    AddChatMessage("No tab '" .. key .. "' in the active row. Use /gpi icons to list keys.")
                    return
                end
                if not self.sv then self:InitSettings() end
                self.sv.iconOverrides = self.sv.iconOverrides or {}
                self.sv.iconOverrides[key] = value
                self._iconsDirty = true
                if self:IsShowing() then self:Render() end
                AddChatMessage("Tab '" .. key .. "' -> " .. (value == "text" and "text label" or value))
                AddChatMessage("If it shows a white square the path is wrong. /gpi icon " .. key .. " text reverts.")
                return
            end
        end

        if (arg or ""):lower():match("^%s*hunt%s*$") then
            -- Diagnostic: list visible top-level controls intersecting the top band
            -- where the phantom card appears. Paste the chat output back to debug.
            local gui = GuiRoot
            local sw, sh = gui:GetWidth(), gui:GetHeight()
            AddChatMessage("Controls visible in the top band:")
            local found = 0
            for i = 1, gui:GetNumChildren() do
                local c = gui:GetChild(i)
                if c and c.IsHidden and not c:IsHidden() then
                    local alpha = (c.GetAlpha and c:GetAlpha()) or 1
                    if alpha > 0.05 then
                        local ok, l, t, r, b = pcall(function()
                            return c:GetLeft(), c:GetTop(), c:GetRight(), c:GetBottom()
                        end)
                        if ok and l and r and t and b
                            and r > sw * 0.18 and l < sw * 0.50 and t < sh * 0.10 and b > 2 then
                            local name = (c.GetName and c:GetName()) or "?"
                            if name ~= "" and not tostring(name):find("GridPad") then
                                found = found + 1
                                AddChatMessage(string.format("%s  [%d,%d -> %d,%d] a=%.2f",
                                    tostring(name), l, t, r, b, alpha))
                            end
                        end
                    end
                end
            end
            if found == 0 then AddChatMessage("(none found -- band may be a child control; tell me)") end
            return
        end
        if (arg or ""):lower():match("^%s*safebank%s*$") then
            GPI.safeBankChrome = not GPI.safeBankChrome
            if GPI.safeBankChrome then GPI:RestoreBankChrome() end
            GPI:Verdict(false, "Safe bank mode " .. (GPI.safeBankChrome and "ON (native chrome untouched)" or "OFF") .. ".")
            if GPI.bankMode and GPI:IsShowing() then GPI:Render() end
            return
        end
        arg = string.lower(arg or "")
        local command, rest = arg:match("^(%S+)%s*(.-)$")
        command = command or arg
        rest = rest or ""
        if command == "auto" then
            self.autoReplaceGamepadInventory = not self.autoReplaceGamepadInventory
            AddChatMessage("auto replacement is now " .. (self.autoReplaceGamepadInventory and "ON" or "OFF") .. ".")
            return
        elseif command == "compare" then
            self:ToggleCompare()
            return
        elseif command == "info" then
            self.showItemInfo = not self.showItemInfo
            if self:IsShowing() then self:Render() end
            AddChatMessage("Item info panel: " .. (self.showItemInfo and "ON" or "OFF"))
            return
        elseif command == "simple" or command == "view" then
            self:ToggleSimpleView()
            AddChatMessage("View: " .. (self.simpleView and "Simple (compact)" or "Full") .. ".")
            return
        elseif command == "pos" or command == "position" then
            local p = (rest or ""):lower()
            local map = { top = "top", upper = "top", center = "center", centre = "center", middle = "center", bottom = "bottom", lower = "bottom" }
            local val = map[p]
            if val then
                if self.sv then self.sv.simplePosition = val end
                self:ApplyLayout()
                if self:IsShowing() then self:Render() end
                AddChatMessage("Simple view position: " .. val .. " (right-aligned).")
            else
                AddChatMessage("Usage: /gpi pos <top|center|bottom>  (current: " .. tostring(self.sv and self.sv.simplePosition or "center") .. ")")
            end
            return
        elseif command == "opacity" or command == "alpha" then
            local v = tonumber(rest)
            if v and v >= 30 and v <= 100 then
                if self.sv then self.sv.simpleOpacity = v / 100 end
                self:ApplyLayout()
                if self:IsShowing() then self:Render() end
                AddChatMessage("Simple view opacity set to " .. tostring(math.floor(v)) .. "%.")
            else
                local cur = (self.sv and self.sv.simpleOpacity or 0.85) * 100
                AddChatMessage("Usage: /gpi opacity <30-100>  (current: " .. tostring(math.floor(cur + 0.5)) .. "%)")
            end
            return
        elseif command == "cmp" then
            -- Live-tune the ESO Style Compare card layout so it lines up exactly with
            -- the native bars on your resolution. Usage: /gpi cmp <x|w|gap|top|bottom> <n>
            local key, numStr = rest:match("^(%S+)%s+(%S+)$")
            local n = tonumber(numStr)
            local map = { x = "cmpColX", w = "cmpColW", gap = "cmpColGap", top = "cmpTopY", bottom = "cmpBottomGap" }
            local field = key and map[key:lower()]
            if field and n then
                if self.sv then self.sv[field] = math.floor(n + 0.5) end
                if self.compareOpen then self:ShowCompare(true) end
                AddChatMessage("Compare " .. key:lower() .. " set to " .. tostring(math.floor(n + 0.5)) .. ".")
            else
                local s = self.sv or {}
                AddChatMessage("ESO Compare layout -- usage: /gpi cmp <x|w|gap|top|bottom> <number>")
                AddChatMessage(string.format("  x=%d  w=%d  gap=%d  top=%d  bottom=%d",
                    s.cmpColX or 60, s.cmpColW or 540, s.cmpColGap or 8, s.cmpTopY or 90, s.cmpBottomGap or 96))
                AddChatMessage("  x = left edge of card 1, w = card width, gap = space between cards,")
                AddChatMessage("  top = top edge, bottom = space reserved for the control bar.")
            end
            return
        elseif command == "frost" then
            local v = tonumber(rest)
            if v and v >= 0 and v <= 80 then
                if self.sv then self.sv.simpleFrost = v / 100 end
                if self:IsShowing() then self:Render() end
                AddChatMessage("Simple view frost set to " .. tostring(math.floor(v)) .. "%.")
            else
                local cur = (self.sv and self.sv.simpleFrost or 0.35) * 100
                AddChatMessage("Usage: /gpi frost <0-80>  (current: " .. tostring(math.floor(cur + 0.5)) .. "%)")
            end
            return
        elseif command == "tippad" then
            local pad = tonumber(rest)
            if pad and pad >= 0 and pad <= 60 then
                self.tipPad = math.floor(pad)
                self:ApplyTooltipChrome(self.itemTooltip)
                self:ApplyTooltipChrome(self.hoverTooltip)
                if self.compareTips then
                    for i = 1, 3 do self:ApplyTooltipChrome(self.compareTips[i]) end
                end
                if self:IsShowing() then self:Render() end
                AddChatMessage("Tooltip box margin set to " .. tostring(self.tipPad) .. " per side.")
            else
                AddChatMessage("Usage: /gpi tippad <0-60> (current: " .. tostring(self.tipPad or 26) .. ")")
            end
            return
        elseif command == "tipscale" then
            local value = tonumber(rest)
            if value and value >= 0.8 and value <= 1.6 then
                self.tipScale = value
                self:ApplyTooltipLayout()
                self:Render()
                AddChatMessage("item tooltip scale set to " .. tostring(value) .. ".")
            else
                AddChatMessage("usage: /gpi tipscale <0.8 - 1.6>   (current: " .. tostring(self.tipScale or 1.1) .. ")")
            end
            return
        elseif command == "debug" then
            self.debugMode = not self.debugMode
            AddChatMessage("live debug trace is now " .. (self.debugMode and "ON" or "OFF") .. ".")
            if self.debugLabel then self.debugLabel:SetText("") end
            return
        elseif command == "test" then
            -- Runs the exact same path as pressing A, but from chat -- this bypasses
            -- ALL controller/keybind machinery. If /gpi test equips but A does not,
            -- the problem is input routing, not the equip call.
            AddChatMessage("Running equip/use test on the selected item...")
            self:UseSelected("slash-test")
            return
        elseif command == "log" then
            local log = self.equipLog or {}
            if #log == 0 then
                AddChatMessage("Equip log is empty. Select an item and press A (or /gpi test) first.")
            else
                AddChatMessage("--- Equip log (" .. #log .. " lines) ---")
                for i = 1, #log do AddChatMessage(i .. ". " .. log[i]) end
            end
            return
        elseif command == "view" then
            self:SetSimpleView(not self.simpleView)
            AddChatMessage("view is now " .. (self.simpleView and "SIMPLE" or "FULL") .. ".")
            return
        elseif command == "equipped" or command == "worn" then
            self.showEquippedInGrid = not self.showEquippedInGrid
            AddChatMessage("worn gear inside the grid is now " .. (self.showEquippedInGrid and "ON" or "OFF") .. ". (The character panel on the left always shows equipped gear.)")
            self:Refresh()
            return
        elseif command == "cover" or command == "popup" or command == "modal" then
            self.coverNativeInventory = not self.coverNativeInventory
            AddChatMessage("native inventory cover is now " .. (self.coverNativeInventory and "ON" or "OFF") .. ".")
            if self:IsShowing() and self.modal then
                self.modal:SetHidden(not self.coverNativeInventory)
            end
            return
        elseif command == "native" or command == "chrome" then
            self.hideNativeControls = not self.hideNativeControls
            AddChatMessage("native inventory chrome hiding is now " .. (self.hideNativeControls and "ON" or "OFF") .. ".")
            if self:IsShowing() then
                if self.hideNativeControls then self:HideNativeInventoryChrome() else self:RestoreNativeInventoryChrome() end
            end
            return
        elseif command == "tooltip" or command == "nativetooltip" then
            self.useNativeTooltip = not self.useNativeTooltip
            AddChatMessage("embedded native item tooltip is now " .. (self.useNativeTooltip and "ON (full standard-UI item data)" or "OFF (compact GridPad summary)") .. ".")
            if not self.useNativeTooltip and self.itemTooltip then
                pcall(function() self.itemTooltip:ClearLines() end)
                self.itemTooltip:SetHidden(true)
            end
            self:Render()
            return
        elseif command == "keys" or command == "keybinds" then
            self.showKeybindStrip = not self.showKeybindStrip
            AddChatMessage("GridPad keybind strip visuals are now " .. (self.showKeybindStrip and "ON" or "OFF") .. ". The internal keybind group stays active for A/use/equip.")
            if self:IsShowing() then
                self:AddKeybindStrip()
                if not self.showKeybindStrip then self:HideNativeInventoryChrome(true) end
            end
            return
        elseif command == "filter" then
            self:SetFilter(rest)
            return
        elseif command == "seen" or command == "dismissnew" then
            if self:IsShowing() then
                self:DismissAllNew()
            else
                AddChatMessage("Open Grid Pad first, then type /gpi seen to clear every new-item marker.")
            end
            return
        elseif command == "filters" then
            AddChatMessage("filters: " .. self:GetFilterListText())
            return
        end
        self:ToggleWindow()
    end
    SLASH_COMMANDS["/gridpad"] = SLASH_COMMANDS["/gpi"]

    do
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "InventorySlot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
            -- Looting mats routes them straight into BAG_VIRTUAL; mark the cached
            -- craft bag stale so the tab rebuilds next time it is shown.
            if BAG_VIRTUAL ~= nil and bagId == BAG_VIRTUAL then self:InvalidateCraftBag() end
            self:ScheduleRefresh()
        end)
        if EVENT_INVENTORY_FULL_UPDATE then
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "InventoryFull", EVENT_INVENTORY_FULL_UPDATE, function()
                self:InvalidateCraftBag()
                self:ScheduleRefresh()
            end)
        end
    end

    do
        -- Zoning safety: a load screen tears the whole UI down. If ANY of our
        -- native-chrome suppression or bank state is alive at that moment (e.g.
        -- teleporting away while browsing a banker), restore everything and go
        -- fully idle BEFORE the teardown. Cheap, idempotent insurance.
        do
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Deactivated", EVENT_PLAYER_DEACTIVATED, function()
                GPI.zoning = true -- gates all control/chrome/refresh work until PLAYER_ACTIVATED
                if GPI:DiagLevel() >= 2 then
                    -- diag 2: bare-minimum teardown -- flag + hide our own window only.
                    GPI.bankMode = nil
                    GPI.bankHandoff = nil
                    if GPI.bankFrame then SafeCall(function() GPI.bankFrame:SetHidden(true) end) end
                    if GPI:IsShowing() then SafeCall(function() GPI:Hide(true) end) end
                    return
                end
                SafeCall(function() GPI:StopDialogWatch() end)
                GPI.bankMode = nil
                GPI.bankHandoff = nil
                GPI.bankChromeReleased = nil
                GPI.bankDialogPoll = nil
                GPI.bankChromeDeferred = nil
                GPI.bankDialogSeenAt = nil
                SafeCall(function() GPI:StopBankChromeBeat() end)
                SafeCall(function() GPI:RemoveBankKeybinds() end)
                SafeCall(function() GPI:HideBankConfirm() end)
                SafeCall(function() GPI:RestoreBankChrome() end)
                if GPI.selZone == "bankgrid" then GPI.selZone = "grid" end
                if GPI.bankFrame then SafeCall(function() GPI.bankFrame:SetHidden(true) end) end
                if GPI:IsShowing() then SafeCall(function() GPI:Hide(true) end) end
            end)
        end
        do
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Activated", EVENT_PLAYER_ACTIVATED, function()
                -- Post-load: same cleanup, in case anything re-registered mid-load.
                GPI.zoning = false
                GPI.bankMode = nil
                if GPI:DiagLevel() >= 2 then
                    -- diag 2: no post-load chrome or tooltip work at all.
                    GPI.deferredCurrencyRestore = nil
                    return
                end
                SafeCall(function() GPI:RestoreBankChrome() end)
                -- If Hide() ran during the pre-load teardown, the native currency
                -- relayout was deferred to here, where the tooltip system is stable.
                if GPI.deferredCurrencyRestore then
                    GPI.deferredCurrencyRestore = nil
                    if GAMEPAD_TOOLTIPS and GAMEPAD_LEFT_TOOLTIP then
                        pcall(function() GAMEPAD_TOOLTIPS:LayoutCurrencies(GAMEPAD_LEFT_TOOLTIP) end)
                    end
                end
            end)
        end
        do
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "OpenBank", EVENT_OPEN_BANK, function(_, bankBag)
                -- Quarantine switch (/gpi bank off): leave the entire banker
                -- interaction to the native UI. GridPad's bank takeover is the one
                -- subsystem still implicated in load-screen AppHangs (Aug 2026).
                if GPI.sv and GPI.sv.bankTakeoverDisabled then return end
                -- Only the player bank (house storage keeps the native UI for now).
                if BAG_BANK ~= nil and bankBag ~= BAG_BANK then return end
                GPI.bankMode = true
                -- One-time-per-session pointer to the currency strip, which is easy
                -- to miss: it sits above the bank grid and is reached with UP.
                if not GPI.bankCurrencyHintShown then
                    GPI.bankCurrencyHintShown = true
                    zo_callLater(function()
                        if GPI.bankMode and GPI:IsShowing() then
                            GPI:Alert(false, "Deposit/withdraw gold: LEFT into the bank, UP past its top row, A on a currency.")
                        end
                    end, 600)
                end
                GPI.bankIndex = 1
                GPI.bankPage = 0
                GPI:HideInfoPopup()
                if not GPI:IsShowing() then GPI:Show(false) end
                GPI:AddBankKeybinds()
                -- Steady heartbeat: re-assert chrome suppression every 500ms while
                -- banking, defeating any native re-show regardless of its timing.
                do
                    SafeCall(function()
                        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "BankChromeBeat", 125, function()
                            if GPI.bankMode and GPI:IsShowing() then
                                GPI:EnforceBankChromeHidden()
                            end
                        end)
                    end)
                end
                GPI:HideNativeInventoryChrome(true)
                zo_callLater(function()
                    if GPI.bankMode and GPI:IsShowing() then GPI:HideNativeInventoryChrome(true) end
                end, 250)
                GPI:Refresh()
            end)
        end
        if EVENT_CURRENCY_UPDATE then
            -- Keeps the strip's carried/banked readouts and the open transfer
            -- panel live while banking, whatever moved the currency.
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CurrencyUpdate", EVENT_CURRENCY_UPDATE, function()
                if not (GPI.bankMode and GPI:IsShowing()) then return end
                if GPI.curPanelOpen then GPI:RenderCurrencyPanel() end
                GPI:Render()
            end)
        end
        do
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CloseBank", EVENT_CLOSE_BANK, function()
                GPI.bankMode = nil
                GPI.bankHandoff = nil
                GPI:StopBankChromeBeat()
                GPI:RemoveBankKeybinds()
                GPI:HideBankConfirm()
                GPI:HideCurrencyPanel()
                if GPI.selZone == "bankgrid" or GPI.selZone == "bankcurrency" then GPI.selZone = "grid" end
                if GPI.bankFrame then GPI.bankFrame:SetHidden(true) end
                GPI:RestoreBankChrome()
                if GPI:IsShowing() then GPI:Hide(true) end
            end)
        end
        -- (A previously registered overland-difficulty event was removed: it does
        -- not exist in the API. The difficulty label refreshes with the panel.)
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "VetDiff", EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, function()
            GPI:UpdateCharacterPanel()
        end)
        if EVENT_INVENTORY_BOUGHT_BAG_SPACE then
            -- Fires with the number of slots gained once the server accepts a
            -- BuyBagSpaceFromInventory() purchase -- the authoritative success
            -- signal for the Upgrade Bag Space confirm.
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "BoughtBagSpace", EVENT_INVENTORY_BOUGHT_BAG_SPACE, function(_, numSlots)
                local size = SafeCall(GetBagSize, BAG_BACKPACK) or 0
                local gained = (type(numSlots) == "number" and numSlots > 0) and string.format(" (+%d)", numSlots) or ""
                GPI:Verdict(false, string.format("Bag upgraded to %d slots%s.", size, gained))
                if GPI:IsShowing() then GPI:Refresh() end
            end)
        end
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "GamepadMode", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
            self:InstallSceneHooks()
        end)
    end

    AddChatMessage("v" .. self.version .. " loaded.")
end

function GridPadInventory.Toggle()
    if GPI.Initialize and not GPI.initialized then GPI:Initialize() end
    GPI:ToggleWindow()
end

-- v1.4.1: the v1.3.0 control remap only touched the gamepad-shortcut and raw-keycode
-- paths. Physical LB/RB/LT/RT that arrive as KEYBOARD keys (Steam Input) bound in
-- ESO Controls land HERE, on the bindable actions -- so the remap must live here too.
-- Action names are unchanged on purpose: existing key bindings keep working.
-- Physical intent: LB/RB = filters, LT = page cycle, RT = compare.

ZO_CreateStringId("SI_BINDING_NAME_GPI_TOGGLE", "Toggle Grid Pad")
ZO_CreateStringId("SI_BINDING_NAME_GPI_MOVE_LEFT", "GridPad Move Left")
ZO_CreateStringId("SI_BINDING_NAME_GPI_MOVE_RIGHT", "GridPad Move Right")
ZO_CreateStringId("SI_BINDING_NAME_GPI_MOVE_UP", "GridPad Move Up")
ZO_CreateStringId("SI_BINDING_NAME_GPI_MOVE_DOWN", "GridPad Move Down")
ZO_CreateStringId("SI_BINDING_NAME_GPI_PAGE_PREVIOUS", "GridPad LB: Prev Filter")
ZO_CreateStringId("SI_BINDING_NAME_GPI_PAGE_NEXT", "GridPad RB: Next Filter")
ZO_CreateStringId("SI_BINDING_NAME_GPI_FILTER_PREVIOUS", "GridPad LT: Item Info")
ZO_CreateStringId("SI_BINDING_NAME_GPI_FILTER_NEXT", "GridPad RT: Compare")
ZO_CreateStringId("SI_BINDING_NAME_GPI_USE_SELECTED", "GridPad Use / Equip Selected")
ZO_CreateStringId("SI_BINDING_NAME_GPI_COMPARE", "GridPad Compare Selected vs Equipped")
ZO_CreateStringId("SI_BINDING_NAME_GPI_TOGGLE_JUNK", "GridPad Toggle Junk")
ZO_CreateStringId("SI_BINDING_NAME_GPI_LINK_SELECTED", "GridPad Link Selected Item")
ZO_CreateStringId("SI_BINDING_NAME_GPI_CLOSE", "GridPad Close")

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        GPI:Initialize()
    end
end)
