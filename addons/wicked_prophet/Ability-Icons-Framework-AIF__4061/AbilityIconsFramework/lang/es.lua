local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "Trago de heroísmo",
    HP_POTION_NAME_10             = "Tintura de heroísmo",
    HP_POTION_NAME_20             = "Trago corto de heroísmo",
    HP_POTION_NAME_30             = "Poción de heroísmo",
    HP_POTION_NAME_40             = "Solución de heroísmo",
    HP_POTION_NAME_CP10           = "Elixir de heroísmo",
    HP_POTION_NAME_CP50           = "Panacea de heroísmo",
    HP_POTION_NAME_CP100          = "Destilado de heroísmo",
    HP_POTION_NAME_CP150          = "Esencia de heroísmo",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "Herramienta para personalizar los iconos de habilidades y la interfaz de combate.",
    SI_AIF_SETTINGS_HEADER        = "Ajustes",
    SI_AIF_GLOBAL_SETTINGS        = "Usar la misma configuración para todos los personajes",
    SI_AIF_SCRIBING_ICONS         = "Usar iconos de escribanía personalizados",
    SI_AIF_BASE_GAME_ICONS        = "Reemplazar iconos del juego base",
    SI_AIF_HEROISM_POTIONS        = "Habilitar iconos de pociones de heroísmo",
    SI_AIF_RESOLUTION             = "Resolución de iconos del juego base",
    SI_AIF_RESOLUTION_TIP         = "Resolución de textura para los iconos predeterminados",
    SI_AIF_RESOLUTION_WARN        = "Requiere /reloadui para aplicar los cambios",
    SI_AIF_RELOAD_UI              = "Recargar interfaz",
    SI_AIF_PACK_ORDER_SUBMENU     = "Orden de carga de paquetes de iconos",
    SI_AIF_PACK_PRIORITY          = "Prioridad de paquetes de iconos",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "Comandos disponibles:",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <casilla 3-8> [1 para barra secundaria]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <casilla 3-8> [1 para barra secundaria]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (inspeccionar variables guardadas)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (abrir menú de ajustes)",
    SI_AIF_SLOT_EMPTY             = "La casilla <<1>> (barra <<2>>) está vacía.",
    SI_AIF_SLOT_REDIRECT_NONE     = "  Redirigido a: (ninguno)",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
