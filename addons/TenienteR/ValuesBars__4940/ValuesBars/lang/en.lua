--[[
    lang/en.lua
    Textos en inglés. Debe tener exactamente las mismas claves que lang/es.lua.
    Los nombres de las claves no se traducen.
]]

ValuesBars.RegisterLanguage("en", {
    -- Encabezados del menú
    MENU_HEADER_GENERAL = "General",
    MENU_HEADER_TEXT = "Text and Values",
    MENU_HEADER_PLAYER_BARS = "Character Bars",
    MENU_HEADER_ULTIMATE = "Ultimate",

    -- General
    MENU_SHOW_VALUES = "Show Values",
    MENU_SHOW_VALUES_TT = "Shows or hides the numeric values on bars.",
    MENU_PREVIEW = "Show Preview",
    MENU_PREVIEW_TT =
    "Shows health, magicka, stamina, experience and action bars in this menu so you can see your changes. Turns off when the menu is closed.",

    -- Texto y valores
    MENU_FONT_SIZE = "Font Size",
    MENU_FONT_SIZE_TT = "Text size on bars.",
    MENU_CONTRAST = "Improve Contrast",
    MENU_CONTRAST_TT =
    "Adds a shadow or outline to the text so it's easier to read on light backgrounds, especially when it's displayed outside the bars. It also applies inside them.",
    MENU_CONTRAST_SOFT_THIN = "Thin Soft Shadow",
    MENU_CONTRAST_SOFT_THICK = "Thick Soft Shadow",
    MENU_CONTRAST_SHADOW = "Shadow",
    MENU_CONTRAST_OUTLINE = "Thick Outline",
    MENU_NUMBER_FORMAT = "Number Format",
    MENU_NUMBER_FORMAT_TT = "Adds a thousands divider. \nWith divider (12,345)\nWithout divider (12345)",
    MENU_NUMBER_FORMAT_SEPARATED = "With Divider",
    MENU_NUMBER_FORMAT_PLAIN = "Without Divider",
    MENU_SHOW_PERCENT = "Show Percentage",
    MENU_SHOW_PERCENT_TT = "Shows the percentage next to the value, for example 10,000 / 20,000 (50%).",

    -- Barras del personaje
    MENU_PLAYER_POSITION = "Text Position on Character Bars",
    MENU_PLAYER_POSITION_TT =
    "Health, magicka and stamina: value inside, above or below the bars. All other bars always show the value inside.",
    MENU_POSITION_INSIDE = "Inside",
    MENU_POSITION_ABOVE = "Above",
    MENU_POSITION_BELOW = "Below",
    MENU_TEXT_GAP = "Text Spacing",
    MENU_TEXT_GAP_TT = "Distance between the text and the bar when it is shown above or below.",
    MENU_MAGICKA_ALIGN = "Magicka Bar Alignment",
    MENU_MAGICKA_ALIGN_TT = "Horizontal text position of the magicka bar, whether inside, above or below it.",
    MENU_STAMINA_ALIGN = "Stamina Bar Alignment",
    MENU_STAMINA_ALIGN_TT = "Horizontal text position of the stamina bar, whether inside, above or below it.",
    MENU_XP_ALIGN = "Experience Bar Alignment",
    MENU_XP_ALIGN_TT = "Horizontal text position inside the experience bar.",
    MENU_ALIGN_CENTER = "Centered",
    MENU_ALIGN_LEFT = "Left",
    MENU_ALIGN_RIGHT = "Right",

    -- Habilidad máxima
    MENU_ULTIMATE_SHOW = "Show Ultimate Percentage",
    MENU_ULTIMATE_SHOW_TT =
    "Shows the charge percentage on the Ultimate ability button.",
    MENU_ULTIMATE_POSITION = "Position",
    MENU_ULTIMATE_POSITION_TT = "Where the percentage appears inside the Ultimate ability button.",
    MENU_ULTIMATE_TOP = "Top",
    MENU_ULTIMATE_CENTER = "Center",
    MENU_ULTIMATE_BOTTOM = "Bottom",
})
