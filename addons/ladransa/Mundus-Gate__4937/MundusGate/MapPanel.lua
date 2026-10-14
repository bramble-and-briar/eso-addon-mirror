-- Панель слева от карты мира.
--
-- Две вкладки:
--   • «Завершение области» — панель самой игры (ZO_WorldMapZoneStoryTopLevel_Keyboard),
--     встроенная сюда: аддон только переставляет её на место вкладки и
--     прячет, когда открыта другая вкладка;
--   • «Mundus Gate» — ваши места. Щелчок по месту открывает его настройку:
--     значок и цвет (общие для кнопок и колеса), ячейка колеса, кнопка на экране.
-- Сверху вкладки Mundus Gate — сэкономленное на перемещениях через игроков золото.
--
-- Панель стоит вплотную к левому краю окна карты, по его высоте, и не
-- заходит на карту. Окна «Выбор места» и «Выбор значка» открываются рядом
-- с панелью, на одной с ней высоте.
local QTM   = MundusGate
local L     = QTM.L
local Data  = QTM.Data
local Style = QTM.Style

local MapPanel = {}
QTM.MapPanel = MapPanel

local TYPE_ROW       = 1
local TYPE_EMPTY     = 2
local ROW_HEIGHT     = 56
local ROW_TILE       = 38
local PREVIEW_SIZE   = 64
local SWATCH_GAP     = 4
local WHEEL_TILE     = 36
local WHEEL_RADIUS   = 64
local EDITOR_HEIGHT  = 810
local DEFAULT_BUTTON_SIZE = 56

local MAP_GAP        = 10    -- отступ между панелью и картой
local SCREEN_EDGE    = 8     -- отступ от края экрана
local MIN_WIDTH      = 330
local MAX_WIDTH      = 420
local LAYOUT_EVERY_MS = 500

local ZONE_HIDE_REASON = "MundusGateTab"

-- Приглушённые цвета панели
local GOLD   = Style.GOLD
local ICE    = Style.ICE
local MUTED  = Style.MUTED
local TEXT   = Style.TEXT
local INFO   = Style.INFO
local GROUP  = Style.GROUP

local lower = zo_strlower or string.lower

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---------------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------------
function MapPanel:Initialize()
    local root = MundusGateMapPanelRoot
    self.root  = root
    self.panel = root:GetNamedChild("Panel")
    self.view  = "list"
    local panel = self.panel

    -- Вкладки
    self.tabs = {
        zone = panel:GetNamedChild("TabZone"),
        gate = panel:GetNamedChild("TabGate"),
    }
    self.tabs.zone:GetNamedChild("Text"):SetText(L.PANEL_TAB_ZONE)
    self.tabs.gate:GetNamedChild("Text"):SetText(L.PANEL_TAB_GATE)
    self.tabIndicator = panel:GetNamedChild("TabIndicator")
    self.langButton = panel:GetNamedChild("Lang")
    self:PaintLanguageButton(false)
    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_LANGUAGE", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = L.LANG_TITLE },
        mainText    = { text = "<<1>>" },
        buttons     = {
            {
                text     = L.LANG_RELOAD,
                callback = function(dialog)
                    QTM.sv.language = dialog.data.code
                    ReloadUI("ingame")
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
    self.tabIndicator:SetColor(ICE[1], ICE[2], ICE[3], 1)
    panel:GetNamedChild("TabLine"):SetColor(1, 1, 1, 0.12)

    -- Шапка Mundus Gate
    self.gateHeader = panel:GetNamedChild("GateHeader")
    self.savedLabel = self.gateHeader:GetNamedChild("Saved")

    -- Завершение области
    self.zoneArea  = panel:GetNamedChild("Zone")
    self.zoneEmpty = self.zoneArea:GetNamedChild("Empty")
    self.zoneEmpty:SetText(L.PANEL_ZONE_EMPTY)

    -- Список мест
    self.listView = panel:GetNamedChild("ListView")
    local search = self.listView:GetNamedChild("SearchBgBox")
    search:SetMaxInputChars(60)
    if search.SetDefaultText then search:SetDefaultText(L.PANEL_SEARCH) end
    search:SetHandler("OnTextChanged", function(edit)
        self.query = lower(Trim(edit:GetText()))
        self:RefreshList()
    end)
    self.search = search
    self.query  = ""

    local list = self.listView:GetNamedChild("List")
    self.list = list
    ZO_ScrollList_AddDataType(list, TYPE_ROW, "MundusGate_PanelRow", ROW_HEIGHT,
        function(control, data) self:SetupRow(control, data) end)
    ZO_ScrollList_AddDataType(list, TYPE_EMPTY, "MundusGate_Empty", 90,
        function(control, data) QTM.Menu:SetupEmpty(control, data, list) end)

    -- Настройка места
    self.editView = panel:GetNamedChild("EditView")
    local back = self.editView:GetNamedChild("Back")
    back:GetNamedChild("Text"):SetText(L.PANEL_BACK)
    local scroll = self.editView:GetNamedChild("Scroll")
    self.scroll = scroll
    local scrollChild = scroll:GetNamedChild("ScrollChild")
    self.editor = CreateControlFromVirtual(panel:GetName() .. "Editor", scrollChild, "MundusGate_PanelEditor")
    self.editor:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, 0)
    self:InitializeEditor(self.editor)

    -- Панель живёт вместе с картой мира (клавиатурный режим)
    self.fragment = ZO_SimpleSceneFragment:New(root)
    if WORLD_MAP_SCENE then
        WORLD_MAP_SCENE:AddFragment(self.fragment)
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                self:Refresh()
            elseif newState == SCENE_HIDDEN then
                ZO_Tooltips_HideTextTooltip()
                QTM.ClosePickers()
            end
        end)
    end

    -- Окно карты можно растянуть или переключить в полный размер — следим за ним
    panel:SetHandler("OnUpdate", function()
        local now = GetFrameTimeMilliseconds()
        if not self.nextLayout or now >= self.nextLayout then
            self.nextLayout = now + LAYOUT_EVERY_MS
            self:Layout()
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        if self:IsShown() then self:RefreshZoneTab() end
    end)

    self:UpdateVisibility()
