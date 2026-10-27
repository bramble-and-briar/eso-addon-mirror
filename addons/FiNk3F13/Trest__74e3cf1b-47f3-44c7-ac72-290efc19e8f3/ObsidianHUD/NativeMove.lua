local O=ObsidianHUD
local originals={}
local move
local currentProfile
local currentFixed
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
local function screenSize(control)
    local right=control.GetRight and control:GetRight()
    local bottom=control.GetBottom and control:GetBottom()
    return type(right)=="number" and right-control:GetLeft() or control:GetWidth(),
        type(bottom)=="number" and bottom-control:GetTop() or control:GetHeight()
end
local function screenFactor(key)
    local control=target(key)
    if not control or key=="buffs" then return 1 end
    local _,height=screenSize(control)
    local cached=O.skillScaleDimensions and O.skillScaleDimensions[control]
    local localHeight=cached and cached[2] or control:GetHeight()
    return localHeight>0 and height/localHeight or 1
end
local function screenCenter(control)
    local width,height=screenSize(control)
    return control:GetLeft()+width/2,control:GetTop()+height/2
end
function O.IsFixedSkillView()
    return O.vars.skillHudView=="fixed" or O.vars.skillHudView=="fixed_dual"
        or O.vars.skillHudView=="fixed_static" or O.vars.skillHudView=="fixed_dual_static"
end
function O.DualUltimateView()
    return (O.vars.skillHudView=="fixed_dual" or O.vars.skillHudView=="fixed_dual_static") and O.vars.backBar
end
function O.NoSkillAnimationsView()
    return O.vars.skillHudView=="fixed_static" or O.vars.skillHudView=="fixed_dual_static"
end
function O.FixedSkillRows()
    if not O.IsFixedSkillView() or not O.vars.backBar then return false end
    local active=GetActiveHotbarCategory()
    return active==HOTBAR_CATEGORY_PRIMARY or active==HOTBAR_CATEGORY_BACKUP
end
function O.SkillRowGap(control)
    -- The slot artwork extends nine units beyond the stable native slot;
    -- its outer bevel occupies 60 of the 64 texture pixels.
    local _,height=O.SkillSlotSize(control)
    return (height+9)*60/64
end
function O.SkillSlotSize(control)
    local cached=O.skillScaleDimensions and O.skillScaleDimensions[control]
    if cached then return cached[1],cached[2] end
    return control:GetWidth(),control:GetHeight()
end
function O.CaptureSkillScaleDimensions()
    local result={}
    if not ZO_ActionBar_GetButton then return result end
    for slot=3,8 do
        local button=ZO_ActionBar_GetButton(slot)
        if button and button.slot then
            local c=button.slot
            result[c]={c:GetWidth(),c:GetHeight()}
        end
    end
    local quick=target("quickslot")
    if quick then result[quick]={quick:GetWidth(),quick:GetHeight()} end
    return result
end
function O.UltimateRowSeparation()
    local skills,ultimate=target("skills"),target("ultimate")
    if not skills or not ultimate then return 80 end
    return math.max(O.SkillRowGap(skills),O.SkillRowGap(ultimate))+16
end
function O.SkillRowOffset(key)
    if not O.FixedSkillRows() then return 0 end
    if key=="ultimate" or key=="quickslot" then
        local first=target("skills")
        local center=first and -O.SkillRowGap(first)/2 or 0
        if key=="ultimate" and O.DualUltimateView() then
            return center+(GetActiveHotbarCategory()==HOTBAR_CATEGORY_PRIMARY and -1 or 1)*O.UltimateRowSeparation()/2
        end
        return center
    end
    if key~="skills" or GetActiveHotbarCategory()~=HOTBAR_CATEGORY_PRIMARY then return 0 end
    local control=target(key)
    return control and -O.SkillRowGap(control) or 0
end
function O.NativeHudOffset(key)
    return (O.SkillRowOffset(key)-(O.FixedSkillRows() and titles[key] and 32 or 0))*screenFactor(key)
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
function O.CaptureSkillScalePositions()
    local result={}
    for _,key in ipairs({"skills","ultimate","quickslot"}) do
        local control=target(key)
        if control then
            local old=originals[control]
            local cx,cy=screenCenter(control)
            result[key]=old and old.fixedBase or {
                x=cx/GuiRoot:GetWidth(),
                y=(cy-(old and old.owned and O.NativeHudOffset(key) or 0))/GuiRoot:GetHeight()}
        end
    end
    return result
