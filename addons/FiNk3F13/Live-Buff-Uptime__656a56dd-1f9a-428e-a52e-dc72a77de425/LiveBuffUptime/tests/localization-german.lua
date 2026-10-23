GetCVar = function(name) assert(name == "language.2"); return "de" end
dofile("lang/en.lua")
dofile("Localization.lua")
local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
assert(env.setting("Kampfstatistiken").buttonText == "Kampfbericht oeffnen")
assert(env.setting("Panelgroesse").max == 1.5)
env.setting("Gruppenpanel anzeigen").setFunction(true)
local key = env.saved().trackers[1].key
assert(not pcall(env.setting, "Platzierungsvorschau"))
assert(env.controls["LiveBuffUptimeGroupPanel" .. key .. "Title"].text ~= "")
assert(LiveBuffUptimeLocalization.Decimal(7.79) == "7,79")
print("German localization: real localization module retains settings, panel decimals and all group calculation fixtures")
