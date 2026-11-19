# GroupReset 0.1.1 – Testversion

Autor: FiNk3--F13--

Der Lead löst über LibRadialMenu das gemeinsame Verlassen einer Prüfung aus.
Jeder teilnehmende Spieler benötigt GroupReset, seine Abhängigkeiten und
aktivierte Teilnahme. Spieler ohne Add-on werden nicht hinausbefördert.
Die Gruppe bleibt bestehen. Nach dem Schnellrad-Befehl setzt der Lead die
Instanz automatisch zurück, wenn Auto-Reset eingeschaltet ist (Standard: AN).
Es gibt eine separat schaltbare Todesautomatik (Standard: AUS) und kein
automatisches Zurückporten.

## Einrichtung auf Konsole und PTS

1. GroupReset installieren; LibGroupBroadcast und LibRadialMenu einschließlich
   ihrer Abhängigkeiten müssen ebenfalls installiert sein.
2. Unter Einstellungen → Erweiterungen → GroupReset die Teilnahme einschalten.
   Auf Konsole unter Einstellungen → Add-ons. Teilnahme ist anfangs AUS.
3. Im LibRadialMenu den Eintrag GroupReset → Gruppe: Raid verlassen belegen.
4. Der Lead löst diesen Eintrag innerhalb der Prüfung einmal aus. Das normale
   ESO-Bestätigungsfenster erscheint: Ja führt die Aktion aus, Nein oder
   Abbrechen verwirft sie. Die Controller-Tasten stellt ESO passend zur
   Plattform dar. Das Fenster kann in den Einstellungen abgeschaltet werden.
5. Auto-Reset wartet nach der Ausreise des Leads, bis niemand aus der Gruppe
   mehr in einer Instanz ist. Dann wird die Schwierigkeit gewechselt und nach
   mindestens einer Sekunde auf den vor der Ausreise gespeicherten Wert
   zurückgestellt. Bis zum Abschluss des Resets bitte draußen bleiben.

Auto-Reset hat einen eigenen Schalter in den Einstellungen und im Schnellrad.
Ein nachträgliches Ausschalten verwirft einen noch nicht gestarteten Reset.
Wurde die Schwierigkeit bereits geändert, wird die Wiederherstellung noch
abgeschlossen. ESO kann Änderungen ablehnen, etwa bei einer Gruppe aus der
Aktivitätensuche. Bei fehlender Bestätigung wird ein Hinweis ausgegeben;
eine erfolgreiche Änderung allein garantiert keinen erfolgreich neuen Raid.

## Optionale Todesautomatik

Schaltet der Lead die Todesautomatik ein, reicht ein Todesfall eines echten
Gruppenspielers im selben Raid zum gemeinsamen Verlassen. Diese automatische
Auslösung benötigt keine weitere Bestätigung. Ein eingeschalteter Auto-Reset
setzt die Instanz anschließend wie beim manuellen Schnellrad-Befehl zurück.
Bleibt Todesautomatik AUS, passiert bei Todesfällen nichts automatisch.

Es zählen nur exakt player oder group mit einer Spielernummer und zusätzlich
ESOs Prüfung IsUnitPlayer. Pets, Atronachen, Sprengknochen, Begleiter und andere
beschworene Einheiten lösen nichts aus. Doppelte Todesmeldungen desselben
Spielers und mehrere gleichzeitige Todesfälle starten keine parallele Ausreise.
Die Todesautomatik des Leads benötigt weiterhin aktivierte Teilnahme; die
Empfänger benötigen nur ihre Teilnahme, nicht ihre eigene Todesautomatik.

Empfänger benötigen keine zusätzliche Bestätigung. Sie haben den Empfang mit
der Teilnahme bereits eingeschaltet. Akzeptiert werden nur Signale des
aktuellen Gruppenleiters im selben Gebiet. Außerhalb von Prüfungen passiert
nichts. Bei noch nicht möglichem Verlassen wird höchstens 15 Sekunden gewartet.
Beim Gebiets- oder Leadwechsel und beim Ausschalten wird die Vormerkung verworfen.
Mehrfachdrücken startet keine parallelen Reiseanforderungen. Der Lead verlässt
die Prüfung leicht verzögert, um dem Gruppensignal Zeit zu geben. Die Übertragung
garantiert weder den Empfang bei allen Spielern noch deren erfolgreiches Reisen.
Einzelne Offline-Spieler und ESO-Sperren können die gemeinsame Ausreise verhindern.

Schnellrad enthält außerdem Teilnahme AN/AUS, Auto-Reset AN/AUS,
Todesautomatik AN/AUS und Status anzeigen.
PC: eine frei belegbare Taste ist unter Steuerung → GroupReset vorhanden.
Chatbefehle: /groupreset, /groupreset on, /groupreset off, /groupreset status.
Es werden keine Nachrichten an den Gruppenchat gesendet. Lokale Hinweise gibt
es bei Fehlern, ausdrücklicher Statusabfrage und der optionalen Bestätigung.

## Gemeinsames Gruppensignal

Diese Testversion implementiert das bestehende LibGroupBroadcast-Signal
ExitInstanceRequest (Custom Event 3), mit derselben Bedeutung wie HodorReflexes.
Es wird keine neue Signal-ID unter anderem Namen vergeben. Eine bestehende
Registrierung oder andere ID-Kollision wird abgefangen: GroupReset startet
dann keine Übertragung und zeigt die Ursache auf Anforderung unter Status.
GroupReset und HodorReflexes nicht gleichzeitig laden. Bereits installierte
andere Auswurffunktionen arbeiten unabhängig vom GroupReset-Teilnahmeschalter.
Ein aktivierter HodorReflexes-Empfänger auf einem anderen Rechner kann das
gleiche Signal ebenfalls auswerten; die Wirkung bestimmt dort HodorReflexes.
Für den ersten Test soll die gesamte Gruppe ausschließlich GroupReset verwenden.
Ist HodorReflexes auf demselben Client geladen, registriert GroupReset kein
Signal, um dessen Initialisierung auch bei späterer Registrierung zu schützen.

Referenz für das gemeinsame Signal (eigenständige Implementierung):
https://github.com/m00nyONE/HodorReflexes/blob/main/modules/exitinstance/protocol.lua
LibGroupBroadcast: https://github.com/sirinsidiator/ESO-LibGroupBroadcast

## Teststand

Die Abläufe werden mit ESO- und Bibliotheksnachbildungen geprüft. Ein echter
Test der Übertragung zwischen mehreren ESO-Clients, des Instanz-Resets, der Ausreise im Kampf und
der Konsolenoberfläche steht noch aus. Erst mit zwei Spielern in einer Prüfung
testen: beide Teilnahme AN, Lead-Auslösung; beide sollen hinausreisen, die
Gruppe soll bestehen bleiben. Danach Teilnahme AUS bei einem Empfänger prüfen:
dieser muss im Raid bleiben und Auto-Reset muss auf ihn warten. Erst
anschließend die ganze Raidgruppe testen. Schwierigkeit nach jedem Test prüfen.

Referenz für den Reset durch Schwierigkeitswechsel:
https://github.com/m00nyONE/FastReset/blob/main/logic/leader.lua
