if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Suppress questions about the region we already occupy, including its parent zones.
local B=IHR_Runtime.Beta
local previousMatch,previousAnswer=B.MatchPlaces,B.PlaceAnswer
-- Only descriptive aliases of the same ruin/site are collapsed. A temple,
-- room, cave or mine inside a town is still a distinct destination.
local function localName(name)
    local text=B.Normalize(name):gsub("^le ",""):gsub("^la ",""):gsub("^les ",""):gsub("^l ","")
    return text:gsub("^ruines de ",""):gsub("^ruines d ","")
end
function B.Here(place)
    local sought=localName(type(place)=="table" and place.name or place)
    if sought=="" then return false end
    local index=GetUnitZoneIndex("player")
    local function same(name) return type(name)=="string" and name~="" and localName(name)==sought end
    if type(GetZoneNameByIndex)=="function" and same(GetZoneNameByIndex(index)) then return true end
    local id=type(GetZoneId)=="function" and GetZoneId(index) or nil
    local seen={}
    for _=1,8 do
        if not id or id==0 or seen[id] then break end
        seen[id]=true
        if type(GetZoneNameById)=="function" and same(GetZoneNameById(id)) then return true end
        local story=type(GetZoneStoryZoneIdForZoneId)=="function" and GetZoneStoryZoneIdForZoneId(id) or 0
        if story and story>0 and type(GetZoneNameById)=="function" and same(GetZoneNameById(story)) then return true end
        id=type(GetParentZoneId)=="function" and GetParentZoneId(id) or nil
    end
    -- Real subzone names are accepted; GetMapName is deliberately excluded (the player may browse another map).
    if type(GetPlayerActiveSubzoneName)=="function" and same(GetPlayerActiveSubzoneName()) then return true end
    if type(GetPlayerLocationName)=="function" and same(GetPlayerLocationName()) then return true end
    return false
end
function B.MatchPlaces(q)
    local result={}
    for _,place in ipairs(previousMatch(q)) do if not B.Here(place) then result[#result+1]=place end end
    return result
end
function B.PlaceAnswer(place)
    if B.npc then B.npc.lastReferral=nil end
    if B.Here(place) then return place.name.." ? Mais vous y êtes. Regardez autour de vous." end
    return previousAnswer(place)
end
