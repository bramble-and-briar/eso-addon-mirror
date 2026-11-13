-- Quartermaster (formerly Keep My Crafts; folder and saved settings keep the old name so it updates)
-- Keeps items crafted by any of your characters (writ stock, gear you made), and set gear with a
-- trait you keep, out of the lists where they could be sold or destroyed by mistake: the merchant's
-- Sell list, deconstruction at crafting stations, and universal deconstruction (the Ragpicker
-- assistant). Click the right stick on those screens to show or hide them again; the choice is
-- remembered. Selling junk and repairing at merchants: Quartermaster.lua. Gamepad screens only,
-- which is what consoles use. On/off: enable or disable the add-on.
--
-- Hook points (from ZeniMax's published UI source, game version 12.1.6):
--   * Sell: STORE_WINDOW_GAMEPAD.components[ZO_MODE_STORE_SELL].list.updateFunc builds the list.
--   * Deconstruction: ZO_GamepadExtractionInventory and ZO_UniversalDeconstructionInventory_Gamepad
--     both put their rows on screen through AddFilteredDataToList (inherited from
--     ZO_GamepadCraftingInventory); we override it on those two subclasses only, so crafting
--     creation and improvement lists are untouched.
--   * Bank: GAMEPAD_BANKING builds its lists on first open and hands the Deposit list to
--     SetDepositList; that list's itemFilterFunction (the game's own hides stolen items) is wrapped
--     so writ stock your characters crafted (white gear, glyphs, potions, poisons) isn't offered for
--     the bank or house storage. The bank's own X button (UI_SHORTCUT_SECONDARY) is only used to
--     rename house storage, so at the bank that same descriptor is borrowed to show/hide them; adding
--     a second button on a key the game already registered would trip its duplicate-keybind check.
--   * Trade: GAMEPAD_TRADE builds its inventory list on first open (InitializeInventoryList) with
--     the game's filter (TRADE_WINDOW:CanTradeItem: not bound, stolen or locked, and dungeon drops
--     only if this partner was in the group). We add "dungeon loot only": just the bind-on-pickup
--     drops (IsItemBoPAndTradeable) this partner can take. Its button goes on the left stick inside
--     the game's own keybindStripDescriptorInventory group (that list doesn't use the left stick).
--   * Toggle button: GAMEPAD_SMITHING_DECONSTRUCT_SCENE and UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE add
--     their buttons on SCENE_SHOWING and remove them on SCENE_HIDDEN; we do the same.

local ADDON_NAME = "ESOCKeepMyCrafts"
ESOC_KeepMyCrafts = ESOC_KeepMyCrafts or {}
local WS = ESOC_KeepMyCrafts

local settings = { hide = true, hideBank = true, tradeLootOnly = true }
local myNames = nil
WS.hiddenCount = 0

local function norm(name)
    local s = name or ""
    local ok, formatted = pcall(zo_strformat, "<<1>>", s)
    if ok and type(formatted) == "string" then s = formatted end
    return s:lower()
end

