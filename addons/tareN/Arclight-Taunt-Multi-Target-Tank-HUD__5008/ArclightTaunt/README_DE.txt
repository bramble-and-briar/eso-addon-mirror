ARCLIGHT TAUNT 1.1.2
Modernes Multi-Target-Taunt-HUD für The Elder Scrolls Online
Author: tareN
Kontakt im Spiel: @uhtareN (PC/EU)

FUNKTIONEN
Kompakte Übersicht Eurer eigenen Taunts aus normalen und Scribing-Fähigkeiten,
einschließlich Eurer eigenen Pets. Flüssige Countdown-Balken, Zielhervorhebung,
Bosskennzeichnung und getrennte Früh-/Ablaufwarnungen machen Prioritäten sichtbar.
Gegner mit gleichen Namen bleiben getrennte Einträge. Kurze Zeilenübergänge
schließen Lücken; eine kleine Lichtkante markiert das Ende der Countdown-Füllung.
Animationen reduzieren unter Design & Lesbarkeit stoppt dekorative Bewegungen. Flüssige Countdowns und eingestellte Warnungen bleiben erhalten.
Liste & Anordnung bündelt Größe, Abstände und Position. Design & Lesbarkeit
ordnet Balken/Hintergrund, Schrift/Countdown und Zielfokus/Animationen.

INSTALLATION
Diese Pflichtbibliotheken separat installieren; sie sind nicht enthalten:
- LibAddonMenu-2.0 r43 oder neuer:
  https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html
- LibMediaProvider r39 oder neuer:
  https://www.esoui.com/downloads/info56-LibMediaProvider.html

Den Ordner ArclightTaunt hierhin entpacken:
Documents/Elder Scrolls Online/live/AddOns/
Die Manifestdatei muss unter AddOns/ArclightTaunt/ArclightTaunt.txt liegen.

UPDATE
Addonordner ersetzen, SavedVariables behalten. Persönliche Position, Größe,
Medien und weiterhin angebotene Sounds bleiben erhalten. Alte Zeilenhöhen in
Prozent werden einmalig in zusätzliche Höhe über dem lesbaren Minimum
umgerechnet. Neue Installationen starten mit 115 Prozent HUD-Größe,
Signatur-Balken und 72 Prozent Hintergrunddeckkraft.
Einstellungen gelten accountweit und gemeinsam für alle Megaserver. Kampfverläufe,
Charakterfortschritt und andere serverspezifische Daten werden nicht gespeichert.

EINSTELLUNGEN
ESC > Einstellungen > Erweiterungen > Arclight Taunt
- Schnellzugriff: Vorschau anzeigen/pausieren und Verschiebemodus.
- Liste & Anordnung: Sichtbarkeit, Größe, Breite, Zeilenhöhe, Abstand,
  eine/zwei Spalten, Spiegelung, Position und Bosse anheften.
  Aktive Taunts werden nach verbleibender Zeit sortiert.
- Design & Lesbarkeit: Schmal/Full-row, hoher Kontrast, dezente/deutliche Zielhervorhebung,
  Schriften, Balkentexturen und Warnschwellen.
- Bosse: Erkennung, Kennzeichnung, Warnzeit, Darstellung und Warntöne.
- Tracking & Tests: Spieler-Taunts und Willkommens-/Sprach-Schrifttests.

Die Vorschau beginnt mit versetzten Timern, fügt unregelmäßig Gegner hinzu
und erneuert Taunts. Pro Zyklus wechseln Dungeon-/Prüfungsnamen. Pause friert
Timer, Ankünfte und Zielfokus ein; danach geht es an derselben Stelle weiter.
Beim Beenden der Vorschau wird die Pause gelöscht. Die Listenvorschau selbst
erzeugt keine Bossbanner.

BOSSWARNUNGEN
Türkis warnt vor dem Ablauf eines erkannten Bosstaunts, standardmäßig
2,5 Sekunden vorher. Rot warnt nach Ablauf. Beide Banner können gleichzeitig
eigene betroffene Bosse zusammenfassen. Re-Taunt oder erkannter Tod entfernt
den jeweiligen Boss aus seiner Warnung. Angeheftete abgelaufene Bosse stehen
vor angehefteten aktiven Bossen.

Warnton bei Ablauf, Frühwarnung, beidem oder aus wählen. Frühwarnton ist
standardmäßig aus, mit Duell-Grenzwarnung vorausgewählt. Ablauf nutzt
Duellbeginn. Rote und unmittelbar anstehende Ablaufwarnungen haben Vorrang;
unterdrückte Frühtöne werden nicht später nachgeholt.

Warnablauf testen zeigt Frühwarnung, Ablauf und danach Türkis unter Rot.
Aktivierte Warnungen und Töne werden berücksichtigt; ohne Frühwarnung nur Rot.
Echte Warnungen haben Vorrang. Die Tauntliste lässt sich ausblenden, während
konfigurierte Bossbanner und Sounds weiterarbeiten. Vorschau/Verschiebemodus
können die ausgeblendete Liste zur Einrichtung weiterhin anzeigen.

SPRACHEN
Deutsch, Englisch, Französisch, Spanisch und Russisch werden passend zur
ESO-Spielsprache gewählt. Andere Sprachen nutzen Englisch. Gespeicherte
Positionen und Medien bleiben beim Sprachwechsel erhalten.

GUT ZU WISSEN
- Verwendet die von ESO gemeldeten Taunt-Effekte (38254 und 38541), keine
  direkte Aggromessung. Ablauf beweist keinen Zielwechsel des Gegners.
- Spielerziele sind standardmäßig ausgeschlossen, unter Tracking & Tests
  jedoch optional aktivierbar.
- Gegner hervorheben: nur Gegner mit ESO-Bossleiste oder Bosse und starke Gegner
  (Standard). Starke Gegner sind nicht zwingend Bosse. „Banner auch bei starken
  Gegnern“ erweitert aktivierte Banner und deren Warntöne. Standard: aus.
  Die bisherige Zwischenstufe wird auf Bosse und starke Gegner umgestellt;
  die Warneinstellung bleibt erhalten.
- Zielfokus nutzt direkte Ereignisidentität oder einen eindeutigen eigenen
  Taunt-Zeitabgleich. Unsichere Zeitabgleiche entfernen keinen anderen Gegner.
  Keine separate Fadenkreuzanzeige oder fremde/Gruppentaunt-Anzeige.
- Fehlende Medien verwenden vorübergehend einen Ersatz, ohne die Auswahl zu
  löschen. Gespeicherte alte Zeilenhintergründe bleiben; ihr Auswahlfeld entfällt.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Bitte Fähigkeit/Morph oder Scribing-Kombination, Sprache, Begegnung,
Beobachtung und gegebenenfalls Lua-Fehler nennen. Bei Bildfehlern hilft ein Screenshot.

CREDITS / TRANSPARENZ
Die frühe Alpha-Idee wurde von Untaunted von Solinur inspiriert:
https://www.esoui.com/downloads/info1475-Untaunted.html
KI-unterstützte Lua-Programmierung unter Leitung von tareN. Funktionen wurden
im echten ESO-Spielbetrieb einschließlich DLC-Dungeons getestet, ergänzt durch
automatisierte Regressionstests. Diese ersetzen keinen echten Spielclient.
Boss-Schädel und Werbegrafik wurden mit KI erzeugt. LibAddonMenu-2.0 und
LibMediaProvider sind separate Projekte und werden nicht mitgeliefert.
Arclight Taunt ist nicht mit ZeniMax Online Studios verbunden.
