-- Canonical English language source for all A.T("English text") calls.
-- This table is intentionally small: English is embedded at call sites and
-- used verbatim when a locale does not provide a translation.
local A = ArclightTaunt
A.translations = A.translations or {}
A.translations.en = {}
-- Compatibility labels for identifiers saved by previous German-based builds.
-- Do not change these keys: existing user selections must survive updates.
A.legacyLabels = {
    ["Allgemeiner Alarm"] = "General alarm",
    ["Countdown-Warnung"] = "Countdown warning",
    ["Duell-Grenzwarnung"] = "Duel boundary warning",
    ["Entdeckt"] = "Detected",
    ["Fähigkeit fehlgeschlagen"] = "Ability failed",
    ["Gesucht"] = "Wanted",
    ["Ohne Textur"] = "No texture",
    ["Prüfung gescheitert"] = "Trial failed",
    ["Questschritt gescheitert"] = "Quest step failed",
    ["Rüstung beschädigt"] = "Armor damaged",
    ["Todesstoß"] = "Killing blow",
    ["Wie Gegnername"] = "Same as enemy name",
}
