GridBagsDeliveryUI = {}
local U=GridBagsDeliveryUI
local I,R,P=GridBagsRoutingInsights,GridBagsRouting,GridBagsRoutingUI
function U:Close()
    if self.window then self.window:SetHidden(true);self.search:LoseFocus()end
end
function U:Show()
    if GridBagsRecipeGatherUI then GridBagsRecipeGatherUI:Close()end
    if GridBagsProtectionUI then GridBagsProtectionUI:Close() end
    GridBags:ReleaseSearchFocus();P:Close();GridBagsCraftingUI:Close();GridBagsToolsUI:Close();GridBagsGoldUI:Close()
    self.window:SetHidden(false);self:Update()
end
function U:Details(title,text)
    self:Close();GridBagsToolsUI:Show("history");GridBagsToolsUI:Text(title,text)
end
function U:Explain(rule)
    self:Details("RULE EXPLANATION",I:ExplainRule(rule))
end
function U:Update()
    if not self.window or self.window:IsHidden()then return end
    local entries,counts=I:Deliveries({query=self.search:GetText(),character=self.character,state=self.state})
    self.page=math.max(0,math.min(self.page or 0,math.max(0,math.ceil(#entries/6)-1)))
    self.summary:SetText((GridBagsActivity:IsPaused()and "TRANSFERS PAUSED | "or "")..string.format("%d matching deliveries | page %d\nAll routes: %d awaiting deposit; %d stored for pickup; %d need review; %d completed",#entries,self.page+1,counts.source,counts.bank,counts.review,counts.done))
    self.characterButton:SetText(self.character and R:Name(self.character)or "Any character")
    self.stateButton:SetText(self.state and I.states[self.state]or "All stages")
    for index,row in ipairs(self.rows)do
        local p=entries[self.page*6+index];row.button:SetHidden(not p);row.label:SetHidden(not p)
        if p then
            row.button:SetText(I.states[p.state]or p.state)
            row.label:SetText((p.name or p.link).." x"..(p.state=="done"and p.qty or p.remaining).." | "..R:Name(p.source).." > "..R:Name(p.dest).."\n"..I:Reason(p))
            row.button:SetHandler("OnClicked",function()self:Details("DELIVERY DETAILS",I:DeliveryDetails(p))end)
            GridBagsHelp:Bind(row.button,function()return I:DeliveryDetails(p)end)
        end
    end
end
function U:Initialize()
    self.window=P.MakeFrame("GridBagsDeliveryOverview",1000,720)
    P.MakeLabel(self.window,"DELIVERY OVERVIEW",20,12,820,"ZoFontWinH2")
    P.MakeButton(self.window,"Close",880,12,100,function()self:Close()end)
    self.search=P.MakeEdit(self.window,"Find item",20,60,"");self.search:SetMaxInputChars(100)
    self.search:SetHandler("OnTextChanged",function()self.page=0;self:Update()end)
    self.characterButton=P.MakeButton(self.window,"Any character",330,60,320,function(c)
        ClearMenu();AddMenuItem("Any character",function()ClearMenu();self.character=nil;self.page=0;self:Update()end)
        AddMenuItem("Account bank",function()ClearMenu();self.character=R.BANK;self.page=0;self:Update()end)
        local ids={};ids[R.character]=true
        for id in pairs(GridBagsSnapshots.records)do ids[id]=true end
        for _,p in ipairs(R.data.plans)do ids[p.source]=true;ids[p.dest]=true end
        local list={};for id in pairs(ids)do if id~=R.BANK then list[#list+1]=id end end
        table.sort(list,function(a,b)return R:Name(a)<R:Name(b)end)
        for _,id in ipairs(list)do local value=id;AddMenuItem(R:Name(id),function()ClearMenu();self.character=value;self.page=0;self:Update()end)end
        ShowMenu(c)
    end)
    self.stateButton=P.MakeButton(self.window,"All stages",670,60,310,function(c)
        ClearMenu();AddMenuItem("All stages",function()ClearMenu();self.state=nil;self.page=0;self:Update()end)
        for _,key in ipairs({"source","bank","review","done","cancelled"})do local state=key;AddMenuItem(I.states[state],function()ClearMenu();self.state=state;self.page=0;self:Update()end)end
        ShowMenu(c)
    end)
    self.summary=P.MakeLabel(self.window,"",20,105,950)
    self.rows={}
    for index=1,6 do
        local y=165+(index-1)*73
        local row={button=P.MakeButton(self.window,"Details",20,y,200,function()end),label=P.MakeLabel(self.window,"",240,y,735,"ZoFontGameSmall")}
        row.label:SetDimensions(735,66);row.label:SetMaxLineCount(3);row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS);self.rows[index]=row
    end
    P.MakeButton(self.window,"Previous",20,625,130,function()self.page=math.max(0,(self.page or 0)-1);self:Update()end)
    P.MakeButton(self.window,"Next",165,625,130,function()self.page=(self.page or 0)+1;self:Update()end)
    P.MakeButton(self.window,"Refresh",310,625,150,function()self:Update()end)
    P.MakeButton(self.window,"Routing planner",480,625,230,function()self:Close();P:Show()end)
    P.MakeButton(self.window,"Transfer log",730,625,240,function()self:Close();GridBagsToolsUI:Show("history")end)
    P.MakeLabel(self.window,"Item routes and last recorded reasons; Preview rechecks the current visit. Gold is in the log. Review can mean an uncertain move. Completed records do not track current ownership.",20,670,950,"ZoFontGameSmall")
    GridBagsHelp:Bind(self.search,"Search saved item deliveries by item name or link text. This filters the list without changing plans or searching live inventory.")
    GridBagsHelp:Bind(self.characterButton,"Show routes where the selected character is either the source or destination. Characters without a current snapshot can still appear if a saved delivery refers to them.")
    GridBagsHelp:Bind(self.stateButton,"Filter by transfer stage. Stored for pickup is reserved bank stock; Needs review means an outcome or reservation needs inspection.")
end
