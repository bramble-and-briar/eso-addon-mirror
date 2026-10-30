DungeonScores = DungeonScores or {}

-- Locale-independent encounter observations. This module records only API
-- identities, numeric health values, timestamps, and boolean state. Localized
-- display text must never become a key or a classification input here.

local DS = DungeonScores
DS.EncounterEvidence = DS.EncounterEvidence or {}
local Evidence = DS.EncounterEvidence

Evidence.SCHEMA_VERSION = 1

local function IsPositiveNumber(value)
    value = tonumber(value)
    return value ~= nil and value > 0
end

local function AddSetValue(container, key)
    if key == nil or container[key] == true then
        return false
    end
    container[key] = true
    return true
end

function Evidence:NewLedger(zoneId)
    return {
        schemaVersion = self.SCHEMA_VERSION,
        zoneId = tonumber(zoneId) or 0,
        identities = {},
        latestIdentityByUnitTag = {},
        maxHealthIndex = {},
    }
end

-- Retired chronology was never read by the scorer or HM resolvers. Prune old
-- SavedVariables instances without discarding the numeric identity and health
-- evidence that is needed for encounter attribution and troubleshooting.
function Evidence:PruneRetiredTelemetry(ledger)
    if type(ledger) ~= "table" then
        return false
    end
    local hadRetired = ledger.bossListSignals ~= nil
        or ledger.combatDeaths ~= nil or ledger.combatDeathUnitIndex ~= nil
    if hadRetired then
        ledger.bossListSignals = nil
        ledger.combatDeaths = nil
        ledger.combatDeathUnitIndex = nil
    end
    return hadRetired
end

function Evidence:EnsureLedger(run)
    if type(run) ~= "table" then
        return nil
    end

    local ledger = run.encounterEvidence
    if type(ledger) ~= "table" or ledger.schemaVersion ~= self.SCHEMA_VERSION then
        ledger = self:NewLedger(run.zoneId)
        run.encounterEvidence = ledger
    end
    ledger.identities = ledger.identities or {}
    ledger.latestIdentityByUnitTag = ledger.latestIdentityByUnitTag or {}
    ledger.maxHealthIndex = ledger.maxHealthIndex or {}
    self:PruneRetiredTelemetry(ledger)
    return ledger
end

function Evidence:GetLatestIdentityIdForUnitTag(run, unitTag)
    local ledger = self:EnsureLedger(run)
    if not ledger or unitTag == nil then
        return nil
    end
    local identityId = tonumber(ledger.latestIdentityByUnitTag[tostring(unitTag)])
    return IsPositiveNumber(identityId) and identityId or nil
end

function Evidence:GetIdentity(run, boss, create)
    local ledger = self:EnsureLedger(run)
    local identityId = boss and tonumber(boss.identityId) or nil
    if not ledger or not IsPositiveNumber(identityId) then
        return nil, nil
    end

    local identity = ledger.identities[identityId]
    if type(identity) ~= "table" and create then
        identity = {
            identityId = identityId,
            startReason = boss.identityStartReason,
            unitIds = {},
            unitTags = {},
            maxHealthSamples = {},
            coobservedIdentityIds = {},
            semanticBindings = {},
        }
        ledger.identities[identityId] = identity
    end
    return identity, ledger
end

