local WH = WizardsHelper

local function isIndex(value)
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function meaningful(value, seen, step)
    if type(value) == "number" then return value ~= 0 end
    if type(value) == "boolean" then return value end
    if type(value) == "string" then return value ~= "0" and value:find("%S") ~= nil end
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for _, child in next, value do
        if step then step() end
        if meaningful(child, seen, step) then return true end
    end
    return false
end

function WH.HasSavedContent(setup)
    if type(setup) ~= "table" then return false end
    local step = coroutine.running() and coroutine.yield
    if type(setup.skills) == "table" then
        for _, bar in next, setup.skills do if meaningful(bar, nil, step) then return true end end
    end
    if type(setup.gear) == "table" then
        for slot, gear in next, setup.gear do
            if step then step() end
            if type(slot) == "number" and type(gear) == "table" and (meaningful(gear.id) or meaningful(gear.link)) then return true end
        end
    end
    if meaningful(setup.cp, nil, step) or meaningful(setup.food, nil, step) or meaningful(setup.code) then return true end
    local metadata = { name = true, disabled = true, condition = true, skills = true, gear = true, cp = true, food = true, code = true }
    for key, value in next, setup do
        if step then step() end
        if not metadata[key] and meaningful(value, nil, step) then return true end
    end
    -- WW creates trial names and boss conditions before a build is saved.
    return false
end

function WH:CheckWardrobe()
    local ww = WizardsWardrobe
    if type(ww) ~= "table" or type(ww.storage) ~= "table" or type(ww.setups) ~= "table"
        or type(ww.pages) ~= "table" or type(ww.zones) ~= "table" then
        return false, "Wizard's Wardrobe is not ready. Enable WW and reload the UI."
    end
    if ww.storage.setups ~= ww.setups or ww.storage.pages ~= ww.pages then return false, "Unsupported Wizard's Wardrobe storage layout." end
    if type(WizardsWardrobeSV) ~= "table" then return false, "Wizard's Wardrobe SavedVariables are not available. Reload the UI with WW enabled." end
    return true
end

function WH:GetAccountData()
    -- Do not initialize or migrate another character while browsing.
    local root = WizardsWardrobeSV
    local profile = type(root) == "table" and rawget(root, "Default")
    return type(profile) == "table" and rawget(profile, GetDisplayName()) or nil
end

function WH:GetRoster()
    local roster = {}
    for index = 1, GetNumCharacters() do
        local name, gender, _, classId, _, _, characterId = GetCharacterInfo(index)
        if characterId then
            characterId = tostring(characterId)
            local className = GetClassName and GetClassName(gender, classId) or ("Class " .. tostring(classId))
            roster[characterId] = {
                id = characterId, name = zo_strformat("<<1>>", name), classId = classId,
                className = zo_strformat("<<1>>", className), isCurrent = characterId == tostring(GetCurrentCharacterId()),
            }
        end
    end
    return roster
end

function WH.CharacterLess(a, b)
    if a.className ~= b.className then return a.className < b.className end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

