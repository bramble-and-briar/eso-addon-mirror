-- Notes to Translators:
--   - You will have to create a copy of this file and change it's name to your language. Then translate stuff in that file.
--     List of languages and resulting file names:
--       German: ui_de.lua
--       French: ui_fr.lua
--       Russian: ui_ru.lua
--       Japanese: ui_jp.lua
--       Spanish: ui_es.lua
--       Portuguese: ui_br.lua
--       Polish: ui_pl.lua
--   - /n is newline. It might not work/diplay correctly in all entries. Tooltips should be safe.
--   - %s %d are substitution commands that Addon will replace with dynamic values. They need to stay in translation!
--   - |c ... |r is for coloring text. They need to stay in translation!
--   - Tables/Lists marked "LOOP" are displayed via for loop.  Meaning you can add/remove lines if advantageous for translation
--     If you need to add lines for one not marked loop try /n for newline inside the string
--     If you hit a wall with /n. Let me know. Some additional ones could be changed to LOOP implementation
--   - A lot of UI Elements are fixed width and rather narrow. I know might make translating hard. Please try to fit. 
--     Worst come worst. I might be able to make dimensions as part of the language files. But this would be quite some work I fear. Please try to fit.
--   - Working iterative might be time consuming (Translate some values. Save. /reloadui in game). But safer. 
--     Changing a hundred things. Then /reloadui and nothing works anymore. And trying to figure out which of the 100 changes was the culprit is not pleasant. 
ILeadList = ILeadList or {}
local ILL = ILeadList

ILL.ZONENAME_ALLZONES = "All Zones"
ILL.ZONENAME_BGS = "Battlegrounds"

ILL.KEYBINDINGTEXT = "Toggle Lead List Window"

-- UI Filter Elements (Dropdowns) 	

ILL.DropdownTooltips = {
	major = "Complex Filter Criteria",
	zone = "Filter by Zone",
	settype = "Filter by Set or Type of Antiquity",
}

ILL.DropdownData = {
	ChoicesMajor  = { "Can Find", "Leads with expiration", "Missing Codex Entries", "Never dug out", "Actionable Leads", "All Leads", "Group Dungeons", "Latest DLC",},
  
--	TooltipsMajor  = {
--		"Exludes found but not scried Leads as well as non-repeatable ones already found once",
--		"Only shows Leads which have been found but not scried yet",
--		"Only shows Antiquities which have missing Codex Entries",
--		"Only shows Antiquities which have not been dug out yet",
--		"Shows all Leads except finished non-repeatables",
--		"Shows all Leads including finished non-repeatables",
--		"Shows only Leads coming from 4 Man dungeons",
--		"Shows only new Leads from latest DLC",
--	},
	
	ChoicesZone = {ILL.ZONENAME_ALLZONES, "Current Zone", "Latest DLC", "Exclude minor DLC", "Event Zone"},
	ChoicesSetType  = { "Everything", "Hide Obvious", "Multipart Antiquities", "Mythics",},
}

ILL.LABEL_ALERTS = "|c%sLeads: %d <7d; %d <1d; %d <1d; Codex: %d|r"


ILL.TOOLTIP_ALERTS_1HOUR = "Leads expiring in < 1 hour : %d"
ILL.TOOLTIP_ALERTS_1DAY = " Leads expiring in < 1 day : %d"
ILL.TOOLTIP_ALERTS_7DAYS = " Leads expiring in < 7 day : %d"
ILL.TOOLTIP_ALERTS_TOTALCM = "Total missing codex entries: %d"
ILL.TOOLTIP_ALERTS_TOTALMAP = "---including from treasure maps: %d"
ILL.TOOLTIP_ALERTS_TOTALEA = "---including from Infinite Archive: %d"
ILL.TOOLTIP_ALERTS_TOTALEVENT = "---including from event zones: %d"

ILL.SORTHEADER_NAMES = { "Lead", "Zone", "Location", "Lore", "Dug", "Set", "Expiration", }
ILL.SORTHEADER_TOOLTIP = {
	"Name of the Antiquity",
	"Zone where Lead can be found/scried",
	"Short Location Description\n(D) = Delve\n(PD) = Public Dungeon\n(GD) = Group Dungeon\n(WB) = World Boss",
	"How many Lore/Codex Entries are still missing",
	"How many times has the antiquity been dug out already",
	"Name of the Set that will be rewarded if multipart Antiquity\n. Or type of Reward if single Lead Antiquity",
	"Time until Lead expires.\n For some Leads expiraton time does not go down for the first couple of days.",
}


ILL.TOOLTIP_MAPPINS = "Included in Hoft's MapPins Addon"

ILL.FREERUNNER_INFO = "!!! Any older lead have a chance to drop from Frerunners favor, Nowhere Vault's chests or High Seas event bosses on top of the regular drop spot listed below !!!"


