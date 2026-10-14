local A = Atlas
A.version = "1.0.2"
ZO_CreateStringId("SI_BINDING_NAME_ATLAS_OPEN","Open Atlas")
A.defaults = {skyshards=true, lorebooks=true, treasure=true, bosses=true, delves=true, worldBosses=true, publicDungeons=true, events=true, wayshrines=true, strikingLocales=true, mundus=true, craftingStations=true, surveys=true, hideCollected=true, carriedOnly=false}
A.layerCount=13
A.options = {
    {key="skyshards", title="Skyshards", detail="Native skyshard locations supplied by ESO on the viewed map.", color={0.50,0.85,1}, texture="EsoUI/Art/MapPins/skyshard_seen.dds"},
    {key="lorebooks", title="Lorebooks", detail="Recorded Shalidor lorebooks across supported map floors.", color={0.65,0.55,1}, texture="EsoUI/Art/Icons/quest_book_001.dds"},
    {key="treasure", title="Treasure-map digs", detail="Recorded treasure digs across supported zones.", color={1,1,1}, texture="Atlas/Textures/Treasure.dds"},
    {key="bosses", title="Interior bosses", detail="Recorded delve and public-dungeon bosses; group coverage is incomplete.", color={1,0.48,0.40}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds"},
    {key="delves", title="Delves", detail="Native delve entrances, including undiscovered locations.", color={0.75,0.86,1}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_DELVES,ZONE_COMPLETION_TYPE_GROUP_DELVES}},
    {key="worldBosses", title="World bosses", detail="Native world-boss locations on the viewed map.", color={1,0.48,0.40}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_GROUP_BOSSES}},
    {key="publicDungeons", title="Public dungeons", detail="Native public-dungeon entrances; interior bosses are separate.", color={0.75,0.65,1}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS}},
    {key="events", title="Dolmens / world events", detail="Native event sites: dolmens, geysers and other zone events.", color={1,0.75,0.3}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_WORLD_EVENTS}},
    {key="wayshrines", title="Wayshrines", detail="Native wayshrine locations, including undiscovered shrines.", color={0.65,0.85,1}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_WAYSHRINES}},
    {key="strikingLocales", title="Striking locales", detail="Native landmarks, including undiscovered locations.", color={0.85,0.8,0.55}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_STRIKING_LOCALES}},
    {key="mundus", title="Mundus stones", detail="Native Mundus stone sites, including undiscovered locations.", color={0.7,0.65,1}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_MUNDUS_STONES}},
    {key="craftingStations", title="Set crafting stations", detail="Native set crafting sites, including undiscovered locations.", color={0.65,0.9,0.65}, texture="EsoUI/Art/Icons/poi/poi_groupboss_incomplete.dds", completionTypes={ZONE_COMPLETION_TYPE_SET_STATIONS}},
    {key="surveys", title="Crafting surveys", detail="Survey report locations; enable the backpack filter to show only carried reports.", color={1,1,1}, texture="Atlas/Textures/Survey.dds"},
    {key="hideCollected", title="Hide collected", detail="Hide acquired skyshards and known lorebooks on this character."},
    {key="carriedOnly", title="Carried maps / surveys only", detail="Only show digs and surveys whose map/report is in your backpack."},
}

function A.MapKey()
    local path = GetMapTileTexture(1) or ""
    return path:lower():match("([^/]+)_%d+%.dds$") or ""
end

local function clean(s)
    return s and s ~= "" and zo_strformat("<<1>>",s) or nil
end

local function valid(x,y)
    return type(x)=="number" and type(y)=="number" and x==x and y==y and x>=0 and x<=1 and y>=0 and y<=1
end

local function checkpoint()
    if A.inWorker then coroutine.yield() end
end
function A.CarriedMaps()
    if A.carriedCache then return A.carriedCache end
    if A.inWorker then
        while A.carriedBuilding and not A.carriedCache do checkpoint() end
        if A.carriedCache then return A.carriedCache end
    end
    A.carriedBuilding=true
    local items = {}
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        checkpoint()
        local id = GetItemId(BAG_BACKPACK,slot)
        if id and id>0 then items[id]=true end
    end
    A.carriedCache=items;A.carriedBuilding=false
    return items
