# Public beta testing

Build: 0.2.0-beta

## Completed automated checks

- All packaged Lua modules compile in the Lua validation runtime.
- 344 simulated regression checks passed, including loot accounting, quantity/timing
  classification, goal selection/entry, migrations, travel preview, tooltips and exports.
- 20 isolated fresh-install smoke checks passed with both optional addons absent.
- Window position/open-state recovery and hidden-window redraw suppression were checked.
- Visible loot bursts coalesce to one refresh; data accounting remains immediate.

These are mocked ESO checks. They do not prove live rendering, actual map coordinates,
server travel behavior or the interaction of other installed addons.

## Live ESO check — pending

Use a test character/profile; retain your existing saved variables. A genuinely fresh
install should be checked in a separate profile instead of deleting your live history.

- [ ] Fresh install: window opens, /surveys toggles it, no Lua errors.
- [ ] Move and close the window; /reloadui keeps it closed and restores its position.
- [ ] Reopen/minimize; verify the timer and totals continue as expected.
- [ ] Choose a survey type and material, click Quantity, type a target and Set Goal.
- [ ] Harvest a normal raw node, a survey raw node and rune nodes; compare with the loot log.
- [ ] Reach a material goal and check the message/sound.
- [ ] Pause/resume; Finish Run; verify summary and detailed export can be copied.
- [ ] /reloadui with an unfinished run; confirm it restores paused with the same totals.
- [ ] With LibTreasure installed, verify map marker and preview destination before travel.
- [ ] Travel once from a wayshrine and once by recall, checking normal costs/restrictions.
- [ ] Check bank snapshots with the bank open.
- [ ] With TTC installed, confirm known prices and the handling of unpriced materials.

## Download-page preparation

ESOUI_DESCRIPTION.txt contains a ready-to-copy listing draft. CREDITS.md acknowledges the
optional integrations. CHANGELOG.md covers the public-beta candidate. The game version/API
compatibility and live checks above should be confirmed on the publishing machine.
