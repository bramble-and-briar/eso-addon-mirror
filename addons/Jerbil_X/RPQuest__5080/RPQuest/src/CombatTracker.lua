-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.CombatTracker = {}
local CombatTracker = Addon.CombatTracker

local LISTENER_DIED = "RPQuest_CombatTracker_Died"
local LISTENER_DIED_XP = "RPQuest_CombatTracker_DiedXP"
local LISTENER_JUSTICE_BOUNTY = "RPQuest_Justice_Bounty"
local LISTENER_JUSTICE_INFAMY = "RPQuest_Justice_Infamy"
local LISTENER_JUSTICE_PICKPOCKET = "RPQuest_Justice_Pickpocket"
local MAX_RECENT_KILLED_UNITS = 32

local function IsAllowedKillSource(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_COMPANION
end

local function RegisterDeathFilter(listenerName, expectedResult, callback)
    EVENT_MANAGER:UnregisterForEvent(listenerName, EVENT_COMBAT_EVENT)
    if not expectedResult then return end
    EVENT_MANAGER:RegisterForEvent(listenerName, EVENT_COMBAT_EVENT, callback)
    EVENT_MANAGER:AddFilterForEvent(listenerName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, expectedResult)
    EVENT_MANAGER:AddFilterForEvent(listenerName, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
end

function CombatTracker:UpdateJusticeRegistration(activeQuest)
    local modes = Addon.Constants.STEALTH_MODE
    local stealthMode = activeQuest and activeQuest.stealthMode
    local shouldTrack = (activeQuest ~= nil)
        and not activeQuest.completed
        and not activeQuest.failed
        and (stealthMode == modes.OPTIONAL or stealthMode == modes.REQUIRED)
        and not activeQuest.wasDetected

    if not shouldTrack then
        if self._isJusticeRegistered then
            EVENT_MANAGER:UnregisterForEvent(LISTENER_JUSTICE_BOUNTY, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED)
            EVENT_MANAGER:UnregisterForEvent(LISTENER_JUSTICE_INFAMY, EVENT_JUSTICE_INFAMY_UPDATED)
            EVENT_MANAGER:UnregisterForEvent(LISTENER_JUSTICE_PICKPOCKET, EVENT_JUSTICE_PICKPOCKET_FAILED)
            self._isJusticeRegistered = false
        end
        return
    end

    if self._isJusticeRegistered then return end

    self._bountyHandler = self._bountyHandler or function(eventCode, oldBounty, newBounty, isInitialize)
        self:OnJusticeBountyUpdated(eventCode, oldBounty, newBounty, isInitialize)
    end
    self._infamyHandler = self._infamyHandler or function(eventCode, oldInfamy, newInfamy, oldInfamyLevel, newInfamyLevel)
        self:OnJusticeInfamyUpdated(eventCode, oldInfamy, newInfamy, oldInfamyLevel, newInfamyLevel)
    end
    self._pickpocketHandler = self._pickpocketHandler or function(eventCode)
        self:OnJusticePickpocketFailed(eventCode)
    end

    EVENT_MANAGER:RegisterForEvent(LISTENER_JUSTICE_BOUNTY, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, self._bountyHandler)
    EVENT_MANAGER:RegisterForEvent(LISTENER_JUSTICE_INFAMY, EVENT_JUSTICE_INFAMY_UPDATED, self._infamyHandler)
    EVENT_MANAGER:RegisterForEvent(LISTENER_JUSTICE_PICKPOCKET, EVENT_JUSTICE_PICKPOCKET_FAILED, self._pickpocketHandler)
    self._isJusticeRegistered = true
end

function CombatTracker:UpdateRegistration()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    self:UpdateJusticeRegistration(activeQuest)

    local hasActiveQuest = (activeQuest ~= nil)
    if not hasActiveQuest then
        if self._isRegistered then
            EVENT_MANAGER:UnregisterForEvent(LISTENER_DIED, EVENT_COMBAT_EVENT)
            EVENT_MANAGER:UnregisterForEvent(LISTENER_DIED_XP, EVENT_COMBAT_EVENT)
            self._isRegistered = false
        end
        return
    end

    if self._isRegistered then return end

    self._combatHandler = self._combatHandler or function(...)
        self:OnCombatEvent(...)
    end
    RegisterDeathFilter(LISTENER_DIED, ACTION_RESULT_DIED, self._combatHandler)
    RegisterDeathFilter(LISTENER_DIED_XP, ACTION_RESULT_DIED_XP, self._combatHandler)
    self._isRegistered = true
end

function CombatTracker:Initialize()
    self._isRegistered = false
    self._isJusticeRegistered = false
    self._recentKilledOrder = {}
    self._recentKilledSet = {}
    self._recentKilledCursor = 0
    if not self._repoListenerAdded then
        Addon.QuestRepository:RegisterListener(function(eventType)
            if eventType ~= "DRAFT_UPDATED" and eventType ~= "DRAFT_TARGET_CAPTURED" and eventType ~= "QUEST_PROGRESS" then
                self:UpdateRegistration()
            end
        end)
        self._repoListenerAdded = true
    end

    self:UpdateRegistration()
end

function CombatTracker:MarkUnitKilled(targetUnitId)
    if not targetUnitId or targetUnitId <= 0 then return end
    self._recentKilledOrder = self._recentKilledOrder or {}
    self._recentKilledSet = self._recentKilledSet or {}
    if self._recentKilledSet[targetUnitId] then return end

    local cursor = ((self._recentKilledCursor or 0) % MAX_RECENT_KILLED_UNITS) + 1
    self._recentKilledCursor = cursor
    local evicted = self._recentKilledOrder[cursor]
    if evicted then
        self._recentKilledSet[evicted] = nil
    end
    self._recentKilledOrder[cursor] = targetUnitId
    self._recentKilledSet[targetUnitId] = true
end

local function GetAreaContextIfNeeded(quest)
    if not quest then return nil end
    local hasMapConstraint = (quest.mapId and quest.mapId > 0) or (quest.zoneId and quest.zoneId > 0)
    if not hasMapConstraint then
        return nil
    end
    return Addon.TargetCapture:GetPlayerMapContext(false, false)
end

function CombatTracker:OnCombatEvent(_eventCode, result, isError, _abilityName, _abilityGraphic,
                                     _abilityActionSlotType, _sourceName, sourceType, targetName,
                                     _targetType, _hitValue, _powerType, _damageType, _log,
                                     _sourceUnitId, targetUnitId, _abilityId)
    if isError then return end

    local isDeath = (result == ACTION_RESULT_DIED) or (result == ACTION_RESULT_DIED_XP)

    if not isDeath then
        return
    end

    if not IsAllowedKillSource(sourceType) then
        return
    end

    if targetUnitId and targetUnitId > 0 and self._recentKilledSet and self._recentKilledSet[targetUnitId] then
        return
    end

    local activeQuest, matchedTarget = Addon.QuestRepository:FindPendingTarget(targetName)
    if not activeQuest or not matchedTarget then
        return
    end

    local playerContext = nil
    if Addon.QuestRepository:HasTargetLocation(matchedTarget) then
        local pZone, pWorldX, _, pWorldZ = GetUnitWorldPosition("player")
        playerContext = {
            worldZoneId = pZone,
            worldX = pWorldX,
            worldZ = pWorldZ,
        }
    end

    local recorded, updatedQuest, justCompleted, finalTarget, questFailed, customMsgText = Addon.QuestRepository:RecordTargetEliminated(
        targetName, playerContext, activeQuest, matchedTarget
    )
    if questFailed and updatedQuest then
        self:MarkUnitKilled(targetUnitId)
        Addon.Announcements:AnnounceQuestFailed(updatedQuest, finalTarget, customMsgText)
        return
    end
    if not recorded or not updatedQuest then
        return
    end

    self:MarkUnitKilled(targetUnitId)

    if justCompleted then
        Addon.Announcements:AnnounceQuestCompleted(updatedQuest, finalTarget)
    else
        Addon.Announcements:AnnounceQuestProgress(updatedQuest, finalTarget)
    end
    if type(customMsgText) == "string" and customMsgText ~= "" then
        Addon.Announcements:AnnounceTargetCustomMessage(updatedQuest, finalTarget, customMsgText)
    end
end

function CombatTracker:HandleJusticeViolation()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    local modes = Addon.Constants.STEALTH_MODE
    if not activeQuest or activeQuest.completed or activeQuest.failed or activeQuest.wasDetected then
        return
    end
    if activeQuest.stealthMode ~= modes.OPTIONAL and activeQuest.stealthMode ~= modes.REQUIRED then
        return
    end
    local playerContext = GetAreaContextIfNeeded(activeQuest)
    local recorded, updatedQuest, questFailed = Addon.QuestRepository:RecordPlayerDetected(playerContext)
    if recorded and updatedQuest then
        if questFailed then
            Addon.Announcements:AnnounceQuestFailed(updatedQuest, nil, Addon.Locale:Get("ALERT_QUEST_FAILED_STEALTH"))
        else
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_STEALTH_DETECTED"), true)
        end
    end
end

function CombatTracker:OnJusticeBountyUpdated(_eventCode, oldBounty, newBounty, isInitialize)
    if isInitialize then return end
    if type(newBounty) ~= "number" or type(oldBounty) ~= "number" or newBounty <= oldBounty then
        return
    end
    self:HandleJusticeViolation()
end

function CombatTracker:OnJusticeInfamyUpdated(_eventCode, oldInfamy, newInfamy, _oldInfamyLevel, _newInfamyLevel)
    if type(newInfamy) ~= "number" or type(oldInfamy) ~= "number" or newInfamy <= oldInfamy then
        return
    end
    self:HandleJusticeViolation()
end

function CombatTracker:OnJusticePickpocketFailed(_eventCode)
    self:HandleJusticeViolation()
end
