local env = dofile("tests/addon.lua")
local saved = env.saved()
saved.trackers = {
    {key = 1, id = 123, unit = "player", x = 100, y = 100, scale = 1},
    {key = 2, id = 123, unit = "group", x = 100, y = 180, scale = 1.5},
}
ZO_SavedVars.NewAccountWide = function() return saved end
local create = WINDOW_MANAGER.CreateControl
local measurements = 0
function WINDOW_MANAGER:CreateControl(name, parent, kind)
    local control = create(self, name, parent, kind)
    function control:GetTextWidth()
        assert(self.text == "100.0 %", "Reserve the widest percentage, not a changing combat value")
        measurements = measurements + 1
        return 76
    end
    return control
end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
for index = 1, 2 do
    local frame = env.controls["LiveBuffUptimeTracker" .. index]
    assert(frame.width == 136 and frame.height == 48, "Frame must end just after percentage text")
    assert(frame.labels[2].width == 76 and frame.labels[3].width == 76)
    assert(frame.labels[2].x + frame.labels[2].width + 4 == frame.width)
    assert(frame.labels[1].text ~= "" and frame.labels[2].text:find("%%"))
end
assert(measurements == 2, "Text measurement must happen only once per tracker")
for index = 1, 10 do env.setClock(30 + index); env.events.tick() end
assert(measurements == 2 and env.controls.LiveBuffUptimeTracker1.width == 136,
    "Combat updates must not remeasure or resize the HUD")
assert(saved.trackers[1].x == 100 and saved.trackers[2].scale == 1.5)
print("Compact HUD: font-measured maximum percentage, four-pixel padding, group coverage and stable combat dimensions passed")
