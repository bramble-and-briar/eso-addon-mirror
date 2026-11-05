local C=CrownCrateCodex
function C:HideTooltip()
    if self.tooltipWindow then self.tooltipWindow:SetHidden(true) end
end
function C:ShowTooltip(target,text)
    if not self.tooltipWindow then
        local window=WINDOW_MANAGER:CreateTopLevelWindow("CrownCrateCodexTooltip")
        self.tooltipWindow=window
        window:SetMouseEnabled(false)
        window:SetClampedToScreen(true)
        window:SetDrawTier(DT_HIGH)
        window:SetTopmost(true)
        C.UI.Backdrop(window,0.99)
        self.tooltipLines={}
    end
    local window=self.tooltipWindow
    local width=math.min(self.db.settings.tooltipWidth,GuiRoot:GetWidth()-32)
    local maxHeight=math.min(700,GuiRoot:GetHeight()-32)
    local font=self.db.settings.displaySize=="Extra Large" and "$(MEDIUM_FONT)|22|soft-shadow-thin" or "ZoFontGame"
    local y,index=14,0
    for line in string.gmatch(text.."\n","(.-)\n") do
        index=index+1
        if not self.tooltipLines[index] then self.tooltipLines[index]=C.UI.Label(window,nil,16,0,width-32,30,font) end
        local label=self.tooltipLines[index]
        label:SetHidden(false)
        label:ClearAnchors(); label:SetAnchor(TOPLEFT,window,TOPLEFT,16,y)
        label:SetDimensions(width-32,maxHeight)
        label:SetFont(font); label:SetMaxLineCount(20); label:SetText(line)
        local height=math.max(28,label:GetTextHeight()+8)
        if y+height+40>maxHeight then
            label:SetText(C.L("More details: hover an individual reward."))
            label:SetDimensions(width-32,28)
            y=y+28
            break
        end
        label:SetDimensions(width-32,height)
        y=y+height+6
    end
    for i=index+1,#self.tooltipLines do self.tooltipLines[i]:SetHidden(true) end
    local height=math.min(maxHeight,y+10)
    window:SetDimensions(width,height)
    local left,top,right=target:GetScreenRect()
    local x=right+12
    if x+width>GuiRoot:GetWidth()-16 then x=left-width-12 end
    x=math.max(16,math.min(GuiRoot:GetWidth()-width-16,x))
    top=math.max(16,math.min(GuiRoot:GetHeight()-height-16,top))
    window:ClearAnchors(); window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,top)
    window:SetHidden(false); window:BringWindowToTop()
end
