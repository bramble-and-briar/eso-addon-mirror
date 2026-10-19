local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
assert(LiveBuffUptimePerformance == nil and LiveBuffUptimeBuffDebug == nil and LiveBuffUptimeEnemyDebug == nil)
assert(LiveBuffUptimeReports.ReceiptDebug == nil)
local function forbidden()
    error("Removed diagnostic code must never be called")
end
local trap = setmetatable({active = true}, {__index = forbidden})
LiveBuffUptimePerformance, LiveBuffUptimeBuffDebug, LiveBuffUptimeEnemyDebug = trap, trap, trap
setup.begin(1000)
setup.raw(1001, 1, EFFECT_RESULT_GAINED, 1016, 11)
setup.raw(1003, 1, EFFECT_RESULT_UPDATED, 1018, 12)
setup.raw(1005, 1, EFFECT_RESULT_UPDATED, 1020, 13)
setup.raw(1007, 1, EFFECT_RESULT_UPDATED, 1022, 14)
setup.damage(1010)
env.setClock(1011)
setup.callbacks[51](51, {unitIds = {player = 1}, units = {}})
local report = assert(env.saved().lastUptimeReport)
local member
for _, row in ipairs(report.buffs[1].members) do if row.id == 1 then member = row end end
assert(member and member.received == 1 and member.renewed == 3,
    "Removing raw diagnostics must preserve the normal receipt/renewal statistics")
local commands = {"buffdebug 61771", "buffdebug start 61771", "buffdebug group 61771", "buffdebug report", "buffdebug off",
    "debuffdebug 34384", "receiptdebug 61771", "perf start", "perf stop", "perf report"}
local before = #env.messages
for _, command in ipairs(commands) do SLASH_COMMANDS["/lbu"](command) end
assert(#env.messages == before + #commands)
for index = 1, 20 do env.events.tick() end
assert(#env.messages == before + #commands, "Removed commands must not enable background logging")
assert(not env.controls.LiveBuffUptimePerformanceFrames)
assert(not pcall(env.setting, "Platzierungsvorschau"), "Placement preview must no longer be offered")
local manifest = assert(io.open("LiveBuffUptime.addon", "r"))
local text = manifest:read("*a"); manifest:close()
for _, name in ipairs({"BuffDebug.lua", "EnemyDebug.lua", "Performance.lua", "Diagnostics.lua", "UptimeAudit.lua"}) do
    assert(not text:find(name, 1, true), "Developer tools must not ship in the manifest")
end
for _, path in ipairs({"LiveBuffUptime.lua", "BuffReports.lua", "LiveUptime.lua"}) do
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"); file:close()
    for _, identifier in ipairs({"LiveBuffUptimeBuffDebug", "LiveBuffUptimeEnemyDebug", "receiptTrace", "freezeCheck", "Performance.Wrap"}) do
        assert(not source:find(identifier, 1, true), "Runtime diagnostic hook remains: " .. identifier)
    end
end
assert(type(LiveBuffUptimeReports.ToggleLock) == "function" and #env.saved().uptimeHistory > 0)
print("No debug runtime: no modules, profiler, buffers, raw hooks or commands; normal counters, history and locks preserved")
