-- Original gamepad presentation for An_Daghdha1233 Inventory. No inventory actions live here.
An_Daghdha1233Inventory = An_Daghdha1233Inventory or {}
local View = {}
An_Daghdha1233Inventory.View = View

local COLUMNS = 10
local ROWS = 3
local PAGE_SIZE = COLUMNS * ROWS
local ROOT_WIDTH, ROOT_HEIGHT = 1760, 900
local BAG_X, BAG_WIDTH = 20, 1130
local DETAILS_X, DETAILS_WIDTH = 1170, 570
local FRAME_TEXTURE = "An_Daghdha1233Inventory/media/KellsFrame.dds"
local WHEEL_TEXTURE = "An_Daghdha1233Inventory/media/QuickslotWheel.dds"
local SOCKET_TEXTURE = "An_Daghdha1233Inventory/media/QuickslotSocket.dds"
local SOCKET_FOCUS_TEXTURE = "An_Daghdha1233Inventory/media/QuickslotSocketFocus.dds"

local CATEGORIES = {
    { id = "all", label = "ALL" },
    { id = "gear", label = "GEAR" },
    { id = "materials", label = "MATERIALS" },
    { id = "supplies", label = "SUPPLIES" },
    { id = "slottable", label = "SLOTTABLE" },
    { id = "quest", label = "QUEST" },
}
local GEAR_FILTERS = {
    { id = "all", label = "ALL GEAR" },
    { id = "heavy", label = "HEAVY" },
    { id = "medium", label = "MEDIUM" },
    { id = "light", label = "LIGHT" },
    { id = "weapons", label = "WEAPONS" },
    { id = "jewelry", label = "JEWELRY" },
    { id = "other", label = "OTHER" },
}

local SLOTS = {
    { EQUIP_SLOT_MAIN_HAND, "Main hand", 1, 1 },
    { EQUIP_SLOT_HEAD, "Head", 2, 1 },
    { EQUIP_SLOT_NECK, "Neck", 3, 1 },
    { EQUIP_SLOT_OFF_HAND, "Off hand", 4, 1 },
    { EQUIP_SLOT_RING1, "Ring 1", 1, 2 },
    { EQUIP_SLOT_SHOULDERS, "Shoulders", 2, 2 },
    { EQUIP_SLOT_CHEST, "Chest", 3, 2 },
    { EQUIP_SLOT_RING2, "Ring 2", 4, 2 },
    { EQUIP_SLOT_HAND, "Hands", 1, 3 },
    { EQUIP_SLOT_WAIST, "Waist", 2, 3 },
    { EQUIP_SLOT_LEGS, "Legs", 3, 3 },
    { EQUIP_SLOT_FEET, "Feet", 4, 3 },
    { EQUIP_SLOT_BACKUP_MAIN, "Backup main", 1, 4 },
    { EQUIP_SLOT_BACKUP_OFF, "Backup off", 4, 4 },
}

local nextViewId = 0

local function NewControl(name, parent, controlType, x, y, width, height)
    local control = WINDOW_MANAGER:CreateControl(name, parent, controlType)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    return control
end

local function NewPanel(name, parent, x, y, width, height, r, g, b, a)
    local panel = NewControl(name, parent, CT_BACKDROP, x, y, width, height)
    panel:SetCenterColor(r, g, b, a)
    panel:SetEdgeColor(r, g, b, a)
    return panel
end

