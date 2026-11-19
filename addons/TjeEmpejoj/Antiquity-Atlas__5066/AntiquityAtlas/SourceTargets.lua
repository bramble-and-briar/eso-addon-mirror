-- Original numeric lead-to-instance routes; geography comes from LibZone public APIs.
-- No LibSets/LibZone geographic tables are redistributed.
local A = AntiquityAtlas
A.InstanceZones = {}
A.LeadInstances = {
    [61] = {287},
    [62] = {337},
    [63] = {265},
    [64] = {329},
    [66] = {413},
    [67] = {899},
    [68] = {22},
    [69] = {930},
    [70] = {169},
    [71] = {1187},
    [74] = {63},
    [75] = {895},
    [76] = {890},
    [105] = {1182},
    [107] = {1187},
    [108] = {1165},
    [111] = {1020},
    [116] = {449},
    [119] = {533, 531, 494, 505},
    [120] = {1186},
    [122] = {126},
    [123] = {284},
    [125] = {1066, 1073},
    [127] = {38},
    [130] = {216},
    [132] = {706},
    [133] = {142},
    [136] = {130},
    [137] = {557},
    [138] = {144},
    [139] = {134},
    [249] = {706},
    [254] = {148},
    [264] = {1196, 1201, 1197},
    [269] = {1134, 1135},
    [289] = {1081},
    [308] = {638, 636, 639},
    [335] = {1224},
    [336] = {284},
    [338] = {330},
    [341] = {932},
    [342] = {380},
    [343] = {124},
    [345] = {1214},
    [346] = {1214},
    [347] = {1214},
    [348] = {1214},
    [349] = {1214},
    [350] = {1214},
    [351] = {1214},
    [384] = {635},
    [386] = {11},
    [388] = {906},
    [389] = {936},
    [390] = {1260},
    [392] = {843},
    [396] = {1259},
    [398] = {848},
    [400] = {306},
    [443] = {380, 935},
    [448] = {974},
    [449] = {1228},
    [452] = {1310},
    [462] = {1121},
    [463] = {1122},
    [464] = {1123},
    [465] = {1310},
    [466] = {678},
    [469] = {487},
    [511] = {1344},
    [521] = {162},
    [524] = {1334},
    [528] = {486},
    [531] = {935},
    [533] = {1302},
    [537] = {1338},
    [538] = {919},
    [546] = {146},
    [549] = {933},
    [552] = {1374},
    [554] = {176},
    [555] = {1375},
    [557] = {1389},
    [559] = {1399},
    [562] = {925},
    [563] = {1361},
    [564] = {1301},
    [565] = {919, 918},
    [566] = {1415},
    [573] = {1397},
    [574] = {1390},
    [576] = {1416},
    [583] = {934},
    [584] = {923},
    [591] = {1396},
    [593] = {405},
    [594] = {283},
    [599] = {1400},
    [612] = {1398},
    [614] = {985},
    [626] = {1401},
    [628] = {697},
    [669] = {1447},
    [670] = {705},
    [671] = {22},
    [672] = {327},
    [673] = {975},
    [674] = {1448},
    [677] = {1122},
    [678] = {1090},
    [679] = {291},
    [682] = {677},
    [683] = {487},
    [699] = {1467},
    [701] = {1445},
    [702] = {1446},
    [704] = {1449},
    [706] = {1466},
    [708] = {1444},
    [719] = {1512},
    [720] = {1514},
    [722] = {1511},
    [723] = {1081},
    [724] = {1090},
    [725] = {725},
    [726] = {1089},
    [727] = {725},
    [729] = {1081},
    [731] = {137},
    [732] = {1513},
    [733] = {467},
    [754] = {694},
    [756] = {1055},
    [758] = {1052},
    [759] = {1528},
    [760] = {1530},
    [762] = {1529},
    [767] = {1527},
    [790] = {1267},
}
A.PendingInstanceSources = {}
-- These entries also allow outdoor/world-boss sources in the same region.
A.LeadSourceRegions = { [125] = {726}, [264] = {1160}, [269] = {1133},
    [345] = {1208}, [346] = {1208}, [347] = {1208}, [348] = {1208},
    [349] = {1208}, [350] = {1208}, [351] = {1208}, [473] = {1318,1011} }
