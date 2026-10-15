# Satuve Xbox UI 1.7.19

- Replaces Satuve's separate minimap renderer with a bridge to Votan's Minimap 2.2.2.
- Uses Votan's dedicated native ZOS minimap mode instead of clipping or reparenting the full world map.
- Requires VotansMiniMap, LibAsync and LibHarvensAddonSettings in addition to the existing controller libraries.
- The Satuve controller menu controls Votan's enable state, visible pixel size, transparency, title, pin scale and common zoom values.
- Minimap size remains 200-500 pixels; 200 means a 200x200 visible native map area.
- Full world-map mode always restores alpha 100% and remains independent from the minimap size/transparency.
- Removes the old SXUI_MinimapCore runtime, viewport parenting and 250 ms correction loop.
- Does not bundle or copy Votan's source code.
