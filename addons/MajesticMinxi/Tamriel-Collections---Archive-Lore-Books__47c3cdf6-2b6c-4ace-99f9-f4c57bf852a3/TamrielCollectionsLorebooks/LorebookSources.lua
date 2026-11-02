-- Per-book acquisition information. The game remains the ownership authority.
local TC = TamrielCollections
local Sources = {}
TC.lorebookSources = Sources
local nativeBooks
local mapNames, mapTextures, mapIds, mapReady, mapBuilding, readyCallbacks
local resolvedMaps = {}

local function Text(value) return zo_strformat(value or '') end
local function Key(value)
    return (zo_strlower(Text(value)):gsub('’', "'"):gsub('‘', "'"):gsub('|c%x%x%x%x%x%x', ''):gsub('|r', '')
        :gsub('%^.*$', ''):gsub('[%p%c]+', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function NativeBooks()
    if nativeBooks then return nativeBooks end
    local result = {}
    local kind = ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS
    if not (kind and GetNextZoneStoryZoneId and GetNumZoneActivitiesForZoneCompletionTypeAndIndex
        and GetZoneActivityIdForZoneCompletionType) then return result end
    local zoneId, visited = GetNextZoneStoryZoneId(), {}
    while zoneId and not visited[zoneId] do
        visited[zoneId] = true
        local count = GetNumZoneActivitiesForZoneCompletionTypeAndIndex(zoneId, kind) or 0
        for index = 1, count do
            local id = GetZoneActivityIdForZoneCompletionType(zoneId, kind, index)
            if id and id > 0 then
                result[id] = result[id] or {}
                result[id][#result[id] + 1] = {
                    zoneId = zoneId, activityId = id,
                    title = GetZoneStoryActivityNameByActivityId and Text(GetZoneStoryActivityNameByActivityId(zoneId, kind, id)) or '',
                }
            end
        end
        zoneId = GetNextZoneStoryZoneId(zoneId)
    end
    if next(result) then nativeBooks = result end
    return result
end

local function TextureKey(texture)
    local name = (texture or ''):lower():match('([^/]+)$') or ''
    name = name:gsub('%.dds$', ''):gsub('[_%-]%d+[_%d%-]*$', ''):gsub('_base$', '')
    return Key(name)
end

local function AddMap(id, index, name, zoneIndex)
    if not name or name == '' then return end
    local identity = id or ('index:' .. tostring(index))
    if mapIds[identity] then return end
    local texture = id and GetMapTileTextureForMapId and GetMapTileTextureForMapId(id, 1) or ''
    local entry = { mapId = id, mapIndex = index, name = Key(name), texture = texture or '', zoneIndex = zoneIndex, zones = {} }
    local zoneId = zoneIndex and GetZoneId and GetZoneId(zoneIndex)
    local seen = {}
    if zoneIndex and GetZoneNameByIndex then entry.zones[Key(GetZoneNameByIndex(zoneIndex))] = true end
    while zoneId and zoneId > 0 and not seen[zoneId] do
        seen[zoneId] = true
        if GetZoneNameById then entry.zones[Key(GetZoneNameById(zoneId))] = true end
        -- Some quest/dungeon zone IDs are their own parent. The game's
        -- Zone Guide still supplies their enclosing collection zone.
        local storyZoneId = GetZoneStoryZoneIdForZoneId and GetZoneStoryZoneIdForZoneId(zoneId)
        if storyZoneId and storyZoneId > 0 and GetZoneNameById then
            entry.zones[Key(GetZoneNameById(storyZoneId))] = true
        end
        zoneId = GetParentZoneId and GetParentZoneId(zoneId)
    end
    mapIds[identity] = entry
    mapNames[entry.name] = mapNames[entry.name] or {}
    table.insert(mapNames[entry.name], entry)
    local textureKey = TextureKey(texture)
    if textureKey ~= '' then
        mapTextures[textureKey] = mapTextures[textureKey] or {}
        table.insert(mapTextures[textureKey], entry)
    end
end

-- GetNumMaps enumerates the zone menu, not all interior/floor map IDs.
-- Read the complete ID catalogue once in bounded chunks without changing the
-- player's map. No continuing timer or map-changing scan is installed.
function Sources.WarmMaps(callback)
    readyCallbacks = readyCallbacks or {}
    if callback then
        if mapReady then callback() else table.insert(readyCallbacks, callback) end
    end
    if mapBuilding or mapReady then return end
    mapBuilding = true
    mapNames, mapTextures, mapIds = {}, {}, {}
    local maximum = 8192
    if GetNumMaps and GetMapInfoByIndex then
        for index = 1, GetNumMaps() do
            local name, _, _, zoneIndex = GetMapInfoByIndex(index)
            local id = GetMapIdByIndex and GetMapIdByIndex(index)
            if id and id <= 0 then id = nil end
            if id then maximum = math.max(maximum, id + 2048) end
            AddMap(id, index, name, zoneIndex)
        end
    end
    local nextId = 1
    local function Finish()
        mapReady, mapBuilding = true, false
        if Sources.AuditMaps then Sources.AuditMaps() end
        local callbacks = readyCallbacks
        readyCallbacks = {}
        for _, ready in ipairs(callbacks) do ready() end
    end
    if not GetMapInfoById then Finish(); return end
    local function Step()
        local last = math.min(nextId + 127, maximum)
        for id = nextId, last do
            local name, _, _, zoneIndex = GetMapInfoById(id)
            if name and name ~= '' then
                AddMap(id, GetMapIndexById and GetMapIndexById(id), name, zoneIndex)
            end
        end
        nextId = last + 1
        if nextId > maximum then Finish()
        elseif zo_callLater then zo_callLater(Step, 0)
        else Step() end
    end
    Step()
end

local function ChooseMap(candidates, context)
    if not candidates or #candidates == 0 then return nil end
    if #candidates == 1 then return candidates[1] end
    local narrowed, bestScore = {}, 0
    for _, entry in ipairs(candidates) do
        local score, weight = 0, 1
        for part in (context or ''):gmatch('[^/]+') do
            if entry.zones[Key(part)] then score = score + weight end
            weight = weight + 1
        end
        if score > bestScore then narrowed, bestScore = { entry }, score
        elseif score > 0 and score == bestScore then table.insert(narrowed, entry) end
    end
    if #narrowed == 1 then return narrowed[1] end
    if #narrowed == 0 then narrowed = candidates end
    local first = narrowed[1]
    -- Multiple map IDs can be alternate instances of the identical floor.
    -- Require both its full texture and native name to agree before sharing XY.
    if first.texture == '' then return nil end
    for _, entry in ipairs(narrowed) do
        if entry.texture ~= first.texture or entry.name ~= first.name or entry.zoneIndex ~= first.zoneIndex then return nil end
    end
    return first
end

local function ResolveMap(name, context)
    Sources.WarmMaps()
    local identity = name .. '\n' .. (context or '')
    if mapReady and resolvedMaps[identity] ~= nil then return resolvedMaps[identity] or nil end
    local function Remember(target)
        if mapReady then resolvedMaps[identity] = target or false end
        return target
    end
    local hints = TC.lorebookMapHints and TC.lorebookMapHints[name] or {}
    for _, hint in ipairs(hints) do
        local found = ChooseMap(mapTextures[Key(hint[1])], context ~= '' and context or hint[2])
        if found then return Remember(found) end
    end
    local exact = ChooseMap(mapNames[Key(name)], context)
    if exact then return Remember(exact) end
    -- UESP qualifies floor names with the dungeon/parent name. Match the
    -- explicit floor, never project interior XY onto its surrounding zone.
    local floor = name:match(':%s*(.+)$') or name:match('%(([^()]+)%)$')
    return Remember(floor and ChooseMap(mapNames[Key(floor)], context) or nil)
end

local auditBuilding
function Sources.AuditMaps()
    if not mapReady then return nil end
    if auditBuilding then return TC.lorebookMapAudit end
    auditBuilding = true
    local seen, report = {}, { resolved = 0, unresolved = 0, unresolvedMaps = {} }
    local tables = { TC.lorebookLocationData or {}, TC.lorebookAcquisitionData or {} }
    local sourceIndex, key, records, index = 1, nil, nil, 1
    local function Step()
        local started = GetGameTimeMilliseconds and GetGameTimeMilliseconds()
        for unit = 1, 64 do
            local record = records and records[index]
            if record then
                local identity = record[1] .. '\n' .. (record[6] or '')
                if not seen[identity] then
                    seen[identity] = true
                    if ResolveMap(record[1], record[6] or '') then report.resolved = report.resolved + 1
                    else
                        report.unresolved = report.unresolved + 1
                        table.insert(report.unresolvedMaps, identity)
                    end
                end
                index = index + 1
            else
                local value
                key, value = next(tables[sourceIndex], key)
                if key then
                    records = sourceIndex == 1 and value or value.points
                    index = 1
                else
                    sourceIndex, records, index = sourceIndex + 1, nil, 1
                    if not tables[sourceIndex] then
                        auditBuilding = false
                        TC.lorebookMapAudit = report
                        return
                    end
                end
            end
            if started and GetGameTimeMilliseconds() - started >= 4 then break end
        end
        if zo_callLater then zo_callLater(Step, 10) else return Step() end
    end
    if zo_callLater then zo_callLater(Step, 10) else Step() end
    return TC.lorebookMapAudit
end

local function MailSource(collection)
    local name = Key(collection.name)
    local favors = {
        ['lady arabelle davaux'] = { 'Glenumbra / Aldcroft', 'Complete Lady Arabelle\'s Favors at the Freerunner\'s Post in Aldcroft. Further Favors unlock the next letters.' },
        ['lady arabelle'] = { 'Glenumbra / Aldcroft', 'Complete Lady Arabelle\'s Favors at the Freerunner\'s Post in Aldcroft. Further Favors unlock the next letters.' },
        ['holgunn one eye'] = { 'Stonefalls / Ebonheart', 'Complete Holgunn One-Eye\'s Favors at the Freerunner\'s Post in Ebonheart. Further Favors unlock the next letters.' },
        ['battlereeve urcelmo'] = { 'Auridon / Skywatch', 'Complete Battlereeve Urcelmo\'s Favors at the Freerunner\'s Post in Skywatch. Further Favors unlock the next letters.' },
    }
    if favors[name] then return { location = favors[name][1], description = favors[name][2] } end
    local mailType = GetMailListType and GetMailListType(collection.mailListIndex)
    if MAIL_LIST_TYPE_HIRELING and mailType == MAIL_LIST_TYPE_HIRELING then
        return { location = 'Crafting hireling mail',
            description = 'Unlock the Hireling passive in the relevant crafting skill line, then receive and collect the hireling\'s mail.' }
    end
    return { location = 'Correspondence / ' .. collection.name,
        description = 'Receive this sender\'s letters through their associated quests or crafting hireling. Collected letters are saved in the Lore Library.' }
end

local function Geometry(record)
    local id = record[1] .. '\n' .. (record[6] or '')
    return TC.lorebookMapGeometry and TC.lorebookMapGeometry[id], id
end

local function RecordInZone(record, zone)
    if not zone then return true end
    local geometry, identity = Geometry(record)
    local memberships = TC.lorebookMapZones and TC.lorebookMapZones[identity]
    if memberships then return memberships[zone] == true end
    if geometry and TC.lorebookZoneNames and TC.lorebookZoneNames[geometry[3]] then
        return geometry[3] == zone
    end
    local target = ResolveMap(record[1], record[6] or '')
    return target and target.zones[zone] == true or false
end

local function PointSource(record, book)
    local target = ResolveMap(record[1], record[6] or '')
    local geometry, identity = Geometry(record)
    local x, y = record[2] * (geometry and geometry[1] or 1), record[3] * (geometry and geometry[2] or 1)
    local overrides = book and book.bookId and TC.lorebookLocationNotes and TC.lorebookLocationNotes[book.bookId]
    local note = overrides and overrides[identity] or record[4]
    local description = string.format('Read the book at the reported map location (%.1f%%, %.1f%%).', x * 100, y * 100)
    if note and note ~= '' then
        description = note .. string.format(' (%.1f%%, %.1f%%).', x * 100, y * 100)
    end
    return { location = record[6] and record[6] ~= '' and (record[6] .. ' / ' .. record[1]) or record[1],
        description = description, mapName = record[1], context = record[6] or '',
        mapId = target and target.mapId, mapIndex = target and target.mapIndex,
        x = x, y = y, verified = true }
end

local function Points(book)
    local collection = book.collection
    local nameKey, collectionKey = Key(book.name), Key(collection.name)
    local acquisition = book.bookId and TC.lorebookAcquisitionData and TC.lorebookAcquisitionData[book.bookId]
    local points = {}
    local ambiguous = TC.lorebookAmbiguousTitles and TC.lorebookAmbiguousTitles[nameKey]
    ambiguous = ambiguous and ambiguous[collectionKey]
    local records = not ambiguous and TC.lorebookLocationData and TC.lorebookLocationData[nameKey]
    for _, record in ipairs(records or {}) do
        if record[5] == '' or Key(record[5]) == collectionKey then table.insert(points, record) end
    end
    for _, record in ipairs(acquisition and acquisition.points or {}) do table.insert(points, record) end
    return points, acquisition
end

function Sources.GetZones()
    local result = { { name = 'All locations' } }
    local zones = {}
    for key, name in pairs(TC.lorebookZoneNames or {}) do zones[#zones + 1] = { key = key, name = name } end
    table.sort(zones, function(a, b) return Key(a.name) < Key(b.name) end)
    for _, zone in ipairs(zones) do result[#result + 1] = zone end
    return result
end

function Sources.InZone(book, zone)
    if not zone then return true end
    -- Source membership does not depend on read status or the selected zone.
    -- Resolve all memberships once per book, then subsequent zones use a lookup.
    -- Map ancestry becomes complete after WarmMaps, so pre-warm results expire.
    local zones = book._tclSourceZones
    if not zones or book._tclSourceZonesMapReady ~= (mapReady == true) then
        zones = {}
        if book.collection.mailListIndex then
            local location = Key(MailSource(book.collection).location)
            for key in pairs(TC.lorebookZoneNames or {}) do
                if location:find(key, 1, true) then zones[key] = true end
            end
        elseif TC.lorebookGlobalBookshelfSources and TC.lorebookGlobalBookshelfSources[book.bookId] then
            zones.all = true
        else
            local named = TC.lorebookAcquisitionZones and TC.lorebookAcquisitionZones[book.bookId]
            for key, included in pairs(named or {}) do if included then zones[key] = true end end
            for _, record in ipairs(Points(book)) do
                local geometry, identity = Geometry(record)
                local memberships = TC.lorebookMapZones and TC.lorebookMapZones[identity]
                if memberships then
                    for key, included in pairs(memberships) do if included then zones[key] = true end end
                elseif geometry and TC.lorebookZoneNames and TC.lorebookZoneNames[geometry[3]] then
                    zones[geometry[3]] = true
                else
                    local target = ResolveMap(record[1], record[6] or '')
                    for key, included in pairs(target and target.zones or {}) do
                        if included then zones[key] = true end
                    end
                end
            end
            for _, candidate in ipairs(book.bookId and NativeBooks()[book.bookId] or {}) do
                if (candidate.title == '' or Key(candidate.title) == Key(book.name)) and GetZoneNameById then
                    zones[Key(GetZoneNameById(candidate.zoneId))] = true
                end
            end
        end
        book._tclSourceZones = zones
        book._tclSourceZonesMapReady = mapReady == true
    end
    return zones.all == true or zones[zone] == true
end

function Sources.Get(book, zone)
    if not book then return nil end
    local collection = book.collection
    if collection.mailListIndex then return MailSource(collection) end
    local points, acquisition = Points(book)
    local fallback
    for _, record in ipairs(points) do
        if RecordInZone(record, zone) then
            local source = PointSource(record, book)
            fallback = fallback or source
            if source.mapId or source.mapIndex then return source end
        end
    end
    -- Prefer a saved exact position over a Zone Guide route that can expose
    -- only the surrounding zone or hide the book's position on this floor.
    local candidates = book.bookId and NativeBooks()[book.bookId]
    if candidates then
        for _, candidate in ipairs(candidates) do
            if (candidate.title == '' or Key(candidate.title) == Key(book.name)) and
                (not zone or GetZoneNameById and Key(GetZoneNameById(candidate.zoneId)) == zone) then
                local zone = GetZoneNameById and Text(GetZoneNameById(candidate.zoneId)) or ''
                local description = GetZoneStoryShortDescriptionByActivityId
                    and Text(GetZoneStoryShortDescriptionByActivityId(candidate.zoneId, ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS, candidate.activityId)) or ''
                return { location = zone ~= '' and zone or collection.name,
                    description = description ~= '' and description or 'Find and read this lorebook in this zone. Show on Map opens the location supplied by the Zone Guide.',
                    zoneId = candidate.zoneId, activityId = candidate.activityId,
                    mapId = GetMapIdByZoneId and GetMapIdByZoneId(candidate.zoneId) }
            end
        end
    end
    if fallback then return fallback end
    if acquisition and (not zone or Sources.InZone(book, zone)) then
        if zone then
            local label = TC.lorebookZoneNames and TC.lorebookZoneNames[zone] or zone
            local notes = TC.lorebookAcquisitionByZone and TC.lorebookAcquisitionByZone[book.bookId]
            local note = notes and notes[zone]
            local global = TC.lorebookGlobalBookshelfSources and TC.lorebookGlobalBookshelfSources[book.bookId]
            return { location = label, description = note or (global and acquisition.description)
                or ('A source in ' .. label .. ' is recorded for this book. Exact directions have not been verified.'), verified = true }
        end
        return { location = acquisition.location, description = acquisition.description, verified = true }
    end
    return { location = 'Location not yet verified', description = collection.description ~= ''
        and collection.description or 'A verified acquisition location has not been added for this book yet.' }
end

function Sources.CanMap(source)
    if not (source and WORLD_MAP_MANAGER and ZO_WorldMap_ShowWorldMap) then return false end
    if source.mapName and not (source.mapId or source.mapIndex) then
        local target = ResolveMap(source.mapName, source.context or '')
        if target then source.mapId, source.mapIndex = target.mapId, target.mapIndex end
    end
    return (source.mapId and source.mapId > 0 and type(WORLD_MAP_MANAGER.SetMapById) == 'function')
        or (source.mapIndex and type(WORLD_MAP_MANAGER.SetMapByIndex) == 'function') or false
end

local mapRequest = 0
local mapContext, parentCallbackInstalled

local function EntrancePosition(name)
    local exact = Key(name)
    local wanted = exact:gsub('%s+[ivx]+$', '')
    if wanted == '' then return end
    local foundX, foundY, bestRank, ambiguous = nil, nil, 0, false
    local function Match(label, x, y)
        local key = Key(label)
        local rank = key == exact and 2 or (key:gsub('%s+[ivx]+$', '') == wanted and 1 or 0)
        if rank == 0 or rank < bestRank then return end
        if not x or not y or x <= 0 or x >= 1 or y <= 0 or y >= 1 then return end
        if rank > bestRank then foundX, foundY, ambiguous, bestRank = nil, nil, false, rank end
        if foundX and (math.abs(foundX - x) > 0.001 or math.abs(foundY - y) > 0.001) then ambiguous = true end
        foundX, foundY = x, y
    end
    local zoneIndex = GetCurrentMapZoneIndex and GetCurrentMapZoneIndex()
    if zoneIndex and GetNumPOIs and GetPOIInfo and GetPOIMapInfo then
        for index = 1, GetNumPOIs(zoneIndex) do
            local label = GetPOIInfo(zoneIndex, index)
            local x, y, _, _, shown = GetPOIMapInfo(zoneIndex, index)
            if shown then Match(label, x, y) end
        end
    end
    if not foundX and GetNumMapLocations and GetMapLocationTooltipHeader and GetMapLocationIcon then
        for index = 1, GetNumMapLocations() do
            local label = GetMapLocationTooltipHeader(index)
            local _, x, y = GetMapLocationIcon(index)
            Match(label, x, y)
        end
    end
    if not ambiguous then return foundX, foundY end
end

local function WatchParentMap(source)
    if not (CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback and GetCurrentMapId) then return end
    mapContext = { source = source, mapId = GetCurrentMapId(), request = mapRequest }
    if parentCallbackInstalled then return end
    parentCallbackInstalled = true
    CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged', function(navigateIn)
        local context = mapContext
        if not context or context.request ~= mapRequest then return end
        local parentId, childId = GetCurrentMapId(), context.mapId
        if parentId == childId then return end
        context.mapId = parentId
        -- Only follow the native outward navigation. Selecting another map or
        -- entering another destination ends this book's navigation context.
        if navigateIn ~= false then mapContext = nil; return end
        local pins = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
        if pins then pins:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE') end
        local function CenterEntrance()
            if mapContext ~= context or context.request ~= mapRequest or GetCurrentMapId() ~= parentId then return end
            local name = GetMapNameById and GetMapNameById(childId)
            local x, y = EntrancePosition(name or '')
            if not x then x, y = EntrancePosition(context.source.mapName or '') end
            if not x then
                -- Floor names can be generic; the saved context names the
                -- enclosing dungeon/city. Never reuse indoor XY outside it.
                local parts = {}
                for part in (context.source.context or ''):gmatch('[^/]+') do parts[#parts + 1] = part end
                for index = #parts, 1, -1 do
                    x, y = EntrancePosition(parts[index])
                    if x then break end
                end
            end
            local manager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
            local pan = ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom()
            if x and manager and pan then
                manager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE')
                local pin = manager:CreatePin(MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE', x, y)
                if pin then pan:JumpToPin(pin) end
            end
        end
        if zo_callLater then zo_callLater(CenterEntrance, 150) else CenterEntrance() end
    end)
end

function Sources.CancelMap()
    mapRequest = mapRequest + 1
    mapContext = nil
    local pins = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
    if pins then pins:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE') end
end

function Sources.ShowMap(source)
    if not Sources.CanMap(source) then return false end
    if WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then return false end
    mapRequest = mapRequest + 1
    mapContext = nil
    local request = mapRequest
    local oldPins = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
    if oldPins then oldPins:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE') end
    ZO_WorldMap_ShowWorldMap()
    local function SetTarget()
        if source.mapId and WORLD_MAP_MANAGER.SetMapById then WORLD_MAP_MANAGER:SetMapById(source.mapId)
        elseif source.mapIndex then WORLD_MAP_MANAGER:SetMapByIndex(source.mapIndex) end
    end
    SetTarget()
    local attempts = 0
    local function Place()
        if request ~= mapRequest then return end
        attempts = attempts + 1
        local correct
        if source.mapId and GetCurrentMapId then correct = GetCurrentMapId() == source.mapId
        elseif source.mapIndex and GetCurrentMapIndex then correct = GetCurrentMapIndex() == source.mapIndex end
        local x, y = source.x, source.y
        if correct and source.zoneId and GetNormalizedPositionForZoneStoryActivityId then
            local radius, visible
            x, y, radius, visible = GetNormalizedPositionForZoneStoryActivityId(source.zoneId, ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS, source.activityId)
            if not visible then x, y = nil, nil end
        end
        if not correct or not x or not y or x <= 0 or x >= 1 or y <= 0 or y >= 1 then
            if not correct then SetTarget() end
            if attempts < 20 and zo_callLater then zo_callLater(Place, 50)
            elseif ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS and SOUNDS.NEGATIVE_CLICK, 'The book position could not be shown on this map.') end
            return
        end
        local pins = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager()
        local pan = ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom()
        if pins and pan then
            pins:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE')
            local pin = pins:CreatePin(MAP_PIN_TYPE_QUEST_PING, 'TCL_BOOK_SOURCE', x, y)
            if pin then
                pan:JumpToPin(pin)
                WatchParentMap(source)
            end
        elseif attempts < 20 and zo_callLater then zo_callLater(Place, 50) end
    end
    if zo_callLater then zo_callLater(Place, 150) else Place() end
    return true
end
