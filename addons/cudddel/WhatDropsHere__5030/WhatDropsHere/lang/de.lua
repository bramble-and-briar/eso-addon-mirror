-- lang/de.lua
-- Deutsche Texte (ueberschreiben die englischen aus lang/en.lua)

local function Override(target, source)
    for key, value in pairs(source) do target[key] = value end
end

Override(WDH_STRINGS, {
    -- Allgemein
    PREFIX              = "|c66CCFF[WDH]|r ",
    DEBUG_PREFIX        = "|c888888[WDH-Debug]|r ",

    -- Debug
    DEBUG_ON            = "|c88FF88[WDH]|r Debug-Modus AN.",
    DEBUG_OFF           = "|c88FF88[WDH]|r Debug-Modus AUS.",
    -- %s = Quelle, %s = Zone, %s = targetType, %s = AoE-Ziel, %s = AoE-Einstellung, %d = Gold, %s = Art
    DEBUG_SESSION       = "%s |cAAAAAA(Zone: %s, targetType=%s, AoE-Ziel=%s, AoE-Einstellung=%s, Gold=%d, Art=%s)|r",
    -- %s = Item, %d = Anzahl, %s = Kategorie
    DEBUG_ITEM          = "  %s x%d |cAAAAAA-> %s|r",
    -- %s = Itemlink, %d = Anzahl
    DEBUG_NO_WINDOW     = "Beute ohne Lootfenster: %s x%d",
    DEBUG_NEW_TARGET    = "Neues Ziel ohne LOOT_CLOSED dazwischen, vorherige Sitzung abgeschlossen.",
    -- %s = Quelle
    DEBUG_REOPEN        = "%s erneut geöffnet, nur bekannte Reste - nicht erneut gezählt.",
    DEBUG_NO_NAME       = "Plünderung ohne Namen der Quelle verworfen:",
    -- %s = Aktion, %s = Ziel
    DEBUG_INTERACT      = "Interaktion: %s - %s",
    -- %s = Itemlink, %d = Anzahl, %s = Quelle des offenen Lootfensters
    DEBUG_DURING_WINDOW = "Beute während Lootfenster, aber nicht in dessen Liste (nicht gezählt): %s x%d (Fenster: %s)",
    DEBUG_AFTER_WINDOW  = "Beute kurz nach Lootfenster, aber nicht in dessen Liste (nicht gezählt): %s x%d",
    DEBUG_TIMEOUT       = "Kein LOOT_CLOSED nach 5 Sek., Sitzung trotzdem gespeichert.",
    DEBUG_LATE          = "|cFFAA00Lootfenster war schon leer (Auto-Loot war schneller), Beute aus dem Eingang gezählt:|r",

    -- Statistik (/wdh)
    -- %s = Quelle, %s = Zone, %d = Plünderungen, %d = Gold
    RECORD_HEADER       = "|cFFFFFF%s|r |cAAAAAA(%s)|r - %dx geplündert, %d Gold",
    RECORD_AOE          = " |cFFAA00[Sammelplünderung]|r",
    RECORD_PICKPOCKET   = " |cFFAA00[Taschendiebstahl]|r",
    RECORD_THEFT        = " |cFF6666[Diebstahl]|r",
    -- %s = Name, %d = Anzahl, %d = Treffer, %d = Plünderungen, %s = Qualitäten
    RECORD_LINE         = "  %s: %d gesamt, in %d von %d (%s)",
    RECORD_ITEM         = "      %s: %d gesamt, in %d von %d (%s)",
    -- %s = Setname, %s = Plätze, %d = Anzahl, %d = Treffer, %d = Plünderungen, %s = Qualitäten
    RECORD_SET          = "  Set %s [%s]: %d gesamt, in %d von %d (%s)",
    RECORD_NONE         = "|cAAAAAA[WDH]|r Keine Daten gefunden.",
    RECORD_NO_LAST      = "|cAAAAAA[WDH]|r Keine letzte Quelle bekannt. Verwendung: /wdh [Name der Quelle], Übersicht: /wdh_zones",

    -- Zonenliste (/wdh_zone)
    ZONE_HEADER         = "|cFFFFFF[WDH] Quellen in %s:|r",
    ZONE_ENTRY          = "  %s: %dx",

    -- Zonenübersicht (/wdh_zones)
    ZONES_HEADER        = "|cFFFFFF[WDH] Gespeicherte Daten:|r",
    -- %s = Zone, %d = Quellen, %d = Plünderungen
    ZONES_ENTRY         = "  %s: %d Quellen, %d Plünderungen",

    -- Anzeige am Fadenkreuz
    -- %d = Plünderungen
    HUD_HEADER          = "|cAAAAAA%dx geplündert|r",
    -- %d = Gold pro Plünderung
    HUD_GOLD            = "|cAAAAAA · Ø %d Gold|r",
    -- %s = Name (farbig), %d = Anzahl, %d = Prozent
    HUD_ITEM            = "%s  |cAAAAAA%dx · %d %%|r",
    -- %s = Setname (farbig), %s = Plätze, %d = Anzahl, %d = Prozent
    HUD_SET             = "%s [%s]  |cAAAAAA%dx · %d %%|r",
    -- %d = Anzahl weiterer Einträge, %s = Name für /wdh
    HUD_MORE            = "|cAAAAAA+%d weitere (/wdh %s)|r",

    -- Einstellungen
    NAMES_SET           = "|c88FF88[WDH]|r Am Fadenkreuz mit Namen ab: %s",
    NAMES_USAGE         = "|cFFFF00[WDH]|r Verwendung: /wdh_names 0-5 (0 = alles mit Namen, 2 = ab grün, 3 = ab blau)",
    SHOW_SET            = "|c88FF88[WDH]|r Anzeige-Schwelle für alle eingeschalteten Arten von Quellen: %s",
    SHOW_USAGE          = "|cFFFF00[WDH]|r Verwendung: /wdh_show 0-5 (0 = alles, 1 = ab weiß, 3 = ab blau)",
    HUD_ON              = "|c88FF88[WDH]|r Anzeige am Fadenkreuz AN.",
    HUD_OFF             = "|c88FF88[WDH]|r Anzeige am Fadenkreuz AUS.",
    HUD_UNITS_ON        = "|c88FF88[WDH]|r Anzeige für lebende Ziele AN.",
    HUD_UNITS_OFF       = "|c88FF88[WDH]|r Anzeige für lebende Ziele AUS.",

    -- Reset
    RESET_CONFIRM       = "ja",
    RESET_USAGE         = "|cFFFF00[WDH]|r Alle Daten löschen: /wdh_reset ja",
    RESET_DONE          = "|c88FF88[WDH]|r Alle Daten gelöscht.",

    -- Sonstiges
    PICKPOCKET_UNKNOWN  = "Unbekanntes Opfer",
    ZONE_ANYWHERE       = "überall",
    SET_UNKNOWN         = "Set #%d",
})

