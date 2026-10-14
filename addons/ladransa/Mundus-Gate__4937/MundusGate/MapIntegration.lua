-- Пункт «Добавить в Mundus Gate» на карте мира.
--
-- Когда игрок щёлкает по точке на карте, игра берёт список обработчиков
-- из ZO_MapPin.PIN_CLICK_HANDLERS[кнопка мыши][тип точки]. Для одной точки
-- используется ПЕРВЫЙ подходящий обработчик. Если у обработчика есть функция
-- GetDynamicHandlers, он может вернуть сразу несколько действий, и тогда
-- игра показывает меню выбора — так уже работают дома («Внутрь» / «Снаружи»).
--
-- Мы ставим в начало списка свой обработчик-«обёртку». Он находит обычное
-- действие игры (переместиться к святилищу, в дом и т.д.) и возвращает его
-- вместе с нашими пунктами:
--   • «Бесплатно: к @игрок (группа)» — только на том святилище, которое ближе
--     всего к члену вашей группы (игра переносит именно к ближайшему святилищу);
--   • «Бесплатно: через игрока и E у святилища» — на остальных платных местах;
--   • «Добавить в Mundus Gate».
--
-- Подсказка святилища на карте: на таком святилище вместо стоимости
-- пишется «Бесплатно — рядом член группы @игрок».
--
-- Друзей и согильдийцев вне группы на карте не учитываем: игра сообщает
-- аддонам только их локацию, а не точку, и нельзя понять, у какого они святилища.
local QTM  = MundusGate
local L    = QTM.L
local Data = QTM.Data

local MapIntegration = {}
QTM.MapIntegration = MapIntegration

local function GetNode(pin)
    local nodeIndex = pin.GetFastTravelNodeIndex and pin:GetFastTravelNodeIndex()
    if not nodeIndex then return nil end
    Data:EnsureBuilt()
    return Data.byIndex[nodeIndex]
end

---------------------------------------------------------------------------
-- Бесплатно через друга или согильдийца
---------------------------------------------------------------------------
-- Можно ли сейчас бесплатно попасть в локацию этого святилища через игрока.
-- Только для обычного платного перемещения (не у святилища, не в PvP, не дом).
local function FreeEntryForPin(pin)
    if not pin or not pin.GetFastTravelNodeIndex then return nil end
    if ZO_Map_GetFastTravelNode and ZO_Map_GetFastTravelNode() ~= nil then return nil end
    local nodeIndex = pin:GetFastTravelNodeIndex()
    if not nodeIndex then return nil end
    if GetFastTravelNodeHouseId(nodeIndex) ~= 0 then return nil end
    if pin.IsLockedByLinkedCollectible and pin:IsLockedByLinkedCollectible() then return nil end
    if IsInCampaign() or IsUnitDead("player") or not CanLeaveCurrentLocationViaTeleport() then return nil end
    if GetFastTravelNodeOutboundOnlyInfo(nodeIndex) then return nil end
    local known = GetFastTravelNodeInfo(nodeIndex)
    if not known then return nil end
    local node = GetNode(pin)
    if not node then return nil end
    local entry = QTM.Presence:FindGroupMemberNearNode(nodeIndex)
    if not entry then return nil end
    return entry, node
end
MapIntegration.FreeEntryForPin = FreeEntryForPin

local freeHandler = {
    name = function(pin)
        local entry = FreeEntryForPin(pin)
        if not entry then return "" end
        return zo_strformat(L.MAP_FREE_TRAVEL, entry.displayName, QTM.Presence:DescribeKind(entry))
    end,
    show = function(pin)
        return FreeEntryForPin(pin) ~= nil
    end,
    callback = function(pin)
        local entry, node = FreeEntryForPin(pin)
        if entry then Data:TravelToPlayer(entry, node.zoneName, GetRecallCost(node.nodeIndex)) end
    end,
    duplicates = function(pin1, pin2)
        return pin1:GetFastTravelNodeIndex() == pin2:GetFastTravelNodeIndex()
    end,
}

