# LiveBuffUptime

Eigenstaendiges ESO-Addon fuer frei platzierbare Effekt-Tracker.
Restzeit im Icon, Live-Uptime direkt rechts daneben.
Tracker werden in Menues und auf der Karte ausgeblendet; die Messung laeuft im Hintergrund weiter. Im Move-UI-Modus bleiben die Tracker zum Verschieben sichtbar.

## Einrichtung

1. Addon aktivieren und `/reloadui` ausfuehren.
2. Unter Einstellungen > Addons das Panel **LiveBuffUptime** oeffnen.
3. Effekt-ID eingeben, **Auf mir**, **Auf dem Gegner** oder **Auf der Gruppe** waehlen und **Hinzufuegen** anklicken.
4. Am jeweiligen Tracker **Move UI > Icon verschieben** anklicken.
5. Den ausgewaehlten Tracker mit der Maus ziehen oder mit dem rechten Stick verschieben.
6. Nach 3 Sekunden ohne Bewegung wird die Position automatisch gespeichert und gesperrt, wie in Weaving Metronome. Waehrend des Ziehens bleibt der Modus aktiv. Die Groesse laesst sich weiterhin im Panel einstellen.

Die Bibliotheken `LibHarvensAddonSettings` und `LibCombat` werden benoetigt. Ein weiteres Auswertungsaddon muss nicht installiert sein.
Es werden anfangs keine Tracker vorgegeben.
Jeder gespeicherte Tracker hat den Schalter "Buff aktiv". Ausschalten blendet ihn aus und pausiert seine Messung; ID, Position, Groesse und Optionen bleiben gespeichert. Einschalten startet eine neue Messung ab diesem Zeitpunkt. Bestehende Tracker ohne gespeicherten Schalter bleiben aktiviert. Ausgeschaltete Tracker bleiben auch im Move-Modus und nach einem UI-Neuladen verborgen.

## Messung

