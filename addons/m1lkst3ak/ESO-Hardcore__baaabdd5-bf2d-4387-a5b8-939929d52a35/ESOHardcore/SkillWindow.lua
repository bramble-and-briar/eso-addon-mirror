local N=ESOHardcore
local layerName="ESO Hardcore Directions"
if ZO_CreateStringId then ZO_CreateStringId("SI_ESOHC_GRID_LAYER",layerName) end
local W={selected=1,page=1,detail=false,tiles={}}
local names=N.skillNames
local wm=WINDOW_MANAGER
local gold={.86,.71,.43,1}
local pale={.88,.86,.79,1}
local guides={
{'Gather resource nodes','Harvest statistics','Node recording','Known node markers','Nearby resource hints','Farming routes','Efficiency analysis'},
{'Blacksmith equipment and research','Crafting statistics','Material inventory','Research planner','Cost estimator','Set advisor','Crafting optimization'},
{'Craft wooden equipment','Crafting statistics','Material inventory','Research planner','Cost estimator','Set advisor','Crafting optimization'},
{'Craft cloth and leather equipment','Crafting statistics','Material inventory','Research planner','Cost estimator','Set advisor','Crafting optimization'},
{'Create potions and poisons','Crafting statistics','Ingredient reference','Reagent inventory','Recipe advisor','Cost analysis','Alchemy workshop'},
{'Craft glyphs','Crafting statistics','Rune reference','Recipe calculator','Glyph catalog','Enchanting advisor','Glyph optimization'},
{'Prepare food and drink','Cooking statistics','Recipe catalog','Ingredient tracking','Food recommendations','Buff expiry alerts','Nutrition advisor'},
{'Craft jewelry','Crafting statistics','Material inventory','Research planner','Cost estimator','Set advisor','Crafting optimization'},
{'Catch fish','Fishing journal','Known fishing holes','Bait reference','Rare fish tracker','Expedition planner','Fishing analysis'},
{'Complete quests and discover places','Adventure journal','Lore intelligence','Narrative continuity','Zone advisor','Adventure finder','Progression advisor'},
{'Defeat enemies and bosses','Kill journal','Enemy statistics','Known bosses','Slayer assignments','Boss intelligence','Master contracts'},
{'Complete group dungeons','Dungeon journal','Career statistics','DPS and HPS','Role analysis','Boss intelligence','Performance reports'},
{'Earn qualifying alliance points','PvP statistics','Match history','Opponent history','Battlefield intelligence','Mission advisor','Career analytics'},
{'Craft and place furnishings','Housing journal','Furniture catalog','Duplicate detection','Material planner','Estate valuation','Estate dashboard'},
{'Earn gold through permitted NPC sales','Income tracker','Loot valuation','Deconstruction advisor','Wealth dashboard','NPC sale advisor','Profit analysis'},
{'Pickpocket, lockpick and fence','Criminal journal','Fencing tracker','Known safe boxes','Bounty advisor','Heist routes','Career dashboard'},
{'Scry and excavate antiquities','Excavation journal','Lead tracker','Expiry reminders','Regional advisor','Acquisition guide','Expedition planner'},
{'Survive active gameplay','Survival journal','Equipment warnings','Critical health awareness','Danger indicators','Threat awareness','Survival intelligence'},
{'Survive combat encounters','Engagement history','Combat alert','Danger warning','Directional indicators','Rear threat awareness','Threat prioritization'},
{'Sustain combat','Expedition tracker','Fatigue awareness','Stamina warnings','Resource trends','Combat efficiency','Resource advisor'},
{'Discover locations','Travel journal','Landmark catalog','Cardinal compass','Known routes','Sanctuary guidance','Return navigation'},
{'Heal and recover in combat','Healing journal','Potion warnings','Status recognition','Damage trends','Recovery advisor','Emergency alerts'},
{'Interrupt and defeat enemies','Combat journal','Block and dodge stats','Interrupt analysis','Attack reference','Defensive feedback','Combat analysis'},
{'Craft your own supplies','Wealth tracker','Acquisition journal','Supply dashboard','Equipment advisor','Shortage warnings','Self-sufficiency advisor'},
{'Establish a residence','Residence journal','Storage ledger','Supply inventory','Preparation checklist','Shortage advisor','Sanctuary dashboard'},
{'Sneak and evade detection','Stealth journal','Detection history','Escape statistics','Disengagement feedback','Known safe routes','Evasion analysis'} }
local marks={5,15,30,50,75,99}
local icons={'crafting','blacksmithing','woodworking','clothier','alchemy','enchanting','provisioning','jewelrycrafting'}
local function label(parent,size,x,y,w,h)
 local l=wm:CreateControl(nil,parent,CT_LABEL);l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);l:SetDimensions(w,h);l:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick');l:SetColor(unpack(pale));return l
