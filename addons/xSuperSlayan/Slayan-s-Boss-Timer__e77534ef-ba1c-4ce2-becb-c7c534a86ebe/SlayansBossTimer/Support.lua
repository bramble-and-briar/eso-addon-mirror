-- SUPPORT: edit this file to change the Supporters page of the settings menu, the donation QR code and the Feedback
-- QR code.
--
-- Rules, so the file keeps working:
--   * Text always goes inside double quotes, followed by a comma:  "PlayerOne",
--   * Never type a double quote inside the text itself.
--   * Lines starting with two dashes (--) are notes like this one; the game ignores them.
--   * After editing, run the tests (luajit tests/run.lua, or ask the local agent): they name the line if a quote or
--     comma is wrong. A broken file hides the QR code and the supporters list without any other warning.

SlayansBossTimer.support = {
    -- The web address the donation QR code opens when scanned with a phone.
    donationLink = "https://square.link/u/VRJwqHFW",

    -- The web address the Feedback QR code opens: the form for bug reports and questions.
    feedbackLink = "https://docs.google.com/forms/d/e/1FAIpQLSf-YqKkQZ5Y6mRg5Re34EmSlVW40H-HcMUY5dJSgJq-shkUUA/viewform",

    -- SUPPORTERS: the gamertag of every player who has donated. Each shows in the settings menu as "GT: <gamertag>".
    -- Add one line per player between the two curly brackets below, without dashes in front, like this:
    --
    --     supporters = {
    --         "PlayerOne",
    --         "PlayerTwo",
    --     },
    --
    -- While the list is empty, the menu shows "Be the first!".
    supporters = {
    },
}
