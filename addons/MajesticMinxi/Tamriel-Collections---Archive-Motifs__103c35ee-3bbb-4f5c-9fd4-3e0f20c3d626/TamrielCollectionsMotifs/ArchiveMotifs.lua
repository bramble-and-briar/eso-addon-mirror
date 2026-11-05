-- Archive Motifs registration and the user's selected source/map corrections.
local TC = TamrielCollections
local definition = {
    displayName = 'Motifs',
    addonName = 'Tamriel Collections - Archive Motifs',
    assetRoot = 'TamrielCollectionsMotifs',
    screenControl = 'TCMQuestJournalTL',
    version = 1101,
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

-- Motifs layout v1.0.12: a separate scene-owned background plane keeps the
-- native masked menus, search controls, emblem and panel rails unobscured.
-- Geometry is measured
-- against GuiRoot because ESO narrows the native scene owner to quadrant 1.
local Pilot = {}
TC.motifLayoutPreview = Pilot
local function IsMotifs(screen)
    if screen.mode == 'categories' then
        local data = screen.categoryList and screen.categoryList:GetTargetData()
        return data and data.categoryKey == 'motifs'
    end
    return screen.activeModuleId == 'motifs' and (screen.mode == 'styles' or screen.mode == 'details')
end
local function Capture(control)
    local saved = { anchors = {}, width = control:GetWidth(), height = control:GetHeight(), hidden = control:IsHidden(), parent = control:GetParent() }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constrains = control:GetAnchor(index)
        if valid then saved.anchors[#saved.anchors + 1] = { point, relative, relativePoint, x, y, constrains } end
    end
    if control.GetAutoRectClipChildren then saved.clip = control:GetAutoRectClipChildren() end
    if control.GetDrawLayer then saved.layer = control:GetDrawLayer() end
    if control.GetDrawLevel then saved.level = control:GetDrawLevel() end
    if control.GetFont then saved.font = control:GetFont() end
    return saved
end
local function RestoreControl(control, saved)
    if saved.parent and control:GetParent() ~= saved.parent then control:SetParent(saved.parent) end
    control:ClearAnchors()
    control:SetDimensions(saved.width, saved.height)
    for _, anchor in ipairs(saved.anchors) do
        control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5], anchor[6])
    end
    control:SetHidden(saved.hidden)
    if saved.clip ~= nil and control.SetAutoRectClipChildren then control:SetAutoRectClipChildren(saved.clip) end
    if saved.layer ~= nil then control:SetDrawLayer(saved.layer) end
    if saved.level ~= nil then control:SetDrawLevel(saved.level) end
    if saved.font then control:SetFont(saved.font) end
end
local moved = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'collectionsHeaderLogo', 'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop',
    'motifSearchControl', 'styleListContainer', 'detailControl', 'detailHeading', 'detailAcquisition',
    'detailWhereTitle', 'detailLocation', 'detailSource', 'detailAchievement', 'detailIcon',
    'moduleUnavailableTitle', 'moduleUnavailableBody' }
local hiddenLines = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop' }
local function Bounds(screen)
    local owner, root = screen.control, GuiRoot or screen.control
    if not owner or not root or not root.GetLeft or not screen.middle or not screen.right then return end
    local left, top, width, height = root:GetLeft(), root:GetTop(), root:GetWidth(), root:GetHeight()
    if not (left and top and width and height and width > 600 and height > 400) then return end
    local middle, right = screen.middle:GetLeft() - left, screen.right:GetLeft() - left
    if not (middle > 100 and right > middle + 100 and right < width - 100) then return end
    local alley = ZO_GAMEPAD_ALLEY_WIDTH or 10
    local panelLeft = math.max(0, middle - screen.right:GetWidth() - alley)
    local panelRight = math.min(width, screen.right.GetRight and screen.right:GetRight() - left or width)
    local middleEnd = math.min(right - alley, screen.middle.GetRight and screen.middle:GetRight() - left or right - alley)
    local texture = ZO_KeybindStripGamepadBackgroundTexture
    local keybindHeight = texture and texture.GetHeight and texture:GetHeight() or ZO_GAMEPAD_KEYBIND_STRIP_BACKGROUND_HEIGHT or 128
    local footer = texture and texture.GetTop and texture:GetTop() - top or height - keybindHeight
    if not footer or footer <= height / 2 or footer > height then footer = height - keybindHeight end
    footer = footer - 16
    -- All columns share a title baseline and two narrow gold rules. Keep the
    -- left menu and chapter-list divider aligned, leaving the middle list open.
    local titleTop = math.max(24, ZO_GAMEPAD_SAFE_ZONE_INSET_Y or 54) + 8
    local first, second = titleTop + 56, titleTop + 216
    local listTop, lower = second + 18, footer - 234
    if lower - listTop < 314 then return end
    return { root = root, owner = owner, width = width, height = height,
        left = panelLeft, leftEnd = middle - alley, middle = middle, middleEnd = middleEnd,
        right = right, edge = panelRight, titleTop = titleTop, first = first,
        second = second, listTop = listTop, lower = lower, footer = footer }
