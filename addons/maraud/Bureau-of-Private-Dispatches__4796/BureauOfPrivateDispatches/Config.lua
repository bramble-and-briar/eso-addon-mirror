local addon = BureauOfPrivateDispatches

-- Visual and behavioral release defaults. Player-owned state such as panel
-- position, collapsed state, scale, opacity, combat auto-collapse, and
-- unanswered whisper snapshots remains in SavedVariables.
addon.config =
{
	-- Panel geometry
	PANEL_WIDTH = 340,
	HEADER_HEIGHT = 26,
	HEADER_TO_CARDS_SPACING = 3,
	EXPANDED_CARD_HEIGHT = 42,
	COMPACT_CARD_HEIGHT = 24,
	CARD_SPACING = 2,
	OVERFLOW_HEIGHT = 20,

	-- Card internals
	RAIL_WIDTH = 3,
	CARD_HORIZONTAL_PADDING = 6,
	COMPACT_SENDER_WIDTH = 96,
	COMPACT_MESSAGE_GAP = 6,
	CLOSE_BUTTON_SIZE = 18,
	CLOSE_BUTTON_INSET = 4,
	META_GAP = 3,
	TIME_WIDTH = 36,
	COMPACT_TIME_WIDTH = 32,
	COUNT_WIDTH = 30,
	COMPACT_COUNT_WIDTH = 24,
	STATUS_WIDTH = 18,
	SENDER_ROW_OFFSET_Y = 4,
	SENDER_ROW_HEIGHT = 17,
	MESSAGE_ROW_OFFSET_Y = 22,
	MESSAGE_ROW_HEIGHT = 17,
	META_ROW_HEIGHT = 15,
	HEADER_HORIZONTAL_PADDING = 7,
	HEADER_COUNT_WIDTH = 110,
	HEADER_ICON_SIZE = 16,
	HEADER_CLEAR_TEXTURE = "EsoUI/Art/Buttons/minus_up.dds",
	HEADER_COLLAPSE_TEXTURE = "EsoUI/Art/Buttons/tree_open_up.dds",
	HEADER_EXPAND_TEXTURE = "EsoUI/Art/Buttons/tree_closed_up.dds",
	HEADER_LOCK_TEXTURE = "EsoUI/Art/Miscellaneous/locked_up.dds",
	HEADER_UNLOCK_TEXTURE = "EsoUI/Art/Miscellaneous/unlocked_up.dds",

	-- Notification limits
	MESSAGE_PREVIEW_CHARACTERS = 34,
	COMPACT_PREVIEW_CHARACTERS = 26,
	SENDER_DISPLAY_CHARACTERS = 20,
	COMPACT_SENDER_CHARACTERS = 14,
	DEFAULT_VISIBLE_SENDERS = 6,
	MAX_VISIBLE_SENDERS = 12,
	MAX_TRACKED_SENDERS = 48,
	MAX_DISMISSED_TAPE = 20,
	MAX_DISPLAYED_UNREAD = 99,
	MAX_DISPLAYED_TOTAL_UNREAD = 999,

	-- Unanswered whispers are snapshotted per character so they survive
	-- ReloadUI. Message text is never stored: only sender identity, unread
	-- count, and timestamps. Public chat and answered cards are omitted.
	WHISPER_RESTORE_MAX_AGE_SECONDS = 21600,
	WHISPER_RESTORE_MAX_CHARACTERS = 8,
	WHISPER_RESTORE_MAX_QUEUED_EVENTS = 64,
	-- Restored cards never persist message text. If pChat is loaded, a matching
	-- incoming whisper may be copied from its in-memory LineStrings only.
	PCHAT_PREVIEW_TIMESTAMP_SLACK_SECONDS = 30,

	-- Follow-up lifecycle. The timer starts with the first unanswered whisper in
	-- a cycle. Opening the reply composer grants a short grace period, but only an
	-- observed outgoing whisper marks the cycle as answered.
	FOLLOW_UP_WAITING_MS = 90000,
	FOLLOW_UP_OVERDUE_MS = 180000,
	FOLLOW_UP_REPLY_GRACE_MS = 30000,
	FOLLOW_UP_REPLY_TARGET_MAX_AGE_MS = 600000,
	FOLLOW_UP_ANSWERED_VISIBLE_MS = 4000,
	FOLLOW_UP_WAITING_SECONDS_MIN = 15,
	FOLLOW_UP_WAITING_SECONDS_MAX = 300,
	FOLLOW_UP_OVERDUE_SECONDS_MIN = 30,
	FOLLOW_UP_OVERDUE_SECONDS_MAX = 600,
	FOLLOW_UP_OVERDUE_GAP_SECONDS = 15,
	FOLLOW_UP_REPLY_GRACE_SECONDS_MIN = 5,
	FOLLOW_UP_REPLY_GRACE_SECONDS_MAX = 120,
	FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MIN = 1,
	FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MAX = 15,

	-- Default position and screen clamping
	DEFAULT_INSET_RIGHT = 70,
	DEFAULT_TOP = 180,
	MAX_ABSOLUTE_OFFSET = 8192,
	MIN_ONSCREEN_MARGIN = 24,
	PANEL_SCALE_MIN = 0.85,
	PANEL_SCALE_MAX = 1.50,
	PANEL_SCALE_DEFAULT = 1.00,
	PANEL_OPACITY_MIN = 0.40,
	PANEL_OPACITY_MAX = 1.00,
	PANEL_OPACITY_DEFAULT = 1.00,

	-- Font descriptors
	FONT_FACE = "$(MEDIUM_FONT)",
	FONT_FACE_BOLD = "$(BOLD_FONT)",
	FONT_STYLE = "soft-shadow-thin",
	HEADER_FONT_SIZE = 12,
	HEADER_COUNT_FONT_SIZE = 12,
	SENDER_FONT_SIZE = 14,
	MESSAGE_FONT_SIZE = 12,
	COMPACT_FONT_SIZE = 12,
	META_FONT_SIZE = 11,
	GLYPH_FONT_SIZE = 15,
	OVERFLOW_FONT_SIZE = 11,

	-- House palette
	HEADER_BACKGROUND_COLOR = { 0.030, 0.038, 0.048, 0.94 },
	CARD_BACKGROUND_COLOR = { 0.055, 0.065, 0.078, 0.93 },
	CARD_HOVER_COLOR = { 0.078, 0.088, 0.100, 0.95 },
	OVERFLOW_BACKGROUND_COLOR = { 0.030, 0.038, 0.048, 0.90 },
	HAIRLINE_COLOR = { 0.16, 0.20, 0.23, 0.85 },
	TRANSPARENT_COLOR = { 0, 0, 0, 0 },
	ACCENT_COLOR = { 0.435, 0.796, 0.624, 1.00 },
	HEADER_TEXT_COLOR = { 0.72, 0.76, 0.78, 1.00 },
	SENDER_TEXT_COLOR = { 0.90, 0.90, 0.87, 1.00 },
	MESSAGE_TEXT_COLOR = { 0.68, 0.71, 0.73, 1.00 },
	MUTED_TEXT_COLOR = { 0.46, 0.49, 0.52, 1.00 },
	COUNT_TEXT_COLOR = { 0.75, 0.78, 0.77, 1.00 },
	GLYPH_COLOR = { 0.52, 0.55, 0.57, 1.00 },
	GLYPH_HOVER_COLOR = { 0.90, 0.90, 0.87, 1.00 },
	FOCUS_RAIL_COLOR = { 0.92, 0.92, 0.88, 1.00 },
	DISMISS_HOVER_COLOR = { 0.90, 0.40, 0.36, 1.00 },
	FOLLOW_UP_WAITING_COLOR = { 0.72, 0.64, 0.40, 1.00 },
	FOLLOW_UP_OVERDUE_COLOR = { 0.96, 0.58, 0.24, 1.00 },
	FOLLOW_UP_ANSWERED_COLOR = { 0.435, 0.796, 0.624, 1.00 },
	RELATION_GROUP_COLOR = { 0.400, 0.700, 0.850, 1.00 },
	RELATION_FRIEND_COLOR = { 0.850, 0.720, 0.400, 1.00 },
	RELATION_GUILD_COLOR = { 0.720, 0.560, 0.850, 1.00 },

	-- Stable per-sender identity hues
	SENDER_HUES =
	{
		{ 0.435, 0.796, 0.624, 1.00 },
		{ 0.400, 0.700, 0.850, 1.00 },
		{ 0.850, 0.720, 0.400, 1.00 },
		{ 0.720, 0.560, 0.850, 1.00 },
		{ 0.900, 0.520, 0.440, 1.00 },
	},

	-- Pulse animation
	PULSE_MIN_ALPHA = 0.00,
	PULSE_MAX_ALPHA = 0.60,
	PULSE_TINT_ALPHA = 0.12,
	PULSE_DURATION_MS = 850,
	PULSE_LOOP_COUNT = 2,
	FOLLOW_UP_REMINDER_MAX_ALPHA = 0.80,
	FOLLOW_UP_REMINDER_TINT_ALPHA = 0.22,
	FOLLOW_UP_REMINDER_DURATION_MS = 650,
	FOLLOW_UP_REMINDER_LOOP_COUNT = 3,
	FOLLOW_UP_REMINDER_SOUND = "NEW_TIMED_NOTIFICATION",
	INCOMING_SOUND = "NEW_MAIL",
	INCOMING_SOUND_THROTTLE_MS = 1500,
	DND_DURATION_SECONDS = 300,

	-- Card draw levels
	DRAW_LEVEL_BACKGROUND = 0,
	DRAW_LEVEL_WASH = 1,
	DRAW_LEVEL_ACCENT = 2,
	DRAW_LEVEL_CONTENT = 3,

	-- Relative timestamp refresh
	CLOCK_INTERVAL_MS = 1000,
	INTERACTION_UNLOCK_DELAY_MS = 75,
}