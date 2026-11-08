-- Per-tick loop: target hold timeout, rescans, expiry, timers and flashing.
local BEV = BetterEffectViewer

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Updates one slot's timer text and flash state. Returns its remaining time.
local function updateSlot(self, slot, now, flashThreshold, flashColor, pulse)
    local effect = slot.effect
    if not effect then
        return math.huge
    end

    local remaining = self:TimeRemaining(effect, now)
    local text = self:FormatTime(remaining)
    if text ~= slot.lastTimerText then
        slot.timer:SetText(text)
        slot.lastTimerText = text
    end

    local flashing = remaining > 0 and remaining <= flashThreshold
    if flashing then
        local br, bg, bb, ba = self:UnpackColor(slot.baseBorderColor)
        local tr, tg, tb, ta = self:UnpackColor(slot.baseTimerColor)
        local fr, fg, fb, fa = self:UnpackColor(flashColor)
        slot.border:SetEdgeColor(lerp(br, fr, pulse), lerp(bg, fg, pulse), lerp(bb, fb, pulse), lerp(ba, fa, pulse))
        slot.timer:SetColor(lerp(tr, fr, pulse), lerp(tg, fg, pulse), lerp(tb, fb, pulse), lerp(ta, fa, pulse))
        slot.isFlashing = true
    elseif slot.isFlashing then
        slot.border:SetEdgeColor(self:UnpackColor(slot.baseBorderColor))
        slot.timer:SetColor(self:UnpackColor(slot.baseTimerColor))
        slot.isFlashing = false
    end

    if remaining <= 0 then
        return math.huge
    end
    return remaining
end

function BEV:UpdateVisuals(now, profile)
    if not self.contentShown then
        self.nextVisualUpdateAt = now + profile.visualIdle
        return
    end

    local sv = self.sv
    local flashThreshold = sv.flashThreshold
    local flashColor = sv.flashColor
    local pulse = 0.5 + 0.5 * math.sin(GetFrameTimeMilliseconds() / 150)
    local minRemaining = math.huge

    for _, group in pairs(self.groups) do
        local slots = group.slots
        for i = 1, group.visible do
            local remaining = updateSlot(self, slots[i], now, flashThreshold, flashColor, pulse)
            if remaining < minRemaining then
                minRemaining = remaining
            end
        end
    end

    local fastBelow = math.max(sv.decimalThreshold, flashThreshold)
    if minRemaining <= fastBelow then
        self.nextVisualUpdateAt = now + profile.visualFast
    elseif minRemaining < math.huge then
        self.nextVisualUpdateAt = now + profile.visualNormal
    else
        self.nextVisualUpdateAt = now + profile.visualIdle
    end
end

function BEV:OnUpdate()
    local now = GetFrameTimeSeconds()
    local profile = self:GetPerformanceProfile()

    if self.targetLostAt and now - self.targetLostAt >= self.sv.reticleHoldDuration then
        self:ClearTarget()
    end

    -- Fallback sync for effects that don't emit reliable EVENT_EFFECT_CHANGED updates.
    if self.hasTarget and not self.targetLostAt and now >= self.nextRescanAt then
        self:RescanTarget(now)
    end

    if self.previewActive and self:RefreshPreviewEffects(now) then
        self.needsRedraw = true
    end

    if now >= self.nextMaintenanceAt then
        if self:CleanupExpiredEffects(now) then
            self.needsRedraw = true
        end
        self.nextMaintenanceAt = now + profile.maintenance
    end

    if self.needsRedraw then
        self:Redraw(now)
    end

    if now >= self.nextVisualUpdateAt then
        self:UpdateVisuals(now, profile)
    end
end
