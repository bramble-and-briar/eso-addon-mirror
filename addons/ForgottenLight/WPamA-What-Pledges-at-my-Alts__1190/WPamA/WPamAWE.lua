---о-UTF8-о---
local WPamA = WPamA
--
local function nvl(a, b) if a ~= nil then return a elseif b ~= nil then return b else return "nil" end end
local function nvlb(val) if val == nil then return "Nil" elseif val then return "True" end return "False" end
--
local SortedWorldEventsIndex = {}
local CurrentWorldEvents = {}
--=========================================================================
--=============== World events data-base Section ==========================
--=========================================================================
-- POI : [PoiInd] = { ID = POI Index, Name = POI name, isActive = false, EndTS = Event end's TS }
-- Structure : [ZoneId] = { PZI = Map Zone Index, ZoneName = Zone Name, POI | Units = {}, WEContext = context }
-- WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST | WORLD_EVENT_LOCATION_CONTEXT_UNIT | WORLD_EVENT_LOCATION_CONTEXT_NONE
--[[
  EventType :
    WORLD_EVENT_TYPE_MONSTER_HUNT = 0
    WORLD_EVENT_TYPE_SCRIPTED_EVENT = 1
    WORLD_EVENT_TYPE_STATIC_MONSTER = 2
--]]
local WORLD_EVENT_LOCATION_CONTEXT_MIX = 99 -- a dummy context for mixed context events
local WorldEvents = {
  CurrentZoneId = 0,
  CurrentActivePOI = { POI = 0, InstanceId = 0, StartTS = 0 },
  CurrentActiveENC = { InstanceId = 0, Stage = 0, EndTS = 0, isPart = false },
  AverageTimeBetweenPOI = 0,
  UNITBuffs = { [122559] = true, [122561] = true, [122562] = true },
  -- Buff 122562 [Storm Dragon] | 122561 [Frost Dragon] | 122559 [Flame Dragon]
  UNITEvents = {
    [1086] = { PZI = 682, -- PoiZoneIndex "Northern Elsweyr"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_UNIT,
               EventType = WORLD_EVENT_TYPE_MONSTER_HUNT,
               RespTimeDelta = 600,
               -- 1 South dragon | 2 North dragon | 3 West dragon
               UNIT = { 1, 2, 3 },
               UnitPos = {
                 [1] = GetString(SI_COMPASS_SOUTH_ABBREVIATION),
                 [2] = GetString(SI_COMPASS_NORTH_ABBREVIATION),
                 [3] = GetString(SI_COMPASS_WEST_ABBREVIATION)
               },
               -- SI_COMPASS_EAST_ABBREVIATION  = "E" | SI_COMPASS_NORTH_ABBREVIATION = "N"
               -- SI_COMPASS_SOUTH_ABBREVIATION = "S" | SI_COMPASS_WEST_ABBREVIATION  = "W"
             },
    [1133] = { PZI = 721, -- PoiZoneIndex "Southern Elsweyr"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_UNIT,
               EventType = WORLD_EVENT_TYPE_MONSTER_HUNT,
               RespTimeDelta = 120,
               -- 12 North dragon | 13 South dragon
               UNIT = { 12, 13 },
               UnitPos = {
                 [12] = GetString(SI_COMPASS_NORTH_ABBREVIATION),
                 [13] = GetString(SI_COMPASS_SOUTH_ABBREVIATION)
               },
             },
  }, -- UNITEvents array
  POIEvents = {
               -- PZI = PoiZoneIndex = MapZoneIndex
    [   3] = { PZI = 2, -- PoiZoneIndex "Glenumbra"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 43, 44, 45 },
               -- PinIcon = "|t24:24:/esoui/art/icons/poi/poi_portal_complete. dds|t",
               -- PinType = 40,
             },
------------
    [  19] = { PZI = 4, -- PoiZoneIndex "Stormhaven"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 39, 40, 41 },
             },
------------
    [  20] = { PZI = 5, -- PoiZoneIndex "Rivenspire"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 38, 39, 40 },
             },
------------
    [  41] = { PZI = 9, -- PoiZoneIndex "Stonefalls"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 43, 44, 45 },
             },
------------
    [  57] = { PZI = 10, -- PoiZoneIndex "Deshaan"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 40, 41, 42 },
             },
------------
    [  58] = { PZI = 11, -- PoiZoneIndex "Malabal Tor"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 38, 39, 40 },
             },
------------
    [  92] = { PZI = 14, -- PoiZoneIndex "Bangkorai"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 37, 38, 39 },
             },
------------
    [ 101] = { PZI = 15, -- PoiZoneIndex "Eastmarch"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 38, 39, 40 },
             },
------------
    [ 103] = { PZI = 16, -- PoiZoneIndex "The Rift"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 39, 40, 41 },
             },
------------
    [ 104] = { PZI = 17, -- PoiZoneIndex "Alik'r Desert"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 36, 37, 38 },
             },
------------
    [ 108] = { PZI = 18, -- PoiZoneIndex "Greenshade"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 29, 30, 31 },
             },
------------
    [ 117] = { PZI = 19, -- PoiZoneIndex "Shadowfen"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 41, 42, 43 },
             },
------------
    [ 181] = { PZI = 38, -- PoiZoneIndex "Cyrodiil"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 58, 59, 60, 61, 62, 63, 64, 65, 66, 106 },
             },
------------
    [ 381] = { PZI = 178, -- PoiZoneIndex "Auridon"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 37, 38, 39 },
             },
------------
    [ 382] = { PZI = 179, -- PoiZoneIndex "Reaper's March"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 24, 25, 26 },
             },
------------
    [ 383] = { PZI = 180, -- PoiZoneIndex "Grahtwood"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 26, 27, 28 },
             },
------------
    [1011] = { PZI = 617, -- PoiZoneIndex "Summerset"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 44, 46, 49, 51, 52, 58 },
             },
------------
    [1160] = { PZI = 744, -- PoiZoneIndex "Western Skyrim"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 29, 30, 31, 32, 33, 34 },
               Replace = { ["RU"] = "ьный " },
             },
------------
    [1161] = { PZI = 745, -- PoiZoneIndex "Blackreach: Greymoor Caverns"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 18, 19, 20, 21 },
               Replace = { ["RU"] = "ьный " },
             },
------------
    [1207] = { PZI = 784, -- PoiZoneIndex "The Reach"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 8, 9, 13, 14 },
               Replace = { ["RU"] = "ьный " },
             },
------------
    [1318] = { PZI = 884, -- PoiZoneIndex "High Isle"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 41, 42, 43, 44, 45, 46, 47 },
               Replace = { ["RU"] = "ический " },
             },
------------
    [1383] = { PZI = 931, -- PoiZoneIndex "Galen"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 11, 12, 13, 14, 15 },
               Replace = { ["RU"] = "ический " },
             },
------------
    [1443] = { PZI = 983, -- PoiZoneIndex "West Weald"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 60, 62, 63, 64 },
               Replace = { ["RU"] = "альной " },
             },
------------
    [1502] = { PZI = 1034, -- PoiZoneIndex "Solstice"
               -- ZoneName = "",
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_SCRIPTED_EVENT,
               POI = { 58, 59, 60, 61, 62 },
             },