end
local function anchor(control,x,y)
    capture(control)
    local old=originals[control]
    if O.skillScalePositions then
        -- Anchor offsets can use the inherited scale, while GetLeft/GetTop
        -- report screen coordinates. Measure this conversion once per layout
        -- instead of assuming they use the same units.
        if not old.transform then
            control:ClearAnchors(); control:SetAnchor(CENTER,GuiRoot,TOPLEFT,0,0)
            local ox,oy=screenCenter(control)
            control:ClearAnchors(); control:SetAnchor(CENTER,GuiRoot,TOPLEFT,1,1)
            local ax,ay=screenCenter(control)
            old.transform={ox,oy,math.abs(ax-ox)>0.0001 and ax-ox or 1,
                math.abs(ay-oy)>0.0001 and ay-oy or 1}
        end
        local t=old.transform
        x,y=(x-t[1])/t[3],(y-t[2])/t[4]
    end
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
    local fixed=O.FixedSkillRows()
    if currentProfile~=profile or currentFixed~=fixed then
        O.ReleaseNativePositions(); currentProfile=profile; currentFixed=fixed
    end
    local planned={}
    for key,pos in pairs(O.skillScalePositions or {}) do planned[key]=pos end
    for key,pos in pairs(positions()) do planned[key]=pos end
    if fixed then
        -- Capture all baselines before moving the skill group: ESO normally
        -- anchors the ultimate to the fifth skill, so it would move twice.
        for _,key in ipairs({"skills","ultimate","quickslot","buffs"}) do
            local control=target(key)
            if control then
                capture(control)
                local old=originals[control]
                if not old.fixedBase then
                    local cx,cy=screenCenter(control)
                    old.fixedBase={x=cx/GuiRoot:GetWidth(),y=cy/GuiRoot:GetHeight()}
                end
                planned[key]=planned[key] or old.fixedBase
            end
        end
        if planned.skills then
            for _,key in ipairs({"ultimate","quickslot"}) do
                if planned[key] then planned[key]={x=planned[key].x,y=planned.skills.y} end
            end
        end
    end
    -- Scale the distance between independently movable groups as well as the
    -- icons themselves. Keeping the old absolute ultimate/trank X would let
    -- the growing five-skill row run into them.
    local groupFactor=O.skillHudFactor or 1
    if groupFactor~=1 and planned.skills then
        for _,key in ipairs({"ultimate","quickslot"}) do
            local pos=planned[key]
            if pos then planned[key]={x=planned.skills.x+(pos.x-planned.skills.x)*groupFactor,y=pos.y} end
        end
        local first=target("skills")
        local lastButton=ZO_ActionBar_GetButton(7)
        if first and lastButton and lastButton.slot then
            local firstX=screenCenter(first)
            local firstWidth=screenSize(first)
            local lastWidth=screenSize(lastButton.slot)
            local pad=10*screenFactor("skills")
            local desired=planned.skills.x*GuiRoot:GetWidth()
            local left=desired-firstWidth/2-pad
            local right=desired+lastButton.slot:GetLeft()+lastWidth-firstX+pad
            for _,key in ipairs({"ultimate","quickslot"}) do
                local c,pos=target(key),planned[key]
                if c and pos then
                    local width=screenSize(c)
                    left=math.min(left,pos.x*GuiRoot:GetWidth()-width/2-pad)
                    right=math.max(right,pos.x*GuiRoot:GetWidth()+width/2+pad)
                end
            end
            -- Shift the complete group together at the screen edge; clamping
            -- the ultimate alone would push it back into the fifth skill.
            local shift=math.max(0,-left)+math.min(0,GuiRoot:GetWidth()-right)
            if shift~=0 then
                for _,key in ipairs({"skills","ultimate","quickslot"}) do
                    local pos=planned[key]
                    if pos then planned[key]={x=pos.x+shift/GuiRoot:GetWidth(),y=pos.y} end
                end
            end
        end
    end
    for key,pos in pairs(planned) do
        local control=titles[key] and target(key)
        if control then
            local w,h=screenSize(control)
            local x=math.max(w/2,math.min(GuiRoot:GetWidth()-w/2,pos.x*GuiRoot:GetWidth()))
            local bottom=GuiRoot:GetHeight()-h/2
            if not fixed and key~="buffs" then
                -- Standard/running/equal and single-row layouts also need
                -- space for the native key labels below the icons.
                bottom=bottom-38*screenFactor(key)
            end
            if fixed and key~="buffs" then
                -- Reserve the lower row's native binding glyphs and a margin,
                -- even while the active button itself is on the upper row.
                local factor=screenFactor(key)
                bottom=bottom+(-38+O.SkillRowOffset(key))*factor
                if key=="ultimate" and O.DualUltimateView() then
                    local first=target("skills")
                    local lower=first and -O.SkillRowGap(first)/2+O.UltimateRowSeparation()/2 or 0
                    bottom=bottom-math.max(0,lower)*factor
                end
            end
            local y=math.max(h/2,math.min(bottom,pos.y*GuiRoot:GetHeight()+O.NativeHudOffset(key)))
            anchor(control,x,y)
        end
    end
