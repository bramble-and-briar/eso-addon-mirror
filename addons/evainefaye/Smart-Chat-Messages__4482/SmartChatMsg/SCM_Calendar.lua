SmartChatMsg = SmartChatMsg or {}

local function leap(year) return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) end
local function monthDays(year, month)
    local lengths = {31,28,31,30,31,30,31,31,30,31,30,31}
    return month == 2 and leap(year) and 29 or lengths[month]
end
local function civilSeconds(year, month, day, hour, minute)
    local days = 0
    for y = 1970, year - 1 do days = days + (leap(y) and 366 or 365) end
    for m = 1, month - 1 do days = days + monthDays(year, m) end
    return (days + day - 1) * 86400 + hour * 3600 + minute * 60
end
local function firstSunday(year, month)
    local weekday = (math.floor(civilSeconds(year, month, 1, 0, 0) / 86400) + 4) % 7
    return 1 + ((7 - weekday) % 7)
end

local zones={ET={name="Eastern",standard=-5,daylight="EDT",winter="EST"},
    CT={name="Central",standard=-6,daylight="CDT",winter="CST"},
    MT={name="Mountain",standard=-7,daylight="MDT",winter="MST"},
    PT={name="Pacific",standard=-8,daylight="PDT",winter="PST"}}
function SmartChatMsg:NormalizeSchedulingTimeZone(zone)
    local aliases={["America/New_York"]="ET",["America/Chicago"]="CT",["America/Denver"]="MT",["America/Los_Angeles"]="PT"}
    zone=aliases[zone] or zone
    return zones[zone] and zone or "ET"
end
function SmartChatMsg:GetSchedulingTimeZone()
    return self:NormalizeSchedulingTimeZone(self.savedVars and self.savedVars.schedulingTimeZone)
end
function SmartChatMsg:GetSchedulingTimeZoneName(zone)
    return zones[self:NormalizeSchedulingTimeZone(zone or self:GetSchedulingTimeZone())].name
end
function SmartChatMsg:GetTimeZoneUtcOffset(utc,zone)
    local z=zones[self:NormalizeSchedulingTimeZone(zone or self:GetSchedulingTimeZone())]
    local year=os.date("!*t",utc).year
    local starts=civilSeconds(year,3,firstSunday(year,3)+7,2,0)-z.standard*3600
    local ends=civilSeconds(year,11,firstSunday(year,11),2,0)-(z.standard+1)*3600
    return utc>=starts and utc<ends and z.standard+1 or z.standard
end
function SmartChatMsg:GetTimeZoneParts(utc,zone)
    zone=self:NormalizeSchedulingTimeZone(zone or self:GetSchedulingTimeZone())
    local z=zones[zone];local offset=self:GetTimeZoneUtcOffset(utc,zone)
    local p=os.date("!*t",utc+offset*3600)
    p.timezone=offset==z.standard and z.winter or z.daylight
    return p
