--[[
File : de.lua
Version : 4.5
Author : Ayantir
Translator: @Medallyon - Many thanks to him
]]--
 
--Option Translation
 
SafeAddString(BMR_AUTO_TRANSFERT								, "Automatisches verlagern beim Öffnen der Bank", 1)
SafeAddString(BMR_AUTO_TRANSFERT_TOOLTIP					, "Beim Öffnen der Bank werden alle Verlagerungen automatisch durchgeführt.", 1)

SafeAddString(BMR_STACK_DETAILLED							, "Details Anzeigen", 1)
SafeAddString(BMR_STACK_DETAILLED_TOOLTIP					, "Zeigt Informationen für jede Verlagerung im Chat an.", 1)

SafeAddString(BMR_DISPLAY_SUMMARY							, "Zusammenfassung Anzeigen", 1)
SafeAddString(BMR_DISPLAY_SUMMARY_TOOLTIP					, "Zeigt eine Zusammenfassung der verlagerten Items & Währungen im Chat an.", 1)

SafeAddString(BMR_STACK_DETAILLED_NOTMOVED				, "Zeige fehlgeschlagene Umlagerungen", 1)
SafeAddString(BMR_STACK_DETAILLED_NOTMOVED_TOOLTIP		, "Zeigt eine Nachricht, wenn BMR die Umlagerung nicht ausführen konnte, wegen zu wenig Platz im Ziel-Inventar", 1)

SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS				, "Geschützte Items nicht verlagern", 1)
SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS_TOOLTIP	, "Items markiert von ESO, ItemSaver oder FCO Itemsaver nicht verlagern.", 1)

SafeAddString(BMR_DONT_MOVE_MOVED_ITEMS					, "Nichts umlagern, das schon umgelagert wurde", 1)
SafeAddString(BMR_DONT_MOVE_MOVED_ITEMS_TOOLTIP			, "Deaktiviert das Umlagern von Gegenständen, die vorher von einem anderen Addon oder durch den Spieler selbst umgelagert wurden", 1)

SafeAddString(BMR_WAIT_AT_STARTUP							,"Zeit bis BMR umlagert nach öffnen der Bank", 1)
SafeAddString(BMR_WAIT_AT_STARTUP_TOOLTIP				,"Verringere den Wert, wenn du nicht warten willst. Ein niedrigerer Wert kann zu Fehlern bei BMR führen, wenn dein Computer langsamer ist - besonders bei der Gildenbank", 1)
	
SafeAddString(BMR_NO_OVERFILL								, "Platz freihalten im Ziel-Inventar", 1)
SafeAddString(BMR_NO_OVERFILL_TOOLTIP					, "Wenn eingestellt, versucht BMR diese Zahl an Plätzen im Ziel-Inventar frei zu halten und keine weiteren Gegenstände bewegen wenn die Grenze erreicht ist", 1)

SafeAddString(BMR_DELAY_BETWEEN_MOVES					, "Verzögerungen zwischen Umlagerung", 1)
SafeAddString(BMR_DELAY_BETWEEN_MOVES_TOOLTIP			, "Fügt eine Verzögerung zwischen allen Umlagerungen hinzu um das Risiko auf Abstürze und/oder Serverkicks zu reduzieren", 1)

SafeAddString(BMR_ONLY_IF_NOT_FULL_STACK					, "Nur lagern wenn kein Stack existiert", 1)
SafeAddString(BMR_ONLY_IF_NOT_FULL_STACK_TOOLTIP		, "Items nicht verlagern wenn im Ziel-Inventar schon ein voller Stack existiert.", 1)

SafeAddString(BMR_MAX_STACK									, "Maximale Stacks/Stapel", 1)
SafeAddString(BMR_MAX_STACK_TOOLTIP							, "Anzahl der Stapel an Gegenständen die maximal verschoben werden sollen bzw. im Ziel-Inventar sein können.", 1)

SafeAddString(BMR_GUILD_LIST									, "Zugewiesene Gildenbank", 1)
SafeAddString(BMR_GUILD_LIST_TOOLTIP						, "Name der Gildenbank die mit den nachfolgenden Regeln verknüpft ist. BMR wird Gegenstände in diese Gildenbank umlagern, wenn deine persönlichen Einstellungen zutreffen", 1)

