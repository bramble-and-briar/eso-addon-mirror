local strings = {
    [SI_ONEFRAME_DEBUG] = "Debug",
    [SI_ONEFRAME_DEBUG_OFF] = "Desactivado",
    [SI_ONEFRAME_DEBUG_SMALL] = "Grupo pequeño",
    [SI_ONEFRAME_DEBUG_LARGE] = "Grupo grande",
    [SI_ONEFRAME_DISPLAY] = "Visualización",
    [SI_ONEFRAME_TANK_ROLE] = "Tanque",
    [SI_ONEFRAME_HEALER_ROLE] = "Sanador",
    [SI_ONEFRAME_DAMAGE_ROLE] = "Daño",
    [SI_ONEFRAME_SHOW_STATISTIC] = "Estadística que mostrar",
    [SI_ONEFRAME_NOTHING] = "Ninguna",
    [SI_ONEFRAME_LEVEL_CP] = "Nivel / Puntos de campeón",
    [SI_ONEFRAME_GROUP_DPS] = "DPS del grupo",
    [SI_ONEFRAME_HEALTH_THOUSANDS] = "%.1fk",
    [SI_ONEFRAME_GENERAL] = "General",
    [SI_ONEFRAME_SORT] = "Ordenar el grupo por rol",
    [SI_ONEFRAME_CLASS] = "Mostrar icono de clase",
    [SI_ONEFRAME_DPS_LABEL] = "DPS",
    [SI_ONEFRAME_HPS_LABEL] = "HPS",
    [SI_ONEFRAME_UNAVAILABLE] = "—",
    [SI_ONEFRAME_KILO] = "%.1fk",
    [SI_ONEFRAME_MILLION] = "%.2fm",
    [SI_ONEFRAME_SHIELD_COLOR] = "Color del escudo",
    [SI_ONEFRAME_CONTEXT_MENU] = "Menú contextual con clic derecho",
    [SI_ONEFRAME_WHISPER] = "Susurrar",
    [SI_ONEFRAME_TRAVEL] = "Viajar hasta el jugador",
    [SI_ONEFRAME_REMOVE] = "Expulsar del grupo",
    [SI_ONEFRAME_UNSUPPORTED] = "OneFrame: esta versión de la interfaz de ESO no se ha verificado; las mejoras de los marcos están desactivadas.",
    [SI_ONEFRAME_MISSING] = "OneFrame: los marcos predeterminados no son compatibles; no se han aplicado las mejoras.",
}

for id, text in pairs(strings) do
    SafeAddString(id, text, 1)
end
