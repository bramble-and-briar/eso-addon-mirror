-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: CMProgressbar.lua. See third-party/UPSTREAM.md for modifications.

local Util = WeavePulse.Util
Util.Ability = Util.Ability or {}
Util.Ability.Tracker = Util.Ability.Tracker or {}
local Tracker = Util.Ability.Tracker
Util.Text = Util.Text or {}
WeavePulse.SV = WeavePulse.SV or {}

local function AnchorSpellIcon(dynamic)
    if dynamic and not WeavePulse.Progressbar.spellIconAnchoredDynamically then
        WeavePulse.Progressbar.spellIcon:ClearAnchors()
        WeavePulse.Progressbar.spellIcon:SetAnchor(RIGHT, WeavePulse.Progressbar.bar.segments[2].bars[1], RIGHT, -(WeavePulse.SV.Progressbar.height/10), 0)
        WeavePulse.Progressbar.spellIconAnchoredDynamically = true
    elseif WeavePulse.Progressbar.spellIconAnchoredDynamically and not dynamic then
        WeavePulse.Progressbar.spellIcon:ClearAnchors()
        WeavePulse.Progressbar.spellIcon:SetAnchor(RIGHT, WeavePulse.Progressbar.frame, LEFT, -(WeavePulse.SV.Progressbar.height/10), 0)
        WeavePulse.Progressbar.spellIconAnchoredDynamically = false
    end
end

local function CreateDisplayName(name)
    local displayName
    WeavePulse.Progressbar.spellLabel:SetText(name)
    local barSpace = WeavePulse.SV.Progressbar.width - (WeavePulse.SV.Progressbar.showTimeRemaining and 2.5*WeavePulse.Progressbar.timeLabel:GetWidth() or 0)
    if WeavePulse.Progressbar.spellLabel:GetWidth() > barSpace then
        for i = #name, 1, -1 do
            local shortName =  string.sub(name, 1, i):gsub("%s+$", "") .. ".."
            WeavePulse.Progressbar.spellLabel:SetText(shortName)
            if WeavePulse.Progressbar.spellLabel:GetWidth() <= barSpace then
                displayName = shortName
                break
            end
        end
    else
        displayName = name
    end

    return displayName
end

