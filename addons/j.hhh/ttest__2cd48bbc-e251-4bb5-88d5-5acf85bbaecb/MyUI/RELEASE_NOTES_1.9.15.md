# Satuve Xbox UI 1.9.15

- Fixes controller entry into the existing far-left `BUI_Panel` sidebar from ESO's `mainMenuGamepad` scene.
- Builds navigation dynamically from visible, enabled sidebar controls in top-to-bottom order.
- Adds native D-Pad Up/Down selection, A activation, and Right/B return to the normal menu.
- Pauses and restores ESO's current main-menu list so its selected entry is preserved.
- Shows the native Select and Back keybind hints while sidebar focus is active.
- Removes all sidebar input ownership when the main-menu scene closes and adds no permanent update loop.
- Does not change Combat Log or Statistics code.
