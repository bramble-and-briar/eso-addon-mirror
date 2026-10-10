SmartChatMsg = SmartChatMsg or {}
local phases = {"ANY", "BEFORE", "DAY", "LIVE", "SOON"}
local function positiveInteger(value)
    value = tonumber(value)
    return value and value > 0 and value < math.huge and value == math.floor(value) and value or nil
end

function SmartChatMsg:NormalizeSchedule(data)
    if type(data) ~= "table" then return nil, "Schedule not configured." end
    local result = {enabled=data.enabled == true, paused=data.paused == true, timeZone=self:NormalizeSchedulingTimeZone(data.timeZone or self:GetSchedulingTimeZone()),
        delivery=data.delivery or "REPEAT", intervalMinutes=positiveInteger(data.intervalMinutes or 5), messagePhases={}, phaseIntervals={},
        mode=data.mode or "EVENT", recurrence=data.recurrence or "NONE", recurrenceInterval=positiveInteger(data.recurrenceInterval or 1), weekdays={}, phaseOnce={}}
    if result.mode~="EVENT" and result.mode~="WINDOW" and result.mode~="REMINDER" then return nil,"Choose a schedule kind." end
    result.startingSoonEnabled=result.mode=="EVENT" and data.startingSoonEnabled==true
    result.startingSoonMinutes=positiveInteger(data.startingSoonMinutes or 120)
    if result.startingSoonEnabled and not result.startingSoonMinutes then return nil,"Starting soon: enter a positive whole number of minutes before the event." end
    if not result.startingSoonMinutes then result.startingSoonMinutes=120 end
    local validRecurrence={NONE=true,DAILY=true,WEEKLY=true,BIWEEKLY=true,MONTHLY_DATE=true,MONTHLY_WEEKDAY=true}
    if not validRecurrence[result.recurrence] or not result.recurrenceInterval then return nil,"Choose a valid recurrence and positive interval." end
    local patternOk,patternError=self:NormalizeEventPattern(data,result)
    if not patternOk then return nil,patternError end
    for day=1,7 do if type(data.weekdays)=="table" and data.weekdays[day] then result.weekdays[day]=true end end
    for _,phase in ipairs(phases) do result.phaseOnce[phase]=type(data.phaseOnce)=="table" and data.phaseOnce[phase]==true end
    local simpleEvent=data.mode=="EVENT" and (data.promotionDays~=nil or not data.startDate)
    local names=result.mode=="REMINDER" and {"start"} or result.mode=="WINDOW" and {"start","end"} or simpleEvent and {"event"} or {"start","event","end"}
    if result.mode=="REMINDER" then result.delivery="REPEAT" end
    if result.delivery ~= "REPEAT" and result.delivery ~= "ZONE" then return nil,"Choose Repeat or Zone delivery." end
    if not result.intervalMinutes then return nil,"Enter a positive whole-number interval in minutes." end
    for _, name in ipairs(names) do
        local date, time = self:Trim(data[name.."Date"] or ""), self:Trim(data[name.."Time"] or "")
        local fold = data[name.."Fold"]
        if data.mode and not fold then fold="EDT" end
        local utc, reason = self:ParseScheduleDateTime(date,time,fold,result)
        if not utc then return nil,name..": "..reason end
        result[name.."Date"],result[name.."Time"],result[name.."Fold"] = date,time,fold
        result[name == "start" and "startsAtUtc" or name == "end" and "endsAtUtc" or "eventAtUtc"] = utc
    end
    if result.mode=="REMINDER" then result.eventAtUtc=result.startsAtUtc;result.endsAtUtc=result.startsAtUtc+120
    elseif result.mode=="WINDOW" then result.eventAtUtc=result.startsAtUtc
    elseif simpleEvent then
        local lead,delay=tonumber(data.promotionDays or 1),positiveInteger(data.endDelayMinutes or 60)
        if not lead or lead<0 or lead>3650 or lead~=math.floor(lead) or not delay then return nil,"Use whole promotion days and a positive end delay." end
        result.promotionDays,result.endDelayMinutes=lead,delay
        result.startsAtUtc,result.endsAtUtc=result.eventAtUtc-lead*86400,result.eventAtUtc+delay*60
        local o=self:BuildScheduleOccurrence(result,result.eventAtUtc);if not o then return nil,"Promotion start time does not exist." end
        result.startsAtUtc,result.endsAtUtc=o.startsAtUtc,o.endsAtUtc
    end
    for _,name in ipairs({"start","event","end"}) do
        if not result[name.."Date"] then
            local value=name=="start" and result.startsAtUtc or name=="end" and result.endsAtUtc or result.eventAtUtc
            local formatted=self:FormatScheduleDateTime(value,result)
            result[name.."Date"],result[name.."Time"]=formatted:sub(1,10),formatted:sub(12,19)
        end
    end
    if result.startsAtUtc > result.eventAtUtc or result.eventAtUtc >= result.endsAtUtc then
        return nil,"Schedule start must be at/before the event, and schedule end must be after the event."
    end
    for id, assignments in pairs(type(data.messagePhases) == "table" and data.messagePhases or {}) do
        if type(id) == "string" and type(assignments) == "table" then
            result.messagePhases[id]={}
            for _, phase in ipairs(phases) do result.messagePhases[id][phase]=assignments[phase] == true end
        end
    end
    for _, phase in ipairs({"BEFORE","DAY","LIVE","SOON"}) do
        local raw = type(data.phaseIntervals) == "table" and data.phaseIntervals[phase] or nil
        if phase=="SOON" and raw==nil then raw=data.startingSoonIntervalMinutes end
        if raw ~= nil and raw ~= "" then
            local interval=positiveInteger(raw)
            if not interval then return nil,phase..": interval must be a positive whole number or blank." end
            result.phaseIntervals[phase]=interval
        end
    end
    result.nextDueAt = positiveInteger(data.nextDueAt)
    result.nextDuePhase = data.nextDuePhase
    result.nextDueOccurrence=data.nextDueOccurrence
    result.completedOccurrences=type(data.completedOccurrences)=="table" and data.completedOccurrences or {}
    return result
