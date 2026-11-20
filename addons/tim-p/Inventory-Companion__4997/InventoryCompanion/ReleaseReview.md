# Hotfix Release Waiver

Status: [Hotfix Waiver - Package Verified]
Waiver authorized by: @Tim-P
Waiver authorized (UTC): 2026-11-20T01:22:37Z
Release version: 1.8.1
Hotfix reason: Small settings visibility and HUD clearance fixes for an urgent patch release.
Source identity: DEV commit c6e5aff5fe3bfb3044dc4d52a0c9729476f35332 plus worktree changes in Tracking\PanelLayout.lua and Project\Tests\PanelLayoutTests.lua; runtime files were not edited after DEV UAT.
Full standards review: SKIPPED
Waiver scope: Skip the full release standards review for this hotfix only.
Candidate SHA256: CBAF20A2B7876A5630C5F5A9587933B694B26D1F2BDBFCE53C5DD203D44B30DB
Focused synthetic tests: 19/19 passed
DEV diagnostic: 88/88 passed; runtime version=1.8.1
DEV diagnostic evidence: Project\Tests\Evidence\1.8.1-20261120-hotfix-dev-diagnostics.txt
UAT runtime identity: 66CEEED34B3F165D2E08F11400C41C43A92AE391024BAF1410B22192CF885C27
DEV UAT report: The author confirms user testing was fine; no issues were reported.
Package verification: PASS — Finalize verified the package and retained archive.
Publication approval: NOT GRANTED

## What this waiver means

The author explicitly authorized skipping the full release standards review for
this hotfix. No full code, standards, or documentation review is claimed by this
record. Focused synthetic tests and UAT performed in DEV must identify the
release runtime version and evidence. The staging process then verifies the
candidate identity and package contents, and Finalize verifies the archive hash.
The final author approval of the exact package remains required. This waiver
does not authorize staging, ESOUI upload, or GitHub publication by itself.

DEV UAT is acceptable only when the package is a direct runtime-file port of
the tested DEV version. Any runtime code changes after UAT require repeating
the relevant tests and updating this record.

## Final package

Finalize records package verification in this document. The final ZIP SHA-256 is
provided separately with the final package approval because embedding a ZIP's
own hash inside that ZIP would be self-referential.
