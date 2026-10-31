SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function integer(v,a,b) return type(v)=='number' and v==math.floor(v) and v>=a and v<=b end
local function hours(v)
 if type(v)~='table' then return nil end
 local a,b=v.startMinute,v.endMinute
 if a==nil then a=0 end;if b==nil then b=1440 end
 if not integer(a,0,1439) or not integer(b,1,1440) or a==b then return nil end
 return {startMinute=a,endMinute=b}
end
function S:NormalizeReminderAvailability(raw,config)
 if raw==nil then return nil end
 local result=hours(raw);if not result then return nil,'Availability needs valid start/end minutes; use 0 to 1440 for all day.' end
 result.enabled=raw.enabled==true
 if raw.maxPerDay~=nil then if not integer(raw.maxPerDay,1,1000) then return nil,'Daily maximum must be a whole number from 1 to 1000 or blank.' end;result.maxPerDay=raw.maxPerDay end
 if raw.weekdays~=nil then
  if type(raw.weekdays)~='table' then return nil,'Choose valid availability weekdays.' end
  result.weekdays={};for day,value in pairs(raw.weekdays) do if not integer(day,1,7) or type(value)~='boolean' then return nil,'Choose valid availability weekdays.' end;if value then result.weekdays[day]=true end end
 end
 for _,scope in ipairs({'weekdayOverrides','dateOverrides'}) do
  result[scope]={}
  if raw[scope]~=nil and type(raw[scope])~='table' then return nil,'Invalid availability overrides.' end
  for key,value in pairs(raw[scope] or {}) do
   local valid=scope=='weekdayOverrides' and integer(key,1,7) or scope=='dateOverrides' and type(key)=='string' and key:match('^%d%d%d%d%-%d%d%-%d%d$') and self:ParseScheduleDateTime(key,'12:00 PM','FIRST',config)
   local h=hours(value);if not valid or not h then return nil,'Choose a valid override date/weekday and hours.' end;result[scope][key]=h
  end
 end
 return result
end
local normalize=S.NormalizeSchedule
function S:NormalizeSchedule(data)
 local result,reason=normalize(self,data);if not result or result.timelineVersion~=1 then return result,reason end
 if data.dailyLimitShared~=nil and type(data.dailyLimitShared)~='boolean' then return nil,'Choose a valid daily limit scope.' end
 if data.sharedDailyLimit~=nil and not integer(data.sharedDailyLimit,1,1000) then return nil,'Shared daily maximum must be a whole number from 1 to 1000 or blank.' end
 result.dailyLimitShared=data.dailyLimitShared==true;result.sharedDailyLimit=data.sharedDailyLimit
 local byId={};for _,raw in ipairs(data.reminders or {}) do byId[raw.id]=raw end
 for _,row in ipairs(result.reminders) do
  local value,error=self:NormalizeReminderAvailability(byId[row.id].availability,result)
  if error then return nil,error end;row.availability=value
 end
 result.availabilityUsage={}
 for key,value in pairs(type(data.availabilityUsage)=='table' and data.availabilityUsage or {}) do
  if type(key)=='string' and type(value)=='table' and integer(value.count,0,9007199254740991) and integer(value.lastAt,0,253402300799) then result.availabilityUsage[key]={count=value.count,lastAt=value.lastAt} end
 end
 return result
end
local function day(self,config,utc) local p=self:GetScheduleParts(utc,config);return math.floor((utc+self:GetTimeZoneUtcOffset(utc,config.timeZone)*3600)/86400),p end
local function date(number) local p=os.date('!*t',number*86400);return string.format('%04d-%02d-%02d',p.year,p.month,p.day),p.wday end
local function clock(self,config,number,minute,fold)
 if minute==1440 then number,minute=number+1,0 end
 local h=math.floor(minute/60);return self:ParseScheduleDateTime(date(number),string.format('%02d:%02d %s',h%12==0 and 12 or h%12,minute%60,h>=12 and 'PM' or 'AM'),fold,config)
