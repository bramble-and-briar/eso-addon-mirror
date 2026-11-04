ARCLIGHT TAUNT 1.1.1
Modernes Multi-Target-Taunt-HUD für The Elder Scrolls Online
Author: tareN
Kontakt im Spiel: @uhtareN (PC/EU)

FUNKTIONEN
Kompakte Übersicht Eurer eigenen Taunts aus normalen und Scribing-Fähigkeiten,
einschließlich Eurer eigenen Pets. Flüssige Countdown-Balken, Zielhervorhebung,
Bosskennzeichnung und getrennte Früh-/Ablaufwarnungen machen Prioritaeten sichtbar.
Gegner mit gleichen Namen bleiben getrennte Einträge.

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
- Bosse: Erkennung, Kennzeichnung, Warnzeit, Darstellung und Warntoene.
- Tracking & Tests: Spieler-Taunts und Willkommens-/Sprach-Schrifttests.

Die Vorschau beginnt mit versetzten Timern, fügt unregelmaessig Gegner hinzu
und erneuert Taunts. Pro Zyklus wechseln Dungeon-/Prüfungsnamen. Pause friert
Timer, Ankuenfte und Zielfokus ein; danach geht es an derselben Stelle weiter.
Beim Beenden der Vorschau wird die Pause gelöscht. Die Listenvorschau selbst
erzeugt keine Bossbanner.

BOSSWARNUNGEN
Tuerkis warnt vor dem Ablauf eines erkannten Bosstaunts, standardmaessig
2,5 Sekunden vorher. Rot warnt nach Ablauf. Beide Banner koennen gleichzeitig
eigene betroffene Bosse zusammenfassen. Re-Taunt oder erkannter Tod entfernt
den jeweiligen Boss aus seiner Warnung. Angeheftete abgelaufene Bosse stehen
vor angehefteten aktiven Bossen.

Warnton bei Ablauf, Frühwarnung, beidem oder aus waehlen. Frühwarnton ist
standardmaessig aus, mit Duell-Grenzwarnung vorausgewählt. Ablauf nutzt
Duellbeginn. Rote und unmittelbar anstehende Ablaufwarnungen haben Vorrang;
unterdrueckte Frühtoene werden nicht später nachgeholt.

Warnablauf testen zeigt Frühwarnung, Ablauf und danach Tuerkis unter Rot.
Aktivierte Warnungen und Toene werden berücksichtigt; ohne Frühwarnung nur Rot.
Echte Warnungen haben Vorrang. Die Tauntliste lässt sich ausblenden, während
konfigurierte Bossbanner und Sounds weiterarbeiten. Vorschau/Verschiebemodus
koennen die ausgeblendete Liste zur Einrichtung weiterhin anzeigen.

SPRACHEN
Deutsch, Englisch, Franzoesisch, Spanisch und Russisch werden passend zur
ESO-Spielsprache gewählt. Andere Sprachen nutzen Englisch. Gespeicherte
Positionen und Medien bleiben beim Sprachwechsel erhalten.

GUT ZU WISSEN
- Verwendet die von ESO gemeldeten Taunt-Effekte (38254 und 38541), keine
  direkte Aggromessung. Ablauf beweist keinen Zielwechsel des Gegners.
- Spielerziele sind standardmaessig ausgeschlossen, unter Tracking & Tests
  jedoch optional aktivierbar.
- Breite Bosserkennung kann starke Nicht-Bosse einbeziehen. Warnungen erfordern
  einen offiziell erkannten Boss, ausser Warnungen für klassifizierte Elitegegner
  wurden gesondert aktiviert.
- Zielfokus nutzt direkte Ereignisidentitaet oder einen eindeutigen eigenen
  Taunt-Zeitabgleich. Unsichere Zeitabgleiche entfernen keinen anderen Gegner.
  Keine separate Fadenkreuzanzeige oder fremde/Gruppentaunt-Anzeige.
- Fehlende Medien verwenden vorübergehend einen Ersatz, ohne die Auswahl zu
  löschen. Gespeicherte alte Zeilenhintergruende bleiben; ihr Auswahlfeld entfaellt.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Bitte Fähigkeit/Morph oder Scribing-Kombination, Sprache, Begegnung,
Beobachtung und gegebenenfalls Lua-Fehler nennen. Bei Bildfehlern hilft ein Screenshot.

CREDITS / TRANSPARENZ
Die frühe Alpha-Idee wurde von Untaunted von Solinur inspiriert:
https://www.esoui.com/downloads/info1475-Untaunted.html
KI-unterstützte Lua-Programmierung unter Leitung von tareN. Funktionen wurden
im echten ESO-Spielbetrieb einschließlich DLC-Dungeons getestet, ergaenzt durch
automatisierte Regressionstests. Diese ersetzen keinen echten Spielclient.
Boss-Schaedel und Werbegrafik wurden mit KI erzeugt. LibAddonMenu-2.0 und
LibMediaProvider sind separate Projekte und werden nicht mitgeliefert.
Arclight Taunt ist nicht mit ZeniMax Online Studios verbunden.
