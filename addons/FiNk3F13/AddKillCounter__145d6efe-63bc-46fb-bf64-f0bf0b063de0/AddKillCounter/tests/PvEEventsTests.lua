-- Regression: NPC kills use DIED_XP / DIED even when participation is OFF.
-- The old adapter wrongly restricted DIED_XP to participation and ignored DIED.
dofile("tests/IntegrationTests.lua")
local A = AddKillCounter
local checks = 0
local function eq(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
A.sv.stats = A.Core.NewStats()
A.sv.enabled = true
A.sv.participation = false
A.sv.includePets = false
A.sv.includeCompanion = false
A.session = 0
A:ResetRuntime()
local function event(result, id, name, source, target)
    A:OnCombat(nil, result, false, "Test ability", 0, 0, "Testchar", source or COMBAT_UNIT_TYPE_PLAYER,
        name or "Skelett^m", target or COMBAT_UNIT_TYPE_OTHER, 50, 0, 0, false, 1, id)
end
event(ACTION_RESULT_DIED_XP, 100)
eq(A.sv.stats.total, 1, "Own NPC XP death counts with participation disabled")
eq(A.sv.stats.enemies, nil, "NPC names are not stored")
event(ACTION_RESULT_DIED, 101, "Reh")
eq(A.sv.stats.total, 2, "Own NPC death without XP counts")
event(ACTION_RESULT_DIED_XP, 101, "Reh")
event(ACTION_RESULT_KILLING_BLOW, 101, "Reh")
eq(A.sv.stats.total, 2, "Mixed death events deduplicated")
event(ACTION_RESULT_DIED_XP, 102, "Wolf", COMBAT_UNIT_TYPE_PLAYER_PET)
eq(A.sv.stats.total, 2, "Disabled pet excluded from NPC XP deaths")
A.sv.includePets = true
event(ACTION_RESULT_DIED_XP, 103, "Wolf", COMBAT_UNIT_TYPE_PLAYER_PET)
eq(A.sv.stats.total, 3, "Enabled pet NPC kill counts")
event(ACTION_RESULT_DIED_COMPANION_XP, 104, "Wolf", COMBAT_UNIT_TYPE_PLAYER_COMPANION)
eq(A.sv.stats.total, 3, "Disabled companion excluded")
A.sv.includeCompanion = true
event(ACTION_RESULT_DIED_COMPANION_XP, 105, "Wolf", COMBAT_UNIT_TYPE_PLAYER_COMPANION)
eq(A.sv.stats.total, 4, "Companion NPC death counts")
event(ACTION_RESULT_DIED_XP, 105, "Wolf", COMBAT_UNIT_TYPE_PLAYER_COMPANION)
eq(A.sv.stats.total, 4, "Companion XP event deduplicated")
event(ACTION_RESULT_DIED_XP, 106, "Other player's kill", COMBAT_UNIT_TYPE_GROUP)
eq(A.sv.stats.total, 4, "Group kills excluded in own-kill mode")
event(ACTION_RESULT_DAMAGE, 107, "Zombie")
event(ACTION_RESULT_DIED_XP, 107, "", COMBAT_UNIT_TYPE_GROUP)
eq(A.sv.stats.total, 4, "Prior damage does not enable participation implicitly")
A.sv.participation = true
event(ACTION_RESULT_DIED_XP, 107, "", COMBAT_UNIT_TYPE_GROUP)
eq(A.sv.stats.total, 5, "Explicit participation still works")
A.sv.participation = false
event(ACTION_RESULT_DAMAGE, 108, "Spinne")
event(ACTION_RESULT_DIED_XP, 108, "")
eq(A.sv.stats.total, 6, "Own death with missing name resolves from hits")
event(ACTION_RESULT_DIED, 109, "Puppe", nil, COMBAT_UNIT_TYPE_TARGET_DUMMY)
eq(A.sv.stats.total, 6, "Training dummy still excluded")
event(ACTION_RESULT_DIED, 110, "Self", nil, COMBAT_UNIT_TYPE_PLAYER)
eq(A.sv.stats.total, 6, "Player death still excluded")
event(ACTION_RESULT_DIED_XP, 0, "Unknown ID")
eq(A.sv.stats.total, 6, "Unknown identity does not invent a kill")
eq(A.session, 6, "Session total updates for NPC deaths")
eq(A.sv.stats.log, nil, "No individual kill history stored")
print("PvE death regressions: " .. checks .. " checks passed (mock ESO API)")
