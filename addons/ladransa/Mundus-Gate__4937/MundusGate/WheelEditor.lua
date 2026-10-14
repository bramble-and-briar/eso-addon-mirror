-- Окно «Колесо: быстрое перемещение».
-- Слева — список мест, справа — колесо из 8 ячеек, расположенных так же,
-- как в игровом колесе быстрого доступа. Места перетаскиваются мышью:
--   • из списка на ячейку — положить место в ячейку;
--   • с ячейки на ячейку — поменять местами;
--   • с ячейки за пределы колеса — убрать.
-- Щелчок по ячейке выделяет её: справа настраиваются значок и цвет.
local QTM   = MundusGate
local L     = QTM.L
local Data  = QTM.Data
local Style = QTM.Style
local Wheel = QTM.Wheel

local WheelEditor = {}
QTM.WheelEditor = WheelEditor

local SCENE_NAME   = "MundusGateWheelScene"
local SLOT_SIZE    = 60
local RADIUS       = 150
local DRAG_SIZE    = 52
local SWATCH_SIZE  = 22
local SWATCH_GAP   = 5
local SWATCH_COLS  = 6
local TYPE_HEADER  = 1
local TYPE_ROW     = 2
local TYPE_EMPTY   = 3

local lower = zo_strlower or string.lower

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SetColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

---------------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------------
function WheelEditor:Initialize()
    local win = MundusGateWheelWindow
    self.window = win
    self.filter = { text = "", onlyFavorites = false, onlyOpen = false }
    self.selected = 1

    win:GetNamedChild("Title"):SetText(L.WHEEL_TITLE)
    win:GetNamedChild("Hint"):SetText(L.WHEEL_EDITOR_HINT)
    win:GetNamedChild("PlacesCaption"):SetText(L.WHEEL_EDITOR_PLACES)

    -- Список мест
    local search = win:GetNamedChild("SearchBgBox")
    search:SetMaxInputChars(60)
    search:SetHandler("OnTextChanged", function(edit)
        self.filter.text = edit:GetText()
        self:RefreshList()
    end)
    self.search = search

    local onlyFav = win:GetNamedChild("OnlyFav")
    ZO_CheckButton_SetLabelText(onlyFav, L.PICK_PLACE_ONLY_MINE)
    ZO_CheckButton_SetToggleFunction(onlyFav, function(_, checked)
        self.filter.onlyFavorites = checked
        self:RefreshList()
    end)
    local onlyOpen = win:GetNamedChild("OnlyOpen")
    ZO_CheckButton_SetLabelText(onlyOpen, L.EDITOR_ONLY_OPEN)
    ZO_CheckButton_SetToggleFunction(onlyOpen, function(_, checked)
        self.filter.onlyOpen = checked
        self:RefreshList()
    end)

    local list = win:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_HEADER, "MundusGate_PickerHeader", 30,
        function(control, data)
            control:SetWidth(list:GetWidth() - 16)
            control:GetNamedChild("Text"):SetText(data.text)
        end)
    ZO_ScrollList_AddDataType(list, TYPE_ROW, "MundusGate_DragRow", 30,
        function(control, data) self:SetupRow(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_EMPTY, "MundusGate_Empty", 80,
        function(control, data) QTM.Menu:SetupEmpty(control, data, list) end)

    -- Колесо
    self.wheelArea  = win:GetNamedChild("WheelArea")
    self.centerName = self.wheelArea:GetNamedChild("CenterName")
    self.centerInfo = self.wheelArea:GetNamedChild("CenterInfo")
    self:CreateSlots()

    -- Свойства выбранной ячейки
    self:InitializeDetails(win:GetNamedChild("Details"))

    -- Значок, который «едет» за мышью при перетаскивании
    self.dragIcon = MundusGateDragIcon
    self.dragTile = self.dragIcon:GetNamedChild("Tile")
    self.dragIcon:SetHandler("OnUpdate", function() self:OnDragUpdate() end)

    -- Позиция окна
    local saved = QTM.sv.editorPositions[SCENE_NAME]
    if saved and saved.x then
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    end
    win:SetHandler("OnMoveStop", function()
        QTM.sv.editorPositions[SCENE_NAME] = { x = win:GetLeft(), y = win:GetTop() }
    end)

    -- Сцена
    self.scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    self.scene:AddFragment(ZO_SimpleSceneFragment:New(win))
    self.scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            self.selected = self.selected or Wheel:FirstFreeIndex() or 1
            self:RefreshList()
            self:RefreshWheel()
        elseif newState == SCENE_HIDDEN then
            self:CancelDrag()
            QTM.ClosePickers()
            ZO_Tooltips_HideTextTooltip()
        end
    end)
