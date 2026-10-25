-- PledgesQuest.lua – DungeonFinderPlus
DungeonFinderPlus = DungeonFinderPlus or {}
local DFP = DungeonFinderPlus

DFP.Pledges = DFP.Pledges or { active = {} }

-- ──────────────────────────────────────────────────────────────
-- Normalisierung 
-- ──────────────────────────────────────────────────────────────
local function foldLatin(s)
    if not s then return "" end
    return s
        :gsub("Ä","Ae"):gsub("Ö","Oe"):gsub("Ü","Ue")
        :gsub("ä","ae"):gsub("ö","oe"):gsub("ü","ue")
        :gsub("ß","ss")
end

local function norm(s)
    if not s then return "" end
    s = zo_strformat("<<C:1>>", s)
    s = foldLatin(s):lower()
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("[%p%s%c]+", " ")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end


local function CleanKey(text)
    local s = norm(text)
    return s:gsub("%s+", "")
end


local function CleanKeyWithoutFirstWord(text)
    local s = norm(text)
    local _, firstWordEnd = s:find("^%s*%S+")
    if not firstWordEnd then return "" end
    local alias = s:sub(firstWordEnd + 1):gsub("%s+", "")
    return #alias >= 6 and alias or ""
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
                        cleanKey = cKey,
                        aliasKey = CleanKeyWithoutFirstWord(name),
                        normKey  = norm(name), -- exakter Schlüssel für Finder.lua
                        name     = name,
                    }
                    self.catalog[cKey] = entry
                    self.activityList[#self.activityList + 1] = entry
                end
            end
        end
    end

    AddType(LFG_ACTIVITY_DUNGEON)
    AddType(LFG_ACTIVITY_MASTER_DUNGEON)

    -- Längere Namen zuerst prüfen (verhindert Teil-Treffer bei I vs II)
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
-- Journal scannen 
-- ──────────────────────────────────────────────────────────────
function DFP.Pledges:ScanJournal()
    if not self.activityList or #self.activityList == 0 then
        self:BuildCatalog()
    end

    local pledges = {}
    local used    = {}
    local maxQuests = _G.MAX_JOURNAL_QUESTS or 25

    for qi = 1, maxQuests do
        local qName = type(GetJournalQuestName) == "function" and GetJournalQuestName(qi) or ""
        if qName ~= "" then
            local isPledge = false
            if _G.QUEST_TYPE_UNDAUNTED_PLEDGE and type(GetJournalQuestType) == "function" then
                isPledge = (GetJournalQuestType(qi) == QUEST_TYPE_UNDAUNTED_PLEDGE)
            end

            if not isPledge then
                local low = qName:lower()
                if low:find("gelöbnis") or low:find("geloebnis") or low:find("pledge") or low:find("serment") then
                    isPledge = true
                end
            end

            if isPledge then
                local cleanQuest = CleanKey(qName)

                for _, act in ipairs(self.activityList) do
                    if not used[act.cleanKey] then
                        local isMatch = cleanQuest:find(act.cleanKey, 1, true)
                        if not isMatch and act.aliasKey ~= "" then
                            isMatch = cleanQuest:find(act.aliasKey, 1, true)
                        end

                        if isMatch then
                           
                            pledges[act.normKey]  = true
                            pledges[act.cleanKey] = true
                            if act.name then
                                pledges[act.name:lower()] = true
                            end

                            used[act.cleanKey] = true
                            break
                        end
                    end
                end
            end
        end
    end

    self.active = pledges
    ScheduleUIRefresh()
end

-- ──────────────────────────────────────────────────────────────
-- Auto-Accept / Turn-in Dialog Flow
-- ──────────────────────────────────────────────────────────────
local PLEDGE_MASTERS = {
    ["maj"]      = true, -- Maj al-Ragath
    ["glirion"]  = true, -- Glirion der Bartlose / the Beastmaster
    ["urgarlag"] = true, -- Urgarlag Häuptlingsfluch / Chief-bane
}

local function IsPledgeMasterTarget()
    local targetName = zo_strlower(GetUnitName("interact") or "")
    if targetName == "" then return false end
    for master, _ in pairs(PLEDGE_MASTERS) do
        if targetName:find(master, 1, true) then
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
    end, ms or 100)
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

-- 3. Nach Quest-Abschluss oder Annahme -> Fenster schließen
local function OnQuestFinished()
    if not (DFP.sv and DFP.sv.autoPledge and DFP.sv.autoPledge.enabled) then return end
    if not IsPledgeMasterTarget() then return end

    CloseChatterGracefully(120)
end

-- 4. Dialog analysieren und durchklicken
local function OnChatterBegin()
    if not (DFP.sv and DFP.sv.autoPledge and DFP.sv.autoPledge.enabled) then return end
    if not IsPledgeMasterTarget() then return end
    if type(GetChatterOptionCount) ~= "function" or type(GetChatterOption) ~= "function" or type(SelectChatterOption) ~= "function" then return end

    local count = GetChatterOptionCount()
    if count == 0 then return end

    local targetOption = nil

    -- Priorität: 1. Abgeben, 2. Neue Quest starten, 3. Weiter-Dialog
    for i = 1, count do
        local _, optionType = GetChatterOption(i)

        if optionType == CHATTER_COMPLETE_QUEST then
            targetOption = i
            break
        elseif optionType == CHATTER_START_NEW_QUEST_BESTOWAL and not targetOption then
            targetOption = i
        elseif (optionType == CHATTER_START_TALK or optionType == CHATTER_TALK_CHOICE) and not targetOption then
            -- Klickt automatische Begrüßungen ("Ich habe Neuigkeiten", etc.) weiter
            targetOption = i
        end
    end

    if targetOption then
        SelectChatterOption(targetOption)
    end
end

-- Events für den Dialog fest registrieren
if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent("DFP_AutoPledge_Chatter",   EVENT_CHATTER_BEGIN,           OnChatterBegin)
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
    EVENT_MANAGER:RegisterForEvent("DFP_P_QCompleted", EVENT_QUEST_COMPLETE,           DebouncedScan)

    if _G.EVENT_QUEST_ADVANCED then
        EVENT_MANAGER:RegisterForEvent("DFP_P_QAdvanced", EVENT_QUEST_ADVANCED, DebouncedScan)
    end
    if _G.EVENT_QUEST_CONDITION_COUNTER_CHANGED then
        EVENT_MANAGER:RegisterForEvent("DFP_P_QCondition", EVENT_QUEST_CONDITION_COUNTER_CHANGED, DebouncedScan)
    end

    EVENT_MANAGER:RegisterForEvent("DFP_P_PlayerInit", EVENT_PLAYER_ACTIVATED, function()
        DFP.Pledges:BuildCatalog()
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