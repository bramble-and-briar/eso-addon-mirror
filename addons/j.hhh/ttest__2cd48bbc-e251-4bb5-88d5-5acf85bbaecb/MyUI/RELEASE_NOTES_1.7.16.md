# Satuve Xbox UI 1.7.16

- The Minimap size setting now maps directly to pixels: 200 means 200x200 px and 500 means 500x500 px.
- Changing the size immediately updates the live Minimap container, background, label, native map mode, and map control.
- The size setting no longer depends on the general Minimap reinitialization path, which could defer while a gamepad menu was open and leave the visible Minimap at its previous size.
- The controller range remains 200-500 in 20 px steps.
- No other Minimap slider, full world map behavior, Frame Editor behavior, localization, or SavedVariables format was changed.