------------
  }, -- POIEvents array
  MIXEvents = {
    -- GetMapIndexById(*integer* mapId) | Returns: *luaindex:nilable* index
    [1559] = { PZI = 1077, -- PoiZoneIndex "Night Market"
               WEContext = WORLD_EVENT_LOCATION_CONTEXT_MIX,
               EventType = WORLD_EVENT_TYPE_MONSTER_HUNT,
               RespTimeDelta = 1800,
               -- 1 Skittering Precinct | 2 The Parch | 3 Sorrow's Friend
               -- MapID = { 2773, 2772, 2774 },
               UNIT = { 52, 53, 54 }, -- Instance IDs of Calamity units
               UnitIcon = WPamA.Textures.GetTexture(71, 20, true),
               -- UnitPos = { [1] = "S", [2] = "N", [3] = "W" },
               POIInstance = { 74 }, -- Instance ID of Skirmish POIs
               POI = { 10, 11, 9 },
               PoiIcon = WPamA.Textures.GetTexture(72, 20, true),
               Recolor = { string.format("%02x%02x%02x", 198, 248, 175),
                           string.format("%02x%02x%02x", 248, 198, 138),
                           string.format("%02x%02x%02x", 175, 248, 240) },
             },
  }, -- MIXEvents array
  DYNEvents = {
    [   3] = { --PZI = 2, -- "Glenumbra"
               -- the "Vampire Hunt" dynamic encounter
               --WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_STATIC_MONSTER,
               -- 96 >> 99 -> 100 -> 101 -> 102 -> 103 -> 104 -> 105 >> 96
               DynEvent = { [96] = 0, [99] = 1, [100] = 2, [101] = 3, [102] = 4, [103] = 5, [104] = 6, [105] = 7 },
               DynProgr = { [99] = 10, [101] = 25, [103] = 50, [105] = 75 },
               ----DynCoord = { StartX = 246580, StartZ = 147292, StopX = 226055, StopZ = 117905 },
             },
------------
    [  41] = { --PZI = 9, -- "Stonefalls"
               -- the "Bilsa's Delivery" dynamic encounter
               --WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_STATIC_MONSTER,
               -- 95 >> 106 -> 107 -> 108 -> 109 -> 112 -> 110 >> 95
               DynEvent = { [95] = 0, [106] = 1, [107] = 2, [108] = 3, [109] = 4, [112] = 5, [110] = 6 },
               DynProgr = { [107] = 25, [109] = 50, [110] = 75 },
               ----DynCoord = { StartX = 182608, StartZ = 207728, StopX = 166945, StopZ = 244688 },
             },
------------
    [ 381] = { --PZI = 178, -- "Auridon"
               -- the "Flowervine Farm" dynamic encounter
               --WEContext = WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST,
               EventType = WORLD_EVENT_TYPE_STATIC_MONSTER,
               -- 98 >> 131 >> 98
               DynEvent = { [98] = 0, [131] = 1 },
               DynProgr = { }, -- [131] = 10 },
               ----DynCoord = { StartX = 249090, StartZ = 371435, StopX = 249090, StopZ = 371435 },
             },
------------
  }, -- DYNEvents array
} -- WorldEvents array
local isPlayerChangedZone = false -- true if player change location
--=========================================================================
--================= World events code Section =============================
--=========================================================================
local function CWE_Iterator(array)
  local i = 0 -- iterator
  local iterFunc =
    function ()
      i = i + 1
      if SortedWorldEventsIndex[i] == nil then
        return nil, nil
      else
        return SortedWorldEventsIndex[i], array[ SortedWorldEventsIndex[i] ]
      end
    end
  return iterFunc
end

local function UpdateWorldEventsIndex()
  local tinsert = table.insert
  SortedWorldEventsIndex = {}
  for ind in pairs(CurrentWorldEvents) do tinsert(SortedWorldEventsIndex, ind) end
  if #SortedWorldEventsIndex > 0 then
    table.sort(SortedWorldEventsIndex,
               function(A, B)
                 return CurrentWorldEvents[A].EndTS < CurrentWorldEvents[B].EndTS
               end)
  end
end

local function GetDistanceFromPlayer(uTag)
  local PlayerX, PlayerY, PlayerZ = 0, 0, 0
  local UnitX, UnitY, UnitZ = 0, 0, 0
  local UnitZoneId = 0
  UnitZoneId, PlayerX, PlayerY, PlayerZ = GetUnitWorldPosition("player")
  UnitZoneId, UnitX, UnitY, UnitZ = GetUnitWorldPosition(uTag)
  local X = UnitX - PlayerX
  local Y = UnitY - PlayerY
  local Z = UnitZ - PlayerZ
  local D = zo_floor( zo_sqrt(X*X + Y*Y + Z*Z) / 100 )
  ---- local D = math.floor(math.sqrt(X*X + Y*Y + Z*Z) / 100)
  ---- local D = zo_floor(zo_distance3D(UnitX, UnitY, UnitZ, PlayerX, PlayerY, PlayerZ) / 100)
  return D
end

local function GetDistancePoiFromPlayer(poiZI, poiInd)
  local UnitZoneId, PlayerX, PlayerY, PlayerZ = 0, 0, 0, 0
  UnitZoneId, PlayerX, PlayerY, PlayerZ = GetUnitWorldPosition("player")
  local PoiX, PoiZ = GetPOIMapInfo(poiZI, poiInd)
  local X = PoiX - PlayerX
  local Z = PoiZ - PlayerZ
  local D = zo_floor( zo_sqrt(X*X + Z*Z) / 100 )
  ---- local D = zo_floor( zo_distance(PoiX, PoiZ, PlayerX, PlayerZ) / 100)
  return D
end

local function IsWorldEventDynamical(WEInstanceId)
  local WE = WorldEvents
  if WE.DYNEvents[WE.CurrentZoneId] then -- it's a DYN-WE location
    local zoneWE = WE.DYNEvents[WE.CurrentZoneId]
    if zoneWE.DynEvent[WEInstanceId] then return true end
  end
  return false
end

local function GetActiveDynamicEncounterStage()
  local count = -1 -- no Dynamic Encounter by default
  local WE = WorldEvents
  if WE.DYNEvents[WE.CurrentZoneId] then -- it's a DYN-WE location
    local zoneWE = WE.DYNEvents[WE.CurrentZoneId]
    --if zoneWE.DynEvent then
      count = 0
      for wei, val in pairs(zoneWE.DynEvent) do
        if GetWorldEventId(wei) > 0 then count = count + val end
      end
    --end
  end
  return count
end

--[[
local function UpdateAverageTimeBetweenUNIT(WEInstanceId)
--  local WE = WorldEvents
  local unitData = CurrentWorldEvents[WEInstanceId]
  if unitData then
    local old = unitData.OldEndTS or 0
    local curr = unitData.EndTS or 0
    if old > 0 then CurrentWorldEvents[WEInstanceId].AverageTimeBetweenUNIT = curr - old
    else CurrentWorldEvents[WEInstanceId].AverageTimeBetweenUNIT = 0
    end
  end
end -- UpdateAverageTimeBetweenUNIT end
--]]

