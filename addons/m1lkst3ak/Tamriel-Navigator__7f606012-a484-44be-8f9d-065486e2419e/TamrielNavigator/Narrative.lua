-- Narrative continuity using the attributed AdventureData directory and existing lore.
local N=TamrielNavigator
local function clean(v) return tostring(v or ''):gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('%^%a+',''):gsub('%s+',' '):match('^%s*(.-)%s*$') end
local function done(N,id)
 if N.ch and N.ch.quests[id] then return true end
 if type(HasCompletedQuest)=='function' then local ok,v=pcall(HasCompletedQuest,id); return ok and v==true end
 return false
end
function N:narrative(q,kind)
 if kind~='New quest' and kind~='Recap' then return q.context end
 self.s.narrative=self.s.narrative or {people={},notes={},recaps={}}
 local history=self.s.narrative
 history.bios=history.bios or {}
 local cached=history.recaps[q.id]
 if kind=='Recap' and cached then return cached~='' and cached:gsub('Recorded quest contact: [^%.]+%.%s*','') or nil end
 local candidates={}; for g in pairs(NavigatorQuestContacts[q.id] or {}) do local name=clean(NavigatorQuestGivers[g]); if name~="" and name~="Prologue" then candidates[g]=name end end; local giver,key,count=nil,nil,0
 for k,v in pairs(candidates) do giver,key=v,k; count=count+1 end
 if count~=1 then giver,key=nil,nil end
 local target=self.adventureTarget
 if target and target.id==q.id and count>1 then
  for k,v in pairs(candidates) do if v==target.giver then giver,key=v,k; break end end
 end
 local parts={}; local person=key and history.people[key]
 if giver then
  if person and person.last~=q.id then
   local prior=NavigatorQuestNames[person.last]
   parts[#parts+1]='You have met '..giver..(prior and (' during '..clean(prior)) or ' before')..'.'
  elseif not NavigatorNPCResearch[key] then parts[#parts+1]='Your adventure begins with '..giver..'.' end
 end
 local bio=key and NavigatorNPCResearch[key]
 local bioKey=giver and giver:lower()
 if bio and not history.bios[bioKey] then
  parts[#parts+1]=bio
  if kind=='New quest' then history.bios[bioKey]=true end
 end
 local mission=NavigatorQuestResearch[q.id]
 if mission and not q.bg:lower():find(mission:lower(),1,true) then parts[#parts+1]=mission end
 local previous
 for _,id in ipairs(NavigatorQuestPrerequisites[q.id] or {}) do
  if done(self,id) and NavigatorQuestNames[id] then previous=clean(NavigatorQuestNames[id]); break end
 end
 if previous then parts[#parts+1]='This assignment follows your completed adventure, '..previous..'.' end
 local hay=(q.name..' '..q.bg..' '..(giver or '')):lower()
 local added=0
 for _,list in ipairs({NavigatorLore or {},NavigatorThemes or {}}) do
  for _,note in ipairs(list) do
   if not bio and not mission and added<1 and hay:find(note[1],1,true) and not history.notes[note[1]] then
    parts[#parts+1]=note[2]; added=added+1
    if kind=='New quest' then history.notes[note[1]]=true end
   end
  end
 end
 local result=table.concat(parts,' '):gsub('Recorded quest contact: [^%.]+%.%s*','')
 if kind=='New quest' then
  if key then history.people[key]={last=q.id} end
  history.recaps[q.id]=result
 end
 return result~='' and result or nil
end
