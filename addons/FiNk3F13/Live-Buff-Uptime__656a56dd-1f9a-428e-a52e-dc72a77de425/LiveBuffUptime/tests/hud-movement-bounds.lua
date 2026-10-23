local env = dofile("tests/addon.lua")
local config = env.saved().trackers[1]
local frame = env.controls["LiveBuffUptimeTracker" .. config.key]
assert(not frame.handlers.OnMouseEnter and not frame.handlers.OnMouseExit,
    "HUD trackers must not create hover tooltips")
local scale = 1
function frame:SetScale(value) scale = value end
function frame:GetWidth() return self.width * scale end
function frame:GetHeight() return self.height * scale end
local stickX, stickY = 0, 0
GetGamepadRightStickX = function() return stickX end
GetGamepadRightStickY = function() return stickY end
for _, size in ipairs({0.5, 1, 1.5, 2}) do
    env.setting("Groesse").setFunction(size)
    env.setting("Move UI").clickHandler()
    stickX, stickY = 1, -1
    for index = 1, 200 do env.events.move() end
    assert(frame.x == GuiRoot:GetWidth() - frame:GetWidth(), "HUD must reach the right edge at scale " .. size)
    assert(frame.y == GuiRoot:GetHeight() - frame:GetHeight(), "HUD must reach the bottom edge at scale " .. size)
    assert(config.x == frame.x and config.y == frame.y)
    stickX, stickY = -1, 1
    for index = 1, 200 do env.events.move() end
    assert(frame.x == 0 and frame.y == 0, "HUD must reach top and left without going off screen")
    stickX, stickY = 0, 0
    env.setClock(GetFrameTimeSeconds() + 3)
    env.events.move()
    assert(not frame.mouse and config.x == 0 and config.y == 0)
end
assert(env.setting("Groesse").tooltip and env.setting("Panelbreite").tooltip,
    "Removing HUD hover text must retain settings descriptions")
env.setting("Gruppenpanel anzeigen").setFunction(true)
env.setting("Panelgroesse").setFunction(1.5)
env.setting("Panelbreite").setFunction(180)
local panel = env.controls["LiveBuffUptimeGroupPanel" .. config.key]
local panelScale = 1.5
function panel:SetScale(value) panelScale = value end
function panel:GetWidth() return self.width * panelScale end
function panel:GetHeight() return self.height * panelScale end
env.setting("Group Panel Move UI").clickHandler()
stickX, stickY = 1, -1
for index = 1, 200 do env.events.move() end
assert(math.abs(panel.x - (GuiRoot:GetWidth() - panel:GetWidth())) < 0.001,
    string.format("Panel right edge: x %.3f, width %.3f", panel.x, panel:GetWidth()))
assert(panel.y == GuiRoot:GetHeight() - panel:GetHeight())
assert(config.groupPanel.x == panel.x and config.groupPanel.y == panel.y)
print("HUD movement: no tooltip, all screen edges, scale applied once, persistence and shared group-panel bounds passed")
