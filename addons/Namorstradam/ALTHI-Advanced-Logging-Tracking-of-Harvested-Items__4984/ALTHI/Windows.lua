local A=ALTHarvestItems
function A:RegisterDialog(window)
    self.dialogs=self.dialogs or {}
    if self.dialogs[window] then return end
    window:SetHidden(true)
    self.dialogs[window]=true
    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then SCENE_MANAGER:RegisterTopLevel(window,false) end
end
function A:TopDialog()
    local top
    for window in pairs(self.dialogs or {}) do
        if not window:IsHidden() and (not top or (window.althiOrder or 0)>(top.althiOrder or 0)) then top=window end
    end
    return top
end
function A:InstallDialogEscape()
    if self.dialogEscapeInstalled or not ZO_PreHook or not SCENE_MANAGER
        or type(SCENE_MANAGER.OnToggleGameMenuBinding)~="function" then return end
    -- Handle ESC only while an ALTHI dialog is visible. Native confirmation
    -- dialogs take priority; without our windows the original method runs.
    ZO_PreHook(SCENE_MANAGER,"OnToggleGameMenuBinding",function()
        if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then return false end
        local top=self:TopDialog()
        if not top then return false end
        if top==self.languageWindow and top.firstRun then return true end
        self:CloseDialog(top); return true
    end)
    self.dialogEscapeInstalled=true
end
function A:ShowDialog(window)
    self:RegisterDialog(window)
    local parent=self:TopDialog()
    local ancestor=parent
    while ancestor do
        if ancestor==window then parent=nil; break end
        ancestor=ancestor.althiParent
    end
    if window.althiRoot then parent=nil end
    if window:IsHidden() then window.althiParent=parent~=window and parent or nil end
    self.dialogOrder=(self.dialogOrder or 0)+1; window.althiOrder=self.dialogOrder
    self:InstallDialogEscape()
    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then SCENE_MANAGER:ShowTopLevel(window) end
    self:Front(window)
end
function A:CloseDialog(window)
    if not window or window:IsHidden() or window.althiClosing then return false end
    if window==self.languageWindow and window.firstRun then return false end
    window.althiClosing=true
    for child in pairs(self.dialogs or {}) do
        if child~=window and child.althiParent==window and not child:IsHidden() then self:CloseDialog(child) end
    end
    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then SCENE_MANAGER:HideTopLevel(window)
    else window:SetHidden(true) end
    window.althiParent=nil
    window.althiClosing=nil
    return true
end
function A:CloseAllDialogs()
    for window in pairs(self.dialogs or {}) do self:CloseDialog(window) end
end
function A:CloseIcon(window)
    if window.closeIcon then return window.closeIcon end
    local button=self:Button(window,"X",30,function() self:CloseDialog(window) end)
    button:SetFont("ZoFontWinH3"); button:SetAnchor(TOPRIGHT,window,TOPRIGHT,-18,12)
    window.closeIcon=button
    return button
end
