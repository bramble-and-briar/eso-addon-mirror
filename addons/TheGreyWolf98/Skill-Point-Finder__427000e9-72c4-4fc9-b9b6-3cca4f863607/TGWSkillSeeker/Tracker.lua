local M=TGWSS
M.categories={"Dungeons","DLC dungeons","Zones","Cyrodiil","Imperial City","PvP","Public dungeons","Other"}
function M.CharId() return tostring(GetCurrentCharacterId()) end
function M.Clean(s)return zo_strformat("<<1>>",s or "")end
function M.QuestDone(id)
 local name=GetCompletedQuestInfo(id)
 return type(name)=="string" and name~=""
end
function M.Name(zone)return M.Clean(GetZoneNameById(zone))end
function M.Tasks()
 local tasks={}
 local function Add(fn)tasks[#tasks+1]=fn end
 for _,r in ipairs(M.catalog.dungeons)do
  local d=r;Add(function(s)
   local cat=d.dlc and 2 or 1
   s.rows[cat][#s.rows[cat]+1]={name=M.Name(d.zone),done=M.QuestDone(d.quest) and 1 or 0,total=1,detail="Skill-point quest: "..M.Clean(GetQuestName(d.quest)),quest=d.quest,zone=d.zone}
  end)
 end
 for _,r in ipairs(M.catalog.zones)do
  local z=r;Add(function(s)
   local cat=z.zone==181 and 4 or z.zone==584 and 5 or 3
   local done=0;local details={}
   for _,id in ipairs(z.quests)do local complete=M.QuestDone(id);if complete then done=done+1 end;details[#details+1]=(complete and "[Done] " or "[Missing] ")..M.Clean(GetQuestName(id))end
   local acquired=0;local count=GetNumSkyshardsInZone(z.zone)
   for i=1,count do if GetSkyshardDiscoveryStatus(GetZoneSkyshardId(z.zone,i))==SKYSHARD_DISCOVERY_STATUS_ACQUIRED then acquired=acquired+1 end end
   s.shards=s.shards+acquired;s.shardTotal=s.shardTotal+count
   s.rows[cat][#s.rows[cat]+1]={name=M.Name(z.zone),done=done,total=#z.quests,shards=acquired,shardTotal=count,detail=table.concat(details,"\n"),zone=z.zone}
  end)
 end
 for _,r in ipairs(M.catalog.public)do
  local p=r;Add(function(s)s.rows[7][#s.rows[7]+1]={name=M.Name(p.zone),done=IsAchievementComplete(p.achievement) and 1 or 0,total=1,detail="Character-specific public-dungeon GROUP EVENT skill point.",zone=p.zone}end)
 end
 Add(function(s)local rank=GetUnitAvARank("player");s.rows[6][1]={name="Alliance Rank",done=rank,total=50,detail="Skill points awarded by Alliance Rank; AP balance is not used."}end)
 Add(function(s)local done=0;for _,id in ipairs(M.catalog.main)do if M.QuestDone(id)then done=done+1 end end;s.rows[8][1]={name="The Harbourage",done=done,total=#M.catalog.main,detail="Completed quest history for this character."};local level=GetUnitLevel("player");s.rows[8][2]={name="Character levels",done=math.floor(level/5)+math.floor(level/10)+level-1,total=64,detail="Level-based skill-point awards."};s.rows[8][3]={name="Infinite Archive introduction",done=M.QuestDone(7061) and 1 or 0,total=1,detail="Introductory quest reward."};s.rows[8][4]={name="Tutorial / Folium / other exceptional rewards",unknown=true,detail="Excluded from totals: cannot reliably infer these optional or legacy rewards."}end)
 return tasks
end
function M.CancelScan()M.generation=(M.generation or 0)+1;EVENT_MANAGER:UnregisterForUpdate(M.name.."Scan");M.scanning=false end
function M.Scan()
 M.CancelScan();local gen=M.generation;local id=M.CharId();local tasks=M.Tasks();local index=0
 local s={id=id,name=M.Clean(GetUnitName("player")),availablePoints=GetAvailableSkillPoints(),rows={},shards=0,shardTotal=0,updated=GetTimeStamp(),version=M.version}
 for i=1,#M.categories do s.rows[i]={}end
 M.scanning=true;M.scanProgress=0
 EVENT_MANAGER:RegisterForUpdate(M.name.."Scan",40,function()
  if gen~=M.generation or id~=M.CharId()then return end
  -- Two bounded catalogue records per update, never a whole login scan in one frame.
  for _=1,2 do index=index+1;if tasks[index] then tasks[index](s)else
   for _,rows in ipairs(s.rows)do table.sort(rows,function(a,b)return a.name<b.name end)end
   M.db.characters[id]=s;M.CancelScan();M.scanProgress=100;if M.render then M.render()end;return
  end end
  M.scanProgress=math.floor(index/#tasks*100);if M.render then M.render()end
 end)
end
function M.Characters()
 local chars={};for i=1,GetNumCharacters()do local name,_,_,_,_,_,id=GetCharacterInfo(i);id=tostring(id);chars[#chars+1]={id=id,name=M.Clean(name),scanned=M.db.characters[id]~=nil}end
 table.sort(chars,function(a,b)return a.name<b.name end);return chars
end
EVENT_MANAGER:RegisterForEvent(M.name,EVENT_ADD_ON_LOADED,function(_,name)
 if name~=M.name then return end;EVENT_MANAGER:UnregisterForEvent(M.name,EVENT_ADD_ON_LOADED)
 M.db=ZO_SavedVars:NewAccountWide("TGWSkillSeekerSavedVariables",1,GetWorldName(),{characters={}})
 -- Preserve existing character snapshots while updating the release label.
 for _,snapshot in pairs(M.db.characters)do
  for _,row in ipairs(snapshot.rows and snapshot.rows[8] or {})do
   if row.name=="Main story quests"then row.name="The Harbourage"end
  end
 end
 SLASH_COMMANDS["/spf"]=function()M.Open()end;SLASH_COMMANDS["/tgwsp"]=SLASH_COMMANDS["/spf"];SLASH_COMMANDS["/skillseeker"]=SLASH_COMMANDS["/spf"]
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_ACTIVATED,function()M.active=true;M.activation=(M.activation or 0)+1;local token=M.activation;zo_callLater(function()if M.active and token==M.activation then M.Scan()end end,1500)end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_PLAYER_DEACTIVATED,function()M.active=false;M.activation=(M.activation or 0)+1;M.CancelScan();EVENT_MANAGER:UnregisterForUpdate(M.name.."Debounce")end)
 local function RefreshLater()if not M.active then return end;EVENT_MANAGER:UnregisterForUpdate(M.name.."Debounce");EVENT_MANAGER:RegisterForUpdate(M.name.."Debounce",1000,function()EVENT_MANAGER:UnregisterForUpdate(M.name.."Debounce");if M.active then M.Scan()end end)end
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_QUEST_REMOVED,function(_,complete)if complete then RefreshLater()end end)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_SKYSHARDS_UPDATED,RefreshLater)
 EVENT_MANAGER:RegisterForEvent(M.name,EVENT_ACHIEVEMENT_UPDATED,RefreshLater)
end)