-- Names of every character on this account (crafted items record the crafter's character name)
local function loadNames()
    myNames = {}
    pcall(function()
        for i = 1, GetNumCharacters() do
            local name = GetCharacterInfo(i)
            if name and name ~= "" then myNames[norm(name)] = true end
        end
    end)
    pcall(function() myNames[norm(GetUnitName("player"))] = true end)
end

function WS.IsWritStock(bagId, slotIndex)
    if not myNames then loadNames() end
    local ok, creator = pcall(GetItemCreatorName, bagId, slotIndex)
    if not ok or not creator or creator == "" then return false end
    return myNames[norm(creator)] == true
end

-- Crafted by you, or gear with a trait you keep (see Quartermaster.lua)
function WS.IsProtected(bagId, slotIndex)
    if WS.IsWritStock(bagId, slotIndex) then return true end
    local QM = ESOC_Quartermaster
    return QM ~= nil and QM.IsKept ~= nil and QM.IsKept(bagId, slotIndex) == true
end

-- Writ stock one of your characters crafted, no use in the bank: white gear, glyphs, potions, poisons.
local function isWritConsumable(itemType)
    if itemType == nil then return false end
    return itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON or itemType == ITEMTYPE_GLYPH_ARMOR
        or itemType == ITEMTYPE_GLYPH_WEAPON or itemType == ITEMTYPE_GLYPH_JEWELRY
end

function WS.IsWritGear(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= nil and (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON) then
        local ok, quality = pcall(GetItemDisplayQuality, bagId, slotIndex)
        if not ok or quality == nil or quality ~= ITEM_DISPLAY_QUALITY_NORMAL then return false end
    elseif not isWritConsumable(itemType) then
        return false
    end
    return WS.IsWritStock(bagId, slotIndex)
end

function WS.IsHiding()
    return settings.hide
end

---------------------------------------------------------------------------
-- The right-stick toggle, added next to each screen's own buttons
---------------------------------------------------------------------------
local refreshCurrent = nil
local onSellScreen = false
local toggleGroup = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = function()
            if settings.hide then
                return WS.hiddenCount > 0 and string.format("Show kept items (%d)", WS.hiddenCount) or "Show kept items"
            end
            return "Hide kept items"
        end,
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        callback = function()
            settings.hide = not settings.hide
            if refreshCurrent then pcall(refreshCurrent) end
            KEYBIND_STRIP:UpdateKeybindButtonGroup(WS.toggleGroup)
        end,
    },
    -- Sell trash: only on the merchant's Sell screen, and only when automatic selling is off
    {
        name = function()
            local QM = ESOC_Quartermaster
            local n = QM and QM.PendingCount and QM.PendingCount(WS.IsWritStock) or 0
            return n > 0 and string.format("Sell trash (%d)", n) or "Sell trash"
        end,
        keybind = "UI_SHORTCUT_LEFT_STICK",
        visible = function()
            local QM = ESOC_Quartermaster
            if not onSellScreen or not QM or not QM.Options then return false end
            if QM.Options().autoSell or QM.IsSelling() or not QM.IsAtStore() then return false end
            return QM.PendingCount(WS.IsWritStock) > 0
        end,
        callback = function()
            local QM = ESOC_Quartermaster
            if QM then QM.SellNow(WS.IsWritStock) end
            KEYBIND_STRIP:UpdateKeybindButtonGroup(WS.toggleGroup)
        end,
    },
}
WS.toggleGroup = toggleGroup

local function showToggle(refresh)
    refreshCurrent = refresh
    KEYBIND_STRIP:RemoveKeybindButtonGroup(toggleGroup)
    KEYBIND_STRIP:AddKeybindButtonGroup(toggleGroup)
end

local function hideToggle()
    refreshCurrent = nil
    KEYBIND_STRIP:RemoveKeybindButtonGroup(toggleGroup)
end

local function updateToggle()
    pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(toggleGroup) end)
end

---------------------------------------------------------------------------
-- Filtering
---------------------------------------------------------------------------
-- Removes protected items from a list of item data tables in place; returns how many were removed.
function WS.FilterInPlace(items)
    if not settings.hide then return 0 end
    local kept, removed = 0, 0
    for i = 1, #items do
        local data = items[i]
        if data and data.bagId and data.slotIndex and WS.IsProtected(data.bagId, data.slotIndex) then
            removed = removed + 1
        else
            kept = kept + 1
            items[kept] = data
        end
    end
    for i = #items, kept + 1, -1 do items[i] = nil end
    return removed
end

local function hookSell()
    local component = STORE_WINDOW_GAMEPAD and STORE_WINDOW_GAMEPAD.components
        and STORE_WINDOW_GAMEPAD.components[ZO_MODE_STORE_SELL]
    local list = component and component.list
    if not list or not list.updateFunc then return false end
    local original = list.updateFunc
    list.updateFunc = function(...)
        local items = original(...)
        WS.hiddenCount = WS.FilterInPlace(items)
        updateToggle()
        return items
    end
    component.fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_SHOWING then
            onSellScreen = true
            showToggle(function() list:UpdateList() end)
        elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_HIDING then
            onSellScreen = false
            hideToggle()
        end
    end)
    return true
