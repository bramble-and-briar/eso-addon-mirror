# Third-party contributions and provenance

This publication edition is maintained by **TjeEmpejoj**, with ChatGPT/Codex assistance.

## Bundled source catalog and attribution

- **Lead List 51.0.1**, Irhak: https://www.esoui.com/downloads/info4159. Based on **Display Leads**, remosito: https://www.esoui.com/downloads/info2651. The bundled LeadSources_en.lua retains 774 source records; EmbeddedData.lua retains 153 source-region exceptions and 35 set reward item mappings from the earlier personal build. These are adapted upstream data, not an independently researched Atlas database. No Lead List UI, event handlers, bootstrap or save manager is included, and Lead List need not be installed.
- Original detailed location data: **@inklings**, transformed by **frozenhamster**; **remosito** for Display Leads; **Gabriel_H**, **Irhak** and other contributors for updates. Upstream translation credits: **Hasenwarrior**, **Orejana**, **Jakez31**, **AWEyeforaneye**, **FusRoDah** and **sora0v0**. The upstream Chinese/Japanese/German/French/Russian translation files are not bundled; Atlas retains its own small EN/RU UI/source-label translation layer.

### Rights status of the acquisition database

The Lead List description says: "I cannot claim ownership or copyright to anything here except meshing it all together." This acknowledges upstream authorship; it is not treated here as an explicit redistribution license or a waiver of the original contributors' rights. No separate permission covering redistribution of all bundled acquisition texts has been established by this task. Credits are preserved, but credits alone do not establish permission. This standalone package meets the requested technical behavior; its database redistribution status remains unresolved for public submission. Do not describe it as an independently authored or permission-cleared database. The developer has not contacted the upstream authors or submitted this archive to ESOUI.

## External providers (not distributed)

- **LibZone**, Baertram, geographical work credited upstream to IsJustaGhost: https://www.esoui.com/downloads/info2171. Atlas calls GetZoneMapPinInfo and GetZoneGeographicalParentZoneId; neither implementation nor geographic/name tables are bundled. The inspected 9.01 license explicitly allows use from other ESO addons through its API.
- **LibSets**, Baertram, was a research reference in earlier personal builds. The publication edition contains no extracted LibSets zone/parent/node/name table and does not require LibSets. Prior influence is acknowledged; extracted geography is replaced by runtime LibZone calls and native ESO names.

## Bundled licensed material

BossLocations.lua (Bosses coordinates) and ResourceData.lua (selected ChestData, FishingNodes and TreasureMaps coordinates) include selected **Map Pins 1.100.22** data. Authors: Hoft, art1ink, gamersa22 and the contributors named upstream. Permission and warranty terms are preserved in MAP_PINS_LICENSE.txt. Only these selected data portions carry that MIT permission; it does not relicense all Atlas code.

## Original Atlas work and research

The catalog UI, reward grouping, current-assembly model, filtering, previews, numeric map routing, source classifications, guarded pin display and provider adapters are Atlas implementation. Lead List's data supplied the factual basis for source classifications/routes; this influence is credited and those source descriptions remain bundled with the above rights status. Five named-boss clarifications were researched using game-maps.com and ESO Hub. Those sites were references for factual names, not copied UI or guide articles. Source classifications are not an independently sourced replacement acquisition database.

Map Pins and HarvestMap optionally supply current-account recordings through existing data/cache interfaces. Neither provider's runtime implementation nor private recording database is bundled. Atlas does not change their configuration or recordings. Provider interfaces may change.

ESO native names, textures and rewards are supplied by ZeniMax's game APIs. All third-party rights remain with their owners. No upstream author endorsement is claimed.
