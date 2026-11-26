local N=ESOHardcore;local s=N.safe
local skills={'Harvesting','Smithing','Woodworking','Tailoring','Alchemy','Enchanting','Provisioning','Jewelry','Fishing','Adventuring','Slayer','Dungeoneering','Warfare','Housing','Commerce','Thievery','Antiquities','Survivalist','Perception','Endurance','Pathfinding','Medicine','Combat Mastery','Self-Reliance','Fortification','Stealth'}
local function c() return N.hardcore.saved end
local function threshold(l) return math.floor(250*(1.08^(l-1)-1)) end
local function level(x) local l=1;while l<99 and x>=threshold(l+1) do l=l+1 end;return l end
local pending={};local function award(k,x)
 local a=c();if not a.active or a.fallen then return end;if N.trackAction then N.trackAction(k) end;x=x*N.hardcore.multiplier()*(a.devXP or 1);if x<=0 then return end
 local old=a.xp[k] or 0;a.xp[k]=math.min(threshold(99),old+x);local gain=a.xp[k]-old;if gain<=0 then return end
 pending[k]=(pending[k] or 0)+gain;if level(a.xp[k])>level(old) then N.notice=k..' level '..level(a.xp[k]) end
end
N.award=award
function N.clearSkillNotices() pending={};N.notice=nil;N.dropUntil=0 end
function N.rank(k) local a=c();return level(a and a.xp and a.xp[k] or 0) end
local function event(name,ev,fn) if ev then EVENT_MANAGER:RegisterForEvent('ESOHC'..name,ev,function(...) local ok,err=pcall(fn,...);if not ok then EVENT_MANAGER:UnregisterForEvent('ESOHC'..name,ev);if d then d('ESO Hardcore event '..name..': '..tostring(err)) end end end) end end
local function dialog(id,title,body,buttons)
 ZO_Dialogs_RegisterCustomDialog(id,{gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text=title},mainText={text=body},buttons=buttons});ZO_Dialogs_ShowGamepadDialog(id)
end
N.skillNames=skills;N.skillLevel=level;N.skillThreshold=threshold
local function overview() N.openSkillWindow() end
local function setup()
 local a=c();if a.setupDone then overview();return end
 dialog('ESOHCSetup','ESO Hardcore | One life','Start only on a fresh character. Disable all other add-ons for this character. First person, selectable difficulty, no trade, non-Hardcore bank resources, unowned crafting materials, guild traders or non-Hardcore groups. Death ends the run; delete manually. Most restrictions are honor rules in this preview.',{{keybind='DIALOG_PRIMARY',text='Begin Hardcore',callback=function() if (s(GetUnitLevel,'player') or 99)>3 then if d then d('Use a new character (level 1–3).') end;return end;a.active=true;a.setupDone=true end},{keybind='DIALOG_NEGATIVE',text='Not now'}})
end
local elapsed=0;local combatTime=0;local lastCombat=false;local dropTime=0
function N.skillsTick(dt,visible,combat)
 if not c().active or c().fallen then return end
 if visible or combat then elapsed=elapsed+dt;if combat then combatTime=combatTime+dt end end
 if elapsed>=60 then elapsed=elapsed-60;award('Survivalist',20) end
 if lastCombat and not combat and combatTime>=5 then award('Perception',20);award('Endurance',math.min(60,combatTime));combatTime=0 end;lastCombat=combat
 dropTime=dropTime+dt;if visible and dropTime>=1 then dropTime=0;local l={};for k,v in pairs(pending) do l[#l+1]=string.format('+%g %s XP',math.floor(v*10)/10,k) end;pending={};if N.notice then l[#l+1]=N.notice;N.notice=nil end;if #l>0 then N.drop:SetText(table.concat(l,'\n'));N.dropUntil=(s(GetFrameTimeSeconds) or 0)+5 end end
 N.drop:SetHidden(not visible or (s(GetFrameTimeSeconds) or 0)>(N.dropUntil or 0))
end
function N.initSkills()
 local a=c();a.xp=a.xp or {};local w=WINDOW_MANAGER:CreateTopLevelWindow('ESOHCXP');w:SetHidden(false);w:SetDrawLayer(DL_OVERLAY);w:SetDrawTier(DT_HIGH);w:SetDimensions(350,180);w:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-100,180);w:SetMouseEnabled(false);N.drop=WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL);N.drop:SetAnchorFill(w);N.drop:SetHorizontalAlignment(TEXT_ALIGN_RIGHT);N.drop:SetVerticalAlignment(TEXT_ALIGN_TOP);N.drop:SetFont('$(BOLD_FONT)|30|soft-shadow-thick');N.drop:SetColor(.9,.77,.45,1);N.drop:SetHidden(true)
 event('Quest',EVENT_QUEST_COMPLETE,function() award('Adventuring',100) end)
 event('Craft',EVENT_CRAFT_COMPLETED,function(_,craft) local map={};for _,p in ipairs({{CRAFTING_TYPE_BLACKSMITHING,'Smithing'},{CRAFTING_TYPE_CLOTHIER,'Tailoring'},{CRAFTING_TYPE_WOODWORKING,'Woodworking'},{CRAFTING_TYPE_JEWELRYCRAFTING,'Jewelry'},{CRAFTING_TYPE_ALCHEMY,'Alchemy'},{CRAFTING_TYPE_ENCHANTING,'Enchanting'},{CRAFTING_TYPE_PROVISIONING,'Provisioning'}}) do if p[1] then map[p[1]]=p[2] end end;local k=map[craft or s(GetCraftingInteractionType)];if k then award(k,30);award('Self-Reliance',10) end end)
 event('POI',EVENT_POI_DISCOVERED,function() award('Pathfinding',80);award('Adventuring',40) end)
 event('Dungeon',EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE,function() if s(IsUnitInDungeon,'player') then award('Dungeoneering',250) end end)
 event('AP',EVENT_ALLIANCE_POINT_UPDATE,function(_,total,delta) if type(delta)=='number' and delta>0 then award('Warfare',math.min(80,delta/20)) end end)
 event('Combat',EVENT_COMBAT_EVENT,function(_,result,err,ability,graphic,action,source,sourceType,target,targetType,value) if err or sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end;if result==ACTION_RESULT_KILLING_BLOW then award('Slayer',15) elseif result==ACTION_RESULT_INTERRUPT then award('Combat Mastery',20) end end)
 N.buildSkillWindow(); ESOHardcoreOpen=setup; if ZO_CreateStringId then ZO_CreateStringId('SI_BINDING_NAME_ESO_HARDCORE_OPEN','ESO Hardcore: Open skills') end; if SLASH_COMMANDS then SLASH_COMMANDS['/hardcore']=setup end
 if LibAddonMenu2 then local id='ESOHardcoreSettings';LibAddonMenu2:RegisterAddonPanel(id,{type='panel',name='ESO Hardcore',displayName='ESO Hardcore',author='Trash Man Enterprises',version='0.8.0'});local o={{type='button',name='Open Hardcore skills / setup',func=setup}};for _,v in ipairs(N.hardcore.options()) do if v.name and v.name~='Activate Hardcore test run' then o[#o+1]=v end end;LibAddonMenu2:RegisterOptionControls(id,o) end
 EVENT_MANAGER:RegisterForUpdate('ESOHCSetupPrompt',2000,function() if N.gameplay() and not s(IsUnitInCombat,'player') then EVENT_MANAGER:UnregisterForUpdate('ESOHCSetupPrompt');if not a.setupDone then pcall(setup) end end end)
end
