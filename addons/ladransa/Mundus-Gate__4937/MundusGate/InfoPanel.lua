-- Панель справа от карты мира — вместо правой панели игры.
--
-- Вкладки (по порядку): Задания (своя вкладка Mundus Gate), Фильтры, Локации,
-- Дома, Реликвии (если открыты навыки антиквара) и Обозначения.
--
-- Фильтры, Локации, Дома, Реликвии и Обозначения — вкладки самой игры:
-- аддон встраивает их содержимое в свою панель (как «Завершение области»
-- слева) и оформляет в своём стиле, а вкладки игры остаются рабочими — их
-- содержимое, фильтры других аддонов (HarvestMap, SkyShards и т. п.) и
-- щелчки работают как обычно. Своя вкладка «Задания» заменяет вкладку игры.
--
-- Панель стоит вплотную к правому краю окна карты, по его высоте.
local QTM   = MundusGate
local L     = QTM.L
local Style = QTM.Style

local InfoPanel = {}
QTM.InfoPanel = InfoPanel

local TYPE_SECTION = 1
local TYPE_GROUP   = 2
local TYPE_ROW     = 3
local TYPE_EMPTY   = 4
local ROW_HEIGHT   = 56

local MAP_GAP         = 10
local SCREEN_EDGE     = 8
local MIN_WIDTH       = 330
local MAX_WIDTH       = 420
local LAYOUT_EVERY_MS = 500
local SYNC_EVERY_MS   = 150

-- Вкладка «Задания» не принадлежит игре: такого имени у панели игры нет,
-- и при открытии карты игра ничего из своих вкладок не включает
local QUESTS_SENTINEL = "MundusGateQuests"

local GOLD   = Style.GOLD
local ICE    = Style.ICE
local MUTED  = Style.MUTED
local TEXT   = Style.TEXT
local INFO   = Style.INFO
local GROUP  = Style.GROUP

-- Цвет полоски у пункта: задания — золото, стремления — янтарь, фолиант — сирень
local KIND_COLORS = Style.KIND_COLORS
InfoPanel.KIND_COLORS = KIND_COLORS

local ICON_TRAVEL = "EsoUI/Art/ZoneStories/completionTypeIcon_wayshrine.dds"
local ICON_PIN    = "EsoUI/Art/WritAdvisor/advisor_trackedPin_icon.dds"
local ICON_MAIN   = "EsoUI/Art/Collections/Favorite_StarOnly.dds"
InfoPanel.ICON_TRAVEL = ICON_TRAVEL
InfoPanel.ICON_PIN    = ICON_PIN
InfoPanel.ICON_MAIN   = ICON_MAIN

local lower = zo_strlower or string.lower

-- Вкладки. mode — имя вкладки в панели игры
local TABS = {
    { key = "quests",      text = "INFO_TAB_QUESTS",      icon = "EsoUI/Art/WorldMap/map_indexIcon_quests_%s.dds" },
    { key = "filters",     text = "INFO_TAB_FILTERS",     icon = "EsoUI/Art/WorldMap/map_indexIcon_filters_%s.dds",   mode = "SI_MAP_INFO_MODE_FILTERS" },
    { key = "locations",   text = "INFO_TAB_LOCATIONS",   icon = "EsoUI/Art/WorldMap/map_indexIcon_locations_%s.dds", mode = "SI_MAP_INFO_MODE_LOCATIONS" },
    { key = "houses",      text = "INFO_TAB_HOUSES",      icon = "EsoUI/Art/WorldMap/map_indexIcon_housing_%s.dds",   mode = "SI_MAP_INFO_MODE_HOUSES" },
    { key = "antiquities", text = "INFO_TAB_ANTIQUITIES", icon = "EsoUI/Art/Journal/journal_tabIcon_antiquities_%s.dds", mode = "SI_MAP_INFO_MODE_ANTIQUITIES",
      visible = function() return AreAntiquitySkillLinesDiscovered == nil or AreAntiquitySkillLinesDiscovered() end },
    { key = "key",         text = "INFO_TAB_KEY",         icon = "EsoUI/Art/WorldMap/map_indexIcon_key_%s.dds",       mode = "SI_MAP_INFO_MODE_KEY" },
}

-- Содержимое вкладок игры и его внутренний отступ слева (у списков игры он 20)
local CONTENT = {
    { name = "ZO_WorldMapQuests",               inset = 0 },
    { name = "ZO_WorldMapKey",                  inset = 20 },
    { name = "ZO_WorldMapFilters",              inset = 20 },
    { name = "ZO_WorldMapLocations",            inset = 20 },
    { name = "ZO_WorldMapHouses",               inset = 20 },
    { name = "ZO_WorldMapAntiquities_Keyboard", inset = 0 },
}

local function GetTabDef(key)
    for _, def in ipairs(TABS) do
        if def.key == key then return def end
    end
    return nil
end

local function GetMode(def)
    return def and def.mode and _G[def.mode] or nil
end

local function IsTabVisible(def)
    return def.visible == nil or def.visible()
end

