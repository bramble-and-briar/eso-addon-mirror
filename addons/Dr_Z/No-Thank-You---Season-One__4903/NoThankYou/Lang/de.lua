-------------------------------------
-- German localization for No, Thank You by Bosmerland & Scootworks --
-------------------------------------

SafeAddString(NOTY_INTERACTION_TAKE,			"Einfangen", 1) -- Don't change
SafeAddString(NOTY_INSECT_BUTTERFLY,			"Schmetterling", 1) -- Don't change
SafeAddString(NOTY_INSECT_TORCHBUG,			"Fackelkäfer", 1) -- Don't change
SafeAddString(NOTY_INSECT_WASP,				"Wespe", 1) -- Don't change
SafeAddString(NOTY_INSECT_FLESHFLIES,			"Fleischfliegen", 1) -- Don't change
SafeAddString(NOTY_INSECT_DRAGONFLY,			"Libelle", 1) -- Don't change
SafeAddString(NOTY_INSECT_NETCHCALF,			"Netchkalb", 1) -- Don't change
SafeAddString(NOTY_INSECT_FETCHERFLY,			"Zunderfliege", 1) -- Don't change
SafeAddString(NOTY_INSECT_DOVAH,			"Seths Dovahviin", 1) -- Don't change

SafeAddString(NOTY_RAID_COMPLETE,			" haben", 1) -- Don't change
SafeAddString(NOTY_RAID_OTHERS,				"und <<1>> andere ", 1) -- Don't change

SafeAddString(NOTY_ENTERING_GROUP_AREA,			"Ihr habt einen Bereich für Gruppen betreten.", 1) -- Don't change
SafeAddString(NOTY_LEAVING_GROUP_AREA,			"Ihr habt den Bereich für Gruppen verlassen.", 1) -- Don't change

SafeAddString(NOTY_GUILD_INV_OPTION_0,			"niemals", 1)
SafeAddString(NOTY_GUILD_INV_OPTION_1,			"immer", 1)
SafeAddString(NOTY_GUILD_INV_OPTION_2,			"bei maximaler Gildenanzahl", 1)

SafeAddString(NOTY_AVA_MODE_OPTION_0,			"keine", 1)
SafeAddString(NOTY_AVA_MODE_OPTION_1,			"Chatnachricht", 1)
SafeAddString(NOTY_AVA_MODE_OPTION_2,			"stumm", 1)

SafeAddString(NOTY_SOUND_MODE_OPTION_0,			"niemals", 1)
SafeAddString(NOTY_SOUND_MODE_OPTION_1,			"wenn nicht im Kampf", 1)
SafeAddString(NOTY_SOUND_MODE_OPTION_2,			"während des Kampfs", 1)
SafeAddString(NOTY_SOUND_MODE_OPTION_3,			"immer", 1)

SafeAddString(NOTY_GALERTS_OPTION_0,			"keine", 1)
SafeAddString(NOTY_GALERTS_OPTION_1,			"Chatnachricht", 1)
SafeAddString(NOTY_GALERTS_OPTION_2,			"stumm", 1)

SafeAddString(NOTY_RAID_OPTION_0,			"immer", 1)
SafeAddString(NOTY_RAID_OPTION_1,			"niemals", 1)

SafeAddString(NOTY_MOTD_OPTION_0,			"keine", 1)
SafeAddString(NOTY_MOTD_OPTION_1,			"Chatnachricht", 1)
SafeAddString(NOTY_MOTD_OPTION_2,			"stumm", 1)

SafeAddString(NOTY_MOTD_OPTION_0,			"keine", 1)
SafeAddString(NOTY_MOTD_OPTION_1,			"Chatnachricht", 1)
SafeAddString(NOTY_MOTD_OPTION_2,			"stumm", 1)

SafeAddString(NOTY_LUAERR_OPTION_0,			"keine", 1)
SafeAddString(NOTY_LUAERR_OPTION_1,			"Mitteilung", 1)
SafeAddString(NOTY_LUAERR_OPTION_2,			"Chatnachricht", 1)

