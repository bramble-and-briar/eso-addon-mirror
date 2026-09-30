BackBarTimer = BackBarTimer or {}
local Addon = BackBarTimer

Addon.State = Addon.State or {}
local State = Addon.State

local function NewBar()
    local bar = {}
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        bar[slot] = {
            slot = slot,
            id = 0,
            name = "",
            icon = "",
            staticDurationMs = 0,
            durationMs = 0,
            endTimeMs = 0,
            active = false,
            alerted = false,
            source = "",
        }
    end
    return bar
end

function State:Reset()
    self.bars = {
        [HOTBAR_CATEGORY_PRIMARY] = NewBar(),
        [HOTBAR_CATEGORY_BACKUP] = NewBar(),
    }
    self.pending = {}
    self.inCombat = false
    self.menuOpen = false
    self.suppressNativeRestore = false
    self.clusterAlerted = {}
    self:ClearCadence(false)
end

function State:GetRecord(hotbar, slot)
    local bar = self.bars and self.bars[hotbar]
    return bar and bar[slot] or nil
end

function State:ClearTimers()
    for _, hotbar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        local bar = self.bars and self.bars[hotbar]
        if bar then
            for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
                local record = bar[slot]
                if record then
                    record.durationMs = 0
                    record.endTimeMs = 0
                    record.active = false
                    record.alerted = false
                    record.source = ""
                end
            end
        end
    end
    self.pending = {}
    self.clusterAlerted = {}
end

function State:ClearCadence(rearm)
    self.blockWasActive = false
    self.cadenceArmed = rearm == true and self.inCombat == true
    self.cadenceRunning = false
    self.cadenceStartedMs = 0
    self.cadenceNextCueTimeMs = 0
    self.blockPulseUntilMs = 0
    self.lightPulseUntilMs = 0
end

