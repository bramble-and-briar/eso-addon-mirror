-- Окно настройки «слотов»: общее для кнопок на экране и для колеса.
-- Слева — список кнопок (или слотов колеса), справа — свойства выбранной:
-- место, значок, цвет, окраска значка; у кнопок ещё размер, подпись и видимость.
local QTM   = MundusGate
local L     = QTM.L
local Data  = QTM.Data
local Style = QTM.Style

local SlotEditor = ZO_InitializingObject:Subclass()
QTM.SlotEditor = SlotEditor

local TYPE_ROW    = 1
local ROW_HEIGHT  = 52
local SWATCH_SIZE = 26
local SWATCH_GAP  = 6
local PREVIEW_MAX = 96

local function SetColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

---------------------------------------------------------------------------
-- adapter — что именно редактируем:
--   title, hint, empty      — тексты
--   sceneName               — имя сцены окна
--   GetItems()              — список
--   Add()                   — создать элемент, вернуть его (или nil)
--   Remove(item, index)
--   Move(index, delta)      — переставить (только колесо), вернуть новый индекс
--   OnChanged(item)         — элемент изменился
--   GetItemIndex(id)        — найти индекс по id (для кнопок)
--   hasButtonOptions        — показывать размер, подпись, видимость
---------------------------------------------------------------------------
function SlotEditor:Initialize(window, adapter)
    self.window  = window
    self.adapter = adapter
    self.selectedIndex = nil

    local body = window:GetNamedChild("Body")
    self.body = body
    body:GetNamedChild("Title"):SetText(adapter.title)
    body:GetNamedChild("Hint"):SetText(adapter.hint)
    body:GetNamedChild("Empty"):SetText(adapter.empty)
    body:GetNamedChild("Close"):SetHandler("OnClicked", function() self:Hide() end)

    -- Кнопки под списком
    local add = body:GetNamedChild("Add")
    add:SetText(L.SLOT_ADD)
    add:SetHandler("OnClicked", function() self:AddItem() end)
    local remove = body:GetNamedChild("Remove")
    remove:SetText(L.SLOT_REMOVE)
    remove:SetHandler("OnClicked", function() self:RemoveSelected() end)
    self.removeButton = remove

    local up, down = body:GetNamedChild("Up"), body:GetNamedChild("Down")
    if adapter.Move then
        up:SetText(L.SLOT_UP)
        down:SetText(L.SLOT_DOWN)
        up:SetHandler("OnClicked", function() self:MoveSelected(-1) end)
        down:SetHandler("OnClicked", function() self:MoveSelected(1) end)
    else
        up:SetHidden(true)
        down:SetHidden(true)
    end
    self.upButton, self.downButton = up, down

    -- Список
    local list = body:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_ROW, "MundusGate_SlotRow", ROW_HEIGHT,
        function(control, data) self:SetupRow(control, data) end)

    -- Правая панель
    local details = body:GetNamedChild("Details")
    self.details = details
    self.preview    = details:GetNamedChild("Preview")
    self.placeName  = details:GetNamedChild("PlaceName")
    self.placeInfo  = details:GetNamedChild("PlaceInfo")
    self.placePrice = details:GetNamedChild("PlacePrice")

    local renamePlace = details:GetNamedChild("RenamePlace")
    renamePlace:SetText(L.CTX_RENAME)
    renamePlace:SetHandler("OnClicked", function()
        local item = self:GetSelected()
        local node = item and item.nodeIndex and Data:GetNode(item.nodeIndex)
        if node then Data:ShowRenameDialog(node) end
    end)
    self.renameButton = renamePlace

    local pickPlace = details:GetNamedChild("PickPlace")
    pickPlace:SetText(L.SLOT_PICK_PLACE)
    pickPlace:SetHandler("OnClicked", function() self:PickPlace() end)

    details:GetNamedChild("IconCaption"):SetText(L.SLOT_ICON)
    self.iconPreview = details:GetNamedChild("IconPreview")
    local pickIcon = details:GetNamedChild("PickIcon")
    pickIcon:SetText(L.SLOT_PICK_ICON)
    pickIcon:SetHandler("OnClicked", function() self:PickIcon() end)
    local resetIcon = details:GetNamedChild("ResetIcon")
    resetIcon:SetText(L.SLOT_RESET_ICON)
    resetIcon:SetHandler("OnClicked", function() self:Change(function(item) item.icon = nil end) end)

    details:GetNamedChild("ColorCaption"):SetText(L.SLOT_COLOR)
    local swatch = details:GetNamedChild("ColorSwatch")
    self.colorSwatch = swatch
    swatch:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then self:PickColor() end
    end)
    swatch:SetHandler("OnMouseEnter", function(c)
        c.isHover = true
        self:PaintSwatch()
        ZO_Tooltips_ShowTextTooltip(c, TOP, L.SLOT_COLOR_TT)
    end)
    swatch:SetHandler("OnMouseExit", function(c)
        c.isHover = false
        self:PaintSwatch()
        ZO_Tooltips_HideTextTooltip()
    end)
    self:CreatePalette(details:GetNamedChild("Palette"))

    local tint = details:GetNamedChild("Tint")
    ZO_CheckButton_SetLabelText(tint, L.SLOT_TINT)
    ZO_CheckButton_SetToggleFunction(tint, function(_, checked)
        self:Change(function(item) item.tint = checked end)
    end)
    self.tintCheck = tint

    -- Только для кнопок: размер, подпись, видимость
    local buttonOptions = details:GetNamedChild("ButtonOptions")
    self.buttonOptions = buttonOptions
    buttonOptions:SetHidden(not adapter.hasButtonOptions)
    if adapter.hasButtonOptions then
        buttonOptions:GetNamedChild("SizeCaption"):SetText(L.SLOT_SIZE)
        self.sizeValue = buttonOptions:GetNamedChild("SizeValue")
        local minus, plus = buttonOptions:GetNamedChild("SizeMinus"), buttonOptions:GetNamedChild("SizePlus")
        minus:SetText("−")
        plus:SetText("+")
        minus:SetHandler("OnClicked", function() self:ChangeSize(-4) end)
        plus:SetHandler("OnClicked", function() self:ChangeSize(4) end)

        local showLabel = buttonOptions:GetNamedChild("ShowLabel")
        ZO_CheckButton_SetLabelText(showLabel, L.SLOT_SHOW_LABEL)
        ZO_CheckButton_SetToggleFunction(showLabel, function(_, checked)
            self:Change(function(item) item.showLabel = checked end)
        end)
        self.showLabelCheck = showLabel

        local visible = buttonOptions:GetNamedChild("Visible")
        ZO_CheckButton_SetLabelText(visible, L.SLOT_VISIBLE)
        ZO_CheckButton_SetToggleFunction(visible, function(_, checked)
            self:Change(function(item) item.hidden = not checked end)
        end)
        self.visibleCheck = visible
    end

    -- Позиция окна
    local saved = QTM.sv.editorPositions[adapter.sceneName]
    if saved and saved.x then
        window:ClearAnchors()
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    end
    window:SetHandler("OnMoveStop", function()
        QTM.sv.editorPositions[adapter.sceneName] = { x = window:GetLeft(), y = window:GetTop() }
    end)

    -- Сцена: курсор и закрытие по Esc
    self.scene = ZO_Scene:New(adapter.sceneName, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    self.scene:AddFragment(ZO_SimpleSceneFragment:New(window))
    self.scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            self:Refresh()
            self:PickPlaceIfUnbound()
        elseif newState == SCENE_HIDDEN then
            QTM.ClosePickers()
            ZO_Tooltips_HideTextTooltip()
        end
    end)