end

function SmartChatMsg:GetGuildSchedule(commandId,guildName)
    local settings=self:GetCommandGuildSettings(commandId,guildName,false)
    return settings and settings.schedule or nil
end

function SmartChatMsg:SaveGuildSchedule(commandId,guildName,draft)
    if not self:GetCommandById(commandId) or not self:GetGuildSlotByName(guildName) then
        return false,"Select an available command and guild."
    end
    local candidate={};for key,value in pairs(draft) do candidate[key]=value end
    candidate.timeZone=self:GetGuildSchedulingTimeZone(guildName)
    local schedule,reason=self:NormalizeSchedule(candidate)
    if not schedule then return false,reason end
    if schedule.enabled and schedule.delivery=="ZONE" then
        for id,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do
            for key,settings in pairs(byGuild) do
                local other=settings.schedule
                if settings.runAt=="SCHEDULED" and other and other.enabled and other.delivery=="ZONE"
                    and (id~=commandId or key~=self:NormalizeKey(guildName)) then
                    return false,"Only one enabled scheduled Zone combination is supported. Disable the other schedule first."
                end
            end
        end
    end
    local settings=self:GetCommandGuildSettings(commandId,guildName,true)
    if self.StopScheduledDelivery then self:StopScheduledDelivery(commandId,guildName) end
    local active=self.GetActiveAutoPopulate and self:GetActiveAutoPopulate()
    if active and active.commandId==commandId and self:StringsEqualIgnoreCase(active.guildName,guildName) then self:ClearActiveAutoPopulate() end
    settings.schedule,settings.runAt=schedule,"SCHEDULED"
    if self.RegisterDynamicCommands then self:RegisterDynamicCommands() end
    if self.TickSchedules then self:TickSchedules() end
    return true
end

