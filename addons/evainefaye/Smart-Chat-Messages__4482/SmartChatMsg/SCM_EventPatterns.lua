SmartChatMsg=SmartChatMsg or {}
local factions={AD='Aldmeri Dominion',EP='Ebonheart Pact',DC='Daggerfall Covenant'}

function SmartChatMsg:NormalizeEventPattern(data,result)
    result.specialPattern=data.specialPattern or 'NONE'
    result.messageVariants={}
    local validPatterns={NONE=true,FACTION_ROTATION=true,MONTH_FINAL=true}
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
    local variants={ALL=true,REGULAR=true,FINAL=true,AD=true,EP=true,DC=true}
    for id,variant in pairs(type(data.messageVariants)=='table' and data.messageVariants or {}) do
        if type(id)~='string' or not variants[variant] then return false,'Invalid message event group.' end
        result.messageVariants[id]=result.specialPattern=='MONTH_FINAL' and variant=='ALL' and 'REGULAR' or variant
    end
    return true
end

function SmartChatMsg:GetScheduleEventVariant(schedule,eventAt)
    if schedule.specialPattern=='FACTION_ROTATION' then
        -- Compare schedule-zone calendar dates, preserving rotation blocks across DST.
        local function day(utc) return math.floor((utc+self:GetTimeZoneUtcOffset(utc,schedule.timeZone)*3600)/86400) end
        local weeks=math.floor(math.max(0,day(eventAt)-day(schedule.eventAtUtc))/7)
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

function SmartChatMsg:GetScheduleFactionName(schedule,eventAt)
    return factions[self:GetScheduleEventVariant(schedule,eventAt)]
end

function SmartChatMsg:GetScheduleVariantLabel(variant)
    return factions[variant] or ({ALL='All selected factions',REGULAR='Regular events',FINAL='Month-final events'})[variant] or variant
end

function SmartChatMsg:GetScheduleMessageVariant(schedule,messageId)
    local value=(schedule.messageVariants or {})[messageId]
    if schedule.specialPattern=='FACTION_ROTATION' then return (value=='ALL' or factions[value]) and value or 'ALL' end
    if schedule.specialPattern=='MONTH_FINAL' then return (value=='REGULAR' or value=='FINAL') and value or 'REGULAR' end
    return 'ALL'
end
