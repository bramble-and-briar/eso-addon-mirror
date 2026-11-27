local N=ESOHardcore;local s=N.safe
local function c() return N.hardcore.saved end
function N.trackAction(k,base)
 if N.rewards then N.rewards.record(k,base) end
 if N.journalAction then N.journalAction(k) end
end
local function copy(v) if type(v)~="table" then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
function N.archiveDeath()
 local a=c();local hall=N.hall;if not hall then return end;local record={name=s(GetUnitName,'player') or '?',race=s(GetUnitRace,'player'),class=s(GetUnitClass,'player'),level=s(GetUnitLevel,'player'),zone=s(GetUnitZone,'player'),seconds=a.survivalSeconds or 0,time=a.deathTime,skills={},journal=copy(a.journal),difficultySeconds=copy(a.difficultySeconds)}
 for _,k in ipairs(N.skillNames) do record.skills[k]=N.rank(k) end;hall.records[#hall.records+1]=record
end
function N.expansionPage(page)
 if page==5 then return 'RULESET INTEGRITY\n\nDeath: tracked locally; manual deletion.\nFirst person: honor-based. Difficulty selectable.\nTrading / mail / shared bank: honor-based.\nShared HC Craft Bag allowed; guild traders prohibited.\nHardcore-only groups / Champion Points: honor-based.\nNo automatic disqualification from uncertain API signals.'
 else local lines={'HALL OF THE FALLEN','Account-wide records | newest first',''};local r=N.hall and N.hall.records or {};for i=#r,math.max(1,#r-7),-1 do local v=r[i];lines[#lines+1]=string.format('%s | Lv %s | %s | %d min',v.name,tostring(v.level or '?'),v.zone or '?',math.floor(v.seconds/60)) end;if #r==0 then lines[#lines+1]='No fallen characters recorded in this version.' end;return table.concat(lines,'\n') end
end
-- Item use detection: only restore after a matching player buff appears following a food/drink stack decrease.
local candidate,lastBuff=nil,nil;local snapshots={};local lastCombat=false
local function clock() return s(GetFrameTimeSeconds) or 0 end
local function matchNutrition()
 if not candidate or not lastBuff or math.abs(candidate.at-lastBuff.at)>5 then return end
 local a=c();if not a.active or a.fallen then candidate=nil;lastBuff=nil;return end
 local amount=candidate.amount;local key=candidate.kind==ITEMTYPE_FOOD and 'food' or 'water';a[key]=math.min(100,a[key]+amount);if N.recordNutritionBuff then N.recordNutritionBuff(lastBuff.slot,lastBuff.name,lastBuff.ending) end;candidate=nil;lastBuff=nil
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
 lastBuff={at=clock(),slot=slotId,name=name,ending=endTime};matchNutrition()
end
local lastHarvest=-100;local harvestAwarded=false
local function harvestContext()
 local action,_,_,_,_,interaction=s(GetGameCameraInteractableActionInfo)
 if (INTERACTION_HARVEST and s(GetInteractionType)==INTERACTION_HARVEST) or (type(action)=='string' and action:lower():find('harvest',1,true)) or (INTERACTION_HARVEST and interaction==INTERACTION_HARVEST) then
 if clock()-lastHarvest>1 then harvestAwarded=false end;lastHarvest=clock()
 end
end
local function harvestLoot(_,receivedBy,item,qty,sound,lootType,selfLoot)
 if not N.visualActive() then return end
 if selfLoot~=true or harvestAwarded or clock()-lastHarvest>8 then return end
 if LOOT_TYPE_ITEM and lootType~=LOOT_TYPE_ITEM then return end
 harvestAwarded=true;N.award('Harvesting',30);if N.recordNode then N.recordNode(item,qty) end
end
function N.expansionTick(dt,visible,combat)
 local a=c();if not N.visualActive() then return end
 harvestContext()
 if N.progressTick then N.progressTick(dt,visible,combat) end
 lastCombat=combat
end
function N.initExpansion()
 N.hall=ZO_SavedVars:NewAccountWide('ESOHardcoreSaved',1,'Hall',{records={}})
 if BAG_BACKPACK and GetBagSize then for i=0,(s(GetBagSize,BAG_BACKPACK) or 0)-1 do pcall(slot,nil,BAG_BACKPACK,i) end end
 if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then EVENT_MANAGER:RegisterForEvent('ESOHCNutritionInventory',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(...) pcall(slot,...) end) end
 if EVENT_LOOT_RECEIVED then EVENT_MANAGER:RegisterForEvent('ESOHCHarvestLoot',EVENT_LOOT_RECEIVED,function(...) pcall(harvestLoot,...) end) end
 if EVENT_EFFECT_CHANGED then EVENT_MANAGER:RegisterForEvent('ESOHCNutritionBuff',EVENT_EFFECT_CHANGED,function(...) pcall(nutrition,...) end) end
end
