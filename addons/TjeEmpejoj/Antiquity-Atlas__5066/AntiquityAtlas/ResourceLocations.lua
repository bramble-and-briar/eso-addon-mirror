local A=AntiquityAtlas
local PIN="ANTIQUITY_ATLAS_RESOURCE_PIN"
local names={
 chest={"Treasure chest","Сундук"}, safebox={"Safebox or justice container","Сейф или контейнер для кражи"}, fishing={"Fishing spot","Рыболовное место"},
 trove={"Thieves trove","Воровской клад"}, treasure_map={"Treasure map dig site","Место раскопки карты сокровищ"},
 wood={"Woodworking node","Древесина"}, ore={"Ore or jewelry node","Руда или ювелирный материал"},
 cloth={"Clothing node","Ткань"}, enchanting={"Runestone","Рунный камень"},
 psijic={"Potential Psijic portal site","Возможное место портала Псиджиков"}, alchemy={"Alchemy node","Алхимический ресурс"},
 clam={"Giant clam","Гигантский моллюск"}, heavy_sack={"Heavy sack","Тяжёлый мешок"},
}
function A.ResourceName(kind)
 local item=names[kind] or {kind,kind};return A.SourceLabel(item[1],item[2])
end
local function harvestReady()
 return type(Harvest)=="table" and type(Harvest.Data)=="table" and type(Harvest.Data.mapCaches)=="table"
  and type(Harvest.Data.GetMapCache)=="function" and type(Harvest.mapTools)=="table"
  and type(Harvest.mapTools.GetViewedMapMetaData)=="function"
end
function A.CanShowResources(part)
 local info=part and A.SourceInfo[part.id]
 if not info or not info.resources then return false end
 if harvestReady() then return true end
 for _,kind in ipairs(info.resources) do
  if kind=="chest" or kind=="trove" or kind=="fishing" or kind=="treasure_map" then return true end
 end
 return false
end
local function mapPinsSaved(root,key)
 if type(root)~="table" then return end
 local profile=root.Default or root[A.Call(GetWorldName)]
 local account=type(profile)=="table" and profile[A.Call(GetDisplayName)]
 local data=type(account)=="table" and account["$AccountWide"]
 return type(data)=="table" and data[key]
