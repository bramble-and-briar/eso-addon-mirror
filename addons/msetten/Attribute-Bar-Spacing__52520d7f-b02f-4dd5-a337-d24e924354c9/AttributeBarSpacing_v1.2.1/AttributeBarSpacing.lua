AttributeBarSpacing = AttributeBarSpacing or {} 
AttributeBarSpacing.author = "msetten"
AttributeBarSpacing.version = "1.2.1"
AttributeBarSpacing.GUTTER = 15
AttributeBarSpacing.MAX_BAR_WIDTH = 323
AttributeBarSpacing.MAX_BAR_HEIGHT = 35

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
  },
  BUFFBAR = {
    en = "Vertical positioning of the buff bar",
    de = "Vertikale Positionierung der Buff-Leiste",
    fr = "Position verticale de la barre de buffs",
    ru = "Вертикальное позиционирование панели баффов",
    ja = "バフバーの垂直配置",
    zh = "增益条的垂直定位",
    es = "Posicionamiento vertical de la barra de beneficios",
    it = "Posizionamento verticale della barra dei buff",
    pl = "Pionowe pozycjonowanie paska buffów"
  },
  BUFFBAR_TOOLTIP = {
    en = "Vertical position of the buff bar on screen",
    de = "Vertikale Position der Buff-Leiste auf dem Bildschirm",
    fr = "Position verticale de la barre de buffs à l'écran",
    ru = "Вертикальное расположение панели баффов на экране",
    ja = "画面上のバフバーの垂直位置",
    zh = "屏幕上增益条的垂直位置",
    es = "Ubicación vertical de la barra de beneficios en la pantalla",
    it = "Posizione verticale della barra dei buff sullo schermo",
    pl = "Pionowe pozycjonowanie paska buffów na ekranie"
  },
  WARNING = {
    en = "WARNING",
    de = "WARNUNG",
    fr = "AVERTISSEMENT",
    ru = "ПРЕДУПРЕЖДЕНИЕ",
    ja = "警告",
    zh = "警告",
    es = "ADVERTENCIA",
    it = "AVVERTIMENTO",
    pl = "OSTRZEŻENIE"
  },
  WARNING_TEXT = {
    en = "As you are also using the FancyActionBar+ add-on, please be aware of a potential conflict: if you have enabled the options 'Adjust Health Bar', 'Adjust Mag/Stam Bar' and/or 'Adjust Player Buffs Bar' in the Miscellaneous section of FancyActionBar+ this add-on will not work, FancyActionBar+ then overrides this add-on's changes. Please disable these settings in FancyActionBar+if you want to use this add-on.",
    de = "Da Sie auch das FancyActionBar+-Add-on verwenden, seien Sie sich eines möglichen Konflikts bewusst: Wenn Sie die Optionen 'Gesundheitsleiste anpassen', 'Magie/Stamina-Leiste anpassen' und/oder 'Spieler-Buffs-Leiste anpassen' im Abschnitt 'Verschiedenes' von FancyActionBar+ aktiviert haben, funktioniert dieses Add-on nicht, da FancyActionBar+ die Änderungen dieses Add-ons überschreibt. Bitte deaktivieren Sie diese Einstellungen in FancyActionBar+, wenn Sie dieses Add-on verwenden möchten.",
    fr = "Comme vous utilisez également le module complémentaire FancyActionBar+, veuillez être conscient d'un conflit potentiel : si vous avez activé les options 'Ajuster la barre de santé', 'Ajuster la barre Mag/Stam' et/ou 'Ajuster la barre des buffs du joueur' dans la section Divers de FancyActionBar+, ce module complémentaire ne fonctionnera pas car FancyActionBar+ remplace les modifications de ce module complémentaire. Veuillez désactiver ces paramètres dans FancyActionBar+ si vous souhaitez utiliser ce module complémentaire.",
    ru = "Поскольку вы также используете аддон FancyActionBar+, обратите внимание на возможный конфликт: если вы включили опции 'Настроить панель здоровья', 'Настроить панель магии/выносливости' и/или 'Настроить панель баффов игрока' в разделе 'Разное' FancyActionBar+, этот аддон не будет работать, так как FancyActionBar+ переопределяет изменения этого аддона. Пожалуйста, отключите эти настройки в FancyActionBar+, если вы хотите использовать этот аддон.",
    ja = "FancyActionBar+アドオンも使用しているため、潜在的な競合に注意してください。FancyActionBar+の「その他」セクションで「体力バーを調整」、「マジック/スタミナバーを調整」、および/または「プレイヤーバフバーを調整」のオプションを有効にしている場合、このアドオンは機能しません。FancyActionBar+がこのアドオンの変更を上書きするためです。このアドオンを使用したい場合は、これらの設定をFancyActionBar+で無効にしてください。",
    zh = "由于您也在使用 FancyActionBar+ 插件，请注意可能的冲突：如果您在 FancyActionBar+ 的杂项部分启用了“调整生命值条”、“调整魔法/耐力条”和/或“调整玩家增益条”选项，则此插件将无法工作，因为 FancyActionBar+ 会覆盖此插件的更改。如果您想使用此插件，请在 FancyActionBar+ 中禁用这些设置。",
    es = "Dado que también está utilizando el complemento FancyActionBar+, tenga en cuenta un posible conflicto: si ha habilitado las opciones 'Ajustar barra de salud', 'Ajustar barra de Mag/Stam' y/o 'Ajustar barra de beneficios del jugador' en la sección Miscelánea de FancyActionBar+, este complemento no funcionará, ya que FancyActionBar+ anula los cambios de este complemento. Desactive estas configuraciones en FancyActionBar+ si desea usar este complemento.",
    it = "Poiché stai anche utilizzando il componente aggiuntivo FancyActionBar+, tieni presente un potenziale conflitto: se hai abilitato le opzioni 'Regola barra della salute', 'Regola barra Mag/Stam' e/o 'Regola barra dei buff del giocatore' nella sezione Varie di FancyActionBar+, questo componente aggiuntivo non funzionerà poiché FancyActionBar+ sovrascrive le modifiche di questo componente aggiuntivo. Disattiva queste impostazioni in FancyActionBar+ se desideri utilizzare questo componente aggiuntivo.",
    pl = "Ponieważ używasz również dodatku FancyActionBar+, pamiętaj o potencjalnym konflikcie: jeśli w sekcji Różne dodatku FancyActionBar+ włączyłeś opcje 'Dostosuj pasek zdrowia', 'Dostosuj pasek Mag/Sta' i/lub 'Dostosuj pasek buffów gracza', ten dodatek nie będzie działał, ponieważ FancyActionBar+ nadpisuje zmiany tego dodatku. Wyłącz te ustawienia w FancyActionBar+, jeśli chcesz korzystać z tego dodatku."
  }
}


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

