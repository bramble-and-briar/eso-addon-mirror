local Engine = {}
Engine.__index = Engine

local SETTLE_MS = 300
local RETRY_MS = 700
local TIMEOUT_MS = 8000
local MAX_ATTEMPTS = 3

local function Copy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Copy(key, seen)] = Copy(child, seen)
    end
    return result
end

local function Call(engine, name, ...)
    local method = engine.adapter[name]
    if type(method) ~= "function" then
        return false
    end
    return pcall(method, engine.adapter, ...)
end

function Engine.New(adapter, notify)
    return setmetatable({
        adapter = adapter,
        notify = notify,
        state = "idle",
        pending = nil,
        active = nil,
        pausedAt = nil,
    }, Engine)
end

local function Components(value)
    if value == nil then return { gear = true, skills = true, champion = true } end
    if type(value) ~= "table" then return nil end
    local result = {}
    for key, enabled in pairs(value) do
        if (key ~= "gear" and key ~= "skills" and key ~= "champion") or type(enabled) ~= "boolean" then return nil end
    end
    for _, key in ipairs({ "gear", "skills", "champion" }) do result[key] = value[key] == true end
    if not result.gear and not result.skills and not result.champion then return nil end
    return result
end

function Engine:Emit(state, message, id, components)
    if not components then
        local request = self.pending and self.pending.id == id and self.pending or self.active and self.active.id == id and self.active
        components = request and request.components
    end
    self.state = state
    if self.lastState == state and self.lastMessage == message and self.lastId == id and self.lastComponents == components then
        return
    end
    self.lastState, self.lastMessage, self.lastId, self.lastComponents = state, message, id, components
    if type(self.notify) == "function" then
        pcall(self.notify, state, message, id, components)
    end
end

function Engine:Request(profile, id, reason, automatic, components)
    if type(profile) ~= "table" then
        self:Emit("error", "Setup invalide.", id)
        return false, "Setup invalide."
    end
    local snapshot = Copy(profile)
    local selected = Components(components)
    if not selected then
        local problem = "Choisis l'équipement, les compétences ou les étoiles Champion à charger."
        self:Emit("error", problem, id)
        return false, problem
    end
    self.pending = {
        profile = snapshot,
        components = selected,
        id = id,
        reason = reason,
        automatic = automatic == true,
    }
    self:Emit("pending", "Setup mis en attente.", id)
    return true
end

function Engine:IsBusy()
    return self.active ~= nil or self.pending ~= nil
end

function Engine:StopActive(message)
    local request = self.active
    if not request then
        return false
    end
    local operation = request.operation
    if operation and operation.accepted then
        request.draining = true
        request.cancelMessage = message
        self:Emit("waiting", "Arrêt demandé : attente de la confirmation de l'étape envoyée.", request.id)
    else
        self.active = nil
        self.pausedAt = nil
        self:Emit("cancelled", message, request.id)
    end
    return true
end

function Engine:Cancel()
    local id = self.pending and self.pending.id or self.active and self.active.id
    self.pending = nil
    if not self:StopActive("Changement annulé.") then
        self.pausedAt = nil
        self:Emit("cancelled", "Changement annulé.", id)
    end
end

function Engine:CancelProfile(id)
    local removedPending = self.pending and self.pending.id == id
    if removedPending then self.pending = nil end
    if self.active and self.active.id == id then
        self:StopActive("Changement annulé : ce setup a été supprimé.")
        return true
    end
    if removedPending then
        if not self.active then self.pausedAt = nil end
        self:Emit("cancelled", "Changement annulé : ce setup a été supprimé.", id)
        return true
    end
    return false
end

function Engine:CancelAutomatic(preservePending)
    local pendingId
    local cancelledPending = false
    if self.pending and self.pending.automatic and not preservePending then
        pendingId = self.pending.id
        cancelledPending = true
        self.pending = nil
    end
    if self.active and self.active.automatic then
        self:StopActive("Changement automatique annulé : le contexte a changé.")
        return true
    end
    if cancelledPending then
        if not self.active then
            self.pausedAt = nil
        end
        self:Emit("cancelled", "Changement automatique annulé : le contexte a changé.", pendingId)
        return true
    end
    return false
