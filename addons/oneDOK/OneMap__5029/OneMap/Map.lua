local A = OneMap

function A:CurrentMapDestination()
    local mapType = GetMapType()
    if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC then return nil end
    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex or zoneIndex <= 0 then return nil end
    return self:ZoneDestination(GetZoneId(zoneIndex))
end

function A:ResizeEnlargedMap()
    if IsInGamepadPreferredMode() or WORLD_MAP_MANAGER:GetModeMapSize() ~= 1 or not self.saved.enlargeMap then
        return false
    end

    -- Match ESO's fullscreen keyboard bounds before adding our enlargement.
    -- Its sizing helpers are local to worldmap.lua, so only this mode is handled
    -- here; the native pan/zoom code still lays out tiles, pins and scroll bounds.
    local uiWidth, uiHeight = GuiRoot:GetDimensions()
    local scale = GetUIGlobalScale()
    local size = math.min(math.max(200, uiHeight - 240 - 30 / scale), uiWidth, uiHeight)
    if (uiWidth - size) / 2 < 425 then
        size = math.min(math.max(200, uiWidth - 850), uiWidth, uiHeight)
    end
    size = math.min(size * 1.10, uiWidth, uiHeight)
    ZO_WorldMap:SetDimensionConstraints(200, 200, uiWidth, uiHeight)
    ZO_WorldMap:SetDimensions(size, size)
    ZO_WorldMap:ClearAnchors()
    ZO_WorldMap:SetAnchor(CENTER, nil, CENTER, 0, 9 / scale)
    local zoom = ZO_WorldMap_GetPanAndZoom()
    -- Refresh once at the final size without cancelling an active zoom target.
    zoom:SetCurrentNormalizedZoomInternal(zoom:GetCurrentNormalizedZoom())
    WORLD_MAP_MANAGER.blobNamesDirty = true
    return true
end

function A:ApplyMapSettings()
    if not self.baseMapScale then return end
    local keyboard = not IsInGamepadPreferredMode()
    ZO_WorldMap:SetScale(self.baseMapScale)
    local hide = keyboard and self.saved.hideCompletion
    WORLD_MAP_ZONE_STORY_KEYBOARD_FRAGMENT:SetHiddenForReason(self.name, hide)
    -- The zone story's native OnShowing/OnHiding manages its shared background.
    -- That background is a simple fragment without SetHiddenForReason.
    self:UpdateMapActivity()
end

function A:HideTravelTooltip()
    self.hoverOwner, self.hoverDestination = nil, nil
    if self.travelTooltip then self.travelTooltip:SetHidden(true) end
end

function A:ShowTravelTooltip(owner, destination)
    if not self.saved.travelTooltips or not destination or not self:CanUseMap() then
        self:HideTravelTooltip(); return
    end
    self.hoverOwner, self.hoverDestination = owner, destination
    self:RenderTravelTooltip(destination)
end

function A:RenderTravelTooltip(destination)
    local tooltip = self.travelTooltip
    tooltip.label:SetWidth(280)
    tooltip.label:SetText("|c80dfff" .. self:PriceText(destination) .. "|r")
    local textWidth = tooltip.label:GetTextDimensions()
    local width = math.min(280, math.max(1, textWidth)) + 12
    tooltip.label:SetWidth(width - 12)
    local _, height = tooltip.label:GetTextDimensions()
    tooltip:SetDimensions(width, height + 12)
    local x, y = GetUIMousePosition()
    x = math.max(0, math.min(x + 16, GuiRoot:GetWidth() - width))
    y = math.max(0, math.min(y + 16, GuiRoot:GetHeight() - height - 12))
    tooltip:ClearAnchors()
    tooltip:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    tooltip:SetHidden(false)
end

function A:UpdateWaves()
    local pin = ZO_WorldMap_GetPinManager():GetPlayerPin()
    local control = pin and pin:GetControl()
    local visible = self.saved.playerPulse and control and not control:IsHidden()
    local time = GetFrameTimeMilliseconds()
    for index, wave in ipairs(self.waves) do
        wave:SetHidden(not visible)
        if visible then
            wave:ClearAnchors()
            wave:SetAnchor(CENTER, control, CENTER)
            local progress = ((time + (index - 1) * 800) % 2400) / 2400
            local size = 20 + 76 * progress
            wave:SetDimensions(size, size)
            wave:SetAlpha(math.sin(progress * math.pi) * 0.76)
        end
    end
end

