Antiquity Atlas 0.13.3 - full bundled-data edition
Author: TjeEmpejoj

AI disclosure: Developed with code-generation assistance from ChatGPT/Codex.
Automated syntax and mocked-API checks are documented; these do not establish live
in-game compatibility, performance or correctness of every source.

REQUIRED: LibZone >= 9.01 (AddOnVersion >= 901).
https://www.esoui.com/downloads/info2171
Optional: Map Pins and HarvestMap for additional current-account recorded locations.
Lead List, Display Leads and LibSets do not need to be installed or enabled.

FULL DATA
All 774 source records, 153 source-region exceptions and 35 set reward item mappings
from the existing personal catalog are bundled. No runtime access to ILeadList or
Lead List is used. English source/search fallback is retained independently of any
provider localization. Atlas UI/source-label translation is English/Russian.
Data updates now require an Atlas update; updating Lead List alone cannot update this
independent snapshot. Existing coverage is retained, not enlarged or fully fact-verified.

FEATURES
Reward cards, component leads, search, filters, mythic item tooltips and reward previews.
Assembly progress sorts by current readiness percentage: held OR excavated parts, counted
once per required slot. Multi-part rewards precede single-part rewards; each section
keeps descending readiness. Previous completed assemblies do not fill the next assembly.
Left click opens known matching boss positions first, falling back to an instance entrance
or source map when no matching positions are available. Right click opens the excavation
region. Shift + left click requests the entrance/source map. Multiple locations offer a choice.
Resource sources draw matching recorded spawn sites. Locations do not guarantee a live
object or lead drop. High Isle lead 522 needs trove/safebox records; ordinary chests are
not substituted. Optional providers' settings and recordings are not changed.

INSTALLATION
Exit ESO, back up and replace the AntiquityAtlas folder completely in
Documents/Elder Scrolls Online/live/AddOns. Keep SavedVariables.
This is an alternative edition with the same addon ID, not a second simultaneous install.
Enable LibZone and Atlas; use /atlas or /antiquityatlas. /atlascheck checks numeric routes.
Install and backup status is documented separately by the packaging task.

NEW ROUTING LIMITATION
High Isle world-boss POIs for leads 472/475/520 are numeric candidates inherited from the
latest personal fix. Their POI identities have not been verified inside ESO; validate
Mornard Falls, Serpent Bog and Faun Falls in game. Lead 473 concerns ordinary coastal
sea adders; it offers High Isle/Summerset regions without invented fixed spawn points.

PROVENANCE / PUBLIC SUBMISSION
The bundled acquisition database is adapted from Lead List / Display Leads and their
contributors, not claimed as independently authored by TjeEmpejoj. Full credits and the
unresolved redistribution status are in THIRD_PARTY_NOTICES.md. The upstream author's
statement acknowledging others' rights is not represented as permission to redistribute.
Map Pins coordinates retain their included MIT permission. LibZone implementation and
geographic tables are not bundled; its public API supplies geographic data. LibSets is
not needed. No TTC or other addon is bundled.

LIMITATIONS / VALIDATION
PC keyboard/mouse only; gamepad and console support are not claimed. Detailed source
correctness/current availability is not independently certified. Tests use mocked ESO UI
and actual local library getters; real ESO validation of this exact release remains pending. Existing user screenshots
illustrate the UI but do not establish every map route or this release load order.
No account data or private provider recordings are included. Atlas saves its window scale.
No license for the full original Atlas project is assigned by this packaging change.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
