-- Tipos de display: icon, bar, text.
-- Cada display implementa Build(key), Configure(displayConfig) y Update(state, now).
-- Los controles de ESO no se pueden destruir, así que se reutilizan desde un pool por nombre.

local OA = OmniAura
local U = OA.Utils
local WM = WINDOW_MANAGER

local D = { types = {}, pool = {} }
OA.Display = D

D.DEFAULT_ICON = "/esoui/art/icons/icon_missing.dds"

local WHITE = { 1, 1, 1, 1 }
local BAR_COLOR = { 0.2, 0.6, 1, 0.9 }
local BAR_BG = { 0, 0, 0, 0.6 }

local function Font(size, style)
    return string.format("$(BOLD_FONT)|%d|%s", zo_round(size), style or "soft-shadow-thick")
end

function D.Solid(name, parent, r, g, b, a)
    local bd = WM:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(r, g, b, a)
    bd:SetEdgeColor(0, 0, 0, 0)
    return bd
end

function D.Label(name, parent, align)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local Solid, Label = D.Solid, D.Label

-- Hace que una ventana se mueva arrastrando solo "handle" (su barra de título).
-- Si la ventana entera fuese movible, arrastrar una barra de scroll movería la ventana.
function D.MakeDraggable(win, handle)
    local updateName = win:GetName() .. "_Drag"
    handle:SetMouseEnabled(true)
    handle:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local mx, my = GetUIMousePosition()
        local left, top = win:GetLeft(), win:GetTop()
        EVENT_MANAGER:RegisterForUpdate(updateName, 0, function()
            local x, y = GetUIMousePosition()
            win:ClearAnchors()
            win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left + x - mx, top + y - my)
        end)
    end)
    handle:SetHandler("OnMouseUp", function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
    end)
end

---------------------------------------------------------------------------
-- Base común: contenedor, posición y modo "unlock" para mover.
---------------------------------------------------------------------------
local Base = {}

function Base:BuildCommon(key)
    local root = WM:CreateControl(key, D.tlw, CT_CONTROL)
    root:SetHidden(true)
    root:SetClampedToScreen(true)
    self.root = root

    self.moveBg = Solid(key .. "MoveBg", root, 0, 0.6, 1, 0.3)
    self.moveBg:SetAnchorFill(root)
    self.moveBg:SetDrawLevel(10)
    self.moveBg:SetHidden(true)

    self.moveLabel = Label(key .. "MoveLabel", root)
    self.moveLabel:SetFont(Font(14))
    self.moveLabel:SetColor(1, 0.85, 0.2, 1)
    self.moveLabel:SetAnchor(TOP, root, BOTTOM, 0, 4)
    self.moveLabel:SetHidden(true)

    root:SetHandler("OnMoveStop", function() self:SavePosition() end)

    -- Esquina para cambiar el tamaño arrastrando (solo en modo edición).
    local grip = Solid(key .. "Grip", root, 1, 0.85, 0.2, 0.9)
    grip:SetDimensions(12, 12)
    grip:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 5, 5)
    grip:SetDrawLevel(11)
    grip:SetMouseEnabled(true)
    grip:SetHidden(true)
    grip:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then self:StartResize() end
    end)
    grip:SetHandler("OnMouseUp", function() self:StopResize() end)
    grip:SetHandler("OnMouseEnter", function()
        if MOUSE_CURSOR_RESIZE_NWSE then WM:SetMouseCursor(MOUSE_CURSOR_RESIZE_NWSE) end
    end)
    grip:SetHandler("OnMouseExit", function()
        if MOUSE_CURSOR_DO_NOT_CARE then WM:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE) end
    end)
    self.grip = grip
end

function Base:ApplyPosition()
    local d = self.aura.display
    self.root:ClearAnchors()
    self.root:SetAnchor(CENTER, GuiRoot, CENTER, d.x or 0, d.y or 0)
end