SafeAddString(NOTYOU_LUAERR_MESSAGE,			"Lua Fehler ausgelöst!", 1)
SafeAddString(NOTYOU_LUAERR_HEADING,			"Lua Fehler", 1)
SafeAddString(NOTYOU_LUAERR_SHORT,			"Lua Fehler", 1)

SafeAddString(NOTYOU_LUADIALOG_TITLE,			"Lua hat ihr Speicherlimit erreicht.", 1)
SafeAddString(NOTYOU_LUADIALOG_TEXT,			"Möchten Sie das Speicherlimit ihrer Lua von |cFFFFFF<<1>>|r auf |cFFFFFF<<2>>|r MB erhöhen? (UI wird neu geladen!)", 1)

SafeAddString(NOTYOU_AVA_HEADER,			"AvA-Nachrichten", 1)
SafeAddString(NOTYOU_AVA,				"Optionen:", 1)
SafeAddString(NOTYOU_AVA_TOOLTIP,			"Wählen Sie aus, wie sie AvA-Nachrichten behandeln möchten, wenn Sie sich nicht in der AvA-Welt aufhalten:\n|cFFFFFFkeine|r – Standardspieleinstellung\n|cFFFFFFChatnachricht|r – Nachrichten werden ins Chatfenster umgeleitet.\n|cFFFFFFstumm|r – Nachrichten werden vollständig blockiert.", 1)

SafeAddString(NOTYOU_GROUPZONE_HEADER,			"Benachrichtigungen für Gruppenbereiche", 1)
SafeAddString(NOTYOU_GROUPZONE,				"Optionen:", 1)
SafeAddString(NOTYOU_GROUPZONE_TOOLTIP,			"Auswahl für Benachrichtigungen für Gruppenbereiche treffen: \n|cFFFFFFkeine|r - Standardspieleinstellung\n|cFFFFFFChatnachricht|r - Nachrichten werden ins Chatfenster umgeleitet\n|cFFFFFFstumm|r - Nachrichten werden vollständig blockiert", 1)

SafeAddString(NOTYOU_FRIENDS_HEADER,			"Statusmeldungen bei Freunden", 1)
SafeAddString(NOTYOU_FRIENDS_ACTIVITY,			"Blockiert die Statusmeldungen bei Freunden", 1)
SafeAddString(NOTYOU_FRIENDS_ACTIVITY_TOOLTIP,		"Blockiert Statusmeldungen bei Freunden, wenn sie sich ein- oder ausloggen:\n- |cFFFFFF[@username] hat sich mit [character] eingeloggt.|r\n- |cFFFFFF[@username] hat sich mit [character] ausgeloggt|r", 1)

