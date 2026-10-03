-- Keep ESO's scenes, action layers, leave handlers and social dialog.
-- This file adapts their data/visibility to the replacement visual surface.
-- No addon action layer, stick navigation, custom leave dialog or HUD leave prompt.
local A, C = ScoreboardFixXbox, ScoreboardFixXboxCore
local function Identity(p)
    return p and C.Key({displayName=p.displayName,characterName=zo_strformat(SI_UNIT_NAME,p.characterName or '')})
end

function A:NativeAvailable()
    local n=BATTLEGROUND_SCOREBOARD_FRAGMENT
    local live=ZO_BATTLEGROUND_SCOREBOARD_IN_GAME
    local final=BATTLEGROUND_SCOREBOARD_END_OF_GAME
    return n and n.control and n.backgroundsContainer and n.headers and n.panelContainer and n.roundsControl
        and type(n.UpdateAll)=='function' and type(n.SetSelectedPlayerData)=='function'
        and type(n.ShouldShowAggregateScores)=='function' and type(n.GetViewedRound)=='function'
        and type(n.RegisterCallback)=='function' and type(n.IsShowing)=='function'
        and live and live.keybindStripDescriptor and live.listNavigationKeybindStripDescriptor
        and type(live.SetupKeybindStripDescriptorAlignment)=='function'
        and type(live.RefreshMatchInfoFragments)=='function'
        and final and final.leaveBattlegroundKeybind and final.keybindNameTextMap
        and type(final.RefreshMatchInfoFragments)=='function'
        and BATTLEGROUND_SCOREBOARD_IN_GAME_SCENE and BATTLEGROUND_SCOREBOARD_IN_GAME_UI_SCENE
        and BATTLEGROUND_SCOREBOARD_END_OF_GAME_SCENE
end

