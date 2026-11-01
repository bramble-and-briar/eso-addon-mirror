Sora Sorc Reticle Tracker 1.0.2
================================

AI assistance disclosure
------------------------
This addon was developed with AI assistance. The code was reviewed against the
current ESO API / ESOUI source and tested in game by sora0v0.

A compact reticle-side Sorcerer tracker for Crystal Fragments, Bound Armaments,
and optional Maelstrom Arena back-bar ground-skill timers.

Crystal Fragments
-----------------
- ESO Armory Build icon 20.
- Cyan tint and glow.
- Proc timer centered on the icon.
- Works while Crystal Fragments is on the inactive weapon bar.
- Default size: icon 78 / text 35.

Bound Armaments
---------------
- ESO Armory Build icon 39.
- Purple tint and glow.
- Stack number centered on the icon.
- Stack colors:
  1-2 white
  3 gold
  4+ red
- Default size: icon 94 / text 35.

Maelstrom back-bar timer
------------------------
Optional feature, enabled by default.
The timer is intentionally text-only.

Supported weapon/skill pairs:
- Merciless Charge / Perfected Merciless Charge: Stampede
- Crushing Wall / Perfected Crushing Wall:
  Elemental Blockade or Unstable Wall of Elements
- Thunderous Volley / Perfected Thunderous Volley: Endless Hail

Timer colors:
- More than 5 seconds: white
- 5 seconds or less: gold
- 2 seconds or less: red

Settings
--------
Requires LibAddonMenu-2.0 r43 or newer.

All three displays have independent position/size controls.
The Maelstrom section also has a master toggle and per-weapon toggles.

Commands
--------
/ssrt crystal
/ssrt bound
/ssrt maelstrom
/ssrt stop
/ssrt reset

Credits / references
--------------------
ESOUI source and ESO API documentation were used to validate API/event behavior.
Crystal Fragments proc ID 46327 and Bound Armaments stack ID 203447 were
cross-checked against EZOCombat by Zuriplayer. No third-party addon code is
bundled or copied.
