-- Master file and fallback for all other translations
local strings = {
  SI_SHOPPINGLIST_CLEAR = "Clear",
  SI_SHOPPINGLIST_OWN = "Subtract Owned",
  SI_SHOPPINGLIST_PRINT = "Print",
  SI_SHOPPINGLIST_FULL = "Show Full Need",
  SI_SHOPPINGLIST_IMPORT = "Import List",
  SI_FSL_WINDOW_TITLE = "Shopping List",
  SI_FSL_HEADER_ITEM = "ITEM",
  SI_FSL_HEADER_QUANTITY = "QTY",
  SI_FSL_HEADER_MATERIAL = "MATERIAL",
  SI_FSL_HEADER_NEED = "NEED",
  SI_FSL_HEADER_PRICE = "PRICE",
  SI_FSL_IMPORT_TITLE = "Import a furnishing list",
  SI_FSL_IMPORT_HINT = "Paste exported lines from Furniture Catalogue, or item ids. Each new craftable item is added once.",
  SI_FSL_IMPORT_DO = "Import",
  SI_FSL_PRINT_TITLE = "Print shopping list",
  SI_FSL_PRINT_HINT = "Each page fits one chat message or mail. Put a page into it, send it there, then continue with the next page.",
  SI_FSL_PRINT_LINKS = "Item links",
  SI_FSL_PRINT_FURNISHINGS = "List furnishings",
  SI_FSL_PRINT_MAIL = "Pages for mail",
  SI_FSL_PRINT_TO_CHAT = "To chat",
  SI_FSL_PRINT_TO_MAIL = "To mail",

  SI_BINDING_NAME_SL_ADD = "Add to Shopping List",
  SI_BINDING_NAME_SL_TOGGLE = "Toggle Shopping List window",

  FSL_REQUIRES_FC = "[FurnitureShoppingList] This addon requires LibFurnitureCatalogue to function.",
  FSL_DB_NOT_READY = "[FurnitureShoppingList] The furniture catalogue database is not ready yet.",
  FSL_NOT_VALID_ITEM = "[FurnitureShoppingList] This item cannot be crafted.",
  FSL_MAIL_NOT_EMPTY = "[FurnitureShoppingList] The mail already has text. Clear it to put the list there.",
  FSL_PRINT_FOR = "For:",
  FSL_ADD_TO_LIST = "Add to shopping list",
  SI_FSL_QUANTITY_TITLE = "Shopping list",
  SI_FSL_QUANTITY_TEXT = "How many <<1>>?",
  FSL_CHANGE_QUANTITY = "Change quantity",
  FSL_REMOVE_ITEM = "Remove from shopping list",
  FSL_IMPORT_RESULT = "Added <<1>>, duplicates <<2>>, unknown <<3>>, not craftable <<4>>",
}

for stringId, stringValue in pairs(strings) do
  ZO_CreateStringId(stringId, stringValue)
  SafeAddVersion(stringId, 1)
end
