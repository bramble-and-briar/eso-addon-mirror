local O = OneCrosshair
O.GCD = { idleColor = { .8, .82, .85 }, readyColor = { .26, .88, .38 } }
local MAX_LATENCY_MS = 150 -- CombatMetronome default ping-zone cap; heuristic, not an engine window
function O.GCD.New() return { active = false, progress = 0 } end
function O.GCD.Read(self)
    local wasActive, wasReady = self.active, self.ready
    local previousRemaining, previousAt = self.remaining, self.sampleAt
    local now = GetFrameTimeMilliseconds()
    self.sampleAt = now
    self.active, self.progress, self.ready = false, 0, false
    self.latency, self.lead = nil, 0
    self.remaining, self.duration = 0, 0
    if not GetSlotCooldownInfo then return self end
    -- Ignore potion/item/individual cooldowns: the explicit global flag is required.
    -- Scan the active bar; a locally cooling slot may mask its global cooldown.
    local bestRemaining, bestDuration = 0, 0
    -- ESO's own actionbar.lua converts these engine constants with +1.
    for slot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 do
        local remaining, duration, global, globalSlotType = GetSlotCooldownInfo(slot)
        local abilityCooldown = globalSlotType == ACTION_TYPE_ABILITY or globalSlotType == ACTION_TYPE_CRAFTED_ABILITY
        if global and abilityCooldown and duration > 0 and remaining > bestRemaining then
            bestRemaining, bestDuration = remaining, duration
        end
    end
    if bestRemaining > 0 then
        self.active = true
        self.remaining, self.duration = bestRemaining, bestDuration
        self.progress = O.Clamp(1 - bestRemaining / bestDuration)
    end
    if self.active then
        -- A rising timer or an expired prior sample starts a fresh observed cycle,
        -- including back-to-back skills with no sampled zero between them.
        local newCycle = not wasActive or bestRemaining > previousRemaining
            or (previousAt and now - previousAt >= previousRemaining)
        self.latency = GetLatency and GetLatency() or nil
        self.lead = math.min(MAX_LATENCY_MS, math.max(0, self.latency or 0))
        -- Enter the reference's ping zone, then latch until this GCD completes.
        -- LA availability and previous LA hits do not define the timing cue.
        self.ready = (not newCycle and wasReady) or bestRemaining <= self.lead
    end
    return self
end
function O.GCD.Presentation(self)
    if not self.active then return 1, O.GCD.idleColor, .25 end
    if self.ready then return 1, O.GCD.readyColor, 1 end
    return self.progress, O.GCD.idleColor, 1
end
