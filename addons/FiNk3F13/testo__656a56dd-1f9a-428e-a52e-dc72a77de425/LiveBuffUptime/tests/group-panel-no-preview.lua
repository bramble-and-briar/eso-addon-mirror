local env = dofile("tests/addon.lua")
assert(not pcall(env.setting, "Platzierungsvorschau"))
local show = env.setting("Gruppenpanel anzeigen")
local move = env.setting("Group Panel Move UI")
show.setFunction(false)
assert(move.disable() and env.setting("Panelbreite").disable())
show.setFunction(true)
assert(not move.disable() and not env.setting("Panelgroesse").disable())
move.clickHandler()
local key = env.saved().trackers[1].key
local window = env.controls["LiveBuffUptimeGroupPanel" .. key]
assert(not window.hidden and window.mouse, "Real panel must remain movable")
local tracker = {config = {key = 99, id = 61771, unit = "group", groupPanel = {enabled = true}}}
local members = {{tag = "player", name = "@ActualMember", available = true}}
LiveBuffUptimeGroupPanels.Render(tracker, members, {}, 100, true, false, function() return {ends = 110} end, "Actual Buff")
assert(tracker.groupPanel.title.text == "Actual Buff")
assert(tracker.groupPanel.rows[1].name.text == "@ActualMember")
assert(tracker.groupPanel.rows[1].timer.text == "10,0")
for index = 2, 12 do assert(tracker.groupPanel.rows[index].name.hidden) end
LiveBuffUptimeGroupPanels.Render(tracker, {}, {}, 101, false, false, function() error("No fake members allowed") end, "Actual Buff")
assert(tracker.groupPanel.window.hidden, "Panel must obey ordinary visibility")
for index = 1, 12 do assert(tracker.groupPanel.rows[index].name.hidden) end
print("Group panel: preview removed; live members, timers, visibility and movement retained")
