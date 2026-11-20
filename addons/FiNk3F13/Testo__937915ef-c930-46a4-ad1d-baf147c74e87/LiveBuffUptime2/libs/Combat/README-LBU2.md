LibCombat 89, originally by Solinur.
Source: https://github.com/Solinur/LibCombat
Upstream commit: 80817e6929c7626832f9b9114d3b12bad8d642c1
License: LICENSE.md (Artistic License 2.0).

Taken from the verified local SimpleGroupDPS 2.0.8 bundle. The Lua engine and
English strings are identical after renaming the private namespace and constants:
SimpleGroupDPSCombat -> LiveBuffUptime2Combat; SGD_LIBCOMBAT -> LBU2COMBAT.

Preserves its safe CVar defaults, isolated logger, player/pet opening DoT fix,
local passive-skill helper, version 89 critical-mastery support and private
read/refresh/discard helper methods. These helpers only affect this collector.
EmbeddedCombat.lua exports the known event identifiers explicitly. Damage,
healing, effects, combat start and combat summary are delivered by the library;
LiveBuffUptime2 builds the report and renders its own HUD and statistics.
No external combat-library instance or other addon's data is used at runtime.
