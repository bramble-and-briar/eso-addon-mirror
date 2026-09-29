local CAM = CraftPawns
CAM.SavedData = {}
local SD = CAM.SavedData

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[DeepCopy(key, seen)] = DeepCopy(child, seen) end
    return copy
end

local function EnsureServer(database, serverKey)
    database.servers = database.servers or {}
    database.servers[serverKey] = database.servers[serverKey] or {
        characters = {}, order = {}, former = {}, plans = {}, prepared = {},
    }
    local server = database.servers[serverKey]
    server.characters = server.characters or {}
    server.order = server.order or {}
    server.former = server.former or {}
    server.plans = server.plans or {}
    server.prepared = server.prepared or {}
    return server
end

local function IsNewerRecord(candidate, existing)
    if not existing then return true end
    local candidateScan = tonumber(candidate and (candidate.lastScan or (candidate.snapshot and candidate.snapshot.scannedAt))) or 0
    local existingScan = tonumber(existing and (existing.lastScan or (existing.snapshot and existing.snapshot.scannedAt))) or 0
    return candidateScan > existingScan
end

function SD:MergeAccountDatabase(source, accountName, copySettings)
    if type(source) ~= "table" or source == CAM.sv then return end
    accountName = tostring(accountName or "UnknownAccount")
    CAM.sv.migratedAccounts = CAM.sv.migratedAccounts or {}
    if CAM.sv.migratedAccounts[accountName] then return end

    if copySettings and type(source.settings) == "table" then
        CAM.sv.settings = DeepCopy(source.settings)
    end
    if type(source.knowledgeCatalog) == "table" and not CAM.sv.knowledgeCatalog then
        CAM.sv.knowledgeCatalog = DeepCopy(source.knowledgeCatalog)
    end

    for serverKey, sourceServer in pairs(source.servers or {}) do
        if type(sourceServer) == "table" then
            local target = EnsureServer(CAM.sv, serverKey)
            for _, bucketName in ipairs({ "characters", "former" }) do
                local sourceBucket = sourceServer[bucketName] or {}
                for id, sourceRecord in pairs(sourceBucket) do
                    if type(sourceRecord) == "table" then
                        local record = DeepCopy(sourceRecord)
                        record.account = record.account or (record.snapshot and record.snapshot.account) or accountName
                        local existing = target.characters[id] or target.former[id]
                        if IsNewerRecord(record, existing) then
                            target.characters[id] = nil
                            target.former[id] = nil
                            target[bucketName][id] = record
                        end
                    end
                end
            end
            for id, plan in pairs(sourceServer.plans or {}) do
                if target.plans[id] == nil then target.plans[id] = DeepCopy(plan) end
            end
            for id, prepared in pairs(sourceServer.prepared or {}) do
                if target.prepared[id] == nil then target.prepared[id] = DeepCopy(prepared) end
            end
            local seen = {}
            for _, id in ipairs(target.order) do seen[id] = true end
            for _, id in ipairs(sourceServer.order or {}) do
                if not seen[id] then target.order[#target.order + 1] = id; seen[id] = true end
            end
        end
    end
    CAM.sv.migratedAccounts[accountName] = true
end

function SD:MigrateMachineData(rawSavedVariables, currentAccount, currentLegacy)
    CAM.sv.migratedAccounts = CAM.sv.migratedAccounts or {}
    local firstMigration = (tonumber(CAM.sv.machineMigrationVersion) or 0) < 1
    self:MergeAccountDatabase(currentLegacy, currentAccount, firstMigration)

    -- ESO loads every account branch from this SavedVariables file into the
    -- global table. Import each legacy $AccountWide branch once, so accounts
    -- that were already used on this machine appear without another login.
    for _, profile in pairs(type(rawSavedVariables) == "table" and rawSavedVariables or {}) do
        if type(profile) == "table" then
            for accountName, accountBranch in pairs(profile) do
                if accountName ~= "$Machine" and type(accountBranch) == "table" then
                    local legacy = accountBranch["$AccountWide"]
                    if type(legacy) == "table" then
                        self:MergeAccountDatabase(legacy, accountName, false)
                    end
                end
            end
        end
    end
    CAM.sv.machineMigrationVersion = 1
end

function SD:Initialize()
    local rawSavedVariables = _G["CraftPawnsSavedVariables"]
    local currentAccount = GetDisplayName and GetDisplayName() or "UnknownAccount"
    local currentLegacy = ZO_SavedVars:NewAccountWide("CraftPawnsSavedVariables", 1, nil, CAM.defaults)
    CAM.sv = ZO_SavedVars:NewAccountWide("CraftPawnsSavedVariables", 1, nil, CAM.defaults, nil, "$Machine")
    self:MigrateMachineData(rawSavedVariables, currentAccount, currentLegacy)
    self:Migrate()
    CAM.serverKey = GetWorldName and GetWorldName() or "UnknownServer"
    local servers = CAM.sv.servers
    servers[CAM.serverKey] = servers[CAM.serverKey] or {
        characters = {}, order = {}, former = {}, plans = {}, prepared = {},
    }
    CAM.server = servers[CAM.serverKey]
    self:RefreshRoster()
end

function SD:Migrate()
    local version = tonumber(CAM.sv.schemaVersion) or 0
    if version < 1 then CAM.sv.schemaVersion = 1 end
    if version < 2 then
        CAM.sv.migratedAccounts = CAM.sv.migratedAccounts or {}
        CAM.sv.machineMigrationVersion = tonumber(CAM.sv.machineMigrationVersion) or 1
        CAM.sv.schemaVersion = 2
    end
end

function SD:RefreshRoster()
    local active = {}
    local selectOrder = {}
    local currentAccount = GetDisplayName and GetDisplayName() or "UnknownAccount"
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        id = tostring(id)
        active[id] = true
        selectOrder[#selectOrder + 1] = id
        local old = CAM.server.characters[id] or CAM.server.former[id]
        CAM.server.former[id] = nil
        CAM.server.characters[id] = old or { id=id, currentName=zo_strformat(SI_UNIT_NAME, name), status="needsScan" }
        CAM.server.characters[id].currentName = zo_strformat(SI_UNIT_NAME, name)
        CAM.server.characters[id].account = currentAccount
    end
    for id, character in pairs(CAM.server.characters) do
        if character.account == currentAccount and not active[id] then
            CAM.server.former[id] = character
            CAM.server.characters[id] = nil
        end
    end
    local result, seen = {}, {}
    for _, id in ipairs(CAM.server.order) do
        if CAM.server.characters[id] and not seen[id] then result[#result + 1] = id; seen[id] = true end
    end
    for _, id in ipairs(selectOrder) do
        if not seen[id] then result[#result + 1] = id; seen[id] = true end
    end
    CAM.server.order = result
    CAM.server.selectOrder = selectOrder
end

function SD:CommitSnapshot(id, snapshot)
    local record = CAM.server.characters[id]
    if not record then return false end
    record.snapshot = snapshot
    record.account = snapshot.account or record.account
    record.currentName = snapshot.name
    record.lastScan = snapshot.scannedAt
    record.status = "valid"
    record.scanError = nil
    return true
end

function SD:MarkScanFailure(id, reason)
    local record = CAM.server.characters[id]
    if not record then return end
    record.scanError = tostring(reason or "Incomplete scan")
    if not record.snapshot then record.status = "incomplete" end
end

function SD:Move(id, delta)
    local order = CAM.server.order
    for i, value in ipairs(order) do
        if value == id then
            local target = zo_clamp(i + delta, 1, #order)
            order[i], order[target] = order[target], order[i]
            return
        end
    end
end

function SD:ResetOrder()
    local result, seen = {}, {}
    for _, id in ipairs(CAM.server.selectOrder or {}) do result[#result + 1] = id; seen[id] = true end
    for _, id in ipairs(CAM.server.order or {}) do
        if CAM.server.characters[id] and not seen[id] then result[#result + 1] = id; seen[id] = true end
    end
    CAM.server.order = result
end
