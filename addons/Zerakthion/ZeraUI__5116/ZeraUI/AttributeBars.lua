-- Default Attribute Bar adapter: arranges ESO's own resource controls and
-- visualizer modules while shared geometry, formatting, scene routing, and
-- HUD Editor guards live in AttributeCore.lua.
function ZeraUIAttachAttributes(A,UI)
    local core=ZeraUIAttributeCore
    local entries={
        {name="Health",control="ZO_PlayerAttributeHealth",power="COMBAT_MECHANIC_FLAGS_HEALTH",stat="STAT_HEALTH_MAX"},
        {name="Magicka",control="ZO_PlayerAttributeMagicka",power="COMBAT_MECHANIC_FLAGS_MAGICKA",stat="STAT_MAGICKA_MAX"},
        {name="Stamina",control="ZO_PlayerAttributeStamina",power="COMBAT_MECHANIC_FLAGS_STAMINA",stat="STAT_STAMINA_MAX"},
    }
    local function scale(c)
        if not c then return 1 end
        return (c.GetEffectiveScale and c:GetEffectiveScale()) or (c.GetScale and c:GetScale()) or 1
    end
    local function findModule()
        local v=PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer
        for m in pairs(v and v.visualModules or {}) do
            if ZO_UnitVisualizer_ShrinkExpandModule and m.IsInstanceOf and m:IsInstanceOf(ZO_UnitVisualizer_ShrinkExpandModule) then return m end
        end
    end
    local function post(obj,name,fn)
        if obj and type(obj[name])=="function" and type(SecurePostHook)=="function" then
            return pcall(SecurePostHook,obj,name,fn)
        end
    end
    local function pre(obj,name,fn)
        if obj and type(obj[name])=="function" and type(ZO_PreHook)=="function" then
            return pcall(ZO_PreHook,obj,name,fn)
        end
    end
    local function fixedWidth(c,w)
        if c:GetWidth()~=w then c:SetWidth(w) end
        if c.bgContainer and c.bgContainer:GetWidth()~=w then c.bgContainer:SetWidth(w) end
    end
    local function named(c,suffix)
        if c.GetNamedChild then return c:GetNamedChild(suffix) end
    end
    -- Scope the native width override to each actual resource update. Other
    -- bars (mount, werewolf, siege) and native HUD Edit retain stock widths.
    local function installWidthHook(m)
        local pending,depth={},0
        local okPost=post(m,"OnValueChanged",function(_,bar)
            local ctx=pending[depth]
            if ctx and ctx.bar==bar then
                depth=depth-1
                m.normalWidth,m.expandedWidth,m.shrunkWidth=ctx.normal,ctx.expanded,ctx.shrunk
                if ctx.entry and A.attrOwned and A.attrModule==m then fixedWidth(bar,ctx.entry.width) end
            end
        end)
        if not okPost then return false end
        return pre(m,"OnValueChanged",function(_,bar,info,_,instant)
            if A.attrOwned and A.attrModule==m and not A:IsNativeHudEditorOpen() then
                for _,e in ipairs(entries) do
                    if e.bar==bar and e.width then
                        depth=depth+1
                        local ctx=pending[depth]
                        if not ctx then ctx={}; pending[depth]=ctx end
                        ctx.bar,ctx.entry,ctx.normal,ctx.expanded,ctx.shrunk=bar,e,m.normalWidth,m.expandedWidth,m.shrunkWidth
                        m.normalWidth,m.expandedWidth,m.shrunkWidth=e.width,e.width,e.width
                        -- The native max-resource animation also drives the
                        -- triangular Warner glow, even when widths are equal.
                        -- Keep the real stat state without playing that visual.
                        if A.settings.attrCleanGlow~=false and not instant and info and type(info.value)=="number"
                            and ATTRIBUTE_BAR_STATE_NORMAL and ATTRIBUTE_BAR_STATE_EXPANDED and ATTRIBUTE_BAR_STATE_SHRUNK then
                            info.state=info.value>0 and ATTRIBUTE_BAR_STATE_EXPANDED or
                                info.value<0 and ATTRIBUTE_BAR_STATE_SHRUNK or ATTRIBUTE_BAR_STATE_NORMAL
                        end
                        return
                    end
                end
            end
        end)
    end
    -- Suspend the player visualizer's glow-producing modules at the source,
    -- using the native module registry. Shield and shrink/expand
    -- stay registered; restoration re-reads the current native visual state.
    local function glowKind(m)
        if not m.IsInstanceOf then return end
        if ZO_UnitVisualizer_UnwaveringModule and m:IsInstanceOf(ZO_UnitVisualizer_UnwaveringModule) then return "unwavering" end
        if ZO_UnitVisualizer_ArmorDamage and m:IsInstanceOf(ZO_UnitVisualizer_ArmorDamage) then return "armor" end
        if ZO_UnitVisualizer_PossessionModule and m:IsInstanceOf(ZO_UnitVisualizer_PossessionModule) then return "possession" end
    end
    local armorPoolMethods={"GetOrCreateIncreaseArmorPool","GetOrCreateDecreaseArmorPool","GetOrCreateIncreasePowerPool","GetOrCreateDecreasePowerPool"}
    local armorControls={"increasedArmorBg","increasedArmorFrame","decreasedArmorOverlay","increasedPowerTexture","increasedPowerGlow","decreasedPowerTexture"}
    local possessionControls={"possessionHaloTexture","possessionHaloGlow"}
    local function isOwnedBar(bar)
        for _,e in ipairs(entries) do if e.bar and bar==e.bar then return true end end
        return false
    end
    local function isOwnedResource(control)
        local parent=control and control.GetParent and control:GetParent()
        return isOwnedBar(parent)
    end
    local function belongsToResource(control)
        -- Pooled overlays can contain texture children. Check the current
        -- ancestry, not the control's original owner: ESO reuses its pools
        -- between player, target and other attribute visualizers.
        local current=control
        for _=1,16 do
            if not current then return false end
            if isOwnedBar(current) then return true end
            current=current.GetParent and current:GetParent() or nil
        end
        return false
    end
    local function visitPool(pool,fields,visit)
        if not pool or not pool.ActiveObjectIterator then return end
        for _,object in pool:ActiveObjectIterator() do
            if isOwnedResource(object) then visit(object)
            elseif type(object)=="table" then
                for _,field in ipairs(fields) do
                    local control=object[field]
                    if isOwnedResource(control) then visit(control) end
                end
            end
        end
    end
    local function visitGlow(m,kind,visit)
        if kind=="unwavering" then
            for _,info in pairs(m.barInfo or {}) do
                if info.control then visit(info.control,info.value) end
            end
        elseif kind=="armor" then
            for _,method in ipairs(armorPoolMethods) do
                if type(m[method])=="function" then visitPool(m[method](m),armorControls,visit) end
            end
        elseif kind=="possession" then
            for _,info in pairs(m.barInfo or {}) do
                if isOwnedResource(info.barOverlayControl) then visit(info.barOverlayControl,info.value) end
            end
            if type(m.GetOrCreatePossessionPool)=="function" then visitPool(m:GetOrCreatePossessionPool(),possessionControls,visit) end
        end
    end
    local function glowEnabled()
        return A.attrOwned and A.settings.attrCleanGlow~=false and not A:IsNativeHudEditorOpen()
    end
    local blankGlowPath=UI.path.."attribute_no_glow.dds"
    local function blankGlowArtwork(c)
        if not glowEnabled() or not belongsToResource(c) then return end
        if c.GetTextureFileName and c.SetTexture then
            local file=c:GetTextureFileName()
            if type(file)=="string" and file~="" and file:lower()~=blankGlowPath:lower() then
                A.attrGlowTextures[c]=file
                if not A.attrGlowTextureHooks[c] then
                    A.attrGlowTextureHooks[c]=true
                    post(c,"SetTexture",function(_,texture)
                        if texture~=blankGlowPath and A.attrGlowTextures[c] and glowEnabled() and belongsToResource(c) then blankGlowArtwork(c) end
                    end)
                end
                c:SetTexture(blankGlowPath)
            end
        end
        if c.GetNumChildren and c.GetChild then
            for i=1,c:GetNumChildren() do local child=c:GetChild(i); if child then blankGlowArtwork(child) end end
        end
    end
    local function hideGlowControl(c)
        if not glowEnabled() or not belongsToResource(c) or not c.SetHidden or not c.IsHidden then return end
        -- IsHidden can reflect a hidden HUD parent, even when the actual
        -- glow is locally shown. Check the local hidden flag instead.
        local hidden=c.IsControlHidden and c:IsControlHidden()
        if not c.IsControlHidden then hidden=c:IsHidden() end
        if not hidden then
            A.attrGlowHidden[c]=true
            c:SetHidden(true)
        end
        -- A native alpha timeline can retain bright artwork during a layout
        -- switch. Keep the visual control transparent as well as hidden.
        if c.GetAlpha and c.SetAlpha then
            local alpha=c:GetAlpha()
            if A.attrGlowAlpha[c]==nil then A.attrGlowAlpha[c]=alpha end
            if alpha~=0 then c:SetAlpha(0) end
        end
        -- Native timelines can animate visibility and opacity without Lua
        -- callbacks. A transparent effect texture still cannot render glow.
        blankGlowArtwork(c)
    end
    local function releasePooledGlow(c,show)
        -- Reset only controls previously modified by us. On pool release the
        -- parent is nil and the engine intentionally leaves the object hidden.
        local file=A.attrGlowTextures[c]
        if file then A.attrGlowTextures[c]=nil; c:SetTexture(file) end
        local alpha=A.attrGlowAlpha[c]
        if alpha~=nil then A.attrGlowAlpha[c]=nil; c:SetAlpha(alpha) end
        local hidden=A.attrGlowHidden[c]
        A.attrGlowHidden[c]=nil
        if show and hidden and c.SetHidden then c:SetHidden(false) end
        if c.GetNumChildren and c.GetChild then
            for i=1,c:GetNumChildren() do local child=c:GetChild(i); if child then releasePooledGlow(child,show) end end
        end
    end
    local function silenceGlow(m,kind)
        if not glowEnabled() then return end
        visitGlow(m,kind,function(c)
            if not A.attrGlowControlHooks[c] then
                A.attrGlowControlHooks[c]=true
                -- Native timelines may reveal these exact visual controls
                -- after the module callback (e.g. on skin or scene changes).
                -- Never hook general attribute, target or shield controls.
                post(c,"SetHidden",function(_,hidden) if not hidden then hideGlowControl(c) end end)
                if ZO_PostHookHandler then pcall(ZO_PostHookHandler,c,"OnEffectivelyShown",function() hideGlowControl(c) end) end
            end
            if (kind=="armor" or kind=="possession") and not A.attrGlowParentHooks[c] then
                A.attrGlowParentHooks[c]=post(c,"SetParent",function(_,parent)
                    if not belongsToResource(c) then releasePooledGlow(c,parent~=nil) end
                end)
            end
            hideGlowControl(c)
        end)
    end
    -- Identify the exact native white glow artwork even if another addon or
    -- a future template creates it outside a recognized module's barInfo.
    -- Only inspect our player resource bars, never target or shield art.
    local function silenceLooseGlow(c)
        if c.GetTextureFileName then
            local file=c:GetTextureFileName()
            if type(file)=="string" and file:lower():find("attributebar_dynamic_increasedpowerglow",1,true) then blankGlowArtwork(c) end
        end
        if c.GetNumChildren and c.GetChild then
            for i=1,c:GetNumChildren() do local child=c:GetChild(i); if child then silenceLooseGlow(child) end end
        end
    end
    local function silenceResourceWarning(e)
        if e.name=="Health" or not e.bar then return end
        local warner=e.bar.warner
        if warner and type(warner.SetPaused)=="function" then
            if not A.attrResourceWarners[warner] then
                A.attrResourceWarners[warner]={paused=warner.paused==true,power=e.power}
            end
            if not A.attrResourceWarnerHooks[warner] then
                A.attrResourceWarnerHooks[warner]=post(warner,"SetPaused",function(_,paused)
                    if paused==false and glowEnabled() then warner:SetPaused(true) end
                end)
            end
            if not warner.paused then warner:SetPaused(true) end
        end
        local control=e.bar.warnerContainer or named(e.bar,"Warner")
        if control then
            A.attrResourceWarningControls[control]=true
            if not A.attrGlowControlHooks[control] then
                A.attrGlowControlHooks[control]=true
                post(control,"SetHidden",function(_,hidden) if not hidden then hideGlowControl(control) end end)
            end
            hideGlowControl(control)
        end
    end
    local function silenceRegeneration(m)
        if not A.attrRegenHooks[m] then
            A.attrRegenHooks[m]=pre(m,"PlayArrow",function(_,bar)
                if glowEnabled() and isOwnedBar(bar) then return true end
            end)
        end
        -- Stop only arrows owned by the player's three bars; the pool and
        -- visualizers of other frames/addons are never globally released.
        local pool=m.arrowPool
        local active=pool and pool.GetActiveObjects and pool:GetActiveObjects()
        if active then for _,arrow in pairs(active) do
            if isOwnedResource(arrow) then
                if arrow.animation and arrow.animation.Stop then arrow.animation:Stop()
                elseif arrow.SetHidden then arrow:SetHidden(true) end
            end
        end end
    end
    function A:RestoreAttributeGlow()
        if not self.attrGlowHidden then return end
        for c,file in pairs(self.attrGlowTextures or {}) do c:SetTexture(file) end
        for c,alpha in pairs(self.attrGlowAlpha or {}) do c:SetAlpha(alpha) end
        for c in pairs(self.attrResourceWarningControls or {}) do
            if self.attrGlowHidden[c] then c:SetHidden(false) end
        end
        for m,kind in pairs(self.attrGlowHooks or {}) do
            visitGlow(m,kind,function(c,v)
                if self.attrGlowHidden[c] and (v==nil or v==true or (type(v)=="number" and v>0)) then c:SetHidden(false) end
            end)
        end
        self.attrGlowHidden={}
        self.attrGlowAlpha={}
        self.attrGlowTextures={}
        self.attrResourceWarningControls={}
        local warners=self.attrResourceWarners or {}
        self.attrResourceWarners={}
        for warner,old in pairs(warners) do
            -- A stopped native blink must not be restored half-lit.
            if warner.warning and warner.warning.SetAlpha then warner.warning:SetAlpha(0) end
            if not old.paused and GetUnitPower and _G[old.power] then
                local value=GetUnitPower("player",_G[old.power])
                if type(value)=="number" then warner.currentPower=value end
            end
            warner:SetPaused(old.paused)
        end
        local detached=self.attrGlowDetached or {}
        self.attrGlowDetached={}
        for m,record in pairs(detached) do
            if record.modules[m]==nil then record.modules[m]=record.value end
            -- Effects can have changed while the module was detached.
            if m.InitializeBarValues then m:InitializeBarValues() end
        end
    end
    function A:SyncAttributeGlow()
        if self.settings.attrCleanGlow==false then self:RestoreAttributeGlow(); return end
        self.attrGlowHidden=self.attrGlowHidden or {}
        self.attrGlowAlpha=self.attrGlowAlpha or {}
        self.attrGlowTextures=self.attrGlowTextures or {}
        self.attrGlowTextureHooks=self.attrGlowTextureHooks or {}
        self.attrGlowDetached=self.attrGlowDetached or {}
        self.attrGlowControlHooks=self.attrGlowControlHooks or {}
        self.attrGlowParentHooks=self.attrGlowParentHooks or {}
        self.attrGlowHooks=self.attrGlowHooks or {}
        self.attrResourceWarners=self.attrResourceWarners or {}
        self.attrResourceWarnerHooks=self.attrResourceWarnerHooks or {}
        self.attrResourceWarningControls=self.attrResourceWarningControls or {}
        self.attrRegenHooks=self.attrRegenHooks or {}
        local v=PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer
        local modules=v and v.visualModules
        if not modules then return end
        -- Finish existing native max-stat animations before pausing resource
        -- warners. Health's separate low-health Warner remains untouched.
        local resize=self.attrModule
        for _,e in ipairs(entries) do
            local info=resize and resize.barInfo and resize.barInfo[_G[e.stat]]
            local animation=info and info.animation
            if animation and animation.IsPlaying and animation:IsPlaying() then animation:Stop() end
            silenceResourceWarning(e)
        end
        for m,record in pairs(self.attrGlowDetached) do silenceGlow(m,record.kind) end
        for m,value in pairs(modules) do
            if ZO_UnitVisualizer_ArrowRegenerationModule and m.IsInstanceOf and m:IsInstanceOf(ZO_UnitVisualizer_ArrowRegenerationModule) then
                silenceRegeneration(m)
            end
            local kind=glowKind(m)
            if kind then
                if not self.attrGlowHooks[m] then
                    self.attrGlowHooks[m]=kind
                    local function update() silenceGlow(m,kind) end
                    -- A detached module may still have its own player-activated
                    -- callback. Skip its refresh until we restore the module.
                    pre(m,"InitializeBarValues",function() return glowEnabled() and A.attrGlowDetached[m]~=nil end)
                    for _,method in ipairs({"OnValueChanged","InitializeBarValues","ApplyPlatformStyle","OnUnitChanged","PlayAnimation","PlayPowerIncreaseAnimation","PlayPowerDecreaseAnimation","PlayArmorIncreaseAnimation","PlayArmorDecreaseAnimation"}) do post(m,method,update) end
                end
                silenceGlow(m,kind)
                if not self.attrGlowDetached[m] then
                    self.attrGlowDetached[m]={modules=modules,value=value,kind=kind}
                    modules[m]=nil
                end
            end
        end
        for _,e in ipairs(entries) do if e.bar then silenceLooseGlow(e.bar) end end
    end
    local function shieldValue(module)
        local bar=module and module.attributeInfo and module.attributeInfo[ATTRIBUTE_HEALTH]
        local info=bar and bar.visualInfo and bar.visualInfo[ATTRIBUTE_VISUAL_POWER_SHIELDING]
        return info and type(info.value)=="number" and math.max(0,info.value) or 0
    end
    local function stopDeadHealthWarner(bar)
        local warner=bar and bar.warner
        if not warner then return end
        if warner.warnAnimation and warner.warnAnimation.IsPlaying and warner.warnAnimation:IsPlaying() then
            warner.warnAnimation:Stop()
        end
        if warner.warning and warner.warning.SetAlpha then warner.warning:SetAlpha(0) end
    end
    local function onPower(kind,value,maxValue,effectiveMax)
        if not A.attrOwned then return end
        local e=A.attrByPower and A.attrByPower[kind]
        if not e or type(value)~="number" then return end
        local maximum=core.ReachableMax(maxValue,effectiveMax)
        if type(maximum)~="number" or maximum<=0 then maximum=e.maximum end
        if not maximum or maximum<=0 then return end
        e.value,e.maximum=value,maximum
        if e.name=="Health" and (value<=0 or (IsUnitDead and IsUnitDead("player"))) then
            stopDeadHealthWarner(e.bar)
        end
        A:RenderAttributeNumber(e,value,maximum,A.attrShieldAmount or 0)
    end
    -- Use the native PowerShield visualizer (zero extra visual events in Default mode).
    function A:SyncAttributeShield()
        local v=PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer
        local module
        for m in pairs(v and v.visualModules or {}) do
            if ZO_UnitVisualizer_PowerShieldModule and m.IsInstanceOf and m:IsInstanceOf(ZO_UnitVisualizer_PowerShieldModule) then module=m; break end
        end
        self.attrShieldModule=module
        self.attrShieldAmount=shieldValue(module)
        if not module then return end
        self.attrShieldHooks=self.attrShieldHooks or {}
        if not self.attrShieldHooks[module] then
            self.attrShieldHooks[module]=post(module,"OnValueChanged",function(_,_,_,visualType)
                if not self.attrOwned or self.attrShieldModule~=module or visualType~=ATTRIBUTE_VISUAL_POWER_SHIELDING then return end
                local amount=shieldValue(module)
                if amount==self.attrShieldAmount then return end
                self.attrShieldAmount=amount
                if self.settings.attrShieldValue==false then return end
                local health=entries[1]
                if health.value and health.maximum then onPower(_G[health.power],health.value,health.maximum,health.maximum) end
            end)
        end
    end
    function A:PositionAttributes()
        if not self.attrOwned or self:IsNativeHudEditorOpen() then return end
        local s=self.settings; local geometry=self:AttributeGeometry()
        for _,e in ipairs(entries) do
            local c=e.bar; local g=geometry[e.name]
            UI.reposition(e.anchor,self.root,g[1],g[2]); e.anchor:SetDimensions(g[3],g[4])
            c:ClearAnchors(); c:SetAnchor(TOPLEFT,e.anchor,TOPLEFT,0,0)
            c:SetScale(scale(self.root)*s.attrScale/scale(c:GetParent()))
            local width=g[3]/s.attrScale
            local changed=e.width~=width
            e.width=width
            -- Snap an existing native expand/shrink animation to the new width.
            -- Force a valid state transition exactly once per width change.
            local m=self.attrModule
            local stat=_G[e.stat]
            local info=stat and m.barInfo and m.barInfo[stat]
            if changed and info and type(info.value)=="number" and ANIMATION_INSTANT and ATTRIBUTE_BAR_STATE_EXPANDED and ATTRIBUTE_BAR_STATE_NORMAL then
                info.state=info.value==0 and ATTRIBUTE_BAR_STATE_EXPANDED or ATTRIBUTE_BAR_STATE_NORMAL
                m:OnValueChanged(c,info,stat,ANIMATION_INSTANT)
            end
            fixedWidth(c,width)
            -- Compare native width readings in the same coordinate space.
            -- Keep e.width unscaled for the layout and native width hooks.
            e.sceneWidth=c:GetWidth()
            e.sceneBgWidth=c.bgContainer and c.bgContainer:GetWidth()
        end
    end
    function A:ReleaseAttributes()
        if not self.attrOwned then return end
        self.attrOwned=false
        local m=self.attrModule
        local gamepad=IsInGamepadPreferredMode and IsInGamepadPreferredMode()
        self:RestoreAttributeGlow()
        for _,e in ipairs(entries) do
            local c,old=e.bar,e.old
            UI.hidden(e.number,true)
            -- When switching to gamepad mode, HUD_MANAGER has already applied
            -- gamepad anchors; do not overwrite them with keyboard anchors.
            -- PLAYER_ATTRIBUTE_BARS:ApplyStyle does not reset scale or
            -- dimensions, so always restore those from the snapshot.
            if not gamepad then core.RestoreAnchors(c,old.anchors) end
            local width=old.width
            local info=m and m.barInfo and m.barInfo[_G[e.stat]]
            if info and info.state~=old.state then
                if ATTRIBUTE_BAR_STATE_EXPANDED and info.state==ATTRIBUTE_BAR_STATE_EXPANDED then width=m.expandedWidth
                elseif ATTRIBUTE_BAR_STATE_SHRUNK and info.state==ATTRIBUTE_BAR_STATE_SHRUNK then width=m.shrunkWidth
                else width=m.normalWidth end
            end
            c:SetScale(old.scale); c:SetDimensions(width,old.height)
            if c.bgContainer and old.bgWidth then c.bgContainer:SetWidth(width==old.width and old.bgWidth or width) end
            if old.label then old.label:SetAlpha(old.alpha) end
            if e.forced and c.playerAttributeBarObject and c.playerAttributeBarObject.RemoveForcedVisibleReference then
                c.playerAttributeBarObject:RemoveForcedVisibleReference("ZeraUI"); e.forced=nil
            end
            e.old=nil; e.width=nil
            e.sceneWidth,e.sceneBgWidth=nil,nil
        end
    end
    -- A scene callback alone does not change resource geometry, font or
    -- visualizer ownership. Check the native objects we own and only fall
    -- back to a full repair when the host really changed them.
    function A:MaintainAttributeScene()
        if not self.attrOwned or not self.attrSceneModules then return false end
        local v=PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer
        local modules=v and v.visualModules
        if modules~=self.attrSceneModules then return false end
        for m in pairs(modules) do if not self.attrSceneModuleSet[m] then return false end end
        for m in pairs(self.attrSceneModuleSet) do if modules[m]==nil then return false end end
        for _,e in ipairs(entries) do
            local c=e.bar
            if not c or not e.old or not e.anchor or not e.width then return false end
            if c~=_G[e.control] or e.old.label~=c.resourceNumbersLabel then
                -- Reacquire a replaced native control/label, never silently
                -- keep a stale reference from a prior style generation.
                self:ReleaseAttributes(); return false
            end
            local valid,p,r,rp,x,y=c:GetAnchor(0)
            if not valid or p~=TOPLEFT or r~=e.anchor or rp~=TOPLEFT or x~=0 or y~=0 or c:GetAnchor(1) then return false end
            local expected=scale(self.root)*self.settings.attrScale/scale(c:GetParent())
            if math.abs(c:GetScale()-expected)>.001 then return false end
            if not e.sceneWidth or math.abs(c:GetWidth()-e.sceneWidth)>.01 then return false end
            if c.bgContainer~=e.sceneBackground or (c.bgContainer and (not e.sceneBgWidth or math.abs(c.bgContainer:GetWidth()-e.sceneBgWidth)>.01)) then return false end
            if c.GetNumChildren and c:GetNumChildren()~=e.sceneChildCount then return false end
        end
        -- Stock numbers can be made opaque again by the native scene; this
        -- is a cheap repair, not a reason to rebuild layout/glow/font state.
        for _,e in ipairs(entries) do
            local l=e.old.label
            if l and l:GetAlpha()~=0 then l:SetAlpha(0) end
        end
        return true
    end
    local function syncDefault(active,relayout)
        if not active then A:ReleaseAttributes(); return end
        local sceneOnly=not relayout
        if sceneOnly and A:MaintainAttributeScene() then return end
        if sceneOnly and A.NormalizeAttributeLayout then A:NormalizeAttributeLayout() end
        local s=A.settings
        if not A.attrOwned then
            local m=findModule()
            -- Fail closed if the game is not initialized or the native editor cannot be guarded.
            if not A.attrEditorGuard then A.attrStatus="Native HUD editor lifecycle unavailable; integration safely disabled"; return end
            if not m or not m.normalWidth or not m.expandedWidth or not m.shrunkWidth then A.attrStatus="Waiting for native attribute visualizer"; return end
            for _,e in ipairs(entries) do
                local c=_G[e.control]
                if not c or not c.GetAnchor or not c.GetWidth or not c.GetHeight or not c.GetScale or not c:GetParent() then A.attrStatus="Waiting for native attribute controls"; return end
                local a=core.SaveAnchors(c); if not a or #a==0 then A.attrStatus="Waiting for native attribute anchors"; return end
                local l=c.resourceNumbersLabel
                local info=m.barInfo and m.barInfo[_G[e.stat]]
                e.bar=c; e.old={anchors=a,width=c:GetWidth(),height=c:GetHeight(),scale=c:GetScale(),bgWidth=c.bgContainer and c.bgContainer:GetWidth(),label=l,alpha=l and l:GetAlpha(),state=info and info.state}
            end
            A.attrModule=m
            if A.attrHookedModule~=m then
                A.attrShrinkHookReady=installWidthHook(m)
                A.attrHookedModule=m
            end
            if not A.attrShrinkHookReady then A.attrStatus="Native width hooks unavailable; integration safely disabled"; return end
            A.attrByPower={}; A.attrBaseHeight=0
            for _,e in ipairs(entries) do
                local c=e.bar
                if c.SetHidden and c.IsControlHidden and c:IsControlHidden() then c:SetHidden(false) end
                A.attrByPower[_G[e.power] or e.name]=e
                A.attrBaseHeight=math.max(A.attrBaseHeight,e.old.height)
                if not e.anchor then e.anchor=UI.panel(A.root,1,1,0,0) end
                if not e.number then
                    e.number=UI.text(c,16,100,24,0,0,30)
                    e.number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                    e.number:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                    e.number:SetDrawTier(DT_HIGH)
                end
                if e.old.label then e.old.label:SetAlpha(0) end
                local obj=c.playerAttributeBarObject
                if obj and obj.AddForcedVisibleReference and obj.RemoveForcedVisibleReference then
                    local ok=pcall(obj.AddForcedVisibleReference,obj,"ZeraUI"); e.forced=ok
                end
                if obj and not e.hookedLabel then
                    e.hookedLabel=post(obj,"UpdateResourceNumbersLabel",function()
                        if A.attrOwned and e.old and e.old.label and e.old.label:GetAlpha()~=0 then e.old.label:SetAlpha(0) end
                    end)
                end
                if e.name=="Health" and c.warner and not e.hookedDeadWarner then
                    e.hookedDeadWarner=post(c.warner,"UpdateAlphaPulse",function(_,healthPerc)
                        if A.attrOwned and ((type(healthPerc)=="number" and healthPerc<=0) or (IsUnitDead and IsUnitDead("player"))) then
                            stopDeadHealthWarner(c)
                        end
                    end)
                end
            end
            A.attrOwned=true
        end
        A.attrStatus="Active: "..s.attrLayout..(s.attrSplit and " (individual)" or " (grouped)")
        A:PositionAttributes()
        A:SyncAttributeGlow()
        A:SyncAttributeShield()
        local face=A:ResolveFont(s.attrFont=="HUD font" and s.fontFace or s.attrFont)
        for _,e in ipairs(entries) do
            local c=e.bar; local h=e.old.height; local w=e.width
            -- Native style/scene refreshes may restore stock number opacity.
            if e.old.label and e.old.label:GetAlpha()~=0 then e.old.label:SetAlpha(0) end
            A:LayoutAttributeNumber(e.number,c.bgContainer or c,w,h,face)
            UI.hidden(e.number,false,true)
            e.displayKey,e.lastPercent,e.danger=nil,nil,nil
            local power=_G[e.power]
            if power and GetUnitPower then onPower(power,GetUnitPower("player",power)) end
            e.sceneBackground=c.bgContainer
            e.sceneChildCount=c.GetNumChildren and c:GetNumChildren() or nil
        end
        local v=PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer
        A.attrSceneModules=v and v.visualModules
        A.attrSceneModuleSet={}
        for m in pairs(A.attrSceneModules or {}) do A.attrSceneModuleSet[m]=true end
    end
    core.RegisterAdapter("default",{Sync=syncDefault,OnPower=onPower})
end
