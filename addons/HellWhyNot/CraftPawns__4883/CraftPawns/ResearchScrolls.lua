local CAM = CraftPawns
CAM.ResearchScrolls = {}
local RS = CAM.ResearchScrolls

local DAILY_COOLDOWN = 20 * 60 * 60
local SCROLLS = {
    [CRAFTING_TYPE_BLACKSMITHING] = { itemId=125473, name="Blacksmithing" },
    [CRAFTING_TYPE_CLOTHIER] = { itemId=125474, name="Clothing" },
    [CRAFTING_TYPE_WOODWORKING] = { itemId=125475, name="Woodworking" },
    [CRAFTING_TYPE_JEWELRYCRAFTING] = { itemId=138814, name="Jewelry Crafting" },
}

local function Remaining(research, snapshot, now)
    local endsAt = tonumber(research and research.endsAt)
    if endsAt then return math.max(0, endsAt-now) end
    local remaining = tonumber(research and research.remaining) or 0
    local scannedAt = tonumber(snapshot and snapshot.scannedAt) or now
    return math.max(0, remaining-math.max(0, now-scannedAt))
end

function RS:IsClaimedToday(characterId, craftType, now)
    now = tonumber(now) or GetTimeStamp()
    local claims = CAM.server and CAM.server.researchScrollClaims
    local claimedAt = claims and claims[tostring(characterId)] and tonumber(claims[tostring(characterId)][craftType])
    return claimedAt and now-claimedAt < DAILY_COOLDOWN or false
end

function RS:MarkClaimed(characterId, craftType)
    CAM.server.researchScrollClaims = CAM.server.researchScrollClaims or {}
    characterId = tostring(characterId)
    CAM.server.researchScrollClaims[characterId] = CAM.server.researchScrollClaims[characterId] or {}
    CAM.server.researchScrollClaims[characterId][craftType] = GetTimeStamp()
end

function RS:IsCraftReady(characterId, snapshot, craftType, now)
    now = tonumber(now) or GetTimeStamp()
    if self:IsClaimedToday(characterId, craftType, now) then return false end
    local research = snapshot and snapshot.research and snapshot.research[craftType]
    local activeCount = 0
    for _,line in ipairs((research and research.lines) or {}) do
        if line.currentResearch then
            local remaining = Remaining(line.currentResearch, snapshot, now)
            if remaining > 0 then
                activeCount = activeCount + 1
                if remaining <= 86400 then return false end
            end
        end
    end
    return activeCount > 0
end

function RS:FindItem(bag, itemId)
    if not bag or type(GetBagSize)~="function" then return nil end
    for slot=0,GetBagSize(bag) do
        local link=GetItemLink(bag,slot,LINK_STYLE_DEFAULT)
        if link and link~="" and GetItemLinkItemId(link)==itemId then return slot end
    end
end

function RS:FindEmptyBackpackSlot()
    for slot=0,GetBagSize(BAG_BACKPACK) do
        local link=GetItemLink(BAG_BACKPACK,slot,LINK_STYLE_DEFAULT)
        if not link or link=="" then return slot end
    end
end

function RS:PullOne(characterId, craftType, snapshot, finished)
    local scroll=SCROLLS[craftType]
    if not scroll or not self:IsCraftReady(characterId,snapshot,craftType) then finished(false); return end
    if self:FindItem(BAG_BACKPACK,scroll.itemId) then
        self:MarkClaimed(characterId,craftType); finished(true,scroll.name,false); return
    end
    local sourceBag,sourceSlot
    for _,bag in ipairs({BAG_BANK,BAG_SUBSCRIBER_BANK}) do
        local slot=self:FindItem(bag,scroll.itemId)
        if slot then sourceBag,sourceSlot=bag,slot; break end
    end
    if not sourceSlot then finished(false,nil,false,scroll.name); return end
    local destination=self:FindEmptyBackpackSlot()
    if destination==nil then finished(false,nil,false,nil,true); return end
    if type(CallSecureProtected)~="function" then finished(false,nil,false,nil,false,true); return end
    local called,result=pcall(CallSecureProtected,"RequestMoveItem",sourceBag,sourceSlot,BAG_BACKPACK,destination,1)
    if not called or result==false then finished(false,nil,false,nil,false,true); return end
    zo_callLater(function()
        if RS:FindItem(BAG_BACKPACK,scroll.itemId) then
            RS:MarkClaimed(characterId,craftType); finished(true,scroll.name,true)
        else finished(false,nil,false,nil,false,true) end
    end,400)
end

function RS:OnBankOpened()
    local characterId=tostring(GetCurrentCharacterId())
    local record=CAM.server and CAM.server.characters and CAM.server.characters[characterId]
    local snapshot=record and record.snapshot
    if not snapshot then return end
    local eligible={}
    for _,craftType in ipairs(CAM.RESEARCH_CRAFTS) do
        if self:IsCraftReady(characterId,snapshot,craftType) then eligible[#eligible+1]=craftType end
    end
    if #eligible==0 then return end
    local index,withdrawn,already,missing=1,{},{},{}
    local backpackFull,transferFailed=false,false
    local function nextCraft()
        local craftType=eligible[index]
        if not craftType then
            local parts={}
            if #withdrawn>0 then parts[#parts+1]="Withdrew: "..table.concat(withdrawn,", ") end
            if #already>0 then parts[#parts+1]="Already carried: "..table.concat(already,", ") end
            if #missing>0 then parts[#parts+1]="Not in bank: "..table.concat(missing,", ") end
            if backpackFull then parts[#parts+1]="Backpack is full" end
            if transferFailed then parts[#parts+1]="ESO blocked the bank transfer; close and reopen the bank to retry" end
            if #parts>0 then CAM:Notify(table.concat(parts,"  •  "),#withdrawn==0 and #already==0) end
            if CAM.UI then CAM.UI:RefreshResearchTimerIndicator() end
            return
        end
        self:PullOne(characterId,craftType,snapshot,function(ok,name,moved,missingName,full,blocked)
            if ok and moved then withdrawn[#withdrawn+1]=name
            elseif ok then already[#already+1]=name
            elseif missingName then missing[#missing+1]=missingName
            elseif full then backpackFull=true end
            if blocked then transferFailed=true end
            index=index+1; zo_callLater(nextCraft,200)
        end)
    end
    nextCraft()
end

function RS:Initialize()
    CAM.server.researchScrollClaims = CAM.server.researchScrollClaims or {}
    if EVENT_OPEN_BANK then EVENT_MANAGER:RegisterForEvent(CAM.name.."ResearchScrollBank",EVENT_OPEN_BANK,function() zo_callLater(function() RS:OnBankOpened() end,500) end) end
end
