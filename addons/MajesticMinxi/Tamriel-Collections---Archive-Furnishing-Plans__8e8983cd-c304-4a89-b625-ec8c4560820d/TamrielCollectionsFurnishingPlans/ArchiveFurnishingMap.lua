-- Furnishing acquisition map routes. No map scans or game API calls at load.
local TC=TamrielCollections
local Map={}
TC.furnishingPlanMap=Map
local destinations={
    rolis={merchant='Rolis Hlaalu'},faustina={merchant='Faustina Curio'},
    carpenter={mapId=205,x=.7352361083,y=.6263480783,names={'Byla Drethan'}},
    blacksmith={mapId=205,x=.719827652,y=.661062479,names={'Am-Eepa'}},
    clothier={mapId=205,x=.7116211057,y=.6566445231,names={'Felariel'}},
    chef={mapId=205,x=.4300083518,y=.436653465,names={'Chef Freki'}},
    grocer={mapId=205,x=.41482988,y=.4345231652,names={'Llurour Dres'}},
    nalirsewen={mapId=1429,x=.6420033574,y=.3056214452,names={'Nalirsewen'}},
    filer={mapId=2407,x=.7470588088,y=.480392158,names={'Filer Ool'}},
    archive={mapId=2407,zoneOnly=true},world={maps={'Tamriel'},zoneOnly=true},
    ['gold-coast']={maps={'Gold Coast'},zoneOnly=true},
    ['hews-bane']={maps={"Hew's Bane"},zoneOnly=true},
    stormhaven={maps={'Stormhaven'},zoneOnly=true},wrothgar={maps={'Wrothgar'},zoneOnly=true},
    grahtwood={maps={'Grahtwood'},zoneOnly=true},apocrypha={maps={'Apocrypha'},zoneOnly=true},
    solstice={maps={'Solstice','Western Solstice'},zoneOnly=true},
    ['west-weald']={maps={'West Weald'},zoneOnly=true},
    vvardenfell={maps={'Vvardenfell'},zoneOnly=true},
    ['western-skyrim']={maps={'Western Skyrim'},zoneOnly=true},
    blackreach={maps={'Blackreach: Greymoor Caverns','Blackreach','Western Skyrim'},zoneOnly=true},
    solitude={maps={'Solitude','Western Skyrim'},zoneOnly=true},
    reach={maps={'The Reach','Markarth'},zoneOnly=true},
    blackwood={maps={'Blackwood'},zoneOnly=true},fargrave={maps={'Fargrave','Fargrave City District','Deadlands'},zoneOnly=true},
    ['high-isle']={maps={'High Isle','High Isle and Amenos'},zoneOnly=true},
    galen={maps={'Galen','Galen and Y\'ffelon'},zoneOnly=true},
    telvanni={maps={'Telvanni Peninsula'},zoneOnly=true},summerset={maps={'Summerset'},zoneOnly=true},
    deadlands={maps={'Deadlands','The Deadlands'},zoneOnly=true},
    glenumbra={maps={'Glenumbra'},zoneOnly=true},clockwork={maps={'Clockwork City'},zoneOnly=true},
    murkmire={maps={'Murkmire'},zoneOnly=true},elsweyr={maps={'Northern Elsweyr','Elsweyr'},zoneOnly=true},
    coldharbour={maps={'Coldharbour'},zoneOnly=true},
    moongrave={nodes={'Moongrave Fane','Lair of Maarselok'},maps={'Northern Elsweyr','Elsweyr'}},
    maarselok={nodes={'Lair of Maarselok'},maps={'Grahtwood'}},
    ['moon-hunter']={nodes={'Moon Hunter Keep','March of Sacrifices'},maps={'Reaper\'s March','Greenshade'}},
    ['fang-lair']={nodes={'Fang Lair','Scalecaller Peak'},maps={'Bangkorai','Stormhaven'}},
    nymic={maps={'Telvanni Peninsula'},poi={'Bastion Nymic'}},
    vale={maps={'Solstice','Eastern Solstice'},poi={'Vale of Revelry'}},
    dismantler={maps={'Blackreach: Greymoor Caverns','Blackreach'},poi={"Dismantler's Ruin"}},
    darano={maps={"Abah's Landing","Hew's Bane"},names={'House Darano','Darano House'}},
    tribute={maps={'Gonfalon Bay','High Isle','High Isle and Amenos'},names={'Gonfalon Gaming Hall','Tales of Tribute'}},
}
local mapCache={}
local function Key(value)
    value=zo_strformat and zo_strformat(value or '') or tostring(value or '')
    return string.lower(value):gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('%^.*',''):gsub('’',"'")
