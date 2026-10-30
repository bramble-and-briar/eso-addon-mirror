local WH = WizardsHelper

local function isIndex(value)
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

function WH:CheckWardrobe()
    local ww = WizardsWardrobe
    if type(ww) ~= "table" or type(ww.storage) ~= "table" or type(ww.setups) ~= "table"
        or type(ww.pages) ~= "table" or type(ww.zones) ~= "table" then
        return false, "Wizard's Wardrobe is not ready. Enable WW and reload the UI."
    end
    if ww.storage.setups ~= ww.setups or ww.storage.pages ~= ww.pages then
        return false, "Unsupported Wizard's Wardrobe storage layout."
    end
    if type(WizardsWardrobeSV) ~= "table" then
        return false, "Wizard's Wardrobe SavedVariables are not available. Reload the UI with WW enabled."
    end
    return true
end

function WH:GetAccountData()
    -- Never call ZO_SavedVars constructors for another character. Constructors
    -- can migrate keys, add defaults, or clear data when versions differ.
    local root = WizardsWardrobeSV
    local profile = type(root) == "table" and rawget(root, "Default")
    return type(profile) == "table" and rawget(profile, GetDisplayName()) or nil
end

function WH:GetRoster()
    local roster = {}
    for index = 1, GetNumCharacters() do
        local name, _, _, classId, _, _, characterId = GetCharacterInfo(index)
        if characterId then
            characterId = tostring(characterId)
            roster[characterId] = { id = characterId, name = zo_strformat("<<1>>", name), classId = classId }
        end
    end
    return roster
end

function WH:ScanSources(complete)
    return self:StartJob("Reading Wizard's Wardrobe setups...", function()
        local account, roster = self:GetAccountData(), self:GetRoster()
        local sources = {}
        if type(account) ~= "table" then return sources end
        local currentId, currentClass = tostring(GetCurrentCharacterId()), GetUnitClassId("player")
        for id, character in pairs(roster) do
            local storage = rawget(account, id)
            if id ~= currentId and character.classId == currentClass and type(storage) == "table"
                and type(storage.setups) == "table" and type(storage.pages) == "table" then
                local source = { id = id, name = character.name, pages = {} }
                for tag, zoneSetups in next, storage.setups do
                    local zonePages = storage.pages[tag]
                    if type(tag) == "string" and type(zoneSetups) == "table" and type(zonePages) == "table"
                        and WizardsWardrobe.zones[tag] then
                        for _, pageId in ipairs(self.SortedKeys(zoneSetups)) do
                            local setups, metadata = zoneSetups[pageId], zonePages[pageId]
                            if type(setups) == "table" and type(metadata) == "table" then
                                local page = {
                                    sourceId = id, sourceName = character.name, tag = tag, pageId = pageId,
                                    name = tostring(metadata.name or ("Page " .. pageId)), rows = {},
                                    data = setups, metadata = metadata,
                                }
                                for _, setupId in ipairs(self.SortedKeys(setups)) do
                                    local setup = setups[setupId]
                                    if type(setup) == "table" then
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
        return self.Sort(sources, function(a, b) return a.name < b.name end)
    end, complete)
end

function WH:ResolveSource(page)
    local account, roster = self:GetAccountData(), self:GetRoster()
    local character = roster[page.sourceId]
    if not character or character.classId ~= GetUnitClassId("player")
        or page.sourceId == tostring(GetCurrentCharacterId()) then
        error("The source must be another character of the same base class.")
    end
    local storage = type(account) == "table" and account[page.sourceId]
    if storage and (storage.setups == WizardsWardrobe.setups or storage.pages == WizardsWardrobe.pages) then
        error("Source and destination storage overlap. Reload the UI before copying.")
    end
    local setups = storage and storage.setups and storage.setups[page.tag]
    local pages = storage and storage.pages and storage.pages[page.tag]
    if not setups or setups[page.pageId] ~= page.data or not pages or pages[page.pageId] ~= page.metadata then
        error("The source page changed. Refresh the browser and select it again.")
    end
    return setups[page.pageId]
end

function WH.ValidateSetup(setup)
    if type(setup) ~= "table" or type(setup.name) ~= "string" or type(setup.code) ~= "string"
        or type(setup.skills) ~= "table" or type(setup.skills[0]) ~= "table" or type(setup.skills[1]) ~= "table"
        or type(setup.gear) ~= "table" or type(setup.cp) ~= "table" or type(setup.food) ~= "table"
        or type(setup.condition) ~= "table" then
        error("Unsupported WW setup structure. Nothing was copied.")
    end
    -- Validate structure only. WW owns skill, CP, equipment, and banking checks.
