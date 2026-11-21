GridBagsRecipeGatherUI = {}
local U=GridBagsRecipeGatherUI
local Q,R,P=GridBagsRecipeGather,GridBagsRouting,GridBagsRoutingUI

function U:Close()
    if self.window then self.window:SetHidden(true);self.batches:LoseFocus();self.search:LoseFocus()end
    if self.ownsPause then self.ownsPause=false;P.editingSession=false;R:Notify()end
end
function U:Show(list,index,batches)
    GridBags:ReleaseSearchFocus();P:Close();GridBagsCraftingUI:Close();GridBagsToolsUI:Close();GridBagsDeliveryUI:Close();GridBagsProtectionUI:Close();GridBagsGoldUI:Close();self:Close()
    self.allowCrafting=not GridBags:IsActive();self.ownsPause=true;P.editingSession=true
    self.list,self.index=list,index;self.page=0;self.mode="needs";self.draft=nil
    self.batches:SetText(tostring(batches and math.max(1,batches)or 1));self.search:SetText("")
    self.window:SetHidden(false);R:Notify()
    if list and index then self:Refresh()else self.status:SetText("Choose a known recipe, optionally search by name, then Refresh preview. Unknown recipes cannot be gathered.");self:Update()end
end
function U:SelectRecipe(button)
    ClearMenu();local query=zo_strlower(self.search:GetText());local count=0
    if not GetNumRecipeLists or not GetRecipeListInfo then self.status:SetText("Recipe catalogue is unavailable.");return end
    for list=1,GetNumRecipeLists()do
        local _,n=GetRecipeListInfo(list)
        for index=1,n do
            local known,name=GetRecipeInfo(list,index)
            if known and (query==""or zo_strlower(name):find(query,1,true))then
                local l,r=list,index
                AddMenuItem(name,function()ClearMenu();self.list,self.index=l,r;self:Refresh()end)
                count=count+1;if count>=100 then break end
            end
        end
        if count>=100 then break end
    end
    if count==0 then AddMenuItem("No learned recipe matches this search",function()end)end
    ShowMenu(button)
end
function U:Refresh()
    self.draft=nil;self.page=0;self.ingredientFilter=nil
    local draft,reason=Q:Preview(self.list,self.index,tonumber(self.batches:GetText()))
    self.draft=draft
    self.status:SetText(draft and "Review Needs and Transfers. Uncheck unwanted sources; confirm only the selected named deliveries. Missing quantities remain unfilled."or reason)
    self:Update()
