SmartChatMsg = SmartChatMsg or {}

-- Local scheduled notices identify the guild before the command label.
function SmartChatMsg:GetScheduledNoticeLabel(commandId,guildName)
    local commandName=self:GetSlashCommandDisplayName(commandId):gsub("^/", "")
    return guildName.." ("..commandName..")"
end

-- Session-only pacing; saved event dates and per-command cooldowns stay intact.
function SmartChatMsg:GetSchedulePacingDelay(commandId,guildName)
    local now=GetTimeStamp()
    if self.scheduleStartupEndsAt and now<self.scheduleStartupEndsAt then
        return self.scheduleStartupEndsAt,"Startup delay until "..self:FormatScheduleDateTime(self.scheduleStartupEndsAt,self:GetGuildSchedule(commandId,guildName))
    end
    local pause=self.scheduledSendPause
    if pause and now<pause.endsAt and pause.senderKey~=self:GetReminderStateKey(commandId,guildName) then
        return pause.endsAt,"5-minute pause after another scheduled message until "..self:FormatScheduleDateTime(pause.endsAt,self:GetGuildSchedule(commandId,guildName))
    end
end

function SmartChatMsg:HandleScheduledSendConfirmed(metadata)
    if not metadata or not metadata.scheduledDelivery then return end
    if metadata.autoPopulate then self:ScheduleNextScheduledDelivery(metadata.commandId,metadata.guildName) end
    local schedule=self:GetGuildSchedule(metadata.commandId,metadata.guildName)
    if schedule and (schedule.mode=="REMINDER" or (schedule.phaseOnce or {})[metadata.scheduledPhase]) and metadata.scheduledOccurrence then
        schedule.completedOccurrences={[metadata.scheduledOccurrence..":"..metadata.scheduledPhase]=true}
    end
    self.scheduledSendPause={senderKey=self:GetReminderStateKey(metadata.commandId,metadata.guildName),endsAt=GetTimeStamp()+300}
    self:ShowStatusMessage(self:GetScheduledNoticeLabel(metadata.commandId,metadata.guildName)
        ..": Scheduled message sent. Other schedules pause for 5 minutes, until "..self:FormatScheduleDateTime(self.scheduledSendPause.endsAt,self:GetGuildSchedule(metadata.commandId,metadata.guildName))..".")
end

function SmartChatMsg:GetChatEditControl()
    local chat=CHAT_SYSTEM
    if not chat then return nil end
    if chat.GetEditControl then
        local edit=chat:GetEditControl(); if edit then return edit end
    end
    local entry=chat.textEntry
    if entry then
        if entry.GetEditControl then
            local edit=entry:GetEditControl(); if edit then return edit end
        end
        if entry.editControl or entry.EditControl then return entry.editControl or entry.EditControl end
    end
    return ZO_ChatWindowTextEntryEditBox
end

function SmartChatMsg:IsChatPopulationBusy()
    if self:IsExecutionBusy() then return true end
    local edit=self:GetChatEditControl()
    return not edit or not edit.GetText or edit:GetText()~=""
end

function SmartChatMsg:CancelQueuedChatPopulation(commandId,guildName)
    local key=self:GetReminderStateKey(commandId,guildName)
    local queued=self.chatPopulationQueue and self.chatPopulationQueue[key]
    if self.chatPopulationQueue then self.chatPopulationQueue[key]=nil end
    if queued and queued.metadata.startupQueue then self:FinalizeStartupQueueCurrent(true,"queued startup canceled") end
end

function SmartChatMsg:QueueChatPopulation(commandId,guildName,channelOverride,metadata,priority)
    self.chatPopulationQueue=self.chatPopulationQueue or {}
    local key=self:GetReminderStateKey(commandId,guildName)
    if not key then return false,"Invalid command/guild." end
    local old=self.chatPopulationQueue[key]
    if old and old.priority<=priority then return true end
    if old and old.metadata.startupQueue and not (metadata and metadata.startupQueue) then
        self:FinalizeStartupQueueCurrent(true,"queued startup replaced by manual request")
    end
    self.chatPopulationSequence=(self.chatPopulationSequence or 0)+1
    self.chatPopulationQueue[key]={commandId=commandId,guildName=guildName,channelOverride=channelOverride,
        metadata=metadata or {},priority=priority,sequence=self.chatPopulationSequence,queuedAt=GetTimeStamp(),
        runAt=self:GetGuildRunAt(commandId,guildName),schedule=self:GetGuildSchedule(commandId,guildName)}
    return true
end

