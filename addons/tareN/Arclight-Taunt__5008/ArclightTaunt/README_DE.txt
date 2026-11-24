ARCLIGHT TAUNT 1.4.0
Modernes Multi-Target-Taunt-HUD für The Elder Scrolls Online
Autor: tareN
Kontakt im Spiel: @uhtareN (PC/EU)

FUNKTIONEN
Arclight zeigt deine Taunts aus normalen Fähigkeiten und aus der Schriftlehre.
Auch Taunts deiner beschworenen Kreaturen werden erfasst. Gleichnamige Gegner
haben eigene Einträge.
Flüssige Countdowns, Zielhervorhebung und Bosswarnungen zeigen, was als
Nächstes Aufmerksamkeit braucht.

Eine kleine Leiste oder ein Kreis am Fadenkreuz zeigt den bestätigten eigenen
Taunt ohne Zahlen. Die Anzeige ist standardmäßig aus und unter „Tauntstatus am
Fadenkreuz“ aktivierbar. Optional zeigt ein helles Symbol fehlende Bestätigung
eines eigenen Taunts an. Aggro und Taunt-Effekt können sich unabhängig ändern.
Auch das Symbol ist standardmäßig aus. Neue Konfigurationen starten beim Einschalten mit
einem mittigen Kreis; die Leiste bleibt wählbar. Die gewählte Form bleibt beim
Ausschalten erhalten. Gespeicherte Größen und Positionen werden beibehalten.
Beide Formen lassen sich unabhängig von der Liste platzieren.

Unabhängige Bossfilter begrenzen Liste oder Fadenkreuzanzeige auf ESO-Bosse und,
im umfassenden Modus, auch starke Gegner. Andere Taunts werden weiter erfasst;
konfigurierte Bosswarnungen bleiben aktiv. „Position: gesperrt“ im Schnellzugriff
anklicken, um sichtbare Anzeigen zu ziehen. Vorschau und Erfassung laufen weiter.

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
ESO beenden, Addondateien ersetzen und ESO wieder starten.
Behalte live/SavedVariables/ArclightTaunt.lua, damit deine Einstellungen erhalten bleiben.
Optionales Aufräumen: Nur AddOns/ArclightTaunt vor dem Entpacken des
neuen Ordners löschen. Alte ungenutzte Dateien können ohne Auswirkung auf das
Addon liegen bleiben; dieser Schritt entfernt lediglich Reste früherer Versionen.
/reloadui lädt neue Texturdateien einer laufenden Sitzung nicht zuverlässig nach.
Einstellungen gelten accountweit und gemeinsam für alle Megaserver. Kampfverläufe,
Charakterfortschritt und andere serverspezifische Daten werden nicht gespeichert.

EINSTELLUNGEN
ESC > Einstellungen > Erweiterungen > Arclight Taunt
- Bei der ersten Installation führt ein kurzer Chat-Hinweis zu diesem Menü. Die Listenvorschau lässt sich im Schnellzugriff starten.
- Schnellzugriff: zwei kompakte Tastenreihen für Vorschau, Pause, Positionssperre, Balkenstil, Kontrast und Zielfokus.
- Taunt-Liste: Sichtbarkeit, Priorität, Größe, Abstände, Spalten und Position.
- Bosswarnungen: Warntest, Banner, Töne, Warnzeiten und Position.
- Fadenkreuz: Anzeigeart, Vorschau, Ausrichthilfe, Größe und Position.
- Design & Schrift: Balken, Zielhervorhebung, Animationen, Schriften und Farben.
- Ziele & Markierungen: ESO-Zielmarkierungen, Spielerziele, Boss-Erkennung, Namen und Totenköpfe.
- Countdown & Bereinigung: Sekundenanzeige, Warnschwellen und Entfernen von Einträgen.

