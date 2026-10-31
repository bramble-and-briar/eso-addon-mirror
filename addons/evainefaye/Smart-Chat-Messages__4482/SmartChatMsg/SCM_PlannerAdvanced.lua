SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local days={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}
local function validName(self,name)
 name=self:Trim(name or '');local _,n=name:gsub('[^\128-\191]','')
 if n<1 or n>80 then return nil,'Enter a name from 1 to 80 characters.' end
 return name
end
function S:AddPlannerActivity(model,name)
 local clean,err=validName(self,name);if not clean then return nil,err end
 local d=model.schedule;d.rotationEvents=d.rotationEvents or {};if #d.rotationEvents>=50 then return nil,'Maximum 50 activities.' end
 model.activityIdHistory=model.activityIdHistory or {};local ids=model.activityIdHistory
 for _,a in ipairs(d.rotationEvents) do ids[a.id]=true end
 local base=self:GenerateUuid();local id=base;local n=1;while ids[id] do n=n+1;id=base..'-'..n end
 ids[id]=true;d.rotationEvents[#d.rotationEvents+1]={id=id,name=clean};model.activityId=id;model.dirty=true;return id
end
function S:RenamePlannerActivity(model,id,name)
 local clean,err=validName(self,name);if not clean then return false,err end
 for _,a in ipairs(model.schedule.rotationEvents or {})do if a.id==id then a.name=clean;model.dirty=true;return true end end
 return false,'Choose an activity.'
end
function S:MovePlannerActivity(model,id,delta)
 local list=model.schedule.rotationEvents or {};for i,a in ipairs(list)do if a.id==id and list[i+delta] then list[i],list[i+delta]=list[i+delta],list[i];model.dirty=true;return true end end;return false
end
function S:RemovePlannerActivity(model,id)
 for _,v in pairs(model.schedule.messageVariants or {})do if v==id then return false,'Assign this activity’s messages to another group before removing it.' end end
 for i,a in ipairs(model.schedule.rotationEvents or {})do if a.id==id then table.remove(model.schedule.rotationEvents,i);model.activityId=nil;model.dirty=true;return true end end;return false
end
function S:AddPlannerImportantTime(model,key,label)
 local d=model.schedule;d.importantTimes=d.importantTimes or {}
 if not key or key=='' then local i=1;while d.importantTimes['time'..i]do i=i+1 end;key='time'..i end
 if not key:match('^[a-z][a-z0-9_]*$') then return nil,'Token keys must start with a lowercase letter and contain only lowercase letters, numbers, and underscores.' end
 if d.importantTimes[key] then return nil,'This token key already exists.' end
 local clean,err=validName(self,label or 'Important time');if not clean then return nil,err end
 d.importantTimes[key]={label=clean,offsetMinutes=-60};model.markId=key;model.dirty=true;return key
end
function S:RemovePlannerImportantTime(model,key)
 for _,r in ipairs(model.schedule.reminders or {})do for _,a in ipairs({r.start,r.finish})do if a and a.kind=='MARK' and a.name==key then return false,'A period uses this important time. Change its boundary before removing it.' end end end
 if not (model.schedule.importantTimes or {})[key] then return false end
 model.schedule.importantTimes[key]=nil;model.markId=nil;model.dirty=true;return true
end
function S:GetPlannerMarkBase(model)
 local o,c=self:GetPlannerOccurrence(model);if o then return o.eventAtUtc,c end
 local d=model.schedule;local at=self:ParseScheduleDateTime(d.eventDate,d.eventTime,d.eventFold or 'FIRST',d)
 return at,d
end
function S:SetPlannerImportantTimeDateTime(model,key,date,clock)
 local mark=(model.schedule.importantTimes or {})[key];if not mark then return false,'Choose an important time.' end
 local base,c=self:GetPlannerMarkBase(model);if not base then return false,'Choose a valid event date and time first.' end
 local at,err=self:ParseScheduleDateTime(date,clock,nil,c);if not at then return false,err end
 local minutes=(at-base)/60;if minutes~=math.floor(minutes) or math.abs(minutes)>5256000 then return false,'Choose an important time within 10 years of the event.' end
 mark.offsetMinutes=minutes;model.dirty=true;return true
end
function S:SetPlannerCancellation(model,date,action)
 if action~=nil and action~='KEEP' and action~='POSTPONE' then return false,'Choose Keep or Postpone rotation.' end
 if not self:ParseScheduleDateTime(date,'12:00 PM','FIRST',model.schedule) then return false,'Choose a valid cancellation date.' end
 model.schedule.occurrenceExceptions=model.schedule.occurrenceExceptions or {};model.schedule.occurrenceExceptions[date]=action and {action=action} or nil;model.dirty=true;return true
end
function S:BuildPlannerAdvancedEditor(parent,w)
 local UI=self.PlannerUI;local m=self.plannerModel;local d=m.schedule;local y=8;local width=w-24
 local function changed(refresh)self:PlannerChanged();if refresh then self:RefreshEventPlanner()end end
 local function result(ok,err)if ok then changed(true)elseif err then self:PlannerError(err)end end
 local function label(key,text,height)
  local control=UI.label(parent,key,text,12,y,width,10000)
  local h=math.max(height or 28,control:GetTextHeight()+2);control:SetHeight(h);y=y+h+6
 end
 local function combo(key,title,labels,values,value,cb)label(key..'title',title);UI.combo(parent,key,labels,values,value,12,y,width,cb);y=y+40 end
 local function button(key,text,cb)UI.button(parent,key,text,12,y,width,cb);y=y+40 end
 local function edit(key,title,value,cb)label(key..'title',title);UI.edit(parent,key,value,12,y,width,32,cb);y=y+40 end
 local function slider(key,title,value,min,max,cb)UI.slider(parent,key,title,value,min,max,12,y,width,cb,tostring);y=y+66 end
 label('advancedTitle','ADVANCED EVENT CONFIGURATION')
 if d.recurrence=='MONTHLY_WEEKDAY' then
  local n=self:NormalizeSchedule(d) or {}
  combo('monthlyWeek','Monthly on',{'First','Second','Third','Fourth','Fifth','Last'},{1,2,3,4,5,'LAST'},d.monthlyWeek or n.monthlyWeek or 1,function(v)d.monthlyWeek=v;changed()end)
  combo('monthlyDay','Weekday',days,{1,2,3,4,5,6,7},d.monthlyWeekday or n.monthlyWeekday or 1,function(v)d.monthlyWeekday=v;changed()end)
  label('monthlyHelp','Last occurs every month. Fifth skips months with only four of that weekday. The event date anchors the starting month.',58)
 end
 if d.recurrence~='NONE' then
  label('weekdaysTitle','Repeat on weekdays (optional)');d.weekdays=d.weekdays or {}
  for i,name in ipairs(days)do local day=i;UI.check(parent,'weekday'..i,name,d.weekdays[i],12,y,width,function(v)d.weekdays[day]=v;changed()end);y=y+30 end
  label('weekdayHelp','With no selection, weekly schedules use the original event weekday. Selected days add occurrences in eligible weeks; daily schedules still honor their interval.',76)
 end
 if d.mode=='EVENT' and d.recurrence~='NONE' then
  combo('pattern','Special event pattern',{'None','Faction rotation','Rotating event','Last event of month'},{'NONE','FACTION_ROTATION','EVENT_ROTATION','MONTH_FINAL'},d.specialPattern or 'NONE',function(v)d.specialPattern=v;changed(true)end)
 end
 if d.specialPattern=='FACTION_ROTATION' then
  local function cycleText()
   local count=0;for _,code in ipairs(d.rotationFactions or {'AD','EP','DC'})do if code~='NONE'then count=count+1 end end
   return 'Complete rotation: '..((d.rotationWeeks or 4)*count)..' weeks ('..(d.rotationWeeks or 4)..' weeks x '..count..' factions).'
  end
  slider('factionWeeks','Weeks per faction',d.rotationWeeks or 4,1,52,function(v)d.rotationWeeks=v;changed();if parent.plannerControls.factionCycle then parent.plannerControls.factionCycle:SetText(cycleText())end end)
  local factions=d.rotationFactions or {'AD','EP','DC'}
  for i=1,3 do local index=i;local names={'Aldmeri Dominion','Ebonheart Pact','Daggerfall Covenant'};local values={'AD','EP','DC'};if i>1 then table.insert(names,1,'Not used');table.insert(values,1,'NONE')end
   combo('faction'..i,({'First faction','Second faction','Third faction'})[i],names,values,factions[i] or 'NONE',function(v)d.rotationFactions=d.rotationFactions or {'AD','EP','DC'};d.rotationFactions[index]=v;changed(true)end)
  end
  label('factionCycle',cycleText(),50)
  label('factionHelp','Event date anchors the first faction block. Each faction must be unique. Use %eventfaction% for the full faction name.',58)
 elseif d.specialPattern=='EVENT_ROTATION' then
  slider('activityEvery','Occurrences per activity',d.rotationEvery or 1,1,1000,function(v)d.rotationEvery=v;changed()end)
  label('activityHelp','Activities repeat in order, including while offline. Use %eventactivity%. IDs remain stable when renamed or reordered.',58)
  local names,ids={},{};for i,a in ipairs(d.rotationEvents or {})do names[i]=i..'. '..a.name;ids[i]=a.id end
  if not m.activityId then m.activityId=ids[1]end
  combo('activity','Selected activity',names,ids,m.activityId,function(v)m.activityId=v;self:RefreshEventPlanner()end)
  local selected;for _,a in ipairs(d.rotationEvents or {})do if a.id==m.activityId then selected=a end end
  if selected then
   edit('activityName','Activity name',selected.name,function(v)local ok,err=self:RenamePlannerActivity(m,selected.id,v);if ok then changed()else self:PlannerError(err)end end)
   button('activityUp','Move activity up',function()result(self:MovePlannerActivity(m,selected.id,-1))end)
   button('activityDown','Move activity down',function()result(self:MovePlannerActivity(m,selected.id,1))end)
   button('activityRemove','Remove activity',function()result(self:RemovePlannerActivity(m,selected.id))end)
  end
  edit('activityNew','New activity name',m.newActivityName or '',function(v)m.newActivityName=v end)
  button('activityAdd','Add activity',function()local id,err=self:AddPlannerActivity(m,m.newActivityName);if id then m.newActivityName='' end;result(id,err)end)
 elseif d.specialPattern=='MONTH_FINAL' then label('monthFinalHelp','The last scheduled event of each month uses Month-final messages; regular messages are the fallback. All events messages apply to both groups.',76)end
 if d.recurrence~='NONE' or next(d.occurrenceExceptions or {}) then
  label('cancelTitle','OCCURRENCE CANCELLATIONS');label('cancelHelp','Keep rotation advances normally. Postpone rotation holds that slot. Changes apply when you save the event.',58)
  local c=self:NormalizeSchedule(d);local rows=c and self:GetNominalScheduleOccurrences(c,GetTimeStamp(),12) or {};local labels,dates,seen={},{},{}
  for _,o in ipairs(rows)do local date=self:GetScheduleOccurrenceDate(c,o.eventAtUtc);seen[date]=true;dates[#dates+1]=date;labels[#labels+1]=date..(c.specialPattern~='NONE' and ' - '..self:GetScheduleVariantLabel(self:GetScheduleEventVariant(c,o.eventAtUtc),c.specialPattern,c) or '')..(o.cancelled and ' (cancelled: '..o.exceptionAction..')' or '')end
  local old={};for date in pairs(d.occurrenceExceptions or {})do if not seen[date]then old[#old+1]=date end end;table.sort(old)
  for _,date in ipairs(old)do dates[#dates+1]=date;labels[#labels+1]=date..' (cancelled: '..d.occurrenceExceptions[date].action..')'end
  local found=false;for _,date in ipairs(dates)do if date==m.cancellationDate then found=true end end;if not found then m.cancellationDate=dates[1]end
  combo('cancellation','Occurrence to cancel or undo',labels,dates,m.cancellationDate,function(v)m.cancellationDate=v;self:RefreshEventPlanner()end)
  combo('cancelAction','Cancellation rotation',{'Keep rotation','Postpone rotation'},{'KEEP','POSTPONE'},m.cancellationAction or 'KEEP',function(v)m.cancellationAction=v end)
  button('cancelOccurrence','Cancel selected occurrence',function()if m.cancellationDate then result(self:SetPlannerCancellation(m,m.cancellationDate,m.cancellationAction or 'KEEP'))end end)
  button('undoOccurrence','Undo selected cancellation',function()if m.cancellationDate then result(self:SetPlannerCancellation(m,m.cancellationDate,nil))end end)
  label('earlierTitle','Earlier cancellation date');UI.date(parent,'earlierDate',m.earlierCancellationDate or d.eventDate,12,y,width,function(v)m.earlierCancellationDate=v;self:RefreshEventPlanner()end);y=y+40
  button('undoEarlier','Undo earlier cancellation',function()result(self:SetPlannerCancellation(m,m.earlierCancellationDate or d.eventDate,nil))end)
 end
 label('marksTitle','IMPORTANT TIMES')
 local names,keys={},{};for key in pairs(d.importantTimes or {})do keys[#keys+1]=key end;table.sort(keys)
 for i,key in ipairs(keys)do names[i]=d.importantTimes[key].label..' ('..key..')'end
 if not (d.importantTimes or {})[m.markId] then m.markId=keys[1]end
 combo('mark','Selected important time',names,keys,m.markId,function(v)m.markId=v;self:RefreshEventPlanner()end)
 local mark=(d.importantTimes or {})[m.markId]
 if mark then
  local key=m.markId;edit('markName','Name',mark.label,function(v)mark.label=v;changed()end)
  label('markTokens','Stable tokens: %eventwhen:'..key..'%  %eventdate:'..key..'%\n%eventtime:'..key..'%  %eventcountdown:'..key..'%',58)
  local base,c=self:GetPlannerMarkBase(m)
  if base then local p=self:GetScheduleParts(base+(mark.offsetMinutes or 0)*60,c);local date=string.format('%04d-%02d-%02d',p.year,p.month,p.day);local clock=string.format('%02d:%02d %s',p.hour%12==0 and 12 or p.hour%12,p.min,p.hour>=12 and 'PM' or 'AM')
   label('markDateTitle','Date relative to upcoming event occurrence');UI.date(parent,'markDate',date,12,y,width,function(v)result(self:SetPlannerImportantTimeDateTime(m,key,v,clock))end);y=y+40
   UI.clock(parent,'markClock',clock,12,y,width,function(v)result(self:SetPlannerImportantTimeDateTime(m,key,date,v))end,c.timeZone);y=y+40
  else label('markNeedsDate','Set a valid event date and time to edit this important time.',50)end
  button('markRemove','Remove important time',function()result(self:RemovePlannerImportantTime(m,key))end)
 end
 edit('markKey','New token key (optional; generated when empty)',m.newMarkKey or '',function(v)m.newMarkKey=v end)
 edit('markNewName','New important time name',m.newMarkName or '',function(v)m.newMarkName=v end)
 button('markAdd','Add important time',function()local id,err=self:AddPlannerImportantTime(m,m.newMarkKey,m.newMarkName~='' and m.newMarkName or nil);if id then m.newMarkKey='';m.newMarkName=''end;result(id,err)end)
 return y+8
end
