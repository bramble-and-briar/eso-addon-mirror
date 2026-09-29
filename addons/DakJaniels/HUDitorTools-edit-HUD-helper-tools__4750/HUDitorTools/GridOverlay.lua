-- -----------------------------------------------------------------------------
-- HUDitorTools - grid overlay (adapted from LuiExtended GridOverlay)
-- Pooled CT_LINE lattice for the HUD editor. Style is factory/color-only;
-- rebuilds skip when size is unchanged; hide keeps the pool for the next show.
-- -----------------------------------------------------------------------------

local HT = HUDitorTools

local DEFAULT_GRID_SIZE = 15
local OVERLAY_CONTROL_NAME = "HUDitorTools_GridSnap_Overlay"
local LINE_TEMPLATE_V = "HUDitorTools_GridSnap_Overlay_Line_V"
local LINE_TEMPLATE_H = "HUDitorTools_GridSnap_Overlay_Line_H"
local EDITOR_SCENE_NAME = "hud_editor_keyboard"
local GRID_SIZE_SLIDER_UPDATE_NAME = HT.eventName .. "_GridSizeSlider"
local SCREEN_RESIZE_EVENT_NAME = HT.eventName .. "_GridOverlay"
local GRID_SIZE_SLIDER_DEBOUNCE_MS = 50

local windowManager = GetWindowManager()
local eventManager = GetEventManager()
local sceneManager = SCENE_MANAGER
local zo_floor = zo_floor
local zo_round = zo_round

local function ResetLine(line)
    line:ClearAnchors()
    line:SetHidden(true)
end

local function FormatUiLayoutMeasurement(layoutValue)
    return string.format("%dui", zo_round(layoutValue))
end

local function ApplyLineStyle(line)
    line:SetDrawLayer(DL_BACKGROUND)
    line:SetDrawTier(DT_LOW)
    line:SetDrawLevel(2)
    local color = HT.SV.gridColor
    line:SetColor(color.r, color.g, color.b, color.a)
    line:SetThickness("1px")
    line:SetPixelRoundingEnabled(true)
end

local Overlay = ZO_DeferredInitializingObject:Subclass()

function Overlay:Initialize(fragment, control)
    ZO_DeferredInitializingObject.Initialize(self, fragment)
    self.control = control
    self.fragment = fragment
    self.size = DEFAULT_GRID_SIZE
    self.lastGridSize = nil
    self.lastRootWidth = nil
    self.lastRootHeight = nil
    self:OnDeferredInitialize()
end

function Overlay:OnDeferredInitialize()
    local parentControl = self.control
    local function verticalLineFactory(objectPool, objectKey)
        return ZO_ObjectPool_CreateControl(LINE_TEMPLATE_V, objectPool, parentControl)
    end
    local function horizontalLineFactory(objectPool, objectKey)
        return ZO_ObjectPool_CreateControl(LINE_TEMPLATE_H, objectPool, parentControl)
    end
    self.verticalPool = ZO_ObjectPool:New(verticalLineFactory, ResetLine)
    self.verticalPool:SetCustomFactoryBehavior(ApplyLineStyle)
    self.verticalPool:SetCustomAcquireBehavior(function (line)
        line:SetHidden(false)
    end)

    self.horizontalPool = ZO_ObjectPool:New(horizontalLineFactory, ResetLine)
    self.horizontalPool:SetCustomFactoryBehavior(ApplyLineStyle)
    self.horizontalPool:SetCustomAcquireBehavior(function (line)
        line:SetHidden(false)
    end)
end

function Overlay:AddFragmentToEditorScene()
    local scene = sceneManager:GetScene(EDITOR_SCENE_NAME)
    if not scene:HasFragment(self.fragment) then
        scene:AddFragment(self.fragment)
    end
end

function Overlay:RemoveFragmentFromEditorScene()
    sceneManager:GetScene(EDITOR_SCENE_NAME):RemoveFragment(self.fragment)
end

function Overlay:OnShowing()
    self:UpdateLines(self.size)
end

function Overlay:AcquireLine(objectPool, objectKey)
    return select(1, objectPool:AcquireObject(objectKey))
end

function Overlay:ReleaseUnused(objectPool, maxRetainedKey)
    local activeObjects = objectPool:GetActiveObjects()
    for objectKey in pairs(activeObjects) do
        if objectKey > maxRetainedKey then
            objectPool:ReleaseObject(objectKey)
        end
    end
end

