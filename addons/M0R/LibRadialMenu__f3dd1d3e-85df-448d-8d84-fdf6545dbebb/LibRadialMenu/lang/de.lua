local LIBRADIAL_WHEEL = HOTBAR_CATEGORY_MAX_VALUE + 100
local libradialwheelcategory = string.format("SI_HOTBARCATEGORY%d",LIBRADIAL_WHEEL)
SafeAddString(_G[libradialwheelcategory], "AddOn Einträge", 1)
local quickSlotWheelStr = GetString(SI_BINDING_NAME_GAMEPAD_UI_SHORTCUT_QUICK_SLOTS)

SafeAddString(SI_LIBRADIALMENU_ASSIGN_TITLE, "Eintrag %d zuweisen", 1)
SafeAddString(SI_LIBRADIALMENU_ASSIGN_SLOT, "Eintrag %d: ", 1)
SafeAddString(SI_LIBRADIALMENU_ASSIGN_NOTHING, "Diesem Eintrag wurde noch nichts zugewiesen!", 1)
SafeAddString(SI_LIBRADIALMENU_NUM_SLOTS, "Anzahl Einträge", 1)
SafeAddString(SI_LIBRADIALMENU_NUM_SLOTS_TOOLTIP, "Lege die Anzahl der Einträge im Schnellzugriff Rad \'" .. GetString(_G[libradialwheelcategory]) .. "\' fest.", 1)
SafeAddString(SI_LIBRADIALMENU_REFRESH_MENU, "Einstellungen aktualisieren", 1)
SafeAddString(SI_LIBRADIALMENU_REFRESH_MENU_TOOLTIP, "Nachdem die Anzahl der Einträge verändert wurde (welche auf dem Schnellzugriff erscheinen), drücke bitte diesen Knopf um die unten zugewiesenen Einträge zu aktualisieren!", 1)
SafeAddString(SI_LIBRADIALMENU_ASSIGN_SLOTS_HEADER, "Eintrag zuweisen", 1)
SafeAddString(SI_LIBRADIALMENU_OPEN_SETTINGS, "Einstellungen öffnen", 1)
SafeAddString(SI_LIBRADIALMENU_OPEN_SETTINGS_TOOLTIP, "Öffnet die Einstellungsseite für LibRadialMenu", 1)
SafeAddString(SI_LIBRADIALMENU_WHEEL_INDEX, quickSlotWheelStr .. " Rad Position", 1)
SafeAddString(SI_LIBRADIALMENU_WHEEL_INDEX_TOOLTIP, "Ändert an welcher Position das LibRadialMenu Rad im " .. quickSlotWheelStr .. " platziert wird.\n1 bedeutet z.B., dass es beim Öffnen des Schnellzugriffes zuerst geöffnet wird.\n\nMit 0 wird das zusätzliche LRM Rad deaktiviert.", 1)

-- SafeAddString(SI_LIBRADIALMENU_TRANSLATEDBY, "", 1) -- translated by Baertram