end
local function Coordinates(x,y)return x and y and x>0 and x<1 and y>0 and y<1 end
local function Copy(data)local result={};for key,value in pairs(data)do result[key]=value end;return result end
local function MapForZone(zoneIndex)
    local zoneId=zoneIndex and GetZoneId and GetZoneId(zoneIndex)
    if not zoneId then return end
    local mapId=GetMapIdByZoneId and GetMapIdByZoneId(zoneId)
    local mapIndex=GetMapIndexByZoneId and GetMapIndexByZoneId(zoneId)
    if mapId and mapId<=0 then mapId=nil end
    if mapIndex and mapIndex<=0 then mapIndex=nil end
    if mapId or mapIndex then return {mapId=mapId,mapIndex=mapIndex,zoneIndex=zoneIndex} end
end
local function NamedMap(names)
    for _,name in ipairs(names or {})do
        local wanted=Key(name)
        if mapCache[wanted] then return Copy(mapCache[wanted]) end
        local highest=GetCurrentMapId and GetCurrentMapId() or 0
        for index=1,GetNumMaps and GetNumMaps() or 0 do
            local id=GetMapIdByIndex and GetMapIdByIndex(index)
            highest=math.max(highest,id or 0)
            local mapName=GetMapNameByIndex and GetMapNameByIndex(index)
            if not mapName and GetMapInfoByIndex then mapName=GetMapInfoByIndex(index)end
            if Key(mapName)==wanted then
                local target={mapId=id,mapIndex=index}
                mapCache[wanted]=target;return Copy(target)
            end
        end
        -- A city may have a map ID without belonging to the zone-map list.
        -- Keep only the selected result, rather than building a large map DB.
        for id=1,highest do
            local mapName=GetMapNameById and GetMapNameById(id)
            if not mapName and GetMapInfoById then mapName=GetMapInfoById(id)end
            if Key(mapName)==wanted then
                local target={mapId=id};mapCache[wanted]=target;return Copy(target)
            end
        end
        for index=1,GetNumZones and GetNumZones() or 0 do
            if GetZoneNameByIndex and Key(GetZoneNameByIndex(index))==wanted then
                local target=MapForZone(index)
                if target then mapCache[wanted]=target;return Copy(target)end
            end
        end
    end
end
local function MasterMerchant(name)
    local alliance=GetUnitAlliance and GetUnitAlliance('player')
    local target={mapId=205,x=.7330694795,y=.7467228174,names={name}}
    if alliance and ALLIANCE_ALDMERI_DOMINION and alliance==ALLIANCE_ALDMERI_DOMINION then
        target.mapId=445
        if name=='Rolis Hlaalu' then target.x,target.y=.7270160317,.6399757266
        else target.x,target.y=.7292988896,.6426149011 end
    elseif alliance and ALLIANCE_DAGGERFALL_COVENANT and alliance==ALLIANCE_DAGGERFALL_COVENANT then
        if name=='Rolis Hlaalu' then target.mapId,target.x,target.y=33,.7799844146,.2364572585
        else target.mapId,target.x,target.y=12,.6164457202,.5481200218 end
    end
    return target
end
local function Resolve(source)
    local record=source and destinations[source.map]
    if not record then return end
    if record.merchant then return MasterMerchant(record.merchant)end
    if record.mapId then return Copy(record)end
    if record.nodes and GetNumFastTravelNodes and GetFastTravelNodePOIIndicies and GetFastTravelNodeInfo then
        for _,name in ipairs(record.nodes)do
            for node=1,GetNumFastTravelNodes()do
                local _,nodeName=GetFastTravelNodeInfo(node)
                if Key(nodeName)==Key(name) then
                    local zoneIndex,poiIndex=GetFastTravelNodePOIIndicies(node)
                    local target=MapForZone(zoneIndex)
                    if target then target.nodeIndex,target.poiIndex=node,poiIndex;return target end
                end
            end
        end
    end
    local target=NamedMap(record.maps)
    if not target then return end
    target.names,target.zoneOnly=record.names,record.zoneOnly
    if record.poi and GetNumZones and GetZoneNameByIndex and GetNumPOIs and GetPOIInfo then
        for zone=1,GetNumZones()do
            local zoneName=Key(GetZoneNameByIndex(zone))
            local matches=false
            for _,name in ipairs(record.maps)do if zoneName==Key(name)then matches=true;break end end
            if matches then
                for poi=1,GetNumPOIs(zone)do
                    local name=Key(GetPOIInfo(zone,poi))
                    for _,candidate in ipairs(record.poi)do
                        if name==Key(candidate)then target.zoneIndex,target.poiIndex=zone,poi;return target end
                    end
                end
            end
        end
    end
    -- A broad source or a named activity without a native entrance pin still
    -- has a correct source-region map, without an invented coordinate.
    if not target.names then target.zoneOnly=true end
    return target
