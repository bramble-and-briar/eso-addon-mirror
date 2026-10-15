# Satuve Xbox UI 1.7.17

- Fixes ESO's gamepad map layout replacing the selected Minimap size with the large gamepad map dimensions.
- The selected value now sizes both the Bandit Minimap root and the native ESO map scroll viewport, which clips the rendered map to the requested square.
- The layout is reapplied after the stock world-map fragment refresh because that refresh can restore ESO's large gamepad dimensions.
- Opening the full world map restores its native frame and layout; this clipping is active only for the HUD Minimap.
- Minimap range remains 200-500 in 20 px steps. No other setting or Frame Editor behavior was changed.