- Ab 1.4.0 verwendet Live-Uptime eine ereignisbasierte Einheitenauswertung: Buffsekunden / Summe der individuellen Einheitenzeiten. Die Kampfzeit bleibt intern, ohne weitere Anzeige.
- LibCombat-Schadens-, Heilungs- und Effekt-Ereignisse bestimmen die Daten. Ausgehender eigener Schaden sowie ausgehende/selbstbezogene Heilung setzen das Kampfzeitfenster. Eingehender oder fremder Gruppenschaden verlaengert es nicht. Heilung am Kampfende kann es deshalb verlaengern.
- Die finale LibCombat-Zusammenfassung liefert die verbindlichen Kampfgrenzen. Einheitenzeiten entstehen aus den fuer Live-Uptime relevanten Schadens-, Heilungs- und Buff-Ereignissen und werden auf diese Grenzen beschnitten. Der Endwert kann dadurch den vorlaeufigen Live-Wert korrigieren.
- Gruppenauswertung: standardmaessig beobachtete Spieler-/Gruppenmitglieder mit individuellen Zeiten. "Begleiter in Gruppenmessung" nimmt zusaetzlich eigene Begleiter auf. Todes-, Offline- und Zonenzeiten werden nicht pauschal als Luecken aus dem Nenner geloescht. Als Offline markierte oder in der finalen Zusammenfassung fehlende Einheiten werden ausgeschlossen.
- Ab 1.5.0 filtert "Auswertungsansicht" Einheiten wie eine Heilungs-/Schadensauswahl: beobachtete Effekte oder positive Werte in der gewaehlten Ansicht machen eine Einheit relevant. Nur angelegte Einheiten ohne solche Daten zaehlen nicht. Gruppe/Spieler bieten ausgehende/eingehende Heilung, Ziel bietet ausgehenden/eingehenden Schaden. "Ueberheilung als relevante Daten" ist ausschliesslich fuer ausgehende Heilung relevant.
- "Uptime-Auswertung" bleibt standardmaessig auf "Normale Buffzeit". "Stapelgewichtet" summiert Stapelsekunden je Effekt-ID und Einheit und normalisiert auf deren hoechsten beobachteten Stapel. Bei 5 Sekunden mit einem Stapel und 5 Sekunden mit vier Stapeln ergeben sich 100% normale Zeit, aber 62,5% gewichtete Zeit. Gleichzeitige Instanzen oder Alias-IDs koennen in der gewichteten Instanzsumme ueber 100% ergeben; das ist nicht die normale Buffabdeckung. Der beobachtete Maximalstapel kann den vorlaeufigen Wert waehrend des Kampfes veraendern.
- Buff-Quelle pro Tracker: "Alle Quellen" oder "Nur ich und meine Begleiter". Die Quellenwahl ist unabhaengig von der Auswahl der beobachteten Einheiten; der Gruppendurchschnitt wird durch Summieren der Einheiten berechnet.
- Gleichzeitige Buff-Slots bilden eine gemeinsame aktive Zeit und zaehlen nicht doppelt. Verspaetete Effekt-Ereignisse werden chronologisch nachgerechnet. Buff-Abfragen steuern Restzeit/Icon, nicht die Live-Uptime. Vorzeitig gemeldetes Ende beendet die Ereigniszeit sofort.
- Eine fehlende Ende-Meldung wird am individuellen Einheiten-/Kampfende begrenzt, nicht anhand einer geschaetzten Ablaufzeit. Fehlende Spielereignisse koennen damit nicht sicher erkannt werden.
- Fuer Vergleiche muessen Kampf, Einheitenauswahl, Effekt und Buff-Quelle identisch sein. Gesamtansichten, persoenliche Kampf-Uptime, Stapelgewichtung und Battlescrolls koennen andere Bezugszeiten verwenden. Keine Zusicherung identischer Werte in beliebigen Ansichten.
- Eine alte/unvollstaendige LibCombat-Schnittstelle wird mit einer Warnung als Ersatzmessung mit anderen Messregeln gekennzeichnet.
- Jeder neue Kampf setzt die Messung zurueck. Nach Kampfende bleibt der letzte Prozentwert stehen.
- Vor Kampfbeginn aktive Effekte zaehlen, soweit LibCombat sie als Anfangsereignisse bereitstellt.
- Gleichzeitige Anwendungen derselben ID werden zusammengefasst und nicht doppelt gezaehlt.
- Ziel-Tracker werten den anhand einer ESO-Effektmeldung identifizierten aktuellen Gegner aus. Beim Zielwechsel wird die alte Identitaet verworfen; bis zur neuen Identifizierung steht die Uptime auf null, statt Daten des alten Gegners zu zeigen.
- Alle Live-Uptime-Werte enden mit der LibCombat-Kampfzusammenfassung, nicht erst wenn jedes Gruppenmitglied seinen Kampfstatus verliert.
- Das Gruppen-Icon zeigt die kuerzeste aktive Restzeit auf einem lebenden Mitglied. Unter der Uptime steht die aktuelle Buffabdeckung, zum Beispiel 4/12: vier von zwoelf auswertbaren Mitgliedern haben den Buff. Der Tooltip zeigt sie ebenfalls. Ohne Gruppe wird der Spieler als einzelne Person gemessen.
- Die aktuelle Abdeckungszahl unter dem Gruppenwert zeigt weiterhin lebende, verbundene Mitglieder in derselben Zone. Sie ist eine Momentaufnahme, nicht der historische Live-Uptime-Zeitnenner.
- Die Effekt-ID kann von der ID der Fertigkeit abweichen. Die Alias-IDs aus SimpleWarhornTimer sowie Effekte mit gleichem normalisierten Namen werden zusammengefasst.
- `--` bedeutet inaktiv, `*` bedeutet aktiv ohne bekannte Ablaufzeit.
- Off Balance (39077) auf dem Gegner: derselbe Timer zeigt Off Balance in Hellgruen und anschliessend die sichtbare Immunitaet (134599) in Orange. Die Immunitaet zaehlt nicht zur Uptime. Ohne sichtbaren Immunitaetseffekt wird kein geschaetzter Cooldown angezeigt; beim Zielwechsel gilt nur das neue Ziel.
- Im Live-Uptime-Modus werden Immunitaets- und Cooldownzeiten nicht abgezogen. Die bisherigen Abzugsschalter sind dort deaktiviert; alte gespeicherte Einstellungen bleiben fuer die Ersatzmessung erhalten. Orange Restzeit-Anzeigen bleiben bestehen.
- Set-Cooldowns werden nicht aus beliebigen Buff-Anwendungen geraten. Beim passenden Tracker unter "Cooldown-Quelle" ein Profil waehlen: Turning Tide und Archdruid Devyric fuer Groessere Verwundbarkeit (106754) auf dem Gegner; Nunatak fuer Groessere Bruechigkeit (145977) auf dem Gegner; Roaring Opportunist fuer Groesseren Schlaechter (93109) auf mir oder auf der Gruppe. Standard ist "Keiner".
- Turning Tide, Archdruid und Nunatak verfolgen ausschliesslich eigene erkannte Set-Procs (15 Sekunden). Roaring Opportunist verfolgt die durch ESO gemeldeten Procs pro Empfaenger (22 Sekunden). Die Proc-IDs stammen aus Srendarrs Cooldown-Daten, Srendarr selbst wird nicht benoetigt. Gefilterte ESO-Kampfereignisse starten den Timer; Folgetreffer innerhalb des Cooldowns starten ihn nicht neu.
- Hellgruen zeigt die tatsaechliche Effekt-Restzeit, Orange danach den erkannten Set-Cooldown. Diese Anzeigen aendern die Live-Uptime nicht. Die optionale Verfuegbarkeitsberechnung mit Cooldown-Abzug existiert nur noch in der Ersatzmessung.
- Nicht beobachtete Set-Procs werden nicht rueckwirkend geschaetzt. Nach einem UI-Neuladen wird der naechste gemeldete Proc benoetigt. Bei ESO-/PTS-Aenderungen muessen die Proc-IDs und echten Ereignisse im Spiel geprueft werden.
- Nunatak trennt Proc (167682), Stack-Effekt (172992) und Groessere Bruechigkeit (145977/167681). Nur eigene Proc-Meldungen zu 167682 starten den berechneten 15-Sekunden-Cooldown; Stack-Aufbau und Stack-Updates starten ihn nicht. Alte Gegner-Tracker mit 172992 bleiben kompatibel und messen den echten Bruechigkeit-Debuff, nicht die Stack-Dauer. Fuer neue Tracker 145977 mit Nunatak-Profil verwenden. Der genaue Proc-Zeitpunkt bleibt im PTS zu pruefen; die sichtbare Laufzeit von 167682 wird nicht als Cooldowndauer interpretiert.
- Beim Nunatak-Profil zeigt das Icon vor dem Debuff den orangefarbenen Set-Cooldown, bei aktiver Groesserer Bruechigkeit die hellgruene Debuff-Restzeit und danach den verbleibenden Cooldown. Der Cooldown laeuft im Hintergrund weiter; Stackaufbau, Anwendung und Verlaengerung von Groesserer Bruechigkeit starten ihn nicht neu. Die Uptime misst davon unabhaengig weiterhin nur den Debuff.
- Prozentwerte und Anzeige werden im 100-ms-Takt aktualisiert. Schadens-/LibCombat-Effektmeldungen speichern sofort ihre Zeitdaten, ohne je Meldung die gesamte Anzeige neu zu berechnen. Rohe Effekt-, Ziel-, Gruppen- und Cooldown-Ereignisse erfassen ihre Messdaten sofort; auch Effekte zwischen zwei Ticks bleiben erhalten. Kampfende und Einstellungsaktionen koennen die Anzeige sofort aktualisieren.
- Neu hinzugefuegte Tracker oder eine geaenderte Einheit starten ihre Messung zum Zeitpunkt der Aenderung.

