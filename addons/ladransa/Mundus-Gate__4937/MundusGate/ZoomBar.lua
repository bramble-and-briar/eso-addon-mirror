-- Масштаб карты: свой ползунок внизу окна карты вместо стандартного
-- (который стоит под правой панелью). Минус и плюс — шаг масштаба, щелчок
-- или перетаскивание по полосе — нужный масштаб, колесо мыши над полосой —
-- тоже шаг. Управляет тем же механизмом масштаба, что и ползунок игры.
-- Если у карты масштаб не меняется (подземелья, поля сражений) — полоса скрыта.
local QTM = MundusGate

local ZoomBar = {}
QTM.ZoomBar = ZoomBar

local NUM_TICKS   = 11
local BOTTOM_GAP  = 8
local GOLD = { 0.90, 0.85, 0.66 }

function ZoomBar:IsEnabled()
    return QTM.sv.zoomBar ~= false
end

local function GetPanAndZoom()
    if ZO_WorldMap_GetPanAndZoom then return ZO_WorldMap_GetPanAndZoom() end
    return nil
end

function ZoomBar:Initialize()
    local control = MundusGateZoomBar
    self.control = control
    self.content = control:GetNamedChild("Content")
    self.track   = self.content:GetNamedChild("Track")
    self.line    = self.track:GetNamedChild("Line")
    self.fill    = self.track:GetNamedChild("Fill")
    self.thumb   = self.track:GetNamedChild("Thumb")
    self.minus   = self.content:GetNamedChild("Minus")
    self.plus    = self.content:GetNamedChild("Plus")

    -- Как часть карты: тонкая полоса и деления в цвет интерфейса игры, без своей рамки
    self.line:SetColor(1, 1, 1, 0.22)
    self.fill:SetColor(GOLD[1], GOLD[2], GOLD[3], 0.75)

    -- Деления: 11 ступеней масштаба, как у ползунка игры
    self.ticks = {}
    for index = 1, NUM_TICKS do
        local tick = CreateControl(control:GetName() .. "Tick" .. index, self.track, CT_TEXTURE)
        tick:SetDimensions(1, 6)
        tick:SetColor(1, 1, 1, 0.28)
        tick:SetDrawLayer(DL_CONTROLS)
        self.ticks[index] = tick
    end

    self.fragment = ZO_SimpleSceneFragment:New(control)
    control:SetHandler("OnUpdate", function() self:Update() end)

    self:Apply()
end

-- Свой ползунок вместо стандартного (или наоборот, если выключено)
function ZoomBar:Apply()
    if not WORLD_MAP_SCENE then return end
    local enabled = self:IsEnabled()
    if enabled == self.applied then return end
    self.applied = enabled
    if enabled then
        if WORLD_MAP_ZOOM_FRAGMENT then WORLD_MAP_SCENE:RemoveFragment(WORLD_MAP_ZOOM_FRAGMENT) end
        WORLD_MAP_SCENE:AddFragment(self.fragment)
    else
        WORLD_MAP_SCENE:RemoveFragment(self.fragment)
        if WORLD_MAP_ZOOM_FRAGMENT then WORLD_MAP_SCENE:AddFragment(WORLD_MAP_ZOOM_FRAGMENT) end
        self.control:SetHidden(true)
    end
end

