local NagaMapUI = NagaMapUI

local WAYPOINT_ICON='EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination.dds'
-- Resolve addon texture paths (works even if folder case/root differs).
local function AddonTex(rel)
    if NAGA_UI and NAGA_UI.GetAssetPath then
        return NAGA_UI:GetAssetPath(rel)
    end
    return 'AbyssUI/' .. rel:gsub('^assets/', 'assets/')
end
-- Ícone de círculo de área (não a espada de unidade do evento).
local WORLD_EVENT_ICON = AddonTex('assets/MiniMap/EventWorld.dds')
-- Ícone compacto para eventos dinâmicos (mesmo pulse/borda do EventWorld).
local DYNAMIC_EVENT_ICON = AddonTex('assets/MiniMap/EventDynamic.dds')
local function IsDynamicEventTexture(texture)
    local tex = (texture or ''):lower()
    if tex == '' then return false end
    -- U50+ official: esoui/art/icons/poi/u50_poi_dynamic_world_event.dds
    -- also servicemappins/u50_poi_dynamic_world_event.dds
    if tex:find('u50_poi_dynamic', 1, true) then return true end
    if tex:find('dynamic_world_event', 1, true) then return true end
    if tex:find('poi_dynamic_world', 1, true) then return true end
    if tex:find('mapkey_dynamic', 1, true) then return true end
    if tex:find('dynamicworldevent', 1, true) then return true end
    if tex:find('dynamic_encounter', 1, true) then return true end
    if tex:find('/dynamic_', 1, true) and tex:find('event', 1, true) then return true end
    return false
end

