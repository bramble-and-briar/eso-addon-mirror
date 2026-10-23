local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local config = env.saved().trackers[1]
local setting = assert(env.setting("Panelbreite"))
assert(setting.min == 120 and setting.max == 600 and setting.step == 10)
assert(setting.getFunction() == 420 and setting.disable())
TEXT_WRAP_MODE_ELLIPSIS = 99
local createControl = WINDOW_MANAGER.CreateControl
function WINDOW_MANAGER:CreateControl(name, parent, kind)
    local control = createControl(self, name, parent, kind)
    function control:SetWrapMode(value) self.wrapMode = value end
    function control:SetFont(value) self.font = value end
    function control:SetMaxLineCount(value) self.lineCount = value end
    return control
end
env.setting("Gruppenpanel anzeigen").setFunction(true)
assert(not setting.disable())
local panel = env.controls.LiveBuffUptimeGroupPanel1
local before = env.controls.LiveBuffUptimeTracker1.labels[2].text
local x, y, scale = config.groupPanel.x, config.groupPanel.y, config.groupPanel.scale
for _, width in ipairs({120, 180, 300, 600, 420, 300}) do
    setting.setFunction(width)
    assert(setting.getFunction() == width and config.groupPanel.width == width)
    local narrow = width < 420
    local frameWidth = narrow and (120 + (width - 120) / 300 * 84) or width
    assert(panel.width == frameWidth and panel.height == (narrow and 316 or 172))
    assert(env.controls.LiveBuffUptimeGroupPanel1Title.width == frameWidth - 28)
    for index = 1, 12 do
        local name = env.controls["LiveBuffUptimeGroupPanel1Name" .. index]
        local timer = env.controls["LiveBuffUptimeGroupPanel1Timer" .. index]
        local tint = env.controls["LiveBuffUptimeGroupPanel1Tint" .. index]
        assert(name.width == (narrow and frameWidth - 74 or (width - 12) / 2 - 74) and name.height == 22)
        assert(name.wrapMode == TEXT_WRAP_MODE_ELLIPSIS and name.lineCount == 1,
            "Narrow names must use ellipsis rather than wrap or overflow")
        assert(name.font == "ZoFontGamepad18" and timer.width == 38,
            "Changing width must not shrink the font or timer")
        assert(name.x + name.width < timer.x and timer.x + timer.width <= width,
            "Narrowing must preserve a gap between the ellipsized name and fixed-size timer")
        assert(tint.x + tint.width <= width and name.y == timer.y)
    end
    assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == before, "Width must not change uptime")
    assert(config.groupPanel.x == x and config.groupPanel.y == y and config.groupPanel.scale == scale)
end
env.setting("Panelgroesse").setFunction(1.25)
assert(config.groupPanel.scale == 1.25 and config.groupPanel.width == 300 and math.abs(panel.width - 170.4) < 0.001)
assert(LiveBuffUptimeGroupPanels.Config({config = config}).width == 300, "Saved width must survive config reuse")
setting.setFunction(10)
assert(config.groupPanel.width == 120)
setting.setFunction(1000)
assert(config.groupPanel.width == 600)
local size = env.setting("Panelgroesse")
assert(size.min == 0.5 and size.max == 1.5)
size.setFunction(2)
assert(config.groupPanel.scale == 1.5)
size.setFunction(0.1)
assert(config.groupPanel.scale == 0.5)
config.groupPanel.scale = 2
assert(LiveBuffUptimeGroupPanels.Config({config = config}).scale == 1.5,
    "Previously saved oversized panels must be clamped on load")
assert(config.scale == scale, "Panel limits must not change the tracker HUD scale")
print("Panel width: native slider, migration default, independent scale/position, narrow/wide geometry, timer separation and unchanged uptime passed")
