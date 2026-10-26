ATLAS MINI MAP 1.0.6
by @TheGreyWolf98

UPLOAD
Use AtlasMiniMap.addon with the Bethesda ESO add-on uploader.
Version 1.0.6 / AddOnVersion 9 / API 101050 101051.
Existing TGWAtlasMiniMapSaved settings are retained. Fishing spots default ON.

FISHING SPOTS
4,357 recorded fishing-hole coordinates across 106 map tiles are bundled, using the same coordinate facts as MasterBaiter. MasterBaiter and Atlas do not need to be installed or enabled for fishing spots to appear.
Each water type uses a different fish icon and tint: ocean/saltwater is cyan, lake is green, river is blue and foul water is purple. Coverage varies by zone and map floor. These are possible spawn locations, not a live indicator of active fishing holes. Completed fishing achievements do not hide spots from the minimap.
Open /minimap and toggle Fishing spots to show or hide them independently of Atlas layers. Points use the existing five-second location refresh, viewport clipping and reusable pin controls. No extra update worker is added; the existing combined 512-point limit is retained.

CONTROLS
/minimap opens settings. D-pad selects in two columns; A toggles or increases, LT decreases and RT increases. X opens Socials / Support; Y refreshes the preview; RB resets defaults. B closes, or returns from Socials to settings.
/minimap toggle, /minimap reset, /minimap socials and /minimap support remain available. Settings cannot open during combat. Mouse users can click settings rows.

FEATURES
North-up map, digital clock, FPS, latency, native services/traders and quest icons, optional Atlas layers, fishing spots, waypoint direction and antiquity dig areas. Dig areas use ESO's exposed current-map data. Arbitrary third-party custom pins and group markers are not included. No external libraries required.

CREDITS
Fishing coordinate facts reused from MasterBaiter/FishingData.lua, researched from Map Pins by Hoft, art1ink, Gamer_sa22 and community contributors.
Source: https://github.com/art1ink/MapPins
No Map Pins executable code or artwork is bundled. Fish icons reference ESO's built-in assets.

SOCIALS
Ko-fi: https://ko-fi.com/thegreywolf98
Instagram: https://www.instagram.com/thegreywolf_98/
Discord: https://discord.gg/Fp9RSaeU8h
Support is optional; the add-on remains free.

VALIDATION
Local checks cover eleven settings, navigation across uneven columns, saved preferences, reset, social/back/close cleanup, standalone fishing without other add-ons, water styles, duplicate and invalid coordinates, crop visibility, control reuse and map changes. Map tile drawing and existing movement timing are retained. Live Xbox appearance and behaviour still need testing.
