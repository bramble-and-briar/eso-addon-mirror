local strings = {
    [SI_ONEFRAME_DEBUG] = "Debug",
    [SI_ONEFRAME_DEBUG_OFF] = "Deaktiviert",
    [SI_ONEFRAME_DEBUG_SMALL] = "Kleine Gruppe",
    [SI_ONEFRAME_DEBUG_LARGE] = "Große Gruppe",
    [SI_ONEFRAME_DISPLAY] = "Anzeige",
    [SI_ONEFRAME_TANK_ROLE] = "Tank",
    [SI_ONEFRAME_HEALER_ROLE] = "Heiler",
    [SI_ONEFRAME_DAMAGE_ROLE] = "Schadensausteiler",
    [SI_ONEFRAME_SHOW_STATISTIC] = "Statistik anzeigen",
    [SI_ONEFRAME_NOTHING] = "Keine",
    [SI_ONEFRAME_LEVEL_CP] = "Stufe / Championpunkte",
    [SI_ONEFRAME_GROUP_DPS] = "Gruppen-DPS",
    [SI_ONEFRAME_HEALTH_THOUSANDS] = "%.1fk",
    [SI_ONEFRAME_GENERAL] = "Allgemein",
    [SI_ONEFRAME_SORT] = "Gruppe nach Rolle sortieren",
    [SI_ONEFRAME_CLASS] = "Klassensymbol anzeigen",
    [SI_ONEFRAME_DPS_LABEL] = "DPS",
    [SI_ONEFRAME_HPS_LABEL] = "HPS",
    [SI_ONEFRAME_UNAVAILABLE] = "—",
    [SI_ONEFRAME_KILO] = "%.1fk",
    [SI_ONEFRAME_MILLION] = "%.2fm",
    [SI_ONEFRAME_SHIELD_COLOR] = "Schildfarbe",
    [SI_ONEFRAME_CONTEXT_MENU] = "Kontextmenü per Rechtsklick",
    [SI_ONEFRAME_WHISPER] = "Anflüstern",
    [SI_ONEFRAME_TRAVEL] = "Zu Spieler reisen",
    [SI_ONEFRAME_REMOVE] = "Aus Gruppe entfernen",
    [SI_ONEFRAME_UNSUPPORTED] = "OneFrame: Diese ESO-Oberflächenversion wurde nicht geprüft; die Rahmenerweiterungen sind deaktiviert.",
    [SI_ONEFRAME_MISSING] = "OneFrame: Die Standardrahmen werden nicht unterstützt; die Erweiterungen wurden nicht eingebunden.",
}

for id, text in pairs(strings) do
    SafeAddString(id, text, 1)
end