-- Место — нижняя полоса окна карты (там же кнопки этажей подземелий).
-- В Сиродиле по центру полосы стоит ползунок истории — тогда ползунок
-- масштаба уходит к левому краю полосы.
function ZoomBar:Layout()
    local map = ZO_WorldMap
    if not map then return end
    local strip = ZO_WorldMapButtons
    local history = ZO_WorldMapButtonsHistorySlider
    local historyShown = history ~= nil and not history:IsHidden()
    local key = tostring(map:GetBottom()) .. ":" .. tostring(map:GetLeft()) .. ":" .. tostring(map:GetRight()) .. ":" .. tostring(historyShown) .. ":" .. tostring(self.track:GetWidth())
    if key == self.layoutKey then return end
    self.layoutKey = key
    self.control:ClearAnchors()
    if strip then
        if historyShown then
            self.control:SetAnchor(LEFT, strip, LEFT, 8, 0)
        else
            self.control:SetAnchor(CENTER, strip, CENTER, 0, 0)
        end
    else
        self.control:SetAnchor(BOTTOM, map, BOTTOM, 0, -BOTTOM_GAP)
    end

    local width = self.track:GetWidth()
    for index, tick in ipairs(self.ticks) do
        tick:ClearAnchors()
        tick:SetAnchor(CENTER, self.track, LEFT, zo_floor((index - 1) / (NUM_TICKS - 1) * width), 0)
    end
end

function ZoomBar:GetValueFromMouse()
    local mouseX = GetUIMousePosition()
    local left, width = self.track:GetLeft(), self.track:GetWidth()
    if not width or width <= 0 then return 0 end
    return zo_clamp((mouseX - left) / width, 0, 1)
end

function ZoomBar:SetZoom(value)
    local pz = GetPanAndZoom()
    if not pz then return end
    if pz.SetLockedNormalizedZoom and ZO_WorldMapScroll then
        pz:SetLockedNormalizedZoom(value, ZO_WorldMapScroll:GetCenter())
    elseif pz.SetTargetNormalizedZoom then
        pz:SetTargetNormalizedZoom(value)
    end
end

function ZoomBar:Update()
    local pz = GetPanAndZoom()
    if not pz then return end
    self:Layout()

    local minZoom, maxZoom = pz:GetZoomMinMax()
    local canZoom = minZoom ~= nil and maxZoom ~= nil and maxZoom - minZoom > 0
    if pz.CanMapZoom and not pz:CanMapZoom() then canZoom = false end
    self.content:SetHidden(not canZoom)
    if not canZoom then return end

    if self.dragging then
        local value = self:GetValueFromMouse()
        if not self.lastDrag or math.abs(value - self.lastDrag) > 0.004 then
            self.lastDrag = value
            self:SetZoom(value)
        end
    end

    local value = self.dragging and self.lastDrag or (pz:GetCurrentNormalizedZoom() or 0)
    local width = self.track:GetWidth()
    local x = zo_floor(value * width)
    self.thumb:ClearAnchors()
    self.thumb:SetAnchor(CENTER, self.track, LEFT, x, 0)
    self.fill:SetWidth(zo_max(1, x))

    if pz.CanZoomOutFurther then self.minus:SetEnabled(pz:CanZoomOutFurther() ~= false) end
    if pz.CanZoomInFurther then self.plus:SetEnabled(pz:CanZoomInFurther() ~= false) end
end

---------------------------------------------------------------------------
-- Из XML
---------------------------------------------------------------------------
function ZoomBar:Step(amount)
    local pz = GetPanAndZoom()
    if not pz then return end
    PlaySound(amount > 0 and SOUNDS.MAP_ZOOM_IN or SOUNDS.MAP_ZOOM_OUT)
    pz:Step(amount)
end

function ZoomBar:OnWheel(delta)
    if delta > 0 then self:Step(1) elseif delta < 0 then self:Step(-1) end
end

function ZoomBar:OnTrackDown(button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    self.dragging = true
    self.lastDrag = nil
    PlaySound(SOUNDS.MAP_ZOOM_LEVEL_CLICKED or SOUNDS.DEFAULT_CLICK)
end

function ZoomBar:OnTrackUp(button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if self.dragging then
        self:SetZoom(self:GetValueFromMouse())
    end
    self.dragging = false
    self.lastDrag = nil
end

function ZoomBar:OnThumbEnter()
    self.thumb:SetTexture("EsoUI/Art/Buttons/smoothSliderButton_over.dds")
end

function ZoomBar:OnThumbExit()
    self.thumb:SetTexture("EsoUI/Art/Buttons/smoothSliderButton_up.dds")
end