local function UpdateAverageTimeBetweenPOI()
  local WE = WorldEvents
  local countEndedWE = 0 -- how many WE's have completed right now
  local avrTime = 0
  for i = 1, #SortedWorldEventsIndex do
    local ind1 = SortedWorldEventsIndex[i]
    local ind2 = SortedWorldEventsIndex[i + 1] or SortedWorldEventsIndex[1]
    local ets1 = CurrentWorldEvents[ind1].EndTS
    local ets2 = CurrentWorldEvents[ind2].EndTS
    if (ets1 > 9999) and (ets2 > 9999) then
      countEndedWE = countEndedWE + 1
      if ets1 < ets2 then
        avrTime = avrTime + (ets2 - ets1)
      else
        avrTime = avrTime + math.floor( (ets1 - ets2) / (#SortedWorldEventsIndex - 1) )
      end
    end
  end
  if countEndedWE > 0 then
    WE.AverageTimeBetweenPOI = math.floor(avrTime / countEndedWE) -- average time between POIs
  end
end -- UpdateAverageTimeBetweenPOI end

local function ActivateWorldEventDataUNIT(WEInstanceId, WEUnitTag)
  local WE = WorldEvents
  local CWE = CurrentWorldEvents[WEInstanceId]
  local WEunits = GetNumWorldEventInstanceUnits(WEInstanceId)
  if WEunits > 0 then
    if not CWE then
      --- unknown UNIT detected ---
      CurrentWorldEvents[WEInstanceId] = {}
      CWE = CurrentWorldEvents[WEInstanceId]
      CWE.EndTS = 0
    end
    local uTag = WEUnitTag or GetWorldEventInstanceUnitTag(WEInstanceId, 1) -- usually only 1 unit per event
    local curHP, maxHP, emaxHP = GetUnitPower(uTag, COMBAT_MECHANIC_FLAGS_HEALTH)
--
    local unitName = ""
    local nameBuff, _, _, _, _, _, _, _, _, _, abilityID = GetUnitBuffInfo(uTag, 1) -- 1st buff is a type of unit
    if WE.UNITBuffs[abilityID] then unitName = nameBuff
    else unitName = GetUnitName(uTag)
    end
--
    CWE.isActive = true
    CWE.UnitTag = uTag
    CWE.Name = zo_strformat( SI_COMPANION_NAME_FORMATTER, unitName )
    CWE.CurHP = curHP
    CWE.MaxHP = emaxHP
--    CWE.PinType = GetWorldEventInstanceUnitPinType(WEInstanceId, uTag)
--    CWE.PinIcon = pinIcon
--    CWE.EndTS = 0
  end
end -- ActivateWorldEventDataUNIT end

local function DeactivateWorldEventDataUNIT(WEInstanceId, WEUnitTag)
  -- local WE = WorldEvents
  -- local currZoneId = WE.CurrentZoneId
  local CWE = CurrentWorldEvents[WEInstanceId]
  if CWE then
    CWE.isActive = false
    CWE.EndTS = GetTimeStamp()
    -- CWE.PinType = GetWorldEventInstanceUnitPinType(WEInstanceId, WEUnitTag)
    -- CWE.PinIcon = pinIcon
  end
end -- DeactivateWorldEventDataUNIT end

local function ActivateWorldEventDataPOI(WEInstanceId)
  local WE = WorldEvents
  local zoneInd, poiInd = GetWorldEventPOIInfo(WEInstanceId)
  if (zoneInd < 2) or (poiInd < 2) then return end
  ---
  local CWE = CurrentWorldEvents[poiInd]
  if not CWE then
    --- unknown POI detected ---
    CurrentWorldEvents[poiInd] = {}
    CWE = CurrentWorldEvents[poiInd]
    local poiName = GetPOIInfo(zoneInd, poiInd)
    CWE.Name = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName)
    CWE.EndTS = poiInd
  end
  ---
  local mapX, mapZ, pinType, pinIcon = GetPOIMapInfo(zoneInd, poiInd)
  pinIcon = zo_strformat("|t<<1>>:<<1>>:<<2>>|t", 24, pinIcon)
  CWE.PinType = pinType
  CWE.PinIcon = pinIcon
  CWE.isActive = true
  ---
  if isPlayerChangedZone or (WE.CurrentActivePOI.POI ~= poiInd) then
    WE.CurrentActivePOI.POI = poiInd
    WE.CurrentActivePOI.InstanceId = WEInstanceId
    WE.CurrentActivePOI.StartTS = GetTimeStamp()
  end
end -- ActivateWorldEventDataPOI end

local function DeactivateWorldEventDataPOI(WEInstanceId)
  local WE = WorldEvents
  if WE.CurrentActivePOI.InstanceId ~= WEInstanceId then return end
  ---
  local poiInd = WE.CurrentActivePOI.POI
  ----local zoneInd, poiInd = GetWorldEventPOIInfo(WEInstanceId)
  local CWE = CurrentWorldEvents[poiInd]
  if CWE then
    local TS = GetTimeStamp()
    CWE.isActive = false
    CWE.ActTime = 0
    if (TS - WE.CurrentActivePOI.StartTS) > 10 then -- protection vs "false completing" of the event
      CWE.EndTS = TS
      CWE.ActTime = TS - WE.CurrentActivePOI.StartTS
      local currZoneId = WE.CurrentZoneId
      local poiZI = (not WE.POIEvents[currZoneId]) and 0 or WE.POIEvents[currZoneId].PZI -- protection vs unknown POI
      local mapX, mapZ, pinType, pinIcon = GetPOIMapInfo(poiZI, poiInd)
      pinIcon = zo_strformat("|t<<1>>:<<1>>:<<2>>|t", 24, pinIcon)
      CWE.PinType = pinType
      CWE.PinIcon = pinIcon
    end
  end
  ---
  WE.CurrentActivePOI.POI = 0
  WE.CurrentActivePOI.InstanceId = 0
  WE.CurrentActivePOI.StartTS = 0
end -- DeactivateWorldEventDataPOI end

local function ActivateDynamicEncounterData(WEInstanceId, isEventCalled)
  local WE = WorldEvents
  local CE = WE.CurrentActiveENC
  local stage = GetActiveDynamicEncounterStage()
  if stage < 0 then
   --- no Dynamic Encounter = no data ---
    CE.InstanceId = 0
    CE.Stage = 0
    CE.EndTS = 0
    CE.isPart = false
    return
  elseif (stage == 0) and (not isEventCalled) then
   --- fake Dynamic Encounter activity ---
    return
  elseif (stage == 0) and (CE.Stage > 0) then
   --- fake Dynamic Encounter call before an event end ---
    return
  --elseif isPlayerChangedZone or (CE.InstanceId ~= WEInstanceId) then
  end
  --============= an active Dynamic Encounter =============
  local zoneWE = WE.DYNEvents[WE.CurrentZoneId]
  if stage == 0 then
   --- init Dynamic Encounter event ---
    CE.InstanceId = WEInstanceId
    CE.Stage = 0
    CE.EndTS = 0
    CE.isPart = false
  --elseif (stage > 0) and (zoneWE.DynEvent[WEInstanceId] > 0) then
  elseif stage > 0 then
   --- current Dynamic Encounter stage ---
    CE.InstanceId = WEInstanceId
    CE.Stage = stage
    CE.EndTS = 0
    local eid = GetParticipatingWorldEventStep()
    CE.isPart = eid > 0
  end
  --============= notify Dynamic Encounter ================
  local showNotify = WPamA.SV_Main.DynEncounterNotifyMode
  if showNotify > 0 then
    local MSG = WPamA.i18n.DynamicEncounter
    local stageText = ""
    if (showNotify == 2) or ( (showNotify == 1) and (not CE.isPart) ) then
      local isOnInitStage = (stage > 0) and (zoneWE.DynEvent[WEInstanceId] == 0)
      if stage == 0 then
        stageText = MSG.Start
      elseif isOnInitStage and (not isEventCalled) then
        stageText = MSG.Activ
        stage = 0
      elseif stage > 0 then
        local WEType = GetWorldEventType( GetWorldEventId(WEInstanceId) )
        local progress = zoneWE.DynProgr[WEInstanceId]
        if progress and (WEType == zoneWE.EventType) then
          stageText = zo_strformat(MSG.Progr, progress)
        end
      end
    end
    ---
    if stageText ~= "" then
      local messageText = zo_strformat("<<1>><<2>>: <<3>>", MSG.Icon, MSG.Title, stageText)
      local color = string.format("%02x%02x%02x", 238, 238, 200)
      messageText = zo_strformat("|c<<1>><<2>>|r", color, messageText)
      WPamA:PostChatMessage(messageText)
      if stage == 0 then
        messageText = zo_strformat("|c<<1>><<2>>:\n<<3>>|r", color, MSG.Title, stageText)
        WPamA:PostScreenAnnounceMessage(messageText, CSA_CATEGORY_MAJOR_TEXT, nil,
                                        ----CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST,
                                        WPamA.Textures.GetTexture(73))
      end
    end
    ---
  end
  --=============================
end -- ActivateDynamicEncounterData end

local function DeactivateDynamicEncounterData(WEInstanceId)
  local WE = WorldEvents
  local zoneWE = WE.DYNEvents[WE.CurrentZoneId]
  if zoneWE.DynEvent[WEInstanceId] > 0 then return end
  --============= notify Dynamic Encounter ================
  local showNotify = WPamA.SV_Main.DynEncounterNotifyMode
  if showNotify > 0 then
    local MSG = WPamA.i18n.DynamicEncounter
    local stageText = ""
    if (showNotify == 2) or ( (showNotify == 1) and (not WE.CurrentActiveENC.isPart) ) then
      stageText = MSG.Stop
    end
    ---
    if stageText ~= "" then
      local messageText = zo_strformat("<<1>><<2>>: <<3>>", MSG.Icon, MSG.Title, stageText)
      local color = string.format("%02x%02x%02x", 238, 238, 200)
      messageText = zo_strformat("|c<<1>><<2>>|r", color, messageText)
      WPamA:PostChatMessage(messageText)
      ----d("Ending Time: " .. WPamA:TimestampToStr(WE.CurrentActiveENC.EndTS) )
      ----d("Next Time: " .. WPamA:TimestampToStr(30 * 60 + WE.CurrentActiveENC.EndTS) )
      messageText = zo_strformat("|c<<1>><<2>>:\n<<3>>|r", color, MSG.Title, stageText)
      WPamA:PostScreenAnnounceMessage(messageText, CSA_CATEGORY_MAJOR_TEXT, nil,
                                      ----CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST,
                                      WPamA.Textures.GetTexture(73))
    end
  end
  --=============================
  WE.CurrentActiveENC.InstanceId = WEInstanceId
  WE.CurrentActiveENC.Stage = 0
  WE.CurrentActiveENC.EndTS = GetTimeStamp()
  WE.CurrentActiveENC.isPart = false
end -- DeactivateDynamicEncounterData end

local function ActivateAdventureEventDataUNIT(WEInstanceId)
  local WE = WorldEvents
  if not WE.MIXEvents[WE.CurrentZoneId] then return end
  local zoneWE = WE.MIXEvents[WE.CurrentZoneId]
  if not ZO_IsElementInNumericallyIndexedTable(zoneWE.UNIT, WEInstanceId) then return end
  ---
  local CWE = CurrentWorldEvents[WEInstanceId]
  local WEunits = GetNumWorldEventInstanceUnits(WEInstanceId)
  if WEunits > 0 then
    if not CWE then
      --- unknown UNIT detected ---
      CurrentWorldEvents[WEInstanceId] = {}
      CWE = CurrentWorldEvents[WEInstanceId]
      CWE.EndTS = 0
    end
    local uTag = GetWorldEventInstanceUnitTag(WEInstanceId, 1) -- usually only 1 unit per event
    if DoesUnitExist(uTag) then
      local curHP, maxHP, emaxHP = GetUnitPower(uTag, COMBAT_MECHANIC_FLAGS_HEALTH)
      local unitName = GetUnitName(uTag)
      CWE.isActive = true
      CWE.UnitTag = uTag
      CWE.Name = zo_strformat( SI_COMPANION_NAME_FORMATTER, unitName )
      CWE.CurHP = curHP
      CWE.MaxHP = emaxHP
    end
  end
end -- ActivateAdventureEventDataUNIT end

local function DeactivateAdventureEventDataUNIT(WEInstanceId)
  local WE = WorldEvents
  if not WE.MIXEvents[WE.CurrentZoneId] then return end
  local zoneWE = WE.MIXEvents[WE.CurrentZoneId]
  if not ZO_IsElementInNumericallyIndexedTable(zoneWE.UNIT, WEInstanceId) then return end
  ---
  local CWE = CurrentWorldEvents[WEInstanceId]
  if CWE then
    CWE.isActive = false
    CWE.EndTS = GetTimeStamp()
  end
end -- DeactivateAdventureEventDataUNIT end

local function ActivateAdventureEventDataPOI(poiInd)
  local WE = WorldEvents
  if not WE.MIXEvents[WE.CurrentZoneId] then return end
  local zoneWE = WE.MIXEvents[WE.CurrentZoneId]
  if not ZO_IsElementInNumericallyIndexedTable(zoneWE.POI, poiInd) then return end
  ---
  local zoneInd = zoneWE.PZI
  local districtInd = ZO_IndexOfElementInNumericallyIndexedTable(zoneWE.POI, poiInd)
  local CWE = CurrentWorldEvents[poiInd]
  if not CWE then
    --- unknown POI detected ---
    CurrentWorldEvents[poiInd] = {}
    CWE = CurrentWorldEvents[poiInd]
    local poiName = GetPOIInfo(zoneInd, poiInd)
    CWE.Name = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName)
    CWE.EndTS = poiInd
  end
  ---
  CWE.MaxHP, CWE.CurHP, CWE.UnitTag = 0, 0, ""
  ---- local poiName = GetPOIInfo(zoneInd, poiInd)
  ---- CWE.Name = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName)
  ---- local districtName = zo_strformat(SI_ADVENTURE_ZONE_EVENT_FORMATTER, GetAdventureZoneEventLocationName(districtInd))
  local districtEventState = GetAdventureZoneEventLocationState(districtInd)
  if     districtEventState == ADVENTURE_ZONE_WORLD_EVENT_LOCATION_STATE_INACTIVE then
    if CWE.isActive then CWE.EndTS = GetTimeStamp() end
    CWE.isActive = false
  elseif districtEventState == ADVENTURE_ZONE_WORLD_EVENT_LOCATION_STATE_ACTIVE then
    CWE.isActive = true
  elseif districtEventState == ADVENTURE_ZONE_WORLD_EVENT_LOCATION_STATE_STARTS_SOON then
    CWE.isActive = false
    CWE.EndTS = zo_floor(GetAdventureZoneEventLocationStartTimestampMs(districtInd) / 1000)
    ---- local secondsRemaining = zo_max(startTimestamp - GetTimeStamp(), 0)
    ---- local timeRemainingText = ZO_FormatTime(secondsRemaining, TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS, TIME_FORMAT_PRECISION_SECONDS)
    end
