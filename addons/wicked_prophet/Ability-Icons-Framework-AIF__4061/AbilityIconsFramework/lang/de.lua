local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "Schluck des Heldentums",
    HP_POTION_NAME_10             = "Tinktur des Heldentums",
    HP_POTION_NAME_20             = "Trunk des Heldentums",
    HP_POTION_NAME_30             = "Trank des Heldentums",
    HP_POTION_NAME_40             = "Lösung des Heldentums",
    HP_POTION_NAME_CP10           = "Elixier des Heldentums",
    HP_POTION_NAME_CP50           = "Panazee des Heldentums",
    HP_POTION_NAME_CP100          = "Destillat des Heldentums",
    HP_POTION_NAME_CP150          = "Essenz des Heldentums",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "Framework zur Anpassung von Fähigkeits-Icons und Kampf-UI.",
    SI_AIF_SETTINGS_HEADER        = "Einstellungen",
    SI_AIF_GLOBAL_SETTINGS        = "Dieselben Einstellungen für alle Charaktere verwenden",
    SI_AIF_SCRIBING_ICONS         = "Benutzerdefinierte Schriftlehre-Icons verwenden",
    SI_AIF_BASE_GAME_ICONS        = "Grundspiel-Icons ersetzen",
    SI_AIF_HEROISM_POTIONS        = "Icons für Heldentum-Tränke aktivieren",
    SI_AIF_RESOLUTION             = "Auflösung der Grundspiel-Icons",
    SI_AIF_RESOLUTION_TIP         = "Texturauflösung für Standard-Icons",
    SI_AIF_RESOLUTION_WARN        = "Erfordert /reloadui, um Änderungen anzuwenden",
    SI_AIF_RELOAD_UI              = "UI neu laden",
    SI_AIF_PACK_ORDER_SUBMENU     = "Ladereihenfolge der Icon-Pakete",
    SI_AIF_PACK_PRIORITY          = "Priorität der Icon-Pakete",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "Verfügbare Befehle:",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <Platz 3-8> [1 für Hintergrund-Leiste]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <Platz 3-8> [1 für Hintergrund-Leiste]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (gespeicherte Variablen prüfen)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (Einstellungsmenü öffnen)",
    SI_AIF_SLOT_EMPTY             = "Platz <<1>> (Leiste <<2>>) ist leer.",
    SI_AIF_SLOT_REDIRECT_NONE     = "  Umgeleitet zu: (keine)",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
