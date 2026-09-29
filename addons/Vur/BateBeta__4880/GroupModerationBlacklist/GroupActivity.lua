--[[
    GroupActivity.lua
    Модуль управления состоянием группы и перевыставлением в Activity Finder.

    Сохраняет параметры группы (название, описание, роли, сложность) в
    SavedVariables. После исключения участника автоматически перевыставляет
    группу в Activity Finder с идентичными параметрами.

    Защита:
    - Флаг isReposting против двойного срабатывания
    - Проверка IsUnitGroupLeader перед перевыставлением
    - Отмена при смене лидера или распуске группы
    - Проверка состояния Activity Finder
]]

local ADDON_NAME = "GroupModerationBlacklist"

-- Локальные ссылки
local CallSecureFunction = CallSecureFunction
local IsUnitGroupLeader = IsUnitGroupLeader
local IsProtectedFunction = IsProtectedFunction
local GetTimeStamp = GetTimeStamp
local zo_callLater = zo_callLater

-- Модуль GroupActivity
GroupActivity = GroupActivity or {}

-- Внутреннее состояние
local repostPending = false
local repostTimer = nil

-- Получение текущих параметров группы
local function CaptureGroupSnapshot()
    local SV = GroupModerationBlacklist.SV
    if not SV then return nil end

    -- Снимок параметров группы
    -- Точные функции зависят от версии API, поэтому используем проверки
    local snapshot = {
        name = nil,
        description = nil,
        roles = nil,
        difficulty = nil,
    }

    -- Пытаемся получить параметры через различные API
    if GetGroupActivityName then
        snapshot.name = GetGroupActivityName()
    end
    if GetGroupActivityDescription then
        snapshot.description = GetGroupActivityDescription()
    end
    if GetGroupActivityRoles then
        snapshot.roles = GetGroupActivityRoles()
    end
    if GetGroupActivityDifficulty then
        snapshot.difficulty = GetGroupActivityDifficulty()
    end

    -- Альтернативный вариант через Activity Finder
    if not snapshot.name and GetActivityFinderStatus then
        local status = GetActivityFinderStatus()
        if status then
            snapshot.name = status.name
            snapshot.description = status.description
        end
    end

    return snapshot
end

-- Сохранение снимка в SavedVariables
local function SaveSnapshot(snapshot)
    local SV = GroupModerationBlacklist.SV
    if not SV then return end
    SV.groupActivitySnapshot = snapshot
end

-- Проверка, находится ли группа в Activity Finder
local function IsGroupInActivityFinder()
    -- Проверяем состояние Activity Finder
    if IsGroupActivityFinderOpen then
        return IsGroupActivityFinderOpen()
    end
    -- Fallback: проверяем по размеру группы
    return GetGroupSize() > 0
end

-- Перевыставление группы в Activity Finder
local function RepostGroup()
    local SV = GroupModerationBlacklist.SV
    if not SV then return end

    -- Проверка лидерства
    if not IsUnitGroupLeader("player") then
        repostPending = false
        return
    end

    -- Защита от двойного срабатывания
    if SV.isReposting then
        return
    end

    -- Проверяем, есть ли снимок
    local snapshot = SV.groupActivitySnapshot
    if not snapshot or not snapshot.name then
        return
    end

    -- Устанавливаем флаг
    SV.isReposting = true

    -- Вызываем перевыставление через CallSecureFunction
    if IsProtectedFunction("GroupActivitySetData") then
        CallSecureFunction("GroupActivitySetData",
            snapshot.name,
            snapshot.description,
            snapshot.roles,
            snapshot.difficulty
        )
    else
        -- Fallback для незащищённой функции
        GroupActivitySetData(snapshot.name, snapshot.description,
                            snapshot.roles, snapshot.difficulty)
    end

    -- Сбрасываем флаг через задержку
    zo_callLater(function()
        SV.isReposting = false
    end, 1000) -- 1 секунда
end

-- Обработка подтверждения кика от Moderation
function GroupActivity:OnKickConfirmed(preKickGroupSize, preKickWasFull)
    d("[GroupActivity] KickConfirmed: preKickSize=" .. tostring(preKickGroupSize) .. ", wasFull=" .. tostring(preKickWasFull))

    -- Проверяем, нужно ли перевыставление
    -- Перевыставляем только если группа была полной (финальный участник)
    if not preKickWasFull then
        d("[GroupActivity] Пропуск: группа не была полной")
        return
    end

    -- Проверяем, что мы всё ещё лидер
    if not IsUnitGroupLeader("player") then
        d("[GroupActivity] Пропуск: игрок не лидер")
        return
    end

    -- Проверяем, находится ли группа в Activity Finder
    if not IsGroupInActivityFinder() then
        d("[GroupActivity] Пропуск: группа не в Activity Finder")
        return
    end

    -- Запускаем перевыставление с небольшой задержкой
    -- чтобы событие GROUP_MEMBER_LEFT полностью обработалось
    repostPending = true
    zo_callLater(function()
        if repostPending then
            repostPending = false
            RepostGroup()
        end
    end, 500) -- 500 мс
end

-- Обработка события обновления группы
local function OnGroupUpdate(eventCode)
    -- Обновляем снимок параметров группы
    if IsUnitGroupLeader("player") then
        local snapshot = CaptureGroupSnapshot()
        if snapshot then
            SaveSnapshot(snapshot)
        end
    end
end

-- Обработка смены лидера
local function OnLeaderChanged(eventCode, leaderTag)
    -- Отменяем ожидающее перевыставление
    repostPending = false
    local SV = GroupModerationBlacklist.SV
    if SV then
        SV.isReposting = false
    end
end

-- Обработка распуска группы
local function OnGroupDisbanded(eventCode)
    repostPending = false
    local SV = GroupModerationBlacklist.SV
    if SV then
        SV.isReposting = false
    end
end

-- Инициализация модуля
function GroupActivity:Initialize()
    -- Регистрация событий
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_UPDATE, OnGroupUpdate)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_LEADER_CHANGED, OnLeaderChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_DISBANDED, OnGroupDisbanded)
end
