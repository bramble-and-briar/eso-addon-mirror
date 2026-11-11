-- ESO Hybrid UI: English strings (default language, always loaded).
--
-- Every user-facing text lives here. String ids are global in ESO, so all of them
-- carry the SI_ESOHYBRIDUI_ prefix (the keybinding ids below are fixed by name:
-- Bindings.xml and ESO's SI_BINDING_NAME_<ACTION> convention require them).
--
-- To add a language: copy this file to lang/<code>.lua (de, fr, es, ru, zh, ja ...),
-- replace ZO_CreateStringId with SafeAddString(ID, "text", 1) and translate the
-- values, then add this manifest line AFTER lang/en.lua:   lang/$(language).lua
-- Strings with <<1>> receive a value through zo_strformat. Chat commands and the
-- /esohybrid_dump and /esohybrid_trace developer output stay English on purpose.

-- Keybindings screen (ids fixed by Bindings.xml / ESO naming rules)
ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_ESO_HYBRID_UI", "ESO Hybrid UI")
ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_ESO_HYBRID_UI_WHEEL", "ESO Hybrid UI: utility wheel bridge")
ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_UI", "Toggle gamepad / hybrid UI")
ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_LEFT", "Cycle utility wheel left (controller)")
ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_RIGHT", "Cycle utility wheel right (controller)")

-- Settings: controller page intro and keyboard panel intro
ZO_CreateStringId("SI_ESOHYBRIDUI_GP_INTRO_NAME", "Controller settings")
ZO_CreateStringId("SI_ESOHYBRIDUI_GP_INTRO_TEXT", "Configure ESO Hybrid UI without leaving the gamepad interface. These settings are shared with the keyboard Add-Ons panel.")
ZO_CreateStringId("SI_ESOHYBRIDUI_KB_INTRO_TEXT", "For controller users. Use the button below once to configure ESO's recommended input and chat settings, then choose your interface style.")
ZO_CreateStringId("SI_ESOHYBRIDUI_HEADER_INTERFACE", "Interface")

-- Settings: recommended ESO settings
ZO_CreateStringId("SI_ESOHYBRIDUI_RECOMMENDED_NAME", "Recommended ESO settings")
ZO_CreateStringId("SI_ESOHYBRIDUI_RECOMMENDED_TOOLTIP", "Saves Gamepad Mode, gamepad keybind display, keyboard chat and cursor-on-chat-focus in ESO. Applied only when you press this button.")
ZO_CreateStringId("SI_ESOHYBRIDUI_RECOMMENDED_BUTTON", "Apply settings")
ZO_CreateStringId("SI_ESOHYBRIDUI_RECOMMENDED_APPLIED", "Recommended ESO settings applied and saved: Gamepad Mode, gamepad keybind display, keyboard chat and cursor-on-chat-focus are on.")

-- Settings: interface mode
ZO_CreateStringId("SI_ESOHYBRIDUI_MODE_NAME", "Interface mode")
ZO_CreateStringId("SI_ESOHYBRIDUI_MODE_TOOLTIP", "Gamepad: ESO's full controller interface. Hybrid: compact keyboard-layout HUD and quickslot wheel with controller glyphs; menus, map, loot and lockpicking stay native gamepad UI. ESO's Gamepad Mode must be On, not Auto.")
ZO_CreateStringId("SI_ESOHYBRIDUI_MODE_GAMEPAD", "Gamepad")
ZO_CreateStringId("SI_ESOHYBRIDUI_MODE_HYBRID", "Hybrid")
ZO_CreateStringId("SI_ESOHYBRIDUI_STATUS_GAMEPAD", "native gamepad UI")
ZO_CreateStringId("SI_ESOHYBRIDUI_STATUS_HYBRID", "hybrid UI")

-- Settings: how menus opened from the HUD are chosen
ZO_CreateStringId("SI_ESOHYBRIDUI_POLICY_NAME", "Menus opened from the HUD")
ZO_CreateStringId("SI_ESOHYBRIDUI_POLICY_TOOLTIP", "Gamepad: prefer ESO's native gamepad versions for UI-system objects and registered root scenes; direct special-case screens can still follow ESO's own routing. Legacy: the older 3.x behaviour, where ESO may choose keyboard menus from the HUD. Switch to Legacy only if the default policy causes a specific compatibility problem.")
ZO_CreateStringId("SI_ESOHYBRIDUI_POLICY_GAMEPAD", "Gamepad (recommended)")
ZO_CreateStringId("SI_ESOHYBRIDUI_POLICY_LEGACY", "Legacy")
ZO_CreateStringId("SI_ESOHYBRIDUI_POLICY_CHANGED", "Menu policy: <<1>>")

-- Settings: profile scope
ZO_CreateStringId("SI_ESOHYBRIDUI_ACCOUNT_NAME", "Account-wide settings")
ZO_CreateStringId("SI_ESOHYBRIDUI_ACCOUNT_TOOLTIP", "Use the same settings on all characters. Current settings are copied to the shared profile the first time this is enabled.")

-- Settings: Hybrid HUD features
ZO_CreateStringId("SI_ESOHYBRIDUI_HEADER_HYBRID_HUD", "Hybrid HUD")
ZO_CreateStringId("SI_ESOHYBRIDUI_WHEEL_NAME", "Keyboard-style quickslot wheel")
ZO_CreateStringId("SI_ESOHYBRIDUI_WHEEL_TOOLTIP", "On: the quickslot wheel uses the keyboard radial layout in Hybrid and keeps controller cycling. Off: ESO uses its native gamepad quickslot wheel. Applies the next time the wheel is opened.")
ZO_CreateStringId("SI_ESOHYBRIDUI_GLYPHS_NAME", "Controller glyphs on the action bar")
ZO_CreateStringId("SI_ESOHYBRIDUI_GLYPHS_TOOLTIP", "On: show controller button glyphs on the compact keyboard-layout action bar in Hybrid. Off: use the normal keyboard-layout action-bar labels. This setting refreshes the action-bar labels immediately.")

-- Settings: HUD prompt fonts
ZO_CreateStringId("SI_ESOHYBRIDUI_HEADER_PROMPTS", "HUD prompts")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_RETICLE_NAME", "Interaction button font")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_RETICLE_TOOLTIP", "Size of the button label beside the reticle.")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_CONTEXT_NAME", "Interaction context font")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_CONTEXT_TOOLTIP", "Size of the interaction description beside the reticle.")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_STEALTH_NAME", "Stealth icon font")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_STEALTH_TOOLTIP", "Size of stealth and lockpicking prompt icons.")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_SMALL", "Small")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_DEFAULT", "Default")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_LARGE", "Large")
ZO_CreateStringId("SI_ESOHYBRIDUI_FONT_XLARGE", "Extra large")

