SmartChatMsg = SmartChatMsg or {}

local function records(self,text)
    local result={}
    for line in (tostring(text or ""):gsub("\r", "").."\n"):gmatch("(.-)\n") do
        if line~="" then
            local row={}
            for value in (line.."|"):gmatch("(.-)|") do row[#row+1]=self:UnescapeImportExportField(value) end
            result[#result+1]=row
        end
    end
    return result
end
local function encode(self,row)
    local fields={}
    for i,value in ipairs(row) do fields[i]=self:EscapeImportExportField(value) end
    return table.concat(fields,"|")
end
local function hex(text) return (text:gsub(".",function(c) return string.format("%02X",c:byte()) end)) end
local function unhex(text)
    if #text%2~=0 or text:find("[^%x]") then return nil end
    return (text:gsub("%x%x",function(c) return string.char(tonumber(c,16)) end))
end
local function marker(kind,name) return "{{SCM_GUILD:"..kind..":"..hex(name).."}}" end
local function guildField(kind)
    if kind=="MESSAGE" then return 5 end
    if kind=="MESSAGEPOOL_V1" or kind=="CHANNEL" or kind=="GUILDSETTING" or kind=="ACTIVE" or kind:match("^SCHEDULE") then return 3 end
    if kind=="GUILDTIMEZONE" then return 2 end
end
local function slashReferences(text,resolve)
    local missing
    local output=text:gsub("()/([gGoO])([1-5])()",function(first,kind,slot,after)
        local before=text:sub(first-1,first-1)
        local following=text:sub(after,after)
        local delimiter=before:match("[%s%(%[%{.,:;!?]") or before==string.char(34) or before=="'"
        if (first>1 and not delimiter) or following:match("[%w_/]") then return "/"..kind..slot end
        local replacement,reason=resolve(kind,tonumber(slot))
        if not replacement then missing=reason end
        return replacement or "/"..kind..slot
    end)
    return output,missing
end

function SmartChatMsg:BuildExportString()
    local rows=records(self,self:BuildSlotExportString())
    rows[1]={"SCM_EXPORT_V2"}
    local function sourceName(slot)
        return self:GetGuildNameByIndex(tonumber(slot)) or "Unknown source guild slot "..tostring(slot)
    end
    for _,row in ipairs(rows) do
        local kind=row[1]
        local index=guildField(kind)
        if index and row[index] and row[index]~="" then
            local slot=self:GetGuildSlotByName(row[index])
            if slot then row[index]=self:GetGuildNameByIndex(slot) end
        end
        if kind=="DEFAULT" then row[2]=row[2]~="" and sourceName(row[2]) or "" end
        if kind=="MESSAGE" then
            local name=row[5]~="" and row[5] or sourceName(row[4])
            row[4],row[5]=name,name
            row[6]=slashReferences(row[6],function(channel,slot) return marker(channel:lower(),sourceName(slot)) end)
        elseif kind=="GUILDSETTING" then
            local previousSlot=row[10]
            if row[10]~="" then row[10]=row[3] end
            local prefix,slot=(row[9] or ""):match("^([gGoO]?)([1-5])$")
            if slot then row[9]=marker(prefix=="" and "p" or prefix:upper(),slot==previousSlot and row[3] or sourceName(slot)) end
            row[9]=slashReferences(row[9] or "",function(channel,slot) return marker(channel:lower(),sourceName(slot)) end)
        end
    end
    local lines={};for _,row in ipairs(rows) do lines[#lines+1]=encode(self,row) end
    return table.concat(lines,"\n")
end

function SmartChatMsg:PrepareGuildTransfer(rawText)
    local rows=records(self,self:Trim(rawText or ""))
    local version=rows[1] and rows[1][1]
    if version~="SCM_EXPORT_V1" and version~="SCM_EXPORT_V2" then return nil,"Import text must start with SCM_EXPORT_V1 or SCM_EXPORT_V2." end
    local transfer={notices={},slotNames={},version=version}
    -- Old exports identify a source slot on named message records. Do not
    -- interpret an unknown sender slot as the recipient's current slot.
    local seenSlots={}
    local function remember(slot,name)
        if not slot or not name or name=="" then return end
        if seenSlots[slot] then
            local previous=transfer.slotNames[slot]
            if not previous or not self:StringsEqualIgnoreCase(previous,name) then transfer.slotNames[slot]=false end
        else seenSlots[slot]=true;transfer.slotNames[slot]=name end
    end
    local commandNames={}
    for _,row in ipairs(rows) do
        if row[1]=="END" then break end
        if row[1]=="COMMAND" then commandNames[row[2]]=row[3] end
        if version=="SCM_EXPORT_V1" then
            if row[1]=="MESSAGE" then remember(tonumber(row[4]),row[5]) end
            if row[1]=="GUILDSETTING" and #row>=14 then remember(tonumber(row[10]),row[3]) end
        end
    end
    local function resolve(name)
        local slot=self:GetGuildSlotByName(name)
        return slot,slot and self:GetGuildNameByIndex(slot)
    end
    local function notice(row,name)
        local details=row[1].." "..tostring(commandNames[row[2]] or row[2] or "")
        if row[1]=="MESSAGE" then details=details.." ("..tostring(commandNames[row[3]] or row[3] or "").."): "..tostring(row[6] or ""):sub(1,100) end
        transfer.notices[#transfer.notices+1]="[SmartChatMsg] Skipped record "..details.." due to no such guild ("..tostring(name)..")."
    end
    transfer.notice=notice
    local function restoreText(text)
        local missing
        local result=text:gsub("{{SCM_GUILD:([gopGO]):([^}]*)}}",function(kind,encoded)
            local name=unhex(encoded)
            local slot=name and resolve(name)
            if not slot then missing=name or "invalid guild reference";return "" end
            if kind=="p" then return tostring(slot) end
            if kind=="G" or kind=="O" then return kind:lower()..slot end
            return "/"..kind..slot
        end)
        if version=="SCM_EXPORT_V1" then
            local legacyMissing
            result,legacyMissing=slashReferences(result,function(kind,slot)
                local name=transfer.slotNames[slot]
                local target=name and resolve(name)
                if not target then return nil,name or "unknown source guild slot "..slot end
                return "/"..kind..target
            end)
            missing=missing or legacyMissing
        end
        return result,missing
    end
    transfer.restoreText=restoreText
    local output={"SCM_EXPORT_V1"}
    for i=2,#rows do
        local row=rows[i];local kind=row[1];local missing
        if kind=="END" then output[#output+1]="END";break end
        local index=guildField(kind)
        if index then
            local name=row[index] or ""
            if name=="" and kind=="MESSAGE" then name=transfer.slotNames[tonumber(row[4])] or "unknown source guild slot "..tostring(row[4]) end
            local slot,canonical=resolve(name)
            if not slot then missing=name else row[index]=canonical end
            if kind=="MESSAGE" and slot then row[4]=tostring(slot) end
        end
        if kind=="DEFAULT" and row[2]~="" then
            local name=version=="SCM_EXPORT_V2" and row[2] or transfer.slotNames[tonumber(row[2])]
            local slot=name and resolve(name)
            if slot then row[2]=tostring(slot) else missing=name or "unknown source guild slot "..tostring(row[2]) end
        elseif kind=="MESSAGE" and not missing then
            row[6],missing=restoreText(row[6] or "")
        elseif kind=="GUILDSETTING" and version=="SCM_EXPORT_V2" and not missing then
            row[9],missing=restoreText(row[9] or "")
            if row[10]~="" then
                local slot=resolve(row[10]);if slot then row[10]=tostring(slot) else missing=row[10] end
            end
        end
        if missing then notice(row,missing) else output[#output+1]=encode(self,row) end
    end
    return table.concat(output,"\n"),transfer
end

function SmartChatMsg:RemapImportedGuildSlots(imported,transfer)
    if transfer.version~="SCM_EXPORT_V1" then return end
    for id,guilds in pairs(imported.commandGuildSettings or {}) do
        for guild,settings in pairs(guilds) do
            local previous=settings.lastUsedGuildIndex
            if previous then settings.lastUsedGuildIndex=self:GetGuildSlotByName(guild) end
            local parameter=settings.lastUsedParamText
            local prefix,slotText=tostring(parameter or ""):match("^([gGoO]?)([1-5])$")
            if slotText then
                local slot=tonumber(slotText)
                local name=transfer.slotNames[slot] or (slot==previous and guild)
                local target=name and self:GetGuildSlotByName(name)
                if target then settings.lastUsedParamText=prefix:lower()..tostring(target) else
                    guilds[guild]=nil
                    transfer.notice({"GUILDSETTING",id},name or "unknown source guild slot "..parameter)
                end
            elseif parameter then
                local restored,missing=transfer.restoreText(parameter)
                if missing then guilds[guild]=nil;transfer.notice({"GUILDSETTING",id},missing)
                else settings.lastUsedParamText=restored end
            end
        end
    end
end

function SmartChatMsg:ImportSettingsFromString(rawText)
    if self:Trim(rawText or "")=="" then return false,"Paste exported settings first." end
    local text,transfer=self:PrepareGuildTransfer(rawText)
    if not text then return false,transfer end
    return self:ImportSlotSettingsFromString(text,transfer)
end
