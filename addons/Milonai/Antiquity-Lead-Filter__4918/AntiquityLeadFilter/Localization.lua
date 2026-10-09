-- Strings for all ESO client languages. Difficulty and type names come localized from the game.
-- Unknown languages fall back to English.

AntiquityLeadFilter = AntiquityLeadFilter or {}

local STRINGS = {
    en = {
        NO_SELECTION = "No Difficulty",
        ALL_SELECTED = "All Difficulties",
        NUM_SELECTED = "<<1>> Difficulties",

        NOT_FOUND = "Not Found Yet",
        FOUND = "Already Found",
        FOUND_ALL = "All Antiquities",
        FOUND_NONE = "No Antiquities",

        TYPE_OTHER = "Other",
        TYPE_NONE = "No Type",
        TYPE_ALL = "All Types",
        TYPE_COUNT = "<<1>> Types",
    },
    de = {
        NO_SELECTION = "Keine Stufe",
        ALL_SELECTED = "Alle Stufen",
        NUM_SELECTED = "<<1>> Stufen",

        NOT_FOUND = "Noch nicht gefunden",
        FOUND = "Bereits gefunden",
        FOUND_ALL = "Alle Antiquitäten",
        FOUND_NONE = "Keine Antiquitäten",

        TYPE_OTHER = "Sonstiges",
        TYPE_NONE = "Keine Art",
        TYPE_ALL = "Alle Arten",
        TYPE_COUNT = "<<1>> Arten",
    },
    fr = {
        NO_SELECTION = "Aucune difficulté",
        ALL_SELECTED = "Toutes les difficultés",
        NUM_SELECTED = "<<1>> difficultés",

        NOT_FOUND = "Pas encore trouvées",
        FOUND = "Déjà trouvées",
        FOUND_ALL = "Toutes les antiquités",
        FOUND_NONE = "Aucune antiquité",

        TYPE_OTHER = "Autre",
        TYPE_NONE = "Aucun type",
        TYPE_ALL = "Tous les types",
        TYPE_COUNT = "<<1>> types",
    },
    es = {
        NO_SELECTION = "Ninguna dificultad",
        ALL_SELECTED = "Todas las dificultades",
        NUM_SELECTED = "<<1>> dificultades",

        NOT_FOUND = "Aún no encontradas",
        FOUND = "Ya encontradas",
        FOUND_ALL = "Todas las antigüedades",
        FOUND_NONE = "Ninguna antigüedad",

        TYPE_OTHER = "Otros",
        TYPE_NONE = "Ningún tipo",
        TYPE_ALL = "Todos los tipos",
        TYPE_COUNT = "<<1>> tipos",
    },
    ru = {
        NO_SELECTION = "Нет сложности",
        ALL_SELECTED = "Любая сложность",
        NUM_SELECTED = "Сложностей: <<1>>",

        NOT_FOUND = "Ещё не найдены",
        FOUND = "Уже найдены",
        FOUND_ALL = "Все древности",
        FOUND_NONE = "Нет древностей",

        TYPE_OTHER = "Прочее",
        TYPE_NONE = "Нет типа",
        TYPE_ALL = "Все типы",
        TYPE_COUNT = "Типов: <<1>>",
    },
    jp = {
        NO_SELECTION = "難易度なし",
        ALL_SELECTED = "すべての難易度",
        NUM_SELECTED = "<<1>>種類の難易度",

        NOT_FOUND = "未発見",
        FOUND = "発見済み",
        FOUND_ALL = "すべての遺物",
        FOUND_NONE = "遺物なし",

        TYPE_OTHER = "その他",
        TYPE_NONE = "種類なし",
        TYPE_ALL = "すべての種類",
        TYPE_COUNT = "<<1>>種類",
    },
    zh = {
        NO_SELECTION = "无难度",
        ALL_SELECTED = "所有难度",
        NUM_SELECTED = "<<1>>种难度",

        NOT_FOUND = "尚未找到",
        FOUND = "已找到",
        FOUND_ALL = "所有古物",
        FOUND_NONE = "无古物",

        TYPE_OTHER = "其他",
        TYPE_NONE = "无类型",
        TYPE_ALL = "所有类型",
        TYPE_COUNT = "<<1>>种类型",
    },
}

local language = GetCVar("language.2")
AntiquityLeadFilter.L = setmetatable(STRINGS[language] or {}, { __index = STRINGS.en })