end
local function LocationCoordinates(names)
    if not (names and GetNumMapLocations and GetMapLocationTooltipHeader and GetMapLocationIcon)then return end
    local wanted={};for _,name in ipairs(names)do wanted[Key(name)]=true end
    for index=1,GetNumMapLocations()do
        local matches=wanted[Key(GetMapLocationTooltipHeader(index))]
        if not matches and GetNumMapLocationTooltipLines and GetMapLocationTooltipLineInfo then
            for line=1,GetNumMapLocationTooltipLines(index)do
                local _,name=GetMapLocationTooltipLineInfo(index,line)
                if wanted[Key(name)]then matches=true;break end
            end
        end
        if matches then
            local _,x,y=GetMapLocationIcon(index)
            if Coordinates(x,y)then return x,y end
        end
    end
end
local requestNumber=0
local pinTag='TCF_FURNISHING_SOURCE'
local mapScreen
local function Clear()
    requestNumber=requestNumber+1
    local manager=ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
    if manager then manager:RemovePins('pings',MAP_PIN_TYPE_QUEST_PING,pinTag)end
end
local function Alert(message)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ERROR,SOUNDS and SOUNDS.NEGATIVE_CLICK,message)end
end
function Map.CanShow(source)return source and destinations[source.map]~=nil or false end
function Map.Show(screen,source)
    if not Map.CanShow(source) or not WORLD_MAP_MANAGER or not ZO_WorldMap_ShowWorldMap then return end
    if WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed()then return end
    local target=Resolve(source)
    if not target or not (target.mapId or target.mapIndex)then
        Alert('The furnishing source map is not available.');return
    end
    local index=target.mapIndex or (GetMapIndexById and target.mapId and GetMapIndexById(target.mapId))
    if index and index<=0 then index=nil end
    if not (target.mapId and WORLD_MAP_MANAGER.SetMapById)and not (index and WORLD_MAP_MANAGER.SetMapByIndex)then return end
    Clear()
    local request=requestNumber
    mapScreen=screen
    if not Map.travelHook and ZO_PreHook and type(FastTravelToNode)=='function' then
        Map.travelHook=true
        ZO_PreHook('FastTravelToNode',function()
            local owner=mapScreen
            if owner and owner.activeModuleId=='furnishingPlans' and owner._tcfMapReturn then
                owner._tcfMapReturn=nil
                owner.returnToMotifsAfterMap,owner.resumeMotifsAfterMap=false,false
                Clear()
                if SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER.ShowBaseScene
                    and SCENE_MANAGER:IsShowing('tamrielCollectionsGamepad')then SCENE_MANAGER:ShowBaseScene()end
            end
        end)
    end
    if GAMEPAD_WORLD_MAP_SCENE and not Map.returnCallback then
        Map.returnCallback=true
        GAMEPAD_WORLD_MAP_SCENE:RegisterCallback('StateChange',function(_,state)
            if state==SCENE_HIDDEN then Clear()end
        end)
    end
    screen._tcfMapReturn={mode=screen.mode,familyKey=screen._tcfFamilyKey,planKey=screen._tcfPlanKey}
    screen.returnToMotifsAfterMap=true
    screen.returnMotifSelectedIndex=screen.styleList:GetSelectedIndex()
    ZO_WorldMap_ShowWorldMap()
    if target.mapId and WORLD_MAP_MANAGER.SetMapById then WORLD_MAP_MANAGER:SetMapById(target.mapId)
    else WORLD_MAP_MANAGER:SetMapByIndex(index)end
    if target.zoneOnly then return end
    local attempts=0
    local function PlacePin()
        if request~=requestNumber then return end
        attempts=attempts+1
        local correct=target.mapId and GetCurrentMapId and GetCurrentMapId()==target.mapId
            or (not target.mapId and GetCurrentMapIndex and GetCurrentMapIndex()==index)
        local x,y
        if correct then
            if target.nodeIndex and GetFastTravelNodeInfo then
                local _,_,nx,ny,_,_,_,shown=GetFastTravelNodeInfo(target.nodeIndex)
                if shown and Coordinates(nx,ny)then x,y=nx,ny end
            end
            if not Coordinates(x,y) and target.poiIndex and GetPOIMapInfo then
                local px,py,_,_,shown=GetPOIMapInfo(target.zoneIndex,target.poiIndex)
                if shown and Coordinates(px,py)then x,y=px,py end
            end
            if target.names then
                local nx,ny=LocationCoordinates(target.names)
                if Coordinates(nx,ny)then x,y=nx,ny end
            end
            if not Coordinates(x,y)and Coordinates(target.x,target.y)then x,y=target.x,target.y end
        end
        if not correct or not Coordinates(x,y)then
            if attempts<20 and zo_callLater then zo_callLater(PlacePin,50)end
            return
        end
        local manager=ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
        local pan=ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom()
        if not (manager and pan)then return end
        manager:RemovePins('pings',MAP_PIN_TYPE_QUEST_PING,pinTag)
        local pin=manager:CreatePin(MAP_PIN_TYPE_QUEST_PING,pinTag,x,y)
        if pin then pan:JumpToPin(pin)end
    end
    if zo_callLater then zo_callLater(PlacePin,150)else PlacePin()end
end