-- Scan map locations for active dynamic-encounter icons (coords + name).
local function CollectDynamicEventLocations()
    local out = {}
    if not GetNumMapLocations or not GetMapLocationIcon then return out end
    for i = 1, GetNumMapLocations() do
        -- Only visible steps (U50: all steps exist; IsMapLocationVisible filters the active one)
        if not IsMapLocationVisible or IsMapLocationVisible(i) then
            local texture, x, y = GetMapLocationIcon(i)
            if IsDynamicEventTexture(texture) and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local name = nil
                if GetMapLocationTooltipHeader then
                    name = GetMapLocationTooltipHeader(i)
                end
                out[#out + 1] = { x = x, y = y, name = name, texture = texture }
            end
        end
    end
    return out
end

NagaMapUI.Minimap = {}
-- Original NagaMapUI minimap. Uses ESO map tiles; no third-party addon dependency.
local root,view,title,clock,settings,player,camera,bg
local tiles,pins={},{}
local points={}
local areas,areaControls={},{}
local key,nextPoints='',0
local SIZE=326
local mapDirty=true
local wasBrowsing=false

local function MapKey()
    local floor=GetMapFloorInfo and GetMapFloorInfo() or 0
    return tostring(GetCurrentMapId())..':'..tostring(floor)..':'..tostring(GetMapTileTexture(1))
end

function NagaMapUI.Minimap.GetZoom()
    -- Keep scale constant while walking, mounting and teleporting. In particular,
    -- dungeon maps must not inherit the 12x zoom formerly used for all zone maps.
    local dungeon=GetMapContentType and GetMapContentType()==MAP_CONTENT_DUNGEON
    local base=dungeon and 1.35 or (GetMapType()==MAPTYPE_ZONE and 8 or 2.2)
    local limit=GetMapCustomMaxZoom and GetMapCustomMaxZoom()
    if limit and limit>0 then base=math.min(base,limit) end
    return math.max(1,math.min(dungeon and 3 or 16,base*settings.zoomBias))
end

local function RefreshMapPins()
    -- Refresh even when SetMapToPlayerLocation reports no change: on login or
    -- after another addon selects a map, the hidden map's pin pool can be empty.
    CALLBACK_MANAGER:FireCallbacks('OnWorldMapChanged')
    local manager=ZO_WorldMap_GetPinManager()
    if manager and manager.RefreshObjectives then manager:RefreshObjectives() end
    if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.RefreshAllAntiquityDigSites then WORLD_MAP_MANAGER:RefreshAllAntiquityDigSites() end
    if ZO_WorldMap_RefreshWorldEvents then ZO_WorldMap_RefreshWorldEvents() end
    mapDirty=false
end
local function Label(parent,size)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    NagaMapUI.Theme.Text(c,size) c:SetMouseEnabled(false)
    return c
end
local function Texture(parent)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
    -- Match ESO's ZO_MapTile template. Rounding moving texture edges to whole
    -- pixels causes uneven steps and resampling ripples during fractional pans.
    -- Pins use the same subpixel coordinates as the map underneath them.
    c:SetPixelRoundingEnabled(false)
    c:SetMouseEnabled(false) return c
end

-- Nome da zona somente em ingles. Com a traducao ativa o jogo devolve "Nome local (English Name)":
-- ficamos com a parte entre parenteses (se for texto ASCII/ingles). Sem parenteses, mantem o nome.
local function EnglishZoneName(name)
    name = zo_strformat('<<1>>', name or '')
    local inner = name:match('^.-%s*%(([^%(%)]+)%)%s*$')
    if inner and not inner:find('[\128-\255]') and inner:find('%a') then return inner end
    return name
end

-- ---------------------------------------------------------------------------
-- Border pins (like MiniMap's "Border pin settings"): pins outside the circular view are
-- drawn on its edge. Categories are decided from the native pin type name / icon path.
-- ---------------------------------------------------------------------------
-- NOTE: never iterate _G here (pairs(_G) touches private functions and the game raises an
-- insecure-access error). Look up each MAP_PIN_TYPE_* constant by its exact name instead;
-- names that do not exist in this game version are simply skipped.
local catByKind
local function BuildCatByKind()
    catByKind={}
    local function Add(cat,names)
        for _,n in ipairs(names) do
            local v=_G['MAP_PIN_TYPE_'..n]
            if type(v)=='number' then catByKind[v]=cat end
        end
    end
    local assisted,tracked={},{}
    for _,q in ipairs({'QUEST','QUEST_REPEATABLE','QUEST_ZONE_STORY'}) do
        for _,c in ipairs({'CONDITION','OPTIONAL_CONDITION','ENDING'}) do
            assisted[#assisted+1]='ASSISTED_'..q..'_'..c
            tracked[#tracked+1]='TRACKED_'..q..'_'..c
        end
    end
    Add('assisted',assisted)
    Add('tracked',tracked)
    Add('questoffer',{'QUEST_OFFER','QUEST_OFFER_REPEATABLE','QUEST_OFFER_ZONE_STORY','TRACKED_QUEST_OFFER_ZONE_STORY'})
    Add('waypoint',{'PLAYER_WAYPOINT'})
    Add('wayshrine',{'FAST_TRAVEL_WAYSHRINE'})
    Add('skyshard',{'SKYSHARD_SEEN','SKYSHARD_SUGGESTED'})
    Add('skyshard_done',{'SKYSHARD_COMPLETE'})
    Add('worldevent',{'WORLD_EVENT_UNIT','WORLD_EVENT_POI_ACTIVE','WORLD_EVENT_POI_PASSIVE'})
    Add('treasure',{'ANTIQUITY_DIG_SITE','TRACKED_ANTIQUITY_DIG_SITE'})
    local alliances={'ALDMERI_DOMINION','EBONHEART_PACT','DAGGERFALL_COVENANT'}
    local avabg={'AVA_RESTRICTED_LINK','BGOBJECTIVE','BATTLEGROUND_OBJECTIVE'}
    for _,al in ipairs(alliances) do
        avabg[#avabg+1]='FORWARD_CAMP_'..al
        avabg[#avabg+1]='ARTIFACT_'..al
        avabg[#avabg+1]='ARTIFACT_'..al..'_OFFENSIVE'
        avabg[#avabg+1]='ARTIFACT_'..al..'_DEFENSIVE'
    end
    for _,n in ipairs({'ALDMERI','EBONHEART','DAGGERFALL'}) do
        avabg[#avabg+1]='ARTIFACT_'..n..'_OFFENSIVE'
        avabg[#avabg+1]='ARTIFACT_'..n..'_DEFENSIVE'
    end
    Add('avabg',avabg)
end
local function Classify(kind,texture,native)
    if not catByKind then BuildCatByKind() end
    local c=catByKind[kind]
    if c then return c end
    local tex=(texture or ''):lower()
    if ZO_MapPin and ZO_MapPin.KEEP_PIN_TYPES and ZO_MapPin.KEEP_PIN_TYPES[kind] then return 'keep' end
    if tex:find('poi_keep',1,true) then return 'keep' end
    if IsDynamicEventTexture(tex) then return 'dynamicevent' end
    if tex:find('dragonnextlocation',1,true) or tex:find('worldevent',1,true) then return 'worldevent' end
    if tex:find('treasure_',1,true) or tex:find('survey',1,true) then return 'treasure' end
    if tex:find('/ava/',1,true) or tex:find('battleground',1,true) or tex:find('forwardcamp',1,true)
        or tex:find('artifact',1,true) or tex:find('flag',1,true) then return 'avabg' end
    return nil
end
local CRAFT_HINTS={'smith','wood','cloth','alchemy','enchant','provision','armory','transmut','jewel','craft','station'}
local function ClassifyLocation(texture)
    local tex=(texture or ''):lower()
    if IsDynamicEventTexture(tex) then return 'dynamicevent' end
    if tex:sub(-8)=='bank.dds' then return 'bank' end
    if tex:sub(-10)=='stable.dds' then return 'stable' end
    for _,h in ipairs(CRAFT_HINTS) do if tex:find(h,1,true) then return 'crafting' end end
    return nil
end
-- Every category is on by default except "group leader only"; keys live in the minimap SV.
local BORDER_DEFAULTS={borderPins=true,borderAssisted=true,borderLeader=false,borderWaypoint=true,
    borderBank=true,borderStables=true,borderWayshrine=true,borderTreasure=true,borderQuestGivers=true,
    borderCrafting=true,borderWorldEvents=true,borderAvaBg=true,borderKeep=true,borderSkyshard=true}
local function BorderOn(key)
    local v=settings and settings[key]
    if v==nil then return BORDER_DEFAULTS[key] end
    return v and true or false
end
-- May this point be shown on the border (it is already known to be outside the view)?
local function BorderAllowed(point)
    if not BorderOn('borderPins') then return false end
    local c=point.cat
    if c=='waypoint' then return BorderOn('borderWaypoint') end
    if c=='assisted' then return true end
    if c=='tracked' then return not BorderOn('borderAssisted') end
    if c=='questoffer' then return BorderOn('borderQuestGivers') end
    if c=='bank' then return BorderOn('borderBank') end
    if c=='stable' then return BorderOn('borderStables') end
    if c=='crafting' then return BorderOn('borderCrafting') end
    if c=='treasure' then return BorderOn('borderTreasure') end
    if c=='worldevent' or c=='dynamicevent' then return BorderOn('borderWorldEvents') end
    if c=='avabg' then return BorderOn('borderAvaBg') end
    if c=='wayshrine' then return BorderOn('borderWayshrine') and point.closest end
    if c=='skyshard' then return BorderOn('borderSkyshard') and point.closest end
    if c=='keep' then return BorderOn('borderKeep') and point.closest and GetCurrentMapId()==16 end
    if c=='group' then
        if not BorderOn('borderLeader') then return true end
        return point.leader and true or false
    end
    return false
end
-- Distância (em METROS) a partir da qual cada tipo de pin passa a aparecer NA BORDA do minimapa.
-- 0/nil = sem limite. Chave salva no SV do minimapa: pinDistM_<categoria>.
-- Escala metros/mapa: calibrada com a posição real do jogador (GetUnitRawWorldPosition, em cm)
-- contra a posição normalizada do mapa; melhora conforme você se move e fica salva por mapa.
local PIN_DIST_ALIAS={skyshard_done='skyshard'}
local PIN_DIST_CATS={assisted=true,tracked=true,questoffer=true,waypoint=true,wayshrine=true,skyshard=true,
    worldevent=true,dynamicevent=true,treasure=true,avabg=true,keep=true,bank=true,stable=true,crafting=true,group=true,other=true}
local mapScale={}
local function UpdateMapScale(x,y,columns,rows)
    if not GetUnitRawWorldPosition or not GetCurrentMapId or not columns or columns<=0 or not rows then return end
    local mapId=GetCurrentMapId()
    if not mapId or mapId==0 then return end
    local ok,_,wx,_,wz=pcall(GetUnitRawWorldPosition,'player')
    if not ok or not wx or not wz then return end
    local m=mapScale[mapId]
    if not m then
        local saved=settings and settings.mapScales and settings.mapScales[mapId]
        m={s=saved and saved.s,b=saved and saved.b or 0}
        mapScale[mapId]=m
    end
    local cur={x=x,y=y*rows/columns,wx=wx,wz=wz}
    local ref=m.ref
    if not ref then m.ref=cur return end
    local dn=math.sqrt((cur.x-ref.x)^2+(cur.y-ref.y)^2)
    if dn>0.003 and dn>m.b then
        local dw=math.sqrt((cur.wx-ref.wx)^2+(cur.wz-ref.wz)^2)/100
        if dw>2 then
            m.s=dw/dn m.b=dn
            if settings then
                settings.mapScales=settings.mapScales or {}
                settings.mapScales[mapId]={s=m.s,b=m.b}
            end
        end
    end
end
local function BeyondPinLimit(cat,px,py,x,y,rows,columns)
    cat=PIN_DIST_ALIAS[cat or '']or cat or 'other'
    if not PIN_DIST_CATS[cat] then cat='other' end
    local limit=settings and tonumber(settings['pinDistM_'..cat])
    if not limit or limit<=0 then return false end
    local m=GetCurrentMapId and mapScale[GetCurrentMapId()]
    if not m or not m.s or not columns or columns<=0 then return false end
    local mx,my=px-x,(py-y)*rows/columns
    return math.sqrt(mx*mx+my*my)*m.s>limit
end
local CLOSEST_CATS={wayshrine=true,skyshard=true,keep=true}
local function MarkClosest(list,px,py)
    local best={}
    for _,pt in ipairs(list) do
        pt.closest=false
        if CLOSEST_CATS[pt.cat] then
            local d=(pt.x-px)^2+(pt.y-py)^2
            local b=best[pt.cat]
            if not b or d<b.d then best[pt.cat]={d=d,pt=pt} end
        end
    end
    for _,b in pairs(best) do b.pt.closest=true end
end

-- ---------------------------------------------------------------------------
-- Pins the hidden world-map manager does not reliably keep while on the HUD (same sources the
-- MiniMap addon reads): the player waypoint and world events (dragons, dolmens, harrowstorms,
-- dark anchors...). Read them straight from the API and add them as normal points.
-- ---------------------------------------------------------------------------
local function AddDirectPoints(list)
    local function Add(x,y,texture,caption,cat,extra)
        local pt={x=x,y=y,texture=texture,color={1,1,1,1},coords={0,1,0,1},rotation=0,level=30,cat=cat,caption=caption}
        if extra then for k,v in pairs(extra) do pt[k]=v end end
        list[#list+1]=pt
    end
    local function Strip(cat)
        for i=#list,1,-1 do if list[i].cat==cat then table.remove(list,i) end end
    end
    -- Player waypoint (personal marker)
    pcall(function()
        local wx,wy=GetMapPlayerWaypoint()
        if wx and wy and not (wx==0 and wy==0) then
            local data=ZO_MapPin and ZO_MapPin.PIN_DATA and MAP_PIN_TYPE_PLAYER_WAYPOINT and ZO_MapPin.PIN_DATA[MAP_PIN_TYPE_PLAYER_WAYPOINT]
            Strip('waypoint')
            Add(wx,wy,(data and data.texture) or WAYPOINT_ICON,nil,'waypoint')
        end
    end)
    -- World events (dólmen, fenda, etc.):
    -- 1 pin por EVENTO ativo (ícone de evento mundial) — nunca as espadinhas de unidade.
    -- alwaysBorder + pulse no Put(); quando o evento acaba, some (sem sobras).
    pcall(function()
        if not GetNextWorldEventInstanceId then return end
        if ZO_WorldMap_DoesMapHideWorldEventPins and ZO_WorldMap_DoesMapHideWorldEventPins() then return end
        local found={}
        local id=GetNextWorldEventInstanceId(nil)
        local guard=0
        while id and id~=0 and guard<64 do
            guard=guard+1
            local context=GetWorldEventLocationContext(id)
            if context==WORLD_EVENT_LOCATION_CONTEXT_UNIT then
                -- Uma única posição (média das unidades), 1 ícone de evento — não 1 espada por unidade.
                local sx,sy,n=0,0,0
                for i=1,GetNumWorldEventInstanceUnits(id) do
                    local unitTag=GetWorldEventInstanceUnitTag(id,i)
                    local ux,uy,_,inMap=GetMapPlayerPosition(unitTag)
                    if inMap and ux and uy and not (ux==0 and uy==0) then
                        sx=sx+ux sy=sy+uy n=n+1
                    end
                end
                if n>0 then
                    found[#found+1]={sx/n,sy/n,WORLD_EVENT_ICON,nil}
                end
            elseif context==WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
                local zoneIndex,poiIndex=GetWorldEventPOIInfo(id)
                -- U50 Dynamic Encounters report zoneIndex=1, poiIndex=1 (they are map locations, not real POIs).
                if zoneIndex==1 and poiIndex==1 then
                    -- handled below via CollectDynamicEventLocations
                elseif poiIndex then
                    local nX,nY,_,_,isOnMap=GetPOIMapInfo(GetCurrentMapZoneIndex(),poiIndex)
                    if isOnMap and nX and nY then
                        local name=GetPOIInfo and GetPOIInfo(GetCurrentMapZoneIndex(),poiIndex)
                        found[#found+1]={nX,nY,WORLD_EVENT_ICON,name,'worldevent'}
                    end
                end
            end
            id=GetNextWorldEventInstanceId(id)
        end
        -- Dynamic encounters (EventDynamic.dds) from map locations
        local dyn=CollectDynamicEventLocations()
        for _,d in ipairs(dyn) do
            found[#found+1]={d.x,d.y,DYNAMIC_EVENT_ICON,d.name,'dynamicevent'}
        end
        Strip('worldevent')
        Strip('dynamicevent')
        for _,f in ipairs(found) do
            local cat=f[5] or 'worldevent'
            Add(f[1],f[2],f[3],f[4],cat,{alwaysBorder=true})
        end
    end)
end
-- Ícone padrão de missão assistida (usado quando o pin tem círculo azul e o texture está oculto).
local ASSISTED_QUEST_ICON='EsoUI/Art/Compass/quest_icon_assisted.dds'
local TRACKED_QUEST_ICON='EsoUI/Art/Compass/quest_icon.dds'

-- ---------------------------------------------------------------------------
-- Missão assistida fora do mapa atual (cidade/interior): mantém pin na borda.
-- Quando o mapa muda e o pin nativo some, usamos a última posição conhecida
-- e/ou RequestJournalQuestConditionAssistance para continuar apontando na borda.
-- ---------------------------------------------------------------------------
local assistedCache=nil -- {x,y,texture,radius,hasRadius,questIndex,mapKey,updated}
local questPending={}
local nextQuestRequest=0
local QUEST_NS='AbyssUI_MinimapQuest'

local function GetAssistedQuestIndex()
    if not MAX_JOURNAL_QUESTS or not IsValidQuestIndex or not GetTrackedIsAssisted then return nil end
    for i=1,MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) and GetTrackedIsAssisted(TRACK_TYPE_QUEST,i) then
            return i
        end
    end
    return nil
end

local function CancelQuestRequests()
    if not CancelRequestJournalQuestConditionAssistance then return end
    for taskId in pairs(questPending) do
        pcall(CancelRequestJournalQuestConditionAssistance,taskId)
    end
    questPending={}
end

local function RequestAssistedQuestPosition()
    if not RequestJournalQuestConditionAssistance then return end
    local index=GetAssistedQuestIndex()
    if not index then
        assistedCache=nil
        CancelQuestRequests()
        return
    end
    local now=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    if now<nextQuestRequest then return end
    nextQuestRequest=now+2.5
    CancelQuestRequests()
    local function request(step,condition)
        local id=RequestJournalQuestConditionAssistance(index,step,condition)
        if id then
            questPending[id]={questIndex=index,step=step,condition=condition,started=now}
        end
    end
    local ok,complete=pcall(GetJournalQuestIsComplete,index)
    if ok and complete then
        request(QUEST_MAIN_STEP_INDEX or 1,1)
    else
        local numSteps=GetJournalQuestNumSteps and GetJournalQuestNumSteps(index) or 1
        for step=(QUEST_MAIN_STEP_INDEX or 1),numSteps do
            local numCond=GetJournalQuestNumConditions and GetJournalQuestNumConditions(index,step) or 1
            for condition=1,numCond do
                local visible,failed,done=true,false,false
                if GetJournalQuestConditionValues then
                    local a,b,f,d,_,v=GetJournalQuestConditionValues(index,step,condition)
                    failed,done,visible=f==true,d==true,v~=false
                end
                if visible and not failed and not done then request(step,condition) end
            end
        end
    end
end

local function OnQuestPositionComplete(_,taskId,pinType,x,y,radius,inside,breadcrumb,teleportNPCId,waypointId,symbolic)
    local req=questPending[taskId]
    if not req then return end
    questPending[taskId]=nil
    if symbolic==QUEST_PIN_STATE_IS_SYMBOLIC_POSITION then return end
    if pinType==MAP_PIN_TYPE_INVALID then return end
    if type(x)~='number' or type(y)~='number' then return end
    -- Aceita coords mesmo com inside=false: em cidades o jogo às vezes devolve
    -- a direção na borda do submapa; se estiver em 0..1 usamos na borda.
    if x<0 or x>1 or y<0 or y>1 then return end
    local index=req.questIndex
    if GetAssistedQuestIndex()~=index then return end
    local hasRadius=(type(radius)=='number' and radius>0) or false
    assistedCache={
        x=x,y=y,
        texture=ASSISTED_QUEST_ICON,
        radius=hasRadius and radius or 0,
        hasRadius=hasRadius,
        questIndex=index,
        mapKey=MapKey(),
        updated=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0,
        alwaysBorder=true,
    }
end

local function InjectAssistedBorderPin(list)
    -- Se já existe pin assisted/tracked nativo, atualiza o cache e não injeta duplicata.
    local foundNative=false
    for _,pt in ipairs(list) do
        if pt.cat=='assisted' or pt.cat=='tracked' then
            foundNative=true
            assistedCache={
                x=pt.x,y=pt.y,texture=pt.texture or ASSISTED_QUEST_ICON,
                radius=0,hasRadius=pt.alwaysBorder==true,
                questIndex=GetAssistedQuestIndex(),
                mapKey=MapKey(),
                updated=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0,
                alwaysBorder=pt.alwaysBorder==true,
            }
        end
    end
    if foundNative then return end
    -- Sem pin nativo (mapa de cidade/interior): pede posição e injeta do cache.
    local currentKey=MapKey()
    local cache=assistedCache
    -- Cache de outro mapa não serve: força novo pedido neste mapa.
    if cache and cache.mapKey and cache.mapKey~=currentKey then
        assistedCache=nil
        cache=nil
        nextQuestRequest=0
    end
    RequestAssistedQuestPosition()
    cache=assistedCache
    if not cache then return end
    local index=GetAssistedQuestIndex()
    if not index or (cache.questIndex and cache.questIndex~=index) then return end
    local now=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    if cache.updated and (now-cache.updated)>60 then
        assistedCache=nil
        nextQuestRequest=0
        RequestAssistedQuestPosition()
        return
    end
    if cache.mapKey and cache.mapKey~=currentKey then return end
    list[#list+1]={
        x=cache.x,y=cache.y,
        texture=cache.texture or ASSISTED_QUEST_ICON,
        color={1,1,1,1},coords={0,1,0,1},rotation=0,level=45,
        cat='assisted',alwaysBorder=true,
        caption=nil,
    }
end

local function CollectPoints()
    points={} areas={}
    local manager=ZO_WorldMap_GetPinManager()
    if not manager or not manager.GetActiveObjects then return end
    manager:UpdateMovingPins()
    for _,native in pairs(manager:GetActiveObjects()) do
        local kind=native:GetPinType()
        local control=native:GetControl()
        local texture=native.backgroundControl
        local hasRadius=false
        -- Círculo de área (fenda no início do evento): coleta mesmo se o ícone do pin estiver oculto.
        do
            local x,y=native:GetNormalizedPosition()
            local blob=native.polygonBlob or native.pinBlob
            local radius=native.radius
            if (not radius or radius<=0) and native.GetRadius then
                local ok,r=pcall(function() return native:GetRadius() end)
                if ok then radius=r end
            end
            if x and y and blob and not blob:IsControlHidden() then
                if native.polygonBlob and native.borderInformation then
                    local edge=native:GetBorderColor()
                    areas[#areas+1]={x=x,y=y,polygon=true,border=native.borderInformation,
                        color={blob:GetCenterColor()},edge={edge:UnpackRGBA()}}
                elseif radius and radius>0 then
                    hasRadius=true
                    areas[#areas+1]={x=x,y=y,radius=radius,texture=blob:GetTextureFileName(),color={blob:GetColor()}}
                end
            end
        end
        -- Parent map is hidden on HUD: test local visibility, not IsHidden().
        -- Grupo e companheiro: nunca coletar pins nativos (só os nossos com estados).
        local skipNativeGroup = kind==MAP_PIN_TYPE_PLAYER or kind==MAP_PIN_TYPE_GROUP
            or kind==MAP_PIN_TYPE_GROUP_LEADER or kind==MAP_PIN_TYPE_LOCATION
            or (MAP_PIN_TYPE_ACTIVE_COMPANION and kind==MAP_PIN_TYPE_ACTIVE_COMPANION)
            or (MAP_PIN_TYPE_COMPANION and kind==MAP_PIN_TYPE_COMPANION)
        -- Tipos nativos de evento mundial = só círculo (já em areas), nunca o ícone de unidade/espada.
        local isWorldEventKind = (MAP_PIN_TYPE_WORLD_EVENT_UNIT and kind==MAP_PIN_TYPE_WORLD_EVENT_UNIT)
            or (MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE and kind==MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE)
            or (MAP_PIN_TYPE_WORLD_EVENT_POI_PASSIVE and kind==MAP_PIN_TYPE_WORLD_EVENT_POI_PASSIVE)
            or (ZO_MapPin and ZO_MapPin.WORLD_EVENT_UNIT_PIN_TYPES and ZO_MapPin.WORLD_EVENT_UNIT_PIN_TYPES[kind])
            or false
        if not skipNativeGroup and not isWorldEventKind and texture
            and not control:IsControlHidden() and not texture:IsControlHidden() then
            local x,y=native:GetNormalizedPosition()
            local filename=texture:GetTextureFileName()
            local texLow=(filename or ''):lower()
            local isGroupTex = texLow:find('grouppip',1,true) or texLow:find('group_pin',1,true)
                or texLow:find('companion',1,true) or texLow:find('worldmapgroup',1,true)
            -- Espadas/ícones de fenda e sobras no fim do evento — bloquear.
            local isWorldEventIcon = texLow:find('worldevent',1,true) or texLow:find('dragonnext',1,true)
                or texLow:find('completiontypeicon_worldevents',1,true)
                or texLow:find('mapkey_dragon',1,true)
                or texLow:find('rift',1,true) or texLow:find('portal',1,true)
                or texLow:find('daedric',1,true) and texLow:find('sword',1,true)
                or texLow:find('ability_warrior',1,true) and texLow:find('sword',1,true)
            if not isGroupTex and not isWorldEventIcon and x and y and x>=0 and x<=1 and y>=0 and y<=1 and filename and filename~='' then
                local cat=Classify(kind,filename,native)
                -- Evento mundial: só o círculo de área; sem ícone de espada/unidade.
                if cat~='worldevent' then
                    points[#points+1]={x=x,y=y,texture=filename,
                        color={texture:GetColor()},coords={texture:GetTextureCoords()},
                        rotation=0,level=texture:GetDrawLevel(),cat=cat,
                        alwaysBorder=hasRadius and (cat=='assisted' or cat=='tracked') or nil}
                end
            end
        -- Missão com círculo azul cujo ícone nativo está oculto: ainda assim criar pin para a borda.
        elseif hasRadius and not skipNativeGroup then
            local x,y=native:GetNormalizedPosition()
            if x and y and x>=0 and x<=1 and y>=0 and y<=1 then
                local cat=Classify(kind,nil,native)
                if cat=='assisted' or cat=='tracked' then
                    local filename
                    if texture and not texture:IsControlHidden() then
                        filename=texture:GetTextureFileName()
                    end
                    if not filename or filename=='' then
                        if ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[kind] then
                            local pd=ZO_MapPin.PIN_DATA[kind]
                            filename=type(pd.texture)=='string' and pd.texture or nil
                        end
                    end
                    if not filename or filename=='' then
                        filename=(cat=='assisted') and ASSISTED_QUEST_ICON or TRACKED_QUEST_ICON
                    end
                    points[#points+1]={x=x,y=y,texture=filename,
                        color={1,1,1,1},coords={0,1,0,1},
                        rotation=0,level=40,cat=cat,alwaysBorder=true}
                end
            end
        end
    end
    -- Location pins (banks, crafting stations, doors, etc.) otherwise remain
    -- queued in the hidden world map's refresh group. Read this map directly,
    -- so an interior can never inherit the previous city's location pins.
    if GetNumMapLocations then
        for i=1,GetNumMapLocations() do
            if IsMapLocationVisible(i) then
                local texture,x,y=GetMapLocationIcon(i)
                if texture and texture~='' and x and y and x>=0 and x<=1 and y>=0 and y<=1 then
                    local cat=ClassifyLocation(texture)
                    if not cat and IsDynamicEventTexture(texture) then cat='dynamicevent' end
                    local tex=texture
                    if cat=='dynamicevent' then
                        tex=DYNAMIC_EVENT_ICON
                    end
                    points[#points+1]={x=x,y=y,texture=tex,color={1,1,1,1},
                        coords={0,1,0,1},rotation=0,level=(cat=='dynamicevent') and 35 or 20,cat=cat,
                        caption=GetMapLocationTooltipHeader and GetMapLocationTooltipHeader(i) or nil,
                        alwaysBorder=(cat=='dynamicevent') or nil}
                end
            end
        end
    end
    AddDirectPoints(points)
    InjectAssistedBorderPin(points)
    -- Círculo de área do evento mundial (quando o nativo não trouxe pinBlob).
    do
        local AREA_TEX='EsoUI/Art/MapPins/map_areaPin.dds'
        for _,pt in ipairs(points) do
            if pt.cat=='worldevent' then
                local has=false
                for _,a in ipairs(areas) do
                    if a.x and a.y and math.abs(a.x-pt.x)<0.03 and math.abs(a.y-pt.y)<0.03 then
                        has=true break
                    end
                end
                if not has then
                    areas[#areas+1]={x=pt.x,y=pt.y,radius=0.045,texture=AREA_TEX,color={0.35,0.55,1,0.45}}
                end
            end
        end
    end
    table.sort(points,function(a,b) return a.level<b.level end)
end
function NagaMapUI.Minimap.DrawAreas(view,areaControls,areas,width,height,left,top,cosH,sinH,rotateMap,viewSize)
    cosH=cosH or 1 sinH=sinH or 0 viewSize=viewSize or 0
    local half=viewSize/2
    -- Gira um ponto (em coordenadas da view, sem rotacao) em volta do jogador (centro),
    -- igual aos tiles e pins, para a area ficar fixa no mapa.
    local function Rot(vx,vy)
        if not rotateMap then return vx,vy end
        local dx,dy=vx-half,vy-half
        return cosH*dx-sinH*dy+half, sinH*dx+cosH*dy+half
    end
    local used=0
    for _,area in ipairs(areas) do
        used=used+1
        local kind=area.polygon and CT_POLYGON or CT_TEXTURE
        local c=areaControls[used]
        if c and c.areaKind~=kind then c:SetHidden(true) c=nil end
        if not c then
            c=WINDOW_MANAGER:CreateControl(nil,view,kind) c.areaKind=kind
            -- Pixel rounding is a texture API, not a PolygonControl method.
            if kind==CT_TEXTURE then c:SetPixelRoundingEnabled(false) end
            c:SetMouseEnabled(false)
            c:SetDrawLayer(DL_BACKGROUND) c:SetDrawLevel(5)
            areaControls[used]=c
        end
        local w,h
        if area.polygon then
            local bw=area.border.borderWidth*width local bh=area.border.borderHeight*height
            local cx=area.x*width-left local cy=area.y*height-top
            -- Pontos no espaco da view, ja rotacionados junto com o mapa.
            local pts,minX,minY,maxX,maxY={},math.huge,math.huge,-math.huge,-math.huge
            for _,point in ipairs(area.border.borderPoints) do
                local vx,vy=Rot(cx+(point.x-0.5)*bw, cy+(point.y-0.5)*bh)
                pts[#pts+1]={vx,vy}
                if vx<minX then minX=vx end if vx>maxX then maxX=vx end
                if vy<minY then minY=vy end if vy>maxY then maxY=vy end
            end
            w=math.max(maxX-minX,1) h=math.max(maxY-minY,1)
            c:ClearPoints()
            for _,pt in ipairs(pts) do c:AddPoint((pt[1]-minX)/w,(pt[2]-minY)/h) end
            c:SetCenterColor(unpack(area.color)) c:SetBorderColor(unpack(area.edge))
            c:SetBorderThickness(1,1,0)
            c:SetDimensions(w,h) c:ClearAnchors()
            c:SetAnchor(TOPLEFT,view,TOPLEFT,minX,minY)
            c:SetHidden(false)
        else
            w=area.radius*2*height h=w
            -- Native ZO_PinBlob is a procedural HALO, not an image texture.
            c:SetShaderEffectType(SHADER_EFFECT_TYPE_HALO)
            c:SetColor(unpack(area.color))
        end
        if not area.polygon then
            local ax,ay=Rot(area.x*width-left,area.y*height-top)
            c:SetDimensions(w,h) c:ClearAnchors()
            c:SetAnchor(CENTER,view,TOPLEFT,ax,ay)
            c:SetHidden(false)
        end
    end
    for i=used+1,#areaControls do areaControls[i]:SetHidden(true) end
end
function NagaMapUI.Minimap.DrawPin(view,pins,index,x,y,texture,name,rotation,style,interactive,host)
    local pin=pins[index]
    host=host or view
    if not pin then
        pin=Texture(host) pin.diaHost=host pin:SetDimensions(22,22) pin:SetDrawLayer(DL_OVERLAY)
        pin:SetMouseEnabled(interactive~=false)
        pin:SetHandler('OnMouseEnter',function(self)
            if self.caption then ZO_Tooltips_ShowTextTooltip(self,TOPLEFT,self.caption) end
        end)
        pin:SetHandler('OnMouseExit',function() ZO_Tooltips_HideTextTooltip() end)
        pins[index]=pin
    end
    pin.caption=name
    -- Pins da borda ficam fora da mascara circular (podem passar da borda do mapa).
    if pin.diaHost~=host then pin:SetParent(host) pin.diaHost=host end
    if pin.diaTexture~=texture then pin:SetTexture(texture) pin.diaTexture=texture end
    pin:SetTextureRotation(rotation or 0)
    if style then
        pin:SetColor(unpack(style.color)) pin:SetTextureCoords(unpack(style.coords))
    else
        pin:SetColor(1,1,1,1) pin:SetTextureCoords(0,1,0,1)
    end
    pin:SetDrawLevel(index)
    pin:ClearAnchors() pin:SetAnchor(CENTER,view,TOPLEFT,x,y)
    pin:SetHidden(false)
end
function NagaMapUI.Minimap.ReadFrame()
    local now=GetFrameTimeSeconds()
    -- Only change global map context on HUD; never interrupt world-map browsing.
    if ZO_WorldMap_IsWorldMapShowing() then wasBrowsing=true return end
    if wasBrowsing then mapDirty=true wasBrowsing=false end
    if not DoesCurrentMapMatchMapForPlayerLocation() then
        local result=SetMapToPlayerLocation()
        if result==SET_MAP_RESULT_MAP_CHANGED then mapDirty=true end
        if result==SET_MAP_RESULT_FAILED then return end
    end
    if not DoesCurrentMapMatchMapForPlayerLocation() then return end
    local columns,rows=GetMapNumTiles()
    local noTiles=false
    -- No tile art (some cities/interiors): keep going with a 1x1 grid so border pins still work.
    if not columns or not rows or columns<1 or rows<1 then columns,rows=1,1 noTiles=true end
    local x,y,heading,shown=GetMapPlayerPosition('player')
    if not shown then return end
    -- The player pip follows the view direction even while the body stands still.
    if GetPlayerCameraHeading then heading=GetPlayerCameraHeading() end
    local context=MapKey()
    local changed=context~=key
    if changed or mapDirty then
        points={} areas={}
        RefreshMapPins()
        -- Callbacks may change context. Never pair old coordinates with new pins.
        if MapKey()~=context or not DoesCurrentMapMatchMapForPlayerLocation() then
            mapDirty=true return
        end
        key=context nextPoints=0
    end
    if now>=nextPoints then CollectPoints() nextPoints=now+0.5 end
    return {columns=columns,rows=rows,noTiles=noTiles,x=x,y=y,heading=heading,key=context,
        points=points,areas=areas,name=GetMapName()}
end
function NagaMapUI.Minimap.InitializeShared()
    if NagaMapUI.Minimap.sharedReady then return end
    NagaMapUI.Minimap.sharedReady=true
    CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged',function() mapDirty=true end)
    EVENT_MANAGER:RegisterForEvent('NagaMapUIMapData',EVENT_PLAYER_ACTIVATED,function() mapDirty=true end)
end
local CAMERA_PIVOT_Y = 0.66 -- vertex of CameraPointer.dds (fraction of texture height)
local noFrameSince
local lastMapRecovery=0
local lastGoodFrame -- último frame válido para transição suave (cidade/mar)
-- Rotação suave (MiniMap smoothHeadingRotation): interpola heading em vez do valor bruto.
local smoothMapHeading=nil
local TWO_PI=math.pi*2
local function SmoothMapHeading(target)
    if target==nil then return 0 end
    if smoothMapHeading==nil then
        smoothMapHeading=target
        return target
    end
    local diff=((target-smoothMapHeading)+math.pi)%TWO_PI-math.pi
    smoothMapHeading=(smoothMapHeading+diff/10)%TWO_PI
    if smoothMapHeading<0 then smoothMapHeading=smoothMapHeading+TWO_PI end
    return smoothMapHeading
end
-- Transição tipo MiniMap: esconde só tiles velhos; mantém fundo + jogador durante troca de mapa.
local function ClearTilesOnly()
    for i=1,#tiles do tiles[i]:SetHidden(true) end
    for i=1,#areaControls do areaControls[i]:SetHidden(true) end
end
local function ClearView()
    ClearTilesOnly()
    for i=1,#pins do pins[i]:SetHidden(true) end
    -- Mantém jogador/câmera visíveis sobre o wheelbackground (como MiniMap sem tiles).
    if player then player:SetHidden(false) end
    if camera then
        local showCam=settings and settings.showCamera~=false
        camera:SetHidden(not showCam)
    end
    if bg then bg:SetHidden(false) end
end
local function Update()
    local now=GetFrameTimeSeconds()
    if ZO_WorldMap_IsWorldMapShowing() then wasBrowsing=true return end
    if root:IsHidden() then return end
    local frame=NagaMapUI.Minimap.ReadFrame()
    if not frame then
        -- Transição: segura o último frame ~0.35s, depois limpa tiles antigos.
        -- Watchdog: se a API de mapa ficar dessincronizada, tenta recuperar o mapa
        -- do jogador periodicamente em vez de deixar o minimapa preso para sempre.
        noFrameSince = noFrameSince or now
        if (now-lastMapRecovery)>1 then
            lastMapRecovery=now
            -- Force a fresh player-map selection when the map API gets stuck.
            -- Use pcall because ESO can temporarily reject map calls during transitions.
            if SetMapToPlayerLocation then
                local ok, result = pcall(SetMapToPlayerLocation)
                if ok and result == SET_MAP_RESULT_MAP_CHANGED then mapDirty=true end
            end
            mapDirty=true
            key=''
            -- Refresh the zone label independently of a valid tile frame.
            -- The label and map share ReadFrame(), so a failed map frame used to freeze both.
            if title and GetMapName then
                local ok, zoneName = pcall(GetMapName)
                if ok and zoneName and zoneName ~= '' then
                    title:SetText(EnglishZoneName(zoneName))
                end
            end
        end
        if lastGoodFrame and (now-noFrameSince)<0.35 then
            frame=lastGoodFrame
        else
            if now-noFrameSince>0.35 then ClearView() end
            return
        end
    else
        noFrameSince=nil
        lastGoodFrame=frame
    end
    local firstTile=GetMapTileTexture(1)
    local noTiles=frame.noTiles or firstTile==nil or firstTile==''
    local columns,rows,x,y,heading=frame.columns,frame.rows,frame.x,frame.y,frame.heading
    local cameraHeading = GetPlayerCameraHeading and GetPlayerCameraHeading() or heading
    local rotateMap = settings and settings.rotateMap ~= false
    -- Modo rotativo: suaviza o heading (como MiniMap) para a rotação não “pular”.
    if rotateMap then
        heading=SmoothMapHeading(heading)
    else
        smoothMapHeading=nil -- reseta ao sair do modo rotativo
    end
    title:SetText(EnglishZoneName(frame.name))
    local zoom=NagaMapUI.Minimap.GetZoom()
    local width=SIZE*zoom local height=width*rows/columns
    local left=x*width-SIZE/2
    local top=y*height-SIZE/2
    local cosH, sinH = 1, 0
    if rotateMap then
        -- ESO heading grows counter-clockwise; to keep the facing direction up the
        -- map must turn clockwise by `heading` (screen Y points down).
        cosH = math.cos(heading)
        sinH = math.sin(heading)
    end
    local tileW, tileH = width/columns, height/rows
    local tileCount=noTiles and 0 or columns*rows
    -- Fundo do círculo sempre visível (MiniMap wheelbackground) — preenche buracos/sem tiles.
    if bg then bg:SetHidden(false) end
    for i=1,tileCount do
        local tile=tiles[i]
        if not tile then tile=Texture(view) tile:SetDrawLayer(DL_BACKGROUND) tile:SetDrawLevel(1) tiles[i]=tile end
        local filename=GetMapTileTexture(i)
        if tile.diaTexture~=filename then tile:SetTexture(filename) tile.diaTexture=filename end
        tile:SetDimensions(tileW, tileH)
        tile:ClearAnchors()
        if rotateMap then
            -- Tile center in view space (player at center), then rotate around player.
            local col = (i-1) % columns
            local row = math.floor((i-1) / columns)
            local cx = (col + 0.5) * tileW - left - SIZE/2
            local cy = (row + 0.5) * tileH - top - SIZE/2
            local rx = cosH * cx - sinH * cy
            local ry = sinH * cx + cosH * cy
            tile:SetAnchor(CENTER, view, CENTER, rx, ry)
            tile:SetTextureRotation(-heading, 0.5, 0.5)
        else
            tile:SetTextureRotation(0)
            tile:SetAnchor(TOPLEFT,view,TOPLEFT,((i-1)%columns)*tileW-left,math.floor((i-1)/columns)*tileH-top)
        end
        tile:SetHidden(filename==nil or filename=='')
    end
    for i=tileCount+1,#tiles do tiles[i]:SetHidden(true) end
    if noTiles then ClearTilesOnly() end
    -- Moldura (Wheelframes) gira junto com o mapa, como no MiniMap (as 'Steady' ficam fixas).
    do
        local D=NagaMapUI.DS3Theme
        local ring=D and D.mapRing
        if ring then
            if rotateMap and D.wheelRotates and not (settings and settings.frameRotate == false) then ring:SetTextureRotation(-heading,0.5,0.5)
            else ring:SetTextureRotation(0,0.5,0.5) end
        end
    end
    MarkClosest(points,x,y)
    UpdateMapScale(x,y,columns,rows)
    NagaMapUI.Minimap.DrawAreas(view,areaControls,frame.areas,width,height,left,top,cosH,sinH,rotateMap,SIZE)
    local count=0
    local R=SIZE/2
    local function Put(px,py,texture,name,rotation,style,info)
        -- Evento dinâmico: sempre o ícone compacto (nativo é grande demais na borda).
        if info and info.cat=='dynamicevent' then texture=DYNAMIC_EVENT_ICON end
        local sx = px * width - left
        local sy = py * height - top
        if rotateMap then
            -- Move pin position with map, but keep pin icon fixed (no spin).
            local dx, dy = sx - SIZE/2, sy - SIZE/2
            local rx = cosH * dx - sinH * dy
            local ry = sinH * dx + cosH * dy
            sx, sy = rx + SIZE/2, ry + SIZE/2
            rotation = nil  -- pins stay upright, do not rotate with the map
        end
        info = info or style
        local ddx, ddy = sx - SIZE/2, sy - SIZE/2
        local dist = math.sqrt(ddx*ddx + ddy*ddy)
        if dist > R - 10 and info and info.cat and BorderAllowed(info) and dist > 0 then
            -- Pin na borda: só aparece se estiver dentro da distância (metros) configurada.
            -- Missões com círculo azul (alwaysBorder) ignoram o limite de distância.
            if not info.alwaysBorder and BeyondPinLimit(info.cat, px, py, x, y, rows, columns) then return end
            -- Outside the circle: clamp to the edge, pointing toward the real position.
            -- borderPinOffset (px): negativo = mais para dentro do mapa, positivo = mais para fora.
            local edge = R - 14 + (tonumber(settings and settings.borderPinOffset) or 0)
            count=count+1
            NagaMapUI.Minimap.DrawPin(view,pins,count,SIZE/2+ddx/dist*edge,SIZE/2+ddy/dist*edge,texture,name,rotation,style,nil,root)
            if pins[count] then
                local pinSize = math.max(12, math.min(48, tonumber(settings and settings.pinSize) or 22))
                local edgeSize = math.max(10, math.floor(pinSize * 18 / 22 + 0.5))
                local pin = pins[count]
                -- Evento ativo: EventWorld.dds pisca, +1x tamanho e gira horário (1 frame / 0.5s).
                if info and (info.cat=='worldevent' or info.cat=='dynamicevent') then
                    local t=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
                    local phase=math.floor(t/0.5)%2
                    local sz=phase==0 and edgeSize*2 or edgeSize
                    pin:SetDimensions(sz,sz)
                    pin:SetAlpha(phase==0 and 1 or 0.35)
                    -- Horário contínuo; passo visual a cada 0.5s (phase).
                    pin:SetTextureRotation(-(t*2*math.pi))
                else
                    pin:SetDimensions(edgeSize, edgeSize)
                    pin:SetAlpha(1)
                    if pin.SetTextureRotation then pin:SetTextureRotation(0) end
                end
            end
        elseif sx>=0 and sx<=SIZE and sy>=0 and sy<=SIZE then
            count=count+1 NagaMapUI.Minimap.DrawPin(view,pins,count,sx,sy,texture,name,rotation,style,nil,view)
            if pins[count] then
                local pinSize = math.max(12, math.min(48, tonumber(settings and settings.pinSize) or 22))
                local pin = pins[count]
                if info and (info.cat=='worldevent' or info.cat=='dynamicevent') then
                    local t=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
                    local phase=math.floor(t/0.5)%2
                    local sz=phase==0 and pinSize*2 or pinSize
                    pin:SetDimensions(sz,sz)
                    pin:SetAlpha(phase==0 and 1 or 0.35)
                    pin:SetTextureRotation(-(t*2*math.pi))
                else
                    pin:SetDimensions(pinSize, pinSize)
                    pin:SetAlpha(1)
                    if pin.SetTextureRotation then pin:SetTextureRotation(0) end
                end
            end
        end
    end
    for _,point in ipairs(points) do Put(point.x,point.y,point.texture,point.caption,point.rotation,point) end
    -- Pins de grupo/companheiro: furtivo / nadando / montado / pip (sem duplicar nativos).
    local GROUP_DEFAULT='EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds'
    local GROUP_STEALTH='AbyssUI/assets/MiniMap/stealthed.dds'
    local GROUP_SWIM='AbyssUI/assets/MiniMap/swimming.dds'
    local GROUP_MOUNT_LEADER='AbyssUI/assets/MiniMap/mountedLeader.dds'
    local GROUP_MOUNT_MEMBER='AbyssUI/assets/MiniMap/mountedMember.dds'
    local STEALTH_NONE=STEALTH_STATE_NONE or 0
    local STEALTH_DETECTED=STEALTH_STATE_DETECTED or 3
    local MOUNTED_NONE=MOUNTED_STATE_MOUNT_NONE or 0
    local function GroupPinTexture(tag,isLeader)
        -- Furtivo (prioridade)
        if GetUnitStealthState then
            local st=GetUnitStealthState(tag)
            if st and st~=STEALTH_NONE and st~=STEALTH_DETECTED then
                return GROUP_STEALTH
            end
        end
        -- Nadando
        if IsUnitSwimming and IsUnitSwimming(tag) then
            return GROUP_SWIM
        end
        -- Montado: líder → mountedLeader; membro/companheiro → mountedMember
        if GetTargetMountedStateInfo then
            local name=GetUnitName(tag)
            local display=GetUnitDisplayName and GetUnitDisplayName(tag)
            local mountedState
            if name and name~='' then
                local ok,ms=pcall(GetTargetMountedStateInfo,name)
                if ok then mountedState=ms end
            end
            if (not mountedState or mountedState==MOUNTED_NONE) and display and display~='' then
                local ok,ms=pcall(GetTargetMountedStateInfo,display)
                if ok then mountedState=ms end
            end
            if mountedState and mountedState~=MOUNTED_NONE then
                return isLeader and GROUP_MOUNT_LEADER or GROUP_MOUNT_MEMBER
            end
        end
        -- Sem estado especial: pip padrão
        return GROUP_DEFAULT
    end
    for i=1,GROUP_SIZE_MAX do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and not AreUnitsEqual(tag,'player') then
            local gx,gy,gh,visible=GetMapPlayerPosition(tag)
            if visible then
                local isLeader=IsUnitGroupLeader(tag)
                local tex=GroupPinTexture(tag,isLeader)
                Put(gx,gy,tex,GetUnitName(tag),gh,nil,{cat='group',leader=isLeader})
            end
        end
    end
    -- Companheiro: um único pin (furtivo / nadando / montado → mountedMember; senão pip).
    do
        local ctag='companion'
        if DoesUnitExist and DoesUnitExist(ctag) then
            local cx,cy,ch,visible=GetMapPlayerPosition(ctag)
            if visible and cx and cy then
                local tex=GroupPinTexture(ctag,false)
                Put(cx,cy,tex,GetUnitName(ctag),ch,nil,{cat='group',leader=false})
            end
        end
    end
    for i=count+1,#pins do pins[i]:SetHidden(true) end
    -- Player always center. When map rotates, player faces up (0); else rotate pip.
    player:SetDrawLevel(count+2)
    if rotateMap then
        player:SetTextureRotation(0)
    else
        player:SetTextureRotation(heading)
    end
    player:SetHidden(false)
    -- Camera pointer (two-arrow look direction), like Fyr MiniMap.
    if camera then
        local showCam = settings and settings.showCamera ~= false
        camera:SetHidden(not showCam)
        if showCam then
            local cp = cameraHeading
            if rotateMap then
                -- Relative to player heading so the cone shows where the camera looks.
                cp = (cameraHeading - heading) % (math.pi * 2)
            end
            camera:SetTextureRotation(cp, 0.5, CAMERA_PIVOT_Y)
            camera:SetDrawLevel(count+1)
        end
    end
end
local function DefaultMinimapSV()
    -- Defaults from author's tuned profile (NagaMapUI_SavedVariables)
    return {
        zoomBias = 1,
        unlocked = true,
        visible = true,
        showClock = true,
        showZone = true,
        clockPosition = 'bottom',
        zonePosition = 'bottom',
        rotateMap = true,
        showCamera = true,
        playerSize = 24,
        pinSize = 32,
        enabled = true,
        wheelFrame = 'Daedric',
        frameAdjust = -40,
        frameRotate = true,
        mapSize = 250,
        zoneFont = 'trajan',
        zoneFontSize = 18,
        borderPinOffset = -6,
    }
end
local function LayoutOpts()
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    return {
        showClock = false, -- horario removido do minimapa
        showZone = settings.showZone ~= false,
        clockPosition = settings.clockPosition == 'top' and 'top' or 'bottom',
        zonePosition = (settings.zonePosition ~= 'top') and 'bottom' or 'top',
        wheelFrame = 'Daedric',
    }
end
function NagaMapUI.Minimap.ApplyLabelLayout()
    if not root or not view then return end
    if NagaMapUI.Theme and NagaMapUI.Theme.ds3 and NagaMapUI.DS3Theme and NagaMapUI.DS3Theme.LayoutMapLabels then
        NagaMapUI.DS3Theme.LayoutMapLabels(root, view, title, clock, LayoutOpts())
    end
end
function NagaMapUI.Minimap.Initialize()
    NagaMapUI.Minimap.InitializeShared()
    if root then return end
    if NagaMapUI.Settings and not NagaMapUI.Settings.StyleEnabled() then return end
    settings=NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    -- Module switched off in the addon settings: build nothing.
    if settings.enabled == false then return end
    local theme=NagaMapUI.Theme
    -- DS3 ring is 266px; view must be ~250 so the map never overflows the border art.
    if theme.ds3 and NagaMapUI.DS3Theme and NagaMapUI.DS3Theme.MAP_VIEW then
        -- Tamanho do mapa e ajuste da moldura escolhidos pelo usuario no menu.
        local ms = tonumber(settings.mapSize)
        if ms then NagaMapUI.DS3Theme.MAP_VIEW = math.max(150, math.min(400, math.floor(ms + 0.5))) end
        NagaMapUI.DS3Theme.wheelAdjust = math.max(-60, math.min(60, math.floor(tonumber(settings.frameAdjust) or -40)))
        SIZE = NagaMapUI.DS3Theme.MAP_VIEW
    elseif theme.classic then
        SIZE = 248
    end
    local sidebar=theme.MapHost and theme.MapHost() or theme.Sidebar()
    root=WINDOW_MANAGER:CreateControl('NagaMapUIMinimap',sidebar,CT_CONTROL)
    root:SetDimensions(SIZE+16,SIZE+80)
    root:SetAnchor(TOPLEFT,sidebar,TOPLEFT,0,0)
    root:SetMouseEnabled(false)
    NagaMapUI.Theme.mapHeight=SIZE+80
    if not theme.classic and not theme.ds3 then
        NagaMapUI.Theme.Separator(root,34)
        NagaMapUI.Theme.Separator(root,SIZE+39)
        NagaMapUI.Theme.Separator(root,SIZE+77)
    end
    title=Label(root,24) title:SetDimensions(SIZE,32) title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT,root,TOPLEFT,8,0)
    view=WINDOW_MANAGER:CreateControl(nil,root,CT_SCROLL)
    view:SetDimensions(SIZE,SIZE) view:SetAnchor(TOPLEFT,root,TOPLEFT,8,39)
    view:SetScrollBounding(SCROLL_BOUNDING_UNBOUND) view:SetMouseEnabled(true)
    local function Zoom(delta)
        settings.zoomBias=math.max(0.25,math.min(3,settings.zoomBias+delta*0.1)) Update()
    end
    view:SetHandler('OnMouseWheel',function(_,delta) Zoom(delta) end)
    -- Fills the circle wherever there is no map art (same idea as MiniMap's wheelbackground);
    -- it sits below the tiles, and the circular mask on `view` clips it to the ring.
    bg=Texture(view)
    bg:SetDimensions(SIZE,SIZE) bg:SetAnchor(CENTER,view,CENTER,0,0)
    bg:SetTexture('AbyssUI/assets/MiniMap/wheelbackground.dds')
    bg:SetDrawLayer(DL_BACKGROUND) bg:SetDrawLevel(0)
    -- Camera cone like Fyr MiniMap (native texture size ~64px, not scaled to map).
    camera=Texture(view)
    camera:SetDimensions(64, 64)
    camera:SetAnchor(CENTER, view, CENTER, 0, 0)
    camera:SetTexture('AbyssUI/assets/MiniMap/CameraPointer.dds')
    camera:SetDrawLayer(DL_OVERLAY)
    camera:SetDrawLevel(9)
    camera:SetColor(1, 1, 1, 0.9)
    -- Player arrow (MiniMap PlayerPointer size).
    player=Texture(view) player:SetDimensions(32, 32)
    player:SetAnchor(CENTER,view,CENTER,0,0)
    player:SetTexture('AbyssUI/assets/MiniMap/PlayerPointer.dds')
    player:SetDrawLayer(DL_OVERLAY) player:SetDrawLevel(10)
    NagaMapUI.Minimap.ApplyPointerSize()
    clock=Label(root,24) clock:SetAnchor(TOPLEFT,root,TOPLEFT,12,SIZE+44)
    if theme.ds3 then NagaMapUI.DS3Theme.SkinMap(root,view,title,clock,Zoom, LayoutOpts())
    elseif theme.classic then NagaMapUI.ClassicTheme.SkinMap(root,view,title,clock,Zoom) end
    clock:SetHidden(true) -- horario removido do minimapa
    NagaMapUI.Minimap.ApplyTextStyle()
    if settings.visible == false and sidebar then sidebar:SetHidden(true) end
    if sidebar and sidebar.SetMovable then
        sidebar:SetMovable(settings.unlocked ~= false)
    end
    root:SetHandler('OnUpdate',Update)
    -- Missão assistida em outro mapa (cidade): atualiza posição via API do diário.
    EVENT_MANAGER:UnregisterForEvent(QUEST_NS,EVENT_QUEST_POSITION_REQUEST_COMPLETE)
    EVENT_MANAGER:RegisterForEvent(QUEST_NS,EVENT_QUEST_POSITION_REQUEST_COMPLETE,OnQuestPositionComplete)
    EVENT_MANAGER:UnregisterForEvent(QUEST_NS,EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent(QUEST_NS,EVENT_PLAYER_ACTIVATED,function()
        assistedCache=nil
        nextQuestRequest=0
        RequestAssistedQuestPosition()
    end)
    EVENT_MANAGER:UnregisterForEvent(QUEST_NS,EVENT_QUEST_ADVANCED)
    EVENT_MANAGER:RegisterForEvent(QUEST_NS,EVENT_QUEST_ADVANCED,function()
        assistedCache=nil
        nextQuestRequest=0
    end)
    RequestAssistedQuestPosition()
end
function NagaMapUI.Minimap.SetUnlocked(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.unlocked = v and true or false
    local host = NagaMapUI.Theme and NagaMapUI.Theme.MapHost and NagaMapUI.Theme.MapHost()
    if host and host.SetMovable then host:SetMovable(settings.unlocked) end
end
function NagaMapUI.Minimap.SetEnabled(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.enabled = v and true or false
    if settings.enabled and not root then
        -- Was off at login: build it now.
        pcall(NagaMapUI.Minimap.Initialize)
        if not root then d('[AbyssUI] Minimapa ativado. Use /reloadui se ele não aparecer.') end
    end
    local host = NagaMapUI.Theme and NagaMapUI.Theme.MapHost and NagaMapUI.Theme.MapHost()
    if host then host:SetHidden(not (settings.enabled and settings.visible ~= false)) end
end
function NagaMapUI.Minimap.SetVisible(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.visible = v and true or false
    local host = NagaMapUI.Theme and NagaMapUI.Theme.MapHost and NagaMapUI.Theme.MapHost()
    if host then host:SetHidden(not (settings.visible and settings.enabled ~= false)) end
end
function NagaMapUI.Minimap.SetZoomBias(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.zoomBias = math.max(0.25, math.min(3, tonumber(v) or 1))
end
function NagaMapUI.Minimap.ApplyPointerSize()
    local size = math.max(8, math.min(96, tonumber(settings and settings.playerSize) or 32))
    if player then player:SetDimensions(size, size) end
    -- Camera cone keeps the original 4:1 look relative to the old 16px arrow (32px arrow -> 64px cone).
    if camera then
        local cam = size * 2
        camera:SetDimensions(cam, cam)
        -- CameraPointer.dds has its V vertex below the texture center (~66% of its height).
        -- Shift it up so that vertex sits on the player arrow, and rotate around that same point.
        camera:ClearAnchors()
        camera:SetAnchor(CENTER, view, CENTER, 0, -(CAMERA_PIVOT_Y - 0.5) * cam)
    end
end
function NagaMapUI.Minimap.SetPlayerSize(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.playerSize = math.max(8, math.min(96, tonumber(v) or 32))
    NagaMapUI.Minimap.ApplyPointerSize()
end
-- Reaplica tamanho do mapa / moldura em tempo real (tema DS3).
local function ReapplySize()
    local D = NagaMapUI.DS3Theme
    if not (root and view and D and D.SetWheelFrame and NagaMapUI.Theme and NagaMapUI.Theme.ds3) then return end
    D.MAP_VIEW = SIZE
    view:SetDimensions(SIZE, SIZE)
    if bg then bg:SetDimensions(SIZE, SIZE) end
    D.SetWheelFrame('Daedric', root, view, title, clock, LayoutOpts())
end
function NagaMapUI.Minimap.SetMapSize(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.mapSize = math.max(150, math.min(400, math.floor((tonumber(v) or 250) + 0.5)))
    local D = NagaMapUI.DS3Theme
    if root and D and NagaMapUI.Theme and NagaMapUI.Theme.ds3 then
        SIZE = settings.mapSize
        ReapplySize()
    end
end
-- Fontes: as mesmas ja usadas no addon (Game Small/Medium, Antique, Trajan, Univers, Chat).
local FONT_FALLBACK = {
    gameSmall='$(BOLD_FONT)', gameMedium='$(MEDIUM_FONT)', antique='$(ANTIQUE_FONT)',
    trajan='EsoUI/Common/Fonts/TrajanPro-Regular.slug',
    univers='EsoUI/Common/Fonts/Univers57.slug', chat='$(CHAT_FONT)',
}
local function FontFace(key)
    local bv = NAGA_UI and NAGA_UI.BarVisuals
    return (bv and bv.Fonts and bv.Fonts[key]) or FONT_FALLBACK[key]
end
function NagaMapUI.Minimap.ApplyTextStyle()
    if not settings then return end
    local function Set(ctrl, key, size, defSize)
        if not ctrl then return end
        size = math.max(8, math.min(32, math.floor((tonumber(size) or defSize) + 0.5)))
        local face = key and key ~= 'theme' and FontFace(key) or nil
        if face then ctrl:SetFont(face..'|'..size..'|soft-shadow-thick')
        else ctrl:SetFont(NagaMapUI.Theme.Font(size)) end
    end
    Set(title, settings.zoneFont, settings.zoneFontSize, 18)
end
function NagaMapUI.Minimap.SetZoneFont(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.zoneFont = v or 'theme'
    NagaMapUI.Minimap.ApplyTextStyle()
end
function NagaMapUI.Minimap.SetZoneFontSize(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.zoneFontSize = tonumber(v) or 18
    NagaMapUI.Minimap.ApplyTextStyle()
end
function NagaMapUI.Minimap.SetBorderPinOffset(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.borderPinOffset = math.max(-60, math.min(80, math.floor((tonumber(v) or 0) + 0.5)))
end
function NagaMapUI.Minimap.SetFrameRotate(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.frameRotate = v and true or false
end
function NagaMapUI.Minimap.SetFrameAdjust(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.frameAdjust = math.max(-60, math.min(60, math.floor(tonumber(v) or 0)))
    local D = NagaMapUI.DS3Theme
    if D then D.wheelAdjust = settings.frameAdjust end
    ReapplySize()
end
function NagaMapUI.Minimap.SetWheelFrame(name)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.wheelFrame = 'Daedric'
    local D = NagaMapUI.DS3Theme
    if root and view and D and D.SetWheelFrame and NagaMapUI.Theme and NagaMapUI.Theme.ds3 then
        D.SetWheelFrame('Daedric', root, view, title, clock, LayoutOpts())
    end
end
function NagaMapUI.Minimap.SetPinSize(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.pinSize = math.max(12, math.min(48, tonumber(v) or 22))
end
function NagaMapUI.Minimap.SetPinDistance(cat,v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    if PIN_DIST_CATS[cat] then settings['pinDistM_'..cat] = math.max(0, math.min(5000, tonumber(v) or 0)) end
end
function NagaMapUI.Minimap.SetBorderOption(key,v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    if BORDER_DEFAULTS[key] ~= nil then settings[key] = v and true or false end
end
function NagaMapUI.Minimap.SetRotateMap(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.rotateMap = v and true or false
end
function NagaMapUI.Minimap.SetShowCamera(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.showCamera = v and true or false
end
function NagaMapUI.Minimap.SetShowZone(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.showZone = v and true or false
    NagaMapUI.Minimap.ApplyLabelLayout()
end
function NagaMapUI.Minimap.SetZonePosition(v)
    settings = settings or NagaMapUI.SavedVariables.Account('minimap', DefaultMinimapSV())
    settings.zonePosition = (v == 'bottom') and 'bottom' or 'top'
    NagaMapUI.Minimap.ApplyLabelLayout()
end
