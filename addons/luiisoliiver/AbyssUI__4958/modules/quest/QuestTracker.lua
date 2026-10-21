-- Панель заданий на экране: главное задание и закреплённые.
--
-- Два вида (настройка «Вид панели заданий»):
--   • подробная — карточки: главное сверху, крупнее и со всеми условиями,
--     закреплённые ниже, по одному условию;
--   • простая — без карточек, как панель заданий игры: разделы по локациям
--     (сворачиваются щелчком), под заданием — его условия.
-- У заданий с известным местом — кнопка перемещения к ближайшему святилищу
-- (с бесплатным путём через игрока, если он включён).
-- Щёлкать можно в режиме курсора; ПКМ — то же меню, что на панели карты.
-- Панель можно перетащить мышью и растянуть по ширине за край (если не
-- закреплена — замок в углу панели); задания внутри перетаскиваются мышью.
-- Фон и непрозрачность настраиваются в «Оформлении».
-- По желанию стандартная панель заданий игры прячется, чтобы не дублировать.
local QTM = AbyssQuest
local L   = QTM.L

local QuestTracker = {}
QTM.QuestTracker = QuestTracker

local HIDE_REASON   = "AbyssQuest"
local DEFAULT_WIDTH = 310
local MIN_WIDTH     = 220
local MAX_WIDTH     = 640
local RESIZE_HANDLE = 8
local ENTRY_GAP     = 4
local MAX_MAIN_LINES = 4
local SIMPLE_LINES   = 2     -- условий у остальных заданий в простой панели
local SIMPLE_GAP     = 3
local SIMPLE_TOP     = 6     -- отступ сверху у простой панели (шапки нет)
local ICON_LOCKED    = "EsoUI/Art/Miscellaneous/locked_up.dds"
local ICON_UNLOCKED  = "EsoUI/Art/Miscellaneous/unlocked_up.dds"
local GOLD   = QTM.Style.GOLD
local ICE    = QTM.Style.ICE
local TEXT   = QTM.Style.TEXT
local DETAIL = QTM.Style.DETAIL
local INFO   = QTM.Style.INFO

function QuestTracker:IsEnabled()
    return QTM.sv.questTracker ~= false
end

function QuestTracker:IsSimple()
    return QTM.sv.trackerStyle == "simple"
end

function QuestTracker:Initialize()
    local control = AbyssQuestQuestTracker
    self.control = control
    self.entriesArea = control:GetNamedChild("Entries")
    control:GetNamedChild("Title"):SetText(L.TRACKER_TITLE)
    self.hint = control:GetNamedChild("Hint")
    self.lock = control:GetNamedChild("Lock")
    self.bg   = control:GetNamedChild("Bg")
    self.entries = {}

    self.pool       = ZO_ControlPool:New("AbyssQuest_TrackerEntry", self.entriesArea, "Entry")
    self.simplePool = ZO_ControlPool:New("AbyssQuest_TrackerSimpleEntry", self.entriesArea, "Simple")
    self.headerPool = ZO_ControlPool:New("AbyssQuest_TrackerSimpleHeader", self.entriesArea, "Header")
    -- Перетащить задание на пустое место панели — в конец закреплённых
    control.mgDrop = function() return "pinned", nil, "bottom" end

    self:RestorePosition()
    self.fragment = ZO_HUDFadeSceneFragment:New(control)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)

    self:ApplySettings()
end

---------------------------------------------------------------------------
-- Положение
---------------------------------------------------------------------------
function QuestTracker:RestorePosition()
    local pos = QTM.sv.trackerPos
    if type(pos) == "table" and pos.x and pos.y then
        self.control:ClearAnchors()
        self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function QuestTracker:SavePosition()
    if self.preview then return end
    QTM.sv.trackerPos = { x = self.control:GetLeft(), y = self.control:GetTop() }
end

