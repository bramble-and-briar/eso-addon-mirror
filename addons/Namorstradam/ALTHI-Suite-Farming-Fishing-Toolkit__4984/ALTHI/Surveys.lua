-- Survey stock; opening exactly one matching envelope requires an explicit click.
local A=ALTHarvestItems
local specs={
 {key='alchemy',title='ALCHEMY',sample=57744,closed=219853},
 {key='metal',title='BLACKSMITHING',sample=57687,closed=219849},
 {key='wood',title='WOODWORKING_47A0D9',sample=57741,closed=219851},
 {key='cloth',title='CLOTHING',sample=57738,closed=219850},
 {key='jewelry',title='JEWELRY',sample=139422,closed=219854},
 {key='runes',title='ENCHANTING',sample=57733,closed=219852},
}
local function clean(s)
    s=type(s)=='string' and s or ''
    if zo_strformat and SI_TOOLTIP_ITEM_NAME then s=zo_strformat(SI_TOOLTIP_ITEM_NAME,s) end
    -- Lua byte-character classes may classify UTF-8 continuation bytes as space.
    -- Do not trim the end of a Unicode Roman numeral into an invalid glyph.
    return s:gsub('%^.*',''):gsub('^[ \t\r\n]+',''):gsub('[ \t\r\n]+$','')
end
local function bankOpen()
    return IsBankOpen and IsBankOpen() and GetBankingBag and GetBankingBag()==BAG_BANK
end
function A:SurveyTemplates()
    if self.surveyTemplates then return self.surveyTemplates end
    local result={}; local auridon=GetZoneNameById and clean(GetZoneNameById(381)) or ''
    if auridon=='' then return result end
    for _,spec in ipairs(specs) do
        local name=clean(GetItemLinkName(self.Link(spec.sample)))
        local first,last=name:find(auridon,1,true)
        if first then result[spec.key]={before=name:sub(1,first-1),after=name:sub(last+1)} end
    end
    -- Missing native item metadata is retried, not cached as a valid template.
    if next(result) then self.surveyTemplates=result end
    return result