function Base:SavePosition()
    local cx, cy = self.root:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    local d = self.aura.display
    d.x, d.y = zo_round(cx - gx), zo_round(cy - gy)
    self:ApplyPosition()
end

function Base:SetUnlocked(on)
    self.moveBg:SetHidden(not on)
    self.moveLabel:SetHidden(not on)
    self.grip:SetHidden(not on)
    self.root:SetMouseEnabled(on)
    self.root:SetMovable(on)
    if on and self.aura then
        self.moveLabel:SetText(self.aura.name or "")
    end
    if not on then self:StopResize() end
end

-- Redimensionado: se sigue al ratón cada fotograma mientras el botón está pulsado.
-- El aura está anclada por su centro, así que se desplaza la mitad del cambio
-- para que la esquina superior izquierda se quede quieta.
local RESIZE_UPDATE = "OmniAura_Resize"

function Base:StartResize()
    local mx, my = GetUIMousePosition()
    local w, h = self.root:GetDimensions()
    local d = self.aura.display
    self.resize = { mx = mx, my = my, w = w, h = h, x = d.x or 0, y = d.y or 0 }
    EVENT_MANAGER:RegisterForUpdate(RESIZE_UPDATE, 0, function() self:UpdateResize() end)
end

function Base:UpdateResize()
    local r = self.resize
    if not r then return end
    local mx, my = GetUIMousePosition()
    local d = self.aura.display
    self:SetBoxSize(d, r.w + (mx - r.mx), r.h + (my - r.my))
    self:Configure(d)
    local w, h = self.root:GetDimensions()
    d.x = zo_round(r.x + (w - r.w) / 2)
    d.y = zo_round(r.y + (h - r.h) / 2)
    self:ApplyPosition()
end

function Base:StopResize()
    if not self.resize then return end
    self:UpdateResize()
    self.resize = nil
    EVENT_MANAGER:UnregisterForUpdate(RESIZE_UPDATE)
end

local function Clamp(v, lo, hi)
    return zo_clamp(zo_round(v), lo, hi)
end

function Base:SetShown(show)
    self.root:SetHidden(not show)
end

local function NewType(name)
    local impl = setmetatable({}, { __index = Base })
    D.types[name] = impl
    return impl
end

---------------------------------------------------------------------------
-- icon: icono con sombreado de duración, temporizador y acumulaciones.
--   size, icon, color, textColor, text (centro, "{time}"), text2 (esquina, "{stacks}"), shade, border
---------------------------------------------------------------------------
local Icon = NewType("icon")

function Icon:SetBoxSize(d, w, h)
    d.size = Clamp(math.max(w, h), 16, 256)
end

function Icon:Build(key)
    local root = self.root

    self.border = Solid(key .. "Border", root, 0, 0, 0, 0.85)
    self.border:SetAnchor(TOPLEFT, root, TOPLEFT, -1, -1)
    self.border:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 1, 1)
    self.border:SetDrawLevel(0)

    self.icon = WM:CreateControl(key .. "Icon", root, CT_TEXTURE)
    self.icon:SetAnchorFill(root)
    self.icon:SetDrawLevel(1)

    self.shade = Solid(key .. "Shade", root, 0, 0, 0, 0.6)
    self.shade:SetAnchor(TOPLEFT, root, TOPLEFT)
    self.shade:SetAnchor(TOPRIGHT, root, TOPRIGHT)
    self.shade:SetDrawLevel(2)

    self.timer = Label(key .. "Timer", root)
    self.timer:SetAnchor(CENTER, root, CENTER)
    self.timer:SetDrawLevel(3)

    self.stacks = Label(key .. "Stacks", root, TEXT_ALIGN_RIGHT)
    self.stacks:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -2, 0)
    self.stacks:SetDrawLevel(3)

    -- Texto encima del icono (solo se usa en el tipo "Icono + texto").
    self.top = Label(key .. "Top", root)
    self.top:SetAnchor(BOTTOM, root, TOP, 0, -2)
end

