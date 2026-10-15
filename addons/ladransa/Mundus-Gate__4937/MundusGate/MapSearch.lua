-- Быстрый поиск по карте: поле в нижней полосе окна карты, справа от
-- ползунка масштаба. Ищет всё, что есть на картах: локации, города,
-- святилища, подземелья, пещеры, достопримечательности, дома — и места,
-- куда переместиться нельзя (это просто поиск по карте).
-- Список открывается над полем, в оформлении аддона.
-- Навели на строку (мышью или стрелками) — карта переходит в нужную
-- локацию и показывает место; щелчок — оставить карту там; значок справа
-- (у мест, куда можно переместиться) — переместиться.
local QTM  = MundusGate
local L    = QTM.L
local Data = QTM.Data

local MapSearch = {}
QTM.MapSearch = MapSearch

local WIDTH       = 280
local LIST_WIDTH  = 430
local ROW_HEIGHT  = 44
local MAX_ROWS    = 8
local HOVER_DELAY = 120   -- мс: карта не дёргается, пока курсор проезжает по списку
local EDGE_GAP    = 10
local ICON_ZONE   = "EsoUI/Art/WorldMap/map_indexIcon_locations_up.dds"

local KIND_NODE, KIND_POI, KIND_ZONE = "node", "poi", "zone"

local lower = zo_strlower or string.lower
local ICE    = QTM.Style.ICE
local TEXT   = QTM.Style.TEXT
local DETAIL = QTM.Style.DETAIL

function MapSearch:IsEnabled()
    return QTM.sv.mapSearch ~= false
end

---------------------------------------------------------------------------
-- Элементы: поле поиска и список над ним
---------------------------------------------------------------------------
function MapSearch:Initialize()
    local WM = WINDOW_MANAGER
    local root = WM:CreateTopLevelWindow("MundusGateMapSearch")
    root:SetDimensions(WIDTH, 30)
    root:SetHidden(true)
    root:SetDrawTier(DT_MEDIUM)
    self.root = root

    local backdrop = WM:CreateControlFromVirtual("MundusGateMapSearchBg", root, "ZO_EditBackdrop")
    backdrop:SetAnchorFill(root)
    local edit = WM:CreateControlFromVirtual("MundusGateMapSearchBox", backdrop, "ZO_DefaultEditForBackdrop")
    edit:SetMaxInputChars(60)
    if edit.SetDefaultText then edit:SetDefaultText(L.MAP_SEARCH_HINT) end
    edit:SetHandler("OnTextChanged", function(box)
        self.query = lower(zo_strtrim(box:GetText()))
        self.selected = nil
        self:RefreshList()
    end)
    edit:SetHandler("OnFocusGained", function() self:RefreshList() end)
    edit:SetHandler("OnFocusLost", function()
        -- щелчок по строке снимает фокус раньше, чем срабатывает строка
        zo_callLater(function()
            if not self.edit:HasFocus() and not self:IsMouseOverList() then self:HideList() end
        end, 150)
    end)
    edit:SetHandler("OnUpArrow", function() self:MoveSelection(-1) end)
    edit:SetHandler("OnDownArrow", function() self:MoveSelection(1) end)
    edit:SetHandler("OnEnter", function()
        local row = self.rows[self.selected or 1]
        if row and not row:IsHidden() and row.entry then self:Pick(row.entry) end
        self.edit:LoseFocus()
    end)
    edit:SetHandler("OnEscape", function()
        self.edit:SetText("")
        self.edit:LoseFocus()
        self:HideList()
    end)
    self.edit = edit
    self.query = ""

    -- Список над полем: фон и рамка как у панелей аддона
    local list = WM:CreateControl("MundusGateMapSearchList", root, CT_CONTROL)
    list:SetDimensions(LIST_WIDTH, ROW_HEIGHT)
    list:SetAnchor(BOTTOMRIGHT, root, TOPRIGHT, 0, -6)
    list:SetMouseEnabled(true)
    list:SetHidden(true)
    local listBg = WM:CreateControlFromVirtual("MundusGateMapSearchListBg", list, "ZO_DefaultBackdrop")
    listBg:SetAnchorFill(list)
    QTM.Style.Themed(listBg, "panel")
    self.list = list

    self.rows = {}
    for index = 1, MAX_ROWS do
        self.rows[index] = self:CreateRow(index)
    end
    self.empty = WM:CreateControl("MundusGateMapSearchEmpty", list, CT_LABEL)
    self.empty:SetFont("ZoFontGame")
    self.empty:SetAnchor(LEFT, list, LEFT, 16, 0)
    self.empty:SetText(L.MAP_SEARCH_NOTHING)

    self.fragment = ZO_SimpleSceneFragment:New(root)
    root:SetHandler("OnUpdate", function()
        local now = GetFrameTimeMilliseconds()
        if not self.nextLayout or now >= self.nextLayout then
            self.nextLayout = now + 250
            self:Layout()
        end
    end)
    if WORLD_MAP_SCENE then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_HIDDEN then
                self:HideList()
                if self.edit:HasFocus() then self.edit:LoseFocus() end
            end
        end)
    end
    self:Apply()
