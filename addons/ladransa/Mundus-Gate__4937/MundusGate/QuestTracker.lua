-- Панель заданий на экране: главное задание и закреплённые.
--
-- Главное — сверху, крупнее и со всеми условиями; закреплённые — ниже, по
-- одному условию. У заданий с известным местом — кнопка перемещения к
-- ближайшему святилищу (с бесплатным путём через игрока, если он включён).
-- Щёлкать можно в режиме курсора; ПКМ — то же меню, что на панели карты.
-- Панель можно перетащить мышью и растянуть по ширине за край (если не
-- закреплена в настройках); задания внутри перетаскиваются мышью.
-- По желанию стандартная панель заданий игры прячется, чтобы не дублировать.
local QTM = MundusGate
local L   = QTM.L

local QuestTracker = {}
QTM.QuestTracker = QuestTracker

local HIDE_REASON   = "MundusGate"
local DEFAULT_WIDTH = 310
local MIN_WIDTH     = 220
local MAX_WIDTH     = 640
local RESIZE_HANDLE = 8
local ENTRY_GAP     = 4
local MAX_MAIN_LINES = 4
local GOLD  = { 0.90, 0.85, 0.66 }
local ICE   = { 0.36, 0.76, 0.91 }

function QuestTracker:IsEnabled()
    return QTM.sv.questTracker ~= false
end

function QuestTracker:Initialize()
    local control = MundusGateQuestTracker
    self.control = control
    self.entriesArea = control:GetNamedChild("Entries")
    control:GetNamedChild("Title"):SetText(L.TRACKER_TITLE)
    self.hint = control:GetNamedChild("Hint")
    self.entries = {}

    self.pool = ZO_ControlPool:New("MundusGate_TrackerEntry", self.entriesArea, "Entry")
    control:GetNamedChild("Bg"):SetColor(0.03, 0.03, 0.04, 0.55)
    control:GetNamedChild("Line"):SetColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    -- Перетащить задание на пустое место панели — в конец закреплённых
    control.mgDrop = function() return "pinned", nil, "bottom" end

    self:RestorePosition()
    self.fragment = ZO_HUDFadeSceneFragment:New(control)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)

    self:ApplySettings()
    self:Refresh()
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
    QTM.sv.trackerPos = { x = self.control:GetLeft(), y = self.control:GetTop() }
end

function QuestTracker:GetWidth()
    return zo_clamp(tonumber(QTM.sv.trackerWidth) or DEFAULT_WIDTH, MIN_WIDTH, MAX_WIDTH)
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
-- Настройки: видимость, закрепление, стандартная панель игры
---------------------------------------------------------------------------
function QuestTracker:ApplySettings()
    local sv = QTM.sv
    local enabled = self:IsEnabled()
    local locked = sv.trackerLocked == true
    self.control:SetMovable(not locked)
    self.control:SetResizeHandleSize(locked and 0 or RESIZE_HANDLE)
    self.fragment:SetHiddenForReason("Disabled", not enabled)

    local hideGame = enabled and sv.hideGameTracker ~= false
    if FOCUSED_QUEST_TRACKER_FRAGMENT then
        FOCUSED_QUEST_TRACKER_FRAGMENT:SetHiddenForReason(HIDE_REASON, hideGame, 0, 0)
    end
    if TIMED_ACTIVITY_TRACKER_FRAGMENT then
        TIMED_ACTIVITY_TRACKER_FRAGMENT:SetHiddenForReason(HIDE_REASON, hideGame, 0, 0)
    end
    self:Refresh()
end

---------------------------------------------------------------------------
-- Содержимое
---------------------------------------------------------------------------
function QuestTracker.GetTravelTooltip()
    local text = L.QUEST_TRAVEL_TT
    if QTM.sv.routeQuest then text = text .. "\n" .. L.QUEST_TRAVEL_FREE_TT end
    return text
end

