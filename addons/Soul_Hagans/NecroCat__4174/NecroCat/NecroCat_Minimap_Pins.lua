NecroCat = NecroCat or {}
NecroCat.Minimap = NecroCat.Minimap or {}
NecroCat.Minimap.Pins = {}

local minimap = NecroCat.Minimap
local pins = minimap.Pins

local g_pinPool = {}
local g_activePins = {}
local g_pinIndex = 0

local g_groupPins = {}
local g_bgObjectivePins = {}
local g_customPinsList = {}

local g_currentPinZoneId = 0
local g_currentPinMapTile = ""
local g_isPlayerActivated = false

-- Выделенные контролы-одиночки для системных меток (никогда не двоятся)
local g_waypointControl = nil
local g_rallyControl = nil
local g_pingControls = {}

local function ClearOldZonePins()
    local currentZone = select(1, GetUnitWorldPosition("player")) or 0
    local currentMapTile = GetMapTileTexture and GetMapTileTexture(1) or ""

    if g_currentPinZoneId ~= currentZone or (currentMapTile ~= "" and g_currentPinMapTile ~= currentMapTile) then
        g_currentPinZoneId = currentZone
        g_currentPinMapTile = currentMapTile
        g_customPinsList = {}
    end
end

-- =========================================================================
-- 1. НЕУБИВАЕМЫЙ ПУЛ ОБЪЕКТОВ
-- =========================================================================
local function AcquirePin()
    g_pinIndex = g_pinIndex + 1
    local pin = g_pinPool[g_pinIndex]
    
    if not pin then
        pin = CreateControl("NCMM_MapPin_" .. g_pinIndex, NecroCat_MapContainer, CT_TEXTURE)
        pin:SetDimensions(20, 20)
        pin:SetDrawTier(DT_MEDIUM)
        pin:SetDrawLayer(DL_OVERLAY)
        pin:SetDrawLevel(2)
        pin:SetMouseEnabled(true)
        
        pin:SetHandler("OnMouseEnter", function(self)
            if self.pinTooltipCreator then
                InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
                if type(self.pinTooltipCreator) == "function" then
                    pcall(self.pinTooltipCreator, self)
                elseif type(self.pinTooltipCreator) == "string" and self.pinTooltipCreator ~= "" then
                    SetTooltipText(InformationTooltip, self.pinTooltipCreator)
                elseif type(self.pinTooltipCreator) == "number" then
                    SetTooltipText(InformationTooltip, GetString(self.pinTooltipCreator))
                end
            elseif self.pinText and self.pinText ~= "" then
                InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
                SetTooltipText(InformationTooltip, self.pinText)
            end
        end)
        
        pin:SetHandler("OnMouseExit", function(self)
            ClearTooltip(InformationTooltip)
        end)
        
        table.insert(g_pinPool, pin)
    end
    
    pin:SetHidden(false)
    table.insert(g_activePins, pin)
    return pin
end

function pins.Reset()
    ClearOldZonePins()
    for _, pin in ipairs(g_activePins) do
        pin:SetHidden(true)
        pin:ClearAnchors()
        pin:SetColor(1, 1, 1, 1)
        pin.pinText = nil
        pin.pinTooltipCreator = nil
        pin.normX = nil
        pin.normY = nil
        pin.m_PinType = nil
        pin.m_PinTag = nil
        pin.isQuestPin = nil
        pin.isAreaPin = nil
    end
    for _, pin in pairs(g_bgObjectivePins) do
        pin:SetHidden(true)
    end
    for _, pin in pairs(g_groupPins) do
        pin:SetHidden(true)
    end
    ZO_ClearTable(g_activePins)
    g_pinIndex = 0
end

local function GetIconPriority(tex)
    if not tex or type(tex) ~= "string" then return 0 end
    local s = string.lower(tex)
    -- Плотные сервисные значки, ключи карты и наковальни имеют высший приоритет (3)
    if string.find(s, "servicepin") or string.find(s, "mapkey") or string.find(s, "craft") then
        return 3
    end
    -- Полупрозрачные блеклые POI пергамента карты ZOS имеют низкий приоритет (1)
    if string.find(s, "/poi/") or string.find(s, "poi_") then
        return 1
    end
    return 2
end

-- =========================================================================
-- 2. СОЗДАНИЕ И ВРАЩЕНИЕ МЕТОК
-- =========================================================================
function pins.CreatePin(iconTexture, normX, normY, text, size, tooltipCreator, pinType, pinTag, tint, drawLayer, drawLevel)
    if not normX or not normY or normX <= 0 or normY <= 0 or normX >= 1 or normY >= 1 then return end
    
    if type(iconTexture) == "table" then
        iconTexture = iconTexture.texture or iconTexture.icon or iconTexture[1]
    end
    if not iconTexture or type(iconTexture) ~= "string" or iconTexture == "" then return end

    local pin = nil
    local isArea = (string.find(tostring(iconTexture), "areaPin") ~= nil or string.find(tostring(iconTexture), "AreaPin") ~= nil)
    
    for _, existingPin in ipairs(g_activePins) do
        if existingPin.normX and existingPin.normY then
            -- Если координаты почти идентичны (в пределах 0.0012)
            if math.abs(existingPin.normX - normX) < 0.0012 and math.abs(existingPin.normY - normY) < 0.0012 then
                -- Не склеиваем квесты и зоны поиска
                if existingPin.isAreaPin == isArea and not existingPin.isQuestPin then
                    if existingPin.m_PinType == pinType or (not existingPin.isQuestPin and not isArea) then
                        pin = existingPin
                        break
                    end
                end
            end
        end
    end

    -- Если метка в этой точке уже есть — применяем правило плотного приоритета
    if pin then
        local currentPrio = GetIconPriority(pin.currentIconTexture)
        local newPrio = GetIconPriority(iconTexture)
        
        -- Повышаем качество текстуры, если новая плотнее и ярче
        if newPrio >= currentPrio then
            pin:SetTexture(iconTexture)
            pin.currentIconTexture = iconTexture
        end
        if text and text ~= "" then pin.pinText = text end
        if tooltipCreator then pin.pinTooltipCreator = tooltipCreator end
        return pin
    end

    pin = AcquirePin()
    
    local userBaseSize = (minimap.settings and minimap.settings.pinSize) or 20
    local rawSize = size or 20
    local finalPinSize

    if isArea then
        finalPinSize = rawSize
        pin.isAreaPin = true
    else
        finalPinSize = zo_round(rawSize * (userBaseSize / 20))
        pin.isAreaPin = false
    end
    
    pin:SetDimensions(finalPinSize, finalPinSize)
    pin:SetTexture(iconTexture)
    pin.currentIconTexture = iconTexture
    pin.pinText = text
    pin.pinTooltipCreator = tooltipCreator
    pin.normX = normX
    pin.normY = normY
    pin.m_PinType = pinType
    pin.m_PinTag = pinTag

    if drawLayer then pin:SetDrawLayer(drawLayer) else pin:SetDrawLayer(DL_OVERLAY) end
    if drawLevel then pin:SetDrawLevel(drawLevel) else pin:SetDrawLevel(pin.isAreaPin and 1 or 2) end

    if tint then
        if type(tint) == "table" and tint.UnpackRGBA then
            pin:SetColor(tint:UnpackRGBA())
        elseif type(tint) == "table" and tint.r and tint.g and tint.b then
            pin:SetColor(tint.r, tint.g, tint.b, tint.a or 1)
        elseif type(tint) == "table" and tint[1] and tint[2] and tint[3] then
            pin:SetColor(tint[1], tint[2], tint[3], tint[4] or 1)
        else
            pin:SetColor(1, 1, 1, 1)
        end
    else
        pin:SetColor(1, 1, 1, 1)
    end

    local containerSize = NecroCat_MapContainer:GetWidth()
    local cfg = minimap.settings
    local doesRotate = cfg and cfg.rotate

    pin:ClearAnchors()
    if doesRotate then
        local pNormX, pNormY = GetMapPlayerPosition("player")
        local playerX = (pNormX or 0) * containerSize
        local playerY = (pNormY or 0) * containerSize
        local heading = GetPlayerCameraHeading() or 0
        local cosH = math.cos(heading)
        local sinH = math.sin(heading)

        local ix = (normX * containerSize) - playerX
        local iy = (normY * containerSize) - playerY
        local rx = (cosH * ix) - (sinH * iy)
        local ry = (sinH * ix) + (cosH * iy)
        pin:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round(rx), zo_round(ry))
    else
        local posX = normX * containerSize
        local posY = normY * containerSize
        pin:SetAnchor(CENTER, NecroCat_MapContainer, TOPLEFT, posX, posY)
    end
    return pin
