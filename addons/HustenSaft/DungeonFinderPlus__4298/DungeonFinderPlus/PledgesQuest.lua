-- PledgesQuest.lua – DungeonFinderPlus (Multilingual)
DungeonFinderPlus = DungeonFinderPlus or {}
local DFP = DungeonFinderPlus

DFP.Pledges = DFP.Pledges or {}

-- ──────────────────────────────────────────────────────────────
-- Status-Konstanten für die Farbgebung
-- ──────────────────────────────────────────────────────────────
DFP.PLEDGE_STATE_NONE      = 0 -- Weiß: Nicht aktiv / Kein Pledge heute / bereits erledigt
DFP.PLEDGE_STATE_AVAILABLE = 1 -- Blau: Heute dran (LibUndauntedPledges), noch nicht angenommen
DFP.PLEDGE_STATE_ACCEPTED  = 2 -- Gelb: Im Tagebuch angenommen, Dungeon noch offen
DFP.PLEDGE_STATE_COMPLETED = 3 -- Grün: Dungeon erledigt, bereit zum Abgeben

DFP.Pledges.active           = {}
DFP.Pledges.states           = {}
DFP.Pledges.activeActivities = {}
DFP.Pledges.turnedToday      = {}
DFP.Pledges.lastDayKey       = ""

-- ──────────────────────────────────────────────────────────────
-- Mehrsprachige Text-Normalisierung
-- ──────────────────────────────────────────────────────────────
local function foldAccents(s)
    if not s then return "" end
    return s
        :gsub("[Ää]","ae"):gsub("[Öö]","oe"):gsub("[Üü]","ue"):gsub("ß","ss")
        :gsub("[ÀÁÂÃÄÅàáâãå]","a"):gsub("[ÈÉÊËèéêë]","e"):gsub("[ÌÍÎÏìíîï]","i")
        :gsub("[ÒÓÔÕØòóôõø]","o"):gsub("[ÙÚÛÜùúûü]","u"):gsub("[Ññ]","n"):gsub("[Çç]","c")
end

local function norm(s)
    if not s then return "" end
    s = zo_strformat("<<C:1>>", s)
    s = foldAccents(s):lower()
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("[%p%s%c]+", " ")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function CleanKey(text)
    local s = norm(text)
    return s:gsub("%s+", "")
end

local function SafeActivityInfo(activityId)
    if not activityId or not GetActivityInfo then return nil end
    local name = GetActivityInfo(activityId)
    if name and name ~= "" then
        return zo_strformat("<<C:1>>", name)
    end
    return nil
end

-- ──────────────────────────────────────────────────────────────
-- Tages-Cache für heute bereits abgegebene Gelöbnisse
-- ──────────────────────────────────────────────────────────────
local function GetCurrentDayKey()
    if type(GetDate) == "function" then
        return tostring(GetDate())
    end
    return tostring(os.date("%Y%m%d"))
end

local function CheckDayRollover()
    local currentDay = GetCurrentDayKey()
    if DFP.Pledges.lastDayKey ~= currentDay then
        DFP.Pledges.lastDayKey = currentDay
        DFP.Pledges.turnedToday = {}

        if DFP.sv then
            DFP.sv.pledgeTurnedToday = DFP.sv.pledgeTurnedToday or {}
            if DFP.sv.pledgeTurnedDay ~= currentDay then
                DFP.sv.pledgeTurnedDay = currentDay
                DFP.sv.pledgeTurnedToday = {}
            else
                for k, v in pairs(DFP.sv.pledgeTurnedToday) do
                    DFP.Pledges.turnedToday[k] = v
                end
            end
        end
    end
end

local function MarkPledgeTurnedIn(questName)
    if not questName or questName == "" then return end
    CheckDayRollover()

    local cKey = CleanKey(questName)
    local nKey = norm(questName)

    DFP.Pledges.turnedToday[cKey] = true
    DFP.Pledges.turnedToday[nKey] = true

    if DFP.Pledges.activityList then
        for _, act in ipairs(DFP.Pledges.activityList) do
            if cKey:find(act.cleanKey, 1, true) or act.cleanKey:find(cKey, 1, true) then
                DFP.Pledges.turnedToday[act.cleanKey] = true
                DFP.Pledges.turnedToday[act.normKey]  = true
                if act.activityId then
                    DFP.Pledges.turnedToday[act.activityId] = true
                end
            end
        end
    end

    if DFP.sv and DFP.sv.pledgeTurnedToday then
        for k, v in pairs(DFP.Pledges.turnedToday) do
            DFP.sv.pledgeTurnedToday[k] = v
        end
    end
