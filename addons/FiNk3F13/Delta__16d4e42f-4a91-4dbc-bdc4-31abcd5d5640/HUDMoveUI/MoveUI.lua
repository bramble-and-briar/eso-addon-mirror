local H=HUDMoveUI
local LAYER="HUDMoveUI_Edit"
local overlay,border,hint
local function makeOverlay()
    if overlay then return end
    overlay=WINDOW_MANAGER:CreateTopLevelWindow("HUDMoveUIOverlay")
    overlay:SetAnchorFill(GuiRoot); overlay:SetDrawTier(DT_HIGH); overlay:SetMouseEnabled(false)
    border=WINDOW_MANAGER:CreateControl(nil,overlay,CT_BACKDROP)
    border:SetCenterColor(.08,.6,.8,.15); border:SetEdgeColor(.2,.9,1,1); border:SetEdgeTexture(nil,1,1,3)
    hint=WINDOW_MANAGER:CreateControl(nil,overlay,CT_LABEL)
    hint:SetAnchor(TOP,overlay,TOP,0,80); hint:SetDimensions(math.min(1100,GuiRoot:GetWidth()-60),180)
    hint:SetFont("ZoFontGamepad27"); hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay:SetHidden(true)
end
local function copy(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
local function sceneAllowed()
    if not SCENE_MANAGER then return true end
    local name=SCENE_MANAGER:GetCurrentSceneName()
    return name=="hud" or name=="hudui"
end
local function draw()
    local move=H.moving
    if not move then return end
    local _,_,w,h=H.Bounds(move.control,move.entry)
    w,h=math.max(w,120),math.max(h,32)
    border:ClearAnchors(); border:SetAnchor(CENTER,GuiRoot,TOPLEFT,move.cfg.x*GuiRoot:GetWidth(),move.cfg.y*GuiRoot:GetHeight())
    border:SetDimensions(math.min(w,GuiRoot:GetWidth()),math.min(h,GuiRoot:GetHeight()))
    hint:SetText("Move UI: "..move.entry.title.."\nRechter Stick: verschieben | Kreuz: speichern | Kreis: abbrechen\nSpeichert nach 3 Sekunden Stillstand. Ausserhalb von Move UI keine Tastenbelegung.")
end
function H.StopMove(save)
    local move=H.moving
    if not move then return end
    H.moving=nil
    EVENT_MANAGER:UnregisterForUpdate(H.name.."Move")
    if IsActionLayerActiveByName(LAYER) then RemoveActionLayerByName(LAYER) end
    if not save then
        for k in pairs(move.cfg) do move.cfg[k]=nil end
        for k,v in pairs(move.previous) do move.cfg[k]=v end
        H.saved.enabled=move.previousEnabled
    end
    if overlay then overlay:SetHidden(true) end
    if SCENE_MANAGER and move.previousUI~=nil then SCENE_MANAGER:SetInUIMode(move.previousUI) end
    if SetGameCameraUIMode and move.previousCamera~=nil then SetGameCameraUIMode(move.previousCamera) end
    H.Refresh()
    H.Print(save and (move.entry.title..": Position gespeichert.") or "Move UI abgebrochen; vorige Position wiederhergestellt.")
end
function H.MoveTick()
    local move=H.moving
    if not move then return end
    if move.profile~=H.Profile() then H.StopMove(false); return end
    local now=GetFrameTimeSeconds()
    if IsUnitInCombat("player") then H.StopMove(false); return end
    if not sceneAllowed() then
        if now-move.started<1 then move.lastTime=now; move.lastInput=now; return end
        H.StopMove(false); return
    end
    local dt=math.min(math.max(now-move.lastTime,0),.05); move.lastTime=now
    local x=GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE)
    local y=GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE)
    if math.abs(x)>.08 or math.abs(y)>.08 then
        local speed=H.Clamp(H.saved.speed or 500,100,1200)
        move.cfg.x=H.Clamp(move.cfg.x+x*speed*dt/GuiRoot:GetWidth(),.01,.99)
        move.cfg.y=H.Clamp(move.cfg.y-y*speed*dt/GuiRoot:GetHeight(),.01,.99)
        move.lastInput=now
        H.Apply(move.entry)
    end
    draw()
    if now-move.lastInput>=3 then H.StopMove(true) end
end
function H.StartMove(entry)
    if IsUnitInCombat("player") then H.Print("Move UI bitte ausserhalb des Kampfes starten."); return false end
    H.StopMove(true)
    local control=H.Resolve(entry)
    if not control then H.Print(entry.title..": Auf diesem Client noch nicht verfuegbar."); return false end
    local cfg=H.Config(entry)
    local previous=copy(cfg)
    local enabled=H.saved.enabled
    if not cfg.x or not cfg.y then
        local x,y=H.Bounds(control,entry)
        cfg.x,cfg.y=x/GuiRoot:GetWidth(),y/GuiRoot:GetHeight()
    end
    cfg.enabled=true; H.saved.enabled=true
    if not H.Apply(entry) then
        for k in pairs(cfg) do cfg[k]=nil end; for k,v in pairs(previous) do cfg[k]=v end
        H.saved.enabled=enabled
        local err=entry.error
        H.Apply(entry)
        H.Print("Dieses Element laesst sich gerade nicht verschieben: "..tostring(err)); return false
    end
    makeOverlay()
    -- We explicitly leave settings for the HUD; ending edit mode must release the camera.
    local previousUI,previousCamera=false,false
    SCENE_MANAGER:ShowBaseScene()
    SCENE_MANAGER:SetInUIMode(true)
    if SetGameCameraUIMode then SetGameCameraUIMode(true) end
    local now=GetFrameTimeSeconds()
    H.moving={entry=entry,control=control,cfg=cfg,previous=previous,previousEnabled=enabled,profile=H.Profile(),
        started=now,lastTime=now,lastInput=now,previousUI=previousUI,previousCamera=previousCamera}
    PushActionLayerByName(LAYER)
    overlay:SetHidden(false); draw()
    EVENT_MANAGER:RegisterForUpdate(H.name.."Move",16,H.MoveTick)
    return true
end
