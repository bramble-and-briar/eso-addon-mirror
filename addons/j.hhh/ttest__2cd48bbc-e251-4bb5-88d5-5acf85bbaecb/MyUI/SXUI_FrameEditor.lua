-- My UI: single-mode PlayStation mover. No legacy MoveFrames() call.
-- Dedicated gamepad scene owns L1/R1, D-pad and Circle. Avoid UI-mode hijacking.
BUI.FrameEditor = BUI.FrameEditor or {}
local Editor = BUI.FrameEditor
local STEP = 8
local FRAME_NAMES = {
    'BUI_PlayerFrame', 'BUI_TargetFrame', 'BUI_BuffsP', 'BUI_BuffsT',
    'BUI_BuffsC', 'BUI_BuffsS', 'BUI_BuffsPas', 'BUI_BossFrame',
    'BUI_OnScreen', 'BUI_OnScreenS', 'BUI_Glyphs', 'BUI_MiniMeter',
    'BUI_GroupDPS', 'BUI_Attackers', 'BUI_BuffsUp',
}
local ANNOUNCEMENT_FRAMES = {
    {name='ZO_CenterScreenAnnounce', label='Basegame Announcements'},
}
local REQUESTED_DEFAULT_FRAMES = {
    'ZO_SynergyTopLevelContainer',
    'ZO_PlayerToPlayerAreaPromptContainer',
    'ZO_ActiveCombatTips',
}
-- Editor-only stand-ins for native frames which ESO creates only in specific content.
-- The saved anchors use the original ESO name, never the stand-in name.
local PINNED_DEFAULT_FRAMES = {
    {name='ZO_CenterScreenAnnounce', label='Basegame Announcements', x=0, y=-175},
    {name='ZO_PlayerToPlayerAreaPromptContainer', label='Interaction Button', x=0, y=130},
    {name='ZO_SynergyTopLevelContainer', label='Synergy', x=0, y=215},
    {name='ZO_ActiveCombatTips', label='Combat Tips', x=0, y=40},
}
-- ESO positions the three trackers through shared HUD layout when available.
local TRACKER_NAMES={
    ZO_FocusedQuestTrackerPanel=true,
    ZO_BattlegroundHUDFragmentTopLevelBattlegroundScoreHud=true,
    ZO_EndDunHUDTrackerContainer=true,
}
local function sharedTracker()
    return rawget(_G,'ZO_HUDTrackers') or rawget(_G,'ZO_FocusedQuestTrackerPanel')
end
local SPECIAL_ANCHOR_POINTS = {
    ZO_LootHistoryControl_Keyboard = BOTTOMRIGHT,
    ZO_LootHistoryControl_Gamepad = BOTTOMLEFT,
    ZO_PlayerAttributeMagicka = RIGHT,
    ZO_PlayerAttributeStamina = LEFT,
    ZO_EndDunHUDTrackerContainer = BOTTOMRIGHT,
}
local function log(message)
    if type(d)=='function' then d('[My UI Move] '..tostring(message)) end
end
local function keyIs(key, constant)
    local value=rawget(_G, constant)
    return value~=nil and key==value
end
local function hasGeometry(control)
    if not control or not control.GetCenter or not control.GetDimensions then return false end
    local ok,x,y=pcall(control.GetCenter,control)
    if not ok or not x or not y then return false end
    local ok2,w,h=pcall(control.GetDimensions,control)
    return ok2 and (tonumber(w) or 0)>0 and (tonumber(h) or 0)>0
end
local function getPreviewControl(name, fallbackX, fallbackY)
    Editor.previewControls=Editor.previewControls or {}
    if Editor.previewControls[name] then return Editor.previewControls[name] end
    local control=WINDOW_MANAGER:CreateTopLevelWindow('MyUI_MovePreview_'..name)
    control:SetDimensions(230,54)
    control:SetMouseEnabled(false)
    control:SetHidden(true)
    local anchor=BUI.Vars and BUI.Vars[name]
    local x,y=fallbackX or 0,fallbackY or 0
    if type(anchor)=='table' then
        x=tonumber(anchor[3]) or x
        y=tonumber(anchor[4]) or y
    end
    control:SetAnchor(CENTER,GuiRoot,CENTER,x,y)
    Editor.previewControls[name]=control
    return control
