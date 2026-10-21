-- Кнопки быстрого перемещения на экране.
-- Каждая кнопка — квадратная плитка со значком и цветом, привязанная к месту.
-- Кнопки видны на основном экране игры; нажимать их можно в режиме курсора
-- (клавиша «.» по умолчанию). Пока кнопки не закреплены, их можно перетаскивать.
local QTM   = AbyssQuest
local L     = QTM.L
local Data  = QTM.Data
local Style = QTM.Style

local Buttons = {}
QTM.Buttons = Buttons

local DEFAULT_SIZE = 56
local MIN_SIZE     = 32
local MAX_SIZE     = 128
local DRAG_EPSILON = 3

Buttons.MIN_SIZE = MIN_SIZE
Buttons.MAX_SIZE = MAX_SIZE

---------------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------------
function Buttons:Initialize()
    self.hud       = AbyssQuestHud
    self.container = self.hud:GetNamedChild("Container")
    self.pool      = ZO_ControlPool:New("AbyssQuest_HudButton", self.container, "Button")
    self.controls  = {}   -- id кнопки -> control

    -- Показываем слой кнопок на основном экране и в режиме курсора
    self.fragment = ZO_HUDFadeSceneFragment:New(self.hud)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)

    self:RebuildAll()
end

function Buttons:GetList()
    return QTM.sv.buttons
end

function Buttons:FindById(id)
    for index, item in ipairs(QTM.sv.buttons) do
        if item.id == id then return item, index end
    end
end

---------------------------------------------------------------------------
-- Создание и удаление
---------------------------------------------------------------------------
function Buttons:Add(nodeIndex)
    local sv = QTM.sv
    sv.nextButtonId = (sv.nextButtonId or 0) + 1

    -- Новая кнопка появляется чуть выше центра экрана, каждая следующая — со сдвигом
    local count = #sv.buttons
    local x = zo_floor(GuiRoot:GetWidth() / 2 - DEFAULT_SIZE / 2 + (count % 6) * (DEFAULT_SIZE + 10) - 2.5 * (DEFAULT_SIZE + 10))
    local y = zo_floor(GuiRoot:GetHeight() * 0.32 + zo_floor(count / 6) * (DEFAULT_SIZE + 24))

    local item = {
        id        = sv.nextButtonId,
        nodeIndex = nodeIndex,
        icon      = nil,              -- nil = значок места
        color     = Style.CopyColor(Style.DEFAULT_COLOR),
        tint      = false,
        size      = DEFAULT_SIZE,
        showLabel = false,
        hidden    = false,
        x         = x,
        y         = y,
    }
    Data:ApplyPlaceStyle(item)
    sv.buttons[#sv.buttons + 1] = item
    self:Refresh(item)
    return item
end

function Buttons:Remove(id)
    local _, index = self:FindById(id)
    if index then table.remove(QTM.sv.buttons, index) end
    local control = self.controls[id]
    if control then
        self.pool:ReleaseObject(control.poolKey)
        self.controls[id] = nil
    end
end

function Buttons:RebuildAll()
    self.pool:ReleaseAllObjects()
    ZO_ClearTable(self.controls)
    for _, item in ipairs(QTM.sv.buttons) do
        self:Refresh(item)
    end
    self:UpdateVisibility()
end

---------------------------------------------------------------------------
-- Отрисовка
---------------------------------------------------------------------------
function Buttons:GetControl(item)
    local control = self.controls[item.id]
    if not control then
        local key
        control, key = self.pool:AcquireObject()
        control.poolKey = key
        self.controls[item.id] = control
    end
    control.itemId = item.id
    return control
end

-- Состояние кнопки: открыто ли место и можно ли переместиться прямо сейчас
function Buttons:GetState(item)
    local node = item.nodeIndex and Data:GetNode(item.nodeIndex)
    if not node then
        return node, false, false
    end
    local available = Data:GetNodeStatus(node)
    local blocked = available and Data:GetNodeBlockReason(node, "Buttons") ~= nil
    return node, available, blocked
end

function Buttons:Paint(control, item)
    local node, available, blocked = self:GetState(item)
    Style.PaintTile(control, {
        icon  = Style.ResolveIcon(item, node),
        color = item.color,
        tint  = item.tint,
    }, {
        size      = item.size or DEFAULT_SIZE,
        available = available,
        blocked   = blocked,
        hover     = control.isHover,
        pressed   = control.isPressed,
        label     = item.showLabel and node and node.name or nil,
    })
end

function Buttons:Refresh(item)
    local control = self:GetControl(item)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, item.x or 0, item.y or 0)
    control:SetMovable(not QTM.sv.buttonsLocked)
    control:SetHidden(item.hidden == true)
    self:Paint(control, item)
end

function Buttons:RefreshAll()
    for _, item in ipairs(QTM.sv.buttons) do
        local control = self.controls[item.id]
        if control then
            control:SetMovable(not QTM.sv.buttonsLocked)
            self:Paint(control, item)
        end
    end
end