end

function pins.UpdateRotation(playerX, playerY, cosHeading, sinHeading, containerSize)
    for _, pin in ipairs(g_activePins) do
        if pin.normX and pin.normY then
            local ix = (pin.normX * containerSize) - playerX
            local iy = (pin.normY * containerSize) - playerY
            
            local rx = (cosHeading * ix) - (sinHeading * iy)
            local ry = (sinHeading * ix) + (cosHeading * iy)
            
            pin:ClearAnchors()
            pin:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round(rx), zo_round(ry))
        end
    end

    if g_waypointControl and not g_waypointControl:IsHidden() and g_waypointControl.normX then
        local ix = (g_waypointControl.normX * containerSize) - playerX
        local iy = (g_waypointControl.normY * containerSize) - playerY
        g_waypointControl:ClearAnchors()
        g_waypointControl:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round((cosHeading * ix) - (sinHeading * iy)), zo_round((sinHeading * ix) + (cosHeading * iy)))
    end

    if g_rallyControl and not g_rallyControl:IsHidden() and g_rallyControl.normX then
        local ix = (g_rallyControl.normX * containerSize) - playerX
        local iy = (g_rallyControl.normY * containerSize) - playerY
        g_rallyControl:ClearAnchors()
        g_rallyControl:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round((cosHeading * ix) - (sinHeading * iy)), zo_round((sinHeading * ix) + (cosHeading * iy)))
    end

    for _, pingCtrl in pairs(g_pingControls) do
        if pingCtrl and not pingCtrl:IsHidden() and pingCtrl.normX then
            local ix = (pingCtrl.normX * containerSize) - playerX
            local iy = (pingCtrl.normY * containerSize) - playerY
            pingCtrl:ClearAnchors()
            pingCtrl:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round((cosHeading * ix) - (sinHeading * iy)), zo_round((sinHeading * ix) + (cosHeading * iy)))
        end
    end
end

