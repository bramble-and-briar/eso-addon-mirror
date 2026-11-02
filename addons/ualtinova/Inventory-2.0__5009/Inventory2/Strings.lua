InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Loaded first (Inventory2.txt), before anything that wants to read IG.S or IG.Strings at its
-- own file's top level. Keep it that way: a localized label built into a table literal at another
-- file's top level runs before IG.sv exists (OnAddOnLoaded sets it, long after every file has
-- already been parsed once), so IG.S can only promise the client's own language at that point --
-- a languageOverride picked by hand is read correctly only by code that calls IG.S() from inside
-- a function run after OnAddOnLoaded (IG.CreateSettingsPanel and everything under it qualifies).

-- Every language this addon understands, in the order the Settings > About > Language dropdown
-- offers them. code = nil is not a real language: it is "follow the client", the choice a player
-- is on until they pick one by hand (IG.sv.languageOverride stays nil).
IG.LANGUAGES = {
    { code = nil,  label = "Automatic (Game Language)" },
    { code = "en", label = "English" },
    { code = "de", label = "Deutsch" },
    { code = "fr", label = "Francais" },
    -- ESO does not ship an official Russian client, so GetCVar("Language.2") never returns "ru"
    -- on its own -- this entry is reached only by picking it here by hand, never by Automatic.
    { code = "ru", label = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185" }, -- "Русский"
}

-- [language code][string key] = text. Only the handful of strings seen on first opening the
-- settings page are here so far (the About block and the top-level category names) -- the
-- hundreds of individual switch names and tooltips deeper in Settings.lua are still English-only
-- and will move over in later sessions. IG.S falls back to English, and to the key itself, so a
-- key missing from a language (or from this table altogether) is never a Lua error.
IG.Strings = {
    en = {
        ABOUT_PITCH = "The inventory ESO should have shipped with.",
        ABOUT_PITCH_1 = "Sets grouped by where they drop",
        ABOUT_PITCH_2 = "Your Armory loadouts, inside the bag",
        ABOUT_PITCH_3 = "Everything the places you just left dropped",
        ABOUT_PITCH_4 = "House chests, wherever you are",
        ABOUT_HELP_BUG_REPORT = "Help / Bug Report",
        ABOUT_SUPPORT = "Support the Author",
        ABOUT_RESET = "Reset everything",
        LANGUAGE_PREFIX = "",
        LANGUAGE_LABEL = "Language",
        LANGUAGE_RELOAD_TITLE = "Change language",
        LANGUAGE_RELOAD_BODY = "Inventory 2.0 will reload the UI to switch to %s.",
        CATEGORY_GENERAL = "General",
        CATEGORY_VISUALS = "VISUALS",
        CATEGORY_LAYOUT = "LAYOUT",
        CATEGORY_DRAWERS = "DRAWERS",
        CATEGORY_INFO_SHOWN = "INFO SHOWN",
        CATEGORY_GROUPS = "Groups: name, color, order",
        CATEGORY_ITEMS_MOVED = "Items you moved yourself",
        CATEGORY_VENDORS_STATIONS = "Vendors & Crafting Stations",
        CATEGORY_MODULES_HEADER = "Modules",
        CATEGORY_MODULES_ON_OFF = "On / Off",
        CATEGORY_MODULE_SETTINGS = "Module Settings",
        UNDO_NOTHING = "Nothing to undo",
        UNDO_UNDONE = "Undone: %s",
        DECON_CHAT_DONE = "Inventory 2.0: Deconstructed %d %s.",
        DECON_ITEM_SINGULAR = "item",
        DECON_ITEM_PLURAL = "items",
        DECON_PIECE_SINGULAR = "piece",
        DECON_PIECE_PLURAL = "pieces",
        DECON_DIALOG_TITLE = "Deconstruct all of it?",
        DECON_DIALOG_BODY = "Deconstruct %s %s from DECONSTRUCT at this station?\n\nWhat is "
            .. "deconstructed is gone: nothing here can be undone.",
    },
    de = {
        ABOUT_PITCH = "Das Inventar, mit dem ESO eigentlich haette erscheinen sollen.",
        ABOUT_PITCH_1 = "Sets gruppiert danach, wo sie fallen",
        ABOUT_PITCH_2 = "Deine Armory-Ausruestungen, direkt im Beutel",
        ABOUT_PITCH_3 = "Alles, was die Orte, die du gerade verlassen hast, fallen liessen",
        ABOUT_PITCH_4 = "Haustruhen, egal wo du bist",
        ABOUT_HELP_BUG_REPORT = "Hilfe / Fehlerbericht",
        ABOUT_SUPPORT = "Den Autor unterstuetzen",
        ABOUT_RESET = "Alles zuruecksetzen",
        LANGUAGE_PREFIX = "",
        LANGUAGE_LABEL = "Sprache",
        LANGUAGE_RELOAD_TITLE = "Sprache aendern",
        LANGUAGE_RELOAD_BODY = "Inventory 2.0 laedt die Oberflaeche neu, um zu %s zu wechseln.",
        CATEGORY_GENERAL = "Allgemein",
        CATEGORY_VISUALS = "AUSSEHEN",
        CATEGORY_LAYOUT = "LAYOUT",
        CATEGORY_DRAWERS = "SCHUBLADEN",
        CATEGORY_INFO_SHOWN = "ANGEZEIGTE INFOS",
        CATEGORY_GROUPS = "Gruppen: Name, Farbe, Reihenfolge",
        CATEGORY_ITEMS_MOVED = "Selbst verschobene Gegenstaende",
        CATEGORY_VENDORS_STATIONS = "Haendler & Werkstationen",
        CATEGORY_MODULES_HEADER = "Module",
        CATEGORY_MODULES_ON_OFF = "Ein / Aus",
        CATEGORY_MODULE_SETTINGS = "Moduleinstellungen",
        UNDO_NOTHING = "Nichts rueckgaengig zu machen",
        UNDO_UNDONE = "Rueckgaengig gemacht: %s",
        DECON_CHAT_DONE = "Inventory 2.0: %d %s zerlegt.",
        DECON_ITEM_SINGULAR = "Gegenstand",
        DECON_ITEM_PLURAL = "Gegenstaende",
        DECON_PIECE_SINGULAR = "Teil",
        DECON_PIECE_PLURAL = "Teile",
        DECON_DIALOG_TITLE = "Alles zerlegen?",
        DECON_DIALOG_BODY = "%s %s aus ZERLEGEN an dieser Station zerlegen?\n\nWas zerlegt "
            .. "wurde, ist weg: Das hier kann nicht rueckgaengig gemacht werden.",
    },
    fr = {
        ABOUT_PITCH = "L'inventaire qu'ESO aurait du avoir des le depart.",
        ABOUT_PITCH_1 = "Sets groupes selon leur lieu de drop",
        ABOUT_PITCH_2 = "Vos configurations d'Armurerie, directement dans le sac",
        ABOUT_PITCH_3 = "Tout ce que les lieux que vous venez de quitter ont fait tomber",
        ABOUT_PITCH_4 = "Coffres de maison, ou que vous soyez",
        ABOUT_HELP_BUG_REPORT = "Aide / Signaler un bug",
        ABOUT_SUPPORT = "Soutenir l'auteur",
        ABOUT_RESET = "Tout reinitialiser",
        LANGUAGE_PREFIX = "",
        LANGUAGE_LABEL = "Langue",
        LANGUAGE_RELOAD_TITLE = "Changer de langue",
        LANGUAGE_RELOAD_BODY = "Inventory 2.0 va recharger l'interface pour passer en %s.",
        CATEGORY_GENERAL = "General",
        CATEGORY_VISUALS = "VISUEL",
        CATEGORY_LAYOUT = "DISPOSITION",
        CATEGORY_DRAWERS = "TIROIRS",
        CATEGORY_INFO_SHOWN = "INFOS AFFICHEES",
        CATEGORY_GROUPS = "Groupes : nom, couleur, ordre",
        CATEGORY_ITEMS_MOVED = "Objets que vous avez deplaces vous-meme",
        CATEGORY_VENDORS_STATIONS = "Marchands et ateliers d'artisanat",
        CATEGORY_MODULES_HEADER = "Modules",
        CATEGORY_MODULES_ON_OFF = "Active / Desactive",
        CATEGORY_MODULE_SETTINGS = "Parametres des modules",
    },
    -- Russian is not an official ESO client language (see IG.LANGUAGES above): nobody reaches
    -- this table through Automatic, only by picking "Russkiy" on the settings page by hand.
    -- Written as raw UTF-8 Cyrillic rather than escape sequences -- this file is saved UTF-8 like
    -- every other addon file here, and the escape form would be unreadable to edit or proofread.
    ru = {
        ABOUT_PITCH = "Инвентарь, с которым ESO должна была выйти изначально.",
        ABOUT_PITCH_1 = "Сеты, сгруппированные по месту выпадения",
        ABOUT_PITCH_2 = "Ваши комплекты из Оружейной -- прямо в сумке",
        ABOUT_PITCH_3 = "Всё, что выпало там, откуда вы только что ушли",
        ABOUT_PITCH_4 = "Сундуки дома -- где бы вы ни были",
        ABOUT_HELP_BUG_REPORT = "Помощь / Сообщить об ошибке",
        ABOUT_SUPPORT = "Поддержать автора",
        ABOUT_RESET = "Сбросить всё",
        LANGUAGE_PREFIX = "",
        LANGUAGE_LABEL = "Язык",
        LANGUAGE_RELOAD_TITLE = "Сменить язык",
        LANGUAGE_RELOAD_BODY = "Inventory 2.0 перезагрузит интерфейс, чтобы переключиться на %s.",
        CATEGORY_GENERAL = "Общие",
        CATEGORY_VISUALS = "ВИЗУАЛ",
        CATEGORY_LAYOUT = "РАСКЛАДКА",
        CATEGORY_DRAWERS = "ЯЩИКИ",
        CATEGORY_INFO_SHOWN = "ОТОБРАЖАЕМАЯ ИНФОРМАЦИЯ",
        CATEGORY_GROUPS = "Группы: имя, цвет, порядок",
        CATEGORY_ITEMS_MOVED = "Предметы, перемещённые вручную",
        CATEGORY_VENDORS_STATIONS = "Торговцы и ремесленные станции",
        CATEGORY_MODULES_HEADER = "Модули",
        CATEGORY_MODULES_ON_OFF = "Вкл / Выкл",
        CATEGORY_MODULE_SETTINGS = "Настройки модулей",
    },
}

-- The client's own language, exactly as the API reports it (en/de/fr/...). GetCVar("Language.2")
-- is the CVar other addons' own localization fallback chains read this from; there is no
-- documented list of every value it can return, so anything not in IG.Strings simply falls
-- through to English below rather than erroring.
function IG.GameLanguage()
    return GetCVar("Language.2") or "en"
end

-- languageOverride is nil (follow the client) until the player picks one by hand on the settings
-- page. IG.sv does not exist yet at a file's own top level (see the note above), so this answers
-- with the client language even then -- the same safe-before-load default IG.IsEnabled() uses.
function IG.CurrentLanguage()
    if IG.sv and IG.sv.languageOverride then return IG.sv.languageOverride end
    return IG.GameLanguage()
end

function IG.S(key)
    local lang = IG.Strings[IG.CurrentLanguage()]
    local text = lang and lang[key]
    if text then return text end
    text = IG.Strings.en[key]
    if text then return text end
    return key
end
