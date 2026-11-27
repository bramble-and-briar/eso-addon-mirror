-- Independent in-world resource markers; no world-map registration.
local N=ESOHardcore;local R=N.rewards;local s=N.safe
local root,pool=nil,{};local bearingRoot,bearingPool=nil,{};local grounded={};local bearingCount=0;local selected={};local failure,sourceStatus;local visibleCount=0;local lastScan=0;local lastZone,lastCharacter,lastRank,lastRevision
local function character() return N.hardcore and N.hardcore.saved end
local function eligible(l) local a=character();return a and a.active and not a.fallen and N.rank('Harvesting')>=l end
local function position()
 local zone,x,h,z=s(GetUnitRawWorldPosition,'player');if type(zone)=='number' and zone>0 and type(x)=='number' and type(h)=='number' and type(z)=='number' then return zone,x/100,h/100,z/100 end
end
local function records() local a=character();return a and a.harvestWorld or {} end
local function hide() if root then root:SetHidden(true) end;if bearingRoot then bearingRoot:SetHidden(true) end;visibleCount=0;bearingCount=0 end
local function valid(v) return type(v)=='number' and v==v and math.abs(v)<1000000 end
local colors={ore={.55,.70,1},wood={1,.57,.24},cloth={.27,1,.68},rune={.77,.36,1},alchemy={.68,1,.22},water={.18,.76,1},generic={1,.76,.22}}
local function kind(link)
 local t=link and s(GetItemLinkItemType,link);if t==nil then return 'generic' end
 if t==ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or t==ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then return 'ore' end
 if t==ITEMTYPE_WOODWORKING_RAW_MATERIAL then return 'wood' end
 if t==ITEMTYPE_CLOTHIER_RAW_MATERIAL then return 'cloth' end
 if t==ITEMTYPE_ENCHANTING_RUNE_ASPECT or t==ITEMTYPE_ENCHANTING_RUNE_ESSENCE or t==ITEMTYPE_ENCHANTING_RUNE_POTENCY then return 'rune' end
 if t==ITEMTYPE_REAGENT then return 'alchemy' end
 if t==ITEMTYPE_POTION_BASE or t==ITEMTYPE_POISON_BASE then return 'water' end
 return 'generic'
end
local old=N.recordNode
function N.recordNode(link,qty)
 old(link,qty)
 if not eligible(15) then return end
 local zone,x,h,z=position();if not zone then return end
 local a=character();a.harvestWorld=a.harvestWorld or {};local t=a.harvestWorld
 local key=zone..':'..math.floor(x/3)..':'..math.floor(h/4)..':'..math.floor(z/3)
 if t[key] then t[key].visits=(t[key].visits or 1)+1;t[key].kind=kind(link) else
  t[key]={zone=zone,x=x,h=h,z=z,kind=kind(link),visits=1}
 end
 lastScan=0
end
local function providerKind(H,t)
 if t==H.BLACKSMITH or t==H.JEWELRY then return 'ore' elseif t==H.CLOTHING then return 'cloth' elseif t==H.WOODWORKING then return 'wood' elseif t==H.ENCHANTING then return 'rune' elseif t==H.WATER then return 'water' else return 'alchemy' end