-- =========================================================================
-- 3. СИСТЕМНЫЕ МЕТКИ (Путевые точки F, Ралли, Пинги — Синглтоны)
-- =========================================================================
function pins.RefreshWaypoints()
    local containerSize = NecroCat_MapContainer:GetWidth()
    local doesRotate = minimap.settings and minimap.settings.rotate

    local wpX, wpY = GetMapPlayerWaypoint()
    if wpX and wpY and wpX > 0 and wpY > 0 and wpX < 1 and wpY < 1 then
        if not g_waypointControl then
            g_waypointControl = CreateControl("NCMM_WaypointPin", NecroCat_MapContainer, CT_TEXTURE)
            g_waypointControl:SetDimensions(28, 28)
            g_waypointControl:SetTexture("EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination.dds")
            g_waypointControl:SetDrawTier(DT_HIGH)
            g_waypointControl:SetDrawLayer(DL_OVERLAY)
            g_waypointControl:SetDrawLevel(25)
            g_waypointControl:SetMouseEnabled(true)
            g_waypointControl:SetHandler("OnMouseEnter", function(self)
                InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
                SetTooltipText(InformationTooltip, "|c00ffffМетка назначения (F)|r")
            end)
            g_waypointControl:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        end
        g_waypointControl.normX = wpX
        g_waypointControl.normY = wpY
        g_waypointControl:SetHidden(false)
        if not doesRotate then
            g_waypointControl:ClearAnchors()
            g_waypointControl:SetAnchor(CENTER, NecroCat_MapContainer, TOPLEFT, wpX * containerSize, wpY * containerSize)
        end
    else
        if g_waypointControl then
            g_waypointControl:SetHidden(true)
            g_waypointControl.normX = nil
            g_waypointControl.normY = nil
        end
    end

    local rallyX, rallyY = GetMapRallyPoint()
    if rallyX and rallyY and rallyX > 0 and rallyY > 0 and rallyX < 1 and rallyY < 1 then
        if not g_rallyControl then
            g_rallyControl = CreateControl("NCMM_RallyPin", NecroCat_MapContainer, CT_TEXTURE)
            g_rallyControl:SetDimensions(30, 30)
            g_rallyControl:SetTexture("EsoUI/Art/MapPins/MapRallyPoint.dds")
            g_rallyControl:SetDrawTier(DT_HIGH)
            g_rallyControl:SetDrawLayer(DL_OVERLAY)
            g_rallyControl:SetDrawLevel(25)
            g_rallyControl:SetMouseEnabled(true)
            g_rallyControl:SetHandler("OnMouseEnter", function(self)
                InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
                SetTooltipText(InformationTooltip, "|cff3333Точка сбора лидера (Rally)|r")
            end)
            g_rallyControl:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        end
        g_rallyControl.normX = rallyX
        g_rallyControl.normY = rallyY
        g_rallyControl:SetHidden(false)
        if not doesRotate then
            g_rallyControl:ClearAnchors()
            g_rallyControl:SetAnchor(CENTER, NecroCat_MapContainer, TOPLEFT, rallyX * containerSize, rallyY * containerSize)
        end
    else
        if g_rallyControl then
            g_rallyControl:SetHidden(true)
            g_rallyControl.normX = nil
            g_rallyControl.normY = nil
        end
    end

    local pingIcon = "EsoUI/Art/MapPins/MapPing.dds"
    local function UpdateSinglePing(unitTag, isLeader, name)
        local px, py = GetMapPing(unitTag)
        local pingCtrl = g_pingControls[unitTag]
        if px and py and px > 0 and py > 0 and px < 1 and py < 1 then
            if not pingCtrl then
                pingCtrl = CreateControl("NCMM_PingPin_" .. unitTag, NecroCat_MapContainer, CT_TEXTURE)
                pingCtrl:SetDimensions(28, 28)
                pingCtrl:SetTexture(pingIcon)
                pingCtrl:SetDrawTier(DT_HIGH)
                pingCtrl:SetDrawLayer(DL_OVERLAY)
                pingCtrl:SetDrawLevel(25)
                pingCtrl:SetMouseEnabled(true)
                pingCtrl:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
                g_pingControls[unitTag] = pingCtrl
            end
            pingCtrl.normX = px
            pingCtrl.normY = py
            local text = isLeader and ("|cff3333Пинг лидера (" .. name .. ")|r") or ("|cffff00Пинг: " .. name .. "|r")
            pingCtrl:SetHandler("OnMouseEnter", function(self)
                InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
                SetTooltipText(InformationTooltip, text)
            end)
            pingCtrl:SetHidden(false)
            if not doesRotate then
                pingCtrl:ClearAnchors()
                pingCtrl:SetAnchor(CENTER, NecroCat_MapContainer, TOPLEFT, px * containerSize, py * containerSize)
            end
        else
            if pingCtrl then
                pingCtrl:SetHidden(true)
                pingCtrl.normX = nil
                pingCtrl.normY = nil
            end
        end
    end

    if IsUnitGrouped("player") then
        local groupSize = GetGroupSize()
        for i = 1, groupSize do
            local unitTag = GetGroupUnitTagByIndex(i)
            if DoesUnitExist(unitTag) then
                UpdateSinglePing(unitTag, IsUnitGroupLeader(unitTag), GetUnitName(unitTag))
            end
        end
    else
        UpdateSinglePing("player", false, "Карта")
    end
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_MapPingEvent", EVENT_MAP_PING, function(_, pingEventType, pinType, _, x, y)
    if pins.RefreshWaypoints then
        pins.RefreshWaypoints()
    end
end)

-- =========================================================================
-- 4. СТАТИЧЕСКИЕ ИГРОВЫЕ МЕТКИ
-- =========================================================================
function pins.RefreshWayshrines()
    if IsInAvAZone and IsInAvAZone() then return end

    local numNodes = GetNumFastTravelNodes()
    for nodeIndex = 1, numNodes do
        local known, name, normX, normY, icon, _, poiType, isLocatedInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        -- Рисуем ТОЛЬКО настоящие дорожные святилища (тип 1), не трогая данжи, триалы и дома
        if known and isLocatedInCurrentMap and normX > 0 and normY > 0 and (poiType == 1 or poiType == POI_TYPE_WAYSHRINE) then
            pins.CreatePin(icon, normX, normY, name, 24, nil, MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE)
        end
    end
end

function pins.RefreshLocations()
    if GetMapContentType() == MAP_CONTENT_DUNGEON or GetCurrentZoneHouseId() ~= 0 then return end

    local numLocations = GetNumMapLocations and GetNumMapLocations() or 0
    for i = 1, numLocations do
        if IsMapLocationVisible(i) then
            local icon, normX, normY = GetMapLocationIcon(i)
            if icon and icon ~= "" and normX > 0 and normY > 0 then
                local name = GetMapLocationTooltipHeader(i)
                pins.CreatePin(icon, normX, normY, name, 20)
            end
        end
    end
end

function pins.RefreshPOIs()
    if GetMapContentType() == MAP_CONTENT_DUNGEON or GetCurrentZoneHouseId() ~= 0 then return end

    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex or zoneIndex > 100000 then return end

    local numPOIs = GetNumPOIs(zoneIndex)
    for i = 1, numPOIs do
        local xLoc, zLoc, poiPinType, icon = GetPOIMapInfo(zoneIndex, i)
        local poiType = GetPOIType(zoneIndex, i)
        local isDuplicate = (poiType == POI_TYPE_WAYSHRINE or poiType == POI_TYPE_HOUSE)

        if (not icon or icon == "") and poiPinType and ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[poiPinType] then
            local layout = ZO_MapPin.PIN_DATA[poiPinType]
            local tex = layout.texture
            if type(tex) == "function" then
                local ok, res = pcall(tex, { m_PinType = poiPinType })
                if ok and type(res) == "string" then icon = res end
            elseif type(tex) == "string" then
                icon = tex
            end
        end

        if not isDuplicate and icon and icon ~= "" and xLoc > 0 and zLoc > 0 and xLoc < 1 and zLoc < 1 then
            local poiName = GetPOIInfo(zoneIndex, i)
            pins.CreatePin(icon, xLoc, zLoc, poiName, 22, nil, poiPinType)
        end
    end
end

