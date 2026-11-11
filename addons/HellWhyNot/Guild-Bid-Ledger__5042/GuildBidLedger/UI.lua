local A, WM = GuildBidLedger, WINDOW_MANAGER
local WIDTH, HEIGHT = 500, 770
local function label(parent,x,y,w,h,text,font)
    local c=WM:CreateControl(nil,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h)
    c:SetFont(font or "ZoFontGame");c:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    c:SetMaxLineCount(1);c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if text then c:SetText(text) end
    return c
end
local function tooltip(control,text)
    control.tip=text;control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter",function()
        local t=type(control.tip)=="function" and control.tip() or control.tip
        if not t or t=="" then return end
        InitializeTooltip(InformationTooltip,control,TOPRIGHT,0,0,TOPLEFT)
        InformationTooltip:AddLine(t,"ZoFontGame",1,1,1)
    end)
    control:SetHandler("OnMouseExit",function()ClearTooltip(InformationTooltip)end)
end
-- Do not recursively traverse ESO controls here. Some native controls report
-- child slots that resolve to nil; the old traversal crashed every refresh.
-- The resize-to-fit optimization is unnecessary for this fixed-size panel.
function A:Money(amount,exact)
    if not amount then return "—" end
    if exact then return ZO_CommaDelimitNumber(math.floor(amount+0.5)).." gold" end
    if amount>=1000000 then return string.format("%.2fM",amount/1000000) end
    if amount>=1000 then return string.format("%.1fK",amount/1000) end
    return tostring(math.floor(amount+0.5))
end
function A:Date(attempt)
    if not attempt.ending then return "Week unknown" end
    return (attempt.projected and "~ " or "")..GetDateStringFromTimestamp(attempt.ending)
