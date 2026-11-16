ChillGiveaway = {}
local A = ChillGiveaway
local NAME = "ChillGiveaway"
local PAGE_SIZE = 12
local function say(s) d("|cFF66F3[Chill Giveaway]|r " .. s) end
local function id(slot) return Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot)) end
local function scan()
    local items, byId = {}, {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_BRACKETS)
        if link and link ~= "" then
            local _, count = GetItemInfo(BAG_BACKPACK, slot)
            local item = {uid = id(slot), link = link, count = count or 1, slot = slot}
            items[#items + 1] = item
            byId[item.uid] = item
        end
    end
    table.sort(items, function(a, b) return a.link < b.link end)
    return items, byId
end
function A.Reconcile()
    local items, current = scan()
    local removed = 0
    for uid in pairs(A.saved.selected) do
        if not current[uid] then A.saved.selected[uid] = nil; removed = removed + 1 end
    end
    if removed > 0 then
        A.queue = nil; A.pending = nil
        say(string.format("Removed %d unavailable item(s). Use /givepost to rebuild your messages.", removed))
    end
    A.items, A.current = items, current
    return removed
end
-- Counting raw UTF-8 bytes is deliberately conservative: no hyperlink is ever cut.
function A.NormalizePrefix(text)
    return (tostring(text or ""):gsub("[\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
function A.Pack(parts, limit, prefix)
    prefix = A.NormalizePrefix(prefix)
    local base = prefix ~= "" and prefix .. " " or ""
    local messages, line, hasItem = {}, base, false
    for _, part in ipairs(parts) do
        if #part > limit then return nil, "An item link exceeds the chat limit." end
        if hasItem and #line + 1 + #part > limit then
            messages[#messages + 1] = line; line = ""; hasItem = false
        end
        if not hasItem and #line + #part > limit then
            return nil, "Pre-text plus the first item link exceeds the chat limit. Shorten the pre-text in Settings > Addons > Chill Giveaway."
        end
        line = line .. (hasItem and " " or "") .. part
        hasItem = true
    end
    if hasItem then messages[#messages + 1] = line end
    return messages
end
local function chatBusy()
    local entry = CHAT_SYSTEM and CHAT_SYSTEM.textEntry
    if not entry then say("Chat is not available yet."); return true end
    if entry:GetText() ~= "" then
        say("Send or clear your current chat draft first."); return true
    end
    return false
end
function A.Next()
    A.Reconcile()
    if not A.queue then say("Use /givepost to prepare the current list."); return end
    if A.nextIndex > #A.queue then say("All parts have been loaded. Use /givepost to repost."); return end
    if chatBusy() then return end
    local index = A.nextIndex
    StartChatInput(A.queue[index])
    A.pending = {text = A.queue[index], channel = CHAT_SYSTEM.currentChannel}
    if #A.queue == 1 then
        say("ONE MESSAGE ONLY. Your entire giveaway fits here. Press Enter once to send; there are no further messages.")
    else
        say(string.format("MESSAGE %d OF %d. Press Enter to send.%s", index, #A.queue,
            index < #A.queue and " The next message will load automatically." or " This is the LAST message."))
    end
end
function A.Advance(pending)
    if not pending or A.pending ~= pending or not A.queue then return end
    A.pending = nil
    A.nextIndex = A.nextIndex + 1
    if A.nextIndex <= #A.queue then
        local queue = A.queue
        -- Defer to the next UI tick so ESO finishes closing the sent chat entry.
        zo_callLater(function()
            if A.queue == queue and not A.pending then A.Next() end
        end, 0)
    else
        say("All giveaway messages submitted. Use /givepost to repost remaining items.")
    end
end
-- Server echo is a fallback for alternate chat interfaces; the pending token
-- prevents a late echo from advancing the next message a second time.
function A.OnChatMessage(_, channel, _, text, _, displayName)
    local pending = A.pending
    if pending and displayName == GetDisplayName() and channel == pending.channel
        and text == pending.text then A.Advance(pending) end
end
function A.RegisterChatHooks()
    ZO_PreHook(CHAT_SYSTEM, "SubmitTextEntry", function(self)
        local pending = A.pending
        A.submittedPending = nil
        if pending and self.textEntry:GetText() == pending.text
            and self.currentChannel == pending.channel and self:ValidateChatChannel() then
            A.submittedPending = pending
        end
    end)
    SecurePostHook(CHAT_SYSTEM, "SubmitTextEntry", function()
        local pending = A.submittedPending
        A.submittedPending = nil
        A.Advance(pending)
    end)
end
function A.BuildParts()
    local entries, byLink = {}, {}
    for _, item in ipairs(A.items) do
        if A.saved.selected[item.uid] then
            local entry = byLink[item.link]
            if not entry then
                entry = {link = item.link, count = 0}
                byLink[item.link] = entry; entries[#entries + 1] = entry
            end
            entry.count = entry.count + item.count
        end
    end
    local parts = {}
    for _, entry in ipairs(entries) do
        -- Quantity is plain text OUTSIDE the untouched complete hyperlink.
        parts[#parts + 1] = entry.link .. (entry.count > 1 and " x" .. entry.count or "")
    end
    return parts
end
function A.Post()
    A.Reconcile()
    if chatBusy() then return end
    local parts = A.BuildParts()
    if #parts == 0 then say("No items selected. Right-click backpack items and choose Giveaway."); return end
    local edit = CHAT_SYSTEM.textEntry.editControl
    local limit = edit and edit:GetMaxInputChars() or 350
    if not limit or limit < 1 then limit = 350 end
    local messages, err = A.Pack(parts, math.min(limit, 350), A.saved.preText)
    if not messages then say(err); return end
    A.queue, A.nextIndex = messages, 1
    A.Next()
end
local function label(parent, text, x, y, width)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    c:SetFont("ZoFontGame"); c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, 30); c:SetText(text)
    return c
end
local function button(parent, text, x, y, width, callback)
    local c = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetDimensions(width, 32)
    c:SetText(text); c:SetHandler("OnClicked", callback)
    return c
end
function A.Refresh()
    if not A.window then return end
    local filtered, selected = {}, 0
    for _, item in ipairs(A.items or {}) do
        if A.saved.selected[item.uid] then selected = selected + 1 end
        if not A.onlySelected or A.saved.selected[item.uid] then filtered[#filtered + 1] = item end
    end
    local pages = math.max(1, math.ceil(#filtered / PAGE_SIZE))
    A.page = math.max(1, math.min(A.page or 1, pages))
    A.status:SetText(string.format("%d selected   |   Page %d/%d", selected, A.page, pages))
    for n, row in ipairs(A.rows) do
        local item = filtered[(A.page - 1) * PAGE_SIZE + n]
        row:SetHidden(not item)
        row.item = item
        if item then
            row:SetText((A.saved.selected[item.uid] and "[X]  " or "[  ]  ") .. item.link .. (item.count > 1 and "  x" .. item.count or ""))
        end
    end
end
function A.Toggle()
    if not A.saved then return end
    A.Reconcile()
    if not A.window then A.CreateWindow() end
    A.window:SetHidden(not A.window:IsHidden())
    A.Refresh()
end
function A.CreateWindow()
    local w = WINDOW_MANAGER:CreateTopLevelWindow("ChillGiveawayWindow")
    A.window = w
    w:SetDimensions(720, 600); w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    w:SetMouseEnabled(true); w:SetMovable(true); w:SetClampedToScreen(true); w:SetHidden(true)
    local bg = WINDOW_MANAGER:CreateControlFromVirtual(nil, w, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(w)
    label(w, "|cFF66F3Chill Giveaway|r", 22, 15, 550)
    button(w, "Close", 610, 12, 85, function() w:SetHidden(true) end)
    label(w, "Click items to select. Only your backpack is included.", 22, 52, 670)
    A.status = label(w, "", 22, 84, 670)
    A.rows = {}
    for n = 1, PAGE_SIZE do
        local row = WINDOW_MANAGER:CreateControl(nil, w, CT_BUTTON)
        row:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 120 + (n - 1) * 30)
        row:SetDimensions(675, 29); row:SetFont("ZoFontGame"); row:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row:SetHandler("OnClicked", function(self)
            if not self.item then return end
            local uid = self.item.uid
            A.saved.selected[uid] = not A.saved.selected[uid] or nil
            A.queue = nil; A.pending = nil; A.Refresh()
        end)
        row:SetHandler("OnMouseEnter", function(self)
            if self.item then InitializeTooltip(ItemTooltip, self, RIGHT, -10, 0, LEFT); ItemTooltip:SetBagItem(BAG_BACKPACK, self.item.slot) end
        end)
        row:SetHandler("OnMouseExit", function() ClearTooltip(ItemTooltip) end)
        A.rows[n] = row
    end
    button(w, "Previous", 22, 489, 110, function() A.page = A.page - 1; A.Refresh() end)
    button(w, "Next page", 142, 489, 110, function() A.page = A.page + 1; A.Refresh() end)
    button(w, "Selected / All", 262, 489, 160, function() A.onlySelected = not A.onlySelected; A.page = 1; A.Refresh() end)
    button(w, "Clear selection", 437, 489, 180, function() A.saved.selected = {}; A.queue = nil; A.pending = nil; A.Refresh() end)
    button(w, "Post list", 22, 537, 170, function() A.Post() end)
    label(w, "Press Enter for each part. /givepost reposts.", 215, 542, 475)
    ZO_CreateStringId("SI_BINDING_NAME_CHILL_GIVEAWAY_OPEN", "Open item selection")
end
function A.ToggleItem(uid)
    A.Reconcile()
    local item = A.current[uid]
    if not item then say("That item is no longer in your backpack."); return end
    local selected = not A.saved.selected[uid]
    A.saved.selected[uid] = selected or nil
    A.queue = nil; A.pending = nil
    A.Refresh()
    say((selected and "Added " or "Removed ") .. item.link .. (selected and " to your giveaway." or " from your giveaway."))
end
function A.RegisterContextMenu()
    LibCustomMenu:RegisterContextMenu(function(inventorySlot)
        local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if bag ~= BAG_BACKPACK or slot == nil then return end
        local link = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
        if not link or link == "" then return end
        local uid = id(slot)
        AddCustomMenuItem(A.saved.selected[uid] and "Remove from Giveaway" or "Giveaway", function()
            A.ToggleItem(uid)
        end)
    end, LibCustomMenu.CATEGORY_LATE)
end
function A.RegisterSettings()
    local panel = "ChillGiveawayOptions"
    LibAddonMenu2:RegisterAddonPanel(panel, {
        type = "panel", name = "Chill Giveaway", displayName = "Chill Giveaway",
        author = "HellWhyNot", version = "1.0.0", registerForRefresh = true,
    })
    LibAddonMenu2:RegisterOptionControls(panel, {
        {type = "description", text = "Right-click backpack items and choose Giveaway. Use /givepost to post your remaining list. Press Enter for each message; the next part loads automatically."},
        {type = "editbox", name = "Message pre-text", width = "full", isMultiline = true,
            tooltip = "Added before the item links in the first message only. Counts toward the message limit. Leave blank for links only. Line breaks are converted to spaces.",
            getFunc = function() return A.saved.preText or "" end,
            setFunc = function(value)
                A.saved.preText = A.NormalizePrefix(value)
                A.queue = nil; A.pending = nil
            end,
        },
        {type = "button", name = "Review giveaway items", width = "half",
            func = function() A.Toggle() end},
        {type = "button", name = "Clear giveaway list", width = "half",
            func = function()
                A.saved.selected = {}; A.queue = nil; A.pending = nil
                A.Refresh(); say("Giveaway selection cleared.")
            end},
    })
end
local function scheduleRefresh()
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Refresh", 250, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
        A.Reconcile(); A.Refresh()
    end)
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addon)
    if addon ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    A.saved = ZO_SavedVars:NewCharacterIdSettings("InventoryLinkerSaved", 1, nil, {selected = {}, preText = "FREE. NO WHISPERS. ONE PER PERSON UNLESS UNCLAIMED"})
    A.page = 1
    A.RegisterContextMenu()
    A.RegisterSettings()
    A.RegisterChatHooks()
    ZO_CreateStringId("SI_BINDING_NAME_CHILL_GIVEAWAY_OPEN", "Open item selection")
    ZO_CreateStringId("SI_BINDING_NAME_CHILL_GIVEAWAY_POST", "Post current list")
    SLASH_COMMANDS["/givepost"] = A.Post
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CHAT_MESSAGE_CHANNEL, A.OnChatMessage)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() A.Reconcile(); A.Refresh() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag)
        if bag == BAG_BACKPACK then scheduleRefresh() end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_INVENTORY_FULL_UPDATE, scheduleRefresh)
end)
