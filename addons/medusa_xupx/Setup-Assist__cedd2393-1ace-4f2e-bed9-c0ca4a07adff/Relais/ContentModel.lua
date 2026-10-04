-- Content pages and shared setup references. SavedVars identity stays stable.
local R = Relais
local GENERAL = { id = "general", category = "general", name = "Général", nameEn = "General", encounters = {} }
local DUNGEONS = { id = "dungeons:general", category = "dungeons", name = "Donjons", nameEn = "Dungeons", namesByLocale = { fr = "Donjons", en = "Dungeons" }, encounters = {}, sharedDungeons = true,
    difficulty = { normal = true, veteran = true, hardMode = { supported = true, detection = "manual" } } }
local DIFFICULTIES = { any = true, normal = true, veteran = true, hard = true }
local ROLES = { any = true, tank = true, healer = true, damage = true }
local function Table(value) return type(value) == "table" and value or {} end
local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = DeepCopy(v) end
    return result
end
local function ContentId(value) return type(value) == "table" and value.id or value end
local function Language()
    if type(GetCVar) == "function" then
        local ok, language = pcall(GetCVar, "language.2")
        if ok and type(language) == "string" then return language end
    end
    return "fr"
end
local function Clean(text)
    return type(text) == "string" and text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("[%c]", " ") or ""
end
local function FormatName(text)
    if type(zo_strformat) == "function" and SI_UNIT_NAME then
        local ok, name = pcall(zo_strformat, SI_UNIT_NAME, text)
        if ok and type(name) == "string" then return Clean(name) end
    end
    return Clean(text)
end
local function Normalize(self, name)
    if self.NormalizeBossName then return self:NormalizeBossName(name) end
    name = FormatName(name)
    return type(zo_strlower) == "function" and zo_strlower(name) or string.lower(name)
end
local function Changed(self)
    self:SavedDataChanged()
    self:RefreshUI()
end

function R:GetContent(value)
    local id = ContentId(value)
    if id == "general" then return GENERAL end
    if id == DUNGEONS.id then return DUNGEONS end
    for _, content in ipairs(Table(self.ContentCatalog).entries or {}) do if content.id == id then return content end end
end

function R:GetContentSetupId(value)
    local content = type(value) == "table" and value or self:GetContent(value)
    if not content then return nil end
    return content.category == "dungeons" and DUNGEONS.id or content.id
end

function R:GetContentName(value)
    local content = type(value) == "table" and value or self:GetContent(value)
    if not content then return "Contenu indisponible" end
    local language = Language()
    if type(Table(content.namesByLocale)[language]) == "string" then return FormatName(content.namesByLocale[language]) end
    if content.localizedName and content.localizedLanguage == language then return FormatName(content.localizedName) end
    return FormatName(language == "fr" and content.name or (content.nameEn or content.name))
end

function R:GetCurrentContent()
    local zone = self.GetZoneId and self:GetZoneId() or 0
    if zone == 0 then return nil end
    local found
    for _, content in ipairs(Table(self.ContentCatalog).entries or {}) do
        for _, id in ipairs(content.zoneIdentityVerifiedInGame ~= false and content.zoneIds or {}) do
            if id == zone then
                if found and found.id ~= content.id then return nil end
                found = content
            end
        end
    end
    return found
end

function R:IsContentFavorite(id)
    return Table(Table(self.db).contentSettings).favorites and self.db.contentSettings.favorites[id] == true or false
end

function R:IsAutomaticContentNavigationEnabled()
    return self.db.contentSettings.navigateAutomatically == true
end

function R:SetAutomaticContentNavigation(enabled)
    if type(enabled) ~= "boolean" then return false end
    self.db.contentSettings.navigateAutomatically = enabled
    Changed(self)
    return true
end

function R:SetContentFavorite(id, enabled)
    if not self:GetContent(id) or type(enabled) ~= "boolean" then return false end
    self.db.contentSettings.favorites[id] = enabled or nil
    Changed(self)
    return true
end

