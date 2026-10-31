SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local function copy(t) if type(t)~='table' then return t end;local r={};for k,v in pairs(t) do r[k]=copy(v) end;return r end
local function integer(v,min,max) return type(v)=='number' and v==math.floor(v) and v>=min and v<=max end
local function anchor(a,marks)
 if type(a)~='table' then return nil end
 if a.kind=='OFFSET' and integer(a.minutes,-5256000,5256000) then return copy(a) end
 if a.kind=='DAY' and integer(a.days,-3650,3650) and type(a.time)=='string' and a.time:match('^%d%d?:%d%d [AP]M$') then return copy(a) end
 if a.kind=='MARK' and type(a.name)=='string' and marks[a.name] then return copy(a) end
end
function S:ResolveTimelineAnchor(config,occurrence,a)
 if not a then return nil end
 if a.kind=='OFFSET' then return occurrence.eventAtUtc+a.minutes*60 end
 if a.kind=='MARK' then local mark=(config.importantTimes or {})[a.name];return mark and occurrence.eventAtUtc+mark.offsetMinutes*60 end
 if a.kind=='DAY' then
  local event=self:GetScheduleParts(occurrence.eventAtUtc,config)
  -- Normalize a civil calendar date through UTC noon, then resolve its wall time.
  local day=self:ParseScheduleDateTime(string.format('%04d-%02d-%02d',event.year,event.month,event.day),'12:00 PM','FIRST',config)
  if not day then return nil end
  local civil=os.date('!*t',day+self:GetTimeZoneUtcOffset(day,config.timeZone)*3600+a.days*86400)
  return self:ParseScheduleDateTime(string.format('%04d-%02d-%02d',civil.year,civil.month,civil.day),a.time,a.fold or 'FIRST',config)
 end
end
-- One definition is shared by selection, queue revalidation and peer matching.
-- A once notice exactly on the event end retains its short delivery grace.
function S:GetTimelineReminderWindow(config,occurrence,row)
 local start=self:ResolveTimelineAnchor(config,occurrence,row.start)
 local finish=row.once and not row.onceUntilFinish and start and start+row.lateMinutes*60 or self:ResolveTimelineAnchor(config,occurrence,row.finish)
 if start and finish and config.eventDurationMinutes~=nil and not row.allowAfterEventEnd then
  local ending=occurrence.eventAtUtc+config.eventDurationMinutes*60
  if not (row.once and start==ending) then finish=math.min(finish,ending) end
 end
 return start,finish
