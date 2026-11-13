local ADDON_NAME = "CyrodiilMapLabels"
local wm = WINDOW_MANAGER
local labels = {}

CyrodiilMapLabelsAddon = {
    name = ADDON_NAME,
    wm = wm,
    labels = labels
}

CyrodiilMapLabelsDefaults = {
    version = "1.9.1",
    variableVersion = 1,
    datasetChoice = "Long Names",
    useAllianceColors = true,
    fontScale = 1.0,
    fontStyle = "EsoUI/Common/Fonts/Univers57.slug|14|soft-shadow-thin",
    fallbackR = 0.2,
    fallbackG = 1.0,
    fallbackB = 0.0,
}

-- Built in core game fonts
CyrodiilMapLabelsFonts = {
    ["Trajan Pro (Stone Tablet)"]   = "EsoUI/Common/Fonts/TrajanPro-Regular.slug|16|soft-shadow-thin",
    ["Trajan Pro (Heavy Outline)"]  = "EsoUI/Common/Fonts/TrajanPro-Regular.slug|16|thick-outline",
    ["Standard Sans-Serif"]         = "EsoUI/Common/Fonts/Univers57.slug|14|soft-shadow-thin",
    ["Standard Sans-Serif (BOLD)"]  = "EsoUI/Common/Fonts/Univers67.slug|14|soft-shadow-thick", -- True Univers Bold
    ["Universal Hand (Chat)"]       = "EsoUI/Common/Fonts/Univers57.slug|14",
    ["Futura Condensed"]            = "EsoUI/Common/Fonts/ftn57.slug|16|soft-shadow-thin",
    ["Futura Condensed (BOLD)"]     = "EsoUI/Common/Fonts/ftn87.slug|16|soft-shadow-thick",  -- True Futura Bold
    ["Standard Outlined"]           = "EsoUI/Common/Fonts/Univers57.slug|14|outline",
}

CyrodiilMapLabelsData = CyrodiilMapLabelsData or {}
CyrodiilMapLabelsDataShort = CyrodiilMapLabelsDataShort or {}

local function IsPlayerInCyrodiilMainMap()
    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    local mapTexture = GetMapTileTexture()
    if not mapTexture then return false end
    return zoneId == 181 and string.find(mapTexture:lower(), "ava_whole") ~= nil
end

local function FindLivePinForKeep(keepId)
    if not ZO_WorldMapPins or not ZO_WorldMapPins.m_pinPanels then return nil end
    
    local pvpPanel = ZO_WorldMapPins.m_pinPanels[MAP_PIN_TYPE_KEEPS]
    if pvpPanel and pvpPanel.m_activePins then
        for _, pin in pairs(pvpPanel.m_activePins) do
            if pin and pin.m_PinData and pin.m_PinData.keepId == keepId then
                return pin
            end
        end
    end
    
    if ZO_WorldMapPins.m_activePins then
        for _, pin in pairs(ZO_WorldMapPins.m_activePins) do
            if pin and pin.m_PinData and pin.m_PinData.keepId == keepId then
                return pin
            end
        end
    end
    
    return nil
end