function SmartChatMsg:GetGuildScheduleState(commandId,guildName,utc)
    if self:GetGuildRunAt(commandId,guildName)~="SCHEDULED" then return "ON_DEMAND" end
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if not schedule then return "UNCONFIGURED" end
    if not schedule.enabled then return schedule.paused and "PAUSED" or "DISABLED" end
    utc=utc or GetTimeStamp()
    local occurrence=self:GetScheduleOccurrence(schedule,utc)
    if not occurrence then return "FINISHED" end
    if schedule.paused then return "PAUSED" end
    if utc<occurrence.startsAtUtc then return "WAITING" end
    return "RUNNING",self:GetSchedulePhase(schedule,utc)
end

function SmartChatMsg:GetScheduleIntervalMinutes(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    if not schedule then return nil end
    local phase=self:GetSchedulePhase(schedule,GetTimeStamp())
    return (schedule.phaseIntervals or {})[phase] or schedule.intervalMinutes
end

function SmartChatMsg:GetScheduledMessageEntries(commandId,guildName)
    local state,phase=self:GetGuildScheduleState(commandId,guildName)
    if state~="RUNNING" then return {} end
    local schedule=self:GetGuildSchedule(commandId,guildName)
    local result={}
    local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp())
    local variant=self:GetScheduleEventVariant(schedule,occurrence.eventAtUtc)
    local entries=self:GetMessageEntriesForCommandAndGuild(commandId,guildName)
    if schedule.specialPattern=='MONTH_FINAL' and variant=='FINAL' then
        local hasSpecialMessages=false
        for _,entry in ipairs(entries) do
            if self:GetScheduleMessageVariant(schedule,entry.id)=='FINAL' then hasSpecialMessages=true;break end
        end
        if not hasSpecialMessages then variant='REGULAR' end
    end
    for _,entry in ipairs(entries) do
        local assigned=schedule.messagePhases[entry.id]
        local group=self:GetScheduleMessageVariant(schedule,entry.id)
        if (not assigned or assigned.ANY or assigned[phase]) and (schedule.specialPattern=='NONE' or group=='ALL' or group==variant) then result[#result+1]=entry end
    end
    return result
end

function SmartChatMsg:ExportScheduleRecords()
    local lines={}
    local function encode(fields)
        for index,value in ipairs(fields) do fields[index]=self:EscapeImportExportField(value) end
        return table.concat(fields,"|")
    end
    for id,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do
        for guild,settings in pairs(byGuild) do
            local s=settings.schedule
            if s then
                local fields={"SCHEDULE_V1",id,guild,s.enabled and "1" or "0",s.paused and "1" or "0",s.delivery,tostring(s.intervalMinutes)}
                for _,name in ipairs({"start","event","end"}) do
                    fields[#fields+1]=s[name.."Date"]; fields[#fields+1]=s[name.."Time"]; fields[#fields+1]=s[name.."Fold"] or ""
                end
                for _,phase in ipairs({"BEFORE","DAY","LIVE"}) do fields[#fields+1]=tostring(s.phaseIntervals[phase] or "") end
                lines[#lines+1]=encode(fields)
                local days={};for day=1,7 do days[day]=s.weekdays and s.weekdays[day] and "1" or "0" end
                local once={};for _,phase in ipairs(phases) do once[#once+1]=s.phaseOnce and s.phaseOnce[phase] and "1" or "0" end
                lines[#lines+1]=encode({"SCHEDULEOPTIONS_V1",id,guild,s.mode or "EVENT",s.recurrence or "NONE",tostring(s.recurrenceInterval or 1),table.concat(days),tostring(s.promotionDays or ""),tostring(s.endDelayMinutes or ""),table.concat(once),s.startingSoonEnabled and "1" or "0",tostring(s.startingSoonMinutes or 120),tostring(s.phaseIntervals.SOON or "")})
                lines[#lines+1]=encode({"SCHEDULEPATTERN_V1",id,guild,s.specialPattern or "NONE",tostring(s.rotationWeeks or 4),table.concat(s.rotationFactions or {"AD","EP","DC"},",")})
                for messageId,variant in pairs(s.messageVariants or {}) do
                    if not self:IsMessageLocked(messageId) then lines[#lines+1]=encode({"SCHEDULEVARIANT_V1",id,guild,messageId,variant}) end
                end
                for messageId,assigned in pairs(s.messagePhases) do
                    if not self:IsMessageLocked(messageId) then
                    local row={"SCHEDULEMESSAGE_V1",id,guild,messageId}
                    for _,phase in ipairs(phases) do row[#row+1]=assigned[phase] and "1" or "0" end
                    lines[#lines+1]=encode(row)
                    end
                end
            end
        end
    end
    return lines
end

function SmartChatMsg:ImportScheduleRecords(records,imported)
    local candidates={}
    local commands={}
    for _,command in ipairs(imported.commands) do commands[command.id]=true end
    for _,row in ipairs(records) do
        for i,value in ipairs(row) do row[i]=self:UnescapeImportExportField(value) end
        local kind,id,guild=row[1],row[2],self:NormalizeKey(row[3])
        if commands[id] and guild then
            candidates[id]=candidates[id] or {}; candidates[id][guild]=candidates[id][guild] or {messagePhases={}}
            local d=candidates[id][guild]
            if kind=="SCHEDULE_V1" then
                d.enabled,d.paused,d.delivery,d.intervalMinutes=row[4]=="1",row[5]=="1",row[6],row[7]
                local index=8
                for _,name in ipairs({"start","event","end"}) do
                    d[name.."Date"],d[name.."Time"],d[name.."Fold"]=row[index],row[index+1],row[index+2]; index=index+3
                end
                d.phaseIntervals={BEFORE=row[17],DAY=row[18],LIVE=row[19]}
            elseif kind=="SCHEDULEOPTIONS_V1" then
                d.mode,d.recurrence,d.recurrenceInterval=row[4],row[5],row[6]
                d.weekdays={};for day=1,7 do if (row[7] or ""):sub(day,day)=="1" then d.weekdays[day]=true end end
                d.promotionDays=row[8]~="" and row[8] or nil;d.endDelayMinutes=row[9]~="" and row[9] or nil
                d.startingSoonEnabled=row[11]=="1";d.startingSoonMinutes=row[12] or 120;d.startingSoonIntervalMinutes=row[13]
                d.phaseOnce={};for index,phase in ipairs(phases) do d.phaseOnce[phase]=(row[10] or ""):sub(index,index)=="1" end
            elseif kind=="SCHEDULEPATTERN_V1" then
                d.specialPattern,d.rotationWeeks=row[4],row[5]
                d.rotationFactions={};for faction in (row[6] or ""):gmatch("[^,]+") do d.rotationFactions[#d.rotationFactions+1]=faction end
            elseif kind=="SCHEDULEVARIANT_V1" then
                if not row[4] or row[4]=="" then return false,"Imported event group is missing its message ID." end
                d.messageVariants=d.messageVariants or {};d.messageVariants[row[4]]=row[5]
            else
                if not row[4] or row[4]=="" then return false,"Imported schedule message is missing its ID." end
                d.messagePhases[row[4]]={ANY=row[5]=="1",BEFORE=row[6]=="1",DAY=row[7]=="1",LIVE=row[8]=="1",SOON=row[9]=="1"}
            end
        end
    end
    local enabledZones=0
    for id,byGuild in pairs(candidates) do
        for guild,draft in pairs(byGuild) do
            draft.timeZone=self:GetGuildSchedulingTimeZone(guild,imported)
            local schedule,reason=self:NormalizeSchedule(draft)
            if not schedule then return false,"Imported schedule: "..reason end
            if schedule.enabled and schedule.delivery=="ZONE" then enabledZones=enabledZones+1 end
            if enabledZones>1 then return false,"Import contains more than one enabled scheduled Zone combination." end
            imported.commandGuildSettings[id]=imported.commandGuildSettings[id] or {}
            imported.commandGuildSettings[id][guild]=imported.commandGuildSettings[id][guild] or {}
            imported.commandGuildSettings[id][guild].schedule=schedule
        end
    end
    return true
end
