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
local function getName(control)
    if control.GetName then return control:GetName() or 'Frame' end
    return 'Frame'
end
local function refresh()
    local entry=Editor.frames and Editor.frames[Editor.index]
    if not Editor.highlight then return end
    if not Editor.active or not entry then Editor.highlight:SetHidden(true); return end
    Editor.highlight:ClearAnchors()
    Editor.highlight:SetAnchor(TOPLEFT,entry.control,TOPLEFT,-5,-5)
    Editor.highlight:SetAnchor(BOTTOMRIGHT,entry.control,BOTTOMRIGHT,5,5)
    Editor.highlight:SetHidden(false)
    if Editor.label then Editor.label:SetText(getName(entry.control)..'\nL1/R1: Wechseln | Steuerkreuz: Bewegen | Kreis: Speichern & Schliessen') end
end
local function createOverlay()
    if Editor.highlight then return end
    local wm=WINDOW_MANAGER
    local win=wm:CreateTopLevelWindow('MyUI_MoveSelection')
    win:SetDrawTier(DT_HIGH);win:SetDrawLayer(DL_OVERLAY);win:SetDrawLevel(50)
    win:SetMouseEnabled(false);win:SetHidden(true)
    local border=wm:CreateControl('MyUI_MoveSelectionBorder',win,CT_BACKDROP)
    border:SetAnchorFill(win);border:SetCenterColor(0.9,0.8,0.1,0.08)
    border:SetEdgeColor(1,0.8,0.1,1)
    Editor.highlight=win
    local hint=wm:CreateTopLevelWindow('MyUI_MoveHint')
    hint:SetDimensions(800,70);hint:SetAnchor(TOP,GuiRoot,TOP,0,75)
    hint:SetDrawTier(DT_HIGH);hint:SetDrawLayer(DL_OVERLAY)
    hint:SetMouseEnabled(false);hint:SetHidden(true)
    local label=wm:CreateControl('MyUI_MoveHintLabel',hint,CT_LABEL)
    label:SetAnchorFill(hint)
    label:SetFont('ZoFontGamepad20')
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    Editor.hint=hint;Editor.label=label
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
    if Editor.highlight then Editor.highlight:SetHidden(true) end
    if Editor.hint then Editor.hint:SetHidden(true) end
    local dirty=Editor.dirty or {}
    Editor.dirty={}
    Editor.frames={}
    Editor.index=nil
    local saved=0
    for control,entry in pairs(dirty) do
        if BUI.Menu and type(BUI.Menu.SaveAnchor)=='function' then
            local ok,err=pcall(BUI.Menu.SaveAnchor,BUI.Menu,control,nil,entry.saveName,entry.anchorPoint)
            if ok then saved=saved+1 else log('SaveAnchor: '..tostring(err)) end
        end
    end
    log('Editor geschlossen. Positionen gespeichert: '..saved)
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
                else log('Editor-Tasten aktiv: L1/R1, D-Pad, Kreis') end
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
    local function include(control,saveName,anchorPoint)
        if hasGeometry(control) and not seen[control] then
            seen[control]=true
            list[#list+1]={control=control,saveName=saveName,anchorPoint=anchorPoint}
        end
    end
    for _,name in ipairs(FRAME_NAMES) do include(rawget(_G,name)) end
    if BUI.Meters and BUI.Meters.List and BUI.Vars then
        for _,name in pairs(BUI.Meters.List) do
            if BUI.Vars['Meter_'..tostring(name)] then include(rawget(_G,'BUI_Meter_'..tostring(name))) end
        end
    end
    if #list==0 then log('Keine verschiebbaren Frames gefunden');return end
    local ok,valid=pcall(ensureScene)
    if not ok or not valid then log('Szene konnte nicht erzeugt werden');return end
    self.frames=list;self.index=1;self.dirty={};self.active=true
    -- Showing this scene transitions the options scene away normally.
    -- Do NOT force SetInUIMode(true), HideCurrentScene or TakeFocus.
    local shown,err=pcall(SCENE_MANAGER.Show,SCENE_MANAGER,SCENE_NAME)
    if not shown then log('Szene-Start fehlgeschlagen: '..tostring(err)); self:Close();return end
    refresh()
    log('Editor-Szene gestartet ('..#list..' Frames). L1/R1, Steuerkreuz, Kreis.')
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
