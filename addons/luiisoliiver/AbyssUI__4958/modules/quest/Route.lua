-- Бесплатный путь в платное место: прыжок к игроку → одно нажатие E у святилища → сразу на место.
--
-- Почему это работает:
--   • перемещение к другу или согильдийцу в игре бесплатное и ставит вас
--     у святилища рядом с ним;
--   • перемещение от святилища к святилищу тоже бесплатное.
-- Значит, в любое платное место можно попасть бесплатно в два шага. Аддон
-- запоминает цель, переносит вас к игроку, а когда вы активируете святилище (E),
-- сразу отправляет в нужное место — без карты и подтверждений.
--
-- Предосторожности:
--   • цель живёт ROUTE_TIMEOUT_MS (5 минут), потом сбрасывается;
--   • срабатывает один раз — следующая активация святилища уже обычная;
--   • отменить можно крестиком на подсказке или командой /qtm отмена.
--
-- Для каждого способа перемещения (быстрое меню, кнопки, колесо, карта)
-- в настройках своя галочка «через игрока».
local QTM  = AbyssQuest
local L    = QTM.L
local Data = QTM.Data

local Route = {}
QTM.Route = Route

local ROUTE_TIMEOUT_MS = 5 * 60 * 1000
local MAX_ATTEMPTS     = 8      -- ошибки приходят мгновенно, без загрузки — можно пробовать многих
local NEAR_DISTANCE    = 0.03   -- «стоите у святилища» — в долях открытой карты
local TRAVEL_DELAY_MS  = 200    -- дать карте открыться, прежде чем отправлять дальше
local UPDATE_NAME      = "AbyssQuestRouteTick"

Route.active = nil   -- { nodeIndex, name, stage = "jumping" | "loading" | "armed", expiresAt, hint }

---------------------------------------------------------------------------
-- Можно ли сюда бесплатным путём
---------------------------------------------------------------------------
-- Есть ли друг или согильдиец в локации со святилищами (прыжок к нему
-- поставит у святилища; игроки в подземельях, домах, Сиродиле не подходят)
function Route:HasCandidates()
    local Presence = QTM.Presence
    if not Presence:HasAnyone() then return false end
    local zones = Data:GetWayshrineZones()
    for zoneId in pairs(Presence.byZone) do
        if zones[zoneId] then return true end
    end
    return false
end

-- Без учёта настроек: место платное, открыто, и есть к кому переместиться
function Route:CanRoute(node)
    node = Data:Resolve(node)
    if not node or node.isPlayerHouse or Data:IsHouse(node) then return false end
    if QTM.atWayshrine then return false end
    if not Data:GetNodeStatus(node) then return false end
    if (GetRecallCost(node.nodeIndex) or 0) <= 0 then return false end
    return self:HasCandidates()
end

-- Настройка «через игрока» для способа перемещения
Route.SOURCES = { "Menu", "Buttons", "Wheel", "Map", "Quest" }

function Route:IsEnabledFor(source)
    return source ~= nil and QTM.sv["route" .. source] == true
end

-- Будет ли обычное нажатие на место (из этого способа) использовать бесплатный путь
function Route:WillUse(node, source)
    return self:IsEnabledFor(source) and self:CanRoute(node)
end