end
local function getName(control)
    if control.GetName then return control:GetName() or 'Frame' end
    return 'Frame'
end
local function prettifyName(name)
    name=tostring(name or 'Frame')
    name=name:gsub('^BUI_','')
    name=name:gsub('^ZO_','')
    name=name:gsub('Frame$',' Frame')
    name=name:gsub('BuffsP','Player Buffs')
    name=name:gsub('BuffsT','Target Buffs')
    name=name:gsub('BuffsC','Cooldown Buffs')
    name=name:gsub('BuffsS','Short Buffs')
    name=name:gsub('BuffsPas','Passive Buffs')
    name=name:gsub('BuffsUp','Upper Buffs')
    name=name:gsub('OnScreenS','On Screen Small')
    name=name:gsub('OnScreen','On Screen')
    name=name:gsub('BossFrame','Boss Frame')
    name=name:gsub('PlayerFrame','Player Frame')
    name=name:gsub('TargetFrame','Target Frame')
    name=name:gsub('MiniMeter','Mini Meter')
    name=name:gsub('GroupDPS','Group DPS')
    name=name:gsub('ActionBar1','Action Bar')
    name=name:gsub('FocusedQuestTrackerPanel','Quest Tracker')
    name=name:gsub('PlayerToPlayerAreaPromptContainer','Interaction Button')
    name=name:gsub('SynergyTopLevelContainer','Synergy')
    name=name:gsub('ActiveCombatTips','Combat Tips')
    name=name:gsub('EndDunHUDTrackerContainer','Archive Tracker')
    name=name:gsub('BattlegroundHUDFragmentTopLevelBattlegroundScoreHud','Battlegrounds Tracker')
    name=name:gsub('CenterScreenAnnounce','Center Screen Announce')
    name=name:gsub('ObjectiveCaptureMeter','Objective Capture Meter')
    name=name:gsub('TargetUnitFramereticleover','Target Unit')
    name=name:gsub('CompassFrame','Compass')
    name=name:gsub('AlertTextNotification','Alert Text')
    name=name:gsub('HUDInfamyMeter','Infamy Meter')
    name=name:gsub('HUDTelvarMeter','Tel Var Meter')
    name=name:gsub('LootHistoryControl_Keyboard','Loot History')
    name=name:gsub('LootHistoryControl_Gamepad','Loot History')
    name=name:gsub('RamTopLevel','AvA Ram')
    name=name:gsub('Subtitles','Subtitles')
    name=name:gsub('BuffDebuffTopLevelSelfContainerContainer1','Buff / Debuff')
    name=name:gsub('Attackers','Attackers')
    name=name:gsub('Glyphs','Glyphs')
    return name
end
local function getDisplayName(control, explicitName)
    if explicitName and explicitName~='' then return explicitName end
    return prettifyName(getName(control))
