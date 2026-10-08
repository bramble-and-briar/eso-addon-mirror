TGWBI = {name="TGWBindAndInvite", version="1.0.0", log={}, pending={}, recent={}, queue={}, excluded={}}
local M=TGWBI
function M.Normalize(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")):lower() end
function M.Id(id) return id and Id64ToString(id) or "" end
function M.Note(s)
 M.status=s; table.insert(M.log,1,s); if #M.log>40 then table.remove(M.log) end
 if M.db and M.db.messages then d("[TGW Bind & Invite] "..s) end
 if M.render then M.render() end
end
function M.Eligible(slot)
 local link=GetItemLink(BAG_BACKPACK,slot,LINK_STYLE_DEFAULT)
 if link=="" or IsItemPlayerLocked(BAG_BACKPACK,slot) or IsItemStolen(BAG_BACKPACK,slot) then return end
 if not IsItemLinkSetCollectionPiece(link) then return end
 local hasSet,_,_,_,_,setId=GetItemLinkSetInfo(link,false)
 if not hasSet or not setId or setId==0 then return end
 local collectionSlot=GetItemLinkItemSetCollectionSlot(link)
 if IsItemSetCollectionSlotUnlocked(setId,collectionSlot) then return end
 local tradeable=IsItemBoPAndTradeable(BAG_BACKPACK,slot)
 if IsItemBound(BAG_BACKPACK,slot) and not tradeable then return end
 local bindType=GetItemBindType(BAG_BACKPACK,slot)
 if not tradeable and bindType~=BIND_TYPE_ON_EQUIP and bindType~=BIND_TYPE_ON_PICKUP then return end
 local uid=M.Id(GetItemUniqueId(BAG_BACKPACK,slot)); if uid=="" or uid=="0" then return end
 return {slot=slot,uid=uid,link=link,key=setId..":"..M.Id(collectionSlot),setId=setId,collectionSlot=collectionSlot,quality=GetItemLinkFunctionalQuality(link),tradeable=tradeable}
end
function M.Scan(includeExcluded)
 local byPiece={}
 for slot=0,GetBagSize(BAG_BACKPACK)-1 do
  local r=M.Eligible(slot)
  if r and (includeExcluded or not M.excluded[r.uid]) then
   local old=byPiece[r.key]
   if not old or r.quality<old.quality or (r.quality==old.quality and r.slot<old.slot) then byPiece[r.key]=r end
  end
 end
 local rows={}; for _,r in pairs(byPiece) do rows[#rows+1]=r end
 table.sort(rows,function(a,b)return a.slot<b.slot end); return rows
end
function M.CancelBind()
 M.bindGeneration=(M.bindGeneration or 0)+1
 EVENT_MANAGER:UnregisterForUpdate(M.name.."Bind"); M.queue={}; M.busy=false
end
function M.SetAutoBind(enabled)
 M.autoGeneration=(M.autoGeneration or 0)+1
 M.db.autoBind=enabled==true
 M.newItems={}
 EVENT_MANAGER:UnregisterForUpdate(M.name.."Auto")
 M.CancelBind()
 M.Note(M.db.autoBind and "Automatic binding enabled for new arrivals." or "Manual mode: all queued binding cancelled.")
end
function M.StartBind(rows,automatic)
 if automatic~=true and automatic~=false then return end
 if automatic and M.db.autoBind~=true then return end
 if M.busy then return M.Note("Binding already in progress.") end
 if IsUnitInCombat("player") then return M.Note("Binding paused: leave combat and try again.") end
 local generation=M.bindGeneration or 0
 M.queue=rows; M.busy=true; local index=0; local success,skipped,failed=0,0,0; local used={};local waiting=false
 EVENT_MANAGER:RegisterForUpdate(M.name.."Bind",150,function()
  if generation~=(M.bindGeneration or 0) then return end
  if IsUnitInCombat("player") or (automatic and M.db.autoBind~=true) then M.CancelBind(); M.Note("Binding cancelled.");return end
  if waiting then return end
  index=index+1; local r=M.queue[index]
  if not r then M.CancelBind(); M.Note("Binding finished: "..success.." confirmed, "..skipped.." skipped, "..failed.." unconfirmed.");if M.db.autoBind and next(M.newItems) then M.RequestAuto() end;return end
  -- Resolve by immutable instance ID; never trust a preview's old bag slot.
  local current
  for slot=0,GetBagSize(BAG_BACKPACK)-1 do
   if M.Id(GetItemUniqueId(BAG_BACKPACK,slot))==r.uid then current=M.Eligible(slot);break end
  end
  if not current or current.key~=r.key or M.excluded[r.uid] or used[r.key] then skipped=skipped+1;return end
  used[r.key]=true
  -- Last gate immediately at the irreversible API call.
  if automatic and M.db.autoBind~=true then M.CancelBind();return end
  M.Note((automatic and "AutoBind" or "Manual bind").." request: "..current.link)
  local ok,err=pcall(BindItem,BAG_BACKPACK,current.slot)
  if not ok then failed=failed+1;M.Note("Bind error: "..tostring(err));return end
  -- Observe asynchronous confirmation for up to two seconds; never resend BindItem.
  waiting=true
  local attempts=0
  local function Confirm()
   if generation~=(M.bindGeneration or 0) then return end
   attempts=attempts+1
   local confirmed=IsItemSetCollectionSlotUnlocked(r.setId,r.collectionSlot)
   if not confirmed then
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
     if M.Id(GetItemUniqueId(BAG_BACKPACK,slot))==r.uid then
      confirmed=IsItemBound(BAG_BACKPACK,slot) and not IsItemBoPAndTradeable(BAG_BACKPACK,slot)
      break
     end
    end
   end
   if confirmed then success=success+1;waiting=false
   elseif attempts<8 then zo_callLater(Confirm,250)
   else failed=failed+1;waiting=false end
  end
  zo_callLater(Confirm,250)
 end)
 M.Note("Binding "..#rows.." selected collection pieces. Trading ends for these items.")
end
function M.RequestAuto(slot)
 if M.db.autoBind~=true or not M.active or M.busy or (slot and not M.Eligible(slot)) then return end
 EVENT_MANAGER:UnregisterForUpdate(M.name.."Auto")
 local generation=M.autoGeneration or 0
 EVENT_MANAGER:RegisterForUpdate(M.name.."Auto",500,function()
  if generation~=(M.autoGeneration or 0) then return end
  EVENT_MANAGER:UnregisterForUpdate(M.name.."Auto")
  if M.db.autoBind~=true or not M.active or M.busy or IsUnitInCombat("player") then return end
  -- Only newly received instances participate; no sweep of existing farm loot.
  local rows,byPiece={},{}
  for uid in pairs(M.newItems) do
   for s=0,GetBagSize(BAG_BACKPACK)-1 do
    if M.Id(GetItemUniqueId(BAG_BACKPACK,s))==uid then
     local r=M.Eligible(s)
     if r and not M.excluded[uid] and (not byPiece[r.key] or r.quality<byPiece[r.key].quality) then byPiece[r.key]=r end
     break
    end
   end
  end
  M.newItems={};for _,r in pairs(byPiece)do rows[#rows+1]=r end
  if #rows>0 then M.StartBind(rows,true) end
 end)
end
function M.CleanPending()
 local now=GetFrameTimeMilliseconds()
 for name,expiry in pairs(M.pending)do if expiry<=now then M.pending[name]=nil end end
 for name,time in pairs(M.recent)do if now-time>60000 then M.recent[name]=nil end end
end
function M.Invite(_,channel,from,text,isCS,displayName)
 if not M.db.autoInvite or not M.active or channel~=CHAT_CHANNEL_WHISPER or isCS then return end
 if M.Normalize(text)~=M.Normalize(M.db.keyword) or M.Normalize(M.db.keyword)=="" then return end
 local name=displayName and displayName~="" and displayName or from
 if not name or name=="" or M.Normalize(name)==M.Normalize(GetDisplayName()) then return end
 local size=GetGroupSize()
 if size>0 and not IsUnitGroupLeader("player") then M.Note("Invite skipped: you are not group leader.");return end
 M.CleanPending(); local key=M.Normalize(name); local now=GetFrameTimeMilliseconds()
 if IsPlayerInGroup(name) or M.pending[key] or (M.recent[key] and now-M.recent[key]<30000) then return end
 if IsIgnored and IsIgnored(name) then return end
 local reserved=0;for _ in pairs(M.pending)do reserved=reserved+1 end
 if math.max(1,size)+reserved>=M.db.groupLimit then M.Note("Invite skipped: group / pending invites reached "..M.db.groupLimit..".");return end
 if M.lastInvite and now-M.lastInvite<1000 then M.Note("Invite delayed by cooldown; sender can repeat keyword.");return end
 M.lastInvite=now;M.recent[key]=now;M.pending[key]=now+30000
 -- Use ESO's console-aware helper; respects platform communication checks.
 local ok,err=pcall(TryGroupInviteByName,name,true,true)
 if not ok then M.pending[key]=nil;M.Note("Invite error: "..tostring(err))
 else M.Note("Invite requested for "..name.." (pending up to 30s).") end
end
