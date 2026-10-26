# ALTHI 0.9.4 – Languages / Sprachen

## English

The main addon loads English as fallback and the ESO client language through lang/$(language).lua. Other language files are included for native ESO clients but are not all loaded into memory.

For an interface language different from English or your ESO language, install the optional ALTHI_Language_de, _fr, _es, _ru, _zh or _jp pack. Extract the desired pack ZIP directly into live/AddOns beside ALTHI, enable it in the addon list and reload. OptionalDependsOn loads enabled packs before the main addon. No English pack is needed; installing every pack is unnecessary.

The welcome screen starts in English. Choose an available language and apply. Later use Settings → Choose language. Unavailable languages are dimmed. A stored choice is not erased when its pack is absent: ALTHI temporarily uses the client language or English. Reinstalling/enabling the pack restores the stored choice on the next load. Item names and native tooltips continue to follow your ESO language.

German and English have complete text coverage. French, Spanish, Russian, Simplified Chinese and Japanese are translation drafts requiring native-speaker review. Actual fonts/layout remain client-test work.

## Deutsch

Standardmäßig werden Englisch und die ESO-Spiel­sprache geladen. Ein zusätzliches Sprachpaket ist nur nötig, wenn die ALTHI-Oberfläche eine andere Sprache nutzen soll. Das gewünschte Paket neben dem ALTHI-Ordner unter live/AddOns entpacken, aktivieren und neu laden. Für Deutsch bei deutschem ESO brauchst du kein Zusatzpaket.

Fehlende Sprachen sind in der Auswahl abgeblendet. Eine gespeicherte Wahl bleibt beim fehlenden Paket erhalten; vorübergehend gilt die Spielsprache bzw. Englisch. Nach Installation des passenden Pakets wird die Wahl wieder verwendet. Die ESO-Spiel­sprache wird nicht verändert.

## Translation contributors

Visible category/tab/source labels use neutral IDs. Translate the values in lang/en.lua into the corresponding language file; preserve keys and formatting placeholders such as %s and %d. Language-specific name abbreviations live in that locale's nameAbbreviations table and follow the client/item language.

Files are generated from the development project's translation tables, tools/string_ids.json and tools/name_abbreviations.json; submit corrections so they can be incorporated rather than overwritten by a later build. Optional packs come from the same files. Source-kind/Item IDs and verified localized world-interaction matching names are operational data, not interface translations.

Please send translation suggestions to Roman; do not redistribute modified ALTHI packages without permission. See LICENSE.txt.
