--[[
    UI.lua
    Модуль пользовательского интерфейса.

    Вкладка «Черный список» в меню группы (GroupMenu:AddTab).
    Прокручиваемый список на ZO_ScrollList.
    Поле ввода @accountName, кнопки добавления/удаления.
]]

local ADDON_NAME = "GroupModerationBlacklist"

-- Локальные ссылки
local ZO_ScrollList_CreateNamedControl = ZO_ScrollList_CreateNamedControl
local ZO_ScrollList_AddDataType = ZO_ScrollList_AddDataType
local ZO_ScrollList_AddData = ZO_ScrollList_AddData
local ZO_ScrollList_Clear = ZO_ScrollList_Clear
local ZO_ScrollList_EnableHighlight = ZO_ScrollList_EnableHighlight
local ZO_ScrollList_Commit = ZO_ScrollList_Commit
local ZO_ScrollList_RefreshVisible = ZO_ScrollList_RefreshVisible
local ZO_ScrollList_SelectData = ZO_ScrollList_SelectData
local ZO_ScrollList_GetData = ZO_ScrollList_GetData
local CreateControlFromVirtual = CreateControlFromVirtual
local GetTimeStamp = GetTimeStamp
local string_lower = string.lower
local string_match = string.match
local pairs = pairs
local table_insert = table.insert
local table_sort = table.sort

-- Модуль UI
UI = UI or {}

-- Внутреннее состояние
local scrollList = nil
local blacklistData = {}
local tabData = nil
local container = nil
local inputControl = nil
local addButton = nil

-- Тип данных для ScrollList
local BLACKLIST_DATA_TYPE = 1

-- Валидация формата @accountName
local function IsValidAccountName(name)
    if not name or name == "" then return false end
    -- Формат: @ + буквы/цифры/дефис/подчёркивание
    return string_match(name, "^@[%w%-_]+$") ~= nil
end

-- Нормализация аккаунта (lowercase)
local function NormalizeAccount(name)
    if not name then return nil end
    return string_lower(name)
end

-- Получение отсортированного списка аккаунтов
local function GetSortedBlacklist()
    local SV = GroupModerationBlacklist.SV
    if not SV or not SV.blacklist then return {} end

    local list = {}
    for account, timestamp in pairs(SV.blacklist) do
        table_insert(list, {
            account = account,
            timestamp = timestamp or 0,
        })
    end

    -- Сортировка по timestamp (новые сверху)
    table_sort(list, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return list
end

-- Callback для setup строки ScrollList
local function SetupEntry(control, data)
    control.data = data

    -- Текст аккаунта
    local label = control:GetNamedChild("Label")
    if label then
        label:SetText(data.account)
    end

    -- Дата добавления
    local dateLabel = control:GetNamedChild("Date")
    if dateLabel and data.timestamp then
        local dateStr = GetDateStringFromTimestamp(data.timestamp)
        dateLabel:SetText(dateStr)
    end

    -- Кнопка удаления
    local deleteButton = control:GetNamedChild("DeleteButton")
    if deleteButton then
        deleteButton:SetHandler("OnClicked", function()
            UI:DeleteFromBlacklist(data.account)
        end)
        deleteButton:SetHandler("OnMouseEnter", function()
            deleteButton:SetAlpha(1)
        end)
        deleteButton:SetHandler("OnMouseExit", function()
            deleteButton:SetAlpha(0.7)
        end)
    end
end

-- Обновление списка
function UI:RefreshBlacklist()
    if not scrollList then return end

    ZO_ScrollList_Clear(scrollList)

    blacklistData = GetSortedBlacklist()
    for _, data in ipairs(blacklistData) do
        ZO_ScrollList_AddData(scrollList, BLACKLIST_DATA_TYPE, data)
    end

    ZO_ScrollList_Commit(scrollList)
end

-- Добавление аккаунта в чёрный список
function UI:AddToBlacklist()
    if not inputControl then return end

    local text = inputControl:GetText()
    if not IsValidAccountName(text) then
        d("[UI] Ошибка: неверный формат аккаунта")
        return
    end

    local account = NormalizeAccount(text)
    local SV = GroupModerationBlacklist.SV
    if not SV then return end

    SV.blacklist[account] = GetTimeStamp()
    inputControl:SetText("")

    d("[UI] Добавлен в чёрный список: " .. account)
    UI:RefreshBlacklist()
end

-- Удаление аккаунта из чёрного списка
function UI:DeleteFromBlacklist(account)
    local SV = GroupModerationBlacklist.SV
    if not SV or not SV.blacklist then return end

    SV.blacklist[account] = nil
    d("[UI] Удалён из чёрного списка: " .. account)
    UI:RefreshBlacklist()
end

-- Создание контролов вкладки
function UI:CreateControls(parent)
    container = parent

    -- Поле ввода
    inputControl = CreateControlFromVirtual("$(parent)Input", container, "ZO_Edit")
    inputControl:SetAnchor(TOPLEFT, container, TOPLEFT, 10, 10)
    inputControl:SetAnchor(TOPRIGHT, container, TOPRIGHT, -10, 10)
    inputControl:SetHeight(30)
    inputControl:SetMaxInputChars(50)
    inputControl:SetHandler("OnEnter", function()
        UI:AddToBlacklist()
    end)

    -- Кнопка добавления
    addButton = CreateControlFromVirtual("$(parent)AddButton", container, "ZO_DefaultButton")
    addButton:SetAnchor(TOPLEFT, inputControl, BOTTOMLEFT, 0, 5)
    addButton:SetAnchor(TOPRIGHT, inputControl, BOTTOMRIGHT, 0, 5)
    addButton:SetHeight(30)
    addButton:SetText("Добавить")
    addButton:SetHandler("OnClicked", function()
        UI:AddToBlacklist()
    end)

    -- ScrollList
    local scrollContainer = CreateControlFromVirtual("$(parent)Scroll", container, "ZO_ScrollContainer")
    scrollContainer:SetAnchor(TOPLEFT, addButton, BOTTOMLEFT, 0, 10)
    scrollContainer:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -10, -10)

    scrollList = ZO_ScrollList_CreateNamedControl(
        scrollContainer,
        "GroupBlacklistScrollList",
        "ZO_BlacklistEntryTemplate",
        40,
        scrollContainer:GetWidth()
    )

    ZO_ScrollList_AddDataType(scrollList, BLACKLIST_DATA_TYPE, "ZO_BlacklistEntryTemplate", 40, SetupEntry)
    ZO_ScrollList_EnableHighlight(scrollList, "ZO_TreeEntryHighlight")

    UI:RefreshBlacklist()
end

-- Инициализация вкладки GroupMenu
function UI:Initialize()
    -- Проверяем доступность GroupMenu API
    if not GroupMenu or not GroupMenu.AddTab then
        d("[GroupModeration] GroupMenu API недоступен")
        return
    end

    GroupMenu:AddTab(ADDON_NAME, {
        buttonText = "Черный список",
        buttonGroup = GROUP_MENU_TAB_GROUP_SECONDARY,

        OnInitialize = function(data)
            tabData = data
        end,

        OnUninitialize = function(data)
            tabData = nil
            container = nil
            scrollList = nil
        end,

        InitializeControls = function(data)
            if not container then
                UI:CreateControls(data:GetNamedChild("ScrollContainer") or data)
            end
        end,

        UpdateControls = function(data)
            UI:RefreshBlacklist()
        end,
    })
end