Die Position ist standardmäßig gesperrt. Zum Ziehen einer sichtbaren Liste oder
Fadenkreuzanzeige entsperren und danach wieder sperren. Außerhalb des Kampfes
hilft die jeweilige Vorschau beim Platzieren. Entsperren startet oder pausiert
keine Vorschau.
Die Tasten zeigen den aktuellen Stil oder Zustand; Kontrast und Zielfokus sind
ausgeschaltet blasser. Ein Klick ändert die Einstellung ohne Auswahlmenü.

„Vorschau anzeigen“ startet einen simulierten Kampf. In der Pause stehen die
Timer still und es erscheinen keine neuen Gegner. Beim Fortsetzen läuft die
Vorschau ab derselben Stelle weiter. Die Gegnerzahl passt zur Listenkapazität,
die Taunts starten versetzt. Die Listenvorschau erzeugt
selbst keine Bossbanner. Ein bestätigter neuer eigener Taunt beendet laufende
Listen-, Fadenkreuz- und Warnvorschauen, damit echte Kampfdaten übernehmen.

Die helle Balkenspur verändert die leere schmale Leiste; die Zeileneinfärbung
betont Einträge nahe ihrer Warnschwellen. Beide Details sind unabhängig und nur
bei normalen schmalen Balken aktiv. Beim Füllen der ganzen Zeile und bei hohem
Kontrast bleiben beide Einstellungen gespeichert.

„Abgelaufene Taunts behalten“ betrifft den Timerablauf. „Tote Gegner entfernen“
entfernt erkannte Tote unabhängig davon, auch bereits als tot bekannte Einträge
beim Einschalten. Ist die Todesbereinigung aus, gilt für diese Zeilen weiterhin
die Ablaufregel. Kampfende leert die erfasste Liste immer.

Unter „Fadenkreuz“ lässt „Vorschau anzeigen“ einen Countdown
wiederholt durch die gewählten Warnstufen laufen, unabhängig von der Liste und auch
beim Verschieben. Das optionale helle Symbol erscheint nach Ablauf nur, wenn es
aktiviert ist.
„Vorschau-Fadenkreuz“ hilft mit der kleinen oder großen
ESO-Grafik beim Ausrichten, auch im Menü. Schließen der Einstellungen oder
Kampfbeginn beendet die Fadenkreuzvorschau. Die echte Anzeige erscheint nur
im Kampf. Schließen der Einstellungen speichert einen laufenden Ziehvorgang,
ohne die Positionssperre zu ändern.

Kreis und Leiste merken sich Größe, Dicke, Hintergrund-Deckkraft und Position
getrennt. Der Kreis startet mittig, die Leiste unter dem Fadenkreuz. Zum
Platzieren die Position entsperren oder genaue horizontale/vertikale Werte nutzen.
„Dicke“ ändert die Leistenhöhe bzw. Ringstärke. „Position zurücksetzen“ setzt
die Position der gewählten Form zurück. „Anzeige zurücksetzen“ setzt zusätzlich
ihre Darstellung zurück. Aktivierung,
Vorschau, Bossfilter und andere Form bleiben erhalten. Die allgemeinen
Standardwerte setzen beide Formen zurück und schalten die Anzeige aus.

FARBEN & LESBARKEIT
Eigene Warnfarben lassen sich unter „Design & Schrift“ aktivieren.
Sie gelten für Liste, Fadenkreuz und Bossbanner. Die Arclight-Farben bleiben
Standard; Timertext wird bei Bedarf für dunkle Flächen aufgehellt.

Beobachtete ESO-Zielmarkierungen stehen getrennt vom Boss-Schädel neben dem
Namen. Änderungen nutzen direkte Zielzuordnung oder einen eindeutig passenden
aktiven eigenen Taunt mit bekannter Start- und Endzeit. Bei Unsicherheit bleibt
die letzte Beobachtung erhalten. Neuvergabe entfernt das Symbol nur beim
bisherigen Besitzer. Änderungen außerhalb des Blickfelds benötigen eine erneute
Beobachtung. Arclight setzt selbst keine Marker. Unter „Ziele & Markierungen“
lässt sich die Anzeige ausschalten. Beispielsymbole stehen neben der Option.