function Icon:Configure(d)
    local size = d.size or 48
    self.size = size
    self.root:SetDimensions(size, size)
    self.border:SetHidden(d.border == false)
    self.timer:SetFont(Font(math.max(12, size * 0.38)))
    self.stacks:SetFont(Font(math.max(10, size * 0.3)))
    self.top:SetFont(Font(math.max(12, size * 0.32)))
    self.top:SetColor(U.Color(d.textColor, WHITE))
    self.top:SetHidden(self.dtype ~= "icontext")
    self.timer:SetColor(U.Color(d.textColor, WHITE))
    self.stacks:SetColor(U.Color(d.textColor, WHITE))
end

function Icon:Update(state, now)
    local d = self.aura.display
    self.icon:SetTexture(d.icon or state.icon or D.DEFAULT_ICON)
    self.icon:SetDesaturation((state.missing and d.desaturate ~= false) and 1 or 0)
    self.icon:SetColor(U.Color(d.color, WHITE))

    local progress = U.Progress(state, now)
    if progress and d.shade ~= false then
        self.shade:SetHidden(false)
        self.shade:SetHeight(self.size * (1 - progress))
    else
        self.shade:SetHidden(true)
    end

    self.timer:SetText(U.FormatTemplate(d.text or "{time}", state, now))
    self.stacks:SetText(U.FormatTemplate(d.text2 or "{stacks}", state, now))
    if self.dtype == "icontext" then
        self.top:SetText(U.FormatTemplate(d.textTop or "{name}", state, now))
    end
end

-- icontext: el mismo icono con un texto encima (textTop, por defecto "{name}").
D.types.icontext = Icon

---------------------------------------------------------------------------
-- bar: barra de progreso (duración o % de recurso) con icono opcional.
--   width, height, showIcon, icon, color, bgColor, textColor, text (izq, "{name}"), text2 (der, "{time}")
---------------------------------------------------------------------------
local Bar = NewType("bar")

function Bar:SetBoxSize(d, w, h)
    d.width = Clamp(w, 40, 800)
    d.height = Clamp(h, 8, 100)
end

function Bar:Build(key)
    local root = self.root

    self.icon = WM:CreateControl(key .. "Icon", root, CT_TEXTURE)

    self.area = WM:CreateControl(key .. "Area", root, CT_CONTROL)

    self.bg = Solid(key .. "Bg", self.area, 0, 0, 0, 0.6)
    self.bg:SetAnchorFill(self.area)
    self.bg:SetDrawLevel(0)

    self.fill = Solid(key .. "Fill", self.area, 1, 1, 1, 1)
    self.fill:SetAnchor(TOPLEFT, self.area, TOPLEFT)
    self.fill:SetAnchor(BOTTOMLEFT, self.area, BOTTOMLEFT)
    self.fill:SetDrawLevel(1)

    self.left = Label(key .. "Left", self.area, TEXT_ALIGN_LEFT)
    self.left:SetAnchor(LEFT, self.area, LEFT, 4, 0)
    self.left:SetDrawLevel(2)

    self.right = Label(key .. "Right", self.area, TEXT_ALIGN_RIGHT)
    self.right:SetAnchor(RIGHT, self.area, RIGHT, -4, 0)
    self.right:SetDrawLevel(2)
end

function Bar:Configure(d)
    local w, h = d.width or 220, d.height or 24
    local iconW = (d.showIcon == false) and 0 or h
    self.root:SetDimensions(w, h)

    self.icon:SetHidden(iconW == 0)
    self.icon:ClearAnchors()
    self.icon:SetAnchor(TOPLEFT, self.root, TOPLEFT)
    self.icon:SetDimensions(h, h)

    self.area:ClearAnchors()
    self.area:SetAnchor(TOPLEFT, self.root, TOPLEFT, iconW, 0)
    self.area:SetAnchor(BOTTOMRIGHT, self.root, BOTTOMRIGHT)
    self.barWidth = w - iconW

    self.bg:SetCenterColor(U.Color(d.bgColor, BAR_BG))
    local font = Font(math.max(10, h * 0.6))
    self.left:SetFont(font)
    self.right:SetFont(font)
    self.left:SetColor(U.Color(d.textColor, WHITE))
    self.right:SetColor(U.Color(d.textColor, WHITE))
