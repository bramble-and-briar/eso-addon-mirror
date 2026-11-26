-- shared
-- The words on the windows: buttons, legends, the Start here page, chat help. The words of one
-- tracked thing (its column titles and hover texts) are in that thing's own file in Trackers/.
local CT = FurysCharacterTracker

local X = {}
CT.TEXT = X

-- Craft names for the offline viewer; in game the game's own names are used (see CT.CraftName).
X.CRAFTS = { [1] = "Blacksmithing", [2] = "Clothing", [3] = "Enchanting", [4] = "Alchemy", [5] = "Provisioning",
             [6] = "Woodworking", [7] = "Jewelry Crafting" }

X.LEGEND = "|cA08CFFViolet|r maxed  ·  bar = how far along  ·  |c8A86B0-|r none  ·  |c5CC2FFblue|r your pick  ·  |cFFC857amber|r waiting on you  ·  click a name for details  ·  right-click for the menu"
X.UNREAD = "Not read yet. Log in on this character once and its row fills in."
X.UNREAD_TIP = "Not read yet. Log in on this character once, a few seconds is enough, and the addon reads everything about it.\nRight-click to take it off the board."
X.SORT_TIP = "Click to sort by this column. Click again to reverse, a third time for your own order."
X.ACCOUNT_TIP = "The account and megaserver on the board. Every account that plays on this PC shows up here after it logs in once with the addon on.\nOther accounts show what they saved at their last logout."
X.SETTINGS_TIP = "Settings\n(also Settings > Addons > Fury's Character Tracker, or /fct settings)"
X.START_TIP = "New here? One page on how the board works: getting your characters on it, what the colors mean, what each tab is for, and the alert switches.\n(also /fct start)"

-- Buttons under the board, left to right. `id` is what the window does when one is clicked.
X.FOOTER = {
    { id = "timers", label = "Research timers",
      tip = "Every research slot on this account: what is researching, time left, and slots that are free.\n(also /fct timers)" },
    { id = "brag", label = "Brag card",
      tip = "Your roster's best numbers on one card, sized for a screenshot to share on Discord.\n(also /fct brag)" },
    { id = "copy", label = "Copy for Discord",
      tip = "The tab you are looking at as text, ready to paste into Discord.\nIt opens selected: press Ctrl+C, then paste." },
    { id = "export", label = "Export to Excel",
      tip = "Saves the board for the free Windows Tools, which write the Excel file. It reloads the UI, and asks you first.\nNo reload needed: the offline viewer in the Windows Tools has its own Save for Excel button." },
    { id = "scan", label = "Read this character",
      tip = "Reads the character you are on right now. It also happens by itself at login and after progress." },
    { id = "removed", label = "Show removed",
      tip = "Puts back every character you took off the board with right-click > Remove." },
}

X.EXPORT_TITLE = "Export to Excel"
X.EXPORT_BODY = "This saves the board and reloads the UI (a few seconds, like /reloadui).\n\n" ..
    "The file itself is written by the free Windows Tools. Get them with /fct tools, then either " ..
    "open the offline viewer and click Save for Excel (no reload needed at all), or double-click " ..
    "Turn On Auto Export.cmd in the Windows Tools folder once (it is a file there, not a setting in game) " ..
    "and ESO Characters.csv appears in Documents\\Elder Scrolls Online after the reload.\n\nReload now?"
X.EXPORT_SAVED = "Saved %s for export. If you have run Turn On Auto Export.cmd from the Windows Tools folder, ESO Characters.csv is in Documents\\Elder Scrolls Online in a few seconds. If not, open the offline viewer and click Save for Excel."

X.HELP = {
    "/fct  open the board (also on a key: Controls > Keybindings > Fury's Character Tracker)",
    "/fct start  the Start here page: how the board works, in one page",
    "/fct overview, class, weapons, armor, guilds, world, crafting, traits, daily, weekly, collections, points, wallet, progress, sets  open a tab",
    "/fct brag  the brag card: your best numbers on one screen, for a screenshot",
    "/fct timers  research timers window: what each character is researching and time left",
    "/fct research  research slots and timers in chat",
    "/fct settings  open the settings page (or the gear on the board)",
    "/fct alerts on | off  chat line when research or a riding lesson is ready on any character",
    "/fct unread  characters never read, or not read in 7 days (/fct unread 30 for 30 days)",
    "/fct scan  read this character again now",
    "/fct export  export to Excel (asks first, then reloads the UI; the Windows Tools write the file)",
    "/fct tools  get the Windows Tools (offline viewer, Excel export) from GitHub",
}