end
local function saveMove()
    local handle=O.nativeMoveHandle
    if move.keepUltimate then
        local other=move.keepUltimate
        positions(move.profile).ultimate={x=other.x/GuiRoot:GetWidth(),y=(other.y-O.NativeHudOffset("ultimate"))/GuiRoot:GetHeight()}
        anchor(other.control,other.x,other.y)
        move.keepUltimate=nil
    end
    local x=handle:GetLeft()+move.dx
    local y=handle:GetTop()+move.dy
    local savedX=x/GuiRoot:GetWidth()
    local groupFactor=O.skillHudFactor or 1
    if groupFactor~=1 and (move.key=="ultimate" or move.key=="quickslot") then
        local p=positions(move.profile)
        local first=p.skills or (O.skillScalePositions and O.skillScalePositions.skills)
        if first then savedX=first.x+(savedX-first.x)/groupFactor end
    end
    positions(move.profile)[move.key]={x=savedX,y=(y-O.NativeHudOffset(move.key))/GuiRoot:GetHeight()}
    if O.FixedSkillRows() and (move.key=="skills" or move.key=="ultimate" or move.key=="quickslot") then
        local p=positions(move.profile)
        if move.key~="skills" then
            local skills=target("skills")
            if skills then
                local cx=screenCenter(skills)
                p.skills={x=p.skills and p.skills.x or cx/GuiRoot:GetWidth(),y=p[move.key].y}
            end
        end
        if p.skills then
            for _,key in ipairs({"ultimate","quickslot"}) do if p[key] then p[key].y=p.skills.y end end
        end
    end
    anchor(move.control,x,y)
    if O.FixedSkillRows() then O.UpdateNativePositions() end
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
    local cx,cy=screenCenter(control)
    if key=="buffs" then return cx-250,cy-40,500,80,cx,cy end
    local left,top=control:GetLeft(),control:GetTop()
    local w,h=screenSize(control)
    local right,bottom=left+w,top+h
    local factor=screenFactor(key)
    if key=="skills" then
        for slot=4,7 do
            local button=ZO_ActionBar_GetButton(slot)
            if button and button.slot then
                local c=button.slot
                local cw,ch=screenSize(c)
                left,top=math.min(left,c:GetLeft()),math.min(top,c:GetTop())
                right,bottom=math.max(right,c:GetLeft()+cw),math.max(bottom,c:GetTop()+ch)
            end
        end
    end
    if key=="skills" or key=="ultimate" then
        if O.FixedSkillRows() then
            local gap=O.SkillRowGap(control)
            if key=="ultimate" and O.DualUltimateView() then gap=O.UltimateRowSeparation() end
            gap=gap*factor
            if GetActiveHotbarCategory()==HOTBAR_CATEGORY_PRIMARY then bottom=bottom+gap else top=top-gap end
        else top=top-65*factor end
    end
    return left-8*factor,top-8*factor,math.max(70,right-left+16*factor),math.max(70,bottom-top+36*factor),cx,cy
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
            local ux,uy=screenCenter(ultimate)
            move.keepUltimate={control=ultimate,x=ux,y=uy}
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
