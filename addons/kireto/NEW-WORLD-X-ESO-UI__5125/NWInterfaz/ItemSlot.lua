-- Casilla de objeto plana, usada por el inventario, los bancos y el equipo.
local NWUI = NWUI
local Slot = {}
NWUI.Slot = Slot

local WM = WINDOW_MANAGER
local C, F = NWUI.C, NWUI.F
local LOCK_ICON = "EsoUI/Art/Miscellaneous/status_locked.dds"

local function Brighten(q, f)
    return math.min(1, q[1] * f), math.min(1, q[2] * f), math.min(1, q[3] * f)
end

-- ---------------------------------------------------------------------
-- Información emergente
-- ---------------------------------------------------------------------
function Slot.ShowTooltip(c)
    local d = c.data
    if not d then return end
    local left = d.tooltipSide ~= "right"
    if d.kind == "wheel" and d.hasItem then
        local link = GetSlotItemLink and GetSlotItemLink(d.wheelSlot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if link and link ~= "" then
            InitializeTooltip(ItemTooltip, c, RIGHT, -6, 0, LEFT)
            pcall(ItemTooltip.SetLink, ItemTooltip, link)
            return
        end
    elseif d.kind == "quest" then
        InitializeTooltip(ItemTooltip, c, RIGHT, -6, 0, LEFT)
        if d.toolIndex then
            pcall(ItemTooltip.SetQuestTool, ItemTooltip, d.questIndex, d.toolIndex)
        else
            pcall(ItemTooltip.SetQuestItem, ItemTooltip, d.questIndex, d.stepIndex, d.conditionIndex)
        end
        return
    end
    if not d.hasItem then
        if d.emptyName then
            if left then
                InitializeTooltip(InformationTooltip, c, RIGHT, -6, 0, LEFT)
            else
                InitializeTooltip(InformationTooltip, c, LEFT, 6, 0, RIGHT)
            end
            SetTooltipText(InformationTooltip, d.emptyName)
        end
        return
    end
    if left then
        InitializeTooltip(ItemTooltip, c, RIGHT, -6, 0, LEFT)
    else
        InitializeTooltip(ItemTooltip, c, LEFT, 6, 0, RIGHT)
    end
    if d.kind == "worn" then
        pcall(ItemTooltip.SetWornItem, ItemTooltip, d.slotIndex)
    else
        pcall(ItemTooltip.SetBagItem, ItemTooltip, d.bagId, d.slotIndex)
        if d.equippable then
            pcall(function()
                ItemTooltip:ShowComparativeTooltips()
                ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip1)
                ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip2)
            end)
        end
    end
end

function Slot.HideTooltip()
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
    pcall(ItemTooltip.HideComparativeTooltips, ItemTooltip)
end

-- ---------------------------------------------------------------------
-- Acciones
-- ---------------------------------------------------------------------
function Slot.Transfer(d)
    if d.kind == "craft" then
        NWUI.MoveItem(d.bagId, d.slotIndex, "backpack")
        return
    end
    if d.kind == "item" then
        local mode = NWUI.Scenes and NWUI.Scenes.CurrentMode() or "inventory"
        if mode == "guildbank" then
            NWUI.MoveItem(d.bagId, d.slotIndex, "guild")
        elseif mode == "bank" or mode == "housebank" then
            NWUI.MoveItem(d.bagId, d.slotIndex, "bank")
        end
    elseif d.kind == "bank" or d.kind == "guild" then
        NWUI.MoveItem(d.bagId, d.slotIndex, "backpack")
    end
end

-- Doble clic
function Slot.PrimaryAction(c)
    local d = c.data
    if not d or not d.hasItem then return end
    if d.kind == "worn" then
        NWUI.Unequip(d.slotIndex)
        return
    end
    if d.kind == "quest" or d.kind == "wheel" then return end
    if d.assignMode then
        Slot.AssignToTarget(c)
        return
    end
    if d.kind == "craft" then
        Slot.Transfer(d)
        return
    end
    local mode = NWUI.Scenes and NWUI.Scenes.CurrentMode() or "inventory"
    if mode ~= "inventory" or d.kind ~= "item" then
        Slot.Transfer(d)
        return
    end
    if d.equippable then
        NWUI.Equip(d.bagId, d.slotIndex)
    elseif d.usable then
        NWUI.Call("UseItem", d.bagId, d.slotIndex)
    end
