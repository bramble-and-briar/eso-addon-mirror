-- One effective material selection shared by both HUDs. Stock is never loot.
local A=ALTHarvestItems
local icons=A.SurveyIcons
function A:SurveyIcons(key)
    if key=='selected' then key=self:SurveySelectedKeys()[1] or 'alchemy' end
    return icons(self,key)
end
function A:SurveySelectedKeys()
    local keys={}
    for i=1,6 do
        local key=self.professionSpecs[i][1]
        local _,selected=self:ProfessionSelection(key)
        if selected>0 then keys[#keys+1]=key end
    end
    return keys
end
local summary=A.SurveySummary
function A:SurveySummary(key)
    if key~='selected' then return summary(self,key) end
    local result={inventory=0,bank=0,closedInventory=0,closedBank=0,areas={},rows={},unassigned=0}
    for _,craft in ipairs(self:SurveySelectedKeys()) do
        local s=summary(self,craft)
        for _,field in ipairs({'inventory','bank','closedInventory','closedBank'}) do result[field]=result[field]+s[field] end
        result.unassigned=s.unassigned -- The same unknown stock, not once per profession.
        for name,row in pairs(s.areas) do
            local merged=result.areas[name] or {name=name,inventory=0,bank=0,total=0}
            result.areas[name]=merged
            for _,field in ipairs({'inventory','bank','total'}) do merged[field]=merged[field]+row[field] end
        end
    end
    for _,row in pairs(result.areas) do result.rows[#result.rows+1]=row end
    table.sort(result.rows,function(a,b) if a.total==b.total then return zo_strlower(a.name)<zo_strlower(b.name) end return a.total>b.total end)
    return result
end
function A:AllFiltersState()
    local ids=self:AllMaterialIds(); local selected=0
    for _,id in ipairs(ids) do if self:IsEnabled(id) then selected=selected+1 end end
    return ids,selected
end
function A:ToggleAllFilters()
    local ids,selected=self:AllFiltersState()
    self:SetItemsEnabled(ids,selected~=#ids)
end
function A:CreateAllFiltersButton(parent)
    local b=self:Button(parent,'',32,function() self:ToggleAllFilters() end)
    -- Existing native checkbox textures communicate the action without a new glyph.
    b:SetHandler('OnMouseEnter',function(c) self.allFiltersHovered=c; self:ShowSuiteTip(c,TOP,c.tip) end)
    b:SetHandler('OnMouseExit',function() self.allFiltersHovered=nil; self:HideSuiteTip() end)
    return b
end
function A:RefreshAllFiltersButton(b)
    local ids,selected=self:AllFiltersState(); local full=#ids>0 and selected==#ids
    b:SetText('|t24:24:EsoUI/Art/Inventory/inventory_tabIcon_crafting_'..(full and 'down' or 'up')..'.dds|t')
    b:SetAlpha(selected>0 and 1 or 0.4)
    b.tip=self:T(full and 'DESELECT_ENTIRE_LIST' or 'SELECT_ENTIRE_LIST')
    if self.allFiltersHovered==b then self:ShowSuiteTip(b,TOP,b.tip) end
end
function A:CreateSurveyProfessions()
    local w=self.surveyWindow; if w.professions then return end
    w.professions={}
    for i,spec in ipairs(self.professionSpecs) do
        if i>6 then break end
        local b=self:Button(w,'',40,function(c) self:SetItemsEnabled(c.ids,c.selected~=c.total) end)
        b.icon=WINDOW_MANAGER:CreateControl(nil,b,CT_TEXTURE)
        b.icon:SetAnchor(CENTER,b,CENTER,0,0); b.icon:SetDimensions(24,24)
        b.icon:SetTexture('EsoUI/Art/'..spec[3]); b.icon:SetMouseEnabled(false)
        b.ring=WINDOW_MANAGER:CreateControl(nil,b,CT_TEXTURE)
        b.ring:SetAnchor(CENTER,b,CENTER,0,0); b.ring:SetDimensions(34,34)
        b.ring:SetTexture('ALTHI/art/profession_ring.dds'); b.ring:SetMouseEnabled(false)
        b:SetHandler('OnMouseEnter',function(c) self.professionHovered=c; self:ShowSuiteTip(c,TOP,c.tip) end)
        b:SetHandler('OnMouseExit',function() self.professionHovered=nil; self:HideSuiteTip() end)
        w.professions[i]=b
    end
    w.allFilters=self:CreateAllFiltersButton(w)
end
local layout=A.LayoutSurveyWindow
function A:LayoutSurveyWindow()
    layout(self)
    local w=self.surveyWindow; if w.key~='selected' then return end
    self:CreateSurveyProfessions()
    local width,height=w:GetWidth(),w:GetHeight(); local step=(width-36)/7
    for i,spec in ipairs(self.professionSpecs) do
        if i>6 then break end
        local b=w.professions[i]; b:ClearAnchors(); b:SetAnchor(TOPLEFT,w,TOPLEFT,18+(i-1)*step,60); b:SetDimensions(step,40)
        self:RefreshProfessionButton(b,spec)
    end
    w.allFilters:ClearAnchors(); w.allFilters:SetAnchor(TOPLEFT,w,TOPLEFT,18+6*step,64); w.allFilters:SetDimensions(step,32)
    self:RefreshAllFiltersButton(w.allFilters)
    local function move(c,x,y,ww,hh) c:ClearAnchors(); c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y); c:SetDimensions(ww,hh) end
    move(w.info,18,112,width-36,60); move(w.bankStatus,18,174,width-36,24)
    move(w.columns,18,214,width-36,28); move(w.empty,18,278,width-60,30)
    move(w.scroll,width-22,254,12,height-334)
    move(w.dividers[2],18,204,width-36,1)
end
local capacity=A.SurveyRowCapacity
function A:SurveyRowCapacity()
    if self.surveyWindow.key=='selected' then return math.max(3,math.min(25,math.floor((self.surveyWindow:GetHeight()-334)/32))) end
    return capacity(self)
end
local travelRows=A.RefreshSurveyTravelRows
function A:RefreshSurveyTravelRows()
    travelRows(self)
    local w=self.surveyWindow; if not w or w.key~='selected' then return end
    w.title:SetText(self:GoldText(self:T('SURVEY_OVERVIEW')))
    for i,label in ipairs(w.rows) do
        local y=278+(i-1)*32
        label:ClearAnchors(); label:SetAnchor(TOPLEFT,w,TOPLEFT,18,y)
        w.amounts[i]:ClearAnchors(); w.amounts[i]:SetAnchor(TOPLEFT,w,TOPLEFT,w:GetWidth()-190,y)
        w.rowLines[i]:ClearAnchors(); w.rowLines[i]:SetAnchor(TOPLEFT,w,TOPLEFT,18,y+31)
        w.travelButtons[i]:ClearAnchors(); w.travelButtons[i]:SetAnchor(TOPLEFT,w,TOPLEFT,w:GetWidth()-78,y)
    end
end
function A:OpenSurveyOverview()
    self:OpenSurveyList('selected','SURVEY_OVERVIEW')
    local w=self.surveyWindow
    w:SetDimensionConstraints(480,446,1200,1100)
    if w:GetHeight()<446 then w:SetHeight(446) end
    self:DrawSurveyList()
end
function A:OpenSurveyShortcut()
    if self.surveyWindow and self.surveyRequestedVisible then
        self:CloseSurveyList()
    else self:OpenSurveyOverview() end
end
local refresh=A.RefreshSurveys
function A:RefreshSurveys()
    refresh(self)
    if not self.surveyButtons then return end
    local width=self.window:GetWidth()-36; local step=width/(#self.professionSpecs+2)
    local visible=self.db.ui.activity=='resources' and not self.db.ui.minimized
    for i,b in ipairs(self.professionButtons) do
        b:ClearAnchors(); b:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*step,188); b:SetWidth(step)
        local s=self.surveyButtons[i]
        if s then
            s:ClearAnchors(); s:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*step,226)
            s:SetWidth(step); s:SetAlpha(b.selected>0 and 1 or 0.3)
            s:SetText(self.Integer(self:SurveySummary(s.key).inventory))
        end
    end
    if not self.allFiltersButton then self.allFiltersButton=self:CreateAllFiltersButton(self.window) end
    self.allFiltersButton:ClearAnchors(); self.allFiltersButton:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+#self.professionSpecs*step,192); self.allFiltersButton:SetWidth(step)
    self.allFiltersButton:SetHidden(not visible); self:RefreshAllFiltersButton(self.allFiltersButton)
    self.suiteFilter:ClearAnchors(); self.suiteFilter:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(#self.professionSpecs+1)*step,192); self.suiteFilter:SetWidth(step)
    for _,b in ipairs(self.surveyButtons) do b:SetHandler('OnClicked',function() self:OpenSurveyOverview() end) end
end
local changed=A.SelectionChanged
function A:SelectionChanged()
    changed(self); self:StopSurveyBatch(); self:RefreshProfessions()
    self.surveyOffset=0
    if self.surveyWindow and not self.surveyWindow:IsHidden() then self:DrawSurveyList() end
end
