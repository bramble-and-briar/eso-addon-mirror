local DIAhelp = DIAhelp
-- Sell only explicitly marked junk to ordinary merchants. Original code.
DIAhelp.Junk={}
local M=DIAhelp.Junk
local active,pending,total=false,nil,0
local started=0
function M.Eligible(slot)
    if not IsItemJunk(BAG_BACKPACK,slot) or IsItemPlayerLocked(BAG_BACKPACK,slot) or IsItemStolen(BAG_BACKPACK,slot) then return false end
    local _,count,price,_,locked=GetItemInfo(BAG_BACKPACK,slot)
    return count>0 and price>0 and not locked
end
local function Stop()
    active=false pending=nil
    EVENT_MANAGER:UnregisterForUpdate('DIAhelpJunk')
    if total>0 then
        local message=GetCVar('language.2')=='ru' and 'Продано предметов мусора: ' or 'Junk items sold: '
        CHAT_SYSTEM:AddMessage('DIAhelp: '..message..total)
    end
    total=0
end
function M.Tick()
    if not active then return end
    if GetInteractionType()~=INTERACTION_VENDOR then Stop() return end
    local now=GetFrameTimeSeconds()
    if now<started then return end
    if pending then
        local _,count=GetItemInfo(BAG_BACKPACK,pending.slot)
        if GetItemLink(BAG_BACKPACK,pending.slot)~=pending.link then count=0 end
        if count<pending.count then total=total+pending.count-count pending=nil
        elseif now-pending.time>=3 then Stop() return
        else return end
    end
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        if M.Eligible(slot) then
            local _,count=GetItemInfo(BAG_BACKPACK,slot)
            pending={slot=slot,count=count,link=GetItemLink(BAG_BACKPACK,slot),time=now}
            SellInventoryItem(BAG_BACKPACK,slot,count)
            return
        end
    end
    Stop()
end
function M.Start()
    if active then return end
    if GetInteractionType()~=INTERACTION_VENDOR then return end
    active=true total=0 pending=nil started=GetFrameTimeSeconds()+0.5
    EVENT_MANAGER:RegisterForUpdate('DIAhelpJunk',250,M.Tick)
end
function DIAhelp.Junk.Initialize()
    EVENT_MANAGER:RegisterForEvent('DIAhelpJunk',EVENT_OPEN_STORE,M.Start)
    EVENT_MANAGER:RegisterForEvent('DIAhelpJunk',EVENT_CLOSE_STORE,Stop)
end