end
function SmartChatMsg:ParseZonedDateTime(date,time,fold,zone)
    zone=self:NormalizeSchedulingTimeZone(zone or self:GetSchedulingTimeZone())
    local z=zones[zone]
    local year,month,day=tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year,month,day=tonumber(year),tonumber(month),tonumber(day)
    if not year or year<2007 or year>2099 or month<1 or month>12 or day<1 or day>monthDays(year,month) then
        return nil,"Use a valid YYYY-MM-DD date between 2007 and 2099."
    end
    local hour,minute,meridiem=tostring(time or ""):upper():match("^(%d%d?):(%d%d)%s+([AP]M)$")
    hour,minute=tonumber(hour),tonumber(minute)
    if not hour or hour<1 or hour>12 or minute>59 then return nil,"Use a time such as 08:00 PM, with AM or PM." end
    hour=hour%12+(meridiem=="PM" and 12 or 0)
    local wall=civilSeconds(year,month,day,hour,minute);local candidates={}
    for _,offset in ipairs({z.standard+1,z.standard}) do
        local utc=wall-offset*3600
        if self:GetTimeZoneUtcOffset(utc,zone)==offset then candidates[#candidates+1]=utc end
    end
    if #candidates==0 then return nil,"That "..z.name.." time does not exist during the spring DST change."
    elseif #candidates==1 then return candidates[1]
    elseif fold=="FIRST" or fold==z.daylight or fold=="EDT" then return candidates[1]
    elseif fold=="SECOND" or fold==z.winter or fold=="EST" then return candidates[2] end
    return nil,"That "..z.name.." time occurs twice. Choose the first ("..z.daylight..") or second ("..z.winter..") occurrence."
end
function SmartChatMsg:FormatZonedDateTime(utc,zone)
    local p=self:GetTimeZoneParts(utc,zone)
    return string.format("%04d-%02d-%02d %02d:%02d %s %s",p.year,p.month,p.day,
        p.hour%12==0 and 12 or p.hour%12,p.min,p.hour>=12 and "PM" or "AM",p.timezone)
end
function SmartChatMsg:GetScheduleParts(utc,schedule) return self:GetTimeZoneParts(utc,schedule and schedule.timeZone) end
function SmartChatMsg:ParseScheduleDateTime(date,time,fold,schedule) return self:ParseZonedDateTime(date,time,fold,schedule and schedule.timeZone) end
function SmartChatMsg:FormatScheduleDateTime(utc,schedule) return self:FormatZonedDateTime(utc,schedule and schedule.timeZone) end
-- Explicit Eastern helpers retain their meaning for legacy callers and ET text.
function SmartChatMsg:GetEasternUtcOffset(utc) return self:GetTimeZoneUtcOffset(utc,"ET") end
function SmartChatMsg:GetEasternParts(utc) return self:GetTimeZoneParts(utc,"ET") end
function SmartChatMsg:ParseEasternDateTime(date,time,fold) return self:ParseZonedDateTime(date,time,fold,"ET") end
function SmartChatMsg:FormatEasternDateTime(utc) return self:FormatZonedDateTime(utc,"ET") end

function SmartChatMsg:GetSchedulePhase(schedule, utc)
    if schedule.mode=="WINDOW" or schedule.mode=="REMINDER" then return "ANY" end
    local soonMinutes=schedule.startingSoonEnabled and tonumber(schedule.startingSoonMinutes)
    local occurrence=self.GetScheduleOccurrence and self:GetScheduleOccurrence(schedule,utc)
    schedule=occurrence or schedule
    if utc >= schedule.eventAtUtc then return "LIVE" end
    if soonMinutes and utc>=schedule.eventAtUtc-soonMinutes*60 then return "SOON" end
    local event = self:GetScheduleParts(schedule.eventAtUtc,schedule)
    local midnight = self:ParseScheduleDateTime(string.format("%04d-%02d-%02d", event.year, event.month, event.day), "12:00 AM",nil,schedule)
    return utc < midnight and "BEFORE" or "DAY"
end

function SmartChatMsg:GetGuildSchedulingTimeZone(guildName,vars)
    vars=vars or self.savedVars or {}
    local key=guildName and self:NormalizeKey(guildName)
    local overrides=type(vars.guildSchedulingTimeZones)=="table" and vars.guildSchedulingTimeZones or {}
    return self:NormalizeSchedulingTimeZone(key and overrides[key] or vars.schedulingTimeZone)
end
function SmartChatMsg:GetGuildSchedulingTimeZoneOverride(guildName)
    local key=guildName and self:NormalizeKey(guildName)
    local overrides=self.savedVars and self.savedVars.guildSchedulingTimeZones
    return type(overrides)=="table" and key and overrides[key] or "GLOBAL"
end
-- Validate every affected schedule before changing preferences or touching chat.
function SmartChatMsg:RezoneGuildSchedules(affected,zoneForGuild,applyPreference)
    local editor=self.scheduleEditor
    local replacements={}
    for id,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do
        for guild,settings in pairs(byGuild) do
            if settings.schedule and affected(guild) then
                local draft={};for key,value in pairs(settings.schedule) do draft[key]=value end
                draft.timeZone=zoneForGuild(guild);draft.nextDueAt=nil;draft.nextDuePhase=nil;draft.nextDueOccurrence=nil
                draft.completedOccurrences={}
                local schedule,reason=self:NormalizeSchedule(draft)
                if not schedule then return false,"Timezone unchanged: "..tostring(reason) end
                replacements[#replacements+1]={id=id,guild=guild,settings=settings,schedule=schedule}
            end
        end
    end
    for _,replacement in ipairs(replacements) do
        if self.StopScheduledDelivery then self:StopScheduledDelivery(replacement.id,replacement.guild) end
    end
    applyPreference()
    for _,replacement in ipairs(replacements) do replacement.settings.schedule=replacement.schedule end
    self.scheduleEditor=nil
    -- Changing this preference inside Scheduling must not discard unsaved edits.
    if editor and self.GetScheduleEditorDraft then
        local fresh=self:GetScheduleEditorDraft()
        if self.scheduleEditor.key==editor.key then
            if editor.draft.timeZone~=fresh.timeZone then
                editor.draft.nextDueAt=nil;editor.draft.nextDuePhase=nil;editor.draft.nextDueOccurrence=nil
                editor.draft.completedOccurrences={}
            end
            editor.draft.timeZone=fresh.timeZone
            self.scheduleEditor.draft=editor.draft
            self.scheduleEditor.dirty=editor.dirty
        end
    end
    if self.RefreshSettingsUI and self.settings and self.settings.controls then self:RefreshSettingsUI() end
    return true
end
function SmartChatMsg:SetSchedulingTimeZone(zone)
    if not zones[zone] then return false,"Choose ET, CT, MT or PT." end
    if zone==self:GetSchedulingTimeZone() then return true end
    return self:RezoneGuildSchedules(function(guild) return self:GetGuildSchedulingTimeZoneOverride(guild)=="GLOBAL" end,
        function() return zone end,function() self.savedVars.schedulingTimeZone=zone end)
end
function SmartChatMsg:SetGuildSchedulingTimeZone(guildName,zone)
    if zone~="GLOBAL" and not zones[zone] then return false,"Choose Use global default, ET, CT, MT or PT." end
    if not guildName or not self:GetGuildSlotByName(guildName) then return false,"Select an available guild first." end
    local key=self:NormalizeKey(guildName)
    if self:GetGuildSchedulingTimeZoneOverride(guildName)==zone then return true end
    local effective=zone=="GLOBAL" and self:GetSchedulingTimeZone() or zone
    return self:RezoneGuildSchedules(function(guild) return self:NormalizeKey(guild)==key end,
        function() return effective end,function()
            self.savedVars.guildSchedulingTimeZones=self.savedVars.guildSchedulingTimeZones or {}
            self.savedVars.guildSchedulingTimeZones[key]=zone~="GLOBAL" and zone or nil
        end)
end
