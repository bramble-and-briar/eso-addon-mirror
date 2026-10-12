-- Данные о местах перемещения: список узлов, доступность, цена и само перемещение.
local QTM = MundusGate
local L   = QTM.L

local Data = {}
QTM.Data = Data

---------------------------------------------------------------------------
-- Типы мест
---------------------------------------------------------------------------
Data.TYPE_WAYSHRINE = 1
Data.TYPE_DUNGEON   = 2
Data.TYPE_TRIAL     = 3
Data.TYPE_ARENA     = 4
Data.TYPE_HOUSE     = 5
Data.TYPE_OTHER     = 6
Data.TYPE_PLAYER_HOUSE = 7   -- дом другого игрока (добавлен из списка друзей, гильдии или группы)

Data.PLAYER_HOUSE_ICON = "/esoui/art/icons/mapkey/mapkey_housing.dds"

Data.TYPE_LIST = {
    Data.TYPE_WAYSHRINE, Data.TYPE_DUNGEON, Data.TYPE_TRIAL,
    Data.TYPE_ARENA, Data.TYPE_HOUSE, Data.TYPE_PLAYER_HOUSE, Data.TYPE_OTHER,
}

-- Названия типов берутся в момент показа — так они всегда на выбранном языке
local TYPE_KEYS = {
    [Data.TYPE_WAYSHRINE] = "TYPE_WAYSHRINE",
    [Data.TYPE_DUNGEON]   = "TYPE_DUNGEON",
    [Data.TYPE_TRIAL]     = "TYPE_TRIAL",
    [Data.TYPE_ARENA]     = "TYPE_ARENA",
    [Data.TYPE_HOUSE]     = "TYPE_HOUSE",
    [Data.TYPE_OTHER]     = "TYPE_OTHER",
    [Data.TYPE_PLAYER_HOUSE] = "TYPE_PLAYER_HOUSE",
}
Data.TYPE_NAMES = setmetatable({}, {
    __index = function(_, typeId) return TYPE_KEYS[typeId] and L[TYPE_KEYS[typeId]] or "" end,
})

local lower = zo_strlower or string.lower

local function Alert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, text)
end
Data.Alert = Alert

-- Тип места определяем по типу точки интереса и по пути к иконке на карте
local function Classify(poiType, icon)
    local path = string.lower(icon or "")
    local function has(s) return path:find(s, 1, true) ~= nil end

    if poiType == POI_TYPE_HOUSE then return Data.TYPE_HOUSE end
    if has("raiddungeon") then return Data.TYPE_TRIAL end
    if has("solotrial") or has("arena") then return Data.TYPE_ARENA end
    if has("endless") then return Data.TYPE_OTHER end
    if (POI_TYPE_GROUP_DUNGEON and poiType == POI_TYPE_GROUP_DUNGEON)
        or has("groupinstance") or has("dungeon") then
        return Data.TYPE_DUNGEON
    end
    if poiType == POI_TYPE_WAYSHRINE or has("wayshrine") then return Data.TYPE_WAYSHRINE end
    return Data.TYPE_OTHER
end

local function CompareByZone(a, b)
    if a.zoneName ~= b.zoneName then return a.zoneName < b.zoneName end
    if a.type ~= b.type then return a.type < b.type end
    if a.name ~= b.name then return a.name < b.name end
    return Data.CompareKeys(a.nodeIndex, b.nodeIndex)
end

local function CompareByName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return Data.CompareKeys(a.nodeIndex, b.nodeIndex)
end

