ATLAS 1.0.7
by @TheGreyWolf98

UPLOAD
Use Atlas/Atlas.addon in the Bethesda ESO add-on uploader.
Version 1.0.7, AddOnVersion 10007, API 101051. Existing AtlasSaved settings are retained. The two new layers default ON. No external libraries required.

CONTROLS
/atlas opens or closes settings. D-pad selects, A toggles, Y refreshes and B closes. X opens Socials / Support; B returns to Atlas.
/atlas socials and /atlas support open the social page.
/atlas refresh rebuilds pins. /atlas all on and /atlas all off affect all fifteen pin layers, preserving filter/style switches.

LAYERS
Skyshards, Shalidor lorebooks, treasure-map digs, surveys, interior bosses, delves, world bosses, public dungeons, events, wayshrines, landmarks, Mundus stones, set crafting stations, ordinary treasure chests and Thieves Guild troves.

CHESTS AND TROVES
These two layers are separate from treasure-map digs. Bundled coordinate facts contain 11,947 chest locations on 575 map tiles and 1,467 trove locations on 93 map tiles, derived from MapPins community records. Coverage varies by zone and floor; it is not a complete catalogue.
Pins mark possible spawn sites, not live containers. A site can be empty, looted or awaiting respawn. The trove layer does not check Thieves Guild membership or Finders Keepers access.
Atlas also remembers new chest/trove sites when a successful interaction reports a recognized container name. Recording uses the player's position near the container, so learned points are approximate. English, German, French, Spanish, Russian and Japanese names are recognized. The viewed map must match the player's location; Atlas never changes your viewed map to record a point. Other viewed maps, failed interactions and invalid coordinates are ignored. Nearby recorded sites are deduplicated. Additional saved discoveries are capped at 2,000 total and 500 per map/layer.
Hide-collected affects books and skyshards. Backpack-only affects maps and surveys. Neither hides chest/trove spawn sites.

FASTER LOADING
The worker now runs every 10ms rather than 50ms, batches up to 16 candidate checks between cooperative yields, and skips renderer jobs while their coordinates are still building. All eight native discovery layers share one POI scan per map/cache refresh. Native refreshes no longer reserve an otherwise empty tick.
Each tick stops after approximately 2ms, 96 resumes or 32 created pins, whichever limit is reached first. Individual engine calls cannot be interrupted. Symbols and neon rings share the same cap. Combat pauses work; map changes discard stale jobs and caches. Only the viewed map is cached. The survey/map backpack scan remains shared.
These limits are a starting point for Xbox testing, not a guarantee of console frame time.

VALIDATION
Local mocked checks cover pin/time budgets, shared scans and caches, filters, combat pause, map changes, discovery refresh, all nineteen switches, social/back/close cleanup, error recovery, chest/trove separation and discovery deduplication.
A synthetic case with 1,200 skyshard candidates and 320 POIs produced the same 768 pins. 1.0.6 used 1,035 scheduler ticks (51.75 seconds of configured delay); 1.0.7 used 31 ticks (0.31 seconds). POI reads fell from 2,560 to 320. This isolates scheduling overhead with a mocked zero-cost game clock; real Xbox APIs and rendering will take longer.
Lua syntax, package paths, coordinate bounds and assets are checked. Live Xbox speed, appearance and controller behaviour still need testing.

OTHER LIMITS
Lorebooks cover Shalidor records rather than all Eidetic Memory. Group-dungeon interior coverage is incomplete. Event pins show sites, not live events. Wayshrines do not unlock travel. Carried-only checks the current backpack; maps and survey reports are still required. Disable overlapping pin layers in other add-ons if desired.

SOCIALS
Ko-fi: https://ko-fi.com/thegreywolf98
Instagram: https://www.instagram.com/thegreywolf_98/
Discord: https://discord.gg/Fp9RSaeU8h
The social-page QR opens Ko-fi. Support is optional; Atlas remains free.