-- Кого пробовать: сначала тех, кто в локации нужного места (может повезти —
-- окажетесь сразу у него), потом всех остальных (друзья раньше согильдийцев)
function Route:GetCandidates(node)
    local Presence = QTM.Presence
    Presence:EnsureFresh()
    local list, seen = {}, {}
    local function Push(entry)
        if not seen[entry.displayName] then
            seen[entry.displayName] = true
            list[#list + 1] = entry
        end
    end

    local zones = Data:GetWayshrineZones()
    for _, entry in ipairs(Presence.byZone[node.zoneId] or {}) do Push(entry) end

    local others = {}
    for zoneId, entries in pairs(Presence.byZone) do
        if zoneId ~= node.zoneId and zones[zoneId] then
            for _, entry in ipairs(entries) do others[#others + 1] = entry end
        end
    end
    table.sort(others, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.displayName < b.displayName
    end)
    for _, entry in ipairs(others) do Push(entry) end
    return list
end

---------------------------------------------------------------------------
-- Запуск
-- Возвращает: "started", "dialog" или nil (отказ) — как Data:Travel
---------------------------------------------------------------------------
function Route:Request(node)
    node = Data:Resolve(node)
    if not node then return nil end
    local block = Data:GetBlockReason(false, true)
    if block then
        Data.Alert(block)
        return nil
    end
    if not self:HasCandidates() then
        Data.Alert(L.ROUTE_NOBODY)
        return nil
    end
    if QTM.sv.confirmTravel then
        local cost = ZO_Currency_FormatKeyboard(GetRecallCurrency and GetRecallCurrency(node.nodeIndex) or CURT_MONEY,
            GetRecallCost(node.nodeIndex) or 0, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
        ZO_Dialogs_ShowDialog("ABYSSQUEST_CONFIRM_ROUTE", { nodeIndex = node.nodeIndex },
            { mainTextParams = { node.name, cost } })
        return "dialog"
    end
    return self:Start(node)
end

function Route:Start(node)
    local block = Data:GetBlockReason(false, true)
    if block then
        Data.Alert(block)
        return nil
    end
    local candidates = self:GetCandidates(node)
    if #candidates == 0 then
        Data.Alert(L.ROUTE_NOBODY)
        return nil
    end

    self:SetActive({
        nodeIndex = node.nodeIndex,
        name      = node.name,
        stage     = "jumping",
        expiresAt = GetFrameTimeMilliseconds() + ROUTE_TIMEOUT_MS,
        cost      = GetRecallCost(node.nodeIndex) or 0,   -- столько стоило бы обычное перемещение
    })

    local active = self.active
    QTM.Presence:Jump(candidates[1], {
        candidates  = candidates,
        maxAttempts = MAX_ATTEMPTS,
        onLoading   = function()
            if self.active == active then active.stage = "loading" end
        end,
        onFail      = function()
            if self.active == active then
                self:Clear()
                Data.Alert(L.ROUTE_FAILED)
            end
        end,
    })

    -- Карта, меню и прочие окна больше не нужны — закрываем
    QTM.Menu:Hide()
    if not SCENE_MANAGER:IsShowing("hud") then SCENE_MANAGER:ShowBaseScene() end
    return "started"
end

---------------------------------------------------------------------------
-- Состояние
---------------------------------------------------------------------------
function Route:SetActive(active)
    self.active = active
    active.hint = zo_strformat(L.ROUTE_HINT_JUMPING, active.name)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 1000, function() self:OnTick() end)
    self:UpdateHint()
end

function Route:Clear()
    self.active = nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    self:UpdateHint()
    if QTM.RefreshTravelState then QTM.RefreshTravelState() end
end

function Route:IsActive()
    return self.active ~= nil
end

-- Отменить вручную (щелчок по подсказке, /qtm отмена)
function Route:Cancel()
    local active = self.active
    if not active then return false end
    self:Clear()
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ROUTE_CANCELLED, active.name))
    return true
end

function Route:OnTick()
    local active = self.active
    if not active then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        return
    end
    if GetFrameTimeMilliseconds() >= active.expiresAt then
        self:Clear()
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, zo_strformat(L.ROUTE_EXPIRED, active.name))
        return
    end
    self:UpdateHint()
end

---------------------------------------------------------------------------
-- После загрузки: где мы оказались
---------------------------------------------------------------------------
-- Ближайшее к игроку святилище и расстояние до него (в долях карты)
function Route:FindNearestWayshrine()
    local mapShown = ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing()
    if not mapShown and SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    local x, y, _, isShownInCurrentMap = GetMapPlayerPosition("player")
    if not isShownInCurrentMap then return nil end
    return QTM.Presence:NearestWayshrineOnMap(x, y)
end

function Route:OnPlayerActivated()
    local active = self.active
    if not active or active.stage ~= "loading" then return end
    active.stage = "armed"
    -- Положение игрока становится известно не сразу после загрузки
    zo_callLater(function()
        if self.active == active then self:Evaluate() end
    end, 800)
end

