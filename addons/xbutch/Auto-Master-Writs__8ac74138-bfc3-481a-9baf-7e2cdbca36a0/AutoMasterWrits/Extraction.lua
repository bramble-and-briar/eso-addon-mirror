local AMW=AutoMasterWrits
AMW.unopenedIds={[217917]=true,[217918]=true,[217919]=true,[217920]=true,[217921]=true,[217923]=true}

function AMW:StopExtraction(message)
    self.extracting=nil
    self:CancelJob("extract")
    if message then self:SetStatus(message,true) end
end

function AMW:StartExtraction()
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    if not self:CanUseInventory() then return self:Alert("Close the bank, loot or crafting interaction first.") end
    local operation={opened=0,limit=self.saved.extractLimit}
    self.extracting=operation
    self:ArmBanking()
    self:StartJob("extract",function()
        local stacks={}
        for slot=0,GetBagSize(BAG_BACKPACK)-1 do
            if self.unopenedIds[GetItemId(BAG_BACKPACK,slot)] and not IsItemPlayerLocked(BAG_BACKPACK,slot) then
                stacks[#stacks+1]={slot=slot,uid=self:UniqueId(BAG_BACKPACK,slot)}
            end
            self:Yield()
        end
        for _,stack in ipairs(stacks) do
            while self:UniqueId(BAG_BACKPACK,stack.slot)==stack.uid and operation.opened<operation.limit do
                if self.extracting~=operation then return end
                if not self:CanUseInventory() then return self:StopExtraction("Opening stopped by the current interaction.") end
                if GetNumBagFreeSlots(BAG_BACKPACK)<=self.saved.reserveSlots then
                    return self:StopExtraction("Backpack space reserve reached.")
                end
                local amount=GetSlotStackSize(BAG_BACKPACK,stack.slot)
                local id=GetItemId(BAG_BACKPACK,stack.slot)
                if not self.unopenedIds[id] then return self:StopExtraction("The unopened stack changed.") end
                self:SecureCall("UseItem",BAG_BACKPACK,stack.slot)
                local deadline=GetFrameTimeSeconds()+8
                repeat
                    self:Yield(100)
                    local uid=self:UniqueId(BAG_BACKPACK,stack.slot)
                    local current=uid==stack.uid and GetSlotStackSize(BAG_BACKPACK,stack.slot) or 0
                    if uid and uid~=stack.uid then return self:StopExtraction("The unopened stack moved. No further item was used.") end
                    if current<amount then
                        if amount-current~=1 then return self:StopExtraction("Another operation changed the stack. Stop the other extractor.") end
                        operation.opened=operation.opened+1
                        break
                    end
                    if GetFrameTimeSeconds()>deadline then return self:StopExtraction("Opening was not confirmed. No retry was sent.") end
                until false
                self:SetStatus("Opened "..operation.opened.." writs.")
                self:Yield(750)
            end
            self:Yield()
        end
        self.extracting=nil
        -- One bounded classification pass after the batch, never after every item.
        if self:ScanWorker() then self:ArmBanking() end
        self:SetStatus("Opening finished: "..operation.opened.." writs.",true)
    end)
end

