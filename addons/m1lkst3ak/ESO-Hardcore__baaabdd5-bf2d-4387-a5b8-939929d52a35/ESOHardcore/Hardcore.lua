-- Character-local experimental Hardcore presentation; does not enforce the full ruleset.
local N=ESOHardcore; local s=N.safe
local H={effects={},edges={}}; N.hardcore=H
local function cfg() return H.saved end
local function clamp(x) return math.max(0,math.min(100,x)) end
local matrix={{200,150,100,50,0},{150,150,75,37.5,0},{100,75,25,12.5,0},{50,37.5,12.5,6.25,0},{0,0,0,0,0}}
local function tier(v) if v>=80 then return 1 elseif v>=50 then return 2 elseif v>=25 then return 3 elseif v>=10 then return 4 else return 5 end end
local difficulties={'Adventurer','Seasoned','Master','Vestige'}
local factors={1,1.5,2,3}
function H.difficulty()
 local v=s(GetOverlandDifficulty);local reason=s(GetOverlandDifficultyDisabledReason)
 if reason~=nil and OVERLAND_DIFFICULTY_DISABLED_REASON_NONE~=nil and reason~=OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then H.difficultyState='Inactive here';return 1 end
 for i,n in ipairs(difficulties) do local k=_G['OVERLAND_DIFFICULTY_'..n:upper()];if k~=nil and v==k then H.difficultyState='Detected';return i end end
 -- Resolve native enum through localized string where available; never assume numeric indexing.
 if v~=nil and SI_OVERLANDDIFFICULTY then local label=s(GetString,SI_OVERLANDDIFFICULTY,v);for i,n in ipairs(difficulties) do if label==n then H.difficultyState='Detected';return i end end end
 H.difficultyState='Unverified';return 1
end
function H.difficultyName() local i=H.difficulty();return H.difficultyState=="Detected" and difficulties[i] or H.difficultyState end
function H.changeDifficulty() end
function H.multiplier() local c=cfg(); if not c or not c.active then return 1 end; if c.fallen then return 0 end; return matrix[tier(c.food)][tier(c.water)]/100*factors[H.difficulty()] end
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
 local root=WINDOW_MANAGER:CreateTopLevelWindow('ESOHardcoreOverlay');H.root=root;root:SetAnchorFill(GuiRoot);root:SetMouseEnabled(false);root:SetHidden(true)
 -- Nested translucent edge strips, avoiding external texture assets or shader hooks.
 H.vignette=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);H.vignette:SetAnchorFill(root);H.vignette:SetTexture('ESOHardcore/Vignette.dds');H.vignette:SetMouseEnabled(false)
 local hud=WINDOW_MANAGER:CreateTopLevelWindow('ESOHardcoreNutrition');H.hud=hud;hud:SetDimensions(390,64);hud:SetMouseEnabled(false);hud:SetHidden(true)
 H.text=label(hud,23);H.text:SetAnchor(TOP,hud,TOP,0,0);H.text:SetDimensions(390,25)
 H.status=label(hud,19);H.status:SetAnchor(BOTTOM,hud,BOTTOM,0,0);H.status:SetDimensions(390,22)
 H.bars={};for i=1,2 do local bg=WINDOW_MANAGER:CreateControl(nil,hud,CT_TEXTURE);bg:SetDimensions(175,9);bg:SetAnchor(TOPLEFT,hud,TOPLEFT,i==1 and 10 or 205,29);bg:SetColor(.15,.13,.11,.85);local bar=WINDOW_MANAGER:CreateControl(nil,bg,CT_TEXTURE);bar:SetAnchor(TOPLEFT,bg,TOPLEFT);bar:SetColor(i==1 and .72 or .30,i==1 and .57 or .58,i==1 and .30 or .78,1);H.bars[i]=bar end