---
end -- ActivateAdventureEventDataPOI end

local function DeactivateAdventureEventDataPOI(poiInd)
  local WE = WorldEvents
  if not WE.MIXEvents[WE.CurrentZoneId] then return end
  local zoneWE = WE.MIXEvents[WE.CurrentZoneId]
  if not ZO_IsElementInNumericallyIndexedTable(zoneWE.POI, poiInd) then return end
  ---
  local CWE = CurrentWorldEvents[poiInd]
  if CWE then
    CWE.isActive = false
    CWE.EndTS = GetTimeStamp()
  end
end -- DeactivateAdventureEventDataPOI end

local function UpdateCurrentWorldEvents(WEContext, WEAction, WEInstanceId)
  if WEAction == "RELOAD" then
    WorldEvents.CurrentActiveENC = { InstanceId = 0, Stage = 0, EndTS = 0, isPart = false }
   --- collect info about all current World Events ---
    WEInstanceId = GetNextWorldEventInstanceId(nil)
    while WEInstanceId do
      ---
      if IsWorldEventDynamical(WEInstanceId) then
       --- any of dynamic World Events ---
        ActivateDynamicEncounterData(WEInstanceId, false)
       --- any of static World Events ---
      elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
        ActivateWorldEventDataUNIT(WEInstanceId)
      elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
        ActivateWorldEventDataPOI(WEInstanceId)
      end
      ---
      WEInstanceId = GetNextWorldEventInstanceId( WEInstanceId )
    end
