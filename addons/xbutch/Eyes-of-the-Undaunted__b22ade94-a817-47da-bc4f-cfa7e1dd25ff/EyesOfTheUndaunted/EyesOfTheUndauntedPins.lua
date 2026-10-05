-- Lightweight custom map-pin adapter for Eyes of the Undaunted.
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

local MapPins = {}
MapPins.pinManager = ZO_WorldMap_GetPinManager()

local function GetPinTypeId(pinType)
    if type(pinType) == "string" then
        return _G[pinType]
    elseif type(pinType) == "number" then
        return pinType
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
    self.pinManager:RefreshCustomPins(pinTypeId)
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
    if pinType == nil then
        self.pinManager:RefreshCustomPins()
        return
    end

    local pinTypeId = GetPinTypeId(pinType)
    if pinTypeId then
        self.pinManager:RefreshCustomPins(pinTypeId)
    end
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

EOTU.internal.mapPins = MapPins
