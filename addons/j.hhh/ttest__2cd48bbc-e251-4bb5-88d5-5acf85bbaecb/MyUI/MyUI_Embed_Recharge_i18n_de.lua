if GetCVar("Language.2") ~= "de" then return end
local strings = {
--Addon LAM menu
	ARC_LAM_ADDON_DESC								= "Beim Eintreten oder Verlassen eines Kampfes, werden automatischen deine Waffen aufgeladen und deine Rüstung repariert.",
	ARC_LAM_OPTION_ACCOUNTWIDE						= "Accountweite Einstellung",
	ARC_LAM_OPTION_ACCOUNTWIDE_TT					= "Wenn du diese Einstellung aktivierst, werden die Einstellungen auf alle deiner Charakter übernommen.",
	ARC_LAM_HEADER_AUTO_CHARGE						= GetString(SI_CHARGE_WEAPON_TITLE),
	ARC_LAM_OPTION_AUTO_RECHARGE						= "Automatisch " .. GetString(SI_CHARGE_WEAPON_TITLE),
	ARC_LAM_OPTION_AUTO_RECHARGE_TT					= "Beim Eintreten/Verlassen eines Kampfes, wird automatisch die Waffen aufgeladen, sofern diese Einstellung aktiviert ist. " .. GetString(SI_CHARGE_WEAPON_CONSUME),
	ARC_LAM_OPTION_AUTO_RECHARGE_DELAY				= GetString(SI_CHARGE_WEAPON_TITLE) .. " Verzögerung",
	ARC_LAM_OPTION_AUTO_RECHARGE_DELAY_TT			= "Mit diesem Zeit Wert in Millisekunden (ms) zwischen jedem " .. GetString(SI_CHARGE_WEAPON_TITLE) .." Versuch -> Verhindere, dass der Server dich wegen Nachrichten-Spam vom Server wirft!\nAbhängig von der Anzahl der aktivierten AddOns, der Anzahl der spielenden Spieler, der Serverlast durch aktive Events etc., musst du diese Nummer ggf. höher einstellen!",
	ARC_LAM_OPTION_AUTO_REPAIR_DELAY					= GetString(SI_ITEM_FORMAT_STR_ARMOR) .." Verzögerung",
	ARC_LAM_OPTION_AUTO_REPAIR_DELAY_TT				= "Mit diesem Zeit Wert in Millisekunden (ms) zwischen jedem " .. GetString(SI_ITEM_FORMAT_STR_ARMOR) .." Versuch -> Verhindere, dass der Server dich wegen Nachrichten-Spam vom Server wirft!\nAbhängig von der Anzahl der aktivierten AddOns, der Anzahl der spielenden Spieler, der Serverlast durch aktive Events etc., musst du diese Nummer ggf. höher einstellen!",
	ARC_LAM_OPTION_AUTO_RECHARGE_MIN_TH	 			= "Grenzwert [%] zum Aufladen",
	ARC_LAM_OPTION_AUTO_RECHARGE_MIN_TH_TT			= "Setze einen Wert zwischen 0-99%. Deine Waffen werden automatisch aufgeladen, sobald dieser Wert erreicht oder unterschritten wird.",
	ARC_LAM_HEADER_AUTO_REPAIR						= GetString(SI_ITEM_FORMAT_STR_ARMOR) .. " reparieren",
	ARC_LAM_OPTION_AUTO_REPAIR						= "Automatisch Reparieren",
	ARC_LAM_OPTION_AUTO_REPAIR_TT		   			= "Beim Eintreten/Verlassen eines Kampfes, wird automatisch die Rüstung repariert, sofern diese Einstellung aktiviert ist. " .. GetString(SI_REPAIR_KIT_CONSUME),
	ARC_LAM_OPTION_AUTO_REPAIR_MIN_TH   				= "Grenzwert [%] zum Reparieren",
	ARC_LAM_OPTION_AUTO_REPAIR_MIN_TH_TT				= "Setze einen Wert zwischen 0-99%. Deine Rüstung wird automatisch repariert, sobald dieser Wert erreicht oder unterschritten wird.",
	ARC_LAM_HEADER_CHATOUTPUT						= GetString(SI_CHAT_TAB_GENERAL) .. " " .. GetString(SI_AUDIO_OPTIONS_OUTPUT),
    ARC_LAM_OPTION_SHOW_CHAT_MSG						= "Chatmitteilungen",
	ARC_LAM_OPTION_SHOW_CHAT_MSG_TT					= "Zeigt dir Chatmitteilungen an, wenn aufgeladen/repariert wurde, oder ein Fehler auftrat.",
	ARC_LAM_OPTION_SUPPRESS_CHAT_MSG_NOTHING			= "Deaktiviere die \'Nichts ...\' Mitteilungen",
	ARC_LAM_OPTION_SUPPRESS_CHAT_MSG_NOTHING_TT		= "Deaktiviert die \'Nichts geladen\' und die \'Nichts repariert\' Mitteilungen",
	ARC_LAM_HEADER_ALERT 							= "Alarm Meldungen",
	
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT				= "Zeigt \'Reparatursets leer\' Meldungen",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_TT			= "Bei leeren Reparatursets wird eine Alarm Meldung in der Mitte vom Bildschirm angezeigt",
	ARC_LAM_OPTION_ALERT_SOON_EMPTY_REPAIRKIT		= "Zeigt \'Reparatursets gehen bald aus\' Meldungen",
	ARC_LAM_OPTION_ALERT_SOON_EMPTY_REPAIRKIT_TT		= "Wenn deine Reparatursets knapp werden, wird eine Alarm Meldung in der Mitte vom Bildschirm angezeigt.\n\nLege den Grenzwert der Meldung auf der rechten Seite fest!",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_TH			= "Grenzwert Meldung",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_TH_TT		= "Wähle einen Wert zwischen 1 und 100 aus. Falls du den Wert erreichst oder unterschreitest, nachdem ein Kampf beendet ist, wird es dir eine Alarm Meldung anzeigen.",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_LOGIN		= "Zeigt \'Reparatursets leer\' nach Anmelden/Reloadui",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_LOGIN_TT	= "Wenn aktiviert wird es dir eine Alarm Meldung nach dem Anmelden/Reloadui zeigen, sofern der Grenzwert erreicht oder unterschritten wird.",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_VENDOR		= "Zeigt \'Reparatursets leer\' beim Händler",
	ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_VENDOR_TT	= "Wenn aktiviert wird es dir eine Alarm Meldung nach dem öffnen eines Händler Menüs zeigen, sofern der Grenzwert erreicht oder unterschritten wird.",

	ARC_LAM_OPTION_ALERT_EMPTY_SOULGEM				= "Zeigt \'" .. GetString(SI_ITEMTYPE19) .. " leer\' Meldungen",
	ARC_LAM_OPTION_ALERT_EMPTY_SOULGEM_TT			= "Bei leeren " .. GetString(SI_ITEMTYPE19) .. " wird eine Alarm Meldung in der Mitte vom Bildschirm angezeigt",
	ARC_LAM_OPTION_ALERT_SOON_EMPTY_SOULGEM			= "Zeigt \'" .. GetString(SI_ITEMTYPE19) .. " gehen bald aus \' Meldungen",
	ARC_LAM_OPTION_ALERT_SOON_EMPTY_SOULGEM_TT		= "Wenn deine " .. GetString(SI_ITEMTYPE19) .. " knapp werden, wird eine Alarm Meldung in der Mitte vom Bildschirm angezeigt.\n\nLege den Grenzwert der Meldung auf der rechten Seite fest!",
	ARC_LAM_OPTION_ALERT_EMPTY_SOULGEM_TH			= "Grenzwert Meldung",
	ARC_LAM_OPTION_ALERT_EMPTY_SOULGEM_TH_TT			= GetString(ARC_LAM_OPTION_ALERT_EMPTY_REPAIRKIT_TH_TT),
	ARC_LAM_OPTION_ALERT_EMPTY_SOULGEM_LOGIN	  		= "Zeige \'" .. GetString(SI_ITEMTYPE19) .. " leer \' nach Anmelden/Reloadui",
	ARC_LAM_OPTION_ALERT_EMPTY_SOULGEM_LOGIN_TT		= "Wenn aktiviert wird es dir eine Alarm Meldung nach dem Anmelden/Reloadui zeigen, sofern der Grenzwert erreicht oder unterschritten wird.",

	ARC_LAM_OPTION_SHOW_REPAIR_KITS_LEFT_AT_VENDOR	= "Zeige restl. Reparatursets beim Händler",
	ARC_LAM_OPTION_SHOW_REPAIR_KITS_LEFT_AT_VENDOR_TT= "Zeigt deine aktuell verbliebenen Reparatursets bei einem Hädnler als kleines Symbol mit der Anzahl daneben an.",
	ARC_LAM_OPTION_USE_REPAIR_KITS_FOR_ITEM_LEVEL	= "Reparaturset entspricht Level",
	ARC_LAM_OPTION_USE_REPAIR_KITS_FOR_ITEM_LEVEL_TT = "Sollten verschiedene Reparatursets im Inventar verfügbar sein, so wird das dem zu reparierenden Gegenstand Level entsprechende verwendet (z.B. 'Groß' für CP160 Rüstung), um den Gegenstand auf mindestens 90% zu reparieren",
	ARC_LAM_OPTION_DO_NOT_USE_CROWN_STORE_REPAIR_KITS= "Kronen Shop Reparatur Kits nicht verwenden",
	ARC_LAM_OPTION_DO_NOT_USE_CROWN_STORE_REPAIR_KITS_TT = "Ist diese Option aktiviert, dann werden Reparatursets aus dem Kronen Shop nicht für automatische Reparaturen verwendet.",
	ARC_LAM_OPTION_USE_CROWN_STORE_REPAIR_KITS_FIRST = "Kronen Reperaturkits zuerst",
	ARC_LAM_OPTION_USE_CROWN_STORE_REPAIR_KITS_FIRST_TT = "Verwende die Kronenshop Reperaturkits zuerst, und wenn keine mehr da sind verwende die normalen Kits",
	ARC_LAM_OPTION_USE_CROWN_STORE_SOULGEMS_FIRST = "Kronen Seelensteine zuerst",
	ARC_LAM_OPTION_USE_CROWN_STORE_SOULGEMS_FIRST_TT = "Verwende die Kronenshop Seelensteine zuerst, und wenn keine mehr da sind verwende die normalen Seelensteine",

	ARC_LAM_OPTION_ALERT_RELOADUI_LOGIN_ZONING 		= "Nur beim Login/reloadUI/Zonenwechsel",
	ARC_LAM_OPTION_ALERT_RELOADUI_LOGIN_ZONING_TT	= "Zeigt die Warnung nur an wenn du dich einloggst, die Benutzeroberfläche neu lädst oder bei einem Zonenwechsel (mit Ladebildschirm)",
	ARC_LAM_OPTION_ALERT_VENDOR						= "Zeige Warnung beim Händler an",
	ARC_LAM_OPTION_ALERT_VENDOR_TT					= "Wenn du den Händler öffnest:\nZeige eine Warnung auf dem Bildschirm an",

	--Chat output messages
	ARC_CHATOUTPUT_CHARGED							= GetString(SI_ITEMTRAITTYPE2) .. ": ",
	ARC_CHATOUTPUT_CHARGED_NOTHING	   				= zo_strformat("Nichts <<c:1>>:", GetString(SI_ITEMTRAITTYPE2)),
	ARC_CHATOUPUT_NO_CHARGEABLE_WEAPONS				= GetString(SI_SOULGEMITEMCHARGINGREASON1),
	ARC_CHATOUTPUT_REPAIRED							= "Repariert: ",
	ARC_CHATOUTPUT_REPAIRED_NOTHING					= "Nichts repariert: ",
	ARC_CHATOUPUT_NO_REPAIRABLE_ARMOR				= GetString(SI_NO_REPAIRS_TO_MAKE),

	ARC_CHATOUPUT_MIN_CHARGE 						= GetString(SI_GRAPHICSPRESETS0) .. " " .. GetString(SI_CHARGE_WEAPON_CONFIRM) .. ": ",
	ARC_CHATOUPUT_MIN_CONDITION 						= GetString(SI_GRAPHICSPRESETS0) .. " " .. GetString(SI_REPAIR_SORT_TYPE_CONDITION) .. ": ",
	ARC_CHATOUPUT_INVALID_PERCENTAGE					= "Ungültiger Prozentsatz: <<C:1>>, Werte: 0-99.",
	ARC_CHATOUPUT_CHARGE								= GetString(SI_CHARGE_WEAPON_CONFIRM) .. " ",
	ARC_CHATOUPUT_REPAIR								= GetString(SI_REPAIR_KIT_TITLE) .. " ",
    ARC_CHATOUPUT_SETTINGS_ENABLED					= GetString(SI_ADDON_MANAGER_ENABLED),
    ARC_CHATOUPUT_SETTINGS_DISABLED					= GetString(SI_CHECK_BUTTON_DISABLED),

	ARC_CHATOUPUT_REPAIRKITS_EMPTY_THRESHOLD			= "Grenze leere "  .. GetString(SI_HOOK_POINT_STORE_REPAIR_KIT_HEADER) .. " ",
    ARC_CHATOUPUT_SOULGEMS_EMPTY_THRESHOLD			= "Grenze leere " .. GetString(SI_ITEMTYPE19) .. ": ",

	ARC_LAM_OPTION_AUTO_RECHARGE_IN_COMBAT			= GetString(SI_CHARGE_WEAPON_TITLE) .. " im Kampf",
	ARC_LAM_OPTION_AUTO_RECHARGE_IN_COMBAT_TT		= "Automatisch deine Waffen auch im Kampf aufladen",
	ARC_LAM_OPTION_AUTO_RECHARGE_ON_WEAPON_PAIR_CHANGE		= GetString(SI_CHARGE_WEAPON_TITLE) .. " beim Waffe wechseln",
	ARC_LAM_OPTION_AUTO_RECHARGE_ON_WEAPON_PAIR_CHANGE_TT	= "Beim Waffen Wechsel diese prüfen und aufladen.",
	ARC_LAM_OPTION_AUTO_RECHARGE_ON_WEAPON_PAIR_CHANGE_ONLY_IN_COMBAT = "Waffen Wechsel: Nur im Kampf",
	ARC_LAM_OPTION_AUTO_RECHARGE_ON_WEAPON_PAIR_CHANGE_ONLY_IN_COMBAT_TT = "Führt die " .. GetString(SI_CHARGE_WEAPON_TITLE) .. " Prüfung beim Waffen Wechsel nur im Kampf aus",

	ARC_LAM_OPTION_AUTO_REPAIR_IN_COMBAT				= "Reparieren im Kampf",
	ARC_LAM_OPTION_AUTO_REPAIR_IN_COMBAT_TT		   	= "Automatisch deine Rüstung auch im Kampf reparieren",

--Alert messages
	ARC_ALERT_REPAIRKITS_EMPTY						= "Die Reparatursets sind ausgegangen!",
	ARC_ALERT_REPAIRKITS_SOON_EMPTY					= "Die Reparatursets gehen bald aus! Nur <<C:1>> übrig!",
	ARC_ALERT_SOULGEMS_EMPTY							= "Die " .. GetString(SI_ITEMTYPE19) .. " sind ausgegangen!",
	ARC_ALERT_SOULGEMS_SOON_EMPTY					= "Die " .. GetString(SI_ITEMTYPE19) .. " gehen bald aus! Nur <<C:1>> übrig!",

    --Keybindings
    SI_KEYBINDINGS_CATEGORY_RECHARGE                    = "Auto Recharge",
    SI_BINDING_NAME_RUN_RECHARGE                        = "Nutze AutoRecharge/AutoRepair",
	SI_BINDING_NAME_RUN_REPAIR_SINGLE					= "Nutze AutoRepair",
	SI_BINDING_NAME_RUN_RECHARGE_SINGLE					= "Nutze AutoRecharge",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
