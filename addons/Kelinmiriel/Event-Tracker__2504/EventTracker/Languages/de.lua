-- Created May 11, 2020
-- Updated every time there's an event update for the addon.
-- 1.991 Initial German version started July 9, 2023 - Much thanks to Nîlaethea!
-- /script SetCVar("language.2", "de")

local strings = {
--	EVT_EVENT_INFO_NEWS_NA = "Neue Uhrzeit für Scheine-Reset: 4h später! Auf NA bleiben am letzten Tag nur4h Zeit! Neu: Fragmente für Persönlichkeiten können beim nachfolgenden Event noch gekauft werden.",
--	EVT_EVENT_INFO_NEWS_EU = "Neue Uhrzeit für Scheine-Reset: 3h früher. Holt die Scheine nicht erst in letzter Minute! Neu: Fragmente für Persönlichkeiten können beim nachfolgenden Event noch gekauft werden.",
--	EVT_EVENT_INFO_NEWS_NA = "Zenithars Eifer wurde um einen weiteren Tag verlängert!",
--	EVT_EVENT_INFO_NEWS_EU = "Zenithars Eifer wurde um einen weiteren Tag verlängert!",
-- "Double XP is now automatically (passively) granted for the duration of the event (without having to use a tool) (the tools can still be used, but now as a memento without effect)"
	EVT_EVENT_INFO_NEWS_NA = "Doppelte XP wird jetzt für die Dauer des Events automatisch (passiv) gewährt (ohne dass ein Werkzeug benutzt werden muss) (die Werkzeuge können auch weiterhin, nun jedoch als Memento ohne Effekt, verwendet werden)",
	EVT_EVENT_INFO_NEWS_EU = "Doppelte XP wird jetzt für die Dauer des Events automatisch (passiv) gewährt (ohne dass ein Werkzeug benutzt werden muss) (die Werkzeuge können auch weiterhin, nun jedoch als Memento ohne Effekt, verwendet werden)",
-- "PTS event cycle remains a secret. Until the announcement"
	EVT_EVENT_INFO_NEWS_PTS = "PTS Event-Zyklus bleibt ein Geheimnis. Bis zur Bekanntgabe",
	
	
	EVT_EVENT_INFO_TICKETS = "gebt",
	EVT_EVENT_INFO_IMPRESARIO = "aus",
	
	EVT_EVENT_INFO_PET = "Es gibt 3 Fragmente (je 5 Scheine), bei der Impressario, die zu einem friedlichen Begleiter zusammengefügt werden können",
	
	EVT_EVENT_INFO_MORPH = "3 Fragmente (zu je 10 Scheinen) können einen |H1:collectible:10697|h|h Begleiter zu einer |H1:collectible:10913|h|h Persönlichkeit oder einer |H1:collectible:10661|h|h Erscheinung kombinieren. Der Begleiter wird dabei verbraucht.",
	
	
	
	EVT_EVENT_INFO_INDRIK = "Bei jedem Event gibt es jetzt einen Indrik-Händler in Kargstein. Er bietet 4 Federn (je 5 Scheine) für die Kombination zu einem heranwachsenden Indrik. Dieser, sowie 4 Beeren (je 10 Scheine) können dann zu einer Prächtigen Version kombiniert werden.",
	
	EVT_EVENT_INFO_INDRIK_CYCLE_1 = "Der heranwachsende Indrik",
	EVT_EVENT_INFO_INDRIK_CYCLE_2 = "bei jedem Ereignis gibt es alle Federn; zwei Begleiter, sowie die Beeren für die dazu passenen Prächtigen Versionen. Jan-Mrz: Dämmerholz+Spektral, Apr-Jun. Goldschein+Eisodem, Jul-Sep: Onyx+Moosherz, Oct-Dez: Reinschnee+Purpur",
	
	
	EVT_XPBUFF = "4 jährliche Events geben bei Benutzen eines Werkzeuges (früher Memento) einen Erfahrungs-Bonus. Mrz.:Narren, April: Geburtstag, Okt.:Hexen, Dez.:Neujahr. Event Tracker erneuert den Bonus mit dem Chatbefehl: /xpbuff ",
	
	
	
	
	EVT_EVENT_INFO_NONE = "kein Ereignis aktiv",
	EVT_EVENT_INFO_UNKNOWN = "diese Version des Event-Tracker hat keine genaueren Informationen. Bitte Updates prüfen",
	
	
	
	
	
-- *************** ANNUAL EVENTS	
	
	EVT_EVENT_INFO_WHITESTRAKE = "Aug. and Oct. 2026.  ZERO Handelsbarren täglich! DOUBLE XP/AP/Tel Var in Cyro/IC/BG!",
--	EVT_EVENT_INFO_WHITESTRAKE = "21.Jan.-4.Feb. 2026.  3 Scheine täglich (pro Konto und Server): 2 from Battlegrounds or Cyrodiil, plus 1 from Imperial City; per account per day. DOUBLE XP/AP/Tel Var in Cyro/IC/BG!",
--	EVT_EVENT_INFO_WHITESTRAKE = "24.Juli-7.Aug. 2025.  3 Scheine täglich (pro Konto und Server): 2 from Battlegrounds or Cyrodiil, plus 1 from Imperial City; per account per day. DOUBLE XP/AP/Tel Var PASSIVE NOW!",
	--	EVT_EVENT_INFO_WHITESTRAKE = "20.Feb.-4.März 2025.  3 Scheine täglich (pro Konto und Server): 2 from Battlegrounds or Cyrodiil, plus 1 from Imperial City; per account per day. DOUBLE XP/AP/Tel Var PASSIVE NOW!",
--	EVT_EVENT_INFO_WHITESTRAKE = "25.Juli-6.Aug. 2024 (39 Scheine).  3 Scheine täglich (pro Konto und Server)",
--	EVT_EVENT_INFO_WHITESTRAKE = "Feb. 22-March 5, 2024. Tickets from DAILY quests: 2 from Battlegrounds or Cyrodiil, plus 1 from Imperial City; per account per day. DOUBLE XP/AP/Tel Var PASSIVE NOW!",
--	EVT_EVENT_INFO_WHITESTRAKE = "29.Juni-11.Juli 2023 (39 Scheine). Tickets für Tägliche",
	
	
	
	EVT_PTS_INFO_ANNIVERSARY = "PTS: 26.Jan.-2.Feb. 2026.; Live: April. 300 TRADE BARS acquired once per day per account from eating this year's Anniversary Cake. (Cake is a TOOL.) XP IS PASSIVE!",
--	EVT_PTS_INFO_ANNIVERSARY = "PTS: Feb. 12-19.; Live: Early April. 3 tickets acquired once per day per account from eating Anniversary Cake. (Cake is a TOOL.) XP IS PASSIVE NOW!",
--	EVT_EVENT_INFO_ANNIVERSARY = "6.-18.April 2023 (39 Scheine) 3 Scheine täglich (pro Konto und Server) für den Verzehr von Jubiläumskuchen (inzwischen ein Werkzeug)",
	EVT_EVENT_INFO_ANNIVERSARY = "2-15.April 2026. 300 HANDELSBARREN täglich (pro Konto und Server) für den Verzehr von Jubiläumskuchen (inzwischen ein Werkzeug)",
--	EVT_EVENT_INFO_ANNIVERSARY = "3.-22.April 2025 (60 Scheine). 3 Scheine täglich (pro Konto und Server) für den Verzehr von Jubiläumskuchen (inzwischen ein Werkzeug)",
	--	EVT_EVENT_INFO_ANNIVERSARY = "EU: 4.-25.April 2024. NA: 4.-24.April 2024. 3 Scheine täglich (pro Konto und Server) für den Verzehr von Jubiläumskuchen (inzwischen ein Werkzeug)",

	
	
	EVT_PTS_INFO_JESTER = "PTS: 19-26.Jan. 2026; Live: Late Marz. 300 TRADE BARS per day per account from turning in your first Jester's daily. XP IS PASSIVE!",
--	EVT_PTS_INFO_JESTER = "PTS: Feb. 5-12; Live: Late March. 3 tickets per day per account from turning in your first Jester's daily. XP IS PASSIVE NOW!",
--	EVT_EVENT_INFO_JESTER = "29.Mrz. bis 06.Apr.2023 (24 Scheine) 3 Scheine täglich (pro Konto und Server) für das Abgeben des ersten täglichen Narrenquests. Esst Pastete (Werkzeug) für einen 2h XP-Bonus.",
	EVT_EVENT_INFO_JESTER = "25.März-2.April 2026. 300 HANDELSBARREN täglich (pro Konto und Server) für das Abgeben des ersten täglichen Narrenquests.",
--	EVT_EVENT_INFO_JESTER = "27.März-3.April 2025 (21 Scheine). 3 Scheine täglich (pro Konto und Server) für das Abgeben des ersten täglichen Narrenquests.",
	--	EVT_EVENT_INFO_JESTER = "28.März-4.April 2024. 3 Scheine täglich (pro Konto und Server) für das Abgeben des ersten täglichen Narrenquests.",

	
	
	PTS_EVENT_INFO_WITCHES = "PTS: 21.-28.Juli 2025; Live: Oktober, 2025. 2 Scheine/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
	EVT_EVENT_INFO_WITCHES = "21.Okt.-4.Nov. 2026, 300 Handelsbarren täglich/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
--	EVT_EVENT_INFO_WITCHES = "23.Okt.-5.Nov. 2025, 2 Scheine/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
--	EVT_EVENT_INFO_WITCHES = "Oktober 2025, 2 Scheine/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
	--	EVT_EVENT_INFO_WITCHES = "Oktober 2023, 2 Scheine/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
--	Trinkt das Gebräu der Hexenmutter für den XP-Bonus.",
	EVT_EVENT_INFO_UNDAUNTED = "18.-30.Sept. 2025, täglich 2 Scheine pro Konto für das Looten des letzten Bosses von GRUPPEN-Verliesen. Das muss nicht über den Dungeon finder ablaufen",
--	EVT_EVENT_INFO_UNDAUNTED = "7.-19.Sept. 2023, täglich 2 Scheine pro Konto für das Looten des letzten Bosses von GRUPPEN-Verliesen. Das muss nicht über den Dungeon finder ablaufen",
-- "Early"	EVT_EVENT_INFO_UNDAUNTED = "Früher Sept. 2023, täglich 2 Scheine pro Konto für das Looten des letzten Bosses von GRUPPEN-Verliesen. Das muss nicht über den Dungeon finder ablaufen",
	
	EVT_EVENT_INFO_NEW_LIFE = "18.Dec. 2025-6.Jan. 2026. 3 tickets/day/account from turning in your first New Life (or Old Life) daily quest. PASSIVE DOUBLE XP!",
--	EVT_EVENT_INFO_NEW_LIFE = "19.Dec. 2024-7.Jan. 2025. 3 tickets/day/account from turning in your first New Life (or Old Life) daily quest. DOUBLE XP PASSIVE NOW!",
	--	EVT_EVENT_INFO_NEW_LIFE = "21.Dec. 2023-9.Jan. 2024. (60 Scheine) 3 tickets/day/account from turning in your first New Life (or Old Life) daily quest. DOUBLE XP PASSIVE NOW!",

	EVT_EVENT_INFO_ZEAL_OF_ZENITHAR = "24.June-8.Juli 2026. 300 Handelsbarren täglich (pro Konto und Server) für das Einreichen der täglichen Quest 'Ehrliche Arbeit' (Fasaria beim Schrein von Zenithar, westl.v. Belkarth, Kargstein). UM EINEN TAG VERLÄNGERT",
--	EVT_EVENT_INFO_ZEAL_OF_ZENITHAR = "26.June bis 8.Juli.2025. (39 Scheine) 3 Scheine täglich (pro Konto und Server) für das Einreichen der täglichen Quest 'Ehrliche Arbeit' (Fasaria beim Schrein von Zenithar, westl.v. Belkarth, Kargstein). UM EINEN TAG VERLÄNGERT",
--	EVT_EVENT_INFO_ZEAL_OF_ZENITHAR = "30.June bis 2.Juli.2024. (39 Scheine) 3 Scheine täglich (pro Konto und Server) für das Einreichen der täglichen Quest 'Ehrliche Arbeit' (Fasaria beim Schrein von Zenithar, westl.v. Belkarth, Kargstein). UM EINEN TAG VERLÄNGERT",
--	EVT_EVENT_INFO_ZEAL_OF_ZENITHAR = "27.Juli bis 9.Aug.2023. (42 Scheine) 2 Scheine täglich (pro Konto und Server) für das Einreichen der täglichen Quest 'Ehrliche Arbeit' (Fasaria beim Schrein von Zenithar, westl.v. Belkarth, Kargstein). UM EINEN TAG VERLÄNGERT",
	
-- 2.341 "Heart's Week"
	EVT_EVENT_INFO_HEARTS_WEEK = "11.-18.Feb. 2026. 2 Scheine, once/day/acct: Completing a Heart's Week quest; or IN A GROUP OR WITH COMPANION ACTIVE! Archive, Delve, or World boss; Looting a treasure chest; Pickpocketing. Chance of tickets: Incursion boss, Harvest node. DBL XP for COMPANIONS",


-- *************** NON-ANNUAL EVENTS
-- 2.430 "High Seas"
	EVT_EVENT_INFO_HIGH_SEAS = "30.Sept-14.Okt 2026. 300 trade bars, once/day/acct: Completing the daily quest 'Bounty of the Abecean Sea', or the starter quest 'Raising the Riotous Redress'.",
-- 2.240 "Pan-Tamriel"
	EVT_EVENT_INFO_DAEDRIC_WAR = "20.Nov-2.Dec 2025. (26 Scheine) 2 tickets/day/account, from zone DAILY or trial WEEKLY quest: 1 Morrowind/HoF OR Clockwork City/AS; PLUS 1 Summerset/CR.",
	EVT_EVENT_INFO_PAN_TAMRIEL = "23.Jan-4.Feb 2025. (39 Scheine) 3 Scheine/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
-- 2.240 "Legacy of the Bretons"
	EVT_EVENT_INFO_BRETONS = "21.Nov-3.Dec 2024. 2 Scheine/Tag/Konto, from your first High Isle/Tribute or Galen DAILY quest, Dreadsail WEEKLY quest, or the final boss of Coral Aerie, Shipwright's Regret, Earthen Root, or Graven Deep.",
-- 2.240 "Fallen Leaves of the West Weald"
	EVT_EVENT_INFO_WEST_WEALD = "26.Sept-8.Okt 2024. 2 Scheine/Tag/Konto, from your first Gold Road or event (Gandrinar) DAILY quest, or Lucent Citadel WEEKLY quest.",


-- *************** DEPRECATED EVENTS	
-- 2.001 "Secrets of the Telvanni"; added extra day to Zenithar
	EVT_EVENT_INFO_TELVANNI = "28.Sept-10.Okt 2023. 2 Scheine/Tag/Konto, from your first Necrom DAILY quest, or Sanity's Edge WEEKLY quest.",
-- 2.020 "Gates of Oblivion Celebration" (Oblivion)
	EVT_EVENT_INFO_OBLIVION = "16.-29.Nov. 2023 (29 Scheine). 2 tickets/day/account, from your first Blackwood or Deadlands DAILY quest, Rockgrove WEEKLY quest, or the final boss of Red Petal Bastion, Cauldron, Dread Cellar, or Black Drake Villa.",
-- 2.020 "Guilds and Glory Celebration" (Guilds)
	EVT_EVENT_INFO_GUILDS = "18.-30.Jan. 2024 2 tickets/day/account, from Wrothgar/Gold Coast/Hew's Bane/IC DAILY, MoL WEEKLY, IC district/sewer bosses, or ICP/WGT/MA final boss.",
-- "Season of the Dragon"
	EVT_EVENT_INFO_DRAGON = "Jan. 26-Feb. 7, 2023. (26 tickets) 2 tickets per day per account: 1 from N. Elsweyr DAILY quest (or Sunspire WEEKLY); plus 1 from S. Elsweyr DAILY.",
-- "Dark Heart of Skyrim"	
	EVT_EVENT_INFO_SKYRIM = "Nov. 17-29, 2022. (26 tickets) 2 tickets per day per account: 1 from a Western Skyrim DAILY quest (or Kyne's Aegis WEEKLY); and 1 from a DAILY quest in The Reach. (A Harrowstorm can count for both!)",
	EVT_EVENT_INFO_HIGH_ISLE = "Sept 29-Oct. 11, 2022. (26 tickets) 2 tickets per day per account, from your first High Isle DAILY quest, or Dreadsail Reef WEEKLY quest.",
--	EVT_EVENT_INFO_DAEDRIC_WAR = "Late Nov., 2025. 2 tickets/day/account, from zone DAILY or trial WEEKLY quest: 1 Morrowind/HoF OR Clockwork City/AS; PLUS 1 Summerset/CR.",
	EVT_EVENT_INFO_YEAR_ONE = "Aug. 26-Sept. 7, 2021. (26 tickets) Tickets per day per account: 1 from a Craglorn or Wrothgar DAILY quest (or WEEKLY SO/AA/HRC trial); plus 1 from an IC DAILY. (NOT ICP or WGT.)",
	EVT_EVENT_INFO_BLACKWOOD = "Sept. 30-Oct. 12, 2021. (26 tickets) 2 tickets per day per account, from your first Blackwood DAILY quest, or Rockgrove WEEKLY quest.",
	EVT_EVENT_INFO_PAN_ELSWEYR = "July 22-Aug. 3, 2021. (26 tickets) Tickets per day per account: 1 from N. Elsweyr DAILY quest (or Sunspire WEEKLY); plus 1 from S. Elsweyr DAILY.",
	EVT_EVENT_INFO_TRIBUNAL = "Feb. 25-Mar. 9, 2021. (26 tickets) Tickets per day per account: 1 from Morrowind DAILY quest (or HoF WEEKLY); and 1 from Clockwork City DAILY (or Asylum WEEKLY).",
	EVT_EVENT_INFO_IMPERIAL_CITY = "Sept. 3-15, 2020 (39 tickets). Loot 3 tickets per day per account from any DAILY Imperial City quest, or the body of the FINAL BOSS of Imperial City Prison or White Gold Tower.",
	EVT_EVENT_INFO_LOST_TREASURES = "Sept. 23-Oct. 5, 2020 (39 tickets). 3 tickets per day per account, from a Greymoor DAILY quest or Kyne's Aegis WEEKLY.",
	EVT_EVENT_INFO_SUMMERSET = "July 23-Aug. 4, 2020 (39 tickets). 3 tickets per day per account, from a Summerset DAILY quest or Cloudrest WEEKLY.",
	EVT_EVENT_INFO_MURKMIRE = "Feb. 20-March 3, 2020 (39 tickets). Loot 3 tickets once per day per account, that could drop from anything, including other group members who aren't even near you. Recommend not being in a group until you get your tickets.",
	EVT_EVENT_INFO_WROTHGAR = "Aug. 8-19, 2019 (24 tickets). 2 tickets available per day per account for your first daily quest in Wrothgar.",
	EVT_EVENT_INFO_CRIME_PAYS = "July 2-15, 2019 (28 tickets). Tickets per day per account: 1 from a TG Heist, 1 from a DB Black Sacrament.",
	EVT_EVENT_INFO_MORROWIND = "Feb. 7-18, 2019 (24 tickets). Tickets per day per account: 1 from the daily delve quest and 1 from the daily world boss quest, in Vvardenfell.",
	EVT_EVENT_INFO_CLOCKWORK = "Nov. 15-26, 2018 (24 tickets). 2 tickets available per day per account from your first Clockwork City daily quest.",}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end

