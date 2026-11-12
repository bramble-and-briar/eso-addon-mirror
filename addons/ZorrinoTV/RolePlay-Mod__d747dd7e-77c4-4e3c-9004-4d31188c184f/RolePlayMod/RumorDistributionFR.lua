-- Stocks persist per establishment; opening a dialogue never replenishes them.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local W=B.WildernessRumors
local function number(v) return type(v)=='number' and v==v and math.abs(v)<1e12 end
function W.RumorCooldownSeconds()
    local hours=tonumber(R.Options().rumorCooldownHours) or 2
    return math.max(1,math.min(24,math.floor(hours)))*3600
end
function W.RumorVenue()
    -- Only venues actually registered by the hospitality system are separated.
    -- A city/subzone or the speaker's name alone cannot identify an inn.
    if type(GetUnitWorldPosition)=='function' then
        local zone,x,y,z=GetUnitWorldPosition('player')
        if number(zone) and zone>0 and number(x) and number(y) and number(z) then
            local nearest,distance
            for _,v in ipairs(B.saved.hospitalityVenues or {}) do
                if v.zone==zone and number(v.x) and number(v.y) and number(v.z) then
                    local d=(x-v.x)^2+(y-v.y)^2+(z-v.z)^2
                    if d<=1000000 and (not distance or d<distance) then nearest,distance=v,d end
                end
            end
            if nearest then
                return string.format('venue:%d:%.0f:%.0f:%.0f',zone,nearest.x,nearest.y,nearest.z),false
            end
        end
    end
    -- No guessed division by coordinate cells: all unidentifiable venues share
    -- this persistent fallback, including when world coordinates are unavailable.
    return 'shared-unidentified',true
end
local function stock(npc)
    B.saved.rumorStocks23=B.saved.rumorStocks23 or {}
    local key,fallback=W.RumorVenue()
    local venue=B.saved.rumorStocks23[key]
    if not venue then venue={speakers={},heard={},cycle=1};B.saved.rumorStocks23[key]=venue end
    local now=GetTimeStamp()
    if venue.lastHeard and now-venue.lastHeard>=W.RumorCooldownSeconds() then
        venue.speakers={};venue.heard={};venue.lastHeard=nil;venue.cycle=venue.cycle+1
    end
    local speakerKey=B.Profile(npc).key
    local speaker=venue.speakers[speakerKey]
    if not speaker then speaker={count=0};venue.speakers[speakerKey]=speaker end
    return venue,speaker,key,fallback
