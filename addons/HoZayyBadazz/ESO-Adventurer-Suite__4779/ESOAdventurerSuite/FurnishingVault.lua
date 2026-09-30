-- ESO Adventurer Suite
-- v0.29.617 - dedicated Furnishing Vault Suite grid.
-- ESO keeps ownership of the Furnishing Vault scene, tabs, search, filters, sort,
-- capacity and secure inventory state. This module only replaces the visible item
-- rows with the same collapsible Suite icon-grid treatment used by House Storage.
-- No private inventory-transfer APIs are referenced here.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER or not EVENT_MANAGER then return end

local U = EPC.BankGridUnifiedV2
local wm = WINDOW_MANAGER
local ADDON = EPC.name or "ESOAdventurerSuite"
local NAME = ADDON .. "_FurnishingVaultGrid029617"
local CELL, GAP, HEADER_H = 48, 5, 28
local MAX_CELLS, MAX_HEADERS = 320, 64

local root
local cells, headers = {}, {}
local collapsed = { WITHDRAW = {}, DEPOSIT = {} }
local scroll = { WITHDRAW = 0, DEPOSIT = 0 }
local cachedItems = { WITHDRAW = nil, DEPOSIT = nil }
local cachedSignature = { WITHDRAW = nil, DEPOSIT = nil }
local emptyPasses = { WITHDRAW = 0, DEPOSIT = 0 }
local nativeVisualState = setmetatable({}, { __mode = "k" })
local currentMode, activeNativeList
local contentHeight = 0
local sessionGeneration, refreshGeneration = 0, 0
local render

local function call1(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function fragmentShown(fragment)
    if not fragment then return false end
    if type(fragment.IsShowing) == "function" then
        local ok, shown = pcall(fragment.IsShowing, fragment)
        if ok and shown == true then return true end
    end
    if type(fragment.GetState) == "function" then
        local ok, state = pcall(fragment.GetState, fragment)
        if ok then
            return state == rawget(_G, "SCENE_FRAGMENT_SHOWING")
                or state == rawget(_G, "SCENE_FRAGMENT_SHOWN")
        end
    end
    return false
end

local function inventoryData(inventoryType)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" or inventoryType == nil then return nil end
    local data = manager.inventories[inventoryType]
    return type(data) == "table" and data or nil
end

local function inventoryList(inventoryType, fallbackName)
    local data = inventoryData(inventoryType)
    if data then
        return data.listView or data.list or data.scrollList or rawget(_G, fallbackName)
    end
    return rawget(_G, fallbackName)
end

local function withdrawList()
    return inventoryList(rawget(_G, "INVENTORY_FURNITURE_VAULT"), "ZO_FurnitureVaultList")
end

local function depositList()
    return inventoryList(rawget(_G, "INVENTORY_BACKPACK"), "ZO_PlayerInventoryList")
end

local function vaultActive()
    if fragmentShown(rawget(_G, "BACKPACK_FURNITURE_VAULT_LAYOUT_FRAGMENT")) then return true end
    if fragmentShown(rawget(_G, "FURNITURE_VAULT_FRAGMENT")) then return true end

    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) == "table" and type(manager.inventories) == "table" then
        for _, inventoryType in ipairs({ rawget(_G, "INVENTORY_BACKPACK"), rawget(_G, "INVENTORY_FURNITURE_VAULT") }) do
            local data = inventoryType ~= nil and manager.inventories[inventoryType] or nil
            if type(data) == "table" and tostring(data.currentContext or "") == "furnitureVaultTextSearch" then
                return true
            end
        end
    end

    local sm = rawget(_G, "SCENE_MANAGER")
    if sm and type(sm.IsShowing) == "function" then
        local ok, shown = pcall(sm.IsShowing, sm, "furnitureVault")
        if ok and shown == true then return true end
    end
    return false
end

