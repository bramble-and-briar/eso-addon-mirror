# What Drops Here? (Beta)

> **Beta-Version 0.3.0.** Die Grundfunktionen sind getestet, aber vieles lässt sich allein nicht in absehbarer Zeit prüfen:
> Verliese und Prüfungen, Weltbosse, Taschendiebstahl, Diebstahl, Spuren, andere Auto-Loot-Addons, Gamepad-Modus.
> Rückmeldungen sind sehr willkommen, siehe [Beta-Rückmeldung](#beta-rückmeldung).

Merkt sich, was dir jede Beutequelle bisher gegeben hat, und zeigt es dir neben dem Fadenkreuz,
bevor du plünderst.

> *Schwere Truhe – 47x geplündert · Ø 32 Gold*
> *Härtungsmittel 3x · 6 %*

Eine vollständige Loot-Tabelle wie in anderen Spielen gibt es in ESO nicht: Fast jede Quelle kann fast alles droppen,
und vieles hängt von Zone und Level ab. What Drops Here? sammelt deshalb **deine eigene Statistik**, Quelle für Quelle.

## Was erfasst wird

- **Rohstoffvorkommen** mit Hauptrohstoff und Beifang (z. B. Kernholz, Stilmaterial, Härtungsmittel)
- **Behälter** wie Truhen, Säcke, Fässer, Kisten, Rucksäcke
- **Leichen** von Gegnern und Tieren
- **Kleintiere**, die du mit „Nehmen" einsammelst (Insekten, Quallen, Motten …)
- **Taschendiebstahl**
- **Spuren** (Antiquitäten)

Jeder Fund wird vollständig gespeichert: mit seiner Item-ID und seiner Kategorie (z. B. „Schmiedematerial").
Ob ein Item am Fadenkreuz mit Namen oder zusammengefasst in seiner Kategorie erscheint, entscheidet erst die Anzeige.
Die Statistik gilt pro Quelle und Zone und für alle Charaktere deines Accounts.

## Anzeige am Fadenkreuz

- Erscheint bei Vorkommen, Behältern, Leichen, Kleintieren und auch bei **lebenden** Gegnern, Tieren und NPCs.
- Je Eintrag: Gesamtmenge und Anteil der Plünderungen, in denen er dabei war.
- **Im Kampf ausgeblendet.**

## Einstellungen

Im Spiel unter *Einstellungen → Erweiterungen → What Drops Here?* oder mit `/wdh_menu` (benötigt LibAddonMenu-2.0).

**Alle Plünderungen werden immer gespeichert.** Die Anzeige-Einstellungen bestimmen nur, was am Fadenkreuz erscheint:
- Anzeige an/aus, wie viele Einträge
- **je Art der Quelle eine eigene Schwelle**: „Aus" oder ab welcher Qualität. Arten: **Feinde** (auch lebende),
  **Truhen und Behälter**, **Rohstoffe**, **Kleintiere und Sonstiges**, **Diebstahl**.
  So zeigt z. B. ein Farm-Charakter bei Rohstoffen schon grüne Funde, bei Feinden erst lila.

**Je Charakter:** Jeder Charakter hat seine eigenen Anzeige-Einstellungen; im Menü unter *Einstellungen anderer Charaktere*
lassen sich die eines anderen übernehmen. Die gesammelten Daten gelten weiterhin für den ganzen Account.

**Mit Namen anzeigen ab Qualität:** darunter erscheinen Items zusammengefasst in ihrer Kategorie, darüber einzeln
mit Namen. Weil immer alles mit Item-ID gespeichert wird, wirkt die Einstellung sofort auch auf alle bisherigen Funde.

**Diebstahl** aus fremden Behältern, Tresoren und von fremden Gegenständen wird getrennt gespeichert.
Eine gestohlene „Kiste" verfälscht also nicht die Statistik freier Kisten, und am Fadenkreuz
erscheint bei einem fremden Behälter die Diebstahl-Statistik.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/wdh_menu` | Einstellungsmenü öffnen |
| `/wdh` | Statistik der zuletzt geplünderten Quelle |
| `/wdh <Name>` | Quelle suchen (erst aktuelle Zone, dann alle) |
| `/wdh_zone` | alle Quellen der aktuellen Zone |
| `/wdh_zones` | alle Zonen mit gespeicherten Daten |
| `/wdh_hud` | Anzeige am Fadenkreuz an/aus |
| `/wdh_units` | Anzeige für lebende Ziele an/aus |
| `/wdh_show 0-5` | Anzeige-Schwelle (Qualität) für alle eingeschalteten Arten; einzeln im Menü |
| `/wdh_names 0-5` | am Fadenkreuz mit Namen ab Qualität, darunter als Kategorie |
| `/wdh_debug` | Debug-Ausgabe im Chat an/aus |
| `/wdh_reset ja` | alle Daten löschen (`yes` geht in jeder Sprache) |

## Bekannte Einschränkungen

### Flächenplündern (mehrere Leichen auf einmal)

Ist in den Spieleinstellungen **Flächenplündern** aktiv (manche Auto-Loot-Addons wie *Much Smarter AutoLoot*
schalten es selbst ein), legt ESO die Beute aller Leichen in der Nähe in **ein** Lootfenster.
Das Spiel nennt dabei nur **einen** Namen als Quelle. Welcher Gegenstand von welcher Leiche stammt,
ist nicht mehr feststellbar, z. B. bei einem Weltboss mit seinen Begleitern.

What Drops Here? speichert solche Plünderungen deshalb **getrennt als „Sammelplünderung"**,
statt sie dem einen genannten Gegner gutzuschreiben. Sie verfälschen also nicht die Statistik der Einzelquellen.
Bei lebenden Zielen am Fadenkreuz werden nur die eindeutigen Zuordnungen gezeigt.

**Für genaue Zahlen pro Gegner:** Flächenplündern in den Spieleinstellungen abschalten.

### Weitere Einschränkungen

- **Nicht jeder Gegner wird unter dem Fadenkreuz erkannt.** Das liegt am Spiel; bei solchen Gegnern bleibt die Anzeige leer.
- **Gleichnamige Quellen werden zusammengefasst.** ESO liefert keine eindeutige Kennung pro Objekt; alle „Eisenerz"-Vorkommen
  einer Zone landen im selben Eintrag. Das ist gewollt, denn so entsteht die Statistik.
- **Gespeichert wird beim Ausloggen, bei `/reloadui` und beim normalen Beenden.** Bei einem Absturz oder Alt+F4
  gehen die Plünderungen seit dem letzten Speichern verloren. Das betrifft alle Addons.
- **Taschendiebstahl:** Der Name des Opfers kommt von der letzten Interaktion bzw. dem Ziel unter dem Fadenkreuz.

### Sprachen

Die Texte gibt es auf Deutsch und Englisch; andere Client-Sprachen zeigen Englisch.
Die Erfassung funktioniert in jeder Sprache, Quellen werden aber unter ihrem Namen in der Client-Sprache gespeichert.
Daten aus verschiedenen Client-Sprachen mischen sich deshalb nicht.

## Geplant

- **Datenbanken zusammenführen:** ein kleines externes Werkzeug (ähnlich HarvestMapData), das die Statistiken
  mehrerer Spieler zusammenführt. Eigene und gemeinsame Daten sollen getrennt sichtbar bleiben.
- **Feinere Anzeige:** z. B. für Rohstoffe die Spanne pro Plünderung (Minimum–Maximum) statt nur der Gesamtmenge.
- **Heatmap:** Karte, wo bestimmte Rohstoffe oder Set-Gegenstände besonders häufig droppen, zum gezielten Farmen.
- **Weitere Sprachen:** Übersetzungen (z. B. Französisch) sind willkommen, eine Vorlage ist `lang/en.lua`.

## Beta-Rückmeldung

Am meisten helfen Berichte aus Situationen, die bisher wenig getestet sind: Verliese, Prüfungen, Weltbosse,
Taschendiebstahl, Diebstahl, Spuren, Gamepad-Modus und andere Auto-Loot-Addons.

1. Debug-Ausgabe einschalten: `/wdh_debug` oder im Menü unter *Entwicklung*.
2. Plündern wie gewohnt. Im Chat steht zu jeder Plünderung Quelle, Zone, Art der Quelle und jedes Item mit Kategorie.
3. Fällt etwas auf (falsche Quelle, falsche Kategorie, fehlende Beute, Lua-Fehler), die betreffenden Chatzeilen
   mit kurzer Beschreibung in die Kommentare auf ESOUI schreiben.

## Zusammenspiel mit Auto-Loot-Addons

Getestet mit *Much Smarter AutoLoot* und *Smarter AutoLoot*. Erfasst wird, was eine Quelle **angeboten** hat,
nicht nur was genommen wurde. Die Filter deines Auto-Loot-Addons verfälschen die Statistik also nicht.

## Installation

ZIP von den [Releases](https://github.com/cudddel-spec/WhatDropsHere/releases) laden und nach
`Dokumente\Elder Scrolls Online\live\AddOns\` entpacken, sodass dort der Ordner `WhatDropsHere` liegt.

Optional: [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) für das Einstellungsmenü.

## Entwicklung

- Die Addon-Dateien liegen direkt im Hauptordner des Repositorys; ein Klon im `AddOns`-Ordner lässt sich sofort im Spiel testen.
- `python tools/build_release.py` baut `dist/WhatDropsHere-<Version>.zip` mit nur den Dateien, die Spieler brauchen.
- `docs/` enthält das Konzept mit Testprotokollen und offenen Fragen sowie die ESOUI-Beschreibungen (Deutsch und Englisch) und die Änderungsliste für ESOUI.
- Fehler und Ideen gern als [Issue](https://github.com/cudddel-spec/WhatDropsHere/issues).

## Lizenz

MIT, siehe [LICENSE](LICENSE).
