local A=ALTHarvestItems
function A:ShowSuiteTip(control,anchor,text)
    if not control or not text or text=='' then return end
    if not self.surveyTipWindow then
        local w=WINDOW_MANAGER:CreateTopLevelWindow('ALTHarvestItemsSurveyTooltip'); self.surveyTipWindow=w
        w:SetMouseEnabled(false); w:SetClampedToScreen(true); self:Backdrop(w)
        w.label=self:Label(w,'ZoFontGameBold'); w.label:SetAnchor(TOPLEFT,w,TOPLEFT,10,7)
    end
    local w=self.surveyTipWindow; local width,lines=0,0
    for line in text:gmatch('[^\n]+') do width=math.max(width,w.label:GetStringWidth(line)); lines=lines+1 end
    width=math.min(math.max(160,width+20),(GuiRoot:GetWidth() or 1920)-24)
    w:SetDimensions(width,lines*26+14); w.label:SetMaxLineCount(lines)
    w.label:SetDimensions(width-20,lines*26); w.label:SetText(text)
    w:ClearAnchors(); w:SetAnchor(BOTTOMLEFT,control,TOPLEFT,0,-6); self:Front(w)
    self.suiteTipOwner=control
end
function A:HideSuiteTip()
    if self.surveyTipWindow then self.surveyTipWindow:SetHidden(true) end
    self.suiteTipOwner=nil
end