end

local function wrapDepositFilter(list)
    if not list or list.esocWrapped then return end
    list.esocWrapped = true
    local function hideFromBank(slot)
        if not settings.hideBank or not slot or not slot.bagId or not slot.slotIndex then return false end
        local ok, writ = pcall(WS.IsWritGear, slot.bagId, slot.slotIndex)
        return ok and writ
    end
    local original = list.itemFilterFunction
    list.itemFilterFunction = function(slot)
        if original and not original(slot) then return false end
        return not hideFromBank(slot)
    end
    -- if the game sets its own filter again later, keep ours on top of it
    local setFilter = list.SetItemFilterFunction
    if setFilter then
        list.SetItemFilterFunction = function(self, fn)
            return setFilter(self, function(slot)
                if fn and not fn(slot) then return false end
                return not hideFromBank(slot)
            end)
        end
    end
end

-- How many backpack items the bank is (or would be) leaving out.
local function bankHiddenCount()
    local n = 0
    for slot = 0, (GetBagSize(BAG_BACKPACK) or 0) - 1 do
        local ok, writ = pcall(WS.IsWritGear, BAG_BACKPACK, slot)
        if ok and writ then n = n + 1 end
    end
    return n
end

-- Borrow the bank's X button (house-storage rename) as a show/hide toggle at the real bank.
local function wrapBankToggle(bank)
    local group = bank.mainKeybindStripDescriptor
    if type(group) ~= "table" or group.esocWrapped then return false end
    local button
    for _, b in ipairs(group) do
        if type(b) == "table" and b.keybind == "UI_SHORTCUT_SECONDARY" then button = b end
    end
    if not button then
        -- the game no longer has one: add ours (X is free on this screen then)
        button = { keybind = "UI_SHORTCUT_SECONDARY", visible = function() return false end, callback = function() end }
        group[#group + 1] = button
    end
    group.esocWrapped = true
    local function ours()
        local ok, mine = pcall(function()
            return GetBankingBag() == BAG_BANK and bank:IsInDepositMode()
        end)
        return ok and mine
    end
    local gameName, gameVisible, gameCallback = button.name, button.visible, button.callback
    button.name = function(...)
        if ours() then
            if settings.hideBank then
                local n = bankHiddenCount()
                return n > 0 and string.format("Show crafted (%d)", n) or "Show crafted"
            end
            return "Hide crafted"
        end
        if type(gameName) == "function" then return gameName(...) end
        return gameName
    end
    button.visible = function(...)
        if ours() then return true end
        if type(gameVisible) == "function" then return gameVisible(...) end
        return gameVisible ~= false
    end
    button.callback = function(...)
        if ours() then
            settings.hideBank = not settings.hideBank
            if bank.depositList and bank.depositList.RefreshList then pcall(bank.depositList.RefreshList, bank.depositList) end
            pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(group) end)
            return
        end
        if gameCallback then return gameCallback(...) end
    end
    return true
end

local function hookBank()
    local bank = GAMEPAD_BANKING
    if not bank or not bank.SetDepositList then return false end
    if bank.depositList then wrapDepositFilter(bank.depositList) end
    pcall(wrapBankToggle, bank)
    local original = bank.SetDepositList
    bank.SetDepositList = function(self, list, ...)
        local result = original(self, list, ...)
        pcall(wrapDepositFilter, list)
        pcall(wrapBankToggle, self)
        return result
    end
    return true
end

---------------------------------------------------------------------------
-- Trade: dungeon / trial loot only
---------------------------------------------------------------------------
-- A bind-on-pickup drop you can still trade, and the game would let you offer to this partner.
local function isTradeLoot(slot)
    if not slot or not slot.bagId or not slot.slotIndex then return false end
    if not IsItemBoPAndTradeable(slot.bagId, slot.slotIndex) then return false end
    if TRADE_WINDOW and TRADE_WINDOW.CanTradeItem and not TRADE_WINDOW:CanTradeItem(slot) then return false end
    if ZO_IsItemCurrentlyOfferedForTrade and ZO_IsItemCurrentlyOfferedForTrade(slot.bagId, slot.slotIndex) then return false end
    return true
