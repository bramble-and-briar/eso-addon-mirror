-- Craft Master: no external libraries. All scans use the game's event manager.
CraftMaster = { name = "CraftMaster", version = "1.0.7" }
local CM = CraftMaster
local EM = EVENT_MANAGER
local GREEN, RED, GREY = "66ee88", "ff7777", "b7bec9"
local TICK = "|t28:28:EsoUI/Art/Buttons/checkbox_checked.dds|t"
local CROSS = "|t28:28:EsoUI/Art/Buttons/decline_up.dds|t"
function CM:Clean(text)
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, text)
end
function CM:Lower(text) return string.lower(self:Clean(text)) end
function CM:Link(id, subtype, level)
    -- ESO requires 21 numeric item-data fields, including scaling at field 20.
    return string.format("|H1:item:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h", id, subtype or 1, level or 1)
end
function CM:RecipeKey(list, index)
    local _, _, _, _, _, _, _, resultId = GetRecipeInfo(list, index)
    local link = GetRecipeResultItemLink(list, index, LINK_STYLE_DEFAULT)
    if link and link ~= "" then
        local actualId = GetItemLinkItemId(link)
        if actualId and actualId > 0 then resultId = actualId end
    end
    if resultId and resultId > 0 then return "r:" .. resultId end
end
function CM:ReadRecipe(list, index, pending)
    local known, name, _, _, _, _, station, resultId = GetRecipeInfo(list, index)
    if not resultId or resultId <= 0 or not name or name == "" then return end
    local link = GetRecipeResultItemLink(list, index, LINK_STYLE_DEFAULT)
    if not link or link == "" then link = self:Link(resultId)
    else
        local actualId = GetItemLinkItemId(link)
        if actualId and actualId > 0 then resultId = actualId end
    end
    local key = "r:" .. resultId
    local _, icon, _, _, quality = GetRecipeResultItemInfo(list, index)
    quality = quality or GetItemLinkDisplayQuality(link) or 1
    local cat, sub
    local dataId = GetItemLinkFurnitureDataId(link)
    if dataId and dataId > 0 then cat, sub = GetFurnitureDataCategoryInfo(dataId) end
    local furniture = cat ~= nil and cat > 0
    if not furniture then
        local itemType = GetItemLinkItemType(link)
        furniture = itemType == ITEMTYPE_FURNISHING
    end
    local e = self.sv.catalog[key] or {}
    e.key, e.name, e.resultId = key, self:Clean(name), resultId
    e.kind = furniture and "housing" or "recipes"
    e.category, e.subcategory = furniture and cat or nil, furniture and sub or nil
    e.list, e.index, e.quality, e.icon = list, index, quality, icon
    e.station = station
    e.resultType, e.resultLink = GetItemLinkItemType(link), link
    self.sv.catalog[key] = e
    self.searchNames[key] = self:Lower(e.name)
    if type(known) == "boolean" then pending[key] = known end
    return e
end
function CM:ResolvePlanRow(row)
    -- Verify both sides of the ID pair against native item types. Never infer
    -- recipe-vs-result identity from the order used by an external index.
    local candidates = {row[2], row[1]}
    for _, variant in ipairs({{1,1}, {0,0}, {5,1}}) do
        for _, id in ipairs(candidates) do
            local link = self:Link(id, variant[1], variant[2])
            if GetItemLinkItemType(link) == ITEMTYPE_RECIPE then
                local result = GetItemLinkRecipeResultItemLink(link, LINK_STYLE_DEFAULT)
                local fallbackResultId = id == row[1] and row[2] or row[1]
                if not result or result == "" then result = self:Link(fallbackResultId) end
                local resultId = GetItemLinkItemId(result)
                if resultId and resultId > 0 then return link, id, result, resultId end
            end
        end
    end