end
local importedZone, importedRows=nil,{}
local function importedFor(zone)
 if importedZone==zone then return importedRows end
 importedZone=zone;importedRows={}
 local blob=N.importedHarvest and N.importedHarvest[zone]
 if type(blob)=='string' then
  for a,b,c,k in blob:gmatch('([%-%.%d]+),([%-%.%d]+),([%-%.%d]+),(%a+)') do
   importedRows[#importedRows+1]={zone=zone,x=tonumber(a),h=tonumber(b),z=tonumber(c),kind=k,community=true}
  end
 end
 return importedRows
end
-- Only show live native compass detections supplied by Hardcore ResourceSense. Never infer spawn from a saved coordinate.
local function nearest(zone,x,h,z,radius,withProvider)
 local list={};grounded={};local range2=radius*radius
 local native=N.resourceSense;local pins=native and native.resolved
 if type(pins)~='table' then sourceStatus='Native resource detector unavailable.';return list end
 -- A transient detector failure must not suppress still-active resolved nodes.
 local known={};for _,v in pairs(records()) do if v.zone==zone and valid(v.x) and valid(v.h) and valid(v.z) then known[#known+1]=v end end
 local personalCount=#known
 if withProvider then for _,v in ipairs(importedFor(zone)) do known[#known+1]=v end end
 local live=0;local unresolved=0;local rejected=0;local used={}
 
 for id,v in pairs(pins) do
  if valid(v.worldX) and valid(v.worldY) and native.active[id] and v.zone==zone then
   local dx,dz=v.worldX-x,v.worldY-z;local dd=dx*dx+dz*dz
   if dd<=range2 then
    live=live+1;local best,bd
    local ambiguous=false
    for _,q in ipairs(known) do
     local d2=(q.x-v.worldX)^2+(q.z-v.worldY)^2
     if d2<=25 and (not v.kind or q.kind==v.kind or q.kind=="generic") then
      -- Horizontal matches alone cannot distinguish stacked terrain or interiors.
      -- A suspect high site keeps its compass cue; never substitute player height.
      local horizontal=math.sqrt((q.x-x)^2+(q.z-z)^2)
      local rise=q.h-h
      local ceiling=math.min(12,3+horizontal*.12)
      if rise<=ceiling then
       local score=d2+math.min(4,math.abs(rise)*.02)
       if best and math.abs(q.h-best.h)>4 and math.abs(score-bd)<=4 then ambiguous=true end
       if not bd or score<bd then best,bd=q,score end
      else rejected=rejected+1 end
     end
    end
    if ambiguous then best=nil;rejected=rejected+1 end
    -- A live compass bearing resolves horizontal position only. Do not invent altitude.
    -- Snap to a recorded 3D site, as a live compass signal is not a terrain-height query.
    if best then
     local key=best
     if not used[key] then
      used[key]=true
      local ex,ez=best.x-x,best.z-z
      list[#list+1]={x=best.x,h=best.h,z=best.z,kind=v.kind or best.kind or 'generic',distance=ex*ex+ez*ez,community=best.community,control=id,record=best}
     end
    else unresolved=unresolved+1 end
   end
  end
 end
 table.sort(list,function(a,b)return a.distance<b.distance end)
 sourceStatus=live..' live signals | '..personalCount..' personal sites | '..unresolved..' unmatched / no reliable elevation | '..rejected..' suspect height matches | '..tostring(native.controlErrors or 0)..' isolated control errors.'..(native.error and (' Detector retry: '..native.error) or '')
 return list
end
local function ensureRoot()
 if root then return end
 root=WINDOW_MANAGER:CreateTopLevelWindow('ESOHCWorldResources');root:SetHidden(true);root:SetMouseEnabled(false);root:Create3DRenderSpace()
end
local function marker(i)
 if pool[i] then return pool[i] end
 -- Separate world anchor from billboard. Rotate the anchor around its base;
 -- the texture's height is a local offset, never part of the world coordinate.
 local anchor=WINDOW_MANAGER:CreateControl('ESOHCWorldResource'..i,root,CT_CONTROL)
 anchor:SetHidden(true);anchor:SetMouseEnabled(false);anchor:Create3DRenderSpace()
 anchor:Set3DRenderSpaceUsesDepthBuffer(true)
 local aura=WINDOW_MANAGER:CreateControl('ESOHCWorldResourceAura'..i,anchor,CT_TEXTURE)
 aura:SetMouseEnabled(false);aura:Create3DRenderSpace();aura:Set3DRenderSpaceUsesDepthBuffer(true)
 aura:SetTexture('ESOHardcore/HarvestAura.dds')
 if TEX_BLEND_MODE_ALPHA then aura:SetBlendMode(TEX_BLEND_MODE_ALPHA) end
 local p={anchor=anchor,aura=aura};pool[i]=p
 return p
end
local function appearance(v,dist2,now,index)
 local dist=math.sqrt(math.max(0,dist2 or 0))
 local pulse=(math.sin((now or 0)/240 + index*0.55)+1)/2
 local drift=(math.cos((now or 0)/520 + index*0.31)+1)/2
 -- Larger at distance to resist perspective shrinkage; same visibility for undiscovered sites.
 local scale=1+math.min(2.5,dist/65)
 local alpha=.90+.10*pulse
 local width=(2.1+.18*pulse)*scale
 local height=4.8
 local hover=height*.50
 return 'ESOHardcore/HarvestAura.dds',width,height,hover,alpha
end
-- A live compass signal exposes bearing, not terrain altitude. At mastery, show
-- a separate icon-free direction cue for unmatched signals, never a fake 3D position.
local function bearings(rank)
 bearingCount=0
 if rank<99 then if bearingRoot then bearingRoot:SetHidden(true) end;return end
 local native=N.resourceSense;local compass=ZO_CompassContainer
 if not native or not compass or compass:IsHidden() then if bearingRoot then bearingRoot:SetHidden(true) end;return end
 local left,right=compass:GetLeft(),compass:GetRight()
 if not valid(left) or not valid(right) or right<=left then if bearingRoot then bearingRoot:SetHidden(true) end;return end
 for control,row in pairs(native.active or {}) do
  if not grounded[control] then
   pcall(function()
    local cx=control:GetCenter()
    if not valid(cx) or cx<left or cx>right then return end
    if not bearingRoot then bearingRoot=WINDOW_MANAGER:CreateTopLevelWindow('ESOHCResourceBearings');bearingRoot:SetAnchorFill(GuiRoot);bearingRoot:SetMouseEnabled(false) end
    local i=bearingCount+1;local p=bearingPool[i]
    if not p then p=WINDOW_MANAGER:CreateControl('ESOHCResourceBearing'..i,bearingRoot,CT_TEXTURE);p:SetMouseEnabled(false);p:SetTexture('ESOHardcore/HarvestAura.dds');p:SetDimensions(20,38);bearingPool[i]=p end
    local resolved=native.resolved and native.resolved[control]
    local color=colors[row.kind or (resolved and resolved.kind) or 'generic'] or colors.generic
    p:ClearAnchors();p:SetAnchor(TOP,p:GetParent(),TOPLEFT,cx-bearingRoot:GetLeft(),compass:GetBottom()-bearingRoot:GetTop()+4)
    p:SetColor(color[1],color[2],color[3],.95);p:SetHidden(false);bearingCount=i
   end)
  end
 end
 if bearingRoot then bearingRoot:SetHidden(bearingCount==0);for i=bearingCount+1,#bearingPool do bearingPool[i]:SetHidden(true) end end
end
local function tick()
 if not eligible(15) or not N.gameplay() then hide();lastScan=0;return end
 local zone,x,h,z=position();if not zone then hide();return end
 local rank=N.rank('Harvesting');local now=s(GetFrameTimeMilliseconds) or 0
 local revision=N.resourceSense and N.resourceSense.revision
 if revision~=lastRevision or lastScan==0 or now-lastScan>=300 or zone~=lastZone or character()~=lastCharacter or rank~=lastRank then
  local radius=rank>=99 and math.huge or rank>=75 and 350 or rank>=50 and 220 or 120
  selected={};local displayed={}
  -- Higher ranks retain the rank-15 memory perk; live signals only add information.
  if rank>=30 then
   selected=nearest(zone,x,h,z,radius,rank>=99)
   for _,v in ipairs(selected) do if v.record then displayed[v.record]=true end end
  else sourceStatus='Personal recorded sites.' end
  local remembered=0
  for _,v in pairs(records()) do
   if v.zone==zone and valid(v.x) and valid(v.h) and valid(v.z) then
    local dd=(v.x-x)^2+(v.z-z)^2
    if dd<=radius*radius and not displayed[v] then
     selected[#selected+1]={x=v.x,h=v.h,z=v.z,kind=v.kind,distance=dd,personal=true}
     remembered=remembered+1
    end
   end
  end
  sourceStatus=(sourceStatus or '')..' | '..remembered..' remembered sites without a live match.'
  lastScan=now;lastZone=zone;lastCharacter=character();lastRank=rank;lastRevision=revision
 end
 grounded={}
 if #selected==0 then if root then root:SetHidden(true) end;visibleCount=0;bearings(rank);return end
 ensureRoot()
 local a,b,c=s(WorldPositionToGuiRender3DPosition,0,0,0);local heading=s(GetPlayerCameraHeading)
 if not valid(a) or not valid(b) or not valid(c) or not valid(heading) then hide();failure='Native 3D position or camera API unavailable';return end
 root:Set3DRenderSpaceOrigin(a,b,c);root:SetHidden(false)
 visibleCount=0
 for i,v in ipairs(selected) do
  local ok,e=pcall(function()
   local p=marker(i);local color=colors[v.kind] or colors.generic
   local texture,width,height,hover,alpha=appearance(v,v.distance,now,i)
   -- Convert each absolute raw world position explicitly and express it relative
   -- to the converted root. The aura itself is a local vertical offset only.
   local px,py,pz=s(WorldPositionToGuiRender3DPosition,v.x*100,v.h*100,v.z*100)
   if not valid(px) or not valid(py) or not valid(pz) then error('invalid native resource transform') end
   p.anchor:Set3DRenderSpaceOrigin(px-a,py-b,pz-c)
   p.anchor:Set3DRenderSpaceOrientation(0,heading,0)
   p.aura:Set3DLocalDimensions(width,height)
   p.aura:Set3DRenderSpaceOrigin(0,hover,0)
   p.aura:SetColor(color[1],color[2],color[3],alpha)
   p.anchor:SetHidden(false);if v.control then grounded[v.control]=true end;visibleCount=visibleCount+1
  end)
  if not ok then if pool[i] then pcall(function() pool[i].anchor:SetHidden(true) end) end;sourceStatus=(sourceStatus or "").." | marker retry: "..tostring(e) end
 end
 for i=#selected+1,#pool do pool[i].anchor:SetHidden(true) end
 bearings(rank);failure=nil
end
function N.initHarvestMap()
 EVENT_MANAGER:RegisterForUpdate('ESOHCWorldResources',150,function()
  if failure and failure:find('render error',1,true) and (s(GetFrameTimeMilliseconds) or 0)<(N.harvestRetryAt or 0) then return end
  local ok,e=pcall(tick);if not ok then failure='World marker render error: '..tostring(e);N.harvestRetryAt=(s(GetFrameTimeMilliseconds) or 0)+3000;pcall(hide) end
 end)
end
local function count() local n=0;for _ in pairs(records()) do n=n+1 end;return n end
local function status() return failure or (count()..' personal 3D locations | '..visibleCount..' grounded markers | '..bearingCount..' bearing cues | '..(sourceStatus or 'Awaiting live detection')) end
R.defs.Harvesting[2][1]='Record and display personal resource locations in 3D'
R.install('Harvesting',2,function()return status()..' | Personal site auras within 120m, including depleted sites at every subsequent rank. Earlier 2D records require revisiting.' end)
R.defs.Harvesting[3][1]='Personal in-world resource markers'
R.install('Harvesting',3,function()return status()..' | 120m configured range, no marker-count cap. No world-map pins.' end)
R.defs.Harvesting[4][1]='Extended resource awareness'
R.install('Harvesting',4,function()return status()..' | 220m configured range, no marker-count cap.' end)
R.defs.Harvesting[5][1]='Advanced in-world resource guidance'
R.install('Harvesting',5,function()return status()..' | 350m configured range, no marker-count cap.' end)
function N.harvestMasteryStatus() return status()..' | All live signals plus remembered personal sites; recorded elevation required for 3D auras; other signals use colored compass-direction auras; native compass descriptions classify resources when available. No add-on distance or count cap. '..(sourceStatus or 'Community data checked in gameplay at level 99.') end
