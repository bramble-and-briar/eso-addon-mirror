-- Бесплатное перемещение через друзей и согильдийцев.
--
-- Перемещение к другу или члену гильдии в игре бесплатное: игра переносит
-- к ближайшему к этому игроку святилищу. Аддоны знают только ЛОКАЦИЮ друзей
-- и согильдийцев (не координаты), поэтому заранее нельзя сказать, у какого
-- именно святилища окажешься. Аддон честно показывает это отдельным
-- пунктом «Святилище рядом с @игрок — Бесплатно», а у мест — их цену.
--
-- Список «кто в какой локации» собирается из списка друзей и всех гильдий
-- и кэшируется: пересобирается, когда кто-то сменил локацию, вошёл или вышел
-- из игры, но не чаще, чем раз в несколько секунд.
local QTM  = MundusGate
local L    = QTM.L

local Presence = {}
QTM.Presence = Presence

Presence.KIND_FRIEND = 1
Presence.KIND_GUILD  = 2
Presence.KIND_GROUP  = 3

local MIN_REBUILD_MS = 3000

Presence.dirty     = true
Presence.lastBuild = nil
Presence.byZone    = {}

local function IsOnline(status)
    return status ~= nil and status ~= PLAYER_STATUS_OFFLINE
end

---------------------------------------------------------------------------
-- Сбор списка
---------------------------------------------------------------------------
-- Добавить игрока в список локации; друзья идут раньше согильдийцев
-- Можно ли вообще прыгнуть к игроку в этой локации (не закрытое DLC, не
-- одиночная арена и т.п.). Ответ игры кэшируется на время одной сборки.
local function CanJumpInto(zoneId, cache)
    if cache[zoneId] == nil then
        cache[zoneId] = not CanJumpToPlayerInZone or CanJumpToPlayerInZone(zoneId) == true
    end
    return cache[zoneId]
end

