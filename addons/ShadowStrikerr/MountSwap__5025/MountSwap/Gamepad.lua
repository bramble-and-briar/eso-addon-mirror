-- PC controller navigation follows the workspace's Crown Crate Codex pattern.
-- All input is inherited from ESO UI actions; no player bindings are assigned.
local M = MountSwap
local LAYER = 'MountSwapGamepad'
local function shown(control) return control and not control:IsHidden() end
local function parent(control) return control.GetParent and control:GetParent() or control.parent end
local function value(text) return type(text) == 'function' and text() or text end

function M:RegisterGamepadTarget(control, callback, description)
    self.gamepadTargets = self.gamepadTargets or {}
    self.gamepadTargets[#self.gamepadTargets + 1] = {control=control, callback=callback, description=description}
end

function M:GamepadRoot()
    if shown(self.textWindow) then return self.textWindow end
    if shown(self.controllerMenu) and self.menuState and self.menuState.overPicker then return self.controllerMenu end
    if shown(self.picker) then return self.picker end
    if shown(self.controllerMenu) then return self.controllerMenu end
    if shown(self.window) then return self.window end
end

function M:GamepadCandidates(root)
    local result = {}
    if not root then return result end
    for _, entry in ipairs(self.gamepadTargets or {}) do
        local control, visible = entry.control, true
        if control.IsEnabled and not control:IsEnabled() then visible=false end
        while control and control ~= root do
            if control:IsHidden() then visible=false; break end
            control=parent(control)
        end
        if visible and control == root then result[#result+1]=entry end
    end
    return result
end

function M:GamepadFocus(entry)
    self.gamepadFocus=entry
    if not entry then
        if self.gamepadOutline then self.gamepadOutline:SetHidden(true) end
        return
    end
    if not self.gamepadOutline then
        local outline=WINDOW_MANAGER:CreateControl(nil,entry.control,CT_BACKDROP)
        outline:SetCenterColor(0,0,0,0)
        outline:SetEdgeColor(0.4,0.9,1,1)
        outline:SetEdgeTexture('',1,1,3,0)
        outline:SetMouseEnabled(false)
        outline:SetDrawLayer(DL_OVERLAY)
        self.gamepadOutline=outline
    end
    local outline=self.gamepadOutline
    outline:SetParent(entry.control); outline:ClearAnchors(); outline:SetAnchorFill(entry.control); outline:SetHidden(false)
end

function M:ControllerFont()
    local size=self.saved and self.saved.controllerTextSize or 'Normal'
    return size=='Extra Large' and 'ZoFontGamepad34' or size=='Large' and 'ZoFontGamepad27' or 'ZoFontGame'
end

function M:GamepadBinding(action)
    if not GetHighestPriorityActionBindingInfoFromName then return M.L('[Unavailable]') end
    local key,m1,m2,m3,m4=GetHighestPriorityActionBindingInfoFromName(action,true)
    local function render(code)
        if not code or code==0 or code==KEY_INVALID then return end
        local texture=ZO_Keybindings_GetTexturePathForKey and ZO_Keybindings_GetTexturePathForKey(code)
        if texture and texture~='' then return '|t28:28:'..texture..'|t' end
        -- Do not substitute generic controller button numbers for missing artwork.
        return M.L('[Icon unavailable]')
    end
    local text=render(key)
    if not text then return M.L('[Unbound]') end
    local parts={}
    for _,code in ipairs({m1 or 0,m2 or 0,m3 or 0,m4 or 0}) do
        local modifier=render(code); if modifier then parts[#parts+1]=modifier end
    end
    parts[#parts+1]=text
    return table.concat(parts,' + ')
end

function M:LayoutControllerHints(root, active)
    local width,base=root.mountSwapWidth,root.mountSwapHeight
    if not width then return end
    if not root.mountSwapHints then
        local label=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL)
        label:SetAnchor(TOPLEFT,root,TOPLEFT,20,base)
        label:SetMouseEnabled(false)
        root.mountSwapHints=label
    end
    local hint=root.mountSwapHints
    hint:SetHidden(not active)
    root.mountSwapDirectionHints=root.mountSwapDirectionHints or {}
    for _,label in ipairs(root.mountSwapDirectionHints) do label:SetHidden(not active) end
    local height=base
    if active then
        local parts={}
        local function add(action,label) parts[#parts+1]=self:GamepadBinding(action)..' '..M.L(label) end
        add('UI_SHORTCUT_PRIMARY','Select'); add('UI_SHORTCUT_NEGATIVE','Back')
        add('UI_SHORTCUT_RIGHT_STICK','Details')
        if root==self.picker then
            add('UI_SHORTCUT_SECONDARY','Search'); add('UI_SHORTCUT_TERTIARY','Picker actions')
        elseif root==self.window then
            add('UI_SHORTCUT_SECONDARY','Use focused favorite'); add('UI_SHORTCUT_TERTIARY','Settings')
            add('UI_SHORTCUT_LEFT_SHOULDER','Multi-Rider'); add('UI_SHORTCUT_RIGHT_SHOULDER','Single-Rider')
        elseif root==self.controllerMenu then
            add('UI_SHORTCUT_SECONDARY','Use favorite / secondary action')
        end
        if root==self.picker or root==self.controllerMenu then
            add('UI_SHORTCUT_LEFT_TRIGGER','Previous page'); add('UI_SHORTCUT_RIGHT_TRIGGER','Next page')
        end
        hint:ClearAnchors(); hint:SetAnchor(TOPLEFT,root,TOPLEFT,20,base)
        hint:SetFont(self:ControllerFont()); hint:SetDimensions(width-40,1000)
        hint:SetText(table.concat(parts,'   |   '))
        local measured=math.max(28,hint.GetTextHeight and hint:GetTextHeight() or 140)
        hint:SetDimensions(width-40,measured)
        -- Separate controls provide a real row gap and equal-width columns;
        -- spaces/newlines inside a single label cannot guarantee either.
        local gap=24
        local columnWidth=(width-40-3*gap)/4
        local rowTop=base+measured+16
        local rowHeight=28
        local directionLeft=20
        for index,data in ipairs({{'UI_SHORTCUT_INPUT_UP','Up'},{'UI_SHORTCUT_INPUT_DOWN','Down'},
            {'UI_SHORTCUT_INPUT_LEFT','Left'},{'UI_SHORTCUT_INPUT_RIGHT','Right'}}) do
            local label=root.mountSwapDirectionHints[index]
            if not label then
                label=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL)
                label:SetMouseEnabled(false)
                root.mountSwapDirectionHints[index]=label
            end
            label:SetFont(self:ControllerFont());label:SetDimensions(columnWidth,1000)
            label:SetText(self:GamepadBinding(data[1])..' '..M.L(data[2]))
            local textWidth=label.GetStringWidth and label:GetStringWidth(label:GetText())
                or label.GetTextWidth and label:GetTextWidth() or 144
            if not textWidth or textWidth<=0 then textWidth=144 end
            local fittedWidth=math.min(columnWidth,math.max(80,textWidth+8))
            label:ClearAnchors();label:SetAnchor(TOPLEFT,root,TOPLEFT,directionLeft,rowTop)
            label:SetDimensions(fittedWidth,1000)
            local textHeight=math.max(28,label.GetTextHeight and label:GetTextHeight() or 56)
            label:SetDimensions(fittedWidth,textHeight);label:SetHidden(false)
            directionLeft=directionLeft+fittedWidth+gap
            rowHeight=math.max(rowHeight,textHeight)
        end
        height=rowTop+rowHeight+20
    end
    root:SetDimensions(width,height)
    if root.SetScale and GuiRoot.GetWidth and GuiRoot.GetHeight then
        root:SetScale(math.min(1,(GuiRoot:GetWidth()-32)/width,(GuiRoot:GetHeight()-32)/height))
    end
end

function M:SyncGamepad()
    if (self.visibilityDepth or 0)>0 or self.syncingGamepad then return end
    self.syncingGamepad=true
    local root=self:GamepadRoot()
    local focus=WINDOW_MANAGER.GetFocusControl and WINDOW_MANAGER:GetFocusControl()
    local active=root and not self.navigationSuspended and IsInGamepadPreferredMode and IsInGamepadPreferredMode()
        and not self.editingControl and not focus and PushActionLayerByName and RemoveActionLayerByName
    if active then
        if not self.gamepadLayerActive or (IsActionLayerActiveByName and not IsActionLayerActiveByName(LAYER)) then
            PushActionLayerByName(LAYER)
        end
        self.gamepadLayerActive=not IsActionLayerActiveByName or IsActionLayerActiveByName(LAYER)
        active=self.gamepadLayerActive
        local candidates=self:GamepadCandidates(root)
        local current
        for _,entry in ipairs(candidates) do if entry==self.gamepadFocus and self.gamepadRoot==root then current=entry end end
        if not current and self.gamepadRoot~=root then
            local preferred=root==self.window and self.slotButtons[1] or root==self.picker and self.pickerRows[1]
                or root==self.controllerMenu and self.menuRows[1]
            for _,entry in ipairs(candidates) do if entry.control==preferred then current=entry end end
        end
        self.gamepadRoot=root
        self:GamepadFocus(current or candidates[1])
    else
        if self.gamepadLayerActive and RemoveActionLayerByName then RemoveActionLayerByName(LAYER) end
        self.gamepadLayerActive=false; self.gamepadRoot=nil; self:GamepadFocus(nil)
    end
    self:SyncDirectionalInput(active and root)
    for _,window in pairs({self.window,self.picker,self.controllerMenu,self.textWindow}) do
        self:LayoutControllerHints(window,active and window==root)
    end
    self.syncingGamepad=false
end

-- Use ESO's own D-pad/left-stick movement and repeat handling while our window
-- owns input. No addon OnUpdate/timer loop and no player keybinding assignments.
function M:SyncDirectionalInput(root)
    local input=DIRECTIONAL_INPUT
    if self.directionalRoot and self.directionalRoot~=root then
        if input and input.Deactivate then input:Deactivate(self) end
        self.directionalRoot=nil
        self.movementHorizontal,self.movementVertical=nil,nil
    end
    if root and not self.directionalRoot and input and input.Activate and input.Deactivate and ZO_MovementController then
        -- D-pad presses are dispatched by our inherited UI actions below.
        -- Sampling them here as well would require suppressing those actions,
        -- which leaves D-pad movement dead whenever native sampling is blocked.
        self.movementHorizontal=ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL,nil,function()
            return input.GetX and ZO_DI_LEFT_STICK and -input:GetX(ZO_DI_LEFT_STICK) or 0
        end)
        self.movementVertical=ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,nil,function()
            return input.GetY and ZO_DI_LEFT_STICK and input:GetY(ZO_DI_LEFT_STICK) or 0
        end)
        self.directionalRoot=root
        input:Activate(self,root)
    end
end

function M:UpdateDirectionalInput()
    if not self.directionalRoot or not self.gamepadLayerActive then return end
    local trace=self.controllerInputTrace or {}
    self.controllerInputTrace=trace
    trace.updates=(trace.updates or 0)+1
    local focus=WINDOW_MANAGER.GetFocusControl and WINDOW_MANAGER:GetFocusControl()
    if focus or self.editingControl or not IsInGamepadPreferredMode() then self:SyncGamepad();return end
    if IsActionLayerTopLayerByName and not IsActionLayerTopLayerByName(LAYER) then
        trace.blockedByTop=(trace.blockedByTop or 0)+1
        return
    end
    local horizontal=self.movementHorizontal:CheckMovement()
    local vertical=self.movementVertical:CheckMovement()
    trace.horizontal,trace.vertical=horizontal,vertical
    if horizontal==MOVEMENT_CONTROLLER_MOVE_NEXT then self:GamepadMove(1,0)
    elseif horizontal==MOVEMENT_CONTROLLER_MOVE_PREVIOUS then self:GamepadMove(-1,0)
    elseif vertical==MOVEMENT_CONTROLLER_MOVE_NEXT then self:GamepadMove(0,1)
    elseif vertical==MOVEMENT_CONTROLLER_MOVE_PREVIOUS then self:GamepadMove(0,-1) end
end

function M:ControllerDiagnostics()
    local root=self:GamepadRoot()
    local name=root and root.GetName and root:GetName() or tostring(root)
    local active=IsActionLayerActiveByName and IsActionLayerActiveByName(LAYER)
    local top=IsActionLayerTopLayerByName and IsActionLayerTopLayerByName(LAYER)
    local key=GetHighestPriorityActionBindingInfoFromName and GetHighestPriorityActionBindingInfoFromName('MOUNTSWAP_GP_DOWN',true)
    local trace=self.controllerInputTrace or {}
    return string.format('Controller diagnostic | root=%s | targets=%d | candidates=%d | layer=%s | top=%s | directional=%s | down-key=%s | last-action=%s | stick-updates=%s | blocked-top=%s | stick-h=%s | stick-v=%s',
        tostring(name),#(self.gamepadTargets or {}),#self:GamepadCandidates(root),tostring(active),tostring(top),tostring(self.directionalRoot~=nil),tostring(key),
        tostring(trace.command),tostring(trace.updates or 0),tostring(trace.blockedByTop or 0),tostring(trace.horizontal),tostring(trace.vertical))
end

function M:FocusControl(control)
    for _,entry in ipairs(self:GamepadCandidates(self:GamepadRoot())) do
        if entry.control==control then self:GamepadFocus(entry); return end
    end
end

function M:GamepadMove(dx,dy)
    local entry=self.gamepadFocus
    if not entry then return end
    local control=entry.control
    if self.gamepadRoot==self.picker and dy~=0 then
        for index,row in ipairs(self.pickerRows) do
            if row==control then
                local absolute=self.pickerOffset+index+dy
                if absolute>=1 and absolute<=#self.pickerList then
                    if absolute<=self.pickerOffset then self:ScrollPicker(absolute-1)
                    elseif absolute>self.pickerOffset+8 then self:ScrollPicker(self.pickerOffset+1) end
                    self:FocusControl(self.pickerRows[absolute-self.pickerOffset]); return
                end
            end
        end
    elseif self.gamepadRoot==self.controllerMenu and dy~=0 then
        local index=control.mountSwapMenuIndex
        if index then
            local state=self.menuState
            state.selected=math.max(1,math.min(#state.entries,index+dy))
            self:RefreshControllerMenu(); return
        end
    end
    local l,t,r,b=control:GetScreenRect()
    local x,y=(l+r)/2,(t+b)/2
    local best,score
    for _,candidate in ipairs(self:GamepadCandidates(self.gamepadRoot)) do
        local left,top,right,bottom=candidate.control:GetScreenRect()
        local ex,ey=(left+right)/2-x,(top+bottom)/2-y
        local along,across=ex*dx+ey*dy,math.abs(ex*dy-ey*dx)
        if along>2 and (not score or along+across*4<score) then best,score=candidate,along+across*4 end
    end
    if best then self:GamepadFocus(best) end
end

function M:GamepadDetails()
    local entry=self.gamepadFocus
    if not entry then return end
    local control=entry.control
    local id=control.mountId or (control.slotIndex and self.saved.slots[control.slotIndex])
    local text
    if id then
        local name,description=GetCollectibleInfo(id)
        text=(name or M.L('Mount'))..'\n'..(description or '')
    else text=M.L(value(entry.description) or 'Select activates the focused control.') end
    -- Split long descriptions into scrollable chunks rather than truncating text.
    local entries={}
    for line in (text..'\n'):gmatch('(.-)\n') do
        if line=='' then line=' ' end
        local chunk=''
        for word in line:gmatch('%S+') do
            if #chunk>0 and #chunk+#word>180 then entries[#entries+1]={name=chunk}; chunk='' end
            chunk=chunk=='' and word or chunk..' '..word
        end
        entries[#entries+1]={name=chunk=='' and ' ' or chunk}
    end
    self:ShowControllerMenu('Details',entries,true)
end

function M:GamepadBack()
    if shown(self.textWindow) then self.cancelText=true; self.textEdit:LoseFocus(); self:SetWindowHidden(self.textWindow,true)
    elseif self:GamepadRoot()==self.picker then self:ClosePicker()
    elseif shown(self.controllerMenu) then
        self:CloseControllerMenu()
    else self:CloseWindows() end
end

function M:GamepadCommand(command)
    -- Check live mode/focus too, including commands queued just as a field gains focus.
    self:SyncGamepad()
    if not self.gamepadLayerActive then return end
    self.controllerInputTrace=self.controllerInputTrace or {}
    self.controllerInputTrace.command=command
    local root=self.gamepadRoot
    if command=='up' then self:GamepadMove(0,-1)
    elseif command=='down' then self:GamepadMove(0,1)
    elseif command=='left' then self:GamepadMove(-1,0)
    elseif command=='right' then self:GamepadMove(1,0)
    elseif command=='select' then
        local entry=self.gamepadFocus
        if entry and entry.callback then entry.callback(entry.control) end
    elseif command=='back' then self:GamepadBack()
    elseif command=='details' then self:GamepadDetails()
    elseif command=='secondary' then
        local control=self.gamepadFocus and self.gamepadFocus.control
        if root==self.picker then self.pickerSearch:TakeFocus()
        elseif root==self.window and control and control.slotIndex then self:Slot(control.slotIndex)
        elseif root==self.controllerMenu and control and control.mountSwapMenuIndex then
            local entry=self.menuState.entries[control.mountSwapMenuIndex]
            if entry and entry.secondary then entry.secondary() end
        end
    elseif command=='options' then
        if root==self.picker then
            local entries={{name='Search',callback=function() self:CloseControllerMenu(); self.pickerSearch:TakeFocus() end},
                {name='Clear search',callback=function() self.pickerSearch:SetText(''); self:CloseControllerMenu() end}}
            if not self.manageMode then entries[#entries+1]={name='Clear this favorite',callback=function()
                if self.pickerSlot then self.saved.slots[self.pickerSlot]=nil end
                self:CloseControllerMenu(); self:ClosePicker(); self:Refresh()
            end} end
            self:ShowControllerMenu('Picker actions',entries,true)
        elseif root==self.window then self:OpenSettings() end
    elseif (command=='multi' or command=='single') and root==self.window then
        local slot=self.gamepadFocus and self.gamepadFocus.control.slotIndex or 1
        self:FocusControl(self.slotButtons[(slot-1)%4+1+(command=='single' and 4 or 0)])
    elseif command=='previousPage' or command=='nextPage' then
        local direction=command=='nextPage' and 1 or -1
        if root==self.picker then self:ScrollPicker(self.pickerOffset+direction*8); self:FocusControl(self.pickerRows[1])
        elseif root==self.controllerMenu then
            self.menuState.selected=math.max(1,math.min(#self.menuState.entries,self.menuState.selected+direction*7))
            self:RefreshControllerMenu()
        end
    end
    self:SyncGamepad()
    return true
end
