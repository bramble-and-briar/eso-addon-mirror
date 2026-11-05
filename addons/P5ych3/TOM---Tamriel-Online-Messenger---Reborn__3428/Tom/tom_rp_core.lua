--	TOM Reborn - Roleplay - Core (v6.5.0)
--	✅ P5YCH3: New file. Text strings, settings, the chat adapter (fills the chat box, notices when the player sends), the part queue
--	and the optional session archive. The addon never sends: it places one part in the chat box and the player presses Enter.

tomRP = tomRP or {}
local RP = tomRP
RP.name = "tomRoleplay"
RP.version = "6.5.0"
RP.ready = false

local Splitter = RP.Splitter

--===============================================================================================================
-- TEXT
--===============================================================================================================
-- ✅ P5YCH3: All player text is in this table. Other languages fall back to English; to translate, copy it as RP.Strings.<code> and keep %s / %d in the same order.
RP.Strings = {}
RP.Strings.en = {
	-- main window / button
	CMD_HEADER = "TOM - Roleplay", CMD_OPEN = "Opens or closes the Roleplay panel.", CMD_ALIAS = "Short form of /tomrp (only when no other addon uses it).",
	CMD_PAUSE = "Pauses the post being sent.", CMD_RESUME = "Prepares the current part again and carries on.",
	CMD_NEXT = "Skips to the next part (the skipped part is not counted as sent).", CMD_PREVIOUS = "Prepares the previous part again (check chat first, it may already have been sent).",
	CMD_CANCEL = "Cancels the post being sent.", CMD_TEST = "Runs a quick self-check of the text splitter.",
	CMD_DEBUG = "Turns a step-by-step trace in chat on or off (no message text is shown).",
	KEY_TOGGLE = "Roleplay: open / close the panel", KEY_NEXT = "Roleplay: prepare / resume the current part",
	BUTTON_TIP = "Roleplay: write a long post and send it in chat-sized parts",
	TITLE = "Roleplay",
	TAB_COMPOSE = "Compose", TAB_SESSIONS = "Sessions", TAB_LIBRARY = "Library",
	BACK_TO_TOM_TIP = "Back to TOM: show the main window and close this one.",
	CLOSE_TIP = "Close", HELP_TIP = "How it works",
	HELP_BODY = "1. Write or paste your post in the big box.\n2. Pick where it goes (Say, Emote, Group, Whisper or a Guild).\n3. Press Start. The first part appears in your normal chat box.\n4. Read it, then press Enter yourself. The next part loads on its own.\n\nThe addon never sends for you. Escape, changing channel or opening chat by hand pauses it safely.\nYour unsent text is kept when you reload or log out.\n\nDrag the edges of the window to resize it. When it gets small, the extra tools fold behind small buttons (Tools..., Options..., Preview... and so on) and return by themselves when there is room.",
	-- compose
	TO = "To:", WHISPER_TO = "Whisper to:", USE_CURRENT = "Use my chat channel", USE_CURRENT_TIP = "Copy the channel (and whisper name) your chat box is on right now.",
	PLACEHOLDER = "Write or paste your roleplay post here...",
	STATS = "%s characters  -  %s parts  -  longest part %d of %d",
	STATS_EMPTY = "Nothing written yet",
	STATS_ERROR = "%s",
	POLISH = "Polish", POLISH_TIP = "Tidy typography: ... becomes an ellipsis, -- becomes a dash, straight quotes become curly quotes. You can undo it.",
	UNDO = "Undo", CLEAR = "Clear", CLEAR_CONFIRM = "Really clear?", CLEAR_TIP = "Empty the box (press twice). Your text is kept for Undo.",
	INSERT_TIP = "Insert at the cursor",
	MAX_CHARS = "Max chars", PREFIX = "Prefix", SUFFIX = "Suffix", APPLY = "Apply",
	MARKERS = "Markers", MARKERS_TIP = "Pick a ready-made look for the ends of each part.",
	PRESET_PLUS = "+ text +", PRESET_NUMBERS = "(1/3) text on every part", PRESET_QUOTES = "\"text\" on every part", PRESET_ELLIPSIS = "text... ...text", PRESET_ARROWS = "text >> >> text", PRESET_NONE = "No markers",
	MODE_BETWEEN = "Markers: between parts", MODE_EVERY = "Markers: every part",
	MODE_TIP = "Between parts: the first part has no prefix and the last part has no suffix, so \"+ text +\" reads as a continuation. Every part: each part, even a single one, gets both (for quotation marks or numbering).",
	SET_KEEP_CATACOMB = "Keep Catacombs open when TOM closes",
	SET_KEEP_CATACOMB_TIP = "On: closing the main TOM window leaves the Catacombs window open until you close it yourself. Combat and menu settings still hide it. Off: the Catacombs close with the main window.",
	SET_KEEP_RP = "Keep Roleplay open when TOM closes",
	SET_KEEP_RP_TIP = "On: closing the main TOM window leaves the Roleplay panel open until you close it yourself. Off: the Roleplay panel closes with the main window. A post in progress keeps going and shows its progress bar.",
	SET_KEEP_MAGIC = "Keep Magic Messages open when TOM closes",
	SET_KEEP_MAGIC_TIP = "On: closing the main TOM window leaves the Magic Messages window open until you close it yourself. Combat and menu settings still hide it. Off: Magic Messages closes with the main window.",
	SET_KEEP_GUILD = "Keep Guild Functions open when TOM closes",
	SET_KEEP_GUILD_TIP = "On: closing the main TOM window leaves the Guild Functions window open until you close it yourself. Combat and menu settings still hide it. Off: Guild Functions closes with the main window.",
	SET_KEEP_TOM_MAGIC = "Keep TOM open when Magic Messages opens",
	SET_KEEP_TOM_MAGIC_TIP = "On: opening Magic Messages leaves the main TOM window open. Off: the main window closes when Magic Messages opens, and Magic Messages stays open until you close it.",
	SET_KEEP_TOM_GUILD = "Keep TOM open when Guild Functions opens",
	SET_KEEP_TOM_GUILD_TIP = "On: opening Guild Functions leaves the main TOM window open. Off: the main window closes when Guild Functions opens, and Guild Functions stays open until you close it.",
	SET_KEEP_TOM_CATACOMB = "Keep TOM open when Catacombs opens",
	SET_KEEP_TOM_CATACOMB_TIP = "On: opening the Catacombs leaves the main TOM window open. Off: the main window closes when the Catacombs open, and the Catacombs stay open until you close them.",
	SET_KEEP_TOM_RP = "Keep TOM open when Roleplay opens",
	SET_KEEP_TOM_RP_TIP = "On: opening the Roleplay panel leaves the main TOM window open. Off: the main window closes when the Roleplay panel opens, and the panel stays open until you close it.",
	SENTENCES_ON = "Sentences: prefer", SENTENCES_OFF = "Sentences: ignore",
	SENTENCES_TIP = "On: parts end at the end of a sentence when possible. Off: parts end at any space.",
	PARAGRAPHS_ON = "Paragraphs: own part", PARAGRAPHS_OFF = "Paragraphs: merge",
	PARAGRAPHS_TIP = "On: every paragraph (blank line) starts a new part. Off: short paragraphs share a part.",
	TAG_ON = "Shared tag: on", TAG_OFF = "Shared tag: off",
	TAG_TIP = "Adds an invisible 4-character mark to each part so tagged lines can be recognised (for example when recording). It uses 4 characters of every part.",
	POP_TOOLS = "Tools...", POP_OPTIONS = "Options...", POP_PREVIEW = "Preview...", POP_SESSION = "Session...", POP_PEOPLE = "People...", POP_RECORDING = "Recording...", POP_SAVE = "Save...",
	PREVIEW_TITLE = "Part %d of %d  (%d of %d characters)", PREVIEW_HELP = "Your parts appear here as you write.",
	START = "Start sending", CONTINUE = "Continue: part %d of %d", CONTINUE_TIP = "Your last post was interrupted. Pick up at the next unsent part.",
	CONTINUE_CHANGED = "The part count changed from %d to %d (the chat limit or your settings changed). Check part %d before sending.",
	PROGRESS = "Part %d of %d", PROGRESS_SENT = "%d sent", IDLE = "Ready. Write something, then press Start sending.",
	PAUSE = "Pause", RESUME = "Resume", PREVIOUS = "Previous", NEXT = "Next", FINISH = "Finish", CANCEL = "Cancel",
	PREVIOUS_WARNING = "Previous prepares an older part again. It may already have been sent - check chat before pressing Enter.",
	-- indicator
	BAR_DONE = "Roleplay  done",
	BAR_TITLE = "Roleplay  %d / %d", BAR_TITLE_PAUSED = "Roleplay  %d / %d  (paused)", BAR_OPEN = "Open",
	-- notices
	NOTICE_STARTED = "Part 1 is in your chat box. Press Enter to send it.",
	NOTICE_NEXT_READY = "Part %d of %d is in your chat box. Press Enter when ready.",
	NOTICE_DONE = "All %d parts sent.",
	NOTICE_DONE_PARTIAL = "The last part was sent, but not every part was seen being sent.",
	NOTICE_SETTINGS = "Settings applied.", NOTICE_POLISHED = "Text polished.", NOTICE_NOTHING_TO_UNDO = "Nothing to undo.",
	NOTICE_SAVED = "Saved to your library.", NOTICE_DELETED = "Deleted.", NOTICE_LOADED = "Loaded into the composer.", NOTICE_INSERTED = "Inserted.",
	NOTICE_DRAFT_RESTORED = "Your unsent text was restored.",
	-- why a queue stops (shown as the reason)
	Q_NOT_ACTIVE = "No post is being sent.", Q_ACTIVE = "A post is already being sent. Finish or cancel it first.", Q_PAUSED = "Paused.",
	Q_CANCELLED = "Cancelled. Nothing was changed in your chat box.", Q_READY = "Ready: check the part in chat, then press Enter.",
	Q_NO_PART = "There is no part at this position.", Q_NOT_READY = "Not ready yet.", Q_EMPTY = "There is nothing to send.",
	Q_WAITING_ECHO = "Waiting for the game to show your line in chat...", Q_ECHO_TIMEOUT = "No sign of that line in chat after 10 seconds. Check chat, then use Next or Resume.",
	Q_AMBIGUOUS = "That text was already sent to this place earlier, so the game cannot tell if this is a new send. Check chat, then use Next.",
	Q_UNCONFIRMED = "The last line was sent but not seen yet. Wait a moment or use Next.",
	Q_PREPARING_NEXT = "Preparing the next part...", Q_FINISHED_MANUALLY = "Finished by hand.", Q_FIRST_PART = "This is the first part.",
	Q_INPUT_REOPENED = "Chat was opened by hand.", Q_INPUT_CLOSED = "The chat box was closed.", Q_CHANNEL_CHANGED = "The chat channel was changed. Resume returns to the original one.",
	Q_SUBMIT_UNSEEN = "The line was submitted but could not be matched. Check chat, then use Next or Resume.",
	Q_DEACTIVATED = "You changed zones or logged out.",
	Q_BAD_DESTINATION = "That destination is not available right now.", Q_BAD_TARGET = "Enter the character or @account name to whisper.",
	Q_UNSAFE = "That part cannot be placed safely in the chat box.", Q_EXISTING_DRAFT = "There is already text in your chat box. Send or clear it first, then Resume.",
	Q_STAGE_MISMATCH = "The chat box did not accept the part (chat may be closed or busy). Press Resume to try again.",
	Q_KEYBOARD_ONLY = "Roleplay works with the keyboard chat only.", Q_NO_LIMIT = "The chat length limit is not available yet.",
	Q_HOOKS = "Chat cannot be watched right now.", Q_CHANNEL_DIFFERENT = "Your chat channel is not the one this post was started in. Resume returns to it.",
	-- splitter refusals
	E_MAX_RANGE = "Max chars must be a whole number from 1 to %d (or empty for the full chat length).",
	E_LIMIT = "The part length is not valid.", E_TOO_SMALL = "The part length is too small for the markers. Raise it or shorten the markers.",
	E_BAD_TEXT = "The text contains a character the game cannot place in chat.", E_PIPE = "Remove the | character (the game treats it as the start of colour or link codes).",
	E_CONTROL = "The text contains an invisible control character.", E_EMPTY = "Write something first.",
	E_MARKER = "The markers cannot contain | or line breaks.", E_PREFIX_COMMAND = "The start marker may not begin with /.",
	E_STARTS_COMMAND = "Part %d would start with / and be run as a command. Change the wording or the markers.",
	-- destinations
	CH_SAY = "Say", CH_YELL = "Yell", CH_EMOTE = "Emote", CH_PARTY = "Group", CH_WHISPER = "Whisper", CH_GUILD = "Guild %d", CH_OFFICER = "Officers %d",
	-- sessions
	SESSION_NAME = "Session name", CREATE_SESSION = "Create session", NO_SESSION = "No session selected. Create one to start.",
	SESSION_TITLE = "%s  (%d of %d)", SESSION_INFO = "Created %s",
	PARTICIPANTS = "People to record (one per line; character name or @account). Your own lines are always recorded.",
	PARTICIPANTS_DIRTY = "People to record - not saved yet",
	SAVE_PARTICIPANTS = "Save people", RECORD_START = "Start recording", RECORD_STOP = "Stop recording",
	RECORDING = "Recording: %s", RECORDING_HELP = "Chat from you and your saved people is stored on this computer.",
	RECORD_WARNING_OFF = "Recording is off. Ask people before you record what they write; whispers are included when they involve you.",
	RECORD_WARNING_ON = "|cFF4040RECORDING|r  your lines and your saved people's lines, in every chat channel, including whispers. Stop when the scene ends.",
	ADDON_ONLY_ON = "Only tagged lines: on", ADDON_ONLY_OFF = "Only tagged lines: off",
	ADDON_ONLY_TIP = "On: keep only lines that carry the shared roleplay tag (turn the tag on in Compose). The tag is a label, not security.",
	DELETE_SESSION = "Delete session", DELETE_CONFIRM = "Really delete?", SESSION_CREATED = "Session created.", SESSION_DELETED = "Session deleted.",
	PARTICIPANTS_SAVED = "People saved.", RECORDING_ON_NOTICE = "Recording started.", RECORDING_OFF_NOTICE = "Recording stopped.",
	HISTORY_TITLE = "Page %d of %d  -  %d lines kept  -  %d dropped", HISTORY_NEWEST = "Newest first", HISTORY_OLDEST = "Oldest first",
	HISTORY_OUT = "[%s] You: %s", HISTORY_IN = "[%s] %s: %s", SELECT_ALL = "Select all", SELECT_ALL_TIP = "Select the page so you can copy it with Ctrl+C.",
	SESSION_LIMIT = "You can keep up to 50 sessions. Delete one first.",
	-- library
	QUICKSAVE_PROMPT = "Name for this saved text", QUICKSAVE_TIP = "Save the composed text to the Library under a name.",
	LIB_NAME = "Name", LIB_SAVE = "Save current text", LIB_LOAD = "Load", LIB_INSERT = "Insert at cursor", LIB_DELETE = "Delete", LIB_DELETE_CONFIRM = "Really delete?",
	LIB_HELP = "Keep openings, descriptions and favourite lines here. Load replaces the composer (Undo brings the old text back); Insert adds the entry where your cursor is. Press \"Save...\" at any time to preserve the state of your composed message.",
	LIB_EMPTY = "Your library is empty. Write something in Compose, give it a name above, and press Save.", LIB_LIMIT = "The library holds up to 60 entries. Delete one first.",
	LIB_NEED_NAME = "Give it a name first.", LIB_NEED_TEXT = "There is no text to save.", LIB_SELECT = "Pick an entry from the list.",
	LIB_LINE = "%s   (%d characters)", LIB_PICK = "Saved entries",
	-- misc
	UNKNOWN_SENDER = "Unknown", UNKNOWN_TIME = "?",
	DEBUG_ON = "Roleplay debug is on. Trace lines show in chat (no message text).", DEBUG_OFF = "Roleplay debug is off.",
	TEST_PASSED = "Roleplay self-test passed.", TEST_FAILED = "Roleplay self-test FAILED: %s",
	HELP_COMMANDS = "/tomrp  open the panel.   /tomrp pause | resume | next | previous | cancel   control the queue.   /tomrp test   self-test.   /tomrp debug   trace.",
	NOT_READY = "The Roleplay panel is not ready yet. Try again in a moment.",
	SOUND = "Play a soft sound when the next part is ready", SOUND_ON = "Sound: on", SOUND_OFF = "Sound: off", SOUND_TIP = "A soft click when the next part is ready in your chat box.",
}