--
  elseif WEAction == "ACT" then
   --- activation of a single event ---
    if WEContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      ActivateWorldEventDataUNIT(WEInstanceId, WEUnitTag)
    elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
      ActivateWorldEventDataPOI(WEInstanceId)
    end
--
  elseif WEAction == "DEACT" then
   --- deactivation of a single event ---
    if WEContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      DeactivateWorldEventDataUNIT(WEInstanceId, WEUnitTag)
    elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
      DeactivateWorldEventDataPOI(WEInstanceId)
    end
--
  elseif WEAction == "RELOAD-MIX" then
    for wei = 1, #WEInstanceId do -- use WEInstanceId as a table of IDs
      local Instance = WEInstanceId[wei]
      if WEContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
        ActivateAdventureEventDataPOI(Instance)
      elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
        ActivateAdventureEventDataUNIT(Instance)
      end
    end
--
  elseif WEAction == "ACT-MIX" then
   --- activation of a single event ---
    if WEContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
      local _, POIIndex = GetWorldEventPOIInfo(WEInstanceId)
      ActivateAdventureEventDataPOI(POIIndex)
    elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      ActivateAdventureEventDataUNIT(WEInstanceId)
    end
--
  elseif WEAction == "DEACT-MIX" then
   --- deactivation of a single event ---
    if WEContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
      local WE = WorldEvents
      if WE.MIXEvents[WE.CurrentZoneId] then
        local zoneWE = WE.MIXEvents[WE.CurrentZoneId]
        for poi = 1, #zoneWE.POI do
          ActivateAdventureEventDataPOI( zoneWE.POI[poi] )
        end
      end
    elseif WEContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      DeactivateAdventureEventDataUNIT(WEInstanceId)
    end
--
  end -- all WEAction types
--
  UpdateWorldEventsIndex()
  UpdateAverageTimeBetweenPOI()
end -- UpdateCurrentWorldEvents end

local function ReloadCurrentZoneWE()
  local WE = WorldEvents
  local currZoneId = GetUnitWorldPosition("player")
  --local currZoneName = GetUnitZone("player")
  if WE.CurrentZoneId ~= currZoneId then -- the player has changed location or just log in the game
   --- full initialization of the WE list in the location ---
    CurrentWorldEvents = {}
    WE.AverageTimeBetweenPOI = 0
    WE.CurrentZoneId = currZoneId
    isPlayerChangedZone = true
    if WE.POIEvents[currZoneId] then -- it's a POI-WE location
      local zoneWE = WE.POIEvents[currZoneId]
      --zoneWE.PZI = GetCurrentMapZoneIndex()
      --[[
      local mapZI = GetCurrentMapZoneIndex()
      if zoneWE.PZI ~= mapZI then
        zoneWE.PZI = mapZI
        d("-=- WE-PZI was changed to " .. mapZI)
      end
      --]]
      local poiZI = zoneWE.PZI
      local context = zoneWE.WEContext
      --if zoneWE.ZoneName ~= currZoneName then zoneWE.ZoneName = currZoneName end
      for i = 1, #zoneWE.POI do
        local poiInd = zoneWE.POI[i]
        CurrentWorldEvents[poiInd] = {}
        local CWE = CurrentWorldEvents[poiInd]
        CWE.isActive = false
        local poiName = GetPOIInfo(poiZI, poiInd)
        poiName = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName)
        CWE.Name = poiName
        if zoneWE.Replace and zoneWE.Replace[WPamA.i18n.Lng] then
          CWE.Name = poiName:gsub(zoneWE.Replace[WPamA.i18n.Lng], ".")
        end
        --CWE.EndTS = 0
        --CWE.ToolTip = ""
        CWE.EndTS = poiInd
        CWE.ActTime = 0
        local mapX, mapZ, pinType, pinIcon = GetPOIMapInfo(poiZI, poiInd)
        pinIcon = zo_strformat("|t<<1>>:<<1>>:<<2>>|t", 24, pinIcon)
        CWE.PinType = pinType
        CWE.PinIcon = pinIcon
      end
      UpdateCurrentWorldEvents(context, "RELOAD")
--
    elseif WE.UNITEvents[currZoneId] then -- it's a Unit-WE location
      local zoneWE = WE.UNITEvents[currZoneId]
      local context = zoneWE.WEContext
      --if zoneWE.ZoneName ~= currZoneName then zoneWE.ZoneName = currZoneName end
      for i = 1, #zoneWE.UNIT do
        local unitInd = zoneWE.UNIT[i]
        CurrentWorldEvents[unitInd] = {}
        local CWE = CurrentWorldEvents[unitInd]
        CWE.isActive = false
        CWE.UnitTag = ""
        CWE.Name = ""
        CWE.EndTS = 0
        CWE.CurHP = 0
        CWE.MaxHP = 0
        --CWE.PinType = 0
        --CWE.PinIcon = ""
      end
      UpdateCurrentWorldEvents(context, "RELOAD")
--
    elseif WE.MIXEvents[currZoneId] then -- it's a Mixed-WE location (Adventure Zone)
      local zoneWE = WE.MIXEvents[currZoneId]
      --local context = zoneWE.WEContext
      for i = 1, #zoneWE.UNIT do
        local unitInd = zoneWE.UNIT[i]
        CurrentWorldEvents[unitInd] = { isActive = false, UnitTag = "", Name = "",
                                        EndTS = i, CurHP = 0, MaxHP = 0, Distr = i }
      end
      for i = 1, #zoneWE.POI do
        local poiInd = zoneWE.POI[i]
        CurrentWorldEvents[poiInd] = { isActive = false, UnitTag = "", Name = "",
                                       EndTS = i, CurHP = 0, MaxHP = 0, Distr = i }
        local poiName = GetPOIInfo(zoneWE.PZI, poiInd)
        CurrentWorldEvents[poiInd].Name = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName)
      end
      UpdateCurrentWorldEvents(WORLD_EVENT_LOCATION_CONTEXT_UNIT, "RELOAD-MIX", zoneWE.UNIT)
      UpdateCurrentWorldEvents(WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST, "RELOAD-MIX", zoneWE.POI)