end

local function LinkInChat(d)
    local link = GetItemLink(d.bagId, d.slotIndex)
    if link and link ~= "" then ZO_LinkHandler_InsertLink(link) end
end

-- Menú propio (se usa si el menú del juego no está disponible)
function Slot.OwnMenu(c)
    local d = c.data
    ClearMenu()
    local mode = NWUI.Scenes and NWUI.Scenes.CurrentMode() or "inventory"
    if d.kind == "worn" then
        AddMenuItem("Desequipar", function() NWUI.Unequip(d.slotIndex) end)
    else
        if mode ~= "inventory" then
            if d.kind == "item" then
                AddMenuItem("Depositar", function() Slot.Transfer(d) end)
            else
                AddMenuItem("Retirar", function() Slot.Transfer(d) end)
            end
        end
        if d.kind == "item" then
            if d.equippable then AddMenuItem("Equipar", function() NWUI.Equip(d.bagId, d.slotIndex) end) end
            if d.usable then AddMenuItem("Usar", function() NWUI.Call("UseItem", d.bagId, d.slotIndex) end) end
            if not CanItemBeMarkedAsJunk or CanItemBeMarkedAsJunk(d.bagId, d.slotIndex) then
                AddMenuItem(d.junk and NWUI.T("unjunk") or NWUI.T("junk"), function()
                    SetItemIsJunk(d.bagId, d.slotIndex, not d.junk)
                end)
            end
            if SetItemIsPlayerLocked then
                AddMenuItem(d.locked and "Desbloquear" or "Bloquear", function()
                    SetItemIsPlayerLocked(d.bagId, d.slotIndex, not d.locked)
                end)
            end
        end
    end
    AddMenuItem(NWUI.T("link_chat"), function() LinkInChat(d) end)
    ShowMenu(c)
end

function Slot.ShowMenu(c)
    if NWUI.sv.inv.useGameMenu and ZO_InventorySlot_ShowContextMenu then
        local ok = pcall(ZO_InventorySlot_ShowContextMenu, c)
        if ok then return end
    end
    Slot.OwnMenu(c)
end

function Slot.AssignToTarget(c)
    local d = c.data
    local panel = c.panel
    local target = panel and panel.qsTarget
    if not target and GetCurrentQuickslot then target = GetCurrentQuickslot() end
    if NWUI.Inventory and NWUI.Inventory.AssignQuickslot then
        NWUI.Inventory.AssignQuickslot(d.bagId, d.slotIndex, target)
    end
end

function Slot.Drop(c)
    if GetCursorContentType() == MOUSE_CONTENT_EMPTY then return end
    local d = c.data
    if d and d.kind == "wheel" then
        -- primero lo que hace el juego: colocar lo del cursor en la casilla
        if NWUI.Call("PlaceInActionBar", d.wheelSlot, WHEEL_CAT) then return end
        local bag, slot = GetCursorBagId(), GetCursorSlotIndex()
        ClearCursor()
        if NWUI.Inventory and NWUI.Inventory.AssignQuickslot then
            NWUI.Inventory.AssignQuickslot(bag, slot, d.wheelSlot)
        end
        return
    end
    if d and d.kind == "worn" then
        NWUI.DropOnto("worn", d.slotIndex)
    elseif c.panel then
        c.panel:ReceiveDrop()
    end
end

-- ---------------------------------------------------------------------
-- Manejadores compartidos (casilla propia y botón seguro)
-- ---------------------------------------------------------------------
local NEW_ICON = "NWInterfaz/textures/nuevo.dds"

