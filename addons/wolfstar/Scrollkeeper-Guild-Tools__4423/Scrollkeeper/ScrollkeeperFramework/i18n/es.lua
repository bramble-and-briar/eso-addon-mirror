Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeper Framework cargado exitosamente",
  CRITICAL_ERROR = "ERROR CRÍTICO: ¡No se pudo crear el panel de configuración!",
  ERROR_REGISTERING = "ERROR al registrar configuración",
  LAM2_UNAVAILABLE = "¡LibAddonMenu2 no disponible!",
  ALREADY_INITIALIZED = "Ya inicializado, saltando...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButton no disponible - botones de chat desactivados",
  HEADER_DESC = "Marco central para Scrollkeeper Guild Tools con integraciones de biblioteca mejoradas. Los módulos individuales tienen su propia configuración y no requieren recarga.",
  DONATE_BUTTON = "Apoyar el Desarrollo",
  DONATE_TOOLTIP = "Enviar una donación a @WolfStar07 en PC/NA para apoyar el desarrollo continuo",
  OPEN_ALL_WINDOWS = "Abrir Todas las Ventanas de Scrollkeeper",
  OPEN_SETTINGS = "Abrir Configuración de Scrollkeeper",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Guild Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "Temas de Color",
  DESCRIPTION = "Elige entre temas de color predefinidos para los elementos de interfaz de Scrollkeeper.",
  ACTIVE_THEME = "Tema Activo",
  ACTIVE_THEME_TOOLTIP = "Selecciona qué tema de color aplicar a los elementos de interfaz de Scrollkeeper.",
  CURRENT_THEME = "Tema actual: %s",
  
  -- Preview Section
  PREVIEW_HEADER = "Vista Previa de Colores:",
  BORDER_COLOR = "Color de Borde",
  BORDER_DESC = "Bordes y aristas de ventanas",
  HEADER_COLOR = "Color de Encabezado",
  HEADER_DESC = "Barras de título y encabezados de columnas",
  TEXT_COLOR = "Color de Texto", 
  TEXT_DESC = "Texto principal y etiquetas",
  ACCENT_COLOR = "Color de Acento",
  ACCENT_DESC = "Botones resaltados y selecciones",
  NOTE = "Nota: Los cambios de tema se aplican inmediatamente a todas las ventanas abiertas de Scrollkeeper.",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r ERROR: ¡Falta ScrollkeeperFramework!",
  
  -- Theme Names
  THEME_EMBER = "Ascua",
  THEME_FORGE = "Fragua",
  THEME_OCEAN = "Océano",
  THEME_SKY = "Cielo",
  THEME_REGALIA = "Regalia",
  THEME_BRIAR = "Zarza",
  THEME_JUNGLE = "Selva",
  
  -- Status Messages
  STATUS_UNKNOWN = "Desconocido",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "Seguimiento de Miembros Provisionales",
  DESCRIPTION = "Rastrea miembros de la hermandad en rangos de prueba y aquellos que no cumplen con los requisitos de donación. Usa |cFFD700/sgtprovision|r para abrir la ventana de gestión.",
  MASTER_ENABLE = "Activar Seguimiento de Miembros Provisionales (Maestro)",
  MASTER_ENABLE_TIP = "Interruptor maestro para todas las funciones de seguimiento de miembros provisionales.",
  OPEN_ADMIN = "Abrir Ventana de Administración",
  OPEN_ADMIN_TIP = "Abrir la ventana de gestión de miembros provisionales",
  CLEAR_SCAN = "Limpiar Datos Incorrectos y Escanear",
  CLEAR_SCAN_TIP = "Limpiar miembros rastreados incorrectamente y escanear en busca de nuevos",
  RESET_GOLD = "Restablecer Eliminaciones de Oro",
  RESET_GOLD_TIP = "Limpiar todas las marcas de eliminación basadas en oro, permitiendo que los miembros sean reevaluados para el seguimiento de oro",
  STATUS_TRACKING = "Actualmente rastreando: %d miembros provisionales activos",
  STATUS_RANK_REMOVED = "Eliminados permanentemente (rango): %d miembros",
  STATUS_GOLD_REMOVED = "Eliminados temporalmente (oro): %d miembros",
  WINDOW_OPENED_MESSAGE = "Ventana abierta. Use el botón |cFFFFFFEscanear|r para verificar miembros que necesitan seguimiento.",
  
  -- Window UI
  WINDOW_TITLE = "Gestión de Miembros Provisionales",
  SELECT_GUILD = "Seleccionar Hermandad:",
  FILTER_LABEL = "Filtro:",
  MEMBER_NAME = "Nombre del Miembro",
  DAYS = "Días",
  STATUS = "Estado de Seguimiento",
  NOTES = "Notas",
  ACTIONS = "Acciones",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Activar para %s",
  ENABLE_FOR_GUILD_TIP = "Activar seguimiento de miembros provisionales para esta hermandad.",
  AUTO_TAG = "Auto-Etiquetar Nuevos Miembros",
  AUTO_TAG_TIP = "Etiquetar automáticamente miembros que cumplan con los criterios de seguimiento.",
  NOTIFY_JOIN = "Notificar Cuando se Unan Miembros",
  NOTIFY_JOIN_TIP = "Mostrar notificaciones para nuevos miembros en esta hermandad.",
  PROBATION_DAYS = "Período de Prueba (Días)",
  PROBATION_DAYS_TIP = "Cuántos días permanecen los miembros en estado de prueba antes de ser promovidos.",
  
  -- Gold Tracking
  GOLD_HEADER = "Seguimiento de Donaciones de Oro",
  INACTIVITY_HEADER = "Seguimiento de Inactividad",
  DONOR_HEADER = "Reconocimiento de Donantes",
  GOLD_ENABLE = "Activar Filtro de Donación de Oro",
  GOLD_ENABLE_TIP = "Rastrear miembros que no han cumplido con los requisitos de donación.",
  GOLD_AMOUNT = "Cantidad de Donación Requerida",
  GOLD_AMOUNT_TIP = "Cantidad de oro que los miembros deben donar en el período de tiempo (ej. 5000 para cuotas de 5k).",
  GOLD_PERIOD = "Período de Tiempo (Días)",
  GOLD_PERIOD_TIP = "Número de días para verificar donaciones (ej. 30 para cuotas mensuales, 7 para semanales).",
  STATUS_PENDING_DONATION = "Donación Pendiente",
  SOURCE_MANUAL = "Manual",
  TIP_DAYS_MANUAL = "^ = Incluye entradas de donaciones manuales",
  
  -- Statistics
  GUILD_STATS = "Estadísticas de Hermandad",
  NO_MEMBERS = "Actualmente no hay miembros provisionales rastreados para esta hermandad",
  STATS_FORMAT = "Rastreando %d miembros: %d activos, %d vencidos, %d promovidos",
  RECENT_ADDITIONS = "Adiciones recientes (últimos 7 días): %d",
  
  -- Integration Status
  INTEGRATION_HEADER = "Fuentes de Datos de Tiempo de Unión e Integración",
  AMT_AVAILABLE = "Advanced Member Tooltip - Tiempos de unión más precisos disponibles",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - No instalado",
  AMT_INSTALL = "Instalar desde: esoui.com/downloads/info2351",
  AMT_DESC = "Proporciona el seguimiento más preciso del tiempo de unión a la hermandad",
  LH_READY = "LibHistoire - Listo y procesando historial de hermandad",
  LH_MISSING = "LibHistoire - No encontrado (dependencia requerida)",
  DATA_AVAILABLE = "Módulo de Datos - Seguimiento de donaciones de oro activado",
  DATA_UNAVAILABLE = "Módulo de Datos - Filtrado de oro no disponible",
  
  -- Symbol Legend
  SYMBOL_LEGEND = "Símbolos de la Columna de Días:",
  SYMBOL_AMT = "* = Datos AMT (más preciso)",
  SYMBOL_HISTOIRE = "~ = Historial de hermandad LibHistoire",
  SYMBOL_DONATION = "? = Estimación de primera donación",
  SYMBOL_TAGGED = "! = Tiempo de inicio de seguimiento",
  SYMBOL_VALIDATED = "(sin símbolo) = Datos almacenados validados",
  SYMBOL_UNKNOWN = "DESC = Fuente desconocida/no confiable",
  SYMBOL_FOOTER = "Pasa el cursor sobre cualquier valor de días para información detallada de la fuente.",
  TIP_SORT_NAME = "Haz clic para ordenar por nombre",
  TIP_SORT_DAYS = "Haz clic para ordenar por días desde el ingreso",

  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] ERROR: ¡Falta el framework!",
  ERROR_NO_GUILD_SELECTED = "No se seleccionó hermandad",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMail no disponible",
  ERROR_NO_MEMBERS_TO_MAIL = "No hay miembros para enviar correo",
  ERROR_MAIL_WINDOW_FAILED = "Fallo al acceder a la ventana de correo",
  ERROR_SETTINGS_UNAVAILABLE = "Configuración no disponible",
  ERROR_NO_GUILDS = "No hay hermandades disponibles. Únete a una hermandad para configurar ajustes por hermandad.",
 
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltip detectado - seguimiento mejorado activado",
  SUCCESS_HISTOIRE_READY = "Integración de LibHistoire lista - tiempos de unión precisos disponibles",
  SUCCESS_REMOVED = "%s eliminado del seguimiento",
  SUCCESS_BULK_REMOVED = "%d miembros eliminados masivamente del seguimiento",
  SUCCESS_CLEARED_DATA = "Datos de seguimiento limpiados para %s",
  SUCCESS_CLEARED_GOLD = "%d marcas de eliminación basadas en oro limpiadas",
  SUCCESS_MAIL_OPENED = "Ventana de correo abierta con %d miembros provisionales de %s",

  -- Status Messages
  STATUS_DISABLED = "Seguimiento de provisionales está desactivado",
  STATUS_NO_DATA = "No hay datos disponibles",
  STATUS_NO_TRACKING = "No hay datos de seguimiento disponibles",
  STATUS_SELECT_GUILD = "Selecciona una hermandad para ver estadísticas",
  STATUS_NO_FILTER_MATCH = "Ningún miembro coincide con los criterios de filtro actuales.",
  STATUS_NO_SELECTED = "No hay miembros seleccionados para promoción",
  STATUS_NO_SELECTED_REMOVE = "No hay miembros seleccionados para eliminación",

  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "Verde: Información de donaciones",
  NOTES_COLOR_OFFLINE = "Naranja: Información de desconexión",
  NOTES_COLOR_NO_DONATION = "Rojo: No se encontraron donaciones",
  
  -- Button Labels
  BTN_REFRESH = "Actualizar",
  BTN_REFRESH_TIP = "Actualizar datos de hermandad y lista de miembros",
  BTN_EXPORT = "Exportar",
  BTN_EXPORT_TIP = "Exportar datos de miembros a ventana de texto copiable",
  BTN_SCAN = "Escanear",
  BTN_SCAN_TIP = "Escanear listas de hermandad en busca de nuevos miembros provisionales",
  BTN_VIEW_SELECTED = "Ver Seleccionados",
  BTN_VIEW_ALL = "Ver Todos",
  BTN_VIEW_SELECTED_TIP = "Alternar entre ver todos los miembros y solo los seleccionados",
  BTN_PROMOTE_ALL = "Promover Todos",
  BTN_PROMOTE_ALL_TIP = "Abrir lista de hermandad para promover miembros resaltados.",
  BTN_REMOVE_ALL = "Eliminar Todos",
  BTN_REMOVE_ALL_TIP = "Eliminar todos los miembros seleccionados del seguimiento",
  BTN_MAIL_SELECTED = "Enviar Correo a Seleccionados",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "Abrir ventana de correo con miembros seleccionados (%d)",
  BTN_MAIL_SELECTED_TIP_FILTERED = "Abrir ventana de correo con miembros filtrados",
  BTN_SELECT_ALL = "Seleccionar Todos",
  BTN_CLOSE = "Cerrar",

  -- Filter Labels
  FILTER_ALL = "TODOS",
  FILTER_PROBATION_ICON_TIP = "Filtrar por miembros de prueba",
  FILTER_GOLD_ICON_TIP = "Filtrar por miembros con bajas donaciones de oro",
  STATUS_INACTIVE = "Inactivo",
  STATUS_DONOR = "Donante Activo",

  -- Export Window
  EXPORT_TITLE = "Exportar Datos - Seleccionar y Copiar Texto",
  EXPORT_INSTRUCTION = "Haz clic en 'Seleccionar Todos' y luego usa Ctrl+C para copiar al portapapeles",
  EXPORT_REPORT_HEADER = "Informe de Miembros Provisionales para %s",
  EXPORT_GENERATED = "Generado: %s",
  EXPORT_FILTER = "Filtro: %s",
  EXPORT_VIEW_SELECTED = "Vista: Solo Miembros Seleccionados",
  EXPORT_FILTER_ALL = "Todos los Miembros",
  EXPORT_FILTER_RANK = "Miembros de Prueba",
  EXPORT_FILTER_GOLD = "Miembros de Donación de Oro",
  EXPORT_FILTER_CUSTOM = "Miembros Filtrados",
  EXPORT_FORMAT = "%s | Estado: %s | Días en hermandad: %s | Razón: %s | Notas: %s",
  EXPORT_DAYS_NA = "N/D (filtro de oro)",
  EXPORT_DAYS_FORMAT = "%d (%s)",
  EXPORT_DAYS_ACTUAL = "real",
  EXPORT_DAYS_ESTIMATED = "estimado",
  EXPORT_FILTER_INACTIVE = "Miembros Inactivos",
  EXPORT_FILTER_DONOR = "Donantes Activos",

  -- Tooltips
  TIP_OPEN_ROSTER = "Abrir lista de miembros para %s",
  TIP_REMOVE = "Eliminar %s del seguimiento",
  TIP_DAYS_HEADER = "Días desde unión a la hermandad\n\n",
  TIP_DAYS_OFFLINE_HEADER = "Días Desconectado",
  TIP_DAYS_OFFLINE_DESC = "Muestra cuántos días este miembro ha estado desconectado.\nNúmeros más altos indican mayor inactividad.",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip (más preciso)",
  TIP_DAYS_HISTOIRE = "~ = Historial de hermandad LibHistoire",
  TIP_DAYS_DONATION = "? = Estimación de primera donación",
  TIP_DAYS_TAGGED = "! = Tiempo de inicio de seguimiento",
  TIP_DAYS_UNKNOWN = "(Desconocido - sin fuente de datos confiable)",
  TIP_DAYS_GOLD = "(Miembro de filtro de oro)",
  TIP_DAYS_VALIDATED = "(Validado desde datos almacenados)",
  TIP_INSTALL_AMT = "Instala Advanced Member Tooltip\npara tiempos de unión más precisos",
  TIP_REVIEW_KICK = "Abrir lista para revisar/expulsar %s (miembro inactivo)",
  TIP_REVIEW_PROMOTE = "Abrir lista para revisar/expulsar %s (miembro en prueba)",
  TIP_REVIEW_DONATION = "Abrir lista para revisar %s (donación pendiente)",
  TIP_PROMOTE_DONOR = "Abrir lista para promover %s (colaborador valioso)",
  FILTER_INACTIVE_TIP = "Mostrar miembros que han estado desconectados durante el período configurado",
  FILTER_DONOR_TIP = "Mostrar miembros que cumplen los requisitos mínimos de donación",

  -- Logging Messages
  LOG_STARTING_SCAN = "Iniciando escaneo manual...",
  LOG_SCAN_COMPLETE = "Escaneo manual completo - %d entradas incorrectas limpiadas, %d nuevos miembros encontrados",
  LOG_REFRESHED = "Visualización actualizada",
  LOG_NEW_MEMBER = "Nuevo miembro se unió a %s: %s",
  LOG_OPENING_ROSTER_PROMOTE = "Abriendo lista para promover: %s",
  LOG_OPENING_ROSTER_BULK = "Abriendo lista - promover estos %d miembros: %s",
  LOG_NO_GUILD_ID = "No se pudo encontrar ID de hermandad para: %s",
  LOG_NO_GUILD_ID_SIMPLE = "No se pudo encontrar ID de hermandad",
  LOG_FILTER_MODE = "Modo %s - %d miembros seleccionados",
  LOG_INITIALIZING = "Inicializando - %s",
  ERROR_DATA_NOT_READY = "Los datos del historial de hermandad aún no están listos. Espera un momento e inténtalo de nuevo.",
  LOG_SCAN_COMPLETE_SHORT = "¡Escaneo completo!",
  
  -- Mail Integration
  MAIL_SUBJECT_GOLD = "Recordatorio de Cuotas de Hermandad - %s",
  MAIL_RECIPIENT_COUNT = "Destinatarios Provisionales: %d",
  MAIL_STATUS = "Estado: %d miembros provisionales listos para enviar correo",

  -- Stats Display
  STATS_FORMAT_FULL = "Hermandad: %s | Total: %d | Activos: %d | Vencidos: %d | Promovidos: %d | Prueba: %d | Oro: %d",
  STATS_LH_READY = "listo",
  STATS_LH_LOADING = "cargando",

  -- Auto-tag Messages
  AUTO_TAG_SCAN = "Auto-etiquetado (escaneo)",
  AUTO_TAG_LOGIN = "Auto-etiquetado (escaneo de inicio de sesión)",
  AUTO_TAG_ONLINE = "Auto-etiquetado (unido en línea)",
  ACTIVE_DONOR = "Donante Activo",

  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "No hay hermandades configuradas para seguimiento",

  -- Status Values
  STATUS_PROVISIONAL = "provisional",
  STATUS_PROMOTED = "promovido",

  -- Reason Values
  REASON_RANK = "rango",
  REASON_GOLD = "oro",
  REASON_INACTIVE = "Inactivo",
  REASON_DONOR = "Donante",

  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "Estado de addons integrados y fuentes de datos:",

  -- Member Count Status
  MEMBER_COUNT_STATUS = "Estado del Conteo de Miembros",
  MEMBER_COUNT_FORMAT = "Actualmente rastreando: %d miembros provisionales activos\nEliminados permanentemente (rango): %d miembros\nEliminados temporalmente (oro): %d miembros",

  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "donación",
  SOURCE_TAGGED = "etiquetado",
  SOURCE_STORED = "almacenado",
  SOURCE_UNKNOWN = "desconocido",
  SOURCE_DATA = "datos",

  -- Days display values
  DAYS_UNKNOWN = "DESC",
  DAYS_ERROR = "ERR",
  DAYS_NA = "-",
  
  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "Rastrear Miembros Inactivos",
  INACTIVITY_ENABLE_TIP = "Rastrear automáticamente miembros que han estado desconectados por un período prolongado",
  INACTIVITY_DAYS = "Inactivo Después de (Días)",
  INACTIVITY_DAYS_TIP = "Considerar un miembro inactivo si no ha iniciado sesión durante esta cantidad de días",
  
  -- Settings - Donor Filter
  DONOR_ENABLE = "Rastrear Donantes Activos",
  DONOR_ENABLE_TIP = "Rastrear miembros que cumplen o superan los requisitos mínimos de donación (útil para reconocer colaboradores)",
  DONOR_AMOUNT = "Cantidad Mínima de Donación",
  DONOR_AMOUNT_TIP = "Cantidad de oro requerida para ser considerado un donante activo",
  DONOR_PERIOD = "Período de Tiempo (Días)",
  DONOR_PERIOD_TIP = "Verificar donaciones dentro de los últimos X días",
  MANUAL_SCAN_NOTE = "Nota: El seguimiento de miembros requiere escaneo manual. Abre la ventana de Miembros Provisionales y haz clic en el botón Escanear para verificar miembros que necesitan seguimiento.",
}

