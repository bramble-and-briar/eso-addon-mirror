local AlabuzyaUI = AlabuzyaUI
-- Original AlabuzyaUI equipment maintenance. GPL-3.0-or-later.
AlabuzyaUI.Maintenance = {}
local M=AlabuzyaUI.Maintenance
local pending, retryAfter
local function Config(kind)
    return AlabuzyaUI.Settings and AlabuzyaUI.Settings.Maintenance(kind) or {enabled=true, threshold=10, crown=true}
end
local function Value(kind,slot)
    if kind=="repair" then return GetItemCondition(BAG_WORN,slot) end
    return GetChargeInfoForItem(BAG_WORN,slot)
end
local function Count(slot)
    local _,count=GetItemInfo(BAG_BACKPACK,slot)
    return count or 0
end
function M.Cheaper(a,b)
    if a.crown~=b.crown then return not a.crown end
    if a.price~=b.price then return a.price<b.price end
    if a.tier~=b.tier then return a.tier<b.tier end
    return a.slot<b.slot
end
function M.FindMaterial(kind,target)
    local best
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        if Count(slot)>0 and not IsItemPlayerLocked(BAG_BACKPACK,slot) then
            local valid,crown,tier,amount=false,false,0,0
            if kind=="repair" and IsItemRepairKit(BAG_BACKPACK,slot) and IsItemNonGroupRepairKit(BAG_BACKPACK,slot) then
                crown=not IsItemNonCrownRepairKit(BAG_BACKPACK,slot)
                tier=GetRepairKitTier(BAG_BACKPACK,slot)
                amount=GetAmountRepairKitWouldRepairItem(BAG_WORN,target,BAG_BACKPACK,slot)
                valid=not crown or IsItemUsable(BAG_BACKPACK,slot)
            elseif kind=="charge" and IsItemSoulGem(SOUL_GEM_TYPE_FILLED,BAG_BACKPACK,slot) then
                tier=GetSoulGemItemInfo(BAG_BACKPACK,slot)
                crown=tier==0 or IsItemFromCrownStore(BAG_BACKPACK,slot) or IsItemFromCrownCrate(BAG_BACKPACK,slot)
                amount=GetAmountSoulGemWouldChargeItem(BAG_WORN,target,BAG_BACKPACK,slot)
                valid=true
            end
            if valid and amount>0 and (not crown or Config(kind).crown) then
                local _,_,price=GetItemInfo(BAG_BACKPACK,slot)
                local candidate={slot=slot,crown=crown,tier=tier,price=price or 0}
                if not best or M.Cheaper(candidate,best) then best=candidate end
            end
        end
    end
    return best
end
function M.Tick()
    local now=GetFrameTimeSeconds()
    if IsUnitDeadOrReincarnating("player") then return end
    if pending then
        if GetItemLink(BAG_WORN,pending.target)~=pending.link then
            pending=nil
        elseif Value(pending.kind,pending.target)>pending.before then
            local ru=GetCVar("language.2")=="ru"
            local action=pending.kind=="repair" and (ru and "Починено" or "Repaired") or (ru and "Заряжено" or "Recharged")
            CHAT_SYSTEM:AddMessage("|c8FCC9AAlabuzyaUI|r: "..action..": "..pending.link)
            pending=nil
        elseif now-pending.time<5 then return
        else
            pending=nil retryAfter=now+30
            return
        end
    end
    if retryAfter and now<retryAfter then return end
    for target=0,GetBagSize(BAG_WORN)-1 do
        local link=GetItemLink(BAG_WORN,target)
        if link~="" then
            local kind
            if Config("repair").enabled and DoesItemHaveDurability(BAG_WORN,target) and GetItemCondition(BAG_WORN,target)<=Config("repair").threshold then
                kind="repair"
            elseif Config("charge").enabled and IsItemChargeable(BAG_WORN,target) then
                local charge,maximum=GetChargeInfoForItem(BAG_WORN,target)
                if maximum>0 and charge/maximum<=Config("charge").threshold/100 then kind="charge" end
            end
            local material=kind and M.FindMaterial(kind,target)
            if material then
                pending={kind=kind,target=target,link=link,before=Value(kind,target),
                    material=material.slot,materialLink=GetItemLink(BAG_BACKPACK,material.slot),
                    count=Count(material.slot),time=now}
                if kind=="charge" then
                    ChargeItemWithSoulGem(BAG_WORN,target,BAG_BACKPACK,material.slot)
                elseif material.crown then
                    if IsProtectedFunction("UseItem") then
                        CallSecureProtected("UseItem",BAG_BACKPACK,material.slot)
                    else UseItem(BAG_BACKPACK,material.slot) end
                else
                    RepairItemWithRepairKit(BAG_WORN,target,BAG_BACKPACK,material.slot)
                end
                return -- one request at a time; re-read actual inventory next tick
            end
        end
    end
end
function AlabuzyaUI.Maintenance.Initialize()
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIMaintenance",EVENT_PLAYER_ACTIVATED,function()
        EVENT_MANAGER:RegisterForUpdate("AlabuzyaUIMaintenance",2000,M.Tick)
    end)
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIMaintenance",EVENT_PLAYER_DEACTIVATED,function()
        EVENT_MANAGER:UnregisterForUpdate("AlabuzyaUIMaintenance")
    end)
end