## Befehle

- `/lbu move`: Positionen entsperren/sperren.
- `/lbu reset`: aktuelle Uptime-Messung zuruecksetzen.
- `/lbu check on`: interne Selbstpruefung aktivieren (alternativ im Einstellungsmenue). Nach Kampfende folgen kompakte Chatberichte je Tracker mit Kampfzeit, Buffzeit, auswertbarer Zeit, Abzug und unabhaengig nachgerechnetem Prozentwert. Gruppenzeit ist die Summe der auswertbaren Mitgliedszeiten.
- `/lbu check last`: letzte bis zu 12 Tracker-Berichte erneut anzeigen. `/lbu check off` schaltet die Selbstpruefung aus und verwirft wartende Pruefdaten.
- `/lbu report`: letzter gespeicherter Gruppenbericht (sonst letzter Tracker) mit Buffsekunden und Bezugszeit je Einheit. Bei aktivierter Selbstpruefung werden bis zu 12 kompakte Live-Uptime-Messberichte mit jeweils hoechstens 48 Einheiten sowie die abgeschlossenen Pruefberichte gespeichert. Sie sind nach einem geordneten Logout oder `/reloadui` wieder verfuegbar; ein Absturz vor dem ESO-Speichern kann die letzten Werte verlieren. Alte Messungen aus 1.3 werden nicht nachtraeglich wiederhergestellt.
- Neue Berichte speichern Ansicht, Begleiter-/Ueberheilungsauswahl und Zeit-/Stapelmodus sowie normale und gewichtete Buffsekunden. Die Selbstpruefung rechnet Stapelintervalle unabhaengig und schrittweise nach. Bestehende Berichte bleiben erhalten; ihre neuen Auswahlfelder sind noch nicht vorhanden.
- Selbstpruefung ist standardmaessig aus. Maximal 12 wartende Tracker, 48 Mitglieder je Tracker, 128 Pruefschritte je 100-ms-Tick und 16.384 Schritte je Tracker begrenzen Zusatzlast und Speicher. Ausgelassene/unvollstaendige Pruefungen werden gemeldet; Pruef-/Chatfehler werden abgefangen. Keine Ausgabe pro Schadensereignis. Die Messzeiten erfassen die periodische UI-Berechnung mit der verfuegbaren Spieluhr, keine gesamten FPS oder Netzwerklatenzen.
- `OK intern` bedeutet interne Konsistenz, nicht bestaetigte Vollstaendigkeit der ESO-Ereignisse oder Gleichheit mit anderen Auswertungen. `WARN` samt Bericht fuer die Fehlersuche aufbewahren, etwa als Konsolenclip. Es wird kein Log exportiert und keine zusaetzliche Kampfzeituhr angezeigt.
- `/lbu debug`: Cooldown-Proc-Meldungen im Chat ein-/ausschalten (ID, Resultat und Quelle), zum Pruefen auf dem PTS. Beim Einschalten werden die konfigurierten Tracker und Cooldown-Quellen ausgegeben. Nunatak-Effektmeldungen fuer Proc, Stacks und Bruechigkeit werden ebenfalls protokolliert; eigene periodische Schadensmeldungen zu 167682 koennen den Cooldown starten.

