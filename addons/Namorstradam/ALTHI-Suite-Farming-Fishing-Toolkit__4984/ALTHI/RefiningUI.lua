local A=ALTHarvestItems
local function L(key) return A:T(key) end
local crafts={{'metal','BLACKSMITHING'},{'jewelry','JEWELRY'},{'cloth','CLOTHING'},{'wood','WOODWORKING_47A0D9'}}
local function sum(t) local n=0; for _,v in pairs(t) do n=n+v end; return n end
local function place(c,p,x,y,w,h)
    c:ClearAnchors(); c:SetAnchor(TOPLEFT,p,TOPLEFT,x,y); c:SetDimensions(w,h)
end
function A:RefiningRows(total)
    local s=self:RefiningState(); local state=total and s.total or s.current
    local rows={}; local value=0; local missing=0
    local locale=self:ClientLanguage()
    if self.refiningNameLocale~=locale then self.refiningNames={}; self.refiningNameLocale=locale end
    local function nativeName(id)
        local cached=self.refiningNames[id]
        if cached then return cached end
        local name=GetItemLinkName(self.Link(id))
        if type(name)=='string' and name~='' then
            name=zo_strformat(SI_TOOLTIP_ITEM_NAME,name); self.refiningNames[id]=name; return name
        end
        return (s.items[id] or {}).name or tostring(id)
    end
    local function row(name,amount,right,heading)
        local r={name=name,amount=amount,right=right,heading=heading}; rows[#rows+1]=r; return r
    end
    local function itemName(id)
        local m=s.items[id]; if not m then return tostring(id) end
        return '|t20:20:'..m.icon..'|t '..GetItemQualityColor(m.quality or 1):Colorize(nativeName(id))
    end
    for _,spec in ipairs(crafts) do
        local g=state.crafts[spec[1]]
        if g and next(g.inputs) then
            local used=sum(g.inputs); local worth=0; local absent=0
            if not total then
                for id,n in pairs(g.outputs) do
                    local price=self:Price(id)
                    if price then worth=worth+n*price else absent=absent+1 end
                end
                value=value+worth; missing=missing+absent
            end
            local title=row(total and self:GoldText(L(spec[2])) or L(spec[2]),nil,total and '' or (absent>0 and L('PARTIAL') or '')..self.Gold(worth),true)
            if total then title.foldKind='craft'; title.foldKey=spec[1] end
            if not total or not (self.db.ui.refiningClosed or {})[spec[1]] then
            local input=row(L('REFINE_INPUTS'),self.Integer(used),'',true)
            if total then input.foldKind='inputs'; input.foldKey=spec[1] end
            local ids={}; for id in pairs(g.inputs) do ids[#ids+1]=id end
            table.sort(ids,function(a,b) return nativeName(a)<nativeName(b) end)
            if not total or (self.db.ui.refiningInputsOpen or {})[spec[1]] then
                for _,id in ipairs(ids) do row(itemName(id),self.Integer(g.inputs[id]),'') end
            end
            if total and (g.excludedBoosterInputs or 0)>0 then
                row(L('REFINE_BOOSTER_SAMPLE'),self.Integer(g.boosterInputs or 0),'',true)
                row(L('REFINE_BOOSTER_EXCLUDED'),self.Integer(g.excludedBoosterInputs),'')
            end
            row(L('REFINE_RESULTS'),L('QUANTITY'),total and L('REFINE_PER_100') or L('REFINE_UNIT_TOTAL'),true)
            local results={}; for id in pairs(g.outputs) do results[#results+1]=id end
            table.sort(results,function(a,b)
                local aa,bb=s.items[a],s.items[b]
                if aa.role~=bb.role then return aa.role<bb.role end
                if aa.quality~=bb.quality then return aa.quality<bb.quality end
                return nativeName(a)<nativeName(b)
            end)
            local qualities={}
            for _,id in ipairs(results) do
                local count=g.outputs[id]; local meta=s.items[id]; local right=''
                if total then
                    local denominator=used
                    if meta.role=='base' then
                        denominator=0
                        for raw,n in pairs(g.inputs) do if g.baseFor[raw]==id then denominator=denominator+n end end
                    elseif meta.role=='booster' then
                        qualities[meta.quality]=true
                        denominator=g.boosterInputs or used
                    end
                    right=denominator>0 and string.format('%.2f',count*100/denominator) or '—'
                else
                    local price=self:Price(id)
                    right=price and self.UnitGold(price)..' / '..self.Gold(price*count) or '—'
                end
                row(itemName(id),self.Integer(count),right)
            end
            if total then
                for quality=2,5 do
                    if not qualities[quality] then row(L('REFINE_QUALITY_'..quality),'0',(g.boosterInputs or used)>0 and '0.00' or '—') end
                end
            end
            end -- expanded craft
            row('','','',true)
        end
    end
    return rows,value,missing
end
function A:RefreshRefining()
    if not self.refiningPanel then return end
    local active=self.db.ui.activity=='refining'; local hidden=not active or self.db.ui.minimized==true
    self.refiningPanel:SetHidden(hidden)
    local width=self.window:GetWidth()-36
    -- These are the collecting sub-tabs; the Gold navigation remains separate.
    for i,key in ipairs({'resources','fishing','refining'}) do
        local button=i==3 and self.refiningTab or self.activityButtons[i]
        place(button,self.window,18+(i-1)*(width+8)/3,152,(width-16)/3,30)
        button:SetHidden(self.db.ui.minimized or self.db.ui.activity=='gold')
        button:SetAlpha(self.db.ui.activity==key and 1 or 0.55)
    end
    if not active then return end
    for _,list in ipairs({self.rowControls,self.headers,self.dividers}) do for _,c in ipairs(list) do c:SetHidden(true) end end
    for _,c in ipairs({self.sessionGroup,self.stockGroup,self.empty,self.slider,self.stockButton,self.priceNote,self.guildStatus,self.resumeStatus}) do c:SetHidden(true) end
    -- Refining has its own value and does not repurpose the gathering stopwatch.
    self.status:SetText(L('REFINE_INDEPENDENT'))
    self.rate:SetText(''); self.bagTotal:SetText('')
    local total=self.db.ui.refiningLifetime==true
    local rows,value,missing=self:RefiningRows(total)
    self.sessionTotal:SetText(total and L('REFINE_TOTAL_VIEW') or L('REFINE_TOTAL_VALUE')..': '..(missing>0 and L('PARTIAL') or '')..self.Gold(value))
    if hidden then return end
    place(self.refiningPanel,self.window,18,190,width,math.max(160,self.window:GetHeight()-260))
    for i,b in ipairs(self.refiningViews) do
        place(b,self.refiningPanel,(i-1)*(width+8)/2,0,(width-8)/2,30)
        b:SetAlpha((i==2)==total and 1 or 0.55)
    end
    self.refiningNote:SetText(L(total and 'REFINE_LIFETIME_SCOPE' or 'REFINE_ESTIMATE'))
    place(self.refiningNote,self.refiningPanel,0,34,width-24,36)
    self.refiningSkillNote:SetText(L('REFINE_SKILLS_NOTE'))
    place(self.refiningSkillNote,self.refiningPanel,0,62,width-24,36)
    local capacity=math.max(1,math.floor((self.refiningPanel:GetHeight()-110)/28))
    self.refiningOffset=math.max(0,math.min(self.refiningOffset or 0,math.max(0,#rows-capacity)))
    self.refiningScrollbar:SetMinMax(0,math.max(1,#rows-capacity))
    self.refiningScrollbar:SetValue(self.refiningOffset); self.refiningScrollbar:SetHidden(#rows<=capacity)
    self.refiningEmpty:SetText(L('REFINE_EMPTY')); self.refiningEmpty:SetHidden(#rows>0)
    place(self.refiningEmpty,self.refiningPanel,0,110,width-24,50)
    for i=1,math.max(capacity,#self.refiningLabels) do
        local r=self.refiningLabels[i]
        if not r then
            r={name=self:Label(self.refiningPanel,'ZoFontWinT2'),amount=self:Label(self.refiningPanel,'ZoFontWinT2'),value=self:Label(self.refiningPanel,'ZoFontWinT2')}
            r.amount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); r.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            r.toggle=self:MenuButton(self.refiningPanel,'',100,function()
                local data=r.data; if not data or not data.foldKind then return end
                local field=data.foldKind=='craft' and 'refiningClosed' or 'refiningInputsOpen'
                self.db.ui[field]=self.db.ui[field] or {}
                self.db.ui[field][data.foldKey]=not self.db.ui[field][data.foldKey]
                self:QueueRefresh()
            end)
            r.line=WINDOW_MANAGER:CreateControl(nil,self.refiningPanel,CT_TEXTURE); r.line:SetColor(0.65,0.65,0.6,0.4)
            self.refiningLabels[i]=r
        end
        local data=i<=capacity and rows[self.refiningOffset+i]
        r.data=data
        for _,key in ipairs({'name','amount','value','line'}) do r[key]:SetHidden(not data) end
        r.toggle:SetHidden(not data or not data.foldKind)
        if data then
            local y=108+(i-1)*28; local usable=width-28
            place(r.toggle,self.refiningPanel,0,y,usable,27)
            place(r.name,self.refiningPanel,0,y,usable*0.48,26)
            place(r.amount,self.refiningPanel,usable*0.49,y,usable*0.14,26)
            place(r.value,self.refiningPanel,usable*0.64,y,usable*0.36,26)
            r.name:SetFont(data.heading and 'ZoFontGameBold' or 'ZoFontWinT2')
            r.name:SetText(data.name or ''); r.amount:SetText(data.amount or ''); r.value:SetText(data.right or '')
            place(r.line,self.refiningPanel,0,y+26,usable,1)
        end
    end
end
local create=A.CreateWindow
function A:CreateWindow()
    create(self)
    self.refiningTab=self:MenuButton(self.window,L('REFINE_TAB'),150,function() self:SelectActivity('refining') end)
    self.refiningPanel=WINDOW_MANAGER:CreateControl(nil,self.window,CT_CONTROL)
    self.refiningPanel:SetAutoRectClipChildren(true); self.refiningPanel:SetMouseEnabled(true)
    self.refiningPanel:SetHandler('OnMouseWheel',function(_,d) self.refiningOffset=math.max(0,(self.refiningOffset or 0)-d*3); self:QueueRefresh() end)
    self.refiningViews={}; self.refiningLabels={}
    for i,key in ipairs({'REFINE_CURRENT_VIEW','REFINE_TOTAL_VIEW'}) do
        local total=i==2
        self.refiningViews[i]=self:MenuButton(self.refiningPanel,L(key),200,function()
            self.db.ui.refiningLifetime=total; self.refiningOffset=0; self:QueueRefresh()
        end)
    end
    self.refiningNote=self:Label(self.refiningPanel,'ZoFontGameSmall')
    self.refiningSkillNote=self:Label(self.refiningPanel,'ZoFontGameSmall')
    self.refiningSkillNote:SetMaxLineCount(2); self.refiningSkillNote:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    self.refiningEmpty=self:Label(self.refiningPanel,'ZoFontWinT2')
    self.refiningScrollbar=self:MakeSlider('ALTHarvestItemsRefiningScroll',self.refiningPanel,108,-4,function(value)
        if self.refiningOffset~=value then self.refiningOffset=value; self:QueueRefresh() end
    end)
    self:RefreshRefining()
end
local refresh=A.Refresh
function A:Refresh() refresh(self); self:RefreshRefining() end
