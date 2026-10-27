# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-26T15:24:42Z
Reviewer: AI assistant using Copilot SDK in VS Code (model identifier not exposed in this session)
Checked by: Tim-P
Release version: 1.01
Candidate SHA256: CD164BA0A316C05BDEA26F505EA245FCCCA8F9AEE77959AD8FBC79A2116D2AB8
Review status: APPROVED

## Review confirmations

- [x] ESOUI release guidance, upload rules, and linked prohibited-functionality guidance
- [x] House-chest transfers follow a player-opened interaction and supported protected APIs; record relevant precedent or unresolved concerns
- [x] Addon globals, saved-variable names and scope, UI names, and event filters
- [x] Current API versions and every non-optional dependency minimum version
- [x] Upload description, AI disclosure, credits, licensing, and install information
- [x] Release tests and exact ZIP contents

## v1.01 release review

- Scope: the frozen sibling `InventoryCompanion` installation, not the evolving development checkout. Its 28 files (manifest plus 27 runtime files) were verified against the staging hashes. The candidate identity above hashes the sorted `relative-path|SHA256` records joined with LF, encoded as UTF-8. Packaging verifies each ZIP entry against these original runtime hashes.
- Re-read the current ESOUI release best practices, upload rules, and prohibited-functionality forum guidance:
  - https://www.esoui.com/forums/showthread.php?t=10790
  - https://www.esoui.com/forums/showthread.php?t=11
  - https://www.esoui.com/forums/showthread.php?t=9865
- Limitation: the linked add-on-removal Wiki page returned HTTP 403/Cloudflare both through HTTP retrieval and the integrated browser. It was not successfully re-read; this review does not claim otherwise. The available current forum guidance was reviewed. No conflicting behavior or unresolved transfer-policy concern was identified in the inspected candidate. This is a release-readiness review, not an exhaustive security audit or a guarantee of ESOUI moderator acceptance.
- Transfer review: `Core/Events.lua` invokes bank handling through `EVENT_OPEN_BANK`. `Banking/BankTransfers.lua` checks `IsBankOpen()` at bulk/context entry and while processing the transfer queue; it uses `CallSecureProtected` for `PickupInventoryItem`, `PlaceInTransfer`, and `RequestMoveItem`. The candidate does not initiate bank interactions, player movement, or combat. This follows the established player-opened bank-transfer pattern recorded in the earlier review.
- Namespace and data review: Lua module state is rooted under `InventoryCompanion`; runtime startup uses the release name without the excluded development bootstrap. Saved variables remain `InventoryCompanion_SavedVariables`, through `ZO_SavedVars` account-wide and character-ID scopes. XML controls, scenes, binding actions, dialog identifiers, and event registrations use prefixed names; child controls use parent-derived names. Frequent slot events are filtered individually to backpack, craft bag, standard bank, and subscriber bank, registered conditionally, with UI refresh debounce.
- Dual-installation review: `Core/LoadCheck.lua` is first in both manifests and warns about an existing namespace before it can be overwritten. It intentionally does not make double-loading safe. Profiles must select one installation; both use the same saved variables. The release contains neither `Core/Development.lua` nor its manifest entry.
- API/dependency review: the candidate declares API 101051, confirmed by the author's earlier in-game report and the current live UI source README (12.1.6, 19 October 2026). No PTS client is available, so no unverified PTS API is declared. `LibAddonMenu-2.0>=43` matches the installed library's `AddOnVersion: 43` and the current public r43 release listing.
  - https://raw.githubusercontent.com/esoui/esoui/live/README.md
  - https://www.esoui.com/downloads/info7-LibAddonMenu.html
- Listing/author review: the upload-description source (`readme.md`, not a runtime candidate file) now puts the explicit AI disclosure first, the sole required dependency immediately after it, and describes the actual tracking/currency/banking behavior and simple extraction installation. No third-party runtime library or external asset is bundled; built-in ESO UI resources are referenced. The earlier author confirmation of distribution rights, credits, and listing claims is carried forward; Tim-P has also confirmed the candidate looks good in game and requested packaging. The upload form still requires the uploader's certification and any requested screenshot; this process does not upload anything.
- Packaging scope: exactly one `InventoryCompanion` folder, the original manifest/runtime bytes, and this review document. No SavedVariables, generated API definitions, editor files, executables, nested archives, development bootstrap, or project documents are included. The review is added only in a temporary packaging copy; the installed candidate stays unchanged.

## v1.01 staged candidate results