function pins.RefreshSkyshards()
    if GetCurrentZoneHouseId() ~= 0 then return end

    local lmp = LibMapPins
    local showUncollected = false
    local showCollected = false

    if lmp and lmp.IsEnabled then
        for pinType, _ in pairs(lmp.filters or {}) do
            local layout = ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType]
            local icon = layout and (layout.texture or layout[1])
            local iconStr = type(icon) == "string" and string.lower(icon) or ""
            local pinTypeStr = string.lower(tostring(pinType))

            if string.find(pinTypeStr, "sky") or string.find(iconStr, "skyshard") then
                if lmp:IsEnabled(pinType) then
                    if string.find(iconStr, "complete") then showCollected = true else showUncollected = true end
                end
            end
        end
    else
        showUncollected = true
    end

    if not showUncollected and not showCollected then return end

    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex or zoneIndex > 100000 then return end

    local zoneId = GetZoneId(zoneIndex)
    if not zoneId or zoneId == 0 then
        zoneId = select(1, GetUnitWorldPosition("player")) or 0
    end
    if not zoneId or zoneId == 0 or not GetNumSkyshardsInZone then return end

    local numSkyshards = GetNumSkyshardsInZone(zoneId)
    if not numSkyshards or numSkyshards == 0 then return end

    for i = 1, numSkyshards do
        local skyshardId = GetZoneSkyshardId(zoneId, i)
        if skyshardId and skyshardId > 0 then
            local normX, normY = GetNormalizedPositionForSkyshardId(skyshardId)
            if normX and normY and normX > 0 and normY > 0 and normX < 1 and normY < 1 then
                local status = GetSkyshardDiscoveryStatus(skyshardId)
                local isAcquired = (status == SKYSHARD_DISCOVERY_STATUS_ACQUIRED)

                if isAcquired and showCollected then
                    pins.CreatePin("EsoUI/Art/Icons/MapKey/mapkey_skyshard_complete.dds", normX, normY, "|c00ff00Собранный небесный осколок|r", 18)
                elseif not isAcquired and showUncollected then
                    pins.CreatePin("EsoUI/Art/Icons/MapKey/mapkey_skyshard_seen.dds", normX, normY, "|c66f2ffНебесный осколок|r", 20)
                end
            end
        end
    end
end

-- =========================================================================
-- 5. КВЕСТЫ И ЗОНЫ ПОИСКА (Area Pins)
-- =========================================================================
function pins.RefreshQuests()
    local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
    if not pinManager or not pinManager.m_Active then return end

    local containerSize = NecroCat_MapContainer:GetWidth()

    for _, mapPin in pairs(pinManager.m_Active) do
        if type(mapPin) == "table" and mapPin.IsQuest and mapPin:IsQuest() then
            local x, y = mapPin:GetNormalizedPosition()
            if not x or not y then
                x = mapPin.normalizedX
                y = mapPin.normalizedY
            end

            if x and y and x > 0 and y > 0 and x < 1 and y < 1 then
                local isAssisted = mapPin.IsAssisted and mapPin:IsAssisted()
                local radius = mapPin.radius or (mapPin.m_PinTag and mapPin.m_PinTag.radius) or (mapPin.GetRadius and mapPin:GetRadius()) or 0
                
                local questName = ""
                local qIndex = mapPin.GetQuestIndex and mapPin:GetQuestIndex()
                if not qIndex and mapPin.m_PinTag and type(mapPin.m_PinTag) == "table" then
                    qIndex = mapPin.m_PinTag[1] or mapPin.m_PinTag.questIndex
                end
                if qIndex and qIndex > 0 then
                    questName = GetJournalQuestName(qIndex)
                end

                if radius and radius > 0 then
                    -- Площадная зона квеста (Area Pin)
                    local areaDiameter = zo_round(radius * 2 * containerSize)
                    local areaIcon = isAssisted and "EsoUI/Art/MapPins/map_assistedAreaPin.dds" or "EsoUI/Art/MapPins/map_areaPin.dds"
                    -- Сочный бирюзовый для активного квеста и яркий чёткий белый контур для остальных
                    local areaTint = isAssisted and ZO_ColorDef:New(0.0, 0.85, 1.0, 0.85) or ZO_ColorDef:New(1.0, 1.0, 1.0, 0.95)
                    local p = pins.CreatePin(areaIcon, x, y, questName ~= "" and ("|cffff66Зона задачи: " .. questName .. "|r") or nil, areaDiameter, nil, mapPin:GetPinType(), nil, areaTint, DL_BACKGROUND, 1)
                    if p then p.isQuestPin = true end
                else
                    -- Точечный маркер квеста
                    local icon = mapPin.GetQuestIcon and mapPin:GetQuestIcon()
                    if not icon or icon == "" then
                        icon = isAssisted and "EsoUI/Art/Compass/quest_assisted_icon.dds" or "EsoUI/Art/Compass/quest_icon.dds"
                    end

                    local p = pins.CreatePin(icon, x, y, questName ~= "" and ("|cffff66" .. questName .. "|r") or nil, 24, nil, mapPin:GetPinType(), nil, nil, DL_OVERLAY, 22)
                    if p then p.isQuestPin = true end
                end
            end
        end
    end
end

-- =========================================================================
-- 5.1. ЗОНЫ ЛОЦИРОВАНИЯ И РАСКОПОК (Реликвии / Antiquities)
-- =========================================================================
function pins.RefreshAntiquities()
    if not GetNumInProgressAntiquities then return end
    local containerSize = NecroCat_MapContainer:GetWidth()
    local numInprogress = GetNumInProgressAntiquities()

    for antiquityIndex = 1, numInprogress do
        local numDigSites = GetNumDigSitesForInProgressAntiquity(antiquityIndex)
        for digSiteIndex = 1, numDigSites do
            local digSiteId = GetInProgressAntiquityDigSiteId(antiquityIndex, digSiteIndex)
            if digSiteId and digSiteId > 0 then
                local centerX, centerZ, isShownInCurrentMap = GetDigSiteNormalizedCenterPosition(digSiteId)
                if isShownInCurrentMap and centerX > 0 and centerZ > 0 and centerX < 1 and centerZ < 1 then
                    local isTracked = IsDigSiteAssociatedWithTrackedAntiquity(digSiteId)
                    local borderPoints = { GetDigSiteNormalizedBorderPoints(digSiteId) }
                    
                    local minX, maxX = 1.0, 0.0
                    local minY, maxY = 1.0, 0.0
                    for p = 1, #borderPoints, 2 do
                        local bx = borderPoints[p]
                        local by = borderPoints[p + 1]
                        if bx and by then
                            minX = math.min(minX, bx)
                            maxX = math.max(maxX, bx)
                            minY = math.min(minY, by)
                            maxY = math.max(maxY, by)
                        end
                    end

                    local blobWidth = (maxX > minX) and (maxX - minX) or 0.08
                    local blobHeight = (maxY > minY) and (maxY - minY) or 0.08
                    local diameter = zo_round(math.max(blobWidth, blobHeight) * containerSize)
                    
                    -- Каноничный сочный бирюзовый цвет как на большой карте
                    local color = ZO_ColorDef:New(0.0, 0.85, 1.0, 0.90)
                    local pinType = isTracked and MAP_PIN_TYPE_TRACKED_ANTIQUITY_DIG_SITE or MAP_PIN_TYPE_ANTIQUITY_DIG_SITE

                    -- 1. Чёткий бирюзовый купол зоны раскопок
                    pins.CreatePin("EsoUI/Art/MapPins/map_areaPin.dds", centerX, centerZ, "|c66f2ffМесто раскопок (Реликвия)|r", diameter, nil, pinType, digSiteId, color, DL_BACKGROUND, 1)

                    -- 2. Значок лопаты по центру
                    pins.CreatePin("EsoUI/Art/Icons/ServiceMapPins/servicepin_antiquities.dds", centerX, centerZ, "|c66f2ffМесто раскопок (Реликвия)|r", 22, nil, pinType, digSiteId, nil, DL_OVERLAY, 16)
                end
            end
        end
    end