end

function WheelEditor:Show()
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then
        self:RefreshWheel()
    else
        SCENE_MANAGER:Show(SCENE_NAME)
    end
end

function WheelEditor:RefreshIfShown()
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then
        self:RefreshList()
        self:RefreshWheel()
    end
end

function WheelEditor:Hide()
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then
        SCENE_MANAGER:Hide(SCENE_NAME)
    end
end

---------------------------------------------------------------------------
-- Ячейки колеса (расположены как в игре: ячейка 1 — справа снизу,
-- дальше по кругу через «справа», «сверху», «слева», последняя — снизу)
---------------------------------------------------------------------------
function WheelEditor:CreateSlots()
    self.slotTiles = {}
    local arc = 2 * math.pi / Wheel.MAX_SLOTS
    for index = 1, Wheel.MAX_SLOTS do
        local angle = index * arc
        local tile = CreateControlFromVirtual(self.wheelArea:GetName() .. "Slot" .. index, self.wheelArea, "MundusGate_Tile")
        tile:SetAnchor(CENTER, self.wheelArea, CENTER, math.sin(angle) * RADIUS, math.cos(angle) * RADIUS)
        tile:SetMouseEnabled(true)
        tile.slotIndex = index

        tile:SetHandler("OnMouseEnter", function(c) self:OnSlotEnter(c) end)
        tile:SetHandler("OnMouseExit", function(c) self:OnSlotExit(c) end)
        tile:SetHandler("OnDragStart", function(c, button) self:OnSlotDragStart(c, button) end)
        tile:SetHandler("OnReceiveDrag", function() self:FinishDrag() end)
        tile:SetHandler("OnMouseUp", function(c, button, upInside) self:OnSlotMouseUp(c, button, upInside) end)

        self.slotTiles[index] = tile
    end
end

function WheelEditor:PaintSlot(index)
    local tile = self.slotTiles[index]
    local slot = Wheel:GetSlot(index)
    local node = slot and Data:GetNode(slot.nodeIndex)
    local isTarget = self.drag and self.dropTarget == index

    if node then
        local available = Data:GetNodeStatus(node)
        Style.PaintTile(tile, {
            icon = Style.ResolveIcon(slot, node), color = slot.color, tint = slot.tint,
        }, {
            size = SLOT_SIZE, available = available,
            hover = tile.isHover or isTarget, selected = self.selected == index,
            label = node.name,
        })
    else
        -- Пустая ячейка: тёмный квадрат со значком пустого слота игры
        Style.PaintTile(tile, {
            icon = ZO_UTILITY_SLOT_EMPTY_TEXTURE, color = Style.PALETTE[11], iconScale = 0.9,
        }, {
            size = SLOT_SIZE, available = true,
            hover = tile.isHover or isTarget, selected = self.selected == index,
        })
    end
end

function WheelEditor:RefreshWheel()
    for index = 1, Wheel.MAX_SLOTS do
        self:PaintSlot(index)
    end
    self:RefreshCenter(self.hoverSlot or self.selected)
    self:RefreshDetails()
end

-- Подпись в центре колеса: как в игре — название наведённого места
function WheelEditor:RefreshCenter(index)
    local slot = index and Wheel:GetSlot(index)
    local node = slot and Data:GetNode(slot.nodeIndex)
    if node then
        self.centerName:SetText(node.name)
        self.centerInfo:SetText(node.zoneName)
    else
        self.centerName:SetText(L.WHEEL_CATEGORY)
        self.centerInfo:SetText(index and zo_strformat(L.WHEEL_SLOT_N, index) or "")
    end
end

function WheelEditor:Select(index)
    self.selected = index
    self:RefreshWheel()
end

function WheelEditor:OnSlotEnter(tile)
    tile.isHover = true
    self.hoverSlot = tile.slotIndex
    self:PaintSlot(tile.slotIndex)
    self:RefreshCenter(tile.slotIndex)
    if not self.drag then
        QTM.ShowTip("windows", tile, TOP, Wheel:GetSlot(tile.slotIndex) and L.WHEEL_SLOT_TT or L.WHEEL_SLOT_EMPTY_TT)
    end
