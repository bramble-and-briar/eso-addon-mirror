local C=CrownCrateCodex
function C:HideChoiceMenu()
    if self.choiceWindow then self:SetWindowHidden(self.choiceWindow,true) end
end
function C:ShowChoiceMenu(anchor,title,entries)
    if self.choiceWindow and not self.choiceWindow:IsHidden() and self.choiceAnchor==anchor then self:HideChoiceMenu(); return end
    self:HideTooltip()
    if not self.choiceWindow then
        local window=WINDOW_MANAGER:CreateTopLevelWindow("CrownCrateCodexChoices")
        window:SetHidden(true)
        self.choiceWindow=window
        window:SetMouseEnabled(true); window:SetClampedToScreen(true)
        window:SetDrawTier(DT_HIGH); window:SetTopmost(true)
        C.UI.Backdrop(window,1)
        self.choiceTitle=C.UI.Label(window,nil,14,8,300,28,"ZoFontGameBold")
        self.choiceClose=C.UI.Button(window,nil,C.L("Close"),0,6,70,function() self:HideChoiceMenu() end)
        self.choiceStatus=C.UI.Label(window,nil,14,0,440,26,"ZoFontGame")
        self.choiceRows={}
        local function Wheel(_,delta)
            self.choiceOffset=math.max(0,math.min(math.max(0,#self.choiceEntries-self.choiceVisible),self.choiceOffset-delta))
            self:RefreshChoices()
        end
        window:SetHandler("OnMouseWheel",Wheel)
        for index=1,10 do
            local rowIndex=index
            local row=C.UI.Button(window,nil,"",8,40+(index-1)*36,480,function()
                local entry=self.choiceEntries[self.choiceOffset+rowIndex]
                if entry then self:HideChoiceMenu(); entry.callback() end
            end)
            row:SetDimensions(480,36)
            row.label=C.UI.Label(row,nil,10,4,450,28,"ZoFontGame")
            row.label:SetMaxLineCount(1); row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            row:SetHandler("OnMouseWheel",Wheel)
            row:SetHandler("OnMouseEnter",function(target)
                local entry=self.choiceEntries[self.choiceOffset+rowIndex]
                if entry then
                    row.label:SetText("|c69D6FF"..entry.name.."|r")
                    if row.label.WasTruncated and row.label:WasTruncated() then self:ShowTooltip(target,entry.name) end
                end
            end)
            row:SetHandler("OnMouseExit",function() self:HideTooltip(); self:RefreshChoices() end)
            self.choiceRows[index]=row
        end
        self.choiceSlider=WINDOW_MANAGER:CreateControl(nil,window,CT_SLIDER)
        self.choiceSlider:SetOrientation(ORIENTATION_VERTICAL)
        self.choiceSlider:SetMouseEnabled(true); self.choiceSlider:SetValueStep(1)
        local thumb="EsoUI/Art/Miscellaneous/scrollbox_elevator.dds"
        self.choiceSlider:SetThumbTexture(thumb,thumb,thumb,16,32,0,0,1,1)
        self.choiceSlider:SetHandler("OnValueChanged",function(_,value)
            if not self.updatingChoices then self.choiceOffset=math.floor(value+0.5); self:RefreshChoices() end
        end)
        self.choiceSlider:SetHandler("OnMouseWheel",Wheel)
        if self.WatchGamepadWindow then self:WatchGamepadWindow(window) end
    end
    local window=self.choiceWindow
    self.choiceAnchor,self.choiceEntries,self.choiceOffset=anchor,entries,0
    self.choiceVisible=math.min(10,math.max(1,math.floor((GuiRoot:GetHeight()-120)/36)))
    local width=math.min(520,GuiRoot:GetWidth()-32)
    local height=76+math.min(self.choiceVisible,#entries)*36
    window:SetDimensions(width,height)
    self.choiceTitle:SetText(title); self.choiceTitle:SetDimensions(width-100,28)
    self.choiceClose:ClearAnchors(); self.choiceClose:SetAnchor(TOPLEFT,window,TOPLEFT,width-80,6)
    self.choiceStatus:ClearAnchors(); self.choiceStatus:SetAnchor(TOPLEFT,window,TOPLEFT,14,height-30)
    self.choiceStatus:SetDimensions(width-28,26)
    self.choiceSlider:ClearAnchors(); self.choiceSlider:SetAnchor(TOPLEFT,window,TOPLEFT,width-24,40)
    self.choiceSlider:SetDimensions(16,math.min(self.choiceVisible,#entries)*36)
    local left,top,_,bottom=anchor:GetScreenRect()
    local x=math.max(16,math.min(GuiRoot:GetWidth()-width-16,left))
    local y=bottom+4
    if y+height>GuiRoot:GetHeight()-16 then y=top-height-4 end
    y=math.max(16,math.min(GuiRoot:GetHeight()-height-16,y))
    window:ClearAnchors(); window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    self:RefreshChoices()
    C:SetWindowHidden(window,false); window:BringWindowToTop()
    if self.SyncGamepad then self:SyncGamepad() end
end
function C:RefreshChoices()
    local width=self.choiceWindow:GetWidth()
    local font=self.db.settings.displaySize=="Extra Large" and "$(MEDIUM_FONT)|22|soft-shadow-thin" or "ZoFontGame"
    for index,row in ipairs(self.choiceRows) do
        local entry=index<=self.choiceVisible and self.choiceEntries[self.choiceOffset+index]
        row:SetHidden(not entry)
        if entry then
            row:SetDimensions(width-36,36); row.label:SetDimensions(width-56,28); row.label:SetFont(font)
            row.label:SetText((entry.selected and "|c69D6FF" or "|cE7C877")..entry.name.."|r")
        end
    end
    self.updatingChoices=true
    self.choiceSlider:SetMinMax(0,math.max(0,#self.choiceEntries-self.choiceVisible))
    self.choiceSlider:SetValue(self.choiceOffset)
    self.choiceSlider:SetHidden(#self.choiceEntries<=self.choiceVisible)
    self.updatingChoices=false
    self.choiceStatus:SetText(string.format("%d-%d of %d%s",self.choiceOffset+1,math.min(#self.choiceEntries,self.choiceOffset+self.choiceVisible),#self.choiceEntries,#self.choiceEntries>self.choiceVisible and C.L(" / Mouse wheel or scrollbar") or ""))
end