end
local function Place(control, b, left, right, top, height)
    if not control then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, b.root, TOPLEFT, left, top)
    control:SetAnchor(TOPRIGHT, b.root, TOPLEFT, right, top)
    control:SetHeight(height)
end
local function Foreground(control)
    if not control then return end
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(90)
end
local function NewControl(state, name, kind, level)
    local isBackground = name == 'Backdrop' or name == 'FooterFill' or name == 'HeaderShade'
    local parent = isBackground and state.backgroundRoot or state.bounds.owner
    local control = WINDOW_MANAGER:CreateControl('TCMMotifsLayoutPilot' .. name, parent, kind)
    if DT_LOW then control:SetDrawTier(DT_LOW) end
    control:SetDrawLayer(isBackground and DL_BACKGROUND or DL_CONTROLS)
    control:SetDrawLevel(isBackground and 0 or level)
    control:SetHidden(true)
    return control
end
local function MakeControls(state, screen)
    if state.controls then return end
    local c = {}; state.controls = c
    -- Scroll masks and top-level windows compose their descendants as a group.
    -- Raising a label cannot place it above an opaque sibling in another
    -- composed layer. Keep the paint in a distinct, lower background window.
    local background = WINDOW_MANAGER:CreateTopLevelWindow('TCMMotifsBackgroundWindow')
    background:SetHidden(true)
    background:SetMouseEnabled(false)
    background:SetDrawTier(DT_LOW)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetDrawLevel(0)
    state.backgroundRoot = background
    state.backgroundFragment = ZO_SimpleSceneFragment:New(background)
    state.backgroundFragment:SetConditional(function() return state.active == true and IsMotifs(screen) end)
    screen.scene:AddFragment(state.backgroundFragment)
    -- A near-solid tint retains a faint glimpse of the world beneath the
    -- native gamepad panels, while keeping collection text readable.
    c.Backdrop = NewControl(state, 'Backdrop', CT_TEXTURE, 10)
    c.Backdrop:SetColor(32 / 255, 37 / 255, 38 / 255, 0.72)
    c.FooterFill = NewControl(state, 'FooterFill', CT_TEXTURE, 11)
    c.FooterFill:SetColor(36 / 255, 40 / 255, 40 / 255, 1)
    c.FooterRule = NewControl(state, 'FooterRule', CT_TEXTURE, 20)
    c.FooterRule:SetColor(145 / 255, 137 / 255, 112 / 255, 1)
    c.HeaderShade = NewControl(state, 'HeaderShade', CT_TEXTURE, 15)
    c.HeaderShade:SetColor(0.015, 0.02, 0.02, 0.24)
    for _, name in ipairs({ 'TitleRule', 'HeaderRule', 'MenuRule', 'SourceRule' }) do
        local line = NewControl(state, name, CT_TEXTURE, 20)
        -- The native divider fades toward its ends. A solid two-unit rule
        -- spans the exact panel bounds without fading or stretching an image.
        line:SetColor(224 / 255, 191 / 255, 124 / 255, 1)
        c[name] = line
    end
    for _, name in ipairs({ 'ArchivesTitle', 'ModuleTitle', 'DetailsTitle', 'StarterHint' }) do
        local label = NewControl(state, name, CT_LABEL, 90)
        label:SetFont(name == 'StarterHint' and 'ZoFontGamepad25' or 'ZoFontGamepadBold34')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if name == 'StarterHint' then label:SetColor(0.72, 0.72, 0.68, 1)
        else label:SetColor(244 / 255, 225 / 255, 182 / 255, 1) end
        c[name] = label
    end
    c.ModuleEmblem = NewControl(state, 'ModuleEmblem', CT_TEXTURE, 90)
    c.ModuleEmblem:SetColor(244 / 255, 225 / 255, 182 / 255, 0.45)
    c.ArchivesTitle:SetText('TAMRIEL ARCHIVES')
    c.ModuleTitle:SetText('MOTIFS')
    c.DetailsTitle:SetText('DETAILS')
    c.StarterHint:SetText('Choose a motif to view its chapters,\ncollection progress and sources.')