function WeavePulse:Update()

    local latency, cdTimer
    local sv = WeavePulse.SV.Progressbar
    local progressbar = WeavePulse.Progressbar

    if progressbar.showSample then
        progressbar.bar.segments[2].progress = 0.7
        progressbar.bar.backgroundTexture:SetWidth(0.7*sv.width)
        if sv.dontShowPing then
            progressbar.bar.segments[1].progress = 0
        else
            progressbar.bar.segments[1].progress = 0.071
        end
        if sv.showSpell then
            progressbar.spellLabel:SetText("Generic sample text")
            progressbar.spellIcon:SetTexture("/esoui/art/icons/ability_dualwield_002_b.dds")
        end
        if sv.showTimeRemaining then
            progressbar.timeLabel:SetText("7.8s")
        end
        if sv.changeOnChanneled then
            progressbar.bar.segments[2].color = sv.channelColor
        else
            progressbar.bar.segments[2].color = sv.progressColor
        end
        progressbar.bar:Update()
        progressbar.UI.HiddenStates()
    else

        if not (self.currentEvent and self.currentEvent.ability and ((not self.currentEvent.ability.instant and self.currentEvent.ability.delay <= 1000) or self.currentEvent.ability.delay > 1000)) and progressbar.bar.segments[2].color ~= sv.progressColor then
            progressbar.bar.segments[2].color = sv.progressColor
        elseif not self.currentEvent and progressbar.bar.segments[2].color ~= sv.progressColor then
            progressbar.bar.segments[2].color = sv.progressColor
        end

        if sv.dontShowPing then
            latency = 0
        else
            latency = math.min(GetLatency(), sv.maxLatency)
        end

        local time = GetFrameTimeMilliseconds()

        local gcdProgress, slotRemaining, slotDuration = Tracker:GCDCheck()

        if not self.currentEvent and not progressbar.soundTickPlayed then

            if sv.forceSoundTock and (self.inCombat or (sv.showOOC and sv.playSoundsOOC)) and
            (

            (not sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and slotRemaining >= slotDuration - sv.soundTickOffset) or

            (sv.forceTickMSBeforeEnd and slotRemaining >= sv.forceTickTime - sv.soundTickOffset) or

            (sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and slotRemaining >= 500 - sv.soundTickOffset)
            ) then
                self:PrintDebug("tickTock", "forced 'tick'")
                for i = 1, math.min(sv.tickVolume, 30) do
                    PlaySound(sv.soundTickEffect)
                end
            end

            progressbar.soundTickPlayed = true
        end

        if not progressbar.soundTockPlayed and not self.currentEvent and time >= self.abilityFinished + sv.soundTockOffset and (self.inCombat or (sv.showOOC and sv.playSoundsOOC))
           and ((slotRemaining == 0) or (sv.soundTockOffset < 0 and slotRemaining >= -sv.soundTockOffset)) then

            progressbar.soundTockPlayed = true

            self:PrintDebug("tickTock", "normal 'tock'")
            for i = 1, math.min(sv.tickVolume, 30) do
                PlaySound(sv.soundTockEffect)
            end
        end

        if sv.trackGCD and not self.currentEvent then

            if progressbar.spellIconAnchoredDynamically then
                AnchorSpellIcon(false)
            end

            progressbar.bar.background:SetWidth(sv.width)
            progressbar.bar.borderL:SetWidth(sv.width/2)
            progressbar.bar.borderR:SetWidth(sv.width/2)

            progressbar.bar.segments[1].progress = (sv.showPingOnGCD and latency/1000) or 0
            progressbar.bar.segments[2].progress = gcdProgress

            if self.gcdEvent.finished <= time then
                self.gcdEvent = {finished = 0}
                if Tracker.rollDodgeFinished >= time and sv.trackRolldodge then
                    self.gcdEvent.displayName = CreateDisplayName(Util.Text.CropZOSString(GetAbilityName(28549), "ability"))
                    self.gcdEvent.icon = "/esoui/art/icons/ability_rogue_035.dds"
                    self.gcdEvent.clearSynergy = false
                    self.gcdEvent.finished = time + slotRemaining
                elseif progressbar.activeMount.action ~= "" and sv.trackMounting then
                    if sv.showMountNick then
                        self.gcdEvent.displayName = CreateDisplayName(string.format("%s (%s)",progressbar.activeMount.action,progressbar.activeMount.name))
                    else
                        self.gcdEvent.displayName = CreateDisplayName(progressbar.activeMount.action)
                    end
                    self.gcdEvent.icon = progressbar.activeMount.icon
                    self.gcdEvent.clearSynergy = false
                    self.gcdEvent.finished = time + slotRemaining
                elseif progressbar.collectibleInUse and sv.trackCollectibles then
                    self.gcdEvent.displayName = CreateDisplayName(progressbar.collectibleInUse.name)
                    self.gcdEvent.icon = progressbar.collectibleInUse.icon
                    self.gcdEvent.clearSynergy = false
                    self.gcdEvent.finished = time + slotRemaining
                elseif progressbar.synergy and sv.trackSynergies and progressbar.synergy.wasUsed then
                    self.gcdEvent.displayName = CreateDisplayName(progressbar.synergy.name)
                    self.gcdEvent.icon = progressbar.synergy.icon
                    self.gcdEvent.clearSynergy = true
                    self.gcdEvent.finished = time + slotRemaining
                elseif progressbar.itemUsed and sv.trackItems then
                    self.gcdEvent.displayName = CreateDisplayName(progressbar.itemUsed.name)
                    self.gcdEvent.icon = progressbar.itemUsed.icon
                    self.gcdEvent.clearSynergy = false
                    self.gcdEvent.finished = time + slotRemaining
                elseif progressbar.breakingFree and sv.trackBreakingFree then
                    self.gcdEvent.displayName = CreateDisplayName(progressbar.breakingFree.name)
                    self.gcdEvent.icon = progressbar.breakingFree.icon
                    self.gcdEvent.clearSynergy = false
                    self.gcdEvent.finished = time + slotRemaining
                elseif progressbar.festivalGCD then
                    self.gcdEvent.displayName = CreateDisplayName(self.FESTIVAL_IDS[progressbar.festivalGCD].name)
                    self.gcdEvent.icon = self.FESTIVAL_IDS[progressbar.festivalGCD].icon
                    self.gcdEvent.clearSynergy = false
                    self.gcdEvent.finished = time + slotRemaining
                end
                self:SetIconsAndNamesNil()
            end

            if self.gcdEvent.displayName then self:GCDSpecifics(self.gcdEvent.displayName, self.gcdEvent.icon, gcdProgress, self.gcdEvent.clearSynergy) end

            if slotRemaining <= 0 then
                self:OnCDStop("Reset non ability stuff")
                self.gcdEvent = {finished = 0}
            else
                self:HideBar(false)
                progressbar.bar.backgroundTexture:SetWidth(gcdProgress*sv.width)
            end
            progressbar.bar:Update()
        elseif self.currentEvent then

            if slotRemaining <= 0 and self.currentEvent.ability.delay <= 1000 and not self.currentEvent.ability.channeled and not self.currentEvent.ability.heavy then
                self:OnCDStop("GCD over")
                return
            end
            local ability = self.currentEvent.ability

            if not ability.name or ability.name == "" then
                self:OnCDStop("No ability name")
                return
            end

            local start = self.currentEvent.start
            if time - start < 0 then
                cdTimer = 0
            else
                cdTimer = time - start
            end

            local duration = (ability.heavy and ability.delay or math.max(self.gcd or 1000, ability.delay)) + (self.currentEvent.adjust or 0)

            local timeRemaining = (duration - cdTimer) / 1000
            local castProgress = timeRemaining/(duration/1000)

            if timeRemaining < 0 then
                self:OnCDStop("Time remaining < 0")
                return
            end

            local dynamicProgress = sv.expandDynamically and sv.dynamicExpansionMultiplyer*duration/10000 > 1 and duration <= 6000

            if ability.heavy then

                if not sv.displayPingOnHeavy then

                    latency = 0
                end
            end

            if time > self.currentEvent.ending and slotRemaining == 0 then
                self:OnCDStop("Event seems to be over")
                return
            else

                if not progressbar.soundTickPlayed then
                    if (

                        (not sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and time >= start + sv.soundTickOffset) or

                        (sv.forceTickMSBeforeEnd and timeRemaining*1000 <= sv.forceTickTime) or

                        (sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and time >= start + duration/2 + sv.soundTickOffset)
                    ) then

                        progressbar.soundTickPlayed = true

                        if self.inCombat or (sv.showOOC and sv.playSoundsOOC) then
                            self:PrintDebug("tickTock", string.format("normal 'tick' for '%s'", ability.name))
                            for i = 1, math.min(sv.tickVolume, 30) do
                                PlaySound(sv.soundTickEffect)
                            end
                        end
                    end
                end
                if not progressbar.soundTockPlayed then
                    local isSameEvent = sv.soundTockOffset < 0
                    local tockTimer = isSameEvent and (self.currentEvent.ending + sv.soundTockOffset) or (sv.forceSoundTock and (self.lastAbilityFinished + sv.soundTockOffset) or 0)

                    if (sv.forceSoundTock and tockTimer >= start and time >= tockTimer) or (not sv.forceSoundTock and isSameEvent and time >= tockTimer) then
                        if (self.inCombat or (sv.showOOC and sv.playSoundsOOC)) then
                            for i = 1, math.min(sv.tickVolume, 30) do
                                PlaySound(sv.soundTockEffect)
                            end
                        end

                        if isSameEvent then
                            self:PrintDebug("tickTock", string.format("normal 'tock' for '%s'", ability.name))
                            progressbar.soundTockPlayed = true
                        elseif sv.forceSoundTock then
                            self:PrintDebug("tickTock", "force 'tock' during next ability")
                            self.lastAbilityFinished = self.abilityFinished
                        end
                    end
                end

                if sv.changeOnChanneled then
                    if (not ability.instant and ability.delay <= 1000) or ability.delay > 1000 then
                        local castIsFinished = ((ability.delay <= 1000) and (timeRemaining*1000 <= 1000 - ability.delay)) or (timeRemaining <= 0)
                        if not castIsFinished and progressbar.bar.segments[2].color == sv.progressColor then
                            progressbar.bar.segments[2].color = sv.channelColor
                        elseif not ability.heavy and castIsFinished  and progressbar.bar.segments[2].color == sv.channelColor then
                            progressbar.bar.segments[2].color = sv.progressColor
                        end
                    else
                        if progressbar.bar.segments[2].color == sv.channelColor then
                            progressbar.bar.segments[2].color = sv.progressColor
                        end
                    end
                end
                if cdTimer >= (duration+latency) then
                    self:OnCDStop("cdTimer seems to be over")
                else
                    self:HideBar(false)
                end

                if dynamicProgress then
                    local multiplyer = sv.dynamicExpansionMultiplyer*duration/10000
                    local isDynamic = castProgress*multiplyer > 1
                    local dynamicBarWidth = isDynamic and sv.width*castProgress*multiplyer or sv.width
                    progressbar.bar.segments[2].progress = isDynamic and 1 or castProgress*multiplyer
                    progressbar.bar.segments[1].progress = isDynamic and multiplyer*latency / (1000*timeRemaining) or sv.dynamicExpansionMultiplyer*latency/duration
                    progressbar.bar.background:SetWidth(dynamicBarWidth)
                    progressbar.bar.backgroundTexture:SetWidth(sv.width*castProgress*multiplyer)
                    progressbar.bar.borderL:SetWidth(dynamicBarWidth/2)
                    progressbar.bar.borderR:SetWidth(dynamicBarWidth/2)
                    local dynamicAnchor = sv.barAlign == "Center" and sv.moveIconDynamically and isDynamic
                    AnchorSpellIcon(dynamicAnchor)
                else
                    progressbar.bar.background:SetWidth(sv.width)
                    progressbar.bar.segments[2].progress = castProgress
                    progressbar.bar.segments[1].progress = latency / duration
                    progressbar.bar.backgroundTexture:SetWidth(castProgress*sv.width)
                    progressbar.bar.borderL:SetWidth(sv.width/2)
                    progressbar.bar.borderR:SetWidth(sv.width/2)
                    AnchorSpellIcon(false)
                end
                progressbar.bar:Update()
            end

            if sv.showTimeRemaining and ((ability.delay > 0 and timeRemaining >= 0) or sv.alwaysShowTimeRemaining) and (not ability.heavy or ability.heavy and sv.showHeavyDetails) then
                progressbar.timeLabel:SetText(string.format("%.1fs", timeRemaining))
                progressbar.timeLabel:SetHidden(false)
            else
                progressbar.timeLabel:SetHidden(true)
            end

            if sv.showSpell and ((ability.delay > 0 and timeRemaining >= 0) or sv.alwaysShowSpell) and (not ability.heavy or ability.heavy and sv.showHeavyDetails) then
                if not ability.displayName then
                    ability.displayName = CreateDisplayName(ability.name)
                end
                progressbar.spellLabel:SetText(ability.displayName)
                progressbar.spellLabel:SetHidden(false)

                progressbar.spellIcon:SetTexture(ability.icon)
                progressbar.spellIcon:SetHidden(false)
                progressbar.spellIconBorder:SetHidden(false)
            else
                progressbar.spellLabel:SetHidden(true)
                progressbar.spellIcon:SetHidden(true)
                progressbar.spellIconBorder:SetHidden(true)
            end
        else
            self:OnCDStop("End of update cycle")
            progressbar.bar:Update()
        end
    end
end
