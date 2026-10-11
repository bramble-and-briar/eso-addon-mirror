--[[
    lang/es.lua
    Textos en español. Debe tener las mismas claves que lang/en.lua, que es el idioma base.
    Los nombres de las claves no se traducen.
]]

ValuesBars.RegisterLanguage("es", {
    -- Encabezados del menú
    MENU_HEADER_GENERAL = "General",
    MENU_HEADER_TEXT = "Texto y valores",
    MENU_HEADER_PLAYER_BARS = "Barras del personaje",
    MENU_HEADER_ULTIMATE = "Habilidad máxima",

    -- General
    MENU_SHOW_VALUES = "Mostrar valores",
    MENU_SHOW_VALUES_TT = "Muestra u oculta los valores numéricos sobre las barras.",
    MENU_PREVIEW = "Mostrar vista previa",
    MENU_PREVIEW_TT =
    "Muestra las barras de salud, magia, aguante y experiencia, y la barra de acciones, en este menú para ver los cambios. Se desactiva al cerrarlo.",

    -- Texto y valores
    MENU_FONT_SIZE = "Tamaño de fuente",
    MENU_FONT_SIZE_TT = "Tamaño del texto sobre las barras.",
    MENU_CONTRAST = "Mejorar contraste",
    MENU_CONTRAST_TT =
    "Añade sombra o contorno al texto para leerlo mejor sobre fondos claros, especialmente cuando se muestra fuera de las barras. También se aplica dentro de ellas.",
    MENU_CONTRAST_SOFT_THIN = "Sombra suave fina",
    MENU_CONTRAST_SOFT_THICK = "Sombra suave gruesa",
    MENU_CONTRAST_SHADOW = "Sombra",
    MENU_CONTRAST_OUTLINE = "Contorno grueso",
    MENU_NUMBER_FORMAT = "Formato de números",
    MENU_NUMBER_FORMAT_TT = "Añade un separador de miles. \nCon separador (12,345)\nSin separador (12345)",
    MENU_NUMBER_FORMAT_SEPARATED = "Con separador",
    MENU_NUMBER_FORMAT_PLAIN = "Sin separador",
    MENU_SHOW_PERCENT = "Mostrar porcentaje",
    MENU_SHOW_PERCENT_TT = "Muestra el porcentaje junto al valor, por ejemplo 10,000 / 20,000 (50%).",

    -- Barras del personaje
    MENU_PLAYER_POSITION = "Posición en barras del personaje",
    MENU_PLAYER_POSITION_TT =
    "Salud, magia y aguante: valor dentro, por encima o por debajo de las barras. El resto de barras siempre muestra el valor dentro.",
    MENU_POSITION_INSIDE = "Dentro",
    MENU_POSITION_ABOVE = "Por encima",
    MENU_POSITION_BELOW = "Por debajo",
    MENU_TEXT_GAP = "Separación del texto",
    MENU_TEXT_GAP_TT = "Distancia entre el texto y la barra cuando se muestra por encima o por debajo.",
    MENU_MAGICKA_ALIGN = "Alineación en barra de magia",
    MENU_MAGICKA_ALIGN_TT = "Posición horizontal del texto en la barra de magia, dentro, encima o debajo de ella.",
    MENU_STAMINA_ALIGN = "Alineación en barra de aguante",
    MENU_STAMINA_ALIGN_TT = "Posición horizontal del texto en la barra de aguante, dentro, encima o debajo de ella.",
    MENU_XP_ALIGN = "Alineación en barra de experiencia",
    MENU_XP_ALIGN_TT = "Posición horizontal del texto dentro de la barra de experiencia.",
    MENU_ALIGN_CENTER = "Centrado",
    MENU_ALIGN_LEFT = "A la izquierda",
    MENU_ALIGN_RIGHT = "A la derecha",

    -- Habilidad máxima
    MENU_ULTIMATE_SHOW = "Mostrar porcentaje de habilidad máxima",
    MENU_ULTIMATE_SHOW_TT =
    "Muestra sobre el botón de la habilidad máxima el porcentaje de carga.",
    MENU_ULTIMATE_POSITION = "Posición",
    MENU_ULTIMATE_POSITION_TT = "Lugar del porcentaje dentro del botón de la habilidad máxima.",
    MENU_ULTIMATE_TOP = "Arriba",
    MENU_ULTIMATE_CENTER = "Centro",
    MENU_ULTIMATE_BOTTOM = "Abajo",
})
