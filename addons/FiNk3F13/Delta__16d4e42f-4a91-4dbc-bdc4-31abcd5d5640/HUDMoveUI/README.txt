HUD Move UI 1.0.0-test
======================
Eigenstaendiges ESO-HUD-Addon fuer den Konsolentest.
Ein Addon-Ordner, keine eingebettete LibAPH und keine Messfunktionen.
Benoetigt: LibHarvensAddonSettings, getrennt auf der Konsole installiert.

BEDIENUNG
Einstellungen > Addons > HUD Move UI.
Jedes Element hat einen eigenen aufklappbaren Abschnitt:
- Status: verfuegbar, verborgen oder auf diesem Client noch nicht vorhanden.
- Anpassen: gespeicherte Position und Groesse fuer dieses Element aktivieren.
- Move UI: wechselt aus dem Einstellungsmenue ins Spielbild.
- Groesse: 50 bis 200 Prozent der urspruenglichen Elementgroesse.
- Zuruecksetzen: Originalposition und Originalgroesse wiederherstellen.

Move UI aktiviert die Anpassung fuer das gewaehlte Element automatisch.
Mit dem RECHTEN STICK verschieben. KREUZ speichert, KREIS bricht ab und
stellt den Stand vor dem Verschieben wieder her. Drei Sekunden Stillstand
speichern automatisch. Danach werden Tasten und Kamera freigegeben.
Im Kampf laesst sich der Modus nicht starten. Beginnt waehrenddessen ein
Kampf, wird der Verschiebevorgang abgebrochen.
Waehle das Einstellungsmenue danach erneut, um ein weiteres Element zu bewegen.

BEISPIEL
01 Ressourcen / Lebensleiste oeffnen, Move UI waehlen, mit dem rechten Stick
bewegen und drei Sekunden warten. Dann im Menue Groesse auf 150 Prozent setzen.

UNTERSTUETZTE ZIELE DIESER TESTFASSUNG
01 Ressourcen: Leben, Magicka und Ausdauer einzeln; Reittier, Werwolf und Belagerung.
02 Kampf: Skillleiste einschliesslich Ultimate/Schnellzugriff, Synergie-Hinweis,
          Ziel-Lebensleiste, Boss-Lebensleiste, Kampfhinweise.
03 Effekte: eigene Buffs/Debuffs und Ziel-Buffs/Debuffs.
04 Orientierung: Kompass, Interaktionshinweis, Erfahrungs-/Champion-Fortschritt.
05 Gruppe und Aufgaben: Questanzeige und kleine Gruppenanzeige.
06 Eigene Addons: Obsidian HUD Ressourcenblock, wenn ObsidianHUD.root existiert.

Es handelt sich um eine explizite Liste unterstuetzter Steuerelemente, nicht
um einen beliebigen Editor aller Menues oder aller Drittanbieter-Addon-Fenster.
Die Skillleiste wird als Einheit bewegt und skaliert. Raid-Spalten, weitere
Aufgabenfenster sowie einzelne Skill-Slots sind in dieser Fassung nicht enthalten.
Einige native Elemente sind je nach Client/Spielzustand nicht vorhanden.

VERSTECKTE ELEMENTE
Das Addon blendet keine Synergie, Buffs oder andere Spielinformationen kuenstlich
ein. Ist der native Container vorhanden, aber gerade verborgen, erscheint im
Verschiebemodus nur ein beschrifteter Positionsrahmen. Die gespeicherte Position
wird verwendet, wenn ESO das Element tatsaechlich zeigt.

PROFILE UND ZURUECKSETZEN
Positionen und Groessen werden accountweit gespeichert. Controller und Tastatur
haben getrennte Layouts. Anfangs sind alle einzelnen Anpassungen ausgeschaltet.
Der Hauptschalter gibt die vom Addon gesteuerten Positionen wieder frei.
Einzelne Elemente lassen sich direkt zuruecksetzen. Alles zuruecksetzen fragt
vorher nach und loescht die gespeicherten Positionen fuer beide Bedienmodi.

KONFLIKTE
Nur ein Addon soll ein bestimmtes Steuerelement verschieben oder skalieren.
Obsidian HUD oder ein anderer HUD-Mover kann eigene Regeln fuer dieselben
Elemente haben. Diese dort deaktivieren oder das Element hier ausgeschaltet lassen.
Ausgeblendete native Ressourcenleisten eines anderen HUD-Addons werden nicht
wieder eingeblendet; nutze in diesem Fall dessen eigenes HUD oder den optionalen
Obsidian-Ressourcenblock.

TESTSTATUS
Lua-Syntax, Standardeinstellungen ohne Eingriff, skalierte Ankerumrechnung,
Stickbewegung, Speichern, Abbrechen, Original-Wiederherstellung, Kampf-Abbruch,
verborgene Synergie-Container, Layoutwechsel und Freigabe der Tasten/Kamera
wurden mit simulierten ESO-Funktionen geprueft.
Die echten nativen HUD-Layouts und Controller-Steuerung muessen noch im
ESO-Client beziehungsweise auf echter Konsole geprueft werden.

UPLOAD
Nur den Ordner HUDMoveUI auswaehlen. LibHarvensAddonSettings muss als Abhaengigkeit
auf der Konsole verfuegbar/aktiviert sein. Es wurde kein Upload vorgenommen.
Die Fassung zielt auf ESO API 101051 und 101052.
