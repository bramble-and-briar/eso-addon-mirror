# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-30T00:37:50Z
Reviewer: AI assistant using Copilot SDK in VS Code (GPT-6.1-sol)
Checked by: Tim-P
Add-on: InventoryCompanion
Release version: 1.4.1
Candidate SHA256: C4E38C92BC1946F3ACBAFCB95B2735B45F462C5B0A4892A9C792C7489824E1AB
Candidate identity method: SHA-256 of sorted candidate-relative Windows-path and file-SHA256 pairs, joined with LF and encoded as UTF-8, as recorded by the staging script
Report location: ReleaseReview.md in the development checkout
Review status: APPROVED
Review format: compact-v1
Review mode: DELTA
Baseline review: ReleaseReview.md approved for v1.2.1, candidate SHA256 F7F3E3B1F06177608871B3FC5A9880D66CDF96F62D4A672C132CB52050E9AC09, reviewed 2026-10-27T22:04:15Z

Testing scope: Offline checks and Live/EU testing completed. PTS was not reported and is not claimed.

## Review scope

- [x] Record the candidate installation, reproducible identity method, staging/test-installation verification, and comparison baseline.

CURRENT RELEASE 1.4.1: At the author's direction, the diagnostic-removal hotfix has been staged through the standard release workflow as version 1.4.1, AddOnVersion 10401, with the candidate identity at the top of this report. Compared with original 1.4.0, changes are limited to removal of the unconditional editor-layout diagnostic, manifest/runtime version metadata, and the 1.4.1 changelog entry. Earlier 1.4.0 staging details and diagnostic reports below are retained as historical evidence, not relabeled as fresh 1.4.1 tests. The corrected 1.4.0 candidate and custom-named archive are superseded; use the standard InventoryCompanion-v1.4.1.zip. Standard staging state now describes 1.4.1. The 71/71 post-fix offline test result and unchanged-behavior Live evidence carry forward; no fresh 1.4.1 Live run is claimed.

PASS: The candidate is staged at `live/AddOns/InventoryCompanion` as v1.4.0 with 31 files. Its installed hashes match the staging state, and the independently recomputed deterministic identity is recorded above. The manifest reports AddOnVersion 10400 and the runtime source reports 1.4.0. Stage removed the DEV bootstrap/title marker, backed up both last-on-disk saved-variable files with verified hashes, and advanced DEV to 1.4.1. Tim-P's Live diagnostic confirms Installation=InventoryCompanion, runtime version=1.4.0, DEV=false, AddOnVersion=10400, with no enabled DEV copy listed.

PASS: The approved v1.2.1 archive reproduces its recorded 28-file identity F7F3E3B1F06177608871B3FC5A9880D66CDF96F62D4A672C132CB52050E9AC09. Before replacing the blocked v1.3.2 installation, its preserved ZIP was verified against all 31 staging records. That ZIP (archive SHA256 20C36A451C54AAA1C2CCE1AA3A418A21E0D6E5AE5DB00FA5EF0CBAF172DD8196) and its historical report remain available for diff review and file rollback; rollback does not undo inventory or saved-data changes.

## Changes reviewed

- [x] Summarize the actual candidate-to-baseline diff, inspect changed code plus affected callers/data flows, and record findings. Carry forward unchanged source-review evidence by baseline reference.

PASS: This resumes the recorded v1.2.1-to-v1.3.2 source-review coverage rather than treating the blocked 1.3.2 report as an approved baseline. That coverage assessed tracker layout/visibility, editors, sparse overrides, diagnostics, and the corrected empty-pattern matcher. Its runtime bytes are unchanged except for the differences enumerated below; its unresolved large-group hang is explicitly reassessed here. Approved v1.2.1 evidence remains applicable to unchanged code, especially transfers and protected-call paths.

PASS: Compared every frozen 1.4.0 candidate file against the verified 1.3.2 ZIP. Six files differ bytewise: manifest/runtime version metadata, changelog, `Tracking/ItemTrackerPanel.lua`, and line-ending-only changes in `Tracking/EditPanelItemsTab.xml` and `Tracking/ItemTrackerPanel.xml`. Both XML files parse. The other 25 files are byte-identical.