-- Broad sources remain regional; no arbitrary single delve is selected.
A.RegionInstanceSources = { [344] = true, [399] = true }
A.SourceZones = {}
for _, zone in pairs(A.InstanceZones) do table.insert(A.SourceZones, zone) end
A.SourceDetails = {
    [61] = { zone = 287, boss = "Zozuzetharus" },
    [62] = { zone = 337, boss = "Klathzgar's Centurion" },
    [64] = { zone = 329, boss = "Thinks-in-Gears" },
    [66] = { zone = 413, boss = "Thzallek Eft" },
    [338] = { zone = 330, boss = "Feremuzh" },
}
function A.SourceDetail(part)
    return A.SourceDetails[part.id]
end
function A.RefreshGeography()
    if type(LibZone) ~= "table" or type(LibZone.GetZoneMapPinInfo) ~= "function"
        or type(LibZone.GetZoneGeographicalParentZoneId) ~= "function" then
        return false, "Antiquity Atlas: LibZone 9.01 or newer is required."
    end
    local zones = {}
    for _, ids in pairs(A.LeadInstances) do
        for _, id in ipairs(ids) do
            if not zones[id] then
                local parent, _, poiIndex, valid = LibZone:GetZoneMapPinInfo(id)
                parent = parent or LibZone:GetZoneGeographicalParentZoneId(id) or id
                zones[id] = {id = id, parent = parent,
                    name = zo_strformat("<<C:1>>", GetZoneNameById(id))}
                if valid and type(poiIndex) == "number" and poiIndex > 0 then
                    zones[id].poiIndex = poiIndex
                end
            end
        end
    end
    A.InstanceZones, A.SourceZones = zones, {}
    for _, zone in pairs(zones) do table.insert(A.SourceZones, zone) end
    return true
end
function A.SourceLabel(en, ru)
    return (A.language or (GetCVar and GetCVar("language.2"))) == "ru" and ru or en
end
-- High Isle native POI order: Ghost Haven Bay 12, Whalefall 17;
-- world-boss POIs follow the six delves (19 through 24).
A.WorldBossSources = {
    [472] = {id=1318,parent=1318,poiIndex=24,worldBoss=true,name="Mornard Falls"},
    [475] = {id=1318,parent=1318,poiIndex=20,worldBoss=true,name="Serpent Bog"},
    [520] = {id=1318,parent=1318,poiIndex=21,worldBoss=true,name="Faun Falls"},
}
function A.ResolveSourceZones(part)
    local targets = {}
    if A.WorldBossSources[part.id] then table.insert(targets, A.WorldBossSources[part.id]) end
    for _, id in ipairs(A.LeadInstances[part.id] or {}) do
        local target = A.InstanceZones[id]
        if target then table.insert(targets, target) end
    end
    for _, id in ipairs(A.LeadSourceRegions[part.id] or {}) do
        table.insert(targets, {id = id, parent = id, region = true})
    end
    return targets
end
-- Numeric API lookup only. Fail closed if an API gives an inconsistent region/index.
function A.SourcePOIIndices(target)
    if not target or target.region then return end
    local zi, pi
    if target.poiIndex then
        zi, pi = A.Call(GetZoneIndex, target.parent), target.poiIndex
    elseif target.poi and type(GetPOIIndices) == "function" then
        zi, pi = GetPOIIndices(target.poi)
    elseif target.node and type(GetFastTravelNodePOIIndicies) == "function" then
        zi, pi = GetFastTravelNodePOIIndicies(target.node)
    end
    if zi and zi > 0 and pi and pi > 0 then
        local actualZone = A.Call(GetZoneId, zi)
        if actualZone and actualZone ~= target.parent then return end
        local count = A.Call(GetNumPOIs, zi)
        if count and pi > count then return end
        return zi, pi
    end
end
function A.CheckSourceLocation(part, target)
    return A.SourcePOIIndices(target) ~= nil
end
function A.InstanceMapZone(target)
    return (target.node or target.poi or target.poiIndex) and target.parent or target.id
