-- Character-local experimental Hardcore presentation; does not enforce the full ruleset.
local N=ESOHardcore; local s=N.safe
local H={effects={},edges={}}; N.hardcore=H
local function cfg() return H.saved end
local function clamp(x) return math.max(0,math.min(100,x)) end
local matrix={{200,150,100,50,0},{150,150,75,37.5,0},{100,75,25,12.5,0},{50,37.5,12.5,6.25,0},{0,0,0,0,0}}
local function tier(v) if v>=80 then return 1 elseif v>=50 then return 2 elseif v>=25 then return 3 elseif v>=10 then return 4 else return 5 end end
local difficulties={'Adventurer','Seasoned','Master','Vestige'}
local factors={1,1.5,2,3}
-- Read native player difficulty first; use only unambiguous named values.
local aliases={BASEGAME=1,ADVENTURER=1,SEASONED=2,MASTER=3,VESTIGE=4}
local enumValues,enumLines={},{}
-- Explicit allowlist: never enumerate protected globals.
local function discoverEnums()
 for _,name in ipairs({'BASEGAME','ADVENTURER','SEASONED','MASTER','VESTIGE'}) do
  local ok,v=pcall(function() return _G['OVERLAND_DIFFICULTY_TYPE_'..name] end)
  if ok and type(v)=='number' then
   enumLines[#enumLines+1]=name..'='..v
   local i=aliases[name]
   if enumValues[v] and enumValues[v]~=i then enumValues[v]=false elseif enumValues[v]==nil then enumValues[v]=i end
  end
 end
end
local function difficultyLabel(v)
 if type(v)~='number' then return end
 local label=s(GetString,'SI_OVERLANDDIFFICULTYTYPE',v)
 if type(label)=='string' then return label end
end
local function resolveDifficulty(v)
 if type(v)=='string' then return aliases[v:upper()] end
 if type(v)~='number' then return end
 local label=difficultyLabel(v)
 local i=label and aliases[label:upper():match('^%s*(.-)%s*$')]
 if i then return i,'label' end
 if enumValues[v] then return enumValues[v],'enum' end
end
local lastRead=-10000
local function readDifficulty(force)
 local now=s(GetFrameTimeMilliseconds) or 0
 if not force and now-lastRead<1000 then return end
 lastRead=now
 H.rawDifficulty=s(GetOverlandDifficulty)
 H.rawPlayerDifficulty=s(GetUnitOverlandDifficulty,'player')
 H.rawReason=s(GetOverlandDifficultyDisabledReason)
end
function H.difficulty()
 readDifficulty(false)
 if H.rawReason~=nil and OVERLAND_DIFFICULTY_DISABLED_REASON_NONE~=nil and H.rawReason~=OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then H.difficultyState='Inactive here';return 1 end
 local c=cfg();local manual=c and c.difficultyFallback
 if type(manual)=='number' and difficulties[manual] then H.difficultyState='Manual';return manual end
 local p,ps=resolveDifficulty(H.rawPlayerDifficulty);local g,gs=resolveDifficulty(H.rawDifficulty)
 local i
 -- The selected difficulty API and the native display label take precedence.
 if g and gs=='label' then i=g
 elseif p and ps=='label' then i=p
 elseif g then i=g
 else i=p end
 if i then H.difficultyState='Detected';return i end
 H.difficultyState='Base rate';return 1
end
function H.difficultyName() local i=H.difficulty();if H.difficultyState=='Detected' then return difficulties[i] elseif H.difficultyState=='Manual' then return difficulties[i]..' (manual)' elseif H.difficultyState=='Base rate' then return 'Difficulty unavailable (base rate)' end;return H.difficultyState end
function H.changeDifficulty(delta)
 local c=cfg();if not c then return end
 c.difficultyFallback=((c.difficultyFallback or 0)+(delta or 1))%5
end
function H.difficultyInfo()
 readDifficulty(true)
 return 'Native: '..tostring(H.rawDifficulty)..' | Player: '..tostring(H.rawPlayerDifficulty)..' | Disabled: '..tostring(H.rawReason)..'\nNative label: '..tostring(difficultyLabel(H.rawDifficulty))..' | Player label: '..tostring(difficultyLabel(H.rawPlayerDifficulty))..'\nEnums: '..table.concat(enumLines,', ')..'\nManual: '..(difficulties[(cfg() or {}).difficultyFallback] or 'Off')
end
discoverEnums()
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
 H.skillGlow=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);H.skillGlow:SetAnchorFill(root);H.skillGlow:SetTexture('ESOHardcore/Vignette.dds');H.skillGlow:SetMouseEnabled(false);H.skillGlow:SetHidden(true)
 H.staminaHaze=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);H.staminaHaze:SetAnchorFill(root);H.staminaHaze:SetTexture('ESOHardcore/BlurHaze.dds');H.staminaHaze:SetMouseEnabled(false);H.staminaHaze:SetHidden(true)
 local hud=WINDOW_MANAGER:CreateTopLevelWindow('ESOHardcoreNutrition');H.hud=hud;hud:SetDimensions(390,64);hud:SetMouseEnabled(false);hud:SetHidden(true)
 H.text=label(hud,23);H.text:SetAnchor(TOP,hud,TOP,0,0);H.text:SetDimensions(390,25)
 H.status=label(hud,19);H.status:SetAnchor(BOTTOM,hud,BOTTOM,0,0);H.status:SetDimensions(390,22)
 H.bars={};for i=1,2 do local bg=WINDOW_MANAGER:CreateControl(nil,hud,CT_TEXTURE);bg:SetDimensions(175,9);bg:SetAnchor(TOPLEFT,hud,TOPLEFT,i==1 and 10 or 205,29);bg:SetColor(.15,.13,.11,.85);local bar=WINDOW_MANAGER:CreateControl(nil,bg,CT_TEXTURE);bar:SetAnchor(TOPLEFT,bg,TOPLEFT);bar:SetColor(i==1 and .72 or .30,i==1 and .57 or .58,i==1 and .30 or .78,1);H.bars[i]=bar end
