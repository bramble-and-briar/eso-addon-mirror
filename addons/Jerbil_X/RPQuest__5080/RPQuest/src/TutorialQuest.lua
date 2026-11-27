-- Ref: docs/adr/0012-savedvars-account-wide-y-migracion-por-personaje.md
-- Ref: docs/adr/0013-protocolo-versionado-de-esquema-y-migraciones-de-misiones.md
-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.TutorialQuest = {}
local TutorialQuest = Addon.TutorialQuest

TutorialQuest.TOTAL_STEPS = 3

local STEP_DEFINITIONS = {
    [1] = {
        step = 1,
        icon = "search",
        zoneId = 3,
        mapId = 63,
        targetX = 0.505,
        targetY = 0.195,
        titleKey = "TUTORIAL_1_TITLE",
        descKey = "TUTORIAL_1_DESC",
        completionKey = "TUTORIAL_1_COMPLETION_MSG",
        sequentialDiscoveries = false,
        stealthMode = function()
            return Addon.Constants.STEALTH_MODE.DISABLED
        end,
        buildTargets = function()
            return {}
        end,
        buildDiscoveries = function()
            return {}
        end,
        buildDialogues = function()
            local L = Addon.Locale
            return {
                {
                    npcName = L:Get("TUTORIAL_1_NPC_1_NAME"),
                    zoneId = 3,
                    clue = L:Get("TUTORIAL_1_NPC_1_CLUE"),
                    response = L:Get("TUTORIAL_1_NPC_1_RESPONSE"),
                    required = false,
                    executed = false,
                },
                {
                    npcName = L:Get("TUTORIAL_1_NPC_2_NAME"),
                    zoneId = 3,
                    clue = L:Get("TUTORIAL_1_NPC_2_CLUE"),
                    response = L:Get("TUTORIAL_1_NPC_2_RESPONSE"),
                    required = false,
                    executed = false,
                },
            }
        end,
    },
    [2] = {
        step = 2,
        icon = "steal",
        zoneId = 3,
        mapId = 63,
        titleKey = "TUTORIAL_2_TITLE",
        descKey = "TUTORIAL_2_DESC",
        completionKey = "TUTORIAL_2_COMPLETION_MSG",
        sequentialDiscoveries = true,
        stealthMode = function()
            return Addon.Constants.STEALTH_MODE.OPTIONAL
        end,
        buildTargets = function()
            return {}
        end,
        buildDiscoveries = function()
            local L = Addon.Locale
            return {
                {
                    x = 0.5340133905,
                    y = 0.1943165213,
                    worldX = 106106,
                    worldY = 16735,
                    worldZ = 295564,
                    radius = 800,
                    zoneId = 3,
                    mapId = 63,
                    message = L:Get("TUTORIAL_2_DISC_1_MSG"),
                    required = false,
                    discovered = false,
                },
                {
                    x = 0.5646548867,
                    y = 0.1879615039,
                    worldX = 108446,
                    worldY = 17023,
                    worldZ = 295070,
                    radius = 800,
                    zoneId = 3,
                    mapId = 63,
                    message = L:Get("TUTORIAL_2_DISC_2_MSG"),
                    required = false,
                    discovered = false,
                },
                {
                    x = 0.589560926,
                    y = 0.2385056764,
                    worldX = 110348,
                    worldY = 16928,
                    worldZ = 298999,
                    radius = 800,
                    zoneId = 3,
                    mapId = 63,
                    message = L:Get("TUTORIAL_2_DISC_3_MSG"),
                    required = false,
                    discovered = false,
                },
            }
        end,
        buildDialogues = function()
            return {}
        end,
    },
    [3] = {
        step = 3,
        icon = "black_hand",
        zoneId = 3,
        mapId = 63,
        worldX = 113396,
        worldY = 17372,
        worldZ = 299031,
        targetX = 0.6592507064,
        targetY = 0.2962924913,
        titleKey = "TUTORIAL_3_TITLE",
        descKey = "TUTORIAL_3_DESC",
        completionKey = "TUTORIAL_3_COMPLETION_MSG",
        sequentialDiscoveries = false,
        stealthMode = function()
            return Addon.Constants.STEALTH_MODE.DISABLED
        end,
        buildTargets = function()
            local L = Addon.Locale
            return {
                {
                    name = L:Get("TUTORIAL_3_TARGET_1_NAME"),
                    requiredCount = 1,
                    currentCount = 0,
                    optional = false,
                    isPlayer = false,
                    locationRequired = false,
                    zoneId = 3,
                    targetX = 0.6294734478,
                    targetY = 0.2389173359,
                    worldX = 113411,
                    worldZ = 299267,
                    areaCenterX = 0.6096014641,
                    areaCenterY = 0.2472405289,
                    areaRadius = 0.039,
                    radius = 3900,
                    customMessage = L:Get("TUTORIAL_3_TARGET_1_MSG"),
                    customMessageInLocation = L:Get("TUTORIAL_3_TARGET_1_LOC_MSG"),
                },
                {
                    name = L:Get("TUTORIAL_3_TARGET_2_NAME"),
                    requiredCount = 1,
                    currentCount = 0,
                    optional = true,
                    isPlayer = false,
                    locationRequired = false,
                    zoneId = 3,
                    targetX = 0.6890279651,
                    targetY = 0.3536676466,
                    worldX = 119149,
                    worldZ = 306809,
                    areaCenterX = 0.6716449522,
                    areaCenterY = 0.3689295318,
                    areaRadius = 0.039,
                    radius = 3900,
                    customMessage = L:Get("TUTORIAL_3_TARGET_2_MSG"),
                    customMessageInLocation = "",
                },
            }
        end,
        buildDiscoveries = function()
            return {}
        end,
        buildDialogues = function()
            return {}
        end,
    },
}