end

function MapPanel:InitializeEditor(editor)
    self.preview    = editor:GetNamedChild("Preview")
    self.detailName = editor:GetNamedChild("Name")
    self.detailInfo = editor:GetNamedChild("Info")
    self.detailPrice = editor:GetNamedChild("Price")
    self.travelButton = editor:GetNamedChild("Travel")
    self.travelButton:SetText(L.PANEL_TRAVEL)

    editor:GetNamedChild("LookCaption"):SetText(L.PANEL_LOOK)
    self.iconButton  = editor:GetNamedChild("Icon")
    self.resetButton = editor:GetNamedChild("ResetIcon")
    self.iconButton:SetText(L.PANEL_ICON)
    self.resetButton:SetText(L.PANEL_ICON_RESET)
    self.tintCheck = editor:GetNamedChild("Tint")
    ZO_CheckButton_SetLabelText(self.tintCheck, L.PANEL_TINT)
    ZO_CheckButton_SetToggleFunction(self.tintCheck, function(_, checked)
        self:ChangeLook(function(look) look.tint = checked end)
    end)
    self.palette = editor:GetNamedChild("Palette")
    self:CreatePalette(self.palette)

    editor:GetNamedChild("WheelCaption"):SetText(L.PANEL_WHEEL)
    self.wheelArea   = editor:GetNamedChild("Wheel")
    self.wheelCenter = self.wheelArea:GetNamedChild("Center")
    self.wheelStatus = editor:GetNamedChild("WheelStatus")
    editor:GetNamedChild("WheelHelp"):SetText(L.PANEL_WHEEL_HELP)
    self:CreateWheel()

    editor:GetNamedChild("ButtonCaption"):SetText(L.PANEL_BUTTON)
    self.buttonStatus = editor:GetNamedChild("ButtonStatus")
    self.buttonToggle = editor:GetNamedChild("ButtonToggle")
    self.sizeCaption  = editor:GetNamedChild("SizeCaption")
    self.sizeCaption:SetText(L.PANEL_SIZE)
    self.sizeMinus    = editor:GetNamedChild("SizeMinus")
    self.sizeValue    = editor:GetNamedChild("SizeValue")
    self.sizePlus     = editor:GetNamedChild("SizePlus")
    self.showLabel    = editor:GetNamedChild("ShowLabel")
    self.buttonHelp   = editor:GetNamedChild("ButtonHelp")
    self.buttonHelp:SetText(L.PANEL_BUTTON_HELP)
    ZO_CheckButton_SetLabelText(self.showLabel, L.PANEL_SHOW_LABEL)
    ZO_CheckButton_SetToggleFunction(self.showLabel, function(_, checked)
        self:ChangeButtons(function(item) item.showLabel = checked end)
    end)

    for _, name in ipairs({ "LookLine", "WheelLine", "ButtonLine" }) do
        editor:GetNamedChild(name):SetColor(1, 1, 1, 0.12)
    end
end

---------------------------------------------------------------------------
-- Предпросмотр рядом с настройками аддона: панель (вкладка Mundus Gate,
-- список мест) показывается в заданном месте поверх меню
---------------------------------------------------------------------------
function MapPanel:SetPreview(enabled, right, top, width, height)
    if not self.panel then return end
    local root, panel = self.root, self.panel
    if enabled then
        if not self:IsEnabled() then return end
        self.preview = { tab = QTM.sv.mapPanelTab, view = self.view, tier = root:GetDrawTier() }
        QTM.sv.mapPanelTab = "gate"
        self.view = "list"
        root:SetDrawTier(DT_HIGH)
        root:SetHidden(false)
        panel:SetHidden(false)
        panel:ClearAnchors()
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, right, top)
        panel:SetDimensions(width, height)
        self:LayoutTabs(width)
        self:LayoutEditor(width)
        self:ApplyTab()
        self:RefreshGate()
        return
    end
    local preview = self.preview
    if not preview then return end
    self.preview = nil
    QTM.sv.mapPanelTab = preview.tab
    self.view = preview.view
    root:SetDrawTier(preview.tier)
    root:SetHidden(true)   -- с картой панель снова покажет её фрагмент
    self.layoutKey = nil
    self:UpdateVisibility()