local function langCode()
	local ok, code = pcall(GetCVar, "language.2")
	if ok and type(code) == "string" then return string.lower(code) end
	return "en"
end

function RP.L(key, ...)
	local set = RP.Strings[langCode()] or RP.Strings.en
	local text = set[key] or RP.Strings.en[key] or key
	if select("#", ...) == 0 then return text end
	return string.format(text, ...)
end
local L = RP.L

--===============================================================================================================
-- SETTINGS
--===============================================================================================================
-- ✅ P5YCH3: Own saved-variables table (tomrpvars), kept apart from tomvars so "/tom reset" never touches drafts, library or archives.
RP.defaults = {
	maxChars = 0,			-- 0 = use the live chat limit
	prefix = "", suffix = "",	-- no markers until the player picks a style (Markers drop-down) or types their own
	sentences = true, paragraphs = false, everyPart = true, tag = false, sound = true, clearWhenDone = true,
	draft = "",				-- unsent text, restored after a reload
	progress = nil,			-- the post being sent: { text, confirmed, total, channel, target, ... } so it can be continued
	destination = { channel = 0, target = "" },
	library = {}, nextLibraryId = 1,
	sessions = {}, nextSessionId = 1,
	historyNewestFirst = true,
	window = {}, bar = {},
	debug = false,
}