function QuestTracker:GetWidth()
    if self.preview then return self.preview.width end
    return zo_clamp(tonumber(QTM.sv.trackerWidth) or DEFAULT_WIDTH, MIN_WIDTH, MAX_WIDTH)
end

-- Привязать панель за левый верхний угол к сохранённому месту
function QuestTracker:PinTopLeft()
    local control = self.control
    if self.preview then
        control:ClearAnchors()
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, self.preview.right, self.preview.top)
        return
    end
    local pos = QTM.sv.trackerPos
    if type(pos) == "table" and pos.x and pos.y then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

---------------------------------------------------------------------------
-- Предпросмотр рядом с настройками аддона: панель показывается в заданном
-- месте поверх меню, перетаскивать её в это время нельзя
---------------------------------------------------------------------------
function QuestTracker:SetPreview(enabled, right, top, width)
    local control = self.control
    if not control then return top end
    if enabled then
        self.preview = { right = right, top = top, width = width }
        self.previewTier = self.previewTier or control:GetDrawTier()
        control:SetDrawTier(DT_HIGH)
        control:SetMovable(false)
        control:SetResizeHandleSize(0)
        self:Refresh()
        local shown = self:IsEnabled() and #self.entries > 0
        control:SetHidden(not shown)
        return shown and (top + control:GetHeight()) or top
    end
    if not self.preview then return top end
    self.preview = nil
    if self.previewTier then control:SetDrawTier(self.previewTier) end
    self.previewTier = nil
    control:SetHidden(true)   -- на экране игры панель снова покажет её фрагмент
    control:ClearAnchors()
    if type(QTM.sv.trackerPos) == "table" then
        self:RestorePosition()
    else
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -24, 210)
    end
    self:ApplySettings()
    return top
end

-- Растянули за край: запоминаем ширину (высота всегда по содержимому)
function QuestTracker:SaveSize()
    QTM.sv.trackerWidth = zo_floor(self.control:GetWidth())
    self:SavePosition()
    self:Refresh()
end

function QuestTracker:ResetPosition()
    QTM.sv.trackerPos = nil
    QTM.sv.trackerWidth = nil
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -24, 210)
    self:Refresh()
end

---------------------------------------------------------------------------
-- Настройки: видимость, вид, закрепление, стандартная панель игры
---------------------------------------------------------------------------
function QuestTracker:ApplySettings()
    if not self.control then return end
    local sv = QTM.sv
    local enabled = self:IsEnabled()
    local locked = sv.trackerLocked == true
    self.control:SetMovable(not locked and not self.preview)
    self.control:SetResizeHandleSize((locked or self.preview) and 0 or RESIZE_HANDLE)
    self.fragment:SetHiddenForReason("Disabled", not enabled)

    local hideGame = enabled and sv.hideGameTracker ~= false
    if FOCUSED_QUEST_TRACKER_FRAGMENT then
        FOCUSED_QUEST_TRACKER_FRAGMENT:SetHiddenForReason(HIDE_REASON, hideGame, 0, 0)
    end
    if TIMED_ACTIVITY_TRACKER_FRAGMENT then
        TIMED_ACTIVITY_TRACKER_FRAGMENT:SetHiddenForReason(HIDE_REASON, hideGame, 0, 0)
    end
    self:ApplyStyle()   -- перерисует панель
end

