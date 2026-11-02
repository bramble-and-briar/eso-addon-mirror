# Authors / Credits

**Althi & Roman (@namorstradam & @bakaroobanzai)**

Althi is the name used for the OpenAI ChatGPT/Codex assistant supporting Roman with programming, documentation and translation drafts. Roman directs development and tests the addon in ESO.

Item names, quality colors, icons, currency textures and localized trait names are read from the ESO client; game assets are not bundled in this archive. ESO and third-party addon names identify their respective products.

Optional integrations: LibAddonMenu-2.0, Awesome Guild Store, Tamriel Trade Centre, Arkadius' Trade Tools Master Merchant and LibHistoire. No copies of these libraries/addons are included or required as a group.

Data/provenance references: MATERIALQUELLEN.md and KATALOG_QUELLEN.md. Material tables were assembled from documented IDs and client APIs; external source snapshots and tools remain in the development project, outside the public archive. Farming Party Plus, by DeviousCode, was an inspiration/development reference; no Farming Party Plus code is included and it is not a dependency.

Material information was cross-checked against UESP, CraftStore (Rhyono), LibLazyCrafting (Dolgubon), HarvestMap and ESO-Hub. Their published material/recipe IDs and source information informed the data tables; source URLs and limits are documented in KATALOG_QUELLEN.md and MATERIALQUELLEN.md. Native ESO UI/API references guided integration. These acknowledgements do not claim ownership of third-party data or assets.

Original ALTHI permissions are stated in LICENSE.txt, following Roman's chosen restrictions. Those restrictions do not apply to third-party material or grant rights Roman does not hold.

Fishing module: public ESO fishing/inventory/crafting APIs; Votan’s Fisherman bait-index, water-label and common-fish-ID data were consulted as factual references. Votan’s Fish Fillet was reviewed for its public user-facing workflow and supported native API calls. No third-party program logic is copied or bundled; neither addon is a dependency. Fishing container IDs were cross-checked with ESO-Hub. See README.md and KNOWN_ISSUES.md.

The small fishing-hook texture in art/fishing_hook.dds is an original ALTHI asset, reproducible using tools/build_fishing_icon.py in the development project. Native fish and inventory icons are referenced from ESO, not bundled.

Gold module: native ESO API 101051 documentation (https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt), checked 2026-10-29 for currency events, character roster and guild purchase context. Original accounting implementation; no external gold-addon implementation copied.

Gold sale-mail follow-up: Awesome Guild Store by sirinsidiator was consulted read-only for native sold-mail subject labels and the existing mailAugmentationData record fields. Optional ALTHI integration reads a matching existing mail-ID association; no AGS implementation is copied or bundled. Native currency/mail/guild-history APIs are used by original ALTHI code. Native references: https://github.com/esoui/esoui/blob/live/esoui/ingame/mail/mailinbox_shared.lua and ESOUIDocumentation.txt.

Optional gold-history integration uses LibHistoire by sirinsidiator through its documented v2 API. No library implementation is included. Library API/stop semantics and native history-range interfaces guided original ALTHI attribution logic; missing/ambiguous history is not treated as a proven sale identity.

Gold overview follow-up (2026-10-30): original account/character presentation and bounded dated trade summaries using existing LibHistoire scalar event fields and native time/currency APIs. No third-party implementation copied.

Suite follow-up (2026-10-30): original settings-only historical import through LibHistoire v2 StartIteratingTimeRange; native GetGuildKioskCycleTimes, GetTradingHousePostPriceInfo and trader-event tax fields checked against API101051. Awesome Guild Store MailInvoice was consulted read-only to confirm that event tax is the guild-bank share, separate from the remaining house cut. Native ESO inventory, bank-service, character, chat-settings and mail icons are referenced, not bundled. No external implementation copied.

Profession circle: original ALTHI asset, reproducible with tools/build_profession_ring.py. Profession textures are referenced from ESO, not bundled. Native asset paths were checked against ESO/ESOUI references and existing item metadata; no external addon implementation copied. Public camera-mode, movement and indexed character APIs checked against native API101051 documentation.

Survey-stock follow-up: BeamMeUp (DeadSoon, Gamer1986PAN, Baertram) TeleporterGlobals and Dolgubon's Lazy Writ Crafter (Dolgubon / Joseph Heinzle) SlashCommands/LootHandler were consulted read-only for factual item IDs (six tradable survey envelopes and six Auridon survey references). Original ALTHI classification uses native localized item metadata; no third-party survey implementation or full mapping database is copied or bundled. Native jewelry craft-bag and survey-scroll texture paths checked against BeamMeUp / Awesome Guild Store references; ESO assets remain referenced only. Native API101051 documentation checked on 2026-10-30.

Test.12 visibility icons are original ALTHI assets, reproducible with tools/build_visibility_icons.py. Native inventoryslot.lua was consulted for normal item use versus required combination confirmation; original ALTHI click handler uses the documented protected API without replacing native functions. Native icon for the unidentified report comes from its ESO item metadata.

Survey implementation: native API101051 label measuring and protected-item cooldown/use interfaces plus inventoryslot.lua were checked again. Dolgubon's Lazy Writ Crafter LootHandler.lua was consulted read-only to confirm existing outside-combat container usage through CallSecureProtected. No implementation copied; original ALTHI bounded series waits for native inventory results, preserves confirmations and provides stop/timeout guards.

Survey implementation: ESO native mailinbox_shared.lua, keyboard mail inbox/main menu and ingamescenemanager.lua guided original mail access and persistent HUD behavior. BeamMeUp (DeadSoon, Gamer1986PAN, Baertram) core/List.lua and TeleporterChecker.lua consulted read-only for native roster/jump API usage; no implementation, retry logic, data table or graphics copied. Native wayshrine texture path checked against the ESOUI Client Textures/DDS List (thread 648). No additional dependency. Native API101051 documentation rechecked 2026-10-31.

Survey implementation: native API101051, mappin.lua and ingamedialogs.lua consulted for unlocked wayshrine enumeration and RECALL_CONFIRM handoff, live costs and native confirmation keys. Original ALTHI combined profession/zone UI and bounded multi-profession opening; no third-party implementation copied. ESO jewelry service-pin asset referenced, not bundled; path checked against BeamMeUp TeleporterGlobals.

Survey implementation: native ESO itemfilterutils.lua asset paths, worldmap.lua map manager, generic zo_dialog.lua and API101051 item-refinement/currency interfaces consulted. Original shared tooltip, folding survey HUD, presentation-only material mapping and revalidated cost-confirmation implementation. No external implementation or native graphic files bundled. Diminished Aetherial Dust is observed through native item metadata (ID120078), not a fabricated catalog entry.

Survey implementation: original event-aware survey caches, UTF-8-safe numbered-zone normalization, region status/position persistence and guild separators. Native API101051 zone and fast-travel-network events checked. Local call-count tests do not claim actual game performance measurements. No third-party implementation copied.


Refining observation: native ESO UI/API documentation for PrepareDeconstructMessage, AddItemToDeconstructMessage, SecurePostHook, craft events and last-crafting-result queries. Native extraction flow consulted for API semantics; no third-party addon implementation copied.
https://github.com/esoui/esoui/blob/live/esoui/ingame/crafting/smithingextraction_shared.lua
https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt
