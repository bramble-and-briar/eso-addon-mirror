-- Default (English) strings. Loaded for every client; a language file next to
-- this one (lang/de.lua, ...) is loaded after it and overrides whichever
-- strings it translates, so anything it leaves out stays English. Deliberately
-- not named en.lua: that would load this file twice on an English client.
--
-- To translate: copy the loop at the bottom into lang/<code>.lua, with a table
-- of just the strings you are translating, and call SafeAddString instead:
--
--     local strings = { COMPANIONROSTER_COLUMN_LEVEL = "Stufe", ... }
--     for stringId, stringValue in pairs(strings) do
--         SafeAddString(_G[stringId], stringValue, 1)
--     end
--
-- <<1>>, <<2>> are filled in at runtime (zo_strformat); keep them, and move them
-- where the sentence needs them. Names the game already translates (role names,
-- skill types, companion names, skill line names) are not here: they come from
-- the game's own strings. The addon's title and the rapport tip descriptions
-- (hand-transcribed from the UESP wiki) are deliberately left in English.

local strings = {
    -- Keybind name (the game requires this exact SI_BINDING_NAME_ id)
    SI_BINDING_NAME_COMPANIONROSTER_TOGGLE = "Toggle Feliks' Companion Roster",

    -- Roster window
    COMPANIONROSTER_COLUMN_COMPANION = "Companion",
    COMPANIONROSTER_COLUMN_LEVEL = "Level",
    COMPANIONROSTER_COLUMN_RAPPORT = "Rapport",
    COMPANIONROSTER_LEVEL_CELL = "Lv.<<1>>",
    COMPANIONROSTER_LEVEL_UNKNOWN = "Lv.?",
    COMPANIONROSTER_STATUS_NOT_OWNED = "Not Owned",
    COMPANIONROSTER_STATUS_QUEST_NOT_DONE = "Quest Not Done",
    COMPANIONROSTER_STATUS_NO_INFO = "No Info",
    COMPANIONROSTER_FOOTER = "<<1>> - Version: <<2>>",

    -- Roster window tooltips
    COMPANIONROSTER_TIP_NOT_OWNED = "You don't own this companion yet.",
    COMPANIONROSTER_TIP_QUEST_NOT_DONE = "You haven't completed this companion's recruitment quest on this character yet.",
    COMPANIONROSTER_TIP_NO_RAPPORT_DATA = "Rapport data will be recorded when this companion is summoned.",
    COMPANIONROSTER_TIP_CLICK_RAPPORT = "Click for rapport tips",
    COMPANIONROSTER_TIP_UNLOCKED = "- Unlocked",
    COMPANIONROSTER_TIP_CLICK_SUMMON = "Click to summon",
    COMPANIONROSTER_TIP_NO_SKILL_DATA = "Skill data will be recorded when this companion is summoned.",
    COMPANIONROSTER_TIP_NO_GUILD_DATA = "No Guild skill line data recorded yet for this companion.",
    COMPANIONROSTER_TIP_ROLE_HINT = "Right-click to tag this companion's role.",

    -- Level tooltip
    COMPANIONROSTER_LEVEL_TIP_LABEL = "<<1>>:",
    COMPANIONROSTER_LEVEL_TIP_UNTRAINED = "Untrained",
    COMPANIONROSTER_LEVEL_TIP_ALL_MAXED = "all maxed (<<1>>)",

    -- Skill ranks
    COMPANIONROSTER_MAXED = "(Maxed)",
    COMPANIONROSTER_GUILD_RANK = "<<1>> Rank <<2>>",
    COMPANIONROSTER_NAME_VALUE = "<<1>>: <<2>>",

    -- Roles
    COMPANIONROSTER_ROLE_PAIR = "<<1>> + <<2>>",
    COMPANIONROSTER_ROLE_NONE = "None",
    COMPANIONROSTER_ROLE_CLEAR = "Clear Role",

    -- Results popup (chat command search and companion lookup)
    COMPANIONROSTER_RESULTS_SEARCH_TITLE = "Rapport tips: <<1>>",
    COMPANIONROSTER_RESULTS_COMPANION_TITLE = "<<1>> Rapport",
    COMPANIONROSTER_RESULTS_LIKES = "Likes",
    COMPANIONROSTER_RESULTS_DISLIKES = "Dislikes",
    COMPANIONROSTER_RESULTS_NONE = "(none)",
    COMPANIONROSTER_TIP_LINE = "<<1>>: <<2>> (<<3>>)",
    COMPANIONROSTER_SEARCH_DETAIL = "<<1>> - <<2>> (<<3>>)",

    -- Chat messages (each is printed after the addon's name)
    COMPANIONROSTER_SAY_AMBIGUOUS = "\"<<1>>\" matches more than one companion: <<2>>",
    COMPANIONROSTER_SAY_CANT_SUMMON_YET = "<<1>> can't be summoned on this character yet.",
    COMPANIONROSTER_SAY_CANT_SUMMON_REASON = "can't summon <<1>> - <<2>>",
    COMPANIONROSTER_SAY_SWITCH_CHARACTER = "switch the dropdown to the character you're playing to summon <<1>>.",
    COMPANIONROSTER_SAY_NO_COMPANION = "no companion found matching \"<<1>>\".",
    COMPANIONROSTER_SAY_NO_TIPS = "no rapport tips found for \"<<1>>\".",
    COMPANIONROSTER_SAY_USAGE_SEARCH = "usage - <<1>> s <term>, e.g. <<1>> s Undaunted",
    COMPANIONROSTER_SAY_USAGE_COMPANION = "usage - <<1>> c <name>, e.g. <<1>> c tan",
    COMPANIONROSTER_SAY_HUD_FAILED = "the Companion Info frame could not be set up for Edit HUD (<<1>>).",
    COMPANIONROSTER_COMMAND_TAKEN_WARNING = "|cFF0000!!!! WARNING !!!!|r <<1>>: <<2>> has been taken over by <<3>> and won't open this window anymore. Check Settings > Add-Ons > <<1>> to pick a different command.",
    COMPANIONROSTER_ANOTHER_ADDON = "another addon",

    -- Companion Info frame
    COMPANIONROSTER_HUD_ELEMENT_NAME = "Companion Info",
    COMPANIONROSTER_HUD_LEVEL = "Lv:<<1>>",
    COMPANIONROSTER_HUD_RAPPORT_LEVEL = "Rap:<<1>>",

    -- Settings: General
    COMPANIONROSTER_SETTINGS_GENERAL = "General",
    COMPANIONROSTER_SETTINGS_COMMAND = "Chat Command",
    COMPANIONROSTER_SETTINGS_COMMAND_TIP = "The chat command that toggles the roster window, typed without the slash. Takes effect immediately, no reload needed.",
    COMPANIONROSTER_SETTINGS_COMMAND_REQUIRED = "A chat command is required.",
    COMPANIONROSTER_SETTINGS_COMMAND_TAKEN = "<<1>> is already used by another command - pick something else.",
    COMPANIONROSTER_SETTINGS_COMMAND_NOT_REGISTERED = "The chat command isn't registered, so it can't be changed right now.",
    COMPANIONROSTER_SETTINGS_CLOSE_COMBAT = "Close Window When Entering Combat",
    COMPANIONROSTER_SETTINGS_CLOSE_COMBAT_TIP = "Close when entering combat.",
    COMPANIONROSTER_SETTINGS_SHOW_ROLES = "Show Roles in Collections",
    COMPANIONROSTER_SETTINGS_SHOW_ROLES_TIP = "Shows each companion's Role icon on their tile in the Collections screen. Keyboard and mouse UI only.",
    COMPANIONROSTER_SETTINGS_SHOW_RAPPORT = "Show Rapport in Collections",
    COMPANIONROSTER_SETTINGS_SHOW_RAPPORT_TIP = "Shows each companion's current rapport number under their portrait in the Collections screen. Keyboard and mouse UI only.",

    -- Settings: Companion Info frame
    COMPANIONROSTER_SETTINGS_HUD_HEADER = "Companion Info Frame",
    COMPANIONROSTER_SETTINGS_HUD_DESCRIPTION = "A small always-visible line showing your active companion. Move it with Game Menu > Edit HUD.",
    COMPANIONROSTER_SETTINGS_HUD_ENABLED = "Show Companion Info Frame",
    COMPANIONROSTER_SETTINGS_HUD_ENABLED_TIP = "Turns the whole frame on or off. When off, it also disappears from Edit HUD.",
    COMPANIONROSTER_SETTINGS_HUD_BOLD = "Bold Text",
    COMPANIONROSTER_SETTINGS_HUD_BOLD_TIP = "Use the bold game font instead of the regular one.",
    COMPANIONROSTER_SETTINGS_HUD_COLOR = "Text Color",
    COMPANIONROSTER_SETTINGS_HUD_COLOR_TIP = "The color of the whole line.",
    COMPANIONROSTER_SETTINGS_HUD_PARTS = "Parts to show (the companion's name is always shown):",
    COMPANIONROSTER_SETTINGS_HUD_LEVEL = "Level",
    COMPANIONROSTER_SETTINGS_HUD_LEVEL_TIP = "For example Lv:16.",
    COMPANIONROSTER_SETTINGS_HUD_XP_RAW = "XP (current/needed)",
    COMPANIONROSTER_SETTINGS_HUD_XP_RAW_TIP = "For example (94938/116000). Hidden at max level.",
    COMPANIONROSTER_SETTINGS_HUD_XP_PERCENT = "XP Percent",
    COMPANIONROSTER_SETTINGS_HUD_XP_PERCENT_TIP = "For example 81%. Hidden at max level.",
    COMPANIONROSTER_SETTINGS_HUD_XP_GAIN = "XP Gain",
    COMPANIONROSTER_SETTINGS_HUD_XP_GAIN_TIP = "The most recent XP gain, for example [+120]. Hidden at max level.",
    COMPANIONROSTER_SETTINGS_HUD_RAPPORT_LEVEL = "Rapport Level",
    COMPANIONROSTER_SETTINGS_HUD_RAPPORT_LEVEL_TIP = "For example Rap:6.",
    COMPANIONROSTER_SETTINGS_HUD_RAPPORT_CHANGE = "Rapport Change",
    COMPANIONROSTER_SETTINGS_HUD_RAPPORT_CHANGE_TIP = "The most recent rapport gain or loss, for example [+25].",
    COMPANIONROSTER_SETTINGS_HUD_RAPPORT_NUMBER = "Rapport Number",
    COMPANIONROSTER_SETTINGS_HUD_RAPPORT_NUMBER_TIP = "Your current rapport points, for example (3247).",

    -- Settings: Colors
    COMPANIONROSTER_SETTINGS_COLORS_HEADER = "Colors",
    COMPANIONROSTER_SETTINGS_COLORS_DESCRIPTION = "The colors used for rapport and Guild ranks in the roster window, the Collections screen and the search results, and for the labels in the roster's Level tooltip.",
    COMPANIONROSTER_SETTINGS_COLOR_DONE = "Done Color",
    COMPANIONROSTER_SETTINGS_COLOR_DONE_TIP = "Maxed rapport and maxed Guild ranks.",
    COMPANIONROSTER_SETTINGS_COLOR_IN_PROGRESS = "In Progress Color",
    COMPANIONROSTER_SETTINGS_COLOR_IN_PROGRESS_TIP = "Rapport and Guild ranks that can still go up.",
    COMPANIONROSTER_SETTINGS_COLOR_LABEL = "Tooltip Label Color",
    COMPANIONROSTER_SETTINGS_COLOR_LABEL_SAMPLE = "Sample 5",
    COMPANIONROSTER_SETTINGS_COLOR_LABEL_TIP ="The labels in the Level tooltip, such as Guild: and Untrained:.",

    -- Settings: Companion Roles
    COMPANIONROSTER_SETTINGS_ROLES_HEADER = "Companion Roles",
    COMPANIONROSTER_SETTINGS_ROLES_DESCRIPTION = "Purely a label you set yourself - there's no way to detect a companion's build from their gear or slotted skills. Account-wide, same as the companion itself. Right-clicking a companion's Role icon in the roster window does the same thing.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(_G[stringId], 1)
end