end
function A:CreateUI()
    self.uiGeneration=(self.uiGeneration or 0)+1
    local prefix=self.name.."UI"..self.uiGeneration
    -- Root UI panels must be top-level windows. Ordinary children of GuiRoot
    -- can exist in Lua yet never render (especially while modal dialogs show).
    local p=WM:CreateTopLevelWindow(prefix.."Panel")
    p:SetDimensions(WIDTH,HEIGHT)
    p:SetMouseEnabled(true)
    p:SetMovable(false)
    p:SetDrawLayer(DL_OVERLAY)
    p:SetDrawTier(DT_HIGH)
    p:SetDrawLevel(90)
    p:SetHidden(true)
    local bg=WM:CreateControlFromVirtual(prefix.."Background",p,"ZO_DefaultBackdrop");bg:SetAnchorFill()
    self.panel=p
    label(p,18,14,464,30,"Guild Bid Ledger","ZoFontWinH3")
    self.heading=label(p,18,50,464,48,nil,"ZoFontGameBold");self.heading:SetMaxLineCount(2)
    self.latest=label(p,18,108,464,24,nil,"ZoFontGameBold")
    self.lastWin=label(p,18,138,464,24)
    label(p,18,176,220,20,"AVERAGE WON","ZoFontGameSmall")
    label(p,258,176,224,20,"AVERAGE UNSUCCESSFUL","ZoFontGameSmall")
    self.winAverage=label(p,18,198,220,28,nil,"ZoFontWinH3")
    self.lossAverage=label(p,258,198,224,28,nil,"ZoFontWinH3")
    self.range=label(p,18,235,464,24,nil,"ZoFontGameSmall")
    label(p,18,275,464,24,"Estimated competitive range","ZoFontGameBold")
    self.estimate=label(p,18,303,464,48);self.estimate:SetMaxLineCount(2)
    label(p,18,366,218,20,"Autofill amount (gold)","ZoFontGameSmall")
    label(p,258,366,224,20,"Default guild","ZoFontGameSmall")
    local eb=WM:CreateControlFromVirtual(prefix.."AmountBG",p,"ZO_EditBackdrop")
    eb:SetAnchor(TOPLEFT,p,TOPLEFT,18,390);eb:SetDimensions(218,30)
    local edit=WM:CreateControlFromVirtual(prefix.."Amount",eb,"ZO_DefaultEditForBackdrop")
    edit:SetMaxInputChars(10);edit:SetTextType(TEXT_TYPE_NUMERIC);edit:SetText(tostring(self.sv.amount))
    self.amountEdit=edit
    edit:SetHandler("OnFocusLost",function()
        local n=tonumber(edit:GetText());local previous=self.sv.amount
        if n and n==math.floor(n) and n>=1 and n<=2147483647 then self.sv.amount=n end
        edit:SetText(tostring(self.sv.amount))
        if self.context then self:TryFill(self.context,previous) end
        self:RefreshUI()
    end)
    -- ESO's native combo dropdown is a separate top-level control. Since our
    -- ledger is drawn over the modal bid dialogue, that dropdown can be behind
    -- this panel and become impossible to click. Use an in-panel picker instead.
    self.status=label(p,18,428,464,20,nil,"ZoFontGameSmall")
    label(p,18,468,264,24,"This trader’s attempts","ZoFontGameBold")
    local refresh=WM:CreateControlFromVirtual(prefix.."Refresh",p,"ZO_DefaultButton")
    refresh:SetAnchor(TOPLEFT,p,TOPLEFT,340,463);refresh:SetDimensions(142,30);refresh:SetText("Refresh history")
    refresh:SetHandler("OnClicked",function()
        edit:LoseFocus()
        if self.context then self:RequestHistory(self.context.guildId,true);self:RefreshUI() end
    end)
    label(p,18,505,140,22,"Week ending","ZoFontGameSmall")
    label(p,172,505,112,22,"Bid amount","ZoFontGameSmall")
    label(p,302,505,166,22,"Outcome","ZoFontGameSmall")
    self.list=WM:CreateControlFromVirtual(prefix.."History",p,"ZO_ScrollContainer")
    self.list:SetAnchor(TOPLEFT,p,TOPLEFT,18,533);self.list:SetDimensions(464,194)
    self.scroll=self.list:GetNamedChild("Scroll")
    self.child=self.scroll and self.scroll:GetNamedChild("Child")
    if not self.child then
        -- Fail visibly instead of aborting panel creation on template variations.
        self.child=WM:CreateControl(prefix.."RowsFallback",p,CT_CONTROL)
        self.child:SetAnchor(TOPLEFT,p,TOPLEFT,18,533)
    end
    if self.child.SetResizeToFitDescendents then self.child:SetResizeToFitDescendents(false) end
    self.child:SetDimensions(440,194)
    self.empty=label(p,18,540,438,84,nil,"ZoFontGame");self.empty:SetMaxLineCount(3)
    self.coverage=label(p,18,739,464,20,nil,"ZoFontGameSmall")
    tooltip(self.coverage,"Only delivered history is retained. A ~ date is projected from ESO's current seven-day auction cycle. Older schedule changes may affect week assignments. Inferred wins mean a placed bid has no recorded refund after settlement; missing history can cause false positives. Unknown attempts and direct/unverified hires are excluded from averages.")
    self.rows={}
    -- Build the popover last so ESO does not paint later sibling controls
    -- (history scrollbar, refresh button, labels) on top of its options.
    self:CreateDefaultGuildPicker(p,prefix)
    self.uiReady=true
