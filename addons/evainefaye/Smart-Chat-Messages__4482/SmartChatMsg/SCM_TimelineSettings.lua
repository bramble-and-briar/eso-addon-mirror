SmartChatMsg = SmartChatMsg or {}
local S=SmartChatMsg
local function copy(v) if type(v)~='table' then return v end local r={} for k,x in pairs(v) do r[k]=copy(x) end return r end
local function includes(t,id) for _,v in ipairs(t or {}) do if v==id then return true end end return false end
local function dirty(self) self.scheduleEditor.dirty=true;self:RefreshSettingsUI() end
function S:FormatSchedulingMinutes(value,zero)
 local n=tonumber(value) or 0;if n==0 then return zero or 'Not set' end
 local h=math.floor(n/60);local m=n%60;local parts={}
 if h>0 then parts[#parts+1]=h..(h==1 and ' hour' or ' hours') end
 if m>0 then parts[#parts+1]=m..(m==1 and ' minute' or ' minutes') end
 return table.concat(parts,' ')
end
function S:BuildSchedulingSlider(label,reference,min,max,get,set,describe,disabled)
 local explanations={
  ['Event duration']='How long the event runs after its start. Not set is no event-end cap. A positive duration enables underway invitations and limits them to the event end.',
  ['Recurrence interval']='Multiplier for the selected event recurrence. Every week with interval 2 means every two weeks; every other week with interval 2 means every four weeks. It does not set announcement frequency.',
  ['Repeat Frequency']='How often an eligible message is prepared during this period. All selected messages share the interval. Send once uses its own deadline instead.',
 }
 return {type='slider',reference=reference,name=function()return label..' — '..describe(tonumber(get()) or min)end,min=min,max=max,step=1,decimals=0,clampInput=true,
  tooltip=(explanations[label] and explanations[label]..' ' or '')..'Drag or use the mouse wheel. Existing saved values outside this slider range are retained until you change them.',
  getFunc=function()return tonumber(get()) or min end,setFunc=function(value)local n=tonumber(value);if not n or n~=math.floor(n) or n<min or n>max then self:ShowStatusMessage(label..': choose a whole number from '..min..' to '..max..'.');return end;set(n)end,disabled=disabled}
end
function S:GetSelectedTimelineReminder()
 local d=self:GetScheduleEditorDraft()
 for _,r in ipairs(d.reminders or {}) do if r.id==self.scheduleEditor.reminderId then return r end end
 local r=(d.reminders or {})[1];self.scheduleEditor.reminderId=r and r.id;return r
end
function S:AddTimelineReminder()
 local d=self:GetScheduleEditorDraft();d.reminders=d.reminders or {}
 if #d.reminders>=100 then return nil end
 local ids={} for _,r in ipairs(d.reminders) do ids[r.id]=true end
 local base=self:GenerateUuid();local id=base;local suffix=1
 while ids[id] do suffix=suffix+1;id=base..'-'..suffix end
 local r={id=id,label='New period',start={kind='OFFSET',minutes=-60},finish={kind='OFFSET',minutes=0},intervalMinutes=15,lateMinutes=5,once=false,timeSensitive=false,messageIds={}}
 d.reminders[#d.reminders+1]=r;self.scheduleEditor.reminderId=id;dirty(self);return r
end
function S:RemoveTimelineReminder(id)
 local d=self:GetScheduleEditorDraft();if #(d.reminders or {})<=1 then return false end
 for i,r in ipairs(d.reminders) do if r.id==id then table.remove(d.reminders,i);self.scheduleEditor.reminderId=nil;dirty(self);return true end end
 return false
end
function S:AddTimelineImportantTime(label,minutes)
 local d=self:GetScheduleEditorDraft();d.importantTimes=d.importantTimes or {}
 local i=1;while d.importantTimes['time'..i] do i=i+1 end
 local id='time'..i;d.importantTimes[id]={label=label or 'Important time',offsetMinutes=minutes or -60};self.scheduleEditor.markId=id;dirty(self);return id
end
function S:RemoveTimelineImportantTime(id)
 local d=self:GetScheduleEditorDraft()
 for _,r in ipairs(d.reminders or {}) do for _,a in ipairs({r.start,r.finish}) do if a and a.kind=='MARK' and a.name==id then return false end end end
 if not (d.importantTimes or {})[id] then return false end
 d.importantTimes[id]=nil;self.scheduleEditor.markId=nil;dirty(self);return true
end
-- Shared by explicit single-event conversion and helper-command consolidation.
-- eventAtUtc is the chosen parent's true event; sourceEventAtUtc identifies the
-- aligned source occurrence (which may have used a technical helper time).
function S:BuildLegacyTimelineRows(config,command,guild,eventAtUtc,sourceEventAtUtc)
 local c,reason=self:NormalizeSchedule(config);if not c then return nil,reason end
 local sourceEvent=sourceEventAtUtc or c.eventAtUtc;local occurrence=self:BuildScheduleOccurrence(c,sourceEvent)
 if not occurrence then return nil,'The source occurrence cannot be resolved.' end
 local event=eventAtUtc or sourceEvent;local p=self:GetScheduleParts(sourceEvent,c)
 local midnight=self:ParseScheduleDateTime(string.format('%04d-%02d-%02d',p.year,p.month,p.day),'12:00 AM',nil,c)
 local soon=c.startingSoonEnabled and sourceEvent-c.startingSoonMinutes*60 or sourceEvent
 local ranges={}
 if c.mode=='EVENT' then
  ranges={{'BEFORE','Before event day',occurrence.startsAtUtc,math.min(midnight,soon)},{'DAY','On event day',math.max(occurrence.startsAtUtc,midnight),math.min(soon,sourceEvent)}}
  if c.startingSoonEnabled then ranges[#ranges+1]={'SOON','Starting soon',math.max(occurrence.startsAtUtc,soon),sourceEvent} end
  ranges[#ranges+1]={'LIVE','After event starts',sourceEvent,occurrence.endsAtUtc}
 else ranges={{'ANY',c.mode=='REMINDER' and 'One-time reminder' or 'While active',occurrence.startsAtUtc,occurrence.endsAtUtc}} end
 local parentDay=math.floor((event+self:GetTimeZoneUtcOffset(event,c.timeZone)*3600)/86400)
 local function civil(utc)
  local part=self:GetScheduleParts(utc,c)
  return {kind='DAY',days=math.floor((utc+self:GetTimeZoneUtcOffset(utc,c.timeZone)*3600)/86400)-parentDay,time=string.format('%02d:%02d %s',part.hour%12==0 and 12 or part.hour%12,part.min,part.hour>=12 and 'PM' or 'AM')}
 end
 local function anchor(utc,phase)
  if phase=='SOON' or phase=='LIVE' or c.mode=='EVENT' and (utc==sourceEvent or c.startingSoonEnabled and utc==soon) then return {kind='OFFSET',minutes=math.floor((utc-event)/60)} end
  return civil(utc)
 end
 local rows,ids={},{}
 for _,range in ipairs(ranges) do if range[4]>range[3] then
  local base=self:GenerateUuid();local id=base;local suffix=1;while ids[id] do suffix=suffix+1;id=base..'-'..suffix end;ids[id]=true
  local r={id=id,label=range[2],start=anchor(range[3],range[1]),finish=anchor(range[4],range[1]),messageIds={},timeSensitive=false,legacyPhase=range[1]}
  r.intervalMinutes=(c.phaseIntervals or {})[range[1]] or c.intervalMinutes or 15;r.once=(c.phaseOnce or {})[range[1]]==true
  if c.mode=='REMINDER' then r.once=true;r.lateMinutes=math.max(1,math.ceil((range[4]-range[3])/60)) else r.lateMinutes=math.min(1440,math.max(1,math.ceil((range[4]-range[3])/60)));r.onceUntilFinish=r.once end
  for _,m in ipairs(self:GetMessageEntriesForCommandAndGuild(command,guild)) do local a=(c.messagePhases or {})[m.id];if not a or a.ANY or a[range[1]] then r.messageIds[#r.messageIds+1]=m.id end end
  rows[#rows+1]=r
 end end
 return rows,copy(c.messageVariants or {})
end
-- Conversion is opt-in and retains the complete original configuration.
function S:ConvertScheduleDraftToTimeline()
 local d,command,guild=self:GetScheduleEditorDraft();if d.timelineVersion then return false,'This event already uses reminders.' end
 if d.mode~='EVENT' then return false,'Choose Promote an event first.' end
 local rows,variants=self:BuildLegacyTimelineRows(d,command,guild)
 if not rows then return false,variants end
 d.legacyTimelineBackup=copy(d);d.timelineVersion=1;d.importantTimes={};d.reminders=rows
 if #d.reminders==0 then self:AddTimelineReminder() end
 self.scheduleEditor.reminderId=d.reminders[1].id;dirty(self);return true
end
function S:GetTimelinePreviewContext(id)
 local c,reason=self:NormalizeSchedule(self:GetScheduleEditorDraft());if not c then return nil,reason end
 local occurrence=self:GetUpcomingScheduleOccurrences(c,GetTimeStamp(),1,true)[1] or self:BuildScheduleOccurrence(c,c.eventAtUtc)
 if not occurrence then return nil,'No event occurrence is available.' end
 for _,r in ipairs(c.reminders) do if r.id==id then
  local first,last=self:GetTimelineReminderWindow(c,occurrence,r)
  if not first or not last or last<=first then return nil,'This reminder is outside the event duration. Adjust its window or enable its explicit after-event exception.' end
  return {schedule=c,occurrence=occurrence,now=first+math.floor((last-first)/2),phase=r.id,reminderId=r.id}
 end end
 return nil,'Choose a reminder to test.'
end
local checklist=S.GetScheduleMessageChecklist
function S:GetScheduleMessageChecklist(phase)
 if phase~='TIMELINE' then return checklist(self,phase) end
 local r=self:GetSelectedTimelineReminder();if not r then return {} end
 local choices=checklist(self,'ANY')
 for _,choice in ipairs(choices) do
  local id=choice.messageId;local rowId=r.id
  choice.phaseText='Reminder: '..r.label
  choice.getFunc=function() for _,row in ipairs(self:GetScheduleEditorDraft().reminders or {}) do if row.id==rowId then return includes(row.messageIds,id) end end return false end
  choice.setFunc=function(value)
   for _,row in ipairs(self:GetScheduleEditorDraft().reminders or {}) do if row.id==rowId then
    local result={} for _,v in ipairs(row.messageIds or {}) do if v~=id then result[#result+1]=v end end
    if value then result[#result+1]=id end row.messageIds=result;dirty(self);return
   end end
  end
 end
 return choices
end
local context=S.GetMessagePreviewContext
function S:GetMessagePreviewContext(entry,phase)
 if phase=='TIMELINE' then local r=self:GetSelectedTimelineReminder();return self:GetTimelinePreviewContext(r and r.id) end
 return context(self,entry,phase)
end
local testMessage=S.TestMessagePreview
function S:TestMessagePreview(id,phase)
 if phase~='TIMELINE' then return testMessage(self,id,phase) end
 local r=self:GetSelectedTimelineReminder();local ctx,reason=self:GetTimelinePreviewContext(r and r.id)
 if not ctx then self:AddLocalChatMessage('[SmartChatMsg] Test unavailable: '..tostring(reason));return nil end
 for _,entry in ipairs(self.savedVars.messages or {}) do if entry.id==id then
  local text=self.settings and self.settings.GetEffectiveMessageText and self.settings:GetEffectiveMessageText(entry) or entry.text
  local output=self:ApplyMessageSubstitutions(text,entry.commandId,entry.guildName,ctx)
  self:AddLocalChatMessage('[SmartChatMsg] Message test — '..r.label..' — '..self:FormatScheduleDateTime(ctx.now,ctx.schedule));self:AddLocalChatMessage(output);return output,ctx
 end end
end
function S:DescribeTimelineAnchor(a,d)
 if not a then return 'Choose a time' end
 local c=self:NormalizeSchedule(d);if c then local list=self:GetUpcomingScheduleOccurrences(c,GetTimeStamp(),1,true);local at=list[1] and list[1].eventAtUtc or c.eventAtUtc;local value=self:ResolveTimelineAnchor(c,{eventAtUtc=at},a);if value then return self:FormatScheduleDateTime(value,c) end end
 if a.kind=='MARK' then local m=(d.importantTimes or {})[a.name];return m and m.label or 'Choose an important time' end
 if a.kind=='DAY' then return tostring(a.days)..' calendar days from event at '..tostring(a.time) end
 local minutes=tonumber(a.minutes) or 0
 if minutes==0 then return 'Event starts' end
 local magnitude=math.abs(minutes);local amount=magnitude%1440==0 and tostring(magnitude/1440)..' days' or magnitude%60==0 and tostring(magnitude/60)..' hours' or tostring(magnitude)..' minutes'
 return amount..(minutes<0 and ' before event' or ' after event')
end
-- Native cards are bounded and scrollable; selecting a card edits one stable row.
function S:RefreshTimelineCards(control,marks)
 local d=self:GetScheduleEditorDraft();local width=math.max(240,control:GetWidth() or 520)
 if not control.timelineScroll then
  self.timelineControlSerial=(self.timelineControlSerial or 0)+1;control.timelineControlName='SCM_TimelineCards'..self.timelineControlSerial
  local scroll=WINDOW_MANAGER:CreateControlFromVirtual(control.timelineControlName,control,'ZO_ScrollContainer');scroll:SetAnchor(TOPLEFT,control,TOPLEFT,0,0);scroll:SetHeight(180)
  control.timelineScroll=scroll;control.timelineContent=scroll:GetNamedChild('Scroll'):GetNamedChild('Child');control.timelineContent:SetResizeToFitDescendents(false);control.timelineRows={}
  control:SetHandler('OnRectWidthChanged',function() self:RefreshTimelineCards(control,marks) end)
  control:SetHandler('OnEffectivelyShown',function() self:RefreshTimelineCards(control,marks) end)
 end
 local scroll,content=control.timelineScroll,control.timelineContent;scroll:SetWidth(width);content:SetWidth(width-28)
 for _,r in ipairs(control.timelineRows) do r:SetHidden(true) end
 local items={}
 if marks then for id,m in pairs(d.importantTimes or {}) do items[#items+1]={id=id,label=m.label,detail=tostring(m.offsetMinutes)..' minutes from event - token key: '..id} end table.sort(items,function(a,b) return a.id<b.id end)
 else for _,r in ipairs(d.reminders or {}) do items[#items+1]={id=r.id,label=r.label,detail=(r.paused and 'Paused' or r.enabled==false and 'Disabled' or 'Enabled')..' · '..self:DescribeTimelineAnchor(r.start,d)..(r.once and not r.onceUntilFinish and '' or ' → '..self:DescribeTimelineAnchor(r.finish,d))..'\n'..(r.once and (r.onceUntilFinish and 'Once within window' or 'Once') or 'Every '..tostring(r.intervalMinutes)..' minutes')..' · '..(r.timeSensitive and 'Time-sensitive' or 'Normal')..' · '..#(r.messageIds or {})..' messages'} end end
 local y=0
 for i,item in ipairs(items) do
  local card=control.timelineRows[i]
  if not card then
   local name=control.timelineControlName..'Card'..i
   card=WINDOW_MANAGER:CreateControl(name,content,CT_CONTROL);card:SetMouseEnabled(true)
   card.backdrop=WINDOW_MANAGER:CreateControlFromVirtual(name..'Backdrop',card,'ZO_DefaultBackdrop');card.backdrop:SetAnchorFill(card);card.backdrop:SetCenterColor(0.025,0.025,0.035,0.95);card.backdrop:SetEdgeColor(0.55,0.43,0.22,0.8)
   card.label=WINDOW_MANAGER:CreateControl(name..'Label',card,CT_LABEL);card.label:SetFont('ZoFontGame');card.label:SetAnchor(TOPLEFT,card,TOPLEFT,12,8);card.label:SetColor(0.95,0.82,0.45,1)
   local function wheel(_,delta) ZO_Scroll_OnMouseWheel(scroll,delta) end card:SetHandler('OnMouseWheel',wheel);card.label:SetMouseEnabled(true);card.label:SetHandler('OnMouseWheel',wheel)
   control.timelineRows[i]=card
  end
  card:SetHidden(false);card:SetWidth(width-28);card:ClearAnchors();card:SetAnchor(TOPLEFT,content,TOPLEFT,0,y);card.label:SetWidth(width-56);card.label:SetHeight(10000)
  local selected=marks and self.scheduleEditor.markId==item.id or not marks and self:GetSelectedTimelineReminder() and self:GetSelectedTimelineReminder().id==item.id
  card.label:SetText((selected and '|cE8C56ASelected · |r' or '')..item.label..'\n|cBDB8AA'..item.detail..'|r');local height=math.max(60,card.label:GetTextHeight()+16);card.label:SetHeight(height-16);card:SetHeight(height)
  local function choose(_,button,inside) if button==MOUSE_BUTTON_INDEX_LEFT and inside then if marks then self.scheduleEditor.markId=item.id else self.scheduleEditor.reminderId=item.id end self:RefreshSettingsUI() end end
  card:SetHandler('OnMouseUp',choose);card.label:SetHandler('OnMouseUp',choose);y=y+height+6
 end
 content:SetHeight(math.max(y,1));control:SetHeight(180);ZO_Scroll_UpdateScrollBar(scroll,true)
end
local build=S.BuildScheduleOptionControls
function S:BuildScheduleOptionControls()
 local controls=build(self)
 local function draft() return self:GetScheduleEditorDraft() end
 local function row() return self:GetSelectedTimelineReminder() end
 local function active() return draft().timelineVersion==1 end
 local function refresh() dirty(self) end
 -- Retain common event settings; no alternate schedule types or phase pools.
 local clean={};local refs={SCM_EventTimingSubmenu=true,SCM_MonthlyWeekdaySubmenu=true,SCM_FactionRotationSubmenu=true,SCM_EventRotationSubmenu=true,SCM_OccurrenceCancellationSubmenu=true}
 for i,c in ipairs(controls) do
  local ref=c.reference or ''
  if ref=='SCM_EventTimingSubmenu' then local dates={};for n=1,4 do dates[n]=c.controls[n] end;c.controls=dates;c.name='Event date and time';c.disabled=nil end
  if i<=3 or refs[ref] or ref:match('^SCM_Repeat') or c.name=='Guild timezone' or c.name=='Repeat schedule' or c.name=='Special event pattern' or c.name=='Save and activate' or c.name=='Save disabled' then clean[#clean+1]=c end
 end
 controls=clean
 for _,c in ipairs(controls) do if c.reference=='SCM_RepeatOptionsSubmenu' then
  c.controls[1]=self:BuildSchedulingSlider('Recurrence interval','SCM_PeriodRecurrenceSlider',1,10,function()return draft().recurrenceInterval or 1 end,function(n)draft().recurrenceInterval=n;refresh()end,function(n)local recurrence=draft().recurrence;local unit=recurrence=='DAILY' and 'day' or (recurrence=='WEEKLY' or recurrence=='BIWEEKLY') and 'week' or 'month';local count=recurrence=='BIWEEKLY' and n*2 or n;return 'Every '..count..' '..unit..(count==1 and '' or 's')end,function()return draft().recurrence=='NONE'end)
 end end

 controls[#controls+1]={type='description',reference='SCM_NextScheduleOccurrence',text=function()return self:GetNextScheduleOccurrenceText(draft())end}
 local helpText={
  label='A short name for this announcement period. It is shown in status and previews, not sent in chat.',
  lateMinutes='How many minutes a one-time announcement remains eligible after its scheduled start. If it expires while offline, it is skipped.',
  once='Prepare one announcement for this period per event occurrence. Only a confirmed send or matching peer announcement completes it; preparing or timing out does not.',
  onceUntilFinish='With Send once enabled, allow the announcement anywhere between Period Starts and Period Stops. Otherwise its lateness allowance defines the short deadline. It still sends only once.',
  timeSensitive='Prioritize a start/deadline notice and bypass ordinary spacing between schedules. Startup delay, player chat protection, peer cooldowns and daily limits still apply.',
  allowAfterEventEnd='Advanced exception for a brief closing announcement after the event ends. Usually use Send once and a short deadline; this does not extend the actual event duration.',
 }
 local function field(name,key,numeric)
  return {type='editbox',name=name,tooltip=helpText[key],getFunc=function() return tostring(row() and row()[key] or '') end,setFunc=function(v) if row() then row()[key]=numeric and (tonumber(v) or v) or v;refresh() end end,disabled=function() return not active() or not row() end}
 end
 local function flag(name,key)
  return {type='checkbox',name=name,width='full',tooltip=helpText[key],getFunc=function() return row() and row()[key]==true end,setFunc=function(v) if row() then row()[key]=v;refresh() end end,disabled=function() return not active() or not row() or key=='onceUntilFinish' and not row().once end}
 end
 local function selectedMark()
  local marks=draft().importantTimes or {};local id=self.scheduleEditor.markId
  if not marks[id] then for key in pairs(marks) do id=key;break end self.scheduleEditor.markId=id end
  return marks[id],id
 end
 local function markClock()
  local d=draft();local normalized=self:NormalizeSchedule(d)
  local upcoming=normalized and self:GetUpcomingScheduleOccurrences(normalized,GetTimeStamp(),1,true)
  local at=upcoming and upcoming[1] and upcoming[1].eventAtUtc or self:ParseScheduleDateTime(d.eventDate,d.eventTime,d.eventFold or 'FIRST',d)
  local m=selectedMark();local parts=at and self:GetScheduleParts(at+(tonumber(m and m.offsetMinutes) or 0)*60,d)
  if not parts then return d.eventDate,d.eventTime,at end
  return string.format('%04d-%02d-%02d',parts.year,parts.month,parts.day),string.format('%02d:%02d %s',parts.hour%12==0 and 12 or parts.hour%12,parts.min,parts.hour>=12 and 'PM' or 'AM'),at
 end
 local function setMarkClock(date,time)
  local m=selectedMark();local _,_,at=markClock();if not m or not at then return end
  local target,reason=self:ParseScheduleDateTime(date,time,'FIRST',draft())
  if not target then self:ShowStatusMessage(reason or 'Choose a valid important date and time.');return end
  m.offsetMinutes=(target-at)/60;refresh()
 end
 local named={
  {type='description',text='Choose the date and time of a named moment such as Ticket sales close, in the scheduling timezone. Its relationship to the next event is saved and follows recurring events automatically.'},
  {type='custom',minHeight=180,maxHeight=180,createFunc=function(c) self:RefreshTimelineCards(c,true) end,refreshFunc=function(c) self:RefreshTimelineCards(c,true) end},
  {type='button',name='Add important time',func=function() self:AddTimelineImportantTime() end},
  {type='editbox',name='Important time name',getFunc=function() local m=selectedMark();return m and m.label or '' end,setFunc=function(v) local m=selectedMark();if m then m.label=v;refresh() end end},
  {type='description',text=function() local m,id=selectedMark();if not m then return 'Add an important time to see its message substitutions.' end return 'Message substitutions for '..m.label..': %eventwhen:'..id..'% - %eventdate:'..id..'% - %eventtime:'..id..'% - %eventcountdown:'..id..'%' end},
  {type='datepicker',name='Important time date',tooltip='Select the date of this named moment relative to the next event. Its saved offset follows recurring events; use the displayed key in message substitutions.',datePickerType='normal',getFunc=function()local date=markClock();return self:ScheduleDateToPicker(date)end,setFunc=function(v)local _,time=markClock();setMarkClock(self:ScheduleDateFromPicker(v),time)end,disabled=function()return not selectedMark()end},
  {type='button',name='Remove important time',func=function() local _,id=selectedMark();if not self:RemoveTimelineImportantTime(id) then self:ShowStatusMessage('Choose another start or end for reminders using this important time before removing it.') end end},
 }
 for index,part in ipairs({'hour','minute','AM/PM'}) do
  local choices={};if index==1 then for n=1,12 do choices[#choices+1]=string.format('%02d',n)end elseif index==2 then for n=0,59 do choices[#choices+1]=string.format('%02d',n)end else choices={'AM','PM'}end
  table.insert(named,#named,{type='dropdown',name='Important time '..part,tooltip='Clock for this named moment in the guild scheduling timezone. It is converted to an offset from the next actual event occurrence.',choices=choices,getFunc=function()local _,time=markClock();local h,m,a=tostring(time):match('^(%d%d?):(%d%d) ([AP]M)$');return ({h or '08',m or '00',a or 'PM'})[index]end,setFunc=function(value)local date,time=markClock();local h,m,a=tostring(time):match('^(%d%d?):(%d%d) ([AP]M)$');local parts={h or '08',m or '00',a or 'PM'};parts[index]=value;setMarkClock(date,parts[1]..':'..parts[2]..' '..parts[3])end,disabled=function()return not selectedMark()end})
 end
 local duration=self:BuildSchedulingSlider('Event duration','SCM_PeriodDurationSlider',0,240,function()return draft().eventDurationMinutes or 0 end,function(n)draft().eventDurationMinutes=n>0 and n or nil;refresh()end,function(n)return self:FormatSchedulingMinutes(n,'Not set')end)
 local rowState={type='dropdown',name='Period Status',tooltip='Pause or disable only this period without deleting messages or cooldown history.',choices={'Enabled','Paused','Disabled'},getFunc=function()local r=row();return r and (r.paused and 'Paused' or r.enabled==false and 'Disabled' or 'Enabled') or 'Enabled'end,setFunc=function(value)local r=row();if r then r.enabled=value~='Disabled';r.paused=value=='Paused';refresh()end end}
 local function periodChoices()
  local labels,ids={},{}
  for i,r in ipairs(draft().reminders or {}) do
   local label=tostring(r.label or '')
   labels[#labels+1]=tostring(i)..'. '..(label~='' and label or 'Unnamed period')
   ids[#ids+1]=r.id
  end
  return labels,ids
 end
 self.rotationEditorChoiceProviders=self.rotationEditorChoiceProviders or {}
 self.rotationEditorChoiceProviders.SCM_TimelinePeriodSelector=periodChoices
 local periodLabels,periodIds=periodChoices()
 local periodSelector={type='dropdown',reference='SCM_TimelinePeriodSelector',name='Edit period',
  tooltip='Choose which period to edit below. All periods belong to this same event; selecting one does not change its schedule.',
  choices=periodLabels,choicesValues=periodIds,scrollable=true,
  getFunc=function()local r=row();return r and r.id end,
  setFunc=function(id)for _,r in ipairs(draft().reminders or {}) do if r.id==id then self.scheduleEditor.reminderId=id;self:RefreshSettingsUI();return end end end,
  disabled=function()return #(draft().reminders or {})==0 end}
 local pane={
  duration,
  {type='description',text='Keep the actual event date and time above. Add as many reminder periods or one-time milestones as you need. The latest active normal period wins an overlap; one-time milestones keep their own delivery. You always press Enter to send.'},
  {type='submenu',name='Important times',controls=named},
  periodSelector,
  {type='description',text='Choose a period above to edit its dates, frequency and message pool below. The list underneath also selects periods and scrolls independently.'},
  {type='header',name='Periods'},
  {type='custom',minHeight=180,maxHeight=180,createFunc=function(c) self:RefreshTimelineCards(c,false) end,refreshFunc=function(c) self:RefreshTimelineCards(c,false) end},
  {type='button',name='Add period',func=function() self:AddTimelineReminder() end},
  {type='button',name='Preview Period Timeline',func=function()
   local c,reason=self:NormalizeSchedule(draft());if not c then self:ShowStatusMessage(reason);return end
   local occurrence=self:GetUpcomingScheduleOccurrences(c,GetTimeStamp(),1,true)[1] or self:BuildScheduleOccurrence(c,c.eventAtUtc)
   if not occurrence then self:ShowStatusMessage('No event occurrence is available.');return end
   self:AddLocalChatMessage('[SmartChatMsg] Event: '..self:FormatScheduleDateTime(occurrence.eventAtUtc,c))
   for _,r in ipairs(c.reminders) do local first=self:ResolveTimelineAnchor(c,occurrence,r.start);local last=(not r.once or r.onceUntilFinish) and self:ResolveTimelineAnchor(c,occurrence,r.finish)
    self:AddLocalChatMessage(r.label..': '..self:FormatScheduleDateTime(first,c)..(last and ' → '..self:FormatScheduleDateTime(last,c) or ' · Once')..' · '..(r.timeSensitive and 'Time-sensitive' or 'Normal'))
   end
  end},
  {type='header',name=function() local r=row();return 'Selected period / '..(r and r.label or 'Choose a period') end},
  field('Period Label','label'),
 }
 local function append(c) pane[#pane+1]=c end
 local function eventOccurrence()
  local d=draft();local c=self:NormalizeSchedule(d)
  if c then local list=self:GetUpcomingScheduleOccurrences(c,GetTimeStamp(),1,true);if list[1] then return list[1].eventAtUtc end end
  return self:ParseScheduleDateTime(d.eventDate,d.eventTime,d.eventFold or 'FIRST',d)
 end
 local function boundary(key)
  local at=eventOccurrence();if not at then return draft().eventDate,draft().eventTime,nil end
  local value=self:ResolveTimelineAnchor(draft(),{eventAtUtc=at},row() and row()[key]) or at
  local p=self:GetScheduleParts(value,draft())
  return string.format('%04d-%02d-%02d',p.year,p.month,p.day),string.format('%02d:%02d %s',p.hour%12==0 and 12 or p.hour%12,p.min,p.hour>=12 and 'PM' or 'AM'),at
 end
 local function setBoundary(key,date,time)
  local r=row();if not r then return end
  local _,_,at=boundary(key);local d=draft();local a=r[key] or {};local target,reason=self:ParseScheduleDateTime(date,time,a.fold or 'FIRST',d)
  if not target or not at then self:ShowStatusMessage(reason or 'Choose a valid event date and time first.');return end
  local allow=self.scheduleEditor.allowAfterStart and self.scheduleEditor.allowAfterStart[r.id]
  local existing=self:ResolveTimelineAnchor(d,{eventAtUtc=at},r.start)
  if key=='start' and target>at and not allow and not (existing and existing>at) then self:ShowStatusMessage('Period Starts must be on or before the event. Enable promotion after event starts for underway announcements.');return end
  local other=self:ResolveTimelineAnchor(d,{eventAtUtc=at},r[key=='start' and 'finish' or 'start'])
  if not (r.once and not r.onceUntilFinish) and other and (key=='start' and target>other or key=='finish' and target<other) then self:ShowStatusMessage('Period Stops must be on or after Period Starts.');return end
  local noon=self:ParseScheduleDateTime(date,'12:00 PM','FIRST',d);local p=self:GetScheduleParts(at,d)
  local eventNoon=self:ParseScheduleDateTime(string.format('%04d-%02d-%02d',p.year,p.month,p.day),'12:00 PM','FIRST',d)
  local days=math.floor(((noon+self:GetTimeZoneUtcOffset(noon,d.timeZone)*3600)-(eventNoon+self:GetTimeZoneUtcOffset(eventNoon,d.timeZone)*3600))/86400+0.5)
  r[key]={kind='DAY',days=days,time=time,fold=a.fold or 'FIRST'};refresh()
 end
 for _,which in ipairs({'start','finish'}) do
  local key=which;local title=key=='start' and 'Period Starts' or 'Period Stops'
  local function unavailable() return not row() or key=='finish' and row().once and not row().onceUntilFinish end
  append({type='header',name=title})
  append({type='datepicker',name=title..' date',tooltip='Calendar boundary of this announcement period in the guild scheduling timezone. The relationship to the event follows future recurring occurrences.',datePickerType='normal',getFunc=function()local date=boundary(key);return self:ScheduleDateToPicker(date)end,setFunc=function(v)local _,time=boundary(key);setBoundary(key,self:ScheduleDateFromPicker(v),time)end,disabled=unavailable})
  for i,part in ipairs({'hour','minute','AM / PM'}) do
   local index=i;local choices={};if i==3 then choices={'AM','PM'} else for n=i==1 and 1 or 0,i==1 and 12 or 59 do choices[#choices+1]=string.format('%02d',n) end end
   append({type='dropdown',name=title..' '..part,tooltip='Server clock in the guild scheduling timezone, including daylight saving for this date. Period Stops must not be before Period Starts.',choices=choices,getFunc=function()local _,time=boundary(key);local h,m,a=tostring(time):match('^(%d%d?):(%d%d) ([AP]M)$');return ({h or '08',m or '00',a or 'PM'})[index]end,setFunc=function(value)local date,time=boundary(key);local h,m,a=tostring(time):match('^(%d%d?):(%d%d) ([AP]M)$');local parts={h or '08',m or '00',a or 'PM'};parts[index]=value;setBoundary(key,date,parts[1]..':'..parts[2]..' '..parts[3])end,disabled=unavailable})
  end
 end
 append({type='checkbox',name='Allow promotion after event starts',tooltip='Allow underway invitations after the event starts. Set a positive Event duration first; periods stop at the event end unless a closing exception is enabled.',getFunc=function()local r=row();if not r then return false end;local _,_,at=boundary('start');local starts=at and self:ResolveTimelineAnchor(draft(),{eventAtUtc=at},r.start);return (self.scheduleEditor.allowAfterStart or {})[r.id]==true or starts and starts>at or false end,setFunc=function(v)local r=row();if r then self.scheduleEditor.allowAfterStart=self.scheduleEditor.allowAfterStart or {};self.scheduleEditor.allowAfterStart[r.id]=v;refresh()end end,disabled=function()return not row() or not (tonumber(draft().eventDurationMinutes) and tonumber(draft().eventDurationMinutes)>0)end})
 append(rowState);append(flag('Allow a closing announcement after the event ends','allowAfterEventEnd'));append(flag('Send once','once'));append(flag('Send once anytime in this period','onceUntilFinish'));append(self:BuildSchedulingSlider('Repeat Frequency','SCM_PeriodFrequencySlider',1,1440,function()return row() and row().intervalMinutes or 30 end,function(n)if row() then row().intervalMinutes=n;refresh()end end,function(n)return 'Every '..self:FormatSchedulingMinutes(n)end,function()return not row() or row().once end));append(flag('Time-sensitive reminder','timeSensitive'))
 append({type='description',text='Time-sensitive reminders can bypass ordinary reminder pacing. Lateness allowance is the number of minutes a one-time reminder remains available. Offline or expired milestones are skipped.'})
 append(field('Lateness allowance (minutes)','lateMinutes',true))
 append({type='custom',minHeight=230,maxHeight=230,createFunc=function(c) self:RefreshScheduleMessagePool(c,'TIMELINE') end,refreshFunc=function(c) self:RefreshScheduleMessagePool(c,'TIMELINE') end})
 append({type='description',text='Check the messages this reminder may use. Click any message text to test it at a simulated time inside this reminder. Message group selectors support regular / month-final events and faction rotation.'})
 append({type='button',name='Remove selected period',func=function() local r=row();if r then self:RemoveTimelineReminder(r.id) end end,disabled=function() return #(draft().reminders or {})<=1 end})
 local index=#controls+1;for i,c in ipairs(controls) do if c.name=='Save and activate' then index=i;break end end
 table.insert(controls,index,{type='submenu',reference='SCM_TimelineSubmenu',name='Period Timeline',controls=pane,disabled=function() return not active() end})
 return controls
end
-- Message libraries show reminder membership rather than obsolete phase tags.
local phaseText=S.GetScheduleMessagePhaseText
function S:GetScheduleMessagePhaseText(messageId,schedule)
 if not schedule or schedule.timelineVersion~=1 then return phaseText(self,messageId,schedule) end
 local labels={}
 for _,row in ipairs(schedule.reminders or {}) do if includes(row.messageIds,messageId) then labels[#labels+1]=row.label end end
 local text=#labels>0 and table.concat(labels,' · ') or 'Not selected for any reminder'
 if schedule.specialPattern and schedule.specialPattern~='NONE' then text=text..' · '..self:GetScheduleVariantLabel(self:GetScheduleMessageVariant(schedule,messageId),schedule.specialPattern,schedule) end
 return text
end
local sortEntries=S.SortScheduledMessageEntries
function S:SortScheduledMessageEntries(entries,schedule)
 if not schedule or schedule.timelineVersion~=1 then return sortEntries(self,entries,schedule) end
 local ranks={};local occurrence=schedule.eventAtUtc and {eventAtUtc=schedule.eventAtUtc}
 for index,row in ipairs(schedule.reminders or {}) do
  local at=occurrence and self:ResolveTimelineAnchor(schedule,occurrence,row.start) or index
  for _,id in ipairs(row.messageIds or {}) do ranks[id]=math.min(ranks[id] or math.huge,at or index) end
 end
 local decorated={};for index,entry in ipairs(entries) do decorated[#decorated+1]={entry=entry,rank=ranks[entry.id] or math.huge,index=index} end
 table.sort(decorated,function(a,b)return a.rank==b.rank and a.index<b.index or a.rank<b.rank end)
 local result={};for _,item in ipairs(decorated) do result[#result+1]=item.entry end;return result
end
local expansion=S.RefreshEventTimingExpansion
function S:RefreshEventTimingExpansion()
 expansion(self)
 local draft=self:GetScheduleEditorDraft();local control=_G.SCM_TimelineSubmenu
 local key=self.scheduleEditor and self.scheduleEditor.key;local state=self.timelineExpansion
 local active=draft.timelineVersion==1
 if active and control and not control.disabled and (not state or not state.active or state.control~=control or state.key~=key) then
  if not control.open then control.open=true;control.animation:PlayFromStart() end
 end
 self.timelineExpansion={key=key,control=control,active=active}
end