function SmartChatMsg:ProcessChatPopulationQueue()
    if self:IsChatPopulationBusy() then return end
    local ordered={}
    for key,request in pairs(self.chatPopulationQueue or {}) do request.key=key; ordered[#ordered+1]=request end
    table.sort(ordered,function(a,b)
        if a.priority~=b.priority then return a.priority<b.priority end
        if (a.queuedAt or 0)~=(b.queuedAt or 0) then return (a.queuedAt or 0)<(b.queuedAt or 0) end
        return a.sequence<b.sequence
    end)
    -- Choose anew among equal automatic priorities when delivery is available.
    -- Stable input order prevents the collection shuffle from canceling this shuffle.
    local first=1
    while first<=#ordered do
        local last=first
        while last<#ordered and ordered[last+1].priority==ordered[first].priority and ordered[last+1].queuedAt==ordered[first].queuedAt do last=last+1 end
        if ordered[first].priority==0 or ordered[first].priority>=3 then
            local group={}
            for index=first,last do group[#group+1]=ordered[index] end
            table.sort(group,function(a,b) return a.key<b.key end)
            for index=#group,2,-1 do local other=zo_random(1,index);group[index],group[other]=group[other],group[index] end
            for index=first,last do ordered[index]=group[index-first+1] end
        end
        first=last+1
    end
    for _,request in ipairs(ordered) do
        self.chatPopulationQueue[request.key]=nil
        local state,phase=self:GetGuildScheduleState(request.commandId,request.guildName)
        local valid=self:GetCommandById(request.commandId) and self:GetGuildSlotByName(request.guildName)
            and self:GetGuildRunAt(request.commandId,request.guildName)==request.runAt
        if request.metadata.scheduledDelivery then
            valid=valid and self:IsScheduledSendingEnabled() and state=="RUNNING" and phase==request.metadata.scheduledPhase
                and self:GetGuildSchedule(request.commandId,request.guildName)==request.schedule
                and (not request.metadata.scheduledOccurrence or (self:GetScheduleOccurrence(request.schedule,GetTimeStamp()) or {}).occurrenceKey==request.metadata.scheduledOccurrence)
            if valid and request.schedule.delivery=="ZONE" then
                local zone=self:GetEffectiveAutoPopulateZoneId(self:GetPlayerZoneId())
                valid=zone and zone==request.metadata.zoneId
                    and (request.metadata.manualScheduled or not self:ShouldSkipAutoPopulateForZone(request.commandId,request.guildName,zone))
            elseif valid and not request.metadata.manualScheduled then
                valid=GetTimeStamp()>=self:GetScheduledDueAt(request.commandId,request.guildName,phase)
            end
        end
        if valid and request.metadata.reminderRepeat then
            valid=self:IsReminderAutomationActive(request.commandId,request.guildName)
                and self:GetGuildLastUsedAt(request.commandId,request.guildName)==request.metadata.lastUsedAt
        elseif valid and request.metadata.autoPopulate and not request.metadata.scheduledDelivery then
            local active=self:GetActiveAutoPopulate()
            local zone=self:GetEffectiveAutoPopulateZoneId(self:GetPlayerZoneId())
            valid=active and active.commandId==request.commandId
                and self:StringsEqualIgnoreCase(active.guildName,request.guildName)
                and zone and zone==request.metadata.zoneId
                and not self:ShouldSkipAutoPopulateForZone(request.commandId,request.guildName,zone)
        end
        if valid and request.metadata.scheduledDelivery and self:GetSchedulePacingDelay(request.commandId,request.guildName) then
            self.chatPopulationQueue[request.key]=request
        elseif valid and request.metadata.observedDueAt and GetTimeStamp()<request.metadata.observedDueAt then
            self.chatPopulationQueue[request.key]=request
        elseif valid then
            request.metadata.queuedDelivery=true
            local ok=self:PopulateChatBufferForCommand(request.commandId,request.guildName,request.channelOverride,request.metadata)
            if ok and self.pendingRestoreState and request.metadata.scheduledDelivery then
                self:ShowStatusMessage(self:GetScheduledNoticeLabel(request.commandId,request.guildName)
                    ..": Scheduled message ready in chat. Press Enter to send (chat timeout: "..tostring(self.pendingRestoreState.timeoutSeconds).." seconds).")
            end
            if ok and self.pendingRestoreState then return end
        end
        local startup=self.startupQueueCurrent
        if not self.chatPopulationQueue[request.key] and request.metadata.startupQueue and startup and startup.commandId==request.commandId
            and self:StringsEqualIgnoreCase(startup.guildName,request.guildName) then
            self:FinalizeStartupQueueCurrent(true,"queued startup no longer deliverable")
        end
    end
end

function SmartChatMsg:WithdrawScheduledPending(commandId,guildName)
    local state=self.pendingRestoreState
    local metadata=state and state.metadata
    if not metadata or not metadata.scheduledDelivery or metadata.commandId~=commandId
        or not self:StringsEqualIgnoreCase(metadata.guildName or "",guildName) then return end
    local edit=self:GetChatEditControl()
    if edit and edit.GetText and edit:GetText()==state.rawExpectedText then
        self:ClearPendingChatBuffer(); self:RestoreChatChannel(state.previousChannel)
    end
    self:ClearPendingRestoreState("scheduled window/phase stopped")
end

function SmartChatMsg:StopScheduledDelivery(commandId,guildName)
    self:CancelQueuedChatPopulation(commandId,guildName)
    self:WithdrawScheduledPending(commandId,guildName)
    self:ClearCommandReminder(commandId,guildName)
    self:SetReminderAutomationActive(commandId,guildName,false)
    local active=self:GetActiveAutoPopulate()
    if active and active.scheduledOwner and active.commandId==commandId
        and self:StringsEqualIgnoreCase(active.guildName,guildName) then self:ClearActiveAutoPopulate() end
    local key=self:GetReminderStateKey(commandId,guildName)
    if self.scheduleRuntime then self.scheduleRuntime[key]=nil end
end

function SmartChatMsg:PauseGuildSchedule(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if not schedule then return false,"Schedule not configured." end
    schedule.paused=true; self:StopScheduledDelivery(commandId,guildName)
    return true
end

function SmartChatMsg:ResumeGuildSchedule(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if not schedule then return false,"Schedule not configured." end
    schedule.paused=false; self:TickSchedules()
    return true
end

-- Cooldowns belong to the phase in which the announcement was observed or
-- sent. Derive the boundary from the calendar so reloading in a new phase
-- also ignores old cooldowns without deleting accurate usage history.
function SmartChatMsg:GetScheduledCooldownStart(commandId,guildName)
    if self:GetGuildRunAt(commandId,guildName)~="SCHEDULED" then return nil end
    local config=self:GetGuildSchedule(commandId,guildName)
    if not config or config.mode~="EVENT" then return nil end
    local occurrence=self:GetScheduleOccurrence(config,GetTimeStamp())
    if not occurrence then return nil end
    local phase=self:GetSchedulePhase(config,GetTimeStamp())
    if phase=="LIVE" then return occurrence.eventAtUtc end
    if phase=="SOON" then return math.max(occurrence.startsAtUtc,occurrence.eventAtUtc-config.startingSoonMinutes*60) end
    if phase=="DAY" then
        local p=self:GetScheduleParts(occurrence.eventAtUtc,config)
        local midnight=self:ParseScheduleDateTime(string.format("%04d-%02d-%02d",p.year,p.month,p.day),"12:00 AM",nil,config)
        return math.max(occurrence.startsAtUtc,midnight)
    end
    return occurrence.startsAtUtc
end

function SmartChatMsg:GetScheduledPeerDelay(commandId,guildName,lastUsedAt)
    local settings=self:GetCommandGuildSettings(commandId,guildName,false)
    local delay=0
    for _,usage in pairs(settings and settings.observedChatCooldowns or {}) do
        if usage.at==lastUsedAt then delay=math.max(delay,usage.delaySeconds) end
    end
    return delay
end

function SmartChatMsg:GetScheduledDueAt(commandId,guildName,phase)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
    if not occurrence then return math.huge end
    local phaseStart=self:GetScheduledCooldownStart(commandId,guildName) or occurrence.startsAtUtc
    local observed=self:GetObservedCommandCooldownEndsAt(commandId,guildName,self:GetSavedChatChannel(commandId,guildName))
    local function deadline(value) return observed and math.max(value,observed) or value end
    local once=schedule.mode=="REMINDER" or (schedule.phaseOnce or {})[phase]
    local token=occurrence.occurrenceKey..":"..phase
    if once and (schedule.completedOccurrences or {})[token] then return math.huge end
    local lastUsedAt=self:GetGuildLastUsedAt(commandId,guildName)
    if once and lastUsedAt and lastUsedAt>=phaseStart then return math.huge end
    local peerDelay=lastUsedAt and self:GetScheduledPeerDelay(commandId,guildName,lastUsedAt) or 0
    if schedule.nextDueAt and schedule.nextDuePhase==phase and (not schedule.nextDueOccurrence and (schedule.recurrence or "NONE")=="NONE" or schedule.nextDueOccurrence==occurrence.occurrenceKey) then
        if peerDelay>0 and lastUsedAt>=phaseStart then
            return deadline(math.max(schedule.nextDueAt,lastUsedAt+self:GetScheduleIntervalMinutes(commandId,guildName)*60+peerDelay))
        end
        return deadline(schedule.nextDueAt)
    end
    if lastUsedAt and lastUsedAt>=phaseStart then
        return deadline(lastUsedAt+self:GetScheduleIntervalMinutes(commandId,guildName)*60+peerDelay)
    end
    return deadline(phaseStart)
end

function SmartChatMsg:ScheduleNextScheduledDelivery(commandId,guildName,extraDelaySeconds)
    if self:GetGuildScheduleState(commandId,guildName)~="RUNNING" then return end
    local schedule=self:GetGuildSchedule(commandId,guildName)
    schedule.nextDueAt=GetTimeStamp()+self:GetScheduleIntervalMinutes(commandId,guildName)*60+(extraDelaySeconds or 0)
    schedule.nextDuePhase=self:GetSchedulePhase(schedule,GetTimeStamp())
    local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
    schedule.nextDueOccurrence=occurrence and occurrence.occurrenceKey
    self:SetReminderAutomationActive(commandId,guildName,schedule.delivery=="REPEAT")
end

function SmartChatMsg:RequestScheduledDelivery(commandId,guildName,manual)
    if not self:IsScheduledSendingEnabled() then return false,"Scheduled sending is OFF. Use /scm on to resume." end
    local state,phase=self:GetGuildScheduleState(commandId,guildName)
    if state~="RUNNING" then return false,"Schedule is "..state:lower().."." end
    local pacingEndsAt,pacingReason=self:GetSchedulePacingDelay(commandId,guildName)
    if pacingEndsAt then return false,pacingReason end
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if #self:GetScheduledMessageEntries(commandId,guildName)==0 then return false,"No message for this phase." end
    if manual then
        local observed=self:GetObservedCommandCooldownEndsAt(commandId,guildName,self:GetSavedChatChannel(commandId,guildName))
        if observed and GetTimeStamp()<observed then return false,"A matching announcement from another player is still on cooldown." end
    end
    local zoneId
    if schedule.delivery=="ZONE" then
        zoneId=self:GetEffectiveAutoPopulateZoneId(self:GetPlayerZoneId())
        if not zoneId then return false,"Current zone is not eligible." end
        if not manual and self:ShouldSkipAutoPopulateForZone(commandId,guildName,zoneId) then
            self:NotifyCooldownDelay(commandId,guildName,self:GetAutoPopulateCooldownEndsAt(commandId,guildName,zoneId))
            return false,"Zone cooldown."
        end
    elseif not manual and GetTimeStamp()<self:GetScheduledDueAt(commandId,guildName,phase) then
        self:NotifyCooldownDelay(commandId,guildName,self:GetObservedCommandCooldownEndsAt(commandId,guildName,self:GetSavedChatChannel(commandId,guildName)))
        return false,"Repeat cooldown."
    end
    local pending=self.pendingRestoreState and self.pendingRestoreState.metadata
    if pending and pending.commandId==commandId and self:StringsEqualIgnoreCase(pending.guildName or "",guildName) then return true end
    return self:QueueChatPopulation(commandId,guildName,nil,{scheduledDelivery=true,manualScheduled=manual==true,scheduledPhase=phase,scheduledOccurrence=(self:GetScheduleOccurrence(schedule,GetTimeStamp()) or {}).occurrenceKey,
        autoPopulate=schedule.delivery=="ZONE",zoneId=zoneId,commandId=commandId,guildName=guildName,
        guildIndex=self:GetGuildSlotByName(guildName),paramText=tostring(self:GetGuildSlotByName(guildName))},manual and 1 or 3)
end

function SmartChatMsg:HandleScheduledPopulateTimeout(metadata)
    if self:GetGuildScheduleState(metadata.commandId,metadata.guildName)~="RUNNING" then return end
    local schedule=self:GetGuildSchedule(metadata.commandId,metadata.guildName)
    local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
    if metadata.scheduledOccurrence and metadata.scheduledOccurrence~=occurrence.occurrenceKey then return end
    if metadata.scheduledPhase and metadata.scheduledPhase~=self:GetSchedulePhase(schedule,GetTimeStamp()) then return end
    local retry=self:GetGuildEffectiveReminderRetryMinutes(metadata.commandId,metadata.guildName)
    schedule.nextDueAt=GetTimeStamp()+(retry>0 and retry or self:GetScheduleIntervalMinutes(metadata.commandId,metadata.guildName))*60
    schedule.nextDuePhase=self:GetSchedulePhase(schedule,GetTimeStamp())
    local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
    schedule.nextDueOccurrence=occurrence and occurrence.occurrenceKey
    if schedule.timelineVersion==1 then
        local row=self:GetActiveTimelineReminder(schedule,GetTimeStamp())
        if row then
            if row.timeSensitive and retry<=0 then schedule.nextDueAt=GetTimeStamp()+60 end
            local key=occurrence.occurrenceKey..":"..row.id
            schedule.timelineUsage=schedule.timelineUsage or {}
            local usage=schedule.timelineUsage[key] or {};schedule.timelineUsage[key]=usage
            usage.nextDueAt=schedule.nextDueAt
        end
    end
    local runtime=self.scheduleRuntime and self.scheduleRuntime[self:GetReminderStateKey(metadata.commandId,metadata.guildName)]
    self:ShowStatusMessage(self:GetScheduledNoticeLabel(metadata.commandId,metadata.guildName)
        ..": Scheduled message was not sent before the chat timeout. Next attempt: "..self:FormatScheduleDateTime(schedule.nextDueAt,schedule)..".")
    if runtime and schedule.delivery=="ZONE" then runtime.zonePending=retry>0 end
end

-- These notices use the local addon notification path, never an outgoing chat channel.
-- Explicit testing action. Preserve templates, dates, pause state and rotation counts.
function SmartChatMsg:ResetAllCooldowns()
    local repeats={}
    for _,command in ipairs(self:GetCommands() or {}) do
        command.lastUsedAt=nil
        for guild,settings in pairs((self.savedVars.commandGuildSettings or {})[command.id] or {}) do
            local active=self:IsReminderAutomationActive(command.id,guild)
            self:CancelQueuedChatPopulation(command.id,guild)
            self:WithdrawObservedChatDuplicate(command.id,guild)
            self:ClearCommandReminder(command.id,guild)
            settings.lastUsedAt=nil
            settings.lastAutoPopulateSentAtByZone={}
            settings.observedChatCooldowns={}
            local schedule=settings.schedule
            if schedule then
                schedule.nextDueAt=nil;schedule.nextDuePhase=nil;schedule.nextDueOccurrence=nil
                schedule.completedOccurrences={}
                schedule.timelineUsage={}
                schedule.availabilityUsage={}
            end
            if active and settings.runAt~="SCHEDULED" then repeats[#repeats+1]={command.id,guild} end
        end
    end
    self.scheduledSendPause=nil
    self.cooldownNoticeDeadlines={}
    for _,runtime in pairs(self.scheduleRuntime or {}) do runtime.zonePending=true end
    self:ShowStatusMessage("SmartChatMsg cooldowns reset for testing. Schedule dates and On/Paused/Off states are unchanged; the startup delay still applies.")
    for _,item in ipairs(repeats) do self:TriggerReminderPopulate(item[1],item[2],nil,"cooldown reset") end
    self:TickSchedules()
    local auto=self:GetActiveAutoPopulate()
    if auto and self:GetGuildRunAt(auto.commandId,auto.guildName)~="SCHEDULED" then self:HandleZoneAutoPopulate() end
    if self.statusPanelVisible then self:RefreshStatusPanel() end
end

function SmartChatMsg:GetSchedulePhaseDescription(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    local phase=self:GetSchedulePhase(schedule,GetTimeStamp())
    local labels={BEFORE="Before event day",DAY="On event day",SOON="Starting soon",LIVE="After event starts"}
    local label=schedule.mode=="EVENT" and labels[phase] or "Scheduled window"
    local frequency
    if schedule.delivery=="ZONE" then frequency="on zone arrival"
    elseif schedule.mode=="REMINDER" or (schedule.phaseOnce or {})[phase] then frequency="one announcement"
    else frequency="every "..tostring(self:GetScheduleIntervalMinutes(commandId,guildName)).." minutes" end
    return (label or phase or "Scheduled window").." ("..frequency..")",phase
end

function SmartChatMsg:NotifyScheduleTransition(commandId,guildName,state)
    self.scheduleNoticeStates=self.scheduleNoticeStates or {}
    local key=self:GetReminderStateKey(commandId,guildName)
    local config=self:GetGuildSchedule(commandId,guildName)
    local previous=self.scheduleNoticeStates[key]
    if previous and previous.config~=config then previous=nil end
    local occurrence=config and self:GetScheduleOccurrence(config,GetTimeStamp())
    local description,phase
    if state=="RUNNING" then description,phase=self:GetSchedulePhaseDescription(commandId,guildName) end
    local prefix=self:GetScheduledNoticeLabel(commandId,guildName)..": "
    if previous and previous.occurrence and not previous.ended and GetTimeStamp()>=previous.occurrence.endsAtUtc then
        self:ShowStatusMessage(prefix.."Schedule ended at "..self:FormatScheduleDateTime(previous.occurrence.endsAtUtc,previous.occurrence)..".")
        previous.ended=true
    end
    if state=="RUNNING" and occurrence and (not previous or previous.state~="RUNNING" or previous.occurrence.occurrenceKey~=occurrence.occurrenceKey) then
        self:ShowStatusMessage(prefix.."Schedule "..(previous and previous.state=="PAUSED" and "resumed" or "started").."; "..description.."; active until "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)..".")
        self:OpenStatusPanelOnRunIfConfigured(commandId,guildName)
        previous={config=config,occurrence=occurrence,ended=false}
    elseif state=="RUNNING" and previous and previous.description~=description then
        self:ShowStatusMessage(prefix.."Schedule changed to "..description.."; active until "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)..".")
    elseif state=="PAUSED" and previous and previous.state=="RUNNING" then
        self:ShowStatusMessage(prefix.."Schedule paused.")
    end
    previous=previous or {config=config}
    previous.state=state
    previous.phase,previous.description=phase,description
    self.scheduleNoticeStates[key]=previous
end

function SmartChatMsg:NotifyCooldownDelay(commandId,guildName,endsAt)
    if not endsAt or endsAt==math.huge or endsAt<=GetTimeStamp() then return end
    self.cooldownNoticeDeadlines=self.cooldownNoticeDeadlines or {}
    local key=self:GetReminderStateKey(commandId,guildName)
    if self.cooldownNoticeDeadlines[key]==endsAt then return end
    self.cooldownNoticeDeadlines[key]=endsAt
    local prefix=self:GetSlashCommandDisplayName(commandId).." / "..guildName..": message"
    if self:GetGuildRunAt(commandId,guildName)=="SCHEDULED" then
        prefix=self:GetScheduledNoticeLabel(commandId,guildName)..": Message"
    end
    self:ShowStatusMessage(prefix.." delayed by cooldown until "..self:FormatScheduleDateTime(endsAt,self:GetGuildSchedule(commandId,guildName))..".")
end

function SmartChatMsg:TickSchedules()
    if not self.savedVars or self.schedulerTicking then return end
    self.schedulerTicking=true
    self.scheduleRuntime=self.scheduleRuntime or {}
    local combinations={}
    for commandId,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do
        for guildKey,settings in pairs(byGuild) do
            if settings.runAt=="SCHEDULED" then
                combinations[#combinations+1]={commandId=commandId,guildName=guildKey,key=self:GetReminderStateKey(commandId,guildKey)}
            end
        end
    end
    table.sort(combinations,function(a,b) return a.key<b.key end)
    -- Shuffle once as each batch enters the queue. Queue sequence then preserves
    -- that order across ticks, chat drafts, and the pause between schedules.
    for i=#combinations,2,-1 do
        local j=zo_random(1,i)
        combinations[i],combinations[j]=combinations[j],combinations[i]
    end
    local seen={}
    for _,combination in ipairs(combinations) do
        local id,guild,key=combination.commandId,combination.guildName,combination.key
        -- Resolve canonical local guild name (saved keys are normalized).
        local slot=self:GetGuildSlotByName(guild)
        guild=slot and self:GetGuildNameByIndex(slot) or guild
        seen[key]=true
        local state,phase=self:GetGuildScheduleState(id,guild)
        if slot and self:GetCommandById(id) then self:NotifyScheduleTransition(id,guild,state) end
        if not self:IsScheduledSendingEnabled() or state~="RUNNING" or not slot or not self:GetCommandById(id) then
            self:StopScheduledDelivery(id,guild)
        else
            local schedule=self:GetGuildSchedule(id,guild)
            local runtime=self.scheduleRuntime[key]
            if not runtime then runtime={commandId=id,guildName=guild,zonePending=true}; self.scheduleRuntime[key]=runtime end
            local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
            if schedule.nextDuePhase and (schedule.nextDuePhase~=phase or schedule.nextDueOccurrence and schedule.nextDueOccurrence~=occurrence.occurrenceKey) then
                schedule.nextDueAt,schedule.nextDuePhase,schedule.nextDueOccurrence=nil,nil,nil
            end
            if runtime.phase and (runtime.phase~=phase or runtime.occurrenceKey~=occurrence.occurrenceKey) then
                self:WithdrawScheduledPending(id,guild); self:CancelQueuedChatPopulation(id,guild); runtime.zonePending=true
            end
            runtime.phase,runtime.reason,runtime.occurrenceKey=phase,nil,occurrence.occurrenceKey
            local eligible=self:GetScheduledMessageEntries(id,guild)
            local pending=self.pendingRestoreState and self.pendingRestoreState.metadata
            if pending and pending.scheduledDelivery and pending.commandId==id and self:StringsEqualIgnoreCase(pending.guildName,guild) then
                local found=false; for _,entry in ipairs(eligible) do if entry.id==pending.selectedEntryId then found=true end end
                if not found then self:WithdrawScheduledPending(id,guild) end
            end
            if #eligible==0 then
                runtime.reason="No message for this phase"
                self:WithdrawScheduledPending(id,guild)
                self:CancelQueuedChatPopulation(id,guild)
                self:SetReminderAutomationActive(id,guild,false)
            elseif schedule.delivery=="ZONE" then
                local active=self:GetActiveAutoPopulate()
                if active and (active.commandId~=id or not self:StringsEqualIgnoreCase(active.guildName,guild)) then
                    runtime.reason="Waiting for active Zone command"
                else
                    if not active then self:SetActiveAutoPopulate(id,guild); active=self:GetActiveAutoPopulate() end
                    if active then active.scheduledOwner=true end
                    local zone=self:GetPlayerZoneId()
                    if runtime.zoneId~=zone then
                        self:CancelQueuedChatPopulation(id,guild)
                        runtime.zoneId,runtime.zonePending=zone,true
                    end
                    if runtime.zonePending and (not schedule.nextDueAt or GetTimeStamp()>=schedule.nextDueAt) then
                        local ok,reason=self:RequestScheduledDelivery(id,guild)
                        if not ok then runtime.reason=reason end
                    end
                end
            else
                self:SetReminderAutomationActive(id,guild,true)
                local ok,reason=self:RequestScheduledDelivery(id,guild)
                if not ok then runtime.reason=reason end
            end
        end
    end
    for key,runtime in pairs(self.scheduleRuntime) do
        if not seen[key] then self:StopScheduledDelivery(runtime.commandId,runtime.guildName) end
    end
    self:ProcessChatPopulationQueue()
    self.schedulerTicking=false
end

function SmartChatMsg:InitializeScheduler()
    self.scheduleRuntime,self.chatPopulationQueue={},{}
    self.scheduleStartupEndsAt=GetTimeStamp()+180
    self.scheduledSendPause=nil
    self.scheduleNoticeStates,self.cooldownNoticeDeadlines={},{}
    self:ShowStatusMessage("SmartChatMsg is running. Scheduled messages wait 3 minutes, until "..self:FormatScheduleDateTime(self.scheduleStartupEndsAt)..".")
    if not self:IsScheduledSendingEnabled() then self:AddLocalChatMessage('[SmartChatMsg] Scheduled sending is OFF (saved preference). Use /scm on to enable scheduled announcements. Incoming monitoring and ordinary commands remain active.') end
    local active=self:GetActiveAutoPopulate()
    if active and self:GetGuildRunAt(active.commandId,active.guildName)=="SCHEDULED" then active.scheduledOwner=true end
    EVENT_MANAGER:RegisterForUpdate(self.name.."_Scheduler",1000,function() SmartChatMsg:TickSchedules() end)
    self:TickSchedules()
end

function SmartChatMsg:GetScheduleSummaryText()
    local lines={}
    for id,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do
        for guild,settings in pairs(byGuild) do
            if settings.runAt=="SCHEDULED" then
                lines[#lines+1]=(self:GetSlashCommandDisplayName(id) or id).." / "..guild..": "..self:GetScheduleStatusText(id,guild)
            end
        end
    end
    table.sort(lines)
    return table.concat(lines,"\n")
end

-- Describe who owns the chat text without treating our prepared message as user input.
function SmartChatMsg:GetScheduleChatWaitText(commandId,guildName)
    local pending=self.pendingRestoreState
    local metadata=pending and pending.metadata
    local edit=self:GetChatEditControl()
    if not edit or not edit.GetText then return "Chat input unavailable" end
    if metadata and metadata.commandId==commandId and self:StringsEqualIgnoreCase(metadata.guildName or "",guildName) then
        if edit:GetText()==pending.rawExpectedText then return "Message ready — press Enter" end
        return "Waiting for your chat — your edits are protected"
    end
    if edit:GetText()~="" then return "Waiting for your chat — your text is protected" end
    if self:IsExecutionBusy() then return "Waiting for another command" end
end

function SmartChatMsg:GetScheduleStatusText(commandId,guildName)
    local state,phase=self:GetGuildScheduleState(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    local labels={RUNNING="Active",WAITING="Scheduled — waiting",PAUSED="Paused",FINISHED="Finished",DISABLED="Disabled",UNCONFIGURED="No schedule saved yet. Configure the schedule below, then click Save and activate.",ON_DEMAND="Scheduling is not active for this command."}
    local phaseNames={BEFORE="Before event day",DAY="On event day",SOON="Starting soon",LIVE="After event starts"}
    local text=(labels[state] or state)..(phaseNames[phase] and " / "..phaseNames[phase] or "")
    local runtime=self.scheduleRuntime and self.scheduleRuntime[self:GetReminderStateKey(commandId,guildName)]
    local pacingEndsAt,pacingReason
    if state=="RUNNING" then pacingEndsAt,pacingReason=self:GetSchedulePacingDelay(commandId,guildName) end
    if pacingReason then text=text.." — "..pacingReason
    elseif runtime and runtime.reason then text=text.." — "..runtime.reason end
    if state=="RUNNING" then
        local wait=self:GetScheduleChatWaitText(commandId,guildName)
        if wait then text=text.." — "..wait end
    end
    if schedule then
        local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp()) or schedule
        text=text.."\n"..self:FormatScheduleDateTime(occurrence.startsAtUtc,occurrence).." → "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)
        if phase and schedule.delivery=="REPEAT" then
            local due=self:GetScheduledDueAt(commandId,guildName,phase)
            if pacingEndsAt then due=math.max(due,pacingEndsAt) end
            text=text..(due<occurrence.endsAtUtc and "\nNext eligible: "..self:FormatScheduleDateTime(math.max(due,GetTimeStamp()),schedule) or "\nNo further delivery before window end")
        end
    end
    return text
end

-- Offsets are elapsed durations relative to the same scheduled occurrence.
-- Restrict their grammar so malformed tokens remain literal text.
function SmartChatMsg:ParseScheduledEventToken(token)
    token=zo_strlower(tostring(token or ""))
    local valid={eventdate=true,eventtime=true,eventwhen=true,eventfaction=true,eventactivity=true,eventcountdown=true}
    if valid[token] then return token,0 end
    local named,mark=token:match("^(event%a+):([%a][%w_]*)$")
    if valid[named] and named~="eventfaction" and named~="eventactivity" then return named,0,mark end
    local kind,sign,amount,unit=token:match("^(event%a+)([+%-])(%d+)([mhd])$")
    if kind~="eventtime" and kind~="eventcountdown" and kind~="eventwhen" and kind~="eventdate" then return nil end
    amount=tonumber(amount)
    local seconds=amount*({m=60,h=3600,d=86400})[unit]
    if seconds>36500*86400 then return nil end
    return kind,sign=="-" and -seconds or seconds
end

function SmartChatMsg:HasExplicitEventCountdown(text)
    for token in tostring(text or ""):gmatch("%%([%a][%w_:+%-]*)%%") do
        if self:ParseScheduledEventToken(token)=="eventcountdown" then return true end
    end
    return false
end

function SmartChatMsg:GetScheduledEventTokenValue(token,commandId,guildName,context)
    local kind,offset,mark=self:ParseScheduledEventToken(token)
    if not kind then return nil end
    token=kind
    local schedule=context and context.schedule or self:GetGuildSchedule(commandId,guildName)
    if not schedule then return nil end
    if mark then local important=(schedule.importantTimes or {})[mark];if not important then return nil end;offset=important.offsetMinutes*60 end
    local now=context and context.now or GetTimeStamp()
    local occurrence=context and context.occurrence or self:GetScheduleOccurrence(schedule,now)
    if token=="eventactivity" then return occurrence and self:GetScheduleActivityName(schedule,occurrence.eventAtUtc) end
    if token=="eventfaction" then
        return occurrence and self:GetScheduleFactionName(schedule,occurrence.eventAtUtc)
    end
    local condensed=context and context.condensedDateTime
    if condensed==nil then condensed=self:GetGuildCondensedDateTime(commandId,guildName) end
    schedule=occurrence or schedule
    local dateFormat=condensed and "%02d/%02d" or "%02d/%02d/%04d"
    local target=schedule.eventAtUtc+offset
    if token=="eventcountdown" then return self:FormatEventCountdown(target-now) end
    local event=self:GetScheduleParts(target,schedule)
    if token=="eventdate" then return string.format(dateFormat,event.month,event.day,event.year) end
    if token=="eventtime" then
        if condensed then return string.format("%d%s%s %s",event.hour%12==0 and 12 or event.hour%12,event.min==0 and "" or string.format("%02d",event.min),event.hour>=12 and "PM" or "AM",schedule.timeZone) end
        return self:FormatScheduleDateTime(target,schedule):sub(12)
    end
    if token=="eventwhen" then
        local current=self:GetScheduleParts(now,schedule)
        local day=self:ParseScheduleDateTime(string.format("%04d-%02d-%02d",current.year,current.month,current.day),"12:00 AM",nil,schedule)
        if current.year==event.year and current.yday==event.yday then return "today" end
        -- Compare civil dates through noon UTC to avoid a 23/25-hour DST day.
        local nextDay=os.date("!*t",day+self:GetTimeZoneUtcOffset(day,schedule.timeZone)*3600+86400)
        if nextDay.year==event.year and nextDay.yday==event.yday then return "tomorrow" end
        local weekdays={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
        return (condensed and weekdays[event.wday]:sub(1,3) or weekdays[event.wday]).." "..string.format(dateFormat,event.month,event.day,event.year)
    end
end

function SmartChatMsg:ResolveScheduledEventTokens(text,commandId,guildName,context)
    return tostring(text or ""):gsub("%%([%a][%w_:+%-]*)%%",function(token)
        return self:GetScheduledEventTokenValue(zo_strlower(token),commandId,guildName,context) or "%"..token.."%"
    end)
end