-- Бесплатный путь: прыжок к любому другу или согильдийцу, затем E у святилища
local function RouteNodeForPin(pin)
    if not pin or not pin.GetFastTravelNodeIndex then return nil end
    if ZO_Map_GetFastTravelNode and ZO_Map_GetFastTravelNode() ~= nil then return nil end
    if FreeEntryForPin(pin) then return nil end   -- рядом член группы — это быстрее
    local node = GetNode(pin)
    if node and QTM.Route:CanRoute(node) then return node end
    return nil
end

-- Включена галочка «через игрока» для карты и Shift не зажат: щелчок по
-- платному святилищу сразу запускает бесплатный путь (одно действие —
-- игра выполняет его без меню). Shift + щелчок — все действия как обычно.
local function IsDirectRoute(pin)
    if not QTM.Route:IsEnabledFor("Map") then return false end
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    return RouteNodeForPin(pin) ~= nil
end
MapIntegration.IsDirectRoute = IsDirectRoute

local routeHandler = {
    name = function() return L.MAP_ROUTE_FREE end,
    show = function(pin) return RouteNodeForPin(pin) ~= nil end,
    callback = function(pin)
        local node = RouteNodeForPin(pin)
        if node then QTM.Route:Request(node) end
    end,
    duplicates = function(pin1, pin2)
        return pin1:GetFastTravelNodeIndex() == pin2:GetFastTravelNodeIndex()
    end,
}

-- Строки в подсказке святилища вместо стоимости
local function AddFreeLines(tooltip, entry, node)
    local r, g, b = ZO_SUCCEEDED_TEXT:UnpackRGB()
    tooltip:AddLine(zo_strformat(L.MAP_TOOLTIP_FREE, entry.displayName, QTM.Presence:DescribeKind(entry)), "", r, g, b)
    r, g, b = ZO_DISABLED_TEXT:UnpackRGB()
    tooltip:AddLine(zo_strformat(L.MAP_TOOLTIP_SHRINE_COST, Data:GetPriceInfo(node)), "", r, g, b)
end

local function AddRouteLines(tooltip, node)
    tooltip:AddLine(L.MAP_TOOLTIP_ROUTE, "", 0.36, 0.76, 0.91)
    local r, g, b = ZO_DISABLED_TEXT:UnpackRGB()
    tooltip:AddLine(zo_strformat(L.MAP_TOOLTIP_ROUTE_COST, Data:GetPriceInfo(node)), "", r, g, b)
end

-- Что писать вместо стоимости: бесплатно через члена группы, бесплатный путь или ничего
local function CostReplacement(pin)
    local entry, node = FreeEntryForPin(pin)
    if entry then
        return function(tooltip) AddFreeLines(tooltip, entry, node) end
    end
    if QTM.Route:IsEnabledFor("Map") then
        local routeNode = RouteNodeForPin(pin)
        if routeNode then
            return function(tooltip) AddRouteLines(tooltip, routeNode) end
        end
    end
    return nil
end

function MapIntegration:InstallTooltip()
    local tooltip = InformationTooltip
    if not tooltip or type(tooltip.AppendWayshrineTooltip) ~= "function" or tooltip.qtmWrapped then return end
    tooltip.qtmWrapped = true

    local original = tooltip.AppendWayshrineTooltip
    tooltip.AppendWayshrineTooltip = function(self, pin)
        local addLines = not IsInGamepadPreferredMode() and QTM.TipsEnabled("mapPins") and CostReplacement(pin)
        if not addLines then
            return original(self, pin)
        end

        -- Игра добавляет стоимость функцией AddMoney — на время подменяем её своими строками
        local replaced = false
        local originalAddMoney = self.AddMoney
        self.AddMoney = function(_, target)
            replaced = true
            addLines(target or self)
        end
        local ok, err = pcall(original, self, pin)
        self.AddMoney = originalAddMoney
        if not ok then error(err, 0) end

        -- Стоимости не было (например, идёт перезарядка) — всё равно пишем, что можно бесплатно
        if not replaced then addLines(self) end
    end
