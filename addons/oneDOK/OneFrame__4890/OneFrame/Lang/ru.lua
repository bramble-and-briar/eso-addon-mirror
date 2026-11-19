local strings = {
    [SI_ONEFRAME_DEBUG] = "Debug",
    [SI_ONEFRAME_DEBUG_OFF] = "Отключено",
    [SI_ONEFRAME_DEBUG_SMALL] = "Малая группа",
    [SI_ONEFRAME_DEBUG_LARGE] = "Большая группа",
    [SI_ONEFRAME_DISPLAY] = "Отображение",
    [SI_ONEFRAME_TANK_ROLE] = "Танк",
    [SI_ONEFRAME_HEALER_ROLE] = "Хил",
    [SI_ONEFRAME_DAMAGE_ROLE] = "ДД",
    [SI_ONEFRAME_SHOW_STATISTIC] = "Что показывать",
    [SI_ONEFRAME_NOTHING] = "Ничего",
    [SI_ONEFRAME_LEVEL_CP] = "Уровень / ЧП",
    [SI_ONEFRAME_GROUP_DPS] = "ДПС группы",
    [SI_ONEFRAME_HEALTH_THOUSANDS] = "%.1fк",
    [SI_ONEFRAME_GENERAL] = "Основные",
    [SI_ONEFRAME_SORT] = "Сортировать группу по роли",
    [SI_ONEFRAME_CLASS] = "Показывать значок класса",
    [SI_ONEFRAME_DPS_LABEL] = "ДПС",
    [SI_ONEFRAME_HPS_LABEL] = "ХПС",
    [SI_ONEFRAME_UNAVAILABLE] = "—",
    [SI_ONEFRAME_KILO] = "%.1fk",
    [SI_ONEFRAME_MILLION] = "%.2fm",
    [SI_ONEFRAME_SHIELD_COLOR] = "Цвет щита",
    [SI_ONEFRAME_CONTEXT_MENU] = "Контекстное меню по ПКМ",
    [SI_ONEFRAME_WHISPER] = "Шёпот",
    [SI_ONEFRAME_TRAVEL] = "Телепортироваться к игроку",
    [SI_ONEFRAME_REMOVE] = "Исключить из группы",
    [SI_ONEFRAME_UNSUPPORTED] = "OneFrame: эта версия интерфейса ESO не проверена; расширения фреймов отключены.",
    [SI_ONEFRAME_MISSING] = "OneFrame: стандартные фреймы недоступны; расширения не подключены.",
}

for id, text in pairs(strings) do
    SafeAddString(id, text, 1)
end