---------------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------------
function InfoPanel:Initialize()
    local root = MundusGateInfoRoot
    self.root  = root
    self.panel = root:GetNamedChild("Panel")
    local panel = self.panel

    self.title        = panel:GetNamedChild("Title")
    self.content      = panel:GetNamedChild("Content")
    self.tabIndicator = panel:GetNamedChild("TabIndicator")
    self.tabIndicator:SetColor(ICE[1], ICE[2], ICE[3], 1)
    panel:GetNamedChild("TabLine"):SetColor(1, 1, 1, 0.12)

    -- Вкладки-значки
    local tabsArea = panel:GetNamedChild("Tabs")
    self.tabButtons = {}
    for _, def in ipairs(TABS) do
        local button = CreateControlFromVirtual(tabsArea:GetName() .. def.key, tabsArea, "MundusGate_InfoTab")
        button.tabKey = def.key
        button.def = def
        self.tabButtons[def.key] = button
    end

    -- Справа вверху: режим панели заданий на экране — все задания журнала (T)
    -- или только выбранные здесь
    local mode = WINDOW_MANAGER:CreateControl(panel:GetName() .. "TrackerMode", panel, CT_BUTTON)
    mode:SetDimensions(30, 30)
    mode:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -12, 11)
    mode:SetMouseEnabled(true)
    local modeBg = WINDOW_MANAGER:CreateControl(mode:GetName() .. "Bg", mode, CT_TEXTURE)
    modeBg:SetAnchorFill(mode)
    local modeIcon = WINDOW_MANAGER:CreateControl(mode:GetName() .. "Icon", mode, CT_TEXTURE)
    modeIcon:SetDimensions(22, 22)
    modeIcon:SetAnchor(CENTER, mode, CENTER, 0, 0)
    modeIcon:SetTexture("EsoUI/Art/Compass/quest_icon_assisted.dds")
    mode.bg, mode.icon = modeBg, modeIcon
    mode:SetHandler("OnClicked", function() QTM.QuestTracker:ToggleMode() end)
    mode:SetHandler("OnMouseEnter", function(c)
        c.isHover = true
        self:PaintModeButton()
        local selected = QTM.QuestTracker:IsSelectedMode()
        QTM.ShowTip("infoPanel", c, BOTTOM, (selected and L.TRACKER_MODE_SELECTED_TT or L.TRACKER_MODE_JOURNAL_TT)
            .. "\n|c8A8A8A" .. L.TRACKER_MODE_HINT .. "|r")
    end)
    mode:SetHandler("OnMouseExit", function(c)
        c.isHover = false
        self:PaintModeButton()
        ZO_Tooltips_HideTextTooltip()
    end)
    self.modeButton = mode
    self:PaintModeButton()

    -- Поиск группы (внизу панели)
    self.status = panel:GetNamedChild("Status")
    self.status:GetNamedChild("Bg"):SetColor(0.08, 0.12, 0.14, 0.85)
    self.status:GetNamedChild("Stripe"):SetColor(ICE[1], ICE[2], ICE[3], 1)
    self.status:GetNamedChild("Line"):SetColor(1, 1, 1, 0.12)
    self.status:GetNamedChild("Travel"):SetText(L.GROUP_TRAVEL)

    -- Задания
    self.questsView = panel:GetNamedChild("Quests")
    local search = self.questsView:GetNamedChild("SearchBgBox")
    search:SetMaxInputChars(60)
    if search.SetDefaultText then search:SetDefaultText(L.QUEST_SEARCH) end
    search:SetHandler("OnTextChanged", function(edit)
        self.query = lower(zo_strtrim(edit:GetText()))
        self:RefreshQuests()
    end)
    self.search = search
    self.query  = ""

    local list = self.questsView:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_SECTION, "MundusGate_QuestSection", 34,
        function(control, data) self:SetupSection(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_GROUP, "MundusGate_QuestGroup", 26,
        function(control, data) self:SetupGroup(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_ROW, "MundusGate_QuestRow", ROW_HEIGHT,
        function(control, data) self:SetupRow(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_EMPTY, "MundusGate_Empty", 90,
        function(control, data) QTM.Menu:SetupEmpty(control, data, list) end)

    -- Сохранённая вкладка
    local saved = QTM.sv.infoTab
    self.tab = GetTabDef(saved) and saved or "quests"

    self.fragment = ZO_SimpleSceneFragment:New(root)
    if WORLD_MAP_SCENE then
        WORLD_MAP_SCENE:AddFragment(self.fragment)
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                self:Refresh()
            elseif newState == SCENE_SHOWN then
                -- Игра при открытии карты включает свою последнюю вкладку — сверяемся
                self:ApplyTab()
            elseif newState == SCENE_HIDDEN then
                ZO_Tooltips_HideTextTooltip()
                ClearMenu()
            end
        end)
    end

    panel:SetHandler("OnUpdate", function()
        local now = GetFrameTimeMilliseconds()
        if not self.nextLayout or now >= self.nextLayout then
            self.nextLayout = now + LAYOUT_EVERY_MS
            self:Layout()
        end
        if not self.nextSync or now >= self.nextSync then
            self.nextSync = now + SYNC_EVERY_MS
            self:SyncFromGame()
        end
        if not self.nextStatus or now >= self.nextStatus then
            self.nextStatus = now + 1000
            self:UpdateGroupStatus()
        end
    end)

    self:UpdateVisibility()
end

---------------------------------------------------------------------------
-- Размер и положение: вплотную к правому краю окна карты, по его высоте
---------------------------------------------------------------------------
function InfoPanel:Layout()
    if self.previewState then return end
    local panel = self.panel
    local map = ZO_WorldMap
    if not map or not map.GetRight then return end
    local right, top, bottom = map:GetRight(), map:GetTop(), map:GetBottom()
    if not right or not top or not bottom or bottom <= top then return end

    local screenWidth = GuiRoot:GetWidth()
    local available = screenWidth - right - MAP_GAP - SCREEN_EDGE
    local width = zo_clamp(available, MIN_WIDTH, MAX_WIDTH)
    local key = string.format("%d:%d:%d:%d", right, top, bottom, width)
    if key == self.layoutKey then return end
    self.layoutKey = key

    panel:ClearAnchors()
    if available >= MIN_WIDTH then
        panel:SetAnchor(TOPLEFT, map, TOPRIGHT, MAP_GAP, 0)
        panel:SetAnchor(BOTTOMLEFT, map, BOTTOMRIGHT, MAP_GAP, 0)
    else
        -- Справа от карты нет места (карта во весь экран): ставим у края экрана
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, screenWidth - SCREEN_EDGE, top)
        panel:SetAnchor(BOTTOMRIGHT, GuiRoot, TOPLEFT, screenWidth - SCREEN_EDGE, bottom)
    end
    panel:SetWidth(width)
    self:LayoutTabs()
    if self.list then ZO_ScrollList_RefreshVisible(self.list) end
end

function InfoPanel:LayoutTabs()
    local x = 0
    for _, def in ipairs(TABS) do
        local button = self.tabButtons[def.key]
        local visible = IsTabVisible(def)
        button:SetHidden(not visible)
        if visible then
            button:ClearAnchors()
            button:SetAnchor(LEFT, button:GetParent(), LEFT, x, 0)
            x = x + 44
        end
    end
end

---------------------------------------------------------------------------
-- Видимость
---------------------------------------------------------------------------
function InfoPanel:IsEnabled()
    return QTM.sv.infoPanel ~= false
end

function InfoPanel:IsShown()
    return self.panel ~= nil and WORLD_MAP_SCENE ~= nil and WORLD_MAP_SCENE:IsShowing()
        and not self.panel:IsHidden()
end

function InfoPanel:UpdateVisibility()
    if not self.panel then return end
    local enabled = self:IsEnabled()
    self.panel:SetHidden(not enabled)
    if enabled then
        self:Adopt()
    else
        self:Release()
    end
end

function InfoPanel:Refresh()
    self:UpdateVisibility()
    self:PaintModeButton()
    if not self:IsEnabled() then return end
    self.layoutKey = nil
    self:Layout()
    if not IsTabVisible(GetTabDef(self.tab)) then self.tab = "quests" end
    self:ApplyTab()
    self:RefreshQuests()
    self:UpdateGroupStatus()
end

