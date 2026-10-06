-- =========================================================================
-- ИНТЕГРАЦИЯ С HARVESTMAP ДЛЯ МИНИКАРТЫ NECROCAT (ФИНАЛЬНЫЙ АДАПТЕР)
-- =========================================================================

NecroCat = NecroCat or {}
NecroCat.Minimap = NecroCat.Minimap or {}

local minimap = NecroCat.Minimap

local NECROCAT_MODE = {}
local g_pinTypeManagerClass = nil

-- 1. Расчет положения метки без вращения
local function DefaultUpdateLocation(self, pinIndex)
    local x, y = self.mapCache:GetLocal(self.nodeId[pinIndex])
    local mapWidth = Harvest.pinController.MAP_WIDTH or 1000
    self.composite:SetInsets(pinIndex, x * mapWidth, x * mapWidth, y * mapWidth, y * mapWidth)
end

-- 2. Расчет положения метки при вращении
local function RotatedUpdateLocation(self, pinIndex)
    local x, y = self.mapCache:GetLocal(self.nodeId[pinIndex])
    local mapWidth = Harvest.pinController.MAP_WIDTH or 1000
    
    local rawX = (x * mapWidth) - NECROCAT_MODE.offsetX
    local rawY = (y * mapWidth) - NECROCAT_MODE.offsetY

    local rotatedX = (NECROCAT_MODE.cos * rawX) - (NECROCAT_MODE.sin * rawY)
    local rotatedY = (NECROCAT_MODE.sin * rawX) + (NECROCAT_MODE.cos * rawY)

    self.composite:SetInsets(pinIndex, rotatedX, rotatedX, rotatedY, rotatedY)
end

-- 3. Режим NecroCat для HarvestMap
NECROCAT_MODE = {
    cos = 1,
    sin = 0,
    offsetX = 0,
    offsetY = 0,

    Activate = function(self)
        self:UpdateContainerAnchor()
    end,

    UpdateContainerAnchor = function(self)
        local PinController = Harvest.pinController
        if not PinController or not PinController.container then return end

        local cfg = minimap.settings
        local doesRotate = cfg and cfg.rotate

        PinController.container:ClearAnchors()

        if doesRotate then
            PinController.container:SetParent(NecroCat_Minimap_MainWindow_Map_Scroll)
            PinController.container:SetAnchor(CENTER, NecroCat_Minimap_MainWindow_Map_Scroll, CENTER, 0, 0)
            if g_pinTypeManagerClass then
                g_pinTypeManagerClass.UpdateLocationOfPinWithIndex = RotatedUpdateLocation
            end
        else
            PinController.container:SetParent(NecroCat_MapContainer)
            PinController.container:SetAnchor(TOPLEFT, NecroCat_MapContainer, TOPLEFT, 0, 0)
            if g_pinTypeManagerClass then
                g_pinTypeManagerClass.UpdateLocationOfPinWithIndex = DefaultUpdateLocation
            end
        end
    end,

    GetDimensions = function(self)
        if NecroCat_MapContainer then
            return NecroCat_MapContainer:GetDimensions()
        end
        return 1000, 1000
    end,
}

local function ApplyHarvestRefresh()
    if not (minimap.settings and minimap.settings.enabled) then return end
    if ZO_WorldMap_IsWorldMapShowing() then return end
    if not Harvest or not Harvest.pinController then return end

    NECROCAT_MODE:UpdateContainerAnchor()

    local w, h = NecroCat_MapContainer:GetDimensions()
    if w and w > 0 then
        Harvest.pinController:OnMapSizeChange(w, h)
        if Harvest.mapPins and Harvest.mapPins.RedrawPins then
            Harvest.mapPins:RedrawPins()
        end
    end
end

local function InitializeHarvestIntegration()
    if not Harvest or not Harvest.pinController or not Harvest.mapMode then return end

    -- 1. Ссылка на базовый класс рендера иконок
    local sampleManager = select(2, next(Harvest.pinController.pinTypeManagers))
    if sampleManager then
        g_pinTypeManagerClass = getmetatable(sampleManager)
    end

    -- 2. ЧЕСТНО возвращаем true вместо использования ZO_PreHook (лечит проблему двух настроек!)
    local origIsInMinimapMode = Harvest.mapMode.IsInMinimapMode
    Harvest.mapMode.IsInMinimapMode = function(self, ...)
        if not ZO_WorldMap_IsWorldMapShowing() and minimap.settings and minimap.settings.enabled then
            return true
        end
        return origIsInMinimapMode(self, ...)
    end

    -- 3. Подменяем CheckMapMode прямым перехватом
    local origCheckMapMode = Harvest.pinController.CheckMapMode
    Harvest.pinController.CheckMapMode = function(self, ...)
        if not ZO_WorldMap_IsWorldMapShowing() and minimap.settings and minimap.settings.enabled then
            self:SetMode(NECROCAT_MODE)
            NECROCAT_MODE:UpdateContainerAnchor()
            return
        end
        return origCheckMapMode(self, ...)
    end

    -- 4. Подключаем слушатели к миникарте NecroCat
    if minimap.Pins then
        ZO_PostHook(minimap.Pins, "RefreshAll", function()
            ApplyHarvestRefresh()
        end)

        ZO_PostHook(minimap.Pins, "UpdateRotation", function(playerX, playerY, cosVal, sinVal, containerSize)
            if not (minimap.settings and minimap.settings.enabled and minimap.settings.rotate) then return end
            if ZO_WorldMap_IsWorldMapShowing() then return end

            NECROCAT_MODE.cos = cosVal
            NECROCAT_MODE.sin = sinVal
            NECROCAT_MODE.offsetX = playerX
            NECROCAT_MODE.offsetY = playerY

            for pinTypeId, pinManager in pairs(Harvest.pinController.pinTypeManagers) do
                for pinIndex, _ in pairs(pinManager.nodeId) do
                    RotatedUpdateLocation(pinManager, pinIndex)
                end
            end
        end)
    end

    -- 5. Принудительно применяем режим прямо сейчас
    Harvest.mapMode:CheckModeAndNotifty()
    Harvest.pinController:CheckMapMode()
    ApplyHarvestRefresh()
end

-- Моментальная инициализация при загрузке и при смене персонажа
EVENT_MANAGER:RegisterForEvent("NecroCat_HarvestMap_Init", EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent("NecroCat_HarvestMap_Init", EVENT_PLAYER_ACTIVATED)
    InitializeHarvestIntegration()
end)