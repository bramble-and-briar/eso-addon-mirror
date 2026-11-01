ARCLIGHT TAUNT 1.0.3
Modern Multi-Target Taunt HUD for The Elder Scrolls Online
Author / Maintainer: tareN

ABOUT
Arclight Taunt tracks recognized active taunt effects on multiple enemies in
one compact, customizable display. Colored countdowns, full or narrow progress
bars, target focus, boss indicators and optional boss early/expiration warnings
are designed to help ESO tanks stay oriented during busy encounters.

REQUIRED LIBRARIES (INSTALL SEPARATELY)
- LibAddonMenu-2.0 r43 or newer:
  https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html
- LibMediaProvider:
  https://www.esoui.com/downloads/info56-LibMediaProvider.html
These libraries are required but are not included in this download.

INSTALLATION
1. Extract the ArclightTaunt folder into:
   Documents/Elder Scrolls Online/live/AddOns/
2. Verify the file layout is:
   .../AddOns/ArclightTaunt/ArclightTaunt.txt
3. Install both libraries above, separately (for example through Minion).
4. Start ESO or use /reloadui, then open:
   ESC > Settings > Add-ons > Arclight Taunt

UPDATING
Replace the previous ArclightTaunt folder with the new one. Preserve your
SavedVariables folder; it contains your personal configuration and HUD position.

DEFAULT SETTINGS (NEW INSTALLS)
- HUD position X=1507, Y=370; HUD scale 125%, screen-fit enabled.
- One column with up to 10 visible targets, ordered by remaining time.
- Turquoise / yellow at 7 s / red at 4 s, customizable thresholds.
- Narrow Signal progress bar; full-row progress available as an option.
- Boss early warning enabled at 2.5 s; expiration warning enabled.
- Boss expiry warning audio enabled with Killing blow; immunity/stack display disabled.
- One-time introductory chat tip for new users.

LANGUAGES
English is the original language and fallback. German, French, Spanish,
and Russian translations are included. The add-on automatically uses the
ESO client language (en/de/fr/es/ru); no language option is necessary.
Other languages (including simplified Chinese) use English automatically.
Language changes do not alter saved layout, media or sound settings.

KNOWN LIMITATIONS
- Tracking currently recognizes taunt effect IDs 38254 and 38541. Other skill
  configurations, including all possible Scribing taunts, have not been
  independently verified. Do not assume every taunt ability is supported.
- A taunt expiring does not prove that enemy aggro has changed.
- Some elite enemies can be classified as bosses by difficulty-based detection.
- Optional immunity and taunt stack indicators are experimental and depend on
  reliable target matching. No group data synchronization is provided.
- HUD target highlighting uses observed player-owned taunt timing or an
  identity directly supplied by an effect event. Pet/group target focus and
  reticle death cleanup require a direct event identity; uncertain timer
  matches never remove another tracked entry. There is no separate crosshair HUD.
- Unavailable media use temporary display fallbacks while keeping the saved
  selection. A selected medium can restore when its provider registers it;
  reopen settings to refresh the available media lists.

BOSS SETTINGS
Warnings and detection share one Bosses section, with headings for warning
appearance and detection. Test warning plays the selected sound only
when warning audio is enabled. Sound is tested together with the banner; there
is no separate sound-preview button. Preview audio does not consume the live cooldown.
The red expiry banner and the smaller turquoise early warning occupy separate
fixed areas, with the early warning below the red banner's position. Both can
appear together and group their bosses independently. Live early entries clear
on taunt expiry, re-taunt or recognized death; they do not wait behind red alerts.
Their lifetime follows the active taunts in the early-warning window. The display
duration option controls real red warnings and standalone previews. Both areas
share the position and opacity options. Test warning shows red first and adds
turquoise 1.5 seconds later only when early warnings are enabled. In this combined
test, red stays visible for at least 2 seconds to demonstrate overlap without
changing the saved duration. Early warnings are always silent.
Turquoise joining visible red glides downward from behind it through a clipped
reveal. Alone, turquoise fades in and out. Red joining an existing early warning
does not restart it. Fades blend smoothly when groups grow, and very short early
warnings shorten their entrance. Resets, switches and real warnings cancel pending
test samples rather than leaving a delayed sample to appear later.
The two warning tests share an equal-width button row directly after the
early-warning settings. The welcome and language/font tests share another row at the bottom
of Tracking & experiments. Row background remains optional, with no texture
selected by default; existing custom background choices are preserved.
The five main settings headings use the normal white style. Arclight accents inside
the sections distinguish champagne boss detection, red/turquoise warnings,
blue target focus and yellow experimental
indicators. Ordinary settings and test actions keep a quieter appearance.
Pinned bosses with expired taunts appear before pinned bosses with active taunts;
expired entries still follow the selected removal rules. Existing sound choices
are preserved when updating; Killing blow applies to new or restored defaults.

WEBSITE AND FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntModernTankHUD.html
The add-on settings panel provides Website and Feedback links.
Both lead to the official ESOUI page (leave feedback in the comments).

SUPPORT
If a taunt is missed, please report the ability and morph, client language,
encounter, observed behavior and any Lua error in the ESOUI comment section.

CREDITS / TRANSPARENCY
Created and maintained by tareN. Features and presentation have been tested
extensively in live ESO gameplay, including DLC dungeon encounters, with
additional automated Lua regression tests. AI-assisted Lua programming was
used under the direction of tareN. The addon is not affiliated with ZeniMax
Online Studios. LibAddonMenu-2.0 and LibMediaProvider are independent projects
installed separately; their source files are not distributed in this archive.
