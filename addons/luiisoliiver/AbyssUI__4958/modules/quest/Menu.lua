-- Окно быстрого меню, которое открывается по клавише.
local QTM  = AbyssQuest
local L    = QTM.L
local Data = QTM.Data

local Menu = {}
QTM.Menu = Menu

local SCENE_NAME      = "AbyssQuestScene"
local TYPE_HEADER     = 1
local TYPE_ROW        = 2
local TYPE_EMPTY      = 3
local TYPE_PLAYER     = 4    -- «Святилище рядом с @игрок — Бесплатно»
local PLAYER_ICON     = "/esoui/art/icons/mapkey/mapkey_groupmember.dds"
local HEADER_HEIGHT   = 26
local ROW_HEIGHT      = 30
local EMPTY_HEIGHT    = 80
local CHROME_HEIGHT   = 100  -- заголовок, строка статуса и подсказка внизу
local MAX_LIST_HEIGHT = 520

local function SetColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

function Menu:Initialize()
    local win = AbyssQuestWindow
    self.window = win
    self.title  = win:GetNamedChild("Title")
    self.status = win:GetNamedChild("Status")
    self.hint   = win:GetNamedChild("Hint")
    self.list   = win:GetNamedChild("List")

    self.title:SetText(L.MENU_TITLE)
    self.hint:SetText(L.MENU_HINT)

    ZO_ScrollList_AddDataType(self.list, TYPE_HEADER, "AbyssQuest_MenuHeader", HEADER_HEIGHT,
        function(control, data) self:SetupHeader(control, data) end)
    ZO_ScrollList_AddDataType(self.list, TYPE_ROW, "AbyssQuest_MenuRow", ROW_HEIGHT,
        function(control, data) self:SetupRow(control, data) end)
    ZO_ScrollList_AddDataType(self.list, TYPE_PLAYER, "AbyssQuest_MenuRow", ROW_HEIGHT,
        function(control, data) self:SetupPlayerRow(control, data) end)
    ZO_ScrollList_AddDataType(self.list, TYPE_EMPTY, "AbyssQuest_Empty", EMPTY_HEIGHT,
        function(control, data) self:SetupEmpty(control, data, self.list) end)

    -- Восстанавливаем позицию окна, если игрок его перетаскивал
    local pos = QTM.sv.window
    if pos and pos.x and pos.y then
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end

    -- Своя «сцена»: игра сама покажет курсор и закроет окно по Esc
    self.fragment = ZO_SimpleSceneFragment:New(win)
    self.scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    self.scene:AddFragment(self.fragment)
    self.scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            self:Refresh()
        elseif newState == SCENE_HIDDEN then
            ZO_Tooltips_HideTextTooltip()
        end
    end)
end

function Menu:Toggle()
    -- У святилища меню живёт поверх карты, а не в своей сцене
    if QTM.atWayshrine then
        if self.overlay then self:HideOverlay() else self:ShowOverlay() end
        return
    end
    SCENE_MANAGER:Toggle(SCENE_NAME)
end

function Menu:Hide()
    self:HideOverlay()
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then
        SCENE_MANAGER:Hide(SCENE_NAME)
    end
end

---------------------------------------------------------------------------
-- Меню у святилища.
-- Активированное святилище открывает карту. Если открыть меню как обычно
-- (своей сценой), карта закроется и взаимодействие со святилищем прервётся —
-- перемещение снова станет платным. Поэтому у святилища окно показывается
-- поверх карты, а сцена карты остаётся открытой.
---------------------------------------------------------------------------
function Menu:ShowOverlay()
    self.overlay = true
    self.window:SetHidden(false)
    self:Refresh()
    -- Карта открывается в тот же момент — поднимаем окно над ней чуть позже
    zo_callLater(function()
        if self.overlay then pcall(self.window.BringWindowToTop, self.window) end
    end, 100)
end

function Menu:HideOverlay()
    if not self.overlay then return end
    self.overlay = false
    ZO_Tooltips_HideTextTooltip()
    if not (self.scene and self.scene:IsShowing()) then
        self.window:SetHidden(true)
    end
end

function Menu:IsShown()
    return self.overlay or (self.scene ~= nil and self.scene:IsShowing())
end

function Menu:RefreshIfShown()
    if self:IsShown() then
        self:Refresh()
    end
end

function Menu:OnMoveStop()
    QTM.sv.window = { x = self.window:GetLeft(), y = self.window:GetTop() }
end