function R:GetContentEntries(category, options)
    options = Table(options)
    if category == "raids" then category = "trials" end
    local query = Normalize(self, options.query or "")
    local result = {}
    local contents = {}
    for _, content in ipairs(Table(self.ContentCatalog).entries or {}) do
        if (content.category ~= "dungeons" or options.includeIndividualDungeons == true)
            and (not content.eventContent or content.zoneIdentityVerifiedInGame == true or options.includeHistoricalEvents == true) then contents[#contents + 1] = content end
    end
    if options.includeIndividualDungeons ~= true then contents[#contents + 1] = DUNGEONS end
    for _, content in ipairs(contents) do
        local favorite = self:IsContentFavorite(content.id)
        local matches = category == nil or category == content.category or (category == "favorites" and favorite)
        if matches and (options.dlc == nil or content.dlc == options.dlc) and (not options.favorites or favorite) then
            if query == "" or Normalize(self, self:GetContentName(content)):find(query, 1, true)
                or Normalize(self, content.nameEn or ""):find(query, 1, true) then result[#result + 1] = content end
        end
    end
    table.sort(result, function(a, b) return self:GetContentName(a) < self:GetContentName(b) end)
    return result
end

function R:GetPageEntries(contentId, difficulty)
    local entries = {}
    for _, id in ipairs(self:GetPageIds()) do
        local context = Table(Table(self.db.pageContexts)[id])
        local content, mode = context.contentId or "general", context.difficulty or "any"
        if (contentId == nil or contentId == content) and (difficulty == nil or difficulty == "any" or difficulty == mode) then
            entries[#entries + 1] = { id = id, name = self:GetPageName(id), contentId = content, difficulty = mode, role = context.role or "any" }
        end
    end
    return entries
end

function R:NormalizeContentData()
    local db, repaired = self.db, false
    self:InitializeRaidRouteEncounters()
    local currentSchema = db.schema
    local function RepairContainer(parent, key, path)
        if type(parent[key]) == "table" then return end
        if parent[key] ~= nil or (type(currentSchema) == "number" and currentSchema >= 3) then
            db.recoveredContentData = Table(db.recoveredContentData)
            if parent[key] ~= nil then db.recoveredContentData[path or key] = parent[key] end
            repaired = true
        end
        parent[key] = {}
    end
    RepairContainer(db, "contentSettings")
    for _, key in ipairs({ "favorites", "activePages", "difficultyOverride", "initialTrash", "encounterAliases" }) do
        RepairContainer(db.contentSettings, key, "contentSettings." .. key)
    end
    -- This optional feature was introduced after the base catalogue schema.
    -- An absent field stays disabled, including on existing schema-3 saves.
    if db.contentSettings.dungeonBossObservation == nil then db.contentSettings.dungeonBossObservation = {}
    else RepairContainer(db.contentSettings, "dungeonBossObservation", "contentSettings.dungeonBossObservation") end
    db.contentSettings.navigateAutomatically = db.contentSettings.navigateAutomatically == true
    if type(db.pageContexts) ~= "table" then db.recoveredPageContexts = db.pageContexts; RepairContainer(db, "pageContexts") end
    for id in pairs(db.pages) do
        local context = db.pageContexts[id]
        if type(context) ~= "table" then
            if context ~= nil or (type(currentSchema) == "number" and currentSchema >= 3) then
                if context ~= nil then
                    db.recoveredContentData = Table(db.recoveredContentData)
                    db.recoveredContentData["pageContexts." .. tostring(id)] = context
                end
                repaired = true
            end
            context = {}; db.pageContexts[id] = context
        end
        if context.unavailableContentId and self:GetContent(context.unavailableContentId) then
            context.contentId, context.unavailableContentId = context.unavailableContentId, nil
        end
        if not self:GetContent(context.contentId or "general") then
            context.unavailableContentId, context.contentId = context.contentId, "general"; repaired = true
        end
        local storedContent = self:GetContent(context.contentId)
        if storedContent and storedContent.category == "dungeons" and storedContent.id ~= DUNGEONS.id then
            context.recoveredDungeonContentId, context.contentId = context.contentId, "general"; repaired = true
        end
        context.contentId = context.contentId or "general"
        if id == 1 then context.contentId = "general" end
        if context.difficulty ~= nil and not DIFFICULTIES[context.difficulty] then
            context.recoveredDifficulty, context.difficulty = context.difficulty, "any"; repaired = true
        end
        context.difficulty = context.difficulty or "any"
        context.role = ROLES[context.role] and context.role or "any"
    end
    for id in pairs(db.pageContexts) do if not db.pages[id] then db.pageContexts[id] = nil end end
    for contentId, pages in pairs(db.contentSettings.activePages) do
        if type(pages) ~= "table" then db.contentSettings.activePages[contentId] = nil; repaired = true
        else
            for difficulty, pageId in pairs(pages) do
                local context = Table(db.pageContexts[pageId])
                if not DIFFICULTIES[difficulty] or not db.pages[pageId] or context.contentId ~= contentId
                    or (context.difficulty ~= "any" and context.difficulty ~= difficulty) then
                    pages[difficulty] = nil; repaired = true
                end
            end
        end
    end
    for id, mode in pairs(db.contentSettings.difficultyOverride) do
        if not DIFFICULTIES[mode] or mode == "any" then
            db.contentSettings.recoveredDifficultyOverride = Table(db.contentSettings.recoveredDifficultyOverride)
            db.contentSettings.recoveredDifficultyOverride[id] = mode
            db.contentSettings.difficultyOverride[id] = nil; repaired = true
        end
    end
    if type(db.contentAssignments) ~= "table" then db.recoveredContentAssignments = db.contentAssignments; RepairContainer(db, "contentAssignments") end
    for contentId, pages in pairs(db.contentAssignments) do
        if type(pages) == "table" then
            for pageId, slots in pairs(pages) do
                local context = db.pageContexts[pageId]
                if type(slots) ~= "table" or not context or context.contentId ~= contentId then
                    db.recoveredContentAssignments = Table(db.recoveredContentAssignments)
                    db.recoveredContentAssignments[contentId] = Table(db.recoveredContentAssignments[contentId])
                    db.recoveredContentAssignments[contentId][pageId] = slots
                    pages[pageId] = nil; repaired = true
                else
                    for key, profileId in pairs(slots) do
                        if type(key) ~= "string" or type(profileId) ~= "number" or not db.profiles[profileId] then
                            slots[key] = nil; repaired = true
                        end
                    end
                end
            end
        else
            db.recoveredContentAssignments = Table(db.recoveredContentAssignments)
            db.recoveredContentAssignments[contentId], db.contentAssignments[contentId] = pages, nil; repaired = true
        end
    end
    if repaired then
        db.settings.automatic = false
        self.savedDataMessage = "Associations réorganisées. Vérifie tes pages avant de réactiver l'automatique."
    end
    if self.NormalizeRaidLayouts then self:NormalizeRaidLayouts() end
    if self.NormalizeRaidRouteData then self:NormalizeRaidRouteData() end
    db.schema = 3
end

function R:CreateContentPage(contentId, difficulty, name, role)
    local content = self:GetContent(contentId)
    if not content or not DIFFICULTIES[difficulty or "any"] then return nil, "Choisis un contenu et une difficulté disponibles." end
    if content.category == "dungeons" and content.id ~= DUNGEONS.id then return nil, "Utilise la rubrique Donjons pour tes pages communes." end
    if difficulty == "hard" and Table(Table(content.difficulty).hardMode).supported == false then return nil, "Ce contenu n'a pas de mode difficile renseigné." end
    local id = self:CreatePage(name)
    if not id then return nil end
    self.db.pageContexts[id] = { contentId = contentId, difficulty = difficulty or "any", role = ROLES[role] and role or "any" }
    self:SetActiveContentPage(contentId, difficulty or "any", id)
    return id
end

function R:MovePageToContent(pageId, contentId, difficulty, role)
    if not self.db.pages[pageId] or (pageId == 1 and contentId ~= "general") or not self:GetContent(contentId)
        or not DIFFICULTIES[difficulty or "any"] then return false, "Cette page ne peut pas être déplacée ici." end
    if self:GetContent(contentId).category == "dungeons" and contentId ~= DUNGEONS.id then return false, "Utilise la rubrique Donjons pour tes pages communes." end
    if difficulty == "hard" and Table(Table(self:GetContent(contentId).difficulty).hardMode).supported == false then return false, "Ce contenu n'a pas de mode difficile renseigné." end
    self:RemoveContentPage(pageId)
    self.db.pageContexts[pageId] = { contentId = contentId, difficulty = difficulty or "any", role = ROLES[role] and role or "any" }
    self:SetActiveContentPage(contentId, difficulty or "any", pageId)
    return true
end

function R:SetActiveContentPage(contentId, difficulty, pageId)
    difficulty = difficulty or "any"
    local context = self.db.pageContexts[pageId]
    if not self:GetContent(contentId) or not DIFFICULTIES[difficulty] or not self.db.pages[pageId] or not context
        or context.contentId ~= contentId or (context.difficulty ~= "any" and context.difficulty ~= difficulty) then
        return false, "Cette page ne correspond pas au contenu ou à la difficulté."
    end
    local pages = self.db.contentSettings.activePages
    pages[contentId] = Table(pages[contentId])
    local previous = pages[contentId][difficulty]
    pages[contentId][difficulty] = pageId
    if previous ~= pageId and self:GetContent(contentId).category == "trials" and self.InvalidateRaidProgress then
        self:InvalidateRaidProgress(contentId, pageId, "page")
    end
    Changed(self)
    return true
end

function R:GetActiveContentPage(contentId, difficulty)
    if not self:GetContent(contentId) then return nil end
    local active = Table(self.db.contentSettings.activePages[contentId])
    for _, key in ipairs(difficulty and { difficulty, "any" } or { "any" }) do
        local id = active[key]
        local context = Table(self.db.pageContexts[id])
        if self.db.pages[id] and context.contentId == contentId and (context.difficulty == "any" or context.difficulty == difficulty) then return id end
    end
    local match, common
    for _, entry in ipairs(self:GetPageEntries(contentId)) do
        if entry.difficulty == difficulty and not match then match = entry.id end
        if entry.difficulty == "any" and not common then common = entry.id end
    end
    return match or common
end

function R:GetSelectedContentDifficulty(value)
    return self.db.contentSettings.difficultyOverride[self:GetContentSetupId(value) or ContentId(value)] or "any"
end

function R:SetContentDifficulty(value, mode)
    local content = self:GetContent(value)
    if not content or not DIFFICULTIES[mode] then return false end
    if mode == "hard" and Table(Table(content.difficulty).hardMode).supported == false then return false, "Ce contenu n'a pas de mode difficile renseigné." end
    local previous = self:GetSelectedContentDifficulty(content)
    self.db.contentSettings.difficultyOverride[self:GetContentSetupId(content)] = mode ~= "any" and mode or nil
    if previous ~= mode and content.category == "trials" and self.InvalidateRaidProgress then self:InvalidateRaidProgress(content.id, nil, "difficulty") end
    Changed(self)
    return true
end

function R:GetContentDifficulty(value)
    local selected = self:GetSelectedContentDifficulty(value)
    if selected ~= "any" and DIFFICULTIES[selected] then return selected end
    if type(GetCurrentZoneDungeonDifficulty) == "function" then
        local ok, mode = pcall(GetCurrentZoneDungeonDifficulty)
        if ok and mode == 1 then return "normal" end
        if ok and mode == 2 then return "veteran" end
    end
end

local function RouteAllowed(route, context)
    local mode = Table(context).difficulty or "any"
    if mode == "any" then return true end
    if type(route.difficulties) == "table" then return route.difficulties[mode] == true end
    return route.difficulty == nil or route.difficulty == "any" or route.difficulty == mode
end

function R:GetRaidRoutes(value, pageId)
    local content = self:GetContent(value)
    if not content or content.category ~= "trials" or content.eventContent then return {} end
    local routes = Table(Table(self.RaidRouteCatalog)[content.id]).routes
    local result = {}
    local context = Table(Table(Table(self.db).pageContexts)[pageId])
    for _, route in ipairs(Table(routes)) do
        if type(route.id) == "string" and type(route.steps) == "table" and RouteAllowed(route, context) then
            result[#result + 1] = route
        end
    end
    return result
end

local function ApplyRaidLayout(self, route, contentId, pageId)
    local layout = Table(Table(Table(self.db).raidLayouts)[pageId])[route.id]
    if type(layout) ~= "table" or layout.contentId ~= contentId or type(layout.order) ~= "table" then return route end
    local composed, byId = DeepCopy(route), {}
    for _, step in ipairs(composed.steps) do byId[step.id] = step end
    for id, step in pairs(Table(layout.extraSteps)) do
        if type(step) == "table" then byId[id] = DeepCopy(step) end
    end
    composed.steps = {}
    for _, id in ipairs(layout.order) do
        local step = byId[id]
        if step then
            local name = Table(layout.names)[id]
            if type(name) == "string" then step.name, step.nameEn, step.namesByLocale = name, name, {} end
            composed.steps[#composed.steps + 1] = step
        end
    end
    composed.personalized, composed.orderModified = true, layout.orderModified == true
    composed.orderVerified = route.orderVerified == true and not composed.orderModified
    composed.originalName, composed.name = route.name, route.name .. " · personnalisé"
    if composed.orderModified then
        composed.description = (route.description or "") .. " Ordre personnalisé : reprends et charge les étapes manuellement ; aucun passage suivant n'est déduit."
    end
    return composed
end

function R:GetRaidRoute(value, pageId, routeId)
    local id = ContentId(value)
    local selected = routeId or Table(Table(Table(self.db).contentSettings).routeSelections)[pageId]
    local routes = self:GetRaidRoutes(id, pageId)
    local fallback = Table(Table(self.RaidRouteCatalog)[id]).defaultRoute
    local default
    for _, route in ipairs(routes) do
        if route.id == selected then return ApplyRaidLayout(self, route, id, pageId) end
        if route.id == fallback then default = route end
    end
    if routeId ~= nil then return nil end
    local route = default or routes[1]
    return route and ApplyRaidLayout(self, route, id, pageId) or nil
end

function R:InitializeRaidRouteEncounters()
    local changed = false
    for _, content in ipairs(Table(self.ContentCatalog).entries or {}) do
        local existing = {}
        for _, encounter in ipairs(content.encounters or {}) do existing[encounter.id] = true end
        for _, encounter in ipairs(Table(Table(self.RaidRouteCatalog)[content.id]).additionalEncounters or {}) do
            if type(encounter.id) == "string" and not existing[encounter.id] then
                content.encounters = content.encounters or {}
                content.encounters[#content.encounters + 1] = DeepCopy(encounter)
                existing[encounter.id], changed = true, true
            end
        end
    end
    return changed
end

local function FindEncounter(self, contentId, encounterId)
    for _, encounter in ipairs(Table(self:GetContent(contentId)).encounters or {}) do
        if encounter.id == encounterId then return encounter end
    end
end

function R:GetRaidSteps(contentId, pageId, routeId)
    local route = self:GetRaidRoute(contentId, pageId, routeId)
    if not route then return {} end
    local result = {}
    for _, definition in ipairs(route.steps) do
        local step = DeepCopy(definition)
        step.custom, step.isOfficial = definition.custom == true, definition.custom ~= true
        local encounter = FindEncounter(self, contentId, step.encounterId)
        local before = FindEncounter(self, contentId, step.beforeEncounterId)
        local after = FindEncounter(self, contentId, step.afterEncounterId)
        step.key = "stage:" .. step.id
        if step.name then step.name = self:GetContentName(step)
        elseif step.kind == "free" then step.name = "Setup libre"
        elseif step.kind == "boss" then step.name = "Boss — " .. self:GetContentName(encounter)
        elseif before and after then step.name = "Trash — de " .. self:GetContentName(after) .. " à " .. self:GetContentName(before)
        elseif before then step.name = "Trash — vers " .. self:GetContentName(before)
        elseif after then step.name = "Trash — après " .. self:GetContentName(after)
        else step.name = "Trash — entrée du raid" end
        if not step.description then
            step.description = step.kind == "free" and "Setup libre de cette page ; chargement manuel hors combat."
                or step.kind == "boss" and "Setup de cette rencontre ; chargement hors combat."
                or "Setup de cette portion de parcours ; les autres portions gardent leurs propres associations."
        end
        if step.optional then step.description = step.description .. " Rencontre facultative." end
        step.routeId, step.verified, step.available = route.id, route.orderVerified == true, true
        result[#result + 1] = step
    end
    return result
end

function R:GetRaidStep(contentId, pageId, stepId)
    if type(stepId) ~= "string" then return nil end
    stepId = stepId:gsub("^stage:", "")
    for _, step in ipairs(self:GetRaidSteps(contentId, pageId)) do if step.id == stepId then return step end end
end

function R:SetRaidRoute(contentId, pageId, routeId)
    local context = Table(Table(self.db.pageContexts)[pageId])
    if not self.db.pages[pageId] or context.contentId ~= contentId or not self:GetRaidRoute(contentId, pageId, routeId) then
        return false, "Choisis un parcours disponible pour cette page."
    end
    self.db.contentSettings.routeSelections = Table(self.db.contentSettings.routeSelections)
    if self.db.contentSettings.routeSelections[pageId] == routeId then return true end
    self.db.contentSettings.routeSelections[pageId] = routeId
    if self.InvalidateRaidProgress then self:InvalidateRaidProgress(contentId, pageId, "route") end
    Changed(self)
    return true
end

function R:GetEffectiveRaidStepProfile(contentId, pageId, stepId)
    local step = self:GetRaidStep(contentId, pageId, stepId)
    if not step then return nil end
    local assignments = Table(Table(Table(self.db.contentAssignments)[contentId])[pageId])
    local id = self:GetAssignedProfile(contentId, pageId, step.key)
    if id then return id, "stage" end
    if assignments[step.key] ~= nil then return nil, "invalid" end
    if step.kind == "free" then return nil end
    local fallback = step.kind == "trash" and "trash" or "boss"
    id = self:GetAssignedProfile(contentId, pageId, fallback)
    if id == nil and assignments[fallback] ~= nil then return nil, "invalid" end
    return id, id and fallback or nil
end

function R:GetProfileContentAssignments(profileId)
    local result = {}
    for contentId, pages in pairs(Table(self.db.contentAssignments)) do
        for pageId, slots in pairs(Table(pages)) do
            local names = {}
            for _, route in ipairs(self:GetRaidRoutes(contentId)) do
                local steps = self:GetRaidSteps(contentId, pageId, route.id)
                if #steps == 0 then steps = self:GetRaidSteps(contentId, nil, route.id) end
                for _, slot in ipairs(steps) do names[slot.key] = slot.name end
            end
            for _, slot in ipairs(self:GetContentSlots(contentId, pageId)) do names[slot.key] = slot.name end
            for key, id in pairs(Table(slots)) do
                if id == profileId then result[#result + 1] = { contentId = contentId, pageId = pageId, key = key,
                    name = names[key] or (key:match("^stage:") and "Emplacement retiré du parcours" or key) } end
            end
        end
    end
    table.sort(result, function(a, b)
        return tostring(a.contentId) .. ":" .. tostring(a.pageId) .. ":" .. a.key < tostring(b.contentId) .. ":" .. tostring(b.pageId) .. ":" .. b.key
    end)
    return result
end

function R:NormalizeRaidRouteData()
    local db = self.db
    local settings = db.contentSettings
    if type(settings.routeSelections) ~= "table" then
        if settings.routeSelections ~= nil then settings.recoveredRouteSelections = settings.routeSelections end
        settings.routeSelections = {}
    end
    for pageId, selected in pairs(settings.routeSelections) do
        local context = Table(db.pageContexts[pageId])
        if not db.pages[pageId] or not self:GetRaidRoute(context.contentId, pageId, selected) then
            settings.recoveredRouteSelections = Table(settings.recoveredRouteSelections)
            settings.recoveredRouteSelections[pageId], settings.routeSelections[pageId] = selected, nil
        end
    end
    if type(db.raidRouteMigrations) ~= "table" then
        if db.raidRouteMigrations ~= nil then db.recoveredRaidRouteMigrations = db.raidRouteMigrations end
        db.raidRouteMigrations = {}
    end
    for contentId, pages in pairs(Table(db.contentAssignments)) do
        -- Migration uses the union of route definitions, never the current list order.
        local mappings = {}
        for _, route in ipairs(self:GetRaidRoutes(contentId)) do
            for _, step in ipairs(route.steps) do
                for _, key in ipairs(Table(step.legacyKeys)) do
                    mappings[key] = Table(mappings[key]); mappings[key]["stage:" .. step.id] = true
                end
            end
        end
        for pageId, slots in pairs(Table(pages)) do
            db.raidRouteMigrations[contentId] = Table(db.raidRouteMigrations[contentId])
            local notes = Table(db.raidRouteMigrations[contentId][pageId])
            db.raidRouteMigrations[contentId][pageId] = notes
            local legacy = {}
            for key, profileId in pairs(Table(slots)) do
                if type(key) == "string" and (key:match("^encounter:") or key:match("^after:")) then
                    legacy[#legacy + 1] = { key = key, profileId = profileId }
                end
            end
            for _, association in ipairs(legacy) do
                local key, profileId = association.key, association.profileId
                if type(key) == "string" and (key:match("^encounter:") or key:match("^after:")) then
                    local targets, count, target = mappings[key], 0
                    for candidate in pairs(Table(targets)) do count, target = count + 1, candidate end
                    if count == 1 then
                        local previous = Table(notes[key])
                        local alreadyMapped = previous.status == "mapped" and previous.profileId == profileId and previous.target == target
                        if slots[target] == nil and not alreadyMapped then slots[target] = profileId end
                        if alreadyMapped or slots[target] == profileId then
                            notes[key] = { target = target, profileId = profileId, status = "mapped" }
                        else
                            notes[key] = { profileId = profileId, status = "kept", reason = "differentAssignment" }
                        end
                    elseif #self:GetRaidRoutes(contentId) > 0 then
                        notes[key] = { profileId = profileId, status = "kept", reason = count == 0 and "noFollowingStage" or "severalStages" }
                    end
                end
            end
        end
    end
    db.raidRouteSchema = 1
end

function R:GetRaidMigrationNotes(contentId, pageId)
    local result = {}
    local slots = Table(Table(Table(self.db.contentAssignments)[contentId])[pageId])
    for key, note in pairs(Table(Table(Table(self.db.raidRouteMigrations)[contentId])[pageId])) do
        if type(note) == "table" and note.status == "kept" and slots[key] == note.profileId and self.db.profiles[note.profileId] then
            result[#result + 1] = { key = key, profileId = note.profileId, reason = note.reason }
        end
    end
    table.sort(result, function(a, b) return a.key < b.key end)
    return result
end

local function PersonalName(value)
    if type(value) ~= "string" then return nil end
    local name = Clean(value):gsub("^%s+", ""):gsub("%s+$", "")
    local _, characters = name:gsub("[^\128-\191]", "")
    if name == "" or characters > 48 or #name > 192 then return nil end
    return name
end

local function EditableRaid(self, contentId, pageId)
    local context = Table(Table(self.db.pageContexts)[pageId])
    if not self.db.pages[pageId] or context.contentId ~= contentId then return nil, "Cette page de raid n'est plus disponible." end
    if self.bankTransfer or (self.engine and type(self.engine.IsBusy) == "function" and self.engine:IsBusy()) then return nil, "Attends la fin de l'action en cours." end
    local route = self:GetRaidRoute(contentId, pageId)
    if not route then return nil, "Ce parcours n'est plus disponible." end
    return route
end

local function EditLayout(self, contentId, pageId, route)
    self.db.raidLayouts = Table(self.db.raidLayouts)
    self.db.raidLayouts[pageId] = Table(self.db.raidLayouts[pageId])
    local layout = self.db.raidLayouts[pageId][route.id]
    if not layout then
        layout = {contentId = contentId, order = {}, extraSteps = {}, names = {}, nextId = 1, orderModified = false}
        for _, step in ipairs(route.steps) do layout.order[#layout.order + 1] = step.id end
        self.db.raidLayouts[pageId][route.id] = layout
    end
    return layout
end

local function RaidLayoutChanged(self, contentId, pageId, orderChanged)
    if orderChanged and self.InvalidateRaidProgress then self:InvalidateRaidProgress(contentId, pageId, "layout") end
    if self.SuppressAutomationForContext then self:SuppressAutomationForContext() end
    Changed(self)
end

function R:AddRaidStep(contentId, pageId, name, kind, afterStepId)
    local route, problem = EditableRaid(self, contentId, pageId)
    if not route then return nil, problem end
    kind = kind or "free"
    local clean = PersonalName(name)
    if not clean or (kind ~= "free" and kind ~= "trash" and kind ~= "boss") then return nil, "Choisis un nom court et un type d'emplacement." end
    if #route.steps >= 128 then return nil, "Limite de 128 étapes atteinte pour ce parcours." end
    local insertAt = #route.steps + 1
    if afterStepId then
        local found
        for index, step in ipairs(route.steps) do if step.id == afterStepId then insertAt, found = index + 1, true end end
        if not found then return nil, "L'étape de départ n'est plus disponible." end
    end
    local layout = EditLayout(self, contentId, pageId, route)
    local number = self.db.nextRaidStepId or layout.nextId or 1
    local id = "custom:" .. route.id .. ":" .. number
    local retained = Table(Table(Table(self.db.contentAssignments)[contentId])[pageId])
    while layout.extraSteps[id] or retained["stage:" .. id] ~= nil do number = number + 1; id = "custom:" .. route.id .. ":" .. number end
    if number >= 1000000000 then return nil, "Limite d'emplacements personnels atteinte." end
    layout.nextId = number + 1
    self.db.nextRaidStepId = number + 1
    layout.extraSteps[id] = {id = id, kind = kind, name = clean, nameEn = clean, custom = true, victorySafe = false,
        description = "Emplacement personnel : choisis et charge son setup manuellement. Aucune reconnaissance de boss n'est déduite."}
    table.insert(layout.order, insertAt, id)
    layout.orderModified = true
    RaidLayoutChanged(self, contentId, pageId, true)
    return id
end

function R:RenameRaidStep(contentId, pageId, stepId, name)
    local route, problem = EditableRaid(self, contentId, pageId)
    if not route then return false, problem end
    local step, clean = self:GetRaidStep(contentId, pageId, stepId), PersonalName(name)
    if not step or not clean then return false, "Choisis une étape et un nom court." end
    local layout = EditLayout(self, contentId, pageId, route)
    layout.names[step.id] = clean
    RaidLayoutChanged(self, contentId, pageId, false)
    return true
end

function R:MoveRaidStep(contentId, pageId, stepId, delta)
    local route, problem = EditableRaid(self, contentId, pageId)
    if not route then return false, problem end
    if delta ~= -1 and delta ~= 1 then return false, "Choisis Monter ou Descendre." end
    local step, index = self:GetRaidStep(contentId, pageId, stepId)
    if not step then return false, "Cette étape n'est plus disponible." end
    for i, entry in ipairs(route.steps) do if entry.id == step.id then index = i end end
    local target = index and index + delta
    if not target or target < 1 or target > #route.steps then return false, "Cette étape est déjà au bord du parcours." end
    local layout = EditLayout(self, contentId, pageId, route)
    layout.order[index], layout.order[target] = layout.order[target], layout.order[index]
    layout.orderModified = true
    RaidLayoutChanged(self, contentId, pageId, true)
    return true
end

function R:RemoveRaidStep(contentId, pageId, stepId)
    local route, problem = EditableRaid(self, contentId, pageId)
    if not route then return false, problem end
    local step = self:GetRaidStep(contentId, pageId, stepId)
    if not step then return false, "Cette étape n'est plus disponible." end
    if #route.steps <= 1 then return false, "Conserve au moins une étape dans le parcours." end
    local layout = EditLayout(self, contentId, pageId, route)
    for index, id in ipairs(layout.order) do if id == step.id then table.remove(layout.order, index); break end end
    layout.orderModified = true
    RaidLayoutChanged(self, contentId, pageId, true)
    return true
end

function R:DuplicateRaidStep(contentId, pageId, stepId, name)
    local route, problem = EditableRaid(self, contentId, pageId)
    if not route then return nil, problem end
    local step = self:GetRaidStep(contentId, pageId, stepId)
    if not step then return nil, "Cette étape n'est plus disponible." end
    local profileId, source = self:GetEffectiveRaidStepProfile(contentId, pageId, step.id)
    if source == "invalid" then return nil, "Vérifie le setup associé avant de copier cette étape." end
    local id, failure = self:AddRaidStep(contentId, pageId, name or "Copie de l'étape", step.kind, step.id)
    if not id then return nil, failure end
    if profileId then
        local copy = self:DuplicateSetup(profileId)
        if copy then self.db.profiles[copy].pageId = pageId; self:AssignContentProfile(contentId, pageId, "stage:" .. id, copy) end
        return id, copy
    end
    return id
end

function R:RestoreRaidRoute(contentId, pageId)
    local route, problem = EditableRaid(self, contentId, pageId)
    if not route then return false, problem end
    Table(Table(self.db.raidLayouts)[pageId])[route.id] = nil
    RaidLayoutChanged(self, contentId, pageId, true)
    return true
end

function R:NormalizeRaidLayouts()
    local db = self.db
    local maxId = 0
    local function CheckId(id)
        local number = type(id) == "string" and tonumber(id:match("^custom:.*:(%d+)$")) or nil
        if number and number < 1000000000 then maxId = math.max(maxId, number) end
    end
    for _, pages in pairs(Table(db.contentAssignments)) do
        for _, slots in pairs(Table(pages)) do
            for key in pairs(Table(slots)) do if type(key) == "string" then CheckId(key:gsub("^stage:", "")) end end
        end
    end
    for _, layouts in pairs(Table(db.raidLayouts)) do
        for _, layout in pairs(Table(layouts)) do
            for id in pairs(Table(Table(layout).extraSteps)) do CheckId(id) end
        end
    end
    local previous = db.nextRaidStepId
    if type(previous) ~= "number" or previous ~= previous or previous <= maxId or previous < 1 or previous > 1000000000 or previous ~= math.floor(previous) then
        db.nextRaidStepId = maxId + 1
    end
    local function Recover(pageId, value)
        db.recoveredRaidLayouts = Table(db.recoveredRaidLayouts)
        db.recoveredRaidLayouts[tostring(pageId)] = DeepCopy(value)
        db.settings.automatic = false
        self.savedDataMessage = "Un parcours personnel a été conservé à part. Vérifie tes pages avant de réactiver l'automatique."
    end
    if db.raidLayouts == nil then db.raidLayouts = {} end
    if type(db.raidLayouts) ~= "table" then Recover("container", db.raidLayouts); db.raidLayouts = {} end
    for pageId, layouts in pairs(db.raidLayouts) do
        local context = Table(db.pageContexts[pageId])
        local valid = db.pages[pageId] ~= nil and type(layouts) == "table" and #self:GetRaidRoutes(context.contentId) > 0
        if valid then
            local routes = {}
            for _, route in ipairs(self:GetRaidRoutes(context.contentId)) do routes[route.id] = route end
            for routeId, layout in pairs(layouts) do
                local route = routes[routeId]
                local readable = route and type(layout) == "table" and layout.contentId == context.contentId
                    and type(layout.order) == "table" and type(layout.extraSteps) == "table" and type(layout.names) == "table"
                    and type(layout.nextId) == "number" and layout.nextId >= 1 and layout.nextId < 1000000000 and layout.nextId == math.floor(layout.nextId)
                    and type(layout.orderModified) == "boolean"
                local known, seen, count = {}, {}, 0
                if readable then
                    for _, step in ipairs(route.steps) do known[step.id] = true end
                    for id, step in pairs(layout.extraSteps) do
                        local prefix = "custom:" .. routeId .. ":"
                        if type(id) ~= "string" or id:sub(1, #prefix) ~= prefix or not id:sub(#prefix + 1):match("^%d+$")
                            or type(step) ~= "table" or step.id ~= id or step.custom ~= true
                            or (step.kind ~= "free" and step.kind ~= "trash" and step.kind ~= "boss") or not PersonalName(step.name)
                            or step.encounterId ~= nil or step.memberIds ~= nil or step.coEncounterIds ~= nil then readable = false; break end
                        known[id] = true
                    end
                    for index, id in pairs(layout.order) do
                        count = count + 1
                        if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > 128 or not known[id] or seen[id] then readable = false; break end
                        seen[id] = true
                    end
                    if count == 0 or count > 128 then readable = false end
                    for index = 1, count do if layout.order[index] == nil then readable = false end end
                    for id, name in pairs(layout.names) do if not known[id] or not PersonalName(name) then readable = false; break end end
                    -- A persisted flag cannot certify a different user-defined order.
                    local sameOrder = count == #route.steps
                    for index, step in ipairs(route.steps) do if layout.order[index] ~= step.id then sameOrder = false end end
                    if not sameOrder then layout.orderModified = true end
                    for _, step in pairs(layout.extraSteps) do if type(step) == "table" then step.victorySafe = false end end
                end
                if not readable then Recover(tostring(pageId) .. ":" .. tostring(routeId), layout); layouts[routeId] = nil end
            end
        else Recover(pageId, layouts); db.raidLayouts[pageId] = nil end
    end
    db.raidLayoutSchema = 1
end

function R:GetContentSlots(value, pageId)
    local content = self:GetContent(value)
    if not content then return {} end
    local slots = {
        { key = "generic", name = "Général", description = "Configuration générale du contenu, hors combat.", available = true },
        { key = "trash", name = "Trash par défaut", description = "Groupes d'ennemis ordinaires ; après une victoire confirmée ou à l'entrée si cette option est activée.", available = true },
        { key = "boss", name = "Boss par défaut", description = "Remplacement pour une rencontre reconnue sans configuration dédiée.", available = true },
    }
    for _, step in ipairs(self:GetRaidSteps(content.id, pageId)) do slots[#slots + 1] = step end
    for _, encounter in ipairs(content.encounters or {}) do
        local name = self:GetContentName(encounter)
        slots[#slots + 1] = { key = "encounter:" .. encounter.id, name = name, description = "Configuration de cette rencontre reconnue.", encounterId = encounter.id, legacy = true, verified = encounter.verified ~= false, available = true }
        slots[#slots + 1] = { key = "after:" .. encounter.id, name = "Trash après « " .. name .. " »", description = "Après une victoire observée ; une disparition ou un wipe ne suffit pas.", encounterId = encounter.id, legacy = true, verified = encounter.verified ~= false, available = true }
        slots[#slots + 1] = { key = "prepare:" .. encounter.id, name = "Préparer « " .. name .. " »", description = "Préparation avant engagement depuis un point personnel enregistré sur place.", encounterId = encounter.id, legacy = true, verified = encounter.preparationVerified == true, available = true }
    end
    return slots
end

local function ValidSlot(self, contentId, key, pageId)
    for _, slot in ipairs(self:GetContentSlots(contentId, pageId)) do if slot.key == key then return true end end
    return false
end

function R:GetAssignedProfile(contentId, pageId, key)
    local context = Table(self.db.pageContexts[pageId])
    if context.contentId ~= contentId or not self.db.pages[pageId] or not ValidSlot(self, contentId, key, pageId) then return nil end
    local id = Table(Table(self.db.contentAssignments[contentId])[pageId])[key]
    return self.db.profiles[id] and id or nil
end

function R:AssignContentProfile(contentId, pageId, key, profileId)
    local context = Table(self.db.pageContexts[pageId])
    if context.contentId ~= contentId or not self.db.pages[pageId] or not ValidSlot(self, contentId, key, pageId)
        or (profileId ~= nil and not self.db.profiles[profileId]) then return false, "Choisis une page, un emplacement et un setup disponibles." end
    local assignments = self.db.contentAssignments
    assignments[contentId] = Table(assignments[contentId]); assignments[contentId][pageId] = Table(assignments[contentId][pageId])
    assignments[contentId][pageId][key] = profileId
    Changed(self)
    return true
end

function R:UnassignContentProfile(contentId, pageId, key) return self:AssignContentProfile(contentId, pageId, key, nil) end

function R:CaptureContentSlot(contentId, pageId, key)
    local context = Table(self.db.pageContexts[pageId])
    if context.contentId ~= contentId or not ValidSlot(self, contentId, key, pageId) then return nil, "Cet emplacement n'est plus disponible." end
    local slotName
    for _, slot in ipairs(self:GetContentSlots(contentId, pageId)) do if slot.key == key then slotName = slot.name end end
    local id = self:SaveNewSetup(slotName and #slotName <= 48 and slotName or nil, pageId)
    if not id then return nil end
    self:AssignContentProfile(contentId, pageId, key, id)
    return id
end

function R:IsInitialTrashEnabled(contentId, pageId)
    return Table(self.db.contentSettings.initialTrash[contentId])[pageId] == true
end

function R:SetInitialTrashEnabled(contentId, pageId, enabled)
    if not self.db.pages[pageId] or Table(self.db.pageContexts[pageId]).contentId ~= contentId or type(enabled) ~= "boolean" then return false end
    local setting = self.db.contentSettings.initialTrash
    setting[contentId] = Table(setting[contentId]); setting[contentId][pageId] = enabled or nil
    Changed(self)
    return true
end

function R:IsDungeonBossObservationEnabled(pageId)
    return Table(self.db.pageContexts[pageId]).contentId == DUNGEONS.id and Table(self.db.contentSettings.dungeonBossObservation)[pageId] == true
end

function R:SetDungeonBossObservationEnabled(pageId, enabled)
    if not self.db.pages[pageId] or Table(self.db.pageContexts[pageId]).contentId ~= DUNGEONS.id or type(enabled) ~= "boolean" then return false end
    self.db.contentSettings.dungeonBossObservation = Table(self.db.contentSettings.dungeonBossObservation)
    self.db.contentSettings.dungeonBossObservation[pageId] = enabled or nil
    Changed(self)
    return true
end

function R:RemoveContentPage(pageId)
    if not self.db.contentSettings then return end
    for _, pages in pairs(self.db.contentAssignments or {}) do if type(pages) == "table" then pages[pageId] = nil end end
    for _, active in pairs(self.db.contentSettings.activePages or {}) do
        if type(active) == "table" then for key, id in pairs(active) do if id == pageId then active[key] = nil end end end
    end
    for _, pages in pairs(self.db.contentSettings.initialTrash or {}) do if type(pages) == "table" then pages[pageId] = nil end end
    Table(self.db.contentSettings.dungeonBossObservation)[pageId] = nil
    Table(self.db.contentSettings.routeSelections)[pageId] = nil
    Table(self.db.raidLayouts)[pageId] = nil
    for _, pages in pairs(Table(self.db.raidRouteMigrations)) do Table(pages)[pageId] = nil end
    if self.InvalidateRaidProgress then self:InvalidateRaidProgress(nil, pageId, "page") end
    if self.db.pageContexts then self.db.pageContexts[pageId] = nil end
end

function R:RemoveContentProfile(id)
    for _, pages in pairs(self.db.contentAssignments or {}) do
        if type(pages) == "table" then for _, slots in pairs(pages) do
            if type(slots) == "table" then for key, value in pairs(slots) do if value == id then slots[key] = nil end end end
        end end
    end
end

function R:DuplicatePage(pageId, name)
    if not self.db.pages[pageId] then return nil end
    local profiles = {}
    for _, id in ipairs(self.db.order) do if self.db.profiles[id].pageId == pageId then profiles[#profiles + 1] = id end end
    local id = self:CreatePage(name or "Copie de la page")
    if not id then return nil end
    self.db.pageContexts[id] = DeepCopy(self.db.pageContexts[pageId] or { contentId = "general", difficulty = "any", role = "any" })
    self.db.contentSettings.routeSelections = Table(self.db.contentSettings.routeSelections)
    self.db.contentSettings.routeSelections[id] = self.db.contentSettings.routeSelections[pageId]
    self.db.raidLayouts = Table(self.db.raidLayouts)
    self.db.raidLayouts[id] = self.db.raidLayouts[pageId] and DeepCopy(self.db.raidLayouts[pageId]) or nil
    local copied = {}
    for _, original in ipairs(profiles) do
        local duplicate = self:DuplicateSetup(original)
        self.db.profiles[duplicate].pageId = id; copied[original] = duplicate
    end
    local contentId = self.db.pageContexts[id].contentId
    local previous = Table(Table(self.db.contentAssignments[contentId])[pageId])
    self.db.contentAssignments[contentId] = Table(self.db.contentAssignments[contentId])
    local slots = {}; self.db.contentAssignments[contentId][id] = slots
    for key, profileId in pairs(previous) do slots[key] = copied[profileId] or profileId end
    self:SetActiveContentPage(contentId, self.db.pageContexts[id].difficulty, id)
    return id
end

function R:MovePage(pageId, delta)
    if delta ~= -1 and delta ~= 1 then return false end
    local context = Table(self.db.pageContexts[pageId]).contentId or "general"
    local index, other
    for i, id in ipairs(self.db.pageOrder) do if id == pageId then index = i; break end end
    if not index then return false end
    local i = index + delta
    while i > 0 and i <= #self.db.pageOrder do
        if (Table(self.db.pageContexts[self.db.pageOrder[i]]).contentId or "general") == context then other = i; break end
        i = i + delta
    end
    if not other then return false end
    self.db.pageOrder[index], self.db.pageOrder[other] = self.db.pageOrder[other], self.db.pageOrder[index]
    Changed(self); return true
end

function R:LearnEncounterAlias(contentId, encounterId, memberId, observedName, expectedZoneId)
    local content, current = self:GetContent(contentId), self:GetCurrentContent()
    if not content or not current or current.id ~= contentId then return false, "Place-toi dans ce contenu avant de reconnaître un boss." end
    if expectedZoneId and self:GetZoneId() ~= expectedZoneId then return false, "La zone a changé. Rouvre la reconnaissance du boss." end
    local encounter, member
    for _, entry in ipairs(content.encounters or {}) do if entry.id == encounterId then encounter = entry end end
    if not encounter then return false, "Cette rencontre n'est plus disponible." end
    for _, entry in ipairs(encounter.members or {}) do if entry.id == memberId then member = entry end end
    if not member and not (memberId == encounterId and #(encounter.members or {}) == 0) then return false, "Choisis le bon boss de la rencontre." end
    local name
    if type(observedName) == "string" and observedName ~= "" and self.GetObservedBossNames then
        local names, problem = self:GetObservedBossNames()
        if not problem then
            for _, live in ipairs(Table(names)) do
                if Normalize(self, live) == Normalize(self, observedName) then name = live; break end
            end
        end
    elseif observedName == nil then name = self.GetTargetBossName and self:GetTargetBossName() end
    if type(name) ~= "string" or name == "" then return false, "Cible un boss vivant reconnu par le jeu, puis réessaie." end
    local existing, existingMember = self:GetEncounterMemberForBoss(contentId, name)
    if existing and (existing.id ~= encounterId or existingMember ~= memberId) then return false, "Ce nom correspond déjà à un autre boss. Vérifie la rencontre choisie." end
    local aliases = self.db.contentSettings.encounterAliases
    aliases[contentId] = Table(aliases[contentId]); aliases[contentId][Language()] = Table(aliases[contentId][Language()])
    aliases[contentId][Language()][Normalize(self, name)] = { encounterId = encounterId, memberId = memberId, name = FormatName(name), source = "observedBoss" }
    Changed(self)
    return true
end

function R:GetLearnedEncounterAliases(contentId, encounterId)
    local result = {}
    for language, aliases in pairs(Table(self.db.contentSettings.encounterAliases[contentId])) do
        for key, data in pairs(Table(aliases)) do
            if type(data) == "table" and (encounterId == nil or data.encounterId == encounterId) then
                result[#result + 1] = { language = language, key = key, name = data.name, encounterId = data.encounterId, memberId = data.memberId }
            end
        end
    end
    table.sort(result, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return result
end

function R:ForgetEncounterAlias(contentId, language, key)
    local aliases = Table(Table(self.db.contentSettings.encounterAliases[contentId])[language])
    if not aliases[key] then return false end
    aliases[key] = nil; Changed(self); return true
end

function R:GetEncounterMemberForBoss(value, bossName)
    local content, normalized = self:GetContent(value), Normalize(self, bossName)
    if not content or normalized == "" then return nil end
    local found, memberId
    local learned = Table(Table(Table(self.db).contentSettings).encounterAliases)
    learned = Table(Table(learned[content.id])[Language()])[normalized]
    if type(learned) == "table" and learned.source == "observedBoss" then
        for _, encounter in ipairs(content.encounters or {}) do
            if encounter.id == learned.encounterId then
                for _, member in ipairs(encounter.members or {}) do
                    if member.id == learned.memberId then found, memberId = encounter, member.id end
                end
                if #(encounter.members or {}) == 0 and learned.memberId == encounter.id then found, memberId = encounter, encounter.id end
            end
        end
    end
    local function Matches(entry)
        for _, names in pairs(Table(entry.aliases)) do
            for _, name in ipairs(Table(names)) do if Normalize(self, name) == normalized then return true end end
        end
        return Normalize(self, entry.name) == normalized or Normalize(self, entry.nameEn) == normalized
    end
    for _, encounter in ipairs(content.encounters or {}) do
        if encounter.verified ~= false then
            local matchedMember
            for _, member in ipairs(encounter.members or {}) do
                if Matches(member) then
                    if found and (found.id ~= encounter.id or memberId ~= member.id) then return nil end
                    found, memberId = encounter, member.id
                    matchedMember = true
                end
            end
            if not matchedMember and Matches(encounter) then
                if found and found.id ~= encounter.id then return nil end
                found, memberId = encounter, encounter.id
            end
        end
    end
    return found, memberId
end

function R:GetEncounterForBoss(content, bossName) return (self:GetEncounterMemberForBoss(content, bossName)) end
