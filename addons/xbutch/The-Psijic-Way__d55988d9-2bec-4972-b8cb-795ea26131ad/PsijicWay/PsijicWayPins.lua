-- Lightweight custom map-pin adapter for The Psijic Way.
-- Minimal adapted subset of LibMapPins-1.0, backed directly by ESO's
-- native ZO_WorldMap pin manager.
--
-- Copyright (c) 2014, 2015 Ales Machat (Garkin)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

PsijicWay = PsijicWay or {}
PsijicWay.internal = PsijicWay.internal or {}

local MapPins = {
    pinManager = ZO_WorldMap_GetPinManager(),
    filters = {},
    pendingRefreshes = {},
}

local function HasMapPinBudget()
    if GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS then
        local available = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
        if available > 0 then return GetTotalUserAddOnCPUTimeUsedNowMS() + 20 < available end
    end
    return true
end

local function GetPinTypeId(pinType)
    if type(pinType) == "string" then
        return _G[pinType]
    elseif type(pinType) == "number" then
        return pinType
    end
end

local function GetPinTypeIdAndString(pinType)
    if type(pinType) == "string" then
        return _G[pinType], pinType
    elseif type(pinType) == "number" then
        local pinData = MapPins.pinManager.customPins and MapPins.pinManager.customPins[pinType]
        return pinType, pinData and pinData.pinTypeString or nil
    end
end

function MapPins:AddPinType(pinTypeString, addCallback, resizeCallback, layout, tooltipCreator)
    assert(type(pinTypeString) == "string", "pinTypeString must be a string")
    assert(not _G[pinTypeString], "pin type already exists: " .. pinTypeString)
    assert(type(addCallback) == "function", "addCallback must be a function")

    layout = layout or {
        level = 40,
        texture = "EsoUI/Art/Inventory/newitem_icon.dds",
    }

    self.pinManager:AddCustomPin(pinTypeString, addCallback, resizeCallback, layout, tooltipCreator)

    local pinTypeId = _G[pinTypeString]
    if not pinTypeId then
        return nil
    end

    self.pinManager:SetCustomPinEnabled(pinTypeId, true)
    self:RefreshPins(pinTypeId)
    return pinTypeId
end

function MapPins:CreatePin(pinType, pinTag, x, y, areaRadius)
    if pinTag == nil or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    local pinTypeId = GetPinTypeId(pinType)
    if not pinTypeId then
        return
    end

    local customPins = self.pinManager.customPins
    if customPins and customPins[pinTypeId] and self.pinManager:IsCustomPinEnabled(pinTypeId) then
        self.pinManager:CreatePin(pinTypeId, pinTag, x, y, areaRadius)
    end
end

function MapPins:RefreshPins(pinType)
    local pinTypeId = GetPinTypeId(pinType)
    -- A nil native argument refreshes every addon's custom pins.
    if not pinTypeId or not self.pinManager.customPins[pinTypeId] or self.pendingRefreshes[pinTypeId] then return end
    self.pendingRefreshes[pinTypeId] = true
    local function Refresh()
        if not HasMapPinBudget() then zo_callLater(Refresh, 50); return end
        self.pendingRefreshes[pinTypeId] = nil
        self.pinManager:RefreshCustomPins(pinTypeId)
    end
    zo_callLater(Refresh, 50)
end

function MapPins:SetLayoutKey(pinType, key, value)
    if type(key) ~= "string" then
        return
    end

    local pinTypeId = GetPinTypeId(pinType)
    local pinData = pinTypeId and ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinTypeId]
    if pinData then
        pinData[key] = value
    end
end

function MapPins:SetClickHandlers(pinType, leftHandler, rightHandler)
    local pinTypeId = GetPinTypeId(pinType)
    if not pinTypeId then
        return
    end

    if type(leftHandler) == "table" or leftHandler == nil then
        ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_LEFT][pinTypeId] = leftHandler
    end
    if type(rightHandler) == "table" or rightHandler == nil then
        ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_RIGHT][pinTypeId] = rightHandler
    end
