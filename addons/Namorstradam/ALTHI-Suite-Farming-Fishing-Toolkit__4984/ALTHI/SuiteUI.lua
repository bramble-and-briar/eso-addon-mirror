-- Suite presentation; underlying resource/fishing activity and saved cash stay intact.
local A=ALTHarvestItems
local function L(key) return A:T(key) end
local function icon(path) return '|t22:22:'..path..'|t' end
local inventory='EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds'
local bank='EsoUI/Art/Icons/servicemappins/servicepin_bank.dds'
local account='EsoUI/Art/MainMenu/menubar_character_up.dds'
local mail='EsoUI/Art/Mail/mail_inbox_unreadMessage.dds'
local function signed(n) return (n>0 and '|c44CC66+' or n<0 and '|cDD5555−' or '')..A.Gold(math.abs(n))..(n~=0 and '|r' or '') end
local function place(control,parent,x,y,w,h,text,font)
    control:ClearAnchors(); control:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); control:SetDimensions(w,h)
    if font then control:SetFont(font) end
    if text then control:SetText(text) end
end
local header=A.RefreshGoldHeader
function A:RefreshGoldHeader()
    header(self)
    if not self.goldHeaderLabels or self.db.ui.activity~='gold' then return end
    local g=self:GoldState(); local c=g.characters[self:GoldCharacterId()]
    local values={c and self.Gold(c.balance) or '—',g.bankKnown and self.Gold(g.bank) or '—',self.Gold(self:GoldWealth())}
    local icons={inventory,bank,account}; local tips={'GOLD_WALLET','GOLD_BANK_SHORT','GOLD_ACCOUNT_TOTAL'}
    local available=self.window:GetWidth()-48; local x=18
    local _,known,total=self:GoldWealth()
    for i=1,3 do
        local label=self.goldHeaderLabels[i]
        local width=available*({0.31,0.25,0.44})[i]
        local count=i==3 and (' ('..known..'/'..total..')') or ''
        place(label,self.window,x,60,width,22,icon(icons[i])..count..' '..values[i],'ZoFontWinT2')
        x=x+width+6
        if label:GetStringWidth(label:GetText())>width then label:SetFont('ZoFontGameSmall') end
        label:SetMouseEnabled(true); label.althiTip=i==3 and L('SUITE_CAPTURED_CHARACTERS') or L(tips[i])..': '..values[i]
        label:SetHandler('OnMouseEnter',function(control) if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(control,TOP,control.althiTip) end end)
        label:SetHandler('OnMouseExit',function() if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end end)
    end
    local money=self:GoldInboxAmount(); local text=L('SUITE_NO_POST')
    if (money and money>0) or self:GoldHasMailNotice() then
        text=icon(mail)..' '..L('SUITE_HAVE_POST')..(money and money>0 and ' · '..self.Gold(money) or '')
    end
    place(self.goldHeaderLabels[4],self.window,18,84,self.window:GetWidth()-36,22,text,'ZoFontWinT2')