SafeAddString(NOTYOU_TEXT_ALERTS_HEADER,		"Textmeldungen", 1)
SafeAddString(NOTYOU_MOB_IMMUNE,			"Blockiert \"Das Ziel ist immun.\"-Meldungen", 1)
SafeAddString(NOTYOU_MOB_IMMUNE_TOOLTIP,		"Blockiert während Bosskämpfen häufig auftretende Textmeldungen:\n- |cFFFFFF".. GetErrorString(162) .."|r\n- |cFFFFFF".. GetErrorString(177) .."|r\n- |cFFFFFF" .. GetString("SI_ACTIONRESULT", ACTION_RESULT_MISSING_EMPTY_SOUL_GEM) .. "|r\n- |cFFFFFF" .. GetString("SI_ACTIONRESULT", ACTION_RESULT_IMMUNE) .. "|r", 1)
SafeAddString(NOTYOU_SCREENSHOT,			"Blockiert \"Screenshot gespeichert\"-Meldungen", 1)
SafeAddString(NOTYOU_SCREENSHOT_TOOLTIP,		"Blockiert die Meldung, dass ein Screenshot gespeichert wurde:\n- |cFFFFFFScreenshot gespeichert unter: <path>|r", 1)
SafeAddString(NOTYOU_ENLIGHTENED,			"Blockiert \"erfrischt\"-Meldungen", 1)
SafeAddString(NOTYOU_ENLIGHTENED_TOOLTIP,		"Blockiert die Meldungen, wenn ein Spieler erfrischt ist:\n- |cFFFFFFIhr seid nun erfrischt.|r", 1)
SafeAddString(NOTYOU_CRAFTRESULT,			"Blockiert Ergebnismeldungen an Handwerksstationen:", 1)
SafeAddString(NOTYOU_CRAFTRESULT_TOOLTIP,		"Blockiert Ergebnismeldungen an Handwerksstationen:\n- |cFFFFFF" .. GetString(SI_TRADESKILLRESULT119) .. "|r\n- |cFFFFFF" .. GetString(SI_SMITHING_EXTRACTION_FAILED) .."|r\n- |cFFFFFF" .. GetString(SI_SMITHING_DECONSTRUCTION_LEVEL_PENALTY) .. "|r\n- |cFFFFFF" .. GetString(SI_ALCHEMY_NO_YIELD) .. "|r\n- |cFFFFFF" .. GetString(SI_ENCHANT_NO_YIELD) .. "|r", 1)
SafeAddString(NOTYOU_REPAIR,				"Blockiert die Reperaturmeldung", 1)
SafeAddString(NOTYOU_REPAIR_TOOLTIP,			"Blockiert die Reperaturmeldung:\n- |cFFFFFF<item> repariert.|r", 1)
SafeAddString(NOTYOU_ALERT_THROTTLING,			"Alarmverzögerung", 1)
SafeAddString(NOTYOU_ALERT_THROTTLING_TOOLTIP,		"Gleichlautende Meldungen werden nur im eingestellten Takt wiederholt.", 1)

SafeAddString(NOTYOU_SOUND_HEADER,			"Akustische Signale", 1)
SafeAddString(NOTYOU_ULTISOUND,				"Signal \“Ultimative Fähigkeit aufgeladen\" stumm:", 1)
SafeAddString(NOTYOU_ULTISOUND_TOOLTIP,			"Auswählen, wenn das akustische Signal \“Ultimative Fähigkeit aufgeladen\" stumm geschaltet werden soll.", 1)

SafeAddString(NOTYOU_MARKET_HEADER,			"Kronen-Shop-Einblendung", 1)
SafeAddString(NOTYOU_MARKET_ADS,			"Blockiert die Kronen-Shop-Einblendung", 1)
SafeAddString(NOTYOU_MARKET_ADS_TOOLTIP,		"Blockiert die Kronen-Shop-Einblendung nach dem Einloggen.", 1)

SafeAddString(NOTYOU_MAIL_HEADER,			"\"Lösche Nachricht\"-Dialog unterdrücken:", 1)
SafeAddString(NOTYOU_MAIL,				"\"Lösche Nachricht\"-Dialog unterdrücken:", 1)
SafeAddString(NOTYOU_MAIL_TOOLTIP,			"Blockiert den Dialog zur Bestätigung, wenn eine leere Nachricht gelöscht werden soll.", 1)

SafeAddString(NOTYOU_FENCE_HEADER,			"Hehler-Dialog", 1)
SafeAddString(NOTYOU_FENCE,				"Hehler-Dialog unterdrücken:", 1)
SafeAddString(NOTYOU_FENCE_TOOLTIP,			"Blockiert den Dialog zur Bestätigung, wenn ein seltener Gegenstand an einen Hehler verkauft werden soll.", 1)

SafeAddString(NOTYOU_GROUPS_HEADER,			"Gruppendialoge", 1)
SafeAddString(NOTYOU_GROUPS_DISBAND,			"\"Gruppe verlassen\"-Dialog unterdrücken:", 1)
SafeAddString(NOTYOU_GROUPS_DISBAND_TOOLTIP,		"Blockiert den Dialog zur Bestätigung, wenn eine Gruppe verlassen wird.", 1)
SafeAddString(NOTYOU_GROUPS_LARGE,			"Großgruppen-Dialog und Meldungen unterdrücken", 1)
SafeAddString(NOTYOU_GROUPS_LARGE_TOOLTIP,		"Unterdrückt den Bestätigungsdialog und die Meldungen, wenn die Gruppe " .."zu einer Großgruppe wird oder keine Großgruppe mehr ist.", 1)

