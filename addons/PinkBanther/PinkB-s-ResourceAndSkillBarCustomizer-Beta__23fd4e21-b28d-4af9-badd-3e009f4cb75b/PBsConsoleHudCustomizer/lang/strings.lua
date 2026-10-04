local strings = {
	SI_PBSCHC_EXPLANATION = "Moves and resizes the health, magicka and stamina bars on the HUD. The game fixes all three to the bottom of the screen at one size; each one below starts at the game's own place, and nothing is changed until you move something. While this panel is open, a coloured outline shows where each bar will sit.",

	SI_PBSCHC_ENABLED = "Change the resource bars",
	SI_PBSCHC_ENABLED_TOOLTIP = "Apply the settings below. Turn this off to put all three bars straight back where the game has them -- your settings are kept for when you turn it on again.",

	SI_PBSCHC_PREVIEW = "Show a preview here",
	SI_PBSCHC_PREVIEW_TOOLTIP = "The bars are only drawn on the HUD, so they cannot be seen from this menu. While this is on, an outline the size of each bar is drawn where it will sit.",

	SI_PBSCHC_BAR_HEALTH = "Health",
	SI_PBSCHC_BAR_MAGICKA = "Magicka",
	SI_PBSCHC_BAR_STAMINA = "Stamina",

	SI_PBSCHC_BAR_SKILLBAR = "Skill bar",

	-- ---- The look of the resource bars ---------------------------------------------------
	SI_PBSCHC_SECTION_STYLE = "The look of the bars",
	SI_PBSCHC_STYLE = "Bar style",
	SI_PBSCHC_STYLE_TOOLTIP = "Standard is the game's own bars, untouched. Liquid keeps the game's own shape, frame and gloss and turns the fill into a liquid in a glass tube: soft currents drifting through it, a surface that sloshes when the amount changes, a trace of what was lost draining away, rising bubbles and a glint along the glass. Crystal keeps the same shape and makes the fill a clear cut crystal: faceted planes catching the light in turn, a bright girdle line and twinkling sparkles. Both are as solid as the game's own bars; How solid below makes them see-through. Square draws each bar as a flat rectangle -- a dark track and a solid block of the power's own colour -- with the game's arrow-shaped frame and background put away, at the size the game draws it. MURA-HIGE Style is the same rectangle at a width and a height of your own, set below. MURA-HIGE NEO Style uses the same size settings, with health, magicka and stamina all filling from left to right. In these styles the bars themselves are left in place and still doing their work, so damage shields, armour changes and the low-health warning all still show on top.",
	SI_PBSCHC_STYLE_LIQUIDFLOW = "Liquid",
	SI_PBSCHC_STYLE_CRYSTAL = "Crystal",
	SI_PBSCHC_STYLE_STANDARD = "Standard",
	SI_PBSCHC_STYLE_PLAIN = "Square",
	SI_PBSCHC_STYLE_ROUNDED = "MURA-HIGE Style",
	SI_PBSCHC_STYLE_NEO = "MURA-HIGE NEO Style",
	SI_PBSCHC_PLAIN_OPACITY = "How solid",
	SI_PBSCHC_PLAIN_OPACITY_TOOLTIP = "How solid the rectangles are. 100% hides the game's own fill completely; below that it shows through, which is one way to keep a little of the original look.",
	SI_PBSCHC_BORDER_COLOUR = "Outline colour",
	SI_PBSCHC_BORDER_COLOUR_TOOLTIP = "Outline colour shared by health, magicka and stamina in Square, MURA-HIGE Style and MURA-HIGE NEO Style. Visible when Draw an outline is enabled.",
	SI_PBSCHC_BORDER_BLACK = "Black (default)",
	SI_PBSCHC_BORDER_WHITE = "White",
	SI_PBSCHC_BORDER_SILVER = "Silver",
	SI_PBSCHC_BORDER_GOLD = "Gold",
	SI_PBSCHC_BORDER_RED = "Red",
	SI_PBSCHC_BORDER_BLUE = "Blue",
	SI_PBSCHC_RESOURCE_ALIGN = "Resource text alignment",
	SI_PBSCHC_RESOURCE_ALIGN_TOOLTIP = "Text alignment shared by health, magicka and stamina in MURA-HIGE Style and MURA-HIGE NEO Style. Defaults to left.",
	SI_PBSCHC_RESOURCE_ALIGN_LEFT = "Left",
	SI_PBSCHC_RESOURCE_ALIGN_RIGHT = "Right",
	SI_PBSCHC_RESOURCE_ALIGN_CENTER = "Center",

	SI_PBSCHC_PLAIN_BORDER = "Draw an outline",
	SI_PBSCHC_PLAIN_BORDER_TOOLTIP = "Draw a thin line in the selected colour round each bar. The game's own arrow-shaped frame is always put away while one of these styles is chosen -- a flat rectangle inside an arrow frame is neither one thing nor the other -- so this is the only frame on offer. Off, the bar is a block of colour with no line at all.",

	-- ---- The shade over a skill ----------------------------------------------------------
	SI_PBSCHC_SECTION_SHADE = "Shade over a skill in use",
	SI_PBSCHC_SHADE_EXPLANATION = "While an ability's effect is running, its icon is shaded over, and the shade is wiped away down the icon as the time runs out -- so how much is left can be seen without reading the number. It runs on both weapon sets, and the game itself does the sweeping, so it is always exactly as long as the effect.",
	SI_PBSCHC_SHADE_ENABLED = "Shade a skill while its effect runs",
	SI_PBSCHC_SHADE_ENABLED_TOOLTIP = "Darken the icon of an ability whose effect is running, and clear that darkness as the effect counts down.",
	SI_PBSCHC_SHADE_DARKNESS = "How dark",
	SI_PBSCHC_SHADE_DARKNESS_TOOLTIP = "How much the icon is darkened while the effect runs. 0% leaves the icon as it is and only the moving edge shows.",
	SI_PBSCHC_SHADE_DIRECTION = "Which way it clears",
	SI_PBSCHC_SHADE_DIRECTION_TOOLTIP = "Downwards clears the shade from the top of the icon first, so what is left sinks. If a game update ever runs the sweep the other way round, this puts it back.",
	SI_PBSCHC_SHADE_DIRECTION_DOWN = "Downwards",
	SI_PBSCHC_SHADE_DIRECTION_UP = "Upwards",
	SI_PBSCHC_SHADE_EDGE = "Bright edge on the sweep",
	SI_PBSCHC_SHADE_EDGE_TOOLTIP = "A lit line along the edge of the shade as it moves, the same one the game uses on its ability cooldowns.",
	SI_PBSCHC_SKILLBAR_ENABLED = "Let this add-on touch the skill bar",
	SI_PBSCHC_SKILLBAR_ENABLED_TOOLTIP = "Turn this off to hand the skill bar back to the game, and to any other add-on that lays it out. Its position and size, the spacing along it, the other weapon set's row, the countdown and target count on the icons and the shade over a skill in use are all put back and stay off; the settings are kept for when you turn it on again. The health, magicka and stamina bars are not affected.",
	SI_PBSCHC_BAR_WIDTH = "<<1>>: bar width",
	SI_PBSCHC_BAR_WIDTH_TOOLTIP = "How wide the bar is drawn, in pixels. MURA-HIGE Style and MURA-HIGE NEO Style only: that style draws the bar itself, so it can be given a size. The other styles scale the game's own bar instead, because the width of those controls is the game's to write. The game's own is 224.",
	SI_PBSCHC_BAR_HEIGHT = "<<1>>: bar height",
	SI_PBSCHC_BAR_HEIGHT_TOOLTIP = "How tall the bar is drawn, in pixels. MURA-HIGE Style and MURA-HIGE NEO Style only. The game's own is 17.",

	-- ---- The gaps along the skill bar ----------------------------------------------------
	SI_PBSCHC_SECTION_GAPS = "Spacing along the skill bar",
	SI_PBSCHC_GAPS_EXPLANATION = "How far apart the buttons sit. The game leaves a lot of room around the ultimate and the item, and between the item and the abilities there is an invisible control -- the weapon swap marker, which the console never draws -- taking up space as well. These are the gaps you can actually see.",
	SI_PBSCHC_GAP_SKILL = "Between the abilities",
	SI_PBSCHC_GAP_SKILL_TOOLTIP = "The space between the five ability buttons. The game's own is 10.",
	SI_PBSCHC_GAP_ULTIMATE = "Before the ultimate",
	SI_PBSCHC_GAP_ULTIMATE_TOOLTIP = "The space between the last ability and the ultimate. The game's own is 65, which is what makes the ultimate sit out on its own.",
	SI_PBSCHC_GAP_ITEM = "Before the item",
	SI_PBSCHC_GAP_ITEM_TOOLTIP = "The space between the quickslot item and the first ability -- and, while a companion is out, between the item and the companion's ultimate as well. The game's own is the weapon swap marker's whole width, so this is where most of the room is to be won back.",

	-- ---- The other weapon set ----------------------------------------------------------
	SI_PBSCHC_SECTION_BACKBAR = "The other weapon set",
	SI_PBSCHC_BACKBAR_EXPLANATION = "A row of your other weapon set's abilities, above the skill bar, with the same countdown and target count on each. The game has a row of its own, but it only appears for a slot whose effect is still running; this one is always there.",
	SI_PBSCHC_BACKBAR_ENABLED = "Show the other weapon set",
	SI_PBSCHC_BACKBAR_ENABLED_TOOLTIP = "Draw the abilities of the weapon set you are not on, above the skill bar. They swap over when you swap weapons.",
	SI_PBSCHC_BACKBAR_EMPTY = "Show empty slots",
	SI_PBSCHC_BACKBAR_EMPTY_TOOLTIP = "Keep the frame of a slot with nothing in it, so the row stays the same width. Off, only the slots with an ability in them are drawn.",
	SI_PBSCHC_BACKBAR_SCALE = "Size of the row",
	SI_PBSCHC_BACKBAR_SCALE_TOOLTIP = "The size of the other set's icons, as a percentage. This is on top of the skill bar's own size, so a bar at 80% with a row at 80% draws the row smaller again.",
	SI_PBSCHC_BACKBAR_GAP = "Gap above the bar",
	SI_PBSCHC_BACKBAR_GAP_TOOLTIP = "How far above the skill bar the row sits. The row follows the bar wherever you put it, so this is the only distance that needs setting.",

	-- ---- The text on the icons ---------------------------------------------------------
	SI_PBSCHC_SECTION_TEXT = "Text on the skill bar",
	SI_PBSCHC_TEXT_EXPLANATION = "How long is left on each ability's effect, and how many targets are under it, written on the icon -- on both weapon sets. The time comes from the game itself, the same number its own bar timers use.",
	SI_PBSCHC_TIMER_MODE = "Countdown on the bar you are on",
	SI_PBSCHC_TIMER_MODE_TOOLTIP = "The set you are not on always gets this add-on's countdown, because the game never draws one there. On the set you are on the game draws its own when Settings > Interface > Action Bar Timers is on, at a size no add-on can change. This add-on: ours, with the game's faded out of the way, so the text size below always does something. Both: ours next to the game's. The game: the front bar is left alone.",
	SI_PBSCHC_TIMER_MODE_ADDON = "This add-on",
	SI_PBSCHC_TIMER_MODE_BOTH = "Both",
	SI_PBSCHC_TIMER_MODE_GAME = "The game",
	SI_PBSCHC_TIMER_SIZE = "Countdown text size (this bar)",
	SI_PBSCHC_TIMER_SIZE_TOOLTIP = "Size of the time left on the bar you are on. The game's own is 27.",
	SI_PBSCHC_TIMER_SIZE_BACK = "Countdown text size (other set)",
	SI_PBSCHC_TIMER_SIZE_BACK_TOOLTIP = "The same, for the row showing the weapon set you are not on. Its icons are smaller than the bar's, so a smaller number often reads better there. Until you move this, it follows the size above.",
	SI_PBSCHC_COUNT_SIZE_BACK = "Target count text size (other set)",
	SI_PBSCHC_COUNT_SIZE_BACK_TOOLTIP = "The same, for the row showing the weapon set you are not on. Until you move this, it follows the size above.",
	SI_PBSCHC_TEXT_SIZE_MATCH = "Match the other set to this bar",
	SI_PBSCHC_TEXT_SIZE_MATCH_TOOLTIP = "Forget the sizes set for the other weapon set's row, so it follows the bar you are on again.",
	SI_PBSCHC_TIMER_DECIMALS = "Tenths under ten seconds",
	SI_PBSCHC_TIMER_DECIMALS_TOOLTIP = "Under ten seconds, show one decimal place (9.4) instead of whole seconds. A minute or more is always shown as whole minutes.",
	SI_PBSCHC_COUNT_ENABLED = "Show the target count",
	SI_PBSCHC_COUNT_ENABLED_TOOLTIP = "How many targets are under the effect, in the corner of the icon. Counted from the effects you and anything of yours apply, and matched to the slot by the cast that produced it. A buff on yourself, or on a pet of yours, carries no number: the countdown beside it already says it is up.",
	SI_PBSCHC_COUNT_SIZE = "Target count text size (this bar)",
	SI_PBSCHC_COUNT_SIZE_TOOLTIP = "Size of the target count on the bar you are on.",
	SI_PBSCHC_COUNT_FROM_ONE = "Show it for a single target",
	SI_PBSCHC_COUNT_FROM_ONE_TOOLTIP = "Write the count even when there is only one target, which is how it starts. Off, the number appears from two targets, so a single-target ability does not carry a 1 for its whole duration -- but a single-target ability then shows nothing at all.",

	SI_PBSCHC_POSITION_X = "<<1>>: sideways",
	SI_PBSCHC_POSITION_X_TOOLTIP = "How far the middle of the bar is from the middle of the screen. 0 is dead centre, negative is to the left, positive is to the right.",
	SI_PBSCHC_POSITION_Y = "<<1>>: height",
	SI_PBSCHC_POSITION_Y_TOOLTIP = "How far the middle of the bar is up from the bottom edge of the screen. The game's own bars sit 137 up, clear of the skill bar.",

	SI_PBSCHC_SCALE = "<<1>>: size",
	SI_PBSCHC_SCALE_TOOLTIP = "The size of the bar, as a percentage of the game's own. The frame, the background, the bar itself and the numbers on it all grow and shrink together, and the bar stays where its middle was put. The small bar that belongs to it -- werewolf over magicka, mount stamina under stamina, siege health under health -- is given the same size.",

	SI_PBSCHC_RESET_BAR = "Reset <<1>>",
	SI_PBSCHC_RESET_BAR_TOOLTIP = "Put this one bar back where the game draws it, at the game's own size.",

	SI_PBSCHC_SECTION_GENERAL = "All three bars",
	SI_PBSCHC_RESET = "Reset everything",
	SI_PBSCHC_RESET_TOOLTIP = "Put all three bars back where the game draws them, at the game's own size.",
	SI_PBSCHC_RESET_BUTTON = "Reset",

	SI_PBSCHC_SECTION_TRACE = "Measurement",
	SI_PBSCHC_TRACE_HINT = "For working out why an ability's countdown is wrong. Press Start, cast the ability once -- for one that is aimed, place it once and cancel it once -- then press Show: what the game sent, and when, is written into the chat window. It records nothing until Start is pressed and stops again at Show, and it changes nothing on the screen either way.",
	SI_PBSCHC_TRACE_START = "Record a cast",
	SI_PBSCHC_TRACE_START_TOOLTIP = "Start writing down every press, ground-targeting circle, effect and combat event of the abilities you cast from now on.",
	SI_PBSCHC_TRACE_START_BUTTON = "Start",
	SI_PBSCHC_TRACE_SHOW = "Show what was recorded",
	SI_PBSCHC_TRACE_SHOW_TOOLTIP = "Stop recording and write the whole record into the chat window, oldest first, with the time each line arrived.",
	SI_PBSCHC_TRACE_SHOW_BUTTON = "Show",

	SI_PBSCHC_GAME_SETTINGS_HINT = "Whether the numbers are shown on the bars, and whether the bars fade out when nothing is happening, are the game's own settings under Settings > Interface. An add-on cannot change those, so set them there.",

	SI_PBSCHC_PREVIEW_CAPTION = "Resource bars (preview)",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