end

-- =========================================================================
-- 6. СИРОДИЛ И ПОЛЯ СРАЖЕНИЙ
-- =========================================================================
function pins.RefreshCyrodiil()
    local isAvA = (IsInAvAZone and IsInAvAZone()) or (GetMapContentType() == MAP_CONTENT_AVA)
    if not isAvA then return end

    local bgContext = BGQUERY_LOCAL
    local numKeeps = GetNumKeeps and GetNumKeeps() or 0

    -- 1. Крепости и ресурсы
    for i = 1, numKeeps do
        local keepId = GetKeepKeysByIndex(i)
        if keepId and keepId > 0 then
            local keepName = GetKeepName(keepId)
            local isVault = keepName and (string.find(keepName, "Хранилище") or string.find(keepName, "Vault"))
            local hasArtifact = GetKeepHasArtifact and GetKeepHasArtifact(keepId)

            if not isVault or hasArtifact then
                local pinType, normX, normY = GetKeepPinInfo(keepId, bgContext)
                
                if pinType and pinType ~= MAP_PIN_TYPE_INVALID and normX and normY and normX > 0 and normY > 0 and normX < 1 and normY < 1 then
                    local layout = ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType]
                    local icon = layout and layout.texture
                    if type(icon) == "function" then
                        local ok, res = pcall(icon, { m_PinType = pinType, keepId = keepId })
                        if ok and type(res) == "string" then icon = res else icon = nil end
                    end

                    if icon and icon ~= "" then
                        local keepType = GetKeepType and GetKeepType(keepId)
                        local isResource = (keepType == KEEP_TYPE_RESOURCE)
                        local size = isResource and 22 or 28

                        -- 1. Если замок/ресурс/район в осаде — рисуем аккуратную звезду штурма НА ЗАДНЕМ ПЛАНЕ (слой 10)
                        local isUnderAttack = GetKeepUnderAttack and GetKeepUnderAttack(keepId, bgContext)
                        if isUnderAttack then
                            local burstSize = isResource and 32 or 46
                            pins.CreatePin("EsoUI/Art/MapPins/AvA_attackBurst_64.dds", normX, normY, "|cff3333[В ОСАДЕ] " .. keepName .. "|r", burstSize, nil, "NCMM_KeepUnderAttackBurst", keepId, nil, DL_OVERLAY, 10)
                        end

                        -- 2. Рисуем сам замок/ресурс ПОВЕРХ вспышки на переднем плане (слой 12)
                        pins.CreatePin(icon, normX, normY, keepName, size, nil, pinType, keepId, nil, DL_OVERLAY, 12)
                    end
                end
            end
        end
    end

    -- 2. Осадные палатки (Иконка + Белый купол зоны действия)
    local numForwardCamps = GetNumForwardCamps and GetNumForwardCamps(BGQUERY_LOCAL) or 0
    local playerAlliance = GetUnitAlliance("player")
    local campTint = GetAllianceColor(playerAlliance)
    local containerSize = NecroCat_MapContainer:GetWidth()

    for i = 1, numForwardCamps do
        local pinType, normX, normY, radius, usable = GetForwardCampPinInfo(BGQUERY_LOCAL, i)
        if pinType and normX and normY and normX > 0 and normY > 0 and normX < 1 and normY < 1 then
            if usable and radius and radius > 0 then
                local campDiameter = zo_round(radius * 2 * containerSize)
                pins.CreatePin("EsoUI/Art/MapPins/map_areaPin.dds", normX, normY, "Зона действия лагеря", campDiameter, nil, pinType, nil, ZO_ColorDef:New(1, 1, 1, 0.85), DL_BACKGROUND, 1)
            end

            local layout = ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType]
            local campIcon = layout and layout.texture
            if type(campIcon) == "function" then
                local ok, res = pcall(campIcon, { m_PinType = pinType })
                if ok and type(res) == "string" then campIcon = res else campIcon = nil end
            end

            if campIcon and campIcon ~= "" then
                pins.CreatePin(campIcon, normX, normY, "Полевой лагерь (Палатка)", 30, nil, pinType, nil, campTint, DL_OVERLAY, 15)
            end
        end
    end
end

