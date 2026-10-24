--[[
    AetherPath - Lightweight map pin support
    Minimal: only marks favorite wayshrines when enabled
    Original code
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.MapPins = AP.MapPins or {}

local MapPins = AP.MapPins

function MapPins:Initialize()
    -- We keep this intentionally light.
    -- Full custom pin libraries are heavy; here we only expose a toggle
    -- and let the player use the built-in map filters + favorites list.
    self.enabled = AP.sv.mapPinsEnabled
end

function MapPins:SetEnabled(state)
    AP.sv.mapPinsEnabled = state and true or false
    self.enabled = AP.sv.mapPinsEnabled
end

-- Placeholder for future pin integration if desired.
-- For minimalist design we avoid drawing custom textures on the world map.
function MapPins:Refresh()
    -- no-op in pure minimalist mode
end