PASS: Inspected the complete tracker delta and its member collection, total-count calculation, row pooling/reset, layout signatures, expansion selection, wrapping, viewport, and refresh paths. More than 200 eligible members produce one overflow row instead of thousands of display rows; filtering occurs before the cap and totals still include every matching item. Groups at or below 200 retain sorted member rows. Overflow count participates in the layout signature; pooled rows reset icon visibility/color and text color when reused. No new material issue was found. Tim-P subsequently confirmed the requested targeted Live check of prompt expansion/collapse, overflow message/information icon, and intact summary counts.

## Release checks

- [x] Check candidate identity, package contents, manifest/dependencies, final listing/changelog/assets, and applicable author confirmations.

PASS: The manifest uses API 101051, AddOnVersion 10400, and `LibAddonMenu-2.0>=43`. Candidate contents include the existing AI/dependency readme and updated BBCode changelog, and exclude DEV bootstrap, saved variables, generated API files, and offline test tooling. Runtime files match source, apart from the subsequent DEV version increment and Init line endings. No newest-published dependency claim is made. The standing author rights/no-malicious-material assertion and prior policy/listing confirmations carry forward from the approved v1.2.1 review; no relevant policy-facing behavior changed.

PASS (author direction): The manual and its SVGs are not part of this release handoff because the author is not uploading a manual at this time. The actual `InventoryCompanion CurrencyConfig.png` is available for handoff (SHA256 `99C8C8AAF6AC054878AEECC7F4B64FE2DD37E2A3A4E353D4AAC2A95E03E69D5D`). The prior review noted that the image is cropped at the top and bottom; confirm its presentation before ESOUI submission. Final archive verification remains required before upload.

## Test evidence

- [x] Reference one complete diagnostic and representative human checks, with tester/date/environment and candidate identity; name relevant results and limitations.

PASS (AI, offline): On 2026-10-30, the existing `Project/Tests/Run-RuleTests.py` runner was executed against a private copy of the frozen 1.4.0 runtime bytes with the existing offline fixtures: 71/71 isolated tests passed and all runtime Lua syntax compiled under Lua 5.1. Coverage includes 199/200/201/5000-member boundaries, zero-stock filtering before the cap, full bank/bag totals, pooled overflow-to-normal transitions, empty patterns, scrolling, visibility, and saved-data contracts. Synthetic 5000-member expansion took 4/1000 ms; five refreshes took 20/1500 ms. Other measured limits passed: scans 46/500 ms, slot matches 0/100 ms, tracked updates 1/200 ms, warmed 100 x 20-item refreshes 10/250 ms, and 20 x 1000-item refreshes 16/1500 ms. No live inventory or saved variables were mutated by these tests.

PASS (AI, packaging): `Project/Publishing/Test-PackageRelease.ps1` passed 191 isolated assertions. Its temporary fixtures did not modify the live installation or saved variables.

PASS (TEST, Tim-P): The complete 1.4.0 diagnostic below reports 79/79 passed at 2026-10-30T00:17:48Z on Live/EU, game eso.live.12.1.6.3309674, API 101051, English, ESO Plus active, bank closed. Runtime version and installation match the frozen candidate. LibAddonMenu-2.0 AddOnVersion 43 meets the manifest minimum; its outOfDate flag is retained, not treated as an integer-version failure. All timings pass: scans 67/500 ms, slot-rule matches 0/100 ms, tracked-item updates 3/200 ms, and 100 read-only live scans 230/500 ms with 783 occupied entries.

PASS (HUMAN, Tim-P): At 2026-10-30T00:18:07Z, Tim-P replied "confirmed" to the targeted request to repeat the previously hanging intentional `*` group expansion and confirm prompt expansion/collapse, overflow message/amber information icon, and correct summary counts. This resolves the prior large-group finding for the identified 1.4.0 candidate.

HISTORICAL (TEST, Tim-P): The complete 1.3.2 Live diagnostic below reported 79/79 tests at 2026-10-29T23:39:43Z, with API 101051 and dependency AddOnVersion 43. It is not a 1.4.0 result and did not reveal the later human-reported large-group hang.

