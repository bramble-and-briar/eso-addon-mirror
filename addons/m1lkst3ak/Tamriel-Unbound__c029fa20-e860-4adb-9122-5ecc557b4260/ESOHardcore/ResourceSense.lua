-- Hardcore-owned native harvest compass observer. No external addon required.
local N=ESOHardcore
local S={active={},resolved={},scale=1,revision=0,controlErrors=0}
local function changed() S.revision=S.revision+1 end
N.resourceSense=S
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<1e8 end
local function reset() S.active={};S.resolved={};S.zone=nil;changed() end
function ESOHCResourceAppeared(control)
 if control then S.active[control]={};S.resolved[control]=nil;changed() end
end
function ESOHCResourceDisappeared(control)
 if control and S.active[control] then S.active[control]=nil;S.resolved[control]=nil;changed() end
end
function S.markHarvested(zone,x,z,kind)
 local best,bd
 for id,v in pairs(S.resolved) do
  local row=S.active[id]
  if row and not row.harvested and v.zone==zone and (not v.kind or kind=="generic" or v.kind==kind) then
   local d=(v.worldX-x)^2+(v.worldY-z)^2
   if d<49 and (not bd or d<bd) then best,bd=row,d end
  end
 end
 if best then best.harvested=true;changed() end
end
local function calibrate()
 local rz,rx,ry,rr=GetUnitRawWorldPosition('player')
 local wz,wx,wy,wr=GetUnitWorldPosition('player')
 if rz~=S.zone then S.zone=rz;S.scale=1 end
 if not finite(rx) or not finite(wx) then return end
 local a=GetNormalizedWorldPosition(rz,rx+1000,ry,rr)-GetNormalizedWorldPosition(rz,rx,ry,rr)
 local b=GetRawNormalizedWorldPosition(wz,wx+1000,wy,wr)-GetRawNormalizedWorldPosition(wz,wx,wy,wr)
 if finite(a) and finite(b) and math.abs(a)>1e-9 and b/a>=.25 and b/a<=4 then S.scale=b/a else S.scale=1 end
end
local resourceNames={}
for name in ('maple|oak|beech|hickory|yew|ash|birch|mahogany|nightwood|ruby ash wood|scrap wood'):gmatch("[^|]+") do resourceNames[name]="wood" end
for name in ('jute|flax|cotton|spidersilk|ebonthread|kreshweed|ironweed|silverweed|void bloom|ancestor silk|torn cloth'):gmatch("[^|]+") do resourceNames[name]="cloth" end
for name in ('runestone'):gmatch("[^|]+") do resourceNames[name]="rune" end
for name in ('pure water|water skin|potable liquids'):gmatch("[^|]+") do resourceNames[name]="water" end
for name in ("blessed thistle|wormwood|lady's smock|bugloss|dragonthorn|mountain flower|columbine|corn flower|nirnroot|water hyacinth|stinkhorn|blue entoloma|emetic russula|violet coprinus|namira's rot|white cap|luminous russula|imp stool|nightshade|crimson nirnroot|herbalist's satchel"):gmatch("[^|]+") do resourceNames[name]="alchemy" end
local function classify(name)
 if type(name)~="string" then return end
 name=name:lower():gsub("%^%a+", ""):gsub("^%s+", ""):gsub("%s+$", "")
 return resourceNames[name] or ((name:find(" ore$",1) or name:find(" seam$",1)) and "ore") or (name:find("runestone",1,true) and "rune")
end
local function readTypes(container)
 for i=1,container:GetNumCenterOveredPins() do
  if container:GetCenterOveredPinType(i)==MAP_PIN_TYPE_HARVEST_NODE then
   local kind=classify(container:GetCenterOveredPinDescription(i))
   if kind then
    local _,level=container:GetCenterOveredPinLayerAndLevel(i)
    local match
    for control,row in pairs(S.active) do
     local ok,yes=pcall(function() return control:GetDrawLevel()==level and math.abs(2*(control:GetCenter()-container:GetLeft())/container:GetWidth()-1)<.14 end)
     if ok and yes then if match then match=nil;break end;match=control end
    end
    if match and S.active[match].kind~=kind then
     S.active[match].kind=kind
     if S.resolved[match] then S.resolved[match].kind=kind end
     changed()
    end
   end
  end
 end
