local S=SurveySidekick
local math = math
local CALLBACK_MANAGER, SCENE_MANAGER, WORLD_MAP_MANAGER = CALLBACK_MANAGER, SCENE_MANAGER, WORLD_MAP_MANAGER
local SET_MAP_RESULT_FAILED = SET_MAP_RESULT_FAILED
local function Eligible(index)
    local known,name,x,y,_,_,kind,shown,locked=GetFastTravelNodeInfo(index)
    if known and not locked and shown and kind==POI_TYPE_WAYSHRINE and not GetFastTravelNodeOutboundOnlyInfo(index)
        and x>=0 and x<=1 and y>=0 and y<=1 then return name,x,y end
end
function S.ClosestShrine(loc)
    local oldMap,oldFloor=GetCurrentMapId(),GetMapFloorInfo()
    local changed=SetMapToMapId(loc.mapId)
    if changed==SET_MAP_RESULT_FAILED then return nil,"Could not open this survey's map." end
    local best,bestName,bestDistance
    local w,h=GetMapNumTiles();w,h=math.max(w,1),math.max(h,1)
    for i=1,GetNumFastTravelNodes() do
        local name,x,y=Eligible(i)
        if name then
            local distance=((x-loc.x)*w)^2+((y-loc.y)*h)^2
            if not bestDistance or distance<bestDistance then best,bestName,bestDistance=i,name,distance end
        end
    end
    SetMapToMapId(oldMap);if oldFloor>0 then SetMapFloor(oldFloor)end
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    return best,bestName
end
function S.Travel(preview)
    local entry=S.selected and S.inventory[S.selected]
    if not entry then S.Say("Select a survey in your backpack first.");return end
    local loc=S.locations[S.selected]
    if not loc then S.Say("Location unavailable. Install/update LibTreasure to enable survey travel.");return end
    if WORLD_MAP_MANAGER and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then S.Say("Close the current map interaction and try again.");return end
    local _,_,content=GetMapInfoById(loc.mapId)
    if content==MAP_CONTENT_AVA or content==MAP_CONTENT_BATTLEGROUND then S.Say("PvP travel networks are not supported.");return end
    local node,name=S.ClosestShrine(loc)
    if not node then S.Say(name or "No unlocked wayshrine is shown on the survey's map.");return end
    if preview then
        S.Say(entry.name.." -> "..name.." | Recall quote: "..GetRecallCost(node).." gold. Wayshrine-to-wayshrine travel is free.");return
    end
    if IsUnitDeadOrReincarnating("player") or IsUnitInCombat("player") then S.Say("You must be alive and out of combat to travel.");return end
    if IsPlayerInAvAWorld() or IsActiveWorldBattleground() or not CanLeaveCurrentLocationViaTeleport() then S.Say("Travel is unavailable from your current location.");return end
    S.Say("Travel requested: "..name..". Normal ESO travel costs apply. Use Map Pin after arriving.")
    FastTravelToNode(node)
end
function S.ShowMap()
    local loc=S.selected and S.locations[S.selected]
    if not loc then S.Say("Select a survey with a known location. LibTreasure supplies the coordinates.");return end
    if WORLD_MAP_MANAGER and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then S.Say("Close the current map interaction first.");return end
    if SetMapToMapId(loc.mapId)==SET_MAP_RESULT_FAILED then S.Say("Could not open the survey map.");return end
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT,MAP_TYPE_LOCATION_CENTERED,loc.x,loc.y)
    if IsInGamepadPreferredMode() then SCENE_MANAGER:Show("gamepad_worldMap")
    else SCENE_MANAGER:Show("worldMap") end
    S.Say("Waypoint placed for "..GetItemLinkName(S.Link(loc.id))..". This replaces your current waypoint.")
end