end
local function HideNative(screen)
    for _, name in ipairs(hiddenLines) do if screen[name] then screen[name]:SetHidden(true) end end
end
function Pilot.Restore(screen)
    local state = screen._tcmLayoutPilot
    if not state then return end
    state.generation = (state.generation or 0) + 1
    state.pending, state.attempts = nil, 0
    local wasActive = state.active
    state.active = false
    if state.backgroundFragment then state.backgroundFragment:Refresh() end
    if not wasActive then return end
    for list, offset in pairs(state.listOffsets or {}) do
        list:SetFixedCenterOffset(offset)
    end
    state.listOffsets = nil
    for control, saved in pairs(state.saved) do RestoreControl(control, saved) end
    for _, control in pairs(state.controls or {}) do control:SetHidden(true) end
    if state.ownerLayer ~= nil then screen.control:SetDrawLayer(state.ownerLayer) end
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData or { titleText = 'TAMRIEL ARCHIVES' })
    end
    state.saved = nil
end
function Pilot.Apply(screen)
    if not IsMotifs(screen) then return false end
    local state = screen._tcmLayoutPilot
    if not state then state = {}; screen._tcmLayoutPilot = state end
    local b = state.active and state.bounds or Bounds(screen)
    if not b then
        if zo_callLater and not state.pending and (state.attempts or 0) < 3 then
            state.pending, state.attempts = true, (state.attempts or 0) + 1
            local generation = state.generation or 0
            zo_callLater(function()
                if (state.generation or 0) ~= generation then return end
                state.pending = nil
                if IsMotifs(screen) then Pilot.Apply(screen) end
            end, 33)
        end
        return false
    end
    if not state.active then
        state.bounds, state.saved, state.attempts = b, {}, 0
        state.ownerLayer = screen.control:GetDrawLayer()
        for _, name in ipairs(moved) do
            local control = screen[name]
            if control and control.GetNumAnchors then state.saved[control] = Capture(control) end
        end
        for _, row in ipairs(screen.fixedCategoryRows or {}) do state.saved[row] = Capture(row) end
        MakeControls(state, screen)
        state.active = true
    end
    -- Explicitly separate the scene's content plane from its background plane.
    screen.control:SetDrawLayer(DL_CONTROLS)
    local c, starter = state.controls, screen.mode == 'categories'
    Place(state.backgroundRoot, b, 0, b.width, 0, b.height)
    Place(c.Backdrop, b, 0, b.width, 0, b.height)
    local keybindTop = b.footer + 16
    Place(c.FooterFill, b, 0, b.width, keybindTop, b.height - keybindTop)
    Place(c.FooterRule, b, 0, b.width, keybindTop, 2)
    Place(c.HeaderShade, b, b.left, b.edge, b.titleTop - 20, b.second - b.titleTop + 20)
    Place(c.TitleRule, b, b.left, b.edge, b.first, 2)
    Place(c.HeaderRule, b, b.left, b.edge, b.second, 2)
    Place(c.MenuRule, b, b.left, b.leftEnd, b.lower, 2)
    Place(c.SourceRule, b, b.right, b.edge, b.lower, 2)
    Place(c.ArchivesTitle, b, b.left + 12, b.leftEnd - 12, b.titleTop, 48)
    Place(c.ModuleTitle, b, b.middle + 12, b.middleEnd - 12, b.titleTop, 48)
    Place(c.DetailsTitle, b, b.right + 12, b.edge - 12, b.titleTop, 48)
    local category = TC.GetArchiveCategory and TC:GetArchiveCategory('motifs')
    local emblem = category and screen:GetCategoryIcon(category)
    if emblem then c.ModuleEmblem:SetTexture(emblem) end
    local emblemSize = math.min(128, b.footer - b.lower - 40)
    Place(c.ModuleEmblem, b, (b.left + b.leftEnd - emblemSize) / 2,
        (b.left + b.leftEnd + emblemSize) / 2, (b.lower + b.footer - emblemSize) / 2, emblemSize)
    Place(c.StarterHint, b, b.right + 28, b.edge - 28, (b.listTop + b.lower) / 2 - 48, 96)
    for _, control in pairs(c) do control:SetHidden(false) end
    c.StarterHint:SetHidden(not starter)
    c.ModuleEmblem:SetHidden(not emblem)
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, { titleText = '' })
    end
    local center = (b.first + b.second) / 2
    if screen.collectionsHeaderLogo then
        -- The native header is a separately animated fragment. Its hidden
        -- state and scroll mask must not hide the fixed Archives artwork.
        screen.collectionsHeaderLogo:SetParent(b.owner)
        screen.collectionsHeaderLogo:SetHidden(false)
        screen.collectionsHeaderLogo:ClearAnchors()
        screen.collectionsHeaderLogo:SetDimensions(100, 100)
        screen.collectionsHeaderLogo:SetAnchor(CENTER, b.root, TOPLEFT, (b.left + b.leftEnd) / 2, center)
        Foreground(screen.collectionsHeaderLogo)
    end
    if screen.detailIcon then
        screen.detailIcon:ClearAnchors()
        screen.detailIcon:SetDimensions(100, 100)
        screen.detailIcon:SetAnchor(CENTER, b.root, TOPLEFT, (b.right + b.edge) / 2, center)
        Foreground(screen.detailIcon)
    end
    if screen.motifSearchControl then
        screen.motifSearchControl:ClearAnchors()
        screen.motifSearchControl:SetAnchor(CENTER, b.root, TOPLEFT, (b.middle + b.middleEnd) / 2, center)
        -- The same native search affordance is visible on the starter. Its
        -- existing Search shortcut opens Motifs and then focuses the edit box.
        screen.motifSearchControl:SetHidden(false)
        Foreground(screen.motifSearchControl)
    end
    Place(screen.styleListContainer, b, b.middle + 8, b.middleEnd - 8, b.listTop, b.footer - b.listTop)
    Place(screen.detailControl, b, b.right + 8, b.edge - 8, b.listTop, b.lower - b.listTop - 12)
    for _, name in ipairs({ 'styleListContainer', 'detailControl' }) do
        if screen[name] and screen[name].SetAutoRectClipChildren then screen[name]:SetAutoRectClipChildren(true) end
    end
    -- Native vertical lists anchor the selected row at their center. Bring
    -- that anchor to the top of the viewport without moving the panel itself.
    state.listOffsets = state.listOffsets or {}
    for _, list in ipairs({ screen.styleList, screen.detailList }) do
        if list.SetFixedCenterOffset and list.GetControl then
            if state.listOffsets[list] == nil then
                state.listOffsets[list] = list.fixedCenterOffset or 0
            end
            list:SetFixedCenterOffset(8 - list:GetControl():GetHeight() / 2)
        end
    end
    Place(screen.detailHeading, b, b.right + 24, b.edge - 24, b.first + 20, 76)
    if screen.detailHeading then screen.detailHeading:SetFont('ZoFontGamepadBold27') end
    Place(screen.detailAcquisition, b, b.right + 24, b.edge - 24, b.first + 110, 30)
    Foreground(screen.detailHeading)
    Foreground(screen.detailAcquisition)
    Place(screen.detailWhereTitle, b, b.right + 24, b.edge - 24, b.lower + 10, 28)
    Place(screen.detailLocation, b, b.right + 24, b.edge - 24, b.lower + 42, 30)
    Place(screen.detailSource, b, b.right + 24, b.edge - 24, b.lower + 76, 88)
    Place(screen.detailAchievement, b, b.right + 24, b.edge - 24, b.lower + 170, 58)
    -- Retain foreground placement without changing native data, row templates,
    -- scrolling, search controls or controller bindings.
    for _, name in ipairs({ 'styleListContainer', 'detailControl', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement',
        'moduleUnavailableTitle', 'moduleUnavailableBody' }) do Foreground(screen[name]) end
    local rows = screen.fixedCategoryRows or {}
    local spacing = #rows > 1 and math.min(80, (b.lower - b.listTop - 90) / (#rows - 1)) or 0
    for index, row in ipairs(rows) do
        -- Keep only the visuals outside the animated header. The invisible
        -- native category list retains all controller input and selection.
        row:SetParent(b.owner)
        row:SetHidden(false)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, b.root, TOPLEFT, b.left + 44, b.listTop + 14 + (index - 1) * spacing)
        Foreground(row)
    end
    if starter then
        -- A single module heading above the search field identifies this page;
        -- preserve the native press-X prompt without repeating the heading.
        if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
        Place(screen.moduleUnavailableBody, b, b.middle + 32, b.middleEnd - 32,
            (b.listTop + b.lower) / 2 - 76, 152)
    end
    HideNative(screen)
    state.backgroundFragment:Refresh()
    return true
