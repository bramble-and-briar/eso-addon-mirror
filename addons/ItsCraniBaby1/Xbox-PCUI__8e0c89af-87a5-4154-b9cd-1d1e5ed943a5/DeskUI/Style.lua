local A, C = DeskUI, DeskUI.Core
A.Style = {}
local S = A.Style
S.palette = {
    panel = {0.015, 0.018, 0.018, 0.82},
    line = {0.50, 0.45, 0.27, 0.75}, accent = {0.78, 0.74, 0.53, 1},
    text = {0.94, 0.93, 0.88, 1}, muted = {0.66, 0.65, 0.55, 1},
}
local P = S.palette

function S.Panel(parent, x, y, w, h, color, border)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetDimensions(w, h)
    c:SetCenterColor(unpack(color or P.panel))
    c:SetEdgeColor(unpack(border and P.line or {0, 0, 0, 0}))
    if border then
        c:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 16)
        c:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    else c:SetEdgeTexture("", 1, 1, 1) end
    c:SetMouseEnabled(false)
    return c
end

function S.Label(parent, x, y, w, h, text, color, size, bold)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetDimensions(w, h)
    c:SetFont((bold and "$(BOLD_FONT)" or "$(MEDIUM_FONT)") .. "|" .. (size or 18)
        .. (bold and size and size >= 24 and "|soft-shadow-thick" or "|soft-shadow-thin"))
    c:SetColor(unpack(color or P.text)); c:SetText(text or ""); c:SetMouseEnabled(false)
    return c
end

function S.Rule(parent, x, y, width)
    return S.Texture(parent, x, y, width, 4, "EsoUI/Art/Miscellaneous/horizontalDivider.dds")
end

function S.Texture(parent, x, y, width, height, path)
    local texture = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    texture:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); texture:SetDimensions(width, height)
    texture:SetTexture(path); texture:SetMouseEnabled(false)
    return texture
end

function S.Button(parent, x, y, w, h, text, callback)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetDimensions(w, h)
    c.background = S.Panel(c, 0, 0, w, h, {0, 0, 0, 0.18})
    c.label = S.Label(c, 6, 7, w - 12, h - 8, text, P.accent, 17, true)
    c:SetMouseEnabled(true); c:SetHandler("OnClicked", callback)
    c:SetHandler("OnMouseEnter", function() c.background:SetCenterColor(0.19, 0.23, 0.22, 0.8) end)
    c:SetHandler("OnMouseExit", function() c.background:SetCenterColor(0, 0, 0, 0.18) end)
    return c
end

function S.Icon(parent, x, y, size, texture)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); c:SetDimensions(size, size)
    c:SetMouseEnabled(false)
    if texture then c:SetTexture(texture) end
    return c
end

function S.Card(parent, x, y, heading)
    local card = {}
    card.root = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    card.root:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); card.root:SetDimensions(416, 570)
    S.Panel(card.root, 0, 0, 416, 570, nil, true)
    S.Label(card.root, 10, 12, 396, 24, heading, P.accent, 16, true):SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    S.Rule(card.root, 12, 44, 392)
    card.kind = S.Label(card.root, 16, 55, 332, 25, "", P.accent, 17)
    card.icon = S.Icon(card.root, 364, 52, 34)
    card.title = S.Label(card.root, 16, 96, 384, 65, "Select an item", P.text, 22, true)
    card.title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    S.Rule(card.root, 16, 168, 384)
    card.stats = S.Label(card.root, 16, 180, 384, 48, "", P.accent, 17, true)
    card.stats:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    card.viewport = WINDOW_MANAGER:CreateControl(nil, card.root, CT_SCROLL)
    card.viewport:SetAnchor(TOPLEFT, card.root, TOPLEFT, 16, 240); card.viewport:SetDimensions(384, 277)
    card.viewport:SetMouseEnabled(true)
    card.body = S.Label(card.viewport, 0, 0, 384, 277, "", P.accent, 17)
    card.body:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    card.offset, card.maxScroll = 0, 0
    local function Scroll(delta)
        card.offset = math.max(0, math.min(card.maxScroll, card.offset - delta * 48))
        card.viewport:SetVerticalScroll(card.offset)
    end
    card.viewport:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    S.Button(card.root, 16, 530, 180, 28, "Details up", function() Scroll(3) end)
    S.Button(card.root, 210, 530, 190, 28, "Details down", function() Scroll(-3) end)
    A.MakeMovable(card.root, heading, parent, x, y, 416)
    return card
end

