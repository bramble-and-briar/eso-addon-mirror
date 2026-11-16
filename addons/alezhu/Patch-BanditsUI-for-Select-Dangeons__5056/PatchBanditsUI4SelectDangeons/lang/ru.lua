-- PatchBanditsUI4SelectDangeons Localization: Russian

local strings = {
    SI_PATCHBUI_UNCOMPLETED_BUTTON      = "Непройденные",
    SI_PATCHBUI_PLEDGES_BUTTON          = "Выбрать активные задания",
    SI_PATCHBUI_DIFF_NORMAL             = "Обычная",
    SI_PATCHBUI_DIFF_VETERAN            = "Ветеранская",
    SI_PATCHBUI_UNCOMPLETED_TOOLTIP     = "Выбрать только доступные подземелья с непройденными заданиями.\nСложность: <<1>> (согласно настройкам группы).\nДоступно: <<2>>.",
    SI_PATCHBUI_PLEDGES_TOOLTIP         = "Выбрать подземелья с активными заданиями Неустрашимых.\nСложность: <<1>> (согласно настройкам группы).\nДоступно: <<2>>.",
    SI_PATCHBUI_UNCOMPLETED_SELECTED    = "Выбрано непройденных заданий: <<1>> (<<2>>)",
    SI_PATCHBUI_UNCOMPLETED_NONE        = "Все доступные задания подземелий уже пройдены! (<<1>>)",
    SI_PATCHBUI_PLEDGES_SELECTED        = "Выбрано активных заданий Неустрашимых: <<1>> (<<2>>)",
    SI_PATCHBUI_PLEDGES_NONE            = "Нет активных заданий Неустрашимых для сложности: <<1>>",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 2)
end