end

function Engine:FinishCancellation()
    local request = self.active
    self.active = nil
    self.pausedAt = nil
    self:Emit("cancelled", request.cancelMessage or "Changement annulé.", request.id)
end

function Engine:Fail(message)
    local id = self.active and self.active.id or self.pending and self.pending.id
    self.active = nil
    self:Emit("error", tostring(message or "Le changement a échoué."), id)
end

function Engine:Resume(now)
    if not self.pausedAt then
        return
    end
    local duration = math.max(0, now - self.pausedAt)
    local operation = self.active and self.active.operation
    if self.active then self.active.needsRebuild = true end
    if operation then
        if operation.startedAt then
            operation.startedAt = operation.startedAt + duration
        end
        if operation.lastAttemptAt then
            operation.lastAttemptAt = operation.lastAttemptAt + duration
        end
        if operation.confirmedAt then
            operation.confirmedAt = operation.confirmedAt + duration
        end
    end
    self.pausedAt = nil
end

function Engine:BeginPending()
    local request = self.pending
    self.pending = nil
    self.active = request
    local ok, operations, problem = Call(self, "BuildPlan", request.profile, request.components)
    if not ok then
        self:Fail("Impossible de préparer ce setup. Recharge l'interface puis réessaie.")
        return false
    end
    if type(operations) ~= "table" then
        self:Fail(problem or "Impossible de préparer ce setup. Réenregistre-le puis réessaie.")
        return false
    end
    request.operations = operations
    request.index = 1
    request.operation = nil
    self:Emit("applying", "Chargement du setup.", request.id)
    return true
end

function Engine:Finish()
    local request = self.active
    local ok, verified, problem = Call(self, "Verify", request.profile, request.components)
    if not ok then
        self:Fail("Impossible de confirmer le résultat. Vérifie ton setup puis recharge l'interface.")
        return
    end
    if verified ~= true then
        self:Fail(problem or "Le setup n'est pas entièrement chargé. Vérifie-le puis réessaie.")
        return
    end
    self.active = nil
    local all = request.components.gear and request.components.skills and request.components.champion
    self:Emit("success", all and "Setup chargé et vérifié." or "Composants sélectionnés chargés et vérifiés.", request.id, request.components)
end

