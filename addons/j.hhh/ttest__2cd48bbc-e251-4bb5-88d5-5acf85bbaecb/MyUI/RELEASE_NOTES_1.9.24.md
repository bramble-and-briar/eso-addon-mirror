# Satuve Xbox UI 1.9.24

- Fixes PlayerFrame resource labels sometimes retaining `Health`, `Magicka`, `Stamina` and `Pct%` after their controls were rebuilt.
- The six PlayerFrame resource labels now start empty instead of displaying construction placeholders.
- `BUI.Frames:SetupPlayer()` now forces one pass through the existing live resource updater for health, magicka and stamina.
- The regular 100 ms resource refresh keeps its unchanged-value fast path; resource calculations and live event handling are unchanged.
- RaidFrame persistence, Frame Editor positioning, Combat Log, Sidebar, Custom Bar, Quick Menu and controller navigation are unchanged.