-- Profiles
SafeAddString(BMR_PROFILES										, "Profil", 1)
SafeAddString(BMR_PROFILE_LIST								, "Ausgewähltes Profil", 1)
SafeAddString(BMR_PROFILE_LIST_TOOLTIP						, "Für jeden Charakter gibt es 9 Profile die angepasst werden können die du auch mit der letzten Einstellung übertragen kannst.", 1)
SafeAddString(BMR_PROFILE_NAME								, "Profilname", 1)
SafeAddString(BMR_PROFILE_NAME_TOOLTIP						, "Name des ausgewählten Profils", 1)
SafeAddString(BMR_PROFILE_RESET								, "Profil zurücksetzen", 1)
SafeAddString(BMR_PROFILE_RESET_TOOLTIP					, "Einstellung dieses Profils werden zurückgesetzt.", 1)

SafeAddString(BMR_PROFILE 										, "Profil <<1>>", 1)
		 
-- Currencies
SafeAddString(BMR_CURRENCY_PUSH								, "Im Inventar behalten", 1)
SafeAddString(BMR_CURRENCY_PUSH_TOOLTIP					, "Eingestellten Wert behalten.\n\nWenn der Wert für 'Auffüllen bis' eingestellt wurde, wird dies als Mindestwert für die jetzige Option hier verwendet werden.", 1)
		 
SafeAddString(BMR_CURRENCY_PULL								, "Auffüllen bis zu", 1)
SafeAddString(BMR_CURRENCY_PULL_TOOLTIP					, "Bis zum eingetragenen Wert auffüllen. Auf 0 lassen um diese Option zu deaktivieren.", 1)
		 
SafeAddString(BMR_CURRENCY_NOTHING							, "Kein(e) <<1>> behalten", 1)
SafeAddString(BMR_CURRENCY_NOTHING_TOOLTIP				, "Diese Option verlagert alles an <<1>> in die Bank wenn aktiviert.", 1)

SafeAddString(BMR_CURRENCY_KEEP_IN_BANK					, "In der Bank behalten", 1)
SafeAddString(BMR_CURRENCY_KEEP_IN_BANK_TOOLTIP			, "Haltet die gewünschte Menge in der Bank anstatt der Tasche und füllt die Bank auf, wenn die Fill-Up-Option festgelegt ist", 1)

SafeAddString(BMR_TRADESKILL_ALCHEMY						, "Alchemie", 1)
SafeAddString(BMR_TRADESKILL_CLOTHIER						, "Schneiderei", 1)
SafeAddString(BMR_TRADESKILL_PROVISIONING					, "Versorgen", 1)
SafeAddString(BMR_TRADESKILL_ENCHANTING						, "Verzaubern", 1)
SafeAddString(BMR_TRADESKILL_BLACKSMITHING					, "Schmiedekunst", 1)
SafeAddString(BMR_TRADESKILL_WOODWORKING					, "Schreinerei", 1)
SafeAddString(BMR_TRADESKILL_JEWELRYCRAFTING				, "Schmuckhandwerk", 1)

-- Trophies are hardcoded because there is nothing to label them
SafeAddString(BMR_TROPHY_TREASURE_MAP						, "Schatzkarten", 1)
SafeAddString(BMR_TROPHY_SURVEY_MAP							, "Fundberichte", 1)
SafeAddString(BMR_TROPHY_MOTIF_FRAGMENT					, "Stilfragmente", 1)
SafeAddString(BMR_TROPHY_RECIPE_FRAGMENT					, "Rezeptfragmente", 1)
SafeAddString(BMR_TROPHY_IMPERIALCITY_PVE					, "Kaiserstadt Trophäen", 1)
SafeAddString(BMR_TROPHY_QUEST_REWARD						, "Questbelohnungs Trophäen", 1)

-- Writ quests
SafeAddString(BMR_WRIT_QUESTS								, "Behalte/entnehme Handwerksquestgegenstände", 1)
SafeAddString(BMR_WRIT_QUESTS_TOOLTIP						, "Behalte/entnehme Gegenstände/Material die/das du für deine Handwerksquest benötigst", 1)

-- Bindings
SafeAddString(SI_BINDING_NAME_BMR_PROFILE1				, "Profil 1", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE2				, "Profil 2", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE3				, "Profil 3", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE4				, "Profil 4", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE5				, "Profil 5", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE6				, "Profil 6", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE7				, "Profil 7", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE8				, "Profil 8", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE9				, "Profil 9", 1)

-- Dropwdons
SafeAddString(BMR_ACTION_PUSH									, "In die Bank verlagern", 1)
SafeAddString(BMR_ACTION_PULL									, "Ins Inventar verlagern", 1)
SafeAddString(BMR_ACTION_NOTSET								, "-", 1)
SafeAddString(BMR_ACTION_PUSH_GBANK							, "In Gildenbank verlagern", 1)
SafeAddString(BMR_ACTION_PUSH_BOTH							, "In beide Banken verlagern", 1)

