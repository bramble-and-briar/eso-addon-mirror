BackBarTimer = BackBarTimer or {}
local Addon = BackBarTimer

Addon.Config = {
    addonName = "BackBarTimer",
    displayName = "BackBarTimer",
    version = "2.0-rc2",
    savedVariablesName = "BackBarTimer_Saved",
    savedVariablesVersion = 2,

    firstSlot = 3,
    lastSlot = 7,
    minimumDurationMs = 4000,
    hudWarningMs = 2000,
    timerUpdateIntervalMs = 100,
    cadenceUpdateIntervalMs = 10,
    pendingEffectWindowMs = 1200,
    clusterWindowMs = 3000,

    cadencePeriodMs = 1000,
    cadencePulseMs = 300,
    cadenceMaxCatchUp = 4,
}

Addon.Defaults = {
    mode = "hud",
    leadSeconds = 2,
    debug = false,
    suppressZeroDuration = true,

    blockCadence = false,
    lightCadence = true,

    hudFullCountdown = true,
    hudCountdownSeconds = 10,

    hudScale = 1.0,
    leftInset = 500,
    leftY = -50,
    rightInset = 700,
    rightY = -50,

    frontSlots = {
        [3] = true, [4] = true, [5] = true, [6] = true, [7] = true,
    },
    backSlots = {
        [3] = true, [4] = true, [5] = true, [6] = true, [7] = true,
    },
}

function Addon:Log(message, force)
    if not force and not (self.sv and self.sv.debug) then return end
    local text = string.format("[BBT %s] %s", self.Config.version, tostring(message))
    if type(CHAT_ROUTER) == "table" and type(CHAT_ROUTER.AddSystemMessage) == "function" then
        CHAT_ROUTER:AddSystemMessage(text)
    elseif type(d) == "function" then
        d(text)
    end
end