end

-- How many such drops are in the backpack right now.
function WS.TradeLootCount()
    local n = 0
    for slot = 0, (GetBagSize(BAG_BACKPACK) or 0) - 1 do
        local data = { bagId = BAG_BACKPACK, slotIndex = slot }
        local ok, yes = pcall(function()
            if (GetItemId(BAG_BACKPACK, slot) or 0) == 0 then return false end
            data.stolen = IsItemStolen(BAG_BACKPACK, slot)
            data.isPlayerLocked = IsItemPlayerLocked(BAG_BACKPACK, slot)
            return isTradeLoot(data)
        end)
        if ok and yes then n = n + 1 end
    end
    return n
end

-- The filter is on only while you have dungeon loot to give; otherwise the list is the game's own.
local function tradeFilterActive()
    if not settings.tradeLootOnly then return false end
    local ok, n = pcall(WS.TradeLootCount)
    return ok and n > 0
end

local function wrapTradeFilter(list)
    if not list or list.esocWrapped then return end
    list.esocWrapped = true
    local active = false
    local function ours(slot)
        if not active then return true end
        local ok, yes = pcall(isTradeLoot, slot)
        return not ok or yes -- if anything fails, leave the item in
    end
    local function wrap(fn)
        return function(slot)
            if fn and not fn(slot) then return false end
            return ours(slot)
        end
    end
    list.itemFilterFunction = wrap(list.itemFilterFunction)
    local setFilter = list.SetItemFilterFunction
    if setFilter then
        list.SetItemFilterFunction = function(self, fn) return setFilter(self, wrap(fn)) end
    end
    -- decide once per rebuild (where the game runs the filter), not once per item
    for _, method in ipairs({ "GenerateSlotTable", "IsEmpty" }) do
        local original = list[method]
        if type(original) == "function" then
            list[method] = function(self, ...)
                active = tradeFilterActive()
                return original(self, ...)
            end
        end
    end
    active = tradeFilterActive()
end

local function addTradeButton(trade)
    local group = trade.keybindStripDescriptorInventory
    if type(group) ~= "table" or group.esocWrapped then return false end
    for _, b in ipairs(group) do
        if type(b) == "table" and b.keybind == "UI_SHORTCUT_LEFT_STICK" then return false end -- taken: don't clash
    end
    group.esocWrapped = true
    group[#group + 1] = {
        keybind = "UI_SHORTCUT_LEFT_STICK",
        name = function()
            if settings.tradeLootOnly then return "Show all items" end
            return string.format("Dungeon loot only (%d)", WS.TradeLootCount())
        end,
        visible = function()
            local ok, n = pcall(WS.TradeLootCount)
            return ok and n > 0
        end,
        callback = function()
            settings.tradeLootOnly = not settings.tradeLootOnly
            if trade.inventoryList and trade.inventoryList.RefreshList then
                pcall(trade.inventoryList.RefreshList, trade.inventoryList, true)
            end
            pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(group) end)
        end,
    }
    return true
end

local function hookTrade()
    local trade = GAMEPAD_TRADE
    if not trade or not trade.InitializeInventoryList then return false end
    pcall(addTradeButton, trade)
    if trade.inventoryList then wrapTradeFilter(trade.inventoryList) end
    local original = trade.InitializeInventoryList
    trade.InitializeInventoryList = function(self, ...)
        local result = original(self, ...)
        pcall(wrapTradeFilter, self.inventoryList)
        pcall(addTradeButton, self)
        return result
    end
    return true
end

local function hookInventoryClass(class)
    if not class then return false end
    local original = class.AddFilteredDataToList -- inherited from ZO_GamepadCraftingInventory
    class.AddFilteredDataToList = function(self, filteredDataTable)
        WS.hiddenCount = WS.FilterInPlace(filteredDataTable)
        updateToggle()
        return original(self, filteredDataTable)
    end
    return true
end

