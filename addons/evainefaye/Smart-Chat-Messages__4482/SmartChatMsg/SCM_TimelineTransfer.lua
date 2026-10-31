SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local function clone(t) if type(t)~='table' then return t end;local r={};for k,v in pairs(t) do r[k]=clone(v) end;return r end
local kinds={SCHEDULETIMELINE_V1=true,SCHEDULEMARK_V1=true,SCHEDULEROW_V1=true,SCHEDULEPOOL_V1=true,SCHEDULEUSAGE_V1=true}
local export=S.ExportScheduleRecords
function S:ExportScheduleRecords()
 local lines=export(self)
 local function add(fields) for i,value in ipairs(fields) do fields[i]=self:EscapeImportExportField(tostring(value)) end;lines[#lines+1]=table.concat(fields,'|') end
 for id,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do for guild,settings in pairs(byGuild) do local config=settings.schedule
  if config and config.timelineVersion==1 then
   add({'SCHEDULETIMELINE_V1',id,guild,1,config.eventDurationMinutes or ''})
   for name,mark in pairs(config.importantTimes or {}) do add({'SCHEDULEMARK_V1',id,guild,name,mark.label,mark.offsetMinutes}) end
   for _,row in ipairs(config.reminders) do
    local fields={'SCHEDULEROW_V1',id,guild,row.id,row.label,row.once and '1' or '0',row.timeSensitive and '1' or '0',row.intervalMinutes,row.lateMinutes,row.onceUntilFinish and '1' or '0'}
    for _,a in ipairs({row.start,row.finish or {}}) do for _,k in ipairs({'kind','minutes','days','time','name','fold'}) do fields[#fields+1]=a[k] or '' end end
    fields[#fields+1]=row.enabled==false and '0' or '1';fields[#fields+1]=row.paused and '1' or '0';fields[#fields+1]=row.allowAfterEventEnd and '1' or '0'
    add(fields)
    for _,messageId in ipairs(row.messageIds) do if not self:IsMessageLocked(messageId) then add({'SCHEDULEPOOL_V1',id,guild,row.id,messageId}) end end
   end
   for key,usage in pairs(config.timelineUsage or {}) do add({'SCHEDULEUSAGE_V1',id,guild,key,usage.lastSentAt or '',usage.nextDueAt or '',usage.peerAt or '',usage.completed and '1' or '0'}) end
  end
 end end
 return lines
end
local import=S.ImportScheduleRecords
function S:ImportScheduleRecords(records,imported)
 local legacy,new={},{}
 for _,row in ipairs(records) do if kinds[row[1]] then local decoded={};for i,v in ipairs(row) do decoded[i]=self:UnescapeImportExportField(v) end;new[#new+1]=decoded else legacy[#legacy+1]=row end end
 local ok,reason=import(self,legacy,imported);if not ok then return false,reason end
 local candidates={}
 for _,row in ipairs(new) do
  local id,guild=row[2],self:NormalizeKey(row[3]);local settings=guild and imported.commandGuildSettings[id] and imported.commandGuildSettings[id][guild]
  if settings and settings.schedule then
   local key=id..'\n'..guild;local d=candidates[key]
   if not d then d=clone(settings.schedule);d.importantTimes={};d.reminders={};d.timelineUsage={};candidates[key]={draft=d,settings=settings};else d=d.draft end
   if row[1]=='SCHEDULETIMELINE_V1' then if row[4]~='1' then return false,'Unsupported timeline version.' end;d.timelineVersion=1;d.eventDurationMinutes=tonumber(row[5])
   elseif row[1]=='SCHEDULEMARK_V1' then if d.importantTimes[row[4]] then return false,'Duplicate important time.' end;d.importantTimes[row[4]]={label=row[5],offsetMinutes=tonumber(row[6])}
   elseif row[1]=='SCHEDULEROW_V1' then
    local reminder={id=row[4],label=row[5],once=row[6]=='1',timeSensitive=row[7]=='1',intervalMinutes=tonumber(row[8]),lateMinutes=tonumber(row[9]),onceUntilFinish=row[10]=='1',enabled=row[23]~='0',paused=row[24]=='1',allowAfterEventEnd=row[25]=='1',messageIds={}}
    local index=11;for _,name in ipairs({'start','finish'}) do local a={};for _,field in ipairs({'kind','minutes','days','time','name','fold'}) do local value=row[index];index=index+1;if value and value~='' then a[field]=(field=='minutes' or field=='days') and tonumber(value) or value end end;reminder[name]=next(a) and a or nil end
    d.reminders[#d.reminders+1]=reminder
   elseif row[1]=='SCHEDULEUSAGE_V1' then d.timelineUsage[row[4]]={lastSentAt=tonumber(row[5]),nextDueAt=tonumber(row[6]),peerAt=tonumber(row[7]),completed=row[8]=='1'} end
  end
 end
 for _,row in ipairs(new) do if row[1]=='SCHEDULEPOOL_V1' then
  local candidate=candidates[row[2]..'\n'..self:NormalizeKey(row[3])];local found=false
  if candidate then for _,reminder in ipairs(candidate.draft.reminders) do if reminder.id==row[4] then reminder.messageIds[#reminder.messageIds+1]=row[5];found=true end end end
  if candidate and not found then return false,'Imported pool references a missing reminder.' end
 end end
 for _,candidate in pairs(candidates) do
  if not candidate.draft.timelineVersion then return false,'Timeline record missing its version.' end
  local normalized,error=self:NormalizeSchedule(candidate.draft);if not normalized then return false,'Imported timeline: '..tostring(error) end;candidate.settings.schedule=normalized
 end
 return true
end
local preserve=S.PreserveLockedMessages
function S:PreserveLockedMessages(imported)
 preserve(self,imported)
 for _,entry in ipairs(imported.messages or {}) do if entry.locked then
  local guild=entry.guildName or self:GetGuildNameByIndex(entry.guildIndex);local oldId
  local newCommand;for _,command in ipairs(imported.commands) do if command.id==entry.commandId then newCommand=command end end
  for _,command in ipairs(self:GetCommands()) do if newCommand and (command.id==newCommand.id or zo_strlower(command.name)==zo_strlower(newCommand.name)) then oldId=command.id;break end end
  local old=oldId and self:GetGuildSchedule(oldId,guild)
  local key=self:NormalizeKey(guild);local settings=key and imported.commandGuildSettings[entry.commandId] and imported.commandGuildSettings[entry.commandId][key]
  local target=settings and settings.schedule
  if old and target and old.timelineVersion==1 and target.timelineVersion==1 then
   local selected={};for _,row in ipairs(old.reminders) do for _,id in ipairs(row.messageIds) do if id==entry.id then selected[row.id]=true end end end
   for _,row in ipairs(target.reminders) do local ids={};for _,id in ipairs(row.messageIds) do if id~=entry.id then ids[#ids+1]=id end end;if selected[row.id] then ids[#ids+1]=entry.id end;row.messageIds=ids end
  end
 end end
end
-- Explicit consolidation only. Never identify related events from command names.
function S:MergeTimelineEvents(targetId,guild,sourceIds)
 local saved=self:GetGuildSchedule(targetId,guild)
 if not saved or saved.timelineVersion~=1 then return false,'Save the parent event as a reminder timeline first.' end
 local target=clone(saved);target.legacyTimelineBackup=target.legacyTimelineBackup or {};target.legacyTimelineBackup.merged=target.legacyTimelineBackup.merged or {}
 local changes,sources,seen={},{},{}
 local parentEvent=target.eventAtUtc
 local function aligned(config)
  if config.recurrence=='MONTHLY_DATE' or config.recurrence=='MONTHLY_WEEKDAY' then
   -- Compare real occurrences in a shared eligible month, not technical anchor
   -- dates. Nominal projection includes cancellations and has no short horizon.
   local function midnight(utc)
    return self:ParseScheduleDateTime(self:GetScheduleOccurrenceDate(target,utc),'12:00 AM','FIRST',target)
   end
   local parent=self:GetNominalScheduleOccurrences(target,midnight(math.max(target.eventAtUtc,config.eventAtUtc)),1,true)[1]
   local source=parent and self:GetNominalScheduleOccurrences(config,midnight(parent.eventAtUtc),1,true)[1]
   if not parent or not source or self:GetScheduleOccurrenceDate(target,parent.eventAtUtc)~=self:GetScheduleOccurrenceDate(config,source.eventAtUtc) then return nil end
   return source.eventAtUtc,parent.eventAtUtc
  end
  local step=config.recurrence=='BIWEEKLY' and 14 or config.recurrence=='WEEKLY' and 7 or nil
  if not step then return config.eventAtUtc end
  step=step*(config.recurrenceInterval or 1)
  local days=math.floor((parentEvent-config.eventAtUtc)/86400+.5)
  local week=math.floor(days/step+.5)*step
  local p=self:GetScheduleParts(config.eventAtUtc,config)
  local d=os.date('!*t',config.eventAtUtc+self:GetTimeZoneUtcOffset(config.eventAtUtc,config.timeZone)*3600+week*86400)
  return self:ParseScheduleDateTime(string.format('%04d-%02d-%02d',d.year,d.month,d.day),string.format('%02d:%02d %s',p.hour%12==0 and 12 or p.hour%12,p.min,p.hour>=12 and 'PM' or 'AM'),'FIRST',config)
 end
 local function rewrite(text,delta,names)
  return tostring(text):gsub('%%([%a][%w_:+%-]*)%%',function(token)
   local kind,offset,mark=self:ParseScheduledEventToken(token)
   if not kind or kind=='eventfaction' or kind=='eventactivity' then return '%'..token..'%' end
   if mark then return '%'..kind..':'..(names[mark] or mark)..'%' end
   local minutes=(offset or 0)/60+delta
   if minutes==0 then return '%'..kind..'%' end
   return '%'..kind..(minutes<0 and '-' or '+')..math.abs(minutes)..'m%'
  end)
 end
 for _,id in ipairs(sourceIds or {}) do
  if id==targetId or seen[id] then return false,'Choose each helper once, excluding the parent.' end;seen[id]=true
  local source=self:GetGuildSchedule(id,guild)
  if target.legacyTimelineBackup.merged[id] then return false,'This helper was already combined into this event.' end
  if not source or source.timeZone~=target.timeZone or self:GetSavedChatChannel(id,guild)~=self:GetSavedChatChannel(targetId,guild) then return false,'Helpers must use the same guild, timezone and output channel.' end
  local function selectedDays(config) local count=0;for _,selected in pairs(config.weekdays or {}) do if selected then count=count+1 end end;return count end
  if selectedDays(source)>1 or selectedDays(target)>1 then return false,'Combine single-weekday event schedules only; review multi-weekday helpers separately.' end
  if source.recurrence~=target.recurrence or source.recurrenceInterval~=target.recurrenceInterval then return false,'Helper recurrence differs from the parent; align it before combining.' end
  if source.recurrence=='MONTHLY_DATE' or source.recurrence=='MONTHLY_WEEKDAY' then
   local a,b=self:GetScheduleParts(source.eventAtUtc,source),self:GetScheduleParts(target.eventAtUtc,target)
   if ((a.year-b.year)*12+a.month-b.month)%(source.recurrenceInterval or 1)~=0 then return false,'Monthly helper repeat months differ from the parent; align their starting-month phase before combining.' end
   if source.recurrence=='MONTHLY_DATE' and a.day~=b.day or source.recurrence=='MONTHLY_WEEKDAY' and ((source.monthlyWeekday or a.wday)~=(target.monthlyWeekday or b.wday) or (source.monthlyWeek or math.floor((a.day-1)/7)+1)~=(target.monthlyWeek or math.floor((b.day-1)/7)+1)) then return false,'Monthly helpers must use the same day or ordinal weekday as the parent.' end
  end
  if source.specialPattern~='NONE' and source.specialPattern~=target.specialPattern then return false,'Helper special pattern differs from the parent.' end
  local event,actualParent=aligned(source);local parentAt=actualParent or parentEvent;if not event then return false,'Cannot align a helper occurrence.' end
  local delta=math.floor((event-parentAt)/60)
  local rows,variants
  local names={}
  if source.timelineVersion==1 then
   rows=clone(source.reminders);variants=clone(source.messageVariants)
   local srcDay=math.floor((event+self:GetTimeZoneUtcOffset(event,target.timeZone)*3600)/86400)
   local parentDay=math.floor((parentAt+self:GetTimeZoneUtcOffset(parentAt,target.timeZone)*3600)/86400)
   for name,mark in pairs(source.importantTimes) do local base='source_'..zo_strlower(id):gsub('[^%w_]','_')..'_'..name;local key=base;local n=1;while target.importantTimes[key] do n=n+1;key=base..'_'..n end;names[name]=key;target.importantTimes[key]={label=mark.label,offsetMinutes=mark.offsetMinutes+delta} end
   for _,row in ipairs(rows) do for _,a in ipairs({row.start,row.finish}) do if a.kind=='OFFSET' then a.minutes=a.minutes+delta elseif a.kind=='DAY' then a.days=a.days+srcDay-parentDay elseif a.kind=='MARK' then a.name=names[a.name] end end end
  else rows,variants=self:BuildLegacyTimelineRows(source,id,guild,parentAt,event) end
  if not rows then return false,variants end
  local rowIds={};for _,r in ipairs(target.reminders) do rowIds[r.id]=true end
  for _,row in ipairs(rows) do row.sourceTimelineId=row.id;if rowIds[row.id] then row.id=id..'_'..row.id end;rowIds[row.id]=true;target.reminders[#target.reminders+1]=row end
  for messageId,variant in pairs(variants or {}) do target.messageVariants[messageId]=variant end
  for _,entry in ipairs(self:GetMessageEntriesForCommandAndGuild(id,guild)) do
   if source.specialPattern=='NONE' then target.messageVariants[entry.id]='ALL' end
   local text=rewrite(entry.text,delta,names)
   if entry.locked and text~=entry.text then return false,'Unlock or manually adapt the helper message before changing its event-time tokens.' end
   changes[#changes+1]={entry=entry,text=text}
  end
  target.legacyTimelineBackup.merged[id]={command=clone(self:GetCommandById(id)),settings=clone(self:GetCommandGuildSettings(id,guild,false)),sourceEventAtUtc=event}
  sources[#sources+1]={id=id,rows=rows,source=source}
 end
 if #sources==0 then return false,'Select at least one helper.' end
 local normalized,reason=self:NormalizeSchedule(target);if not normalized then return false,reason end
 for _,item in ipairs(sources) do self:MapLegacyTimelineUsage(item.source,normalized,item.rows,item.id,guild) end
 -- Commit only after every helper and rewritten message has validated.
 for _,item in ipairs(changes) do item.entry.commandId=targetId;item.entry.text=item.text end
 local settings=self:GetCommandGuildSettings(targetId,guild,true);settings.schedule=normalized
 for _,item in ipairs(sources) do
  self:StopScheduledDelivery(item.id,guild)
  local sourceSettings=self:GetCommandGuildSettings(item.id,guild,true)
  sourceSettings.schedule.enabled=false;sourceSettings.schedule.paused=true;sourceSettings.schedule.mergedInto=targetId;sourceSettings.mergedInto=targetId
 end
 if self.RegisterDynamicCommands then self:RegisterDynamicCommands() end
 if self.RefreshSettingsUI then self:RefreshSettingsUI() end
 return true
end
function S:MapLegacyTimelineUsage(source,target,rows,commandId,guild)
 target.timelineUsage=target.timelineUsage or {}
 local settings=self:GetCommandGuildSettings(commandId,guild,false) or {}
 if source.timelineVersion==1 then
  for sourceKey,usage in pairs(source.timelineUsage or {}) do
   local epoch,rowId=sourceKey:match('^(%d+):(.+)$');epoch=tonumber(epoch)
   if epoch then
    local nearest,distance
    for _,occurrence in ipairs(self:GetUpcomingScheduleOccurrences(target,epoch-15*86400,32,true)) do
     local diff=math.abs(occurrence.eventAtUtc-epoch)
     if not distance or diff<distance then nearest,distance=occurrence,diff end
    end
    if nearest then for _,row in ipairs(rows) do if (row.sourceTimelineId or row.id)==rowId then
     target.timelineUsage[nearest.occurrenceKey..':'..row.id]=clone(usage)
    end end end
   end
  end
  return
 end
 for sourceKey,completed in pairs(source.completedOccurrences or {}) do
  local epoch,phase=sourceKey:match('^(%d+):(.+)$');epoch=tonumber(epoch)
  if completed and epoch then
   local nearest,distance
   for _,occurrence in ipairs(self:GetUpcomingScheduleOccurrences(target,epoch-15*86400,32,true)) do
    local diff=math.abs(occurrence.eventAtUtc-epoch)
    if not distance or diff<distance then nearest,distance=occurrence,diff end
   end
   if nearest then for _,row in ipairs(rows) do if row.once and row.legacyPhase==phase then
    local key=nearest.occurrenceKey..':'..row.id;target.timelineUsage[key]=target.timelineUsage[key] or {};target.timelineUsage[key].completed=true
   end end end
  end
 end
 local last=settings.lastUsedAt
 if type(last)~='number' then return end
 local occurrence=self:GetScheduleOccurrence(target,last)
 if not occurrence then return end
 for _,row in ipairs(rows) do
  local start,finish=self:GetTimelineReminderWindow(target,occurrence,row)
  if start and finish and last>=start and last<finish then
   local key=occurrence.occurrenceKey..':'..row.id
   local usage={lastSentAt=last,completed=row.once or nil,nextDueAt=last+row.intervalMinutes*60}
   if source.nextDueAt and (not row.legacyPhase or source.nextDuePhase==row.legacyPhase) then usage.nextDueAt=math.max(usage.nextDueAt,source.nextDueAt) end
   for _,observed in pairs(settings.observedChatCooldowns or {}) do if observed.at==last then usage.peerAt=last;usage.nextDueAt=math.max(usage.nextDueAt,last+row.intervalMinutes*60+observed.delaySeconds) end end
   target.timelineUsage[key]=usage
  end
 end
end
local save=S.SaveGuildSchedule
function S:SaveGuildSchedule(id,guild,draft)
 local source=self:GetGuildSchedule(id,guild)
 if source and not source.timelineVersion and draft.timelineVersion==1 then
  local candidate,reason=self:NormalizeSchedule(draft);if not candidate then return false,reason end
  self:MapLegacyTimelineUsage(source,candidate,draft.reminders or {},id,guild)
  draft=clone(draft);draft.timelineUsage=candidate.timelineUsage
 end
 return save(self,id,guild,draft)
end
