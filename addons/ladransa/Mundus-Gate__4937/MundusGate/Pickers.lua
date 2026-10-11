-- Окна выбора: «Выбор места» и «Выбор значка».
-- Открываются поверх редакторов кнопок и колеса и возвращают результат
-- через функцию обратного вызова.
local QTM   = MundusGate
local L     = QTM.L
local Data  = QTM.Data
local Style = QTM.Style
local Icons = QTM.Icons

local lower = zo_strlower or string.lower

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SetColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

---------------------------------------------------------------------------
-- Выбор места
---------------------------------------------------------------------------
local PlacePicker = {}
QTM.PlacePicker = PlacePicker

local TYPE_HEADER = 1
local TYPE_ROW    = 2
local TYPE_EMPTY  = 3

function PlacePicker:Initialize()
    local win = MundusGatePlacePicker
    self.window = win
    self.filter = { text = "", onlyOpen = false, onlyFavorites = false }

    win:GetNamedChild("Title"):SetText(L.PICK_PLACE_TITLE)
    win:GetNamedChild("Hint"):SetText(L.PICK_PLACE_HINT)

    local search = win:GetNamedChild("SearchBgBox")
    search:SetMaxInputChars(60)
    search:SetHandler("OnTextChanged", function(edit)
        self.filter.text = edit:GetText()
        self:Refresh()
    end)
    self.search = search

    local onlyOpen = win:GetNamedChild("OnlyOpen")
    ZO_CheckButton_SetLabelText(onlyOpen, L.EDITOR_ONLY_OPEN)
    ZO_CheckButton_SetToggleFunction(onlyOpen, function(_, checked)
        self.filter.onlyOpen = checked
        self:Refresh()
    end)

    local onlyFav = win:GetNamedChild("OnlyFav")
    ZO_CheckButton_SetLabelText(onlyFav, L.PICK_PLACE_ONLY_MINE)
    ZO_CheckButton_SetToggleFunction(onlyFav, function(_, checked)
        self.filter.onlyFavorites = checked
        self:Refresh()
    end)

    local list = win:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_HEADER, "MundusGate_PickerHeader", 30,
        function(control, data)
            control:SetWidth(list:GetWidth() - 16)
            control:GetNamedChild("Text"):SetText(data.text)
        end)
    ZO_ScrollList_AddDataType(list, TYPE_ROW, "MundusGate_PickerRow", 30,
        function(control, data) self:SetupRow(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_EMPTY, "MundusGate_Empty", 80,
        function(control, data) QTM.Menu:SetupEmpty(control, data, list) end)
end

function PlacePicker:Open(callback)
    self.callback = callback
    self.window:SetHidden(false)
    self.search:SetText("")
    self:Refresh()
end

function PlacePicker:Close()
    self.window:SetHidden(true)
    self.callback = nil
    ZO_Tooltips_HideTextTooltip()
end

function PlacePicker:Refresh()
    local f = self.filter
    local query = lower(Trim(f.text or ""))
    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)

    local lastZone
    for _, node in ipairs(Data:GetNodes()) do
        local ok = (query == "" or node.searchKey:find(query, 1, true) ~= nil)
            and (not f.onlyFavorites or Data:IsFavorite(node.nodeIndex))
        if ok then
            local available, reason = Data:GetNodeStatus(node)
            if available or not f.onlyOpen then
                if node.zoneName ~= lastZone then
                    lastZone = node.zoneName
                    dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_HEADER, { text = node.zoneName })
                end
                dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW,
                    { node = node, available = available, reason = reason })
            end
        end
    end
    if #dataList == 0 then
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY, { text = L.EDITOR_NOTHING })
    end
    ZO_ScrollList_Commit(self.list)
end

function PlacePicker:SetupRow(control, data)
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
    local text = Data.TYPE_NAMES[node.type]
    if not data.available then text = text .. " · " .. (data.reason or "") end
    info:SetText(text)
    SetColor(info, data.available and ZO_NORMAL_TEXT or ZO_DISABLED_TEXT)
end

function PlacePicker:OnRowEnter(control)
    control:GetNamedChild("Highlight"):SetAlpha(1)
end

function PlacePicker:OnRowExit(control)
    control:GetNamedChild("Highlight"):SetAlpha(0)
end

function PlacePicker:RefreshIfShown()
    if self.window and not self.window:IsHidden() then self:Refresh() end
end

function PlacePicker:OnRowClicked(control, button)
    if button == MOUSE_BUTTON_INDEX_RIGHT and control.data then
        ClearMenu()
        AddMenuItem(L.CTX_RENAME, function() Data:ShowRenameDialog(control.data.node) end)
        ShowMenu(control)
        return
    end
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not control.data then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    local callback = self.callback
    self:Close()
    if callback then callback(control.data.node.nodeIndex) end
end

---------------------------------------------------------------------------
-- Выбор значка
---------------------------------------------------------------------------
local IconPicker = {}
QTM.IconPicker = IconPicker

local TYPE_ICON_ROW = 1
local COLUMNS       = 10
local CELL_SIZE     = 44
local CELL_GAP      = 8