-- Settings: advanced
ZO_CreateStringId("SI_ESOHYBRIDUI_ADVANCED_NAME", "Advanced")
ZO_CreateStringId("SI_ESOHYBRIDUI_ADVANCED_TOOLTIP", "Troubleshooting options.")
ZO_CreateStringId("SI_ESOHYBRIDUI_DEBUG_NAME", "Diagnostic logging")
ZO_CreateStringId("SI_ESOHYBRIDUI_DEBUG_TOOLTIP", "Enable detailed debug messages. For saved logs and stack traces install LibDebugLogger and DebugLogViewer.")
ZO_CreateStringId("SI_ESOHYBRIDUI_DEBUG_ON", "Diagnostic logging enabled.")
ZO_CreateStringId("SI_ESOHYBRIDUI_DEBUG_OFF", "Diagnostic logging disabled.")
ZO_CreateStringId("SI_ESOHYBRIDUI_DEBUG_NEED_LIB", "Install LibDebugLogger and DebugLogViewer to keep logs; messages are shown in chat until then.")
ZO_CreateStringId("SI_ESOHYBRIDUI_ANNOUNCE_NAME", "Announce load in chat")
ZO_CreateStringId("SI_ESOHYBRIDUI_ANNOUNCE_TOOLTIP", "Print one chat line when the addon loads. Off by default.")
ZO_CreateStringId("SI_ESOHYBRIDUI_ANNOUNCE_LOADED", "<<1>> loaded. /esohybrid switches Gamepad and Hybrid.")
ZO_CreateStringId("SI_ESOHYBRIDUI_COMMANDS_TEXT", "Chat commands: /esohybrid, /esohybrid_policy gamepad|legacy, /esohybrid_debug on|off, /esohybrid_dump, /esohybrid_trace on|off|report|reset.")

-- Settings: support
ZO_CreateStringId("SI_ESOHYBRIDUI_HEADER_SUPPORT", "Support the addon")
ZO_CreateStringId("SI_ESOHYBRIDUI_SUPPORT_TEXT", "Optional gold donations are appreciated. This opens a mail addressed to @ZOSPlsFix; you choose whether to attach gold and the amount.")
ZO_CreateStringId("SI_ESOHYBRIDUI_DONATE_NAME", "Donation mail")
ZO_CreateStringId("SI_ESOHYBRIDUI_DONATE_TOOLTIP", "Opens a mail draft only. ESO Hybrid UI never attaches or changes gold.")
ZO_CreateStringId("SI_ESOHYBRIDUI_DONATE_BUTTON", "Open mail")
ZO_CreateStringId("SI_ESOHYBRIDUI_MAIL_UNAVAILABLE", "The mail composer is not available.")

-- First-install dialog
ZO_CreateStringId("SI_ESOHYBRIDUI_WELCOME_TITLE", "Welcome to ESO Hybrid UI")
ZO_CreateStringId("SI_ESOHYBRIDUI_WELCOME_TEXT", "Open ESO Hybrid UI settings and click Apply Recommended ESO Settings once. This turns on Gamepad Mode, gamepad keybind display, keyboard chat and the mouse cursor when chat receives focus. Then choose Gamepad or Hybrid. You can apply the settings again later if needed.")
ZO_CreateStringId("SI_ESOHYBRIDUI_WELCOME_BUTTON", "Got it")
