SimpleGroupDPS 2.0.6

Eigene Schadens-, Heilungs-, Gesamt-DPS- und Boss-DPS-Erfassung durch eingebettetes LibCombat 89 direkt aus Solinurs Original-Repository, Stand 80817e6, mit beibehaltenem Fix fuer eigene eroeffnende DoTs. Eigenstaendige Kennung; keine gemeinsame Bibliotheksinstanz und keine Abhaengigkeit von CMX2. Lizenz und Aenderungsbeschreibung liegen unter libs/Combat.

DamageMeter.lua ist nur noch ein Adapter fuer LibCombat-Rueckmeldungen. Keine eigene Trefferpufferung, Zielerkennung oder zweite DPS-Berechnung. Heilungswerte kommen ebenfalls direkt von LibCombat, ohne zusaetzlich geschaetzte natuerliche Regeneration. Der sichtbare Kampftimer ist getrennt von den nativen DPS-Zeiten. Boss-Phasen und Kampfende folgen der Bibliothek.

Solo-Tod friert das Ergebnis ein und pausiert nur die eigene Bibliotheksinstanz bis zur Wiederbelebung. In Gruppen bleibt die native Messung beim Spielertod aktiv.

Gruppenaustausch und Summenzeile unveraendert aus 1.9.33. Keine externen Kampf-/Timerdaten oder Messvergleiche. Bei lokalem BattleScrolls bleibt dessen eigener Sender zustaendig.

Alte Messergebnisse werden bei der Umstellung nicht uebernommen; Layout und sonstige Einstellungen bleiben erhalten. /sgdstatus zeigt Messgrundlage und Zeiten.

Der sichtbare HUD-Timer zeigt die Zeit seit LibCombats Kampfstart und laeuft auch in Angriffspausen weiter. Er friert am LibCombat-Kampfende ohne Nachlauf der Zusammenfassung ein. DPS-, Boss-DPS- und Heilungszeiten bleiben davon unabhaengig. Solo-Tod friert die Anzeige sofort ein.

Optionale LibCombat-Analyse (standardmaessig aus, nur fuer diese Sitzung):
- Vor dem Testkampf /sgdanalyse an eingeben oder im Einstellungsabschnitt LibCombat-Analyse einschalten.
- /sgdanalyse zeigt fuer alle 25 LibCombat-Datenarten die Anzahl der gelieferten Meldungen.
- /sgdbuffs 1 zeigt Buffs und Debuffs mit Name, Faehigkeits-ID, Ziel, Richtung, beobachteter Wirkzeit, Zeitanteil und maximalen Stapeln. Weitere Seiten: /sgdbuffs 2 usw. In den Einstellungen kann ebenfalls durch die Berichtseiten geblaettert werden.
- /sgdanalyse aus beendet die zusaetzlichen Abonnements; der letzte Bericht bleibt bis zum Neuladen im Speicher. Der naechste aufgezeichnete Kampf ersetzt ihn. Keine Analyseberichte werden gespeichert, exportiert oder an die Gruppe gesendet.
- Wirkzeit ist die Vereinigung beobachteter Intervalle je Effekt/Ziel/Richtung; ueberlappende Quellen werden nicht addiert. Der Prozentwert bezieht sich auf das Analysefenster, nicht auf eine DPS-Zeit. Die Aufnahme folgt dem nativen Kampfende; solo wird sie beim Tod pausiert und nach Wiederbelebung fuer den naechsten Kampf wieder aktiviert.
- Einschalten mitten im Kampf ergibt eine Teilaufnahme. Unbekannte Effektanfaenge und eine eventuell erreichte Speichergrenze werden ausgewiesen. Maximal 2000 unterschiedliche Effekt-/Zielkombinationen pro Aufnahme; weitere Meldungen werden gezaehlt und als Auslassungen gemeldet.
- Eine Meldungszahl von 0 beweist keinen Fehler: Manche Ereignisse treten im Test nicht auf. Erweiterte Charakterwerte sind schon im Original LibCombat 89 intern deaktiviert. Die Analyse bestaetigt gelieferte Ereignisse, nicht die Vollstaendigkeit aller vom Spiel moeglicherweise vorhandenen Daten. Sie ersetzt keine vollstaendige CMX-Oberflaeche und zeigt keine garantierte globale Gruppen-Buffabdeckung.

