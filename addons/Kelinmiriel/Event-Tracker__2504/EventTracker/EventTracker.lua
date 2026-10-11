-- Added: --EVENTUPDATE tag to mark places in all .lua files that need to be updated or at least checked with every event update.
local Latest_Version = 2.430

-- ****** Line 1100 ****** Remember to change the collectibles for each event as appropriate!
-- 3220 If version increased by more than 0.12, pop up info box. Adjust according to whether there's new info

-- 2.430 High Seas; Witches
-- 2.420 Zeal of Zenithar; U50; U51 for PTS
-- 2.412 Zeal of Zenithar on PTS
-- 2.411 Should now avoid Trade Bars dropped from other sources such as Twitch or Tome purchases.
-- 2.410 Anniversary (had 3 trade bars instead of 300); U50 API
-- 2.401 Fixed final trade bars for Jester's; more info on future
-- 2.400 Jester's Fest  & Anniversary; U49 API; MAJOR CHANGE - TRADE BARS! No more Event Tickets!!
-- 2.390 Heart's Week. Added info about upcoming changes.
-- 2.380 Mayhem. Not updating for U49 yet though PTS has been out for a week.
-- 2.371 Fixed end date code
-- 2.370 New Life
-- 2.361 fixed
-- 2.360 Daedric War
-- 2.350 Witches Festival
-- 2.340 Undaunted on live; Heart's Week on PTS (just dates & tickets)
-- 2.330 Whitestrake's extended one day - didnt find out until after last reset for EU
-- 2.322 Whitestrake's Mayhem; U47 (2.321 was only a manifest change)
-- 2.320 Zeal of Zenithar; U46 API (2023 collectibles added)
-- 2.311 Robes of Truth and Law was missing fifth (unused) parameter
-- 2.310 Anniversary
-- 2.301 Anniv end date; changed to ".addon" to begin console compatibility
-- 2.300 Jesters Festival & start of Anniversary
-- 2.291 Fixed ticket algorithm
-- 2.290 Mayhem
-- 2.280 Pan-Tamriel; U45 API; Jester's & Anniversary on PTS
-- 2.271 Collectibles weren't triggering right for 5-part house
-- 2.270 New Life
-- 2.260 Legacy of the Bretons
-- 2.250 Witches Festival
-- 2.240 Fallen Leaves of the West Weald; PTS Legacy of the Bretons, New Life, Pan-Tamriel
-- 2.230 Undaunted; U44 API
-- 2.220 Whitestrake's Mayhem; U43 API
-- 2.210 Zeal of Zenithar
-- 2.202 Event effectively reduced by one day on the NA when a last-minute shutdown was announced for 6am-2pm. (NA only)
-- 2.201 Event extended two days because of major PTS/NA fiasco; updated default cake memento to 2024
-- 2.200 Anniversary: Removed library to get it working again as quickly as possible.
-- 2.110 Jester's Festival: First live library release! Changed "d" outputs; removed a leftover debug statement in EVTEvents
-- 2.100 Library - first beta version (Whitestrake's Mayhem) - no zone, localization incomplete, quest not done, locks not done
-- 2.070 Whitestrake's Mayhem; Anniversary on PTS
-- 2.060 Guilds and Glory; Jester & Anniversary on PTS
-- 2.050 New Life
-- 2.041 Gate of Oblivion extended one day because of system maintenance the night before original end
-- 2.040 Gate of Oblivion (put together while computer under duress)
-- 2.031 Fixed date code for end
-- 2.030 Witches Festival
-- 2.021 fixed minor typo in message for not having chapter
-- 2.020 Secrets of the Telvanni
-- 2.010 Undaunted
-- 2.001 Zenithar extended one day due to lengthy log-in queues and server issues
-- 2.000 Zeal of Zenithar
-- 1.991 Added Silver Leaves collectible; fix boards to trigger warning; initial German support (not released)
-- 1.990 2nd Mayhem; also check for Tribute match when using scroll
-- 1.981 Minor changes to "/evt coll"
-- 1.98 Added collectible info to "/evt"; first Mayhem; Zenithar
-- 1.97 Less cakes
-- 1.96 Anniversary, and a few minor things 
-- 1.95 Jester's Festival - added evti news (different by server)
-- 1.94 Fix PTS events and incorporate new ticket timer
-- 1.93 Event tickets weren't being picked up right for Dragon (version not changed in Event Tracker.lua) 
-- 1.92 Missed NPC activator warnings for Dragon (version not changed in Event Tracker.lua)
-- 1.91 Season of the Dragon; PTS Jester & Anniv. (guessed) (incorrectly)
-- SAFETY NET feature under development: Set up an event ahead of time if possible, with a check to notice if it's started, even if no dates are known yet.
-- AUTOBUFF Running tests on new auto-buffing algorithms; currently disabled for live

--  This addon tracks event loot. Many details moved to EVT_Archive.txt

--  @module EventTracker
--  @author Kelinmiriel

-- 2.100 LIBRARY LibEventInfo is the public one; LibEventTracker embedded. Embedded version for publication, but can use the public library for testing.
--local LibEVT = LibEventInfo
-- 2.200 local LibEVT = LibEventTracker

EVT_ONE_DAY = 86400
EVT_ONE_HOUR = 3600
EVT_DATE_UNKNOWN = 9999999999
local Scroll_ID = 121550 -- 64221 Psijic Ambrosia for testing
local Scroll_Memento = 999999
local No_Event_Info = string.format("Event Tracker version %s has no information about the next event yet.",Latest_Version)

-- 2.100 LIBRARY Used for collectibles info; passed from library
local WhichQuarter,WhichMonthInQuarter

--EVENTUPDATE
-- 2.411 Update cake collectible number in Events!
-- 2.070 2024 cake 12422 (replaces 2023 cake 11089)
-- /script for i=335,30000 do memname=GetCollectibleInfo(i) if memname == "Jubilee Cake 2026" then d(i) end end
local Collectible_Num = {
	["Jubilee Cake 2026"] = 14325,
--	["Jubilee Cake 2025"] = 13520,
--	["Jubilee Cake 2024"] = 12422,
--	["Jubilee Cake 2023"] = 11089,
	["cake"] = 14325,
--	["cake"] = 12422, 2024
	}
-- 2.201 Cake
local Current_Cake = "Jubilee Cake 2026"

--EVENTUPDATE
EVT_EVENT_START = EVT_DATE_UNKNOWN
EVT_EVENT_END = EVT_DATE_UNKNOWN

-- 2.110
local EVT_CURRENT_INFO = ""

-- ******************************************
-- EVENTUPDATE DLC CHAPTER UNLOCKED
-- ******************************************
-- 1.54 New feature: For events locked behind a paywall, set a flag if access is unlocked.
EVT_DLC_UNLOCKED =	{true,true,true}

-- 2.050 Restored defaults: no DLCs or chapters to check
local DLC_Names = {"","",""}
local DLC_Types = {"","",""}
local DLC_IDs = {0,0,0}


-- 1.87 Set these variables here or in Init where checking is done
-- CODE TO DO THE CHECKING MUST BE ACTIVATED IN INIT
-- See: -- EVENTUPDATE LOCKED DLC CHAPTER INITIALIZATION
--[[ 10475 Necrom
local DLC_Names = {"Blackwood/Deadlands","",""}
local DLC_Types = {"DLC","",""}
local DLC_IDs = {8659,0,0}
]]

-- 1.60 Planning ahead for last fragment of collectible behind paywall - standard event. Changed in init if different.
EVT_PLAN_AHEAD = false -- false if no special planning is required, or it's too late to do anything about it
EVT_FRAGMENTS_DONE = true
Fragment1 = false
Fragment2 = false

-- SAFETY NET Quest max is the max number currently available as a quest reward from any single completed quest in the journal.
local EventQuestGiver = {}
-- EVT_QUEST_MAX = 0

-- 2.371 Jan & Feb were "+1"
-- 2.250 Added, so I don't have to look these numbers up all the time
-- Hardcoded numbers from 2024
local MonthCode = {
	["61"] = 1704034800 + EVT_ONE_DAY*365*2+EVT_ONE_DAY,	-- Jan. 10am EST
	["62"] = 1706713200 + EVT_ONE_DAY*365*2+EVT_ONE_DAY,	-- Feb.
	["6M"] = 1709218800 + EVT_ONE_DAY*365*2,	-- Mar. (EST)
	["63"] = 1709215200 + EVT_ONE_DAY*365*2,	-- Mar. (EDT)
	["64"] = 1711893600 + EVT_ONE_DAY*365*2,	-- Apr.
	["65"] = 1714485600 + EVT_ONE_DAY*365*2,	-- May
	["66"] = 1717164000 + EVT_ONE_DAY*365*2,	-- June
	["67"] = 1719756000 + EVT_ONE_DAY*365*2,	-- July
	["68"] = 1722434400 + EVT_ONE_DAY*365*2,	-- August
	["69"] = 1725112800 + EVT_ONE_DAY*365*2,	-- Sept.
	["6A"] = 1727704800 + EVT_ONE_DAY*365*2,	-- Oct.
	["6N"] = 1730383200 + EVT_ONE_DAY*365*2,	-- Nov. (EDT)
	["6B"] = 1730386800 + EVT_ONE_DAY*365*2,	-- Nov. (EST)
	["6C"] = 1732978800 + EVT_ONE_DAY*365*2,	-- Dec.

}
-- DST changes: (2am) (March: 2 becomes 3; Nov.: 2 becomes 1.)
-- 2024   March 10   Nov. 3
-- 2025   March  9   Nov. 2
-- 2026   March  8   Nov. 1
-- 2027   March 14   Nov. 7
-- 2028   March 11   Nov. 4

-- ******************************************
-- EVENTUPDATE INITIALIZE EVENT
-- ******************************************
-- 2.100 LIBRARY REMOVED

--[[ 2.260 Legacy of the Bretons (PTS 9/16-9/23/24) 11/21-12/3/24
EVT_EVENT_START = MonthCode["4B"] + EVT_ONE_DAY*21 -- EST
EVT_EVENT_END   = MonthCode["4C"] + EVT_ONE_DAY*3
EVT_NEXT_EVENT  = "Bretons"
EVT_EVENT_DETAILS = {
		["Name"] = "Bretons",
		["T_Types_1"] = "Bretons",
		["T_Types_2"] = "not used",
		["T_Tickets"] = {2,0,0,0,},
		["T_ToDo"] = {1,0,0,},
		}

EVT_EVENT_INFO_BEGIN = "Check Crown Store for FREE starter quest."
EVT_EVENT_INFO_BOX = "2 GOLD boxes/day/account: 1 from High Isle or Galen daily quest or DSR weekly; one from final boss of DSR, Shipwright's, Coral Aerie, Graven Deep, or Earthen Root. Purple boxes from almost anything in High Isle, Galen, DSR, or those 4 group dungeons."
EVT_UPCOMING_INFO = "Dec: New Life(3); 2025 Jan.: Pan-Tamriel(3); Feb.: Whitestrake's Mayhem(3). (number)=Tickets per day, per account."
]]


-- 2.240 New Life PTS 9/23-30
-- 2.241 Pan-Tamriel PTS 9/30-10/7 (Live: January 2025)

--[[ 2.280 Pan-Tamriel 1/23/25-2/4/25
EVT_EVENT_START = MonthCode["51"] + EVT_ONE_DAY*23
EVT_EVENT_END   = MonthCode["52"] + EVT_ONE_DAY*4
EVT_NEXT_EVENT  = "Pan-Tamriel"
EVT_EVENT_DETAILS = {
	["Name"] = "Pan-Tamriel",
	["T_Types_1"] = "Pan-Tamriel",
	["T_Types_2"] = "not used",
	["T_Tickets"] = {3,0,0,0,},
	["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "Check Crown Store for FREE starter quest."
EVT_EVENT_INFO_BOX = "Up to 8 gold boxes/day/account from differnt types of final bosses: delve, wb, trial, arena, Tho'at, group dungeon, pub dungeon, incursion (dolmen/dragon/etc)."
EVT_UPCOMING_INFO = "Feb.: Whitestrake's Mayhem(3); Mar: Jesters(3); Apr: Anniversary(3). (number)=Tickets per day, per account."
]]

--[[ 2.340 Undaunted 9/18-30/25
EVT_EVENT_START = MonthCode["59"] + EVT_ONE_DAY*18
EVT_EVENT_END   = MonthCode["59"] + EVT_ONE_DAY*30
EVT_NEXT_EVENT  = "Undaunted"
EVT_EVENT_DETAILS = {
["Name"] = "Undaunted",
["T_Types_1"] = "Undaunted",
["T_Types_2"] = "not used",
["T_Tickets"] = {2,0,0,0,},
["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "Look for Predicant Maera at any Battlegrounds Camp, or at your alliance base camp in Cyrodiil (use the alliance war menu, L, to travel there)."
EVT_EVENT_INFO_BOX = "Get boxes from DAILY Battlegrounds quests, Cyrodiil quests (including towns), and Imperial City quests."
EVT_UPCOMING_INFO = "Oct: Witches(3) XP!; Daedric War (2); Dec: New Life(3) XP!. (number)=Tickets per day, per account."
]]


-- 2.351 11/20-12/2/25; PTS 9/29-10/6/25
--[[ Lock code around 3100 in init; also in Sign-on
EVT_EVENT_START = MonthCode["5B"] + EVT_ONE_DAY*20
EVT_EVENT_END   = MonthCode["5C"] + EVT_ONE_DAY*2
EVT_NEXT_EVENT  = "Daedric War"
EVT_EVENT_DETAILS = {
	["Name"] = "Daedric War",
	["T_Types_1"] = "Morrowind/Clockwork",
	["T_Types_2"] = "Summerset",
	["T_Tickets"] = {1,1,0,0,},
	["T_ToDo"] = {1,1,0,},
}

EVT_EVENT_INFO_BEGIN = "Check Crown Store for FREE starter quest; get one extra purple box per character for the event."
EVT_EVENT_INFO_BOX = "Additional boxes from killing, looting, harvesting, questing, dungeons, delves, trials, etc, in all 3 zones."
EVT_UPCOMING_INFO = "Dec: New Life(3)*. Jan: Whitestrake's Mayhem(3). Feb: Heart's Week(2). March: Jester's(3)*. April: Anniversary(3)*. (number)=Tickets per day, per account. *=DBL XP"

EVT_DLC_UNLOCKED =	{true,false,true}

DLC_Names = {"","Summerset",""}
DLC_Types = {"","DLC",""}
DLC_IDs = {0,5107,0}
]]

-- 2.270 New Life 12/19/24-1/7/25
-- 2.370 12/18/25-1/6/26 New dailies PTS 9/22-9/29/25
-- 2.371 Had "6A" instead of "61" for end date
--[[EVT_EVENT_START = MonthCode["5C"] + EVT_ONE_DAY*18
EVT_EVENT_END   = MonthCode["61"] + EVT_ONE_DAY*6
EVT_NEXT_EVENT  = "New Life"
EVT_EVENT_DETAILS = {
	["Name"] = "New Life",
	["T_Types_1"] = "New Life",
	["T_Types_2"] = "not used",
	["T_Tickets"] = {3,0,0,0,},
	["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "Go to Breda's tent in Kynesgrove in Eastmarch, south of Windhelm. You can port there from any Impresario tent."
EVT_EVENT_INFO_BOX = "Additional boxes drop from New Life and Old Life quests; up to 18 boxes total per character per day."
EVT_UPCOMING_INFO = "Jan: Whitestrake's Mayhem(3). Feb: Heart's Week(2). March: Jester's(3)*. April: Anniversary(3)*. (number)=Tickets per day, per account. *=DBL XP"
]]


-- 2.380 Mayhem 1/21-2/4/26
--[[ 2.330 Mayhem 7/24-8/7/25 (PTS 4/28-5/5)
EVT_EVENT_START = MonthCode["61"] + EVT_ONE_DAY*21
EVT_EVENT_END   = MonthCode["62"] + EVT_ONE_DAY*4
EVT_NEXT_EVENT  = "Whitestrake's Mayhem"
EVT_EVENT_DETAILS = {
["Name"] = "Whitestrake's Mayhem",
["T_Types_1"] = "Cyro/BG",
["T_Types_2"] = "Imperial City",
["T_Tickets"] = {2,1,0,0,},
["T_ToDo"] = {1,1,0,},
}

EVT_EVENT_INFO_BEGIN = "Look for Predicant Maera at any Battlegrounds Camp, or at your alliance base camp in Cyrodiil (use the alliance war menu, L, to travel there)."
EVT_EVENT_INFO_BOX = "Get boxes from DAILY Battlegrounds quests, Cyrodiil quests (including towns), and Imperial City quests."
EVT_UPCOMING_INFO = "Feb: Heart's Week(2 TICKETS); Mar: * Jester's(300 TRADE BARS); Apr: * Anniv(300 TRADE BARS) (number)=Tickets/Trade bars per day, per account. *=DBL XP"
]]


--[[ 2.390 NEW annual Heart's Week event on PTS (for 2026) 9/15-22/25
EVT_EVENT_START = MonthCode["62"] + EVT_ONE_DAY*11
EVT_EVENT_END   = MonthCode["62"] + EVT_ONE_DAY*18
EVT_NEXT_EVENT  = "Heart's Week"
EVT_EVENT_DETAILS = {
["Name"] = "Heart's Week",
["T_Types_1"] = "Heart's Week",
["T_Types_2"] = "not used",
["T_Tickets"] = {2,0,0,0,},
["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "(opt.) Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.) Then go to the new Festival Grounds west of Belkarth in Craglorn."
EVT_EVENT_INFO_BOX = "Get boxes from a Boss of a Delve, WB, Archive, or Incursion; a Treasure Chest; Harvesting a Node; or Pickpocketing. BEST TO HAVE A COMPANION OUT WHEN OPENING BOXES!"
EVT_UPCOMING_INFO = "late March: Jester's Fest(300); April: Anniversary(300) (both DBL XP). (number)=TRADE BARS per day, per account."
]]


-- 2.300 Jester's Festival 3/27-4/3/25 (Jan. 21-27 2025 on PTS, started Tues because of holiday)
--[[ 2.400 Jester's Festival 3/25-4/2/26 - First event with TRADE BARS
EVT_EVENT_START = MonthCode["63"] + EVT_ONE_DAY*25
EVT_EVENT_END   = MonthCode["64"] + EVT_ONE_DAY*2
EVT_NEXT_EVENT  = "Jester's Festival"
EVT_EVENT_DETAILS = {
["Name"] = "Jester's Festival",
["T_Types_1"] = "Jester's Festival",
["T_Types_2"] = "none",
["T_Tickets"] = {300,0,0,0,},
["T_ToDo"] = {1,0,0,},
}
EVT_EVENT_INFO_BEGIN = "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.) Then go to a Jester's tent near Vulkhel Guard, Daggerfall, or south of Ebonheart in Stonefalls."
EVT_EVENT_INFO_BOX = "Get boxes from any Jester's daily quest."
EVT_UPCOMING_INFO = "IMMEDIATELY FOLLOWING JESTERS: ANNIVERSARY (Apr. 2-15)!! 300 TRADE BARS per day from cake; double xp. June: Zenithar (300 bars/acct/day)"
]]


-- 2.300 Anniversary 4/3-22/25 (PTS: Jan. 27-Feb. 3)
--[[ 2.400 Anniversary 4/2-15/26
EVT_EVENT_START = MonthCode["64"] + EVT_ONE_DAY*2
EVT_EVENT_END   = MonthCode["64"] + EVT_ONE_DAY*15
EVT_NEXT_EVENT  = "Anniversary"
EVT_EVENT_DETAILS = {
["Name"] = "Anniversary",
["T_Types_1"] = "Anniversary",
["T_Types_2"] = "not used",
["T_Tickets"] = {300,0,0,0,},
["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "Go to the docks of Vulkhel Guard, Daggerfall, or Davon's Watch, and look for Chef Donolan's Apprentice Mogh, or first pick up the FREE quest in the Crown Store to start (it doesn't cost anything)"
EVT_EVENT_INFO_BOX = "Get boxes from ANY DAILY QUEST, anywhere! (Even crafting!)"
EVT_UPCOMING_INFO = "June: Zeal of Zenithar (300 bars/acct/day); then Oct: Witches (DOUBLE XP)."
]]

-- Zeal of Zenithar 6/26-7/8/25 (PTS 4/21-28)
--[[ 2.420 Zeal of Zenithar 6/24-7/8/26 (PTS 4/13-20)
EVT_EVENT_START = MonthCode["66"] + EVT_ONE_DAY*24
EVT_EVENT_END   = MonthCode["67"] + EVT_ONE_DAY*8
EVT_NEXT_EVENT  = "Zeal of Zenithar"
EVT_EVENT_DETAILS = {
	["Name"] = "Zeal of Zenithar",
	["T_Types_1"] = "Zeal of Zenithar",
	["T_Types_2"] = "none",
	["T_Tickets"] = {300,0,0,0,},
	["T_ToDo"] = {1,0,0,},
}
EVT_EVENT_INFO_BEGIN = "(opt.) Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.) Go to the Festival Grounds west of Belkarth in Craglorn."
EVT_EVENT_INFO_BOX = "Get purple boxes from daily crafting writs (1 total) and master (1 per discipline) (per day per acct); world bosses/world events/arenas/possibly stealing, while in party with ONLINE NEARBY guild members."
EVT_UPCOMING_INFO = "Aug, Nov: Mayhem (no bars); Oct: Witches(300). (number)=Trade Bars per day, per account."
]]

-- 2.430 High Seas 9/30-10/14/26 (PTS 8/3-10)
EVT_EVENT_START = MonthCode["69"] + EVT_ONE_DAY*30
EVT_EVENT_END   = MonthCode["6A"] + EVT_ONE_DAY*14
EVT_NEXT_EVENT  = "High Seas"
EVT_EVENT_DETAILS = {
	["Name"] = "High Seas",
	["T_Types_1"] = "High Seas",
	["T_Types_2"] = "none",
	["T_Tickets"] = {300,0,0,0,},
	["T_ToDo"] = {1,0,0,},
}
EVT_EVENT_INFO_BEGIN = "(opt.) Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.) Find Baron-Captain Olsien Guy Mard west of Anvil in the Gold Coast; complete the 'Raising the Riotous Redress' quest to unlock dailies."
EVT_EVENT_INFO_BOX = "Get purple boxes from repeating Olsien Guy Mard's High Seas quest on additional characters."
EVT_UPCOMING_INFO = "Oct: Witches(300; DOUBLE XP); Nov: Mayhem (NO TRADE BARS); Dec: New Life(300; DOUBLE XP). (number)=Trade Bars per day, per account."


-- 2.250 Witches 10/24-11/6/24 (EST)
-- 2.350 10/23-11/5/25 (EST)
--[[ 2.430 10/21-11/4/26 (EST) NO PTS
EVT_EVENT_START = MonthCode["6A"] + EVT_ONE_DAY*21
EVT_EVENT_END   = MonthCode["6B"] + EVT_ONE_DAY*4 -- EST
EVT_NEXT_EVENT  = "Witches"
EVT_EVENT_DETAILS = {
["Name"] = "Witches",
["T_Types_1"] = "Witches",
["T_Types_2"] = "not used",
["T_Tickets"] = {2,0,0,0,},
["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "Check Crown Store for FREE starter quest."
EVT_EVENT_INFO_BOX = "There's a chance of additional boxes from any boss, even the little daedric incursions that pop up all over. LOOT ALL BODIES AND REWARD CHESTS!"
EVT_UPCOMING_INFO = "Nov: Mayhem (NO TRADE BARS). Dec: New Life(300)*. Feb: Heart's Week(200). March: Jester's(300)*. April: Anniversary(300)*. (number)=Tickets per day, per account. *=DBL XP"
]]


-- PTS events around line 2900

--------------------------------------------------------------------


-- SAFETY NET Actual values for this are set in EVT.QuestTickets() in EVTEvents, because they need to be reset to zero at the beginning of each run
-- When I figure out how, they should be moved changed to languange file instead.
EVT_QUEST_TICKETS = {}

-- 1.83 Setting EVT_FUTURE to 0 disables this whole mess.
-- 1.75 I don't remember if this even worked, but I had left it active, so set it up for Anniversary.
EVT_FUTURE	= 0	-- Number of future events in buffer (I'm starting with 1 - Anniversary - though technically, I don't even really know anything about it yet.)
EVT_FUTURE_START	= {
--		EVT_DATE_UNKNOWN,	-- 1.95 Set up for start of Anniversary immediately after Jester
		EVT_EVENT_END,	-- 2.300 Activate this code for Jesters Fest; deactivate it the rest of the year
		}
EVT_FUTURE_END	= {
		EVT_DATE_UNKNOWN,
--		MonthCode["64"] + EVT_ONE_DAY*22
		}
EVT_FUTURE_EVENT	= {
		"Anniversary",
		}
EVT_FUTURE_NEXT	= {
		"June: Zeal of Zenithar (300 bars/acct/day); then Oct: Witches (DOUBLE XP).",	-- Upcoming_Info
		}
EVT_FUTURE_BEGIN	= {
		"Go to the docks of Vulkhel Guard, Daggerfall, or Davon's Watch, and look for Chef Donolan's Apprentice Mogh, or first pick up the FREE quest in the Crown Store to start (it doesn't cost anything)",
		}
EVT_FUTURE_BOX	= {
		"Get boxes from ANY DAILY QUEST, anywhere! (Even crafting!)",
		}
EVT_FUTURE_DETAILS = {
		["Name"] = "Anniversary",
		["T_Types_1"] = "Anniversary",
		["T_Types_2"] = "not used",
		["T_Tickets"] = {300,0,0,0,},
		["T_ToDo"] = {1,0,0,},
		}

EVT_POLLING_ACTIVE = "None"         -- Possible values: "None", "Update UI", "Start New Event", "Daily Reset", "XP_Buff"
EVT_POLL_TIME = 0

EVT_MESSAGE_DELAY = EVT_ONE_HOUR*24
-- 1.17 Make EVT_HIDE_UI a temporary variable so I can hide it in between events without affecting the user's setting.
EVT_HIDE_UI = false

EVT = {}

-- 2.000 Added for localization
EVT.lang = {}

EVT.name             = "EventTracker"
EVT.version          = string.format("%s",Latest_Version)
EVT.variable_version = 2                 -- Never change this number - it will remove all existing settings and data

-- 1.30 StorybookTerror found the function for Total_Tickets; no need anymore to start with -1 = Unknown!
EVT.default = {
	EVT_version    = Latest_Version,
	debug          = false,        -- Whether or not to show debug output
	Install_Time = GetTimeStamp(),
	Message_Time = GetTimeStamp(),
-- 2.400 Replace CURT_EVENT_TICKETS with CURT_TRADE_BARS
	Total_Tickets  = GetCurrencyAmount(CURT_TRADE_BARS, CURRENCY_LOCATION_ACCOUNT),

-- EVENTUPDATE
	Current_Event  = "None",
	T_Types   = {
		[1] = "First",
		[2] = "Second",
		[3] = "Boss",
		},
	T_Time   = {0,0,0,},
	T_ToDo = {0,0,0,},
	T_Tickets = {0,0,0,0,},

-- 1.01 Added to be able to tell what to do if # of tickets changes
--      other than earning or spending them.
	LastUpdated = GetTimeStamp(),

	left = 450,
	top = 10,
	HideUI = false,
-- autoHide is actually a "minimize chat output".
	autoHide = false,

-- 1.50 Added NEWS! Because it's really useful info but I just don't want to inundate people with it all at once.
-- Set this to zero when there's nothing important to impart. Otherwise, number of news messages, and count down.
-- Set news messages in language file.
-- EVENTUPDATE
	NewsIndex = 0,
-- 1.65 Added skulls for Witches; remove after event
--	Skulls_Done = EVT_SKULLS_DONE,
}


EVT.defaultSettings = {
-- 1.65 Added auto xp buff
	XP_refresh = 200, -- Automatically refresh xp buff when minutes remaining drop below this number
	XP_frequency = 5, -- If XP buff attempt didn't work, how soon to re-try (min)
	InfoBox = 0, -- 2.390
}

-- 2.400 Function EVT.ReticleHook was here

----------------------------------------
-- ToggleDebug
-- Toggles whether or not to print debug output to chat
----------------------------------------
function EVT.ToggleDebug(set)
	EVT.vars.debug = set
--	CHAT_ROUTER:AddSystemMessage("[EVT]: Debug set to " .. tostring(EVT.vars.debug))
	if EVT.vars.debug then
		CHAT_ROUTER:AddSystemMessage("[EVT]: Debug messages ON.")
	else
		CHAT_ROUTER:AddSystemMessage("[EVT]: Debug messages OFF.")
	end
end


----------------------------------------
-- ToggleAutoHide - Changed from an actual toggle, to a straight setting: "hide" or "show".
----------------------------------------
function EVT.ToggleAutoHide(set)
	EVT.vars.autoHide = set
	if EVT.vars.autoHide then
		CHAT_ROUTER:AddSystemMessage("[EVT]: Chat messages hidden, except the most important ones.")
	else
		CHAT_ROUTER:AddSystemMessage("[EVT]: All chat messages will show.")
	end
end


----------------------------------------
-- Show info about the event
----------------------------------------
function EVT.EventInfo(SendToChat,WhichEvent)
	local PrevReset, Hrs, Mins, EvtDays, EvtHrs = EVT.DailyReset()
	local ShowStartDate, ShowStartTime = FormatAchievementLinkTimestamp(EVT_EVENT_START)

	local EVT_Event_Info = {
		["Upcoming"] = EVT_UPCOMING_INFO,
--		["Future_Dates"] = GetString(EVT_EVENT_INFO_FUTURE_DATES),

		["None"] = GetString(EVT_EVENT_INFO_NONE),
		["Unknown"] = GetString(EVT_EVENT_INFO_UNKNOWN),

		["Boss"] = GetString(EVT_EVENT_INFO_BOSS),

-- 1.95 Added news (server specific)
		["News-NA"] = GetString(EVT_EVENT_INFO_NEWS_NA),
		["News-EU"] = GetString(EVT_EVENT_INFO_NEWS_EU),
		["News-PTS"] = GetString(EVT_EVENT_INFO_NEWS_PTS),

-- 1.52 Added imp (Impresario), pet (Pet, for the Unstable Morpholith), and morph (Morph, about morphing the pet)
		["Impresario"] = GetString(EVT_EVENT_INFO_TICKETS) .. " |H1:help:342|h[EVENT TICKETS]|h " .. GetString(EVT_EVENT_INFO_IMPRESARIO) .. " |H1:help:341|h[IMPRESARIO]|h ",
-- 1.78 Updated Unstable Morpholith and its morphs to Soulfire Dragon Illusion and ITS morphs. Added Indrik info and High Isle
-- 2024 Molag Bal Illusion Imp |H1:help:524|h|h Morphs |H1:help:525|h|h
		["Pet"] = GetString(EVT_EVENT_INFO_PET) .. " |H1:help:495|h|h ",	-- was 436 and 437 in 2021, then 467 and 468 in 2022
		["Morph"] = GetString(EVT_EVENT_INFO_MORPH) .. " |H1:help:496|h|h ",
		["Indrik"] = GetString(EVT_EVENT_INFO_INDRIK),
--		["Indrik"] = GetString(EVT_EVENT_INFO_INDRIK) .. " |H1:help:348|h|h " .. GetString(EVT_EVENT_INFO_INDRIK_MORPH) .. " |H1:help:349|h|h",
		["Indrik Cycle"] = GetString(EVT_EVENT_INFO_INDRIK_CYCLE_1) .. " |H1:help:348|h|h " .. GetString(EVT_EVENT_INFO_INDRIK_CYCLE_2),

-- 1.62 Added
		["Xpbuff"] = GetString(EVT_XPBUFF),

-- 1.46 activate box and add "Begin" -- 1.50 Can't use GetString because it must be changed dynamically. Darn.
		["Box"] = EVT_EVENT_INFO_BOX,
		["Begin"] = EVT_EVENT_INFO_BEGIN,

-- 1.53 Added Year One and Pan-Elsweyr -- 1.54 Added Blackwood ("Bounties of Blackwood"); Mid-Year Mayhem renamed to Whitestrake
		["Anniversary"] = GetString(EVT_EVENT_INFO_ANNIVERSARY) .. " |H1:help:368|h|h",	-- once per day, per account
		["Jester's Festival"] = GetString(EVT_EVENT_INFO_JESTER) .. " |H1:help:367|h|h",	-- Once a day per account
		["Whitestrake's Mayhem"] = GetString(EVT_EVENT_INFO_WHITESTRAKE) .. " |H1:help:356|h|h",	-- doesn't say "per account"
		["New Life"] = GetString(EVT_EVENT_INFO_NEW_LIFE) .. " |H1:help:355|h|h",	-- once a day per account
		["Undaunted"] = GetString(EVT_EVENT_INFO_UNDAUNTED) .. " |H1:help:354|h|h",	-- Once per day, per account
		["Witches"] = GetString(EVT_EVENT_INFO_WITCHES) .. " |H1:help:345|h|h",	-- per day per account
		["Zeal of Zenithar"] = GetString(EVT_EVENT_INFO_ZEAL_OF_ZENITHAR) .. " |H1:help:474|h|h",	-- 1.77 added

-- Special events
-- ALSO FIX AROUND LINE 1000
-- 2.240 New events
		["High Seas"] = GetString(EVT_EVENT_INFO_HIGH_SEAS) .. " |H1:help:636|h|h",	-- 2.430 added "High Seas"

-- 2.240 New events
		["Heart's Week"] = GetString(EVT_EVENT_INFO_HEARTS_WEEK) .. " |H1:help:603|h|h",	-- 2.350 added "Heart's Week"

-- 2.240 New events
		["Pan-Tamriel"] = GetString(EVT_EVENT_INFO_PAN_TAMRIEL) .. " |H1:help:579|h|h",	-- 2.240 added "Pan-Tamriel Celebration"
		["Bretons"] = GetString(EVT_EVENT_INFO_BRETONS),	-- .. " |H1:help:578|h|h",	-- 2.240 added "Legacy of the Bretons"
		["West Weald"] = GetString(EVT_EVENT_INFO_WEST_WEALD),	-- .. " |H1:help:576|h|h",	-- 2.240 added "Fallen Leaves of the West Weald"
		["Guilds & Glory"] = GetString(EVT_EVENT_INFO_GUILDS),	-- .. " |H1:help:526|h|h",	-- 2.020 added "Guilds and Glory Celebration"

-- 2.220 Deprecated help files
		["Telvanni"] = GetString(EVT_EVENT_INFO_TELVANNI),	-- .. " |H1:help:523|h|h",	-- 2.000 added "Secrets of the Telvanni"
		["Oblivion"] = GetString(EVT_EVENT_INFO_OBLIVION),	-- .. " |H1:help:527|h|h",	-- 2.020 added "Gates of Oblivion Celebration"

-- 2.000 All help files removed from PTS except Zenithar and Telvanni
		["Daedric War"] = GetString(EVT_EVENT_INFO_DAEDRIC_WAR), -- .. " |H1:help:466|h|h",	-- 1.65 added; 2.350 re-added

-- 1.83 Season of the Dragon -- 1.87
		["Dragon"] = GetString(EVT_EVENT_INFO_DRAGON),		-- .. " |H1:help:499|h[Season of the Dragon]|h ",	-- Help file still not available as of 1.83, but decided to put it in anyway

-- 1.81 Added High Isle and Skyrim -- 1.87
		["High Isle"] = GetString(EVT_EVENT_INFO_HIGH_ISLE),	-- .. " |H1:help:493|h|h",
		["Skyrim"] = GetString(EVT_EVENT_INFO_SKYRIM),		-- .. " |H1:help:500|h|h",	-- Help file still not available as of 1.83, but decided to put it in anyway

-- 1.64 Deprecated - help files removed from the game.
		["Blackwood"] = GetString(EVT_EVENT_INFO_BLACKWOOD),	-- .. " |H1:help:461|h|h",	-- 1.64 added; 1.81 help file gone
		["Pan-Elsweyr"] = GetString(EVT_EVENT_INFO_PAN_ELSWEYR),	-- .. " |H1:help:446|h|h",	-- 1.64 added; 1.81 help file gone
		["Year One"] = GetString(EVT_EVENT_INFO_YEAR_ONE),	-- .. " |H1:help:455|h|h",	-- 1.64 added; 1.81 help file gone
		["Clockwork City"] = GetString(EVT_EVENT_INFO_CLOCKWORK),		-- .. " |H1:help:353|h|h",
		["Crime Pays"] = GetString(EVT_EVENT_INFO_CRIME_PAYS),		-- .. " |H1:help:358|h|h" .. " |H1:help:359|h|h",
		["Imperial City"] = GetString(EVT_EVENT_INFO_IMPERIAL_CITY),	-- .. " |H1:help:388|h|h",
		["Lost Treasures"] = GetString(EVT_EVENT_INFO_LOST_TREASURES),	-- .. " |H1:help:418|h|h",
		["Morrowind"] = GetString(EVT_EVENT_INFO_MORROWIND),		-- .. " |H1:help:357|h|h",
		["Murkmire"] = GetString(EVT_EVENT_INFO_MURKMIRE),		-- .. " |H1:help:390|h|h",
		["Summerset"] = GetString(EVT_EVENT_INFO_SUMMERSET),		-- .. " |H1:help:404|h|h",
		["Tribunal"] = GetString(EVT_EVENT_INFO_TRIBUNAL),		-- .. " |H1:help:438|h|h",
		["Wrothgar"] = GetString(EVT_EVENT_INFO_WROTHGAR),		-- .. " |H1:help:382|h|h",

-- These already had been, before I had added links.
--		["Dragon Rise"] = GetString(EVT_EVENT_INFO_DRAGON_RISE),
--		["Dragonguard"] = GetString(EVT_EVENT_INFO_DRAGONGUARD),
	}

--[[ 2.240 New events
	if GetAPIVersion() < 101048 then
		EVT_Event_Info["Bretons"] = GetString(EVT_EVENT_INFO_BRETONS) .. " |H1:help:578|h|h"	-- 2.240 added "Legacy of the Bretons"
		EVT_Event_Info["Heart's Week"] = GetString(EVT_EVENT_INFO_HEARTS_WEEK)	-- .. " |H1:help:603|h|h",	-- 2.350 added "Heart's Week"
	end
]]

--[[ 2.220
	if GetAPIVersion() == 101039 then
		EVT_Event_Info["Oblivion"] = GetString(EVT_EVENT_INFO_OBLIVION)	-- 2.020 added "Gates of Oblivion Celebration"
		EVT_Event_Info["Guilds & Glory"] = GetString(EVT_EVENT_INFO_GUILDS)	-- 2.020 added "Guilds and Glory Celebration"
	end
]]

-- 1.94 Added PTS info
	if GetWorldName() == "PTS" then
		EVT_Event_Info["Anniversary"] = GetString(EVT_PTS_INFO_ANNIVERSARY) .. " |H1:help:368|h|h"
		EVT_Event_Info["Jester's Festival"] = GetString(EVT_PTS_INFO_JESTER) .. " |H1:help:367|h|h"
		EVT_Event_Info["Witches"] = GetString(EVT_PTS_INFO_WITCHES) .. " |H1:help:345|h|h"
	end

-- 1.34
	local Details = " "
-- 1.40 Add options for viewing info for any event that has info
	if WhichEvent ~= nil then
		if EVT_Event_Info[WhichEvent] ~= nil then
			Details = EVT_Event_Info[WhichEvent]
			if Details ~= " " and WhichEvent ~= "Box" and WhichEvent ~= "Begin" and WhichEvent ~= "Upcoming" then
				Details = WhichEvent .. ": " .. Details
			end
		end
--		EVT.PrintDebug("Event (SPECIFIED): " .. WhichEvent .. "Info: " .. Details)

-- 2.110 LIBRARY (2 lines)
-- 2.200	else
-- 2.200		Details = EVT_CURRENT_INFO
-- 2.200 commented out: start
	elseif EVT.vars.Current_Event == "None" then
		if EVT_Event_Info[EVT_NEXT_EVENT] ~= nil then
			Details = EVT_Event_Info[EVT_NEXT_EVENT]
		end
		EVT.PrintDebug("Event (Next): " .. EVT_NEXT_EVENT .. "Info: " .. Details)
	else
		if EVT_Event_Info[EVT.vars.Current_Event] ~= nil then
			Details = EVT_Event_Info[EVT.vars.Current_Event]
		end
--		EVT.PrintDebug("Event (Current): " .. EVT.vars.Current_Event .. "Info: " .. Details)
-- 2.200 commented out: end
	end

-- 1.40 Add options for viewing info for any event that has info
	if WhichEvent ~= nil then
		if Details == " " then
			CHAT_ROUTER:AddSystemMessage("Sorry, no details have been entered yet for " .. WhichEvent)
		elseif SendToChat then
			StartChatInput(Details .. " (Event Tracker addon)")
		else
			CHAT_ROUTER:AddSystemMessage(Details)
		end

-- 1.30 If Unknown, there is no info, and chat function is disabled.
-- 1.34 If event start or end date is not known, same.
-- 1.57 Deal with unknown start/end dates.
	elseif EVT.vars.Current_Event == "Unknown" then
-- or EVT_EVENT_START == EVT_DATE_UNKNOWN or EVT_EVENT_END == EVT_DATE_UNKNOWN then
		CHAT_ROUTER:AddSystemMessage("This version of Event Tracker has no detailed information for the current event. There may be an update available.")
	elseif not SendToChat then
		if EVT.vars.Current_Event == "None" then
-- 1.57 Deal with unknown start date; removed " Event starts %s at %s,",ShowStartDate, ShowStartTime)
--  and added " Event starts" to beginning of " Event starts in ..."
			if EVT_EVENT_START == EVT_DATE_UNKNOWN then EvtDays = 999 end
--			if EvtDays > 30 then
			if EvtDays > 1 and EVT_EVENT_START ~= EVT_DATE_UNKNOWN then
				CHAT_ROUTER:AddSystemMessage(string.format("%s Event starts in %s days, %s hr, %s min.",EVT_NEXT_EVENT,EvtDays,EvtHrs,Mins))
			elseif EvtDays > 0 and EVT_EVENT_START ~= EVT_DATE_UNKNOWN then
				CHAT_ROUTER:AddSystemMessage(string.format("%s Event starts in %s day, %s hr, %s min.",EVT_NEXT_EVENT,EvtDays,EvtHrs,Mins))
			elseif EvtHrs < 1 then
-- 1.96 Fixed a missing param bug I'd never seen because it only triggers when using /evti less than an hour before an event
				CHAT_ROUTER:AddSystemMessage(string.format("%s Event starts in %s MINUTES!",EVT_NEXT_EVENT,Mins))
			elseif EvtHrs < 2 then
				CHAT_ROUTER:AddSystemMessage(string.format("%s Event starts in %s hr, %s min!",EVT_NEXT_EVENT,EvtHrs,Mins))
			elseif EVT_EVENT_START ~= EVT_DATE_UNKNOWN then
				CHAT_ROUTER:AddSystemMessage(string.format("%s Event starts in %s hr, %s min.",EVT_NEXT_EVENT,EvtHrs,Mins))
			end

-- 1.34
			if Details ~= " " then
				CHAT_ROUTER:AddSystemMessage(Details)
			end

--			EVT.PrintDebug(string.format("Minutes until next event: %s",(EVT_EVENT_START-EVT.FindCurrentTime())/60))

-- 1.57 Cover the case of not knowing when the event ends
		elseif EVT_EVENT_END == EVT_DATE_UNKNOWN then
			CHAT_ROUTER:AddSystemMessage("End date is unknown. " .. Details)
		else
-- 1.57 Just Event name and Details, as date is now redundant.
--			CHAT_ROUTER:AddSystemMessage(string.format("%s Event runs until %s %s. ",EVT.vars.Current_Event,FormatAchievementLinkTimestamp(EVT_EVENT_END)) .. Details)
			CHAT_ROUTER:AddSystemMessage(string.format("%s Event: ",EVT.vars.Current_Event) .. Details)

-- 1.03 Wasn't calculating remaining tickets correctly on final day.
-- 1.31 Still not		if EvtDays < 1 or EvtHrs < Hrs then
			DaysRemaining = EvtDays
			if EvtHrs > Hrs then
				DaysRemaining = EvtDays + 1
			end
--			EVT.PrintDebug("Trade Bar reset: " .. string.format("%s hours, %s minutes. Event end %s days, %s hours. Days Remaining: %s",Hrs,Mins,EvtDays,EvtHrs,DaysRemaining))

--			local TicketsPerDay = EVT.vars.T_Tickets[1] + EVT.vars.T_Tickets[2] + EVT.vars.T_Tickets[3]
-- 1.54 LOCKED TICKETS  Event ends in h hours, m min. Total remaining: 0. (14 from Elsweyr DLC; 14 from Dragonhold DLC.)
			local MinTicketsRem = 0
			local MaxTicketsRem = 0
			local LockedTickets = "."
			if EVT.vars.T_ToDo[1] < 0 and EVT_DLC_UNLOCKED[1] then
				MinTicketsRem = EVT.vars.T_Tickets[1] * DaysRemaining
				MaxTicketsRem = EVT.vars.T_Tickets[1] * (DaysRemaining + 1)
			elseif EVT_DLC_UNLOCKED[1] then
				MinTicketsRem = EVT.vars.T_Tickets[1] * (DaysRemaining + EVT.vars.T_ToDo[1])
				MaxTicketsRem = EVT.vars.T_Tickets[1] * (DaysRemaining + EVT.vars.T_ToDo[1])
			else
				if EVT_DLC_UNLOCKED[2] and EVT_DLC_UNLOCKED[3] then
					LockedTickets = string.format(". (%s from %s.)",EVT.vars.T_Tickets[1] * (DaysRemaining + 1),DLC_Names[1])
				else
					LockedTickets = string.format(". (%s from %s; ",EVT.vars.T_Tickets[1] * (DaysRemaining + 1),DLC_Names[1])
				end
			end
			if EVT.vars.T_ToDo[2] < 0 and EVT_DLC_UNLOCKED[2] then
				MinTicketsRem = MinTicketsRem + EVT.vars.T_Tickets[2] * DaysRemaining
				MaxTicketsRem = MaxTicketsRem + EVT.vars.T_Tickets[2] * (DaysRemaining + 1)
			elseif EVT_DLC_UNLOCKED[2] then
				MinTicketsRem = MinTicketsRem + EVT.vars.T_Tickets[2] * (DaysRemaining + EVT.vars.T_ToDo[2])
				MaxTicketsRem = MaxTicketsRem + EVT.vars.T_Tickets[2] * (DaysRemaining + EVT.vars.T_ToDo[2])
			else
				if EVT_DLC_UNLOCKED[3] then
					LockedTickets = string.format(". (%s from %s.)",EVT.vars.T_Tickets[2] * (DaysRemaining + 1),DLC_Names[2])
				else
					LockedTickets = string.format(". (%s from %s; ",EVT.vars.T_Tickets[2] * (DaysRemaining + 1),DLC_Names[2])
				end
			end

			if EVT.vars.T_ToDo[3] < 0 and EVT_DLC_UNLOCKED[3] then
				MinTicketsRem = MinTicketsRem + EVT.vars.T_Tickets[3] * DaysRemaining
				MaxTicketsRem = MaxTicketsRem + EVT.vars.T_Tickets[3] * (DaysRemaining + 1)
			elseif EVT_DLC_UNLOCKED[3] then
				MinTicketsRem = MinTicketsRem + EVT.vars.T_Tickets[3] * (DaysRemaining + EVT.vars.T_ToDo[3])
				MaxTicketsRem = MaxTicketsRem + EVT.vars.T_Tickets[3] * (DaysRemaining + EVT.vars.T_ToDo[3])
			else
				LockedTickets = string.format(". (%s from %s.)",EVT.vars.T_Tickets[3] * (DaysRemaining + 1),DLC_Names[3])
			end

			if EvtDays > 1 then
				if MinTicketsRem == MaxTicketsRem then
					CHAT_ROUTER:AddSystemMessage(string.format("Event ends in %s days, %s hrs, %s min. Total remaining: %s%s",EvtDays,EvtHrs,Mins,MaxTicketsRem,LockedTickets))
				else
					CHAT_ROUTER:AddSystemMessage(string.format("Event ends in %s days, %s hrs, %s min. Total remaining: %s-%s%s",EvtDays,EvtHrs,Mins,MinTicketsRem,MaxTicketsRem,LockedTickets))
				end
			elseif EvtDays > 0 then
				if MinTicketsRem == MaxTicketsRem then
					CHAT_ROUTER:AddSystemMessage(string.format("Event ends in %s day, %s hrs, %s min. Total remaining: %s%s",EvtDays,EvtHrs,Mins,MaxTicketsRem,LockedTickets))
				else
					CHAT_ROUTER:AddSystemMessage(string.format("Event ends in %s day, %s hrs, %s min. Total remaining: %s-%s%s",EvtDays,EvtHrs,Mins,MinTicketsRem,MaxTicketsRem,LockedTickets))
				end
			elseif EvtHrs < 1 then
				if MinTicketsRem == MaxTicketsRem then
					CHAT_ROUTER:AddSystemMessage(string.format("|cFF0000Event ends in %s MIN.!|r Total remaining: %s%s",Mins,MaxTicketsRem,LockedTickets))
				else
					CHAT_ROUTER:AddSystemMessage(string.format("|cFF0000Event ends in %s MIN.!|r Total remaining: %s-%s%s",Mins,MinTicketsRem,MaxTicketsRem,LockedTickets))
				end
			elseif EvtHrs < 2 then
				if MinTicketsRem == MaxTicketsRem then
					CHAT_ROUTER:AddSystemMessage(string.format("|cFF0000Event ends in %s hr, %s min.!|r Total remaining: %s%s",EvtHrs,Mins,MaxTicketsRem,LockedTickets))
				else
					CHAT_ROUTER:AddSystemMessage(string.format("|cFF0000Event ends in %s hr, %s min.!|r Total remaining: %s-%s%s",EvtHrs,Mins,MinTicketsRem,MaxTicketsRem,LockedTickets))
				end
			else
				if MinTicketsRem == MaxTicketsRem then
					CHAT_ROUTER:AddSystemMessage(string.format("Event ends in %s hrs, %s min. Total remaining: %s%s",EvtHrs,Mins,MaxTicketsRem,LockedTickets))
				else
					CHAT_ROUTER:AddSystemMessage(string.format("Event ends in %s hrs, %s min. Total remaining: %s-%s%s",EvtHrs,Mins,MinTicketsRem,MaxTicketsRem,LockedTickets))
				end
			end
		end
	elseif SendToChat then

-- 1.57 Moved this here; removed (and EVT.vars.Current_Event ~= "Unknown") from above
		if Details == " " then
			CHAT_ROUTER:AddSystemMessage("Chat function disabled when no information is available.")
-- 1.38 Added (Event Tracker) at end for chat output
		elseif EVT.vars.Current_Event == "None" then

-- 1.35 Changed to actual dates unknown
-- 1.57 Deal with unknown start date; removed " Event starts %s",ShowStartDate
--  and added " Event starts" to beginning of " Event starts in ..."
			if EVT_EVENT_START == EVT_DATE_UNKNOWN then
				StartChatInput(Details .. " (Event Tracker addon)")
			elseif EvtDays > 1 then
				StartChatInput(string.format("%s Event starts in %s days, %s hrs, %s min. ",EVT_NEXT_EVENT,EvtDays,EvtHrs,Mins) .. Details .. " (Event Tracker addon)")
			elseif EvtDays > 0 then
				StartChatInput(string.format("%s Event starts in %s day, %s hrs, %s min. ",EVT_NEXT_EVENT,EvtDays,EvtHrs,Mins) .. Details .. " (Event Tracker addon)")
			elseif EvtHrs < 1 then
				StartChatInput(string.format("%s Event starts in %s MIN.! ",EVT_NEXT_EVENT,Mins) .. Details .. " (Event Tracker addon)")
			elseif EvtHrs < 2 then
				StartChatInput(string.format("%s Event starts in %s hr, %s min.! ",EVT_NEXT_EVENT,EvtHrs,Mins) .. Details .. " (Event Tracker addon)")
			else
				StartChatInput(string.format("%s Event starts in %s hrs, %s min. ",EVT_NEXT_EVENT,EvtHrs,Mins) .. Details .. " (Event Tracker addon)")
			end
-- 1.66 Cover the case of not knowing when the event ends
		elseif EVT_EVENT_END == EVT_DATE_UNKNOWN then
			StartChatInput(Details .. " (Event Tracker addon)")
		else
-- 1.31 Still not		if EvtDays < 1 or EvtHrs < Hrs then
			DaysRemaining = EvtDays
			if EvtHrs > Hrs then
				DaysRemaining = EvtDays + 1
			end

			local TicketsPerDay = EVT.vars.T_Tickets[1] + EVT.vars.T_Tickets[2] + EVT.vars.T_Tickets[3]
			local MinTicketsRem = EVT.vars.T_Tickets[1] * DaysRemaining
			local MinTicketsRem = MinTicketsRem + EVT.vars.T_Tickets[2] * DaysRemaining
			local MinTicketsRem = MinTicketsRem + EVT.vars.T_Tickets[3] * DaysRemaining
			local MaxTicketsRem = EVT.vars.T_Tickets[1] * (DaysRemaining + 1)
			local MaxTicketsRem = MaxTicketsRem + EVT.vars.T_Tickets[2] * (DaysRemaining + 1)
			local MaxTicketsRem = MaxTicketsRem + EVT.vars.T_Tickets[3] * (DaysRemaining + 1)
--			CHAT_ROUTER:AddSystemMessage(string.format("%s event tickets available per day. %s-%s total remaining.",TicketsPerDay,MinTicketsRem,MaxTicketsRem))
			local TmpEndDay, TmpEndHour = FormatAchievementLinkTimestamp(EVT_EVENT_END)

			if EvtDays > 1 then
				StartChatInput(Details .. string.format(" %s-%s total remaining.",MinTicketsRem,MaxTicketsRem) .. " (Event Tracker addon)")
			elseif EvtDays > 0 then
				StartChatInput(string.format("Ends in %s day, %s hrs, %s min. ",EvtDays,EvtHrs,Mins) .. Details .. string.format(" %s-%s total remaining.",MinTicketsRem,MaxTicketsRem) .. " (Event Tracker addon)")
			elseif EvtHrs < 1 then
				StartChatInput(string.format("Ends in %s MIN! ",Mins) .. Details .. " (Event Tracker addon)")
			elseif EvtHrs < 2 then
				StartChatInput(string.format("Ends in %s hr, %s min! ",EvtHrs,Mins) .. Details .. " (Event Tracker addon)")
			else
				StartChatInput(string.format("Ends in %s hrs, %s min. ",EvtHrs,Mins) .. Details .. string.format(" %s-%s total remaining.",MinTicketsRem,MaxTicketsRem) .. " (Event Tracker addon)")
			end
		end
	end
end

-- 1.88 Added check for unlock
function EVT.TicketsDone(keyWord)
	if string.lower(keyWord) == "done" and EVT.vars.T_Types[2]~="not used" and EVT_DLC_UNLOCKED[1] and EVT_DLC_UNLOCKED[2] then
		CHAT_ROUTER:AddSystemMessage("|cFFD700/evt done1|r |cFFFFFF" .. EVT.vars.T_Types[1])
		CHAT_ROUTER:AddSystemMessage("|cFFD700/evt done2|r |cFFFFFF" .. EVT.vars.T_Types[2])
	end

	local which_ticket = 0
	if (string.lower(keyWord) == "done" and EVT_DLC_UNLOCKED[1]) or string.lower(keyWord) == "done1" then
		which_ticket = 1
		if EVT.vars.T_ToDo[which_ticket] > 0 then
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |cFF00CC<<1[/One trade bar/$d trade bars]>> collected from <<2>>!|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
			EVT.vars.T_Time[which_ticket] = EVT.FindCurrentTime()
			EVT.vars.T_ToDo[which_ticket] = 0
		else
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |c00CCFF<<1[/One trade bar/$d trade bars]>> already collected from <<2>>. No change.|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
		end
	end

	if EVT.vars.T_Tickets[2]>0 and ((string.lower(keyWord) == "done" and EVT_DLC_UNLOCKED[2]) or string.lower(keyWord) == "done2") then
		which_ticket = 2
		if EVT.vars.T_ToDo[which_ticket] > 0 then
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |cFF00CC<<1[/One trade bar/$d trade bars]>> collected from <<2>>!|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
			EVT.vars.T_Time[which_ticket] = EVT.FindCurrentTime()
			EVT.vars.T_ToDo[which_ticket] = 0
		else
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |c00CCFF<<1[/One trade bar/$d trade bars]>> already collected from <<2>>. No change.|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
		end
	end
	CHAT_ROUTER:AddSystemMessage("|cFFD700/evt undo|r |cFFFFFFto reverse this.|r")
	EVT.ShowVars("UI")
end

function EVT.TicketsUndo(keyWord)
	if string.lower(keyWord) == "undo" and EVT.vars.T_Types[2]~="not used" and EVT_DLC_UNLOCKED[1] and EVT_DLC_UNLOCKED[2] then
		CHAT_ROUTER:AddSystemMessage("|cFFD700/evt undo1|r |cFFFFFF" .. EVT.vars.T_Types[1])
		CHAT_ROUTER:AddSystemMessage("|cFFD700/evt undo2|r |cFFFFFF" .. EVT.vars.T_Types[2])
	end

	local which_ticket = 0
	if (string.lower(keyWord) == "undo" and EVT_DLC_UNLOCKED[1]) or string.lower(keyWord) == "undo1" then
		which_ticket = 1
		if EVT.vars.T_ToDo[which_ticket] == 0 then
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |cFF00CC<<1[/One trade bar/$d trade bars]>> REMOVED from <<2>>!|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
			EVT.vars.T_Time[which_ticket] = EVT.FindCurrentTime() - EVT_ONE_DAY
			EVT.vars.T_ToDo[which_ticket] = EVT.vars.T_Tickets[which_ticket]
		else
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |cFFFFFFNo change to <<2>> <<1[/trade bar/trade bars]>>.|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
		end
	end

	if EVT.vars.T_Tickets[2]>0 and ((string.lower(keyWord) == "undo" and EVT_DLC_UNLOCKED[2]) or string.lower(keyWord) == "undo2") then
		which_ticket = 2
		if EVT.vars.T_ToDo[which_ticket] == 0 then
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |cFF00CC<<1[/One trade bar/$d trade bars]>> REMOVED from <<2>>!|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
			EVT.vars.T_Time[which_ticket] = EVT.FindCurrentTime() - EVT_ONE_DAY
			EVT.vars.T_ToDo[which_ticket] = EVT.vars.T_Tickets[which_ticket]
		else
			CHAT_ROUTER:AddSystemMessage(zo_strformat("[EVT]: |cFFFFFFNo change to <<2>> <<1[/trade bar/trade bars]>>.|r",EVT.vars.T_Tickets[which_ticket],EVT.vars.T_Types[which_ticket]))
		end
	end
	EVT.ShowVars("UI")
end

-- Called with "/evt csb" undocumented command, for testing/info.
-- 154 Imperial City
-- 215 Orsinium
-- 254 Thieves Guild
-- 306 Dark Brotherhood
-- 593 Morrowind
-- 1240 Clockwork City
-- 5107 Summerset
-- 5755 Murkmire
-- 5843 Elsweyr
-- 6920 Dragonhold
-- 7466 Greymoor
-- 8388 Markarth
-- 8659 Blackwood
-- 9365 The Deadlands
-- 10053 High Isle

-- GetCollectibleUnlockStateByID results: 1 for unlocked by ESO+ membership; 2 for having purchased it. Probably 0 for locked.
--[[local function DisplayCollectibleIDs()
    local name, _, numCollectibles, unlockedCollectibles, _, _, collectibleCategoryType = GetCollectibleCategoryInfo(COLLECTIBLE_CATEGORY_TYPE_DLC)
	for i=0, 20000 do
		local collectibleId = GetCollectibleId(COLLECTIBLE_CATEGORY_TYPE_DLC, nil, i)
		local collectibleName, _, _, _, unlocked = GetCollectibleInfo(i) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
		if collectibleName == "Imperial City" or collectibleName == "Greymoor" or collectibleName == "Orsinium" or collectibleName == "Markarth" or collectibleName == "Murkmire" then
			CHAT_ROUTER:AddSystemMessage("DLC: " .. i .. " " .. collectibleName.. " unlocked (from GetCollectibleInfo): " .. tostring(unlocked) .. " unlocked (from GetCollectibleUnlockStateByID): " .. tostring(GetCollectibleUnlockStateById(i)))
		end
	end
--	CHAT_ROUTER:AddSystemMessage(string.format("All should be unlocked (but no event) - Max Available Today: %s",EVT.MaxAvailableToday()))
--	local All_Locked = not ((EVT_DLC_UNLOCKED[1] and EVT.vars.T_Tickets[1]>0) or (EVT_DLC_UNLOCKED[2] and EVT.vars.T_Tickets[2]>0) or (EVT_DLC_UNLOCKED[3] and EVT.vars.T_Tickets[3]>0))
--	CHAT_ROUTER:AddSystemMessage(string.format("Unlocked 1: %s, 2: %s, 3: %s, All_Locked: %s",tostring(EVT_DLC_UNLOCKED[1]),tostring(EVT_DLC_UNLOCKED[2]),tostring(EVT_DLC_UNLOCKED[3]),tostring(All_Locked)))
end
]]

-- 1.98 Added to show collectible status when "/evt" has been used with no parameters and there are >9 tickets. Might also add "/evt col" to show collectibles.
local function ShowCollectibles()
-- 1.98
--	local collectibleName, _, _, _, DLC_unlocked = GetCollectibleInfo(10053) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
--	EVT.PrintDebug("DLC: " .. dlc_ID .. " " .. collectibleName .. " unlocked: " .. tostring(DLC_unlocked))
	local Fragment1 = false
	local Fragment2 = false
	local Fragment3 = false
	local Fragment4 = false
	local Fragment5 = false

	local function ShowCollectibleBase(BaseName,BaseType,BaseNum,FragName1,FragNum1,FragName2,FragNum2,FragName3,FragNum3,FragName4,FragNum4,FragsAvailable,FragsTotal,NewOrOld)
		local HaveBase = EVT.IsItUnlocked(BaseType,BaseNum,BaseName)
		local NumFrags = 0
		local StillNeed = ""

		if FragsAvailable > 0 then
			Fragment1 = EVT.IsItUnlocked("Fragment",FragNum1,FragName1)
			if Fragment1 then NumFrags = 1 else StillNeed = FragName1 end
		end

		if FragsAvailable > 1 then
			Fragment2 = EVT.IsItUnlocked("Fragment",FragNum2,FragName2)
-- 2.060			if Fragment2 then NumFrags = NumFrags + 1 elseif Fragment1 then StillNeed = FragName2 else StillNeed = string.format("%s & %s",StillNeed,FragName2) end
			if Fragment2 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName2 else StillNeed = string.format("%s & %s",StillNeed,FragName2) end
		end

		if FragsAvailable > 2 then
			Fragment3 = EVT.IsItUnlocked("Fragment",FragNum3,FragName3)
-- 2.060			if Fragment3 then NumFrags = NumFrags + 1 elseif Fragment1 or Fragment2 then StillNeed = FragName3 else StillNeed = string.format("%s & %s",StillNeed,FragName3) end
			if Fragment3 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName3 else StillNeed = string.format("%s & %s",StillNeed,FragName3) end
		end

		if FragsAvailable > 3 then
			Fragment4 = EVT.IsItUnlocked("Fragment",FragNum4,FragName4)
-- 2.060			if Fragment4 then NumFrags = NumFrags + 1 elseif Fragment1 or Fragment2 or Fragment3 then StillNeed = FragName4 else StillNeed = string.format("%s & %s",StillNeed,FragName4) end
			if Fragment4 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName4 else StillNeed = string.format("%s & %s",StillNeed,FragName4) end
		end

-- 2.000 Output only for new collectibles
		if NewOrOld == "new" then
-- 1.981
			if not HaveBase and NumFrags == 0 then
				CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s: NO %s, ZERO fragments.",BaseName,BaseType))
-- 1.981
			elseif HaveBase and NumFrags == 0 then 
				CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s: COLLECTED. Fragments for a second %s: |cFFFFFFZERO.",BaseName,BaseType))
			elseif HaveBase and NumFrags == 3 then 
				CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s: COLLECTED. Also enough fragments for a second %s.",BaseName,BaseType))
			else
				local secondBase = "a"
				if HaveBase then
					CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s %s: COLLECTED.",BaseName,BaseType))
					secondBase = "a second"
				end
				if NumFrags > 2 then
					CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s: You could make %s %s.",BaseName,secondBase,BaseType))
				end
				if NumFrags ~= 3 then
					if NumFrags > 3 then NumFrags = NumFrags - 3 end
					CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CC%s PARTIAL: |cFFFFFFYou have %d fragments of %d needed to make %s %s.",BaseName,NumFrags,FragsTotal,secondBase,BaseType))
					if EVT.vars.Current_Event ~= "None" then
						CHAT_ROUTER:AddSystemMessage(zo_strformat("|cFFFFFFFragment<<1[/s]>> still needed: <<2%s>>",NumFrags,StillNeed))
					end
				end
			end
		end

		if NumFrags>=FragsTotal then
			HaveBase = true
			NumFrags = NumFrags-FragsTotal
		end
		return HaveBase,NumFrags,StillNeed	-- For old collectibles, if there are enough fragments to make the thing, count it as done.
	end

	local function ShowCollectibleMorph(MorphName,MorphType,MorphNum,FragName1,FragNum1,FragName2,FragNum2,FragName3,FragNum3,FragName4,FragNum4,FragName5,FragNum5,FragsAvailable,FragsTotal,NewOrOld)
		local HaveMorph = EVT.IsItUnlocked(MorphType,MorphNum,MorphName)
		local NumFrags = 0
		local StillNeed = ""

		if FragsAvailable > 0 then
			Fragment1 = EVT.IsItUnlocked("Fragment",FragNum1,FragName1)
			if Fragment1 then NumFrags = 1 else StillNeed = FragName1 end
		end

		if FragsAvailable > 1 then
			Fragment2 = EVT.IsItUnlocked("Fragment",FragNum2,FragName2)
-- 2.060			if Fragment2 then NumFrags = NumFrags + 1 elseif Fragment1 then StillNeed = FragName2 else StillNeed = string.format("%s & %s",StillNeed,FragName2) end
			if Fragment2 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName2 else StillNeed = string.format("%s & %s",StillNeed,FragName2) end
		end

		if FragsAvailable > 2 then
			Fragment3 = EVT.IsItUnlocked("Fragment",FragNum3,FragName3)
-- 2.060			if Fragment3 then NumFrags = NumFrags + 1 elseif Fragment1 or Fragment2 then StillNeed = FragName3 else StillNeed = string.format("%s & %s",StillNeed,FragName3) end
			if Fragment3 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName3 else StillNeed = string.format("%s & %s",StillNeed,FragName3) end
		end

		if FragsAvailable > 3 then
			Fragment4 = EVT.IsItUnlocked("Fragment",FragNum4,FragName4)
-- 2.060			if Fragment4 then NumFrags = NumFrags + 1 elseif Fragment1 or Fragment2 or Fragment3 then StillNeed = FragName4 else StillNeed = string.format("%s & %s",StillNeed,FragName4) end
			if Fragment4 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName4 else StillNeed = string.format("%s & %s",StillNeed,FragName4) end
		end

-- Darn Doomchar Plateau and its 5 frags!
		if FragsAvailable > 4 then
			Fragment5 = EVT.IsItUnlocked("Fragment",FragNum5,FragName5)
-- 2.060			if Fragment5 then NumFrags = NumFrags + 1 elseif Fragment1 or Fragment2 or Fragment3 or Fragment4 then StillNeed = FragName5 else StillNeed = string.format("%s & %s",StillNeed,FragName5) end
			if Fragment5 then NumFrags = NumFrags + 1 elseif StillNeed == "" then StillNeed = FragName5 else StillNeed = string.format("%s & %s",StillNeed,FragName5) end
		end

-- 2.400 Changed "morph a pet into" to "create"
-- 2.000 Output only for new collectibles
		if NewOrOld == "new" then
			if HaveMorph then
				CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s %s: COLLECTED.",MorphName,MorphType))
			elseif NumFrags == 0 then
				CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s: NO %s, ZERO fragments.",MorphName,MorphType))
-- 2.271 Fixed problem of 5-fragment collectibles showing as complete with only 3 collected: was ">2"
			elseif NumFrags == FragsTotal then
				CHAT_ROUTER:AddSystemMessage(string.format("|cD677EE%s: You have all the fragments you need to create the %s.",MorphName,MorphType))
			elseif NumFrags == FragsAvailable then
				CHAT_ROUTER:AddSystemMessage(string.format("|cFFFFFF%s PARTIAL: You have all fragments currently available (%d) to create the %s.",MorphName,NumFrags,MorphType))
			elseif NumFrags < FragsAvailable then
				CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CC%s PARTIAL: |cFFFFFFYou have %d fragments of %d needed to create the %s. There are %d currently available.",MorphName,NumFrags,FragsTotal,MorphType,FragsAvailable))
				if EVT.vars.Current_Event ~= "None" then
					CHAT_ROUTER:AddSystemMessage(zo_strformat("|cFFFFFFFragment<<1[/s]>> still needed: <<2%s>>",NumFrags,StillNeed))
				end
			end
		end

		if NumFrags>=FragsTotal then
			HaveMorph = true
			NumFrags = NumFrags-FragsTotal
		end
		return HaveMorph,NumFrags,StillNeed	-- For old collectibles, if there are enough fragments to make the thing, count it as done.
	end

	local function ShowOld (Base,HaveBase,BaseFrags,NeedBase,Morph,HaveMorph,MorphFrags,NeedMorph,Vendor)
		if not(HaveBase) and EVT.vars.Current_Event ~= "None" then
			CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCYou could get fragments for the %s|cFFFFFF from %s.",Base,Vendor))
		end
		if not(HaveMorph) and EVT.vars.Current_Event ~= "None" then
			CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCYou could get fragments for the %s|cFFFFFF from %s.",Morph,Vendor))
		end
	end

-- 1.981 Changed Base to function; added 4th fragment parameter to all (to prep for Indriks - also, Deadlands personality morph fragments were available from Philius during Zeal on PTS)

-- 2.030 Until the library is working, set the variables manually.
-- 2.100 LIBRARY Remove the following lines
	WhichQuarter = 1
	WhichMonthInQuarter = 1
	local LookupEvent = EVT.vars.Current_Event
	if EVT.vars.Current_Event == "None" then
		CHAT_ROUTER:AddSystemMessage("|cFF00CCThere is no event currently running. When the next starts:")
		LookupEvent = EVT_NEXT_EVENT
	end

-- 2.270 Changed method (this should be removed if/when library works)
-- 2.310 Changed Anniversary to fake being the second event in Q2 because it's dropping the first TWO fragments
-- (this was also the case in 2024, but not in 2023, so it might be a trend but no guarantee)
	local CycleLookup = {
	["Whitestrake's Mayhem"] = {1,1},
	["Heart's Week"] = {1,2},
	["Jester's Festival"] = {1,3},
	["Anniversary"] = {2,1},
	["may event"] = {2,2},
	["Zeal of Zenithar"] = {2,3},
	["july event"] = {3,1},
	["august event"] = {3,2},
	["High Seas"] = {3,3},
	["Witches"] = {4,1},
	["nov event"] = {4,2},
	["New Life"] = {4,3},
	}


	if CycleLookup[LookupEvent]~=nil then
		WhichQuarter = CycleLookup[LookupEvent][1]
		WhichMonthInQuarter = CycleLookup[LookupEvent][2]
	end

	-- 2.430 Collectibles disabled until I have time to update it properly.
	if EVT.vars.Current_Event == "High Seas" then return end

--[[ Heart's Week fragments: (10 tickets each)
Crimson Bat Statuette
Embellished Dance Card
Red Rose Petals
Rosy Boutonnniere
Sharp Rosebush Thorn

Thorn's Bite Withersteed
Blooming Saddle
Gilded Stirrups
Withered Antlers

Thorn's Bite Revelry Gown
Sanguine Red Silk
Sanguine Soul Gem
Sanguine Spool of Thread
]]

-- 2.380 2026
--		ShowCollectibleBase("","pet",0,"",0,"",0,"",0,"none",0,3,3,"new")
--		ShowCollectibleMorph("","type",0,"",0,"",0,"",0,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	if WhichQuarter == 4 and WhichMonthInQuarter == 3 then
		ShowCollectibleBase("Roseblood Bat","pet",13739,"Crimson Bat Statuette",14059,"Red Rose Petals",14060,"Sharp Rosebush Thorn",14061,"none",0,3,3,"new")
		ShowCollectibleMorph("Logical Rune Extraction","customized action",13095,"Exalted Icon of Logic",13085,"Flawless Prism",13086,"Jhunal's Magnificent Extrication",13087,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Robes of Truth and Law","costume",12671,"Golden Fabric",13464,"Sapphire Fabric",13465,"Torc of Wisdom",13466,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Law of Julianos Dwarven Spider","mount",12802,"Dwarven Control Rod",13597,"Comfortable Spider Chassis",13598,"Whirring Dwarven Dynamo",13599,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Wildgrown Chapel of Julianos","notable house",13759,"Diminutive Runed Archway",13845,"Heavy Philosophical Tomes",13846,"Lawkeeper's Lectern",13847,"Stained Glass Fragment",13848,"Thaumaturgic Paving Stone",13849,5,5,"new")
	elseif WhichQuarter == 1 then
		ShowCollectibleBase("Roseblood Bat","pet",13739,"Crimson Bat Statuette",14059,"Red Rose Petals",14060,"Sharp Rosebush Thorn",14061,"none",0,3,3,"new")
		ShowCollectibleMorph("Roseblood Wings Recall","customized action",14050,"Embellished Dance Card",14062,"Rosy Boutonniere",14063,"Sanguine's Goodbye Kiss",14064,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 2 then
		ShowCollectibleBase("Roseblood Bat","pet",13739,"Crimson Bat Statuette",14059,"Red Rose Petals",14060,"Sharp Rosebush Thorn",14061,"none",0,3,3,"new")
		ShowCollectibleMorph("Robes of Truth and Law","costume",12671,"Golden Fabric",13464,"Sapphire Fabric",13465,"Torc of Wisdom",13466,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 3 then
		ShowCollectibleBase("Roseblood Bat","pet",13739,"Crimson Bat Statuette",14059,"Red Rose Petals",14060,"Sharp Rosebush Thorn",14061,"none",0,3,3,"new")
		ShowCollectibleMorph("Law of Julianos Dwarven Spider","mount",12802,"Dwarven Control Rod",13597,"Comfortable Spider Chassis",13598,"Whirring Dwarven Dynamo",13599,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 4 then
		ShowCollectibleBase("Roseblood Bat","pet",13739,"Crimson Bat Statuette",14059,"Red Rose Petals",14060,"Sharp Rosebush Thorn",14061,"none",0,3,3,"new")
		local FragsAvailable=WhichMonthInQuarter+1
		ShowCollectibleMorph("Wildgrown Chapel of Julianos","notable house",13759,"Diminutive Runed Archway",13845,"Heavy Philosophical Tomes",13846,"Lawkeeper's Lectern",13847,"Stained Glass Fragment",13848,"Thaumaturgic Paving Stone",13849,FragsAvailable,5,"new")
	end

--[[ 2025
	if WhichQuarter == 4 and WhichMonthInQuarter == 3 then
		ShowCollectibleBase("Stonewisp of Truth and Law","pet",12665,"Axiomatic Runestones",13082,"Glyph of Law",13083,"Powdered Wisp Remains",13084,"none",0,3,3,"new")
		ShowCollectibleMorph("Logical Rune Extraction","customized action",13095,"Exalted Icon of Logic",13085,"Flawless Prism",13086,"Jhunal's Magnificent Extrication",13087,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Robes of Truth and Law","costume",12671,"Golden Fabric",13464,"Sapphire Fabric",13465,"Torc of Wisdom",13466,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Law of Julianos Dwarven Spider","mount",12802,"Dwarven Control Rod",13597,"Comfortable Spider Chassis",13598,"Whirring Dwarven Dynamo",13599,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Wildgrown Chapel of Julianos","notable house",13759,"Diminutive Runed Archway",13845,"Heavy Philosophical Tomes",13846,"Lawkeeper's Lectern",13847,"Stained Glass Fragment",13848,"Thaumaturgic Paving Stone",13849,5,5,"new")
	elseif WhichQuarter == 1 then
		ShowCollectibleBase("Stonewisp of Truth and Law","pet",12665,"Axiomatic Runestones",13082,"Glyph of Law",13083,"Powdered Wisp Remains",13084,"none",0,3,3,"new")
		ShowCollectibleMorph("Logical Rune Extraction","customized action",13095,"Exalted Icon of Logic",13085,"Flawless Prism",13086,"Jhunal's Magnificent Extrication",13087,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 2 then
		ShowCollectibleBase("Stonewisp of Truth and Law","pet",12665,"Axiomatic Runestones",13082,"Glyph of Law",13083,"Powdered Wisp Remains",13084,"none",0,3,3,"new")
		ShowCollectibleMorph("Robes of Truth and Law","costume",12671,"Golden Fabric",13464,"Sapphire Fabric",13465,"Torc of Wisdom",13466,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 3 then
		ShowCollectibleBase("Stonewisp of Truth and Law","pet",12665,"Axiomatic Runestones",13082,"Glyph of Law",13083,"Powdered Wisp Remains",13084,"none",0,3,3,"new")
		ShowCollectibleMorph("Law of Julianos Dwarven Spider","mount",12802,"Dwarven Control Rod",13597,"Comfortable Spider Chassis",13598,"Whirring Dwarven Dynamo",13599,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 4 then
		ShowCollectibleBase("Stonewisp of Truth and Law","pet",12665,"Axiomatic Runestones",13082,"Glyph of Law",13083,"Powdered Wisp Remains",13084,"none",0,3,3,"new")
		local FragsAvailable=WhichMonthInQuarter+1
		ShowCollectibleMorph("Wildgrown Chapel of Julianos","notable house",13759,"Diminutive Runed Archway",13845,"Heavy Philosophical Tomes",13846,"Lawkeeper's Lectern",13847,"Stained Glass Fragment",13848,"Thaumaturgic Paving Stone",13849,FragsAvailable,5,"new")
	end
]]

--[[ 2024
	if WhichQuarter == 4 and WhichMonthInQuarter == 3 then
		ShowCollectibleBase("Molag Bal Illusion Imp pet","pet",11440,"Anchor Chain Fragment",11893,"Dark Anchor Pinion",11894,"Effigy of the Dominator",11895,"none",0,3,3,"new")
		ShowCollectibleMorph("Planemeld's Master Body Art","body & face markings",11497,"Crematory Ash",11896,"Incandescent Brimstone",11897,"Seething Censer",11898,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Master of Schemes","personality",11875,"Cold Iron Gauntlet",12408,"Grim Iron Mask",12409,"Tyrant's Soul Gem",12410,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Anchorborn Welwa","mount",11880,"Bizarre Daedric Meat",12508,"Fine Ebonsteel Chain",12509,"Strengthened Welwa Muzzle",12510,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Haven of the Five Companions","notable house",12656,"Varen Aquilarios's Key",12694,"Lyris Titanborn's Key",12695,"Abnur Tharn's Key",12696,"Sai Sahan's Key",12697,"Mannimarco's Master Key",12698,5,5,"new")
	elseif WhichQuarter == 1 then
		ShowCollectibleBase("Molag Bal Illusion Imp pet","pet",11440,"Anchor Chain Fragment",11893,"Dark Anchor Pinion",11894,"Effigy of the Dominator",11895,"none",0,3,3,"new")
		ShowCollectibleMorph("Planemeld's Master Body Art","body & face markings",11497,"Crematory Ash",11896,"Incandescent Brimstone",11897,"Seething Censer",11898,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 2 then
		ShowCollectibleBase("Molag Bal Illusion Imp pet","pet",11440,"Anchor Chain Fragment",11893,"Dark Anchor Pinion",11894,"Effigy of the Dominator",11895,"none",0,3,3,"new")
		ShowCollectibleMorph("Master of Schemes","personality",11875,"Cold Iron Gauntlet",12408,"Grim Iron Mask",12409,"Tyrant's Soul Gem",12410,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 3 then
		ShowCollectibleBase("Molag Bal Illusion Imp pet","pet",11440,"Anchor Chain Fragment",11893,"Dark Anchor Pinion",11894,"Effigy of the Dominator",11895,"none",0,3,3,"new")
		ShowCollectibleMorph("Anchorborn Welwa","mount",11880,"Bizarre Daedric Meat",12508,"Fine Ebonsteel Chain",12509,"Strengthened Welwa Muzzle",12510,"none",0,"none",0,WhichMonthInQuarter,3,"new")
	elseif WhichQuarter == 4 then
		ShowCollectibleBase("Molag Bal Illusion Imp pet","pet",11440,"Anchor Chain Fragment",11893,"Dark Anchor Pinion",11894,"Effigy of the Dominator",11895,"none",0,3,3,"new")
-- This didn't work perfectly - when all available frags were collected, instead of saying that, it said that the collectible could be completed.
		local FragsAvailable=WhichMonthInQuarter+1
		if WhichMonthInQuarter==3 then FragsAvailable=5 end
		ShowCollectibleMorph("Haven of the Five Companions","notable house",12656,"Varen Aquilarios's Key",12694,"Lyris Titanborn's Key",12695,"Abnur Tharn's Key",12696,"Sai Sahan's Key",12697,"Mannimarco's Master Key",12698,FragsAvailable,5,"new")
	end
]]

--[[ 2023
		ShowCollectibleBase("Passion Dancer Blossom","pet",10697,"Chartreuse Lily Petals",11051,"Enchanted Silver Flute",11052,"Mystical Sheet Music",11053,"none",0,3,3,"new")
		ShowCollectibleMorph("Passion's Muse","personality",10913,"Bottle of Silver Mist",11055,"Delicate Dancer's Baton",11056,"Pressed Lily Petal Insoles",11057,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Meadowbreeze Memories","skin",10661,"Bottled Skin Dyes",11176,"Ground Jade Lily Powder",11177,"Pressed Silver Leaves",11178,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Passion Dancer's Attire","costume",10702,"Bolt of Indigo Cotton",11428,"Bolt of Silver Silk",11429,"Enchanted Sewing Kit",11430,"none",0,"none",0,3,3,"new")
		ShowCollectibleMorph("Hoardhunter Ursauk","mount",10703,"Blessed Honeycomb",11509,"Gilded and Dyed Saddle",11510,"Sorcerous Golden Ink",11511,"none",0,"none",0,3,3,"new")
]]

-- 2.000 Added 2021 collectibles: Deadlands pet and personality (Philius Dormier, the Impresario's assistant), without all of the output in the function, so this could also be used for Indriks.
	local HaveBase,BaseFrags,NeedBase = ShowCollectibleBase("Unstable Morpholith","pet",8124,"Deadlands Flint",8866,"Rune-Etched Striker",8867,"Smoldering Bloodgrass Tinder",8868,"none",0,3,3,"old")
	if WhichQuarter == 3 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Deadlands Firewalker","personality",774,"Vial of Bubbling Daedric Brew",9086,"Vial of Scalding Daedric Brew",9087,"Vial of Simmering Daedric Brew",9085,"none",0,"none",0,3,3,"old")
		ShowOld ("Unstable Morpholith",HaveBase,BaseFrags,NeedBase,"Deadlands Firewalker",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 4 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Dagonic Quasigriff","mount",8880,"Black Iron Bit and Bridle",9163,"Black Iron Stirrups",9164,"Smoke-Wreathed Gryphon Feather",9162,"none",0,"none",0,3,3,"old")
		ShowOld ("Unstable Morpholith",HaveBase,BaseFrags,NeedBase,"Dagonic Quasigriff",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 1 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Doomchar Plateau","notable house",9649,"Molten Key",9737,"Profane Pedestal",9738,"Scorching Pillar",9739,"Searing Column",9740,"Unholy Tablet",9741,5,5,"old")
		ShowOld ("Unstable Morpholith",HaveBase,BaseFrags,NeedBase,"Doomchar Plateau",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 2 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Dagonic Quasigriff","mount",8880,"Black Iron Bit and Bridle",9163,"Black Iron Stirrups",9164,"Smoke-Wreathed Gryphon Feather",9162,"none",0,"none",0,3,3,"old")
		ShowOld ("Unstable Morpholith",HaveBase,BaseFrags,NeedBase,"Dagonic Quasigriff",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	end
	
-- 2.210 2022 collectibles added to Philius along with the last of 2021 (2024 Q2)
	local HaveBase,BaseFrags,NeedBase = ShowCollectibleBase("Soulfire Dragon Illusion","pet",9437,"Hallowed Hourglass Basin",10068,"Illuminated Dragon Scroll",10069,"Kvatchian Incense",10070,"none",0,3,3,"old")
	if WhichQuarter == 2 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Scales of Akatosh","skin",9436,"Aureate Anointing Oils",10071,"Lustrous Ritual Sand",10072,"Sacred Scale",10179,"none",0,"none",0,3,3,"old")
		ShowOld ("Soulfire Dragon Illusion",HaveBase,BaseFrags,NeedBase,"Scales of Akatosh",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 3 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Aurielic Quasigriff","mount",9775,"Aurelite Gryphon Feather",10232,"Gilded Gryphon Barding",10233,"Sacred Seeds of Akatosh",10234,"none",0,"none",0,3,3,"old")
		ShowOld ("Soulfire Dragon Illusion",HaveBase,BaseFrags,NeedBase,"Aurielic Quasigriff",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 4 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Daggerfall Paladin","costume",9790,"Blessed Rubedite Enamel",10333,"Captured Dragonflame",10334,"Sanctified Metalworking Tools",10335,"none",0,"none",0,3,3,"old")
		ShowOld ("Soulfire Dragon Illusion",HaveBase,BaseFrags,NeedBase,"Daggerfall Paladin",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 1 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Sacred Hourglass of Alkosh","furnishing",10587,"Engraved Glassblowing Tools",10588,"Hallowed White-Gold Ingot",10589,"Mysterious Time-Lost Sands",10590,"none",0,"none",0,3,3,"old")
		ShowOld ("Soulfire Dragon Illusion",HaveBase,BaseFrags,NeedBase,"Sacred Hourglass of Alkosh",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	end

-- 2.230 2023 collectibles added to Philius (2025 Q2 June)
	local HaveBase,BaseFrags,NeedBase = ShowCollectibleBase("Passion Dancer Blossom","pet",10697,"Chartreuse Lily Petals",11051,"Enchanted Silver Flute",11052,"Mystical Sheet Music",11053,"none",0,3,3,"old")
	if WhichQuarter == 2 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Passion's Muse","personality",10913,"Bottle of Silver Mist",11055,"Delicate Dancer's Baton",11056,"Pressed Lily Petal Insoles",11057,"none",0,"none",0,3,3,"old")
		ShowOld ("Passion Dancer Blossom",HaveBase,BaseFrags,NeedBase,"Passion's Muse",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 3 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Meadowbreeze Memories","skin",10661,"Bottled Skin Dyes",11176,"Ground Jade Lily Powder",11177,"Pressed Silver Leaves",11178,"none",0,"none",0,3,3,"old")
		ShowOld ("Passion Dancer Blossom",HaveBase,BaseFrags,NeedBase,"Meadowbreeze Memories",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 4 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Passion Dancer's Attire","costume",10702,"Bolt of Indigo Cotton",11428,"Bolt of Silver Silk",11429,"Enchanted Sewing Kit",11430,"none",0,"none",0,3,3,"old")
		ShowOld ("Passion Dancer Blossom",HaveBase,BaseFrags,NeedBase,"Passion Dancer's Attire",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	elseif WhichQuarter == 1 then
		local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Hoardhunter Ursauk","mount",10703,"Blessed Honeycomb",11509,"Gilded and Dyed Saddle",11510,"Sorcerous Golden Ink",11511,"none",0,"none",0,3,3,"old")
		ShowOld ("Passion Dancer Blossom",HaveBase,BaseFrags,NeedBase,"Hoardhunter Ursauk",HaveMorph,MorphFrags,NeedMorph,"Philius Dormier, the Impresario's Assistant")
	end

-- 2.060 Indriks
	local CheckIndriks = true
	if CheckIndriks then

		local function IndrikPet (Pet1Name,Pet1Code,Pet2Name,Pet2Code)
			local HavePet1 = EVT.IsItUnlocked("pet",Pet1Code,Pet1Name)
			local HavePet2 = EVT.IsItUnlocked("pet",Pet2Code,Pet2Name)
			if not HavePet1 and not HavePet2 then CHAT_ROUTER:AddSystemMessage(string.format("|cFFFFFFYou could get the |cFF00CC%s or the %s Indrik pet |cFFFFFFfrom Nenulaure, Indrik Vendor.",Pet1Name,Pet2Name))
			elseif not HavePet1 then CHAT_ROUTER:AddSystemMessage(string.format("|cFFFFFFYou could get the |cFF00CC%s Indrik pet |cFFFFFFfrom Nenulaure, Indrik Vendor.",Pet1Name))
			elseif not HavePet2 then CHAT_ROUTER:AddSystemMessage(string.format("|cFFFFFFYou could get the |cFF00CC%s Indrik pet |cFFFFFFfrom Nenulaure, Indrik Vendor.",Pet2Name))
			end
		end

		local HaveBase,BaseFrags,NeedBase = ShowCollectibleBase("Nascent Indrik","mount",5710,"Emerald Indrik Feather",6706,"Gilded Indrik Feather",6707,"Onyx Indrik Feather",6708,"Opaline Indrik Feather",6709,4,4,"old")
		if WhichQuarter == 1 then
			local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Dawnwood Indrik","mount",5067,"Berries of Bloom",6659,"Berries of Budding",6660,"Berries of Growth",6661,"Berries of Ripeness",6662,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Dawnwood Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Spectral Indrik","mount",6942,"Berries of Bloom",7021,"Berries of Budding",7022,"Berries of Growth",7023,"Berries of Ripeness",7024,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Spectral Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			IndrikPet ("Springtide",5085,"Haunting",6950)
		elseif WhichQuarter == 2 then
			local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Luminous Indrik","mount",5068,"Berries of Bloom",6694,"Berries of Budding",6695,"Berries of Growth",6696,"Berries of Ripeness",6697,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Luminous Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Icebreath Indrik","mount",7219,"Berries of Bloom",7791,"Berries of Budding",7792,"Berries of Growth",7793,"Berries of Ripeness",7794,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Icebreath Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			IndrikPet ("Shimmering",5087,"Rimedusk",7278)
		elseif WhichQuarter == 3 then
			local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Onyx Indrik","mount",5549,"Berries of Bloom",6698,"Berries of Budding",6699,"Berries of Growth",6700,"Berries of Ripeness",6701,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Onyx Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Mossheart Indrik","mount",7468,"Berries of Bloom",8126,"Berries of Budding",8127,"Berries of Growth",8128,"Berries of Ripeness",8129,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Mossheart Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			IndrikPet ("Ebon-Glow",6616,"Sapling",7503)
		elseif WhichQuarter == 4 then
			local HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Pure-Snow Indrik","mount",5550,"Berries of Bloom",6702,"Berries of Budding",6703,"Berries of Growth",6704,"Berries of Ripeness",6705,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Pure-Snow Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			HaveMorph,MorphFrags,NeedMorph = ShowCollectibleMorph("Crimson Indrik","mount",7467,"Berries of Bloom",8465,"Berries of Budding",8466,"Berries of Growth",8467,"Berries of Ripeness",8468,"none",0,4,4,"old")
			ShowOld ("Nascent Indrik",HaveBase,BaseFrags,NeedBase,"Crimson Indrik",HaveMorph,MorphFrags,NeedMorph,"Nenulaure, Indrik Vendor")
			IndrikPet ("Frost-Light",6617,"Rosethorn",7502)
		end
	end
end

function EVT.HandleEVTCommand(keyWord)
-- 897 AD sewer base. EP: 890, DC: 900. City: 660
-- 1.41 Need location info sometimes
	EVT.PrintDebug(string.format("Location Code: %s Name I'm using %s",GetCurrentMapId(),EVT.Ticket_Location()))
	if(string.lower(keyWord) == "info") then
		EVT.EventInfo(false)

	elseif(string.lower(keyWord) == "chat") then
		EVT.EventInfo(true)
	elseif(string.lower(keyWord) == "show") then
--Show all messages (switch off hide) (DEFAULT)
		EVT.ToggleAutoHide(false)
	elseif(string.lower(keyWord) == "hide") then
--Hide all but the most important messages
		EVT.ToggleAutoHide(true)
	elseif(string.lower(keyWord) == "dboff") then
		EVT.ToggleDebug(false)
	elseif(string.lower(keyWord) == "dbon") then
		EVT.ToggleDebug(true)
	elseif(string.lower(keyWord) == "ui") then
		EVT.ToggleUI()
	elseif(string.lower(keyWord) == "help" or keyWord == "?") then
		CHAT_ROUTER:AddSystemMessage("/evt - See YOUR trade bar info (and current collectibles, if you have trade bars to spend)")
		CHAT_ROUTER:AddSystemMessage("/evti - Details about events (|cFFD700/evti help|r for options)")
		CHAT_ROUTER:AddSystemMessage("/evtc - Post details about events to chat (|cFFD700/evtc help|r for options)") -- 1.91 Was "/evti"
-- 1.86 Added xpbuff to help
		CHAT_ROUTER:AddSystemMessage("/xpbuff - Refresh event xp buff (if there's a double xp event running)")
		CHAT_ROUTER:AddSystemMessage("/xpbuff auto - Toggle automatic event xp buff")
-- 1.91 added on/off to help
		if EVT.settings.XP_refresh < 120 then
			CHAT_ROUTER:AddSystemMessage("/xpbuff off - Turn OFF automatic event xp buff")
		else
			CHAT_ROUTER:AddSystemMessage("/xpbuff on - Turn ON automatic event xp buff")
		end
		if EVT.vars.HideUI and EVT_HIDE_UI then
			CHAT_ROUTER:AddSystemMessage("/evt ui - Show user interface (toggle)")
		elseif not EVT.vars.HideUI and EVT_HIDE_UI then
			CHAT_ROUTER:AddSystemMessage("/evt ui - Show user interface TEMPORARILY")
			CHAT_ROUTER:AddSystemMessage("      - (between events UI is off every time you sign on)")
		else
			CHAT_ROUTER:AddSystemMessage("/evt ui - Hide user interface (toggle)")
		end
-- 1.91 Add "done" to help
		CHAT_ROUTER:AddSystemMessage("/evt done - Mark trade bars for the day as completed")
		CHAT_ROUTER:AddSystemMessage("/evt undone - Mark trade bars for the day as not yet done")
		CHAT_ROUTER:AddSystemMessage("/evt coll - See your current collectibles")
		if EVT.vars.autoHide then
			CHAT_ROUTER:AddSystemMessage("/evt show - Show all chat messages (restore default)")
		else
			CHAT_ROUTER:AddSystemMessage("/evt hide - Hide all but the most important chat messages")
		end
-- 1.35 Reset -- 1.91 Removed
--		CHAT_ROUTER:AddSystemMessage("/evt reset - Resets daily ticket info (if tickets are not registering after 24 hrs, try this)")
		CHAT_ROUTER:AddSystemMessage("/evt help or /evt ? - List all commands")
-- 1.35 Added reset function
	elseif(string.lower(keyWord) == "reset") then
		if EVT_EVENT_START <= EVT.FindCurrentTime() and EVT_EVENT_END > EVT.FindCurrentTime() then
			EVT.vars.Current_Event = "None"
			EVT.StartNewEvent()
			EVT_HIDE_UI = EVT.vars.HideUI
			EVT.vars.DataCleared = nil
			CHAT_ROUTER:AddSystemMessage("|cFF0000Daily trade bar info has been reset.|r")
			CHAT_ROUTER:AddSystemMessage("|cFFD700If you have already gotten trade bars today,|r")
			CHAT_ROUTER:AddSystemMessage("|cFFD700it will appear as if you haven't, for the rest of the day.|r")
		else
			EVT.vars.Current_Event = "None"
			EVT_HIDE_UI = true
			EVT.ClearData()
			CHAT_ROUTER:AddSystemMessage("|c00CCFFThere is no known event running currently, so your data has been cleared.|r")
		end
		EVT.ShowVars("UI")

-- 1.86 Added experimental, untested "done" and "undo" functions. Undocumented. Not added to slashcommander yet
-- 1.87 Added EVT.ShowVars("UI") at the end of each to refresh UI; moved them out to separate function.
	elseif(string.lower(keyWord) == "done" or string.lower(keyWord) == "done1" or string.lower(keyWord) == "done2") then
		EVT.TicketsDone(keyWord)
	elseif(string.lower(keyWord) == "undo" or string.lower(keyWord) == "undo1" or string.lower(keyWord) == "undo2") then
		EVT.TicketsUndo(keyWord)
-- 1.98
	elseif(string.lower(keyWord) == "coll") then
		ShowCollectibles()
	else
		EVT.ShowVars("/evt")
		if not EVT.vars.HideUI and EVT.vars.Total_Tickets > 4 then
			ShowCollectibles()
		else
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFType |cFFD700/evt coll|cFFFFFF to see your collectibles.")
		end
	end
end

--CHAT_ROUTER:AddSystemMessage(EventTrackerVars['Default']['@Kelinmiriel']['$AccountWide'][GetWorldName()]['Skulls_Done'])
function EVT.HandleEVTInfoChat(SpecificEvent,tochat)

	if(SpecificEvent == "nex" or SpecificEvent == "upc") then	-- "next" (or "upc" for "upcoming")
		EVT.EventInfo(tochat,"Upcoming")
-- 1.95 Added news
	elseif(SpecificEvent == "new") then				-- "new" for "news"
		EVT.EventInfo(tochat,"News-"..string.sub(GetWorldName(),1,2))
-- 1.62 Added xpbuff
	elseif(SpecificEvent == "xpb") then				-- "xpbuff"
		EVT.EventInfo(tochat,"Xpbuff")
-- 1.52 Added imp (Impresario), pet (Pet, for the Unstable Morpholith), and morph (Morph, about morphing the pet)
	elseif(SpecificEvent == "imp") then				-- "imp"
		EVT.EventInfo(tochat,"Impresario")
	elseif(SpecificEvent == "pet") then				-- "pet"
		EVT.EventInfo(tochat,"Pet")
-- 1.53 4 letters to separate "morph" from "Morrowind"
	elseif(SpecificEvent == "morp") then				-- "morp"
		EVT.EventInfo(tochat,"Morph")
	elseif(SpecificEvent == "box") then				-- "box"
		EVT.EventInfo(tochat,"Box")
	elseif(SpecificEvent == "beg" or SpecificEvent == "sta") then	-- "begin" (how to begin event), (or "sta" for "start")
		EVT.EventInfo(tochat,"Begin")
-- 1.78 Added Indrik
	elseif(SpecificEvent == "ind") then				-- "indrik"
		EVT.EventInfo(tochat,"Indrik")
	elseif(SpecificEvent == "cyc") then				-- "cyc"
		EVT.EventInfo(tochat,"Indrik Cycle")

-- *************** ANNUAL EVENTS
	elseif(SpecificEvent == "ann") then				-- "anniv"
		EVT.EventInfo(tochat,"Anniversary")
	elseif(SpecificEvent == "jes") then				-- "jester"
		EVT.EventInfo(tochat,"Jester's Festival")
-- 1.57 Added "whi" for renamed event
	elseif(SpecificEvent == "mid" or SpecificEvent == "whi") then	-- "mid" (Midyear) or "whi" (Whitestrake's)
		EVT.EventInfo(tochat,"Whitestrake's Mayhem")
-- 1.96 Since "new" is now "news", use "nl" or "lif" for "New Life"
--	elseif(SpecificEvent == "new") then
	elseif(SpecificEvent == "nl" or SpecificEvent == "lif") then	-- 1.96 "new" for "New Life" changed to "nl" or "lif"
		EVT.EventInfo(tochat,"New Life")
	elseif(SpecificEvent == "und") then				-- "undaunted"
		EVT.EventInfo(tochat,"Undaunted")
	elseif(SpecificEvent == "wit") then				-- "witch"
		EVT.EventInfo(tochat,"Witches")
	elseif(SpecificEvent == "zea" or SpecificEvent == "zen") then	-- 1.77 "zea" or "zen" for Zeal of Zenithar
		EVT.EventInfo(tochat,"Zeal of Zenithar")
	elseif(SpecificEvent == "hea") then	-- 2.350 (Heart's Week)
		EVT.EventInfo(tochat,"Heart's Week")

-- *************** NOT YET DEPRECATED EVENTS
-- Also fix around line 1800 (EVT.RegisterSlashCommands)
	elseif(SpecificEvent == "dae" or SpecificEvent == "dea") then	-- 1.53, 2.350 "dae" or "dea" for people who can't type/spell (Daedric War)
		EVT.EventInfo(tochat,"Daedric War")
	elseif(SpecificEvent == "sea") then	-- 2.430 (High Seas)
		EVT.EventInfo(tochat,"High Seas")

-- *************** DEPRECATED EVENTS
	elseif(SpecificEvent == "tam") then				-- 2.240 Pan-Tamriel Celebration
		EVT.EventInfo(tochat,"Pan-Tamriel")
	elseif(SpecificEvent == "bre") then				-- 2.240 Legacy of the Bretons
		EVT.EventInfo(tochat,"Bretons")
	elseif(SpecificEvent == "wea") then				-- 2.240 Fallen Leaves of the West Weald
		EVT.EventInfo(tochat,"West Weald")
	elseif(SpecificEvent == "gui") then				-- 2.020 Guilds and Glory Celebration
		EVT.EventInfo(tochat,"Guilds & Glory")

	elseif(SpecificEvent == "tel") then				-- 2.000 Secrets of the Telvanni
		EVT.EventInfo(tochat,"Telvanni")
	elseif(SpecificEvent == "obl") then				-- 2.020 Gates of Oblivion Celebration
		EVT.EventInfo(tochat,"Oblivion")
	elseif(SpecificEvent == "dra") then				-- 1.83 "dra" -- 1.87 Changed from "Season of the Dragon" to "Dragon" so it works with my event name
		EVT.EventInfo(tochat,"Dragon")
	elseif(SpecificEvent == "sky") then				-- 1.81 "sky" -- 1.87 Changed from "Dark Heart of Skyrim" to "Skyrim"
		EVT.EventInfo(tochat,"Skyrim")
	elseif(SpecificEvent == "hig") then				-- 1.78 "hig"
		EVT.EventInfo(tochat,"High Isle")
	elseif(SpecificEvent == "bla") then				-- 1.54 "bla"
		EVT.EventInfo(tochat,"Blackwood")
	elseif(SpecificEvent == "els") then				-- 1.53 "els"
		EVT.EventInfo(tochat,"Pan-Elsweyr")
	elseif(SpecificEvent == "one") then				-- "one"
		EVT.EventInfo(tochat,"Year One")

	elseif(SpecificEvent == "clo" or SpecificEvent == "cwc") then	-- "cwc", ( or "clo" for "clock")
		EVT.EventInfo(tochat,"Clockwork City")
	elseif(SpecificEvent == "tg" or SpecificEvent == "db") then		-- both "db" and "tg" go here
		EVT.EventInfo(tochat,"Crime Pays")
	elseif(SpecificEvent == "ic" or SpecificEvent == "imp") then	-- "ic" (or "imp" for "imperial")
		EVT.EventInfo(tochat,"Imperial City")
-- 1.81 "Sky" removed as an option from the old Greymoor event
	elseif(SpecificEvent == "los" or SpecificEvent == "gre") then	-- "lost" (or "gre" for "Greymoor")
		EVT.EventInfo(tochat,"Lost Treasures")
-- 1.53 4 letters to separate "morph" from "Morrowind"
	elseif(SpecificEvent == "morr" or SpecificEvent == "vva" or SpecificEvent == "var") then	-- "morrow" (also "vva" for "vvardenfell" or "var" for people who can't type "vvardenfell")
		EVT.EventInfo(tochat,"Morrowind")
	elseif(SpecificEvent == "mur") then				-- "murk"
		EVT.EventInfo(tochat,"Murkmire")
	elseif(SpecificEvent == "sum") then				-- "summer"
		EVT.EventInfo(tochat,"Summerset")
	elseif(SpecificEvent == "tri") then				-- "tribunal"
		EVT.EventInfo(tochat,"Tribunal")
	elseif(SpecificEvent == "wro" or SpecificEvent == "ors" or SpecificEvent == "orc") then	-- "wrothgar" (also "ors" for "orsinium" or "orc")
		EVT.EventInfo(tochat,"Wrothgar")

	elseif(SpecificEvent == "hel" or SpecificEvent == "?") then		-- "help" or "?"
--		CHAT_ROUTER:AddSystemMessage("|cFFD700/evti|r |cffffff- Details about the CURRENT event. Use|r |cFFD700/evti next|r |cFFFFFFfor info about upcoming events,|r |cFFD700/evti box|r |cFFFFFFfor more info about box drops, or|r")
--[[		CHAT_ROUTER:AddSystemMessage("|cFFD700/evti|r |cffffff- Details about the CURRENT event. Use|r |cFFD700/evti next|r |cFFFFFFfor info about upcoming events, or|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700/evti <event>|r |cFFFFFFto see details for any specific event, such as|r |cFFD700/evti witch|r |cFFFFFFfor the Witches Festival.|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFOptions are:|r |cFFD700anniv|r (Anniversary)   |cFFD700cwc|r (Clockwork)   |cFFD700db|r (Dark Brotherhood)   |cFFD700ic|r (Imperial City)")
		CHAT_ROUTER:AddSystemMessage("|cFFD700jester   lost|r (Lost Treasures)   |cFFD700mid|r (Mid-Year Mayhem)   |cFFD700morrow|r (Morrowind)   |cFFD700murk|r (Murkmire)")
		CHAT_ROUTER:AddSystemMessage("|cFFD700new|r (New Life)   |cFFD700summer|r (Summerset)   |cFFD700tg|r (Thieves Guild)   |cFFD700undaunted   witch   wrothgar|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700/evti help|r or |cFFD700/evti ?|r - List all info options")
]]
-- 1.96 Updated info
		if tochat then
			CHAT_ROUTER:AddSystemMessage("|cFFD700/evtc|r |cFFFFFFoptions:|r |cFFD700next|r|cAAAAAA-upcoming events|r |cFFD700new|r|cAAAAAA-News|r")
		else
			CHAT_ROUTER:AddSystemMessage("|cFFD700/evti|r |cFFFFFFoptions:|r |cFFD700next|r|cAAAAAA-upcoming events|r |cFFD700new|r|cAAAAAA-News|r")
		end
		CHAT_ROUTER:AddSystemMessage("|cFFD700beg|r|cAAAAAAin event|r  |cFFD700box|r|cAAAAAA-get boxes|r  |cFFD700imp|r|cAAAAAAresario|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700pet|r|cAAAAAA,|r  |cFFD700morp|r|cAAAAAAh,|r  |cFFD700ind|r|cAAAAAArik-things to buy with trade bars|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700cwc|r|cAAAAAA-Clockwork|r  |cFFD700db|r|cAAAAAA-Dark Brotherhood|r  |cFFD700ic|r|cAAAAAA-Imperial City|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700jester  lost|r |cAAAAAATreasures|r  |cFFD700mid|r|cAAAAAAYear Mayhem|r  |cFFD700morrow|r|cAAAAAAind|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700nl|r|cAAAAAA-New Life|r  |cFFD700tribunal  undaunted  witch  wrothgar   help|r |cAAAAAAor|r |cFFD700?   (none)|r |cAAAAAA-current|r")
		CHAT_ROUTER:AddSystemMessage("|cFFD700murk|r|cAAAAAAmire|r  |cFFD700summer|r|cAAAAAAset|r  |cFFD700tg|r|cAAAAAA-Thieves Guild|r")
	else
		EVT.EventInfo(tochat)
	end
end

function EVT.HandleEVTInfo(keyWord)
	local SpecificEvent = string.sub(string.lower(keyWord),1,3)
	local tochat = false

-- 1.53 "morph" becomes "morp" and "Morrowind" uses "morr" instead of 3 letters
	if SpecificEvent == "mor" then SpecificEvent = string.sub(string.lower(keyWord),1,4) end
	EVT.HandleEVTInfoChat(SpecificEvent,tochat)
end

function EVT.HandleEVTChat(keyWord)
	local SpecificEvent = string.sub(string.lower(keyWord),1,3)
	local tochat = true

-- 1.53 "morph" becomes "morp" and "Morrowind" uses "morr" instead of 3 letters
	if SpecificEvent == "mor" then SpecificEvent = string.sub(string.lower(keyWord),1,4) end
	EVT.HandleEVTInfoChat(SpecificEvent,tochat)
end


-- Stolen directly from Reveries. Thanks @StorybookTerror! <3
function EVT.PlayMemento(mementoID)
-- 1.69 Don't do it if in stealth. Also, return block reason (not always useful) / 91 for stealthed
--	local Stealthed = GetUnitStealthState("player") ~= STEALTH_STATE_NONE

-- 1.97 Cakes are spawning EVERYWHERE!! (Cakes refuse to follow memento rules. So I shall force them to. Also crafting stations.)
	local blockReason = "none"
	local Stealthed = GetUnitStealthState("player") ~= STEALTH_STATE_NONE

-- 1.72 Added mount (scroll can be used on mount, but it will kick you off, so won't do that.)
-- 1.990 Added Tribute; removed Anniversary-only check
	if Stealthed then blockReason = "IN STEALTH"
--	elseif EVT.vars.Current_Event == "Anniversary" then
	elseif IsMounted() then blockReason = "ON MOUNT"
	elseif IsUnitInCombat("player") then blockReason = "IN COMBAT"
	elseif IsUnitDeadOrReincarnating("player") then blockReason = "DEAD"
	elseif IsUnitSwimming("player") then blockReason = "SWIMMING"
	elseif IsPlayerInteractingWithObject() then blockReason = "INTERACTING"
	elseif IsScryingInProgress() then blockReason = "SCRYING"
	elseif IsDiggingGameActive() then blockReason = "EXCAVATING"
	elseif GetTributeMatchType() ~= 0 then blockReason = "TRIBUTE"
--	end
	end

--[[ 1.97 Avoid spawning cake if interacting with crafting stations
	local Cake_Block = "No"
	if EVT.vars.Current_Event == "Anniversary" then Interaction = INTERACTION_NONE end -- Interacting with things isn't an issue if not cake
	local Interaction = GetInteractionType()
]]
--[[
    INTERACTION_ATTRIBUTE_RESPEC
    INTERACTION_AVA_HOOK_POINT
    INTERACTION_BANK
    INTERACTION_BOOK
    INTERACTION_BUY_BAG_SPACE
    INTERACTION_CONVERSATION
    INTERACTION_CRAFT
    INTERACTION_DYE_STATION
    INTERACTION_FAST_TRAVEL
    INTERACTION_FAST_TRAVEL_KEEP
    INTERACTION_FISH
    INTERACTION_FURNITURE
    INTERACTION_GUILDBANK
    INTERACTION_GUILDKIOSK_BID
    INTERACTION_GUILDKIOSK_PURCHASE
    INTERACTION_HARVEST
    INTERACTION_HIDEYHOLE
    INTERACTION_KEEP_GUILD_CLAIM
    INTERACTION_KEEP_GUILD_RELEASE
    INTERACTION_KEEP_INSPECT
    INTERACTION_KEEP_PIECE
    INTERACTION_LOCKPICK
    INTERACTION_LOOT
    INTERACTION_MAIL
    INTERACTION_NONE
    INTERACTION_PAY_BOUNTY
    INTERACTION_PICKPOCKET
    INTERACTION_QUEST
    INTERACTION_RETRAIT
    INTERACTION_SIEGE
    INTERACTION_SKILL_RESPEC
    INTERACTION_STABLE
    INTERACTION_STONE_MASON
    INTERACTION_STORE
    INTERACTION_TRADINGHOUSE
    INTERACTION_TREASURE_MAP
    INTERACTION_VENDOR 
]]

-- 1.97 Added a line
	if blockReason == "none" then
		blockReason = GetCollectibleBlockReason(mementoID)
-- 1.67 Switched to SI instead of hard-coded English messages
		local blockReasons = {
			[COLLECTIBLE_USAGE_BLOCK_REASON_BLOCKED_BY_ZONE] = 1,		-- "unable to use in zone"
			[COLLECTIBLE_USAGE_BLOCK_REASON_IN_WATER] = 2,			-- "in water"
			[COLLECTIBLE_USAGE_BLOCK_REASON_DEAD] = 3,			-- "dead"
			[COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_COLLECTIBLE] = 4,		-- "invalid collectible"
			[COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_GENDER] = 5,		-- "invalid gender"
			[COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_RACE] = 6,		-- "invalid race"
			[COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_ALLIANCE] = 7,		-- "invalid alliance"
			[COLLECTIBLE_USAGE_BLOCK_REASON_PLACED_IN_HOUSE] = 8,		-- "placed in house"
			[COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN] = 9,			-- "on cooldown"
			[COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_CLASS] = 10,		-- "class"
			[COLLECTIBLE_USAGE_BLOCK_REASON_TARGET_REQUIRED] = 11,		-- "requires target"
			[COLLECTIBLE_USAGE_BLOCK_REASON_ON_MOUNT] = 12,			-- "on mount"
			[COLLECTIBLE_USAGE_BLOCK_REASON_BLOCKED_BY_SUBZONE] = 13,		-- "unable to use in subzone"
			}
		if Stealthed then
			EVT.PrintDebug("|cFF00CCXP buff cannot be refreshed:|r |cFFFFFFSTEALTHED")
			return 91
		elseif IsCollectibleUsable(mementoID) then
--		EVT.PrintDebug("|cFF00CCBefore attempting to refresh XP buff, block reason: |r |cFFFFFF" .. (GetString("SI_COLLECTIBLEUSAGEBLOCKREASON",blockReasons[blockReason]) or ("unknown reason: " .. blockReason)))
			UseCollectible(mementoID)
			blockReason = GetCollectibleBlockReason(mementoID)
--		EVT.PrintDebug("|cFF00CCAfter attempting to refresh XP buff, block reason: |r |cFFFFFF" .. (GetString("SI_COLLECTIBLEUSAGEBLOCKREASON",blockReasons[blockReason]) or ("unknown reason: " .. blockReason)))
		else
			EVT.PrintDebug("|cFF00CCXP buff cannot be refreshed:|r |cFFFFFF" .. (GetString("SI_COLLECTIBLEUSAGEBLOCKREASON",blockReasons[blockReason]) or "unknown reason"))
		end
	else
		EVT.PrintDebug("|cFF00CCCAKE cannot be spawned:|r |cFFFFFF" .. blockReason)
	end
end

-- 1.86 Possible return values: Reasons why the scroll wasn't used ("IN STEALTH", "ON MOUNT"...), "Done" (success), "SCROLL MISSING"
local last_scroll_Run = 0 -- 1.86 changed from last_Run to avoid accidental re-use
-- 1.71 Added!
function EVT.UpdateScrollBuff()
	local blockReason = "none"
	local Stealthed = GetUnitStealthState("player") ~= STEALTH_STATE_NONE

-- Something is calling this twice in a row, and I'm too tired to figure out what or why, but want it to stop.
	if EVT.FindCurrentTime()-last_scroll_Run < 60*3 then return end	-- 3 min

-- 1.72 Added mount (scroll can be used on mount, but it will kick you off, so won't do that.)
	if Stealthed then blockReason = "IN STEALTH"
	elseif IsMounted() then blockReason = "ON MOUNT"
	elseif IsUnitInCombat("player") then blockReason = "IN COMBAT"
	elseif IsUnitDeadOrReincarnating("player") then blockReason = "DEAD"
	elseif IsUnitSwimming("player") then blockReason = "SWIMMING"
--	elseif IsPlayerInteractingWithObject() then blockReason = "INTERACTING with object"
	elseif IsScryingInProgress() then blockReason = "SCRYING"
	elseif IsDiggingGameActive() then blockReason = "EXCAVATING"
	elseif GetTributeMatchType() ~= 0 then blockReason = "TRIBUTE"	-- 1.990 Added Tribute
	end

	if blockReason == "none" then
		local numSlots = GetBagSize(BAG_BACKPACK)
		
		-- iterate through bag to find the item that matches stored foodLink setting
		for slotIndex = 0, numSlots do
			local slotItemId = GetItemId(BAG_BACKPACK, slotIndex)
	--		EVT.PrintDebug(string.format("EVT: Item name %s, Slot Index %s",GetItemName(BAG_BACKPACK, slotIndex),slotIndex))
			if slotItemId == Scroll_ID then	-- Scroll of Pelinal's Fury
				-- UseItem is protected, so CallSecureProtected is used to make the call
				local success = CallSecureProtected("UseItem", BAG_BACKPACK, slotIndex)
				CHAT_ROUTER:AddSystemMessage("|c00FF00Scroll used!")
				return "Done"
			end
		end
		blockReason = "SCROLL MISSING"
	end

	CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCPelinal scroll cannot be refreshed:|r |cFFFFFF%s|r",blockReason))
	CHAT_ROUTER:AddSystemMessage("Will try again later.")

--	CHAT_ROUTER:AddSystemMessage(string.format("Current time: %s Last scroll run: %s",EVT.FindCurrentTime(),last_scroll_Run))
	last_scroll_Run = EVT.FindCurrentTime() -- 1.86 This was "last_Message" - changed to last_scroll_Run
--	CHAT_ROUTER:AddSystemMessage(string.format("Will try again in %s min.",(EVT.Next_Buff_Time()-EVT.FindCurrentTime())/60))
	return blockReason

-- 1.72 Disabled this
--	CHAT_ROUTER:AddSystemMessage("|cFF0000ERROR: Scroll of Pelinal's Ferocity not found!|r")
--	return "Missing"
end


-- mementoName passed as the parameter from XPBuff and RVBuff only; otherwise blank. Ignored if not valid.
function EVT.XP_Event(mementoName)
	local mementoID = 0
	local XP_Memento_IDs = {
		["pie"] = 1167,
		["mead"] = 1168,
		["witch"] = 479,
-- 2.070 2024 cake 12422 (replaces 2023 cake 11089)
-- 2.311 Fix variable name
		["cake"] = Collectible_Num ["cake"],
		["scroll"] = Scroll_Memento
		}

	local memento = "none"
	local XP_Memento = {
		["Jester's Festival"] = "pie",
		["New Life"] = "mead",
-- 2.000		["Witches"] = "witch",	-- Witches Festival XP buff is passive and continuous now.
		["Anniversary"] = "cake",
		["Whitestrake's Mayhem"] = "scroll"
		}

	local IsXpEvent = false
	local IsXpEventOutput = "false"
	if XP_Memento[EVT.vars.Current_Event] ~= nil then
		IsXpEvent = true
		IsXpEventOutput = "true"
		mementoID = XP_Memento_IDs[XP_Memento[EVT.vars.Current_Event]]
		memento = XP_Memento[EVT.vars.Current_Event]
	end

	if mementoName ~= nil then
		if XP_Memento_IDs[mementoName] ~= nil then
			memento = mementoName
			mementoID = XP_Memento_IDs[mementoName]
			if IsXpEvent and memento ~= mementoName then
				IsXpEvent = false
				IsXpEventOutput = "false (different event)"
			end
		end
	end
--	EVT.PrintDebug(string.format("XP_Event: %s, Memento ID: %s, Memento: %s",IsXpEventOutput,mementoID, memento))
	return IsXpEvent, mementoID, memento
end


-- 1.50 Added XPBuff slash command to refresh event xp buff
function EVT.XPBuff(keyWord)
	local IsXpEvent, mementoID, memento = EVT.XP_Event(keyWord)
--	EVT.PrintDebug(type(keyWord))

-- 1.65 Add auto buff -- 1.67 add call to Toggle_Auto_Buff
-- 1.86 Add options "on" and "off"
	if EVT.settings.XP_refresh > 120 and keyWord == "off" then
		CHAT_ROUTER:AddSystemMessage("|cFF0000xpbuff is already OFF")
	elseif EVT.settings.XP_refresh < 120 and keyWord == "on" then
		CHAT_ROUTER:AddSystemMessage("|c32CD32xpbuff is already ON")
	elseif keyWord == "auto" or keyWord == "on" or keyWord == "off" then
		if EVT.settings.XP_refresh < 120 or keyWord == "off" then
			EVT.Toggle_Auto_Buff(false)
			return
		else
			local bufftime, msg = EVT.XP_Buff_Time()
			if mementoID ~= 0 then
				if msg == "Ok" then
					EVT.Refresh_XP_Buff(memento)
				else
-- "Auto-buff will not remove your old Pelinal Scroll buff" or "Auto-buff will not remove your old double XP buff"
					EVT.Notification("|cFFD700** NOTICE","|r" .. msg .. " |cFFD700**|r",SOUNDS.LEVEL_UP)
					CHAT_ROUTER:AddSystemMessage("|c00CCFF" .. msg)
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r |cFFD700/xpbuff|r |cFFFFFFto start the current buff sooner.|r")
				end
			end
-- 1.71 Setting this will force Toggle_Auto_Buff to run the polling function, which may be necessary in case the player stays on long enough after turning on autobuff to need re-buffing.
			EVT_POLLING_ACTIVE = "XP Buff"
			EVT.Toggle_Auto_Buff(true)
		end

-- This is a choice, not auto, so let it be done.
	elseif mementoID ~= 0 then
		EVT.Refresh_XP_Buff(memento)
	end
end


-- 1.50 Stealth feature: /rvbuff will work with Reveries. Whether or not the player has Reveries installed, it'll trigger the buff for those who do.
function EVT.RVBuff(keyWord)
	local mementoName = "none"
	local mementoNames = {
		["pie"] = "The Pie of Misrule",
		["mead"] = "Breda's Bottomless Mead Mug",
		["witch"] = "Witchmother's Whistle",
		["cake"] = Current_Cake,	-- 2.201 Changed to a variable
		["scroll"] = "Pelinal's Scroll"
		}

	local IsXpEvent, mementoID, mementoName = EVT.XP_Event(keyWord)

-- 1.71 Make sure a valid parameter overrides anything else
	if keyWord ~= nil then
		if mementoNames[keyWord] ~= nil then mementoName = keyWord end
	end

	if mementoNames[mementoName] == nil then
		CHAT_ROUTER:AddSystemMessage("|cFF00CCSorry, there is no xp event active right now!|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFDouble xp events run March, April, Oct., Dec.|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFIn Jan & June; 2x xp only for Cyro player kills.|r")
	else
		if mementoName == "scroll" then
			CHAT_ROUTER:AddSystemMessage("|cFF6900Sorry; you can't get other people to use scrolls.|r")
			EVT.UpdateScrollBuff()
		else
			StartChatInput("rv " .. mementoNames[mementoName])
		end
	end
end


-- Returns cake ID for a valid old cake, or 0 if none.
function EVT.WhichCake()
	local numCakes = 7
	local Cakes = {
-- Only old cakes that can't give tickets are included in this list.
		13520,	-- 2025
		12422,	-- 2024
		11089,	-- 2023
		10287,	-- 2022
		9012,	-- 2021
		7619,	-- 2020
		5886,	-- 2019
		4786,	-- 2018
		1109,	-- 2017
		356	-- 2016
		}
	local cake = 0

	for i = 1, numCakes do
		if GetCollectibleUnlockStateById(Cakes[i]) ~= COLLECTIBLE_UNLOCK_STATE_LOCKED then cake = Cakes[i] end
	end
	return cake
end

-- 1.96 Reduce messages to once per login
-- 1.981 Added extra return parameter Try_Again to reduce extra messages when scroll, cake, pie, etc. is missing.
local New_Event_Msg = true
function EVT.Refresh_XP_Buff(memento)
--	local msg1 = "Sorry, there is no xp event active right now! Double xp events run four times every year."
--	local msg2 = "Jester's Fest (March), Anniversary (April), Witches (October), and New Life (December)."


	local XP_Event_Name = {
		["pie"] = "Jester's Festival",
		["mead"] = "New Life",
		["witch"] = "Witches",
		["cake"] = "Anniversary",
		["scroll"] = "Whitestrake's Mayhem"
		}

-- 2.311 Fix variable name Collectible_Num
	local XP_Memento_IDs = {
		["pie"] = 1167,
		["mead"] = 1168,
		["witch"] = 479,
		["cake"] = Collectible_Num ["cake"],	-- 2024 cake
		["scroll"] = Scroll_Memento
		}

	local IsXpEvent, default_mementoID, default_memento = EVT.XP_Event()
	local mementoID = default_mementoID
	local Return_msg = "no return msg"
	local Try_Again = true

-- Unless this is called from slash command with a parameter, this will be the standard buff refresh.
-- If there's no event running, give error message and exit.
-- If there IS an event, use the event memento/scroll.
	if memento == nil then
		if not IsXpEvent then
			CHAT_ROUTER:AddSystemMessage("|cFF00CCSorry, there is no xp event active right now!|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFDouble xp events run March, April, Oct., Dec.|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFIn Jan & June; 2x xp only for Cyro player kills.|r")
			return "No event"
		end
		memento = default_memento

-- 1.71 Make sure a valid parameter overrides anything else
	else
		if XP_Memento_IDs[memento] ~= nil then mementoID = XP_Memento_IDs[memento] end
	end

-- Cover all cases of scroll first, then exit. Attempt to update the buff by using scroll if possible.
-- 1.86 Possible return values from scroll: Reasons why the scroll wasn't used ("IN STEALTH", "ON MOUNT"...); "Done" (success), "SCROLL MISSING"
	if memento == "scroll" then
		Return_msg = EVT.UpdateScrollBuff()
-- 1.981 Stop the insane messages every five minutes
		if Return_msg == "SCROLL MISSING" then
			Try_Again = false
		end


-- If memento is cake and it's locked, check for old ones.
	elseif memento == "cake" and GetCollectibleUnlockStateById(mementoID) == COLLECTIBLE_UNLOCK_STATE_LOCKED then
		mementoID = EVT.WhichCake()
		if mementoID == 0 then
-- 1.96 Reduce messages to once per login
			if New_Event_Msg then
				if EVT.vars.Current_Event == XP_Event_Name[memento] then
					CHAT_ROUTER:AddSystemMessage("|cFF00CCYou need to begin this event to unlock this year's cake!|r")
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFPlease open the Crown Store and select EVENTS->Quest Starters.|r")
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFChoose 'Purchase'. Check that it costs ZERO Crowns, then confirm 'Purchase' to begin quest.|r")
				else
					CHAT_ROUTER:AddSystemMessage("|cFF00CCYou haven't unlocked any cakes, and can't unlock one now.|r")
				end
				New_Event_Msg = false
			end
			Return_msg =  "NO CAKE"
-- 1.981 Stop the insane messages every five minutes
			Try_Again = false
		else
-- 1.96 Reduce messages to once per login
			if New_Event_Msg then
				if EVT.vars.Current_Event == XP_Event_Name[memento] then
					CHAT_ROUTER:AddSystemMessage("|cFF00CCYou need to begin this event to unlock this year's cake to get trade bars,|r")
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFalthough you can get the xp buff from your old cake.|r")
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFPlease open the Crown Store and select EVENTS->Quest Starters.|r")
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFChoose 'Purchase'. Check that it costs ZERO Crowns, then confirm 'Purchase' to begin quest.|r")
				end
				New_Event_Msg = false
			end
			EVT.PlayMemento(mementoID)
			Return_msg = "No new cake-old cake used"
-- 1.981 Stop the insane messages every five minutes
			Try_Again = false
		end

-- If memento is anything else and it's locked
	elseif GetCollectibleUnlockStateById(mementoID) == COLLECTIBLE_UNLOCK_STATE_LOCKED then
		if EVT.vars.Current_Event == XP_Event_Name[memento] then
-- 1.86 Added names, because "need to unlock witch" was just too silly.
			local mementoNames = {
				["pie"] = "The Pie of Misrule",
				["mead"] = "Breda's Bottomless Mead Mug",
				["witch"] = "Witchmother's Whistle",
				["cake"] = "Jubilee Cake",		-- Cake and scroll should never come up here.
				["scroll"] = "Pelinal's Scroll"
				}
-- 1.96 Reduce messages to once per login
			if New_Event_Msg then
				CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCYou need to begin this event to unlock %s!|r",mementoNames[memento]))
				CHAT_ROUTER:AddSystemMessage("|cFFFFFFPlease open the Crown Store and select EVENTS->Quest Starters.|r")
				CHAT_ROUTER:AddSystemMessage("|cFFFFFFChoose 'Purchase'. Check that it costs ZERO Crowns, then confirm 'Purchase' to begin quest.|r")
				New_Event_Msg = false
			end
			Return_msg = "NEED TO UNLOCK " .. memento
-- 1.981 Stop the insane messages every five minutes
			Try_Again = false
		else
--			CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCYou haven't unlocked the %s, and can't unlock it now.|r",memento))
			Return_msg = "CANNOT UNLOCK " .. memento
-- 1.981 Stop the insane messages every five minutes
			Try_Again = false
		end

-- 2.400 Removed old code below
-- If event is Anniversary and tickets are at cap, issue a warning. Use a different cake if one's available, for buff only.
--	elseif EVT.vars.Current_Event == "Anniversary" and memento == "cake" then
	else
		EVT.PlayMemento(mementoID)
		Return_msg = "XP Buff ok"
	end
	return Return_msg, Try_Again
end


-- 1.65 Run when needed. Disable otherwise.
-- /script for i=91300,91400 do if GetAbilityName(i) ~= nil then CHAT_ROUTER:AddSystemMessage(tostring(i) .. GetAbilityName(i)) end end
--[[
function EVT.Find_XP_Buffs()
	local Buff_Names = {
		["Anniversary EXP Buff"] = "cake",
		["Witchmother's Boon"] = "witch",
		["Breda's Magnificent Mead"] = "mead",
		["Jester's Experience Boost Pie"] = "pie",
		["Pelinal's Ferocity"] = "scroll"
		}

	local XP_Buff_IDs = {
		[77123] = "cake",
		[86075] = "mead",
		[91365] = "pie",
		[91368] = "pie",
		[91369] = "pie",
		[91446] = "mead",
		[91449] = "mead",
		[91450] = "mead",
		[91451] = "mead",
		[91453] = "mead",
		[92232] = "scroll",
		[96118] = "witch",
		[118985] = "cake",
		[136348] = "cake",
		[152514] = "cake"
		[167846] = "cake",	-- 2022
		[181478] = "cake"	-- 1.94 2023 cake
		}

	for i=1,200000 do
		if Buff_Names[GetAbilityName(i)] ~= nil then
			if XP_Buff_IDs[i] == nil then
				CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCMISSING!|r %s %s",i,Buff_Names[GetAbilityName(i)]))
			elseif XP_Buff_IDs[i] == Buff_Names[GetAbilityName(i)] then
				CHAT_ROUTER:AddSystemMessage(string.format("OK: %s %s",i,Buff_Names[GetAbilityName(i)]))
			else
				CHAT_ROUTER:AddSystemMessage(string.format("|cFF00CCFIX!|r %s Game: %s EVT: %s",i,Buff_Names[GetAbilityName(i)],XP_Buff_IDs[i]))
			end
		end
	end
end
]]

-- 1.65 Add auto buff
-- 1.67 Added second parameter, error messages. Possible options: "Ok", "Not an XP event", "Auto-buff will not remove your old Pelinal Scroll buff", "Auto-buff will not remove your old double XP buff"
-- First parameter returns the time that the buff ends, not how long remains. If there's a buff running that won't be auto removed, add enough time to that that auto buff won't happen until it runs out.
-- It seems that finish (from GetUnitBuffInfo) and GetGameTimeMillseconds are both seconds/milliseconds since signon (very weird). Using UTC time code from FindCurrentTime (which is GetTimeStamp except when testing).
function EVT.XP_Buff_Time()
	local XP_Buff_Type = "none"
	local XP_Buff_IDs = {
		[77123] = "cake",
		[86075] = "mead",
		[91365] = "pie",
		[91368] = "pie",
		[91369] = "pie",
		[91446] = "mead",
		[91449] = "mead",
		[91450] = "mead",
		[91451] = "mead",
		[91453] = "mead",
		[92232] = "scroll",
		[96118] = "witch",
		[118985] = "cake",
		[136348] = "cake",
		[152514] = "cake",
		[167846] = "cake",	-- 2022
		[181478] = "cake"	-- 1.94 2023 cake
		}
-- http://esolog.uesp.net/viewlog.php?search=Anniversary+EXP+Buff&searchtype=

-- EVT.Find_XP_Buffs() -- Enable this temporarily as needed, to get more codes to add to the table above.

-- Check if this is an XP event.
	if EVT.XP_Event() then
--		EVT.PrintDebug("|c00CCFFXP Buff Event: " .. EVT.vars.Current_Event)
	else
		local BuffEndTime = EVT_DATE_UNKNOWN
		if EVT.vars.Current_Event == "None" then
			BuffEndTime = EVT_EVENT_START
			EVT.PrintDebug("|c00CCFFNo event running. Returning start date as next time to check for auto buff.")
		else
			BuffEndTime = EVT_EVENT_END
			EVT.PrintDebug("|c00CCFFNot an XP event. Returning end date as next time to check for auto buff.")
		end
		return BuffEndTime, "Not an XP event"
	end

-- Finish is when the buff ends, in seconds, from the time the player signed on. Subtract GetGameTime (time from signon to current) from that, to get the time buff ends from current time.
-- for i = 1, GetNumBuffs("player") do name = GetUnitBuffInfo("player", i) d(name) end
	for i = 1, GetNumBuffs("player") do
		local name, _, finish, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
		EVT.PrintDebug(string.format("|c32CD32 Buff: %s FINISH: %s GetGameTimeMilliseconds/1000: %s",name,finish,(GetGameTimeMilliseconds() / 1000)))
		local remaining = finish - (GetGameTimeMilliseconds() / 1000)
		local BuffEndTime = EVT.FindCurrentTime() + remaining
		local timeString = ZO_FormatTime(remaining, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_MINUTES)
		if XP_Buff_IDs[abilityId] ~= nil then
			XP_Buff_Type = XP_Buff_IDs[abilityId]
			EVT.PrintDebug(string.format("Your %s buff runs out in %s minutes.",XP_Buff_Type,timeString))
			local msg = "Ok"
			if (XP_Buff_Type == "scroll") == (EVT.vars.Current_Event == "Whitestrake's Mayhem") then 
			elseif XP_Buff_Type == "scroll" then
				remaining = remaining + EVT.settings.XP_refresh*60 + 1 -- remaining is seconds; refresh setting is minutes
				timeString = ZO_FormatTime(remaining, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_MINUTES)
				BuffEndTime = BuffEndTime + EVT.settings.XP_refresh*60 + 1
				msg = "Auto-buff will not remove your old Pelinal Scroll buff."
				EVT.PrintDebug(string.format("|cFF0000WRONG EVENT!|r Adjusted time is %s minutes. %s",XP_Buff_Type,timeString,msg))
			else
				remaining = remaining + EVT.settings.XP_refresh*60 + 1
				timeString = ZO_FormatTime(remaining, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_MINUTES)
				BuffEndTime = BuffEndTime + EVT.settings.XP_refresh*60 + 1
				msg = "Auto-buff will not remove your old double XP buff."
				EVT.PrintDebug(string.format("|cFF0000WRONG EVENT!|r Adjusted time is %s minutes. %s",XP_Buff_Type,timeString,msg))
			end
			local showdate,showtime = FormatAchievementLinkTimestamp(BuffEndTime)
--			d(string.format("|c32CD32 End buff time: %s %s",showdate,showtime))
			return BuffEndTime, msg
--		else
--			d(string.format("Buff skipped: %s %s",abilityId,name))
		end
	end
	EVT.PrintDebug("|c00CCFFNo buff found. Returning current time.")
	return EVT.FindCurrentTime(), "Ok"
end


--[[function EVT.HandleEVTTest(keyWord)
	d("|cFF00CCHere's a list of your active quests:|r")
	local count = GetNumJournalQuests()
	for i = 1, count do
		local questName, bgText, activeStepText, activeStepType, activeStepTrackerOverrideText, QuestCompleted, QuestTracked, QuestLevel, QuestPushed, QuestType, InstanceDisplayType = GetJournalQuestInfo(i)

--    Returns: string questName, string backgroundText, string activeStepText, number activeStepType, string activeStepTrackerOverrideText, boolean completed, boolean tracked, number questLevel, boolean pushed, number questType, number InstanceDisplayType
-- Tracked: The currently active quest. Pushed: Always seems to be false. Don't know what this is.
		local QuestIsDone = "Completed"
		if QuestCompleted then QuestIsDone = " Completed," else QuestIsDone = " NOT completed," end

--		d(questName .. QuestIsDone)

		local JesterQuest = false
		if questName == "Royal Revelry" then JesterQuest = true end
		if questName == "Springtime Flair" then JesterQuest = true end
		if questName == "A Noble Guest" then JesterQuest = true end
		if questName == "A Foe Most Porcine" then JesterQuest = true end
		if questName == "The King's Spoils" then JesterQuest = true end
		if questName == "Prankster's Carnival" then JesterQuest = true end

		if JesterQuest then d(questName .. QuestIsDone) end

		local numRewards = GetJournalQuestNumRewards(i)
		for j = 1, numRewards do
-- number RewardType, string name, number amount, textureName iconFile, boolean meetsUsageRequirement, number ItemQuality, number:nilable RewardItemType
			local rewardType, rewardname, amount = GetJournalQuestRewardInfo(i, j)
			if rewardType == REWARD_TYPE_EVENT_TICKETS then
				d("|cFFD700" .. rewardname .. "|r " .. string.format("|cFF00CC%s Event Tickets being offered!|r",amount))
			elseif JesterQuest then
				d("|cFFD700" .. rewardname .. "|r")
			end
		end
	end
	d("|cFF00CCEnd of list!|r")
end
]]

function EVT.RegisterSubCommand(cmd, shortname, description, callback)
	local sub = cmd:RegisterSubCommand()
	sub:AddAlias(shortname)
	sub:SetCallback(function() callback(shortname) end)
	sub:SetDescription(description)
end

----------------------------------------
-- RegisterSlashCommands
-- Registers the slash commands to be used by EVT
----------------------------------------
function EVT.RegisterSlashCommands()
	local lsc = LibSlashCommander
	if lsc then
		local cmd

		cmd = lsc:Register("/evt", EVT.HandleEVTCommand, "See your Event details - /evt ? for commands")
		local subcommands = {
--		["info"] = "Show Event info",
--		["chat"] = "Post Event info to chat",
		["ui"] = "Toggle UI",
		["hide"] = "Less chat messages (from EVT)",
		["show"] = "Regular chat messages (restore default)",
--		["dbon"] = "Debugging: On",
--		["dboff"] = "Debugging: Off",
		["done"] = "Mark today's trade bars as done",	-- 1.88 Added
		["undo"] = "Mark today's trade bars as NOT done",
		["help"] = "Display Help",
		["coll"] = "Check your collectibles",		-- 2.000 Added to list
		["?"] = "Display Help",
--		["reset"] = "Reset Ticket Data",
		}

		for sub, desc in pairs(subcommands) do
			EVT.RegisterSubCommand(cmd, sub, desc, EVT.HandleEVTCommand)
		end

		cmd = lsc:Register("/evti", EVT.HandleEVTInfo, "Info about current Event - /evti <event> for others")

-- EVENTUPDATE
		subcommands = {
-- 1.52 Added
		["imp"] = "Impresario",
		["pet"] = "Pet",
		["morph"] = "Morph",
-- 1.62 Added
		["xpbuff"] = "XP Buff Events",

		["next"] = "Upcoming events",
		["begin"] = "Begin (How/Where to Start Event)",
		["box"] = "How to get more event Boxes",
-- 1.78
		["ind"] = "Indriks",
		["cyc"] = "Cycle for Indrik morphs",

-- 1.95 Added "news" (different by server)
		["new"] = "News",

-- *************** ANNUAL EVENTS
-- 1.57 Added "whi" for renamed event
		["mid"] = "Whitestrake's (Mid-Year) Mayhem",
		["whi"] = "Whitestrake's Mayhem",
		["jes"] = "Jesters Festival",
		["ann"] = "Anniversary Jubilee",
		["wit"] = "Witches Festival",
		["und"] = "Undaunted",
-- 1.96 Since "new" is now "news", use "nl" or "lif" for "New Life"
--		["new"] = "New Life",
		["nl"] = "New Life",
		["lif"] = "New Life",
		["zea"] = "Zeal of Zenithar",		-- 1.77, 2.000
		["zen"] = "Zeal of Zenithar",		-- 1.77, 2.000
		["hea"] = "Heart's Week",		-- 2.350

-- *************** NOT YET DEPRECATED EVENTS
		["dae"] = "Daedric War",		-- 1.53; brought back 2.350
		["dea"] = "Daedric War",		-- 1.53 (for people who can't type/spell "Daedric")
		["tam"] = "Pan-Tamriel Celebration",	-- 2.240
		["sea"] = "High Seas",		-- 2.430

-- *************** DEPRECATED EVENTS
-- 2.350		["bre"] = "Legacy of the Bretons",	-- 2.240
-- 2.350		["wea"] = "Fallen Leaves of the West Weald",	-- 2.240, added for U43, deprecated in U44
-- 2.350		["gui"] = "Guilds and Glory",		-- 2.020
-- 2.240		["tel"] = "(Secrets of the) Telvanni",	-- 2.000
-- 2.240		["obl"] = "(Gates of) Oblivion",	-- 2.020
-- 2.000		["dra"] = "Dragon",			-- 1.83 -- 1.87
-- 2.000		["sky"] = "Skyrim",			-- 1.81 -- 1.87
-- 2.000		["hig"] = "High Isle",		-- 1.78
-- 2.000		["one"] = "Year One",
-- 2.000		["bla"] = "(Bounties of) Blackwood",			-- 1.54 deprecated
-- 2.000		["els"] = "Pan-Elsweyr",				-- 1.53 deprecated
-- old		["cwc"] = "Clockwork City",
-- old		["db"] = "Dark Brotherhood/Thieves Guild",
-- old		["ic"] = "Imperial City",
-- old		["los"] = "Lost Treasures",
-- old		["morr"] = "Morrowind",
-- old		["mur"] = "Murkmire",
-- old		["sum"] = "Summerset",
-- old		["tg"] = "Thieves Guild/Dark Brotherhood",
-- 1.62 old	["tri"] = "Tribunal",
-- old		["wro"] = "Wrothgar",
		}

-- 1.95
		subcommands["new"] = "News - " .. string.sub(GetWorldName(),1,2)

		for sub, desc in pairs(subcommands) do
			EVT.RegisterSubCommand(cmd, sub, desc, EVT.HandleEVTInfo)
		end

		cmd = lsc:Register("/evtc", EVT.HandleEVTChat, "Post current event info to chat - /evtc <event> for others")

		for sub, desc in pairs(subcommands) do
			EVT.RegisterSubCommand(cmd, sub, desc, EVT.HandleEVTChat)
		end

		cmd = lsc:Register("/xpbuff", EVT.XPBuff, "Refresh event xp buff")
		local subcommands = {
		["pie"] = "Jester's Fest (Pie of Misrule)",
		["mead"] = "New Life (Breda's Bottomless Mead)",
		["witch"] = "Witches Fest (Witchmother's Whistle)",
		["cake"] = "Anniversary Jubilee (Jubilee Cake)",
		["scroll"] = "Whitestrake's Mayhem (Pelinal's Scroll)",
-- 1.65 Add auto buff -- 1.86 Add "on" and "off" as options
		["auto"] = "Turn automatic XP buff on/off",
		["on"] = "Turn automatic XP buff on",
		["off"] = "Turn automatic XP buff off",
		}

		for sub, desc in pairs(subcommands) do
			EVT.RegisterSubCommand(cmd, sub, desc, EVT.XPBuff)
		end

		cmd = lsc:Register("/rvbuff", EVT.RVBuff, "Share event xp buff using Reveries!")
-- 1.86 Set these separate from xpbuff subcommands: "auto" never should've worked, and "on" and "off" shouldn't either!
		local subcommands = {
		["pie"] = "Jester's Fest (Pie of Misrule)",
		["mead"] = "New Life (Breda's Bottomless Mead)",
		["witch"] = "Witches Fest (Witchmother's Whistle)",
		["cake"] = "Anniversary Jubilee (Jubilee Cake)",
		["scroll"] = "Whitestrake's Mayhem (Pelinal's Scroll)",
		}

		for sub, desc in pairs(subcommands) do
			EVT.RegisterSubCommand(cmd, sub, desc, EVT.RVBuff)
		end

-- 2.000		SLASH_COMMANDS["/evtinfo"] = function() EVT.EventInfo(false) end
--		SLASH_COMMANDS["/evti"] = EVT.HandleEVTInfo
--		SLASH_COMMANDS["/evtc"] = EVT.HandleEVTChat
	else
-- 2.000		SLASH_COMMANDS["/evtinfo"] = function() EVT.EventInfo(false) end

		SLASH_COMMANDS["/evt"] = EVT.HandleEVTCommand
		SLASH_COMMANDS["/evti"] = EVT.HandleEVTInfo
		SLASH_COMMANDS["/evtc"] = EVT.HandleEVTChat
		SLASH_COMMANDS["/xpbuff"] = EVT.XPBuff
		SLASH_COMMANDS["/rvbuff"] = EVT.RVBuff
	end
--	SLASH_COMMANDS["/evtt"] = EVT.HandleEVTTest
-- 1.54 My personal commands to do whatever I need it to do for testing or information. It'll change. Never to be documented.
-- Placed not-first so I can comment them out without having to change "if" and "elseif".
-- Functions used here to be placed immediately above, which can also be commented out or just removed. Whatever. MINE!!
--	SLASH_COMMANDS["/csb"] = EVT.Show_Poll
--	SLASH_COMMANDS["/csb"] = EVT.XP_Buff_Time
--	SLASH_COMMANDS["/csb"] = DisplayCollectibleIDs
--[[	elseif(string.lower(keyWord) == "l1") then
		EVT_DLC_UNLOCKED[1] = false
	elseif(string.lower(keyWord) == "l2") then
		EVT_DLC_UNLOCKED[2] = false
	elseif(string.lower(keyWord) == "u1") then
		EVT_DLC_UNLOCKED[1] = true
	elseif(string.lower(keyWord) == "u2") then
		EVT_DLC_UNLOCKED[2] = true
]]
end


---------------------------------------
-- onCurrencyUpdate
-- Listen if Event Trade Bar currency was received.
-- Parameters: EVENT_CURRENCY_UPDATE (number eventCode, CurrencyType currencyType, CurrencyLocation currencyLocation, number newAmount, number oldAmount, CurrencyChangeReason reason)
-- eventCode (constant 131225 identifies "EVENT_CURRENCY_UPDATE")
-- CurrencyType CURT_EVENT_TICKETS = 9
-- CurrencyLocation CURRENCY_LOCATION_ACCOUNT = 3
-- CurrencyChangeReason possible values 0 (loot), 4 (quest), 72 (crown gift), 1 (spent with vendor), player init (35)
-- EVT.onCurrencyUpdate(EVENT_CURRENCY_UPDATE, CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT, EVT.vars.Total_Tickets+NewTickets, EVT.vars.Total_Tickets, CURRENCY_CHANGE_REASON_LOOT)
---------------------------------------
function EVT.onCurrencyUpdate(_, currencyType, currencyLocation, newAmount, oldAmount, reason)

-- 2.400 Replace CURT_EVENT_TICKETS with CURT_TRADE_BARS
	if currencyType == CURT_TRADE_BARS then
		EVT.PrintDebug("New Trade Bars: " .. tostring(newAmount))

-- 1.57 Add notification if in danger of losing tickets, and wasn't before(in EVTUserInterface).
-- 1.57 Max today & tomorrow
		local MaxToday, MaxTomorrow = EVT.MaxAvailable()
		local Prev_Max_Total = EVT.vars.Total_Tickets + MaxToday

		if reason == CURRENCY_CHANGE_REASON_LOOT or reason == CURRENCY_CHANGE_REASON_QUESTREWARD then
--			EVT.PrintDebug("Trade Bar acquired! Old amount: " .. tostring(oldAmount))
			EVT.vars.Total_Tickets = newAmount
			if reason == CURRENCY_CHANGE_REASON_LOOT then
				EVT.SetTicketTime(newAmount,oldAmount,"Loot")
			else
				EVT.SetTicketTime(newAmount,oldAmount,"Quest")
			end
			EVT.vars.LastUpdated = EVT.FindCurrentTime()
			EVT.ShowVars("Loot")
-- 1.67 Update tickets available from quests
			EVT.QuestTickets()
--[[ 2.240 REMOVED ALL REASONS except loot drop or quest, for processing. Because NOBODY WANTS TO BE PESTERED!
		elseif reason == CURRENCY_CHANGE_REASON_VENDOR then  -- 1
			EVT.vars.Total_Tickets = newAmount
--			EVT.PrintDebug("Trade Bars spent! Old amount: " .. tostring(oldAmount))
			EVT.vars.LastUpdated = EVT.FindCurrentTime()
			EVT.ShowVars("Spent")
-- 2.412 Changed to Reason #27: Bought with Tome Points (can't buy with Crowns anymore, but this is essentially the same)
--	elseif reason == CURRENCY_CHANGE_REASON_PURCHASED_WITH_CROWNS then  -- 72
		elseif reason == 27 then  -- Bought with Tome Points
			EVT.vars.Total_Tickets = newAmount
--			EVT.PrintDebug("Tickets purchased with crowns. Old amount: " .. tostring(oldAmount))
			EVT.vars.LastUpdated = EVT.FindCurrentTime()
			EVT.ShowVars("Crowns")
-- 2.400 Need to update UI when Trade Bar Satchel is opened
		elseif reason == CURRENCY_CHANGE_REASON_LOOT_CURRENCY_CONTAINER then -- 76
			EVT.vars.Total_Tickets = newAmount
--			EVT.SetTicketTime(newAmount,oldAmount,"Loot")
			EVT.vars.LastUpdated = EVT.FindCurrentTime()
			EVT.ShowVars("Loot")
			EVT.PrintDebug("Reason for opening Trade Bar Satchel: " .. tostring(reason))
-- 2.412 Need to update UI when Trade Bars have been spent in Gold Coast Bazaar. No idea what name of the constant is.
		elseif reason == 84 then
			EVT.vars.Total_Tickets = newAmount
--			EVT.SetTicketTime(newAmount,oldAmount,"Loot")
			EVT.vars.LastUpdated = EVT.FindCurrentTime()
			EVT.ShowVars("Spent")
			EVT.PrintDebug("Reason for spending Trade Bars in Gold Coast Bazaar: " .. tostring(reason))
-- 1.34 Set up for new reason for Anniversary Event - didn't happen. Left code here in case someday some other unexpected reason happens.
		elseif reason ~= CURRENCY_CHANGE_REASON_PLAYER_INIT then
			EVT.vars.Total_Tickets = newAmount
-- 2.412 Removed next line, because it's safer to not process misc Trade Bar changes as acquiring from an event
--			EVT.SetTicketTime(newAmount,oldAmount,"Anniversary")
			EVT.vars.LastUpdated = EVT.FindCurrentTime()
			EVT.ShowVars("Loot")
			EVT.PrintDebug("NEW TICKET DROP REASON! " .. tostring(reason))
			]]
		end

--[[ 1.78 In case fragments were purchased
		if EVT.vars.Current_Event == "Undaunted" then
			Fragment1 = EVT.IsItUnlocked("Fragment",10333,"Blessed Rubedite Enamel")
			Fragment2 = EVT.IsItUnlocked("Fragment",10334,"Captured Dragonflame")
			Fragment3 = EVT.IsItUnlocked("Fragment",10335,"Sanctified Metalworking Tools")
			if Fragment1 or Fragment2 or Fragment3 then EVT_PLAN_AHEAD = true end
		end
]]

--[[ 1.62 In case fragments were purchased
		if EVT.vars.Current_Event == "Blackwood" then
			Fragment3 = EVT.IsItUnlocked("Fragment",9164,"Black Iron Stirrups")	-- Black Iron Stirrups (3rd)
			if Fragment3 then EVT_PLAN_AHEAD = false end
		end
]]

-- 2.400 REMOVED
-- 1.57 Add notification if in danger of losing tickets, and wasn't before(in EVTUserInterface).
--		MaxToday, MaxTomorrow = EVT.MaxAvailable()
--		if EVT.vars.Current_Event ~= "Unknown" and EVT.vars.Current_Event ~= "None" and EVT.vars.Total_Tickets + MaxToday > 12 and Prev_Max_Total <= 12 and not EVT_PLAN_AHEAD and reason ~= CURRENCY_CHANGE_REASON_PURCHASED_WITH_CROWNS then
--			EVT.Notification("|cFF0000** WARNING","|rSpend Event Tickets or you could lose some! |cFF0000**|r",SOUNDS.LEVEL_UP)
---			EVT.Notification("|cFF0000** WARNING",string.format("|cFFD700You have %s tickets! |cFF0000**|r",EVT.vars.Total_Tickets),SOUNDS.CHAMPION_POINTS_COMMITTED)
-- EVENTUPDATE
--[[ 1.62 1.80
		elseif EVT_PLAN_AHEAD and EVT.vars.Total_Tickets + MaxToday > 12 and Prev_Max_Total <= 12 and not EVT_FRAGMENTS_DONE then
			EVT.Notification("|cFF0000** WARNING","|rSpend Event Tickets or you could lose some! |cFF0000**|r",SOUNDS.LEVEL_UP)
			EVT.Notification("|cFF0000** WARNING",string.format("|cFFD700You have %s tickets! |cFF0000**|r",EVT.vars.Total_Tickets),SOUNDS.CHAMPION_POINTS_COMMITTED)
			EVT.Notification("|cFF0000** WARNING","|cFFD700You still need a fragment for the Daggerfall Paladin Costume! |cFF0000**|r",SOUNDS.LEVEL_UP)
		elseif EVT_PLAN_AHEAD and EVT_FRAGMENTS_DONE and EVT.vars.Total_Tickets >= 10 and Prev_Max_Total < 10 then
			EVT.Notification("|cFF0000** SAVE TEN TICKETS"," |cFFD700For the final Daggerfall Paladin Costume fragment! |cFF0000**|r",SOUNDS.LEVEL_UP)
]]
--		end

	end
end


----------------------------------------
-- SignonMsg
----------------------------------------
function EVT.SignonMsg()
	EVT.PrintDebug("|cFF00CC ** SignonMsg ** Version " .. tostring(EVT.vars.EVT_version))
	if (EVT.FindCurrentTime() - EVT.vars.Install_Time) < 300 then
		if EVT.vars.Current_Event == "None" or EVT.vars.Current_Event == "Unknown" then
			CHAT_ROUTER:AddSystemMessage("[EVT]: Welcome to Event Tracker, version " .. tostring(EVT.vars.EVT_version))
		else
			CHAT_ROUTER:AddSystemMessage("[EVT]: Welcome to Event Tracker, version " .. tostring(EVT.vars.EVT_version) .. " - " .. EVT.vars.Current_Event .. " Event!")
		end
		CHAT_ROUTER:AddSystemMessage("[EVT]: |cFFD700/evt|r to see your Event info; |cFFD700/evt help|r for other chat commands.")
	else

-- 1.31 This just isn't happening enough, so move it to the end of INIT where it MUST.
--		EVT.ShowVars("Signon")

-- 1.05 Also list /evtinfo, and not as often (if messages aren't minimized to most important only, and it hasn't shown within the past day)
		if not EVT.vars.autoHide and (EVT.FindCurrentTime() - EVT.vars.Message_Time > EVT_MESSAGE_DELAY) then
--[[ 1.95			CHAT_ROUTER:AddSystemMessage("[EVT]: |cFFD700/evt|r to see your Event Tickets; |cFFD700/evt help|r for other chat commands.")

-- 1.50 Added News; leave this alone for news if there is any.
			if EVT.vars.NewsIndex == 0 then
				EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show this once a day
			end
]]
		end
	end

-- 1.95 Moved (from here) this as early as possible, because somehow version is getting updated before entering this function
--WAS Special message, if needed

-- 1.71 Message to let new people know to get IC for free from Crown Store.
	if EVT.vars.Current_Event == "Whitestrake's Mayhem" and not EVT.vars.autoHide then
		local dlc_ID = 154			-- Imperial City
		local collectibleName, _, _, _, Imp_City_unlocked = GetCollectibleInfo(dlc_ID) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
		local DLC_Name = collectibleName .. " DLC"
		EVT.PrintDebug("DLC: " .. dlc_ID .. " " .. DLC_Name .. " unlocked: " .. tostring(Imp_City_unlocked))

		if not Imp_City_unlocked then
			EVT.Notification("|cFF0000** SEE CHAT","|cFFD700Get Imperial City, FREE! |cFF0000**|r",SOUNDS.CHAMPION_POINTS_COMMITTED)
			CHAT_ROUTER:AddSystemMessage("|cFF00CCGet Imperial City DLC FREE!|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFGo to the Crown Store, DLC, select Imperial City,|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFPurchase, (check it costs zero!), confirm!|r")
		end
	end

--[[ 1.86 removed 1.83 Message to let new people know to get High Isle bundle for free from Crown Store.
	if EVT.FindCurrentTime() < (1664546400 + EVT_ONE_DAY*21) and (EVT.FindCurrentTime() - EVT.vars.Message_Time > EVT_MESSAGE_DELAY) and not EVT.vars.autoHide then
		local dlc_ID = 10053			-- High Isle
		local collectibleName, _, _, _, High_Isle_unlocked = GetCollectibleInfo(dlc_ID) -- Will return true or false.
		local DLC_Name = collectibleName .. " Chapter"
		EVT.PrintDebug("Chapter: " .. dlc_ID .. " " .. DLC_Name .. " unlocked: " .. tostring(High_Isle_unlocked))

		dlc_ID = 10416			-- Plant Yourself emote
		collectibleName, _, _, _, reward_unlocked = GetCollectibleInfo(dlc_ID)
		DLC_Name = collectibleName .. " emote"
		EVT.PrintDebug("Emote: " .. dlc_ID .. " " .. DLC_Name .. " unlocked: " .. tostring(reward_unlocked))

		if High_Isle_unlocked then
			if not reward_unlocked then
				EVT.Notification("|cFF0000** FREE","|cFFD700Get your Heroes of High Isle Reward bundle! |cFF0000**|r",SOUNDS.CHAMPION_POINTS_COMMITTED)
				CHAT_ROUTER:AddSystemMessage("|cFF00CCGet your Heroes of High Isle Reward bundle FREE!|r")
				CHAT_ROUTER:AddSystemMessage("|cFFFFFFGo to the Crown Store, Special Offers!r")
				CHAT_ROUTER:AddSystemMessage("|cFFFFFFPurchase, (check it costs zero!), confirm!|r")
				CHAT_ROUTER:AddSystemMessage(" ")
			end

			dlc_ID = 9791			-- Appleback Salamander pet
			collectibleName, _, _, _, reward_unlocked = GetCollectibleInfo(dlc_ID)
			DLC_Name = collectibleName .. " pet"
			EVT.PrintDebug("Pet: " .. dlc_ID .. " " .. DLC_Name .. " unlocked: " .. tostring(reward_unlocked))

			if IsESOPlusSubscriber() and not reward_unlocked then
				CHAT_ROUTER:AddSystemMessage("|cFF00CCGet your Appleback Salamander pet FREE|r")
				CHAT_ROUTER:AddSystemMessage("|cFFFFFF(if you have a paid ESO+ membership)|r")
				CHAT_ROUTER:AddSystemMessage("|cFFFFFFGo to the Crown Store, Featured|r")
				CHAT_ROUTER:AddSystemMessage("|cFFFFFFPurchase, (check it costs zero!), confirm!|r")
			end
		end
		EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours
	else
		EVT.PrintDebug(" ")
		EVT.PrintDebug(string.format("|cFF00CCNO MESSAGE!! Current time: %s Message time: %s Message delay: %s|r",EVT.FindCurrentTime(),EVT.vars.Message_Time,EVT_MESSAGE_DELAY))
		EVT.PrintDebug(" ")
	end
]]

-- 1.46 warning about missing boxes
--	CHAT_ROUTER:AddSystemMessage("version " .. tostring(EVT.vars.EVT_version))
--	if EVT.vars.EVT_version < 1.46  or (EVT.vars.Current_Event == "Tribunal" and EVT.FindCurrentTime() < EVT_EVENT_END and EVT.vars.T_ToDo[1]+EVT.vars.T_ToDo[2]==2 and EVT.vars.T_Time[2]>EVT_EVENT_START) then
--		CHAT_ROUTER:AddSystemMessage("|cFF00CCWARNING - If you want max boxes, get Vvardenfall tickets BEFORE Clockwork City!|r |cFFD700/evti box|r |cFFFFFFfor details.|r")
--	end

-- 1.50 Added NEWS! Update as needed.
-- 1.31 Added special message about start of Anniversary event, no more often than once every 3 hours at sign on, until it starts. -- 1.50 2021 Updated & improved.
-- 1.57 New message for Year One. -- 1.58 Had left in ~= Year One that was here for testing.
-- 2.361 Daedric War (only Summerset can be locked)
--	EVT.PrintDebug(string.format("|cFF00CCEvent: %s autohide: %s Current time - prev time: %s Delay: %s",EVT.vars.Current_Event,tostring(EVT.vars.autoHide),EVT.FindCurrentTime() - EVT.vars.Message_Time,EVT_MESSAGE_DELAY))
	if not EVT.vars.autoHide and (EVT.FindCurrentTime() - EVT.vars.Message_Time > EVT_MESSAGE_DELAY) then
		EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours
-- This should be included for every event that has a lock.
		if EVT.vars.Current_Event == "Daedric War" then
			if not EVT_DLC_UNLOCKED[1] then
				EVT.IsItUnlocked(DLC_Types[1],DLC_IDs[1],DLC_Names[1])
-- 2.021 was missing ".." (probably for a very long time)
--[[				if EVT.vars.Current_Event == "Bretons" then
					CHAT_ROUTER:AddSystemMessage("|cFF6900[EVT]: Blackwood, Deadlands, and the following dungeons do not appear to be unlocked. ")
					CHAT_ROUTER:AddSystemMessage("|cFF6900(Dungeons: Red Petal Bastion, The Cauldron, Dread Cellar, and Black Drake Villa)")
				else
]]
					CHAT_ROUTER:AddSystemMessage("|cFF6900[EVT]: " .. DLC_Names[1] .. " " .. DLC_Types[1] .. " does not appear to be unlocked. ")
--				end
				CHAT_ROUTER:AddSystemMessage(zo_strformat("|cFF6900<<1[/one trade bar/$d trade bars]>> not available.",EVT.vars.T_Tickets[1]))

--[[				local Fragment1 = EVT.IsItUnlocked("Fragment",10333,"Blessed Rubedite Enamel")
				local Fragment2 = EVT.IsItUnlocked("Fragment",10334,"Captured Dragonflame")
				local Fragment3 = EVT.IsItUnlocked("Fragment",10335,"Sanctified Metalworking Tools")
				if (Fragment1 and Fragment2) and not Fragment3 and EVT.vars.Total_Tickets > 9 then
					EVT.Notification("|cFF0000** SEE CHAT","|cFFD700Go to the Impresario to get your Costume! |cFF0000**|r",SOUNDS.CHAMPION_POINTS_COMMITTED)
					CHAT_ROUTER:AddSystemMessage("|cFF00CCYour Daggerfall Paladin Costume is available!|r")
					CHAT_ROUTER:AddSystemMessage("|cFFFFFFGo to the Impresario to purchase the last fragment for it.|r")
				end
]]
			end
			if not EVT_DLC_UNLOCKED[2] then
				EVT.IsItUnlocked(DLC_Types[2],DLC_IDs[2],DLC_Names[2])
					CHAT_ROUTER:AddSystemMessage("|cFF6900[EVT]: " .. DLC_Names[2] .. " " .. DLC_Types[2] .. " does not appear to be unlocked. ")
					CHAT_ROUTER:AddSystemMessage(zo_strformat("|cFF6900<<1[/one trade bar/$d trade bars]>> not available.",EVT.vars.T_Tickets[2]))
			end
		end

-- ******************************************
-- EVENTUPDATE LOCK MESSAGE
-- ******************************************
-- goes here for events in DLC/Chapter areas

--		EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours

--[[		CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFNew feature!|r |cFFD700/xpbuff auto|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFTurns on AUTOMATIC event buff!!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFApplies to ALL of your characters!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************************|r")
		EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours
]]
--		if EVT.vars.NewsIndex == 3 then -- fuschia

--[[ 1.62 Not using cycles with multiple messages, but I need 3 separate options to choose which message
		local cost = 10 -- cost of third fragment behind locked paywall
		if EVT_DLC_UNLOCKED[1] then -- aqua
			CHAT_ROUTER:AddSystemMessage("|c00CCFF********************************************|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFIf Mirri or Bastian are summoned when you|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFopen a |H0:item:181433:34:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h,|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFa piece of Companion's gear will be in it!|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF********************************************|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFAll 2021 fragments will be available again during New Life!")
		elseif EVT_PLAN_AHEAD and cost <= EVT.vars.Total_Tickets then -- fuschia
			CHAT_ROUTER:AddSystemMessage("|cFF00CC*********************************************************|r")
			CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFYou can get the Dagonic Quasigriff mount NOW if you go|r")
			CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFto The Impresario (|H1:help:341|h|h)|r") -- [Tutorial: Events - Event Merchant]
			CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFand buy |H1:collectible:9164|h|h. All 2021 morph fragments|r") -- [Black Iron Stirrups]
			CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFwill also be available during New Life in December.|r")
			CHAT_ROUTER:AddSystemMessage("|cFF00CC*********************************************************|r")
		elseif EVT_PLAN_AHEAD then -- yellow
			CHAT_ROUTER:AddSystemMessage("|cFFD700***********************************************************|r")
			CHAT_ROUTER:AddSystemMessage("|cFFD700**|r |cFFFFFFTo morph an |H1:collectible:8124|h|h into a Dagonic Quasigriff|r") -- [Unstable Morpholith]
			CHAT_ROUTER:AddSystemMessage("|cFFD700**|r |cFFFFFFmount, you still need one more fragment. You don't have|r")
			CHAT_ROUTER:AddSystemMessage("|cFFD700**|r |cFFFFFFenough tickets to get it now, but all 2021 fragments|r")
			CHAT_ROUTER:AddSystemMessage("|cFFD700**|r |cFFFFFFwill be available again during New Life in December.|r")
			CHAT_ROUTER:AddSystemMessage("|cFFD700***********************************************************|r")
		end
			EVT.vars.NewsIndex = EVT.vars.NewsIndex - 3
]]
--[[
		if EVT.vars.NewsIndex == 2 then -- fuschia
			CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************|r")
			CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFNew reset time for Event|r")
			if GetWorldName() == "NA Megaserver" then
				CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFTickets now 4 hrs LATER!|r")
				CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFLast partial-day very limited!|r")
			elseif GetWorldName() == "EU Megaserver" then
				CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFTickets now 3 hrs EARLIER!|r")
				CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFFirst partial-day is shorter!|r")
			end
			CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r  |cFFD700/evti news|r  |cFFFFFFfor news|r")
			EVT.vars.NewsIndex = EVT.vars.NewsIndex - 1
		elseif EVT.vars.NewsIndex == 1 then -- aqua
			CHAT_ROUTER:AddSystemMessage("|c00CCFF********************************|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFF|H1:collectible:10913|h|h Fragments|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFwill still be available|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFthrough next quarter's events.|r")
			CHAT_ROUTER:AddSystemMessage("|c00CCFF********************************|r")
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r  |cFFD700/evti news|r  |cFFFFFFfor news|r")
			EVT.vars.NewsIndex = EVT.vars.NewsIndex - 1

--		elseif (EVT.FindCurrentTime() - EVT.vars.Message_Time > EVT_MESSAGE_DELAY) then
			EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours
			EVT.vars.NewsIndex = 2
		end
]]
	end

-- 1.95 Test what messages look like
	if EVT.vars.debug then
--[[		CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFNew reset time for Event|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFTickets now 4 hrs LATER!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFLast partial-day very limited!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r  |cFFD700/evti news|r  |cFFFFFFfor news|r")
		CHAT_ROUTER:AddSystemMessage(".")
		CHAT_ROUTER:AddSystemMessage("|c00CCFF********************************|r")
		CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFF|H1:collectible:10913|h|h Fragments|r")
		CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFwill still be available|r")
		CHAT_ROUTER:AddSystemMessage("|c00CCFF**|r |cFFFFFFthrough next quarter's events.|r")
		CHAT_ROUTER:AddSystemMessage("|c00CCFF********************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r  |cFFD700/evti news|r  |cFFFFFFfor news|r")
		CHAT_ROUTER:AddSystemMessage(".")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFNew reset time for Event|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFTickets now 3 hrs EARLIER!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC**|r |cFFFFFFFirst partial-day is shorter!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF00CC******************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r  |cFFD700/evti news|r  |cFFFFFFfor news|r")
]]
	end

--[[ 1.42 Special message about Undaunted event being rescheduled - if this is the first time running after update, then force message
	if EVT.FindCurrentTime() < 1606748400 - EVT_ONE_DAY*3 and not EVT.vars.autoHide and (EVT.FindCurrentTime() - EVT.vars.Message_Time > EVT_MESSAGE_DELAY) then
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFUndaunted Event has been delayed, and will run December 3-15.|r")
		CHAT_ROUTER:AddSystemMessage("|c00CCFFNew Life will begin TWO DAYS after Undaunted ends, and will run December 17-January 5, 2021.|r")
		EVT_MESSAGE_DELAY = EVT_ONE_HOUR*6
		EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours
	end

-- 1.42 Is message called for?
	if EVT.FindCurrentTime() > EVT_EVENT_END - EVT_ONE_DAY*5 and EVT.FindCurrentTime() < EVT_EVENT_END and not EVT.vars.autoHide and (EVT.FindCurrentTime() - EVT.vars.Message_Time > EVT_MESSAGE_DELAY) then
		if EVT.vars.Current_Event == "Witches" then	-- 1.40 Time change warning
			CHAT_ROUTER:AddSystemMessage("|cFFFFFFNOTE: Event will end|r |cFF0000ONE HOUR EARLIER THAN USUAL!|r |cFFFFFFBecause of the US time change.|r")
		elseif EVT.vars.Current_Event == "Undaunted" then	-- 1.42 Warning about (almost) back-to-back events
			CHAT_ROUTER:AddSystemMessage("|cFF0000NEW LIFE FESTIVAL BEGINS|r |cFFFFFF48 hours after Undaunted Event ends!|r")
		end
		EVT.vars.Message_Time = EVT.FindCurrentTime()    -- Only show message once every few hours
	end
]]

--[[ 2.201 One-time message. Fuschia FF00CC
	if EVT.vars.EVT_version < 2.202 and GetWorldName() == "NA Megaserver" then
		CHAT_ROUTER:AddSystemMessage("|cFF0000******************************|r")
		CHAT_ROUTER:AddSystemMessage("|cFF0000**|r |cFFFFFFAnniversary Jubilee|r")
		CHAT_ROUTER:AddSystemMessage("|cFF0000**|r |cFFFFFFFinal partial day|r")
		CHAT_ROUTER:AddSystemMessage("|cFF0000** GONE due to SHUTDOWN!!|r")
		CHAT_ROUTER:AddSystemMessage("|cFF0000**|r |cFFFFFFNA SERVER ONLY|r")
		CHAT_ROUTER:AddSystemMessage("|cFF0000******************************|r")
--		CHAT_ROUTER:AddSystemMessage("|cFFFFFFType|r  |cFFD700/evti news|r  |cFFFFFFfor news|r")
	end
]]

-- 2.390 In EVTUserInterface
	if EVT.settings.InfoBox == 0 then
		EVT.ShowDialog()
	end
end


----------------------------------------
-- Initialize
----------------------------------------
function EVT.Initialize()
	ZO_CreateStringId("SI_BINDING_NAME_EVT_TOGGLE_UI", "Toggle UI")
--	ZO_CreateStringId("SI_BINDING_NAME_EVT_ADVANCE_DAY", "Advance 1 day")
--	ZO_CreateStringId("SI_BINDING_NAME_EVT_ADVANCE_HOUR", "Advance 1 hour")
--	ZO_CreateStringId("SI_BINDING_NAME_EVT_ADVANCE_END_HOUR", "Advance 58 minutes")
--	EVENT_MANAGER:UnregisterForEvent(EVT.name, EVENT_ADD_ON_LOADED)
-- 1.76
	EVENT_MANAGER:UnregisterForUpdate(EVT.name)
-- 1.84	EVENT_MANAGER:UnregisterForEvent(EVT.name, EVENT_PLAYER_ACTIVATED)

-- 2.390 In EVTUserInterface
	EVT.initializeDialogs()

-- Get saved variables
	EVT.vars = ZO_SavedVars:NewAccountWide("EventTrackerVars",
		EVT.variable_version,
		GetWorldName(),
		EVT.default)
--	CHAT_ROUTER:AddSystemMessage("version " .. tostring(EVT.vars.EVT_version))

	EVT.settings = ZO_SavedVars:NewAccountWide("EventTrackerShared",
		1,
		nil,
		EVT.defaultSettings,
		nil,
		"$SharedSettings")

-- 1.95 Moved this (to here) as early as possible, because somehow version is getting updated before entering this function
--EVENTUPDATE Special message, if needed
	if EVT.vars.EVT_version < 1.95 then
		EVT.vars.Message_Time = 0
		EVT_MESSAGE_DELAY = EVT_ONE_HOUR*24
--		EVT.vars.NewsIndex = 2
		EVT.PrintDebug(string.format("|cFF00CCSET: Message time: %s Message delay: %s|r",EVT.vars.Message_Time,EVT_MESSAGE_DELAY))
	end

-- Time test needs data to be updated to work properly
	if EVT.FindCurrentTime() > GetTimeStamp() then
		local TimeDif = EVT.FindCurrentTime() - GetTimeStamp()
		local ShowDate1, ShowTime1 = FormatAchievementLinkTimestamp(EVT.vars.Message_Time)
		local ShowDate2, ShowTime2 = FormatAchievementLinkTimestamp(EVT.vars.Message_Time+TimeDif)
		EVT.vars.debug = true
		EVT.PrintDebug(string.format("Message time changed from: %s %s to %s %s",ShowDate1, ShowTime1, ShowDate2, ShowTime2))
		ShowDate1, ShowTime1 = FormatAchievementLinkTimestamp(EVT.vars.Install_Time)
		ShowDate2, ShowTime2 = FormatAchievementLinkTimestamp(EVT.vars.Install_Time+TimeDif)
		EVT.PrintDebug(string.format("Install time changed from: %s %s to %s %s",ShowDate1, ShowTime1, ShowDate2, ShowTime2))
		ShowDate1, ShowTime1 = FormatAchievementLinkTimestamp(EVT.vars.LastUpdated)
		ShowDate2, ShowTime2 = FormatAchievementLinkTimestamp(EVT.vars.LastUpdated+TimeDif)
		EVT.PrintDebug(string.format("Last updated time changed from: %s %s to %s %s",ShowDate1, ShowTime1, ShowDate2, ShowTime2))
		EVT.vars.Message_Time = EVT.vars.Message_Time + TimeDif
		EVT.vars.Install_Time = EVT.vars.Install_Time + TimeDif
		EVT.vars.LastUpdated = EVT.vars.LastUpdated + TimeDif
		ShowDate1, ShowTime1 = FormatAchievementLinkTimestamp(EVT.vars.T_Time[1])
		ShowDate2, ShowTime2 = FormatAchievementLinkTimestamp(EVT.vars.T_Time[1]+TimeDif)
		if EVT.vars.T_Time[1] > 0 then
			EVT.vars.T_Time[1] = EVT.vars.T_Time[1] + TimeDif
--			EVT.vars.T_Time[1] = EVT.FindCurrentTime() - EVT_ONE_HOUR*6
			EVT.PrintDebug(string.format(EVT.vars.T_Types[1] .. " trade bar time changed from: %s %s to %s %s",ShowDate1, ShowTime1, ShowDate2, ShowTime2))
		else
			EVT.PrintDebug(string.format(EVT.vars.T_Types[1] .. " trade bar time unchanged: %s %s",ShowDate1, ShowTime1))
		end
		ShowDate1, ShowTime1 = FormatAchievementLinkTimestamp(EVT.vars.T_Time[2])
		ShowDate2, ShowTime2 = FormatAchievementLinkTimestamp(EVT.vars.T_Time[2]+TimeDif)
		if EVT.vars.T_Time[2] > 0 then
			EVT.vars.T_Time[2] = EVT.vars.T_Time[2] + TimeDif
			EVT.PrintDebug(string.format(EVT.vars.T_Types[2] .. " trade bar time changed from: %s %s to %s %s",ShowDate1, ShowTime1, ShowDate2, ShowTime2))
		else
			EVT.PrintDebug(string.format(EVT.vars.T_Types[2] .. " trade bar time unchanged: %s %s",ShowDate1, ShowTime1))
		end
		ShowDate1, ShowTime1 = FormatAchievementLinkTimestamp(EVT.vars.T_Time[3])
		ShowDate2, ShowTime2 = FormatAchievementLinkTimestamp(EVT.vars.T_Time[3]+TimeDif)
		if EVT.vars.T_Time[3] > 0 then
			EVT.vars.T_Time[3] = EVT.vars.T_Time[3] + TimeDif
			EVT.PrintDebug(string.format(EVT.vars.T_Types[3] .. " trade bar time changed from: %s %s to %s %s",ShowDate1, ShowTime1, ShowDate2, ShowTime2))
		else
			EVT.PrintDebug(string.format(EVT.vars.T_Types[3] .. " trade bar time unchanged: %s %s",ShowDate1, ShowTime1))
		end
		EVT.vars.debug = false
	end

-- 2.200 MUST REMOVE THESE THREE LINES when LIBRARY is re-activated!
--EVT_EVENT_INFO_BEGIN = EVT.lang[lang_index]["Begin"]
--EVT_EVENT_INFO_BOX = EVT.lang[lang_index]["Box"]
--EVT_UPCOMING_INFO = EVT.lang[lang_index]["Upcoming"]

--[[ 2.200
-- 2.100 LIBRARY!!!
	local IsEvent,EventCode,EventCode_next,EventCode_future,L_WhichQuarter,L_WhichMonthInQuarter = LibEVT:CurrentEvent()
	if not IsEvent then EventCode=EventCode_next EventCode_next=EventCode_future end
	local Lname,Lstart,Lend,Lnum_t1,Lnum_t2,Lsource_t1,Lsource_t2,Ltype_t1,Ltype_t2,LockIndex_1,LockIndex_2,Lxp_event = LibEVT:EventInfo(EventCode)

	EVT_EVENT_START = Lstart
	EVT_EVENT_END   = Lend
	EVT_NEXT_EVENT  = Lname
	EVT_EVENT_DETAILS = {
			["Name"] = Lname,
			["T_Types_1"] = Lsource_t1,
			["T_Types_2"] = Lsource_t2,
			["T_Tickets"] = {Lnum_t1,Lnum_t2,0,0,},
			["T_ToDo"] = {1,0,0,},
			}
	if Lnum_t2 > 0 then EVT_EVENT_DETAILS["T_ToDo"][2] = 1 end

	local lang_index = "EVENT INFO " .. EventCode
	EVT_EVENT_INFO_BEGIN = EVT.lang[lang_index]["Begin"]
	EVT_EVENT_INFO_BOX = EVT.lang[lang_index]["Box"]
	EVT_UPCOMING_INFO = EVT.lang[lang_index]["Upcoming"]

-- 2.110 Use library to add dates to info
	if EVT_EVENT_END == EVT_DATE_UNKNOWN and EVT_EVENT_START == EVT_DATE_UNKNOWN then
		EVT_CURRENT_INFO = EVT.lang[lang_index]["Info"]
	elseif EVT_EVENT_END == EVT_DATE_UNKNOWN and EVT_EVENT_START ~= EVT_DATE_UNKNOWN then
		EVT_CURRENT_INFO = string.format("%s. %s",os.date(EVT.lang["DateFormatStart"], EVT_EVENT_START),EVT.lang[lang_index]["Info"])
-- If same month, example: "Jan. 18-30, 2024" (in English), "18.-30.Jan 2024" (German)
	elseif os.date("%m", EVT_EVENT_START) == os.date("%m", EVT_EVENT_END) then
		EVT_CURRENT_INFO = string.format("%s%s. %s",os.date(EVT.lang["DateFormat1a"], EVT_EVENT_START),os.date(EVT.lang["DateFormat1b"], EVT_EVENT_END),EVT.lang[lang_index]["Info"])
-- Different months: "Mar. 28-Apr. 4, 2024" (en), "28.Mar-4.Apr 2024" (de)
	else
		EVT_CURRENT_INFO = string.format("%s%s. %s",os.date(EVT.lang["DateFormat2a"], EVT_EVENT_START),os.date(EVT.lang["DateFormat2b"], EVT_EVENT_END),EVT.lang[lang_index]["Info"])
	end

	WhichQuarter = L_WhichQuarter
	WhichMonthInQuarter = L_WhichMonthInQuarter
2.200 END]]

-- 1.83 Start next event in 5 minutes if debug is on: Need to do this to test auto xp buffing, and also UI issues just before event starts
--	EVT.AdvanceTime("Event")

-- 1.50 Cycle the FUTURE stack down as far as needed. "start_now" parameter is false; if new event is needed to start, it'll be set up and happen later.
-- Function in EVTUtils near the end.
--	EVT.NextEvent(false)



-- 2.301 REVERSED: Non-PTS first. PTS 1.43
	if GetWorldName() ~= "PTS" then

		EVT.PrintDebug("Server: " .. GetWorldName())

-- EVENTUPDATE NEXT EVENT (Especially Back to back events!)
-- 2.301 Everything from here to PTS was above the "PTS" code. Now in "non-PTS".
-- 2.301 ANNIVERSARY
		if EVT.vars.Current_Event == "Anniversary" and EVT.vars.T_Tickets[1] == 3 then
			EVT.vars.T_Tickets[1] = 300
		end

-- **********************************************************************************
-- **********************************************************************************
-- 1.75 If there's another known event coming, put it here.
		if EVT_EVENT_END < EVT.FindCurrentTime() then


-- 2.430 10/21-11/4/26 (EST) NO PTS
EVT_EVENT_START = MonthCode["6A"] + EVT_ONE_DAY*21
EVT_EVENT_END   = MonthCode["6B"] + EVT_ONE_DAY*4 -- EST
EVT_NEXT_EVENT  = "Witches"
EVT_EVENT_DETAILS = {
["Name"] = "Witches",
["T_Types_1"] = "Witches",
["T_Types_2"] = "not used",
["T_Tickets"] = {2,0,0,0,},
["T_ToDo"] = {1,0,0,},
}

EVT_EVENT_INFO_BEGIN = "Check Crown Store for FREE starter quest."
EVT_EVENT_INFO_BOX = "There's a chance of additional boxes from any boss, even the little daedric incursions that pop up all over. LOOT ALL BODIES AND REWARD CHESTS!"
EVT_UPCOMING_INFO = "Nov: Mayhem (NO TRADE BARS). Dec: New Life(300)*. Feb: Heart's Week(200). March: Jester's(300)*. April: Anniversary(300)*. (number)=Tickets per day, per account. *=DBL XP"



		end
-- **********************************************************************************
-- **********************************************************************************


--[[ SAFETY NET - If safety net has triggered event to start, make sure event start date is set prior to today. Doesn't matter when; but must be before today.
	if EVT.vars.Current_Event ~= "None" and EVT_EVENT_START == EVT_DATE_UNKNOWN then -- 1.66 Event start date should never be unknown. Yet. Not tested.
		EVT_EVENT_START = EVT.FindCurrentTime() - EVT_ONE_DAY*2
	end
]]

--[[ 2.202 NA event lost final partial day due to shutdown
	if GetWorldName() == "NA Megaserver" then
		EVT_EVENT_END   = 1711893600 + EVT_ONE_DAY*25 - EVT_ONE_HOUR*4
	end
]]



-- 2.301 PTS
	else

		CHAT_ROUTER:AddSystemMessage("|cFF00CCThis is the PTS!|r")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFF*************************|r")
		if GetAPIVersion() == 101038 then
			CHAT_ROUTER:AddSystemMessage("|cFFD700** ! EU SERVER COPY !  **|r")
		end
		if ((GetTimeStamp()+GetTimeUntilNextDailyLoginRewardClaimS())%86400)/3600 < 5 then
			CHAT_ROUTER:AddSystemMessage("|cFFD700** EU DAILY RESET TIME **|r")
		else
			CHAT_ROUTER:AddSystemMessage("|cFFD700** NA DAILY RESET TIME **|r")
		end
		CHAT_ROUTER:AddSystemMessage("|cFFFFFF*************************|r")

-- 2.100 LIBRARY REMOVED 2.200 restored
-- Defaults
		EVT_EVENT_START = EVT_DATE_UNKNOWN
		EVT_EVENT_END = EVT_DATE_UNKNOWN
		EVT_NEXT_EVENT = "None"
		EVT_UPCOMING_INFO = "I have no idea what's coming next... this is the PTS!!"

-- **********************************************************************************
-- **********************************************************************************
-- PTS Event





-- If a second event is going to be tested, put it here.
		if EVT_EVENT_END < EVT.FindCurrentTime() then





		end
-- **********************************************************************************
-- **********************************************************************************


		if EVT_EVENT_END < EVT.FindCurrentTime() then
-- Leave this here to reset to "none" after PTS event ends, when there isn't anything else to put here.
			EVT_EVENT_START = EVT_DATE_UNKNOWN
			EVT_EVENT_END = EVT_DATE_UNKNOWN
			EVT_NEXT_EVENT = "None"
			EVT_UPCOMING_INFO = "I have no idea what's coming next... this is the PTS!!"

		end

		if EVT_NEXT_EVENT ~= "None" then
			CHAT_ROUTER:AddSystemMessage("|cFF00CCPTS TEST!!|r |cFFFFFFEvent:|r |c00CCFF" .. EVT_NEXT_EVENT .. "|r")
			if EVT_EVENT_START == EVT_DATE_UNKNOWN then
				CHAT_ROUTER:AddSystemMessage("Start Date UNKNOWN")
			else
				CHAT_ROUTER:AddSystemMessage(string.format("Start: %s %s",FormatAchievementLinkTimestamp(EVT_EVENT_START)))
			end

			if EVT_EVENT_END == EVT_DATE_UNKNOWN then
				CHAT_ROUTER:AddSystemMessage("End Date UNKNOWN")
			else
				CHAT_ROUTER:AddSystemMessage(string.format("End: %s %s",FormatAchievementLinkTimestamp(EVT_EVENT_END)))
			end

		end
--2.100 END LIBRARY REMOVED 2.200 restored
	end

-- 2.301 Moved after PTS 1.65 Added skulls for Witches
	if EVT.vars.Current_Event == "Witches" then
		if EVT.vars.Skulls_Done == nil then EVT.vars.Skulls_Done = EVT_SKULLS_DONE end
			else
				EVT.vars.Skulls_Done = nil
				end


-- 1.66 If there is a new event ready to be started, check that there isn't some old event that hasn't been closed properly.
-- EVENTUPDATE Set this to pick up next event instead, when I set that up.
	if EVT_EVENT_END < EVT.FindCurrentTime() then
		EVT.PrintDebug("|cFF00CCLast known event has ended - set dates to Unknown and event to NONE.")
		EVT_EVENT_START = EVT_DATE_UNKNOWN
		EVT_EVENT_END = EVT_DATE_UNKNOWN
		if EVT.vars.Current_Event ~= "None" then
			EVT.vars.Current_Event = "None"
			EVT.ClearData()
		end
	elseif EVT.vars.Current_Event ~= EVT_NEXT_EVENT and EVT.vars.Current_Event ~= "None" then
		EVT.vars.Current_Event = "None"
		EVT.ClearData()
	end

	if EVT_EVENT_START == EVT_DATE_UNKNOWN then
		EVT.PrintDebug("Start Date UNKNOWN")
	else
		EVT.PrintDebug(string.format("Start: %s %s",FormatAchievementLinkTimestamp(EVT_EVENT_START)))
	end

	if EVT_EVENT_END == EVT_DATE_UNKNOWN then
		EVT.PrintDebug("End Date UNKNOWN")
	else
		EVT.PrintDebug(string.format("End: %s %s",FormatAchievementLinkTimestamp(EVT_EVENT_END)))
	end

-- StorybookTerror found the function for Total_Tickets, so correct them
-- Warning message if numbers don't match. 1.95 Added "/evt done" to message
--[[ 2.430 Removed warning
	if EVT.vars.Total_Tickets ~= GetCurrencyAmount(CURT_TRADE_BARS, CURRENCY_LOCATION_ACCOUNT) then
		CHAT_ROUTER:AddSystemMessage("|cFF0000WARNING!|r [EVT]: Number of trade bars has changed. (You may have gotten trade bars that weren't recorded.)")
		CHAT_ROUTER:AddSystemMessage("|cFFFFFFThis will fix itself after the next reset; or use|r |cFFD700/evt done|r |cFFFFFFto change trade bars manually.|r")
	end
]]

-- 2.400 Replace CURT_EVENT_TICKETS with CURT_TRADE_BARS
	EVT.vars.Total_Tickets  = GetCurrencyAmount(CURT_TRADE_BARS, CURRENCY_LOCATION_ACCOUNT)

-- EVENTUPDATE Update version number for new events that have announcements
--[[	if EVT.vars.EVT_version < 1.51 then
		EVT.vars.NewsIndex = 3
	end
]]

-- UI needs initialization, but will be done for real later on, so hide it for now.
	EVT_HIDE_UI = true
	EVT.InitializeUI()
-- 1.62 Move SignonMsg from here to end, because when it's here, it still doesn't know which event is running, and hasn't tested for things like locked
--	EVT.SignonMsg()

--      Start new event if one has started.
	if EVT_EVENT_START <= EVT.FindCurrentTime() and EVT_EVENT_END > EVT.FindCurrentTime() and (EVT.vars.Current_Event == "None" or EVT.vars.Current_Event == "Unknown") then
		EVT.StartNewEvent()
		EVT_HIDE_UI = EVT.vars.HideUI
		EVT.vars.DataCleared = nil

	elseif EVT.vars.Current_Event == "None" and EVT.vars.DataCleared == nil and EVT.vars.EVT_version > 1.34 then
		EVT.ClearData()

	elseif EVT_EVENT_END < EVT.FindCurrentTime() then
		EVT.vars.Current_Event = "None"
		EVT_HIDE_UI = true
		EVT.ClearData()
	end

	if EVT.vars.Current_Event ~= "None" or (EVT_EVENT_START-EVT.FindCurrentTime() < EVT_ONE_DAY*5 and EVT_EVENT_START >= EVT.FindCurrentTime() and EVT_EVENT_START~=EVT_DATE_UNKNOWN) then
-- If there's an event going on, or either one's about to start, and it's not an unknown start date, then use the saved choice.
		EVT_HIDE_UI = EVT.vars.HideUI
	else
--  Otherwise turn on temp hide, to hide UI without overwriting player's setting.
		EVT_HIDE_UI = true
		if EVT_EVENT_START < EVT.FindCurrentTime() then
			EVT_PRE_INFO = No_Event_Info
			EVT_PRE_CHAT = nil
		end
	end

-- 1.34 Hide or show UI, after it's been decided whether it should be. (Most likely still hidden at this point.)
	if EVT_HIDE_UI then
		EVT.HideUI("Hide")
	else
		EVT.HideUI("Show")
	end

-- ******************************************
-- EVENTUPDATE LOCKED DLC CHAPTER INITIALIZATION
-- ******************************************
-- 1.54 New feature: For events locked behind a paywall, check if there is access.

-- 154 Imperial City
-- 215 Orsinium
-- 254 Thieves Guild
-- 306 Dark Brotherhood
-- 593 Morrowind
-- 1240 Clockwork City
-- 5107 Summerset
-- 5755 Murkmire
-- 5843 Elsweyr
-- 6920 Dragonhold
-- 7466 Greymoor
-- 8388 Markarth
-- 8659 Blackwood
-- 9365 The Deadlands
-- 10053 High Isle
-- 10660 Firesong
-- 10475 Necrom
-- 11871 Gold Road

-- 9651 Coral Aerie
-- 9652 Shipwright's Regret
-- 10400 Earthen Root Enclave
-- 10401 Graven Deep

-- 1.81 High Isle
-- 1.87 Changed to use vars

--[[ 2.240
	if EVT.vars.Current_Event == "West Weald" then
		EVT_DLC_UNLOCKED[1] = EVT.IsItUnlocked("Chapter",11871,"Gold Road")

		DLC_Names = {"Gold Road","",""}
		DLC_Types = {"Chapter","",""}
		DLC_IDs = {11871,0,0}

-- 2.241 This code is for an event that has ONE set of trade bars, that can come from any of SIX possible DLC locations, but NO base game.
-- I have no way to run tests for all the possible combinations to be certain this works correctly.
-- Also, DLC dungeons are sold in pairs, so it technically isn't necessary to check for all four.
	elseif EVT.vars.Current_Event == "Bretons" then
		local All_DLC_Names = {"High Isle","Firesong","Coral Aerie","Shipwright's Regret","Earthen Root Enclave","Graven Deep"}
		local All_DLC_Types = {"DLC","DLC","DLC","DLC","DLC","DLC"}
		local All_DLC_IDs = {10053,10660,9651,9652,10400,10401}

		EVT_DLC_UNLOCKED[1] = false
		for i=1,6 do
			if not EVT_DLC_UNLOCKED[1] then
				EVT_DLC_UNLOCKED[1] = EVT.IsItUnlocked(All_DLC_Types[i],All_DLC_IDs[i],All_DLC_Names[i])
				if not EVT_DLC_UNLOCKED[1] then
					DLC_Names = {All_DLC_Names[i],"",""}
					DLC_Types = {All_DLC_Types[i],"",""}
					DLC_IDs = {All_DLC_IDs[i],0,0}
				end
			end
		end
	end
]]

--[[ 2.040 Oblivion
	if EVT.vars.Current_Event == "Oblivion" then
		EVT_DLC_UNLOCKED[1] = EVT.IsItUnlocked(DLC_Types[1],DLC_IDs[1],DLC_Names[1])
	end
]]

--	if EVT.vars.Current_Event == "High Isle" then
--		EVT_DLC_UNLOCKED[1] = EVT.IsItUnlocked("Chapter",10053,"High Isle")
--[[	if EVT.vars.Current_Event == "Skyrim" then
		DLC_Names = {"Greymoor","Markarth",""}
		DLC_Types = {"DLC","DLC",""}
		DLC_IDs = {7466,8388,0}

		EVT_DLC_UNLOCKED[1] = EVT.IsItUnlocked(DLC_Types[1],DLC_IDs[1],DLC_Names[1])
		EVT_DLC_UNLOCKED[2] = EVT.IsItUnlocked(DLC_Types[2],DLC_IDs[2],DLC_Names[2])
	else
]]
		
--[[ Test
	else
		EVT.IsItUnlocked("Chapter",10053,"High Isle")
		EVT.IsItUnlocked("DLC",7466,"Greymoor")
		EVT.IsItUnlocked("DLC",8388,"Markarth")
	end
]]

-- 2.361 Daedric War
	if EVT.vars.Current_Event == "Daedric War" then
--[[		local collectibleName = "name"	-- establishes this as local (EVT_DLC_UNLOCKED is not.)
		local dlc_ID = 593			-- Morrowind
		collectibleName, _, _, _, EVT_DLC_UNLOCKED[1] = GetCollectibleInfo(dlc_ID) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
		DLC_Names[1] = collectibleName .. " DLC"
		EVT.PrintDebug("DLC: " .. dlc_ID .. " " .. DLC_Names[1] .. " unlocked: " .. tostring(EVT_DLC_UNLOCKED[1]))

		if not EVT_DLC_UNLOCKED[1] then
			dlc_ID = 1240			-- Clockwork City
			collectibleName, _, _, _, EVT_DLC_UNLOCKED[1] = GetCollectibleInfo(dlc_ID) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
			DLC_Names[1] = collectibleName .. " DLC"
			EVT.PrintDebug("DLC: " .. dlc_ID .. " " .. DLC_Names[1] .. " unlocked: " .. tostring(EVT_DLC_UNLOCKED[1]))
		else
			EVT.PrintDebug("Clockwork not checked.")
		end
]]
		local dlc_ID = 5107			-- Summerset
		local collectibleName = "name"	-- establishes this as local (EVT_DLC_UNLOCKED is not.)
		collectibleName, _, _, _, EVT_DLC_UNLOCKED[2] = GetCollectibleInfo(dlc_ID) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
		DLC_Names[2] = collectibleName .. " DLC"
		EVT.PrintDebug("DLC: " .. dlc_ID .. " " .. DLC_Names[2] .. " unlocked: " .. tostring(EVT_DLC_UNLOCKED[2]))
	end

--		EVT_DLC_LOCKED[1] = GetCollectibleUnlockStateById(5843)	-- Elsweyr
--		EVT_DLC_LOCKED[2] = GetCollectibleUnlockStateById(6920)	-- Dragonhold

--[[ 1.60 Better planning ahead for final fragment of collectible behind paywall
	elseif EVT.vars.Current_Event == "Year One" then
--		local collectibleName = "name"	-- establishes this as local
--		local Blackwood_Unlocked = true
--		collectibleName, _, _, _, Blackwood_Unlocked = GetCollectibleInfo(8659) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
--		EVT.PrintDebug("DLC: 8659 " .. collectibleName .. " Chapter" .. " unlocked: " .. tostring(Blackwood_Unlocked))

		if not EVT.IsItUnlocked("Chapter",8659,"Blackwood") then -- Blackwood
			collectibleName, _, _, _, Fragment1 = GetCollectibleInfo(9162) -- Smoke-Wreathed Gryphon Feather (1st)
			EVT.PrintDebug("Fragment: 9162 " .. collectibleName .. " unlocked: " .. tostring(Fragment1))
			collectibleName, _, _, _, Fragment2 = GetCollectibleInfo(9163) -- Black Iron Bit and Bridle (2nd)
			EVT.PrintDebug("Fragment: 9163 " .. collectibleName .. " unlocked: " .. tostring(Fragment2))
			local cost = 10 -- cost of third fragment behind locked paywall
			if not Fragment1 then cost = cost+10 end
			if not Fragment2 then cost = cost+10 end

			local PrevReset, Hrs, Mins, EvtDays, EvtHrs = EVT.DailyReset()
			DaysRemaining = EvtDays
			if EvtHrs > Hrs then
				DaysRemaining = EvtDays + 1
			end

			local TicketsRem = 0
			if EVT_DLC_UNLOCKED[1] then
				TicketsRem = EVT.vars.T_Tickets[1] * (DaysRemaining + EVT.vars.T_ToDo[1])
			end
			if EVT_DLC_UNLOCKED[2] then
				TicketsRem = TicketsRem + EVT.vars.T_Tickets[2] * (DaysRemaining + EVT.vars.T_ToDo[2])
			end
			if EVT_DLC_UNLOCKED[3] then
				TicketsRem = TicketsRem + EVT.vars.T_Tickets[3] * (DaysRemaining + EVT.vars.T_ToDo[3])
			end

-- PLAN_AHEAD: Person doesn't have Blackwood and can still get mount
-- FRAGMENTS_DONE: Both fragments have been purchased (trade bars still need to be saved through end of previous event)
			if cost <= EVT.vars.Total_Tickets + TicketsRem then
				EVT_PLAN_AHEAD = true
				if Fragment1 and Fragment2 then EVT_FRAGMENTS_DONE = true end
			end
		end

	elseif EVT.vars.Current_Event == "Blackwood" then
		local collectibleName = "name"	-- establishes this as local (EVT_DLC_UNLOCKED is not.)
		local dlc_ID = 8659			-- Blackwood
		collectibleName, _, _, _, EVT_DLC_UNLOCKED[1] = GetCollectibleInfo(dlc_ID) -- Will return true or false. If the user unlocked through ESO+ without buying DLC it will return true.
		DLC_Names[1] = collectibleName .. " Chapter"
		EVT.PrintDebug("DLC: " .. dlc_ID .. " " .. DLC_Names[1] .. " unlocked: " .. tostring(EVT_DLC_UNLOCKED[1]))

		if not EVT_DLC_UNLOCKED[1] then

-- 1.62 More code added for people who don't have Blackwood but planned ahead
-- PLAN_AHEAD: Person doesn't have Blackwood, has 2 fragments but not 3rd (only needed to flag if the last part is still needed at this point)
-- FRAGMENTS_DONE isn't needed
-- Changed to not check if enough trade bars are available, because same day Blackwood announced, New Life out on PTS included that fragments will be available again then.
			collectibleName, _, _, _, Fragment1 = GetCollectibleInfo(9162) -- Smoke-Wreathed Gryphon Feather (1st)
			EVT.PrintDebug("Fragment: 9162 " .. collectibleName .. " unlocked: " .. tostring(Fragment1))
			collectibleName, _, _, _, Fragment2 = GetCollectibleInfo(9163) -- Black Iron Bit and Bridle (2nd)
			EVT.PrintDebug("Fragment: 9163 " .. collectibleName .. " unlocked: " .. tostring(Fragment2))
			collectibleName, _, _, _, Fragment3 = GetCollectibleInfo(9164) -- Black Iron Stirrups (3rd)
			EVT.PrintDebug("Fragment: 9164 " .. collectibleName .. " unlocked: " .. tostring(Fragment3))

--			local cost = 10 -- cost of third fragment behind locked paywall
--			if Fragment1 and Fragment2 and (not Fragment3) and cost <= EVT.vars.Total_Tickets then
			if Fragment1 and Fragment2 and (not Fragment3) then
				EVT_PLAN_AHEAD = true
			end
		end
]]
--	end

-- 2.390 Initialize this to zero to force the new popup info box to come up
	if EVT.vars.EVT_version+1.40 < Latest_Version then
		EVT.settings.InfoBox = 0
	end

-- 1.62 Moved SignonMsg from very early to here
	EVT.SignonMsg()

-- AUTOBUFF
--[[ 2.030 AUTOBUFF REMOVED!!
-- 1.67 Refresh XP buff at signon if it's an XP event and settings are set to do it - changed to do it earlier.
-- 1.76 Or cake for tickets, if not yet gotten today and not at cap.
	local MaxToday, MaxTomorrow = EVT.MaxAvailable()
	if (EVT.vars.Current_Event == "Anniversary" and MaxToday > 0 and EVT.vars.Total_Tickets + MaxToday <= 12) or (EVT.settings.XP_refresh < 120 and EVT.XP_Event()) then
		local bufftime, msg = EVT.XP_Buff_Time()
		if msg == "Ok" then
			EVT.Refresh_XP_Buff()

			PollSecs = EVT.settings.XP_refresh
			EVT.PrintDebug(string.format("|cAD00FFAttempted to refresh buff. Next check: %s minutes",PollSecs/60))
-- 1.85 "RegisterForUpdate" was using "Refresh_XP_Buff" instead of "Auto_XP_Buff"
			EVENT_MANAGER:RegisterForUpdate("EVT_Refresh_XP_Buff", PollSecs*1000, EVT.Auto_XP_Buff)
		else
-- "Auto-buff will not remove your old Pelinal Scroll buff" or "Auto-buff will not remove your old double XP buff"
			CHAT_ROUTER:AddSystemMessage("|c00CCFF" .. msg)
		end
	end
AUTOBUFF REMOVED!! ]]

-- 1.31 This just isn't happening enough, so move it to the end of INIT where it MUST.
-- Also disabled two calls above, which are no longer needed.
	EVT.ShowVars("Signon")
-- 1.16 Add character data for New Life - Not used yet.
--	EVT.SetUpChars()

-- 1.42 Move this as late as possible to help ensure anything tied to fresh update has a chance to run.
	EVT.vars.EVT_version    = Latest_Version

-- 2.400 Remove CurrencyUpdate and add LootReceived for Jester's 2026
	EVT.RegisterSlashCommands()
	if EVT.vars.Current_Event == "Jester's Festival" then
		EVENT_MANAGER:RegisterForEvent("EVT.BarsReceived", EVENT_LOOT_RECEIVED, EVT.OnBarsReceived)
	end
	EVENT_MANAGER:RegisterForEvent("EVT.CurrencyUpdate", EVENT_CURRENCY_UPDATE, EVT.onCurrencyUpdate)

-- 1.42 De-activated this unless there's a reason to have it active
-- 1.54	if EVT.vars.Current_Event == "Unknown" or EVT.vars.Current_Event == "None" or EVT.vars.Current_Event == "Witches" or 
	if EVT.vars.Current_Event == "Witches" then
		EVENT_MANAGER:RegisterForEvent("EVT.LootReceived", EVENT_LOOT_RECEIVED, EVT.OnLootReceived)
	end

-- 1.42 Re-activated for New Life (though it's not actually doing anything atm.) For quest-based events.
-- Quest ID 6588 Old Life Observance, Item ID 171327, New Life Festival Box
-- 5852 War Orphan's Sojourn, Item ID 171327, New Life Festival Box
-- 5839 Signal Fire Sprint
-- 5837 Lava Foot Stomp
-- 5838 Mud Ball Merriment
-- 5811 Snow Bear Plunge
-- 5839 Signal Fire Sprint
-- 5845 Castle Charm Challenge
-- 5855 Fish Boon Feast
-- 5834 The Trial of Five-Clawed Guile
-- 167170 Imperial Charity Writ for "1 Grape Preserves" (1 voucher)
-- 1.53 Quests MUST BE active for Whitestrake's Mayhem, Pan-Elsweyr, and Year One!
-- 1.71 Quests now being used for everything except Witches, Undaunted, and Anniversary.
-- 1.71 Interaction warning now being used for everything except Witches/Undaunted. 1.84 or none
	if EVT.vars.Current_Event ~= "Witches" and EVT.vars.Current_Event ~= "Undaunted" and EVT.vars.Current_Event ~= "None" then
		if EVT.vars.Current_Event ~= "Anniversary" or GetCollectibleUnlockStateById(Collectible_Num["cake"]) == COLLECTIBLE_UNLOCK_STATE_LOCKED then
			EVENT_MANAGER:RegisterForEvent("EVT.QuestRemoved", EVENT_QUEST_REMOVED, EVT.FindQuest)
		end
--	if EVT.vars.Current_Event == "New Life" then
-- 1.54		EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_LOOT_RECEIVED, EVT.OnLootReceived)
--	end

-- 1.51 Written by @StorybookTerror, thank you!
-- 1.60 Added Impresario warning for final fragment behind locked paywall
-- EVENTUPDATE
-- SAFETY NET
--	if EVT.vars.Current_Event ~= "Unknown" and EVT.vars.Current_Event ~= "None" and (EVT.vars.Current_Event == "Anniversary" and EVT.vars.Total_Tickets + MaxToday > 12) then
-- or (EVT.vars.Current_Event == "Year One" and EVT_PLAN_AHEAD) then

-- 1.67 Warning for quest turn-in
		EVT.infoLabel = CreateControlFromVirtual("EVTInteractionLabel", ZO_ReticleContainerInteract, "ZO_KeybindButton")
		EVT.infoLabel:SetAnchor(TOPLEFT, ZO_ReticleContainerInteractKeybindButton, BOTTOMLEFT, -100, 0)

-- 2.400 REMOVED
--		ZO_PreHook(RETICLE, "TryHandlingInteraction", EVT.ReticleHook)

-- 2.411 QuestTickets now initializes var(s) in EVTEvents so MUST BE RUN
		EVT.QuestTickets()
-- 1.67 -- 1.89 Change "EVT.name"
		if EVT.vars.Current_Event ~= "Anniversary" then
			EVENT_MANAGER:RegisterForEvent("EVT.QuestUpdate", EVENT_QUEST_ADVANCED, EVT.QuestTickets) -- triggered when getting into the circle; when reached next step; only last fire on Signal Fire Sprint
		else
			EVENT_MANAGER:RegisterForEvent("EVT.OnInteract", EVENT_CLIENT_INTERACT_RESULT, EVT.OnInteract)
		end
	end
--	EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, EVT.test2) -- triggered when getting into the circle; when reached next step; triggered for each brazier on Signal Fire Sprint
--	EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_OBJECTIVES_UPDATED, EVT.test3) -- triggered a lot in a dungeon (no pledge)
--	EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_OBJECTIVE_COMPLETED, EVT.test4) -- might have triggered at end of dungeon - I didn't finish it
--	EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_OBJECTIVE_CONTROL_STATE, EVT.test5) -- triggered occasionally in a dungeon (no pledge)
--	EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_TRACKING_UPDATE, EVT.test6) -- triggered when traveling to a different zone (not subzone) (not related to quests; triggered whether or not there was a door)
--	EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_QUEST_TOOL_UPDATED, EVT.test7)

end

--[[ 2.200 REMOVED: START
-- 2.100 LIBRARY New loading method: added next two functions
----------------------------------------
-- Init Delay
-- Wait for information to be loaded
----------------------------------------
local fail_safe = 1
local function EVT_Init_Delay()
	if LibEVT:IsInfoReady() then
		EVENT_MANAGER:UnregisterForUpdate(EVT.name)
		EVT.Initialize()
	end
	if fail_safe > 10 then -- limited number of tries
		EVENT_MANAGER:UnregisterForUpdate(EVT.name)
--		d("|cFF0000EVT: GAVE UP! TOO MANY TRIES!")
	else
--		d(string.format("|cFF00CCEVT Attempt:|cFFFFFF %d",fail_safe))
		fail_safe = fail_safe+1
	end
end


----------------------------------------
-- OnAddonLoaded
----------------------------------------
function EVT.OnAddonLoaded(code, AddonName)
	if AddonName ~= EVT.name then return end
	EVENT_MANAGER:UnregisterForEvent(EVT.name, EVENT_ADD_ON_LOADED)

	if LibEVT:IsInfoReady() then EVT.Initialize()
	else EVENT_MANAGER:RegisterForUpdate(EVT.name, 1000, EVT_Init_Delay) end -- Don't forget to unregister!
--	zo_callLater(EVT.Initialize,2000)
end
-- 2.200 REMOVED: END]]

-- 2.200 RESTORED following
-- 2.100 LIBRARY New loading method: removed following
----------------------------------------
-- OnAddonLoaded
-- 1.34 Introduced a 5-second load delay -- 1.65 Tried reducing that to 3 sec
--      to hopefully stop mysterious issues that might be caused by not having everything loaded
----------------------------------------
--
function EVT.OnAddonLoaded(_, AddonName)
	if AddonName == EVT.name then
		EVENT_MANAGER:UnregisterForEvent(EVT.name, EVENT_ADD_ON_LOADED)

-- 1.83		EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_PLAYER_ACTIVATED, EVT.Initialize)
-- 1.76 Had tried player_activated with 1.76; but some things just aren't working right.
		EVENT_MANAGER:RegisterForUpdate(EVT.name, 5*1000, EVT.Initialize) -- Don't forget to unregister!
-- 1.49 Not necessary with hidden="true" added to .xml
--		EVT.HideUI("Hide")
--		EVT.Initialize()
	end
end
-- 2.200 END RESTORED

-- Register addon load handler
EVENT_MANAGER:RegisterForEvent(EVT.name, EVENT_ADD_ON_LOADED, EVT.OnAddonLoaded)
