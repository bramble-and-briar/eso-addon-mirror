# Add Kill Counter · 1.3.4

ESO-PvE-Killzähler für die Controller-Oberfläche. Benötigt LibHarvensAddonSettings. Manifest: AddKillCounter.addon; API-Ziel: 101051.

## Gebiet auswählen

Es gibt kein fest eingebautes Zielgebiet mehr. Gehe in das gewünschte Gebiet und wähle unter Einstellungen → Addons → Add Kill Counter → Erfassung den Knopf „Aktuelles Gebiet aktivieren“. Das aktuelle Gebiet wird gespeichert. Dort zählt das Add-on und zeigt den Zähler an; außerhalb wird pausiert und ausgeblendet. Beim Zurückkehren geht es automatisch weiter. Mit demselben Knopf kannst du später ein anderes Gebiet wählen. Es ist immer nur ein Gebiet aktiv. „Gebiet deaktivieren“ hebt die Auswahl auf. Ohne Auswahl wird nicht gezählt.

Die Auswahl bleibt bei UI-Neuladen und Login erhalten. Bestehende Gesamt- und Tageszahlen bleiben unverändert und laufen über spätere Gebietswechsel weiter. Es werden keine einzelnen Kills oder Gegnernamen gespeichert. Die Verschiebe-Vorschau lässt sich weiterhin unabhängig vom ausgewählten Gebiet öffnen.

## Tage löschen und Zählung

Unter Statistik → Alle Tage ein Datum markieren und R3 (rechten Stick drücken) verwenden. Die Aktion „Löschen“ erscheint in ESOs normaler Tastenleiste und nutzt UI_SHORTCUT_RIGHT_STICK. Sie ist auch in der Tagesübersicht verfügbar; Seitenwechsel und leere Zeilen lassen sich damit nicht löschen. Die Löschung wird in ESOs nativem Controller-Bestätigungsdialog bestätigt. Er verwendet die normalen Dialogaktionen für Löschen und Abbrechen. Es gibt keine zusätzliche Löschseite. Auch das Löschen der gesamten Statistik verwendet diesen Dialog. Die Gesamtzahl bleibt erhalten. Wird der heutige Tag gelöscht, beginnt Heute bei 0; der nächste Kill erhöht Heute auf 1 und zählt zur bestehenden Gesamtzahl hinzu.

Es gibt kein eingebautes Kill- oder Tageslimit. Die Seitenlänge der Liste begrenzt nur die Anzeige pro Seite, nicht die gespeicherten Tage oder die gezählten Kills.

## Anzeige und Menüs

- HUD: Heute und Gesamtzahl. Ohne Rahmen und ohne Sitzungsanzeige. Die Breite passt sich dem Text an.
- Einstellungen unter Einstellungen → Addons → Add Kill Counter.
- Statistik: Heute, Gesamtzahl und Anzahl getöteter Adds pro Tag.
- Keine separate Gegner-Aufschlüsselung und kein eigener Eintrag im Spielhauptmenü.
- Move UI: rechter Stick; automatisches Speichern nach 3 Sekunden ohne Bewegung. Zurück verwirft die Positionsänderung.
- Größe, Sichtbarkeit, Erfassung, Pets, Begleiter und Killbeteiligungen sind einstellbar.

## Zählung und Speicherung

Eigene NPC-Todesmeldungen über DIED, DIED_XP und DIED_COMPANION_XP werden anhand der Quelle verarbeitet. Pets und Begleiter zählen nur bei aktivierter Option. Killbeteiligungen erfordern einen zuvor beobachteten eigenen Treffer. Mehrere Todesmeldungen derselben Gegner-ID werden zusammengeführt. PvP-Zonen und Trainingspuppen werden ausgeschlossen.

Gespeichert werden nur Gesamt- und Tageszahlen sowie die Uhrzeit des ersten und letzten Kills pro Tag. Einzelkill-Protokolle und Gegnernamen werden nicht dauerhaft gespeichert. Alte Detaildaten werden beim Laden entfernt; Gesamt- und Tageszahlen bleiben erhalten. Das Add-on überträgt keine Daten ins Internet. Das Update löscht keine vorhandenen Statistiken. Datum und Uhrzeit stammen aus der lokalen ESO-Clientzeit.

Nach Änderungen an den Add-on-Dateien /reloadui ausführen. /akc öffnet die Statistik; /akcstatus zeigt Diagnoseinformationen im Chat.

## Installation und Prüfung

Im PTS liegt das Add-on unter dem Dokumente-Ordner in Elder Scrolls Online/pts/AddOns/AddKillCounter. Auf PS5 erfolgt die Installation nach Veröffentlichung im ESO-Add-on-Katalog; die ZIP ist nicht direkt auf der Konsole installierbar.

Lua-5.1-Syntax und simulierte ESO-Adapter-/Menüabläufe geprüft. Die Tests ersetzen keine Live-Prüfung auf PS5. Aus dem Add-on-Ordner lassen sich tests/CoreTests.lua, tests/SettingsTests.lua und tests/PvEEventsTests.lua mit einem Lua-Interpreter ausführen.

Offizieller Uploader: https://help.bethesda.net/app/answers/detail/a_id/69621/
UI-/API-Referenz: https://github.com/esoui/esoui/tree/live
