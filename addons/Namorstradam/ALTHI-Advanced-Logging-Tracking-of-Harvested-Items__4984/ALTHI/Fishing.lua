local A = ALTHarvestItems
local function L(key) return A:T(key) end
local function fresh() return { counts={}, catches={}, oldFish={}, outputs={}, caught=0, white=0, special=0, bycatch=0, elapsed=0, baitUsed=0, filleted=0, roe=0, sinceRoe=0 } end
function A:FishingState()
    self.db.session.fishing=self.db.session.fishing or fresh()
    self.db.fishingTotals=self.db.fishingTotals or fresh()
    self.db.fishingKnown=self.db.fishingKnown or {}
    for _,stats in ipairs({self.db.session.fishing,self.db.fishingTotals}) do
        for key,value in pairs(fresh()) do if stats[key]==nil then stats[key]=self.Copy(value) end end
    end
    if self.db.options.autoBait==nil then self.db.options.autoBait=true end
    return self.db.session.fishing,self.db.fishingTotals
end
local oldMigrate=A.Migrate
function A:Migrate() oldMigrate(self); self:FishingState() end
local oldCategory=A.CategoryFor
function A:CategoryFor(id,kind)
    if id==33753 or id==64222 then return 'fishing' end -- Keep fillet products in their established tab despite generic ingredients.
    if (id~=33753 and kind==ITEMTYPE_FISH) or kind==ITEMTYPE_LURE then return 'fishing' end
    -- A material may be found by more than one activity. Fishing discovery must
    -- not reclassify reagent/rawhide/etc. permanently or block its creature loot.
    local resource=oldCategory(self,id,kind)
    if resource then return resource end
    if self.db.fishingKnown and self.db.fishingKnown[id] then return 'fishing' end