end
local normalize=S.NormalizeSchedule
function S:NormalizeSchedule(data)
 local candidate=data
 if type(data)=='table' and data.timelineVersion then candidate=copy(data);candidate.promotionDays=0;candidate.endDelayMinutes=1 end
 local result,reason=normalize(self,candidate)
 if result and type(data.mergedInto)=='string' then result.mergedInto=data.mergedInto end
 if not result or not data.timelineVersion then return result,reason end
 if data.timelineVersion~=1 or result.mode~='EVENT' then return nil,'Unsupported event timeline version or mode.' end
 result.legacyTimelineBackup=copy(data.legacyTimelineBackup)
 if data.eventDurationMinutes~=nil then
  if not integer(data.eventDurationMinutes,0,5256000) then return nil,'Event duration must be a whole number of minutes, zero or more, or blank.' end
  result.eventDurationMinutes=data.eventDurationMinutes
 end
 result.timelineVersion=1;result.importantTimes={};result.reminders={};result.timelineUsage={}
 if type(data.reminders)~='table' or data.importantTimes~=nil and type(data.importantTimes)~='table' then return nil,'Choose reminder rows and valid important times.' end
 for key,usage in pairs(type(data.timelineUsage)=='table' and data.timelineUsage or {}) do
  if type(key)=='string' and type(usage)=='table' then
   local valid={completed=usage.completed==true}
   for _,field in ipairs({'lastSentAt','nextDueAt','peerAt'}) do if integer(usage[field],0,253402300799) then valid[field]=usage[field] end end
   result.timelineUsage[key]=valid
  end
 end
 for id,mark in pairs(data.importantTimes or {}) do
  if type(id)~='string' or id~=zo_strlower(id) or not id:match('^[%a][%w_]*$') or type(mark)~='table' or not integer(mark.offsetMinutes,-5256000,5256000) then return nil,'Invalid important time.' end
  result.importantTimes[id]={label=tostring(mark.label or id),offsetMinutes=mark.offsetMinutes}
 end
 local ids={}
 for _,raw in ipairs(data.reminders or {}) do
  if type(raw)~='table' then return nil,'Invalid reminder row.' end
  if type(raw.id)~='string' or raw.id=='' or ids[raw.id] then return nil,'Reminder IDs must be unique.' end;ids[raw.id]=true
  local row={id=raw.id,label=tostring(raw.label or 'Reminder'),start=anchor(raw.start,result.importantTimes),finish=anchor(raw.finish,result.importantTimes),once=raw.once==true,onceUntilFinish=raw.onceUntilFinish==true,timeSensitive=raw.timeSensitive==true,enabled=raw.enabled~=false,paused=raw.paused==true,allowAfterEventEnd=raw.allowAfterEventEnd==true,lateMinutes=raw.lateMinutes or 5,intervalMinutes=raw.intervalMinutes or 60,messageIds={}}
  if not row.start or (not row.once or row.onceUntilFinish) and not row.finish or not integer(row.intervalMinutes,1,5256000) or not integer(row.lateMinutes,1,1440) then return nil,'Check reminder times, interval and lateness allowance.' end
  if raw.messageIds~=nil and type(raw.messageIds)~='table' then return nil,'Choose a valid message pool.' end
  local messages={};for _,id in ipairs(raw.messageIds or {}) do if type(id)~='string' or messages[id] then return nil,'Invalid reminder message selection.' end;messages[id]=true;row.messageIds[#row.messageIds+1]=id end
  result.reminders[#result.reminders+1]=row
 end
 if #result.reminders>100 or #result.reminders==0 then return nil,'Choose between one and 100 reminders.' end
 local occurrence={eventAtUtc=result.eventAtUtc}
 -- An explicit monthly selector can place its first event after the stored
 -- recurrence anchor. Validate reminder clocks on that real occurrence.
 if result.recurrence=='MONTHLY_WEEKDAY' then
  occurrence=self:GetNominalScheduleOccurrences(result,result.eventAtUtc,1,true)[1]
  if not occurrence then return nil,'No monthly weekday occurrence exists in the supported date range.' end
 end
 local first,last
 for _,row in ipairs(result.reminders) do
  local start=self:ResolveTimelineAnchor(result,occurrence,row.start)
  local finish=row.once and not row.onceUntilFinish and start and start+row.lateMinutes*60 or self:ResolveTimelineAnchor(result,occurrence,row.finish)
  if not start or not finish or finish<=start then return nil,'Reminder end must be after its start.' end
  start,finish=self:GetTimelineReminderWindow(result,occurrence,row)
  if finish>start then first=math.min(first or start,start);last=math.max(last or finish,finish) end
 end
 result.startsAtUtc,result.endsAtUtc=first or result.eventAtUtc,last or result.eventAtUtc
 return result
end
local build=S.BuildScheduleOccurrence
function S:BuildScheduleOccurrence(config,event)
 local occurrence=build(self,config,event);if not occurrence or not config.timelineVersion then return occurrence end
 local first,last
 for _,row in ipairs(config.reminders or {}) do
  local start,finish=self:GetTimelineReminderWindow(config,occurrence,row)
  -- A future civil clock can fall in the DST gap; other rows still apply.
  if start and finish and finish>start then first=math.min(first or start,start);last=math.max(last or finish,finish) end
 end
 occurrence.eventEndsAtUtc=config.eventDurationMinutes~=nil and event+config.eventDurationMinutes*60 or nil
 occurrence.startsAtUtc,occurrence.endsAtUtc=first or event,last or event;return occurrence
end
function S:GetActiveTimelineReminder(config,utc)
 if not config or config.timelineVersion~=1 then return nil end
 local occurrence=self:GetScheduleOccurrence(config,utc);if not occurrence then return nil end
 local picked,from,to
 for _,row in ipairs(config.reminders) do
  local start,finish=self:GetTimelineReminderWindow(config,occurrence,row)
  local usage=(config.timelineUsage or {})[occurrence.occurrenceKey..':'..row.id]
  local available,allowedStart,allowedFinish=true
  if self.GetReminderAvailabilityStatus then available,allowedStart,allowedFinish=self:GetReminderAvailabilityStatus(config,row,occurrence,utc) end
  if start and finish and available and row.enabled~=false and not row.paused and utc>=start and utc<finish and not(row.once and usage and usage.completed) then
   start,finish=allowedStart or start,allowedFinish or finish
   if not picked or row.timeSensitive and not picked.timeSensitive or row.timeSensitive==picked.timeSensitive and (start>from or start==from and row.once and not picked.once) then picked,from,to=row,start,finish end
  end
 end
 return picked,from,to,occurrence
end
local phase=S.GetSchedulePhase
function S:GetSchedulePhase(config,utc)
 if config.timelineVersion==1 then local row=self:GetActiveTimelineReminder(config,utc);return row and row.id or 'IDLE' end
 return phase(self,config,utc)
end
local entries=S.GetScheduledMessageEntries
function S:GetScheduledMessageEntries(id,guild)
 local config=self:GetGuildSchedule(id,guild);if not config or config.timelineVersion~=1 then return entries(self,id,guild) end
 if self:GetGuildScheduleState(id,guild)~='RUNNING' then return {} end
 local row,_,_,occurrence=self:GetActiveTimelineReminder(config,GetTimeStamp());if not row then return {} end
 local selected={};for _,key in ipairs(row.messageIds) do selected[key]=true end
 local variant=self:GetScheduleEventVariant(config,occurrence.eventAtUtc)
 local all=self:GetMessageEntriesForCommandAndGuild(id,guild);local hasFinal=false
 for _,entry in ipairs(all) do if selected[entry.id] and self:GetScheduleMessageVariant(config,entry.id)=='FINAL' then hasFinal=true end end
 if config.specialPattern=='MONTH_FINAL' and variant=='FINAL' and not hasFinal then variant='REGULAR' end
 local result={};for _,entry in ipairs(all) do local group=self:GetScheduleMessageVariant(config,entry.id)
  if selected[entry.id] and (config.specialPattern=='NONE' or group=='ALL' or group==variant) then result[#result+1]=entry end
 end;return result
end
local pacing=S.GetSchedulePacingDelay
function S:GetSchedulePacingDelay(id,guild)
 local row=self:GetActiveTimelineReminder(self:GetGuildSchedule(id,guild),GetTimeStamp())
 if row and row.timeSensitive and not (self.scheduleStartupEndsAt and GetTimeStamp()<self.scheduleStartupEndsAt) then return nil end
 return pacing(self,id,guild)
end
local cooldown=S.GetScheduledCooldownStart
function S:GetScheduledCooldownStart(id,guild)
 local config=self:GetGuildSchedule(id,guild)
 if config and config.timelineVersion==1 then local _,start=self:GetActiveTimelineReminder(config,GetTimeStamp());return start end
 return cooldown(self,id,guild)
end
local interval=S.GetScheduleIntervalMinutes
function S:GetScheduleIntervalMinutes(id,guild)
 local row=self:GetActiveTimelineReminder(self:GetGuildSchedule(id,guild),GetTimeStamp())
 if row then return row.intervalMinutes end;return interval(self,id,guild)
end
local due=S.GetScheduledDueAt
function S:GetScheduledDueAt(id,guild,phase)
 local config=self:GetGuildSchedule(id,guild);if not config or config.timelineVersion~=1 then return due(self,id,guild,phase) end
 local row,start,_,occurrence=self:GetActiveTimelineReminder(config,GetTimeStamp());if not row then return math.huge end
 local usage=(config.timelineUsage or {})[occurrence.occurrenceKey..':'..row.id] or {}
 if row.once and usage.completed then return math.huge end
 local nextDue=usage.nextDueAt or start
 if not row.timeSensitive then
  local observed=self:GetObservedCommandCooldownEndsAt(id,guild,self:GetSavedChatChannel(id,guild))
  if observed then nextDue=math.max(nextDue,observed) end
 end
 return nextDue
end
local nextDelivery=S.ScheduleNextScheduledDelivery
function S:ScheduleNextScheduledDelivery(id,guild,delay)
 local config=self:GetGuildSchedule(id,guild);if not config or config.timelineVersion~=1 then return nextDelivery(self,id,guild,delay) end
 local row,_,_,occurrence=self:GetActiveTimelineReminder(config,GetTimeStamp());if not row then return end
 config.timelineUsage=config.timelineUsage or {};local key=occurrence.occurrenceKey..':'..row.id
 local usage=config.timelineUsage[key] or {};config.timelineUsage[key]=usage
 usage.nextDueAt=GetTimeStamp()+row.intervalMinutes*60+(delay or 0)
end
local confirmed=S.HandleScheduledSendConfirmed
function S:HandleScheduledSendConfirmed(metadata)
 confirmed(self,metadata)
 if not metadata or not metadata.scheduledDelivery then return end
 local config=self:GetGuildSchedule(metadata.commandId,metadata.guildName);if not config or config.timelineVersion~=1 then return end
 for _,row in ipairs(config.reminders) do if row.id==metadata.scheduledPhase then
  config.timelineUsage=config.timelineUsage or {};local key=metadata.scheduledOccurrence..':'..row.id
  local usage=config.timelineUsage[key] or {};config.timelineUsage[key]=usage
  usage.lastSentAt=GetTimeStamp();usage.completed=row.once or nil;usage.nextDueAt=GetTimeStamp()+row.intervalMinutes*60
 end end
end
local queue=S.QueueChatPopulation
function S:QueueChatPopulation(id,guild,channel,metadata,priority)
 if metadata and metadata.scheduledDelivery then
  local row=self:GetActiveTimelineReminder(self:GetGuildSchedule(id,guild),GetTimeStamp())
  if row and row.timeSensitive then priority=0 end
 end
 return queue(self,id,guild,channel,metadata,priority)
end
local description=S.GetSchedulePhaseDescription
function S:GetSchedulePhaseDescription(id,guild)
 local row=self:GetActiveTimelineReminder(self:GetGuildSchedule(id,guild),GetTimeStamp())
 if row then return row.label..(row.once and ' (one announcement)' or ' (every '..row.intervalMinutes..' minutes)'),row.id end
 return description(self,id,guild)
end
local observed=S.MarkObservedChatUsage
function S:MarkObservedChatUsage(entry,guild,channel,matchingEntries)
 local config=self:GetGuildSchedule(entry.commandId,guild)
 local occurrence=config and config.timelineVersion==1 and self:GetScheduleOccurrence(config,GetTimeStamp())
 if occurrence then
  config.timelineUsage=config.timelineUsage or {}
  for _,row in ipairs(config.reminders) do
   local relevant=false
   for _,candidate in ipairs(matchingEntries or {entry}) do
    for _,messageId in ipairs(row.messageIds) do if messageId==candidate.id and (not row.availability or not row.availability.enabled or self:IsReminderMessageVariantEligible(config,row,candidate,guild,occurrence)) then relevant=true;break end end
    if relevant then break end
   end
   local start,finish=self:GetTimelineReminderWindow(config,occurrence,row)
   if relevant and start and finish and row.enabled~=false and not row.paused and GetTimeStamp()>=start and GetTimeStamp()<finish then
    local key=occurrence.occurrenceKey..':'..row.id;local usage=config.timelineUsage[key] or {};config.timelineUsage[key]=usage
    usage.peerAt=GetTimeStamp();usage.completed=row.once or nil;usage.nextDueAt=GetTimeStamp()+row.intervalMinutes*60+zo_random(30,90)
   end
  end
 end
 return observed(self,entry,guild,channel)
end
local observedDeadline=S.GetObservedCommandCooldownEndsAt
function S:GetObservedCommandCooldownEndsAt(id,guild,channel)
 local config=self:GetGuildSchedule(id,guild)
 if not config or config.timelineVersion~=1 then return observedDeadline(self,id,guild,channel) end
 local row,start,_,occurrence=self:GetActiveTimelineReminder(config,GetTimeStamp())
 if not row then return nil end
 if row.timeSensitive then
  local usage=(config.timelineUsage or {})[occurrence.occurrenceKey..':'..row.id]
  return usage and usage.peerAt and usage.nextDueAt or nil
 end
 local settings=self:GetCommandGuildSettings(id,guild,false)
 local relevant=false
 for _,usage in pairs(settings and settings.observedChatCooldowns or {}) do if usage.at>=start then relevant=true end end
 return relevant and observedDeadline(self,id,guild,channel) or nil
end
local markObserved=S.MarkObservedChatUsage
function S:MarkObservedChatUsage(entry,guild,channel,matchingEntries)
 local row=self:GetActiveTimelineReminder(self:GetGuildSchedule(entry.commandId,guild),GetTimeStamp())
 local contains=false;if row then for _,candidate in ipairs(matchingEntries or {entry}) do for _,id in ipairs(row.messageIds) do if id==candidate.id then contains=true end end end end
 self.timelineIgnoreUnrelatedPeer=row and row.timeSensitive and not contains and {id=entry.commandId,guild=guild} or nil
 local ok,reason=pcall(markObserved,self,entry,guild,channel,matchingEntries)
 self.timelineIgnoreUnrelatedPeer=nil
 if not ok then error(reason) end
end
local function ignorePeer(self,id,guild)
 local active=self.timelineIgnoreUnrelatedPeer
 return active and active.id==id and self:StringsEqualIgnoreCase(active.guild,guild)
end
local withdraw=S.WithdrawObservedChatDuplicate
function S:WithdrawObservedChatDuplicate(id,guild) if not ignorePeer(self,id,guild) then return withdraw(self,id,guild) end end
local cancel=S.CancelQueuedChatPopulation
function S:CancelQueuedChatPopulation(id,guild) if not ignorePeer(self,id,guild) then return cancel(self,id,guild) end end
local nextScheduled=S.ScheduleNextScheduledDelivery
function S:ScheduleNextScheduledDelivery(id,guild,delay) if not ignorePeer(self,id,guild) then return nextScheduled(self,id,guild,delay) end end
local process=S.ProcessChatPopulationQueue
function S:ProcessChatPopulationQueue()
 local pending=self.pendingRestoreState
 local metadata=pending and pending.metadata
 if metadata and metadata.scheduledDelivery then
  local current=self:GetActiveTimelineReminder(self:GetGuildSchedule(metadata.commandId,metadata.guildName),GetTimeStamp())
  if not current or not current.timeSensitive then
   for _,request in pairs(self.chatPopulationQueue or {}) do
    local row=self:GetActiveTimelineReminder(self:GetGuildSchedule(request.commandId,request.guildName),GetTimeStamp())
    if request.metadata.scheduledDelivery and row and row.timeSensitive and not self:GetSchedulePacingDelay(request.commandId,request.guildName)
     and GetTimeStamp()>=self:GetScheduledDueAt(request.commandId,request.guildName,row.id) then
     -- WithdrawScheduledPending only clears untouched addon text, preserving user edits.
     self:WithdrawScheduledPending(metadata.commandId,metadata.guildName)
     break
    end
   end
  end
 end
 return process(self)
end
