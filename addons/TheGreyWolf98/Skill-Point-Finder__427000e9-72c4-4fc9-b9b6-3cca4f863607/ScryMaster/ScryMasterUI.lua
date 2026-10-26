local SM = ScryMaster
local WM = WINDOW_MANAGER
local FONT = "$(GAMEPAD_MEDIUM_FONT)|30|soft-shadow-thin"
local TITLE_FONT = "$(GAMEPAD_MEDIUM_FONT)|38|soft-shadow-thick"
local SMALL = "$(GAMEPAD_MEDIUM_FONT)|26|soft-shadow-thin"
local ROW = 64
local function label(parent, text, x, y, w, h, font)
    local c = WM:CreateControl(nil, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, h)
    c:SetFont(font or FONT)
    c:SetText(text or "")
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return c
end
local function backdrop(parent, x, y, w, h, r, g, b, a)
    local c = WM:CreateControl(nil, parent, CT_BACKDROP)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, h)
    c:SetCenterColor(r, g, b, a)
    c:SetEdgeColor(.55, .36, .13, 1)
    return c
end
local function button(parent, text, x, y, w, callback)
    local c = WM:CreateControl(nil, parent, CT_BUTTON)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, 42)
    backdrop(c, 0, 0, w, 42, .13, .18, .24, 1)
    local t = label(c, text, 8, 0, w - 16, 42)
    t:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c:SetHandler("OnClicked", callback)
    return c, t
end
function SM:CycleFilter()
    self.filter=self.filter % #self.filters+1
    self.selected=1; self.results={}
    self:Refresh()