local function NewLabel(name, parent, x, y, width, height, font, r, g, b)
    local label = NewControl(name, parent, CT_LABEL, x, y, width, height)
    label:SetFont(font)
    label:SetColor(r, g, b, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function GetQualityRGBA(item)
    if item and item.quality then
        local color = GetItemQualityColor(item.quality)
        if color then
            return color:UnpackRGBA()
        end
    end
    return 0.46, 0.40, 0.27, 1
end

local function ApplyItemIcon(icon, item)
    if item and item.icon and item.icon ~= "" then
        icon:SetTexture(item.icon)
        icon:SetHidden(false)
    else
        icon:SetHidden(true)
    end
end

local function FindEquipped(equipped, equipSlot)
    if type(equipped) ~= "table" or equipSlot == nil then
        return nil
    end
    for _, item in ipairs(equipped) do
        if item.equipSlot == equipSlot then
            return item
        end
    end
    return nil
end

local function AddNativeDescriptions(parts, item, heading)
    if not item or not item.itemLink or item.itemLink == "" then
        return
    end
    local link = item.itemLink
    parts[#parts + 1] = heading
    parts[#parts + 1] = item.name or GetItemLinkName(link) or "Item"

    local _, traitDescription = GetItemLinkTraitInfo(link)
    if traitDescription and traitDescription ~= "" then
        parts[#parts + 1] = "TRAIT  " .. traitDescription
    end

    local _, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(link)
    if enchantDescription and enchantDescription ~= "" then
        parts[#parts + 1] = (enchantHeader and enchantHeader ~= "" and enchantHeader or "ENCHANTMENT")
        parts[#parts + 1] = enchantDescription
    end

    local isEquipped = item.bagId == BAG_WORN
    local hasSet, setName, numBonuses = GetItemLinkSetInfo(link, isEquipped)
    if hasSet then
        parts[#parts + 1] = "SET  " .. (setName or "")
        for index = 1, (numBonuses or 0) do
            local required, bonusDescription = GetItemLinkSetBonusInfo(link, isEquipped, index)
            if bonusDescription and bonusDescription ~= "" then
                parts[#parts + 1] = string.format("(%s) %s", tostring(required or "?"), bonusDescription)
            end
        end
    end
end

local function RenderSummary(card, item, propertyLabel, value)
    card.name:SetText(item and (item.name or "Item") or "Empty slot")
    card.property:SetText(item and propertyLabel and value and (propertyLabel .. ": " .. tostring(value)) or "")
    local group = item and An_Daghdha1233Inventory.Data
        and An_Daghdha1233Inventory.Data.GetGearGroup(item) or nil
    local label = group == "heavy" and "HEAVY ARMOR"
        or group == "medium" and "MEDIUM ARMOR"
        or group == "light" and "LIGHT ARMOR"
        or group == "weapons" and "WEAPON"
        or group == "jewelry" and "JEWELRY"
        or group == "other" and "OTHER GEAR" or ""
    card.type:SetText(label)
    card.type:SetHidden(label == "")
    ApplyItemIcon(card.icon, item)
    card.border:SetCenterColor(GetQualityRGBA(item))
end

function View.Create()
    nextViewId = nextViewId + 1
    local prefix = "An_Daghdha1233InventoryView" .. tostring(nextViewId)
    local view = setmetatable({ prefix = prefix, equipmentRows = {}, bagCells = {},
        lastDetailsKey = nil, equippedCardVisible = true }, { __index = View })
    local root = WINDOW_MANAGER:CreateTopLevelWindow(prefix .. "Root")
    root:SetDimensions(ROOT_WIDTH, ROOT_HEIGHT)
    root:SetAnchor(CENTER, GuiRoot, CENTER)
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    root:SetScale(math.min(1, screenWidth / (ROOT_WIDTH + 40), screenHeight / (ROOT_HEIGHT + 40)))
    root:SetHidden(true)
    view.root = root

    local background = NewControl(prefix .. "Background", root, CT_TEXTURE, 0, 0,
        ROOT_WIDTH, ROOT_HEIGHT)
    background:SetTexture(FRAME_TEXTURE)
    view.background = background
    NewPanel(prefix .. "TitlePlaque", root, 154, 10, 640, 58, 0.035, 0.045, 0.034, 0.92)
    local title = NewLabel(prefix .. "Title", root, 171, 12, 610, 55,
        "ZoFontGamepad42", 0.94, 0.86, 0.65)
    title:SetText("An_Daghdha1233 Inventory")
    view.hint = NewLabel(prefix .. "Hint", root, 1190, 24, 470, 38,
        "ZoFontGamepad22", 0.78, 0.82, 0.7)
    view.hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    view.hint:SetText("L1 / R1  CHANGE CATEGORY")

    NewPanel(prefix .. "EquipmentPanel", root, 20, 80, 1130, 350, 0.045, 0.057, 0.044, 0.9)
    NewPanel(prefix .. "BagPanel", root, BAG_X, 444, BAG_WIDTH, 394, 0.045, 0.057, 0.044, 0.9)
    NewPanel(prefix .. "DetailsPanel", root, DETAILS_X, 80, DETAILS_WIDTH, 758, 0.045, 0.057, 0.044, 0.9)
    NewLabel(prefix .. "EquipmentHeading", root, 39, 87, 400, 42, "ZoFontGamepad27", 0.94, 0.84, 0.58):SetText("EQUIPMENT")
    NewLabel(prefix .. "BagHeading", root, BAG_X + 19, 448, 240, 38, "ZoFontGamepad27", 0.94, 0.84, 0.58):SetText("INVENTORY")
    NewLabel(prefix .. "DetailsHeading", root, DETAILS_X + 18, 88, 515, 42, "ZoFontGamepad27", 0.94, 0.84, 0.58):SetText("ITEM DETAILS")
    NewPanel(prefix .. "EquipmentRule", root, 39, 126, 1072, 2, 0.47, 0.39, 0.22, 1)
    NewPanel(prefix .. "BagRule", root, BAG_X + 19, 534, BAG_WIDTH - 38, 2, 0.47, 0.39, 0.22, 1)
    NewPanel(prefix .. "DetailsRule", root, DETAILS_X + 18, 126, DETAILS_WIDTH - 36, 2, 0.47, 0.39, 0.22, 1)

    for index, slot in ipairs(SLOTS) do
        local x = 39 + (slot[3] - 1) * 276
        local y = 137 + (slot[4] - 1) * 73
        local rowName = prefix .. "Equipment" .. index
        local row = {}
        row.border = NewPanel(rowName .. "Border", root, x, y, 264, 62, 0.34, 0.32, 0.22, 1)
        row.fill = NewPanel(rowName .. "Fill", row.border, 2, 2, 260, 58, 0.045, 0.055, 0.041, 1)
        row.focusBar = NewPanel(rowName .. "FocusBar", row.border, 2, 2, 7, 58, 1, 0.84, 0.19, 1)
        row.focusBar:SetHidden(true)
        row.icon = NewControl(rowName .. "Icon", row.border, CT_TEXTURE, 9, 6, 48, 48)
        row.slot = NewLabel(rowName .. "Slot", row.border, 66, 4, 190, 21, "ZoFontGamepad20", 0.79, 0.75, 0.64)
        row.slot:SetText(slot[2])
        row.item = NewLabel(rowName .. "Item", row.border, 66, 27, 190, 27, "ZoFontGamepad22", 0.94, 0.94, 0.92)
        row.equipSlot = slot[1]
        view.equipmentRows[index] = row
    end
    local backupLabel = NewLabel(prefix .. "BackupLabel", root, 371, 356, 428, 62,
        "ZoFontGamepad22", 0.67, 0.66, 0.54)
    backupLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    backupLabel:SetText("BACKUP WEAPON SET")

    view.categoryTabs = {}
    for index, category in ipairs(CATEGORIES) do
        local x = 277 + (index - 1) * 143
        local tabName = prefix .. "Category" .. index
        local tab = {}
        tab.border = NewPanel(tabName .. "Border", root, x, 487, 138, 43, 0.34, 0.32, 0.22, 1)
        tab.fill = NewPanel(tabName .. "Fill", tab.border, 2, 2, 134, 39, 0.035, 0.05, 0.038, 1)
        tab.label = NewLabel(tabName .. "Label", tab.border, 4, 3, 130, 37,
            "ZoFontGamepad20", 0.78, 0.81, 0.83)
        tab.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        tab.id = category.id
        tab.title = category.label
        view.categoryTabs[index] = tab
    end

    view.gearFilters = {}
    for index, filter in ipairs(GEAR_FILTERS) do
        local x = 283 + (index - 1) * 122
        local name = prefix .. "GearFilter" .. index
        local chip = {}
        chip.border = NewPanel(name .. "Border", root, x, 451, 118, 29, 0.34, 0.32, 0.22, 1)
        chip.label = NewLabel(name .. "Label", chip.border, 3, 2, 112, 25,
            "ZoFontGamepad18", 0.78, 0.81, 0.83)
        chip.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        chip.label:SetText(filter.label)
        chip.id = filter.id
        view.gearFilters[index] = chip
    end

    local cellWidth, cellHeight, gapX, gapY = 100, 76, 10, 10
    for index = 1, PAGE_SIZE do
        local col = (index - 1) % COLUMNS
        local rowIndex = math.floor((index - 1) / COLUMNS)
        local x = BAG_X + 19 + col * (cellWidth + gapX)
        local y = 544 + rowIndex * (cellHeight + gapY)
        local cellName = prefix .. "BagCell" .. index
        local cell = {}
        cell.border = NewPanel(cellName .. "Border", root, x, y, cellWidth, cellHeight, 0.34, 0.32, 0.22, 1)
        cell.fill = NewPanel(cellName .. "Fill", cell.border, 3, 3, cellWidth - 6, cellHeight - 6, 0.035, 0.05, 0.038, 1)
        cell.focusBar = NewPanel(cellName .. "FocusBar", cell.border, 3, 70,
            cellWidth - 6, 5, 1, 0.84, 0.19, 1)
        cell.focusBar:SetHidden(true)
        cell.icon = NewControl(cellName .. "Icon", cell.border, CT_TEXTURE, 20, 4, 60, 58)
        cell.stack = NewLabel(cellName .. "Stack", cell.border, 61, 52, 33, 17, "ZoFontGamepad18", 1, 1, 1)
        cell.stack:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        cell.lock = NewLabel(cellName .. "Lock", cell.border, 5, 3, 74, 18, "ZoFontGamepad18", 0.97, 0.77, 0.43)
        cell.isNew = NewLabel(cellName .. "New", cell.border, 5, 53, 53, 16, "ZoFontGamepad18", 0.6, 0.95, 0.65)
        view.bagCells[index] = cell
    end
    view.page = NewLabel(prefix .. "Page", root, BAG_X + 19, 797, BAG_WIDTH - 38, 34, "ZoFontGamepad22", 0.88, 0.9, 0.9)
    view.page:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local cardWidth = 250
    local function MakeSummaryCard(suffix, x)
        local base = prefix .. suffix
        local card = {}
        card.heading = NewLabel(base .. "Heading", root, x, 137, cardWidth, 30, "ZoFontGamepad22", 0.77, 0.79, 0.65)
        card.border = NewPanel(base .. "Border", root, x, 172, cardWidth, 137, 0.39, 0.35, 0.24, 1)
        NewPanel(base .. "Fill", card.border, 3, 3, cardWidth - 6, 131, 0.044, 0.055, 0.041, 1)
        card.icon = NewControl(base .. "Icon", card.border, CT_TEXTURE, 12, 13, 72, 72)
        card.name = NewLabel(base .. "Name", card.border, 91, 12, 148, 65, "ZoFontGamepad22", 0.97, 0.96, 0.9)
        card.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        card.name:SetMaxLineCount(2)
        card.type = NewLabel(base .. "Type", card.border, 10, 83, cardWidth - 20, 23,
            "ZoFontGamepad20", 1, 0.84, 0.44)
        card.property = NewLabel(base .. "Property", card.border, 10, 107, cardWidth - 20, 22,
            "ZoFontGamepad18", 0.79, 0.83, 0.69)
        return card
    end
    view.candidateCard = MakeSummaryCard("Candidate", DETAILS_X + 18)
    view.candidateCard.heading:SetText("FOCUSED ITEM")
    view.equippedCard = MakeSummaryCard("Equipped", DETAILS_X + 294)
    view.equippedCard.heading:SetText("CURRENTLY EQUIPPED")
    view.delta = NewLabel(prefix .. "Delta", root, DETAILS_X + 18, 318, DETAILS_WIDTH - 36, 38, "ZoFontGamepad27", 0.88, 0.88, 0.79)
    view.condition = NewLabel(prefix .. "Condition", root, DETAILS_X + 18, 354, DETAILS_WIDTH - 36, 76, "ZoFontGamepad20", 0.78, 0.83, 0.72)

    -- The shared gamepad scroll container owns right-stick input and its scroll indicator.
    local description = WINDOW_MANAGER:CreateControlFromVirtual(prefix .. "Description", root, "ZO_ScrollContainer_Shared")
    description:SetAnchor(TOPLEFT, root, TOPLEFT, DETAILS_X + 18, 438)
    description:SetDimensions(DETAILS_WIDTH - 36, 381)
    description.useScrollbar = false
    local scrollChild = description.scroll:GetNamedChild("Child")
    view.descriptionText = NewLabel(prefix .. "DescriptionText", scrollChild, 0, 0, DETAILS_WIDTH - 74, 1, "ZoFontGamepad22", 0.89, 0.91, 0.82)
    view.descriptionText:SetVerticalAlignment(TEXT_ALIGN_TOP)
    view.descriptionText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    view.description = description

    -- The game's full tooltip is translucent. Cover our details while it is
    -- shown so the two sets of text do not overlap.
    view.detailsCover = NewPanel(prefix .. "DetailsCover", root, DETAILS_X, 80,
        DETAILS_WIDTH, 758, 0.034, 0.044, 0.035, 1)
    view.detailsCover:SetHidden(true)

    view.status = NewLabel(prefix .. "Status", root, 26, 846, ROOT_WIDTH - 52, 40, "ZoFontGamepad24", 0.86, 0.88, 0.78)
    view.status:SetText("")

    -- Keep this in a separate top-level window. A backdrop within the main
    -- window draws below its labels and textures even when created last.
    local picker = WINDOW_MANAGER:CreateTopLevelWindow(prefix .. "QuickslotPicker")
    picker:SetDimensions(ROOT_WIDTH, ROOT_HEIGHT)
    picker:SetAnchor(CENTER, GuiRoot, CENTER)
    picker:SetScale(math.min(1, screenWidth / (ROOT_WIDTH + 40), screenHeight / (ROOT_HEIGHT + 40)))
    picker:SetDrawTier(DT_HIGH)
    picker:SetHidden(true)
    view.quickslotPicker = picker
    local pickerBackground = NewControl(prefix .. "QuickslotBackground", picker, CT_TEXTURE,
        0, 0, ROOT_WIDTH, ROOT_HEIGHT)
    pickerBackground:SetTexture(FRAME_TEXTURE)
    local pickerPanel = NewPanel(prefix .. "QuickslotPanel", picker, 20, 80, 1130, 758,
        0.035, 0.047, 0.039, 0.99)
    NewLabel(prefix .. "QuickslotTitle", pickerPanel, 40, 22, 1050, 52,
        "ZoFontGamepad42", 0.96, 0.85, 0.58):SetText("QUICKSLOT ASSIGNMENT")
    NewPanel(prefix .. "QuickslotRule", pickerPanel, 40, 78, 1050, 2, 0.47, 0.39, 0.22, 1)
    local wheel = NewControl(prefix .. "QuickslotWheel", pickerPanel,
        CT_TEXTURE, 265, 88, 600, 600)
    wheel:SetTexture(WHEEL_TEXTURE)
    view.quickslotPending = NewLabel(prefix .. "QuickslotPending", pickerPanel, 427, 329,
        276, 48, "ZoFontGamepad27", 0.96, 0.85, 0.58)
    view.quickslotPending:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    view.quickslotState = NewLabel(prefix .. "QuickslotState", pickerPanel, 427, 380,
        276, 38, "ZoFontGamepad22", 0.88, 0.9, 0.79)
    view.quickslotState:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    NewLabel(prefix .. "QuickslotHint", pickerPanel, 90, 696, 950, 40,
        "ZoFontGamepad22", 0.8, 0.83, 0.72):SetText("D-PAD  CHOOSE POSITION")
    NewPanel(prefix .. "QuickslotDetail", picker, DETAILS_X, 80, DETAILS_WIDTH, 758,
        0.035, 0.047, 0.039, 0.99)
    NewLabel(prefix .. "QuickslotDetailTitle", picker, DETAILS_X + 26, 107,
        DETAILS_WIDTH - 52, 44, "ZoFontGamepad27", 0.96, 0.85, 0.58):SetText("ITEM TO ASSIGN")
    view.quickslotItemIcon = NewControl(prefix .. "QuickslotItemIcon", picker,
        CT_TEXTURE, DETAILS_X + 32, 180, 80, 80)
    view.quickslotItemName = NewLabel(prefix .. "QuickslotItemName", picker,
        DETAILS_X + 132, 180, DETAILS_WIDTH - 164, 80,
        "ZoFontGamepad27", 0.96, 0.94, 0.83)
    NewPanel(prefix .. "QuickslotDetailRule", picker, DETAILS_X + 30, 286,
        DETAILS_WIDTH - 60, 2, 0.47, 0.39, 0.22, 1)
    NewLabel(prefix .. "QuickslotDestinationTitle", picker, DETAILS_X + 32, 311,
        DETAILS_WIDTH - 64, 35, "ZoFontGamepad22", 0.96, 0.85, 0.58)
        :SetText("SELECTED POSITION")
    view.quickslotDestination = NewLabel(prefix .. "QuickslotDestination", picker,
        DETAILS_X + 32, 351, DETAILS_WIDTH - 64, 64,
        "ZoFontGamepad27", 0.96, 0.94, 0.83)
    view.quickslotDestination:SetMaxLineCount(2)
    view.quickslotChange = NewLabel(prefix .. "QuickslotChange", picker,
        DETAILS_X + 32, 430, DETAILS_WIDTH - 64, 120,
        "ZoFontGamepad22", 0.8, 0.83, 0.72)
    view.quickslotChange:SetMaxLineCount(3)
    view.quickslotEntries = {}
    local centerX, centerY, radius = 565, 388, 217
    for index = 1, 8 do
        -- ESO's native radial menu starts action slot 1 at lower right and
        -- proceeds counterclockwise. Match its physical slot placement.
        local angle = math.pi / 4 - (index - 1) * math.pi / 4
        local x = math.floor(centerX + radius * math.cos(angle) - 56)
        local y = math.floor(centerY + radius * math.sin(angle) - 56)
        local name = prefix .. "Quickslot" .. index
        local entry = {}
        entry.border = NewControl(name .. "Socket", pickerPanel, CT_TEXTURE,
            x, y, 112, 112)
        entry.border:SetTexture(SOCKET_TEXTURE)
        entry.icon = NewControl(name .. "Icon", pickerPanel,
            CT_TEXTURE, x + 25, y + 13, 62, 62)
        entry.empty = NewLabel(name .. "Empty", pickerPanel,
            x + 9, y + 39, 94, 27, "ZoFontGamepad20", 0.7, 0.78, 0.67)
        entry.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        entry.empty:SetText("EMPTY")
        entry.number = NewLabel(name .. "Number", pickerPanel,
            x + 16, y + 78, 80, 23, "ZoFontGamepad20", 0.9, 0.86, 0.73)
        entry.number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        view.quickslotEntries[index] = entry
    end
    return view
end

function View:ShowQuickslotPicker(visible, selected, item)
    self.pickerVisible = visible
    self.quickslotPicker:SetHidden(not visible)
    self.hint:SetText(visible and "D-PAD  CHOOSE QUICK SLOT"
        or (self.lastCategory == "gear" and "D-PAD UP  GEAR TYPES    L1 / R1  CATEGORY"
            or "L1 / R1  CHANGE CATEGORY"))
    if not visible then return end
    self.quickslotItemName:SetText(item and (item.name or "Item") or "Choose an item")
    ApplyItemIcon(self.quickslotItemIcon, item)
    for index, entry in ipairs(self.quickslotEntries) do
        local slotType = GetSlotType(index, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        local occupied = slotType ~= nil and slotType ~= ACTION_TYPE_NOTHING
        local icon = occupied and GetSlotTexture(index, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
        entry.icon:SetHidden(not icon or icon == "")
        if icon and icon ~= "" then entry.icon:SetTexture(icon) end
        entry.empty:SetHidden(occupied)
        entry.number:SetText(string.format("%02d", index))
        entry.number:SetColor(index == selected and 1 or 0.9,
            index == selected and 0.88 or 0.86,
            index == selected and 0.46 or 0.73, 1)
        entry.border:SetTexture(index == selected and SOCKET_FOCUS_TEXTURE or SOCKET_TEXTURE)
        if index == selected then
            local slotName = occupied and type(GetSlotName) == "function"
                and GetSlotName(index, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
            if not slotName or slotName == "" then
                slotName = occupied and "Assigned item" or "Empty position"
            end
            self.quickslotPending:SetText(string.format("POSITION %02d", index))
            self.quickslotState:SetText(occupied and "IN USE" or "AVAILABLE")
            self.quickslotDestination:SetText(slotName)
            self.quickslotChange:SetText(occupied
                and "Assigning here replaces the item currently in this position."
                or "Assigning here adds the selected item to the quickslot wheel.")
        end
    end
end

function View:GetPageSize()
    return PAGE_SIZE
end

function View:GetColumns()
    return COLUMNS
end

function View:GetEquipmentSlotCount()
    return #SLOTS
end

function View:GetEquipmentNeighbor(index, moveX, moveY)
    local current = SLOTS[index]
    if not current then return nil end
    local column, row = current[3], current[4]
    local targetColumn = column + (moveX or 0)
    local targetRow = row + (moveY or 0)
    if targetColumn < 1 or targetColumn > 4 or targetRow < 1 or targetRow > 4 then
        return nil
    end
    local bestIndex, bestDistance
    for candidateIndex, slot in ipairs(SLOTS) do
        if (moveX ~= 0 and slot[4] == row and
            ((moveX > 0 and slot[3] >= targetColumn) or (moveX < 0 and slot[3] <= targetColumn)))
            or (moveY ~= 0 and slot[4] == targetRow) then
            local distance = math.abs(slot[3] - targetColumn)
            if bestDistance == nil or distance < bestDistance then
                bestIndex, bestDistance = candidateIndex, distance
            end
        end
    end
    return bestIndex
end

function View:GetEquipmentEntryForBagColumn(column)
    return column <= COLUMNS / 2 and 13 or 14
end

function View:GetBagEntryForEquipment(index, count)
    local slot = SLOTS[index]
    if not slot or count < 1 then return 1 end
    local column = math.floor((slot[3] - 1) * (COLUMNS - 1) / 3) + 1
    return math.min(column, count)
end

function View:SetStatus(text)
    self.status:SetText(text or "")
end

function View:SetVisible(visible)
    self.sceneVisible = visible
    self.root:SetHidden(not visible or self.pickerVisible)
    self.quickslotPicker:SetHidden(not visible or not self.pickerVisible)
end

function View:SetNativeTooltipVisible(visible)
    self.detailsCover:SetHidden(not visible)
    self.candidateCard.heading:SetHidden(visible)
    self.candidateCard.border:SetHidden(visible)
    self.equippedCard.heading:SetHidden(visible or not self.equippedCardVisible)
    self.equippedCard.border:SetHidden(visible or not self.equippedCardVisible)
    self.delta:SetHidden(visible)
    self.condition:SetHidden(visible)
    self.description:SetHidden(visible)
end

function View:ScrollDetails(direction)
    if type(direction) ~= "number" or direction == 0 then
        return
    end
    ZO_ScrollRelative(self.description, direction * 72)
end

function View:Render(items, equipped, selectedIndex, pane, equippedIndex, destination, comparison, categoryId, inventoryRevision, categoryCounts, gearFilterId)
    self.lastCategory = categoryId
    if self.quickslotPicker.hidden then
        self.hint:SetText(categoryId == "gear" and "D-PAD UP  GEAR TYPES    L1 / R1  CATEGORY"
            or "L1 / R1  CHANGE CATEGORY")
    end
    items = type(items) == "table" and items or {}
    equipped = type(equipped) == "table" and equipped or {}
    selectedIndex = type(selectedIndex) == "number" and selectedIndex or 1
    equippedIndex = type(equippedIndex) == "number" and equippedIndex or 1
    local equipmentFocused = pane == "equipment" or pane == "equipped"
    local filtersFocused = pane == "gearFilters"
    local selectedBag = items[selectedIndex]
    local selectedEquipSlot = SLOTS[equippedIndex] and SLOTS[equippedIndex][1]
    local selectedEquipped = FindEquipped(equipped, selectedEquipSlot)
    local destinationSlot = type(destination) == "table" and destination.equipSlot or nil
    local worn = not equipmentFocused and destinationSlot and FindEquipped(equipped, destinationSlot) or nil
    self.equippedCardVisible = equipmentFocused or destinationSlot ~= nil
    self.equippedCard.heading:SetHidden(not self.equippedCardVisible)
    self.equippedCard.border:SetHidden(not self.equippedCardVisible)
    local focused
    if equipmentFocused then
        focused = selectedEquipped
    elseif not filtersFocused then
        focused = selectedBag
    end

    for _, tab in ipairs(self.categoryTabs) do
        local active = tab.id == (categoryId or "all")
        local count = categoryCounts and categoryCounts[tab.id]
        tab.label:SetText(tab.title .. (type(count) == "number" and ("  " .. tostring(count)) or ""))
        tab.border:SetCenterColor(active and 1 or 0.36, active and 0.84 or 0.34,
            active and 0.19 or 0.23, 1)
        tab.fill:SetCenterColor(active and 0.23 or 0.035, active and 0.16 or 0.05,
            active and 0.045 or 0.038, 1)
        tab.label:SetColor(active and 1 or 0.81, active and 0.94 or 0.83,
            active and 0.74 or 0.69, 1)
    end
    for _, filter in ipairs(self.gearFilters) do
        local visible = categoryId == "gear"
        filter.border:SetHidden(not visible)
        local active = filter.id == (gearFilterId or "all")
        filter.border:SetCenterColor(filtersFocused and active and 1 or active and 0.81 or 0.36,
            filtersFocused and active and 0.84 or active and 0.68 or 0.34,
            active and 0.19 or 0.23, 1)
        filter.label:SetColor(active and 1 or 0.81, active and 0.94 or 0.83,
            active and 0.74 or 0.69, 1)
    end
    for _, row in ipairs(self.equipmentRows) do
        local item = FindEquipped(equipped, row.equipSlot)
        ApplyItemIcon(row.icon, item)
        row.item:SetText(item and (item.name or "Item") or "Empty")
        local r, g, b = GetQualityRGBA(item)
        local isFocused = equipmentFocused and row.equipSlot == selectedEquipSlot
        row.focusBar:SetHidden(not isFocused)
        if isFocused then
            row.border:SetCenterColor(1, 0.84, 0.19, 1)
            row.fill:SetCenterColor(0.23, 0.16, 0.045, 1)
        elseif destinationSlot and row.equipSlot == destinationSlot then
            row.border:SetCenterColor(0.42, 0.83, 0.74, 1)
            row.fill:SetCenterColor(0.058, 0.073, 0.054, 1)
        else
            row.border:SetCenterColor(r * 0.58, g * 0.58, b * 0.58, 1)
            row.fill:SetCenterColor(0.058, 0.073, 0.054, 1)
        end
    end

    local pageCount = math.max(1, math.ceil(#items / PAGE_SIZE))
    local pageIndex = math.min(pageCount, math.max(1, math.floor((selectedIndex - 1) / PAGE_SIZE) + 1))
    local firstIndex = (pageIndex - 1) * PAGE_SIZE + 1
    for index, cell in ipairs(self.bagCells) do
        local dataIndex = firstIndex + index - 1
        local item = items[dataIndex]
        ApplyItemIcon(cell.icon, item)
        cell.stack:SetText(item and item.stackCount and item.stackCount > 1 and tostring(item.stackCount) or "")
        cell.lock:SetText(item and item.locked and "LOCKED" or "")
        cell.isNew:SetText(item and item.isNew and "NEW" or "")
        local r, g, b = GetQualityRGBA(item)
        local isFocused = item and pane == "bag" and dataIndex == selectedIndex
        cell.focusBar:SetHidden(not isFocused)
        if isFocused then
            cell.border:SetCenterColor(1, 0.84, 0.19, 1)
            cell.fill:SetCenterColor(0.23, 0.16, 0.045, 1)
        elseif item then
            cell.border:SetCenterColor(r, g, b, 1)
            cell.fill:SetCenterColor(0.035, 0.05, 0.038, 1)
        else
            cell.border:SetCenterColor(0.30, 0.30, 0.22, 1)
            cell.fill:SetCenterColor(0.035, 0.05, 0.038, 1)
        end
    end
    self.page:SetText(#items == 0 and (categoryId == "quest" and "No quest items"
        or categoryId == "all" and "Backpack empty" or "No items in this category")
        or string.format("Page %d of %d  |  %d %s", pageIndex, pageCount, #items,
            #items == 1 and "item" or "items"))

    local propertyLabel = comparison and comparison.label or nil
    RenderSummary(self.candidateCard, focused, propertyLabel, comparison and comparison.candidate)
    RenderSummary(self.equippedCard, worn, propertyLabel, comparison and comparison.current)
    if comparison and type(comparison.delta) == "number" then
        local delta = comparison.delta
        self.delta:SetText(string.format("%s  %s%d", propertyLabel or "Difference", delta >= 0 and "+" or "", delta))
        self.delta:SetColor(delta > 0 and 0.44 or delta < 0 and 0.96 or 0.86,
            delta > 0 and 0.88 or delta < 0 and 0.48 or 0.86,
            delta > 0 and 0.53 or delta < 0 and 0.42 or 0.86, 1)
    else
        self.delta:SetText(filtersFocused and "Choose a gear type"
            or equipmentFocused and (selectedEquipped and "Equipped item selected" or "Empty equipment slot")
            or focused and focused.isQuest and "Quest item" or "No comparable item property")
        self.delta:SetColor(0.7, 0.77, 0.8, 1)
    end
    local notes = {}
    if destination and destination.label then
        notes[#notes + 1] = "Compared with: " .. destination.label .. "."
    end
    if comparison and comparison.kind == "armorRating"
        and (comparison.candidate ~= comparison.candidateBase or comparison.current ~= comparison.currentBase) then
        notes[#notes + 1] = "Armor rating uses current condition."
    end
    if type(destination) == "table" and destination.canEquip == false then
        notes[#notes + 1] = "Cannot equip now."
    end
    if focused and destinationSlot then
        if focused.equipType == EQUIP_TYPE_TWO_HAND then
            local pairedSlot
            if destinationSlot == EQUIP_SLOT_MAIN_HAND then
                pairedSlot = EQUIP_SLOT_OFF_HAND
            elseif destinationSlot == EQUIP_SLOT_BACKUP_MAIN then
                pairedSlot = EQUIP_SLOT_BACKUP_OFF
            end
            if pairedSlot and FindEquipped(equipped, pairedSlot) then
                notes[#notes + 1] = "Equipping also displaces the off-hand item."
            end
        elseif destinationSlot == EQUIP_SLOT_OFF_HAND or destinationSlot == EQUIP_SLOT_BACKUP_OFF then
            local mainSlot = destinationSlot == EQUIP_SLOT_OFF_HAND
                and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN
            local mainHand = FindEquipped(equipped, mainSlot)
            if mainHand and mainHand.equipType == EQUIP_TYPE_TWO_HAND then
                notes[#notes + 1] = "Equipping also displaces the two-handed main-hand item."
            end
        end
    end
    self.condition:SetText(table.concat(notes, " "))

    local detailsKey = tostring(inventoryRevision or 0) .. ":"
        .. tostring(focused and focused.itemLink or "") .. ":"
        .. tostring(focused and focused.questItemId or "") .. ":"
        .. tostring(focused and focused.slotIndex or "") .. ":"
        .. tostring(worn and worn.itemLink or "") .. ":" .. tostring(worn and worn.slotIndex or "")
    if detailsKey ~= self.lastDetailsKey then
        local parts = {}
        AddNativeDescriptions(parts, focused, "FOCUSED ITEM")
        if worn and worn ~= focused then
            parts[#parts + 1] = " "
            AddNativeDescriptions(parts, worn, "CURRENTLY EQUIPPED")
        end
        self.descriptionText:SetText(#parts > 0 and table.concat(parts, "\n")
            or focused and focused.questItemId and "Quest item. Open the full tooltip for its native description."
            or "Select an item to view its traits, enchantment, and set bonuses.")
        self.descriptionText:SetHeight(2000)
        self.descriptionText:SetHeight(math.max(381, self.descriptionText:GetTextHeight() + 20))
        self.description:ResetToTop()
        self.lastDetailsKey = detailsKey
    end
end