SafeAddString(NOTYOU_CRAFT_HEADER,			"Dialoge an Handwerksstationen", 1)
SafeAddString(NOTYOU_CRAFT,				"\"Gegenstand aufwerten\"-Dialog unterdrücken:", 1)
SafeAddString(NOTYOU_CRAFT_TOOLTIP,			"Blockiert den Dialog zur Bestätigung, wenn ein Gegenstand aufgewertet werden soll.", 1)

SafeAddString(NOTYOU_CHAMELEON_HEADER,			"Kronen-Mimenstein", 1)
SafeAddString(NOTYOU_CHAMELEON,				"Verstecke die Kronen-Mimenstein Checkbox", 1) -- Scootworks
SafeAddString(NOTYOU_CHAMELEON_TOOLTIP,			"Verstecke die Kronen-Mimenstein Checkbox wenn du keine Steine besitzt", 1) -- Scootworks

SafeAddString(NOTYOU_CHAT_HEADER,			"Freunde-Symbol", 1)
SafeAddString(NOTYOU_CHAT,				"Freunde-Symbol ausblenden:", 1)
SafeAddString(NOTYOU_CHAT_TOOLTIP,			"Blendet das Freunde-Symbol oberhalb des Chatfensters aus.", 1)

SafeAddString(NOTYOU_RETICLE_HEADER,			"Sammeln", 1)
SafeAddString(NOTYOU_RETICLE_TAKE,			"Sammeln verkürzen:", 1)
SafeAddString(NOTYOU_RETICLE_TAKE_TOOLTIP,		"Überspringt die \"Nehmen\"-Interaktion für gesammelte Insekten.", 1) -- Scootworks
SafeAddString(NOTYOU_EMPTY_INTERACT,			"Bei leeren Behältern die Interaktion unterbinden", 1)
SafeAddString(NOTYOU_EMPTY_INTERACT_TOOLTIP,		"Zeigt den Text für Interaktionen nicht an, wenn der Behälter leer ist.", 1)

SafeAddString(NOTYOU_NOREPORTONITEMS,			"Für Gegenstände \"Hilfe erhalten\" nicht anzeigen", 1)
SafeAddString(NOTYOU_NOREPORTONITEMS_TOOLTIP,		"Für Gegenstände \"Hilfe erhalten\" nicht anzeigen. Wird verwendet um ZOS Gegenstände zu melden.", 1)

SafeAddString(NOTYOU_NOBINDALERT,			"Keine Warnung vor dem Binden eines Gegenstandes",1)
SafeAddString(NOTYOU_NOBINDALERT_TOOLTIP,		"Deaktiviert den Bestätigungsdialog wenn ein Gegenstand angelegt werden soll, der beim Anlegen an den Account gebunden wird",1)

SafeAddString(NOTYOU_NOPORTONLEADER,			"Deaktiviere den \"Reise zum Gruppenanführer\" Dialog",1)
SafeAddString(NOTYOU_NOPORTONLEADER_TOOLTIP,		"Deaktiviert den Dialog, welcher bei einem Gruppenbeitritt das Reisen zur Gruppenanführer Position voreschlägt",1)

SafeAddString(NOTY_NOPORTONLEADER_0,			"Nie",1)
SafeAddString(NOTY_NOPORTONLEADER_1,			"Wenn Ziel nicht erreichbar ist",1)
SafeAddString(NOTY_NOPORTONLEADER_2,			"Immer", 1)