function pins.RefreshBattleground()
    local isBG = (IsPlayerInBattleground and IsPlayerInBattleground()) 
        or (IsActiveWorldBattleground and IsActiveWorldBattleground()) 
        or (GetMapContentType() == MAP_CONTENT_BATTLEGROUND)
    if not isBG then return end

    local numObjectives = GetNumObjectives and GetNumObjectives() or 0
    if numObjectives == 0 then return end

    for i = 1, numObjectives do
        local keepId, objectiveId, bgContext = GetObjectiveIdsForIndex(i)
        
        if keepId and objectiveId and bgContext and IsLocalBattlegroundContext(bgContext) then
            local isEnabled = IsObjectiveEnabled(keepId, objectiveId, bgContext)
            local exists = DoesObjectiveExist(keepId, objectiveId, bgContext)
            
            if isEnabled and exists then
                -- 1. Точки спавна и постаменты появления (Мяч Хаоса, Флаги, Базы)
                local spawnPinType, spawnX, spawnY = GetObjectiveSpawnPinInfo(keepId, objectiveId, bgContext)
                if spawnPinType and spawnPinType ~= MAP_PIN_TYPE_INVALID and spawnX and spawnY and spawnX > 0 and spawnY > 0 and spawnX < 1 and spawnY < 1 then
                    local layout = ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[spawnPinType]
                    local icon = layout and layout.texture
                    if type(icon) == "function" then
                        local ok, res = pcall(icon, { m_PinType = spawnPinType, keepId = keepId, objectiveId = objectiveId })
                        if ok and type(res) == "string" then icon = res else icon = nil end
                    end
                    if icon and icon ~= "" then
                        local tint = layout and layout.tint
                        if type(tint) == "function" then
                            local ok, res = pcall(tint, { m_PinType = spawnPinType, keepId = keepId, objectiveId = objectiveId })
                            if ok then tint = res else tint = nil end
                        end
                        pins.CreatePin(icon, spawnX, spawnY, "Место появления", 22, nil, spawnPinType, nil, tint, DL_OVERLAY, 18)
                    end
                end

                -- 2. Базы и точки возврата реликвий
                local returnPinType, returnX, returnY = GetObjectiveReturnPinInfo(keepId, objectiveId, bgContext)
                if returnPinType and returnPinType ~= MAP_PIN_TYPE_INVALID and returnX and returnY and returnX > 0 and returnY > 0 and returnX < 1 and returnY < 1 then
                    local layout = ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[returnPinType]
                    local icon = layout and layout.texture
                    if type(icon) == "function" then
                        local ok, res = pcall(icon, { m_PinType = returnPinType, keepId = keepId, objectiveId = objectiveId })
                        if ok and type(res) == "string" then icon = res else icon = nil end
                    end
                    if icon and icon ~= "" then
                        local tint = layout and layout.tint
                        if type(tint) == "function" then
                            local ok, res = pcall(tint, { m_PinType = returnPinType, keepId = keepId, objectiveId = objectiveId })
                            if ok then tint = res else tint = nil end
                        end
                        pins.CreatePin(icon, returnX, returnY, "База реликвии", 24, nil, returnPinType, nil, tint, DL_OVERLAY, 18)
                    end
                end
            end
        end
    end
end
-- =========================================================================
-- 7. ЖИВОЙ ТРЕКЕР ГРУППЫ И СПУТНИКОВ
-- =========================================================================
local function GetGroupMemberIcon(unitTag, isLeader)
    local osi = OSI or OdySupportIcons
    if osi then
        local displayName = GetUnitDisplayName(unitTag)
        local rawCharName = GetUnitName(unitTag)
        local cleanCharName = rawCharName and zo_strformat("<<1>>", rawCharName)

        local keys = {}
        if displayName and displayName ~= "" then
            table.insert(keys, displayName)
            table.insert(keys, string.lower(displayName))
        end
        if cleanCharName and cleanCharName ~= "" then
            table.insert(keys, cleanCharName)
            table.insert(keys, string.lower(cleanCharName))
        end

        local tablesToCheck = { osi.special, osi.users, osi.custom, osi.rlicons }
        for _, t in ipairs(tablesToCheck) do
            if type(t) == "table" then
                for _, key in ipairs(keys) do
                    local val = t[key]
                    if val then
                        if type(val) == "string" and val ~= "" then return val
                        elseif type(val) == "table" and (val.icon or val.texture) then return val.icon or val.texture end
                    end
                end
            end
        end
    end

    if isLeader then
        return "EsoUI/Art/Compass/groupLeader.dds"
    end

    return "EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds"
end

