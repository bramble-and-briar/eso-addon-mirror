# Änderungen

## 0.3.0-beta (07.11.2026)

- **Anzeige-Einstellungen je Charakter.** Jeder Charakter hat seine eigene Anzeige; im Menü lassen sich
  die Einstellungen eines anderen Charakters übernehmen. Beim Update starten alle Charaktere mit den bisherigen Einstellungen.
  Die Daten bleiben für den ganzen Account gemeinsam.
- **Anzeige-Schwelle je Art der Quelle.** Feinde, Truhen und Behälter, Rohstoffe, Kleintiere und Sonstiges und Diebstahl
  haben je eine eigene Schwelle („Aus" oder ab welcher Qualität). Das ersetzt die bisherigen Schalter und die gemeinsame Schwelle.
  `/wdh_show` setzt die Schwelle für alle eingeschalteten Arten.
- **Englische Texte.** Englisch ist jetzt Standard; im deutschen Client bleibt alles deutsch.
  Andere Client-Sprachen (Französisch, Japanisch …) zeigen Englisch.
- Auto-Loot schneller als What Drops Here?: Hat z. B. Much Smarter AutoLoot das Lootfenster schon geleert und geschlossen,
  bevor es gelesen werden konnte, werden Items und Gold jetzt beim Eingang gezählt, statt verloren zu gehen.
- Lootfenster ohne Namen (z. B. die Truhe am Dunklen Anker): Aktualisierungen beim Nehmen der Items
  gehören jetzt zur selben Plünderung, statt als namenlose Plünderung verworfen zu werden.
- `/wdh_reset yes` löscht die Daten in jeder Sprache (im deutschen Client weiterhin auch `/wdh_reset ja`).

## 0.2.0-beta (06.11.2026)

Erste öffentliche Beta.

- Erfassung pro Quelle und Zone: Rohstoffvorkommen, Truhen und Behälter, Leichen, Kleintiere („Nehmen"),
  Taschendiebstahl, Diebstahl, Spuren
- Jeder Fund wird mit Item-ID und Kategorie gespeichert; Stoff und Leder getrennt
- Anzeige am Fadenkreuz, auch für lebende Ziele; im Kampf ausgeblendet
- Anzeige-Filter nach Qualität und nach Art der Quelle (Feinde, Truhen und Behälter, Rohstoffe, Kleintiere und Sonstiges, Diebstahl)
- Sammelplünderungen (Flächenplündern) getrennt gespeichert
- Erneut geöffnete Quellen (Reste, die ein Auto-Loot-Addon liegen lässt) werden nicht doppelt gezählt
- Einstellungsmenü (LibAddonMenu-2.0, optional) und Slash-Befehle
- Debug-Ausgabe standardmäßig aus
- Für Live (API 101051) und Testserver 12.2 (API 101052); neue Trinkets vom Testserver werden erkannt
