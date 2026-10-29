local AMW=AutoMasterWrits

function AMW:ArmBanking()
    if not self.sessionActive or self.bankArmed then return end
    self.bankArmed=true
    EVENT_MANAGER:RegisterForEvent(self.name.."Bank",EVENT_OPEN_BANK,function()
        if self.bankArmed and not self:IsBusy() then self:StartBanking(false) end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."BankClose",EVENT_CLOSE_BANK,function()
        if self.bankOperation then self:StopBanking("Bank closed. Pending selections have been kept.") end
    end)
end

function AMW:StopBanking(message)
    self.bankOperation=nil
    self:CancelJob("bank")
    EVENT_MANAGER:UnregisterForEvent(self.name.."BankInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    if message then self:SetStatus(message,true) end
end

function AMW:BankTransferDelay(deposit)
    -- Match Lazy Writ's deposit and withdrawal queues, rounded by our scheduler.
    if not deposit then return 10 end
    return math.max(0,tonumber(GetLatency()) or 0)+20
end

function AMW:SendBankTransfer(operation,bag,slot,destination,target,count)
    local pending={uid=self:UniqueId(bag,slot),sourceBag=bag,sourceSlot=slot,bag=destination,slot=target}
    operation.pending=pending
    self.lastCommandAt=GetGameTimeMilliseconds()
    if destination==BAG_BACKPACK then
        return pcall(self.SecureCall,self,"RequestMoveItem",bag,slot,destination,target,count)
    end
    if GetCursorContentType()~=MOUSE_CONTENT_EMPTY then return false,"Finish the current item drag first." end
    -- Native bank placement chooses the actual personal/subscriber-bank slot.
    -- Keep pickup and placement together; never yield with our item on the cursor.
    local ok,err=pcall(function()
        self:SecureCall("PickupInventoryItem",bag,slot,count)
        if GetCursorBagId()~=bag or GetCursorSlotIndex()~=slot then error("The selected writ could not be picked up.") end
        self:SecureCall("PlaceInTransfer")
    end)
    if GetCursorBagId()==bag and GetCursorSlotIndex()==slot then ClearCursor() end
    return ok,err
end

function AMW:StartBanking(manual)
    if not self:ActivateSession() then return end
    if not IsBankOpen() then return self:SetStatus("Talk to your personal banker.",true) end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    self.bankOperation={moved=0}
    local operation=self.bankOperation
    EVENT_MANAGER:RegisterForEvent(self.name.."BankInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag,slot)
        local pending=operation.pending
        if self.bankOperation~=operation or not pending or type(slot)~="number" or slot<0 then return end
        local destination=pending.sourceBag==BAG_BACKPACK and (bag==BAG_BANK or bag==BAG_SUBSCRIBER_BANK)
            or pending.sourceBag~=BAG_BACKPACK and bag==BAG_BACKPACK
        if destination and self:UniqueId(bag,slot)==pending.uid then pending.bag,pending.slot=bag,slot end
    end)
    self:StartJob("bank",function()
        if not self:ScanWorker() then return self:StopBanking("Bank closed.") end
        local plan={}
        for uid,record in pairs(self.inventory) do
            if self.saved.withdraw[uid] and self.saved.overrides[uid] and record.bag~=BAG_BACKPACK then
                plan[#plan+1]={record=record,destination=BAG_BACKPACK}
            elseif record.bag==BAG_BACKPACK and record.deferred and (manual or self.saved.autoDeposit) then
                plan[#plan+1]={record=record,destination=BAG_BANK}
            end
            self:Yield()
        end
        for _,entry in ipairs(plan) do
            if entry.destination==BAG_BACKPACK and not operation.withdrawStarted then
                operation.withdrawStarted=true
                self:Yield(math.max(0,tonumber(GetLatency()) or 0)+50)
            end
            if self.bankOperation~=operation then return end
            if not IsBankOpen() or (GetBankingBag()~=BAG_BANK and GetBankingBag()~=BAG_SUBSCRIBER_BANK)
                or IsUnitInCombat("player") then return self:StopBanking("Transfers stopped. Personal bank must remain open.") end
            local record,destination=entry.record,entry.destination
            self:Classify(record)
            local selected=destination==BAG_BACKPACK and self.saved.overrides[record.uid]
                or destination~=BAG_BACKPACK and record.deferred
            if selected then
                local bag,slot=self:FindItem(record.uid)
                if not bag then return self:StopBanking("A writ moved. Reopen the bank to refresh the pending transfers.") end
                if IsItemPlayerLocked(bag,slot) then return self:StopBanking("A selected writ is locked. Pending transfers have been kept.") end
                if destination==BAG_BACKPACK and GetNumBagFreeSlots(BAG_BACKPACK)<=self.saved.reserveSlots then
                    return self:StopBanking("Backpack space reserve reached.")
                end
                local target=FindFirstEmptySlotInBag(destination)
                if target==nil and destination==BAG_BANK and IsESOPlusSubscriber() then
                    destination=BAG_SUBSCRIBER_BANK
                    target=FindFirstEmptySlotInBag(destination)
                end
                if target==nil then return self:StopBanking("Destination full. Pending selections have been kept.") end
                local deposit=destination~=BAG_BACKPACK
                local delay=self:BankTransferDelay(deposit)
                local sent,err=self:SendBankTransfer(operation,bag,slot,destination,target,GetSlotStackSize(bag,slot))
                if not sent then return self:StopBanking("Transfer stopped: "..tostring(err)) end
                local deadline=GetFrameTimeSeconds()+math.max(5,delay/1000+1)
                self:Yield(delay)
                repeat
                    if not IsBankOpen() then return self:StopBanking("Bank closed. Pending selections have been kept.") end
                    local pending=operation.pending
                    destination,target=pending.bag,pending.slot
                    if self:UniqueId(destination,target)==record.uid and self:UniqueId(bag,slot)~=record.uid then break end
                    if GetFrameTimeSeconds()>deadline then return self:StopBanking("Transfer not confirmed. No retry was sent.") end
                    self:Yield(10)
                until false
                operation.pending=nil
                record.bag,record.slot=destination,target
                if self.counts then
                    local category=record.crafted and "crafted" or record.deferred and "deferred" or "eligible"
                    if bag==BAG_BACKPACK and destination~=BAG_BACKPACK then
                        self.counts[category]=math.max(0,(self.counts[category] or 0)-1)
                    elseif bag~=BAG_BACKPACK and destination==BAG_BACKPACK then
                        self.counts[category]=(self.counts[category] or 0)+1
                    end
                end
                if destination==BAG_BACKPACK then self.saved.withdraw[record.uid]=nil end
                operation.moved=operation.moved+1
                self:SetStatus("Bank transfers: "..operation.moved.." confirmed.")
            end
            self:Yield()
        end
        self:StopBanking()
        self:SetStatus("Bank transfers finished: "..operation.moved.." writs moved.",true)
    end)
end

