-- Runtime raid checkpoints. Setup verification and encounter victory are separate.
local R = Relais
local function Table(value) return type(value) == "table" and value or {} end
local function Refresh(self) if self.RefreshUI then self:RefreshUI() end end
local function Runtime(self)
    if not self.raidRuntime then self.raidRuntime = { contexts = {}, loads = setmetatable({}, { __mode = "k" }), revision = 0,
        initialTrashBlocked = true, blockedPages = {}, blockedContents = {} } end
    return self.raidRuntime
end
local function Changed(self, progress, cancel)
    local runtime = Runtime(self)
    runtime.revision = runtime.revision + 1
    progress.revision = runtime.revision
    if cancel and self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
    Refresh(self)
end
local function Route(self, contentId, pageId)
    local content = self.GetContent and self:GetContent(contentId)
    if not content or content.category ~= "trials" or not self.GetRaidRoute then return nil end
    local route = self:GetRaidRoute(contentId, pageId)
    return type(route) == "table" and type(route.id) == "string" and route or nil
end
local function Steps(self, contentId, pageId)
    return self.GetRaidSteps and Table(self:GetRaidSteps(contentId, pageId)) or {}
end
local function Step(self, contentId, pageId, id)
    if self.GetRaidStep then return self:GetRaidStep(contentId, pageId, id) end
    for _, step in ipairs(Steps(self, contentId, pageId)) do if step.id == id then return step end end
end
local function NewProgress(route)
    return { routeId = route.id, currentStepId = nil, completed = {}, proofs = {}, needsResume = true,
        completedRun = false, status = "waiting", stepLoads = {}, revision = 0 }
end
function R:GetRaidProgress(contentId, pageId)
    if type(pageId) ~= "number" or pageId < 1 or pageId ~= math.floor(pageId) or not Table(self.db).pages
        or not self.db.pages[pageId] or Table(Table(self.db.pageContexts)[pageId]).contentId ~= contentId then return nil end
    local route = Route(self, contentId, pageId)
    if not route then return nil end
    local runtime = Runtime(self)
    runtime.contexts[contentId] = runtime.contexts[contentId] or {}
    local progress = runtime.contexts[contentId][pageId]
    if not progress or progress.routeId ~= route.id then
        progress = NewProgress(route)
        progress.initialTrashBlocked = runtime.initialTrashBlocked or runtime.blockedPages[pageId] or runtime.blockedContents[contentId] or false
        runtime.contexts[contentId][pageId] = progress
        runtime.revision = runtime.revision + 1
        progress.revision = runtime.revision
    end
    return progress
end
local function ReadyForProgress(self, contentId, observingVictory)
    local current = self.GetCurrentContent and self:GetCurrentContent()
    if not current or current.id ~= contentId then
        return false, "Entre dans ce raid avant de reprendre sa progression."
    end
    if self.automation and not self.automation.worldReady then return false, "Attends la fin du chargement de la zone." end
    if self.bankTransfer or (self.IsSavingSetup and self:IsSavingSetup()) then return false, "Attends la fin de l’action en cours." end
    if not observingVictory and self.engine and self.engine.IsBusy then
        local ok, busy = pcall(self.engine.IsBusy, self.engine)
        if not ok or busy ~= false then return false, "Attends la fin du changement de setup." end
    end
    if type(IsUnitInCombat) ~= "function" or type(IsUnitDeadOrReincarnating) ~= "function" then return false, "Le personnage n’est pas encore prêt." end
    for _, check in ipairs({ IsUnitInCombat, IsUnitDeadOrReincarnating }) do
        local ok, active = pcall(check, "player")
        if not ok or type(active) ~= "boolean" then return false, "Le personnage n’est pas encore prêt." end
        if active then return false, "Reprends la progression après le combat et la résurrection." end
    end
    if type(GetGroupSize) ~= "function" or type(GetGroupUnitTagByIndex) ~= "function" then return false, "Informations du groupe en attente." end
    if type(GetGroupSize) == "function" then
        local ok, size = pcall(GetGroupSize)
        if not ok or type(size) ~= "number" or size < 0 or size > 24 or size ~= math.floor(size) then return false, "Informations du groupe en attente." end
        for index = 1, size do
            local tagOK, tag = pcall(GetGroupUnitTagByIndex, index)
            local combatOK, fighting = false, nil
            if tagOK and type(tag) == "string" and tag ~= "" then combatOK, fighting = pcall(IsUnitInCombat, tag) end
            if not combatOK or type(fighting) ~= "boolean" then return false, "Informations du groupe en attente." end
            if fighting then return false, "Le groupe est encore en combat." end
        end
    end
    return true