SafeAddString(NOTYOU_TAMRIEL,				"Symbole auf der Tamriel-Karte mithilfe von Filtern ein- bzw. ausblenden",1)
SafeAddString(NOTYOU_TAMRIEL_BUTTON,			"Filter für die Tamriel-Karte",1)
SafeAddString(NOTYOU_TAMRIEL_TOOLTIP,			"Filter für die Tamriel-Karte",1)

SafeAddString(NOTYOU_NOUNOWNEDHOUSES,			"Nicht gekaufte Häuser ausblenden", 1)
SafeAddString(NOTYOU_NOUNOWNEDHOUSES_TOOLTIP,		"Häuser, die man nicht besitzt, ausblenden. Nur Häuser, die man besitzt werden angezeigt.", 1)

SafeAddString(NOTYOU_NOSHRINESTAMRIEL,			"Wegschreine auf der Tamrielkarte nicht anzeigen", 1)
SafeAddString(NOTYOU_NOSHRINESTAMRIEL_TOOLTIP,		"Wegschreine auf der Karte von Tamriel nicht anzeigen. Diese werden nur auf den Karten der Gebiete angezeigt.", 1)

SafeAddString(NOTYOU_ONLY_CAPITAL_PINS,			"Nur Wegschreine in Hauptstädten auf der Weltkarte anzeigen", 1)
SafeAddString(NOTYOU_ONLY_CAPITAL_PINS_TOOLTIP,		"Auf der Weltkarte werden nur Wegschreine in Hauptsta..dten angezeigt. Alle anderen sind bis auf die Zonenansicht verborgen.", 1)

SafeAddString(NOTYOU_NOWRITQUESTS,			"Versiegelte Schriebe nicht automatisch öffnen", 1)
SafeAddString(NOTYOU_NOWRITQUESTS_TOOLTIP,		"Zeige Handwerksschriebe nicht automatisch an, sobald ein Meisterschrieb gelootet wurde.", 1)

SafeAddString(NOTYOU_GUILDS_HEADER,			"Gildeneinladungen", 1)
SafeAddString(NOTYOU_GUILDS,				"Grad der Blockierung festlegen:", 1)
SafeAddString(NOTYOU_GUILDS_TOOLTIP,			"Blockiert Gildeneinladungen.", 1)
SafeAddString(NOTYOU_GUILDSAPP,				"Gildenbewerbungsbenachrichtigungen ausblenden", 1)
SafeAddString(NOTYOU_GUILDSAPP_TOOLTIP,			"Blenden Sie die Gildenanwendungsbenachrichtigungen aus.", 1)

SafeAddString(NOTYOU_GROSTER_HEADER,			"Nachrichten über Gildenmitglieder", 1)
SafeAddString(NOTYOU_GROSTER_HEADER_TOOLTIP,		"Wie sollen Nachrichten über Gildenmitglieder behandelt werden?", 1)
SafeAddString(NOTYOU_GROSTER,				"Optionen:", 1)
SafeAddString(NOTYOU_GROSTER_TOOLTIP,			"Wählt aus, wie Nachrichten über Gildenmitglieder behandelt werden sollen:\n|cFFFFFFkeine|r - Standardspieleinstellung\n|cFFFFFFChatnachricht|r - Nachrichten werden ins Chatfenster umgeleitet.\n|cFFFFFFstumm|r – Nachrichten werden vollständig blockiert.", 1)

SafeAddString(NOTYOU_RAIDSCORE_HEADER,			"Raid Score-Mitteilungen", 1)
SafeAddString(NOTYOU_RAIDSCORE_HEADER_TOOLTIP,		"Wie sollen Raid Score-Mitteilungen behandelt werden?", 1)
SafeAddString(NOTYOU_RAIDSCORE_ONLYFOR,			"Nur anzeige für:", 1) -- Scootworks
SafeAddString(NOTYOU_RAIDSCORE_ONLYFOR_TOOLTIP,		"Wählt aus, wie Raid Score-Mitteilungen behandelt werden sollen:\n|cFFFFFFimmer|r - Standardspieleinstellung\n|cFFFFFFniemals|r - blockiert alle Raid Score-Mitteilungen", 1)
SafeAddString(NOTYOU_RAIDSCORE_REDIRECT,		"Mitteilungen ins Chatfenster umleiten.", 1)

