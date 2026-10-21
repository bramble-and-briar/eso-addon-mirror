-- «Быстрое перемещение» как ещё одна категория игрового колеса
-- «Предметы быстрого доступа» (по умолчанию клавиша Q).
--
-- У колеса игры есть категории: быстрые слоты, союзники, памятные вещи,
-- инструменты, эмоции. Их листают клавишами «Предыдущая/Следующая категория»
-- (по умолчанию — кнопки мыши). Список категорий в игре локальный, поэтому
-- аддон не меняет его, а переопределяет методы самого колеса:
--   • номер категории после последней игровой — наша категория;
--   • для неё колесо заполняется выбранными местами, а выбор места — перемещение;
--   • для игровых категорий всё работает как обычно.
local QTM   = AbyssQuest
local L     = QTM.L
local Data  = QTM.Data
local Style = QTM.Style

local Wheel = {}
QTM.Wheel = Wheel

-- Столько же слотов, сколько в игровых категориях колеса
Wheel.MAX_SLOTS = ACTION_BAR_UTILITY_BAR_SIZE or 8

-- Номер «категории» для нашей страницы колеса. Такой категории в игре нет,
-- поэтому для неё игровые функции слотов не вызываются.
local TRAVEL_HOTBAR_CATEGORY = 1000

---------------------------------------------------------------------------
-- Ячейки колеса: sv.wheelSlots[1..8], пустая ячейка = nil.
-- Номер ячейки совпадает с её положением в колесе игры.
-- Настраиваются перетаскиванием в окне «Колесо: быстрое перемещение».
---------------------------------------------------------------------------
function Wheel:GetSlots()
    return QTM.sv.wheelSlots
end

function Wheel:GetSlot(index)
    return QTM.sv.wheelSlots[index]
end

-- Новая ячейка всегда выглядит как место: его сохранённый вид или вид по умолчанию
function Wheel:NewSlot(nodeIndex)
    local look = Data:GetPlaceLook(nodeIndex)
    return {
        nodeIndex = nodeIndex,
        icon      = look.icon,
        color     = Style.CopyColor(look.color),
        tint      = look.tint == true,
    }
end

-- Положить место в ячейку (старое место в ней заменяется)
function Wheel:SetSlot(index, nodeIndex)
    local slots = QTM.sv.wheelSlots
    slots[index] = Wheel:NewSlot(nodeIndex)
    return slots[index]
end

function Wheel:ClearSlot(index)
    QTM.sv.wheelSlots[index] = nil
end

function Wheel:SwapSlots(a, b)
    local slots = QTM.sv.wheelSlots
    slots[a], slots[b] = slots[b], slots[a]
end

function Wheel:FirstFreeIndex()
    for index = 1, Wheel.MAX_SLOTS do
        if not QTM.sv.wheelSlots[index] then return index end
    end
end

-- Добавить место в первую свободную ячейку
function Wheel:AddSlot(nodeIndex)
    local index = self:FirstFreeIndex()
    if not index then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, zo_strformat(L.WHEEL_FULL, Wheel.MAX_SLOTS))
        return nil
    end
    return self:SetSlot(index, nodeIndex), index
end

function Wheel:IsEnabled()
    return QTM.sv.utilityWheelEnabled ~= false
end

---------------------------------------------------------------------------
-- Встраивание в колесо игры
---------------------------------------------------------------------------
local function CountGameCategories(wheel, originalNext)
    -- Игровая функция «следующая категория» возвращает 1 после последней —
    -- так узнаём, сколько категорий в колесе, не заглядывая в локальный список
    local saved = wheel.currentHotbarCategoryIndex
    local count = 1
    for index = 1, 50 do
        wheel.currentHotbarCategoryIndex = index
        if originalNext(wheel) == 1 then
            count = index
            break
        end
    end
    wheel.currentHotbarCategoryIndex = saved
    return count
end

-- Текст в центре колеса для места: название, локация, цена или причина
local function EntryName(node, available, reason)
    local status
    if available then
        local block = Data:GetNodeBlockReason(node, "Wheel")
        if block then
            status = "|cFF6060" .. block .. "|r"
        else
            local text, _, _, isRoute = Data:GetDisplayPrice(node, "Wheel")
            status = isRoute and ("|c" .. QTM.Style.Hex(QTM.Style.ICE) .. "" .. text .. "|r |c9A9A9A(" .. L.ROUTE_SHORT .. ")|r") or text
        end
    else
        status = "|cFF6060" .. (reason or "") .. "|r"
    end
    return node.name .. "\n|c9A9A9A" .. node.zoneName .. "|r\n" .. status
end

