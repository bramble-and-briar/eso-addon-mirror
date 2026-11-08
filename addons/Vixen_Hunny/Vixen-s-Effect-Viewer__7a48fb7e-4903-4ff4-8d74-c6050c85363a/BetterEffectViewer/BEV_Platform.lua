-- Console-specific caps that keep memory and update load down.
local BEV = BetterEffectViewer

function BEV:IsConsolePlatform()
    return IsConsoleUI ~= nil and IsConsoleUI()
end

function BEV:ApplyRuntimePlatformTuning()
    local runtime = {}
    self.runtime = runtime

    local sv, defaults = self.sv, self.defaults
    if not sv.autoConsoleTuning or not self:IsConsolePlatform() then
        return
    end

    runtime.maxRows = self.ClampInt(sv.consoleSlotRowsCap, 1, 20, defaults.consoleSlotRowsCap)
    runtime.effectCap = self.ClampInt(sv.consoleEffectCap, 8, 256, defaults.consoleEffectCap)
    runtime.maxColsCap = self.ClampInt(sv.consoleMaxColsCap, 1, 20, defaults.consoleMaxColsCap)
    runtime.rescanInterval = self.Clamp(sv.fallbackRescanInterval, 0.5, 5.0, defaults.fallbackRescanInterval)
    runtime.performanceMode = "ultra"
end