-- Что показывать: главное и закреплённые (выполненные стремления и задания фолианта — нет)
function QuestTracker:GetItems()
    local all = QTM.Quests:GetAll()
    local items = {}
    local main = all.mainKey and all.byKey[all.mainKey]
    if main then
        items[1] = main
    end
    for _, key in ipairs(QTM.Quests:GetPins()) do
        local item = all.byKey[key]
        if item and item ~= main and not (item.complete and item.kind ~= QTM.Quests.KIND_QUEST) then
            items[#items + 1] = item
        end
    end
    return items
end

function QuestTracker:Refresh()
    if not self.control then return end
    self.pool:ReleaseAllObjects()
    self.entries = {}
    if not self:IsEnabled() then
        self.fragment:SetHiddenForReason("Empty", true)
        return
    end

    local items = self:GetItems()
    self.fragment:SetHiddenForReason("Empty", #items == 0)
    if #items == 0 then return end

    local y = 0
    local trackerWidth = self:GetWidth()
    local width = trackerWidth - 12
    for index, item in ipairs(items) do
        local entry = self.pool:AcquireObject()
        entry.item = item
        entry.mgDrop = function(target)
            if target.isMain then return "main", nil, "fill" end
            return "pinned", target.item, "top"
        end
        entry:SetWidth(width)
        entry:ClearAnchors()
        entry:SetAnchor(TOPLEFT, self.entriesArea, TOPLEFT, 0, y)
        self:SetupEntry(entry, item, index == 1 and item.isMain)
        self.entries[#self.entries + 1] = entry
        y = y + entry:GetHeight() + ENTRY_GAP
    end
    local height = 30 + y + 4
    self.control:SetDimensionConstraints(MIN_WIDTH, height, MAX_WIDTH, height)
    self.control:SetDimensions(trackerWidth, height)
    self.hint:SetText(#items > 1 and zo_strformat(L.TRACKER_PINNED, #items - (items[1].isMain and 1 or 0)) or "")
end

function QuestTracker:PaintEntry(entry)
    local item = entry.item
    if not item then return end
    local color = QTM.InfoPanel.KIND_COLORS[item.kind] or QTM.InfoPanel.KIND_COLORS.q
    local alpha = entry.isHover and 0.85 or (entry.isMain and 0.7 or 0.55)
    local r, g, b = QTM.Style.Darken(color, entry.isHover and 0.22 or 0.12)
    entry:GetNamedChild("Bg"):SetColor(r, g, b, alpha)
    entry:GetNamedChild("Stripe"):SetColor(color.r, color.g, color.b, entry.isMain and 1 or 0.7)
end

function QuestTracker:SetupEntry(entry, item, isMain)
    entry.isMain = isMain
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
        name:SetColor(1, 1, 1, 1)
    end

    -- Условия: у главного — до четырёх строк, у остальных — одна
    local lines = {}
    if item.kind == QTM.Quests.KIND_QUEST then
        local source = item.lines or {}
        if #source == 0 and item.stepText and item.stepText ~= "" then source = { item.stepText } end
        local limit = isMain and MAX_MAIN_LINES or 1
        for index = 1, zo_min(#source, limit) do lines[#lines + 1] = source[index] end
        if #source > limit then lines[#lines] = zo_strformat(L.QUEST_MORE_LINES, lines[#lines], #source - limit + 1) end
    else
        lines[1] = item.info or ""
    end
    local nameHeight = zo_max(name:GetTextHeight() or 0, isMain and 24 or 20)
    local linesLabel = entry:GetNamedChild("Lines")
    linesLabel:ClearAnchors()
    linesLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, 38, 5 + nameHeight + 1)
    linesLabel:SetWidth(textWidth)
    linesLabel:SetText(table.concat(lines, "\n"))
    if item.claimable then
        linesLabel:SetColor(0.45, 0.85, 0.45, 1)
    else
        linesLabel:SetColor(0.78, 0.78, 0.78, 1)
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

---------------------------------------------------------------------------
-- Из XML
---------------------------------------------------------------------------
function QuestTracker:OnEntryEnter(entry)
    entry.isHover = true
    self:PaintEntry(entry)
    if entry.item then
        local text = QTM.InfoPanel.BuildItemTooltip(entry.item)
        ZO_Tooltips_ShowTextTooltip(entry, LEFT, text .. "\n\n|c8A8A8A" .. L.TRACKER_HINT .. "|r")
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
    ZO_Tooltips_ShowTextTooltip(button, LEFT, QuestTracker.GetTravelTooltip())
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
