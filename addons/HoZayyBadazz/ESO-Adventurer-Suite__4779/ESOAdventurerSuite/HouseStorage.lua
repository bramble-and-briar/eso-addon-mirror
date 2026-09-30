-- ESO Adventurer Suite
-- v0.29.607 - House Storage single-owner stable Suite grid.
-- ESO owns filtering/search/sort and secure inventory data. This module alone owns
-- House Storage presentation: it reads native rows, renders the Suite grid, and
-- suppresses only the native row visuals after the data has been captured.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER then return end

local U = EPC.BankGridUnifiedV2
local wm = WINDOW_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_HouseStorageGrid029594"
local CELL, GAP, HEADER_H, MAX_CELLS = 48, 5, 28, 320
local MAX_HEADERS = 64

local root
local cells, headers = {}, {}
local collapsed = { WITHDRAW = {}, DEPOSIT = {} }
local scroll = { WITHDRAW = 0, DEPOSIT = 0 }
local cachedItems = { WITHDRAW = nil, DEPOSIT = nil }
local cachedSignature = { WITHDRAW = nil, DEPOSIT = nil }
local emptyPasses = { WITHDRAW = 0, DEPOSIT = 0 }
local nativeVisualState = setmetatable({}, { __mode = "k" })
local sessionGeneration = 0
local refreshGeneration = 0
local activeNativeList, currentMode
local contentHeight = 0
local render

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a, b, c, d, e
end

local function fragmentShown(fragment)
    if not fragment then return false end
    if type(fragment.IsShowing) == "function" then
        local ok, value = pcall(fragment.IsShowing, fragment)
        if ok and value == true then return true end
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

local function controlEffectivelyShown(control)
    if not control then return false end
    if type(rawget(_G, "IsControlHidden")) == "function" then
        local ok, hidden = pcall(IsControlHidden, control)
        if ok then return hidden == false end
    end
    if type(control.IsHidden) == "function" then
        return first(control.IsHidden, true, control) == false
    end
    return false
end

local function houseStorageActive()
    if fragmentShown(rawget(_G, "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT")) then return true end
    local sm = rawget(_G, "SCENE_MANAGER")
    if sm and type(sm.IsShowing) == "function" then
        local ok, value = pcall(sm.IsShowing, sm, "houseBank")
        if ok and value == true then return true end
    end
    return fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT"))
        or fragmentShown(rawget(_G, "HOUSE_BANK_MENU_FRAGMENT"))
end

local function inventoryData(inventoryType)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" or inventoryType == nil then return nil end
    local data = manager.inventories[inventoryType]
    return type(data) == "table" and data or nil
end

local function inventoryList(inventoryType, fallback)
    local data = inventoryData(inventoryType)
    if data then return data.listView or data.list or data.scrollList or rawget(_G, fallback) end
    return rawget(_G, fallback)
end

local function withdrawList()
    return inventoryList(rawget(_G, "INVENTORY_HOUSE_BANK"), "ZO_HouseBankBackpack")
end

local function depositList()
    return inventoryList(rawget(_G, "INVENTORY_BACKPACK"), "ZO_PlayerInventoryList")
end

local function modeAndList()
    local withdraw = withdrawList()
    local deposit = depositList()
    local manager = rawget(_G, "PLAYER_INVENTORY")
    local selected = type(manager) == "table" and tonumber(manager.selectedTabType) or nil
    local backpackType = tonumber(rawget(_G, "INVENTORY_BACKPACK"))
    local houseType = tonumber(rawget(_G, "INVENTORY_HOUSE_BANK"))

    if selected ~= nil then
        if backpackType ~= nil and selected == backpackType and deposit then
            return "DEPOSIT", deposit
        end
        if houseType ~= nil and selected == houseType and withdraw then
            return "WITHDRAW", withdraw
        end
    end

    local ws = controlEffectivelyShown(withdraw)
    local ds = controlEffectivelyShown(deposit)
    if ds and not ws then return "DEPOSIT", deposit end
    if ws and not ds then return "WITHDRAW", withdraw end

    if fragmentShown(rawget(_G, "INVENTORY_FRAGMENT"))
        and not fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT")) then
        return "DEPOSIT", deposit
    end
    if fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT")) then
        return "WITHDRAW", withdraw
    end

    if currentMode == "DEPOSIT" and deposit then return "DEPOSIT", deposit end
    return "WITHDRAW", withdraw
end

