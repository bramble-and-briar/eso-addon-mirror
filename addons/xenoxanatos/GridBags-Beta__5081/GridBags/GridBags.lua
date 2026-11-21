local ADDON = "GridBags"
local VERSION = "0.15.3"
local G = { panels = {}, sceneName = nil }
GridBags = G
local WM, EM = WINDOW_MANAGER, EVENT_MANAGER
local ROWS, GAP, GRID_Y = 7, 5, 158
local DEFAULTS = { enabled = true, showGold = true, columns = 8, size = 48, sort = "name", externalFilters = true, embeddedFilters = true, snapshots = {} }
local C, S = GridBagsCompatibility, GridBagsSnapshots
local A = GridBagsAdvancedFilters

local function Label(parent, text, x, y, font)
    local c = WM:CreateControl(nil, parent, CT_LABEL)
    c:SetFont(font or "ZoFontGame")
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetText(text)
    return c
end

local function Button(parent, text, x, y, width, callback)
    local c = WM:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    c:SetDimensions(width, 28)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetText(text)
    c:SetHandler("OnClicked", callback)
    GridBagsHelp:Auto(c,text)
    return c
end

local function Backdrop(parent)
    local c = WM:CreateControl(nil, parent, CT_BACKDROP)
    c:SetAnchorFill(parent)
    c:SetCenterColor(0.035, 0.04, 0.05, 0.99)
    c:SetEdgeColor(0.35, 0.31, 0.23, 1)
    c:SetEdgeTexture("", 1, 1, 1, 0)
    return c
end

function G:IsBankScene()
    return self.sceneName == "bank" and IsBankOpen() and GetBankingBag() == BAG_BANK
end

function G:IsSupportedScene()
    if self.sceneName == "inventory" and PLAYER_INVENTORY and PLAYER_INVENTORY.selectedTabType
        and PLAYER_INVENTORY.selectedTabType ~= INVENTORY_BACKPACK then return false end
    return not IsInGamepadPreferredMode()
        and (self.sceneName == "inventory" or self:IsBankScene())
end

function G:IsActive()
    return self.saved.enabled and self:IsSupportedScene()
end

function G:ReleaseSearchFocus()
    for _, panel in ipairs(self.panels) do panel.search:LoseFocus() end
end

function G:QueueRefresh()
    EM:UnregisterForUpdate(ADDON .. "Refresh")
    if not self:IsActive() then self:Refresh(); return end
    EM:RegisterForUpdate(ADDON .. "Refresh", 60, function()
        EM:UnregisterForUpdate(ADDON .. "Refresh")
        self:Refresh()
    end)
end

function G:OpenInventoryTools(section)
    self.saved.enabled = true; self.nativeFiltersMode = false
    if SCENE_MANAGER.Show then SCENE_MANAGER:Show(IsBankOpen() and GetBankingBag() == BAG_BANK and "bank" or "inventory") end
    EM:RegisterForUpdate("GridBagsSettingsShortcut", 1, function()
        EM:UnregisterForUpdate("GridBagsSettingsShortcut")
        if section == "mark" then self.planMode = true end
        self:Refresh()
        if section == "planner" or section == "profiles" then
            GridBagsRoutingUI:Show()
            if section == "profiles" then GridBagsRoutingUI:Profiles(GridBagsRoutingUI.profileButton) end
        end
        if section == "gold" then GridBagsGoldUI:Show() end
        if section == "crafting" then GridBagsCraftingUI:Show() end
        if section == "deliveries" then GridBagsDeliveryUI:Show() end
        if section == "protected" then GridBagsProtectionUI:Show() end
        if section == "gather" then GridBagsRecipeGatherUI:Show() end
        if section == "history" or section == "preview" or section == "report" or section == "backups" then
            GridBagsToolsUI:Show(section == "backups" and "history" or section)
            if section == "backups" then GridBagsToolsUI:ConfigMenu(GridBagsToolsUI.configButton) end
        end
    end)
end

local function IsCurrent(cell)
    if cell.readOnly or not G:IsActive() or G.root:IsHidden() then return false end
    if cell.bagId == BAG_BACKPACK and S:GetSelected(G) then return false end
    if not cell.itemIdentity or cell:IsHidden() then return false end
    if cell.bagId ~= BAG_BACKPACK and not G:IsBankScene() then return false end
    return GetItemId(cell.bagId, cell.slotIndex) ~= 0
        and Id64ToString(GetItemUniqueId(cell.bagId, cell.slotIndex)) == cell.itemIdentity
end

