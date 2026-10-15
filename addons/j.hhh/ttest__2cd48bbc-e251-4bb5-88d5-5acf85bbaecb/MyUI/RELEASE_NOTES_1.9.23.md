# Satuve Xbox UI 1.9.23

- Fixes the unreadably small numeric target-health value.
- The affected control is `BUI_TargetFrame_HealthCurrent`.
- Its final font assignment now uses the existing primary frame font and outline style at 26 pixels instead of the previous calculated 20–22 pixels.
- Does not resize or reposition `BUI_TargetFrame` and does not change its health bar or target-name controls.
- RaidFrame, Frame Editor, Combat Log, Sidebar, Custom Bar and controller navigation are unchanged.