end
function A:AttemptTooltip(b)
    local lines={self:Date(b).." • "..(b.inferred and "Won (inferred)" or b.outcome), self:Money(b.amount,true),b.reason}
    if b.snapshot then lines[#lines+1]="Native bid observed: "..GetDateStringFromTimestamp(b.snapshot.observed) end
    for _, r in ipairs(b.evidence) do
        lines[#lines+1]=GetDateStringFromTimestamp(r.time).." • "..r.kind.." • "..self:Money(r.amount,true).." • "..r.actor
    end
    return table.concat(lines,"\n\n")
end
function A:RefreshUI()
    if not self.context or not self.panel or not self.uiReady then return end
    local ctx=self.context
    local permitted=DoesPlayerHaveGuildPermission(ctx.guildId,GUILD_PERMISSION_GUILD_KIOSK_BID)
    local attempts=permitted and self:BuildAttempts(ctx.guildId,ctx.kiosk) or {}
    local s=self:AttemptSummary(attempts)
    self.heading:SetText(zo_strformat("<<1>>\n<<2>>",ctx.kiosk,GetGuildName(ctx.guildId)))
    self.latest:SetText(s.latest and ("Latest: "..(s.latest.inferred and "Won*" or s.latest.outcome).." • "..self:Money(s.latest.amount).." • "..self:Date(s.latest)) or "Last completed: —")
    tooltip(self.latest,s.latest and self:AttemptTooltip(s.latest) or "No classifiable completed attempt in delivered history.")
    self.lastWin:SetText(s.lastWin and ((s.lastWin.inferred and "Last inferred win: " or "Last won: ")..self:Money(s.lastWin.amount).." • "..self:Date(s.lastWin)) or "Last known win: —")
    tooltip(self.lastWin,s.lastWin and self:AttemptTooltip(s.lastWin) or "A hire without sufficient auction evidence remains Unknown.")
    self.winAverage:SetText(self:Money(s.winAverage).."  ("..s.wins..")")
    self.lossAverage:SetText(self:Money(s.lossAverage).."  ("..s.losses..")")
    tooltip(self.winAverage,self:Money(s.winAverage,true).."\nSample: "..s.wins.." winning or inferred-winning attempts ("..s.inferredWins.." inferred from no recorded refund). Missing refund history could overstate wins. Pending, unknown and direct rentals excluded.")
    tooltip(self.lossAverage,self:Money(s.lossAverage,true).."\nSample: "..s.losses.." unsuccessful attempts. Includes refunded backups, which need not have been outbid. Not a market-price estimate.")
    self.range:SetText("Our historical winning range: "..(s.minWin and (self:Money(s.minWin).." – "..self:Money(s.maxWin)) or "—"))
    tooltip(self.range,s.minWin and (self:Money(s.minWin,true).." to "..self:Money(s.maxWin,true)) or "Insufficient winning evidence.")
    local estimate={}
    if s.ceiling then estimate[#estimate+1]="Ceiling ≤ "..self:Money(s.ceiling.amount).." • "..self:Date(s.ceiling) end
    if s.floor then estimate[#estimate+1]="Floor ≥ "..self:Money(s.floor.amount).." • "..self:Date(s.floor) end
    self.estimate:SetText(#estimate>0 and table.concat(estimate,"\n") or "Insufficient evidence")
    local tip="Historical effective competition, not other guilds' private bid amounts or a promise of a future win. Floors are inclusive because tie priority may decide an equal bid. Allocation can remove higher competing bids awarded elsewhere.\n"
    if #s.bounds>0 then
        tip=tip..s.samples.." qualifying results in the last eight weeks. "..GetDateStringFromTimestamp(s.oldest).." to "..GetDateStringFromTimestamp(s.newest)..". Each bound applies to its own auction; different weeks are not one interval.\n"
        for _, b in ipairs(s.bounds) do tip=tip.."\n"..GetDateStringFromTimestamp(b.date).." • "..b.side.." • "..self:Money(b.amount,true) end
        if s.floor and s.ceiling and s.floor.amount>s.ceiling.amount then tip=tip.."\nBounds differ across weeks; competition varied. No combined range can be justified." end
    else tip=tip.."Projected weeks, ambiguous refunds, unverified hires and missing evidence cannot establish a reliable competing-price range." end
    tooltip(self.estimate,tip)
    self:RefreshDefaultGuildPicker()
    self.status:SetText(self.autofillStatus or "Saved amount fills eligible boxes. Review and submit yourself.")
    local loading=self.requests[ctx.guildId] or self.scanning[ctx.guildId]
    self.coverage:SetText(not permitted and "Guild bidding permission required." or (self.historyError and "History temporarily unavailable • /gbl debug for details" or (loading and "Loading available history…" or "Observed history • hover rows for evidence and limitations")))
    self.empty:SetHidden(#attempts>0)
    self.empty:SetText(not permitted and "Guild bidding permission required." or (loading and "Loading this trader’s available history…" or "No matching attempts received. Refresh history to request available records."))
    for i,b in ipairs(attempts) do
        local row=self.rows[i]
        if not row then
            local c=WM:CreateControl(nil,self.child,CT_CONTROL);c:SetDimensions(440,48);c:SetAnchor(TOPLEFT,self.child,TOPLEFT,0,(i-1)*48)
            row={control=c,date=label(c,0,0,146,24),amount=label(c,154,0,114,24,nil,"ZoFontGameBold"),outcome=label(c,284,0,156,24),note=label(c,0,25,440,18,nil,"ZoFontGameSmall")}
            self.rows[i]=row
            tooltip(c,function()return c.attempt and self:AttemptTooltip(c.attempt)end)
            for _,child in ipairs({row.date,row.amount,row.outcome,row.note}) do tooltip(child,function()return c.attempt and self:AttemptTooltip(c.attempt)end) end
        end
        row.control.attempt=b;row.control:SetHidden(false)
        row.date:SetText(self:Date(b));row.amount:SetText(self:Money(b.amount));row.outcome:SetText(b.inferred and "Won*" or b.outcome)
        local colors={Won={0.55,0.83,0.56,1},Unsuccessful={0.88,0.64,0.5,1},Pending={0.83,0.78,0.52,1},Unknown={0.65,0.65,0.65,1}}
        row.outcome:SetColor(unpack(colors[b.outcome] or colors.Unknown))
        row.note:SetText(b.rental and "Direct / unverified hire" or (b.inferred and "Inferred: no refund in saved history" or (b.outbid and "Outbid evidence" or (b.outcome=="Unsuccessful" and "Returned bid • reason may be uncertain" or (b.projected and "Estimated week • hover for evidence" or "Hover for evidence")))))
    end
    for i=#attempts+1,#self.rows do self.rows[i].control:SetHidden(true);self.rows[i].control.attempt=nil end
    self.child:SetHeight(math.max(194,#attempts*48))
end
function A:SetContext(object,guildId,mode)
    if not guildId then return end
    self:ObserveCycle()
    local kiosk=zo_strformat("<<1>>",GetUnitName("interact"))
    local changed=not self.context or self.context.guildId~=guildId or self.context.kiosk~=kiosk
    self.context={object=object,guildId=guildId,mode=mode,kiosk=kiosk}
    -- Keep this independent of the dialog's resize/visibility/layout lifecycle.
    self.panel:ClearAnchors()
    if not object or not object.control then
        self.panel:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-20,20)
        self.panel:SetHidden(false);self:RefreshUI();return
    end
    local space,right=GuiRoot:GetWidth()-object.control:GetRight()-32,true
    if object.control:GetLeft()-32>space then space=object.control:GetLeft()-32;right=false end
    if mode=="gamepad" then space=GuiRoot:GetWidth()*0.45;right=true end
    local heightScale=math.min(1,(GuiRoot:GetHeight()-32)/HEIGHT)
    local scale=math.min(1,space/WIDTH,heightScale)
    -- On narrower screens, a 10-30% panel is practically invisible.
    -- Instead use a readable overlay pinned to the screen's right edge.
    if mode=="gamepad" or scale < 0.65 then
        scale=math.min(0.85,heightScale,GuiRoot:GetWidth()/WIDTH)
        self.panel:SetScale(scale)
        self.panel:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-12,12)
    else
        self.panel:SetScale(scale)
        local y=math.max(-object.control:GetTop()+16,math.min(0,GuiRoot:GetHeight()-16-object.control:GetTop()-HEIGHT*scale))
        if right then self.panel:SetAnchor(TOPLEFT,object.control,TOPRIGHT,16,y)
        else self.panel:SetAnchor(TOPRIGHT,object.control,TOPLEFT,-16,y) end
    end
    if changed then
        if self.guildPickerPopup then self.guildPickerPopup:SetHidden(true) end
        if self.guildPickerArrow then self.guildPickerArrow:SetText("▼") end
        if self.scroll and self.scroll.SetVerticalScroll then self.scroll:SetVerticalScroll(0) end
        self:RequestHistory(guildId)
    end
    self:ObserveBid(self.context)
    self.panel:SetHidden(false);self:TryFill(self.context);self:RefreshUI()
end
-- In-panel selector: its popup stays on the same top-level window as the ledger.
-- It does not depend on ESO's independently layered combo-box dropdown.
function A:CreateDefaultGuildPicker(parent,prefix)
    local base=WM:CreateControlFromVirtual(prefix.."GuildPickerBG",parent,"ZO_EditBackdrop")
    base:SetAnchor(TOPLEFT,parent,TOPLEFT,258,390)
    base:SetDimensions(224,30)
    local trigger=WM:CreateControl(prefix.."GuildPickerButton",parent,CT_BUTTON)
    trigger:SetAnchorFill(base)
    trigger:SetMouseEnabled(true)
    trigger:SetDrawLayer(DL_OVERLAY)
    trigger:SetDrawLevel(110)
    self.guildPickerText=label(trigger,7,3,189,24,nil,"ZoFontGame")
    self.guildPickerArrow=label(trigger,200,3,20,24,"▼","ZoFontGameSmall")
    self.guildPickerArrow:SetColor(0.9,0.85,0.65,1)
    self.guildPickerText:SetDrawLayer(DL_OVERLAY)
    self.guildPickerText:SetDrawLevel(120)
    self.guildPickerArrow:SetDrawLayer(DL_OVERLAY)
    self.guildPickerArrow:SetDrawLevel(120)

    local popup=WM:CreateControl(prefix.."GuildPickerPopup",parent,CT_BACKDROP)
    popup:SetAnchor(TOPLEFT,parent,TOPLEFT,258,420)
    popup:SetDimensions(224,30)
    popup:SetCenterColor(0.045,0.045,0.045,0.98)
    popup:SetEdgeColor(0.7,0.66,0.45,1)
    popup:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,16)
    popup:SetDrawLayer(DL_OVERLAY)
    popup:SetDrawLevel(180)
    popup:SetMouseEnabled(true)
    popup:SetHidden(true)
    self.guildPickerPopup=popup
    self.guildPickerRows={}
    trigger:SetHandler("OnClicked",function()
        local opening=popup:IsHidden()
        if opening then self:PopulateDefaultGuilds() end
        popup:SetHidden(not opening)
        self.guildPickerArrow:SetText(opening and "▲" or "▼")
    end)
    self:RefreshDefaultGuildPicker()
end
function A:RefreshDefaultGuildPicker()
    if not self.guildPickerText then return end
    local id=self.sv.defaultGuildId
    self.guildPickerText:SetText((id and self:EligibleDefaultGuild(id) and GetGuildName(id)) or "No automatic switch")
end
function A:PopulateDefaultGuilds()
    if not self.guildPickerPopup then return end
    local choices={{name="No automatic switch",id=nil}}
    for i=1,GetNumGuilds() do
        local id=GetGuildId(i)
        if self:EligibleDefaultGuild(id) then
            choices[#choices+1]={name=GetGuildName(id),id=id}
        end
    end
    local popup=self.guildPickerPopup
    local rowHeight=30
    popup:SetHeight(#choices*rowHeight+4)
    for i,choice in ipairs(choices) do
        local row=self.guildPickerRows[i]
        if not row then
            row=WM:CreateControl(nil,popup,CT_BUTTON)
            row:SetAnchor(TOPLEFT,popup,TOPLEFT,2,2+(i-1)*rowHeight)
            row:SetDimensions(220,rowHeight)
            row:SetDrawLayer(DL_OVERLAY)
            row:SetDrawLevel(190)
            local textControl=label(row,7,3,206,24,nil,"ZoFontGame")
            textControl:SetDrawLayer(DL_OVERLAY)
            textControl:SetDrawLevel(200)
            row.textControl=textControl
            row:SetHandler("OnMouseEnter",function()row.textControl:SetColor(1,0.85,0.4,1)end)
            row:SetHandler("OnMouseExit",function()row.textControl:SetColor(1,1,1,1)end)
            self.guildPickerRows[i]=row
        end
        row:SetHidden(false)
        row.textControl:SetText(choice.name)
        row.textControl:SetColor(1,1,1,1)
        local guildId=choice.id
        row:SetHandler("OnClicked",function()
            self.sv.defaultGuildId=guildId
            popup:SetHidden(true)
            self.guildPickerArrow:SetText("▼")
            self:RefreshDefaultGuildPicker()
            if self.context and guildId then
                self:ApplyDefaultGuild(self.context.object,self.context.mode)
            end
            self:RefreshUI()
        end)
    end
    for i=#choices+1,#self.guildPickerRows do
        self.guildPickerRows[i]:SetHidden(true)
    end
end

-- Standalone UI test; displays even with no trader open and no history context.
function A:ShowPanelTest()
    if not self:EnsureUI() then
        d("GBL: Could not create panel. Use /gbl debug for the error.")
        return
    end
    self.panel:ClearAnchors()
    local scale=math.min(0.85,(GuiRoot:GetHeight()-32)/HEIGHT,GuiRoot:GetWidth()/WIDTH)
    self.panel:SetScale(scale)
    self.panel:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    self.panel:SetHidden(false)
    self.heading:SetText("UI TEST: panel rendered")
    self.latest:SetText("Window type: ESO top-level")
    self.lastWin:SetText("Open a trader to display historical bids.")
    self.status:SetText("/gbl hide closes this test window")
    self.empty:SetHidden(false)
    self.empty:SetText("If you can see this, window creation works.")
    d("GBL: UI test shown; visible="..tostring(not self.panel:IsHidden()))
end
