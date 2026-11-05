local C=CrownCrateCodex
local LAYER="CrownCrateCodexGamepad"
local function Shown(control) return control and not control:IsHidden() end
local function Parent(control) return control.GetParent and control:GetParent() or control.parent end
local function Handler(control,event) return control.GetHandler and control:GetHandler(event) or control.handlers and control.handlers[event] end

function C:RegisterGamepadTarget(control,callback,description,reward)
    self.gamepadTargets=self.gamepadTargets or {}
    self.gamepadTargets[#self.gamepadTargets+1]={control=control,callback=callback,description=description,reward=reward}
end
function C:WatchGamepadWindow(window)
    if self.ManageWindow then self:ManageWindow(window) end
    for _,event in ipairs({"OnShow","OnHide"}) do
        local previous=Handler(window,event)
        window:SetHandler(event,function(...)
            if previous then previous(...) end
            self:SyncGamepad()
        end)
    end
end
function C:GamepadRoot()
    if Shown(self.choiceWindow) then return self.choiceWindow end
    if Shown(self.legacyImportWindow) then return self.legacyImportWindow end
    if Shown(self.exportWindow) then return self.exportWindow end
    if Shown(self.window) then return self.window end
end
function C:GamepadCandidates(root)
    local result={}
    for _,entry in ipairs(self.gamepadTargets or {}) do
        local control,visible=entry.control,true
        if control.IsEnabled and not control:IsEnabled() then visible=false end
        while control and control~=root do
            if control:IsHidden() then visible=false; break end
            control=Parent(control)
        end
        if visible and control==root then result[#result+1]=entry end
    end
    return result
end
function C:GamepadFocus(entry)
    self.gamepadFocus=entry
    if not entry then
        if self.gamepadOutline then self.gamepadOutline:SetHidden(true) end
        return
    end
    if not self.gamepadOutline then
        self.gamepadOutline=WINDOW_MANAGER:CreateControl(nil,entry.control,CT_BACKDROP)
        self.gamepadOutline:SetCenterColor(0,0,0,0)
        self.gamepadOutline:SetEdgeColor(0.41,0.84,1,1)
        self.gamepadOutline:SetEdgeTexture("",1,1,2)
        self.gamepadOutline:SetMouseEnabled(false)
        if DL_OVERLAY then self.gamepadOutline:SetDrawLayer(DL_OVERLAY) end
    end
    local outline=self.gamepadOutline
    outline:SetParent(entry.control); outline:ClearAnchors(); outline:SetAnchorFill(entry.control); outline:SetHidden(false)
end
function C:GamepadBinding(action)
    if not GetHighestPriorityActionBindingInfoFromName then return action end
    local key,mod1,mod2,mod3,mod4=GetHighestPriorityActionBindingInfoFromName(action,true)
    local size=self.db.settings.displaySize=="Extra Large" and 28 or 24
    local function Render(code)
        if not code or code==0 or code==KEY_INVALID then return end
        local texture=ZO_Keybindings_GetTexturePathForKey and ZO_Keybindings_GetTexturePathForKey(code)
        if texture and texture~="" then return string.format("|t%d:%d:%s|t",size,size,texture) end
        return GetKeyName and GetKeyName(code) or tostring(code)
    end
    local parts={}
    for _,modifier in ipairs({mod1 or 0,mod2 or 0,mod3 or 0,mod4 or 0}) do
        local text=Render(modifier); if text then parts[#parts+1]=text end
    end
    local text=Render(key)
    if not text or text=="" then return C.L("Unbound") end
    parts[#parts+1]=text
    return table.concat(parts," + ")
end
function C:GamepadHints()
    if not self.helpLabel then return end
    local parts={}
    for _,item in ipairs({{"UI_SHORTCUT_PRIMARY","Select"},{"UI_SHORTCUT_NEGATIVE","Back"},{"UI_SHORTCUT_SECONDARY","Open in Collections"},{"UI_SHORTCUT_TERTIARY","Controller options"},{"UI_SHORTCUT_RIGHT_STICK","Details"}}) do
        parts[#parts+1]=self:GamepadBinding(item[1])..": "..C.L(item[2])
    end
    parts[#parts+1]=self:GamepadBinding("UI_SHORTCUT_INPUT_UP")..self:GamepadBinding("UI_SHORTCUT_INPUT_DOWN")..self:GamepadBinding("UI_SHORTCUT_INPUT_LEFT")..self:GamepadBinding("UI_SHORTCUT_INPUT_RIGHT")..": "..C.L("Move")
    parts[#parts+1]=self:GamepadBinding("UI_SHORTCUT_LEFT_SHOULDER").." / "..self:GamepadBinding("UI_SHORTCUT_RIGHT_SHOULDER")..": "..C.L("Tabs")
    parts[#parts+1]=self:GamepadBinding("UI_SHORTCUT_LEFT_TRIGGER").." / "..self:GamepadBinding("UI_SHORTCUT_RIGHT_TRIGGER")..": "..C.L("Pages")
    self.helpLabel:SetHidden(false)
    self.helpLabel:SetDimensions(1200,56)
    self.helpLabel:SetMaxLineCount(2)
    self.helpLabel:SetText(table.concat(parts,"  |  "))
end
function C:SyncGamepad()
    if (self.visibilityDepth or 0)>0 then return end
    local root=self:GamepadRoot()
    if not root then self.gamepadEditing=false end
    local active=root and self.db and self.db.settings.gamepadNavigation~=false
        and IsInGamepadPreferredMode and IsInGamepadPreferredMode() and not self.gamepadEditing
    if active and PushActionLayerByName then
        if not self.gamepadLayerActive then PushActionLayerByName(LAYER); self.gamepadLayerActive=true end
        local candidates=self:GamepadCandidates(root)
        local current
        for _,entry in ipairs(candidates) do if entry==self.gamepadFocus then current=entry end end
        if self.gamepadRoot~=root then
            current=nil
            local preferred=root==self.window and self.crateButton or root==self.legacyImportWindow and self.legacyImportServer or root==self.choiceWindow and self.choiceRows[1]
            for _,entry in ipairs(candidates) do if entry.control==preferred then current=entry end end
        end
        self.gamepadRoot=root
        self:GamepadFocus(current or candidates[1]); self:GamepadHints()
    else
        if self.gamepadLayerActive and RemoveActionLayerByName then RemoveActionLayerByName(LAYER) end
        self.gamepadLayerActive=false; self.gamepadRoot=nil; self:GamepadFocus(nil)
        if self.window and Shown(self.window) then
            self.helpLabel:SetHidden(not self.db.settings.showHelp)
            self.helpLabel:SetText(C.L("Left-click: rate. ")..self:ActionHint(C.L("Right-click collectible: Collections."))..C.L(" Filters do not change rate denominators."))
        end
    end
end
function C:GamepadMove(dx,dy)
    local current=self.gamepadFocus
    if not current then return end
    if self.gamepadRoot==self.choiceWindow and dy~=0 then
        for index,row in ipairs(self.choiceRows) do
            if current.control==row then
                local absolute=math.max(1,math.min(#self.choiceEntries,self.choiceOffset+index+dy))
                self.choiceOffset=math.max(0,math.min(math.max(0,#self.choiceEntries-self.choiceVisible),absolute-1,self.choiceOffset+(absolute>self.choiceOffset+self.choiceVisible and 1 or 0)))
                if absolute<=self.choiceOffset then self.choiceOffset=absolute-1 end
                self:RefreshChoices()
                local control=self.choiceRows[absolute-self.choiceOffset]
                for _,entry in ipairs(self:GamepadCandidates(self.choiceWindow)) do if entry.control==control then self:GamepadFocus(entry); return end end
            end
        end
    end
    local left,top,right,bottom=current.control:GetScreenRect()
    local x,y=(left+right)/2,(top+bottom)/2
    local best,score
    for _,entry in ipairs(self:GamepadCandidates(self.gamepadRoot)) do
        local l,t,r,b=entry.control:GetScreenRect()
        local ex,ey=(l+r)/2-x,(t+b)/2-y
        local along=ex*dx+ey*dy
        local across=math.abs(ex*dy-ey*dx)
        local distance=along+across*4
        if along>2 and (not score or distance<score) then best,score=entry,distance end
    end
    if best then self:HideTooltip(); self:GamepadFocus(best) end
end
function C:GamepadSelect()
    local focus=self.gamepadFocus
    if focus and focus.callback then focus.callback() end
    self:SyncGamepad()
end
function C:GamepadBack()
    if Shown(self.tooltipWindow) then self:HideTooltip()
    elseif Shown(self.choiceWindow) then self:HideChoiceMenu()
    elseif Shown(self.legacyImportWindow) then self:CloseLegacyImportDialog()
    elseif Shown(self.exportWindow) then self:SetWindowHidden(self.exportWindow,true)
    elseif Shown(self.window) then self:SetWindowHidden(self.window,true) end
    self:SyncGamepad()
end
function C:GamepadDetails()
    local entry=self.gamepadFocus
    if not entry then return end
    local reward=entry.reward and entry.reward()
    local text=reward and self:RewardDescription(reward) or entry.description and entry.description()
    if text and text~="" then self:ShowTooltip(entry.control,text) end
end
function C:GamepadSetting(option)
    if option.type=="checkbox" then option.setFunc(not option.getFunc())
    elseif option.type=="button" then option.func()
    else
        local entries={}
        local function Add(name,value)
            entries[#entries+1]={name=tostring(name),callback=function()
                option.setFunc(value)
                if option.requiresReload then self:ShowTooltip(self.window,option.tooltip) end
                self:SyncGamepad()
            end}
        end
        if option.type=="dropdown" then
            for i,name in ipairs(option.choices) do Add(name,option.choicesValues and option.choicesValues[i] or name) end
        elseif option.type=="slider" then
            for value=option.min,option.max,option.step or 1 do Add(value,value) end
        elseif option.type=="colorpicker" then
            for _,preset in ipairs({{"Blue",0.41,0.84,1},{"Purple",0.7,0.44,1},{"Gold",0.91,0.8,0.52},{"White",1,1,1}}) do
                local color=preset
                entries[#entries+1]={name=C.L(color[1]),callback=function() option.setFunc(color[2],color[3],color[4]) end}
            end
        end
        self:ShowChoiceMenu(self.window,option.name,entries)
    end
end
function C:GamepadSettings()
    local entries={}
    for _,option in ipairs(self:SettingsControls()) do
        if option.type~="header" and option.type~="description" then
            local data=option
            local name=option.name
            if option.getFunc and option.type~="colorpicker" then
                local value=option.getFunc()
                local display=type(value)=="boolean" and (value and C.L("ON") or C.L("OFF")) or tostring(value)
                if option.type=="dropdown" then
                    for i,label in ipairs(option.choices) do if (option.choicesValues and option.choicesValues[i] or label)==value then display=label end end
                end
                name=name..": "..display
            end
            entries[#entries+1]={name=name,callback=function() self:GamepadSetting(data) end}
        end
    end
    self:ShowChoiceMenu(self.window,C.L("Settings"),entries)
end
function C:GamepadOptions()
    local focus=self.gamepadFocus
    local entries={}
    local function Add(name,callback) entries[#entries+1]={name=C.L(name),callback=callback} end
    Add("Details",function() self.gamepadFocus=focus; self:GamepadDetails() end)
    Add("Select Crate Type",function() self:ShowCrateMenu() end)
    Add("All reward types",function() self:ShowCategoryMenu() end)
    Add("Search",function() self:GamepadSearch() end)
    Add("Clear",function() self.searchBox:SetText("") end)
    Add("Settings",function() self:GamepadSettings() end)
    Add("Import Crown Crate Tracker History",function() self:OpenLegacyImportDialog() end)
    Add("Export CSV",function() self:ShowExport() end)
    Add("Reload UI",function() if ReloadUI then ReloadUI() end end)
    self:ShowChoiceMenu(self.window,C.L("Controller options"),entries)
end
function C:GamepadSearch()
    self.gamepadEditing=true; self:SyncGamepad()
    self.searchBox:TakeFocus()
    -- ESO's native edit control handles the PC virtual keyboard. Release our
    -- action layer until editing finishes so it cannot consume text input.
end
function C:GamepadCommand(command)
    if not self.gamepadLayerActive then return end
    if command=="up" then self:GamepadMove(0,-1)
    elseif command=="down" then self:GamepadMove(0,1)
    elseif command=="left" then self:GamepadMove(-1,0)
    elseif command=="right" then self:GamepadMove(1,0)
    elseif command=="select" then self:GamepadSelect()
    elseif command=="back" then self:GamepadBack()
    elseif command=="details" then self:GamepadDetails()
    elseif command=="collections" then
        local entry=self.gamepadFocus; local reward=entry and entry.reward and entry.reward()
        if reward then self:OpenCollectible(reward); self:SyncGamepad() end
    elseif command=="options" and self.gamepadRoot==self.window then self:GamepadOptions()
    elseif (command=="previousTab" or command=="nextTab") and self.gamepadRoot==self.window then
        local views={"History","Reward rates","Codex","Status"}
        local index=1; for i,name in ipairs(views) do if name==self.view then index=i end end
        self.view=views[((index-1+(command=="nextTab" and 1 or -1))%#views)+1]
        self.page,self.scrollOffset=1,0; self:RefreshUI()
    elseif command=="previousPage" or command=="nextPage" then
        local direction=command=="nextPage" and 1 or -1
        if self.gamepadRoot==self.choiceWindow then
            self.choiceOffset=math.max(0,math.min(math.max(0,#self.choiceEntries-self.choiceVisible),self.choiceOffset+direction*self.choiceVisible)); self:RefreshChoices()
        elseif self.gamepadRoot==self.exportWindow then self:ExportPage(direction)
        elseif self.gamepadRoot==self.window then self:MoveRows(direction) end
    end
    self:SyncGamepad()
    return true
end