---------------------------------------------------------------------------
-- Наполнение списка
---------------------------------------------------------------------------
function Menu:Refresh()
    local sv = QTM.sv
    local favorites = Data:GetFavoriteNodes(not sv.groupByZone)

    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)
    local contentHeight = 0
    local lastZone

    -- Строки «Святилище рядом с @игрок» — по одной на локацию, где есть ваши места
    -- и сейчас находится друг или согильдиец
    local playerRowAdded = {}
    local function AddPlayerRow(node, withZoneName)
        if QTM.atWayshrine or not node.zoneId or playerRowAdded[node.zoneId] then return end
        local entry = QTM.Presence:FindFor(node)
        if not entry then return end
        playerRowAdded[node.zoneId] = true
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_PLAYER, {
            playerRow = true, entry = entry, zoneId = node.zoneId, zoneName = node.zoneName,
            withZoneName = withZoneName,
        })
        contentHeight = contentHeight + ROW_HEIGHT
    end
    if not sv.groupByZone then
        for _, node in ipairs(favorites) do AddPlayerRow(node, true) end
    end

    for _, node in ipairs(favorites) do
        local available, reason = Data:GetNodeStatus(node)
        if available or sv.showUnavailable then
            if sv.groupByZone and node.zoneName ~= lastZone then
                lastZone = node.zoneName
                dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_HEADER, { text = node.zoneName })
                contentHeight = contentHeight + HEADER_HEIGHT
                AddPlayerRow(node, false)
            end

            local priceText, affordable, isFree, isRoute = Data:GetDisplayPrice(node, "Menu")
            dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW, {
                node       = node,
                available  = available,
                reason     = reason,
                priceText  = priceText,
                affordable = affordable,
                isFree     = isFree,
                isRoute    = isRoute,
            })
            contentHeight = contentHeight + ROW_HEIGHT
        end
    end

    if #dataList == 0 then
        local text = (#favorites == 0) and L.MENU_EMPTY or L.MENU_ALL_HIDDEN
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY, { text = text })
        contentHeight = EMPTY_HEIGHT
    end

    -- Окно подстраивает высоту под количество мест, но не больше MAX_LIST_HEIGHT
    self.window:SetHeight(CHROME_HEIGHT + zo_min(contentHeight, MAX_LIST_HEIGHT))
    ZO_ScrollList_Commit(self.list)

    self:UpdateStatus()
end

function Menu:UpdateStatus()
    local block = Data:GetBlockReason(false)
    if QTM.atWayshrine then
        self.status:SetText(L.STATUS_AT_WAYSHRINE)
        SetColor(self.status, ZO_SUCCEEDED_TEXT)
    elseif block then
        self.status:SetText(block)
        SetColor(self.status, ZO_ERROR_COLOR)
    else
        local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
        local goldText = ZO_Currency_FormatKeyboard(CURT_MONEY, gold, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
        self.status:SetText(zo_strformat(L.STATUS_GOLD, goldText))
        SetColor(self.status, ZO_NORMAL_TEXT)
    end
end

---------------------------------------------------------------------------
-- Отрисовка строк
---------------------------------------------------------------------------
-- Строка «список пуст» (общая для меню и окна «Мои места»)
function Menu:SetupEmpty(control, data, list)
    control:SetWidth(list:GetWidth() - 16)
    control:GetNamedChild("Text"):SetText(data.text)
end

-- Кнопка-карандаш в заголовке меню: открыть окно «Мои места»
function Menu:OnEditClicked()
    QTM.Settings:Show()
end

function Menu:SetupHeader(control, data)
    control:SetWidth(self.list:GetWidth() - 16)
    control:GetNamedChild("Text"):SetText(data.text)
end

-- Строка «Святилище рядом с @игрок — Бесплатно»
function Menu:SetupPlayerRow(control, data)
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)
    control:SetAlpha(1)
    control:GetNamedChild("Highlight"):SetAlpha(0)

    local icon = control:GetNamedChild("Icon")
    icon:SetTexture(PLAYER_ICON)
    icon:SetDesaturation(0)

    local name = control:GetNamedChild("Name")
    local text = zo_strformat(L.ROW_NEAR_PLAYER, data.entry.displayName)
    if data.withZoneName then
        text = text .. " |c8A8A8A(" .. data.zoneName .. ")|r"
    end
    name:SetText(text)
    SetColor(name, ZO_SUCCEEDED_TEXT)

    local price = control:GetNamedChild("Price")
    price:SetText(L.FREE)
    SetColor(price, ZO_SUCCEEDED_TEXT)
end