Ersatzgrafiken anderer Addons werden übernommen, wenn sie ESOs gemeinsame
Symbolfunktion verwenden. Ändern sie nur die Anzeige über dem Gegner, bleibt
das Listensymbol unverändert. Fehler bei der Symbolabfrage blenden das Icon aus;
der Taunt-Timer läuft weiter.

BOSSWARNUNGEN
In der Standardpalette warnt Türkis vor dem Ablauf eines erkannten Bosstaunts, standardmäßig
2,5 Sekunden vorher. Rot warnt nach Ablauf. Beide Banner können gleichzeitig
eigene betroffene Bosse zusammenfassen. Re-Taunt oder erkannter Tod entfernt
den jeweiligen Boss aus seiner Warnung. Angeheftete abgelaufene Bosse stehen
vor angehefteten aktiven Bossen.

Warntöne lassen sich für Ablauf, Frühwarnung, beides oder keines aktivieren.
Der Frühwarnton ist standardmäßig aus; Duell-Grenzwarnung ist vorausgewählt.
Bei Ablauf ist Duellbeginn vorausgewählt. Sichtbare und unmittelbar anstehende
Ablaufwarnungen haben Tonvorrang; unterdrückte Frühtöne werden nicht nachgeholt.

„Warnablauf testen“ steht oben im Reiter „Bosswarnungen“. Der Test zeigt
Frühwarnung, Ablauf und danach beide Banner. Das Ablaufbanner erscheint im Test
auch bei deaktivierter Anzeige im Kampf. Die Frühwarnung und die Töne richten
sich nach deinen Einstellungen. Über „Warnablauf stoppen“ beendest du die Testfolge.
Echte Warnungen haben Vorrang. Die Tauntliste lässt sich ausblenden, während
konfigurierte Bossbanner und Sounds weiterarbeiten. Die Vorschau kann eine
ausgeblendete Liste zur Einrichtung weiterhin anzeigen.

SPRACHEN
Deutsch, Englisch, Französisch, Spanisch und Russisch werden passend zur
ESO-Spielsprache gewählt. Andere Sprachen nutzen Englisch. Gespeicherte
Positionen und Medien bleiben beim Sprachwechsel erhalten.

GUT ZU WISSEN
- Verwendet von ESO gemeldete Taunt-Effekte, keine direkte Aggromessung. Ablauf
  beweist keinen Zielwechsel des Gegners.
- Spielerziele sind standardmäßig ausgeschlossen. Unter „Ziele & Markierungen“
  lassen sie sich aktivieren.
- Umfassende Boss-Erkennung kann auch starke Gegner erfassen, die keine Bosse
  sind. Warnungen für sie sind optional und standardmäßig aus.
- Die Fadenkreuzanzeige bestätigt nur eigene Taunts; Taunts anderer Spieler
  werden nicht erfasst.
- Unterstützung für Schriftlehre gilt für erkannte Taunt-Effekte.

FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments
Nutzt du Arclight? Wir freuen uns zu hören, was dir gefällt und was besser
funktionieren könnte. Ein kurzer Kommentar hilft, auch ohne gefundenen Fehler.
Bei Problemen bitte Fähigkeit/Morph oder Scribing-Kombination, Sprache,
Begegnung und Beobachtung nennen. Lua-Fehler oder Screenshots helfen, falls vorhanden.

CREDITS / TRANSPARENZ
- Frühe Alpha-Idee: Untaunted von Solinur:
  https://www.esoui.com/downloads/info1475-Untaunted.html
- Fadenkreuz-Idee: Dryzler's Taunt Helper von dryzler.elder-geek.net:
  https://www.esoui.com/downloads/info1755-DryzlersTauntHelper.html

Entwickelt von tareN mit KI-unterstützter Lua-Programmierung.
Boss-Schädel und Werbegrafik wurden mit KI erzeugt. LibAddonMenu-2.0 und
LibMediaProvider sind separate Projekte und werden nicht mitgeliefert.
Arclight Taunt ist nicht mit ZeniMax Online Studios verbunden.