-- Einstellungsmenü (LibAddonMenu)
WDH_STRINGS.MENU_INTRO            = "Merkt sich, was dir jede Beutequelle bisher gegeben hat, und zeigt es am Fadenkreuz an.\n" ..
                                    "|cFFFF88Alle Plünderungen werden immer gespeichert.|r Die Anzeige-Einstellungen bestimmen nur, was am Fadenkreuz erscheint."
WDH_STRINGS.MENU_HUD_HEADER       = "Anzeige am Fadenkreuz"
WDH_STRINGS.MENU_HUD              = "Anzeige einschalten"
WDH_STRINGS.MENU_HUD_TT           = "Zeigt neben dem Fadenkreuz, was die anvisierte Quelle dir bisher gegeben hat. Im Kampf ausgeblendet."
WDH_STRINGS.MENU_MAX_LINES        = "Einträge höchstens"
WDH_STRINGS.MENU_MAX_LINES_TT     = "Weitere Einträge erscheinen als \"+N weitere\". Vollständige Liste mit /wdh <Name>."
WDH_STRINGS.MENU_TYPES_HEADER     = "Anzeige nach Art der Quelle"
WDH_STRINGS.MENU_TYPES_INFO       = "Je Art der Quelle: ab welcher Qualität Einträge am Fadenkreuz erscheinen, oder \"Aus\". Darunter liegende Einträge werden nur ausgeblendet, gespeichert wird immer alles."
WDH_STRINGS.MENU_ENEMIES          = "Feinde"
WDH_STRINGS.MENU_ENEMIES_TT       = "Leichen von Gegnern, Tieren und NPCs."
WDH_STRINGS.MENU_UNITS            = "   auch lebende Feinde"
WDH_STRINGS.MENU_UNITS_TT         = "Zeigt die Statistik schon beim Anvisieren eines lebenden Ziels (außerhalb des Kampfes). Nur eindeutige Zuordnungen, keine Sammelplünderungen."
WDH_STRINGS.MENU_CONTAINERS       = "Truhen und Behälter"
WDH_STRINGS.MENU_CONTAINERS_TT    = "Truhen, Säcke, Fässer, Kisten, Rucksäcke und andere Behälter mit Lootfenster."
WDH_STRINGS.MENU_RESOURCES        = "Rohstoffe"
WDH_STRINGS.MENU_RESOURCES_TT     = "Erz, Holz, Pflanzen, Fasern, Runensteine, Lösungsmittel."
WDH_STRINGS.MENU_OTHER            = "Kleintiere und Sonstiges"
WDH_STRINGS.MENU_OTHER_TT         = "Mit \"Nehmen\" eingesammelte Kleintiere und Gegenstände ohne Lootfenster."
WDH_STRINGS.MENU_THEFT            = "Diebstahl"
WDH_STRINGS.MENU_THEFT_TT         = "Fremde Behälter, Tresore und Gegenstände, die jemandem gehören. Werden getrennt von gleichnamigen freien Behältern gespeichert."
WDH_STRINGS.MENU_DATA_HEADER      = "Datenbank"
WDH_STRINGS.MENU_DATA_INFO        = "Jede Plünderung wird vollständig gespeichert: jedes Item mit Item-ID und Kategorie. Alle Einstellungen oben betreffen nur die Anzeige und lassen sich jederzeit ändern, auch rückwirkend."
WDH_STRINGS.MENU_NAME_QUALITY     = "Mit Namen anzeigen ab Qualität"
WDH_STRINGS.MENU_NAME_QUALITY_TT  = "Darunter erscheinen Items zusammengefasst in ihrer Kategorie (z. B. \"Schmiedematerial\"). Set-Gegenstände, Einrichtung, Stilseiten, Schatzkarten und Spuren immer mit Namen; Trash, Schätze und Ausrüstung ohne Set immer als Kategorie. Vollständige Liste mit /wdh <Name>."
-- %d = Zonen, %d = Quellen, %d = Plünderungen
WDH_STRINGS.MENU_DATA_SUMMARY     = "Gespeichert: %d Zonen, %d Quellen, %d Plünderungen."
WDH_STRINGS.MENU_ZONES            = "Zonen im Chat"
WDH_STRINGS.MENU_ZONES_TT         = "Listet alle Zonen mit gespeicherten Daten im Chat auf (wie /wdh_zones)."
WDH_STRINGS.MENU_RESET            = "Alle Daten löschen"
WDH_STRINGS.MENU_RESET_TT         = "Löscht alle gesammelten Plünderungen. Die Einstellungen bleiben erhalten."
WDH_STRINGS.MENU_RESET_WARNING    = "Alle gesammelten Plünderungen werden unwiderruflich gelöscht."
WDH_STRINGS.MENU_DEV_HEADER       = "Entwicklung"
WDH_STRINGS.MENU_DEBUG            = "Debug-Ausgabe im Chat"
WDH_STRINGS.MENU_DEBUG_TT         = "Zeigt jede Plünderung mit Quelle, Art und Kategorien im Chat. Gilt für alle Charaktere."

