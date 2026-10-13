-- Перемещение к заданию: к ближайшему к цели задания открытому святилищу.
--
-- Как находится святилище:
--   1. карта переключается туда, где находится цель задания (как кнопка игры
--      «Показать на карте»);
--   2. у игры запрашивается точка цели на этой карте — та же, по которой
--      рисуется метка задания;
--   3. ищется ближайшее к этой точке открытое святилище на той же карте; если
--      на ней святилищ нет (подземелье, пещера, город без святилища),
--      карта поднимается на уровень выше и точка запрашивается снова;
--   4. карта возвращается как была, и начинается обычное перемещение — с
--      бесплатным путём через игрока, если он включён для заданий.
--
-- Перемещаться можно только к заданиям, у которых место цели известно: у
-- условий вроде «соберите 10 рунных камней» места нет — кнопки не будет.
local QTM = MundusGate
local L   = QTM.L

local QuestTravel = {}
QTM.QuestTravel = QuestTravel

local REQUEST_TIMEOUT_MS = 2000
local MAX_ZOOM_OUT       = 2
local SOURCE             = "Quest"
local MAIN_STEP          = QUEST_MAIN_STEP_INDEX or 1

local function Alert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
end

function QuestTravel:Initialize()
    EVENT_MANAGER:RegisterForEvent(QTM.name .. "QuestTravel", EVENT_QUEST_POSITION_REQUEST_COMPLETE,
        function(_, taskId, pinType, x, y, areaRadius, insideCurrentMapWorld, isBreadcrumb)
            self:OnPosition(taskId, x, y, insideCurrentMapWorld)
        end)
end

function QuestTravel:IsBusy()
    return self.job ~= nil
end

-- Обычное нажатие — с бесплатным путём через игрока (если включён), с Shift — сразу за золото
function QuestTravel:IsDirect()
    return IsShiftKeyDown ~= nil and IsShiftKeyDown()
end

-- questIndex — номер задания в журнале; payNow = true — без бесплатного пути
function QuestTravel:Start(questIndex, payNow)
    if self.job then self:Abort() end
    if not questIndex or not IsValidQuestIndex(questIndex) then return false end

    local targets = QTM.Quests:GetTravelTargets(questIndex)
    if #targets == 0 then
        Alert(L.QUEST_NO_LOCATION)
        return false
    end
    if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
        Alert(L.QUEST_MAP_LOCKED)
        return false
    end

    self.token = (self.token or 0) + 1
    self.job = {
        token        = self.token,
        questIndex   = questIndex,
        questName    = GetJournalQuestName and GetJournalQuestName(questIndex) or "",
        targets      = targets,
        targetIndex  = 0,
        payNow       = payNow == true,
        mapWasShown  = WORLD_MAP_SCENE ~= nil and WORLD_MAP_SCENE:IsShowing(),
        startMapId   = GetCurrentMapId(),
        requests     = 0,
    }
    self:NextTarget()
    return true
end

-- Главное задание (кнопка в «Управлении», кнопка панели заданий)
function QuestTravel:TravelMain()
    local all = QTM.Quests:GetAll()
    local item = all.mainKey and all.byKey[all.mainKey]
    if not item or item.kind ~= QTM.Quests.KIND_QUEST or not item.canTravel then
        -- Главное — не задание из журнала или его место неизвестно: берём первое закреплённое задание с известным местом
        item = nil
        for _, key in ipairs(QTM.Quests:GetPins()) do
            local pinned = all.byKey[key]
            if pinned and pinned.kind == QTM.Quests.KIND_QUEST and pinned.canTravel then
                item = pinned
                break
            end
        end
    end
    if not item then
        Alert(L.QUEST_NO_MAIN)
        return false
    end
    return self:Start(item.questIndex, self:IsDirect())
end

function QuestTravel:NextTarget()
    local job = self.job
    if not job then return end
    job.targetIndex = job.targetIndex + 1
    local target = job.targets[job.targetIndex]
    if not target then
        return self:Finish(nil)
    end

    job.zoomOuts = 0
    local result
    if target.ending then
        result = SetMapToQuestStepEnding(job.questIndex, target.step)
    else
        result = SetMapToQuestCondition(job.questIndex, target.step, target.condition)
    end
    if result == SET_MAP_RESULT_FAILED then
        return self:NextTarget()
    end
    self:Request()
end

function QuestTravel:Request()
    local job = self.job
    if not job then return end
    local target = job.targets[job.targetIndex]
    local step = target.ending and MAIN_STEP or target.step
    local condition = target.ending and 1 or target.condition

    local taskId = RequestJournalQuestConditionAssistance(job.questIndex, step, condition)
    if not taskId then
        return self:NextTarget()
    end
    job.taskId = taskId
    job.requests = job.requests + 1
    local token, request = job.token, job.requests
    zo_callLater(function()
        local current = self.job
        if current and current.token == token and current.requests == request and current.taskId then
            CancelRequestJournalQuestConditionAssistance(current.taskId)
            current.taskId = nil
            self:NextTarget()
        end
    end, REQUEST_TIMEOUT_MS)
end

function QuestTravel:OnPosition(taskId, x, y, insideCurrentMapWorld)
    local job = self.job
    if not job or job.taskId ~= taskId then return end
    job.taskId = nil

    if insideCurrentMapWorld ~= false and x and y and (x ~= 0 or y ~= 0) then
        local nodeIndex = QTM.Presence:NearestWayshrineOnMap(x, y, true)
        if nodeIndex then
            return self:Finish(nodeIndex)
        end
    end

    -- На этой карте открытых святилищ нет — поднимаемся на уровень выше
    if job.zoomOuts < MAX_ZOOM_OUT and MapZoomOut() == SET_MAP_RESULT_MAP_CHANGED then
        job.zoomOuts = job.zoomOuts + 1
        return self:Request()
    end
    self:NextTarget()
end

-- Вернуть карту: открытая карта остаётся на месте задания, закрытая — как была
function QuestTravel:RestoreMap(job)
    local result
    if job.mapWasShown then
        result = SET_MAP_RESULT_MAP_CHANGED
    else
        result = SetMapToMapId(job.startMapId)
        if result == SET_MAP_RESULT_FAILED then result = SetMapToPlayerLocation() end
    end
    if result == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
end

function QuestTravel:Abort()
    local job = self.job
    if not job then return end
    self.job = nil
    if job.taskId then CancelRequestJournalQuestConditionAssistance(job.taskId) end
    self:RestoreMap(job)
end

function QuestTravel:Finish(nodeIndex)
    local job = self.job
    if not job then return end
    self.job = nil
    self:RestoreMap(job)

    local node = nodeIndex and QTM.Data:GetNode(nodeIndex)
    if not node then
        Alert(L.QUEST_NO_WAYSHRINE)
        return
    end
    d(zo_strformat(L.QUEST_CHAT_TRAVEL, job.questName, node.name))
    QTM.Data:Travel(node, job.payNow, SOURCE)
end
