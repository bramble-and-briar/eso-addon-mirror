local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local function record(id)
    return {title = tostring(id), marker = id, zone = "Raid", started = 0, ended = 10,
        buffs = {{id = 61771, name = "Buff", unit = "player", covered = 5, duration = 10, percent = 50, members = {}}}}
end
local history, records = {}, {}
for index = 1, 300 do
    records[index] = record(index)
    table.insert(history, 1, records[index])
end
records[1].locked = true
local saved = {uptimeHistory = history}
reports.Init(saved)
local bindings
KEYBIND_STRIP = {AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end}
reports.Open()
reports.ShowZone()
reports.SelectFight(300)
local newest = record(301)
reports.Save(newest)
assert(#history == 300 and history[1] == newest and history[300] == records[1])
for _, report in ipairs(history) do assert(report ~= records[2], "Evict the oldest unlocked fight, not the protected oldest one") end
assert(list.index == 300 and list.entries[300].locked, "Eviction elsewhere must preserve the selected locked fight")
reports.Close()
reports.Save(record(302))
reports.Open()
reports.ShowZone()
assert(history[list.entries[list.index].fightIndex] == records[1], "Selection must survive new reports while closed")
reports.Close()
for _, report in ipairs(history) do report.locked = true end
local previous = history[1]
local beforeMessages = #env.messages
reports.Save(record(303))
assert(#history == 300 and history[1] == previous and saved.lastUptimeReport == previous)
assert(#env.messages == beforeMessages + 1 and env.messages[#env.messages]:find("Neuen Kampf nicht gespeichert", 1, true),
    "Full protected storage must reject a new report explicitly, never silently overwrite a locked fight")
reports.Init(saved)
assert(#history == 300 and history[300] == records[1] and history[300].locked)
local victim = history[150]
victim.locked = nil
local afterUnlock = record(304)
reports.Save(afterUnlock)
assert(#history == 300 and history[1] == afterUnlock and saved.lastUptimeReport == afterUnlock)
for _, report in ipairs(history) do assert(report ~= victim) end
local legacy = {uptimeHistory = {}}
for index = 1, 303 do legacy.uptimeHistory[index] = record(index) end
legacy.uptimeHistory[303].locked = true
reports.Init(legacy)
assert(#legacy.uptimeHistory == 300 and legacy.uptimeHistory[300].marker == 303 and legacy.uptimeHistory[300].locked,
    "Load-time trimming must protect saved locks too")
assert(records[1].buffs[1].percent == 50)
print("Locked retention: oldest-unlocked eviction, 300 total slots, fully locked warning, selection identity and safe reload trimming passed")