--------------------------------------------------------------------------------
-- GUILD MAIL
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "Correo de Hermandad",
  DESCRIPTION = "Composición de correo masivo con integración de plantillas. Los envíos de correo se limitan automáticamente a 3.1 segundos entre mensajes. Usa |cFFD700/sgtmail|r para abrir la ventana de correo.",
  ENABLE_MAIL = "Activar Correo de Hermandad",
  ENABLE_MAIL_TIP = "Activar o desactivar la función de Correo de Hermandad.",
  OPEN_MAIL = "Abrir Ventana de Correo",
  OPEN_MAIL_TIP = "Haz clic para abrir la ventana de composición de correo.",
  
  -- Window UI
  WINDOW_TITLE = "Correo de Hermandad Scrollkeeper",
  MAIL_TEMPLATES = "Plantillas de Correo:",
  SELECT_TEMPLATE = "-- Seleccionar Plantilla --",
  GUILD_LABEL = "Hermandad:",
  RANK_FILTER = "Filtro de Rango:",
  ALL_RANKS = "Todos los Rangos",
  PROVISIONAL_LABEL = "Miembros Provisionales:",
  ALL_PROVISIONAL = "Todos los Provisionales",
  GOLD_ONLY = "Solo Filtro de Oro",
  RANK_ONLY = "Solo Filtro de Rango",
  USE_PROVISIONAL = "Usar Lista Provisional",
  KICK_AFTER_MAIL = "Remover después de enviar:",
  KICK_NO = "No remover",
  KICK_YES = "Remover después de enviar",
  KICK_NO_PERMISSION = "No tienes permiso para remover miembros de este gremio",
  MEMBER_KICKED = "Expulsado: %s",
  MEMBER_NOT_FOUND = "No se pudo encontrar al miembro %s en el roster del gremio",
  PREVIEW_TITLE = "Vista previa del correo",
  PREVIEW_MAIL = "Vista previa",
  
  -- Composition
  SUBJECT_LABEL = "Asunto:",
  BODY_LABEL = "Cuerpo del Mensaje:",
  READY_TO_SEND = "Listo para enviar",
  STATUS_READY = "Estado: Listo",
  RECIPIENTS = "Destinatarios: %d",
  
  -- Buttons
  SAVE_TEMPLATE = "Guardar Plantilla",
  PREVIEW_RECIPIENTS = "Vista Previa de Destinatarios",
  SEND_MAIL = "Enviar Correo",
  PAUSE = "Pausar",
  RESUME = "Reanudar",
  
  -- Status Messages
  NO_GUILD = "Estado: Por favor selecciona una hermandad primero",
  NO_SUBJECT = "Estado: Por favor ingresa un asunto",
  NO_BODY = "Estado: Por favor ingresa un cuerpo de mensaje",
  NO_RECIPIENTS = "Estado: No se encontraron destinatarios",
  STARTING = "Estado: Iniciando envío de correo...",
  SENDING = "Enviando %d/%d",
  SENDING_TO = "Para: %s",
  SUCCESS = "Estado: Correo enviado exitosamente",
  FAILED = "Estado: Fallido - %s",
  PAUSED = "Estado: Pausado",
  COMPLETED = "Completado: %d enviados, %d fallidos",
  TEMPLATE_SAVED = "Estado: Plantilla guardada",
  TEMPLATE_FAILED = "Estado: Fallo al guardar plantilla",
  NEED_SUBJECT_BODY = "Estado: Por favor ingresa asunto y cuerpo",
  RECIPIENTS_FOUND = "Estado: %d destinatarios encontrados",
  NO_MATCH_FILTERS = "Estado: Ningún destinatario coincide con los filtros",
  PROVISIONAL_SELECTED = "Estado: %d miembros provisionales seleccionados",
  NO_PROVISIONAL = "Estado: No se encontraron miembros provisionales",
  USING_PROVISIONAL = "Estado: Usando lista de miembros provisionales...",
  
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "Destinatario no encontrado",
  MAILBOX_FULL = "Buzón lleno",
  IGNORED = "Destinatario ignorando correo",
  BLANK_MAIL = "Correo en blanco no permitido",
  UNKNOWN_ERROR = "Error desconocido",

  -- Character count display
  CHAR_COUNT = "%d/%d",

  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "todos",
  PROVISION_FILTER_GOLD = "oro", 
  PROVISION_FILTER_RANK = "rango",

  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "Recordatorio de Cuotas de Hermandad - %s",

  -- Failure log content
  FAILURE_LOG_TITLE = "Informe de Fallo de Envío de Correo",
  FAILURE_LOG_DATE = "Fecha: %s",
  FAILURE_LOG_SUBJECT_LINE = "Asunto: %s",
  FAILURE_LOG_TOTAL_SENT = "Total Enviados: %d",
  FAILURE_LOG_TOTAL_FAILED = "Total Fallidos: %d",
  FAILURE_LOG_FAILED_LIST = "Destinatarios Fallidos:",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "Cuerpo del Mensaje Original:",
  FAILURE_LOG_SAVED = "Registro de fallos guardado en Cuaderno: '%s'",
  FAILURE_LOG_SAVE_FAILED = "Fallo al guardar registro de fallos en Cuaderno",
  FAILURE_LOG_NO_NOTEBOOK = "No se puede guardar registro de fallos - Cuaderno no disponible",
  
  -- Mail tags
  TAG_MAIL = "correo",
  TAG_TEMPLATE = "plantilla",
  TAG_MAIL_LOG = "registro-correo",
  TAG_FAILURES = "fallos",

  -- Failure log
  FAILURE_LOG_TITLE_FORMAT = "Fallos de correo - %s",
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "Configuración de Cuaderno",
  WINDOW_TITLE = "Cuaderno Scrollkeeper",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r ERROR: ¡Falta ScrollkeeperFramework!",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r Ya inicializado, saltando...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r La ventana ya existe, devolviendo la existente",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Advertencia: No se pudo crear el menú desplegable",
  ERROR_WINDOW_NOT_INIT = "Ventana de cuaderno no inicializada.",
  ERROR_NO_NOTE_ENTRY = "No hay entrada de nota para %s.",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r El cuaderno está desactivado",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Por favor ingresa un título para la nota",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Fallo al guardar la nota",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Por favor ingresa un título para la plantilla",
  
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Nota guardada: %s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Plantilla de correo guardada: %s",
  
  -- Window Labels
  LABEL_SEARCH = "Buscar:",
  LABEL_CATEGORY = "Categoría:",
  LABEL_SAVED_NOTES = "Notas Guardadas:",
  LABEL_NOTE_TITLE = "Título de Nota:",
  LABEL_TAGS = "Etiquetas (separadas por comas):",
  LABEL_NOTE_CONTENT = "Contenido de Nota:",
  LABEL_NOTES_COUNT = "Notas: %d/%d",
  LABEL_NOTES_SIMPLE = "Notas: %d",
  
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
  
  -- Dropdown Options
  DROPDOWN_SELECT = "-- Seleccionar Nota --",
  DROPDOWN_NO_MATCHES = "-- No se encontraron coincidencias --",
  
  -- Default Text
  DEFAULT_NOTE_TITLE = "Nueva Nota",
  DEFAULT_NOTE_BODY = "Ingresa tu nota aquí...",
  
  -- Button Labels
  BTN_SAVE = "Guardar",
  BTN_NEW = "Nueva",
  BTN_DELETE = "Eliminar",
  BTN_SAVE_MAIL = "Guardar Correo",
  BTN_OPEN_NOTEBOOK = "Abrir Cuaderno",
  
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "Haz clic para abrir la ventana del cuaderno (igual que el comando /sgtnote).",
  
  -- Settings
  SETTING_ENABLE = "Activar Módulo de Cuaderno",
  SETTING_ENABLE_TIP = "Activar/desactivar la función de Cuaderno.",
  SETTING_SEARCH = "Activar Filtro de Búsqueda",
  SETTING_SEARCH_TIP = "Permitir filtrado de notas por términos de búsqueda.",
  SETTING_DEFAULT_CATEGORY = "Categoría Predeterminada",
  SETTING_DEFAULT_CATEGORY_TIP = "Categoría predeterminada para nuevas notas. Usa 'Correo' para plantillas de correo.",
  
  -- Descriptions
  DESC_MAIN = "Un bloc de notas en el juego con todas las funciones con búsqueda, categorías y etiquetado. Usa |cFFD700/sgtnote|r para abrir la ventana del cuaderno.",
  DESC_MAIL_TEMPLATES = "Plantillas de correo: Guarda notas en la categoría 'Correo' para usarlas como plantillas tanto en el cliente de correo nativo como en el sistema de correo de hermandad.",
  
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "Plantillas de Correo:",
  MAIL_DROPDOWN_SELECT = "-- Seleccionar Plantilla --",
  
  -- Categories
  CAT_GENERAL = "General",
  CAT_MAIL = "Correo",
  CAT_EVENTS = "Eventos",
  CAT_ALL_CATEGORIES = "Todas las Categorías",
  
  ERROR_MAX_TOTAL_NOTES = "No se puede crear la nota: Se alcanzó el máximo total de notas (%d). Elimina algunas notas primero.",
  ERROR_MAX_CATEGORY_NOTES = "No se puede crear la nota: Se alcanzó el máximo de notas (%d) para la categoría '%s'.",
  ERROR_NOTE_TOO_LARGE = "La nota es demasiado grande (%d caracteres). El máximo es %d caracteres.",
  STATS_HEADER = "Estadísticas de Almacenamiento del Cuaderno Scrollkeeper",
  STATS_TOTAL = "Notas Totales: %d / %d",
  STATS_CATEGORY = " %s: %d / %d notas (~%.1f KB)",
  BTN_PREVIEW_MAIL = "Vista previa",
  PREVIEW_TITLE = "Vista previa del correo",
  ERROR_NO_BODY = "Por favor ingrese texto en el cuerpo",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES   = "(Usa 'Guardar correo' en el Cuaderno para añadir plantillas)",
  SETTING_GUILDMAIL_INJECT = "Mostrar selector de plantillas en el correo de hermandad",
  SETTING_GUILDMAIL_INJECT_TIP = "Muestra un selector de plantillas de correo del Cuaderno en la ventana de redacción de correo de hermandad.",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "Búsqueda de Historial de Hermandad",
  WINDOW_TITLE = "Búsqueda de Historial de Hermandad",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r ERROR: ¡Falta ScrollkeeperFramework!",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r Fallo al crear ventana",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r No hay eventos para exportar",
  
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r Listo - usa /sgthistory",
  
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r Cargando... SF.Data existe: %s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents al cargar: %s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents no disponible",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r Inicialización de respaldo activada",
  
  -- Window Labels
  LABEL_GUILD = "Hermandad:",
  LABEL_CATEGORY = "Categoría:",
  LABEL_SEARCH = "Buscar:",
  LABEL_EVENTS_COUNT = "Eventos: %d",
  LABEL_REFRESH = "Actualizar",
  LABEL_EXPORT = "Exportar",
  
  -- Status Messages
  STATUS_READY = "Listo",
  STATUS_READY_LOADED = "Listo - %d eventos cargados",
  STATUS_NO_GUILD = "No se seleccionó hermandad",
  STATUS_DATA_NOT_READY = "Módulo de datos no listo",
  STATUS_NO_EVENTS_CACHE = "No se encontraron eventos - el caché puede estar aún construyéndose. Asegúrate de que la categoría esté activa en LibHistoire.",
  STATUS_WAITING_LH = "Esperando a que LibHistoire se inicialice...",
  STATUS_ENABLE_GUILDS = "Activa hermandades en la configuración de Historial",
  
  -- Column Headers
  HEADER_TIME = "Tiempo",
  HEADER_CATEGORY = "Categoría",
  HEADER_EVENT = "Evento",
  HEADER_MEMBER = "Miembro",
  HEADER_DETAILS = "Detalles",
  
  -- Category Names
  CAT_ALL = "Todos los Eventos",
  CAT_ROSTER = "Lista",
  CAT_BANK_GOLD = "Oro del Banco",
  CAT_BANK_ITEMS = "Objetos del Banco",
  CAT_SALES = "Ventas",
  
  -- Event Type Names - Roster
  EVENT_INVITED = "Invitado",
  EVENT_JOINED = "Unido",
  EVENT_PROMOTED = "Promovido",
  EVENT_DEMOTED = "Degradado",
  EVENT_LEFT = "Abandonó",
  EVENT_KICKED = "Expulsado",
  EVENT_APP_ACCEPTED = "Solicitud Aceptada",
  
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "Oro Depositado",
  EVENT_GOLD_WITHDRAWN = "Oro Retirado",
  EVENT_TRADER_BID = "Oferta de Comerciante",
  EVENT_BID_RETURNED = "Oferta Devuelta",
  
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "Objeto Depositado",
  EVENT_ITEM_WITHDRAWN = "Objeto Retirado",
  
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "Objeto Vendido",
  
  -- Unknown Event
  EVENT_UNKNOWN = "Desconocido (%s)",
  
  -- Time Formatting
  TIME_JUST_NOW = "Justo ahora",
  TIME_MINUTES_AGO = "hace %dm",
  TIME_HOURS_AGO = "hace %dh",
  TIME_DAYS_AGO = "hace %dd",
  TIME_MONTHS_AGO = "hace %dme",
  
  -- Export Window
  EXPORT_TITLE = "Exportar Datos - Seleccionar y Copiar Texto",
  EXPORT_INSTRUCTION = "Haz clic en 'Seleccionar Todos' y luego usa Ctrl+C para copiar al portapapeles",
  EXPORT_SELECT_ALL = "Seleccionar Todos",
  EXPORT_HEADER = "Exportación de Historial de Hermandad para %s",
  EXPORT_GENERATED = "Generado: %s",
  EXPORT_CATEGORY = "Categoría: %s",
  EXPORT_TOTAL = "Total de Eventos: %d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
  
  -- Tooltips
  TIP_REFRESH = "Actualizar lista de hermandades y datos de eventos",
  TIP_EXPORT = "Exportar eventos visibles a texto",
  TIP_FULL_TIMESTAMP = "Marca de tiempo completa",
  TIP_FULL_DETAILS = "Detalles completos",
  
  -- Settings - Main
  SETTINGS_DESC = "Buscar eventos de historial de hermandad en caché. Usa |cFFD700/sgthistory|r para abrir la ventana de búsqueda.\n\nLos datos se almacenan automáticamente en caché para todas las hermandades por ScrollkeeperData. Aquí controlas qué hermandades y categorías mostrar en la ventana de búsqueda.",
  SETTINGS_DISPLAY = "Configuración de Visualización",
  SETTINGS_MAX_EVENTS = "Eventos Máximos",
  SETTINGS_MAX_EVENTS_TIP = "Número máximo de eventos a cargar a la vez",
  SETTINGS_SEARCH_DELAY = "Retraso de Búsqueda (ms)",
  SETTINGS_SEARCH_DELAY_TIP = "Retraso antes de que se ejecute la búsqueda mientras escribes",
  SETTINGS_COLOR_CODING = "Activar Codificación de Color",
  SETTINGS_COLOR_CODING_TIP = "Codificar eventos por color según el tipo",
  
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "Mostrar en Ventana de Historial",
  SETTINGS_SHOW_GUILD_TIP = "Mostrar esta hermandad en la ventana de búsqueda de historial",
  SETTINGS_CATEGORIES = "Categorías de Eventos a Mostrar",
  SETTINGS_ROSTER_EVENTS = "Eventos de Lista",
  SETTINGS_ROSTER_EVENTS_TIP = "Mostrar uniones de miembros, abandonos, promociones, expulsiones",
  SETTINGS_BANK_GOLD_EVENTS = "Eventos de Oro del Banco",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "Mostrar depósitos de oro, retiros, ofertas de comerciante",
  SETTINGS_BANK_ITEMS_EVENTS = "Eventos de Objetos del Banco",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "Mostrar depósitos y retiros de objetos",
  SETTINGS_SALES_EVENTS = "Eventos de Ventas",
  SETTINGS_SALES_EVENTS_TIP = "Mostrar ventas de la tienda de hermandad",
  
  -- Dropdown
  DROPDOWN_NO_GUILDS = "No hay hermandades activadas - ver configuración",
  
  -- Formatting
  FORMAT_GOLD = "%s oro",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "a %s",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "Esta es una donación registrada manualmente",
  NOTES_LABEL = "Notas",
  DELETE_MANUAL_ENTRY = "Eliminar esta entrada manual",
  SUCCESS_DELETED_ENTRY = "Entrada manual eliminada correctamente",
  ERROR_DELETE_FAILED = "Error al eliminar la entrada",
  
  -- Member Names
  MEMBER_UNKNOWN = "Desconocido",
    
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScroll no encontrado - usando desplazamiento básico",
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "Mejora de Lista",
  
  -- Settings
  SETTING_TRADER_TIMER = "Mostrar Temporizador de Cambio de Comerciante",
  SETTING_TRADER_TIMER_TIP = "Mostrar temporizador de cuenta regresiva que muestra el tiempo hasta el próximo cambio de comerciante de hermandad.\n\n" ..
                              "El color del temporizador indica urgencia:\n" ..
                              "• |c00FF0024+ hrs|r - Seguro\n" ..
                              "• |cFFFF006-24 hrs|r - Planificar con anticipación\n" ..
                              "• |cFF88002-6 hrs|r - Actuar pronto\n" ..
                              "• |cFF0000< 2 hrs|r - ¡Urgente!",

  -- Timer Display
  TIMER_LABEL = "Cambio de Comerciante: %s",
  TIMER_FLIPPING = "Cambiando ahora",
  TIMER_FORMAT = "%dh %dm",
  
  -- Full tooltip
  TOOLTIP_FULL = "Tiempo hasta el cambio de comerciante de hermandad\n\n" ..
                 "El color indica urgencia:\n" ..
                 "|c00FF0024+ horas|r - Seguro\n" ..
                 "|cFFFF006-24 horas|r - Planificar con anticipación\n" ..
                 "|cFF88002-6 horas|r - Actuar pronto\n" ..
                 "|cFF0000< 2 horas|r - ¡Urgente!",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r ERROR: ¡Falta ScrollkeeperFramework!",
  
  -- Tasks
  TASKS_HEADER = "Recordatorios de Tareas",
  TASKS_DESCRIPTION = "Los recordatorios de tareas se configuran por hermandad a continuación. Activa 'Mostrar Tareas en el Registro' para cada hermandad donde desees recordatorios.",
  CUSTOM_TASKS = "Tareas Personalizadas",
  CUSTOM_TASKS_DESC = "Agrega y configura tareas personalizadas. El panel de configuración no se actualizará hasta que recargues, pero la tarea se agregará o eliminará en tiempo real.",
  ADD_CUSTOM_TASK = "Añadir Tarea Personalizada",
  REMOVE = "Eliminar",

  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "Mostrar Tareas en el Registro",
  GUILD_TASKS_ENABLE_TIP = "Activar recordatorios de tareas para la página de registro de esta hermandad",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "Configurar recordatorios de tareas para %s",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "Tareas Predefinidas",

  -- Frequency settings
  FREQUENCY_NUMBER = "Frecuencia (número)",
  FREQUENCY_NUMBER_TIP = "Introduce el número de unidades de tiempo",
  FREQUENCY_UNIT = "Unidad",

  -- Task window
  TASK_WINDOW_TITLE = "Agregar Tarea Personalizada",
  TASK_WINDOW_NAME_LABEL = "Nombre de la Tarea:",
  TASK_WINDOW_FREQ_LABEL = "Frecuencia:",
  TASK_WINDOW_GUILD_LABEL = "Hermandades (selecciona múltiples o 'Todas'):",
  TASK_WINDOW_ADD = "Agregar Tarea",
  TASK_WINDOW_CANCEL = "Cancelar",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "Por favor introduce un nombre de tarea",
  ERROR_INVALID_FREQ_NUMBER = "Por favor introduce un número válido para la frecuencia",
  ERROR_NO_FREQ_UNIT = "Por favor selecciona una unidad de frecuencia",

  -- Task completion messages
  TASK_COMPLETED = "Tarea completada: %s",
  TASK_ADDED = "Tarea agregada: %s (hermandad: %s, activada: verdadero, esPersonalizada: verdadero)",
  TASK_REMOVED = "Tarea eliminada: %s",
  ERROR_PRESET_REMOVE = "Las tareas predefinidas no se pueden eliminar. Desactívalas en la configuración en su lugar.",

  -- Task list display
  TASK_STATUS_OVERDUE = "VENCIDA",

  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "Clic izquierdo: Completar tarea",
  TASK_TOOLTIP_RIGHT = "Clic derecho: Eliminar tarea",

  PRESET_REVIEW_APPLICATIONS = "Revisar Solicitudes",
  PRESET_CHECK_BANK_DEPOSITS = "Verificar Depósitos del Banco",
  PRESET_UPDATE_MOTD = "Actualizar Mensaje del Día",
  PRESET_PROMOTE_PROBATIONARY = "Promover Probatorios",
  PRESET_REVIEW_INACTIVES = "Revisar Inactivos",

  TASK_COLOR_LEGEND = "Leyenda de colores - Tiempo restante:\n|c00FF00>25%|r - Seguro\n|cFFFF0010-25%|r - Planificar con anticipación\n|cFF88005-10%|r - Actuar pronto\n|cFF0000<5% o vencida|r - ¡Urgente!",
    
  -- Remove Button
  REMOVE_CUSTOM_TASK = "Eliminar Tarea Personalizada",
  REMOVE_CUSTOM_TASK_TIP = "Selecciona una tarea personalizada para eliminar permanentemente",
  REMOVE_WARNING = "ADVERTENCIA: ¡La eliminación es permanente! Para restaurar una tarea, debes agregarla nuevamente de forma manual.",
  REMOVE_INSTRUCTION = "Haz clic en una tarea a continuación para eliminarla:",
  REMOVE_WINDOW_CANCEL = "Cancelar",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "Opciones de Menú Contextual",
  DESCRIPTION = "Agrega entradas de nuevo correo, invitación a hermandad e invitación a chat a todos los menús contextuales de clic derecho.",
  MASTER_ENABLE = "Activar Funciones de Menú Contextual",
  MASTER_ENABLE_TIP = "Interruptor maestro para todas las mejoras del menú contextual.",
  SF_UNAVAILABLE = "ERROR: ¡Falta ScrollkeeperFramework!",
  
  -- Headers
  SCROLLKEEPER_TOOLS = "Herramientas de Scrollkeeper",
  CHAT_HEADER = "Opciones de Chat",
  ROSTER_HEADER = "Opciones de Lista de Hermandad",
  
  -- Options
  NEW_MAIL = "Nuevo Correo",
  NEW_MAIL_TIP = "Agregar opción 'Nuevo Correo' a los menús contextuales de chat.",
  GUILD_INVITE = "Invitación a Hermandad",
  GUILD_INVITE_TIP = "Agregar opciones de invitación a hermandad a los menús contextuales de chat.",
  ROSTER_DESC = "Agrega integración de cuaderno al menú de clic derecho de la lista de hermandad.",
  NOTEBOOK_CONTEXT = "Activar Menú Contextual de Cuaderno",
  NOTEBOOK_CONTEXT_TIP = "Haz clic derecho en miembros de hermandad para abrir o crear entradas de cuaderno.",
  ROSTER_INVITE = "Invitación a Hermandad desde Lista",
  ROSTER_INVITE_TIP = "Agregar opciones de invitación a hermandad a los menús contextuales de la lista de hermandad.",
  
  -- Context Menu Items
  INVITE_TO = "Invitar a %s",
  GO_TO_NOTEBOOK = "Ir a Entrada de Cuaderno",
  MAKE_NOTE = "Crear Nota en Cuaderno",
  
  -- Messages
  NOTEBOOK_NOT_FOUND = "Módulo de cuaderno no encontrado.",
  NOTE_EXISTS = "La nota ya existe para %s.",
  NOTE_CREATED = "Nota creada para %s en Cuaderno.",
  OPEN_NOTE = "Abrir Entrada de Cuaderno",
  CREATE_NOTE = "Crear Nota en Cuaderno",
  LOG_CONVERSATION = "Registrar Chat Reciente",
  CONVERSATION_LOGGED = "Registrados %d mensajes recientes de %s en el Cuaderno bajo la categoría 'Chat'",
  NO_CONVERSATION = "No se encontró chat reciente relacionado con %s en los últimos 100 mensajes.",
  LOG_CONVERSATIONS = "Activar Registro de Conversaciones",
  LOG_CONVERSATIONS_TIP = "Registrar conversaciones de chat en el Cuaderno (requiere addon pChat).",
  PCHAT_WARNING = "Addon pChat no detectado - esta función no funcionará",
  
  -- Mail Logging
  LOG_DONATION = "Registrar Donación",
  LOG_DONATION_TIP = "Registrar manualmente una donación para este miembro",
  DONATION_WINDOW_TITLE = "Registrar Donación Manual",
  DONATION_PLAYER = "Miembro",
  DONATION_GUILD = "Hermandad",
  DONATION_VALUE_LABEL = "Valor en Oro",
  DONATION_VALUE_TIP = "Introduce el valor en oro de esta donación (para objetos, introduce su valor estimado)",
  DONATION_NOTES_LABEL = "Notas (Opcional)",
  DONATION_NOTES_TIP = "Detalles adicionales como 'Enviado 50 Cera de Dreugh por correo' o 'Oro enviado el 25/12'",
  DONATION_TYPE_LABEL = "Tipo de Donación",
  DONATION_TYPE_GOLD = "Oro (Correo)",
  DONATION_TYPE_ITEMS = "Objetos (Valorados)",
  BTN_RECORD_DONATION = "Registrar Donación",
  BTN_CANCEL = "Cancelar",
  SUCCESS_DONATION_LOGGED = "Donación de %d oro registrada para %s",
  ERROR_INVALID_AMOUNT = "Por favor introduce una cantidad de oro válida",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "Servicio de almacenamiento en caché en segundo plano para datos de historial de hermandad usando LibHistoire.",
  
  -- Status Messages
  HISTOIRE_READY = "LibHistoire listo - almacenando en caché todo el historial de hermandad",
  CACHE_STATUS = "=== Estado del Caché de Eventos ===",
  NO_CACHED_DATA = "No se encontraron datos en caché",
  CACHE_EMPTY = "El caché está vacío - esto puede tomar unos minutos en la primera carga",
  WAITING_FOR_HISTOIRE = "Esperando a que LibHistoire se inicialice...",
  
  -- Log Messages
  EVENTS_CACHED = "%s/%s: %d eventos en caché",
  STARTED_CACHING = "Iniciado almacenamiento en caché de %d hermandades",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r Cargado - servicio de almacenamiento en caché en segundo plano",
  LOG_MANUAL_DONATION = "%s - %d oro registrado manualmente",
  MANUAL_DONATION_SOURCE = "Entrada Manual",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r ERROR: ¡Falta ScrollkeeperFramework!",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r CRÍTICO: ¡SF.Data no es una tabla!",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r ERROR: ¡No se encontró LibHistoire!",
  
  -- Cache Display
  GUILD_HEADER = "%s:",
  CATEGORY_LINE = "  %s: %d eventos",
  HISTOIRE_STATUS = "LibHistoire listo: %s",
  
  -- Category Names (for display)
  CAT_ROSTER = "lista",
  CAT_BANKED_GOLD = "oroBanco",
  CAT_BANKED_ITEMS = "objetosBanco",
  CAT_SALES = "ventas",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r Registrado: %d oro de %s a %s",
  
  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Faltan parámetros requeridos",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r Entrada manual eliminada exitosamente de caché y almacenamiento",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Entrada no encontrada",
  
  -- Debug cache messages
  DEBUG_NO_GUILD = "[Depuración de Datos] Gremio no especificado",
  DEBUG_NO_CACHE_FOR_GUILD = "[Depuración de Datos] Sin caché para gremio: %s",
  DEBUG_AVAILABLE_GUILDS = "[Depuración de Datos] Gremios disponibles:",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[Depuración de Datos] Caché para %s:",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold: %d eventos",
  DEBUG_RECENT_DEPOSITS = "  Depósitos recientes:",
  DEBUG_NO_DEPOSITS = "  No se encontraron depósitos",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold: NO PRESENTE",
  DEBUG_ROSTER_COUNT = "  roster: %d eventos",
  DEBUG_ROSTER_MISSING = "  roster: NO PRESENTE",
  
  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "Módulo de datos o función de verificación no disponible",
  CMD_CHECKGOLD_USAGE = "Uso: /sgtcheckgold NombreGremio|@NombreUsuario|Días",
  CMD_CHECKGOLD_EXAMPLE = "Ejemplo: /sgtcheckgold Dragon's Nest Thievery Co|@TuNombre|14",
  CMD_CHECKGOLD_RESULT = "%s donó %d oro en los últimos %d días (%s)",
  
  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r ERROR: LibHistoire no encontrado",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "Mensajes de Bienvenida",
  DESCRIPTION = "Configura mensajes de bienvenida para miembros de la hermandad. Usa %1 para el nombre del jugador y %2 para el nombre de la hermandad. Los mensajes se pondrán en cola al aceptar múltiples solicitudes o si el campo de texto está activo.",
  MASTER_ENABLE = "Activar Mensajes de Bienvenida",
  MASTER_ENABLE_TIP = "Activar o desactivar todos los mensajes de bienvenida.",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %s se unió a %s como %s",
  
  -- Template
  TEMPLATE_HEADER = "Variables de Plantilla",
  VAR_PLAYER = "%1 - Nombre del Miembro",
  VAR_GUILD = "%2 - Nombre de la Hermandad",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Activar para esta Hermandad",
  MESSAGE_TEMPLATE = "Plantilla de Mensaje",
  PREVIEW = "Vista Previa: %s",
  DEFAULT_MESSAGE = "Bienvenido %1 a %2",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "Comandos de Chat y Utilidades",
  DESCRIPTION = "Comandos de utilidad adicionales y soporte de asignación de teclas para Scrollkeeper.",
  
  -- Headers
  COMMANDS_HEADER = "Comandos Disponibles",
  UTILITY_HEADER = "Comandos de Utilidad",
  STATUS_HEADER = "Comandos de Estado",
  MODULE_HEADER = "Comandos de Módulo",
  DEBUG_HEADER = "Comandos de Depuración",
  
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - Mostrar información de depuración del sistema",
  CMD_SKTEST = "|cf3ebd1/sktest <opción>|r - Ejecutar pruebas de módulo (opciones: context, settings, notebook, mail, data)",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - Alternar ventana de cuaderno",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - Abrir ventana de correo",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - Abrir ventana de búsqueda de historial",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - Abrir ventana de miembros provisionales",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - Mostrar estado del caché de eventos",
  CMD_ROLL = "|cf3ebd1/roll <número>|r - Lanzar dados (ejemplo: /roll 20)",
  CMD_DICE = "|cf3ebd1/dice <número>|r - Igual que /roll",
  CMD_RL = "|cf3ebd1/rl|r - Recargar interfaz",
  CMD_ON = "|cf3ebd1/on|r - Establecer estado en Conectado",
  CMD_OFF = "|cf3ebd1/off|r - Establecer estado en Desconectado",
  CMD_AFK = "|cf3ebd1/afk|r - Establecer estado en Ausente",
  CMD_DND = "|cf3ebd1/dnd|r - Establecer estado en No Molestar",
  CMD_OFFL = "|cf3ebd1/offl|r - Alternar Conectado/Desconectado",
  
  -- Full command list
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - Alternar ventana de cuaderno\n" ..
                "|cf3ebd1/sgtmail|r - Abrir ventana de correo\n" ..
                "|cf3ebd1/sgthistory|r - Abrir búsqueda de historial\n" ..
                "|cf3ebd1/sgtprovision|r - Abrir ventana de miembros provisionales\n" ..
                "|cf3ebd1/roll <número>|r - Lanzar dados\n" ..
                "|cf3ebd1/rl|r - Recargar interfaz\n" ..
                "|cf3ebd1/on /off /afk /dnd|r - Establecer estado del miembro\n" ..
                "|cf3ebd1/offl|r - Alternar desconectado\n" ..
                "|cf3ebd1/skdebug|r - Mostrar info de depuración\n" ..
                "|cf3ebd1/sgtcache|r - Mostrar estado del caché",
				"|cf3ebd1/sgtcheckpm NombreHermandad|@NombreUsuario|r - Depurar verificación de donación de oro para un miembro específico\n" ..
				"|cf3ebd1/sgtattendance start [nombre evento]|r - Iniciar seguimiento\n" ..
				"|cf3ebd1/sgtattendance stop|r - Detener y guardar informe\n" ..
				"|cf3ebd1/sgtattendance status|r - Mostrar información de sesión actual" ..
				"|cf3ebd1/sgttask add <nombre>|<frecuencia>|<hermandad>|r para añadir una tarea personalizada" ..
				"|cf3ebd1/sgttask list|r - Mostrar todas las tareas con estado" ..
				"|cf3ebd1/sgttask complete <número>|r - Marcar tarea como completada",
  
  -- Buttons
  TEST_BUTTON = "Probar Todos los Sistemas",
  TEST_BUTTON_TIP = "Ejecutar una prueba exhaustiva de todos los módulos de Scrollkeeper",
  
  -- Status Messages
  STATUS_ONLINE = "Estado establecido en Conectado",
  STATUS_OFFLINE = "Estado establecido en Desconectado",
  STATUS_DND = "Estado establecido en No Molestar",
  STATUS_AWAY = "Estado establecido en Ausente",
  STATUS_CHANGED = "Scrollkeeper: Estado establecido en %s",
  STATUS_TOGGLED = "Ventana de cuaderno alternada",
  
  -- Roll Messages
  ROLL_USAGE = "Uso: /roll <máx>",
  ROLL_EXAMPLE = "Ejemplo: /roll 20",
  ROLL_INVALID = "Número inválido: %s",
  ROLL_OUTPUT = "lanzó %d (1-%d)",
  
  -- Debug Messages
  DEBUG_HEADER = "=== Info de Depuración de Scrollkeeper ===",
  DEBUG_FRAMEWORK = "Framework cargado: %s",
  DEBUG_SETTINGS = "Tabla de configuración: %s",
  DEBUG_LAM = "LAM2 disponible: %s",
  DEBUG_FUNC = "SF.func disponible: %s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings: %s",
  DEBUG_PANEL = "Panel registrado: %s",
  DEBUG_MODULE = "Módulo: %s - Controles: %d - Icono: %s",
  DEBUG_TOTAL_MODULES = "Total de módulos registrados: %d",
  DEBUG_NO_MODULES = "No se encontró configuración de módulos",
  DEBUG_CONTEXT = "Menú contextual activado: %s",
  DEBUG_NOTEBOOK = "Módulo de cuaderno: %s",
  DEBUG_DATA = "Módulo de datos: %s",
  DEBUG_HISTOIRE = "LibHistoire: %s",
  DEBUG_DATETIME = "LibDateTime: %s",
  
  -- Test Messages
  TEST_HEADER = "=== Comandos de Prueba de Scrollkeeper ===",
  TEST_USAGE = "Uso: /sktest <opción>",
  TEST_OPTIONS = "Opciones: context, settings, notebook, mail, data, attendance",
  TEST_RUNNING = "Ejecutando prueba exhaustiva del sistema...",
  TEST_UNKNOWN = "Opción de prueba desconocida: %s",
  TEST_AVAILABLE = "Opciones disponibles: context, settings, notebook, mail, data, attendance",
  
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== Prueba de Menú Contextual ===",
  TEST_CONTEXT_ACTIVE = "El gancho del menú contextual está activo",
  TEST_CONTEXT_ENABLED = "Menú contextual activado en configuración: %s",
  TEST_CONTEXT_MAIL = "Opción de nuevo correo en chat: %s",
  TEST_CONTEXT_INVITE = "Opción de invitación en chat: %s",
  TEST_CONTEXT_NOT_LOADED = "Módulo ScrollkeeperContextMenu no cargado",
  TEST_CONTEXT_FAILED = "Gancho del menú contextual FALLÓ - CHAT_SYSTEM no disponible",
  
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== Prueba de Configuración ===",
  TEST_SETTINGS_ACCESSIBLE = "Configuración de %s accesible: %s",
  TEST_SETTINGS_PANEL = "Panel de configuración está registrado",
  TEST_SETTINGS_NO_PANEL = "Panel de configuración no registrado",
  TEST_SETTINGS_NO_ACCESS = "No se puede acceder a la configuración del módulo - problema del framework",
  
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== Prueba de Cuaderno ===",
  TEST_NOTEBOOK_LOADED = "Módulo de cuaderno cargado",
  TEST_NOTEBOOK_ENABLED = "Activado: %s",
  TEST_NOTEBOOK_WINDOW = "Ventana de cuaderno existe: %s",
  TEST_NOTEBOOK_SAVE = "Prueba de guardado de nota: %s",
  TEST_NOTEBOOK_NOT_LOADED = "Módulo de cuaderno no cargado",
  
  -- Test: Mail
  TEST_MAIL_HEADER = "=== Prueba de Módulo de Correo ===",
  TEST_MAIL_LOADED = "Módulo de correo cargado",
  TEST_MAIL_ENABLED = "Activado: %s",
  TEST_MAIL_WINDOW = "Ventana de correo existe: %s",
  TEST_MAIL_COMMAND = "Comando /sgtmail registrado",
  TEST_MAIL_NO_COMMAND = "Comando /sgtmail no registrado",
  TEST_MAIL_NOT_LOADED = "Módulo de correo no cargado",
  
  -- Test: Data
  TEST_DATA_HEADER = "=== Prueba de Módulo de Datos ===",
  TEST_DATA_LOADED = "Módulo de datos cargado",
  TEST_DATA_LH_AVAILABLE = "LibHistoire disponible",
  TEST_DATA_CACHE_ACCESSIBLE = "Caché de eventos accesible: %s",
  TEST_DATA_RECORDS = "Total de registros de eventos en caché: %d",
  TEST_DATA_NO_FUNCTIONS = "Funciones de datos no disponibles",
  TEST_DATA_NO_LH = "LibHistoire no disponible",
  TEST_DATA_NOT_LOADED = "Módulo de datos no cargado",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r ERROR: ¡Falta ScrollkeeperFramework!",
  ERROR_NOTEBOOK_DISABLED = "El cuaderno está desactivado en la configuración",
  ERROR_NOTEBOOK_NO_WINDOW = "Ventana de cuaderno no disponible",
  ERROR_NOTEBOOK_NOT_LOADED = "Módulo de cuaderno no cargado",
  
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r Registrando comandos de barra...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r Comandos de barra registrados",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r Inicializando...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r Inicialización completa",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "Asistencia a Eventos",
  
  -- Description
  DESCRIPTION = "Rastrear asistencia a eventos con detección automática de llegadas tarde/tempranas.",
  
  -- Settings
  MASTER_ENABLE = "Habilitar Seguimiento de Asistencia a Eventos",
  MASTER_ENABLE_TIP = "Habilitar funciones y comandos de seguimiento de asistencia",
  
  -- Headers
  HEADER_COMMANDS = "Comandos y Uso",
  HEADER_HISTORY = "Historial de Sesiones",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [nombre] - Comenzar seguimiento\n/sgtattendance stop - Finalizar y guardar\n/sgtattendance status - Verificar sesión actual",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== Comandos de Seguimiento de Asistencia ===",
  HELP_START = "/sgtattendance start [nombre evento] - Iniciar seguimiento",
  HELP_STOP = "/sgtattendance stop - Detener y guardar informe",
  HELP_STATUS = "/sgtattendance status - Mostrar información de sesión actual",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "Seguimiento iniciado: %s (%d miembros presentes)",
  SUCCESS_TRACKING_STOPPED = "Seguimiento detenido: %s",
  SUCCESS_SAVED_TO_NOTEBOOK = "Informe de asistencia guardado en la categoría 'Eventos' del Cuaderno como '%s'",
  SUCCESS_HISTORY_CLEARED = "Historial de asistencia borrado",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "¡Ya se está rastreando un evento! Usa /sgtattendance stop primero.",
  ERROR_NO_ACTIVE_SESSION = "No hay sesión de seguimiento activa.",
  ERROR_UNKNOWN_COMMAND = "Comando desconocido. Usa /sgtattendance help",
  ERROR_NOT_SAVED = "Advertencia: No se pudo guardar en el Cuaderno.",
  ERROR_NOTEBOOK_DISABLED = "Cuaderno no disponible - informe guardado solo en historial de asistencia",
  
  -- Status messages
  STATUS_NO_SESSION = "No hay sesión de seguimiento activa",
  STATUS_ACTIVE = "Rastreando: %s | Duración: %d min | Asistentes: %d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%s se unió al evento (%d minutos tarde)",
  LOG_MEMBER_LEFT = "%s dejó el evento (presente durante %d minutos)",
  
  -- Report sections
  REPORT_HEADER = "Informe de Asistencia: %s",
  REPORT_TIME = "Hora: %s a %s",
  REPORT_SUMMARY = "Total de Asistentes: %d | Asistencia Completa: %d | Llegadas Tarde: %d | Salidas Tempranas: %d",
  
  SECTION_FULL_ATTENDANCE = "Asistencia Completa",
  SECTION_ON_TIME = "A Tiempo",
  SECTION_LATE = "Llegadas Tarde",
  SECTION_LEFT_EARLY = "Salidas Tempranas",
  
  -- History display
  NO_SESSIONS = "Aún no hay sesiones rastreadas",
  SESSIONS_COUNT = "Sesiones Rastreadas: %d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "Borrar Historial",
  BTN_CLEAR_HISTORY_TIP = "Eliminar todas las sesiones de asistencia guardadas",
  WARNING_CLEAR_HISTORY = "¡Esto eliminará permanentemente todos los registros de asistencia!",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "Solicitudes de Gremio",
  DESCRIPTION = "Registra automáticamente las solicitudes de gremio en tu Cuaderno para mantener un registro. Las solicitudes se guardan con detalles completos, incluido el mensaje del solicitante.",
  
  -- Settings
  MASTER_ENABLE = "Habilitar Registro de Solicitudes",
  MASTER_ENABLE_TIP = "Interruptor principal para la funcionalidad de registro de solicitudes",
  AUTO_LOG = "Registrar Automáticamente Nuevas Solicitudes",
  AUTO_LOG_TIP = "Cuando está habilitado, las nuevas solicitudes de gremio se guardan automáticamente en el Cuaderno",
  SHOW_NOTIFICATIONS = "Mostrar Notificaciones en Chat",
  SHOW_NOTIFICATIONS_TIP = "Mostrar un mensaje en el chat cuando se registren solicitudes",
  
  -- Guild settings
  HEADER_GUILDS = "Configuración por Gremio",
  GUILDS_DESC = "Elige para qué gremios registrar solicitudes:",
  GUILD_TOGGLE_TIP = "Registrar solicitudes para %s",

  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r El módulo de Cuaderno no está disponible. No se pueden registrar solicitudes.",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r ADVERTENCIA: Módulo de Cuaderno no cargado. El registro de solicitudes no funcionará.",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r Solicitud de |cFFD700%s|r para |cFFD700%s|r registrada",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r Error al guardar la solicitud de %s",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r %d solicitudes para |cFFD700%s|r registradas",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization