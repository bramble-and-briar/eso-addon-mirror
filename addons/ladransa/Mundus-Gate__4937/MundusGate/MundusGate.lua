-- Точка входа: настройки по умолчанию, загрузка сохранений, подписка на события игры.
local QTM = MundusGate
local L   = QTM.L

QTM.name    = "MundusGate"
QTM.version = "2.5.0"
QTM.author  = "ladransa"
QTM.contact = "@Watter_Mellon322"   -- кому приходят донаты и отзывы

QTM.defaults = {
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
    freeViaGroup    = true,    -- на карте: бесплатно у святилища рядом с членом группы    -- пункт «Добавить в Mundus Gate» на карте
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
    if QTM.ButtonsEditor and QTM.ButtonsEditor.editor then QTM.ButtonsEditor.editor:RefreshIfShown() end
    if QTM.WheelEditor and QTM.WheelEditor.RefreshIfShown then QTM.WheelEditor:RefreshIfShown() end
    if QTM.PlacePicker and QTM.PlacePicker.RefreshIfShown then QTM.PlacePicker:RefreshIfShown() end
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
    RefreshTravelState()
    -- Сразу показываем свои места рядом с картой: отсюда перемещение бесплатное
    if QTM.sv.showAtWayshrine then
        QTM.Menu:ShowOverlay()
    end
end

local function OnFastTravelEnd()
    QTM.atWayshrine        = false
    QTM.wayshrineNodeIndex = nil
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

local function OnAddOnLoaded(_, addonName)
    if addonName ~= QTM.name then return end
    EVENT_MANAGER:UnregisterForEvent(QTM.name, EVENT_ADD_ON_LOADED)

    -- Перенос настроек со старого названия аддона (Quick Travel Menu).
    -- Старые данные видны, только если файл SavedVariables\QuickTravelMenu.lua
    -- переименован в MundusGate.lua (см. README).
    if MundusGate_SavedVariables == nil and QuickTravelMenu_SavedVariables ~= nil then
        MundusGate_SavedVariables = QuickTravelMenu_SavedVariables
    end
    QuickTravelMenu_SavedVariables = nil

    QTM.sv = ZO_SavedVars:NewAccountWide("MundusGate_SavedVariables", 1, nil, QTM.defaults)

    QTM.Data:Initialize()
    QTM.Presence:Initialize()
    QTM.Menu:Initialize()
    QTM.Buttons:Initialize()
    QTM.Wheel:Initialize()
    QTM.PlacePicker:Initialize()
    QTM.IconPicker:Initialize()
    QTM.SlotEditor.CreateEditors()
    QTM.WheelEditor:Initialize()
    QTM.Settings:Initialize()
    QTM.MapIntegration:Initialize()
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
        elseif arg == "lock" or arg == "закрепить" then
            QTM.Buttons:SetLocked(not QTM.sv.buttonsLocked)
            d(QTM.sv.buttonsLocked and L.CHAT_LOCKED or L.CHAT_UNLOCKED)
        else
            QTM.Toggle()
        end
    end
end

EVENT_MANAGER:RegisterForEvent(QTM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