end
local function scan()
 if not ZO_CompassContainer or ZO_CompassContainer:IsHidden() then return end
 if not next(S.active) then return end
 pcall(readTypes,ZO_CompassContainer)
 local zone=GetUnitRawWorldPosition('player')
 if zone~=S.zone then S.resolved={};changed();for _,row in pairs(S.active) do row.samples=nil end;calibrate() end
 if not S.camera then S.camera=WINDOW_MANAGER:CreateControl('ESOHCResourceCamera',GuiRoot,CT_CONTROL);S.camera:Create3DRenderSpace() end
 Set3DRenderSpaceToCurrentCamera(S.camera:GetName())
 local cx,ch,cz=S.camera:Get3DRenderSpaceOrigin()
 cx,ch,cz=GuiRender3DPositionToWorldPosition(cx,ch,cz)
 local fx,_,fz=S.camera:Get3DRenderSpaceForward()
 local rx,_,rz=S.camera:Get3DRenderSpaceRight()
 local fl=math.sqrt(fx*fx+fz*fz)
 if fl<.001 then return end
 local left,width=ZO_CompassContainer:GetLeft(),ZO_CompassContainer:GetWidth()
 if width<=0 then return end
 for control,row in pairs(S.active) do
  local ok,err=pcall(function()
  if control:IsHidden() then
   if S.resolved[control] then S.resolved[control]=nil;changed() end
   row.samples=nil;return
  end
  do
   local x=2*(control:GetCenter()-left)/width-1
   local dist=(2-control:GetScale())*100*S.scale
   -- Smooth approximation of the native compass's nonlinear angular mapping.
   -- Require stable consecutive samples; reject edge measurements.
   if finite(x) and finite(dist) and math.abs(x)<.98 and dist>=0 and dist<190 then
    local u=math.abs(x)
    local slope=x*(0.62658117 + u*(1.49067028 + u*(-2.98275289 + u*2.36038436)))
    local dx,dz=fx/fl+rx*slope,fz/fl+rz*slope
    local length=math.sqrt(dx*dx+dz*dz)
    if length>.001 then
     local px,pz=cx/100+dx/length*dist,cz/100+dz/length*dist
     local samples=row.samples or {};row.samples=samples
     samples[#samples+1]={px,pz};if #samples>3 then table.remove(samples,1) end
     if #samples==3 then
      local ax,az=0,0;for _,p in ipairs(samples) do ax=ax+p[1]/3;az=az+p[2]/3 end
      local stable=true;for _,p in ipairs(samples) do if (p[1]-ax)^2+(p[2]-az)^2>9 then stable=false end end
      if stable then
       local prev=S.resolved[control]
       if not prev or (prev.worldX-ax)^2+(prev.worldY-az)^2>1 or prev.kind~=row.kind then
        S.resolved[control]={worldX=ax,worldY=az,zone=zone,kind=row.kind};changed()
       end
       row.lastMeasured=GetFrameTimeMilliseconds()
      end
     end
    end
   end
  end
  if S.resolved[control] and (not row.lastMeasured or GetFrameTimeMilliseconds()-row.lastMeasured>1500) then S.resolved[control]=nil;row.samples=nil;changed() end
  end)
  if not ok then
   S.controlErrors=S.controlErrors+1;S.lastControlError=tostring(err)
   if S.resolved[control] then S.resolved[control]=nil;changed() end
   row.samples=nil
  end
 end
end
EVENT_MANAGER:RegisterForEvent('ESOHCResourceSenseOff',EVENT_PLAYER_DEACTIVATED,reset)
EVENT_MANAGER:RegisterForEvent('ESOHCResourceSenseOn',EVENT_PLAYER_ACTIVATED,function() pcall(calibrate) end)
EVENT_MANAGER:RegisterForUpdate('ESOHCResourceSenseScan',50,function()
 local ok,err=pcall(scan);S.error=not ok and tostring(err) or nil
end)
