local H=HUDMoveUI
H.captured={}
local function clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
H.Clamp=clamp
function H.Profile()
    return (IsConsoleUI() or IsInGamepadPreferredMode()) and "controller" or "keyboard"
end
function H.Config(entry)
    local profile=H.Profile()
    H.saved.layouts[profile]=H.saved.layouts[profile] or {}
    local entries=H.saved.layouts[profile]
    entries[entry.key]=entries[entry.key] or {enabled=false,scale=1}
    return entries[entry.key]
end
function H.Print(text) d("[HUD Move UI] "..text) end
function H.Bounds(control,entry)
    local x,y=control:GetLeft(),control:GetTop()
    local right,bottom=control:GetRight(),control:GetBottom()
    local w,h=right and x and right-x or 0,bottom and y and bottom-y or 0
    if not x or not y or w<1 or h<1 then
        return entry.x*GuiRoot:GetWidth(),entry.y*GuiRoot:GetHeight(),entry.w,entry.h
    end
    return x+w/2,y+h/2,w,h
end
local function capture(control)
    local old=H.captured[control]
    if old then return old end
    old={scale=control:GetScale(),anchors={}}
    for i=0,control:GetNumAnchors()-1 do
        local valid,point,relative,relativePoint,x,y=control:GetAnchor(i)
        if valid then old.anchors[#old.anchors+1]={point,relative,relativePoint,x,y} end
    end
    H.captured[control]=old
    return old
end
local function ownAnchor(control,old)
    local valid,point,relative,relativePoint,x,y=control:GetAnchor(0)
    return old.owned and control:GetNumAnchors()==1 and valid and point==CENTER and relative==GuiRoot
        and relativePoint==TOPLEFT and math.abs(x-old.owned[1])<.05 and math.abs(y-old.owned[2])<.05
end
function H.Release(control)
    local old=H.captured[control]
    if not old then return end
    -- Restore only changes still owned by this addon; do not overwrite another mover.
    if ownAnchor(control,old) then
        control:ClearAnchors()
        for _,a in ipairs(old.anchors) do control:SetAnchor(unpack(a)) end
    end
    if old.ownedScale and math.abs(control:GetScale()-old.ownedScale)<.0001 then control:SetScale(old.scale) end
    H.captured[control]=nil
end
local function apply(entry,control,cfg)
    local old=capture(control)
    if not cfg.x or not cfg.y then
        local cx,cy=H.Bounds(control,entry)
        cfg.x,cfg.y=cx/GuiRoot:GetWidth(),cy/GuiRoot:GetHeight()
    end
    local scale=old.scale*clamp(cfg.scale or 1,.5,2)
    if math.abs(control:GetScale()-scale)>.0001 then control:SetScale(scale); old.transform=nil end
    old.ownedScale=scale
    local sw,sh=GuiRoot:GetWidth(),GuiRoot:GetHeight()
    local _,_,width,height=H.Bounds(control,entry)
    local halfW,halfH=math.min(width/(2*sw),.5),math.min(height/(2*sh),.5)
    cfg.x,cfg.y=clamp(cfg.x,halfW,1-halfW),clamp(cfg.y,halfH,1-halfH)
    local factor=control.GetEffectiveScale and control:GetEffectiveScale() or scale
    local t=old.transform
    if not t or t.sw~=sw or t.sh~=sh or t.factor~=factor then
        -- Calibrate inherited/scaled anchors instead of assuming screen pixels equal offsets.
        control:ClearAnchors(); control:SetAnchor(CENTER,GuiRoot,TOPLEFT,0,0)
        local ox,oy=H.Bounds(control,entry)
        control:ClearAnchors(); control:SetAnchor(CENTER,GuiRoot,TOPLEFT,1,1)
        local ax,ay=H.Bounds(control,entry)
        -- Zero-sized hidden controls have no measurable transform yet.
        local left,top,right,bottom=control:GetLeft(),control:GetTop(),control:GetRight(),control:GetBottom()
        local measurable=left and top and right and bottom and right-left>0 and bottom-top>0
        t={ox=measurable and ox or 0,oy=measurable and oy or 0,
            fx=measurable and math.abs(ax-ox)>.0001 and ax-ox or 1,
            fy=measurable and math.abs(ay-oy)>.0001 and ay-oy or 1,sw=sw,sh=sh,factor=factor}
        old.transform=measurable and t or nil
    end
    local x=(clamp(cfg.x,0,1)*sw-t.ox)/t.fx
    local y=(clamp(cfg.y,0,1)*sh-t.oy)/t.fy
    local valid,point,relative,relativePoint,px,py=control:GetAnchor(0)
    if not(valid and control:GetNumAnchors()==1 and point==CENTER and relative==GuiRoot
        and relativePoint==TOPLEFT and math.abs(px-x)<.05 and math.abs(py-y)<.05) then
        control:ClearAnchors(); control:SetAnchor(CENTER,GuiRoot,TOPLEFT,x,y)
    end
    old.owned={x,y}
end
function H.Apply(entry)
    local control=H.Resolve(entry)
    if not control then return false end
    local cfg=H.Config(entry)
    local ok,err=pcall(function()
        if H.saved.enabled and cfg.enabled then apply(entry,control,cfg) else H.Release(control) end
    end)
    entry.error=not ok and tostring(err) or nil
    return ok
end
function H.Refresh()
    local profile=H.Profile()
    if H.lastProfile and H.lastProfile~=profile then
        H.StopMove(false)
        for c in pairs(H.captured) do H.Release(c) end
    end
    H.lastProfile=profile
    for _,entry in ipairs(H.entries) do H.Apply(entry) end
end
function H.Reset(entry)
    if H.moving then H.StopMove(false) end
    local control=H.Resolve(entry)
    if control then H.Release(control) end
    H.Config(entry) -- Ensure the profile exists even before the first player activation.
    H.saved.layouts[H.Profile()][entry.key]={enabled=false,scale=1}
end
function H.ResetAll()
    H.StopMove(false)
    for control in pairs(H.captured) do H.Release(control) end
    H.saved.layouts={controller={},keyboard={}}
end
function H.Initialize()
    H.saved=ZO_SavedVars:NewAccountWide("HUDMoveUISavedVariables",1,nil,
        {enabled=true,speed=500,layouts={controller={},keyboard={}},discovered={}})
    H.RestoreDiscovered()
    H.CreateSettings()
    EVENT_MANAGER:RegisterForEvent(H.name,EVENT_PLAYER_ACTIVATED,function()
        H.Refresh()
        if not H.discoveryStarted then H.StartDiscovery() end
    end)
    EVENT_MANAGER:RegisterForEvent(H.name,EVENT_PLAYER_COMBAT_STATE,function(_,inCombat)
        if inCombat then H.StopMove(false) else H.Refresh() end
    end)
    EVENT_MANAGER:RegisterForEvent(H.name,EVENT_PLAYER_DEACTIVATED,function() H.StopMove(false) end)
    EVENT_MANAGER:RegisterForUpdate(H.name.."Refresh",500,function() if not H.moving then H.Refresh() end end)
    SLASH_COMMANDS["/hudmoveui"]=function(text)
        if text=="stop" then H.StopMove(true) elseif H.byKey[text] then H.StartMove(H.byKey[text])
        else H.Print("Einstellungen > Addons > HUD Move UI. Move UI auswaehlen; rechter Stick bewegt, Kreuz speichert, Kreis bricht ab.") end
    end
end
EVENT_MANAGER:RegisterForEvent(H.name,EVENT_ADD_ON_LOADED,function(_,name)
    if name~=H.name then return end
    EVENT_MANAGER:UnregisterForEvent(H.name,EVENT_ADD_ON_LOADED)
    H.Initialize()
end)
