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
    for _,name in ipairs({"hud","hudui","siegeBar"}) do
        local scene=SCENE_MANAGER:GetScene(name)
        if scene then scene:RegisterCallback("StateChange",function(_,state)
            if state~=SCENE_SHOWN then return end
            if A.UpdateEvents then A.UpdateEvents() end
            local data=A.currentdata
            if data and (tonumber(data.dpstime) or 0)<=0 and (tonumber(data.hpstime) or 0)<=0 then
                data=A.lastfights and A.lastfights[#A.lastfights] or data
            end
            if data then CombatMetrics2_LiveReport:Update(data) end
        end) end
    end
end
