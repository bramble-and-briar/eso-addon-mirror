local A = OneDungeon
local DAY = 86400

-- The cycle was aligned on 2025-03-13; Update 47 extended the DLC cycle
-- from 32 to 34 entries with a -2 phase adjustment. See DATA_SOURCES.md.
function A:CalculatePledges(timestamp, untilReset, apiVersion)
    if apiVersion < 101045 or apiVersion > 101051 then return nil end
    if type(timestamp) ~= "number" or type(untilReset) ~= "number" or untilReset < 0 or untilReset > DAY then return nil end
    local reset = untilReset == 0 and DAY or untilReset
    local serverDay = math.floor((timestamp + reset - DAY) / DAY)
    local epochDay = math.floor(GetTimestampForStartOfDate(2025, 3, 13, false) / DAY)
    local elapsed = serverDay - epochDay
    local result = {}
    for giver = 1, 3 do
        local rotation = giver == 3 and apiVersion < 101047 and self.pledgeDlcBefore47 or self.pledgeRotations[giver]
        local phase = giver == 3 and apiVersion >= 101047 and -2 or 0
        local zoneId = rotation[1 + (elapsed + phase) % #rotation]
        result[zoneId] = true
    end
    return result
end

function A:ReadTodaysPledges()
    return self:CalculatePledges(GetTimeStamp(), GetTimeUntilNextDailyLoginRewardClaimS(), GetAPIVersion())
end

-- One scheduled wakeup at the next daily reset, only while the list is visible.
function A:ScheduleDailyRefresh()
    local key = self.name .. "DailyReset"
    EVENT_MANAGER:UnregisterForUpdate(key)
    if not self.panel or self.panel:IsHidden() or self.failed then return end
    local seconds = GetTimeUntilNextDailyLoginRewardClaimS()
    if type(seconds) ~= "number" or seconds < 0 or seconds > DAY then return end
    if seconds == 0 then seconds = DAY end
    EVENT_MANAGER:RegisterForUpdate(key, (seconds + 1) * 1000, function()
        EVENT_MANAGER:UnregisterForUpdate(key)
        self:RefreshInformation()
        self:ScheduleDailyRefresh()
    end)
end
