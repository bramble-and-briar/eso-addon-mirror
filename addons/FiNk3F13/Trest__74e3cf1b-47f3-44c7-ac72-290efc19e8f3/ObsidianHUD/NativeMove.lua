local O=ObsidianHUD
local originals={}
local move
local currentProfile
local titles={skills="Skillleiste und Backbar",ultimate="Ultimate und Backbar",quickslot="Traenke / Schnellzugriff",buffs="Eigene Buffanzeige"}
local function mode() return IsInGamepadPreferredMode and IsInGamepadPreferredMode() and "controller" or "keyboard" end
local function positions(profile)
    profile=profile or mode()
    O.vars.hudPositions[profile]=O.vars.hudPositions[profile] or {}
    return O.vars.hudPositions[profile]
end
local function target(key)
    if key=="buffs" then return ZO_BuffDebuffTopLevelSelfContainer end
    if not ZO_ActionBar_GetButton then return nil end
    local slot=key=="skills" and 3 or (key=="ultimate" and 8 or 1)
    local button=ZO_ActionBar_GetButton(slot,key=="quickslot" and HOTBAR_CATEGORY_QUICKSLOT_WHEEL or nil)
    return button and button.slot
end
local function capture(control)
    if originals[control] then return end
    local anchors={}
    for i=0,control:GetNumAnchors()-1 do
        local valid,point,relativeTo,relativePoint,x,y=control:GetAnchor(i)
        if valid then anchors[#anchors+1]={point,relativeTo,relativePoint,x,y} end
    end
    originals[control]={anchors=anchors}
end
local function anchor(control,x,y)
    capture(control)
    local valid,point,relativeTo,relativePoint,oldX,oldY=control:GetAnchor(0)
    if valid and point==CENTER and relativeTo==GuiRoot and relativePoint==TOPLEFT
        and math.abs(oldX-x)<0.1 and math.abs(oldY-y)<0.1 then
        originals[control].owned={x,y}; return
    end
    control:ClearAnchors()
    control:SetAnchor(CENTER,GuiRoot,TOPLEFT,x,y)
    originals[control].owned={x,y}
end
function O.ReleaseNativePositions()
    for control,old in pairs(originals) do
        local valid,point,relativeTo,relativePoint,x,y=control:GetAnchor(0)
        local owned=old.owned
        if owned and valid and point==CENTER and relativeTo==GuiRoot and relativePoint==TOPLEFT
            and math.abs(x-owned[1])<0.1 and math.abs(y-owned[2])<0.1 then
            control:ClearAnchors()
            for _,args in ipairs(old.anchors) do control:SetAnchor(unpack(args,1,5)) end
        end
    end
    originals={}
end
function O.UpdateNativePositions()
    if not O.vars.enabled then O.ReleaseNativePositions(); return end
    local profile=mode()
    if currentProfile~=profile then O.ReleaseNativePositions(); currentProfile=profile end
    for key,pos in pairs(positions()) do
        local control=titles[key] and target(key)
        if control then
            local w,h=control:GetWidth(),control:GetHeight()
            local x=math.max(w/2,math.min(GuiRoot:GetWidth()-w/2,pos.x*GuiRoot:GetWidth()))
            local y=math.max(h/2,math.min(GuiRoot:GetHeight()-h/2,pos.y*GuiRoot:GetHeight()))
            anchor(control,x,y)
        end
    end
end
local function saveMove()
    local handle=O.nativeMoveHandle
    if move.keepUltimate then
        local other=move.keepUltimate
        positions(move.profile).ultimate={x=other.x/GuiRoot:GetWidth(),y=other.y/GuiRoot:GetHeight()}
        anchor(other.control,other.x,other.y)
        move.keepUltimate=nil
    end
    local x=handle:GetLeft()+move.dx
    local y=handle:GetTop()+move.dy
    positions(move.profile)[move.key]={x=x/GuiRoot:GetWidth(),y=y/GuiRoot:GetHeight()}
    anchor(move.control,x,y)
    move.changed=true
end
function O.StopNativeMove()
    if not move then return end
    if move.changed or move.dragging then saveMove() end
    O.nativeMoveHandle:StopMovingOrResizing()
    O.nativeMoveHandle:SetHidden(true)
    O.nativeMoveHandle:SetMouseEnabled(false)
    EVENT_MANAGER:UnregisterForUpdate(O.name.."NativeMove")
    O.moveOverlay:SetHidden(true)
    local previousUI,previousCamera=move.ui,move.camera
    move=nil; O.nativeMoving=false
    if previousUI==false and SCENE_MANAGER then SCENE_MANAGER:SetInUIMode(false) end
    if previousCamera==false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
    O.Tick()
end
function O.NativeMoveUpdate()
    if not move then return end
    local handle=O.nativeMoveHandle
    local at=GetFrameTimeSeconds()
    local x,y=handle:GetLeft(),handle:GetTop()
    if move.dragging or x~=move.x or y~=move.y then saveMove(); move.at=at end
    if SCENE_MANAGER and not SCENE_MANAGER:IsInUIMode() then SCENE_MANAGER:SetInUIMode(true) end
    if SetGameCameraUIMode and IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then SetGameCameraUIMode(true) end
    local sx=GetGamepadRightStickX and GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE) or 0
    local sy=GetGamepadRightStickY and GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
    if not move.dragging and (math.abs(sx)>=0.05 or math.abs(sy)>=0.05) then
        x=math.max(0,math.min(math.max(0,GuiRoot:GetWidth()-handle:GetWidth()),x+sx*22))
        y=math.max(0,math.min(math.max(0,GuiRoot:GetHeight()-handle:GetHeight()),y-sy*22))
        handle:ClearAnchors(); handle:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
        saveMove(); move.at=at
    end
    move.x,move.y=handle:GetLeft(),handle:GetTop()
    if at-move.at>=3 then O.StopNativeMove() end
