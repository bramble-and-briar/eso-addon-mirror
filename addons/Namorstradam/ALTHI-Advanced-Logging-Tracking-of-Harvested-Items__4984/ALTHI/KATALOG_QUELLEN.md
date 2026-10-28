# Material catalog and sources – ALTHI 1.0.0

The catalog starts with 300 material-ID candidates and 4,015 recipe lookup IDs. Candidates are accepted only if ESO resolves a valid name and a supported material type (with explicit identities for selected special materials). Recipes themselves are not tracked as gathered materials.

The client supplies names, icons, quality, valid style/trait material links, current recipe-book ingredient links and supported newly observed loot/stock materials. Lookup work is spread across small background batches and cached per addon/API version. Possession of seed items or lookup recipes is not required. Unavailable client data is ignored; this is not a complete database export or a claim that every historical candidate is still obtainable.

Supported material groups cover equipment crafting, alchemy, enchanting, furnishing, styles/traits, provisioning and fishing. Fish meat and Perfect Roe retain their fishing classification. Native recipe-book discovery supplements historical recipe IDs; unknown fishing catches can be added when caught. A known item/source is distinct from a session-acquisition event.

## Data references

- CraftStore (Rhyono), ingredients/runes/solvents and recipe IDs: https://github.com/Rhyono/CraftStore/blob/master/CraftStore_VarInit.lua
- LibLazyCrafting (Dolgubon), material tiers: https://github.com/Dolgubon/LibLazyCrafting/blob/master/Smithing.lua
- UESP, reagent/solvent identities: https://github.com/uesp/uesp-esolog/blob/master/esoPotionData.php
- HarvestMap, published node-material identity mappings: https://github.com/seisenreich/HarvestMap/blob/master/Modules/HarvestMap/Main/PinTypes.lua . Historical jewelry grain/trait mappings are not treated as proof of current node drops.
- Additional identity cross-checks: https://eso-hub.com/en/trading/115026 (Aetherial Dust), https://eso-hub.com/en/trading/56862 and https://eso-hub.com/en/trading/56863 (Nirncrux), https://eso-hub.com/en/trading/139411 and https://eso-hub.com/en/trading/139417 (Aurbic Amber), https://eso-hub.com/en/trading/139413 and https://eso-hub.com/en/trading/139419 (Dibellium), https://eso-hub.com/en/trading/204881 (Luminous Ink), https://eso-hub.com/en/trading/114891 (Clean Pelt).
- U51 reagent IDs 224357–224360: LibAlchemy author changelog and documented community references listed in MATERIALQUELLEN.md.
- Votan's Fisherman fishing/bait facts and Votan's Fish Fillet public workflow/API reference: acknowledged in AUTHORS.md; no third-party implementation or library is bundled.

Source snapshots, build tools, tests and personal item observations remain in the development workspace and are excluded from the public release. Original addon code is not obtained by executing these source tables. See AUTHORS.md and LICENSE.txt for attribution and permissions.
