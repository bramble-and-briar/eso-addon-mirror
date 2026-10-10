local env = dofile("tests/addon.lua")
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local callbacks = {}
LibCombat = { RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end }
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
env.setCombat(false); env.setClock(30)
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "group", x = 0, y = 0, scale = 1, includePets = true, buffSource = "own" },
    { key = 2, id = 61771, unit = "player", x = 0, y = 48, scale = 1 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    callbacks[_G["LIBCOMBAT_" .. name]](_G["LIBCOMBAT_" .. name], time * 1000 + 100000, ...)
end
send("EVENT_MESSAGES", 30, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_EFFECTS_IN", 30, 1, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_GROUPEFFECTS_IN", 30, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, nil, 1)
send("EVENT_GROUPEFFECTS_IN", 31, 10, 999, EFFECT_RESULT_GAINED, 1, 1, nil, 2)
send("EVENT_DAMAGE_OUT", 32, 1, 1, 99, 123, 500)
send("EVENT_EFFECTS_IN", 35, 1, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_GROUPEFFECTS_IN", 36, 10, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 1)
send("EVENT_HEAL_OUT", 40, 1, 1, 10, 123, 500)
env.events.tick()
local group, player = env.controls.LiveBuffUptimeTracker1, env.controls.LiveBuffUptimeTracker2
assert(group.labels[2].text == "63.6 %", group.labels[2].text)
assert(player.labels[2].text == "37.5 %", player.labels[2].text)
local prior = group.labels[2].text
send("EVENT_DAMAGE_IN", 45, 1, 99, 1, 123, 500)
env.events.tick()
assert(group.labels[2].text == prior, "Incoming damage must not extend the Live-Uptime fight")
env.setClock(46)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 132000, endtime = 140000, units = {
        [1] = { unitType = COMBAT_UNIT_TYPE_PLAYER }, [10] = { unitType = COMBAT_UNIT_TYPE_GROUP },
        [99] = { unitType = COMBAT_UNIT_TYPE_OTHER },
    },
})
assert(group.labels[2].text == "63.6 %")
assert(player.labels[2].text == "37.5 %")
for index = 1, 30 do env.events.tick() end
assert(#saved.lastFights == 2 and #saved.lastCheck.last == 2, "Reports must be saved")
assert(saved.lastFights[1].duration == 11 and saved.lastFights[1].covered == 7)
assert(saved.trackers[1].buffSource == nil, "Legacy source setting must be cleared")
assert(saved.lastFights[1].source == "all_without_pets")
assert(saved.lastFights[1].diagnostics.unknownSourceEvents == 2 and #saved.lastFights[1].unknownEffects == 2)
assert(saved.lastFights[1].unknownEffects[1].trackedBuff and saved.lastFights[1].unknownEffects[1].recipientIncluded)
assert(not saved.lastFights[1].unknownEffects[2].trackedBuff and saved.lastFights[1].unknownEffects[2].recipientIncluded)
local unknownReportFrom = #env.messages
SLASH_COMMANDS["/lbu"]("report group")
local unknownReport = table.concat(env.messages, "\n", unknownReportFrom + 1)
assert(unknownReport:find("Effekt 61771", 1, true) and unknownReport:find("Effekt 999", 1, true))
assert(unknownReport:find("Buff-ID relevant ja", 1, true) and unknownReport:find("Buff-ID relevant nein", 1, true))
-- Reload uses stored reports, but never resumes the previous fight's clock.
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "0.0 %")
assert(saved.lastFights[1].unknownEffects[1].id == 61771 and saved.lastFights[1].unknownEffects[1].recipient == 10)
local count = #env.messages
SLASH_COMMANDS["/lbu"]("check last")
assert(#env.messages == count + 2)
-- Disabled trackers restart from enable time, even if the buff was gained while disabled.
env.setting("Buff aktiv").setFunction(false)
send("EVENT_MESSAGES", 50, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_GROUPEFFECTS_IN", 50, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_HEAL_OUT", 50, 1, 1, 10, 123, 500)
local calculations, scans = 0, 0
local calculate, getNum = LiveBuffUptimeEngine.Calculate, GetNumBuffs
LiveBuffUptimeEngine.Calculate = function(...) calculations = calculations + 1; return calculate(...) end
GetNumBuffs = function(...) scans = scans + 1; return getNum(...) end
for index = 1, 2000 do
    send("EVENT_GROUPEFFECTS_IN", 51, 10, 61771, EFFECT_RESULT_UPDATED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
end
assert(calculations == 0 and scans == 0, "Event bursts must not rescan or recalculate the UI")
send("EVENT_GROUPEFFECTS_IN", 51, 10, 61771, EFFECT_RESULT_GAINED, 1, 99, COMBAT_UNIT_TYPE_PLAYER_PET, 99)
env.setClock(52)
env.setting("Buff aktiv").setFunction(true)
send("EVENT_HEAL_OUT", 54, 1, 1, 10, 123, 500)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "100.0 %", "Re-enabled ongoing buff must be seeded: " .. env.controls.LiveBuffUptimeTracker1.labels[2].text)
LiveBuffUptimeEngine.Calculate, GetNumBuffs = calculate, getNum
send("EVENT_GROUPEFFECTS_IN", 55, 10, 61771, EFFECT_RESULT_UPDATED, 1, 4, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_HEAL_OUT", 56, 1, 1, 10, 123, 500)
env.setting("Uptime-Auswertung").setFunction(nil, nil, { data = "stacks" })
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "43.8 %")
for _, descriptor in ipairs(env.panel.descriptors) do
    assert(descriptor.label ~= "Begleiter in Gruppenmessung", "Pet option must be removed")
    assert(descriptor.label ~= "Buff-Quelle", "Source option must be removed")
end
assert(saved.trackers[1].includePets == nil, "Legacy pet setting must be cleared")
assert(env.setting("Auswertungsansicht").getFunction() == "Heilung ausgehend")
env.setClock(58)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 150000, endtime = 156000, units = { [10] = { unitType = COMBAT_UNIT_TYPE_GROUP, name = "Raid member" } },
})
for index = 1, 30 do env.events.tick() end
local record = saved.lastFights[#saved.lastFights - 1]
assert(record.metric == "stacks" and record.view == "healingOut" and not record.includePets)
assert(record.normalCovered == 4 and record.stackCovered == 1.75)
assert(string.find(saved.lastCheck.last[#saved.lastCheck.last - 1], "OK intern", 1, true))
local final = env.controls.LiveBuffUptimeTracker1.labels[2].text
send("EVENT_DAMAGE_OUT", 60, 1, 1, 99, 123, 500)
send("EVENT_GROUPEFFECTS_IN", 60, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 99)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == final, "Late events must not reopen the completed fight")
assert(record.diagnosticVersion == 2 and record.diagnosticsComplete)
assert(record.diagnostics.lateActions == 1 and record.diagnostics.lateEffects == 1)
assert(record.freeze.checks == 1 and record.freeze.violations == 0)
assert(record.members[1].kind == COMBAT_UNIT_TYPE_GROUP and record.members[1].starts == 52 and record.members[1].ends == 56)
local reportFrom = #env.messages
SLASH_COMMANDS["/lbu"]("report group")
local reportText = table.concat(env.messages, "\n", reportFrom + 1)
assert(reportText:find("Gruppenmitglied", 1, true) and reportText:find("OK unveraendert", 1, true))
assert(reportText:find("Nachlauf verworfen: 1 Aktionen, 1 Effekte", 1, true))
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local restored = saved.lastFights[#saved.lastFights - 1]
assert(restored.diagnostics.lateActions == 1 and restored.members[1].kind == COMBAT_UNIT_TYPE_GROUP)
print("Live-Uptime addon: group and personal windows, healing, incoming damage, finalization, fixed sources, pet exclusion and persisted reports passed")
