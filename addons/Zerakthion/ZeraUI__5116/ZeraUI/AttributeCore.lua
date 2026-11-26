-- Shared native-API engine for Zera's attribute bar modes (Default, Custom
-- flat, and Curved arcs): reachable-max calculation, value formatting/cache
-- keys, anchor snapshot/restore, single visual-event subscription, shared
-- update-rate gate, and pausing ESO's hidden attribute bars and warners.
ZeraUIAttributeCore={}
local core=ZeraUIAttributeCore
local unpack=unpack or table.unpack

-- The largest value a resource pool can actually reach. ESO's own bar fills
-- current/powerMax and uses effectiveMax only for its number label
-- (playerattributebars.lua UpdateStatusBar). During some encounter mechanics
-- effectiveMax stays above powerMax; taking the smaller positive value keeps
-- fill and percentage aligned.
function core.ReachableMax(maxValue,effectiveMax)
    local m=type(maxValue)=="number" and maxValue>0 and maxValue or nil
    local e=type(effectiveMax)=="number" and effectiveMax>0 and effectiveMax or nil
    if m and e then return m<e and m or e end
    return m or e
end
ZeraUIReachableMax=core.ReachableMax

-- Match the native ESO abbreviated resource number (one decimal) while
-- supporting Zera's Short, Full, and Full / Max formats with zero allocation
-- when display keys are unchanged.
function core.FormatValue(v,format,maxValue)
    if format=="Full / Max" then return tostring(v).." / "..tostring(maxValue) end
    if format=="Full" or v<1000 then return tostring(v) end
    local tenths=math.floor(v/100+.5)
    if tenths%10==0 then return tostring(tenths/10):gsub("%.0$","").."k" end
    return string.format("%.1fk",tenths/10)
end
function core.DisplayKey(n,format)
    return format=="Short" and n>=1000 and -math.floor(n/100+.5) or n
end
function core.ShieldKey(shieldWhole)
    if shieldWhole<=0 then return -1 end
    return shieldWhole>=1000 and -(math.floor(shieldWhole/100+.5)+2) or shieldWhole
end

