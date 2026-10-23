local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local config = env.saved().trackers[1]
local setting = assert(env.setting("Panelbreite"))
for _, descriptor in ipairs(env.panel.descriptors) do
    assert(descriptor.label ~= "Spalten", "Column choice must be automatic, not another setting")
end
assert(setting.getFunction() == 420 and setting.disable())
config.groupPanel.columns = 1
assert(LiveBuffUptimeGroupPanels.Config({config = config}).columns == nil, "Old manual column settings must be removed")
env.setting("Gruppenpanel anzeigen").setFunction(true)
assert(not setting.disable())
local panel = env.controls.LiveBuffUptimeGroupPanel1
local before = env.controls.LiveBuffUptimeTracker1.labels[2].text
local x, y, scale = config.groupPanel.x, config.groupPanel.y, config.groupPanel.scale
local previousRowWidth, previousTimerX
for width = 600, 120, -10 do
    setting.setFunction(width)
    local rowWidth = env.controls.LiveBuffUptimeGroupPanel1Tint1.width
    local timerX = env.controls.LiveBuffUptimeGroupPanel1Timer1.x
    if previousRowWidth then
        assert(rowWidth < previousRowWidth and timerX < previousTimerX,
            "Every narrowing step must change visible row width and timer position, including 410 to 210")
        assert(previousRowWidth - rowWidth <= 5.001,
            "Row width must not jump or grow when players wrap into one column")
    end
    for index = 1, 12 do
        assert(not env.controls["LiveBuffUptimeGroupPanel1Name" .. index].hidden)
    end
    previousRowWidth, previousTimerX = rowWidth, timerX
end
setting.setFunction(420)
local twoColumnRowWidth = env.controls.LiveBuffUptimeGroupPanel1Tint1.width
local twoColumnTimerX = env.controls.LiveBuffUptimeGroupPanel1Timer1.x
setting.setFunction(410)
assert(env.controls.LiveBuffUptimeGroupPanel1Tint1.width < twoColumnRowWidth)
assert(twoColumnRowWidth - env.controls.LiveBuffUptimeGroupPanel1Tint1.width < 3)
assert(env.controls.LiveBuffUptimeGroupPanel1Timer1.x < twoColumnTimerX,
    "420 to 410 must stack the second column without widening rows or moving timers right")
assert(math.abs(panel.width - 201.2) < 0.001 and panel.height == 316)
setting.setFunction(180)
assert(math.abs(panel.width - 136.8) < 0.001 and math.abs(env.controls.LiveBuffUptimeGroupPanel1Name1.width - 62.8) < 0.001,
    "Narrower widths must still shrink names without changing font scale")
for _, width in ipairs({300, 410, 420, 600, 410, 420, 300}) do
    local columns = width < 420 and 1 or 2
    setting.setFunction(width)
    assert(config.groupPanel.columns == nil and config.groupPanel.width == width)
    assert(setting.getFunction() == width)
    assert(panel.height == (columns == 1 and 316 or 172))
    for index = 1, 12 do
        local name = env.controls["LiveBuffUptimeGroupPanel1Name" .. index]
        local timer = env.controls["LiveBuffUptimeGroupPanel1Timer" .. index]
        local rows = columns == 1 and 12 or 6
        assert(not name.hidden and name.y == 30 + ((index - 1) % rows) * 24)
        assert(name.x == (columns == 2 and index > 6 and (width - 12) / 2 + 38 or 26))
        assert(name.width == (columns == 1 and 120 + (width - 120) / 300 * 84 - 74 or (width - 12) / 2 - 74),
            "Stacked rows must remain compact rather than stretch across two columns")
        assert(name.y + name.height <= panel.height and timer.y == name.y)
    end
    assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == before)
    assert(config.groupPanel.x == x and config.groupPanel.y == y and config.groupPanel.scale == scale)
end
env.setting("Panelbreite").setFunction(300)
assert(math.abs(env.controls.LiveBuffUptimeGroupPanel1Name1.width - 96.4) < 0.001)
assert(math.abs(env.controls.LiveBuffUptimeGroupPanel1Timer12.x - 128.4) < 0.001 and math.abs(panel.width - 170.4) < 0.001)
env.setting("Panelgroesse").setFunction(1.25)
assert(config.groupPanel.columns == nil and config.groupPanel.width == 300 and config.groupPanel.scale == 1.25)
assert(LiveBuffUptimeGroupPanels.Config({config = config}).width == 300, "Saved width must determine the restored layout")
env.setting("Group Panel Move UI").clickHandler()
assert(panel.mouse and panel.height == 316, "The taller one-column frame must remain movable")
env.setClock(GetFrameTimeSeconds() + 3)
env.events.move()
assert(not panel.mouse)
print("Automatic columns: removed manual setting, legacy migration, width-based 1/2 columns, threshold changes, twelve stacked players, unchanged uptime and movement passed")