end
function B.KnownRumors(npc)
    if not npc or not B.HospitalityContext(npc) then return {} end
    local venue,speaker,key,fallback=stock(npc)
    local maximum=B.IsPublican(npc) and 2 or 1
    speaker.maximum=maximum
    local profile=B.Profile(npc);local pool={}
    local candidates,progress=W.Candidates(npc)
    for _,r in ipairs(candidates) do
        local seed=B.Hash(profile.key..':voyage:'..r.quest..':'..key..':'..venue.cycle)
        pool[#pool+1]={rumor=r,order=B.Hash(tostring(seed)..':'..r.quest..':'..profile.key)}
    end
    table.sort(pool,function(a,b) return a.order<b.order or a.order==b.order and a.rumor.quest<b.rumor.quest end)
    local result={};local regionalRemaining,venueRemaining=0,0
    for _,item in ipairs(pool) do
        local r=item.rumor
        if not W.QuestKnown(r.quest) then
            regionalRemaining=regionalRemaining+1
            if not venue.heard[tostring(r.quest)] then
                venueRemaining=venueRemaining+1
                if #result<maximum-speaker.count and W.KnowsRumor(npc,r,venueRemaining) then
                    result[#result+1]=r
                end
            end
        end
    end
    local observedOthers,othersWithSlots=0,0
    if not fallback then
        for _,other in pairs(venue.speakers) do
            if other~=speaker and other.maximum then
                observedOthers=observedOthers+1
                if other.count<other.maximum then othersWithSlots=othersWithSlots+1 end
            end
        end
    end
    -- With only one interlocutor observed, let the player try the other tables.
    local venueExhausted=venueRemaining==0
        or (speaker.count>=maximum and observedOthers>0 and othersWithSlots==0)
    local cooling=venueExhausted and venue.lastHeard and math.max(0,venue.lastHeard+W.RumorCooldownSeconds()-GetTimeStamp()) or 0
    local regionalComplete=W.catalogueReady and progress and progress.total>0 and progress.remaining==0 or false
    W.status={map=B.MapKey(),catalogueReady=W.catalogueReady,eligible=#pool,
        regionalRemaining=progress and progress.remaining or regionalRemaining,regionalComplete=regionalComplete,
        regionalTotal=progress and progress.total,venueExhausted=venueExhausted,
        available=#result,heard=speaker.count,cooling=cooling,maximum=maximum,venueKey=key,sharedCooldown=fallback,
        scope='départs éloignés des villes'}
    B.saved.tavernLastCheck136=W.status
    return result
end
local hear=B.HearRumor
function B.HearRumor(r)
    local npc=B.npc
    if not npc then return end
    local text=hear(r)
    if text then
        -- The old delivery revalidates the candidate, willingness and notebook.
        -- Only a delivered reply spends a slot; refusals/replays spend nothing.
        local venue,speaker=stock(npc)
        local id=tostring(r.quest)
        if not venue.heard[id] then
            venue.heard[id]=true;speaker.count=speaker.count+1;venue.lastHeard=GetTimeStamp()
        end
    end
    return text
end
local ending=W.EndLine
function W.RumorWaitPhrase(seconds)
    if seconds<60 then return 'dans un instant' end
    local minutes=math.ceil(seconds/60)
    local hours=math.floor(minutes/60);minutes=minutes%60
    local words={[1]='une',[2]='deux',[3]='trois',[4]='quatre',[5]='cinq',[6]='six',
        [7]='sept',[8]='huit',[9]='neuf',[10]='dix',[11]='onze',[12]='douze',
        [13]='treize',[14]='quatorze',[15]='quinze',[16]='seize',[17]='dix-sept',
        [18]='dix-huit',[19]='dix-neuf',[20]='vingt',[21]='vingt et une',
        [22]='vingt-deux',[23]='vingt-trois',[24]='vingt-quatre'}
    local function amount(n,unit) return (words[n] or tostring(n))..' '..unit..(n>1 and 's' or '') end
    local duration
    if hours==0 then
        duration=minutes==15 and 'un quart d’heure' or minutes==30 and 'une demi-heure'
            or minutes==45 and 'trois quarts d’heure' or amount(minutes,'minute')
    else
        duration=amount(hours,'heure')
        if minutes==30 then duration=duration..' et demie'
        elseif minutes>0 then duration=duration..' et '..amount(minutes,'minute') end
    end
    return 'dans environ '..duration
end
function W.EndLine(npc,status)
    if status and status.catalogueReady and not status.regionalComplete and status.venueExhausted and status.cooling>0 then
        local khajiit=B.IsKhajiitSpeaker(npc)
        local name=B.DialogueFirstName(npc)
        local bank=khajiit and {
            name..' croit qu’on a fait le tour des nouvelles ici. Revenez {wait}, d’autres voyageurs seront peut-être passés.',
            'Pour l’instant, '..name..' n’a rien entendu de plus dans cette auberge. Repassez {wait}, il y aura peut-être du nouveau.',
        } or {
            'On a fait le tour des nouvelles ici. Repassez {wait}, d’autres voyageurs seront peut-être passés d’ici là.',
            'Les tables ont fait le tour de ce qui se raconte. Revenez {wait}, on aura peut-être du nouveau.',
        }
        return (B.Line('rumor-stock-exhausted',bank,npc):gsub('{wait}',W.RumorWaitPhrase(status.cooling)))
    end
    return ending(npc,status)
end
local reset=B.ResetTavernRumors
function B.ResetTavernRumors(...)
    if B.saved then B.saved.rumorStocks23=nil end
    return reset(...)
end