function Buttons:UpdateVisibility()
    local sv = QTM.sv
    local hide = not sv.buttonsVisible or (sv.buttonsHideInCombat and IsUnitInCombat("player"))
    self.container:SetHidden(hide)
    self.container:SetAlpha(QTM.Style.T.buttonsAlpha or 1)
end

function Buttons:SetLocked(locked)
    QTM.sv.buttonsLocked = locked
    self:RefreshAll()
end

---------------------------------------------------------------------------
-- Мышь (обработчики вызываются из AbyssQuest.xml)
---------------------------------------------------------------------------
local function ItemFor(control)
    return control.itemId and (Buttons:FindById(control.itemId))
end

function Buttons:OnMouseEnter(control)
    local item = ItemFor(control)
    if not item then return end
    control.isHover = true
    self:Paint(control, item)
    if not QTM.sv.buttonsTooltips then return end

    local node, available = self:GetState(item)
    local lines = {}
    if node then
        lines[#lines + 1] = "|cFFFFFF" .. node.name .. "|r"
        lines[#lines + 1] = "|c9A9A9A" .. node.zoneName .. " · " .. Data.TYPE_NAMES[node.type] .. "|r"
        if available then
            local block = Data:GetNodeBlockReason(node, "Buttons")
            if block then
                lines[#lines + 1] = "|cFF6060" .. block .. "|r"
            else
                lines[#lines + 1] = Data:GetPriceLine(node, "Buttons")
            end
        else
            local _, reason = Data:GetNodeStatus(node)
            lines[#lines + 1] = "|cFF6060" .. (reason or "") .. "|r"
        end
    else
        lines[#lines + 1] = L.BUTTON_NOT_BOUND
    end
    lines[#lines + 1] = "|c7A7A7A" .. (QTM.sv.buttonsLocked and L.BUTTON_HINT_LOCKED or L.BUTTON_HINT) .. "|r"

    local side = (control:GetCenter() > GuiRoot:GetWidth() / 2) and LEFT or RIGHT
    QTM.ShowTip("buttons", control, side, table.concat(lines, "\n"))
end

function Buttons:OnMouseExit(control)
    local item = ItemFor(control)
    control.isHover = false
    control.isPressed = false
    ZO_Tooltips_HideTextTooltip()
    if item then self:Paint(control, item) end
end

function Buttons:OnMouseDown(control, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local item = ItemFor(control)
    if not item then return end
    control.downX, control.downY = control:GetLeft(), control:GetTop()
    control.isPressed = true
    self:Paint(control, item)
end

function Buttons:OnMoveStop(control)
    local item = ItemFor(control)
    if not item then return end
    item.x = zo_floor(control:GetLeft())
    item.y = zo_floor(control:GetTop())
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, item.x, item.y)
end

function Buttons:OnMouseUp(control, button, upInside)
    local item = ItemFor(control)
    if not item then return end
    control.isPressed = false
    self:Paint(control, item)

    -- Кнопку перетащили — это не нажатие
    if button == MOUSE_BUTTON_INDEX_LEFT and control.downX then
        local moved = math.abs(control:GetLeft() - control.downX) > DRAG_EPSILON
                   or math.abs(control:GetTop() - control.downY) > DRAG_EPSILON
        control.downX, control.downY = nil, nil
        if moved then return end
    end
    if not upInside then return end

    if button == MOUSE_BUTTON_INDEX_LEFT then
        local node = item.nodeIndex and Data:GetNode(item.nodeIndex)
        if not node then
            QTM.ButtonsEditor:Show(item.id)
            return
        end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        Data:Travel(node, false, "Buttons")
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        ZO_Tooltips_HideTextTooltip()
        ClearMenu()
        AddMenuItem(L.BUTTON_CTX_EDIT, function() QTM.ButtonsEditor:Show(item.id) end)
        local node = item.nodeIndex and Data:GetNode(item.nodeIndex)
        if node then
            if Data:GetNodeStatus(node) then
                if QTM.Route:WillUse(node, "Buttons") then
                    AddMenuItem(zo_strformat(L.CTX_PAY_NOW, (Data:GetPriceInfo(node))), function() Data:Travel(node, true, "Buttons") end)
                elseif QTM.Route:CanRoute(node) then
                    AddMenuItem(L.CTX_ROUTE_FREE, function() QTM.Route:Request(node) end)
                end
            end
            AddMenuItem(L.BUTTON_CTX_RENAME, function() Data:ShowRenameDialog(node) end)
        end
        if QTM.sv.buttonsLocked then
            AddMenuItem(L.BUTTON_CTX_UNLOCK, function() self:SetLocked(false) end)
        else
            AddMenuItem(L.BUTTON_CTX_LOCK, function() self:SetLocked(true) end)
        end
        AddMenuItem(L.BUTTON_CTX_DELETE, function() self:Remove(item.id) end)
        ShowMenu(control)
    end
end

---------------------------------------------------------------------------
-- Размер
---------------------------------------------------------------------------
function Buttons:ClampSize(size)
    return zo_clamp(size, MIN_SIZE, MAX_SIZE)
end
