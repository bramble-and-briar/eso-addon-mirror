-- Remaining native settings use the same drafts and shared addon APIs.
SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local UI=S.PlannerUI
local weekdays={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}
local function clock(n)
    n=n%1440;return string.format('%02d:%02d %s',math.floor(n/60)%12==0 and 12 or math.floor(n/60)%12,n%60,n>=720 and 'PM' or 'AM')
end
local function minutes(text,ending)
    local h,m,a=tostring(text):match('^(%d%d?):(%d%d) ([AP]M)$');h,m=tonumber(h),tonumber(m)
    if not h or h<1 or h>12 or not m or m>59 then return nil end
    local n=(h%12+(a=='PM' and 12 or 0))*60+m;return ending and n==0 and 1440 or n
end
function S:GetPlannerAvailabilityOverride(model,scope,key)
    local r=self:GetPlannerPeriod(model);local a=r and r.availability
    if not a then return nil end
    if (a[scope] or {})[key] then return a[scope][key],true end
    if scope=='dateOverrides' then
        local at=self:ParseScheduleDateTime(key,'12:00 PM','FIRST',model.schedule)
        if at then local day=self:GetScheduleParts(at,model.schedule).wday
            if (a.weekdayOverrides or {})[day] then return a.weekdayOverrides[day],false end
        end
    end
    return a,false
end
function S:SetPlannerAvailabilityOverride(model,scope,key,member,text)
    if scope~='weekdayOverrides' and scope~='dateOverrides' then return false,'Choose a valid override type.' end
    if scope=='weekdayOverrides' and (type(key)~='number' or key<1 or key>7 or key~=math.floor(key)) then return false,'Choose a weekday.' end
    if scope=='dateOverrides' and not self:ParseScheduleDateTime(key,'12:00 PM','FIRST',model.schedule) then return false,'Choose a valid override date.' end
    local n=minutes(text,member=='endMinute');if not n then return false,'Choose a valid server clock time.' end
    local r=self:GetPlannerPeriod(model);if not r then return false,'Choose a period.' end
    r.availability=r.availability or {enabled=false,startMinute=0,endMinute=1440}
    local a=r.availability;local inherited=self:GetPlannerAvailabilityOverride(model,scope,key)
    a[scope]=a[scope] or {};a[scope][key]=a[scope][key] or {startMinute=inherited.startMinute or 0,endMinute=inherited.endMinute or 1440}
    a[scope][key][member]=n;model.dirty=true;return true
end
function S:ResetPlannerAvailabilityOverride(model,scope,key)
    local r=self:GetPlannerPeriod(model);local a=r and r.availability
    if a and a[scope] then a[scope][key]=nil end;model.dirty=true;return true
end
function S:BuildPlannerAvailabilityOverrides(parent,w,y)
    local m=self.plannerModel;local r=self:GetPlannerPeriod(m);if not r or not r.availability then return y end
    UI.label(parent,'overridesTitle','Availability overrides',8,y,w-16,28,true);y=y+34
    m.overrideWeekday=m.overrideWeekday or 1
    m.overrideDate=m.overrideDate or self:GetScheduleOccurrenceDate(m.schedule,GetTimeStamp())
    local half=math.floor((w-28)/2)
    for _,scope in ipairs({'weekdayOverrides','dateOverrides'})do
        local key=scope=='weekdayOverrides' and m.overrideWeekday or m.overrideDate
        if scope=='weekdayOverrides' then
            UI.label(parent,'weekdayOverrideLabel','Override weekday',8,y,w-16,25);y=y+28
            UI.combo(parent,'overrideWeekday',weekdays,{1,2,3,4,5,6,7},key,8,y,w-16,function(v)m.overrideWeekday=v;self:RefreshEventPlanner()end)
        else
            UI.label(parent,'dateOverrideLabel','Override opening date',8,y,w-16,25);y=y+28
            UI.date(parent,'overrideDate',key,8,y,w-16,function(v)m.overrideDate=v;self:RefreshEventPlanner()end)
        end;y=y+40
        local hours,own=self:GetPlannerAvailabilityOverride(m,scope,key);hours=hours or {startMinute=0,endMinute=1440}
        UI.label(parent,scope..'Status',own and 'Modified hours for this selection' or 'Inherited hours — edit to override',8,y,w-16,25);y=y+28
        UI.label(parent,scope..'From','From',8,y,half,24);UI.label(parent,scope..'Until','Until',half+20,y,half,24);y=y+26
        local function set(member,v)local ok,error=self:SetPlannerAvailabilityOverride(m,scope,key,member,v);if ok then self:PlannerChanged();self:RefreshEventPlanner()else self:PlannerError(error)end end
        UI.clock(parent,scope..'Start',clock(hours.startMinute or 0),8,y,half,function(v)set('startMinute',v)end,m.schedule.timeZone)
        UI.clock(parent,scope..'End',clock(hours.endMinute or 1440),half+20,y,half,function(v)set('endMinute',v)end,m.schedule.timeZone);y=y+42
        UI.button(parent,scope..'Reset',scope=='weekdayOverrides' and 'Reset selected weekday hours' or 'Reset selected date hours',8,y,w-16,function()self:ResetPlannerAvailabilityOverride(m,scope,key);self:PlannerChanged();self:RefreshEventPlanner()end);y=y+44
    end
    local live=m.commandId and self:GetGuildSchedule(m.commandId,m.guild)
    local count=live and self:GetReminderAvailabilityCount(live,r,GetTimeStamp()) or 0
    UI.label(parent,'overrideHelp','Today: '..count..' counted announcements. Date overrides take priority over weekday overrides, then usual hours. Resetting hours keeps counts.',8,y,w-16,76)
    return y+84
