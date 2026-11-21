GridBagsProtectionUI = {}
local U=GridBagsProtectionUI
local R,P=GridBagsRouting,GridBagsRoutingUI

function U:ItemName(link)
    if GetItemLinkName then
        local name=GetItemLinkName(link)
        if name and name~=""then return zo_strformat(SI_TOOLTIP_ITEM_NAME,name)end
    end
    return link
end
function U:Entries(source,query)
    local entries={};query=zo_strlower(query or "")
    for id,list in pairs(R.data.protections)do
        if not source or source==id then
            for link,guard in pairs(list)do
                local name=self:ItemName(link)
                if (guard.blocked or (guard.keep or 0)>0)and (query==""or zo_strlower(name):find(query,1,true)or zo_strlower(link):find(query,1,true))then
                    entries[#entries+1]={source=id,link=link,name=name,blocked=guard.blocked==true,keep=guard.keep or 0}
                end
            end
        end
    end
    table.sort(entries,function(a,b)
        if a.source~=b.source then return R:Name(a.source)<R:Name(b.source)end
        return a.name==b.name and a.link<b.link or a.name<b.name
    end)
    return entries
end
function U:Close()
    if self.window then self.window:SetHidden(true);self.editor:SetHidden(true);self.search:LoseFocus();self.keep:LoseFocus()end
end
function U:Show()
    if GridBagsRecipeGatherUI then GridBagsRecipeGatherUI:Close()end
    GridBags:ReleaseSearchFocus();P:Close();GridBagsCraftingUI:Close();GridBagsDeliveryUI:Close();GridBagsToolsUI:Close();GridBagsGoldUI:Close()
    self.editor:SetHidden(true);self.window:SetHidden(false);self:Update()
end
function U:Update()
    if not self.window or self.window:IsHidden()then return end
    local entries=self:Entries(self.source,self.search:GetText())
    self.page=math.max(0,math.min(self.page or 0,math.max(0,math.ceil(#entries/6)-1)))
    self.summary:SetText((GridBagsActivity:IsPaused()and "TRANSFERS PAUSED | "or "")..#entries.." protections | page "..(self.page+1).."\nNever export blocks an item; Keep retains a minimum. These override rule approvals.")
    self.sourceButton:SetText(self.source and R:Name(self.source)or "All protection sources")
    for index,row in ipairs(self.rows)do
        local entry=entries[self.page*6+index];row.button:SetHidden(not entry);row.label:SetHidden(not entry)
        if entry then
            row.label:SetText(entry.name.." | "..R:Name(entry.source).."\n"..(entry.blocked and "Never export: ON"or "Never export: off").." | Keep "..entry.keep.." units")
            row.button:SetHandler("OnClicked",function()self:Edit(entry)end)
            GridBagsHelp:Bind(row.button,"Edit or remove this source's exact-item transfer protection. This affects all matching rules; other characters' protections and ESO item locks are separate.")
        end
    end
end
function U:Edit(entry)
    self.selected=entry;local guard=R:Protection(entry.source,entry.link)
    self.blocked=guard.blocked==true;self.keep:SetText(tostring(guard.keep or 0))
    self.title:SetText(entry.name.."\n"..R:Name(entry.source));self.error:SetText("")
    self.toggle:SetText(self.blocked and "Never export: ON"or "Never export: off")
    self.window:SetHidden(true);self.editor:SetHidden(false)
end
function U:Save(remove)
    if R.pending then self.error:SetText("Wait for the current item transfer to settle.");return end
    local entry=self.selected;if not entry then return end
    local ok,err
    if remove then ok,err=R:RemoveProtection(entry.source,entry.link)
    else ok,err=R:SetProtection(entry.source,entry.link,self.blocked,self.keep:GetText())end
    if not ok then self.error:SetText(err);return end
    GridBagsActivity:Append({kind="control",outcome="control",code=remove and "PROTECTION_REMOVED"or "PROTECTION_UPDATED",
        reason=remove and "Transfer protection removed; existing item locks and other sources remain protected"or "Transfer protection updated",source=entry.source,item=entry.name})
    self.keep:LoseFocus();self.editor:SetHidden(true);self.window:SetHidden(false);self:Update();R:Notify()
end
function U:Initialize()
    self.window=P.MakeFrame("GridBagsProtectionList",920,720)
    P.MakeLabel(self.window,"PROTECTED ITEMS / SOURCE RESERVES",20,12,770,"ZoFontWinH2")
    P.MakeButton(self.window,"Close",800,12,100,function()self:Close()end)
    self.sourceButton=P.MakeButton(self.window,"All protection sources",20,55,390,function(c)
        ClearMenu();AddMenuItem("All protection sources",function()ClearMenu();self.source=nil;self.page=0;self:Update()end)
        local sources={};for id in pairs(R.data.protections)do sources[#sources+1]=id end
        table.sort(sources,function(a,b)return R:Name(a)<R:Name(b)end)
        for _,id in ipairs(sources)do local key=id;AddMenuItem(R:Name(id),function()ClearMenu();self.source=key;self.page=0;self:Update()end)end;ShowMenu(c)
    end)
    self.search=P.MakeEdit(self.window,"Find item",440,55,"");self.search:SetMaxInputChars(100)
    self.search:SetHandler("OnTextChanged",function()self.page=0;self:Update()end)
    self.summary=P.MakeLabel(self.window,"",20,105,880)
    self.rows={}
    for index=1,6 do
        local y=160+(index-1)*70
        self.rows[index]={button=P.MakeButton(self.window,"Edit / remove",20,y,180,function()end),label=P.MakeLabel(self.window,"",220,y,680,"ZoFontGameSmall")}
        self.rows[index].label:SetDimensions(680,65);self.rows[index].label:SetMaxLineCount(3);self.rows[index].label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    P.MakeButton(self.window,"Previous",20,615,130,function()self.page=math.max(0,(self.page or 0)-1);self:Update()end)
    P.MakeButton(self.window,"Next",165,615,130,function()self.page=(self.page or 0)+1;self:Update()end)
    P.MakeButton(self.window,"Pause / resume transfers",315,615,290,function()GridBagsActivity:SetPaused(not GridBagsActivity:IsPaused());self:Update()end)
    P.MakeButton(self.window,"Recipe holds...",625,615,275,function(c)GridBagsRecipeGatherUI:Show();GridBagsRecipeGatherUI:Requests(GridBagsRecipeGatherUI.recipeButton)end)
    P.MakeLabel(self.window,"Removing protection can allow approved queued moves after their next live check. Pause first if reviewing rules. This list does not unlock ESO-locked items or clear uncertain transfer holds.",20,665,880,"ZoFontGameSmall")
    self.editor=P.MakeFrame("GridBagsProtectionEditor",680,390)
    self.title=P.MakeLabel(self.editor,"",20,12,640,"ZoFontWinH3")
    self.toggle=P.MakeButton(self.editor,"Never export",20,95,640,function()self.blocked=not self.blocked;self.toggle:SetText(self.blocked and "Never export: ON"or "Never export: off")end)
    self.keep=P.MakeEdit(self.editor,"Keep units on source",20,145,0)
    P.MakeButton(self.editor,"Save protection",20,200,300,function()self:Save(false)end)
    P.MakeButton(self.editor,"Remove protection",345,200,315,function()self:Save(true)end)
    P.MakeButton(self.editor,"Back",20,250,640,function()self.keep:LoseFocus();self.editor:SetHidden(true);self.window:SetHidden(false);self:Update()end)
    self.error=P.MakeLabel(self.editor,"",20,300,640)
    GridBagsHelp:Bind(self.search,"Find effective Never export blocks or Keep reserves by item name or exact-link text, including items absent from your current bag.")
    GridBagsHelp:Bind(self.sourceButton,"Filter by the character or account bank whose exports are protected. Any-source rules obey each of these concrete sources' protections.")
    GridBagsHelp:Bind(self.toggle,"Never export prevents every matching planned move from this source. Turning it off still preserves the Keep amount; Remove protection clears both for this source only.")
end