end

function MapPins:IsEnabled(pinType)
    local pinTypeId = GetPinTypeId(pinType)
    if pinTypeId then
        return self.pinManager:IsCustomPinEnabled(pinTypeId)
    end
    return false
end

function MapPins:SetEnabled(pinType, state)
    local pinTypeId = GetPinTypeId(pinType)
    if not pinTypeId then
        return
    end

    local enabled
    if type(state) == "number" then
        enabled = state ~= 0
    else
        enabled = state and true or false
    end

    local needsRefresh = self.pinManager:IsCustomPinEnabled(pinTypeId) ~= enabled
    local filter = self.filters[pinTypeId]
    if filter then
        local mapFilterType = GetMapFilterType()
        local checkbox
        if mapFilterType == MAP_FILTER_TYPE_STANDARD then
            checkbox = filter.pve
        elseif mapFilterType == MAP_FILTER_TYPE_AVA_CYRODIIL then
            checkbox = filter.pvp
        elseif mapFilterType == MAP_FILTER_TYPE_AVA_IMPERIAL then
            checkbox = filter.imperialPvP
        elseif mapFilterType == MAP_FILTER_TYPE_BATTLEGROUND then
            checkbox = filter.battleground
        end
        if checkbox then
            ZO_CheckButton_SetCheckState(checkbox, enabled)
        end
    end

    self.pinManager:SetCustomPinEnabled(pinTypeId, enabled)
    if needsRefresh then
        self:RefreshPins(pinTypeId)
    end
end

function MapPins:AddPinFilter(pinType, checkboxText, separate, savedVars, pveKey, pvpKey, imperialPvpKey, battlegroundKey)
    local pinTypeId, pinTypeString = GetPinTypeIdAndString(pinType)
    if not pinTypeId or not pinTypeString or self.filters[pinTypeId] then
        return
    end

    local filter = {}
    self.filters[pinTypeId] = filter

    if type(savedVars) == "table" then
        filter.vars = savedVars
        filter.pveKey = pveKey or pinTypeString
        if separate then
            filter.pvpKey = pvpKey or pinTypeString .. "_pvp"
            filter.imperialPvPKey = imperialPvpKey or pinTypeString .. "_imperialPvP"
            filter.battlegroundKey = battlegroundKey or pinTypeString .. "_battleground"
        else
            filter.pvpKey = filter.pveKey
            filter.imperialPvPKey = filter.pveKey
            filter.battlegroundKey = filter.pveKey
        end
    end

    if type(checkboxText) ~= "string" then
        checkboxText = pinTypeString
    end

    local function AddCheckbox(panel)
        if not panel or not panel.checkBoxPool then
            return nil
        end
        local checkbox = panel.checkBoxPool:AcquireObject()
        ZO_CheckButton_SetLabelText(checkbox, checkboxText)
        panel:AnchorControl(checkbox)
        return checkbox
    end

    filter.pve = AddCheckbox(WORLD_MAP_FILTERS and WORLD_MAP_FILTERS.pvePanel)
    filter.pvp = AddCheckbox(WORLD_MAP_FILTERS and WORLD_MAP_FILTERS.pvpPanel)
    filter.imperialPvP = AddCheckbox(WORLD_MAP_FILTERS and WORLD_MAP_FILTERS.imperialPvPPanel)
    filter.battleground = AddCheckbox(WORLD_MAP_FILTERS and WORLD_MAP_FILTERS.battlegroundPanel)

    local function ConfigureCheckbox(control, key)
        if not control then
            return
        end
        ZO_CheckButton_SetToggleFunction(control, function(_, state)
            if filter.vars and key then
                filter.vars[key] = state
            end
            self:SetEnabled(pinTypeId, state)
        end)
    end

    ConfigureCheckbox(filter.pve, filter.pveKey)
    ConfigureCheckbox(filter.pvp, filter.pvpKey)
    ConfigureCheckbox(filter.imperialPvP, filter.imperialPvPKey)
    ConfigureCheckbox(filter.battleground, filter.battlegroundKey)

    if filter.vars then
        local mapFilterType = GetMapFilterType()
        local key = filter.pveKey
        if mapFilterType == MAP_FILTER_TYPE_AVA_CYRODIIL then
            key = filter.pvpKey
        elseif mapFilterType == MAP_FILTER_TYPE_AVA_IMPERIAL then
            key = filter.imperialPvPKey
        elseif mapFilterType == MAP_FILTER_TYPE_BATTLEGROUND then
            key = filter.battlegroundKey
        end
        self:SetEnabled(pinTypeId, filter.vars[key])
    else
        for _, control in pairs({
            filter.pve,
            filter.pvp,
            filter.imperialPvP,
            filter.battleground,
        }) do
            if control then
                ZO_CheckButton_SetCheckState(control, self:IsEnabled(pinTypeId))
            end
        end
    end

    return filter.pve, filter.pvp, filter.imperialPvP, filter.battleground
