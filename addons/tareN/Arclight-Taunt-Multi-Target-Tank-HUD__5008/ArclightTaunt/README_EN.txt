ARCLIGHT TAUNT 1.1.1
Modern Multi-Target Taunt HUD for The Elder Scrolls Online
Author: tareN
In-game contact: @uhtareN (PC/EU)

ABOUT
A compact overview of your own taunts from standard and Scribing skills,
including your pets' taunts. Smooth countdown bars, target highlighting,
boss indicators and separate early/expiration warnings keep priorities readable.
Enemies with identical names remain separate.

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
Replace the addon folder and keep your SavedVariables. Personal layout, media
and supported sound selections are preserved. Old row-height percentages are
converted once to extra height above the readable minimum. New installations
use 115% HUD scale, Signature bars and 72% background opacity.
Settings are account-wide and shared across megaservers. No combat history,
character progress or other server-specific data is stored.

SETTINGS
ESC > Settings > Add-ons > Arclight Taunt
- Quick settings: show and pause the list preview; enter drag mode.
- List & layout: visibility, size, width, row height, spacing, one/two columns,
  mirroring, position and boss pinning. Active taunts sort by remaining time.
- Design & readability: narrow/full-row display, optional high contrast,
  Subtle/Strong current-target highlighting, fonts, bar textures and countdown thresholds.
- Bosses: boss detection, indicators, warning timing, appearance and sound.
- Tracking & tests: player-target tracking and the welcome/language-font tests.

The preview starts with several staggered timers, adds and re-taunts enemies
irregularly, and chooses varied dungeon/trial names each cycle. Pause freezes
timers, arrivals and focus; resume continues from the same point. Ending the
preview clears its pause. The list preview itself does not create boss warnings.

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
- Tracks ESO-reported taunt effects (IDs 38254 and 38541), not measured aggro.
  Expiration is not proof that the enemy has changed target.
- Player targets are excluded by default; enable them under Tracking & tests.
- Broader boss detection can include strong non-boss enemies. Warnings require
  an officially recognized boss unless alerts for classified elites are enabled.
- HUD focus uses direct event identity or a unique own-taunt timing match.
  Uncertain timer matches never authorize removing another target. There is
  no separate crosshair HUD or other-player/group-taunt display.
- Unavailable media temporarily fall back while keeping the saved choice.
  Legacy row backgrounds are preserved, but their selector has been removed.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Include your ability/morph or Scribing combination, client language, encounter,
observed behavior and any Lua error. Screenshots help with visual issues.

CREDITS / TRANSPARENCY
Early alpha concept inspired by Untaunted by Solinur:
https://www.esoui.com/downloads/info1475-Untaunted.html
AI-assisted Lua programming under the direction of tareN. Features have been
tested in live ESO gameplay, including DLC dungeons, with automated regression
tests supporting development. These tests do not reproduce the game client.
Boss skull and promotional artwork were AI-generated. LibAddonMenu-2.0 and
LibMediaProvider are independent third-party projects installed separately.
Arclight Taunt is not affiliated with ZeniMax Online Studios.
