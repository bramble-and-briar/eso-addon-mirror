-- German localisation
-- luacheck: ignore 631
local L = function(k, v)
    ZO_CreateStringId("MARKTRIALHELPER_" .. k, v)
end

L("ADD_AVOID", 'Auf "Zu Vermeiden" hinzufügen')
L("ALL_BOTH", "Alle Verse und Visionen erworben")
L("ALL_VISIONS", "Alle Visionen erworben")
L("ALL_VERSES", "Alle Verse erworben")
L("ARC_BOSS", "Tho’at Replicanum folgt")
L("AUDITOR", "Loyalen Prüfer automatisch beschwören")
L("AUDITOR_NAME", "Loyaler Wirtschaftsprüfer")
L("AVOID", "Zu Vermeiden")
L("BONUS", "Bonuslevel")
L("BUFF_SELECTED", "<<1>> hat <<2>> ausgewählt")
L("COUNT", "<<1>> von <<2>>")
L("CROSSING_END", "Ende")
L("CROSSING_FAIL", "gesperrt") -- Die Hebel sind gesperrt. Keiner kommt weiter
L("CROSSING_INVALID", 'Hilfe kann nur in "Tückischer Übergang" im Endlosen Archiv aktiviert werden')
L("CROSSING_KEY", "<<1>> Biegen Sie links ab - <<2>> Biegen Sie rechts ab")
L("CROSSING_NO_SOLUTIONS", "Keine Pfade gefunden")
L("CROSSING_PATHS", "Mögliche Wege")
L("CROSSING_SLASH", "helfer")
L("CROSSING_START", "Anfang")
L("CROSSING_SUCCESS", "gelöst") -- Ihr habt des Rätsel der Gänge gelöst
L("CROSSING_TITLE", "Tückischer Übergang Helfer")

L(
    "CROSSING_INSTRUCTIONS",
    "Suchen Sie den Schalter, der dem Anfang des Pfades entspricht, und wählen Sie ihn in der Dropdown-Liste unten aus (1 ist der Schalter ganz links, 6 der ganz rechts)." ..
        " Suchen Sie dann ggf. den 2. Schritt oder das Ende des Weges, bis nur noch eine Lösung übrig bleibt."
)
L("CYCLE_BOSS", "Bosskampf folgt")
L("DEN_TIMER", "Noch <<1[0s übrig/1s übrig/$ds übrig]>>")
L("FABLED", "umwobene")
L("FABLED_MARKER", "Zielmarkierungen zu Sagenumwobenen hinzufügen")
L(
    "FABLED_TOOLTIP",
    "Diese Funktion wird nicht zusammen mit Lykeions Fabled Marker Addon funktionieren, da sonst beide Addons die gleichen Dinge markieren würden."
)

L("FLAMESHAPER", "Flammenformer")
L("GW", "Gw Langfinger")
L("GW_MARKER", "Zielmarkierungen zu Gw Langfinger hinzufügen")
L("GW_PLAY", "Warnung bei ankommenden Gw abspielen")
L("HERD", "Hütet die Geisterlichter")
L("HERD_FAIL", "ausreichend") -- Ihr habt nicht ausreichend Geisterlichter gehütet
L("HERD_SUCCESS", "erfolgreich") -- Ihr habt die Geisterlichter erfolgreich zurückgebracht
L("MARAUDER_MARKER", "Zielmarkierungen zu Marodeuren hinzufügen")
L("MARAUDER_INCOMING_PLAY", "Warnung bei ankommenden Marodeuren abspielen")
L("OPTIONAL_LIBS_CHAT", "Mark Trial Helper funktioniert am besten, wenn LibChatMessage installiert ist.")
L("OPTIONAL_LIBS_SHARE", "Damit der Duo-Modus effektiv funktioniert, installieren Sie bitte LibDataShare.")
L("PREVENT", "Verhindern Sie eine versehentliche Buff-Auswahl")
L("PREVENT_TOOLTIP", "Deaktiviert die Aktionstaste kurzzeitig, wenn die Buff-Auswahl geöffnet wird")
L("PROGRESS", "<<1>> Kriterien fortgeschritten. <<2>> verbleiben.")
L("PROGRESS_ACHIEVEMENT", "Fortschritt der Errungenschaften")
L("PROGRESS_CHAT", "Im Chat anzeigen")
L("PROGRESS_SCREEN", "Auf dem Bildschirm ankündigen")
L("RANDOM", "<<1>> hat <<2>> bekommen")
L("REMINDER", "Erinnerung an ein Bosskampf anzeigen")
L("REMINDER_QUEST", "Erinnerung an ein Quest Gegenstand anzeigen")
L("REMINDER_QUEST_TEXT", "Questgegenstand nicht vergessen!")
L("REMINDER_TOOLTIP", "Bei der Auswahl von Versen eine Erinnerung anzeigen, wenn der nächste Abschnitt ein Boss ist.")
L("REMOVE_AVOID", 'Von "Zu Vermeiden" entfernen')
L("REQUIRES", "Benötigt LibChatMessage")
L("SECONDS", "s")
L("SHARD", "Tho'at-Scherbe")
L("SHARD_IGNORE", "Scherben außerhalb von Zyklus 5 ignorieren")
L("SHARD_MARKER", "Zielmarkierungen zu Tho'at Scherben hinzufügen")
L("SHOW_COUNT", "Verbleibende Buchsiedler im Erfasser-Flügel zählen")
L("SHOW_CROSSING_HELPER", "Tückischer Übergang Helfer anzeigen")

