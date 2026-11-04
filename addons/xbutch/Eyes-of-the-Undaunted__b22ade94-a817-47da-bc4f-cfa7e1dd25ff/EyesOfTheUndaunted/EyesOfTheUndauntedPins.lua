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
MapPins.sliceMilliseconds = 2
MapPins.sliceUnits = 8
MapPins.sharedReserveMilliseconds = 200
local WORK_UPDATE = "EyesOfTheUndauntedPinWork"

function MapPins:HasWorkBudget()
    if GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS then
        local total = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
        local used = GetTotalUserAddOnCPUTimeUsedNowMS()
        return type(total) == "number" and total > 0 and type(used) == "number"
            and used + self.sharedReserveMilliseconds < total
    end
    return true
end

function MapPins:StopWork()
    EVENT_MANAGER:UnregisterForUpdate(WORK_UPDATE)
    self.workRunning = false
end

function MapPins:CancelPending()
    self.pinWorker, self.pendingRefresh = nil, nil
    self:StopWork()
end

function MapPins:StartWork()
    if self.workRunning then return end
    self.workRunning = true
    EVENT_MANAGER:RegisterForUpdate(WORK_UPDATE, 25, function() self:RunWorkSlice() end)
end

function MapPins:QueuePins(worker)
    self.pinWorker = coroutine.create(worker)
    self:StartWork()
end

function MapPins:RunWorkSlice()
    if not self.pinWorker and not self.pendingRefresh then self:StopWork(); return end
    if not self:HasWorkBudget() then return end
    local frame = GetFrameTimeMilliseconds()
    if self.lastWorkFrame == frame then return end
    self.lastWorkFrame = frame
    local started, units = GetGameTimeMilliseconds(), 0
    if self.pendingRefresh then
        local pinType = self.pendingRefresh
        self.pendingRefresh = nil
        self.pinManager:RefreshCustomPins(pinType)
        units = units + 1
    end
    while self.pinWorker and units < self.sliceUnits and self:HasWorkBudget()
        and GetGameTimeMilliseconds() - started < self.sliceMilliseconds do
        local worker = self.pinWorker
        local ok, message = coroutine.resume(worker)
        units = units + 1
        if not ok then
            self:CancelPending()
            local addon = EOTU
            if addon and addon.Print then addon:Print("Pin update stopped: " .. tostring(message)) end
            return
        end
        if self.pinWorker == worker and coroutine.status(worker) == "dead" then self.pinWorker = nil end
    end
    if not self.pinWorker and not self.pendingRefresh then self:StopWork() end
end

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
    if pinTypeId then
        -- New context/settings invalidate unfinished pins before requesting one
        -- coalesced native refresh. Never refresh unrelated addons' pin types.
        self.pinWorker = nil
        self.pendingRefresh = pinTypeId
        self:StartWork()
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
