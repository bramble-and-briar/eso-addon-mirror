# IsoStats2 2.3.6 – Kritschadenanzeige bis 200 %

Das HUD zeigt standardmaessig den berechneten Kritschaden bis maximal 200 %, auch oberhalb des Spiel-Caps. Beim ersten Laden dieser Version wird die bisherige Einstellung einmal auf Rohwertanzeige umgestellt. Danach bleiben eigene Aenderungen der Einstellung erhalten.

Das wirkliche Spiel-Cap bleibt separat 125 % bzw. 155 % bei erkannter Meisterschaft. Die Diagnose zeigt weiterhin den vollstaendigen Rohwert (auch ueber 200), den nutzbaren Wert und den Ueberschuss. 200 % sind nur die Anzeigegrenze, kein neues Spiel-Cap. Mit 'CD: nutzbaren Wert anzeigen' laesst sich die alte begrenzte Anzeige wieder einschalten.

# IsoStats2 2.3.4 – Krit-Buffdiagnose

Puppe kurz anvisieren, danach `/isostats2 cdinfo` eingeben. Die Ausgabe zeigt die Live-Rechnung und beim Wegschauen zusaetzlich das zuletzt anvisierte Ziel, deutlich als GESPEICHERT und NICHT LIVE markiert.

- `/isostats2 buffs`: wie cdinfo, kompakte Krit-Buffdiagnose.
- `/isostats2 buffs all`: zusaetzlich alle von ESO sichtbaren Spieler- und Zieleffekte mit Name, ID, Stapeln und Restzeit zum Messzeitpunkt. Diese Rohliste addiert nichts.
- `/isostats2 buffs last`: zuletzt anvisiertes Ziel, kein Kampfmaximum.
- `/isostats2 buffs live`: ausschliesslich aktuelle Messung.
- `/isostats2 cdinfo live` und `cdinfo last`: bisherige Live-/Kampfmaximum-Diagnose.

Zeigt Basis, Charakterbonus, Hinterhalt, Schatten, jeden eingerechneten Ziel-Kritbonus mit Effektfamilie, Spielname, ID und Erfassungsart sowie Zielsumme, Rohwert, HUD-Wert, Cap und Ueberschuss. Der CD-Diagnoseknopf in den Einstellungen verwendet ebenfalls die neue Ausgabe.

Spielerbuffs wie Lucent Echoes werden nicht pauschal nochmals addiert: Ihr numerischer Anteil ist gegebenenfalls bereits im ESO-Charakterwert enthalten. Ihre Sichtbarkeit allein beweist keinen separaten numerischen Beitrag. Unbekannte Effekte werden nur in der Rohliste angezeigt. Ein unbekannter oder unsichtbarer Effekt wird nicht automatisch erkannt oder geschaetzt.

Die letzte Zielmessung wird bei Zonenwechsel oder Diagnose-Reset geloescht. Sie zeigt den letzten beobachteten Zustand; abgelaufene Effekte der gespeicherten Messung sind nicht als aktuell zu verstehen. Keine Aenderung der bisherigen HUD-Berechnung. Kein Live-Test im Spiel durchgefuehrt.

Validierung: Lua-5.1-Simulation mit vorhandenen Kritschaden-Regressionstests und neuen Tests fuer 67+50+25, Zielverlust, gespeicherte Messung, Rohliste, Reset, deaktivierte Zielboni, Catalyst-Deduplizierung und Chatbefehle.

---

# Vorheriger Stand 2.3.3


## Gespeicherter PEN-Kampfvergleich

Seit 2.3.3 wird der Vergleich automatisch im Kampf mitgespeichert: beide Rechnungen und ihre Statusquellen vom selben Zeitpunkt beim höchsten beobachteten IsoStats2-PEN-Wert inklusive Zielboni. Bei gleichem neuen Gesamtwert bleibt der höhere alte Vergleichswert erhalten. /isostats2 compare zeigt standardmäßig diese gespeicherte Messung, ausdrücklich nicht live; nach Buff-Ablauf oder Wegschauen bleibt sie erhalten. /isostats2 compare last zeigt nur die Aufzeichnung, /isostats2 compare live ausdrücklich nur aktuelle Werte. Neuer Kampf oder PEN/CD-Diagnose-Reset leert die Vergleichsmessung. Nach einem Update/reload muss erneut gekämpft werden; frühere Kämpfe lassen sich nicht nachträglich rekonstruieren. Ohne Aufzeichnung zeigt compare ersatzweise klar gekennzeichnete Live-Werte mit Hinweis auf die fehlende Messung.