function A:NativeOrderedPlayers(players,team)
    local byIdentity,ordered={},{}
    for _,p in ipairs(players) do byIdentity[C.Key(p)]=p end
    for _,p in ipairs(BATTLEGROUND_SCOREBOARD_FRAGMENT.playerEntryData) do
        local captured=byIdentity[Identity(p)]
        if captured and p.battlegroundTeam==team then
            ordered[#ordered+1]=captured
        end
    end
    -- Use the native roster for the displayed round. Departed players still
    -- appear when inspecting their earlier round, without inflating 4v4 results.
    return ordered
end

function A:HideNativeVisuals()
    local n=BATTLEGROUND_SCOREBOARD_FRAGMENT
    n.backgroundsContainer:SetHidden(true)
    n.headers:SetHidden(true)
    n.panelContainer:SetHidden(true)
    n.roundsControl:SetHidden(true)
end


function A:RefreshFromNative()
    if not IsActiveWorldBattleground() then
        self.visible=false;self.inMatch=false;self.match=nil
        self.window:SetHidden(true)
        return
    end
    local n=BATTLEGROUND_SCOREBOARD_FRAGMENT
    self:Capture()
    self.viewRound=n:ShouldShowAggregateScores() and self.match and self.match.total and 'total' or n:GetViewedRound()
    self.selected=Identity(n.selectedPlayerData)
    self.visible=n:IsShowing()
    self.window:SetHidden(not self.visible)
    self:HideNativeVisuals()
    if self.visible then self:Render() end
end

function A:LayoutNativePrompts()
    local final=BATTLEGROUND_SCOREBOARD_END_OF_GAME
    -- Preserve native cooldown/callback routing; only adjust wording and position.
    final.keybindNameTextMap[final.leaveBattlegroundKeybind]='LEAVE INSTANCE'
    final.leaveBattlegroundKeybind:SetText('LEAVE INSTANCE')
    final.closingTimerLabel:SetHidden(true) -- Our main header already shows the timer.
    local container=final.control:GetNamedChild('KeybindContainer')
    container:ClearAnchors()
    container:SetAnchor(BOTTOM,GuiRoot,BOTTOM,0,-30)
    container:SetScale(math.min(1,GuiRoot:GetWidth()*0.94/math.max(1,container:GetWidth())))
end

function A:BuildRoundPrompts()
    self.roundPrompts={}
    for i,action in ipairs({'BATTLEGROUND_SCOREBOARD_PREVIOUS_ROUND','BATTLEGROUND_SCOREBOARD_NEXT_ROUND'}) do
        local b=WINDOW_MANAGER:CreateControlFromVirtual('ScoreboardFixXboxRoundHint'..i,self.window,'ZO_KeybindButton')
        b:SetKeybind(action,true,action);b:SetText('');b:SetMouseEnabled(false)
        b:SetAnchor(i==1 and RIGHT or LEFT,self.roundButton,i==1 and LEFT or RIGHT,i==1 and -8 or 8,0)
        self.roundPrompts[i]=b
    end
end

function A:InstallNativeIntegration()
    local n=BATTLEGROUND_SCOREBOARD_FRAGMENT
    local live=ZO_BATTLEGROUND_SCOREBOARD_IN_GAME
    local final=BATTLEGROUND_SCOREBOARD_END_OF_GAME
    self:BuildRoundPrompts()
    -- ZOS deliberately left-aligns both live scoreboard keybind groups in
    -- gamepad mode. Keep the native descriptors/actions, but centre the
    -- prompts beneath our centred replacement board. The final scoreboard
    -- uses its own KeybindContainer and is positioned separately above.
    ZO_PostHook(live,'SetupKeybindStripDescriptorAlignment',function()
        if IsInGamepadPreferredMode() then
            live.keybindStripDescriptor.alignment=KEYBIND_STRIP_ALIGN_CENTER
            live.listNavigationKeybindStripDescriptor.alignment=KEYBIND_STRIP_ALIGN_CENTER
        end
    end)
    for _,descriptor in ipairs(live.keybindStripDescriptor) do
        if descriptor.keybind=='LEAVE_BATTLEGROUND' then descriptor.name='RAGE QUIT' end
    end
    -- Native scenes continue to own action layers, prompts and the Xbox
    -- match-info / medal panel. Do not suppress RefreshMatchInfoFragments.
    ZO_PostHook(final,'OnShowing',function() self:LayoutNativePrompts() end)
    ZO_PostHook(final,'ApplyPlatformStyle',function() self:LayoutNativePrompts() end)
    ZO_PostHook(n,'UpdateAll',function() self:RefreshFromNative() end)
    ZO_PostHook(n,'SetSelectedPlayerData',function()
        self.selected=Identity(n.selectedPlayerData)
        self:UpdateSelection()
    end)
    n:RegisterCallback('StateChange',function(_,state)
        if state==SCENE_FRAGMENT_SHOWING or state==SCENE_FRAGMENT_SHOWN then
            self:RefreshFromNative()
            -- Native SHOWING resets to the active round. At match end start on
            -- RESULT through the native aggregate API, preserving LT/RT behaviour.
            if state==SCENE_FRAGMENT_SHOWING and self.match and self.match.finished
                and self.match.total then n:ShowAggregateScores(true) end
        elseif state==SCENE_FRAGMENT_HIDING or state==SCENE_FRAGMENT_HIDDEN then
            self.visible=false;self.window:SetHidden(true)
        end
    end)
    ZO_PostHook(self,'Render',function()
        local rounds=self.match and (self.match.numRounds or 1)>1
        for _,b in ipairs(self.roundPrompts) do b:SetHidden(not rounds) end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_BATTLEGROUND_STATE_CHANGED,function(_,_,state)
        if state==BATTLEGROUND_STATE_FINISHED then
            zo_callLater(function()
                if IsActiveWorldBattleground() and GetCurrentBattlegroundState()==BATTLEGROUND_STATE_FINISHED then
                    self:RefreshFromNative()
                    if self.visible and self.match and self.match.total then n:ShowAggregateScores(true) end
                end
            end,0)
        end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_PLAYER_ACTIVATED,function()
        self:RefreshFromNative()
        if self.visible and self.match and self.match.finished and self.match.total then n:ShowAggregateScores(true) end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_PLAYER_DEACTIVATED,function()
        self.visible=false;self.inMatch=false;self.window:SetHidden(true)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name..'Prompts',EVENT_SCREEN_RESIZED,function() self:LayoutNativePrompts() end)
    self:LayoutNativePrompts()
    self:RefreshFromNative()
end
