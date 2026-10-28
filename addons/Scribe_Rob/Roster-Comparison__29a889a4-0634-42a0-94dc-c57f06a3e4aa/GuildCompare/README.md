# Guild Compare 1.0

ESO add-on source intended for Xbox Series X|S. No libraries required.

## Use

1. Open both guild rosters and let them load.
2. Open text chat and enter `/gc guilds` to list your current guild slots.
3. Enter `/gc 1 2`, replacing the numbers with the two slots you want.
4. Read the shared members and their ranks in your local chat output.
5. Use `/gc next`, `/gc prev`, or `/gc page 3` to browse eight members at a time.
6. Use `/gc refresh` to take a fresh snapshot.

`/guildcompare` is an alias for `/gc`. Text entry can use the console keyboard. There is no controller menu in this version.

Compares account names case-insensitively, sorts results alphabetically, includes offline members, and uses ESO's final rank names (including default and custom ranks). Pending invitations are excluded. It only reads guilds your current account belongs to, on your current server. It cannot query arbitrary guilds. Results stay local; nothing is sent to chat channels, exported, or saved between sessions.

## Xbox distribution

A ZIP cannot be installed directly on Xbox. Publish through ESO's console Developer Uploader Tool, then install the published add-on from the in-game Add-Ons browser. Xbox One is unsupported. Follow the uploader's current package instructions; select the add-on source folder/manifest as required. This archive is a source package, not a published Xbox listing.

Official instructions: https://help.bethesda.net/app/answers/detail/a_id/69621/

## Validation and limitations

This version has not been run inside ESO or on Xbox. Verify local chat output and slash-command entry on the target console before publishing. Test overlapping members with different ranks, an offline shared member, no overlap, multiple pages, and leaving a selected guild before refreshing. Roster comparison uses the data currently available to the client; open both rosters first and refresh after changes. The manifest targets API 101050/101051; check the current console API version before upload.
