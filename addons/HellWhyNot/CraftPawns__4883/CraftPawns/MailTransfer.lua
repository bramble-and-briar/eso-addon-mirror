local CAM = CraftPawns
CAM.MailTransfer = {}
local MT = CAM.MailTransfer

local function Lookup(...)
    local result={}
    for index=1,select("#",...) do local value=select(index,...); if value~=nil then result[value]=true end end
    return result
end

local WRIT_TRAITS = Lookup(
    ITEM_TRAIT_TYPE_ARMOR_INTRICATE,ITEM_TRAIT_TYPE_ARMOR_ORNATE,
    ITEM_TRAIT_TYPE_WEAPON_INTRICATE,ITEM_TRAIT_TYPE_WEAPON_ORNATE,
    ITEM_TRAIT_TYPE_JEWELRY_INTRICATE,ITEM_TRAIT_TYPE_JEWELRY_ORNATE)

local GLYPH_TYPES = Lookup(ITEMTYPE_GLYPH_ARMOR,ITEMTYPE_GLYPH_WEAPON,ITEMTYPE_GLYPH_JEWELRY)

function MT:IsWritLoot(bag, slot)
    local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    if not link or link == "" then return false end
    if type(IsItemBound) == "function" and IsItemBound(bag, slot) then return false end
    if type(IsItemPlayerLocked) == "function" and IsItemPlayerLocked(bag, slot) then return false end
    if type(IsItemStolen) == "function" and IsItemStolen(bag, slot) then return false end
    local itemType = select(1, GetItemLinkItemType(link))
    if GLYPH_TYPES[itemType] then
        return GetItemLinkFunctionalQuality(link) == ITEM_FUNCTIONAL_QUALITY_MAGIC
    end
    return WRIT_TRAITS[select(1, GetItemLinkTraitInfo(link))] == true
end