function Overlay:UpdateLines(gridSize)
    if not self.control or not gridSize or gridSize <= 0 then
        return
    end
    local canvasWidth, canvasHeight = self.control:GetDimensions()
    canvasWidth = canvasWidth or 0
    canvasHeight = canvasHeight or 0
    if self.lastGridSize == gridSize and self.lastRootWidth == canvasWidth and self.lastRootHeight == canvasHeight then
        return
    end
    self.lastGridSize = gridSize
    self.lastRootWidth = canvasWidth
    self.lastRootHeight = canvasHeight

    local layoutOffsetZero = FormatUiLayoutMeasurement(0)
    local verticalLineCount = zo_floor(canvasWidth / gridSize)
    for lineIndex = 0, verticalLineCount do
        local offsetX = zo_round(lineIndex * gridSize)
        local layoutOffsetX = FormatUiLayoutMeasurement(offsetX)
        local line = self:AcquireLine(self.verticalPool, lineIndex)
        line:ClearAnchors()
        line:SetAnchor(TOPLEFT, self.control, TOPLEFT, layoutOffsetX, layoutOffsetZero)
        line:SetAnchor(BOTTOMLEFT, self.control, BOTTOMLEFT, layoutOffsetX, layoutOffsetZero)
    end
    self:ReleaseUnused(self.verticalPool, verticalLineCount)

    local horizontalLineCount = zo_floor(canvasHeight / gridSize)
    for lineIndex = 0, horizontalLineCount do
        local offsetY = zo_round(lineIndex * gridSize)
        local layoutOffsetY = FormatUiLayoutMeasurement(offsetY)
        local line = self:AcquireLine(self.horizontalPool, lineIndex)
        line:ClearAnchors()
        line:SetAnchor(TOPLEFT, self.control, TOPLEFT, layoutOffsetZero, layoutOffsetY)
        line:SetAnchor(TOPRIGHT, self.control, TOPRIGHT, layoutOffsetZero, layoutOffsetY)
    end
    self:ReleaseUnused(self.horizontalPool, horizontalLineCount)
end

function Overlay:ApplyColorToActiveLines()
    local function restylePool(objectPool)
        local activeObjects = objectPool:GetActiveObjects()
        for _, line in pairs(activeObjects) do
            ApplyLineStyle(line)
        end
    end
    restylePool(self.verticalPool)
    restylePool(self.horizontalPool)
end

function Overlay:Hide()
    eventManager:UnregisterForUpdate(GRID_SIZE_SLIDER_UPDATE_NAME)
    -- Keep pooled Line controls; parent hide is enough while toggling in-scene
    -- or leaving the editor. Fragment is removed so scene Show cannot unhide it
    -- when showGrid is false.
    self:RemoveFragmentFromEditorScene()
    self.control:SetHidden(true)
end

function Overlay:Refresh(visible, size)
    self.size = size
    if not visible then
        self:Hide()
        return
    end
    self:AddFragmentToEditorScene()
    self.control:SetHidden(false)
    self:UpdateLines(self.size)
end

local sharedOverlay
local screenResizeRegistered = false

local function GetOverlay()
    if not sharedOverlay then
        local control = windowManager:GetControlByName(OVERLAY_CONTROL_NAME)
        control:SetAnchorFill(GuiRoot)
        control:SetDrawLayer(DL_BACKGROUND)
        control:SetDrawTier(DT_LOW)
        control:SetDrawLevel(0)
        control:SetAlpha(1)
        control:SetMouseEnabled(false)
        control:SetMovable(false)
        control:SetHidden(true)
        control:SetClampedToScreen(false)
        sharedOverlay = Overlay:New(ZO_SimpleSceneFragment:New(control), control)
    end
    if not screenResizeRegistered then
        eventManager:RegisterForEvent(SCREEN_RESIZE_EVENT_NAME, EVENT_SCREEN_RESIZED, function ()
            HT.RefreshGridOverlay()
        end)
        screenResizeRegistered = true
    end
    return sharedOverlay
end

function HT.RefreshGridOverlay()
    local sv = HT.SV
    GetOverlay():Refresh(HT.IsEditorShowing() and sv.showGrid, sv.gridSize)
end

function HT.RefreshGridOverlayDebounced()
    eventManager:UnregisterForUpdate(GRID_SIZE_SLIDER_UPDATE_NAME)
    local DO_ONCE = true
    eventManager:RegisterForUpdate(GRID_SIZE_SLIDER_UPDATE_NAME, GRID_SIZE_SLIDER_DEBOUNCE_MS, function ()
                                       HT.RefreshGridOverlay()
                                   end, DO_ONCE)
end

function HT.HideGridOverlay()
    GetOverlay():Hide()
end

function HT.RefreshGridOverlayColors()
    if not sharedOverlay then
        return
    end
    sharedOverlay:ApplyColorToActiveLines()
end