---------------------------------------------------------------------------
-- Встраивание правой панели игры
---------------------------------------------------------------------------
function InfoPanel:GetGameInfo()
    local info = WORLD_MAP_INFO
    local control = ZO_WorldMapInfo
    if info and control and info.modeBar then
        return info, control
    end
    return nil
end

function InfoPanel:Adopt()
    local info, control = self:GetGameInfo()
    if not info or self.adopted then return end
    self.adopted = true
    self.menuBar = control:GetNamedChild("MenuBar")

    -- Свои вкладки и заголовок — вкладки игры прячем
    if self.menuBar then self.menuBar:SetHidden(true) end

    self.infoTier = control:GetDrawTier()
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, self.content, TOPLEFT, 0, 0)
    control:SetAnchor(BOTTOMRIGHT, self.content, BOTTOMRIGHT, 0, 0)
    control:SetDrawTier(DT_MEDIUM)

    self.contentTiers = {}
    for _, entry in ipairs(CONTENT) do
        local content = _G[entry.name]
        if content then
            self.contentTiers[entry.name] = content:GetDrawTier()
            content:ClearAnchors()
            content:SetAnchor(TOPLEFT, self.content, TOPLEFT, -entry.inset, 0)
            content:SetAnchor(BOTTOMRIGHT, self.content, BOTTOMRIGHT, 0, 0)
            content:SetDrawTier(DT_MEDIUM)
        end
    end

    -- Фон игры (тёмная полоса справа) не нужен: фон даёт панель
    if WORLD_MAP_SCENE and WORLD_MAP_INFO_BG_FRAGMENT then
        WORLD_MAP_SCENE:RemoveFragment(WORLD_MAP_INFO_BG_FRAGMENT)
    end

    -- Своя вкладка «Задания»: игра не должна включать свою вкладку заданий
    if self.tab == "quests" then
        info.modeBar:SetStartingFragment(QUESTS_SENTINEL)
    else
        local mode = GetMode(GetTabDef(self.tab))
        if mode then info.modeBar:SetStartingFragment(mode) end
    end

    self:InstallSkins()
end

function InfoPanel:Release()
    local info, control = self:GetGameInfo()
    if not info or not self.adopted then return end
    self.adopted = false

    if self.menuBar then self.menuBar:SetHidden(false) end
    control:ClearAnchors()
    control:SetAnchor(RIGHT, GuiRoot, RIGHT, 0, -2)
    control:SetDimensions(350, 690)
    if self.infoTier then control:SetDrawTier(self.infoTier) end

    for _, entry in ipairs(CONTENT) do
        local content = _G[entry.name]
        if content then
            content:ClearAnchors()
            content:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 95)
            content:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -20, 0)
            local tier = self.contentTiers and self.contentTiers[entry.name]
            if tier then content:SetDrawTier(tier) end
        end
    end

    if WORLD_MAP_SCENE and WORLD_MAP_INFO_BG_FRAGMENT then
        WORLD_MAP_SCENE:AddFragment(WORLD_MAP_INFO_BG_FRAGMENT)
    end
    -- Без своей вкладки «Задания» игра снова открывает свою
    if info.modeBar:GetLastFragment() == QUESTS_SENTINEL and SI_MAP_INFO_MODE_QUESTS then
        info.modeBar:SetStartingFragment(SI_MAP_INFO_MODE_QUESTS)
    end
end

---------------------------------------------------------------------------
-- Вкладки
---------------------------------------------------------------------------
function InfoPanel:PaintTabs()
    for key, button in pairs(self.tabButtons) do
        local def = button.def
        local state = key == self.tab and "down" or (button.isHover and "over" or "up")
        button:GetNamedChild("Icon"):SetTexture(string.format(def.icon, state))
    end
    local active = self.tabButtons[self.tab]
    if active then
        self.tabIndicator:ClearAnchors()
        self.tabIndicator:SetAnchor(TOP, active, BOTTOM, 0, 2)
    end
    local def = GetTabDef(self.tab)
    self.title:SetText(def and L[def.text] or "")
end

function InfoPanel:OnTabEnter(button)
    button.isHover = true
    self:PaintTabs()
    QTM.ShowTip("infoPanel", button, BOTTOM, L[button.def.text])
end

function InfoPanel:OnTabExit(button)
    button.isHover = false
    self:PaintTabs()
    ZO_Tooltips_HideTextTooltip()
end

function InfoPanel:SelectTab(key)
    local def = GetTabDef(key)
    if not def or not IsTabVisible(def) then return end
    if key ~= self.tab then PlaySound(SOUNDS.DEFAULT_CLICK) end
    self.tab = key
    QTM.sv.infoTab = key
    self:ApplyTab()
    if key == "quests" then self:RefreshQuests() end
end

-- Показать выбранную вкладку: свою — спрятав вкладку игры, игровую — через панель игры
function InfoPanel:ApplyTab()
    if not self.panel then return end
    local isQuests = self.tab == "quests"
    self.questsView:SetHidden(not isQuests)
    self:PaintTabs()

    local info = self:GetGameInfo()
    if not info or not self.adopted then return end
    local bar = info.modeBar
    if isQuests then
        if bar.currentFragmentGroup and SCENE_MANAGER then
            SCENE_MANAGER:RemoveFragmentGroup(bar.currentFragmentGroup)
        end
        bar.currentFragmentGroup = nil
        if bar.RemoveActiveKeybind then bar:RemoveActiveKeybind() end
        if self.menuBar then ZO_MenuBar_ClearSelection(self.menuBar) end
        bar:SetStartingFragment(QUESTS_SENTINEL)
    else
        local mode = GetMode(GetTabDef(self.tab))
        if mode then info:SelectTab(mode) end
    end
    self.lastSelected = self.menuBar and ZO_MenuBar_GetSelectedDescriptor(self.menuBar) or nil
end

-- Вкладку игры могли включить в обход панели (например, щелчком по реликвии) — подстраиваемся
local MODE_TO_TAB

function InfoPanel:SyncFromGame()
    if not self.adopted or not self.menuBar then return end
    local selected = ZO_MenuBar_GetSelectedDescriptor(self.menuBar)
    if selected == self.lastSelected then return end
    self.lastSelected = selected
    if selected == nil then return end

    if not MODE_TO_TAB then
        MODE_TO_TAB = {}
        for _, def in ipairs(TABS) do
            local mode = GetMode(def)
            if mode then MODE_TO_TAB[mode] = def.key end
        end
    end
    if SI_MAP_INFO_MODE_QUESTS and selected == SI_MAP_INFO_MODE_QUESTS then
        -- Вкладка заданий игры заменена своей
        self.tab = "quests"
        QTM.sv.infoTab = "quests"
        self:ApplyTab()
        self:RefreshQuests()
    elseif MODE_TO_TAB[selected] and MODE_TO_TAB[selected] ~= self.tab then
        self.tab = MODE_TO_TAB[selected]
        QTM.sv.infoTab = self.tab
        self.questsView:SetHidden(true)
        self:PaintTabs()
    end