local function UpdateAttributeBars(value, vertical, buffbar)
    local minOffsetX = AttributeBarSpacing.GUTTER
    local maxOffsetX = (GuiRoot:GetWidth() - AttributeBarSpacing.MAX_BAR_WIDTH) / 2 - AttributeBarSpacing.MAX_BAR_WIDTH - AttributeBarSpacing.GUTTER
    local offsetX = (value - 3) * (maxOffsetX - minOffsetX) / 200 + minOffsetX
    local offsetY = 0
    if value < 45 then
        offsetY = 30
    else
        offsetY = 0
    end

    local healthVerticalPosition = vertical + AttributeBarSpacing.MAX_BAR_HEIGHT + (offsetY / 2)
    ZO_PlayerAttributeHealth:ClearAnchors()
    ZO_PlayerAttributeHealth:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -healthVerticalPosition)    

    ZO_PlayerAttributeMagicka:ClearAnchors()
    ZO_PlayerAttributeMagicka:SetAnchor(RIGHT, ZO_PlayerAttributeHealth, CENTER, -offsetX, offsetY)

    ZO_PlayerAttributeStamina:ClearAnchors()
    ZO_PlayerAttributeStamina:SetAnchor(LEFT, ZO_PlayerAttributeHealth, CENTER, offsetX, offsetY)

    ZO_BuffDebuffTopLevelSelfContainer:ClearAnchors()
    ZO_BuffDebuffTopLevelSelfContainer:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -buffbar)
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
        max = 250,
        step = 5,
        getFunc = function() return AttributeBarSpacing.savedVars.spacing end,
        setFunc = function(value) 
          AttributeBarSpacing.savedVars.spacing = value
          UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical, AttributeBarSpacing.savedVars.buffbar)
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
          UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical, AttributeBarSpacing.savedVars.buffbar)
        end,
    },
    {
        type = "slider",
        name = L("BUFFBAR"),
        tooltip = function() return L("BUFFBAR_TOOLTIP") end,
        min = 0,
        max = Round(GuiRoot:GetHeight() - (AttributeBarSpacing.MAX_BAR_HEIGHT * 2)),
        step = 5,
        getFunc = function() return AttributeBarSpacing.savedVars.buffbar  end,
        setFunc = function(value) 
          AttributeBarSpacing.savedVars.buffbar = value
          UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical, AttributeBarSpacing.savedVars.buffbar)
        end,
    }
  }

  if FancyActionBar ~= nil then
    table.insert(optionsTable, {
        type = "description",
        title = L("WARNING"),
        text = L("WARNING_TEXT")
    })
  end


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
    if AttributeBarSpacing.savedVars.spacing ~= nil then
        if AttributeBarSpacing.savedVars.spacing < 0 then AttributeBarSpacing.savedVars.spacing = 50 end
        if AttributeBarSpacing.savedVars.spacing > 250 then AttributeBarSpacing.savedVars.spacing = 250 end
    end
    if FancyActionBar == nil then 
      AttributeBarSpacing.savedVars.spacing = AttributeBarSpacing.savedVars.spacing or 50
      AttributeBarSpacing.savedVars.vertical = AttributeBarSpacing.savedVars.vertical or 90
      AttributeBarSpacing.savedVars.buffbar = AttributeBarSpacing.savedVars.buffbar or 190
    else 
      AttributeBarSpacing.savedVars.spacing = AttributeBarSpacing.savedVars.spacing or 50
      AttributeBarSpacing.savedVars.vertical = AttributeBarSpacing.savedVars.vertical or 180
      AttributeBarSpacing.savedVars.buffbar = AttributeBarSpacing.savedVars.buffbar or 290
    end
    UpdateAttributeBars(AttributeBarSpacing.savedVars.spacing, AttributeBarSpacing.savedVars.vertical, AttributeBarSpacing.savedVars.buffbar)
end

--- Initialize the AttributeBarSpacing addon
--- This function sets up the saved variables, registers events, and creates the settings panel.
--- It is called when the addon is loaded.
---@return void
function AttributeBarSpacing:Initialize()
    -- Initialize the attribute bar spacing settings
    AttributeBarSpacing.savedVars = ZO_SavedVars:NewAccountWide("AttributeBarSpacingSavedVars", 1, nil, nil)

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