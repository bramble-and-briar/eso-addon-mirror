-- Español. Solo sobrescribe las claves de lang/en.lua. Las que en en.lua usan GetString
-- (textos que ya tiene el juego) no se repiten: el juego ya las da traducidas.
local L = Vigilant.L

L.TAGLINE = "Seguimiento de bufos del grupo"

-- Atajos de teclado
L.BINDING_TOGGLE = "Mostrar/ocultar el panel"
L.BINDING_LOCK = "Bloquear/desbloquear el panel"

-- Panel
L.NO_BUFFS = "No hay bufos elegidos: /vigilant settings"
L.MISSING = "|cFF4444Le falta|r"
L.MISSING_ON = "|cFF4444Les falta a:|r"
L.OUT_OF_RANGE = "|c999999Lejos o desconectado|r"
L.REMAINING = "Quedan %s s"
L.LOCK_TIP_BUTTON = "Bloquear: fijarlo en su sitio"
L.UNLOCK_TIP = "Desbloquear: moverlo y cambiar su tamaño"
L.SWITCH_TO = "Cambiar a %s"
L.HIDDEN = "Panel oculto. Escribe |cFFFF00/vigilant|r para volver a mostrarlo."

-- Categorías de bufos comunes (ajustes)
L.CAT_OFFENSE = "Bufos ofensivos"
L.CAT_DEFENSE = "Bufos defensivos"
L.CAT_RESOURCES = "Recursos y movilidad"
L.CAT_SETS = "Sets y definitivas"

-- Catálogo de todos los efectos
L.BROWSER_TITLE = "Bufos y procs"
L.BROWSER_HINT = "Pulsa + (o doble clic) para seguirlo. Cuentan todas las variantes con el mismo nombre."
L.BROWSER_LOADING = "Preparando la lista de efectos del juego... %d%%"
L.BROWSER_EMPTY = "No se ha encontrado nada."
L.BROWSER_NO_ACTIVE = "Nadie cerca tiene bufos ahora mismo.\nConsigue el bufo o el proc y vuelve."
L.BROWSER_COUNT = "%s efectos"
L.BROWSER_TRACKED = "Seguido"
L.BROWSER_VARIANTS = "%d variantes"
L.BROWSER_ADDED = "Siguiendo: %s"
L.BROWSER_REMOVED = "Ya no se sigue: %s"
L.CAT_GROUP_QUICK = "Rápido"
L.CAT_ACTIVE = "Activos ahora (tú y el grupo)"
L.CAT_TRACKED = "Seguidos"
L.CAT_MAJOR_MINOR = "Bufos mayores y menores"
L.CAT_GEAR = "Sets y procs"
L.CAT_GROUP_CLASSES = "Clases"
L.CAT_GROUP_OTHER = "Otros"
L.CAT_WORLD = "Mundo y JcJ"

-- Bufos personalizados
L.CUSTOM_BAD_ID = "No existe ninguna habilidad con el ID %d."
L.CUSTOM_EXISTS = "Ya se sigue: %s"
L.CUSTOM_ADDED = "Bufo añadido: %s"
L.CUSTOM_REMOVED = "Bufo quitado: %s"
L.CUSTOM_NOT_FOUND = "Ningún bufo personalizado coincide con '%s' (mira |cFFFF00/vigilant list|r)"
L.CUSTOM_TAG = "personalizado"

-- Comandos de chat
L.HELP_HEADER = "Comandos (v%s):"
L.HELP = {
    "|cFFFF00/vigilant|r - mostrar/ocultar el panel",
    "|cFFFF00/vigilant unlock|r / |cFFFF00lock|r - mover y redimensionar el panel / fijarlo",
    "|cFFFF00/vigilant grid|r / |cFFFF00summary|r - una fila por miembro / una fila por bufo",
    "|cFFFF00/vigilant browse|r - catálogo de todos los bufos y procs para seguir cualquiera",
    "|cFFFF00/vigilant add <nombre>|r - seguir un bufo por su nombre",
    "|cFFFF00/vigilant remove <nombre o número>|r - dejar de seguir un bufo personalizado",
    "|cFFFF00/vigilant list|r - lista de bufos seguidos",
    "|cFFFF00/vigilant reset|r - poner el uptime a cero",
    "|cFFFF00/vigilant settings|r - abrir los ajustes",
}
L.USAGE_ADD = "Uso: /vigilant add <nombre del bufo>   (o abre el catálogo: /vigilant browse)"
L.USAGE_REMOVE = "Uso: /vigilant remove <nombre o número de /vigilant list>"
L.LOCKED = "Panel bloqueado."
L.UNLOCKED = "Panel desbloqueado: arrástralo para moverlo y arrastra sus bordes o la esquina inferior derecha para cambiar su tamaño."
L.UNIT_NOT_FOUND = "La unidad '%s' no existe (prueba player, group1, group2...)"
L.SCAN_HEADER = "%d bufos en %s:"
L.LIST_HEADER = "%d bufos seguidos:"
L.CHECK_OK = "Todos los ID de la lista de bufos son correctos."
L.CHECK_BAD = "%d ID ya no corresponden al bufo esperado (en rojo arriba)."

