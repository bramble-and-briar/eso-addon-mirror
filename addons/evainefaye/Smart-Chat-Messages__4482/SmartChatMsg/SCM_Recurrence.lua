SmartChatMsg = SmartChatMsg or {}
local occurrenceCache=setmetatable({}, {__mode="k"})
local function date(p) return string.format('%04d-%02d-%02d',p.year,p.month,p.day) end
local function time(p) return string.format('%02d:%02d %s',p.hour%12==0 and 12 or p.hour%12,p.min,p.hour>=12 and 'PM' or 'AM') end
local function dayNumber(p)
    local days=0
    for y=1970,p.year-1 do days=days+((y%4==0 and (y%100~=0 or y%400==0)) and 366 or 365) end
    local lengths={31,28,31,30,31,30,31,31,30,31,30,31}
    if p.year%4==0 and (p.year%100~=0 or p.year%400==0) then lengths[2]=29 end
    for m=1,p.month-1 do days=days+lengths[m] end
    return days+p.day-1
end
local function civilUtc(self,p,fold,schedule)
    return self:ParseScheduleDateTime(date(p),time(p),fold or 'FIRST',schedule)
end
function SmartChatMsg:BuildScheduleOccurrence(s,event)
    local mode=s.mode or 'EVENT'
    local anchor=mode=='EVENT' and s.eventAtUtc or s.startsAtUtc
    if not anchor then return nil end
    local ap=self:GetScheduleParts(anchor,s)
    local ep=self:GetScheduleParts(event,s)
    local delta=dayNumber(ep)-dayNumber(ap)
    local function shift(value,fold)
        local p=self:GetScheduleParts(value,s)
        local target=os.date('!*t',(dayNumber(p)+delta)*86400)
        target.hour,target.min=p.hour,p.min
        return civilUtc(self,target,fold,s)
    end
    local starts,ends
    if mode=='REMINDER' then starts,ends=event,event+120
    elseif mode=='EVENT' and s.promotionDays~=nil then
        local p=os.date('!*t',(dayNumber(ep)-s.promotionDays)*86400);p.hour,p.min=ep.hour,ep.min
        if s.promotionDays==0 then p.hour,p.min=0,0 end
        starts=civilUtc(self,p,s.eventFold,s);ends=event+(s.endDelayMinutes or 60)*60
    else starts,ends=shift(s.startsAtUtc,s.startFold),shift(s.endsAtUtc,s.endFold) end
    if not starts or not ends then return nil end
    return {startsAtUtc=starts,eventAtUtc=event,endsAtUtc=ends,occurrenceKey=tostring(event),mode=mode,timeZone=s.timeZone}
end
function SmartChatMsg:GetScheduleOccurrenceDate(s,eventAt)
    return date(self:GetScheduleParts(eventAt,s))
end
function SmartChatMsg:IsScheduleOccurrenceCancelled(s,eventAt)
    return (s.occurrenceExceptions or {})[self:GetScheduleOccurrenceDate(s,eventAt)]~=nil
end
-- Nominal projection deliberately includes cancellations, for rotation arithmetic and Undo.
function SmartChatMsg:GetNominalScheduleOccurrences(s,utc,count,futureEventsOnly)
    return self:GetUpcomingScheduleOccurrences(s,utc,count,futureEventsOnly,true)