function core.SaveAnchors(control)
    if not (control and control.GetAnchor) then return nil end
    local result={}
    for i=0,1 do
        local valid,p,r,rp,x,y,constrains=control:GetAnchor(i)
        if valid then result[#result+1]={p,r,rp,x,y,constrains} end
    end
    return result
end
function core.RestoreAnchors(control,saved)
    if not (control and saved and control.ClearAnchors and control.SetAnchor) then return end
    control:ClearAnchors()
    for _,a in ipairs(saved) do control:SetAnchor(unpack(a,1,a[6]~=nil and 6 or 5)) end
end

-- Same arguments ESO's PowerShield module uses for the player's health bar
-- (powershield.lua CreateInfoTable / unitattributevisualizermodulebase.lua).
-- Engine-aggregated totals avoid per-effect delta drift and sequenceId desync.
local function visual(kind)
    if not (GetUnitAttributeVisualizerEffectInfo and kind) then return 0 end
    return GetUnitAttributeVisualizerEffectInfo("player",kind,STAT_MITIGATION,ATTRIBUTE_HEALTH,COMBAT_MECHANIC_FLAGS_HEALTH) or 0
end
function core.ReadVisuals(out)
    out=out or {}
    out.shield=visual(ATTRIBUTE_VISUAL_POWER_SHIELDING)
    out.trauma=visual(ATTRIBUTE_VISUAL_TRAUMA)
    out.noHealing=visual(ATTRIBUTE_VISUAL_NO_HEALING)>0
    return out
end
-- One visual only (the one an event reports): one engine call.
local FIELD
function core.ReadVisual(out,kind)
    if not FIELD then
        FIELD={}
        if ATTRIBUTE_VISUAL_POWER_SHIELDING then FIELD[ATTRIBUTE_VISUAL_POWER_SHIELDING]="shield" end
        if ATTRIBUTE_VISUAL_TRAUMA then FIELD[ATTRIBUTE_VISUAL_TRAUMA]="trauma" end
        if ATTRIBUTE_VISUAL_NO_HEALING then FIELD[ATTRIBUTE_VISUAL_NO_HEALING]="noHealing" end
    end
    local field=FIELD[kind]
    if not field then return false end
    local value=visual(kind)
    if field=="noHealing" then value=value>0 end
    if out[field]==value then return false end
    out[field]=value
    return true
end

-- Single player visual-event subscription shared by Custom flat and Curved
-- arcs (registered only while a consumer is active; zero listeners in Off or
-- Default mode).
core.vis={shield=0,trauma=0,noHealing=false}
local VISUAL_EVENTS={"EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED","EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED","EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED"}
local VISUAL_NS="ZeraUIAttributeVisual"
local wantedVisual
local visualConsumer
local visualRegistered=false
local function onVisual(_,unitTag,visualType,_,attribute)
    if unitTag~="player" or not wantedVisual[visualType] then return end
    if attribute and ATTRIBUTE_HEALTH and attribute~=ATTRIBUTE_HEALTH then return end
    if not core.ReadVisual(core.vis,visualType) then return end
    if visualConsumer then visualConsumer(core.vis,visualType) end
end
function core.SetVisualConsumer(fn)
    visualConsumer=fn
    local E=EVENT_MANAGER
    if not E then return end
    if fn and not visualRegistered then
        if not wantedVisual then
            wantedVisual={}
            for _,k in ipairs({"ATTRIBUTE_VISUAL_POWER_SHIELDING","ATTRIBUTE_VISUAL_TRAUMA","ATTRIBUTE_VISUAL_NO_HEALING"}) do
                if _G[k] then wantedVisual[_G[k]]=true end
            end
        end
        for i,name in ipairs(VISUAL_EVENTS) do
            local ev=_G[name]
            if ev then
                E:RegisterForEvent(VISUAL_NS..i,ev,onVisual)
                if REGISTER_FILTER_UNIT_TAG then
                    E:AddFilterForEvent(VISUAL_NS..i,ev,REGISTER_FILTER_UNIT_TAG,"player")
                end
            end
        end
        visualRegistered=true
    elseif not fn and visualRegistered then
        visualRegistered=false
        for i,name in ipairs(VISUAL_EVENTS) do
            local ev=_G[name]
            if ev then E:UnregisterForEvent(VISUAL_NS..i,ev) end
        end
    end
end

-- Update rate: "Every change" draws each event; the throttled rates draw at
-- most N times a second per key and always draw the last value afterwards.
core.RATES={"Every change","Max 20 per second","Max 10 per second"}
local INTERVAL={["Max 20 per second"]=50,["Max 10 per second"]=100}
function core.Interval(A) return INTERVAL[A.settings.attrUpdateRate] end
function core.NewGate(A,ns)
    local g={last={},pending={}}
    local function flush()
        local ms=core.Interval(A)
        local now=GetFrameTimeMilliseconds()
        local left=false
        for key,draw in pairs(g.pending) do
            if not ms or now-(g.last[key] or 0)>=ms then
                g.pending[key]=nil; g.last[key]=now; draw()
            else left=true end
        end
        if not left then g.armed=nil; EVENT_MANAGER:UnregisterForUpdate(ns) end
    end
    function g:Request(key,draw)
        local ms=core.Interval(A)
        if not ms then self.pending[key]=nil; draw(); return end
        local now=GetFrameTimeMilliseconds()
        local last=self.last[key]
        if not last or now-last>=ms then
            self.pending[key]=nil; self.last[key]=now; draw(); return
        end
        self.pending[key]=draw
        if not self.armed then self.armed=true; EVENT_MANAGER:RegisterForUpdate(ns,ms,flush) end
    end
    function g:Cancel()
        for key in pairs(self.pending) do self.pending[key]=nil end
        if self.armed then self.armed=nil; EVENT_MANAGER:UnregisterForUpdate(ns) end
    end
    return g
end
function core.Gate(A)
    if not core.sharedGate then core.sharedGate=core.NewGate(A,"ZeraUIAttributeRate") end
    return core.sharedGate
end
function core.CancelGate()
    if core.sharedGate then core.sharedGate:Cancel() end
end

-- Hidden native bars still ran ESO's power handler on every change and
-- started a 500 ms smooth fill (trial boss profile: 2771 calls, 60 ms in
-- 30 s, plus the animations). While Zera's bars own the screen the handler
-- is unregistered; afterwards ESO's handler is registered again as
-- playerattributebars.lua does, with its power-type filter, and the bar is
-- refreshed once from the current values. One table for Curved and Custom,
-- so a bar is never unregistered or registered twice.
core.NATIVE={"ZO_PlayerAttributeHealth","ZO_PlayerAttributeMagicka","ZO_PlayerAttributeStamina","ZO_PlayerAttributeMountStamina"}
core.FLAT_NATIVE={"ZO_PlayerAttributeHealth","ZO_PlayerAttributeMagicka","ZO_PlayerAttributeStamina"}
local paused={}
local pausedWarners={}
local warnerHooks={}
local function pauseWarner(c,on)
    local warner=c and c.warner
    if not (warner and type(warner.SetPaused)=="function") then return end
    if on and not pausedWarners[warner] then
        local bar=c.playerAttributeBarObject
        pausedWarners[warner]={
            paused=warner.paused==true,
            power=(bar and bar.powerType) or warner.powerType or (c==_G.ZO_PlayerAttributeHealth and COMBAT_MECHANIC_FLAGS_HEALTH or nil),
        }
        -- ShrinkExpand (OnStop) and Unwavering (OnPlay) call warner:SetPaused(false);
        -- keep the hidden bar's warner paused until native bars are restored,
        -- and remember that the host requested unpause if it was mid-animation.
        if not warnerHooks[warner] and type(SecurePostHook)=="function" then
            warnerHooks[warner]=pcall(SecurePostHook,warner,"SetPaused",function(_,isPaused)
                if isPaused==false and pausedWarners[warner] then
                    pausedWarners[warner].paused=false
                    warner:SetPaused(true)
                end
            end)
        end
        if not warner.paused then warner:SetPaused(true) end
        if warner.warning and warner.warning.SetAlpha then warner.warning:SetAlpha(0) end
    elseif not on and pausedWarners[warner] then
        local old=pausedWarners[warner]
        pausedWarners[warner]=nil
        if warner.warning and warner.warning.SetAlpha then warner.warning:SetAlpha(0) end
        if not old.paused and old.power and GetUnitPower then
            local value=GetUnitPower("player",old.power)
            if type(value)=="number" then warner.currentPower=value end
        end
        warner:SetPaused(old.paused)
    end
end
function core.PauseNative(c,on)
    local bar=c.playerAttributeBarObject
    if not (bar and EVENT_POWER_UPDATE and c.RegisterForEvent and c.UnregisterForEvent) then return end
    if on and not paused[c] then
        c:UnregisterForEvent(EVENT_POWER_UPDATE); paused[c]=true
    elseif not on and paused[c] then
        paused[c]=nil
        c:RegisterForEvent(EVENT_POWER_UPDATE,function(_,unitTag,powerPoolIndex,powerType,current,max,effectiveMax)
            bar:OnPowerUpdate(unitTag,powerPoolIndex,powerType,current,max,effectiveMax)
        end)
        if c.AddFilterForEvent and REGISTER_FILTER_POWER_TYPE and bar.powerType then
            c:AddFilterForEvent(EVENT_POWER_UPDATE,REGISTER_FILTER_POWER_TYPE,bar.powerType)
        end
        if bar.UpdateStatusBar then bar:UpdateStatusBar() end
        -- Refresh ESO's contextual fade delay so restored native bars appear
        -- instead of staying faded to alpha 0 while resources are full.
        if bar.ResetFadeOutDelay then bar:ResetFadeOutDelay() end
        if bar.UpdateContextualFading then bar:UpdateContextualFading() end
    end
end
-- The player's ESO visualizer modules keep drawing on the hidden bars.
-- PowerShield: every overlay draw (shield/trauma events, the native bar's
-- value and max handlers, its per-frame resize check) ends in
-- OnStatusBarValueChanged; that is skipped, while OnValueChanged (shield and
-- trauma sounds, tutorial) still runs. ArrowRegeneration: arrows are not
-- played. Hooks are on the player's own module instances only, so target
-- and group frames are untouched.
local quiet=false
local hooked={}
local function playerModules()
    local v=PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer
    return v and v.visualModules or {}
end
local function isA(m,cls) return cls and m.IsInstanceOf and m:IsInstanceOf(cls) end
local function quietModules()
    if type(ZO_PreHook)~="function" then return end
    for m in pairs(playerModules()) do
        if not hooked[m] then
            if isA(m,ZO_UnitVisualizer_PowerShieldModule) and m.OnStatusBarValueChanged then
                hooked[m]=pcall(ZO_PreHook,m,"OnStatusBarValueChanged",function() return quiet end)
            elseif isA(m,ZO_UnitVisualizer_ArrowRegenerationModule) and m.PlayArrow then
                hooked[m]=pcall(ZO_PreHook,m,"PlayArrow",function() return quiet end)
            end
        end
    end
end
-- Redraw the shield overlay once from the values ESO kept current.
local function redrawShield()
    for m in pairs(playerModules()) do
        if isA(m,ZO_UnitVisualizer_PowerShieldModule) and m.UpdateValue and m.attributeInfo and m.attributeBarControls then
            for attribute,info in pairs(m.attributeInfo) do
                local bar=m.attributeBarControls[attribute]
                if bar then pcall(m.UpdateValue,m,bar,info) end
            end
        end
    end
end
-- Hide (and pause) or show (and resume) ESO's attribute bars (all four,
-- or the names given) along with their native warners.
function core.SetNative(hidden,names)
    if hidden then quiet=true; quietModules() end
    local wasQuiet=quiet
    if not hidden then quiet=false end
    for _,name in ipairs(names or core.NATIVE) do
        local c=_G[name]
        if c and c.SetHidden then c:SetHidden(hidden) end
        if c then
            core.PauseNative(c,hidden)
            pauseWarner(c,hidden)
        end
    end
    if not hidden and wasQuiet then redrawShield() end
