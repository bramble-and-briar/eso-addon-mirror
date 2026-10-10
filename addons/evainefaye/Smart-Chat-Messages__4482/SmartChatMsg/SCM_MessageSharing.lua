SmartChatMsg = SmartChatMsg or {}

local function validChannel(channel) return channel=="Zone" or channel=="Guild" or channel=="Officer" or channel=="Group" end

function SmartChatMsg:BuildMessageShareString(commandId,guildName)
    if not self:GetCommandById(commandId) or not self:GetGuildSlotByName(guildName) then
        return nil,"Select a command and an available guild in Messages Settings first."
    end
    local channel=self:GetSavedChatChannel(commandId,guildName)
    if not validChannel(channel) then return nil,"Select the output channel in Messages Settings first." end
    local entries=self:GetMessageEntriesForCommandAndGuild(commandId,guildName)
    if #entries==0 then return nil,"No messages to share for this command/guild." end
    local lines={"SCM_MESSAGES_V1","SET|"..self:EscapeImportExportField(guildName).."|"..channel}
    for _,entry in ipairs(entries) do
        if entry.locked~=true then lines[#lines+1]="TEXT|"..self:EscapeImportExportField(entry.text) end
    end
    if #lines==2 then return nil,"No unlocked messages to share for this command/guild." end
    lines[#lines+1]="END"
    local text=table.concat(lines,"\n")
    if #text>30000 then return nil,"This message set is too large to share in one paste (30,000 bytes)." end
    return text
end

function SmartChatMsg:ImportSharedMessages(rawText,commandId,guildName)
    local slot=self:GetGuildSlotByName(guildName)
    if not self:GetCommandById(commandId) or not slot then return false,"Select a command and an available guild in Messages Settings first." end
    local text=self:Trim(tostring(rawText or "")):gsub("\r\n","\n")
    if #text>30000 then return false,"Shared message text exceeds 30,000 bytes." end
    local lines={}; for line in (text.."\n"):gmatch("(.-)\n") do if line~="" then lines[#lines+1]=line end end
    if lines[1]~="SCM_MESSAGES_V1" then return false,"Use an Export Messages string starting with SCM_MESSAGES_V1." end
    if lines[#lines]~="END" then return false,"Shared message text is incomplete: missing END." end
    local sourceGuild,channel=(lines[2] or ""):match("^SET|([^|]+)|([^|]+)$")
    sourceGuild=sourceGuild and self:UnescapeImportExportField(sourceGuild)
    if not sourceGuild or not self:StringsEqualIgnoreCase(sourceGuild,guildName) then return false,"Shared messages belong to a different guild." end
    if not validChannel(channel) or channel~=self:GetSavedChatChannel(commandId,guildName) then
        return false,"Select the same output channel as the shared message set before importing."
    end
    local candidates={}
    for index=3,#lines-1 do
        local encoded=lines[index]:match("^TEXT|([^|]*)$")
        if not encoded then return false,"Invalid shared message record on line "..index.."." end
        local message=self:UnescapeImportExportField(encoded)
        if self:Trim(message)=="" or (zo_strlen and zo_strlen(message) or #message)>360 then
            return false,"Shared messages must contain 1–360 characters."
        end
        candidates[#candidates+1]=message
    end
    if #candidates==0 then return false,"The shared set contains no messages." end
    local existing,ids={},{}
    for _,entry in ipairs(self:GetMessageEntriesForCommandAndGuild(commandId,guildName)) do existing[entry.text]=true end
    for _,entry in ipairs(self.savedVars.messages or {}) do ids[entry.id]=true end
    local additions,duplicates={},0
    for _,message in ipairs(candidates) do
        if existing[message] then duplicates=duplicates+1 else
            local id
            for attempt=1,20 do local candidate=self:GenerateUuid(); if not ids[candidate] then id=candidate; break end end
            if not id then return false,"Could not allocate a message ID. Please try again." end
            ids[id],existing[message]=true,true
            additions[#additions+1]={id=id,commandId=commandId,guildName=self:GetGuildNameByIndex(slot),guildIndex=slot,text=message}
        end
    end
    -- Apply only after validating the complete payload. Personal settings,
    -- automation ownership, existing message IDs and usage remain untouched.
    for _,entry in ipairs(additions) do self.savedVars.messages[#self.savedVars.messages+1]=entry end
    return true,string.format("Added %d messages; skipped %d exact duplicates.",#additions,duplicates)
end

function SmartChatMsg:BuildMessageSharingOptionControls()
    local function selection() return self.savedVars.selectedMessagesCommand,self:GetSelectedGuildNameForMessages() end
    return {
        {type="description",text="Select a command, guild and output channel in Messages Settings. Export Messages shares only that set. Import Messages adds new templates and skips exact duplicates, preserving your other messages and settings. The source guild and channel must match. Copy/paste the text between players."},
        {type="description",text=function() local id,guild=selection(); return (self:GetCommandNameById(id) or "No command").." / "..tostring(guild or "No guild").." / "..tostring(self:GetSavedChatChannel(id,guild) or "No channel") end},
        {type="editbox",name="Shared message text",isMultiline=true,isExtraWide=true,maxChars=30000,width="full",
            getFunc=function() return self.pendingMessageShareText or "" end,setFunc=function(v) self.pendingMessageShareText=v end},
        {type="button",name="Export Messages",func=function()
            local id,guild=selection(); local text,reason=self:BuildMessageShareString(id,guild)
            if text then self.pendingMessageShareText=text; self:RefreshSettingsUI() else self:ShowStatusMessage(reason) end
        end},
        {type="button",name="Import Messages (merge)",func=function()
            local id,guild=selection(); local ok,result=self:ImportSharedMessages(self.pendingMessageShareText,id,guild)
            self:ShowStatusMessage(result)
            if ok then self.pendingMessageShareText=""; self:RefreshSettingsUI() end
        end},
        {type="description",text="This does not copy schedules, cooldowns, channels or pauses. For %eventdate%, %eventtime% or %eventwhen% templates, configure the matching event in your scheduling settings. New scheduled templates default to ANY phase until you assign them. Full backup/restore remains in Import / Export Settings and replaces all settings."},
    }
end
