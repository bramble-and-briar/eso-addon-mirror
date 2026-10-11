-- RELEASE NOTES: edit this file to change what the "What's New?" pop-up and the settings menu show.
--
-- The pop-up appears once, in the middle of the screen, the first time a player logs in after updating to a
-- version listed here. A version that isn't listed gets no pop-up, which suits small fixes.
--
-- To add a release:
--   1. Copy the block between the two "----" lines below and paste it at the top of the list (newest first).
--   2. Change the version so it matches ## Version in CanCraftMasterWrit.addon exactly (for example "1.0").
--   3. Write one short line per highlight, inside quotes, each followed by a comma.
-- Keep it to about five highlights: the pop-up is only on screen for a few seconds.
--
-- Never type a double quote inside a highlight (use an apostrophe instead), and keep the comma after each one. After
-- editing, run the tests (luajit tests/run.lua, or ask the local agent): they name the line if a quote or comma is
-- wrong. A broken file hides the pop-up and the Release Notes section without any other warning.

CanCraftMasterWrit.releaseNotes = {
    ----
    {
        version = "1.0",
        highlights = {
            "ENCHANTING AND ALCHEMY - Now checked, along with every other crafting writ and holiday writs.",
            "MATERIALS COUNT - Craftable only when you have enough of everything; anything missing is listed.",
            "A BRAND-NEW TOOLTIP - Redesigned, with every skill and requirement on its own line.",
            "MAKE IT YOURS - Choose what your writs show, or send feedback, in the new settings menu.",
            "ANY LANGUAGE, ANY UPDATE - Reads writs in every language; new sets and motifs just work.",
        },
    },
    ----
}