function MT:GetWritLootSlots()
    local result = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) do
        if self:IsWritLoot(BAG_BACKPACK, slot) then result[#result + 1] = slot end
    end
    return result
end

function MT:QueueWritMail(targetId)
    local record = CAM.server and CAM.server.characters and CAM.server.characters[targetId]
    local currentAccount = GetDisplayName and GetDisplayName() or ""
    if not record or not record.account then CAM:Notify("The selected character has no saved account identity.",true); return false end
    if record.account == currentAccount then CAM:Notify("Select a character on another account for writ mail.",true); return false end
    local slots = self:GetWritLootSlots()
    if #slots == 0 then CAM:Notify("No intricate or ornate gear or green glyphs were found in the backpack.",true); return false end
    CAM.server.writMailQueue = { account=record.account, character=record.currentName, queuedAt=GetTimeStamp() }
    self:RefreshWritKeybind()
    return self:AttachWritLoot()
end

function MT:AttachWritLoot()
    local queue = CAM.server and CAM.server.writMailQueue
    if not queue or not queue.account then CAM:Notify("Choose Mail Decon Rewards for a character on another account first.",true); return false end
    if self.pending then CAM:Notify("Finish or cancel the prepared research-item mail first.",true); return false end
    if self:HasQueuedAttachments() then CAM:Notify("Send or clear the current attachments first.",true); return false end
    local slots = self:GetWritLootSlots()
    if #slots == 0 then CAM.server.writMailQueue=nil; self:RefreshWritKeybind(); CAM:Notify("No queued writ loot remains in the backpack."); return false end
    if type(MAIL_SEND) ~= "table" or type(MAIL_SEND.ComposeMailTo) ~= "function" then CAM:Notify("ESO's mail composer is unavailable.",true); return false end
    MAIL_SEND:ComposeMailTo(queue.account)
    if type(MAIL_SEND.SetReply) == "function" then MAIL_SEND:SetReply(queue.account,"Crafting rewards","Intricate and ornate gear and green glyphs.") end
    zo_callLater(function()
        local attached = 0
        local maximum = math.min(#slots, tonumber(MAIL_MAX_ATTACHED_ITEMS) or 6)
        for index = 1, maximum do
            local slot = slots[index]
            if type(CanQueueItemAttachment) ~= "function" or CanQueueItemAttachment(BAG_BACKPACK,slot,index) then
                QueueItemAttachment(BAG_BACKPACK,slot,index)
                local bag,queuedSlot,_,stack = GetQueuedItemAttachmentInfo(index)
                if bag == BAG_BACKPACK and queuedSlot == slot and (tonumber(stack) or 0) > 0 then attached=attached+1 end
            end
        end
        if attached==0 then CAM:Notify("ESO would not attach the queued writ loot.",true); return end
        MT.writPending={ count=attached, account=queue.account, more=#slots>attached }
        CAM:Notify(string.format("Attached %d writ reward%s for %s. Review and press Send%s",attached,attached==1 and "" or "s",queue.account,#slots>attached and "; more remain." or "."))
    end,250)
    return true
end

function MT:AddWritKeybind()
    if self.writKeybindVisible or not (CAM.server and CAM.server.writMailQueue) or type(KEYBIND_STRIP)~="table" then return end
    self.writKeybind={alignment=KEYBIND_STRIP_ALIGN_LEFT,{
        name="Attach Decon Rewards", keybind="CRAFTPAWNS_ATTACH_WRIT_MAIL", order=2460,
        callback=function() MT:AttachWritLoot() end,
    }}
    KEYBIND_STRIP:AddKeybindButtonGroup(self.writKeybind)
    self.writKeybindVisible=true
end

function MT:RemoveWritKeybind()
    if not self.writKeybindVisible or type(KEYBIND_STRIP)~="table" then return end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.writKeybind)
    self.writKeybindVisible=false
end

function MT:RefreshWritKeybind()
    self:RemoveWritKeybind()
    local scene = type(SCENE_MANAGER)=="table" and SCENE_MANAGER:GetCurrentScene()
    if scene and type(scene.GetName)=="function" and scene:GetName()=="mailSend" then self:AddWritKeybind() end
end

function MT:IsSafeMatch(entry, bag, slot)
    if not entry or not entry.item or (entry.status ~= "crafted" and entry.status ~= "mailed") then return false end
    local item = entry.item
    local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    if not link or link == "" then return false end
    if type(IsItemLinkCrafted) ~= "function" or not IsItemLinkCrafted(link) then return false end
    if (GetItemLinkRequiredLevel(link) or 0) > 1 or (GetItemLinkRequiredChampionPoints(link) or 0) > 0 then return false end
    if GetItemLinkFunctionalQuality(link) ~= ITEM_FUNCTIONAL_QUALITY_NORMAL then return false end
    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
    if hasSet or (tonumber(setId) or 0) ~= 0 then return false end
    if type(IsItemPlayerLocked) == "function" and IsItemPlayerLocked(bag, slot) then return false end
    if type(IsItemBound) == "function" and IsItemBound(bag, slot) then return false end
    if select(1, GetItemLinkTraitInfo(link)) ~= item.traitType then return false end
    local qualifications = entry.qualifications
    if type(qualifications) ~= "table" then return false end
    local itemType, specializedItemType = GetItemLinkItemType(link)
    return itemType == qualifications.itemType
        and specializedItemType == qualifications.specializedItemType
        and GetItemLinkEquipType(link) == qualifications.equipType
        and GetItemLinkWeaponType(link) == qualifications.weaponType
        and GetItemLinkArmorType(link) == qualifications.armorType
end

function MT:FindAccessibleMatch(entry)
    local bags = { BAG_BACKPACK, BAG_BANK }
    if BAG_SUBSCRIBER_BANK then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    for _, bag in ipairs(bags) do
        for slot = 0, GetBagSize(bag) do
            if self:IsSafeMatch(entry, bag, slot) then return bag, slot end
        end
    end
end

function MT:GetEligibleEntries(targetId)
    local record = CAM.server and CAM.server.characters and CAM.server.characters[targetId]
    local currentAccount = GetDisplayName and GetDisplayName() or ""
    if not record or not record.account or record.account == currentAccount then return {}, record end
    local entries = {}
    for reference, entry in pairs((CAM.server.prepared and CAM.server.prepared[targetId]) or {}) do
        if entry.status == "crafted" and entry.item then entries[#entries + 1] = { reference=reference, entry=entry } end
    end
    table.sort(entries, function(a, b)
        local aq, bq = tonumber(a.entry.queuedAt) or 0, tonumber(b.entry.queuedAt) or 0
        if aq == bq then return tostring(a.reference) < tostring(b.reference) end
        return aq < bq
    end)
    return entries, record
end

function MT:FindBatch(targetId)
    local entries, record = self:GetEligibleEntries(targetId)
    local batch, used = {}, {}
    local maximum = tonumber(MAIL_MAX_ATTACHED_ITEMS) or 6
    for _, candidate in ipairs(entries) do
        for slot = 0, GetBagSize(BAG_BACKPACK) do
            if not used[slot] and self:IsSafeMatch(candidate.entry, BAG_BACKPACK, slot) then
                used[slot] = true
                batch[#batch + 1] = { reference=candidate.reference, entry=candidate.entry, bag=BAG_BACKPACK, slot=slot }
                break
            end
        end
        if #batch >= maximum then break end
    end
    return batch, record, #entries
end

function MT:HasQueuedAttachments()
    if type(GetQueuedItemAttachmentInfo) ~= "function" then return false end
    for index = 1, (tonumber(MAIL_MAX_ATTACHED_ITEMS) or 6) do
        local _, _, _, stack = GetQueuedItemAttachmentInfo(index)
        if (tonumber(stack) or 0) > 0 then return true end
    end
    return false
end

function MT:Prepare(targetId)
    if self.pending and not self:HasQueuedAttachments() then self.pending = nil end
    if self.pending then CAM:Notify("Finish or cancel the currently prepared CraftPawns mail first.",true); return false end
    if self.writPending then CAM:Notify("Finish or cancel the currently prepared writ-loot mail first.",true); return false end
    if type(MAIL_SEND) ~= "table" or type(MAIL_SEND.ComposeMailTo) ~= "function" then CAM:Notify("ESO's mail composer is unavailable.",true); return false end
    if self:HasQueuedAttachments() then CAM:Notify("Your current mail draft already has attachments. Send or clear it first.",true); return false end
    local batch, record, waiting = self:FindBatch(targetId)
    if not record or not record.account then CAM:Notify("The selected character has no saved account identity. Rescan it first.",true); return false end
    if record.account == GetDisplayName() then CAM:Notify("This character is on the current account; use the bank instead of mail.",true); return false end
    if #batch == 0 then
        CAM:Notify(waiting > 0 and "No matching prepared items were found in this character's backpack." or "No newly crafted research items are waiting for this account.",true)
        return false
    end
    MAIL_SEND:ComposeMailTo(record.account)
        if type(MAIL_SEND.SetReply) == "function" then MAIL_SEND:SetReply(record.account,"CraftPawns research gear","Prepared research items for "..tostring(record.currentName or "your alt")..".") end
    zo_callLater(function()
        local attached = {}
        for index, item in ipairs(batch) do
            if type(CanQueueItemAttachment) == "function" and CanQueueItemAttachment(item.bag, item.slot, index) then
                QueueItemAttachment(item.bag, item.slot, index)
                local bag, slot, _, stack = GetQueuedItemAttachmentInfo(index)
                if bag == item.bag and slot == item.slot and (tonumber(stack) or 0) > 0 then attached[#attached + 1] = item end
            end
        end
        if #attached == 0 then CAM:Notify("ESO would not attach any matching items. They must be unlocked and in the backpack.",true); return end
        MT.pending = { targetId=targetId, account=record.account, character=record.currentName, items=attached }
        local remaining=waiting-#attached
        CAM:Notify(string.format("Prepared %d item%s for %s%s",#attached,#attached==1 and "" or "s",record.account,remaining>0 and string.format("; %d remain.",remaining) or "."))
    end, 250)
    return true
end

function MT:OnSendSuccess()
    local pending = self.pending
    if pending then
        local now = GetTimeStamp()
        for _, item in ipairs(pending.items) do
            item.entry.status = "mailed"; item.entry.mailedAt = now; item.entry.mailedTo = pending.account; item.entry.updatedAt = now
        end
        CAM:Notify(string.format("Sent %d prepared research item%s to %s.",#pending.items,#pending.items==1 and "" or "s",pending.account))
        self.pending = nil
        if CAM.UI then CAM.UI:Refresh() end
        return
    end
    if self.writPending then
        local sent=self.writPending
        CAM:Notify(string.format("Sent %d decon reward%s to %s%s",sent.count,sent.count==1 and "" or "s",sent.account,sent.more and ". Use Attach Decon Rewards for the next batch." or "."))
        self.writPending=nil
        if not sent.more then CAM.server.writMailQueue=nil; self:RefreshWritKeybind() end
    end
end

function MT:OnSendFailed(reason)
    if not self.pending and not self.writPending then return end
    CAM:Notify("Mail was not sent; prepared-item records were left unchanged.",true)
    self.pending = nil
    self.writPending = nil
end

function MT:Initialize()
    if EVENT_MAIL_SEND_SUCCESS then EVENT_MANAGER:RegisterForEvent(CAM.name.."MailSuccess",EVENT_MAIL_SEND_SUCCESS,function() MT:OnSendSuccess() end) end
    if EVENT_MAIL_SEND_FAILED then EVENT_MANAGER:RegisterForEvent(CAM.name.."MailFailed",EVENT_MAIL_SEND_FAILED,function(_,reason) MT:OnSendFailed(reason) end) end
    local scene = type(SCENE_MANAGER)=="table" and SCENE_MANAGER:GetScene("mailSend")
    if scene and type(scene.RegisterCallback)=="function" then
        scene:RegisterCallback("StateChange",function(_,newState)
            if newState==SCENE_SHOWING or newState==SCENE_SHOWN then MT:AddWritKeybind()
            elseif newState==SCENE_HIDING or newState==SCENE_HIDDEN then MT:RemoveWritKeybind() end
        end)
    end
end
