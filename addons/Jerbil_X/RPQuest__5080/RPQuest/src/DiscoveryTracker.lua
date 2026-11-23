-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.DiscoveryTracker = {}
local DiscoveryTracker = Addon.DiscoveryTracker

local UPDATE_NAME = "RPQuest_DiscoveryTracker_Update"
local LISTENER_ACTIVATED = "RPQuest_DiscoveryTracker_PlayerActivated"
local LISTENER_ZONE = "RPQuest_DiscoveryTracker_ZoneChanged"

function DiscoveryTracker:Initialize()
    if self.isInitialized then return end

    Addon.QuestRepository:RegisterListener(function()
        self:UpdatePollingState()
    end)

    EVENT_MANAGER:RegisterForEvent(LISTENER_ACTIVATED, EVENT_PLAYER_ACTIVATED, function()
        self:UpdatePollingState()
    end)
    EVENT_MANAGER:RegisterForEvent(LISTENER_ZONE, EVENT_ZONE_CHANGED, function()
        self:UpdatePollingState()
    end)

    self.isInitialized = true
    self:UpdatePollingState()
end

function DiscoveryTracker:UpdatePollingState()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    local shouldPoll = Addon.QuestRepository:HasPendingDiscoveries(activeQuest)
    self._isPolling = self._isPolling or false

    if shouldPoll and not self._isPolling then
        local interval = Addon.Constants.DISCOVERY_POLL_INTERVAL_MS or 750
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, interval, function()
            self:OnUpdateTick()
        end)
        self._isPolling = true
    elseif not shouldPoll and self._isPolling then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        self._isPolling = false
    end
end

function DiscoveryTracker:OnUpdateTick()
    if not self._isPolling then return end
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if not Addon.QuestRepository:HasPendingDiscoveries(activeQuest) then
        self:UpdatePollingState()
        return
    end
    local zoneId, worldX, worldY, worldZ = GetUnitWorldPosition("player")
    if zoneId and zoneId ~= 0 and worldX and worldZ then
        self:EvaluatePlayerPosition(zoneId, worldX, worldY or 0, worldZ, activeQuest)
    end
end

function DiscoveryTracker:EvaluatePlayerPosition(zoneId, worldX, _worldY, worldZ, preloadedQuest)
    local activeQuest = preloadedQuest or Addon.QuestRepository:GetActiveQuest()
    if not preloadedQuest and not Addon.QuestRepository:HasPendingDiscoveries(activeQuest) then
        self:UpdatePollingState()
        return false
    end
    if not activeQuest or activeQuest.completed or type(activeQuest.discoveries) ~= "table" then
        return false
    end

    local defaultRadius = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    local triggeredAny = false
    for idx, point in ipairs(activeQuest.discoveries) do
        if not point.discovered and point.worldX and point.worldZ then
            local zoneMatches = (point.zoneId == 0) or (zoneId == 0) or (point.zoneId == zoneId)
            if zoneMatches then
                local dx = worldX - point.worldX
                local dz = worldZ - point.worldZ
                local radius = point.radius or defaultRadius
                if ((dx * dx) + (dz * dz)) <= (radius * radius) then
                    local ok, quest, isCompleted, triggeredPoint = Addon.QuestRepository:MarkDiscoveryTriggered(activeQuest.id, idx)
                    if ok and triggeredPoint then
                        triggeredAny = true
                        Addon.Announcements:AnnounceDiscovery(quest, triggeredPoint)
                        if isCompleted then
                            Addon.Announcements:AnnounceQuestCompleted(quest)
                            break
                        end
                    end
                end
            end
        end
    end

    if triggeredAny then
        self:UpdatePollingState()
    end
    return triggeredAny
end
