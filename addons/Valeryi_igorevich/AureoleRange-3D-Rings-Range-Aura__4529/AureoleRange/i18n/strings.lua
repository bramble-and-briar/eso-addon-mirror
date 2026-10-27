local strings = {
    en = {
        SI_AR_ADDON_NAME            = "AureoleRange",
        SI_AR_ENABLE_RINGS          = "Enable 3D rings",
        SI_AR_RING_SETS_HEADER      = "Ring Sets",
        SI_AR_ACTIVE_RING_SET       = "Active ring set",
        SI_AR_SET_NAME              = "Set name",
        SI_AR_LOAD_SET              = "Load set",
        SI_AR_SAVE_SET              = "Save (overwrite)",
        SI_AR_ADD_TO_SET            = "Add rings to set",
        SI_AR_REMOVE_FROM_SET       = "Remove rings from set",
        SI_AR_NEW_SET               = "New set",
        SI_AR_DELETE_SET            = "Delete set",
        SI_AR_LOAD_SET_TT           = "Enable only rings from this set (disables all others).",
        SI_AR_SAVE_SET_TT           = "Save currently enabled rings to this set (overwrites existing).",
        SI_AR_ADD_TO_SET_TT         = "Add currently enabled rings to this set (union, does not remove existing).",
        SI_AR_REMOVE_FROM_SET_TT    = "Remove currently enabled rings from this set.",
        SI_AR_NEW_SET_TT            = "Create a new set from currently enabled rings.",
        SI_AR_DELETE_SET_TT         = "Delete the currently selected set (cannot delete last set).",
        SI_AR_SETS_NOTE             = "Note: after creating/deleting/renaming sets, use /reloadui to refresh the dropdown list.",
        SI_AR_GLOBAL_HEADER         = "Global",
        SI_AR_HEIGHT_OFFSET         = "Height offset",
        SI_AR_STACKING_STEP         = "Stacking step",
        SI_AR_USE_DEPTH_BUFFER      = "Use depth buffer",
        SI_AR_UPDATE_INTERVAL       = "Update interval (ms)",
        SI_AR_PULSE_GLOBAL          = "Pulse (global)",
        SI_AR_PULSE_PERIOD          = "Pulse period (ms)",
        SI_AR_PULSE_MIN_MUL         = "Pulse min multiplier",
        SI_AR_PULSE_MAX_MUL         = "Pulse max multiplier",
        SI_AR_RINGS_NOTE            = "Enable multiple rings at once. Use Ring Sets to save/load combinations.",
        SI_AR_RING_N_HEADER         = "Ring %d",
        SI_AR_RING_NAME             = "Name",
        SI_AR_RING_ENABLED          = "Enabled",
        SI_AR_RING_RADIUS           = "Radius (meters)",
        SI_AR_RING_COLOR            = "Color",
        SI_AR_RING_INTENSITY        = "Intensity",
        -- НОВОЕ: Хоткей
        SI_BINDING_NAME_AUREOLERANGE_TOGGLE_VISIBILITY = "Toggle Rings Visibility",
    },
    ru = {
        SI_AR_ADDON_NAME            = "AureoleRange",
        SI_AR_ENABLE_RINGS          = "Включить 3D-ореолы",
        SI_AR_RING_SETS_HEADER      = "Наборы колец",
        SI_AR_ACTIVE_RING_SET       = "Активный набор",
        SI_AR_SET_NAME              = "Название набора",
        SI_AR_LOAD_SET              = "Загрузить набор",
        SI_AR_SAVE_SET              = "Сохранить (перезаписать)",
        SI_AR_ADD_TO_SET            = "Добавить кольца в набор",
        SI_AR_REMOVE_FROM_SET       = "Убрать кольца из набора",
        SI_AR_NEW_SET               = "Новый набор",
        SI_AR_DELETE_SET            = "Удалить набор",
        SI_AR_LOAD_SET_TT           = "Включить только кольца из этого набора (остальные выключатся).",
        SI_AR_SAVE_SET_TT           = "Сохранить текущие включённые кольца в этот набор (перезаписать).",
        SI_AR_ADD_TO_SET_TT         = "Добавить текущие включённые кольца в набор (объединение, существующие не удаляются).",
        SI_AR_REMOVE_FROM_SET_TT    = "Убрать текущие включённые кольца из набора.",
        SI_AR_NEW_SET_TT            = "Создать новый набор из текущих включённых колец.",
        SI_AR_DELETE_SET_TT         = "Удалить активный набор (нельзя удалить последний).",
        SI_AR_SETS_NOTE             = "Примечание: после создания/удаления/переименования набора сделай /reloadui.",
        SI_AR_GLOBAL_HEADER         = "Общие",
        SI_AR_HEIGHT_OFFSET         = "Высота над землёй",
        SI_AR_STACKING_STEP         = "Шаг слоёв (против мерцания)",
        SI_AR_USE_DEPTH_BUFFER      = "Использовать depth buffer",
        SI_AR_UPDATE_INTERVAL       = "Интервал обновления (мс)",
        SI_AR_PULSE_GLOBAL          = "Пульсация (глобально)",
        SI_AR_PULSE_PERIOD          = "Период пульсации (мс)",
        SI_AR_PULSE_MIN_MUL         = "Мин. множитель пульсации",
        SI_AR_PULSE_MAX_MUL         = "Макс. множитель пульсации",
        SI_AR_RINGS_NOTE            = "Включай несколько колец одновременно. Наборы: сохранить/загрузить комбинации.",
        SI_AR_RING_N_HEADER         = "Кольцо %d",
        SI_AR_RING_NAME             = "Имя",
        SI_AR_RING_ENABLED          = "Включено",
        SI_AR_RING_RADIUS           = "Радиус (метры)",
        SI_AR_RING_COLOR            = "Цвет",
        SI_AR_RING_INTENSITY        = "Яркость",
        -- НОВОЕ: Хоткей
        SI_BINDING_NAME_AUREOLERANGE_TOGGLE_VISIBILITY = "Вкл/Выкл видимость колец",
    },
}

local lang        = GetCVar("Language.2")
local langStrings = strings[lang] or strings["en"]

for stringId, stringValue in pairs(langStrings) do
    local id = _G[stringId]
    if id then
        SafeAddString(id, stringValue, 1)
    else
        ZO_CreateStringId(stringId, stringValue)
        SafeAddString(_G[stringId], stringValue, 1)
    end
end