function IconPicker:Initialize()
    local win = MundusGateIconPicker
    self.window = win
    self.tab = Icons.TAB_PLACES
    self.query = ""

    win:GetNamedChild("Title"):SetText(L.PICK_ICON_TITLE)
    win:GetNamedChild("PathCaption"):SetText(L.PICK_ICON_PATH)
    self.count = win:GetNamedChild("Count")

    -- Вкладки
    self.tabs = {}
    for tab = Icons.TAB_PLACES, Icons.TAB_COLLECTIBLES do
        local button = win:GetNamedChild("Tab" .. tab)
        button:SetText(Icons.TAB_NAMES[tab])
        button:SetHandler("OnClicked", function() self:SelectTab(tab) end)
        self.tabs[tab] = button
    end
    self.tabIndicator = win:GetNamedChild("TabIndicator")

    -- Поиск
    local search = win:GetNamedChild("SearchBgBox")
    search:SetMaxInputChars(60)
    search:SetHandler("OnTextChanged", function(edit)
        self.query = lower(Trim(edit:GetText()))
        self:Refresh()
    end)
    self.search = search

    -- Свой путь к текстуре
    self.pathBox = win:GetNamedChild("PathBgBox")
    self.pathBox:SetMaxInputChars(200)
    local apply = win:GetNamedChild("Apply")
    apply:SetText(L.PICK_ICON_APPLY)
    apply:SetHandler("OnClicked", function()
        local path = Trim(self.pathBox:GetText())
        if path ~= "" then self:Choose(path) end
    end)

    -- Сетка значков
    local list = win:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_ICON_ROW, "MundusGate_IconRow", CELL_SIZE + CELL_GAP,
        function(control, data) self:SetupRow(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_EMPTY, "MundusGate_Empty", 80,
        function(control, data) QTM.Menu:SetupEmpty(control, data, list) end)
end

-- look = { color = {r,g,b}, tint = bool } — чтобы значки сразу показывались как на кнопке
function IconPicker:Open(look, callback)
    self.look = look or {}
    self.callback = callback
    self.window:SetHidden(false)
    self.pathBox:SetText("")
    self.search:SetText("")
    self:SelectTab(self.tab)
end

function IconPicker:Close()
    self.window:SetHidden(true)
    self.callback = nil
    ZO_Tooltips_HideTextTooltip()
end

function IconPicker:SelectTab(tab)
    self.tab = tab
    local button = self.tabs[tab]
    self.tabIndicator:ClearAnchors()
    self.tabIndicator:SetAnchor(TOPLEFT, button, BOTTOMLEFT, 4, 1)
    self.tabIndicator:SetAnchor(TOPRIGHT, button, BOTTOMRIGHT, -4, 1)
    self:Refresh()
end

function IconPicker:Refresh()
    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)

    local row, total = nil, 0
    for _, entry in ipairs(Icons:GetTab(self.tab)) do
        if self.query == "" or entry.key:find(self.query, 1, true) then
            if not row or #row.entries >= COLUMNS then
                row = { entries = {} }
                dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ICON_ROW, row)
            end
            row.entries[#row.entries + 1] = entry
            total = total + 1
        end
    end
    if total == 0 then
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY, { text = L.EDITOR_NOTHING })
    end
    ZO_ScrollList_Commit(self.list)
    self.count:SetText(zo_strformat(L.PICK_ICON_COUNT, total))
end

function IconPicker:SetupRow(control, data)
    control:SetWidth(self.list:GetWidth() - 16)
    control.cells = control.cells or {}
    for i = 1, COLUMNS do
        local cell = control.cells[i]
        if not cell then
            cell = CreateControlFromVirtual(control:GetName() .. "Cell" .. i, control, "MundusGate_Tile")
            cell:SetAnchor(TOPLEFT, control, TOPLEFT, (i - 1) * (CELL_SIZE + CELL_GAP), 0)
            cell:SetMouseEnabled(true)
            cell:SetHandler("OnMouseEnter", function(c) self:OnCellEnter(c) end)
            cell:SetHandler("OnMouseExit", function(c) self:OnCellExit(c) end)
            cell:SetHandler("OnMouseUp", function(c, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT and c.entry then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    self:Choose(c.entry.icon)
                end
            end)
            control.cells[i] = cell
        end
        local entry = data.entries[i]
        cell.entry = entry
        if entry then
            cell:SetHidden(false)
            self:PaintCell(cell, false)
        else
            cell:SetHidden(true)
        end
    end
end

function IconPicker:PaintCell(cell, hover)
    Style.PaintTile(cell, {
        icon  = cell.entry.icon,
        color = self.look.color,
        tint  = self.look.tint,
    }, { size = CELL_SIZE, hover = hover })
end

function IconPicker:OnCellEnter(cell)
    if not cell.entry then return end
    self:PaintCell(cell, true)
    ZO_Tooltips_ShowTextTooltip(cell, TOP, cell.entry.name .. "\n|c7A7A7A" .. cell.entry.icon .. "|r")
end

function IconPicker:OnCellExit(cell)
    if not cell.entry then return end
    self:PaintCell(cell, false)
    ZO_Tooltips_HideTextTooltip()
end

function IconPicker:Choose(path)
    local callback = self.callback
    self:Close()
    if callback then callback(path) end
end

---------------------------------------------------------------------------
function QTM.ClosePickers()
    PlacePicker:Close()
    IconPicker:Close()
end