end
function R:SelectRaidStep(contentId, pageId, stepId)
    local progress, step = self:GetRaidProgress(contentId, pageId), Step(self, contentId, pageId, stepId)
    if not progress or not step then return false, "Cette étape du parcours n’est plus disponible." end
    local ready, problem = ReadyForProgress(self, contentId)
    if not ready then return false, problem end
    progress.currentStepId, progress.needsResume, progress.completedRun = step.id, false, false
    progress.status, progress.awaitingEvidence, progress.attempt = "selected", false, nil
    progress.recognizedStepId = nil
    Changed(self, progress, true)
    if self.SuppressAutomationForContext then self:SuppressAutomationForContext() end
    return true
end
function R:ResetRaidProgress(contentId, pageId)
    local ready, problem = ReadyForProgress(self, contentId)
    if not ready then return false, problem end
    local route = Route(self, contentId, pageId)
    if not route then return false, "Ce parcours n’est plus disponible." end
    local progress = NewProgress(route)
    Runtime(self).contexts[contentId] = Runtime(self).contexts[contentId] or {}
    Runtime(self).contexts[contentId][pageId] = progress
    local first = Steps(self, contentId, pageId)[1]
    if first then progress.currentStepId, progress.needsResume = first.id, false; progress.awaitingEvidence = first.kind == "boss" end
    progress.status = progress.awaitingEvidence and "waiting" or "selected"
    Changed(self, progress, true)
    if self.SuppressAutomationForContext then self:SuppressAutomationForContext() end
    return true
end
function R:InvalidateRaidProgress(contentId, pageId, reason)
    local runtime = Runtime(self)
    if contentId == nil and pageId == nil then
        runtime.initialTrashBlocked = reason ~= "zone"
        runtime.blockedPages, runtime.blockedContents = {}, {}
    elseif pageId ~= nil then runtime.blockedPages[pageId] = true
    elseif contentId ~= nil then runtime.blockedContents[contentId] = true end
    if contentId == nil and pageId ~= nil then
        for _, pages in pairs(runtime.contexts) do pages[pageId] = nil end
    elseif contentId == nil then runtime.contexts = {}; runtime.loads = setmetatable({}, { __mode = "k" }); runtime.currentLoad = nil
    elseif runtime.contexts[contentId] then
        if pageId then runtime.contexts[contentId][pageId] = nil else runtime.contexts[contentId] = nil end
    end
    runtime.revision = runtime.revision + 1
    if self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
    Refresh(self)
end
local function StringSet(list)
    if type(list) ~= "table" then return nil end
    local set, count = {}, 0
    for key, id in pairs(list) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) or key > 64 or type(id) ~= "string" or id == "" or set[id] then return nil end
        set[id], count = true, count + 1
    end
    for index = 1, count do if list[index] == nil then return nil end end
    return set, count
end
local function AllowedMembers(expected, observed)
    -- Variant actors may arrive during later phases. The route is chosen
    -- explicitly; absence does not identify another +n variant or a victory.
    for id in pairs(observed) do if not expected[id] then return false end end
    return true
end
function R:GetObservedRaidStep(contentId, pageId, bossSlots)
    local content, progress = self.GetContent and self:GetContent(contentId), self:GetRaidProgress(contentId, pageId)
    if not content or not progress then return nil end
    local members, encounters, present = {}, {}, false
    for _, observation in pairs(Table(bossSlots)) do
        if observation.dead == false then
            present = true
            local encounter, memberId = self:GetEncounterMemberForBoss(content, observation.key)
            if not encounter or type(encounter.id) ~= "string" or type(memberId) ~= "string" then return nil, "Boss non identifié dans ce parcours. Choisis l’étape manuellement." end
            members[memberId], encounters[encounter.id] = true, true
        end
    end
    if not present then return nil end
    local found
    for _, step in ipairs(Steps(self, contentId, pageId)) do
        if step.kind == "boss" and step.manualOnly ~= true and type(step.encounterId) == "string" then
            local allowed = { [step.encounterId] = true }
            local co = step.coEncounterIds and StringSet(step.coEncounterIds)
            if co then for id in pairs(co) do allowed[id] = true end end
            local matches = encounters[step.encounterId] == true and (step.coEncounterIds == nil or co ~= nil)
            for id in pairs(encounters) do if not allowed[id] then matches = false end end
            if step.memberIds then
                local expected, count = StringSet(step.memberIds)
                matches = matches and expected ~= nil and count > 0 and AllowedMembers(expected, members)
            end
            if matches then
                if found then return nil, "Plusieurs étapes correspondent aux boss visibles. Choisis l’étape manuellement." end
                found = step
            end
        end
    end
    return found, not found and "La variante du boss n’est pas confirmée. Choisis l’étape manuellement." or nil
