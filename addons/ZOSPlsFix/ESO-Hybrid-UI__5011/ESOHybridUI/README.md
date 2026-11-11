# ESO Hybrid UI 4.2.1-beta

**AI-assisted development disclosure:** AI tools were used during development and review. The addon is maintained and tested by its author. Please report compatibility issues with the ESO game version and a diagnostic dump.

ESO Hybrid UI provides a controller-first interface that keeps ESO's Gamepad Mode enabled while offering a compact keyboard-layout HUD in Hybrid mode.

## Requirements

- The Elder Scrolls Online PC client.
- **LibAddonMenu-2.0 r43 or newer** (required).
- ESO's **Gamepad Mode must be set to On**, not Auto. Auto can switch input presentation unexpectedly.
- Optional: LibGamepadOptions for the native controller settings page.
- Optional: LibDebugLogger (and DebugLogViewer) for persistent diagnostic logs.

## Installation

1. Install LibAddonMenu-2.0 r43 or newer.
2. Extract the `ESOHybridUI` folder into `Documents/Elder Scrolls Online/live/AddOns/`.
3. Start ESO and enable ESO Hybrid UI in the Add-Ons menu.
4. Open the addon settings and press **Apply settings** once. This applies the recommended controller, keybind-display and chat settings; it does not change them automatically on every login.
5. Choose **Hybrid** as the interface mode.

The addon folder must be named exactly `ESOHybridUI` and contain `ESOHybridUI.txt`.

## Interface modes

### Gamepad

Uses ESO's normal Gamepad UI without the Hybrid presentation policy.

### Hybrid

- Keeps the compact keyboard-layout HUD and action bar.
- Can display controller glyphs on the action bar and HUD prompts.
- Routes supported platform-selected menus and dialogs to ESO's native Gamepad UI.
- Keeps the native Gamepad world map, loot and lockpicking interfaces.
- Uses the keyboard-style quickslot wheel by default, with controller cycling bridged to ESO's native wheel actions.
- The player-interaction wheel also appears keyboard-style in the current Hybrid setup. This uses ESO's normal interaction path; the addon deliberately does not replace the resurrection interaction function.
- The built-in HUD layout editor edits the keyboard HUD layout.

The **Keyboard-style quickslot wheel** setting can be turned off to use ESO's native Gamepad quickslot radial instead. The player-interaction wheel has no separate setting.

The **Menus opened from the HUD** policy defaults to **Gamepad**. The **Legacy** option retains the older routing behaviour and is intended only as a compatibility fallback.

## Settings

The keyboard Add-Ons panel is provided by LibAddonMenu. If LibGamepadOptions is installed, the same settings are also available from its native controller settings page.

- **Apply settings:** explicitly applies the recommended ESO input and chat settings.
- **Interface mode:** switches between Gamepad and Hybrid.
- **Menus opened from the HUD:** selects the default Gamepad routing policy or Legacy behaviour.
- **Account-wide settings:** shares the addon settings across characters on the current megaserver.
- **Keyboard-style quickslot wheel:** chooses the keyboard or native Gamepad quickslot radial in Hybrid.
- **Controller glyphs on the action bar:** enables or disables controller glyphs in Hybrid.
- **HUD prompt fonts:** adjusts interaction and stealth prompt font sizes.
- **Advanced:** optional diagnostic logging, opt-in load announcement and command reference.
- **Donation mail:** opens a mail draft addressed to the author. It does not attach or transfer gold. The mail composer is keyboard-oriented and may not open correctly from every native Gamepad screen.

## Commands

- `/esohybrid` — toggle Gamepad / Hybrid.
- `/esohybrid_status` — show the current interface mode.
- `/esohybrid_policy gamepad|legacy` — change the menu-routing policy.
- `/esohybrid_settings` — open addon settings.
- `/esohybrid_debug on|off` — enable or disable diagnostic logging.
- `/esohybrid_dump` — print a diagnostic snapshot.
- `/esohybrid_trace on|off|report|reset` — trace platform queries, scenes and UI-system routing.
- `/esohybrid_sv` — show SavedVariables initialization status.

## Compatibility notes and known limitations

ESO's UI platform selection is handled through several internal systems. Hybrid uses targeted hooks around those selection points; a game update or another addon that replaces the same functions can affect compatibility.

- Not every special-purpose screen necessarily uses the same platform-selection path. The Event Pursuit HUD entry has been observed opening its keyboard presentation in Hybrid, even when the page opened directly from the Gamepad UI uses the native Gamepad presentation.
- Some prompt remaps refer to ESO-owned keybind descriptor positions. A game update can change those descriptors; diagnostic logging records the remaps.
- The quickslot controller bridge inherits ESO's own controller bindings. Custom controller rebinding should be checked after changing those bindings.
- The menu policy and special-case screens should be retested after major ESO updates.

If reporting a problem, include the ESO API version, the action that triggered it, whether the issue occurs in Gamepad or Hybrid mode, and the output of `/esohybrid_dump`. For routing problems, enable `/esohybrid_trace on`, reproduce the issue, then include `/esohybrid_trace report`.

## Credits

ESO Hybrid UI is an AI-assisted revision inspired by **Advanced Disable Controller UI** by **Lionas**, with contributions by **jc28735250** and **DoriKyll**. Credit is given for the original addon concept and inspiration; this project is maintained as a separate implementation.
