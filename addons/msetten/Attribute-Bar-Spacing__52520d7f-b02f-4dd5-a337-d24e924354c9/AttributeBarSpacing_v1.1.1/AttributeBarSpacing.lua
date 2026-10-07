AttributeBarSpacing = AttributeBarSpacing or {} 
AttributeBarSpacing.author = "msetten"
AttributeBarSpacing.version = "1.1.1"
AttributeBarSpacing.GUTTER = 15
AttributeBarSpacing.MAX_BAR_WIDTH = 323
AttributeBarSpacing.MAX_BAR_HEIGHT = 35
AttributeBarSpacing.defaults = {
    spacing = 50,
    vertical = 90
}

local strings = {
   SETTINGS_DISPLAY_NAME = {
    en = "Attribute Bar Spacing Settings",
    de = "Abstandseinstellungen der Attributleisten",
    fr = "Paramètres de l'espacement des barres d'attribut",
    ru = "Настройки расстояния между панелями атрибутов",
    ja = "アトリビュートバーの間隔設定",
    zh = "属性条间距设置",
    es = "Configuración del espaciado de la barra de atributos",
    it = "Impostazioni dello spazio tra le barre degli attributi",
    pl = "Ustawienia odstępów między paskami atrybutów"
  },
  SPACING = {
    en = "Attribute Bar Spacing",
    de = "Abstand zwischen Attributleisten",
    fr = "Espacement des barres d'attribut",
    ru = "Расстояние между панелями атрибутов",
    ja = "アトリビュートバーの間隔",
    zh = "属性条间距",
    es = "Espaciado de la barra de atributos",
    it = "Spaziatura della barra degli attributi",
    pl = "Odstęp między paskami atrybutów"
  },
  SPACING_TOOLTIP = {
    en = "Space between attribute bars. Values between 0 and 45 will push the magicka and stamina bars below the health bar.",
    de = "Abstand zwischen Attributleisten. Werte zwischen 0 und 45 verschieben die Magicka- und Ausdauerleisten unter die Gesundheitsleiste.",
    fr = "Espace entre les barres d'attribut. Des valeurs comprises entre 0 et 45 pousseront les barres de Magie et d'Endurance sous la barre de santé.",
    ru = "Пробел между панелями атрибутов. Значения от 0 до 45 перемещают панели магии и выносливости под панель здоровья.",
    ja = "アトリビュートバー間のスペース。0から45の値は、マジカバーとスタミナバーをヘルスバーの下に押し下げます。",
    zh = "属性条之间的间距。0到45之间的值会将魔法值条和耐力条推到生命值条下方。",
    es = "Espacio entre las barras de atributos. Los valores entre 0 y 45 empujarán las barras de Magia y Resistencia debajo de la barra de salud.",
    it = "Spazio tra le barre degli attributi. I valori tra 0 e 45 spingeranno le barre di Magicka e Stamina sotto la barra della salute.",
    pl = "Odległość między paskami atrybutów. Wartości między 0 a 45 przesuną paski many i wytrzymałości poniżej paska zdrowia."
  },
  VERTICAL = {
    en = "Vertical positioning of the bars",
    de = "Vertikale Positionierung der Leisten",
    fr = "Position verticale des barres",
    ru = "Вертикальное позиционирование панелей",
    ja = "バーの垂直配置",
    zh = "属性条的垂直定位",
    es = "Posicionamiento vertical de las barras",
    it = "Posizionamento verticale delle barre",
    pl = "Pionowe pozycjonowanie pasków"
  },
  VERTICAL_TOOLTIP = {
    en = "Vertical position of the attribute bars on screen",
    de = "Vertikale Position der Attributleisten auf dem Bildschirm",
    fr = "Position verticale des barres d'attribut à l'écran",
    ru = "Вертикальное расположение панелей атрибутов на экране",
    ja = "画面上のアトリビュートバーの垂直位置",
    zh = "屏幕上属性条的垂直位置",
    es = "Ubicación vertical de las barras de atributos en la pantalla",
    it = "Posizione verticale delle barre degli attributi sullo schermo",
    pl = "Pionowe pozycjonowanie pasków atrybutów na ekranie"
  }}


--- Localizes a string based on the current language setting.
-- This function retrieves the localized string for the given key based on the current language setting.
-- If the string is not available in the current language, it defaults to English.
-- @param key The key for the string to be localized.
-- @return The localized string for the given key.
---@param key string
---@return string localizedString
local function L(key)
    local lang = GetCVar("Language.2")
    return strings[key][lang] or strings[key]["en"]
end

local function Round(to_round)
    local divided = to_round / 5
    local rounded = 5 * math.floor(divided)
    return rounded
end