function Evidence:ObserveBoss(run, boss, currentHealth, maxHealth, effectiveMaxHealth, inCombat, observedAtMs)
    local identity, ledger = self:GetIdentity(run, boss, true)
    if not identity then
        return nil, false
    end

    observedAtMs = tonumber(observedAtMs) or 0
    currentHealth = tonumber(currentHealth)
    maxHealth = tonumber(maxHealth)
    effectiveMaxHealth = tonumber(effectiveMaxHealth)

    local changed = identity.firstObservedAtMs == nil
    identity.firstObservedAtMs = identity.firstObservedAtMs or observedAtMs
    identity.lastObservedAtMs = observedAtMs
    identity.latestCurrentHealth = currentHealth
    identity.latestMaxHealth = maxHealth
    identity.latestEffectiveMaxHealth = effectiveMaxHealth

    if IsPositiveNumber(boss.unitId) then
        changed = AddSetValue(identity.unitIds, tonumber(boss.unitId)) or changed
    end
    if boss.unitTag ~= nil then
        local unitTag = tostring(boss.unitTag)
        changed = AddSetValue(identity.unitTags, unitTag) or changed
        if ledger.latestIdentityByUnitTag[unitTag] ~= identity.identityId then
            ledger.latestIdentityByUnitTag[unitTag] = identity.identityId
            changed = true
        end
    end

    if IsPositiveNumber(maxHealth) then
        local sample = identity.maxHealthSamples[maxHealth]
        if type(sample) ~= "table" then
            sample = {
                firstObservedAtMs = observedAtMs,
                lastObservedAtMs = observedAtMs,
            }
            identity.maxHealthSamples[maxHealth] = sample
            changed = true
        else
            sample.lastObservedAtMs = observedAtMs
        end

        local indexedIdentities = ledger.maxHealthIndex[maxHealth]
        if type(indexedIdentities) ~= "table" then
            indexedIdentities = {}
            ledger.maxHealthIndex[maxHealth] = indexedIdentities
        end
        changed = AddSetValue(indexedIdentities, identity.identityId) or changed

        if currentHealth ~= nil and currentHealth >= 0 and currentHealth < maxHealth
            and identity.sawHealthLoss ~= true then
            identity.sawHealthLoss = true
            identity.firstHealthLossAtMs = observedAtMs
            changed = true
        end
    end

    if inCombat == true and identity.sawCombat ~= true then
        identity.sawCombat = true
        identity.firstCombatAtMs = observedAtMs
        changed = true
    end

    return identity, changed
end

function Evidence:RecordBossCohort(run, bosses, observedAtMs)
    local ledger = self:EnsureLedger(run)
    if not ledger then
        return false
    end

    local identityIds = {}
    for _, boss in pairs(bosses or {}) do
        local identityId = tonumber(boss.identityId)
        if IsPositiveNumber(identityId) and ledger.identities[identityId] then
            identityIds[#identityIds + 1] = identityId
        end
    end
    if #identityIds < 2 then
        return false
    end

    -- Retain only numeric run-local co-observation edges. These allow a verified
    -- encounter key observed later in a pull to bind a member that has already
    -- died, without consulting localized names or assuming boss-tag order.
    local changed = false
    observedAtMs = tonumber(observedAtMs) or 0
    for _, identityId in ipairs(identityIds) do
        local identity = ledger.identities[identityId]
        identity.coobservedIdentityIds = identity.coobservedIdentityIds or {}
        for _, otherIdentityId in ipairs(identityIds) do
            if otherIdentityId ~= identityId
                and type(identity.coobservedIdentityIds[otherIdentityId]) ~= "table" then
                identity.coobservedIdentityIds[otherIdentityId] = {
                    firstObservedAtMs = observedAtMs,
                }
                changed = true
            end
        end
    end
    return changed
end

function Evidence:RecordDeathState(run, boss, isDead, observedAtMs)
    local identity = self:GetIdentity(run, boss, true)
    if not identity then
        return false
    end

    local dead = isDead == true
    if identity.deathState == dead then
        return false
    end
    identity.deathState = dead
    identity.deathStateChangedAtMs = tonumber(observedAtMs) or 0
    if dead then
        identity.sawDeathState = true
    end
    return true
end

function Evidence:BindSemanticKey(run, boss, semanticKey, sourceCode, observedAtMs)
    local identity = self:GetIdentity(run, boss, true)
    if not identity or semanticKey == nil then
        return false
    end

    semanticKey = tostring(semanticKey)
    local current = identity.semanticBindings[semanticKey]
    if type(current) == "table" then
        return false
    end
    identity.semanticBindings[semanticKey] = {
        sourceCode = sourceCode and tostring(sourceCode) or nil,
        observedAtMs = tonumber(observedAtMs) or 0,
    }
    return true
end
