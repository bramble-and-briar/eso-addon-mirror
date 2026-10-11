local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
COMBAT_UNIT_TYPE_NONE, COMBAT_MECHANIC_FLAGS_HEALTH = 0, 1
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
LIBCOMBAT_LOG_EVENT_COMBATSTATE, LIBCOMBAT_LOG_EVENT_DAMAGE, LIBCOMBAT_LOG_EVENT_HEAL, LIBCOMBAT_LOG_EVENT_EFFECT = 1, 2, 3, 4
LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_MESSAGE_COMBATSTART = 51, 1
local callbacks, bossId, health, dead = {}, 99, 50, false
LibCombat2 = {
    RegisterForCombatEvent = function(_, event, callback) callbacks[event] = callback; return true end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitIdByTag = function(tag) return tag == "boss1" and bossId or tag == "player" and 1 end,
    GetUnitById = function(id)
        return { GetUnitType = function() return id == 1 and 1 or id == 10 and 3 or 4 end }
    end,
}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local exists = DoesUnitExist
function DoesUnitExist(tag) return tag == "boss1" and bossId ~= nil or exists(tag) end
function GetUnitPower() return health, 100 end
function GetGroupSize() return 0 end
function GetUnitName(tag) return tag == "boss1" and "Test boss" or tag end
function IsUnitDead() return dead end
env.setCombat(false); env.setClock(30); env.setBuffs("player", {})
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "player", scale = 1, x = 0, y = 0 },
    { key = 2, id = 61771, unit = "group", scale = 1, x = 0, y = 48 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(event, time, ...)
    env.setClock(time)
    callbacks[event](event, GetGameTimeMilliseconds(), ...)
end
local function action(time) send(2, time, 1, 1, bossId or 99, 123, 500, 1, 0) end
local function buff(time, id, change) send(4, time, id, 61771, change, 1, 1, 1, 1) end
local function summary(time, group)
    env.setClock(time)
    local units = { [1] = { unitType = 1 }, [bossId or 99] = { unitType = 4, isBoss = true } }
    if group then units[10] = { unitType = 3 } end
    callbacks[51](51, { unitIds = { player = 1, bosses = { [bossId or 99] = true } }, units = units })
    for index = 1, 30 do env.events.tick() end
end
local function records() return #(saved.lastFights or {}) end
send(1, 30, 1); action(30)
buff(35, 1, 1); buff(35, 10, 1); buff(95, 1, 3); buff(95, 10, 3); action(130)
summary(131, true)
assert(records() == 0, "A damaged living boss must defer the library summary")
-- Raw effects still close during the combat-state pause.
buff(140, 1, 1); buff(145, 1, 3)
send(1, 150, 1); action(150)
buff(160, 1, 1); buff(240, 1, 3); action(250)
health = 0
summary(251)
assert(records() == 2 and saved.lastFights[1].combatDuration == 220)
assert(saved.lastFights[1].covered == 145 and saved.lastFights[1].duration == 220,
    "Both segments and buff events during the pause must survive")
assert(saved.lastFights[1].diagnostics.encounterSegments == 2)
assert(#saved.lastFights[2].members == 2, "Earlier group recipients must survive later summary omission")
local percent = env.controls.LiveBuffUptimeTracker1.labels[2].text
action(260); buff(260, 1, 1); env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == percent, "Completed encounters must remain frozen")

-- A reset to full health ends the pending encounter and starts a fresh attempt.
health = 50
send(1, 300, 1); action(300); buff(300, 1, 1); buff(310, 1, 3); action(320); summary(321)
assert(records() == 2)
health = 100; env.events.tick()
for index = 1, 30 do env.events.tick() end
assert(records() == 4 and saved.lastFights[3].combatDuration == 20)
send(1, 330, 1); action(330); action(340); health = 0; summary(341)
assert(records() == 6 and saved.lastFights[5].combatDuration == 10)

-- Same name is insufficient: a different boss ID must never merge.
health = 50; bossId = 99
send(1, 400, 1); action(400); action(420); summary(421)
assert(records() == 6)
bossId = 100
send(1, 430, 1); action(430); action(440); health = 0; summary(441)
assert(records() == 10 and saved.lastFights[7].combatDuration == 20 and saved.lastFights[9].combatDuration == 10)

-- Wipes, vanished bosses and manual resets cannot retain a pending encounter.
health = 50; bossId = 99
send(1, 500, 1); action(500); action(510); summary(511)
dead = true; env.events.tick(); dead = false
for index = 1, 30 do env.events.tick() end
assert(records() == 12)
send(1, 530, 1); action(530); action(540); summary(541)
bossId = nil; env.events.tick()
for index = 1, 30 do env.events.tick() end
assert(saved.lastFights[11].combatDuration == 10)
bossId = 99; health = 50
send(1, 560, 1); action(560); action(570); summary(571)
SLASH_COMMANDS["/lbu"]("reset")
local from = #env.messages + 1
SLASH_COMMANDS["/lbu"]("status")
local status = table.concat(env.messages, "\n", from)
assert(status:find("Boss-Fortsetzungen 1", 1, true) and status:find("Boss-Pause nein", 1, true))
assert(status:find("Callback-Fehler 0", 1, true))
-- Ordinary add pulls must reset both the active clock and accumulated buff time.
bossId = nil
send(1, 580, 1); action(580)
buff(582, 1, 1); buff(586, 1, 3); action(590); summary(591)
local personal = saved.lastFights[#saved.lastFights - 1]
assert(personal.covered == 4 and personal.duration == 10 and personal.percent == 40,
    "An add pull must use only its own buff intervals and active clock")
assert(personal.diagnostics.encounterSegments == 1)
send(1, 600, 1); action(600)
buff(604, 1, 1); buff(618, 1, 3); action(620); summary(621)
personal = saved.lastFights[#saved.lastFights - 1]
assert(personal.covered == 14 and personal.duration == 20 and personal.percent == 70,
    "A second add pull must not inherit the previous pull's numerator or denominator")
assert(personal.diagnostics.encounterSegments == 1)
-- A visible damaged boss alone is insufficient without confirmation in the fight.
bossId, health = 99, 50
send(1, 630, 1); action(630); action(640)
callbacks[51](51, { unitIds = { player = 1 }, units = { [1] = { unitType = 1 } } })
for index = 1, 30 do env.events.tick() end
personal = saved.lastFights[#saved.lastFights - 1]
assert(personal.duration == 10 and personal.percent == 0 and personal.diagnostics.encounterSegments == 1,
    "Unrelated add fights must finish even when a damaged boss tag is visible")
-- Summary clocks can include actions that were absent from the live callbacks.
-- Their earlier boundary must survive a later segment as well.
local bridge = LiveBuffUptimeCombatBridge.Create(LibCombat2)
local result
bridge:RegisterForCombatEvent("test", bridge.EVENT_MESSAGES, function() end)
bridge:RegisterForCombatEvent("test", bridge.EVENT_DAMAGE_OUT, function() end)
bridge:RegisterForCombatEvent("test", bridge.EVENT_FIGHTSUMMARY, function(_, fight) result = fight end)
send(1, 600, 1); action(610); action(620)
callbacks[51](51, { unitIds = { player = 1, bosses = { [99] = true } }, units = {},
    damageDone = { [1] = { startTime = 700000, endTime = 720000 } } })
assert(result == nil)
send(1, 630, 1); action(630); action(650); health = 0
callbacks[51](51, { unitIds = { player = 1 }, units = {} })
assert(result.starttime == 700000 and result.endtime == 750000 and result.encounterSegments == 2)
print("Boss continuation: phases, pause effects, full span, recipients, frozen end, resets, boss identity, wipes and disappearance passed")