PASS (HUMAN, Tim-P): The toggle initially appeared ineffective while the older v1.3.1 runtime was loaded. After reloading the correct v1.3.2 candidate, Tim-P reported the toggle worked; this behavior is unchanged by the empty-pattern fix. On the prior v1.3.2 candidate (SHA256 D7E473AA08D5F32E91CF61980E0969176FB1328B0D7B62BFE74F5C242A5F99C6), Tim-P reported “all fine, normal things available” for the transfer check and no problems. Transfer implementation was unchanged in the corrected candidate, so this evidence carries forward. No PTS testing was reported.

## Findings and decision

- [x] Summarize findings, limitations, unresolved items, and the approval decision; separate candidate approval from archive verification and upload readiness.

CORRECTED CANDIDATE APPROVED (2026-10-30): The original 1.4.0 identity was 9F7CC6F4273CC01A7C361F71865474F72365F19687321AD515FB7A43F77AC544. An unconditional editor-layout chat diagnostic was subsequently found in `Tracking/EditPanelTabManager.lua`. The sole runtime correction removes that print, its explanatory comment, and a blank line; the exact removal was verified against the original ZIP. No movement, layout, state, or debug-setting behavior changes. The existing offline suite passed 71/71 again after correction, including Lua 5.1 syntax validation. The earlier 79/79 Live report and targeted human observations apply to unchanged behavior; no fresh Live test is claimed for this deletion-only correction. The corrected installed file-set identity is recorded at the top of this report. The original ZIP/handoff remain unchanged and must not be uploaded; use the separately verified corrected handoff instead. The original staging state remains a historical record of the original candidate, not the corrected identity.

APPROVED: Source delta review, offline checks, the correct-installation 79/79 Live diagnostic, and Tim-P's targeted large-group confirmation satisfy the candidate checks. No unresolved material candidate issue remains. Prior transfer evidence above carries forward because transfer code is byte-identical; no additional transfer matrix is requested. The 1.3.2 release remains blocked and must not be uploaded. Approval covers this 1.4.0 candidate identity, not a future archive. Final archive verification is required; the cropped screenshot's presentation remains an uploader check before submission. No PTS compatibility claim is made.

## Complete 1.4.0 Live diagnostic supplied by Tim-P

