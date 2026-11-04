Jesus de Platre v0.8.7 — Hotfix
Fixed a startup Lua error caused by a leftover call to the removed RecordTargetSample function.
Gold donations: @Evokation, PC NA.

Jesus de Platre - Cyber Taunt Reticle + Multi-Taunt v0.8.5
Author: Jesus de Platre

INSTALL
Replace the existing JesusDePlatre_PrivateMarker directory in
Documents/Elder Scrolls Online/live/AddOns/ with this directory.
Do not keep two copies. Reload the UI (/reloadui).

COMMANDS (help is OPT-IN; no startup chatter)
/jdptaunt help     Multi-enemy taunt tracker and move/lock controls
/jdptaunt demo     Three example enemy entries
/jdptaunt demo off
/jdptaunt lock off  Unlock drag handle
/jdpcross help     Cyber reticle and its positioning/options
/jdpcross demo green
/jdpcross demo off
/jdpmarker help    Optional classic HUD/target health bar indicator
/jdpdonate         Optional in-game gold donation instructions

ABOUT
Displays taunt indicators and countdowns for your reticle target and
tracked combat targets. Green = yours, blue = other player's (when
known), red = expired / no taunt, yellow = uncertain owner.
Some combat events do not expose a reliable owner or unitId; the
tracker avoids claiming certainty in such cases.

ESOUI REVIEW CHANGES v0.8.5
- Settings use ZO_SavedVars NewAccountWide with GetWorldName profile;
  prevents one account/server's config overwriting another's.
- Removed experimental 3D marker and diagnostic protected calls.
  /jdpmarker world and /jdpmarker probe are discontinued.
- Removed loaded/version/info chat spam; help only by command.
- Reduced countdown/alert UI refreshes from 100ms to 250ms;
  target changes and taunt events are separately registered.
  Periodic updates remain solely for countdowns and expirations,
  which cannot update visually from events alone.
- No automatic gold mailing; the user manually sends mail.
- Manifest targets ESO API 101051.

IMPORTANT SAVED-SETTINGS CHANGE
Older versions saved flat global tables without server/account separation.
New settings therefore start from defaults per account/server instead of
silently importing potentially mixed older values. Reposition UI if needed.

SCREENSHOT FOR ESOUI
Create an actual in-game screenshot showing /jdptaunt demo and
/jdpcross demo green. Upload the screenshot separately on the ESOUI
add-on page. This ZIP does not claim to include an in-game screenshot.

DONATIONS
Optional in-game gold gifts: @Evokation on PC NA only. Use /jdpdonate
for instructions. Gold is NEVER transferred automatically.
Players on PC EU cannot send gold across servers.

AI DISCLOSURE AND CREDITS
Lua code and maintenance were assisted by OpenAI ChatGPT (AI).
Original design direction and publishing: Jesus de Platre.
Please test in-game before public release.
