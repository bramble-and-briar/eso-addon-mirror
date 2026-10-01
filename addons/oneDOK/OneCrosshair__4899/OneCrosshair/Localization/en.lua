local strings = {
    LOCKED_APPEARANCE = "Locked in release 1.0. Edit Core/Config.lua and reload the UI.",
    PRESET_LARGE_DOT = "Large Dots (5x)",
    PRESET_RAYS = "Rays", PRESET_DIAMONDS = "Diamonds", PRESET_ESO = "ESO Default",
    PRESET_DOT = "Dot", NORMAL = "Normal", TARGET = "Target", BLOCK = "Block",
    CROSSHAIR = "Crosshair", PRESET = "Preset", APPEARANCE = "Appearance",
    CROSSHAIR_OPACITY = "Crosshair Opacity", HUD_OPACITY = "HUD Opacity", HUD = "HUD",
    RESOURCES = "Resources", GCD = "GCD", VISIBILITY = "Visibility",
    ALWAYS = "Always", COMBAT_ONLY = "Combat Only", DYNAMIC = "Dynamic", OFF = "Off",
    EFFECTS = "Effects", LOW_RESOURCE = "Low Resource Warning",
    SHIELD = "Shield", COMBAT_FEEDBACK = "Combat Feedback",
    RESOURCE_GEOMETRY = "Resource Geometry", RESOURCE_THICKNESS = "Line Thickness",
    RESOURCE_LENGTH = "Arc Length (0–100%)", RESOURCE_RADIUS = "Ring Radius",
}
for key, value in pairs(strings) do
    local id = "SI_ONECROSSHAIR_" .. key
    if not _G[id] then ZO_CreateStringId(id, value) end
end