function pins.UpdateGroupPinsRealtime()
    if not NecroCat_Minimap_MainWindow or NecroCat_Minimap_MainWindow:IsHidden() then return end

    local containerSize = NecroCat_MapContainer:GetWidth()
    local cfg = minimap.settings
    local doesRotate = cfg and cfg.rotate

    local playerX, playerY = 0, 0
    local pNormX, pNormY = GetMapPlayerPosition("player")
    if pNormX and pNormY then
        playerX = containerSize * pNormX
        playerY = containerSize * pNormY
    end
    local heading = GetPlayerCameraHeading() or 0
    local cosH = math.cos(heading)
    local sinH = math.sin(heading)

    -- 1. Живые Сопартийцы и Спутники
    for _, pin in pairs(g_groupPins) do
        pin:SetHidden(true)
    end

    local unitsToTrack = {}
    if IsUnitGrouped("player") then
        local groupSize = GetGroupSize()
        for i = 1, groupSize do
            local tag = GetGroupUnitTagByIndex(i)
            if DoesUnitExist(tag) and not AreUnitsEqual("player", tag) then
                table.insert(unitsToTrack, tag)
            end
        end
    end

    if HasActiveCompanion and HasActiveCompanion() and DoesUnitExist("companion") then
        table.insert(unitsToTrack, "companion")
    end

    for _, unitTag in ipairs(unitsToTrack) do
        local x, y, _, isInCurrentMap = GetMapPlayerPosition(unitTag)
        local pin = g_groupPins[unitTag]
        if not pin then
            pin = CreateControl("NCMM_GroupPin_" .. unitTag, NecroCat_MapContainer, CT_TEXTURE)
            pin:SetDrawTier(DT_HIGH)
            pin:SetDrawLayer(DL_OVERLAY)
            pin:SetDrawLevel(5)
            pin:SetMouseEnabled(true)
            pin:SetHandler("OnMouseEnter", function(self)
                if self.pinText then
                    InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
                    SetTooltipText(InformationTooltip, self.pinText)
                end
            end)
            pin:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
            g_groupPins[unitTag] = pin
        end

        if isInCurrentMap and x > 0 and y > 0 then
            pin:SetHidden(false)
            local isCompanion = (unitTag == "companion")
            local isLeader = not isCompanion and IsUnitGroupLeader(unitTag)

            if isCompanion then
                pin:SetTexture("EsoUI/Art/MapPins/UI-WorldMapCompanionPip.dds")
                local rawName = GetCompanionName(GetActiveCompanionDefId())
                pin.pinText = rawName and zo_strformat("|c66f2ffСпутник: <<1>>|r", rawName) or "Спутник"
            else
                pin:SetTexture(GetGroupMemberIcon(unitTag, isLeader))
                pin.pinText = isLeader and ("|cffd700Лидер группы: " .. GetUnitName(unitTag) .. "|r") or GetUnitName(unitTag)
            end
            
            local baseSize = (cfg and cfg.pinSize or 20)
            local pinSize = isLeader and (baseSize + 6) or (baseSize + 2)
            local drawLevel = isLeader and 12 or 5

            pin:SetDimensions(pinSize, pinSize)
            pin:SetDrawLevel(drawLevel)
            pin:ClearAnchors()
            if doesRotate then
                local ix = (x * containerSize) - playerX
                local iy = (y * containerSize) - playerY
                pin:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round((cosH * ix) - (sinH * iy)), zo_round((sinH * ix) + (cosH * iy)))
            else
                pin:SetAnchor(CENTER, NecroCat_MapContainer, TOPLEFT, x * containerSize, y * containerSize)
            end
        else
            pin:SetHidden(true)
        end
    end

    -- 2. Живые реликвии БГ и Свитки Сиродила
    local isBG = (GetMapContentType() == MAP_CONTENT_BATTLEGROUND) or (IsPlayerInBattleground and IsPlayerInBattleground())
    local isAvA = (IsInAvAZone and IsInAvAZone()) or (GetMapContentType() == MAP_CONTENT_AVA)

    if isBG or isAvA then
        local numObjectives = GetNumObjectives and GetNumObjectives() or 0
        for i = 1, numObjectives do
            local keepId, objectiveId, bgContext = GetObjectiveIdsForIndex(i)
            local pin = g_bgObjectivePins[i]
            
            local isValidContext = isAvA or (bgContext and IsLocalBattlegroundContext(bgContext))
            if keepId and objectiveId and bgContext and isValidContext and IsObjectiveEnabled(keepId, objectiveId, bgContext) and IsObjectiveObjectVisible(keepId, objectiveId, bgContext) then
                local pinType, curX, curY = GetObjectivePinInfo(keepId, objectiveId, bgContext)
                
                if isAvA and (type(pinType) == "number" and pinType >= 128 and pinType <= 220) then
                    pinType = MAP_PIN_TYPE_INVALID
                end

                if pinType and pinType ~= MAP_PIN_TYPE_INVALID and curX and curY and curX > 0 and curY > 0 and curX < 1 and curY < 1 then
                    if not pin then
                        pin = CreateControl("NCMM_BGObjPin_" .. i, NecroCat_MapContainer, CT_TEXTURE)
                        pin:SetDrawTier(DT_HIGH)
                        pin:SetDrawLayer(DL_OVERLAY)
                        pin:SetDrawLevel(30)
                        g_bgObjectivePins[i] = pin
                    end

                    local layout = ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType]
                    local icon = layout and layout.texture
                    if type(icon) == "function" then
                        local ok, res = pcall(icon, { m_PinType = pinType, keepId = keepId, objectiveId = objectiveId })
                        if ok and type(res) == "string" then icon = res else icon = nil end
                    end

                    if icon and icon ~= "" then
                        pin:SetTexture(icon)
                        local size = isAvA and 32 or 38
                        pin:SetDimensions(size, size)
                        pin:ClearAnchors()

                        if doesRotate then
                            local ix = (curX * containerSize) - playerX
                            local iy = (curY * containerSize) - playerY
                            pin:SetAnchor(CENTER, NecroCat_MapContainer, CENTER, zo_round((cosH * ix) - (sinH * iy)), zo_round((sinH * ix) + (cosH * iy)))
                        else
                            pin:SetAnchor(CENTER, NecroCat_MapContainer, TOPLEFT, curX * containerSize, curY * containerSize)
                        end
                        pin:SetHidden(false)
                    else
                        if pin then pin:SetHidden(true) end
                    end
                else
                    if pin then pin:SetHidden(true) end
                end
            else
                if pin then pin:SetHidden(true) end
            end
        end
    else
        for _, p in pairs(g_bgObjectivePins) do p:SetHidden(true) end
    end
end

-- =========================================================================
-- 8. СТРИМИНГ СТОРОННИХ АДДОНОВ (MapPins, LibMapPins, QuestMap)
-- =========================================================================
local function HandleCustomPinCreation(pinType, pinTag, xLoc, yLoc)
    if not (minimap.settings and minimap.settings.enabled) then return end
    if not xLoc or not yLoc or xLoc <= 0 or yLoc <= 0 or xLoc >= 1 or yLoc >= 1 then return end

    if DoesCurrentMapMatchMapForPlayerLocation and not DoesCurrentMapMatchMapForPlayerLocation() then
        return
    end

    if ZO_MapPin and ZO_MapPin.IsQuestPinType and ZO_MapPin.IsQuestPinType(pinType) then return end
    if pinType == MAP_PIN_TYPE_PLAYER_WAYPOINT or pinType == MAP_PIN_TYPE_RALLY_POINT or pinType == MAP_PIN_TYPE_PING then return end
    if ZO_MapPin and ZO_MapPin.POI_PIN_TYPES and ZO_MapPin.POI_PIN_TYPES[pinType] then return end
    if ZO_MapPin and ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES and ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES[pinType] then return end
    if pinType == MAP_PIN_TYPE_LOCATION then return end

    local lmp = LibMapPins
    if lmp and lmp.IsEnabled and pinType and lmp:IsEnabled(pinType) == false then return end

    local layout = nil
    if lmp and lmp.GetLayoutData then layout = lmp:GetLayoutData(pinType) end
    if not layout and ZO_MapPin and ZO_MapPin.PIN_DATA then layout = ZO_MapPin.PIN_DATA[pinType] end

    if layout then
        local icon = layout.texture or layout[1]
        if type(icon) == "function" then
            local ok, res = pcall(icon, { m_PinType = pinType, m_PinTag = pinTag })
            if ok and type(res) == "string" then icon = res else icon = nil end
        end

        if icon and icon ~= "" then
            local size = 18
            local tooltipCreator = layout.tooltip
            local tint = layout.tint
            if type(tint) == "function" then
                local ok, res = pcall(tint, { m_PinType = pinType, m_PinTag = pinTag })
                if ok then tint = res else tint = nil end
            end

            g_customPinsList[pinType] = g_customPinsList[pinType] or {}
            local pinKey = string.format("%.4f:%.4f", xLoc, yLoc)
            g_customPinsList[pinType][pinKey] = {
                icon = icon, x = xLoc, y = yLoc, size = size,
                tooltip = tooltipCreator, pinType = pinType, pinTag = pinTag, tint = tint
            }

            pins.CreatePin(icon, xLoc, yLoc, nil, size, tooltipCreator, pinType, pinTag, tint)
        end
    end
end