end

---------------------------------------------------------------------------
-- Предпросмотр рядом с настройками аддона: вкладка «Задания» в заданном
-- месте поверх меню (вкладки игры без карты не показываются)
---------------------------------------------------------------------------
function InfoPanel:SetPreview(enabled, right, top, width, height)
    if not self.panel then return end
    local root, panel = self.root, self.panel
    if enabled then
        if not self:IsEnabled() then return end
        self.previewState = { tab = self.tab, tier = root:GetDrawTier() }
        self.tab = "quests"
        root:SetDrawTier(DT_HIGH)
        root:SetHidden(false)
        panel:SetHidden(false)
        panel:ClearAnchors()
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, right, top)
        panel:SetDimensions(width, height)
        self:LayoutTabs()
        self.questsView:SetHidden(false)
        self:PaintTabs()
        self:RefreshQuests()
        return
    end
    local preview = self.previewState
    if not preview then return end
    self.previewState = nil
    self.tab = preview.tab
    root:SetDrawTier(preview.tier)
    root:SetHidden(true)   -- с картой панель снова покажет её фрагмент
    self.layoutKey = nil
end

function InfoPanel:RefreshPreview()
    if self.previewState then self:PaintTabs(); self:RefreshQuests() end
end

-- Сменилась цветовая тема: перекрасить то, что красится один раз
-- Кнопка режима: включённый «только выбранные» подсвечен цветом темы
function InfoPanel:PaintModeButton()
    local button = self.modeButton
    if not button then return end
    button:SetHidden(not QTM.QuestTracker:IsEnabled())
    local on = QTM.QuestTracker:IsSelectedMode()
    if on then
        button.icon:SetColor(ICE[1], ICE[2], ICE[3], 1)
        button.bg:SetColor(ICE[1], ICE[2], ICE[3], button.isHover and 0.45 or 0.3)
    else
        local value = button.isHover and 1 or 0.6
        button.icon:SetColor(value, value, value, 1)
        button.bg:SetColor(1, 1, 1, button.isHover and 0.12 or 0)
    end
end

function InfoPanel:OnThemeChanged()
    if not self.panel then return end
    self:PaintModeButton()
    self.tabIndicator:SetColor(ICE[1], ICE[2], ICE[3], 1)
    self.status:GetNamedChild("Stripe"):SetColor(ICE[1], ICE[2], ICE[3], 1)
    self:PaintTabs()
    if self:IsShown() then self:Refresh() end
end

---------------------------------------------------------------------------
-- Оформление вкладок игры в стиле аддона: строки — карточки на тёмном фоне,
-- заголовки — золотом
---------------------------------------------------------------------------
local function PaintHeaderLabel(label)
    if not label then return end
    label:SetFont("ZoFontWinH5")
    label:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
    if label.SetModifyTextType and MODIFY_TEXT_TYPE_UPPERCASE then
        label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    end
end

local function EnsureCard(control)
    local bg = control.mgCard
    if not bg then
        bg = CreateControl(control:GetName() .. "MGCard", control, CT_TEXTURE)
        bg:SetDrawLayer(DL_BACKGROUND)
        bg:SetAnchor(TOPLEFT, control, TOPLEFT, -8, 1)
        bg:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, -1)
        control.mgCard = bg
        local stripe = CreateControl(control:GetName() .. "MGStripe", control, CT_TEXTURE)
        stripe:SetDrawLayer(DL_BACKGROUND)
        stripe:SetWidth(3)
        stripe:SetAnchor(TOPLEFT, bg, TOPLEFT, 0, 0)
        stripe:SetAnchor(BOTTOMLEFT, bg, BOTTOMLEFT, 0, 0)
        control.mgStripe = stripe
    end
    return bg, control.mgStripe
end

local function SkinRow(list, control, color, highlight)
    if not InfoPanel:IsEnabled() then return end
    local width = list:GetWidth() - (ZO_SCROLL_BAR_WIDTH or 16) - 12
    if width > 0 then control:SetWidth(width) end
    local bg, stripe = EnsureCard(control)
    local even = (control.index or 1) % 2 == 0
    local r, g, b = Style.Darken(color, even and 0.12 or 0.08)
    bg:SetColor(r, g, b, Style.RowAlpha(false))
    bg:SetHidden(false)
    stripe:SetColor(color.r, color.g, color.b, highlight and 1 or 0.45)
    stripe:SetHidden(false)
end

local function HideCard(control)
    if control.mgCard then control.mgCard:SetHidden(true) end
    if control.mgStripe then control.mgStripe:SetHidden(true) end
end

local SKIN_ICE  = Style.ICE_RGB
local SKIN_GOLD = Style.GOLD_RGB

-- Обернуть отрисовку строк списка игры: сначала игра, потом наше оформление
local function WrapList(list, skin)
    if not list or not list.dataTypes then return end
    for _, dataType in pairs(list.dataTypes) do
        if not dataType.mgSkinned and dataType.setupCallback then
            dataType.mgSkinned = true
            local original = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                original(control, data, ...)
                skin(list, control, data)
            end
        end
    end
end

function InfoPanel:InstallSkins()
    -- Локации: строка-карточка, текущая карта — с яркой полоской
    WrapList(ZO_WorldMapLocationsList, function(list, control, data)
        local selected = WORLD_MAP_LOCATIONS and data and WORLD_MAP_LOCATIONS.selectedMapIndex == data.index
        SkinRow(list, control, SKIN_ICE, selected)
    end)

    -- Дома: заголовки золотом, дома — карточками
    WrapList(ZO_WorldMapHousesList, function(list, control)
        if control:GetNamedChild("Name") then
            SkinRow(list, control, SKIN_GOLD, false)
        else
            if InfoPanel:IsEnabled() then PaintHeaderLabel(control:GetNamedChild("Label")) end
            HideCard(control)
        end
    end)

    -- Реликвии: свои карточки вместо фона игры, заголовки золотом
    WrapList(ZO_WorldMapAntiquities_KeyboardList, function(list, control)
        if not InfoPanel:IsEnabled() then return end
        local backdrop = control:GetNamedChild("Backdrop")
        if control:GetNamedChild("Name") then
            if backdrop then backdrop:SetHidden(true) end
            SkinRow(list, control, KIND_COLORS.p, false)
        else
            PaintHeaderLabel(control:GetNamedChild("Label") or control.label)
            HideCard(control)
        end
    end)

    -- Обозначения: заголовки разделов золотом
    if WORLD_MAP_KEY and not self.keySkinned then
        self.keySkinned = true
        local hook = SecurePostHook or ZO_PostHook
        if hook then
            hook(WORLD_MAP_KEY, "RefreshKey", function(key)
                if not InfoPanel:IsEnabled() or not key.headerPool then return end
                for _, header in pairs(key.headerPool:GetActiveObjects()) do
                    PaintHeaderLabel(header)
                end
            end)
        end
    end
