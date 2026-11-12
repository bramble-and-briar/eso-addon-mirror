if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Verified NPC race lookup: client first, then exact names from a global source-backed catalogue.
local B=IHR_Runtime.Beta
local R={};B.NpcRaces=R
local index=B.CompactCatalogue
local byName,byTitledName={},{}
local function norm(text) return B.Normalize(type(text)=='string' and text or '') end
local function bare(text) return norm(text):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','') end
-- ESO can prepend a grammatical article to a titled NPC name.
-- Preserve the title itself and do not strip words from arbitrary proper names.
local titles={capitaine=true,commandant=true,commandante=true,lieutenant=true,lieutenante=true,
    guerrier=true,guerriere=true,warrior=true,chaman=true,chamane=true,shaman=true,
    sergent=true,sergente=true,general=true,generale=true,amiral=true,amirale=true,
    roi=true,reine=true,prince=true,princesse=true,duc=true,duchesse=true,comte=true,comtesse=true,
    baron=true,baronne=true,seigneur=true,dame=true,maitre=true,maitresse=true,conservateur=true,conservatrice=true,
    prophete=true,pretre=true,pretresse=true,aldarque=true,archimage=true,ambassadeur=true,ambassadrice=true,
    grand=true,grande=true,haut=true,haute=true,vice=true,chef=true,oracle=true,frere=true,soeur=true,
    captain=true,commander=true,king=true,queen=true,prince=true,princess=true,lord=true,lady=true,
    duke=true,duchess=true,count=true,countess=true,baron=true,baroness=true,master=true,mistress=true,
    general=true,admiral=true,sergeant=true,prophet=true,priest=true,priestess=true,high=true,grand=true}
local function titledKey(key)
    local without=key:gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ',''):gsub('^the ','')
    local first=without:match('^([^ ]+)')
    if titles[first] then return without end
    return key
end
function R.NameKey(text) return titledKey(norm(text)) end
local generic={garde=true,guard=true,soldat=true,soldate=true,soldier=true,guerrier=true,guerriere=true,warrior=true,
    citoyen=true,citoyenne=true,citizen=true,villageois=true,villageoise=true,villager=true,marchand=true,marchande=true,merchant=true,
    habitant=true,habitante=true,refugie=true,refugiee=true,refugee=true,client=true,patron=true,customer=true,
    serviteur=true,servante=true,servant=true,travailleur=true,travailleuse=true,worker=true,ouvrier=true,ouvriere=true,
    voyageur=true,voyageuse=true,traveler=true,traveller=true,pelerin=true,pelerine=true,pilgrim=true,
    prisonnier=true,prisonniere=true,prisoner=true,bandit=true,pirate=true,noble=true,mage=true,
    aubergiste=true,innkeeper=true,recrue=true,recruit=true,aventurier=true,aventuriere=true,adventurer=true}
local function Generic(name)
    name=bare(name):gsub('^the ','')
    if generic[name] then return true end
    for _,prefix in ipairs({'garde de ','garde du ','garde des ','soldat du ','soldat de ','soldat des ','aldmeri soldier','dominion guard','elden root guard'}) do
        if name:sub(1,#prefix)==prefix then return true end
    end
    return false
end
for _,record in ipairs(IHR_NpcRaceData.records) do
    local seen,seenTitles={},{}
    for _,name in ipairs(record.names) do
        local key=norm(name)
        if key~='' and not seen[key] then
            index.Add(byName,key,record);seen[key]=true
        end
        local titled=titledKey(key)
        if titled~='' and not seenTitles[titled] then
            index.Add(byTitledName,titled,record);seenTitles[titled]=true
        end
    end
end
function R.TitledRecords(name) return index.Records(byTitledName[R.NameKey(name)]) end
function R.ScopeMatches(record, locality, region)
    local localMatch,regionMatch
    for _,place in ipairs(record.scopes or {}) do
        local key=bare(place)
        if key~='' then
            if key==locality then localMatch=true end
            if key==region then regionMatch=true end
        end
    end
    return localMatch,regionMatch
end
function R.Context(npc)
    local region
    if type(B.SocialZone)=='function' then local _,zone=B.SocialZone(npc);region=zone end
    return {region=bare(region),locality=bare(npc and npc.locality)}
end
function R.Find(name,context)
    if Generic(name) then return nil,'generique' end
    local key=norm(name)
    local candidates=byName[key] or byTitledName[titledKey(key)]
    local match,race,ambiguous
    for _,record in index.Records(candidates) do
        if race and race~=record.raceKey then ambiguous=true end
        match=match or record;race=record.raceKey
    end
    -- A name whose documented occurrences all share the same race needs no geographic guess.
    if match and not ambiguous then return match,'catalogue' end
    if not match then return nil,'absent' end
    if type(context)=='string' then context={region=bare(context)} end
    context=context or {}
    local best,score,bestRace,tied=nil,0,nil,false
    local locality,region=bare(context.locality),bare(context.region)
    for _,record in index.Records(candidates) do
        local rank=0
        local localMatch,regionMatch=R.ScopeMatches(record,locality,region)
        if localMatch and regionMatch then rank=3
        elseif regionMatch then rank=2
        elseif localMatch then rank=1 end
        if rank>score then best=record;score=rank;bestRace=record.raceKey;tied=false
        elseif rank>0 and rank==score and bestRace~=record.raceKey then tied=true end
    end
    if best and not tied then return best,'catalogue' end
    return nil,'ambigu'
end
function R.Resolve(npc,unitTag)
    if not npc then return end
    local native=npc.race
    if npc.raceSource=='catalogue' or npc.raceSource=='client-identifiant' or npc.raceSource=='contexte-local' then native=npc.raceClient end
    native=type(native)=='string' and native or ''
    npc.raceClient=native;npc.raceReference=nil;npc.raceReferenceRevision=nil;npc.raceStatus=nil
    if norm(native)~='' then npc.race=native;npc.raceSource='client';return native end
    local id=0
    if type(GetUnitRaceId)=='function' then
        local ok,value=pcall(GetUnitRaceId,unitTag)
        if ok and type(value)=='number' then id=value end
    end
    npc.raceIdClient=id
    if id>0 and type(GetRaceName)=='function' then
        local gender=type(GetUnitGender)=='function' and GetUnitGender(unitTag) or 0
        local ok,name=pcall(GetRaceName,gender,id)
        if ok and type(name)=='string' and norm(name)~='' then npc.race=B.Name(name);npc.raceSource='client-identifiant';return npc.race end
    end
    local record,status=R.Find(npc.name,R.Context(npc))
    npc.raceStatus=status
    if record then
        npc.race=record.race;npc.raceSource='catalogue';npc.raceReference=record.source;npc.raceReferenceRevision=record.revision
        return npc.race
    end
    -- User-defined fallback for the named clan warriors/shaman at Mordécorce.
    -- Native race and exact sourced identities above always take priority.
    local context=R.Context(npc)
    local locality=context.locality
    local clan=context.region=='bois de graht' and (locality=='mordecorce' or locality=='forteresse mordecorce'
        or locality=='forteresse de mordecorce' or locality=='promontoire de reman' or locality=='longere du chef')
    local role=R.NameKey(npc.name):match('^([^ ]+) .+')
    if clan and ({guerrier=true,guerriere=true,warrior=true,chaman=true,chamane=true,shaman=true})[role] then
        npc.race='Orque';npc.raceSource='contexte-local';npc.raceStatus='clan-mordecorce'
        npc.raceReference='Clan orque de Mordécorce : règle locale demandée par le joueur'
        return npc.race
    end
    npc.race='';npc.raceSource=nil
end