end
-- Restore original visibility outside active Hardcore gameplay.
local hidden,transparent={},{}
local function nativeHUD(active)
 local function suppress(control)
  if not control then return end
  local ok=pcall(function() if hidden[control]==nil then hidden[control]=control:IsHidden() end;if not control:IsHidden() then control:SetHidden(true) end end)
 end
 -- Do not mutate shared native scene fragments; only hide individual HUD controls.
 if not active then
  for control,was in pairs(hidden) do pcall(function() control:SetHidden(was) end);hidden[control]=nil end
  for control,was in pairs(transparent) do pcall(function() control:SetAlpha(was) end);transparent[control]=nil end
  return
 end
 -- Keep the native compass running for resource detection; suppress only its appearance.
 for _,name in ipairs({'ZO_Compass','ZO_CompassFrame','ZO_CompassContainer'}) do
  local control=_G[name]
  if control then pcall(function()
   if transparent[control]==nil then transparent[control]=control:GetAlpha() end
   if control:GetAlpha()~=0 then control:SetAlpha(0) end
  end) end
 end
 -- Candidate native controls; unavailable controls are ignored on console.
 for _,name in ipairs({'ZO_PromotionalEventTracker_TL','ZO_GoldenPursuitsTracker','ZO_GoldenPursuitsTrackerGamepad','ZO_GoldenPursuitsTracker_Keyboard','ZO_GoldenPursuitsTracker_Gamepad','ZO_Compass','ZO_CompassFrame','ZO_FocusedQuestTracker','ZO_FocusedQuestTrackerPanel','ZO_FocusedQuestTrackerGamepad','ZO_QuestTracker','ZO_QuestTrackerGamepad','ZO_PlayerAttributeHealth','ZO_PlayerAttributeMagicka','ZO_PlayerAttributeStamina','ZO_PlayerAttributeGamepadHealth','ZO_PlayerAttributeGamepadMagicka','ZO_PlayerAttributeGamepadStamina','ZO_PlayerAttributeHealthGamepad','ZO_PlayerAttributeMagickaGamepad','ZO_PlayerAttributeStaminaGamepad'}) do if not name:find("Compass",1,true) then suppress(_G[name]) end end
 for _,name in ipairs({'ZO_PlayerAttribute','ZO_PlayerAttributeBars','ZO_PlayerAttributeGamepad','ZO_PlayerAttributeBarsGamepad'}) do local root=_G[name];if root then for _,key in ipairs({'Health','Magicka','Stamina'}) do suppress(s(GetControl,root,key)) end end end
