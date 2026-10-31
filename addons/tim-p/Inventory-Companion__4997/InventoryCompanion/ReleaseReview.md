# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-30T20:02:03Z
Reviewer: AI assistant using Copilot SDK in VS Code
Checked by: Tim-P
Add-on: InventoryCompanion
Release version: 1.5.0
Candidate SHA256: 7475DDCCBAA254214C8B33E0E038B82BB055BA5ABBF767B32755C92F4A63FC72
Candidate identity method: SHA-256 of sorted candidate-relative Windows-path and file-SHA256 pairs, joined with LF and encoded as UTF-8, as recorded by the staging script
Report location: ReleaseReview.md in the development checkout
Review status: APPROVED
Review format: compact-v1
Review mode: DELTA
Baseline review: Project/Publishing/Packages/Reviewed/InventoryCompanion-v1.4.1/ReleaseReview.md; approved version 1.4.1, candidate SHA256 C4E38C92BC1946F3ACBAFCB95B2735B45F462C5B0A4892A9C792C7489824E1AB, reviewed 2026-10-30T00:37:50Z

Testing scope: Offline checks, Live/EU diagnostics, and requested human checks completed. PTS compatibility is not claimed.

## Review scope

- [x] Record the candidate installation, reproducible identity method, staging/test-installation verification, and comparison baseline.

PASS: Standard staging installed version 1.5.0, AddOnVersion 10500, in the sibling InventoryCompanion installation and advanced DEV to 1.5.1. All 31 candidate file hashes were independently checked against staging state. The file-set identity above was independently recomputed. Both installation saved-variable files were backed up and their SHA-256 hashes verified before staging.

The approved 1.4.1 review and archive remain in their historical handoff folder. Unchanged transfer, dependency, and policy-facing behavior carries forward from that review; this report does not relabel prior Live results as current tests.

## Changes reviewed

- [x] Summarize the actual candidate-to-baseline diff, inspect changed code plus affected callers/data flows, and record findings.

PASS: The source delta from the 1.4.1 commit changes tracker expansion handling, offline tests, and the user manual. The staged changelog adds the 1.5.0 entry, and manifest/runtime metadata identify 1.5.0. Development planning documents and offline tests are not release runtime inputs.

Inspected the tracker delta and its existing group-header creation, click handler, layout model, previous-layout/context invalidation, row selection, sizing, and final rendering. Saved isExpanded now records manual preference, while preferredExpanded and effective expanded state are separate in-memory layout fields. Automatic layout decisions no longer call SetRuleFlag. Closed preferences cannot enter automatic expansion candidates, including edited/reintroduced groups. Clicks toggle the rendered state so a temporarily collapsed preferred-open group can be opened normally. Existing overflow, wrapping, scrolling, and retention policies are otherwise preserved.

No new saved-variable fields, schema version, or migration are introduced. Existing saved values are preserved because their past manual/automatic origin cannot be reconstructed.

## Release checks

- [x] Check candidate identity, package contents, manifest/dependencies, final listing/changelog/assets, and applicable author confirmations.

PASS: Standard staging froze runtime files, release manifest, readme, and authoritative BBCode changelog. DEV bootstrap is omitted. Candidate identity is verified. The author's standing rights/no-malicious-material assertion and unchanged policy evidence carry forward from the approved baseline.

PASS: Independently reproduced the approved 1.4.1 file-set identity from its historical ZIP, using case-insensitive record ordering consistent with PowerShell Sort-Object and excluding the separately added review. Compared all candidate paths and bytes: the file set is unchanged, and only Changelog.bbcode, Core\Init.lua, InventoryCompanion.txt, and Tracking\ItemTrackerPanel.lua differ. Verified all current candidate hashes again and confirmed other runtime files match DEV test inputs byte-for-byte.

PASS: Preserve the author's Current Documentation readme and feature-list text for the combined handoff listing; their expanded publishing prose intentionally differs from the minimal frozen runtime readme. The current changelog describes both changed behaviours. Preserve the prior direction not to upload a manual; the differing working manual is therefore not included in this handoff. Use the actual root InventoryCompanion CurrencyConfig.png, not its shortcut. The baseline image-cropping limitation carries forward. Final ZIP verification is delegated to Finalize after candidate approval. No ESOUI publication is claimed.

## Test evidence

- [x] Reference one complete diagnostic/test report and representative human checks, with tester/date/environment and candidate identity.