-- Einstellungen je Charakter
-- %s = Name des Charakters
WDH_STRINGS.MENU_CHAR_INFO        = "Die Anzeige-Einstellungen gelten nur für |cFFFFFF%s|r. Jeder Charakter hat seine eigenen."
WDH_STRINGS.MENU_SHOW_OFF         = "Aus"
WDH_STRINGS.MENU_COPY_HEADER      = "Einstellungen anderer Charaktere"
WDH_STRINGS.MENU_COPY_INFO        = "Übernimmt alle Anzeige-Einstellungen eines anderen Charakters für diesen Charakter."
WDH_STRINGS.MENU_COPY_FROM        = "Kopieren von"
WDH_STRINGS.MENU_COPY_FROM_TT     = "Ein Charakter erscheint hier, sobald er einmal mit What Drops Here? eingeloggt war."
WDH_STRINGS.MENU_COPY_NONE        = "(keine anderen Charaktere)"
WDH_STRINGS.MENU_COPY             = "Übernehmen"
WDH_STRINGS.MENU_COPY_TT          = "Ersetzt die Anzeige-Einstellungen dieses Charakters durch die des gewählten Charakters."
WDH_STRINGS.MENU_COPY_WARNING     = "Die Anzeige-Einstellungen dieses Charakters werden überschrieben."
-- %s = Name des Charakters
WDH_STRINGS.COPY_DONE             = "|c88FF88[WDH]|r Anzeige-Einstellungen von %s übernommen."

