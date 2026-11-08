SimpleGroupDPS2: separate Testversion ohne ausgehenden DPS/HPS-Versand.

Eigene Schadens-, Heilungs- und Zeitberechnung unveraendert aus Version 1.9.14. Empfang anderer Gruppenmitglieder bleibt erhalten. Eigene BattleScrolls-Callbacks werden weiterhin ignoriert. Eigene gespeicherte Einstellungen und Addon-Kennung.

Zum Vergleich SimpleGroupDPS deaktivieren, SimpleGroupDPS2 und BattleScrolls aktivieren. BattleScrolls misst und sendet weiterhin selbst; diese Testkopie sendet nichts.

Version 1.9.15: Tankzeilen folgen dem tatsaechlich empfangenen Nachrichtentyp (DPS oder effektive/gesamte HPS), statt alte DPS oder 0 zu zeigen. Tanksymbole und Rollenfilter bleiben erhalten. Eigene Tanks waehlen HPS bei hoeheren HPS als DPS. Echte Gruppenheiler zeigen empfangene effektive HPS (rohe HPS), zwei Tanks und zwei Heiler sind separat getestet. HPS werden nicht als Schaden addiert. Keine Fake-Spieler, kein Versand; Schaden und Timer unveraendert.

Version 1.9.16: Anzeige folgt fuer alle Rollen dem empfangenen BattleScrolls-Nachrichtentyp. Keine Rollen-Uebersteuerung fuer DDs oder Heiler. Eigene Anzeige verwendet wie classifyData rohe HPS > Gesamt-DPS, bei Gleichstand Schaden. Symbole und Sichtbarkeitsfilter folgen weiterhin der gewaehlten Rolle. Keine Aenderung an Messung, Timer oder Versandfreiheit.

Version 1.9.17: Eigene rohe und effektive HPS werden wie in BattleScrolls durch dieselbe Begegnungszeit wie DPS geteilt, statt durch das kurze Fenster vom ersten zum letzten Heilereignis. Spaete passive Heilung wird dadurch nicht auf eine Sekunde hochgerechnet. Eigener Schaden an persoenlichen/freundlichen Zielen wird wie ApplyPersonalDamage zur Gesamt-DPS gezaehlt; fremder eingehender Schaden bleibt ausgeschlossen. Boss-Zuordnung, Kampfzeit und Senderfreiheit bleiben unveraendert. 30 Tests; HPS zusaetzlich direkt mit originalen Arithmancer-Funktionen verglichen. Ob diese beiden Korrekturen die gesamte konkrete Video-Abweichung beheben, muss erneut im Spiel geprueft werden.

Version 1.9.18 ergaenzt nur einen lesenden Messvergleich. /sgd2vergleich oder Allgemein > Messvergleich ausgeben zeigt eigene und native ungerundete Zeit, Rohschadenssummen, HPS und bis zu drei abweichende Ziel-Summen. Bei beiden aktiv messenden Addons wird einmal pro Sekunde ein unabhaengiger Vergleich im Speicher behalten, damit er nach dem Kampf abrufbar bleibt (Alter steht dabei). Keine Uebernahme fremder Werte, kein Sender, keine weitere spekulative Mess- oder Timerkorrektur. Fotos allein belegen die Ursache der aktuellen Abweichung nicht.