end

-- No map-changing calls: coordinates always refer to the currently viewed map.
function A.BuildLocations(key)
    local result = {}
    local function add(x,y,title,description,known,texture)
        if valid(x,y) then
            result[#result+1]={x=x,y=y,title=title,description=description,known=known,texture=texture}
        end
    end
    if key=="skyshards" then
        if not GetNumSkyshards or not GetNormalizedPositionForSkyshardId then return result end
        for index=1,GetNumSkyshards() do
            checkpoint()
            local id=GetSkyshardId(index)
            local x,y,onMap=GetNormalizedPositionForSkyshardId(id)
            if onMap then
                local known=GetSkyshardDiscoveryStatus(id)==SKYSHARD_DISCOVERY_STATUS_ACQUIRED
                if not (A.saved.hideCollected and known) then
                    add(x,y,clean(GetSkyshardHint(id)) or "Skyshard",known and "Atlas | Acquired skyshard" or "Atlas | Skyshard",known,known and "EsoUI/Art/MapPins/skyshard_complete.dds" or nil)
                end
            end
        end
    elseif key=="lorebooks" then
        for _,p in ipairs((A.booksByMapId and GetCurrentMapId and A.booksByMapId[GetCurrentMapId()]) or A.books[A.MapKey()] or {}) do
            checkpoint()
            local name,bookIcon,known=GetLoreBookInfo(1,p[3],p[4])
            if not (A.saved.hideCollected and known) then
                add(p[1],p[2],clean(name) or "Lorebook",known and "Atlas | Known Shalidor book" or "Atlas | Shalidor book; recorded location",known,bookIcon)
            end
        end
    elseif key=="treasure" or key=="surveys" then
        local carried=A.saved.carriedOnly and A.CarriedMaps() or nil
        for _,p in ipairs((key=="surveys" and ((A.surveysByMapId and GetCurrentMapId and A.surveysByMapId[GetCurrentMapId()]) or A.surveys[A.MapKey()] or {}) or ((A.treasureByMapId and GetCurrentMapId and A.treasureByMapId[GetCurrentMapId()]) or A.treasure[A.MapKey()])) or {}) do
            checkpoint()
            if not carried or carried[p[3]] then
                local link=("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"):format(p[3])
                local mapIcon=key=="surveys" and "Atlas/Textures/Survey.dds" or "Atlas/Textures/Treasure.dds"
                add(p[1],p[2],clean(GetItemLinkName(link)) or p[4],key=="surveys" and "Atlas | Survey site; report required to harvest" or "Atlas | Treasure-map dig; map required to dig",nil,mapIcon)
            end
        end
    elseif key=="bosses" then
        for _,p in ipairs(A.bosses[A.MapKey()] or {}) do
            checkpoint()
            local name=p.name
            if not name then name=p[4] and GetAchievementCriterion(p[3],p[4]) or GetAchievementInfo(p[3]) end
            add(p[1],p[2],clean(name) or "Dungeon boss","Atlas | "..(p.kind or "Public-dungeon boss"))
        end
    else
        local option
        for i=5,A.layerCount do if A.options[i].key==key then option=A.options[i]; break end end
        if option then
            local zoneIndex=GetCurrentMapZoneIndex()
            if zoneIndex and zoneIndex>0 then
                for poi=1,GetNumPOIs(zoneIndex) do
                    checkpoint()
                    local completionType=GetPOIZoneCompletionType(zoneIndex,poi)
                    local matches=false
                    for _,t in ipairs(option.completionTypes) do if completionType==t then matches=true; break end end
                    if matches then
                        local x,y,_,poiIcon,onMap,_,discovered=GetPOIMapInfo(zoneIndex,poi)
                        if onMap then
                            local title=clean(GetPOIInfo(zoneIndex,poi)) or option.title
                            add(x,y,title,"Atlas | "..option.title..(discovered and " | Discovered" or " | Undiscovered"),nil,poiIcon)
                        end
                    end
                end
            end
        end
    end
    return result
end

-- A single shared worker limits candidate checks AND native pin creation.
-- Keep only the viewed map's cache; no growing per-zone saved data.
function A.MapSignature()
    return tostring(GetCurrentMapId and GetCurrentMapId() or "")..":"..(GetMapTileTexture(1) or "")
end
function A.CheckMap()
    local signature=A.MapSignature()
    if A.workMap~=signature then
        A.workMap=signature;A.cache={};A.jobs={};A.refreshLayers={};A.carriedCache=nil;A.carriedBuilding=false
    end
    return signature
end
function A.ScheduleLayer(key,manager)
    local signature=A.CheckMap()
    if not manager and A.jobs[key] then return end
    A.jobs[key]={run=coroutine.create(function()
        local points=A.cache[key]
        if not points then points=A.BuildLocations(key);A.cache[key]=points end
        if manager then
            for _,point in ipairs(points) do
                checkpoint()
                if A.saved[key] and A.workMap==signature then
                    manager:CreatePin(A.pinTypes[key],point,point.x,point.y)
                end
            end
        end
    end)}
    A.StartWorker()
end
function A.Locations(key)
    A.CheckMap()
    if not A.cache[key] then A.ScheduleLayer(key) end
    return A.cache[key] or {}
end
function A.StartWorker()
    if A.workerActive then return end
    A.workerActive=true
    EVENT_MANAGER:RegisterForUpdate("AtlasWork",50,function()
        A.CheckMap()
        if IsUnitInCombat and IsUnitInCombat("player") then return end
        local started=GetGameTimeMilliseconds()
        local layer=next(A.refreshLayers)
        if layer then
            A.refreshLayers[layer]=nil
            A.manager:RefreshCustomPins(A.pinTypes[layer])
            -- Even native layer removal gets its own tick.
            return
        end
        local steps=0
        while steps<12 and GetGameTimeMilliseconds()-started<2 do
            -- Round-robin avoids a large skyshard list starving other layers.
            local selected
            for offset=1,A.layerCount do
                local index=((A.workerCursor or 0)+offset-1)%A.layerCount+1
                local key=A.options[index].key
                if A.jobs[key] then selected=key;A.workerCursor=index;break end
            end
            if not selected then break end
            local job=A.jobs[selected]
            A.inWorker=true
            local ok=coroutine.resume(job.run)
            A.inWorker=false;steps=steps+1
            if not ok or coroutine.status(job.run)=="dead" then
                A.jobs[selected]=nil
                if not ok then
                    A.lastWorkError=selected
                    if selected=="treasure" or selected=="surveys" then A.carriedBuilding=false end
                end
                A.paintPending=true
            end
        end
        if A.paintPending and A.Paint then A.paintPending=false;A.Paint() end
        if not next(A.jobs) and not next(A.refreshLayers) then
            EVENT_MANAGER:UnregisterForUpdate("AtlasWork");A.workerActive=false
        end
    end)
end

local function tooltip(pin)
    local _,p=pin:GetPinTypeAndTag()
    local t=ZO_WorldMap_GetTooltipForMode(ZO_MAP_TOOLTIP_MODE.INFORMATION)
    if t.LayoutStringLine and t.tooltip then
        local style=t.tooltip:GetStyle("keepBaseTooltipContent")
        t:LayoutStringLine(t.tooltip,p.title,style)
        t:LayoutStringLine(t.tooltip,p.description,style)
    elseif t.AddLine then
        t:AddLine(p.title,"ZoFontGameOutline",1,0.82,0.4)
        t:AddLine(p.description,"ZoFontGame",0.8,0.85,0.9)
    end
end

function A.RegisterPins()
    A.manager=ZO_WorldMap_GetPinManager()
    A.pinTypes={}
    for i=1,A.layerCount do
        local o=A.options[i]
        local key=o.key
        local typeName="ATLAS_PIN_"..key:upper()
        A.manager:AddCustomPin(typeName,function(manager)
            if not A.saved[key] then return end
            A.ScheduleLayer(key,manager)
        end,nil,{level=55,size=28,texture=function(pin)
            local _,p=pin:GetPinTypeAndTag()
            return p.texture and p.texture~="" and p.texture or o.texture
        end,tint=ZO_ColorDef:New(unpack(o.color))},
        -- Both ESO tooltip sorters compare category IDs with native numeric IDs.
        {tooltip=ZO_MAP_TOOLTIP_MODE.INFORMATION,creator=tooltip,categoryId=ZO_MapPin.PIN_ORDERS.DESTINATIONS,entryName=function(pin) local _,p=pin:GetPinTypeAndTag(); return p.title end})
        A.pinTypes[key]=_G[typeName]
        A.manager:SetCustomPinEnabled(A.pinTypes[key],A.saved[key])
    end
end

function A.Refresh(keys)
    if not A.manager then return end
    A.CheckMap()
    local affected={}
    if type(keys)=="table" then for _,key in ipairs(keys) do affected[key]=true end
    else for i=1,A.layerCount do affected[A.options[i].key]=true end end
    for i=1,A.layerCount do
        local key=A.options[i].key
        if affected[key] then
            A.cache[key]=nil;A.jobs[key]=nil;A.refreshLayers[key]=true
            A.manager:SetCustomPinEnabled(A.pinTypes[key],A.saved[key])
        end
    end
    if affected.treasure or affected.surveys then A.carriedCache=nil;A.carriedBuilding=false end
    A.StartWorker()
    if A.Paint then A.Paint() end
end
function A.QueueRefresh(keys)
    A.queuedLayers=A.queuedLayers or {}
    if type(keys)=="table" then for _,key in ipairs(keys) do A.queuedLayers[key]=true end
    else for i=1,A.layerCount do A.queuedLayers[A.options[i].key]=true end end
    -- Coalesce bursts without postponing refresh indefinitely.
    if A.refreshQueued then return end
    A.refreshQueued=true
    EVENT_MANAGER:RegisterForUpdate("AtlasRefresh",300,function()
        EVENT_MANAGER:UnregisterForUpdate("AtlasRefresh")
        A.refreshQueued=false
        local list={};for key in pairs(A.queuedLayers) do list[#list+1]=key end
        A.queuedLayers={};A.Refresh(list)
    end)
end

function A.Toggle(index)
    A.selected=index or A.selected or 1
    local key=A.options[A.selected].key
    A.saved[key]=not A.saved[key]
    if A.selected<=A.layerCount then A.Refresh({key})
    elseif key=="carriedOnly" then A.Refresh({"treasure","surveys"})
    else A.Refresh({"skyshards","lorebooks"}) end
end

function A.NextOption()
    A.selected=(A.selected or 1)%#A.options+1
    A.Paint()
end

function A.Open()
    if A.scene:IsShowing() then SCENE_MANAGER:Hide("atlas") else SCENE_MANAGER:Show("atlas") end
end

local function loaded(_,name)
    if name~="Atlas" then return end
    EVENT_MANAGER:UnregisterForEvent("Atlas",EVENT_ADD_ON_LOADED)
    A.saved=ZO_SavedVars:NewAccountWide("AtlasSaved",1,nil,A.defaults)
    -- Populate new switches when upgrading an existing 0.1.0 saved profile.
    for key,value in pairs(A.defaults) do if A.saved[key]==nil then A.saved[key]=value end end
    A.selected=1
    A.CreateUI()
    A.RegisterPins()
    SLASH_COMMANDS["/atlas"]=function(arg)
        arg=zo_strtrim(arg or ""):lower()
        if arg=="refresh" then A.Refresh()
        elseif arg=="all on" or arg=="all off" then
            for i=1,A.layerCount do A.saved[A.options[i].key]=arg=="all on" end
            A.Refresh()
        else A.Open() end
    end
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_PLAYER_ACTIVATED,function() A.QueueRefresh() end)
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_SKYSHARDS_UPDATED,function() A.QueueRefresh({"skyshards"}) end)
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_LORE_BOOK_LEARNED,function() A.QueueRefresh({"lorebooks"}) end)
    local discoveryKeys={"delves","worldBosses","publicDungeons","events","wayshrines","strikingLocales","mundus","craftingStations"}
    if EVENT_POI_UPDATED then EVENT_MANAGER:RegisterForEvent("AtlasDiscovery",EVENT_POI_UPDATED,function() A.QueueRefresh(discoveryKeys) end) end
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag)
        if A.saved.carriedOnly and bag==BAG_BACKPACK then A.QueueRefresh({"treasure","surveys"}) end
    end)
    A.Refresh()
end
EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_ADD_ON_LOADED,loaded)
