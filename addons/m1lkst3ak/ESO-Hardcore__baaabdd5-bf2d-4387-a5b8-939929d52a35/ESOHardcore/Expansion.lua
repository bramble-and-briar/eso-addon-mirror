local N=ESOHardcore;local s=N.safe
local function c() return N.hardcore.saved end
local function day() return math.floor((s(GetTimeStamp) or 0)/86400) end
local tasks={{'Adventuring',3,100},{'Slayer',15,120},{'Provisioning',5,100},{'Self-Reliance',8,120},{'Pathfinding',3,120},{'Combat Mastery',5,100},{'Harvesting',12,120},{'Smithing',5,100},{'Woodworking',5,100},{'Tailoring',5,100},{'Alchemy',5,100},{'Enchanting',5,100},{'Jewelry',5,100}}
local function daily()
 local a=c();local d=day();if not a.daily or a.daily.day~=d then a.daily={day=d,counts={},done={}} end;return a.daily
end
local function selected(d,i) local q=daily();if not q.selection then local size=6;if not next(q.counts) and not next(q.done) then size=#tasks end;q.selection={};for n=1,3 do q.selection[n]=(d+n-1)%size+1 end end;return tasks[q.selection[i]] end
local rewarding=false
function N.trackAction(k)
 if rewarding then return end
 if N.journalAction then N.journalAction(k) end
 local a=c();local q=daily();a.contract=a.contract or {count=0,done=false}
 for i=1,3 do local t=selected(q.day,i);if k==t[1] and not q.done[i] then q.counts[i]=(q.counts[i] or 0)+1;if q.counts[i]>=t[2] then q.done[i]=true;rewarding=true;N.award(k,t[3]);rewarding=false end end end
 if k=='Self-Reliance' and not a.contract.done then a.contract.count=a.contract.count+1;if a.contract.count>=25 then a.contract.done=true;rewarding=true;N.award(k,500);rewarding=false end end