function G:CreateCell(panel, index, readOnly)
    -- A real inventory row allows Research Assistant/CraftStore decorators to run.
    local row = WM:CreateControlFromVirtual(ADDON .. panel.key .. (readOnly and "SavedRow" or "Row") .. index,
        panel.control, "ZO_PlayerInventorySlot")
    row:SetMouseEnabled(false)
    row.isGrid = true
    local cell = row:GetNamedChild("Button")
    cell.row = row
    cell:SetMouseEnabled(true)
    -- Live action handlers belong to ESO's inherited template. Calling them from
    -- an addon wrapper taints PickupInventoryItem / UseItem. Never replace them.
    if readOnly then
        for _, event in ipairs({ "OnClicked", "OnMouseDoubleClick", "OnDragStart", "OnReceiveDrag" }) do
            cell:SetHandler(event, function() end)
        end
        cell:SetHandler("OnMouseEnter", function(c)
          if c.snapshotItem then
            InitializeTooltip(ItemTooltip, c, TOPRIGHT, 0, 0, TOPLEFT)
            ItemTooltip:SetLink(c.snapshotItem.link)
            ItemTooltip:AddLine("Read-only character snapshot")
            if c.snapshotItem.equipSlot then
                ItemTooltip:AddLine(GridBagsEquipment:SlotName(c.snapshotItem.equipSlot))
            end
            GridBagsEquipment:Show(self, c)
          end
        end)
        cell:SetHandler("OnMouseExit", function() ClearTooltip(ItemTooltip); GridBagsEquipment:Clear() end)
    end
    cell:SetHandler("OnMouseWheel", function(_, delta) self:Wheel(panel, delta) end)
    cell.frame = Backdrop(row)
    cell.frame:SetDrawLayer(DL_BACKGROUND)
    cell.status = Label(cell, "", 1, 0, "ZoFontGameSmall")
    cell.status:SetDrawLayer(DL_OVERLAY)
    cell.status:SetMouseEnabled(false)
    cell.planButton = Button(row, "P", 0, 0, 20, function()
        if cell.routingItem then GridBagsRoutingUI:Mark(panel, cell.routingItem) end
    end)
    cell.planButton:ClearAnchors()
    cell.planButton:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
    cell.planButton:SetDimensions(20, 20)
    cell.planButton:SetDrawLayer(DL_OVERLAY)
    cell.planButton:SetHidden(true)
    return cell
end

