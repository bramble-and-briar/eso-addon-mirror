-- Archive Motifs registration and the user's selected source/map corrections.
local TC = TamrielCollections
local definition = {
    displayName = 'Motifs',
    addonName = 'Tamriel Collections - Archive Motifs',
    assetRoot = 'TamrielCollectionsMotifs',
    screenControl = 'TCMQuestJournalTL',
    version = 1006,
    supportsSearch = true,
    onCategoryFocus = function(screen, data)
        screen:ShowMotifCategory(data)
    end,
    open = function(screen)
        screen:OpenMotifs()
    end,
    activateSearch = function(screen)
        screen:ActivateMotifSearch()
    end,
}
TC:RegisterArchiveModule('motifs', definition)

-- Register the working family entry before loading optional corrections.
-- Everything is in this original manifest file so console updates do not
-- depend on adding a newly listed Lua file.
local correctionsReady, correctionsError = pcall(function()
-- Motifs source and map corrections v1.0.6
-- Explicit corrections for the motifs selected by the user. All other
-- motifs continue through the original screen, text and map callbacks.
local TC = TamrielCollections
local records = {}

local function Key(value)
    -- Keep startup indexing independent of ESO's UI formatting helpers.
    if type(value) ~= 'string' then return '' end
    value = string.lower(value):gsub('%^.*$', '')
    value = value:gsub('’', ' '):gsub('‘', ' '):gsub('–', ' '):gsub('—', ' ')
    value = value:gsub('[%p%c]+', ' '):gsub('%s+', ' ')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    return (value:gsub('%s+style$', ''))
end

local function Add(name, location, kind, destination, zone, aliases)
    local record = { name = name, location = location, kind = kind,
        destination = destination, zone = zone }
    records[Key(name)] = record
    for _, alias in ipairs(aliases or {}) do records[Key(alias)] = record end
    return record
end

Add('Black Fin Legion', 'Blackwood / Leyawiin', 'NODE', 'Leyawiin Wayshrine')
Add('Elder Argonian', 'Murkmire / Root-Whisper', 'NODE', 'Root-Whisper Wayshrine')
Add('Dead-Water', 'Murkmire / Lilmoth', 'NODE', 'Lilmoth Wayshrine')
Add('Morag Tong', 'Vvardenfell / Vivec City', 'NODE', 'Vivec City Wayshrine')
Add('Order of the Hour', 'Gold Coast / Kvatch', 'NODE', 'Kvatch Wayshrine', nil, { 'Order Hour', 'Order of Hour' })
Add('Pellitine', 'Northern Elsweyr / Rimmen', 'NODE', 'Rimmen Wayshrine')
Add('West Weald Legion', 'West Weald / Skingrad', 'HUB', { 'Skingrad City Wayshrine' }, { 'Skingrad', 'West Weald' })
Add('Nighthollow', 'The Reach / Markarth', 'NODE', 'Markarth Wayshrine')
Add('Wayward Guardian', 'The Reach / Markarth', 'NODE', 'Markarth Wayshrine')
Add("Kindred's Concord", 'Telvanni Peninsula / Necrom', 'NODE', 'Necrom Wayshrine', nil, { 'Kindreds Concord' })
Add('Militant Ordinator', 'Battlegrounds', 'LOCATION', { "Gladiator's Quarters", 'Battlemaster Rivyn' }, 'Alinor')
Add('Hircine Bloodhunter', 'Crown Store / Crown Crates', 'NONE', nil, nil, { "Hircine's Bloodhunter", 'Hiricine Bloodhunter' })
Add("Abah's Watch", "Hew's Bane / Abah's Landing", 'NODE', "Abah's Landing Wayshrine", nil, { 'Abahs Watch' })
Add('Akaviri', 'War Researcher / Cyrodiil', 'WAR_RESEARCHER')
Add('Aldmeri Dominion', 'Treasure chests / Imperial City', 'ZONE', 'Imperial City')
Add('Anequina', 'Northern Elsweyr / Rimmen', 'NODE', 'Rimmen Wayshrine')
Add('Apostle', 'Clockwork City / Brass Fortress', 'HUB', { 'Brass Fortress Wayshrine' }, { 'Brass Fortress', 'The Brass Fortress', 'Clockwork City' })
Add('Arkthzand Armory', 'The Reach / Markarth', 'NODE', 'Markarth Wayshrine')
Add('Ashlander', "Vvardenfell / Ald'ruhn", 'NODE', "Ald'ruhn Wayshrine")
Add('Blackreach Vanguard', 'Western Skyrim / Solitude', 'NODE', 'Solitude Wayshrine')
Add('Daggerfall Covenant', 'Treasure chests / Imperial City', 'ZONE', 'Imperial City')
Add('Dark Brotherhood', 'Gold Coast / Dark Brotherhood Sanctuary', 'POI', 'Dark Brotherhood Sanctuary', 'Gold Coast')
Add('Dragonguard', 'Southern Elsweyr / Senchal', 'NODE', 'Senchal Wayshrine')
Add('Ebonheart Pact', 'Treasure chests / Imperial City', 'ZONE', 'Imperial City')
Add('Ebonshadow', 'Clockwork City / Brass Fortress', 'HUB', { 'Brass Fortress Wayshrine' }, { 'Brass Fortress', 'The Brass Fortress', 'Clockwork City' })
Add('Firesong', 'Galen / Vastyr', 'NODE', 'Vastyr Wayshrine')
Add('Greymoor', 'Western Skyrim / Solitude', 'NODE', 'Solitude Wayshrine')
Add('Hallowjack', 'Witches Festival', 'NONE', nil, nil, { 'Hollowjack', 'Hallow Jack', 'Hollow Jack' })
Add('House Hexos', 'Deadlands / Fargrave', 'NODE', 'Fargrave Wayshrine')
Add('House Hlaalu', 'Pickpocketing in Vvardenfell', 'ZONE', 'Vvardenfell')
Add('House Mornard', 'Galen / Vastyr', 'NODE', 'Vastyr Wayshrine')
Add('House Redoran', 'Pickpocketing in Vvardenfell', 'ZONE', 'Vvardenfell')
Add('House Telvanni', 'Pickpocketing in Vvardenfell', 'ZONE', 'Vvardenfell')
Add('Ivory Brigade', 'Blackwood / Leyawiin', 'NODE', 'Leyawiin Wayshrine')
Add('Malacath', 'Wrothgar / Orsinium', 'NODE', 'Orsinium Wayshrine')
Add('New Moon Priest', 'Southern Elsweyr / Dragonguard Sanctum', 'NODE', 'Dragonguard Sanctum Wayshrine')
Add('Outlaw', "Hew's Bane / Abah's Landing", 'NODE', "Abah's Landing Wayshrine")
Add('Psijic', 'Summerset / Alinor', 'NODE', 'Alinor Wayshrine', nil, { 'Psijic Order' })
Add('Sapiarch', 'Summerset / Alinor', 'NODE', 'Alinor Wayshrine')
Add('Shardborn', 'West Weald / Skingrad', 'HUB', { 'Skingrad City Wayshrine' }, { 'Skingrad', 'West Weald' })
Add('Steadfast Society', 'High Isle / Gonfalon Bay', 'NODE', 'Gonfalon Square Wayshrine')
Add('Stirk Fellowship', 'Solstice / Fellowship Camp', 'NODE', 'Rampart Camp Wayshrine')
Add('Systres Guardian', 'High Isle / Gonfalon Bay', 'NODE', 'Gonfalon Square Wayshrine')
Add('Trinimac', 'Wrothgar / Orsinium', 'NODE', 'Orsinium Wayshrine')

-- Text-only records keep the original map callback and Square visibility.
Add('Tide-Born', 'Solstice / Sunport', 'TEXT', nil, nil, { 'Tide Born' })
Add('Minotaur', 'Gold Coast / Kvatch', 'TEXT')
Add('Ancient Orc', 'Wrothgar / Orsinium', 'TEXT')
Add('Dead Keeper', 'Telvanni Peninsula / Necrom', 'TEXT')
Add('Fargrave Guardian', 'Deadlands / Fargrave', 'TEXT')
Add('Shield of Senchal', 'Southern Elsweyr / Senchal', 'TEXT')

-- A nil location preserves the existing acquisition label.
Add('Dwemer', nil, 'NONE')
Add('Ebony', nil, 'NONE')
Add('Koldane Cartel', 'Outlaw Refuge', 'MAP', { 'Daggerfall Outlaws Refuge' })
Add('Thieves Guild', nil, 'MAP', { 'Thieves Den', 'Thieves Guild Den' }, nil, { "Thieves' Guild" })
Add('Xivkyn', nil, 'ZONE', 'Imperial City')

local pickpocketingDescription = 'Obtained by pickpocketing citizens in Vvardenfell.'
for _, house in ipairs({ 'Hlaalu', 'Redoran', 'Telvanni' }) do
    records[Key('House ' .. house)].description = pickpocketingDescription
    -- Native collection titles omit "House". Only their description changes;
    -- retain the original location label and already-working map callback.
    Add(house, nil, 'TEXT').description = pickpocketingDescription
end

local function GetRecord(style)
    return style and records[Key(zo_strformat(style.name or ''))] or nil
end

local nodeIndex, mapIdsByName
local function Core(name)
    return (Key(name):gsub('%s+wayshrine$', ''))
end

local function Nodes()
    if nodeIndex then return nodeIndex end
    nodeIndex = {}
    if not (GetNumFastTravelNodes and GetFastTravelNodeInfo and GetFastTravelNodePOIIndicies) then return nodeIndex end
    for index = 1, GetNumFastTravelNodes() do
        local _, name = GetFastTravelNodeInfo(index)
        local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(index)
        if name and name ~= '' and zoneIndex and poiIndex then
            nodeIndex[#nodeIndex + 1] = { nodeIndex = index, name = name,
                zoneIndex = zoneIndex, poiIndex = poiIndex }
        end
    end
    return nodeIndex
end

local function MapForZone(zoneIndex)
    if not (zoneIndex and GetZoneId) then return nil end
    local zoneId = GetZoneId(zoneIndex)
    local index = GetMapIndexByZoneId and GetMapIndexByZoneId(zoneId) or nil
    local id = GetMapIdByZoneId and GetMapIdByZoneId(zoneId) or nil
    return { mapIndex = index and index > 0 and index or nil,
        mapId = id and id > 0 and id or nil, zoneIndex = zoneIndex }
end

local function ZoneIndex(name)
    if not (GetNumZones and GetZoneNameByIndex) then return nil end
    for index = 1, GetNumZones() do
        if Key(GetZoneNameByIndex(index)) == Key(name) then return index end
    end
end

local function ExactMap(name)
    mapIdsByName = mapIdsByName or {}
    local key = Key(name)
    if mapIdsByName[key] then return { mapId = mapIdsByName[key] } end
    local highest = GetCurrentMapId and GetCurrentMapId() or 0
    if GetNumMaps and GetMapIdByIndex then
        for index = 1, GetNumMaps() do
            local id = GetMapIdByIndex(index)
            highest = math.max(highest, id or 0)
            if GetMapNameByIndex and Key(GetMapNameByIndex(index)) == key then
                return { mapIndex = index, mapId = id }
            end
        end
    end
    -- City maps need their own IDs; a parent zone uses different coordinates.
    if GetMapNameById then
        for id = 1, highest do
            if Key(GetMapNameById(id)) == key then
                mapIdsByName[key] = id
                return { mapId = id }
            end
        end
    end
end

local function ResolveZone(name)
    if name == 'Imperial City' and GetImperialCityMapIndex then
        local index = GetImperialCityMapIndex()
        if index and index > 0 then return { mapIndex = index } end
    end
    local index = ZoneIndex(name)
    return index and MapForZone(index) or ExactMap(name)
end

local function ResolveNode(name)
    for _, node in ipairs(Nodes()) do
        if Key(node.name) == Key(name) or Core(node.name) == Core(name) then
            local target = MapForZone(node.zoneIndex)
            if target then
                target.nodeIndex, target.poiIndex = node.nodeIndex, node.poiIndex
                return target
            end
        end
    end
end

local function ResolvePoi(name, zoneName)
    local zoneIndex = ZoneIndex(zoneName)
    if zoneIndex and GetNumPOIs and GetPOIInfo then
        for poiIndex = 1, GetNumPOIs(zoneIndex) do
            if Key(GetPOIInfo(zoneIndex, poiIndex)) == Key(name) then
                local target = MapForZone(zoneIndex)
                if target then target.poiIndex = poiIndex; return target end
            end
        end
    end
    local target = ExactMap(zoneName)
    if target then target.locationNames = { name }; return target end
end

local function WarResearcher()
    local alliance = GetUnitAlliance and GetUnitAlliance('player') or nil
    local gate, merchant = 'Southern High Rock Gate', 'Telfour'
    if alliance == ALLIANCE_ALDMERI_DOMINION then gate, merchant = 'Eastern Elsweyr Gate', 'Eanor'
    elseif alliance == ALLIANCE_EBONHEART_PACT then gate, merchant = 'Northern Morrowind Gate', 'Llivia Ralas' end
    local target = ExactMap(gate)
    if target then
        target.locationNames = { 'War Researcher', merchant }
        return target
    end
    -- A native alliance gate pin is the access hub if the detailed base map
    -- is unavailable. Never use a different alliance's base.
    local index = GetCyrodiilMapIndex and GetCyrodiilMapIndex() or nil
    if index and GetNumKeeps and GetKeepKeysByIndex and GetKeepName then
        for i = 1, GetNumKeeps() do
            local keepId, context = GetKeepKeysByIndex(i)
            if Key(GetKeepName(keepId)) == Key(gate) then
                return { mapIndex = index, keepId = keepId, context = context }
            end
        end
    end
end

local function Resolve(record)
    if not record or record.kind == 'NONE' then return nil end
    local target
    if record.kind == 'NODE' then target = ResolveNode(record.destination)
    elseif record.kind == 'HUB' then
        -- These city wayshrines can belong to a subzone whose zone-to-map
        -- lookup returns a different map. Open the named city explicitly.
        for _, name in ipairs(record.zone) do
            target = ExactMap(name)
            if target then break end
        end
        if target then
            local node
            for _, name in ipairs(record.destination) do
                node = ResolveNode(name)
                if node then break end
            end
            if node then
                target.nodeIndex, target.poiIndex, target.zoneIndex = node.nodeIndex, node.poiIndex, node.zoneIndex
            else
                -- The city itself remains a valid destination even if the
                -- account's native wayshrine list does not expose its node.
                target.zoneOnly = true
            end
        end
    elseif record.kind == 'MAP' then
        for _, name in ipairs(record.destination) do
            target = ExactMap(name)
            if target then target.zoneOnly = true; break end
        end
    elseif record.kind == 'ZONE' then
        target = ResolveZone(record.destination)
        if target then target.zoneOnly = true end
    elseif record.kind == 'POI' then target = ResolvePoi(record.destination, record.zone)
    elseif record.kind == 'LOCATION' then
        target = ExactMap(record.zone)
        if target then target.locationNames = record.destination end
    elseif record.kind == 'WAR_RESEARCHER' then target = WarResearcher() end
    return target
end

local function IsCoordinate(x, y)
    return x and y and x > 0 and x < 1 and y > 0 and y < 1
end

local function LocationCoordinates(names)
    if not (GetNumMapLocations and GetMapLocationTooltipHeader and GetMapLocationIcon) then return nil end
    local wanted = {}
    for _, name in ipairs(names or {}) do wanted[Key(name)] = true end
    for index = 1, GetNumMapLocations() do
        local matches = wanted[Key(GetMapLocationTooltipHeader(index))]
        if not matches and GetNumMapLocationTooltipLines and GetMapLocationTooltipLineInfo then
            for line = 1, GetNumMapLocationTooltipLines(index) do
                local _, name, _, category = GetMapLocationTooltipLineInfo(index, line)
                if wanted[Key(name)] or wanted[Key(category)] then matches = true; break end
            end
        end
        if matches then
            local _, x, y = GetMapLocationIcon(index)
            if IsCoordinate(x, y) then return x, y end
        end
    end
end

local requestNumber = 0
local function Alert(message)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, message)
end

