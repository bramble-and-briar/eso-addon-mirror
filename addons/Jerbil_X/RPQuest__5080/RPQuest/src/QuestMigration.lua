-- Ref: docs/adr/0012-savedvars-account-wide-y-migracion-por-personaje.md
-- Ref: docs/adr/0013-protocolo-versionado-de-esquema-y-migraciones-de-misiones.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestMigration = {}
local QuestMigration = Addon.QuestMigration

-- Registry of sequential schema migrators keyed by source schemaVersion (vN -> vN+1).
-- A migrator may return `false, reason` to flag a breaking PREPARED quest with `needsMigration = true`.
QuestMigration.SCHEMA_MIGRATORS = QuestMigration.SCHEMA_MIGRATORS or {}

QuestMigration.SCHEMA_MIGRATORS[1] = function(quest)
    if type(quest) ~= "table" then
        return true
    end
    local modes = Addon.Constants and Addon.Constants.STEALTH_MODE
    local disabled = (modes and modes.DISABLED) or "disabled"
    local optional = (modes and modes.OPTIONAL) or "optional"
    local required = (modes and modes.REQUIRED) or "required"

    local mode = quest.stealthMode
    if mode ~= disabled and mode ~= optional and mode ~= required then
        quest.stealthMode = (quest.requireUndetected == true) and optional or disabled
    end
    quest.requireUndetected = nil
    return true
end

QuestMigration.SCHEMA_MIGRATORS[2] = function(quest)
    if type(quest) ~= "table" then
        return true
    end
    if quest.recommendHideMapAreas == nil then
        quest.recommendHideMapAreas = (quest.hideMapArea == true)
    end
    quest.hideMapArea = nil

    local defaultRad = (Addon.Constants and Addon.Constants.AREA_RADIUS and Addon.Constants.AREA_RADIUS.MEDIUM) or 0.125
    local qCenterX = quest.areaCenterX
    local qCenterY = quest.areaCenterY
    local qRadius = tonumber(quest.areaRadius)
    if not qRadius or qRadius <= 0 then
        qRadius = defaultRad
    end

    if type(quest.targets) == "table" then
        for _, target in ipairs(quest.targets) do
            if type(target) == "table" then
                if target.areaCenterX == nil and qCenterX ~= nil then
                    target.areaCenterX = qCenterX
                end
                if target.areaCenterY == nil and qCenterY ~= nil then
                    target.areaCenterY = qCenterY
                end
                if target.areaRadius == nil or (tonumber(target.areaRadius) or 0) <= 0 then
                    target.areaRadius = qRadius
                end
                if type(target.customMessage) ~= "string" then
                    target.customMessage = ""
                end
                if type(target.customMessageInLocation) ~= "string" then
                    target.customMessageInLocation = ""
                end
                if type(target.customMessageOutsideLocation) ~= "string" then
                    target.customMessageOutsideLocation = ""
                end
            end
        end
    end

    quest.areaCenterX = nil
    quest.areaCenterY = nil
    quest.areaRadius = nil
    return true
end

function QuestMigration:GetCurrentSchemaVersion()
    local schema = Addon.Constants and Addon.Constants.QUEST_SCHEMA
    return (schema and tonumber(schema.CURRENT_VERSION)) or 1
end

function QuestMigration:NeedsMigration(quest)
    return type(quest) == "table" and quest.needsMigration == true
end

function QuestMigration:MigrateQuestRecord(quest, options)
    if type(quest) ~= "table" then
        return quest, false
    end

    local targetVersion = (options and tonumber(options.targetVersion)) or self:GetCurrentSchemaVersion()
    local migrators = (options and type(options.migrators) == "table" and options.migrators) or self.SCHEMA_MIGRATORS

    local version = math.floor(tonumber(quest.schemaVersion) or 1)
    if version < 1 then
        version = 1
    end

    if quest.needsMigration == true and version >= targetVersion then
        quest.schemaVersion = version
        return quest, false, quest.migrationReason
    end

    local didMigrate = (quest.schemaVersion ~= version)
    while version < targetVersion do
        local migrator = migrators[version]
        if type(migrator) == "function" then
            local ok, reason = migrator(quest, options)
            if ok == false then
                quest.schemaVersion = version
                quest.needsMigration = true
                quest.migrationReason = (type(reason) == "string" and reason ~= "") and reason or nil
                return quest, false, quest.migrationReason
            end
        end
        version = version + 1
        quest.schemaVersion = version
        didMigrate = true
    end

    quest.schemaVersion = version
    quest.needsMigration = nil
    quest.migrationReason = nil
    return quest, didMigrate
end

function QuestMigration:MigrateQuestList(quests, options)
    if type(quests) ~= "table" then
        return 0
    end
    local migratedCount = 0
    for _, quest in ipairs(quests) do
        if type(quest) == "table" then
            local _, didMigrate = self:MigrateQuestRecord(quest, options)
            if didMigrate then
                migratedCount = migratedCount + 1
            end
        end
    end
    return migratedCount
end

