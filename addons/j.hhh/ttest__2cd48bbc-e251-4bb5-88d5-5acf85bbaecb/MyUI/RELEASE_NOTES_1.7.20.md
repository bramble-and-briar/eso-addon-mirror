# Satuve Xbox UI 1.7.20

- Adds Votan's native Minimap as a selectable target in the existing Move Frames screen.
- The editor shows a Minimap-sized position handle while the native map is hidden.
- A starts and confirms movement, the D-Pad moves the handle, and B cancels the current unconfirmed movement.
- Confirmed coordinates are stored in Votan's account.x and account.y values and applied through RestorePosition().
- Mouse dragging uses the same Votan position commit path.
- The full world map remains separate and is never repositioned by Move Frames.