end
function Pilot.Prompt(screen, data)
    screen:ShowUnavailableCategory(data, TC:GetArchiveCategory('motifs'))
    if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetText('MOTIFS') end
    if screen.moduleUnavailableBody then screen.moduleUnavailableBody:SetText('Browse crafting motifs and track your collection.\nFind unlearned chapters and their sources.\n\nPress X to browse Motifs.') end
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search Motifs')
    end
    Pilot.Apply(screen)
end
function Pilot.Install(screen)
    if screen._tcmLayoutPilotInstalled then return end
    screen._tcmLayoutPilotInstalled = true
    local originalShowCategory = screen.ShowCategory
    screen.ShowCategory = function(self, data)
        if not data or data.categoryKey ~= 'motifs' then Pilot.Restore(self) end
        return originalShowCategory(self, data)
    end
    local originalShowStyle = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if IsMotifs(self) then
            Pilot.Apply(self)
            if self.mode ~= 'categories' then self:SetMotifContentVisible(true) end
        else Pilot.Restore(self) end
        local result = originalShowStyle(self, data)
        if IsMotifs(self) then Pilot.Apply(self) end
        return result
    end
    local originalHiding = screen.OnHiding
    screen.OnHiding = function(self, ...)
        Pilot.Restore(self)
        if originalHiding then return originalHiding(self, ...) end
    end