end
function A:DescribeSurvey(id)
    self.surveyDescriptions=self.surveyDescriptions or {}
    local cached=self.surveyDescriptions[id]
    if cached then return cached.key,cached.area,cached.closed end
    for _,spec in ipairs(specs) do if spec.closed==id then return spec.key,nil,true end end
    local link=self.Link(id); local _,special=GetItemLinkItemType(link)
    if not SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT or special~=SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then return end
    local name=clean(GetItemLinkName(link))
    for key,template in pairs(self:SurveyTemplates()) do
        local before,after=template.before,template.after
        if #before+#after>0 and name:sub(1,#before)==before and (after=='' or name:sub(-#after)==after) then
            local area=clean(name:sub(#before+1,#name-#after))
            -- I/II/III sites in the same zone are combined only when the base
            -- exactly matches a native zone name. Otherwise keep the full label.
            local base=area:match('^(.-)%s+[IVX]+$')
            if base and GetNumZones and GetZoneNameByIndex then
                self.surveyZoneNames=self.surveyZoneNames or {}
                if not self.surveyZonesLoaded then
                    for i=1,GetNumZones() do self.surveyZoneNames[clean(GetZoneNameByIndex(i))]=true end
                    self.surveyZonesLoaded=true
                end
                if self.surveyZoneNames[base] then area=base end
            end
            if area~='' then
                self.surveyDescriptions[id]={key=key,area=area,closed=false}
                return key,area,false
            end
        end
    end
    -- Unsupported naming layouts remain visibly unassigned, never guessed.
    return nil,name,false
end
function A:ScanSurveyBag(bag)
    local counts={}
    self.surveyBagSlots=self.surveyBagSlots or {}; self.surveyBagSlots[bag]={}
    if not GetBagSize or not GetItemLink or not GetItemLinkItemId then return counts end
    for slot=0,GetBagSize(bag)-1 do
        local link=GetItemLink(bag,slot); local id=GetItemLinkItemId(link)
        if id and id>0 then
            local _,special=GetItemLinkItemType(link); local closed=false
            for _,spec in ipairs(specs) do if id==spec.closed then closed=true; break end end
            if closed or (SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT and special==SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT) then
                local count=GetSlotStackSize(bag,slot)
                if count and count>0 then counts[id]=(counts[id] or 0)+count; self.surveyBagSlots[bag][slot]=id end
            end
        end
    end
    return counts
end
function A:UpdateSurveyStock()
    self.surveyBackpack=self:ScanSurveyBag(BAG_BACKPACK)
    if bankOpen() then
        local counts=self:ScanSurveyBag(BAG_BANK)
        if BAG_SUBSCRIBER_BANK and BAG_SUBSCRIBER_BANK~=BAG_BANK then
            for id,count in pairs(self:ScanSurveyBag(BAG_SUBSCRIBER_BANK)) do counts[id]=(counts[id] or 0)+count end
        end
        self.db.surveyBank={counts=counts,updated=GetTimeStamp()}
    end
    local pending=self.surveyOpening
    if pending and pending.key then
        local total=0
        for id,count in pairs(self.surveyBackpack) do if id==pending.id then total=total+count end end
        if total<pending.before then
            self.surveyOpening=nil
            if self.surveyBatch then
                self.surveyBatch.left=self.surveyBatch.left-1
                local remaining=self.surveyBatch.remaining
                if remaining then remaining[pending.id]=math.max(0,(remaining[pending.id] or 0)-1) end
            end
            self.surveyNextAt=self.Now()+0.2
        end
    end
    self:RefreshSurveys()
    if self.surveyWindow and not self.surveyWindow:IsHidden() then self:DrawSurveyList() end
end
function A:SurveySummary(key)
    local result={inventory=0,bank=0,closedInventory=0,closedBank=0,areas={},unassigned=0}
    for _,source in ipairs({{self.surveyBackpack or {},'inventory','closedInventory'},
        {self.db.surveyBank and self.db.surveyBank.counts or {},'bank','closedBank'}}) do
        for id,count in pairs(source[1]) do
            local craft,area,closed=self:DescribeSurvey(id)
            if craft==key then
                if closed then result[source[3]]=result[source[3]]+count
                else
                    result[source[2]]=result[source[2]]+count
                    local row=result.areas[area] or {name=area,inventory=0,bank=0,total=0}; result.areas[area]=row
                    row[source[2]]=row[source[2]]+count; row.total=row.total+count
                end
            elseif not craft then result.unassigned=result.unassigned+count end
        end
    end
    result.rows={}; for _,row in pairs(result.areas) do result.rows[#result.rows+1]=row end
    table.sort(result.rows,function(a,b) if a.total==b.total then return a.name<b.name end; return a.total>b.total end)
    return result
end
function A:SurveyIcons(key)
    local opened='EsoUI/Art/Icons/treasuremap_witchesfestival.dds'; local closed=opened
    for _,spec in ipairs(specs) do
        if spec.key==key and GetItemLinkIcon then
            local native=GetItemLinkIcon(self.Link(spec.closed)); if native and native~='' then closed=native end
            break
        end
    end
    return '|t22:22:'..opened..'|t','|t22:22:'..closed..'|t'
end
function A:SurveyTip(key)
    local s=self:SurveySummary(key)
    local opened,closed=self:SurveyIcons(key)
    local bank=self.db.surveyBank and tostring(s.bank) or '—'
    local closedBank=self.db.surveyBank and tostring(s.closedBank) or '—'
    local text=string.format(self:T('SURVEY_COMPACT_INVENTORY'),opened,s.inventory,closed,s.closedInventory)
        ..'\n'..string.format(self:T('SURVEY_COMPACT_BANK'),opened,bank,closed,closedBank)
    if s.unassigned>0 then text=text..'\n'..string.format(self:T('SURVEY_UNASSIGNED'),s.unassigned) end
    return text
end
function A:ShowSurveyTip(control)
    self:ShowSuiteTip(control,TOP,self:SurveyTip(control.key)); self.surveyTooltipOwner=control
end
function A:HideSurveyTip()
    if self.suiteTipOwner==self.surveyTooltipOwner then self:HideSuiteTip() end
    self.surveyTooltipOwner=nil
end
function A:SurveyBankStatus()
    local bank=self.db.surveyBank
    if not bank or not bank.updated then return self:T('SURVEY_BANK_UNKNOWN') end
    local date=GetDateStringFromTimestamp and GetDateStringFromTimestamp(bank.updated) or tostring(bank.updated)
    local age=math.max(0,math.floor((GetTimeStamp()-bank.updated)/60))
    return string.format(self:T('SURVEY_BANK_UPDATED'),date,age)
end
function A:SurveyInventoryRows(key)
    local rows={}
    for _,row in ipairs(self:SurveySummary(key).rows) do
        if row.inventory>0 then rows[#rows+1]=row end
    end
    table.sort(rows,function(a,b)
        if a.inventory==b.inventory then
            local an,bn=zo_strlower(a.name),zo_strlower(b.name)
            if an==bn then return a.name<b.name end
            return an<bn
        end
        return a.inventory>b.inventory
    end)
    return rows
end
function A:SurveyOpeningSlot(key)
    if self.surveyOpening or self.surveyBatch then return end
    local slot,id,cooldown=self:FindSurveyEnvelope(key)
    if slot and cooldown==0 then return slot,id end
end
function A:OpenSurveyEnvelope() self:StartSurveyOpening(false) end
function A:RefreshSurveys()
    if not self.surveyButtons then return end
    local width=self.window:GetWidth()-36; local narrow=width<570
    local step=(width-40)/7
    local visible=self.db.ui.activity=='resources' and not self.db.ui.minimized
    for i,button in ipairs(self.professionButtons) do
        button:ClearAnchors(); button:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*step,188)
        button:SetWidth(narrow and step or 34)
        local scroll=self.surveyButtons[i]
        if scroll then
            scroll:ClearAnchors(); scroll:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*step+(narrow and 0 or 34),narrow and 226 or 192)
            scroll:SetDimensions(narrow and step or step-34,32); scroll:SetHidden(not visible)
            local summary=self:SurveySummary(scroll.key)
            scroll:SetText('|t18:18:EsoUI/Art/Icons/treasuremap_witchesfestival.dds|t '..summary.inventory)
        end
    end
    self.suiteFilter:ClearAnchors(); self.suiteFilter:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+7*step,192); self.suiteFilter:SetDimensions(36,32)
    if self.surveyHovered and visible then self:ShowSurveyTip(self.surveyHovered)
    else self:HideSurveyTip() end
end
local top=A.TableTop
function A:TableTop() return top(self)+(self.db.ui.activity=='resources' and 38 or 0) end
local refresh=A.RefreshProfessions
function A:RefreshProfessions() refresh(self); self:RefreshSurveys() end
local create=A.CreateWindow
function A:CreateWindow()
    create(self); self.surveyButtons={}
    for i,spec in ipairs(specs) do
        local key,title=spec.key,spec.title
        local button=self:Button(self.window,'',34,function() self:OpenSurveyList(key,title) end)
        button.key=key
        button:SetFont('ZoFontGameSmall')
        button:SetHandler('OnMouseEnter',function(control) self.surveyHovered=control; self:ShowSurveyTip(control) end)
        button:SetHandler('OnMouseExit',function() self.surveyHovered=nil; self:HideSurveyTip() end)
        self.surveyButtons[i]=button
    end
    self:RefreshSurveys()
end
function A:QueueSurveyScan()
    if self.surveyScanQueued then return end
    self.surveyScanQueued=true
    EVENT_MANAGER:RegisterForUpdate('ALTHarvestItemsSurveyScan',200,function()
        EVENT_MANAGER:UnregisterForUpdate('ALTHarvestItemsSurveyScan'); self.surveyScanQueued=nil; self:UpdateSurveyStock()
    end)
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self); self:UpdateSurveyStock()
    local function event(name,eventId,callback)
        if eventId then EVENT_MANAGER:RegisterForEvent('ALTHarvestItemsSurveys'..name,eventId,callback) end
    end
    for i,bag in ipairs({BAG_BACKPACK,BAG_BANK,BAG_SUBSCRIBER_BANK}) do
        local name='ALTHarvestItemsSurveyBag'..i
        EVENT_MANAGER:RegisterForEvent(name,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,changedBag,slot)
            if slot~=nil then
                local previous=self.surveyBagSlots and self.surveyBagSlots[changedBag] and self.surveyBagSlots[changedBag][slot]
                if not previous then
                    local link=GetItemLink(changedBag,slot); local id=GetItemLinkItemId(link)
                    local report=false
                    for _,spec in ipairs(specs) do if id==spec.closed then report=true; break end end
                    if not report then local _,special=GetItemLinkItemType(link); report=special==SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT end
                    if not report then return end
                end
            end
            if changedBag~=BAG_BACKPACK and bankOpen() then self:UpdateSurveyStock() else self:QueueSurveyScan() end
        end)
        EVENT_MANAGER:AddFilterForEvent(name,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,REGISTER_FILTER_BAG_ID,bag)
    end
    event('Full',EVENT_INVENTORY_FULL_UPDATE,function() self:QueueSurveyScan() end)
    event('Bank',EVENT_OPEN_BANK,function() self:QueueSurveyScan() end)
    event('CloseBank',EVENT_CLOSE_BANK,function() self:UpdateSurveyStock() end)
    event('Login',EVENT_PLAYER_ACTIVATED,function() self:QueueSurveyScan() end)
end