end
function SmartChatMsg:GetUpcomingScheduleOccurrences(s,utc,count,futureEventsOnly,includeCancelled)
    if not s or not s.startsAtUtc then return {} end
    utc=utc or GetTimeStamp();count=count or 3
    local anchor=(s.mode or 'EVENT')=='EVENT' and s.eventAtUtc or s.startsAtUtc
    local ap=self:GetScheduleParts(anchor,s);local ad=dayNumber(ap)
    local recurrence=s.recurrence or 'NONE';local interval=s.recurrenceInterval or 1
    if recurrence=='NONE' then local o=self:BuildScheduleOccurrence(s,anchor);return o and (includeCancelled or not self:IsScheduleOccurrenceCancelled(s,anchor)) and (futureEventsOnly and o.eventAtUtc>=utc or not futureEventsOnly and o.endsAtUtc>utc) and {o} or {} end
    local cp=self:GetScheduleParts(utc,s);local cd=dayNumber(cp)
    local lead=math.ceil(math.max(s.eventAtUtc-s.startsAtUtc,s.endsAtUtc-s.eventAtUtc)/86400)+2
    local cache=occurrenceCache[s] or {}
    occurrenceCache[s]=cache
    local exceptions={}
    for key,value in pairs(s.occurrenceExceptions or {}) do exceptions[#exceptions+1]=key..':'..tostring(value.action) end
    table.sort(exceptions)
    local cacheKey=tostring(s.monthlyWeek)..':'..tostring(s.monthlyWeekday)..':'..tostring(s.recurrence)..':'..tostring(interval)..':'..tostring(count)..':'..tostring(futureEventsOnly)..':'..tostring(includeCancelled)..':'..table.concat(exceptions,',')
    local cached=cache[cacheKey]
    if cached and cached.count==count and utc>=cached.at
        and (#cached.value==0 or (futureEventsOnly and utc<=cached.value[1].eventAtUtc or not futureEventsOnly and utc<cached.value[1].endsAtUtc)) then return cached.value end
    local first=math.max(ad,futureEventsOnly and cd or cd-lead)
    local out={}
    for day=first,dayNumber({year=2099,month=12,day=31}) do
        local p=os.date('!*t',day*86400);local offset=day-ad;local eligible=false
        local selected=type(s.weekdays)=='table' and next(s.weekdays)~=nil
        if recurrence=='DAILY' then eligible=offset%interval==0 and (not selected or s.weekdays[p.wday])
        elseif recurrence=='WEEKLY' or recurrence=='BIWEEKLY' then
            local weeks=recurrence=='BIWEEKLY' and 2*interval or interval
            local anchorSunday=ad-(ap.wday-1)
            eligible=math.floor((day-anchorSunday)/7)%weeks==0 and (selected and s.weekdays[p.wday] or not selected and p.wday==ap.wday)
        elseif recurrence=='MONTHLY_DATE' or recurrence=='MONTHLY_WEEKDAY' then
            local months=(p.year-ap.year)*12+p.month-ap.month
            local week=s.monthlyWeek or math.floor((ap.day-1)/7)+1
            local nextWeek=os.date('!*t',(day+7)*86400)
            local ordinalMatches=week=='LAST' and nextWeek.month~=p.month or week~='LAST' and math.floor((p.day-1)/7)+1==week
            eligible=months%interval==0 and (recurrence=='MONTHLY_DATE' and p.day==ap.day or recurrence=='MONTHLY_WEEKDAY' and p.wday==(s.monthlyWeekday or ap.wday) and ordinalMatches)
        end
        if eligible then
            p.hour,p.min=ap.hour,ap.min
            local event=civilUtc(self,p,(s.mode or 'EVENT')=='EVENT' and s.eventFold or s.startFold,s)
            local o=event and self:BuildScheduleOccurrence(s,event)
            -- A real event still consumes its rotation slot when a promotion
            -- wall clock falls in a DST gap. Delivery keeps its usual bounds.
            if event and not o and includeCancelled then
                o={eventAtUtc=event,startsAtUtc=event,endsAtUtc=event,occurrenceKey=tostring(event),mode=s.mode or 'EVENT',timeZone=s.timeZone}
            end
            if o and (includeCancelled or not self:IsScheduleOccurrenceCancelled(s,event)) and (futureEventsOnly and o.eventAtUtc>=utc or not futureEventsOnly and o.endsAtUtc>utc) then
                o.cancelled=self:IsScheduleOccurrenceCancelled(s,event)
                o.exceptionAction=o.cancelled and s.occurrenceExceptions[self:GetScheduleOccurrenceDate(s,event)].action or nil
                out[#out+1]=o;if #out>=count then break end
            end
        end
    end
    cache[cacheKey]={count=count,at=utc,value=out}
    return out
end
function SmartChatMsg:GetScheduleOccurrence(s,utc)
    local occurrences=self:GetUpcomingScheduleOccurrences(s,utc,1)
    return occurrences[1]
end
