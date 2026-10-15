# Satuve Xbox UI 1.7.18

- Activates the existing addon-owned `BUI_MinimapViewport` as the actual visible Minimap window.
- ESO's full-size map remains active internally, but the native scroll control is displayed only through the selected 200-500 px clipping square.
- The stock world-map root, frame, and gamepad floor/level controls remain hidden while the HUD Minimap is active.
- Opening the full world map detaches the viewport layout and restores the native map presentation.
- The existing 250 ms follow update now repairs the viewport only when ESO changes its parent, size, or root visibility; no additional repeating timer was added.
