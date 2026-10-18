-- RELEASE NOTES: edit this file to change what the "What's New?" pop-up and the settings menu show.
--
-- The pop-up appears once, in the middle of the screen, the first time a player logs in after updating to a
-- version listed here. A version that isn't listed gets no pop-up, which suits small fixes. While the list is empty,
-- there is no pop-up and no Release Notes row in the settings menu.
--
-- To add a release:
--   1. Copy the example block below (from "{" to "},"), paste it inside the list between the two curly brackets
--      under "releaseNotes", at the top (newest first), and take the dashes off the front of each line.
--   2. Change the version so it matches ## Version in SlayansBossTimer.addon exactly (for example "1.0").
--   3. Write one short line per highlight, inside quotes, each followed by a comma.
-- Keep it to about five highlights: the pop-up is only on screen for ten seconds.
--
--     {
--         version = "1.0",
--         highlights = {
--             "Added respawn timers for world bosses.",
--             "Various UI tweaks and fixes.",
--         },
--     },
--
-- Never type a double quote inside a highlight (use an apostrophe instead), and keep the comma after each one. After
-- editing, run the tests (luajit tests/run.lua, or ask the local agent): they name the line if a quote or comma is
-- wrong. A broken file hides the pop-up and the Release Notes row without any other warning.

SlayansBossTimer.releaseNotes = {
}