end
A.categories[#A.categories+1]={key='fishing',name='FISHING'}
A.filterCategories[#A.filterCategories+1]={key='fishing',name='FISHING',tabs={'FILETABLE_FISH','SPECIAL_FISH','BYCATCH','FILLET_RESULTS'}}
local oldSection=A.SectionFor
function A:SectionFor(item) if item.category=='fishing' then return 'fishing' end; return oldSection(self,item) end
local oldFilterTab=A.FilterTab
function A:FilterTab(item,id)
    if item.category=='fishing' then
        if id==33753 or id==64222 then return 4 end
        if self:IsFiletableLink(self.Link(id)) then return 1 end
        return self:IsSpecialFish(self.Link(id)) and 2 or 3
    end
    return oldFilterTab(self,item,id)
end
function A:IsSpecialFish(link)
    local kind,special=GetItemLinkItemType(link)
    return kind==ITEMTYPE_FISH and not self:IsFiletableLink(link) or
        SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH and special==SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH or false
end
function A:IsFiletableLink(link)
    if GetItemLinkItemId(link)==33753 or GetItemLinkItemType(link)~=ITEMTYPE_FISH then return false end
    if GetItemLinkDisplayQuality(link)~=(ITEM_DISPLAY_QUALITY_NORMAL or ITEM_QUALITY_NORMAL or 1) then return false end
    -- White quality alone must never authorize consuming trophy/rare fish.
    return GetItemLinkItemUseType and ITEM_USE_TYPE_FILLET_FISH and GetItemLinkItemUseType(link)==ITEM_USE_TYPE_FILLET_FISH or false
end
function A:ObserveCatch(link)
    local id=self.ValidId(GetItemLinkItemId(link))
    if not id or GetItemLinkName(link)=='' then return end
    self.db.fishingKnown[id]=true
    return self:Observe(link)
end
function A:EnsureRunningFishing()
    if self.db.session.state=='stopped' then
        if not self.db.options.autoStart then return false end
        self:Play()
    elseif self.db.session.state=='paused' then
        if not self.db.options.autoResume then return false end
        self:Play()
    end
    return true
end
local oldPlay=A.Play
function A:Play()
    oldPlay(self)
    self:FishingState()
end
local oldReset=A.ResetSession
function A:ResetSession() self:StopFilleting(); oldReset(self); self:FishingState(); self.fishingAt=nil; self.fishingEvidence=nil end
local oldPause=A.Pause
function A:Pause() oldPause(self); self.fishingAt=nil; self:StopFilleting() end
local oldStop=A.Stop
function A:Stop() oldStop(self); self.fishingAt=nil; self.fishingEvidence=nil; self:StopFilleting() end
local oldAccrue=A.AccrueTime
function A:AccrueTime()
    local f,t=self:FishingState()
    local now=self.Now()
    if self.fishingAt and self.db.session.state=='running' then
        local delta=math.max(0,now-self.fishingAt)
        f.elapsed=f.elapsed+delta; t.elapsed=t.elapsed+delta
    end
    self.fishingAt=self.fishingActive and self.db.session.state=='running' and now or nil
    oldAccrue(self)
end
function A:SelectActivity(tab)
    self.db.ui.activity=tab; self.offset=0; self:QueueRefresh()
end
-- Fixed public ESO lure slots. Names, counts and icons always come from ESO.
local waters={
    ['грязная вода']={3,9},['маслянистая вода']={3,9},['речная вода']={4,6},['озёрная вода']={2,8},['солёная вода']={5,7},
    ['汚水']={3,9},['川']={4,6},['湖']={2,8},['塩水']={5,7},
    ['foul']={3,9},['oily']={3,9},['brackwasser']={3,9},['ölwasser']={3,9},['sale']={3,9},['huileux']={3,9},
    ['river']={4,6},['flusswasser']={4,6},['rivière']={4,6},
    ['lake']={2,8},['seewasser']={2,8},['lacustre']={2,8},
    ['mystic']={5,7},['mythenwasser']={5,7},['mystique']={5,7},['мистическая вода']={5,7},['秘術']={5,7},
    ['saltwater']={5,7},['salzwasser']={5,7},['eau de mer']={5,7},
}
function A:ChooseFishingBait()
    if not self.db.options.autoBait or not SetFishingLure or not GetFishingLureInfo then return end
    if self.fishingActive or INTERACTION_FISH and GetInteractionType()==INTERACTION_FISH then return end
    if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode() then return end
    local _,name,_,_,extra=GetGameCameraInteractableActionInfo()
    -- ESO can report interaction blocked when no lure is selected. Selecting a
    -- lure is harmless; it does not interact, cast, or bypass the blocked action.
    if not ADDITIONAL_INTERACT_INFO_FISHING_NODE or extra~=ADDITIONAL_INTERACT_INFO_FISHING_NODE then return end
    local text=zo_strlower(zo_strformat('<<z:1>>',name or ''))
    local choices=waters[text]
    if not choices then
        local aliases={}; for label in pairs(waters) do aliases[#aliases+1]=label end
        table.sort(aliases,function(a,b) return #a>#b end)
        for _,label in ipairs(aliases) do if text:find(label,1,true) then choices=waters[label]; break end end
    end
    if not choices then return end -- Unknown water: preserve the player's selection.
    for _,index in ipairs({choices[1],choices[2],1}) do
        local _,_,stock=GetFishingLureInfo(index)
        if stock and stock>0 then
            if GetFishingLure()~=index then
                if self.baitAttemptIndex~=index or self.Now()-(self.baitAttemptAt or -1)>=0.5 then
                    self.baitAttemptIndex,self.baitAttemptAt=index,self.Now()
                    SetFishingLure(index)
                end
            end
            return index
        end
    end
end
function A:SampleBait(active)
    if not GetFishingLure or not GetFishingLureInfo then return end
    local index=GetFishingLure()
    if not index or index<1 then self.baitSnapshot=nil; return end
    local name,icon,stock=GetFishingLureInfo(index)
    if type(stock)~='number' then return end
    local previous=self.baitSnapshot
    if active and previous and previous.index==index and stock<previous.stock and self.db.session.state=='running' then
        local f,t=self:FishingState(); local delta=previous.stock-stock
        f.baitUsed=f.baitUsed+delta; t.baitUsed=t.baitUsed+delta
    end
    self.baitSnapshot={index=index,name=zo_strformat(SI_TOOLTIP_ITEM_NAME or '<<C:1>>',name),icon=icon,stock=stock}
end
local oldMark=A.MarkWorldNode
function A:MarkWorldNode() self:ChooseFishingBait(); self:SampleBait(false); oldMark(self); if self.harvestEvidence and self.harvestEvidence.worldNode then self:SelectActivity('resources') end end
local oldBlock=A.BlockTransfer
function A:BlockTransfer()
    self:AccrueTime()
    self.fishingEvidence=nil; self.fishingActive=false; self.fishingAt=nil; self.baitSnapshot=nil
    oldBlock(self)
end
local oldPoll=A.PollInteraction
function A:PollInteraction()
    local now=self.Now()
    local blocked=self.transferUntil and now<self.transferUntil
    local current=GetInteractionType()
    local active=not blocked and INTERACTION_FISH and current==INTERACTION_FISH or false
    if not active and not blocked and current==INTERACTION_NONE and not self:InventoryOpen() then
        self:ChooseFishingBait()
    end
    self:AccrueTime()
    if active then
        if not self.fishingActive then
            self.creatureAttempt=nil; self.interactionAttempt=nil
            -- A paused session resumes on a real catch, not merely casting the line.
            if self.db.session.state~='paused' then self:EnsureRunningFishing() end
            self.castBackpack=self:FishingBackpack(); self:SelectActivity('fishing')
        end
        local _,name=GetGameCameraInteractableActionInfo()
        if not self.fishingEvidence or not self.fishingEvidence.lootOpen then self.fishingEvidence={name=name or '',untilTime=now+2} end
    elseif current==INTERACTION_HARVEST or blocked then
        self.fishingEvidence=nil
        if current==INTERACTION_HARVEST and self.lastFishingInteraction~=current then self:SelectActivity('resources') end
    elseif self.fishingEvidence and self.fishingEvidence.untilTime<now then self.fishingEvidence=nil end
    self:SampleBait(active or self.fishingActive)
    self.fishingActive=active; self.lastFishingInteraction=current
    self.fishingAt=active and self.db.session.state=='running' and now or nil
    oldPoll(self)
    self:RefreshDialogActionLayer()
    if not active and self:InventoryOpen() then self.fishingEvidence=nil end
    self:PollFilleting()
end
function A:IsFishingLoot()
    self:PollInteraction()
    local e=self.fishingEvidence
    if not e or e.untilTime<self.Now() then return false end
    local name,kind=GetLootTargetInfo()
    if not self.fishingActive and self:GatheredInteractionSource() then return false end
    if (not name or name=='') and kind==INTERACT_TARGET_TYPE_NONE and not self.fishingActive and self:AutolootCreatureName() then return false end
    if kind==INTERACT_TARGET_TYPE_CLIENT_CHARACTER or kind==INTERACT_TARGET_TYPE_AOE_LOOT then return false end
    if name and name~='' and e.name~='' and zo_strlower(name)~=zo_strlower(e.name) then return false end
    return true
end
local oldLootOpened=A.LootOpened
function A:LootOpened()
    if self:IsFishingLoot() then
        self.fishingEvidence.untilTime=self.Now()+120; self.fishingEvidence.lootOpen=true
    else oldLootOpened(self) end
end
local oldLootClosed=A.LootClosed
function A:LootClosed()
    oldLootClosed(self)
    if self.fishingEvidence then self.fishingEvidence.untilTime=self.Now()+0.25; self.fishingEvidence.lootOpen=nil end
end
local oldLoot=A.Loot
function A:Loot(event,who,link,count,sound,kind,isSelf,...)
    link=self:LootItemLink(link,select(3,...))
    if isSelf and kind==LOOT_TYPE_ITEM and type(count)=='number' and count>0 and count==math.floor(count) and self:IsFishingLoot() then
        local id=self:ObserveCatch(link)
        if id and self:EnsureRunningFishing() then
            local f,t=self:FishingState()
            f.catches[id]=(f.catches[id] or 0)+count; t.catches[id]=(t.catches[id] or 0)+count
            if self:IsFiletableLink(link) and f.oldFish[id]==nil then
                f.oldFish[id]=math.max(0,((self.castBackpack or {})[id] or 0)-(f.counts[id] or 0))
            end
            f.counts[id]=(f.counts[id] or 0)+count
            f.caught=f.caught+count; t.caught=t.caught+count
            if self:IsFiletableLink(link) then f.white=f.white+count; t.white=t.white+count
            elseif self:IsSpecialFish(link) then f.special=f.special+count; t.special=t.special+count
            else f.bycatch=f.bycatch+count; t.bycatch=t.bycatch+count end
            self:RecordSource(id,'fishing',self.fishingEvidence and self.fishingEvidence.name)
            self:SelectActivity('fishing'); self:NotifyRare(link,count); self:QueueRefresh()
        end
        return
    end
    local id=GetItemLinkItemId(link)
    local item=self.db.catalog[id]
    if item and item.category=='fishing' and item.itemType~=ITEMTYPE_LURE then return end
    oldLoot(self,event,who,link,count,sound,kind,isSelf,...)
end
local oldAccepted=A.AcceptedHarvest
function A:AcceptedHarvest(id,count)
    local accepted=oldAccepted(self,id,count)
    if accepted then self:SelectActivity('resources') end
    return accepted
end
function A:FishingBackpack()
    local result,slots={},{}
    if not GetBagSize then return result,slots end
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        local link=GetItemLink(BAG_BACKPACK,slot,LINK_STYLE_DEFAULT)
        local id=link~='' and self.ValidId(GetItemLinkItemId(link))
        if id then
            local count=GetSlotStackSize(BAG_BACKPACK,slot)
            result[id]=(result[id] or 0)+count
            if self:IsFiletableLink(link) then slots[#slots+1]={slot=slot,id=id,count=count} end
        end
    end
    return result,slots
end
function A:ProcessingSnapshot()
    local counts,slots=self:FishingBackpack()
    local function Total(id)
        if GetItemLinkStacks then local b,_,v=GetItemLinkStacks(self.Link(id)); return (b or 0)+(v or 0) end
        return (counts[id] or 0)+(self.stock[id] or 0)
    end
    return {counts=counts,slots=slots,meat=Total(33753),roe=Total(64222),at=self.Now(),sessionFishing=self.db.session.fishing}
end
function A:BeginFilletObservation()
    self.fishingEvidence=nil
    if not self.filletObservation then self.filletObservation=self:ProcessingSnapshot(); self.filletChangedAt=nil end
end
function A:FinishFilletObservation()
    local before=self.filletObservation
    if not before then return false end
    -- Coalesce server messages: roe can arrive separately after the meat update.
    if self.Now()-(self.filletChangedAt or before.at)<0.3 then return false end
    local after=self:ProcessingSnapshot()
    local n,removed=0,{}
    for _,entry in ipairs(before.slots) do
        if not removed[entry.id] then
            local delta=(before.counts[entry.id] or 0)-(after.counts[entry.id] or 0)
            if delta>0 then removed[entry.id]=delta; n=n+delta end
        end
    end
    local meat,roe=after.meat-before.meat,after.roe-before.roe
    -- Positive meat corroborates actual processing; transfers/deletion alone never count.
    if n<=0 or meat<n or roe<0 then return false end
    self.filletObservation=nil
    local f,t=self:FishingState()
    local sameSession=before.sessionFishing==f
    for _,stats in ipairs(sameSession and {f,t} or {t}) do
        stats.filleted=stats.filleted+n; stats.roe=stats.roe+roe
        if roe>0 then stats.sinceRoe=n==1 and 0 or false
        elseif stats.sinceRoe~=false then stats.sinceRoe=stats.sinceRoe+n end
    end
    local entirelySession=sameSession
    for id,amount in pairs(removed) do
        local old=math.min(f.oldFish[id] or before.counts[id] or 0,amount)
        if sameSession then f.oldFish[id]=math.max(0,(f.oldFish[id] or before.counts[id] or 0)-old) end
        local recent=amount-old
        if old>0 or (f.counts[id] or 0)<recent then entirelySession=false end
        if sameSession then f.counts[id]=math.max(0,(f.counts[id] or 0)-recent) end
    end
    -- Mixed old/new batches have ambiguous output provenance. Never invent session gold.
    if entirelySession then
        f.outputs[33753]=(f.outputs[33753] or 0)+meat
        f.outputs[64222]=(f.outputs[64222] or 0)+roe
    end
    if self.filletQueue then self.filletQueue.waiting=nil; self.filletQueue.nextAt=self.Now()+0.5 end
    self.filletChangedAt=nil
    self:RecordSource(33753,'filleting'); if roe>0 then self:RecordSource(64222,'filleting') end
    if roe>0 then self:NotifyRare(self.Link(64222),roe) end
    self:QueueRefresh()
    return true
end
function A:StopFilleting() self.filletQueue=nil; self.filletPending=nil end
function A:InventoryOpen()
    return SCENE_MANAGER and SCENE_MANAGER.IsShowing and (SCENE_MANAGER:IsShowing('inventory') or SCENE_MANAGER:IsShowing('gamepad_inventory')) or false
end
function A:FilletViewAllowed(inventoryBound)
    if inventoryBound then return self:InventoryOpen() end
    if SCENE_MANAGER and SCENE_MANAGER.IsShowingBaseScene then return SCENE_MANAGER:IsShowingBaseScene() end
    return not self:InventoryOpen()
end
function A:ToggleFilleting()
    if self.filletQueue then self:StopFilleting(); return end
    self:StartFilleting()
end
function A:StartFilleting()
    local inventoryBound=self:InventoryOpen()
    if not self:FilletViewAllowed(inventoryBound) or not CallSecureProtected or IsUnitInCombat and IsUnitInCombat('player') then return end
    if GetInteractionType()~=INTERACTION_NONE then return end
    local _,slots=self:FishingBackpack()
    local eligible=false
    for _,entry in ipairs(slots) do
        if not IsItemPlayerLocked or not IsItemPlayerLocked(BAG_BACKPACK,entry.slot) then eligible=true; break end
    end
    if not eligible or CheckInventorySpaceSilently and not CheckInventorySpaceSilently(2) then return end
    self.fishingEvidence=nil
    self:PlayIfNeededForFillet()
    self.filletQueue={nextAt=self.Now(),inventoryBound=inventoryBound}
end
function A:PlayIfNeededForFillet() if self.db.session.state~='running' then self:Play() end end
function A:PollFilleting()
    local now=self.Now()
    if self.filletObservation then
        local completed=self:FinishFilletObservation()
        if completed and self.filletQueue then self.filletQueue.waiting=nil; self.filletQueue.nextAt=now+0.5 end
        if self.filletObservation and now-self.filletObservation.at>5 then self.filletObservation=nil; self:StopFilleting(); self:Say(L('FILLET_TIMEOUT')) end
    end
    local queue=self.filletQueue
    if not queue then
        if self:InventoryOpen() and not self.filletObservation then self.filletPrevious=self:ProcessingSnapshot() end
        return
    end
    if not self:FilletViewAllowed(queue.inventoryBound) or GetInteractionType()~=INTERACTION_NONE or IsUnitInCombat and IsUnitInCombat('player') or IsUnitDead and IsUnitDead('player') then self:StopFilleting(); return end
    if queue.waiting or now<queue.nextAt then return end
    if CheckInventorySpaceSilently and not CheckInventorySpaceSilently(2) then self:StopFilleting(); return end
    local _,slots=self:FishingBackpack()
    for _,entry in ipairs(slots) do
        local locked=IsItemPlayerLocked and IsItemPlayerLocked(BAG_BACKPACK,entry.slot)
        local usable,onlySlot=true,false
        if IsItemUsable then usable,onlySlot=IsItemUsable(BAG_BACKPACK,entry.slot) end
        local interact=not CanInteractWithItem or CanInteractWithItem(BAG_BACKPACK,entry.slot)
        if not locked and usable and not onlySlot and interact then
            local remaining=GetItemCooldownInfo and GetItemCooldownInfo(BAG_BACKPACK,entry.slot) or 0
            if remaining>0 then queue.nextAt=now+remaining/1000+0.05; return end
            self:BeginFilletObservation(); queue.waiting=true
            local success=CallSecureProtected('UseItem',BAG_BACKPACK,entry.slot)
            if success==false then self.filletObservation=nil; self:StopFilleting(); self:Say(L('FILLET_DECLINED')) end
            return
        end
    end
    self:StopFilleting()
end
local oldRows=A.RowsAndTotals
function A:RowsAndTotals()
    local rows,totals=oldRows(self)
    local f=self:FishingState()
    local counts={}
    for id,n in pairs(f.counts) do counts[id]=(counts[id] or 0)+n end
    for id,n in pairs(f.outputs) do counts[id]=(counts[id] or 0)+n end
    local fishRows={}; local backpack=self:FishingBackpack()
    for id,count in pairs(counts) do
        if count>0 and self:IsEnabled(id) then
            local item=self.db.catalog[id]; local price,source=self:Price(id)
            -- Caught totals retain processed fish; output units are not new catches.
            if price then totals.sessionGold=totals.sessionGold+count*price else totals.missingSession=totals.missingSession+1 end
            fishRows[#fishRows+1]={id=id,name=item.name,icon=item.icon,quality=item.quality,count=count,stock=(backpack[id] or 0)+(self.stock[id] or 0),price=price,source=source}
        end
    end
    for id,count in pairs(f.catches) do if self:IsEnabled(id) then totals.sessionCount=totals.sessionCount+count end end
    if self.db.session.elapsed>=1 then totals.perHour=totals.sessionGold*3600/self.db.session.elapsed end
    if self.db.ui.activity=='fishing' then
        -- Same tracked material scope as the craft-bag total, plus backpack;
        -- bank storage never contributes to either inventory column or value.
        for id,stock in pairs(backpack) do
            if stock>0 and self:IsEnabled(id) and self:SessionItemSeen(id) then
                local price=self:Price(id); totals.stockCount=totals.stockCount+stock
                if price then totals.stockGold=totals.stockGold+stock*price
                elseif (self.stock[id] or 0)==0 then totals.missingStock=totals.missingStock+1 end
            end
        end
        self:SortRows(fishRows); return fishRows,totals
    end
    return rows,totals
end
function A:ResetFishingTotals()
    self:AccrueTime(); self.db.fishingTotals=fresh(); self:QueueRefresh()
end
function A:IntermediateFishingFont()
    if ZoFontGame and ZoFontGame.GetFontInfo and ZoFontGameSmall and ZoFontGameSmall.GetFontInfo then
        local face,large,style=ZoFontGame:GetFontInfo()
        local _,small=ZoFontGameSmall:GetFontInfo()
        return string.format('%s|%d|%s',face,math.floor((large+small)/2+0.5),style or '')
    end
    return '$(MEDIUM_FONT)|16|soft-shadow-thin'
end
-- UI integration follows the existing table and button components.
local oldCreate=A.CreateWindow
function A:CreateWindow()
    oldCreate(self)
    self.activityButtons={}
    for i,spec in ipairs({{'RESOURCES','resources'},{'FISHING','fishing'}}) do
        local tab=spec[2]
        local button=self:MenuButton(self.window,L(spec[1]),140,function() self:SelectActivity(tab) end)
        button:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*148,114)
        self.activityButtons[i]=button
    end
    self.fishingInfo=self:Label(self.window,'ZoFontGame')
    self.fishingInfo:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,150)
    self.fishingInfo:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-24,150)
    self.fishingInfo:SetHeight(25)
    self.fishingCards={}
    for index,key in ipairs({'CATCH_LABEL','WHITE_LABEL','BACKPACK_FISH_LABEL'}) do
        local card=WINDOW_MANAGER:CreateControl(nil,self.window,CT_CONTROL)
        card:SetHeight(48); card:SetMouseEnabled(true)
        card.value=self:Label(card,'ZoFontGame'); card.value:SetAnchor(TOPLEFT,card,TOPLEFT,0,0)
        card.value:SetAnchor(TOPRIGHT,card,TOPRIGHT,0,0); card.value:SetHeight(24)
        card.rate=self:Label(card,'ZoFontGame'); card.rate:SetAnchor(TOPLEFT,card,TOPLEFT,0,24)
        card.rate:SetAnchor(TOPRIGHT,card,TOPRIGHT,0,24); card.rate:SetHeight(24)
        card:SetHandler('OnMouseEnter',function(control)
            if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(control,TOP,L(key)) end
        end)
        card:SetHandler('OnMouseExit',function() if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end end)
        self.fishingCards[index]=card
    end
    self.fishingLines={}
    for index=1,3 do
        local label=self:Label(self.window,self:IntermediateFishingFont())
        label:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,226+(index-1)*24)
        label:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-24,226+(index-1)*24); label:SetHeight(24)
        self.fishingLines[index]=label
    end
    self.fishingTools={}
    local specs={
        {'FILLET',function() self:ToggleFilleting() end},
        {'SESSION_TOTAL',function() self.db.ui.fishingLifetime=not self.db.ui.fishingLifetime; self:QueueRefresh() end},
        {'AUTO_BAIT',function() self.db.options.autoBait=not self.db.options.autoBait; self:QueueRefresh() end},
    }
    for i,spec in ipairs(specs) do
        local button=self:MenuButton(self.window,L(spec[1]),130,spec[2])
        button:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*138,243)
        self.fishingTools[i]=button
    end
    self:Refresh()