end
local originalMotifsOpen = definition.open
definition.onCategoryFocus = function(screen, data)
    InstallCorrections(screen)
    Pilot.Install(screen)
    Pilot.Prompt(screen, data)
end
definition.open = function(screen)
    InstallCorrections(screen)
    Pilot.Install(screen)
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search Motifs')
    end
    screen:ShowMotifCategory()
    originalMotifsOpen(screen)
    Pilot.Apply(screen)
end

-- Collector view is local to Motifs, including when another module owns the UI.
local function InstallCollectorView(screen)
    if screen._tcmCollectorInstalled then return end
    screen._tcmCollectorInstalled = true
    local populate = screen.PopulateMotifList
    screen.PopulateMotifList = function(self)
        if self.styles ~= self._tcmFilteredStyles then self._tcmAllStyles = self.styles end
        local filtered = {}
        for _, style in ipairs(self._tcmAllStyles or {}) do
            if self._tcmShowAll or (style.known or 0) < (style.total or 0) then
                filtered[#filtered + 1] = style
            end
        end
        self.styles, self._tcmFilteredStyles = filtered, filtered
        return populate(self)
    end
    local addEntry = screen.detailList.AddEntry
    screen.detailList.AddEntry = function(list, template, data, ...)
        if screen.activeModuleId == 'motifs' and not screen._tcmShowAll and data and data.isKnown then return end
        return addEntry(list, template, data, ...)
    end
    local showStyle = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        local result = showStyle(self, data)
        if self.activeModuleId == 'motifs' and not (data and data.style) then
            self.detailList:Clear()
            self.detailList:Commit()
            for _, name in ipairs({ 'detailHeading', 'detailAcquisition', 'detailLocation', 'detailSource', 'detailAchievement' }) do
                if self[name] then self[name]:SetText('') end
            end
            if self.detailHeading then
                self.detailHeading:SetHidden(false)
                self.detailHeading:SetText('No unlearned motifs')
            end
            if self.detailWhereTitle then self.detailWhereTitle:SetHidden(true) end
            if self.detailIcon then self.detailIcon:SetHidden(true) end
        end
        return result
    end
    local group, strip = screen.keybindStripDescriptor, KEYBIND_STRIP
    if group then
        local registered = strip and strip.HasKeybindButtonGroup and strip:HasKeybindButtonGroup(group)
        if registered then strip:RemoveKeybindButtonGroup(group) end
        table.insert(group, {
            name = function() return screen._tcmShowAll and 'Show Unlearned' or 'Show All' end,
            keybind = 'UI_SHORTCUT_LEFT_STICK',
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            visible = function()
                return screen.activeModuleId == 'motifs' and (screen.mode == 'styles' or screen.mode == 'details')
            end,
            callback = function()
                local target = screen.styleList:GetTargetData()
                local selected = target and target.style
                local details = screen.mode == 'details'
                screen._tcmShowAll = not screen._tcmShowAll
                screen:PopulateMotifList()
                for index, style in ipairs(screen.styles or {}) do
                    if style == selected then screen.styleList:SetSelectedIndex(index); break end
                end
                screen:ShowStyle(screen.styleList:GetTargetData())
                if details and not screen.styleList:GetTargetData() then screen:ReturnToStyles() end
                screen:RefreshKeybinds()
            end,
        })
        if registered then strip:AddKeybindButtonGroup(group) end
    end
end
local collectorFocus, collectorOpen = definition.onCategoryFocus, definition.open
definition.onCategoryFocus = function(screen, data)
    InstallCollectorView(screen)
    return collectorFocus(screen, data)
end
definition.open = function(screen)
    InstallCollectorView(screen)
    return collectorOpen(screen)
end