```text
[InventoryCompanion tests] 79/79 passed; 20 x 100-item scans / 20 rules: 67/500 ms; 100 slot-rule matches: 0/100 ms; 100 tracked-item slot updates: 3/200 ms; 100 live backpack/bank/craft-bag scans (bank closed): 230/500 ms, 783 occupied entries
[InventoryCompanion tests] INFO Environment: timestamp=1793319468 (Unix UTC); game=eso.live.12.1.6.3309674; API=101051; server=EU Megaserver; language=en
[InventoryCompanion tests] INFO Installation: InventoryCompanion; runtime version=1.4.0; DEV=false; ESO Plus=true; bank=closed
[InventoryCompanion tests] INFO Enabled add-on: AddonSelector; AddOnVersion=302030; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: InventoryCompanion; AddOnVersion=10400; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: LibScrollableMenu; AddOnVersion=20407; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: VotansKeybinder; AddOnVersion=0; state=2; outOfDate=true
[InventoryCompanion tests] INFO Enabled add-on: LibAddonMenu-2.0; AddOnVersion=43; state=2; outOfDate=true
[InventoryCompanion tests] INFO Conditional currency coverage: Alliance Points; ID=2; available=true
[InventoryCompanion tests] INFO Conditional currency coverage: Transmute Crystals; ID=5; available=true
[InventoryCompanion tests] INFO Transmute Crystals capped-colour assertions enabled=true
[InventoryCompanion tests] INFO Conditional currency coverage: Trade Bars; ID=9; available=true
[InventoryCompanion tests] INFO Human evidence still required: Live/PTS channel, candidate SHA256/installation verification, manifest API/minimum-version comparison, UI/event delivery, transfers, persistence and collision checks.
[InventoryCompanion tests] INFO Safety: live scans are read-only; synthetic tests temporarily replace runtime state and restore it; no inventory transfers or intentional saved-variable writes.
[InventoryCompanion tests] PASS Runtime and dependency discovery
[InventoryCompanion tests] PASS Live read-only scan: 100 scans, 783 occupied entries on final scan, bank closed
[InventoryCompanion tests] PASS Progress bar resource model and preferences
[InventoryCompanion tests] PASS Currency notification preferences and changes
[InventoryCompanion tests] PASS Prune known saved-variable diagnostic keys only
[InventoryCompanion tests] PASS Currency panel resource preferences
[InventoryCompanion tests] PASS Live currency helper API
[InventoryCompanion tests] PASS Profile import copies tracked items and rule overrides
[InventoryCompanion tests] PASS Tracked item count respects backpack and craft-bag scope
[InventoryCompanion tests] PASS Case-insensitive substring matching
[InventoryCompanion tests] PASS Wildcard matching
[InventoryCompanion tests] PASS Literal punctuation and missing names
[InventoryCompanion tests] PASS Any-pattern matching
[InventoryCompanion tests] PASS Baseline and saved-rule override resolution
[InventoryCompanion tests] PASS Display-flag writes preserve other overrides
[InventoryCompanion tests] PASS 100-item backpack and craft-bag scan
[InventoryCompanion tests] PASS Repeated 100-item inventory scan performance
[InventoryCompanion tests] PASS 100 repeated slot-rule matches
[InventoryCompanion tests] PASS 100 synthetic tracked-item slot updates
[InventoryCompanion tests] PASS Event listener transitions and refresh debounce
[InventoryCompanion tests] PASS Currency messages: capped balance colours follow the progress bar thresholds
[InventoryCompanion tests] PASS Currency messages: Picking up 10 gold
[InventoryCompanion tests] PASS Currency messages: Picking up three 10-gold piles in quick succession merges
[InventoryCompanion tests] PASS Currency messages: Picking up three 10-gold piles with quiet periods between
[InventoryCompanion tests] PASS Currency messages: Withdrawing 10 gold (bank event first)
[InventoryCompanion tests] PASS Currency messages: Withdrawing 10 gold (bag event first)
[InventoryCompanion tests] PASS Currency messages: Depositing 10 gold
[InventoryCompanion tests] PASS Currency messages: Withdrawing a large amount
[InventoryCompanion tests] PASS Currency messages: Depositing a large amount
[InventoryCompanion tests] PASS Currency messages: Spending a large amount
[InventoryCompanion tests] PASS Currency messages: Spending a small amount
[InventoryCompanion tests] PASS Currency messages: Login balance report is silent
[InventoryCompanion tests] PASS Currency messages: Withdrawing then depositing the same amount in one window sends nothing
[InventoryCompanion tests] PASS Currency messages: Pickup and withdrawal in one window show consistent balances
[InventoryCompanion tests] PASS Currency messages: Alliance Points gained
[InventoryCompanion tests] PASS Currency messages: Alliance Points spent
[InventoryCompanion tests] PASS Currency messages: Alliance Points withdrawn from the bank
[InventoryCompanion tests] PASS Currency messages: Alliance Points deposited in the bank
[InventoryCompanion tests] PASS Currency messages: Transmute Crystals gained
[InventoryCompanion tests] PASS Currency messages: Transmute Crystals spent
[InventoryCompanion tests] PASS Currency messages: Trade Bars gained
[InventoryCompanion tests] PASS Currency messages: Trade Bars spent
[InventoryCompanion tests] PASS Capacity messages: bag space used by looting
[InventoryCompanion tests] PASS Capacity messages: bag space freed by selling
[InventoryCompanion tests] PASS Capacity messages: bag changes that cancel out
[InventoryCompanion tests] PASS Capacity messages: bag space crossing the warning and danger thresholds
[InventoryCompanion tests] PASS Capacity messages: bank to bag move
[InventoryCompanion tests] PASS Capacity messages: bag to bank move
[InventoryCompanion tests] PASS Capacity messages: moving a stack of 10 counts all items
[InventoryCompanion tests] PASS Capacity messages: stack merged into an existing stack still reports the move
[InventoryCompanion tests] PASS Capacity messages: bank change away from the bank is silent
[InventoryCompanion tests] PASS Capacity messages: opposite changes without a bank visit are bag-only
[InventoryCompanion tests] PASS Capacity messages: transfer plus a pickup
[InventoryCompanion tests] PASS Capacity messages: bag-only notification during a withdrawal
[InventoryCompanion tests] PASS Capacity messages: disabled notifications stay silent
[InventoryCompanion tests] PASS Capacity messages: load-screen reports stay silent
[InventoryCompanion tests] PASS Capacity messages: balance colours follow the progress bar thresholds
[InventoryCompanion tests] PASS Capacity notification preferences
[InventoryCompanion tests] PASS Delta patterns follow the sequential specification
[InventoryCompanion tests] PASS Delta patterns are unique and support empty lists and custom groups
[InventoryCompanion tests] PASS Rule setters write only selected fields and prune restored defaults
[InventoryCompanion tests] PASS Legacy rules convert to sparse overrides without altering the baseline
[InventoryCompanion tests] PASS Invalid rule mutations fail without writing saved state
[InventoryCompanion tests] PASS Saved rule boundary rejects malformed data without discarding it
[InventoryCompanion tests] PASS Initialization validates inactive saved profiles and optional absence
[InventoryCompanion tests] PASS Internal mutation contracts reject sparse lists and invalid list switches
[InventoryCompanion tests] PASS Broken maintained baselines fail before normalization or writes
[InventoryCompanion tests] PASS Scans require compiled rules instead of silently compiling raw input
[InventoryCompanion tests] PASS Runtime cache rebuilds lazily and keeps editor views isolated
[InventoryCompanion tests] PASS Hidden groups stay cached and list switching invalidates immediately
[InventoryCompanion tests] PASS Failed runtime rebuilds do not publish partial caches
[InventoryCompanion tests] PASS Profile copy preserves sparse deltas and never aliases its source
[InventoryCompanion tests] PASS Malformed imported rules fail before clearing the destination
[InventoryCompanion tests] PASS Scanning and notifications use current compiled rules
[InventoryCompanion tests] PASS Empty patterns do not match every item
[InventoryCompanion tests] PASS Group lifecycle mutations invalidate and clear only the active profile
[InventoryCompanion tests] PASS Untouched defaults allocate no saved rule data
[InventoryCompanion tests] PASS Reconciled pattern deltas obey set invariants across repeated edits
[InventoryCompanion tests] PASS Cached synthetic scans and inventory bursts stay within thresholds
```