end

function MapPanel:RefreshPreview()
    if self.preview then self:ApplyTab(); self:RefreshGate() end
end

-- Сменилась цветовая тема: перекрасить то, что красится один раз
function MapPanel:OnThemeChanged()
    if not self.panel then return end
    self.tabIndicator:SetColor(ICE[1], ICE[2], ICE[3], 1)
    self:PaintLanguageButton(false)
    self:ApplyTab()
    self:RefreshIfShown()
end

---------------------------------------------------------------------------
-- Размер и положение: вплотную к левому краю окна карты, по его высоте
---------------------------------------------------------------------------
function MapPanel:Layout()
    if self.preview then return end
    local panel = self.panel
    local map = ZO_WorldMap
    if not map or not map.GetLeft then return end
    local left, top, bottom = map:GetLeft(), map:GetTop(), map:GetBottom()
    if not left or not top or not bottom or bottom <= top then return end

    local available = left - MAP_GAP - SCREEN_EDGE
    local width = zo_clamp(available, MIN_WIDTH, MAX_WIDTH)
    local key = string.format("%d:%d:%d:%d", left, top, bottom, width)
    if key == self.layoutKey then return end
    self.layoutKey = key

    panel:ClearAnchors()
    if available >= MIN_WIDTH then
        panel:SetAnchor(TOPRIGHT, map, TOPLEFT, -MAP_GAP, 0)
        panel:SetAnchor(BOTTOMRIGHT, map, BOTTOMLEFT, -MAP_GAP, 0)
    else
        -- Слева от карты нет места (карта во весь экран): ставим у края экрана
        panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SCREEN_EDGE, top)
        panel:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, SCREEN_EDGE, bottom)
    end
    panel:SetWidth(width)
    self:LayoutTabs(width)
    self:LayoutEditor(width)
    if self.list then ZO_ScrollList_RefreshVisible(self.list) end
end

-- Вкладки по ширине текста; если обе не помещаются — шрифт поменьше
-- (справа от вкладок — кнопка языка)
function MapPanel:LayoutTabs(panelWidth)
    local room = panelWidth - 32 - 52
    for _, font in ipairs({ "ZoFontWinH4", "ZoFontWinH5" }) do
        local total = 16
        for _, button in pairs(self.tabs) do
            local label = button:GetNamedChild("Text")
            label:SetFont(font)
            local width = (label:GetTextWidth() or 100) + 4
            button:SetWidth(width)
            total = total + width
        end
        if total <= room then break end
    end
end

-- Ширина содержимого настройки: панель минус поля и полоса прокрутки
function MapPanel:LayoutEditor(panelWidth)
    local width = panelWidth - 16 - 12 - (ZO_SCROLL_BAR_WIDTH or 16) - 6
    self.editorWidth = width
    self.editor:SetDimensions(width, EDITOR_HEIGHT)
    self.travelButton:SetWidth(width)
    self.buttonToggle:SetWidth(width)
    local half = zo_floor((width - 8) / 2)
    self.iconButton:SetWidth(half)
    self.resetButton:SetWidth(half)

    -- Палитра на всю ширину: размер квадратиков подбирается под ширину
    local count = #Style.PALETTE
    local size = zo_floor((width - (count - 1) * SWATCH_GAP) / count)
    self.swatchSize = zo_min(size, 26)
    for index, swatch in ipairs(self.swatches) do
        swatch:ClearAnchors()
        swatch:SetAnchor(TOPLEFT, self.palette, TOPLEFT, (index - 1) * (self.swatchSize + SWATCH_GAP), 0)
    end
    self.palette:SetWidth(width)
    self:PaintPalette()
end

---------------------------------------------------------------------------
-- Язык аддона: кнопка с кодом языка и меню выбора
---------------------------------------------------------------------------
function MapPanel:PaintLanguageButton(hover)
    local button = self.langButton
    if not button then return end
    local label = button:GetNamedChild("Text")
    label:SetText(string.upper(QTM.language or "en"))
    label:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
    self.panel:GetNamedChild("LangBg"):SetColor(GOLD[1], GOLD[2], GOLD[3], hover and 0.22 or 0.10)
end

function MapPanel:OnLanguageEnter(button)
    self:PaintLanguageButton(true)
    QTM.ShowTip("mapPanel", button, BOTTOM, zo_strformat(L.LANG_BUTTON_TT, QTM.GetLanguageName(QTM.language)))
end

function MapPanel:OnLanguageExit()
    self:PaintLanguageButton(false)
    ZO_Tooltips_HideTextTooltip()
end