end
function CM:ReadCatalogPlan(row, pending)
    local planLink, planId, resultLink, resultId = self:ResolvePlanRow(row)
    if not planLink then self.scanSkippedPlans = (self.scanSkippedPlans or 0) + 1; return end
    local quality, fallbackCategory, fallbackName = row[3], row[4], row[5]
    local key = "r:" .. resultId
    local name = self:Clean(GetItemLinkName(resultLink))
    if name == "" then name = fallbackName or self:Clean(GetItemLinkName(planLink)) end
    if not name or name == "" then return end
    local resultType = GetItemLinkItemType(resultLink)
    local cat, sub
    local dataId = GetItemLinkFurnitureDataId(resultLink)
    if dataId and dataId > 0 then cat, sub = GetFurnitureDataCategoryInfo(dataId) end
    local furniture = resultType == ITEMTYPE_FURNISHING or (cat and cat > 0)
    if IsItemLinkFurnitureRecipe then furniture = furniture or IsItemLinkFurnitureRecipe(planLink) end
    if not furniture and self.categoryByName[self:Lower(fallbackCategory)] then furniture = true end
    if furniture and not cat then cat = self.categoryByName[self:Lower(fallbackCategory)] end
    local e = self.sv.catalog[key] or {}
    e.key, e.resultId, e.planId, e.name = key, resultId, planId, name
    e.kind = furniture and "housing" or "recipes"
    e.resultType, e.resultLink = resultType, resultLink
    e.category, e.subcategory = cat, sub
    e.quality = quality or GetItemLinkDisplayQuality(planLink) or 1
    self.sv.catalog[key], self.searchNames[key] = e, self:Lower(name)
    local known = IsItemLinkRecipeKnown(planLink)
    if type(known) == "boolean" and pending[key] ~= true then pending[key] = known end
    self.scanValidPlans = (self.scanValidPlans or 0) + 1
    return e
