# Execute Blocker

**Author:** O-Range  
**Version:** 2.6.0  
**Category:** Combat / Utility

---

### Description
Prevents casting of execute abilities when the target is still above a configurable health threshold.

Uses the shared **LibExecuteSkills** library for the skill database. Ranked ability IDs (Executioner etc.) are automatically detected by name.

#### Features
- Master enable / disable
- Per-skill on/off and independent threshold (5–100 %)
- Option to also block when you have no living hostile target
- Account-wide settings
- Clean, minimal code – no visual effects

#### Supported Skills
- Nightblade – Assassin’s Blade, Killer’s Blade, Impale
- Templar – Radiant Destruction, Radiant Oppression, Radiant Glory
- Sorcerer – Mages’ Fury, Mages’ Wrath, Endless Fury
- Two-Handed – Reverse Slash, Executioner, Reverse Slice
- Dual Wield – Whirlwind, Whirling Blades*, Steel Tornado
- Bow – Poison Injection
- Warden – Feral / Eternal / Wild Guardian*

\* Whirling Blades and the three Warden Guardian ultimates are disabled by default.

#### Requirements
- LibAddonMenu-2.0 (≥ 43)
- LibExecuteSkills (≥ 1.1.0)

#### Installation
Extract into your `AddOns` folder and enable in-game.  
Configure under **Settings → Addon Settings → Execute Blocker**.

---

### Changelog

**2.6.0**
- Complete rewrite
- Removed flash visual entirely
- Cleaner structure and variable naming
- Same reliable CanUseActionSlots blocking path
- Ranked ability ID resolution retained

**2.5.x**
- Various reliability and flash fixes (flash later removed)

**2.4.0**
- Integrated LibExecuteSkills