--
    else -- it's a location with an unknown WE type
      CurrentWorldEvents[1] = { isActive = false, EndTS = 0, PinType = 0, PinIcon = "", Name = WPamA.i18n.NoWorldEventsHere }
      WE.AverageTimeBetweenPOI = 0
      UpdateWorldEventsIndex()
    end
-------
  else -- the player stayed at the same location
    isPlayerChangedZone = false
    if WE.POIEvents[currZoneId] then -- it's a POI-WE location
      local zoneWE = WE.POIEvents[currZoneId]
      local context = zoneWE.WEContext
      for i = 1, #zoneWE.POI do
        local poiInd = zoneWE.POI[i]
        CurrentWorldEvents[poiInd].isActive = false
      end
      UpdateCurrentWorldEvents(context, "RELOAD")
--
    elseif WE.UNITEvents[currZoneId] then -- it's a Unit-WE location
      local zoneWE = WE.UNITEvents[currZoneId]
      local context = zoneWE.WEContext
      for i = 1, #zoneWE.UNIT do
        local unitInd = zoneWE.UNIT[i]
        CurrentWorldEvents[unitInd].isActive = false
      end
      UpdateCurrentWorldEvents(context, "RELOAD")
--
    elseif WE.MIXEvents[currZoneId] then -- it's a Mixed-WE location (Adventure Zone)
      local zoneWE = WE.MIXEvents[currZoneId]
      local context = zoneWE.WEContext
      for i = 1, #zoneWE.UNIT do
        local unitInd = zoneWE.UNIT[i]
        CurrentWorldEvents[unitInd].isActive = false
      end
      for i = 1, #zoneWE.POI do
        local poiInd = zoneWE.POI[i]
        CurrentWorldEvents[poiInd].isActive = false
      end
      UpdateCurrentWorldEvents(WORLD_EVENT_LOCATION_CONTEXT_UNIT, "RELOAD-MIX", zoneWE.UNIT)
      UpdateCurrentWorldEvents(WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST, "RELOAD-MIX", zoneWE.POI)
--
    else -- it's a location with an unknown WE type
      CurrentWorldEvents[1] = { isActive = false, EndTS = 0, PinType = 0, PinIcon = "", Name = WPamA.i18n.NoWorldEventsHere }
      WE.AverageTimeBetweenPOI = 0
      UpdateWorldEventsIndex()
    end
  end -- a location has been changed or not
-------
  WPamA:UpdCharLoginData(isPlayerChangedZone) -- hirelings mail update
-------
  local m = WPamA.SV_Main.ShowMode
  local Modes = { [5] = true, [38] = true }
  if Modes[m] then WPamA:UpdWindowInfo() end
end -- ReloadCurrentZoneWE end

function WPamA.OnPlayerActiveWE(event, ...)
  --local WE = WorldEvents
  if event == EVENT_PLAYER_DEACTIVATED then
    WPamA.isPlayerActive = false
    WPamA.CurChar.PlayedTime = GetSecondsPlayed()
    WPamA:UpdateActiveTimedEffects()
  elseif event == EVENT_PLAYER_ACTIVATED then
    WPamA.PlayerInZone = {
      AvA     = IsInCampaign() or IsInImperialCity() or IsActiveWorldBattleground() or false,
      Veng    = IsCurrentCampaignVengeanceRuleset() or false,
      Raid    = IsPlayerInRaid() or false,
      EndDung = IsInstanceEndlessDungeon() or false,
      Dungeon = IsUnitInDungeon("player") or false,
      Advent  = IsInAdventureZone() or false
    }
    ReloadCurrentZoneWE()
    WPamA.isPlayerActive = true
    if WPamA:IsDelayedChatMessage() then WPamA:PostDelayedChatMessages() end
  end -- events
end -- OnPlayerActiveWE end

function WPamA.OnWorldEventsCalled(eventCode, WEInstanceId, unitTag, ...)
  if not WPamA.isPlayerActive then return end
  local WELocationContext = GetWorldEventLocationContext(WEInstanceId)
  -- WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST | WORLD_EVENT_LOCATION_CONTEXT_UNIT | WORLD_EVENT_LOCATION_CONTEXT_NONE
  local AdventWEContext = 0
  if WPamA.PlayerInZone.Advent then
    AdventWEContext = WELocationContext
    WELocationContext = WORLD_EVENT_LOCATION_CONTEXT_MIX
  end

  --================== Dynamic Encounter events ======================
  if IsWorldEventDynamical(WEInstanceId) then
    if eventCode == EVENT_WORLD_EVENT_ACTIVATED then
    -- EVENT_WORLD_EVENT_ACTIVATED (worldEventInstanceId)
      ActivateDynamicEncounterData(WEInstanceId, true)
    elseif eventCode == EVENT_WORLD_EVENT_DEACTIVATED then
     -- EVENT_WORLD_EVENT_DEACTIVATED (worldEventInstanceId)
      DeactivateDynamicEncounterData(WEInstanceId)
    end

  --======================= Unknown events ===========================
  elseif WELocationContext == WORLD_EVENT_LOCATION_CONTEXT_NONE then
    --[[
    if not WPamA.PlayerInZone.Advent then
      local WEType = GetWorldEventType( GetWorldEventId(WEInstanceId) )
      local textWEType = "Unknown"
      if WEType == WORLD_EVENT_TYPE_MONSTER_HUNT then textWEType = "Monster Hunt"
      elseif WEType == WORLD_EVENT_TYPE_SCRIPTED_EVENT then textWEType = "Scripted Event"
      elseif WEType == WORLD_EVENT_TYPE_STATIC_MONSTER then textWEType = "Static Monster"
      end
      d("=-=- Unknown WE detected -=-=")
      d(zo_strformat("=-=- InstId:<<1>> Type:<<2>>", WEInstanceId, textWEType))
      local zoneInd, poiInd = GetWorldEventPOIInfo(WEInstanceId)
      if (zoneInd > 0) and (poiInd > 0) then
        local poiName = GetPOIInfo(zoneInd, poiInd)
        d(zo_strformat("POI:[<<1>>]", zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName) ))
        d(zo_strformat("POI ZI:<<1>> Ind:<<2>>", zoneInd, poiInd))
      end
      local WEunits = GetNumWorldEventInstanceUnits(WEInstanceId)
      if WEunits > 0 then
        local uTag = GetWorldEventInstanceUnitTag(WEInstanceId, 1)
        d(zo_strformat("Unit name:[<<1>>]", GetUnitName(uTag) ))
      end
    end --]]

  --====================== POI-based events ==========================
  elseif WELocationContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
    if eventCode == EVENT_WORLD_EVENT_ACTIVATED then
    -- EVENT_WORLD_EVENT_ACTIVATED (worldEventInstanceId)
      UpdateCurrentWorldEvents(WELocationContext, "ACT", WEInstanceId)
    elseif eventCode == EVENT_WORLD_EVENT_DEACTIVATED then
     -- EVENT_WORLD_EVENT_DEACTIVATED (worldEventInstanceId)
      UpdateCurrentWorldEvents(WELocationContext, "DEACT", WEInstanceId)
    end

  --====================== UNIT-based events =========================
  elseif WELocationContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
    if eventCode == EVENT_WORLD_EVENT_UNIT_CREATED then
     -- EVENT_WORLD_EVENT_UNIT_CREATED (worldEventInstanceId, unitTag)
      ActivateWorldEventDataUNIT(WEInstanceId, unitTag)
    elseif eventCode == EVENT_WORLD_EVENT_UNIT_DESTROYED then
     -- EVENT_WORLD_EVENT_UNIT_DESTROYED (worldEventInstanceId, unitTag)
      DeactivateWorldEventDataUNIT(WEInstanceId, unitTag)
    --elseif eventCode == EVENT_WORLD_EVENT_UNIT_CHANGED_PIN_TYPE then
     -- EVENT_WORLD_EVENT_UNIT_CHANGED_PIN_TYPE (worldEventInstanceId, unitTag, oldPinType, newPinType)
    end

  --====================== MIX-based events ==========================
  elseif WELocationContext == WORLD_EVENT_LOCATION_CONTEXT_MIX then
    if eventCode == EVENT_WORLD_EVENT_ACTIVATED then
    -- EVENT_WORLD_EVENT_ACTIVATED (worldEventInstanceId)
      UpdateCurrentWorldEvents(AdventWEContext, "ACT-MIX", WEInstanceId)
    elseif eventCode == EVENT_WORLD_EVENT_DEACTIVATED then
     -- EVENT_WORLD_EVENT_DEACTIVATED (worldEventInstanceId)
      UpdateCurrentWorldEvents(AdventWEContext, "DEACT-MIX", WEInstanceId)
    elseif eventCode == EVENT_ADVENTURE_ZONE_WORLD_EVENT_STARTS_SOON then
      UpdateCurrentWorldEvents(WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST, "DEACT-MIX", WEInstanceId)
    end

  --==================================================================
  end -- Location's Context