---------------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------------
function Data:Initialize()
    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_CONFIRM", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = L.DIALOG_TITLE },
        mainText    = { text = L.DIALOG_TEXT },
        buttons     = {
            {
                text     = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    FastTravelToNode(dialog.data.nodeIndex)
                    QTM.Menu:Hide()
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })

    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_CONFIRM_PLAYER", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = L.DIALOG_TITLE },
        mainText    = { text = L.DIALOG_PLAYER_TEXT },
        buttons     = {
            {
                text     = L.DIALOG_PLAYER_CONFIRM,
                callback = function(dialog)
                    Data:JumpToPlayer(dialog.data.entry, dialog.data.savedCost)
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })

    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_RENAME", {
        title    = { text = L.RENAME_TITLE },
        mainText = { text = L.RENAME_TEXT },
        editBox  = { defaultText = "", maxInputCharacters = 60, selectAll = true },
        buttons  = {
            {
                text     = L.RENAME_SAVE,
                callback = function(dialog)
                    Data:Rename(dialog.data.nodeIndex, ZO_Dialogs_GetEditBoxText(dialog))
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })

    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_CLEAR", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = L.DIALOG_CLEAR_TITLE },
        mainText    = { text = L.DIALOG_CLEAR_TEXT },
        buttons     = {
            {
                text     = SI_DIALOG_CONFIRM,
                callback = function()
                    Data:ClearFavorites()
                    QTM.Settings:RefreshEditor()
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

-- Собираем все места перемещения один раз: имя, локацию, тип
function Data:BuildNodes()
    local nodes, byIndex, zones, zoneSeen = {}, {}, {}, {}

    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, name, _, _, icon, _, poiType = GetFastTravelNodeInfo(nodeIndex)
        if name and name ~= "" then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            local zoneId = (zoneIndex and zoneIndex > 0) and GetZoneId(zoneIndex) or nil
            local zoneName = ""
            if zoneIndex and zoneIndex > 0 then
                zoneName = GetZoneNameByIndex(zoneIndex) or ""
            end
            if zoneName == "" then
                zoneName = L.UNKNOWN_ZONE
            else
                zoneName = zo_strformat("<<1>>", zoneName)
            end

            local node = {
                nodeIndex    = nodeIndex,
                originalName = zo_strformat("<<1>>", name),
                zoneName     = zoneName,
                zoneId       = zoneId,
                icon         = icon,
                type         = Classify(poiType, icon),
            }
            self:ApplyCustomName(node)

            nodes[#nodes + 1] = node
            byIndex[nodeIndex] = node
            if not zoneSeen[zoneName] then
                zoneSeen[zoneName] = true
                zones[#zones + 1] = zoneName
            end
        end
    end

    -- Дома других игроков: ключ места — ID игрока («@name»)
    for _, displayName in ipairs(self:GetPlayerHouseNames()) do
        local node = self:MakePlayerHouseNode(displayName)
        nodes[#nodes + 1] = node
        byIndex[displayName] = node
        if not zoneSeen[node.zoneName] then
            zoneSeen[node.zoneName] = true
            zones[#zones + 1] = node.zoneName
        end
    end

    table.sort(nodes, CompareByZone)
    table.sort(zones)

    self.nodes, self.byIndex, self.zones = nodes, byIndex, zones
end

---------------------------------------------------------------------------
-- Свои названия мест: sv.customNames[ключ места] = "текст".
-- node.name — то, что видно везде; node.originalName — название из игры.
---------------------------------------------------------------------------
function Data:ApplyCustomName(node)
    local custom = QTM.sv.customNames[node.nodeIndex]
    node.isRenamed = custom ~= nil and custom ~= ""
    node.name = node.isRenamed and custom or node.originalName
    -- Искать можно и по своему, и по игровому названию
    node.searchKey = lower(node.name .. " " .. node.originalName .. " " .. node.zoneName
        .. (node.displayName and (" " .. node.displayName) or ""))
end

-- Пустое название или такое же, как в игре, — вернуть исходное
function Data:Rename(nodeIndex, newName)
    newName = newName and newName:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local node = self:GetNode(nodeIndex)
    if newName == "" or (node and newName == node.originalName) then
        QTM.sv.customNames[nodeIndex] = nil
    else
        QTM.sv.customNames[nodeIndex] = newName
    end
    -- Пересобираем список, чтобы порядок по алфавиту учитывал новое название
    self:Invalidate()
    if QTM.RefreshAllViews then QTM.RefreshAllViews() end
end

function Data:ShowRenameDialog(node)
    if not node then return end
    ZO_Dialogs_ShowDialog("MUNDUSGATE_RENAME", { nodeIndex = node.nodeIndex }, {
        mainTextParams  = { node.originalName },
        initialEditText = node.name,
    })
end

-- Сбросить кэш (например, после добавления дома игрока)
function Data:Invalidate()
    self.nodes, self.byIndex, self.zones, self.wayshrineZones = nil, nil, nil, nil
end

---------------------------------------------------------------------------
-- Дома других игроков
---------------------------------------------------------------------------
function Data.CompareKeys(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"   -- сначала места игры, потом дома игроков
end

function Data.IsPlayerKey(key)
    return type(key) == "string"
end

function Data:GetPlayerHouseNames()
    local names = {}
    for displayName in pairs(QTM.sv.playerHouses) do
        names[#names + 1] = displayName
    end
    table.sort(names)
    return names
end

function Data:MakePlayerHouseNode(displayName)
    local node = {
        nodeIndex     = displayName,
        isPlayerHouse = true,
        displayName   = displayName,
        originalName  = zo_strformat(L.PLAYER_HOUSE_NAME, displayName),
        zoneName      = L.PLAYER_HOUSES_ZONE,
        icon          = Data.PLAYER_HOUSE_ICON,
        type          = Data.TYPE_PLAYER_HOUSE,
    }
    self:ApplyCustomName(node)
    return node
end

function Data:HasPlayerHouse(displayName)
    return QTM.sv.playerHouses[displayName] ~= nil
end

-- Добавить дом игрока: он сразу попадает в «Мои места»
function Data:AddPlayerHouse(displayName)
    QTM.sv.playerHouses[displayName] = { addedAt = GetTimeStamp() }
    self:SetFavorite(displayName, true)
    self:Invalidate()
end

-- Забыть дом игрока совсем: из «Моих мест», колеса и кнопок
function Data:RemovePlayerHouse(displayName)
    QTM.sv.playerHouses[displayName] = nil
    self:SetFavorite(displayName, nil)
    for index = 1, (ACTION_BAR_UTILITY_BAR_SIZE or 8) do
        local slot = QTM.sv.wheelSlots[index]
        if slot and slot.nodeIndex == displayName then QTM.sv.wheelSlots[index] = nil end
    end
    for _, item in ipairs(QTM.sv.buttons) do
        if item.nodeIndex == displayName then item.nodeIndex = nil end
    end
    self:Invalidate()
end

-- Перемещение в дом: свой дом или дом другого игрока
function Data:IsHouse(node)
    return node.type == Data.TYPE_HOUSE or node.type == Data.TYPE_PLAYER_HOUSE
end

function Data:EnsureBuilt()
    if not self.nodes or #self.nodes == 0 then
        self:BuildNodes()
    end
end

function Data:GetNodes()
    self:EnsureBuilt()
    return self.nodes
end

function Data:GetNode(nodeIndex)
    if not nodeIndex then return nil end
    self:EnsureBuilt()
    return self.byIndex[nodeIndex]
end

function Data:GetZones()
    self:EnsureBuilt()
    return self.zones
end

---------------------------------------------------------------------------
-- Вид места: значок, цвет и окраска значка.
-- Настраивается один раз (на панели карты или в редакторах кнопок и колеса)
-- и общий для всего: новые кнопки и ячейки колеса берут его сами, а при
-- изменении он сразу переносится на все кнопки и ячейки этого места.
---------------------------------------------------------------------------
local function CopyLook(from, to)
    to.icon  = from.icon
    to.color = QTM.Style.CopyColor(from.color)
    to.tint  = from.tint == true
end

function Data:GetPlaceStyle(key)
    return key ~= nil and QTM.sv.placeStyles[key] or nil
end

-- Вид места для отрисовки (всегда таблица)
function Data:GetPlaceLook(key)
    local style = self:GetPlaceStyle(key)
    return {
        icon  = style and style.icon or nil,
        color = style and style.color or QTM.Style.DEFAULT_COLOR,
        tint  = style and style.tint or false,
    }
end

function Data:SetPlaceStyle(key, look)
    if key == nil then return end
    local sv = QTM.sv
    local style = {}
    CopyLook(look, style)
    sv.placeStyles[key] = style
    for _, item in ipairs(sv.buttons) do
        if item.nodeIndex == key then CopyLook(style, item) end
    end
    for index = 1, (ACTION_BAR_UTILITY_BAR_SIZE or 8) do
        local slot = sv.wheelSlots[index]
        if slot and slot.nodeIndex == key then CopyLook(style, slot) end
    end
    if QTM.Buttons and QTM.Buttons.controls then QTM.Buttons:RefreshAll() end
end

-- Кнопку или ячейку колеса изменили в редакторе — запоминаем вид для места
function Data:SavePlaceStyleFrom(item)
    if item and item.nodeIndex ~= nil then self:SetPlaceStyle(item.nodeIndex, item) end
end

-- Кнопке или ячейке назначили место — берём сохранённый вид места, если он есть
function Data:ApplyPlaceStyle(item)
    local style = item and self:GetPlaceStyle(item.nodeIndex)
    if style then CopyLook(style, item) end
    return item
end

-- Локации, где есть святилища (открытый мир): прыжок к игроку там ставит у святилища
function Data:GetWayshrineZones()
    self:EnsureBuilt()
    if not self.wayshrineZones then
        local zones = {}
        for _, node in ipairs(self.nodes) do
            if node.type == Data.TYPE_WAYSHRINE and node.zoneId then zones[node.zoneId] = true end
        end
        self.wayshrineZones = zones
    end
    return self.wayshrineZones
end

---------------------------------------------------------------------------
-- Избранное (то, что игрок выбрал в настройках)
---------------------------------------------------------------------------
function Data:IsFavorite(nodeIndex)
    return QTM.sv.favorites[nodeIndex] == true
end

function Data:SetFavorite(nodeIndex, isFavorite)
    QTM.sv.favorites[nodeIndex] = isFavorite and true or nil
end

function Data:ClearFavorites()
    ZO_ClearTable(QTM.sv.favorites)
end

function Data:CountFavorites()
    self:EnsureBuilt()
    local count = 0
    for nodeIndex in pairs(QTM.sv.favorites) do
        if self.byIndex[nodeIndex] then count = count + 1 end
    end
    return count
end

function Data:GetFavoriteNodes(sortByName)
    local result = {}
    for _, node in ipairs(self:GetNodes()) do
        if self:IsFavorite(node.nodeIndex) then
            result[#result + 1] = node
        end
    end
    if sortByName then table.sort(result, CompareByName) end
    return result
end

---------------------------------------------------------------------------
-- Доступность, цена, ограничения
---------------------------------------------------------------------------
function Data:GetHouseId(node)
    if node.houseId == nil and GetFastTravelNodeHouseId then
        node.houseId = GetFastTravelNodeHouseId(node.nodeIndex) or 0
    end
    return node.houseId or 0
end

function Data:IsHouseOwned(node)
    local houseId = self:GetHouseId(node)
    if houseId == 0 then return false end
    local collectibleId = GetCollectibleIdForHouse(houseId)
    if not collectibleId or collectibleId == 0 then return false end
    if IsCollectibleOwnedByDefId then
        return IsCollectibleOwnedByDefId(collectibleId)
    end
    return IsCollectibleUnlocked(collectibleId)
end

-- Можно ли в принципе попасть в это место (открыто ли оно).
-- Возвращает: available, reasonText
function Data:GetNodeStatus(node)
    if node.isPlayerHouse then return true end
    local known, _, _, _, icon, _, _, _, linkedCollectibleIsLocked = GetFastTravelNodeInfo(node.nodeIndex)
    if icon and icon ~= "" then node.icon = icon end

    if node.type == Data.TYPE_HOUSE then
        if self:IsHouseOwned(node) then return true end
        return false, L.REASON_NOT_OWNED
    end
    if linkedCollectibleIsLocked then return false, L.REASON_LOCKED end
    if not known then return false, L.REASON_UNDISCOVERED end
    if GetFastTravelNodeOutboundOnlyInfo and GetFastTravelNodeOutboundOnlyInfo(node.nodeIndex) then
        return false, L.REASON_OUTBOUND
    end
    return true
end

-- Цена перемещения к самому месту. Возвращает: text, affordable, isFree
function Data:GetPriceInfo(node)
    if self:IsHouse(node) then
        return L.FREE, true, true
    end
    if QTM.atWayshrine then
        if QTM.wayshrineNodeIndex == node.nodeIndex then
            return L.PRICE_HERE, true, true
        end
        return L.FREE, true, true
    end
    local cost = GetRecallCost(node.nodeIndex) or 0
    if cost <= 0 then
        return L.FREE, true, true
    end
    local currency = (GetRecallCurrency and GetRecallCurrency(node.nodeIndex)) or CURT_MONEY
    local owned = GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER)
    local text = ZO_Currency_FormatKeyboard(currency, cost, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    return text, cost <= owned, false
end

-- Мешает ли что-то переместиться прямо сейчас (бой, смерть, PvP, перезарядка)
function Data:GetBlockReason(isHouse, viaPlayer)
    if IsUnitDead("player") then return L.BLOCK_DEAD end
    if IsUnitInCombat("player") then return L.BLOCK_COMBAT end

    if isHouse then
        if CanJumpToHouseFromCurrentLocation and not CanJumpToHouseFromCurrentLocation() then
            return L.BLOCK_HOUSE_LOCATION
        end
        return nil
    end

    if not QTM.atWayshrine and IsInCampaign() then return L.BLOCK_CAMPAIGN end
    if not CanLeaveCurrentLocationViaTeleport() then return L.BLOCK_LOCATION end

    if not QTM.atWayshrine and not viaPlayer then
        local _, timeLeft = GetRecallCooldown()
        if timeLeft and timeLeft > 0 then
            local timeText = ZO_FormatTimeMilliseconds(timeLeft, TIME_FORMAT_STYLE_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS)
            return zo_strformat(L.BLOCK_COOLDOWN, timeText)
        end
    end
    return nil
end

-- Что мешает переместиться в это место прямо сейчас
-- (для бесплатного пути перезарядка перемещения не важна)
-- source — откуда перемещение: "Menu", "Buttons", "Wheel" или "Map"
function Data:GetNodeBlockReason(node, source)
    if QTM.Route and QTM.Route:WillUse(node, source) then
        return self:GetBlockReason(false, true)
    end
    return self:GetBlockReason(self:IsHouse(node))
end

-- Цена, которую видит игрок: с учётом бесплатного пути через игрока.
-- Возвращает: text, affordable, isFree, isRoute
function Data:GetDisplayPrice(node, source)
    if QTM.Route and QTM.Route:WillUse(node, source) then
        return L.ROUTE_PRICE, true, true, true
    end
    local text, affordable, isFree = self:GetPriceInfo(node)
    return text, affordable, isFree, false
end

-- Строка о цене для подсказок: «Стоимость: 480»
function Data:GetPriceLine(node, source)
    local text, _, _, isRoute = self:GetDisplayPrice(node, source)
    if isRoute then
        return L.PRICE_LABEL .. " |c5DC1E8" .. text .. "|r |c9A9A9A(" .. L.ROUTE_SHORT .. ")|r\n|c9A9A9A"
            .. zo_strformat(L.ROUTE_TOOLTIP_COST, (self:GetPriceInfo(node))) .. "|r"
    end
    return L.PRICE_LABEL .. " " .. text
end

-- Бесплатно к ближайшему к другу или согильдийцу святилищу.
-- savedCost — цена святилища, которую игрок не заплатит (для счётчика; если известна)
function Data:TravelToPlayer(entry, zoneName, savedCost)
    if not entry then return nil end
    local block = self:GetBlockReason(false, true)
    if block then
        Alert(block)
        return nil
    end
    if QTM.sv.confirmTravel then
        ZO_Dialogs_ShowDialog("MUNDUSGATE_CONFIRM_PLAYER", { entry = entry, savedCost = savedCost }, {
            mainTextParams = { entry.displayName, QTM.Presence:DescribeKind(entry), zoneName or entry.zoneName or "" },
        })
        return "dialog"
    end
    self:JumpToPlayer(entry, savedCost)
    return "started"
end

function Data:JumpToPlayer(entry, savedCost)
    QTM.Presence:Jump(entry, {
        onLoading = savedCost and function() QTM.AddSavedGold(savedCost) end or nil,
    })
    QTM.Menu:Hide()
    if not SCENE_MANAGER:IsShowing("hud") then SCENE_MANAGER:ShowBaseScene() end
end

---------------------------------------------------------------------------
-- Перемещение
-- Возвращает: "started" — перемещение началось, "dialog" — ждём подтверждения, nil — отказ
-- payNow — заплатить и переместиться сразу, даже если можно бесплатным путём
-- source — откуда нажали ("Menu", "Buttons", "Wheel"): у каждого своя настройка
---------------------------------------------------------------------------
function Data:Travel(node, payNow, source)
    local available, reason = self:GetNodeStatus(node)
    if not available then
        Alert(reason)
        return nil
    end

    -- Платное место: бесплатно через игрока и святилище
    if not payNow and QTM.Route:WillUse(node, source) then
        return QTM.Route:Request(node)
    end

    local isHouse = self:IsHouse(node)
    local block = self:GetBlockReason(isHouse)
    if block then
        Alert(block)
        return nil
    end

    if node.isPlayerHouse then
        JumpToHouse(node.displayName)
        return "started"
    end

    if isHouse then
        RequestJumpToHouse(self:GetHouseId(node), QTM.sv.houseOutside)
        return "started"
    end

    if QTM.atWayshrine and QTM.wayshrineNodeIndex == node.nodeIndex then
        Alert(L.BLOCK_ALREADY_HERE)
        return nil
    end

    local priceText, affordable = self:GetPriceInfo(node)
    if not affordable then
        Alert(L.BLOCK_NO_GOLD)
        return nil
    end

    if QTM.sv.confirmTravel then
        ZO_Dialogs_ShowDialog("MUNDUSGATE_CONFIRM",
            { nodeIndex = node.nodeIndex },
            { mainTextParams = { node.name, priceText } })
        return "dialog"
    end

    FastTravelToNode(node.nodeIndex)
    return "started"
end