## Historical 1.3.2 staged release test confirmation (not 1.4.0 evidence)

Staged (UTC): 10/29/2026 23:37:53
Confirmed (UTC): 2026-10-29T23:47:50.6445317Z

[InventoryCompanion tests] 79/79 passed; 20 x 100-item scans / 20 rules: 72/500 ms; 100 slot-rule matches: 0/100 ms; 100 tracked-item slot updates: 2/200 ms; 100 live backpack/bank/craft-bag scans (bank closed): 243/500 ms, 783 occupied entries [InventoryCompanion tests] INFO Environment: timestamp=1793317183 (Unix UTC); game=eso.live.12.1.6.3309674; API=101051; server=EU Megaserver; language=en [InventoryCompanion tests] INFO Installation: InventoryCompanion; runtime version=1.3.2; DEV=false; ESO Plus=true; bank=closed [InventoryCompanion tests] INFO Enabled add-on: AddonSelector; AddOnVersion=302030; state=2; outOfDate=false [InventoryCompanion tests] INFO Enabled add-on: InventoryCompanion; AddOnVersion=10302; state=2; outOfDate=false [InventoryCompanion tests] INFO Enabled add-on: LibScrollableMenu; AddOnVersion=20407; state=2; outOfDate=false [InventoryCompanion tests] INFO Enabled add-on: VotansKeybinder; AddOnVersion=0; state=2; outOfDate=true [InventoryCompanion tests] INFO Enabled add-on: LibAddonMenu-2.0; AddOnVersion=43; state=2; outOfDate=true [InventoryCompanion tests] INFO Conditional currency coverage: Alliance Points; ID=2; available=true [InventoryCompanion tests] INFO Conditional currency coverage: Transmute Crystals; ID=5; available=true [InventoryCompanion tests] INFO Transmute Crystals capped-colour assertions enabled=true [InventoryCompanion tests] INFO Conditional currency coverage: Trade Bars; ID=9; available=true [InventoryCompanion tests] INFO Human evidence still required: Live/PTS channel, candidate SHA256/installation verification, manifest API/minimum-version comparison, UI/event delivery, transfers, persistence and collision checks. [InventoryCompanion tests] INFO Safety: live scans are read-only; synthetic tests temporarily replace runtime state and restore it; no inventory transfers or intentional saved-variable writes. [InventoryCompanion tests] PASS Runtime and dependency discovery [InventoryCompanion tests] PASS Live read-only scan: 100 scans, 783 occupied entries on final scan, bank closed [InventoryCompanion tests] PASS Progress bar resource model and preferences [InventoryCompanion tests] PASS Currency notification preferences and changes [InventoryCompanion tests] PASS Prune known saved-variable diagnostic keys only [InventoryCompanion tests] PASS Currency panel resource preferences [InventoryCompanion tests] PASS Live currency helper API [InventoryCompanion tests] PASS Profile import copies tracked items and rule overrides [InventoryCompanion tests] PASS Tracked item count respects backpack and craft-bag scope [InventoryCompanion tests] PASS Case-insensitive substring matching [InventoryCompanion tests] PASS Wildcard matching [InventoryCompanion tests] PASS Literal punctuation and missing names [InventoryCompanion tests] PASS Any-pattern matching [InventoryCompanion tests] PASS Baseline and saved-rule override resolution [InventoryCompanion tests] PASS Display-flag writes preserve other overrides [InventoryCompanion tests] PASS 100-item backpack and craft-bag scan [InventoryCompanion tests] PASS Repeated 100-item inventory scan performance [InventoryCompanion tests] PASS 100 repeated slot-rule matches [InventoryCompanion tests] PASS 100 synthetic tracked-item slot updates [InventoryCompanion tests] PASS Event listener transitions and refresh debounce [InventoryCompanion tests] PASS Currency messages: capped balance colours follow the progress bar thresholds [InventoryCompanion tests] PASS Currency messages: Picking up 10 gold [InventoryCompanion tests] PASS Currency messages: Picking up three 10-gold piles in quick succession merges [InventoryCompanion tests] PASS Currency messages: Picking up three 10-gold piles with quiet periods between [InventoryCompanion tests] PASS Currency messages: Withdrawing 10 gold (bank event first) [InventoryCompanion tests] PASS Currency messages: Withdrawing 10 gold (bag event first) [InventoryCompanion tests] PASS Currency messages: Depositing 10 gold [InventoryCompanion tests] PASS Currency messages: Withdrawing a large amount [InventoryCompanion tests] PASS Currency messages: Depositing a large amount [InventoryCompanion tests] PASS Currency messages: Spending a large amount [InventoryCompanion tests] PASS Currency messages: Spending a small amount [InventoryCompanion tests] PASS Currency messages: Login balance report is silent [InventoryCompanion tests] PASS Currency messages: Withdrawing then depositing the same amount in one window sends nothing [InventoryCompanion tests] PASS Currency messages: Pickup and withdrawal in one window show consistent balances [InventoryCompanion tests] PASS Currency messages: Alliance Points gained [InventoryCompanion tests] PASS Currency messages: Alliance Points spent [InventoryCompanion tests] PASS Currency messages: Alliance Points withdrawn from the bank [InventoryCompanion tests] PASS Currency messages: Alliance Points deposited in the bank [InventoryCompanion tests] PASS Currency messages: Transmute Crystals gained [InventoryCompanion tests] PASS Currency messages: Transmute Crystals spent [InventoryCompanion tests] PASS Currency messages: Trade Bars gained [InventoryCompanion tests] PASS Currency messages: Trade Bars spent [InventoryCompanion tests] PASS Capacity messages: bag space used by looting [InventoryCompanion tests] PASS Capacity messages: bag space freed by selling [InventoryCompanion tests] PASS Capacity messages: bag changes that cancel out [InventoryCompanion tests] PASS Capacity messages: bag space crossing the warning and danger thresholds [InventoryCompanion tests] PASS Capacity messages: bank to bag move [InventoryCompanion tests] PASS Capacity messages: bag to bank move [InventoryCompanion tests] PASS Capacity messages: moving a stack of 10 counts all items [InventoryCompanion tests] PASS Capacity messages: stack merged into an existing stack still reports the move [InventoryCompanion tests] PASS Capacity messages: bank change away from the bank is silent [InventoryCompanion tests] PASS Capacity messages: opposite changes without a bank visit are bag-only [InventoryCompanion tests] PASS Capacity messages: transfer plus a pickup [InventoryCompanion tests] PASS Capacity messages: bag-only notification during a withdrawal [InventoryCompanion tests] PASS Capacity messages: disabled notifications stay silent [InventoryCompanion tests] PASS Capacity messages: load-screen reports stay silent [InventoryCompanion tests] PASS Capacity messages: balance colours follow the progress bar thresholds [InventoryCompanion tests] PASS Capacity notification preferences [InventoryCompanion tests] PASS Delta patterns follow the sequential specification [InventoryCompanion tests] PASS Delta patterns are unique and support empty lists and custom groups [InventoryCompanion tests] PASS Rule setters write only selected fields and prune restored defaults [InventoryCompanion tests] PASS Legacy rules convert to sparse overrides without altering the baseline [InventoryCompanion tests] PASS Invalid rule mutations fail without writing saved state [InventoryCompanion tests] PASS Saved rule boundary rejects malformed data without discarding it [InventoryCompanion tests] PASS Initialization validates inactive saved profiles and optional absence [InventoryCompanion tests] PASS Internal mutation contracts reject sparse lists and invalid list switches [InventoryCompanion tests] PASS Broken maintained baselines fail before normalization or writes [InventoryCompanion tests] PASS Scans require compiled rules instead of silently compiling raw input [InventoryCompanion tests] PASS Runtime cache rebuilds lazily and keeps editor views isolated [InventoryCompanion tests] PASS Hidden groups stay cached and list switching invalidates immediately [InventoryCompanion tests] PASS Failed runtime rebuilds do not publish partial caches [InventoryCompanion tests] PASS Profile copy preserves sparse deltas and never aliases its source [InventoryCompanion tests] PASS Malformed imported rules fail before clearing the destination [InventoryCompanion tests] PASS Scanning and notifications use current compiled rules [InventoryCompanion tests] PASS Empty patterns do not match every item [InventoryCompanion tests] PASS Group lifecycle mutations invalidate and clear only the active profile [InventoryCompanion tests] PASS Untouched defaults allocate no saved rule data [InventoryCompanion tests] PASS Reconciled pattern deltas obey set invariants across repeated edits [InventoryCompanion tests] PASS Cached synthetic scans and inventory bursts stay within thresholds blank patten no longer matches anything. * does match everything stil (expected) but it exposes another edge case - if the user adds * and also 'totals' then the panel needs to show EVERY ITEM THEY HAVE and it freezes the game when you try to expand the group,

