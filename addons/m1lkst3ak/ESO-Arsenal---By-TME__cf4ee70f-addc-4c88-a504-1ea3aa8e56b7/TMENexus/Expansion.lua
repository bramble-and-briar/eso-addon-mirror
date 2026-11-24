-- Arsenal Expansion: independent, fail-closed optional systems.
local N=TMENexus
local s=N.safe
local X={alerts={},stats={},boss={},session={},rows={}}
N.expansion=X
local function now() return s(GetFrameTimeSeconds) or 0 end
local function stamp() return s(GetTimeStamp) or 0 end
local function same(a,b) return b~=nil and a==b end
local function cfg() return N.saved and N.saved.expansion end
local function clean(v) return tostring(v or ''):gsub('%^%a+','') end
local function alert(key,title,detail,priority,seconds)
 if not cfg() then return end
 X.alerts[key]={title=title,detail=detail,priority=priority,ends=now()+seconds}
end
local function panel(name,w,h)
 local p=WINDOW_MANAGER:CreateTopLevelWindow(name);p:SetDimensions(w,h);p:SetHidden(true)
 local b=WINDOW_MANAGER:CreateControl(nil,p,CT_BACKDROP);b:SetAnchorFill(p);b:SetCenterColor(.025,.023,.020,.91);b:SetEdgeColor(.66,.51,.29,1);b:SetEdgeTexture('',1,1,1)
 local l=WINDOW_MANAGER:CreateControl(nil,p,CT_LABEL);l:SetAnchor(TOPLEFT,p,TOPLEFT,12,8);l:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-12,-8);l:SetFont('$(BOLD_FONT)|22|soft-shadow-thick');l:SetColor(.94,.87,.72,1);l:SetVerticalAlignment(TEXT_ALIGN_CENTER);l:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 return p,l
end
local function power(kind)
 local k=_G['COMBAT_MECHANIC_FLAGS_'..kind] or _G['POWERTYPE_'..kind];if not k then return end
 local a,b=s(GetUnitPower,'player',k);if type(a)=='number' and type(b)=='number' and b>0 then return a/b end
end
local function zone()
 local z=s(GetUnitZoneIndex,'player');return tostring(z or '?'),clean(s(GetUnitZone,'player') or (z and s(GetZoneNameByIndex,z)) or 'Unknown zone')
end
local function combat(_,r,err,ability,graphic,action,source,st,target,tt,amount,pt,dt,log,sid,tid,id)
 local c=cfg();if not c or err then return end
 local me=same(tt,COMBAT_UNIT_TYPE_PLAYER);local own=same(st,COMBAT_UNIT_TYPE_PLAYER)
 local damage=same(r,ACTION_RESULT_DAMAGE) or same(r,ACTION_RESULT_CRITICAL_DAMAGE) or same(r,ACTION_RESULT_DOT_TICK) or same(r,ACTION_RESULT_DOT_TICK_CRITICAL)
 if c.awareness and me and not own then
  if same(r,ACTION_RESULT_DOT_TICK) or same(r,ACTION_RESULT_DOT_TICK_CRITICAL) then
   local k=tostring(id or ability);local t=now();local last=X.stats[k];X.stats[k]=t
   if last and t-last<3 then alert('damage','REPEATED DAMAGE',clean(ability)..' • check positioning',70,2) end
  elseif same(r,ACTION_RESULT_STUNNED) or same(r,ACTION_RESULT_KNOCKBACK) then alert('cc','CONTROLLED','Break free if needed',95,2) end
 end
 if c.encounters and N.context=='Dungeon' and me and damage and not own then
  local k=tostring(id or ability);local e=X.boss[k] or {name=clean(ability),hits=0,total=0};e.hits=e.hits+1;e.total=e.total+(tonumber(amount) or 0);X.boss[k]=e
 end
