MountSwap 0.8.11
Author: ShadowStrikerr

INSTALL / UPDATE
1. Exit ESO. Privately back up existing MountSwap SavedVariables and addon files.
2. Extract the ZIP's MountSwap folder into your active ESO AddOns folder.
   Correct layout: AddOns/MountSwap/MountSwap.txt (no extra nested MountSwap).
3. Keep SavedVariables outside the addon folder; never replace them from a ZIP.
4. Enable MountSwap. Disable the older SteadyMount prototype if installed.

USE
/ms opens the dashboard, or settings when dashboard mode is OFF.
Click M1-M4 or S1-S4 to choose an unlocked mount in the corresponding picker.
Saving a favorite does not summon it. Use selects it; your normal mount key rides.
Manage mount categories provides Review/manual fallback when metadata is missing.
Passenger requests are player-triggered and consider eligible group members only.

/m1-/m4 select Multi-Rider favorites; /s1-/s4 select Single-Rider favorites.
Customize these and /ms in settings; conflicts are rejected. Reset restores
available defaults. Original /mountswap commands stay usable.
/mountswapr selects Random; /mountswapp requests a passenger seat.
/mountswap settings opens settings; /mountswap debug prints technical diagnostics.

CONTROLLER
PC gamepad: D-pad and left stick move focus, native hints show available actions,
shoulders change banks and triggers page applicable lists. Settings reuse the
keyboard definitions. Text entry uses native helpers or keyboard fallback.
Assign the separate Open MountSwap (controller) action yourself if wanted.
MountSwap does not assign or overwrite player bindings. Input releases on close,
mode changes and text entry. Enter/Escape mode switching is normal ESO behavior.

DEPENDENCIES
None required. LibAddonMenu-2.0 is optional for keyboard Settings > AddOns;
r43 is tested/recommended. libAddonKeybinds and Votan's Keybinder are separate
optional keybinding integrations. Install optional addons separately. Optional
manifest entries provide load order, not enforced numeric minimum versions.

LANGUAGES / DATA
English, German, French, Spanish, Russian, Simplified Chinese and Japanese.
Automatic follows ESO; unsupported languages use English. Manual selection
requires Reload UI. ESO provides mount names in its own client language.
Existing favorites, custom/disabled commands, OFF settings and account/server
separation are preserved; SavedVariables identity/schema are unchanged.

TEST STATUS
The author reported successful PC gamepad navigation, confirmed the 0.8.7
Escape/menu fix and accepted the final English 0.8.9 spacing screenshot.
cover classification, settings, controller lifecycle, data preservation, seven
dictionaries and three text sizes. They do not certify every controller, text
entry variant or localized layout. Native-speaker and all-language live rendering
review remain unverified. Mac and console are not claimed tested.

AI / CREDITS
Code and documentation generated with OpenAI Codex assistance; translations are
AI-drafted. Crown Crate Codex by ShadowStrikerr is the user-authorized workspace
reference. Full attribution/source-license scope is in CREDITS.txt.
AI disclosure, existing credits and the following notice were already in the
package; this README.txt also carries them for installation reference.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc.
or its affiliates. The Elder Scrolls® and related logos are registered
trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other
countries. All rights reserved.

FINAL 0.8.9 STATUS
The final English 0.8.9 dashboard screenshot was reviewed and accepted: compact direction hints have clear gaps and no visible clipping. This is not certification of every localized client or text size.
The optional combined settings gallery overview is AI-assisted and is labelled
as a presentation composite. Original settings screenshots are also available.

Final submission materials: ESOUI-Description.txt contains the approved public
wording. The separate versioned ESOUI-Post-BBCode file uses Crown Crate Codex
formatting. Detailed test counts and audit evidence remain in verification
documents; the listing retains player-facing limitations and source credits.
AI disclosure and credits were already present; their presentation was revised.
