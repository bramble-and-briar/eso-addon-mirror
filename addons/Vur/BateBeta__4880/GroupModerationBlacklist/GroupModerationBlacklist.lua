--[[
    GroupModerationBlacklist.lua
    Точка входа аддона. Инициализация, загрузка SavedVariables,
    регистрация базовых событий.
]]

local ADDON_NAME = "GroupModerationBlacklist"

-- Глобальное состояние аддона
GroupModerationBlacklist = GroupModerationBlacklist or {}
GroupModerationBlacklist.SV = nil
GroupModerationBlacklist.initialized = false

-- Настройки по умолчанию
local function GetDefaultSettings()
    return {
        version = 1,
        -- Черный список: @accountName -> timestamp добавления
        blacklist = {},
        -- Снимок параметров группы для перевыставления
        groupActivitySnapshot = {
            name = nil,
            description = nil,
            roles = nil,
            difficulty = nil,
        },
        lastKickTime = 0,
        isReposting = false,
        kickCooldown = 5, -- секунд между исключениями
    }
end

-- Инициализация аддона
local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then return end

    -- Загрузка SavedVariables
    GroupModerationBlacklist.SV = ZO_SavedVars:NewAccountWide(
        "GroupModerationBlacklistSV",
        1,
        nil,
        GetDefaultSettings()
    )

    GroupModerationBlacklist.initialized = true

    -- Инициализация модулей
    Moderation:Initialize()
    GroupActivity:Initialize()
    UI:Initialize()
    Settings:Initialize()

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

-- Регистрация события загрузки
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
