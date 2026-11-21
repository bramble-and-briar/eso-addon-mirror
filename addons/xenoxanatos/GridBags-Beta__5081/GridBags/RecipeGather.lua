-- An explicit, finite recipe request. No crafting or off-bank inventory API calls.
GridBagsRecipeGather = {}
local Q=GridBagsRecipeGather
local R,F,M,T=GridBagsRouting,GridBagsCrafting,GridBagsSmartRouting,GridBagsTransferTools
local function Whole(value)return type(value)=="number"and value==math.floor(value)and value>0 end
local function Key(link)return GetItemLinkItemId and GetItemLinkItemId(link)end
local function Active(p)return p.state=="source"or p.state=="bank"or p.state=="review"end
local function Count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end

function Q:Read(list,index,batches)
    if not Whole(list)or not Whole(index)or not Whole(batches)or batches>1000 then return nil,"Choose a recipe and 1–1000 crafting batches."end
    if not GetRecipeInfo or not GetRecipeIngredientItemLink or not GetRecipeIngredientItemInfo or not GetRecipeTradeskillRequirement then return nil,"Recipe APIs are unavailable."end
    local ok,recipe,reason=pcall(function()
        local known,name,n,level,quality,_,craft,result=GetRecipeInfo(list,index)
        if known~=true then return nil,"Only a recipe learned by the current character can be gathered."end
        if not F.names[craft]or craft<1 or craft>7 or not Whole(result)or not Whole(n)or n>40 then return nil,"Recipe identity or ingredients are unavailable."end
        local skills=M:CaptureProfessions()
        local r={list=list,index=index,name=name,craft=craft,resultId=result,batches=batches,at=GetTimeStamp(),ingredients={},requirements={},quality=quality or 0,skills=skills,valid=true}
        if not skills[craft]then return nil,"Refresh this character's profession observations."end
        for number=1,GetNumRecipeTradeskillRequirements(list,index)do
            local profession,tier=GetRecipeTradeskillRequirement(list,index,number)
            r.requirements[profession]=math.max(r.requirements[profession]or 0,tier)
        end
        if (level or 0)>0 then r.requirements[5]=math.max(r.requirements[5]or 0,level)end
        for profession,tier in pairs(r.requirements)do if not skills[profession]or skills[profession].tier<tier then return nil,"The current character does not meet this recipe's crafting skill requirements."end end
        if r.quality>0 then
            if not skills[5]or not GetNonCombatBonus or not NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL or GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL)<r.quality then return nil,"The recipe quality passive requirement is not met."end
            skills[5].rarity=GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL)
        end
        local byId={}
        for ingredient=1,n do
            local link=GetRecipeIngredientItemLink(list,index,ingredient,LINK_STYLE_DEFAULT)
            local id=Key(link);local itemName,_,units=GetRecipeIngredientItemInfo(list,index,ingredient)
            if not Whole(id)or not Whole(units)then return nil,"An ingredient identity/quantity is unavailable."end
            if not byId[id]then byId[id]={id=id,link=link,name=itemName,perCraft=0};r.ingredients[#r.ingredients+1]=byId[id]end
            byId[id].perCraft=byId[id].perCraft+units
        end
        table.sort(r.ingredients,function(a,b)return a.id<b.id end)
        local signature={tostring(result),tostring(craft)}
        for _,ingredient in ipairs(r.ingredients)do ingredient.needed=ingredient.perCraft*batches;signature[#signature+1]=ingredient.id..":"..ingredient.perCraft end
        r.fingerprint=table.concat(signature,"|");return r
    end)
    if not ok then return nil,"Recipe data could not be read; refresh the selected recipe."end
    return recipe,reason
end

function Q:Resolve(recipe)
    local found=self:Read(recipe.list,recipe.index,recipe.batches)
    if found and found.fingerprint==recipe.fingerprint then return found end
    if GetNumRecipeLists and GetRecipeListInfo then
        for list=1,GetNumRecipeLists()do
            local _,n=GetRecipeListInfo(list)
            for index=1,n do
                local known,_,_,_,_,_,_,result=GetRecipeInfo(list,index)
                if known and result==recipe.resultId then local r=self:Read(list,index,recipe.batches);if r and r.fingerprint==recipe.fingerprint then return r end end
            end
        end
    end
    return nil,"The selected recipe is unknown, changed, or no longer craftable by this character."
end

function Q:Requests()R.data.gatherRequests=R.data.gatherRequests or {};return R.data.gatherRequests end
function Q:Keep(source,link)
    local id=Key(link);local n=0
    for _,request in pairs(R.data.gatherRequests or {})do
        if request.target==source and not request.closed then
            for _,ingredient in ipairs(request.recipe.ingredients)do if ingredient.id==id then n=n+ingredient.needed end end
        end
    end
    return n
end
function Q:CloseRequest(id)
    local request=self:Requests()[id];if not request then return nil,"Request not found."end
    request.closed=true;R:Notify();return true
end

function Q:SourceItems(source)
    if source==R.BANK and R:IsBanking()then return R:Scan(R.BANK),true end
    local record=source==R.BANK and GridBags.saved.bankSnapshots[GetWorldName()]or GridBagsSnapshots.records[source]
    if not record or GetTimeStamp()-(record.updatedAt or 0)>7*86400 then return {},false end
    local items={}
    for _,item in ipairs(record.items or {})do
        items[#items+1]={link=item.link,name=item.displayName or item.name,qty=item.stack,uid=item.uid,maxStack=item.maxStack,bound=item.bound,
            blocked=item.locked or item.playerLocked or item.stolen,observedAt=record.updatedAt}
    end
    return items,true
end
function Q:CraftBagCount(ingredient)
    if BAG_VIRTUAL and GetSlotStackSize then local ok,n=pcall(GetSlotStackSize,BAG_VIRTUAL,ingredient.id);if ok and type(n)=="number"then return n end end
    if GetItemLinkStacks then local ok,_,_,n=pcall(GetItemLinkStacks,ingredient.link);if ok and type(n)=="number"then return n end end
    return 0
end

function Q:Preview(list,index,batches)
    if R.pending or GridBagsGold.pending then return nil,"Wait for the current transfer to settle."end
    local recipe,reason=self:Read(list,index,batches);if not recipe then return nil,reason end
    for _,request in pairs(R.data.gatherRequests or {})do
        if request.target==R.character and not request.closed and request.recipe.fingerprint==recipe.fingerprint then return nil,"An active gather request already covers this recipe. Use Requests to inspect or release its ingredient hold first."end
    end
    local draft={recipe=recipe,target=R.character,rows={},proposals={},notices={}}
    local backpack=R:Scan(R.character)
    local sources={{id=R.BANK}}
    for id in pairs(GridBagsSnapshots.records)do if id~=R.character then sources[#sources+1]={id=id}end end
    table.sort(sources,function(a,b)if a.id==b.id then return false elseif a.id==R.BANK then return true elseif b.id==R.BANK then return false else return R:Name(a.id)<R:Name(b.id)end end)
    for _,source in ipairs(sources)do
        source.items,source.observed=self:SourceItems(source.id)
        if not source.observed then draft.notices[#draft.notices+1]=R:Name(source.id)..": missing/stale observation; excluded"end
    end
    for _,ingredient in ipairs(recipe.ingredients)do
        local row=T:Clone(ingredient);row.backpack=0;row.craftBag=self:CraftBagCount(ingredient);row.incoming=0;row.held=0;row.planned=0
        local outbound=0
        for _,item in ipairs(backpack)do if Key(item.link)==ingredient.id then row.backpack=row.backpack+item.qty end end
        for _,p in ipairs(R.data.plans)do
            if Active(p)and Key(p.link)==ingredient.id then
                if p.source==R.character and (p.state=="source"or p.state=="review")then outbound=outbound+p.remaining end
                if p.dest==R.character then if p.state=="review"then row.held=row.held+p.remaining else row.incoming=row.incoming+p.remaining end end
            end
        end
        row.otherRecipeHold=self:Keep(R.character,ingredient.link)
        row.have=math.max(0,row.backpack+row.craftBag-outbound-row.otherRecipeHold)
        local priorDeficit=math.max(0,row.otherRecipeHold-math.max(0,row.backpack+row.craftBag-outbound))
        row.incoming=math.max(0,row.incoming-priorDeficit)
        local need=math.max(0,row.needed-row.have-row.incoming-row.held)
        for _,source in ipairs(sources)do
            local linkUsed={}
            for _,item in ipairs(source.items)do
                if need>0 and Key(item.link)==ingredient.id and item.uid and item.maxStack and not item.blocked then
                    local characterBound=GetItemLinkBindType and BIND_TYPE_ON_PICKUP_BACKPACK and GetItemLinkBindType(item.link)==BIND_TYPE_ON_PICKUP_BACKPACK
                    local guard=R:Protection(source.id,item.link)
                    local allocated,total=R:Allocated(source.id,item)
                    local available=math.min(item.qty-allocated,R:Total(source.items,item.link)-total-R:KeepFloor(source.id,item.link)-(linkUsed[item.link]or 0))
                    if not guard.blocked and not characterBound and available>0 then
                        local qty=math.min(need,available)
                        draft.proposals[#draft.proposals+1]={source=source.id,dest=R.character,link=item.link,name=item.name,uid=item.uid,qty=qty,
                            available=item.qty,maxStack=item.maxStack,bound=item.bound,observedAt=item.observedAt or GetTimeStamp(),ingredient=ingredient.id,include=true,live=source.id==R.BANK and R:IsBanking()}
                        linkUsed[item.link]=(linkUsed[item.link]or 0)+qty;need=need-qty;row.planned=row.planned+qty
                    end
                end
            end
        end
        row.missing=need;draft.rows[#draft.rows+1]=row
    end
    return draft
end

function Q:Signature(draft)
    local parts={draft.target,draft.recipe.fingerprint,tostring(draft.recipe.batches)}
    for _,row in ipairs(draft.rows)do parts[#parts+1]=table.concat({row.id,row.needed,row.have,row.incoming,row.held,row.planned,row.missing,row.otherRecipeHold},":")end
    for _,p in ipairs(draft.proposals)do parts[#parts+1]=table.concat({p.source,p.link,p.uid,p.qty,p.available,p.maxStack,tostring(p.bound)},":")end
    return table.concat(parts,"|")
end

function Q:Commit(draft)
    if draft.target~=R.character then return nil,"The active character changed; build a fresh preview."end
    local fresh,reason=self:Preview(draft.recipe.list,draft.recipe.index,draft.recipe.batches)
    if not fresh then return nil,reason end
    if self:Signature(fresh)~=self:Signature(draft)then return nil,"Recipe quantities, inventory, reservations or protections changed. Refresh and review the new preview."end
    local hadRequests=R.data.gatherRequests~=nil
    local requests=self:Requests();local prune
    if Count(requests)>=100 then
        for id,old in pairs(requests)do
            if old.closed then
                local settled=true;for _,pid in ipairs(old.plans)do local p=R:Plan(pid);if p and Active(p)then settled=false end end
                if settled and (not prune or id<prune)then prune=id end
            end
        end
        if not prune then return nil,"Gather history is full; release completed request holds or finish pending deliveries."end
    end
    local start=#R.data.plans;local oldId=R.data.nextId
    local request={id=R:Id(),target=R.character,recipe=fresh.recipe,approved=true,at=GetTimeStamp(),plans={}}
    requests[request.id]=request
    for index,proposal in ipairs(fresh.proposals)do
        if draft.proposals[index].include~=false then
            proposal.mode="advance";proposal.smart={kind="gatherRecipe",request=request.id,ingredient=proposal.ingredient}
            local p,err=R:Add(proposal)
            if not p then
                while #R.data.plans>start do table.remove(R.data.plans)end
                requests[request.id]=nil;R.data.nextId=oldId
                if not hadRequests then R.data.gatherRequests=nil end
                return nil,"No deliveries saved: "..tostring(err)
            end
            request.plans[#request.plans+1]=p.id
        end
    end
    if prune then requests[prune]=nil end
    GridBagsActivity:Append({kind="control",outcome="control",code="RECIPE_GATHER_CONFIRMED",reason="Selected recipe ingredient deliveries explicitly approved; target ingredient hold active",item=request.recipe.name,destination=request.target})
    R:Notify();return request
end

function Q:Eligible(plan)
    local smart=plan.smart;local request=(R.data.gatherRequests or {})[smart.request]
    if not request or not request.approved or request.target~=plan.dest then return false,"Recipe gather authorization is missing","RECIPE_GATHER_INVALID"end
    local registered=false;for _,id in ipairs(request.plans)do if id==plan.id then registered=true end end
    if not registered then return false,"Delivery is not part of the approved recipe request","RECIPE_GATHER_INVALID"end
    local recipe=request.recipe
    if plan.dest==R.character then
        local current,reason=self:Resolve(recipe)
        if not current then return false,reason,"RECIPE_GATHER_INVALID"end
    else
        if not recipe.valid or GetTimeStamp()-recipe.at>7*86400 then return false,"Recipient's specific recipe proof is missing/stale; log into the recipient to refresh","RECIPE_GATHER_STALE"end
        local record=GridBagsSnapshots.records[plan.dest]
        local skills=recipe.skills
        if record and record.updatedAt>=recipe.at then skills=record.professions end
        if not skills or not skills[recipe.craft]then return false,"Recipient profession evidence unavailable","CRAFT_DATA_MISSING"end
        for profession,tier in pairs(recipe.requirements)do if not skills[profession]or skills[profession].tier<tier then return false,"Recipient no longer meets recipe profession requirements","RECIPE_GATHER_INVALID"end end
        if recipe.quality>0 and (not skills[5]or not skills[5].rarity or skills[5].rarity<recipe.quality)then return false,"Recipient recipe quality passive is insufficient","RECIPE_GATHER_INVALID"end
    end
    for _,ingredient in ipairs(recipe.ingredients)do if ingredient.id==smart.ingredient and Key(plan.link)==ingredient.id then return true end end
    return false,"Item is not an ingredient of the approved recipe","RECIPE_GATHER_INVALID"
end

function Q:RefreshProofs()
    for _,request in pairs(R.data.gatherRequests or {})do
        if request.target==R.character then
            local current=self:Resolve(request.recipe)
            if current then request.recipe=current else request.recipe.valid=false end
        end
    end
end
