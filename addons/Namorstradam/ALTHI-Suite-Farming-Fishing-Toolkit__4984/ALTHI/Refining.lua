-- Read-only observation of the native deconstruction message and craft results.
-- No crafting calls, inventory moves or native UI/settings changes.
local A=ALTHarvestItems
local function fresh() return {crafts={}} end
local function group(state,key)
    state.crafts[key]=state.crafts[key] or {inputs={},outputs={},baseFor={}}
    return state.crafts[key]
end
local function add(t,id,n) t[id]=(t[id] or 0)+n end
function A:RefiningState()
    self.db.refining=self.db.refining or {current=fresh(),total=fresh(),items={}}
    return self.db.refining
end
function A:RefiningCraftKey(skill)
    if skill==CRAFTING_TYPE_BLACKSMITHING then return 'metal' end
    if skill==CRAFTING_TYPE_CLOTHIER then return 'cloth' end
    if skill==CRAFTING_TYPE_WOODWORKING then return 'wood' end
    if skill==CRAFTING_TYPE_JEWELRYCRAFTING then return 'jewelry' end
end
function A:RefiningMeta(link)
    local id=self.ValidId(GetItemLinkItemId(link)); if not id then return end
    local s=self:RefiningState()
    local kind=GetItemLinkItemType(link)
    local role='other'
    if kind==ITEMTYPE_BLACKSMITHING_MATERIAL or kind==ITEMTYPE_CLOTHIER_MATERIAL
        or kind==ITEMTYPE_WOODWORKING_MATERIAL or kind==ITEMTYPE_JEWELRYCRAFTING_MATERIAL then role='base'
    elseif kind==ITEMTYPE_BLACKSMITHING_BOOSTER or kind==ITEMTYPE_CLOTHIER_BOOSTER
        or kind==ITEMTYPE_WOODWORKING_BOOSTER or kind==ITEMTYPE_JEWELRYCRAFTING_BOOSTER then role='booster' end
    s.items[id]={name=zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link)),
        icon=GetItemLinkIcon(link),quality=GetItemLinkDisplayQuality(link),role=role}
    return id
end
function A:RefiningStock(id)
    local backpack,bank,virtual=GetItemLinkStacks(self.Link(id))
    return (backpack or 0)+(bank or 0)+(virtual or 0)
end
function A:PrepareRefiningObservation()
    self.refiningBuild={inputs={},at=self.Now()}
end
function A:AddRefiningObservation(bag,slot,quantity)
    local b=self.refiningBuild
    if not b or b.invalid then return end
    local skill=GetCraftingInteractionType(); local key=self:RefiningCraftKey(skill)
    local link=GetItemLink(bag,slot,LINK_STYLE_DEFAULT or 0)
    local kind=GetItemLinkItemType(link)
    local core=kind==ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or kind==ITEMTYPE_CLOTHIER_RAW_MATERIAL
        or kind==ITEMTYPE_WOODWORKING_RAW_MATERIAL or kind==ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL
    -- ESO's own refinability check also accepts raw traits/style materials/grains.
    -- They must not poison a multi-item message containing ordinary ore/dust.
    if not key or not CanItemBeRefined(bag,slot,skill) then b.invalid=true; return end
    local id=self:RefiningMeta(link)
    if not id or not quantity or quantity<=0 then b.invalid=true; return end
    if b.key and b.key~=key then b.invalid=true; return end
    b.key=key; b.skill=skill
    local e=b.inputs[id] or {before=self:RefiningStock(id),requested=0}
    e.requested=e.requested+quantity
    local refined=GetItemLinkRefinedMaterialItemLink(link,LINK_STYLE_DEFAULT or 0)
    e.base=self.ValidId(GetItemLinkItemId(refined or ''))
    e.core=core
    if e.base then
        self:RefiningMeta(refined)
        e.convertsBooster=self:RefiningState().items[e.base].role=='booster'
    end
    b.inputs[id]=e
end
function A:StartRefiningObservation(skill)
    local b=self.refiningBuild; self.refiningBuild=nil
    self.refiningPending=nil
    if not b or b.invalid or b.skill~=skill or self.Now()-b.at>10 or not next(b.inputs) then return end
    -- Completion owns the result snapshot; an unrelated crafting event cannot reuse it.
    self.refiningPending=b