end

---------------------------------------------------------------------------
-- Показ
---------------------------------------------------------------------------
-- selectIndex — какой элемент выделить (необязательно)
function SlotEditor:Show(selectIndex)
    if selectIndex then self.selectedIndex = selectIndex end
    if SCENE_MANAGER:IsShowing(self.adapter.sceneName) then
        self:Refresh()
        self:PickPlaceIfUnbound()
    else
        SCENE_MANAGER:Show(self.adapter.sceneName)
    end
end

-- У выделенной кнопки ещё нет места — сразу открываем выбор места
function SlotEditor:PickPlaceIfUnbound()
    local item = self:GetSelected()
    if item and not item.nodeIndex then
        self:PickPlace()
    end
end

function SlotEditor:RefreshIfShown()
    if SCENE_MANAGER:IsShowing(self.adapter.sceneName) then self:Refresh() end
end

function SlotEditor:Hide()
    if SCENE_MANAGER:IsShowing(self.adapter.sceneName) then
        SCENE_MANAGER:Hide(self.adapter.sceneName)
    end
end

function SlotEditor:GetSelected()
    local items = self.adapter.GetItems()
    if self.selectedIndex and items[self.selectedIndex] then
        return items[self.selectedIndex]
    end
end

function SlotEditor:Refresh()
    local items = self.adapter.GetItems()
    if #items == 0 then
        self.selectedIndex = nil
    elseif not self.selectedIndex or not items[self.selectedIndex] then
        self.selectedIndex = 1
    end

    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)
    for index, item in ipairs(items) do
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW, { item = item, index = index })
    end
    ZO_ScrollList_Commit(self.list)
    self:RefreshDetails()
