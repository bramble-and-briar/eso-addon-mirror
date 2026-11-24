-- Translated strings only: a string missing here shows in English (copy it from en.lua to translate it)
local strings = {
  SI_SHOPPINGLIST_CLEAR = "Leeren",
  SI_SHOPPINGLIST_OWN = "Bestand abziehen",
  SI_SHOPPINGLIST_PRINT = "Ausgeben",
  SI_SHOPPINGLIST_FULL = "Gesamtbedarf zeigen",
  SI_SHOPPINGLIST_IMPORT = "Liste importieren",
  SI_FSL_WINDOW_TITLE = "Einkaufsliste",
  SI_FSL_HEADER_ITEM = "GEGENSTAND",
  SI_FSL_HEADER_QUANTITY = "ANZ",
  SI_FSL_HEADER_MATERIAL = "MATERIAL",
  SI_FSL_HEADER_NEED = "BEDARF",
  SI_FSL_HEADER_PRICE = "PREIS",
  SI_FSL_IMPORT_TITLE = "Einrichtungsliste importieren",
  SI_FSL_IMPORT_HINT = "Exportierte Zeilen aus Furniture Catalogue oder Gegenstands-IDs einfügen. Jeder neue herstellbare Gegenstand wird einmal hinzugefügt.",
  SI_FSL_IMPORT_DO = "Importieren",
  SI_FSL_PRINT_TITLE = "Einkaufsliste ausgeben",
  SI_FSL_PRINT_HINT = "Jede Seite passt in eine Chatnachricht oder Post. Seite dort einfügen, absenden, dann mit der nächsten Seite fortfahren.",
  SI_FSL_PRINT_LINKS = "Gegenstandslinks",
  SI_FSL_PRINT_FURNISHINGS = "Einrichtung auflisten",
  SI_FSL_PRINT_MAIL = "Seiten für Post",
  SI_FSL_PRINT_TO_CHAT = "In den Chat",
  SI_FSL_PRINT_TO_MAIL = "In die Post",

  SI_BINDING_NAME_SL_ADD = "Zur Einkaufsliste hinzufügen",
  SI_BINDING_NAME_SL_TOGGLE = "Einkaufsliste ein-/ausblenden",

  FSL_REQUIRES_FC = "[FurnitureShoppingList] Dieses Addon benötigt LibFurnitureCatalogue.",
  FSL_DB_NOT_READY = "[FurnitureShoppingList] Die Datenbank des Möbelkatalogs ist noch nicht bereit.",
  FSL_NOT_VALID_ITEM = "[FurnitureShoppingList] Dieser Gegenstand kann nicht hergestellt werden.",
  FSL_MAIL_NOT_EMPTY = "[FurnitureShoppingList] Die Nachricht enthält bereits Text. Leere sie, um die Liste dort einzufügen.",
  FSL_PRINT_FOR = "Für:",
  FSL_ADD_TO_LIST = "Zur Einkaufsliste hinzufügen",
  SI_FSL_QUANTITY_TITLE = "Einkaufsliste",
  SI_FSL_QUANTITY_TEXT = "Wie viele <<1>>?",
  FSL_CHANGE_QUANTITY = "Anzahl ändern",
  FSL_REMOVE_ITEM = "Von der Einkaufsliste entfernen",
  FSL_IMPORT_RESULT = "Hinzugefügt <<1>>, doppelt <<2>>, unbekannt <<3>>, nicht herstellbar <<4>>",
}

for stringId, stringValue in pairs(strings) do
  ZO_CreateStringId(stringId, stringValue)
  SafeAddVersion(stringId, 1)
end
