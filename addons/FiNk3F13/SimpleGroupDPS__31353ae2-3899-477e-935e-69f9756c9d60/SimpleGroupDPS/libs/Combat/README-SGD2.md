LibCombat 89, originally by Solinur.
Source: https://github.com/Solinur/LibCombat
Upstream commit: 80817e6929c7626832f9b9114d3b12bad8d642c1
License: LICENSE.md (Artistic License 2.0).

The complete upstream engine and English strings are bundled.
Console adaptations: safe CVar defaults; disabled optional external logger; private namespace; local passive-skill helper.
The opening player/pet DoT fix is retained. Four private adapter methods expose/refresh the current fight and discard only this collector on solo death/revival.
All other upstream functionality, including effects, buffs/debuffs, resources, stats and version 89 critical-mastery tracking, is retained.
No dependency on or access to CombatMetrics2 or the shared LibCombat global.

The fourth private adapter method finishes prepared wildlife fights that never enter combat, through the native lifecycle. It preserves native boss/portal guards and active group combat, and cancels its pending end if combat or new damage resumes during the summary grace period.