end
function S:GetReminderAvailabilityForDate(config,row,key)
 local a=row.availability;if not a or not a.enabled then return nil end
 local noon=self:ParseScheduleDateTime(key,'12:00 PM','FIRST',config);if not noon then return nil end
 local p=self:GetScheduleParts(noon,config)
 if a.weekdays and not a.weekdays[p.wday] then return nil end
 if a.dateOverrides and a.dateOverrides[key] then return a.dateOverrides[key],'DATE',p.wday end
 if a.weekdayOverrides and a.weekdayOverrides[p.wday] then return a.weekdayOverrides[p.wday],'WEEKDAY',p.wday end
 return a,'USUAL',p.wday
end
function S:GetEffectiveReminderWindows(config,row,occurrence,fromUtc,toUtc)
 local first,last=self:GetTimelineReminderWindow(config,occurrence,row)
 if not first or not last or last<=first then return {} end
 local a=row.availability
 if not a or not a.enabled then return first<toUtc and last>fromUtc and {{row=row,start=first,finish=last,eventAtUtc=occurrence.eventAtUtc}} or {} end
 if toUtc<=fromUtc or toUtc-fromUtc>400*86400+7200 then return {} end
 local startDay=day(self,config,fromUtc)-1;local endDay=day(self,config,toUtc)
 local out={}
 for origin=startDay,endDay do
  local key=date(origin);local h,source,weekday=self:GetReminderAvailabilityForDate(config,row,key)
  if h then
   local ending=origin+(h.endMinute<h.startMinute and 1 or 0)
   local rawStart,rawEnd=clock(self,config,origin,h.startMinute,'FIRST'),clock(self,config,ending,h.endMinute,'SECOND')
   if rawStart and rawEnd then
    local begin,finish=math.max(first,rawStart),math.min(last,rawEnd)
    if finish>begin and begin<toUtc and finish>fromUtc then out[#out+1]={row=row,start=begin,finish=finish,eventAtUtc=occurrence.eventAtUtc,availabilityDate=key,availabilityWeekday=weekday,availabilitySource=source,hours={startMinute=h.startMinute,endMinute=h.endMinute},rawStart=rawStart,rawEnd=rawEnd,baseStart=first,baseEnd=last,clipStart=begin,clipEnd=finish} end
   end
  end
 end
 return out
end
function S:GetReminderAvailabilityCount(config,row,utc)
 local key=row.id..':'..self:GetScheduleOccurrenceDate(config,utc)
 config.availabilityUsage=config.availabilityUsage or {}
 local usage=config.availabilityUsage[key]
 if not usage then
  local latest
  for id,value in pairs(config.timelineUsage or {}) do if id:sub(-#row.id-1)==':'..row.id then
   for _,name in ipairs({'lastSentAt','peerAt'}) do local at=value[name];if at and self:GetScheduleOccurrenceDate(config,at)==self:GetScheduleOccurrenceDate(config,utc) then latest=math.max(latest or at,at) end end
  end end
  if latest then usage={count=1,lastAt=latest};config.availabilityUsage[key]=usage end
 end
 return usage and usage.count or 0
end
function S:RecordReminderAvailabilityUsage(config,row,utc)
 local count=self:GetReminderAvailabilityCount(config,row,utc)
 config.availabilityUsage=config.availabilityUsage or {};config.availabilityUsage[row.id..':'..self:GetScheduleOccurrenceDate(config,utc)]={count=count+1,lastAt=utc}
end
-- The aggregate is maintained even when unlimited or using per-period caps.
function S:GetScheduleDailyLimitCount(config,utc)
 local today=self:GetScheduleOccurrenceDate(config,utc);local key='_command:'..today
 config.availabilityUsage=config.availabilityUsage or {}
 local usage=config.availabilityUsage[key]
 if not usage then
  -- Older versions stored only period counters; sum their known daily usage.
  local count,lastAt=0,utc
  for _,row in ipairs(config.reminders or {}) do
   count=count+self:GetReminderAvailabilityCount(config,row,utc)
   local localUsage=config.availabilityUsage[row.id..':'..today]
   if localUsage then lastAt=math.max(lastAt,localUsage.lastAt) end
  end
  usage={count=count,lastAt=lastAt};config.availabilityUsage[key]=usage
 end
 return usage.count
end
function S:GetReminderDailyLimit(config,row,utc)
 local shared=config.dailyLimitShared==true
 local limit=shared and config.sharedDailyLimit or nil
 if not shared then limit=row and row.availability and row.availability.maxPerDay or nil end
 local count=shared and self:GetScheduleDailyLimitCount(config,utc) or self:GetReminderAvailabilityCount(config,row,utc)
 return {shared=shared,limit=limit,count=count,reached=limit~=nil and count>=limit}
end
function S:RecordScheduleDailyLimitUsage(config,utc)
 local count=self:GetScheduleDailyLimitCount(config,utc)
 config.availabilityUsage['_command:'..self:GetScheduleOccurrenceDate(config,utc)]={count=count+1,lastAt=utc}
end
function S:GetReminderAvailabilityStatus(config,row,occurrence,utc)
 local a=row.availability
 if self:GetReminderDailyLimit(config,row,utc).reached then return false,nil,nil,'CAP' end
 if not a or not a.enabled then return true end
 local windows=self:GetEffectiveReminderWindows(config,row,occurrence,utc,utc+1)
 for _,w in ipairs(windows) do if utc>=w.start and utc<w.finish then return true,w.start,w.finish,w.availabilitySource,w.availabilityDate end end
 return false,nil,nil,'HOURS'
end
local confirmed=S.HandleScheduledSendConfirmed
function S:HandleScheduledSendConfirmed(metadata)
 if metadata and metadata.scheduledDelivery then
  local config=self:GetGuildSchedule(metadata.commandId,metadata.guildName)
  if config and config.timelineVersion==1 then self:RecordScheduleDailyLimitUsage(config,GetTimeStamp()) end
  for _,row in ipairs(config and config.reminders or {}) do if row.id==metadata.scheduledPhase then self:RecordReminderAvailabilityUsage(config,row,GetTimeStamp()) end end
 end
 return confirmed(self,metadata)
end
function S:IsReminderMessageVariantEligible(config,row,entry,guild,occurrence)
 local selected={};for _,id in ipairs(row.messageIds) do selected[id]=true end
 if not selected[entry.id] then return false end
 local variant=self:GetScheduleEventVariant(config,occurrence.eventAtUtc)
 if config.specialPattern=='MONTH_FINAL' and variant=='FINAL' then
  local hasFinal=false
  for _,candidate in ipairs(self:GetMessageEntriesForCommandAndGuild(entry.commandId,guild)) do
   if selected[candidate.id] and self:GetScheduleMessageVariant(config,candidate.id)=='FINAL' then hasFinal=true;break end
  end
  if not hasFinal then variant='REGULAR' end
 end
 local group=self:GetScheduleMessageVariant(config,entry.id)
 return config.specialPattern=='NONE' or group=='ALL' or group==variant
end
local observed=S.MarkObservedChatUsage
function S:MarkObservedChatUsage(entry,guild,channel,matchingEntries)
 local config=self:GetGuildSchedule(entry.commandId,guild);local utc=GetTimeStamp()
 local occurrence=config and config.timelineVersion==1 and self:GetScheduleOccurrence(config,utc)
 if occurrence then
  local relevantRows={}
  for _,row in ipairs(config.reminders) do
   -- Freeze legacy bootstrap before downstream peer cooldown history changes.
   -- Otherwise an irrelevant variant with hours off could become a false count.
   local count=self:GetReminderAvailabilityCount(config,row,utc)
   local key=row.id..':'..self:GetScheduleOccurrenceDate(config,utc)
   if not config.availabilityUsage[key] then config.availabilityUsage[key]={count=count,lastAt=utc} end
   local relevant=false;for _,candidate in ipairs(matchingEntries or {entry}) do if self:IsReminderMessageVariantEligible(config,row,candidate,guild,occurrence) then relevant=true;break end end
   local first,last=self:GetTimelineReminderWindow(config,occurrence,row)
   if relevant and first and last and utc>=first and utc<last then relevantRows[#relevantRows+1]=row end
  end
  if #relevantRows>0 then
   self:RecordScheduleDailyLimitUsage(config,utc)
   for _,row in ipairs(relevantRows) do self:RecordReminderAvailabilityUsage(config,row,utc) end
  end
 end
 return observed(self,entry,guild,channel,matchingEntries)
end
local save=S.SaveGuildSchedule
function S:SaveGuildSchedule(id,guild,draft)
 local candidate=copy(draft);local old=self:GetGuildSchedule(id,guild)
 if old then candidate.availabilityUsage=copy(old.availabilityUsage or {}) end
 return save(self,id,guild,candidate)
end
local apply=S.ApplyImportedSettings
function S:ApplyImportedSettings(imported)
 for id,guilds in pairs(imported.commandGuildSettings or {}) do
  local oldId=id
  if not self:GetCommandById(id) then for _,new in ipairs(imported.commands or {}) do if new.id==id then for _,old in ipairs(self:GetCommands()) do if zo_strlower(old.name)==zo_strlower(new.name) then oldId=old.id end end end end end
  for guild,settings in pairs(guilds) do if settings.schedule then
   local old=self:GetGuildSchedule(oldId,guild);settings.schedule.availabilityUsage={}
   local rows={};for _,row in ipairs(settings.schedule.reminders or {}) do rows[row.id]=true end
   for key,value in pairs(old and old.availabilityUsage or {}) do local rowId=key:match('^(.*):%d%d%d%d%-%d%d%-%d%d$');if rowId=='_command' or rows[rowId] then settings.schedule.availabilityUsage[key]=copy(value) end end
   -- Imported legacy usage can still carry ordinary cooldown history, but it
   -- must never bootstrap another player's announcements into recipient caps.
   local oldCopy=old and copy(old)
   local today=self:GetScheduleOccurrenceDate(settings.schedule,GetTimeStamp())
   for _,row in ipairs(settings.schedule.reminders or {}) do
    local dates={[today]=true}
    for key,usage in pairs(settings.schedule.timelineUsage or {}) do if key:sub(-#row.id-1)==':'..row.id then
     for _,field in ipairs({'lastSentAt','peerAt'}) do if usage[field] then dates[self:GetScheduleOccurrenceDate(settings.schedule,usage[field])]=true end end
    end end
    local oldRow;for _,candidate in ipairs(oldCopy and oldCopy.reminders or {}) do if candidate.id==row.id then oldRow=candidate end end
    for date in pairs(dates) do local key=row.id..':'..date
     if not settings.schedule.availabilityUsage[key] then
      local noon=self:ParseScheduleDateTime(date,'12:00 PM','FIRST',settings.schedule)
      local count=oldRow and noon and self:GetReminderAvailabilityCount(oldCopy,oldRow,noon) or 0
      local previous=oldCopy and oldCopy.availabilityUsage and oldCopy.availabilityUsage[key]
      settings.schedule.availabilityUsage[key]=previous and copy(previous) or {count=count,lastAt=GetTimeStamp()}
     end
    end
   end
  end end
 end
 return apply(self,imported)
end

-- Portable configuration records deliberately omit recipient daily counters.
local export=S.ExportScheduleRecords
function S:ExportScheduleRecords()
 local lines=export(self)
 local function add(fields) for i,v in ipairs(fields) do fields[i]=self:EscapeImportExportField(tostring(v)) end;lines[#lines+1]=table.concat(fields,'|') end
 for id,guilds in pairs(self.savedVars.commandGuildSettings or {}) do for guild,settings in pairs(guilds) do
  if settings.schedule and settings.schedule.timelineVersion==1 then add({'SCHEDULEDAILYLIMIT_V1',id,guild,settings.schedule.dailyLimitShared and '1' or '0',settings.schedule.sharedDailyLimit or ''}) end
  for _,row in ipairs(settings.schedule and settings.schedule.reminders or {}) do local a=row.availability;if a then
   local days='*';if a.weekdays then local bits={};for day=1,7 do bits[day]=a.weekdays[day] and '1' or '0' end;days=table.concat(bits) end
   add({'SCHEDULEAVAILABILITY_V1',id,guild,row.id,a.enabled and '1' or '0',a.startMinute,a.endMinute,a.maxPerDay or '',days})
   for _,scope in ipairs({'weekdayOverrides','dateOverrides'}) do for key,h in pairs(a[scope] or {}) do add({'SCHEDULEAVAILABILITYDAY_V1',id,guild,row.id,scope=='dateOverrides' and 'DATE' or 'WEEKDAY',key,h.startMinute,h.endMinute}) end end
  end end
 end end
 return lines
end
local import=S.ImportScheduleRecords
function S:ImportScheduleRecords(records,imported)
 local legacy,new={},{}
 for _,row in ipairs(records) do if row[1]=='SCHEDULEDAILYLIMIT_V1' or row[1]=='SCHEDULEAVAILABILITY_V1' or row[1]=='SCHEDULEAVAILABILITYDAY_V1' then local decoded={};for i,v in ipairs(row) do decoded[i]=self:UnescapeImportExportField(v) end;new[#new+1]=decoded else legacy[#legacy+1]=row end end
 local ok,reason=import(self,legacy,imported);if not ok then return false,reason end
 local seen={}
 for _,record in ipairs(new) do if record[1]=='SCHEDULEDAILYLIMIT_V1' then
  local id,guild=record[2],self:NormalizeKey(record[3]);local key=id..'\n'..tostring(guild)
  local settings=guild and imported.commandGuildSettings[id] and imported.commandGuildSettings[id][guild]
  local limit=record[5]~='' and tonumber(record[5]) or nil
  if #record~=5 or not settings or not settings.schedule or seen[key] or (record[4]~='0' and record[4]~='1') or record[5]~='' and not integer(limit,1,1000) then return false,'Invalid or duplicate shared daily limit record.' end
  seen[key]=true;settings.schedule.dailyLimitShared=record[4]=='1';settings.schedule.sharedDailyLimit=limit
 end end
 for _,record in ipairs(new) do if record[1]=='SCHEDULEAVAILABILITY_V1' then
  local id,guild,rowId=record[2],self:NormalizeKey(record[3]),record[4]
  local settings=guild and imported.commandGuildSettings[id] and imported.commandGuildSettings[id][guild]
  local row;for _,candidate in ipairs(settings and settings.schedule and settings.schedule.reminders or {}) do if candidate.id==rowId then row=candidate end end
  local key=id..'\n'..tostring(guild)..'\n'..tostring(rowId)
  if not row or seen[key] or (record[5]~='0' and record[5]~='1') then return false,'Invalid or duplicate reminder availability record.' end;seen[key]=true
  local a={enabled=record[5]=='1',startMinute=tonumber(record[6]),endMinute=tonumber(record[7]),maxPerDay=record[8]~='' and tonumber(record[8]) or nil,weekdayOverrides={},dateOverrides={}}
  if not a.startMinute or not a.endMinute or record[8]~='' and not a.maxPerDay then return false,'Invalid availability clock or daily maximum.' end
  if record[9]~='*' then if type(record[9])~='string' or #record[9]~=7 or record[9]:find('[^01]') then return false,'Invalid availability weekdays.' end;a.weekdays={};for day=1,7 do if record[9]:sub(day,day)=='1' then a.weekdays[day]=true end end end
  row.availability=a
 end end
 for _,record in ipairs(new) do if record[1]=='SCHEDULEAVAILABILITYDAY_V1' then
  local settings=imported.commandGuildSettings[record[2]] and imported.commandGuildSettings[record[2]][self:NormalizeKey(record[3])]
  local row;for _,candidate in ipairs(settings and settings.schedule and settings.schedule.reminders or {}) do if candidate.id==record[4] then row=candidate end end
  local scope=record[5]=='DATE' and 'dateOverrides' or record[5]=='WEEKDAY' and 'weekdayOverrides'
  local key=scope=='weekdayOverrides' and tonumber(record[6]) or record[6]
  if not row or not row.availability or not scope or key==nil or row.availability[scope][key] then return false,'Invalid or duplicate availability override.' end
  row.availability[scope][key]={startMinute=tonumber(record[7]),endMinute=tonumber(record[8])}
  if not row.availability[scope][key].startMinute or not row.availability[scope][key].endMinute then return false,'Invalid availability override hours.' end
 end end
 for _,guilds in pairs(imported.commandGuildSettings) do for _,settings in pairs(guilds) do if settings.schedule then local normalized,error=self:NormalizeSchedule(settings.schedule);if not normalized then return false,error end;settings.schedule=normalized end end end
 return true
end

local function displayMinute(value) if type(value)~='number' or value~=value or value==math.huge then return tostring(value or '') end;return string.format('%02d:%02d',math.floor(value/60),value%60) end
local function parseMinute(value,ending)
 local h,m=tostring(value):match('^(%d%d?):(%d%d)$');h,m=tonumber(h),tonumber(m)
 if h and m and m<60 and (h<24 or ending and h==24 and m==0) then return h*60+m end
 return value
end
local controls=S.BuildScheduleOptionControls
function S:BuildScheduleOptionControls()
 local result=controls(self)
 local function selected() return self:GetSelectedTimelineReminder() end
 local function a(create)
  local row=selected();if not row then return nil end
  if not row.availability and create then row.availability={enabled=false,startMinute=0,endMinute=1440,weekdayOverrides={},dateOverrides={}} end
  return row.availability
 end
 local function refresh() if self.scheduleEditor then self.scheduleEditor.dirty=true end;self:RefreshSettingsUI() end
 local pane={
  {type='description',text='Limit this reminder to selected server weekdays and hours. Overnight hours belong to their opening day; promotion boundaries and Send once still apply.'},
  {type='checkbox',name='Limit reminder availability',getFunc=function() return a() and a().enabled or false end,setFunc=function(v) local value=a(true);if value then value.enabled=v;refresh() end end},
 }
 local function inheritedHours(value,scope,key)
  local own=(value[scope] or {})[key];if own then return own end
  if scope=='dateOverrides' then
   local config=self:GetScheduleEditorDraft();local noon=self:ParseScheduleDateTime(key,'12:00 PM','FIRST',config)
   local weekday=noon and self:GetScheduleParts(noon,config).wday
   if weekday and value.weekdayOverrides and value.weekdayOverrides[weekday] then return value.weekdayOverrides[weekday] end
  end
  return value
 end
 local function hourField(name,member,scope)
  return {type='editbox',name=name,getFunc=function()
   local value=a();local h=value
   if scope and value then local key=scope=='dateOverrides' and (self.availabilityOverrideDate or self:GetScheduleOccurrenceDate(self:GetScheduleEditorDraft(),GetTimeStamp())) or self.availabilityOverrideWeekday or 1;h=inheritedHours(value,scope,key) end
   return displayMinute(h and h[member] or (member=='startMinute' and 0 or 1440))
  end,setFunc=function(v)
   local value=a(true);if not value then return end
   local h=value
   if scope then
    local key=scope=='dateOverrides' and (self.availabilityOverrideDate or self:GetScheduleOccurrenceDate(self:GetScheduleEditorDraft(),GetTimeStamp())) or self.availabilityOverrideWeekday or 1
    if key==nil or key=='' then self:ShowStatusMessage('Select the override date first.');return end
    local inherited=inheritedHours(value,scope,key)
    value[scope]=value[scope] or {};value[scope][key]=value[scope][key] or {startMinute=inherited.startMinute,endMinute=inherited.endMinute};h=value[scope][key]
   end
   h[member]=parseMinute(v,member=='endMinute');refresh()
  end,disabled=function() return not selected() end}
 end
 pane[#pane+1]=hourField('Allowed from (HH:MM)','startMinute');pane[#pane+1]=hourField('Allowed until (HH:MM, 24:00 is midnight)','endMinute')
 for day,name in ipairs({'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}) do local index=day
  pane[#pane+1]={type='checkbox',name='Available on '..name,getFunc=function() return not a() or not a().weekdays or a().weekdays[index]==true end,setFunc=function(v)
   local value=a(true);if not value then return end;if not value.weekdays then value.weekdays={};for n=1,7 do value.weekdays[n]=true end end;value.weekdays[index]=v==true or nil;refresh()
  end}
 end
 pane[#pane+1]={type='dropdown',name='Override weekday',choices={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'},getFunc=function() return ({'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'})[self.availabilityOverrideWeekday or 1] end,setFunc=function(v) for index,name in ipairs({'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}) do if v==name then self.availabilityOverrideWeekday=index end end;refresh() end}
 pane[#pane+1]=hourField('Weekday override from (HH:MM)','startMinute','weekdayOverrides');pane[#pane+1]=hourField('Weekday override until (HH:MM)','endMinute','weekdayOverrides')
 pane[#pane+1]={type='button',name='Reset selected weekday hours',func=function() local value=a();if value and value.weekdayOverrides then value.weekdayOverrides[self.availabilityOverrideWeekday or 1]=nil;refresh() end end}
 pane[#pane+1]={type='datepicker',name='Override opening date',datePickerType='normal',getFunc=function() return self:ScheduleDateToPicker(self.availabilityOverrideDate or self:GetScheduleOccurrenceDate(self:GetScheduleEditorDraft(),GetTimeStamp())) end,setFunc=function(v) self.availabilityOverrideDate=self:ScheduleDateFromPicker(v);refresh() end}
 pane[#pane+1]=hourField('Date override from (HH:MM)','startMinute','dateOverrides');pane[#pane+1]=hourField('Date override until (HH:MM)','endMinute','dateOverrides')
 pane[#pane+1]={type='button',name='Reset selected date hours',func=function() local value=a();if value and value.dateOverrides then value.dateOverrides[self.availabilityOverrideDate or self:GetScheduleOccurrenceDate(self:GetScheduleEditorDraft(),GetTimeStamp())]=nil;refresh() end end}
 pane[#pane+1]={type='description',text=function() local row=selected();local config=self:GetScheduleEditorDraft();return row and 'Today: '..self:GetReminderAvailabilityCount(config,row,GetTimeStamp())..' counted announcements. Date overrides take priority over weekday overrides, then usual hours. Resetting hours keeps counts.' or 'Select a reminder.' end}
 local target
 for _,control in ipairs(result) do if control.reference=='SCM_TimelineSubmenu' then target=control.controls end end
 if target then
  local tooltip='Counts confirmed sends and matching announcements from other players, including while paused. Preparing chat and timeouts do not count. Resets at midnight in the schedule timezone. By default each period has its own limit; sharing uses one limit across every period for this command and guild. Unlimited keeps counting so changing scope preserves today’s usage.'
  local slider=self:BuildSchedulingSlider('Daily announcement limit','SCM_PeriodDailyLimitSlider',0,20,function()
   local config=self:GetScheduleEditorDraft();return config.dailyLimitShared and (config.sharedDailyLimit or 0) or (a() and a().maxPerDay or 0)
  end,function(n)
   local config=self:GetScheduleEditorDraft()
   if config.dailyLimitShared then config.sharedDailyLimit=n>0 and n or nil else local value=a(true);if value then value.maxPerDay=n>0 and n or nil end end
   refresh()
  end,function(n)return n==0 and 'Unlimited' or tostring(n)end,function()return not selected()end)
  slider.tooltip=tooltip
  local shared={type='checkbox',name='Share Limit to ALL periods',tooltip='Unchecked: the daily limit applies only to this period. Checked: one daily limit is shared by ALL periods for this command and guild; an announcement from any period counts toward it.',getFunc=function()return self:GetScheduleEditorDraft().dailyLimitShared==true end,setFunc=function(v)self:GetScheduleEditorDraft().dailyLimitShared=v==true;refresh()end,disabled=function()return not selected()end}
  local index=#target+1;for n,control in ipairs(target) do if control.reference=='SCM_PeriodFrequencySlider' then index=n+1;break end end
  table.insert(target,index,slider);table.insert(target,index+1,shared)
 end
 if target then target[#target+1]={type='submenu',name='Reminder availability',controls=pane,disabled=function() return not selected() end} end
 return result
end
