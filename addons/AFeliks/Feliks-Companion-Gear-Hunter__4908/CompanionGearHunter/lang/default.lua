-- Default (English) strings. Loaded for every client; a language file next to
-- this one (lang/de.lua, ...) is loaded after it and overrides whichever
-- strings it translates, so anything it leaves out stays English. Deliberately
-- not named en.lua: that would load this file twice on an English client.
--
-- To translate: copy the loop at the bottom into lang/<code>.lua, with a table
-- of just the strings you are translating, and call SafeAddString instead:
--
--     local strings = { COMPANIONGEARHUNTER_ANY = "Beliebig", ... }
--     for stringId, stringValue in pairs(strings) do
--         SafeAddString(_G[stringId], stringValue, 1)
--     end
--
-- <<1>>, <<2>> are filled in at runtime (zo_strformat); keep them, and move them
-- where the sentence needs them. Names the game already translates (slot names,
-- armor weights, weapon types, traits, qualities) are not here: they come
-- from the game's own strings.

local strings = {
    -- Keybind name (the game requires this exact SI_BINDING_NAME_ id)
    SI_BINDING_NAME_COMPANIONGEARHUNTER_TOGGLE = "Toggle Feliks' Companion Gear Hunter",

    -- Weapon types the game has no separate name for
    COMPANIONGEARHUNTER_WEAPON_TWO_HANDED_AXE = "Two-Handed Axe",
    COMPANIONGEARHUNTER_WEAPON_TWO_HANDED_HAMMER = "Two-Handed Hammer",
    COMPANIONGEARHUNTER_WEAPON_TWO_HANDED_SWORD = "Two-Handed Sword",

    -- Window
    COMPANIONGEARHUNTER_ANY = "Any",
    COMPANIONGEARHUNTER_COLUMN_SLOT = "Slot",
    COMPANIONGEARHUNTER_COLUMN_TYPE = "Type",
    COMPANIONGEARHUNTER_COLUMN_TRAIT = "Trait",
    COMPANIONGEARHUNTER_COLUMN_QUALITY = "Quality",
    COMPANIONGEARHUNTER_COLUMN_FIND = "Find",
    COMPANIONGEARHUNTER_COLUMN_QUALITY_FLOOR = "Quality Floor",
    COMPANIONGEARHUNTER_QUALITY_FLOOR_TIP = "Matches the selected quality or better - e.g. \"Superior\" also matches Epic and Legendary drops.",
    COMPANIONGEARHUNTER_ALL_SLOTS = "All slots",
    COMPANIONGEARHUNTER_ALL_SLOTS_TIP = "Set a value on every slot of this companion at once. Type only affects armor; picking Any resets that column. Off-Hand is skipped while it is greyed out (no one-handed Main Hand).",
    COMPANIONGEARHUNTER_CLEAR = "Clear",
    COMPANIONGEARHUNTER_CLEAR_TIP = "Clear every slot for this companion.",
    COMPANIONGEARHUNTER_OFF_HAND_CLOSED_TIP = "Needs a one-handed Main Hand. Equip one, or pick a one-handed weapon type on the Main Hand row.",
    COMPANIONGEARHUNTER_FOOTER = "Feliks' Companion Gear Hunter - Version: <<1>>",

    -- Clear dialog
    COMPANIONGEARHUNTER_CLEAR_DIALOG_TITLE = "Clear Gear Page",
    COMPANIONGEARHUNTER_CLEAR_DIALOG_TEXT = "Clear all wanted gear for <<1>>?",

    -- Item tooltip lines
    COMPANIONGEARHUNTER_TOOLTIP_WANTED = "Wanted for <<1>>",
    COMPANIONGEARHUNTER_TOOLTIP_UPGRADE = "Upgrade for <<1>>",

    -- Chat warning when another addon takes over the chat command
    COMPANIONGEARHUNTER_COMMAND_HIJACKED = "|cFF0000!!!! WARNING !!!!|r Feliks' Companion Gear Hunter: <<1>> has been taken over by <<2>> and won't open this window anymore. Check Settings > Add-Ons > Feliks' Companion Gear Hunter to pick a different command.",
    COMPANIONGEARHUNTER_ANOTHER_ADDON = "another addon",

    -- Settings panel
    COMPANIONGEARHUNTER_SETTINGS_GENERAL = "General",
    COMPANIONGEARHUNTER_SETTINGS_TAG_CHAT = "Tag Gear in Chat",
    COMPANIONGEARHUNTER_SETTINGS_TAG_CHAT_TIP = "When checked, companion gear item links in chat (any channel, including your own messages) get a companion icon in front of them, in the wanted or upgrade color below. Hover the link for details. Edits the line in place - no extra chat lines.",
    COMPANIONGEARHUNTER_SETTINGS_COMMAND = "Chat Command",
    COMPANIONGEARHUNTER_SETTINGS_COMMAND_TIP = "The chat command that toggles the window, typed without the slash. Takes effect immediately, no reload needed.",
    COMPANIONGEARHUNTER_SETTINGS_COMMAND_REQUIRED = "A chat command is required.",
    COMPANIONGEARHUNTER_SETTINGS_COMMAND_TAKEN = "<<1>> is already used by another command - pick something else.",
    COMPANIONGEARHUNTER_SETTINGS_COMMAND_NOT_REGISTERED = "The chat command isn't registered, so it can't be changed right now.",
    COMPANIONGEARHUNTER_SETTINGS_PREFIX = "Tooltip Prefix",
    COMPANIONGEARHUNTER_SETTINGS_PREFIX_TIP = "Text shown at the start of the lines this addon adds to item tooltips. Leave it empty for no prefix.",
    COMPANIONGEARHUNTER_SETTINGS_UPGRADES_HEADER = "Gear Quality Upgrades",
    COMPANIONGEARHUNTER_SETTINGS_UPGRADES = "Find Gear Quality Upgrades",
    COMPANIONGEARHUNTER_SETTINGS_UPGRADES_TIP = "When checked, browsing a companion item that's a higher quality than what a companion currently has equipped in a slot you aren't actively hunting for (\"Find\" unchecked) marks that item and adds a note to its tooltip. Weight/type and trait must match what's equipped - only the quality is an upgrade. When unchecked, no companion gets upgrade suggestions, whatever is set below.",
    COMPANIONGEARHUNTER_SETTINGS_UPGRADES_DESC = "Upgrade suggestions are only shown for the companions checked below. Items matching your wishlist are not affected.",
    COMPANIONGEARHUNTER_SETTINGS_UPGRADES_COMPANION_TIP = "Suggest quality upgrades for <<1>>.",
    COMPANIONGEARHUNTER_SETTINGS_COLORS_HEADER = "Colors",
    COMPANIONGEARHUNTER_SETTINGS_COLORS_DESC = "The color of the icons shown on items in your bags, banks, guild stores, trades and mail, in chat, and next to companions in the window. Dark colors are not suggested.",
    COMPANIONGEARHUNTER_SETTINGS_COLOR_WANTED = "Wanted Color",
    COMPANIONGEARHUNTER_SETTINGS_COLOR_WANTED_TIP = "Items matching something on your wishlist.",
    COMPANIONGEARHUNTER_SETTINGS_COLOR_UPGRADE = "Upgrade Color",
    COMPANIONGEARHUNTER_SETTINGS_COLOR_UPGRADE_TIP = "Items that are a quality upgrade over what a companion has equipped.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(_G[stringId], 1)
end
