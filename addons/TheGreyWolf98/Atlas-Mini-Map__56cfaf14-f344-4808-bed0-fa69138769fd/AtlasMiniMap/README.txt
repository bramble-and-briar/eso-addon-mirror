ATLAS MINI MAP 1.0.3
by @TheGreyWolf98

INSTALL
Replace the existing AtlasMiniMap folder with the folder in this archive.
Reload UI. Saved settings are retained. /minimap opens controller settings.
/minimap toggle toggles visibility; /minimap reset restores defaults.
No external libraries required; optional Atlas layers remain supported.

CHANGES
- Large clock in a compact 42px header directly against the map.
- FPS and latency moved below the map, beneath the zone name.
- Native service/trader icons and journal quest/breadcrumb icons added.
- Native POIs and services stay visible when Atlas layers are enabled.
- Duplicate icons at the same position are removed.
- Dig areas use ESO's main-map colours, 39% shading and textured 3px border.
- Larger pins and waypoint/edge arrows retained from 1.0.2.
- Author consistently @TheGreyWolf98.

Scrying overlays use only revealed search-area borders on the current map;
they do not reveal the exact excavation spot. Quest icons use ESO's journal
quest location cache and update when quest positions change. Group markers
and arbitrary third-party custom pins are not included. Atlas's extra ring
styling is not copied. The full map remains independent and north-up.

CHECK IN GAME
1. Check 12/24-hour clock at the smallest and largest map sizes.
2. Visit Vivec City: check trader, bank and other visible service icons.
3. Track a quest: check objective and doorway markers on the current map.
4. Toggle Atlas layers: native services and quests should stay present.
5. Scry an antiquity: compare area shading and outline with the main map.
6. Place/clear a waypoint; check nearby marker and distant edge arrow.
7. Open/close the full map; finish a dig; check refresh and isolation.

VALIDATION
Mocked UI/API tests passed for compact layout and screen bounds, combined
service/quest/POI/Atlas sources, deduplication, quest refresh, native dig styles,
clipping, excavation cleanup, waypoint changes and full-map isolation.
Xbox visual and live API behaviour still require in-game testing.