function MapPanel:ShowLanguageMenu(button)
    ZO_Tooltips_HideTextTooltip()
    local selected = QTM.sv.language or "auto"
    local function Item(code, text)
        if code == selected then text = "|c" .. QTM.Style.Hex(QTM.Style.ICE) .. "» " .. text .. "|r" end
        AddMenuItem(text, function() self:ConfirmLanguage(code) end)
    end
    ClearMenu()
    Item("auto", zo_strformat(L.LANG_AUTO, QTM.GetLanguageName(QTM.ResolveLanguage("auto"))))
    for _, info in ipairs(QTM.LANGUAGES) do
        Item(info.code, info.name)
    end
    ShowMenu(button)
end

-- Сменить язык: спрашиваем и перезагружаем интерфейс (тексты нужны уже при загрузке)
function MapPanel:ConfirmLanguage(code)
    if code == (QTM.sv.language or "auto") then return end
    local resolved = QTM.ResolveLanguage(code)
    local name = code == "auto" and zo_strformat(L.LANG_AUTO, QTM.GetLanguageName(resolved)) or QTM.GetLanguageName(code)
    local text = zo_strformat(L.LANG_RELOAD_TEXT, name)
    if QTM.CJK_LANGUAGES[resolved] and QTM.GetClientLanguage() ~= resolved then
        text = text .. "\n\n" .. L.LANG_FONT_WARNING
    end
    ZO_Dialogs_ShowDialog("MUNDUSGATE_LANGUAGE", { code = code }, { mainTextParams = { text } })
end

---------------------------------------------------------------------------
-- Видимость и вкладки
---------------------------------------------------------------------------
function MapPanel:IsEnabled()
    return QTM.sv.mapPanel ~= false
end

function MapPanel:UpdateVisibility()
    if not self.panel then return end
    local enabled = self:IsEnabled()
    self.panel:SetHidden(not enabled)
    if enabled then
        self:AdoptZoneStory()
    else
        self:ReleaseZoneStory()
    end
    self:ApplyTab()
end

function MapPanel:IsShown()
    return self.panel ~= nil and WORLD_MAP_SCENE ~= nil and WORLD_MAP_SCENE:IsShowing()
        and not self.panel:IsHidden()
end

function MapPanel:RefreshIfShown()
    if self:IsShown() then self:Refresh() end
end

function MapPanel:GetTab()
    return QTM.sv.mapPanelTab == "zone" and "zone" or "gate"
end

function MapPanel:SelectTab(tab)
    if tab ~= self:GetTab() then PlaySound(SOUNDS.DEFAULT_CLICK) end
    QTM.sv.mapPanelTab = tab
    QTM.ClosePickers()
    ZO_Tooltips_HideTextTooltip()
    self:ApplyTab()
    if tab == "gate" then self:RefreshGate() else self:RefreshZoneTab() end
end

function MapPanel:ApplyTab()
    local tab = self:GetTab()
    local isGate = tab == "gate"

    for name, button in pairs(self.tabs) do
        local r, g, b = unpack(name == tab and GOLD or MUTED)
        button:GetNamedChild("Text"):SetColor(r, g, b, 1)
    end
    local active = self.tabs[tab]:GetNamedChild("Text")
    self.tabIndicator:ClearAnchors()
    self.tabIndicator:SetAnchor(TOPLEFT, active, BOTTOMLEFT, 0, 4)
    self.tabIndicator:SetAnchor(TOPRIGHT, active, BOTTOMRIGHT, 0, 4)

    self.gateHeader:SetHidden(not isGate)
    self.listView:SetHidden(not isGate or self.view ~= "list")
    self.editView:SetHidden(not isGate or self.view ~= "edit")
    self.zoneArea:SetHidden(isGate)

    local zoneStory = self:GetZoneStory()
    if zoneStory and self.adopted then
        zoneStory:GetFragment():SetHiddenForReason(ZONE_HIDE_REASON, isGate)
    end
end

---------------------------------------------------------------------------
-- «Завершение области»: панель игры встраивается во вкладку
---------------------------------------------------------------------------
function MapPanel:GetZoneStory()
    local zoneStory = WORLD_MAP_ZONE_STORY_KEYBOARD
    local control = ZO_WorldMapZoneStoryTopLevel_Keyboard
    if zoneStory and control and zoneStory.GetFragment then
        return zoneStory, control
    end
    return nil
end

function MapPanel:AdoptZoneStory()
    local zoneStory, control = self:GetZoneStory()
    if not zoneStory or self.adopted then return end
    self.adopted = true

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, self.zoneArea, TOPLEFT, 0, -14)
    control:SetAnchor(BOTTOMRIGHT, self.zoneArea, BOTTOMRIGHT, 0, 0)
    -- Над фоном нашей панели
    self.zoneTier = control:GetDrawTier()
    control:SetDrawTier(DT_MEDIUM)
    -- Заголовок у вкладки уже есть — свой заголовок игры прячем
    local title = control:GetNamedChild("Title")
    if title then title:SetHidden(true) end
    -- Свой фон игры (тёмная полоса у левого края) не нужен: фон даёт панель
    zoneStory.GetBackgroundFragment = function() return nil end
end