function S.FillCard(card, item, empty)
    local stamp = item and (item.link .. ":" .. item.stack .. ":" .. tostring(item.locked)
        .. ":" .. tostring(item.slotLabel) .. ":" .. (A.detailRevision or 0)) or empty
    if card.stamp == stamp then return end
    card.stamp = stamp
    card.title:SetText(item and item.name or empty)
    if item then card.title:SetColor(C.QualityColor(item.quality))
    else card.title:SetColor(unpack(P.text)) end
    card.kind:SetText(item and (item.slotLabel or item.kind) or "")
    card.icon:SetHidden(not item)
    if item then card.icon:SetTexture(item.icon) end
    if item then
        local stat, statName = C.Stat(item)
        local cp = C.Try("GetItemLinkRequiredChampionPoints", item.link) or 0
        local level = cp > 0 and ("CP " .. cp) or ("LEVEL " .. (C.Try("GetItemLinkRequiredLevel", item.link) or "-"))
        local statValue = statName == "QUANTITY" and item.stack or (stat or "-")
        card.stats:SetText(statName .. " " .. statValue .. "    " .. level .. "\nVALUE " .. item.value .. " gold")
        card.body:SetText(C.Description(item))
    else
        card.stats:SetText("")
        card.body:SetText("Choose an item to inspect its details.\n\nEquippable backpack items are compared with the matching worn slot. Rings compare with Ring 1; weapons use the active weapon bar.")
    end
    card.body:SetHeight(math.max(277, card.body:GetTextHeight()))
    card.maxScroll = math.max(0, card.body:GetTextHeight() - 277)
    card.offset = 0; card.viewport:SetVerticalScroll(0)
end

