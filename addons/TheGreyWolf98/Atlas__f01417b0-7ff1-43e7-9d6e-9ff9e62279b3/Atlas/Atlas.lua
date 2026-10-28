local A = Atlas
A.version = "1.0.8"
A.author = "@TheGreyWolf98"
ZO_CreateStringId("SI_BINDING_NAME_ATLAS_OPEN","Open Atlas")
A.defaults = {skyshards=true, lorebooks=true, treasure=true, bosses=true, delves=true, worldBosses=true, publicDungeons=true, events=true, wayshrines=true, strikingLocales=true, mundus=true, craftingStations=true, surveys=true, hideCollected=true, carriedOnly=false, neonColours=true, largerPins=false,chests=true,troves=true}
A.layerCount=15
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
    {key="chests", title="Treasure chests", detail="Recorded chest spawn sites, separate from treasure-map digs. Not live availability.", color={1,0.82,0.28}, texture="Atlas/Textures/Chest.dds"},
    {key="troves", title="Thieves Guild troves", detail="Recorded trove spawn sites. Availability and Thieves Guild access are not checked.", color={0.55,0.65,1}, texture="Atlas/Textures/Trove.dds"},
    {key="hideCollected", title="Hide collected", detail="Hide acquired skyshards and known lorebooks on this character."},
    {key="carriedOnly", title="Carried maps / surveys only", detail="Only show digs and surveys whose map/report is in your backpack."},
    {key="neonColours", title="Neon colours", detail="Bright coloured rings around Atlas symbols (except solid-colour chest pins)."},
    {key="largerPins", title="Larger pins", detail="Increase most Atlas symbols from 28 to 42; chest pins use 22 or 32."},
}

-- The ring is monochrome so tint colours stay bright even when an icon's own
-- texture is gold, red or blue. Original symbols remain readable inside it.
A.neonPalette = {
    skyshards={0,1,1}, lorebooks={1,0.15,1}, treasure={1,1,0},
    bosses={1,0.15,0.15}, delves={0.15,0.65,1}, worldBosses={1,0.35,0},
    publicDungeons={0.65,0.3,1}, events={1,0.65,0}, wayshrines={0.2,1,0.6},
    strikingLocales={1,1,1}, mundus={1,0.25,0.65}, craftingStations={0.45,1,0},
    surveys={0,1,0.2},chests={1,0.8,0},troves={0.65,0.25,1},
}

function A.OptionColour(option)
    return A.saved and A.saved.neonColours and A.neonPalette[option.key] or option.color
end

function A.UpdatePinStyles()
    if not A.layouts then return end
    for i=1,A.layerCount do
        local o=A.options[i]
        local layout=A.layouts[o.key]
        layout.size=o.key=="chests" and (A.saved.largerPins and 32 or 22) or (A.saved.largerPins and 42 or 28)
        layout.tint:SetRGB(unpack((o.key=="chests" or not A.saved.neonColours) and o.color or {1,1,1}))
        A.ringLayouts[o.key].size=A.saved.largerPins and 64 or 46
    end
end

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

A.workerLimits={interval=20,resumes=40,milliseconds=2,candidates=12,pins=20}
local function checkpoint(pin)
    if not A.inWorker then return end
    A.sliceCandidates=(A.sliceCandidates or 0)+1
    if pin or A.sliceCandidates>=A.workerLimits.candidates or GetGameTimeMilliseconds()-A.sliceStarted>=1 then
        coroutine.yield()
        A.sliceCandidates=0;A.sliceStarted=GetGameTimeMilliseconds()
    end