end
local function inventory()
 local c=cfg();if not c then return '' end
 local items={};local used,cap=0,0;local bags={};for _,name in ipairs({'BAG_BACKPACK','BAG_BANK','BAG_SUBSCRIBER_BANK','BAG_VIRTUAL'}) do if _G[name]~=nil then bags[#bags+1]=_G[name] end end
 local count=0;local unpriced=0
 for _,bag in ipairs(bags) do
  local size=s(GetBagSize,bag);if type(size)=='number' and bag~=BAG_VIRTUAL then
   for slot=0,size-1 do
    local link=s(GetItemLink,bag,slot,LINK_STYLE_DEFAULT);if type(link)=='string' and link~='' then
     if bag==BAG_BACKPACK then used=used+1 end
     local qty=s(GetSlotStackSize,bag,slot) or 1;local key=tostring(s(GetItemLinkItemId,link) or link);local e=items[key] or {name=clean(s(GetItemLinkName,link)),qty=0,copies=0,value=0};e.qty=e.qty+qty;e.copies=e.copies+1;items[key]=e
     local gs=GoldStandard;if gs and s(gs.IsSlotMarketable,gs,bag,slot,link)==true then local v=s(gs.Estimate,gs,link,qty);if type(v)=='number' then e.value=e.value+v else unpriced=unpriced+1 end end
    end
   end
   if bag==BAG_BACKPACK then cap=size end
  end
 end
 local list={};for _,e in pairs(items) do if c.search=='' or e.name:lower():find(c.search:lower(),1,true) then list[#list+1]=e end end
 table.sort(list,function(a,b) if a.value==b.value then return a.name<b.name end return a.value>b.value end)
 local lines={string.format('Backpack %d / %d | %d matching item types',used,cap,#list),'Bank + backpack • verified marketable value'}
 for i=1,math.min(8,#list) do local e=list[i];lines[#lines+1]=string.format('%s x%d | %dg%s',e.name,e.qty,math.floor(e.value),e.copies>1 and ' • multiple stacks' or '') end
 lines[#lines+1]=tostring(unpriced)..' eligible stacks unpriced; craft bag excluded from scan'
 return table.concat(lines,'\n')
end
local function loot(_,receivedBy,item,qty,sound,lootType,selfLoot)
 local c=cfg();if not c or not c.explorer or selfLoot~=true then return end
 local key,name=zone();local e=c.zones[key] or {name=name,items=0,events=0,gold=0,visits=0};c.zones[key]=e
 e.events=e.events+1;e.items=e.items+(tonumber(qty) or 0);local v=GoldStandard and s(GoldStandard.Estimate,GoldStandard,item,qty);if type(v)=='number' then e.gold=e.gold+v end
 local x,y=s(GetMapPlayerPosition,'player');if type(x)=='number' and type(y)=='number' and x>0 and y>0 and s(GetMapZoneIndex)==s(GetUnitZoneIndex,'player') then
  e.cells=e.cells or {};local cell=math.floor(x*10)..':'..math.floor(y*10);e.cells[cell]=(e.cells[cell] or 0)+1
 end
end
local function report(kind)
 local c=cfg();if not c then return '' end
 if kind=='Inventory' then return inventory() end
 if kind=='Encounters' then local a={};for _,e in pairs(X.boss) do a[#a+1]=e end;table.sort(a,function(x,y)return x.total>y.total end);local l={'Incoming dungeon damage • current session'};for i=1,math.min(10,#a) do local e=a[i];l[#l+1]=e.name..' | '..e.hits..' hits | '..math.floor(e.total) end;return table.concat(l,'\n') end
 if kind=='Explorer' then local a={};for _,e in pairs(c.zones) do a[#a+1]=e end;table.sort(a,function(x,y)return x.gold>y.gold end);local l={'Recorded self-loot by zone • estimated value'};for i=1,math.min(8,#a) do local e=a[i];local best,n='—',0;for k,v in pairs(e.cells or {}) do if v>n then best,n=k,v end end;l[#l+1]=e.name..' | '..e.items..' items | '..math.floor(e.gold)..'g | cell '..best end;return table.concat(l,'\n') end
 local l={'Utilities • current character'};local a,b=s(GetNumBagFreeSlots,BAG_BACKPACK),s(GetBagSize,BAG_BACKPACK);if type(a)=='number' then l[#l+1]='Backpack free: '..a..' / '..tostring(b or '?') end
 local riding=s(GetTimeUntilCanBeTrained);if type(riding)=='number' then l[#l+1]=riding<=0 and 'Mount training available' or string.format('Mount training: %.1fh',riding/3600000) end
 for _,craft in ipairs({CRAFTING_TYPE_BLACKSMITHING,CRAFTING_TYPE_CLOTHIER,CRAFTING_TYPE_WOODWORKING,CRAFTING_TYPE_JEWELRYCRAFTING}) do local count=s(GetNumSmithingResearchLines,craft);local active=0;if type(count)=='number' then for line=1,count do local _,_,traits=s(GetSmithingResearchLineInfo,craft,line);for trait=1,tonumber(traits) or 0 do local duration,remaining=s(GetSmithingResearchLineTraitTimes,craft,line,trait);if type(remaining)=='number' and remaining>0 then active=active+1 end end end;l[#l+1]='Research '..tostring(craft)..': '..active..' active' end end
 return table.concat(l,'\n')
end
local function tick()
 local c=cfg();if not c or not X.hud then return end
 local visible=N.gameplay();local t=now()
 if c.awareness and s(IsUnitInCombat,'player') then
  for _,k in ipairs({'HEALTH','MAGICKA','STAMINA'}) do local p=power(k);local key='power'..k;if p and p<=c.low/100 then alert(key,'LOW '..k,math.floor(p*100)..'% remaining',k=='HEALTH' and 100 or 45,1) else X.alerts[key]=nil end end
 end
 if c.utilities and t-(X.lastUtility or -60)>30 then X.lastUtility=t;local free=s(GetNumBagFreeSlots,BAG_BACKPACK);if type(free)=='number' and free<=5 then alert('bag','INVENTORY NEARLY FULL',free..' free slots',20,5) end end
 local best;for k,e in pairs(X.alerts) do if e.ends<=t then X.alerts[k]=nil elseif not best or e.priority>best.priority then best=e end end
 X.hud:ClearAnchors();X.hud:SetAnchor(CENTER,GuiRoot,CENTER,c.x,c.y);X.hud:SetScale(c.scale/100);X.hud:SetHidden(not visible or not best);if best then X.label:SetText(best.title..'\n'..best.detail) end
end
function X.options()
 local c=cfg();if not c then return {} end
 local o={};local function toggle(k,name) o[#o+1]={type='checkbox',name=name,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 local function slider(k,name,min,max) o[#o+1]={type='slider',name=name,min=min,max=max,step=1,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 toggle('awareness','Combat awareness');toggle('encounters','Dungeon incoming damage report');toggle('utilities','Inventory capacity reminders');toggle('explorer','Explorer loot history');slider('low','Low resource threshold (%)',5,40);slider('x','Alert X',-1000,1000);slider('y','Alert Y',-700,700);slider('scale','Alert scale (%)',50,150)
 o[#o+1]={type='editbox',name='Inventory search',getFunc=function()return c.search end,setFunc=function(v)c.search=tostring(v or '') end}
 for _,kind in ipairs({'Inventory','Encounters','Explorer','Utilities'}) do local k=kind;o[#o+1]={type='button',name='Show '..k..' report',func=function() local ok,txt=pcall(report,k);if d then d('|cD9BC80Arsenal • '..k..'|r\n'..tostring(txt)) end end} end
 o[#o+1]={type='button',name='Preview combat alert',func=function()alert('preview','COMBAT INTELLIGENCE','Preview • return to gameplay',110,15)end}
 return o
end
EVENT_MANAGER:RegisterForEvent('ArsenalExpansionInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='TMENexus' then return end;EVENT_MANAGER:UnregisterForEvent('ArsenalExpansionInit',EVENT_ADD_ON_LOADED)
 local function init()
  if not N.saved then return end;N.saved.expansion=N.saved.expansion or {};local c=N.saved.expansion;for k,v in pairs({awareness=true,encounters=true,utilities=true,explorer=true,low=20,x=0,y=-220,scale=100,search='',zones={}}) do if c[k]==nil then c[k]=v end end
  local ok,a,b=pcall(panel,'ArsenalExpansionAlert',460,68);if ok then X.hud,X.label=a,b end
  if EVENT_COMBAT_EVENT then EVENT_MANAGER:RegisterForEvent('ArsenalExpansionCombat',EVENT_COMBAT_EVENT,function(...)pcall(combat,...)end) end
  if EVENT_LOOT_RECEIVED then EVENT_MANAGER:RegisterForEvent('ArsenalExpansionLoot',EVENT_LOOT_RECEIVED,function(...)pcall(loot,...)end) end
  EVENT_MANAGER:RegisterForUpdate('ArsenalExpansionTick',250,function()pcall(tick)end)
 end
 if N.saved then init() else zo_callLater(init,100) end
end)
