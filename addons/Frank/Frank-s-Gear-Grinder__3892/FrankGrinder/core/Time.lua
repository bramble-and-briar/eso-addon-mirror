local AddonName = FrankGrinder.name

local function chat_msg(msg)
    d("[|cFF0000Frank|cFF5500Grinder|r] " .. tostring(msg))
end

function FrankGrinder:ChatMsg(msg) chat_msg(msg) end

function FrankGrinder:IsDebugEnabled() return self._debugEnabled == true end
function FrankGrinder:SetDebugEnabled(v) self._debugEnabled = v and true or false end

function FrankGrinder:DebugMsg(msg)
    if self:IsDebugEnabled() then
        chat_msg("|cCC6699debug:|r " .. tostring(msg))
    end
end

function FrankGrinder.RedGreenGradient(i, N)
    if N == 0 then return "FFFFFF" end
    if i < 0 then i = 0 end
    if i > N then i = N end

    local ratio = i / N
    local R = math.floor(255 * (1 - ratio) + 0.5)
    local G = math.floor(255 * ratio + 0.5)
    local B = 0

    return string.format("%02X%02X%02X", R, G, B)
end

function FrankGrinder.SecondsToClock(value, timeFmt)
    local days, hours, mins, secs, seconds = 0, 0, 0, 0, tonumber(value)

    if (timeFmt == "Full(dhms)") then
        if seconds <= 0 then return GetString(GG_TIME_NONE) end
        days = math.floor(seconds / 86400); seconds = seconds - (days * 86400)
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)

        if (days == 0 and hours == 0 and mins == 0) then return string.format("%01.f " .. GetString(GG_TIME_SECONDS), secs)
        elseif (days == 0 and hours == 0) then return string.format("%01.f " .. GetString(GG_TIME_MINUTES) .. ", %01.f " .. GetString(GG_TIME_SECONDS), mins, secs)
        elseif (days == 0) then return string.format("%01.f " .. GetString(GG_TIME_HOURS) .. ", %01.f " .. GetString(GG_TIME_MINUTES) .. ", %01.f " .. GetString(GG_TIME_SECONDS), hours, mins, secs)
        else return string.format("%01.f " .. GetString(GG_TIME_DAYS) .. ", %01.f " .. GetString(GG_TIME_HOURS) .. ", %01.f " .. GetString(GG_TIME_MINUTES) .. ", %01.f " .. GetString(GG_TIME_SECONDS), days, hours, mins, secs)
        end

    elseif (timeFmt == "first_two") then
        if seconds <= 0 then return GetString(GG_TIME_NONE) end
        days = math.floor(seconds / 86400); seconds = seconds - (days * 86400)
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)

        if (days == 0 and hours == 0 and mins == 0) then return string.format("%01.fs", secs)
        elseif (days == 0 and hours == 0) then return string.format("%01.fm %01.fs", mins, secs)
        elseif (days == 0) then return string.format("%01.fh %01.fm", hours, mins)
        else return string.format("%01.fd %01.fh", days, hours)
        end

    elseif (timeFmt == "Full(hms)") then
        if seconds <= 0 then return GetString(GG_TIME_NONE) end
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)

        if (hours == 0 and mins == 0) then return string.format("%01.f " .. GetString(GG_TIME_SECONDS), secs)
        elseif (hours == 0) then return string.format("%01.f " .. GetString(GG_TIME_MINUTES) .. ", %01.f " .. GetString(GG_TIME_SECONDS), mins, secs)
        else return string.format("%01.f " .. GetString(GG_TIME_HOURS) .. ", %01.f " .. GetString(GG_TIME_MINUTES) .. ", %01.f " .. GetString(GG_TIME_SECONDS), hours, mins, secs)
        end

    elseif (timeFmt == "d:hh:mm:ss") then
        if seconds <= 0 then return "-" end
        days = math.floor(seconds / 86400); seconds = seconds - (days * 86400)
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)
        return string.format("%01.f:%02.f:%02.f:%02.f", days, hours, mins, secs)

    elseif (timeFmt == "short") then
        if seconds <= 0 then return "-" end
        days = math.floor(seconds / 86400); seconds = seconds - (days * 86400)
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)
        return string.format("%01.fd %02.f:%02.f:%02.f", days, hours, mins, secs)

    elseif (timeFmt == "d:h:mm:ss") then
        if seconds <= 0 then return "-" end
        days = math.floor(seconds / 86400); seconds = seconds - (days * 86400)
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)
        return string.format("%01.f:%01.f:%02.f:%02.f", days, hours, mins, secs)

    elseif (timeFmt == "h:mm:ss") then
        if seconds <= 0 then return "-" end
        hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
        mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
        secs = math.floor(seconds)
        return string.format("%01.f:%02.f:%02.f", hours, mins, secs)
    end

    if seconds <= 0 then return "-" end
    days = math.floor(seconds / 86400); seconds = seconds - (days * 86400)
    hours = math.floor(seconds / 3600); seconds = seconds - (hours * 3600)
    mins = math.floor(seconds / 60); seconds = seconds - (mins * 60)
    secs = math.floor(seconds)
    return string.format("%01.f:%02.f:%02.f:%02.f", days, hours, mins, secs)
end

function FrankGrinder.GetTimeElapsed(prevTime)
    return (prevTime ~= nil and prevTime ~= 0) and GetDiffBetweenTimeStamps(GetTimeStamp(), prevTime) or 0
end

function FrankGrinder.GetOffset()
    local now = os.time()
    local utcNow = os.time(os.date("!*t", now))
    return now - utcNow
end

function FrankGrinder.GetResetHour()
    local worldName = GetWorldName()
    return tonumber(worldName == "EU Megaserver" and 3 or 10)
end

function FrankGrinder.GetNextDailyResetTime()
    local currentTime = os.time()
    local utcTime = os.date("!%H:%M:%S", currentTime)

    local delta = utcTime > string.format("%02d:00:00", FrankGrinder.GetResetHour()) and ZO_ONE_DAY_IN_SECONDS or 0
    local nextTime = os.date("!*t", currentTime + delta)

    nextTime.hour = FrankGrinder.GetResetHour()
    nextTime.min = 0
    nextTime.sec = 0

    return os.time(nextTime) + FrankGrinder.GetOffset()
end

function FrankGrinder.GetNextWeeklyResetTime()
    local currentTime = os.time()
    local utcTime = os.date("!%H:%M:%S", currentTime)
    local weekDay = tonumber(os.date("!%w", currentTime))
    local UTCResetDay = 2 -- Tuesday (0=Sunday)

    local delta = ((weekDay > UTCResetDay) or (weekDay == UTCResetDay and utcTime > string.format("%02d:00:00", FrankGrinder.GetResetHour())))
        and (7 - (weekDay - UTCResetDay)) * ZO_ONE_DAY_IN_SECONDS
        or (UTCResetDay - weekDay) * ZO_ONE_DAY_IN_SECONDS

    local nextTime = os.date("!*t", currentTime + delta)
    nextTime.hour = FrankGrinder.GetResetHour()
    nextTime.min = 0
    nextTime.sec = 0

    return os.time(nextTime) + FrankGrinder.GetOffset()
end

function FrankGrinder.GetTimeRemaining(prevTime)
    if (prevTime ~= nil and prevTime ~= 0) then
        local remainingTime = FrankGrinder.GetNextWeeklyResetTime() - prevTime
        if remainingTime >= 0 and remainingTime < ZO_ONE_DAY_IN_SECONDS * 7 then
            return remainingTime
        end
    end
    return 0
end