local function Add(byZone, seen, zoneId, entry, jumpCache)
    if not zoneId or zoneId == 0 or seen[entry.displayName] then return end
    if not CanJumpInto(zoneId, jumpCache) then return end
    seen[entry.displayName] = true
    entry.zoneId = zoneId
    local list = byZone[zoneId]
    if not list then
        list = {}
        byZone[zoneId] = list
    end
    list[#list + 1] = entry
end

function Presence:Rebuild()
    local byZone, seen, jumpCache = {}, {}, {}
    local me = GetDisplayName()
    seen[me] = true
    local sv = QTM.sv

    if sv.freeViaFriends then
        for friendIndex = 1, GetNumFriends() do
            local displayName, _, status = GetFriendInfo(friendIndex)
            if IsOnline(status) then
                local hasCharacter, characterName, zoneName, _, _, _, _, zoneId = GetFriendCharacterInfo(friendIndex)
                if hasCharacter then
                    Add(byZone, seen, zoneId, {
                        displayName = displayName,
                        characterName = characterName,
                        zoneName = zoneName,
                        kind = Presence.KIND_FRIEND,
                    }, jumpCache)
                end
            end
        end
    end

    if sv.freeViaGuild then
        for guildIndex = 1, GetNumGuilds() do
            local guildId = GetGuildId(guildIndex)
            local guildName = GetGuildName(guildId)
            for memberIndex = 1, GetNumGuildMembers(guildId) do
                local displayName, _, _, status = GetGuildMemberInfo(guildId, memberIndex)
                if IsOnline(status) and not seen[displayName] then
                    local hasCharacter, characterName, zoneName, _, _, _, _, zoneId = GetGuildMemberCharacterInfo(guildId, memberIndex)
                    if hasCharacter then
                        Add(byZone, seen, zoneId, {
                            displayName = displayName,
                            characterName = characterName,
                            zoneName = zoneName,
                            kind = Presence.KIND_GUILD,
                            guildName = guildName,
                        }, jumpCache)
                    end
                end
            end
        end
    end

    self.byZone    = byZone
    self.dirty     = false
    self.lastBuild = GetFrameTimeMilliseconds()
end

function Presence:EnsureFresh()
    local now = GetFrameTimeMilliseconds()
    if self.lastBuild == nil or (self.dirty and now - self.lastBuild >= MIN_REBUILD_MS) then
        self:Rebuild()
    end
end

function Presence:MarkDirty()
    self.dirty = true
end

---------------------------------------------------------------------------
-- Поиск игрока для места
---------------------------------------------------------------------------
function Presence:IsEnabled()
    local sv = QTM.sv
    return sv.freeViaFriends or sv.freeViaGuild
end

-- Первый друг или согильдиец в этой локации (или nil)
function Presence:FindForZone(zoneId)
    if not zoneId or zoneId == 0 or not self:IsEnabled() then return nil end
    self:EnsureFresh()
    local list = self.byZone[zoneId]
    return list and list[1] or nil
end

-- Друг или согильдиец в локации этого места (только места игры в открытом мире)
function Presence:FindFor(node)
    if not node then return nil end
    if node.isPlayerHouse or node.type == QTM.Data.TYPE_HOUSE then return nil end
    return self:FindForZone(node.zoneId)
end

-- Как назвать, кто это: «друг» или «гильдия «…»»
function Presence:DescribeKind(entry)
    if entry.kind == Presence.KIND_FRIEND then
        return L.KIND_FRIEND
    elseif entry.kind == Presence.KIND_GROUP then
        return L.KIND_GROUP
    end
    return zo_strformat(L.KIND_GUILD, entry.guildName or "")
end

-- Подробный текст для подсказки строки «Святилище рядом с @игрок»:
-- к кому перемещение, кто ещё здесь, куда именно попадёшь
local MAX_LISTED = 4

function Presence:DescribeNearPlayer(zoneId)
    self:EnsureFresh()
    local list = zoneId and self.byZone[zoneId]
    if not list or #list == 0 then return nil end

    local lines = {
        "|c66CC66" .. L.FREE_NEAR_EXPLAIN .. "|r",
        zo_strformat(L.FREE_VIA_WHO, list[1].displayName, self:DescribeKind(list[1])),
    }
    if #list > 1 then
        local others = {}
        for index = 2, zo_min(#list, MAX_LISTED) do
            others[#others + 1] = list[index].displayName .. " (" .. self:DescribeKind(list[index]) .. ")"
        end
        local text = zo_strformat(L.FREE_VIA_ALSO, table.concat(others, ", "))
        if #list > MAX_LISTED then
            text = text .. " " .. zo_strformat(L.FREE_VIA_MORE, #list - MAX_LISTED)
        end
        lines[#lines + 1] = "|c9A9A9A" .. text .. "|r"
    end
    lines[#lines + 1] = "|c9A9A9A" .. L.FREE_NEAR_ARRIVAL .. "|r"
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Перемещение к игроку — надёжнее, по примеру аддона BeamMeUp:
--   • если вы верхом, игра при первой попытке только спешивает и никуда не
--     переносит — через полторы секунды пробуем ещё раз;
--   • если игрока не удалось найти (он ушёл в подземелье, дом, сменил
--     локацию или вышел), пробуем следующего друга или согильдийца в той же
--     локации — до MAX_ATTEMPTS попыток.
-- Удачное перемещение видно по началу загрузки (EVENT_PLAYER_DEACTIVATED).
---------------------------------------------------------------------------
local MAX_ATTEMPTS     = 3
local MOUNT_RETRY_MS   = 1500
local PENDING_TIMEOUT  = 10000

-- Ошибки, при которых пробовать другого игрока бессмысленно: дело в вас, а не в нём
-- (бой, арест, место, откуда нельзя уйти, слишком частые запросы).
-- При любой другой ошибке (игрок в групповом подземелье, в доме, в закрытой
-- локации, ушёл из игры…) аддон пробует следующего.
local STOP_RESULTS = {}
for _, name in ipairs({ "SOCIAL_RESULT_NO_JUMP_IN_COMBAT", "SOCIAL_RESULT_JUMPS_EXIT_DISABLED",
                        "SOCIAL_RESULT_BEING_ARRESTED", "SOCIAL_RESULT_RATE_LIMIT_EXCEEDED",
                        "SOCIAL_RESULT_NO_ERROR" }) do
    if _G[name] ~= nil then STOP_RESULTS[_G[name]] = true end
end

local function CanTryAnother(errorCode)
    return errorCode ~= nil and not STOP_RESULTS[errorCode]
end

local function SendJump(entry)
    if entry.kind == Presence.KIND_FRIEND then
        JumpToFriend(entry.displayName)
    elseif entry.kind == Presence.KIND_GROUP then
        JumpToGroupMember(entry.displayName)
    else
        JumpToGuildMember(entry.displayName)
    end
end

-- Перемещение к игроку.
-- opts (необязательно):
--   candidates  — свой список игроков для повторных попыток (по умолчанию — все
--                 друзья и согильдийцы в той же локации);
--   maxAttempts — сколько игроков пробовать;
--   onLoading   — вызывается, когда началась загрузка (перемещение удалось);
--   onFail      — вызывается, если не удалось ни к кому (вместо обычного сообщения).
function Presence:Jump(entry, opts)
    opts = opts or {}
    local pending = {
        zoneId      = entry.zoneId,
        zoneName    = entry.zoneName,
        tried       = {},
        attempts    = 0,
        candidates  = opts.candidates,
        maxAttempts = opts.maxAttempts or MAX_ATTEMPTS,
        onLoading   = opts.onLoading,
        onFail      = opts.onFail,
    }
    self.pending = pending
    self:Attempt(pending, entry)
end

-- Не получилось совсем: сообщаем тому, кто просил, или пишем сами
local function Fail(self, pending, errorCode)
    pending.finished = true
    if self.pending == pending then self.pending = nil end
    if pending.onFail then
        pending.onFail(errorCode)
    elseif CanTryAnother(errorCode) and pending.entry.kind ~= Presence.KIND_GROUP then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
            zo_strformat(L.ALERT_JUMP_NONE, pending.zoneName or pending.entry.zoneName or ""))
    end
end

function Presence:Attempt(pending, entry)
    if CancelCast then CancelCast() end  -- на всякий случай прерываем каст, как BeamMeUp

    pending.entry     = entry
    pending.attempts  = pending.attempts + 1
    pending.startedAt = GetFrameTimeMilliseconds()
    pending.tried[entry.displayName] = true
    local token = {}
    pending.token = token

    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_JUMPING, entry.displayName))
    SendJump(entry)

    -- Верхом: первая попытка только спешит — повторяем
    if IsMounted and IsMounted() then
        zo_callLater(function()
            if self.pending == pending and pending.token == token and not pending.finished then
                SendJump(entry)
            end
        end, MOUNT_RETRY_MS)
    end

    -- Если ничего не произошло (ни загрузки, ни ошибки), через время сдаёмся
    zo_callLater(function()
        if self.pending == pending and pending.token == token and not pending.finished then
            Fail(self, pending, nil)
        end
    end, PENDING_TIMEOUT)
end

function Presence:OnSocialError(errorCode)
    local pending = self.pending
    if not pending or pending.finished then return end
    if GetFrameTimeMilliseconds() - (pending.startedAt or 0) > PENDING_TIMEOUT then
        self.pending = nil
        return
    end

    -- Члена группы не подменяем другим игроком: на карте выбрано конкретное святилище
    local canRetry = CanTryAnother(errorCode) and pending.entry.kind ~= Presence.KIND_GROUP
        and pending.attempts < pending.maxAttempts
    if canRetry then
        local list = pending.candidates
        if not list then
            -- Список мог устареть — пересобираем и ищем того, кого ещё не пробовали
            self:Rebuild()
            list = self.byZone[pending.zoneId] or {}
        end
        for _, candidate in ipairs(list) do
            if not pending.tried[candidate.displayName] then
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,
                    zo_strformat(L.ALERT_JUMP_RETRY, pending.entry.displayName, candidate.displayName))
                self:Attempt(pending, candidate)
                return
            end
        end
    end

    Fail(self, pending, errorCode)
end

-- Началась загрузка — перемещение удалось
function Presence:OnPlayerDeactivated()
    local pending = self.pending
    if pending then
        pending.finished = true
        self.pending = nil
        if pending.onLoading then pending.onLoading() end
    end
end

-- Есть ли сейчас хоть кто-то, к кому можно переместиться
function Presence:HasAnyone()
    if not self:IsEnabled() then return false end
    self:EnsureFresh()
    return next(self.byZone) ~= nil
end

---------------------------------------------------------------------------
-- Члены группы: у них, в отличие от друзей и согильдийцев, игра знает
-- точное положение на открытой карте (так рисуются их значки). Поэтому для
-- них можно найти ближайшее святилище — туда и перенесёт игра.
---------------------------------------------------------------------------
-- Ближайшее к точке (x, y) святилище на открытой сейчас карте
function Presence:NearestWayshrineOnMap(x, y)
    local bestIndex, bestDistance
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, _, nx, ny, _, _, poiType, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if isShownInCurrentMap and poiType == POI_TYPE_WAYSHRINE then
            local dx, dy = nx - x, ny - y
            local distance = dx * dx + dy * dy
            if not bestDistance or distance < bestDistance then
                bestIndex, bestDistance = nodeIndex, distance
            end
        end
    end
    return bestIndex, bestDistance and math.sqrt(bestDistance) or nil
end

-- Член группы, ближайшее святилище к которому — именно это (или nil)
function Presence:FindGroupMemberNearNode(nodeIndex)
    if not QTM.sv.freeViaGroup then return nil end
    for index = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(index)
        if unitTag and DoesUnitExist(unitTag) and not AreUnitsEqual("player", unitTag) and IsUnitOnline(unitTag) then
            local x, y, _, isShownInCurrentMap = GetMapPlayerPosition(unitTag)
            if isShownInCurrentMap and (x ~= 0 or y ~= 0) and self:NearestWayshrineOnMap(x, y) == nodeIndex then
                return {
                    displayName   = GetUnitDisplayName(unitTag),
                    characterName = GetUnitName(unitTag),
                    kind          = Presence.KIND_GROUP,
                    unitTag       = unitTag,
                }
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- События: кто-то сменил локацию, вошёл/вышел, список друзей или гильдий изменился
---------------------------------------------------------------------------
function Presence:Initialize()
    local function OnChanged()
        self:MarkDirty()
        if QTM.RefreshTravelState then QTM.RefreshTravelState() end
    end

    local events = {
        EVENT_FRIEND_CHARACTER_ZONE_CHANGED,
        EVENT_FRIEND_PLAYER_STATUS_CHANGED,
        EVENT_FRIEND_ADDED,
        EVENT_FRIEND_REMOVED,
        EVENT_GUILD_MEMBER_CHARACTER_ZONE_CHANGED,
        EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED,
        EVENT_GUILD_MEMBER_ADDED,
        EVENT_GUILD_MEMBER_REMOVED,
        EVENT_GUILD_SELF_JOINED_GUILD,
        EVENT_GUILD_SELF_LEFT_GUILD,
    }
    for index, eventId in ipairs(events) do
        EVENT_MANAGER:RegisterForEvent(QTM.name .. "Presence" .. index, eventId, OnChanged)
    end

    EVENT_MANAGER:RegisterForEvent(QTM.name .. "PresenceError", EVENT_SOCIAL_ERROR,
        function(_, errorCode) self:OnSocialError(errorCode) end)
    EVENT_MANAGER:RegisterForEvent(QTM.name .. "PresenceLoading", EVENT_PLAYER_DEACTIVATED,
        function() self:OnPlayerDeactivated() end)
end