end
A.Checkpoint=checkpoint
-- Scan native POIs once per viewed map, shared by the eight discovery layers.
function A.NativeLocations(key)
    while A.nativeBuilding and not A.nativeCache do checkpoint(true) end
    if not A.nativeCache then
        A.nativeBuilding=true
        local buckets={}
        for i=1,A.layerCount do local o=A.options[i];if o.completionTypes then buckets[o.key]={}end end
        local zone=GetCurrentMapZoneIndex()
        if zone and zone>0 then
            for poi=1,GetNumPOIs(zone)do
                checkpoint()
                local kind=GetPOIZoneCompletionType(zone,poi)
                local x,y,_,icon,onMap,_,discovered=GetPOIMapInfo(zone,poi)
                if onMap and valid(x,y)then
                    for i=1,A.layerCount do
                        local o=A.options[i]
                        for _,t in ipairs(o.completionTypes or {})do
                            if t==kind then
                                local points=buckets[o.key]
                                points[#points+1]={x=x,y=y,title=clean(GetPOIInfo(zone,poi))or o.title,description="Atlas | "..o.title..(discovered and " | Discovered"or " | Undiscovered"),texture=icon}
                                break
                            end
                        end
                    end
                end
            end
        end
        A.nativeCache=buckets;A.nativeBuilding=false
    end
    return A.nativeCache[key]or {}
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
    elseif key=="chests" or key=="troves" then
        local map=A.MapKey()
        for _,p in ipairs(A[key][map]or {})do
            checkpoint()
            add(p[1],p[2],key=="chests"and "Treasure chest"or "Thieves Guild trove","Atlas | Recorded spawn site; may be empty or absent")
        end
        local learned=A.saved.containerLocations and A.saved.containerLocations[key]
        for _,p in ipairs(learned and learned[map]or {})do
            checkpoint()
            add(p[1],p[2],key=="chests"and "Treasure chest"or "Thieves Guild trove","Atlas | Personally recorded spawn site; may be empty or absent")
        end
    elseif key=="bosses" then
        for _,p in ipairs(A.bosses[A.MapKey()] or {}) do
            checkpoint()
            local name=p.name
            if not name then name=p[4] and GetAchievementCriterion(p[3],p[4]) or GetAchievementInfo(p[3]) end
            add(p[1],p[2],clean(name) or "Dungeon boss","Atlas | "..(p.kind or "Public-dungeon boss"))
        end
    else
        return A.NativeLocations(key)
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
        A.workMap=signature;A.cache={};A.jobs={};A.refreshLayers={};A.carriedCache=nil;A.carriedBuilding=false;A.nativeCache=nil;A.nativeBuilding=false
    end
    return signature
end
local function jobId(key, kind) return key..":"..kind end
function A.EnsureLocations(key)
    if A.cache[key] or A.jobs[jobId(key,"build")] then return end
    local signature=A.workMap
    A.jobs[jobId(key,"build")]={run=coroutine.create(function()
        local points=A.BuildLocations(key)
        if A.workMap==signature then A.cache[key]=points end
    end)}
end
function A.ScheduleLayer(key,manager,isRing)
    local signature=A.CheckMap()
    A.EnsureLocations(key)
    if manager then
        local kind=isRing and "ring" or "symbol"
        A.jobs[jobId(key,kind)]={run=coroutine.create(function()
            while not A.cache[key] do checkpoint() end
            for _,point in ipairs(A.cache[key]) do
                checkpoint(true)
                if A.saved[key] and A.workMap==signature and (not isRing or (A.saved.neonColours and key~="chests")) then
                    A.tickPins=A.tickPins+1
                    manager:CreatePin(isRing and A.ringTypes[key] or A.pinTypes[key],point,point.x,point.y)
                end
            end
        end)}
    end
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
    EVENT_MANAGER:RegisterForUpdate("AtlasWork",A.workerLimits.interval,function()
        A.CheckMap()
        if IsUnitInCombat and IsUnitInCombat("player") then return end
        local started=GetGameTimeMilliseconds()
        A.tickPins=0
        local layer=next(A.refreshLayers)
        if layer then
            local pending=A.refreshLayers[layer]
            A.refreshLayers[layer]=nil
            -- Refresh one native pin layer per tick.
            A.manager:RefreshCustomPins(pending.isRing and A.ringTypes[pending.key] or A.pinTypes[pending.key])
            -- Render/build work may use the remainder of this tick.
        end
        local steps=0
        while steps<A.workerLimits.resumes and A.tickPins<A.workerLimits.pins and GetGameTimeMilliseconds()-started<A.workerLimits.milliseconds do
            -- Build, symbol and ring jobs share the same operation/time budget.
            local selected
            local kinds={"build","symbol","ring"}
            local total=A.layerCount*3
            for offset=1,total do
                local index=((A.workerCursor or 0)+offset-1)%total+1
                local option=A.options[math.floor((index-1)/3)+1]
                local id=jobId(option.key,kinds[(index-1)%3+1])
                if A.jobs[id] and (kinds[(index-1)%3+1]=="build" or A.cache[option.key]) then selected=id;A.workerCursor=index;break end
            end
            if not selected then break end
            local job=A.jobs[selected]
            A.inWorker=true;A.sliceCandidates=0;A.sliceStarted=GetGameTimeMilliseconds()
            local ok,err=coroutine.resume(job.run)
            A.inWorker=false;steps=steps+1
            if not ok or coroutine.status(job.run)=="dead" then
                A.jobs[selected]=nil
                if not ok then
                    A.lastWorkError=selected..": "..tostring(err)
                    local failed=selected:match("^(.-):build$")
                    if failed then A.cache[failed]={};A.nativeBuilding=false end
                    if selected=="treasure:build" or selected=="surveys:build" then A.carriedBuilding=false end
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
    A.ringTypes={}
    A.layouts={}
    A.ringLayouts={}
    for i=1,A.layerCount do
        local o=A.options[i]
        local key=o.key
        local typeName="ATLAS_PIN_"..key:upper()
        local ringName="ATLAS_RING_"..key:upper()
        local ringLayout={level=54,size=46,texture="Atlas/Textures/NeonRing.dds",tint=ZO_ColorDef:New(unpack(A.neonPalette[key]))}
        A.ringLayouts[key]=ringLayout
        -- Decorative rings intentionally have no tooltip creator.
        A.manager:AddCustomPin(ringName,function(manager)
            if not A.saved[key] or not A.saved.neonColours or key=="chests" then return end
            A.ScheduleLayer(key,manager,true)
        end,nil,ringLayout)
        A.ringTypes[key]=_G[ringName]
        A.manager:SetCustomPinEnabled(A.ringTypes[key],A.saved[key] and A.saved.neonColours and key~="chests")
        local layout={level=55,size=28,texture=function(pin)
            local _,p=pin:GetPinTypeAndTag()
            return p.texture and p.texture~="" and p.texture or o.texture
        end,tint=ZO_ColorDef:New(unpack(o.color))}
        A.layouts[key]=layout
        A.manager:AddCustomPin(typeName,function(manager)
            if not A.saved[key] then return end
            A.ScheduleLayer(key,manager,false)
        end,nil,layout,
        -- Both ESO tooltip sorters compare category IDs with native numeric IDs.
        {tooltip=ZO_MAP_TOOLTIP_MODE.INFORMATION,creator=tooltip,categoryId=ZO_MapPin.PIN_ORDERS.DESTINATIONS,entryName=function(pin) local _,p=pin:GetPinTypeAndTag(); return p.title end})
        A.pinTypes[key]=_G[typeName]
        A.manager:SetCustomPinEnabled(A.pinTypes[key],A.saved[key])
    end
    A.UpdatePinStyles()
end

function A.Refresh(keys,stylesOnly)
    -- Keybind callbacks can supply a string, so only explicit true skips rebuilding.
    stylesOnly=stylesOnly==true
    if not A.manager then return end
    A.CheckMap()
    A.UpdatePinStyles()
    local affected={}
    if type(keys)=="table" then for _,key in ipairs(keys) do affected[key]=true end
    else for i=1,A.layerCount do affected[A.options[i].key]=true end end
    for i=1,A.layerCount do
        local o=A.options[i]
        if affected[o.key] and o.completionTypes and not stylesOnly then
            A.nativeBuilding=false
            A.nativeCache=nil
            break
        end
    end
    for i=1,A.layerCount do
        local key=A.options[i].key
        if affected[key] then
            if not stylesOnly and (key=="skyshards" or key=="lorebooks" or key=="treasure" or key=="surveys") then A.cache[key]=nil end
            for _,kind in ipairs({"build","symbol","ring"}) do A.jobs[jobId(key,kind)]=nil end
            A.refreshLayers[jobId(key,"symbol")]={key=key,isRing=false}
            if key~="chests" then A.refreshLayers[jobId(key,"ring")]={key=key,isRing=true} end
            A.manager:SetCustomPinEnabled(A.pinTypes[key],A.saved[key])
            A.manager:SetCustomPinEnabled(A.ringTypes[key],A.saved[key] and A.saved.neonColours and key~="chests")
        end
    end
    if affected.treasure or affected.surveys then
        A.carriedBuilding=false
        if not stylesOnly then A.carriedCache=nil end
    end
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
    elseif key=="hideCollected" then A.Refresh({"skyshards","lorebooks"})
    else A.Refresh(nil,true) end
end

function A.NextOption()
    A.selected=(A.selected or 1)%#A.options+1
    A.Paint()
end

function A.Open()
    if A.supportScene and A.supportScene:IsShowing() then SCENE_MANAGER:Hide("atlasSupport")
    elseif A.scene:IsShowing() then SCENE_MANAGER:Hide("atlas") else SCENE_MANAGER:Show("atlas") end
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
    A.RegisterContainerLearning()
    SLASH_COMMANDS["/atlas"]=function(arg)
        arg=zo_strtrim(arg or ""):lower()
        if arg=="socials" or arg=="support" then SCENE_MANAGER:Show("atlasSupport")
        elseif arg=="refresh" then A.Refresh()
        elseif arg=="all on" or arg=="all off" then
            for i=1,A.layerCount do A.saved[A.options[i].key]=arg=="all on" end
            A.Refresh()
        else A.Open() end
    end
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_PLAYER_ACTIVATED,function()
        local old=A.workMap
        local current=A.CheckMap()
        if old~=current then A.QueueRefresh() end
    end)
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_SKYSHARDS_UPDATED,function() A.QueueRefresh({"skyshards"}) end)
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_LORE_BOOK_LEARNED,function() A.QueueRefresh({"lorebooks"}) end)
    local discoveryKeys={"delves","worldBosses","publicDungeons","events","wayshrines","strikingLocales","mundus","craftingStations"}
    for _,eventName in ipairs({"EVENT_POI_DISCOVERED","EVENT_POI_UPDATED","EVENT_POIS_INITIALIZED",
        "EVENT_OBJECTIVE_COMPLETED","EVENT_FAST_TRAVEL_NETWORK_UPDATED"}) do
        local event=_G[eventName]
        if event then EVENT_MANAGER:RegisterForEvent("AtlasDiscovery",event,function() A.QueueRefresh(discoveryKeys) end) end
    end
    EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag)
        if A.saved.carriedOnly and bag==BAG_BACKPACK then A.QueueRefresh({"treasure","surveys"}) end
    end)
    A.Refresh()
end
EVENT_MANAGER:RegisterForEvent("Atlas",EVENT_ADD_ON_LOADED,loaded)