end

-- ──────────────────────────────────────────────────────────────
-- Dungeon-Katalog aus LFG-Aktivitäten aufbauen
-- ──────────────────────────────────────────────────────────────
function DFP.Pledges:BuildCatalog()
    self.catalog = {}
    self.activityList = {}

    local function AddType(activityType)
        if type(GetNumActivitiesByType) ~= "function" or type(GetActivityIdByTypeAndIndex) ~= "function" then return end
        local count = GetNumActivitiesByType(activityType)
        for index = 1, count do
            local actId = GetActivityIdByTypeAndIndex(activityType, index)
            local name = SafeActivityInfo(actId)
            if name and name ~= "" then
                local cKey = CleanKey(name)
                if cKey ~= "" and not self.catalog[cKey] then
                    local entry = {
                        cleanKey   = cKey,
                        normKey    = norm(name),
                        name       = name,
                        activityId = actId,
                    }
                    self.catalog[cKey] = entry
                    self.activityList[#self.activityList + 1] = entry
                end
            end
        end
    end

    AddType(LFG_ACTIVITY_DUNGEON)
    AddType(LFG_ACTIVITY_MASTER_DUNGEON)

    table.sort(self.activityList, function(a, b)
        return #a.cleanKey > #b.cleanKey
    end)
end

-- ──────────────────────────────────────────────────────────────
-- UI-Refresh
-- ──────────────────────────────────────────────────────────────
local function ScheduleUIRefresh()
    if DFP._pledgeUIRefreshPending then return end
    DFP._pledgeUIRefreshPending = true
    zo_callLater(function()
        DFP._pledgeUIRefreshPending = false
        if DFP.Finder and type(DFP.Finder.QuickPledgeUpdate) == "function" then
            DFP.Finder:QuickPledgeUpdate()
        elseif DFP.Finder and type(DFP.Finder.RebuildAndRefresh) == "function" then
            DFP.Finder:RebuildAndRefresh()
        end
    end, 50)
end

-- ──────────────────────────────────────────────────────────────
-- Quest-Status
-- ──────────────────────────────────────────────────────────────
local function IsTurnInCondition(conditionType)
    return conditionType == QUEST_CONDITION_TYPE_GOTO_POINT
        or conditionType == QUEST_CONDITION_TYPE_TALK_TO
end

local function IsQuestReadyToTurnIn(journalIndex)
    if not journalIndex then return false end

    -- Fall 1: ESO signalisiert direkt Abschluss (z. B. direkt beim NPC-Dialog)
    if type(GetJournalQuestIsComplete) == "function" and GetJournalQuestIsComplete(journalIndex) then
        return true
    end

    -- Fall 2: Main Step prüfen
    if type(GetJournalQuestStepInfo) == "function" and type(GetJournalQuestConditionInfo) == "function" then
        local _, _, _, _, conditionCount = GetJournalQuestStepInfo(journalIndex, QUEST_MAIN_STEP_INDEX)
        local hasTurnInCondition = false

        for conditionIndex = 1, (conditionCount or 0) do
            local _, _, _, isFailCondition, isComplete, _, isVisible, conditionType =
                GetJournalQuestConditionInfo(journalIndex, QUEST_MAIN_STEP_INDEX, conditionIndex)

            -- Wenn noch Bedingungen offen sind:
            if isVisible and not isFailCondition and not isComplete then
                if IsTurnInCondition(conditionType) then
                    hasTurnInCondition = true
                else
                    -- Es gibt noch mindestens ein unvollständiges Kampf-/Dungeon-Ziel!
                    -- Daher zwingend noch NICHT fertig -> Gelb
                    return false
                end
            end
        end

        return hasTurnInCondition
    end

    return false
end

-- ──────────────────────────────────────────────────────────────
-- Mehrsprachige Prüfung: Ist eine Quest ein Gelöbnis?
-- ──────────────────────────────────────────────────────────────
local MULTILANG_PLEDGE_KEYWORDS = {
    "gelobnis", "geloebnis", "gelöbnis", -- DE
    "pledge",                            -- EN
    "serment",                           -- FR
    "juramento",                         -- ES
    "обет",                              -- RU
    "誓い",                              -- JP
    "誓约", "誓約"                       -- ZH
}

local function IsJournalQuestPledge(journalIndex, questName)
    if _G.QUEST_TYPE_UNDAUNTED_PLEDGE and type(GetJournalQuestType) == "function" then
        if GetJournalQuestType(journalIndex) == QUEST_TYPE_UNDAUNTED_PLEDGE then
            return true
        end
    end

    local low = norm(questName)
    for _, kw in ipairs(MULTILANG_PLEDGE_KEYWORDS) do
        if low:find(kw, 1, true) then
            return true
        end
    end
    return false
end

-- ──────────────────────────────────────────────────────────────
-- LibUndauntedPledges abfragen
-- ──────────────────────────────────────────────────────────────
local function GetTodayPledgesFromLib()
    local lib = rawget(_G, "LibUndauntedPledges")
    if not lib or type(lib.GetPledges) ~= "function" then
        return nil
    end

    local todayData = nil
    pcall(function()
        todayData = lib.GetPledges()
    end)

    if type(todayData) ~= "table" then return nil end

    local acts = {}
    local zones = {}

    for _, pgId in ipairs({ lib.BASE1 or 1, lib.BASE2 or 2, lib.DLC1 or 3 }) do
        local p = todayData[pgId]
        if type(p) == "table" then
            if p.activityIdN and p.activityIdN > 0 then acts[p.activityIdN] = true end
            if p.activityIdV and p.activityIdV > 0 then acts[p.activityIdV] = true end
            if p.zoneId and p.zoneId > 0 then zones[p.zoneId] = true end
        end
    end

    return { acts = acts, zones = zones }
end

-- ──────────────────────────────────────────────────────────────
-- Journal scannen & Status ermitteln
-- ──────────────────────────────────────────────────────────────
function DFP.Pledges:ScanJournal()
    CheckDayRollover()

    if not self.activityList or #self.activityList == 0 then
        self:BuildCatalog()
    end

    local pledges    = {}
    local states     = {}
    local activeActs = {}
    local used       = {}
    local maxQuests  = _G.MAX_JOURNAL_QUESTS or 25

    -- 1. Quests im Tagebuch prüfen (Gelb oder Grün)
    for qi = 1, maxQuests do
        local qName = type(GetJournalQuestName) == "function" and GetJournalQuestName(qi) or ""
        if qName ~= "" and IsJournalQuestPledge(qi, qName) then
            local cleanQuest = CleanKey(qName)
            local isComplete = IsQuestReadyToTurnIn(qi)
            local qState     = isComplete and DFP.PLEDGE_STATE_COMPLETED or DFP.PLEDGE_STATE_ACCEPTED

            for _, act in ipairs(self.activityList) do
                if not used[act.cleanKey] then
                    if cleanQuest:find(act.cleanKey, 1, true) then
                        pledges[act.normKey]  = true
                        pledges[act.cleanKey] = true
                        if act.name then pledges[act.name:lower()] = true end

                        states[act.cleanKey] = qState
                        states[act.normKey]  = qState
                        if act.name then states[act.name:lower()] = qState end

                        if act.activityId then activeActs[act.activityId] = qState end

                        used[act.cleanKey] = true
                        break
                    end
                end
            end
        end
    end

    -- 2. Heutige Gelöbnisse via LibUndauntedPledges (Blau)
    -- WICHTIG: Nicht blau färben, wenn die Quest bereits im Tagebuch ist ODER heute bereits abgegeben wurde!
    local lupData = GetTodayPledgesFromLib()
    if lupData and lupData.acts then
        for actId, _ in pairs(lupData.acts) do
            local name = SafeActivityInfo(actId)
            local cKey = name and CleanKey(name) or ""
            local isTurnedIn = self.turnedToday[actId] or (cKey ~= "" and self.turnedToday[cKey])

            if not isTurnedIn then
                if not activeActs[actId] then
                    activeActs[actId] = DFP.PLEDGE_STATE_AVAILABLE
                end

                if name and name ~= "" then
                    local nKey = norm(name)
                    if not states[cKey] then
                        states[cKey] = DFP.PLEDGE_STATE_AVAILABLE
                        states[nKey] = DFP.PLEDGE_STATE_AVAILABLE
                        states[name:lower()] = DFP.PLEDGE_STATE_AVAILABLE

                        pledges[nKey] = true
                        pledges[cKey] = true
                        pledges[name:lower()] = true
                    end
                end
            end
        end

        if lupData.zones and GetActivityZoneId then
            for _, act in ipairs(self.activityList) do
                local isTurnedIn = self.turnedToday[act.cleanKey] or (act.activityId and self.turnedToday[act.activityId])
                if not isTurnedIn and act.activityId and not activeActs[act.activityId] then
                    local zoneId = GetActivityZoneId(act.activityId)
                    if zoneId and lupData.zones[zoneId] then
                        activeActs[act.activityId] = DFP.PLEDGE_STATE_AVAILABLE
                        if not states[act.cleanKey] then
                            states[act.cleanKey] = DFP.PLEDGE_STATE_AVAILABLE
                            states[act.normKey]  = DFP.PLEDGE_STATE_AVAILABLE
                            pledges[act.cleanKey] = true
                            pledges[act.normKey]  = true
                        end
                    end
                end
            end
        end
    end

    self.active           = pledges
    self.states           = states
    self.activeActivities = activeActs

    ScheduleUIRefresh()
end

-- ──────────────────────────────────────────────────────────────
-- Status-Getter für Finder.lua
-- ──────────────────────────────────────────────────────────────
function DFP.Pledges:GetState(dungeonKey, dungeonName, actN, actV)
    if self.activeActivities then
        if actN and self.activeActivities[actN] then return self.activeActivities[actN] end
        if actV and self.activeActivities[actV] then return self.activeActivities[actV] end
    end

    if self.states then
        if dungeonKey then
            local cKey = CleanKey(dungeonKey)
            if self.states[cKey] then return self.states[cKey] end
            local nKey = norm(dungeonKey)
            if self.states[nKey] then return self.states[nKey] end
        end

        if dungeonName then
            local cName = CleanKey(dungeonName)
            if self.states[cName] then return self.states[cName] end
            local low = dungeonName:lower()
            if self.states[low] then return self.states[low] end
        end
    end

    return DFP.PLEDGE_STATE_NONE
end

-- ──────────────────────────────────────────────────────────────
-- Auto-Accept / Turn-in Dialog Flow
-- ──────────────────────────────────────────────────────────────
local function IsPledgeMasterTarget()
    local targetName = norm(GetUnitName("interact") or "")
    if targetName == "" then return false end

    local lib = rawget(_G, "LibUndauntedPledges")
    if lib and type(lib.GetPledgeGiverName) == "function" then
        for _, pgId in ipairs({ lib.BASE1 or 1, lib.BASE2 or 2, lib.DLC1 or 3 }) do
            local gName = norm(lib.GetPledgeGiverName(pgId))
            if gName ~= "" and (targetName:find(gName, 1, true) or gName:find(targetName, 1, true)) then
                return true
            end
        end
    end

    local fallbackNames = { "maj", "glirion", "urgarlag", "мадж", "глирион", "ургарлаг", "玛吉", "格利里恩", "乌尔加拉格", "マジ", "グリリオン", "ウルガルラグ" }
    for _, fn in ipairs(fallbackNames) do
        if targetName:find(fn, 1, true) then
            return true
        end
    end

    return false
end

local function CloseChatterGracefully(ms)
    zo_callLater(function()
        if type(GetInteractionType) == "function" and type(EndInteraction) == "function" then
            if GetInteractionType() == INTERACTION_CONVERSATION then
                EndInteraction(INTERACTION_CONVERSATION)
            end
        elseif type(CloseChatter) == "function" then
            CloseChatter()
        end
    end, ms or 150)
end

-- 1. Quest anbieten -> Sofort annehmen
local function OnQuestOffered()
    if not (DFP.sv and DFP.sv.autoPledge and DFP.sv.autoPledge.enabled) then return end
    if not IsPledgeMasterTarget() then return end

    if type(AcceptOfferedQuest) == "function" then
        AcceptOfferedQuest()
    end
end

-- 2. Quest-Belohnungsdialog -> Sofort abschließen
local function OnQuestCompleteDialog()
    if not (DFP.sv and DFP.sv.autoPledge and DFP.sv.autoPledge.enabled) then return end
    if not IsPledgeMasterTarget() then return end

    if type(CompleteQuest) == "function" then
        CompleteQuest()
    end
end

-- 3. Nach Questannahme oder Abgabe -> Fenster schließen
local function OnQuestFinished(eventCode, questIndex, questName)
    if questName and questName ~= "" and DFP.Pledges and DFP.Pledges.MarkPledgeTurnedIn then
        DFP.Pledges:MarkPledgeTurnedIn(questName)
    end

    if not (DFP.sv and DFP.sv.autoPledge and DFP.sv.autoPledge.enabled) then return end
    if not IsPledgeMasterTarget() then return end

    CloseChatterGracefully(150)
end

-- 4. Dialogoptionen durchklicken
local function ProcessChatter()
    if not (DFP.sv and DFP.sv.autoPledge and DFP.sv.autoPledge.enabled) then return end
    if not IsPledgeMasterTarget() then return end
    if type(GetChatterOptionCount) ~= "function" or type(GetChatterOption) ~= "function" or type(SelectChatterOption) ~= "function" then return end

    local count = GetChatterOptionCount()
    if count == 0 then return end

    -- Zuerst nach Abgabe-Option suchen
    for i = 1, count do
        local _, optionType = GetChatterOption(i)
        if optionType == CHATTER_COMPLETE_QUEST or (_G.CHATTER_START_ADVANCE_COMPLETION and optionType == CHATTER_START_ADVANCE_COMPLETION) then
            SelectChatterOption(i)
            return
        end
    end

    -- Danach nach Neuer Quest / Weiterreden suchen
    for i = 1, count do
        local _, optionType = GetChatterOption(i)
        if optionType == CHATTER_START_NEW_QUEST_BESTOWAL or optionType == CHATTER_START_TALK or optionType == CHATTER_TALK_CHOICE then
            SelectChatterOption(i)
            return
        end
    end
end

if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_Chatter",   EVENT_CHATTER_BEGIN,           ProcessChatter)
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_Updated",   EVENT_CONVERSATION_UPDATED,    ProcessChatter)
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_Offered",   EVENT_QUEST_OFFERED,           OnQuestOffered)
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_CompDlg",   EVENT_QUEST_COMPLETE_DIALOG,   OnQuestCompleteDialog)
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_Completed", EVENT_QUEST_COMPLETE,          OnQuestFinished)
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_Added",     EVENT_QUEST_ADDED,             OnQuestFinished)
end

-- ──────────────────────────────────────────────────────────────
-- Events
-- ──────────────────────────────────────────────────────────────
local function DebouncedScan()
    if DFP._pledgeScanPending then return end
    DFP._pledgeScanPending = true
    zo_callLater(function()
        DFP._pledgeScanPending = false
        if DFP.Pledges and DFP.Pledges.ScanJournal then
            DFP.Pledges:ScanJournal()
        end
    end, 50)
end

function DFP.Pledges.RegisterEvents()
    if not EVENT_MANAGER then return end

    EVENT_MANAGER:RegisterForEvent("DFP_P_QAdded",     EVENT_QUEST_ADDED,              DebouncedScan)
    EVENT_MANAGER:RegisterForEvent("DFP_P_QRemoved",   EVENT_QUEST_REMOVED,            DebouncedScan)
    EVENT_MANAGER:RegisterForEvent("DFP_P_QCompleted", EVENT_QUEST_COMPLETE, function(e, qi, qName)
        if qName and qName ~= "" then
            MarkPledgeTurnedIn(qName)
        end
        DebouncedScan()
    end)

    if _G.EVENT_QUEST_ADVANCED then
        EVENT_MANAGER:RegisterForEvent("DFP_P_QAdvanced", EVENT_QUEST_ADVANCED, DebouncedScan)
    end
    if _G.EVENT_QUEST_CONDITION_COUNTER_CHANGED then
        EVENT_MANAGER:RegisterForEvent("DFP_P_QCondition", EVENT_QUEST_CONDITION_COUNTER_CHANGED, DebouncedScan)
    end

    EVENT_MANAGER:RegisterForEvent("DFP_P_PlayerInit", EVENT_PLAYER_ACTIVATED, function()
        DFP.Pledges:BuildCatalog()
        CheckDayRollover()
        DebouncedScan()
    end)
end

function DFP.Pledges.UnregisterEvents()
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForEvent("DFP_P_QAdded",     EVENT_QUEST_ADDED)
    EVENT_MANAGER:UnregisterForEvent("DFP_P_QRemoved",   EVENT_QUEST_REMOVED)
    EVENT_MANAGER:UnregisterForEvent("DFP_P_QCompleted", EVENT_QUEST_COMPLETE)
    if _G.EVENT_QUEST_ADVANCED then
        EVENT_MANAGER:UnregisterForEvent("DFP_P_QAdvanced", EVENT_QUEST_ADVANCED)
    end
    if _G.EVENT_QUEST_CONDITION_COUNTER_CHANGED then
        EVENT_MANAGER:UnregisterForEvent("DFP_P_QCondition", EVENT_QUEST_CONDITION_COUNTER_CHANGED)
    end
    EVENT_MANAGER:UnregisterForEvent("DFP_P_PlayerInit", EVENT_PLAYER_ACTIVATED)
end