## Weitere Support-Set-Profile

Beim jeweiligen Tracker werden nur Quellen angeboten, die zur Effekt-ID und Einheit passen. Auswahl bleibt manuell; das Addon erkennt keine ausgeruesteten Sets automatisch. Bestehende Tracker behalten ihre Einstellungen.

| Cooldown-Quelle | Effekt-ID | Einheit | Cooldown |
| --- | --- | --- | --- |
| Tremorscale | 80866 | Gegner | eigener Proc, 10 s |
| Crimson Oath's Rive | 159288 | Gegner | eigener Proc, 12 s |
| Martial Knowledge | 127070 | Gegner | eigener Proc, 8 s |
| Drake's Rush / Major Heroism | 61709 oder 150974 | Spieler / Gruppe | eigener Proc, 18 s |
| Magma Incarnate / Minor Resolve | 61693 oder 161527 | Spieler / Gruppe | eigener Proc, 15 s |
| Magma Incarnate / Minor Courage | 147417 | Spieler / Gruppe | eigener Proc, 15 s |
| Crusader / Minor Courage | 147417 | Spieler / Gruppe | eigener Proc, 20 s |
| Brands of Imperium / Schild | 66887 | Spieler / Gruppe | eigener Proc, 12 s |
| Pillager's Profit / Ultimate-Zufuhr | 172055 | Spieler / Gruppe | pro Empfaenger, 45 s |
| Symphony of Blades / Meridia's Favor | 117111 | Spieler / Gruppe | pro Empfaenger, 18 s |

Eigene globale Set-Cooldowns laufen auch bei Gruppen-Trackern unter einem gemeinsamen Proc-Zeitpunkt. Bei Pillager, Symphony und Roaring wird dagegen ausschliesslich die Sperre des jeweiligen Empfaengers gemessen, auch wenn der Effekt von einem anderen Support kommt. Nicht betroffene Mitglieder bekommen keine Empfaengersperre. Pillager nutzt die separate Cooldown-ID 172056 und alternativ eine Anwendung von 172055; Ultimate-Ticks allein starten dessen Timer nicht. Die Cooldown-ID wird nicht als aktive Buffzeit gezaehlt.

Die Live-Uptime misst die im Tracker gewaehlte Buff-Quelle ohne Cooldown-Abzug. Der alte optionale Cooldown-Abzug bleibt ausschliesslich Teil der Ersatzmessung mit anderen Messregeln.

