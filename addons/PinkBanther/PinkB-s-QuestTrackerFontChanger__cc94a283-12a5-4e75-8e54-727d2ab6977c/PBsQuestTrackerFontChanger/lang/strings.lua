local strings = {
	SI_PBSQTFC_EXPLANATION = "The trackers stacked down the top right of the HUD are built out of ordinary UI labels, so their fonts can be changed directly -- no interface reload, and nothing that outlives the session. Each is configured separately below, in the order they appear on screen.",

	-- ---- Quest tracker ----------------------------------------------------------------
	SI_PBSQTFC_SECTION_QUEST = "Quest tracker",
	SI_PBSQTFC_SECTION_QUEST_NOTE = "The tracked quest in the top right: its name, the step description and the objective lines. The game gives those three different sizes, so each gets its own slider.",

	SI_PBSQTFC_QUEST_ENABLED = "Custom quest tracker font",
	SI_PBSQTFC_QUEST_ENABLED_TOOLTIP = "Apply the settings below to the quest tracker. Turn this off to hand the game's own font straight back. While every setting here still matches the game's own, nothing is written at all.",

	SI_PBSQTFC_SIZE_QUEST_NAME = "Quest name size",
	SI_PBSQTFC_SIZE_QUEST_NAME_TOOLTIP = "Size of the quest name at the top of the tracker. Starts at the size the game itself draws it at, measured from the tracker rather than assumed.",
	SI_PBSQTFC_SIZE_QUEST_STEP = "Step description size",
	SI_PBSQTFC_SIZE_QUEST_STEP_TOOLTIP = "Size of the step description -- the line under the quest name that says what this stage of the quest is about. Not every quest step has one.",
	SI_PBSQTFC_SIZE_QUEST_GOAL = "Objective size",
	SI_PBSQTFC_SIZE_QUEST_GOAL_TOOLTIP = "Size of the objective lines -- what you actually have to do, and any counters. In gamepad mode the game draws these larger than the quest name; that is the game's own choice, and moving this slider is how to change it.",

	SI_PBSQTFC_POS_X = "Horizontal position",
	SI_PBSQTFC_POS_X_TOOLTIP = "Moves the tracker column left or right from wherever the game puts it. 0 leaves it alone. Positive is right. The game keeps every tracker -- quest, Golden Pursuits, house information and the rest -- in one column, so they all move together and keep their order. On PC, a position set in the game's own Edit HUD screen takes priority over this one.",
	SI_PBSQTFC_POS_Y = "Vertical position",
	SI_PBSQTFC_POS_Y_TOOLTIP = "Moves the tracker column up or down from wherever the game puts it. 0 leaves it alone. Positive is down. The column scrolls when it runs out of room, so moving it down leaves less of it on screen at once.",
	SI_PBSQTFC_SCALE = "Panel scale",
	SI_PBSQTFC_SCALE_TOOLTIP = "Draws the whole quest tracker bigger or smaller -- text, icons and the keybind button together, in proportion. Only the quest tracker; the panels under it keep their size and follow its new height. 100% is the game's own. This is free: scaling does not make the client build a font, so it costs nothing on console. The panel scales towards its top right corner, which is where it is anchored.",

	SI_PBSQTFC_QUEST_FACE = "Quest tracker typeface",
	SI_PBSQTFC_QUEST_STYLE = "Quest tracker outline",

	-- ---- Golden Pursuits --------------------------------------------------------------
	SI_PBSQTFC_SECTION_PURSUIT = "Golden Pursuits",
	SI_PBSQTFC_SECTION_PURSUIT_NOTE = "The panel between the quest tracker and the house information, showing the pursuit you are tracking and a bar for how far along it is. The same panel is reused for Tamriel Tomes and a pinned achievement, so these settings cover all of them.",

	SI_PBSQTFC_PURSUIT_ENABLED = "Custom Golden Pursuits font",
	SI_PBSQTFC_PURSUIT_ENABLED_TOOLTIP = "Apply the settings below to the Golden Pursuits panel. Turn this off to hand the game's own font straight back. While every setting here still matches the game's own, nothing is written at all.",

	SI_PBSQTFC_SIZE_PURSUIT_NAME = "Heading size",
	SI_PBSQTFC_SIZE_PURSUIT_NAME_TOOLTIP = "Size of the heading line next to the icon -- \"Golden Pursuits\", or \"Tamriel Tomes\" when that is what is being tracked.",
	SI_PBSQTFC_SIZE_PURSUIT_DETAIL = "Pursuit name size",
	SI_PBSQTFC_SIZE_PURSUIT_DETAIL_TOOLTIP = "Size of the line under the heading: what you are tracking.",
	SI_PBSQTFC_SIZE_PURSUIT_PROGRESS = "Progress size",
	SI_PBSQTFC_SIZE_PURSUIT_PROGRESS_TOOLTIP = "Size of the numbers inside the progress bar. The bar itself keeps its size, so a much larger setting can spill over its edges.",

	SI_PBSQTFC_PURSUIT_FACE = "Golden Pursuits typeface",
	SI_PBSQTFC_PURSUIT_STYLE = "Golden Pursuits outline",

	-- ---- House tracker ----------------------------------------------------------------
	SI_PBSQTFC_SECTION_HOUSE = "House tracker",
	SI_PBSQTFC_SECTION_HOUSE_NOTE = "The panel under the quest tracker while you are in a house -- yours or someone else's on a home tour. It shows the house name, its nickname and owner, how many people are inside, and the House Tours tags.",

	SI_PBSQTFC_HOUSE_ENABLED = "Custom house tracker font",
	SI_PBSQTFC_HOUSE_ENABLED_TOOLTIP = "Apply the settings below to the house panel. Turn this off to hand the game's own font straight back. While every setting here still matches the game's own, nothing is written at all.",

	SI_PBSQTFC_SIZE_HOUSE_NAME = "House name size",
	SI_PBSQTFC_SIZE_HOUSE_NAME_TOOLTIP = "Size of the house name at the top of the panel.",
	SI_PBSQTFC_SIZE_HOUSE_DETAIL = "House details size",
	SI_PBSQTFC_SIZE_HOUSE_DETAIL_TOOLTIP = "Size of everything under the house name: the nickname and owner, the visitor count, and the House Tours tags. The game draws all three with one font, so they share one slider rather than being given three ways to disagree.",

	SI_PBSQTFC_HOUSE_FACE = "House tracker typeface",
	SI_PBSQTFC_HOUSE_STYLE = "House tracker outline",

	-- ---- Shared -----------------------------------------------------------------------
	SI_PBSQTFC_FACE_TOOLTIP_COMMON = "Which of the game's own faces to use, for every part of this tracker at once. Default keeps the face the game picked for each part separately -- in gamepad mode the name at the top is bold and what is under it is not -- which is also the safest choice in every language. Only faces the UI already has loaded are offered: any other has to be built when it is set, and on console that build is billed to the pool add-ons share and crashes the add-on. Several entries resolve to the same file in some languages -- in Japanese, Interface (medium), Interface (bold) and Console (light) are one gothic face.",
	SI_PBSQTFC_FACE_DEFAULT = "Default",
	SI_PBSQTFC_FACE_GAMEPAD_MEDIUM = "Console (medium)",
	SI_PBSQTFC_FACE_GAMEPAD_BOLD = "Console (bold)",
	SI_PBSQTFC_FACE_GAMEPAD_LIGHT = "Console (light)",
	SI_PBSQTFC_FACE_MEDIUM = "Interface (medium)",
	SI_PBSQTFC_FACE_BOLD = "Interface (bold)",

	SI_PBSQTFC_STYLE_TOOLTIP_COMMON = "How the text is separated from the scenery behind it, for every part of this tracker at once. A thicker outline stays readable against bright ground. WARNING: outline styles make the client build outline glyphs, and the game's own source puts that at about 100 MB for a CJK font -- the same size as the whole memory pool console add-ons share. If the game becomes unstable, leave this on Default.",
	SI_PBSQTFC_STYLE_DEFAULT = "Default",
	SI_PBSQTFC_STYLE_NORMAL = "None",
	SI_PBSQTFC_STYLE_SHADOW = "Shadow",
	SI_PBSQTFC_STYLE_SOFT_SHADOW_THIN = "Soft shadow (thin)",
	SI_PBSQTFC_STYLE_SOFT_SHADOW_THICK = "Soft shadow (thick)",
	SI_PBSQTFC_STYLE_OUTLINE_THICK = "Outline (thick)",

	SI_PBSQTFC_SECTION_GENERAL = "All trackers",
	SI_PBSQTFC_RESET = "Reset",
	SI_PBSQTFC_RESET_TOOLTIP = "Put every setting above, in every section, back to the game's own font.",
	SI_PBSQTFC_RESET_BUTTON = "Reset",

	SI_PBSQTFC_GAME_SETTINGS_HINT = "Whether each tracker is shown at all is the game's own setting, under Settings > Interface. An add-on cannot change those, so set them there.",
}

-- The typeface and outline tooltips say the same thing in every section, so they are written
-- once and pointed at from each rather than kept in step by hand.
strings.SI_PBSQTFC_QUEST_FACE_TOOLTIP = strings.SI_PBSQTFC_FACE_TOOLTIP_COMMON
strings.SI_PBSQTFC_PURSUIT_FACE_TOOLTIP = strings.SI_PBSQTFC_FACE_TOOLTIP_COMMON
strings.SI_PBSQTFC_HOUSE_FACE_TOOLTIP = strings.SI_PBSQTFC_FACE_TOOLTIP_COMMON
strings.SI_PBSQTFC_QUEST_STYLE_TOOLTIP = strings.SI_PBSQTFC_STYLE_TOOLTIP_COMMON
strings.SI_PBSQTFC_PURSUIT_STYLE_TOOLTIP = strings.SI_PBSQTFC_STYLE_TOOLTIP_COMMON
strings.SI_PBSQTFC_HOUSE_STYLE_TOOLTIP = strings.SI_PBSQTFC_STYLE_TOOLTIP_COMMON

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