end

---------------------------------------------------------------------------
-- Список
---------------------------------------------------------------------------
function SlotEditor:SetupRow(control, data)
    control.editor = self
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)

    local item = data.item
    local node = item.nodeIndex and Data:GetNode(item.nodeIndex)
    local available = node and Data:GetNodeStatus(node)
    local selected = data.index == self.selectedIndex

    Style.PaintTile(control:GetNamedChild("Tile"), {
        icon = Style.ResolveIcon(item, node), color = item.color, tint = item.tint,
    }, { size = 40, available = node ~= nil and available, selected = selected })

    local name = control:GetNamedChild("Name")
    local info = control:GetNamedChild("Info")
    if node then
        name:SetText(node.name)
        info:SetText(node.zoneName)
    else
        name:SetText(L.SLOT_NO_PLACE)
        info:SetText(zo_strformat(L.SLOT_NUMBER, data.index))
    end
    SetColor(name, selected and ZO_SELECTED_TEXT or ZO_HIGHLIGHT_TEXT)
    control:GetNamedChild("Selected"):SetHidden(not selected)
    control:GetNamedChild("Highlight"):SetAlpha(0)
end

function SlotEditor.OnRowEnter(control)
    control:GetNamedChild("Highlight"):SetAlpha(1)
end

function SlotEditor.OnRowExit(control)
    control:GetNamedChild("Highlight"):SetAlpha(0)
end

function SlotEditor.OnRowClicked(control, button)
    local self = control.editor
    if not self or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self.selectedIndex = control.data.index
    ZO_ScrollList_RefreshVisible(self.list)
    self:RefreshDetails()
end

function SlotEditor:AddItem()
    local item = self.adapter.Add()
    if not item then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self.selectedIndex = #self.adapter.GetItems()
    self:Refresh()
    ZO_ScrollList_ScrollDataIntoView(self.list, self.selectedIndex)
    -- Сразу предлагаем выбрать место для новой кнопки
    self:PickPlace()
end

function SlotEditor:RemoveSelected()
    local item = self:GetSelected()
    if not item then return end
    self.adapter.Remove(item, self.selectedIndex)
    self.selectedIndex = zo_max(1, self.selectedIndex - 1)
    self:Refresh()
end

function SlotEditor:MoveSelected(delta)
    if not self:GetSelected() then return end
    self.selectedIndex = self.adapter.Move(self.selectedIndex, delta)
    self:Refresh()
end

---------------------------------------------------------------------------
-- Правая панель
---------------------------------------------------------------------------
function SlotEditor:RefreshDetails()
    local item = self:GetSelected()
    self.details:SetHidden(item == nil)
    self.body:GetNamedChild("Empty"):SetHidden(item ~= nil)
    self.removeButton:SetEnabled(item ~= nil)
    self.upButton:SetEnabled(item ~= nil)
    self.downButton:SetEnabled(item ~= nil)
    if not item then return end

    local node = item.nodeIndex and Data:GetNode(item.nodeIndex)
    local available = node ~= nil and Data:GetNodeStatus(node)
    local look = { icon = Style.ResolveIcon(item, node), color = item.color, tint = item.tint }

    -- Большое превью: как кнопка будет выглядеть (не больше 96 px)
    local previewSize = zo_min(item.size or 64, PREVIEW_MAX)
    self.preview:ClearAnchors()
    self.preview:SetAnchor(CENTER, self.details, TOPLEFT, PREVIEW_MAX / 2, PREVIEW_MAX / 2)
    Style.PaintTile(self.preview, look, {
        size = previewSize, available = available,
        label = self.adapter.hasButtonOptions and item.showLabel and node and node.name or nil,
    })

    self.renameButton:SetEnabled(node ~= nil)
    if node then
        self.placeName:SetText(node.name)
        self.placeInfo:SetText(node.zoneName .. " · " .. Data.TYPE_NAMES[node.type])
        if available then
            self.placePrice:SetText(L.PRICE_LABEL .. " " .. Data:GetPriceInfo(node))
            SetColor(self.placePrice, ZO_NORMAL_TEXT)
        else
            local _, reason = Data:GetNodeStatus(node)
            self.placePrice:SetText(reason or "")
            SetColor(self.placePrice, ZO_ERROR_COLOR)
        end
    else
        self.placeName:SetText(L.SLOT_NO_PLACE)
        self.placeInfo:SetText(L.SLOT_NO_PLACE_HINT)
        self.placePrice:SetText("")
    end

    Style.PaintTile(self.iconPreview, look, { size = 44, available = true })
    self:PaintSwatch()
    self:PaintPalette()
    ZO_CheckButton_SetCheckState(self.tintCheck, item.tint == true)

    if self.adapter.hasButtonOptions then
        self.sizeValue:SetText(tostring(item.size or 56))
        ZO_CheckButton_SetCheckState(self.showLabelCheck, item.showLabel == true)
        ZO_CheckButton_SetCheckState(self.visibleCheck, item.hidden ~= true)
    end
