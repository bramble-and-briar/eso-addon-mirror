RPQuest - Custom Roleplay Quests for The Elder Scrolls Online
==============================================================

Manual Installation:
1. Extract the contents of RPQuest.zip.
2. Copy the "RPQuest" folder into your ESO AddOns directory:
   - Windows: %USERPROFILE%\Documents\Elder Scrolls Online\live\AddOns\
   - macOS:   ~/Documents/Elder Scrolls Online/live/AddOns/
3. Verify the path looks like:
   ...\AddOns\RPQuest\RPQuest.txt
4. Launch ESO, open Add-Ons at the character select screen, and enable RPQuest.

Usage:
- Open the Quest Journal (J) and select the RPQuests tab in the top-right icons.
- New players start with a built-in 3-pill progressive Tutorial Pack in
  Daggerfall (Tutorial I in Pending, unlocking II and III on completion;
  optional, never re-seeded after being abandoned or deleted, replayable via
  "Reset", and copyable into Preparing as editable templates).
- Aim at any living NPC or another player and press your "Capture Target Under
  Reticle (NPC)" keybind to add NPC elimination or player duel objectives.
- Click "+ New" to create a quest (optionally assigning a Quest Icon: Black Hand,
  Search, or Steal; creating pure free-form quests completed manually via
  "Complete"; configuring Required discovery points, Sequential order,
  reordering discovery points, or Required NPC dialogues whose execution
  persists across reloads, auto-completes dialogue-only quests, and fails
  quests on resolution if any Required objective was missed), navigate form
  fields with Tab / Shift+Tab, or use "Test Quest" / "Reset" on prepared quests.
- Assign a recipient (@AccountName), optional To (Character), and optionally
  choose a From (Character) from your account characters in the editor, then
  click "Send Quest" in the quest details pane to send via in-game mail.
- Incoming quests appear automatically in Pending (Accept or Reject), and
  Accepted, Rejected, Completed, and Failed results are reported back to the
  Quest Master automatically via mail (separately from Draft/Sent/Received
  lifecycle). "Auto-open RPQuests journal when receiving a new quest" is
  enabled by default (skipped in combat) and can be toggled off at the
  bottom of the quest list panel.
- In the quest details pane, view any Master map-hiding recommendation notice,
  independently toggle "Search Areas", "Location", and "Discovery" in
  MAP MARKERS (all off by default for players, while creators see discovery
  areas in purple automatically and search/zoomed-out reference areas render
  in pulsing emerald green with deterministic offsets), or use "Show on Map"
  whenever a map/area is defined. Entering a pending active target's search area
  or exact location also illuminates the compass border in gold/amber
  (independent of map toggles, excluding hidden discovery points).
- Bind keys under Settings -> Controls -> RPQuest - Custom Quests.

Supported Languages:
- English (en), German (de), Spanish (es), French (fr), Japanese (jp), Russian (ru), Simplified Chinese (zh)

AI Disclosure & Credits:
- Author: JerbilX
- AI Assistance Disclosure: AI coding assistants were used during development for
  code drafting, refactoring, localization, documentation, and unit tests. All
  design, in-game testing, and final reviews were directed and verified by the author.
- Support: https://ko-fi.com/Q7W02BAKN7

Full documentation: see README.md (English) or https://github.com/JerbilX/RPQuests
License: GNU General Public License v3.0 (see LICENSE)