function G:CreatePanel(key, title)
    local p = { key = key, title = title, scrollRow = 0, cells = {}, liveCells = {}, savedCells = {}, filter = nil, query = "" }
    p.control = WM:CreateControl(ADDON .. key, self.root, CT_CONTROL)
    p.control:SetMouseEnabled(true)
    p.control:SetHandler("OnMouseWheel", function(_, delta) self:Wheel(p, delta) end)
    p.titleLabel = Label(p.control, title, 4, 0, "ZoFontWinH2")
    p.titleLabel:SetMaxLineCount(1)
    p.titleLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    p.count = Label(p.control, "", 4, 30)
    p.goldLabel = Label(p.control, "", 0, 0, "ZoFontGameSmall")
    p.sourceLabel = Label(p.control, "", 4, 126, "ZoFontGameSmall")
    p.sourceLabel:SetMaxLineCount(1)
    p.sourceLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if key == "Backpack" then
        p.characterButton = Button(p.control, "Character...", 270, 0, 126, function(c) S:ShowSelector(self, c) end)
        p.compareButton = Button(p.control, "Compare...", 300, 58, 112, function(c) GridBagsEquipment:Menu(self, c) end)
    end
    Label(p.control, "Search", 4, 63)
    local searchBG = WM:CreateControl(nil, p.control, CT_BACKDROP)
    searchBG:SetDimensions(230, 28)
    searchBG:SetAnchor(TOPLEFT, p.control, TOPLEFT, 64, 58)
    searchBG:SetCenterColor(0.1, 0.11, 0.13, 1)
    searchBG:SetEdgeColor(0.4, 0.4, 0.4, 1)
    searchBG:SetEdgeTexture("", 1, 1, 1, 0)
    -- Native edit controls manage typing focus separately from raw keyboard
    -- capture. SetKeyboardEnabled(true) swallows scene keys even when unfocused.
    p.search = WM:CreateControlFromVirtual(ADDON .. key .. "Search", searchBG, "ZO_DefaultEditForBackdrop")
    p.search:SetAnchor(TOPLEFT, searchBG, TOPLEFT, 6, 2)
    p.search:SetAnchor(BOTTOMRIGHT, searchBG, BOTTOMRIGHT, -6, -2)
    p.search:SetFont("ZoFontGame")
    p.search:SetMaxInputChars(100)
    p.search:SetMouseEnabled(true)
    p.search:SetEditEnabled(true)
    GridBagsHelp:Bind(p.search,"Search names in this panel, including saved snapshots. Click to type; Escape or Enter releases typing focus. Search changes the view, not routing rules or inventory contents.")
    p.search:LoseFocus()
    -- Clicking the padding should focus the input too.
    searchBG:SetMouseEnabled(true)
    searchBG:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:ReleaseSearchFocus()
            p.search:TakeFocus()
        end
    end)
    p.searchBackground = searchBG
    p.search:SetHandler("OnTextChanged", function(c)
        p.query = zo_strlower(c:GetText())
        p.scrollRow = 0
        self:QueueRefresh()
    end)
    p.search:SetHandler("OnEscape", function(c) c:LoseFocus() end)
    p.search:SetHandler("OnEnter", function(c) c:LoseFocus() end)

    local filters = {
        { "All" }, { "Weapons", ITEMFILTERTYPE_WEAPONS },
        { "Armor", ITEMFILTERTYPE_ARMOR }, { "Use", ITEMFILTERTYPE_CONSUMABLE },
        { "Craft", ITEMFILTERTYPE_CRAFTING }, { "Junk", "junk" },
    }
    p.filters = {}
    for i, entry in ipairs(filters) do
        local filter = entry[2]
        p.filters[i] = Button(p.control, entry[1], (i - 1) * 66, 94, 64, function()
            p.filter = filter
            p.scrollRow = 0
            self:Refresh()
        end)
    end
    p.rangeLabel = Label(p.control, "", 4, 0)
    p.scrollbar = WM:CreateControl(ADDON .. key .. "ScrollBar", p.control, CT_SLIDER)
    p.scrollbar:SetOrientation(ORIENTATION_VERTICAL)
    p.scrollbar:SetValueStep(1)
    p.scrollbar:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator.dds", "EsoUI/Art/Miscellaneous/scrollbox_elevator.dds", 14, 32, 0, 0, 1, 1)
    Backdrop(p.scrollbar)
    p.scrollbar:SetHandler("OnValueChanged", function(_, value)
        if p.syncingScroll then return end
        self:ScrollRows(p, math.floor(value + 0.5) - p.scrollRow)
    end)
    p.scrollbar:SetHandler("OnMouseWheel", function(_, delta) self:Wheel(p, delta) end)
    self.panels[#self.panels + 1] = p
    if key == "Backpack" then p.savedFilterUI = GridBagsSnapshotFilters:CreateUI(self, p.control) end
    return p
end

function G:ScrollRows(panel, direction)
    panel.scrollRow = zo_clamp(panel.scrollRow + direction, 0, panel.maxScrollRow or 0)
    self:Refresh()
end

function G:Wheel(panel, delta)
    if delta == 0 then return end
    self:ScrollRows(panel, delta > 0 and -1 or 1)
end

local function Matches(panel, item)
    if panel.query ~= "" and not string.find(item.name, panel.query, 1, true) then return false end
    if panel.filter == "junk" then return item.junk end
    if panel.filter == nil then return true end
    for _, filter in ipairs(item.filters) do
        if filter == panel.filter then return true end
    end
    return false
end

function G:ReadItems(panel, bags)
    local items, used, capacity = {}, 0, 0
    panel.filterError = false
    local snapshot = panel.key == "Backpack" and S:GetSelected(self)
    if snapshot then
        if snapshot.afFilters then GridBagsSnapshotFilters:Normalize(snapshot, panel) end
        used, capacity = snapshot.used, snapshot.capacity
        for _, stored in ipairs(snapshot.items) do
            if Matches(panel, stored) and GridBagsSnapshotFilters:Matches(stored, panel.snapshotSelection) then
                -- Sorting and rendering must never mutate the saved record.
                local copy = {}
                for k, v in pairs(stored) do copy[k] = v end
                copy.snapshot = true
                items[#items + 1] = copy
            end
        end
    else
      for _, bag in ipairs(bags) do
        used = used + GetNumBagUsedSlots(bag)
        capacity = capacity + GetBagUseableSize(bag)
        for slot = 0, GetBagSize(bag) - 1 do
            if GetItemId(bag, slot) ~= 0 then
                local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bag, slot))
                local icon, stack, _, usable, locked, _, _, _, quality = GetItemInfo(bag, slot)
                local item = { bag = bag, slot = slot, name = zo_strlower(name),
                        icon = icon, stack = stack, usable = usable, locked = locked,
                        quality = quality, identity = Id64ToString(GetItemUniqueId(bag, slot)),
                        junk = IsItemJunk(bag, slot), playerLocked = IsItemPlayerLocked(bag, slot),
                        stolen = IsItemStolen(bag, slot), filters = { GetItemFilterTypeInfo(bag, slot) } }
                if Matches(panel, item) and C:Matches(self, panel, bag, slot) then
                    items[#items + 1] = item
                end
            end
        end
      end
    end
    table.sort(items, function(a, b)
        if self.saved.sort == "stack" and a.stack ~= b.stack then return a.stack > b.stack end
        if self.saved.sort == "type" and a.filters[1] ~= b.filters[1] then return (a.filters[1] or 0) < (b.filters[1] or 0) end
        if self.saved.sort == "quality" and a.quality ~= b.quality then return a.quality > b.quality end
        if self.saved.sort ~= "slot" and a.name ~= b.name then return a.name < b.name end
        if a.snapshot then return a.order < b.order end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return items, used, capacity
end

function G:RefreshPanel(panel, bags)
    local items, used, capacity = self:ReadItems(panel, bags)
    local pageSize = self.saved.columns * ROWS
    panel.maxScrollRow = math.max(0, math.ceil(#items / self.saved.columns) - ROWS)
    panel.scrollRow = zo_clamp(panel.scrollRow, 0, panel.maxScrollRow)
    local first = panel.scrollRow * self.saved.columns
    panel.syncingScroll = true
    panel.scrollbar:SetMinMax(0, panel.maxScrollRow)
    panel.scrollbar:SetValue(panel.scrollRow)
    panel.scrollbar:SetHidden(panel.maxScrollRow == 0)
    panel.syncingScroll = false
    panel.count:SetText(string.format("%d / %d slots used   |   %d matching", used, capacity, #items))
    local snapshot = panel.key == "Backpack" and S:GetSelected(self)
    local gold
    if snapshot then gold = snapshot.gold else gold = S:ReadGold(panel.key == "Bank") end
    local amount = gold ~= nil and string.format("%.0f", gold):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") or "not captured"
    panel.goldLabel:SetText("Gold: " .. amount .. (snapshot and " (saved)" or ""))
    panel.goldLabel:SetHidden(self.saved.showGold == false)
    if snapshot then
        panel.titleLabel:SetText(snapshot.name .. " (snapshot)")
        local minutes = math.max(0, math.floor((GetTimeStamp() - snapshot.updatedAt) / 60))
        panel.sourceLabel:SetText(string.format("READ ONLY | Updated %s | %d min ago", GetDateStringFromTimestamp(snapshot.updatedAt), minutes))
    else
        panel.titleLabel:SetText(panel.title .. " (LIVE)")
        panel.sourceLabel:SetText(panel.filterError and "External filter error - see chat" or
            (self.saved.externalFilters and "LIVE | Native / addon filters enabled" or "LIVE | Grid filters only"))
    end
    panel.rangeLabel:SetText(string.format("%d-%d of %d", #items == 0 and 0 or first + 1, math.min(first + pageSize, #items), #items))
    for i, control in ipairs(panel.filters) do
        local active = (i == 1 and panel.filter == nil) or
            (i == 2 and panel.filter == ITEMFILTERTYPE_WEAPONS) or
            (i == 3 and panel.filter == ITEMFILTERTYPE_ARMOR) or
            (i == 4 and panel.filter == ITEMFILTERTYPE_CONSUMABLE) or
            (i == 5 and panel.filter == ITEMFILTERTYPE_CRAFTING) or
            (i == 6 and panel.filter == "junk")
        control:SetAlpha(active and 1 or 0.55)
    end
    local pool = snapshot and panel.savedCells or panel.liveCells
    for _, c in ipairs(panel.cells) do c:SetHidden(true); c.row:SetHidden(true) end
    panel.cells = pool
    for i = 1, pageSize do
        local c = panel.cells[i]
        if not c then c = self:CreateCell(panel, i, snapshot ~= nil and snapshot ~= false); pool[i] = c end
        c.row:SetDimensions(self.saved.size, self.saved.size)
        c.row:ClearAnchors()
        c.row:SetAnchor(TOPLEFT, panel.control, TOPLEFT,
            ((i - 1) % self.saved.columns) * (self.saved.size + GAP),
            (self.gridY or GRID_Y) + math.floor((i - 1) / self.saved.columns) * (self.saved.size + GAP))
        local item = items[first + i]
        c:SetHidden(item == nil)
        c.row:SetHidden(item == nil)
        if item then
            c.routingItem = item
            c.planButton:SetHidden(not self.planMode or item.equipSlot ~= nil)
            c.readOnly = item.snapshot or false
            c:SetMouseEnabled(true)
            c.snapshotItem = item.snapshot and item or nil
            c.itemIdentity = item.identity
            C:HideDecorations(c)
            if item.snapshot then
                c.bagId, c.slotIndex, c.slotType, c.dataEntry = nil, nil, nil, nil
                local cooldown = c:GetNamedChild("Cooldown")
                if cooldown then cooldown:ResetCooldown(); cooldown:SetHidden(true) end
                ZO_ItemSlot_SetupSlot(c, item.stack, item.icon, true, false)
            else
                C:SetupRow(self, panel, c, item)
                ZO_Inventory_BindSlot(c, item.bag == BAG_BACKPACK and SLOT_TYPE_ITEM or SLOT_TYPE_BANK_ITEM,
                    item.slot, item.bag)
                ZO_Inventory_SetupSlot(c, item.stack, item.icon, item.usable, item.locked)
            end
            c:ClearAnchors()
            c:SetAnchorFill(c.row)
            c:SetDimensions(self.saved.size, self.saved.size)
            local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, item.quality)
            c.frame:SetEdgeColor(r, g, b, 1)
            local status = ""
            if item.playerLocked then status = status .. "L" end
            if item.stolen then status = status .. "S" end
            if item.junk then status = status .. "J" end
            c.status:SetText(status)
        else
            c.routingItem = nil
            c.planButton:SetHidden(true)
            c.itemIdentity = nil
            c.snapshotItem = nil
            C:HideDecorations(c)
        end
    end
    for i = pageSize + 1, #panel.cells do
        panel.cells[i]:SetHidden(true)
        panel.cells[i].row:SetHidden(true)
        panel.cells[i].itemIdentity = nil
    end
end

function G:ClearHover()
    GridBagsEquipment:Clear()
    for _, panel in ipairs(self.panels) do
        for _, cell in ipairs(panel.cells) do
            if ItemTooltip:GetOwner() == cell or ItemTooltip:GetOwner() == cell.row or WM:GetMouseOverControl() == cell then
                cell:GetHandler("OnMouseExit")(cell)
            end
        end
    end
end

function G:Refresh()
    if not self:IsActive() then
        if GridBagsLayout.owner then GridBagsLayout:Stop() end
        if GridBagsGoldUI.window then GridBagsGoldUI:Close() end
        if GridBagsToolsUI.window then GridBagsToolsUI:Close() end
        if GridBagsRoutingUI.window then GridBagsRoutingUI:Close() end
        if GridBagsCraftingUI.window then GridBagsCraftingUI:Close() end
        if GridBagsDeliveryUI.window then GridBagsDeliveryUI:Close() end
        if GridBagsProtectionUI.window then GridBagsProtectionUI:Close() end
        if GridBagsRecipeGatherUI.window and not GridBagsRecipeGatherUI.allowCrafting then GridBagsRecipeGatherUI:Close() end
        A:Restore()
        C:NativeVisibility(self, true)
        self:ClearHover()
        self.root:SetHidden(true)
        self:ReleaseSearchFocus()
        self.returnToGrid:SetHidden(not (not self.saved.enabled and self:IsSupportedScene()))
        return
    end
    if self.nativeFiltersMode then
        GridBagsLayout:Stop()
        GridBagsGoldUI:Close()
        GridBagsToolsUI:Close()
        GridBagsRoutingUI:Close()
        GridBagsCraftingUI:Close()
        GridBagsDeliveryUI:Close()
        GridBagsProtectionUI:Close()
        if not GridBagsRecipeGatherUI.allowCrafting then GridBagsRecipeGatherUI:Close()end
        A:Restore()
        C:NativeVisibility(self, true)
        self:ClearHover()
        self.root:SetHidden(true)
        self:ReleaseSearchFocus()
        self.returnToGrid:SetHidden(false)
        return
    end
    self.returnToGrid:SetHidden(true)
    C:NativeVisibility(self, false)
    -- Keep native context-menu action closures bound to their original cells.
    if ZO_Menu and not ZO_Menu:IsHidden() then self:QueueRefresh(); return end
    self:ClearHover()
    local banking = self:IsBankScene()
    self.markButton:SetText(self.planMode and "Mark items: ON" or "Mark items: off")
    self.pauseButton:SetText(GridBagsActivity:IsPaused() and "Resume transfers" or "Pause transfers")
    if banking then self.selectedCharacter = S.characterId end
    local selectedSnapshot = S:GetSelected(self)
    self.filtersButton:SetEnabled(true)
    if selectedSnapshot then
        self.hintLabel:SetText(selectedSnapshot.afFilters and "Read-only snapshot | Filter saved classifications and search saved item names" or
            "Detailed snapshot filters need a fresh capture with Advanced Filters enabled. Log into the character or revisit the banker.")
    else
        self.hintLabel:SetText("Double-click: use / transfer   |   Right-click: actions   |   Wheel: scroll   |   L: locked  S: stolen  J: junk")
    end
    local panelWidth = math.max(422, self.saved.columns * (self.saved.size + GAP) + 17)
    local filterHeight = A:ShouldShow(self) and 176 or 0
    self.gridY = GRID_Y + (selectedSnapshot and 170 or 0)
    local footerY = self.gridY + ROWS * (self.saved.size + GAP) + 8
    self.root:SetDimensions(panelWidth * (banking and 2 or 1) + (banking and 64 or 40), footerY + 178 + filterHeight)
    -- Fit smaller displays and larger UI scaling while retaining all controls.
    self.root:SetScale(math.min(1, (GuiRoot:GetWidth() - 50) / self.root:GetWidth(),
        (GuiRoot:GetHeight() - 90) / self.root:GetHeight()))
    GridBagsLayout:Apply()
    self.depositCurrency:SetHidden(not banking); self.withdrawCurrency:SetHidden(not banking)
    for i, panel in ipairs(self.panels) do
        panel.control:ClearAnchors()
        panel.control:SetAnchor(TOPLEFT, self.root, TOPLEFT, 20 + (i - 1) * (panelWidth + 24), 52 + filterHeight)
        panel.control:SetDimensions(panelWidth, footerY + 30)
        local detailedSnapshot = selectedSnapshot ~= nil and selectedSnapshot.afFilters ~= nil
        for _, control in ipairs(panel.filters) do control:SetHidden(filterHeight > 0 or detailedSnapshot) end
        if filterHeight > 0 or detailedSnapshot then panel.filter = nil end
        if panel.savedFilterUI then
            panel.savedFilterUI.control:SetHidden(not selectedSnapshot)
            if selectedSnapshot then GridBagsSnapshotFilters:UpdateUI(self, panel.savedFilterUI, selectedSnapshot, panelWidth) end
        end
        panel.sourceLabel:SetDimensions(panelWidth - 8, 24)
        panel.titleLabel:SetDimensions(panelWidth - (panel.characterButton and 144 or 8), 30)
        if panel.characterButton then
            panel.characterButton:SetEnabled(not banking)
            panel.characterButton:ClearAnchors()
            panel.characterButton:SetAnchor(TOPRIGHT, panel.control, TOPRIGHT, -4, 0)
            panel.compareButton:SetText(self.compareCharacter and "Compare: ON" or "Compare...")
        end
        panel.scrollbar:ClearAnchors()
        panel.scrollbar:SetAnchor(TOPRIGHT, panel.control, TOPRIGHT, -2, self.gridY)
        panel.scrollbar:SetDimensions(14, ROWS * (self.saved.size + GAP) - GAP)
        panel.rangeLabel:ClearAnchors()
        panel.rangeLabel:SetAnchor(TOPLEFT, panel.control, TOPLEFT, 4, footerY + 4)
        panel.goldLabel:ClearAnchors()
        panel.goldLabel:SetAnchor(TOPRIGHT, panel.control, TOPRIGHT, -4, footerY + 4)
        panel.goldLabel:SetDimensions(panelWidth - 170, 26)
    end
    A:Update(self, math.min(650, self.root:GetWidth() - 40))
    self.bank.control:SetHidden(not banking)
    self:RefreshPanel(self.backpack, { BAG_BACKPACK })
    if banking then self:RefreshPanel(self.bank, { BAG_BANK, BAG_SUBSCRIBER_BANK }) end
    self.root:SetHidden(false)
    local hovered = WM:GetMouseOverControl()
    if hovered and hovered.itemIdentity and IsCurrent(hovered) then
        ZO_InventorySlot_OnMouseEnter(hovered)
    elseif hovered and hovered.readOnly and hovered.snapshotItem and not hovered:IsHidden() then
        hovered:GetHandler("OnMouseEnter")(hovered)
    end
end

function G:Initialize()
    GridBagsEquipment:Initialize(self)
    self.saved = ZO_SavedVars:NewAccountWide("GridBagsSavedVariables", 1, nil, DEFAULTS)
    self.version = VERSION
    self.root = WM:CreateTopLevelWindow("GridBagsWindow")
    self.root:SetHidden(true)
    self.root:SetMouseEnabled(true)
    self.root:SetDrawTier(DT_MEDIUM)
    Backdrop(self.root)
    GridBagsLayout:Initialize(self)
    Label(self.root, "GRIDBAGS " .. VERSION, 20, 12, "ZoFontWinH3")
    local close = Button(self.root, "Standard view", 0, 0, 140, function()
        self.saved.enabled = false
        self:Refresh()
        d("GridBags hidden. Type /gridbags to enable it again.")
    end)
    close:ClearAnchors()
    close:SetAnchor(TOPRIGHT, self.root, TOPRIGHT, -16, 8)
    self.backpack = self:CreatePanel("Backpack", "Backpack")
    self.bank = self:CreatePanel("Bank", "Personal bank")
    local filters = Button(self.root, "Filters", 0, 0, 110, function(button)
        local snapshot = S:GetSelected(self)
        if snapshot then
            if snapshot.afFilters then GridBagsSnapshotFilters:Menu(self, button, "category")
            else d("GridBags: refresh this character's snapshot by logging into it, or visit a banker to refresh the saved account bank.") end
            return
        end
        if A:IsAvailable() then
            if not self.saved.externalFilters then
                self.saved.externalFilters = true
                self.saved.embeddedFilters = true
            else
                self.saved.embeddedFilters = not self.saved.embeddedFilters
            end
        else
            self.nativeFiltersMode = true
        end
        self:Refresh()
    end)
    self.filtersButton = filters
    filters:ClearAnchors()
    filters:SetAnchor(TOPRIGHT, self.root, TOPRIGHT, -162, 8)
    self.returnToGrid = WM:CreateTopLevelWindow("GridBagsReturnWindow")
    self.returnToGrid:SetDimensions(160, 36)
    self.returnToGrid:SetMouseEnabled(true)
    self.returnToGrid:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -35, 55)
    self.returnToGrid:SetHidden(true)
    self.returnButton = Button(self.returnToGrid, "GridBags view", 0, 0, 160, function()
        self.saved.enabled = true
        self.nativeFiltersMode = false
        self:Refresh()
    end)
    local hint = Label(self.root, "Double-click: use / transfer   |   Right-click: actions   |   Wheel: scroll   |   L: locked  S: stolen  J: junk", 0, 0, "ZoFontGameSmall")
    self.hintLabel = hint
    hint:ClearAnchors()
    hint:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 16, -12)
    hint:SetAnchor(BOTTOMRIGHT, self.root, BOTTOMRIGHT, -16, -12)
    local planner = Button(self.root, "Planner", 0, 0, 100, function() GridBagsRoutingUI:Show() end)
    planner:ClearAnchors(); planner:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 16, -51)
    self.markButton = Button(self.root, "Mark items: off", 0, 0, 150, function()
        self.planMode = not self.planMode; self:Refresh()
    end)
    self.markButton:ClearAnchors(); self.markButton:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 122, -51)
    self.logButton = Button(self.root, "Log", 0, 0, 60, function() GridBagsToolsUI:Show("history") end)
    self.logButton:ClearAnchors(); self.logButton:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 278, -51)
    local sort = Button(self.root, "Sort...", 0, 0, 100, function(button)
        ClearMenu()
        for _, value in ipairs({ "name", "quality", "type", "stack", "slot" }) do
            local mode = value
            AddMenuItem(mode, function() self.saved.sort = mode; ClearMenu(); self:Refresh() end)
        end
        ShowMenu(button)
    end)
    sort:ClearAnchors(); sort:SetAnchor(BOTTOMRIGHT, self.root, BOTTOMRIGHT, -16, -51)
    self.lockButton = Button(self.root, "Locked", 0, 0, 100, function()
        local layout = GridBagsLayout:Get(GridBagsLayout:Mode())
        GridBagsLayout:SetLocked(GridBagsLayout:Mode(), not layout.locked)
    end)
    self.lockButton:ClearAnchors(); self.lockButton:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 16, -87)
    local goldRules = Button(self.root, "Gold rules...", 0, 0, 130, function() GridBagsGoldUI:Show() end)
    goldRules:ClearAnchors(); goldRules:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 122, -87)
    self.depositCurrency = Button(self.root, "Deposit currency", 0, 0, 160, function() GridBagsGold:Manual("deposit") end)
    self.depositCurrency:ClearAnchors(); self.depositCurrency:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 268, -87)
    self.withdrawCurrency = Button(self.root, "Withdraw currency", 0, 0, 160, function() GridBagsGold:Manual("withdraw") end)
    self.withdrawCurrency:ClearAnchors(); self.withdrawCurrency:SetAnchor(BOTTOMLEFT, self.root, BOTTOMLEFT, 438, -87)
    self.pauseButton = Button(self.root, "Pause transfers", 0, 0, 140, function() GridBagsActivity:SetPaused(not GridBagsActivity:IsPaused()) end)
    self.pauseButton:ClearAnchors(); self.pauseButton:SetAnchor(BOTTOMRIGHT, self.root, BOTTOMRIGHT, -16, -87)
    for _, name in ipairs({ "inventory", "bank" }) do
        local scene = SCENE_MANAGER:GetScene(name)
        scene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then
                self.sceneName = name
                if state == SCENE_SHOWING then self.afInventoryType = nil end
                if state == SCENE_SHOWING then self:ReleaseSearchFocus() end
                self:Refresh()
            elseif self.sceneName == name and (state == SCENE_HIDING or state == SCENE_HIDDEN) then
                self.sceneName = nil
                self.nativeFiltersMode = false
                self:Refresh()
            end
        end)
    end
    EM:RegisterForEvent(ADDON, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag, slot)
        -- Block interaction with stale pooled rows until the pending rebind.
        for _, panel in ipairs(self.panels) do
            for _, cell in ipairs(panel.liveCells) do
                if cell.bagId == bag and cell.slotIndex == slot then cell:SetMouseEnabled(false) end
            end
        end
        self:QueueRefresh()
    end)
    EM:RegisterForEvent(ADDON, EVENT_INVENTORY_FULL_UPDATE, function() self:QueueRefresh() end)
    EM:RegisterForEvent(ADDON, EVENT_CLOSE_BANK, function() self:Refresh() end)
    EM:RegisterForEvent(ADDON, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() self:Refresh() end)
    GridBagsActivity:Initialize(self)
    S:Initialize(self)
    GridBagsRouting:Initialize(self)
    GridBagsRoutingUI:Initialize(self)
    GridBagsCraftingUI:Initialize(self)
    GridBagsGold:Initialize(self)
    GridBagsGoldUI:Initialize(self)
    GridBagsToolsUI:Initialize(self)
    GridBagsDeliveryUI:Initialize(self)
    GridBagsProtectionUI:Initialize(self)
    GridBagsRecipeGatherUI:Initialize()
    C:Initialize(self)
    A:Initialize(self)
    SLASH_COMMANDS["/gridbags"] = function(text)
        local command, value = string.match(text or "", "^%s*(%S*)%s*(%S*)")
        if command == "status" then
            local snapshot = S:GetSelected(self)
            local ui = self.backpack.savedFilterUI
            d(string.format("GridBags %s | view=%s | categories=%d | snapshot panel=%s | grid=%s | live filters=%s/%s",
                VERSION, snapshot and snapshot.name or "LIVE", snapshot and snapshot.afFilters and #snapshot.afFilters.categories or 0,
                ui and not ui.control:IsControlHidden() and "shown" or "hidden", self.root:IsHidden() and "hidden" or "shown",
                tostring(self.saved.externalFilters), tostring(self.saved.embeddedFilters)))
            return
        elseif command == "size" and tonumber(value) then
            self.saved.size = zo_clamp(math.floor(tonumber(value)), 36, 64)
        elseif command == "columns" and tonumber(value) then
            self.saved.columns = zo_clamp(math.floor(tonumber(value)), 6, 12)
        elseif command == "planner" then GridBagsRoutingUI:Show(); return
        elseif command == "crafting" then self:OpenInventoryTools("crafting"); return
        elseif command == "deliveries" then self:OpenInventoryTools("deliveries"); return
        elseif command == "protected" then self:OpenInventoryTools("protected"); return
        elseif command == "gather" then self:OpenInventoryTools("gather"); return
        elseif command == "sort" and (value == "name" or value == "quality" or value == "type" or value == "stack" or value == "slot") then
            self.saved.sort = value
        elseif command == "" then
            self.saved.enabled = not self.saved.enabled
        else
            d("GridBags: /gridbags | status | planner | crafting | deliveries | protected | gather | size 36-64 | columns 6-12 | sort name/quality/type/stack/slot")
            return
        end
        self:Refresh()
        d("GridBags " .. (self.saved.enabled and "enabled. Open inventory or your personal bank." or "disabled."))
    end
end

EM:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then return end
    EM:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    G:Initialize()
end)