local function modeAndList()
    if not vaultActive() then return nil, nil end

    -- ESO's Furnishing Vault is fragment-driven. Prefer these over selectedTabType,
    -- which can lag while changing Withdraw/Deposit.
    if fragmentShown(rawget(_G, "FURNITURE_VAULT_FRAGMENT")) then
        return "WITHDRAW", withdrawList()
    end
    if fragmentShown(rawget(_G, "INVENTORY_FRAGMENT")) then
        return "DEPOSIT", depositList()
    end

    local manager = rawget(_G, "PLAYER_INVENTORY")
    local selected = type(manager) == "table" and tonumber(manager.selectedTabType) or nil
    local vaultType = tonumber(rawget(_G, "INVENTORY_FURNITURE_VAULT"))
    local backpackType = tonumber(rawget(_G, "INVENTORY_BACKPACK"))
    if selected ~= nil and vaultType ~= nil and selected == vaultType then return "WITHDRAW", withdrawList() end
    if selected ~= nil and backpackType ~= nil and selected == backpackType then return "DEPOSIT", depositList() end

    if currentMode == "DEPOSIT" then return "DEPOSIT", depositList() end
    return "WITHDRAW", withdrawList()
end

local function high(control, level)
    if not control then return end
    local tier = rawget(_G, "DT_HIGH")
    local layer = rawget(_G, "DL_OVERLAY")
    if tier ~= nil and type(control.SetDrawTier) == "function" then pcall(control.SetDrawTier, control, tier) end
    if layer ~= nil and type(control.SetDrawLayer) == "function" then pcall(control.SetDrawLayer, control, layer) end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 1200) end
end

local function addUnique(out, seen, control)
    if control == nil or seen[control] then return end
    seen[control] = true
    out[#out + 1] = control
end

local function nativeVisualControls(mode)
    local out, seen = {}, {}
    if mode == "WITHDRAW" then
        local list = withdrawList()
        addUnique(out, seen, list)
        addUnique(out, seen, rawget(_G, "ZO_FurnitureVaultList"))
        addUnique(out, seen, rawget(_G, "ZO_FurnitureVaultListContents"))
    elseif mode == "DEPOSIT" then
        local list = depositList()
        addUnique(out, seen, list)
        addUnique(out, seen, rawget(_G, "ZO_PlayerInventoryList"))
        addUnique(out, seen, rawget(_G, "ZO_PlayerInventoryListContents"))
    end
    return out
end

local function isRootAncestor(control)
    if not root or not control then return false end
    local node = root
    for _ = 1, 20 do
        if node == control then return true end
        if type(node.GetParent) ~= "function" then break end
        local ok, parent = pcall(node.GetParent, node)
        if not ok or not parent or parent == node then break end
        node = parent
    end
    return false
end

local function suppressNativeVisuals(mode)
    if not vaultActive() then return end
    for _, control in ipairs(nativeVisualControls(mode)) do
        if control and not isRootAncestor(control) then
            if nativeVisualState[control] == nil then
                local alpha, mouseEnabled = 1, true
                if type(control.GetAlpha) == "function" then
                    local ok, value = pcall(control.GetAlpha, control)
                    if ok and tonumber(value) then alpha = tonumber(value) end
                end
                if type(control.IsMouseEnabled) == "function" then
                    local ok, value = pcall(control.IsMouseEnabled, control)
                    if ok then mouseEnabled = value == true end
                end
                nativeVisualState[control] = { alpha = alpha, mouseEnabled = mouseEnabled }
            end
            if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 0) end
            if type(control.SetMouseEnabled) == "function" then pcall(control.SetMouseEnabled, control, false) end
        end
    end
end

local function restoreNativeVisuals()
    for control, state in pairs(nativeVisualState) do
        if control and type(control.SetAlpha) == "function" then
            pcall(control.SetAlpha, control, tonumber(state.alpha) or 1)
        end
        if control and type(control.SetMouseEnabled) == "function" then
            pcall(control.SetMouseEnabled, control, state.mouseEnabled == true)
        end
        nativeVisualState[control] = nil
    end
end

local function nativeSlotData(bag, slot)
    local shared = rawget(_G, "SHARED_INVENTORY")
    if type(shared) ~= "table" or type(shared.GetOrCreateBagCache) ~= "function" then return nil end
    local ok, cache = pcall(shared.GetOrCreateBagCache, shared, bag)
    if not ok or type(cache) ~= "table" then return nil end
    return cache[slot]
end

local function tableHasValue(values, wanted)
    if type(values) ~= "table" or wanted == nil then return false end
    for _, value in pairs(values) do
        if value == wanted then return true end
    end
    return false
end