function MapPanel:ReleaseZoneStory()
    local zoneStory, control = self:GetZoneStory()
    if not zoneStory or not self.adopted then return end
    self.adopted = false

    control:ClearAnchors()
    if ZO_SharedMediumLeftPanelBackground then
        control:SetAnchor(TOPLEFT, ZO_SharedMediumLeftPanelBackground, TOPLEFT, 20, 0)
        control:SetAnchor(BOTTOMRIGHT, ZO_SharedMediumLeftPanelBackground, BOTTOMRIGHT, -40, 0)
    end
    if self.zoneTier then control:SetDrawTier(self.zoneTier) end
    local title = control:GetNamedChild("Title")
    if title then title:SetHidden(false) end
    zoneStory.GetBackgroundFragment = nil   -- снова функция игры
    zoneStory:GetFragment():SetHiddenForReason(ZONE_HIDE_REASON, false)
end

function MapPanel:RefreshZoneTab()
    local zoneStory = self:GetZoneStory()
    local hasData = zoneStory ~= nil and zoneStory:HasZoneStoryData()
    self.zoneEmpty:SetHidden(hasData or self:GetTab() ~= "zone")
end

---------------------------------------------------------------------------
-- Mundus Gate
---------------------------------------------------------------------------
function MapPanel:Refresh()
    self:UpdateVisibility()
    self.layoutKey = nil
    self:Layout()
    self:RefreshZoneTab()
    self:RefreshGate()
end

function MapPanel:RefreshGate()
    self:UpdateCounter()
    if self.view == "edit" and not self:GetSelectedNode() then
        self.view = "list"
        self:ApplyTab()
    end
    if self.view == "list" then
        self:RefreshList()
    else
        self:RefreshDetails()
    end
end

