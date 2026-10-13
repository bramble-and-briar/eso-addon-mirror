-- Точка входа: настройки по умолчанию, загрузка сохранений, подписка на события игры.
local QTM = MundusGate
local L   = QTM.L

QTM.name    = "MundusGate"
QTM.version = "3.1.0"
QTM.author  = "ladransa"
QTM.contact = "@Watter_Mellon322"   -- кому приходят донаты и отзывы

QTM.defaults = {
    language        = "auto",  -- язык аддона: "auto" (как в игре) или код языка
    favorites       = {},      -- [nodeIndex или "@игрок"] = true
    playerHouses    = {},      -- ["@игрок"] = { addedAt } — дома других игроков
    customNames     = {},      -- [ключ места] = "своё название"
    confirmTravel   = true,
    groupByZone     = true,
    showUnavailable = true,
    houseOutside    = false,
    mapEntry        = true,
    showAtWayshrine = true,    -- открывать меню поверх карты у святилища
    freeViaFriends  = true,    -- бесплатно через друга в нужной локации
    freeViaGuild    = true,    -- бесплатно через согильдийца в нужной локации
    freeViaGroup    = true,    -- на карте: бесплатно у святилища рядом с членом группы
    -- Бесплатный путь в платное место (прыжок к игроку → святилище) — отдельно для каждого способа
    routeMenu       = true,    -- быстрое меню
    routeButtons    = true,    -- кнопки на экране
    routeWheel      = true,    -- колесо быстрого доступа
    routeMap        = true,    -- карта мира
    routeQuest      = true,    -- перемещение к заданию
    placeStyles     = {},      -- [ключ места] = { icon, color, tint } — вид места для кнопок и колеса
    mapPanel        = true,    -- панель Mundus Gate на карте мира
    mapPanelTab     = "gate",  -- открытая вкладка панели: "gate" (Mundus Gate) или "zone" (Завершение области)
    infoPanel       = true,    -- своя панель справа от карты (задания, фильтры, локации, дома, обозначения)
    infoTab         = "quests",-- открытая вкладка правой панели
    zoomBar         = true,    -- свой ползунок масштаба внизу карты
    questTracker    = true,    -- панель заданий Mundus Gate на экране
    hideGameTracker = true,    -- прятать стандартную панель заданий игры, пока включена своя
    trackerLocked   = false,   -- панель заданий нельзя перетаскивать
    questPins       = {},      -- закреплённые пункты: "q:<id задания>", "p:<кампания>:<номер>", "t:<id>"
    questCollapsed  = {},      -- свёрнутые разделы вкладки «Задания»
    questDoneOpen   = {},      -- развёрнутые группы «Выполнено» (стремления, фолиант)
    goldSaved       = 0,       -- сколько золота сэкономлено бесплатными перемещениями через игроков
    freeTrips       = 0,       -- сколько таких перемещений
    window          = {},      -- позиция окна меню
    editorWindow    = {},      -- позиция окна «Мои места»
    editorPositions = {},      -- позиции окон кнопок и колеса

    -- Кнопки на экране
    buttons             = {},  -- { id, nodeIndex, icon, color, tint, size, showLabel, hidden, x, y }
    nextButtonId        = 0,
    buttonsVisible      = true,
    buttonsLocked       = false,
    buttonsHideInCombat = false,
    buttonsTooltips     = true,

    -- Категория «Быстрое перемещение» в колесе быстрого доступа
    wheelSlots                = {},    -- { nodeIndex, icon, color, tint }, до 8 мест
    utilityWheelEnabled       = true,
    utilityWheelStartOnTravel = false,
}

-- Стоит ли игрок прямо сейчас у святилища (тогда перемещение бесплатное)
QTM.atWayshrine        = false
QTM.wayshrineNodeIndex = nil

-- Перерисовать всё, где видны названия мест
function QTM.RefreshAllViews()
    QTM.Menu:RefreshIfShown()
    QTM.Buttons:RefreshAll()
    QTM.Settings:RefreshEditor()
    if QTM.MapPanel and QTM.MapPanel.RefreshIfShown then QTM.MapPanel:RefreshIfShown() end
    if QTM.ButtonsEditor and QTM.ButtonsEditor.editor then QTM.ButtonsEditor.editor:RefreshIfShown() end
    if QTM.WheelEditor and QTM.WheelEditor.RefreshIfShown then QTM.WheelEditor:RefreshIfShown() end
    if QTM.PlacePicker and QTM.PlacePicker.RefreshIfShown then QTM.PlacePicker:RefreshIfShown() end
end