end
-- GetMapIdByZoneId does not resolve every interior map. The supplied LibZone
-- map workbook contains map IDs through 2728. Read numeric map metadata once;
-- its fourth return is a zoneIndex, which must be converted with GetZoneId.
-- No map is opened and no localized name participates in this lookup.
A.MapIdScanLimit = 2728
-- Explicit shared-map aliases: the map metadata can name a parent or the
-- other Atoll variant. Validate the exact map asset before using these IDs.
A.InstanceMapOverrides = {
    [1182] = {{id = 1754, key = "morthalburialcave_base"}},
    [1310] = {{id = 2000, key = "u30_oblivion_portal_base"}, {id = 2054, key = "u30_oblivion_portal_boss_base"}},
}
-- Both Atoll variants share map assets and can report the older zone 1272.
-- Include all matching floors, including the tower, using exact asset IDs.
A.SharedInstanceMapAssets = {
    [1272] = {zone = 1310, keys = {u30_oblivion_portal_base = true,
        u30_oblivion_portal_tower_base = true, u30_oblivion_portal_boss_base = true}},
}
function A.MapTextureKey(texture)
    if type(texture) ~= "string" then return nil end
    local key = A.Lower(texture):match("[^/\\]+$")
    if not key then return nil end
    return key:gsub("%.dds$", ""):gsub("_%d+$", "")
end
function A.MapKeyForId(id)
    return A.MapTextureKey(A.Call(GetMapTileTextureForMapId, id, 1))
end
function A.BuildInstanceMapIndex()
    if A.instanceMapIds and A.instanceMapLists then return end
    if type(GetMapInfoById) ~= "function" or type(GetZoneId) ~= "function" then return end
    local maps, lists = {}, {}
    local function add(zone, id)
        if not maps[zone] then maps[zone] = id end
        lists[zone] = lists[zone] or {}
        for _, existing in ipairs(lists[zone]) do if existing == id then return end end
        table.insert(lists[zone], id)
    end
    local limit = math.max(A.MapIdScanLimit, A.Call(GetNumMaps) or 0)
    -- Map IDs are sparse and are not map indices. Probing a missing ID can raise an
    -- ESO API error, so protect only this probe, not ordinary calls on known IDs.
    for candidate = 1, limit do
        local ok, _, mapType, _, zoneIndex = pcall(GetMapInfoById, candidate)
        if ok and type(zoneIndex) == "number" and zoneIndex > 0
            and (MAPTYPE_NONE == nil or mapType ~= MAPTYPE_NONE) then
            local id = A.Call(GetZoneId, zoneIndex)
            if id and A.InstanceZones[id] then add(id, candidate) end
            local shared = id and A.SharedInstanceMapAssets[id]
            if shared and shared.keys[A.MapKeyForId(candidate)] then add(shared.zone, candidate) end
        end
    end
    for zone, records in pairs(A.InstanceMapOverrides) do
        for index, record in ipairs(records) do
            if A.MapKeyForId(record.id) == record.key then
                add(zone, record.id)
                if index == 1 then maps[zone] = record.id end
            end
        end
    end
    A.instanceMapIds, A.instanceMapLists = maps, lists
end
function A.ResolveZoneMap(zoneId)
    local mapIndex = A.Call(GetMapIndexByZoneId, zoneId)
    local mapId = A.Call(GetMapIdByZoneId, zoneId)
    if (mapIndex and mapIndex > 0) or (mapId and mapId > 0) then return mapIndex, mapId end
    A.BuildInstanceMapIndex()
    return nil, A.instanceMapIds and A.instanceMapIds[zoneId]
end
function A.AuditSources()
    local leads, entrances, interiors, missing = 0, 0, 0, 0
    for _ in pairs(A.LeadInstances) do leads = leads + 1 end
    for _, target in pairs(A.InstanceZones) do
        local mapZone = A.InstanceMapZone(target)
        local mapIndex, mapId = A.ResolveZoneMap(mapZone)
        if (mapId and mapId > 0) or (mapIndex and mapIndex > 0) then
            if target.poiIndex or target.poi or target.node then
                if A.CheckSourceLocation(nil, target) then entrances = entrances + 1
                else missing = missing + 1; d("Antiquity Atlas: entrance ID unavailable in client: " .. target.id) end
            else interiors = interiors + 1 end
        else missing = missing + 1; d("Antiquity Atlas: map ID not resolved: " .. target.id) end
    end
    d("Antiquity Atlas: " .. leads .. " lead routes; " .. entrances .. " entrance IDs checked; " .. interiors .. " interior maps; " .. missing .. " unavailable. Coordinates checked after opening map.")
    return leads, missing
end