end
function A.CurrentResourcePoints(part)
 local info=part and A.SourceInfo[part.id]
 local key=A.MapTextureKey(A.Call(GetMapTileTexture,1))
 local mapId=A.Call(GetCurrentMapId)
 local status={harvest="not_ready",mapPins=0,harvestMap=0}
 if not info or not info.resources or not key or not mapId then return {},status end
 local points,seen={},{}
 local function add(x,y,kind,provider)
  if type(x)~="number" or type(y)~="number" or x<=0 or x>=1 or y<=0 or y>=1 then return end
  local signature=kind..":"..math.floor(x*10000+0.5)..":"..math.floor(y*10000+0.5)
  if seen[signature] then return end
  seen[signature]=true
  if provider=="HarvestMap" then status.harvestMap=status.harvestMap+1 else status.mapPins=status.mapPins+1 end
  points[#points+1]={x=x,y=y,kind=kind,provider=provider,mapId=mapId,key=key,icon=part.icon}
 end
 local requested={}
 for _,kind in ipairs(info.resources) do
  requested[kind]=true
  local lists={}
  local chests=(A.ResourceChests or {})[key]
  if kind=="chest" then
   lists={chests and chests[1],mapPinsSaved(MP_ChestData,key)}
  elseif kind=="trove" then
   lists={chests and chests[2],mapPinsSaved(MP_ThievesTrove,key)}
  elseif kind=="fishing" then
   lists={(A.ResourceFishing or {})[key]}
   if key=="u48_overland_base" then lists={(A.ResourceFishing or {})[key.."_west"],(A.ResourceFishing or {})[key.."_east"]} end
  elseif kind=="treasure_map" then lists={(A.ResourceTreasureMaps or {})[key]} end
  -- pairs preserves later providers when an earlier optional list is nil.
  for _,list in pairs(lists) do
   for _,point in pairs(type(list)=="table" and list or {}) do
    if type(point)=="table" and (kind~="fishing" or not info.water or point[3]==info.water) then add(point[1],point[2],kind,"Map Pins") end
   end
  end
 end
 if harvestReady() then
  status.harvest="wrong_map"
  local meta=A.Method(Harvest.mapTools,"GetViewedMapMetaData")
  if type(meta)=="table" and meta.mapId==mapId then
   status.harvest="no_cache"
   local cache=A.Method(Harvest.Data,"GetMapCache",meta)
   if type(cache)=="table" and cache.mapMetaData==meta and type(cache.pinTypeId)=="table" then
    status.harvest="ready"
    local types={
        chest={Harvest.CHESTS},safebox={Harvest.JUSTICE},fishing={Harvest.FISHING},trove={Harvest.TROVE},
     heavy_sack={Harvest.HEAVYSACK},wood={Harvest.WOODWORKING},ore={Harvest.BLACKSMITH,Harvest.JEWELRY},
     cloth={Harvest.CLOTHING},enchanting={Harvest.ENCHANTING},psijic={Harvest.PSIJIC,Harvest.ENCHANTING},
     alchemy={Harvest.MUSHROOM,Harvest.FLOWER,Harvest.WATERPLANT,Harvest.HERBALIST,Harvest.CRIMSON},clam={Harvest.CLAM},
    }
    local byType={}
    for kind in pairs(requested) do for _,id in pairs(types[kind] or {}) do if id and not (kind=="fishing" and info.water) then byType[id]=kind end end end
    if requested.enchanting and Harvest.ENCHANTING then byType[Harvest.ENCHANTING]="enchanting" end
    A.Method(cache,"RegisterAccess","AntiquityAtlas")
    for nodeId,pinType in pairs(cache.pinTypeId) do
     local kind=byType[pinType]
     if kind and type(cache.GetLocal)=="function" then
      local x,y=cache:GetLocal(nodeId)
      add(x,y,kind,"HarvestMap")
     end
    end
    A.Method(cache,"UnregisterAccess","AntiquityAtlas")
   end
  end
 end
 table.sort(points,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end;if a.x~=b.x then return a.x<b.x end;return a.y<b.y end)
 return points,status
end
function A.ClearResourceOverlay()
 A.resourceOverlay=nil
 if A.resourcePinsRegistered then ZO_WorldMap_RefreshCustomPinsOfType(_G[PIN]) end
end
function A.ResourceWaypoint(point)
 if point and A.Call(GetCurrentMapId)==point.mapId and A.MapTextureKey(A.Call(GetMapTileTexture,1))==point.key
  and type(PingMap)=="function" then
  PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT,MAP_TYPE_LOCATION_CENTERED,point.x,point.y)
 end
end
local function pinPoint(pin)
 if not pin then return end
 if type(pin.GetPinTypeAndTag)=="function" then local _,point=pin:GetPinTypeAndTag();return point end
 return pin.m_PinTag
end
function A.InitResourcePins()
 if A.resourcePinsRegistered or type(ZO_WorldMap_AddCustomPin)~="function" then return end
 ZO_WorldMap_AddCustomPin(PIN,function(manager)
  local overlay=A.resourceOverlay
  if overlay and overlay.mapId==A.Call(GetCurrentMapId) and overlay.key==A.MapTextureKey(A.Call(GetMapTileTexture,1)) then
   for i=1,math.min(#overlay.points,1500) do local p=overlay.points[i];manager:CreatePin(_G[PIN],p,p.x,p.y) end
  end
 end,nil,{level=110,size=26,texture=function(pin) return pin and pin.m_PinTag and pin.m_PinTag.icon or "/esoui/art/icons/icon_missing.dds" end},
 {tooltip=(ZO_MAP_TOOLTIP_MODE and ZO_MAP_TOOLTIP_MODE.INFORMATION) or 1,creator=function(pin)
  local p=pinPoint(pin);if not p then return end
  if A.Call(IsInGamepadPreferredMode) then return end
  InformationTooltip:AddLine(A.ResourceName(p.kind).." — "..p.provider)
  InformationTooltip:AddLine(A.SourceLabel("Known spawn location; it may currently be empty.","Известное место появления; сейчас оно может быть пустым."))
  if p.kind=="treasure_map" then InformationTooltip:AddLine(A.SourceLabel("Requires the corresponding treasure map.","Нужна соответствующая карта сокровищ.")) end
  InformationTooltip:AddLine(A.SourceLabel("Left click: set waypoint.","Левая кнопка мыши: поставить точку."))
 end})
 ZO_WorldMap_SetCustomPinEnabled(_G[PIN],true)
 if ZO_MapPin and ZO_MapPin.PIN_CLICK_HANDLERS and ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_LEFT] then
  ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_LEFT][_G[PIN]]={{name=A.SourceLabel("Set waypoint","Поставить точку"),callback=function(pin) A.ResourceWaypoint(pinPoint(pin)) end}}
 end
 A.resourcePinsRegistered=true