-- Quita la marca de "nuevo" (como el juego original: al pasar el ratón)
function Slot.ClearNew(c)
    local d = c and c.data
    if not (d and d.isNew) then return end
    d.isNew = false
    if c.newBadge then c.newBadge:SetHidden(true); NWUI.Pulse(c.newBadge, false) end
    if NWUI.Inventory and NWUI.Inventory.ForgetNew then NWUI.Inventory.ForgetNew(d.bagId, d.slotIndex) end
    if NWUI.Inventory and NWUI.Inventory.QueueTabNew then NWUI.Inventory.QueueTabNew() end
    local si = rawget(_G, "SHARED_INVENTORY")
    if si and si.ClearNewStatus and d.bagId and d.slotIndex then
        pcall(si.ClearNewStatus, si, d.bagId, d.slotIndex)
    end
end

function Slot.OnEnter(c)
    c.hl:SetHidden(false)
    Slot.ShowTooltip(c)
    Slot.ClearNew(c)
end

function Slot.OnExit(c)
    c.hl:SetHidden(true)
    Slot.HideTooltip()
end

-- Clic izquierdo. 'handleDrop' = false cuando el juego ya se encarga de
-- soltar lo que lleva el cursor (botón seguro).
function Slot.LeftClick(c, handleDrop)
    local d = c.data
    if not d then return end
    if GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then
        if handleDrop then Slot.Drop(c) end
    elseif d.kind == "wheel" then
        if c.panel then
            c.panel.qsTarget = d.wheelSlot
            c.panel:Refresh()
        end
    elseif d.assignMode and not IsShiftKeyDown() then
        -- con la rueda del juego abierta: el clic levanta el objeto y luego se
        -- hace clic en la casilla de la rueda donde se quiere poner
        local INV = NWUI.Inventory
        if INV and INV.NativeWheelShowing and INV.NativeWheelShowing()
            and NWUI.Call("PickupInventoryItem", d.bagId, d.slotIndex)
            and GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then
            Slot.HideTooltip()
            return
        end
        Slot.AssignToTarget(c)
    elseif IsShiftKeyDown() and d.hasItem and d.kind ~= "quest" then
        LinkInChat(d)
    end
end

function Slot.DragStart(c, button)
    local d = c.data
    if not d or not d.hasItem or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then return end
    Slot.HideTooltip()
    if d.kind == "worn" then
        -- Levantar piezas equipadas es una función privada de ESO:
        -- se desequipa con doble clic o clic derecho > Desequipar.
        return
    elseif d.kind == "item" or d.kind == "bank" then
        NWUI.Call("PickupInventoryItem", d.bagId, d.slotIndex)
    end
end

function Slot.Wheel(c, delta)
    if c.panel and c.panel.ScrollBy then c.panel:ScrollBy(-delta * 90) end
end

-- ---------------------------------------------------------------------
-- Botón seguro
-- Funciones como UseItem (abrir geodas, cofres, contenedores...) son
-- privadas: solo el código del propio juego puede llamarlas. Por eso cada
-- casilla de objeto lleva encima un botón creado con la plantilla nativa
-- del inventario: el clic derecho (menú) y el doble clic los ejecuta el
-- juego, igual que en su inventario, y "Usar" funciona.
-- ---------------------------------------------------------------------
local SECURE_KINDS = { item = true, bank = true, guild = true, craft = true }
local SECURE_TEMPLATES = { "ZO_InventorySlotBehavior_Keyboard", "ZO_ItemSlot" }