## Staged release test confirmation

Staged (UTC): 10/30/2026 00:16:16
Confirmed (UTC): 2026-10-30T00:18:44.3421950Z

Tim-P confirmed the targeted large-group expansion/collapse, overflow message and amber information icon, and correct summary counts on 2026-10-30. Complete 1.4.0 Live diagnostic retained above: 79/79 passed at 2026-10-30T00:17:48Z; Installation=InventoryCompanion; runtime version=1.4.0; DEV=false; AddOnVersion=10400; Live/EU; API=101051; LibAddonMenu-2.0=43; ESO Plus=true; bank closed. Timings: scans 67/500 ms, slot matches 0/100 ms, tracked updates 3/200 ms, live scans 230/500 ms with 783 entries. Unchanged transfer evidence carries forward as documented. PTS not tested.

## Staged release test confirmation

Staged (UTC): 10/30/2026 00:37:50
Confirmed (UTC): 2026-10-30T00:38:00.9445830Z

1.4.1 hotfix: exact deletion of unconditional editor-layout chat diagnostic, plus version metadata and changelog. Post-fix offline Lua 5.1 suite: 71/71 passed. Carry forward Tim-P 1.4.0 Live 79/79 report and targeted large-group confirmation for unchanged behavior, as documented above. No fresh 1.4.1 in-game run claimed.