end

function WheelEditor:OnSlotExit(tile)
    tile.isHover = false
    self.hoverSlot = nil
    self:PaintSlot(tile.slotIndex)
    self:RefreshCenter(self.selected)
    ZO_Tooltips_HideTextTooltip()
end

function WheelEditor:OnSlotDragStart(tile, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local slot = Wheel:GetSlot(tile.slotIndex)
    if not slot then return end
    self:BeginDrag({ nodeIndex = slot.nodeIndex, fromSlot = tile.slotIndex, look = slot })
end

function WheelEditor:OnSlotMouseUp(tile, button, upInside)
    -- Отпустили кнопку после перетаскивания (событие приходит той ячейке, с которой начали)
    if self.drag then
        self:FinishDrag()
        return
    end
    if not upInside then return end

    if button == MOUSE_BUTTON_INDEX_LEFT then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:Select(tile.slotIndex)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT and Wheel:GetSlot(tile.slotIndex) then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        Wheel:ClearSlot(tile.slotIndex)
        self:RefreshWheel()
    end
end

---------------------------------------------------------------------------
-- Перетаскивание
---------------------------------------------------------------------------
function WheelEditor:BeginDrag(drag)
    self.drag = drag
    self.dropTarget = nil
    ZO_Tooltips_HideTextTooltip()

    local node = Data:GetNode(drag.nodeIndex)
    Style.PaintTile(self.dragTile, {
        icon  = Style.ResolveIcon(drag.look, node),
        color = drag.look and drag.look.color,
        tint  = drag.look and drag.look.tint,
    }, { size = DRAG_SIZE, hover = true })
    self:OnDragUpdate()
    self.dragIcon:SetHidden(false)
    PlaySound(SOUNDS.DEFAULT_CLICK)
end

function WheelEditor:SlotUnderMouse()
    for index, tile in ipairs(self.slotTiles) do
        if MouseIsOver(tile) then return index end
    end
end

function WheelEditor:OnDragUpdate()
    if not self.drag then return end
    local x, y = GetUIMousePosition()
    self.dragIcon:ClearAnchors()
    self.dragIcon:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)

    local target = self:SlotUnderMouse()
    if target ~= self.dropTarget then
        local previous = self.dropTarget
        self.dropTarget = target
        if previous then self:PaintSlot(previous) end
        if target then self:PaintSlot(target) end
    end
end

function WheelEditor:FinishDrag()
    local drag = self.drag
    if not drag then return end
    self:CancelDrag()

    local target = self:SlotUnderMouse()
    if target then
        if drag.fromSlot then
            if target ~= drag.fromSlot then Wheel:SwapSlots(drag.fromSlot, target) end
        else
            Wheel:SetSlot(target, drag.nodeIndex)
        end
        self.selected = target
        PlaySound(SOUNDS.DEFAULT_CLICK)
    elseif drag.fromSlot and not MouseIsOver(self.wheelArea) then
        -- Утащили ячейку за пределы колеса — убираем место
        Wheel:ClearSlot(drag.fromSlot)
        PlaySound(SOUNDS.DEFAULT_CLICK)
    end
    self:RefreshWheel()
end

function WheelEditor:CancelDrag()
    self.drag = nil
    local previous = self.dropTarget
    self.dropTarget = nil
    if self.dragIcon then self.dragIcon:SetHidden(true) end
    if previous then self:PaintSlot(previous) end
end

---------------------------------------------------------------------------
-- Список мест
---------------------------------------------------------------------------
function WheelEditor:RefreshList()
    local f = self.filter
    local query = lower(Trim(f.text or ""))
    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)

    -- Сначала «Мои места», потом все остальные
    local function AddNodes(onlyFavorites, title)
        local lastZone
        local added = false
        for _, node in ipairs(Data:GetNodes()) do
            local isFav = Data:IsFavorite(node.nodeIndex)
            local ok = (onlyFavorites == isFav)
                and (query == "" or node.searchKey:find(query, 1, true) ~= nil)
            if ok then
                local available, reason = Data:GetNodeStatus(node)
                if available or not f.onlyOpen then
                    if not added and title then
                        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_HEADER, { text = title })
                        added = true
                    end
                    if not title and node.zoneName ~= lastZone then
                        lastZone = node.zoneName
                        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_HEADER, { text = node.zoneName })
                    end
                    dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW,
                        { node = node, available = available, reason = reason })
                end
            end
        end
    end

    AddNodes(true, L.HEADER_PLACES)
    if not f.onlyFavorites then
        AddNodes(false, nil)
    end

    if #dataList == 0 then
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY, { text = L.EDITOR_NOTHING })
    end
    ZO_ScrollList_Commit(self.list)
