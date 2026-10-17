-- My UI Frame Editor: diagnostics only + emergency timeout recovery.
-- Does not change the editor's controller mappings or save positions.
local E = BUI and BUI.FrameEditor
if not E then return end
local D = {events={}, started=nil, lastAction="Noch keine Eingabe", timedOut=false}
BUI.MoveDiagnostics = D
local function ms()
    if type(GetFrameTimeMilliseconds)=="function" then return GetFrameTimeMilliseconds() end
    return 0
end
local function log(s)
    D.lastAction=tostring(s)
    D.events[#D.events+1]=D.lastAction
    if #D.events>7 then table.remove(D.events,1) end
    if MyUIDebug and MyUIDebug.Note then MyUIDebug.Note("Move Editor",D.lastAction) end
end
local function status()
    local guard=E.inputGuard
    local state=guard and guard.state
    local strip=rawget(_G,"KEYBIND_STRIP")
    local options=rawget(_G,"GAMEPAD_OPTIONS")
    local showing="?"
    if options and options.IsShowing then
        local ok,r=pcall(options.IsShowing,options)
        if ok then showing=tostring(r) end
    end
    return "active="..tostring(E.active).." mode="..tostring(E.mode).." BUI.move="..tostring(BUI.move)
      .." guard="..tostring(state~=nil).." keys="..tostring(strip~=nil)
      .." options="..showing.." frames="..tostring(E.frames and #E.frames or 0)
end
local function show()
    if not D.window and WINDOW_MANAGER and GuiRoot then
        local w=WINDOW_MANAGER:CreateTopLevelWindow("MyUI_MoveDiagnosticsWindow")
        w:SetDimensions(900,155)
        w:SetAnchor(TOP,GuiRoot,TOP,0,15)
        w:SetDrawTier(DT_HIGH)
        w:SetDrawLayer(DL_OVERLAY)
        w:SetMouseEnabled(false)
        local l=WINDOW_MANAGER:CreateControl("MyUI_MoveDiagnosticsLabel",w,CT_LABEL)
        l:SetAnchorFill(w)
        l:SetFont("$(MEDIUM_FONT)|19|soft-shadow-thick")
        l:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        l:SetColor(1,.9,.4,1)
        D.window,D.label=w,l
    end
    if D.window then
        local remaining=D.started and math.max(0,math.ceil((30000-(ms()-D.started))/1000)) or 30
        D.label:SetText("MY UI - MOVE DEBUG (automatischer Abbruch nach "..remaining.." s)\n"..status().."\nLetzte Aktion: "..D.lastAction)
        D.window:SetHidden(false)
    end
end
local names={"Activate","Deactivate","PrimaryAction","BeginMove","Nudge","ConfirmMove","CancelMove","Direction","HandleKeyDown","SelectDirection"}
for _,name in ipairs(names) do
    local original=E[name]
    if type(original)=="function" then
        E[name]=function(self,...)
            local a={...}
            log(name.."("..tostring(a[1] or "")..(a[2]~=nil and ","..tostring(a[2]) or "")..")")
            local ok,res=pcall(original,self,...)
            if not ok then log("FEHLER "..name..": "..tostring(res)); error(res) end
            return res
        end
    end
end
local originalMove=BUI.Menu and BUI.Menu.MoveFrames
if type(originalMove)=="function" then
    BUI.Menu.MoveFrames=function(move,...)
        log("MoveFrames("..tostring(move)..")")
        local ok,res=pcall(originalMove,move,...)
        if not ok then log("MoveFrames FEHLER "..tostring(res)); error(res) end
        return res
    end
end
local function forceStop()
    log("TIMEOUT/ABORT: PlayStation Eingaben freigeben")
    -- Do not directly re-enter MoveFrames(false): that path could throw and
    -- strand UI/camera ownership. The editor has an idempotent emergency exit.
    if type(E.EmergencyClose) == "function" then
        local ok, err = pcall(E.EmergencyClose)
        if not ok then log("EmergencyClose FEHLER: " .. tostring(err)) end
    end
    D.timedOut=true
end
if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForUpdate("MyUI_MoveDiagnosticTicker",1000,function()
        local on=(E.active==true or BUI.move==true or (E.inputGuard and E.inputGuard.state~=nil))
        if on then
            if not D.started then
                D.started=ms()
                D.timedOut=false
                log("Editor erkannt")
            end
            show()
            if not D.timedOut and ms()-D.started>=30000 then forceStop() end
        else
            D.started=nil
            if D.window then D.window:SetHidden(true) end
        end
    end)
end
if SLASH_COMMANDS then
    SLASH_COMMANDS["/movedebug"]=function()
        if type(d)=="function" then
            d("[Move Debug] "..status())
            for _,line in ipairs(D.events) do d("[Move Debug] "..line) end
        end
        show()
    end
    SLASH_COMMANDS["/moveabort"]=function() forceStop() end
end
log("Diagnose geladen, Timeout 30 Sekunden")