end

function MapPins:SetPinFilterHidden(pinType, context, hidden)
    local pinTypeId = GetPinTypeId(pinType)
    local filter = pinTypeId and self.filters[pinTypeId]
    local control = filter and filter[context]
    if not control or control:IsControlHidden() == hidden then
        return
    end

    control:SetHidden(hidden)
    local valid, point, relativeTo, relativePoint, offsetX, offsetY, restrain = control:GetAnchor(0)
    if not valid then
        return
    end

    if hidden then
        control.oldOffsetY = offsetY
        offsetY = control:GetHeight() * -1
    else
        offsetY = control.oldOffsetY or offsetY
    end

    control:ClearAnchors()
    control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY, restrain)
end

function MapPins:GetZoneAndSubzone(alternative, stripUIMap, keepMapNumber)
    local mapTexture = GetMapTileTexture()
    if not mapTexture then
        return nil
    end

    mapTexture = mapTexture:lower():gsub("^.*/maps/", "")
    if stripUIMap then
        mapTexture = mapTexture:gsub("ui_map_", "")
    end
    mapTexture = mapTexture:gsub("%.dds$", "")
    if not keepMapNumber then
        mapTexture = mapTexture:gsub("%d*$", ""):gsub("_+$", "")
    end

    if alternative then
        return mapTexture
    end

    local zone, subzone = mapTexture:match("^([^/]+)/?(.*)$")
    if subzone == "" then
        subzone = nil
    end
    return zone, subzone
end

function MapPins:OnMapChanged()
    local context
    local mapFilterType = GetMapFilterType()
    if mapFilterType == MAP_FILTER_TYPE_STANDARD then
        context = "pve"
    elseif mapFilterType == MAP_FILTER_TYPE_AVA_CYRODIIL then
        context = "pvp"
    elseif mapFilterType == MAP_FILTER_TYPE_AVA_IMPERIAL then
        context = "imperialPvP"
    elseif mapFilterType == MAP_FILTER_TYPE_BATTLEGROUND then
        context = "battleground"
    end
    if not context then
        return
    end

    if self.context == context then
        return
    end
    self.context = context

    local filterKey = context .. "Key"
    for pinTypeId, filter in pairs(self.filters) do
        if filter.vars then
            self:SetEnabled(pinTypeId, filter.vars[filter[filterKey]])
        else
            local control = filter[context]
            if control then
                ZO_CheckButton_SetCheckState(control, self:IsEnabled(pinTypeId))
            end
        end
    end
end

CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
    if MapPins.mapChangePending then return end
    MapPins.mapChangePending = true
    local function ApplyMapContext()
        if not HasMapPinBudget() then zo_callLater(ApplyMapContext, 50); return end
        MapPins.mapChangePending = false
        -- Read the final map context after a burst of native/minimap callbacks.
        MapPins:OnMapChanged()
    end
    zo_callLater(ApplyMapContext, 50)
end)

PsijicWay.internal.mapPins = MapPins