-- The deconstruction screens add their buttons straight from their scene's StateChange callback
-- (they never call their own AddKeybinds), so the toggle follows the scene too.
local function hookScene(scene, panel)
    if not scene or not scene.RegisterCallback or not panel or not panel.inventory then return false end
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            showToggle(function() panel.inventory:PerformFullRefresh() end)
        elseif newState == SCENE_HIDDEN then
            hideToggle()
        end
    end)
    return true
end

-- Called once from the add-on's load event with its saved settings table.
-- Returns the list of screens that were hooked.
function WS.Init(saved)
    if saved then
        if saved.hide == nil then saved.hide = true end
        if saved.hideBank == nil then saved.hideBank = true end
        if saved.tradeLootOnly == nil then saved.tradeLootOnly = true end
        settings = setmetatable({}, {
            __index = function(_, k) return saved[k] end,
            __newindex = function(_, k, v) saved[k] = v end,
        })
    end
    local done = {}
    local function try(label, fn)
        local ok, result = pcall(fn)
        if ok and result then done[#done + 1] = label end
    end
    try("sell", hookSell)
    try("deconstruct", function()
        local panel = SMITHING_GAMEPAD and SMITHING_GAMEPAD.deconstructionPanel
        return hookInventoryClass(ZO_GamepadExtractionInventory) and hookScene(GAMEPAD_SMITHING_DECONSTRUCT_SCENE, panel)
    end)
    try("ragpicker", function()
        local panel = UNIVERSAL_DECONSTRUCTION_GAMEPAD and UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel
        return hookInventoryClass(ZO_UniversalDeconstructionInventory_Gamepad)
            and hookScene(UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE, panel)
    end)
    try("bank", hookBank)
    try("trade", hookTrade)
    return done
end

-- When something sold or a setting changed: refresh the open list and the buttons.
local function changed()
    if refreshCurrent then pcall(refreshCurrent) end
    updateToggle()
end

local savedVars
local function makeSettings()
    local QM, LHAS = ESOC_Quartermaster, LibHarvensAddonSettings
    if not QM or not savedVars or not LHAS then return end
    QM.CreateSettings(savedVars, {
        { type = LHAS.ST_SECTION, label = "Protection" },
        {
            type = LHAS.ST_CHECKBOX, label = "Hide crafted and kept items", default = true,
            tooltip = "Hide items your characters crafted, and set gear with a kept trait, from the Sell, deconstruction and Ragpicker lists. The right stick on those screens does the same.",
            getFunction = function() return savedVars.hide end,
            setFunction = function(v) savedVars.hide = v; changed() end,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Hide crafted writ items from the bank", default = true,
            tooltip = "White gear, glyphs, potions and poisons your characters crafted are left out of the bank's Deposit list, and house storage's. At the bank, X shows or hides them.",
            getFunction = function() return savedVars.hideBank end,
            setFunction = function(v) savedVars.hideBank = v end,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Trade: dungeon loot only", default = true,
            tooltip = "When you trade with someone and have dungeon or trial drops they can take, the item list shows only those. The left stick on that list switches between them and all items.",
            getFunction = function() return savedVars.tradeLootOnly end,
            setFunction = function(v) savedVars.tradeLootOnly = v end,
        },
    })
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    local ok, result = pcall(function()
        savedVars = ZO_SavedVars:NewAccountWide("ESOCKeepMyCrafts_SV", 1, nil, {})
        local QM = ESOC_Quartermaster
        if QM then
            QM.Init(savedVars, WS.IsWritStock)
            QM.onChanged = changed
        end
        return WS.Init(savedVars)
    end)
    if not ok then
        pcall(d, "[Quartermaster] could not start: " .. tostring(result))
    elseif #result < 5 then
        pcall(d, "[Quartermaster] only partly active (" .. table.concat(result, ", ") .. "); a game update may have changed these screens")
    end
    pcall(makeSettings)
end)

-- The settings library may finish loading after us; try again once you're in the world.
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Settings", EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Settings", EVENT_PLAYER_ACTIVATED)
    pcall(makeSettings)
end)
