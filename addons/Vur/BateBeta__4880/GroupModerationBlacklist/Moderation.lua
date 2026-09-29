--[[
    Moderation.lua
    Модуль фильтрации и исключения участников группы.

    Обрабатывает EVENT_GROUP_MEMBER_JOINED, проверяет аккаунт входящего
    участника по чёрному списку и выполняет безопасное исключение через
    CallSecureFunction для выхода из secure-контекста.

    Принципы:
    - Исключать может только лидер группы (IsUnitGroupLeader("player"))
    - Пропускаем локального игрока (isLocalPlayer)
    - Throttle: не чаще одного исключения в N секунд
    - Все защищённые вызовы через CallSecureFunction
]]

local ADDON_NAME = "GroupModerationBlacklist"

-- Локальные ссылки для производительности
local CallSecureFunction = CallSecureFunction
local IsUnitGroupLeader = IsUnitGroupLeader
local IsProtectedFunction = IsProtectedFunction
local GetTimeStamp = GetTimeStamp
local GetGroupSize = GetGroupSize
local GetGroupMaximumSize = GetGroupMaximumSize
local string_lower = string.lower

-- Модуль Moderation
Moderation = Moderation or {}

-- Внутреннее состояние
local preKickGroupSize = 0
local preKickWasFull = false
local pendingKick = nil

-- Проверка, является ли аккаунт в чёрном списке
local function IsAccountBlacklisted(account)
    local SV = GroupModerationBlacklist.SV
    if not SV or not SV.blacklist then return false end
    return SV.blacklist[account] ~= nil
end

-- Нормализация имени аккаунта
local function NormalizeAccount(displayName)
    if not displayName then return nil end
    local account = string_lower(displayName)
    -- Проверка формата @accountName (буквы, цифры, дефис, подчёркивание)
    if not account:match("^@[%w%-_]+$") then return nil end
    return account
end

-- Безопасное исключение участника
local function SafeKick(memberIndex)
    if not memberIndex or memberIndex <= 0 then return end

    if IsProtectedFunction("GroupKick") then
        -- Вызываем через CallSecureFunction для выхода из secure-контекста
        CallSecureFunction("GroupKick", memberIndex)
    else
        -- Функция не защищена, вызываем напрямую
        GroupKick(memberIndex)
    end
end

-- Обработка события входа участника в группу
local function OnGroupMemberJoined(eventCode, characterName, displayName, isLocalPlayer,
                                   isLeader, memberIndex, isOnline)
    d("[Moderation] GroupMemberJoined: " .. tostring(displayName) .. ", isLocal: " .. tostring(isLocalPlayer))

    -- Пропускаем локального игрока
    if isLocalPlayer then return end

    -- Только лидер может исключать
    if not IsUnitGroupLeader("player") then
        d("[Moderation] Пропуск: игрок не лидер")
        return
    end

    -- Нормализуем аккаунт
    local account = NormalizeAccount(displayName)
    if not account then
        d("[Moderation] Пропуск: неверный формат аккаунта")
        return
    end

    -- Проверяем чёрный список
    if not IsAccountBlacklisted(account) then
        d("[Moderation] Пропуск: аккаунт не в чёрном списке")
        return
    end

    -- Throttle: не чаще одного исключения в N секунд
    local SV = GroupModerationBlacklist.SV
    local currentTime = GetTimeStamp()
    if currentTime - SV.lastKickTime < SV.kickCooldown then
        d("[Moderation] Пропуск: throttle")
        return
    end

    -- Фиксируем размер группы перед киком (для edge case с финальным участником)
    preKickGroupSize = GetGroupSize()
    preKickWasFull = (preKickGroupSize == GetGroupMaximumSize())

    -- Обновляем время последнего кика
    SV.lastKickTime = currentTime

    -- Сохраняем информацию о ожидающем кике
    pendingKick = {
        memberIndex = memberIndex,
        account = account,
        timestamp = currentTime,
    }

    d("[Moderation] Исключение участника: " .. account .. ", memberIndex: " .. tostring(memberIndex))

    -- Выполняем исключение
    SafeKick(memberIndex)
end

-- Обработка события выхода участника из группы
local function OnGroupMemberLeft(eventCode, characterName, displayName, isLocalPlayer,
                                 isLeader, memberIndex, reason)
    -- Проверяем, был ли это наш кик
    if pendingKick and pendingKick.memberIndex == memberIndex then
        -- Кик подтверждён, запускаем перевыставление
        pendingKick = nil

        -- Уведомляем модуль GroupActivity о необходимости перевыставления
        if GroupActivity and GroupActivity.OnKickConfirmed then
            GroupActivity:OnKickConfirmed(preKickGroupSize, preKickWasFull)
        end
    end
end

-- Обработка смены лидера
local function OnLeaderChanged(eventCode, leaderTag)
    -- Сбрасываем ожидающий кик, если лидер сменился
    pendingKick = nil
end

-- Инициализация модуля
function Moderation:Initialize()
    -- Регистрация событий
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_JOINED, OnGroupMemberJoined)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_LEFT, OnGroupMemberLeft)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_LEADER_CHANGED, OnLeaderChanged)
end

-- Получение информации о пред-кик состоянии (для GroupActivity)
function Moderation:GetPreKickInfo()
    return preKickGroupSize, preKickWasFull
end
