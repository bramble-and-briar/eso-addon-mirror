RaccoonQuestData 1.0 - data and diagnostics notes
==================================================

Purpose
-------
RaccoonQuestData is Tamriel Progress Map's small internal quest metadata layer.
It separates Base-game/free side quests from Chapter/DLC side quests without
copying a large third-party quest database into the addon.

Sources and trust policy
------------------------
1. The live ESO API provides quest names, zone IDs, type, repeatability and the
   account's completed-quest history.
2. LibQuestData is optional. When installed, its quest IDs are used as extra
   discovery/provenance. Records marked with its placeholder API 100003 are not
   treated as verified merely because they exist in that library.
3. A bounded ESO API fallback can discover candidate IDs if the library is not
   installed. A fallback hit alone remains unknown and does not enter totals.
4. Explicit includes/excludes and mutually exclusive groups live in the small,
   reviewable RaccoonQuestExceptions.lua registry.

Only a completed quest, non-placeholder LibQuestData provenance, or a reviewed
explicit include verifies availability. Repeatable, non-standard, priority and
unknown-zone records are excluded from the two visible totals. This deliberately
produces no artificial 100%.

The reported 1098/1171 result and the alleged 73 missing quests could not be
proved from public/static data alone. TPM therefore exposes evidence instead of
adding 73 speculative records. Run `/tpm questdebug` on an affected account:

  /tpm questdebug
  /tpm questdebug unknown 1
  /tpm questdebug excluded 1
  /tpm questdebug id <ID>

Pages contain at most eight records. Filters: suspicious, all, base, dlc,
unknown, excluded, open and complete. Output includes ID, name, zone/story zone,
type, repeatability, classification, completion, source and exclusion reasons.

Progress policy
---------------
The side-quest rows are journal statistics only. They never participate in ESO's
Zone Guide objective totals, category averages or the global Tamriel percentage.

Fragment policy
---------------
Combination fragments are handled separately by RaccoonFragmentData. All totals
are read live from the ESO combination APIs; there is no fixed 202 total. Past
fragment state consumed or changed by a completed combination may be impossible
for the API to reconstruct, so the detail window marks that history as unreliable.