SafeAddString(NOTYOU_MOTD_HEADER,			"Benachrichtigungen (N)", 1)
SafeAddString(NOTYOU_MOTD_HEADER_TOOLTIP,		"Wie sollen die Benachrichtigungen (N) behandelt werden, die über das Sprechblasensymbol oberhalb des Chatfensters abrufbar sind (Taste N):", 1)
SafeAddString(NOTYOU_MOTD_BLOCK,			"Optionen:", 1)
SafeAddString(NOTYOU_MOTD_BLOCK_TOOLTIP,		"Wie sollen die Benachrichtigungen (N) behandelt werden, die über das Sprechblasensymbol oberhalb des Chatfensters abrufbar sind (Taste N):\n|cFFFFFFkeine Änderung|r - Standardspieleinstellung\n|cFFFFFFChatnachricht|r - Mitteilungen ins Chatfenster umleiten.\n|cFFFFFFstumm|r – Mitteilungen werden vollständig blockiert.", 1)

SafeAddString(NOTYOU_GUILDLEAVE_HEADER,			"Gilde verlassen deaktivieren", 1)
SafeAddString(NOTYOU_GUILDLEAVE_HEADER_TOOLTIP,		"Wählt wie das Gilde verlassen Tastenkürzel im Gildenmenü behandelt werden soll", 1)
SafeAddString(NOTYOU_GUILDLEAVE_BLOCK,			"Deaktivieren für:", 1)
SafeAddString(NOTYOU_GUILDLEAVE_BLOCK_TOOLTIP,		"Wählt wie das Gilde verlassen Tastenkürzel behandelt werden soll:\n|cFFFFFFNicht deaktivieren|r - Standardspieleinstellung\n|cFFFFFFAlle Gilden|r - Deaktivieren für alle Gilden\n|cFFFFFFPer Gilde|r - Wählt für welche Gilden das Tastenkürzel deaktiviert ist", 1)

SafeAddString(NOTYOU_CAMERA_HEADER,			"Kamera & Interaktion", 1)
SafeAddString(NOTYOU_CAMERA_INTERRUPT,			"Interaktionen nicht unterbrechen:", 1)
SafeAddString(NOTYOU_CAMERA_INTERRUPT_TOOLTIP,		"Interaktionen (z.B. ernten, fischen) werden nicht unterbrochen, wenn Fenster (z.B. Karte, Inventar) geöffnet werden.", 1)
SafeAddString(NOTYOU_CAMERA_ROTATE,			"Kamerarotation", 1)
SafeAddString(NOTYOU_CAMERA_ROTATE_TOOLTIP,		"Die Kamera bleibt unverändert und rotiert nicht mehr, wenn Fenster (z.B. Karte, Inventar) geöffnet werden.", 1)
SafeAddString(NOTYOU_CAMERA_ROTATE_STATS,		"Don't rotate game camera while showing status", 1)
SafeAddString(NOTYOU_CAMERA_ROTATE_STATS_TOOLTIP,	"Don't rotate game camera while showing status. If you turn this ON, you can't change outfit on status window by ESO feature.", 1)
SafeAddString(NOTYOU_CAMERA_ROTATE_INV,			"Don't rotate game camera while showing inventory", 1)
SafeAddString(NOTYOU_CAMERA_ROTATE_INV_TOOLTIP,		"Don't rotate game camera while showing inventory. If you turn this ON, you can't preview any item by ESO feature.", 1)

SafeAddString(NOTYOU_AUTOLOOTITEMS_HEADER,		"Behälter automatisch aufsammeln", 1)
SafeAddString(NOTYOU_AUTOLOOTITEMS,			"Behälter automatisch aufsammeln", 1)
SafeAddString(NOTYOU_AUTOLOOTITEMS_TOOLTIP,		"Behälter automatisch aufsammeln wenn automatisches Aufsammeln aktiv ist. Gestohlene Gegenstände von Behältern werden automatisch aufgesammelt wenn die entsprechende Option aktiv ist.", 1)

