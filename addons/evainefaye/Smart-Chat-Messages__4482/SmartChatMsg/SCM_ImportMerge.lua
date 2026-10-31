SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local function copy(value)
 if type(value)~='table' then return value end
 local result={};for key,item in pairs(value) do result[key]=copy(item) end;return result
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end;return true
end
local options={'condensedDateTime','runAt','reminderMinutes','reminderRetryMinutes','autoPopulateCooldownMinutes','autoPopulateOnZone','openStatusPanelOnRun','populateSound'}
local function key(self,name)return self:NormalizeKey(name or '')end
local function commandKey(self,name)return key(self,self:SanitizeCommandName(name))end
function S:MergeImportedSettings(incoming)
 if type(incoming)~='table' then return nil,'Import data is invalid.' end
 local imported=copy(incoming);local result=copy(self.savedVars)
 result.commands=result.commands or {};result.messages=result.messages or {};result.chatChannels=result.chatChannels or {};result.commandGuildSettings=result.commandGuildSettings or {}
 local commandIds,names={},{}
 for _,command in ipairs(result.commands) do commandIds[command.id]=true;local name=commandKey(self,command.name);names[name]=names[name] or {};table.insert(names[name],command) end
 local function unique(used,preferred)
  if preferred and not used[preferred] then used[preferred]=true;return preferred end
  local base=self:GenerateUuid();local id=base;local suffix=0
  while used[id] do suffix=suffix+1;id=base..'-import'..suffix end;used[id]=true;return id
 end
 local commands={}
 for _,source in ipairs(imported.commands or {}) do
  if self:SanitizeCommandName(source.name or '')=='' then return nil,'Imported command has no valid name.' end
  local matches=names[commandKey(self,source.name)] or {}
  if #matches>1 then return nil,'Cannot merge ambiguous command name: '..tostring(source.name) end
  local target=matches[1]
  if not target then target=copy(source);target.name=self:SanitizeCommandName(source.name);target.id=unique(commandIds,source.id);target.lastUsedAt=nil;result.commands[#result.commands+1]=target;names[commandKey(self,source.name)]={target}
  else target.reminderMinutes=source.reminderMinutes end
  commands[source.id]=target.id
 end
 local function settings(id,guild) return imported.commandGuildSettings and imported.commandGuildSettings[id] and imported.commandGuildSettings[id][guild] end
 local usedIds={};for _,message in ipairs(result.messages) do usedIds[message.id]=true end
 local mappings,claimed,reserved={},{},{}
 for _,source in ipairs(imported.messages or {}) do local targetId=commands[source.commandId];local guild=key(self,source.guildName or self:GetGuildNameByIndex(source.guildIndex))
  for _,localMessage in ipairs(result.messages) do if localMessage.id==source.id and localMessage.commandId==targetId and key(self,localMessage.guildName or self:GetGuildNameByIndex(localMessage.guildIndex))==guild and not localMessage.locked then reserved[localMessage.id]=true end end
 end
 for _,source in ipairs(imported.messages or {}) do
  local targetId=commands[source.commandId];if not targetId then return nil,'Imported message has no command.' end
  local guild=key(self,source.guildName or self:GetGuildNameByIndex(source.guildIndex));local sourceSettings=settings(source.commandId,guild) or {};local sourceSchedule=sourceSettings.schedule or {};local variant=(sourceSchedule.messageVariants or {})[source.id] or 'ALL'
  local oldSettings=result.commandGuildSettings[targetId] and result.commandGuildSettings[targetId][guild] or {};local oldSchedule=oldSettings.schedule or {};local ordinary=sourceSettings.runAt~='SCHEDULED'
  local function sameVariant(oldVariant)
   if oldVariant==variant then return true end
   if sourceSchedule.specialPattern~='EVENT_ROTATION' or oldSchedule.specialPattern~='EVENT_ROTATION' then return false end
   local name;for _,activity in ipairs(sourceSchedule.rotationEvents or {}) do if activity.id==variant then name=activity.name end end
   if not name then return false end
   local sourceCount,oldCount,oldName=0,0
   for _,activity in ipairs(sourceSchedule.rotationEvents or {}) do if activity.name==name then sourceCount=sourceCount+1 end end
   for _,activity in ipairs(oldSchedule.rotationEvents or {}) do if activity.name==name then oldCount=oldCount+1 end;if activity.id==oldVariant then oldName=activity.name end end
   return sourceCount==1 and oldCount==1 and oldName==name
  end
  local target
  for _,message in ipairs(result.messages) do if message.id==source.id and message.commandId==targetId and key(self,message.guildName or self:GetGuildNameByIndex(message.guildIndex))==guild and not claimed[message.id] then target=message;break end end
  if not target then for _,message in ipairs(result.messages) do
   if message.commandId==targetId and key(self,message.guildName or self:GetGuildNameByIndex(message.guildIndex))==guild and message.text==source.text and not claimed[message.id] and not reserved[message.id] and (ordinary or sameVariant((oldSchedule.messageVariants or {})[message.id] or 'ALL')) then target=message;break end
  end end
  if not target then target=copy(source);target.id=unique(usedIds,source.id);target.commandId=targetId;target.useCount=0;target.lastUsedAt=nil;result.messages[#result.messages+1]=target
  elseif not target.locked then target.guildIndex=source.guildIndex;target.guildName=source.guildName;target.text=source.text;if source.name~=nil then target.name=source.name end;if source.displayOrder~=nil then target.displayOrder=source.displayOrder end end
  mappings[source.id]=target.id;claimed[target.id]=true
 end
 for sourceId,guilds in pairs(imported.commandGuildSettings or {}) do
  local id=commands[sourceId];if not id then return nil,'Imported settings have no command.' end
  result.commandGuildSettings[id]=result.commandGuildSettings[id] or {}
  for guild,source in pairs(guilds) do
   local target=result.commandGuildSettings[id][guild] or {};result.commandGuildSettings[id][guild]=target
   local prior=target.schedule
   if source.schedule and (source.schedule.timelineVersion~=1 or source.schedule.mode~='EVENT') then return nil,'Unsupported schedule format. Only Period Timeline schedules can be imported; older schedules are not converted.' end
   for _,field in ipairs(options) do target[field]=copy(source[field]) end
   local slot=self:GetGuildSlotByName(guild)
   if slot and target.lastUsedGuildIndex then
    target.lastUsedGuildIndex=slot
    local prefix=tostring(target.lastUsedParamText or ''):match('^([gGoO]?)[1-5]$')
    if prefix then target.lastUsedParamText=prefix..slot end
   end
   target.disabledMessageIds=target.disabledMessageIds or {}
   for foreignId,localId in pairs(mappings) do
    for _,message in ipairs(result.messages) do if message.id==localId and message.commandId==id and key(self,message.guildName or self:GetGuildNameByIndex(message.guildIndex))==guild and not message.locked then target.disabledMessageIds[localId]=source.disabledMessageIds and source.disabledMessageIds[foreignId] or nil end end
   end
   if source.schedule then
    local schedule=copy(source.schedule)
    local activityMap,available={},{}
    if schedule.specialPattern=='EVENT_ROTATION' then
     for _,activity in ipairs(schedule.rotationEvents or {}) do
      local match;local matches=0;local sourceCount=0
      for _,candidate in ipairs(schedule.rotationEvents) do if candidate.name==activity.name then sourceCount=sourceCount+1 end end
      for _,old in ipairs(prior and prior.rotationEvents or {}) do
       if old.id==activity.id then match=old;matches=1;break end
       if old.name==activity.name then match=old;matches=matches+1 end
      end
      local original=activity.id
      if match and matches==1 and sourceCount==1 and not available[match.id] then activity.id=match.id end
      available[activity.id]=true;activityMap[original]=activity.id
     end
    end
    local variants=copy(prior and prior.messageVariants or {})
    if schedule.specialPattern=='EVENT_ROTATION' then for mid,variant in pairs(variants) do
     if variant~='ALL' and not available[variant] then
      local locked=false;for _,message in ipairs(result.messages) do if message.id==mid then locked=message.locked==true end end
      if not locked then variants[mid]='ALL' end
     end
    end end
    for mid,variant in pairs(schedule.messageVariants or {}) do variants[mappings[mid] or mid]=activityMap[variant] or variant end;schedule.messageVariants=variants
    schedule.importantTimes=schedule.importantTimes or {};for name,mark in pairs(prior and prior.importantTimes or {}) do if not schedule.importantTimes[name] then schedule.importantTimes[name]=copy(mark) end end
    local rowIds={}
    for _,row in ipairs(schedule.reminders or {}) do
     local matches={}
     for _,old in ipairs(prior and prior.reminders or {}) do if old.id==row.id then matches={old};break end;if old.label==row.label and equal(old.start,row.start) and equal(old.finish,row.finish) and old.once==row.once then matches[#matches+1]=old end end
     if #matches==1 and not rowIds[matches[1].id] then row.id=matches[1].id end
     if rowIds[row.id] then row.id=unique(rowIds) else rowIds[row.id]=true end
     local selected={};local pool={}
     for _,mid in ipairs(row.messageIds or {}) do local localId=mappings[mid];if localId and not selected[localId] then pool[#pool+1]=localId;selected[localId]=true end end
     if #matches==1 then for _,mid in ipairs(matches[1].messageIds or {}) do for _,message in ipairs(result.messages) do if message.id==mid and message.locked and not selected[mid] then pool[#pool+1]=mid;selected[mid]=true end end end end
     row.messageIds=pool
    end
    -- A transfer updates configuration, never another player's runtime history.
    schedule.timelineUsage=copy(prior and prior.timelineUsage or {});schedule.availabilityUsage=copy(prior and prior.availabilityUsage or {})
    schedule.completedOccurrences=copy(prior and prior.completedOccurrences or {})
    schedule.nextDueAt=nil;schedule.nextDuePhase=nil;schedule.nextDueOccurrence=nil
    target.schedule=schedule
   end
  end
 end
 for sourceId,guilds in pairs(imported.chatChannels or {}) do local id=commands[sourceId];if id then result.chatChannels[id]=result.chatChannels[id] or {};for guild,channel in pairs(guilds) do result.chatChannels[id][guild]=channel end end end
 local globalRecords={defaultGuildIndex='DEFAULT',revertChatSeconds='GENERALREVERT',schedulingTimeZone='GENERALTIMEZONE',statusPanelState='STATUSPANEL'}
 for field,record in pairs(globalRecords) do if imported._presentGlobals and imported._presentGlobals[record] or not imported._presentGlobals and imported[field]~=nil then result[field]=copy(imported[field]) end end
 result.guildSchedulingTimeZones=result.guildSchedulingTimeZones or {};for guild,zone in pairs(imported.guildSchedulingTimeZones or {}) do result.guildSchedulingTimeZones[guild]=zone end
 result._presentGlobals=nil;return result
end
local apply=S.ApplyImportedSettings
function S:ApplyImportedSettings(imported)
 local merged,reason=self:MergeImportedSettings(imported);if not merged then return false,reason end
 return apply(self,merged)
end