end

-- Строка: значок, название (целиком, в одну строку) и под ним — локация и вид места
function MapSearch:CreateRow(index)
    local WM = WINDOW_MANAGER
    local name = "MundusGateMapSearchRow" .. index
    local row = WM:CreateControl(name, self.list, CT_CONTROL)
    row:SetDimensions(LIST_WIDTH - 16, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, self.list, TOPLEFT, 8, 6 + (index - 1) * ROW_HEIGHT)
    row:SetMouseEnabled(true)

    local bg = WM:CreateControl(name .. "Bg", row, CT_TEXTURE)
    bg:SetAnchorFill(row)
    local stripe = WM:CreateControl(name .. "Stripe", row, CT_TEXTURE)
    stripe:SetDimensions(3, ROW_HEIGHT - 8)
    stripe:SetAnchor(LEFT, row, LEFT, 0, 0)
    local icon = WM:CreateControl(name .. "Icon", row, CT_TEXTURE)
    icon:SetDimensions(30, 30)
    icon:SetAnchor(LEFT, row, LEFT, 10, 0)
    local label = WM:CreateControl(name .. "Name", row, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    label:SetAnchor(TOPLEFT, row, TOPLEFT, 50, 3)
    label:SetAnchor(TOPRIGHT, row, TOPRIGHT, -40, 3)
    local info = WM:CreateControl(name .. "Info", row, CT_LABEL)
    info:SetFont("ZoFontGameSmall")
    info:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    info:SetMaxLineCount(1)
    info:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 50, -3)
    info:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -40, -3)
    local travel = WM:CreateControl(name .. "Travel", row, CT_BUTTON)
    travel:SetDimensions(28, 28)
    travel:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    local travelIcon = WM:CreateControl(name .. "TravelIcon", travel, CT_TEXTURE)
    travelIcon:SetAnchorFill(travel)
    travelIcon:SetTexture(QTM.InfoPanel.ICON_TRAVEL)
    row.bg, row.stripe, row.icon, row.label, row.info, row.travel, row.travelIcon = bg, stripe, icon, label, info, travel, travelIcon

    row:SetHandler("OnMouseEnter", function() self:Select(index, true) end)
    row:SetHandler("OnMouseExit", function() self:PaintRows() end)
    row:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and row.entry then self:Pick(row.entry) end
    end)
    travel:SetHandler("OnMouseEnter", function()
        self:Select(index, true)
        travelIcon:SetColor(1, 1, 1, 1)
        local node = row.entry and row.entry.node
        if node then QTM.ShowTip("mapPanel", travel, RIGHT, L.CTX_TRAVEL .. "\n" .. Data:GetPriceLine(node, "Menu")) end
    end)
    travel:SetHandler("OnMouseExit", function()
        ZO_Tooltips_HideTextTooltip()
        self:PaintRows()
    end)
    travel:SetHandler("OnClicked", function()
        local node = row.entry and row.entry.node
        if not node then return end
        ZO_Tooltips_HideTextTooltip()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if Data:Travel(node, false, "Menu") == "started" then
            self:HideList()
            SCENE_MANAGER:ShowBaseScene()
        end
    end)
    return row
end

-- Включить или выключить (настройка «Поиск мест под картой»)
function MapSearch:Apply()
    if not WORLD_MAP_SCENE or not self.fragment then return end
    local enabled = self:IsEnabled()
    if enabled == self.applied then return end
    self.applied = enabled
    if enabled then
        WORLD_MAP_SCENE:AddFragment(self.fragment)
    else
        WORLD_MAP_SCENE:RemoveFragment(self.fragment)
        self.root:SetHidden(true)
        self:HideList()
    end
end

