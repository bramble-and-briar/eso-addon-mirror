# Satuve Xbox UI 1.7.14

- Fixed `BackdropControl: Invalid width[8] or height[3] supplied` when Frame Edit Mode created its gold selection border.
- ESO requires both edge texture dimensions to be powers of two; the border now uses valid dimensions of 8 by 2.
- Added cleanup around editor activation so a future initialization error closes the underlying move mode and restores the suspended settings menu/input state.
- D-Pad selection, A activation, modal menu hiding, and the Minimap slider fixes remain unchanged.