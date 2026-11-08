-- Reticle target tracking, rescans and PvE/PvP layout selection.
local BEV = BetterEffectViewer

function BEV:ResolveReticleUnitTag()
    if DoesUnitExist("reticleover") then
        return "reticleover"
    end
    if DoesUnitExist("reticleoverplayer") then
        return "reticleoverplayer"
    end
    return nil
end

-- Schedules a rescan no later than `delay` seconds from now.
function BEV:RequestRescan(delay)
    local at = GetFrameTimeSeconds() + (delay or 0)
    if at < (self.nextRescanAt or math.huge) then
        self.nextRescanAt = at
    end
end

-- Reads every effect on the reticle target and drops anything no longer present.
function BEV:RescanTarget(now, reset)
    now = now or GetFrameTimeSeconds()
    self.nextRescanAt = now + self:GetRescanInterval()

    if reset then
        self:ResetEffects()
    end

    local unitTag = self:ResolveReticleUnitTag()
    if not unitTag then
        return
    end

    self.scanId = (self.scanId or 0) + 1
    local scanId = self.scanId
    local changed = reset == true

    for index = 1, GetNumBuffs(unitTag) do
        local name, startTime, endTime, _, stackCount, iconName, _, effectType, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo(unitTag, index)

        if name and name ~= "" then
            if self:UpsertEffect(name, abilityId, iconName, effectType, startTime, endTime, stackCount, castByPlayer, now, scanId) then
                changed = true
            end
        end
    end

    for key, effect in pairs(self.effects) do
        if effect.scanId ~= scanId then
            self:RemoveEffect(key)
            changed = true
        end
    end

    if changed then
        self.needsRedraw = true
    end
end

function BEV:OnReticleTargetChanged()
    local unitTag = self:ResolveReticleUnitTag()

    if unitTag then
        self.hasTarget = true
        self.targetLostAt = nil
        self:UpdateTargetHeader(unitTag)
        self:RescanTarget(GetFrameTimeSeconds(), true)
        self:Redraw()
    elseif self.hasTarget and not self.targetLostAt then
        -- Keep the last target on screen briefly so flicking the camera doesn't blank it.
        self.targetLostAt = GetFrameTimeSeconds()
        self:SetHeaderStale(true)
    end
end

function BEV:ClearTarget()
    self.hasTarget = false
    self.targetLostAt = nil
    self:ResetEffects()
    self:UpdateTargetHeader(nil)
    self:Redraw()
end

function BEV:IsPvPZone()
    if IsActiveWorldBattleground ~= nil and IsActiveWorldBattleground() then
        return true
    end
    return IsPlayerInAvAWorld ~= nil and IsPlayerInAvAWorld() == true
end

function BEV:GetActiveLayoutKey()
    return self:IsPvPZone() and "pvpLayout" or "pveLayout"
end

function BEV:ApplyCurrentLayout()
    self.activeLayoutKey = self:GetActiveLayoutKey()
    local layout = self.sv[self.activeLayoutKey]

    self.iconSize = layout.iconSize
    self.fontSize = layout.fontSize

    local cols = layout.maxCols
    if self.runtime.maxColsCap then
        cols = math.min(cols, self.runtime.maxColsCap)
    end
    self.maxCols = math.max(1, cols)

    self:RefreshAppearance()
end