local function CreateSecureButton(c)
    if not WM.CreateControlFromVirtual then return nil end
    local b
    for _, tpl in ipairs(SECURE_TEMPLATES) do
        local ok, ctl = pcall(WM.CreateControlFromVirtual, WM, NWUI.UID("NWUI_SlotBtn"), c, tpl)
        if ok and ctl then b = ctl; break end
    end
    if not b then return nil end

    -- Si se usó la plantilla con gráficos, se ocultan sus partes visibles.
    for _, child in ipairs({ "Icon", "StackCount", "Cooldown" }) do
        local ch = b.GetNamedChild and b:GetNamedChild(child)
        if ch then ch:SetHidden(true) end
    end
    pcall(function() b:SetMouseOverTexture() end)
    pcall(function() b:SetPressedMouseOverTexture() end)

    b:ClearAnchors()
    b:SetAnchorFill(c)
    if b.SetDrawLevel then b:SetDrawLevel(20) end
    if b.EnableMouseButton then b:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true) end
    b:SetMouseEnabled(false)
    b:SetHidden(true)

    -- Lo visual y el arrastre siguen siendo nuestros. OnClicked y
    -- OnMouseDoubleClick se dejan con los manejadores del juego.
    b:SetHandler("OnMouseEnter", function() Slot.OnEnter(c) end)
    b:SetHandler("OnMouseExit", function() Slot.OnExit(c) end)
    b:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        -- En el arcón de artesanía el juego no gestiona soltar; lo hacemos nosotros.
        local d = c.data
        Slot.LeftClick(c, d and d.kind == "craft")
    end)
    -- Arrastrar: lo hace el propio juego (plantilla nativa), así el objeto se
    -- puede soltar en la rueda de objetos rápidos o en cualquier ventana del juego.
    b:SetHandler("OnReceiveDrag", function() Slot.Drop(c) end)
    b:SetHandler("OnMouseWheel", function(_, delta) Slot.Wheel(c, delta) end)
    return b
end

-- ---------------------------------------------------------------------
-- Casillas de la rueda: botón con la plantilla nativa de la rueda del juego
-- (ZO_AbilitySlot). Al soltar un objeto, el propio juego lo coloca
-- (PlaceInActionBar) y reemplaza el anterior; arrastrar desde la rueda
-- también funciona para mover objetos entre casillas.
-- ---------------------------------------------------------------------
local WHEEL_CAT = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
local wheelObject   -- objeto con GetHotbarCategory() que esperan las funciones nativas

local function WheelObject()
    if wheelObject then return wheelObject end
    local qk = rawget(_G, "QUICKSLOT_KEYBOARD")
    local native = type(qk) == "table" and qk.wheel
    if native and type(native.GetHotbarCategory) == "function" then
        wheelObject = native
    else
        wheelObject = { GetHotbarCategory = function() return WHEEL_CAT end }
    end
    return wheelObject
end

local function CreateWheelButton(c)
    if not WM.CreateControlFromVirtual then return nil end
    local ok, ctl = pcall(WM.CreateControlFromVirtual, WM, NWUI.UID("NWUI_WheelSlot"), c, "ZO_AbilitySlot")
    if not ok or not ctl then return nil end
    local b = ctl.GetNamedChild and ctl:GetNamedChild("Button")
    if not b or type(b) == "function" then return nil end
    ctl:ClearAnchors()
    ctl:SetAnchorFill(c)
    if ctl.SetDrawLevel then ctl:SetDrawLevel(20) end
    pcall(function() b:SetMouseOverTexture(nil) end)
    pcall(function() b:SetMouseOverTexture("") end)
    -- lo visual y el clic izquierdo (elegir destino) siguen siendo nuestros;
    -- OnClicked / OnReceiveDrag / OnDragStart / menú: los del juego
    b:SetHandler("OnMouseEnter", function() Slot.OnEnter(c) end)
    b:SetHandler("OnMouseExit", function() Slot.OnExit(c) end)
    b:SetHandler("OnMouseUp", function(_, upInside, button)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and GetCursorContentType() == MOUSE_CONTENT_EMPTY then
            local d = c.data
            if d and c.panel then
                c.panel.qsTarget = d.wheelSlot
                c.panel:Refresh()
            end
        end
    end)
    b:SetHandler("OnMouseDoubleClick", function() end)   -- sin vaciar por accidente
    b:SetHandler("OnMouseWheel", function(_, delta) Slot.Wheel(c, delta) end)
    ctl.button = b
    ctl:SetHidden(true)
    return ctl
end

