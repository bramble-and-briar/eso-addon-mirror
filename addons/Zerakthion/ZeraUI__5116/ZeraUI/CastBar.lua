-- Zera UI: native event-driven cast bar / GCD / channel lifecycle and rendering.
function ZeraUIAttachCastBar(A,UI)
    local CAST_TRACK=UI.castTrack
    local setText,paint=UI.setText,UI.paint
    local EM=EVENT_MANAGER
    local CAST_END_NS="ZeraUICastEnd"
    local ABILITY_TYPE=ACTION_TYPE_ABILITY or 1
    local CRAFTED_TYPE=ACTION_TYPE_CRAFTED_ABILITY or 3

    -- Single reusable pending-cast buffer (zero per-queue table allocation).
    local pendingBuf={}
    local queuedGcdBuf={}
    local function clearQueuedGcd(self)
        queuedGcdBuf.slot=nil; queuedGcdBuf.category=nil; queuedGcdBuf.at=nil
        queuedGcdBuf.abilityId=nil; queuedGcdBuf.name=nil; queuedGcdBuf.icon=nil
        self.queuedGcd=nil
    end
    local function clearPending(self)
        pendingBuf.slot=nil; pendingBuf.category=nil; pendingBuf.at=nil
        pendingBuf.prevEnd=nil; pendingBuf.prevGcdEnd=nil; pendingBuf.prevMode=nil; pendingBuf.mode=nil
        pendingBuf.abilityId=nil; pendingBuf.base=nil
        pendingBuf.trackingSlot=nil; pendingBuf.abilityKey=nil; pendingBuf.exhausting=nil
        pendingBuf.name=nil; pendingBuf.icon=nil
        self.pendingCast=nil
        clearQueuedGcd(self)
    end

    -- Pre-allocated callback for dynamic active-channel termination (zero per-cast closure).
    -- EVENT_COMBAT_EVENT: 1:ev 2:result 3:isError 4:name 5:gfx 6:slotType 7:srcName 8:srcType
    -- 9:tgtName 10:tgtType 11:hitValue 12:powType 13:dmgType 14:log 15:srcId 16:tgtId 17:abilityId
    local function onCastEnd(_,result,isError,_,_,_,_,sourceType,_,targetType,_,_,_,_,sourceUnitId,targetUnitId,abilityId)
        A:OnCastEnd(abilityId,result,isError,sourceType,targetType,sourceUnitId,targetUnitId)
    end

    function A:UnwatchCastEnd()
        if self.castEndWatchedId then
            EM:UnregisterForEvent(CAST_END_NS,EVENT_COMBAT_EVENT)
            self.castEndWatchedId=nil
        end
    end

    -- Register ACTION_RESULT_EFFECT_FADED ONLY for self-targeted channels whose
    -- fade payload carries proven local-player ownership (targetType==PLAYER,
    -- e.g. Fatecarver 193397). Live two-player tests on Radiant Glory (63044)
    -- proved that target-dependent channels emit identical st=0/tt=0/si=0
    -- FADED payloads for both local and remote players, so ambiguous NONE/NONE
    -- fades are never subscribed or used as ClearCast triggers.
    function A:WatchCastEnd(abilityId)
        if not abilityId or abilityId<=0 or not EVENT_COMBAT_EVENT or not ACTION_RESULT_EFFECT_FADED or not REGISTER_FILTER_ABILITY_ID or not REGISTER_FILTER_COMBAT_RESULT or not REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE or not COMBAT_UNIT_TYPE_PLAYER then return end
        if self.castEndWatchedId==abilityId then return end
        self:UnwatchCastEnd()
        self.castEndWatchedId=abilityId
        EM:RegisterForEvent(CAST_END_NS,EVENT_COMBAT_EVENT,onCastEnd)
        EM:AddFilterForEvent(CAST_END_NS,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,abilityId)
        EM:AddFilterForEvent(CAST_END_NS,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,ACTION_RESULT_EFFECT_FADED)
        EM:AddFilterForEvent(CAST_END_NS,EVENT_COMBAT_EVENT,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    end

    local function validAbilityCooldown(rem,dur,global,globalSlotType,sameBar)
        if not (rem and dur and rem>0 and dur>0) then return false end
        if global then
            return not globalSlotType or globalSlotType==ABILITY_TYPE or globalSlotType==CRAFTED_TYPE
        end
        return sameBar and dur<=1500
    end

    -- A skill pressed while the previous cast/GCD still has time left enters
    -- ESO's ability queue: EVENT_ACTION_SLOT_ABILITY_USED fires immediately,
    -- while GetSlotCooldownInfo still reports the outgoing cooldown until the
    -- queued skill starts (EVENT_ACTION_UPDATE_COOLDOWNS). Compare against the
    -- upper bound of the outgoing cast end and its 1000 ms GCD end so neither
    -- <850 ms hardcasts nor the first 150 ms of a channel/hardcast get killed.
    local function isStaleQueuedCooldown(now,rem,dur,prevEnd,prevMode,prevGcdEnd)
        local bound=prevEnd or 0
        if prevGcdEnd and prevGcdEnd>bound then bound=prevGcdEnd end
        if bound<=0 then return false end
        local finish=now+rem
        if finish>bound+150 then return false end
        if prevMode~="gcd" and (dur or 0)>0 and rem>=dur-150 and now>=(prevGcdEnd or 0)-50 and finish>(prevGcdEnd or 0)+150 then return false end
        return true
    end

    local function pendingDeadline(p)
        local bound=math.max(p.at,p.prevEnd or p.at)
        if p.prevGcdEnd and p.prevGcdEnd>bound then bound=p.prevGcdEnd end
        return bound+350
    end

    local function writePending(self,slot,category,now,mode,abilityId,base,trackingSlot,abilityKey,exhausting,name,icon)
        local activeEnd=self.castEnd
        local activeGcd=self.castGcdEnd
        local activeMode=self.castMode
        if not (activeEnd and activeEnd>now) and self.lastGcdEnd and self.lastGcdEnd>now then
            activeEnd=self.lastGcdEnd
            activeGcd=self.lastGcdEnd
            activeMode="gcd"
        end
        clearQueuedGcd(self)
        pendingBuf.slot=slot
        pendingBuf.category=category
        pendingBuf.at=now
        pendingBuf.prevEnd=activeEnd
        pendingBuf.prevGcdEnd=activeGcd
        pendingBuf.prevMode=activeMode
        pendingBuf.mode=mode
        pendingBuf.abilityId=abilityId
        pendingBuf.base=base
        pendingBuf.trackingSlot=trackingSlot
        pendingBuf.abilityKey=abilityKey
        pendingBuf.exhausting=exhausting
        pendingBuf.name=name or ""
        pendingBuf.icon=icon
        self.pendingCast=pendingBuf
    end

    function A:QueuePreBeginGcd(slot,category,now,abilityId,name,icon)
        queuedGcdBuf.slot=slot
        queuedGcdBuf.category=category
        queuedGcdBuf.at=now
        queuedGcdBuf.abilityId=abilityId
        queuedGcdBuf.name=name or ""
        queuedGcdBuf.icon=icon
        self.queuedGcd=queuedGcdBuf
    end

    function A:PrunePendingCast(now)
        local p=self.pendingCast
        if p and now>pendingDeadline(p) then
            local qg=self.queuedGcd
            local qSlot,qCat,qAt,qId,qName,qIcon
            if qg then qSlot,qCat,qAt,qId,qName,qIcon=qg.slot,qg.category,qg.at,qg.abilityId,qg.name,qg.icon end
            clearPending(self)
            if qSlot and ((self.castEnd and self.castEnd>now) or (self.lastGcdEnd and self.lastGcdEnd>now) or now<=qAt+350) then
                writePending(self,qSlot,qCat,qAt,"gcd",qId,0,nil,nil,false,qName,qIcon)
                return self.pendingCast
            end
            return nil
        end
        return p
    end

    function A:QueuePendingCast(slot,category,now,mode,abilityId,base,trackingSlot,abilityKey,exhausting,name,icon)
        writePending(self,slot,category,now,mode,abilityId,base,trackingSlot,abilityKey,exhausting,name,icon)
        if mode=="gcd" then self:TryPromotePendingCast(now) end
    end

    function A:StartCastState(now,slot,category,mode,abilityId,duration,trackingSlot,abilityKey,exhausting,name,icon)
        self.lastCastSlot=slot
        self.lastCastCategory=category
        self.lastCastTime=now
        self.castMode=mode
        self.castAbilityId=abilityId
        self.castBeginSeen=false
        self.castTargetType=nil
        self.castWeaponLocked=mode=="hardcast" and (self.weaponPairLocked==true) or false
        self.lastGcdEnd=nil
        self.castConfigGen=nil
        self.castTimeStep=nil; self.castTimeAfter=nil
        if mode=="indefinite" then
            self.castToggleSlot=trackingSlot
            self.castGcdEnd=nil
        elseif duration and duration>0 then
            self.castDuration=duration
            self.castEnd=now+duration
            self.castGcdEnd=mode=="gcd" and self.castEnd or (now+1000)
        else
            self.castGcdEnd=nil
        end
        if exhausting and mode=="channel" then
            self.castExhaustingSlot=trackingSlot
            self.castExhaustingKey=abilityKey
            trackingSlot.exhaustingSuppressedKey=nil
        end
        self.castBlocked=IsBlockActive and IsBlockActive() or false
        self.castLabelName=name or ""
        self.castIconPath=icon
        setText(self.castName,self.castLabelName)
        if icon and icon~="" then self.castIcon:SetTexture(icon) end
    end

    function A:TryPromotePendingCast(now)
        local p=self:PrunePendingCast(now)
        if not p then return false end
        if p.mode~="gcd" then return false end
        local sameBar=self.active==p.category
        local cat=sameBar and p.category or self.active
        local rem,dur,global,globalSlotType=GetSlotCooldownInfo(p.slot,cat)
        if validAbilityCooldown(rem,dur,global,globalSlotType,sameBar) and not isStaleQueuedCooldown(now,rem,dur,p.prevEnd,p.prevMode,p.prevGcdEnd) then
            local slot,category,abilityId,name,icon=p.slot,p.category,p.abilityId,p.name,p.icon
            clearPending(self)
            self:ClearCast(true)
            self:StartCastState(now,slot,category,"gcd",abilityId,dur,nil,nil,false,name,icon)
            self.castEnd=now+rem
            self.castGcdEnd=self.castEnd
            self.castDuration=dur
            return true
        end
        return false
    end

    local function slotIsAbility(slot,category)
        if GetSlotType then
            local kind=GetSlotType(slot,category)
            return kind==ABILITY_TYPE or kind==CRAFTED_TYPE
        end
        return not GetSlotBoundId or (GetSlotBoundId(slot,category) or 0)>0
    end

    -- Read GCD/ability cooldown safely across bar swaps with zero per-call
    -- allocations. On the same bar, query the cast slot directly; after a bar
    -- swap, probe occupied ability slots on the active bar (cast slot first if
    -- 3..7, then remaining 3..7) so an empty slot returning (0, 0, false, 0)
    -- never drops or prematurely clears an active GCD.
    local function readGcdCooldown(slot,category,active)
        if active==category then
            local rem,dur,global,globalSlotType=GetSlotCooldownInfo(slot,category)
            return rem,dur,global,globalSlotType,true,true
        end
        if active==nil then return nil,nil,nil,nil,false,false end
        local sawZero=false
        if slot>=3 and slot<=7 and slotIsAbility(slot,active) then
            local rem,dur,global,globalSlotType=GetSlotCooldownInfo(slot,active)
            if validAbilityCooldown(rem,dur,global,globalSlotType,false) then
                return rem,dur,global,globalSlotType,false,true
            end
            if (not rem or rem<=0) and (not dur or dur<=0) then sawZero=true end
        end
        for i=3,7 do
            if i~=slot and slotIsAbility(i,active) then
                local rem,dur,global,globalSlotType=GetSlotCooldownInfo(i,active)
                if validAbilityCooldown(rem,dur,global,globalSlotType,false) then
                    return rem,dur,global,globalSlotType,false,true
                end
                if (not rem or rem<=0) and (not dur or dur<=0) then sawZero=true end
            end
        end
        return 0,0,false,0,false,sawZero
    end

    function A:SyncGcdCooldown(now)
        if not self.lastCastSlot or self.castMode~="gcd" then return end
        local rem,dur,global,globalSlotType,sameBar,confirmed=readGcdCooldown(self.lastCastSlot,self.lastCastCategory,self.active)
        if (not rem or rem<=0) and (not dur or dur<=0) then
            if confirmed and self.castEnd then self:ClearCast(true) end
            return
        end
        if validAbilityCooldown(rem,dur,global,globalSlotType,sameBar) then
            local finish=now+rem
            -- Once counting down, a later restart of the global cooldown with no
            -- new slot use (e.g. Ulfsild's rune set off by its own recast) is not
            -- this cast: never stretch the bar into a second one.
            if self.castEnd and (now-self.lastCastTime)>=150 and finish>self.castEnd+200 then return end
            if not self.castEnd or math.abs(finish-self.castEnd)>65 then self.castEnd=finish; self.castTimeStep=nil; self.castTimeAfter=nil end
            self.castGcdEnd=self.castEnd
            self.castDuration=dur
            self.castConfigGen=nil
        end
    end

    function A:OnCastCooldownsUpdated(now)
        if self.pendingCast and self:TryPromotePendingCast(now) then return end
        if self.castMode=="gcd" then self:SyncGcdCooldown(now) end
    end

    -- Native ACTION_RESULT_BEGIN (2200, sourceType==PLAYER, isError==false):
    -- provides authoritative server-computed duration (Crux extensions,
    -- Scribing, passives) for both channels and hardcasts, in and out of combat.
    -- Defense-in-depth sourceType==PLAYER guard rejects remote BEGIN (st=0).
    function A:OnCastBegin(abilityId,hitValue,sourceType,targetType)
        if not self.settings.enabled or self.preview or not abilityId or abilityId<=0 or sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end
        local now=GetFrameTimeMilliseconds()
        local dur=tonumber(hitValue) or 0
        local p=self.pendingCast
        if p and p.mode~="gcd" and p.abilityId==abilityId then
            local slot,category,mode,base,trackingSlot,abilityKey,exhausting,name,icon,queuedAt,prevGcdEnd=
                p.slot,p.category,p.mode,p.base,p.trackingSlot,p.abilityKey,p.exhausting,p.name,p.icon,p.at,p.prevGcdEnd
            local qg=self.queuedGcd
            local cSlot,cCat,cId,cName,cIcon
            if qg then
                cSlot,cCat,cId,cName,cIcon=qg.slot,qg.category,qg.abilityId,qg.name,qg.icon
            elseif self.castMode=="gcd" and self.lastCastSlot and self.lastCastTime and queuedAt and self.lastCastTime>=queuedAt then
                cSlot,cCat,cId,cName,cIcon=self.lastCastSlot,self.lastCastCategory,self.castAbilityId,self.castLabelName,self.castIconPath
            end
            clearPending(self)
            self:ClearCast(true)
            local span=dur>0 and dur or base
            -- Anchor queued cast start and GCD end to native server cooldown
            -- when GetSlotCooldownInfo already reflects this cast's fresh GCD,
            -- eliminating BEGIN arrival RTT drift on castEnd and castGcdEnd.
            local startAt,syncedGcdEnd=now,nil
            local sameBar=self.active==category
            local cdCat=sameBar and category or self.active
            if GetSlotCooldownInfo and slot and cdCat then
                local rem,cdDur,global,globalSlotType=GetSlotCooldownInfo(slot,cdCat)
                if validAbilityCooldown(rem,cdDur,global,globalSlotType,sameBar) and (not prevGcdEnd or now+rem>prevGcdEnd+150) then
                    syncedGcdEnd=now+rem
                    local elapsedGcd=cdDur-rem
                    if elapsedGcd>0 and elapsedGcd<500 then startAt=now-elapsedGcd end
                end
            end
            self:StartCastState(startAt,slot,category,mode,abilityId,span,trackingSlot,abilityKey,exhausting,name,icon)
            if syncedGcdEnd then self.castGcdEnd=syncedGcdEnd end
            self.castBeginSeen=true
            self.castTargetType=targetType
            if mode=="hardcast" then
                self.castWeaponLocked=self.weaponPairLocked==true or (GetActiveWeaponPairInfo and select(2,GetActiveWeaponPairInfo())==true) or false
            elseif mode=="channel" and targetType==COMBAT_UNIT_TYPE_PLAYER then
                self:WatchCastEnd(abilityId)
            end
            if cSlot and mode=="hardcast" and span<=1000 then
                self:QueuePendingCast(cSlot,cCat,now,"gcd",cId,0,nil,nil,false,cName,cIcon)
            end
            return
        end
        if (self.castMode=="channel" or self.castMode=="hardcast") and self.castAbilityId==abilityId then
            if dur>0 then
                -- Anchor to the cast's start timestamp so event arrival RTT never
                -- restarts the bar backward or stretches total duration.
                self.castDuration=dur
                self.castEnd=(self.lastCastTime or now)+dur
                self.castConfigGen=nil; self.castTimeStep=nil; self.castTimeAfter=nil
            end
            self.castBeginSeen=true
            self.castTargetType=targetType
            if self.castMode=="hardcast" then
                self.castWeaponLocked=self.weaponPairLocked==true or (GetActiveWeaponPairInfo and select(2,GetActiveWeaponPairInfo())==true) or false
            elseif self.castMode=="channel" and targetType==COMBAT_UNIT_TYPE_PLAYER then
                self:WatchCastEnd(abilityId)
            end
        end
    end

    -- Native ACTION_RESULT_EFFECT_FADED (2250) termination for self-targeted
    -- channels with proven local-player ownership (targetType==PLAYER).
    -- Ambiguous NONE/NONE fades (e.g. target-dependent beams) are never used
    -- to terminate the CastBar because remote players emit identical payloads.
    function A:OnCastEnd(abilityId,result,isError,sourceType,targetType)
        if isError or result~=ACTION_RESULT_EFFECT_FADED or not self.castBeginSeen or self.castAbilityId~=abilityId then return end
        if self.castMode~="channel" then return end
        if targetType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER then
            self:ClearCast(true)
        end
    end

    -- Native EVENT_WEAPON_PAIR_LOCK_CHANGED for hardcast completion and early
    -- or post-GCD cancellation. Never generalized to channels or GCD.
    function A:OnWeaponPairLockChanged(locked)
        local isLocked=locked==true
        self.weaponPairLocked=isLocked
        if self.castMode~="hardcast" then return end
        if isLocked then
            self.castWeaponLocked=true
        elseif self.castWeaponLocked then
            self.castWeaponLocked=false
            if self.castBeginSeen then self:ClearCast(true) end
        end
    end

    -- Minimal 100 ms housekeeping: zero GetSlotCooldownInfo or ReadNativeTimer
    -- polling for steady GCD, channels, or weapon-locked hardcasts.
    function A:SampleCast(now)
        local p=self:PrunePendingCast(now)
        if p and not self.cooldownEvents and p.mode=="gcd" and self:TryPromotePendingCast(now) then return end
        if not self.lastCastSlot or not self.lastCastTime then return end
        local mode=self.castMode
        local elapsed=now-self.lastCastTime
        if mode=="indefinite" then
            local active=self.tracker:ToggleActive(self.castToggleSlot,self.lastCastSlot,self.lastCastCategory)
            if active then
                if not self.castToggleSeen then self.castToggleSeen=true; self.castConfigGen=nil end
            elseif self.castToggleSeen or elapsed>350 then self:ClearCast(true) end
            return
        end
        if self.castEnd and now>=self.castEnd then self:ClearCast(true); return end
        if elapsed>15000 then self:ClearCast(true); return end
        if mode=="gcd" then
            if not self.castEnd and elapsed>200 then self:ClearCast(true) end
            return
        end
        if self.active~=self.lastCastCategory then self:ClearStalePending(self.active,self.lastCastCategory); self:ClearCast(true); return end
        -- Fallback block-cancel check ONLY when native termination does not
        -- provide local-player-owned coverage: unlocked hardcasts, or
        -- target-dependent channels (where NONE/NONE fades are ambiguous across
        -- both grouped raid members and ungrouped nearby players).
        local needsBlockFallback=(mode=="hardcast" and not self.castWeaponLocked)
            or (mode=="channel" and self.castTargetType~=COMBAT_UNIT_TYPE_PLAYER)
        if needsBlockFallback then
            local blocked=IsBlockActive and IsBlockActive() or false
            if blocked and not self.castBlocked and elapsed>100 then clearPending(self); self:ClearCast(true); return end
            self.castBlocked=blocked
        end
    end

    function A:CancelCastKeepGcd()
        clearPending(self)
        self:ClearCast(true)
    end

    function A:ClearStalePending(activeCategory,outgoingCategory)
        local p=self.pendingCast
        if not p then return end
        if (activeCategory~=nil and p.category~=activeCategory) or (outgoingCategory~=nil and p.category==outgoingCategory) then
            clearPending(self)
        end
    end

    function A:ClearCast(keepPending)
        local now=GetFrameTimeMilliseconds()
        if not keepPending then
            clearPending(self)
            self.lastGcdEnd=nil
        else
            if (self.castMode=="hardcast" or self.castMode=="channel") and self.castGcdEnd and self.castGcdEnd>now then
                self.lastGcdEnd=self.castGcdEnd
            end
            if self.pendingCast and self.castMode~="gcd" and self.pendingCast.prevEnd and self.pendingCast.prevEnd>now then
                self.pendingCast.prevEnd=now
            end
        end
        self:UnwatchCastEnd()
        if self.castExhaustingSlot and self.castExhaustingSlot.abilityKey==self.castExhaustingKey then
            self.castExhaustingSlot.exhaustingSuppressedKey=self.castExhaustingKey
        end
        self.castExhaustingSlot=nil; self.castExhaustingKey=nil
        self.lastCastSlot=nil; self.lastCastCategory=nil; self.lastCastTime=nil
        self.castEnd=nil; self.castGcdEnd=nil; self.castDuration=nil; self.castMode=nil
        self.castAbilityId=nil; self.castBeginSeen=nil; self.castTargetType=nil
        self.castWeaponLocked=nil
        self.castToggleSlot=nil; self.castToggleSeen=nil; self.castBlocked=nil
        self.castConfigGen=nil; self.castFillWidth=nil; self.castTimeStep=nil; self.castTimeAfter=nil
    end

    function A:RenderCast(now)
        if not self.castShown and not self.castEnd and self.castMode~="indefinite" then return end
        local castEnd=self.castEnd
        local mode=self.castMode
        if mode~="indefinite" and castEnd and now>=castEnd then
            self:ClearCast(true)
            if self.castShown then self.cast:SetHidden(true); self.castShown=false end
            return
        end
        local gen=self.hudVisualGen
        if self.castConfigGen~=gen then
            self.castConfigGen=gen
            local cfg=self.settings
            local indefinite=mode=="indefinite" and self.castToggleSeen
            local allow=cfg.showGCD and ((indefinite and cfg.castShowChannels)
                or (castEnd and self.castDuration and self.castDuration>0
                    and ((mode=="channel" and cfg.castShowChannels)
                        or (mode=="hardcast" and cfg.castShowHardcasts)
                        or (mode=="gcd" and cfg.castShowGCD)))) or false
            self.castAllowShow=allow
            self.castIsIndefinite=indefinite and true or false
            self.castIsChannel=mode=="channel"
            if allow then
                local tint=(mode=="channel" or indefinite) and cfg.channelColor or cfg.castColor
                if self.castTint~=tint then paint(self.castFill,tint); self.castTint=tint end
            end
        end
        local showCast=self.castAllowShow
        if self.castShown~=showCast then self.cast:SetHidden(not showCast); self.castShown=showCast end
        if not showCast then
            self.castFillWidth=nil; self.castTimeStep=nil; self.castTimeAfter=nil
            return
        end
        local indefinite=self.castIsIndefinite
        local fraction
        if indefinite then
            fraction=1
        else
            local f=(castEnd-now)/self.castDuration
            if f>1 then f=1 end
            fraction=self.castIsChannel and f or (1-f)
        end
        local hidden=fraction<=0
        if self.castFillHidden~=hidden then self.castFillHidden=hidden; self.castFill:SetHidden(hidden) end
        local width=CAST_TRACK*fraction
        if width<.1 then width=.1 end
        local prevW=self.castFillWidth
        if not prevW or (width-prevW)>=.25 or (prevW-width)>=.25 then
            self.castFill:SetWidth(width); self.castFillWidth=width
        end
        local step=self.castTimeStep
        local timeDue=not step or (indefinite and now>=self.castTimeAfter or not indefinite and now>self.castTimeAfter)
        if timeDue then
            local shownTime=indefinite and (now-self.lastCastTime) or (castEnd-now)
            if shownTime<0 then shownTime=0 end
            local nextStep=math.floor(shownTime/100+.5)
            self.castTimeAfter=indefinite and (self.lastCastTime+(nextStep+.5)*100) or (castEnd-(nextStep-.5)*100)
            if step~=nextStep then
                self.castTimeStep=nextStep
                local display=string.format("%.1f",shownTime/1000)
                setText(self.castTime,display)
                local slot=self.castExhaustingSlot
                if slot and slot.abilityKey==self.castExhaustingKey then
                    setText(slot.timer,display)
                    slot.timerTextMode="fine"; slot.timerWholeSec=nil
                end
            end
        end
    end
end