end
local function bg(parent,x,y,w,h,r,g,b,a)
 local t=wm:CreateControl(nil,parent,CT_TEXTURE);t:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);t:SetDimensions(w,h);t:SetColor(r,g,b,a);return t
end
local function data(i) local a=N.hardcore.saved;local x=(a.xp or {})[names[i]] or 0;local l=N.skillLevel(x);local lo=N.skillThreshold(l);local hi=N.skillThreshold(math.min(99,l+1));return x,l,l==99 and 1 or math.max(0,math.min(1,(x-lo)/math.max(1,hi-lo))) end
local function refresh()
 local a=N.hardcore.saved;local total=0;for i=1,#names do local _,l=data(i);total=total+l end
 W.header:SetText('ESO HARDCORE   |   '..({'SKILLS','SURVIVAL','CAREER','ASSIGNMENTS','RULESET','FALLEN','DEVELOPER','HC INVENTORY','HC BANK','INTEGRITY LOG'})[W.page]);W.sub:SetText('Total level '..total..' / 2574  |  '..(a.fallen and 'FALLEN' or a.active and 'ACTIVE' or 'NOT ENROLLED'))
 local grid=W.page==1 and not W.detail;W.grid:SetHidden(not grid);W.body:SetHidden(grid or W.page==8 or W.page==9);if N.bagGrid then N.bagGrid.render(W.page) end
 if grid then for i,t in ipairs(W.tiles) do local _,l,p=data(i);t.level:SetText(tostring(l)..(l==99 and ' *' or ''));t.fill:SetWidth(math.max(1,170*p));t.back:SetColor(i==W.selected and .28 or .12,i==W.selected and .21 or .10,i==W.selected and .13 or .09,1) end;W.footer:SetText('D-pad: Select    X: Skill guide    L1 / R1: Pages    Circle: Close')
 elseif W.page==1 then local x,l,p=data(W.selected);local g=guides[W.selected];local lines={names[W.selected]..'   |   Level '..l..'/99',string.format('XP: %d   |   %s',math.floor(x),l==99 and 'Mastered' or math.ceil(N.skillThreshold(l+1)-x)..' XP to next level'),'Progress: '..math.floor(p*100)..'%','XP sources: '..g[1],'','SKILL UNLOCKS (guide entries are planned unless listed below)' };for j,m in ipairs(marks) do lines[#lines+1]=string.format('Level %d  |  %s  |  %s',m,g[j+1],l>=m and 'Level met' or 'Locked') end;if names[W.selected]=='Pathfinding' then lines[#lines+1]='Implemented: level 30 native compass' elseif names[W.selected]=='Adventuring' then lines[#lines+1]='Implemented: level 15 quest tracker' elseif names[W.selected]=='Survivalist' then lines[#lines+1]='Implemented: level 50 slower nutrition' end;if N.skillJournal then lines[#lines+1]=N.skillJournal(names[W.selected]) end;W.body:SetText(table.concat(lines,'\n'));W.footer:SetText('Circle: Skills grid    L1 / R1: Pages')
 elseif W.page==2 then W.body:SetText(string.format('Hunger: %d%%\nThirst: %d%%\nSkill XP multiplier: %g%%\n\nMaintain both meters to maximize progression.\nAutomatic nutrition: enabled.\nSurvivalist 50: 10%% slower depletion.',math.floor(a.food),math.floor(a.water),N.hardcore.multiplier()*100));W.body:SetText(W.body:GetText()..'\n\nDifficulty: '..N.hardcore.difficultyName()..'\nAutomatically read from ESO character sheet.');W.footer:SetText('L1/R1: Pages    Circle: Close')
 elseif W.page==3 then W.body:SetText('Character: '..tostring(N.safe(GetUnitName,'player') or '')..'\nStatus: '..(a.fallen and 'Fallen' or a.active and 'Active' or 'Not enrolled')..'\nTotal skill level: '..total..' / 2574\nActive survival time: '..math.floor((a.survivalSeconds or 0)/60)..' minutes'..'\n\n'..N.journalText());W.footer:SetText('L1 / R1: Pages    Circle: Close')
 elseif W.page==8 or W.page==9 then W.footer:SetText("D-pad: Select    X: Category    L1/R1: Pages    Circle: Close")
 elseif W.page==10 then W.body:SetText(N.economyText(W.page).."\n\nRECENT EVENTS\n"..N.economyDebug());W.footer:SetText('D-pad: Browse / sort    L1 / R1: Pages    Circle: Close')
 elseif W.page==7 then W.body:SetText(N.dev.text());W.footer:SetText("D-pad: Adjust/select    X: Apply    Circle: Close")
 else W.body:SetText(N.expansionPage(W.page));W.footer:SetText('L1 / R1: Pages    Circle: Close') end
end
local function move(dx,dy) if W.page==2 then return end;if W.page==8 or W.page==9 then N.bagGrid.move(dx,dy);refresh();return end;if W.page==7 then N.dev.move(dx,dy);refresh();return end;if W.page~=1 or W.detail then return end;W.selected=math.max(1,math.min(#names,W.selected+dx+dy*4));refresh() end
local function release()
 W.focus=false
 if W.layer then W.layer=false;N.safe(RemoveActionLayerByName,layerName) end
 if W.keysAdded then W.keysAdded=false;N.safe(KEYBIND_STRIP.RemoveKeybindButtonGroup,KEYBIND_STRIP,W.keys) end
 if W.root then W.root:SetHidden(true) end
end
function ESOHardcoreGridInput(action)
 if not W.focus or SCENE_MANAGER:GetCurrentScene()~=W.scene or (ZO_Dialogs_IsShowingDialog and N.safe(ZO_Dialogs_IsShowingDialog)) then return end
 if action=='LEFT' then move(-1,0) elseif action=='RIGHT' then move(1,0) elseif action=='UP' then move(0,-1) elseif action=='DOWN' then move(0,1)
 elseif action=='primary' then if W.page==8 or W.page==9 then N.bagGrid.apply();refresh() elseif W.page==7 then if N.dev.apply() then W.focus=false;SCENE_MANAGER:HideCurrentScene() else refresh() end elseif W.page==1 then W.detail=not W.detail;refresh() end
 elseif action=='prev' then W.page=(W.page+8)%10+1;W.detail=false;N.dev.confirm=nil;refresh()
 elseif action=='next' then W.page=W.page%10+1;W.detail=false;N.dev.confirm=nil;refresh()
 elseif action=='back' then if W.detail then W.detail=false;N.dev.confirm=nil;refresh() else W.focus=false;SCENE_MANAGER:HideCurrentScene() end end
end
function N.buildSkillWindow()
 local root=wm:CreateTopLevelWindow('ESOHardcoreSkillWindow');W.root=root;root:SetAnchor(CENTER,GuiRoot,CENTER);root:SetDimensions(960,760);root:SetHidden(true);root:SetDrawLayer(DL_OVERLAY);root:SetDrawTier(DT_HIGH);root:SetMouseEnabled(false)
 bg(root,0,0,960,760,.055,.045,.04,.98);bg(root,16,75,928,2,.64,.43,.25,1)
 W.header=label(root,34,24,15,900,42);W.header:SetColor(unpack(gold));W.sub=label(root,22,24,83,900,32)
 W.grid=wm:CreateControl(nil,root,CT_CONTROL);W.grid:SetAnchorFill(root)
 for i,k in ipairs(names) do local x=24+((i-1)%4)*230;local y=125+math.floor((i-1)/4)*82;local t={};W.tiles[i]=t;t.back=bg(W.grid,x,y,218,74,.12,.10,.09,1);local num=label(t.back,16,8,8,32,22);num:SetText(string.format('%02d',i));num:SetColor(unpack(gold));local name=label(t.back,20,40,7,174,26);name:SetText(k);t.level=label(t.back,25,12,34,190,30);bg(t.back,40,60,170,4,.24,.20,.17,1);t.fill=bg(t.back,40,60,1,4,.76,.56,.30,1) end
 W.body=label(root,24,32,130,895,560);W.footer=label(root,19,24,716,920,35);W.footer:SetColor(unpack(gold));N.bagGrid.build(root)
end
local function setup()
 if W.scene then return true end
 if not (ZO_Scene and SCENE_MANAGER and KEYBIND_STRIP and FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW) then if d then d('Hardcore: native gamepad window unavailable') end;return false end
 if not W.root then N.buildSkillWindow() end
 W.scene=ZO_Scene:New('ESOHardcoreSkillsScene',SCENE_MANAGER)
 W.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
 if W.scene.SetInputPreferredMode and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD then W.scene:SetInputPreferredMode(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD) end
 if GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then W.scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT) end
 W.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT}
 local function key(binding,name,action) W.keys[#W.keys+1]={keybind=binding,name=name,callback=function() ESOHardcoreGridInput(action) end} end
 key('UI_SHORTCUT_LEFT_SHOULDER','Previous page','prev');key('UI_SHORTCUT_RIGHT_SHOULDER','Next page','next');key('UI_SHORTCUT_PRIMARY','Skill guide','primary');key('UI_SHORTCUT_NEGATIVE','Back','back')
 W.scene:RegisterCallback('StateChange',function(_,state)
  if state==SCENE_SHOWING then local w,h=GuiRoot:GetDimensions();W.root:SetScale(math.min(1,w/1020,h/810));refresh();W.root:SetHidden(false)
  elseif state==SCENE_SHOWN then
   local ok,err=pcall(function() KEYBIND_STRIP:AddKeybindButtonGroup(W.keys) end)
   if not ok then if d then d('Hardcore keybind error: '..tostring(err)) end;release();SCENE_MANAGER:HideCurrentScene();return end
   W.keysAdded=true;W.focus=true
   local ready=true;local dirs={'LEFT','RIGHT','UP','DOWN'}
   for _,suffix in ipairs(dirs) do local action='ESOHC_GRID_'..suffix;local code=_G['KEY_GAMEPAD_DPAD_'..suffix]
    if not (CreateDefaultActionBind and code and KEY_INVALID and GetActionIndicesFromName and N.safe(GetActionIndicesFromName,action)) then ready=false
    else local success=pcall(CreateDefaultActionBind,action,code,KEY_INVALID,KEY_INVALID,KEY_INVALID,KEY_INVALID);ready=ready and success end
   end
   if ready and PushActionLayerByName and RemoveActionLayerByName then local pushed=pcall(PushActionLayerByName,layerName);W.layer=pushed;if pushed and IsActionLayerActiveByName then ready=N.safe(IsActionLayerActiveByName,layerName)==true else ready=pushed end else ready=false end
   local bound=0;if GetHighestPriorityActionBindingInfoFromName then for _,suffix in ipairs(dirs) do if N.safe(GetHighestPriorityActionBindingInfoFromName,'ESOHC_GRID_'..suffix,true)==_G['KEY_GAMEPAD_DPAD_'..suffix] then bound=bound+1 end end end
   if d then d('Hardcore: D-pad layer '..(ready and 'active' or 'unavailable')..'; verified bindings '..bound..'/4.') end
  elseif state==SCENE_HIDING or state==SCENE_HIDDEN then release() end
 end)
 return true
end
function N.openSkillWindow() W.page=1;W.detail=false;N.dev.confirm=nil;if setup() then SCENE_MANAGER:Show('ESOHardcoreSkillsScene') end end

-- Radial shortcuts share the existing controller scene and its cleanup.
function N.toggleHardcorePage(page)
 if not N.hardcore or not N.hardcore.saved then return end
 if W.scene and SCENE_MANAGER:GetCurrentScene()==W.scene then
  if W.page==page then W.focus=false;SCENE_MANAGER:HideCurrentScene();return end
  W.page=page;W.detail=false;N.dev.confirm=nil;refresh();return
 end
 W.page=page;W.detail=false;N.dev.confirm=nil
 if setup() then SCENE_MANAGER:Show('ESOHardcoreSkillsScene') end
end