end

-- Изменить выбранный элемент и обновить всё, что от него зависит
function SlotEditor:Change(mutator)
    local item = self:GetSelected()
    if not item then return end
    mutator(item)
    self.adapter.OnChanged(item)
    ZO_ScrollList_RefreshVisible(self.list)
    self:RefreshDetails()
end

function SlotEditor:ChangeSize(delta)
    self:Change(function(item)
        item.size = QTM.Buttons:ClampSize((item.size or 56) + delta)
    end)
end

function SlotEditor:PickPlace()
    if not self:GetSelected() then return end
    QTM.IconPicker:Close()
    QTM.PlacePicker:Open(function(nodeIndex)
        self:Change(function(item) item.nodeIndex = nodeIndex end)
    end)
end

function SlotEditor:PickIcon()
    local item = self:GetSelected()
    if not item then return end
    QTM.PlacePicker:Close()
    QTM.IconPicker:Open({ color = item.color, tint = item.tint }, function(path)
        self:Change(function(target) target.icon = path end)
    end)
end

---------------------------------------------------------------------------
-- Цвет
---------------------------------------------------------------------------
function SlotEditor:PaintSwatch()
    local item = self:GetSelected()
    if not item then return end
    Style.PaintTile(self.colorSwatch, { color = item.color }, { size = 44, hover = self.colorSwatch.isHover })
end

function SlotEditor:PickColor()
    local item = self:GetSelected()
    if not item then return end
    local c = item.color or Style.DEFAULT_COLOR
    SYSTEMS:GetObject("colorPicker"):Show(function(r, g, b)
        self:Change(function(target) target.color = { r = r, g = g, b = b } end)
    end, c.r, c.g, c.b)
end

function SlotEditor:CreatePalette(container)
    self.swatches = {}
    for index, color in ipairs(Style.PALETTE) do
        local swatch = CreateControlFromVirtual(container:GetName() .. "Swatch" .. index, container, "MundusGate_Tile")
        swatch:SetAnchor(TOPLEFT, container, TOPLEFT, (index - 1) * (SWATCH_SIZE + SWATCH_GAP), 0)
        swatch:SetMouseEnabled(true)
        swatch.color = color
        swatch:SetHandler("OnMouseEnter", function(c) c.isHover = true; self:PaintPalette() end)
        swatch:SetHandler("OnMouseExit", function(c) c.isHover = false; self:PaintPalette() end)
        swatch:SetHandler("OnMouseUp", function(c, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                self:Change(function(item) item.color = Style.CopyColor(c.color) end)
            end
        end)
        self.swatches[index] = swatch
    end
end

function SlotEditor:PaintPalette()
    local item = self:GetSelected()
    for _, swatch in ipairs(self.swatches) do
        local current = item and Style.SameColor(item.color, swatch.color)
        Style.PaintTile(swatch, { color = swatch.color }, {
            size = SWATCH_SIZE, hover = swatch.isHover, selected = current,
        })
    end
end

---------------------------------------------------------------------------
-- Редактор кнопок на экране
---------------------------------------------------------------------------
function SlotEditor.CreateEditors()
    local Buttons = QTM.Buttons

    local buttonsEditor = SlotEditor:New(MundusGateButtonsWindow, {
        title     = L.BUTTONS_TITLE,
        hint      = L.BUTTONS_HINT,
        empty     = L.BUTTONS_EMPTY,
        sceneName = "MundusGateButtonsScene",
        hasButtonOptions = true,
        GetItems  = function() return Buttons:GetList() end,
        Add       = function() return Buttons:Add(nil) end,
        Remove    = function(item) Buttons:Remove(item.id) end,
        OnChanged = function(item) Buttons:Refresh(item) end,
    })
    -- Открыть редактор кнопок, выделив кнопку с данным id
    QTM.ButtonsEditor = {
        Show = function(_, id)
            local index
            if id then
                local _, found = Buttons:FindById(id)
                index = found
            end
            buttonsEditor:Show(index)
        end,
        editor = buttonsEditor,
    }

end
