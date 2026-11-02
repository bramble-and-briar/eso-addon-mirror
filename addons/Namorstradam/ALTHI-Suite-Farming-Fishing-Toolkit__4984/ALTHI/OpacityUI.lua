-- Independent backdrop opacity; text and controls never inherit this alpha.
local A=ALTHarvestItems
local function alpha(value) return math.max(0,math.min(1,tonumber(value) or 1)) end
function A:OpacityControl(parent,key)
    local group=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL); group:SetDimensions(134,24)
    local track=WINDOW_MANAGER:CreateControl(nil,group,CT_TEXTURE)
    track:SetAnchor(LEFT,group,LEFT,25,0); track:SetDimensions(84,2); track:SetColor(0.65,0.65,0.6,0.7)
    local function eye(path,side,offset)
        local icon=WINDOW_MANAGER:CreateControl(nil,group,CT_TEXTURE)
        icon:SetAnchor(side,group,side,offset,0); icon:SetDimensions(20,20); icon:SetTexture(path); icon:SetMouseEnabled(false)
    end
    eye('ALTHI/art/visibility_off.dds',LEFT,0); eye('ALTHI/art/visibility_on.dds',RIGHT,0)
    local slider=WINDOW_MANAGER:CreateControl(nil,group,CT_SLIDER)
    slider:SetAnchor(LEFT,group,LEFT,25,0); slider:SetDimensions(84,24)
    slider:SetOrientation(ORIENTATION_HORIZONTAL); slider:SetMouseEnabled(true); slider:SetMinMax(0,100); slider:SetValueStep(1)
    slider:SetThumbTexture('EsoUI/Art/Miscellaneous/scrollbox_elevator.dds','EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds',
        'EsoUI/Art/Miscellaneous/scrollbox_elevator.dds',10,18,0,0,1,1)
    slider:SetHandler('OnValueChanged',function(_,value)
        if group.syncing then return end
        self.db.ui[key]=alpha(value/100); self:ApplyAppearance()
    end)
    slider:SetHandler('OnMouseEnter',function(control)
        group.hovered=true
        if ZO_Tooltips_ShowTextTooltip then self:ShowSuiteTip(control,TOP,self:T('BACKGROUND')..': '..math.floor(alpha(self.db.ui[key])*100+0.5)..'%') end
    end)
    slider:SetHandler('OnMouseExit',function() group.hovered=nil; if ZO_Tooltips_HideTextTooltip then self:HideSuiteTip() end end)
    group.slider=slider
    local addon=self
    function group:Sync(value)
        self.syncing=true; self.slider:SetValue(alpha(value)*100); self.syncing=nil
        if self.hovered and ZO_Tooltips_ShowTextTooltip then
            addon:ShowSuiteTip(self.slider,TOP,addon:T('BACKGROUND')..': '..math.floor(alpha(value)*100+0.5)..'%')
        end
    end
    group:Sync(self.db.ui[key]); return group
end
local appearance=A.ApplyAppearance
function A:ApplyAppearance()
    appearance(self)
    if self.surveyWindow and self.surveyWindow.althiBackdrop then
        self.surveyWindow.althiBackdrop:SetCenterColor(0.025,0.035,0.03,alpha(self.db.ui.surveyBackgroundAlpha))
        self.surveyWindow.althiBackdrop:SetEdgeColor(0.65,0.65,0.6,0.65)
    end
    if self.mainOpacity then self.mainOpacity:Sync(self.db.ui.backgroundAlpha) end
    if self.surveyWindow and self.surveyWindow.opacity then self.surveyWindow.opacity:Sync(self.db.ui.surveyBackgroundAlpha) end
    if self.syncingOpacitySettings then return end
    self.syncingOpacitySettings=true
    for _,entry in ipairs({{self.backgroundSlider,'backgroundAlpha'},{self.surveyBackgroundSlider,'surveyBackgroundAlpha'}}) do
        if entry[1] then entry[1]:SetValue(alpha(self.db.ui[entry[2]])*100) end
    end
    self.syncingOpacitySettings=nil
end
local create=A.CreateWindow
function A:CreateWindow()
    create(self)
    if self.db.ui.surveyBackgroundAlpha==nil then self.db.ui.surveyBackgroundAlpha=1 end
    self.mainOpacity=self:OpacityControl(self.window,'backgroundAlpha'); self:Refresh()
end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    if not self.mainOpacity then return end
    local narrow=self.window:GetWidth()<680
    self.mainOpacity:ClearAnchors(); self.mainOpacity:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-94,narrow and 34 or 16)
    self.titleLabel:SetWidth(self.window:GetWidth()-(narrow and 118 or 254))
    self.subtitleLabel:SetWidth(self.window:GetWidth()-258)
    self.mainOpacity:Sync(self.db.ui.backgroundAlpha)
end
