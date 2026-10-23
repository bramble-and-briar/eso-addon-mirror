local env = dofile("tests/addon.lua")
local names = {"EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT"}
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
UNIT_REACTION_HOSTILE, BUFF_EFFECT_TYPE_DEBUFF = 3, 2
local callbacks = {}
LibCombat = {RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end}
GetUnitReaction = function() return 2 end
IsUnitAttackable = function(tag) return tag == "reticleover" end
DoesUnitExist = function(tag) return tag == "player" or tag == "reticleover" end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local saved = env.saved()
saved.trackers = {{key = 1, id = 34384, unit = "reticleover", scale = 1, x = 0, y = 0}}
ZO_SavedVars.NewAccountWide = function() return saved end
env.setCombat(false); env.setClock(100)
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    callbacks[_G["LIBCOMBAT_" .. name]](_G["LIBCOMBAT_" .. name], time * 1000 + 100000, ...)
    if name == "EVENT_DAMAGE_OUT" then
        local _, _, target, _, damage = ...
        LiveBuffUptimeReports.RecordDamage(1, 4, target, "Uebungsskelett", damage)
    end
end
send("EVENT_MESSAGES", 100, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_DAMAGE_OUT", 100, 1, 1, 99, 123, 100)
env.setClock(102); env.setBuffs("reticleover", {{34384, 102, 110}})
env.events[EVENT_EFFECT_CHANGED](nil, 1, 1, "", "reticleover", 102, 110,
    1, "icon", 0, 2, 0, 0, "Gegner", 99, 34384, 1)
send("EVENT_DAMAGE_OUT", 106, 1, 1, 99, 123, 100)
env.events.tick()
local hud = env.controls.LiveBuffUptimeTracker1
assert(hud.labels[1].text == "4.0", "The native snapshot sees Morag Tong's remaining timer")
assert(hud.labels[2].text == "66.7 %", "Native enemy effect must reach the live numerator: " .. hud.labels[2].text)
env.events[EVENT_RETICLE_TARGET_CHANGED]()
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "PC without target lookup must not erase a live debuff result when the reticle changes")
local before = #env.messages
SLASH_COMMANDS["/lbu"]("status")
local diagnostic = table.concat(env.messages, "\n", before + 1)
assert(diagnostic:find("Debuff-Diagnose ID 34384: ESO-Timer 4.00s | HUD 66.7% | Ziel-ID 99 (number) | Zieleinheit vorhanden", 1, true))
assert(diagnostic:find("Debuff-Live: Buff 4.000s / Bezug 6.000s", 1, true))
assert(diagnostic:find("Debuff-Effektdaten: 1 Einheiten", 1, true))
assert(hud.labels[2].text == "66.7 %", "One-shot diagnostics must not alter the live calculation")
-- A duplicate library callback must not double-count the native slot.
send("EVENT_EFFECTS_OUT", 106, 99, 34384, 2, 2, 1, 1, 1)
env.events.tick()
assert(hud.labels[2].text == "66.7 %")
send("EVENT_DAMAGE_OUT", 112, 1, 1, 99, 123, 100)
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "Known expiry must close the eight-second debuff without a fade event")
env.setClock(113)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 200000, endtime = 212000, playerid = 1,
    units = {[1] = {unitType = 1}, [99] = {unitType = 4}}})
assert(hud.labels[2].text == "66.7 %")
local report = assert(saved.lastUptimeReport)
assert(#report.debuffs == 1 and math.abs(report.debuffs[1].percent - 200 / 3) < 0.00001,
    "Attackable neutral dummy must appear in the report with the same percent as the HUD")
env.setBuffs("reticleover", {})
env.events[EVENT_RETICLE_TARGET_CHANGED]()
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "PC final enemy uptime must survive losing the reticle ID after combat")
send("EVENT_MESSAGES", 120, LIBCOMBAT_MESSAGE_COMBATSTART)
env.events.tick()
assert(hud.labels[2].text == "0.0 %", "The next fight must not reuse the previous enemy result")
AreUnitsEqual = function(a, b) return a == "boss1" and b == "reticleover" end
send("EVENT_DAMAGE_OUT", 122, 1, 1, 199, 123, 100)
env.setClock(123)
env.rawEvents[EVENT_EFFECT_CHANGED](nil, 1, 1, "", "boss1", 123, 130,
    1, "icon", 0, 2, 0, 0, "Boss", 199, 34384, 1)
-- The notification and reticle callback may both arrive before the scheduled HUD tick.
env.events[EVENT_RETICLE_TARGET_CHANGED]()
send("EVENT_DAMAGE_OUT", 128, 1, 1, 199, 123, 100)
env.events.tick()
assert(hud.labels[2].text == "62.5 %", "HUD must use the report's whole combat window, not only the enemy's action span")
env.setClock(129)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 222000, endtime = 228000, playerid = 1,
    units = {[1] = {unitType = 1}, [199] = {unitType = 4}}})
assert(hud.labels[2].text == "62.5 %" and saved.lastUptimeReport.debuffs[1].percent == 62.5,
    "Final HUD and enemy report must agree even when combat starts before the first outgoing hit")
print("Native enemy HUD: PC library without raw forwarding, Morag Tong timer/uptime, duplicate slot and expiry passed")
