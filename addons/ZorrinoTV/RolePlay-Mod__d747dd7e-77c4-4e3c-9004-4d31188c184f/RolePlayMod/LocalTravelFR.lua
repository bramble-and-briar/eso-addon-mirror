-- Public departures read from the current client map, not an inferred route graph.
local B=IHR_Runtime.Beta
local D=B.Dice
local G=B.GeographicKnowledge
local T={};B.LocalTravelFR=T
local function norm(s) return B.Normalize(s or '') end
local function bare(s) return norm(s):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','') end
local function mentions(s,name) return (' '..norm(s)..' '):find(' '..bare(name)..' ',1,true)~=nil end
local function point(x,y) return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 end
local function destinationMention(text,goal)
 local n=' '..norm(text)..' '
 for _,name in ipairs({goal.name,goal.region}) do
  local target=bare(name)
  for _,prefix in ipairs({' vers ',' pour ',' a destination de ',' a destination du ',' a destination des '}) do
   local start=1
   while true do
    local _,last=n:find(prefix,start,true);if not last then break end
    local tail=n:sub(last+1):gsub('^la ',''):gsub('^le ',''):gsub('^les ','')
    if (' '..tail):find(' '..target..' ',1,true)==1 then return true end
    start=last+1
   end
  end
 end
 return false
end
local function originRegion()
 local r=D.Region(GetUnitZoneIndex('player'))
 return r and r.name
end
function T.Goal(task)
 local target=D.TargetForTask(task)
 if not target then return end
 local named=D.JournalDestinationFR and D.JournalDestinationFR(task,target)
 if named then
  local place=G.Place(named,task) or B.PublicPlace(named)
  if place and (place.zone or place.region) then return {name=named,region=place.zone or place.region} end
 end
 if target.region then return {name=target.name,region=target.region} end
 if target.kind=='place' then
  local public=B.PublicPlace(target.name)
  if public and public.entityType=='region' then return {name=target.name,region=target.name} end
  if public and public.region then return {name=target.name,region=public.region} end
 end
 local goal=B.RegionalTravel and B.RegionalTravel.Goal(task)
 if goal then return goal end
end
function T.Departure(goal)
 if type(GetNumMapLocations)~='function' or type(GetMapLocationTooltipHeader)~='function'
  or type(GetMapLocationIcon)~='function' or type(IsMapLocationVisible)~='function' then return end
 if ZO_WorldMap and not ZO_WorldMap:IsHidden() then return end
 SetMapToPlayerLocation()
 local px,py=GetMapPlayerPosition('player')
 if not point(px,py) then return end
 local navigator,navigatorDistance
 for i=1,GetNumMapLocations() do
  if IsMapLocationVisible(i) then
   local header=GetMapLocationTooltipHeader(i)
   local text=header or ''
   if type(GetNumMapLocationTooltipLines)=='function' and type(GetMapLocationTooltipLineInfo)=='function' then
    for j=1,GetNumMapLocationTooltipLines(i) do
     if type(IsMapLocationTooltipLineVisible)~='function' or IsMapLocationTooltipLineVisible(i,j) then
      local _,line=GetMapLocationTooltipLineInfo(i,j)
      if type(line)=='string' then text=text..' '..line end
     end
    end
   end
   local n=norm(text)
   local travel=n:find('voyage',1,true) or n:find('bateau vers',1,true) or n:find('caravane vers',1,true)
    or n:find('passage vers',1,true) or n:find('portail vers',1,true)
   if travel and destinationMention(text,goal) then
    local _,x,y=GetMapLocationIcon(i)
    if point(x,y) then
     local where=(x-px)^2+(y-py)^2<.000009 and 'tout près d’ici' or (B.Bearing(x-px,y-py)..' d’ici')
     return 'Vous trouverez un départ pour '..goal.region..' '..where..'.'
       ..(bare(goal.name)~=bare(goal.region) and (' Une fois dans la région, renseignez-vous sur le chemin de '..goal.name..'.') or ''),
       'Client FR : départ visible « '..(header or goal.region)..' »',header
    end
   end
   -- A visible navigator is a credible place to ask, not proof that a direct
   -- boat or caravan exists to this particular destination.
   if n:find('navigateur',1,true) or n:find('navigatrice',1,true) then
    local _,x,y=GetMapLocationIcon(i)
    if point(x,y) then
     local distance=(x-px)^2+(y-py)^2
     if not navigatorDistance or distance<navigatorDistance then
      local name=B.Name(header or '')
      if name~='' then
       local where=distance<.000009 and 'tout près d’ici' or (B.Bearing(x-px,y-py)..' d’ici')
       if norm(name)=='navigateur' then name='un navigateur' elseif norm(name)=='navigatrice' then name='une navigatrice' end
       navigator='Cherchez '..name..', '..where..'. Demandez quel passage pourrait vous rapprocher de '..goal.region..'.'
       navigatorDistance=distance
      end
     end
    end
   end
  end
 end
 if navigator then return navigator,'Client FR : navigateur visible sur la carte' end
end
function T.Subject(task)
 local goal=T.Goal(task);local origin=originRegion()
 if not goal or not origin or bare(origin)==bare(goal.region) then return end
 local answer,source=T.Departure(goal)
 return D.GeographicScopeFR({task=task,title=task.quest.name,key=task.key..':native-travel:'..bare(origin)..':'..bare(goal.name),
  kind='transport',transport=true,localTravel122=true,target=goal.name,targetKind='place',destination=goal.name,
  question=D.GeographicQuestionFR({name=goal.name,kind='place'}),answer=answer,source=source,
  unresolved=not answer,level=1})
end
local subjects=D.Subjects
function D.Subjects(index)
 local result=subjects(index);local seen={}
 for _,s in ipairs(result) do seen[s.key]=true end
 for _,task in ipairs(D.Tasks(index)) do
  local travel=T.Subject(task)
  if travel and not seen[travel.key] and not D.Saved().hints[travel.key] then
   local replaced=false
   for i=#result,1,-1 do
    local s=result[i]
    if s.task and s.task.key==task.key and s.targetKind=='place' and bare(s.target)==bare(travel.target) then
     table.remove(result,i);replaced=true
    end
   end
   table.insert(result,1,travel)
  end
 end
 return result
end
local refresh=D.RefreshSubject
function D.RefreshSubject(s)
 if s and s.localTravel122 then
  local task=D.Fresh(s.task);if not task then return end
  local next=T.Subject(task)
  if next and next.key==s.key then return next end
  return
 end
 return refresh(s)
end
local followups=D.Followups
function D.Followups(s)
 local result=followups(s)
 if not s or not s.task then return result end
 local task=D.Fresh(s.task)
 local travel=task and T.Subject(task)
 if travel and travel.key~=s.key and not D.Saved().hints[travel.key] then
  if B.LearnedQuestions then B.LearnedQuestions.Decorate(travel,(s.inquiryDepth or 1)+1) end
  for i=#result,1,-1 do
   local other=result[i].subject
   if other and other.targetKind=='place' and bare(other.target)==bare(travel.target) then table.remove(result,i) end
  end
  result[#result+1]={subject=travel,text=D.InquiryLabel(travel,travel.question)}
 end
 return result
end