end
function A:FishingToolsTop() return self.window:GetWidth()<700 and 318 or 296 end
function A:TableTop()
    if self.db.ui.activity~='fishing' then return 190 end
    return self:FishingToolsTop()+(self.window:GetWidth()<700 and 64 or 32)+44
end
local oldRefresh=A.Refresh
function A:Refresh()
    oldRefresh(self)
    if not self.activityButtons then return end
    local top=self:TableTop()
    if not self.db.ui.minimized and self.db.ui.activity=='fishing' and self.window:GetHeight()<top+110 then self.window:SetHeight(top+110) end
    local columns=self.window:GetWidth()<700 and 2 or 3
    local width=(self.window:GetWidth()-36-(columns-1)*8)/columns
    for i,button in ipairs(self.fishingTools) do
        button:ClearAnchors(); button:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+((i-1)%columns)*(width+8),self:FishingToolsTop()+math.floor((i-1)/columns)*32)
        button:SetWidth(width); button:SetFont('ZoFontGameBold')
    end
    for index,row in ipairs(self.rowControls) do
        row:ClearAnchors(); row:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,top+(index-1)*28)
        row:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-42,top+(index-1)*28)
    end
    self.empty:ClearAnchors(); self.empty:SetAnchor(TOPLEFT,self.window,TOPLEFT,24,top+20)
    self.slider:ClearAnchors(); self.slider:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-18,top+6)
    self.slider:SetAnchor(BOTTOMRIGHT,self.window,BOTTOMRIGHT,-18,-(self:TableBottomSpace()+5))
    local minimized=self.db.ui.minimized
    local fishing=self.db.ui.activity=='fishing'
    for i,button in ipairs(self.activityButtons) do
        button:SetHidden(minimized==true)
        button:SetAlpha((i==2)==fishing and 1 or 0.55)
    end
    self.fishingInfo:SetHidden(minimized or not fishing)
    local cardWidth=(self.window:GetWidth()-48)/3
    for index,card in ipairs(self.fishingCards) do
        card:ClearAnchors(); card:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(index-1)*(cardWidth+4),177)
        card:SetWidth(cardWidth); card:SetHidden(minimized or not fishing)
    end
    for index,line in ipairs(self.fishingLines) do
        line:ClearAnchors()
        local y=226+(index-1)*22+(index>=2 and self.window:GetWidth()<700 and 22 or 0)
        line:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,y); line:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-24,y)
        local multiline=index==1 and self.window:GetWidth()<700
        line:SetHeight(multiline and 44 or 22); line:SetMaxLineCount(multiline and 2 or 1)
        line:SetWrapMode(multiline and TEXT_WRAP_MODE_TRUNCATE or TEXT_WRAP_MODE_ELLIPSIS)
        line:SetHidden(minimized or not fishing)
    end
    for _,button in ipairs(self.fishingTools) do button:SetHidden(minimized or not fishing) end
    if fishing then
        local f,t=self:FishingState(); local stats=self.db.ui.fishingLifetime and t or f
        local function Rate(count)
            return stats.elapsed>0 and string.format('%.1f /h',count*3600/stats.elapsed) or '— /h'
        end
        local bag,slots=self:FishingBackpack(); local ready,recent=0,0
        for _,entry in ipairs(slots) do ready=ready+entry.count end
        for id,count in pairs(bag) do if self:IsFiletableLink(self.Link(id)) then recent=recent+math.min(count,f.counts[id] or 0) end end
        self.fishingInventoryOther=math.max(0,ready-recent)
        local fishIcon=GetItemLinkIcon(self.Link(42861))
        self.fishingCards[1].value:SetText('|t24:24:ALTHI/art/fishing_hook.dds|t '..self.Integer(stats.caught))
        self.fishingCards[2].value:SetText('|t24:24:'..fishIcon..'|t '..self.Integer(stats.white))
        self.fishingCards[3].value:SetText('|t24:24:EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds|t '..self.Integer(self.fishingInventoryOther))
        self.fishingCards[1].rate:SetText(Rate(stats.caught)); self.fishingCards[2].rate:SetText(Rate(stats.white))
        self.fishingCards[3].rate:SetText(string.format(L('FILETABLE_STOCK'),ready))
        local bait=self.baitSnapshot
        local selected=bait and ((bait.icon and '|t20:20:'..bait.icon..'|t ' or '')..bait.name..' × '..self.Integer(bait.stock)) or '—'
        local percentage=stats.filleted>0 and string.format('%.2f%%',stats.roe*100/stats.filleted) or '—'
        local perRoe=stats.roe>0 and string.format('%.1f',stats.filleted/stats.roe) or '—'
        self.fishingInfo:SetText(L('FISHING_TIME')..': '..self.Time(stats.elapsed))
        self.fishingLines[1]:SetText(string.format(L('BAIT_AND_USED'),selected,stats.baitUsed))
        self.fishingLines[2]:SetText(string.format(L('FILLET_AND_ROE'),stats.filleted,stats.roe,percentage))
        self.fishingLines[3]:SetText(string.format(L('ROE_GAP'),perRoe,stats.sinceRoe==false and '—' or tostring(stats.sinceRoe)))
        self.fishingTools[1]:SetText(L(self.filletQueue and 'CANCEL' or 'FILLET'))
        local bright,dim='|cFFFFFF','|c888888'
        self.fishingTools[2]:SetText((self.db.ui.fishingLifetime and dim or bright)..L('SESSION_SHORT')..'|r / '..(self.db.ui.fishingLifetime and bright or dim)..L('TOTAL_SHORT')..'|r')
        self.fishingTools[3]:SetText(L('AUTO_BAIT')..': '..L(self.db.options.autoBait and 'ON' or 'OFF'))
        self.stockGroup:SetText(L('INVENTORY_COMBINED'))
        self.stockButton:SetText(L('INVENTORY_VALUE')..L(self.db.ui.showStock and 'ON' or 'OFF'))
        local prefix=L('CRAFT_BAG_8C418C'); local value=self.bagTotal:GetText()
        if value:sub(1,#prefix)==prefix then self.bagTotal:SetText(L('INVENTORY_VALUE')..value:sub(#prefix+1)) end
    else self.stockGroup:SetText(L('CRAFT_BAG_A81872')) end
end
local oldInitialize=A.Initialize
function A:Initialize()
    oldInitialize(self)
    ZO_CreateStringId('SI_BINDING_NAME_ALTHI_FILLET',L('FILLET'))
    ZO_Dialogs_RegisterCustomDialog('ALTHI_FISHING_TOTAL_RESET',{
        title={text=L('RESET_LIFETIME')},mainText={text=L('RESET_LIFETIME_CONFIRM')},
        buttons={{text=L('RESET'),callback=function() self:ResetFishingTotals() end},{text=L('CANCEL')}},
    })
    -- Observe inventory results; never replace or prehook the protected UseItem API.
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        for _,bag in ipairs({BAG_BACKPACK,BAG_VIRTUAL}) do
            local namespace='ALTHIFilletBag'..bag
            EVENT_MANAGER:RegisterForEvent(namespace,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function()
                if self.filletObservation then self.filletChangedAt=self.Now(); return end
                local previous=self.filletPrevious
                if previous and self.Now()-previous.at<=1 and self:InventoryOpen() and
                   not (self.transferUntil and self.Now()<self.transferUntil) and not self.fishingActive then
                    local current=self:ProcessingSnapshot()
                    for _,entry in ipairs(previous.slots) do
                        if (current.counts[entry.id] or 0)<(previous.counts[entry.id] or 0) then
                            self.filletObservation=previous; self.filletChangedAt=self.Now(); break
                        end
                    end
                end
            end)
            EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                REGISTER_FILTER_BAG_ID,bag,REGISTER_FILTER_INVENTORY_UPDATE_REASON,INVENTORY_UPDATE_REASON_DEFAULT)
        end
    end
    EVENT_MANAGER:RegisterForEvent('ALTHIFishingLifecycle',EVENT_PLAYER_DEACTIVATED,function()
        self.fishingActive=false; self.fishingAt=nil; self.fishingEvidence=nil
        self.filletObservation=nil; self.filletPrevious=nil; self:StopFilleting()
    end)
    if EVENT_CRAFT_STARTED then EVENT_MANAGER:RegisterForEvent('ALTHIFillet',EVENT_CRAFT_STARTED,function()
        if GetCraftingInteractionType and CRAFTING_TYPE_PROVISIONING and GetCraftingInteractionType()==CRAFTING_TYPE_PROVISIONING then self:BeginFilletObservation() end
    end) end
    if EVENT_CRAFT_COMPLETED then EVENT_MANAGER:RegisterForEvent('ALTHIFillet',EVENT_CRAFT_COMPLETED,function() if self.filletObservation then self.filletChangedAt=self.Now() end end) end
    for _,id in ipairs({42861,42862,42863,42864,42865,42866,42867,42868,133561,133562,42873,42874,42875,42876,43757,139011,140443,33753,64222}) do
        if GetItemLinkName(self.Link(id))~='' then self:ObserveCatch(self.Link(id)) end
    end
    if FISHING_MANAGER and type(FISHING_MANAGER.PrepareForInteraction)=='function' and ZO_PreHook then
        ZO_PreHook(FISHING_MANAGER,'PrepareForInteraction',function()
            self:RememberCreatureInteraction()
            self:RememberLootInteraction()
            self:ChooseFishingBait(); self:SampleBait(false)
            return false -- Preserve ESO's menu/input implementation and return value.
        end)
    end
    self:QueueRefresh()
