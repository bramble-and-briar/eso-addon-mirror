local CAM = CraftPawns
CAM.AutoResearch = {}
local AR = CAM.AutoResearch

function AR:MatchesQualifications(entry,bag,slot)
    if not entry or not entry.item then return false end
    local item=entry.item
    return type(CanItemBeSmithingTraitResearched)=="function"
        and CanItemBeSmithingTraitResearched(bag,slot,item.craftType,item.lineIndex,item.traitIndex)==true
end

function AR:FindQualifyingItem(entry,station)
    if not entry or not entry.item then return nil end
    local bags={BAG_BACKPACK,BAG_BANK}
    if BAG_SUBSCRIBER_BANK then bags[#bags+1]=BAG_SUBSCRIBER_BANK end
    if type(GetBagSize)=="function" then
        for _,bag in ipairs(bags) do
            for slot=0,GetBagSize(bag) do
                if self:MatchesQualifications(entry,bag,slot) and self:IsSafe(entry,bag,slot,station) then return bag,slot end
            end
        end
    end
end

function AR:IsSafe(entry,bag,slot,station)
    if not entry or (entry.status~="crafted" and entry.status~="mailed") or not entry.item or entry.item.craftType~=station then return false end
    if not self:MatchesQualifications(entry,bag,slot) then return false end
    local link=GetItemLink(bag,slot,LINK_STYLE_DEFAULT)
    if not link or link=="" then return false end
    if type(IsItemLinkCrafted)~="function" or not IsItemLinkCrafted(link) then return false end
    if (GetItemLinkRequiredLevel(link) or 0)>1 or (GetItemLinkRequiredChampionPoints(link) or 0)>0 then return false end
    if GetItemLinkFunctionalQuality(link)~=ITEM_FUNCTIONAL_QUALITY_NORMAL then return false end
    local hasSet,_,_,_,_,setId=GetItemLinkSetInfo(link,false)
    if hasSet or (tonumber(setId) or 0)~=0 then return false end
    if type(IsItemPlayerLocked)=="function" and IsItemPlayerLocked(bag,slot) then return false end
    local traitType=select(1,GetItemLinkTraitInfo(link))
    if traitType~=entry.item.traitType then return false end
    return self:MatchesQualifications(entry,bag,slot)
end

function AR:ProcessNext(manual)
    if self.pending then
        if manual then CAM:Notify("Waiting for ESO to confirm the previous research request.") end
        return false
    end
    local station=GetCraftingInteractionType()
    if station~=CRAFTING_TYPE_BLACKSMITHING and station~=CRAFTING_TYPE_CLOTHIER and station~=CRAFTING_TYPE_WOODWORKING and station~=CRAFTING_TYPE_JEWELRYCRAFTING then
        if manual then CAM:Notify("Open a research-capable crafting station first.",true) end
        return false
    end
    local targetId=tostring(GetCurrentCharacterId())
    local prepared=CAM.server and CAM.server.prepared and CAM.server.prepared[targetId]
    if not prepared then
        if manual then CAM:Notify("This character has no prepared research requests.",true) end
        return false
    end
    local hasPrepared=false
    for _,entry in pairs(prepared) do
        if (entry.status=="crafted" or entry.status=="mailed") and entry.item and entry.item.craftType==station then hasPrepared=true end
        local bag,slot=self:FindQualifyingItem(entry,station)
        if bag then
            entry.status="researching"
            entry.researchRequestedAt=GetTimeStamp()
            self.pendingSerial=(self.pendingSerial or 0)+1
            local serial=self.pendingSerial
            self.pending={entry=entry,craftType=entry.item.craftType,lineIndex=entry.item.lineIndex,traitIndex=entry.item.traitIndex,serial=serial}
            CAM:Notify(string.format("Auto-researching %s — %s.",entry.item.lineName or "item",CAM:GetTraitName(entry.item.traitType)))
            ResearchSmithingTrait(bag,slot)
            zo_callLater(function()
                if AR.pending and AR.pending.serial==serial then
                    entry.status="crafted"
                    entry.researchRequestedAt=nil
                    AR.pending=nil
                    CAM:Notify("ESO did not confirm research; the item remains available to retry.",true)
                end
            end,3000)
            return true
        end
    end
    if manual then
        if hasPrepared then
            CAM:Notify("No matching prepared item or open research slot was found.",true)
        else
            CAM:Notify("No prepared research requests are waiting at this station.")
        end
    end
    return false
end

function AR:OnResearchStarted(craftType,lineIndex,traitIndex)
    local pending=self.pending
    if not pending then return end
    if pending.craftType~=craftType or pending.lineIndex~=lineIndex or pending.traitIndex~=traitIndex then return end
    pending.entry.status="researchStarted"
    pending.entry.researchStartedAt=GetTimeStamp()
    self.pending=nil
    zo_callLater(function() AR:ProcessNext() end,650)
end

function AR:AddStationKeybind()
    if self.stationKeybindVisible or type(KEYBIND_STRIP)~="table" then return end
    local station=GetCraftingInteractionType()
    if station~=CRAFTING_TYPE_BLACKSMITHING and station~=CRAFTING_TYPE_CLOTHIER and station~=CRAFTING_TYPE_WOODWORKING and station~=CRAFTING_TYPE_JEWELRYCRAFTING then return end
    self.stationKeybind={alignment=KEYBIND_STRIP_ALIGN_LEFT,{
        name="Auto Research",
        keybind="CRAFTPAWNS_AUTO_RESEARCH",
        order=2450,
        callback=function() AR:ProcessNext(true) end,
    }}
    KEYBIND_STRIP:AddKeybindButtonGroup(self.stationKeybind)
    self.stationKeybindVisible=true
end

function AR:RemoveStationKeybind()
    if not self.stationKeybindVisible or type(KEYBIND_STRIP)~="table" then return end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.stationKeybind)
    self.stationKeybindVisible=false
end

function AR:Initialize()
    local currentId=tostring(GetCurrentCharacterId())
    local prepared=CAM.server and CAM.server.prepared and CAM.server.prepared[currentId]
    for _,entry in pairs(prepared or {}) do
        if entry.status=="researching" or entry.status=="researchStarted" then entry.status="crafted" end
    end
    EVENT_MANAGER:RegisterForEvent(CAM.name.."AutoResearch",EVENT_CRAFTING_STATION_INTERACT,function()
        zo_callLater(function() AR:AddStationKeybind(); AR:ProcessNext() end,500)
    end)
    EVENT_MANAGER:RegisterForEvent(CAM.name.."AutoResearchEnd",EVENT_END_CRAFTING_STATION_INTERACT,function() AR:RemoveStationKeybind() end)
    EVENT_MANAGER:RegisterForEvent(CAM.name.."AutoResearchStarted",EVENT_SMITHING_TRAIT_RESEARCH_STARTED,function(_,craftType,lineIndex,traitIndex)
        AR:OnResearchStarted(craftType,lineIndex,traitIndex)
    end)
end
