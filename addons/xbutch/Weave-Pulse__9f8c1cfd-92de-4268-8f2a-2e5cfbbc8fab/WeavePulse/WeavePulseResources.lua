-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: CMResources.lua. See third-party/UPSTREAM.md for modifications.

local LAM = WeavePulse.Settings
local Util = WeavePulse.Util
WeavePulse.SV = WeavePulse.SV or {}

local coralThreshold, mkThreshold, bahseiThreshold = 50, 50, 50

function WeavePulse:UpdateLabels()

   if self.Resources.showSample then
        if WeavePulse.SV.Resources.showUltimate then
            self.Resources.ultLabel:SetText("171")
            self.Resources.ultLabel:SetHidden(false)
        else
            self.Resources.ultLabel:SetHidden(true)
        end
        if WeavePulse.SV.Resources.showStamina then
            self.Resources.stamLabel:SetText("62%")
            self.Resources.stamLabel:SetHidden(false)
        else
            self.Resources.stamLabel:SetHidden(true)
        end
        if WeavePulse.SV.Resources.showMagicka then
            self.Resources.magLabel:SetText("75%")
            self.Resources.magLabel:SetHidden(false)
        else
            self.Resources.magLabel:SetHidden(true)
        end
        if WeavePulse.SV.Resources.showHealth then
            self.Resources.hpLabel:SetText("51%")
            self.Resources.hpLabel:SetHidden(false)
        else
            self.Resources.hpLabel:SetHidden(true)
        end
        if not WeavePulse.SV.Resources.unlockExecuteReminder then
            self.Resources.executeLabel:SetHidden(false)
        else
            self.Resources.executeLabel:SetHidden(true)
        end

    else
        local time = GetFrameTimeMilliseconds()

        local showResources = Util.Targeting.isUnitValidCombatTarget("reticleover", WeavePulse.SV.Resources.showResourcesForGuard)
                              or IsUnitInCombat("player")
                              or self.force
                              or WeavePulse.SV.Resources.showResources

        if showResources and WeavePulse.SV.Resources.showUltimate then
            local ult = GetUnitPower("player", POWERTYPE_ULTIMATE)
            self.Resources.ultLabel:SetText(ult)
            self.Resources.ultLabel:SetHidden(false)
        else
            self.Resources.ultLabel:SetHidden(true)
        end

        local coral = WeavePulse.SV.Resources.coralBahsei and WeavePulse.Resources.coralActive
        local mk = WeavePulse.SV.Resources.coralBahsei and WeavePulse.Resources.mkActive
        local bahsei = WeavePulse.SV.Resources.coralBahsei and WeavePulse.Resources.bahseiActive

        if showResources and (WeavePulse.SV.Resources.showStamina or coral or mk) then
            local stam, _, maxStam = GetUnitPower("player", POWERTYPE_STAMINA)
            local percentage = 100 * stam / math.max(1, maxStam)
            local threshold = math.max((WeavePulse.SV.Resources.highlightStam and WeavePulse.SV.Resources.stamHighlightThreshold) or 0, (coral and coralThreshold) or 0, (mk and mkThreshold) or 0)

            if threshold ~= 0 and percentage < threshold then

                local PERIOD = 1000

                local mix = (1 + math.sin(time * math.pi * 2 / PERIOD)) / 2
                local color = Util.Vectors.mix(WeavePulse.SV.Resources.stamColor, WeavePulse.SV.Resources.stamHighligtColor, mix)

                self.Resources.stamLabel:SetColor(unpack(color))
            else
                self.Resources.stamLabel:SetColor(unpack(WeavePulse.SV.Resources.stamColor))

            end

            self.Resources.stamLabel:SetText(stam == maxStam and "100%" or string.format("%i%%", percentage))
            self.Resources.stamLabel:SetHidden(false)
        else
            self.Resources.stamLabel:SetHidden(true)
        end

        if showResources and (WeavePulse.SV.Resources.showMagicka or bahsei) then
            local mag, _, maxMag = GetUnitPower("player", POWERTYPE_MAGICKA)
            local percentage = 100 * mag / math.max(1, maxMag)
            local threshold = math.max((WeavePulse.SV.Resources.highlightMag and WeavePulse.SV.Resources.magHighlightThreshold) or 0, (bahsei and bahseiThreshold) or 0)

            if threshold ~= 0 and percentage < threshold then

                local PERIOD = 1000

                local mix = (1 + math.sin(time * math.pi * 2 / PERIOD)) / 2
                local color = Util.Vectors.mix(WeavePulse.SV.Resources.magColor, WeavePulse.SV.Resources.magHighligtColor, mix)

                self.Resources.magLabel:SetColor(unpack(color))
            else
                self.Resources.magLabel:SetColor(unpack(WeavePulse.SV.Resources.magColor))

            end

            self.Resources.magLabel:SetText(mag == maxMag and "100%" or string.format("%i%%", percentage))
            self.Resources.magLabel:SetHidden(false)
        else
            self.Resources.magLabel:SetHidden(true)
        end

        local hp, _, maxHp = GetUnitPower("reticleover", POWERTYPE_HEALTH)
        if showResources and WeavePulse.SV.Resources.showHealth and hp > 0 and maxHp > 0 then
            local showAbsolute = not self.inCombat or hp == maxHp

            if 100 * (hp / maxHp) < WeavePulse.SV.Resources.hpHighlightThreshold then

                self.Resources.hpLabel:SetFont(Util.Text.getFontString(WeavePulse.SV.Resources.labelFont, (3*WeavePulse.SV.Resources.healthSize/2), WeavePulse.SV.Resources.fontStyle))

                local PERIOD = 1000

                local mix = (1 + math.sin(time * math.pi * 2 / PERIOD)) / 2
                local color = Util.Vectors.mix(WeavePulse.SV.Resources.healthColor, WeavePulse.SV.Resources.healthHighligtColor, mix)

                self.Resources.hpLabel:SetColor(unpack(color))

            else
                self.Resources.hpLabel:SetColor(unpack(WeavePulse.SV.Resources.healthColor))

                self.Resources.hpLabel:SetFont(Util.Text.getFontString(WeavePulse.SV.Resources.labelFont, WeavePulse.SV.Resources.healthSize, WeavePulse.SV.Resources.fontStyle))
            end

            self.Resources.hpLabel:SetText((showAbsolute or self.force)
                and Util.Text.formatNumberCompact(hp)
                or  string.format("%i%%", 100 * hp / maxHp)
            )
            self.Resources.hpLabel:SetHidden(false)
        else
            self.Resources.hpLabel:SetHidden(true)
        end
        if not WeavePulse.SV.Resources.unlockExecuteReminder and WeavePulse.Resources.executeThreshold then
            local reticleOvers = not IsUnitDead("reticleover") and IsUnitAttackable("reticleover") and ((GetCurrentZoneHouseId() ~= 0 and GetUnitType("reticleover") == UNIT_TYPE_CLIENT_CHARACTER) or GetUnitDifficulty("reticleover") >= self.SV.Resources.executeDifficulty)
            if reticleOvers and showResources and WeavePulse.SV.Resources.showExecuteReminder and hp~=1 and 100 * (hp / math.max(1, maxHp)) <= WeavePulse.Resources.executeThreshold and WeavePulse.Resources.executeThreshold ~= 0 then
                self.Resources.executeLabel:SetHidden(false)
            else
                self.Resources.executeLabel:SetHidden(true)
            end
        end
    end
end
