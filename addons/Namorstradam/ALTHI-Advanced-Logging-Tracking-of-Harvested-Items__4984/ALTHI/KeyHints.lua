-- Read-only binding hints. Never create, assign, or change a player's keybinds.
local A=ALTHarvestItems
local function L(key) return A:T(key) end
function A:ActionBindings(action)
    local result={}
    if not GetActionIndicesFromName or not GetActionBindingInfo then return result end
    local layer,category,index=GetActionIndicesFromName(action)
    if not layer then return result end
    for slot=1,(GetMaxBindingsPerAction and GetMaxBindingsPerAction() or 2) do
        local key,m1,m2,m3,m4=GetActionBindingInfo(layer,category,index,slot)
        if key and key~=(KEY_INVALID or 0) then
            local label
            if ZO_Keybindings_GetBindingStringFromKeys then
                label=ZO_Keybindings_GetBindingStringFromKeys(key,m1 or KEY_INVALID or 0,m2 or KEY_INVALID or 0,m3 or KEY_INVALID or 0,m4 or KEY_INVALID or 0)
            elseif GetKeyName then
                local keys={}
                for _,modifier in ipairs({m1 or 0,m2 or 0,m3 or 0,m4 or 0}) do
                    if modifier~=(KEY_INVALID or 0) then keys[#keys+1]=GetKeyName(modifier) end
                end
                keys[#keys+1]=GetKeyName(key); label=table.concat(keys,'+')
            end
            if label and label~='' then result[#result+1]=label end
        end
    end
    return result
end
function A:HintButton(button,action,label)
    local bindings=self:ActionBindings(action)
    if #bindings==0 and button.althiAlternateAction then bindings=self:ActionBindings(button.althiAlternateAction) end
    button.althiHintText=label..(bindings[1] and ' ['..bindings[1]..']' or '')
    button.althiHintLabel=label
    if bindings[1] then
        if not button.hintTitle then
            button.hintTitle=self:Label(button,'ZoFontGameBold')
            button.hintKey=self:Label(button,'ZoFontWinT2')
            button.hintTitle:SetMouseEnabled(false); button.hintKey:SetMouseEnabled(false)
            button.hintTitle:SetColor(0.9,0.9,0.85,1); button.hintKey:SetColor(0.8,0.8,0.76,1)
        end
        button.hintTitle:SetFont(button.althiTitleFont or 'ZoFontGameBold')
        button.hintKey:SetFont(button.althiKeyFont or 'ZoFontWinT2')
        button.hintTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER); button.hintKey:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        button.hintTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER); button.hintKey:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        button.hintTitle:SetHidden(false); button.hintKey:SetHidden(false)
        button.hintTitle:SetText(label); button.hintKey:SetText('['..bindings[1]..']')
        button:SetText('')
    else
        if button.hintTitle then button.hintTitle:SetHidden(true); button.hintKey:SetHidden(true) end
        button:SetText(label)
    end
    button.althiHint=label..(#bindings>0 and '\n'..table.concat(bindings,' / ') or '')
    if not button.althiHintInstalled then
        button.althiHintInstalled=true
        button:SetHandler('OnMouseEnter',function(control)
            if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(control,TOP,control.althiHint) end
        end)
        button:SetHandler('OnMouseExit',function() if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end end)
    end
end
function A:LayoutHintButton(button)
    if not button.hintTitle or button.hintTitle:IsHidden() then return end
    local title,key=button.hintTitle,button.hintKey
    local available=math.max(20,button:GetWidth()-8)
    local keyWidth=math.min(available*0.65,key:GetStringWidth(key:GetText()))
    local titleWidth=math.min(math.max(1,available-keyWidth-6),title:GetStringWidth(title:GetText()))
    local total=titleWidth+6+keyWidth
    title:ClearAnchors(); title:SetDimensions(titleWidth,30); title:SetAnchor(LEFT,button,CENTER,-total/2,0)
    key:ClearAnchors(); key:SetDimensions(keyWidth,30); key:SetAnchor(LEFT,title,RIGHT,6,0)
end
function A:TableBottomSpace() return 60+math.max(0,(self.keyHintRows or 1)-1)*32 end
function A:RefreshKeyHints()
    if not self.window or not self.runButtons then return end
    if not self.hintMeasure then self.hintMeasure=self:Label(self.window,'ZoFontGame'); self.hintMeasure:SetHidden(true) end
    local paused=self.db.session.state=='paused'
    local actions={paused and 'ALTHI_RUN' or 'ALTHI_PAUSE','ALTHI_RESET'}
    local titles={paused and 'RESUME_SESSION' or 'PAUSE','RESET'}
    self.runButtons[1].althiAlternateAction=paused and 'ALTHI_PAUSE' or nil
    local maxWidth=self.window:GetWidth()-36
    local widths={}
    local lines={{width=0,buttons={}}}
    for i,button in ipairs(self.runButtons) do
        self:HintButton(button,actions[i],L(titles[i]))
        self.hintMeasure:SetFont('ZoFontGame')
        button.althiBaseWidth=button.althiBaseWidth or button:GetWidth()
        widths[i]=math.max(button.althiBaseWidth,math.min(maxWidth,self.hintMeasure:GetStringWidth(button.althiHintText)+12))
        local line=lines[#lines]
        if line.width>0 and line.width+6+widths[i]>maxWidth then lines[#lines+1]={width=0,buttons={}}; line=lines[#lines] end
        line.buttons[#line.buttons+1]=i; line.width=line.width+(line.width>0 and 6 or 0)+widths[i]
    end
    local last=lines[#lines]
    if last.width+16+self.stockButton:GetWidth()>maxWidth then lines[#lines+1]={width=0,buttons={}} end
    local previous=self.keyHintRows or 1
    self.keyHintRows=#lines
    for row,line in ipairs(lines) do
        local x=18
        for _,i in ipairs(line.buttons) do
            local button=self.runButtons[i]
            button:SetWidth(widths[i]); button:ClearAnchors()
            button:SetAnchor(BOTTOMLEFT,self.window,BOTTOMLEFT,x,-22-(#lines-row)*32)
            x=x+widths[i]+6
            self:LayoutHintButton(button)
        end
    end
    if not self.db.ui.minimized then
        local minimum=self:TableTop()+self:TableBottomSpace()+48
        if self.window:GetHeight()<minimum then self.window:SetHeight(minimum) end
    end
    if self.priceNote then
        self.priceNote:ClearAnchors(); self.priceNote:SetAnchor(BOTTOMLEFT,self.window,BOTTOMLEFT,18+last.width+14,-23)
        local noteWidth=self.priceNote:GetStringWidth(self.priceNote:GetText())
        self.priceNote:SetHidden(self.db.ui.minimized==true or #lines>1 or self.window:GetWidth()<900 or last.width+noteWidth+self.stockButton:GetWidth()+32>maxWidth)
    end
    if self.filterButton then
        self:HintButton(self.filterButton,'ALTHI_SETTINGS',L('FILTER_LIST'))
        local limit=math.max(130,self.window:GetWidth()-290)
        local width=math.min(limit,math.max(130,self.hintMeasure:GetStringWidth(self.filterButton.althiHintText)+16))
        self.filterButton:SetWidth(width)
        self.filterButton:SetFont('ZoFontWinT2')
        self:LayoutHintButton(self.filterButton)
        if self.mainSettingsButton then
            self.mainSettingsButton:ClearAnchors(); self.mainSettingsButton:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-65-width,12)
        end
    end
    if self.fishingTools and self.fishingTools[1] then
        self:HintButton(self.fishingTools[1],'ALTHI_FILLET',L(self.filletQueue and 'CANCEL' or 'FILLET'))
        local button=self.fishingTools[1]
        button:SetFont(self.hintMeasure:GetStringWidth(button.althiHintText)+12>button:GetWidth() and 'ZoFontWinT2' or 'ZoFontGameBold')
        self:LayoutHintButton(button)
    end
    if previous~=#lines then self:QueueRefresh() end
end
local refresh=A.Refresh
function A:Refresh() refresh(self); self:RefreshKeyHints() end
local create=A.CreateWindow
function A:CreateWindow() create(self); self:RefreshKeyHints() end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    for _,name in ipairs({'EVENT_KEYBINDINGS_LOADED','EVENT_KEYBINDING_SET','EVENT_KEYBINDING_CLEARED','EVENT_INPUT_LANGUAGE_CHANGED','EVENT_KEYBIND_DISPLAY_MODE_CHANGED'}) do
        local event=_G[name]
        if event then EVENT_MANAGER:RegisterForEvent('ALTHIKeyHints',event,function() self:QueueRefresh() end) end
    end
    if EVENT_INVENTORY_ITEM_USED then EVENT_MANAGER:RegisterForEvent('ALTHIItemOrigin',EVENT_INVENTORY_ITEM_USED,function()
        self.recentItemUseUntil=self.Now()+2
    end) end
end
