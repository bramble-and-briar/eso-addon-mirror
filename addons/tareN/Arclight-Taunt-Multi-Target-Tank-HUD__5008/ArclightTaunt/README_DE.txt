ARCLIGHT TAUNT 1.2.0
Modernes Multi-Target-Taunt-HUD für The Elder Scrolls Online
Autor: tareN
Kontakt im Spiel: @uhtareN (PC/EU)

FUNKTIONEN
Arclight zeigt deine eigenen Taunts aus normalen und Scribing-Fähigkeiten,
auch die deiner Pets. Gegner mit gleichem Namen bleiben getrennte Einträge.
Flüssige Countdowns, Zielhervorhebung und Bosswarnungen zeigen, was als
Nächstes Aufmerksamkeit braucht.

Eine kleine Leiste oder ein Kreis am Fadenkreuz zeigt den bestätigten eigenen
Taunt ohne Zahlen. Grau bedeutet nur: kein eigener Taunt bestätigt, nicht
zwingend Aggroverlust. Die Anzeige ist standardmäßig aus; aktivierbar unter
„Tauntstatus am Fadenkreuz“. Neue Konfigurationen starten beim Einschalten mit
einem mittigen Kreis; die Leiste bleibt wählbar. Die gewählte Form bleibt beim
Ausschalten erhalten. Gespeicherte Größen und Positionen werden beibehalten.
Beide Formen lassen sich unabhängig von der Liste platzieren.

Unabhängige Bossfilter begrenzen Liste oder Fadenkreuzanzeige auf ESO-Bosse und,
im umfassenden Modus, auch starke Gegner. Andere Taunts werden weiter erfasst;
konfigurierte Bosswarnungen bleiben aktiv. „Anzeigen verschieben“ friert die
Vorschau ein, damit sich beide Anzeigen getrennt platzieren lassen.
„Anzeige verschieben“ im Fadenkreuz-Reiter bewegt nur die kleine Anzeige.

„Animationen reduzieren“ stoppt dekorative Bewegungen. Countdown, Warnungen
und Töne bleiben aktiv.

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
Addonordner ersetzen und SavedVariables behalten, damit deine Einstellungen
erhalten bleiben.
Einstellungen gelten accountweit und gemeinsam für alle Megaserver. Kampfverläufe,
Charakterfortschritt und andere serverspezifische Daten werden nicht gespeichert.

EINSTELLUNGEN
ESC > Einstellungen > Erweiterungen > Arclight Taunt
- Schnellzugriff: Vorschau anzeigen/pausieren, Anzeigen verschieben und Gegnerpool.
- Liste & Anordnung: Sichtbarkeit, Größe, Abstände, Spalten und Position.
- Design & Lesbarkeit: Balken, Hintergründe, Kontrast und Zielfokus.
- Schrift & Countdown: Schriftarten, Textgröße, Sekundenanzeige und Warnschwellen.
- Tauntstatus am Fadenkreuz: Anzeigeart, Sichtbarkeit, Darstellung und Position.
- Bosse: Unterreiter für Bosswarnungen und Boss-Erkennung.
- Erfassung: Spielerziele, Tote entfernen und abgelaufene Einträge.

Die Vorschau zeigt unterschiedliche Gegner und versetzte Taunts. Zum Einstellen
pausieren; danach läuft sie an derselben Stelle weiter. Die Listenvorschau
erzeugt selbst keine Bossbanner.

Unter „Tauntstatus am Fadenkreuz“ lässt „Vorschau anzeigen“ einen Countdown
wiederholt durch Türkis, Gelb und Rot laufen, unabhängig von der Liste und auch
beim Verschieben. „Vorschau-Fadenkreuz“ hilft mit der kleinen oder großen
ESO-Grafik beim Ausrichten, auch im Menü. Schließen der Einstellungen oder
Kampfbeginn beendet Vorschau und Verschieben. Die echte Anzeige erscheint nur
im Kampf.

