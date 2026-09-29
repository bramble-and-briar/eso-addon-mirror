local AlabuzyaUI = AlabuzyaUI
-- Sell only explicitly marked junk during an ordinary merchant session.
AlabuzyaUI.Junk={}
local M=AlabuzyaUI.Junk
local active,pending,total=false,nil,0
local started,readyAt=0,0
local function Enabled() return not AlabuzyaUI.Settings or AlabuzyaUI.Settings.Enabled('junk') end
function M.Eligible(slot)
    if not IsItemJunk(BAG_BACKPACK,slot) or IsItemPlayerLocked(BAG_BACKPACK,slot) or IsItemStolen(BAG_BACKPACK,slot) then return false end
    local _,count,price,_,locked=GetItemInfo(BAG_BACKPACK,slot)
    return (count or 0)>0 and (price or 0)>0 and not locked
end
local function Message(ru,en)
    CHAT_SYSTEM:AddMessage('Alabuzya UI: '..(GetCVar('language.2')=='ru' and ru or en))
end
function M.Stop()
    active=false pending=nil
    EVENT_MANAGER:UnregisterForUpdate('AlabuzyaUIJunk')
    if total>0 then Message('Продано предметов мусора: '..total, 'Junk items sold: '..total) end
    total=0
end
function M.Tick()
    if not active then return end
    if not Enabled() then M.Stop() return end
    local now=GetFrameTimeSeconds()
    -- OPEN_STORE may arrive before the interaction/UI has switched to vendor.
    -- Wait briefly for readiness, but never sell to a fence or outside the session.
    if GetInteractionType()~=INTERACTION_VENDOR then
        if readyAt>0 or now-started>=3 then M.Stop() end
        return
    end
    if readyAt==0 then readyAt=now+0.5 end
    if now<readyAt then return end
    if pending then
        local _,count=GetItemInfo(BAG_BACKPACK,pending.slot)
        if GetItemLink(BAG_BACKPACK,pending.slot)~=pending.link then count=0 end
        count=count or 0
        if count<pending.count then total=total+pending.count-count pending=nil
        elseif now-pending.time>=3 then
            Message('Торговец не подтвердил продажу мусора. Автопродажа остановлена до следующего открытия магазина.',
                'Merchant did not confirm the junk sale. Stopped until the store is reopened.')
            M.Stop() return
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
    -- Inventory locks can still be settling immediately after opening a store.
    if total>0 or now-started>=3 then M.Stop() end
end
function M.Start()
    if active or not Enabled() then return end
    active=true total=0 pending=nil started=GetFrameTimeSeconds() readyAt=0
    if GetInteractionType()==INTERACTION_VENDOR then readyAt=started+0.5 end
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIJunk',250,M.Tick)
end
function AlabuzyaUI.Junk.Initialize()
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIJunk',EVENT_OPEN_STORE,M.Start)
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIJunk',EVENT_CLOSE_STORE,M.Stop)
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIJunk',EVENT_PLAYER_DEACTIVATED,M.Stop)
end
