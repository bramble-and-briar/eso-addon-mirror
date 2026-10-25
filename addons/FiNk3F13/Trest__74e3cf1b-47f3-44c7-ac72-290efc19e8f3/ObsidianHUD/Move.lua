local O=ObsidianHUD
local dragging,lastInput,lastX,lastY,previousUI,previousCamera
local function now() return GetFrameTimeSeconds() end

local function savePosition()
    local root=O.root
    -- Screen bounds already include the resource window's scale.
    O.vars.x=root:GetLeft()+root:GetWidth()/2-GuiRoot:GetWidth()/2
    O.vars.y=root:GetTop()+root:GetHeight()-GuiRoot:GetHeight()
end

function O.StopMove()
    if not O.moving then return end
    O.root:StopMovingOrResizing()
    savePosition()
    O.moving=false; dragging=false
    EVENT_MANAGER:UnregisterForUpdate(O.name.."Move")
    O.root:SetMovable(false)
    O.root:SetMouseEnabled(false)
    O.root:SetDrawTier(DT_LOW)
    O.root:SetDrawLevel(0)
    O.moveOverlay:SetHidden(true)
    if previousUI==false and SCENE_MANAGER then SCENE_MANAGER:SetInUIMode(false) end
    if previousCamera==false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
    previousUI,previousCamera=nil,nil
    O.Refresh()
end

function O.MoveUpdate()
    if not O.moving then return end
    local root=O.root
    local x,y=root:GetLeft(),root:GetTop()
    local at=now()
    if dragging or x~=lastX or y~=lastY then savePosition(); lastInput=at end
    if SCENE_MANAGER and not SCENE_MANAGER:IsInUIMode() then SCENE_MANAGER:SetInUIMode(true) end
    if SetGameCameraUIMode and IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then SetGameCameraUIMode(true) end
    local sx=GetGamepadRightStickX and GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE) or 0
    local sy=GetGamepadRightStickY and GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
    if not dragging and (math.abs(sx)>=0.05 or math.abs(sy)>=0.05) then
        x=math.max(0,math.min(math.max(0,GuiRoot:GetWidth()-root:GetWidth()),x+sx*22))
        y=math.max(0,math.min(math.max(0,GuiRoot:GetHeight()-root:GetHeight()),y-sy*22))
        O.vars.x=x+root:GetWidth()/2-GuiRoot:GetWidth()/2
        O.vars.y=y+root:GetHeight()-GuiRoot:GetHeight()
        root:ClearAnchors()
        root:SetAnchor(BOTTOM,GuiRoot,BOTTOM,O.vars.x,O.vars.y)
        lastInput=at
    end
    lastX,lastY=root:GetLeft(),root:GetTop()
    if at-lastInput>=3 then O.StopMove() end
end

function O.StartMove()
    if O.nativeMoving then O.StopNativeMove() end
    if O.moving then O.StopMove(); return end
    if not O.vars.enabled then d("Obsidian HUD: Bitte zuerst das HUD aktivieren."); return end
    O.moving=true; dragging=false
    previousUI=SCENE_MANAGER and SCENE_MANAGER:IsInUIMode()
    if SCENE_MANAGER then SCENE_MANAGER:SetInUIMode(true) end
    previousCamera=IsGameCameraUIModeActive and IsGameCameraUIModeActive()
    if SetGameCameraUIMode then SetGameCameraUIMode(true) end
    O.root:SetMovable(true)
    O.root:SetMouseEnabled(true)
    O.root:SetDrawTier(DT_HIGH)
    O.root:SetDrawLevel(10)
    O.moveOverlay:SetHidden(false)
    O.moveHint:SetText("Move UI: Ressourcen-HUD mit Maus oder rechtem Stick verschieben.\nSpeichert nach 3 Sekunden ohne Bewegung.")
    lastInput=now(); lastX,lastY=O.root:GetLeft(),O.root:GetTop()
    EVENT_MANAGER:RegisterForUpdate(O.name.."Move",16,O.MoveUpdate)
    O.Tick()
end

function O.CreateMoveUI()
    local root=O.root
    root:SetMovable(false)
    root:SetClampedToScreen(true)
    root:SetHandler("OnMouseDown",function(control,button)
        if O.moving and button==MOUSE_BUTTON_INDEX_LEFT then
            dragging=true; lastInput=now(); control:StartMoving()
        end
    end)
    root:SetHandler("OnMouseUp",function(control,button)
        if O.moving and dragging and button==MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing(); dragging=false; savePosition(); lastInput=now()
        end
    end)
    root:SetHandler("OnMoveStop",function() if O.moving then savePosition() end end)
    local overlay=WINDOW_MANAGER:CreateTopLevelWindow("ObsidianHUDMoveOverlay")
    O.moveOverlay=overlay
    overlay:SetAnchorFill(GuiRoot)
    overlay:SetDrawTier(DT_HIGH)
    overlay:SetMouseEnabled(false)
    overlay:SetHidden(true)
    for _,horizontal in ipairs({true,false}) do
        local line=WINDOW_MANAGER:CreateControl(nil,overlay,CT_BACKDROP)
        line:SetAnchor(CENTER,overlay,CENTER,0,0)
        line:SetDimensions(horizontal and GuiRoot:GetWidth() or 1,horizontal and 1 or GuiRoot:GetHeight())
        line:SetCenterColor(1,1,1,0.35)
        line:SetEdgeColor(0,0,0,0)
        line:SetMouseEnabled(false)
    end
    local hint=O.Label(overlay,20)
    O.moveHint=hint
    hint:SetAnchor(TOP,overlay,TOP,0,80)
    hint:SetText("Move UI: Ressourcen-HUD mit Maus oder rechtem Stick verschieben.\nSpeichert nach 3 Sekunden ohne Bewegung.")
end
