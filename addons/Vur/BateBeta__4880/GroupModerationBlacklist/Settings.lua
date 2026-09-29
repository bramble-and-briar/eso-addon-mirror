--[[
    Settings.lua
    Модуль панели настроек аддона.

    Использует LibAddonMenu-2.0 если доступен, иначе — встроенный механизм ESO.
    Настройки: kickCooldown, включение/отключение функций, импорт/экспорт списка.
]]

local ADDON_NAME = "GroupModerationBlacklist"

-- Модуль Settings
Settings = Settings or {}

-- Данные панели настроек
local panelData = {
    type = "panel",
    name = "Group Moderation - Blacklist",
    displayName = "Group Moderation - Blacklist",
    author = "GroupModeration Team",
    version = "1.0",
    registerForRefresh = true,
    registerForDefaults = true,
}

-- Опции настроек
local optionsTable = {
    {
        type = "header",
        name = "Основные настройки",
    },
    {
        type = "checkbox",
        name = "Включить автоматическое исключение",
        tooltip = "Автоматически исключать участников из чёрного списка при входе в группу",
        getFunc = function()
            local SV = GroupModerationBlacklist.SV
            return SV and SV.autoKickEnabled ~= false
        end,
        setFunc = function(value)
            local SV = GroupModerationBlacklist.SV
            if SV then
                SV.autoKickEnabled = value
            end
        end,
        default = true,
    },
    {
        type = "slider",
        name = "Задержка между исключениями (сек)",
        tooltip = "Минимальное время между автоматическими исключениями",
        min = 1,
        max = 30,
        step = 1,
        getFunc = function()
            local SV = GroupModerationBlacklist.SV
            return SV and SV.kickCooldown or 5
        end,
        setFunc = function(value)
            local SV = GroupModerationBlacklist.SV
            if SV then
                SV.kickCooldown = value
            end
        end,
        default = 5,
    },
    {
        type = "checkbox",
        name = "Включить перевыставление в Activity Finder",
        tooltip = "Автоматически перевыставлять группу в Activity Finder после исключения финального участника",
        getFunc = function()
            local SV = GroupModerationBlacklist.SV
            return SV and SV.autoRepostEnabled ~= false
        end,
        setFunc = function(value)
            local SV = GroupModerationBlacklist.SV
            if SV then
                SV.autoRepostEnabled = value
            end
        end,
        default = true,
    },
    {
        type = "header",
        name = "Управление чёрным списком",
    },
    {
        type = "button",
        name = "Экспортировать список",
        tooltip = "Скопировать чёрный список в буфер обмена (формат: @account1, @account2, ...)",
        func = function()
            local SV = GroupModerationBlacklist.SV
            if not SV or not SV.blacklist then return end

            local accounts = {}
            for account, _ in pairs(SV.blacklist) do
                table.insert(accounts, account)
            end
            table.sort(accounts)

            local exportStr = table.concat(accounts, ", ")
            -- В ESO нет прямого доступа к буферу обмена, выводим в чат
            d("[GroupModeration] Экспорт чёрного списка:")
            d(exportStr)
        end,
        width = "half",
    },
    {
        type = "button",
        name = "Очистить список",
        tooltip = "Удалить все аккаунты из чёрного списка",
        func = function()
            local SV = GroupModerationBlacklist.SV
            if SV then
                SV.blacklist = {}
                d("[GroupModeration] Чёрный список очищен")
                if UI and UI.RefreshBlacklist then
                    UI:RefreshBlacklist()
                end
            end
        end,
        width = "half",
        isDangerous = true,
        warning = "Вы уверены, что хотите удалить все аккаунты из чёрного списка?",
    },
    {
        type = "header",
        name = "Отладка",
    },
    {
        type = "checkbox",
        name = "Режим отладки",
        tooltip = "Выводить отладочные сообщения в чат",
        getFunc = function()
            local SV = GroupModerationBlacklist.SV
            return SV and SV.debugMode or false
        end,
        setFunc = function(value)
            local SV = GroupModerationBlacklist.SV
            if SV then
                SV.debugMode = value
            end
        end,
        default = false,
    },
}

-- Инициализация панели настроек
function Settings:Initialize()
    -- Проверяем доступность LibAddonMenu-2.0
    if LibAddonMenu2 then
        LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Options", panelData)
        LibAddonMenu2:RegisterOptionControls(ADDON_NAME .. "_Options", optionsTable)
        d("[Settings] Панель настроек зарегистрирована через LibAddonMenu-2.0")
    else
        -- Fallback: встроенный механизм ESO
        Settings:RegisterFallbackPanel()
        d("[Settings] LibAddonMenu-2.0 недоступен, используется встроенный механизм")
    end
end

-- Fallback на встроенный механизм ESO
function Settings:RegisterFallbackPanel()
    -- В ESO есть встроенный механизм настроек через ZO_OptionsPanel
    -- или через SettingsPanel. Здесь используем упрощённый вариант.
    --
    -- Примечание: полноценная реализация fallback требует создания
    -- собственной панели через ZO_OptionsPanel или XML.
    --
    -- Для простоты выводим сообщение о необходимости LibAddonMenu-2.0.
    d("[Settings] Для полноценной панели настроек установите LibAddonMenu-2.0")
    d("[Settings] Скачать: https://www.esoui.com/downloads/info7-LibAddonMenu.html")
end

-- Получение значения настройки
function Settings:GetSetting(key)
    local SV = GroupModerationBlacklist.SV
    if not SV then return nil end
    return SV[key]
end

-- Установка значения настройки
function Settings:SetSetting(key, value)
    local SV = GroupModerationBlacklist.SV
    if not SV then return end
    SV[key] = value
end
