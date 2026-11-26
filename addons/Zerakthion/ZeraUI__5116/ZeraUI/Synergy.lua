-- Zera UI: synergy prompt tracking, cooldown-confirmed dismissal, fade and flash transitions.
function ZeraUIAttachSynergy(A,UI)
    local EM=EVENT_MANAGER
    local ADDON=UI.addon
    local flash,clearFlash,setText,clamp=UI.flash,UI.clearFlash,UI.setText,UI.clamp

    local nativeVisible
    if type(SYNERGY)=="table" and not A.synergyHooked then
        A.synergyHooked=true
        local hook=type(SecurePostHook)=="function" and SecurePostHook or (type(ZO_PostHook)=="function" and ZO_PostHook or nil)
        if hook then
            -- ZO_PrioritizedVisibility calls SYNERGY:SetHidden(true) BEFORE updating
            -- highestPriorityVisibleObject, so capture the explicit `hidden` flag
            -- rather than reading stale SYNERGY:IsVisible() inside the callback.
            hook(SYNERGY,"SetHidden",function(_,hidden)
                nativeVisible=not hidden
                A:RefreshSynergy()
            end)
            -- Both native ZO_Synergy (synergy.lua:83) and BSC (Block.lua:706) call
            -- SHARED_INFORMATION_AREA:SetHidden(SYNERGY, false) on every approved
            -- synergy update — including direct Allowed A -> Allowed C transitions
            -- where SYNERGY stays visible so SYNERGY:SetHidden does not fire.
            -- SHARED_INFORMATION_AREA is a Lua table (unlike userdata SYNERGY.icon).
            if type(SHARED_INFORMATION_AREA)=="table" then
                hook(SHARED_INFORMATION_AREA,"SetHidden",function(_,object,hidden)
                    if object~=SYNERGY or hidden then return end
                    local vis=nativeVisible
                    if vis==nil then vis=SYNERGY.IsVisible and SYNERGY:IsVisible() or false end
                    if vis then A:RefreshSynergy() end
                end)
            end
        end
    end

    local function formatName(name)
        return (zo_strformat and zo_strformat("<<1>>",name)) or name
    end

    local function resolveSynergyId(name,formatted)
        if type(GetNumberOfAvailableSynergies)~="function" or type(GetSynergyInfoAtIndex)~="function" then return nil end
        local count=GetNumberOfAvailableSynergies() or 0
        for idx=1,count do
            local sName,_,_,_,sAbilityId,canBeUsed=GetSynergyInfoAtIndex(idx)
            if canBeUsed and sAbilityId and sAbilityId>0 and (sName==name or formatName(sName)==formatted) then
                return sAbilityId
            end
        end
        return nil
    end

    local function currentSynergy()
        local name,icon
        if type(GetCurrentSynergyInfo)=="function" then
            local available,n,i=GetCurrentSynergyInfo()
            if available then name,icon=n,i end
        elseif type(GetSynergyInfo)=="function" then name,icon=GetSynergyInfo() end
        if not (name and name~="" and icon and icon~="") then return nil end
        local formatted=formatName(name)
        -- Follow native ESO's USE_SYNERGY activation gate (SYNERGY:IsVisible() via
        -- SHARED_INFORMATION_AREA) and approved prompt name (SYNERGY.lastSynergyName),
        -- keeping ZeraUI aligned with Loot/Tutorial/Wheel suppression and synergy
        -- blockers (e.g. BSC's Advanced Synergy) with zero addon dependency.
        if SYNERGY then
            local vis=nativeVisible
            if vis==nil then vis=SYNERGY.IsVisible and SYNERGY:IsVisible() or false end
            if not vis then return nil end
            local approved=SYNERGY.lastSynergyName
            if not approved or approved=="" then return nil end
            if approved~=name and approved~=formatted then return nil,nil,nil,nil,true end
        end
        return name,icon,resolveSynergyId(name,formatted),formatted
    end

    -- Only a personal synergy cooldown gain confirms use; a visibility query
    -- or a disappearing prompt is not proof. Map numeric offer synergyAbilityIds
    -- (from GetSynergyInfoAtIndex) to personal cooldown effect IDs so all
    -- client locales work without hardcoded English names.
    local ORB_SYNERGY={85434,63512,48052,95926,95924}
    local FUNNEL_SYNERGY={39519,39521}
    local FEAST_SYNERGY={41965,41966}
    local SYNERGY_COOLDOWNS_BY_ID={
        [39301]=ORB_SYNERGY,[63507]=ORB_SYNERGY,[26832]=ORB_SYNERGY,[95922]=ORB_SYNERGY,
        [23196]={43769},[22269]={22270},[85572]={85576},[115548]={115567},
        [118604]={118610},[118618]={118610},[39377]={39424},[42194]={42196},[42198]={42196},
        [39500]=FUNNEL_SYNERGY,[41963]=FEAST_SYNERGY,
        [39429]={39451},[41994]={41997},[42016]={42019},[42020]={42019},
        [32974]={48040},[32910]={67717},[48076]={48085},[37729]={37733},[88884]={88892},
    }

    local cooldownByName
    local function cooldownIdsFor(abilityId,name,formatted)
        if abilityId and SYNERGY_COOLDOWNS_BY_ID[abilityId] then return SYNERGY_COOLDOWNS_BY_ID[abilityId] end
        if not cooldownByName and type(GetAbilityName)=="function" then
            cooldownByName={}
            for offerId,ids in pairs(SYNERGY_COOLDOWNS_BY_ID) do
                local raw=GetAbilityName(offerId)
                if raw and raw~="" then
                    cooldownByName[raw]=ids
                    local clean=formatName(raw)
                    if clean and clean~="" then cooldownByName[clean]=ids end
                end
            end
        end
        if cooldownByName then return cooldownByName[formatted] or cooldownByName[name] end
        return nil
    end

    -- Single reusable offer & watch-set buffers + pre-allocated combat callback
    -- (zero per-prompt table or closure allocation).
    local offerBuf={}
    local watchSet={}
    local function onSynergyCombat(_,result,isError,_,_,_,_,_,_,targetType,_,_,_,_,_,_,abilityId)
        if isError or targetType~=COMBAT_UNIT_TYPE_PLAYER or (result~=ACTION_RESULT_EFFECT_GAINED and result~=ACTION_RESULT_EFFECT_GAINED_DURATION) then return end
        local sy=A.synergy
        if not watchSet[abilityId] or not sy.offer or sy.offer.used or not A.settings.enabled or not A.settings.showSynergy or not (A.settings.synergyInstantHide or A.settings.animations and A.settings.synergyPressFlash) or A.preview or not A.updating then return end
        if sy.offer.gone and GetFrameTimeMilliseconds()-sy.offer.gone>800 then return end
        local name,icon=currentSynergy()
        if name and (name~=sy.offer.name or icon~=sy.offer.icon) then return end
        sy.offer.used=true
        if A.settings.synergyInstantHide then A:HideSynergyImmediate() else A:FlashSynergy() end
    end

    function A:WatchSynergy(ids)
        local sy=self.synergy
        if sy.watch==ids then return end
        if sy.watch then
            for _,id in ipairs(sy.watch) do
                EM:UnregisterForEvent(ADDON.."Synergy_"..id,EVENT_COMBAT_EVENT)
                watchSet[id]=nil
            end
        end
        sy.watch=nil
        if not ids or not EVENT_COMBAT_EVENT or not REGISTER_FILTER_ABILITY_ID or not REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE or not COMBAT_UNIT_TYPE_PLAYER then return end
        sy.watch=ids
        for _,id in ipairs(ids) do
            watchSet[id]=true
            local ns=ADDON.."Synergy_"..id
            EM:RegisterForEvent(ns,EVENT_COMBAT_EVENT,onSynergyCombat)
            EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,id)
            EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
        end
    end

    function A:HideSynergyImmediate()
        local sy=self.synergy
        if self.animated[sy] then clearFlash(sy) end
        sy.hold=nil; sy.transition=nil; self.lastSynergy=nil
        if not sy.container:IsHidden() then sy.container:SetHidden(true) end
        if sy.container:GetAlpha()~=0 then sy.container:SetAlpha(0) end
    end

    function A:FlashSynergy()
        local sy=self.synergy
        if not self.settings.showSynergy or not self.settings.animations or not self.settings.synergyPressFlash then return end
        sy.container:SetHidden(false); sy.container:SetAlpha(self.settings.synergyOpacity)
        sy.transition=nil; sy.visual:SetScale(1); sy.visualScale=1
        flash(sy)
        sy.hold=true
    end

    -- Purely event-driven via EVENT_SYNERGY_ABILITY_CHANGED, EVENT_PLAYER_ACTIVATED,
    -- and SYNERGY:SetHidden / SHARED_INFORMATION_AREA:SetHidden post-hooks. Tick only
    -- invokes RefreshSynergy once the 800 ms post-vanish cooldown confirmation window ends.
    function A:SynergyDue(now)
        local offer=self.synergy.offer
        return offer~=nil and offer.gone~=nil and (now-offer.gone)>800
    end

    function A:RefreshSynergy()
        if self.preview or not self.synergy or not self.settings then return end
        local sy=self.synergy
        if not self.settings.showSynergy then
            clearFlash(sy); sy.offer=nil; self:WatchSynergy(nil); sy.hold=nil
            if not sy.container:IsHidden() then sy.container:SetHidden(true) end
            if sy.container:GetAlpha()~=0 then sy.container:SetAlpha(0) end
            sy.transition=nil; self.lastSynergy=nil; return
        end
        local name,icon,abilityId,formatted,pendingApproval=currentSynergy()
        if pendingApproval and self.lastSynergy then return end
        if self.settings.enabled and self.updating and (self.settings.synergyInstantHide or self.settings.animations and self.settings.synergyPressFlash) then
            if name then
                if not sy.offer or sy.offer.name~=name or sy.offer.icon~=icon or sy.offer.gone then
                    offerBuf.name=name; offerBuf.icon=icon; offerBuf.gone=nil; offerBuf.used=nil
                    sy.offer=offerBuf
                    self:WatchSynergy(cooldownIdsFor(abilityId,name,formatted))
                end
            elseif sy.offer then
                local now=GetFrameTimeMilliseconds()
                sy.offer.gone=sy.offer.gone or now
                if now-sy.offer.gone>800 then sy.offer=nil; self:WatchSynergy(nil) end
            end
        else sy.offer=nil; self:WatchSynergy(nil) end
        if name then
            if self.settings.synergyInstantHide and sy.offer and sy.offer.used then self:HideSynergyImmediate(); return end
            if self.lastSynergy~=name or sy.iconPath~=icon then
                setText(sy.name,name)
                sy.icon:SetTexture(icon); sy.iconPath=icon
                if not self.animated[sy] then self:FadeSynergy(true,true) end
            end
            self.lastSynergy=name
            sy.hold=nil
        else
            if self.settings.synergyInstantHide then self:HideSynergyImmediate(); return end
            if self.animated[sy] then sy.hold=true; self.lastSynergy=nil; return end
            if self.lastSynergy or sy.hold then sy.hold=nil; self:FadeSynergy(false)
            elseif not sy.transition or sy.transition.finish>0 or (GetFrameTimeMilliseconds()-sy.transition.at)>=math.max(1,sy.transition.duration or 0) then
                sy.transition=nil
                if not sy.container:IsHidden() then sy.container:SetHidden(true) end
                if sy.container:GetAlpha()~=0 then sy.container:SetAlpha(0) end
            end
            self.lastSynergy=nil
        end
    end

    function A:FadeSynergy(visible,changed)
        local sy=self.synergy
        if visible and not self.settings.showSynergy then return end
        local target=visible and self.settings.synergyOpacity or 0
        local start=sy.container:GetAlpha()
        if visible and sy.container:IsHidden() then start=0 end
        if visible and changed and start>=target then start=target*.25 end
        if not self.settings.animations or not self.settings.synergyAnimations then
            sy.container:SetAlpha(target); sy.visual:SetScale(1); sy.container:SetHidden(not visible); sy.transition=nil; return
        end
        if visible then sy.container:SetHidden(false) end
        sy.container:SetAlpha(start)
        local initialScale=visible and (changed and .88 or sy.visualScale or 1) or (sy.visualScale or 1)
        sy.visualScale=initialScale; sy.visual:SetScale(initialScale)
        sy.transition={start=start,finish=target,scaleStart=initialScale,scaleEnd=visible and 1 or .92,at=GetFrameTimeMilliseconds(),
            duration=visible and self.settings.synergyFadeIn or self.settings.synergyFadeOut}
    end

    function A:RenderSynergy(now)
        local sy=self.synergy
        if sy.hold and not self.animated[sy] then
            sy.hold=nil
            if not self.lastSynergy and not self.preview then self:FadeSynergy(false) end
        end
        local t=sy.transition
        if not t then return end
        local p=clamp((now-t.at)/math.max(1,t.duration))
        local eased=p*p*(3-2*p)
        sy.container:SetAlpha(t.start+(t.finish-t.start)*eased)
        sy.visualScale=t.scaleStart+(t.scaleEnd-t.scaleStart)*eased
        sy.visual:SetScale(sy.visualScale)
        if p>=1 then
            sy.transition=nil
            if t.finish<=0 then sy.container:SetHidden(true) end
        end
    end
end