end

function WheelEditor:SetupRow(control, data)
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)
    control:GetNamedChild("Highlight"):SetAlpha(0)

    local node = data.node
    local icon = control:GetNamedChild("Icon")
    local name = control:GetNamedChild("Name")
    local info = control:GetNamedChild("Info")
    icon:SetTexture(node.icon)
    icon:SetDesaturation(data.available and 0 or 1)
    name:SetText(node.name)
    SetColor(name, data.available and ZO_HIGHLIGHT_TEXT or ZO_DISABLED_TEXT)
    info:SetText(data.available and Data.TYPE_NAMES[node.type] or (data.reason or ""))
    SetColor(info, data.available and ZO_NORMAL_TEXT or ZO_DISABLED_TEXT)
end

function WheelEditor:OnRowEnter(control)
    control:GetNamedChild("Highlight"):SetAlpha(1)
    if not self.drag and control.data then
        QTM.ShowTip("windows", control, RIGHT, L.WHEEL_ROW_TT)
    end
end

function WheelEditor:OnRowExit(control)
    control:GetNamedChild("Highlight"):SetAlpha(0)
    ZO_Tooltips_HideTextTooltip()
end

function WheelEditor:OnRowDragStart(control, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not control.data then return end
    self:BeginDrag({ nodeIndex = control.data.node.nodeIndex })
end

function WheelEditor:OnRowMouseUp(control, button, upInside)
    if self.drag then
        self:FinishDrag()
        return
    end
    if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and control.data then
        ClearMenu()
        AddMenuItem(L.CTX_RENAME, function() Data:ShowRenameDialog(control.data.node) end)
        ShowMenu(control)
        return
    end
    -- Щелчок по месту — положить его в выделенную ячейку
    if upInside and button == MOUSE_BUTTON_INDEX_LEFT and control.data then
        local index = self.selected or Wheel:FirstFreeIndex() or 1
        Wheel:SetSlot(index, control.data.node.nodeIndex)
        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:RefreshWheel()
    end
end

---------------------------------------------------------------------------
-- Свойства выбранной ячейки
---------------------------------------------------------------------------
function WheelEditor:InitializeDetails(details)
    self.details      = details
    self.preview      = details:GetNamedChild("Preview")
    self.detailName   = details:GetNamedChild("Name")
    self.detailInfo   = details:GetNamedChild("Info")
    self.detailEmpty  = details:GetNamedChild("Empty")
    self.detailEmpty:SetText(L.WHEEL_SLOT_EMPTY_HINT)
    self.detailControls = details:GetNamedChild("Controls")

    local controls = self.detailControls
    local pickIcon = controls:GetNamedChild("PickIcon")
    pickIcon:SetText(L.SLOT_PICK_ICON)
    pickIcon:SetHandler("OnClicked", function() self:PickIcon() end)
    local resetIcon = controls:GetNamedChild("ResetIcon")
    resetIcon:SetText(L.SLOT_RESET_ICON)
    resetIcon:SetHandler("OnClicked", function() self:Change(function(slot) slot.icon = nil end) end)

    controls:GetNamedChild("ColorCaption"):SetText(L.SLOT_COLOR)
    local swatch = controls:GetNamedChild("ColorSwatch")
    self.colorSwatch = swatch
    swatch:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then self:PickColor() end
    end)
    swatch:SetHandler("OnMouseEnter", function(c)
        c.isHover = true
        self:PaintColors()
        QTM.ShowTip("windows", c, TOP, L.SLOT_COLOR_TT)
    end)
    swatch:SetHandler("OnMouseExit", function(c)
        c.isHover = false
        self:PaintColors()
        ZO_Tooltips_HideTextTooltip()
    end)

    local palette = controls:GetNamedChild("Palette")
    self.swatches = {}
    for index, color in ipairs(Style.PALETTE) do
        local column = (index - 1) % SWATCH_COLS
        local row = zo_floor((index - 1) / SWATCH_COLS)
        local tile = CreateControlFromVirtual(palette:GetName() .. "Swatch" .. index, palette, "MundusGate_Tile")
        tile:SetAnchor(TOPLEFT, palette, TOPLEFT, column * (SWATCH_SIZE + SWATCH_GAP), row * (SWATCH_SIZE + SWATCH_GAP))
        tile:SetMouseEnabled(true)
        tile.color = color
        tile:SetHandler("OnMouseEnter", function(c) c.isHover = true; self:PaintColors() end)
        tile:SetHandler("OnMouseExit", function(c) c.isHover = false; self:PaintColors() end)
        tile:SetHandler("OnMouseUp", function(c, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                self:Change(function(slot) slot.color = Style.CopyColor(c.color) end)
            end
        end)
        self.swatches[index] = tile
    end

    local tint = controls:GetNamedChild("Tint")
    ZO_CheckButton_SetLabelText(tint, L.SLOT_TINT_SHORT)
    ZO_CheckButton_SetToggleFunction(tint, function(_, checked)
        self:Change(function(slot) slot.tint = checked end)
    end)
    self.tintCheck = tint

    local rename = controls:GetNamedChild("Rename")
    rename:SetText(L.CTX_RENAME)
    rename:SetHandler("OnClicked", function()
        local slot = self:GetSelectedSlot()
        if slot then Data:ShowRenameDialog(Data:GetNode(slot.nodeIndex)) end
    end)

    local clear = controls:GetNamedChild("Clear")
    clear:SetText(L.WHEEL_CLEAR_SLOT)
    clear:SetHandler("OnClicked", function()
        if self.selected then
            Wheel:ClearSlot(self.selected)
            self:RefreshWheel()
        end
    end)
end

function WheelEditor:GetSelectedSlot()
    return self.selected and Wheel:GetSlot(self.selected)
end

function WheelEditor:RefreshDetails()
    local slot = self:GetSelectedSlot()
    local node = slot and Data:GetNode(slot.nodeIndex)
    self.detailControls:SetHidden(node == nil)
    self.detailEmpty:SetHidden(node ~= nil)

    if node then
        local available, reason = Data:GetNodeStatus(node)
        Style.PaintTile(self.preview, {
            icon = Style.ResolveIcon(slot, node), color = slot.color, tint = slot.tint,
        }, { size = 64, available = available })
        self.detailName:SetText(node.name)
        self.detailInfo:SetText(available and node.zoneName or (reason or ""))
        ZO_CheckButton_SetCheckState(self.tintCheck, slot.tint == true)
        self:PaintColors()
    else
        Style.PaintTile(self.preview, {
            icon = ZO_UTILITY_SLOT_EMPTY_TEXTURE, color = Style.PALETTE[11], iconScale = 0.9,
        }, { size = 64 })
        self.detailName:SetText(self.selected and zo_strformat(L.WHEEL_SLOT_N, self.selected) or "")
        self.detailInfo:SetText(L.WHEEL_SLOT_EMPTY)
    end
end

-- Изменение значка или цвета запоминается для места (и переносится на его кнопки)
function WheelEditor:Change(mutator)
    local slot = self:GetSelectedSlot()
    if not slot then return end
    mutator(slot)
    Data:SavePlaceStyleFrom(slot)
    self:RefreshWheel()
end

function WheelEditor:PickIcon()
    local slot = self:GetSelectedSlot()
    if not slot then return end
    QTM.IconPicker:Open({ color = slot.color, tint = slot.tint }, function(path)
        self:Change(function(target) target.icon = path end)
    end)
end

function WheelEditor:PickColor()
    local slot = self:GetSelectedSlot()
    if not slot then return end
    local c = slot.color or Style.DEFAULT_COLOR
    SYSTEMS:GetObject("colorPicker"):Show(function(r, g, b)
        self:Change(function(target) target.color = { r = r, g = g, b = b } end)
    end, c.r, c.g, c.b)
end

function WheelEditor:PaintColors()
    local slot = self:GetSelectedSlot()
    if not slot then return end
    Style.PaintTile(self.colorSwatch, { color = slot.color }, { size = 40, hover = self.colorSwatch.isHover })
    for _, tile in ipairs(self.swatches) do
        Style.PaintTile(tile, { color = tile.color }, {
            size = SWATCH_SIZE, hover = tile.isHover, selected = Style.SameColor(slot.color, tile.color),
        })
    end
end