end
function SM:MoveSelection(delta)
    if self.focus=="categories" then
        self.categorySelected=math.max(1,math.min(#self.categories,self.categorySelected+delta))
    else self.selected=math.max(1,math.min(#self.results,self.selected+delta)) end
    self:Refresh(false)
end
function SM:Select()
    if self.focus=="results" then
        local e=self.results[self.selected]
        if e and e.isGroup then
            self.expanded[e.id]=not self.expanded[e.id]
            self:Refresh()
        end
        return
    end
    local cat=self.categories[self.categorySelected]
    if cat then
        self.zone=cat.id; self.selected=1; self.results={}
        self:Refresh()
    end
end
function SM:Page(delta)
    if self.focus=="categories" then self:MoveSelection(delta*self.rowCount); return end
    local last=math.max(1,math.ceil(#self.results/self.rowCount))
    local page=math.max(1,math.min(last,self.page+delta))
    self.selected=(page-1)*self.rowCount+1
    self:Refresh(false)
end
function SM:Refresh(rebuild)
    if not self.window then return end
    if rebuild~=false or not self.results then self:BuildResults() end
    self.page=math.floor((self.selected-1)/self.rowCount)+1
    local s=self.stats
    if self.zone == -2 or self.zone == -3 then
        self.summary:SetText(s.all..(self.zone == -2 and " mythics" or " sets").."  |  "..s.dug.." fully dug  |  "..s.unfinished.." codex unfinished")
    else
        self.summary:SetText(s.all.." antiquities  |  "..s.dug.." dug  |  "..(s.all-s.dug).." never dug  |  "..s.unfinished.." codex unfinished")
    end
    self.filterLabel:SetText("Filter: "..self.filters[self.filter])
    local reading=self.scanning and (IsUnitInCombat("player") and "  |  Reading paused: combat" or "  |  Reading...") or ""
    self.subtitle:SetText("Live game progress: "..self:Clean(GetUnitName("player"))..reading)
    self.pages:SetText(#self.results.." rows  |  Page "..self.page.."/"..math.max(1,math.ceil(#self.results/self.rowCount)))
    self.focusLabel:SetText(self.focus=="categories" and "CATEGORIES [stick]" or "CATEGORIES")
    local offset=math.max(0,self.categorySelected-self.rowCount)
    for i,row in ipairs(self.categoryRows) do
        row.index=offset+i
        local cat=self.categories[row.index]
        row.control:SetHidden(not cat)
        if cat then
            local active=self.focus=="categories" and row.index==self.categorySelected
            row.background:SetCenterColor(active and .16 or .06,active and .25 or .09,active and .34 or .13,1)
            row.text:SetText((cat.id==self.zone and "|c80c8ff> " or "")..cat.name.."|r")
        end
    end
    for i,row in ipairs(self.resultRows) do
        row.index=(self.page-1)*self.rowCount+i
        local e=self.results[row.index]
        row.control:SetHidden(not e)
        if e then
            local active=self.focus=="results" and row.index==self.selected
            row.background:SetCenterColor(active and .16 or .055,active and .24 or .075,active and .32 or .105,1)
            local grouped=self.zone == -2 or self.zone == -3
            if e.isGroup then
                row.text:SetText("|cffcc80"..(self.expanded[e.id] and "[-] " or "[+] ")..e.name.."|r")
            else row.text:SetText((grouped and "    " or "")..e.name) end
            local dug=e.dug>0 and ("|c85df9cDug "..e.dug.."|r") or "|cffb36bNever dug|r"
            if e.isGroup then
                dug=e.dugPieces.."/"..e.pieces.." fragments dug"
            elseif grouped then dug=e.zoneName.."  |  "..dug end
            local codex=e.complete and "|c85df9c" or "|c9fcaff"
            row.status:SetText(dug.."  |  "..codex..self:CodexText(e).."|r")
        end
    end
    self.detail:SetText(self:DetailText(self.results[self.selected]))
end
function SM:UpdateDirectionalInput()
    if self.search:HasFocus() then return end
    local now=GetFrameTimeMilliseconds()
    local x,y=DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK_NO_KEYBOARD)
    DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)
    if math.abs(x)<.35 and math.abs(y)<.35 then self.nextInput=0; return end
    if now<(self.nextInput or 0) then return end
    self.nextInput=now+180
    if math.abs(x)>math.abs(y) then
        self.focus=x>0 and "results" or "categories"; self:Refresh(false)
    else self:MoveSelection(y>0 and -1 or 1) end
end
function SM:CreateWindow()
    self.zone,self.filter,self.selected,self.categorySelected,self.page=0,1,1,1,1
    self.focus="categories"
    local w=math.min(1550,GuiRoot:GetWidth()-80)
    local h=math.min(900,GuiRoot:GetHeight()-180)
    local left=math.floor(w*.27)
    local listX,listY=left+42,238
    self.rowCount=math.max(1,math.floor((h-listY-180)/ROW))
    local panel=WM:CreateTopLevelWindow("ScryMasterWindow")
    self.window=panel
    panel:SetDimensions(w,h); panel:SetAnchor(CENTER,GuiRoot,CENTER,0,-60)
    panel:SetHidden(true); panel:SetMouseEnabled(true)
    backdrop(panel,0,0,w,h,.025,.035,.055,.98)
    label(panel,"SCRY MASTER",24,10,600,52,TITLE_FONT)
    local author=label(panel,"by @TheGreyWolf98",w-420,16,396,40,SMALL)
    author:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.subtitle=label(panel,"",24,65,w-48,38,SMALL)
    self.subtitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.summary=label(panel,"",24,104,w-48,38,SMALL)
    self.summary:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    local searchW=w-570
    backdrop(panel,24,153,searchW,44,.11,.15,.2,1)
    local search=WM:CreateControl("ScryMasterSearch",panel,CT_EDITBOX)
    self.search=search
    search:SetAnchor(TOPLEFT,panel,TOPLEFT,35,154); search:SetDimensions(searchW-22,42)
    search:SetFont(FONT); search:SetMaxInputChars(100); search:SetMouseEnabled(true)
    local hint=label(panel,"Search antiquity, set or zone...",35,154,searchW-22,42,SMALL)
    hint:SetColor(.6,.65,.7,1)
    search:SetHandler("OnTextChanged",function()
        hint:SetHidden(search:GetText()~="" or search:HasFocus())
        EVENT_MANAGER:UnregisterForUpdate(self.name.."Search")
        EVENT_MANAGER:RegisterForUpdate(self.name.."Search",150,function()
            EVENT_MANAGER:UnregisterForUpdate(self.name.."Search")
            self.selected=1; self.results={}; if self:Visible() then self:Refresh() end
        end)
    end)
    search:SetHandler("OnFocusGained",function()
        hint:SetHidden(true)
        if IsInGamepadPreferredMode() then ZO_GamepadEditBox_FocusGained(search) end
    end)
    search:SetHandler("OnFocusLost",function()
        if IsInGamepadPreferredMode() then ZO_GamepadEditBox_FocusLost(search) end
        hint:SetHidden(search:GetText()~="")
    end)
    search:SetHandler("OnEnter",function() search:LoseFocus(); self.selected=1; self.results={}; self:Refresh() end)
    search:SetHandler("OnEscape",function() search:LoseFocus() end)
    local _,fl=button(panel,"",w-528,153,380,function() self:CycleFilter() end)
    self.filterLabel=fl; fl:SetFont(SMALL)
    local _,rl=button(panel,"Refresh",w-138,153,114,function() self:QueueRefresh() end)
    rl:SetFont(SMALL)
    self.focusLabel=label(panel,"ZONES",24,201,left,36,SMALL)
    self.pages=label(panel,"",listX,201,w-listX-24,36,SMALL)
    self.categoryRows,self.resultRows={},{}
    for i=1,self.rowCount do
        local y=listY+(i-1)*ROW
        local row={}
        row.control=WM:CreateControl(nil,panel,CT_BUTTON)
        row.control:SetAnchor(TOPLEFT,panel,TOPLEFT,24,y); row.control:SetDimensions(left,ROW-4)
        row.background=backdrop(row.control,0,0,left,ROW-4,.06,.09,.13,1)
        row.text=label(row.control,"",10,0,left-20,ROW-4)
        row.text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.control:SetHandler("OnClicked",function()
            self.categorySelected=row.index; self.focus="categories"; self:Select()
        end)
        self.categoryRows[i]=row
        local result,width={},w-listX-24
        result.control=WM:CreateControl(nil,panel,CT_BUTTON)
        result.control:SetAnchor(TOPLEFT,panel,TOPLEFT,listX,y); result.control:SetDimensions(width,ROW-4)
        result.background=backdrop(result.control,0,0,width,ROW-4,.055,.075,.105,1)
        result.text=label(result.control,"",12,0,width-24,34)
        result.text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        result.status=label(result.control,"",12,33,width-24,27,SMALL)
        result.status:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        result.control:SetHandler("OnClicked",function()
            self.selected=result.index; self.focus="results"; self:Refresh(false)
        end)
        self.resultRows[i]=result
    end
    local detailY=listY+self.rowCount*ROW+8
    self.detail=label(panel,"",24,detailY,w-48,h-detailY-38,SMALL)
    self.detail:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label(panel,"Stick: move / switch columns  |  A: choose / expand  |  X: filter  |  LB/RB: pages",24,h-34,w-48,30,SMALL)
    panel:SetHandler("OnMouseWheel",function(_,delta) self:MoveSelection(-delta) end)
    self.keybinds={alignment=KEYBIND_STRIP_ALIGN_CENTER,
 TGWScryMasterSocials.Keybind(),
        {name="Choose / expand",keybind="UI_SHORTCUT_PRIMARY",callback=function() self:Select() end},
        {name="Filter",keybind="UI_SHORTCUT_SECONDARY",callback=function() self:CycleFilter() end},
        {name="Refresh",keybind="UI_SHORTCUT_TERTIARY",callback=function() self:QueueRefresh() end},
        {name="Search",keybind="UI_SHORTCUT_RIGHT_STICK",callback=function() search:TakeFocus() end},
        {name="Previous page",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function() self:Page(-1) end},
        {name="Next page",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function() self:Page(1) end},
        {name="Back",keybind="UI_SHORTCUT_NEGATIVE",callback=function() SCENE_MANAGER:HideCurrentScene() end},
    }
    local scene=ZO_Scene:New("scryMaster",SCENE_MANAGER)
    self.scene=scene
    scene:AddFragment(ZO_SimpleSceneFragment:New(panel))
    if IsInGamepadPreferredMode() then
        if GAMEPAD_UI_MODE_FRAGMENT then scene:AddFragment(GAMEPAD_UI_MODE_FRAGMENT) end
        if KEYBIND_STRIP_GAMEPAD_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) end
        if KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT) end
    else
        if MOUSE_UI_MODE_FRAGMENT then scene:AddFragment(MOUSE_UI_MODE_FRAGMENT) end
        if KEYBIND_STRIP_FADE_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_FADE_FRAGMENT) end
    end
    if UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT) end
    scene:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_SHOWING then
            self:Refresh()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
            DIRECTIONAL_INPUT:Activate(self,panel)
        elseif state==SCENE_SHOWN then
            self:Scan()
        elseif state==SCENE_HIDING then
            search:LoseFocus(); self:StopScan(); self.dirty=true
            for _,suffix in ipairs({"Search","Refresh"}) do EVENT_MANAGER:UnregisterForUpdate(self.name..suffix) end
            DIRECTIONAL_INPUT:Deactivate(self)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
        end
    end)
end
function SM:Toggle()
    if not self.window then self:CreateWindow() end
    if SCENE_MANAGER:IsShowing("scryMaster") then SCENE_MANAGER:HideCurrentScene()
    else SCENE_MANAGER:Show("scryMaster") end
end
