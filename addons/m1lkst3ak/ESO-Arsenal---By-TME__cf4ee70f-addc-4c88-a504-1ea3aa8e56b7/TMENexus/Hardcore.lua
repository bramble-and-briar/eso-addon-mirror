-- Character-local experimental Hardcore presentation; does not enforce the full ruleset.
local N=TMENexus; local s=N.safe
local H={effects={},edges={}}; N.hardcore=H
local function cfg() return H.saved end
local function clamp(x) return math.max(0,math.min(100,x)) end
local matrix={{200,150,100,50,0},{150,150,75,37.5,0},{100,75,25,12.5,0},{50,37.5,12.5,6.25,0},{0,0,0,0,0}}
local function tier(v) if v>=80 then return 1 elseif v>=50 then return 2 elseif v>=25 then return 3 elseif v>=10 then return 4 else return 5 end end
function H.multiplier() local c=cfg(); if not c or not c.active then return 1 end; if c.fallen then return 0 end; return matrix[tier(c.food)][tier(c.water)]/100 end
local colors={health={.65,.015,.035},poison={.32,.62,.08},burn={1,.29,.035},disease={.61,.55,.12},chill={.25,.65,.92},shock={.49,.32,.85},bleed={.48,.015,.075},control={.07,.055,.08},hunger={.28,.23,.13},thirst={.72,.57,.32}}
local names={poison='Poisoned',burn='Burning',disease='Diseased',chill='Chilled',shock='Concussed',bleed='Bleeding',control='Controlled'}
local function now() return s(GetFrameTimeSeconds) or 0 end
local function classify(name)
 name=tostring(name or ''):lower()
 for _,p in ipairs({{'poison','poison'},{'burn','burn'},{'diseas','disease'},{'chilled','chill'},{'concuss','shock'},{'hemorrhag','bleed'},{'bleed','bleed'},{'stunned','control'},{'feared','control'},{'silenced','control'}}) do if name:find(p[1],1,true) then return p[2] end end
end
local function effect(_,change,slot,name,tag,beginTime,endTime)
 if tag~='player' then return end
 if change==EFFECT_RESULT_FADED then H.effects[slot]=nil;return end
 local k=classify(name); if k then H.effects[slot]={kind=k,ends=endTime} else H.effects[slot]=nil end
end
local function label(parent,size)
 local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);l:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick');l:SetColor(.94,.85,.70,1);l:SetHorizontalAlignment(TEXT_ALIGN_CENTER);return l
end
local function build()
 local root=WINDOW_MANAGER:CreateTopLevelWindow('ArsenalHardcoreOverlay');H.root=root;root:SetAnchorFill(GuiRoot);root:SetMouseEnabled(false);root:SetHidden(true)
 -- Nested translucent edge strips, avoiding external texture assets or shader hooks.
 for side=1,4 do H.edges[side]={};for i=1,12 do local q=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);q:SetMouseEnabled(false);H.edges[side][i]=q end end
 local hud=WINDOW_MANAGER:CreateTopLevelWindow('ArsenalHardcoreNutrition');H.hud=hud;hud:SetDimensions(390,64);hud:SetMouseEnabled(false);hud:SetHidden(true)
 H.text=label(hud,19);H.text:SetAnchor(TOP,hud,TOP,0,0);H.text:SetDimensions(390,25)
 H.status=label(hud,16);H.status:SetAnchor(BOTTOM,hud,BOTTOM,0,0);H.status:SetDimensions(390,22)
 H.bars={};for i=1,2 do local bg=WINDOW_MANAGER:CreateControl(nil,hud,CT_TEXTURE);bg:SetDimensions(175,5);bg:SetAnchor(TOPLEFT,hud,TOPLEFT,i==1 and 10 or 205,29);bg:SetColor(.15,.13,.11,.85);local bar=WINDOW_MANAGER:CreateControl(nil,bg,CT_TEXTURE);bar:SetAnchor(TOPLEFT,bg,TOPLEFT);bar:SetColor(i==1 and .72 or .30,i==1 and .57 or .58,i==1 and .30 or .78,1);H.bars[i]=bar end
end
local function paint(side,kind,alpha,w,h)
 local c=colors[kind] or colors.health; local depth=math.max(12,math.min(w,h)*.10);local step=depth/12
 for i,q in ipairs(H.edges[side]) do local a=(i-1)*step;q:ClearAnchors();if side==1 then q:SetAnchor(TOPLEFT,H.root,TOPLEFT,0,a);q:SetDimensions(w,step+1) elseif side==2 then q:SetAnchor(BOTTOMLEFT,H.root,BOTTOMLEFT,0,-a);q:SetDimensions(w,step+1) elseif side==3 then q:SetAnchor(TOPLEFT,H.root,TOPLEFT,a,0);q:SetDimensions(step+1,h) else q:SetAnchor(TOPRIGHT,H.root,TOPRIGHT,-a,0);q:SetDimensions(step+1,h) end;q:SetColor(c[1],c[2],c[3],alpha*(1-(i-1)/12)^2) end