function A:UpdateMapActivity()
    if self.mapTravelKeybindActive then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mapTravelKeybind) end
    EVENT_MANAGER:UnregisterForUpdate("OneMapWaves")
    EVENT_MANAGER:UnregisterForUpdate("OneMapHover")
    if self:IsKeyboardMap() then
        if self.saved.playerPulse then
            EVENT_MANAGER:RegisterForUpdate("OneMapWaves", 33, function() self:UpdateWaves() end)
        end
        if self.saved.travelTooltips then
            EVENT_MANAGER:RegisterForUpdate("OneMapHover", 250, function()
                if not self:CanUseMap() then self:HideTravelTooltip(); return end
                if self.hoverOwner then
                    if self.hoverOwner:IsHidden() or not MouseIsOver(self.hoverOwner) then self:HideTravelTooltip()
                    else self:RenderTravelTooltip(self.hoverDestination); return end
                end
                self.travelTooltip:SetHidden(true)
            end)
        end
    else
        self.pendingQuest = nil
        EVENT_MANAGER:UnregisterForUpdate("OneMapQuestWait")
    end
    if not self.saved.playerPulse or not self:IsKeyboardMap() then
        for _, wave in ipairs(self.waves) do wave:SetHidden(true) end
    end
    if not self.saved.travelTooltips or not self:IsKeyboardMap() then self:HideTravelTooltip() end
end

function A:InitializeMap()
    self.mapTravelKeybind = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = self:Text("travelAction"),
            keybind = "UI_SHORTCUT_QUATERNARY",
            visible = function() return self:CanUseMap() end,
            enabled = function() return self:CanUseMap() and self:CurrentMapDestination() ~= nil end,
            callback = function()
                if not self:CanUseMap() then return end
                local destination = self:CurrentMapDestination()
                if destination then self:Travel(destination) end
            end,
        },
    }
    self.baseMapScale = ZO_WorldMap:GetScale()
    self.waves = {}
    for index = 1, 3 do
        local wave = WINDOW_MANAGER:CreateControl("OneMapWave" .. index, ZO_WorldMapContainer, CT_TEXTURE)
        wave:SetTexture("OneMap/art/wave.dds")
        wave:SetColor(0.05, 0.6, 1, 1)
        wave:SetDrawTier(DT_HIGH)
        wave:SetDrawLevel(9)
        wave:SetMouseEnabled(false)
        wave:SetHidden(true)
        self.waves[index] = wave
    end
    local tooltip = WINDOW_MANAGER:CreateTopLevelWindow("OneMapTravelTooltip")
    tooltip:SetDrawTier(DT_HIGH)
    tooltip:SetDrawLevel(100)
    tooltip:SetMouseEnabled(false)
    tooltip:SetHidden(true)
    local background = WINDOW_MANAGER:CreateControl(nil, tooltip, CT_BACKDROP)
    background:SetAnchorFill()
    background:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    background:SetCenterColor(0.025, 0.035, 0.05, 0.96)
    background:SetEdgeColor(0.25, 0.4, 0.5, 1)
    background:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 8)
    tooltip.label = WINDOW_MANAGER:CreateControl(nil, tooltip, CT_LABEL)
    tooltip.label:SetAnchor(TOPLEFT, tooltip, TOPLEFT, 6, 6)
    tooltip.label:SetWidth(280)
    tooltip.label:SetFont("ZoFontGameSmall")
    self.travelTooltip = tooltip

    -- Avoid laying out the ordinary map before laying out the enlarged map.
    ZO_PreHook(WORLD_MAP_MANAGER, "ResizeAndReanchorMap", function()
        return self:ResizeEnlargedMap()
    end)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapModeChanged", function() self:ApplyMapSettings() end)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        if self.mapTravelKeybindActive then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mapTravelKeybind) end
        self.quote = nil
        self.questPointCache = {}
        if self.pendingQuest and self.pendingQuest.mapId ~= GetCurrentMapId() then
            self.pendingQuest = nil
            EVENT_MANAGER:UnregisterForUpdate("OneMapQuestWait")
        end
        self:HideTravelTooltip()
    end)
    WORLD_MAP_QUEST_BREADCRUMBS:RegisterCallback("QuestAvailable", function(questIndex) self:CacheQuestPoints(questIndex) end)
    SCENE_MANAGER:GetScene("worldMap"):RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
            if not self.mapTravelKeybindActive then
                self.mapTravelKeybindActive = true
                KEYBIND_STRIP:AddKeybindButtonGroup(self.mapTravelKeybind)
            end
        elseif newState == SCENE_SHOWN then
            WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.mapTravelKeybind)
            self.mapTravelKeybindActive = false
        end
        self:ApplyMapSettings()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() self:ApplyMapSettings() end)

    self:ResizeEnlargedMap()
end
