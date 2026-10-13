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

    local function RouteOption(source, name, tooltip)
        local key = "route" .. source
        return {
            type    = "checkbox",
            name    = name,
            tooltip = tooltip,
            width   = "half",
            getFunc = function() return sv[key] end,
            setFunc = function(value)
                sv[key] = value
                if QTM.RefreshTravelState then QTM.RefreshTravelState() end
            end,
            default = defaults[key],
        }
    end

    local options = {
        { type = "description", text = L.SETTINGS_DESC },

        -- Мои места
        { type = "header", name = L.HEADER_PLACES },
        { type = "description", text = L.PLACES_DESC },
        { type = "button", name = L.OPT_OPEN_EDITOR, width = "half", func = function() self:Show() end },
        {
            type    = "checkbox",
            name    = L.OPT_MAP_ENTRY,
            tooltip = L.OPT_MAP_ENTRY_TT,
            getFunc = function() return sv.mapEntry end,
            setFunc = function(value) sv.mapEntry = value end,
            default = defaults.mapEntry,
        },
        {
            type    = "checkbox",
            name    = L.OPT_MAP_PANEL,
            tooltip = L.OPT_MAP_PANEL_TT,
            getFunc = function() return sv.mapPanel end,
            setFunc = function(value)
                sv.mapPanel = value
                QTM.MapPanel:UpdateVisibility()
            end,
            default = defaults.mapPanel,
        },

        -- Бесплатный путь через игрока: своя галочка для каждого способа
        { type = "header", name = L.HEADER_ROUTE },
        { type = "description", text = L.ROUTE_DESC },
        RouteOption("Menu", L.OPT_ROUTE_MENU, L.OPT_ROUTE_MENU_TT),
        RouteOption("Buttons", L.OPT_ROUTE_BUTTONS, L.OPT_ROUTE_BUTTONS_TT),
        RouteOption("Wheel", L.OPT_ROUTE_WHEEL, L.OPT_ROUTE_WHEEL_TT),
        RouteOption("Map", L.OPT_ROUTE_MAP, L.OPT_ROUTE_MAP_TT),
        RouteOption("Quest", L.OPT_ROUTE_QUEST, L.OPT_ROUTE_QUEST_TT),

        -- Карта мира и задания
        { type = "header", name = L.HEADER_QUESTS },
        { type = "description", text = L.QUESTS_DESC },
        {
            type    = "checkbox",
            name    = L.OPT_INFO_PANEL,
            tooltip = L.OPT_INFO_PANEL_TT,
            getFunc = function() return sv.infoPanel end,
            setFunc = function(value)
                sv.infoPanel = value
                QTM.InfoPanel:UpdateVisibility()
            end,
            default = defaults.infoPanel,
        },
        {
            type    = "checkbox",
            name    = L.OPT_ZOOM_BAR,
            tooltip = L.OPT_ZOOM_BAR_TT,
            getFunc = function() return sv.zoomBar end,
            setFunc = function(value)
                sv.zoomBar = value
                QTM.ZoomBar:Apply()
            end,
            default = defaults.zoomBar,
        },
        {
            type    = "checkbox",
            name    = L.OPT_TRACKER,
            tooltip = L.OPT_TRACKER_TT,
            getFunc = function() return sv.questTracker end,
            setFunc = function(value)
                sv.questTracker = value
                QTM.QuestTracker:ApplySettings()
            end,
            default = defaults.questTracker,
        },
        {
            type     = "checkbox",
            name     = L.OPT_HIDE_GAME_TRACKER,
            tooltip  = L.OPT_HIDE_GAME_TRACKER_TT,
            getFunc  = function() return sv.hideGameTracker end,
            setFunc  = function(value)
                sv.hideGameTracker = value
                QTM.QuestTracker:ApplySettings()
            end,
            disabled = function() return not sv.questTracker end,
            default  = defaults.hideGameTracker,
        },
        {
            type     = "checkbox",
            name     = L.OPT_TRACKER_LOCKED,
            tooltip  = L.OPT_TRACKER_LOCKED_TT,
            getFunc  = function() return sv.trackerLocked end,
            setFunc  = function(value)
                sv.trackerLocked = value
                QTM.QuestTracker:ApplySettings()
            end,
            disabled = function() return not sv.questTracker end,
            width    = "half",
            default  = defaults.trackerLocked,
        },
        {
            type     = "button",
            name     = L.OPT_TRACKER_RESET,
            func     = function() QTM.QuestTracker:ResetPosition() end,
            disabled = function() return not sv.questTracker end,
            width    = "half",
        },

        -- Кнопки на экране
        { type = "header", name = L.HEADER_BUTTONS },
        { type = "description", text = L.BUTTONS_DESC },
        {
            type  = "button",
            name  = L.OPT_ADD_BUTTON,
            width = "half",
            func  = function()
                local item = QTM.Buttons:Add(nil)
                QTM.ButtonsEditor:Show(item.id)
            end,
        },
        {
            type  = "button",
            name  = L.OPT_OPEN_BUTTONS,
            width = "half",
            func  = function() QTM.ButtonsEditor:Show() end,
        },
        {
            type    = "checkbox",
            name    = L.OPT_BUTTONS_VISIBLE,
            getFunc = function() return sv.buttonsVisible end,
            setFunc = function(value)
                sv.buttonsVisible = value
                QTM.Buttons:UpdateVisibility()
            end,
            default = defaults.buttonsVisible,
        },
        {
            type    = "checkbox",
            name    = L.OPT_BUTTONS_LOCKED,
            tooltip = L.OPT_BUTTONS_LOCKED_TT,
            getFunc = function() return sv.buttonsLocked end,
            setFunc = function(value) QTM.Buttons:SetLocked(value) end,
            default = defaults.buttonsLocked,
        },
        {
            type    = "checkbox",
            name    = L.OPT_BUTTONS_TOOLTIPS,
            tooltip = L.OPT_BUTTONS_TOOLTIPS_TT,
            getFunc = function() return sv.buttonsTooltips end,
            setFunc = function(value) sv.buttonsTooltips = value end,
            default = defaults.buttonsTooltips,
        },
        {
            type    = "checkbox",
            name    = L.OPT_BUTTONS_COMBAT,
            getFunc = function() return sv.buttonsHideInCombat end,
            setFunc = function(value)
                sv.buttonsHideInCombat = value
                QTM.Buttons:UpdateVisibility()
            end,
            default = defaults.buttonsHideInCombat,
        },

        -- Колесо
        { type = "header", name = L.HEADER_WHEEL },
        { type = "description", text = L.WHEEL_DESC },
        { type = "button", name = L.OPT_OPEN_WHEEL, width = "half", func = function() QTM.WheelEditor:Show() end },
        {
            type    = "checkbox",
            name    = L.OPT_WHEEL_ENABLED,
            tooltip = L.OPT_WHEEL_ENABLED_TT,
            getFunc = function() return sv.utilityWheelEnabled end,
            setFunc = function(value) sv.utilityWheelEnabled = value end,
            default = defaults.utilityWheelEnabled,
        },
        {
            type    = "checkbox",
            name    = L.OPT_WHEEL_START,
            tooltip = L.OPT_WHEEL_START_TT,
            getFunc = function() return sv.utilityWheelStartOnTravel end,
            setFunc = function(value) sv.utilityWheelStartOnTravel = value end,
            default = defaults.utilityWheelStartOnTravel,
            disabled = function() return not sv.utilityWheelEnabled end,
        },

        -- Основное
        { type = "header", name = L.HEADER_GENERAL },
        {
            type    = "checkbox",
            name    = L.OPT_AT_WAYSHRINE,
            tooltip = L.OPT_AT_WAYSHRINE_TT,
            getFunc = function() return sv.showAtWayshrine end,
            setFunc = function(value) sv.showAtWayshrine = value end,
            default = defaults.showAtWayshrine,
        },
        {
            type    = "checkbox",
            name    = L.OPT_FREE_FRIENDS,
            tooltip = L.OPT_FREE_FRIENDS_TT,
            getFunc = function() return sv.freeViaFriends end,
            setFunc = function(value) sv.freeViaFriends = value; QTM.Presence:MarkDirty(); QTM.Presence.lastBuild = nil end,
            default = defaults.freeViaFriends,
        },
        {
            type    = "checkbox",
            name    = L.OPT_FREE_GUILD,
            tooltip = L.OPT_FREE_GUILD_TT,
            getFunc = function() return sv.freeViaGuild end,
            setFunc = function(value) sv.freeViaGuild = value; QTM.Presence:MarkDirty(); QTM.Presence.lastBuild = nil end,
            default = defaults.freeViaGuild,
        },
        {
            type    = "checkbox",
            name    = L.OPT_FREE_GROUP,
            tooltip = L.OPT_FREE_GROUP_TT,
            getFunc = function() return sv.freeViaGroup end,
            setFunc = function(value) sv.freeViaGroup = value end,
            default = defaults.freeViaGroup,
        },

        {
            type    = "checkbox",
            name    = L.OPT_CONFIRM,
            tooltip = L.OPT_CONFIRM_TT,
            getFunc = function() return sv.confirmTravel end,
            setFunc = function(value) sv.confirmTravel = value end,
            default = defaults.confirmTravel,
        },
        {
            type    = "checkbox",
            name    = L.OPT_GROUP,
            tooltip = L.OPT_GROUP_TT,
            getFunc = function() return sv.groupByZone end,
            setFunc = function(value) sv.groupByZone = value end,
            default = defaults.groupByZone,
        },
        {
            type    = "checkbox",
            name    = L.OPT_SHOW_UNAVAIL,
            tooltip = L.OPT_SHOW_UNAVAIL_TT,
            getFunc = function() return sv.showUnavailable end,
            setFunc = function(value) sv.showUnavailable = value end,
            default = defaults.showUnavailable,
        },
        {
            type    = "dropdown",
            name    = L.OPT_HOUSE,
            choices = { L.HOUSE_INSIDE, L.HOUSE_OUTSIDE },
            getFunc = function() return sv.houseOutside and L.HOUSE_OUTSIDE or L.HOUSE_INSIDE end,
            setFunc = function(value) sv.houseOutside = (value == L.HOUSE_OUTSIDE) end,
            default = L.HOUSE_INSIDE,
        },

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
    ZO_Tooltips_ShowTextTooltip(control, TOP, L.EDITOR_HEADER_TT)
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
