if GetCVar("Language.2") ~= "de" then
    return
end

Tooltipruhe = Tooltipruhe or {}
local TR = Tooltipruhe
TR.L = TR.L or {}
local L = TR.L

L.ADDON_DESCRIPTION = "Ein Torfason × Atlas Addon für The Elder Scrolls Online. Steuert Position und Sichtbarkeit der Item-Tooltips im Tastaturmodus."
L.SETTINGS_TITLE = "Tooltipruhe"
L.SETTINGS_SUBTITLE = "Sichtbarkeit und Position der Item-Tooltips"
L.SETTINGS_DESCRIPTION = "Steuert ESOs Item-Tooltips im Tastaturmodus, ohne deren Inhalte zu ersetzen."
L.SECTION_DISPLAY = "ANZEIGE"
L.SECTION_POSITION = "POSITIONIERUNG"
L.SECTION_PRESETS = "POSITIONSVORLAGEN"
L.SECTION_KEYS = "TASTENBELEGUNG"
L.NORMAL_BEHAVIOR = "Normales ESO-Tooltipverhalten"
L.NORMAL_BEHAVIOR_TT = "An: Item-Tooltips folgen ESOs normalem Verhalten und erscheinen beim Überfahren eines Gegenstands. Aus: Die erfassten Item-Tooltips bleiben standardmäßig verborgen und können vorübergehend per Tastenbelegung eingeblendet werden."
L.CHAT_MESSAGES = "Chatmeldungen anzeigen"
L.CHAT_MESSAGES_TT = "Zeigt Statusmeldungen von Tooltipruhe im Chat an. Wichtige Warnungen bleiben davon unabhängig möglich."
L.USE_POSITIONING = "Tooltipruhe-Positionierung verwenden"
L.USE_POSITIONING_TT = "An: Tooltipruhe steuert und speichert die Positionen von ItemTooltip und beiden Vergleichs-Tooltips. Aus: ESO oder andere Addons dürfen die Positionen verwalten; die Sichtbarkeitssteuerung von Tooltipruhe bleibt aktiv. Das ist besonders für die HUD-Änderungen aus Update 51 gedacht."
L.EDIT_POSITIONS = "Positionen bearbeiten"
L.EDIT_POSITIONS_TT = "Zeigt drei verschiebbare Platzhalter. Sie werden mit der linken Maustaste bewegt. Beim Schließen der Einstellungen endet der Bearbeitungsmodus und die Positionen werden gespeichert."
L.RESET_POSITIONS = "Positionen zurücksetzen"
L.RESET_POSITIONS_TT = "Stellt die ursprünglichen Tooltipruhe-Positionen wieder her."
L.PRESET_TOP_LEFT = "Oben links"
L.PRESET_TOP_RIGHT = "Oben rechts"
L.PRESET_BOTTOM_LEFT = "Unten links"
L.PRESET_BOTTOM_RIGHT = "Unten rechts"
L.PRESETS_HELP = "Die Vorlagen ordnen alle drei Tooltip-Fenster nebeneinander an und führen sie von der gewählten Ecke zur Bildschirmmitte."
L.KEYS_HELP = "Unter Steuerung → Tastenbelegung → Tooltipruhe findest Du Tasten für die vorübergehende Sichtbarkeit und den Positionsmodus."
L.DEFAULTS = "Standardwerte"
L.CLOSE = "Schließen"
L.GEAR_TOOLTIP = "Tooltipruhe-Einstellungen öffnen"
L.SETTINGS_VERSION = "Version 2.0.0"

L.MARKER_ITEM = "Item-Tooltip"
L.MARKER_COMPARE1 = "Vergleich 1"
L.MARKER_COMPARE2 = "Vergleich 2"
L.MARKER_HINT = "Mit linker Maustaste verschieben"

L.MSG_SHOWN = "Item-Tooltips eingeblendet."
L.MSG_HIDDEN = "Item-Tooltips ausgeblendet."
L.MSG_EDIT_ON = "Positionsmodus aktiv. Alle drei Platzhalter können mit der linken Maustaste verschoben werden."
L.MSG_EDIT_OFF = "Positionsmodus beendet. Positionen gespeichert."
L.MSG_RESET_POSITIONS = "Tooltip-Positionen wurden zurückgesetzt."
L.MSG_PRESET_APPLIED = "Positionsvorlage '%s' angewendet."
L.MSG_POSITIONING_DISABLED = "Die Tooltipruhe-Positionierung ist ausgeschaltet. Aktiviere sie in den Einstellungen, um Positionen zu bearbeiten."
L.MSG_POSITIONING_ON = "Tooltipruhe-Positionierung aktiviert."
L.MSG_POSITIONING_OFF = "Tooltipruhe-Positionierung deaktiviert. ESO darf die Tooltip-Positionen ab der nächsten Anzeige wieder selbst setzen."
L.MSG_COMMANDS = "Befehle: /tooltipruhe, /tooltipruhe toggle, /tooltipruhe edit, /tooltipruhe reset, /tooltipruhe on, /tooltipruhe off"

L.BIND_TOGGLE_VISIBILITY = "Item-Tooltips vorübergehend ein-/ausblenden"
L.BIND_TOGGLE_EDIT = "Tooltip-Positionen bearbeiten"

L.DEFAULTS_TT = "Stellt die Einstellungen von Tooltipruhe auf die Standardwerte zurück. Gespeicherte Tooltip-Positionen bleiben erhalten."
L.DEFAULTS_DONE = "Einstellungen auf Standardwerte zurückgesetzt."
L.EDIT_POSITIONS_LABEL = "Tooltip-Positionen"
L.RESET_POSITIONS_LABEL = "Gespeicherte Tooltip-Positionen"
L.PRESET_TOP_LEFT_LABEL = "Tooltips von der oberen linken Ecke anordnen"
L.PRESET_TOP_RIGHT_LABEL = "Tooltips von der oberen rechten Ecke anordnen"
L.PRESET_BOTTOM_LEFT_LABEL = "Tooltips von der unteren linken Ecke anordnen"
L.PRESET_BOTTOM_RIGHT_LABEL = "Tooltips von der unteren rechten Ecke anordnen"