end

---------------------------------------------------------------------------
-- Поиск группы: внизу панели — очередь в подземелье (поле сражения, сказки)
-- или набор группы через «Поиск группы» (испытание, подземелье…): сколько
-- игроков уже нашлось и кнопка перемещения в само подземелье / испытание
---------------------------------------------------------------------------
local STATUS_HEIGHT        = 60
local STATUS_HEIGHT_BUTTON = 94
local ROLE_ICONS = {
    { role = "LFG_ROLE_TANK", icon = "EsoUI/Art/LFG/LFG_tank_down.dds" },
    { role = "LFG_ROLE_HEAL", icon = "EsoUI/Art/LFG/LFG_healer_down.dds" },
    { role = "LFG_ROLE_DPS",  icon = "EsoUI/Art/LFG/LFG_dps_down.dds" },
}
local ICON_DUNGEON = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds"
local ICON_GROUP   = "EsoUI/Art/LFG/LFG_indexIcon_groupFinder_up.dds"
local ICON_BG      = "EsoUI/Art/LFG/LFG_indexIcon_battlegrounds_up.dds"

-- Подземелье, испытание или арена, название которых встречается в тексте (самое длинное совпадение)
function InfoPanel.FindInstanceNode(text)
    if not text or text == "" then return nil end
    local Data = QTM.Data
    local haystack = lower(text)
    local best, bestLength
    for _, node in ipairs(Data:GetNodes()) do
        if node.type == Data.TYPE_DUNGEON or node.type == Data.TYPE_TRIAL or node.type == Data.TYPE_ARENA then
            local name = lower(node.originalName or "")
            if #name > 3 and haystack:find(name, 1, true) and (not bestLength or #name > bestLength) then
                best, bestLength = node, #name
            end
        end
    end
    return best
end

local function FormatElapsed(ms)
    local seconds = zo_max(0, zo_floor(ms / 1000))
    return string.format("%d:%02d", zo_floor(seconds / 60), seconds % 60)
end