function RP.Trace(event, details)
	if not (RP.sv and RP.sv.debug) then return end
	pcall(function()
		local q = RP.Queue
		d(string.format("[TOM-RP %s] %s | active=%s paused=%s staged=%s pending=%s", tostring(GetFrameTimeMilliseconds()), event .. (details and (" " .. details) or ""),
			tostring(q.active == true), tostring(q.paused == true), tostring(q.staged ~= nil), tostring(q.pending ~= nil)))
	end)
end
local trace = RP.Trace

function RP.Notify(message)
	-- ✅ P5YCH3: Status text goes to the panel (and the floating bar), never into chat, and never includes the player's draft.
	if RP.UI and RP.UI.Notify then RP.UI.Notify(message) end
end

--===============================================================================================================
-- CHAT ADAPTER
--===============================================================================================================
local Chat = { Destinations = {} }
RP.Chat = Chat
local hookState = setmetatable({}, { __mode = "k" })
local preparing, submitting, owned = false, nil, nil
local submissionSequence = 0

local function chatSystem() return ZO_GetChatSystem() end
local function keyboardMode() return not IsInGamepadPreferredMode() end

-- Whisper names compare ignoring case and the game's grammar suffixes.
function RP.NormalizeName(value)
	if type(value) ~= "string" then return "" end
	local name = value:gsub("^%s+", ""):gsub("%s+$", "")
	if name ~= "" and type(zo_strformat) == "function" then
		name = zo_strformat("<<1>>", name):gsub("^%s+", ""):gsub("%s+$", "")
	end
	return string.lower(name)