local function isVaultEligible(bag, slot, link)
    local furnishingFilter = rawget(_G, "ITEMFILTERTYPE_FURNISHING")
    local slotData = nativeSlotData(bag, slot)
    if slotData and tableHasValue(slotData.filterData, furnishingFilter) then return true end

    if furnishingFilter ~= nil and type(rawget(_G, "GetItemFilterTypeInfo")) == "function" then
        local ok, a, b, c, d, e, f = pcall(GetItemFilterTypeInfo, bag, slot)
        if ok and tableHasValue({ a, b, c, d, e, f }, furnishingFilter) then return true end
    end

    local furnishingType = tonumber(rawget(_G, "ITEMTYPE_FURNISHING"))
    if furnishingType ~= nil and type(rawget(_G, "GetItemType")) == "function" then
        local itemType = tonumber(call1(GetItemType, -1, bag, slot))
        if itemType == furnishingType then return true end
    end

    link = tostring(link or "")
    if link == "" and type(rawget(_G, "GetItemLink")) == "function" then
        link = tostring(call1(GetItemLink, "", bag, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
    end
    local placeable = rawget(_G, "IsItemLinkPlaceableFurniture")
    if link ~= "" and type(placeable) == "function" then
        local ok, yes = pcall(placeable, link)
        if ok and yes == true then return true end
    end
    return false
end

local function categoryForLink(link)
    link = tostring(link or "")
    if link ~= "" then
        local dataId = tonumber(call1(rawget(_G, "GetItemLinkFurnitureDataId"), 0, link)) or 0
        if dataId > 0 and type(rawget(_G, "GetFurnitureDataCategoryInfo")) == "function" then
            local ok, categoryId, subcategoryId = pcall(GetFurnitureDataCategoryInfo, dataId)
            if ok and type(rawget(_G, "GetFurnitureCategoryName")) == "function" then
                if categoryId ~= nil then
                    local category = tostring(call1(GetFurnitureCategoryName, "", categoryId) or "")
                    if category ~= "" then return category end
                end
                if subcategoryId ~= nil then
                    local subcategory = tostring(call1(GetFurnitureCategoryName, "", subcategoryId) or "")
                    if subcategory ~= "" then return subcategory end
                end
            end
        end
    end

    local grid = rawget(_G, "EASInventoryGrid")
    if grid and type(grid.GetExternalGroupName029364) == "function" then
        local ok, group = pcall(grid.GetExternalGroupName029364, grid, link)
        if ok and tostring(group or "") ~= "" then return tostring(group) end
    end
    return "Furnishings"
end

local function buildItem(bag, slot, data)
    bag, slot = tonumber(bag), tonumber(slot)
    if bag == nil or slot == nil then return nil end

    local link = type(data) == "table" and tostring(data.itemLink or data.link or data.itemLinkString or "") or ""
    if link == "" and type(rawget(_G, "GetItemLink")) == "function" then
        link = tostring(call1(GetItemLink, "", bag, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
    end
    if link == "" then return nil end

    local icon, stack, _, _, locked, _, _, quality
    if type(rawget(_G, "GetItemInfo")) == "function" then
        local ok
        ok, icon, stack, _, _, locked, _, _, quality = pcall(GetItemInfo, bag, slot)
        if not ok then icon, stack, locked, quality = nil, nil, false, nil end
    end

    local name = tostring(call1(rawget(_G, "GetItemName"), "", bag, slot) or (type(data) == "table" and data.name) or "")
    stack = tonumber(stack) or (type(data) == "table" and tonumber(data.stackCount)) or tonumber(call1(rawget(_G, "GetSlotStackSize"), 1, bag, slot)) or 1
    quality = tonumber(quality) or (type(data) == "table" and tonumber(data.displayQuality)) or tonumber(call1(rawget(_G, "GetItemDisplayQuality"), 0, bag, slot)) or 0

    return {
        bag = bag,
        slot = slot,
        link = link,
        name = name,
        icon = tostring(icon or (type(data) == "table" and data.iconFile) or ""),
        stack = stack,
        quality = quality,
        locked = locked == true or (type(data) == "table" and data.locked == true),
        group = categoryForLink(link),
    }
end

local function collectFromNative(list, mode)
    local items = {}
    local getData = rawget(_G, "ZO_ScrollList_GetDataList")
    if not list or type(getData) ~= "function" then return items, false end

    local ok, dataList = pcall(getData, list)
    if not ok or type(dataList) ~= "table" then return items, false end

    for _, entry in ipairs(dataList) do
        local data = type(entry) == "table" and (entry.data or entry) or nil
        if type(data) == "table"
            and not data.easSuiteFurnitureVaultHeader029591
            and not data.easSuiteCategoryHeader029364
            and not data.easSuiteCategoryHeader029376 then
            local bag = tonumber(data.bagId or data.bag)
            local slot = tonumber(data.slotIndex or data.slot)
            if bag ~= nil and slot ~= nil then
                local item = buildItem(bag, slot, data)
                if item and (mode ~= "DEPOSIT" or isVaultEligible(bag, slot, item.link)) then
                    items[#items + 1] = item
                end
            end
        end
    end
    return items, true
end

local function collectFallback(mode)
    local items = {}
    local bag = mode == "WITHDRAW" and rawget(_G, "BAG_FURNITURE_VAULT") or rawget(_G, "BAG_BACKPACK")
    if bag == nil or type(rawget(_G, "GetBagSize")) ~= "function" then return items end

    local size = tonumber(call1(GetBagSize, 0, bag)) or 0
    for slot = 0, size - 1 do
        local item = buildItem(bag, slot)
        if item and (mode ~= "DEPOSIT" or isVaultEligible(bag, slot, item.link)) then
            items[#items + 1] = item
        end
    end
    table.sort(items, function(a, b)
        if a.group ~= b.group then return string.lower(a.group) < string.lower(b.group) end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return string.lower(a.name) < string.lower(b.name)
    end)
    return items
end

local function itemSignature(items)
    local parts = {}
    for i, item in ipairs(items) do
        parts[i] = tostring(item.bag) .. ":" .. tostring(item.slot) .. ":" .. tostring(item.stack)
            .. ":" .. tostring(item.quality) .. ":" .. tostring(item.group)
    end
    return table.concat(parts, "|")
end

local function qualityColor(q)
    local colorType = rawget(_G, "INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS")
    if type(rawget(_G, "GetInterfaceColor")) == "function" and colorType ~= nil then
        local ok, r, g, b = pcall(GetInterfaceColor, colorType, tonumber(q) or 0)
        if ok and r ~= nil then return r, g, b end
    end
    return .35, .42, .50
end

local function ensureRoot(list)
    if not list then return false end
    local parent = type(list.GetParent) == "function" and call1(list.GetParent, GuiRoot, list) or GuiRoot
    if not parent then parent = GuiRoot end

    if not root then
        root = wm:CreateControl(NAME, parent, CT_CONTROL)
        root:SetMouseEnabled(true)
        high(root, 1200)
        root:SetHandler("OnMouseWheel", function(_, delta)
            if not vaultActive() or not currentMode then return end
            local height = tonumber(call1(root.GetHeight, 0, root)) or 0
            local maxScroll = math.max(0, contentHeight - height + 4)
            local nextValue = (tonumber(scroll[currentMode]) or 0) - (tonumber(delta) or 0) * 110
            scroll[currentMode] = math.max(0, math.min(nextValue, maxScroll))
            if cachedItems[currentMode] and activeNativeList and type(render) == "function" then
                cachedSignature[currentMode] = nil
                render(activeNativeList, currentMode, true, cachedItems[currentMode])
            end
        end)
    end

    if root._easVaultAnchorList029617 ~= list then
        if type(root.GetParent) == "function" and root:GetParent() ~= parent and type(root.SetParent) == "function" then
            pcall(root.SetParent, root, parent)
        end
        root:ClearAnchors()
        root:SetAnchor(TOPLEFT, list, TOPLEFT, 0, 0)
        root:SetAnchor(BOTTOMRIGHT, list, BOTTOMRIGHT, 0, 0)
        root._easVaultAnchorList029617 = list
    end
    return true
end

local function clearPool()
    for _, header in ipairs(headers) do
        header.group = nil
        if header.label then header.label:SetText("") end
        header:SetMouseEnabled(false)
        header:SetHidden(true)
    end
    for _, cell in ipairs(cells) do
        cell.item = nil
        if cell.count then cell.count:SetText("") end
        if cell.icon then cell.icon:SetTexture(nil) end
        cell:SetMouseEnabled(false)
        cell:SetHidden(true)
    end
end

local function getHeader(i)
    local header = headers[i]
    if header then return header end
    if i > MAX_HEADERS then return nil end

    header = wm:CreateControl(NAME .. "Header" .. i, root, CT_BUTTON)
    header:SetHeight(HEADER_H)
    header:SetMouseEnabled(true)
    high(header, 1220)

    local bg = wm:CreateControl(nil, header, CT_BACKDROP)
    bg:SetAnchorFill(header)
    bg:SetCenterColor(.035, .055, .08, 1)
    bg:SetEdgeColor(.35, .45, .55, 1)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 1)
    bg:SetMouseEnabled(false)

    local label = wm:CreateControl(nil, header, CT_LABEL)
    label:SetAnchor(TOPLEFT, header, TOPLEFT, 8, 3)
    label:SetAnchor(BOTTOMRIGHT, header, BOTTOMRIGHT, -4, -3)
    label:SetFont("ZoFontGameBold")
    label:SetColor(1, .82, .26, 1)
    label:SetMouseEnabled(false)
    header.label = label

    header:SetHandler("OnMouseUp", function(control, button, inside)
        if inside == false or not currentMode or not control.group then return end
        local left = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
        if left ~= nil and button ~= left then return end
        collapsed[currentMode][control.group] = not (collapsed[currentMode][control.group] == true)
        cachedSignature[currentMode] = nil
        if activeNativeList and cachedItems[currentMode] and type(render) == "function" then
            render(activeNativeList, currentMode, true, cachedItems[currentMode])
        end
    end)

    headers[i] = header
    return header
end

local function alert(stringId)
    local fn = rawget(_G, "ZO_Alert")
    if type(fn) ~= "function" or stringId == nil then return end
    local category = rawget(_G, "UI_ALERT_CATEGORY_ERROR")
    local sounds = rawget(_G, "SOUNDS")
    local negative = type(sounds) == "table" and sounds.NEGATIVE_CLICK or nil
    pcall(fn, category, negative, stringId)
end

local function openNativeTransfer(item, mode)
    if type(item) ~= "table" or not vaultActive() then return false end
    local sourceBag, sourceSlot = tonumber(item.bag), tonumber(item.slot)
    if sourceBag == nil or sourceSlot == nil then return false end

    local targetBag
    if mode == "WITHDRAW" then
        targetBag = rawget(_G, "BAG_BACKPACK")
    elseif mode == "DEPOSIT" then
        if item.locked == true or not isVaultEligible(sourceBag, sourceSlot, item.link) then return false end
        targetBag = rawget(_G, "BAG_FURNITURE_VAULT")

        local stolen = rawget(_G, "IsItemStolen")
        if type(stolen) == "function" then
            local ok, yes = pcall(stolen, sourceBag, sourceSlot)
            if ok and yes == true then
                alert(rawget(_G, "SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE"))
                return false
            end
        end

        local gemManager = rawget(_G, "CROWN_GEMIFICATION_MANAGER")
        if type(gemManager) == "table" and type(gemManager.IsItemGemmable) == "function" then
            local ok, yes = pcall(gemManager.IsItemGemmable, sourceBag, sourceSlot)
            if ok and yes == true then
                alert(rawget(_G, "SI_FURNITURE_VAULT_ERROR_GEMMABLE_FURNITURE"))
                return false
            end
        end
    else
        return false
    end

    targetBag = tonumber(targetBag)
    if targetBag == nil or targetBag == sourceBag then return false end

    local space = rawget(_G, "DoesBagHaveSpaceFor")
    if type(space) == "function" then
        local ok, hasSpace = pcall(space, targetBag, sourceBag, sourceSlot)
        if ok and hasSpace == false then
            if mode == "WITHDRAW" then
                alert(rawget(_G, "SI_INVENTORY_ERROR_INVENTORY_FULL"))
            else
                local alertEvent = rawget(_G, "ZO_AlertEvent")
                local eventCode = rawget(_G, "EVENT_BANK_IS_FULL")
                if type(alertEvent) == "function" and eventCode ~= nil then pcall(alertEvent, eventCode) end
            end
            return false
        end
    end

    local systems = rawget(_G, "SYSTEMS")
    if (type(systems) ~= "table" and type(systems) ~= "userdata") or type(systems.GetObject) ~= "function" then return false end
    local ok, dialog = pcall(systems.GetObject, systems, "ItemTransferDialog")
    if not ok or not dialog or type(dialog.StartTransfer) ~= "function" then return false end
    local started = pcall(dialog.StartTransfer, dialog, sourceBag, sourceSlot, targetBag)
    return started == true
end

local function bindCell(control, mode)
    if not control or type(control.item) ~= "table" then return false end
    local slotType = mode == "WITHDRAW" and rawget(_G, "SLOT_TYPE_FURNITURE_VAULT") or rawget(_G, "SLOT_TYPE_ITEM")
    if slotType == nil then return false end
    local bind = rawget(_G, "ZO_Inventory_BindSlot")
    if type(bind) == "function" then
        pcall(bind, control, slotType, control.item.slot, control.item.bag)
    else
        control.slotType, control.slotIndex, control.bagId = slotType, control.item.slot, control.item.bag
    end
    return true
end

local function getStringSafe(stringId)
    local fn = rawget(_G, "GetString")
    if stringId == nil or type(fn) ~= "function" then return "" end
    local ok, text = pcall(fn, stringId)
    return ok and tostring(text or "") or ""
end

local function patchTransferMenu(control, mode)
    local menu = rawget(_G, "ZO_Menu")
    if (type(menu) ~= "table" and type(menu) ~= "userdata") or type(menu.items) ~= "table" then return end

    local wanted
    if mode == "DEPOSIT" then
        wanted = getStringSafe(rawget(_G, "SI_ITEM_ACTION_BANK_DEPOSIT"))
    else
        wanted = getStringSafe(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG"))
    end
    if wanted == "" then return end

    for _, entry in ipairs(menu.items) do
        local menuControl = type(entry) == "table" and entry.item or nil
        local label = menuControl and menuControl.nameLabel
        local text = label and type(label.GetText) == "function" and tostring(label:GetText() or "") or ""
        if text == wanted then
            local callback = function()
                if type(control.item) == "table" then openNativeTransfer(control.item, mode) end
            end
            if type(entry) == "table" then
                entry.callback = callback
                entry.OnSelect = callback
            end
            if menuControl then
                menuControl.callback = callback
                menuControl.OnSelect = callback
                if type(menuControl.SetHandler) == "function" then
                    pcall(menuControl.SetHandler, menuControl, "OnClicked", callback)
                end
            end
            break
        end
    end
end

local function getCell(i)
    local cell = cells[i]
    if cell then return cell end
    if i > MAX_CELLS then return nil end

    cell = wm:CreateControl(NAME .. "Cell" .. i, root, CT_BUTTON)
    cell:SetDimensions(CELL, CELL)
    cell:SetMouseEnabled(true)
    high(cell, 1250)

    local bg = wm:CreateControl(nil, cell, CT_BACKDROP)
    bg:SetAnchorFill(cell)
    bg:SetCenterColor(.06, .07, .09, 1)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 2)
    bg:SetMouseEnabled(false)
    cell.bg = bg

    local icon = wm:CreateControl(nil, cell, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 3, 3)
    icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -3, -3)
    icon:SetTextureCoords(.05, .95, .05, .95)
    icon:SetMouseEnabled(false)
    cell.icon = icon

    local count = wm:CreateControl(nil, cell, CT_LABEL)
    count:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -2, -1)
    count:SetDimensions(28, 14)
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetFont("ZoFontGameSmall")
    count:SetColor(1, 1, 1, 1)
    count:SetMouseEnabled(false)
    cell.count = count

    cell:SetHandler("OnMouseEnter", function(control)
        if control.item and ItemTooltip and type(rawget(_G, "InitializeTooltip")) == "function" then
            InitializeTooltip(ItemTooltip, control, LEFT, -8, 0, RIGHT)
            if type(ItemTooltip.SetBagItem) == "function" then
                pcall(ItemTooltip.SetBagItem, ItemTooltip, control.item.bag, control.item.slot)
            end
        end
    end)
    cell:SetHandler("OnMouseExit", function()
        if ItemTooltip and type(rawget(_G, "ClearTooltip")) == "function" then pcall(ClearTooltip, ItemTooltip) end
    end)
    cell:SetHandler("OnMouseUp", function(control, button, inside)
        if inside == false or type(control.item) ~= "table" or not currentMode then return end
        local left = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
        local right = rawget(_G, "MOUSE_BUTTON_INDEX_RIGHT")
        if button == left then
            openNativeTransfer(control.item, currentMode)
        elseif button == right then
            bindCell(control, currentMode)
            local showMenu = rawget(_G, "ZO_InventorySlot_ShowContextMenu")
            if type(showMenu) == "function" then
                local ok = pcall(showMenu, control)
                if ok then patchTransferMenu(control, currentMode) end
            end
        end
    end)

    cells[i] = cell
    return cell
end

render = function(list, mode, allowEmpty, suppliedItems)
    if not list or not mode then return false end

    local items, nativeReadable
    if suppliedItems then
        items, nativeReadable = suppliedItems, true
    else
        items, nativeReadable = collectFromNative(list, mode)
        if not nativeReadable then items = collectFallback(mode) end
    end

    if #items == 0 then
        emptyPasses[mode] = (tonumber(emptyPasses[mode]) or 0) + 1
        if allowEmpty ~= true then
            if cachedItems[mode] then
                items = cachedItems[mode]
            else
                return false
            end
        elseif emptyPasses[mode] < 2 then
            return false
        else
            clearPool()
            if root then root:SetHidden(true) end
            cachedItems[mode], cachedSignature[mode] = nil, nil
            activeNativeList, currentMode = list, mode
            suppressNativeVisuals(mode)
            return false
        end
    else
        emptyPasses[mode] = 0
        cachedItems[mode] = items
    end

    if not ensureRoot(list) then return false end
    local signature = itemSignature(items)
    if currentMode == mode and activeNativeList == list and cachedSignature[mode] == signature and not root:IsHidden() then
        suppressNativeVisuals(mode)
        return true
    end

    activeNativeList, currentMode = list, mode
    cachedSignature[mode] = signature
    clearPool()
    root:SetHidden(false)
    root:SetAlpha(1)
    root:SetMouseEnabled(true)
    high(root, 1200)

    local groups, order = {}, {}
    for _, item in ipairs(items) do
        if not groups[item.group] then
            groups[item.group] = {}
            order[#order + 1] = item.group
        end
        groups[item.group][#groups[item.group] + 1] = item
    end
    table.sort(order, function(a, b) return string.lower(tostring(a)) < string.lower(tostring(b)) end)

    local width = tonumber(call1(root.GetWidth, 500, root)) or 500
    local height = tonumber(call1(root.GetHeight, 0, root)) or 0
    local cols = math.max(4, math.floor((width - 16) / (CELL + GAP)))
    local offset = tonumber(scroll[mode]) or 0
    local y, headerIndex, cellIndex = 0, 0, 0

    for _, group in ipairs(order) do
        headerIndex = headerIndex + 1
        local headerY = y - offset
        local header = getHeader(headerIndex)
        if header then
            header.group = group
            header.label:SetText((collapsed[mode][group] and "+  " or "-  ") .. group .. "  (" .. tostring(#groups[group]) .. ")")
            header:ClearAnchors()
            header:SetAnchor(TOPLEFT, root, TOPLEFT, 4, headerY)
            header:SetWidth(width - 12)
            local visible = height <= 0 or (headerY >= 0 and headerY + HEADER_H <= height)
            header:SetHidden(not visible)
            header:SetMouseEnabled(visible)
            high(header, 1220)
        end
        y = y + HEADER_H + GAP

        if not collapsed[mode][group] then
            local rows = math.ceil(#groups[group] / cols)
            for i, item in ipairs(groups[group]) do
                cellIndex = cellIndex + 1
                if cellIndex > MAX_CELLS then break end
                local cell = getCell(cellIndex)
                if not cell then break end

                cell.item = item
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cellY = y + row * (CELL + GAP) - offset
                cell:ClearAnchors()
                cell:SetAnchor(TOPLEFT, root, TOPLEFT, 4 + col * (CELL + GAP), cellY)
                cell.icon:SetTexture(item.icon ~= "" and item.icon or "EsoUI/Art/Icons/icon_missing.dds")
                cell.count:SetText(item.stack > 1 and tostring(item.stack) or "")
                local r, g, b = qualityColor(item.quality)
                cell.bg:SetEdgeColor(r, g, b, 1)
                local visible = height <= 0 or (cellY >= 0 and cellY + CELL <= height)
                cell:SetHidden(not visible)
                cell:SetMouseEnabled(visible)
                high(cell, 1250)
            end
            y = y + rows * (CELL + GAP) + GAP
        end
    end

    contentHeight = y
    local maxScroll = math.max(0, contentHeight - height + 4)
    if offset > maxScroll then
        scroll[mode] = maxScroll
        cachedSignature[mode] = nil
        return render(list, mode, true, items)
    end

    suppressNativeVisuals(mode)
    return true
end

local function reserveVault()
    if not U then return end
    U._suiteBankActive029539 = false
    U.specialStorageNative029558 = rawget(_G, "INVENTORY_FURNITURE_VAULT")
    U.furnishingVaultSuiteExclusive029617 = true
    U.furnishingVaultSuiteGrid029577 = false
    U.furnishingVaultDeposit029576 = false
    if U.root and type(U.root.SetHidden) == "function" then pcall(U.root.SetHidden, U.root, true) end
end

local function refreshNow(allowEmpty)
    if not vaultActive() then return end
    reserveVault()
    local mode, list = modeAndList()
    if not mode or not list then return end
    render(list, mode, allowEmpty)
    suppressNativeVisuals(mode)
end

local function scheduleRefresh()
    if not vaultActive() then return end
    refreshNow(false)

    refreshGeneration = refreshGeneration + 1
    local mineRefresh = refreshGeneration
    local mineSession = sessionGeneration
    if type(rawget(_G, "zo_callLater")) ~= "function" then return end

    for _, pass in ipairs({ { 35, false }, { 90, false }, { 180, true }, { 340, true } }) do
        local delay, allowEmpty = pass[1], pass[2]
        zo_callLater(function()
            if mineSession == sessionGeneration and mineRefresh == refreshGeneration and vaultActive() then
                refreshNow(allowEmpty)
            end
        end, delay)
    end
end

local manager = rawget(_G, "PLAYER_INVENTORY")
if type(manager) == "table" and type(rawget(_G, "ZO_PostHook")) == "function" then
    for _, methodName in ipairs({ "UpdateList", "ChangeFilter", "ChangeSort" }) do
        if type(manager[methodName]) == "function" then
            pcall(ZO_PostHook, manager, methodName, function()
                if vaultActive() then scheduleRefresh() end
            end)
        end
    end
end

for _, fragmentName in ipairs({
    "FURNITURE_VAULT_FRAGMENT",
    "INVENTORY_FRAGMENT",
    "BACKPACK_FURNITURE_VAULT_LAYOUT_FRAGMENT",
}) do
    local fragment = rawget(_G, fragmentName)
    if fragment and type(fragment.RegisterCallback) == "function" then
        fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_FRAGMENT_SHOWING")
                or newState == rawget(_G, "SCENE_FRAGMENT_SHOWN") then
                if vaultActive() then scheduleRefresh() end
            end
        end)
    end
end

local sm = rawget(_G, "SCENE_MANAGER")
if sm and type(sm.GetScene) == "function" then
    local scene = sm:GetScene("furnitureVault")
    if scene and type(scene.RegisterCallback) == "function" then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_SHOWING") or newState == rawget(_G, "SCENE_SHOWN") then
                sessionGeneration = sessionGeneration + 1
                refreshGeneration = refreshGeneration + 1
                scroll.WITHDRAW, scroll.DEPOSIT = 0, 0
                emptyPasses.WITHDRAW, emptyPasses.DEPOSIT = 0, 0
                reserveVault()
                scheduleRefresh()
            elseif newState == rawget(_G, "SCENE_HIDING") or newState == rawget(_G, "SCENE_HIDDEN") then
                sessionGeneration = sessionGeneration + 1
                refreshGeneration = refreshGeneration + 1
                restoreNativeVisuals()
                if U then U.furnishingVaultSuiteExclusive029617 = false end
                currentMode, activeNativeList = nil, nil
                cachedItems.WITHDRAW, cachedItems.DEPOSIT = nil, nil
                cachedSignature.WITHDRAW, cachedSignature.DEPOSIT = nil, nil
                emptyPasses.WITHDRAW, emptyPasses.DEPOSIT = 0, 0
                clearPool()
                if root then
                    root._easVaultAnchorList029617 = nil
                    root:SetHidden(true)
                end
            end
        end)
    end
end

for _, eventName in ipairs({
    "EVENT_INVENTORY_FULL_UPDATE",
    "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
    "EVENT_OPEN_BANK",
}) do
    local code = rawget(_G, eventName)
    if code ~= nil then
        EVENT_MANAGER:RegisterForEvent(NAME .. eventName, code, function()
            if vaultActive() then scheduleRefresh() end
        end)
    end
end

scheduleRefresh()