local function addUnique(out, seen, control)
    if control == nil or seen[control] then return end
    seen[control] = true
    out[#out + 1] = control
end

local function nativeVisualControls()
    local out, seen = {}, {}
    local manager = rawget(_G, "PLAYER_INVENTORY")

    local function addInventory(inventoryType)
        if type(manager) ~= "table" or type(manager.inventories) ~= "table" or inventoryType == nil then return end
        local data = manager.inventories[inventoryType]
        if type(data) ~= "table" then return end
        addUnique(out, seen, data.listView)
        addUnique(out, seen, data.list)
        addUnique(out, seen, data.scrollList)
    end

    addInventory(rawget(_G, "INVENTORY_HOUSE_BANK"))
    addInventory(rawget(_G, "INVENTORY_BACKPACK"))

    for _, name in ipairs({
        "ZO_HouseBankBackpack",
        "ZO_HouseBankBackpackList",
        "ZO_HouseBankBackpackListContents",
        "ZO_PlayerInventoryList",
        "ZO_PlayerInventoryListList",
        "ZO_PlayerInventoryListContents",
    }) do
        addUnique(out, seen, rawget(_G, name))
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

local function suppressNativeVisuals()
    if not houseStorageActive() then return end
    for _, control in ipairs(nativeVisualControls()) do
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

local function itemFromEntry(entry)
    local data = type(entry) == "table" and (entry.data or entry) or nil
    if type(data) ~= "table" then return nil end
    if data.easSuiteCategoryHeader029364 or data.easSuiteCategoryHeader029376
        or data.easSuiteHouseStorageHeader029592 or data.easSuiteHouseStorageHeader029594 then
        return nil
    end

    local bag = tonumber(data.bagId or data.bag)
    local slot = tonumber(data.slotIndex or data.slot)
    if bag == nil or slot == nil then return nil end

    local link = tostring(data.itemLink or data.link or data.itemLinkString or "")
    if link == "" and type(rawget(_G, "GetItemLink")) == "function" then
        link = tostring(first(GetItemLink, "", bag, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
    end
    if link == "" then return nil end

    local icon, stack, _, _, locked, _, _, quality
    if type(rawget(_G, "GetItemInfo")) == "function" then
        local ok
        ok, icon, stack, _, _, locked, _, _, quality = pcall(GetItemInfo, bag, slot)
        if not ok then icon, stack, locked, quality = nil, nil, false, nil end
    end

    local name = tostring(first(GetItemName, "", bag, slot) or data.name or "")
    stack = tonumber(stack) or tonumber(data.stackCount) or tonumber(first(GetSlotStackSize, 1, bag, slot)) or 1
    quality = tonumber(quality) or tonumber(data.displayQuality) or tonumber(first(GetItemDisplayQuality, 0, bag, slot)) or 0

    local group = "Other"
    local grid = rawget(_G, "EASInventoryGrid")
    if grid and type(grid.GetExternalGroupName029364) == "function" then
        local ok, value = pcall(grid.GetExternalGroupName029364, grid, link)
        if ok and tostring(value or "") ~= "" then group = tostring(value) end
    end

    return {
        bag = bag, slot = slot, link = link, name = name,
        icon = tostring(icon or data.iconFile or ""), stack = stack,
        quality = quality, locked = locked == true, group = group,
    }
end

local function collectFromNative(list)
    local items = {}
    if not list or type(rawget(_G, "ZO_ScrollList_GetDataList")) ~= "function" then return items end
    local ok, dataList = pcall(ZO_ScrollList_GetDataList, list)
    if not ok or type(dataList) ~= "table" then return items end

    for _, entry in ipairs(dataList) do
        local item = itemFromEntry(entry)
        if item then items[#items + 1] = item end
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
    local parent = type(list.GetParent) == "function" and list:GetParent() or GuiRoot
    if not parent then parent = GuiRoot end

    if not root then
        root = wm:CreateControl(NAME, parent, CT_CONTROL)
        root:SetMouseEnabled(true)
        if rawget(_G, "DT_HIGH") then root:SetDrawTier(DT_HIGH) end
        if rawget(_G, "DL_OVERLAY") then root:SetDrawLayer(DL_OVERLAY) end
        root:SetDrawLevel(900)
        root._easRenderHouseStorage029606 = function(listArg, modeArg, allowEmptyArg, itemsArg)
            if type(render) == "function" then
                return render(listArg, modeArg, allowEmptyArg, itemsArg)
            end
        end
        root:SetHandler("OnMouseWheel", function(_, delta)
            if not houseStorageActive() or not currentMode then return end
            local rootH = tonumber(first(root.GetHeight, 0, root)) or 0
            local maxScroll = math.max(0, contentHeight - rootH + 4)
            local nextValue = (tonumber(scroll[currentMode]) or 0) - (tonumber(delta) or 0) * 110
            scroll[currentMode] = math.max(0, math.min(nextValue, maxScroll))
            if cachedItems[currentMode] and activeNativeList then
                cachedSignature[currentMode] = nil
                render(activeNativeList, currentMode, true, cachedItems[currentMode])
            end
        end)
    end

    if root._easStorageAnchorList029607 ~= list then
        if type(root.GetParent) == "function" and root:GetParent() ~= parent and type(root.SetParent) == "function" then
            pcall(root.SetParent, root, parent)
        end
        root:ClearAnchors()
        root:SetAnchor(TOPLEFT, list, TOPLEFT, 0, 0)
        root:SetAnchor(BOTTOMRIGHT, list, BOTTOMRIGHT, 0, 0)
        root._easStorageAnchorList029607 = list
    end
    return true
end

local function clearPool()
    for _, h in ipairs(headers) do
        h.group = nil
        if h.label then h.label:SetText("") end
        h:SetMouseEnabled(false)
        h:SetHidden(true)
    end
    for _, c in ipairs(cells) do
        c.item = nil
        if c.count then c.count:SetText("") end
        if c.icon then c.icon:SetTexture(nil) end
        c:SetMouseEnabled(false)
        c:SetHidden(true)
    end
end

local function getHeader(i)
    local h = headers[i]
    if h then return h end
    if i > MAX_HEADERS then return nil end

    h = wm:CreateControl(NAME .. "Header" .. i, root, CT_BUTTON)
    h:SetHeight(HEADER_H)
    h:SetMouseEnabled(true)
    h:SetDrawLevel(920)

    local hb = wm:CreateControl(nil, h, CT_BACKDROP)
    hb:SetAnchorFill(h)
    hb:SetCenterColor(.035, .055, .08, 1)
    hb:SetEdgeColor(.35, .45, .55, 1)
    hb:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 1)

    local label = wm:CreateControl(nil, h, CT_LABEL)
    label:SetAnchor(TOPLEFT, h, TOPLEFT, 8, 3)
    label:SetAnchor(BOTTOMRIGHT, h, BOTTOMRIGHT, -4, -3)
    label:SetFont("ZoFontGameBold")
    label:SetColor(1, .82, .26, 1)
    h.label = label

    h:SetHandler("OnClicked", function(control)
        if not currentMode or not control.group then return end
        collapsed[currentMode][control.group] = not (collapsed[currentMode][control.group] == true)
        cachedSignature[currentMode] = nil
        if activeNativeList and cachedItems[currentMode] then
            render(activeNativeList, currentMode, true, cachedItems[currentMode])
        end
    end)

    headers[i] = h
    return h
end

local function currentHouseBag()
    local house = inventoryData(rawget(_G, "INVENTORY_HOUSE_BANK"))
    if house and type(house.backingBags) == "table" then return house.backingBags[1] end
    return nil
end

local function moveItem(item)
    if not item or not houseStorageActive() then return end
    if currentMode == "DEPOSIT" and item.locked then return end

    local targetBag = currentMode == "WITHDRAW" and rawget(_G, "BAG_BACKPACK") or currentHouseBag()
    if targetBag == nil or type(rawget(_G, "FindFirstEmptySlotInBag")) ~= "function" then return end

    local targetSlot = first(FindFirstEmptySlotInBag, nil, targetBag)
    if targetSlot == nil then return end
    local count = tonumber(first(GetSlotStackSize, 1, item.bag, item.slot)) or item.stack or 1

    local protected = false
    if type(rawget(_G, "IsProtectedFunction")) == "function" then
        local ok, value = pcall(IsProtectedFunction, "RequestMoveItem")
        protected = ok and value == true
    end

    if protected and type(rawget(_G, "CallSecureProtected")) == "function" then
        pcall(CallSecureProtected, "RequestMoveItem", item.bag, item.slot, targetBag, targetSlot, count)
    elseif type(rawget(_G, "RequestMoveItem")) == "function" then
        pcall(RequestMoveItem, item.bag, item.slot, targetBag, targetSlot, count)
    end
end

local function getCell(i)
    local c = cells[i]
    if c then return c end
    if i > MAX_CELLS then return nil end

    c = wm:CreateControl(NAME .. "Cell" .. i, root, CT_BUTTON)
    c:SetDimensions(CELL, CELL)
    c:SetMouseEnabled(true)
    c:SetDrawLevel(930)

    local cb = wm:CreateControl(nil, c, CT_BACKDROP)
    cb:SetAnchorFill(c)
    cb:SetCenterColor(.06, .07, .09, 1)
    cb:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 2)
    c.bg = cb

    local icon = wm:CreateControl(nil, c, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, c, TOPLEFT, 3, 3)
    icon:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -3, -3)
    icon:SetTextureCoords(.05, .95, .05, .95)
    c.icon = icon

    local count = wm:CreateControl(nil, c, CT_LABEL)
    count:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -2, -1)
    count:SetDimensions(28, 14)
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetFont("ZoFontGameSmall")
    count:SetColor(1, 1, 1, 1)
    c.count = count

    c:SetHandler("OnMouseEnter", function(control)
        if control.item and ItemTooltip and type(rawget(_G, "InitializeTooltip")) == "function" then
            InitializeTooltip(ItemTooltip, control, LEFT, -8, 0, RIGHT)
            if type(ItemTooltip.SetBagItem) == "function" then
                pcall(ItemTooltip.SetBagItem, ItemTooltip, control.item.bag, control.item.slot)
            end
        end
    end)
    c:SetHandler("OnMouseExit", function()
        if ItemTooltip and type(rawget(_G, "ClearTooltip")) == "function" then pcall(ClearTooltip, ItemTooltip) end
    end)
    c:SetHandler("OnClicked", function(control)
        if control.item then moveItem(control.item) end
    end)

    cells[i] = c
    return c
end