function Engine:Tick()
    if not self:IsBusy() then
        return
    end

    local clockOK, now = Call(self, "Now")
    if not clockOK or type(now) ~= "number" then
        self.pending = nil
        self:Fail("Impossible de suivre le changement. Recharge l'interface puis réessaie.")
        return
    end

    local readinessRequest = self.active and self.active.operation and self.active.operation.accepted and self.active or self.pending or self.active
    local readyOK, ready, problem = Call(self, "IsReady", readinessRequest and readinessRequest.components)
    if not readyOK then
        self.pending = nil
        self:Fail("Impossible de vérifier l'état du personnage. Recharge l'interface puis réessaie.")
        return
    end
    if ready ~= true then
        self.pausedAt = self.pausedAt or now
        local id = self.pending and self.pending.id or self.active and self.active.id
        self:Emit("waiting", problem or "En attente d'un personnage disponible hors combat.", id)
        return
    end
    self:Resume(now)

    -- An operation already sent must settle before a newer request can replace it.
    local operation = self.active and self.active.operation
    if self.pending and (not operation or not operation.accepted) then
        if not self:BeginPending() then
            return
        end
    end
    local request = self.active
    if not request then
        return
    end

    if request.needsRebuild and (not request.operation or not request.operation.accepted) then
        local planOK, operations, planProblem = Call(self, "BuildPlan", request.profile, request.components)
        if not planOK then
            self:Fail("Impossible de vérifier ce setup avant la reprise. Recharge l'interface puis réessaie.")
            return
        end
        if type(operations) ~= "table" then
            self:Fail(planProblem or "Ce setup a changé. Réenregistre-le avant de réessayer.")
            return
        end
        request.operations, request.index, request.operation = operations, 1, nil
        request.needsRebuild = nil
        self:Emit("applying", "Reprise après vérification du setup.", request.id)
    end

    operation = request.operation
    if not operation then
        local nextOperation = request.operations[request.index]
        if not nextOperation then
            self:Finish()
            return
        end
        local timeoutMs = type(nextOperation) == "table" and tonumber(nextOperation.timeoutMs) or nil
        if not timeoutMs or timeoutMs <= 0 or timeoutMs ~= timeoutMs or timeoutMs == math.huge then
            timeoutMs = TIMEOUT_MS
        end
        operation = { value = nextOperation, attempts = 0, timeoutMs = timeoutMs }
        request.operation = operation
    end

    local checkOK, satisfied = Call(self, "Satisfied", operation.value)
    if not checkOK then
        if operation.accepted then self.pending = nil end
        self:Fail("Impossible de vérifier cette étape. Vérifie ton setup puis recharge l'interface.")
        return
    end
    if satisfied == true then
        if operation.attempts > 0 then
            operation.confirmedAt = operation.confirmedAt or now
            if now - operation.confirmedAt < SETTLE_MS then
                self:Emit("applying", "Vérification du changement en cours.", request.id)
                return
            end
        end
        if request.draining then
            self:FinishCancellation()
            return
        end
        request.index = request.index + 1
        request.operation = nil
        return
    end
    operation.confirmedAt = nil

    if operation.startedAt and now - operation.startedAt >= operation.timeoutMs then
        -- The server may still complete an unconfirmed request after this timeout.
        -- Do not start a newer setup automatically from that uncertain state.
        if operation.accepted then self.pending = nil end
        local detail = operation.lastError and (" " .. tostring(operation.lastError)) or ""
        local message = request.draining
            and "Arrêt terminé sans confirmation : vérifie ton setup avant de demander un nouvel essai."
            or "Le jeu n'a pas confirmé le changement. Vérifie ton setup avant de demander un nouvel essai."
        self:Fail(message .. detail)
        return
    end
    if request.draining then
        self:Emit("waiting", "Arrêt demandé : attente de la confirmation de l'étape envoyée.", request.id)
        return
    end
    if operation.accepted and type(operation.value) == "table" and operation.value.retryAccepted == false then
        self:Emit("applying", "En attente de la confirmation du jeu.", request.id)
        return
    end
    if operation.attempts >= MAX_ATTEMPTS then
        self:Emit("applying", "En attente de la confirmation du jeu.", request.id)
        return
    end
    if operation.lastAttemptAt and now - operation.lastAttemptAt < RETRY_MS then
        return
    end

    -- Check readiness again immediately before each mutation.
    readyOK, ready, problem = Call(self, "IsReady", request.components)
    if not readyOK then
        self:Fail("Impossible de vérifier l'état du personnage. Recharge l'interface puis réessaie.")
        return
    end
    if ready ~= true then
        self.pausedAt = now
        self:Emit("waiting", problem or "Changement suspendu hors combat.", request.id)
        return
    end

    operation.startedAt = operation.startedAt or now
    operation.lastAttemptAt = now
    operation.attempts = operation.attempts + 1
    local performOK, accepted, performProblem = Call(self, "Perform", operation.value, request.components)
    if not performOK then
        self.pending = nil
        self:Fail("Le changement a été interrompu. Vérifie ton setup puis recharge l'interface avant de réessayer.")
        return
    end
    if accepted ~= true then
        operation.lastError = performProblem or "Le jeu a refusé cette étape."
    else
        operation.accepted = true
        operation.lastError = nil
    end
    self:Emit("applying", "En attente de la confirmation du jeu.", request.id)
end

Relais.EngineClass = Engine
