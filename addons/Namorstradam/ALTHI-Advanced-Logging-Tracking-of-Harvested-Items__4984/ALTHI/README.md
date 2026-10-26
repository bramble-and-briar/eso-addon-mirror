# ALTHI – Advanced Logging & Tracking of Harvested Items

**0.9.4 · Beta candidate / Beta-Kandidat**

Althi & Roman (@namorstradam & @bakaroobanzai)

Developed with AI assistance. Roman directs design and tests ALTHI in ESO; code, documentation and translation drafts were generated and revised with AI assistance. Local checks use a simulated client; no independent human code audit is claimed.

**Language loading in 0.9.4:** English and your ESO client language load by default. For another interface language install its optional ALTHI language pack. See LANGUAGES.md. Existing preferences are retained when a pack is absent.

## Deutsch

ALTHI protokolliert Ressourcenfunde in einer Sammelsession und zeigt Menge, geschätzten Wert und Wert pro aktiver Stunde. Die Materialauswahl erfolgt anhand von ESO-Item-IDs. Namen, Icons und Qualitätsfarben kommen aus dem Spiel.

### Funktionen

- Nur aktuelle Sessionfunde erscheinen als Zeilen. Nach Reset ist die Liste leer; vorhandene Beutelbestände erzeugen keine zusätzlichen Zeilen.
- Run, Pause, Stop und bestätigter Reset; automatischer Start beim gültigen Fund und automatische Fortsetzung optional.
- Separate Handwerksbeutelwerte, sortierbare/ziehbare Spalten, Scrollen, veränderbare Größe und Transparenz.
- Minimieren klappt die Tabelle zusammen; Sammlung und Timer laufen weiter. Die Übersicht wird standardmäßig in ESO-Menüs verborgen; abschaltbar.
- Filterliste mit Suche, Handwerksreitern, Qualitätsfarben, Eigenschafts-/Ranghinweisen und belegten Herkunftsangaben. Kategorieauswahl und Reiter bleiben beim Scrollen erreichbar.
- Preise nach Priorität: eigene Bruttovorgabe → AGS → TTC → ATT → MM → NPC-Basiswert als gekennzeichneter Ersatz. Keine Preisbibliothek erforderlich.
- Optional 7 % Gilden-Verkaufsabzug für die gesamte Preisanzeige. Gespeicherte Preise bleiben brutto. Die separat bezahlte 1-%-Einstellgebühr wird nicht nochmals abgezogen.
- Große Fundmeldungen für Kuta, Ätherischen Staub, beide Nirnkrux-Arten und Aurbischen Bernstein.
- Deutsch/Englisch sowie fünf zusätzliche Übersetzungsentwürfe; Itemnamen folgen der ESO-Spiel­sprache.

### Installation / Update

1. ESO vollständig beenden. Bei einem Update die eigene Datei `SavedVariables/ALTHISavedVariables.lua` sichern.
2. Den Ordner `ALTHI` aus der ZIP in den ESO-Ordner `live/AddOns/` kopieren und vorhandene Addondateien ersetzen. Ergebnis: `live/AddOns/ALTHI/ALTHI.txt`, kein doppelter ALTHI-Unterordner.
3. SavedVariables bei Updates behalten. Materialwahl, Preise, Sprache und Sessiondaten ab Schema 3 bleiben erhalten; eine zuvor laufende Session kommt nach Reload pausiert zurück.
4. ALTHI im Spiel aktivieren. Bei der Erstinstallation im englischen Begrüßungsdialog die Sprache auswählen und bestätigen. Alle unterstützten Materialien sind anfangs ausgewählt.

LibAddonMenu-2.0 ist optional: Mit vorhandenem LAM öffnet „Einstellungen“ direkt die ALTHI-Seite im ESO-Erweiterungsmenü. Ohne LAM stehen eigene Einstellungen zur Verfügung. Die Preisaddons sind ebenfalls optional und müssen nicht gemeinsam installiert sein.

### Bedienung