end
function A:CompleteRefiningObservation(skill)
    local b=self.refiningPending; self.refiningPending=nil
    if not b or b.skill~=skill then return end
    b.outputs={}
    for index=1,GetNumLastCraftingResultItemsAndPenalty() do
        local link=GetLastCraftingResultItemLink(index,LINK_STYLE_DEFAULT or 0)
        local _,_,count=GetLastCraftingResultItemInfo(index)
        local id=self:RefiningMeta(link)
        if id and count and count>0 then add(b.outputs,id,count) end
    end
    local epoch=self.refiningEpoch or 0
    local function settle(attempt)
        if epoch~=(self.refiningEpoch or 0) or b.finished then return end
        local consumed={}; local amount=0; local waiting=false
        for id,e in pairs(b.inputs) do
            local n=e.before-self:RefiningStock(id)
            local step=GetRequiredSmithingRefinementStackSize()
            if n<0 or n>e.requested or n%step~=0 then return end
            if n==0 then waiting=true end
            if n>0 then consumed[id]=n; amount=amount+n end
        end
        if amount==0 or waiting then
            if attempt<5 and zo_callLater then zo_callLater(function() settle(attempt+1) end,100) end
            return
        end
        b.finished=true
        self:RecordRefining(b.key,consumed,b.outputs,b.inputs)
    end
    settle(0)
end
function A:RecordRefining(key,inputs,outputs,details)
    local s=self:RefiningState()
    local current=group(s.current,key)
    local coreInputs=0; local bases={}; local convertedBooster=false
    for id,n in pairs(inputs) do
        add(current.inputs,id,n)
        if details[id].base then current.baseFor[id]=details[id].base end
        if details[id].core then
            coreInputs=coreInputs+n
            if details[id].base then bases[details[id].base]=true end
        elseif details[id].convertsBooster then convertedBooster=true end
    end
    for id,n in pairs(outputs) do add(current.outputs,id,n) end
    -- Lifetime yield is for raw ore/dust/cloth/hide/wood. Auxiliary conversions
    -- remain fully visible in Current, but cannot dilute these denominators.
    if coreInputs>0 then
        local total=group(s.total,key)
        if total.boosterInputs==nil then
            total.boosterInputs=0
            for _,n in pairs(total.inputs) do total.boosterInputs=total.boosterInputs+n end
        end
        for id,n in pairs(inputs) do
            if details[id].core then
                add(total.inputs,id,n); total.baseFor[id]=details[id].base
            end
        end
        if convertedBooster then
            total.excludedBoosterInputs=(total.excludedBoosterInputs or 0)+coreInputs
        else total.boosterInputs=total.boosterInputs+coreInputs end
        for id,n in pairs(outputs) do
            local item=s.items[id]
            if item and (item.role=='base' and bases[id] or item.role=='booster' and not convertedBooster) then
                add(total.outputs,id,n)
            end
        end
    end
    self.goldManualSelection=true; self:SelectActivity('refining'); self.goldManualSelection=nil
    self:QueueRefresh()
end
function A:ResetRefiningTotals()
    self:RefiningState().total=fresh(); self:QueueRefresh()
end
local reset=A.ResetSession
function A:ResetSession()
    self.refiningEpoch=(self.refiningEpoch or 0)+1
    self.refiningPending=nil; self.refiningBuild=nil
    reset(self); self:RefiningState().current=fresh()
end
-- Never let processing results leak into gathering or fishing.
local loot=A.Loot
function A:Loot(...)
    if self.refiningPending then return end
    return loot(self,...)
end
local init=A.Initialize
function A:Initialize()
    init(self); self:RefiningState()
    if SecurePostHook and PrepareDeconstructMessage and AddItemToDeconstructMessage then
        SecurePostHook(_G,'PrepareDeconstructMessage',function() self:PrepareRefiningObservation() end)
        SecurePostHook(_G,'AddItemToDeconstructMessage',function(bag,slot,n) self:AddRefiningObservation(bag,slot,n) end)
    end
    local ns='ALTHarvestItemsRefining'
    if EVENT_CRAFT_STARTED then EVENT_MANAGER:RegisterForEvent(ns,EVENT_CRAFT_STARTED,function(_,skill) self:StartRefiningObservation(skill) end) end
    if EVENT_CRAFT_COMPLETED then EVENT_MANAGER:RegisterForEvent(ns,EVENT_CRAFT_COMPLETED,function(_,skill) self:CompleteRefiningObservation(skill) end) end
    local function clear() self.refiningPending=nil; self.refiningBuild=nil end
    if EVENT_CRAFT_FAILED then EVENT_MANAGER:RegisterForEvent(ns,EVENT_CRAFT_FAILED,clear) end
    EVENT_MANAGER:RegisterForEvent(ns,EVENT_PLAYER_DEACTIVATED,function()
        clear(); self.refiningEpoch=(self.refiningEpoch or 0)+1
    end)
    ZO_Dialogs_RegisterCustomDialog('ALTHARVESTITEMS_REFINING_RESET',{
        title={text=self:T('REFINE_RESET_TOTAL')},mainText={text=self:T('REFINE_RESET_CONFIRM')},
        buttons={{text=self:T('RESET'),callback=function() self:ResetRefiningTotals() end},{text=self:T('CANCEL')}}})
end