Proc-IDs und Zuordnungen stammen aus den lokal vorhandenen Srendarr-/CMX-Daten. Laufzeiten wurden mit den Setbeschreibungen fuer [Tremorscale](https://eso-hub.com/en/sets/tremorscale), [Crimson Oath](https://eso-hub.com/en/sets/crimson-oaths-rive), [Martial Knowledge](https://eso-sets.com/set/way-of-martial-knowledge), [Drake's Rush](https://eso-sets.com/set/drakes-rush), [Magma Incarnate](https://eso-sets.com/set/magma-incarnate), [Pillager](https://eso-hub.com/en/sets/pillagers-profit) und [Symphony](https://eso-hub.com/en/sets/symphony-of-blades) abgeglichen. Die separate Pillager-Cooldown-ID wird vom Autor von [Group Buff Panels](https://www.esoui.com/downloads/info4226-199164.html) dokumentiert. Echte Proc-Meldungen und Sichtbarkeit der Effekte muessen auf dem PTS noch geprueft werden.

Dies ist kein vollstaendiger Katalog aller Support-Sets. Fuer Olorime, Encratis und weitere Sonderfaelle sind die getrennten Proc-/Empfaengereffekt-IDs noch zu verifizieren. Sets ohne eigenen Cooldown erhalten keinen erfundenen Timer; ihre sichtbaren Buffs bleiben wie bisher ueber Effekt-ID trackbar. Nazaray-Verlaengerungen werden ueber die echte Debuff-Endzeit gelesen, nicht als eigenstaendiger Buff behandelt.

## Entwicklung

`tests/live-uptime-reference.lua` vergleicht 100 zufaellige Buff-Ereignisfolgen direkt mit dem Effektprozessor des benachbarten Combat Metrics. `tests/live-uptime-addon.lua` prueft die neue vollstaendige LibCombat-Schnittstelle, Einheitenzeiten, Heilung, Quellenwahl, Kampfende und gespeicherte Berichte. Die aelteren LibCombat-Tests pruefen weiterhin die Ersatzschnittstelle ohne Gruppenereignisse.
`tests/live-uptime-raid.lua` prueft die Live-Uptime-Messung ueber 25 Minuten mit 12 Mitgliedern, 15.000 Ticks, 1.001 nicht relevanten Gegnern und einer unabhaengigen Buffzeit-Nachrechnung. Der Live-Uptime-Integrationstest prueft ausserdem 2.000 Ereignisse ohne UI-Neuberechnung/Buff-Abfragen und das erneute Aktivieren eines noch laufenden Buffs.
`tests/uptime-evaluation.lua` prueft relevante Einheiten, Begleiter-Auswahl, eingehende/ausgehende Ansichten, Ueberheilung, 50 Stapel-Ereignisfolgen gegen den installierten Referenzprozessor und die gewichtete Selbstpruefung. `StackUptime.lua` verwendet kumulative Integrale und binaere Suche statt vollstaendiger Ereignis-Scans bei jedem UI-Tick.

`tests/uptime.lua` prueft die Zeitberechnung. `tests/addon.lua` prueft das Addon mit nachgebildeten ESO-APIs.
`tests/libcombat.lua` prueft die LibCombat-Messung, Alias-IDs und Kampfzusammenfassung.
Beide Tests aus diesem Ordner mit einem Lua-Interpreter starten.
`tests/group.lua` und `tests/group-addon.lua` pruefen Gruppen-Uptime, Tod, Wiederbelebung und weiterlaufendes Tracking.
Darstellung und echte Effektmeldungen muessen zusaetzlich im Spiel geprueft werden.
`tests/support-sets.lua` prueft die neuen Support-Profile, Quellenfilterung, Alias-IDs, gemeinsame Gruppen-Cooldowns und getrennte Empfaengersperren.
`tests/damage-window.lua` prueft Nachlauf, Boss-Pausen, Gruppen-/Gegnerschaden und identische Live-/Endwerte.
`tests/late-events.lua` prueft 720 Ankunftsreihenfolgen sowie ueberlappende Quellen; `tests/prebuff-expiry.lua` prueft fehlende Ende-Meldungen und getrennte Neuanwendungen.
`tests/raid-duration.lua` simuliert 25 Minuten mit 12 Mitgliedern und 15.000 Aktualisierungen, einschliesslich Tod, Rueckkehr, Mitgliederwechsel und empfaengerspezifischer Cooldowns. Die Laufzeit im Testinterpreter ist keine FPS-Messung in ESO.
`tests/update-batching.lua` prueft 2.000 Bibliotheksereignisse ohne wiederholte Neuberechnung, einen 60-ms-Gruppenbuff zwischen zwei Ticks und die sofortige Endauswertung.
`tests/diagnostics.lua` und `tests/diagnostics-addon.lua` pruefen Nachrechnung, Warnungen, Arbeits-/Speichergrenzen, Fehlerisolation und die Integration am Kampfende.