-- Нижняя полоса окна карты, справа (по центру — ползунок масштаба)
function MapSearch:Layout()
    local map = ZO_WorldMap
    if not map then return end
    local strip = ZO_WorldMapButtons
    local key = tostring(map:GetRight()) .. ":" .. tostring(map:GetBottom())
    if key == self.layoutKey then return end
    self.layoutKey = key
    self.root:ClearAnchors()
    if strip then
        self.root:SetAnchor(RIGHT, strip, RIGHT, -EDGE_GAP, 0)
    else
        self.root:SetAnchor(BOTTOMRIGHT, map, BOTTOMRIGHT, -EDGE_GAP, -8)
    end
end

---------------------------------------------------------------------------
-- Что искать: места аддона, все отметки карт (POI) и сами локации.
-- Собирается один раз, при первом поиске
---------------------------------------------------------------------------
local function MapIndexForZone(zoneIndex)
    if not zoneIndex or zoneIndex <= 0 or not GetMapIndexByZoneId then return nil end
    local zoneId = GetZoneId(zoneIndex)
    local mapIndex = GetMapIndexByZoneId(zoneId)
    if not mapIndex and GetParentZoneId then
        local parent = GetParentZoneId(zoneId)
        if parent and parent ~= zoneId then mapIndex = GetMapIndexByZoneId(parent) end
    end
    return mapIndex
end

local function Format(text)
    if not text or text == "" then return "" end
    return zo_strformat("<<1>>", text)
end

function MapSearch:BuildEntries()
    local entries, taken = {}, {}

    -- Места аддона: святилища, подземелья, испытания, дома (с перемещением)
    for _, node in ipairs(Data:GetNodes()) do
        local target = Data:Resolve(node)
        if target and type(target.nodeIndex) == "number" then
            local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(target.nodeIndex)
            if zoneIndex and poiIndex then taken[zoneIndex .. ":" .. poiIndex] = true end
            entries[#entries + 1] = {
                kind = KIND_NODE, node = node, name = node.name, icon = node.icon,
                info = node.zoneName .. " · " .. Data.TYPE_NAMES[node.type],
                searchKey = node.searchKey,
            }
        end
    end

    -- Локации и все отметки на их картах
    local zoneSeen = {}
    for zoneIndex = 1, (GetNumZones and GetNumZones() or 0) do
        local zoneName = Format(GetZoneNameByIndex(zoneIndex))
        local mapIndex = MapIndexForZone(zoneIndex)
        if zoneName ~= "" and mapIndex then
            if not zoneSeen[zoneName] and GetMapIndexByZoneId(GetZoneId(zoneIndex)) then
                zoneSeen[zoneName] = true
                entries[#entries + 1] = {
                    kind = KIND_ZONE, zoneIndex = zoneIndex, name = zoneName, icon = ICON_ZONE,
                    info = L.MAP_SEARCH_ZONE, searchKey = lower(zoneName),
                }
            end
            for poiIndex = 1, (GetNumPOIs(zoneIndex) or 0) do
                local name = Format(GetPOIInfo(zoneIndex, poiIndex))
                if name ~= "" and not taken[zoneIndex .. ":" .. poiIndex] then
                    taken[zoneIndex .. ":" .. poiIndex] = true
                    local _, _, _, icon = GetPOIMapInfo(zoneIndex, poiIndex)
                    entries[#entries + 1] = {
                        kind = KIND_POI, zoneIndex = zoneIndex, poiIndex = poiIndex, name = name,
                        icon = (icon and icon ~= "") and icon or ICON_ZONE,
                        info = zoneName, searchKey = lower(name .. " " .. zoneName),
                    }
                end
            end
        end
    end
    self.entries = entries
    self.entriesFor = Data:GetNodes()
end

function MapSearch:GetEntries()
    if not self.entries or self.entriesFor ~= Data:GetNodes() then self:BuildEntries() end
    return self.entries
end

-- Сначала то, что начинается с запроса; затем места аддона, локации, остальное
local KIND_ORDER = { [KIND_ZONE] = 1, [KIND_NODE] = 2, [KIND_POI] = 3 }