end
function R:ObserveRaidEncounter(contentId, pageId, encounterId, observedStepId)
    local progress = self:GetRaidProgress(contentId, pageId)
    if not progress then return nil end
    local step = observedStepId and Step(self, contentId, pageId, observedStepId) or nil
    if not step then
        for _, candidate in ipairs(Steps(self, contentId, pageId)) do
            if candidate.kind == "boss" and candidate.encounterId == encounterId and not candidate.memberIds then
                if step then return nil end
                step = candidate
            end
        end
    end
    if not step or step.kind ~= "boss" or step.encounterId ~= encounterId then return nil end
    if progress.completed[step.id] then
        if progress.completedRun then progress.completed, progress.proofs = {}, {}
        else progress.completed[step.id], progress.proofs[step.id] = nil, nil end
        progress.completedRun = false
    end
    if progress.currentStepId ~= step.id or progress.needsResume or progress.awaitingEvidence then
        progress.currentStepId, progress.needsResume, progress.completedRun = step.id, false, false
        progress.awaitingEvidence, progress.status, progress.recognizedStepId = false, "recognized", step.id
        progress.attempt = nil
        Changed(self, progress, true)
    else progress.recognizedStepId = step.id end
    if not progress.attempt then progress.attempt = { contentId = contentId, pageId = pageId, routeId = progress.routeId, stepId = step.id, encounterId = encounterId } end
    return progress.attempt
end
function R:AbortRaidEncounter(contentId, pageId, token)
    local progress = self:GetRaidProgress(contentId, pageId)
    if not progress or (token and progress.attempt ~= token) then return end
    progress.attempt, progress.recognizedStepId = nil, nil
    progress.status = "retry"
    Refresh(self)
end
function R:ConfirmRaidEncounterVictory(contentId, pageId, encounterId, token, nativeProof)
    local progress, route = self:GetRaidProgress(contentId, pageId), Route(self, contentId, pageId)
    if not progress or not route or token == nil or token ~= progress.attempt or token.encounterId ~= encounterId
        or token.routeId ~= route.id or token.contentId ~= contentId or token.pageId ~= pageId then return false end
    local step = Step(self, contentId, pageId, token.stepId)
    if not step or step.kind ~= "boss" or step.encounterId ~= encounterId or step.victorySafe == false then return false end
    if not ReadyForProgress(self, contentId, true) then return false end
    -- Recognition tokens never constitute a victory. Only Automation supplies
    -- this evidence after its complete native member-death verification.
    if type(nativeProof) ~= "table" or nativeProof.catalogComplete ~= true or nativeProof.failed or nativeProof.catalogFailed
        or type(nativeProof.catalog) ~= "table" or nativeProof.catalog.id ~= encounterId or nativeProof.catalog.groupVerified ~= true
        or nativeProof.raidToken ~= token or type(nativeProof.slots) ~= "table" or type(nativeProof.killedSlots) ~= "table"
        or type(nativeProof.slotMembers) ~= "table" then return false end
    local required, requiredCount = StringSet(nativeProof.catalog.requiredMembers)
    -- Older verified fixtures used member objects; actual route data uses IDs.
    if not required then
        local ids = {}
        for index, member in pairs(Table(nativeProof.catalog.requiredMembers)) do ids[index] = type(member) == "table" and member.id or member end
        required, requiredCount = StringSet(ids)
    end
    if not required or requiredCount == 0 then return false end
    local content, canonical = self:GetContent(contentId), nil
    for _, candidate in ipairs(Table(content).encounters or {}) do if candidate.id == encounterId then canonical = candidate break end end
    if canonical ~= nativeProof.catalog then return false end
    local knownIds = {}
    for index, member in pairs(Table(canonical.members)) do knownIds[index] = type(member) == "table" and member.id or nil end
    local known, knownCount = StringSet(knownIds)
    if not known or knownCount ~= requiredCount then return false end
    for memberId in pairs(known) do if not required[memberId] then return false end end
    local killed, liveCount = {}, 0
    for slot in pairs(nativeProof.slots) do
        if nativeProof.killedSlots[slot] ~= true then return false end
        local memberId = nativeProof.slotMembers[slot]
        if type(memberId) ~= "string" or not required[memberId] then return false end
        killed[memberId], liveCount = true, liveCount + 1
    end
    if liveCount == 0 then return false end
    for memberId in pairs(required) do if not killed[memberId] then return false end end
    progress.completed[step.id] = true
    progress.proofs[step.id] = { encounterId = encounterId, source = "observedMemberDeaths" }
    progress.attempt, progress.recognizedStepId = nil, nil
    local steps, nextStep = Steps(self, contentId, pageId), nil
    for index, entry in ipairs(steps) do if entry.id == step.id then nextStep = steps[index + 1] break end end
    if route.orderVerified ~= true then
        progress.currentStepId, progress.needsResume, progress.status, progress.awaitingEvidence = nil, true, "waiting", true
    elseif not nextStep then
        progress.completedRun, progress.status, progress.awaitingEvidence = true, "finished", false
    else
        progress.currentStepId, progress.status, progress.awaitingEvidence = nextStep.id, nextStep.kind == "trash" and "selected" or "waiting", nextStep.kind ~= "trash"
    end
    Changed(self, progress, true)
    return true