end
local function bounds(key,control)
    local cx,cy=control:GetLeft()+control:GetWidth()/2,control:GetTop()+control:GetHeight()/2
    if key=="buffs" then return cx-250,cy-40,500,80,cx,cy end
    local left,top=control:GetLeft(),control:GetTop()
    local right,bottom=left+control:GetWidth(),top+control:GetHeight()
    if key=="skills" then
        for slot=4,7 do
            local button=ZO_ActionBar_GetButton(slot)
            if button and button.slot then
                local c=button.slot
                left,top=math.min(left,c:GetLeft()),math.min(top,c:GetTop())
                right,bottom=math.max(right,c:GetLeft()+c:GetWidth()),math.max(bottom,c:GetTop()+c:GetHeight())
            end
        end
    end
    if key=="skills" or key=="ultimate" then top=top-65 end
    return left-8,top-8,math.max(70,right-left+16),math.max(70,bottom-top+36),cx,cy
end
function O.StartNativeMove(key)
    if not O.vars.enabled then d("Obsidian HUD: Bitte zuerst das HUD aktivieren."); return end
    if not titles[key] then return end
    if O.moving then O.StopMove() end
    if move then
        local same=move.key==key
        O.StopNativeMove()
        if same then return end
    end
    local control=target(key)
    if not control then d("Obsidian HUD: "..titles[key].." ist noch nicht verfuegbar."); return end
    local x,y,w,h,cx,cy=bounds(key,control)
    x=math.max(0,math.min(math.max(0,GuiRoot:GetWidth()-w),x))
    y=math.max(0,math.min(math.max(0,GuiRoot:GetHeight()-h),y))
    local handle=O.nativeMoveHandle
    handle:ClearAnchors(); handle:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    handle:SetDimensions(w,h)
    handle:SetMouseEnabled(true); handle:SetHidden(false)
    O.nativeMoveLabel:SetText(titles[key])
    O.moveHint:SetText("Move UI: "..titles[key].."\nMit Maus oder rechtem Stick verschieben. Speichert nach 3 Sekunden ohne Bewegung.")
    move={key=key,profile=mode(),control=control,dx=cx-x,dy=cy-y,x=x,y=y,at=GetFrameTimeSeconds(),
        ui=SCENE_MANAGER and SCENE_MANAGER:IsInUIMode(),camera=IsGameCameraUIModeActive and IsGameCameraUIModeActive()}
    -- ESO normally anchors the ultimate to the fifth skill. Freeze that
    -- dependent control before moving the five-skill group independently.
    if key=="skills" and not positions().ultimate then
        local ultimate=target("ultimate")
        if ultimate and ultimate~=control then
            move.keepUltimate={control=ultimate,x=ultimate:GetLeft()+ultimate:GetWidth()/2,
                y=ultimate:GetTop()+ultimate:GetHeight()/2}
        end
    end
    O.nativeMoving=true
    if SCENE_MANAGER then SCENE_MANAGER:SetInUIMode(true) end
    if SetGameCameraUIMode then SetGameCameraUIMode(true) end
    O.moveOverlay:SetHidden(false)
    EVENT_MANAGER:RegisterForUpdate(O.name.."NativeMove",16,O.NativeMoveUpdate)
end
function O.ResetNativePositions()
    O.StopNativeMove()
    O.vars.hudPositions={}
    O.ReleaseNativePositions()
    O.Tick()
end
function O.CreateNativeMoveUI()
    local handle=WINDOW_MANAGER:CreateTopLevelWindow("ObsidianHUDNativeMoveHandle")
    O.nativeMoveHandle=handle
    handle:SetDrawTier(DT_HIGH); handle:SetDrawLayer(DL_OVERLAY); handle:SetDrawLevel(15)
    handle:SetMovable(true); handle:SetClampedToScreen(true)
    handle:SetMouseEnabled(false); handle:SetHidden(true)
    local border=WINDOW_MANAGER:CreateControl(nil,handle,CT_BACKDROP)
    border:SetAnchorFill(handle)
    border:SetCenterColor(0.05,0.12,0.18,0.25)
    border:SetEdgeColor(0.3,0.85,1,1)
    border:SetEdgeTexture("esoui/art/miscellaneous/centerscreen_left.dds",1,1,1,0)
    border:SetMouseEnabled(false)
    O.nativeMoveLabel=O.Label(handle,15)
    O.nativeMoveLabel:SetAnchor(CENTER,handle,CENTER,0,0)
    handle:SetHandler("OnMouseDown",function(c,button)
        if move and button==MOUSE_BUTTON_INDEX_LEFT then move.dragging=true; move.at=GetFrameTimeSeconds(); c:StartMoving() end
    end)
    handle:SetHandler("OnMouseUp",function(c,button)
        if move and move.dragging and button==MOUSE_BUTTON_INDEX_LEFT then
            c:StopMovingOrResizing(); saveMove(); move.dragging=false; move.at=GetFrameTimeSeconds()
        end
    end)
    handle:SetHandler("OnMoveStop",function()
        if move and move.dragging then
            saveMove(); move.dragging=false; move.at=GetFrameTimeSeconds()
        end
    end)
end