-- Бесплатное перемещение через игрока удалось: прибавляем сэкономленное золото
function QTM.AddSavedGold(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    QTM.sv.goldSaved = (QTM.sv.goldSaved or 0) + amount
    QTM.sv.freeTrips = (QTM.sv.freeTrips or 0) + 1
    if QTM.MapPanel and QTM.MapPanel.UpdateCounter then QTM.MapPanel:UpdateCounter() end
end

function QTM.Toggle()
    QTM.Menu:Toggle()
end

-- Всё, что показывает доступность мест, обновляется вместе
local function RefreshTravelState()
    QTM.Menu:RefreshIfShown()
    QTM.Buttons:RefreshAll()
end

QTM.RefreshTravelState = RefreshTravelState

local function OnFastTravelStart(_, nodeIndex)
    QTM.atWayshrine        = true
    QTM.wayshrineNodeIndex = nodeIndex
    QTM.MapPanel:UpdateVisibility()
    -- Активный бесплатный путь: сразу отправляем в нужное место
    if QTM.Route:OnWayshrine(nodeIndex) then return end
    RefreshTravelState()
    -- Сразу показываем свои места рядом с картой: отсюда перемещение бесплатное
    if QTM.sv.showAtWayshrine then
        QTM.Menu:ShowOverlay()
    end
end

local function OnFastTravelEnd()
    QTM.atWayshrine        = false
    QTM.wayshrineNodeIndex = nil
    QTM.MapPanel:UpdateVisibility()
    QTM.Menu:HideOverlay()
    RefreshTravelState()
end

local function OnNetworkUpdated()
    -- Игрок открыл новое святилище: обновляем подсветку
    RefreshTravelState()
    QTM.Settings:RefreshEditor()
end

local function OnCombatState()
    RefreshTravelState()
    QTM.Buttons:UpdateVisibility()
end

---------------------------------------------------------------------------
-- Сохранения
---------------------------------------------------------------------------
local SV_NAME    = "MundusGate_SavedVariables"
local SV_VERSION = 1

-- До версии 2.8.1 настройки хранились без разделения по серверам (профиль
-- "Default"). При первом входе на сервер копируем их в профиль этого сервера,
-- чтобы ничего не пропало. Старые данные остаются, пока их не перенесут на
-- все серверы, где играет аккаунт, — затем удаляются.
local function MigrateToServerProfile(world)
    local raw = _G[SV_NAME]
    if type(raw) ~= "table" or type(raw.Default) ~= "table" then return end
    local account = GetDisplayName()
    local old = raw.Default[account]
    if type(old) ~= "table" then return end

    raw[world] = raw[world] or {}
    if raw[world][account] == nil then
        local copy = ZO_DeepTableCopy(old)
        copy.migratedTo = nil
        raw[world][account] = copy
    end

    -- Отмечаем сервер; после переноса на EU и NA старая копия больше не нужна
    old.migratedTo = old.migratedTo or {}
    old.migratedTo[world] = true
    if old.migratedTo["EU Megaserver"] and old.migratedTo["NA Megaserver"] then
        raw.Default[account] = nil
        if next(raw.Default) == nil then raw.Default = nil end
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= QTM.name then return end
    EVENT_MANAGER:UnregisterForEvent(QTM.name, EVENT_ADD_ON_LOADED)

    -- Настройки общие для аккаунта, но отдельные для каждого сервера (EU, NA, PTS):
    -- дома игроков, друзья и гильдии на серверах разные.
    local world = GetWorldName()
    MigrateToServerProfile(world)
    QTM.sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, QTM.defaults, world)

    -- Язык: выбранный в настройках или язык игры
    QTM.SetLanguage(QTM.ResolveLanguage(QTM.sv.language))
    QTM.RegisterBindingNames()

    QTM.Data:Initialize()
    QTM.Presence:Initialize()
    QTM.Route:Initialize()
    QTM.Menu:Initialize()
    QTM.Buttons:Initialize()
    QTM.Wheel:Initialize()
    QTM.PlacePicker:Initialize()
    QTM.IconPicker:Initialize()
    QTM.SlotEditor.CreateEditors()
    QTM.WheelEditor:Initialize()
    QTM.Settings:Initialize()
    QTM.MapIntegration:Initialize()
    QTM.MapPanel:Initialize()
    QTM.Quests:Initialize()
    QTM.QuestDrag:Initialize()
    QTM.QuestTravel:Initialize()
    QTM.ZoomBar:Initialize()
    QTM.InfoPanel:Initialize()
    QTM.QuestTracker:Initialize()
    QTM.SocialIntegration:Initialize()

    local em = EVENT_MANAGER
    em:RegisterForEvent(QTM.name, EVENT_START_FAST_TRAVEL_INTERACTION, OnFastTravelStart)
    em:RegisterForEvent(QTM.name, EVENT_END_FAST_TRAVEL_INTERACTION,   OnFastTravelEnd)
    em:RegisterForEvent(QTM.name, EVENT_FAST_TRAVEL_NETWORK_UPDATED,   OnNetworkUpdated)
    em:RegisterForEvent(QTM.name, EVENT_PLAYER_COMBAT_STATE,           OnCombatState)
    em:RegisterForEvent(QTM.name, EVENT_MONEY_UPDATE,                  RefreshTravelState)
    em:RegisterForEvent(QTM.name, EVENT_PLAYER_ACTIVATED,              OnCombatState)

    -- /qtm — меню; /qtm places | buttons | wheel (или по-русски: места | кнопки | колесо)
    SLASH_COMMANDS["/qtm"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "places" or arg == "edit" or arg == "места" then
            QTM.Settings:Show()
        elseif arg == "buttons" or arg == "кнопки" then
            QTM.ButtonsEditor:Show()
        elseif arg == "wheel" or arg == "колесо" then
            QTM.WheelEditor:Show()
        elseif arg == "cancel" or arg == "отмена" or arg == "отменить" then
            if not QTM.Route:Cancel() then d(L.CHAT_NO_ROUTE) end
        elseif arg == "lock" or arg == "закрепить" then
            QTM.Buttons:SetLocked(not QTM.sv.buttonsLocked)
            d(QTM.sv.buttonsLocked and L.CHAT_LOCKED or L.CHAT_UNLOCKED)
        else
            QTM.Toggle()
        end
    end
end

EVENT_MANAGER:RegisterForEvent(QTM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