local function UpdateAttributeBars(value, vertical)
    local minOffsetX = AttributeBarSpacing.GUTTER
    local maxOffsetX = (GuiRoot:GetWidth() - AttributeBarSpacing.MAX_BAR_WIDTH) / 2 - AttributeBarSpacing.MAX_BAR_WIDTH - AttributeBarSpacing.GUTTER
    local offsetX = (value - 50) * (maxOffsetX - minOffsetX) / 200 + minOffsetX
    local offsetY = 0
    if offsetX < minOffsetX then
        offsetY = 30
    elseif offsetX >= maxOffsetX then
        offsetY = 0
    end

    local healthVerticalPosition = vertical + AttributeBarSpacing.MAX_BAR_HEIGHT + (offsetY / 2)
    ZO_PlayerAttributeHealth:ClearAnchors()
    ZO_PlayerAttributeHealth:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -healthVerticalPosition)    

    ZO_PlayerAttributeMagicka:ClearAnchors()
    ZO_PlayerAttributeMagicka:SetAnchor(RIGHT, ZO_PlayerAttributeHealth, LEFT, -offsetX, offsetY)

    ZO_PlayerAttributeStamina:ClearAnchors()
    ZO_PlayerAttributeStamina:SetAnchor(LEFT, ZO_PlayerAttributeHealth, RIGHT, offsetX, offsetY)
end

-- Creates the settings panel for AttributeBarSpacing.
function AttributeBarSpacing:CreateSettingsPanel()
    local panelName = "AttributeBarSpacingSettingsPanel"

    if IsConsoleUI() and not LibAddonMenu2 then return end

    local optionsTable = {{
        type = "slider",
        name = L("SPACING"),
        tooltip = function() return L("SPACING_TOOLTIP") end,
        min = 0,
        max = 255,
        step = 5,
        getFunc = function() return AttributeBarSpacing.savedVars.spacing end,
        setFunc = function(value) 
          AttributeBarSpacing.savedVars.spacing = value
          UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical)
        end,
    },
    {
        type = "slider",
        name = L("VERTICAL"),
        tooltip = function() return L("VERTICAL_TOOLTIP") end,
        min = 0,
        max = Round(GuiRoot:GetHeight() - (AttributeBarSpacing.MAX_BAR_HEIGHT * 2)),
        step = 5,
        getFunc = function() return AttributeBarSpacing.savedVars.vertical  end,
        setFunc = function(value) 
          AttributeBarSpacing.savedVars.vertical = value
          UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical)
        end,
    }}

    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = L("SPACING"),
        displayName = L("SETTINGS_DISPLAY_NAME"),
        author = AttributeBarSpacing.author,
        version = AttributeBarSpacing.version,
        registerForRefresh = true
    })

    LibAddonMenu2:RegisterOptionControls(panelName, optionsTable)
end

function AttributeBarSpacing.OnPlayerActivated(eventCode)
    AttributeBarSpacing.savedVars.vertical = AttributeBarSpacing.savedVars.vertical or (GuiRoot:GetHeight() - (AttributeBarSpacing.MAX_BAR_HEIGHT * 2))
    AttributeBarSpacing.savedVars.spacing = AttributeBarSpacing.savedVars.spacing or 50
    if AttributeBarSpacing.savedVars.spacing < 0 then AttributeBarSpacing.savedVars.spacing = 50 end
    UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical)
end

--- Initialize the AttributeBarSpacing addon
--- This function sets up the saved variables, registers events, and creates the settings panel.
--- It is called when the addon is loaded.
---@return void
function AttributeBarSpacing:Initialize()
    -- Initialize the attribute bar spacing settings
    AttributeBarSpacing.savedVars = ZO_SavedVars:NewAccountWide("AttributeBarSpacingSavedVars", 1, nil, AttributeBarSpacing.defaults)

    AttributeBarSpacing:CreateSettingsPanel()

    EVENT_MANAGER:RegisterForEvent("AttributeBarSpacing_PlayerActivated", EVENT_PLAYER_ACTIVATED, AttributeBarSpacing.OnPlayerActivated)
end

--- Event handler for the add-on loaded event
--- This function initializes the AttributeBarSpacing addon when it is loaded.
--- It checks if the add-on name matches "AttributeBarSpacing" and then calls the Initialize function.
--- It unregisters the event after initialization to prevent it from being called again.
EVENT_MANAGER:RegisterForEvent("AttributeBarSpacing_Loaded", EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == "AttributeBarSpacing" then
        AttributeBarSpacing:Initialize()
        EVENT_MANAGER:UnregisterForEvent("AttributeBarSpacing_Loaded", EVENT_ADD_ON_LOADED)
    end
end)