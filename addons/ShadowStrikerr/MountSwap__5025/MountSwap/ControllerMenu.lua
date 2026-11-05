local M=MountSwap
local function labelText(entry) return type(entry.name)=='function' and entry.name() or M.L(entry.name) end

function M:CreateControllerMenu()
    local ui=self.UI
    local w=WINDOW_MANAGER:CreateTopLevelWindow('MountSwapControllerMenu')
    self.controllerMenu=w
    w:SetDimensions(900,500); w:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    w:SetClampedToScreen(true); w:SetMouseEnabled(true); w:SetDrawTier(DT_HIGH); w:SetHidden(true)
    ui.backdrop(w)
    self.menuTitle=ui.label(w,'',24,16,700)
    ui.button(w,'Back',764,16,110,function() self:CloseControllerMenu() end)
    self.menuRows={}
    for i=1,7 do
        local row=ui.button(w,'',24,70+(i-1)*48,852,function(control)
            local state=self.menuState
            local entry=state and state.entries[control.mountSwapMenuIndex]
            if entry and entry.callback then entry.callback() end
            if self.menuState then self:RefreshControllerMenu() end
        end)
        row.mountSwapLabel=ui.label(row,'',8,4,836)
        row.mountSwapDescription=function()
            local entry=self.menuState and self.menuState.entries[row.mountSwapMenuIndex]
            if not entry then return '' end
            local description=entry.description
            return type(description)=='function' and description() or description or labelText(entry)
        end
        row.mountSwapLabel:SetMouseEnabled(false)
        self.menuRows[i]=row
        row:SetHandler('OnMouseWheel',function(_,delta)
            self.menuState.selected=math.max(1,math.min(#self.menuState.entries,self.menuState.selected-delta*3))
            self:RefreshControllerMenu()
        end)
    end
    self.menuCount=ui.label(w,'',24,430,800)
    self:ManageWindow(w,900,480)
end

function M:ShowControllerMenu(title,entries,overPicker)
    if not self.controllerMenu then self:CreateControllerMenu() end
    if self.controllerMenu:IsHidden() then self.menuStack={} end
    self.menuStack=self.menuStack or {}
    if self.menuState and not self.controllerMenu:IsHidden() then self.menuStack[#self.menuStack+1]=self.menuState end
    self.menuState={title=title,entries=entries,selected=1,overPicker=overPicker}
    self:RefreshControllerMenu()
    self:SetWindowHidden(self.controllerMenu,false)
    self:FocusControl(self.menuRows[1])
end

function M:CloseControllerMenu()
    local previous=table.remove(self.menuStack or {})
    if previous then self.menuState=previous; self:RefreshControllerMenu()
    else self.menuState=nil; self:SetWindowHidden(self.controllerMenu,true) end
end

function M:RefreshControllerMenu()
    local state=self.menuState
    if not state then return end
    self.menuTitle:SetText(M.L(state.title))
    self:FitLocalizedButton(self.menuTitle)
    state.selected=math.max(1,math.min(#state.entries,state.selected))
    local offset=math.floor((state.selected-1)/7)*7
    local top=70
    for i,row in ipairs(self.menuRows) do
        local index=offset+i
        local entry=state.entries[index]
        row.mountSwapMenuIndex=entry and index
        row.slotIndex=entry and entry.slotIndex
        row:SetHidden(not entry)
        if entry then
            local label=row.mountSwapLabel
            label:SetFont(self:ControllerFont()); label:SetDimensions(836,2000); label:SetText(labelText(entry) or '')
            local height=math.max(38,(label.GetTextHeight and label:GetTextHeight() or 30)+12)
            label:SetDimensions(836,height-8)
            row:ClearAnchors(); row:SetAnchor(TOPLEFT,self.controllerMenu,TOPLEFT,24,top); row:SetDimensions(852,height)
            top=top+height+8
        end
    end
    self.menuCount:ClearAnchors(); self.menuCount:SetAnchor(TOPLEFT,self.controllerMenu,TOPLEFT,24,top)
    self.menuCount:SetText(M.L(#state.entries==0 and 'No entries' or (offset+1)..'-'..math.min(offset+7,#state.entries)..' of '..#state.entries))
    self.controllerMenu.mountSwapHeight=top+40
    self:SyncGamepad()
    self:FocusControl(self.menuRows[state.selected-offset])
end

function M:ControllerSetting(option)
    if option.type=='mountswapfavorite' then
        self:OpenPicker(option.slotIndex,false,true)
    elseif option.type=='editbox' then
        self:EditControllerText(option)
    elseif option.type=='mountswapchattoggle' or option.type=='mountswapdashboard' or option.type=='checkbox' then
        option.setFunc(not option.getFunc())
    elseif option.type=='button' or option.type=='mountswaprightbutton' then
        option.func()
    elseif option.type=='dropdown' then
        local entries={}
        for i,name in ipairs(option.choices) do
            local selection=option.choicesValues and option.choicesValues[i] or name
            entries[#entries+1]={name=name,callback=function() option.setFunc(selection); self:CloseControllerMenu() end}
        end
        self:ShowControllerMenu(option.name,entries)
    end
end

function M:GamepadSettings()
    local entries={}
    for _,option in ipairs(self:SettingsControls()) do
        if option.type~='header' and option.type~='description' then
            local data=option
            entries[#entries+1]={name=function()
                local name=data.name
                if data.getFunc then
                    local current=data.getFunc()
                    if data.type=='mountswapfavorite' then
                        current=current~=0 and select(1,GetCollectibleInfo(current)) or M.L('None')
                    elseif type(current)=='boolean' then current=M.L(current and 'ON' or 'OFF')
                    elseif data.type=='dropdown' then
                        for index,choice in ipairs(data.choices) do
                            if data.choicesValues[index]==current then current=choice;break end
                        end
                    end
                    name=name..': '..tostring(current or '')
                end
                return name
            end,callback=function() self:ControllerSetting(data) end,
                secondary=data.useFunc or data.openFunc, description=data.tooltip or data.name, slotIndex=data.slotIndex}
        end
    end
    self:ShowControllerMenu('MountSwap settings',entries)
end

function M:EditControllerText(option)
    local ui=self.UI
    if not self.textWindow then
        local w=WINDOW_MANAGER:CreateTopLevelWindow('MountSwapTextEntry')
        self.textWindow=w
        w:SetDimensions(860,240); w:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        w:SetMouseEnabled(true); w:SetClampedToScreen(true); w:SetDrawTier(DT_HIGH); w:SetHidden(true)
        ui.backdrop(w)
        self.textTitle=ui.label(w,'',24,16,810)
        local edit=WINDOW_MANAGER:CreateControlFromVirtual('MountSwapControllerEdit',w,'ZO_DefaultEditForBackdrop')
        self.textEdit=edit
        edit:SetDimensions(800,42); edit:SetAnchor(TOPLEFT,w,TOPLEFT,30,66)
        edit:SetFont('ZoFontGamepad27'); edit:SetMouseEnabled(true); edit:SetEditEnabled(true)
        edit:SetHandler('OnMouseDown',function(control) control:TakeFocus() end)
        ui.label(w,'Enter saves; Escape cancels. Use your keyboard if native text entry is unavailable.',24,128,800):SetDimensions(800,60)
        ui.button(w,'Save',24,196,140,function() self:FinishControllerText(false) end)
        ui.button(w,'Cancel',184,196,140,function() self:FinishControllerText(true) end)
        self:HookTextEntry(edit,w,true)
        self:HookControl(edit,'OnFocusLost',function() self:FinishControllerText(self.cancelText) end)
        edit:SetHandler('OnEnter',function() self:FinishControllerText(false) end)
        edit:SetHandler('OnEscape',function() self:FinishControllerText(true) end)
        self:ManageWindow(w,860,240)
    end
    self.textOption=option; self.cancelText=false
    self.textTitle:SetText(option.name); self.textEdit:SetText(option.getFunc() or '')
    self:FitLocalizedButton(self.textTitle)
    self.textEdit:SetMaxInputChars(option.maxChars or 100)
    self:SetWindowHidden(self.textWindow,false)
    self.textEdit:TakeFocus()
end

function M:FinishControllerText(cancel)
    local option=self.textOption
    if not option then return end
    self.textOption=nil -- Commit at most once when Enter also causes focus loss.
    if not cancel then option.setFunc(self.textEdit:GetText()) end
    self.textEdit:LoseFocus()
    self.cancelText=false
    self:SetWindowHidden(self.textWindow,true)
    if self.menuState then self:RefreshControllerMenu() end
end
