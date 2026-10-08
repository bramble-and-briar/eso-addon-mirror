local M=TGWBI
EVENT_MANAGER:RegisterForEvent(M.name,EVENT_ADD_ON_LOADED,function(_,addon)
 if addon~=M.name then return end
 EVENT_MANAGER:UnregisterForEvent(M.name,EVENT_ADD_ON_LOADED)
 M.db=ZO_SavedVars:NewAccountWide("TGWBindAndInviteSavedVariables",1,GetWorldName(),{autoBind=false,autoInvite=false,keyword="invite",groupLimit=4,messages=true})
 -- Upgrade starts in manual mode once, preserving invitation settings.
 if M.db.bindingSafetyVersion~=1 then M.db.autoBind=false;M.db.bindingSafetyVersion=1 end
 M.db.autoBind=M.db.autoBind==true
 M.newItems={};M.active=false
 SLASH_COMMANDS["/tgw"]=M.Open;SLASH_COMMANDS["/tgwbi"]=M.Open
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_ACTIVATED,function()M.active=true;M.newItems={};M.pending={};M.status="Ready. /tgw opens Bind & Invite." end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_DEACTIVATED,function()M.active=false;M.newItems={};M.CancelBind();EVENT_MANAGER:UnregisterForUpdate(M.name.."Auto")end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_CHAT_MESSAGE_CHANNEL,M.Invite)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_GROUP_MEMBER_JOINED,function(_,character,display) M.pending[M.Normalize(display)]=nil;M.pending[M.Normalize(character)]=nil end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag,slot,isNew,_,_,change)
  if bag~=BAG_BACKPACK or not isNew or not change or change<=0 or not M.active or not M.db.autoBind then return end
  local r=M.Eligible(slot);if r then M.newItems[r.uid]=true;M.RequestAuto(slot)end
 end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_COMBAT_STATE,function(_,inCombat)
  if not inCombat and M.db.autoBind then for slot=0,GetBagSize(BAG_BACKPACK)-1 do if M.newItems[M.Id(GetItemUniqueId(BAG_BACKPACK,slot))]then M.RequestAuto(slot);break end end end
 end)
end)
