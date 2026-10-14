local AE = AtlasAddon

AE.Translations.ru = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "Дополнение Torfason × Atlas для The Elder Scrolls Online. Открывает карту мира по мере исследования Тамриэля.",
    PREFIX = "|cD8B36A[Atlas]|r ",
    LOADED = "загружен. /atlas help — список команд.",
    HELP = [[
|cD8B36AAtlas – Команды|r
/atlas – открыть настройки Atlas
/atlas help – показать справку
/atlas on – включить Atlas
/atlas off – выключить Atlas
/atlas reveal – полностью открыть текущую карту
/atlas forget – удалить исследование текущей карты
/atlas import – импортировать TrueExploration текущего персонажа
/atlas importall – объединить все найденные профили TrueExploration
/atlas status – показать сведения о текущей карте
/atlas archive – открыть архив карт Atlas
/atlas settings – открыть настройки
/atlas style <1-6> – выбрать стиль неизведанной карты
/atlas radius <1-8> – радиус открытия в клетках
/atlas opacity <10-100> – непрозрачность неизведанной карты в процентах
/ae — короткий вариант команды.

Немецкие команды тоже работают: /atlas hilfe, /atlas an, /atlas aufdecken.
]],
    ENABLED = "Atlas включён.",
    DISABLED = "Atlas выключен.",
    CURRENT_MAP_REVEALED = "Текущая карта полностью открыта.",
    CURRENT_MAP_CLEARED = "Данные исследования текущей карты удалены.",
    NO_MAP = "Не удалось определить подходящую область карты.",
    STATUS = "Карта: %s | открыто: %d / %d клеток (%.1f%%) | стиль: %s",
    STYLE_SET = "Стиль неизведанной карты: %s",
    RADIUS_SET = "Радиус открытия: %d клеток.",
    OPACITY_SET = "Непрозрачность: %d%%.",
    BAD_VALUE = "Недопустимое значение. Введите /atlas help.",
    ARCHIVE_TITLE = "АРХИВ КАРТ",
    ARCHIVE_SUBTITLE = "Все карты, на которых Atlas уже отмечал открытые области.",
    ARCHIVE_COUNT = "Сохранено карт: %d",
    ARCHIVE_EMPTY = "Исследованные карты ещё не сохранены.",
    ARCHIVE_PAGE = "Страница %d / %d",
    ARCHIVE_PREV = "Назад",
    ARCHIVE_NEXT = "Вперёд",
    ARCHIVE_VARIANT_LABEL = "Карта %d · ID %s",
    ARCHIVE_GROUP_EXPAND_HINT = "Нажмите, чтобы показать отдельные карты или уровни.",
    ARCHIVE_GROUP_COLLAPSE_HINT = "Нажмите, чтобы свернуть группу карт.",
    ARCHIVE_FORGET = "Забыть карту",
    ARCHIVE_FORGET_HINT = "Удалить прогресс исследования Atlas только этой карты. Потребуется подтверждение.",
    ARCHIVE_MAP_CLEARED = "Прогресс исследования карты «%s» удалён.",
    ARCHIVE_OPEN_HINT = "Левая кнопка: открыть карту. Правая: открыть полностью или забыть.",
    ARCHIVE_REVEAL = "Открыть карту полностью",
    ARCHIVE_MAP_REVEALED = "Карта «%s» полностью открыта.",
    ARCHIVE_MENU_UNAVAILABLE = "Меню карты недоступно. Данные не изменены.",
    ARCHIVE_OPEN_FAILED = "ESO не разрешает открыть эту карту отсюда. Atlas сохранит её в архиве.",
    ARCHIVE_UNRESOLVED = "Atlas знает эту карту, но пока не нашёл её идентификатор ESO. Связь будет создана при следующем посещении.",
    ARCHIVE_RESOLVING = "Atlas сопоставляет старые карты с идентификаторами ESO в фоновом режиме…",
    ARCHIVE_PATH = "Сохранено как: %s",
    ARCHIVE_UNKNOWN_MAP = "Неизвестная карта",
    IMPORT_NO_TE = "Данные TrueExploration не загружены. Включите TrueExploration вместе с Atlas, перезагрузите интерфейс и повторите импорт.",
    IMPORT_START = "Проверка импорта TrueExploration…",
    IMPORT_DONE = "Импорт завершён: найдено карт: %d, объединено: %d, добавлено клеток: %d, не распознано записей: %d.",
    IMPORT_NONE = "Профиль TrueExploration текущего персонажа не найден. Включите TrueExploration вместе с Atlas и перезагрузите интерфейс.",
    IMPORT_NONE_ALL = "В TE_SavedVars не найдены таблицы карт TrueExploration.",
    IMPORT_ALL_WARNING = "Все найденные профили TrueExploration будут объединены с текущим персонажем.",
    STYLE_NAMES = { "Пергамент", "Светлая бумага", "Тёмный пергамент", "Серый туман", "Уголь", "Глубокий чёрный" },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "Пергамент – старинная карта путешественника с потускневшим компасом и пометками",
        "Светлая бумага – лист картографа с тонкими линиями съёмки и измерениями",
        "Тёмный пергамент – старая морская карта с выцветшими берегами и сгибами",
        "Серый туман – прохладная дымка с едва заметными горизонталями",
        "Уголь – шероховатая бумага с нарисованными путями и старыми отметками",
        "Глубокий чёрный – загадочная ночная карта с едва заметными звёздами и узорами",
    },
    OPTION_LANGUAGE = "Язык",
    OPTION_LANGUAGE_TT = "Выберите язык только для Atlas. Автоматический режим следует языку ESO, не меняя язык игры или других дополнений.",
    LANGUAGE_AUTO = "Автоматически (как в ESO)",
    SETTINGS_VERSION = "Версия %s",
    SETTINGS_TITLE = "Atlas — настройки",
    SETTINGS_GENERAL_HEADER = "ОБЩИЕ",
    SETTINGS_APPEARANCE_HEADER = "ВНЕШНИЙ ВИД",
    SETTINGS_EXPLORATION_HEADER = "ИССЛЕДОВАНИЕ",
    SETTINGS_DEFAULTS = "По умолчанию",
    SETTINGS_DEFAULTS_TT = "Сбросить настройки Atlas, не удаляя сохранённый прогресс исследования.",
    SETTINGS_CLOSE = "Закрыть",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Открыть настройки Atlas",
    SETTINGS_SELECTED_STYLE = "%s: %s",
    OPTION_DESCRIPTION = "Вначале мир на карте скрыт. Области открываются там, где побывал персонаж. Прогресс хранится отдельно для каждого персонажа, а визуальные настройки общие для учётной записи.",
    OPTION_ENABLED = "Включить Atlas",
    OPTION_ENABLED_TT = "Скрывает неисследованные области карты и открывает их по мере путешествия.",
    OPTION_STYLE = "Стиль неизведанной карты — просмотр",
    OPTION_STYLE_TT = "Нажмите на изображение, чтобы просмотреть стили карт и выбрать один из них.",
    OPTION_SELECTED = "Выбрано",
    OPTION_OPACITY = "Непрозрачность неизведанной карты",
    OPTION_OPACITY_TT = "При 100 % исходная карта полностью скрыта. Меньшие значения делают её слегка видимой.",
    OPTION_RADIUS = "Радиус открытия — большие карты",
    OPTION_RADIUS_TT = "Количество клеток сетки 48 × 48, открываемых вокруг персонажа.",
    OPTION_SUBZONES = "Исследовать города, подземелья и малые карты",
    OPTION_SUBZONES_TT = "Если включено, малые карты тоже изначально скрыты.",
    OPTION_SUBRADIUS = "Радиус открытия — малые карты",
    OPTION_SUBRADIUS_TT = "Малые карты часто меньше, поэтому для них можно задать отдельный, более широкий радиус.",
    OPTION_CURRENT_HEADER = "Текущая карта",
    OPTION_REVEAL = "Полностью открыть текущую карту",
    OPTION_REVEAL_TT = "Отмечает отображаемую карту как полностью исследованную.",
    OPTION_CLEAR = "Забыть текущую карту",
    OPTION_CLEAR_TT = "Удаляет только прогресс Atlas для отображаемой карты.",
    CONFIRM_CLEAR_TITLE = "Забыть исследование карты?",
    CONFIRM_CLEAR_TEXT = "Удалить весь прогресс исследования Atlas для карты «<<1>>»? Это действие нельзя отменить.",
    CONFIRM_CLEAR_ACCEPT = "Забыть карту",
    CONFIRM_CLEAR_CANCEL = "Отмена",
    CONFIRM_CLEAR_UNAVAILABLE = "Окно подтверждения недоступно. Данные исследования не удалены.",

    OPTION_IMPORT_HEADER = "Импорт TrueExploration",
    OPTION_IMPORT_DESC = "Импорт только читает данные TrueExploration и не меняет их. Для импорта текущего персонажа включите TrueExploration вместе с Atlas и перезагрузите интерфейс. Atlas поддерживает 31-битный формат сетки 48 × 48 и объединяет пути, различающиеся только регистром букв.",
    OPTION_IMPORT_CURRENT = "Импорт текущего персонажа",
    OPTION_IMPORT_CURRENT_TT = "Рекомендуется: импортировать данные TrueExploration только текущего персонажа.",
    OPTION_IMPORT_ALL = "Объединить все старые профили",
    OPTION_IMPORT_ALL_TT = "Объединяет все найденные карты TrueExploration с текущим персонажем без удаления существующих клеток Atlas.",
    OPTION_COMMANDS_HEADER = "Команды чата",
    OPTION_COMMANDS = "/atlas   /atlas help   /atlas reveal   /atlas forget   /atlas import   /atlas status\n/atlas style 1-6   /atlas radius 1-8   /atlas opacity 10-100",
}