-- Сколько игроков нашлось по ролям: «7 / 12   [Т] 1/2  [Х] 2/2  [Б] 4/8»
local function FormatRoles(userType)
    local parts, found, total = {}, 0, 0
    for _, entry in ipairs(ROLE_ICONS) do
        local role = _G[entry.role]
        if role then
            local desired = GetGroupFinderUserTypeGroupListingDesiredRoleCount(userType, role) or 0
            local attained = GetGroupFinderUserTypeGroupListingAttainedRoleCount(userType, role) or 0
            found, total = found + attained, total + desired
            if desired > 0 then
                parts[#parts + 1] = string.format("|t16:16:%s|t %d/%d", entry.icon, attained, desired)
            end
        end
    end
    if total == 0 then return nil end
    return zo_strformat(L.GROUP_FOUND, found, total) .. "   " .. table.concat(parts, "  ")
end

function InfoPanel:GetGroupStatus()
    -- Очередь поиска группы (подземелья, поля сражений, «Сказки»)
    if IsCurrentlySearchingForGroup and IsCurrentlySearchingForGroup() then
        local activityId = GetActivityRequestIds and GetActivityRequestIds(1) or 0
        local name = (activityId and activityId > 0 and GetActivityName) and GetActivityName(activityId) or ""
        local count = GetNumActivityRequests and GetNumActivityRequests() or 1
        if count > 1 then name = zo_strformat(L.QUEST_MORE_LINES, name, count - 1) end
        local info = name
        if GetLFGSearchTimes then
            local startMs, estimateMs = GetLFGSearchTimes()
            if startMs and startMs > 0 then
                info = info .. "\n" .. zo_strformat(L.GROUP_QUEUE_TIME, FormatElapsed(GetFrameTimeMilliseconds() - startMs))
                if estimateMs and estimateMs > 0 and ZO_GetSimplifiedTimeEstimateText then
                    info = info .. " · " .. zo_strformat(L.GROUP_QUEUE_ESTIMATE, ZO_GetSimplifiedTimeEstimateText(estimateMs))
                end
            end
        end
        local isBattleground = activityId and GetActivityType and LFG_ACTIVITY_BATTLE_GROUND_CHAMPION
            and (GetActivityType(activityId) == LFG_ACTIVITY_BATTLE_GROUND_CHAMPION
              or GetActivityType(activityId) == LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION
              or GetActivityType(activityId) == LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL)
        return { title = L.GROUP_QUEUE_TITLE, info = info, icon = isBattleground and ICON_BG or ICON_DUNGEON,
                 node = InfoPanel.FindInstanceNode(name) }
    end

    -- Группа из поиска уже собрана
    if IsInLFGGroup and IsInLFGGroup() and GetCurrentLFGActivityId then
        local activityId = GetCurrentLFGActivityId()
        if activityId and activityId > 0 then
            local name = GetActivityName(activityId) or ""
            return { title = L.GROUP_LFG_TITLE, info = name, icon = ICON_DUNGEON, node = InfoPanel.FindInstanceNode(name) }
        end
    end

    -- Набор через «Поиск группы»: своя группа или заявка в чужую
    if HasGroupListingForUserType and GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING then
        local userTypes = {
            { GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING, false },
            { GROUP_FINDER_GROUP_LISTING_USER_TYPE_APPLIED_TO_GROUP_LISTING, true },
        }
        for _, entry in ipairs(userTypes) do
            local userType, applied = entry[1], entry[2]
            if userType and HasGroupListingForUserType(userType) then
                local category = GetGroupFinderUserTypeGroupListingCategory(userType)
                local isTrial = GROUP_FINDER_CATEGORY_TRIAL ~= nil and category == GROUP_FINDER_CATEGORY_TRIAL
                local option = GetGroupFinderUserTypeGroupListingOptionsSelectionText(userType) or ""
                local listingTitle = GetGroupFinderUserTypeGroupListingTitle(userType) or ""
                local title
                if applied then
                    title = isTrial and L.GROUP_APPLIED_TRIAL or L.GROUP_APPLIED
                else
                    title = isTrial and L.GROUP_TRIAL_TITLE or L.GROUP_LISTING_TITLE
                end
                local lines = {}
                if option ~= "" then lines[#lines + 1] = option end
                if listingTitle ~= "" and listingTitle ~= option then lines[#lines + 1] = "|cA0A0A0" .. listingTitle .. "|r" end
                local roles = FormatRoles(userType)
                if roles then lines[#lines + 1] = roles end
                return { title = title, info = table.concat(lines, "\n"), icon = ICON_GROUP,
                         node = InfoPanel.FindInstanceNode(option .. " " .. listingTitle) }
            end
        end
    end
    return nil
end

function InfoPanel:SetStatusSpace(height)
    local panel = self.panel
    for _, control in ipairs({ self.content, self.questsView }) do
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, panel, TOPLEFT, 16, 92)
        control:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -12, -12 - (height > 0 and height + 14 or 0))
    end
end

function InfoPanel:UpdateGroupStatus()
    if not self.status then return end
    local status = self:IsEnabled() and self:GetGroupStatus() or nil
    self.statusNode = status and status.node or nil
    local height = 0
    if status then
        local block = self.status
        block:GetNamedChild("Icon"):SetTexture(status.icon)
        block:GetNamedChild("Title"):SetText(status.title)
        local info = block:GetNamedChild("Info")
        info:SetText(status.info or "")
        local travel = block:GetNamedChild("Travel")
        travel:SetHidden(status.node == nil)
        if status.node then
            travel:SetText(zo_strformat(L.GROUP_TRAVEL_TO, status.node.name))
            travel:SetWidth(zo_min(block:GetWidth() - 12, 260))
        end
        local textHeight = 6 + 22 + (info:GetTextHeight() or 18) + 8
        height = zo_max(status.node and STATUS_HEIGHT_BUTTON or STATUS_HEIGHT, textHeight + (status.node and 34 or 0))
        block:SetHeight(height)
    end
    self.status:SetHidden(status == nil)
    if height ~= self.statusHeight then
        self.statusHeight = height
        self:SetStatusSpace(height)
    end
end

function InfoPanel:OnStatusTravel()
    local node = self.statusNode
    if not node then return end
    QTM.Data:Travel(node, QTM.QuestTravel:IsDirect(), "Quest")
end

---------------------------------------------------------------------------
-- Вкладка «Задания»
---------------------------------------------------------------------------
function InfoPanel:RefreshQuestsIfShown()
    if self:IsShown() and self.tab == "quests" then self:RefreshQuests() end
end

local function Matches(query, item)
    if query == "" then return true end
    local haystack = lower((item.name or "") .. " " .. (item.info or "") .. " " .. (item.zone or "") .. " " .. (item.group or ""))
    return haystack:find(query, 1, true) ~= nil
end

function InfoPanel:IsCollapsed(section)
    local collapsed = QTM.sv.questCollapsed
    return type(collapsed) == "table" and collapsed[section] == true
end

function InfoPanel:ToggleSection(section)
    if type(QTM.sv.questCollapsed) ~= "table" then QTM.sv.questCollapsed = {} end
    QTM.sv.questCollapsed[section] = not self:IsCollapsed(section) or nil
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:RefreshQuests()
end

function InfoPanel:IsDoneOpen(section)
    local open = QTM.sv.questDoneOpen
    return type(open) == "table" and open[section] == true
end

function InfoPanel:ToggleDone(section)
    if type(QTM.sv.questDoneOpen) ~= "table" then QTM.sv.questDoneOpen = {} end
    QTM.sv.questDoneOpen[section] = not self:IsDoneOpen(section) or nil
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:RefreshQuests()
end

function InfoPanel:RefreshQuests()
    if not self.list then return end
    local list = self.list
    ZO_ScrollList_Clear(list)
    local dataList = ZO_ScrollList_GetDataList(list)
    local Quests = QTM.Quests
    local all = Quests:GetAll()
    local query = self.query or ""
    local shown = {}
    local stripeIndex = 0

    local function AddSection(id, text, icon, count, zone)
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_SECTION, {
            id = id, text = text, icon = icon, count = count, collapsed = self:IsCollapsed(id), zone = zone or "other",
        })
        return not self:IsCollapsed(id)
    end
    local function AddGroup(text, zone, extra)
        local data = { text = text, zone = zone or "other" }
        if extra then for k, v in pairs(extra) do data[k] = v end end
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_GROUP, data)
    end
    local function AddRow(item, zone)
        stripeIndex = stripeIndex + 1
        shown[item.key] = true
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW, { item = item, index = stripeIndex, zone = zone })
    end

    -- Главное
    local main = all.mainKey and all.byKey[all.mainKey]
    if main and Matches(query, main) then
        if AddSection("main", L.QUEST_SECTION_MAIN, ICON_MAIN, nil, "main") then AddRow(main, "main") else shown[main.key] = true end
    end

    -- Закреплённые: раздел есть всегда — сюда можно перетащить задание
    local pinned = {}
    for _, key in ipairs(Quests:GetPins()) do
        local item = all.byKey[key]
        if item and not shown[key] and Matches(query, item) then pinned[#pinned + 1] = item end
    end
    if query == "" or #pinned > 0 then
        local open = AddSection("pinned", L.QUEST_SECTION_PINNED, ICON_PIN, #pinned > 0 and tostring(#pinned) or nil, "pinned")
        for _, item in ipairs(pinned) do
            if open then AddRow(item, "pinned") else shown[item.key] = true end
        end
        if open and #pinned == 0 then AddGroup(L.QUEST_PINNED_EMPTY, "pinned", { hint = true }) end
    end

    -- Журнал: по разделам, как в журнале игры (локации, гильдия, поле сражения, пролог…)
    local quests = {}
    for _, item in ipairs(all.quests) do
        if not shown[item.key] and Matches(query, item) then quests[#quests + 1] = item end
    end
    if #all.quests > 0 then
        local count = string.format("%d / %d", #all.quests, MAX_JOURNAL_QUESTS or 25)
        if AddSection("journal", L.QUEST_SECTION_JOURNAL, Quests.ICON_QUEST, count) then
            local lastGroup
            for _, item in ipairs(quests) do
                local group = item.category or item.zone
                if group ~= lastGroup then
                    lastGroup = group
                    AddGroup(group)
                end
                AddRow(item, "other")
            end
        end
    end

    -- Золотые стремления и фолиант: по кампаниям / видам заданий;
    -- выполненные — в свёрнутой группе «Выполнено» в конце раздела
    local function AddActivities(id, text, icon, items)
        if #items == 0 then return end
        local done, active, finished = 0, {}, {}
        for _, item in ipairs(items) do
            if item.complete then done = done + 1 end
            if not shown[item.key] and Matches(query, item) then
                if item.complete then finished[#finished + 1] = item else active[#active + 1] = item end
            end
        end
        if AddSection(id, text, icon, string.format("%d / %d", done, #items)) then
            local lastGroup
            for _, item in ipairs(active) do
                if item.group ~= lastGroup then
                    lastGroup = item.group
                    AddGroup(item.group)
                end
                AddRow(item, "other")
            end
            if #finished > 0 then
                local open = self:IsDoneOpen(id) or query ~= ""
                AddGroup(zo_strformat(L.QUEST_DONE_GROUP, #finished), "other", { doneToggle = id, open = open })
                if open then
                    for _, item in ipairs(finished) do AddRow(item, "other") end
                end
            end
        end
    end
    AddActivities("pursuits", L.QUEST_SECTION_PURSUITS, Quests.ICON_PURSUIT, all.pursuits)
    AddActivities("tome", L.QUEST_SECTION_TOME, Quests.ICON_TOME, all.tomes)

    if #dataList == 0 then
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY,
            { text = query ~= "" and L.EDITOR_NOTHING or L.QUEST_EMPTY })
    end
    ZO_ScrollList_Commit(list)
end

function InfoPanel:GetRowWidth()
    return self.list:GetWidth() - 16
end

-- Куда встанет задание, если отпустить его над этим элементом списка
local function RowDrop(control)
    local data = control.data
    if not data then return nil end
    if data.zone == "main" then return "main", nil, "fill" end
    if data.zone == "pinned" then return "pinned", data.item, data.item and "top" or "fill" end
    return "other", nil, "fill"
end

function InfoPanel:SetupSection(control, data)
    control.data = data
    control.mgDrop = RowDrop
    control:SetWidth(self:GetRowWidth())
    control:GetNamedChild("Text"):SetText(data.text)
    control:GetNamedChild("Count"):SetText(data.count or "")
    control:GetNamedChild("Line"):SetColor(1, 1, 1, control.isHover and 0.3 or 0.12)
    local icon = control:GetNamedChild("Icon")
    icon:SetHidden(data.icon == nil)
    if data.icon then icon:SetTexture(data.icon) end
    control:GetNamedChild("Arrow"):SetTexture(data.collapsed and "EsoUI/Art/Buttons/tree_closed_up.dds" or "EsoUI/Art/Buttons/tree_open_up.dds")
end

function InfoPanel:SetupGroup(control, data)
    control.data = data
    control.mgDrop = RowDrop
    control:SetWidth(self:GetRowWidth())
    local label = control:GetNamedChild("Text")
    local arrow = control:GetNamedChild("Arrow")
    label:SetText(data.text)
    arrow:SetHidden(data.doneToggle == nil)
    if data.doneToggle then
        arrow:SetTexture(data.open and "EsoUI/Art/Buttons/tree_open_up.dds" or "EsoUI/Art/Buttons/tree_closed_up.dds")
        label:SetColor(MUTED[1], MUTED[2], MUTED[3], 1)
    elseif data.hint then
        label:SetColor(MUTED[1], MUTED[2], MUTED[3], 1)
    else
        label:SetColor(GROUP[1], GROUP[2], GROUP[3], 1)
    end
    label:ClearAnchors()
    local x = data.doneToggle and 26 or 8
    label:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, x, -3)
    label:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -6, -3)
end

function InfoPanel:OnGroupClicked(control, button)
    local data = control.data
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not data or not data.doneToggle then return end
    self:ToggleDone(data.doneToggle)
end

function InfoPanel:OnSectionEnter(control)
    control.isHover = true
    control:GetNamedChild("Line"):SetColor(1, 1, 1, 0.3)
    QTM.ShowTip("infoPanel", control, LEFT, control.data and control.data.collapsed and L.QUEST_EXPAND or L.QUEST_COLLAPSE)
end

function InfoPanel:OnSectionExit(control)
    control.isHover = false
    control:GetNamedChild("Line"):SetColor(1, 1, 1, 0.12)
    ZO_Tooltips_HideTextTooltip()
end

function InfoPanel:OnSectionClicked(control, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not control.data then return end
    ZO_Tooltips_HideTextTooltip()
    self:ToggleSection(control.data.id)
end

-- Кнопка-значок в строке: активная — яркая, неактивная — едва заметная
local function PaintIconButton(button, active, color, hover)
    local icon = button:GetNamedChild("Icon")
    if active then
        icon:SetColor(color[1], color[2], color[3], 1)
    elseif hover then
        icon:SetColor(1, 1, 1, 0.9)
    else
        icon:SetColor(1, 1, 1, 0.3)
    end
end
InfoPanel.PaintIconButton = PaintIconButton

function InfoPanel:PaintRow(control)
    local data = control.data
    if not data then return end
    local item = data.item
    local color = KIND_COLORS[item.kind] or KIND_COLORS.q
    if item.complete then color = { r = 0.45, g = 0.45, b = 0.47 } end
    local strength = control.isHover and 0.22 or (item.isMain and 0.18 or ((data.index or 1) % 2 == 0 and 0.12 or 0.08))
    local r, g, b = Style.Darken(color, strength)
    control:GetNamedChild("Bg"):SetColor(r, g, b, Style.RowAlpha(control.isHover))
    control:GetNamedChild("Stripe"):SetColor(color.r, color.g, color.b, (control.isHover or item.isMain) and 1 or 0.6)
end

function InfoPanel:SetupRow(control, data)
    control.data = data
    control.mgDrop = RowDrop
    control:SetWidth(self:GetRowWidth())
    local item = data.item
    self:PaintRow(control)

    local icon = control:GetNamedChild("Icon")
    icon:SetTexture(item.icon or QTM.Quests.ICON_QUEST)
    icon:SetAlpha(item.complete and 0.5 or 1)

    local name = control:GetNamedChild("Name")
    name:SetText(QTM.Quests.FormatName(item, 18))
    if item.complete then
        name:SetColor(MUTED[1], MUTED[2], MUTED[3], 1)
    elseif item.isMain then
        name:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
    else
        name:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
    end

    local info = control:GetNamedChild("Info")
    info:SetText(item.info or "")
    if item.claimable then
        info:SetColor(0.45, 0.85, 0.45, 1)
    else
        info:SetColor(INFO[1], INFO[2], INFO[3], 1)
    end

    -- Полоса прогресса у стремлений и фолианта
    local barBg, barFill = control:GetNamedChild("BarBg"), control:GetNamedChild("BarFill")
    local hasBar = item.maxProgress ~= nil and item.maxProgress > 0
    barBg:SetHidden(not hasBar)
    barFill:SetHidden(not hasBar)
    if hasBar then
        local color = KIND_COLORS[item.kind] or KIND_COLORS.q
        barBg:SetColor(1, 1, 1, 0.1)
        barFill:SetColor(color.r, color.g, color.b, item.complete and 0.5 or 0.9)
        local width = zo_max(1, self:GetRowWidth() - 48 - 88)
        barFill:SetWidth(zo_max(1, zo_floor(width * zo_min(1, item.progress / item.maxProgress))))
    end

    -- Кнопки: перемещение (задания с известным местом), закрепить, главное
    local travel = control:GetNamedChild("Travel")
    travel:GetNamedChild("Icon"):SetTexture(ICON_TRAVEL)
    travel:SetHidden(not item.canTravel)
    PaintIconButton(travel, true, ICE)

    local pin = control:GetNamedChild("Pin")
    pin:GetNamedChild("Icon"):SetTexture(ICON_PIN)
    PaintIconButton(pin, item.isPinned, GOLD)

    local mainButton = control:GetNamedChild("Main")
    mainButton:GetNamedChild("Icon"):SetTexture(ICON_MAIN)
    mainButton:SetHidden(item.complete and item.kind ~= QTM.Quests.KIND_QUEST)
    PaintIconButton(mainButton, item.isMain, GOLD)
end

-- Подсказка к пункту: условия, описание и что делают щелчки
function InfoPanel.BuildItemTooltip(item)
    local parts = { item.name }
    if item.kind == QTM.Quests.KIND_QUEST then
        if item.zone then parts[#parts + 1] = "|c" .. QTM.Style.Hex(QTM.Style.GROUP) .. "" .. item.zone .. "|r" end
        local lines = item.lines or {}
        if #lines == 0 and item.stepText and item.stepText ~= "" then lines = { item.stepText } end
        for _, line in ipairs(lines) do parts[#parts + 1] = "• " .. line end
        if item.canTravel then
            parts[#parts + 1] = "|c" .. QTM.Style.Hex(QTM.Style.ICE) .. "" .. L.QUEST_CAN_TRAVEL .. "|r"
        else
            parts[#parts + 1] = "|c8A8A8A" .. L.QUEST_NO_TRAVEL .. "|r"
        end
    else
        parts[#parts + 1] = item.info
        if item.description and item.description ~= "" then
            parts[#parts + 1] = "|cA0A0A0" .. item.description .. "|r"
        end
    end
    return table.concat(parts, "\n")
end

function InfoPanel:OnRowEnter(control)
    control.isHover = true
    self:PaintRow(control)
    if control.data then
        local text = InfoPanel.BuildItemTooltip(control.data.item)
        local hint = control.data.item.kind == QTM.Quests.KIND_QUEST and L.QUEST_ROW_HINT or L.QUEST_ROW_HINT_ACTIVITY
        QTM.ShowTip("infoPanel", control, LEFT, text .. "\n\n|c8A8A8A" .. hint .. "|r")
    end
end

function InfoPanel:OnRowExit(control)
    control.isHover = false
    self:PaintRow(control)
    ZO_Tooltips_HideTextTooltip()
end

function InfoPanel:OnRowDragStart(control, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not control.data then return end
    QTM.QuestDrag:Begin(control.data.item)
end

function InfoPanel:OnRowMouseUp(control, button, upInside)
    if QTM.QuestDrag:IsDragging() then
        QTM.QuestDrag:Finish()
        return
    end
    if upInside then self:OnRowClicked(control, button) end
end

function InfoPanel:OnRowClicked(control, button)
    local data = control.data
    if not data then return end
    local item = data.item
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        self:ShowContextMenu(control, item)
    elseif button == MOUSE_BUTTON_INDEX_LEFT and item.kind == QTM.Quests.KIND_QUEST then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ZO_WorldMap_ShowQuestOnMap(item.questIndex)
    end
end

-- Общее контекстное меню пункта (панель карты и панель на экране)
function InfoPanel.ShowItemMenu(control, item)
    local Quests = QTM.Quests
    ClearMenu()
    if item.kind == Quests.KIND_QUEST and item.canTravel then
        AddMenuItem(L.QUEST_CTX_TRAVEL, function() QTM.QuestTravel:Start(item.questIndex, false) end)
        AddMenuItem(L.QUEST_CTX_TRAVEL_PAY, function() QTM.QuestTravel:Start(item.questIndex, true) end)
    end
    if item.kind == Quests.KIND_QUEST then
        AddMenuItem(L.QUEST_CTX_SHOW, function() ZO_WorldMap_ShowQuestOnMap(item.questIndex) end)
    end
    if not item.isMain and not (item.complete and item.kind ~= Quests.KIND_QUEST) then
        AddMenuItem(L.QUEST_CTX_MAIN, function() Quests:SetMain(item) end)
    elseif item.isMain and item.kind ~= Quests.KIND_QUEST then
        AddMenuItem(L.QUEST_CTX_UNMAIN, function() Quests:ClearMain() end)
    end
    AddMenuItem(item.isPinned and L.QUEST_CTX_UNPIN or L.QUEST_CTX_PIN, function() Quests:TogglePin(item.key) end)
    ShowMenu(control)
end

function InfoPanel:ShowContextMenu(control, item)
    ZO_Tooltips_HideTextTooltip()
    InfoPanel.ShowItemMenu(control, item)
end

function InfoPanel:OnButtonEnter(button, kind)
    local row = button:GetParent()
    local item = row.data and row.data.item
    if not item then return end
    local text
    if kind == "travel" then
        text = QTM.QuestTracker.GetTravelTooltip()
    elseif kind == "pin" then
        text = item.isPinned and L.QUEST_UNPIN_TT or L.QUEST_PIN_TT
        PaintIconButton(button, item.isPinned, GOLD, true)
    else
        text = item.isMain and L.QUEST_IS_MAIN_TT or L.QUEST_MAIN_TT
        PaintIconButton(button, item.isMain, GOLD, true)
    end
    if kind == "travel" then button:GetNamedChild("Icon"):SetColor(1, 1, 1, 1) end
    QTM.ShowTip("infoPanel", button, LEFT, text)
end

function InfoPanel:OnButtonExit(button)
    ZO_Tooltips_HideTextTooltip()
    local row = button:GetParent()
    if row.data then self:SetupRow(row, row.data) end
end

function InfoPanel:OnTravelClicked(row)
    local item = row.data and row.data.item
    if not item or not item.canTravel then return end
    QTM.QuestTravel:Start(item.questIndex, QTM.QuestTravel:IsDirect())
end

function InfoPanel:OnPinClicked(row)
    local item = row.data and row.data.item
    if not item then return end
    QTM.Quests:TogglePin(item.key)
end

function InfoPanel:OnMainClicked(row)
    local item = row.data and row.data.item
    if not item then return end
    if item.isMain then
        if item.kind ~= QTM.Quests.KIND_QUEST then QTM.Quests:ClearMain() end
    else
        QTM.Quests:SetMain(item)
    end
end