## Quellen des Vergleichs

/isostats2 compare oder der Knopf PEN: mit originalem IsoStats vergleichen liest beide geladenen Addons direkt. Kein Befehl im Original nötig. Ausgabe: geladene Originalversion (falls direkt lesbar), eigene/zusätzliche Pen zum Messzeitpunkt, Differenz sowie Statusquellen beider Berechnungen mit Kennzeichnung alter Ersatz-Debuffs. Beide Vergleichssummen enthalten Zielboni unabhängig vom jeweiligen HUD-Schalter. Fehlt die lesbare Schnittstelle im Original, rechnet IsoStats2 die lokale IsoStats-2.0.4-Referenzlogik mit den aktuellen sichtbaren Effekten nach. Diese Ausgabe heißt ausdrücklich ALT-LOGIK und ist KEIN ausgelesener Original-HUD-Wert. Sie zeigt, welche zusätzlichen Ersatz-Debuffs die alte Logik für Force of Nature annehmen würde. Sie bestätigt weder die tatsächlich geladene Originalversion noch die Richtigkeit einer der beiden Anzeigen. Das Original wird nicht geändert.

## Kritschaden nach dem CMX-Prinzip

CD wird getrennt berechnet: 50 Prozent Basis + erweiterter Charakterbonus + Backstabber gemäß ausgerüsteten CP-Stufen + eingeschaltete Schatten-Korrektur + eingeschaltete Zieleffekte. Eigene Buffs und Ausrüstung werden nicht erneut addiert, weil sie bereits im erweiterten Charakterwert enthalten sind. Backstabber nimmt wie die untersuchte lokale LibCombat-Version eine Flanke an; die tatsächliche Position wird nicht automatisch erkannt.

Ziel-Kritboni werden über sichtbare Effekt-IDs und zeitlich begrenzte Kampf-/Effektereignisse erfasst. Brittle und Elemental Catalyst werden nach Familie zusammengeführt. Die Prüfungsdummy-Version von Catalyst zählt anstelle ihrer drei Elementkomponenten. Ereigniswerte zählen nur bei sicherer Gegner-ID-Zuordnung. Zielwechsel, Ablauf und Fade werden berücksichtigt.

Das bestehende CD-Feld zeigt standardmäßig den am Cap begrenzten Wert. In den CC/CD-Einstellungen lässt sich stattdessen der rechnerische Gesamtbonus anzeigen. Automatisch wird zwischen Standard-Cap 125 und 155 bei aktiver, erlernter Above-and-Beyond-Meisterschaft (ID 263605) unterschieden. Dafür werden aktive Klassenlinien durchsucht, ohne feste Klassen- oder Linienposition. Fehlt die benötigte Skill-API, bleibt der Standardwert mit entsprechendem Diagnosehinweis. Eine manuelle Cap-Einstellung ist verfügbar, wenn die Automatik ausgeschaltet wird.

Der historische Schatten/Göttlich-Workaround der untersuchten LibCombat-Version ist optional und standardmäßig AUS. Er liest den Schatten-Effekttext und die Göttlich-Traits der sieben Rüstungsteile, berechnet die Differenz und wendet sie ausschließlich bei eingeschalteter Option an. Unlesbare Werte werden nicht geschätzt. Vor dem Einschalten mit dem Spielwert abgleichen; der Workaround könnte in aktuellen Spielversionen überflüssig sein.

- /isostats2 cdinfo: aktuelle Aufschlüsselung und separat gespeicherter höchster CD-Kampfwert.
- /isostats2 cdinfo live: ausschließlich aktuelle Messung.
- /isostats2 cdinfo last: ausschließlich gespeicherte Messung, ausdrücklich nicht live.
- /isostats2 cdinfo reset: PEN- und CD-Aufzeichnung gemeinsam leeren. Dasselbe gilt für peninfo reset.

