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
    if message then self:SetStatus(message,true) end
end

function AMW:StartBanking(manual)
    if not self:ActivateSession() then return end
    if not IsBankOpen() then return self:SetStatus("Talk to your personal banker.",true) end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    self.bankOperation={moved=0}
    local operation=self.bankOperation
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
            self:WaitForGameCommand()
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
                local sent,err=self:SendGameCommand("RequestMoveItem",bag,slot,destination,target,GetSlotStackSize(bag,slot))
                if not sent then return self:StopBanking("Transfer stopped: "..tostring(err)) end
                local deadline=GetFrameTimeSeconds()+5
                repeat
                    self:Yield(100)
                    if not IsBankOpen() then return self:StopBanking("Bank closed. Pending selections have been kept.") end
                    if self:UniqueId(destination,target)==record.uid and self:UniqueId(bag,slot)~=record.uid then break end
                    if GetFrameTimeSeconds()>deadline then return self:StopBanking("Transfer not confirmed. No retry was sent.") end
                until false
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
        self.bankOperation=nil
        self:SetStatus("Bank transfers finished: "..operation.moved.." writs moved.",true)
    end)
end