function A.BuildLayout()
    A.items, A.filtered, A.rows, A.equipment = {}, {}, {}, {}
    A.category, A.sortKey, A.offset, A.descending = "All", "name", 0, false
    A.categories, A.sortButtons, A.gearSlots = {}, {}, {}
    local root = WINDOW_MANAGER:CreateTopLevelWindow("DeskUIWindow")
    A.root = root
    root:SetDimensions(1840, 1000); root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    root:SetHidden(true); root:SetMouseEnabled(true); root:SetClampedToScreen(true)
    local sw, sh = GuiRoot:GetDimensions()
    root:SetScale(math.min(1, (sw - 24) / 1840, (sh - 24) / 1000))
    -- The world remains visible between the equipment, cards, and item list.
    local progress = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    progress:SetAnchor(TOPLEFT, root, TOPLEFT, 16, 20); progress:SetDimensions(320, 70)
    A.level = S.Label(progress, 0, 0, 320, 40, "", P.text, 27, true)
    S.Panel(progress, 0, 44, 250, 5, {0.28, 0.25, 0.15, 0.9})
    A.experience = S.Panel(progress, 0, 44, 1, 5, {0.39, 0.61, 0.64, 1})
    A.MakeMovable(progress, "progress", root, 16, 20, 320)
    A.pageTitle = S.Label(root, 1200, 184, 620, 38, "INVENTORY", P.accent, 24, true)
    local gear = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    gear:SetAnchor(TOPLEFT, root, TOPLEFT, 4, 238); gear:SetDimensions(244, 705)
    S.Panel(gear, 0, 0, 244, 705, {0, 0, 0, 0.44})
    S.Label(gear, 12, 6, 220, 32, "EQUIPPED", P.text, 23, true)
    S.Rule(gear, 12, 44, 220)
    S.Label(gear, 12, 44, 220, 24, "APPAREL", P.accent, 15, true)
    local silhouette = C.Try("GetUnitSilhouetteTexture", "player")
    if silhouette then A.silhouette = S.Texture(gear, 94, 145, 64, 256, silhouette) end
    S.Label(gear, 12, 365, 220, 28, "ACCESSORIES", P.accent, 17, true)
    S.Rule(gear, 12, 399, 220)
    S.Label(gear, 12, 489, 220, 28, "WEAPONS", P.accent, 17, true)
    S.Rule(gear, 12, 527, 220)
    for _, definition in ipairs(C.Slots) do
        local name, title, icon, x, y = unpack(definition)
        x, y = x - 4, y - 238
        local slot = _G["EQUIP_SLOT_" .. name]
        if slot ~= nil then
            local button = S.Button(gear, x, y, 56, 56, "", function()
                local item = A.equipment[slot]
                if item then A.Select(item); A.Render() end
            end)
            button.fallback = "/esoui/art/characterwindow/gearslot_" .. icon .. ".dds"
            button.icon = S.Icon(button, 5, 5, 46, button.fallback)
            button.slot = slot
            S.Label(gear, x - 7, y + 57, 78, 19, title, P.muted, 13):SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            A.gearSlots[#A.gearSlots + 1] = button
        end
    end
    A.MakeMovable(gear, "equipment", root, 4, 238, 244)
    A.equipmentPanel = gear
    A.compareCard = S.Card(root, 336, 282, "EQUIPPED COMPARISON")
    A.itemCard = S.Card(root, 768, 282, "SELECTED ITEM")
    A.detailTitle, A.detailBody = A.itemCard.title, A.itemCard.body
    local inventory = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    inventory:SetAnchor(TOPLEFT, root, TOPLEFT, 1200, 238); inventory:SetDimensions(624, 750)
    A.inventoryPanel = inventory
    S.Panel(inventory, 0, 0, 624, 674, {0, 0, 0, 0.70})
    S.Label(inventory, 20, 6, 400, 35, "ITEMS", P.text, 25, true)
    S.Rule(inventory, 16, 45, 592)
    -- The shell supplies the PC item-category icon bar below the heading.
    S.Rule(inventory, 16, 94, 592)
    S.Panel(inventory, 16, 106, 592, 34, {0.14, 0.14, 0.10, 0.55}, true)
    S.Label(inventory, 26, 112, 65, 24, "Search", P.muted, 16)
    A.search = WINDOW_MANAGER:CreateControl("DeskUISearch", inventory, CT_EDITBOX)
    A.search:SetAnchor(TOPLEFT, inventory, TOPLEFT, 94, 111); A.search:SetDimensions(502, 28)
    A.search:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin"); A.search:SetColor(unpack(P.text))
    A.search:SetMouseEnabled(true); A.search:SetEditEnabled(true); A.search:SetMaxInputChars(100)
    A.ConfigureMenuEditBox(A.search)
    A.search:SetHandler("OnTextChanged", function() A.Filter(true) end)
    A.search:SetHandler("OnEscape", function(box) box:LoseFocus(); A.Close() end)
    A.search:SetHandler("OnEnter", function(box) box:LoseFocus() end)
    local function Sort(key)
        if A.sortKey == key then A.descending = not A.descending else A.sortKey, A.descending = key, false end
        A.Filter(true)
    end
    A.sortButtons.name = S.Button(inventory, 46, 145, 367, 32, "NAME", function() Sort("name") end)
    A.sortButtons.stack = S.Button(inventory, 417, 145, 65, 32, "QTY", function() Sort("stack") end)
    A.sortButtons.value = S.Button(inventory, 488, 145, 118, 32, "VALUE", function() Sort("value") end)
    for i = 1, 8 do
        local row = WINDOW_MANAGER:CreateControl(nil, inventory, CT_CONTROL)
        row:SetAnchor(TOPLEFT, inventory, TOPLEFT, 16, 182 + (i - 1) * 52); row:SetDimensions(592, 52)
        row:SetMouseEnabled(true)
        row.background = S.Panel(row, 0, 0, 592, 52, {0, 0, 0, 0.10})
        row.selection = S.Texture(row, 0, 0, 592, 52, "EsoUI/Art/Miscellaneous/listItem_selectedHighlight.dds")
        row.selection:SetHidden(true)
        row.icon = S.Icon(row, 5, 6, 40)
        row.nameLabel = S.Label(row, 55, 14, 338, 27, "", P.text, 18, true)
        row.nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.stackLabel = S.Label(row, 407, 14, 60, 27, "", P.text, 17)
        row.valueLabel = S.Label(row, 480, 14, 100, 27, "", P.accent, 17)
        row:SetHandler("OnMouseEnter", function(control)
            if control.item and A.settings.hoverSelection ~= false then A.Select(control.item); A.Render() end
        end)
        row:SetHandler("OnMouseUp", function(control, button, inside)
            if button == MOUSE_BUTTON_INDEX_LEFT and inside and control.item then A.Select(control.item); A.Render() end
        end)
        row:SetHandler("OnMouseWheel", function(_, delta) A.Scroll(delta) end)
        A.rows[i] = row
    end
    S.Rule(inventory, 16, 608, 592)
    A.count = S.Label(inventory, 16, 617, 590, 46, "", P.accent, 16)
    A.empty = S.Label(inventory, 50, 322, 520, 80, "", P.muted, 21)
    S.Button(inventory, 400, 678, 98, 33, "Previous", function() A.Scroll(4) end)
    S.Button(inventory, 508, 678, 100, 33, "Next", function() A.Scroll(-4) end)
    A.MakeMovable(inventory, "inventory", root, 1200, 238, 624)
    A.inventoryHint = S.Label(root, 490, 880, 680, 55, "Hover or click to inspect  /  Scroll inside a card for more details", P.muted, 16)
    S.Label(inventory, 16, 724, 600, 25, "Mouse wheel: browse    /    Back: close", P.accent, 17)
    inventory:SetMouseEnabled(true)
    inventory:SetHandler("OnMouseWheel", function(_, delta) A.Scroll(delta) end)
    A.pages = {Inventory = {controls = {gear, A.compareCard.root, A.itemCard.root, inventory, A.inventoryHint}}}
    A.activePage, A.navigation = "Inventory", {}
    A.BuildShell()

end