Die Aufschlüsselung zeigt Basis, Charakterbonus, CP, Ziel-IDs und Herkunft, Rohwert, begrenzten Wert, Cap und Überschuss. Neue Kämpfe starten eine neue Aufzeichnung. Ein abgelaufener Buff oder Wegschauen überschreibt den letzten Kampfwert nicht. Die Aufzeichnung bleibt bis zum nächsten Kampf, Reset oder UI-Neustart erhalten. Der gespeicherte Wert ist der höchste beobachtete Momentwert, kein schaden-gewichteter Kampfmittelwert wie in einer vollständigen CMX-Auswertung. Der begrenzte Wert ist rechnerisch und kein aus Treffern gemessener Multiplikator.

Das vorhandene HUD, gespeicherte Größen und Positionen sowie das ursprüngliche IsoStats bleiben unverändert. Keine zusätzliche LibCombat-Abhängigkeit. Referenz: lokal installiertes Combat Metrics 1.7.8 / LibCombat 87; Skill-ID-Abgleich mit dem [ESOUI-Dump](https://cdn.esoui.com/forums/showthread.php?p=54280).

## PEN-Diagnose nach dem Test

/isostats2 peninfo zeigt jetzt die aktuelle Messung und separat den höchsten beobachteten Kampfwert samt vollständiger Zusammensetzung. Jede Messung hat eine laufende Nummer, Zielname und Alter. Die Kampfaufzeichnung startet automatisch beim Kampfbeginn neu. Buff-Ablauf, weitere Grundwert-Abfragen am selben Ziel oder Wegschauen überschreiben den gespeicherten Wert nicht. Der gespeicherte Stand ist ausdrücklich als nicht live gekennzeichnet. Er bleibt bis zum nächsten Kampf, manuellem Reset oder UI-Neustart erhalten.

/isostats2 peninfo live zeigt nur die aktuelle Messung, /isostats2 peninfo last nur den gespeicherten Testwert, /isostats2 peninfo reset beginnt eine leere Diagnose. Die Einstellungen unter IsoStats2 > Durchdringung bieten ebenfalls Ausgabe und Reset. Der Bericht zeigt auch empfangene Status-Ereignisse und deren Gegner-IDs. Eine unbekannte aktuelle Ziel-ID wird ausdrücklich gemeldet; nicht sicher zugeordnete Effekte werden weiterhin nicht ungeprüft addiert. Die jüngsten Ereignisse sind globale Statusmeldungen seit dem Zonenwechsel und gehören nicht zwingend zum aktuellen Ziel.

## Genauere CP-Erfassung

Force of Nature verwendet ausschließlich die acht echten Status-IDs. Sichtbare Status-Effekte werden mit einem neuen Collector für EVENT_COMBAT_EVENT und EVENT_EFFECT_CHANGED zusammengeführt. Ereignisse werden nach tatsächlicher Gegner-ID gespeichert; Auffrischungen zählen einmal, abgelaufene oder entfernte Effekte werden entfernt. Keine Pen mehr allein aufgrund kleinerem Bruch, Brittle, Magickaraub, Verwundbarkeit oder Schändung. Ein Status-Typ zählt einmal, maximal acht Typen mit jeweils 660 Pen, nur bei ausgerüstetem und freigeschaltetem CP.

Die Zuordnung zum anvisierten Gegner erfolgt ausschließlich über ein Effektereignis, das ausdrücklich den Unit-Tag reticleover und eine Gegner-ID liefert. Gegner werden nicht nur anhand ihres Namens gleichgesetzt. Nach einem Zielwechsel wird diese Zuordnung zurückgesetzt. Solange sie fehlt, zählen nur direkt sichtbare echte Status-IDs. Unsichtbare Effekte können dann vorübergehend fehlen. /isostats2 peninfo zeigt ID-Zuordnung und Erfassungsquelle (Kampfereignis, Effektereignis oder sichtbare Status-ID). Zonenwechsel leert den Ereignisspeicher.

Backstabber verwendet wie CMX die tatsächlich investierten Stufen: 2 Prozentpunkte je vollständigen 10 Punkten, maximal 10, nur wenn ausgerüstet. Die Flanke wird weiterhin angenommen und nicht automatisch erkannt. Eigene HUDs, persönliche Positionen, Größen und Abstände bleiben erhalten. LibCombat ist keine zusätzliche Abhängigkeit.

Proportionen überarbeitet: einheitliches Spaltenraster, gleiche Breite für PWR/PEN/CR und exakt doppelte Rasterbreite für CC/CD sowie PR/SR. Reduzierte Zahlen-Schriftgröße (26 statt 30), weniger Höhe und gleichmäßige Innenabstände. CR wird beim ersten Laden dieser Version unter PR/SR linksbündig angeordnet, statt rechts abzustehen. Individuelle Skalierung und Abstände bleiben verfügbar.

Eigenständige Entwicklungsversion mit neuer Kachel-Darstellung. IsoStats bleibt unverändert. Eigene Einstellungen und Befehle: IsoStats2SavedVariables und /isostats2.

## Neues HUD

Fünf einzeln verschiebbare dunkle Kacheln statt der bisherigen Zahl-mit-Kürzel-Anordnung:

- PWR: kleines goldenes Kürzel oben, große weiße Zahl darunter.
- PEN: mintfarbener Akzent und schmaler Fortschrittsbalken bis zum eingestellten Zielwert. Zahl und Balken werden am Ziel grün.
- CC / CD: zwei klar getrennte Spalten mit violetten Überschriften.
- PR / SR: zwei Spalten mit blauen Überschriften.
- CR: eigene Kachel mit violettem Akzent.

Alle Zahlen stehen links unter ihrem Kürzel. Die Breite bleibt bei wechselnden Werten fest; die Zahlenplätze reservieren eine zusätzliche Ziffer. Dunkler Hintergrund, dezente dünne Rahmen und eine schmale farbige Seitenlinie. Kein großer gemeinsamer Kasten.

Beim ersten Laden der neuen Darstellung werden nur die IsoStats2-Kacheln einmal zu einer kompakten Gruppe ohne Überlappung angeordnet. Danach bleiben manuell gespeicherte Positionen erhalten. Größe und Abstände aus der Kopie bleiben erhalten.

## Bedienung

Einstellungen > Addons > IsoStats2. Jedes HUD hat einen eigenen Schalter, Größe (%), Abstände (%), Move UI und Position zurücksetzen. Größe skaliert das ganze HUD gleichmäßig. Abstände verändert Rand und Spaltenabstand. Änderungen zeigen fünf Sekunden Vorschau. Move UI funktioniert mit rechtem Stick oder Maus und speichert nach drei Sekunden ohne Bewegung.

PEN: Zielwert ist standardmäßig 18.200 und anpassbar. PEN: Berechnung anzeigen zeigt eigene Werte, erkannte Effekte und Annahmen im Chat.

/isostats2 version zeigt die Version; /isostats2 peninfo zeigt die Pen-Aufschlüsselung. /isostats2 allein schaltet die HUDs um; /isostats2 pwr, pen, crit, res oder criticalResistance positioniert das entsprechende HUD.

Wenn IsoStats und IsoStats2 gleichzeitig aktiviert sind, zeigen beide ihre unabhängigen HUDs an.

## Berechnung

PWR und PEN nutzen jeweils den höheren Waffen-/Magiewert; CC die höhere Krit-Chance. CD enthält die oben beschriebene CMX-orientierte Berechnung mit Rohwert und Cap. Kein automatischer Flankentest. Crusher zählt bei ID 17906 oder 120007 weiterhin pauschal 2.108. Andere variable Resistenzsenkungen bleiben nominale Schätzwerte. Die neue Force-of-Nature-Erfassung und ihre Grenzen sind oben beschrieben. PR, SR und CR sind Rohwerte aus dem Spiel. Eine separate Erkennung von Zonen mit deaktivierten CP ist weiterhin nicht eingebaut.

Die Darstellung, unabhängigen Einstellungen, Skalierung, Bildschirmgrenzen, Move UI und PEN-Balken wurden mit simulierten ESO-Aufrufen geprüft. CD-Komponenten, Ereignisablauf, Zieltrennung, Cap-Automatik samt fehlender API, optionale Schatten-Korrektur und gespeicherte Kampfwerte wurden zusätzlich mit simulierten ESO-Aufrufen geprüft. Ein Live-Test im Spiel steht aus. Benötigt LibHarvensAddonSettings.

Datenreferenz: lokales Meterskull 1.6.1 von bibik92. API-Referenz: https://github.com/esoui/esoui/blob/master/ESOUIDocumentation.txt

This Add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates.
