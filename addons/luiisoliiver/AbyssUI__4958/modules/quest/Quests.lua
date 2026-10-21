-- Задания: журнал, «Золотые стремления» и «Фолианты Тамриэля» в одном списке.
--
-- Каждый пункт — таблица { kind, key, name, info, ... }:
--   kind = "q" — задание из журнала (key "q:<questId>");
--   kind = "p" — занятие «Золотых стремлений» (key "p:<кампания>:<номер>");
--   kind = "t" — задание фолианта (key "t:<id>").
--
-- Любой пункт можно закрепить (он появится в панели заданий на экране) и
-- один — сделать главным: он показывается первым и отслеживается игрой
-- (задание — как «текущее» с меткой на компасе, стремление и фолиант — как
-- отслеживаемое занятие). Главное задание из журнала всегда совпадает с тем,
-- что игра считает текущим: выбрали другое в журнале — оно и станет главным.
local QTM = AbyssQuest
local L   = QTM.L

local Quests = {}
QTM.Quests = Quests

Quests.KIND_QUEST   = "q"
Quests.KIND_PURSUIT = "p"
Quests.KIND_TOME    = "t"

local ICON_QUEST         = "EsoUI/Art/Compass/quest_icon.dds"
local ICON_QUEST_MAIN    = "EsoUI/Art/Compass/quest_icon_assisted.dds"
local ICON_REPEAT        = "EsoUI/Art/Compass/repeatableQuest_icon.dds"
local ICON_REPEAT_MAIN   = "EsoUI/Art/Compass/repeatableQuest_icon_assisted.dds"
local ICON_STORY         = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds"
local ICON_STORY_MAIN    = "EsoUI/Art/Compass/zoneStoryQuest_icon_assisted.dds"
local ICON_PURSUIT       = "EsoUI/Art/LFG/lfg_indexIcon_promotionalEvents_up.dds"
local ICON_PURSUIT_DONE  = "EsoUI/Art/LFG/lfg_indexIcon_promotionalEvents_up_complete.dds"
local ICON_TOME          = "EsoUI/Art/MainMenu/menuBar_tamrielTomes_up.dds"

Quests.ICON_PURSUIT = ICON_PURSUIT
Quests.ICON_TOME    = ICON_TOME
Quests.ICON_QUEST   = ICON_QUEST

local MAIN_STEP = QUEST_MAIN_STEP_INDEX or 1

local function Id64Text(id)
    if id == nil then return "" end
    if Id64ToString then return Id64ToString(id) end
    return tostring(id)
end

---------------------------------------------------------------------------
-- Задания из журнала
---------------------------------------------------------------------------