-- Шапка панели: у подробной — заголовок и счётчик, у простой — только замок
function QuestTracker:ApplyStyle()
    local control = self.control
    local simple = self:IsSimple()
    for _, name in ipairs({ "Title", "Line", "HeaderIcon", "Hint" }) do
        control:GetNamedChild(name):SetHidden(simple)
    end
    self.lock:ClearAnchors()
    self.lock:SetHidden(simple)
    self.entriesArea:ClearAnchors()
    if simple then
        -- Без шапки и замка: панель двигается за заголовки разделов
        self.entriesArea:SetAnchor(TOPLEFT, control, TOPLEFT, 6, SIMPLE_TOP)
        self.entriesArea:SetAnchor(TOPRIGHT, control, TOPRIGHT, -6, SIMPLE_TOP)
    else
        self.lock:SetAnchor(TOPRIGHT, control, TOPRIGHT, -6, 4)
        self.hint:ClearAnchors()
        self.hint:SetAnchor(TOPRIGHT, self.lock, TOPLEFT, -6, 4)
        self.entriesArea:SetAnchor(TOPLEFT, control, TOPLEFT, 6, 30)
        self.entriesArea:SetAnchor(TOPRIGHT, control, TOPRIGHT, -6, 30)
    end
    self:PaintLock(false)
    self:ApplyTheme()
end

-- Цвета и непрозрачность из «Оформления»
function QuestTracker:ApplyTheme()
    if not self.control then return end
    local T = QTM.Style.T
    local bg = T.trackerBg
    local bgAlpha = self:IsSimple() and T.trackerSimpleBgAlpha or T.trackerBgAlpha
    self.bg:SetColor(bg.r, bg.g, bg.b, bgAlpha or 0)
    self.control:GetNamedChild("Line"):SetColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    -- Непрозрачность текста и значков (фон настраивается отдельно)
    local alpha = T.trackerAlpha or 1
    for _, name in ipairs({ "Entries", "Title", "Line", "HeaderIcon", "Hint", "Lock" }) do
        self.control:GetNamedChild(name):SetAlpha(alpha)
    end
    self:Refresh()
end

function QuestTracker:PaintLock(hover)
    local locked = QTM.sv.trackerLocked == true
    local icon = self.lock:GetNamedChild("Icon")
    icon:SetTexture(locked and ICON_LOCKED or ICON_UNLOCKED)
    -- Закреплённая панель: замок едва заметен, чтобы не мешать
    if hover then
        icon:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
    elseif locked then
        icon:SetColor(INFO[1], INFO[2], INFO[3], 0.45)
    else
        icon:SetColor(ICE[1], ICE[2], ICE[3], 0.9)
    end
end

function QuestTracker:ToggleLock()
    QTM.sv.trackerLocked = not QTM.sv.trackerLocked
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:ApplySettings()
    self:OnLockEnter(self.lock)
end

function QuestTracker:OnLockEnter(button)
    self:PaintLock(true)
    QTM.ShowTip("tracker", button, LEFT, QTM.sv.trackerLocked and L.TRACKER_UNLOCK_TT or L.TRACKER_LOCK_TT)
end

function QuestTracker:OnLockExit()
    self:PaintLock(false)
    ZO_Tooltips_HideTextTooltip()
end

---------------------------------------------------------------------------
-- Содержимое
---------------------------------------------------------------------------
function QuestTracker.GetTravelTooltip()
    local text = L.QUEST_TRAVEL_TT
    if QTM.sv.routeQuest then text = text .. "\n" .. L.QUEST_TRAVEL_FREE_TT end
    return text
end

local function IsDoneActivity(item)
    return item.complete and item.kind ~= QTM.Quests.KIND_QUEST
end