Kreis und Leiste merken sich Größe, Dicke, Hintergrund-Deckkraft und Position
getrennt. Der Kreis startet mittig, die Leiste unter dem Fadenkreuz. Zum
Platzieren „Anzeige verschieben“ oder genaue horizontale/vertikale Werte nutzen.
„Dicke“ ändert die Leistenhöhe bzw. relative Ringstärke. „Anzeige zurücksetzen“
setzt nur Darstellung und Position der gewählten Form zurück. Aktivierung,
Vorschau, Bossfilter und andere Form bleiben erhalten. Die allgemeinen
Standardwerte setzen beide Formen zurück und schalten die Anzeige aus.

BOSSWARNUNGEN
Türkis warnt vor dem Ablauf eines erkannten Bosstaunts, standardmäßig
2,5 Sekunden vorher. Rot warnt nach Ablauf. Beide Banner können gleichzeitig
eigene betroffene Bosse zusammenfassen. Re-Taunt oder erkannter Tod entfernt
den jeweiligen Boss aus seiner Warnung. Angeheftete abgelaufene Bosse stehen
vor angehefteten aktiven Bossen.

Warntöne lassen sich für Ablauf, Frühwarnung, beides oder keines aktivieren.
Der Frühwarnton ist standardmäßig aus; Duell-Grenzwarnung ist vorausgewählt.
Bei Ablauf ist Duellbeginn vorausgewählt. Rote und unmittelbar anstehende
Ablaufwarnungen haben Tonvorrang; unterdrückte Frühtöne werden nicht nachgeholt.

„Warnablauf testen“ zeigt Frühwarnung, Ablauf und danach Türkis unter Rot.
Aktivierte Warnungen und Töne werden berücksichtigt; ohne Frühwarnung nur Rot.
Echte Warnungen haben Vorrang. Die Tauntliste lässt sich ausblenden, während
konfigurierte Bossbanner und Sounds weiterarbeiten. Vorschau/Verschiebemodus
können die ausgeblendete Liste zur Einrichtung weiterhin anzeigen.

SPRACHEN
Deutsch, Englisch, Französisch, Spanisch und Russisch werden passend zur
ESO-Spielsprache gewählt. Andere Sprachen nutzen Englisch. Gespeicherte
Positionen und Medien bleiben beim Sprachwechsel erhalten.

GUT ZU WISSEN
- Verwendet von ESO gemeldete Taunt-Effekte, keine direkte Aggromessung. Ablauf
  beweist keinen Zielwechsel des Gegners.
- Spielerziele sind standardmäßig ausgeschlossen, unter Erfassung
  jedoch optional aktivierbar.
- Umfassende Boss-Erkennung kann auch starke Gegner erfassen, die keine Bosse
  sind. Warnungen für sie sind optional und standardmäßig aus.
- Die Fadenkreuzanzeige bestätigt nur eigene Taunts; Taunts anderer Spieler
  werden nicht erfasst.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Bitte Fähigkeit/Morph oder Scribing-Kombination, Sprache, Begegnung,
Beobachtung und gegebenenfalls Lua-Fehler nennen. Bei Bildfehlern hilft ein Screenshot.

CREDITS / TRANSPARENZ
- Frühe Alpha-Idee: Untaunted von Solinur:
  https://www.esoui.com/downloads/info1475-Untaunted.html
- Fadenkreuz-Idee: Dryzler's Taunt Helper:
  https://www.esoui.com/downloads/info1755-DryzlersTauntHelper.html

Entwickelt von tareN mit KI-unterstützter Lua-Programmierung.
Boss-Schädel und Werbegrafik wurden mit KI erzeugt. LibAddonMenu-2.0 und
LibMediaProvider sind separate Projekte und werden nicht mitgeliefert.
Arclight Taunt ist nicht mit ZeniMax Online Studios verbunden.