end
function A.ShowResourcePoints(part,attempt)
 A.ClearSourceHighlight();A.InitResourcePins()
 local points,status=A.CurrentResourcePoints(part)
 if status.harvest=="wrong_map" and (attempt or 0)<3 then
  local request,mapId,key=A.mapRequest,A.Call(GetCurrentMapId),A.MapTextureKey(A.Call(GetMapTileTexture,1))
  zo_callLater(function()
   if request==A.mapRequest and mapId==A.Call(GetCurrentMapId) and key==A.MapTextureKey(A.Call(GetMapTileTexture,1)) then A.ShowResourcePoints(part,(attempt or 0)+1) end
  end,100)
  return
 end
 A.resourceOverlay={points=points,mapId=A.Call(GetCurrentMapId),key=A.MapTextureKey(A.Call(GetMapTileTexture,1))}
 if A.resourcePinsRegistered then ZO_WorldMap_RefreshCustomPinsOfType(_G[PIN]) end
 if #points==0 then
  local kinds={};for _,kind in ipairs(A.SourceInfo[part.id].resources) do kinds[#kinds+1]=A.ResourceName(kind) end
  d("Antiquity Atlas: "..A.SourceLabel("no recorded locations on this map for: ","на этой карте нет записанных мест для: ")..table.concat(kinds,", ")..".")
  local message=status.harvest=="ready" and A.SourceLabel("HarvestMap loaded; no matching points recorded.","HarvestMap загружен; подходящих точек в записях нет.")
   or A.SourceLabel("HarvestMap data for this map is unavailable.","Данные HarvestMap для этой карты недоступны.")
  d("Antiquity Atlas: "..message)
  return
 end
 local minX,minY,maxX,maxY=1,1,0,0
 for _,point in ipairs(points) do minX=math.min(minX,point.x);minY=math.min(minY,point.y);maxX=math.max(maxX,point.x);maxY=math.max(maxY,point.y) end
 if type(ZO_WorldMap_PanToNormalizedPosition)=="function" then ZO_WorldMap_PanToNormalizedPosition((minX+maxX)/2,(minY+maxY)/2) end
 if #points==1 then A.ResourceWaypoint(points[1]) end
 d("Antiquity Atlas: "..string.format(A.SourceLabel("showing %d of %d known spawn positions; availability is not guaranteed.","показано %d из %d известных мест появления; наличие объекта не гарантировано."),math.min(#points,1500),#points))
end
function A.OpenResourceMap(part,owner)
 if not A.IsResourceSource(part) then return end
 A.ClearResourceOverlay()
 local choices,seen={},{}
 local function add(zone,mapId,region)
  local signature=mapId and ("m"..mapId) or ("z"..zone)
  if not seen[signature] then seen[signature]=true;choices[#choices+1]={id=zone,mapId=mapId,resources=true,region=region} end
 end
 local targets=A.ResolveSourceZones(part)
 if #targets>0 then
  A.BuildInstanceMapIndex()
  for _,target in ipairs(targets) do
   local maps=not target.region and (A.instanceMapLists or {})[target.id]
   if maps and #maps>0 then for _,mapId in ipairs(maps) do add(target.id,mapId) end
   else add(target.id,nil,target.region) end
  end
 else
  local alternatives=({[101012]={1027,1011},[101013]={101,103},[101014]={181,584},[101015]={1207,1160},[101017]={1383,1318},[101018]={1413,1414}})[part.findZoneId]
  if alternatives then for _,zone in ipairs(alternatives) do add(zone) end
  elseif part.findZoneId==101010 then
   local zone=A.Call(GetZoneId,A.Call(GetUnitZoneIndex,"player"));if zone and zone>0 then add(zone) end
  elseif part.findZoneId and part.findZoneId<100000 then add(part.findZoneId) end
 end
 if #choices==1 then A.OpenZoneMap(choices[1].id,part,true,choices[1])
 elseif #choices>1 then
  ClearMenu()
  for _,choice in ipairs(choices) do local selected=choice
   local name=A.DisplayName((choice.mapId and A.Call(GetMapNameById,choice.mapId)) or A.ZoneName(choice.id))
   AddMenuItem(name,function() A.OpenZoneMap(selected.id,part,true,selected) end)
  end
  ShowMenu(owner or A.window)
 else d("Antiquity Atlas: "..A.SourceLabel("no single map for this source.","для этого источника нет единственной карты.")) end
end
