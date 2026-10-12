local strings = {
	SI_PBSCWC_EXPLANATION = "Moves and resizes the chat window on the HUD and changes the size of its text. The game fixes the window to the bottom right at one size; everything below starts at the game's own values, and nothing is changed until you move something. While this panel is open, a pink frame shows where the window will be.",

	SI_PBSCWC_ENABLED = "Change the chat window",
	SI_PBSCWC_ENABLED_TOOLTIP = "Apply the settings below. Turn this off to put the chat window, and its text, straight back the way the game has them -- your settings are kept for when you turn it on again.",

	SI_PBSCWC_PREVIEW = "Show a preview here",
	SI_PBSCWC_PREVIEW_TOOLTIP = "The chat is only drawn on the HUD, so it cannot be seen from this menu. While this is on, a pink frame with a few lines of sample chat is drawn where the window will be, at the text size you chose.",

	-- ---- Position ----------------------------------------------------------------------
	SI_PBSCWC_SECTION_POSITION = "Position",
	SI_PBSCWC_CORNER = "Measured from",
	SI_PBSCWC_CORNER_TOOLTIP = "Which corner of the screen the position is measured from. The window is held by that same corner of itself, so it also decides which way the window grows: from the bottom right -- the game's own choice -- a taller window grows upwards and the input line stays put. Changing this does not move the window.",
	SI_PBSCWC_CORNER_TOP_LEFT = "Top left",
	SI_PBSCWC_CORNER_TOP_RIGHT = "Top right",
	SI_PBSCWC_CORNER_BOTTOM_LEFT = "Bottom left",
	SI_PBSCWC_CORNER_BOTTOM_RIGHT = "Bottom right",

	SI_PBSCWC_POSITION_X = "Distance from the side",
	SI_PBSCWC_POSITION_X_TOOLTIP = "How far the window is from the left or right edge of the screen, whichever the corner above is on. 0 puts it against that edge.",
	SI_PBSCWC_POSITION_Y = "Distance from the top or bottom",
	SI_PBSCWC_POSITION_Y_TOOLTIP = "How far the window is from the top or bottom edge of the screen, whichever the corner above is on. The game's own window is 215 up from the bottom, clear of the skill bar.",

	-- ---- Size --------------------------------------------------------------------------
	SI_PBSCWC_SECTION_SIZE = "Size",
	SI_PBSCWC_WIDTH = "Width",
	SI_PBSCWC_WIDTH_TOOLTIP = "Width of the window, input line included. The game's own is 490. The game normally keeps the window between 300 and 550; this add-on lets it go from 200 up to the width of the screen.",
	SI_PBSCWC_HEIGHT = "Height",
	SI_PBSCWC_HEIGHT_TOOLTIP = "Height of the window, input line included. The game's own is 280. The game normally keeps the window between 170 and 380; this add-on lets it go from 100 up to the height of the screen.",

	-- ---- Text --------------------------------------------------------------------------
	SI_PBSCWC_SECTION_TEXT = "Text",
	SI_PBSCWC_FONT_SIZE = "Message text size",
	SI_PBSCWC_FONT_SIZE_TOOLTIP = "Size of the chat messages. Starts at the size the game draws them at for your Small / Medium / Large setting under Settings > Social, measured rather than assumed. Once you move it, this size is used instead of that setting. The input line keeps the game's size: its box is a fixed height.",

	-- ---- Showing -----------------------------------------------------------------------
	SI_PBSCWC_SECTION_SHOWING = "Showing",
	SI_PBSCWC_ALWAYS_VISIBLE = "Keep the window on screen",
	SI_PBSCWC_ALWAYS_VISIBLE_TOOLTIP = "The game minimises the chat 20 seconds after the last message: the messages disappear and the background fades away until something new arrives. With this on, the window stays as it is for as long as you are on the HUD, the input line included, just as the game shows it while the chat is active. Switching this off hands the window back to the game's own 20-second timer.",

	SI_PBSCWC_IN_MENUS = "Show it in menus too",
	SI_PBSCWC_IN_MENUS_TOOLTIP = "The game only draws the chat on the HUD: open the map, the inventory or any menu and the window goes away. With this on it stays on screen there as well, so you can read chat while you are in a menu. It is still not something you can type in from a menu -- that is the menu's own input. Keeping the window on screen goes on with it, because a window that appeared in a menu and then faded twenty seconds later would be worse than either. If a menu covers the window, set Drawn to in front of the interface. Nothing is forced while you have the chat switched off under Settings > Social.",

	SI_PBSCWC_TIER = "Drawn",
	SI_PBSCWC_TIER_TOOLTIP = "Where the chat window sits in the stack of things drawn on screen. The game draws it above the HUD but below keybind strips, tooltips and announcements. Behind puts it under the rest of the interface, so a HUD element over it wins; In front puts it over almost everything, which is what to pick if something is covering the chat.",
	SI_PBSCWC_TIER_LOW = "Behind the interface",
	SI_PBSCWC_TIER_MEDIUM = "Normal (the game's own)",
	SI_PBSCWC_TIER_HIGH = "In front of the interface",

	SI_PBSCWC_LEVEL = "Order within that layer",
	SI_PBSCWC_LEVEL_TOOLTIP = "Which of two things drawn in the same layer goes on top: the higher number wins. The game gives the chat 30. Worth changing only if something is still drawn over the chat, or the chat over something you would rather see -- raise it or lower it a step at a time. For reference, in the game's normal layer the keybind strip is 10 and a dialog 20; in front, tooltips are 140 and alerts 145.",

	-- ---- Both --------------------------------------------------------------------------
	SI_PBSCWC_SECTION_GENERAL = "All settings",
	SI_PBSCWC_RESET = "Reset",
	SI_PBSCWC_RESET_TOOLTIP = "Put everything above back to the game's own: the position, the size, the text size, the draw order, and keeping the window on screen.",
	SI_PBSCWC_RESET_BUTTON = "Reset",

	SI_PBSCWC_GAME_SETTINGS_HINT = "Whether the chat is shown on the HUD at all is the game's own setting, under Settings > Social. An add-on cannot change it, so set it there.",

	-- ---- Preview -----------------------------------------------------------------------
	SI_PBSCWC_PREVIEW_CAPTION = "Chat window (preview)",
	SI_PBSCWC_PREVIEW_ENTRY = "Input line",
	SI_PBSCWC_PREVIEW_LINE_1 = "|cC8C8FF[Zone] Traveller: Anyone for the world boss?|r",
	SI_PBSCWC_PREVIEW_LINE_2 = "|c9FE8FF[Group] PinkBanther: On my way!|r",
	SI_PBSCWC_PREVIEW_LINE_3 = "|cE8C4FF[Guild] Friend: Thanks for the mats|r",
	SI_PBSCWC_PREVIEW_LINE_4 = "|cFFB6E4[Whisper] PinkBanther: See you there|r",
	SI_PBSCWC_PREVIEW_LINE_5 = "|cFFFFFFPinkBanther says: Hello, Tamriel!|r",
	SI_PBSCWC_PREVIEW_LINE_6 = "|cC8C8FF[Zone] Traveller: Thank you all|r",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
