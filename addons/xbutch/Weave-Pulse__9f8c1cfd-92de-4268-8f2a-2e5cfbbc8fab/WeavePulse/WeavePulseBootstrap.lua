-- WeavePulse: an independent, unofficial adaptation of CombatMetronome.
WeavePulse = {
    name = "WeavePulse", versionString = "1.51.01", upstreamVersion = "1.7.7",
    API = GetAPIVersion(), beta = false, Util = {}, Settings = {},
    StackTracker = { name = "WeavePulseStackTracker" },
    LATracker = { name = "WeavePulseLightAttackTracker" }, Resources = {}, menu = {},
}
local W = WeavePulse
W.Util.Text, W.Util.Stacks, W.Util.Ability = {}, {}, {}
W.Util.Vectors = {}
function W.Util.Vectors.mix(a, b, amount)
    local result = {}
    for index = 1, 4 do result[index] = a[index] + (b[index] - a[index]) * amount end
    return result
end

function W:Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = self:Copy(item) end
    return copy
end

function W:Print(message)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("|cD6B66BWeavePulse|r: " .. tostring(message))
    elseif d then d("WeavePulse: " .. tostring(message)) end
end
W.debug = { Print = function(_, message) W:Print(message) end }

-- Both the game's hard budget and a small private soft budget bound each job.
W.jobs = {}
function W:HasBudget()
    if GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS then
        return GetTotalUserAddOnCPUTimeAvailableEachFrameMS() - GetTotalUserAddOnCPUTimeUsedNowMS() > 0.25
    end
    return true
end
function W:StartUpdate(key, interval, callback)
    if self.jobs[key] then return end
    self.jobs[key] = true
    EVENT_MANAGER:RegisterForUpdate(self.name .. key, interval, function()
        if self.jobs[key] and self:HasBudget() then callback() end
    end)
end
function W:StopUpdate(key)
    if not self.jobs[key] then return end
    self.jobs[key] = nil
    EVENT_MANAGER:UnregisterForUpdate(self.name .. key)
end
function W:PlayCue(sound, volume)
    local soundId = SOUNDS[sound] or sound
    -- Preserve the upstream volume range, with a bounded number of sound calls.
    for _ = 1, math.max(0, math.min(30, tonumber(volume) or 1)) do PlaySound(soundId) end
end

ZO_CreateStringId("SI_BINDING_NAME_WEAVEPULSE_FORCE", "Force WeavePulse display")
ZO_CreateStringId("SI_BINDING_NAME_WEAVEPULSE_TOGGLE_SOUND_CUES", "Toggle WeavePulse sound cues")
ZO_CreateStringId("SI_BINDING_NAME_WEAVEPULSE_TOGGLE_TICK", "Toggle WeavePulse tick")
ZO_CreateStringId("SI_BINDING_NAME_WEAVEPULSE_TOGGLE_TOCK", "Toggle WeavePulse tock")