local function Install(wheel)
    if not wheel or wheel.qtmInstalled then return end
    wheel.qtmInstalled = true

    local original = {
        GetNextHotbarCategoryIndex     = wheel.GetNextHotbarCategoryIndex,
        GetPreviousHotbarCategoryIndex = wheel.GetPreviousHotbarCategoryIndex,
        GetHotbarCategory              = wheel.GetHotbarCategory,
        RefreshCategories              = wheel.RefreshCategories,
        PopulateMenu                   = wheel.PopulateMenu,
        SetupEntryControl              = wheel.SetupEntryControl,
        PrepareForInteraction          = wheel.PrepareForInteraction,
    }

    local gameCount   = CountGameCategories(wheel, original.GetNextHotbarCategoryIndex)
    local travelIndex = gameCount + 1

    local function IsTravel(self)
        return Wheel:IsEnabled() and self.currentHotbarCategoryIndex == travelIndex
    end

    local function CategoryName(self, index)
        if index == travelIndex then return L.WHEEL_CATEGORY end
        local saved = self.currentHotbarCategoryIndex
        self.currentHotbarCategoryIndex = index
        local category = original.GetHotbarCategory(self)
        self.currentHotbarCategoryIndex = saved
        return GetString("SI_HOTBARCATEGORY", category)
    end

    -- Листание категорий: игровые + наша после последней
    function wheel:GetNextHotbarCategoryIndex()
        if not Wheel:IsEnabled() then return original.GetNextHotbarCategoryIndex(self) end
        return self.currentHotbarCategoryIndex % travelIndex + 1
    end

    function wheel:GetPreviousHotbarCategoryIndex()
        if not Wheel:IsEnabled() then return original.GetPreviousHotbarCategoryIndex(self) end
        local index = self.currentHotbarCategoryIndex - 1
        if index == 0 then index = travelIndex end
        return index
    end

    function wheel:GetHotbarCategory()
        if IsTravel(self) then return TRAVEL_HOTBAR_CATEGORY end
        return original.GetHotbarCategory(self)
    end

    -- Названия категорий над колесом
    function wheel:RefreshCategories()
        if not Wheel:IsEnabled() then return original.RefreshCategories(self) end
        self.nextCategoryName:SetText(CategoryName(self, self:GetNextHotbarCategoryIndex()))
        self.previousCategoryName:SetText(CategoryName(self, self:GetPreviousHotbarCategoryIndex()))
        self.categoryLabel:SetText(CategoryName(self, self.currentHotbarCategoryIndex))
    end

    -- Можно сразу открывать колесо на нашей категории
    function wheel:PrepareForInteraction()
        local ok = original.PrepareForInteraction(self)
        if ok and Wheel:IsEnabled() and QTM.sv.utilityWheelStartOnTravel then
            self.currentHotbarCategoryIndex = travelIndex
        end
        return ok
    end

    -- Наполнение колеса
    function wheel:PopulateMenu()
        if not IsTravel(self) then return original.PopulateMenu(self) end

        local slots = Wheel:GetSlots()
        for slotNum = 1, Wheel.MAX_SLOTS do
            local slot = slots[slotNum]
            local node = slot and Data:GetNode(slot.nodeIndex)
            if node then
                local available, reason = Data:GetNodeStatus(node)
                local icon = Style.ResolveIcon(slot, node)
                self.menu:AddEntry(EntryName(node, available, reason), icon, icon,
                    function() Data:Travel(node, false, "Wheel") end,
                    { slotNum = slotNum, name = node.name, qtmSlot = slot, qtmNode = node, qtmAvailable = available })
            else
                self.menu:AddEntry(ZO_UTILITY_SLOT_EMPTY_STRING, ZO_UTILITY_SLOT_EMPTY_TEXTURE,
                    ZO_UTILITY_SLOT_EMPTY_TEXTURE, nil, { slotNum = slotNum })
            end
        end

        self.previousCategoryControl:SetHidden(false)
        self.nextCategoryControl:SetHidden(false)
        self:RefreshCategories()
    end

    -- Вид одного места в колесе
    function wheel:SetupEntryControl(entryControl, data)
        -- Элементы колеса переиспользуются между категориями: сбрасываем наш цвет
        entryControl.icon:SetColor(1, 1, 1, 1)
        if entryControl.glow then entryControl.glow:SetColor(1, 1, 1, 1) end

        if not IsTravel(self) then
            return original.SetupEntryControl(self, entryControl, data)
        end

        local NOT_SELECTED = false
        ZO_SetupSelectableItemRadialMenuEntryTemplate(entryControl, NOT_SELECTED, nil)
        if entryControl.cooldown then
            entryControl.cooldown:ResetCooldown()
            entryControl.cooldown:SetHidden(true)
        end

        local slot, node = data.qtmSlot, data.qtmNode
        if node then
            local color = slot.color or Style.DEFAULT_COLOR
            entryControl.icon:SetDesaturation(data.qtmAvailable and 0 or 1)
            if slot.tint and data.qtmAvailable then
                local r, g, b = Style.Lighten(color, 0.30)
                entryControl.icon:SetColor(r, g, b, 1)
            end
            if entryControl.glow then
                entryControl.glow:SetColor(color.r, color.g, color.b, 1)
            end
        end

        if entryControl.label then
            entryControl.label:SetText(node and node.name or "")
            entryControl.label:SetHidden(node == nil or ZO_AreTogglableWheelsEnabled())
        end
    end
end

function Wheel:Initialize()
    -- Название страницы в колесе (на выбранном языке)
    ZO_CreateStringId("SI_HOTBARCATEGORY" .. TRAVEL_HOTBAR_CATEGORY, L.WHEEL_CATEGORY)
    Install(UTILITY_WHEEL_KEYBOARD)
    Install(UTILITY_WHEEL_GAMEPAD)
end
