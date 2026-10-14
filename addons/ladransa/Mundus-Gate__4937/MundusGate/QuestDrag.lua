-- Перетаскивание заданий мышью — на правой панели карты и на панели заданий на экране.
--
-- Потяните задание: рядом с курсором появится его карточка, а место, куда оно
-- встанет, подсвечивается линией. Отпустите:
--   • на главном — задание станет главным;
--   • среди закреплённых — встанет на это место (не закреплённое — закрепится);
--   • в общем списке — закреплённое открепится.
--
-- Цели перетаскивания — элементы с полем mgDrop: функция, которая возвращает
-- зону ("main", "pinned", "other"), пункт-цель и где рисовать линию ("top" или "fill").
local QTM = MundusGate

local QuestDrag = {}
QTM.QuestDrag = QuestDrag

local ICE  = QTM.Style.ICE
local GOLD = QTM.Style.GOLD

function QuestDrag:Initialize()
    local control = MundusGateQuestDrag
    self.control = control
    self.icon  = control:GetNamedChild("Icon")
    self.label = control:GetNamedChild("Name")
    self.line  = MundusGateQuestDropLine
    self.lineFill = self.line:GetNamedChild("Fill")
    control:GetNamedChild("Bg"):SetColor(0.05, 0.05, 0.06, 0.92)
    self:ApplyTheme()
    control:SetHandler("OnUpdate", function() self:Update() end)
end

function QuestDrag:ApplyTheme()
    if self.control then self.control:GetNamedChild("Stripe"):SetColor(GOLD[1], GOLD[2], GOLD[3], 1) end
end

function QuestDrag:IsDragging()
    return self.item ~= nil
end

-- Начать перетаскивание пункта
function QuestDrag:Begin(item)
    if not item or not self.control then return end
    self.item = item
    self.icon:SetTexture(item.icon or QTM.Quests.ICON_QUEST)
    self.label:SetText(QTM.Quests.FormatName(item, 18))
    self.control:SetHidden(false)
    ZO_Tooltips_HideTextTooltip()
    PlaySound(SOUNDS.DEFAULT_CLICK)
    self:Update()
end

-- Найти цель под курсором: поднимаемся по родителям до элемента с mgDrop
local function FindTarget()
    local control = WINDOW_MANAGER and WINDOW_MANAGER:GetMouseOverControl()
    local depth = 0
    while control and depth < 8 do
        if control.mgDrop then return control end
        control = control:GetParent()
        depth = depth + 1
    end
    return nil
end

function QuestDrag:Update()
    if not self.item then return end
    local x, y = GetUIMousePosition()
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x + 16, y + 8)

    local target = FindTarget()
    self.target = target
    local line = self.line
    if not target then
        line:SetHidden(true)
        return
    end
    local zone, _, where = target.mgDrop(target)
    line:ClearAnchors()
    if where == "fill" then
        line:SetAnchor(TOPLEFT, target, TOPLEFT, 0, 0)
        line:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, 0, 0)
        self.lineFill:SetColor(GOLD[1], GOLD[2], GOLD[3], 0.18)
    elseif where == "bottom" then
        line:SetAnchor(TOPLEFT, target, BOTTOMLEFT, 0, -2)
        line:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, 0, 0)
        self.lineFill:SetColor(ICE[1], ICE[2], ICE[3], 1)
    else
        line:SetAnchor(TOPLEFT, target, TOPLEFT, 0, 0)
        line:SetAnchor(BOTTOMRIGHT, target, TOPRIGHT, 0, 2)
        self.lineFill:SetColor(ICE[1], ICE[2], ICE[3], 1)
    end
    line:SetHidden(zone == nil)
end

-- Отпустили кнопку мыши: true — это было перетаскивание (щелчок не обрабатывать)
function QuestDrag:Finish()
    if not self.item then return false end
    local item = self.item
    self:Update()
    local target = self.target
    self:Cancel()
    if target then
        local zone, targetItem = target.mgDrop(target)
        if zone then QTM.Quests:Drop(item, zone, targetItem) end
    end
    return true
end

function QuestDrag:Cancel()
    self.item = nil
    self.target = nil
    if self.control then self.control:SetHidden(true) end
    if self.line then self.line:SetHidden(true) end
end
