-- The custom planner edits private drafts. Neither selection nor preview sends chat.
SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
S.CopyPlannerValue=copy
local function snapshot(model)
    local result={messages={}}
    for _,key in ipairs({'name','guild','runAt','channel','behavior','schedule'})do result[key]=copy(model[key])end
    for _,m in ipairs(model.messages)do result.messages[m.id]={text=m.text,name=m.name,displayOrder=m.displayOrder}end
    return result
end
local function equal(a,b)
    if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
function S:IsPlannerDraftDirty(model)return not equal(snapshot(model),model.baseline)end
local function contains(list,id) for _,v in ipairs(list or {}) do if v==id then return true end end return false end
local function uniqueId(self,list)
    local base=self:GenerateUuid();local id=base;local n=1;local used={}
    for _,v in ipairs(list or {}) do used[v.id]=true end
    while used[id] do n=n+1;id=base..'-'..n end
    return id
end
function S:CreatePlannerDraft(commandId,guild)
    local settings=commandId and self:GetCommandGuildSettings(commandId,guild,false)
    local source=commandId and self:GetGuildSchedule(commandId,guild)
    local zone=self:GetGuildSchedulingTimeZone(guild)
    local p=self:GetTimeZoneParts(GetTimeStamp(),zone)
    local date=string.format('%04d-%02d-%02d',p.year,p.month,p.day)
    local command=commandId and self:GetCommandById(commandId)
    local model={commandId=commandId,guild=guild,name=command and command.name or '',source=source,
        runAt=commandId and self:GetGuildRunAt(commandId,guild) or 'ON_DEMAND',channel=commandId and self:GetSavedChatChannel(commandId,guild) or 'Guild',
        behavior=copy(settings or {}),messages={},removedMessages={},dirty=false,tab='period',
        schedule=source and copy(source) or {mode='EVENT',timelineVersion=1,enabled=true,paused=false,delivery='REPEAT',timeZone=zone,eventDate=date,eventTime='08:00 PM',recurrence='NONE',specialPattern='NONE',importantTimes={},reminders={},messageVariants={}}}
    model.channel=model.channel or 'Guild'
    if commandId then
        model.behavior.reminderMinutes=self:GetGuildReminderMinutes(commandId,guild)
        model.behavior.reminderRetryMinutes=self:GetGuildReminderRetryMinutes(commandId,guild)
        model.behavior.autoPopulateCooldownMinutes=self:GetGuildAutoPopulateCooldownMinutes(commandId,guild)
        model.behavior.autoPopulateOnZone=self:GetGuildAutoPopulateOnZone(commandId,guild)
        model.behavior.openStatusPanelOnRun=self:GetGuildOpenStatusPanelOnRun(commandId,guild)
        model.behavior.populateSound=self:GetGuildPopulateSound(commandId,guild)
    end
    if commandId then for _,entry in ipairs(self:GetMessageEntriesForCommandAndGuild(commandId,guild) or {}) do model.messages[#model.messages+1]=copy(entry) end end
    if not source then self:AddPlannerPeriod(model);model.dirty=false end
    model.periodId=(model.schedule.reminders or {})[1] and model.schedule.reminders[1].id
    model.baseline=snapshot(model)
    return model
end
function S:GetPlannerPeriod(model)
    for _,r in ipairs(model.schedule.reminders or {}) do if r.id==model.periodId then return r end end
end
function S:SelectPlannerPeriod(model,id)
    for _,r in ipairs(model.schedule.reminders or {}) do if r.id==id then model.periodId=id;return true end end
    return false
end
function S:AddPlannerPeriod(model)
    model.schedule.reminders=model.schedule.reminders or {}
    if #model.schedule.reminders>=100 then return nil,'An event supports at most 100 periods.' end
    local r={id=uniqueId(self,model.schedule.reminders),label='New period',start={kind='OFFSET',minutes=-60},finish={kind='OFFSET',minutes=0},enabled=true,intervalMinutes=30,lateMinutes=5,messageIds={}}
    model.schedule.reminders[#model.schedule.reminders+1]=r;model.periodId=r.id;model.dirty=true;return r
end
function S:RemovePlannerPeriod(model)
    if #model.schedule.reminders<=1 then return false,'Keep at least one period.' end
    for i,r in ipairs(model.schedule.reminders) do if r.id==model.periodId then table.remove(model.schedule.reminders,i);model.periodId=model.schedule.reminders[math.min(i,#model.schedule.reminders)].id;model.dirty=true;return true end end
end
function S:AddPlannerMessage(model)
    local used=copy(model.messages);for _,m in ipairs(self.savedVars.messages or {})do used[#used+1]=m end
    local m={id=uniqueId(self,used),name='Message '..tostring(#model.messages+1),text='',commandId=model.commandId,guildName=model.guild}
    model.messages[#model.messages+1]=m;model.messageId=m.id;model.dirty=true;return m
end
function S:RemovePlannerMessage(model,id)
    for i,m in ipairs(model.messages) do if m.id==id then
        table.remove(model.messages,i);model.removedMessages[id]=true
        for _,r in ipairs(model.schedule.reminders or {}) do for j=#r.messageIds,1,-1 do if r.messageIds[j]==id then table.remove(r.messageIds,j) end end end
        model.schedule.messageVariants=model.schedule.messageVariants or {};model.schedule.messageVariants[id]=nil
        model.messageId=model.messages[1] and model.messages[1].id;model.dirty=true;return true
    end end
end
function S:SetPlannerMessageSelected(model,id,enabled)
    local row=self:GetPlannerPeriod(model);if not row then return end
    row.messageIds=row.messageIds or {}
    if enabled and not contains(row.messageIds,id) then row.messageIds[#row.messageIds+1]=id end
    if not enabled then for i=#row.messageIds,1,-1 do if row.messageIds[i]==id then table.remove(row.messageIds,i) end end end
    model.dirty=true
end
function S:GetPlannerOccurrence(model)
    if model.schedule.timelineVersion~=1 then return nil,nil,'Only current Period Timeline schedules can be edited here.' end
    local c,reason=self:NormalizeSchedule(model.schedule);if not c then return nil,nil,reason end
    local list=self:GetUpcomingScheduleOccurrences(c,GetTimeStamp(),1,true)
    return list[1] or self:BuildScheduleOccurrence(c,c.eventAtUtc),c
end
function S:GetPlannerBoundary(model,key)
    local occurrence,c=self:GetPlannerOccurrence(model);local row=self:GetPlannerPeriod(model)
    if not occurrence or not row then return nil end
    local at=self:ResolveTimelineAnchor(c,occurrence,row[key]);if not at then return nil end
    local p=self:GetScheduleParts(at,c)
    return string.format('%04d-%02d-%02d',p.year,p.month,p.day),string.format('%02d:%02d %s',p.hour%12==0 and 12 or p.hour%12,p.min,p.hour>=12 and 'PM' or 'AM'),at
end
function S:SetPlannerBoundary(model,key,date,time)
    local occurrence,c,reason=self:GetPlannerOccurrence(model);local row=self:GetPlannerPeriod(model)
    if not occurrence or not row then return false,reason or 'Choose a period and valid event date/time.' end
    local at,error=self:ParseScheduleDateTime(date,time,'FIRST',c);if not at then return false,error end
    local previousStart=self:ResolveTimelineAnchor(c,occurrence,row.start)
    if key=='start' and at>occurrence.eventAtUtc and not row.allowAfterEventEnd and not (previousStart and previousStart>occurrence.eventAtUtc) and not (model.allowAfterStart or {})[row.id] then
        return false,'Enable Allow promotion after event starts before moving this period after the event.'
    end
    local p=self:GetScheduleParts(occurrence.eventAtUtc,c)
    local eventDate=string.format('%04d-%02d-%02d',p.year,p.month,p.day)
    local a=self:ParseScheduleDateTime(date,'12:00 PM','FIRST',c)
    local b=self:ParseScheduleDateTime(eventDate,'12:00 PM','FIRST',c)
    local days=math.floor((a+self:GetTimeZoneUtcOffset(a,c.timeZone)*3600-b-self:GetTimeZoneUtcOffset(b,c.timeZone)*3600)/86400+0.5)
    local previous=row[key];row[key]={kind='DAY',days=days,time=time,fold='FIRST'}
    local first,last=self:GetTimelineReminderWindow(c,occurrence,row)
    if not first or not last or last<=first then row[key]=previous;return false,'Period Stops must be after Period Starts and inside the allowed event duration.' end
    if at>occurrence.eventAtUtc and not row.allowAfterEventEnd and not (c.eventDurationMinutes and c.eventDurationMinutes>0) and not row.once then
        row[key]=previous;return false,'Set a positive event duration before promoting after the event starts.'
    end
    model.dirty=true;return true
end
function S:SortPlannerPeriods(model)
    local occurrence,c=self:GetPlannerOccurrence(model);if not occurrence then return end
    table.sort(model.schedule.reminders,function(a,b)
        local x=self:ResolveTimelineAnchor(c,occurrence,a.start) or math.huge
        local y=self:ResolveTimelineAnchor(c,occurrence,b.start) or math.huge
        if x~=y then return x<y end;return a.id<b.id
    end)
end
function S:PreviewPlannerMessage(model,id)
    local entry;for _,m in ipairs(model.messages) do if m.id==id then entry=m;break end end
    if not entry then return nil,'Choose a message.' end
    local context
    if model.runAt=='SCHEDULED' then
        local occurrence,c,reason=self:GetPlannerOccurrence(model);local row=self:GetPlannerPeriod(model)
        if not occurrence or not row then return nil,reason or 'Choose a period.' end
        local first,last=self:GetTimelineReminderWindow(c,occurrence,row)
        if not first or not last or last<=first then return nil,'The selected period is outside the event duration.' end
        context={condensedDateTime=model.behavior.condensedDateTime==true,schedule=c,occurrence=occurrence,now=first+math.floor((last-first)/2),phase=row.id,reminderId=row.id}
    end
    return self:ApplyMessageSubstitutions(entry.text,model.commandId,model.guild,context),context
end
function S:ValidatePlannerDraft(model)
    local name=self:SanitizeCommandName(model.name)
    if name=='' or #name>25 or self:IsReservedCommandName(name) then return nil,'Use a command name of 1–25 letters/numbers that is not reserved.' end
    local command=model.commandId and self:GetCommandById(model.commandId)
    if model.commandId and not command then return nil,'This command was removed in another editor. Cancel and reopen the planner.' end
    if self:CommandNameExists(name,model.commandId) then return nil,'That command name already exists.' end
    if not self:GetGuildSlotByName(model.guild) then
        if model.runAt=='ON_DEMAND' and #model.messages==0 then return 'COMMAND_ONLY' end
        return nil,'Choose an available guild.'
    end
    if model.channel~='Guild' and model.channel~='Officer' and model.channel~='Zone' and model.channel~='Group' then return nil,'Choose an output channel.' end
    if model.runAt~='SCHEDULED' and model.runAt~='STARTUP' and model.runAt~='ON_DEMAND' then return nil,'Choose a Run at type.' end
    local ids={};for _,m in ipairs(model.messages) do
        if not m.id or ids[m.id] then return nil,'Message IDs must be unique.' end;ids[m.id]=true
        if self:Trim(m.text or '')=='' then return nil,'Enter message text or remove the empty message before saving.' end
        if self:CountMessageCharacters(m.name or '')>60 then return nil,'Message names must be 60 characters or fewer.' end
    end
    if model.runAt=='SCHEDULED' then
        if model.schedule.timelineVersion~=1 then return nil,'Only current Period Timeline schedules can be edited here.' end
        local c,reason=self:NormalizeSchedule(model.schedule);if not c then return nil,reason end
        for _,row in ipairs(c.reminders) do
            for _,id in ipairs(row.messageIds) do if not ids[id] then return nil,'A period references a missing message.' end end
            if c.enabled and row.enabled~=false and not row.paused and #row.messageIds==0 then return nil,'Choose at least one message for period "'..row.label..'".' end
        end
        local occurrence=self:BuildScheduleOccurrence(c,c.eventAtUtc);local windows={}
        for _,row in ipairs(c.reminders) do if row.enabled~=false and not row.paused and not row.once then
            local a,b=self:GetTimelineReminderWindow(c,occurrence,row)
            if b and b>c.eventAtUtc and not row.allowAfterEventEnd and not (c.eventDurationMinutes and c.eventDurationMinutes>0) then return nil,'Set a positive Event duration for underway period "'..row.label..'", or finish it at the event start.' end
            if a and b and b>a then windows[#windows+1]={a=a,b=b,label=row.label} end
        end end
        table.sort(windows,function(a,b)return a.a<b.a end)
        for i=2,#windows do if windows[i].a<windows[i-1].b then return nil,'Periods overlap: '..windows[i-1].label..' and '..windows[i].label..'. Adjust their boundaries.' end end
        return c
    end
    for _,key in ipairs({'reminderMinutes','reminderRetryMinutes','autoPopulateCooldownMinutes'}) do
        local v=model.behavior[key];if v~=nil and (type(v)~='number' or v<0 or v~=math.floor(v)) then return nil,'Delivery intervals must be whole numbers, zero or positive.' end
    end
    return true
end
function S:SavePlannerDraft(model)
    local current=model.commandId and self:GetGuildSchedule(model.commandId,model.guild)
    if current~=model.source then return false,'This schedule changed in another editor. Cancel and reopen it before saving.' end
    local normalized,reason=self:ValidatePlannerDraft(model);if not normalized then return false,reason end
    local originalMessages=self.savedVars.messages
    local newCommand=not model.commandId
    if newCommand then
        local ok,error=self:AddCommand(model.name);if not ok then return false,error end
        for _,c in ipairs(self:GetCommands()) do if c.name==self:SanitizeCommandName(model.name) then model.commandId=c.id;break end end
    end
    if normalized=='COMMAND_ONLY' then
        if self:GetCommandById(model.commandId).name~=self:SanitizeCommandName(model.name) then self:RenameCommand(model.commandId,model.name) end
        model.name=self:GetCommandById(model.commandId).name;model.dirty=false;model.baseline=snapshot(model)
        return true
    end
    local replacements={};for _,m in ipairs(model.messages) do replacements[m.id]=m end
    local merged={};for _,entry in ipairs(originalMessages) do
        local staged=replacements[entry.id]
        if staged then
            local nextEntry=copy(entry);for _,field in ipairs({'text','name','displayOrder'}) do nextEntry[field]=staged[field] end
            merged[#merged+1]=nextEntry;replacements[entry.id]=nil
        elseif not model.removedMessages[entry.id] then merged[#merged+1]=entry end
    end
    for _,m in ipairs(model.messages) do if replacements[m.id] then local entry=copy(m);entry.commandId=model.commandId;entry.guildName=model.guild;entry.guildIndex=self:GetGuildSlotByName(model.guild);merged[#merged+1]=entry end end
    self.savedVars.messages=merged
    local oldChannel=self:GetSavedChatChannel(model.commandId,model.guild)
    self:SetSavedChatChannel(model.commandId,model.guild,model.channel)
    if model.runAt=='SCHEDULED' then
        for _,key in ipairs({'timelineUsage','availabilityUsage','nextDueAt','nextDuePhase','nextDueOccurrence'}) do normalized[key]=current and copy(current[key]) or normalized[key] end
        local ok,error=self:SaveGuildSchedule(model.commandId,model.guild,normalized)
        if not ok then
            self.savedVars.messages=originalMessages
            self:SetSavedChatChannel(model.commandId,model.guild,oldChannel)
            if newCommand then for i,c in ipairs(self.savedVars.commands) do if c.id==model.commandId then table.remove(self.savedVars.commands,i);break end end;model.commandId=nil;self:RegisterDynamicCommands() end
            return false,error
        end
    else
        local settings=self:GetCommandGuildSettings(model.commandId,model.guild,true)
        for _,key in ipairs({'reminderMinutes','reminderRetryMinutes','autoPopulateOnZone','autoPopulateCooldownMinutes','openStatusPanelOnRun','populateSound','disabledMessageIds'}) do settings[key]=model.behavior[key] end
        settings.runAt=model.runAt
        settings.reminderRetryMinutes=math.min(settings.reminderRetryMinutes or 0,self:GetGuildReminderRetryCapMinutes(model.commandId,model.guild))
        for _,m in ipairs(model.messages) do self:SetOrdinaryMessageEnabled(model.commandId,model.guild,m.id,not (settings.disabledMessageIds or {})[m.id]) end
        self:StopScheduledDelivery(model.commandId,model.guild)
    end
    self:SetSavedChatChannel(model.commandId,model.guild,model.channel)
    local settings=self:GetCommandGuildSettings(model.commandId,model.guild,true)
    settings.condensedDateTime=model.behavior.condensedDateTime==true
    settings.openStatusPanelOnRun=model.behavior.openStatusPanelOnRun==true
    if model.behavior.populateSound then settings.populateSound=model.behavior.populateSound end
    if self:GetCommandById(model.commandId).name~=self:SanitizeCommandName(model.name) then self:RenameCommand(model.commandId,model.name) end
    model.source=self:GetGuildSchedule(model.commandId,model.guild);model.dirty=false
    if model.source then model.schedule=copy(model.source) end
    local fresh=self:CreatePlannerDraft(model.commandId,model.guild)
    model.behavior,model.messages,model.name=fresh.behavior,fresh.messages,fresh.name
    model.baseline=snapshot(model)
    self:RegisterDynamicCommands();self:TickSchedules()
    if self.statusPanelVisible then self:RefreshStatusPanel() end
    return true
end
