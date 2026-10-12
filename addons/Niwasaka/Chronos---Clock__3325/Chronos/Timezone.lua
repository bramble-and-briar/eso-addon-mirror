local Chronos = _G['Chronos']

local function isDst()
    return os.date("*t").isdst and true or false
end

local function getDstOffset()
    return isDst() and 1 or 0
end

local function getStandardUtcOffsetHours()
    local now = GetTimeStamp()
    local utcDate = os.date("!*t", now)
    utcDate.isdst = false
    return os.difftime(now, os.time(utcDate)) / 3600
end

function Chronos:GetTimeZone()
    return getStandardUtcOffsetHours()
end

function Chronos:GetTimeOffset()
    return self:GetSelectedTimeZoneOffset() * 3600
end

function Chronos:GetTimeString()
    return os.date("!%H:%M", GetTimeStamp() + self:GetTimeOffset())
end

function Chronos:CreateTimeZoneLookup()
    local lookup = {}
    for _, value in ipairs(self.timeZoneTable) do
        lookup[#lookup + 1] = value.name
    end
    self.timeZoneLookup = lookup
end

function Chronos:MigrateTimeZone()
    if self.db.timeZoneIndex <= 0 then
        self.db.timeZoneIndex = self:GetIndexFromOffset(Chronos:GetTimeZone())
    end
end

function Chronos:GetSelectedTimeZoneOffset()
    local timeZone = self.timeZoneTable[self.db.timeZoneIndex]
    return timeZone and (timeZone.offset + (self.db.clockDst and getDstOffset() or 0)) or 0
end

function Chronos:GetIndexFromTimeZone(timeZone)
    for index, value in ipairs(self.timeZoneTable) do
        if value.name == timeZone then
            return index
        end
    end
    return 1
end

function Chronos:GetIndexFromOffset(offset)
    for index, value in ipairs(self.timeZoneTable) do
        if value.offset == offset then
            return index
        end
    end
    return 1
end

function Chronos:InitTimeZone()
    self:CreateTimeZoneLookup()
    self:MigrateTimeZone()
end