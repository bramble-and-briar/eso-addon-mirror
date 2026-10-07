# Live Uptime Buff

Eigenstaendiges ESO-Addon fuer frei platzierbare Effekt-Tracker.
Restzeit im Icon, Live-Uptime direkt rechts daneben.

## Einrichtung

1. Addon aktivieren und `/reloadui` ausfuehren.
2. Unter Einstellungen > Addons das Panel **Live Uptime Buff** oeffnen.
3. Effekt-ID eingeben, **Auf mir**, **Auf dem Gegner** oder **Auf der Gruppe** waehlen und **Hinzufuegen** anklicken.
4. Am jeweiligen Tracker **Move UI > Icon verschieben** anklicken.
5. Den ausgewaehlten Tracker mit der Maus ziehen oder mit dem rechten Stick verschieben.
6. Nach 3 Sekunden ohne Bewegung wird die Position automatisch gespeichert und gesperrt, wie in Weaving Metronome. Waehrend des Ziehens bleibt der Modus aktiv. Groesse und X/Y lassen sich auch im Panel einstellen.

Die benoetigte Bibliothek `LibHarvensAddonSettings` ist bereits im benachbarten Addon-Ordner vorhanden.
Es werden anfangs keine Tracker vorgegeben.

## Messung

- Uptime = aktive Effektzeit / vergangene Kampfzeit, mit einer Nachkommastelle und mindestens einer Sekunde als Nenner, wie in SimpleWarhornTimer.
- Wenn LibCombat vorhanden ist, stammen die Kampfgrenzen und die Spieler-Effektintervalle aus LibCombat. Live beginnt die Messung mit der ersten Schadens-/Heilaktion; am Kampfende wird sie mit den Kampfgrenzen und der aktiven Dauer aus der LibCombat-Zusammenfassung neu berechnet, wie in SimpleWarhornTimer.
- Ohne LibCombat bleibt die Messung ueber ESO-Kampfstatus und sichtbare Effekte verfuegbar.
- Jeder neue Kampf setzt die Messung zurueck. Nach Kampfende bleibt der letzte Prozentwert stehen.
- Bereits vor Kampfbeginn aktive Effekte werden ab Kampfbeginn gezaehlt.
- Gleichzeitige Anwendungen derselben ID werden zusammengefasst und nicht doppelt gezaehlt.
- Ziel-Tracker messen nur den aktuell anvisierten lebenden Gegner. Ohne Gegner zaehlt die Zeit als inaktiv.
- Gruppen-Tracker messen aktive Effektsekunden aller lebenden, verbundenen Mitglieder in derselben Zone, geteilt durch deren gesamte auswertbare Mitgliedszeit. Tote, Offline-Mitglieder und Mitglieder in anderen Zonen werden waehrend dieser Zeit ausgeschlossen.
- Die Gruppenmessung laeuft weiter, solange das Addon oder ein Gruppenmitglied noch im Kampf ist, auch wenn du tot bist. Wiederbelebung setzt den laufenden Gruppenwert nicht zurueck.
- Das Gruppen-Icon zeigt die kuerzeste aktive Restzeit auf einem lebenden Mitglied. Der Tooltip zeigt die aktuelle Abdeckung, zum Beispiel 4/12. Ohne Gruppe wird der Spieler als einzelne Person gemessen.
- Die Gruppenmessung nutzt sichtbare Buff-Listen und ESO-Effektmeldungen. Sie ist ein Gruppendurchschnitt und entspricht nicht CMX' persoenlicher Uptime.
- Beim Zielwechsel gilt sofort der Zustand des neuen Ziels. Effekte auf nicht anvisierten Gegnern werden nicht weitergemessen.
- Effekte aller Quellen zaehlen, auch solche anderer Spieler.
- Die Effekt-ID kann von der ID der Fertigkeit abweichen. Die Alias-IDs aus SimpleWarhornTimer sowie Effekte mit gleichem normalisierten Namen werden zusammengefasst.
- `--` bedeutet inaktiv, `*` bedeutet aktiv ohne bekannte Ablaufzeit.
- Aktualisierung alle 100 ms und bei Effekt-/Zielereignissen. Die Messung folgt den durch ESO sichtbaren Effekten.
- Neu hinzugefuegte Tracker oder eine geaenderte Einheit starten ihre Messung zum Zeitpunkt der Aenderung.

## Befehle

- `/lub move`: Positionen entsperren/sperren.
- `/lub reset`: aktuelle Uptime-Messung zuruecksetzen.

## Entwicklung

`tests/uptime.lua` prueft die Zeitberechnung. `tests/addon.lua` prueft das Addon mit nachgebildeten ESO-APIs.
`tests/libcombat.lua` prueft die LibCombat-Messung, Alias-IDs und Kampfzusammenfassung.
Beide Tests aus diesem Ordner mit einem Lua-Interpreter starten.
`tests/group.lua` und `tests/group-addon.lua` pruefen Gruppen-Uptime, Tod, Wiederbelebung und weiterlaufendes Tracking.
Darstellung und echte Effektmeldungen muessen zusaetzlich im Spiel geprueft werden.