function CyrodiilMapLabelsAddon.UpdateLabels()
    local db = CyrodiilMapLabelsAddon.db
    
    for _, labelPair in pairs(labels) do
        if labelPair.shadow then labelPair.shadow:SetHidden(true) end
        if labelPair.main then labelPair.main:SetHidden(true) end
    end
    
    if not IsPlayerInCyrodiilMainMap() then return end
    if not ZO_WorldMapContainer or not ZO_WorldMapContainer.GetDimensions then return end
    
    local mapWidth, mapHeight = ZO_WorldMapContainer:GetDimensions()
    if not mapWidth or not mapHeight or mapWidth == 0 or mapHeight == 0 then return end
    
    local activeData = CyrodiilMapLabelsData
    if db and db.datasetChoice == "Short Names" then
        activeData = CyrodiilMapLabelsDataShort
    end
    if not activeData or type(activeData) ~= "table" or #activeData == 0 then return end

    local ALLIANCE_COLORS = {}
    ALLIANCE_COLORS[1] = { r = 0.9, g = 0.8, b = 0.2 } -- AD (Yellow)
    ALLIANCE_COLORS[2] = { r = 0.9, g = 0.2, b = 0.2 } -- EP (Red)
    ALLIANCE_COLORS[3] = { r = 0.2, g = 0.5, b = 0.9 } -- DC (Blue)

    local currentScale = db and db.fontScale or CyrodiilMapLabelsDefaults.fontScale
    local activeFont = db and db.fontStyle or CyrodiilMapLabelsDefaults.fontStyle
    local prefix = "SI_CYRODIILMAPLABELS_"
    local baseDistance = 6

    for index, keep in ipairs(activeData) do
        local targetX = keep.x
        local targetY = keep.y

        if not labels[index] then
            local sName = "CyrodiilMapLabel_Shadow_" .. index
            local mName = "CyrodiilMapLabel_Main_" .. index
            
            labels[index] = {
                shadow = wm:CreateControl(sName, ZO_WorldMapContainer, CT_LABEL),
                main = wm:CreateControl(mName, ZO_WorldMapContainer, CT_LABEL)
            }
            
            labels[index].shadow:SetColor(0, 0, 0, 1)
            labels[index].shadow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            labels[index].shadow:SetDimensions(150, 25)
            labels[index].shadow:SetDrawLayer(DL_OVERLAY)
            labels[index].shadow:SetDrawTier(DT_HIGH)
            
            labels[index].main:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            labels[index].main:SetDimensions(150, 25)
            labels[index].main:SetDrawLayer(DL_OVERLAY)
            labels[index].main:SetDrawTier(DT_HIGH)
        end

        labels[index].shadow:SetFont(activeFont)
        labels[index].main:SetFont(activeFont)
        labels[index].shadow:SetScale(currentScale)
        labels[index].main:SetScale(currentScale)

        local r = db and db.fallbackR or CyrodiilMapLabelsDefaults.fallbackR
        local g = db and db.fallbackG or CyrodiilMapLabelsDefaults.fallbackG
        local b = db and db.fallbackB or CyrodiilMapLabelsDefaults.fallbackB

        local stringType = (db and db.datasetChoice == "Short Names") and "SHORT_" or "KEEP_"
        local targetGlobalKey = prefix .. stringType .. keep.keepId
        local displayName = GetString(_G[targetGlobalKey])

        if displayName == "" or displayName == nil then
            displayName = keep.name
        end

        local shouldShowFactionColor = true
        if keep.keepId and keep.keepId >= 124 and keep.keepId <= 129 then
            if keep.keepId == 127 and GetKeepAlliance(11, 1) ~= 2 and GetKeepAlliance(10, 1) ~= 2 then
                shouldShowFactionColor = false
            elseif keep.keepId == 126 and GetKeepAlliance(12, 1) ~= 2 and GetKeepAlliance(10, 1) ~= 2 then
                shouldShowFactionColor = false
            elseif keep.keepId == 128 and GetKeepAlliance(3, 1) ~= 3 and GetKeepAlliance(5, 1) ~= 3 then
                shouldShowFactionColor = false
            elseif keep.keepId == 129 and GetKeepAlliance(4, 1) ~= 3 and GetKeepAlliance(5, 1) ~= 3 then
                shouldShowFactionColor = false
            elseif keep.keepId == 124 and GetKeepAlliance(19, 1) ~= 1 and GetKeepAlliance(16, 1) ~= 1 then
                shouldShowFactionColor = false
            elseif keep.keepId == 125 and GetKeepAlliance(20, 1) ~= 1 and GetKeepAlliance(16, 1) ~= 1 then
                shouldShowFactionColor = false
            end
        end

        if db and db.useAllianceColors and keep.keepId and shouldShowFactionColor then
            local allianceId = GetKeepAlliance(keep.keepId, 1)
            if allianceId and ALLIANCE_COLORS[allianceId] then
                local colorProfile = ALLIANCE_COLORS[allianceId]
                r, g, b = colorProfile.r, colorProfile.g, colorProfile.b
            end
        end

        labels[index].shadow:SetText(displayName)
        labels[index].main:SetText(displayName)
        labels[index].main:SetColor(r, g, b, 1)

        labels[index].shadow:ClearAnchors()
        labels[index].main:ClearAnchors()

        local livePin = FindLivePinForKeep(keep.keepId)

        if livePin and livePin.GetNamedChild and livePin:GetLeft() then
            local pinLeft, pinTop = livePin:GetLeft(), livePin:GetTop()
            local pinWidth, pinHeight = livePin:GetDimensions()
            
            local pinCenterX = pinLeft + (pinWidth / 2)
            local pinCenterY = pinTop + (pinHeight / 2)
            
            local containerLeft, containerTop = ZO_WorldMapContainer:GetLeft(), ZO_WorldMapContainer:GetTop()
            local finalX = pinCenterX - containerLeft
            local finalY = pinCenterY - containerTop

            labels[index].shadow:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT, finalX + 2, finalY + baseDistance + 2)
            labels[index].main:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT, finalX, finalY + baseDistance)
        else
            local finalX = targetX * mapWidth
            local finalY = targetY * mapHeight

            labels[index].shadow:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT, finalX + 2, finalY + baseDistance + 2)
            labels[index].main:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT, finalX, finalY + baseDistance)
        end

        labels[index].shadow:SetHidden(false)
        labels[index].main:SetHidden(false)
    end
end

ZO_WorldMapContainer:SetHandler("OnRectChanged", CyrodiilMapLabelsAddon.UpdateLabels)

local function OnWorldMapChanged()
    CyrodiilMapLabelsAddon.UpdateLabels()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        
        CyrodiilMapLabelsAddon.db = ZO_SavedVars:NewAccountWide("CyrodiilMapLabelsSavedVars", CyrodiilMapLabelsDefaults.variableVersion, nil, CyrodiilMapLabelsDefaults)
        
        if CyrodiilMapLabelsAddon.CreateSettingsMenu then
            CyrodiilMapLabelsAddon.CreateSettingsMenu()
        end
        
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_WORLD_MAP_CHANGED, OnWorldMapChanged)
        
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDDEN then
                for _, labelPair in pairs(labels) do
                    if labelPair.shadow then labelPair.shadow:SetHidden(true) end
                    if labelPair.main then labelPair.main:SetHidden(true) end
                end
            end
        end)
        
        zo_callLater(function() CyrodiilMapLabelsAddon.UpdateLabels() end, 500)
    end
end)