end
-- The engine's uniform blur is a fixed-strength effect. Refresh while owned,
-- as native scene transitions and other effects can clear it between ticks.
local nativeBlur=false
local blurRefresh=-100
local blurStatus='Not requested'
local function setFatigueBlur(on)
 on=on==true
 local t=now()
 if not on and not nativeBlur then return end
 if on and nativeBlur and t-blurRefresh<.75 then return end
 if on and not nativeBlur and t-blurRefresh<.75 then return end
 blurRefresh=t
 if type(SetFullscreenEffect)~='function' or FULLSCREEN_EFFECT_UNIFORM_BLUR==nil or FULLSCREEN_EFFECT_NONE==nil then
  blurStatus='Native blur API unavailable';return
 end
 local ok,err=pcall(SetFullscreenEffect,on and FULLSCREEN_EFFECT_UNIFORM_BLUR or FULLSCREEN_EFFECT_NONE,0,0,true)
 if ok then nativeBlur=on;if not on then blurRefresh=-100 end;blurStatus=on and 'Native blur requested' or 'Native blur cleared'
 else blurStatus='Native blur call failed: '..tostring(err) end
end
local function fatigueTarget(stamina,rank)
 if type(stamina)~='number' or rank<15 or stamina>=.45 then return 0,false end
 local depletion=math.max(0,math.min(1,(.45-stamina)/.45))
 local alpha=.20+.48*depletion
 if rank>=30 and stamina<.30 then alpha=alpha+.06 end
 if rank>=99 and stamina<.10 then alpha=alpha+.06 end
 return math.min(.80,alpha),rank>=30 and stamina<.30
end
function H.fatigueInfo()
 return string.format('Endurance %d | Stamina %s | Fatigue veil %d%% | %s',N.rank('Endurance'),H.fatigueStamina and tostring(math.floor(H.fatigueStamina*100))..'%' or 'unavailable',math.floor((H.fatigueAlpha or 0)*100),blurStatus)
