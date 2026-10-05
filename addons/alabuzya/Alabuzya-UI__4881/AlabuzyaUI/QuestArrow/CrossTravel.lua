-- Destination discovery uses a synchronous, restored map snapshot. Never leave
-- a remote map selected while waiting for an asynchronous quest-position reply.
local A, P = QuestArrow, QuestArrow.Planner
local X = { cache = {} }
A.CrossTravel = X

local function format(s) return zo_strformat("<<1>>", s or "") end
local function node(id)
    local known, name, x, y, _, _, kind, shown, locked = GetFastTravelNodeInfo(id)
    local zone, poi = GetFastTravelNodePOIIndicies(id)
    return {id=id, name=format(name), x=x, y=y, kind=kind, shown=shown, zone=zone, poi=poi,
        usable=known and not locked and not GetFastTravelNodeOutboundOnlyInfo(id)
            and GetFastTravelNodeHouseId(id)==0}
end

function X:Clear()
    self.cache = {}
    self.diagnostic = nil
end

function X:Discover(target)
    local currentMap, currentFloor = GetCurrentMapId(), GetMapFloorInfo()
    local originZone = GetCurrentMapZoneIndex()
    local result
    local ok, err = pcall(function()
        local setResult
        if GetJournalQuestIsComplete(A.questIndex) and IsJournalQuestStepEnding(A.questIndex, target.step) then
            setResult = SetMapToQuestStepEnding(A.questIndex, target.step)
        else
            setResult = SetMapToQuestCondition(A.questIndex, target.step, target.condition)
        end
        if setResult == SET_MAP_RESULT_FAILED then
            result = {reason="destination_map_unavailable"} return
        end
        local destinationZone, destinationMap = GetCurrentMapZoneIndex(), GetCurrentMapId()
        result = {reason="no_destination_anchor", map=destinationMap, zone=destinationZone}
        if destinationMap == currentMap or destinationZone == originZone then
            result.reason = "local_destination" return
        end

        -- Journal location is accepted only when it agrees with the selected
        -- condition's destination zone; quest-giver zone alone is not sufficient.
        local _, _, questZone, questPOI = GetJournalQuestLocationInfo(A.questIndex)
        local anchor
        if questZone == destinationZone and questPOI and questPOI > 0 then
            local x,y,_,_,shown,locked = GetPOIMapInfo(questZone,questPOI)
            if shown and not locked and P.ValidPoint({x=x,y=y}) then anchor={x=x,y=y} end
        end
        local exact, zoneNodes, near, named = {}, {}, {}, {}
        local destinationName = format(GetMapName())
        local destinationZoneName = format(GetZoneNameByIndex(destinationZone))
        for id=1,GetNumFastTravelNodes() do
            local n=node(id)
            if n.usable then
                -- Instance nodes may be registered as a POI of their parent
                -- overland zone. Match a unique exact localized map name too.
                if (destinationName ~= "" and n.name == destinationName)
                    or (destinationZoneName ~= "" and n.name == destinationZoneName) then named[#named+1]=n end
                if questZone == destinationZone and questPOI and questPOI > 0
                    and n.zone == questZone and n.poi == questPOI then exact[#exact+1]=n end
                if n.zone == destinationZone then zoneNodes[#zoneNodes+1]=n end
                if n.kind == POI_TYPE_WAYSHRINE and n.shown and P.ValidPoint(n) then near[#near+1]=n end
            end
        end
        if #exact == 1 then result.node=exact[1] result.reason="destination_poi"
        elseif #named == 1 then result.node=named[1] result.reason="destination_map_name"
        elseif #zoneNodes == 1 then
            -- A location with its own single travel node (e.g. an instance).
            -- Do not choose an arbitrary shrine in a large outdoor zone.
            if GetMapContentType() == MAP_CONTENT_DUNGEON then
                result.node=zoneNodes[1] result.reason="destination_instance"
            end
        end
        if not result.node and anchor then
            local columns,rows=GetMapNumTiles()
            local aspect=(rows and rows>0) and columns/rows or 1
            local bestDistance
            for _,n in ipairs(near) do
                local d=P.Distance(anchor,n,aspect)
                if not bestDistance or d<bestDistance then result.node=n bestDistance=d end
            end
            if result.node then result.reason="nearest_destination_poi" end
        end
        result.anchor = anchor ~= nil
        result.zoneNodes = #zoneNodes
        result.name = destinationName
        result.zoneName = destinationZoneName
    end)
    -- Always restore, including failed lookups; there is no yield in this scope.
    local restored = SetMapToMapId(currentMap)
    if restored ~= SET_MAP_RESULT_FAILED then SetMapFloor(currentFloor) end
    if restored == SET_MAP_RESULT_FAILED or GetCurrentMapId() ~= currentMap or GetMapFloorInfo() ~= currentFloor then
        return {reason="restore_failed"}
    end
    if not ok then return {reason="destination_api_error", error=tostring(err)} end
    return result
end

function X:Plan(player,target,nodes,aspect,t)
    if not A.saved.travel or not target.breadcrumb or A.nodeReason ~= "overland" then return nil end
    if not SetMapToQuestCondition or not GetFastTravelNodeHouseId or not GetJournalQuestLocationInfo then return nil end
    if A:MapVisible() or (WORLD_MAP_MANAGER and not WORLD_MAP_MANAGER:IsMapChangingAllowed()) then return nil end
    if next(A.pending) ~= nil then return nil end
    local key=tostring(A.questId)..":"..target.key..":"..A:MapKey()
    local entry=self.cache[key]
    if not entry or t>=entry.expires then
        entry=self:Discover(target)
        entry.expires=t+30
        self.cache[key]=entry
    end
    self.diagnostic=entry
    local b=entry.node
    if not b then return nil end
    local latest=node(b.id)
    if not latest.usable then self.cache[key]=nil return nil end
    local a, distance
    for _,candidate in ipairs(nodes) do
        local d=P.Distance(player,candidate,aspect)
        if not distance or d<distance then a,distance=candidate,d end
    end
    if not a or a.id==b.id then return nil end
    return {mode="travel",target=target,a=a,b=b,distance=distance,spacing=0.16,
        since=t,reason="cross_zone",crossZone=true,destinationMap=entry.map}
end