end
function U:Update()
    if not self.window or self.window:IsHidden()then return end
    local draft=self.draft;local entries=draft and (self.mode=="needs"and draft.rows or draft.proposals)or {}
    if self.mode=="transfers"and self.ingredientFilter then local filtered={};for _,p in ipairs(entries)do if p.ingredient==self.ingredientFilter then filtered[#filtered+1]=p end end;entries=filtered end
    self.page=math.max(0,math.min(self.page or 0,math.max(0,math.ceil(#entries/6)-1)))
    self.confirm:SetEnabled(draft~=nil)
    self.recipeButton:SetText(draft and draft.recipe.name or "Choose known recipe...")
    local n,units,missing=0,0,0
    if draft then
        for _,p in ipairs(draft.proposals)do if p.include~=false then n=n+1;units=units+p.qty end end
        for _,row in ipairs(draft.rows)do
            local selected=0;for _,p in ipairs(draft.proposals)do if p.ingredient==row.id and p.include~=false then selected=selected+p.qty end end
            missing=missing+math.max(0,row.needed-row.have-row.incoming-row.held-selected)
        end
    end
    self.summary:SetText(draft and string.format("%s | %d batches | %d selected deliveries / %d units | %d unfilled units\n%s | page %d | %d unavailable source observations",R:Name(draft.target),draft.recipe.batches,n,units,missing,self.mode,self.page+1,#draft.notices)or "No approved transfers. Preview only.")
    for index,row in ipairs(self.rows)do
        local entry=entries[self.page*6+index];row.button:SetHidden(not entry);row.label:SetHidden(not entry)
        if entry and self.mode=="needs"then
            local selected=0;for _,p in ipairs(draft.proposals)do if p.ingredient==entry.id and p.include~=false then selected=selected+p.qty end end
            row.button:SetText("Sources")
            row.label:SetText(entry.name.." | Need "..entry.needed.." | have "..entry.have.." | incoming "..entry.incoming.." | on hold "..entry.held..
                "\nSelected transfers "..selected.." | unfilled "..math.max(0,entry.needed-entry.have-entry.incoming-entry.held-selected).." | backpack "..entry.backpack.." / craft bag "..entry.craftBag.." / other recipe holds "..entry.otherRecipeHold)
            row.button:SetHandler("OnClicked",function()self.mode="transfers";self.ingredientFilter=entry.id;self.page=0;self:Update()end)
        elseif entry then
            row.button:SetText(entry.include~=false and "Included: ON"or "Excluded")
            row.label:SetText(entry.name.." x"..entry.qty.." | "..R:Name(entry.source).." > "..R:Name(entry.dest)..
                "\n"..(entry.source==R.BANK and (entry.live and "Live bank stock"or "Saved bank stock; unverified until bank visit")or "Saved backpack; source character must visit its bank").." | observed "..math.max(0,math.floor((GetTimeStamp()-entry.observedAt)/60)).." min ago")
            row.button:SetHandler("OnClicked",function()entry.include=entry.include==false;self:Update()end)
        end
    end
end
function U:Confirm()
    if not self.draft then return end
    if tonumber(self.batches:GetText())~=self.draft.recipe.batches then self.draft=nil;self.status:SetText("Batch count changed. Refresh and review before confirming.");self:Update();return end
    local request,reason=Q:Commit(self.draft)
    if not request then self.status:SetText(reason);return end
    self.draft=nil;self:Update()
    self.status:SetText("Confirmed "..#request.plans.." named deliveries for "..request.recipe.name..". Close this window; execute on the required bank visits (close/reopen an already open bank). Ingredients are held against exports until you release the request after crafting.")
end
function U:Requests(button)
    ClearMenu();local requests={}
    for _,request in pairs(R.data.gatherRequests or {})do if request.target==R.character and not request.closed then requests[#requests+1]=request end end
    table.sort(requests,function(a,b)return a.id>b.id end)
    for _,request in ipairs(requests)do
        local value=request
        AddMenuItem("Release ingredient hold: "..request.recipe.name.." ("..request.recipe.batches.." batches)",function()
            Q:CloseRequest(value.id);ClearMenu();self.draft=nil;self.status:SetText("Ingredient hold released. Already confirmed deliveries remain; cancel individual unwanted moves in the routing planner.");self:Update()
        end)
    end
    if #requests==0 then AddMenuItem("No active ingredient holds for this character",function()end)end
    ShowMenu(button)
end
function U:NativeSelected()
    local provider=PROVISIONER
    if not provider or not provider.GetSelectedRecipeListIndex or not provider.GetSelectedRecipeIndex then return nil end
    local list,index=provider:GetSelectedRecipeListIndex(),provider:GetSelectedRecipeIndex()
    local batches=provider.GetMultiCraftNumIterations and provider:GetMultiCraftNumIterations()or 1
    return list,index,math.max(1,batches or 1)
end
function U:AttachNative()
    local provider=PROVISIONER
    if provider and provider.control and provider.GetSelectedRecipeListIndex and not self.nativeButton then
        self.nativeButton=P.MakeButton(provider.control,"Gather ingredients...",0,0,240,function()
            local list,index,batches=self:NativeSelected();self:Show(list,index,batches)
        end)
        self.nativeButton:ClearAnchors();self.nativeButton:SetAnchor(BOTTOMLEFT,provider.control,BOTTOMLEFT,35,-75)
        local function Refresh()
            local list,index,batches=self:NativeSelected();local recipe=Q:Read(list,index,batches)
            self.nativeButton:SetEnabled(recipe~=nil)
        end
        if SecurePostHook and provider.RefreshRecipeDetails then SecurePostHook(provider,"RefreshRecipeDetails",Refresh)end
        Refresh()
    end
    local cs=CraftStoreFixedAndImprovedLongClassName
    if cs and cs.CookShowRecipe and SecurePostHook and not self.craftStoreHook then
        self.craftStoreHook=true
        SecurePostHook(cs,"CookShowRecipe",function(control,list,index)
            if not control then return end
            if not control.gridBagsGatherButton then
                control.gridBagsGatherButton=P.MakeButton(control,"G",0,0,28,function(c)self:Show(c.recipeList,c.recipeIndex,1)end)
                control.gridBagsGatherButton:ClearAnchors();control.gridBagsGatherButton:SetAnchor(RIGHT,control,RIGHT,-2,0)
                GridBagsHelp:Bind(control.gridBagsGatherButton,"Gather ingredients for this specific learned CraftStore recipe. Shows requirements and source proposals first; does not craft or authorize transfers until confirmed.")
            end
            local button=control.gridBagsGatherButton;button.recipeList,button.recipeIndex=list,index
            local known=GetRecipeInfo(list,index);button:SetHidden(not known)
        end)
    end
end
function U:Initialize()
    self.window=P.MakeFrame("GridBagsRecipeGatherWindow",1040,760)
    P.MakeLabel(self.window,"GATHER SELECTED RECIPE INGREDIENTS",20,12,880,"ZoFontWinH2")
    P.MakeButton(self.window,"Close",920,12,100,function()self:Close()end)
    self.recipeButton=P.MakeButton(self.window,"Choose known recipe...",20,55,600,function(c)self:SelectRecipe(c)end)
    self.batches=P.MakeEdit(self.window,"Crafting batches",650,55,1)
    self.search=P.MakeEdit(self.window,"Recipe search",20,100,"");self.search:SetMaxInputChars(100)
    P.MakeButton(self.window,"Refresh preview",350,100,230,function()self:Refresh()end)
    P.MakeButton(self.window,"Needs / transfers",600,100,200,function()self.mode=self.mode=="needs"and "transfers"or "needs";self.ingredientFilter=nil;self.page=0;self:Update()end)
    P.MakeButton(self.window,"Requests / release",815,100,205,function(c)self:Requests(c)end)
    self.summary=P.MakeLabel(self.window,"",20,145,1000,"ZoFontGameSmall")
    self.rows={}
    for index=1,6 do
        local y=205+(index-1)*64
        self.rows[index]={button=P.MakeButton(self.window,"Sources",20,y,165,function()end),label=P.MakeLabel(self.window,"",205,y,815,"ZoFontGameSmall")}
        self.rows[index].label:SetDimensions(815,61);self.rows[index].label:SetMaxLineCount(3);self.rows[index].label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    P.MakeButton(self.window,"Previous",20,600,140,function()self.page=math.max(0,(self.page or 0)-1);self:Update()end)
    P.MakeButton(self.window,"Next",175,600,140,function()self.page=(self.page or 0)+1;self:Update()end)
    P.MakeButton(self.window,"Unavailable sources",330,600,280,function(c)
        ClearMenu();for _,note in ipairs(self.draft and self.draft.notices or {})do AddMenuItem(note,function()end)end
        if not self.draft or #self.draft.notices==0 then AddMenuItem("No missing/stale tracked source observations",function()end)end;ShowMenu(c)
    end)
    self.confirm=P.MakeButton(self.window,"Confirm selected transfers",660,600,360,function()self:Confirm()end)
    self.status=P.MakeLabel(self.window,"",20,650,1000,"ZoFontGameSmall");self.status:SetDimensions(1000,90)
    GridBagsHelp:Bind(self.confirm,"Explicitly approve only included source stacks and named quantities. Rechecks the recipe and availability before saving. Sources offline wait for their bank visits; no crafting or item use is triggered.")
    GridBagsHelp:Bind(self.batches,"Number of recipe crafting batches, not the number of output items after crafting passives. Ingredient needs are multiplied by this value. Refresh after changing it.")
    self:AttachNative()
    if EVENT_CRAFTING_STATION_INTERACT then EVENT_MANAGER:RegisterForEvent("GridBagsGather",EVENT_CRAFTING_STATION_INTERACT,function()self:AttachNative();Q:RefreshProofs()end)end
    if EVENT_END_CRAFTING_STATION_INTERACT then EVENT_MANAGER:RegisterForEvent("GridBagsGather",EVENT_END_CRAFTING_STATION_INTERACT,function()self:Close()end)end
    EVENT_MANAGER:RegisterForEvent("GridBagsGather",EVENT_PLAYER_ACTIVATED,function()Q:RefreshProofs();self:AttachNative()end)
end
