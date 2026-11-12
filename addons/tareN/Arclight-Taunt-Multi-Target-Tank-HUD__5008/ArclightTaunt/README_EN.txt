ARCLIGHT TAUNT 1.2.0
Modern Multi-Target Taunt HUD for The Elder Scrolls Online
Author: tareN
In-game contact: @uhtareN (PC/EU)

ABOUT
Arclight shows your own taunts from standard and Scribing skills, including
your pets' taunts. Enemies with the same name remain separate. Smooth
countdowns, target highlighting and boss warnings show what needs attention.

A small bar or circle at the crosshair shows your confirmed own taunt without
numbers. Empty gray means no own taunt is confirmed; it does not prove lost
aggro. The indicator is off by default; enable it under Crosshair taunt status.
New setups start with a centered circle when enabled; the bar remains available.
The selected shape is remembered while off. Existing sizes and positions are
preserved. Both shapes can be positioned independently of the list.

Independent boss filters can limit the list or crosshair indicator to ESO bosses
and, in broader mode, strong enemies. Other taunts remain tracked and configured
boss warnings continue. Move displays freezes the preview so you can drag
both displays separately; Move this indicator edits just the crosshair display.

Reduce animations stops decorative motion while countdowns, warnings and
sounds stay active.

INSTALLATION
Install these required libraries separately; they are not bundled:
- LibAddonMenu-2.0 r43 or newer:
  https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html
- LibMediaProvider r39 or newer:
  https://www.esoui.com/downloads/info56-LibMediaProvider.html

Extract the ArclightTaunt folder into:
Documents/Elder Scrolls Online/live/AddOns/
The manifest must be at AddOns/ArclightTaunt/ArclightTaunt.txt.

UPDATING
Replace the addon folder and keep your SavedVariables to preserve your settings.
Settings are account-wide and shared across megaservers. No combat history,
character progress or other server-specific data is stored.

SETTINGS
ESC > Settings > Add-ons > Arclight Taunt
- Quick settings: show/pause preview, move displays and choose preview enemies.
- List & layout: visibility, size, spacing, columns and position.
- Appearance & readability: bars, backgrounds, contrast and target highlighting.
- Text & countdown: fonts, text size, countdown display and warning thresholds.
- Crosshair taunt status: style, visibility, appearance and placement.
- Bosses: submenus for warnings/sounds and enemy detection/markings.
- Tracking: player targets, death removal and expired entries.

Preview shows varied enemies and staggered taunts. Pause it while adjusting the
HUD; resume continues from the same point. The list preview itself does not
create boss warnings.

Under Crosshair taunt status, Show indicator preview runs a repeating countdown
through turquoise, yellow and red, independently of the list. It keeps running
while you move the indicator.
Preview crosshair adds ESO's small or large crosshair as an alignment reference,
also in menus. Preview and placement end when settings close or combat begins;
the live indicator appears only during combat.

Circle and bar remember size, thickness, track opacity and position separately.
The circle starts centered; the bar starts below the crosshair. Use Move this
indicator or the exact horizontal/vertical values to place either shape.
Thickness changes bar height or relative ring line weight. Reset crosshair
settings restores only the selected shape's appearance and position, keeping
activation, preview, boss filters and the other shape unchanged.
The general Defaults action resets both shapes and turns the indicator off.

WARNINGS
Turquoise early warnings appear before a recognized boss taunt expires
(2.5 seconds by default). Red warns after expiration. Both can appear together;
each groups its own affected bosses. Re-taunting or a recognized death clears
the corresponding boss. Boss pinning puts expired bosses ahead of active ones.

Choose sound for expiration, early warning, both or neither. Early audio is off
by default, with Duel boundary warning selected; expiration uses Duel start.
Red/live-pending expiration warnings take priority. Suppressed early sounds
are not queued or replayed after red ends.

Test warning demonstrates early, expiration, then turquoise below red. It
follows your warning/audio settings; without early warnings it tests red only.
Real warnings take priority over the demo. Hide the list to keep configured
boss banners and sounds without enemy rows. Preview and drag mode can still
show a hidden list for configuration.

LANGUAGES
English, German, French, Spanish and Russian follow your ESO client language.
Other client languages use English. Your saved layout/media are unchanged.

GOOD TO KNOW
- Tracks ESO-reported taunt effects, not measured aggro. Expiration does not
  prove that the enemy has changed target.
- Player targets are excluded by default; enable them under Tracking.
- Broader boss detection can also include strong non-boss enemies. Warnings for
  them are optional and off by default.
- The crosshair indicator confirms only your own taunts; other players' taunts
  are not tracked.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Include your ability/morph or Scribing combination, client language, encounter,
observed behavior and any Lua error. Screenshots help with visual issues.

CREDITS / TRANSPARENCY
- Early alpha idea: Untaunted by Solinur:
  https://www.esoui.com/downloads/info1475-Untaunted.html
- Crosshair idea: Dryzler's Taunt Helper:
  https://www.esoui.com/downloads/info1755-DryzlersTauntHelper.html

Developed by tareN with AI-assisted Lua programming.
Boss skull and promotional artwork were AI-generated. LibAddonMenu-2.0 and
LibMediaProvider are independent third-party projects installed separately.
Arclight Taunt is not affiliated with ZeniMax Online Studios.