-- Chat notifications
SafeAddString(BMR_ACTION_ITEMS_MOVED					 	, "BMR hat <<3>>x |t16:16:<<2>>|t<<1>> <<4>> verlagert.", 1)
SafeAddString(BMR_ACTION_ITEMS_NOT_MOVED					, "BMR konnte keine <<3>>x |t16:16:<<2>>|t<<1>> <<4>> verlagern.", 1)
SafeAddString(BMR_ACTION_CURRENCY_SUMMARY					, "BMR hat <<1>> <<2>> verlagert.", 1)

SafeAddString(BMR_ACTION_HAS_MOVED							, "BMR hat verlagert ", 1)
SafeAddString(BMR_ACTION_CURRENCY_MOVED_TO2				, "in die Bank", 1)
SafeAddString(BMR_ACTION_CURRENCY_MOVED_TO3				, "in das Inventar", 1)

SafeAddString(BMR_ACTION_ITEMS_MOVED_TO1					, "in das Inventar", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO2					, "in die Bank", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO6					, "in die Bank", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO3					, "in die Gildenbank <<5>>", 1)
		 
SafeAddString(BMR_ACTION_ITEMS_SUMMARY	 					, "BMR hat <<1>>x verschiedene Items (<<2>> items) verlagert.", 1)
SafeAddString(BMR_RARE_INGREDIENTS							, "<<1>>, <<2>> & <<3>>", 1)
		 
-- Import
SafeAddString(BMR_IMPORT										, "BMR Einstellungen importieren von", 1)
SafeAddString(BMR_IMPORT_DESC									, "Von welchem Charakter Einstellungen importiert werden sollen. Beachten Sie dass Einstellungen Charaktermäßig behandelt werden, d.h. diese Einstellungen gelten nur für den jetzigen Charakter.", 1)
SafeAddString(BMR_IMPORTED										, "BMR Einstellungen wurden von <<1>> importiert.", 1)

SafeAddString(BMR_ZOS_LIMITATIONS							, "Wegen Spiel-Einschränkungen, konnte BMR nur 98 Gegenstände bearbeiten. Bitte warte 10 Sekunden und interagiere erneut mit dem NPC.", 1)
-- Neue Optionen / ScriptTracker
SafeAddString(BMR_GLOBAL_ADDON_PROFILE			, "Globales Addon-Profil (bei Auswahl UI neu laden)", 1)
SafeAddString(BMR_GLOBAL_ADDON_PROFILE_TOOLTIP	, "Wählt das globale BMR-Addon-Profil. Nach der Änderung wird die Benutzeroberfläche neu geladen. Standard: <<1>>", 1)
SafeAddString(BMR_PROFILE_COUNT					, "Anzahl der Profile", 1)
SafeAddString(BMR_PROFILE_COUNT_TOOLTIP			, "Legt fest, wie viele BMR-Profile verfügbar sind. Profile über dieser Zahl bleiben erhalten und werden ausgeblendet, bis die Anzahl wieder erhöht wird.", 1)

SafeAddString(BMR_SCRIPTTRACKER						, "ScriptTracker / Skripturen", 1)
SafeAddString(BMR_SCRIPTTRACKER_DESC					, "Skripturen, die der aktuelle Charakter bereits kennt, werden automatisch in die Bank gelegt. Skripturen, die der Charakter noch nicht kennt, werden aus der Bank entnommen. BMR führt die eigentliche Verlagerung durch.", 1)
SafeAddString(BMR_SCRIPTTRACKER_ENABLE				, "Automatische Skriptur-Verwaltung aktivieren", 1)
SafeAddString(BMR_SCRIPTTRACKER_ENABLE_TOOLTIP	, "Verwendet beim Öffnen der Bank den aktuellen Kenntnisstand des Charakters aus ScriptTracker.", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEPOSIT_KNOWN	, "Bekannte Skripturen in die Bank legen", 1)
SafeAddString(BMR_SCRIPTTRACKER_WITHDRAW_UNKNOWN, "Unbekannte Skripturen aus der Bank entnehmen", 1)
SafeAddString(BMR_SCRIPTTRACKER_ONE_ONLY			, "Nur ein Exemplar je unbekannter Skriptur entnehmen", 1)
SafeAddString(BMR_SCRIPTTRACKER_ONE_ONLY_TOOLTIP, "Wenn aktiviert, entnimmt BMR höchstens ein Exemplar jeder unbekannten Skriptur. Befindet sich die Skriptur bereits im Inventar, wird kein weiteres Exemplar entnommen.", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEBUG				, "ScriptTracker-Debugausgaben aktivieren", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEBUG_TOOLTIP	, "Schreibt detaillierte Diagnoseinformationen zu ScriptTracker und BMR in den Chat. Standardmäßig deaktiviert.", 1)

