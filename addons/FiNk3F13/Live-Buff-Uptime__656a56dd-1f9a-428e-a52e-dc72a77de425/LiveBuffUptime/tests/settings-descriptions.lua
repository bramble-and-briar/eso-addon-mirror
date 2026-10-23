local env = dofile("tests/addon.lua")
local saved = env.saved()
saved.trackers = {
    {key = 1, id = 39077, unit = "reticleover", x = 100, y = 100, scale = 1},
    {key = 2, id = 106754, unit = "reticleover", x = 100, y = 150, scale = 1},
    {key = 3, id = 93109, unit = "group", groupRole = "damage", x = 100, y = 200, scale = 1},
    {key = 4, id = 61771, unit = "player", x = 100, y = 250, scale = 1},
}
ZO_SavedVars.NewAccountWide = function() return saved end
env.setCombat(false)
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local found, selectors = {}, {}
local before = env.controls.LiveBuffUptimeTracker1.labels[2].text
for _, setting in ipairs(env.panel.descriptors) do
    if setting.type ~= LibHarvensAddonSettings.ST_SECTION then
        local text = type(setting.tooltip) == "function" and setting.tooltip(setting) or setting.tooltip
        assert(type(text) == "string" and #text > 0, "Missing description: " .. tostring(setting.label))
        assert(#text <= 160, "Description must remain short: " .. setting.label)
        found[setting.label] = true
        if setting.label == "Einheit" then selectors[#selectors + 1] = setting end
    end
end
assert(found["Panelbreite"] and not found["Spalten"] and found["In Kampfstatistiken anzeigen"])
assert(found["Immunitaetszeit aus Uptime ausnehmen"] and found["Cooldown-Quelle"] and found["Cooldownzeit aus Uptime ausnehmen"])
assert(#selectors == 5)
for _, item in ipairs(selectors[1].items) do
    selectors[1].setFunction(nil, nil, item)
    local text = selectors[1].tooltip()
    assert(type(text) == "string" and #text <= 160)
    if item.data == "group" or item.data == "dds" then assert(text:find("kuerzeste", 1, true)) end
    if item.data == "dds" then assert(text:find("DD-Rolle", 1, true)) end
end
assert(selectors[4].tooltip():find("DD-Rolle", 1, true), "Existing DD tracker help must describe the role filter")
assert(selectors[5].tooltip():find("auf dir", 1, true), "Existing personal tracker help must describe its own scope")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == before, "Reading help must not change the HUD calculation")
assert(saved.trackers[3].unit == "group" and saved.trackers[3].groupRole == "damage" and saved.trackers[3].y == 200)
print("Settings help: concise descriptions for every control, conditional options, dynamic self/group/DD/enemy help and unchanged configuration/calculation passed")
