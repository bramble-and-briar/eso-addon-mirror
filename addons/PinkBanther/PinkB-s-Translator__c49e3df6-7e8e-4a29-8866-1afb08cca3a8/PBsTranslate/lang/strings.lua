local strings = {
	SI_PBSTR_ERROR_WORD_BUDGET = "User dictionary limit: 2,000 units (verbs 12, adjectives 6, others 1) / 128 KiB total, 192 bytes per key and 768 per value. No saved entries were deleted. Remove or shorten entries and try again.",
	SI_PBSTR_ONLY = "Translation only",
	SI_PBSTR_ONLY_TOOLTIP = "Replace translated message bodies while keeping the sender and channel. Untranslated messages keep their original text.",
	SI_PBSTR_HELP_ONLY = "/pbtr only on | off -- show only the translation",
	SI_PBSTR_STATUS_ONLY = "Translation only: %s",
	SI_PBSTR_REPLACE_UNAVAILABLE = "Replacement formatter unavailable; using original plus translation.",

	SI_PBSTR_COLOR = "Translation text color",
	SI_PBSTR_COLOR_TOOLTIP = "Color for the translation prefix and text. Applies to new lines. /pbtr color RRGGBB also changes it.",
	SI_PBSTR_HELP_COLOR = "/pbtr color <RRGGBB | default> -- translation text color",
	SI_PBSTR_ERROR_COLOR = "Use six hexadecimal digits, e.g. /pbtr color FFFF00, or default.",
	SI_PBSTR_REPLY_COLOR = "Translation color: #%s",
	SI_PBSTR_COLOR_SAMPLE = "翻訳の表示サンプル",

	-- ---- Chat -------------------------------------------------------------------------
	SI_PBSTR_LINE_PREFIX = "[JP]",
	SI_PBSTR_LINE_PREFIX_EN = "[EN]",

	-- ---- Settings panel ---------------------------------------------------------------
	SI_PBSTR_EXPLANATION = "Adds a Japanese line under English chat. The translation is done inside the add-on with its own dictionary -- add-ons cannot reach the internet -- so it is a rough, word-order-level rendering, not a polished translation.",

	SI_PBSTR_DIRECTION = "Translation direction",
	SI_PBSTR_DIRECTION_TOOLTIP = "English to Japanese adds a Japanese line under English chat. Japanese to English adds an English line under Japanese chat; it reads the English to Japanese dictionary backwards and is most accurate on short lines. /jp and /en work the same either way.",
	SI_PBSTR_DIRECTION_TO_JA = "English to Japanese",
	SI_PBSTR_DIRECTION_TO_EN = "Japanese to English",
	SI_PBSTR_STATUS_DIRECTION = "Direction: %s",
	SI_PBSTR_HELP_DIRECTION = "/pbtr mode en2ja | ja2en -- translation direction",
	SI_PBSTR_ERROR_DIRECTION = "use /pbtr mode en2ja (English to Japanese) or /pbtr mode ja2en (Japanese to English)",

	SI_PBSTR_ENABLED = "Translate chat",
	SI_PBSTR_ENABLED_TOOLTIP = "The master switch.",
	SI_PBSTR_OWN = "My own messages",
	SI_PBSTR_OWN_TOOLTIP = "Translate what you type, once it appears in the chat window. Only you see the translation; the message you sent is unchanged.",
	SI_PBSTR_OTHERS = "Other players' messages",
	SI_PBSTR_OTHERS_TOOLTIP = "Translate what everyone else says.",
	SI_PBSTR_ZONE = "Include zone chat",
	SI_PBSTR_ZONE_TOOLTIP = "Zone chat is most of the traffic in a busy area. Turn this off to translate only say, group, guild and whispers.",
	SI_PBSTR_KNOWN = "Known words needed",
	SI_PBSTR_KNOWN_TOOLTIP = "A line is translated only when at least this share of its words is in the dictionary. This is what keeps out other languages, names and typos. Lower it to translate more; raise it to see fewer half-translated lines.",

	SI_PBSTR_SECTION_WORDS = "Dictionary",
	SI_PBSTR_WORDS_NOTE = "%d entries are built in. Add your own below, or with the chat commands:\n/pbtr add english = 日本語\n/pbtr remove english\n/pbtr list\n/jp <text> translates a line for you alone.",

	SI_PBSTR_WORD_ENGLISH = "English",
	SI_PBSTR_WORD_ENGLISH_TOOLTIP = "The word or phrase to add, as it is written in chat. Upper and lower case are the same.",
	SI_PBSTR_WORD_JAPANESE = "Japanese",
	SI_PBSTR_WORD_JAPANESE_TOOLTIP = "Its Japanese. Type verbs and adjectives in their dictionary form (走る, 静か).",
	SI_PBSTR_WORD_POS = "Part of speech",
	SI_PBSTR_WORD_POS_TOOLTIP = "Choose a part of speech for a verb or an adjective so it is conjugated. As-is shows the Japanese exactly as typed.",
	SI_PBSTR_POS_X = "As-is (set phrase)",
	SI_PBSTR_POS_N = "Noun",
	SI_PBSTR_POS_GODAN = "Verb, godan (走る, 話す)",
	SI_PBSTR_POS_ICHIDAN = "Verb, ichidan (食べる, 見る)",
	SI_PBSTR_POS_SURU = "Verb, する (攻撃する)",
	SI_PBSTR_POS_AI = "Adjective, い (強い)",
	SI_PBSTR_POS_ADJ_NA = "Adjective, な (静か)",
	SI_PBSTR_WORD_ADD = "Add to dictionary",
	SI_PBSTR_WORD_ADD_TOOLTIP = "Adds the English and Japanese above. An existing entry for the same English is replaced. Your words win over the built-in dictionary.",
	SI_PBSTR_WORD_HINT = "Enter the English and the Japanese, then press Add to dictionary.",
	SI_PBSTR_WORD_LIST = "Your words",
	SI_PBSTR_WORD_LIST_TOOLTIP = "The words you have added. Pick one to remove it.",
	SI_PBSTR_WORD_REMOVE = "Remove selected word",
	SI_PBSTR_WORD_REMOVE_TOOLTIP = "Removes the word picked in Your words.",
	SI_PBSTR_ERROR_WORD_EMPTY = "Enter both the English and the Japanese.",
	SI_PBSTR_ERROR_WORD_CHARS = "The Japanese cannot contain / or =.",

	-- ---- Status -----------------------------------------------------------------------
	SI_PBSTR_ON = "on",
	SI_PBSTR_OFF = "off",
	SI_PBSTR_STATUS_NOT_INSTALLED = "the chat listener is NOT installed -- nothing will be translated",
	SI_PBSTR_STATUS_TARGETS = "own %s, others %s, zone %s, known words %d%%",
	SI_PBSTR_STATUS_DICTIONARY = "dictionary: %d built in, %d of your own",
	SI_PBSTR_STATUS_COUNTS = "this session: %d looked at, %d translated, %d skipped, %d errors",
	SI_PBSTR_STATUS_LAST_ERROR = "last error: %s",

	SI_PBSTR_REPLY_ADDED = "added: %s = %s",
	SI_PBSTR_REPLY_REMOVED = "removed: %s",
	SI_PBSTR_REPLY_NO_WORDS = "you have not added any words",
	SI_PBSTR_REPLY_KNOWN = "(%d of %d words known)",

	SI_PBSTR_ERROR_ADD_FORMAT = "write it as /pbtr add english = 日本語  (optionally n: v: a: adv: before the Japanese)",
	SI_PBSTR_ERROR_POS = "unknown part of speech: %s (use n, v, a, adv, pn or x)",
	SI_PBSTR_ERROR_NOT_FOUND = "not in your words: %s",
	SI_PBSTR_ERROR_ON_OR_OFF = "on or off?",
	SI_PBSTR_ERROR_PERCENT = "a number from 0 to 100",
	SI_PBSTR_ERROR_UNKNOWN = "no such command: %s",

	SI_PBSTR_HELP_TRANSLATE = "/jp <english> -- translate a line for yourself",
	SI_PBSTR_HELP_STATUS = "/pbtr -- status",
	SI_PBSTR_HELP_MASTER = "/pbtr on | off -- translate chat or not",
	SI_PBSTR_HELP_OWN = "/pbtr own on | off -- your own messages",
	SI_PBSTR_HELP_OTHERS = "/pbtr others on | off -- other players' messages",
	SI_PBSTR_HELP_ZONE = "/pbtr zone on | off -- include zone chat",
	SI_PBSTR_HELP_KNOWN = "/pbtr known <0-100> -- share of known words needed",
	SI_PBSTR_HELP_ADD = "/pbtr add english = 日本語 -- add a word or phrase",
	SI_PBSTR_HELP_REMOVE = "/pbtr remove english -- remove one you added",
	SI_PBSTR_HELP_LIST = "/pbtr list -- the words you added",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
