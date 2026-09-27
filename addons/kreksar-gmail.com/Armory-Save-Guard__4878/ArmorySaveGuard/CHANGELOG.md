# Armory Save Guard — Changelog

Full version history for Armory Save Guard. See README.md for current features, usage, and requirements.

---

### 1.1.2

- **Corrected the AI-assistance notice.** It wrongly said the addon had not
  been tested in-game; the author has tested it. The manifest description and
  README now say "reviewed and tested in-game by the author for functionality,"
  matching the rest of this addon family.
- Shortened README.md. The detailed API verification list lives in the Lua
  header comments.

### 1.1.1

- **Reverted the feedback change from 1.1.0.** Messages go to chat only again,
  as uncolored system messages prefixed `[ArmorySaveGuard]`, with the same
  wording as 1.0.0. The on-screen `ZO_Alert` popups and alert sounds are
  removed. They were added in 1.1.0 without being requested.
- All other 1.1.0 changes (disclosure, credits, manifest, docs) are kept.

### 1.1.0

- **Added the required AI-assistance disclosure** to the manifest description
  and README, per ESOUI's addon release rules. (This entry's notice wrongly
  said the addon was untested; corrected in 1.1.2.)
- **Standardized the author credit** to `@Kreksar5 and Claude.ai` in the
  `## Author` manifest field and the README byline, matching the rest of this
  addon family.
- **Added a Credits section** to the README. It credits ZeniMax Online Studios
  for the vanilla dialog code this addon copies, and names two existing addons
  with similar build-lock features (Armory Style Manager, RidinDirty) along
  with their authors. No code or ideas were taken from those addons.
- Manifest `## APIVersion` updated from `101050` to `101050 101051`. Checked
  the esoui/esoui PTS branch (API 101051): every file and function this addon
  relies on is unchanged or has the same signature.
- Manifest `## Title` changed to `Armory Save Guard` (with spaces) for
  readability in the in-game Add-Ons list. The folder and code name stay
  `ArmorySaveGuard`, so SavedVariables are unaffected.
- Manifest `## AddOnVersion` changed from `10000` to `2`, matching the plain
  release counter used across this addon family. 1.0.0 was never published.
- Removed the redundant `## IsLibrary: false` line from the manifest.
- **Feedback now also raised an on-screen alert** via `ZO_Alert`, alongside
  a color-coded chat message. (Reverted in 1.1.1.)
- Event registrations now use the addon name `ArmorySaveGuard` itself as the
  namespace.
- Split the changelog out of README.md into this file, and reformatted
  README.md into BBCode for the ESOUI addon description page.
- Checked for leaked global variables (`luac5.4 -l`): none. The only globals
  are the declared SavedVariables table and the `/armorysaveguard` slash
  command entry.
- `luac5.4 -p` syntax check passed.

### 1.0.0

- Initial release (not published).
- Pre-hooks `ZO_ARMORY_MANAGER:ShowBuildOperationConfirmationDialog`. For save
  operations in keyboard mode, shows a type-to-confirm dialog (`OVERWRITE`)
  instead of the vanilla Accept/Cancel prompt, then calls `SaveArmoryBuild`
  the same way the vanilla dialog does.
- `/armorysaveguard [on|off|toggle|status]` slash command, stored in
  account-wide SavedVariables, default on.