end
local function refresh()
    local entry=Editor.frames and Editor.frames[Editor.index]
    if not Editor.overlays then return end
    if not Editor.active or not Editor.frames or #Editor.frames==0 then
        for _,overlay in pairs(Editor.overlays) do
            if overlay.win then overlay.win:SetHidden(true) end
        end
        if Editor.hint then Editor.hint:SetHidden(true) end
        return
    end

    for i,frameEntry in ipairs(Editor.frames) do
        local overlay=Editor.overlays[i]
        if overlay and frameEntry and frameEntry.control then
            overlay.win:ClearAnchors()
            overlay.win:SetAnchor(TOPLEFT,frameEntry.control,TOPLEFT,-4,-4)
            overlay.win:SetAnchor(BOTTOMRIGHT,frameEntry.control,BOTTOMRIGHT,4,4)
            overlay.label:SetText(getDisplayName(frameEntry.control, frameEntry.displayName))
            if i==Editor.index then
                overlay.backdrop:SetCenterColor(0.95,0.82,0.12,0.10)
                overlay.backdrop:SetEdgeColor(1,0.85,0.10,1)
            else
                overlay.backdrop:SetCenterColor(1,1,1,0.03)
                overlay.backdrop:SetEdgeColor(1,1,1,0.95)
            end
            overlay.win:SetHidden(false)
        end
    end
    for i=#Editor.frames+1, #(Editor.overlays) do
        local overlay=Editor.overlays[i]
        if overlay and overlay.win then overlay.win:SetHidden(true) end
    end

    if Editor.label and entry then
        Editor.label:SetText(getDisplayName(entry.control, entry.displayName)..'  ('..tostring(Editor.index)..'/'..tostring(#Editor.frames)..')'..'\n'..'L1/R1: Wechseln | Steuerkreuz: Bewegen | Kreis: Speichern & Schliessen')
    end
    if Editor.hint then Editor.hint:SetHidden(false) end
    if Editor.guides then Editor.guides:SetHidden(false) end
end
local function createOverlay()
    if Editor.overlays then return end
    local wm=WINDOW_MANAGER
    Editor.overlays={}

    local hint=wm:CreateTopLevelWindow('MyUI_MoveHint')
    hint:SetDimensions(900,70);hint:SetAnchor(TOP,GuiRoot,TOP,0,75)
    hint:SetDrawTier(DT_HIGH);hint:SetDrawLayer(DL_OVERLAY)
    hint:SetMouseEnabled(false);hint:SetHidden(true)
    local label=wm:CreateControl('MyUI_MoveHintLabel',hint,CT_LABEL)
    label:SetAnchorFill(hint)
    label:SetFont('ZoFontGamepad24')
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    Editor.hint=hint;Editor.label=label
    -- Cyan dashed screen-center guides. Texture segments are more reliable
    -- on console than 1-pixel CT_BACKDROP controls with no edge texture.
    local guides=wm:CreateTopLevelWindow('MyUI_MoveCenterGuides')
    local screenW,screenH=GuiRoot:GetDimensions()
    guides:SetDimensions(screenW,screenH)
    guides:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    guides:SetDrawTier(DT_HIGH)
    guides:SetDrawLayer(DL_OVERLAY)
    guides:SetDrawLevel(90)
    guides:SetMouseEnabled(false)
    guides:SetHidden(true)
    local dashLength,gap=12,9
    local interval=dashLength+gap
    local serial=0
    local function dash(x,y,width,height)
        serial=serial+1
        local segment=wm:CreateControl('MyUI_CyanGuide_'..serial,guides,CT_TEXTURE)
        segment:SetTexture('/MyUI/textures/myui_editor_white.dds')
        segment:SetColor(0,0.85,1,0.95)
        segment:SetDimensions(width,height)
        segment:SetAnchor(CENTER,guides,CENTER,x,y)
        segment:SetHidden(false)
    end
    for x=-math.floor(screenW/2),math.floor(screenW/2),interval do
        dash(x,0,dashLength,2)
    end
    for y=-math.floor(screenH/2),math.floor(screenH/2),interval do
        dash(0,y,2,dashLength)
    end
    Editor.guides=guides
end
function Editor:Select(offset)
    if not self.active or not self.frames or #self.frames==0 then return end
    self.index=((self.index-1+offset)%#self.frames)+1
    refresh()
end
function Editor:Direction(dx,dy)
    if not self.active then return end
    local entry=self.frames and self.frames[self.index]
    if not entry then return end
    local control=entry.control
    local x,y=control:GetCenter()
    local rx,ry=GuiRoot:GetCenter()
    if not x or not y or not rx or not ry then return end
    control:ClearAnchors()
    control:SetAnchor(CENTER,GuiRoot,CENTER,x-rx+dx*STEP,y-ry+dy*STEP)
    self.dirty[control]=entry
    refresh()
end
local keys={
    alignment=KEYBIND_STRIP_ALIGN_LEFT,
    {name='Previous Frame (L1)',keybind='UI_SHORTCUT_LEFT_SHOULDER',ethereal=true,callback=function() Editor:Select(-1) end},
    {name='Next Frame (R1)',keybind='UI_SHORTCUT_RIGHT_SHOULDER',ethereal=true,callback=function() Editor:Select(1) end},
    {name='Move Up',keybind='UI_SHORTCUT_INPUT_UP',ethereal=true,callback=function() Editor:Direction(0,-1) end},
    {name='Move Down',keybind='UI_SHORTCUT_INPUT_DOWN',ethereal=true,callback=function() Editor:Direction(0,1) end},
    {name='Move Left',keybind='UI_SHORTCUT_INPUT_LEFT',ethereal=true,callback=function() Editor:Direction(-1,0) end},
    {name='Move Right',keybind='UI_SHORTCUT_INPUT_RIGHT',ethereal=true,callback=function() Editor:Direction(1,0) end},
    {name='Save and Exit',keybind='UI_SHORTCUT_NEGATIVE',callback=function() Editor:Close() end},
}
Editor.keybindDescriptor=keys
function Editor:HandleKeyDown(key)
    if not self.active then return false end
    -- Fallback for raw shoulder and d-pad events on different console mappings.
    if keyIs(key,'KEY_GAMEPAD_LEFT_SHOULDER') or keyIs(key,'KEY_GAMEPAD_BUTTON_L1') then self:Select(-1);return true end
    if keyIs(key,'KEY_GAMEPAD_RIGHT_SHOULDER') or keyIs(key,'KEY_GAMEPAD_BUTTON_R1') then self:Select(1);return true end
    if keyIs(key,'KEY_GAMEPAD_DPAD_UP') then self:Direction(0,-1);return true end
    if keyIs(key,'KEY_GAMEPAD_DPAD_DOWN') then self:Direction(0,1);return true end
    if keyIs(key,'KEY_GAMEPAD_DPAD_LEFT') then self:Direction(-1,0);return true end
    if keyIs(key,'KEY_GAMEPAD_DPAD_RIGHT') then self:Direction(1,0);return true end
    if keyIs(key,'KEY_GAMEPAD_BACK') or keyIs(key,'KEY_ESCAPE') then self:Close();return true end
    return false
end
local SCENE_NAME = 'myui_frame_editor_gamepad'
local function dropKeys()
    local strip = rawget(_G, 'KEYBIND_STRIP')
    if Editor.keysAdded and strip then pcall(strip.RemoveKeybindButtonGroup,strip,keys) end
    Editor.keysAdded=false
    if Editor.keybindStatePushed and strip and strip.PopKeybindGroupState then
        pcall(strip.PopKeybindGroupState,strip)
    end
    Editor.keybindStatePushed=false
    Editor.keybindState=nil
end
local function cleanup()
    dropKeys()
    Editor.active=false
    if Editor.overlays then
        for _,overlay in pairs(Editor.overlays) do
            if overlay.win then overlay.win:SetHidden(true) end
        end
    end
    if Editor.hint then Editor.hint:SetHidden(true) end
    if Editor.guides then Editor.guides:SetHidden(true) end
    local dirty=Editor.dirty or {}
    Editor.dirty={}
    Editor.frames={}
    Editor.index=nil
    local saved=0
    for control,entry in pairs(dirty) do
        if entry.saveName=='MyUI_ChatWindow' then
            local x,y=control:GetCenter()
            local gx,gy=GuiRoot:GetCenter()
            if x and y and gx and gy and BUI.Vars then
                BUI.Vars.MyUI_ChatPosition={x-gx,y-gy}
                saved=saved+1
            end
        elseif entry.saveName=='MyUI_TrackerCombined' then
            local x,y=control:GetCenter()
            local gx,gy=GuiRoot:GetCenter()
            if x and y and gx and gy and BUI.Vars then
                BUI.Vars.MyUI_TrackerCombined={CENTER,CENTER,x-gx,y-gy}
                saved=saved+1
            end
        elseif BUI.Menu and type(BUI.Menu.SaveAnchor)=='function' then
            local ok,err=pcall(BUI.Menu.SaveAnchor,BUI.Menu,control,nil,entry.saveName,entry.anchorPoint)
            if ok then saved=saved+1 else log('SaveAnchor: '..tostring(err)) end
        end
    end

end
function Editor:Close()
    if self.closing then return end
    self.closing=true
    -- Release our keybinds BEFORE scene transition, always.
    dropKeys()
    local manager=rawget(_G,'SCENE_MANAGER')
    if manager and self.scene and self.scene:IsShowing() then
        local ok,err=pcall(manager.Hide,manager,SCENE_NAME)
        if not ok then log('Hide scene: '..tostring(err)) end
    end
    cleanup()
    -- Wait for transition to finish before restoring ordinary game input.
    local function finish()
        local m=rawget(_G,'SCENE_MANAGER')
        if m and m.SetInUIMode then pcall(m.SetInUIMode,m,false) end
        if type(SetGameCameraUIMode)=='function' then pcall(SetGameCameraUIMode,false) end
    end
    if type(zo_callLater)=='function' then zo_callLater(finish,200) else finish() end
    self.closing=false
end
Editor.EmergencyClose=function() Editor:Close() end
local function ensureScene()
    if Editor.scene then return true end
    if not (ZO_Scene and ZO_SimpleSceneFragment and SCENE_MANAGER) then
        log('FEHLER: ESO Gamepad-Szenenbibliothek fehlt')
        return false
    end
    createOverlay()
    local scene=ZO_Scene:New(SCENE_NAME,SCENE_MANAGER)
    -- Use ESO's gamepad-driven scene input handling, not a forced camera/UI mode.
    if FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    end
    -- Only our own overlay; no LAM fragments or previous menu keybinds.
    scene:AddFragment(ZO_SimpleSceneFragment:New(Editor.hint))
    scene:RegisterCallback('StateChange',function(oldState,newState)
        if newState==SCENE_SHOWN then
            if not Editor.active then return end
            local strip=rawget(_G,'KEYBIND_STRIP')
            if strip then
                -- Follow ESO gamepad screens: isolate our keybinds in a pushed state.
                if strip.PushKeybindGroupState and not Editor.keybindStatePushed then
                    local pushed,state=pcall(strip.PushKeybindGroupState,strip)
                    if pushed then
                        Editor.keybindStatePushed=true
                        Editor.keybindState=state
                    else log('Keybind-State Fehler: '..tostring(state)) end
                end
                local ok,err=pcall(strip.AddKeybindButtonGroup,strip,keys,Editor.keybindState)
                Editor.keysAdded=ok
                if not ok then log('Tasten-Registrierung fehlgeschlagen: '..tostring(err)); Editor:Close()
                end
            else log('KEYBIND_STRIP fehlt');Editor:Close() end
            refresh()
        elseif newState==SCENE_HIDDEN then
            dropKeys()
            -- External exit (game menu/back key) also clears the editor.
            if Editor.active and not Editor.closing then Editor:Close() end
        end
    end)
    Editor.scene=scene
    return true
end
function Editor:Open()
    if self.active or self.closing then return end
    local list,seen={},{}
    local function include(control,saveName,anchorPoint,displayName)
        if hasGeometry(control) and not seen[control] then
            seen[control]=true
            list[#list+1]={control=control,saveName=saveName,anchorPoint=anchorPoint,displayName=displayName}
        end
    end
    for _,name in ipairs(FRAME_NAMES) do
        include(rawget(_G,name), nil, nil, nil)
    end
    if BUI.MyUIChatLayout and BUI.MyUIChatLayout.GetControl then
        local chat=BUI.MyUIChatLayout.GetControl()
        if chat then
            BUI.MyUIChatLayout.Apply()
            include(chat,'MyUI_ChatWindow',nil,'Chatbox')
        else
            -- No chat control available at this moment; leave the editor usable.
        end
    end
    -- Only one selection for the native quest / BG / archive tracker region.
    local tracker=sharedTracker()
    if hasGeometry(tracker) then
        include(tracker,'MyUI_TrackerCombined',nil,'Quest / BG / Archive Tracker')
    else
        include(getPreviewControl('MyUI_TrackerCombined',420,-40),'MyUI_TrackerCombined',nil,'Quest / BG / Archive Tracker')
    end
    -- Pinned default HUD positions always have an editor-visible preview.
    -- If ESO has no active geometry, move a temporary preview instead.
    for _,item in ipairs(PINNED_DEFAULT_FRAMES) do
        local native=rawget(_G,item.name)
        local control=hasGeometry(native) and native or getPreviewControl(item.name,item.x,item.y)
        include(control,item.name,SPECIAL_ANCHOR_POINTS[item.name],item.label)
    end
    if BUI.DefaultFrames then
        for name,desc in pairs(BUI.DefaultFrames) do
            local control=rawget(_G,name)
            if name~='ZO_AlertTextNotification' and not TRACKER_NAMES[name] and control and not ((name=='ZO_LootHistoryControl_Keyboard' and BUI.GamepadMode) or (name=='ZO_LootHistoryControl_Gamepad' and not BUI.GamepadMode)) then
                include(control, name, SPECIAL_ANCHOR_POINTS[name], desc)
            end
        end
    else
        for _,name in ipairs(REQUESTED_DEFAULT_FRAMES) do
            include(rawget(_G,name), name, SPECIAL_ANCHOR_POINTS[name], prettifyName(name))
        end
    end
    if BUI.Meters and BUI.Meters.List and BUI.Vars then
        for _,name in pairs(BUI.Meters.List) do
            if BUI.Vars['Meter_'..tostring(name)] then include(rawget(_G,'BUI_Meter_'..tostring(name))) end
        end
    end
    if #list==0 then log('Keine verschiebbaren Frames gefunden');return end
    local ok,valid=pcall(ensureScene)
    if not ok or not valid then log('Szene konnte nicht erzeugt werden');return end
    self.frames=list;self.index=1;self.dirty={};self.active=true
    createOverlay()
    for i,frameEntry in ipairs(list) do
        if not Editor.overlays[i] then
            local win=WINDOW_MANAGER:CreateTopLevelWindow('MyUI_MoveOverlay_'..tostring(i))
            win:SetDrawTier(DT_HIGH)
            win:SetDrawLayer(DL_OVERLAY)
            win:SetDrawLevel(40)
            win:SetMouseEnabled(false)
            win:SetHidden(true)
            local backdrop=WINDOW_MANAGER:CreateControl('MyUI_MoveOverlayBackdrop_'..tostring(i),win,CT_BACKDROP)
            backdrop:SetAnchorFill(win)
            backdrop:SetEdgeTexture(nil, 2, 2, 2)
            backdrop:SetCenterColor(1,1,1,0.03)
            backdrop:SetEdgeColor(1,1,1,0.95)
            local label=WINDOW_MANAGER:CreateControl('MyUI_MoveOverlayLabel_'..tostring(i),win,CT_LABEL)
            label:SetAnchor(CENTER,win,CENTER,0,0)
            label:SetFont('ZoFontGamepad34')
            label:SetColor(1,1,1,1)
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            Editor.overlays[i]={win=win,backdrop=backdrop,label=label}
        end
    end
    -- Showing this scene transitions the options scene away normally.
    -- Do NOT force SetInUIMode(true), HideCurrentScene or TakeFocus.
    local shown,err=pcall(SCENE_MANAGER.Show,SCENE_MANAGER,SCENE_NAME)
    if not shown then log('Szene-Start fehlgeschlagen: '..tostring(err)); self:Close();return end
    refresh()

end
local function launch()
    if Editor.active then return end
    -- Defer to after the clicked LAM action returns; transition itself
    -- closes the previous menu scene and installs our keybind group on SHOWN.
    if type(zo_callLater)=='function' then
        zo_callLater(function() Editor:Open() end,250)
    else Editor:Open() end
end
BUI.StartMoveFramesFromChat=launch
if SLASH_COMMANDS then
    SLASH_COMMANDS['/moveframes']=launch
    SLASH_COMMANDS['/moveabort']=function() Editor:Close() end
end
