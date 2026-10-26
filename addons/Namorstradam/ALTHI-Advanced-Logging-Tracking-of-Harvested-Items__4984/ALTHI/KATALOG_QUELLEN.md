# ALTHI 0.6.1 – Materialkatalog und Quellen

Stand: 24. Oktober 2026.

## Grundbestand

Catalog.lua enthält 293 eindeutige Material-ID-Kandidaten und 4.015 Nachschlagerezept-IDs. Rezepte werden nicht als Sammelbeute aktiviert. Unpassende/obsolete Kandidaten werden vom aktuellen Client nach Namen und Itemtyp aussortiert; gewöhnliche Versorgerzutaten und Fische aus älteren Tabellen sind für diesen Auftrag nicht freigegeben.

Quellen wurden als Daten gelesen, nicht ausgeführt:

- UESP-Reagenzien: https://github.com/uesp/uesp-esolog/blob/master/esoPotionData.php
- CraftStore-Zutaten, Runen, Lösungsmittel und Rezept-IDs: https://github.com/Rhyono/CraftStore/blob/master/CraftStore_VarInit.lua
- LibLazyCrafting, materialItemIDs: https://github.com/Dolgubon/LibLazyCrafting/blob/master/Smithing.lua
- HarvestMap-Rohstoffzuordnungen einschließlich der Erz-, Holz-, Faser- und Schmuckstaubstufen: https://github.com/seisenreich/HarvestMap/blob/master/Modules/HarvestMap/Main/PinTypes.lua
- Romans 40 beobachtete IDs aus dem ersten Spieltest: BEOBACHTETE_IDS.csv. Deren Mengen werden niemals als Startzähler geladen.
- Zusätzliche Lederrohstoffe und seltene Materialien aus ESO-Hubs eigener Itemdatenbank, konkrete URLs und IDs im Projekt unter sources/extra-material-ids.json.

Belegte Lederrohstoffstufen: 793, 4448, 23095, 6020, 23097, 23142, 23143, 800, 4478, 71239.

Zusätzliche geprüfte seltene IDs:

- Aurbic Amber 139411: https://eso-hub.com/en/trading/139411
- Pulverized Aurbic Amber 139417: https://eso-hub.com/en/trading/139417
- Aetherial Dust 115026: https://eso-hub.com/en/trading/115026
- Fortified Nirncrux 56862: https://eso-hub.com/en/trading/56862
- Potent Nirncrux 56863: https://eso-hub.com/en/trading/56863

Der reproduzierbare Generator liegt unter tools/build_catalog.py. Heruntergeladene Quelldateien und Prüfsummen liegen unter sources/ außerhalb der Addon-ZIP.

## Ergänzung aus dem laufenden Client

Die Item-ID liefert über ESO den tatsächlichen lokalisierten Namen, Icon, Qualität und Materialtyp. Namen werden mit großem Anfangsbuchstaben angezeigt. Die aktuellen gültigen Stilmaterialien und API-verfügbaren Eigenschaftsmaterialien werden ohne Besitz abgefragt. Rezept-IDs liefern ihre Materialzutaten in kleinen Hintergrundschritten. Auch diese Rezepte muss der Spieler weder besitzen noch kennen.

Der vollständige Rezeptabgleich läuft einmal pro Addon-/API-Version. Danach wird er aus den gespeicherten Daten wiederverwendet; ein Patch mit neuer API löst den Abgleich erneut aus. Neue passende Ressourcen-IDs können beim Looten oder einer Handwerksbeuteländerung ergänzt werden. Eine abgeschaltete Gruppe schließt auch neue Einträge dieser Gruppe aus.

Die Materialtypen unterstützen jede Stufe, ohne das Handwerkslevel des Charakters auszuwerten. Das ist von der Herkunftserkennung getrennt: Ein bekanntes Material wird nur als Sessionfund gezählt, wenn seine Quelle zusätzlich als Sammelvorgang zugelassen ist.

## Grenzen

Dies ist kein vollständiger aktueller UESP-Datenbankexport; dessen öffentlicher Abruf lieferte eine Browserprüfung. Die angegebenen veröffentlichten Tabellen und die Live-APIs decken den Grundbestand und weitere Materialien ab, belegen aber keine lückenlose Liste jedes seitdem eingeführten Sondermaterials. Auflösbarkeit im Client beweist außerdem nicht aktuelle Erhältlichkeit.

Der Auftrag konzentriert sich auf Ressourcen und ihre Bestände. Eine Katalogzutat aus einem Einrichtungsrezept ist ein Materialeintrag; das bedeutet nicht, dass ALTHI bereits Möbel herstellt. Ebenso sind verarbeitete Materialien zur Bestandsbewertung vorhanden, ohne Veredelung als Sessionquelle zu aktivieren. Tier-/Bosskörperbeute, Angeln und Filetieren bleiben in dieser Version ausgeschlossen. Herkunftsgrenzen und Weltknotenprüfung sind in TECHNIK.md beschrieben.

## Ergänzung 0.6.0

Dibellium 139413 und pulverisiertes Dibellium 139419 als weitere ID-Kandidaten ergänzt (293 insgesamt). Quellen-/Belegkatalog getrennt von Itemidentität unter MATERIALQUELLEN.md und SourceData.lua. Für Rohleder und Materialtypen wird keine spezifische Tierart/Dropchance geraten. Historische Schmuckkorn-/Traitzuordnungen aus der alten HarvestMap-Tabelle werden nicht als sichere heutige Knotenquellen verwendet.

## Abgleich 0.9.1

Seed auf 298 IDs erweitert: Feine Kreide 75370 sowie U51-Reagenzien 224357–224360. Herkunft und ID-Belege in MATERIALQUELLEN.md, vollständige Kandidaten-/Typregelprüfung in HERKUNFT_KATALOGPRUEFUNG.csv und HERKUNFT_TYPREGELN.csv. 4.015 Rezept-IDs unverändert. Ohne gültigen unterstützten ESO-Itemtyp wird kein Kandidat als Sammelmaterial aktiviert.
