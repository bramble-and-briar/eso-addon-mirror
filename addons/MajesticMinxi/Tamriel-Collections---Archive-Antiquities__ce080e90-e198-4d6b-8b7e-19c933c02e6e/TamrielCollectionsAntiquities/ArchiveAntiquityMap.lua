-- Lead-source maps and explicitly labelled excavation fallback. No scans at load.
local TC=TamrielCollections
local Map={}
TC.antiquityMap=Map
local requestNumber,mapScreen=0,nil
local pinTag='TCA_ANTIQUITY_SOURCE'
local function Key(value)return TC.antiquityCatalogue.Key(value)end
local function Coordinates(x,y)return x and y and x>0 and x<1 and y>0 and y<1 end
local function HasSource(source)
    return source and (source.world or source.mapZoneId and source.mapZoneId>0
        or source.zones and #source.zones>0 or source.nodes and #source.nodes>0)
end
function Map.Label(part,source)
    if part and part.treasure then return 'Show zone'end
    return HasSource(source)and 'Show lead source' or 'Show excavation zone'
end
function Map.CanShow(part,source)
    return part and not part.parts and (HasSource(source)or part.zoneId and part.zoneId>0)or false
end
local function ZoneMap(zoneId)
    if not zoneId or zoneId<=0 then return end
    local mapId=GetMapIdByZoneId and GetMapIdByZoneId(zoneId)
    local index=GetMapIndexByZoneId and GetMapIndexByZoneId(zoneId)
    if mapId and mapId<=0 then mapId=nil end
    if index and index<=0 then index=nil end
    if mapId or index then return {mapId=mapId,mapIndex=index,
        zoneIndex=GetZoneIndex and GetZoneIndex(zoneId)}end
end
local function Resolve(part,source,preferred)
    if not HasSource(source)then return ZoneMap(part.zoneId)end
    local specific=source.targetsByZone and source.targetsByZone[preferred]
    if specific then
        local target={}
        for key,value in pairs(specific)do target[key]=value end
        return target
    end
    -- The Earth Forge has a native instance map, but its access portals are
    -- in normal map zones. Keep those regions in the zone chooser; show the
    -- actual instance on the map when its native map is available.
    if source.mapZoneId then
        local target=ZoneMap(source.mapZoneId)
        if target then return target end
    end
    -- Fixed-object lead coordinates belong to their native zone map.
    if Coordinates(source.x,source.y)then
        local target=ZoneMap(source.zones and source.zones[1])
        if target then target.x,target.y=source.x,source.y;return target end
    end
    local preferredSource=false
    for _,id in ipairs(source.zones or {})do if id==preferred then preferredSource=true;break end end
    if source.nodes and GetNumFastTravelNodes and GetFastTravelNodeInfo and GetFastTravelNodePOIIndicies then
        for _,name in ipairs(source.nodes)do
            for node=1,GetNumFastTravelNodes()do
                local _,nodeName=GetFastTravelNodeInfo(node)
                if Key(nodeName)==Key(name)then
                    local zoneIndex,poiIndex=GetFastTravelNodePOIIndicies(node)
                    local zoneId=zoneIndex and GetZoneId and GetZoneId(zoneIndex)
                    local target=(not preferredSource or zoneId==preferred)and ZoneMap(zoneId)
                    if target then target.nodeIndex,target.poiIndex=node,poiIndex;return target end
                end
            end
        end
    end
    if source.world then
        for index=1,GetNumMaps and GetNumMaps()or 0 do
            local name=GetMapNameByIndex and GetMapNameByIndex(index)
            if Key(name)=='tamriel'then return {mapIndex=index,mapId=GetMapIdByIndex and GetMapIdByIndex(index)}end
        end
        return
    end
    local zone=source.zones and source.zones[1]
    for _,id in ipairs(source.zones or {})do if id==preferred then zone=id;break end end
    local target=ZoneMap(zone)
    if not target then return end
    if source.poi and target.zoneIndex and GetNumPOIs and GetPOIInfo then
        for poi=1,GetNumPOIs(target.zoneIndex)do
            local name=Key(GetPOIInfo(target.zoneIndex,poi))
            for _,candidate in ipairs(source.poi)do
                if name==Key(candidate)then target.poiIndex=poi;return target end
            end
        end
    end
    return target
end
local function Clear()
    requestNumber=requestNumber+1
    local manager=ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
    if manager then manager:RemovePins('pings',MAP_PIN_TYPE_QUEST_PING,pinTag)end
end
local function Alert(message)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ERROR,SOUNDS and SOUNDS.NEGATIVE_CLICK,message)end
end
function Map.Show(screen,part,source,preferred)
    if not Map.CanShow(part,source)or not WORLD_MAP_MANAGER or not ZO_WorldMap_ShowWorldMap then return end
    if WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed()then return end
    local target=Resolve(part,source,preferred)
    if not target then Alert('This antiquity map is not available.');return end
    local index=target.mapIndex or (GetMapIndexById and target.mapId and GetMapIndexById(target.mapId))
    if index and index<=0 then index=nil end
    if not(target.mapId and WORLD_MAP_MANAGER.SetMapById)and not(index and WORLD_MAP_MANAGER.SetMapByIndex)then return end
    Clear();local request=requestNumber;mapScreen=screen
    if not Map.travelHook and ZO_PreHook and type(FastTravelToNode)=='function'then
        Map.travelHook=true
        ZO_PreHook('FastTravelToNode',function()
            local owner=mapScreen
            if owner and owner.activeModuleId=='antiquities'and owner._tcaMapReturn then
                owner._tcaMapReturn=nil;owner.returnToMotifsAfterMap,owner.resumeMotifsAfterMap=false,false
                Clear()
                if SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER.ShowBaseScene
                    and SCENE_MANAGER:IsShowing('tamrielCollectionsGamepad')then SCENE_MANAGER:ShowBaseScene()end
            end
        end)
    end
    if GAMEPAD_WORLD_MAP_SCENE and not Map.returnCallback then
        Map.returnCallback=true
        GAMEPAD_WORLD_MAP_SCENE:RegisterCallback('StateChange',function(_,state)if state==SCENE_HIDDEN then Clear()end end)
    end
    screen._tcaMapReturn={mode=screen.mode,level=screen._tcaLevel,family=screen._tcaFamily,parent=screen._tcaParent,item=screen._tcaItem}
    screen.returnToMotifsAfterMap=true;screen.returnMotifSelectedIndex=screen.styleList:GetSelectedIndex()
    ZO_WorldMap_ShowWorldMap()
    if target.mapId and WORLD_MAP_MANAGER.SetMapById then WORLD_MAP_MANAGER:SetMapById(target.mapId)
    else WORLD_MAP_MANAGER:SetMapByIndex(index)end
    if not(target.nodeIndex or target.poiIndex or Coordinates(target.x,target.y))then return end
    local attempts=0
    local function Place()
        if request~=requestNumber then return end
        attempts=attempts+1
        local correct=target.mapId and GetCurrentMapId and GetCurrentMapId()==target.mapId
            or not target.mapId and GetCurrentMapIndex and GetCurrentMapIndex()==index
        local x,y
        if correct then
            if target.nodeIndex and GetFastTravelNodeInfo then
                local _,_,px,py,_,_,_,shown=GetFastTravelNodeInfo(target.nodeIndex)
                if shown and Coordinates(px,py)then x,y=px,py end
            end
            if not Coordinates(x,y)and target.poiIndex and GetPOIMapInfo then
                local px,py,_,_,shown=GetPOIMapInfo(target.zoneIndex,target.poiIndex)
                if shown and Coordinates(px,py)then x,y=px,py end
            end
            if not Coordinates(x,y)and Coordinates(target.x,target.y)then x,y=target.x,target.y end
        end
        if not Coordinates(x,y)then
            if attempts<20 and zo_callLater then zo_callLater(Place,50)end
            return
        end
        local manager=ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
        local pan=ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom()
        if not(manager and pan)then return end
        manager:RemovePins('pings',MAP_PIN_TYPE_QUEST_PING,pinTag)
        local pin=manager:CreatePin(MAP_PIN_TYPE_QUEST_PING,pinTag,x,y)
        if pin then pan:JumpToPin(pin)end
    end
    if zo_callLater then zo_callLater(Place,150)end
end
