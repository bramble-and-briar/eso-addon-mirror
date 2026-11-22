# Execute Blocker

**Author:** O-Range  
**Version:** 2.4.0  
**Category:** Combat / Utility

---

### Short Description
Prevents casting of execute abilities when the target is above a configurable health threshold. Soft visual flash feedback. Uses LibExecuteSkills. Supports Nightblade, Templar, Sorcerer, 2H, Dual Wield, Bow and Warden Guardians.

---

### Full Description

Execute Blocker stops you from wasting your execute skills too early.

When you press an execute ability and the reticle target is still above the health percentage you set, the cast is blocked. A soft, fast-fading red-orange flash gives you clear but non-intrusive feedback that the ability was held back.

This version uses the shared **LibExecuteSkills** library for the execute skill database.

#### Features
- Master enable / disable
- Per-skill on/off and independent threshold (5–100 %)
- Option to also block when you have no living hostile target
- Optional soft fade-in / fade-out flash (very quick, low opacity)
- Correct front / back bar handling
- Account-wide settings via LibAddonMenu-2.0
- Powered by LibExecuteSkills

#### Supported Skills
- Nightblade – Assassin’s Blade, Killer’s Blade, Impale
- Templar – Radiant Destruction, Radiant Oppression, Radiant Glory
- Sorcerer – Mages’ Fury, Mages’ Wrath, Endless Fury
- Two-Handed – Reverse Slash, Executioner, Reverse Slice
- Dual Wield – Whirlwind, Whirling Blades*, Steel Tornado
- Bow – Poison Injection
- Warden – Feral / Eternal / Wild Guardian*

\* Whirling Blades and the three Warden Guardian ultimates are disabled by default (tooltips explain why).

#### Requirements
- LibAddonMenu-2.0 (≥ 43 recommended)
- LibExecuteSkills (≥ 1.1.0)

#### Installation
Extract into your `AddOns` folder and enable in-game.  
Configure under **Settings → Addon Settings → Execute Blocker**.

---

### Changelog

**2.4.0**
- Integrated LibExecuteSkills library for the execute skill database
- Greatly reduced hardcoded skill data – core information now comes from the shared library
- Only minimal local overrides remain (default thresholds, enabled state, special tooltips)
- Updated manifest and documentation

**2.3.0**
- Fixed hotbar category handling for correct ability detection on both bars
- Added soft animated flash feedback when a cast is blocked
- Author name set to O-Range
- Code cleanup and improved settings tooltips

Enjoy cleaner, more intentional executes!