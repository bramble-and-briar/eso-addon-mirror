# Known Vendor Filter

**Version:** 1.0.4  
**Autor:** Ypselon  
**Plattform:** ESO für PC/Mac, Tastatur- und Mausoberfläche  
**ESO-API im Add-on:** 101051

Known Vendor Filter blendet auf Wunsch bereits bekannte oder gesammelte Gegenstände aus. So findest du unbekannte Rezepte und andere Sammlungsstücke leichter.

## Wo funktioniert der Filter?

- Beim **Einkaufen bei normalen Händlern**.
- Beim **Herausnehmen aus der persönlichen Bank**, einschließlich ESO-Plus-Bankplatz.

Für Händler und Bank gibt es jeweils einen eigenen Ein-/Ausschalter. Beim Einlagern in die Bank wird die Liste nicht gefiltert. Gildenhändler, Gildenbank, Hausbank und die Gamepad-Oberfläche werden in dieser Version nicht unterstützt.

## Was kann ausgeblendet werden?

Im Optionsmenü kannst du die folgenden Kategorien einzeln auswählen:

- Rezepte für Essen und Getränke
- Einrichtungspläne
- Handwerksstile
- Monturstilseiten
- Schriftlehre: Grimoires und Skripte
- Sammlungsstücke und Runenkisten
- Bereits im Setbuch gesammelte Setgegenstände

Ein Häkchen bedeutet, dass **bekannte** Gegenstände dieser Kategorie ausgeblendet werden, sobald der jeweilige Filter eingeschaltet ist. Unbekannte Gegenstände bleiben sichtbar. Gegenstände, deren Status nicht eindeutig erkannt werden kann, bleiben ebenfalls sichtbar.

Bei Rezepten und Handwerksstilen zählt der Wissensstand des aktuell gespielten Charakters. Beachte bei Setgegenständen: Ein Gegenstand kann im Setbuch bereits gesammelt sein, auch wenn du ihn für eine andere Eigenschaft oder zum Ausrüsten kaufen oder aus der Bank nehmen möchtest. Du kannst die Kategorie oder den Filter jederzeit ausschalten.

## Bedienung

1. Öffne einen normalen Händler oder wähle bei der persönlichen Bank **Herausnehmen**.
2. Klicke auf **„Bekannte ausblenden: AUS“**, um den jeweiligen Filter einzuschalten. Der Knopf zeigt danach **„AN“**.
3. Über **„Filteroptionen“** wählst du die Kategorien aus. Diese Auswahl gilt gemeinsam für Händler und Bank; die Filter selbst lassen sich einzeln einschalten.

Die Filter sind nach der Installation zunächst ausgeschaltet. Schalter und Kategorieauswahl werden gespeichert.

## Installation

1. Entpacke die ZIP-Datei in deinen ESO-Add-on-Ordner. Unter Windows liegt dieser normalerweise hier:

   ```text
   Dokumente\Elder Scrolls Online\live\AddOns\
   ```

2. Achte darauf, dass die Manifestdatei direkt in folgendem Ordner liegt:

   ```text
   AddOns\KnownVendorFilter\KnownVendorFilter.txt
   ```

3. Aktiviere **Known Vendor Filter** in der ESO-Add-on-Liste. Falls ESO schon läuft, lade die Oberfläche mit `/reloadui` neu. Sollte das neue Add-on noch nicht in der Liste erscheinen, starte das Spiel neu.

## Benötigte und optionale Bibliotheken

**Es sind keine Bibliotheken erforderlich.** Der Filter und sein eigenes Optionsfenster funktionieren eigenständig.

Diese Bibliotheken werden optional unterstützt und können separat über Minion oder ESOUI installiert werden:

- [LibFilters-3.0](https://www.esoui.com/downloads/info2343.html): Unterstützt das Zusammenspiel mit anderen Add-ons, die dieselben Händler- oder Banklisten filtern.
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html): Zeigt die Optionen zusätzlich unter **Einstellungen → Erweiterungen → Known Vendor Filter** an. Ohne die Bibliothek bleiben sie über den Knopf **„Filteroptionen“** erreichbar.

## Sprachen

Das Add-on erkennt die Sprache des ESO-Clients automatisch. Enthalten sind Deutsch, Englisch, Französisch, Spanisch, Russisch, Japanisch und vereinfachtes Chinesisch. Bei einem unbekannten Sprachcode wird Englisch verwendet.
