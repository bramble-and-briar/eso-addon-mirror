ChillItemShare = {}
local A = ChillItemShare
A.name, A.version = "ChillItemShare", "1.0.0"
local EM = EVENT_MANAGER
local LOADED = EVENT_ADD_ON_LOADED
local SLOT_UPDATE = EVENT_INVENTORY_SINGLE_SLOT_UPDATE
local BAG_FILTER = REGISTER_FILTER_BAG_ID
local table = table
local pairs, ipairs, type = pairs, ipairs, type
local sort, concat = table.sort, table.concat
local GetItemLink, GetItemUniqueId = GetItemLink, GetItemUniqueId
local GetItemInfo, Id64ToString = GetItemInfo, Id64ToString
local GetItemLinkName = GetItemLinkName
local BACKPACK, BANK, SUB_BANK = BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK
local VAULT = BAG_FURNITURE_VAULT
local BRACKETS = LINK_STYLE_BRACKETS
local GetBankingBag, IsBankOpen = GetBankingBag, IsBankOpen
local GetCollectibleForBag = GetCollectibleForBag
local GetCollectibleName, GetCollectibleNickname = GetCollectibleName, GetCollectibleNickname
local IterateBagSlots = ZO_IterateBagSlots
local schemaDefaults = {selected = {}, preText = "", delaySeconds = 3}
A.bags = {BACKPACK, BANK, SUB_BANK}
for bag = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do A.bags[#A.bags + 1] = bag end
if VAULT then A.bags[#A.bags + 1] = VAULT end
local supported = {}
for _, bag in ipairs(A.bags) do supported[bag] = true end

function A.Say(text) d("|cFF66F3[Chill Item Share]|r " .. text) end
function A.IsAccessible(bag)
    if bag == BACKPACK then return true end
    if not supported[bag] or not IsBankOpen() then return false end
    local current = GetBankingBag()
    return current == bag or (current == BANK and bag == SUB_BANK)
end
function A.SourceName(bag)
    if bag == BACKPACK then return "Backpack" end
    if bag == BANK or bag == SUB_BANK then return "Personal bank" end
    local collectible = GetCollectibleForBag(bag)
    local name, nickname = "", ""
    if collectible and collectible ~= 0 then
        name, nickname = GetCollectibleName(collectible), GetCollectibleNickname(collectible)
    end
    if name == "" then name = bag == VAULT and "Furnishing vault" or "Housing storage" end
    if nickname ~= "" then name = name .. " (" .. nickname .. ")" end
    -- Bag number keeps identically named containers distinct.
    return name .. " [" .. bag .. "]"
end
function A.ReadItem(bag, slot)
    if not A.IsAccessible(bag) then return end
    local link = GetItemLink(bag, slot, BRACKETS)
    if not link or link == "" then return end
    local uid = Id64ToString(GetItemUniqueId(bag, slot))
    if not uid or uid == "0" then return end
    local _, count = GetItemInfo(bag, slot)
    if not count or count < 1 then return end
    return {uid = uid, bag = bag, slot = slot, link = link, count = count,
        name = GetItemLinkName(link), source = A.SourceName(bag)}
end
function A.Scan()
    local items, current = {}, {}
    for _, bag in ipairs(A.bags) do
        if A.IsAccessible(bag) then
            -- ESO's iterator uses sparse slot IDs for the furnishing vault.
            for slot in IterateBagSlots(bag) do
                local item = A.ReadItem(bag, slot)
                if item then items[#items + 1] = item; current[item.uid] = item end
            end
        end
    end
    local houseKey = A.HouseScope()
    if houseKey then
        for _, record in pairs(A.saved.selected) do
            if type(record) == "table" and record.kind == "house" and record.houseKey == houseKey then
                local placed = A.ScanHouse()
                for _, item in ipairs(placed) do items[#items+1] = item; current[item.uid] = item end
                break
            end
        end
    end
    return items, current
end
function A.RecordAccessible(record)
    if record.kind == "house" then return record.houseKey == A.HouseScope() end
    return A.IsAccessible(record.bag)
end
function A.Reconcile()
    local items, current = A.Scan()
    local removed = 0
    for uid, record in pairs(A.saved.selected) do
        local item = current[uid]
        if item then
            A.saved.selected[uid] = item
        elseif record == true or type(record) ~= "table" or A.RecordAccessible(record) then
            -- Never guess that a different identical item is the lost instance.
            A.saved.selected[uid] = nil; removed = removed + 1
        end
        -- Inaccessible storage records are retained but never counted as verified.
    end
    A.items, A.current = items, current
    return removed
end
function A.SelectionState()
    local rows, parts, byLink, signature, unavailable = {}, {}, {}, {}, 0
    for uid, record in pairs(A.saved.selected) do
        local live = A.current[uid]
        local row = live or record
        if type(row) == "table" then
            rows[#rows + 1] = {uid = uid, item = row, available = live ~= nil}
            signature[#signature + 1] = uid .. ":" .. (live and
                ((live.houseKey or live.bag) .. ":" .. live.link .. ":" .. live.count) or "unavailable")
            if live then
                local entry = byLink[live.link]
                if not entry then entry = {link = live.link, count = 0}; byLink[live.link] = entry end
                entry.count = entry.count + live.count
            else unavailable = unavailable + 1 end
        end
    end
    sort(rows, function(a,b)
        if a.item.name == b.item.name then return a.uid < b.uid end
        return a.item.name < b.item.name
    end)
    for _, entry in pairs(byLink) do parts[#parts + 1] = entry end
    sort(parts, function(a,b) return a.link < b.link end)
    for i, entry in ipairs(parts) do
        parts[i] = entry.link .. (entry.count > 1 and " x" .. entry.count or "")
    end
    sort(signature)
    return rows, parts, concat(signature, "\n"), unavailable
end
function A.Invalidate(reason, resumable)
    local queue = A.queue
    if resumable and queue and queue.index <= #queue.messages then
        -- Copy the checkpoint so outstanding callbacks cannot revive this queue.
        A.pausedQueue = {messages = queue.messages, signature = queue.signature,
            index = queue.index, channel = queue.channel, target = queue.target}
    elseif not resumable or queue then A.pausedQueue = nil end
    local pending = A.pending
    if pending and A.chat and A.chat.textEntry:GetText() == pending.text then
        A.chat.textEntry:SetText("")
    end
    local hadQueue = A.queue ~= nil
    A.queue, A.pending, A.submitting = nil, nil, nil
    if hadQueue and reason then A.Say(reason) end
end
function A.Update()
    A.Reconcile()
    if A.queue then
        local _, _, signature = A.SelectionState()
        if signature ~= A.queue.signature then
            A.Invalidate("Share list contents changed. Use /sharepost to rebuild the remaining list.")
        end
    end
    if A.RefreshUI then A.RefreshUI() end
end
function A.ScheduleUpdate()
    EM:UnregisterForUpdate(A.name .. "Refresh")
    EM:RegisterForUpdate(A.name .. "Refresh", 120, function()
        EM:UnregisterForUpdate(A.name .. "Refresh")
        A.Update()
    end)
end
function A.SetItems(items, selected)
    A.Invalidate()
    local houseCurrent
    for _, item in ipairs(items) do
        -- Re-read by UID to avoid selecting a replacement in a reused slot.
        local live
        if item.kind == "house" then
            if not houseCurrent then local _; _, houseCurrent = A.ScanHouse() end
            live = houseCurrent[item.uid]
        else live = A.ReadItem(item.bag, item.slot) end
        if live and live.uid == item.uid then
            A.saved.selected[live.uid] = selected and live or nil
        end
    end
    A.Update()
    -- Successful selection changes are shown in the review UI, not chat.
end
function A.ToggleItem(uid)
    A.Reconcile()
    local item = A.current[uid]
    if not item then A.Say("This item is no longer accessible."); return end
    A.SetItems({item}, not A.saved.selected[uid], item.name)
end
function A.Clear()
    A.Invalidate(); A.saved.selected = {}; A.Update()
end
function A.SelectBag(bag, selected)
    if bag == SUB_BANK then bag = BANK end
    if not A.IsAccessible(bag) then A.Say("Open that storage container first."); return end
    local list = {}
    for slot in IterateBagSlots(bag) do
        local item = A.ReadItem(bag, slot)
        if item then list[#list + 1] = item end
    end
    if bag == BANK then
        for slot in IterateBagSlots(SUB_BANK) do
            local item = A.ReadItem(SUB_BANK, slot)
            if item then list[#list + 1] = item end
        end
    end
    A.SetItems(list, selected, "Entire " .. A.SourceName(bag))
end
-- The actual keyboard inventory list already contains ESO's category,
-- subcategory, text search and additional addon filters. Use all its entries,
-- not only the rows currently visible in the scroll viewport.
function A.CategoryScope(bag)
    local manager = A.inventory
    for _, inventory in pairs(manager.inventories) do
        local list = inventory.listView
        if list and not list:IsControlHidden() and inventory.backingBags then
            local found = false
            for _, backingBag in ipairs(inventory.backingBags) do if backingBag == bag then found = true end end
            if found then
                local items = {}
                for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
                    local data = entry.data
                    if data and data.bagId and data.slotIndex ~= nil then
                        local item = A.ReadItem(data.bagId, data.slotIndex)
                        if item then items[#items + 1] = item end
                    end
                end
                local title = inventory.activeTab and inventory.activeTab:GetText() or "Current category"
                return items, A.SourceName(bag) .. " / " .. (title ~= "" and title or "Current category") .. " (includes search filters)"
            end
        end
    end
end
local function RegisterMenus()
    local menu = LibCustomMenu
    local add, submenu = AddCustomMenuItem, AddCustomSubMenuItem
    local getBagAndIndex = ZO_Inventory_GetBagAndIndex
    menu:RegisterContextMenu(function(inventorySlot)
        local bag, slot = getBagAndIndex(inventorySlot)
        if slot == nil then return end
        local item = A.ReadItem(bag, slot)
        if not item then return end
        local uid = item.uid
        add(A.saved.selected[uid] and "Remove from Share list" or "Share item", function() A.ToggleItem(uid) end)
        local items, title = A.CategoryScope(bag)
        local entries = {}
        if items then
            entries[#entries+1] = {label = "Select category: " .. title, callback = function() A.SetItems(items, true, title) end}
            entries[#entries+1] = {label = "Deselect category: " .. title, callback = function() A.SetItems(items, false, title) end}
        end
        local source = A.SourceName(bag)
        entries[#entries+1] = {label = "Select entire " .. source, callback = function() A.SelectBag(bag, true) end}
        entries[#entries+1] = {label = "Deselect entire " .. source, callback = function() A.SelectBag(bag, false) end}
        entries[#entries+1] = {label = "Review share list", callback = A.Toggle}
        submenu("Item Share selection", entries)
    end, menu.CATEGORY_LATE)
end
function A.RegisterSettings()
    local LAM = LibAddonMenu2
    A.settingsPanel = LAM:RegisterAddonPanel("ChillItemShareOptions", {type = "panel", name = "Chill Item Share",
        displayName = "|cFF66F3Chill Item Share|r", author = "HellWhyNot", version = A.version, registerForRefresh = true})
    LAM:RegisterOptionControls("ChillItemShareOptions", {
        {type = "description", text = "Right-click an item for Share item or Item Share selection (current filtered category / entire source). /sharepost prepares chat; press Enter for each part. Storage selections can be verified and posted only while that container is open. Closed storage stays selected but blocks posting until reopened or removed."},
        {type = "editbox", name = "Message pre-text", width = "full", isMultiline = true,
            tooltip = "First message only. Counts toward the message limit. Leave blank for links only.",
            getFunc = function() return A.saved.preText end,
            setFunc = function(value) A.Invalidate(); A.saved.preText = A.NormalizePrefix(value); A.Update() end},
        {type = "editbox", name = "Delay between messages (seconds)", width = "full",
            tooltip = "0 to 60 seconds; decimals are supported. Default: 3. Zero removes extra spacing. ESO spam warnings still stop sharing for one minute. Changing this pauses a pending list; use /shareresume to continue.",
            getFunc = function() return tostring(A.DelayMilliseconds()/1000) end,
            setFunc = A.SetDelay, default = "3"},
        {type = "button", name = "Select placed furnishings", width = "full", func = function() A.SelectHouse(true) end},
        {type = "button", name = "Review share list", width = "half", func = A.Toggle},
        {type = "button", name = "Clear share list", width = "half", func = A.Clear},
        {type = "description", text = "Whole selected stacks follow their unique item IDs between accessible supported bags. Remaining stack quantities update automatically. A split-off stack is not automatically selected; if a merge replaces an ID, reselect the destination stack. Craft bag, guild bank, worn items, and other characters are not selectable. Placed furnishings can be shared while visiting their actual house; this does not retrieve furniture or imply it is tradable."},
    })
end
local function Initialize(_, addon)
    if addon ~= A.name then return end
    EM:UnregisterForEvent(A.name, LOADED)
    -- Object globals are resolved after base UI and library initialization.
    A.chat, A.inventory, A.wm = ZO_GetChatSystem(), PLAYER_INVENTORY, WINDOW_MANAGER
    A.tooltip = ItemTooltip
    A.saved = ZO_SavedVars:NewCharacterIdSettings("InventoryLinkerSaved", 1, nil, schemaDefaults)
    A.RegisterSettings(); RegisterMenus(); A.RegisterChatHooks(); A.RegisterSpamGuards()
    local createString = ZO_CreateStringId
    createString("SI_BINDING_NAME_CHILL_ITEM_SHARE_OPEN", "Review share list")
    createString("SI_BINDING_NAME_CHILL_ITEM_SHARE_POST", "Post share list")
    SLASH_COMMANDS["/sharepost"] = A.Post
    SLASH_COMMANDS["/shareresume"] = A.Resume
    SLASH_COMMANDS["/itemshare"] = A.Toggle
    SLASH_COMMANDS["/sharehouse"] = function() A.SelectHouse(true) end
    -- Preserve existing user macros after the rename.
    SLASH_COMMANDS["/givepost"] = A.Post
    SLASH_COMMANDS["/giveaway"] = A.Toggle
    EM:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, A.Update)
    EM:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
        A.Invalidate(nil, true)
        EM:UnregisterForUpdate(A.name .. "Refresh")
    end)
    EM:RegisterForEvent(A.name, EVENT_OPEN_BANK, A.ScheduleUpdate)
    EM:RegisterForEvent(A.name, EVENT_CLOSE_BANK, function()
        for _, record in pairs(A.saved.selected) do
            if type(record) == "table" and record.kind ~= "house" and record.bag ~= BACKPACK then
                A.Invalidate("Storage closed. Reopen it, then /shareresume.", true)
                break
            end
        end
        A.ScheduleUpdate()
    end)
    EM:RegisterForEvent(A.name, EVENT_INVENTORY_FULL_UPDATE, A.ScheduleUpdate)
    EM:RegisterForEvent(A.name, EVENT_HOUSING_FURNITURE_PLACED, A.ScheduleUpdate)
    EM:RegisterForEvent(A.name, EVENT_HOUSING_FURNITURE_REMOVED, A.ScheduleUpdate)
    for _, bag in ipairs(A.bags) do
        local namespace = A.name .. "Bag" .. bag
        EM:RegisterForEvent(namespace, SLOT_UPDATE, A.ScheduleUpdate)
        EM:AddFilterForEvent(namespace, SLOT_UPDATE, BAG_FILTER, bag)
    end
end
EM:RegisterForEvent(A.name, LOADED, Initialize)
