# Satuve Xbox UI 1.9.22

- Fixes only `BUI_RaidFrame` position persistence.
- On movement confirmation, saves the frame's direct on-screen top-left position relative to `GuiRoot`'s top-left position.
- New SavedVariable format: `{TOPLEFT, TOPLEFT, x, y}`.
- Restores this format directly with `SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)`.
- Existing non-canonical RaidFrame anchors continue through the unchanged legacy creation path and are converted only after the user moves and confirms the frame.
- The general `SXUI_FrameEditor` movement system and all other movable frames remain unchanged.