- Tim-P supplied in-game test output on 2026-10-26 after staging the v1.01 release candidate: **57/57 passed**.
- Performance results: 20 x 100-item scans / 20 rules in **71/2000 ms**; 100 slot-rule matches in **1/1000 ms**; 100 tracked-item slot updates in **1/2000 ms**; 100 live backpack/bank/craft-bag scans with the bank closed in **305/1000 ms**, with **980 occupied entries** on the final scan. All reported timings are below their respective limits.
- The pasted per-case output is truncated during the Alliance Points currency scenario. The summary reports all 57 tests passed; the complete per-case listing was not supplied.
- After receiving the results, SHA-256 verification confirmed all 28 staged manifest/runtime files and all 33 recorded source inputs still match the staging state.
- The earlier isolated packaging regression suite passed 88 assertions; the revised frozen-candidate workflow now passes 91 assertions, including candidate-identity mismatch rejection, DEV independence, build/minor version transitions, and byte-for-byte ZIP validation.
- Tim-P subsequently confirmed everything looks good in game and requested a ZIP. The v1.01 review above supersedes the pending review included in the earlier rc1 ZIP; the historical v1.00 approval below is retained only as history.
- At Tim-P's explicit request, tighter diagnostic limits apply only to development: 500 ms for each scan benchmark, 100 ms for slot-rule matching, and 200 ms for tracked-item updates. These edits are excluded from the tested v1.01 candidate and its release-candidate ZIP. No restaging or retesting is needed for that unchanged candidate.

## Historical v1.00 review (not current approval)

```text
Historical reviewed (UTC): 2026-10-26T08:51:45Z
Historical reviewer: Copilot SDK assistant (model identifier not exposed in this session)
Historical checked by: Tim-P
Historical release version: 1.00
Historical review status: APPROVED
```

### Historical review confirmations

- Historical confirmation: ESOUI release guidance, upload rules, and linked prohibited-functionality guidance
- Historical confirmation: House-chest transfers follow a player-opened interaction and supported protected APIs; record relevant precedent or unresolved concerns
- Historical confirmation: Addon globals, saved-variable names and scope, UI names, and event filters
- Historical confirmation: Current API versions and every non-optional dependency minimum version
- Historical confirmation: Upload description, AI disclosure, credits, licensing, and install information
- Historical confirmation: Release tests and exact ZIP contents

### Historical notes and references

- Reviewed the current ESOUI upload guidance, upload rules, prohibited-functionality guidance, and addon coding best practices:
  - https://www.esoui.com/forums/showthread.php?t=10790
  - https://www.esoui.com/forums/showthread.php?t=11
  - https://www.esoui.com/forums/showthread.php?t=9865
  - https://www.esoui.com/forums/showthread.php?t=9867
- The manifest declares `LibAddonMenu-2.0>=43`; the ESOUI library listing identifies r43 as the current listed release. The readme puts the AI disclosure first and the non-optional dependency immediately after it.
  - https://www.esoui.com/downloads/info7-175615.html
- Tim-P confirmed `/script d(GetAPIVersion())` returns `101051` on Live; no PTS client is available. The manifest now lists only the confirmed current Live API version, `101051`; the official ESOUI source repository README also identifies API 101051 as current. Recheck and add the PTS API version if a distinct PTS version becomes available.
- Source review: all addon-owned code is rooted under `InventoryCompanion`; saved variables use the addon's prefixed name and `ZO_SavedVars` account-wide/character-ID scopes. Scene, binding, dialog, and event identifiers use the addon prefix. Inventory slot-update listeners are filtered to relevant bags and enabled conditionally.
- Source review: bank transfers are guarded by `IsBankOpen()` and call ESO's `CallSecureProtected("RequestMoveItem", ...)`. House-chest merging is triggered by the bank-open event after the player opens the chest; no code starts bank/chest interactions or automates movement or combat. No unresolved transfer-policy concern was identified in the reviewed code.
- In-game test results provided by Tim-P: 57/57 passed. The run reported 20 x 100-item scans / 20 rules in 50/2000 ms, 100 slot-rule matches in 1/1000 ms, 100 tracked-item slot updates in 1/2000 ms, and 100 live read-only backpack/bank/craft-bag scans (bank closed) in 327/1000 ms, with 998 occupied entries on the final scan. The output reports PASS for the live read-only scan and all listed test cases.
- Tim-P confirmed the distribution-rights, credit/attribution, description, and installation claims for upload. The readme begins with an AI disclosure, lists the required dependency immediately after it, and explains that users should extract the add-on folder into `live\AddOns`.
- Packaging-only correction: the v1.00 archive was rebuilt from the previously approved v1.00 ZIP after extraction. Runtime files were not changed; `ReleaseReview.md` now sits beside the manifest inside the top-level `InventoryCompanion` folder so the archive extracts directly into `live\AddOns`.
- The package script validates the archive entry set against the manifest-listed runtime files, manifest, and root-level review document, and rejects unexpected or missing entries. It excludes generated API files, SavedVariables, development docs, and unrelated repository files.
- The manifest-format, event-filter, saved-variable, and add-on-removal Wiki references were attempted in the browser but returned 403/Cloudflare. The API version was confirmed in-game and against the official ESOUI source repository README; source review confirmed the saved-variable and event-filter use. No unresolved release-policy concern was identified.

## Staged release test confirmation

Staged (UTC): 10/26/2026 15:02:12
Confirmed (UTC): 2026-10-26T15:25:41.4231561Z

Tim-P reported 57/57 passed on the frozen v1.01 candidate; synthetic scans 71/2000 ms; 100 slot-rule matches 1/1000 ms; 100 tracked-item updates 1/2000 ms; 100 live scans (bank closed) 305/1000 ms, 980 occupied entries. Tim-P subsequently confirmed everything looks good in game and requested release packaging. DEV-only tighter limits are excluded.

