TamrielCalendar = TamrielCalendar or {}
local TC = TamrielCalendar

local es = {
    days = {"Sandas", "Morndas", "Tirdas", "Middas", "Turdas", "Fredas", "Loredas"},
    shortDays = {"Sa", "Mo", "Ti", "Mi", "Tu", "Fr", "Lo"},
    months = {"Estrella del Alba", "Amanecer", "Semilla Primera", "Mano de Lluvia", "Segunda Semilla", "Mitad del Año", "Cénit del Sol", "Última Semilla", "Fuego del Hogar", "Helada", "Ocaso", "Estrella del Sur"},
    realMonths = {"Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"},
    signs = {"El Ritual", "El Amante", "El Señor", "El Mago", "La Sombra", "El Corcel", "El Aprendiz", "El Guerrero", "La Dama", "La Tower", "El Atromach", "El Ladrón", "El Serpiente"},
    moonPhases = {"Luna nueva", "Luna creciente", "Cuarto creciente", "Gibosa creciente", "Luna llena", "Gibosa menguante", "Cuarto menguante", "Luna menguante"},
    yearSuffix = "2.ª Era",
    monthPrefix = "Mes de",
    signPrefix = "Signo:",
    stripFormat = "%s, %d de %s %d | %s | %02d:%02d",
    titleHoliday = "Festividad:",
    btnPrev = "Anterior",
    btnNext = "Siguiente",
    hNames = {
        nl = "Nueva Vida",
        hd = "Día del Corazón",
        aj = "Aniversario ESO",
        jd = "Día del Bufón",
        my = "Midyear",
        wf = "Festival de las Brujas"
    }
}

for k, v in pairs(es) do
    TC.L[k] = v
end

ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_UI", "Mostrar/Ocultar barra")
ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_WINDOW", "Abrir calendario grande")

-- Settings Panel Strings (ES)
ZO_CreateStringId("SI_TC_SECTION_APPEARANCE", "Apariencia de la barra")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_NAME", "Anchura automática")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_TIP", "La barra ajusta automáticamente su anchura a la longitud del texto.")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_NAME", "Anchura fija (px)")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_TIP", "Solo funciona si la anchura automática está desactivada.")
ZO_CreateStringId("SI_TC_STRIP_HEIGHT_NAME", "Altura de la barra (px)")
ZO_CreateStringId("SI_TC_STRIP_ALPHA_NAME", "Opacidad del fondo (%)")
ZO_CreateStringId("SI_TC_STRIP_LOCK_NAME", "Bloquear barra")
ZO_CreateStringId("SI_TC_STRIP_LOCK_TIP", "Bloquea la barra para evitar moverla accidentalmente.")

ZO_CreateStringId("SI_TC_SECTION_FONT", "Ajustes de fuente y texto")
ZO_CreateStringId("SI_TC_TEXT_COLOR_NAME", "Color del texto")
ZO_CreateStringId("SI_TC_TEXT_COLOR_TIP", "Elige el color del texto en la barra.")
ZO_CreateStringId("SI_TC_FONT_FAMILY_NAME", "Familia tipográfica")
ZO_CreateStringId("SI_TC_FONT_SIZE_NAME", "Tamaño de fuente (px)")
ZO_CreateStringId("SI_TC_FONT_STYLE_NAME", "Estilo de sombra / contorno")

-- Font Dropdown Choices
ZO_CreateStringId("SI_TC_FONT_CHOICE_BOLD", "Sistema Negrita (Univers Bold)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_REGULAR", "Sistema Estándar (Univers Regular)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_MEDIUM", "Sistema Medio (Univers Medium)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_GAME", "Fuente de la IU del juego")
ZO_CreateStringId("SI_TC_FONT_CHOICE_ANTIQUE", "Libro / Pergaminos (Antigua)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_HANDWRITTEN", "Manuscrita / Notas")
ZO_CreateStringId("SI_TC_FONT_CHOICE_STONE", "Tabla de piedra / Títulos")

-- Shadow Dropdown Choices
ZO_CreateStringId("SI_TC_STYLE_CHOICE_SOFT", "Sombra suave (Recomendado)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_HARD", "Sombra marcada")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_OUTLINE", "Contorno (Outline)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_THIN", "Sombra fina")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_NONE", "Sin sombra")

-- Elements Toggles
ZO_CreateStringId("SI_TC_SECTION_ELEMENTS", "Elementos mostrados")
ZO_CreateStringId("SI_TC_SHOW_WDAY_NAME", "Día de la semana")
ZO_CreateStringId("SI_TC_SHOW_WDAY_TIP", "Mostrar el día de la semana (Sundas, Morndas...)")
ZO_CreateStringId("SI_TC_SHOW_DATE_NAME", "Día y mes")
ZO_CreateStringId("SI_TC_SHOW_DATE_TIP", "Mostrar el día y el mes (14 Estrella del Alba...)")
ZO_CreateStringId("SI_TC_SHOW_YEAR_NAME", "Año y era")
ZO_CreateStringId("SI_TC_SHOW_YEAR_TIP", "Mostrar el año (582 de la 2.ª Era)")
ZO_CreateStringId("SI_TC_SHOW_SIGN_NAME", "Signo del zodiaco")
ZO_CreateStringId("SI_TC_SHOW_SIGN_TIP", "Mostrar la constelación actual (Signo: El Ritual...)")
ZO_CreateStringId("SI_TC_SHOW_TIME_NAME", "Hora de Tamriel")
ZO_CreateStringId("SI_TC_SHOW_TIME_TIP", "Mostrar la hora del juego (horas y minutos)")