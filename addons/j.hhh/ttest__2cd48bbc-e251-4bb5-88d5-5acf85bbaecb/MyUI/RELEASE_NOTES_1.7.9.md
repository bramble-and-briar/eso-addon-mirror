# Satuve Xbox UI 1.7.9

- Ensures ESO's User Interface Shortcuts action layer is active while Frame Edit Mode owns the controller. D-Pad, A and B therefore reach the exclusive modal keybind state even when the launching Xbox extension menu did not keep that layer active.
- Adds left-stick frame selection with release-to-repeat debouncing. In move mode, the left stick remains fine movement and the right stick remains fast movement.
- Keeps the underlying ESO/Bandit settings list deactivated and restores only the action layer that the editor itself pushed.
- Converts Minimap numeric sliders to finite controller value lists. Size, opacity, pin scale and zoom keep their configured steps and immediately call the original setters.
- Requires LibGamepad AddOnVersion 107 (1.0.7) or newer and LibAddonMenu-2.0 AddOnVersion 41 (r41) or newer. Install the newest Xbox versions available. LibGamepadContextMenuBridge is a separate optional library.
- Keeps SavedVariables, language settings and frame coordinate calculations unchanged.