end
local tableTop=A.TableTop
function A:TableTop() return tableTop(self)+(self.db.ui.activity=='resources' and 38 or 0) end
local toolsTop=A.FishingToolsTop
function A:FishingToolsTop() return toolsTop(self)+38 end
function A:SuiteRows()
    local rows={}; local mode=self.db.ui.goldTab or 'overview'; local g=self:GoldState()
    local function add(label,value) rows[#rows+1]={label=label,value=value} end
    if mode=='characters' then
        local c=g.characters[self.db.ui.goldCharacter or self:GoldCharacterId()]
        if not c then add(L('GOLD_NOT_VISITED')); return rows end
        add(L('GOLD_CHARACTER_MOVEMENTS'))
        local keys={}
        for key,v in pairs(c.categories) do
            if key~='GOLD_GUILD_SALE' and key~='GOLD_GUILD_BUY' and key~='GOLD_LISTING' and key~='GOLD_REFUND'
                and (v.income>0 or v.expenses>0) then keys[#keys+1]=key end
        end
        table.sort(keys,function(a,b) return L(a)<L(b) end)
        for _,key in ipairs(keys) do
            local v=c.categories[key]
            if key=='GOLD_VENDOR' then
                if v.income>0 then add(L('GOLD_NPC_SALES'),signed(v.income)) end
                if v.expenses>0 then add(L('GOLD_NPC_BUYS'),signed(-v.expenses)) end
            else add(L(key),(v.income>0 and signed(v.income) or '')..(v.income>0 and v.expenses>0 and ' / ' or '')..(v.expenses>0 and signed(-v.expenses) or '')) end
        end
    else
        local summary=self:GoldTradeSummary()
        if summary.unavailable then add(L('GOLD_WEEK_UNAVAILABLE')); return rows end
        add(L('GOLD_TRADES_ACCOUNT'),signed(summary.value))
        add(L('GOLD_GUILD_BUY'),signed(-summary.costs))
        add(L('GOLD_TRADE_BALANCE'),signed(summary.value+summary.refunds-summary.costs-summary.fees))
        local list={}; for id,row in pairs(self:GoldGuildMetrics(summary)) do row.guildKey=id; list[#list+1]=row end
        table.sort(list,function(a,b) return (a.name or '')<(b.name or '') end)
        for _,row in ipairs(list) do
            rows[#rows+1]={heading=(row.name or L('GOLD_UNKNOWN_GUILD'))..' · '..signed(row.amount),guildKey=row.guildKey}
            if not self.db.ui.goldGuildClosed or not self.db.ui.goldGuildClosed[row.guildKey] then
                rows[#rows+1]={columns={L('GOLD_GROSS'),L('GOLD_GUILD_TAX'),L('GOLD_NET')}}
                rows[#rows+1]={columns={row.grossMissing and '—' or self.Gold(row.gross),row.taxMissing and '—' or self.Gold(row.tax),self.Gold(row.amount)}}
            end
            rows[#rows+1]={guildEnd=true}
        end
    end
    return rows
end
function A:RefreshSuiteGold()
    if not self.suiteGoldRows then return end
    local panel=self.goldPanel; local width=self.window:GetWidth()-36; local mode=self.db.ui.goldTab or 'overview'
    for i,button in ipairs(self.goldTabs) do
        place(button,panel,(i-1)*(width+6)/2,0,(width-6)/2,30,nil,'ZoFontWinT2')
        button:SetHidden(false); button:SetAlpha(mode==({'overview','characters'})[i] and 1 or 0.55)
    end
    self.goldHero:SetHidden(true)
    for _,label in ipairs(self.goldLines) do label:SetHidden(true) end
    for _,label in ipairs(self.goldValues) do label:SetHidden(true) end
    local c=self:GoldState().characters[self.db.ui.goldCharacter or self:GoldCharacterId()]
    self.goldChoose:SetText(c and c.name or L('GOLD_CHOOSE_CHARACTER')); self.goldChoose:SetHidden(mode~='characters')
    self.goldChoose:SetWidth(math.min(280,width-40))
    self.goldPeriodButton:SetHidden(mode~='overview'); self.goldPeriodButton:SetWidth(width-40)
    self.goldPeriodButton:SetText(L('SUITE_TRADE_DATA')..' · '..L(self:GoldPeriodKey()))
    self.goldExpand:SetHidden(true); self.goldExpand:ClearAnchors()
    self.goldExpand:SetAnchor(BOTTOMLEFT,panel,BOTTOMLEFT,0,0); self.goldExpand:SetWidth((width-12)*2/3)
    self.goldExpand:SetText(L(self.db.ui.goldShowDetails and 'GOLD_HIDE_DETAILS' or 'GOLD_SHOW_DETAILS'))
    for _,button in ipairs(self.goldActions) do button:SetHidden(true) end
    if mode=='overview' then
        local reset=self.goldActions[1]; reset:SetHidden(false); reset:ClearAnchors()
        reset:SetAnchor(BOTTOMRIGHT,panel,BOTTOMRIGHT,0,0); reset:SetWidth((width-12)/3)
    end
    local top=78
    for _,label in pairs(self.suiteCharacterLabels) do label:SetHidden(mode~='characters') end
    if mode=='characters' then
        local labels=self.suiteCharacterLabels; local income,expenses=self:GoldPersonalTotals(c)
        place(labels.wallet,panel,6,78,width-30,28,L('GOLD_WALLET')..': '..(c and self.Gold(c.balance) or '—'),'ZoFontGameBold')
        local money=self:GoldInboxAmount(); local post=''
        if (money and money>0) or self:GoldHasMailNotice() then post=icon(mail)..' '..L('SUITE_HAVE_POST')..(money and money>0 and ' · '..self.Gold(money) or '') end
        place(labels.post,panel,6,111,width-30,24,post,'ZoFontWinT2'); labels.post:SetHidden(post=='')
        local third=(width-30)/3
        for i,spec in ipairs({{'income',L('GOLD_INCOME'),signed(income)},{'expenses',L('GOLD_EXPENSES'),signed(-expenses)},{'balance',L('GOLD_PERSONAL_BALANCE'),signed(income-expenses)}}) do
            place(labels[spec[1]..'Title'],panel,6+(i-1)*third,145,third,24,spec[2],'ZoFontWinT2')
            place(labels[spec[1]],panel,6+(i-1)*third,171,third,28,c and spec[3] or '—','ZoFontGameBold')
        end
        top=216
    end
    local minimum=mode=='characters' and 554 or 454
    if self.window:GetHeight()<minimum then self.window:SetHeight(minimum) end
    local rows=self:SuiteRows(); local visible=math.max(1,math.floor((self.window:GetHeight()-174-18-top-45)/26))
    local maximum=math.max(0,#rows-visible); self.goldOffset=math.min(maximum,self.goldOffset or 0)
    self.goldScroll:SetMinMax(0,math.max(1,maximum)); self.goldScroll:SetValue(self.goldOffset); self.goldScroll:SetHidden(maximum==0)
    for i=1,math.max(visible,#self.suiteGoldRows) do
        local row=self.suiteGoldRows[i]
        if not row then
            row={label=self:Label(panel,'ZoFontWinT2'),value=self:Label(panel,'ZoFontWinT2'),columns={}}
            row.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            for j=1,3 do row.columns[j]=self:Label(panel,'ZoFontWinT2'); row.columns[j]:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
            row.line=WINDOW_MANAGER:CreateControl(nil,panel,CT_TEXTURE); row.line:SetColor(0.65,0.65,0.6,0.4)
            row.endLines={}
            for j=1,2 do
                row.endLines[j]=WINDOW_MANAGER:CreateControl(nil,panel,CT_TEXTURE)
                row.endLines[j]:SetColor(0.65,0.65,0.6,0.7); row.endLines[j]:SetMouseEnabled(false)
            end
            self.suiteGoldRows[i]=row
        end
        local data=i<=visible and rows[self.goldOffset+i]; local y=top+(i-1)*26
        row.label:SetHidden(not data or data.columns~=nil or data.guildEnd==true); row.value:SetHidden(not data or not data.value)
        for j,line in ipairs(row.endLines) do
            line:SetHidden(not data or not data.guildEnd)
            if data and data.guildEnd then place(line,panel,6,y+6+(j-1)*5,width-30,2) end
        end
        row.line:SetHidden(not data or not data.heading)
        for j,label in ipairs(row.columns) do
            label:SetHidden(not data or not data.columns)
            if data and data.columns then place(label,panel,6+(j-1)*(width-30)/3,y,(width-30)/3,25,data.columns[j]) end
        end
        if data and not data.columns and not data.guildEnd then
            place(row.label,panel,6,y,data.value and (width-30)*0.65 or width-30,25,data.heading or data.label,data.heading and 'ZoFontGameBold' or 'ZoFontWinT2')
            row.label:SetHorizontalAlignment(data.heading and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
            row.label:SetMouseEnabled(data.guildKey~=nil)
            row.label:SetHandler('OnMouseUp',data.guildKey and function(_,button)
                if button==MOUSE_BUTTON_INDEX_LEFT then
                    self.db.ui.goldGuildClosed=self.db.ui.goldGuildClosed or {}
                    self.db.ui.goldGuildClosed[data.guildKey]=not self.db.ui.goldGuildClosed[data.guildKey]
                    self:QueueRefresh()
                end
            end or nil)
            if data.value then place(row.value,panel,6+(width-30)*0.65,y,(width-30)*0.35,25,data.value) end
            if data.heading then place(row.line,panel,6,y+25,width-30,1) end
        end
    end
end
local create=A.CreateWindow
function A:CreateWindow()
    create(self)
    self.suiteGoldRows={}; self.suiteCharacterLabels={}
    for _,key in ipairs({'wallet','post','incomeTitle','expensesTitle','balanceTitle','income','expenses','balance'}) do self.suiteCharacterLabels[key]=self:Label(self.goldPanel,'ZoFontWinT2') end
    self.suiteButtons={
        self:MenuButton(self.window,L('SUITE_HARVEST'),200,function()
            self.goldManualSelection=true; self:SelectActivity(self.db.ui.suiteHarvestActivity or 'resources'); self.goldManualSelection=nil
        end),
        self:MenuButton(self.window,L('SUITE_GOLD'),200,function() self:SelectActivity('gold') end)}
    self.suiteFilter=self:MenuButton(self.window,L('FILTER_LIST'),150,function() self:OpenSettings() end)
    self:Refresh()
end
local refresh=A.Refresh
function A:Refresh()
    if self.db and self.db.ui and not self.db.ui.activity then self.db.ui.activity='resources' end
    refresh(self)
    if not self.suiteButtons then return end
    self.goldInfo:SetHidden(true)
    local width=self.window:GetWidth()-36; local gold=self.db.ui.activity=='gold'; local minimized=self.db.ui.minimized
    self.filterButton:SetHidden(true)
    self.mainSettingsButton:ClearAnchors(); self.mainSettingsButton:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-54,12)
    self.mainSettingsButton:SetDimensions(30,30); self.mainSettingsButton:SetText(icon('EsoUI/Art/ChatWindow/chat_options_up.dds'))
    self.mainSettingsButton:SetHandler('OnMouseEnter',function(control) if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(control,TOP,L('SETTINGS')) end end)
    self.mainSettingsButton:SetHandler('OnMouseExit',function() if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end end)
    for i,button in ipairs(self.suiteButtons) do
        place(button,self.window,18+(i-1)*(width+8)/2,114,(width-8)/2,30)
        local active=(i==2)==gold
        button:SetHidden(false); button:SetAlpha(active and 1 or 0.55)
        button:SetText(active and self:GoldText(L(i==1 and 'SUITE_HARVEST' or 'SUITE_GOLD')) or L(i==1 and 'SUITE_HARVEST' or 'SUITE_GOLD'))
    end
    if not gold then self.db.ui.suiteHarvestActivity=self.db.ui.activity end
    for i,button in ipairs(self.activityButtons) do
        button:SetHidden(minimized or gold or i==3)
        if i<=2 then place(button,self.window,18+(i-1)*(width+8)/3,152,(width-16)/3,30) end
    end
    self.suiteFilter:SetHidden(minimized or gold); place(self.suiteFilter,self.window,18+2*(width+8)/3,152,(width-16)/3,30)
    if self.db.ui.activity=='fishing' then
        place(self.fishingInfo,self.window,18,192,width,24)
        local cardWidth=(self.window:GetWidth()-48)/3
        for i,card in ipairs(self.fishingCards) do place(card,self.window,18+(i-1)*(cardWidth+4),215,cardWidth,44) end
        for i,line in ipairs(self.fishingLines) do
            local y=264+(i-1)*22+(i>=2 and self.window:GetWidth()<700 and 22 or 0)
            line:ClearAnchors(); line:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,y); line:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-24,y)
        end
    end
    if not gold or minimized then
        for _,row in ipairs(self.suiteGoldRows) do row.label:SetHidden(true); row.value:SetHidden(true); row.line:SetHidden(true); for _,c in ipairs(row.columns) do c:SetHidden(true) end end
        for _,label in pairs(self.suiteCharacterLabels) do label:SetHidden(true) end
    end
end
