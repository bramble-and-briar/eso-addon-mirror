dofile("Diagnostics.lua")
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local A = LiveBuffUptimeDiagnostics
local disabled = {}
A.RecordUnknown(disabled, 1, 61771, 10, 1, 2)
assert(not disabled.diagnostics and not disabled.unknownEffectIndex)
local fight = { diagnostics = {} }
A.RecordUnknown(fight, 3, 61771, 10, 1, nil)
A.RecordUnknown(fight, 2, 61771, 10, 2, 2)
A.RecordUnknown(fight, 4, 61771, 10, 3, 2)
local entry = fight.diagnostics.unknownEffects[1]
assert(entry.count == 3 and entry.gained == 1 and entry.updated == 1 and entry.faded == 1)
assert(entry.first == 2 and entry.last == 4 and entry.kind == 2)
for index = 1, 10000 do A.RecordUnknown(fight, 5, 61771, 10, 2, 2) end
assert(#fight.diagnostics.unknownEffects == 1 and entry.count == 10003)
for index = 1, 30 do A.RecordUnknown(fight, 6, index, 20, 1, 2) end
assert(#fight.diagnostics.unknownEffects == 24 and fight.diagnostics.unknownDetailsDropped == 7)
local count = 0
for _ in pairs(fight.unknownEffectIndex) do count = count + 1 end
assert(count == 24, "Runtime index must remain bounded too")
A.RecordUnknown(fight, 7, 61771, 10, 3, 2)
assert(entry.count == 10004 and entry.faded == 2 and fight.diagnostics.unknownSourceEvents == 10034)
assert(fight.diagnostics.unknownDetailsDropped == 7, "Existing pairs must still aggregate after the cap")
print("Unknown sources: disabled collection, bounded aggregation, recipients, change types, late ordering and overflow counters passed")
