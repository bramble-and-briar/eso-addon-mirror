ClearSight = ClearSight or {}
local CS = ClearSight

CS.name = "ClearSight"
CS.version = "1.2.6"
CS.updateIntervalMs = 100

CS.defaults = {
    reticle = {
        enabled = true,
        style = "Cross",
        compassLetterRadius = 95,
        compassLetterSize = 48,
        compassOtherLetterSize = 32,
        wayfinderRadius = 140,
        wayfinderSize = 40,
        compassArrowRadius = 116,
        compassArrowSize = 14,
        size = 64,
        thickness = 5,
        gap = 7,
        outline = 2,
        normalColor = { 1.00, 1.00, 1.00, 1.00 },
        friendlyColor = { 0.10, 1.00, 0.20, 1.00 },
        deadColor = { 1.00, 0.82, 0.10, 1.00 },
        hostileColor = { 1.00, 0.15, 0.10, 1.00 },
        showAcquiredBrackets = true,
    },
    waypoint = {
        enabled = true,
        location = "Both",
        baseSize = 20,
        amberSize = 28,
        redSize = 38,
        greenThresholdDegrees = 8,
        amberThresholdDegrees = 35,
        greenColor = { 0.10, 1.00, 0.20, 1.00 },
        amberColor = { 0.65, 0.20, 1.00, 1.00 },
        redColor = { 0.00, 0.00, 0.00, 1.00 },
        arrivalColor = { 1.00, 1.00, 1.00, 1.00 },
        arrivalSize = 16,
        -- Approximate normalized map-distance handoff thresholds, calibrated from
        -- console testing: match the player's waypoint colour near ~300m, then
        -- hide ClearSight near ~150m so only ESO's stock waypoint remains.
        waypointColorDistance = 0.0180,
        hideOverlayDistance = 0.0090,
        opacity = 1.0,
    },
}

local function DeepCopy(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and DeepCopy(value) or value
    end
    return result
end

function CS:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("ClearSight_SavedVariables", 1, nil, DeepCopy(self.defaults))

    -- 1.0.2 tightens the original green guidance cone. There is no user-facing
    -- setting for this value, so safely migrate existing 1.0.1 SavedVariables.
    if self.saved.waypoint and self.saved.waypoint.greenThresholdDegrees == 10 then
        self.saved.waypoint.greenThresholdDegrees = 8
    end

    -- 1.0.3 gives the reticle a simple accessibility colour language:
    -- white = neutral/no target, green = friendly, red = live hostile, yellow = dead.
    -- These colours were not user-configurable in earlier builds, so migrate the
    -- previous cyan normal colour and add the two new state colours safely.
    if self.saved.reticle then
        local normal = self.saved.reticle.normalColor
        if not self.saved.reticle.customColorsEnabled and normal and normal[1] == 0.10 and normal[2] == 0.90 and normal[3] == 1.00 then
            self.saved.reticle.normalColor = { 1.00, 1.00, 1.00, 1.00 }
        end
        self.saved.reticle.friendlyColor = self.saved.reticle.friendlyColor or { 0.10, 1.00, 0.20, 1.00 }
        self.saved.reticle.deadColor = self.saved.reticle.deadColor or { 1.00, 0.82, 0.10, 1.00 }
    end

    -- Only replace the former shipped defaults; preserve personalised colours.
    if not self.saved.waypoint.guidancePaletteV2 then
        local w = self.saved.waypoint
        local a, r = w.amberColor, w.redColor
        if a and a[1] == 1 and a[2] == 0.65 and a[3] == 0.05 then
            w.amberColor = {0.65, 0.20, 1, a[4] or 1}
        end
        if r and r[1] == 1 and r[2] == 0.10 and r[3] == 0.10 then
            w.redColor = {0, 0, 0, r[4] or 1}
        end
        w.guidancePaletteV2 = true
    end
    -- Calibrated values are defaults and upper limits; preserve smaller choices.
    for key, maximum in pairs({compassLetterRadius=95, compassLetterSize=48,
        compassOtherLetterSize=32, wayfinderRadius=140, wayfinderSize=40}) do
        local minimum = (key == "compassLetterRadius" or key == "wayfinderRadius") and 40 or 16
        self.saved.reticle[key] = math.max(minimum, math.min(maximum, tonumber(self.saved.reticle[key]) or maximum))
    end
    self.saved.reticle.customColorsEnabled = true

    if self.InitializeReticle then
        self:InitializeReticle()
    end

    if self.InitializeWaypoint then
        self:InitializeWaypoint()
    end

    if self.InitializeSettings then
        self:InitializeSettings()
    end

    EVENT_MANAGER:RegisterForUpdate(self.name .. "_Update", self.updateIntervalMs, function()
        if self.UpdateReticle then self:UpdateReticle() end
        if self.UpdateWaypoint then self:UpdateWaypoint() end
    end)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= CS.name then return end
    EVENT_MANAGER:UnregisterForEvent(CS.name, EVENT_ADD_ON_LOADED)
    CS:Initialize()
end

EVENT_MANAGER:RegisterForEvent(CS.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