local function SetupWheelButton(c, d)
    local isWheel = d.kind == "wheel" and d.wheelSlot ~= nil and WHEEL_CAT ~= nil
    local w = c.wheelBtn
    if type(w) == "function" then w = nil end
    if isWheel and w == nil then w = CreateWheelButton(c) or false; c.wheelBtn = w end
    if not w then return end
    w:SetHidden(not isWheel)
    w.button:SetMouseEnabled(isWheel)
    if isWheel then
        local b = w.button
        b.slotType = ABILITY_SLOT_TYPE_UTILITY or 2
        b.slotNum = d.wheelSlot
        b.hotbarCategory = WHEEL_CAT
        b.object = WheelObject()
    end
end

local function SetupSecureButton(c, d)
    local b = c.secure
    if not b then return end
    local on = (d.hasItem and SECURE_KINDS[d.kind] and d.slotType ~= nil and d.bagId ~= nil) and true or false
    b:SetMouseEnabled(on)
    b:SetHidden(not on)
    if not on then
        b.slotType, b.bagId, b.slotIndex, b.dataEntry, b.stackCount = nil, nil, nil, nil, 0
        return
    end
    b.slotType = d.slotType
    b.bagId = d.bagId
    b.slotIndex = d.slotIndex
    b.stackCount = d.stack or 0
    b.dataEntry = c.dataEntry
    if ZO_Inventory_BindSlot then
        pcall(ZO_Inventory_BindSlot, b, d.slotType, d.slotIndex, d.bagId)
    end
end

-- ---------------------------------------------------------------------
-- Creación
-- ---------------------------------------------------------------------
function Slot.Create(parent)
    local c = WM:CreateControl(NWUI.UID("NWUI_Slot"), parent, CT_CONTROL)
    c:SetMouseEnabled(true)
    local lw = NWUI.LinePx(1)
    c.border, c.bg = NWUI.FlatBox(c, C.slotEmpty, C.slotBorder, lw)
    -- Base oscura bajo el color de calidad: así el color puede ser translúcido
    -- sin que se vea el borde (que es un relleno) a través de él.
    c.base = NWUI.Tex(c, C.slotEmpty, 1)
    c.base:SetAnchor(TOPLEFT, c, TOPLEFT, lw, lw)
    c.base:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -lw, -lw)
    c.bg:SetDrawLevel(2)

    c.icon = NWUI.Tex(c, nil, 3)
    c.icon:SetAnchor(TOPLEFT, c, TOPLEFT, 3, 3)
    c.icon:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -3, -3)

    -- Barra de durabilidad (línea blanca plana, como en New World)
    c.dura = NWUI.Tex(c, {0.93, 0.93, 0.93, 0.95}, 4)
    c.dura:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 3, -3)
    c.dura:SetHeight(2)
    c.dura:SetHidden(true)

    c.count = NWUI.Label(c, F.count, C.text, "")
    c.count:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -4, 0)

    c.lock = NWUI.Tex(c, nil, 5)
    c.lock:SetTexture(LOCK_ICON)
    c.lock:SetDimensions(16, 16)
    c.lock:SetAnchor(TOPRIGHT, c, TOPRIGHT, -2, 2)
    c.lock:SetHidden(true)

    -- marca de objeto nuevo: círculo blanco con "!" arriba a la izquierda
    c.newBadge = NWUI.Tex(c, nil, 7)
    c.newBadge:SetTexture(NEW_ICON)
    c.newBadge:SetDimensions(17, 17)
    c.newBadge:SetAnchor(TOPLEFT, c, TOPLEFT, 1, 1)
    c.newBadge:SetHidden(true)

    c.price = NWUI.Label(c, F.price, C.text, "")
    c.price:SetHidden(true)

    c.hl = NWUI.Tex(c, {1, 1, 1, 0.10}, 6)
    c.hl:SetAnchorFill(c)
    c.hl:SetHidden(true)

    c:SetHandler("OnMouseEnter", function(self) Slot.OnEnter(self) end)
    c:SetHandler("OnMouseExit", function(self) Slot.OnExit(self) end)
    c:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then return end
        local d = self.data
        if not d then return end
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if d.kind == "wheel" then
                if d.hasItem and NWUI.Inventory then NWUI.Inventory.ClearQuickslot(d.wheelSlot) end
            elseif d.kind ~= "quest" and d.hasItem then
                Slot.ShowMenu(self)
            end
        elseif button == MOUSE_BUTTON_INDEX_LEFT then
            Slot.LeftClick(self, true)
        end
    end)
    c:SetHandler("OnMouseDoubleClick", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then Slot.PrimaryAction(self) end
    end)
    c:SetHandler("OnDragStart", function(self, button) Slot.DragStart(self, button) end)
    c:SetHandler("OnReceiveDrag", function(self) Slot.Drop(self) end)
    c:SetHandler("OnMouseWheel", function(self, delta) Slot.Wheel(self, delta) end)

    c.secure = CreateSecureButton(c)
    return c