render = function(list, mode, allowEmpty, suppliedItems)
    if not list or not mode then return false end
    local items = suppliedItems or collectFromNative(list)

    if #items == 0 then
        emptyPasses[mode] = (tonumber(emptyPasses[mode]) or 0) + 1
        if allowEmpty ~= true then
            if cachedItems[mode] then
                items = cachedItems[mode]
            else
                -- Do not blank or swap the visible Suite grid during ESO's transient
                -- empty rebuild state. A later settled pass will decide if it is real.
                return false
            end
        elseif emptyPasses[mode] < 2 then
            return false
        elseif cachedItems[mode] and currentMode ~= mode then
            -- On a mode transition prefer the last known stable snapshot for that
            -- mode until ESO has completed at least another settled rebuild.
            items = cachedItems[mode]
        else
            clearPool()
            if root then root:SetHidden(true) end
            activeNativeList, currentMode = list, mode
            cachedItems[mode], cachedSignature[mode] = nil, nil
            return false
        end
    else
        emptyPasses[mode] = 0
        cachedItems[mode] = items
    end

    local sig = itemSignature(items)
    if not ensureRoot(list) then return false end

    if currentMode == mode and activeNativeList == list
        and cachedSignature[mode] == sig and not root:IsHidden() then
        suppressNativeVisuals()
        return true
    end

    activeNativeList, currentMode = list, mode
    cachedSignature[mode] = sig
    clearPool()
    root:SetHidden(false)

    local groups, order = {}, {}
    for _, item in ipairs(items) do
        if not groups[item.group] then
            groups[item.group] = {}
            order[#order + 1] = item.group
        end
        groups[item.group][#groups[item.group] + 1] = item
    end
    table.sort(order, function(a, b) return string.lower(a) < string.lower(b) end)

    local width = tonumber(first(root.GetWidth, 500, root)) or 500
    local rootH = tonumber(first(root.GetHeight, 0, root)) or 0
    local cols = math.max(4, math.floor((width - 16) / (CELL + GAP)))
    local offset = tonumber(scroll[mode]) or 0
    local y, headerIndex, cellIndex = 0, 0, 0

    for _, group in ipairs(order) do
        headerIndex = headerIndex + 1
        local headerY = y - offset
        local h = getHeader(headerIndex)
        if h then
            h.group = group
            h.label:SetText((collapsed[mode][group] and "+  " or "-  ") .. group .. "  (" .. #groups[group] .. ")")
            h:ClearAnchors()
            h:SetAnchor(TOPLEFT, root, TOPLEFT, 4, headerY)
            h:SetWidth(width - 12)
            local visible = rootH <= 0 or (headerY + HEADER_H > 0 and headerY < rootH)
            h:SetHidden(not visible)
            h:SetMouseEnabled(visible)
        end
        y = y + HEADER_H + GAP

        if not collapsed[mode][group] then
            local rows = math.ceil(#groups[group] / cols)
            for i, item in ipairs(groups[group]) do
                cellIndex = cellIndex + 1
                if cellIndex > MAX_CELLS then break end
                local c = getCell(cellIndex)
                if not c then break end

                c.item = item
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cellY = y + row * (CELL + GAP) - offset
                c:ClearAnchors()
                c:SetAnchor(TOPLEFT, root, TOPLEFT, 4 + col * (CELL + GAP), cellY)
                c.icon:SetTexture(item.icon ~= "" and item.icon or "EsoUI/Art/Icons/icon_missing.dds")
                c.count:SetText(item.stack > 1 and tostring(item.stack) or "")
                local r, g, b = qualityColor(item.quality)
                c.bg:SetEdgeColor(r, g, b, 1)
                local visible = rootH <= 0 or (cellY + CELL > 0 and cellY < rootH)
                c:SetHidden(not visible)
                c:SetMouseEnabled(visible)
            end
            y = y + rows * (CELL + GAP) + GAP
        end
    end

    contentHeight = y
    local maxScroll = math.max(0, contentHeight - rootH + 4)
    if offset > maxScroll then
        scroll[mode] = maxScroll
        cachedSignature[mode] = nil
        return render(list, mode, true, items)
    end

    suppressNativeVisuals()
    return true
end

local function refreshNow(allowEmpty)
    if not houseStorageActive() then return end

    if U then
        U._suiteBankActive029539 = false
        U.specialStorageNative029558 = rawget(_G, "INVENTORY_HOUSE_BANK")
        if U.root and type(U.root.SetHidden) == "function" then pcall(U.root.SetHidden, U.root, true) end
    end

    local mode, list = modeAndList()
    if not list then return end
    render(list, mode, allowEmpty)
    suppressNativeVisuals()
end

local function scheduleRefresh()
    if not houseStorageActive() then return end

    -- Same-call refresh captures ESO's rebuilt data and suppresses the native rows
    -- before they can visually own a full frame.
    refreshNow(false)

    refreshGeneration = refreshGeneration + 1
    local mineRefresh = refreshGeneration
    local mineSession = sessionGeneration
    if type(rawget(_G, "zo_callLater")) ~= "function" then return end

    for _, pass in ipairs({ { 35, false }, { 90, false }, { 180, true }, { 340, true } }) do
        local delay, allowEmpty = pass[1], pass[2]
        zo_callLater(function()
            if mineSession == sessionGeneration and mineRefresh == refreshGeneration and houseStorageActive() then
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
                if houseStorageActive() then scheduleRefresh() end
            end)
        end
    end
end

for _, fragmentName in ipairs({
    "HOUSE_BANK_FRAGMENT",
    "INVENTORY_FRAGMENT",
    "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT",
}) do
    local fragment = rawget(_G, fragmentName)
    if fragment and type(fragment.RegisterCallback) == "function" then
        fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_FRAGMENT_SHOWING")
                or newState == rawget(_G, "SCENE_FRAGMENT_SHOWN") then
                if houseStorageActive() then scheduleRefresh() end
            end
        end)
    end
end

local sm = rawget(_G, "SCENE_MANAGER")
if sm and type(sm.GetScene) == "function" then
    local scene = sm:GetScene("houseBank")
    if scene and type(scene.RegisterCallback) == "function" then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_SHOWING") or newState == rawget(_G, "SCENE_SHOWN") then
                sessionGeneration = sessionGeneration + 1
                refreshGeneration = refreshGeneration + 1
                scroll.WITHDRAW, scroll.DEPOSIT = 0, 0
                emptyPasses.WITHDRAW, emptyPasses.DEPOSIT = 0, 0
                scheduleRefresh()
            elseif newState == rawget(_G, "SCENE_HIDING") or newState == rawget(_G, "SCENE_HIDDEN") then
                sessionGeneration = sessionGeneration + 1
                refreshGeneration = refreshGeneration + 1
                restoreNativeVisuals()
                activeNativeList, currentMode = nil, nil
                cachedItems.WITHDRAW, cachedItems.DEPOSIT = nil, nil
                cachedSignature.WITHDRAW, cachedSignature.DEPOSIT = nil, nil
                emptyPasses.WITHDRAW, emptyPasses.DEPOSIT = 0, 0
                clearPool()
                if root then
                    root._easStorageAnchorList029607 = nil
                    root:SetHidden(true)
                end
            end
        end)
    end
end

if EVENT_MANAGER then
    local prefix = NAME .. "Events"
    for _, eventName in ipairs({ "EVENT_INVENTORY_FULL_UPDATE", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE" }) do
        local code = rawget(_G, eventName)
        if code then
            EVENT_MANAGER:RegisterForEvent(prefix .. eventName, code, function()
                if houseStorageActive() then scheduleRefresh() end
            end)
        end
    end
end

scheduleRefresh()


-- BEGIN ABSORBED: HouseStorageDepositHeaderInteractionFix.lua
-- ESO Adventurer Suite
-- v0.29.621 - House Storage Deposit header interaction repair.
-- Deposit layout/rendering remains owned by HouseStoragePureNativeFix.lua.
-- This file only ensures category headers are the mouse target. The renderer's
-- existing CT_BUTTON OnClicked handler is allowed to fire exactly once.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end

local ADDON = EPC.name or "ESOAdventurerSuite"
local PREFIX = ADDON .. "_HouseStorageGrid029594"
local MAX_HEADERS = 64
local generation = 0

-- Reuse the file-level fragmentShown helper.
local function depositActive()
    if not fragmentShown(rawget(_G, "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT")) then
        local sm = rawget(_G, "SCENE_MANAGER")
        if not (sm and type(sm.IsShowing) == "function" and sm:IsShowing("houseBank")) then return false end
    end
    return fragmentShown(rawget(_G, "INVENTORY_FRAGMENT"))
        and not fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT"))
end

local function high(control, level)
    if not control then return end
    local tier = rawget(_G, "DT_HIGH")
    local layer = rawget(_G, "DL_OVERLAY")
    if tier ~= nil and type(control.SetDrawTier) == "function" then pcall(control.SetDrawTier, control, tier) end
    if layer ~= nil and type(control.SetDrawLayer) == "function" then pcall(control.SetDrawLayer, control, layer) end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 1220) end
end

local function patchHeader(header)
    if not header then return false end

    high(header, 1220)
    if type(header.SetMouseEnabled) == "function" then pcall(header.SetMouseEnabled, header, true) end

    -- HouseStoragePureNativeFix.lua owns the real collapse state through the
    -- header's original OnClicked handler. Do not forward OnMouseUp into it:
    -- CT_BUTTON already dispatches OnClicked, and forwarding causes a double
    -- toggle (collapse immediately followed by expand).
    if type(header.SetHandler) == "function" then
        pcall(header.SetHandler, header, "OnMouseUp", nil)
    end

    if header.label and type(header.label.SetMouseEnabled) == "function" then
        pcall(header.label.SetMouseEnabled, header.label, false)
    end

    -- The renderer creates an unnamed backdrop plus the label as children.
    -- Neither child may intercept the click from the CT_BUTTON header.
    if type(header.GetNumChildren) == "function" and type(header.GetChild) == "function" then
        local ok, count = pcall(header.GetNumChildren, header)
        count = ok and tonumber(count) or 0
        for i = 1, count do
            local okChild, child = pcall(header.GetChild, header, i)
            if okChild and child and type(child.SetMouseEnabled) == "function" then
                pcall(child.SetMouseEnabled, child, false)
            end
        end
    end

    -- Only report success when the renderer's real collapse callback exists.
    if type(header.GetHandler) == "function" then
        local ok, original = pcall(header.GetHandler, header, "OnClicked")
        return ok and type(original) == "function"
    end
    return false
end

local function apply()
    if not depositActive() then return 0 end
    local root = rawget(_G, PREFIX)
    if root then
        high(root, 1200)
        if type(root.SetMouseEnabled) == "function" then pcall(root.SetMouseEnabled, root, true) end
    end

    local patched = 0
    for i = 1, MAX_HEADERS do
        local header = rawget(_G, PREFIX .. "Header" .. i)
        if header and patchHeader(header) then patched = patched + 1 end
    end
    return patched
end

local function schedule()
    if not depositActive() then return end
    generation = generation + 1
    local mine = generation

    -- The main House Storage renderer has settled passes through 340 ms. Keep a
    -- finite repair burst beyond that point so the final visible headers always
    -- have child mouse input disabled. No permanent OnUpdate loop is used.
    local delays = { 0, 40, 120, 260, 380, 520, 750, 1000 }
    if type(rawget(_G, "zo_callLater")) ~= "function" then apply(); return end
    for _, delay in ipairs(delays) do
        zo_callLater(function()
            if mine == generation and depositActive() then apply() end
        end, delay)
    end
end

for _, fragmentName in ipairs({ "INVENTORY_FRAGMENT", "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT" }) do
    local fragment = rawget(_G, fragmentName)
    if fragment and type(fragment.RegisterCallback) == "function" then
        fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_FRAGMENT_SHOWING")
                or newState == rawget(_G, "SCENE_FRAGMENT_SHOWN") then
                schedule()
            end
        end)
    end
end

for _, eventName in ipairs({
    "EVENT_OPEN_BANK",
    "EVENT_INVENTORY_FULL_UPDATE",
    "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
}) do
    local code = rawget(_G, eventName)
    if code ~= nil then
        EVENT_MANAGER:RegisterForEvent(PREFIX .. "HeaderMouse" .. eventName, code, function()
            if depositActive() then schedule() end
        end)
    end
end

schedule()

-- END ABSORBED: HouseStorageDepositHeaderInteractionFix.lua


-- BEGIN ABSORBED: HouseStorageWithdrawViewportFix.lua
-- ESO Adventurer Suite
-- v0.29.613 - House Storage Withdraw-only renderer correction.
-- Deposit stays owned by HouseStoragePureNativeFix.lua. Withdraw follows ESO's
-- HOUSE_BANK_FRAGMENT first, then reads ESO's filtered list/cache and finally the
-- active GetBankingBag() directly so the Suite grid cannot remain blank.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER or not EVENT_MANAGER then return end

local wm = WINDOW_MANAGER
local ADDON = EPC.name or "ESOAdventurerSuite"
local NAME = ADDON .. "_HouseStorageWithdrawGrid029609"
local MAIN_PREFIX = ADDON .. "_HouseStorageGrid029594"
local CELL, GAP, HEADER_H = 48, 5, 28
local MAX_CELLS, MAX_HEADERS = 320, 64

local root
local cells, headers = {}, {}
local collapsed = {}
local scroll = 0
local contentHeight = 0
local generation = 0
local activeHouseBag

local function call1(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

-- Reuse the file-level architecture-owned scene helpers.
local function inventoryData(inventoryType)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" or inventoryType == nil then return nil end
    local data = manager.inventories[inventoryType]
    return type(data) == "table" and data or nil
end

local function inventoryList(inventoryType, fallback)
    local data = inventoryData(inventoryType)
    if data then return data.listView or data.list or data.scrollList or rawget(_G, fallback) end
    return rawget(_G, fallback)
end

local function withdrawList()
    return inventoryList(rawget(_G, "INVENTORY_HOUSE_BANK"), "ZO_HouseBankBackpack")
end

local function depositList()
    return inventoryList(rawget(_G, "INVENTORY_BACKPACK"), "ZO_PlayerInventoryList")
end

local function currentMode()
    if not houseStorageActive() then return nil end

    -- ESO's House Bank tabs are fragment-driven. HOUSE_BANK_FRAGMENT is the
    -- authoritative Withdraw signal and must win over stale selectedTabType.
    if fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT")) then return "WITHDRAW" end
    if fragmentShown(rawget(_G, "INVENTORY_FRAGMENT")) then return "DEPOSIT" end

    local manager = rawget(_G, "PLAYER_INVENTORY")
    local selected = type(manager) == "table" and tonumber(manager.selectedTabType) or nil
    local house = tonumber(rawget(_G, "INVENTORY_HOUSE_BANK"))
    local backpack = tonumber(rawget(_G, "INVENTORY_BACKPACK"))
    if selected ~= nil and house ~= nil and selected == house then return "WITHDRAW" end
    if selected ~= nil and backpack ~= nil and selected == backpack then return "DEPOSIT" end
    return nil
end

local function isHouseBag(bag)
    bag = tonumber(bag)
    if bag == nil then return false end
    if type(rawget(_G, "IsHouseBankBag")) == "function" then
        local ok, yes = pcall(IsHouseBankBag, bag)
        if ok then return yes == true end
    end
    local firstBag = tonumber(rawget(_G, "BAG_HOUSE_BANK_ONE"))
    local lastBag = tonumber(rawget(_G, "BAG_HOUSE_BANK_TEN"))
    return firstBag ~= nil and lastBag ~= nil and bag >= firstBag and bag <= lastBag
end

local function currentHouseBag()
    if type(rawget(_G, "GetBankingBag")) == "function" then
        local ok, bag = pcall(GetBankingBag)
        if ok and isHouseBag(bag) then
            activeHouseBag = tonumber(bag)
            EPC.HouseStorageActiveBag029611 = activeHouseBag
            return activeHouseBag
        end
    end

    local shared = tonumber(EPC.HouseStorageActiveBag029611)
    if isHouseBag(shared) then activeHouseBag = shared; return shared end
    if isHouseBag(activeHouseBag) then return activeHouseBag end

    local inventory = inventoryData(rawget(_G, "INVENTORY_HOUSE_BANK"))
    if inventory and type(inventory.backingBags) == "table" then
        for _, bag in ipairs(inventory.backingBags) do
            if isHouseBag(bag) then
                activeHouseBag = tonumber(bag)
                return activeHouseBag
            end
        end
    end
    return nil
end

local function groupFor(link)
    local grid = rawget(_G, "EASInventoryGrid")
    if grid and type(grid.GetExternalGroupName029364) == "function" then
        local ok, value = pcall(grid.GetExternalGroupName029364, grid, link)
        if ok and tostring(value or "") ~= "" then return tostring(value) end
    end
    return "Other"
end

local function safeStackCount(bag, slot, fallback)
    if type(rawget(_G, "GetSlotStackSize")) == "function" then
        local ok, value = pcall(GetSlotStackSize, bag, slot)
        if ok then
            value = tonumber(value)
            if value and value > 0 then return value end
        end
    end
    return math.max(1, tonumber(fallback) or 1)
end

local function itemFromData(data, fallbackBag, fallbackSlot)
    if type(data) ~= "table" then return nil end
    if data.easSuiteCategoryHeader029364 or data.easSuiteCategoryHeader029376
        or data.easSuiteHouseStorageHeader029592 or data.easSuiteHouseStorageHeader029594 then
        return nil
    end

    local bag = tonumber(data.bagId or data.bag or fallbackBag)
    local slot = tonumber(data.slotIndex or data.slot or fallbackSlot)
    if bag == nil or slot == nil then return nil end

    local link = tostring(data.itemLink or data.link or data.itemLinkString or "")
    if link == "" and type(rawget(_G, "GetItemLink")) == "function" then
        link = tostring(call1(GetItemLink, "", bag, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
    end
    if link == "" then return nil end

    local icon = tostring(data.iconFile or data.icon or "")
    local stack = tonumber(data.stackCount) or safeStackCount(bag, slot, 1)
    local quality = tonumber(data.displayQuality or data.quality)
    local locked = data.locked == true or data.isPlayerLocked == true

    if type(rawget(_G, "GetItemInfo")) == "function" then
        local ok, i, s, _, _, l, _, _, q = pcall(GetItemInfo, bag, slot)
        if ok then
            if icon == "" then icon = tostring(i or "") end
            if not stack or stack <= 0 then stack = tonumber(s) or 1 end
            if quality == nil then quality = tonumber(q) end
            if l == true then locked = true end
        end
    end

    local name = tostring(data.name or "")
    if name == "" and type(rawget(_G, "GetItemName")) == "function" then
        name = tostring(call1(GetItemName, "", bag, slot) or "")
    end

    return {
        bag = bag,
        slot = slot,
        link = link,
        name = name,
        icon = icon,
        stack = tonumber(stack) or 1,
        quality = tonumber(quality) or 0,
        locked = locked,
        group = groupFor(link),
    }
end

local function passesNativeFilter(inventory, slotData)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.ShouldAddSlotToList) ~= "function" then return true end
    if type(slotData) ~= "table" then return true end
    local ok, allowed = pcall(manager.ShouldAddSlotToList, manager, inventory, slotData)
    if not ok then return true end
    return allowed == true
end

local function sortItems(items)
    table.sort(items, function(a, b)
        if a.group ~= b.group then return string.lower(a.group) < string.lower(b.group) end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return string.lower(a.name) < string.lower(b.name)
    end)
    return items
end

local function collectFromNativeList()
    local items = {}
    local list = withdrawList()
    if not list or type(rawget(_G, "ZO_ScrollList_GetDataList")) ~= "function" then return items end
    local ok, dataList = pcall(ZO_ScrollList_GetDataList, list)
    if not ok or type(dataList) ~= "table" then return items end

    for _, entry in ipairs(dataList) do
        local data = type(entry) == "table" and (entry.data or entry) or nil
        local item = itemFromData(data)
        if item then items[#items + 1] = item end
    end
    return sortItems(items)
end

local function collectFromInventoryCache(bag, inventory)
    local items = {}
    local slotTable = inventory and inventory.slots and inventory.slots[bag]
    if type(slotTable) ~= "table" then return items end

    for slotIndex, slotData in pairs(slotTable) do
        if type(slotData) == "table" and passesNativeFilter(inventory, slotData) then
            local item = itemFromData(slotData, bag, slotIndex)
            if item then items[#items + 1] = item end
        end
    end
    return sortItems(items)
end

local function filterIsDefault(inventory)
    if not inventory then return true end
    local all = rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_ALL")
    if all ~= nil and inventory.currentFilter ~= nil and inventory.currentFilter ~= all then return false end
    local box = inventory.searchBox
    if box and type(box.GetText) == "function" then
        local ok, text = pcall(box.GetText, box)
        if ok and tostring(text or "") ~= "" then return false end
    end
    return true
end

local function collectFromBag(bag, inventory)
    local filtered, rawItems = {}, {}
    local shared = rawget(_G, "SHARED_INVENTORY")

    local function addSlot(slot)
        local data
        if type(shared) == "table" and type(shared.GenerateSingleSlotData) == "function" then
            local ok, value = pcall(shared.GenerateSingleSlotData, shared, bag, slot)
            if ok and type(value) == "table" then data = value end
        end
        local item = itemFromData(data or {}, bag, slot)
        if not item then return end
        rawItems[#rawItems + 1] = item
        if not data or passesNativeFilter(inventory, data) then filtered[#filtered + 1] = item end
    end

    if type(rawget(_G, "ZO_IterateBagSlots")) == "function" then
        for slot in ZO_IterateBagSlots(bag) do addSlot(slot) end
    elseif type(rawget(_G, "GetBagSize")) == "function" then
        local size = tonumber(call1(GetBagSize, 0, bag)) or 0
        for slot = 0, size - 1 do addSlot(slot) end
    end

    if #filtered > 0 then return sortItems(filtered) end
    if filterIsDefault(inventory) then return sortItems(rawItems) end
    return filtered
end

local function collectWithdraw()
    -- First use ESO's already filtered list when it is populated.
    local items = collectFromNativeList()
    if #items > 0 then return items end

    local bag = currentHouseBag()
    local inventory = inventoryData(rawget(_G, "INVENTORY_HOUSE_BANK"))
    if bag == nil or not inventory then return items end

    -- ESO's scene initializes inventory.slots[GetBankingBag()] before showing
    -- Withdraw. Prefer that cache because it contains ESO's filter/search data.
    items = collectFromInventoryCache(bag, inventory)
    if #items > 0 then return items end

    -- Final fallback: enumerate the actual opened storage bag directly.
    return collectFromBag(bag, inventory)
end

local function high(control, level)
    if not control then return end
    if type(control.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if type(control.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then
        pcall(control.SetDrawLayer, control, DL_OVERLAY)
    end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 1200) end
end

local renderWithdraw

local function ensureRoot()
    local list = withdrawList()
    if not list then return false end
    local parent = type(list.GetParent) == "function" and call1(list.GetParent, GuiRoot, list) or GuiRoot
    parent = parent or GuiRoot

    if not root then
        root = wm:CreateControl(NAME, parent, CT_CONTROL)
        root:SetMouseEnabled(true)
        high(root, 1200)
        root:SetHandler("OnMouseWheel", function(_, delta)
            local height = tonumber(call1(root.GetHeight, 0, root)) or 0
            local maxScroll = math.max(0, contentHeight - height + 4)
            scroll = math.max(0, math.min(maxScroll, scroll - (tonumber(delta) or 0) * 110))
            if currentMode() == "WITHDRAW" and type(renderWithdraw) == "function" then renderWithdraw() end
        end)
    elseif type(root.GetParent) == "function" and root:GetParent() ~= parent and type(root.SetParent) == "function" then
        pcall(root.SetParent, root, parent)
    end

    root:ClearAnchors()
    root:SetAnchor(TOPLEFT, list, TOPLEFT, 0, 0)
    root:SetAnchor(BOTTOMRIGHT, list, BOTTOMRIGHT, 0, 0)
    high(root, 1200)
    root._easRenderWithdraw029612 = renderWithdraw
    root._easRenderWithdraw029613 = renderWithdraw
    return true
end

local function clearPool()
    for _, h in ipairs(headers) do
        h.group = nil
        h:SetHidden(true)
        h:SetMouseEnabled(false)
    end
    for _, c in ipairs(cells) do
        c.item = nil
        c:SetHidden(true)
        c:SetMouseEnabled(false)
    end
end

local function getHeader(i)
    local h = headers[i]
    if h then return h end
    if i > MAX_HEADERS then return nil end

    h = wm:CreateControl(NAME .. "Header" .. i, root, CT_BUTTON)
    h:SetHeight(HEADER_H)
    high(h, 1220)

    local bg = wm:CreateControl(nil, h, CT_BACKDROP)
    bg:SetAnchorFill(h)
    bg:SetCenterColor(.035, .055, .08, 1)
    bg:SetEdgeColor(.35, .45, .55, 1)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 1)
    bg:SetMouseEnabled(false)

    local label = wm:CreateControl(nil, h, CT_LABEL)
    label:SetAnchor(TOPLEFT, h, TOPLEFT, 8, 3)
    label:SetAnchor(BOTTOMRIGHT, h, BOTTOMRIGHT, -4, -3)
    label:SetFont("ZoFontGameBold")
    label:SetColor(1, .82, .26, 1)
    label:SetMouseEnabled(false)
    h.label = label

    h:SetHandler("OnClicked", function(control)
        if not control.group then return end
        collapsed[control.group] = not (collapsed[control.group] == true)
        scroll = 0
        if type(renderWithdraw) == "function" then renderWithdraw() end
    end)
    headers[i] = h
    return h
end

local function localWithdraw(item)
    if type(EPC.HouseStorageSafeMove029611) == "function" then
        local ok = pcall(EPC.HouseStorageSafeMove029611, item, "WITHDRAW")
        if ok then return end
    end
    if type(EPC.HouseStorageSafeMove029610) == "function" then
        local ok = pcall(EPC.HouseStorageSafeMove029610, item, "WITHDRAW")
        if ok then return end
    end

    local targetBag = rawget(_G, "BAG_BACKPACK")
    if targetBag == nil or type(rawget(_G, "FindFirstEmptySlotInBag")) ~= "function" then return end
    local targetSlot = call1(FindFirstEmptySlotInBag, nil, targetBag)
    if targetSlot == nil then return end
    local count = safeStackCount(item.bag, item.slot, item.stack)

    if type(rawget(_G, "IsProtectedFunction")) == "function" then
        local ok, protected = pcall(IsProtectedFunction, "RequestMoveItem")
        if ok and protected == true and type(rawget(_G, "CallSecureProtected")) == "function" then
            pcall(CallSecureProtected, "RequestMoveItem", item.bag, item.slot, targetBag, targetSlot, count)
            return
        end
    end
    if type(rawget(_G, "RequestMoveItem")) == "function" then
        pcall(RequestMoveItem, item.bag, item.slot, targetBag, targetSlot, count)
    end
end

local function getCell(i)
    local c = cells[i]
    if c then return c end
    if i > MAX_CELLS then return nil end

    c = wm:CreateControl(NAME .. "Cell" .. i, root, CT_BUTTON)
    c:SetDimensions(CELL, CELL)
    c:SetMouseEnabled(true)
    high(c, 1250)

    local bg = wm:CreateControl(nil, c, CT_BACKDROP)
    bg:SetAnchorFill(c)
    bg:SetCenterColor(.06, .07, .09, 1)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 2)
    bg:SetMouseEnabled(false)
    c.bg = bg

    local icon = wm:CreateControl(nil, c, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, c, TOPLEFT, 3, 3)
    icon:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -3, -3)
    icon:SetTextureCoords(.05, .95, .05, .95)
    icon:SetMouseEnabled(false)
    c.icon = icon

    local count = wm:CreateControl(nil, c, CT_LABEL)
    count:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -2, -1)
    count:SetDimensions(28, 14)
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetFont("ZoFontGameSmall")
    count:SetColor(1, 1, 1, 1)
    count:SetMouseEnabled(false)
    c.count = count

    c:SetHandler("OnMouseEnter", function(control)
        if control.item and ItemTooltip and type(rawget(_G, "InitializeTooltip")) == "function" then
            InitializeTooltip(ItemTooltip, control, LEFT, -8, 0, RIGHT)
            if type(ItemTooltip.SetBagItem) == "function" then
                pcall(ItemTooltip.SetBagItem, ItemTooltip, control.item.bag, control.item.slot)
            end
        end
    end)
    c:SetHandler("OnMouseExit", function()
        if ItemTooltip and type(rawget(_G, "ClearTooltip")) == "function" then pcall(ClearTooltip, ItemTooltip) end
    end)
    c:SetHandler("OnMouseUp", function(control, button, inside)
        if inside == false or type(control.item) ~= "table" then return end
        local left = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
        if button == left then localWithdraw(control.item) end
    end)

    cells[i] = c
    return c
end

local function qualityColor(q)
    local colorType = rawget(_G, "INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS")
    if type(rawget(_G, "GetInterfaceColor")) == "function" and colorType ~= nil then
        local ok, r, g, b = pcall(GetInterfaceColor, colorType, tonumber(q) or 0)
        if ok and r ~= nil then return r, g, b end
    end
    return .35, .42, .50
end

local function hideNativeWithdrawList()
    local list = withdrawList()
    if not list then return end
    if type(list.SetAlpha) == "function" then pcall(list.SetAlpha, list, 0) end
    if type(list.SetMouseEnabled) == "function" then pcall(list.SetMouseEnabled, list, false) end
end

renderWithdraw = function()
    if currentMode() ~= "WITHDRAW" then
        if root then root:SetHidden(true) end
        return false
    end
    if not ensureRoot() then return false end

    local mainRoot = rawget(_G, MAIN_PREFIX)
    if mainRoot and type(mainRoot.SetHidden) == "function" then pcall(mainRoot.SetHidden, mainRoot, true) end

    local items = collectWithdraw()
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
    table.sort(order, function(a, b) return string.lower(a) < string.lower(b) end)

    local width = tonumber(call1(root.GetWidth, 500, root)) or 500
    local height = tonumber(call1(root.GetHeight, 0, root)) or 0
    local cols = math.max(4, math.floor((width - 16) / (CELL + GAP)))
    local y, hi, ci = 0, 0, 0

    for _, group in ipairs(order) do
        hi = hi + 1
        local headerY = y - scroll
        local h = getHeader(hi)
        if h then
            h.group = group
            h.label:SetText((collapsed[group] and "+  " or "-  ") .. group .. "  (" .. tostring(#groups[group]) .. ")")
            h:ClearAnchors()
            h:SetAnchor(TOPLEFT, root, TOPLEFT, 4, headerY)
            h:SetWidth(width - 12)
            local visible = headerY >= 0 and (headerY + HEADER_H) <= height
            h:SetHidden(not visible)
            h:SetMouseEnabled(visible)
            high(h, 1220)
        end
        y = y + HEADER_H + GAP

        if not collapsed[group] then
            local rows = math.ceil(#groups[group] / cols)
            for i, item in ipairs(groups[group]) do
                ci = ci + 1
                if ci > MAX_CELLS then break end
                local c = getCell(ci)
                if not c then break end

                c.item = item
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cellY = y + row * (CELL + GAP) - scroll
                c:ClearAnchors()
                c:SetAnchor(TOPLEFT, root, TOPLEFT, 4 + col * (CELL + GAP), cellY)
                c.icon:SetTexture(item.icon ~= "" and item.icon or "EsoUI/Art/Icons/icon_missing.dds")
                c.count:SetText(item.stack > 1 and tostring(item.stack) or "")
                local r, g, b = qualityColor(item.quality)
                c.bg:SetEdgeColor(r, g, b, 1)

                local visible = cellY >= 0 and (cellY + CELL) <= height
                c:SetHidden(not visible)
                c:SetMouseEnabled(visible)
                high(c, 1250)
            end
            y = y + rows * (CELL + GAP) + GAP
        end
    end

    contentHeight = y
    local maxScroll = math.max(0, contentHeight - height + 4)
    if scroll > maxScroll then
        scroll = maxScroll
        return renderWithdraw()
    end

    hideNativeWithdrawList()
    return true
end

-- Deposit containment below is intentionally kept as-is; Deposit remains owned
-- by HouseStoragePureNativeFix.lua.
local function geometry(control)
    if not control then return nil end
    local l = tonumber(call1(control.GetLeft, nil, control))
    local t = tonumber(call1(control.GetTop, nil, control))
    local r = tonumber(call1(control.GetRight, nil, control))
    local b = tonumber(call1(control.GetBottom, nil, control))
    if not l or not t or not r or not b then return nil end
    return l, t, r, b
end

local function clipDepositGrid()
    if currentMode() ~= "DEPOSIT" then return end
    local viewport = depositList()
    local vl, vt, vr, vb = geometry(viewport)
    if not vl then return end

    for i = 1, MAX_HEADERS do
        local c = rawget(_G, MAIN_PREFIX .. "Header" .. i)
        if c and c.group ~= nil then
            local l, t, r, b = geometry(c)
            if l then
                local contained = l >= vl and r <= vr and t >= vt and b <= vb
                if type(c.SetHidden) == "function" then c:SetHidden(not contained) end
                if type(c.SetMouseEnabled) == "function" then c:SetMouseEnabled(contained) end
            end
        end
    end

    for i = 1, MAX_CELLS do
        local c = rawget(_G, MAIN_PREFIX .. "Cell" .. i)
        if c and c.item ~= nil then
            local l, t, r, b = geometry(c)
            if l then
                local contained = l >= vl and r <= vr and t >= vt and b <= vb
                if type(c.SetHidden) == "function" then c:SetHidden(not contained) end
                if type(c.SetMouseEnabled) == "function" then c:SetMouseEnabled(contained) end
            end
        end
    end
end

local function installDepositWheelClip()
    local mainRoot = rawget(_G, MAIN_PREFIX)
    if not mainRoot or mainRoot._easHouseStorageHardClip029612 then return end
    mainRoot._easHouseStorageHardClip029612 = true
    if type(rawget(_G, "ZO_PostHookHandler")) == "function" then
        pcall(ZO_PostHookHandler, mainRoot, "OnMouseWheel", function()
            if type(rawget(_G, "zo_callLater")) == "function" then zo_callLater(clipDepositGrid, 0) else clipDepositGrid() end
        end)
    end
end

local function refresh()
    if not houseStorageActive() then return end
    installDepositWheelClip()
    if currentMode() == "WITHDRAW" then
        renderWithdraw()
    else
        if root then root:SetHidden(true) end
        clipDepositGrid()
    end
end

local function scheduleRefresh()
    if not houseStorageActive() then return end
    generation = generation + 1
    local mine = generation
    refresh()
    if type(rawget(_G, "zo_callLater")) ~= "function" then return end
    for _, delay in ipairs({ 0, 35, 90, 180, 340 }) do
        zo_callLater(function()
            if mine == generation and houseStorageActive() then refresh() end
        end, delay)
    end
end

local manager = rawget(_G, "PLAYER_INVENTORY")
if type(manager) == "table" and type(rawget(_G, "ZO_PostHook")) == "function" then
    for _, methodName in ipairs({ "UpdateList", "ChangeFilter", "ChangeSort" }) do
        if type(manager[methodName]) == "function" then
            pcall(ZO_PostHook, manager, methodName, function()
                if houseStorageActive() then scheduleRefresh() end
            end)
        end
    end
end

for _, fragmentName in ipairs({ "HOUSE_BANK_FRAGMENT", "INVENTORY_FRAGMENT", "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT" }) do
    local fragment = rawget(_G, fragmentName)
    if fragment and type(fragment.RegisterCallback) == "function" then
        fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_FRAGMENT_SHOWING") or newState == rawget(_G, "SCENE_FRAGMENT_SHOWN") then
                scroll = 0
                currentHouseBag()
                scheduleRefresh()
            end
        end)
    end
end

local sm = rawget(_G, "SCENE_MANAGER")
if sm and type(sm.GetScene) == "function" then
    local scene = sm:GetScene("houseBank")
    if scene and type(scene.RegisterCallback) == "function" then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_SHOWING") or newState == rawget(_G, "SCENE_SHOWN") then
                activeHouseBag = nil
                scroll = 0
                currentHouseBag()
                scheduleRefresh()
            elseif newState == rawget(_G, "SCENE_HIDING") or newState == rawget(_G, "SCENE_HIDDEN") then
                generation = generation + 1
                activeHouseBag = nil
                scroll = 0
                if root then root:SetHidden(true) end
            end
        end)
    end
end

if rawget(_G, "EVENT_OPEN_BANK") ~= nil then
    EVENT_MANAGER:RegisterForEvent(NAME .. "OpenBank", EVENT_OPEN_BANK, function()
        activeHouseBag = nil
        currentHouseBag()
        scroll = 0
        if houseStorageActive() then scheduleRefresh() end
    end)
end

for _, eventName in ipairs({ "EVENT_INVENTORY_FULL_UPDATE", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE" }) do
    local code = rawget(_G, eventName)
    if code ~= nil then
        EVENT_MANAGER:RegisterForEvent(NAME .. eventName, code, function()
            if currentMode() == "WITHDRAW" then scheduleRefresh() end
        end)
    end
end

if type(rawget(_G, "zo_callLater")) == "function" then
    zo_callLater(function()
        if houseStorageActive() then
            currentHouseBag()
            refresh()
        end
    end, 0)
end

-- END ABSORBED: HouseStorageWithdrawViewportFix.lua


-- BEGIN ABSORBED: HouseStorageTransferSafetyFix.lua
-- ESO Adventurer Suite
-- v0.29.615 - House Storage secure transfer bridge.
-- Deposit visuals remain owned by HouseStoragePureNativeFix.lua.
-- Withdraw visuals/interactions remain owned by HouseStorageWithdrawViewportFix.lua.
-- This module only gives the existing Deposit grid a native ESO transfer-dialog handoff.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end

local ADDON = EPC.name or "ESOAdventurerSuite"
local NAME = ADDON .. "_HouseStorageTransferSafety029615_"
local MAIN_PREFIX = ADDON .. "_HouseStorageGrid029594"
local MAX_CELLS = 320
local generation = 0

-- Reuse the file-level architecture-owned scene helpers.
local function currentMode()
    if not houseStorageActive() then return nil end

    -- House Storage is fragment-driven. These are authoritative and must win over
    -- PLAYER_INVENTORY.selectedTabType, which can lag during tab transitions.
    if fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT")) then return "WITHDRAW" end
    if fragmentShown(rawget(_G, "INVENTORY_FRAGMENT")) then return "DEPOSIT" end

    local manager = rawget(_G, "PLAYER_INVENTORY")
    local selected = type(manager) == "table" and tonumber(manager.selectedTabType) or nil
    local house = tonumber(rawget(_G, "INVENTORY_HOUSE_BANK"))
    local backpack = tonumber(rawget(_G, "INVENTORY_BACKPACK"))
    if selected ~= nil and house ~= nil and selected == house then return "WITHDRAW" end
    if selected ~= nil and backpack ~= nil and selected == backpack then return "DEPOSIT" end
    return nil
end

local function currentHouseBag()
    local getBankingBag = rawget(_G, "GetBankingBag")
    if type(getBankingBag) ~= "function" then return nil end

    local ok, bag = pcall(getBankingBag)
    if not ok then return nil end
    bag = tonumber(bag)
    if bag == nil then return nil end

    local isHouseBankBag = rawget(_G, "IsHouseBankBag")
    if type(isHouseBankBag) == "function" then
        local okHouse, yes = pcall(isHouseBankBag, bag)
        if okHouse and yes ~= true then return nil end
    end

    EPC.HouseStorageActiveBag029611 = bag
    return bag
end

local function openNativeTransfer(sourceBag, sourceSlot, targetBag)
    sourceBag = tonumber(sourceBag)
    sourceSlot = tonumber(sourceSlot)
    targetBag = tonumber(targetBag)
    if sourceBag == nil or sourceSlot == nil or targetBag == nil or sourceBag == targetBag then return false end

    local systems = rawget(_G, "SYSTEMS")
    if (type(systems) ~= "table" and type(systems) ~= "userdata") or type(systems.GetObject) ~= "function" then
        return false
    end

    local ok, dialog = pcall(systems.GetObject, systems, "ItemTransferDialog")
    if not ok or not dialog or type(dialog.StartTransfer) ~= "function" then return false end

    -- This only asks ESO's native ItemTransferDialog to own the transfer. The
    -- protected pickup/place operations execute later from ESO's trusted dialog.
    local started = pcall(dialog.StartTransfer, dialog, sourceBag, sourceSlot, targetBag)
    return started == true
end

local function safeMove(item, modeOverride)
    if not houseStorageActive() or type(item) ~= "table" then return false end

    local mode = modeOverride or currentMode()
    local sourceBag = tonumber(item.bag)
    local sourceSlot = tonumber(item.slot)
    if sourceBag == nil or sourceSlot == nil then return false end

    if mode == "WITHDRAW" then
        local backpack = tonumber(rawget(_G, "BAG_BACKPACK"))
        if backpack == nil then return false end
        return openNativeTransfer(sourceBag, sourceSlot, backpack)
    end

    if mode ~= "DEPOSIT" or item.locked == true then return false end

    local targetBag = currentHouseBag()
    if targetBag == nil or targetBag == sourceBag then return false end

    local doesBagHaveSpaceFor = rawget(_G, "DoesBagHaveSpaceFor")
    if type(doesBagHaveSpaceFor) == "function" then
        local ok, hasSpace = pcall(doesBagHaveSpaceFor, targetBag, sourceBag, sourceSlot)
        if ok and hasSpace == false then
            local alert = rawget(_G, "ZO_Alert")
            local category = rawget(_G, "UI_ALERT_CATEGORY_ERROR")
            local fullString = rawget(_G, "SI_INVENTORY_ERROR_INVENTORY_FULL")
            if type(alert) == "function" and category ~= nil and fullString ~= nil then
                pcall(alert, category, nil, fullString)
            end
            return false
        end
    end

    return openNativeTransfer(sourceBag, sourceSlot, targetBag)
end

-- Compatibility exports used by the Withdraw renderer. There is deliberately no
-- private inventory-transfer API referenced anywhere in this file.
EPC.HouseStorageSafeMove029610 = safeMove
EPC.HouseStorageSafeMove029611 = safeMove
EPC.HouseStorageSafeMove029615 = safeMove

local function highMouse(control, level)
    if not control then return end
    local highTier = rawget(_G, "DT_HIGH")
    local overlayLayer = rawget(_G, "DL_OVERLAY")
    if type(control.SetDrawTier) == "function" and highTier ~= nil then
        pcall(control.SetDrawTier, control, highTier)
    end
    if type(control.SetDrawLayer) == "function" and overlayLayer ~= nil then
        pcall(control.SetDrawLayer, control, overlayLayer)
    end
    if type(control.SetDrawLevel) == "function" then
        pcall(control.SetDrawLevel, control, level or 1250)
    end
    if type(control.IsHidden) == "function" and type(control.SetMouseEnabled) == "function" then
        local ok, hidden = pcall(control.IsHidden, control)
        if ok and hidden == false then pcall(control.SetMouseEnabled, control, true) end
    end
end

local function bindDepositSlot(control)
    if not control or type(control.item) ~= "table" then return false end
    local bag = tonumber(control.item.bag)
    local slot = tonumber(control.item.slot)
    local slotType = rawget(_G, "SLOT_TYPE_ITEM")
    if bag == nil or slot == nil or slotType == nil then return false end

    local bindSlot = rawget(_G, "ZO_Inventory_BindSlot")
    if type(bindSlot) == "function" then
        pcall(bindSlot, control, slotType, slot, bag)
    else
        control.slotType, control.slotIndex, control.bagId = slotType, slot, bag
    end
    return true
end

local function depositLabel()
    local stringId = rawget(_G, "SI_ITEM_ACTION_BANK_DEPOSIT")
    local getString = rawget(_G, "GetString")
    if stringId ~= nil and type(getString) == "function" then
        local ok, text = pcall(getString, stringId)
        if ok and tostring(text or "") ~= "" then return tostring(text) end
    end
    return "Deposit"
end

local function patchDepositMenu(control)
    local menu = rawget(_G, "ZO_Menu")
    if (type(menu) ~= "userdata" and type(menu) ~= "table") or type(menu.items) ~= "table" then return end

    local expected = depositLabel()
    for _, entry in ipairs(menu.items) do
        local menuControl = type(entry) == "table" and entry.item or nil
        local label = menuControl and menuControl.nameLabel
        local text = label and type(label.GetText) == "function" and tostring(label:GetText() or "") or ""
        if text == expected then
            local callback = function()
                if type(control.item) == "table" then safeMove(control.item, "DEPOSIT") end
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

local function installDepositCell(control)
    if not control then return end
    control._easHouseStorageTransferSafe029615 = true
    highMouse(control, 1250)

    if control.bg and type(control.bg.SetMouseEnabled) == "function" then
        pcall(control.bg.SetMouseEnabled, control.bg, false)
    end
    if control.icon and type(control.icon.SetMouseEnabled) == "function" then
        pcall(control.icon.SetMouseEnabled, control.icon, false)
    end
    if control.count and type(control.count.SetMouseEnabled) == "function" then
        pcall(control.count.SetMouseEnabled, control.count, false)
    end

    bindDepositSlot(control)
    if type(control.SetHandler) ~= "function" then return end

    pcall(control.SetHandler, control, "OnClicked", nil)
    control:SetHandler("OnMouseUp", function(c, button, upInside)
        if upInside == false or type(c.item) ~= "table" then return end
        local left = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
        local right = rawget(_G, "MOUSE_BUTTON_INDEX_RIGHT")

        if button == left then
            safeMove(c.item, "DEPOSIT")
            return
        end

        if button == right then
            bindDepositSlot(c)
            local showMenu = rawget(_G, "ZO_InventorySlot_ShowContextMenu")
            if type(showMenu) == "function" then
                local ok = pcall(showMenu, c)
                if ok then patchDepositMenu(c) end
            end
        end
    end)
end

local function apply()
    -- Do not touch Withdraw controls here. HouseStorageWithdrawViewportFix.lua
    -- owns their visuals and input handlers completely.
    if currentMode() ~= "DEPOSIT" then return end

    currentHouseBag()
    highMouse(rawget(_G, MAIN_PREFIX), 1200)

    local foundAny, misses = false, 0
    for i = 1, MAX_CELLS do
        local control = rawget(_G, MAIN_PREFIX .. "Cell" .. i)
        if control then
            foundAny, misses = true, 0
            installDepositCell(control)
        elseif foundAny then
            misses = misses + 1
            if misses >= 24 then break end
        end
    end
end

local function scheduleApply()
    if currentMode() ~= "DEPOSIT" then return end
    generation = generation + 1
    local mine = generation
    apply()

    local callLater = rawget(_G, "zo_callLater")
    if type(callLater) ~= "function" then return end
    for _, delay in ipairs({ 0, 35, 90, 180, 360 }) do
        callLater(function()
            if mine == generation and currentMode() == "DEPOSIT" then apply() end
        end, delay)
    end
end

local manager = rawget(_G, "PLAYER_INVENTORY")
local postHook = rawget(_G, "ZO_PostHook")
if type(manager) == "table" and type(postHook) == "function" then
    for _, methodName in ipairs({ "UpdateList", "ChangeFilter", "ChangeSort" }) do
        if type(manager[methodName]) == "function" then
            pcall(postHook, manager, methodName, function()
                if currentMode() == "DEPOSIT" then scheduleApply() end
            end)
        end
    end
end

for _, fragmentName in ipairs({ "HOUSE_BANK_FRAGMENT", "INVENTORY_FRAGMENT", "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT" }) do
    local fragment = rawget(_G, fragmentName)
    if fragment and type(fragment.RegisterCallback) == "function" then
        fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_FRAGMENT_SHOWING") or newState == rawget(_G, "SCENE_FRAGMENT_SHOWN") then
                if currentMode() == "DEPOSIT" then scheduleApply() end
            elseif fragmentName == "HOUSE_BANK_FRAGMENT"
                and (newState == rawget(_G, "SCENE_FRAGMENT_SHOWING") or newState == rawget(_G, "SCENE_FRAGMENT_SHOWN")) then
                generation = generation + 1
            end
        end)
    end
end

local sm = rawget(_G, "SCENE_MANAGER")
if sm and type(sm.GetScene) == "function" then
    local scene = sm:GetScene("houseBank")
    if scene and type(scene.RegisterCallback) == "function" then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == rawget(_G, "SCENE_HIDING") or newState == rawget(_G, "SCENE_HIDDEN") then
                generation = generation + 1
            elseif newState == rawget(_G, "SCENE_SHOWING") or newState == rawget(_G, "SCENE_SHOWN") then
                currentHouseBag()
                if currentMode() == "DEPOSIT" then scheduleApply() end
            end
        end)
    end
end

local openBank = rawget(_G, "EVENT_OPEN_BANK")
if openBank ~= nil then
    EVENT_MANAGER:RegisterForEvent(NAME .. "OpenBank", openBank, function()
        currentHouseBag()
        if currentMode() == "DEPOSIT" then scheduleApply() end
    end)
end

for _, eventName in ipairs({ "EVENT_INVENTORY_FULL_UPDATE", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE" }) do
    local eventCode = rawget(_G, eventName)
    if eventCode ~= nil then
        EVENT_MANAGER:RegisterForEvent(NAME .. eventName, eventCode, function()
            if currentMode() == "DEPOSIT" then scheduleApply() end
        end)
    end
end

if type(rawget(_G, "zo_callLater")) == "function" then
    zo_callLater(function()
        if currentMode() == "DEPOSIT" then scheduleApply() end
    end, 0)
end

-- END ABSORBED: HouseStorageTransferSafetyFix.lua