EVT.lang = {
["WARNING"] = "WARNUNG",
["Tickets"] = "Handelsbarren",
["tickets"] = "Handelsbarren",
["Available"] = "verfügbar",

["Next Event"] = "nächstes Event",
["next"] = "nächstes",
["Event ends"] = "Event Endet",
["EVENT ENDS"] = "EVENT ENDET",
["Final tickets finished"] = "alle Handelsbarren erhalten",
["Final trade bars finished"] = "alle Handelsbarren erhalten",
["days"] = "Tage",
["day"] = "Tag",
["hrs"] = "h",
["hr"] = "h",
["mins"] = "min",
["min"] = "min",

-- Date format 1, same month: "18.-30.Jan 2024"
["DateFormat1a"] = "%d.-",
["DateFormat1b"] = "%d.%b %Y",

-- Date format 2, different months: "28.Sep-10.Okt 2023"
["DateFormat2a"] = "%d.%b-",
["DateFormat2b"] = "%d.%b %Y",

-- Date format Start, only starting date known: "Starts 30.Jan 2024"
["DateFormatStart"] = "Beginnt %d.%b %Y",

-- Collectible types
["pet"] = "pet",
["body & face markings"] = "body & face markings",
["costume"] = "costume",
["customized action"] = "customized action",
["furnishing"] = "furnishing",
["mount"] = "mount",
["notable house"] = "notable house",
["personality"] = "personality",
["skin"] = "skin",

--[[ UserInterface
	["Tickets"]	= "Tickets",
	["Available"]	= "Available",
]]
-- Events

--		A: Anniversary
	["EVENT INFO A"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.) Or look for the baking tent on the docks of Vulkhel Guard, Dolchsturz oder Davons Wacht.",
		["Box"]		= "Get boxes from ANY DAILY QUEST, anywhere! (Even crafting!) Also world events like dolmens, dragons, etc. Final bosses of dungeons & trials. Rewards for the Worthy mails and Tribute boxes.",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "3 Scheine täglich (pro Konto und Server) für den Verzehr von Jubiläumskuchen (inzwischen ein Werkzeug)",
	},