-- Строки условий текущего этапа — как в панели заданий игры
function Quests:GetConditionLines(questIndex)
    local lines = {}
    local _, visibility, stepType, overrideText, numConditions = GetJournalQuestStepInfo(questIndex, MAIN_STEP)
    if overrideText and overrideText ~= "" then
        lines[1] = overrideText
        return lines
    end
    for conditionIndex = 1, numConditions or GetJournalQuestNumConditions(questIndex, MAIN_STEP) do
        local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(questIndex, MAIN_STEP, conditionIndex)
        if text and text ~= "" and isVisible and not isFail and not isComplete then
            lines[#lines + 1] = text
        end
    end
    return lines
end

-- Куда можно переместиться по заданию: условия с известным местом на карте.
-- Если у условия нет места (например, «соберите 10 рунных камней» — они
-- повсюду), перемещаться некуда. Выполненное задание ведёт к тому, кому его сдать.
function Quests:GetTravelTargets(questIndex)
    local targets = {}
    if not questIndex or not IsValidQuestIndex(questIndex) then return targets end

    if GetJournalQuestIsComplete(questIndex) then
        for stepIndex = MAIN_STEP, GetJournalQuestNumSteps(questIndex) do
            if IsJournalQuestStepEnding(questIndex, stepIndex) then
                targets[1] = { step = stepIndex, condition = 1, ending = true }
                return targets
            end
        end
        if DoesJournalQuestConditionHavePosition(questIndex, MAIN_STEP, 1) then
            targets[1] = { step = MAIN_STEP, condition = 1 }
        end
        return targets
    end

    -- Сначала основной этап, затем необязательные
    for stepIndex = MAIN_STEP, GetJournalQuestNumSteps(questIndex) do
        local _, visibility = GetJournalQuestStepInfo(questIndex, stepIndex)
        local hidden = QUEST_STEP_VISIBILITY_HIDDEN ~= nil and visibility == QUEST_STEP_VISIBILITY_HIDDEN
        if not hidden then
            for conditionIndex = 1, GetJournalQuestNumConditions(questIndex, stepIndex) do
                local _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionValues(questIndex, stepIndex, conditionIndex)
                if isVisible and not isFail and not isComplete
                    and DoesJournalQuestConditionHavePosition(questIndex, stepIndex, conditionIndex) then
                    targets[#targets + 1] = { step = stepIndex, condition = conditionIndex }
                end
            end
        end
    end
    return targets
end

function Quests:CanTravelToQuest(questIndex)
    return #self:GetTravelTargets(questIndex) > 0
end

function Quests:GetAssistedQuestIndex()
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) and GetTrackedIsAssisted(TRACK_TYPE_QUEST, questIndex, 0) then
            return questIndex
        end
    end
    return nil
end

local function QuestIcon(questIndex, zoneDisplayType, isMain)
    local repeatType = GetJournalQuestRepeatType and GetJournalQuestRepeatType(questIndex)
    if repeatType and QUEST_REPEAT_NOT_REPEATABLE ~= nil and repeatType ~= QUEST_REPEAT_NOT_REPEATABLE then
        return isMain and ICON_REPEAT_MAIN or ICON_REPEAT
    end
    if ZONE_DISPLAY_TYPE_ZONE_STORY ~= nil and zoneDisplayType == ZONE_DISPLAY_TYPE_ZONE_STORY then
        return isMain and ICON_STORY_MAIN or ICON_STORY
    end
    return isMain and ICON_QUEST_MAIN or ICON_QUEST
end

-- Значок вида задания — как в журнале игры (испытание, подземелье, Бесконечный архив…)
local TYPE_ICON_FILES = {
    ZONE_DISPLAY_TYPE_SOLO            = "EsoUI/Art/Journal/journal_Quest_Instance.dds",
    ZONE_DISPLAY_TYPE_DUNGEON         = "EsoUI/Art/Journal/journal_Quest_Group_Instance.dds",
    ZONE_DISPLAY_TYPE_GROUP_DELVE     = "EsoUI/Art/Journal/journal_Quest_Group_Delve.dds",
    ZONE_DISPLAY_TYPE_GROUP_AREA      = "EsoUI/Art/Journal/journal_Quest_Group_Area.dds",
    ZONE_DISPLAY_TYPE_RAID            = "EsoUI/Art/Journal/journal_Quest_Trial.dds",
    ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON  = "EsoUI/Art/Journal/journal_Quest_Dungeon.dds",
    ZONE_DISPLAY_TYPE_DELVE           = "EsoUI/Art/Journal/journal_Quest_Delve.dds",
    ZONE_DISPLAY_TYPE_HOUSING         = "EsoUI/Art/Journal/journal_Quest_Housing.dds",
    ZONE_DISPLAY_TYPE_ZONE_STORY      = "EsoUI/Art/Journal/journal_Quest_ZoneStory.dds",
    ZONE_DISPLAY_TYPE_COMPANION       = "EsoUI/Art/Journal/journal_Quest_Companion.dds",
    ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON = "EsoUI/Art/Journal/journal_Quest_EndlessDungeon.dds",
    ZONE_DISPLAY_TYPE_ADVENTURE_ZONE  = "EsoUI/Art/Journal/journal_Quest_AdventureZone.dds",
    ZONE_DISPLAY_TYPE_SOLO_DUNGEON    = "EsoUI/Art/Journal/journal_Quest_Solo_Dungeon.dds",
}
local ICON_TYPE_REPEAT = "EsoUI/Art/Journal/journal_Quest_Repeat.dds"
local typeIcons

function Quests.GetQuestTypeIcon(zoneDisplayType, repeatable)
    if not typeIcons then
        typeIcons = {}
        for constant, path in pairs(TYPE_ICON_FILES) do
            if _G[constant] ~= nil then typeIcons[_G[constant]] = path end
        end
    end
    return typeIcons[zoneDisplayType] or (repeatable and ICON_TYPE_REPEAT) or nil
end

-- Название со значком вида задания перед ним
function Quests.FormatName(item, size)
    if item.typeIcon then
        size = size or 20
        return string.format("|t%d:%d:%s|t %s", size, size, item.typeIcon, item.name)
    end
    return item.name
end

-- Раздел журнала — как в журнале игры: локация, «Гильдия», «Поле сражения», «Пролог»…
local CATEGORY_OTHER_ORDER = 9
function Quests:GetCategory(questIndex, zoneName)
    local questType = GetJournalQuestType and GetJournalQuestType(questIndex)
    if QUEST_JOURNAL_MANAGER and QUEST_JOURNAL_MANAGER.GetQuestCategoryNameAndType and questType then
        local name, categoryType = QUEST_JOURNAL_MANAGER:GetQuestCategoryNameAndType(questType, zoneName or "")
        if name and name ~= "" then return name, categoryType or CATEGORY_OTHER_ORDER end
    end
    if zoneName and zoneName ~= "" then return zo_strformat("<<1>>", zoneName), 1 end
    return L.QUEST_ZONE_OTHER, CATEGORY_OTHER_ORDER
end

function Quests:BuildQuest(questIndex, assisted)
    local name, background, stepText, _, _, completed, _, level, _, questType, zoneDisplayType = GetJournalQuestInfo(questIndex)
    local zoneName = GetJournalQuestLocationInfo(questIndex)
    local key = "q:" .. tostring(GetJournalQuestId(questIndex))
    local lines = self:GetConditionLines(questIndex)
    local info = lines[1] or stepText or ""
    if #lines > 1 then info = zo_strformat(L.QUEST_MORE_LINES, info, #lines - 1) end
    local isAssisted = assisted == questIndex
    local repeatType = GetJournalQuestRepeatType and GetJournalQuestRepeatType(questIndex)
    local repeatable = repeatType ~= nil and QUEST_REPEAT_NOT_REPEATABLE ~= nil and repeatType ~= QUEST_REPEAT_NOT_REPEATABLE
    local category, categoryType = self:GetCategory(questIndex, zoneName)
    return {
        kind         = Quests.KIND_QUEST,
        key          = key,
        questIndex   = questIndex,
        name         = zo_strformat("<<1>>", name),
        info         = info,
        lines        = lines,
        description  = background,
        stepText     = stepText,
        complete     = completed,
        level        = level,
        zone         = (zoneName and zoneName ~= "") and zo_strformat("<<1>>", zoneName) or L.QUEST_ZONE_OTHER,
        category     = category,
        categoryType = categoryType,
        assisted     = isAssisted,
        icon         = QuestIcon(questIndex, zoneDisplayType, isAssisted),
        typeIcon     = Quests.GetQuestTypeIcon(zoneDisplayType, repeatable),
        canTravel    = self:CanTravelToQuest(questIndex),
    }
end

function Quests:GetQuestItems()
    local items = {}
    local assisted = self:GetAssistedQuestIndex()
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) then
            items[#items + 1] = self:BuildQuest(questIndex, assisted)
        end
    end
    -- Порядок разделов как в журнале игры: сначала локации, потом остальные
    table.sort(items, function(a, b)
        if a.categoryType ~= b.categoryType then return a.categoryType < b.categoryType end
        if a.category ~= b.category then return a.category < b.category end
        return a.name < b.name
    end)
    return items
end


---------------------------------------------------------------------------
-- «Золотые стремления»
---------------------------------------------------------------------------
function Quests:IsPursuitAvailable()
    if not GetNumActivePromotionalEventCampaigns then return false end
    if IsPromotionalEventSystemLocked and IsPromotionalEventSystemLocked() then return false end
    return true
end

function Quests:GetPursuitItems()
    local items = {}
    if not self:IsPursuitAvailable() then return items end
    local trackedKey, trackedIndex
    if GetTrackedPromotionalEventActivityInfo then
        trackedKey, trackedIndex = GetTrackedPromotionalEventActivityInfo()
    end
    for campaignIndex = 1, GetNumActivePromotionalEventCampaigns() do
        local campaignKey = GetActivePromotionalEventCampaignKey(campaignIndex)
        local campaignId, numActivities = GetPromotionalEventCampaignInfo(campaignKey)
        local campaignName = campaignId and GetPromotionalEventCampaignDisplayName(campaignId) or ""
        campaignName = campaignName ~= "" and zo_strformat("<<1>>", campaignName) or L.QUEST_SECTION_PURSUITS
        for activityIndex = 1, numActivities or 0 do
            local _, name, description, threshold = GetPromotionalEventCampaignActivityInfo(campaignKey, activityIndex)
            local progress, rewardFlags = GetPromotionalEventCampaignActivityProgress(campaignKey, activityIndex)
            progress = progress or 0
            threshold = threshold or 0
            local done = threshold > 0 and progress >= threshold
            local canKnowClaim = rewardFlags ~= nil and PROMOTIONAL_EVENTS_REWARD_FLAG_CLAIMED ~= nil and ZO_FlagHelpers ~= nil
            local claimed = done and (not canKnowClaim or ZO_FlagHelpers.MaskHasFlag(rewardFlags, PROMOTIONAL_EVENTS_REWARD_FLAG_CLAIMED))
            local tracked = trackedKey ~= nil and trackedIndex == activityIndex
                and (AreId64sEqual and AreId64sEqual(trackedKey, campaignKey) or trackedKey == campaignKey)
            items[#items + 1] = {
                kind          = Quests.KIND_PURSUIT,
                key           = "p:" .. Id64Text(campaignKey) .. ":" .. activityIndex,
                campaignKey   = campaignKey,
                activityIndex = activityIndex,
                group         = campaignName,
                name          = zo_strformat("<<1>>", name or ""),
                description   = description,
                progress      = zo_min(progress, threshold > 0 and threshold or progress),
                maxProgress   = threshold,
                info          = done and (claimed and L.QUEST_CLAIMED or L.QUEST_CLAIM) or zo_strformat(L.QUEST_PROGRESS, zo_min(progress, threshold), threshold),
                complete      = claimed,
                claimable     = done and not claimed,
                tracked       = tracked,
                icon          = claimed and ICON_PURSUIT_DONE or ICON_PURSUIT,
            }
        end
    end
    -- Невыполненные — выше
    table.sort(items, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.complete ~= b.complete then return not a.complete end
        return a.activityIndex < b.activityIndex
    end)
    return items
end

---------------------------------------------------------------------------
-- «Фолианты Тамриэля» (ежедневные, еженедельные и сезонные задания)
---------------------------------------------------------------------------
function Quests:IsTomeAvailable()
    if not GetNumTimedActivities then return false end
    if IsTimedActivitySystemAvailable and not IsTimedActivitySystemAvailable() then return false end
    return true
end

local TOME_TYPE_ORDER = {}

function Quests:GetTomeTypeName(activityType)
    if activityType == TIMED_ACTIVITY_TYPE_DAILY then return L.QUEST_TOME_DAILY end
    if activityType == TIMED_ACTIVITY_TYPE_WEEKLY then return L.QUEST_TOME_WEEKLY end
    if TIMED_ACTIVITY_TYPE_SEASONAL ~= nil and activityType == TIMED_ACTIVITY_TYPE_SEASONAL then return L.QUEST_TOME_SEASONAL end
    return L.QUEST_SECTION_TOME
end

function Quests:GetTomeItems()
    local items = {}
    if not self:IsTomeAvailable() then return items end
    TOME_TYPE_ORDER[TIMED_ACTIVITY_TYPE_DAILY or 0] = 1
    TOME_TYPE_ORDER[TIMED_ACTIVITY_TYPE_WEEKLY or 1] = 2
    if TIMED_ACTIVITY_TYPE_SEASONAL ~= nil then TOME_TYPE_ORDER[TIMED_ACTIVITY_TYPE_SEASONAL] = 3 end

    local trackedIndex = GetTrackedTimedActivityInfo and GetTrackedTimedActivityInfo()
    local now = GetTimeStamp()
    local seasonEnd = GetActiveTamrielTomeSeasonEndTimeS and GetActiveTamrielTomeSeasonEndTimeS() or 0
    for index = 1, GetNumTimedActivities() do
        local activityType = GetTimedActivityType(index)
        local progress = GetTimedActivityProgress(index) or 0
        local maxProgress = GetTimedActivityMaxProgress(index) or 0

        -- Сколько раз награду уже получили: «Получено: 1/1» — задание выполнено,
        -- даже если счётчик снова на нуле; «38/∞» — задание бесконечное
        local total = GetTimedActivityTotalNumTimesClaimable and GetTimedActivityTotalNumTimesClaimable(index) or 1
        local claimed = GetTimedActivityNumTimesClaimed and GetTimedActivityNumTimesClaimed(index) or 0
        local infinite = total == 0 or total >= 99
        local fullyClaimed = not infinite and claimed >= total
        local ready = not fullyClaimed and maxProgress > 0 and progress >= maxProgress

        -- Срок: у заданий, которые кончаются раньше сезона
        local endTime = GetTimedActivityEndTimeS and GetTimedActivityEndTimeS(index) or 0
        local left = (endTime > 0 and endTime ~= seasonEnd) and (endTime - now) or nil
        local expired = left ~= nil and left <= 0

        local info
        if fullyClaimed then
            info = L.QUEST_CLAIMED
        elseif ready then
            info = L.QUEST_CLAIM
        elseif expired then
            info = L.QUEST_EXPIRED
        else
            info = zo_strformat(L.QUEST_PROGRESS, zo_min(progress, maxProgress), maxProgress)
            if left and ZO_FormatTimeLargestTwo then
                info = info .. " · " .. zo_strformat(L.QUEST_TIME_LEFT, ZO_FormatTimeLargestTwo(left, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL))
            end
        end
        if infinite and claimed > 0 then
            info = info .. " · " .. zo_strformat(L.QUEST_CLAIMED_COUNT, claimed)
        end

        local done = fullyClaimed or expired
        items[#items + 1] = {
            kind         = Quests.KIND_TOME,
            key          = "t:" .. tostring(GetTimedActivityId(index)),
            timedIndex   = index,
            activityType = activityType,
            order        = TOME_TYPE_ORDER[activityType] or 9,
            group        = self:GetTomeTypeName(activityType),
            name         = zo_strformat("<<1>>", GetTimedActivityName(index) or ""),
            description  = GetTimedActivityDescription and GetTimedActivityDescription(index) or nil,
            progress     = (fullyClaimed or ready) and maxProgress or zo_min(progress, maxProgress),
            maxProgress  = maxProgress,
            info         = info,
            complete     = done,
            claimable    = ready,
            tracked      = trackedIndex == index,
            icon         = ICON_TOME,
        }
    end
    table.sort(items, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        if a.complete ~= b.complete then return not a.complete end
        return a.timedIndex < b.timedIndex
    end)
    return items
end

---------------------------------------------------------------------------
-- Всё вместе
---------------------------------------------------------------------------
function Quests:GetAll()
    local all = {
        quests   = self:GetQuestItems(),
        pursuits = self:GetPursuitItems(),
        tomes    = self:GetTomeItems(),
        byKey    = {},
    }
    for _, list in ipairs({ all.quests, all.pursuits, all.tomes }) do
        for _, item in ipairs(list) do all.byKey[item.key] = item end
    end
    local mainKey = self:GetMainKey()
    if mainKey and not all.byKey[mainKey] then
        -- Главное стремление или задание фолианта закончилось — главным снова будет текущее задание
        local assisted = self:GetAssistedQuestIndex()
        mainKey = assisted and ("q:" .. tostring(GetJournalQuestId(assisted))) or nil
    end
    all.mainKey = mainKey
    for key, item in pairs(all.byKey) do
        item.isMain   = key == mainKey
        item.isPinned = self:IsPinned(key)
    end
    return all
end


---------------------------------------------------------------------------
-- Закреплённые и главное
---------------------------------------------------------------------------
function Quests:GetPins()
    local sv = QTM.sv
    if type(sv.questPins) ~= "table" then sv.questPins = {} end
    return sv.questPins
end

function Quests:IsPinned(key)
    for _, pinned in ipairs(self:GetPins()) do
        if pinned == key then return true end
    end
    return false
end

function Quests:SetPinned(key, pinned)
    local pins = self:GetPins()
    for index = #pins, 1, -1 do
        if pins[index] == key then table.remove(pins, index) end
    end
    if pinned then pins[#pins + 1] = key end
    self:Changed()
end

-- Перетаскивание мышью: поставить пункт перед другим закреплённым (или в конец)
function Quests:MovePin(key, beforeKey)
    local pins = self:GetPins()
    for index = #pins, 1, -1 do
        if pins[index] == key then table.remove(pins, index) end
    end
    local position = #pins + 1
    if beforeKey then
        for index, pinned in ipairs(pins) do
            if pinned == beforeKey then position = index break end
        end
    end
    table.insert(pins, position, key)
    self:Changed()
end

-- Пункт бросили: zone = "main" (на главное — сделать главным), "pinned" (в закреплённые,
-- перед target или в конец) или "other" (из закреплённых в общий список — открепить)
function Quests:Drop(item, zone, target)
    if not item then return end
    if zone == "main" then
        if not item.isMain and not (item.complete and item.kind ~= Quests.KIND_QUEST) then self:SetMain(item) end
    elseif zone == "pinned" then
        if target and target.key == item.key then return end
        self:MovePin(item.key, target and target.key or nil)
        PlaySound(SOUNDS.DEFAULT_CLICK)
    elseif zone == "other" and item.isPinned then
        self:SetPinned(item.key, false)
        PlaySound(SOUNDS.DEFAULT_CLICK)
    end
end

function Quests:TogglePin(key)
    local pinned = not self:IsPinned(key)
    self:SetPinned(key, pinned)
    PlaySound(pinned and SOUNDS.QUEST_FOCUSED or SOUNDS.DEFAULT_CLICK)
    return pinned
end

-- Главный пункт: выбранный стремлением/фолиантом или текущее задание игры
function Quests:GetMainKey()
    local main = QTM.sv.questMain
    if type(main) == "string" and main:sub(1, 2) ~= "q:" then
        return main
    end
    local assisted = self:GetAssistedQuestIndex()
    if assisted then return "q:" .. tostring(GetJournalQuestId(assisted)) end
    return nil
end


-- Сделать главным: игра начинает его отслеживать
function Quests:SetMain(item)
    if not item then return end
    if item.kind == Quests.KIND_QUEST then
        QTM.sv.questMain = item.key
        if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.ForceAssist then
            FOCUSED_QUEST_TRACKER:ForceAssist(item.questIndex)
        end
    elseif item.kind == Quests.KIND_PURSUIT then
        QTM.sv.questMain = item.key
        if TrackPromotionalEventActivity then
            TrackPromotionalEventActivity(item.campaignKey, item.activityIndex)
        end
        if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.SetAssistedAspiration and ZO_HUD_TRACKER_ASPIRATION then
            HUD_TRACKER_MANAGER:SetAssistedAspiration(ZO_HUD_TRACKER_ASPIRATION.PROMOTIONAL_EVENT)
        end
    elseif item.kind == Quests.KIND_TOME then
        QTM.sv.questMain = item.key
        if TrackTimedActivity then TrackTimedActivity(item.timedIndex) end
        if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.SetAssistedAspiration and ZO_HUD_TRACKER_ASPIRATION then
            HUD_TRACKER_MANAGER:SetAssistedAspiration(ZO_HUD_TRACKER_ASPIRATION.TIMED_ACTIVITY)
        end
    end
    PlaySound(SOUNDS.QUEST_FOCUSED or SOUNDS.DEFAULT_CLICK)
    self:Changed()
end

-- Снять «главное» со стремления или фолианта: главным снова станет текущее задание
function Quests:ClearMain()
    QTM.sv.questMain = nil
    self:Changed()
end

---------------------------------------------------------------------------
-- Обновление: всё, что показывает задания, перерисовывается одним разом
---------------------------------------------------------------------------
local UPDATE_NAME = "AbyssQuestQuestsChanged"

function Quests:Changed()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 120, function()
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        if QTM.InfoPanel and QTM.InfoPanel.RefreshQuestsIfShown then QTM.InfoPanel:RefreshQuestsIfShown() end
        if QTM.QuestTracker and QTM.QuestTracker.Refresh then QTM.QuestTracker:Refresh() end
    end)
end

function Quests:Initialize()
    local function OnChanged() self:Changed() end

    local function OnQuestRemoved(_, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
        if questId then self:SetPinned("q:" .. tostring(questId), false) end
        self:Changed()
    end

    local em = EVENT_MANAGER
    local name = QTM.name .. "Quests"
    em:RegisterForEvent(name, EVENT_QUEST_ADDED, OnChanged)
    em:RegisterForEvent(name, EVENT_QUEST_REMOVED, OnQuestRemoved)
    em:RegisterForEvent(name, EVENT_QUEST_ADVANCED, OnChanged)
    em:RegisterForEvent(name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnChanged)
    em:RegisterForEvent(name, EVENT_QUEST_LIST_UPDATED, OnChanged)
    em:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, OnChanged)
    for _, eventName in ipairs({
        "EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED",
        "EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED",
        "EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED",
        "EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED",
        "EVENT_TIMED_ACTIVITIES_UPDATED",
        "EVENT_TIMED_ACTIVITY_TRACKING_UPDATED",
    }) do
        local eventId = _G[eventName]
        if eventId then em:RegisterForEvent(name, eventId, OnChanged) end
    end

    -- Текущее задание выбрали в журнале или на панели игры — оно же и главное
    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.RegisterCallback then
        FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", function(_, assistedData)
            if assistedData and assistedData.trackType == TRACK_TYPE_QUEST then
                local main = QTM.sv.questMain
                if main == nil or main:sub(1, 2) == "q:" then
                    QTM.sv.questMain = nil
                end
            end
            self:Changed()
        end)
    end
end
