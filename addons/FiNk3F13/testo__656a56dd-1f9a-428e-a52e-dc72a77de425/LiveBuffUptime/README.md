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
- Das Gruppen-Icon zeigt die kuerzeste aktive Restzeit auf einem lebenden Mitglied. Unter der Uptime steht die aktuelle Buffabdeckung, zum Beispiel 4/12: vier von zwoelf auswertbaren Mitgliedern haben den Buff. Der Tooltip zeigt sie ebenfalls. Ohne Gruppe wird der Spieler als einzelne Person gemessen.
- Die Gruppenmessung nutzt sichtbare Buff-Listen und ESO-Effektmeldungen. Sie ist ein Gruppendurchschnitt und entspricht nicht CMX' persoenlicher Uptime.
- Beim Zielwechsel gilt sofort der Zustand des neuen Ziels. Effekte auf nicht anvisierten Gegnern werden nicht weitergemessen.
- Effekte aller Quellen zaehlen, auch solche anderer Spieler.
- Die Effekt-ID kann von der ID der Fertigkeit abweichen. Die Alias-IDs aus SimpleWarhornTimer sowie Effekte mit gleichem normalisierten Namen werden zusammengefasst.
- `--` bedeutet inaktiv, `*` bedeutet aktiv ohne bekannte Ablaufzeit.
- Off Balance (39077) auf dem Gegner: derselbe Timer zeigt Off Balance in Hellgruen und anschliessend die sichtbare Immunitaet (134599) in Orange. Die Immunitaet zaehlt nicht zur Uptime. Ohne sichtbaren Immunitaetseffekt wird kein geschaetzter Cooldown angezeigt; beim Zielwechsel gilt nur das neue Ziel.
- Bei diesem Off-Balance-Tracker ist "Immunitaetszeit aus Uptime ausnehmen" standardmaessig aktiv: erkannte Immunitaet ohne gleichzeitig aktives Off Balance wird vom Zeitnenner abgezogen. Direktes erneutes Ausloesen kann so 100 % ergeben; Verzoegerungen nach der Immunitaet senken den Wert. Schalter deaktivieren fuer die bisherige Uptime ueber den ganzen Kampf. Andere Tracker bleiben unveraendert.
- Set-Cooldowns werden nicht aus beliebigen Buff-Anwendungen geraten. Beim passenden Tracker unter "Cooldown-Quelle" ein Profil waehlen: Turning Tide und Archdruid Devyric fuer Groessere Verwundbarkeit (106754) auf dem Gegner; Nunatak fuer Groessere Bruechigkeit (145977) auf dem Gegner; Roaring Opportunist fuer Groesseren Schlaechter (93109) auf mir oder auf der Gruppe. Standard ist "Keiner".
- Turning Tide, Archdruid und Nunatak verfolgen ausschliesslich eigene erkannte Set-Procs (15 Sekunden). Roaring Opportunist verfolgt die durch ESO gemeldeten Procs pro Empfaenger (22 Sekunden). Die Proc-IDs stammen aus Srendarrs Cooldown-Daten, Srendarr selbst wird nicht benoetigt. Gefilterte ESO-Kampfereignisse starten den Timer; Folgetreffer innerhalb des Cooldowns starten ihn nicht neu.
- Hellgruen zeigt weiterhin die tatsaechliche Effekt-Restzeit, Orange danach den erkannten Set-Cooldown. "Cooldownzeit aus Uptime ausnehmen" zieht nur Cooldownzeit ohne gleichzeitig aktiven Effekt ab. Gruppenwerte ziehen bei Roaring nur die jeweilige auswertbare Empfaengerzeit ab. Dies ist eine Verfuegbarkeitsbetrachtung, keine normale Kampf-Uptime und keine Gegner-Immunitaet. Andere Quellen und Nazaray-Verlaengerungen zaehlen weiterhin als aktive Zeit. Mit deaktiviertem Schalter gilt die normale Uptime.
- Nicht beobachtete Set-Procs werden nicht rueckwirkend geschaetzt. Nach einem UI-Neuladen wird der naechste gemeldete Proc benoetigt. Bei ESO-/PTS-Aenderungen muessen die Proc-IDs und echten Ereignisse im Spiel geprueft werden.
- Nunatak trennt Proc (167682), Stack-Effekt (172992) und Groessere Bruechigkeit (145977/167681). Nur eigene Proc-Meldungen zu 167682 starten den berechneten 15-Sekunden-Cooldown; Stack-Aufbau und Stack-Updates starten ihn nicht. Alte Gegner-Tracker mit 172992 bleiben kompatibel und messen den echten Bruechigkeit-Debuff, nicht die Stack-Dauer. Fuer neue Tracker 145977 mit Nunatak-Profil verwenden. Der genaue Proc-Zeitpunkt bleibt im PTS zu pruefen; die sichtbare Laufzeit von 167682 wird nicht als Cooldowndauer interpretiert.
- Beim Nunatak-Profil zeigt das Icon vor dem Debuff den orangefarbenen Set-Cooldown, bei aktiver Groesserer Bruechigkeit die hellgruene Debuff-Restzeit und danach den verbleibenden Cooldown. Der Cooldown laeuft im Hintergrund weiter; Stackaufbau, Anwendung und Verlaengerung von Groesserer Bruechigkeit starten ihn nicht neu. Die Uptime misst davon unabhaengig weiterhin nur den Debuff.
- Aktualisierung alle 100 ms und bei Effekt-/Zielereignissen. Die Messung folgt den durch ESO sichtbaren Effekten.
- Neu hinzugefuegte Tracker oder eine geaenderte Einheit starten ihre Messung zum Zeitpunkt der Aenderung.

