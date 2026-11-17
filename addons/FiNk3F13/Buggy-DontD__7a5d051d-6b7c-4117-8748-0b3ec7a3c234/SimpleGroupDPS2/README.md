SimpleGroupDPS2 1.9.37

Eigene Schadens-, Heilungs-, Gesamt-DPS- und Boss-DPS-Erfassung durch eingebettetes LibCombat 89 direkt aus Solinurs Original-Repository, Stand 80817e6, mit beibehaltenem Fix fuer eigene eroeffnende DoTs. Eigenstaendige Kennung; keine gemeinsame Bibliotheksinstanz und keine Abhaengigkeit von CMX2. Lizenz und Aenderungsbeschreibung liegen unter libs/Combat.

DamageMeter.lua ist nur noch ein Adapter fuer LibCombat-Rueckmeldungen. Keine eigene Trefferpufferung, Zielerkennung oder zweite DPS-Berechnung. Heilungswerte kommen ebenfalls direkt von LibCombat, ohne zusaetzlich geschaetzte natuerliche Regeneration. Der sichtbare Kampftimer ist getrennt von den nativen DPS-Zeiten. Boss-Phasen und Kampfende folgen der Bibliothek.

Solo-Tod friert das Ergebnis ein und pausiert nur die eigene Bibliotheksinstanz bis zur Wiederbelebung. In Gruppen bleibt die native Messung beim Spielertod aktiv.

Gruppenaustausch und Summenzeile unveraendert aus 1.9.33. Keine externen Kampf-/Timerdaten oder Messvergleiche. Bei lokalem BattleScrolls bleibt dessen eigener Sender zustaendig.

Alte Messergebnisse werden bei der Umstellung nicht uebernommen; Layout und sonstige Einstellungen bleiben erhalten. /sgd2status zeigt Messgrundlage und Zeiten.

Der sichtbare HUD-Timer zeigt die Zeit seit LibCombats Kampfstart und laeuft auch in Angriffspausen weiter. Er friert am LibCombat-Kampfende ohne Nachlauf der Zusammenfassung ein. DPS-, Boss-DPS- und Heilungszeiten bleiben davon unabhaengig. Solo-Tod friert die Anzeige sofort ein.

Optionale LibCombat-Analyse (standardmaessig aus, nur fuer diese Sitzung):
- Vor dem Testkampf /sgd2analyse an eingeben oder im Einstellungsabschnitt LibCombat-Analyse einschalten.
- /sgd2analyse zeigt fuer alle 25 LibCombat-Datenarten die Anzahl der gelieferten Meldungen.
- /sgd2buffs 1 zeigt Buffs und Debuffs mit Name, Faehigkeits-ID, Ziel, Richtung, beobachteter Wirkzeit, Zeitanteil und maximalen Stapeln. Weitere Seiten: /sgd2buffs 2 usw. In den Einstellungen kann ebenfalls durch die Berichtseiten geblaettert werden.
- /sgd2analyse aus beendet die zusaetzlichen Abonnements; der letzte Bericht bleibt bis zum Neuladen im Speicher. Der naechste aufgezeichnete Kampf ersetzt ihn. Keine Analyseberichte werden gespeichert, exportiert oder an die Gruppe gesendet.
- Wirkzeit ist die Vereinigung beobachteter Intervalle je Effekt/Ziel/Richtung; ueberlappende Quellen werden nicht addiert. Der Prozentwert bezieht sich auf das Analysefenster, nicht auf eine DPS-Zeit. Die Aufnahme folgt dem nativen Kampfende; solo wird sie beim Tod pausiert und nach Wiederbelebung fuer den naechsten Kampf wieder aktiviert.
- Einschalten mitten im Kampf ergibt eine Teilaufnahme. Unbekannte Effektanfaenge und eine eventuell erreichte Speichergrenze werden ausgewiesen. Maximal 2000 unterschiedliche Effekt-/Zielkombinationen pro Aufnahme; weitere Meldungen werden gezaehlt und als Auslassungen gemeldet.
- Eine Meldungszahl von 0 beweist keinen Fehler: Manche Ereignisse treten im Test nicht auf. Erweiterte Charakterwerte sind schon im Original LibCombat 89 intern deaktiviert. Die Analyse bestaetigt gelieferte Ereignisse, nicht die Vollstaendigkeit aller vom Spiel moeglicherweise vorhandenen Daten. Sie ersetzt keine vollstaendige CMX-Oberflaeche und zeigt keine garantierte globale Gruppen-Buffabdeckung.
