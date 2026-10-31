SmartChatMsg=SmartChatMsg or {}
local function characterCount(value) local _,count=value:gsub('[^\128-\191]','');return count end
local progressCache=setmetatable({}, {__mode="k"})
local factions={AD='Aldmeri Dominion',EP='Ebonheart Pact',DC='Daggerfall Covenant'}

function SmartChatMsg:NormalizeEventPattern(data,result)
    result.specialPattern=data.specialPattern or 'NONE'
    result.messageVariants={}
    local validPatterns={NONE=true,FACTION_ROTATION=true,EVENT_ROTATION=true,MONTH_FINAL=true}
    if not validPatterns[result.specialPattern] then return false,'Choose a valid special event pattern.' end
    if result.specialPattern~='NONE' and (result.mode~='EVENT' or result.recurrence=='NONE') then
        return false,'Special patterns require a repeating Promote an event schedule.'
    end
    result.rotationWeeks=tonumber(data.rotationWeeks or 4)
    if not result.rotationWeeks or result.rotationWeeks<1 or result.rotationWeeks>52 or result.rotationWeeks~=math.floor(result.rotationWeeks) then
        if result.specialPattern=='FACTION_ROTATION' then return false,'Weeks per faction must be a whole number from 1 to 52.' end
        result.rotationWeeks=4
    end
    result.rotationFactions={}
    local order=data.rotationFactions or {'AD','EP','DC'}
    local seen={}
    for i=1,3 do
        local faction=order[i]
        if faction and faction~='NONE' then
        if not factions[faction] or seen[faction] then
            if result.specialPattern=='FACTION_ROTATION' then return false,'Choose each faction once in the rotation order.' end
            result.rotationFactions={'AD','EP','DC'};break
        end
        seen[faction]=true;result.rotationFactions[#result.rotationFactions+1]=faction
        end
    end
    if #result.rotationFactions==0 then
        if result.specialPattern=='FACTION_ROTATION' then return false,'Select at least one faction for the rotation.' end
        result.rotationFactions={'AD','EP','DC'}
    end
    result.rotationEvery=tonumber(data.rotationEvery or 1)
    if not result.rotationEvery or result.rotationEvery<1 or result.rotationEvery>1000 or result.rotationEvery~=math.floor(result.rotationEvery) then
        return false,'Occurrences per activity must be a whole number from 1 to 1000.'
    end
    result.rotationEvents={}
    if data.rotationEvents~=nil and type(data.rotationEvents)~='table' then return false,'Activity rotation must be a list.' end
    local activityIds={}
    for i,item in ipairs(data.rotationEvents or {}) do
        if type(item)~='table' or type(item.id)~='string' or item.id=='' or item.id=='ALL' or activityIds[item.id] or type(item.name)~='string' or #self:Trim(item.name)<1 or characterCount(item.name)>80 then
            return false,'Each activity needs a unique stable ID and a name from 1 to 80 characters.'
        end
        activityIds[item.id]=true;result.rotationEvents[i]={id=item.id,name=self:Trim(item.name)}
    end
    for key in pairs(data.rotationEvents or {}) do
        if type(key)~='number' or key<1 or key>#result.rotationEvents or key~=math.floor(key) then return false,'Activity rotation must be an ordered list.' end
    end
    if #result.rotationEvents>50 or result.specialPattern=='EVENT_ROTATION' and #result.rotationEvents<1 then return false,'Choose 1 to 50 activities.' end
    result.occurrenceExceptions={}
    if data.occurrenceExceptions~=nil and type(data.occurrenceExceptions)~='table' then return false,'Occurrence exceptions must be a date map.' end
    for key,value in pairs(data.occurrenceExceptions or {}) do
        if type(key)~='string' or not key:match('^%d%d%d%d%-%d%d%-%d%d$') or not self:ParseScheduleDateTime(key,'12:00 PM','FIRST',result) or type(value)~='table' or (value.action~='KEEP' and value.action~='POSTPONE') then
            return false,'Each cancellation needs a valid YYYY-MM-DD date and KEEP or POSTPONE action.'
        end
        result.occurrenceExceptions[key]={action=value.action}
    end
    local variants={ALL=true,REGULAR=true,FINAL=true,AD=true,EP=true,DC=true}
    for id,variant in pairs(type(data.messageVariants)=='table' and data.messageVariants or {}) do
        if type(id)~='string' or (result.specialPattern=='EVENT_ROTATION' and variant~='ALL' and not activityIds[variant]) or not variants[variant] and not activityIds[variant] then return false,'Invalid message event group.' end
        result.messageVariants[id]=variant
    end
    return true
end

-- Walk actual nominal dates so off-cadence exceptions never change progression.
function SmartChatMsg:GetScheduleRotationProgress(schedule,eventAt)
    local signature={tostring(schedule.eventAtUtc),schedule.recurrence,tostring(schedule.recurrenceInterval),tostring(schedule.monthlyWeek),tostring(schedule.monthlyWeekday),tostring(schedule.eventFold),tostring(schedule.timeZone)}
    for day=1,7 do signature[#signature+1]=schedule.weekdays and schedule.weekdays[day] and '1' or '0' end
    local exceptions={};for date,value in pairs(schedule.occurrenceExceptions or {}) do exceptions[#exceptions+1]=date..':'..value.action end;table.sort(exceptions)
    signature[#signature+1]=table.concat(exceptions,',');local key=table.concat(signature,'|')
    local cached=progressCache[schedule]
    if not cached or cached.key~=key then cached={key=key,events={}};progressCache[schedule]=cached end
    if cached.events[eventAt] then return unpack(cached.events[eventAt]) end
    local ordinal,postponed,heldDays=0,0,0
    local cursor=schedule.eventAtUtc
    while cursor<eventAt do
        local current=self:GetNominalScheduleOccurrences(schedule,cursor,2,true)
        local o=current[1]
        if not o or o.eventAtUtc>=eventAt then break end
        local following=current[2]
        local exception=(schedule.occurrenceExceptions or {})[self:GetScheduleOccurrenceDate(schedule,o.eventAtUtc)]
        if exception and exception.action=='POSTPONE' then
            postponed=postponed+1
            if following then
                local function day(utc) return math.floor((utc+self:GetTimeZoneUtcOffset(utc,schedule.timeZone)*3600)/86400) end
                heldDays=heldDays+day(following.eventAtUtc)-day(o.eventAtUtc)
            end
        end
        ordinal=ordinal+1
        if not following then break end
        cursor=following.eventAtUtc
    end
    cached.events[eventAt]={ordinal-postponed,heldDays}
    return ordinal-postponed,heldDays
end
function SmartChatMsg:GetScheduleEventVariant(schedule,eventAt)
    if schedule.specialPattern=='EVENT_ROTATION' then
        local progress=self:GetScheduleRotationProgress(schedule,eventAt)
        return schedule.rotationEvents[math.floor(math.max(0,progress)/(schedule.rotationEvery or 1))%#schedule.rotationEvents+1].id
    elseif schedule.specialPattern=='FACTION_ROTATION' then
        local function day(utc) return math.floor((utc+self:GetTimeZoneUtcOffset(utc,schedule.timeZone)*3600)/86400) end
        local held=0
        if next(schedule.occurrenceExceptions or {}) then local ignored;ignored,held=self:GetScheduleRotationProgress(schedule,eventAt) end
        local weeks=math.floor(math.max(0,day(eventAt)-day(schedule.eventAtUtc)-held)/7)
        local index=math.floor(weeks/schedule.rotationWeeks)%#schedule.rotationFactions+1
        return schedule.rotationFactions[index]
    elseif schedule.specialPattern=='MONTH_FINAL' then
        local nextEvent=self:GetUpcomingScheduleOccurrences(schedule,eventAt+1,1,true)[1]
        if not nextEvent then return 'FINAL' end
        local current,nextParts=self:GetScheduleParts(eventAt,schedule),self:GetScheduleParts(nextEvent.eventAtUtc,schedule)
        return (current.year~=nextParts.year or current.month~=nextParts.month) and 'FINAL' or 'REGULAR'
    end
    return 'ALL'
end
function SmartChatMsg:GetScheduleActivityName(schedule,eventAt)
    local id=self:GetScheduleEventVariant(schedule,eventAt)
    for _,activity in ipairs(schedule.rotationEvents or {}) do if activity.id==id then return activity.name end end
end

function SmartChatMsg:GetScheduleFactionName(schedule,eventAt)
    return factions[self:GetScheduleEventVariant(schedule,eventAt)]
end

function SmartChatMsg:GetScheduleVariantLabel(variant,pattern,schedule)
    if schedule then for _,activity in ipairs(schedule.rotationEvents or {}) do if activity.id==variant then return activity.name end end end
    if pattern=='EVENT_ROTATION' and variant=='ALL' then return 'All activities' end
    if variant=='ALL' and pattern=='MONTH_FINAL' then return 'All events' end
    return factions[variant] or ({ALL='All selected factions',REGULAR='Regular events',FINAL='Month-final events'})[variant] or variant
end

function SmartChatMsg:GetScheduleMessageVariant(schedule,messageId)
    local value=(schedule.messageVariants or {})[messageId]
    if schedule.specialPattern=='FACTION_ROTATION' then return (value=='ALL' or factions[value]) and value or 'ALL' end
    if schedule.specialPattern=='EVENT_ROTATION' then
        for _,activity in ipairs(schedule.rotationEvents or {}) do if activity.id==value then return value end end
        return 'ALL'
    end
    if schedule.specialPattern=='MONTH_FINAL' then return (value=='REGULAR' or value=='FINAL' or value=='ALL') and value or 'REGULAR' end
    return 'ALL'
end
