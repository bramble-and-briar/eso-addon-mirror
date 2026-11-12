-- Select a named source alternative from THIS quest's evidence, never race/banner.
local B=IHR_Runtime.Beta
local D=B.Dice
local C={groups={}}
B.GuildRoutesFR=C
local scope={}
for _,ids in ipairs({RPM_GuildReviewedQuestIds or {},RPM_VestigeReviewedQuestIds or {}}) do
    for _,id in ipairs(ids) do scope[id]=true end
end
local function norm(value) return B.Normalize(value or '') end
local function bare(value) return norm(value):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','') end
local function mentions(text,name) return (' '..norm(text)..' '):find(' '..bare(name)..' ',1,true)~=nil end
for _,rows in ipairs({RPM_GuildGeographyFR or {},RPM_VestigeGeographyFR or {}}) do
for _,row in ipairs(rows) do if row.routeGroup then
    local group=C.groups[row.routeGroup] or {};C.groups[row.routeGroup]=group
    group[row.routeCity]={city=row.routeCity,region=row.routeRegion}
end end
end
local function store()
    if not B.saved then return end
    B.saved.guildRoutes122=B.saved.guildRoutes122 or {}
    return B.saved.guildRoutes122
end
function C.Evidence(task,group)
    if not task or not C.groups[group] then return end
    local id=type(GetJournalQuestId)=='function' and GetJournalQuestId(task.index)
    if not id then return end
    local frame=type(GetFrameTimeMilliseconds)=='function' and GetFrameTimeMilliseconds() or 0
    local data=store();if not data then return end
    local cache=C.last
    if cache and cache.task==task and cache.frame==frame and cache.group==group and cache.data==data then return cache.city end
    local meta=D.Metadata(task)
    local city,conflict
    local function choose(name)
        if city and bare(city)~=bare(name) then conflict=true else city=name end
    end
    for _,route in pairs(C.groups[group]) do
        -- The current condition's map/region is authoritative, including a
        -- guildhall interior; the player's present map is never substituted.
        if meta and ((meta.mapName and mentions(meta.mapName,route.city)) or
            (meta.region and bare(meta.region)==bare(route.region))) then choose(route.city) end
        -- Only a current intended-action clause can supplement native metadata.
        for clause in (task.stepText or ''):gmatch('[^%.!%?\n]+') do
            local key=norm(clause)
            if (key:find('je dois ',1,true) or key:find('je devrais ',1,true) or key:find('il me faut ',1,true))
                and mentions(clause,route.city) then choose(route.city) end
        end
    end
    local key=tostring(id)..':'..group
    if conflict then city=nil;data[key]=nil
    elseif city then data[key]={city=city,quest=id,group=group,source='Client FR : destination de cette quête',time=GetTimeStamp()}
    else
        -- A record learned during this same quest may locate its return phase.
        -- It is never copied from another guild quest or another character.
        local previous=data[key]
        if previous and previous.quest==id and previous.group==group and C.groups[group][previous.city] then city=previous.city end
    end
    C.last={task=task,group=group,frame=frame,city=city,data=data}
    return city
end
function D.LocalGeographyRouteMatchesFR(task,row)
    if not row.routeGroup then return true end
    return bare(C.Evidence(task,row.routeGroup))==bare(row.routeCity)
end
function C.WitnessOnRoute(task,row)
    if not row.routeCity then return true end
    if B.Here(row.routeCity) then return true end
    local meta=D.Metadata(task)
    return meta and meta.mapId and type(GetCurrentMapId)=='function' and meta.mapId==GetCurrentMapId()
        and bare(meta.mapName)~=bare(meta.region) and bare(meta.mapName)~='tamriel'
        and bare(meta.region)==bare(row.routeRegion) or false
end
function D.RestrictGeographicBiographyFR(task,target)
    local id=type(GetJournalQuestId)=='function' and GetJournalQuestId(task.index)
    if not scope[id] or target.kind~='person' then return false end
    -- These recurring quest actors move; an unrelated biography location is
    -- never evidence for the current quest phase.
    for _,actor in ipairs({'Valastë','Shalidor','Haskill','Shéogorath','Œil-Perçant','Aelif','Merric','Jofnir',
        'le Prophète','Lyris','Abnur Tharn','Sai Sahan','Vanus Galérion','Cadwell'}) do
        if mentions(target.name,actor) then return true end
    end
    return false
end
local function literalPattern(value) return (value:gsub('([^%w])','%%%1')) end
function D.MatchNativePhaseFR(task,row)
    if not row.stepTemplate or not row.templateEntity then return false end
    -- Only a single explicitly named source entity can fill a native template.
    local text,count=row.stepTemplate:gsub('<<%d+>>','zznativeentityzz')
    if count~=1 then return false end
    text=norm(text)
    local before,after=text:match('^(.-)zznativeentityzz(.-)$')
    if not before then return false end
    before=before:gsub(' un $',' '):gsub(' une $',' ')
    local actual=norm(task.stepText):match('^'..literalPattern(before)..'(.-)'..literalPattern(after)..'$')
    if not actual then return false end
    local function entity(s) return bare(s):gsub('^un ',''):gsub('^une ','') end
    actual=entity(actual)
    local expected=entity(row.templateEntity)
    return actual==expected or expected=='archimage shalidor' and actual=='shalidor'
end