SafeAddString(NOTYOU_NOLOREREADER,			"Entdeckte Bücher nicht lesen", 1)
SafeAddString(NOTYOU_NOLOREREADER_TOOLTIP,		"Zeigt dir die bereits entdeckten Bücher nicht an, ausgeschlossen davon sind die Bücher in der Bibliothek.", 1)

SafeAddString(NOTYOU_NOLOREDISCOVERIES,			"Benachrichtigung entdeckter Bücher deaktivieren", 1)
SafeAddString(NOTYOU_NOLOREDISCOVERIES_TOOLTIP,		"Wählt aus, wie Nachrichten über entdeckte Bücher behandelt werden sollen:\n|cFFFFFFkeine|r - Standardspieleinstellung\n|cFFFFFFChatnachricht|r - Nachrichten werden ins Chatfenster umgeleitet.\n|cFFFFFFstumm|r - Nachrichten werden vollständig blockiert.", 1)

SafeAddString(NOTYOU_NOSKILLSPROGRESS,			"Benachrichtigung Fertigkeitenaufstieg deaktivieren", 1)
SafeAddString(NOTYOU_NOSKILLSPROGRESS_TOOLTIP,		"Wählt aus, wie Nachrichten über Fertigkeitenlevel behandelt werden sollen:\n|cFFFFFFkeine|r - Standardspieleinstellung\n|cFFFFFFChatnachricht|r - Nachrichten werden ins Chatfenster umgeleitet.\n|cFFFFFFstumm|r - Nachrichten werden vollständig blockiert.", 1)

SafeAddString(NOTYOU_NOCRAFTBAG_NOTIF,			"Benachrichtigung Handwerksbeutel deaktivieren", 1)
SafeAddString(NOTYOU_NOCRAFTBAG_NOTIF_TOOLTIP,		"Keine Benachrichtigung anzeigen, wenn meine Materialien beim Einloggen oder Zonenwechsel in den Handwerksbeutel verschoben werden", 1)

SafeAddString(NOTYOU_NOCHATAUTOCOMPLETE,		"Deaktiviere Chat Auto-Vervollständigung",1)
SafeAddString(NOTYOU_NOCHATAUTOCOMPLETE_TOOLTIP,	"Deaktiviere die Auto-Vervollständigung im Chat für z.B. Emotes und Kanäle",1)

SafeAddString(NOTYOU_NOCHATDISABLE,			"Deaktiviere Chat Minimierung im Handelshaus",1)
SafeAddString(NOTYOU_NOCHATDISABLE_TOOLTIP,		"Deaktiviert das automatische Minimieren des Chats wenn das Handelshaus geöffnet wird",1)

SafeAddString(NOTY_GUILDLEAVE_OPTION_0,			"Keine Deaktivierung",1)
SafeAddString(NOTY_GUILDLEAVE_OPTION_1,			"Alle Gilden",1)
SafeAddString(NOTY_GUILDLEAVE_OPTION_2,			"Per Gilde",1)


SafeAddString(NOTYOU_LUA_HEADER,			"Lua Speicherfehler", 1)
SafeAddString(NOTYOU_LUA_MEMORY,			"Lua Speicherfehler umleiten", 1)
SafeAddString(NOTYOU_LUA_MEMORY_TOOLTIP,		"Lua Speicherfehler in eine Chat-Mitteilung umwandeln, statt das Pop-up (Standard) anzuzeigen", 1)
SafeAddString(NOTYOU_LUA_ERROR,				"Lua Fehler umleiten", 1)
SafeAddString(NOTYOU_LUA_ERROR_TOOLTIP,			"Lua Fehler in eine Chat-Mitteilung umwandeln, statt das Pop-up (Standard) anzuzeigen", 1)
