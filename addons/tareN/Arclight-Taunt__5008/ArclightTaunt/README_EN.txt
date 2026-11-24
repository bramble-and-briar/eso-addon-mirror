ARCLIGHT TAUNT 1.4.0
Modern Multi-Target Taunt HUD for The Elder Scrolls Online
Author: tareN
In-game contact: @uhtareN (PC/EU)

ABOUT
Arclight shows your own taunts from standard and Scribing skills, including
your pets' taunts. Enemies with the same name remain separate. Smooth
countdowns, target highlighting and boss warnings show what needs attention.

A small bar or circle at the crosshair shows your confirmed own taunt without
numbers. The indicator is off by default. Enable it under Crosshair.
An optional pale symbol can show when no own taunt is confirmed. It does not
prove the enemy is untaunted or aggro has changed; the symbol is off by default.
New setups start with a centered circle when enabled; the bar remains available.
The selected shape is remembered while off. Existing sizes and positions are
preserved. Both shapes can be positioned independently of the list.

Independent boss filters can limit the list or crosshair indicator to ESO bosses
and, in broader mode, strong enemies. Other taunts remain tracked and configured
boss warnings continue. Unlock position in Quick settings to drag either
visible display. Preview timers and combat tracking keep running.

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
Close ESO, replace the addon files, then start ESO again.
Keep live/SavedVariables/ArclightTaunt.lua to preserve your settings.
Optional cleanup: delete only AddOns/ArclightTaunt before extracting
the new folder. Old unused files can remain without affecting the addon;
this step only removes files left behind by copying over earlier versions.
/reloadui may not load new texture files added while the client was running.
Settings are account-wide and shared across megaservers. No combat history,
character progress or other server-specific data is stored.

SETTINGS
ESC > Settings > Add-ons > Arclight Taunt
- On first installation, a short chat tip points you to this menu. Start the list preview from Quick settings.
- Quick settings: two compact button rows for preview, pause, position lock, bar style, contrast and target highlight.
- Taunt list: visibility, pinning, size, spacing, columns and position.
- Boss warnings: warning test, banners, sounds, timing and position.
- Crosshair: indicator, preview, reference, size and placement.
- Appearance & text: bars, highlighting, animation, fonts and custom colors.
- Targets & markers: ESO markers, player targets, boss detection, names and skulls.
- Countdown & cleanup: countdown display, warning thresholds and row removal.

Position is locked by default. Unlock it to drag a visible list or crosshair
indicator, then lock it again to avoid accidental moves. Use a preview to place
a display outside combat; unlocking does not start or pause any preview.
Quick buttons show the current style or state; contrast and highlight are muted
when off. One click changes the setting, without opening a selection menu.

Show preview simulates a fight in the taunt list. Pause stops the timers and
keeps new enemies from appearing. Resume to pick up where you left off. The
enemy pool adapts to list capacity and shows staggered taunts. The preview does not create
boss warnings. A confirmed new own taunt ends active list, crosshair and warning
previews so the live information takes over.

Bright bar track changes the empty narrow-bar track; Tint near expiry colors
the row near its warning thresholds. These independent details apply only to
normal narrow bars. Full-row and high contrast preserve the saved preferences.

Keep expired taunts retains entries after their timers run out. Remove dead
enemies removes confirmed deaths regardless of that choice, including entries
already known dead when enabled. With death removal off, those rows remain
subject to the expiry preference. Combat end always clears the tracked list.

Under Crosshair, Show indicator preview runs a repeating countdown
through the selected urgency stages, independently of the list. It keeps running
while you move the indicator. The optional unconfirmed symbol appears after expiry
only when enabled.
Preview crosshair adds ESO's small or large crosshair as an alignment reference,
also in menus. The crosshair preview ends when settings close or combat begins;
the live indicator appears only during combat. Closing settings saves an active
drag without changing your position-lock preference.

Circle and bar remember size, thickness, track opacity and position separately.
The circle starts centered; the bar starts below the crosshair. Unlock position
to drag either shape, or use its exact horizontal/vertical values.
Thickness changes bar height or relative ring line weight. Reset placement
restores the selected shape's position. Reset crosshair settings restores its
appearance and position, keeping
activation, preview, boss filters and the other shape unchanged.
The general Defaults action resets both shapes and turns the indicator off.

COLORS & READABILITY
Optionally enable your own urgency colors in Custom colors at the bottom of
Appearance & text. They apply to the list, crosshair and boss banners.
Arclight colors remain the default; numeric text may be lightened for readability.

ESO target markers can appear beside names, separately from the boss skull.
Changes use direct identification or a uniquely matching active own taunt with
known start and end times. Uncertain matches leave the last observation intact;
reassigning a symbol clears its previous tracked owner. Changes on unseen enemies
need another observation. Arclight never places markers. Disable this display
under Targets & markers. Examples beside the option show the affected symbols.

Replacement icons from other addons are followed when supplied through ESO's
shared icon function. Changes confined to overhead visuals do not change the
list icon. Failed icon queries hide the symbol; the taunt timer continues.

BOSS WARNINGS
In the default palette, turquoise early warnings appear before a recognized boss taunt expires
(2.5 seconds by default). Red warns after expiration. Both can appear together;
each groups its own affected bosses. Re-taunting or a recognized death clears
the corresponding boss. Boss pinning puts expired bosses ahead of active ones.

Choose sound for expiration, early warning, both or neither. Early audio is off
by default, with Duel boundary warning selected; expiration uses Duel start.
Visible or pending expiration warnings take priority. Suppressed early sounds
are not queued or replayed after the expiration alert ends.

Test warning is at the top of Boss warnings. It shows early warning, expiration,
then both banners. The test samples the expiration banner even if its live
display is off. The early stage follows your settings, and only enabled sounds
play. Use Stop warning test to end the sequence.
Real warnings take priority over the demo. Hide the list to keep configured
boss banners and sounds without enemy rows. Preview can still show a hidden
list for configuration.

LANGUAGES
English, German, French, Spanish and Russian follow your ESO client language.
Other client languages use English. Your saved layout/media are unchanged.

GOOD TO KNOW
- Tracks ESO-reported taunt effects, not measured aggro. Expiration does not
  prove that the enemy has changed target.
- Player targets are excluded by default. Enable them under Targets & markers.
- Broader boss detection can also include strong non-boss enemies. Warnings for
  them are optional and off by default.
- The crosshair indicator confirms only your own taunts; other players' taunts
  are not tracked.
- Scribing support covers recognized taunt effects.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Using Arclight in your runs? We'd love to hear what you like and what could work
better. Even a short comment helps; you do not need to have found a bug.
Include your ability/morph or Scribing combination, client language, encounter,
observed behavior and any Lua error when reporting a problem. Screenshots help
with visual issues.

CREDITS / TRANSPARENCY
- Early alpha idea: Untaunted by Solinur:
  https://www.esoui.com/downloads/info1475-Untaunted.html
- Crosshair idea: Dryzler's Taunt Helper by dryzler.elder-geek.net:
  https://www.esoui.com/downloads/info1755-DryzlersTauntHelper.html

Developed by tareN with AI-assisted Lua programming.
Boss skull and promotional artwork were AI-generated. LibAddonMenu-2.0 and
LibMediaProvider are independent third-party projects installed separately.
Arclight Taunt is not affiliated with ZeniMax Online Studios.
