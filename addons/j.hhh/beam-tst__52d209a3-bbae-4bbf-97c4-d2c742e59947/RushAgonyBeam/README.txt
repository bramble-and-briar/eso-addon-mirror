Rush of Agony Beam for PS5 - standalone 1.2.0

ONLY PvP: Cyrodiil, Imperial City incl. sewers, Battlegrounds.
Local equipment detection uses JH original LibEquipmentBonus unmodified.
LibSetDetection v5.0 INCLUDED, loaded before the beam.
Remote beams REQUIRE LibGroupBroadcast installed and enabled on every participating player.
LibGroupBroadcast was NOT in the uploaded library archive and is NOT bundled here.
Without it the local beam works, but group set data cannot be transmitted.

This version draws the beam position every rendered frame rather than once per 100ms.
Beam position is derived directly from GetUnitRawWorldPosition without interpolation.
Networked group coordinates can still have ESO engine latency/jitter; PS5 runtime testing required.

Install RushAgonyBeam/ as a separate ESO addon. Do NOT copy into My UI.
Manifest: RushAgonyBeam.addon (not .txt).

PS5 geometry fix 1.2.1:
- Camera-facing beam yaw updated each frame; width slider 100-500 unchanged.
- Height 400 local units, centred 20000 cm above feet, giving a ground-level lower edge.
- Movement update, group status, PvP restriction and equipment logic unchanged.
- In-game 3D rendering still requires console validation.

Version 1.2.2: Helligkeitsregler 20-200 Prozent. Ueber 100 Prozent wird eine zweite deckungsgleiche Leuchtschicht eingeblendet. Beam-Geometrie und Breitenregler unveraendert.

Version 1.2.3: Option Eigenen Beam anzeigen (Standard: Ein). Nur lokale Darstellung, der Set-Status wird davon nicht geaendert. Andere Spieler benoetigen LibGroupBroadcast/LibSetDetection fuer die Erkennung.
