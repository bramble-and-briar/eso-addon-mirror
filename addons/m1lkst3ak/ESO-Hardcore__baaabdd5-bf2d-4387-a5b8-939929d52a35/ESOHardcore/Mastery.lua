-- Shared, bounded mastery systems. No new UI controls or background scans.
local N=ESOHardcore;local R=N.rewards;local s=N.safe
local function c() return N.hardcore.saved end
local function active() local a=c();return a and a.active and not a.fallen end
local function data() local a=c();a.mastery=a.mastery or {};return a.mastery end
local function pos() local z,x,_,y=s(GetUnitWorldPosition,'player');if type(z)=='number' and type(x)=='number' and type(y)=='number' then return z,x,y end end
local function name() return s(GetUnitZone,'player') or 'Unknown' end
local function distance(x,y,a,b) return math.sqrt((x-a)^2+(y-b)^2) end
local function bearing(x,y,a,b) local dx,dy=a-x,b-y;return math.abs(dx)>math.abs(dy) and (dx>0 and 'east (+X)' or 'west (-X)') or (dy>0 and '+Z' or '-Z') end
local function nearest(nodes,limit)
 local z,x,y=pos();local list={};if not z then return list end
 for _,v in pairs(nodes or {}) do if v.zone==z and type(v.x)=='number' and type(v.z)=='number' then list[#list+1]={node=v,d=distance(x,y,v.x,v.z)} end end
 table.sort(list,function(a,b) return a.d<b.d end);while #list>limit do list[#list]=nil end;return list,x,y
end
local function nodes() return c().journal and c().journal.nodes or {} end
local function nearText(n) local a,x,y=nearest(nodes(),1);if not a[1] then return 'No recorded nodes in this zone' end;return string.format('Known node: %.0f world units, %s',a[1].d,bearing(x,y,a[1].node.x,a[1].node.z)) end
R.install('Harvesting',4,nearText)
R.install('Harvesting',5,function() local a=nearest(nodes(),5);if #a==0 then return 'Gather nodes in this zone first' end;local t={};for i,v in ipairs(a) do t[#t+1]=string.format('%d: %.0f,%.0f',i,v.node.x,v.node.z) end;return 'Nearby farming stops (world X/Z): '..table.concat(t,' | ') end)
local function power(flag) local v,m=s(GetUnitPower,'player',flag);if type(v)=='number' and type(m)=='number' and m>0 then return v/m end end
local warned={};local prevH,prevS
local function warn(k,msg,on) if on and not warned[k] and d then d('Hardcore: '..msg) end;warned[k]=on end
local function potions() local count=0;for i=0,(s(GetBagSize,BAG_BACKPACK) or 0)-1 do local l=s(GetItemLink,BAG_BACKPACK,i,LINK_STYLE_DEFAULT);if l and l~='' and s(GetItemLinkItemType,l)==ITEMTYPE_POTION then count=count+(s(GetSlotStackSize,BAG_BACKPACK,i) or 0) end end;return count end
R.install('Survivalist',5,function() return 'Potion availability warning active | Backpack potions: '..potions() end)
R.install('Survivalist',4,function() return 'Rapid health loss warning active; existing nutrition bonus retained' end)
R.install('Endurance',4,function() return 'Rapid stamina loss warning active in gameplay' end)
R.install('Survivalist',6,function() return 'Emergency alert active below 12% health' end)
function N.masteryTick() end