local function EnsureTutorialState(savedVars)
    if type(savedVars) ~= "table" then
        return { steps = {} }
    end
    if type(savedVars.tutorialState) ~= "table" then
        savedVars.tutorialState = {}
    end
    if type(savedVars.tutorialState.steps) ~= "table" then
        savedVars.tutorialState.steps = {}
    end
    return savedVars.tutorialState
end

local function EnsureStepEntry(state, step)
    if type(state.steps[step]) ~= "table" then
        state.steps[step] = {
            seeded = false,
            resolved = false,
            resolution = nil,
        }
    end
    return state.steps[step]
end

function TutorialQuest:GetStepDefinition(step)
    return STEP_DEFINITIONS[tonumber(step)]
end

function TutorialQuest:BuildQuestRecordForStep(repo, step, newId)
    local def = self:GetStepDefinition(step)
    if not def or not repo then
        return nil
    end

    local L = Addon.Locale
    local statuses = Addon.Constants.QUEST_STATUS
    local roles = Addon.Constants.QUEST_ROLE
    local targets = def.buildTargets()
    local discoveries = def.buildDiscoveries()
    local dialogues = def.buildDialogues()

    local data = {
        status = statuses.OFFERED,
        senderDisplayName = "",
        senderCharacterName = L:Get("TUTORIAL_SENDER_NAME"),
        recipientAccount = "",
        recipientCharacterName = "",
        clue = "",
        completionMessage = L:Get(def.completionKey),
        discoveries = discoveries,
        dialogues = dialogues,
        sequentialDiscoveries = def.sequentialDiscoveries == true,
        mapId = def.mapId,
        zoneId = def.zoneId,
        mapName = L:Get("TUTORIAL_MAP_DAGGERFALL"),
        worldX = def.worldX,
        worldY = def.worldY,
        worldZ = def.worldZ,
        targetX = def.targetX,
        targetY = def.targetY,
        recommendHideMapAreas = true,
        stealthMode = def.stealthMode(),
        icon = def.icon,
        isTutorial = true,
        tutorialStep = def.step,
    }

    local quest = repo:BuildQuestRecord(
        newId,
        L:Get(def.titleKey),
        L:Get(def.descKey),
        targets,
        data,
        roles.RECEIVED
    )
    quest.isTutorial = true
    quest.tutorialStep = def.step
    quest.createdAt = GetTimeStamp() or 0
    return quest
end

local function SyncTargetsWithCanonical(existingTargets, canonicalTargets)
    local updated = {}
    for i, canon in ipairs(canonicalTargets) do
        local prev = type(existingTargets) == "table" and existingTargets[i] or nil
        if type(prev) == "table" then
            canon.currentCount = math.min(canon.requiredCount or 1, math.max(0, tonumber(prev.currentCount) or 0))
        end
        updated[i] = canon
    end
    return updated
end

local function SyncDiscoveriesWithCanonical(existingDiscoveries, canonicalDiscoveries)
    local updated = {}
    for i, canon in ipairs(canonicalDiscoveries) do
        local prev = type(existingDiscoveries) == "table" and existingDiscoveries[i] or nil
        if type(prev) == "table" then
            canon.discovered = (prev.discovered == true)
        end
        updated[i] = canon
    end
    return updated
end

local function SyncDialoguesWithCanonical(existingDialogues, canonicalDialogues)
    local updated = {}
    for i, canon in ipairs(canonicalDialogues) do
        local prev = type(existingDialogues) == "table" and existingDialogues[i] or nil
        if type(prev) == "table" then
            canon.executed = (prev.executed == true)
        end
        updated[i] = canon
    end
    return updated
end