-- «Сэкономлено: 12 345 · перемещений: 7»
function MapPanel:UpdateCounter()
    if not self.savedLabel then return end
    local sv = QTM.sv
    local gold = ZO_Currency_FormatKeyboard(CURT_MONEY, sv.goldSaved or 0, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    self.savedLabel:SetText(zo_strformat(L.PANEL_SAVED, gold))
end

function MapPanel:OnSavedEnter(control)
    QTM.ShowTip("mapPanel", control, BOTTOM, zo_strformat(L.PANEL_SAVED_TT, QTM.sv.freeTrips or 0))
end

function MapPanel:ShowList()
    PlaySound(SOUNDS.DEFAULT_CLICK)
    QTM.ClosePickers()
    ZO_Tooltips_HideTextTooltip()
    self.view = "list"
    self:ApplyTab()
    self:RefreshList()
end

function MapPanel:OpenEditor(key)
    self.selected = key
    self.view = "edit"
    QTM.ClosePickers()
    self:ApplyTab()
    if self.scroll and ZO_Scroll_ResetToTop then ZO_Scroll_ResetToTop(self.scroll) end
    self:RefreshDetails()
end

-- Где место уже используется: ячейки колеса и кнопки
function MapPanel:GetUsage(key)
    local slots, buttons = {}, {}
    for index = 1, QTM.Wheel.MAX_SLOTS do
        local slot = QTM.sv.wheelSlots[index]
        if slot and slot.nodeIndex == key then slots[#slots + 1] = index end
    end
    for _, item in ipairs(QTM.sv.buttons) do
        if item.nodeIndex == key then buttons[#buttons + 1] = item end
    end
    return slots, buttons
end

function MapPanel:RefreshList()
    ZO_ScrollList_Clear(self.list)
    local dataList = ZO_ScrollList_GetDataList(self.list)
    local favorites = Data:GetFavoriteNodes(false)

    for _, node in ipairs(favorites) do
        if self.query == "" or node.searchKey:find(self.query, 1, true) then
            local available = Data:GetNodeStatus(node)
            dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ROW, {
                node = node, available = available, index = #dataList + 1,
            })
        end
    end
    if #dataList == 0 then
        dataList[1] = ZO_ScrollList_CreateDataEntry(TYPE_EMPTY,
            { text = #favorites == 0 and L.PANEL_NO_PLACES or L.EDITOR_NOTHING })
    end
    ZO_ScrollList_Commit(self.list)
end

local function PaintPlaceTile(tile, node, size, state)
    local look = Data:GetPlaceLook(node.nodeIndex)
    state = state or {}
    state.size = size
    Style.PaintTile(tile, {
        icon  = Style.ResolveIcon(look, node),
        color = look.color,
        tint  = look.tint,
    }, state)
end

-- Метка справа в строке: «колесо 3» или «кнопка»
local function SetPill(pill, text, color)
    if not text then
        pill:SetHidden(true)
        return 0
    end
    pill:SetHidden(false)
    local label = pill:GetNamedChild("Text")
    label:SetText(text)
    label:SetColor(color[1], color[2], color[3], 1)
    pill:GetNamedChild("Bg"):SetColor(color[1], color[2], color[3], 0.14)
    local width = zo_max(48, (label:GetTextWidth() or 40) + 14)
    pill:SetWidth(width)
    return width
end

function MapPanel:PaintRow(control)
    local data = control.data
    if not data then return end
    local look = Data:GetPlaceLook(data.node.nodeIndex)
    local color = data.available and look.color or { r = 0.45, g = 0.45, b = 0.47 }
    -- Фон строки чуть окрашен в цвет места, чётные строки немного светлее
    local strength = control.isHover and 0.22 or ((data.index or 1) % 2 == 0 and 0.12 or 0.08)
    local r, g, b = Style.Darken(color, strength)
    control:GetNamedChild("Bg"):SetColor(r, g, b, Style.RowAlpha(control.isHover))
    control:GetNamedChild("Stripe"):SetColor(color.r, color.g, color.b, control.isHover and 1 or 0.7)
end

function MapPanel:SetupRow(control, data)
    control.data = data
    control:SetWidth(self.list:GetWidth() - 16)
    local node = data.node

    PaintPlaceTile(control:GetNamedChild("Tile"), node, ROW_TILE, { available = data.available })
    self:PaintRow(control)

    local name = control:GetNamedChild("Name")
    name:SetText(node.name)
    if data.available then
        name:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
    else
        name:SetColor(MUTED[1], MUTED[2], MUTED[3], 1)
    end
    local info = control:GetNamedChild("Info")
    info:SetText(node.zoneName .. "  ·  " .. Data.TYPE_NAMES[node.type])
    info:SetColor(INFO[1], INFO[2], INFO[3], 1)

    -- Метки и ширина текста: текст никогда не заходит под метки
    local slots, buttons = self:GetUsage(node.nodeIndex)
    local width1 = SetPill(control:GetNamedChild("Pill1"),
        #slots > 0 and zo_strformat(L.PANEL_BADGE_WHEEL, table.concat(slots, ",")) or nil, ICE)
    local width2 = SetPill(control:GetNamedChild("Pill2"),
        #buttons > 0 and L.PANEL_BADGE_BUTTON or nil, GOLD)
    local reserve = zo_max(width1, width2)
    reserve = reserve > 0 and (reserve + 18) or 10
    for _, label in ipairs({ name, info }) do
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, control, TOPLEFT, 64, label == name and 7 or 31)
        label:SetAnchor(TOPRIGHT, control, TOPRIGHT, -reserve, label == name and 7 or 31)
    end
end

function MapPanel:OnRowEnter(control)
    control.isHover = true
    self:PaintRow(control)
end

function MapPanel:OnRowExit(control)
    control.isHover = false
    self:PaintRow(control)
end

function MapPanel:OnRowClicked(control, button)
    local data = control.data
    if not data then return end
    local node = data.node
    if button == MOUSE_BUTTON_INDEX_LEFT then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:OpenEditor(node.nodeIndex)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()
        if data.available then
            AddMenuItem(L.CTX_TRAVEL, function() self.selected = node.nodeIndex; self:Travel() end)
        end
        AddMenuItem(L.PANEL_EDIT, function() self:OpenEditor(node.nodeIndex) end)
        AddMenuItem(L.CTX_RENAME, function() Data:ShowRenameDialog(node) end)
        AddMenuItem(L.CTX_REMOVE, function() self:RemovePlace(node.nodeIndex) end)
        ShowMenu(control)
    end
end

function MapPanel:GetSelectedNode()
    return self.selected ~= nil and Data:GetNode(self.selected) or nil
end

-- «+»: выбрать любое место (окно открывается рядом с панелью) и добавить его
function MapPanel:AddPlace()
    QTM.IconPicker:Close()
    QTM.PlacePicker:Open(function(nodeIndex)
        local node = Data:GetNode(nodeIndex)
        if not node then return end
        Data:SetFavorite(nodeIndex, true)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.MAP_ADDED, node.name))
        self.search:SetText("")
        self:OpenEditor(nodeIndex)
        QTM.Menu:RefreshIfShown()
        QTM.Settings:RefreshEditor()
    end, self.panel)
end

function MapPanel:RemovePlace(key)
    Data:SetFavorite(key, false)
    if self.selected == key then
        self.selected = nil
        self.view = "list"
        self:ApplyTab()
    end
    self:RefreshGate()
    QTM.Menu:RefreshIfShown()
    QTM.Settings:RefreshEditor()
end

function MapPanel:Rename()
    local node = self:GetSelectedNode()
    if node then Data:ShowRenameDialog(node) end
end

-- Переместиться прямо с панели (галочка «через игрока» — как для карты мира)
function MapPanel:Travel()
    local node = self:GetSelectedNode()
    if not node then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    if Data:Travel(node, false, "Map") == "started" then
        SCENE_MANAGER:ShowBaseScene()
    end
end

---------------------------------------------------------------------------
-- Настройка выбранного места
---------------------------------------------------------------------------
function MapPanel:RefreshDetails()
    local node = self:GetSelectedNode()
    if not node then return end

    local available, reason = Data:GetNodeStatus(node)
    PaintPlaceTile(self.preview, node, PREVIEW_SIZE, { available = available })
    self.detailName:SetText(node.name)
    self.detailInfo:SetText(node.zoneName .. "  ·  " .. Data.TYPE_NAMES[node.type])
    if not available then
        self.detailPrice:SetText("|cFF6060" .. (reason or "") .. "|r")
    else
        local price, _, _, isRoute = Data:GetDisplayPrice(node, "Map")
        if isRoute then
            price = "|c" .. QTM.Style.Hex(QTM.Style.ICE) .. "" .. price .. "|r |c8A8A8A(" .. L.ROUTE_SHORT .. ")|r"
        end
        self.detailPrice:SetText(L.PRICE_LABEL .. " " .. price)
    end
    self.travelButton:SetEnabled(available == true)

    ZO_CheckButton_SetCheckState(self.tintCheck, Data:GetPlaceLook(node.nodeIndex).tint == true)
    self:PaintPalette()
    self:PaintWheel()
    self:RefreshButtonSection()
end

-- Изменить вид места: сохраняется для места и переносится на кнопки и колесо
function MapPanel:ChangeLook(mutator)
    local key = self.selected
    if key == nil then return end
    local look = Data:GetPlaceLook(key)
    look.color = Style.CopyColor(look.color)
    mutator(look)
    Data:SetPlaceStyle(key, look)
    self:RefreshDetails()
    if QTM.WheelEditor.RefreshIfShown then QTM.WheelEditor:RefreshIfShown() end
end

function MapPanel:PickIcon()
    local key = self.selected
    if key == nil then return end
    local look = Data:GetPlaceLook(key)
    QTM.PlacePicker:Close()
    QTM.IconPicker:Open({ color = look.color, tint = look.tint }, function(path)
        self:ChangeLook(function(target) target.icon = path end)
    end, self.panel)
end

function MapPanel:ResetIcon()
    self:ChangeLook(function(look) look.icon = nil end)
end

function MapPanel:CreatePalette(container)
    self.swatches = {}
    self.swatchSize = 22
    for index, color in ipairs(Style.PALETTE) do
        local swatch = CreateControlFromVirtual(container:GetName() .. "Swatch" .. index, container, "MundusGate_Tile")
        swatch:SetAnchor(TOPLEFT, container, TOPLEFT, (index - 1) * (self.swatchSize + SWATCH_GAP), 0)
        swatch:SetMouseEnabled(true)
        swatch.color = color
        swatch:SetHandler("OnMouseEnter", function(c) c.isHover = true; self:PaintPalette() end)
        swatch:SetHandler("OnMouseExit", function(c) c.isHover = false; self:PaintPalette() end)
        swatch:SetHandler("OnMouseUp", function(c, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                self:ChangeLook(function(look) look.color = Style.CopyColor(c.color) end)
            end
        end)
        self.swatches[index] = swatch
    end
end

function MapPanel:PaintPalette()
    local look = self.selected ~= nil and Data:GetPlaceLook(self.selected)
    for _, swatch in ipairs(self.swatches) do
        Style.PaintTile(swatch, { color = swatch.color }, {
            size = self.swatchSize, hover = swatch.isHover,
            selected = look and Style.SameColor(look.color, swatch.color),
        })
    end
end

---------------------------------------------------------------------------
-- Маленькое колесо: ячейки расположены так же, как в игре и в окне колеса
---------------------------------------------------------------------------
function MapPanel:CreateWheel()
    self.wheelTiles = {}
    local arc = 2 * math.pi / QTM.Wheel.MAX_SLOTS
    for index = 1, QTM.Wheel.MAX_SLOTS do
        local angle = index * arc
        local tile = CreateControlFromVirtual(self.wheelArea:GetName() .. "Slot" .. index, self.wheelArea, "MundusGate_Tile")
        tile:SetAnchor(CENTER, self.wheelArea, CENTER, math.sin(angle) * WHEEL_RADIUS, math.cos(angle) * WHEEL_RADIUS)
        tile:SetMouseEnabled(true)
        tile.slotIndex = index
        tile:SetHandler("OnMouseEnter", function(c) self:OnWheelEnter(c) end)
        tile:SetHandler("OnMouseExit", function(c) self:OnWheelExit(c) end)
        tile:SetHandler("OnMouseUp", function(c, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then self:OnWheelClicked(c.slotIndex) end
        end)
        self.wheelTiles[index] = tile
    end
end

function MapPanel:PaintWheel()
    for index, tile in ipairs(self.wheelTiles) do
        local slot = QTM.Wheel:GetSlot(index)
        local node = slot and Data:GetNode(slot.nodeIndex)
        local mine = slot and slot.nodeIndex == self.selected
        if node then
            Style.PaintTile(tile, {
                icon = Style.ResolveIcon(slot, node), color = slot.color, tint = slot.tint,
            }, { size = WHEEL_TILE, available = Data:GetNodeStatus(node), hover = tile.isHover, selected = mine })
        else
            Style.PaintTile(tile, {
                icon = ZO_UTILITY_SLOT_EMPTY_TEXTURE, color = Style.PALETTE[11], iconScale = 0.9,
            }, { size = WHEEL_TILE, hover = tile.isHover })
        end
        -- Чужие места приглушены, чтобы своё было видно сразу
        if node and not mine then tile:SetAlpha(tile.isHover and 1 or 0.5) end
    end
    local slots = self.selected ~= nil and self:GetUsage(self.selected) or {}
    if #slots > 0 then
        self.wheelStatus:SetText(zo_strformat(L.PANEL_WHEEL_IN, table.concat(slots, ", ")))
        self.wheelCenter:SetText(table.concat(slots, ", "))
    else
        self.wheelStatus:SetText(L.PANEL_WHEEL_NONE)
        self.wheelCenter:SetText("")
    end
end

function MapPanel:OnWheelEnter(tile)
    tile.isHover = true
    self:PaintWheel()
    local node = self:GetSelectedNode()
    if not node then return end
    local slot = QTM.Wheel:GetSlot(tile.slotIndex)
    local slotNode = slot and Data:GetNode(slot.nodeIndex)
    local text
    if slot and slot.nodeIndex == self.selected then
        text = zo_strformat(L.PANEL_WHEEL_TT_MINE, tile.slotIndex, node.name)
    elseif slotNode then
        text = zo_strformat(L.PANEL_WHEEL_TT_OTHER, tile.slotIndex, slotNode.name, node.name)
    else
        text = zo_strformat(L.PANEL_WHEEL_TT_EMPTY, tile.slotIndex, node.name)
    end
    QTM.ShowTip("mapPanel", tile, TOP, text)
end

function MapPanel:OnWheelExit(tile)
    tile.isHover = false
    self:PaintWheel()
    ZO_Tooltips_HideTextTooltip()
end

function MapPanel:OnWheelClicked(index)
    local key = self.selected
    if key == nil then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    local slot = QTM.Wheel:GetSlot(index)
    if slot and slot.nodeIndex == key then
        QTM.Wheel:ClearSlot(index)
    else
        QTM.Wheel:SetSlot(index, key)
    end
    ZO_Tooltips_HideTextTooltip()
    self:RefreshDetails()
    if QTM.WheelEditor.RefreshIfShown then QTM.WheelEditor:RefreshIfShown() end
end

---------------------------------------------------------------------------
-- Кнопка на экране (все кнопки этого места настраиваются вместе)
---------------------------------------------------------------------------
function MapPanel:RefreshButtonSection()
    local _, buttons = self:GetUsage(self.selected)
    local has = #buttons > 0
    if has then
        self.buttonStatus:SetText(#buttons == 1 and L.PANEL_BUTTON_ON or zo_strformat(L.PANEL_BUTTON_HAS, #buttons))
        self.buttonStatus:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
        self.buttonToggle:SetText(L.PANEL_BUTTON_REMOVE)
        self.sizeValue:SetText(tostring(buttons[1].size or DEFAULT_BUTTON_SIZE))
        ZO_CheckButton_SetCheckState(self.showLabel, buttons[1].showLabel == true)
    else
        self.buttonStatus:SetText(L.PANEL_BUTTON_NONE)
        self.buttonStatus:SetColor(MUTED[1], MUTED[2], MUTED[3], 1)
        self.buttonToggle:SetText(L.PANEL_BUTTON_ADD)
    end
    for _, control in ipairs({ self.sizeCaption, self.sizeMinus, self.sizeValue, self.sizePlus, self.showLabel }) do
        control:SetHidden(not has)
    end
    -- Подсказка сразу под кнопкой «Вынести», если настроек размера нет
    self.buttonHelp:ClearAnchors()
    local y = has and 758 or 684
    self.buttonHelp:SetAnchor(TOPLEFT, self.editor, TOPLEFT, 0, y)
    self.buttonHelp:SetAnchor(TOPRIGHT, self.editor, TOPRIGHT, 0, y)
end

function MapPanel:ToggleButton()
    local key = self.selected
    if key == nil then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    local _, buttons = self:GetUsage(key)
    if #buttons > 0 then
        for _, item in ipairs(buttons) do QTM.Buttons:Remove(item.id) end
    else
        QTM.Buttons:Add(key)
        QTM.Buttons:UpdateVisibility()
        local node = Data:GetNode(key)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, zo_strformat(L.ALERT_BUTTON_ADDED, node and node.name or ""))
    end
    self:RefreshDetails()
    if QTM.ButtonsEditor and QTM.ButtonsEditor.editor then QTM.ButtonsEditor.editor:RefreshIfShown() end
end

function MapPanel:ChangeButtons(mutator)
    local _, buttons = self:GetUsage(self.selected)
    for _, item in ipairs(buttons) do
        mutator(item)
        QTM.Buttons:Refresh(item)
    end
    self:RefreshButtonSection()
end

function MapPanel:ChangeButtonSize(delta)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:ChangeButtons(function(item)
        item.size = QTM.Buttons:ClampSize((item.size or DEFAULT_BUTTON_SIZE) + delta)
    end)
end
