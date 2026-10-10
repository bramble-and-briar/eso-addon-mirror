SmartChatMsg = SmartChatMsg or {}

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
    self.scheduledSendPause={senderKey=self:GetReminderStateKey(metadata.commandId,metadata.guildName),endsAt=GetTimeStamp()+300}
    self:ShowStatusMessage(self:GetSlashCommandDisplayName(metadata.commandId).." / "..metadata.guildName
        ..": scheduled message sent. Other schedules pause for 5 minutes, until "..self:FormatScheduleDateTime(self.scheduledSendPause.endsAt,self:GetGuildSchedule(metadata.commandId,metadata.guildName))..".")
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
        metadata=metadata or {},priority=priority,sequence=self.chatPopulationSequence,
        runAt=self:GetGuildRunAt(commandId,guildName),schedule=self:GetGuildSchedule(commandId,guildName)}
    return true
end

function SmartChatMsg:ProcessChatPopulationQueue()
    if self:IsChatPopulationBusy() then return end
    local ordered={}
    for key,request in pairs(self.chatPopulationQueue or {}) do request.key=key; ordered[#ordered+1]=request end
    table.sort(ordered,function(a,b) return a.priority==b.priority and a.sequence<b.sequence or a.priority<b.priority end)
    for _,request in ipairs(ordered) do
        self.chatPopulationQueue[request.key]=nil
        local state,phase=self:GetGuildScheduleState(request.commandId,request.guildName)
        local valid=self:GetCommandById(request.commandId) and self:GetGuildSlotByName(request.guildName)
            and self:GetGuildRunAt(request.commandId,request.guildName)==request.runAt
        if request.metadata.scheduledDelivery then
            valid=valid and state=="RUNNING" and phase==request.metadata.scheduledPhase
                and self:GetGuildSchedule(request.commandId,request.guildName)==request.schedule
                and (not request.metadata.scheduledOccurrence or (self:GetScheduleOccurrence(request.schedule,GetTimeStamp()) or {}).occurrenceKey==request.metadata.scheduledOccurrence)
            if valid and request.schedule.delivery=="ZONE" then
                local zone=self:GetEffectiveAutoPopulateZoneId(self:GetPlayerZoneId())
                valid=zone and zone==request.metadata.zoneId
                    and not self:ShouldSkipAutoPopulateForZone(request.commandId,request.guildName,zone)
            elseif valid then
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
                self:ShowStatusMessage(self:GetSlashCommandDisplayName(request.commandId).." / "..request.guildName
                    ..": scheduled message ready in chat. Press Enter to send (chat timeout: "..tostring(self.pendingRestoreState.timeoutSeconds).." seconds).")
                local schedule=request.schedule
                if schedule.mode=="REMINDER" or (schedule.phaseOnce or {})[phase] then
                    local o=self:GetScheduleOccurrence(schedule,GetTimeStamp())
                    schedule.completedOccurrences={[o.occurrenceKey..":"..phase]=true}
                end
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
    local observed=self:GetObservedCommandCooldownEndsAt(commandId,guildName,self:GetSavedChatChannel(commandId,guildName))
    local function deadline(value) return observed and math.max(value,observed) or value end
    local once=schedule.mode=="REMINDER" or (schedule.phaseOnce or {})[phase]
    local token=occurrence.occurrenceKey..":"..phase
    if once and (schedule.completedOccurrences or {})[token] then return math.huge end
    local lastUsedAt=self:GetGuildLastUsedAt(commandId,guildName)
    local peerDelay=lastUsedAt and self:GetScheduledPeerDelay(commandId,guildName,lastUsedAt) or 0
    if schedule.nextDueAt and schedule.nextDuePhase==phase and (not schedule.nextDueOccurrence and (schedule.recurrence or "NONE")=="NONE" or schedule.nextDueOccurrence==occurrence.occurrenceKey) then
        if peerDelay>0 and lastUsedAt>=occurrence.startsAtUtc then
            return deadline(math.max(schedule.nextDueAt,lastUsedAt+self:GetScheduleIntervalMinutes(commandId,guildName)*60+peerDelay))
        end
        return deadline(schedule.nextDueAt)
    end
    if lastUsedAt and lastUsedAt>=occurrence.startsAtUtc then
        return deadline(lastUsedAt+self:GetScheduleIntervalMinutes(commandId,guildName)*60+peerDelay)
    end
    return deadline(occurrence.startsAtUtc)
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
    local state,phase=self:GetGuildScheduleState(commandId,guildName)
    if state~="RUNNING" then return false,"Schedule is "..state:lower().."." end
    local pacingEndsAt,pacingReason=self:GetSchedulePacingDelay(commandId,guildName)
    if pacingEndsAt then return false,pacingReason end
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if #self:GetScheduledMessageEntries(commandId,guildName)==0 then return false,"No message for this phase." end
    local zoneId
    if schedule.delivery=="ZONE" then
        zoneId=self:GetEffectiveAutoPopulateZoneId(self:GetPlayerZoneId())
        if not zoneId then return false,"Current zone is not eligible." end
        if self:ShouldSkipAutoPopulateForZone(commandId,guildName,zoneId) then
            self:NotifyCooldownDelay(commandId,guildName,self:GetAutoPopulateCooldownEndsAt(commandId,guildName,zoneId))
            return false,"Zone cooldown."
        end
    elseif GetTimeStamp()<self:GetScheduledDueAt(commandId,guildName,phase) then
        self:NotifyCooldownDelay(commandId,guildName,self:GetObservedCommandCooldownEndsAt(commandId,guildName,self:GetSavedChatChannel(commandId,guildName)))
        return false,"Repeat cooldown."
    end
    local pending=self.pendingRestoreState and self.pendingRestoreState.metadata
    if pending and pending.commandId==commandId and self:StringsEqualIgnoreCase(pending.guildName or "",guildName) then return true end
    return self:QueueChatPopulation(commandId,guildName,nil,{scheduledDelivery=true,scheduledPhase=phase,scheduledOccurrence=(self:GetScheduleOccurrence(schedule,GetTimeStamp()) or {}).occurrenceKey,
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
    local runtime=self.scheduleRuntime and self.scheduleRuntime[self:GetReminderStateKey(metadata.commandId,metadata.guildName)]
    self:ShowStatusMessage(self:GetSlashCommandDisplayName(metadata.commandId).." / "..metadata.guildName
        ..": scheduled message was not sent before the chat timeout. Next attempt: "..self:FormatScheduleDateTime(schedule.nextDueAt,schedule)..".")
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
    local labels={BEFORE="Before event day",DAY="On event day",SOON="Starting soon",LIVE="From event start until promotion ends"}
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
    local prefix=self:GetSlashCommandDisplayName(commandId).." / "..guildName..": "
    if previous and previous.occurrence and not previous.ended and GetTimeStamp()>=previous.occurrence.endsAtUtc then
        self:ShowStatusMessage(prefix.."schedule ended at "..self:FormatScheduleDateTime(previous.occurrence.endsAtUtc,previous.occurrence)..".")
        previous.ended=true
    end
    if state=="RUNNING" and occurrence and (not previous or previous.state~="RUNNING" or previous.occurrence.occurrenceKey~=occurrence.occurrenceKey) then
        self:ShowStatusMessage(prefix.."schedule "..(previous and previous.state=="PAUSED" and "resumed" or "started").."; "..description.."; active until "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)..".")
        previous={config=config,occurrence=occurrence,ended=false}
    elseif state=="RUNNING" and previous and previous.description~=description then
        self:ShowStatusMessage(prefix.."schedule changed to "..description.."; active until "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)..".")
    elseif state=="PAUSED" and previous and previous.state=="RUNNING" then
        self:ShowStatusMessage(prefix.."schedule paused.")
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
    self:ShowStatusMessage(self:GetSlashCommandDisplayName(commandId).." / "..guildName..": message delayed by cooldown until "..self:FormatScheduleDateTime(endsAt,self:GetGuildSchedule(commandId,guildName))..".")
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
    local seen={}
    for _,combination in ipairs(combinations) do
        local id,guild,key=combination.commandId,combination.guildName,combination.key
        -- Resolve canonical local guild name (saved keys are normalized).
        local slot=self:GetGuildSlotByName(guild)
        guild=slot and self:GetGuildNameByIndex(slot) or guild
        seen[key]=true
        local state,phase=self:GetGuildScheduleState(id,guild)
        if slot and self:GetCommandById(id) then self:NotifyScheduleTransition(id,guild,state) end
        if state~="RUNNING" or not slot or not self:GetCommandById(id) then
            self:StopScheduledDelivery(id,guild)
        else
            local schedule=self:GetGuildSchedule(id,guild)
            local runtime=self.scheduleRuntime[key]
            if not runtime then runtime={commandId=id,guildName=guild,zonePending=true}; self.scheduleRuntime[key]=runtime end
            local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
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
    local phaseNames={BEFORE="Before event day",DAY="On event day",SOON="Starting soon",LIVE="From event start until promotion ends"}
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

function SmartChatMsg:GetScheduledEventTokenValue(token,commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if not schedule then return nil end
    if token=="eventfaction" then
        local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
        return occurrence and self:GetScheduleFactionName(schedule,occurrence.eventAtUtc)
    end
    schedule=self:GetScheduleOccurrence(schedule,GetTimeStamp()) or schedule
    local event=self:GetScheduleParts(schedule.eventAtUtc,schedule)
    if token=="eventdate" then return string.format("%02d/%02d/%04d",event.month,event.day,event.year) end
    if token=="eventtime" then return self:FormatScheduleDateTime(schedule.eventAtUtc,schedule):sub(12) end
    if token=="eventwhen" then
        local current=self:GetScheduleParts(GetTimeStamp(),schedule)
        local day=self:ParseScheduleDateTime(string.format("%04d-%02d-%02d",current.year,current.month,current.day),"12:00 AM",nil,schedule)
        if current.year==event.year and current.yday==event.yday then return "today" end
        -- Compare civil dates through noon UTC to avoid a 23/25-hour DST day.
        local nextDay=os.date("!*t",day+self:GetTimeZoneUtcOffset(day,schedule.timeZone)*3600+86400)
        if nextDay.year==event.year and nextDay.yday==event.yday then return "tomorrow" end
        local weekdays={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
        return weekdays[event.wday].." "..string.format("%02d/%02d/%04d",event.month,event.day,event.year)
    end
end

function SmartChatMsg:ResolveScheduledEventTokens(text,commandId,guildName)
    return tostring(text or ""):gsub("%%([%a]+)%%",function(token)
        return self:GetScheduledEventTokenValue(zo_strlower(token),commandId,guildName) or "%"..token.."%"
    end)
end