end
function R:ResolveRaidProgressSetup(contentId, pageId)
    local progress = self:GetRaidProgress(contentId, pageId)
    if not progress then return nil end
    if progress.completedRun then return nil, nil, "Parcours terminé. Aucun passage suivant n’est déduit." end
    if progress.needsResume then return nil, nil, "Choisis l’étape actuelle pour reprendre ce raid." end
    if progress.awaitingEvidence then return nil, nil, "Prochain boss en attente de reconnaissance ou de reprise manuelle." end
    local step = Step(self, contentId, pageId, progress.currentStepId)
    if not step then return nil, nil, "L’étape actuelle n’est plus disponible. Choisis une reprise." end
    if step.kind == "free" or step.kind == "manual" then return nil, step, "Cette étape libre se charge manuellement." end
    local id, source = self:GetEffectiveRaidStepProfile(contentId, pageId, step.id)
    if not id then return nil, step, "Associe un setup à cette étape ou à son remplacement " .. (step.kind == "trash" and "Trash" or "Boss") .. "." end
    return id, step, nil, source
end

function R:StartRaidInitialTrash(contentId, pageId)
    local progress = self:GetRaidProgress(contentId, pageId)
    local route = Route(self, contentId, pageId)
    local first = Steps(self, contentId, pageId)[1]
    if not progress or progress.initialTrashBlocked or not route or route.orderVerified ~= true or not progress.needsResume or not first or first.kind ~= "trash" then return false end
    if next(progress.completed) ~= nil then return false end
    progress.currentStepId, progress.needsResume, progress.status, progress.awaitingEvidence = first.id, false, "selected", false
    Changed(self, progress, true)
    return true
end

function R:ObserveRaidPreparation(contentId, pageId, stepId, routeId)
    local progress, step = self:GetRaidProgress(contentId, pageId), Step(self, contentId, pageId, stepId)
    if not progress or not step or step.kind ~= "boss" or progress.routeId ~= routeId or progress.completed[step.id] or progress.completedRun then return false end
    if progress.currentStepId ~= step.id or progress.needsResume or progress.awaitingEvidence then
        progress.currentStepId, progress.needsResume, progress.awaitingEvidence = step.id, false, false
        progress.status, progress.recognizedStepId, progress.attempt = "selected", nil, nil
        Changed(self, progress, true)
    end
    return true
end
function R:RegisterRaidSetupRequest(contentId, pageId, stepId, profileId)
    local progress, engine = self:GetRaidProgress(contentId, pageId), self.engine
    local request = engine and engine.pending
    local step = Step(self, contentId, pageId, stepId)
    if not progress or not step or not request or request.id ~= profileId or type(request.components) ~= "table" then return false end
    if self:GetEffectiveRaidStepProfile(contentId, pageId, step.id) ~= profileId then return false end
    local load = { contentId = contentId, pageId = pageId, stepId = step.id, profileId = profileId,
        routeId = progress.routeId, progress = progress, request = request, state = "pending" }
    Runtime(self).loads[request.components] = load
    progress.stepLoads[step.id] = load
    return true