end

function WH:CopyPage(page, selectedRow, newName, complete)
    if not page or (selectedRow and not isIndex(selectedRow.index)) then return false end
    return self:StartJob("Preparing copy. Existing WW pages will be preserved...", function()
        local ok, reason = self:CheckWardrobe()
        if not ok then error(reason) end
        local ww, characterId = WizardsWardrobe, tostring(GetCurrentCharacterId())
        local targetSetups, targetPages = ww.setups, ww.pages
        local zoneSetups, zonePages = targetSetups[page.tag], targetPages[page.tag]
        if zonePages and (type(zonePages) ~= "table" or type(zonePages[0]) ~= "table") then
            error("Unsupported destination page metadata. Nothing was copied.")
        end
        local source = self:ResolveSource(page)
        if not ww.zones[page.tag] then error("WW does not recognize this zone.") end
        local copied = {}
        if selectedRow then
            if source[selectedRow.index] ~= selectedRow.data then error("The source setup changed. Refresh the browser.") end
            self.ValidateSetup(selectedRow.data)
            copied[1] = self.CopyTable(selectedRow.data)
        else
            local keys = self.SortedKeys(source)
            for position, index in ipairs(keys) do
                if index ~= position then error("The source page contains gaps. Repair it in WW before copying.") end
                self.ValidateSetup(source[index])
                copied[index] = self.CopyTable(source[index])
                coroutine.yield()
            end
        end
        if #copied == 0 then error("The source page is empty.") end
        local metadata = self.CopyTable(page.metadata)
        newName = type(newName) == "string" and newName:match("^%s*(.-)%s*$") or ""
        metadata.name = newName ~= "" and newName or (page.name .. " (" .. page.sourceName .. ")")
        local nextPageId = 1
        for _, collection in ipairs({ zonePages or {}, zoneSetups or {} }) do
            for key in next, collection do
                if isIndex(key) then nextPageId = math.max(nextPageId, key + 1) end
                coroutine.yield()
            end
        end
        self:ResolveSource(page)
        if selectedRow and source[selectedRow.index] ~= selectedRow.data then error("The source setup changed. Refresh the browser.") end
        if tostring(GetCurrentCharacterId()) ~= characterId or ww.setups ~= targetSetups or ww.pages ~= targetPages
            or ww.storage.setups ~= targetSetups or ww.storage.pages ~= targetPages
            or targetSetups[page.tag] ~= zoneSetups or targetPages[page.tag] ~= zonePages then
            error("The destination changed. Refresh the browser.")
        end
        local pages, setups = targetPages[page.tag], targetSetups[page.tag]
        -- Do not yield between choosing a free destination and publishing it.
        while (pages and pages[nextPageId]) or (setups and setups[nextPageId]) do nextPageId = nextPageId + 1 end
        pages = pages or { [0] = { selected = nextPageId } }
        setups = setups or {}
        pages[nextPageId], setups[nextPageId] = metadata, copied
        targetPages[page.tag], targetSetups[page.tag] = pages, setups
        return { tag = page.tag, pageId = nextPageId, name = metadata.name, count = #copied,
            characterId = characterId, metadata = metadata, data = copied }
    end, function(result)
        self.lastCopy = result
        if AUTO_SAVING and AUTO_SAVING.MarkDirty then AUTO_SAVING:MarkDirty() end
        self:SetStatus(string.format("Copied %d setup(s) to %s / %s. Open the new page in WW to use it.", result.count, result.tag, result.name), true)
        if complete then complete(result) end
    end)
end

function WH:OpenLastCopy()
    local copy, ww = self.lastCopy, WizardsWardrobe
    if not copy or copy.characterId ~= tostring(GetCurrentCharacterId()) then return end
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
    -- Launch WW's own existing controls through their native console menu entry.
    local name = WizardsWardrobe.consoleControl and WizardsWardrobe.consoleControl.menuName or "Wizards Wardrobe Control"
    for _, parent in ipairs(ZO_MENU_ENTRIES or {}) do
        for _, entry in ipairs(parent.subMenu or {}) do
            local data = entry.data
            if data and data.addon and data.addon.name == name and type(data.activatedCallback) == "function" then
                data.activatedCallback()
                return true
            end
        end
    end
    if SLASH_COMMANDS["/wizard"] then SLASH_COMMANDS["/wizard"](); return true end
    self:Message("Open Wizard's Wardrobe Control from the Add-ons menu.")
    return false
end
