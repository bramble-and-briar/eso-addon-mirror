-- Move only the existing player-to-player prompt and instance kick warning.
-- Uses native ZO_Anchor and GetScreenRect while keeping an independent editor
-- proxy and yielding cleanly if HUD_MANAGER already owns the native control.
function ZeraUIAttachPlayerInteraction(A,UI)
    local function tr(text) return A.settings and A.settings.menuLanguage=="tr" and ZeraUITranslate and ZeraUITranslate(text) or text end
    local function read(c)
        if not c or not c.GetAnchor or not c.ClearAnchors or not c.SetAnchor then return end
        local valid,p,r,rp,x,y,constrains=c:GetAnchor(0)
        if not valid or c:GetAnchor(1) or type(x)~="number" or type(y)~="number" then return end
        if ZO_Anchor then return ZO_Anchor:New(p,r,rp,x,y,constrains) end
        return {p,r,rp,x,y,constrains}
    end
    local function unpackAnchor(a)
        if not a then return end
        if a.GetMyPoint and a.GetOffsets then
            local ox,oy=a:GetOffsets()
            return a:GetMyPoint(),a:GetTarget(),a:GetRelativePoint(),ox,oy,a.GetConstraints and a:GetConstraints() or nil
        end
        return a[1],a[2],a[3],a[4],a[5],a[6]
    end
    local function equal(a,b)
        if not a or not b then return false end
        local p1,r1,rp1,x1,y1,c1=unpackAnchor(a)
        local p2,r2,rp2,x2,y2,c2=unpackAnchor(b)
        return p1==p2 and r1==r2 and rp1==rp2 and x1==x2 and y1==y2 and c1==c2
    end
    local function write(c,a)
        if a.Set then a:Set(c); return end
        c:ClearAnchors()
        if a[6]~=nil then c:SetAnchor(a[1],a[2],a[3],a[4],a[5],a[6])
        else c:SetAnchor(a[1],a[2],a[3],a[4],a[5]) end
    end
    local function registered(c)
        -- Yield if ESO's native HUD editor already manages this control.
        return HUD_MANAGER and HUD_MANAGER.GetKeyboardElementForControl and not not HUD_MANAGER:GetKeyboardElementForControl(c)
    end
    local function relativeScale(c)
        -- Control:GetScale() in ESO API 101051 includes inherited ancestor
        -- scale while GuiRoot:GetScale() stays 1 (verified via live Probe B).
        if c and c.GetScale and GuiRoot and GuiRoot.GetScale then
            local rootScale,controlScale=GuiRoot:GetScale(),c:GetScale()
            if rootScale and controlScale and rootScale>0 and controlScale>0 then return controlScale/rootScale end
        end
        return 1
    end
    local function factors(point)
        local x,y=.5,.5
        if point==LEFT or point==TOPLEFT or point==BOTTOMLEFT then x=0
        elseif point==RIGHT or point==TOPRIGHT or point==BOTTOMRIGHT then x=1 end
        if point==TOP or point==TOPLEFT or point==TOPRIGHT then y=0
        elseif point==BOTTOM or point==BOTTOMLEFT or point==BOTTOMRIGHT then y=1 end
        return x,y
    end
    local function bounds(c)
        if not c then return end
        local l,t,r,b
        if c.GetScreenRect then l,t,r,b=c:GetScreenRect()
        elseif c.GetLeft and c.GetTop and c.GetRight and c.GetBottom then l,t,r,b=c:GetLeft(),c:GetTop(),c:GetRight(),c:GetBottom() end
        if type(l)=="number" and type(t)=="number" and type(r)=="number" and type(b)=="number" and r>l and b>t then return l,t,r,b end
    end
    local function baseCenter(c,a,height)
        if not c or not a then return 0,120 end
        local gl,gt,gr,gb=bounds(GuiRoot)
        if not gl then return 0,120 end
        local pt,relTo,relPt,ox,oy=unpackAnchor(a)
        local relative=relTo or (c.GetParent and c:GetParent())
        local l,t,r,b=bounds(relative)
        if not l then l,t,r,b=gl,gt,gr,gb end
        local rx,ry=factors(relPt or pt); local px,py=factors(pt)
        local scale=relativeScale(relative)
        -- GetWidth/GetHeight in ESO already include inherited control scale.
        local cw=c.GetWidth and c:GetWidth() or 0
        local ch=c.GetHeight and c:GetHeight() or 0
        local x=l+(r-l)*rx+ox*scale+(.5-px)*cw-(gl+gr)/2
        local y=t+(b-t)*ry+oy*scale-py*ch+height/2-(gt+gb)/2
        if math.abs(x)>(gr-gl)/2 or math.abs(y)>(gb-gt)/2 then return 0,120 end
        return x,y
    end
    local function mover(spec)
        local m={}
        local function st(self)
            self.promptMovers=self.promptMovers or {}
            local t=self.promptMovers[spec.prefix]
            if not t then t={}; self.promptMovers[spec.prefix]=t end
            return t
        end
        function m.release(self,keepProxy)
            local t=st(self)
            local state=t.anchor
            if state and state.applied and equal(read(state.control),state.applied) then
                write(state.control,state.original)
            end
            t.anchor=nil
            if t.proxy and not keepProxy then t.proxy:SetHidden(true) end
        end
        local function proxy(self,c,anchor,status)
            local t=st(self)
            if not t.proxy then
                local w=WINDOW_MANAGER:CreateTopLevelWindow(spec.window)
                w:SetDrawTier(DT_HIGH); w:SetDrawLevel(30); w:SetHidden(true)
                local bg=UI.texture(w,UI.path.."editframe.dds",320,72,0,0,31)
                local label=UI.text(w,16,320,72,0,0,32)
                t.proxy,t.border,t.label=w,bg,label
                self:BindWidgetDrag(w,spec.prefix,function() m.sync(self) end)
            end
            local w=t.proxy
            local width,height=spec.size(c)
            if t.proxyControl~=c or t.proxyWidth~=width or t.proxyHeight~=height then
                w:SetDimensions(width,height)
                t.border:SetDimensions(width,height)
                t.label:SetDimensions(width,height)
                t.proxyControl=c
                t.proxyWidth=width
                t.proxyHeight=height
            end
            local x,y=baseCenter(c,anchor,t.proxyHeight)
            if spec.above then y=y-t.proxyHeight end
            local s=self.settings
            w:ClearAnchors(); w:SetAnchor(CENTER,GuiRoot,CENTER,x+self:UIUnits(s[spec.prefix.."X"] or 0),y+self:UIUnits(s[spec.prefix.."Y"] or 0))
            t.label:SetText(tr(status or spec.sample))
            w:SetHidden(false)
        end
        function m.sync(self)
            local s=self.settings
            local t=st(self)
            local c=spec.control()
            if not s.enabled or (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) or
                (self.IsNativeHudEditorOpen and self:IsNativeHudEditorOpen()) then
                t.yielded=false; t.ready=false
                m.release(self); return
            end
            local current=read(c)
            local managed=c and registered(c)
            if not current or managed then
                t.yielded=not not managed; t.ready=false
                m.release(self,self.editing)
                if self.editing then
                    proxy(self,c,read(c),managed and spec.managed or spec.notReady)
                end
                return
            end
            t.yielded=false; t.ready=true
            local state=t.anchor
            if state and state.control~=c then m.release(self); state=nil end
            local x,y=s[spec.prefix.."X"] or 0,s[spec.prefix.."Y"] or 0
            if state and state.applied and not equal(current,state.applied) and not equal(current,state.original) then
                t.conflict=c; state.applied=nil
            end
            if x==0 and y==0 then
                if state then m.release(self) end
                t.conflict=nil
            elseif t.conflict~=c then
                if not state then state={control=c,original=current}; t.anchor=state end
                local pt,relTo,relPt,ox,oy,constrains=unpackAnchor(state.original)
                local relative=relTo or (c.GetParent and c:GetParent())
                local scale=relativeScale(relative)
                local nx,ny=ox+self:UIUnits(x)/scale,oy+self:UIUnits(y)/scale
                local wanted=ZO_Anchor and ZO_Anchor:New(pt,relTo,relPt,nx,ny,constrains) or {pt,relTo,relPt,nx,ny,constrains}
                if not equal(current,wanted) then write(c,wanted) end
                state.applied=read(c)
            end
            if self.editing then
                local base=t.anchor and t.anchor.original or read(c)
                proxy(self,c,base,t.conflict==c and spec.conflict or nil)
            elseif t.proxy then t.proxy:SetHidden(true) end
        end
        return m
    end
    local playerToPlayer=mover({prefix="playerInteraction",window="ZeraUIPlayerInteractionEditor",
        control=function() return ZO_PlayerToPlayerAreaPromptContainer end,
        sample="Player Name   [F]",managed="[F] - Managed by native HUD editor",
        notReady="[F] - Native prompt not ready",conflict="[F] - Another addon changed the prompt",
        size=function(c)
            local height=72
            local target=c and c.GetNamedChild and c:GetNamedChild("Target")
            local action=c and c.GetNamedChild and c:GetNamedChild("ActionArea")
            if target and action and target.GetTop and action.GetBottom then
                local bottom,top=action:GetBottom(),target:GetTop()
                if type(bottom)=="number" and type(top)=="number" then
                    local h=bottom-top
                    if h>20 and h<300 then height=h end
                end
            end
            return 320,height
        end})
    local instanceKick=mover({prefix="instanceKick",window="ZeraUIInstanceKickEditor",
        control=function() return ZO_InstanceKickWarning_AliveContainer end,
        sample="Removing from area...   [Leave Now]",managed="[Leave Now] - Managed by native HUD editor",
        notReady="[Leave Now] - Native warning not ready",conflict="[Leave Now] - Another addon changed the warning",
        above=true,size=function() return 360,72 end})
    local reticleInteract=mover({prefix="reticleInteract",window="ZeraUIReticleInteractEditor",
        control=function() return ZO_ReticleContainerInteract end,
        sample="NPC / Object   [E]",managed="[E] - Managed by native HUD editor",
        notReady="[E] - Native interact prompt not ready",conflict="[E] - Another addon changed the interact prompt",
        size=function(c)
            local w=c and c.GetWidth and c:GetWidth() or 0
            local h=c and c.GetHeight and c:GetHeight() or 0
            return (type(w)=="number" and w>40 and w<500) and w or 220,(type(h)=="number" and h>20 and h<200) and h or 50
        end})
    local tutorialTip=mover({prefix="tutorialTip",window="ZeraUITutorialTipEditor",
        control=function() return ZO_TutorialHudInfoTipKeyboard end,
        sample="Tutorial / Info Tip",managed="Tutorial tip - Managed by native HUD editor",
        notReady="Tutorial tip - Native tip not ready",conflict="Tutorial tip - Another addon changed the tip",
        size=function(c)
            local w=c and c.GetWidth and c:GetWidth() or 0
            local h=c and c.GetHeight and c:GetHeight() or 0
            return (type(w)=="number" and w>80 and w<700) and w or 430,(type(h)=="number" and h>60 and h<600) and h or 240
        end})
    -- NPC dialogue / quest-accept panel (ZO_InteractWindow): shift Divider,
    -- TopBG's right anchor, and BottomBG's right anchor together so the dark
    -- conversation backdrop and vertical separator stay flush at any offset.
    local INTERACT_WIDTH_PERC,INTERACT_RIGHT_PERC=.4,.0534
    local interactState={hooked=false,applied=false,yielded=false,ready=false}
    local function applyInteractBottomBg(win,dx,dy)
        local bottomBg=win and win.GetNamedChild and win:GetNamedChild("BottomBG")
        if not bottomBg then return end
        local v1,p1,r1,rp1,x1,y1,c1=bottomBg:GetAnchor(1)
        if not v1 then return end
        bottomBg:ClearAnchors()
        bottomBg:SetAnchor(TOPRIGHT,GuiRoot,RIGHT,dx,dy)
        if c1~=nil then bottomBg:SetAnchor(p1,r1,rp1,x1,y1,c1) else bottomBg:SetAnchor(p1,r1,rp1,x1,y1) end
    end
    local function applyInteractAnchors(dx,dy)
        local win=_G.ZO_InteractWindow
        if not (win and win.GetNamedChild and GuiRoot and GuiRoot.GetDimensions) then return end
        local divider=win:GetNamedChild("Divider")
        if not divider then return end
        local uiW,uiH=GuiRoot:GetDimensions()
        if not (type(uiW)=="number" and uiW>0 and type(uiH)=="number" and uiH>0) then return end
        divider:ClearAnchors()
        divider:SetAnchor(RIGHT,GuiRoot,TOPRIGHT,-uiW*INTERACT_RIGHT_PERC+dx,uiH*.5+dy)
        local topBg=win:GetNamedChild("TopBG")
        if topBg then
            local v0,p0,r0,rp0,x0,y0,c0=topBg:GetAnchor(0)
            if v0 then
                topBg:ClearAnchors()
                if c0~=nil then topBg:SetAnchor(p0,r0,rp0,x0,y0,c0) else topBg:SetAnchor(p0,r0,rp0,x0,y0) end
                topBg:SetAnchor(BOTTOMRIGHT,GuiRoot,RIGHT,dx,dy)
            end
        end
        applyInteractBottomBg(win,dx,dy)
    end
    local function syncInteractWindow(self)
        local s=self.settings
        local win=_G.ZO_InteractWindow
        local divider=win and win.GetNamedChild and win:GetNamedChild("Divider")
        local managed=win and registered(win)
        interactState.yielded=not not managed
        interactState.ready=not not (divider and not managed)
        local disabled=not s.enabled or (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) or
            (self.IsNativeHudEditorOpen and self:IsNativeHudEditorOpen()) or not interactState.ready
        local x,y=s.interactWindowX or 0,s.interactWindowY or 0
        if disabled or (x==0 and y==0) then
            if interactState.applied then
                if not managed then applyInteractAnchors(0,0) end
                interactState.applied=false
            end
        else
            if not interactState.hooked and type(INTERACTION)=="table" and type(SecurePostHook)=="function" then
                interactState.hooked=true
                pcall(SecurePostHook,INTERACTION,"AnchorBottomBG",function()
                    if not interactState.applied then return end
                    local cur=A.settings
                    local cx,cy=cur.interactWindowX or 0,cur.interactWindowY or 0
                    if cur.enabled and (cx~=0 or cy~=0) and not (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) then
                        applyInteractBottomBg(_G.ZO_InteractWindow,A:UIUnits(cx),A:UIUnits(cy))
                    end
                end)
                pcall(SecurePostHook,INTERACTION,"OnScreenResized",function()
                    if interactState.applied then syncInteractWindow(A) end
                end)
            end
            applyInteractAnchors(self:UIUnits(x),self:UIUnits(y))
            interactState.applied=true
        end
        if self.editing then
            if not interactState.proxy then
                local w=WINDOW_MANAGER:CreateTopLevelWindow("ZeraUIInteractWindowEditor")
                w:SetDrawTier(DT_HIGH); w:SetDrawLevel(30); w:SetHidden(true)
                local bg=UI.texture(w,UI.path.."editframe.dds",420,300,0,0,31)
                local label=UI.text(w,16,420,300,0,0,32)
                interactState.proxy,interactState.border,interactState.label=w,bg,label
                self:BindWidgetDrag(w,"interactWindow",function() syncInteractWindow(self) end)
            end
            local uiW=GuiRoot and GuiRoot.GetDimensions and select(1,GuiRoot:GetDimensions()) or 1920
            local divW=divider and divider.GetWidth and divider:GetWidth() or 0
            local rawW=(type(divW)=="number" and divW>0) and divW or (uiW*INTERACT_WIDTH_PERC)
            local pw=math.max(280,math.floor(rawW+.5))
            local ph=300
            local w=interactState.proxy
            if interactState.pw~=pw then
                w:SetDimensions(pw,ph); interactState.border:SetDimensions(pw,ph); interactState.label:SetDimensions(pw,ph)
                interactState.pw=pw
            end
            local baseX=uiW*(.5-INTERACT_RIGHT_PERC)-pw*.5
            w:ClearAnchors()
            w:SetAnchor(CENTER,GuiRoot,CENTER,baseX+self:UIUnits(x),self:UIUnits(y))
            interactState.label:SetText(tr("NPC Dialogue / Quest Accept"))
            w:SetHidden(false)
        elseif interactState.proxy then
            interactState.proxy:SetHidden(true)
        end
    end
    local nativePrefixes={
        playerInteraction=true,
        instanceKick=true,
        reticleInteract=true,
        tutorialTip=true,
        interactWindow=true,
    }
    function A:PlayerInteractionDragAllowed(prefix)
        if not nativePrefixes[prefix] then return true end
        if prefix=="interactWindow" then
            return interactState.ready==true and not interactState.yielded
        end
        local t=self.promptMovers and self.promptMovers[prefix]
        return t~=nil and t.ready==true and not t.yielded
    end
    function A:SyncPlayerInteraction()
        playerToPlayer.sync(self)
        instanceKick.sync(self)
        reticleInteract.sync(self)
        tutorialTip.sync(self)
        syncInteractWindow(self)
    end
end