end
local function tick()
 local c=cfg();if not c or not H.root then return end
 local t=now();local dt=math.max(0,math.min(2,t-(H.last or t)));H.last=t
 local visible=N.gameplay();local combat=s(IsUnitInCombat,'player')==true
 if c.active and not c.fallen and (visible or combat) then local rate=combat and 1.25 or 1;c.food=clamp(c.food-dt*100/9000*rate);c.water=clamp(c.water-dt*100/6000*rate) end
 local preview=H.previewUntil and H.previewUntil>t
 local show=visible and (c.active or preview);H.root:SetHidden(not show or not c.overlays);H.hud:SetHidden(not show or not c.meters)
 if not show then return end
 H.hud:ClearAnchors();H.hud:SetAnchor(BOTTOM,GuiRoot,BOTTOM,c.x,c.y);H.hud:SetScale(c.scale/100)
 H.text:SetText(string.format('Hunger %d%%       Thirst %d%%',math.floor(c.food),math.floor(c.water)));H.bars[1]:SetDimensions(175*c.food/100,5);H.bars[2]:SetDimensions(175*c.water/100,5)
 local hp,max=s(GetUnitPower,'player',COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH);local pct=type(hp)=='number' and type(max)=='number' and max>0 and hp/max or 1
 local effects={};local seen={};for slot,e in pairs(H.effects) do if type(e.ends)=='number' and e.ends>0 and e.ends<=t then H.effects[slot]=nil elseif not seen[e.kind] and c[e.kind] then effects[#effects+1]=e.kind;seen[e.kind]=true end end;table.sort(effects)
 H.status:SetText(c.fallen and 'FALLEN — run ended' or string.format('XP %g%%%s',H.multiplier()*100,#effects>0 and ' | '..names[effects[1]] or ''))
 local power=c.health and pct<.75 and math.min(.72,(.75-pct)*.96) or 0
 local kind=effects[1] or (c.food<25 and c.hunger and 'hunger') or (c.water<25 and c.thirst and 'thirst') or 'health';local alpha=kind~='health' and .30 or 0
 if preview then kind=H.previewKind;alpha=.55;power=kind=='health' and .65 or 0 end
 local w,h=GuiRoot:GetDimensions();local intensity=c.intensity/100
 for side=1,4 do local k,a=kind,alpha;if power>0 and (side<=2 or alpha==0) then k,a='health',power elseif side==4 and effects[2] and not preview then k=effects[2] end;paint(side,k,a*intensity,w,h) end
end
local function death() local c=cfg();if c and c.active and not c.fallen then c.fallen=true;c.deathTime=s(GetTimeStamp) or 0;if d then d('Arsenal Hardcore: Fallen. This character’s test run has ended.') end end end
-- Manual provision controls are intentionally labelled test-only until consumption events are verified.
function H.options()
 local c=cfg();if not c then return {} end
 local o={{type='description',text='Experimental character-local Hardcore preview. No verified ruleset enforcement, skill XP integration or automatic food detection yet.'}}
 local function toggle(k,n) o[#o+1]={type='checkbox',name=n,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 local function slider(k,n,a,b) o[#o+1]={type='slider',name=n,min=a,max=b,step=5,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 o[#o+1]={type='checkbox',name='Activate Hardcore test run',getFunc=function()return c.active end,setFunc=function(v) if not c.fallen then c.active=v end end}
 toggle('overlays','Immersive overlays');toggle('meters','Nutrition HUD');slider('intensity','Overlay intensity',0,100);slider('x','Nutrition X',-1000,1000);slider('y','Nutrition Y',-900,0);slider('scale','Nutrition scale',50,150)
 for _,k in ipairs({'health','poison','burn','disease','chill','shock','bleed','control','hunger','thirst'}) do local key=k;toggle(key,'Show '..(names[key] or key));o[#o+1]={type='button',name='Preview '..(names[key] or key),func=function() H.previewKind=key;H.previewUntil=now()+20 end} end
 o[#o+1]={type='button',name='TEST: restore hunger',func=function()c.food=100 end};o[#o+1]={type='button',name='TEST: restore thirst',func=function()c.water=100 end};return o
end
EVENT_MANAGER:RegisterForEvent('ArsenalHardcoreInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='TMENexus' then return end;EVENT_MANAGER:UnregisterForEvent('ArsenalHardcoreInit',EVENT_ADD_ON_LOADED)
 local ok,err=pcall(function()
 H.saved=ZO_SavedVars:NewCharacterIdSettings('NexusHardcoreSaved',1,nil,{active=false,fallen=false,food=100,water=100,overlays=true,meters=true,intensity=65,x=0,y=-230,scale=100,health=true,poison=true,burn=true,disease=true,chill=true,shock=true,bleed=true,control=true,hunger=true,thirst=true})
 build();if EVENT_EFFECT_CHANGED then EVENT_MANAGER:RegisterForEvent('ArsenalHardcoreEffects',EVENT_EFFECT_CHANGED,effect) end;if EVENT_PLAYER_DEAD then EVENT_MANAGER:RegisterForEvent('ArsenalHardcoreDeath',EVENT_PLAYER_DEAD,death) end
 EVENT_MANAGER:RegisterForUpdate('ArsenalHardcoreTick',250,function() local good,e=pcall(tick);if not good then H.root:SetHidden(true);H.hud:SetHidden(true);EVENT_MANAGER:UnregisterForUpdate('ArsenalHardcoreTick');if d then d('Arsenal Hardcore preview disabled: '..tostring(e)) end end end)
 end);if not ok and d then d('Arsenal Hardcore init: '..tostring(err)) end
end)
