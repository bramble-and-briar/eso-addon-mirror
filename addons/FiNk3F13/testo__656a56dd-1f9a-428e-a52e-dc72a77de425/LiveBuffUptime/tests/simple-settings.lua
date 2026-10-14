local env = dofile("tests/addon.lua")
local saved = env.saved()
saved.trackers = {
    { key = 1, id = 61771, unit = "player", personalTime = "unit", uptimeMetric = "stacks",
        view = "healingIn", includeOverheal = true, x = 123, y = 234, scale = 1.2 },
    { key = 2, id = 61771, unit = "group", personalTime = "combat", uptimeMetric = "stacks",
        view = "healingOut", x = 345, y = 456, scale = 1 },
}
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local removed = { ["Persoenliche Bezugszeit"] = true, ["Auswertungsansicht"] = true,
    ["Ueberheilung als relevante Daten"] = true, ["Uptime-Auswertung"] = true }
local selectors = 0
for _, setting in ipairs(env.panel.descriptors) do
    assert(not removed[setting.label], setting.label)
    if setting.label == "Einheit" then
        selectors = selectors + 1
        assert(#setting.items == 3)
        assert(setting.items[1].data == "player" and setting.items[2].data == "group")
        assert(setting.items[3].data == "dds")
    end
end
assert(selectors == 3)
for _, tracker in ipairs(saved.trackers) do
    assert(tracker.personalTime == "auto" and tracker.uptimeMetric == "time")
    assert(tracker.view == nil and tracker.includeOverheal == nil)
end
assert(saved.trackers[1].x == 123 and saved.trackers[1].y == 234 and saved.trackers[1].scale == 1.2)
assert(saved.trackers[1].unit == "player" and saved.trackers[2].unit == "group")
print("Simple settings: only self/group selection, removed calculation controls, migrated defaults and preserved positions passed")
