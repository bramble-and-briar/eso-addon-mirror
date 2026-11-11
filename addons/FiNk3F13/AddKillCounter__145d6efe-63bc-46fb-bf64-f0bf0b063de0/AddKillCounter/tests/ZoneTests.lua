dofile("tests/SettingsTests.lua")
local A = AddKillCounter
local checks = 0
local function eq(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local zone = 347
function GetUnitWorldPosition(tag)
    assert(tag == "player", "Check the player's location")
    return zone, 0, 0, 0
end
function GetParentZoneId(id)
    if id == 9999 then return 557 end -- synthetic child zone
    if id == 557 then return 347 end
    return id
end
A.sv.stats = A.Core.NewStats()
A.sv.stats.total = 50 -- historical total must survive the scope change
A.sv.enabled = true; A.sv.showHUD = true; A.sv.combatOnly = false
A.session = 0
A:LocationChanged()
eq(A:IsInTargetZone(), false, "Coldharbour exterior excluded")
eq(A.hudFragment.testHidden, true, "HUD hidden outside dungeon")
local function event(result, id, source)
    A:OnCombat(nil, result, false, "Test", 0, 0, "Player", source or COMBAT_UNIT_TYPE_PLAYER,
        "Skelett", COMBAT_UNIT_TYPE_OTHER, 50, 0, 0, false, 1, id)
end
event(ACTION_RESULT_DIED_XP, 1)
eq(A.sv.stats.total, 50, "Outside kill does not count")
zone = 557; A:LocationChanged()
eq(A:IsInTargetZone(), true, "Village zone ID accepted")
eq(A.hudFragment.testHidden, false, "HUD appears on entry")
event(ACTION_RESULT_DIED_XP, 2)
eq(A.sv.stats.total, 51, "Inside kill counts")
zone = 108; A:LocationChanged(); event(ACTION_RESULT_DIED_XP, 3)
eq(A.sv.stats.total, 51, "Counting pauses on departure")
eq(A.hudFragment.testHidden, true, "HUD disappears on departure")
zone = 339; A:LocationChanged(); event(ACTION_RESULT_DIED_XP, 4)
eq(A.sv.stats.total, 51, "Map ID is not mistaken for zone ID")
zone = 9999; A:LocationChanged(); event(ACTION_RESULT_DIED_XP, 5)
eq(A.sv.stats.total, 52, "Dungeon child zones included by parent")
zone = 0; A:LocationChanged(); event(ACTION_RESULT_DIED_XP, 6)
eq(A.sv.stats.total, 52, "Unknown/loading zone excluded")
zone = 557; A:LocationChanged()
A.sv.participation = true
event(ACTION_RESULT_DAMAGE, 7)
zone = 347; A:LocationChanged()
zone = 557; A:LocationChanged()
event(ACTION_RESULT_DIED_XP, 7, COMBAT_UNIT_TYPE_GROUP)
eq(A.sv.stats.total, 52, "Prior visit's hit cache is cleared")
eq(A.sv.stats.days["20261110"].total, 2, "Day total includes only in-dungeon kills")
eq(A.sv.stats.log, nil, "Zone restriction does not restore individual logging")
eq(A.sv.stats.enemies, nil, "Zone restriction does not restore enemy records")
A:DeactivateZone()
eq(A.sv.targetZoneId, 0, "No fixed zone after deactivation")
eq(A:IsInTargetZone(), false, "Inactive until explicitly selected")
event(ACTION_RESULT_DIED_XP, 8)
eq(A.sv.stats.total, 52, "No selected zone means no counting")
zone = 108
A:ActivateCurrentZone()
eq(A.sv.targetZoneId, 108, "Current location becomes selected zone")
eq(A.sv.targetZoneName, "Zone 108", "Selected zone name saved")
eq(A.hudFragment.testHidden, false, "HUD shown in newly selected area")
event(ACTION_RESULT_DIED_XP, 9)
eq(A.sv.stats.total, 53, "Kills count in newly selected area")
zone = 557; A:LocationChanged()
event(ACTION_RESULT_DIED_XP, 10)
eq(A.sv.stats.total, 53, "Previous zone no longer counts")
eq(A.hudFragment.testHidden, true, "HUD hidden outside selected area")
zone = 0
eq(A:ActivateCurrentZone(), false, "Loading position cannot be selected")
eq(A.sv.targetZoneId, 108, "Invalid selection preserves existing area")
zone = 108; A:LocationChanged()
eq(A:IsInTargetZone(), true, "Return to saved selection reactivates")
eq(A.sv.stats.log, nil, "Selection does not add individual storage")
print("Dungeon scope: " .. checks .. " checks passed (mock ESO API)")