-- Plätze für Ausrüstung
Override(WDH_SLOT_NAMES, {
    armor   = "Rüstung",
    weapon  = "Waffe",
    jewelry = "Schmuck",
    -- Neuer Platz ab API 101052; Name aus dem Spiel, weil die deutsche Bezeichnung noch nicht feststeht
    trinket = ITEMTYPE_TRINKET and GetString("SI_ITEMTYPE", ITEMTYPE_TRINKET) or "Trinket",
})

-- Anzeigenamen der Kategorien (Schlüssel aus WDH_Categories.lua)
Override(WDH_CAT_NAMES, {
    SET             = "Set-Ausrüstung",
    GEAR_ARMOR      = "Rüstung ohne Set",
    GEAR_WEAPON     = "Waffe ohne Set",
    GEAR_JEWELRY    = "Schmuck ohne Set",
    GEAR_COMPANION  = "Gefährten-Ausrüstung",
    TREASURE        = "Schätze",
    TRASH           = "Trash",
    FURNISHING      = "Einrichtung",
    FURNISHING_PLAN = "Bauplan",
    MOTIF           = "Stilbuch",
    STYLE_PAGE      = "Stilseite",
    RECIPE          = "Rezept",
    COLLECTIBLE     = "Sammlungsstück",
    TREASURE_MAP    = "Schatzkarte",
    SURVEY          = "Vermessungsbericht",
    TROPHY          = "Trophäe",
    CONTAINER       = "Behälter",
    MAT_SMITH       = "Schmiedematerial",
    MAT_CLOTH       = "Schneidermaterial (Stoff)",
    MAT_LEATHER     = "Schneidermaterial (Leder)",
    MAT_WOOD        = "Schreinermaterial",
    MAT_JEWELRY     = "Schmuckmaterial",
    MAT_STYLE       = "Stilmaterial",
    MAT_TRAIT       = "Eigenschaftsmaterial",
    MAT_FURNISHING  = "Einrichtungsmaterial",
    TEMPER          = "Härtungsmittel",
    REAGENT         = "Reagenz",
    SOLVENT         = "Lösungsmittel",
    INGREDIENT      = "Zutat",
    RUNE_ASPECT     = "Aspektrune",
    RUNE_ESSENCE    = "Essenzrune",
    RUNE_POTENCY    = "Machtrune",
    LURE            = "Köder",
    CONSUMABLE      = "Verbrauchsgut",
    GLYPH           = "Glyphe",
    SOUL_GEM        = "Seelenstein",
    TOOL            = "Werkzeug",
    LEAD            = "Spur",
    TRINKET         = ITEMTYPE_TRINKET and GetString("SI_ITEMTYPE", ITEMTYPE_TRINKET) or "Trinket",
    NO_ITEM         = "Sonstiges (kein Item)",
    MISC            = "Sonstiges",
})
