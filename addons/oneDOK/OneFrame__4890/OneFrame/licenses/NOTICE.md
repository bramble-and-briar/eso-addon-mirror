# OneFrame GroupCombat attribution

Data/GroupCombat.lua is a reduced, modified extraction/adaptation of LibCombat version 89, by Solinur, distributed under the Artistic License 2.0 (included verbatim in LibCombat-LICENSE.md). Source: the supplied LibCombat/LibCombat.lua and LibCombat.txt, version 89.

Relevant upstream routines: UnitHandler:Initialize, CheckUnit, onCombatEventDmgGrp, FightHandler:UpdateGrpStats, FightHandler:UpdateStats.

This modified module is named OneFrame GroupCombat and is distributed as Lua source under the Artistic License 2.0. It does not replace LibCombat, expose its API, or prevent the original library from being installed or running alongside it.

Changes: only aggregate damage is retained, keyed by combat target ID. No log UI, healing statistics, buffs, skill tracking, saved fights, callbacks, or LibCombat global are included. OneFrame owns event registration and encounter reset. Pending damage is aggregated per target rather than stored as a per-hit log. Unknown targets require friendly/hostile evidence; healing from a friendly source marks a target friendly. Reclassification excludes friendly targets retroactively. Local outgoing damage supplies the DPS time window; if there is no local damage, the group damage window is used. Timing uses OneFrame's frame clock. LibCombat's 2..200000 damage filters and shielded-damage event inclusion are retained.

This is a local estimate based on ESO-delivered events, not an authoritative server total. It can include other nearby players damaging the same known hostile target, just like a target-based aggregate. It cannot reconstruct events the client never receives. Results need not exactly match Combat Metrics because encounter lifecycle and classification have been reduced as described above.
