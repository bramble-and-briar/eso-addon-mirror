local AE = AtlasAddon

AE.Translations.es = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "Un complemento Torfason × Atlas para The Elder Scrolls Online. Revela el mapa del mundo mientras exploras Tamriel.",
    PREFIX = "|cD8B36A[Atlas]|r ",
    LOADED = "cargado. /atlas help muestra los comandos.",
    HELP = [[
|cD8B36AAtlas – Comandos|r
/atlas – abrir los ajustes de Atlas
/atlas help – mostrar esta ayuda
/atlas on – activar Atlas
/atlas off – desactivar Atlas
/atlas reveal – revelar todo el mapa actual
/atlas forget – borrar la exploración del mapa actual
/atlas import – importar TrueExploration del personaje actual
/atlas importall – fusionar todos los perfiles TrueExploration encontrados
/atlas status – mostrar información del mapa actual
/atlas archive – abrir el archivo de mapas de Atlas
/atlas settings – abrir los ajustes
/atlas style <1-6> – elegir el estilo del mapa sin explorar
/atlas radius <1-8> – radio de revelado en casillas
/atlas opacity <10-100> – opacidad del mapa sin explorar, en porcentaje
/ae sigue disponible como alias abreviado.

Los comandos en alemán también funcionan: /atlas hilfe, /atlas an, /atlas aufdecken.
]],
    ENABLED = "Atlas está activado.",
    DISABLED = "Atlas está desactivado.",
    CURRENT_MAP_REVEALED = "Se ha revelado todo el mapa actual.",
    CURRENT_MAP_CLEARED = "Se han borrado los datos de exploración del mapa actual.",
    NO_MAP = "No se ha podido detectar una zona válida del mapa.",
    STATUS = "Mapa: %s | descubierto: %d / %d casillas (%.1f%%) | estilo: %s",
    STYLE_SET = "Estilo del mapa sin explorar: %s",
    RADIUS_SET = "Radio de revelado: %d casillas.",
    OPACITY_SET = "Opacidad: %d%%.",
    BAD_VALUE = "Valor no válido. Usa /atlas help.",
    ARCHIVE_TITLE = "ARCHIVO DE MAPAS",
    ARCHIVE_SUBTITLE = "Todos los mapas en los que Atlas ya ha dibujado algo.",
    ARCHIVE_COUNT = "%d mapas guardados",
    ARCHIVE_EMPTY = "Todavía no hay mapas explorados guardados.",
    ARCHIVE_PAGE = "Página %d / %d",
    ARCHIVE_PREV = "Anterior",
    ARCHIVE_NEXT = "Siguiente",
    ARCHIVE_VARIANT_LABEL = "Mapa %d · ID %s",
    ARCHIVE_GROUP_EXPAND_HINT = "Haz clic para ver cada mapa o planta por separado.",
    ARCHIVE_GROUP_COLLAPSE_HINT = "Haz clic para contraer este grupo de mapas.",
    ARCHIVE_FORGET = "Olvidar mapa",
    ARCHIVE_FORGET_HINT = "Borra únicamente el progreso de Atlas de este mapa. Se pedirá confirmación.",
    ARCHIVE_MAP_CLEARED = "Se ha borrado el progreso de exploración de «%s».",
    ARCHIVE_OPEN_HINT = "Clic izquierdo: abrir. Clic derecho: revelar u olvidar este mapa.",
    ARCHIVE_REVEAL = "Revelar mapa",
    ARCHIVE_MAP_REVEALED = "Se ha revelado por completo el mapa «%s».",
    ARCHIVE_MENU_UNAVAILABLE = "El menú del mapa no está disponible. No se han modificado los datos.",
    ARCHIVE_OPEN_FAILED = "ESO no permite abrir este mapa directamente desde aquí. Atlas lo conservará en el archivo.",
    ARCHIVE_UNRESOLVED = "Atlas conoce este mapa, pero aún no lo ha vinculado con un ID de ESO. Lo hará automáticamente la próxima vez que lo visites.",
    ARCHIVE_RESOLVING = "Atlas está asociando mapas antiguos guardados con sus ID de ESO en segundo plano…",
    ARCHIVE_PATH = "Guardado como: %s",
    ARCHIVE_UNKNOWN_MAP = "Mapa desconocido",
    IMPORT_NO_TE = "No se han cargado los datos de TrueExploration. Activa TrueExploration junto con Atlas, recarga la interfaz e inténtalo de nuevo.",
    IMPORT_START = "Comprobando la importación de TrueExploration…",
    IMPORT_DONE = "Importación completada: %d mapas encontrados, %d fusionados, %d casillas añadidas, %d entradas no reconocidas.",
    IMPORT_NONE = "No se ha encontrado el perfil TrueExploration del personaje actual. Activa TrueExploration con Atlas y recarga la interfaz.",
    IMPORT_NONE_ALL = "No se encontraron tablas de mapas TrueExploration en TE_SavedVars.",
    IMPORT_ALL_WARNING = "Todos los perfiles TrueExploration encontrados se fusionarán con este personaje.",
    STYLE_NAMES = { "Pergamino", "Papel claro", "Pergamino oscuro", "Niebla gris", "Carbón", "Negro intenso" },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "Pergamino – antiguo mapa de exploración con brújula y marcas de navegación desvaídas",
        "Papel claro – hoja de cartógrafo con líneas de medición y marcas sutiles",
        "Pergamino oscuro – carta náutica envejecida con costas y pliegues desvaídos",
        "Niebla gris – bruma fría con curvas de nivel sutiles y suaves velos",
        "Carbón – papel rugoso con caminos dibujados a mano y señales antiguas",
        "Negro intenso – misterioso mapa nocturno con estrellas y motivos de navegación discretos",
    },
    OPTION_LANGUAGE = "Idioma",
    OPTION_LANGUAGE_TT = "Selecciona el idioma solo para Atlas. El modo automático sigue el idioma de ESO sin cambiar el juego ni otros complementos.",
    LANGUAGE_AUTO = "Automático (como ESO)",
    SETTINGS_VERSION = "Versión %s",
    SETTINGS_TITLE = "Atlas - Ajustes",
    SETTINGS_GENERAL_HEADER = "GENERAL",
    SETTINGS_APPEARANCE_HEADER = "APARIENCIA",
    SETTINGS_EXPLORATION_HEADER = "EXPLORACIÓN",
    SETTINGS_DEFAULTS = "Predeterminados",
    SETTINGS_DEFAULTS_TT = "Restablece los ajustes de Atlas sin borrar tu progreso de exploración guardado.",
    SETTINGS_CLOSE = "Cerrar",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Abrir ajustes de Atlas",
    SETTINGS_SELECTED_STYLE = "%s: %s",
    OPTION_DESCRIPTION = "El mapa comienza sin explorar y se revela únicamente por donde ha viajado tu personaje. El progreso se guarda por personaje; los ajustes visuales son comunes a la cuenta.",
    OPTION_ENABLED = "Activar Atlas",
    OPTION_ENABLED_TT = "Oculta las zonas del mapa sin explorar y revela las nuevas zonas al viajar.",
    OPTION_STYLE = "Estilo del mapa sin explorar – vista previa",
    OPTION_STYLE_TT = "Haz clic en la vista previa para ver todos los estilos y elegir uno.",
    OPTION_SELECTED = "Seleccionado",
    OPTION_OPACITY = "Opacidad del mapa sin explorar",
    OPTION_OPACITY_TT = "El 100 % oculta por completo el mapa. Los valores menores permiten verlo ligeramente.",
    OPTION_RADIUS = "Radio de revelado – mapas grandes",
    OPTION_RADIUS_TT = "Cantidad de casillas de la cuadrícula de 48 × 48 que se revelan alrededor del personaje.",
    OPTION_SUBZONES = "Explorar ciudades, mazmorras y mapas locales",
    OPTION_SUBZONES_TT = "Si está activado, los mapas locales también comienzan sin explorar.",
    OPTION_SUBRADIUS = "Radio de revelado – mapas locales",
    OPTION_SUBRADIUS_TT = "Los mapas locales suelen ser menores, por lo que pueden tener un radio distinto y más amplio.",
    OPTION_CURRENT_HEADER = "Mapa actual",
    OPTION_REVEAL = "Revelar todo el mapa actual",
    OPTION_REVEAL_TT = "Marca el mapa mostrado como completamente descubierto.",
    OPTION_CLEAR = "Olvidar el mapa actual",
    OPTION_CLEAR_TT = "Borra solo el progreso de Atlas en el mapa que se muestra.",
    CONFIRM_CLEAR_TITLE = "¿Olvidar la exploración del mapa?",
    CONFIRM_CLEAR_TEXT = "¿Quieres borrar todo el progreso de exploración de Atlas para «<<1>>»? Esta acción no se puede deshacer.",
    CONFIRM_CLEAR_ACCEPT = "Olvidar mapa",
    CONFIRM_CLEAR_CANCEL = "Cancelar",
    CONFIRM_CLEAR_UNAVAILABLE = "No se puede mostrar la confirmación. No se han borrado datos de exploración.",

    OPTION_IMPORT_HEADER = "Importación de TrueExploration",
    OPTION_IMPORT_DESC = "La importación solo lee TrueExploration y nunca modifica sus datos. Para importar el personaje actual, activa TrueExploration con Atlas y recarga la interfaz. Atlas reconoce el formato de 31 bits de la cuadrícula de 48 × 48 y fusiona rutas que solo difieren en mayúsculas.",
    OPTION_IMPORT_CURRENT = "Importar personaje actual",
    OPTION_IMPORT_CURRENT_TT = "Recomendado: importa únicamente los datos TrueExploration del personaje conectado.",
    OPTION_IMPORT_ALL = "Fusionar todos los perfiles antiguos",
    OPTION_IMPORT_ALL_TT = "Fusiona todos los mapas TrueExploration encontrados sin eliminar casillas Atlas existentes.",
    OPTION_COMMANDS_HEADER = "Comandos del chat",
    OPTION_COMMANDS = "/atlas   /atlas help   /atlas reveal   /atlas forget   /atlas import   /atlas status\n/atlas style 1-6   /atlas radius 1-8   /atlas opacity 10-100",
}
