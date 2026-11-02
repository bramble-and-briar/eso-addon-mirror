-- Native cursor release and edge-aware folding. Never assign or replace ESO bindings.
local A=ALTHarvestItems
local compactHeight=150
function A:SuiteBaseScene()
    return not SCENE_MANAGER or not SCENE_MANAGER.IsShowingBaseScene or SCENE_MANAGER:IsShowingBaseScene()
end
function A:StopSuiteMouse(restore)
    local owned=self.suiteMouseReleased
    self.suiteMouseReleased=nil; EVENT_MANAGER:UnregisterForUpdate('ALTHISuiteMouse')
    if owned and restore then self:EndColumnDrag() end
    if owned and restore and self:SuiteBaseScene() and not self:TopDialog()
        and SetGameCameraUIMode and IsGameCameraUIModeActive and IsGameCameraUIModeActive() then SetGameCameraUIMode(false) end
end
function A:ReleaseSuiteMouse()
    if not SetGameCameraUIMode or not IsGameCameraUIModeActive or not self:SuiteBaseScene() or self:TopDialog()
        or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog()) then return end
    if IsGameCameraUIModeActive() then return end -- Do not take ownership of native/menu mouse mode.
    SetGameCameraUIMode(true); self.suiteMouseReleased=true
    EVENT_MANAGER:RegisterForUpdate('ALTHISuiteMouse',50,function()
        if not self:SuiteBaseScene() or self:TopDialog() or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog()) then self:StopSuiteMouse(false)
        elseif not IsGameCameraUIModeActive() then self:StopSuiteMouse(false)
        elseif IsPlayerTryingToMove and IsPlayerTryingToMove() then self:StopSuiteMouse(true) end
    end)
end
function A:AnchorSuite(top,left)
    local screen=GuiRoot:GetHeight() or 1080
    top=math.max(0,math.min(top,math.max(0,screen-self.window:GetHeight())))
    self.window:ClearAnchors(); self.window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
    self.db.x,self.db.y=left,top
end
function A:ToggleMinimized()
    if not self.window then return end
    self:EndColumnDrag()
    local ui=self.db.ui; local window=self.window
    local top,left=window:GetTop(),window:GetLeft(); local height=window:GetHeight()
    local screen=GuiRoot:GetHeight() or 1080
    if not ui.minimized then
        self.db.height=height
        ui.foldEdge=(top+height/2>=screen/2) and 'bottom' or 'top'
    end
    local edge=ui.foldEdge or ((top+height/2>=screen/2) and 'bottom' or 'top')
    ui.minimized=not ui.minimized
    local target=ui.minimized and compactHeight or math.min(screen,1100,math.max(400,self.db.height))
    window:SetDimensionConstraints(ui.showStock and 620 or 480,ui.minimized and compactHeight or 400,1800,ui.minimized and compactHeight or 1100)
    window:SetHeight(target)
    local anchor=edge=='bottom' and top+height or top
    self:AnchorSuite(edge=='bottom' and anchor-target or anchor,left)
    self.minimizeButton:SetText(ui.minimized and 'v' or '^')
    self:Refresh()
    -- Refresh may enforce a taller native layout. Keep the chosen edge fixed.
    self:AnchorSuite(edge=='bottom' and anchor-window:GetHeight() or anchor,left)
end
local language=A.InitializeLanguage
function A:InitializeLanguage()
    language(self)
    ZO_CreateStringId('SI_BINDING_NAME_ALTHI_MOUSE',self:T('BIND_SUITE_MOUSE'))
    ZO_CreateStringId('SI_BINDING_NAME_ALTHI_MINIMIZE',self:T('BIND_SUITE_MINIMIZE'))
end
local create=A.CreateWindow
function A:CreateWindow()
    create(self)
    if self.db.ui.minimized then
        self.window:SetDimensionConstraints(self.db.ui.showStock and 620 or 480,compactHeight,1800,compactHeight)
        self.window:SetHeight(compactHeight)
        self:AnchorSuite(self.db.y,self.db.x)
    end
    self:Refresh()
end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    if not self.titleLabel then return end
    self.titleLabel:SetWidth(self.window:GetWidth()-118)
    self.titleLabel:SetText(self:GoldText('ALTHI Suite')..' – '..self.version)
    self.subtitleLabel:SetHidden(false); self.subtitleLabel:SetText('By Althi & @Namorstradam')
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    EVENT_MANAGER:RegisterForEvent('ALTHISuiteMouse',EVENT_PLAYER_DEACTIVATED,function() self:StopSuiteMouse(false) end)
end