Umbenennung aus SimpleGroupDPS2 1.9.37: identische Funktionen. Der bisherige private SavedVariables-Name bleibt kompatibel. Durch den geaenderten Add-on-Namen kann ESO jedoch eine neue Einstellungsdatei bzw. Zuordnung anlegen; eine automatische Uebernahme alter Einstellungen ist nicht garantiert. HUD-Positionen gegebenenfalls einmal neu setzen. Primaere Befehle: /sgdstatus, /sgdanalyse, /sgdbuffs. Die alten /sgd2-Befehle bleiben als Aliase erhalten. Nur eine Version installieren; ein vorhandenes altes SimpleGroupDPS wird durch diese Version ersetzt.

2.0.3: Nach Solo-Tod wird die Wiederbelebung sowohl ueber Ereignisse als auch bei jeder normalen HUD-Aktualisierung anhand des tatsaechlichen Spielerzustands erkannt. Ein fehlendes oder vorzeitig gesendetes PLAYER_ALIVE blockiert die Messung nicht mehr. Doppelte Lebendmeldungen setzen einen neuen Kampf nicht zurueck. /sgdstatus zeigt den Pausenzustand.

2.0.5: Gruppenversand wartet nicht mehr auf zuvor empfangene DPS/HPS-Pakete. Dadurch koennen zwei SimpleGroupDPS-Nutzer ohne BattleScrolls selbststaendig den Austausch starten. Versand erfolgt weiterhin nur in einer Gruppe bei aktiviertem Teilen und freigegebenem LibGroupBroadcast-Protokoll. Ein lokal aktives BattleScrolls behaelt seinen eigenen Sender. Messung, HUD und Timer bleiben unveraendert. Alle teilnehmenden SimpleGroupDPS-Nutzer sollten aktualisieren.

2.0.6: Ein Treffer auf Wildtiere ohne anschliessenden Kampfzustand kann die Messung nicht mehr endlos aktiv halten. Nach LibCombats Ereigniswartezeit wird der native Kampfabschluss angestossen, wenn weder Spieler noch Gruppenmitglieder noch ein erkannter Boss-/Portalkampf aktiv sind. Neue Aktivitaet in der nativen Nachlaufphase hebt diesen vorgemerkten Abschluss wieder auf. DPS-/HPS-Berechnungen bleiben unveraendert.

Wamasu Lover (2.0.7): In Rand des Wahnsinns / Sanity's Edge erscheint nach einem bestaetigten toedlichen Wamasu-Ansturm ein lokaler goldener Schriftzug mit Abwaertspfeil ueber dir oder dem betroffenen Gruppenmitglied. Erkennung ueber Todesereignisse und beim eigenen Tod auch ueber den nachgereichten Todesrueckblick (Charge-IDs 191133, 191139, 200544 und 200558). Ein vorangegangener normaler Treffer allein reicht nicht. Die Anzeige bleibt nach Kampfende bis zur Wiederbelebung/Geistform, Gruppenplatz- oder Gebietswechsel. In der Pruefung automatisch aktiv, ohne Menueschalter. Kein TrueShotMarkers als Abhaengigkeit; keine Countdown-Funktion aus TrueShotMarkers uebernommen. Andere Spieler sehen den Text nur, wenn sie diese Funktion ebenfalls installiert haben. Kein Netzwerkversand und keine Aenderungen an DPS/HPS- oder Ultimate-Berechnungen.

Wamasu-Erkennung: Angreifer-ID aus Ansturm-Ereignissen wird gemerkt. Beim eigenen Tod wird ein unmittelbar vorausgegangener Ansturm-Treffer mit derselben Treffer-ID in der Todesrueckschau abgeglichen, falls ESO dort keinen Angreifer nennt. Ein anderer spaeterer Schadenstreffer verwirft diese Zuordnung. /sgdwamasu zeigt Gebiet, letzten Todesstoss und Markerzustand zur Fehlerdiagnose; auch nach der Wiederbelebung abrufbar.