function WH:ScanSources(complete)
    return self:StartJob("Reading saved Wizard's Wardrobe builds...", function()
        local account, roster = self:GetAccountData(), self:GetRoster()
        local sources = {}
        if type(account) ~= "table" then return sources end
        for id, character in pairs(roster) do
            local storage = rawget(account, id)
            if type(storage) == "table" and type(storage.setups) == "table" and type(storage.pages) == "table" then
                local source = { id = id, name = character.name, classId = character.classId,
                    className = character.className, isCurrent = character.isCurrent, pages = {} }
                for tag, zoneSetups in next, storage.setups do
                    local zonePages = storage.pages[tag]
                    if type(tag) == "string" and type(zoneSetups) == "table" and type(zonePages) == "table" and WizardsWardrobe.zones[tag] then
                        for _, pageId in ipairs(self.SortedKeys(zoneSetups)) do
                            local setups, metadata = zoneSetups[pageId], zonePages[pageId]
                            if type(setups) == "table" and type(metadata) == "table" then
                                local page = {
                                    sourceId = id, sourceName = character.name, classId = character.classId, className = character.className,
                                    tag = tag, pageId = pageId, name = tostring(metadata.name or ("Page " .. pageId)),
                                    rows = {}, data = setups, metadata = metadata,
                                }
                                for _, setupId in ipairs(self.SortedKeys(setups)) do
                                    local setup = setups[setupId]
                                    if self.HasSavedContent(setup) then
                                        page.rows[#page.rows + 1] = { index = setupId, name = tostring(setup.name or ("Setup " .. setupId)), data = setup }
                                    end
                                    coroutine.yield()
                                end
                                if #page.rows > 0 then source.pages[#source.pages + 1] = page end
                            end
                            coroutine.yield()
                        end
                    end
                    coroutine.yield()
                end
                source.pages = self.Sort(source.pages, function(a, b)
                    if a.tag == b.tag then return a.pageId < b.pageId end
                    return a.tag < b.tag
                end)
                if #source.pages > 0 then sources[#sources + 1] = source end
            end
            coroutine.yield()
        end
        return self.Sort(sources, self.CharacterLess)
    end, complete)
end

function WH:ResolveSource(page)
    local account, roster = self:GetAccountData(), self:GetRoster()
    if not roster[page.sourceId] then error("The source must belong to the current account/server.") end
    local storage = type(account) == "table" and account[page.sourceId]
    local setups = storage and storage.setups and storage.setups[page.tag]
    local pages = storage and storage.pages and storage.pages[page.tag]
    if not setups or setups[page.pageId] ~= page.data or not pages or pages[page.pageId] ~= page.metadata then
        error("The source page changed. Refresh the browser and select it again.")
    end
    if page.sourceId == tostring(GetCurrentCharacterId()) and (storage.setups ~= WizardsWardrobe.setups or storage.pages ~= WizardsWardrobe.pages) then
        error("The source page changed. Refresh the browser.")
    end
    return setups[page.pageId], storage
end

function WH:ResolveDestination(characterId, sourceId)
    characterId = tostring(characterId)
    local account, roster = self:GetAccountData(), self:GetRoster()
    local character = roster[characterId]
    if type(account) ~= "table" or not character then error("The destination must belong to the current account/server.", 0) end
    if characterId == sourceId then error("Choose a different destination character.", 0) end
    local storage = rawget(account, characterId)
    local schema = WizardsWardrobe.storage.version or 1
    if storage ~= nil and type(storage) ~= "table" then error("Unsupported destination WW storage.", 0) end
    if storage and storage.version ~= schema then
        error("Open WW once on " .. character.name .. " before copying to that character.", 0)
    end
    local pages, setups = storage and rawget(storage, "pages"), storage and rawget(storage, "setups")
    if (pages ~= nil and type(pages) ~= "table") or (setups ~= nil and type(setups) ~= "table") then error("Unsupported destination WW storage layout.", 0) end
    local active = characterId == tostring(GetCurrentCharacterId())
    if active and (pages ~= WizardsWardrobe.pages or setups ~= WizardsWardrobe.setups) then error("The destination changed. Refresh the browser.", 0) end
    return { id = characterId, name = character.name, classId = character.classId, className = character.className,
        account = account, storage = storage, originalPages = pages, originalSetups = setups,
        pages = pages or {}, setups = setups or {}, schema = schema, active = active }
end

function WH:GetDestinations(sourceId)
    local destinations = {}
    for id, character in pairs(self:GetRoster()) do
        if id ~= sourceId then
            local ok, result = pcall(function() return self:ResolveDestination(id, sourceId) end)
            character.disabledReason = not ok and tostring(result) or nil
            destinations[#destinations + 1] = character
        end
    end
    -- The account roster contains at most twenty characters.
    table.sort(destinations, self.CharacterLess)
    return destinations
end

function WH.ValidateSetup(setup)
    if type(setup) ~= "table" or type(setup.name) ~= "string" or type(setup.code) ~= "string"
        or type(setup.skills) ~= "table" or type(setup.skills[0]) ~= "table" or type(setup.skills[1]) ~= "table"
        or type(setup.gear) ~= "table" or type(setup.cp) ~= "table" or type(setup.food) ~= "table" or type(setup.condition) ~= "table" then
        error("Unsupported WW setup structure. Nothing was copied.")
    end
end

function WH:CopyPage(page, selectedRow, newName, complete, destinationId)
    if not page or (selectedRow and not isIndex(selectedRow.index)) then return false end
    destinationId = tostring(destinationId or GetCurrentCharacterId())
    return self:StartJob("Preparing the copy. Existing WW builds will be preserved...", function()
        local ok, reason = self:CheckWardrobe()
        if not ok then error(reason) end
        local ww, activeId = WizardsWardrobe, tostring(GetCurrentCharacterId())
        local source, sourceStorage = self:ResolveSource(page)
        local destination = self:ResolveDestination(destinationId, page.sourceId)
        if sourceStorage.setups == destination.setups or sourceStorage.pages == destination.pages then error("Source and destination storage overlap. Reload the UI before copying.") end
        if not ww.zones[page.tag] then error("WW does not recognize this zone.") end
        local zonePages, zoneSetups = destination.pages[page.tag], destination.setups[page.tag]
        if zonePages and (type(zonePages) ~= "table" or type(zonePages[0]) ~= "table") then error("Unsupported destination page metadata. Nothing was copied.") end
        if zoneSetups and type(zoneSetups) ~= "table" then error("Unsupported destination setup storage.") end
        if zoneSetups and not zonePages and next(zoneSetups) then error("Destination WW page metadata is missing.") end
        local copied, indexMap = {}, {}
        if selectedRow then
            if source[selectedRow.index] ~= selectedRow.data then error("The source setup changed. Refresh the browser.") end
            if not self.HasSavedContent(selectedRow.data) then error("This setup has no saved build data.") end
            self.ValidateSetup(selectedRow.data)
            copied[1] = self.CopyTable(selectedRow.data)
            indexMap[selectedRow.index] = 1
        else
            for _, index in ipairs(self.SortedKeys(source)) do
                if self.HasSavedContent(source[index]) then
                    self.ValidateSetup(source[index])
                    copied[#copied + 1] = self.CopyTable(source[index])
                    indexMap[index] = #copied
                end
                coroutine.yield()
            end
        end
        if #copied == 0 then error("This page has no saved builds.") end
        local metadata = self.CopyTable(page.metadata)
        if metadata.selected then metadata.selected = indexMap[metadata.selected] or 1 end
        newName = type(newName) == "string" and newName:match("^%s*(.-)%s*$") or ""
        metadata.name = newName ~= "" and newName or (page.name .. " (" .. page.sourceName .. ")")
        local nextPageId, missingSetupPages = 1, {}
        for key, value in pairs(zonePages or {}) do
            if isIndex(key) then
                nextPageId = math.max(nextPageId, key + 1)
                if type(value) == "table" and not (zoneSetups and zoneSetups[key]) then missingSetupPages[#missingSetupPages + 1] = key end
            end
            coroutine.yield()
        end
        for key in pairs(zoneSetups or {}) do
            if isIndex(key) then nextPageId = math.max(nextPageId, key + 1) end
            coroutine.yield()
        end
        self:ResolveSource(page)
        if selectedRow and source[selectedRow.index] ~= selectedRow.data then error("The source setup changed. Refresh the browser.") end
        if activeId ~= tostring(GetCurrentCharacterId()) or self:GetAccountData() ~= destination.account
            or rawget(destination.account, destination.id) ~= destination.storage then error("The destination changed. Refresh the browser.") end
        if destination.storage and (rawget(destination.storage, "pages") ~= destination.originalPages
            or rawget(destination.storage, "setups") ~= destination.originalSetups or destination.storage.version ~= destination.schema) then
            error("The destination changed. Refresh the browser.")
        end
        if destination.pages[page.tag] ~= zonePages or destination.setups[page.tag] ~= zoneSetups
            or (destination.active and (ww.pages ~= destination.pages or ww.setups ~= destination.setups)) then error("The destination changed. Refresh the browser.") end
        -- Publish only after all preparation and checks; never yield in this block.
        local pages = zonePages or { [0] = { selected = nextPageId } }
        local setups = zoneSetups or {}
        while pages[nextPageId] or setups[nextPageId] do nextPageId = nextPageId + 1 end
        for _, id in ipairs(missingSetupPages) do if setups[id] == nil then setups[id] = {} end end
        pages[nextPageId], setups[nextPageId] = metadata, copied
        destination.pages[page.tag], destination.setups[page.tag] = pages, setups
        local storage = destination.storage or { version = destination.schema, ["$LastCharacterName"] = destination.name }
        storage.pages, storage.setups = destination.pages, destination.setups
        if not destination.storage then destination.account[destination.id] = storage end
        return { tag = page.tag, pageId = nextPageId, name = metadata.name, count = #copied,
            characterId = destination.id, characterName = destination.name, sourceId = page.sourceId,
            metadata = metadata, data = copied }
    end, function(result)
        self.lastCopy = result
        if AUTO_SAVING and AUTO_SAVING.MarkDirty then AUTO_SAVING:MarkDirty() end
        self:SetStatus(string.format("Copied %d build(s) to %s / %s / %s.", result.count, result.characterName, result.tag, result.name), true)
        if complete then complete(result) end
    end)
end

function WH:OpenLastCopy()
    local copy, ww = self.lastCopy, WizardsWardrobe
    if not copy then return end
    if copy.characterId ~= tostring(GetCurrentCharacterId()) then
        self:SetStatus("Saved to " .. copy.characterName .. ". Log in to that character to equip the copied build in WW.")
        return
    end
    local page = ww.pages[copy.tag] and ww.pages[copy.tag][copy.pageId]
    local data = ww.setups[copy.tag] and ww.setups[copy.tag][copy.pageId]
    if page ~= copy.metadata or data ~= copy.data then self:SetStatus("The copied page moved or changed. Select it directly in WW."); return end
    if type(ww.gui) ~= "table" or type(ww.gui.OnZoneSelect) ~= "function" then return end
    ww.pages[copy.tag][0].selected = copy.pageId
    ww.gui.OnZoneSelect(ww.zones[copy.tag])
    if ww.markers and type(ww.markers.BuildGearList) == "function" then ww.markers.BuildGearList() end
    self:OpenWardrobe()
end

function WH:OpenWardrobe()
    local name = WizardsWardrobe.consoleControl and WizardsWardrobe.consoleControl.menuName or "Wizards Wardrobe Control"
    for _, parent in ipairs(ZO_MENU_ENTRIES or {}) do
        for _, entry in ipairs(parent.subMenu or {}) do
            local data = entry.data
            if data and data.addon and data.addon.name == name and type(data.activatedCallback) == "function" then data.activatedCallback(); return true end
        end
    end
    if SLASH_COMMANDS["/wizard"] then SLASH_COMMANDS["/wizard"](); return true end
    self:Message("Open Wizard's Wardrobe Control from the Add-ons menu.")
    return false
end