L(
    "SHOW_COUNT_TOOLTIP",
    "Damit der Duo-Modus korrekt funktioniert, muss auch der andere Spieler dieses Addon installiert haben. Außerdem müssen beide Spieler LibDataShare installiert haben."
)
L("SHOW_ECHO", "Verbleibende Zeit in der Hallende Höhle anzeigen")
L("SHOW_SELECTION", "Buff-Auswahl im Gruppenchat anzeigen")
L("SHOW_SELECTION_DISPLAY_NAME", "Anzeigenamen statt Charakternamen verwenden")
L("SHOW_TERRAIN_WARNING", "Warnungen für Geländeschäden anzeigen")
L("SHOW_THEATRE_WARNING", "Show warnings in the Theatre of War")
L("SLASH_MISSING", "fehlende")
L("STACKS", "Anzahl der Stapel")
L("TOMESHELL", "Buchsiedler")
L("TOMESHELL_COUNT", "<<1[0 verbleibend/1 verbleibend/$d verbleibend]>>")
L("USE_AUTO_AVOID", "Automatische Markierungen benutzen")
L(
    "USE_AUTO_AVOID_TOOLTIP",
    "Automatisch Verse oder Visionen markieren, die aufgrund nicht vorhandener Fähigkeiten nutzlos sind"
)
L("WARNING", "Warnung: Liste benötigt zum Aktualisieren ein Neuladen der Benutzeroberfläche")
L("WEREWOLF_BEHEMOTH", "Werwolfbehemoth")

-- keybinds
L("SI_BINDING_NAME_MARKTRIALHELPER_MARK_CURRENT_TARGET", "Aktuelles Ziel markieren")
L("SI_BINDING_NAME_MARKTRIALHELPER_TOGGLE_CROSSING_HELPER", "Tückischer Übergang Helfer öffnen/schließen")
L("SI_BINDING_NAME_MARKTRIALHELPER_UNMARK_CURRENT_TARGET", "Markierung des aktuellen Ziels aufheben")

-- Marauders
L("MARAUDER_GOTHMAU", "gothmau")
L("MARAUDER_HILKARAX", "hilkarax")
L("MARAUDER_ULMOR", "ulmor")
L("MARAUDER_BITTOG", "bittog")
L("MARAUDER_ZULFIMBUL", "zulfimbul")
-- Zones
L("MAP_TREACHEROUS_CROSSING", "Tückischer Übergang")
L("MAP_HAEFELS_BUTCHERY", "Haefals Schlachterei")
L("MAP_FILERS_WING", "Erfasser-Flügel")
L("MAP_ECHOING_DEN", "Hallende Höhle")
L("MAP_THEATRE_OF_WAR", "Kriegsspielplatz")
L("MAP_DESTOZUNOS_LIBRARY", "Destozunos Bibliothek")