end
-- Restore original visibility outside active Hardcore gameplay.
local hidden={}
local function nativeHUD(active)
 local function suppress(control)
  if not control then return end
  local ok=pcall(function() if hidden[control]==nil then hidden[control]=control:IsHidden() end;if not control:IsHidden() then control:SetHidden(true) end end)
 end
 -- Do not mutate shared native scene fragments; only hide individual HUD controls.
 if not active then for control,was in pairs(hidden) do pcall(function() control:SetHidden(was) end);hidden[control]=nil end;return end
 -- Candidate native controls; unavailable controls are ignored on console.
 for _,name in ipairs({'ZO_PromotionalEventTracker_TL','ZO_GoldenPursuitsTracker','ZO_GoldenPursuitsTrackerGamepad','ZO_GoldenPursuitsTracker_Keyboard','ZO_GoldenPursuitsTracker_Gamepad','ZO_Compass','ZO_CompassFrame','ZO_FocusedQuestTracker','ZO_FocusedQuestTrackerPanel','ZO_FocusedQuestTrackerGamepad','ZO_QuestTracker','ZO_QuestTrackerGamepad','ZO_PlayerAttributeHealth','ZO_PlayerAttributeMagicka','ZO_PlayerAttributeStamina','ZO_PlayerAttributeGamepadHealth','ZO_PlayerAttributeGamepadMagicka','ZO_PlayerAttributeGamepadStamina','ZO_PlayerAttributeHealthGamepad','ZO_PlayerAttributeMagickaGamepad','ZO_PlayerAttributeStaminaGamepad'}) do local compass=name:find("Compass",1,true);local quest=name:find("QuestTracker",1,true);if not (compass and N.rank("Pathfinding")>=30 or quest and N.rank("Adventuring")>=15) then suppress(_G[name]) elseif hidden[_G[name]]~=nil then local control=_G[name];pcall(function() control:SetHidden(hidden[control]) end);hidden[control]=nil end end
 for _,name in ipairs({'ZO_PlayerAttribute','ZO_PlayerAttributeBars','ZO_PlayerAttributeGamepad','ZO_PlayerAttributeBarsGamepad'}) do local root=_G[name];if root then for _,key in ipairs({'Health','Magicka','Stamina'}) do suppress(s(GetControl,root,key)) end end end