function Route:Evaluate()
    local active = self.active
    if not active then return end

    local nearest, distance = self:FindNearestWayshrine()
    local isNear = distance ~= nil and distance <= NEAR_DISTANCE

    -- Повезло: уже у нужного святилища
    if nearest == active.nodeIndex and isNear then
        self:Clear()
        QTM.AddSavedGold(active.cost)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ROUTE_ARRIVED, active.name))
        return
    end

    local nearestNode = nearest and Data:GetNode(nearest)
    if nearestNode then
        local template = isNear and L.ROUTE_HINT_PRESS_E or L.ROUTE_HINT_WALK
        active.hint = zo_strformat(template, nearestNode.name, active.name)
    else
        active.hint = zo_strformat(L.ROUTE_HINT_ANY, active.name)
    end
    self:UpdateHint()
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, active.hint)
end

---------------------------------------------------------------------------
-- Святилище активировано (E)
-- Возвращает true, если аддон сам отправил игрока дальше
---------------------------------------------------------------------------
function Route:OnWayshrine(nodeIndex)
    local active = self.active
    if not active then return false end

    if GetFrameTimeMilliseconds() >= active.expiresAt then
        self:Clear()
        return false
    end

    -- Уже здесь — просто сбрасываем цель
    if nodeIndex == active.nodeIndex then
        self:Clear()
        QTM.AddSavedGold(active.cost)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, zo_strformat(L.ROUTE_ARRIVED, active.name))
        return false
    end

    local target = active.nodeIndex
    self:Clear()   -- один раз: дальше святилища работают как обычно
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, zo_strformat(L.ROUTE_GO, active.name))

    zo_callLater(function()
        if not QTM.atWayshrine then return end   -- игрок успел отойти или закрыть карту
        PlaySound(SOUNDS.MAP_WAYSHRINE_TELEPORT)
        FastTravelToNode(target)
        SCENE_MANAGER:ShowBaseScene()
        QTM.AddSavedGold(active.cost)
    end, TRAVEL_DELAY_MS)
    return true
end

---------------------------------------------------------------------------
-- Подсказка на экране
---------------------------------------------------------------------------
function Route:UpdateHint()
    local box = self.box
    if not box then return end
    local active = self.active
    if not active then
        box:SetHidden(true)
        return
    end
    local leftMs = zo_max(0, active.expiresAt - GetFrameTimeMilliseconds())
    local minutes = zo_max(1, zo_ceil(leftMs / 60000))
    self.text:SetText(active.hint or "")
    self.sub:SetText(zo_strformat(L.ROUTE_HINT_CANCEL, minutes))
    local node = Data:GetNode(active.nodeIndex)
    local look = Data:GetPlaceLook(active.nodeIndex)
    QTM.Style.PaintTile(self.tile, {
        icon = QTM.Style.ResolveIcon(look, node), color = look.color, tint = look.tint,
    }, { size = 44 })
    local textHeight = self.title:GetTextHeight() + self.text:GetTextHeight() + self.sub:GetTextHeight()
    box:SetHeight(zo_max(textHeight + 34, 72))
    box:SetHidden(false)
end

function Route:OnHintClicked(button)
    if button == MOUSE_BUTTON_INDEX_LEFT then
        self:Cancel()
    end
end

---------------------------------------------------------------------------
function Route:Initialize()
    local win = AbyssQuestRouteHint
    self.window = win
    self.box    = win:GetNamedChild("Box")
    self.title  = self.box:GetNamedChild("Title")
    self.text   = self.box:GetNamedChild("Text")
    self.sub    = self.box:GetNamedChild("Sub")
    self.tile   = self.box:GetNamedChild("Tile")
    self.title:SetText(L.ROUTE_HINT_TITLE)
    self.box:SetHidden(true)

    -- Подсказка видна в обычном интерфейсе и в режиме курсора
    self.fragment = ZO_HUDFadeSceneFragment:New(win)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)

    ZO_Dialogs_RegisterCustomDialog("ABYSSQUEST_CONFIRM_ROUTE", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = L.DIALOG_TITLE },
        mainText    = { text = L.DIALOG_ROUTE_TEXT },
        buttons     = {
            {
                text     = L.DIALOG_ROUTE_CONFIRM,
                callback = function(dialog)
                    local node = Data:GetNode(dialog.data.nodeIndex)
                    if node and self:Start(node) == "started" then QTM.Menu:Hide() end
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })

    EVENT_MANAGER:RegisterForEvent(QTM.name .. "Route", EVENT_PLAYER_ACTIVATED,
        function() self:OnPlayerActivated() end)
end
