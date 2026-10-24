--[[
    AetherPath - Single focused quest tracker
    Shows only the assisted/selected quest (like native), with description.
    Cycles with T (same idea as native quest tracker).
    Original code.
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.Tracker = AP.Tracker or {}

local Tracker = AP.Tracker

local HIDE_REASON = "AetherPath"

function Tracker:Initialize()
    self.focusedIndex = nil
    self.questList = {}   -- ordered journal indices
    self:HideNativeTracker(true)
    self:BuildList()
    self:ResolveFocused()
    -- Re-apply native hide when any scene changes (menus re-show fragments)
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            if AP.sv and AP.sv.showTracker ~= false then
                self:HideNativeTracker(true)
            end
        end)
    end
end

-------------------------------------------------
-- Hide / show native focused quest tracker
-------------------------------------------------
function Tracker:HideNativeTracker(hide)
    hide = hide and true or false
    if FOCUSED_QUEST_TRACKER_FRAGMENT then
        FOCUSED_QUEST_TRACKER_FRAGMENT:SetHiddenForReason(HIDE_REASON, hide, 0, 0)
    end
    -- Also hide timed activities tracker if present (keeps UI clean)
    if TIMED_ACTIVITY_TRACKER_FRAGMENT then
        TIMED_ACTIVITY_TRACKER_FRAGMENT:SetHiddenForReason(HIDE_REASON, hide, 0, 0)
    end
    -- Fallback: direct control hide
    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.control then
        FOCUSED_QUEST_TRACKER.control:SetHidden(hide)
    end
end

function Tracker:Shutdown()
    self:HideNativeTracker(false)
end

-------------------------------------------------
-- Journal list + focused quest
-------------------------------------------------
function Tracker:BuildList()
    self.questList = {}
    local num = GetNumJournalQuests()
    for i = 1, num do
        local name = GetJournalQuestName(i)
        if name and name ~= "" then
            table.insert(self.questList, i)
        end
    end
end

function Tracker:IsAssisted(questIndex)
    if not questIndex then return false end
    -- ESO: TRACK_TYPE_QUEST
    if GetTrackedIsAssisted then
        return GetTrackedIsAssisted(TRACK_TYPE_QUEST, questIndex) == true
    end
    -- Fallback older API style
    if GetJournalQuestIsTracked then
        return GetJournalQuestIsTracked(questIndex) == true
    end
    return false
end

function Tracker:SetAssisted(questIndex)
    if not questIndex then return end
    if SetTrackedIsAssisted then
        SetTrackedIsAssisted(TRACK_TYPE_QUEST, true, questIndex)
    elseif AssistQuest then
        AssistQuest(questIndex)
    end
    self.focusedIndex = questIndex
end

function Tracker:ResolveFocused()
    self:BuildList()
    local found
    for _, idx in ipairs(self.questList) do
        if self:IsAssisted(idx) then
            found = idx
            break
        end
    end
    if not found and #self.questList > 0 then
        found = self.questList[1]
        self:SetAssisted(found)
    end
    self.focusedIndex = found
    return found
end

-------------------------------------------------
-- Full data for the focused quest (native-like)
-------------------------------------------------
function Tracker:GetFocusedQuestData()
    local idx = self.focusedIndex or self:ResolveFocused()
    if not idx then return nil end

    local name, backgroundText, activeStepText, activeStepType, activeStepTrackerOverrideText,
          completed, tracked, questType, zone =
        GetJournalQuestInfo(idx)

    -- Zone / location string
    local zoneName = zone
    if (not zoneName or zoneName == "") and GetJournalQuestLocationInfo then
        zoneName = GetJournalQuestLocationInfo(idx)
    end

    -- Level / type hints
    local level = GetJournalQuestLevel and GetJournalQuestLevel(idx) or 0
    local repeatType = GetJournalQuestRepeatType and GetJournalQuestRepeatType(idx) or 0

    -- Conditions (objectives) of the current main step
    local objectives = {}
    local stepIndex = QUEST_MAIN_STEP_INDEX or 1
    local numCond = GetJournalQuestNumConditions(idx, stepIndex) or 0
    for c = 1, numCond do
        local condText, current, maxVal, isFail, isComplete, isCreditShared, isVisible =
            GetJournalQuestConditionInfo(idx, stepIndex, c)
        if condText and condText ~= "" and not isFail and (isVisible ~= false) then
            table.insert(objectives, {
                text     = condText,
                current  = current or 0,
                max      = maxVal or 0,
                complete = isComplete or false,
            })
        end
    end

    -- Prefer tracker override text when present (same as native)
    local stepText = activeStepTrackerOverrideText
    if not stepText or stepText == "" then
        stepText = activeStepText
    end

    return {
        index        = idx,
        name         = name or "?",
        description  = backgroundText or "",
        stepText     = stepText or "",
        zone         = zoneName or "",
        level        = level,
        completed    = completed,
        tracked      = tracked,
        questType    = questType,
        objectives   = objectives,
        count        = #self.questList,
        position     = self:GetPositionInList(idx),
    }
end

function Tracker:GetPositionInList(questIndex)
    for i, idx in ipairs(self.questList) do
        if idx == questIndex then return i end
    end
    return 1
end

-------------------------------------------------
-- Cycle focused quest (T key behavior)
-------------------------------------------------
function Tracker:CycleNext()
    self:BuildList()
    if #self.questList == 0 then return end

    local currentPos = 0
    for i, idx in ipairs(self.questList) do
        if idx == self.focusedIndex then
            currentPos = i
            break
        end
    end

    local nextPos = currentPos + 1
    if nextPos > #self.questList then nextPos = 1 end
    local nextIndex = self.questList[nextPos]
    self:SetAssisted(nextIndex)
    self.focusedIndex = nextIndex

    if AP.UI and AP.UI.RebuildQuestList then
        AP.UI:RebuildQuestList()
    end
end

function Tracker:CyclePrev()
    self:BuildList()
    if #self.questList == 0 then return end

    local currentPos = 1
    for i, idx in ipairs(self.questList) do
        if idx == self.focusedIndex then
            currentPos = i
            break
        end
    end

    local prevPos = currentPos - 1
    if prevPos < 1 then prevPos = #self.questList end
    local prevIndex = self.questList[prevPos]
    self:SetAssisted(prevIndex)
    self.focusedIndex = prevIndex

    if AP.UI and AP.UI.RebuildQuestList then
        AP.UI:RebuildQuestList()
    end
end

function Tracker:Refresh()
    self:ResolveFocused()
    if AP.UI and AP.UI.RebuildQuestList then
        AP.UI:RebuildQuestList()
    end
end

function Tracker:AbandonQuest(questIndex)
    if not questIndex then return end
    AbandonQuest(questIndex)
end

function Tracker:ShareQuest(questIndex)
    if not questIndex then return end
    ShareQuest(questIndex)
end

function Tracker:ShowQuestOnMap(questIndex)
    if not questIndex then return end
    if ZO_WorldMap_ShowQuestOnMap then
        ZO_WorldMap_ShowQuestOnMap(questIndex)
    end
end