end

-- ---------------------------------------------------------------------
-- Rellenar una casilla con datos
-- ---------------------------------------------------------------------
function Slot.Setup(c, d)
    c.data = d
    local w = c:GetWidth()
    if d.hasItem then
        local q = NWUI.QUALITY[d.quality or 1] or NWUI.QUALITY[1]
        -- Fondo de calidad translúcido (mismo color, menos sólido)
        local a = ((NWUI.sv and NWUI.sv.inv and NWUI.sv.inv.slotBgAlpha) or 35) / 100
        c.bg:SetColor(q[1], q[2], q[3], a)
        local r, g, b = Brighten(q, 1.5)
        c.border:SetColor(r, g, b, math.min(1, a + 0.45))
        c.icon:SetTexture(d.icon)
        c.icon:SetHidden(false)
        if d.meets == false then c.icon:SetColor(1, 0.45, 0.45, 1) else c.icon:SetColor(1, 1, 1, 1) end
        c.icon:SetAlpha(d.junk and 0.5 or 1)
        c.count:SetText((d.stack and d.stack > 1) and tostring(d.stack) or "")
        if d.condition then
            local pct = zo_clamp(d.condition / 100, 0, 1)
            c.dura:SetHidden(false)
            c.dura:SetWidth(math.max(1, (w - 6) * pct))
            if d.condition < 25 then NWUI.SetColor(c.dura, C.danger) else c.dura:SetColor(0.93, 0.93, 0.93, 0.95) end
        else
            c.dura:SetHidden(true)
        end
        c.lock:SetHidden(not d.locked)
        c.newBadge:SetHidden(not d.isNew)
        NWUI.Pulse(c.newBadge, d.isNew == true)
    else
        c.newBadge:SetHidden(true)
        NWUI.Pulse(c.newBadge, false)
        NWUI.SetColor(c.bg, C.slotEmpty)
        NWUI.SetColor(c.border, C.slotBorder)
        if d.emptyIcon then
            c.icon:SetTexture(d.emptyIcon)
            c.icon:SetHidden(false)
            c.icon:SetColor(1, 1, 1, 1)
            c.icon:SetAlpha(0.28)
        else
            c.icon:SetHidden(true)
        end
        c.count:SetText("")
        c.dura:SetHidden(true)
        c.lock:SetHidden(true)
    end

    -- Datos que usa el menú contextual nativo del juego
    c.stackCount = d.stack or 0
    c.dataEntry = { data = {
        bagId = d.bagId, slotIndex = d.slotIndex, stackCount = d.stack or 0,
        isJunk = d.junk, locked = d.locked, meetsUsageRequirement = d.meets ~= false,
        itemType = d.itemType, equipType = d.equipType, quality = d.quality,
        displayQuality = d.quality, name = d.name, iconFile = d.icon,
    } }
    if ZO_Inventory_BindSlot and d.slotType then
        pcall(ZO_Inventory_BindSlot, c, d.slotType, d.slotIndex, d.bagId)
    end
    SetupSecureButton(c, d)
    SetupWheelButton(c, d)

    if NWUI.Price then pcall(NWUI.Price.Apply, c, d) end
end
