SmartChatMsg = SmartChatMsg or {}
local reserved={scm=true,scmdebug=true,on=true,off=true,schedule=true,status=true,retry=true,resetcooldowns=true,send=true}
function SmartChatMsg:IsReservedCommandName(name)
    return reserved[zo_strlower(self:SanitizeCommandName(name or ''))]==true
end
function SmartChatMsg:IsScheduledSendingEnabled()
    return not self.savedVars or self.savedVars.scheduledSendingEnabled~=false
end
function SmartChatMsg:SetScheduledSendingEnabled(enabled)
    self.savedVars.scheduledSendingEnabled=enabled==true
    if not enabled then
        for id,guilds in pairs(self.savedVars.commandGuildSettings or {}) do for guild,settings in pairs(guilds) do
            if settings.runAt=='SCHEDULED' then self:StopScheduledDelivery(id,guild) end
        end end
    end
    self:AddLocalChatMessage(enabled and '[SmartChatMsg] Scheduled sending is ON. Eligible schedules will resume.' or '[SmartChatMsg] Scheduled sending is OFF. Incoming monitoring and ordinary commands remain active. Use /scm on to resume schedules.')
    self:TickSchedules()
    if self.statusPanelVisible then self:RefreshStatusPanel() end
    return true
end

-- A scheduled-only command has no standalone slash handler. Resolve it by name
-- here, without changing its enabled/paused state or its saved output channel.
function SmartChatMsg:TriggerScheduledCommand(name,slotText)
    local function reject(reason)
        self:AddLocalChatMessage("[SmartChatMsg] Cannot prepare reminder: "..reason)
        return false,reason
    end
    local slash=self:BuildSlashCommandName(name or "")
    local command
    for _,candidate in ipairs(self:GetCommands()) do
        if slash and self:BuildSlashCommandName(candidate.name or "")==slash then command=candidate;break end
    end
    if not command then return reject("no saved command named "..tostring(name or "")..".") end
    local slot=slotText and tonumber(slotText)
    if slotText and (not slot or slot<1 or slot>5 or slot~=math.floor(slot)) then
        return reject("use /scm send <command> [guild number 1-5].")
    end
    if not slot then
        local available={}
        for index=1,5 do
            local guild=self:GetGuildNameByIndex(index)
            if guild and self:GetGuildRunAt(command.id,guild)=="SCHEDULED" then available[#available+1]=index end
        end
        if #available==1 then slot=available[1]
        else
            local default=self:GetDefaultGuildIndex()
            for _,index in ipairs(available) do if index==default then slot=index;break end end
        end
        if not slot then return reject("choose its scheduled guild with /scm send "..name.." <guild number 1-5>.") end
    end
    local guild=self:GetGuildNameByIndex(slot)
    if not guild then return reject("guild slot "..slot.." is unavailable.") end
    if self:GetGuildRunAt(command.id,guild)~="SCHEDULED" then
        return reject("that command is not Scheduled for "..guild.."; use its ordinary slash command instead.")
    end
    local ok,reason=self:RequestScheduledDelivery(command.id,guild,true)
    if not ok then return reject(reason) end
    self:ProcessChatPopulationQueue()
    self:AddLocalChatMessage("[SmartChatMsg] "..slash.." / "..guild..": reminder requested. Press Enter when it is ready in chat.")
    return true
end

function SmartChatMsg:HandleScmCommand(paramText)
    local normalized=zo_strlower(self:Trim(paramText or ""))
    if normalized=="" then self:OpenSettings();return true
    elseif normalized=="schedule" then return self:OpenEventPlanner()
    elseif normalized=="on" then return self:SetScheduledSendingEnabled(true)
    elseif normalized=="off" then return self:SetScheduledSendingEnabled(false)
    elseif normalized=="status" then self:ToggleStatusPanel();return true
    elseif normalized=="retry" then return self:RetryTimedOutMessage()
    elseif normalized=="resetcooldowns" then self:ResetAllCooldowns();return true end
    local parts={}
    for word in normalized:gmatch("%S+") do parts[#parts+1]=word end
    if parts[1]=="send" then table.remove(parts,1) end
    if #parts<1 or #parts>2 then
        self:AddLocalChatMessage("[SmartChatMsg] Usage: /scm, /scm on, /scm off, /scm schedule, /scm status, /scm retry, /scm resetcooldowns, or /scm send <command> [guild number 1-5].")
        return false
    end
    return self:TriggerScheduledCommand(parts[1],parts[2])
end