end
local function tick()
 local c=cfg();if not c or not H.root then return end
 local t=now();local dt=math.max(0,math.min(2,t-(H.last or t)));H.last=t
 local visible=N.gameplay();nativeHUD(c.active and not c.fallen and visible and not (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)));local combat=s(IsUnitInCombat,'player')==true
 if c.active and not c.fallen and (visible or combat) then local rate=(combat and 1.25 or 1)*(N.rank("Survivalist")>=50 and .9 or 1);c.survivalSeconds=(c.survivalSeconds or 0)+dt;c.difficultySeconds=c.difficultySeconds or {};local idx=H.difficulty();c.difficultySeconds[idx]=(c.difficultySeconds[idx] or 0)+dt;c.food=clamp(c.food-dt*100/9000*rate);c.water=clamp(c.water-dt*100/6000*rate) end
 local preview=H.previewUntil and H.previewUntil>t
 local show=visible and (c.active or preview);H.root:SetHidden(not show or not c.overlays);H.hud:SetHidden(not show or not c.meters)
 if N.expansionTick then N.expansionTick(dt,visible,combat) end
 if N.economyTick then N.economyTick() end
 if N.skillsTick then N.skillsTick(dt,visible,combat) end
 if not show then return end
 H.hud:ClearAnchors();H.hud:SetAnchor(BOTTOM,GuiRoot,BOTTOM,c.x,c.y);H.hud:SetScale(c.scale/100)
 H.text:SetText(string.format('Hunger %d%%       Thirst %d%%',math.floor(c.food),math.floor(c.water)));H.bars[1]:SetDimensions(175*c.food/100,9);H.bars[2]:SetDimensions(175*c.water/100,9)
 local hp,max=s(GetUnitPower,'player',COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH);local pct=type(hp)=='number' and type(max)=='number' and max>0 and hp/max or 1
 local effects={};local seen={};for slot,e in pairs(H.effects) do if type(e.ends)=='number' and e.ends>0 and e.ends<=t then H.effects[slot]=nil elseif not seen[e.kind] and c[e.kind] then effects[#effects+1]=e.kind;seen[e.kind]=true end end;table.sort(effects)
 H.status:SetText(c.fallen and 'FALLEN — run ended' or string.format('%s | XP %g%%%s',H.difficultyName(),H.multiplier()*100,#effects>0 and ' | '..names[effects[1]] or '')..(c.food<25 and ' | Hungry' or '')..(c.water<25 and ' | Thirsty' or ''))
 local power=c.health and pct<.75 and math.min(.72,(.75-pct)*.96) or 0
 local kind=effects[1] or (c.food<25 and c.hunger and 'hunger') or (c.water<25 and c.thirst and 'thirst') or 'health';local alpha=kind~='health' and .30 or 0
 if preview then kind=H.previewKind;alpha=.55;power=kind=='health' and .65 or 0 end
 local w,h=GuiRoot:GetDimensions();local intensity=c.intensity/100
 if power>0 and (power>=alpha or pct<.25) then kind,alpha='health',power end
 local col=colors[kind] or colors.health;H.vignette:SetColor(col[1],col[2],col[3],math.min(.95,alpha*intensity*1.55))

end
local function death() local c=cfg();if c and c.active and not c.fallen then c.fallen=true;c.deathTime=s(GetTimeStamp) or 0;if N.archiveDeath then N.archiveDeath() end;if N.economyDeath then N.economyDeath() end;if d then d('ESO Hardcore: Fallen. This character’s test run has ended.') end end end
N.simulateDeath=death
-- Manual provision controls are intentionally labelled test-only until consumption events are verified.
function H.options()
 local c=cfg();if not c then return {} end
 local o={{type='description',text='Experimental character-local Hardcore preview. Ruleset restrictions remain honor-based. Automatic nutrition is experimental; test controls are retained as fallback.'}}
 local function toggle(k,n) o[#o+1]={type='checkbox',name=n,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 local function slider(k,n,a,b) o[#o+1]={type='slider',name=n,min=a,max=b,step=5,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 o[#o+1]={type='checkbox',name='Activate Hardcore test run',getFunc=function()return c.active end,setFunc=function(v) if not c.fallen then c.active=v end end}
 toggle('overlays','Immersive overlays');toggle('meters','Nutrition HUD');slider('intensity','Overlay intensity',0,100);slider('x','Nutrition X',-1000,1000);slider('y','Nutrition Y',-900,0);slider('scale','Nutrition scale',50,150)
 for _,k in ipairs({'health','poison','burn','disease','chill','shock','bleed','control','hunger','thirst'}) do local key=k;toggle(key,'Show '..(names[key] or key));o[#o+1]={type='button',name='Preview '..(names[key] or key),func=function() H.previewKind=key;H.previewUntil=now()+20 end} end
 o[#o+1]={type='button',name='TEST: restore hunger',func=function()c.food=100 end};o[#o+1]={type='button',name='TEST: restore thirst',func=function()c.water=100 end};return o
end
EVENT_MANAGER:RegisterForEvent('ESOHardcoreInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='ESOHardcore' then return end;EVENT_MANAGER:UnregisterForEvent('ESOHardcoreInit',EVENT_ADD_ON_LOADED)
 local ok,err=pcall(function()
 H.saved=ZO_SavedVars:NewCharacterIdSettings('ESOHardcoreSaved',1,nil,{active=false,fallen=false,food=100,water=100,overlays=true,meters=true,intensity=90,x=0,y=-230,scale=100,health=true,poison=true,burn=true,disease=true,chill=true,shock=true,bleed=true,control=true,hunger=true,thirst=true})
 build();if N.initSkills then N.initSkills() end;if N.initExpansion then N.initExpansion() end;if N.economyInit then N.economyInit() end;if EVENT_EFFECT_CHANGED then EVENT_MANAGER:RegisterForEvent('ESOHardcoreEffects',EVENT_EFFECT_CHANGED,effect) end;if EVENT_PLAYER_DEAD then EVENT_MANAGER:RegisterForEvent('ESOHardcoreDeath',EVENT_PLAYER_DEAD,death) end
 EVENT_MANAGER:RegisterForUpdate('ESOHardcoreTick',250,function() local good,e=pcall(tick);if not good then nativeHUD(false);H.root:SetHidden(true);H.hud:SetHidden(true);EVENT_MANAGER:UnregisterForUpdate('ESOHardcoreTick');if d then d('ESO Hardcore preview disabled: '..tostring(e)) end end end)
 end);if not ok and d then d('ESO Hardcore init: '..tostring(err)) end
end)