end
function CM:MotifCollections()
    local jobs = {}
    if not GetNumLoreCategories then return jobs end
    for c = 1, GetNumLoreCategories() do
        local categoryName, collections = GetLoreCategoryInfo(c)
        local categoryIsMotif = self:Lower(categoryName):find("motif", 1, true) ~= nil
        for l = 1, collections do
            local name, _, _, total = GetLoreCollectionInfo(c, l)
            local first = total > 0 and GetLoreBookInfo(c, l, 1) or ""
            -- English catalogue detection. Uses the game's own lore-book records.
            if categoryIsMotif or self:Lower(name):find("crafting motif", 1, true)
                or self:Lower(first):find("crafting motif", 1, true) then
                jobs[#jobs + 1] = { c = c, l = l, count = total }
            end
        end
    end
    return jobs
end
function CM:ReadMotif(c, l, b, pending)
    local title, icon, known, bookId = GetLoreBookInfo(c, l, b)
    if not title or title == "" then return end
    local key = "b:" .. bookId
    local e = self.sv.catalog[key] or {}
    e.key, e.name, e.kind, e.quality = key, self:Clean(title), "motifs", 4
    e.bookId, e.icon, e.c, e.l, e.b = bookId, icon, c, l, b
    self.sv.catalog[key] = e
    self.searchNames[key] = self:Lower(title)
    self.motifByTitle[self:Lower(title)] = key
    if type(known) == "boolean" then pending[key] = known end
end
function CM:CurrentCharacter()
    local id = tostring(GetCurrentCharacterId())
    local c = self.sv.characters[id]
    if not c then c = { knowledge = {} }; self.sv.characters[id] = c end
    c.name = self:Clean(GetUnitName("player"))
    return id, c
end
function CM:StartScan()
    if self.scanning then return end
    local id, character = self:CurrentCharacter()
    if not self.sv.main then self.sv.main = id end
    if not self.viewCharacter then self.viewCharacter = self.sv.main end
    self.scanning, self.scanCount, self.scanErrors = true, 0, 0
    self.scanValidPlans, self.scanSkippedPlans = 0, 0
    self.scanCharacter = id
    local list, index, loreJob, book, planIndex = 1, 1, 1, 1, 1
    local phase, pending = "recipes", {}
    self.pendingKnowledge = pending
    self.categoryByName = {}
    for i = 1, GetNumFurnitureCategories() do
        local categoryId = GetFurnitureCategoryId(i)
        self.categoryByName[self:Lower(GetFurnitureCategoryInfo(categoryId))] = categoryId
    end
    local planJobs, planSeen = {}, {}
    for _, row in ipairs(CraftMasterCatalog or {}) do
        planJobs[#planJobs + 1] = row
        planSeen[row[2]] = true
    end
    -- Retain plans encountered after this catalogue version was released.
    for _, e in pairs(self.sv.catalog) do
        if e.planId and not planSeen[e.planId] then
            planJobs[#planJobs + 1] = {e.resultId, e.planId, e.quality, "", e.name}
        end
    end
    local jobs = self:MotifCollections()
    local numLists = GetNumRecipeLists()
    local numInList = numLists > 0 and select(2, GetRecipeListInfo(1)) or 0
    EM:RegisterForUpdate(self.name .. "Scan", 50, function()
        if IsUnitInCombat("player") then return end
        -- Both a job-count ceiling and a wall-clock ceiling. No work during combat.
        local start = GetGameTimeMilliseconds()
        local steps = 0
        while steps < 18 and GetGameTimeMilliseconds() - start < 2 do
            if phase == "recipes" then
                if list > numLists then phase = "plans"
                elseif index > numInList then
                    list, index = list + 1, 1
                    numInList = list <= numLists and select(2, GetRecipeListInfo(list)) or 0
                else
                    local ok, entry = pcall(self.ReadRecipe, self, list, index, pending)
                    if not ok then self.scanErrors = self.scanErrors + 1
                    end
                    index = index + 1
                    self.scanCount = self.scanCount + 1
                end
            elseif phase == "plans" then
                local row = planJobs[planIndex]
                if not row then phase = "motifs"
                else
                    local ok = pcall(self.ReadCatalogPlan, self, row, pending)
                    if not ok then self.scanErrors = self.scanErrors + 1 end
                    planIndex, self.scanCount = planIndex + 1, self.scanCount + 1
                end
            elseif phase == "motifs" then
                local job = jobs[loreJob]
                if not job then
                    EM:UnregisterForUpdate(self.name .. "Scan")
                    -- Keep prior observations on partial/error scans; never invent missing states.
                    for key, value in pairs(pending) do character.knowledge[key] = value end
                    character.lastScan, character.api = GetTimeStamp(), GetAPIVersion()
                    character.complete = self.scanErrors == 0 and (#planJobs == 0 or self.scanValidPlans > 0)
                    character.validPlans, character.skippedPlans, character.scanErrors = self.scanValidPlans, self.scanSkippedPlans, self.scanErrors
                    self.scanning, self.pendingKnowledge = false, nil
                    -- An alt's known-only recipe list is never a reason to remove
                    -- the main crafter's catalogue or anyone else's saved knowledge.
                    self:RefreshIfVisible()
                    self:Message("Scan saved for " .. character.name .. " (" .. self.scanCount .. " records"
                        .. "; " .. self.scanValidPlans .. " plans checked, " .. self.scanSkippedPlans .. " skipped"
                        .. (self.scanErrors > 0 and "; " .. self.scanErrors .. " errors" or "") .. ").")
                    if self.rescanNeeded then
                        self.rescanNeeded = false
                        zo_callLater(function() self:StartScan() end, 500)
                    end
                    return
                elseif book > job.count then loreJob, book = loreJob + 1, 1
                else
                    local ok = pcall(self.ReadMotif, self, job.c, job.l, book, pending)
                    if not ok then self.scanErrors = self.scanErrors + 1 end
                    book, self.scanCount = book + 1, self.scanCount + 1
                end
            end
            steps = steps + 1
        end
        if self.window and not self.window:IsHidden() then self:UpdateSummary() end
    end)
    self:RefreshIfVisible()
end
function CM:Knowledge(key, characterId)
    local c = self.sv.characters[characterId or self.sv.main]
    if not c then return nil end
    return c.knowledge[key]
end
function CM:Status(key, id, icon)
    local known = self:Knowledge(key, id)
    if known == true then return "|c" .. GREEN .. (icon and TICK .. " " or "") .. "Learned|r" end
    if known == false then return "|c" .. RED .. (icon and CROSS .. " " or "") .. "Missing|r" end
    return "|c" .. GREY .. "Not checked|r"
end
function CM:KeyFromItemLink(link)
    local itemType = GetItemLinkItemType(link)
    if itemType == ITEMTYPE_RECIPE then
        local result = GetItemLinkRecipeResultItemLink(link, LINK_STYLE_DEFAULT)
        if result and result ~= "" then
            local id = GetItemLinkItemId(result)
            if id and id > 0 then
                local key = "r:" .. id
                if self.sv.catalog[key] then self.sv.catalog[key].planId = GetItemLinkItemId(link) end
                return key
            end
        end
        local list, index = GetItemLinkGrantedRecipeIndices(link)
        if list and index then return self:RecipeKey(list, index) end
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        return self.motifByTitle[self:Lower(GetItemLinkBookTitle(link))]
    end
end
function CM:TooltipLine(link)
    local itemType = GetItemLinkItemType(link)
    if itemType ~= ITEMTYPE_RECIPE and itemType ~= ITEMTYPE_RACIAL_STYLE_MOTIF then return end
    local c = self.sv.characters[self.sv.main]
    if not c then return "|c" .. GREY .. "Craft Master: select a main crafter|r" end
    local key = self:KeyFromItemLink(link)
    local known = key and self:Knowledge(key)
    -- Explicit false must survive; Lua's 'and' returns false correctly here.
    if key == nil then known = nil end
    if known == true then return "|c" .. GREEN .. TICK .. " " .. c.name .. " - Learned|r" end
    if known == false then return "|c" .. RED .. CROSS .. " " .. c.name .. " - Missing|r" end
    return "|c" .. GREY .. c.name .. " - Not checked|r"
end
function CM:InstallTooltips()
    if ZO_Tooltip and ZO_Tooltip.AddTopSection then
        ZO_PreHook(ZO_Tooltip, "AddTopSection", function(tooltip, link)
            local ok, line = pcall(self.TooltipLine, self, link)
            if ok and line then
                tooltip:AddLine(line, tooltip:GetStyle("bodyHeader"), { fontSize = 28 })
            end
            return false
        end)
    end
    -- Native ItemTooltip/PopupTooltip controls are userdata on console.
    -- Hook only the Lua ZO_Tooltip class above; never pass native controls
    -- to SecurePostHook, which accepts tables only.

end
function CM:Message(text) d("|c80c8ffCraft Master:|r " .. text) end
function CM:RefreshIfVisible()
    if self.window and not self.window:IsHidden() then self:Refresh() end
end
function CM:SetMain(id)
    if not self.sv.characters[id] then return end
    self.sv.main, self.viewCharacter = id, id
    self:Message("Main crafter: " .. self.sv.characters[id].name)
    self:RefreshIfVisible()
end
function CM:Slash(text)
    local command, rest = text:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    if command == "main" then
        if rest == "" then self:SetMain(tostring(GetCurrentCharacterId()))
        else
            for id, c in pairs(self.sv.characters) do
                if self:Lower(c.name) == self:Lower(rest) then self:SetMain(id); return end
            end
            self:Message("Log that character in first, or use /cm main on the crafter.")
        end
    elseif command == "scan" then self:StartScan()
    elseif command == "status" then
        local c = self.sv.characters[self.sv.main]
        self:Message("v" .. self.version .. "; Main: " .. (c and c.name or "none") .. "; catalogued: " .. self:CatalogCount()
            .. "; scan: " .. (self.scanning and "running (" .. self.scanCount .. ")" or "idle") .. "; plans checked: " .. (c and c.validPlans or 0) .. "; skipped: " .. (c and c.skippedPlans or 0)
            .. "; errors: " .. (c and c.scanErrors or 0) .. ".")
    else
        self:Toggle()
        if text ~= "" and self.window and not self.window:IsHidden() then self.search:SetText(text) end
    end
end
function CM:CatalogCount() local n = 0; for _ in pairs(self.sv.catalog) do n = n + 1 end; return n end
function CM:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("CraftMasterSavedVariables", 1, GetWorldName(),
        { characters = {}, catalog = {} })
    if self.sv.catalogRevision ~= 2 then
        -- Discard only recipe catalogue/snapshots built with unverified IDs.
        -- Preserve characters, chosen main and their motif records.
        for key, entry in pairs(self.sv.catalog) do
            if entry.kind ~= "motifs" then self.sv.catalog[key] = nil end
        end
        for _, c in pairs(self.sv.characters) do
            for key in pairs(c.knowledge) do
                if key:sub(1,2) == "r:" then c.knowledge[key] = nil end
            end
            c.complete, c.lastScan, c.validPlans, c.skippedPlans, c.scanErrors = false, nil, nil, nil, nil
        end
        self.sv.catalogRevision = 2
    end
    self.searchNames, self.motifByTitle = {}, {}
    for key, e in pairs(self.sv.catalog) do
        self.searchNames[key] = self:Lower(e.name)
        if e.kind == "motifs" then self.motifByTitle[self:Lower(e.name)] = key end
    end
    self.viewCharacter = self.sv.main
    self:InstallTooltips()
    SLASH_COMMANDS["/cm"] = function(text) self:Slash(text) end
    SLASH_COMMANDS["/craftmaster"] = SLASH_COMMANDS["/cm"]
    ZO_CreateStringId("SI_BINDING_NAME_CRAFT_MASTER_TOGGLE", "Open Craft Master")
    EM:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        if not self.activated then self.activated = true; self:StartScan() end
    end)
    EM:RegisterForEvent(self.name, EVENT_PLAYER_DEACTIVATED, function()
        EM:UnregisterForUpdate(self.name .. "Scan")
        self.scanning, self.activated, self.pendingKnowledge = false, false, nil
    end)
    EM:RegisterForEvent(self.name, EVENT_RECIPE_LEARNED, function(_, list, index)
        local _, c = self:CurrentCharacter()
        local entry = self:ReadRecipe(list, index, c.knowledge)
        if entry and self.pendingKnowledge then self.pendingKnowledge[entry.key] = true end
        self:RefreshIfVisible()
    end)
    EM:RegisterForEvent(self.name, EVENT_STYLE_LEARNED, function()
        -- A scan is rare here and picks up every chapter granted by a whole book.
        if not self.scanning then self:StartScan() else self.rescanNeeded = true end
    end)
end
EM:RegisterForEvent(CM.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= CM.name then return end
    EM:UnregisterForEvent(CM.name, EVENT_ADD_ON_LOADED)
    CM:Initialize()
end)