- `/althi` oder `/althi show`: Ressourcenfenster anzeigen; `/althi settings`: Einstellungen; `/althi catalog`: Filterliste.
- `/althi home`: Ressourcenfenster zurück auf den Bildschirm setzen.
- `/althi testfund`: klar markierte Kuta-Vorschau ohne Mengen-/Timeränderung.
- `/althi debug`: Diagnose umschalten.
- `/althi id <ID>`: Item-ID im Client auflösen und Katalog-/Auswahlstatus ausgeben; nur unterstützte Ressourcen.
- `/althi reset`: Session nach Bestätigung zurücksetzen; Filter und eigene Preise bleiben erhalten.
- Ein unbekannter Unterbefehl (z. B. `/althi help`) zeigt die vollständige Befehlsübersicht.
- `/althi version`: Addon-/ESO-API-Version und gewählte/Client-Sprache für einen Fehlerbericht anzeigen.
- ESO → Steuerung/Tastenbelegung → ALTHI: sechs frei belegbare Aktionen für Fenster, Filterliste, Run/Fortsetzen, Pause, Stop und Reset. Es werden keine Tasten automatisch belegt.
- Eigene Fenster schließen über X oben rechts oder Esc. Esc schließt zunächst das oberste ALTHI-Unterfenster; Bestätigungsdialoge behalten Vorrang. X/Abbrechen im Preisdialog speichert nicht.

Bitte KNOWN_ISSUES.md vor dem Test lesen. Herkunftsangaben sind Informationen, keine zusätzliche Erlaubnis, Post-/Gegner-/Herstellungsbeute in die Session zu zählen.

## English

ALTHI tracks gathered resources in a session and displays quantities, estimated values and value per active hour. Item identity uses ESO IDs; names, icons and quality colors come from the game.

### Highlights

- Session-only rows, a separate crafting-bag snapshot, sorting, adjustable columns, scrolling, resizing and transparency.
- Run/pause/stop and confirmed reset; optional automatic start/resume on a valid harvest.
- Searchable material filters with craft tabs, native trait names, material-passive guidance and documented origins.
- Gross price priority: custom → Awesome Guild Store → Tamriel Trade Centre → Arkadius' Trade Tools → Master Merchant → labelled NPC base-value fallback.
- Optional 7% guild sale deduction throughout the displayed prices. Original/custom prices stay gross; the separately paid 1% listing fee is not deducted again.
- Large rare-resource notifications, six optional keybindings and a compact view that keeps tracking while minimized.
- First-run language selection starts in English. DE/EN are populated; FR/ES/RU/ZH/JP translations are drafts. Item names remain in the ESO client language.

### Install / update

Exit ESO. Back up `SavedVariables/ALTHISavedVariables.lua` when updating. Extract the single `ALTHI` folder to `live/AddOns/`, replacing addon files while keeping SavedVariables. The resulting manifest must be `live/AddOns/ALTHI/ALTHI.txt`. Enable the addon, select a language on first run and apply. Existing saved choices and prices are retained. A running session returns paused after reload.

No mandatory library. With optional LibAddonMenu-2.0, Settings opens ALTHI's native addon-settings panel; without it, standalone settings remain available. All supported materials are selected on a fresh install.

Commands: `/althi` or `/althi show` opens the resource window; `/althi settings` opens settings; `/althi catalog` opens the filter list; `/althi home` returns the window to the screen; `/althi testfund` previews the rare notification; `/althi debug` toggles diagnostics. `/althi id <ID>` resolves an item ID and reports supported resource catalog/selection status. `/althi reset` resets the session after confirmation, keeping filters and manual prices. Unknown subcommands (e.g. `/althi help`) print the complete command list. `/althi version` prints addon/API version and addon/client language for a report. Configure keys under ESO keybindings → ALTHI. Own dialogs use a top-right X and Escape; closing an editor does not save changes.

See KNOWN_ISSUES.md for current scope and testing limits. This is a beta candidate, not a claim of complete loot-source coverage or guaranteed market proceeds. For feedback, include addon/API version, client/UI language, reproduction steps and relevant error text.

## Maintenance 0.9.4 / Wartung

Unique internal namespace ALTHarvestItems, native inventory bag/update-reason filters and neutral localization keys. No experimental fishing features. Existing saved-data file, account/server separation and keybinding action names are retained. Read LICENSE.txt for permissions and AUTHORS.md for credits. Main archive includes all native locale files but loads only English/client language; optional packs are separate downloads.

Eindeutiger interner Name, Ereignisfilter und ausgelagerte Übersetzungstexte. Kein Angeln im Wartungsupdate. Für Deutsch bei deutschem ESO ist kein Sprachpaket nötig. SavedVariables vor dem Update sichern und behalten.