end
local normal = RP.NormalizeName

function Chat.Init()
	Chat.Destinations = {
		{ label = L("CH_SAY"), channel = CHAT_CHANNEL_SAY },
		{ label = L("CH_YELL"), channel = CHAT_CHANNEL_YELL },
		{ label = L("CH_EMOTE"), channel = CHAT_CHANNEL_EMOTE },
		{ label = L("CH_PARTY"), channel = CHAT_CHANNEL_PARTY },
		{ label = L("CH_WHISPER"), channel = CHAT_CHANNEL_WHISPER },
	}
	for i = 1, 5 do
		Chat.Destinations[#Chat.Destinations + 1] = { label = L("CH_GUILD", i), channel = _G["CHAT_CHANNEL_GUILD_" .. i], guildIndex = i }
		Chat.Destinations[#Chat.Destinations + 1] = { label = L("CH_OFFICER", i), channel = _G["CHAT_CHANNEL_OFFICER_" .. i], guildIndex = i }
	end
end

-- The channel and whisper target the chat box is on right now.
function Chat.Current()
	local chat = chatSystem()
	if not chat then return nil end
	return chat.currentChannel, chat.currentTarget
end

function Chat.SameDestination(channel, target, expectedChannel, expectedTarget)
	return channel == expectedChannel and (channel ~= CHAT_CHANNEL_WHISPER or normal(target) == normal(expectedTarget))
end

-- One chat line may hold at most this many characters: the game constant and the live edit box, whichever is smaller.
function Chat.GetLimit()
	local chat = chatSystem()
	local limit = MAX_TEXT_CHAT_INPUT_CHARACTERS
	local entry = chat and chat.textEntry
	local edit = entry and entry:GetEditControl()
	local controlLimit = edit and edit:GetMaxInputChars()
	if type(limit) ~= "number" or limit <= 0 then limit = controlLimit end
	if type(controlLimit) == "number" and controlLimit > 0 and type(limit) == "number" then limit = math.min(limit, controlLimit) end
	if type(limit) ~= "number" or limit < 1 or limit ~= math.floor(limit) then return nil, L("Q_NO_LIMIT") end
	return limit
end

-- Is this destination one we offer, and can the player use it right now? Returns true, or nil + reason.
function Chat.Validate(channel, target)
	local supported
	for _, destination in ipairs(Chat.Destinations) do
		if channel ~= nil and channel == destination.channel then supported = true; break end
	end
	if not supported then return nil, L("Q_BAD_DESTINATION") end
	if channel == CHAT_CHANNEL_WHISPER and (normal(target) == "" or target:find("[|\r\n]")) then return nil, L("Q_BAD_TARGET") end
	local info = ZO_ChatSystem_GetChannelInfo()[channel]
	if not info or (info.requires and not info.requires(channel)) then return nil, L("Q_BAD_DESTINATION") end
	return true
end

function Chat.ClearOwnership() owned = nil end

-- Does a chat event look like OUR line coming back? Same channel, same text (checked by the caller), and we are the sender.
-- Outgoing whispers come back as CHAT_CHANNEL_WHISPER_SENT and their name fields describe the RECIPIENT, so they are matched on the target.
function Chat.MatchesEcho(attempt, channel, fromName, fromDisplayName)
	if attempt.channel == CHAT_CHANNEL_WHISPER then
		if channel ~= CHAT_CHANNEL_WHISPER_SENT then return false end
		local recipient = normal(attempt.target)
		return recipient ~= "" and (recipient == normal(fromName) or recipient == normal(fromDisplayName))
	end
	if channel ~= attempt.channel then return false end
	local account = normal(fromDisplayName)
	if account ~= "" then return account == normal(GetDisplayName()) end
	local sender = normal(fromName)
	return sender ~= "" and (sender == normal(GetDisplayName()) or sender == normal(GetUnitName("player")))
end

-- Watches the stock chat box without replacing anything. Hooks are installed on first use and re-checked before each part.
function Chat.EnsureHooks()
	if not keyboardMode() then return nil, L("Q_KEYBOARD_ONLY") end
	local chat = chatSystem()
	local entry = chat and chat.textEntry
	if not chat or not entry or type(entry.AddCommandHistory) ~= "function" or type(chat.SubmitTextEntry) ~= "function" then return nil, L("Q_HOOKS") end
	local state = hookState[chat]
	if not state then
		state = {}
		hookState[chat] = state
		SecurePostHook(chat, "StartTextEntry", function()
			if not preparing then
				owned = nil
				if RP.Queue.active then RP.Queue.Pause(L("Q_INPUT_REOPENED")) end
			end
		end)
		SecurePostHook(chat, "CloseTextEntry", function()
			if not preparing and not submitting then
				owned = nil
				if RP.Queue.active then RP.Queue.Pause(L("Q_INPUT_CLOSED")) end
			end
		end)
		SecurePostHook(chat, "SetChannel", function()
			if not preparing and RP.Queue.active and not Chat.SameDestination(chat.currentChannel, chat.currentTarget, RP.Queue.channel, RP.Queue.target) then
				owned = nil
				RP.Queue.Pause(L("Q_CHANNEL_CHANGED"))
			end
		end)
	end
	-- The submitted text is read from AddCommandHistory; it is hooked late because other chat addons replace that method.
	if state.history ~= entry.AddCommandHistory then
		state.historyVersion = (state.historyVersion or 0) + 1
		local version = state.historyVersion
		SecurePostHook(entry, "AddCommandHistory", function(_, text)
			if state.historyVersion == version and submitting and submitting.chat == chat and not preparing then
				if submitting.associate and RP.Queue.staged == submitting.staged then
					RP.Queue.ObserveSubmission(text, chat.currentChannel, chat.currentTarget)
				else
					RP.Queue.ObserveUnassociated(text, chat.currentChannel, chat.currentTarget)
				end
			end
		end)
		state.history = entry.AddCommandHistory
	end
	if state.submit ~= chat.SubmitTextEntry then
		state.submitVersion = (state.submitVersion or 0) + 1
		local version = state.submitVersion
		-- Pre-hook: open a record of this submission. It returns nothing, so the original always runs.
		ZO_PreHook(chat, "SubmitTextEntry", function()
			if state.submitVersion ~= version then return end
			local hardware = keyboardMode() and WINDOW_MANAGER:IsHandlingHardwareEvent()
			submissionSequence = submissionSequence + 1
			submitting = { chat = chat, staged = RP.Queue.staged, owned = owned, previous = submitting,
				associate = keyboardMode() and hardware and RP.Queue.active and not RP.Queue.paused and RP.Queue.staged ~= nil, id = submissionSequence }
			trace("SUBMIT_BEGIN", "id=" .. submissionSequence .. " associate=" .. tostring(submitting.associate))
		end)
		-- Post-hook: close the record. A staged part still outstanding means we could not match it, so pause instead of guessing.
		SecurePostHook(chat, "SubmitTextEntry", function()
			if state.submitVersion == version and submitting and submitting.chat == chat then
				local finished = submitting
				submitting = finished.previous
				if owned == finished.owned then owned = nil end
				if RP.Queue.active and finished.staged and RP.Queue.staged == finished.staged then RP.Queue.Pause(L("Q_SUBMIT_UNSEEN")) end
			end
		end)
		state.submit = chat.SubmitTextEntry
	end
	return true
end

-- Put one part into the chat box (never send it). Returns true, or nil + reason.
function Chat.Prepare(text, channel, target, automatic)
	local ok, err = Chat.EnsureHooks()
	if not ok then return nil, err end
	ok, err = Chat.Validate(channel, target)
	if not ok then return nil, err end
	local limit = Chat.GetLimit()
	local length = Splitter.Length(text)
	local body = Splitter.StripTag(text)
	if not limit or not length or length > limit or body == "" or body:match("^%s*/") or text:find("[|\r\n]") then return nil, L("Q_UNSAFE") end
	local chat = chatSystem()
	if not chat or not chat.textEntry then return nil, L("Q_HOOKS") end
	if automatic and not Chat.SameDestination(chat.currentChannel, chat.currentTarget, channel, target) then return nil, L("Q_CHANNEL_DIFFERENT") end
	-- never overwrite something the player is typing: the box must be empty or still hold exactly what we put there for this destination
	local existing = chat.textEntry:GetText()
	if existing ~= "" and not (owned and owned.chat == chat and existing == owned.text and Chat.SameDestination(chat.currentChannel, chat.currentTarget, owned.channel, owned.target)) then
		return nil, L("Q_EXISTING_DRAFT")
	end
	preparing = true
	StartChatInput(text, channel, target)
	preparing = false
	-- StartChatInput returns nothing and quietly does nothing in several situations, so read the box back
	if chatSystem() ~= chat or not chat.textEntry:IsOpen() or chat.textEntry:GetText() ~= text or not Chat.SameDestination(chat.currentChannel, chat.currentTarget, channel, target) then
		owned = nil
		return nil, L("Q_STAGE_MISMATCH")
	end
	owned = { chat = chat, text = text, channel = channel, target = target }
	return true
end

--===============================================================================================================
-- THE PART QUEUE
--===============================================================================================================
local Q = { active = false, paused = false, chunks = {}, current = 0, generation = 0 }
RP.Queue = Q
local retired, retiredCount, serial = {}, 0, 0
local confirmed, confirmedCount = {}, 0
local MAX_FINGERPRINTS = 4096

local function refresh() if RP.UI and RP.UI.Refresh then RP.UI.Refresh() end end

-- The game gives no message id, so a line is recognised by channel + whisper name + exact text. Anything sent before with the same
-- fingerprint makes a new send ambiguous (a late echo of the old one would look identical), and the queue then asks the player.
local function fingerprint(text, channel, target)
	return tostring(channel) .. "\031" .. normal(target) .. "\031" .. text
end

local function retire(attempt)
	if not attempt or retired[attempt.key] then return end
	if retiredCount < MAX_FINGERPRINTS then retired[attempt.key] = true; retiredCount = retiredCount + 1 else Q.manualOnly = true end
end

-- Any change the player makes bumps the generation so a timer that was waiting cannot stage the wrong part.
local function invalidate() Q.generation = Q.generation + 1; Q.staged = nil end

function Q.Pause(reason)
	if not Q.active then return nil, L("Q_NOT_ACTIVE") end
	trace("PAUSE", reason)
	invalidate()
	Q.paused, Q.reason = true, reason or L("Q_PAUSED")
	refresh()
	return true
end

function Q.Cancel()
	trace("CANCEL")
	retire(Q.pending)
	invalidate()
	Q.active, Q.paused, Q.pending = false, false, nil
	Q.chunks, Q.current, Q.channel, Q.target = {}, 0, nil, nil
	Q.reason = L("Q_CANCELLED")
	Chat.ClearOwnership()
	refresh()
	return true
end

function Q.Stage(automatic)
	if not Q.active or Q.paused or Q.pending then return nil, L("Q_NOT_READY") end
	local text = Q.chunks[Q.current]
	if not text then return nil, L("Q_NO_PART") end
	local ok, err = Chat.Prepare(text, Q.channel, Q.target, automatic)
	if not ok then Q.Pause(err); return nil, err end
	Q.staged = { text = text, index = Q.current, generation = Q.generation }
	Q.reason = L("Q_READY")
	trace("STAGED", "part=" .. Q.current)
	if automatic and RP.sv and RP.sv.sound and SOUNDS and SOUNDS.POSITIVE_CLICK then PlaySound(SOUNDS.POSITIVE_CLICK) end
	if RP.UI and RP.UI.OnStaged then RP.UI.OnStaged(Q.current, #Q.chunks, automatic) end
	refresh()
	return true
end

-- chunks: the parts (already tagged if the player turned the tag on). startAt: the part to begin with (default 1).
function Q.Start(chunks, channel, target, startAt)
	if Q.active then return nil, L("Q_ACTIVE") end
	if type(chunks) ~= "table" or #chunks == 0 then return nil, L("Q_EMPTY") end
	local ok, err = Chat.Validate(channel, target)
	if not ok then return nil, err end
	invalidate()
	serial = serial + 1
	Q.postId = tostring(GetTimeStamp()) .. ":" .. tostring(serial)
	confirmed, confirmedCount = {}, 0
	Q.chunks = {}
	for index, text in ipairs(chunks) do Q.chunks[index] = text end
	Q.current = math.max(1, math.min(startAt or 1, #Q.chunks))
	Q.firstIndex = Q.current -- parts before this one were sent in an earlier run (Continue after a reload)
	Q.channel, Q.target = channel, (channel == CHAT_CHANNEL_WHISPER) and target or nil
	Q.active, Q.paused, Q.pending = true, false, nil
	trace("BATCH_START", "parts=" .. #Q.chunks .. " startAt=" .. Q.current)
	return Q.Stage(false)
end

function Q.Resume()
	if not Q.active then return nil, L("Q_NOT_ACTIVE") end
	if Q.pending then return nil, L("Q_UNCONFIRMED") end
	invalidate()
	Q.paused = false
	return Q.Stage(false)
end

-- Manual step: +1 skips ahead, -1 goes back. Skipped parts are NOT recorded as sent.
function Q.Move(delta)
	if not Q.active then return nil, L("Q_NOT_ACTIVE") end
	local index = Q.current + delta
	if index < 1 then return nil, L("Q_FIRST_PART") end
	retire(Q.pending)
	Q.pending = nil
	invalidate()
	if index > #Q.chunks then
		Q.active, Q.paused = false, false
		Q.reason = L("Q_FINISHED_MANUALLY")
		Chat.ClearOwnership()
		refresh()
		return true
	end
	Q.current, Q.paused = index, false
	return Q.Stage(false)
end

-- A submit that is not tied to a staged part (typed by hand, or while paused): remember it so a later echo cannot be mistaken for ours.
function Q.ObserveUnassociated(text, channel, target)
	if text == "" or text:match("^%s*/") then return end
	local key = fingerprint(text, channel, target)
	retire({ key = key })
	if Q.pending and (Q.pending.key == key or Q.manualOnly) then
		Q.pending.ambiguous = true
		Q.Pause(L("Q_AMBIGUOUS"))
	end
end

-- Called only inside a submission that began as a hardware (key/mouse) action while a part was staged; text is what was REALLY submitted.
function Q.ObserveSubmission(text, channel, target)
	if not Q.active or Q.paused or not Q.staged or Q.pending then Q.ObserveUnassociated(text, channel, target); return end
	if not Chat.SameDestination(channel, target, Q.channel, Q.target) then
		Q.ObserveUnassociated(text, channel, target)
		Q.Pause(L("Q_CHANNEL_CHANGED"))
		return
	end
	if text == "" or text:match("^%s*/") then Q.Pause(L("Q_UNSAFE")); return end
	local attempt = { text = text, channel = channel, target = target, index = Q.current, postId = Q.postId, key = fingerprint(text, channel, target) }
	Q.staged, Q.pending = nil, attempt
	Q.reason = L("Q_WAITING_ECHO")
	trace("SUBMISSION_CAPTURED", "part=" .. attempt.index)
	if retired[attempt.key] or Q.manualOnly then attempt.ambiguous = true; Q.Pause(L("Q_AMBIGUOUS")) end
	refresh()
	-- no echo after 10 seconds: pause and keep waiting; never retry (the line may still arrive)
	zo_callLater(function()
		if Q.active and Q.pending == attempt then
			trace("ECHO_TIMEOUT")
			Q.Pause(L("Q_ECHO_TIMEOUT"))
		end
	end, 10000)
end

-- Every chat line the game shows comes here first. Returns the part's metadata when this line is the confirmed echo of our pending part.
function Q.OnMessage(channel, fromName, text, isCustomerService, fromDisplayName)
	local attempt = Q.pending
	if not Q.active or not attempt or attempt.ambiguous or isCustomerService then return end
	if text ~= attempt.text then return end
	if not Chat.MatchesEcho(attempt, channel, fromName, fromDisplayName) then return end
	trace("ECHO_CONFIRMED", "part=" .. attempt.index)
	local meta = { postId = attempt.postId, chunkIndex = attempt.index, chunkCount = #Q.chunks, target = attempt.target }
	retire(attempt)
	if not confirmed[attempt.index] then confirmed[attempt.index] = true; confirmedCount = confirmedCount + 1 end
	Q.pending = nil
	invalidate()
	Q.current = attempt.index + 1
	-- remember how far the post got, for "Continue" after a reload
	local p = RP.sv and RP.sv.progress
	if p then p.confirmed = math.max(p.confirmed or 0, attempt.index) end
	if Q.current > #Q.chunks then
		Q.current, Q.active, Q.paused = #Q.chunks, false, false
		-- every part of THIS run was seen being sent (a continued post only counts the parts from where it resumed)
		local all = (confirmedCount == #Q.chunks - (Q.firstIndex or 1) + 1)
		Q.reason = all and L("NOTICE_DONE", #Q.chunks) or L("NOTICE_DONE_PARTIAL")
		Chat.ClearOwnership()
		if RP.sv then RP.sv.progress = nil end
		if RP.UI and RP.UI.OnQueueCompleted then RP.UI.OnQueueCompleted(Q.postId, all) end
	elseif not Q.paused then
		Q.reason = L("Q_PREPARING_NEXT")
		local generation = Q.generation
		-- 50 ms later (the same pause the stock chat needs to settle), prepare the next part if nothing changed in between
		zo_callLater(function()
			if Q.active and not Q.paused and Q.generation == generation then Q.Stage(true) end
		end, 50)
	else
		Q.reason = L("Q_PAUSED")
	end
	refresh()
	return meta
end

-- Was this part seen being sent in the current run?
function Q.IsConfirmed(index) return confirmed[index] == true end

function Q.Info()
	local sent = 0
	for _ in pairs(confirmed) do sent = sent + 1 end
	return { active = Q.active, paused = Q.paused, current = Q.current, total = #Q.chunks, sent = sent, reason = Q.reason, channel = Q.channel, target = Q.target }
end

--===============================================================================================================
-- SESSIONS (optional local archive of chat)
--===============================================================================================================
-- ✅ P5YCH3: Optional local chat archive: up to 50 sessions of 2000 lines. Off until started, never resumes by itself, stops on a zone change.
local Sessions = {}
RP.Sessions = Sessions
local MAX_SESSIONS, MAX_MESSAGES, MAX_MESSAGE_BYTES = 50, 2000, 8192
local selectedId
local recording = false

local function trim(value)
	if type(value) ~= "string" then return "" end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local PLAYER_CHANNELS
local function playerChannels()
	if PLAYER_CHANNELS then return PLAYER_CHANNELS end
	PLAYER_CHANNELS = {}
	local names = { "CHAT_CHANNEL_SAY", "CHAT_CHANNEL_YELL", "CHAT_CHANNEL_EMOTE", "CHAT_CHANNEL_PARTY", "CHAT_CHANNEL_ZONE", "CHAT_CHANNEL_WHISPER", "CHAT_CHANNEL_WHISPER_SENT" }
	for index = 1, 5 do
		names[#names + 1] = "CHAT_CHANNEL_GUILD_" .. index
		names[#names + 1] = "CHAT_CHANNEL_OFFICER_" .. index
	end
	for index = 1, 7 do names[#names + 1] = "CHAT_CHANNEL_ZONE_LANGUAGE_" .. index end
	for _, name in ipairs(names) do
		local value = _G[name]
		if type(value) == "number" then PLAYER_CHANNELS[value] = true end
	end
	return PLAYER_CHANNELS
end

local function isLocal(fromName, displayName)
	local account = normal(GetDisplayName())
	local eventAccount = normal(displayName)
	if eventAccount ~= "" then return account ~= "" and eventAccount == account end
	local name = normal(fromName)
	if name == "" then return false end
	return (account ~= "" and name == account) or name == normal(GetUnitName("player"))
end

-- A saved person matches a line when "@account" equals the display name, or a character name equals the sender's name.
local function matches(person, fromName, displayName)
	local wanted = normal(person)
	if wanted == "" then return false end
	if wanted:sub(1, 1) == "@" then return wanted == normal(displayName) or wanted == normal(fromName) end
	return wanted == normal(fromName)
end

function Sessions.List() return RP.sv and RP.sv.sessions or {} end
function Sessions.Get(id)
	for _, session in ipairs(Sessions.List()) do if session.id == id then return session end end
end
function Sessions.Current() return Sessions.Get(selectedId) end

function Sessions.Create(name)
	if #Sessions.List() >= MAX_SESSIONS then return nil, L("SESSION_LIMIT") end
	name = trim(name)
	if name == "" then return nil, L("LIB_NEED_NAME") end
	local session = { id = RP.sv.nextSessionId, name = name, createdAt = GetTimeStamp(), participants = {}, addonOnly = false, messages = {}, dropped = 0 }
	RP.sv.nextSessionId = RP.sv.nextSessionId + 1
	RP.sv.sessions[#RP.sv.sessions + 1] = session
	return session
end

function Sessions.Select(id)
	recording = false -- switching session always stops recording
	local session = Sessions.Get(id)
	if not session then return nil, L("NO_SESSION") end
	selectedId = id
	return session
end

function Sessions.Delete(id)
	for index, session in ipairs(Sessions.List()) do
		if session.id == id then
			table.remove(RP.sv.sessions, index)
			recording = false
			if selectedId == id then selectedId = nil end
			return true
		end
	end
	return nil, L("NO_SESSION")
end

function Sessions.SetParticipants(text)
	local session = Sessions.Current()
	if not session then return nil, L("NO_SESSION") end
	local people = {}
	for chunk in tostring(text or ""):gmatch("[^,\r\n]+") do
		local name = trim(chunk)
		if name ~= "" then people[#people + 1] = name end
	end
	session.participants = people
	return people
end

function Sessions.SetAddonOnly(enabled)
	local session = Sessions.Current()
	if not session then return nil, L("NO_SESSION") end
	session.addonOnly = enabled == true
	return true
end

function Sessions.SetRecording(enabled)
	recording = false
	if not enabled then return true end
	if not Sessions.Current() then return nil, L("NO_SESSION") end
	recording = true
	return true
end
function Sessions.IsRecording() return recording end

-- Store one chat line if recording and it qualifies: a player channel, not customer service, from us or a saved person.
function Sessions.Capture(channel, fromName, text, isCustomerService, fromDisplayName, meta)
	local session = Sessions.Current()
	if not recording or not session or isCustomerService then return nil end
	if type(text) ~= "string" or #text > MAX_MESSAGE_BYTES then return nil end
	if not playerChannels()[channel] then return nil end
	local whisperSent = channel == CHAT_CHANNEL_WHISPER_SENT
	local whisper = channel == CHAT_CHANNEL_WHISPER
	local outgoing = whisperSent or (not whisper and isLocal(fromName, fromDisplayName))
	if not outgoing then
		local included
		for _, person in ipairs(session.participants) do
			if matches(person, fromName, fromDisplayName) then included = true; break end
		end
		if not included then return nil end
	end
	local clean, tagged = Splitter.StripTag(text)
	if session.addonOnly == true and not tagged then return nil end
	local target
	if whisper or whisperSent then
		target = trim(fromDisplayName)
		if target == "" then target = trim(fromName) end
		if target == "" then target = nil end
	end
	local sender, display = fromName, fromDisplayName
	if whisperSent then
		-- the SENT whisper's name fields are the recipient; the sender is us
		sender, display = GetUnitName("player"), GetDisplayName()
	end
	local record = { text = clean, addonMarked = tagged, sender = type(sender) == "string" and sender or "", displayName = type(display) == "string" and display or "",
		channel = channel, timestamp = GetTimeStamp(), outgoing = outgoing, target = target }
	if outgoing and type(meta) == "table" and type(meta.chunkIndex) == "number" then
		record.postId, record.chunkIndex, record.chunkCount = meta.postId, meta.chunkIndex, meta.chunkCount
	end
	while #session.messages >= MAX_MESSAGES do
		table.remove(session.messages, 1)
		session.dropped = session.dropped + 1
	end
	session.messages[#session.messages + 1] = record
	return record
end

--===============================================================================================================
-- COMMANDS
--===============================================================================================================
-- The self-test uses only the splitter (no chat or UI calls).
function RP.SelfTest()
	local cases = { { "Short post.", 1 }, { string.rep("x", 40), 1 }, { string.rep("x", 41), 2 }, { string.rep("word ", 100) }, { "First paragraph.\n\n" .. string.rep("Next paragraph. ", 10) } }
	for _, case in ipairs(cases) do
		local parts, info = Splitter.Split(case[1], { maxChars = 40, prefix = "+ ", suffix = " +" })
		if not parts then RP.Notify(L("TEST_FAILED", tostring(info))); d("[TOM-RP] " .. L("TEST_FAILED", tostring(info))); return end
		if case[2] and #parts ~= case[2] then d("[TOM-RP] " .. L("TEST_FAILED", "part count")); return end
		for _, part in ipairs(parts) do
			if Splitter.Length(part) > 40 then d("[TOM-RP] " .. L("TEST_FAILED", "part too long")); return end
		end
	end
	d("[TOM-RP] " .. L("TEST_PASSED"))
end

local function runQueueCommand(name)
	local actions = { pause = function() return Q.Pause(L("Q_PAUSED")) end, resume = Q.Resume, next = function() return Q.Move(1) end, previous = function() return Q.Move(-1) end, cancel = Q.Cancel }
	local action = actions[name]
	if not action then return false end
	local ok, err = action()
	if not ok and err then RP.Notify(err) end
	return true
end

function RP.SlashCommand(argument)
	if not RP.ready then d("[TOM-RP] " .. L("NOT_READY")); return end
	local command = (argument or ""):lower():match("^%s*(.-)%s*$")
	if command == "" then RP.UI.Toggle()
	elseif command == "test" then RP.SelfTest()
	elseif command == "debug" then
		RP.sv.debug = not RP.sv.debug
		d("[TOM-RP] " .. L(RP.sv.debug and "DEBUG_ON" or "DEBUG_OFF"))
	elseif not runQueueCommand(command) then d("[TOM-RP] " .. L("HELP_COMMANDS")) end
end

--===============================================================================================================
-- STARTUP
--===============================================================================================================
local function onAddOnLoaded(_, addOnName)
	-- TOM's manifest name is "tom"; this runs once when TOM itself has loaded.
	if addOnName ~= "tom" then return end
	EVENT_MANAGER:UnregisterForEvent(RP.name, EVENT_ADD_ON_LOADED)
	RP.sv = ZO_SavedVars:NewAccountWide("tomrpvars", 1, nil, RP.defaults)
	-- key-binding names (the bindings themselves are in bindings.xml)
	ZO_CreateStringId("SI_BINDING_NAME_TOM_ROLEPLAY", L("KEY_TOGGLE"))
	ZO_CreateStringId("SI_BINDING_NAME_TOM_ROLEPLAY_NEXT", L("KEY_NEXT"))
	SLASH_COMMANDS["/tomrp"] = RP.SlashCommand
	EVENT_MANAGER:RegisterForEvent(RP.name, EVENT_PLAYER_ACTIVATED, RP.OnPlayerActivated)
end

function RP.OnPlayerActivated()
	if RP.ready then return end
	EVENT_MANAGER:UnregisterForEvent(RP.name, EVENT_PLAYER_ACTIVATED)
	Chat.Init()
	-- /rp is a short alias; it is only claimed when no other addon already owns it
	if SLASH_COMMANDS["/rp"] == nil then SLASH_COMMANDS["/rp"] = RP.SlashCommand end
	RP.ready = true
	if RP.UI and RP.UI.Init then RP.UI.Init() end
	-- ✅ P5YCH3: Own event name, so TOM's chat handler (registered as "tom") is not replaced.
	EVENT_MANAGER:RegisterForEvent(RP.name, EVENT_CHAT_MESSAGE_CHANNEL, function(_, channel, fromName, text, isCustomerService, fromDisplayName)
		local meta = Q.OnMessage(channel, fromName, text, isCustomerService, fromDisplayName)
		if Sessions.Capture(channel, fromName, text, isCustomerService, fromDisplayName, meta) and RP.UI and RP.UI.RefreshSessions then RP.UI.RefreshSessions() end
	end)
	EVENT_MANAGER:RegisterForEvent(RP.name, EVENT_PLAYER_DEACTIVATED, function()
		if Q.active then Q.Pause(L("Q_DEACTIVATED")) end
		Sessions.SetRecording(false)
		refresh()
	end)
end

EVENT_MANAGER:RegisterForEvent(RP.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)

-- ✅ P5YCH3: Key binding entry point.
function tomUI.roleplayHotkey()
	-- one key: open the panel when nothing is running, otherwise resume/prepare the current part
	if not RP.ready then return end
	if Q.active then
		local ok, err = Q.Resume()
		if not ok and err then RP.Notify(err) end
	else
		RP.UI.Toggle()
	end
end

return RP
