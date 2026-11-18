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
    if HOTBAR_CATEGORY_WEREWOLF ~= nil then
        self.bars[HOTBAR_CATEGORY_WEREWOLF] = NewBar()
    end
    self.werewolf = false
    self.bloodHungerStacks = 0
    self.bloodHungerEndSeconds = 0
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

function State:SetWerewolf(active)
    if self.werewolf == active then return false end
    self.werewolf = active
    self.bars[HOTBAR_CATEGORY_WEREWOLF] = NewBar()
    for key, pending in pairs(self.pending) do
        if pending.hotbar == HOTBAR_CATEGORY_WEREWOLF then self.pending[key] = nil end
    end
    self.bloodHungerStacks = 0
    self.bloodHungerEndSeconds = 0
    return true
end

function State:GetBloodHungerStacks()
    if self.bloodHungerEndSeconds > 0 and self.bloodHungerEndSeconds <= GetFrameTimeSeconds() then
        return 0
    end
    return self.bloodHungerStacks
end

function State:IsSlotEnabled(hotbar, slot)
    local settings
    if hotbar == HOTBAR_CATEGORY_BACKUP then
        settings = Addon.sv.backSlots
    elseif hotbar == HOTBAR_CATEGORY_PRIMARY or (self.werewolf and hotbar == HOTBAR_CATEGORY_WEREWOLF) then
        settings = Addon.sv.frontSlots
    end
    return type(settings) == "table" and settings[slot] ~= false
end

function State:ClearTimers()
    for _, bar in pairs(self.bars) do
        for _, record in pairs(bar) do
            record.durationMs = 0
            record.endTimeMs = 0
            record.active = false
            record.alerted = false
            record.source = ""
            record.cooldownEndMs = nil
            record.cast = nil
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