local function ShowOnMap(screen, record)
    local target = Resolve(record)
    if not target or not (target.mapIndex or target.mapId) then
        Alert('No exact map location is available for this motif yet.')
        return
    end
    if not WORLD_MAP_MANAGER or not WORLD_MAP_MANAGER:IsMapChangingAllowed() then return end
    requestNumber = requestNumber + 1
    local request = requestNumber
    local manager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
    if manager then
        manager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCM_MOTIF_SOURCE_CORRECTION')
        manager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCM_MOTIF_SOURCE')
    end
    screen.returnToMotifsAfterMap = true
    screen.returnMotifSelectedIndex = screen.styleList:GetSelectedIndex()
    ZO_WorldMap_ShowWorldMap()
    if target.mapIndex then WORLD_MAP_MANAGER:SetMapByIndex(target.mapIndex)
    elseif WORLD_MAP_MANAGER.SetMapById then WORLD_MAP_MANAGER:SetMapById(target.mapId)
    else Alert('The motif location could not be opened on the map.'); return end
    if target.zoneOnly then return end

    local attempts = 0
    local function PlacePin()
        if request ~= requestNumber then return end
        attempts = attempts + 1
        local correctMap = target.mapIndex and GetCurrentMapIndex() == target.mapIndex
            or (not target.mapIndex and GetCurrentMapId() == target.mapId)
        local x, y
        if correctMap then
            if target.nodeIndex and GetFastTravelNodeInfo then
                local _, _, nx, ny, _, _, _, shown = GetFastTravelNodeInfo(target.nodeIndex)
                if shown and IsCoordinate(nx, ny) then x, y = nx, ny end
            end
            if not IsCoordinate(x, y) and target.poiIndex and GetPOIMapInfo then
                local px, py, _, _, shown = GetPOIMapInfo(target.zoneIndex, target.poiIndex)
                if shown and IsCoordinate(px, py) then x, y = px, py end
            end
            if target.locationNames then x, y = LocationCoordinates(target.locationNames) end
            if target.keepId and GetKeepPinInfo then
                local _, kx, ky = GetKeepPinInfo(target.keepId, target.context)
                if IsCoordinate(kx, ky) then x, y = kx, ky end
            end
        end
        if not correctMap or not IsCoordinate(x, y) then
            if attempts < 20 then zo_callLater(PlacePin, 50)
            else Alert('The motif location has no usable map coordinates.') end
            return
        end
        local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
        local panAndZoom = ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom() or nil
        if not (pinManager and panAndZoom) then return end
        pinManager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCM_MOTIF_SOURCE_CORRECTION')
        local pin = pinManager:CreatePin(MAP_PIN_TYPE_QUEST_PING, 'TCM_MOTIF_SOURCE_CORRECTION', x, y)
        if pin then panAndZoom:JumpToPin(pin) end
    end
    zo_callLater(PlacePin, 150)