end
local function copy(v) if type(v)~="table" then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
function N.archiveDeath()
 local a=c();local hall=N.hall;if not hall then return end;local record={name=s(GetUnitName,'player') or '?',race=s(GetUnitRace,'player'),class=s(GetUnitClass,'player'),level=s(GetUnitLevel,'player'),zone=s(GetUnitZone,'player'),seconds=a.survivalSeconds or 0,time=a.deathTime,skills={},journal=copy(a.journal),difficultySeconds=copy(a.difficultySeconds)}
 for _,k in ipairs(N.skillNames) do record.skills[k]=N.rank(k) end;hall.records[#hall.records+1]=record
end
function N.expansionPage(page)
 local a=c();if page==4 then local q=daily();local lines={'DAILY ASSIGNMENTS (UTC reset)','Rewards use current nutrition multiplier.',''};for i=1,3 do local t=selected(q.day,i);lines[#lines+1]=string.format('%s actions: %d/%d | %s',t[1],q.counts[i] or 0,t[2],q.done[i] and 'Complete' or '+'..t[3]..' XP') end;local k=a.contract or {count=0};lines[#lines+1]='';lines[#lines+1]='CONTRACT: Self-made adventurer';lines[#lines+1]=string.format('Crafting actions: %d/25 | %s',k.count,k.done and 'Complete' or '+500 XP');return table.concat(lines,'\n')
 elseif page==5 then return 'RULESET INTEGRITY\n\nDeath: tracked locally; manual deletion.\nFirst person: honor-based. Difficulty selectable.\nTrading / mail / shared bank: honor-based.\nShared HC Craft Bag allowed; guild traders prohibited.\nHardcore-only groups / Champion Points: honor-based.\nNo automatic disqualification from uncertain API signals.'
 else local lines={'HALL OF THE FALLEN','Account-wide records | newest first',''};local r=N.hall and N.hall.records or {};for i=#r,math.max(1,#r-7),-1 do local v=r[i];lines[#lines+1]=string.format('%s | Lv %s | %s | %d min',v.name,tostring(v.level or '?'),v.zone or '?',math.floor(v.seconds/60)) end;if #r==0 then lines[#lines+1]='No fallen characters recorded in this version.' end;return table.concat(lines,'\n') end
end
-- Item use detection: only restore after a matching player buff appears following a food/drink stack decrease.
local candidate,lastBuff=nil,nil;local snapshots={};local lastCombat=false
local function clock() return s(GetFrameTimeSeconds) or 0 end
local function matchNutrition()
 if not candidate or not lastBuff or math.abs(candidate.at-lastBuff)>5 then return end
 local a=c();if not a.active or a.fallen then candidate=nil;lastBuff=nil;return end
 local amount=candidate.amount;local key=candidate.kind==ITEMTYPE_FOOD and 'food' or 'water';a[key]=math.min(100,a[key]+amount);candidate=nil;lastBuff=nil
 if d then d('Hardcore: restored '..amount..'% '..(key=='food' and 'hunger' or 'thirst')) end
end
local function slot(_,bag,slotId,isNew,sound,reason,delta)
 if bag~=BAG_BACKPACK then return end
 local old=snapshots[slotId];local link=s(GetItemLink,bag,slotId,LINK_STYLE_DEFAULT);local count=s(GetSlotStackSize,bag,slotId) or 0
 local kind=link and s(GetItemLinkItemType,link);local quality=link and (s(GetItemLinkDisplayQuality,link) or s(GetItemLinkQuality,link));local amount=20
 for _,v in ipairs({{ITEM_DISPLAY_QUALITY_NORMAL or ITEM_QUALITY_NORMAL,20},{ITEM_DISPLAY_QUALITY_MAGIC or ITEM_QUALITY_MAGIC,35},{ITEM_DISPLAY_QUALITY_ARCANE or ITEM_QUALITY_ARCANE,50},{ITEM_DISPLAY_QUALITY_ARTIFACT or ITEM_QUALITY_ARTIFACT,75},{ITEM_DISPLAY_QUALITY_LEGENDARY or ITEM_QUALITY_LEGENDARY,100}}) do if quality~=nil and quality==v[1] then amount=v[2] end end
 snapshots[slotId]={link=link,count=count,kind=kind,amount=amount}
 if not c().active or c().fallen or not old then return end
 if (tonumber(delta) or count-old.count)<0 and old.kind~=nil and (old.kind==ITEMTYPE_FOOD or old.kind==ITEMTYPE_DRINK) then
 candidate={kind=old.kind,amount=old.amount,at=clock()};matchNutrition()
 end
end
local function nutrition(_,change,slotId,name,tag,beginTime,endTime)
 if tag~='player' or change==EFFECT_RESULT_FADED then return end
 if type(beginTime)~='number' or type(endTime)~='number' or endTime-beginTime<300 then return end
 lastBuff=clock();matchNutrition()
end
local lastHarvest=-100;local harvestAwarded=false
local function harvestContext()
 local action,_,_,_,_,interaction=s(GetGameCameraInteractableActionInfo)
 if (INTERACTION_HARVEST and s(GetInteractionType)==INTERACTION_HARVEST) or (type(action)=='string' and action:lower():find('harvest',1,true)) or (INTERACTION_HARVEST and interaction==INTERACTION_HARVEST) then
 if clock()-lastHarvest>1 then harvestAwarded=false end;lastHarvest=clock()
 end
end
local function harvestLoot(_,receivedBy,item,qty,sound,lootType,selfLoot)
 if selfLoot~=true or harvestAwarded or clock()-lastHarvest>8 then return end
 if LOOT_TYPE_ITEM and lootType~=LOOT_TYPE_ITEM then return end
 harvestAwarded=true;N.award('Harvesting',30);if N.recordNode then N.recordNode() end
end
function N.expansionTick(dt,visible,combat)
 local a=c();if not a.active or a.fallen then return end
 harvestContext()
 if N.progressTick then N.progressTick(dt,visible,combat) end
 if visible and combat and not lastCombat and N.rank('Perception')>=15 then if d then d('Hardcore: combat engagement') end end;lastCombat=combat
end
function N.initExpansion()
 N.hall=ZO_SavedVars:NewAccountWide('ESOHardcoreSaved',1,'Hall',{records={}})
 if BAG_BACKPACK and GetBagSize then for i=0,(s(GetBagSize,BAG_BACKPACK) or 0)-1 do pcall(slot,nil,BAG_BACKPACK,i) end end
 if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then EVENT_MANAGER:RegisterForEvent('ESOHCNutritionInventory',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(...) pcall(slot,...) end) end
 if EVENT_LOOT_RECEIVED then EVENT_MANAGER:RegisterForEvent('ESOHCHarvestLoot',EVENT_LOOT_RECEIVED,function(...) pcall(harvestLoot,...) end) end
 if EVENT_EFFECT_CHANGED then EVENT_MANAGER:RegisterForEvent('ESOHCNutritionBuff',EVENT_EFFECT_CHANGED,function(...) pcall(nutrition,...) end) end
end
