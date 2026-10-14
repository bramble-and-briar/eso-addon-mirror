-- Страница аддона в «Настройки → Дополнения» (через LibAddonMenu-2.0)
-- и окно «Мои места»: поиск, фильтр по локации и типу, галочки.
--
-- Окно описано в MundusGate.xml и открывается как отдельная сцена,
-- так же как быстрое меню. Раньше редактор встраивался прямо в страницу
-- LibAddonMenu, но там он не отображался.
local QTM  = MundusGate
local L    = QTM.L
local Data = QTM.Data

local Settings = {}
QTM.Settings = Settings

local PANEL_NAME  = "MundusGateOptions"
local SCENE_NAME  = "MundusGateEditorScene"
local TYPE_HEADER = 1
local TYPE_ROW    = 2
local TYPE_EMPTY  = 3

local lower = zo_strlower or string.lower

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SetColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

-- Текущие фильтры редактора
Settings.filter = {
    text          = "",
    zone          = nil,   -- nil = все локации
    type          = nil,   -- nil = все типы
    onlyFavorites = false,
    onlyOpen      = false,
}

---------------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------------
function Settings:Initialize()
    self:InitializeEditorWindow()
    self:InitializeSettingsPanel()
end

function Settings:InitializeSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local sv, defaults = QTM.sv, QTM.defaults

    local panelData = {
        type                = "panel",
        name                = L.ADDON_NAME,
        displayName         = "|c5DC1E8Mundus Gate|r",
        author              = QTM.author,
        version             = QTM.version,
        registerForRefresh  = true,
        registerForDefaults = true,
    }
    self.panel = LAM:RegisterAddonPanel(PANEL_NAME, panelData)

    -- Языки для выпадающего списка: «Авто» и все языки по их самоназванию
    local languageNames = { zo_strformat(L.LANG_AUTO, QTM.GetLanguageName(QTM.ResolveLanguage("auto"))) }
    local languageCodes = { "auto" }
    for _, info in ipairs(QTM.LANGUAGES) do
        languageNames[#languageNames + 1] = info.name
        languageCodes[#languageCodes + 1] = info.code
    end

    local Style = QTM.Style

    local function Checkbox(key, name, tooltip, onChange, extra)
        local option = {
            type    = "checkbox",
            name    = name,
            tooltip = tooltip,
            getFunc = function() return sv[key] end,
            setFunc = function(value)
                sv[key] = value
                if onChange then onChange(value) end
            end,
            default = defaults[key],
        }
        for field, value in pairs(extra or {}) do option[field] = value end
        return option
    end

    local function RouteOption(source, name, tooltip)
        return Checkbox("route" .. source, name, tooltip, function()
            if QTM.RefreshTravelState then QTM.RefreshTravelState() end
        end, { width = "half" })
    end

    -- Оформление: цвет и непрозрачность в процентах. Любая правка — «своя» тема.
    local function ColorOption(key, name, tooltip)
        local default = Style.THEME_DEFAULTS[key]
        return {
            type    = "colorpicker",
            name    = name,
            tooltip = tooltip,
            width   = "half",
            getFunc = function() return Style.GetThemeColor(key) end,
            setFunc = function(r, g, b)
                sv.themePreset = "custom"
                Style.SetThemeColor(key, r, g, b)
            end,
            default = { r = default.r, g = default.g, b = default.b },
        }
    end

    local function AlphaOption(key, name, tooltip, extra)
        local option = {
            type    = "slider",
            name    = name,
            tooltip = tooltip,
            min     = 0,
            max     = 100,
            step    = 5,
            getFunc = function() return zo_round((Style.GetThemeValue(key) or 1) * 100) end,
            setFunc = function(value)
                sv.themePreset = "custom"
                Style.SetThemeValue(key, value / 100)
            end,
            default = zo_round(Style.THEME_DEFAULTS[key] * 100),
        }
        for field, value in pairs(extra or {}) do option[field] = value end
        return option
    end

    local presetNames, presetKeys = {}, {}
    for _, preset in ipairs(Style.THEME_PRESETS) do
        presetNames[#presetNames + 1] = L["THEME_" .. string.upper(preset.key)]
        presetKeys[#presetKeys + 1] = preset.key
    end
    presetNames[#presetNames + 1] = L.THEME_CUSTOM
    presetKeys[#presetKeys + 1] = "custom"

    local function RefreshPresence()
        QTM.Presence:MarkDirty()
        QTM.Presence.lastBuild = nil
    end

    local function TrackerDisabled() return not sv.questTracker end

    -- Подсказки при наведении: отдельно для каждой части аддона
    local function TipOption(category)
        local key = string.upper(category)
        return {
            type    = "checkbox",
            name    = L["OPT_TIPS_" .. key],
            tooltip = L["OPT_TIPS_" .. key .. "_TT"],
            width   = "half",
            getFunc = function() return QTM.TipsEnabled(category) end,
            setFunc = function(value)
                if category == "buttons" then
                    sv.buttonsTooltips = value
                else
                    sv.tooltips[category] = value
                end
                if not value then ZO_Tooltips_HideTextTooltip() end
            end,
            default = true,
        }
    end

    local function RebuildPreview() QTM.Preview:Rebuild() end

    local options = {
        { type = "description", text = L.SETTINGS_DESC },

        -- Основное
        { type = "header", name = L.HEADER_GENERAL },
        {
            type    = "dropdown",
            name    = L.OPT_LANGUAGE,
            tooltip = L.OPT_LANGUAGE_TT,
            choices = languageNames,
            choicesValues = languageCodes,
            getFunc = function() return sv.language or "auto" end,
            setFunc = function(value)
                if value ~= (sv.language or "auto") then QTM.MapPanel:ConfirmLanguage(value) end
            end,
            default = "auto",
        },
        Checkbox("confirmTravel", L.OPT_CONFIRM, L.OPT_CONFIRM_TT),
        {
            type    = "dropdown",
            name    = L.OPT_HOUSE,
            choices = { L.HOUSE_INSIDE, L.HOUSE_OUTSIDE },
            getFunc = function() return sv.houseOutside and L.HOUSE_OUTSIDE or L.HOUSE_INSIDE end,
            setFunc = function(value) sv.houseOutside = (value == L.HOUSE_OUTSIDE) end,
            default = L.HOUSE_INSIDE,
        },

        -- Мои места и быстрое меню
        { type = "header", name = L.HEADER_PLACES },
        { type = "description", text = L.PLACES_DESC },
        { type = "button", name = L.OPT_OPEN_EDITOR, width = "half", func = function() self:Show() end },
        Checkbox("groupByZone", L.OPT_GROUP, L.OPT_GROUP_TT),
        Checkbox("showUnavailable", L.OPT_SHOW_UNAVAIL, L.OPT_SHOW_UNAVAIL_TT),

        -- Бесплатные перемещения: через игроков и бесплатный путь в платные места
        { type = "header", name = L.HEADER_FREE },
        Checkbox("freeViaFriends", L.OPT_FREE_FRIENDS, L.OPT_FREE_FRIENDS_TT, RefreshPresence),
        Checkbox("freeViaGuild", L.OPT_FREE_GUILD, L.OPT_FREE_GUILD_TT, RefreshPresence),
        Checkbox("freeViaGroup", L.OPT_FREE_GROUP, L.OPT_FREE_GROUP_TT),
        { type = "description", title = L.HEADER_ROUTE, text = L.ROUTE_DESC },
        RouteOption("Menu", L.OPT_ROUTE_MENU, L.OPT_ROUTE_MENU_TT),
        RouteOption("Buttons", L.OPT_ROUTE_BUTTONS, L.OPT_ROUTE_BUTTONS_TT),
        RouteOption("Wheel", L.OPT_ROUTE_WHEEL, L.OPT_ROUTE_WHEEL_TT),
        RouteOption("Map", L.OPT_ROUTE_MAP, L.OPT_ROUTE_MAP_TT),
        RouteOption("Quest", L.OPT_ROUTE_QUEST, L.OPT_ROUTE_QUEST_TT),

        -- Карта мира
        { type = "header", name = L.HEADER_MAP },
        { type = "description", text = L.MAP_DESC },
        Checkbox("mapPanel", L.OPT_MAP_PANEL, L.OPT_MAP_PANEL_TT, function() QTM.MapPanel:UpdateVisibility(); RebuildPreview() end),
        Checkbox("infoPanel", L.OPT_INFO_PANEL, L.OPT_INFO_PANEL_TT, function() QTM.InfoPanel:UpdateVisibility(); RebuildPreview() end),
        Checkbox("zoomBar", L.OPT_ZOOM_BAR, L.OPT_ZOOM_BAR_TT, function() QTM.ZoomBar:Apply() end),
        Checkbox("mapEntry", L.OPT_MAP_ENTRY, L.OPT_MAP_ENTRY_TT),

        -- Панель заданий на экране
        { type = "header", name = L.HEADER_TRACKER },
        Checkbox("questTracker", L.OPT_TRACKER, L.OPT_TRACKER_TT, function() QTM.QuestTracker:ApplySettings(); RebuildPreview() end),
        {
            type     = "dropdown",
            name     = L.OPT_TRACKER_STYLE,
            tooltip  = L.OPT_TRACKER_STYLE_TT,
            choices  = { L.TRACKER_STYLE_FULL, L.TRACKER_STYLE_SIMPLE },
            choicesValues = { "full", "simple" },
            getFunc  = function() return sv.trackerStyle == "simple" and "simple" or "full" end,
            setFunc  = function(value)
                sv.trackerStyle = value
                QTM.QuestTracker:ApplySettings()
                RebuildPreview()
            end,
            disabled = TrackerDisabled,
            default  = defaults.trackerStyle,
        },
        Checkbox("trackerShowAll", L.OPT_TRACKER_SHOW_ALL, L.OPT_TRACKER_SHOW_ALL_TT,
            function() QTM.QuestTracker:Refresh(); RebuildPreview() end,
            { disabled = function() return not sv.questTracker or sv.trackerStyle ~= "simple" end }),
        Checkbox("hideGameTracker", L.OPT_HIDE_GAME_TRACKER, L.OPT_HIDE_GAME_TRACKER_TT,
            function() QTM.QuestTracker:ApplySettings() end, { disabled = TrackerDisabled }),
        Checkbox("trackerLocked", L.OPT_TRACKER_LOCKED, L.OPT_TRACKER_LOCKED_TT,
            function() QTM.QuestTracker:ApplySettings() end, { disabled = TrackerDisabled, width = "half" }),
        {
            type     = "button",
            name     = L.OPT_TRACKER_RESET,
            func     = function() QTM.QuestTracker:ResetPosition() end,
            disabled = TrackerDisabled,
            width    = "half",
        },

        -- Кнопки на экране
        { type = "header", name = L.HEADER_BUTTONS },
        { type = "description", text = L.BUTTONS_DESC },
        { type = "button", name = L.OPT_OPEN_BUTTONS, width = "half", func = function() QTM.ButtonsEditor:Show() end },
        Checkbox("buttonsVisible", L.OPT_BUTTONS_VISIBLE, nil, function() QTM.Buttons:UpdateVisibility() end),
        {
            type    = "checkbox",
            name    = L.OPT_BUTTONS_LOCKED,
            tooltip = L.OPT_BUTTONS_LOCKED_TT,
            getFunc = function() return sv.buttonsLocked end,
            setFunc = function(value) QTM.Buttons:SetLocked(value) end,
            default = defaults.buttonsLocked,
        },
        Checkbox("buttonsHideInCombat", L.OPT_BUTTONS_COMBAT, nil, function() QTM.Buttons:UpdateVisibility() end),
        AlphaOption("buttonsAlpha", L.OPT_ALPHA_BUTTONS),

        -- Колесо
        { type = "header", name = L.HEADER_WHEEL },
        { type = "description", text = L.WHEEL_DESC },
        { type = "button", name = L.OPT_OPEN_WHEEL, width = "half", func = function() QTM.WheelEditor:Show() end },
        Checkbox("utilityWheelEnabled", L.OPT_WHEEL_ENABLED, L.OPT_WHEEL_ENABLED_TT),
        Checkbox("utilityWheelStartOnTravel", L.OPT_WHEEL_START, L.OPT_WHEEL_START_TT, nil,
            { disabled = function() return not sv.utilityWheelEnabled end }),

        -- Оформление: цвета и прозрачность
        { type = "header", name = L.HEADER_LOOK },
        { type = "description", text = L.LOOK_DESC },
        Checkbox("settingsPreview", L.OPT_SETTINGS_PREVIEW, L.OPT_SETTINGS_PREVIEW_TT, function(value)
            if value then QTM.Preview:Show() else QTM.Preview:Hide() end
        end),
        {
            type    = "dropdown",
            name    = L.OPT_THEME_PRESET,
            tooltip = L.OPT_THEME_PRESET_TT,
            choices = presetNames,
            choicesValues = presetKeys,
            width   = "half",
            getFunc = function() return sv.themePreset or "default" end,
            setFunc = function(value)
                if value ~= "custom" then Style.ApplyPreset(value) else sv.themePreset = "custom" end
            end,
            default = "default",
        },
        {
            type  = "button",
            name  = L.OPT_THEME_RESET,
            width = "half",
            func  = function()
                sv.themePreset = "default"
                Style.ResetTheme()
            end,
        },
        ColorOption("accent", L.OPT_COLOR_ACCENT, L.OPT_COLOR_ACCENT_TT),
        ColorOption("title", L.OPT_COLOR_TITLE, L.OPT_COLOR_TITLE_TT),
        ColorOption("text", L.OPT_COLOR_TEXT, L.OPT_COLOR_TEXT_TT),
        ColorOption("muted", L.OPT_COLOR_MUTED, L.OPT_COLOR_MUTED_TT),
        ColorOption("panelTint", L.OPT_COLOR_PANEL, L.OPT_COLOR_PANEL_TT),
        AlphaOption("panelAlpha", L.OPT_ALPHA_PANEL, L.OPT_ALPHA_PANEL_TT),
        AlphaOption("windowAlpha", L.OPT_ALPHA_WINDOW, L.OPT_ALPHA_WINDOW_TT),
        AlphaOption("rowAlpha", L.OPT_ALPHA_ROWS, L.OPT_ALPHA_ROWS_TT),
        { type = "description", title = L.LOOK_KINDS, text = L.LOOK_KINDS_DESC },
        ColorOption("quest", L.OPT_COLOR_QUEST),
        ColorOption("pursuit", L.OPT_COLOR_PURSUIT),
        ColorOption("tome", L.OPT_COLOR_TOME),
        { type = "description", title = L.HEADER_TRACKER, text = L.LOOK_TRACKER_DESC },
        ColorOption("trackerBg", L.OPT_COLOR_TRACKER_BG),
        {
            type    = "slider",
            name    = L.OPT_ALPHA_TRACKER_BG,
            tooltip = L.OPT_ALPHA_TRACKER_BG_TT,
            min     = 0,
            max     = 100,
            step    = 5,
            -- У подробной и простой панели своё значение: настраивается то, что выбрано сейчас
            getFunc = function()
                local key = sv.trackerStyle == "simple" and "trackerSimpleBgAlpha" or "trackerBgAlpha"
                return zo_round((Style.GetThemeValue(key) or 0) * 100)
            end,
            setFunc = function(value)
                local key = sv.trackerStyle == "simple" and "trackerSimpleBgAlpha" or "trackerBgAlpha"
                sv.themePreset = "custom"
                Style.SetThemeValue(key, value / 100)
            end,
            default = function()
                local key = sv.trackerStyle == "simple" and "trackerSimpleBgAlpha" or "trackerBgAlpha"
                return zo_round(Style.THEME_DEFAULTS[key] * 100)
            end,
        },
        AlphaOption("trackerCardAlpha", L.OPT_ALPHA_TRACKER_CARDS, L.OPT_ALPHA_TRACKER_CARDS_TT,
            { disabled = function() return sv.trackerStyle == "simple" end }),
        AlphaOption("trackerAlpha", L.OPT_ALPHA_TRACKER, L.OPT_ALPHA_TRACKER_TT),

        -- Подсказки при наведении
        { type = "header", name = L.HEADER_TIPS },
        { type = "description", text = L.TIPS_DESC },
        TipOption("menu"),
        TipOption("buttons"),
        TipOption("mapPanel"),
        TipOption("mapPins"),
        TipOption("infoPanel"),
        TipOption("tracker"),
        TipOption("guild"),
        TipOption("windows"),

        -- Поддержка и обратная связь
        { type = "header", name = L.HEADER_SUPPORT },
        { type = "description", text = zo_strformat(L.SUPPORT_DESC, QTM.contact) },
        {
            type    = "button",
            name    = L.OPT_DONATE,
            tooltip = zo_strformat(L.OPT_DONATE_TT, QTM.contact),
            width   = "half",
            func    = function() Settings:ComposeMail(L.MAIL_SUBJECT_DONATE, L.MAIL_BODY_DONATE) end,
        },
        {
            type    = "button",
            name    = L.OPT_FEEDBACK,
            tooltip = zo_strformat(L.OPT_FEEDBACK_TT, QTM.contact),
            width   = "half",
            func    = function() Settings:ComposeMail(L.MAIL_SUBJECT_FEEDBACK, L.MAIL_BODY_FEEDBACK) end,
        },
    }
    LAM:RegisterOptionControls(PANEL_NAME, options)
end

---------------------------------------------------------------------------
-- Письмо автору: открывается окно почты игры с адресатом и темой.
-- Золото и предметы прикладываются в этом же окне, как в обычном письме.
---------------------------------------------------------------------------
-- Открыть страницу настроек аддона (кнопка-шестерёнка на панели карты)
function Settings:OpenPanel()
    if LibAddonMenu2 and self.panel then
        LibAddonMenu2:OpenToPanel(self.panel)
    end
end

function Settings:ComposeMail(subject, body)
    local to = QTM.contact
    subject = zo_strformat(subject, QTM.version)
    body = zo_strformat(body, QTM.version, GetDisplayName())

    if IsInGamepadPreferredMode() then
        if MAIL_GAMEPAD then MAIL_GAMEPAD:GetSend():ComposeMailTo(to, subject) end
        return
    end

    MAIL_SEND:ComposeMailTo(to, subject)
    -- Текст письма вставляем, когда окно почты открылось и заполнило адресата
    SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, function()
        if MAIL_SEND.body and MAIL_SEND.body:GetText() == "" then
            MAIL_SEND.body:SetText(body)
            MAIL_SEND.body:TakeFocus()
        end
    end)
end

---------------------------------------------------------------------------
-- Окно «Мои места»
---------------------------------------------------------------------------
function Settings:InitializeEditorWindow()
    local win = MundusGateEditorWindow
    self.window = win

    win:GetNamedChild("Title"):SetText(L.EDITOR_TITLE)
    win:GetNamedChild("SearchCaption"):SetText(L.EDITOR_SEARCH)
    win:GetNamedChild("ZoneCaption"):SetText(L.EDITOR_ZONE)
    win:GetNamedChild("TypeCaption"):SetText(L.EDITOR_TYPE)
    win:GetNamedChild("Hint"):SetText(L.EDITOR_HINT)

    -- Поиск
    local search = win:GetNamedChild("SearchBgBox")
    search:SetMaxInputChars(60)
    search:SetHandler("OnTextChanged", function(edit)
        self.filter.text = edit:GetText()
        self:Refresh()
    end)
    self.search = search

    -- Выпадающие списки
    self.zoneCombo = ZO_ComboBox_ObjectFromContainer(win:GetNamedChild("Zone"))
    self.zoneCombo:SetSortsItems(false)
    self.typeCombo = ZO_ComboBox_ObjectFromContainer(win:GetNamedChild("Type"))
    self.typeCombo:SetSortsItems(false)
    self:FillTypeCombo()

    -- Галочки-фильтры
    local onlyFav = win:GetNamedChild("OnlyFav")
    ZO_CheckButton_SetLabelText(onlyFav, L.EDITOR_ONLY_FAV)
    ZO_CheckButton_SetToggleFunction(onlyFav, function(_, checked)
        self.filter.onlyFavorites = checked
        self:Refresh()
    end)

    local onlyOpen = win:GetNamedChild("OnlyOpen")
    ZO_CheckButton_SetLabelText(onlyOpen, L.EDITOR_ONLY_OPEN)
    ZO_CheckButton_SetToggleFunction(onlyOpen, function(_, checked)
        self.filter.onlyOpen = checked
        self:Refresh()
    end)

    -- Кнопка «Снять все» и счётчик
    local clear = win:GetNamedChild("Clear")
    clear:SetText(L.EDITOR_CLEAR)
    clear:SetHandler("OnClicked", function() ZO_Dialogs_ShowDialog("MUNDUSGATE_CLEAR") end)
    self.counter = win:GetNamedChild("Counter")

    -- Список
    local list = win:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_HEADER, "MundusGate_EditorHeader", 32,
        function(c, data) self:SetupHeader(c, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_ROW, "MundusGate_EditorRow", 30,
        function(c, data) self:SetupRow(c, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_EMPTY, "MundusGate_Empty", 60,
        function(c, data) QTM.Menu:SetupEmpty(c, data, list) end)

    -- Позиция окна
    local pos = QTM.sv.editorWindow
    if pos and pos.x and pos.y then
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end

    -- Сцена: курсор мыши и закрытие по Esc
    self.fragment = ZO_SimpleSceneFragment:New(win)
    self.scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    self.scene:AddFragment(self.fragment)
    self.scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            -- Список локаций может измениться (например, добавили дом игрока)
            self.filter.zone = nil
            self:FillZoneCombo()
            self:Refresh()
        elseif newState == SCENE_HIDDEN then
            ZO_Tooltips_HideTextTooltip()
        end
    end)
end

function Settings:Show()
    SCENE_MANAGER:Show(SCENE_NAME)
end

function Settings:Toggle()
    SCENE_MANAGER:Toggle(SCENE_NAME)
end

function Settings:Hide()
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then
        SCENE_MANAGER:Hide(SCENE_NAME)
    end
end

function Settings:OnMoveStop()
    QTM.sv.editorWindow = { x = self.window:GetLeft(), y = self.window:GetTop() }
end

function Settings:FillZoneCombo()
    local combo = self.zoneCombo
    combo:ClearItems()
    local allEntry = combo:CreateItemEntry(L.ZONE_ALL, function()
        self.filter.zone = nil
        self:Refresh()
    end)
    combo:AddItem(allEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    for _, zoneName in ipairs(Data:GetZones()) do
        combo:AddItem(combo:CreateItemEntry(zoneName, function()
            self.filter.zone = zoneName
            self:Refresh()
        end), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    combo:SelectItem(allEntry, true)
end

function Settings:FillTypeCombo()
    local combo = self.typeCombo
    combo:ClearItems()
    local allEntry = combo:CreateItemEntry(L.TYPE_ALL, function()
        self.filter.type = nil
        self:Refresh()
    end)
    combo:AddItem(allEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    for _, typeId in ipairs(Data.TYPE_LIST) do
        combo:AddItem(combo:CreateItemEntry(Data.TYPE_NAMES[typeId], function()
            self.filter.type = typeId
            self:Refresh()
        end), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    combo:SelectItem(allEntry, true)
end

---------------------------------------------------------------------------
-- Фильтрация и наполнение списка
---------------------------------------------------------------------------
function Settings:PassesFilter(node, query)
    local f = self.filter
    if f.zone and node.zoneName ~= f.zone then return false end
    if f.type and node.type ~= f.type then return false end
    if f.onlyFavorites and not Data:IsFavorite(node.nodeIndex) then return false end
    if query ~= "" and not node.searchKey:find(query, 1, true) then return false end
    return true
end

function Settings:Refresh()
    if not self.list then return end

    local query = lower(Trim(self.filter.text or ""))
    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)

    -- Группируем подходящие места по локациям (узлы уже отсортированы)
    local currentHeader
    for _, node in ipairs(Data:GetNodes()) do
        if self:PassesFilter(node, query) then
            local available, reason = Data:GetNodeStatus(node)
            if available or not self.filter.onlyOpen then
                if not currentHeader or currentHeader.zoneName ~= node.zoneName then
                    currentHeader = { zoneName = node.zoneName, nodes = {} }
                    dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_HEADER, currentHeader)
                end
                currentHeader.nodes[#currentHeader.nodes + 1] = node
                dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW, {
                    node      = node,
                    available = available,
                    reason    = reason,
                })
            end
        end
    end

    if #dataList == 0 then
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY, { text = L.EDITOR_NOTHING })
    end

    ZO_ScrollList_Commit(self.list)
    self:UpdateCounter()
end

-- Обновить окно, если оно открыто (например, после добавления места с карты)
function Settings:RefreshEditor()
    if self.scene and self.scene:IsShowing() then
        self:Refresh()
    end
end

function Settings:UpdateCounter()
    if self.counter then
        self.counter:SetText(zo_strformat(L.EDITOR_COUNT, Data:CountFavorites()))
    end
end

-- Перерисовать видимые строки без пересборки списка (после щелчка по галочке)
function Settings:RefreshVisible()
    if self.filter.onlyFavorites then
        self:Refresh()  -- снятые места должны исчезнуть
    else
        ZO_ScrollList_RefreshVisible(self.list)
        self:UpdateCounter()
    end
end

---------------------------------------------------------------------------
-- Отрисовка строк
---------------------------------------------------------------------------
function Settings:SetupHeader(control, data)
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)
    control:GetNamedChild("Text"):SetText(data.zoneName)

    local selected = 0
    for _, node in ipairs(data.nodes) do
        if Data:IsFavorite(node.nodeIndex) then selected = selected + 1 end
    end
    control:GetNamedChild("Count"):SetText(string.format("%d / %d", selected, #data.nodes))
end

function Settings:SetupRow(control, data)
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)

    local node  = data.node
    local check = control:GetNamedChild("Check")
    local icon  = control:GetNamedChild("Icon")
    local name  = control:GetNamedChild("Name")
    local info  = control:GetNamedChild("Info")
    control:GetNamedChild("Highlight"):SetAlpha(0)

    ZO_CheckButton_SetCheckState(check, Data:IsFavorite(node.nodeIndex))
    ZO_CheckButton_SetToggleFunction(check, function(_, checked)
        Data:SetFavorite(node.nodeIndex, checked)
        self:RefreshVisible()
    end)

    icon:SetTexture(node.icon)
    name:SetText(node.name)

    if data.available then
        icon:SetDesaturation(0)
        SetColor(name, ZO_HIGHLIGHT_TEXT)
        info:SetText(Data.TYPE_NAMES[node.type])
        SetColor(info, ZO_NORMAL_TEXT)
    else
        icon:SetDesaturation(1)
        SetColor(name, ZO_DISABLED_TEXT)
        info:SetText(Data.TYPE_NAMES[node.type] .. " · " .. (data.reason or ""))
        SetColor(info, ZO_DISABLED_TEXT)
    end
end

---------------------------------------------------------------------------
-- Мышь (обработчики вызываются из MundusGate.xml)
---------------------------------------------------------------------------
function Settings:OnRowEnter(control)
    control:GetNamedChild("Highlight"):SetAlpha(1)
end

function Settings:OnRowExit(control)
    control:GetNamedChild("Highlight"):SetAlpha(0)
end

function Settings:OnRowClicked(control, button)
    local data = control.data
    if not data then return end
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()
        AddMenuItem(L.CTX_RENAME, function() Data:ShowRenameDialog(data.node) end)
        ShowMenu(control)
        return
    end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local nodeIndex = data.node.nodeIndex
    Data:SetFavorite(nodeIndex, not Data:IsFavorite(nodeIndex))
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:RefreshVisible()
end

function Settings:OnHeaderEnter(control)
    QTM.ShowTip("windows", control, TOP, L.EDITOR_HEADER_TT)
end

function Settings:OnHeaderExit()
    ZO_Tooltips_HideTextTooltip()
end

-- Щелчок по названию локации: если отмечено не всё — отметить всё, иначе снять всё
function Settings:OnHeaderClicked(control, button)
    local data = control.data
    if not data or button ~= MOUSE_BUTTON_INDEX_LEFT then return end

    local allSelected = true
    for _, node in ipairs(data.nodes) do
        if not Data:IsFavorite(node.nodeIndex) then
            allSelected = false
            break
        end
    end
    for _, node in ipairs(data.nodes) do
        Data:SetFavorite(node.nodeIndex, not allSelected)
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:RefreshVisible()
end
