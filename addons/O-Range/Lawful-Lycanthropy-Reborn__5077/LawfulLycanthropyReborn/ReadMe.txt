Lawful Lycanthropy Reborn
Version 1.0.0

Author: O-Range

Description
-----------

Lawful Lycanthropy Reborn helps prevent accidental criminal
Werewolf (Lycanthropy) spellcasting in justice-enabled zones.

The addon automatically blocks verified criminal Werewolf
abilities while out of combat, helping prevent unwanted
bounties while traveling through cities and other protected
areas.

When combat begins, all protected abilities become available
normally. Once combat ends, protection is automatically
restored.

Features
--------

- Blocks verified criminal Werewolf abilities
- Automatically disables protection during combat
- Automatically re-enables protection when combat ends
- Justice-zone-aware operation
- Enable/Disable toggle
- Optional alert notifications
- Account-wide settings
- Works for any class (Werewolf is a World skill line)

Protected Abilities (Initial Focus)
-----------------------------------

Werewolf Transformation (Ultimate)
- Base Transformation
- Pack Leader morph
- Werewolf Berserker morph

Pounce Family
- Pounce
- Brutal Pounce
- Feral Pounce
(+ associated Carnage forms where separate IDs exist)

Hircine's Bounty Family
- Hircine's Bounty
- Hircine's Fortitude
- Hircine's Rage

(Expand the list in the Lua file with additional verified CRIMINAL ACT skills as needed.)

Important Note on Ability IDs
-----------------------------

Ability IDs can change with major updates (especially the 2026
Werewolf combat refresh). The initial list includes the historically
known base Transformation ID (32455). 

You (or future updates) should verify and expand the BLOCKED_ABILITIES
table with current live IDs using in-game tools, data dumps, or
community resources.

Requirements
------------

- LibSkillBlocker
- LibAddonMenu-2.0

Installation
------------

1. Install the required libraries.
2. Extract the addon folder into:
   Documents\Elder Scrolls Online\live\AddOns
3. Enable the addon from the ESO AddOns menu.
4. Configure settings through:
   Settings -> Addon Settings -> Lawful Lycanthropy Reborn

Version History
---------------

Version 1.0.0
- Initial release
- Core blocking logic for criminal Werewolf skills
- Settings panel with enable/disable and alert toggles
- Combat exemption and justice-zone detection
- Account-wide SavedVariables

Thank You
---------

This addon was created as a companion to Lawful Necromancy Reborn
to solve the same problem for Werewolf players:
prevent accidental criminal casting while allowing normal combat gameplay.

Feedback, bug reports, verified ability ID updates, and suggestions
are always welcome.