function Menu:SetupRow(control, data)
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)

    local node  = data.node
    local icon  = control:GetNamedChild("Icon")
    local name  = control:GetNamedChild("Name")
    local price = control:GetNamedChild("Price")
    control:GetNamedChild("Highlight"):SetAlpha(0)

    local text = node.name
    if not QTM.sv.groupByZone then
        text = text .. " |c8A8A8A(" .. node.zoneName .. ")|r"
    end
    name:SetText(text)
    icon:SetTexture(node.icon)

    if data.available then
        -- Открытое место: яркое
        control:SetAlpha(1)
        icon:SetDesaturation(0)
        SetColor(name, ZO_HIGHLIGHT_TEXT)
        price:SetText(data.priceText)
        if data.isRoute then
            price:SetColor(QTM.Style.ICE[1], QTM.Style.ICE[2], QTM.Style.ICE[3], 1)
        elseif data.isFree then
            SetColor(price, ZO_SUCCEEDED_TEXT)
        elseif data.affordable then
            SetColor(price, ZO_NORMAL_TEXT)
        else
            SetColor(price, ZO_ERROR_COLOR)
        end
    else
        -- Неоткрытое место: тусклое и серое
        control:SetAlpha(0.45)
        icon:SetDesaturation(1)
        SetColor(name, ZO_DISABLED_TEXT)
        price:SetText(data.reason or "")
        SetColor(price, ZO_DISABLED_TEXT)
    end
end

---------------------------------------------------------------------------
-- Мышь (обработчики вызываются из AbyssQuest.xml)
---------------------------------------------------------------------------
function Menu:OnRowEnter(control)
    local data = control.data
    if not data then return end
    if data.playerRow then
        control:GetNamedChild("Highlight"):SetAlpha(1)
        local details = QTM.Presence:DescribeNearPlayer(data.zoneId) or ""
        QTM.ShowTip("menu", control, RIGHT, data.zoneName .. "\n" .. details)
        return
    end
    if data.available then
        control:GetNamedChild("Highlight"):SetAlpha(1)
    end
    local tip = data.node.zoneName .. "\n" .. Data.TYPE_NAMES[data.node.type]
    if data.node.isRenamed then
        tip = "|c9A9A9A" .. data.node.originalName .. "|r\n" .. tip
    end
    if not data.available and data.reason then
        tip = tip .. "\n|cFF6060" .. data.reason .. "|r"
    elseif data.isRoute then
        tip = tip .. "\n|c" .. QTM.Style.Hex(QTM.Style.ICE) .. "" .. zo_strformat(L.ROUTE_TOOLTIP, data.node.name) .. "|r\n|c9A9A9A"
            .. zo_strformat(L.ROUTE_TOOLTIP_COST, (Data:GetPriceInfo(data.node))) .. "|r"
    end
    QTM.ShowTip("menu", control, RIGHT, tip)
end

function Menu:OnRowExit(control)
    control:GetNamedChild("Highlight"):SetAlpha(0)
    ZO_Tooltips_HideTextTooltip()
end

function Menu:TravelTo(node, payNow)
    local result = Data:Travel(node, payNow, "Menu")
    if result == "started" then
        self:Hide()
    end
end

function Menu:OnRowClicked(control, button)
    local data = control.data
    if not data then return end

    if data.playerRow then
        if button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            if Data:TravelToPlayer(data.entry, data.zoneName) == "started" then self:Hide() end
        end
        return
    end

    local node = data.node

    if button == MOUSE_BUTTON_INDEX_LEFT then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:TravelTo(node)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()
        if data.available then
            AddMenuItem(L.CTX_TRAVEL, function() self:TravelTo(node) end)
            -- Бесплатный путь включён — можно заплатить и сразу; выключен — можно бесплатно
            if QTM.Route:WillUse(node, "Menu") then
                AddMenuItem(zo_strformat(L.CTX_PAY_NOW, (Data:GetPriceInfo(node))), function() self:TravelTo(node, true) end)
            elseif QTM.Route:CanRoute(node) then
                AddMenuItem(L.CTX_ROUTE_FREE, function()
                    if QTM.Route:Request(node) == "started" then self:Hide() end
                end)
            end
        end
        AddMenuItem(L.CTX_RENAME, function() Data:ShowRenameDialog(node) end)
        AddMenuItem(L.CTX_ADD_BUTTON, function()
            QTM.Buttons:Add(node.nodeIndex)
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_BUTTON_ADDED, node.name))
        end)
        AddMenuItem(L.CTX_ADD_WHEEL, function()
            if QTM.Wheel:AddSlot(node.nodeIndex) then
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_WHEEL_ADDED, node.name))
            end
        end)
        AddMenuItem(L.CTX_REMOVE, function()
            Data:SetFavorite(node.nodeIndex, false)
            self:Refresh()
            QTM.Settings:RefreshEditor()
        end)
        if node.isPlayerHouse and not node.isGuildHall then
            AddMenuItem(L.CTX_FORGET_PLAYER_HOUSE, function()
                Data:RemovePlayerHouse(node.displayName)
                QTM.Buttons:RefreshAll()
                self:Refresh()
            end)
        end
        ShowMenu(control)
    end
end