end
local function tick()
 local c=cfg();if not c or not H.root then return end
 local t=now();local dt=math.max(0,math.min(2,t-(H.last or t)));H.last=t
 local visible=N.gameplay();nativeHUD(N.visualActive() and c.hideNativeHUD~=false and visible and not (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)));local combat=s(IsUnitInCombat,'player')==true
 if c.active and not c.fallen and (visible or combat) then local rate=(combat and 1.25 or 1)*(N.rank("Survivalist")>=50 and .9 or 1);c.survivalSeconds=(c.survivalSeconds or 0)+dt;c.difficultySeconds=c.difficultySeconds or {};local idx=H.difficulty();c.difficultySeconds[idx]=(c.difficultySeconds[idx] or 0)+dt;c.food=clamp(c.food-dt*100/9000*rate);c.water=clamp(c.water-dt*100/6000*rate) end
 local preview=H.previewUntil and H.previewUntil>t
 local show=visible and (N.visualActive() or preview);H.root:SetHidden(not show or not c.overlays);H.hud:SetHidden(not show or not c.meters or N.isImmersive())
 if N.expansionTick then N.expansionTick(dt,visible,combat) end
 if not c.active or c.fallen then if N.masteryTick then N.masteryTick() end end
 if N.skillsTick then N.skillsTick(dt,visible,combat) end
 if not show then setFatigueBlur(false);H.staminaHaze:SetHidden(true);H.fatigueAlpha=0;return end
 H.hud:ClearAnchors();H.hud:SetAnchor(BOTTOM,GuiRoot,BOTTOM,c.x,c.y);H.hud:SetScale(c.scale/100)
 H.text:SetText(string.format('Hunger %d%%       Thirst %d%%',math.floor(c.food),math.floor(c.water)));H.bars[1]:SetDimensions(175*c.food/100,9);H.bars[2]:SetDimensions(175*c.water/100,9)
 local hp,max=s(GetUnitPower,'player',COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH);local pct=type(hp)=='number' and type(max)=='number' and max>0 and hp/max or 1
 local effects={};local seen={};for slot,e in pairs(H.effects) do if type(e.ends)=='number' and e.ends>0 and e.ends<=t then H.effects[slot]=nil elseif not seen[e.kind] and c[e.kind] then effects[#effects+1]=e.kind;seen[e.kind]=true end end;table.sort(effects)
 H.status:SetText(c.fallen and 'FALLEN — run ended' or string.format('%s | XP %g%%%s',H.difficultyName(),H.multiplier()*100,#effects>0 and ' | '..names[effects[1]] or '')..(c.food<25 and ' | Hungry' or '')..(c.water<25 and ' | Thirsty' or ''))
 local power=c.health and pct<.75 and math.min(.72,(.75-pct)*.96) or 0
 local kind=effects[1] or (not N.isImmersive() and c.food<25 and c.hunger and 'hunger') or (not N.isImmersive() and c.water<25 and c.thirst and 'thirst') or 'health';local alpha=kind~='health' and .30 or 0
 if preview then kind=H.previewKind;alpha=.55;power=kind=='health' and .65 or 0 end
 local w,h=GuiRoot:GetDimensions();local intensity=c.intensity/100
 if power>0 and (power>=alpha or pct<.25) then kind,alpha='health',power end
 local col=colors[kind] or colors.health;H.vignette:SetColor(col[1],col[2],col[3],math.min(.95,alpha*intensity*1.55))
 local cue=N.skillEffect;local glow=H.skillGlow
 local haze=H.staminaHaze
 local sp,sm=s(GetUnitPower,'player',COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA);local staminaPct=type(sp)=='number' and type(sm)=='number' and sm>0 and sp/sm or nil
 local fatiguePreview=preview and H.previewKind=='skillFatigue'
 local allowed=c.overlays and intensity>0 and visible and not (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog))
 local hazeAlpha,wantsBlur=0,false
 if allowed and N.visualActive() and c.fatigueEffects~=false then hazeAlpha,wantsBlur=fatigueTarget(staminaPct,N.rank('Endurance')) end
 if allowed and fatiguePreview then hazeAlpha,wantsBlur=.76,true end
 H.fatigueStamina=staminaPct;H.fatigueAlpha=hazeAlpha
 -- Keep the low-health vignette visible; fatigue no longer depends on health.
 setFatigueBlur(wantsBlur)
 if hazeAlpha>0 then
  haze:SetColor(.68,.70,.64,math.min(.85,hazeAlpha*intensity));haze:SetHidden(false)
 else haze:SetHidden(true) end
 local previews={skillHarvest={'corner',{.93,.77,.38}},skillThreat={'side',{.35,.66,1}},skillRear={'rear',{.35,.66,1}},skillFatigue={'haze',{.65,.83,.39}},skillDanger={'vignette',{.95,.16,.20}},skillCombat={'corner',{.95,.72,.35}}}
 local pv=preview and previews[H.previewKind];if pv then H.vignette:SetColor(0,0,0,0);cue={style=pv[1],color=pv[2],start=H.previewUntil-30,ends=H.previewUntil,priority=5,strength=.65} end
 if cue and not (cue.style=='haze' and hazeAlpha>0) and cue.ends>t and (preview or N.visualActive()) and c.overlays and (pct>=.25 or cue.priority>=4) then
  local texture=cue.style=='rear' and 'RearGlow' or cue.style=='side' and 'SideGlow' or cue.style=='corner' and 'CornerGlow' or cue.style=='haze' and 'BlurHaze' or 'Vignette'
  if H.skillTexture~=texture then glow:SetTexture('ESOHardcore/'..texture..'.dds');H.skillTexture=texture end
  -- The paired side glow means a recent off-center sighting; no unverified left/right claim.
  local fade=math.min(1,(t-cue.start)*5,(cue.ends-t)*1.5);local pulse=.75+.25*math.sin((t-cue.start)*7)
  local a=math.max(0,fade)*pulse*cue.strength*intensity
  if power>0 or #effects>0 then a=a*.65 end
  glow:SetColor(cue.color[1],cue.color[2],cue.color[3],math.min(.75,a));glow:SetHidden(false)
 else glow:SetHidden(true) end


end
local function death() local c=cfg();if c and c.active and not c.fallen then c.fallen=true;c.deathTime=s(GetTimeStamp) or 0;if N.archiveDeath then N.archiveDeath() end;if N.economyDeath then N.economyDeath() end;if d then d('Tamriel Unbound: Fallen. This character’s test run has ended.') end end end
N.simulateDeath=death
-- Manual provision controls are intentionally labelled test-only until consumption events are verified.
function H.options()
 local c=cfg();if not c then return {} end
 local o={{type='description',text='Experimental character-local Hardcore preview. Ruleset restrictions remain honor-based. Automatic nutrition is experimental; test controls are retained as fallback.'}}
 local function toggle(k,n) o[#o+1]={type='checkbox',name=n,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 local function slider(k,n,a,b) o[#o+1]={type='slider',name=n,min=a,max=b,step=5,getFunc=function()return c[k]end,setFunc=function(v)c[k]=v end} end
 o[#o+1]={type='checkbox',name='Activate Hardcore test run',getFunc=function()return c.active end,setFunc=function(v) if not c.fallen then c.active=v end end}
 toggle('combatCamera','Immersive Combat Camera');toggle('overlays','Immersive overlays');toggle('meters','Nutrition HUD');slider('intensity','Overlay intensity',0,100);slider('x','Nutrition X',-1000,1000);slider('y','Nutrition Y',-900,0);slider('scale','Nutrition scale',50,150)
 for _,k in ipairs({'health','poison','burn','disease','chill','shock','bleed','control','hunger','thirst'}) do local key=k;toggle(key,'Show '..(names[key] or key));o[#o+1]={type='button',name='Preview '..(names[key] or key),func=function() H.previewKind=key;H.previewUntil=now()+20 end} end
 o[#o+1]={type='button',name='TEST: restore hunger',func=function()c.food=100 end};o[#o+1]={type='button',name='TEST: restore thirst',func=function()c.water=100 end};return o
end
EVENT_MANAGER:RegisterForEvent('ESOHardcoreInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='ESOHardcore' then return end;EVENT_MANAGER:UnregisterForEvent('ESOHardcoreInit',EVENT_ADD_ON_LOADED)
 local ok,err=pcall(function()
 H.saved=ZO_SavedVars:NewCharacterIdSettings('ESOHardcoreSaved',1,nil,{active=false,fallen=false,immersiveMode=false,hideNativeHUD=true,resourceAuras=true,materialOverlay=true,fatigueEffects=true,combatCamera=true,food=100,water=100,overlays=true,meters=true,intensity=90,x=0,y=-230,scale=100,health=true,poison=true,burn=true,disease=true,chill=true,shock=true,bleed=true,control=true,hunger=true,thirst=true})
 build();if N.combatCamera then N.combatCamera.init() end;if N.initSkills then N.initSkills() end;if N.initExpansion then N.initExpansion() end;if N.economyInit then N.economyInit() end;if EVENT_EFFECT_CHANGED then EVENT_MANAGER:RegisterForEvent('ESOHardcoreEffects',EVENT_EFFECT_CHANGED,effect) end;if EVENT_PLAYER_DEAD then EVENT_MANAGER:RegisterForEvent('ESOHardcoreDeath',EVENT_PLAYER_DEAD,death) end
 if EVENT_PLAYER_DEACTIVATED then EVENT_MANAGER:RegisterForEvent('ESOHCBlurCleanup',EVENT_PLAYER_DEACTIVATED,function() setFatigueBlur(false) end) end
 EVENT_MANAGER:RegisterForUpdate('ESOHardcoreTick',250,function() local good,e=pcall(tick);if not good then setFatigueBlur(false);nativeHUD(false);H.root:SetHidden(true);H.hud:SetHidden(true);EVENT_MANAGER:UnregisterForUpdate('ESOHardcoreTick');if d then d('Tamriel Unbound preview disabled: '..tostring(e)) end end end)
 end);if not ok and d then d('Tamriel Unbound init: '..tostring(err)) end
end)
