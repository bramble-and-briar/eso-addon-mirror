BackBarTimer = BackBarTimer or {}
local Addon = BackBarTimer

Addon.Config = {
    addonName = "BackBarTimer",
    displayName = "BackBarTimer",
    version = "2.1.1",
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
    skillIconFirst = false,

    leftOrder = "1,2,3,4,5",
    rightOrder = "1,2,3,4,5",
    leftInvert = false,
    rightInvert = false,
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


-- User-facing skill numbers 1..5 map to ESO slots 3..7.
function Addon:ParseDisplayOrder(text)
    if type(text) ~= "string" then return nil end
    local order, seen = {}, {}
    for token in (text .. ","):gmatch("(.-),") do
        local digit = token:match("^%s*([1-5])%s*$")
        local number = tonumber(digit)
        if not number or seen[number] then return nil end
        seen[number] = true
        order[#order + 1] = number
    end
    if #order ~= 5 then return nil end
    return order
end
function Addon:GetDisplayOrder(side)
    local order = self:ParseDisplayOrder(self.sv[side .. "Order"]) or {1,2,3,4,5}
    if self.sv[side .. "Invert"] then
        for index = 1, 2 do order[index], order[6-index] = order[6-index], order[index] end
    end
    return order
end