end

local function Install(screen)
    if not screen or screen._tcmSourceCorrectionsInstalled then return end
    if type(screen.ShowStyle) ~= 'function' or type(screen.ShowSelectedMotifOnMap) ~= 'function'
        or type(screen.keybindStripDescriptor) ~= 'table' then return end
    local mapDescriptor
    for _, descriptor in ipairs(screen.keybindStripDescriptor) do
        if descriptor.keybind == 'UI_SHORTCUT_SECONDARY' then mapDescriptor = descriptor; break end
    end
    if not mapDescriptor then return end
    local originalShowStyle = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        local result = originalShowStyle(self, data)
        if self.activeModuleId == 'motifs' then
            local record = GetRecord(data and data.style)
            if record then
                if record.location then self.detailLocation:SetText(record.location) end
                if record.description then self.detailSource:SetText(record.description) end
            end
        end
        return result
    end
    local originalShowMap = screen.ShowSelectedMotifOnMap
    screen.ShowSelectedMotifOnMap = function(self)
        requestNumber = requestNumber + 1
        local data = self.styleList and self.styleList:GetTargetData() or nil
        local record = self.activeModuleId == 'motifs' and GetRecord(data and data.style) or nil
        if record then
            if record.kind == 'NONE' then return end
            if record.kind ~= 'TEXT' then return ShowOnMap(self, record) end
        end
        return originalShowMap(self)
    end
    for _, descriptor in ipairs(screen.keybindStripDescriptor or {}) do
        if descriptor.keybind == 'UI_SHORTCUT_SECONDARY' then
            local originalVisible = descriptor.visible
            descriptor.visible = function()
                if screen.activeModuleId == 'motifs' and screen.mode == 'styles' then
                    local data = screen.styleList and screen.styleList:GetTargetData() or nil
                    local record = GetRecord(data and data.style)
                    if record and record.kind ~= 'TEXT' then return record.kind ~= 'NONE' end
                end
                return originalVisible and originalVisible() or false
            end
        end
    end
    screen._tcmSourceCorrectionsInstalled = true
end

TC.motifSourceCorrections = { Get = GetRecord, Install = Install }

end)
if not correctionsReady then TC.motifSourceCorrectionsError = tostring(correctionsError) end

local function InstallCorrections(screen)
    local corrections = TC.motifSourceCorrections
    if type(corrections) == 'table' and type(corrections.Install) == 'function' then
        local ok, err = pcall(corrections.Install, screen)
        if not ok then TC.motifSourceCorrectionsError = tostring(err) end
    end
end

definition.onCategoryFocus = function(screen, data)
    -- Populate the original category and its native icons before attaching
    -- detail/map wrappers; the shared screen may still be initializing.
    screen:ShowMotifCategory(data)
    InstallCorrections(screen)
end

definition.open = function(screen)
    InstallCorrections(screen)
    screen:OpenMotifs()
end