end
function S:GetPlannerMessageGroups(model)
    local d=model.schedule
    if d.specialPattern=='MONTH_FINAL' then return {'Regular events','Month-final events','All events'},{'REGULAR','FINAL','ALL'} end
    local labels,values={'All events'},{'ALL'}
    if d.specialPattern=='FACTION_ROTATION' then
        labels[1]='All selected factions';for _,code in ipairs(d.rotationFactions or {'AD','EP','DC'})do if code~='NONE' then labels[#labels+1]=self:GetScheduleVariantLabel(code);values[#values+1]=code end end
    elseif d.specialPattern=='EVENT_ROTATION' then
        labels[1]='All activities';for _,a in ipairs(d.rotationEvents or {})do labels[#labels+1]=a.name;values[#values+1]=a.id end
    end
    return labels,values
end
function S:BuildPlannerMessageGroup(parent,key,entry,x,y,w)
    local m=self.plannerModel
    if m.runAt~='SCHEDULED' or not m.schedule.specialPattern or m.schedule.specialPattern=='NONE' then return 0 end
    local labels,values=self:GetPlannerMessageGroups(m)
    UI.combo(parent,key,labels,values,self:GetScheduleMessageVariant(m.schedule,entry.id),x,y,w,function(v)
        m.schedule.messageVariants=m.schedule.messageVariants or {};m.schedule.messageVariants[entry.id]=v;self:PlannerChanged()
    end,'Message group applies to this template in every period selecting it. Regular and Month-final separate the pools; All events works in both. Faction/activity groups follow the configured rotation.')
    return 40
end
function S:OpenPlannerGuildSettings()
    self:RequestPlannerAction(function()
        self:RefreshPlannerAfterExternalChange();local m=self.plannerModel
        local c=UI.box(self.plannerWindow,'guildSettingsDialog',0,0,680,330,true);c:ClearAnchors();c:SetAnchor(CENTER,self.plannerWindow,CENTER,0,0);c:SetDrawTier(DT_HIGH);c:SetMouseEnabled(true);UI.hide(c)
        local value=self:GetGuildSchedulingTimeZoneOverride(m.guild)
        UI.label(c,'title',m.guild..' — guild settings',22,18,636,32,true)
        UI.label(c,'label','Scheduling timezone',22,68,636,26)
        UI.combo(c,'zone',{'Use global default','Eastern (ET)','Central (CT)','Mountain (MT)','Pacific (PT)'},{'GLOBAL','ET','CT','MT','PT'},value,22,100,636,function(v)value=v end)
        UI.label(c,'help','Changing this keeps entered event dates and clock times for this guild and changes their UTC moments. Other guilds stay unchanged. Use global default follows the account timezone.',22,148,636,86)
        local errorLabel=UI.label(c,'error','',22,240,636,30)
        UI.button(c,'save','Save',22,280,306,function()
            local ok,error=self:SetGuildSchedulingTimeZone(m.guild,value);if not ok then errorLabel:SetText(error);return end
            c:SetHidden(true);self:RefreshPlannerAfterExternalChange()
        end,true)
        UI.button(c,'cancel','Cancel',348,280,310,function()c:SetHidden(true)end)
    end)
end
function S:GetPlannerLivePeriod()
    local m=self.plannerModel
    if not m or not m.commandId or m.runAt~='SCHEDULED' or self:GetGuildRunAt(m.commandId,m.guild)~='SCHEDULED' then return nil end
    local live=self:GetGuildSchedule(m.commandId,m.guild)
    if not live or not live.enabled or live.paused then return nil end
    local row=self:GetActiveTimelineReminder(live,GetTimeStamp())
    if not row then local _,limited=self:GetScheduledDailyLimitNotice(m.commandId,m.guild);row=limited end
    return row,live
end
function S:GetPlannerPeriodEligibilityText(periodId)
    local row,live=self:GetPlannerLivePeriod();if not row or row.id~=periodId then return nil end
    local m=self.plannerModel;local now=GetTimeStamp()
    if not self:IsScheduledSendingEnabled()then return 'Scheduled sending off' end
    local limit=self:GetReminderDailyLimit(live,row,now)
    if limit.reached then return (limit.shared and 'Command' or 'Period')..' daily limit reached ('..limit.count..'/'..limit.limit..')' end
    local wait=self:GetScheduleChatWaitText(m.commandId,m.guild)
    if wait and wait:find('Message ready',1,true)then return 'Message ready - press Enter' end
    local occurrence=self:GetScheduleOccurrence(live,now)
    local _,finish=self:GetTimelineReminderWindow(live,occurrence,row)
    local due=self:GetScheduledDueAt(m.commandId,m.guild,row.id)
    local pacing=self:GetSchedulePacingDelay(m.commandId,m.guild)
    due=math.max(now,due,pacing or 0)
    if due==math.huge or not finish or due>=finish then return 'No further send in this period' end
    if row.availability and row.availability.enabled then
        local windows=self:GetEffectiveReminderWindows(live,row,occurrence,due,math.min(finish,due+400*86400))
        if not windows[1]then return 'Next eligible: Waiting for allowed hours' end
        due=math.max(due,windows[1].start)
    end
    if due>now then return 'Next eligible: '..self:FormatStatusDuration(due-now),due end
    if wait then return 'Next eligible: Waiting for chat' end
    if live.delivery=='ZONE'then return 'Next eligible: On zone arrival' end
    if #self:GetScheduledMessageEntries(m.commandId,m.guild)==0 then return 'Next eligible: No messages selected' end
    return 'Next eligible: Ready now',now
end
function S:DeletePlannerCommand()
    local m=self.plannerModel;if not m.commandId then return end
    local id,guild=m.commandId,m.guild
    self:ShowPlannerConfirmation('Delete command '..m.name..'?','This removes the command and all of its messages, schedules and guild settings for ALL guilds, including this private draft. This cannot be undone.',function()
        for name in pairs(self.savedVars.commandGuildSettings[id] or {})do self:StopScheduledDelivery(id,name)end
        local ok,error=self:DeleteCommand(id);if not ok then self:PlannerError(error);return end
        local commands=self:GetCommands();self.plannerModel=self:CreatePlannerDraft(commands[1] and commands[1].id,guild);self.plannerModel.tab='event';self:RefreshEventPlanner()
    end)
end
function S:RevertPlannerMessage(model,id)
    for _,entry in ipairs(self.savedVars.messages or {})do if entry.id==id then for _,draft in ipairs(model.messages)do if draft.id==id then draft.text,draft.name=entry.text,entry.name;model.dirty=self:IsPlannerDraftDirty(model);return true end end end end
    local ok=self:RemovePlannerMessage(model,id);model.dirty=self:IsPlannerDraftDirty(model);return ok
end
function S:IsPlannerMessageDirty(entry)
    for _,saved in ipairs(self.savedVars.messages or {})do if saved.id==entry.id then return saved.text~=entry.text or (saved.name or '')~=(entry.name or '') end end
    return true
end
function S:ApplyPlannerMessage(model,id)
    if not model.commandId or not self:GetCommandById(model.commandId)then return false,'Save the new command first, then apply individual messages.' end
    local draft;for _,entry in ipairs(model.messages)do if entry.id==id then draft=entry;break end end
    if not draft then return false,'Choose a message.' end
    local text=self:Trim(draft.text or '')
    if text=='' then return false,'Message must contain text.' end
    if self:CountMessageCharacters(draft.name or '')>60 then return false,'Message names must be 60 characters or fewer.' end
    local current
    for _,entry in ipairs(self.savedVars.messages or {})do if entry.id==id then current=entry;break end end
    if current and (current.commandId~=model.commandId or not self:StringsEqualIgnoreCase(current.guildName or '',model.guild))then return false,'This message belongs to another command/guild.' end
    if not current then
        current={id=id,commandId=model.commandId,guildName=model.guild,guildIndex=self:GetGuildSlotByName(model.guild),displayOrder=draft.displayOrder}
        self.savedVars.messages[#self.savedVars.messages+1]=current
    end
    current.text,current.name=text,self:NormalizeMessageName(draft.name)
    draft.text,draft.name=current.text,current.name
    model.baseline.messages[id]={text=draft.text,name=draft.name,displayOrder=draft.displayOrder}
    model.dirty=self:IsPlannerDraftDirty(model)
    return true
end
function S:PreviewPlannerTimeline()
    local m=self.plannerModel;local occurrence,c,error=self:GetPlannerOccurrence(m)
    if not occurrence then self:PlannerError(error);return end
    self:AddLocalChatMessage('[SmartChatMsg] Event: '..self:FormatScheduleDateTime(occurrence.eventAtUtc,c))
    for _,r in ipairs(c.reminders)do
        local a,b=self:GetTimelineReminderWindow(c,occurrence,r)
        self:AddLocalChatMessage(r.label..': '..(a and self:FormatScheduleDateTime(a,c) or 'Unavailable')..(b and ' - '..self:FormatScheduleDateTime(b,c) or '')..' - '..(r.once and 'Send once' or 'Every '..self:FormatSchedulingMinutes(r.intervalMinutes)))
    end
end
