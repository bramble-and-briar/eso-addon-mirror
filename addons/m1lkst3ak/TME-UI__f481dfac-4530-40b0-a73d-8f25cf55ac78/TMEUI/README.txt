TME UI 1.0.1 | Trash Man Enterprises | PS5
A standalone combat interface extracted from ESO Arsenal 0.5.8.

RETAINED
- Original obsidian-and-gold dual action bars, active/inactive slot styling,
  ability durations, stack counts, cooldown shading, cost dimming and ultimate glow.
- Health, Magicka and Stamina resource meters; optional curved side meters,
  percentage / numerical display and low-resource pulse.
- Native buff and synergy prompt placement and ready-check overlap protection.
- Optional transient low-resource, crowd-control and repeated-damage alerts.
- Independent positioning/scaling, preview, reset, and native bar visibility options.

REMOVED
- Gold Standard and all economy/loot valuation tracking and HUDs.
- Dungeon Rating / Dungeon Buddy, BG Rating / ESOFantasy, Cyrodiil Mercenary.
- Inventory and personal bank replacements and their keybinds (use OnePack).
- Explorer, research, mount training, capacity reminders, encounter reports,
  career profiles and scoring. No HC, survival or progression functionality.

SETTINGS
Requires LibHarvensAddonSettings (the console library may be distributed as
LibVotans, depending on the Bethesda.net listing). In the game, open Start >
Options > Add-Ons > TME UI. Do not enable two copies of the same library.
Settings persist account-wide in TMEUISaved. This is a fresh settings file;
old Arsenal layouts are not imported. Disable ESO Arsenal / TMENexus before
activating TME UI to avoid overlapping HUDs and native control conflicts.
OnePack and standalone analytics add-ons are not dependencies.
Preview lasts 20 seconds; it does not hide native bars or relocate native prompts.

TESTED LOCALLY
Lua syntax, mocked settings registration and duplicate protection, native bar
suppression and restoration, gameplay/menu visibility, preview timeout, master
switch, native action bar option, placement/reset, ability duration and alert
visibility, deactivation cleanup. Live PS5 testing is still required.

LIVE TEST CHECKLIST
1. Load with the required library; confirm Add-Ons > TME UI appears.
2. Check action bars on both weapon bars, cooldowns, timers and ultimate glow.
3. Verify resources, curved side meters, numbers and low resource alerts.
4. Open/close Start, inventory, map and other menus; verify native UI restores.
5. Check synergy and ready-check visibility; disable relocation if necessary.
6. Change sliders, preview, reset; reload and confirm settings persist.
7. Check OnePack and other standalone addons for HUD overlaps.

NEW IN 1.0.1: MANUAL CAMERA CONTROLS
Add-Ons > TME UI > Camera provides native camera distance (0-100%,
corresponding to 0-10 engine units) and third-person FOV (35-65). Zero
distance can enter first person. Maximum third-person view sets both to
the documented maximum. This does not extend ESO's hard camera cap.
The sliders read native settings, change them only on explicit input, and
report if readback differs. No persistent override or polling; normal
controller zoom, other camera addons and game camera states remain in control.
Native camera settings are stored by ESO, not the HUD layout saved variables.
The layout reset button leaves camera alone; the library's global defaults
may restore the camera values captured when the settings panel registered.
No new dependency. On clients without readable camera settings, unavailable
controls are omitted. If a maximum-view button is present but a setting is
not supported, it applies only the supported setting.

LOCAL TESTS: Lua syntax, mocked settings registration and live readback,
maximum view, clamps, rejected writes, unsupported APIs and no writes on load.
LIVE: verify camera controls on PS5, normal controller zoom after setting,
first-person switching, zone changes and compatibility with Tamriel Unbound.

NEW IN 1.0.3: OPTIONAL ETHEREAL RESOURCE SKIN
The original v1.0.1 resource renderer is the default. Enable Use ethereal
resource skin under Resource meters for the alternate wispy bars. Both
styles support curved side meters, positioning, numbers and low-resource
pulse behavior. The new opt-in setting defaults off even after upgrading
from v1.0.2. Other settings are retained. No new dependencies.

NEW IN 1.0.4: TRUE ETHEREAL RESOURCE RENDERER
The alternate skin now uses transparent spectral beams derived from the original
HarvestAura.dds artwork. No underlying solid bar, border, or segmented track.
Blue Magicka, green Stamina, red Health; crop-based depletion and glowing tips.
Original skin remains the default. Switch with the existing ethereal toggle.
Low resource alerts now use separate title and detail labels with a visible gap.
Default Alert X=0, Y=415. Existing old default (0,-220) migrates once; custom
positions are retained. Live PS5 visual/texture validation remains required.

1.0.5: Spectral visibility fix. All custom art uses the same legacy uncompressed
32-bit BGRA DDS header and channel masks as the original HarvestAura.dds. New
asset names avoid reuse of previous texture cache keys. Explicit alpha blend
and white tint; resource controls share the original resource parent. No
change to curve geometry, normal skin, saved positions or alert defaults.
Skin-specific rendering errors restore native bars and fall back to original
on the next update. Console asset loading still requires live verification.

1.0.7: Restore the 1.0.5 resource-to-texture mapping; correct missing Magicka
arc introduced by the 1.0.6 name swap. Health and Magicka now use neutral
textures tinted by native SetColor, avoiding reliance on red/blue DDS channel
interpretation. Stamina art is unchanged. New cache keys, same DDS header,
alpha and geometry. Local Lua syntax and mocked asset routing validated;
actual PS5 rendering remains to be tested.