-- Ajustes
L.SETTINGS_DESC = "Muestra qué bufos tiene cada miembro del grupo. Elige abajo los bufos comunes o cualquier otro bufo o proc desde el catálogo."
L.ACCOUNT_WIDE = "Mismos ajustes para todos los personajes"
L.ACCOUNT_WIDE_TIP = "Activado: todos los personajes usan los ajustes de la cuenta. Desactivado: este personaje tiene los suyos (empieza con una copia de los de la cuenta). Hay que recargar la interfaz."
L.SHOW_PANEL = "Mostrar panel"
L.LOCK_PANEL = "Bloquear panel"
L.LOCK_TIP = "Desbloqueado, el panel se ve siempre y se puede mover y redimensionar. Bloqueado, sigue las condiciones de abajo."
L.LAYOUT = "Vista"
L.LAYOUT_GRID = "Cuadrícula (una fila por miembro)"
L.LAYOUT_SUMMARY = "Resumen (una fila por bufo)"
L.LAYOUT_TIP = "El resumen muestra cuántos miembros tienen cada bufo (p. ej. 6/8). Pasa el ratón por una fila para ver a quién le falta."
L.ONLY_GROUP = "Solo en grupo"
L.ONLY_GROUP_TIP = "Sin grupo el panel te muestra solo a ti, útil para probarlo."
L.ONLY_COMBAT = "Solo en combate"
L.H_LOOK = "Aspecto"
L.NAME_WIDTH = "Ancho de los nombres"
L.BG_ALPHA = "Opacidad del fondo"
L.NAME_FORMAT = "Nombres"
L.NAME_ACCOUNT = "@Cuenta"
L.SHOW_ROLES = "Mostrar iconos de rol"
L.SORT_ROLE = "Ordenar por rol (%s, %s, %s)"
L.SHOW_TIMERS = "Mostrar tiempo restante"
L.WARN_SECONDS = "Avisar con menos de (s)"
L.WARN_SECONDS_TIP = "El tiempo restante se pone naranja por debajo de estos segundos. 0 = nunca."
L.MISSING_STYLE = "Bufos que faltan"
L.MISSING_DIM = "Icono apagado"
L.MISSING_RED = "Icono apagado sobre rojo"
L.H_BUFFS = "Bufos seguidos"
L.BUFFS_DESC = "Cada bufo cuenta lo dé la habilidad o el set que lo dé."
L.BUFFS_DEFAULT = "Recomendados"
L.BUFFS_NONE = "Ninguno"
L.H_CUSTOM = "Otros bufos y procs"
L.CUSTOM_DESC = "Abre el catálogo para buscar cualquier bufo o proc del juego por su nombre y seguirlo con un clic. Truco: consigue antes el proc y míralo en |cFFFF00Activos ahora|r."
L.BROWSE_BUTTON = "Abrir catálogo"
L.BROWSE_TIP = "Todos los bufos y procs del juego, por categorías y con buscador."
L.CUSTOM_LIST = "Añadidos desde el catálogo"
L.CUSTOM_NONE = "(ninguno)"
L.H_COMMANDS = "Comandos de chat"

-- Uptime (barra inferior)
L.UPTIME_TITLE = "Uptime en combate"
L.UPTIME_NONE = "Todavía no ha habido combate."
L.UPTIME_TIP_FIGHT = "Duración del combate actual o del último. Debajo de cada bufo, la parte de ese combate que lo ha tenido el grupo (solo cuentan los miembros cercanos). Pasa el ratón por un porcentaje para ver el de cada miembro."
L.UPTIME_TIP_RUN = "Tiempo en combate de toda la run (todos los combates desde que entraste en esta zona). Debajo de cada bufo, la parte de ese tiempo que lo ha tenido el grupo (solo cuentan los miembros cercanos). Pasa el ratón por un porcentaje para ver el de cada miembro."
L.UPTIME_SWITCH = "Clic para contar: %s"
L.UPTIME_RESET = "Poner uptime a cero"
L.UPTIME_RESET_DONE = "Uptime a cero."
L.UPTIME_SCOPE = "El uptime cuenta"
L.UPTIME_SCOPE_FIGHT = "Cada combate"
L.UPTIME_SCOPE_RUN = "Toda la run (hasta cambiar de zona)"
L.UPTIME_SCOPE_TIP = "Cada combate: empieza de cero al empezar un combate. Toda la run: suma todos los combates (solo el tiempo en combate), p. ej. una mazmorra o una prueba entera, y empieza de cero al cambiar de zona o al pulsar el botón de reinicio (flecha circular) de la barra inferior."
L.SHOW_UPTIME = "Mostrar uptime en combate"
L.SHOW_UPTIME_TIP = "Barra inferior con la duración en combate y el uptime de cada bufo. Solo cuenta mientras estás en combate."

-- Orden de los bufos
L.ORDER_BUTTON = "Ordenar bufos"
L.ORDER_TIP = "Abre el catálogo en los bufos seguidos: usa las flechas para cambiar el orden de las columnas."
L.BROWSER_ORDER_HINT = "Usa las flechas para cambiar el orden de las columnas. La X deja de seguir un bufo."
