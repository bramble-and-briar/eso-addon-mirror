-- English strings. Every piece of on-screen text the add-on writes itself lives here, except the release notes and
-- the supporters list, which the author edits in ReleaseNotes.lua and Support.lua.
-- Text the game already provides (zone, boss and item names) comes from the game API instead, so it is shown in the
-- player's language automatically.
-- To translate, copy this file to lang/<language>.lua, replace ZO_CreateStringId with SafeAddString(id, text, 1)
-- and add the file to the manifest after this one.
-- Labels use title case.

local strings = {
    -- Chat.
    SI_SBT_LOADED = "<<1>> v<<2>> Loaded!",
    SI_SBT_CHAT_TIMER_STARTED = "Boss timer started: <<1>>, back in <<2>>.",
    SI_SBT_CHAT_BOSS_RESPAWNED = "Boss respawned: <<1>>.",
    SI_SBT_CHAT_TIMERS_CLEARED = "Boss timers cleared.",
    -- How long until a boss respawns, in the chat message above: minutes and seconds, so it can't be mistaken for a
    -- time of day.
    SI_SBT_DURATION_MINUTES_SECONDS = "<<1>>m <<2>>s",
    SI_SBT_DURATION_MINUTES = "<<1>>m",
    SI_SBT_DURATION_SECONDS = "<<1>>s",
    -- The short tag LibChatMessage can put before the timer's chat messages, if the player has it and chose short tags.
    SI_SBT_CHAT_TAG_SHORT = "SBT",

    -- Bosses that die together, such as a world boss with several bosses, share one timer.
    SI_SBT_BOSS_PAIR = "<<1>> and <<2>>",
    SI_SBT_BOSS_GROUP = "<<1>> and <<2>> More",

    -- The countdown and the alert in the middle of the screen.
    SI_SBT_COUNTDOWN_EXAMPLE = "Example Boss", -- Shown while placing the countdown, if no timer is running.
    SI_SBT_ALERT_RESPAWNED = "Has Respawned",

    -- The What's New pop-up, the Feedback pop-up and the QR code box in the settings.
    SI_SBT_POPUP_TITLE = "Slayan's Boss Timer",
    SI_SBT_POPUP_VERSION = "Version <<1>>",
    SI_SBT_POPUP_WHATS_NEW = "What's New?",
    SI_SBT_POPUP_SUPPORT_TITLE = "Support Slayan's Boss Timer",
    SI_SBT_POPUP_SUPPORT_SCAN = "Scan With Your Phone to Donate",
    SI_SBT_POPUP_FEEDBACK_TITLE = "Report a Bug or Ask a Question",
    SI_SBT_POPUP_FEEDBACK_SCAN = "Scan With Your Phone to Open the Form",
    SI_SBT_THANK_YOU = "Thank you for your support!",
    SI_SBT_GAMERTAG = "GT: <<1>>", -- One supporter in the settings menu.

    -- Settings menu.
    SI_SBT_MENU_NAME = "Slayan's Boss Timer",
    SI_SBT_MENU_SUPPORT = "Supporters",
    SI_SBT_MENU_DONATE_TOOLTIP = "If you'd like to support my work, any bit is very much appreciated. Donors get their names permanently added to the list :)",
    SI_SBT_MENU_DONATE_NOT_SET = "Donation link coming soon.",
    SI_SBT_MENU_SUPPORTERS_NONE = "Be the first!",
    SI_SBT_MENU_SETTINGS = "Timer Settings",
    SI_SBT_MENU_SHOW_COUNTDOWN = "Show Countdown",
    SI_SBT_MENU_SHOW_COUNTDOWN_ON = "On: A small list on screen shows each defeated boss and the time until it respawns.",
    SI_SBT_MENU_SHOW_COUNTDOWN_OFF = "Off: No list on screen. The timers still run, with their alerts and chat messages.",
    SI_SBT_MENU_FONT_SIZE = "Font Size",
    SI_SBT_MENU_FONT_SIZE_TOOLTIP = "The size of the countdown's text. Its icons and rows grow and shrink with it.",
    SI_SBT_FONT_SIZE_SMALL = "Small",
    SI_SBT_FONT_SIZE_MEDIUM = "Medium",
    SI_SBT_FONT_SIZE_LARGE = "Large",
    SI_SBT_FONT_SIZE_X_LARGE = "X-Large",
    SI_SBT_MENU_POSITION = "Countdown Position",
    SI_SBT_MENU_POSITION_TOOLTIP = "Where the countdown sits. Top Left: under the group list. Top Right: under the quest tracker. Center: above your buffs, or above your health bar when you have none. Custom: wherever you put it with the two sliders below.",
    -- The button on the Timer Settings page that opens the Countdown Position page.
    SI_SBT_MENU_POSITION_PAGE_TOOLTIP = "Select to choose where the countdown sits on the screen.",
    SI_SBT_POSITION_TOP_LEFT = "Top Left",
    SI_SBT_POSITION_TOP_RIGHT = "Top Right",
    SI_SBT_POSITION_CENTER = "Center",
    SI_SBT_POSITION_CUSTOM = "Custom",
    SI_SBT_MENU_POSITION_X = "Left to Right",
    SI_SBT_MENU_POSITION_X_TOOLTIP = "Where the countdown sits across the screen when Countdown Position is Custom: 0 is the left edge and 100 the right. It moves as you change it.",
    SI_SBT_MENU_POSITION_Y = "Top to Bottom",
    SI_SBT_MENU_POSITION_Y_TOOLTIP = "Where the countdown sits down the screen when Countdown Position is Custom: 0 is the top and 100 the bottom. It moves as you change it.",
    SI_SBT_MENU_SHOW_ALERT = "Respawn Alert",
    SI_SBT_MENU_SHOW_ALERT_ON = "On: An alert in the middle of the screen when a boss respawns.",
    SI_SBT_MENU_SHOW_ALERT_OFF = "Off: No alert when a boss respawns.",
    SI_SBT_MENU_PLAY_SOUND = "Respawn Sound",
    SI_SBT_MENU_PLAY_SOUND_ON = "On: A sound plays when a boss respawns.",
    SI_SBT_MENU_PLAY_SOUND_OFF = "Off: No sound when a boss respawns.",
    SI_SBT_MENU_SHOW_CHAT = "Chat Messages",
    SI_SBT_MENU_SHOW_CHAT_ON = "On: A chat message when a boss timer starts and when the boss respawns.",
    SI_SBT_MENU_SHOW_CHAT_OFF = "Off: No chat messages about boss timers.",
    SI_SBT_MENU_RESET = "Reset Boss Timers",
    SI_SBT_MENU_RESET_TOOLTIP = "Clears every boss timer, for all your characters. Typing /sbtreset in chat does the same.",
    SI_SBT_MENU_RELEASE_NOTES = "Release Notes",
    SI_SBT_MENU_RELEASE_NOTES_TOOLTIP = "Select to view the latest changes.",
    SI_SBT_MENU_FEEDBACK = "Feedback",
    SI_SBT_MENU_FEEDBACK_TOOLTIP = "Select to report a bug or ask a question.",
}

for stringId, text in pairs(strings) do
    ZO_CreateStringId(stringId, text)
end