end
function R:LoadRaidStep(contentId, pageId, stepId, components)
    local step, progress = Step(self, contentId, pageId, stepId), self:GetRaidProgress(contentId, pageId)
    if not step or not progress then return false, "Cette étape n’est plus disponible." end
    if self.bankTransfer or (self.IsSavingSetup and self:IsSavingSetup()) then return false, "Attends la fin de l’action en cours." end
    if self.automation and not self.automation.worldReady then return false, "Attends la fin du chargement." end
    if type(IsUnitInCombat) ~= "function" or type(IsUnitDeadOrReincarnating) ~= "function" then return false, "Le personnage n’est pas encore prêt." end
    local combatOK, combat = pcall(IsUnitInCombat, "player")
    local deadOK, dead = pcall(IsUnitDeadOrReincarnating, "player")
    if not combatOK or not deadOK or combat ~= false or dead ~= false then return false, "Charge ce setup après le combat et la résurrection." end
    local id = self:GetEffectiveRaidStepProfile(contentId, pageId, stepId)
    if not id then return false, "Associe d’abord un setup à cette étape ou à son remplacement." end
    local ok, problem = self:EquipSetup(id, "Manuel — étape : " .. (step.name or "raid"), false, components)
    if ok then self:RegisterRaidSetupRequest(contentId, pageId, stepId, id); Refresh(self) end
    return ok == true, problem
end
function R:OnRaidEngineState(state, message, id, components)
    local runtime, load = Runtime(self), components and Runtime(self).loads[components]
    if state == "applying" or state == "success" or state == "error" then
        local current = runtime.currentLoad
        if current then
            current.state = "historical"
            current.progress.loadedStepId, current.progress.loadedProfileId, current.progress.loadedPartial = nil, nil, nil
            runtime.currentLoad = nil
        end
    end
    if state == "error" or state == "cancelled" then
        local engine = self.engine
        for _, candidate in pairs(runtime.loads) do
            if candidate.profileId == id and candidate.state == "pending" and (not engine or (engine.active ~= candidate.request and engine.pending ~= candidate.request)) then
                candidate.state = "failed"
            end
        end
        if load and engine and engine.pending == load.request and engine.active ~= load.request then return end
    end
    if not load or load.profileId ~= id then return end
    local progress = self:GetRaidProgress(load.contentId, load.pageId)
    if progress ~= load.progress or progress.routeId ~= load.routeId or progress.stepLoads[load.stepId] ~= load then return end
    if state == "success" then
        load.state, load.partial = "loaded", not (components.gear and components.skills and components.champion)
        progress.loadedStepId, progress.loadedProfileId, progress.loadedPartial = load.stepId, id, load.partial
        runtime.currentLoad = load
    elseif state == "error" or state == "cancelled" then load.state = "failed"
    elseif state == "pending" or state == "applying" or state == "waiting" then load.state = "pending" end
end
function R:GetRaidStepStatus(contentId, pageId, stepId)
    local progress, step = self:GetRaidProgress(contentId, pageId), Step(self, contentId, pageId, stepId)
    if not progress or not step then return "inactive", "Étape indisponible", {} end
    local load = progress.stepLoads[step.id]
    if load and load.state == "pending" and self.engine and self.engine.pending ~= load.request and self.engine.active ~= load.request then load.state = "failed" end
    local effective = self:GetEffectiveRaidStepProfile(contentId, pageId, step.id)
    if load and load.profileId ~= effective then load = nil end
    local details = { victoryVerified = progress.completed[step.id] == true, loaded = load and load.state == "loaded" or false,
        partial = load and load.state == "loaded" and load.partial == true or false, pending = load and load.state == "pending" or false,
        failed = load and load.state == "failed" or false, recognized = progress.recognizedStepId == step.id, selected = progress.currentStepId == step.id }
    if details.victoryVerified then return "completed", "Victoire confirmée", details end
    if details.pending then return "pending", "Chargement en attente de confirmation", details end
    if details.failed then return "failed", "Chargement interrompu ou non confirmé", details end
    if details.loaded then return details.partial and "partial" or "loaded", details.partial and "Composants choisis chargés et vérifiés" or "Setup chargé et vérifié", details end
    if details.recognized then return "recognized", "Boss reconnu ; victoire non confirmée", details end
    if details.selected then return progress.awaitingEvidence and "waiting" or "selected", progress.awaitingEvidence and "En attente du boss ou d’une reprise manuelle" or "Étape choisie ; setup non confirmé", details end
    return "inactive", "Étape disponible", details
end