function MapSearch:Find(query)
    local results = {}
    for _, entry in ipairs(self:GetEntries()) do
        local position = entry.searchKey:find(query, 1, true)
        if position then
            local nameStart = lower(entry.name):find(query, 1, true) == 1
            results[#results + 1] = { entry = entry, rank = nameStart and 0 or 1 }
        end
    end
    table.sort(results, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        local ka, kb = KIND_ORDER[a.entry.kind], KIND_ORDER[b.entry.kind]
        if ka ~= kb then return ka < kb end
        return a.entry.name < b.entry.name
    end)
    return results
end

function MapSearch:RefreshList()
    if not self.list then return end
    if self.query == "" then
        self:HideList()
        return
    end
    if not self.edit:HasFocus() then return end
    local results = self:Find(self.query)
    local count = zo_min(#results, MAX_ROWS)
    for index, row in ipairs(self.rows) do
        local entry = results[index] and results[index].entry
        row.entry = entry
        row:SetHidden(entry == nil)
        if entry then
            row.available = true
            if entry.node then row.available = Data:GetNodeStatus(entry.node) == true end
            row.icon:SetTexture(entry.icon or ICON_ZONE)
            row.label:SetText(entry.name)
            row.info:SetText(entry.info or "")
            row.travel:SetHidden(not (entry.node and row.available))
        end
    end
    self.empty:SetHidden(count > 0)
    self.list:SetHeight(zo_max(count, 1) * ROW_HEIGHT + 12)
    self.list:SetHidden(false)
    self:PaintRows()
end

function MapSearch:HideList()
    if self.list then self.list:SetHidden(true) end
    self.selected = nil
    self.pendingShow = nil
end

function MapSearch:IsMouseOverList()
    return self.list and not self.list:IsHidden() and MouseIsOver and MouseIsOver(self.list)
end

function MapSearch:PaintRows()
    for index, row in ipairs(self.rows) do
        local active = index == self.selected
        row.bg:SetColor(ICE[1], ICE[2], ICE[3], active and 0.18 or 0)
        row.stripe:SetColor(ICE[1], ICE[2], ICE[3], active and 1 or 0)
        row.label:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
        row.info:SetColor(DETAIL[1], DETAIL[2], DETAIL[3], 1)
        row.travelIcon:SetColor(ICE[1], ICE[2], ICE[3], 1)
    end
end

-- Выделить строку и (при наведении мышью — с небольшой задержкой) показать место на карте
function MapSearch:Select(index, fromMouse)
    local row = self.rows[index]
    if not row or row:IsHidden() or not row.entry then return end
    self.selected = index
    self:PaintRows()
    local entry = row.entry
    if fromMouse then
        self.pendingShow = entry
        zo_callLater(function()
            if self.pendingShow == entry and self.selected == index then self:ShowOnMap(entry) end
        end, HOVER_DELAY)
    else
        self:ShowOnMap(entry)
    end
end

function MapSearch:MoveSelection(step)
    local count = 0
    for _, row in ipairs(self.rows) do
        if not row:IsHidden() and row.entry then count = count + 1 end
    end
    if count == 0 then return end
    local index = (self.selected or (step > 0 and 0 or count + 1)) + step
    if index < 1 then index = count elseif index > count then index = 1 end
    self:Select(index, false)
end

-- Щелчок: карта остаётся на месте, список закрывается
function MapSearch:Pick(entry)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:ShowOnMap(entry)
    self.edit:LoseFocus()
    self:HideList()
end

---------------------------------------------------------------------------
-- Показать на карте: открыть карту нужной локации и плавно навести на место
---------------------------------------------------------------------------
local function OpenMap(mapIndex)
    if not mapIndex or mapIndex == GetCurrentMapIndex() then return end
    if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.SetMapByIndex then
        WORLD_MAP_MANAGER:SetMapByIndex(mapIndex)
    elseif SetMapToMapListIndex(mapIndex) == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
end

local function PanTo(x, y)
    if x and y and x > 0 and y > 0 and x < 1 and y < 1 and ZO_WorldMap_PanToNormalizedPosition then
        ZO_WorldMap_PanToNormalizedPosition(x, y)
    end
end

function MapSearch:ShowOnMap(entry)
    if not entry then return end
    if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then return end

    if entry.kind == KIND_ZONE then
        OpenMap(MapIndexForZone(entry.zoneIndex))
    elseif entry.kind == KIND_POI then
        OpenMap(MapIndexForZone(entry.zoneIndex))
        PanTo(GetPOIMapInfo(entry.zoneIndex, entry.poiIndex))
    else
        local target = Data:Resolve(entry.node)
        if not target or type(target.nodeIndex) ~= "number" then return end
        OpenMap(MapIndexForZone(GetFastTravelNodePOIIndicies(target.nodeIndex)))
        local _, _, x, y = GetFastTravelNodeInfo(target.nodeIndex)
        PanTo(x, y)
    end
end
