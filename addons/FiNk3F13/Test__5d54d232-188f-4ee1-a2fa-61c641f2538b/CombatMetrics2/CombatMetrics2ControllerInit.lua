local A=CMX2
local original=A.InitializeUI
function A.InitializeUI()
    A.db.NotificationAllowed=false
    -- Recover full reports once for existing console-test installations that had
    -- enabled the formerly ambiguous light-mode switch. Later choices persist.
    if A.db.consoleRecordingRecovery~=1 then
        A.db.lightmode=false
        A.db.consoleRecordingRecovery=1
    end
    original()
    A.Controller.Initialize()
    if A.PrepareReport and not A.reportWarmupRegistered then
        A.reportWarmupRegistered=true
        local events=GetEventManager()
        local eventName="CMX2_ReportWarmup"
        events:RegisterForEvent(eventName,EVENT_PLAYER_ACTIVATED,function()
            events:UnregisterForEvent(eventName,EVENT_PLAYER_ACTIVATED)
            -- Let the loading screen and initial HUD settle before any work.
            zo_callLater(function() A.PrepareReport() end,2000)
        end)
    end
    for _,name in ipairs({"hud","hudui","siegeBar"}) do
        local sceneName=name
        local scene=SCENE_MANAGER:GetScene(sceneName)
        if scene then scene:RegisterCallback("StateChange",function(_,state)
            if state~=SCENE_SHOWN then return end
            zo_callLater(function()
                if not SCENE_MANAGER:IsShowing(sceneName) then return end
                CombatMetrics2_LiveReport:Refresh()
                CombatMetrics2_LiveReport:Toggle(A.db.liveReport.enabled)
                if A.UpdateEvents then A.UpdateEvents() end
                local data=A.currentdata
                if data and (tonumber(data.dpstime) or 0)<=0 and (tonumber(data.hpstime) or 0)<=0 then
                    data=A.lastfights and A.lastfights[#A.lastfights] or data
                end
                if data then CombatMetrics2_LiveReport:Update(data) end
            end,0)
        end) end
    end
end
