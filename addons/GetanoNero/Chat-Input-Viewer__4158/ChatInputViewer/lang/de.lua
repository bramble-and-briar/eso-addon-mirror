local localization_strings = {
  CHATIV_WARNING_CAPTION = "Bitte beachten:",
  CHATIV_WARNING_TEXT = "Das Feld für die Anzeige der Chateingabe wird unterhalb des Chatfensters angezeigt.\nDas Chatfenster reicht normalerweise bis zum unteren Rand des Bildschirms.\nWird das Fenster beim sichtbar Machen des AddOns nicht automatisch nach oben verschoben, muss der untere Rand des Chatfensters manuell nach oben geschoben werden.",
  CHATIV_VISIBLE = "Sichtbarkeit",
  CHATIV_VISIBLE_TOOLTIP = "Blendet das Fenster ein oder aus.",
  CHATIV_MINIMISED = "Reduzierte Fenstergröße",
  CHATIV_MINIMISED_TOOLTIP = "Zeigt das Fenster auf eine Zeile minimiert an.",
  CHATIV_FONTSIZE = "Fontgröße",
  CHATIV_FONTSIZE_TOOLTIP = "Die Größe der Buchstaben im Fenster des Viewers. Eine Änderung dieses Werts ändert auch die Höhe des Viewer-Fensters.",
  CHATIV_WINDOWMODE = "Fenstermodus",
  CHATIV_WINDOWMODE_TOOLTIP = "Legt fest, wie die Breite des Fensters bestimmt wird.",
  CHATIV_WINDOWMODE_VAL1 = "Breite des Chat-Fensters",
  CHATIV_WINDOWMODE_VAL2 = "Feste Breite",
  CHATIV_WINDOWWIDTH = "Fensterbreite",
  CHATIV_WINDOWWIDTH_TOOLTIP = "Die Breite des Viewerfensters.",
  CHATIV_NROFLINES = "Anzahl der Textzeilen",
  CHATIV_NROFLINES_TOOLTIP = "Die Anzahl der Textzeilen, die im Viewer angezeigt werden können. Eine Änderung dieses Werts ändert die Höhe des Viewer-Fensters.",
  CHATIV_KEYBINDING_TUGGLE = "Das Fenster ein- oder ausblenden",
  CHATIV_UPDATEMESSAGE_01 = "== Chat Input Viewer - neue Funktionen in Version 1.3.0 ==",
  CHATIV_UPDATEMESSAGE_02 = " * Neuer Anzeigemodus 'Minimiert'",
  CHATIV_UPDATEMESSAGE_03 = " * Chat Kommandos /civshow, /civhide und /civmini",
  CHATIV_UPDATEMESSAGE_04 = " * Konfigurierbares Tastaturkommando zum Wechseln des Modus.",
  CHATIV_UPDATEMESSAGE_05 = "Details findet ihr in der AddOn-Beschreibung auf USOUI: https://www.esoui.com/downloads/info4158-ChatInputViewer.html",
  CHATIV_UPDATEMESSAGE_06 = "(Die Meldung wird noch %s Mal nach einem Login angezeigt werden.)",
}

for stringId, stringValue in pairs(localization_strings) do
  SafeAddString(_G[stringId], stringValue, 2)
end