function TutorialQuest:RefreshExistingQuest(repo, quest)
    if type(quest) ~= "table" or quest.isTutorial ~= true then
        return false
    end
    local step = tonumber(quest.tutorialStep)
    if not step or not self:GetStepDefinition(step) then
        return false
    end

    local canonical = self:BuildQuestRecordForStep(repo, step, quest.id)
    if not canonical then
        return false
    end

    quest.title = canonical.title
    quest.description = canonical.description
    quest.completionMessage = canonical.completionMessage
    quest.senderDisplayName = canonical.senderDisplayName
    quest.senderCharacterName = canonical.senderCharacterName
    quest.icon = canonical.icon
    quest.zoneId = canonical.zoneId
    quest.mapId = canonical.mapId
    quest.mapName = canonical.mapName
    quest.worldX = canonical.worldX
    quest.worldY = canonical.worldY
    quest.worldZ = canonical.worldZ
    quest.targetX = canonical.targetX
    quest.targetY = canonical.targetY
    quest.sequentialDiscoveries = canonical.sequentialDiscoveries
    quest.stealthMode = canonical.stealthMode
    quest.recommendHideMapAreas = canonical.recommendHideMapAreas
    quest.targets = SyncTargetsWithCanonical(quest.targets, canonical.targets)
    quest.discoveries = SyncDiscoveriesWithCanonical(quest.discoveries, canonical.discoveries)
    quest.dialogues = SyncDialoguesWithCanonical(quest.dialogues, canonical.dialogues)
    quest.schemaVersion = canonical.schemaVersion
    quest.needsMigration = nil
    quest.migrationReason = nil

    if Addon.QuestMigration then
        Addon.QuestMigration:MigrateQuestRecord(quest)
    end
    return true
end

function TutorialQuest:SeedStep(repo, step, notify)
    if not repo or not repo.savedVars then
        return nil
    end
    local def = self:GetStepDefinition(step)
    if not def then
        return nil
    end

    local state = EnsureTutorialState(repo.savedVars)
    local entry = EnsureStepEntry(state, step)
    if entry.seeded then
        return nil
    end

    local newId = repo.savedVars.nextId or 1
    repo.savedVars.nextId = newId + 1

    local quest = self:BuildQuestRecordForStep(repo, step, newId)
    if not quest then
        return nil
    end

    table.insert(repo.savedVars.quests, quest)
    if repo._questById then
        repo._questById[quest.id] = quest
    end

    entry.seeded = true
    if notify ~= false then
        repo:NotifyListeners("QUEST_CREATED", quest)
    end
    return quest
end

function TutorialQuest:InitializeForRepository(repo)
    if not repo or not repo.savedVars then
        return
    end
    local state = EnsureTutorialState(repo.savedVars)

    for _, q in ipairs(repo.savedVars.quests or {}) do
        if q.isTutorial == true and q.tutorialStep then
            local step = tonumber(q.tutorialStep)
            if step and self:GetStepDefinition(step) then
                local entry = EnsureStepEntry(state, step)
                entry.seeded = true
                if q.completed then
                    entry.resolved = true
                    entry.resolution = Addon.Constants.QUEST_RESOLUTION.COMPLETED
                elseif q.failed then
                    entry.resolved = true
                    entry.resolution = Addon.Constants.QUEST_RESOLUTION.FAILED
                end
                self:RefreshExistingQuest(repo, q)
            end
        end
    end

    local step1 = EnsureStepEntry(state, 1)
    if not step1.seeded then
        self:SeedStep(repo, 1, false)
    elseif step1.resolution == Addon.Constants.QUEST_RESOLUTION.COMPLETED then
        local step2 = EnsureStepEntry(state, 2)
        if not step2.seeded then
            self:SeedStep(repo, 2, false)
        elseif step2.resolution == Addon.Constants.QUEST_RESOLUTION.COMPLETED then
            local step3 = EnsureStepEntry(state, 3)
            if not step3.seeded then
                self:SeedStep(repo, 3, false)
            end
        end
    end
end

function TutorialQuest:OnQuestResolved(repo, quest, resolution)
    if not repo or not repo.savedVars or type(quest) ~= "table" or quest.isTutorial ~= true then
        return nil
    end
    local step = tonumber(quest.tutorialStep)
    if not step or not self:GetStepDefinition(step) then
        return nil
    end

    local state = EnsureTutorialState(repo.savedVars)
    local entry = EnsureStepEntry(state, step)
    entry.seeded = true
    entry.resolved = true
    entry.resolution = resolution

    if resolution == Addon.Constants.QUEST_RESOLUTION.COMPLETED and step < self.TOTAL_STEPS then
        local nextStep = step + 1
        local nextEntry = EnsureStepEntry(state, nextStep)
        if not nextEntry.seeded then
            return self:SeedStep(repo, nextStep, true)
        end
    end
    return nil
end
