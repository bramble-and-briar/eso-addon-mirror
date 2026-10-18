Sora Sorc Reticle Tracker 0.5.1 TEST
====================================

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

The back-bar timer is intentionally text-only: no skill icon is shown.

It appears only when:
1. the matching Maelstrom Arena weapon is equipped on the backup weapon bar,
2. the matching ground skill is slotted on the backup bar,
3. that skill currently has a native action-slot effect timer running.

Supported weapon/skill pairs:
- Merciless Charge / Perfected Merciless Charge:
  Stampede
- Crushing Wall / Perfected Crushing Wall:
  Elemental Blockade or Unstable Wall of Elements, including elemental variants
- Thunderous Volley / Perfected Thunderous Volley:
  Endless Hail

Timer color:
- More than 5 seconds: white
- 5 seconds or less: gold
- 2 seconds or less: red

The Maelstrom timer is positioned below the reticle by default and can be moved independently.

Settings
--------
Requires LibAddonMenu-2.0.

Crystal:
- icon size
- timer text size
- move / reset

Bound:
- icon size
- stack text size
- move / reset

Maelstrom:
- master on/off
- Stampede on/off
- Blockade / Unstable Wall on/off
- Endless Hail on/off
- timer text size
- move / reset

Commands
--------
/ssrt crystal
/ssrt bound
/ssrt maelstrom
/ssrt stop
/ssrt reset

Development note
----------------
This addon was created with AI assistance. Code was reviewed and tested in game by sora0v0.