end

function Bar:Update(state, now)
    local d = self.aura.display
    if d.showIcon ~= false then
        self.icon:SetTexture(d.icon or state.icon or D.DEFAULT_ICON)
        self.icon:SetDesaturation((state.missing and d.desaturate ~= false) and 1 or 0)
    end

    local progress = U.Progress(state, now) or 1
    self.fill:SetWidth(self.barWidth * progress)
    self.fill:SetCenterColor(U.Color(d.color, BAR_COLOR))

    self.left:SetText(U.FormatTemplate(d.text or "{name}", state, now))
    self.right:SetText(U.FormatTemplate(d.text2 or "{time}", state, now))
end

---------------------------------------------------------------------------
-- text: solo texto.  size, width, textColor, text ("{name} {time}")
---------------------------------------------------------------------------
local Text = NewType("text")

-- El alto controla el tamaño de letra (el contenedor mide letra + 10).
function Text:SetBoxSize(d, w, h)
    d.width = Clamp(w, 40, 800)
    d.size = Clamp(h - 10, 10, 80)
end

function Text:Build(key)
    self.label = Label(key .. "Label", self.root)
    self.label:SetAnchor(CENTER, self.root, CENTER)
end

function Text:Configure(d)
    local size = d.size or 24
    self.root:SetDimensions(d.width or 240, size + 10)
    self.label:SetFont(Font(size))
    self.label:SetColor(U.Color(d.textColor, WHITE))
end

function Text:Update(state, now)
    local d = self.aura.display
    self.label:SetText(U.FormatTemplate(d.text or "{name} {time}", state, now))
end

---------------------------------------------------------------------------
-- API del módulo
---------------------------------------------------------------------------
function D.Init()
    local tlw = WM:CreateTopLevelWindow("OmniAura_TLW")
    tlw:SetAnchorFill(GuiRoot)
    tlw:SetMouseEnabled(false)
    -- Por encima del editor, para poder arrastrar las auras con él abierto.
    tlw:SetDrawTier(DT_MEDIUM)
    D.tlw = tlw

    -- Visible solo en el HUD (se oculta en menús, mapa, inventario...)
    local fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    D.fragment = fragment
end

function D.Acquire(aura)
    aura.display = aura.display or {}
    local dtype = aura.display.type
    if not D.types[dtype] then dtype = "icon" end

    local key = string.format("OmniAura_A%d_%s", aura.id, dtype)
    local obj = D.pool[key]
    if not obj then
        obj = setmetatable({}, { __index = D.types[dtype] })
        obj:BuildCommon(key)
        obj:Build(key)
        D.pool[key] = obj
    end

    obj.aura = aura
    obj.inUse = true
    obj.dtype = dtype
    obj:Configure(aura.display)
    obj:ApplyPosition()
    obj:SetShown(false)
    obj:SetUnlocked(OA.unlocked or OA.previewId == aura.id)
    return obj
end

function D.ReleaseAll()
    for _, obj in pairs(D.pool) do
        obj.inUse = false
        obj:SetUnlocked(false)
        obj:SetShown(false)
    end
end

-- Un aura es editable en pantalla (mover/redimensionar) si están todas desbloqueadas
-- o si es la seleccionada en el editor.
local function IsEditable(aura)
    return OA.unlocked or (aura ~= nil and OA.previewId == aura.id)
end

function D.RefreshUnlocked()
    for _, obj in pairs(D.pool) do
        if obj.inUse then obj:SetUnlocked(IsEditable(obj.aura)) end
    end
end

function D.SetUnlocked(on)
    OA.unlocked = on
    D.RefreshUnlocked()
end
