-- English, and the base every other language file overrides.
local strings = {
	-- dates
	SI_PBSHPS_WEEKDAYS = "Sun,Mon,Tue,Wed,Thu,Fri,Sat",
	SI_PBSHPS_MONTH_FORMAT = "%04d-%02d",

	-- periods
	SI_PBSHPS_SCOPE_TODAY = "Today",
	SI_PBSHPS_SCOPE_THISMONTH = "This month",
	SI_PBSHPS_SCOPE_ALL = "All (last %d days)",

	-- the summary rows
	SI_PBSHPS_NONE = "Nothing recorded yet",
	SI_PBSHPS_ROW_HEAL = "Healed  %s",
	SI_PBSHPS_ROW_HPS = "HPS  %s",
	SI_PBSHPS_ROW_FIGHTS = "Fights  %s   Healing time  %s",
	SI_PBSHPS_ROW_BEST = "Best HPS  %s   Biggest heal  %s",
	SI_PBSHPS_ROW_CRIT = "Critical heals  %s",
	SI_PBSHPS_ROW_OVER = "Overheal  %s  (%s)",
	SI_PBSHPS_ROW_GROUP = "To party  %s  %s  %s players",
	SI_PBSHPS_ROW_OTHER = "To others  %s  %s  %s players",
	SI_PBSHPS_ROW_SELF = "To you  %s  %s",
	SI_PBSHPS_ROW_PT_SHARE = "Your share of party healing  %s",
	SI_PBSHPS_PT_UNKNOWN = "-",
	SI_PBSHPS_TAG_PARTY_SHARE = "[PT %s]",
	SI_PBSHPS_TAG_PARTY = "[party]",

	-- the HUD meter
	SI_PBSHPS_HUD_HPS = "HPS  %s",
	SI_PBSHPS_HUD_RECENT = "Last %d s  %s",
	SI_PBSHPS_HUD_ENDED = "Fight over",
	SI_PBSHPS_HUD_TOTAL = "Healed  %s   %s   %d players",
	SI_PBSHPS_HUD_SHARE = "Party %d%%  Others %d%%  You %d%%",
	SI_PBSHPS_HUD_PT_SHARE = "Your share of party healing  %s",

	-- the statistics window
	SI_PBSHPS_WINDOW_TITLE = "PB's HPS Checker  -  %s",
	SI_PBSHPS_BLOCK_SUMMARY = "Summary",
	SI_PBSHPS_BLOCK_TARGETS = "Top 10 healed  [PT 72%] = your share",
	SI_PBSHPS_BLOCK_SKILLS = "Top 10 skills",
	SI_PBSHPS_BLOCK_FIGHTS = "Latest 10 fights",

	-- the settings panel
	SI_PBSHPS_EXPLANATION = "Counts the healing you do in PvP and shows it as statistics. It only reads game events; nothing is pressed or cast for you.",
	SI_PBSHPS_SECTION_STATS = "Statistics",
	SI_PBSHPS_STATS_BUTTON = "Statistics window",
	SI_PBSHPS_STATS_BUTTON_TIP = "Shows or hides the statistics window. While this panel is open it is drawn over it, and it stays on the HUD afterwards.",
	SI_PBSHPS_STATS_BUTTON_TEXT = "Show / hide",
	SI_PBSHPS_PERIOD = "Period",
	SI_PBSHPS_PERIOD_TIP = "What the statistics below and in the window are taken over: today, this month, everything that is saved, one month or one day.",
	SI_PBSHPS_SHOW_PSN = "Show PSN IDs in the ranking",
	SI_PBSHPS_SHOW_PSN_TIP = "Shows a player's PSN ID in the list of players you healed. The game's combat events give only the character name, so the PSN ID is learned from your party members, from players you point the reticle at, and from the kill feed (a kill names both players). A player who has been none of those stays a character name. Off, every name is a character name.",

	SI_PBSHPS_SECTION_HUD = "HPS meter",
	SI_PBSHPS_HUD = "Show the meter",
	SI_PBSHPS_HUD_TIP = "A small box with the HPS of the fight you are in, how much you healed and who it went to. It comes up with your first heal. While this panel is open it is shown with sample numbers so that you can place it.",
	SI_PBSHPS_HUD_SIZE = "Meter size",
	SI_PBSHPS_HUD_SIZE_TIP = "1 is the smallest, 7 the largest, 4 the standard. The text changes in steps and the box grows with it. Only fonts the console already has loaded are used, so it does not scale smoothly and cannot go any bigger. While this panel is open the meter is shown with sample numbers.",
	SI_PBSHPS_HUD_CUSTOM = "Set the box size in pixels",
	SI_PBSHPS_HUD_CUSTOM_TIP = "Off, the box is as big as its text needs. On, it is exactly the width and height below (pixels, as the sliders show them), whatever the text needs: a line that is too wide ends in ... and lines past the bottom are drawn below the box. Switching it on starts from the box's current size.",
	SI_PBSHPS_HUD_WIDTH = "Box width (px)",
	SI_PBSHPS_HUD_WIDTH_TIP = "Used only while \"Set the box size in pixels\" is on. The text size is the \"Meter size\" above.",
	SI_PBSHPS_HUD_HEIGHT = "Box height (px)",
	SI_PBSHPS_HUD_HEIGHT_TIP = "Used only while \"Set the box size in pixels\" is on. Five lines of text need about 200 px at the standard text size.",
	SI_PBSHPS_HUD_HOLD = "Keep it up after a fight (s)",
	SI_PBSHPS_HUD_HOLD_TIP = "How long the meter stays on screen after a fight ends, so that the result can be read.",
	SI_PBSHPS_HUD_LEFT = "Horizontal position",
	SI_PBSHPS_HUD_LEFT_TIP = "Distance of the meter from the left edge of the screen.",
	SI_PBSHPS_HUD_TOP = "Vertical position",
	SI_PBSHPS_HUD_TOP_TIP = "Distance of the meter from the top edge of the screen.",

	SI_PBSHPS_SECTION_RECORD = "Recording",
	SI_PBSHPS_ENABLED = "Record healing",
	SI_PBSHPS_ENABLED_TIP = "Off, nothing is counted.",
	SI_PBSHPS_OTHERS = "Count other healers' heals",
	SI_PBSHPS_OTHERS_TIP = "Also counts the heals other healers do to your party members, to work out your share of what a party member received. Off, only your own heals are counted, so the share reads 100%. The same while none of their heals reaches the add-on. In a big fight this is every healer's heals, so switch it off if the game feels heavy.",
	SI_PBSHPS_ZONES = "Where to count",
	SI_PBSHPS_ZONES_TIP = "Cyrodiil only (default), every PvP zone (Cyrodiil, the Imperial City, Battlegrounds), or everywhere including PvE.",
	SI_PBSHPS_ZONE_CYRODIIL = "Cyrodiil only",
	SI_PBSHPS_ZONE_PVP = "All PvP zones",
	SI_PBSHPS_ZONE_ALL = "Everywhere",
	SI_PBSHPS_GAP = "Fight ends after (s)",
	SI_PBSHPS_GAP_TIP = "A fight ends when you have not healed for this long. HPS is the amount healed over the time from the first heal of a fight to its last.",

	SI_PBSHPS_SECTION_DATA = "Data",
	SI_PBSHPS_CLEAR = "Delete all records",
	SI_PBSHPS_CLEAR_TIP = "Deletes every day, fight and skill that has been recorded. You are asked first.",
	SI_PBSHPS_BUTTON_RUN = "Run",
	SI_PBSHPS_ERR_NO_DIALOG = "Could not ask for confirmation, so nothing was deleted.",
	SI_PBSHPS_DIALOG_CLEAR_TITLE = "Delete all records?",
	SI_PBSHPS_DIALOG_CLEAR_TEXT = "Every recorded day of healing statistics is deleted. This cannot be undone.",

	-- chat
	SI_PBSHPS_LOADED = "PB's HPS Checker %s loaded. /hps for commands.",
	SI_PBSHPS_HELP = "/hps today | month | all -- print the statistics to chat\n/hps stats [today | month | all] -- show or hide the statistics window\n/hps hud -- show or hide the HPS meter\n/hps on | off -- start or stop recording\n/hps status -- what has been counted so far\n/hps probe -- measure which heals the game sends to the add-on (2 minutes)\n/hps debug -- print the next heals as the game reports them",
	SI_PBSHPS_CMD_SCOPE_HEADING = "[HPS] %s",
	SI_PBSHPS_CMD_TOP_TARGETS = "[HPS] Top 10 players healed",
	SI_PBSHPS_CMD_TOP_SKILLS = "[HPS] Top 10 skills",
	SI_PBSHPS_CMD_ON = "HPS Checker is recording.",
	SI_PBSHPS_CMD_OFF = "HPS Checker stopped recording.",
	SI_PBSHPS_CMD_HUD_ON = "HPS meter on.",
	SI_PBSHPS_CMD_HUD_OFF = "HPS meter off.",
	SI_PBSHPS_CMD_DEBUG_ON = "Debug on: the next %d heals are printed.",
	SI_PBSHPS_CMD_DEBUG_OFF = "Debug off.",
	SI_PBSHPS_DEBUG_FULL = "[HPS] Debug line limit reached. /hps debug starts it again.",
	-- the probe (/hps probe)
	SI_PBSHPS_PROBE_START = "Probe started: for %d seconds every heal the game sends is counted, whoever heals whom. Stand where other healers are healing. /hps probe again stops it early and shows the result.",
	SI_PBSHPS_PROBE_RUNNING = "[HPS] Probe running, %d s left.",
	SI_PBSHPS_PROBE_HEADING = "[HPS] Probe result (%d s). Heals the game sent, as source > target:",
	SI_PBSHPS_PROBE_NONE = "No heal arrived at all.",
	SI_PBSHPS_PROBE_LINE = "  %s > %s  heals: %d  amount: %s  sources: %d  e.g. %s",
	SI_PBSHPS_PROBE_LEGEND = "[HPS] Did it arrive? (PLAYER = you, GROUP = a party member, OTHER = anybody else)",
	SI_PBSHPS_PROBE_Q_SELF_GROUP = "You > party member",
	SI_PBSHPS_PROBE_Q_SELF_OTHER = "You > outside the party",
	SI_PBSHPS_PROBE_Q_GROUP_GROUP = "Party member > party member",
	SI_PBSHPS_PROBE_Q_OTHER_GROUP = "Outside the party > party member",
	SI_PBSHPS_PROBE_Q_OTHER_OTHER = "Outside the party > outside the party",
	SI_PBSHPS_PROBE_YES = "YES (heals: %d)",
	SI_PBSHPS_PROBE_NO = "NO",
	SI_PBSHPS_PROBE_CAVEAT = "[HPS] A NO may only mean it did not happen while probing: it needs other healers healing near you, and for the first two lines, heals of your own.",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
