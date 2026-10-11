-- English strings. Every piece of on-screen text the addon writes itself lives here, except the release notes and
-- the supporters list, which the author edits in ReleaseNotes.lua and Support.lua.
-- Text the game already provides (item, style, trait, set and skill names) comes from the game API instead,
-- so it is shown in the player's language automatically.
-- To translate, copy this file to lang/<language>.lua, replace ZO_CreateStringId with SafeAddString(id, text, 1)
-- and add the file to the manifest after this one.
-- Lines are written as a label and a value, shown "Label: value" with the value in white. Labels use title case.

local strings = {
    -- Overall status, shown at the right of the tooltip's top row, as text only. The tooltip draws it in capitals.
    SI_CCMW_STATUS_CRAFTABLE = "Craftable",
    SI_CCMW_STATUS_NOT_CRAFTABLE = "Uncraftable",
    SI_CCMW_STATUS_UNKNOWN = "Status Unknown",

    -- How a label and its value are joined, and how counts are written (have/need).
    SI_CCMW_LABEL_VALUE = "<<1>>: <<2>>",
    SI_CCMW_LABEL_VALUE_NEW_LINE = "<<1>>:\n<<2>>", -- For long values, such as a motif's full name.
    SI_CCMW_COUNT = "<<1>>/<<2>>",

    -- Smithing (blacksmithing, clothing, woodworking, jewelry).
    SI_CCMW_MOTIF_KNOWN = "Motif Page Known",
    SI_CCMW_MOTIF_MISSING = "Motif Page Missing",
    SI_CCMW_MOTIF_NO_DATA = "Motif Knowledge Not Loaded Yet",
    SI_CCMW_MOTIF_UNKNOWN_STYLE = "Style Not Recognized",
    SI_CCMW_TRAIT_KNOWN = "Trait Researched",
    SI_CCMW_TRAIT_MISSING = "Trait Not Researched",
    SI_CCMW_SET_TRAITS = "Set Traits Known",
    SI_CCMW_SET_UNKNOWN = "Set Not Recognized",
    SI_CCMW_ITEM_UNKNOWN = "Item Type Not Recognized",

    -- Enchanting and alchemy.
    SI_CCMW_RUNES = "Runes",
    SI_CCMW_GLYPH_UNKNOWN = "Glyph Not Recognized",
    SI_CCMW_ASPECT_IMPROVEMENT = "Aspect Improvement",
    SI_CCMW_REAGENTS = "Reagents",
    SI_CCMW_REAGENTS_NONE = "No Reagent Combination Found",
    SI_CCMW_THIRD_SLOT = "Third Reagent Slot",

    -- Provisioning.
    SI_CCMW_RECIPE_KNOWN = "Recipe Known",
    SI_CCMW_RECIPE_MISSING = "Recipe Not Known",
    SI_CCMW_RECIPE_NOT_FOUND = "Recipe Not Found",
    SI_CCMW_RECIPE_QUALITY = "Recipe Quality",

    -- Shared by every craft.
    SI_CCMW_SKILLS_OK = "Skills Learned",
    SI_CCMW_SKILLS_MISSING = "Skills Missing",
    SI_CCMW_SKILLS_UNKNOWN = "Skill Ranks Unknown",
    SI_CCMW_NOT_UNLOCKED = "Not Unlocked",
    SI_CCMW_MATERIALS_OK = "Materials in Stock",
    SI_CCMW_MATERIALS_MISSING = "Materials Missing",
    SI_CCMW_MATERIAL_AMOUNT_UNKNOWN = "Amount Needed Unknown",
    SI_CCMW_STYLE_OR_MIMIC = "<<1>> or <<2>>",
    SI_CCMW_UNSUPPORTED = "This Writ Type Is Not Supported Yet",
    SI_CCMW_ERROR = "Could Not Check This Writ",

    -- Chat.
    SI_CCMW_LOADED = "<<1>> v<<2>> Loaded!",
    SI_CCMW_COMMAND_HELP = "/ccmw debug - Turn debug messages on or off\n/ccmw scan - Check every master writ in your bags\n/ccmw link <item link> - Check one writ\n/ccmw new - Show what's new\n/ru - Reload the UI",
    SI_CCMW_COMMAND_DEBUG = "Debug Messages: <<1>>",
    SI_CCMW_COMMAND_SCAN_NONE = "No master writs in your bags.",
    SI_CCMW_COMMAND_ON = "On",
    SI_CCMW_COMMAND_OFF = "Off",

    -- The What's New pop-up and the QR code box in the settings.
    SI_CCMW_POPUP_TITLE = "Can Craft Master Writ",
    SI_CCMW_POPUP_VERSION = "Version <<1>>",
    SI_CCMW_POPUP_WHATS_NEW = "What's New?",
    SI_CCMW_POPUP_SUPPORT_TITLE = "Support Can Craft Master Writ",
    SI_CCMW_POPUP_SUPPORT_SCAN = "Scan With Your Phone to Donate",
    SI_CCMW_POPUP_FEEDBACK_TITLE = "Report a Bug or Ask a Question",
    SI_CCMW_POPUP_FEEDBACK_SCAN = "Scan With Your Phone to Open the Form",
    SI_CCMW_THANK_YOU = "Thank you for your support!",
    SI_CCMW_GAMERTAG = "GT: <<1>>", -- One supporter in the settings menu.

    -- Settings menu.
    SI_CCMW_MENU_NAME = "Can Craft Master Writ",
    SI_CCMW_MENU_SUPPORT = "Supporters",
    SI_CCMW_MENU_DONATE_TOOLTIP = "If you'd like to support my work, any bit is very much appreciated. Donors get their names permanently added to the list :)",
    SI_CCMW_MENU_DONATE_NOT_SET = "Donation link coming soon.",
    SI_CCMW_MENU_SUPPORTERS_NONE = "Be the first!",
    SI_CCMW_MENU_FILTERS = "Requirement Filters",
    -- Each filter's description depends on whether it is on or off.
    SI_CCMW_MENU_MATERIALS = "Materials",
    SI_CCMW_MENU_MATERIALS_ON = "On: Checks that you have the materials. If any are missing, the writ is Uncraftable.",
    SI_CCMW_MENU_MATERIALS_OFF = "Off: Materials are not checked or shown, so missing materials never make the writ Uncraftable.",
    SI_CCMW_MENU_SET_TRAITS = "Set Traits Known",
    SI_CCMW_MENU_SET_TRAITS_ON = "On: Checks that you have researched enough traits for the item to craft its set. If not, the writ is Uncraftable.",
    SI_CCMW_MENU_SET_TRAITS_OFF = "Off: The traits needed for the set are not checked or shown, so they never make the writ Uncraftable.",
    SI_CCMW_MENU_TRAIT_RESEARCH = "Trait Research",
    SI_CCMW_MENU_TRAIT_RESEARCH_ON = "On: Checks that you have researched the writ's trait. If not, the writ is Uncraftable.",
    SI_CCMW_MENU_TRAIT_RESEARCH_OFF = "Off: The writ's trait is not checked or shown, so an unresearched trait never makes the writ Uncraftable.",
    SI_CCMW_MENU_SHOW_MISSING = "Display Missing Items",
    SI_CCMW_MENU_SHOW_MISSING_ON = "On: Shows the requirements you don't meet yet, and what is missing.",
    SI_CCMW_MENU_SHOW_MISSING_OFF = "Off: Hides the requirements you don't meet yet. They still decide whether the writ is Craftable.",
    SI_CCMW_MENU_SHOW_KNOWN = "Display Known Items",
    SI_CCMW_MENU_SHOW_KNOWN_ON = "On: Shows the requirements you already meet, and the runes or reagents to use.",
    SI_CCMW_MENU_SHOW_KNOWN_OFF = "Off: Hides the requirements you already meet, and the runes or reagents to use. They still decide whether the writ is Craftable.",
    SI_CCMW_MENU_RELEASE_NOTES = "Release Notes",
    SI_CCMW_MENU_RELEASE_NOTES_TOOLTIP = "Select to view the latest changes.",
    SI_CCMW_MENU_FEEDBACK = "Feedback",
    SI_CCMW_MENU_FEEDBACK_TOOLTIP = "Select to report a bug or ask a question.",
}

for stringId, text in pairs(strings) do
    ZO_CreateStringId(stringId, text)
end