end

A.sourceLabels.fishing='FISHING'
A.sourceLabels.filleting='FILLET_RESULTS'
local oldKnown=A.KnownSources
function A:KnownSources(id)
    if self.db.fishingKnown and self.db.fishingKnown[id] and self.db.catalog[id] and self.db.catalog[id].category=='fishing' then
        return {{kind=(id==33753 or id==64222) and 'filleting' or 'fishing',evidence='ESO fishing / filleting API'}}
    end
    return oldKnown(self,id)
end


A.sourceGroups.fishing='fishing'
A.sourceGroups.filleting='processing'
A.sourceFilters[#A.sourceFilters+1]={'fishing','FISHING'}
local oldObserved=A.ObservedText
function A:ObservedText(item)
    local extra={}
    for _,kind in ipairs({'fishing','filleting'}) do
        if item.observed and item.observed[kind] then extra[#extra+1]=L(self.sourceLabels[kind]) end
    end
    if #extra>0 then return table.concat(extra,', ') end
    return oldObserved(self,item)
end
local oldTracking=A.TrackingText
function A:TrackingText(id)
    local item=self.db.catalog[id]
    if item and item.category=='fishing' then
        return L(self:IsEnabled(id) and 'MATERIAL_ENABLED' or 'MATERIAL_DISABLED')..' · '..L((id==33753 or id==64222) and 'FILLET_RESULTS' or 'FISHING')
    end
    return oldTracking(self,id)
end