end

-- Shared adapter registry, scene policy, HUD Editor lifecycle guard, flat
-- layout/number helpers, and single power/mode router for Default, Custom
-- flat, and Curved attribute bars.
local FLAT_NAMES={"Health","Magicka","Stamina"}
local adapters={}
core.activeAdapter=nil
function core.RegisterAdapter(name,adapter)
    adapters[name]=adapter
end

local function preHook(obj,name,fn)
    if obj and type(obj[name])=="function" and type(ZO_PreHook)=="function" then
        return pcall(ZO_PreHook,obj,name,fn)
    end
end
local function postHook(obj,name,fn)
    if obj and type(obj[name])=="function" and type(SecurePostHook)=="function" then
        return pcall(SecurePostHook,obj,name,fn)
    end
end

function ZeraUIAttachAttributeCore(A,UI)
    function A:IsNativeHudEditorOpen()
        local editor=HUD_EDITOR_KEYBOARD
        return self.attrNativeSuspended or (editor and editor.IsShowing and editor:IsShowing()) or false
    end
    function A:AttributeGeometry()
        local s=self.settings
        local w,h=s.attrWidth*s.attrScale,(self.attrBaseHeight or 24)*s.attrScale
        local g=s.attrGap
        local layout=s.attrLayout
        local gw,gh=layout=="Native" and 3*w+2*g or layout=="Stacked" and w or 2*w+g,
            layout=="Native" and h or layout=="Stacked" and 3*h+2*g or 2*h+g
        local top=36+s.gridY-(s.showGCD==false and 22 or 55)-4
        local x,y=275+s.gridX-gw/2+s.attrX,top-gh+s.attrY
        local result={Attributes={x,y,gw,gh}}
        local positions=layout=="Native" and {{w+g,0},{0,0},{2*(w+g),0}} or
            layout=="Stacked" and {{0,0},{0,h+g},{0,2*(h+g)}} or {{(w+g)/2,0},{0,h+g},{w+g,h+g}}
        for i,name in ipairs(FLAT_NAMES) do
            local ox,oy=0,0
            if s.attrSplit then ox,oy=s["attr"..name.."X"],s["attr"..name.."Y"] end
            result[name]={x+positions[i][1]+ox,y+positions[i][2]+oy,w,h}
        end
        return result
    end
    -- Keyboard loot is a HUD interaction, but ESO gives it a separate scene.
    -- Keep the attribute layout across the transition; the action bar can
    -- still hide as before while looting.
    function A:IsAttributeScene()
        if SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui") or SCENE_MANAGER:IsShowing("loot") then return true end
        local nextScene=SCENE_MANAGER.GetNextScene and SCENE_MANAGER:GetNextScene()
        local name=nextScene and nextScene.GetName and nextScene:GetName()
        return name=="hud" or name=="hudui" or name=="loot"
    end
    -- Size and place the number on a flat bar of local size w x h (shared by
    -- Default and Custom flat bars).
    function A:LayoutAttributeNumber(number,anchorTo,w,h,face)
        local s=self.settings
        local padding=math.min(12,w*.08)
        local nw=w-2*padding
        local ts=math.min(s.attrTextSize,math.max(10,math.floor(h*.85)))
        local sample=(s.attrFormat=="Full / Max" and "88888 / 88888") or (s.attrFormat=="Full" and "88888") or "88.8k"
        if s.attrShieldValue~=false then sample=sample.." (88.8k)" end
        if s.attrPercent then sample=sample.." 100%" end
        local style=s.attrOutline or "thick-outline"
        local pad=style:find("thick%-outline") and 4 or style:find("outline") and 2 or 0
        local numberSize=ts
        local function measured()
            local width
            if self.MeasureStringUIWidth then
                width=self:MeasureStringUIWidth(number,sample)
            elseif number.GetStringWidth then
                local ok,w=pcall(number.GetStringWidth,number,sample)
                width=ok and w or nil
            end
            return type(width)=="number" and width>0 and width+pad or nil
        end
        if self.MeasureStringUIWidth or number.GetStringWidth then
            self:ApplyNativeFont(number,face,numberSize,style,"attribute")
            local width=measured()
            local tries=0
            while width and width>nw and numberSize>8 and tries<10 do
                numberSize=math.max(8,math.min(numberSize-1,math.floor(numberSize*nw/width)))
                self:ApplyNativeFont(number,face,numberSize,style,"attribute")
                width=measured(); tries=tries+1
            end
        else
            local chars=#sample
            numberSize=math.min(ts,math.max(10,math.floor(nw/(chars*.58))))
        end
        self:ApplyNativeFont(number,face,numberSize,style,"attribute")
        local offsetY=s.attrTextOffsetY or 0
        number:SetDimensions(nw,h)
        number:ClearAnchors()
        number:SetAnchor(CENTER,anchorTo,CENTER,0,offsetY)
    end
    -- The number on a flat bar (Default and Custom): cached by displayed keys,
    -- so an event that changes nothing visible makes no UI call.
    function A:RenderAttributeNumber(e,value,maximum,shieldAmount)
        local s=self.settings
        local n=math.max(0,math.floor(value+.5))
        local pct=math.max(0,math.min(100,value/maximum*100))
        local displayKey=core.DisplayKey(n,s.attrFormat)
        local maxKey=s.attrFormat=="Full / Max" and math.floor(maximum+.5) or 0
        local rounded=s.attrPercent and math.floor(pct+.5) or -1
        local dead=e.name=="Health" and (value<=0 or (IsUnitDead and IsUnitDead("player")))
        local danger=not dead and s.attrLowWarning and pct<=25 and (e.name=="Health" or s.attrCleanGlow==false)
        local shield=e.name=="Health" and s.attrShieldValue~=false and (shieldAmount or 0) or 0
        local shieldWhole=math.floor(shield+.5)
        local shieldKey=core.ShieldKey(shieldWhole)
        local shieldText=e.shieldText or ""
        if e.shieldKey~=shieldKey then
            shieldText=shield>0 and core.FormatValue(shieldWhole,"Short",shield) or ""
        end
        local richLow=shieldText~="" and danger or false
        if e.displayKey~=displayKey or e.maxKey~=maxKey or e.format~=s.attrFormat or e.lastPercent~=rounded or e.shieldKey~=shieldKey or e.richLow~=richLow then
            local display=core.FormatValue(n,s.attrFormat,math.floor(maximum+.5))
            if richLow then display="|cFF3030"..display.."|r" end
            if shieldText~="" then display=display.." |c4DA6FF("..shieldText..")|r" end
            if rounded>=0 then
                local percent=tostring(rounded).."%"
                display=display.." "..(richLow and "|cFF3030"..percent.."|r" or percent)
            end
            UI.setText(e.number,display)
            e.displayKey,e.maxKey,e.format,e.lastPercent=displayKey,maxKey,s.attrFormat,rounded
            e.shieldText,e.shieldKey,e.richLow=shieldText,shieldKey,richLow
        end
        local redLabel=danger and shieldText=="" or false
        if e.danger~=redLabel then
            local gb=redLabel and .19 or 1
            UI.color(e.number,1,gb,gb,1); e.danger=redLabel
        end
    end
    -- Single EVENT_POWER_UPDATE dispatch to whichever attribute bar mode is
    -- currently active (zero allocations, zero duplicate power listeners).
    function A:UpdateAttributePower(kind,value,maxValue,effectiveMax)
        local adapter=core.activeAdapter
        if adapter and adapter.OnPower then
            adapter.OnPower(kind,value,maxValue,effectiveMax)
        end
    end
    -- Unified mode router for Off, Default, Custom flat, and Curved modes.
    -- Always deactivates non-target adapters before activating the target so
    -- native controls, warners, and visual subscriptions never overlap.
    function A:SyncAttributes(sceneOnly)
        if not sceneOnly and self.NormalizeAttributeLayout then self:NormalizeAttributeLayout() end
        local s=self.settings
        local hud=self:IsAttributeScene()
        local blocked=not s.enabled or not s.attrEnabled or not hud or self:IsNativeHudEditorOpen() or (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
        local target
        if not blocked then
            if s.attrMode=="Custom" and s.attrLayout=="Curved" then target="curved"
            elseif s.attrMode=="Custom" then target="custom"
            elseif s.attrMode=="Default" then target="default" end
        end
        local relayout=not sceneOnly
        for name,adapter in pairs(adapters) do
            if name~=target then adapter.Sync(false,relayout) end
        end
        local active=target and adapters[target] or nil
        if not active then
            core.activeAdapter=nil
            core.SetVisualConsumer(nil)
            core.CancelGate()
            self.attrStatus="Native layout (disabled, outside HUD or native editor active)"
            if self.editing and self.UpdateEditHandles then self:UpdateEditHandles() end
            return
        end
        core.activeAdapter=active
        active.Sync(true,relayout)
        if target=="default" and not self.attrOwned then
            core.activeAdapter=nil
        end
        if self.editing and self.UpdateEditHandles then self:UpdateEditHandles() end
    end

    local function suspend()
        if A.attrNativeSuspended then return end
        A.attrNativeSuspended=true
        if A.editing then A:FinishEdit(false,true) end
        if A.CloseTrackMenu then A:CloseTrackMenu() end
        if A.ReleaseAttributes then A:ReleaseAttributes() end
        A:ApplyVisibility()
    end
    local resumePending=false
    local function refresh()
        resumePending=false
        if not A:IsNativeHudEditorOpen() then A:ApplyVisibility() end
    end
    local function resume()
        A.attrNativeSuspended=false
        if zo_callLater then
            if resumePending then return end
            resumePending=true
            zo_callLater(refresh,0)
        else
            refresh()
        end
    end
    local editor=HUD_EDITOR_KEYBOARD
    if editor then
        local opening,closing=false,false
        for _,name in ipairs({"Show","OnShowing","ShowEditor"}) do if preHook(editor,name,suspend) then opening=true end end
        preHook(editor,"RebuildAllElements",function() if editor:IsShowing() then suspend() end end)
        for _,name in ipairs({"Hide","OnHidden","HideEditor"}) do if postHook(editor,name,resume) then closing=true end end
        local c=editor.control
        if c and ZO_PreHookHandler then
            for _,pair in ipairs({{"OnShow","OnHide"},{"OnEffectivelyShown","OnEffectivelyHidden"}}) do
                opening=pcall(ZO_PreHookHandler,c,pair[1],suspend) or opening
                if ZO_PostHookHandler then closing=pcall(ZO_PostHookHandler,c,pair[2],resume) or closing
                elseif zo_callLater then closing=pcall(ZO_PreHookHandler,c,pair[2],resume) or closing end
            end
        end
        local scene=editor.scene or (SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene("hud_editor_keyboard"))
        if scene and scene.RegisterCallback and SCENE_SHOWING and SCENE_HIDDEN then
            scene:RegisterCallback("StateChange",function(_,state)
                if state==SCENE_SHOWING then suspend() elseif state==SCENE_HIDDEN then resume() end
            end); opening,closing=true,true
        end
        local fragment=editor.fragment
        if fragment and fragment.RegisterCallback and SCENE_FRAGMENT_SHOWING and SCENE_FRAGMENT_HIDDEN then
            fragment:RegisterCallback("StateChange",function(_,state)
                if state==SCENE_FRAGMENT_SHOWING then suspend() elseif state==SCENE_FRAGMENT_HIDDEN then resume() end
            end); opening,closing=true,true
        end
        A.attrEditorGuard=opening and closing
    end
    for _,method in ipairs({"ApplyStyle","OnScreenResized"}) do
        postHook(PLAYER_ATTRIBUTE_BARS,method,function()
            if A:IsNativeHudEditorOpen() then return end
            if A.attrOwned then A:SyncAttributes()
            elseif A.IsCustomBarsActive and A:IsCustomBarsActive() and not (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) and A.RehangCustomSmallBars then
                A:RehangCustomSmallBars()
            end
        end)
    end
end