-- The Start here page, in game and in the offline viewer. A line is a text, or a table:
--   { "text in game", viewer = "text in the offline viewer" }   (viewer = false: not shown there)
--   url = true: a click opens the Windows Tools download page
X.START = {
    { title = "1. Get your characters on the board", lines = {
        "Log in on each character once. A few seconds is enough: the addon reads it right after login.",
        { "Characters not read yet are the dim rows at the bottom of the board. /fct unread lists them in chat.",
          viewer = "Characters not read yet are the dim rows at the bottom of the board." },
        { "After that a character updates by itself whenever you play it. Nothing to click.",
          viewer = "The game saves when you log out or reload the UI. Open the offline viewer again after that to see what is new." },
    } },
    { title = "2. Read the board", lines = {
        "Violet tile = maxed.   A bar behind a number = how far along.   Dim dash = not started.   Blue = your own pick.   Amber = waiting on you.",
        "Hover any cell, or any column title, for what it means. Click a column title to sort by it.",
        { "Click a character for everything saved about it. Right-click a row for its menu: details, move up or down, note, copy, remove.",
          viewer = "Click a character for everything saved about it. Right-click a row to copy it for Discord. Picks, notes and your row order are changed in game." },
        "The bottom row counts how many characters have each column maxed.",
    } },
    { title = "3. The tabs", lines = {
        "Overview: how many skill lines of each kind are maxed, with skill points, research and riding.",
        "Class: level, race, alliance, the three class skill lines each character uses, and other class lines it has trained.",
        "Weapons, Armor, Guilds & AvA, World, Crafting: the rank of every skill line.",
        "Research: traits known in each craft, research slots in use, time until the next one finishes.",
        "Daily: what each character can still do today. Crafting writs, the riding lesson, free research slots, and the first random dungeon, battleground and Tribute match of the day (reward and large XP bonus).",
        "Weekly: the weekly leaderboards (the weekly trial and weekly arena, named in the column titles, Infinite Archive, battlegrounds). Each row shows who ran what; the bottom row is the account's best score and place. Amber = outside the top 500, where the rewards go.",
        "Collections: recipes, furnishing plans, motifs, scribing, companions and hours played.",
        "Skill points: where the points still to earn are: skyshards, public dungeon group events, Alliance War rank.",
        "Wallet & CP: gold and other currencies, bag space, Champion Points. The bank is on the line above.",
        "Progress: what each character gained in the last 7 and 30 days.",
        "Roles & gear: your own role, gear and race picks, a note, and the sets each character is wearing.",
    } },
    { title = "4. Alerts: everything starts turned off. Click a line to switch it.", switches = true },
    { title = "5. More", lines = {
        { "Research timers, Brag card, Copy for Discord: buttons under the board. The gear at the top is Settings.",
          viewer = "Research timers, Brag card, Copy for Discord and Save for Excel: buttons under the board." },
        { "Keys for the board and its windows: Controls > Keybindings > Fury's Character Tracker.", viewer = false },
        "Other accounts on this PC: the button at the top right of the board switches between them.",
        { "Offline viewer and Excel export: the free Windows Tools. Click here to get them (the game asks first).", url = true, viewer = false },
    } },
}
X.START_VIEWER = "Alerts are switched in game: the Start here page there, or Settings > Addons > Fury's Character Tracker."

-- The switches of the Start here page and the settings page: saved field, label, what it does.
-- `on` tells how the field reads when it was never set (existing users from before 1.5.0).
X.SWITCHES = {
    { field = "alertResearch", label = "Research finished", about = "a chat line when research finishes on any character.", unsetIsOn = true, alerts = true },
    { field = "alertRiding", label = "Riding lesson ready", about = "a chat line when a character can take its next lesson.", unsetIsOn = true, alerts = true },
    { field = "loginNotice", label = "Summary at login", about = "one chat line naming what finished while you were away.", unsetIsOn = true },
    { field = "openAtLogin", label = "Open the board at login", about = "the board is on screen every time you log in.", unsetIsOn = false },
}