-- Что показывать: главное и закреплённые (выполненные стремления и задания фолианта — нет).
-- Простая панель по желанию показывает все задания журнала.
function QuestTracker:GetItems()
    local all = QTM.Quests:GetAll()
    local items = {}
    local added = {}
    local function Add(item)
        if item and not added[item.key] and not IsDoneActivity(item) then
            added[item.key] = true
            items[#items + 1] = item
        end
    end
    local main = all.mainKey and all.byKey[all.mainKey]
    if main then
        items[1] = main
        added[main.key] = true
    end
    for _, key in ipairs(QTM.Quests:GetPins()) do
        Add(all.byKey[key])
    end
    if self:IsSimple() and QTM.sv.trackerShowAll then
        for _, item in ipairs(all.quests) do Add(item) end
    end
    return items
end

function QuestTracker:Refresh()
    if not self.control then return end
    self.pool:ReleaseAllObjects()
    self.simplePool:ReleaseAllObjects()
    self.headerPool:ReleaseAllObjects()
    self.entries = {}
    if not self:IsEnabled() then
        self.fragment:SetHiddenForReason("Empty", true)
        if self.preview then self.control:SetHidden(true) end
        return
    end

    local items = self:GetItems()
    self.fragment:SetHiddenForReason("Empty", #items == 0)
    if #items == 0 then
        if self.preview then self.control:SetHidden(true) end
        return
    end

    local trackerWidth = self:GetWidth()
    local y
    if self:IsSimple() then
        y = self:BuildSimple(items, trackerWidth - 12)
    else
        y = self:BuildFull(items, trackerWidth - 12)
    end
    local top = self:IsSimple() and SIMPLE_TOP or 30
    local height = top + y + 4
    -- Верхний край стоит на месте: панель растёт и сворачивается только вниз
    -- (после перетаскивания игра может привязать панель к центру — тогда она
    -- росла бы в обе стороны)
    self:PinTopLeft()
    self.control:SetDimensionConstraints(MIN_WIDTH, height, MAX_WIDTH, height)
    self.control:SetDimensions(trackerWidth, height)
    if self.preview then self.control:SetHidden(false) end
    self.hint:SetText(#items > 1 and zo_strformat(L.TRACKER_PINNED, #items - (items[1].isMain and 1 or 0)) or "")
end

local function DropOnEntry(target)
    if target.isMain then return "main", nil, "fill" end
    return "pinned", target.item, "top"
end

-- Подробная панель: карточки друг под другом
function QuestTracker:BuildFull(items, width)
    local y = 0
    for index, item in ipairs(items) do
        local entry = self.pool:AcquireObject()
        entry.item = item
        entry.mgDrop = DropOnEntry
        entry:SetWidth(width)
        entry:ClearAnchors()
        entry:SetAnchor(TOPLEFT, self.entriesArea, TOPLEFT, 0, y)
        self:SetupEntry(entry, item, index == 1 and item.isMain)
        self.entries[#self.entries + 1] = entry
        y = y + entry:GetHeight() + ENTRY_GAP
    end
    return y
end

-- Раздел задания в простой панели: локация из журнала, стремления, фолиант
local function GroupOf(item)
    local Quests = QTM.Quests
    if item.kind == Quests.KIND_PURSUIT then return L.QUEST_SECTION_PURSUITS end
    if item.kind == Quests.KIND_TOME then return L.QUEST_SECTION_TOME end
    return item.category or item.zone or L.QUEST_ZONE_OTHER
end

function QuestTracker:IsGroupCollapsed(name)
    local collapsed = QTM.sv.trackerCollapsed
    return type(collapsed) == "table" and collapsed[name] == true
end

function QuestTracker:ToggleGroup(name)
    local sv = QTM.sv
    if type(sv.trackerCollapsed) ~= "table" then sv.trackerCollapsed = {} end
    sv.trackerCollapsed[name] = not sv.trackerCollapsed[name] or nil
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:Refresh()
end

-- Простая панель: разделы и задания без карточек
function QuestTracker:BuildSimple(items, width)
    local groups, order = {}, {}
    for _, item in ipairs(items) do
        local name = GroupOf(item)
        if not groups[name] then
            groups[name] = {}
            order[#order + 1] = name
        end
        local list = groups[name]
        list[#list + 1] = item
    end

    local y = 0
    for _, name in ipairs(order) do
        local list = groups[name]
        local collapsed = self:IsGroupCollapsed(name)
        local header = self.headerPool:AcquireObject()
        header.groupName = name
        header:SetWidth(width)
        header:ClearAnchors()
        header:SetAnchor(TOPLEFT, self.entriesArea, TOPLEFT, 0, y)
        self:SetupHeader(header, name, #list, collapsed)
        y = y + header:GetHeight()
        if not collapsed then
            for _, item in ipairs(list) do
                local entry = self.simplePool:AcquireObject()
                entry.item = item
                entry.mgDrop = DropOnEntry
                entry:SetWidth(width)
                entry:ClearAnchors()
                entry:SetAnchor(TOPLEFT, self.entriesArea, TOPLEFT, 0, y)
                self:SetupSimpleEntry(entry, item, item.isMain)
                self.entries[#self.entries + 1] = entry
                y = y + entry:GetHeight() + SIMPLE_GAP
            end
        end
        y = y + 2
    end
    return y
end

function QuestTracker:SetupHeader(header, name, count, collapsed)
    header.collapsed = collapsed
    header:GetNamedChild("Text"):SetText(name)
    header:GetNamedChild("Arrow"):SetTexture(collapsed and "EsoUI/Art/Buttons/tree_closed_up.dds" or "EsoUI/Art/Buttons/tree_open_up.dds")
    header:GetNamedChild("Count"):SetText("")
    self:PaintHeader(header)
end

function QuestTracker:PaintHeader(header)
    local r, g, b = TEXT[1], TEXT[2], TEXT[3]
    if header.isHover then r, g, b = GOLD[1], GOLD[2], GOLD[3] end
    header:GetNamedChild("Text"):SetColor(r, g, b, 1)
    header:GetNamedChild("Arrow"):SetColor(r, g, b, 1)
end

-- Условия задания: у главного — до четырёх строк, у остальных — limit
local function ConditionLines(item, isMain, limit)
    local lines = {}
    if item.kind == QTM.Quests.KIND_QUEST then
        local source = item.lines or {}
        if #source == 0 and item.stepText and item.stepText ~= "" then source = { item.stepText } end
        limit = isMain and MAX_MAIN_LINES or limit
        for index = 1, zo_min(#source, limit) do lines[#lines + 1] = source[index] end
        if #source > limit then lines[#lines] = zo_strformat(L.QUEST_MORE_LINES, lines[#lines], #source - limit + 1) end
    else
        lines[1] = item.info or ""
    end
    return lines
end

function QuestTracker:SetupSimpleEntry(entry, item, isMain)
    entry.isMain = isMain
    entry.isSimple = true
    local icon = entry:GetNamedChild("Icon")
    icon:SetTexture(item.icon or QTM.Quests.ICON_QUEST)

    local textWidth = entry:GetWidth() - 40 - (item.canTravel and 30 or 4)
    local name = entry:GetNamedChild("Name")
    name:ClearAnchors()
    name:SetAnchor(TOPLEFT, entry, TOPLEFT, 40, 2)
    name:SetWidth(textWidth)
    name:SetText(QTM.Quests.FormatName(item, 20))
    if isMain then
        name:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
    else
        name:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
    end
    local nameHeight = zo_max(name:GetTextHeight() or 0, 22)

    local lines = ConditionLines(item, isMain, SIMPLE_LINES)
    local linesLabel = entry:GetNamedChild("Lines")
    linesLabel:ClearAnchors()
    linesLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, 54, 2 + nameHeight + 1)
    linesLabel:SetWidth(zo_max(40, entry:GetWidth() - 54 - 4))
    linesLabel:SetText(table.concat(lines, "\n"))
    if item.claimable then
        linesLabel:SetColor(0.45, 0.85, 0.45, 1)
    else
        linesLabel:SetColor(DETAIL[1], DETAIL[2], DETAIL[3], 1)
    end
    local hasLines = #lines > 0 and lines[1] ~= ""
    linesLabel:SetHidden(not hasLines)
    local textHeight = hasLines and zo_max(linesLabel:GetTextHeight() or 0, #lines * 18) or 0
    entry:SetHeight(2 + nameHeight + 1 + textHeight + 2)

    local travel = entry:GetNamedChild("Travel")
    travel:GetNamedChild("Icon"):SetTexture(QTM.InfoPanel.ICON_TRAVEL)
    travel:SetHidden(not item.canTravel)
    travel:GetNamedChild("Icon"):SetColor(ICE[1], ICE[2], ICE[3], 1)

    self:PaintEntry(entry)
end

function QuestTracker:PaintEntry(entry)
    local item = entry.item
    if not item then return end
    if entry.isSimple then
        -- Без карточки: при наведении — лёгкая подсветка
        entry:GetNamedChild("Bg"):SetColor(ICE[1], ICE[2], ICE[3], entry.isHover and 0.12 or 0)
        return
    end
    local color = QTM.InfoPanel.KIND_COLORS[item.kind] or QTM.InfoPanel.KIND_COLORS.q
    local base = QTM.Style.T.trackerCardAlpha or 0.55
    local alpha = entry.isHover and zo_min(1, base + 0.3) or (entry.isMain and zo_min(1, base + 0.15) or base)
    local r, g, b = QTM.Style.Darken(color, entry.isHover and 0.22 or 0.12)
    entry:GetNamedChild("Bg"):SetColor(r, g, b, alpha)
    entry:GetNamedChild("Stripe"):SetColor(color.r, color.g, color.b, entry.isMain and 1 or 0.7)
end

function QuestTracker:SetupEntry(entry, item, isMain)
    entry.isMain = isMain
    entry.isSimple = false
    entry:GetNamedChild("Icon"):SetTexture(item.icon or QTM.Quests.ICON_QUEST)

    -- Длинное название не обрезается, а переносится на следующую строку
    local textWidth = entry:GetWidth() - 38 - 34
    local name = entry:GetNamedChild("Name")
    name:ClearAnchors()
    name:SetAnchor(TOPLEFT, entry, TOPLEFT, 38, 5)
    name:SetWidth(textWidth)
    name:SetFont(isMain and "ZoFontWinH4" or "ZoFontGameBold")
    name:SetText(QTM.Quests.FormatName(item, isMain and 22 or 18))
    if isMain then
        name:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
    else
        name:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
    end

    -- Условия: у главного — до четырёх строк, у остальных — одна
    local lines = ConditionLines(item, isMain, 1)
    local nameHeight = zo_max(name:GetTextHeight() or 0, isMain and 24 or 20)
    local linesLabel = entry:GetNamedChild("Lines")
    linesLabel:ClearAnchors()
    linesLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, 38, 5 + nameHeight + 1)
    linesLabel:SetWidth(textWidth)
    linesLabel:SetText(table.concat(lines, "\n"))
    if item.claimable then
        linesLabel:SetColor(0.45, 0.85, 0.45, 1)
    else
        linesLabel:SetColor(DETAIL[1], DETAIL[2], DETAIL[3], 1)
    end
    local textHeight = zo_max(linesLabel:GetTextHeight() or 0, #lines * 17)
    local height = 5 + nameHeight + 1 + textHeight + 6

    -- Полоса прогресса у стремлений и фолианта
    local barBg, barFill = entry:GetNamedChild("BarBg"), entry:GetNamedChild("BarFill")
    local hasBar = item.maxProgress ~= nil and item.maxProgress > 0
    barBg:SetHidden(not hasBar)
    barFill:SetHidden(not hasBar)
    if hasBar then
        local color = QTM.InfoPanel.KIND_COLORS[item.kind]
        barBg:ClearAnchors()
        barBg:SetAnchor(TOPLEFT, linesLabel, BOTTOMLEFT, 0, 4)
        barBg:SetAnchor(TOPRIGHT, linesLabel, BOTTOMRIGHT, 0, 4)
        barBg:SetColor(1, 1, 1, 0.12)
        barFill:SetColor(color.r, color.g, color.b, 0.9)
        local width = zo_max(1, entry:GetWidth() - 38 - 34)
        barFill:SetWidth(zo_max(1, zo_floor(width * zo_min(1, item.progress / item.maxProgress))))
        height = height + 7
    end
    entry:SetHeight(zo_max(isMain and 40 or 34, height))

    local travel = entry:GetNamedChild("Travel")
    travel:GetNamedChild("Icon"):SetTexture(QTM.InfoPanel.ICON_TRAVEL)
    travel:SetHidden(not item.canTravel)
    travel:GetNamedChild("Icon"):SetColor(ICE[1], ICE[2], ICE[3], 1)

    self:PaintEntry(entry)
end

-- Разделы простой панели
function QuestTracker:OnHeaderEnter(header)
    header.isHover = true
    self:PaintHeader(header)
    QTM.ShowTip("tracker", header, LEFT, header.collapsed and L.QUEST_EXPAND or L.QUEST_COLLAPSE)
end

function QuestTracker:OnHeaderExit(header)
    header.isHover = false
    self:PaintHeader(header)
    ZO_Tooltips_HideTextTooltip()
end

-- Простая панель без шапки: перетаскивание за заголовок раздела двигает всю панель
function QuestTracker:OnHeaderDragStart(header, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or QTM.sv.trackerLocked or self.preview then return end
    ZO_Tooltips_HideTextTooltip()
    self.movingByHeader = true
    self.control:StartMoving()
end

function QuestTracker:OnHeaderMouseUp(header, button, upInside)
    if self.movingByHeader then
        self.movingByHeader = false
        self.control:StopMovingOrResizing()
        self:SavePosition()
        self:Refresh()
        return
    end
    if upInside then self:OnHeaderClicked(header, button) end
end

function QuestTracker:OnHeaderClicked(header, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not header.groupName then return end
    ZO_Tooltips_HideTextTooltip()
    self:ToggleGroup(header.groupName)
end

---------------------------------------------------------------------------
-- Из XML
---------------------------------------------------------------------------
function QuestTracker:OnEntryEnter(entry)
    entry.isHover = true
    self:PaintEntry(entry)
    if entry.item then
        local text = QTM.InfoPanel.BuildItemTooltip(entry.item)
        QTM.ShowTip("tracker", entry, LEFT, text .. "\n\n|c8A8A8A" .. L.TRACKER_HINT .. "|r")
    end
end

function QuestTracker:OnEntryExit(entry)
    entry.isHover = false
    self:PaintEntry(entry)
    ZO_Tooltips_HideTextTooltip()
end

function QuestTracker:OnEntryDragStart(entry, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not entry.item then return end
    QTM.QuestDrag:Begin(entry.item)
end

function QuestTracker:OnEntryMouseUp(entry, button, upInside)
    if QTM.QuestDrag:IsDragging() then
        QTM.QuestDrag:Finish()
        return
    end
    if upInside then self:OnEntryClicked(entry, button) end
end

function QuestTracker:OnEntryClicked(entry, button)
    local item = entry.item
    if not item then return end
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        ZO_Tooltips_HideTextTooltip()
        QTM.InfoPanel.ShowItemMenu(entry, item)
    elseif button == MOUSE_BUTTON_INDEX_LEFT and not item.isMain then
        QTM.Quests:SetMain(item)
    end
end

function QuestTracker:OnTravelEnter(button)
    button:GetNamedChild("Icon"):SetColor(1, 1, 1, 1)
    QTM.ShowTip("tracker", button, LEFT, QuestTracker.GetTravelTooltip())
end

function QuestTracker:OnTravelExit(button)
    button:GetNamedChild("Icon"):SetColor(ICE[1], ICE[2], ICE[3], 1)
    ZO_Tooltips_HideTextTooltip()
end

function QuestTracker:OnTravelClicked(entry)
    local item = entry.item
    if not item or not item.canTravel then return end
    QTM.QuestTravel:Start(item.questIndex, QTM.QuestTravel:IsDirect())
end
