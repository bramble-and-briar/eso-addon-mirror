local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "Глоток героизма",
    HP_POTION_NAME_10             = "Настойка героизма",
    HP_POTION_NAME_20             = "Микстура героизма",
    HP_POTION_NAME_30             = "Зелье героизма",
    HP_POTION_NAME_40             = "Раствор героизма",
    HP_POTION_NAME_CP10           = "Эликсир героизма",
    HP_POTION_NAME_CP50           = "Панацея героизма",
    HP_POTION_NAME_CP100          = "Дистиллят героизма",
    HP_POTION_NAME_CP150          = "Эссенция героизма",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "Фреймворк для настройки иконок способностей и боевого интерфейса.",
    SI_AIF_SETTINGS_HEADER        = "Настройки",
    SI_AIF_GLOBAL_SETTINGS        = "Одинаковые настройки для всех персонажей",
    SI_AIF_SCRIBING_ICONS         = "Использовать особые иконки чарописи",
    SI_AIF_BASE_GAME_ICONS        = "Заменять иконки базовой игры",
    SI_AIF_HEROISM_POTIONS        = "Включить иконки зелий героизма",
    SI_AIF_RESOLUTION             = "Разрешение иконок базовой игры",
    SI_AIF_RESOLUTION_TIP         = "Разрешение текстур для стандартных иконок",
    SI_AIF_RESOLUTION_WARN        = "Требуется /reloadui для применения изменений",
    SI_AIF_RELOAD_UI              = "Перезагрузить интерфейс",
    SI_AIF_PACK_ORDER_SUBMENU     = "Порядок загрузки наборов иконок",
    SI_AIF_PACK_PRIORITY          = "Приоритет наборов иконок",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "Доступные команды:",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <ячейка 3-8> [1 для запасной панели]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <ячейка 3-8> [1 для запасной панели]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (просмотр сохраненных переменных)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (открыть меню настроек)",
    SI_AIF_SLOT_EMPTY             = "Ячейка <<1>> (панель <<2>>) пуста.",
    SI_AIF_SLOT_REDIRECT_NONE     = "  Перенаправлено на: (нет)",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