--		J: Jesters Fest
	["EVENT INFO J"] = {
		["Begin"]	= "um das Event zu starten holt Euch die FREIE (kostet keine Kronen) Event-Quest im Kronen-Shop ab. Alternativ geht direkt zu einem der Narren Zelte bei Vulkhel Guard, Dolchsturz oder Ebenherz. Die Standorte sind auf der Karte Markiert",
		["Box"]		= "holt Euch weitere Boxen von den Täglichen Narrenquests. Es gibt Quests in Vulkhel Guard, Dolchsturz, und eine extra Quest die in Vivecs Fanfaren in Steinfall, südlich von Ebenherz, startet",
		["Upcoming"]	= "April 4: Anniversary (3). (number)=Tickets per day, per account.",
		["Info"]	= "3 Scheine täglich (pro Konto und Server) für das Abgeben des ersten täglichen Narrenquests.",
	},

--		M: (Whitestrake's) Mayhem
	["EVENT INFO M"] = {
		["Begin"]	= "Look for Predicant Maera at any Battlegrounds Camp, or at your alliance base camp in Cyrodiil (use the alliance war menu, L, to travel there).",
		["Box"]		= "Get boxes from DAILY Battlegrounds quests, Cyrodiil quests (including towns), and Imperial City quests.",
		["Upcoming"]	= "March: Jester's (3); April: Anniversary (3). (number)=Tickets per day, per account.",
		["Info"]	= "Tickets from DAILY quests: 2 from Battlegrounds or Cyrodiil, plus 1 from Imperial City; per account per day. DOUBLE XP/AP/Tel Var PASSIVE NOW!",
	},

--		N: New Life
	["EVENT INFO N"] = {
		["Begin"]	= "Check Crown Store for FREE starter quest; get one extra purple box per character for the event.",
		["Box"]		= "Additional boxes drop from New Life and Old Life quests; up to 10 boxes total per character per day.",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "3 tickets/day/account from turning in your first New Life (or Old Life) daily quest. DOUBLE XP PASSIVE NOW!!",
	},

--		U: Undaunted
	["EVENT INFO U"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "täglich 2 Scheine pro Konto für das Looten des letzten Bosses von GRUPPEN-Verliesen. Das muss nicht über den Dungeon finder ablaufen.",
	},

--		W: Witches Fest
	["EVENT INFO W"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "2 Scheine/Tag/Konto: Weltboss oder Endboss öffentliche Verliese, Endbosse von Gewölben, Dunkle Risse, Dolmen, Drachen usw., Verliese, Arenen oder Prüfungen.",
	},

--		Z: Zeal of Zenithar
	["EVENT INFO Z"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "2 Scheine täglich (pro Konto und Server) für das Einreichen der täglichen Quest 'Ehrliche Arbeit' (Fasaria beim Schrein von Zenithar, westl.v. Belkarth, Kargstein). UM EINEN TAG VERLÄNGERT",
	},

--		Gol: (Gold Road) (I don't know what they'll call this event, but I'm sure there will be one.)
	["EVENT INFO Gol"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "",
	},

--[[ Old special one-time events not expected to return, in order from newest to oldest.
-- Still here just in case they do.
		G&G: Guilds and Glory
	["EVENT INFO G&G"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "",
	},

--		Bla: (Blackwood) Gates of Oblivion
	["EVENT INFO Bla"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "",
	},

--		Nec: (Necrom) Secrets of the Telvanni
	["EVENT INFO Nec"] = {
		["Begin"]	= "Pick up the FREE quest in the Crown Store to start (it doesn't cost anything.)",
		["Box"]		= "",
		["Upcoming"]	= "None known yet.",
		["Info"]	= "",
	},
]]
}
