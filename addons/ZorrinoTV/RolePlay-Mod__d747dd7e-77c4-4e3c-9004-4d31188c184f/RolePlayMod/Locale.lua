-- Client-language boundary. Internal quest/save identities remain canonical.
-- The game APIs and other addons are never replaced globally.
RPM_LOCALE={language=type(GetCVar)=='function' and string.lower(GetCVar('language.2') or 'fr') or 'fr'}
local L=RPM_LOCALE
-- This package carries only the French catalogue.
L.english=false
L.forward={};L.reverse={};L.names={};L.authored={};L.normalized={}
local function clean(text)
    return (text:gsub('%^%a+',''):gsub('\\n','\n'))
end
local function normalize(text)
    text=clean(text):gsub('’',"'"):gsub(' ',' ')
    if type(zo_strlower)=='function' then text=zo_strlower(text) else text=string.lower(text) end
    local accents={['à']='a',['â']='a',['ä']='a',['é']='e',['è']='e',['ê']='e',['ë']='e',['î']='i',['ï']='i',['ô']='o',['ö']='o',['ù']='u',['û']='u',['ü']='u',['ç']='c'}
    for a,b in pairs(accents) do text=text:gsub(a,b) end
    return (text:gsub('^%s+',''):gsub('%s+$',''))
end
function L.Canonical(text)
    if not L.english or type(text)~='string' then return text end
    local value=clean(text)
    return L.reverse[value] or L.normalized[normalize(value)] or value
end
L.NormalizeName=normalize
-- Wrappers read the current API on every call; missing/optional APIs stay nil.
local fields={
 GetJournalQuestInfo={1,2,3,5},GetJournalQuestName={1},GetQuestName={1},
 GetJournalQuestEnding={1,6},GetJournalQuestStepInfo={1,4},GetJournalQuestConditionInfo={1},GetJournalQuestLocationInfo={1,2},
 GetUnitName={1},GetUnitCaption={1},GetUnitRace={1},GetZoneName={1},GetZoneNameById={1},GetZoneNameByIndex={1},
 GetMapName={1},GetPlayerLocationName={1},GetPlayerActiveSubzoneName={1},GetFastTravelNodeInfo={2},
 GetPOIInfo={1,3,4},GetMapLocation={1},GetGameCameraInteractableName={1},GetOfferedQuestInfo={1},
 GetChatterGreeting={1},GetChatterOption={1},GetQuestToolInfo={1},GetJournalQuestToolInfo={1},GetQuestItemInfo={1},
}
local wrappers={}
for key,positions in pairs(fields) do
    local name,indices=key,positions
    wrappers[name]=function(...)
        local values={n=0}
        local function pack(...) values={n=select('#',...),...} end
        pack(_G[name](...))
        local questId
        if name:find('^GetJournalQuest') and type(_G.GetJournalQuestId)=='function' then questId=_G.GetJournalQuestId(select(1,...)) end
        for _,i in ipairs(indices) do
            if not (name=='GetUnitName' and select(1,...)=='player') then values[i]=L.Canonical(values[i],questId) end
        end
        return unpack(values,1,values.n)
    end
end
-- Each addon chunk opts into this environment. Native functions keep _G.
L.environment=setmetatable({}, {__index=function(_,key)
    if wrappers[key] and type(_G[key])=='function' then return wrappers[key] end
    return _G[key]
end,__newindex=_G})
function L.Text(text) return text end -- replaced by LocaleDisplay on EN clients