## Befehle

- `/lbu move`: Positionen entsperren/sperren.
- `/lbu reset`: aktuelle Uptime-Messung zuruecksetzen.
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

Die normale Uptime misst weiterhin Effekte aller Quellen. Der optionale Cooldown-Abzug ist eine Set-Verfuegbarkeitsbetrachtung: bei eigenen globalen Procs gilt derselbe Cooldown fuer alle auswertbaren Gruppenmitglieder, nicht nur die gerade vom Buff erreichten. Fuer normale Gruppenabdeckung ohne diese Anpassung den Schalter deaktivieren.

Proc-IDs und Zuordnungen stammen aus den lokal vorhandenen Srendarr-/CMX-Daten. Laufzeiten wurden mit den Setbeschreibungen fuer [Tremorscale](https://eso-hub.com/en/sets/tremorscale), [Crimson Oath](https://eso-hub.com/en/sets/crimson-oaths-rive), [Martial Knowledge](https://eso-sets.com/set/way-of-martial-knowledge), [Drake's Rush](https://eso-sets.com/set/drakes-rush), [Magma Incarnate](https://eso-sets.com/set/magma-incarnate), [Pillager](https://eso-hub.com/en/sets/pillagers-profit) und [Symphony](https://eso-hub.com/en/sets/symphony-of-blades) abgeglichen. Die separate Pillager-Cooldown-ID wird vom Autor von [Group Buff Panels](https://www.esoui.com/downloads/info4226-199164.html) dokumentiert. Echte Proc-Meldungen und Sichtbarkeit der Effekte muessen auf dem PTS noch geprueft werden.

Dies ist kein vollstaendiger Katalog aller Support-Sets. Fuer Olorime, Encratis und weitere Sonderfaelle sind die getrennten Proc-/Empfaengereffekt-IDs noch zu verifizieren. Sets ohne eigenen Cooldown erhalten keinen erfundenen Timer; ihre sichtbaren Buffs bleiben wie bisher ueber Effekt-ID trackbar. Nazaray-Verlaengerungen werden ueber die echte Debuff-Endzeit gelesen, nicht als eigenstaendiger Buff behandelt.

## Entwicklung

`tests/uptime.lua` prueft die Zeitberechnung. `tests/addon.lua` prueft das Addon mit nachgebildeten ESO-APIs.
`tests/libcombat.lua` prueft die LibCombat-Messung, Alias-IDs und Kampfzusammenfassung.
Beide Tests aus diesem Ordner mit einem Lua-Interpreter starten.
`tests/group.lua` und `tests/group-addon.lua` pruefen Gruppen-Uptime, Tod, Wiederbelebung und weiterlaufendes Tracking.
Darstellung und echte Effektmeldungen muessen zusaetzlich im Spiel geprueft werden.
`tests/support-sets.lua` prueft die neuen Support-Profile, Quellenfilterung, Alias-IDs, gemeinsame Gruppen-Cooldowns und getrennte Empfaengersperren.
