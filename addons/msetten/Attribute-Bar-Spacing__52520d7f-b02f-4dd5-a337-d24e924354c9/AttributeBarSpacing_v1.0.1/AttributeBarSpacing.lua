AttributeBarSpacing = AttributeBarSpacing or {} 
AttributeBarSpacing.author = "msetten"
AttributeBarSpacing.version = "1.0.1"
AttributeBarSpacing.GUTTER = 30
AttributeBarSpacing.MAX_BAR_WIDTH = 323
AttributeBarSpacing.defaults = {
    spacing = 0
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
    en = "Space between attribute bars",
    de = "Abstand zwischen Attributleisten",
    fr = "Espace entre les barres d'attribut",
    ru = "Пробел между панелями атрибутов",
    ja = "アトリビュートバー間のスペース",
    zh = "属性条之间的间距",
    es = "Espacio entre las barras de atributos",
    it = "Spazio tra le barre degli attributi",
    pl = "Odległość między paskami atrybutów"
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


local function UpdateAttributeBarsOffsetX(value)
    local minOffsetX = AttributeBarSpacing.GUTTER
    local maxOffsetX = (GuiRoot:GetWidth() - AttributeBarSpacing.MAX_BAR_WIDTH) / 2 - AttributeBarSpacing.MAX_BAR_WIDTH - AttributeBarSpacing.GUTTER
    local offsetX = (value + 100) * (maxOffsetX - minOffsetX) / 200 + minOffsetX

    ZO_PlayerAttributeMagicka:ClearAnchors()
    ZO_PlayerAttributeMagicka:SetAnchor(RIGHT, ZO_PlayerAttributeHealth, LEFT, -offsetX, 0)

    ZO_PlayerAttributeStamina:ClearAnchors()
    ZO_PlayerAttributeStamina:SetAnchor(LEFT, ZO_PlayerAttributeHealth, RIGHT, offsetX, 0)
end

-- Creates the settings panel for AttributeBarSpacing.
function AttributeBarSpacing:CreateSettingsPanel()
    local panelName = "AttributeBarSpacingSettingsPanel"

    if IsConsoleUI() and not LibAddonMenu2 then return end

    local optionsTable = {{
        type = "slider",
        name = L("SPACING"),
        tooltip = function() return L("SPACING_TOOLTIP") end,
        min = -100,
        max = 100,
        step = 10,
        getFunc = function() return AttributeBarSpacing.savedVars.spacing end,
        setFunc = function(value) 
          AttributeBarSpacing.savedVars.spacing = value
          UpdateAttributeBarsOffsetX(value)
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
    UpdateAttributeBarsOffsetX(AttributeBarSpacing.savedVars.spacing)
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