--
  local m = WPamA.SV_Main.ShowMode
  if m == 38 then WPamA:UpdWindowInfo() end
end -- OnWorldEventsCalled end

function WPamA:GetWEModeColumnNames(columnType)
  local icon = self.Textures.GetTexture
  local WE = WorldEvents
  local czi = WE.CurrentZoneId
  local context = WORLD_EVENT_LOCATION_CONTEXT_NONE
  if WE.POIEvents[czi]  then context = WE.POIEvents[czi].WEContext end
  if WE.UNITEvents[czi] then context = WE.UNITEvents[czi].WEContext end
  if WE.MIXEvents[czi]  then context = WE.MIXEvents[czi].WEContext end
--
  if columnType == "A" then
    if context == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      return icon(11, 24), GetString(SI_NOTIFICATIONTYPE19)
    elseif context == WORLD_EVENT_LOCATION_CONTEXT_MIX then
      return icon(11, 24), GetString(SI_NOTIFICATIONTYPE19)
    else -- POI and None
      return icon(12, 24), GetString(SI_NOTIFICATIONTYPE19)
    end
  elseif columnType == "B" then
    if context == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      self.i18n.ToolTip[112] = self.i18n.ToolTip[118]
      self.i18n.ToolTip[113] = self.i18n.ToolTip[119]
      self.i18n.ToolTip[114] = self.i18n.ToolTip[120]
      return "HP % /" .. icon(13, 28, true),
             self.i18n.WEDistance, icon(6, 26, true)
    elseif context == WORLD_EVENT_LOCATION_CONTEXT_MIX then
      self.i18n.ToolTip[112] = self.i18n.ToolTip[118]
      self.i18n.ToolTip[113] = self.i18n.ToolTip[119]
      self.i18n.ToolTip[114] = self.i18n.ToolTip[120]
      return "HP % /" .. icon(13, 28, true),
             self.i18n.WEDistance, icon(6, 26, true)
    else -- POI and None
      self.i18n.ToolTip[112] = self.i18n.ToolTip[115]
      self.i18n.ToolTip[113] = self.i18n.ToolTip[116]
      self.i18n.ToolTip[114] = self.i18n.ToolTip[117]
      return icon(14, 24, true) .. " /" .. icon(13, 28, true),
             icon(14, 24, true) .. icon(15, 26, true),
             icon(6, 26, true)
    end
  end
--
  return "", "", ""
end -- GetWEModeColumnNames end

function WPamA:UpdWindowModeWorldEvents()
  self.Mode67PeriodUpd = 0
  local unitMaxHP = 0 -- a dummy var instead of _ var
  local f = self.SV_Main.LFGRndAvlFrmt
  local iconVet = self.Textures.GetTexture(10, 24)
  local iconArrDown = self.Textures.GetTexture(13, 24)
  local iconWpnAct = self.Textures.GetTexture(14, 24)
  local WE = WorldEvents
  local sts = WE.CurrentActivePOI.StartTS
  local czi = WE.CurrentZoneId
  local context = WORLD_EVENT_LOCATION_CONTEXT_NONE
  local TS = GetTimeStamp()
  local deltaResp = 0
  if WE.POIEvents[czi] then
    context = WE.POIEvents[czi].WEContext
    deltaResp = WE.POIEvents[czi].RespTimeDelta or 35
  end
  if WE.UNITEvents[czi] then
    context = WE.UNITEvents[czi].WEContext
    deltaResp = WE.UNITEvents[czi].RespTimeDelta or 0
  end
  if WE.MIXEvents[czi] then
    context = WE.MIXEvents[czi].WEContext
    deltaResp = WE.MIXEvents[czi].RespTimeDelta or 0
  end
--
  local RowCnt = #SortedWorldEventsIndex
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(38, RowCnt)
  self:UI_UpdMainWindowHdr()
--
  for i = 1, RowCnt do
    local CWE = CurrentWorldEvents[ SortedWorldEventsIndex[i] ]
    local r = self.ctrlRows[i]
    local txt = ""
    --========================= Units ==============================
    if context == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
      r.BG:SetHidden(true)
      local unitPos = WE.UNITEvents[czi].UnitPos[ SortedWorldEventsIndex[i] ] or ""
      r.Lvl:SetText(unitPos)
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
      txt = CWE.Name
      if CWE.MaxHP > 15000000 then txt = txt .. " " .. iconVet end
      self:SetScaledText(r.Char, txt)
--
      local unitDist = 99999
      if CWE.isActive then unitDist = GetDistanceFromPlayer(CWE.UnitTag) end
--
      r.B[1]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        CWE.CurHP, unitMaxHP, CWE.MaxHP = GetUnitPower(CWE.UnitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
        local percHP = math.floor(100 * CWE.CurHP / CWE.MaxHP) -- / 100
        txt = percHP .. " %"
        if unitDist > 299 then
          r.B[1]:SetColor(self:GetColor(self.Colors.DungStNA))
        end
        if self.Mode67PeriodUpd > 0 then self.Mode67PeriodUpd = 0 end -- let time tick every second
--
      elseif CWE.EndTS > 9999 then
        txt = iconArrDown
        if f == 1 then
          txt = txt .. self:DifTSToStr(TS - CWE.EndTS, true, 0)
        elseif f == 2 then
          txt = txt .. self:TimestampToStr(CWE.EndTS, 6, true)
        else
          txt = txt .. self:TimestampToStr(CWE.EndTS, 7, true)
        end
      else -- EndTS not exist
        r.B[1]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[1], txt)
