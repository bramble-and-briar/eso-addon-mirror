---------------------------------------------
-- German localization for MasterThief
---------------------------------------------
-- translated by Adalan@Aruntas
-- updated by WolfStar07

local localization_strings = {
	-- settings panel name
	MASTER_THIEF_NAME = "Master Thief",
	
	-- options checkboxes
	MT_SNEAK_MODE_NAME = "Schleich- und Stehlen-Modus",
	MT_SNEAK_MODE_TEXT = "Es funktioniert wie ein Sicherheitsnetz. Du kannst alle Behälter (außer Tresore) inspizieren, ohne geschlichen zu sein und nicht alles automatisch zu plündern. Dies hilft, wenn Wachen oder NPCs in der Nähe sind und du nur sehen möchtest, ob es etwas Wertvolles zu stehlen gibt.",
	MT_SHOW_MESSAGEBOX_NAME = "Nachrichtenrahmen anzeigen",
	MT_SHOW_MESSAGEBOX_TEXT = "Nachrichtenrahmen auf dem Bildschirm erzwingen, um Verschieben und Positionieren zu ermöglichen.",
	MT_EXCLUDE_COMPARE_NAME = "Gemeinsame Kenntnisse plündern",
	MT_EXCLUDE_COMPARE_TEXT = "Diese Option überprüft deine bekannten Rezepte und Baupläne über dein Konto hinweg (erfordert LibCharacterKnowledge). Wenn deaktiviert, werden nur die Kenntnisse deines aktuellen Charakters überprüft.",
	MT_LOOT_UNKNOWN_RECIPES_NAME = "Unbekannte erzwingen",
	MT_LOOT_UNKNOWN_RECIPES_TEXT = "Alle unbekannten Rezepte und Baupläne plündern, unabhängig vom eingestellten Qualitätslevel. Wenn deaktiviert, werden nur Rezepte und Baupläne mit dem eingestellten Qualitätslevel oder höher automatisch geplündert.",
	MT_AUTOLOOT_FROM_LOOTLIST_NAME = "Beuteliste automatisch plündern",	
	MT_AUTOLOOT_FROM_LOOTLIST_TEXT = "Wenn aktiviert, stiehlst du automatisch Gegenstände, die zur Beuteliste hinzugefügt wurden. Zugriff auf das Beutefenster erhältst du durch Eingabe von |cedbe3e/mtloot|r.",
	MT_PICKPOCKET_COUNTER_NAME = "Taschendiebstahlzähler",
	MT_PICKPOCKET_COUNTER_TEXT = "Taschendiebstahlzähler auf dem Bildschirm, da NPCs sich gerne bewegen. Töten setzt den Zähler zurück. Gilt für alle NPCs mit demselben generischen Namen, z. B. Löwengarde, also unbedingt durch Töten oder Teleportieren zurücksetzen.",
	
	-- options slider
	MT_MESSAGE_DELAY_NAME = "Nachrichtenverzögerung",
	MT_MESSAGE_DELAY_TEXT = "Lege die Verzögerung für Bildschirmnachrichten in Millisekunden fest, d.h. 1000 Einheiten = 1 Sekunde.",
	MT_FREE_SLOTS_LEFT_LIMIT_NAME = "Warnschwelle für freie Taschenplätze",
	MT_FREE_SLOTS_LEFT_LIMIT_TEXT = "Lege die Mindestanzahl freier Plätze in deiner Tasche fest, bevor eine Warnmeldung über freie Plätze angezeigt wird.",
	MT_MIN_SELL_PRICE_AUTOLOOT_NAME = "Mindestverkaufspreis für automatisches Plündern",
	MT_MIN_SELL_PRICE_AUTOLOOT_TEXT = "Lege den Mindestverkaufspreis fest, um automatisches Plündern gestohlener Gegenstände zu aktivieren. Beachte, dass dies Rezepte, Baupläne und Motive ausschließt, die durch Autoloot-Einstellungen gesteuert werden.",

	-- options dropdown
	MT_RECIPE_QUALITY_NAME = "Mindestqualität von Rezepten",
	MT_RECIPE_QUALITY_TEXT = "Wähle das Mindestqualitätslevel eines Rezepts oder Bauplans für automatisches Plündern. Unbekannte unterhalb des angegebenen Levels werden nur automatisch geplündert, wenn du es explizit erlaubst.",
	MT_RECIPE_COLOR_GREEN = "grün",
	MT_RECIPE_COLOR_BLUE = "blau",
	MT_RECIPE_COLOR_PURPLE = "lila",
	MT_RECIPE_COLOR_GOLD = "gold",

	-- options submenu - announcements
	MT_SUB_ANNOUNCE_NAME = "Ankündigungen",
	MT_SUB_ANNOUNCE_TEXT = "Alle Ankündigungen",
	MT_SUB_ANNOUNCE_ONSCREENMSG_NAME = "Mit Bildschirmnachricht ankündigen",
	MT_SUB_ANNOUNCE_ONSCREENMSG_TEXT = "Rezepte, Baupläne und Motive als Bildschirmnachricht ankündigen.",
	MT_SUB_ANNOUNCE_SPECIALS_NAME = "Spezielle Gegenstände im Chat ankündigen",
	MT_SUB_ANNOUNCE_SPECIALS_TEXT = "Rezepte, Baupläne und Motive im Chat ankündigen. Nur du siehst diese Ankündigungen.",
	MT_SUB_ANNOUNCE_REGULAR_NAME = "Informationen im Chat ankündigen",
	MT_SUB_ANNOUNCE_REGULAR_TEXT = "Informationen wie Zahlungen an Wachen/Verhökern, verkaufte Gegenstände, Kopfgeld usw. im Chat ankündigen.",	
	MT_SUB_ANNOUNCE_USELESS_NAME = "Plunder-Gegenstände ankündigen",
	MT_SUB_ANNOUNCE_USELESS_TEXT = "Plunder-Gegenstände wie durch Mindestverkaufspreis definiert ankündigen. Du kannst diese Gegenstände mit dem Befehl /mt_junk auflisten. Schließt Rezepte, Baupläne oder Motive aus.",
	MT_SUB_ANNOUNCE_BECAREFUL_NAME = "\"Sei vorsichtig\" beim Schleichen ankündigen",
	MT_SUB_ANNOUNCE_BECAREFUL_TEXT = "\"Sei vorsichtig\"-Nachricht anzeigen, weil der Abstand zu NPCs nicht weit genug ist, um vollständig geschlichen zu sein. Dies sollte dir beim vollständig geschlichenen Schleichen und Stehlen helfen.",	
	MT_SUB_ANNOUNCE_KNOWN_RECIPES_NAME = "Bekannte Rezepte ankündigen",
	MT_SUB_ANNOUNCE_KNOWN_RECIPES_TEXT = "Eine Nachricht über das Plündern bereits bekannter Rezepte im Chat ausgeben.",	
	MT_SUB_ANNOUNCE_SELLS_TRANSFERS_NAME = "Verhökern/Wäscher im Chat ankündigen",
	MT_SUB_ANNOUNCE_SELLS_TRANSFERS_TEXT = "Eine Nachricht über Verhökern- und Wäscher-Transaktionen im Chat ausgeben.",	
	MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_NAME = "Verhöker-Limits ankündigen",
	MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_TEXT = "Eine Nachricht im Chat ausgeben, wenn du zu viele Gegenstände zum Verhökern oder Wäschen trägst.",
	
	-- options submenu - companion
	MT_COMP_MENU_SUBMENU_NAME = "Begleiter-Verbundenheitsschutz",
	MT_COMP_MENU_SUBMENU_TOOLTIP = "Einstellungen zum Schutz der Begleiter-Verbundenheit bei Diebstahlaktivitäten.",
	MT_COMP_MENU_WARN_NAME = "Bei missbilligten Aktionen warnen",
	MT_COMP_MENU_WARN_TOOLTIP = "Zeige eine Warnung, wenn dein Begleiter Verbundenheit verlieren würde.",
	MT_COMP_MENU_BLOCK_NAME = "Missbilligte Aktionen blockieren",
	MT_COMP_MENU_BLOCK_TOOLTIP = "Verhindere Aktionen, die dein Begleiter missbilligt, anstatt dich nur zu warnen.",
	MT_COMP_MENU_AUTODISMISS_NAME = "Automatisch entlassen in Gebieten der Dunklen Bruderschaft",
	MT_COMP_MENU_AUTODISMISS_TOOLTIP = "Entlasse automatisch Begleiter, die die Dunkle Bruderschaft nicht mögen, wenn du ihr Heiligtum betrittst.",

	-- Misc Text
	MT_MISC_TRASH_TEXT = "Plunder: ",
	MT_MISC_SOLD_FOR = " verkauft für ",
	MT_MISC_BOUNTY_IS = "Kopfgeld ist ",
	MT_MISC_BOUNTY_REMOVED_FROM_BODY = "Volles Kopfgeld wurde von deinem toten Körper entfernt!",
	MT_MISC_ALL_STOLEN_ITEMS_REMOVED = "Alle gestohlenen Gegenstände wurden von einer Wache entfernt!",
	MT_MISC_YOU_PAID_BOUNTY = "Du hast Kopfgeld bezahlt: ",
	MT_MISC_YOU_SOLD_AN_ITEM_FOR = "Du hast einen Gegenstand verhökert für ",
	MT_MISC_SNEAKMODE_ACTIVE = "Schleichen und Stehlen aktiv",
	MT_MISC_SNEAKMODE_SLEEPING = "Schleichen und Stehlen inaktiv",
	MT_MISC_BE_CAREFUL = "Sei vorsichtig!",
	MT_MISC_IS_KNOWN = "Bereits bekannt: ",
	MT_MISC_FREE_SLOTS_LEFT = "Freie Plätze übrig: ",
	MT_MISC_SELL_MAXIMUM_REACHED = "Warnung: Trägst mehr Gegenstände als verbleibende Verhökern-Plätze!",
	MT_MISC_TRANSFER_MAXIMUM_REACHED = "Warnung: Trägst mehr Gegenstände als verbleibende Wäscher-Plätze!",
	MT_MISC_ITEM_DESTROYED = "...zerstört!",
	MT_MISC_LIST_USELESS_ITEMS = "Liste der Plunder-Gegenstände: ",
	MT_MISC_USELESS_ITEMS_FOUND = "Plunder-Gegenstände gefunden: ",
	MT_MISC_TYPE_COMMAND_DESTROY_ITEM = "Gib /mt_junk delete ein, um sie zu zerstören",
	MT_MISC_NO_ITEMS_FOUND = "Keine Gegenstände zum Zerstören gefunden",
	MT_MISC_ITEMS_BELOW_VALUE_USELESS = "Gegenstände unter diesem Verkaufspreis sind Plunder: ",
	MT_MISC_FOUND_ALOT_GOLD_TEXT = "Du hast Gold geplündert. Gestohlen: ",
	MT_MISC_ITS_KNOWN_BUT_WANTED_TEXT = "Bekannt, aber geplündert: ",
	MT_MISC_LOOTLIST_TEXT = "Beuteliste anzeigen",

	--Text for command list on chat
	MT_MISC_MASTERTHIEF_COMMANDS = "MasterThief Befehle:",
	MT_MISC_MASTERTHIEF_LISTCOMMANDS = "Alle Chat-Befehle auflisten",
	MT_MISC_CMD_LIST_ALL_USELESS_ITEMS = "Liste aller Plunder-Gegenstände",
	MT_MISC_CMD_DESTROY_ALL_USELESS_ITEMS = "Alle Plunder-Gegenstände zerstören",
	
	--Text for recipe tooltip
	MT_MISC_TOOLTIP_RECIPE_CHARS = "Dieses Rezept ist bekannt bei:",

	--Text for Lootlist
	MT_MISC_LOOTLIST_DELETE = " von Beuteliste entfernt",
	MT_MISC_ITEM_ADDED = " zur Beuteliste hinzugefügt",
	MT_MISC_ITEM_ALREADY_ON_LOOTLIST = "Gegenstand ist bereits auf Beuteliste",
	MT_MISC_WORTHFUL_ITEMS = "Beuteliste interessanter Gegenstände",
	MT_MISC_ITEM_TOOLTIP = "Gegenstand ist bereits auf Beuteliste",
	
	-- Text for Context-Menu
	MT_CONTEXTMENU_LOOT_MARK = "Für automatisches Plündern markieren",	
	
	-- Statistics window headers
	MT_STATS_SESSION_HEADER = "Sitzungsstatistiken",
	MT_STATS_LIFETIME_HEADER = "Gesamtstatistiken",
	
	-- Session stats - Looting
	MT_STATS_ITEMS_LOOTED = "Automatisch geplünderte Gegenstände:",
	MT_STATS_ITEMS_SKIPPED = "Übersprungene Gegenstände:",
	MT_STATS_MOTIFS_LOOTED = "Geplünderte Motive:",
	MT_STATS_RECIPES_LOOTED = "Geplünderte Rezepte:",
	MT_STATS_FURNISHING_PLANS = "Einrichtungspläne:",
	MT_STATS_FURNISHINGS = "Geplünderte Einrichtungen:",
	MT_STATS_HIDDEN_WALLETS = "Versteckte Geldbörsen:",
	MT_STATS_RESEARCH_PORTFOLIOS = "Forschungsportfolios:",
	MT_STATS_EDICTS = "Geplünderte Edikte:",
	
	-- Session stats - Justice
	MT_STATS_PICKPOCKETS = "Taschendiebstähle:",
	MT_STATS_SAFEBOXES = "Geknackte Tresore:",
	MT_STATS_DOORS = "Geknackte Türen:",
	MT_STATS_LOCKPICK_BREAKS_PREVENTED = "Tanlorins Führung:",
	MT_STATS_BOW_KILLS = "Klinge des Leids Kills:",
	MT_STATS_GUARD_DEATHS = "Tode durch Wachen:",
	MT_STATS_GOLD_FENCED = "Verhökertes Gold:",
	MT_STATS_HIGHEST_BOUNTY = "Höchstes Kopfgeld:",
	MT_STATS_TROVES = "Diebesverstecke:",
	MT_STATS_HIGHEST_VALUE = "Wertvollster Gegenstand:",
	
	-- Lifetime stats
	MT_STATS_LIFETIME_BOUNTY_PAID = "Gesamt bezahltes Kopfgeld:",
	MT_STATS_GOLD_LAUNDERED = "Für Geldwäsche ausgegebenes Gold:",
	MT_DIALOG_RESET_LIFETIME_TITLE = "Lebensstatistiken zurücksetzen",
	MT_DIALOG_RESET_LIFETIME_TEXT = "Bist du sicher, dass du alle Lebensstatistiken zurücksetzen möchtest? Dies kann nicht rückgängig gemacht werden.",
	MT_DIALOG_RESET_LIFETIME_CONFIRM = "Zurücksetzen",
	MT_DIALOG_RESET_LIFETIME_CANCEL = "Abbrechen",
	
	-- Buttons
	MT_STATS_RESET_SESSION = "Sitzungsstatistiken zurücksetzen",
	MT_STATS_RESET_LIFETIME = "Gesamtstatistiken zurücksetzen",
	MT_STATS_CLOSE = "Schließen",
	
	-- Bastian
	MT_COMP_STEALTH_BASTIAN = "mag Diebstahl und Taschendiebstahl nicht. Erwäge, ihn zu entlassen.",
	MT_COMP_ARRESTED_BASTIAN = "mag Flucht nicht! Bitte um Nachsicht oder zahle die Strafe, um den Verbundenheitsverlust zu minimieren.",
	
	-- Isobel
	MT_COMP_STEALTH_ISOBEL = "mag es nicht, aus Behältern, Leichen und Diebestruhen zu stehlen.",
	
	-- Sharp
	MT_COMP_STEALTH_SHARP = "mag es nicht, Bettlern, Arbeitern oder Fischern die Tasche zu stehlen.",
	
	-- Tanlorin
	MT_COMP_STEALTH_TANLORIN = "verliert Verbundenheit, wenn du Kinderspielzeug, Puppen oder Leichen stiehlst.",
	
	-- Zerith
	MT_COMP_STEALTH_ZERITH = "verliert Verbundenheit, wenn du medizinische, religiöse oder sentimentale Gegenstände stiehlst, Leichen plünderst oder Erlasse verwendest.",
	
	-- Arrest advice 
	MT_COMP_ARRESTED_PAYBOUNTY = "mag es nicht, Wachen zu bezahlen! Fliehe oder bitte um Nachsicht, um Verbundenheitsverlust zu vermeiden.",
	MT_COMP_ARRESTED_GENERIC = "mag diese Situation nicht! Überlege deine Optionen sorgfältig.",
	
	-- Other warnings
	MT_COMP_TROVE_WARN = "mag das Plündern von Diebestruhen nicht! Verbundenheit wird sinken.",
	MT_COMP_PICKPOCKET_WARN = "mag Taschendiebstahl nicht! Verbundenheit wird sinken.",
	MT_COMP_CONTAINER_WARN = "mag es nicht, aus Behältern zu stehlen! Verbundenheit wird sinken.",
	MT_COMP_CORPSE_WARN = "mag das Plündern von Leichen nicht! Verbundenheit wird sinken.",
	MT_COMP_BOUNTY_WARN = "mag es nicht, wenn du erwischt wirst! Erwäge, einen Erlass zu nutzen oder entlasse ihn, bevor ein Wächter dich verhaftet.",
	MT_COMP_BOW_AVAILABLE_WARN = "mag Attentate nicht — Klinge des Wehs ist verfügbar! Tritt zurück, um Verbundenheitsverlust zu vermeiden.",
	MT_COMP_BOW_USED_WARN = "mag die Klinge des Wehs nicht! Verbundenheit ist gesunken.",
	MT_COMP_REFUGE_WARN = "mag Gesetzlosenzufluchtsorte nicht! Verbundenheit wird sinken.",
	MT_COMP_DB_WARN = "mag die Dunkle Bruderschaft nicht!",
	MT_COMP_PAYBOUNTY_WARN = "mag es nicht, einem Wächter Kopfgeld zu zahlen! Verbundenheit wird sinken.",
	MT_COMP_FENCE_WARN = "mag den Verkauf gestohlener Waren nicht! Verbundenheit wird sinken.",
	MT_COMP_EDICT_WARN = "mag die Verwendung von Erlassen nicht! Verbundenheit wird sinken.",
	
	-- Blocked actions
	MT_COMP_TROVE_BLOCK = "mag Diebestruhen nicht! Aktion blockiert.",
	MT_COMP_PICKPOCKET_BLOCK = "mag Taschendiebstahl nicht! Aktion blockiert.",
	MT_COMP_CONTAINER_BLOCK = "mag es nicht, aus Behältern zu stehlen! Aktion blockiert.",
	MT_COMP_BOW_BLOCK = "mag Attentate nicht! Klinge des Wehs blockiert.",
	MT_COMP_REFUGE_BLOCK = "mag Gesetzlosenzufluchtsorte nicht! Zutritt blockiert.",
	MT_COMP_DB_DISMISSED = "wurde entlassen — sie mag die Dunkle Bruderschaft nicht.",
	MT_COMP_FENCE_BLOCK = "mag den Verkauf gestohlener Waren nicht! Hehler geschlossen.",
	MT_COMP_EDICT_BLOCK = "mag die Verwendung von Erlassen nicht! Aktion blockiert.",
	
}

for stringId, stringValue in pairs(localization_strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end