local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
if pinManager then
    ZO_PostHook(pinManager, "CreatePin", function(self, pinType, pinTag, xLoc, yLoc)
        HandleCustomPinCreation(pinType, pinTag, xLoc, yLoc)
    end)
    ZO_PostHook(pinManager, "RefreshCustomPins", function(self, optionalPinType)
        if optionalPinType then
            g_customPinsList[optionalPinType] = {}
        else
            g_customPinsList = {}
        end
        if pins.RefreshSavedCustomPins then
            pins.RefreshSavedCustomPins()
        end
    end)
end

if LibMapPins then
    ZO_PostHook(LibMapPins, "CreatePin", function(self, pinType, pinTag, xLoc, yLoc)
        HandleCustomPinCreation(pinType, pinTag, xLoc, yLoc)
    end)
end

function pins.RefreshSavedCustomPins()
    local lmp = LibMapPins
    for pinType, pinDict in pairs(g_customPinsList) do
        local isEnabled = true
        if lmp and lmp.IsEnabled and lmp:IsEnabled(pinType) == false then
            isEnabled = false
        end
        if isEnabled then
            for _, pData in pairs(pinDict) do
                pins.CreatePin(pData.icon, pData.x, pData.y, pData.text, pData.size, pData.tooltip, pData.pinType, pData.pinTag, pData.tint)
            end
        end
    end
end

-- =========================================================================
-- 9. ГЛАВНЫЙ СИНХРОНИЗАТОР
-- =========================================================================
function pins.RefreshAll()
    pins.Reset()
    if pins.RefreshWayshrines then pins.RefreshWayshrines() end
    if pins.RefreshLocations then pins.RefreshLocations() end
    if pins.RefreshPOIs then pins.RefreshPOIs() end
    if pins.RefreshSkyshards then pins.RefreshSkyshards() end
    if pins.RefreshQuests then pins.RefreshQuests() end
    if pins.RefreshAntiquities then pins.RefreshAntiquities() end
    
    local lmp = LibMapPins
    if lmp and lmp.RefreshPins then
        pcall(function() lmp:RefreshPins() end)
    end

    if pins.RefreshSavedCustomPins then pins.RefreshSavedCustomPins() end
    if pins.RefreshWaypoints then pins.RefreshWaypoints() end
    if pins.RefreshBattleground then pins.RefreshBattleground() end
    if pins.RefreshCyrodiil then pins.RefreshCyrodiil() end
end

EVENT_MANAGER:RegisterForUpdate("NecroCat_Minimap_GroupUpdate", 100, pins.UpdateGroupPinsRealtime)

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_InventoryUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
    if bagId == BAG_BACKPACK then
        EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_InvDebounce")
        EVENT_MANAGER:RegisterForUpdate("NecroCat_Minimap_InvDebounce", 250, function()
            EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_InvDebounce")
            g_customPinsList = {}
            if pins.RefreshAll then
                pins.RefreshAll()
            end
            if minimap.UpdatePlayerPosition then
                minimap.UpdatePlayerPosition(true)
            end
        end)
    end
end)
EVENT_MANAGER:AddFilterForEvent("NecroCat_Minimap_InventoryUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

local function OnQuestStateChanged()
    if not g_isPlayerActivated then return end
    EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_QuestDebounce")
    EVENT_MANAGER:RegisterForUpdate("NecroCat_Minimap_QuestDebounce", 150, function()
        EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_QuestDebounce")
        if pins.RefreshAll then pins.RefreshAll() end
    end)
end

if WORLD_MAP_QUEST_BREADCRUMBS then
    WORLD_MAP_QUEST_BREADCRUMBS:RegisterCallback("QuestAvailable", OnQuestStateChanged)
    WORLD_MAP_QUEST_BREADCRUMBS:RegisterCallback("QuestRemoved", OnQuestStateChanged)
end

if FOCUSED_QUEST_TRACKER then
    FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", OnQuestStateChanged)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_QuestAdv", EVENT_QUEST_ADVANCED, OnQuestStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_QuestCond", EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnQuestStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_QuestComp", EVENT_QUEST_COMPLETE, OnQuestStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_QuestRem", EVENT_QUEST_REMOVED, OnQuestStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_QuestAdd", EVENT_QUEST_ADDED, OnQuestStateChanged)

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_ForwardCamps", EVENT_FORWARD_CAMPS_UPDATED, function()
    if pins.RefreshCyrodiil then
        pins.RefreshCyrodiil()
    end
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_PinTeleport", EVENT_PLAYER_ACTIVATED, function()
    g_isPlayerActivated = true
    ClearOldZonePins()
    if pins.RefreshAll then pins.RefreshAll() end
end)

local function OnBattlegroundObjectivesChanged()
    if not g_isPlayerActivated then return end
    EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_BGDebounce")
    EVENT_MANAGER:RegisterForUpdate("NecroCat_Minimap_BGDebounce", 100, function()
        EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_BGDebounce")
        if pins.RefreshAll then
            pins.RefreshAll()
        end
        if minimap.UpdatePlayerPosition then
            minimap.UpdatePlayerPosition(true)
        end
    end)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_BGObjectives", EVENT_OBJECTIVES_UPDATED, OnBattlegroundObjectivesChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_BGControl", EVENT_OBJECTIVE_CONTROL_STATE, OnBattlegroundObjectivesChanged)

local function OnAntiquitiesStateChanged()
    if not g_isPlayerActivated then return end
    EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_AntiquityDebounce")
    EVENT_MANAGER:RegisterForUpdate("NecroCat_Minimap_AntiquityDebounce", 200, function()
        EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_AntiquityDebounce")
        if pins.RefreshAll then
            pins.RefreshAll()
        end
        if minimap.UpdatePlayerPosition then
            minimap.UpdatePlayerPosition(true)
        end
    end)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_DigSites", EVENT_ANTIQUITY_DIG_SITES_UPDATED, OnAntiquitiesStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_Antiquities", EVENT_ANTIQUITIES_UPDATED, OnAntiquitiesStateChanged)

local function OnCyrodiilStateChanged()
    if not g_isPlayerActivated then return end
    EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_CyroDebounce")
    EVENT_MANAGER:RegisterForUpdate("NecroCat_Minimap_CyroDebounce", 150, function()
        EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_CyroDebounce")
        if pins.RefreshAll then
            pins.RefreshAll()
        end
        if minimap.UpdatePlayerPosition then
            minimap.UpdatePlayerPosition(true)
        end
    end)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_KeepAttack", EVENT_KEEP_UNDER_ATTACK_CHANGED, OnCyrodiilStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_KeepOwner", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, OnCyrodiilStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_Minimap_KeepInit", EVENT_KEEPS_INITIALIZED, OnCyrodiilStateChanged)