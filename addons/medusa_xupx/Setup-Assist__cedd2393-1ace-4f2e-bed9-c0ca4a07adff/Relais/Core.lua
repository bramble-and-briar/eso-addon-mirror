-- Setup Assist: gestion des setups à la manette.
Relais = { name = "Relais", displayName = "Setup Assist", version = "0.4.0-beta", lastState = "idle" }
local R = Relais

function R:Notify(message)
    message = self.displayName .. " : " .. (type(message) == "string" and message or "Action indisponible. Réessaie dans un instant.")
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, message) end
end

function R:GetStatusText()
    local text = self.statusMessage or "Prêt."
    if self.statusProfileId and self.db then
        local profile = self.db.profiles[self.statusProfileId]
        if profile then text = profile.name .. " — " .. text end
    end
    if self.automationMessage then text = text .. "\n" .. self.automationMessage end
    if self.savedDataMessage then text = text .. "\n" .. self.savedDataMessage end
    return text
end

local function CleanName(name, fallback, maxCharacters)
    local result = (type(name) == "string" and name or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("[%c]", "")
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    if result == "" then return fallback end
    local _, characters = result:gsub("[^\128-\191]", "")
    maxCharacters = maxCharacters or 48
    if characters > maxCharacters or #result > maxCharacters * 4 then return nil end
    return result
end

local function ValidId(id)
    return type(id) == "number" and id > 0 and id <= 1000000000 and id == math.floor(id)
end

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
    return result
end

function R:RequestSavedVariablesSave()
    -- This is a deferred priority request, never an acknowledgement of disk writes.
    local requested = false
    if type(GetAddOnManager) == "function" then
        local ok, manager = pcall(GetAddOnManager)
        if ok and manager and type(manager.RequestAddOnSavedVariablesPrioritySave) == "function" then
            requested = pcall(manager.RequestAddOnSavedVariablesPrioritySave, manager, self.name)
        end
    end
    if AUTO_SAVING and type(AUTO_SAVING.MarkDirty) == "function" then pcall(AUTO_SAVING.MarkDirty, AUTO_SAVING) end
    self.savePriorityPending = not requested
    return requested
end

function R:SavedDataChanged()
    if not self.db then return end
    local previous = self.db.revision
    if type(previous) ~= "number" or previous ~= previous or previous < 0 or previous > 1000000000000 then previous = 0 end
    self.db.revision = previous + 1
    self:RequestSavedVariablesSave()
end

function R:GetPageIds()
    local ids = {}
    for _, id in ipairs(self.db.pageOrder or { 1 }) do
        if self.db.pages and type(self.db.pages[id]) == "string" then ids[#ids + 1] = id end
    end
    return ids
end

function R:GetPageName(id)
    return self.db.pages and self.db.pages[id] or "Mes setups"
end

function R:CreatePage(name)
    local clean = CleanName(name, "Nouvelle page")
    if not clean then self:Notify("Le nom est trop long."); return nil end
    if #self:GetPageIds() >= 512 then self:Notify("Limite de 512 pages atteinte."); return nil end
    local id = self.db.nextPageId or 2
    self.db.nextPageId = id + 1
    self.db.pages[id] = clean
    table.insert(self.db.pageOrder, id)
    self:SavedDataChanged()
    self:RefreshUI()
    return id
end

function R:RenamePage(id, name)
    if not self.db.pages or not self.db.pages[id] then return false end
    local clean = CleanName(name, self.db.pages[id])
    if not clean then self:Notify("Le nom est trop long."); return false end
    self.db.pages[id] = clean
    self:SavedDataChanged()
    self:RefreshUI()
    return true
end

function R:DeletePage(id)
    if id == 1 or not self.db.pages or not self.db.pages[id] then return false end
    for _, profile in pairs(self.db.profiles) do if profile.pageId == id then profile.pageId = 1 end end
    self.db.pages[id] = nil
    if self.RemoveContentPage then self:RemoveContentPage(id) end
    for i = #self.db.pageOrder, 1, -1 do if self.db.pageOrder[i] == id then table.remove(self.db.pageOrder, i) end end
    self:SavedDataChanged()
    self:RefreshUI()
    return true
end

function R:MoveSetupToPage(id, pageId)
    local profile = self.db.profiles[id]
    if not profile or not self.db.pages or not self.db.pages[pageId] then return false end
    profile.pageId = pageId
    self:SavedDataChanged()
    self:RefreshUI()
    return true
end

function R:MoveSetup(id, delta)
    if delta ~= -1 and delta ~= 1 then return false end
    local profile = self.db.profiles[id]
    if not profile then return false end
    local index, other
    for i, savedId in ipairs(self.db.order) do if savedId == id then index = i; break end end
    if not index then return false end
    local i = index + delta
    while i > 0 and i <= #self.db.order do
        local candidate = self.db.profiles[self.db.order[i]]
        if candidate and (candidate.pageId or 1) == (profile.pageId or 1) then other = i; break end
        i = i + delta
    end
    if not other then return false end
    self.db.order[index], self.db.order[other] = self.db.order[other], self.db.order[index]
    self:SavedDataChanged()
    self:RefreshUI()
    return true
end

function R:DuplicateSetup(id)
    local profile = self.db.profiles[id]
    if not profile then return nil end
    local nextId, duplicate = self.db.nextId, Copy(profile)
    -- Long legacy names must not prevent duplication.
    duplicate.name = CleanName(profile.name .. " (copie)", "Copie du setup " .. tostring(id)) or ("Copie du setup " .. tostring(id))
    duplicate.savedAt = GetTimeStamp()
    self.db.nextId = nextId + 1
    self.db.profiles[nextId] = duplicate
    local insertAt = #self.db.order + 1
    for i, savedId in ipairs(self.db.order) do if savedId == id then insertAt = i + 1; break end end
    table.insert(self.db.order, insertAt, nextId)
    -- Automatic associations remain with the original setup.
    self:SavedDataChanged()
    self:RefreshUI()
    return nextId
end

function R:NormalizeSavedData()
    local db, repaired = self.db, false
    if type(db.profiles) ~= "table" then
        db.recoveredProfiles = db.profiles
        db.profiles = {}
        repaired = true
    end
    local invalid, ids, maximum = {}, {}, 0
    for id, profile in pairs(db.profiles) do
        if ValidId(id) and type(profile) == "table" then
            -- Preserve the longer names accepted by previous releases.
            profile.name = CleanName(profile.name, "Setup " .. tostring(id), 160) or ("Setup " .. tostring(id))
            ids[#ids + 1] = id
            maximum = math.max(maximum, id)
        else
            invalid[id] = profile
        end
    end
    for id, profile in pairs(invalid) do
        if type(db.recoveredProfiles) ~= "table" then db.recoveredProfiles = {} end
        db.recoveredProfiles[id] = profile
        db.profiles[id] = nil
        repaired = true
    end
    table.sort(ids)
    local order, seen = {}, {}
    if type(db.order) == "table" then
        for _, id in ipairs(db.order) do
            if db.profiles[id] and not seen[id] then
                order[#order + 1], seen[id] = id, true
            else
                repaired = true
            end
        end
    else
        repaired = true
    end
    for _, id in ipairs(ids) do
        if not seen[id] then order[#order + 1] = id; repaired = true end
    end
    db.order = order
    if not ValidId(db.nextId) or db.nextId <= maximum then db.nextId = maximum + 1 end
    if type(db.settings) ~= "table" then
        db.recoveredSettings = db.settings
        db.settings = { automatic = false }
        repaired = true
    end
    db.settings.automatic = db.settings.automatic == true and not repaired
    local log = {}
    if type(db.log) == "table" then
        for _, entry in ipairs(db.log) do
            if type(entry) == "table" and type(entry.message) == "string"
                and (entry.state == "success" or entry.state == "error" or entry.state == "cancelled")
                and not entry.message:find("%.lua:%d+") and not entry.message:find("stack traceback", 1, true) then
                log[#log + 1] = entry
            end
        end
    end
    while #log > 25 do table.remove(log, 1) end
    db.log = log
    local pages, pageOrder, pageSeen, pageIds, maxPage = {}, {}, {}, {}, 1
    if type(db.pages) == "table" then
        for id, name in pairs(db.pages) do
            if ValidId(id) and type(name) == "string" then
                pages[id] = CleanName(name, "Page " .. tostring(id), 160) or ("Page " .. tostring(id))
                maxPage = math.max(maxPage, id)
            end
        end
    end
    pages[1] = pages[1] or "Mes setups"
    for _, profile in pairs(db.profiles) do
        if not ValidId(profile.pageId) then profile.pageId = 1 end
        if not pages[profile.pageId] then
            pages[profile.pageId] = "Page " .. tostring(profile.pageId)
            maxPage = math.max(maxPage, profile.pageId)
        end
    end
    if type(db.pageOrder) == "table" then
        for _, id in ipairs(db.pageOrder) do
            if pages[id] and not pageSeen[id] then pageOrder[#pageOrder + 1], pageSeen[id] = id, true end
        end
    end
    for id in pairs(pages) do if not pageSeen[id] then pageIds[#pageIds + 1] = id end end
    table.sort(pageIds)
    for _, id in ipairs(pageIds) do pageOrder[#pageOrder + 1] = id end
    db.pages, db.pageOrder = pages, pageOrder
    if not ValidId(db.nextPageId) or db.nextPageId <= maxPage then db.nextPageId = maxPage + 1 end
    if self.NormalizeContentData then self:NormalizeContentData() else db.schema = 2 end
    if repaired then self.savedDataMessage = "Sauvegardes réorganisées. Vérifie tes setups avant de réactiver les changements automatiques." end
    self:SavedDataChanged()
end

function R:CaptureProfile(name)
    local function Refuse(message)
        self.statusMessage = type(message) == "string" and message or "Impossible d'enregistrer le setup. Réessaie hors combat après le chargement."
        self.statusProfileId = nil
        self:Notify(self.statusMessage)
        self:RefreshUI()
        return nil
    end
    if self.engine:IsBusy() or self.bankTransfer then
        return Refuse("Attends la fin du changement avant de sauvegarder.")
    end
    local ok, profile, problem = pcall(self.adapter.Capture, self.adapter)
    if not ok or type(profile) ~= "table" then
        return Refuse(ok and problem or nil)
    end
    profile.name = name
    profile.savedAt = GetTimeStamp()
    return profile
end

function R:SaveNewSetup(name, pageId)
    local id = self.db.nextId
    local clean = CleanName(name, "Setup " .. tostring(id))
    if not clean then self:Notify("Le nom est trop long."); return end
    local profile = self:CaptureProfile(clean)
    if not profile then return end
    profile.pageId = self.db.pages and self.db.pages[pageId or 1] and (pageId or 1) or 1
    self.db.nextId = id + 1
    self.db.profiles[id] = profile
    table.insert(self.db.order, id)
    self.statusMessage, self.statusProfileId = "Setup enregistré.", id
    self:SavedDataChanged()
    self:Notify(clean .. " enregistré pour ce personnage.")
    self:RefreshUI()
    return id
end

function R:UpdateSetup(id)
    local original = self.db.profiles[id]
    if not original then return end
    local profile = self:CaptureProfile(original.name)
    if not profile then return end
    profile.pageId = original.pageId or 1
    self.db.profiles[id] = profile
    self.statusMessage, self.statusProfileId = "Setup mis à jour.", id
    self:SavedDataChanged()
    self:Notify(profile.name .. " mis à jour.")
    self:RefreshUI()
    return true
end

function R:RenameSetup(id, name)
    local profile = self.db.profiles[id]
    if not profile then return end
    local clean = CleanName(name, profile.name)
    if not clean then self:Notify("Le nom est trop long."); return end
    profile.name = clean
    self:SavedDataChanged()
    self:RefreshUI()
    return true
end

function R:DeleteSetup(id)
    local profile = self.db.profiles[id]
    if not profile then return end
    if self.bankTransfer and self.bankTransfer.id == id then self:CancelBankTransfer() end
    if self.engine.CancelProfile then self.engine:CancelProfile(id)
    elseif (self.engine.pending and self.engine.pending.id == id) or (self.engine.active and self.engine.active.id == id) then self.engine:Cancel() end
    self.db.profiles[id] = nil
    if self.RemoveContentProfile then self:RemoveContentProfile(id) end
    for i = #self.db.order, 1, -1 do
        if self.db.order[i] == id then table.remove(self.db.order, i) end
    end
    for zone, savedId in pairs(self.db.rules.zones) do
        if savedId == id then self.db.rules.zones[zone] = nil end
    end
    for _, rules in pairs(self.db.rules.bosses) do
        for boss, savedId in pairs(rules) do
            if savedId == id then rules[boss] = nil end
        end
    end
    for i = #self.db.rules.positions, 1, -1 do
        if type(self.db.rules.positions[i]) == "table" and not self.db.rules.positions[i].contentId and self.db.rules.positions[i].profileId == id then
            table.remove(self.db.rules.positions, i)
        end
    end
    for _, rules in pairs(self.db.rules.trashAfterBosses or {}) do
        for boss, savedId in pairs(rules) do if savedId == id then rules[boss] = nil end end
    end
    if self.activeProfileId == id then self.activeProfileId = nil end
    if self.statusProfileId == id then self.statusProfileId = nil end
    self:SavedDataChanged()
    self:Notify(profile.name .. " supprimé.")
    self:RefreshUI()
end

function R:EquipSetup(id, reason, automatic, components)
    local profile = self.db.profiles[id]
    if not profile then self:Notify("Ce setup n'existe plus."); return false end
    if self.bankTransfer then self:Notify("Attends la fin du transfert bancaire."); return false end
    if not automatic and self.SuppressAutomationForContext then
        self:SuppressAutomationForContext()
    end
    self.requestedProfileId = id
    return self.engine:Request(profile, id, reason or "manuel", automatic, components)
end

function R:CancelRequest()
    if self.bankTransfer then self:CancelBankTransfer(); return end
    self.engine:Cancel()
    if self.SuppressAutomationForContext then self:SuppressAutomationForContext() end
    self:Notify("Arrêt demandé. Les étapes déjà terminées restent appliquées.")
end

function R:CancelAutomaticSwap()
    if not self.engine then return end
    local pending = self.engine.pending
    local preservePending = pending and pending.automatic and self:IsAutomaticRequestCurrent(pending.id)
    self.engine:CancelAutomatic(preservePending == true)
end

function R:TickEngine()
    local engine = self.engine
    local request = engine.pending or engine.active
    if request and request.automatic and not self:IsAutomaticRequestCurrent(request.id) then
        self:CancelAutomaticSwap()
    elseif engine.active and engine.active.automatic and not self:IsAutomaticRequestCurrent(engine.active.id) then
        self:CancelAutomaticSwap()
    end
    engine:Tick()
end

function R:OnEngineState(state, message, id, components)
    self.lastState, self.statusMessage = state, message
    self.statusProfileId = id
    if state == "applying" or state == "error" then self.activeProfileId = nil end
    if state == "success" then
        local complete = components == nil or (components.gear == true and components.skills == true and components.champion == true)
        self.activeProfileId = complete and id or nil
    end
    if state == "success" or state == "error" or state == "cancelled" then
        self.db.log = self.db.log or {}
        local profile = self.db.profiles[id]
        table.insert(self.db.log, { time = GetTimeStamp(), state = state, message = message, profileId = id, profileName = profile and profile.name })
        while #self.db.log > 25 do table.remove(self.db.log, 1) end
        self:SavedDataChanged()
        if state ~= "cancelled" then self:Notify(profile and (profile.name .. " : " .. message) or message) end
    end
    if self.OnRaidEngineState then self:OnRaidEngineState(state, message, id, components) end
    self:RefreshUI()
end
