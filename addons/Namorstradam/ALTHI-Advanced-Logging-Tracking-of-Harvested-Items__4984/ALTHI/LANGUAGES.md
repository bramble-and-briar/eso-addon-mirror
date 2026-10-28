# ALTHI 1.0.0 – Languages / Sprachen

All seven interface languages are included in the main addon. No separate language packs are needed. German/English have complete text coverage; French, Spanish, Russian, Simplified Chinese and Japanese are drafts requiring native-speaker review.

## Using the addon

On first launch the welcome screen starts in English. Select a language and apply. Later open Settings → Choose language. You can choose any included language independently of your ESO language, or Automatic (ESO language). A change is saved only on Apply and reload; previews and Cancel do not change your saved preference.

Item names, native item tooltips and name abbreviations follow the ESO client language. The addon never changes the game language, sounds or videos. Existing saved choices survive the update.

## Upgrading from 0.9.4

Update the main ALTHI addon first. Then disable/uninstall the old ALTHI_Language_fr, _es, _ru, _zh or _jp addons; an optional _de installation is also unnecessary. Keep the main ALTHI folder and SavedVariables. Old packs are not deleted automatically and their obsolete translation table does not drive the new interface.

## Deutsch

Alle sieben Oberflächensprachen sind jetzt im Hauptaddon enthalten. Keine Zusatzpakete nötig. Eine Sprache in den ALTHI-Einstellungen wählen oder Automatisch (ESO-Sprache) verwenden. Erst Übernehmen und Neuladen speichert die Wahl; Vorschau und Abbrechen ändern sie nicht. Itemnamen bleiben in der ESO-Spiel­sprache.

Zuerst ALTHI aktualisieren, dann die alten ALTHI_Language_…-Zusatzaddons deaktivieren/deinstallieren. Den Hauptordner ALTHI und SavedVariables behalten. Filter, Preise, Sprache und Sessiondaten bleiben erhalten.

## For translation contributors

Native ESO localization follows https://wiki.esoui.com/How_to_add_localization_support :

- lang/default.lua creates English fallback identifiers with ZO_CreateStringId, using the addon-owned ALTHARVESTITEMS_ prefix (not the reserved SI_ prefix).
- lang/$(language).lua overrides translated strings with SafeAddString(identifier, text, 1).
- Normal interface output uses GetString. Missing native entries keep the English fallback.
- en.lua intentionally contains no strings: English defaults must not be registered twice.

A new native translation can be supplied as lang/<language-code>.lua without changing a core language list. For example:

```lua
SafeAddString(ALTHARVESTITEMS_NAME, "Nazwa", 1)
SafeAddString(ALTHARVESTITEMS_QUANTITY, "Ilość", 1)
```

With Automatic (ESO language), those values are used for a matching client language. Preserve identifiers and format placeholders (%s, %d). Native item/source-kind IDs and verified interaction-name matching are operational data, not interface text.

The established independent ALTHI language picker requires additional bundled data. LanguageChoices.lua contains generated factories: an extra language table is built only when chosen or previewed, and inactive languages do not register their strings. Explicit independent choices apply to the addon-owned IDs at version 2; they do not change ESO's own strings. A preview does not register new runtime values.

The development generator builds native files and manual-choice data from the same translation source. Please submit corrections so both views stay consistent. See LICENSE.txt for redistribution conditions. The existing SI_BINDING_NAME_ALTHI_* identifiers remain because ESO's keybinding system requires those names.