--
      r.B[2]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        txt = zo_strformat(SI_COMPASS_PIN_DISTANCE_FORMATTER, unitDist)
      --[[
      elseif CWE.ActTime > 0 then
        txt = ZO_FormatTime( CWE.ActTime,
              TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL, TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR):gsub("m.-$","m")
      --]]
      else
        r.B[2]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = zo_strformat(SI_COMPASS_PIN_DISTANCE_FORMATTER, "----")
      end
      self:SetScaledText(r.B[2], txt)
--
      r.B[3]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        txt = " "
      elseif CWE.EndTS > 9999 then
        local nextTime = CWE.EndTS + deltaResp - TS
        if nextTime < 1 then
          txt = GetString(SI_GAMEPAD_GENERIC_WAITING_TEXT)
        else
          txt = ""
          if f == 1 then
            txt = txt .. self:DifTSToStr(nextTime, true, 0)
          elseif f == 2 then
            txt = txt .. self:TimestampToStr(TS + nextTime, 6, true)
          else
            txt = txt .. self:TimestampToStr(TS + nextTime, 7, true)
          end
        end
      else -- EndTS not exist
        r.B[3]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[3], txt)

    --========================== POI ===============================
    elseif context == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
      r.BG:SetHidden( not CWE.isActive )
      if CWE.PinType ~= MAP_PIN_TYPE_POI_COMPLETE then
        r.Lvl:SetText(CWE.PinIcon)
      else
        r.Lvl:SetText(" ")
      end
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
      self:SetScaledText(r.Char, CWE.Name)
--
      r.B[1]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        if sts > 0 then
          txt = iconWpnAct .. self:DifTSToStr(TS - WE.CurrentActivePOI.StartTS, true, 0, true)
        else
          txt = " "
        end
      elseif CWE.EndTS > 9999 then
        txt = iconArrDown
        if f == 1 then
          txt = txt .. self:DifTSToStr(TS - CWE.EndTS, true, 0)
        elseif f == 2 then
          txt = txt .. self:TimestampToStr(CWE.EndTS, 6, true)
        else
          txt = txt .. self:TimestampToStr(CWE.EndTS, 7, true)
        end
      else -- EndTS not exist
        r.B[1]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[1], txt)
--
      r.B[2]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        txt = " "
      elseif CWE.ActTime > 0 then
        txt = ZO_FormatTime( CWE.ActTime,
              TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL, TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR):gsub("m.-$","m")
      else
        r.B[2]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[2], txt)
--
      r.B[3]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        txt = " "
      elseif CWE.EndTS > 9999 then
        if WE.AverageTimeBetweenPOI > 0 then
          local deltaTime = (#SortedWorldEventsIndex - 1) * WE.AverageTimeBetweenPOI
          local nextTime = CWE.EndTS + deltaTime + deltaResp - TS
          if nextTime < 1 then
            txt = GetString(SI_GAMEPAD_GENERIC_WAITING_TEXT)
          else
            txt = ""
            if f == 1 then
              txt = txt .. self:DifTSToStr(nextTime, true, 0)
            elseif f == 2 then
              txt = txt .. self:TimestampToStr(TS + nextTime, 6, true)
            else
              txt = txt .. self:TimestampToStr(TS + nextTime, 7, true)
            end
          end
        else
          r.B[3]:SetColor(self:GetColor(self.Colors.DungStNA))
          txt = self.i18n.WECalculating
        end
      else -- EndTS not exist
        r.B[3]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[3], txt)

    --========================== MIX ===============================
    elseif context == WORLD_EVENT_LOCATION_CONTEXT_MIX then
      local zoneWE = WE.MIXEvents[czi]
      r.BG:SetHidden(true)
      local unitPos = zoneWE.UnitIcon
      if CWE.UnitTag == "" then unitPos = zoneWE.PoiIcon end
      r.Lvl:SetText(unitPos)
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
      txt = CWE.Name
      if zoneWE.Recolor and CWE.Distr then
        txt = zo_strformat("|c<<1>><<2>>|r", zoneWE.Recolor[CWE.Distr], txt)
      end
      self:SetScaledText(r.Char, txt)
      ---
      local unitDist = 99999
      if CWE.isActive then
        if CWE.UnitTag ~= "" then
          unitDist = GetDistanceFromPlayer(CWE.UnitTag)
        else
          unitDist = GetDistancePoiFromPlayer(zoneWE.PZI, zoneWE.POI[CWE.Distr])
        end
      end
      ---
      r.B[1]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        if CWE.UnitTag ~= "" then
          CWE.CurHP, unitMaxHP, CWE.MaxHP = GetUnitPower(CWE.UnitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
          local percHP = math.floor(100 * CWE.CurHP / CWE.MaxHP) -- / 100
          txt = percHP .. " %"
          if unitDist > 299 then r.B[1]:SetColor(self:GetColor(self.Colors.DungStNA)) end
        else
          txt = GetString(SI_SCREEN_NARRATION_ACTIVE_ICON_NARRATION) -- "Активно"
        end
        if self.Mode67PeriodUpd > 0 then self.Mode67PeriodUpd = 0 end -- let time tick every second
      ---
      elseif CWE.EndTS >= TS then
        txt = GetString(SI_GAMEPAD_GENERIC_WAITING_TEXT) -- :gsub("%A","")
      ---
      elseif CWE.EndTS > 9999 then
        txt = iconArrDown
        if f == 1 then
          txt = txt .. self:DifTSToStr(TS - CWE.EndTS, true, 0)
        elseif f == 2 then
          txt = txt .. self:TimestampToStr(CWE.EndTS, 6, true)
        else
          txt = txt .. self:TimestampToStr(CWE.EndTS, 7, true)
        end
      else -- EndTS not exist
        r.B[1]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[1], txt)
      ---
      r.B[2]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        txt = zo_strformat(SI_COMPASS_PIN_DISTANCE_FORMATTER, unitDist)
      else
        r.B[2]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = zo_strformat(SI_COMPASS_PIN_DISTANCE_FORMATTER, "----")
      end
      self:SetScaledText(r.B[2], txt)
      ---
      r.B[3]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if CWE.isActive then
        txt = " "
      elseif CWE.EndTS >= TS then
        if f == 1 then
          txt = self:DifTSToStr(CWE.EndTS - TS, true, 0)
        elseif f == 2 then
          txt = self:TimestampToStr(CWE.EndTS, 6, true)
        else
          txt = self:TimestampToStr(CWE.EndTS, 7, true)
        end
      elseif CWE.EndTS > 9999 then
        local nextTime = CWE.EndTS + deltaResp - TS
        if nextTime < 1 then
          txt = GetString(SI_GAMEPAD_GENERIC_WAITING_TEXT)
        else
          if f == 1 then
            txt = self:DifTSToStr(nextTime, true, 0)
          elseif f == 2 then
            txt = self:TimestampToStr(TS + nextTime, 6, true)
          else
            txt = self:TimestampToStr(TS + nextTime, 7, true)
          end
        end
      else -- EndTS not exist
        r.B[3]:SetColor(self:GetColor(self.Colors.DungStNA))
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[3], txt)

    --========================= None ===============================
    else
      r.BG:SetHidden(true)
      r.Lvl:SetText(" ")
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
      self:SetScaledText(r.Char, CWE.Name)
      self:SetScaledText(r.B[1], " ")
      self:SetScaledText(r.B[2], " ")
      self:SetScaledText(r.B[3], " ")
    end
--
    r.Row:SetHidden(false)
  end
---- esoui/art/mappins/dragon_fly_damaged. dds
---- esoui/art/mappins/dragon_fly. dds
end -- UpdWindowModeWorldEvents end