PASS (AI, offline): On 2026-10-30, python Project\Tests\Run-RuleTests.py passed 74/74 isolated tests and compiled runtime Lua under Lua 5.1 in the DEV checkout immediately after staging. DEV differs in version metadata/bootstrap from the candidate; the changed tracker runtime and other runtime inputs were verified byte-identical to the candidate, and the supplied Live run verifies frozen installation loading. Relevant cases cover manual closure across inventory/settings changes, reintroduction and simulated tracker reload, saved-closed initial layout, edited closed groups with spare space, temporary collapse/restoration, clicks on temporarily collapsed groups, context invalidation, one-scan refreshes and debounced bursts, and the existing large-group boundaries.

Measured synthetic workloads: 20 scans 57/500 ms; 100 slot-rule matches 1/100 ms; 100 tracked updates 0/200 ms; 5000-item expansion 4/1000 ms; five large-group refreshes 29/1500 ms; 100 x 20-item refreshes 13/250 ms; 20 x 1000-item refreshes 19/1500 ms. No live inventory or saved variables were modified by offline tests.

PASS (TEST, Tim-P): Supplied the complete /ictest verbose copy report below. It reports 79/79 passed at Unix UTC 1793390318 on Live/EU, game eso.live.12.1.6.3309674, API 101051, English, ESO Plus active, bank closed. Installation=InventoryCompanion, runtime=1.5.0, DEV=false and AddOnVersion=10500 match the frozen candidate; no enabled DEV installation is listed. LibAddonMenu-2.0 integer version 43 meets the existing manifest minimum; its outOfDate flag is retained rather than treated as a minimum-version failure. All timing limits pass, including 100 live scans at 235/500 ms with 771 occupied entries. This diagnostic does not establish manual group persistence or transfer success.

PASS (HUMAN, Tim-P): At 2026-10-30T20:02:03Z, in response to the requested closed-group inventory/row-limit/reload checks, clicking a temporarily collapsed group, and normal transfer check, Tim-P replied: "its all good - everything seems to work". Record this as overall confirmation of the requested checks, not a detailed storage-by-storage test log. No unavailable storage or problems were reported. ESO Plus is confirmed by diagnostics; no PTS testing was reported and none is claimed. Unchanged transfer source and prior approved transfer evidence also carry forward from the baseline.

## Findings and decision

- [x] Summarize findings, limitations, unresolved items and the approval decision.

APPROVED: No unresolved material findings in the inspected delta, offline tests, current Live diagnostics, or supplied human confirmation. Approve only the identified frozen 1.5.0 candidate. Limitations: no PTS claim, no detailed storage-by-storage log, manual upload remains excluded by prior author direction, and the existing screenshot crop should be checked when submitting. Finalize must verify the archive before handoff; publication is a separate action.

## Complete 1.5.0 Live diagnostic supplied by Tim-P

```text
[InventoryCompanion tests] 79/79 passed; 20 x 100-item scans / 20 rules: 56/500 ms; 100 slot-rule matches: 1/100 ms; 100 tracked-item slot updates: 2/200 ms; 100 live backpack/bank/craft-bag scans (bank closed): 235/500 ms, 771 occupied entries
[InventoryCompanion tests] INFO Environment: timestamp=1793390318 (Unix UTC); game=eso.live.12.1.6.3309674; API=101051; server=EU Megaserver; language=en
[InventoryCompanion tests] INFO Installation: InventoryCompanion; runtime version=1.5.0; DEV=false; ESO Plus=true; bank=closed
[InventoryCompanion tests] INFO Enabled add-on: AddonSelector; AddOnVersion=302030; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: InventoryCompanion; AddOnVersion=10500; state=2; outOfDate=false
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
[InventoryCompanion tests] PASS Live read-only scan: 100 scans, 771 occupied entries on final scan, bank closed
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

## Staged release test confirmation

Staged (UTC): 10/30/2026 19:44:46
Confirmed (UTC): 2026-10-30T20:02:28.8695022Z

Tim-P: Live/EU release 1.5.0 DEV=false AddOnVersion=10500: 79/79 passed, all timings pass, 100 live scans 235/500 ms. At 2026-10-30T20:02:03Z confirmed requested closed-group persistence, auto-collapsed group clicks and normal transfers: its all good - everything seems to work. Offline 74/74 passed. Full evidence in ReleaseReview.md.