end

-- Наш пункт меню: добавить или убрать место
local toggleHandler = {
    name = function(pin)
        local node = GetNode(pin)
        if not node then return "" end
        if Data:IsFavorite(node.nodeIndex) then
            return zo_strformat(L.MAP_REMOVE, node.name)
        end
        return zo_strformat(L.MAP_ADD, node.name)
    end,
    show = function(pin)
        return QTM.sv.mapEntry and GetNode(pin) ~= nil
    end,
    callback = function(pin)
        local node = GetNode(pin)
        if not node then return end
        local add = not Data:IsFavorite(node.nodeIndex)
        Data:SetFavorite(node.nodeIndex, add)
        local text = zo_strformat(add and L.MAP_ADDED or L.MAP_REMOVED, node.name)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, text)
        QTM.Menu:RefreshIfShown()
        QTM.Settings:RefreshEditor()
        QTM.MapPanel:RefreshIfShown()
    end,
    -- Если под курсором несколько точек, не показывать одинаковые пункты дважды
    duplicates = function(pin1, pin2)
        return pin1:GetFastTravelNodeIndex() == pin2:GetFastTravelNodeIndex()
    end,
}

local function Install(handlers)
    if not handlers or handlers.qtmInstalled then return end
    handlers.qtmInstalled = true

    -- Первый подходящий обычный обработчик игры (пропуская наш, он стоит первым)
    local function FindOriginal(pin)
        for i = 2, #handlers do
            local handler = handlers[i]
            if handler.show == nil or handler.show(pin) then
                return handler
            end
        end
        return nil
    end

    local wrapper = {
        show = function(pin)
            return toggleHandler.show(pin) or freeHandler.show(pin) or routeHandler.show(pin)
        end,
        GetDynamicHandlers = function(pin)
            if IsDirectRoute(pin) then return { routeHandler } end
            local result = {}
            if freeHandler.show(pin) then
                result[#result + 1] = freeHandler
            elseif routeHandler.show(pin) then
                result[#result + 1] = routeHandler
            end
            local original = FindOriginal(pin)
            if original then
                if original.GetDynamicHandlers then
                    for _, h in ipairs(original.GetDynamicHandlers(pin)) do
                        result[#result + 1] = h
                    end
                else
                    result[#result + 1] = original
                end
            end
            if toggleHandler.show(pin) then
                result[#result + 1] = toggleHandler
            end
            return result
        end,
    }

    table.insert(handlers, 1, wrapper)
end

function MapIntegration:Initialize()
    -- На геймпаде подпись кнопки получает список точек, а не одну точку
    freeHandler.gamepadName   = L.MAP_GAMEPAD
    routeHandler.gamepadName  = L.MAP_GAMEPAD
    toggleHandler.gamepadName = L.MAP_GAMEPAD

    -- Подсказку карты ставим сейчас и ещё раз после входа в мир (на случай,
    -- если карта игры к этому моменту ещё не создана)
    self:InstallTooltip()
    EVENT_MANAGER:RegisterForEvent(QTM.name .. "MapTooltip", EVENT_PLAYER_ACTIVATED, function()
        self:InstallTooltip()
    end)

    if not (ZO_MapPin and ZO_MapPin.PIN_CLICK_HANDLERS) then return end
    local leftHandlers = ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_LEFT]
    if not leftHandlers then return end

    -- Святилища, подземелья, испытания и дома на карте — это точки быстрого перемещения
    Install(leftHandlers[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE])

    -- У святилища, рядом с которым стоит игрок, своих действий нет — создаём список
    if MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC then
        leftHandlers[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC] =
            leftHandlers[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC] or {}
        Install(leftHandlers[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC])
    end
end