local function DeepCopyValue(val, seen)
    if type(val) ~= "table" then
        return val
    end
    seen = seen or {}
    if seen[val] then
        return seen[val]
    end
    local copy = {}
    seen[val] = copy
    for k, v in pairs(val) do
        copy[DeepCopyValue(k, seen)] = DeepCopyValue(v, seen)
    end
    return copy
end

local function IsDraftEmpty(draft)
    if type(draft) ~= "table" then
        return true
    end
    local hasText = (type(draft.title) == "string" and draft.title ~= "")
        or (type(draft.description) == "string" and draft.description ~= "")
        or (type(draft.clue) == "string" and draft.clue ~= "")
        or (type(draft.completionMessage) == "string" and draft.completionMessage ~= "")
    if hasText then
        return false
    end
    local hasLists = (type(draft.targets) == "table" and #draft.targets > 0)
        or (type(draft.discoveries) == "table" and #draft.discoveries > 0)
        or (type(draft.dialogues) == "table" and #draft.dialogues > 0)
    return not hasLists
end

local function IsCharacterBucket(charData)
    if type(charData) ~= "table" then
        return false
    end
    return type(charData.quests) == "table"
        or type(charData.ingestedMailIds) == "table"
        or type(charData.draft) == "table"
        or type(charData.settings) == "table"
end

function QuestMigration:MigrateCharacterSavedVars(rawRoot, displayName, savedVars, currentCharId)
    if type(rawRoot) ~= "table" or type(displayName) ~= "string" or displayName == "" or type(savedVars) ~= "table" then
        return 0
    end
    local defaultProfile = rawRoot["Default"]
    if type(defaultProfile) ~= "table" then
        return 0
    end
    local accountRoot = defaultProfile[displayName]
    if type(accountRoot) ~= "table" then
        return 0
    end

    savedVars.nextId = tonumber(savedVars.nextId) or 1
    savedVars.quests = type(savedVars.quests) == "table" and savedVars.quests or {}
    savedVars.ingestedMailIds = type(savedVars.ingestedMailIds) == "table" and savedVars.ingestedMailIds or {}
    savedVars.migratedCharacterIds = type(savedVars.migratedCharacterIds) == "table" and savedVars.migratedCharacterIds or {}

    local usedIds = {}
    local maxId = 0
    for _, q in ipairs(savedVars.quests) do
        if type(q) == "table" and type(q.id) == "number" then
            usedIds[q.id] = true
            if q.id > maxId then
                maxId = q.id
            end
        end
    end
    if savedVars.nextId <= maxId then
        savedVars.nextId = maxId + 1
    end

    local charKeys = {}
    for charKey, charData in pairs(accountRoot) do
        if charKey ~= "$AccountWide" and not savedVars.migratedCharacterIds[charKey] and IsCharacterBucket(charData) then
            table.insert(charKeys, charKey)
        end
    end
    table.sort(charKeys, function(a, b)
        if currentCharId and a == currentCharId and b ~= currentCharId then
            return true
        end
        if currentCharId and b == currentCharId and a ~= currentCharId then
            return false
        end
        return tostring(a) < tostring(b)
    end)

    local migratedCount = 0
    for _, charKey in ipairs(charKeys) do
        local charData = accountRoot[charKey]
        local idMap = {}

        if type(charData.quests) == "table" then
            for _, srcQuest in ipairs(charData.quests) do
                if type(srcQuest) == "table" then
                    local cloned = DeepCopyValue(srcQuest)
                    local oldId = tonumber(cloned.id)
                    local newId = oldId
                    if not newId or newId < 1 or usedIds[newId] then
                        newId = savedVars.nextId
                        savedVars.nextId = newId + 1
                    elseif newId >= savedVars.nextId then
                        savedVars.nextId = newId + 1
                    end
                    cloned.id = newId
                    usedIds[newId] = true
                    if oldId then
                        idMap[oldId] = newId
                    end
                    table.insert(savedVars.quests, cloned)
                    migratedCount = migratedCount + 1
                end
            end
        end

        if type(charData.ingestedMailIds) == "table" then
            for mailKey, flag in pairs(charData.ingestedMailIds) do
                if flag then
                    savedVars.ingestedMailIds[mailKey] = true
                end
            end
        end

        if savedVars.activeQuestId == nil and charData.activeQuestId ~= nil then
            local activeNum = tonumber(charData.activeQuestId)
            savedVars.activeQuestId = (activeNum and idMap[activeNum]) or charData.activeQuestId
        end

        if not savedVars._migratedSettings and type(charData.settings) == "table" then
            savedVars.settings = type(savedVars.settings) == "table" and savedVars.settings or {}
            for k, v in pairs(charData.settings) do
                if v ~= nil then
                    savedVars.settings[k] = v
                end
            end
            savedVars._migratedSettings = true
        end

        if IsDraftEmpty(savedVars.draft) and type(charData.draft) == "table" and not IsDraftEmpty(charData.draft) then
            local clonedDraft = DeepCopyValue(charData.draft)
            local editId = tonumber(clonedDraft.editingQuestId)
            if editId and idMap[editId] then
                clonedDraft.editingQuestId = idMap[editId]
            end
            savedVars.draft = clonedDraft
        end

        savedVars.migratedCharacterIds[charKey] = true
    end

    return migratedCount
end
