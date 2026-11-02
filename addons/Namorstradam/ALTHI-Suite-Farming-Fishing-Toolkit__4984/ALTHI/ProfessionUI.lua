-- Profession quick selection uses existing effective item filters, including housing.
local A=ALTHarvestItems
local specs={
 {'alchemy','ALCHEMY','icons/servicemappins/servicepin_alchemy.dds'},
 {'metal','BLACKSMITHING','crafting/smithing_tabicon_refine_down.dds'},
 {'wood','WOODWORKING_47A0D9','icons/servicemappins/servicepin_woodworking.dds'},
 {'cloth','CLOTHING','icons/servicemappins/servicepin_clothier.dds'},
 {'jewelry','JEWELRY','icons/servicemappins/servicepin_jewelrycrafting.dds'},
 {'runes','ENCHANTING','icons/servicemappins/servicepin_enchanting.dds'},
 {'provisioning','PROVISIONING','icons/servicetooltipicons/servicetooltipicon_provisioner.dds'},
 {'style','STYLE_MATERIALS','inventory/inventory_tabIcon_Craftbag_styleMaterial_down.dds'},
 {'traits','TRAIT_MATERIALS','inventory/inventory_tabIcon_Craftbag_itemTrait_down.dds'},
}
A.professionSpecs=specs
function A:RefreshProfessionButton(button,spec)
    local ids,selected=self:ProfessionSelection(spec[1])
    button.ids=ids; button.selected=selected; button.total=#ids
    button.icon:SetAlpha(selected>0 and 1 or 0.3)
    button.ring:SetHidden(#ids==0 or selected~=#ids)
    local status=selected==0 and 'PROFESSION_OFF' or selected==#ids and 'PROFESSION_FULL' or 'PROFESSION_PARTIAL'
    button.tip=self:T(spec[2])..' · '..self:T(status)..' ('..selected..'/'..#ids..')'
    if self.professionHovered==button and ZO_Tooltips_ShowTextTooltip then self:ShowSuiteTip(button,TOP,button.tip) end
end
function A:ProfessionSelection(key)
    local ids,selected={},0
    for id,item in pairs(self.db.catalog) do
        if (self.FilterCategoryMatches and self:FilterCategoryMatches(item,id,key)) or (not self.FilterCategoryMatches and self:FilterCategoryFor(item,id)==key) then
            ids[#ids+1]=id; if self:IsEnabled(id) then selected=selected+1 end
        end
    end
    return ids,selected
end
local tableTop=A.TableTop
function A:TableTop() return tableTop(self)+(self.db.ui.activity=='resources' and 46 or 0) end
function A:RefreshProfessions()
    if not self.professionButtons then return end
    local visible=self.db.ui.activity=='resources' and not self.db.ui.minimized
    local width=self.window:GetWidth()-36; local size=math.min(48,width/8)
    local x=18+(width-size*8)/2
    for i,spec in ipairs(specs) do
        local button=self.professionButtons[i]; local ids,selected=self:ProfessionSelection(spec[1])
        button.ids=ids; button.selected=selected; button.total=#ids
        button:ClearAnchors(); button:SetAnchor(TOPLEFT,self.window,TOPLEFT,x+(i-1)*size,188); button:SetDimensions(size,40)
        button:SetHidden(not visible); button.icon:SetAlpha(selected>0 and 1 or 0.3)
        button.ring:SetHidden(#ids==0 or selected~=#ids)
        local status=selected==0 and 'PROFESSION_OFF' or selected==#ids and 'PROFESSION_FULL' or 'PROFESSION_PARTIAL'
        button.tip=self:T(spec[2])..' · '..self:T(status)..' ('..selected..'/'..#ids..')'
        if self.professionHovered==button and ZO_Tooltips_ShowTextTooltip then self:ShowSuiteTip(button,TOP,button.tip) end
    end
    self.suiteFilter:SetHidden(not visible); self.suiteFilter:ClearAnchors()
    self.suiteFilter:SetAnchor(TOPLEFT,self.window,TOPLEFT,x+7*size+4,192); self.suiteFilter:SetDimensions(size-8,32)
    self.suiteFilter:SetText('|t22:22:EsoUI/Art/ChatWindow/chat_options_up.dds|t')
    for i=1,2 do
        local button=self.activityButtons[i]; button:ClearAnchors()
        button:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*(width+8)/2,152); button:SetWidth((width-8)/2)
    end
end
local create=A.CreateWindow
function A:CreateWindow()
    create(self); self.professionButtons={}
    for i,spec in ipairs(specs) do
        local key=spec[1]
        local button=self:Button(self.window,'',42,function(control)
            self:SetItemsEnabled(control.ids,control.selected~=control.total)
            self:RefreshProfessions()
        end)
        button.icon=WINDOW_MANAGER:CreateControl(nil,button,CT_TEXTURE)
        button.icon:SetAnchor(CENTER,button,CENTER,0,0); button.icon:SetDimensions(24,24)
        button.icon:SetTexture('EsoUI/Art/'..spec[3]); button.icon:SetMouseEnabled(false)
        button.ring=WINDOW_MANAGER:CreateControl(nil,button,CT_TEXTURE)
        button.ring:SetAnchor(CENTER,button,CENTER,0,0); button.ring:SetDimensions(34,34)
        button.ring:SetTexture('ALTHI/art/profession_ring.dds'); button.ring:SetMouseEnabled(false)
        button:SetHandler('OnMouseEnter',function(control) self.professionHovered=control; if ZO_Tooltips_ShowTextTooltip then self:ShowSuiteTip(control,TOP,control.tip) end end)
        button:SetHandler('OnMouseExit',function() self.professionHovered=nil; if ZO_Tooltips_HideTextTooltip then self:HideSuiteTip() end end)
        self.professionButtons[i]=button
    end
    self.suiteFilter:SetHandler('OnMouseEnter',function(control) if ZO_Tooltips_ShowTextTooltip then self:ShowSuiteTip(control,TOP,self:T('FILTER_LIST')) end end)
    self.suiteFilter:SetHandler('OnMouseExit',function() if ZO_Tooltips_HideTextTooltip then self:HideSuiteTip() end end)
    self:Refresh()
end
local refresh=A.Refresh
function A:Refresh() refresh(self); self:RefreshProfessions() end
