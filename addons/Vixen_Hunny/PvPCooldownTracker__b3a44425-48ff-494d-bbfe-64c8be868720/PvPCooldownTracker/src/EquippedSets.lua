-- -----------------------------------------------------------------------------
-- PvPCooldownTracker - EquippedSets.lua
--
-- Scans the player's equipped gear, matches set names against the proc catalog
-- in PvPCooldownTracker.Data.Sets, auto-registers cooldown/proc data into
-- savedVars, and provides LAM controls for manual import of unknown sets.
-- -----------------------------------------------------------------------------
PvPCooldownTracker            = PvPCooldownTracker or {}
PvPCooldownTracker.EquippedSets = {}

local PCT = PvPCooldownTracker
local EM = EVENT_MANAGER

local function GetStateTables()
    if PCT.Settings and type(PCT.Settings.EnsureState) == "function" then
        local savedVars = PCT.Settings.EnsureState()
        return savedVars or {}, PCT.character or {}
    end

    if type(PCT.EnsureSavedVariables) == "function" then
        local savedVars, character = PCT.EnsureSavedVariables()
        return savedVars or {}, character or {}
    end

    return PCT.savedVars or {}, PCT.character or {}
end

local function IsStateContainer(value)
    if type(PCT.IsStateContainer) == "function" then
        return PCT.IsStateContainer(value)
    end

    local valueType = type(value)
    return value ~= nil and (valueType == "table" or valueType == "userdata")
end

-- Equipped item slots to scan (mirrors Data.ITEM_SLOTS).
local WORN_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

-- Cached results from the most recent scan.
PCT.EquippedSets.lastScanResults = nil

local function SafeId(v)
    local n = tonumber(v)
    if n ~= nil then
        if n >= 0 then
            n = math.floor(n)
        else
            n = math.ceil(n)
        end
    end
    return (n and n > 0) and n or 0
end

local function NormalizeInteger(value)
    local n = tonumber(value)
    if n == nil then
        return nil
    end

    if n >= 0 then
        return math.floor(n)
    end

    return math.ceil(n)
end

local function CloneTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CloneTable(value)
        else
            copy[key] = value
        end
    end

    return copy
end

local function TrimString(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeNumberish(value)
    if value == nil then
        return ""
    end

    if type(value) == "string" then
        return TrimString(value)
    end

    if type(value) == "number" then
        return tostring(value)
    end

    return ""
end

local function FormatAbilityIds(value)
    if type(value) == "table" then
        local parts = {}
        for i = 1, #value do
            parts[#parts + 1] = tostring(value[i])
        end
        return table.concat(parts, ", ")
    end

    if value == nil then
        return ""
    end

    return tostring(value)
end

local function BuildCatalogSetChoices()
    local catalog = PCT.Data and PCT.Data.Sets
    local choices = {}

    if type(catalog) ~= "table" then
        return choices
    end

    for setName, entry in pairs(catalog) do
        if type(setName) == "string" and setName ~= "" and type(entry) == "table" and (entry.procType == nil or entry.procType == "set") then
            choices[#choices + 1] = setName
        end
    end

    table.sort(choices)
    return choices
end

local function BuildEquippedListedChoices(results)
    local choices = {}
    local seen = {}

    local function AddEntry(setName, suffix)
        if type(setName) ~= "string" or setName == "" or seen[setName] then
            return
        end

        seen[setName] = true
        choices[#choices + 1] = suffix ~= nil and (setName .. suffix) or setName
    end

    if type(results) ~= "table" then
        return choices
    end

    if type(results.found) == "table" then
        for _, entry in ipairs(results.found) do
            AddEntry(entry.setName, " [catalog]")
        end
    end

    if type(results.noProc) == "table" then
        for _, entry in ipairs(results.noProc) do
            AddEntry(entry.setName, " [listed-no-proc]")
        end
    end

    if type(results.unknown) == "table" then
        for _, entry in ipairs(results.unknown) do
            AddEntry(entry.setName, " [unknown]")
        end
    end

    table.sort(choices)
    return choices
end

local function ExtractChoiceSetName(choice)
    local text = TrimString(choice)
    if text == "" then
        return ""
    end

    local baseName = text:match("^(.-)%s+%[[^%]]+%]$")
    return TrimString(baseName or text)
end

local function ReplaceListContents(target, source)
    for i = #target, 1, -1 do
        target[i] = nil
    end

    for i = 1, #source do
        target[i] = source[i]
    end
end

local function ParseAbilityIds(value)
    local text = TrimString(value)
    if text == "" then
        return nil, "At least one ability ID is required."
    end

    local ids = {}
    local seen = {}
    for token in string.gmatch(text, "[^,%s]+") do
        local abilityId = SafeId(token)
        if abilityId <= 0 then
            return nil, string.format("Invalid ability ID '%s'.", tostring(token))
        end

        if not seen[abilityId] then
            ids[#ids + 1] = abilityId
            seen[abilityId] = true
        end
    end

    if #ids == 0 then
        return nil, "At least one ability ID is required."
    end

    if #ids == 1 then
        return ids[1]
    end

    return ids
end

local function NormalizeAbilityIdField(value)
    if type(value) == "table" then
        local ids = {}
        local seen = {}

        for i = 1, #value do
            local id = SafeId(value[i])
            if id > 0 and not seen[id] then
                ids[#ids + 1] = id
                seen[id] = true
            end
        end

        if #ids == 0 then
            return nil
        end

        if #ids == 1 then
            return ids[1]
        end

        return ids
    end

    local id = SafeId(value)
    if id <= 0 then
        return nil
    end

    return id
end

local function NormalizeColor(value)
    local text = TrimString(value)
    if text == "" then
        return "3A97CF"
    end

    text = text:gsub("#", ""):upper()
    if not text:match("^[0-9A-F]+$") then
        return nil, "Settings color must be hex only."
    end

    if #text ~= 6 and #text ~= 8 then
        return nil, "Settings color must be 6 or 8 hex characters."
    end

    return text
end

local function BuildSavedSetDefaults()
    local defaults = PCT.Defaults and PCT.Defaults.Get and PCT.Defaults.Get()
    local prefs = PCT.savedVars or {}
    local defaultSounds = (type(defaults) == "table" and type(defaults.sounds) == "table")
        and CloneTable(defaults.sounds)
        or {
            onProc  = { enabled = true, sound = "STATS_PURCHASE" },
            onReady = { enabled = true, sound = "SKILL_LINE_ADDED" },
        }

    return {
        x      = (IsStateContainer(prefs.TextureLocation) and prefs.TextureLocation.x) or 640,
        y      = (IsStateContainer(prefs.TextureLocation) and prefs.TextureLocation.y) or 300,
        labelx = (IsStateContainer(prefs.LabelLocation) and prefs.LabelLocation.x) or 600,
        labely = (IsStateContainer(prefs.LabelLocation) and prefs.LabelLocation.y) or 300,
        size   = prefs.size or 64,
        sounds = defaultSounds,
    }
end

local function EnsureDefaultSet(setKey)
    local defaults = PCT.Defaults and PCT.Defaults.Get and PCT.Defaults.Get()
    if type(defaults) ~= "table" or type(defaults.sets) ~= "table" then
        return nil
    end

    if type(defaults.sets[setKey]) ~= "table" then
        defaults.sets[setKey] = BuildSavedSetDefaults()
    end

    return defaults.sets[setKey]
end

local function EnsureCharacterSetState(setKey)
    local _, character = GetStateTables()

    if not IsStateContainer(character.set) then
        character.set = {}
    end

    if type(setKey) == "string" and setKey ~= "" and character.set[setKey] == nil then
        -- New sets added after SavedVars are loaded should still get a default enabled state.
        character.set[setKey] = true
    end
end

local function EnsureCustomSetStore()
    local savedVars = GetStateTables()

    if not IsStateContainer(savedVars.customSetData) then
        savedVars.customSetData = {}
    end

    return savedVars.customSetData
end

local function SaveCustomSetToSavedVars(setKey, entry)
    local store = EnsureCustomSetStore()
    if not IsStateContainer(store) or type(entry) ~= "table" then
        return
    end

    local normalizedId = NormalizeAbilityIdField(entry.id)
    if normalizedId == nil then
        return
    end

    store[setKey] = {
        procType = "set",
        event = NormalizeInteger(entry.event) or EVENT_COMBAT_EVENT,
        description = entry.description,
        settingsColor = entry.settingsColor,
        id = normalizedId,
        result = NormalizeInteger(entry.result),
        cooldownDurationMs = NormalizeInteger(entry.cooldownDurationMs) or 0,
        procDelayMs = NormalizeInteger(entry.procDelayMs) or 0,
        texture = entry.texture,
        showFrame = entry.showFrame ~= false,
        userProc = entry.userProc == true or nil,
        customRegistered = true,
    }
end

local function IsSetCurrentlyEquipped(setName)
    if type(setName) ~= "string" or setName == "" then
        return false
    end

    for _, slot in ipairs(WORN_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, slot, LINK_STYLE_BRACKETS)
        if itemLink and itemLink ~= "" then
            local hasSet, equippedSetName = GetItemLinkSetInfo(itemLink)
            if hasSet and equippedSetName == setName then
                return true
            end
        end
    end

    return false
end

local function MoveSavedSetKey(oldKey, newKey)
    if oldKey == newKey or oldKey == nil or newKey == nil or oldKey == "" or newKey == "" then
        return
    end

    local prefs = PCT.savedVars
    if IsStateContainer(prefs) and IsStateContainer(prefs.sets) and prefs.sets[oldKey] ~= nil then
        prefs.sets[newKey] = prefs.sets[oldKey]
        prefs.sets[oldKey] = nil
    end

    if IsStateContainer(prefs) and IsStateContainer(prefs.customSetData) and prefs.customSetData[oldKey] ~= nil then
        prefs.customSetData[newKey] = prefs.customSetData[oldKey]
        prefs.customSetData[oldKey] = nil
    end

    local defaults = PCT.Defaults and PCT.Defaults.Get and PCT.Defaults.Get()
    if type(defaults) == "table" and type(defaults.sets) == "table" and defaults.sets[oldKey] ~= nil then
        defaults.sets[newKey] = defaults.sets[oldKey]
        defaults.sets[oldKey] = nil
    end

    local _, character = GetStateTables()
    if IsStateContainer(character.set) and character.set[oldKey] ~= nil then
        character.set[newKey] = character.set[oldKey]
        character.set[oldKey] = nil
    end
end

local function UnregisterTrackingForEntry(setKey, setData)
    if type(setData) ~= "table" or type(EM) ~= "table" or setKey == nil or setKey == "" then
        return
    end

    EM:UnregisterForUpdate((PCT.name or "PvPCooldownTracker") .. setKey .. "Count")

    local eventCode = setData.event or EVENT_COMBAT_EVENT
    if type(setData.id) == "table" then
        for i = 1, #setData.id do
            EM:UnregisterForEvent((PCT.name or "PvPCooldownTracker") .. "_" .. tostring(setData.id[i]), eventCode)
        end
    elseif setData.id ~= nil then
        EM:UnregisterForEvent((PCT.name or "PvPCooldownTracker") .. "_" .. tostring(setData.id), eventCode)
    end
end

local function LoadDraftFromEntry(draft, setKey, entry)
    local procDelayMs = 0
    if entry and entry.procDelayMs ~= nil then
        procDelayMs = tonumber(entry.procDelayMs) or 0
    elseif entry and entry.customRegistered and tonumber(entry.timeOfProc) and tonumber(entry.timeOfProc) >= 0 and tonumber(entry.timeOfProc) <= 600000 then
        -- Backward compatibility for older custom entries that stored delay in timeOfProc.
        procDelayMs = tonumber(entry.timeOfProc) or 0
    end

    draft.originalSetName = setKey or ""
    draft.setName = setKey or ""
    draft.abilityIds = FormatAbilityIds(entry and entry.id)
    draft.cooldownMs = (entry and entry.cooldownDurationMs ~= nil) and tostring(entry.cooldownDurationMs) or ""
    draft.timeOfProcMs = tostring(procDelayMs)
    draft.resultCode = (entry and entry.result ~= nil) and tostring(entry.result) or ""
    draft.eventCode = (entry and entry.event ~= nil) and tostring(entry.event) or tostring(EVENT_COMBAT_EVENT)
    draft.texture = (entry and entry.texture) or ""
    draft.description = (entry and entry.description) or ""
    draft.settingsColor = (entry and entry.settingsColor) or "3A97CF"
    draft.showFrame = entry == nil or entry.showFrame ~= false
end

-- Returns a deduplicated list of { setName, numEquipped, maxEquipped } for all
-- items currently in BAG_WORN that belong to an item set.
local function GetEquippedSetNames()
    local seen    = {}
    local results = {}

    for _, slot in ipairs(WORN_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, slot, LINK_STYLE_BRACKETS)
        if itemLink and itemLink ~= "" then
            local hasSet, setName, _, numEquipped, maxEquipped = GetItemLinkSetInfo(itemLink)
            if hasSet and type(setName) == "string" and setName ~= "" and not seen[setName] then
                seen[setName] = true
                results[#results + 1] = {
                    setName     = setName,
                    numEquipped = numEquipped or 0,
                    maxEquipped = maxEquipped or 0,
                }
            end
        end
    end

    return results
end

-- Ensures a set that already exists in Data.Sets has a valid savedVars.sets
-- entry (position, size, sounds).  Returns true if successful.
local function EnsureInSavedVars(setKey)
    local catalog = PCT.Data and PCT.Data.Sets
    if not catalog or not catalog[setKey] then return false end

    local prefs = PCT.savedVars
    if not IsStateContainer(prefs) or not IsStateContainer(prefs.sets) then return false end

    if IsStateContainer(prefs.sets[setKey]) then return true end  -- already present

    local defaultSet = EnsureDefaultSet(setKey)

    if type(defaultSet) == "table" then
        prefs.sets[setKey] = CloneTable(defaultSet)
    else
        prefs.sets[setKey] = BuildSavedSetDefaults()
    end

    return true
end

-- -----------------------------------------------------------------------------
-- Public: Scan
-- Matches equipped sets against the proc catalog.  Side-effects:
--   • Any matched set with valid proc data is registered into savedVars.
--   • The result table is cached in PCT.EquippedSets.lastScanResults.
-- Returns { found, noProc, unknown }
-- -----------------------------------------------------------------------------
function PCT.EquippedSets.Scan()
    local equippedSets = GetEquippedSetNames()
    local catalog      = (PCT.Data and PCT.Data.Sets) or {}

    local found   = {}   -- in catalog, has proc id + cooldown
    local noProc  = {}   -- in catalog, but no usable proc data
    local unknown = {}   -- not in catalog at all

    for _, info in ipairs(equippedSets) do
        local name    = info.setName
        local setData = catalog[name]

        if setData then
            -- Resolve primary ability ID (id may be number or array).
            local primaryId = 0
            if type(setData.id) == "table" then
                primaryId = SafeId(setData.id[1])
            else
                primaryId = SafeId(setData.id)
            end

            local hasCooldown = (setData.cooldownDurationMs and setData.cooldownDurationMs > 0)

            if primaryId > 0 and hasCooldown then
                found[#found + 1] = {
                    setName            = name,
                    numEquipped        = info.numEquipped,
                    maxEquipped        = info.maxEquipped,
                    id                 = setData.id,           -- number or array
                    cooldownDurationMs = setData.cooldownDurationMs,
                    result             = setData.result,
                    procType           = setData.procType,
                    texture            = setData.texture,
                    description        = setData.description or "",
                }
                EnsureInSavedVars(name)
                EnsureCharacterSetState(name)
            else
                noProc[#noProc + 1] = {
                    setName     = name,
                    numEquipped = info.numEquipped,
                }
            end
        else
            unknown[#unknown + 1] = {
                setName     = name,
                numEquipped = info.numEquipped,
            }
        end
    end

    PCT.EquippedSets.lastScanResults = {
        found   = found,
        noProc  = noProc,
        unknown = unknown,
    }

    return PCT.EquippedSets.lastScanResults
end

-- -----------------------------------------------------------------------------
-- Public: RegisterCustomEntry
-- Adds a brand-new set entry into Data.Sets + savedVars for sets not already
-- in the catalog.  Immediately wires up event tracking.
-- Parameters:
--   setName     (string)  – exact display name
--   abilityId   (number)  – proc ability ID
--   cooldownMs  (number)  – cooldown in milliseconds
--   resultCode  (number?) – ACTION_RESULT_* value; defaults to 2240 (EFFECT_GAINED)
-- Returns: ok (bool), message (string)
-- -----------------------------------------------------------------------------
function PCT.EquippedSets.RegisterCustomEntry(setName, abilityId, cooldownMs, resultCode)
    if type(setName) ~= "string" or setName == "" then
        return false, "Set name is required."
    end

    local safeId       = SafeId(abilityId)
    local safeCooldown = NormalizeInteger(cooldownMs) or 0

    if safeId <= 0 then
        return false, "A valid ability ID (> 0) is required."
    end
    if safeCooldown <= 0 then
        return false, "Cooldown must be > 0 milliseconds."
    end

    local catalog = PCT.Data and PCT.Data.Sets
    if not catalog then
        return false, "Data.Sets is not available."
    end

    -- Already catalogued – just make sure savedVars has it.
    if catalog[setName] then
        EnsureInSavedVars(setName)
        return true, string.format("'%s' already in catalog; savedVars updated.", setName)
    end

    return PCT.EquippedSets.SaveSetData({
        originalSetName = setName,
        setName = setName,
        abilityIds = tonumber(safeId),
        cooldownMs = tonumber(safeCooldown),
        resultCode = tonumber(resultCode) or 2240,
        eventCode = tonumber(EVENT_COMBAT_EVENT),
        texture = "",
        description = string.format("Custom: %s", setName),
        settingsColor = "3A97CF",
        showFrame = true,
    })
end

function PCT.EquippedSets.SaveSetData(draft)
    local catalog = PCT.Data and PCT.Data.Sets
    if type(catalog) ~= "table" then
        return false, "Data.Sets is not available."
    end

    local newSetName = TrimString(draft and draft.setName)
    if newSetName == "" then
        return false, "Set name is required."
    end

    local originalSetName = TrimString(draft and draft.originalSetName)
    if originalSetName == "" then
        originalSetName = newSetName
    end

    if originalSetName ~= newSetName and catalog[newSetName] ~= nil then
        return false, string.format("'%s' already exists in the catalog.", newSetName)
    end

    local abilityIds, idError = ParseAbilityIds(draft and draft.abilityIds)
    if abilityIds == nil then
        return false, idError
    end

    local cooldownMs = NormalizeInteger(draft and draft.cooldownMs)
    if cooldownMs == nil or cooldownMs <= 0 then
        return false, "Cooldown must be greater than 0 milliseconds."
    end

    local resultCodeText = draft and draft.resultCode
    local resultCode = nil
    if resultCodeText ~= "" then
        resultCode = NormalizeInteger(resultCodeText)
        if resultCode == nil then
            return false, "Result code must be numeric."
        end
    end

    local eventCodeText = TrimString(draft and draft.eventCode)
    local eventCode = NormalizeInteger(eventCodeText)
    if eventCodeText == "" then
        eventCode = EVENT_COMBAT_EVENT
    elseif eventCode == nil then
        return false, "Event code must be numeric."
    end
    if eventCode == nil then
        return false, "Event code must be numeric."
    end

    local settingsColor, colorError = NormalizeColor(draft and draft.settingsColor)
    if settingsColor == nil then
        return false, colorError
    end

    local primaryId = type(abilityIds) == "table" and abilityIds[1] or abilityIds
    local texture = TrimString(draft and draft.texture)
    if texture == "" then
        texture = GetAbilityIcon(primaryId) or ""
    end

    local existingEntry = catalog[originalSetName]
    local existingProcDelayMs = NormalizeInteger(existingEntry and existingEntry.procDelayMs) or 0
    local timeOfProcText = TrimString(draft and draft.timeOfProcMs)
    local procDelayMs = existingProcDelayMs
    if timeOfProcText ~= "" then
        local parsedTimeOfProc = NormalizeInteger(timeOfProcText)
        if parsedTimeOfProc == nil or parsedTimeOfProc < 0 then
            return false, "Proc delay must be a non-negative number."
        end
        procDelayMs = parsedTimeOfProc
    end

    local existingCopy = CloneTable(existingEntry)
    local shouldEnable = existingCopy and existingCopy.enabled == true
    local _, character = GetStateTables()
    local manuallyEnabled = IsStateContainer(character.set)
        and character.set[originalSetName] == true

    if existingCopy then
        UnregisterTrackingForEntry(originalSetName, existingCopy)
    end

    local newEntry = existingCopy or {}
    newEntry.procType = "set"
    newEntry.event = eventCode
    newEntry.description = TrimString(draft and draft.description)
    if newEntry.description == "" then
        newEntry.description = string.format("Custom: %s", newSetName)
    end
    newEntry.settingsColor = settingsColor
    newEntry.id = abilityIds
    newEntry.enabled = existingCopy and existingCopy.enabled or false
    newEntry.result = tonumber(resultCode)
    newEntry.cooldownDurationMs = tonumber(cooldownMs)
    newEntry.onCooldown = existingCopy and existingCopy.onCooldown or false
    newEntry.timeOfProc = NormalizeInteger(existingCopy and existingCopy.timeOfProc) or 0
    newEntry.procDelayMs = procDelayMs
    newEntry.texture = texture ~= "" and texture or nil
    newEntry.showFrame = draft == nil or draft.showFrame ~= false
    newEntry.customRegistered = true
    if draft ~= nil and draft.userProc == true then
        -- Added from the recent-procs list: tracked regardless of equipped gear.
        newEntry.userProc = true
    end

    if originalSetName ~= newSetName then
        catalog[originalSetName] = nil
        MoveSavedSetKey(originalSetName, newSetName)
    end

    catalog[newSetName] = newEntry
    SaveCustomSetToSavedVars(newSetName, newEntry)
    EnsureDefaultSet(newSetName)
    EnsureInSavedVars(newSetName)
    EnsureCharacterSetState(newSetName)

    local characterState = IsStateContainer(character.set) and character.set[newSetName]
    local isManuallyDisabled = characterState == false
    local isEquippedNow = IsSetCurrentlyEquipped(newSetName)

    if PCT.Tracking and type(PCT.Tracking.EnableTrackingForSet) == "function" and isEquippedNow and not isManuallyDisabled then
        PCT.Tracking.EnableTrackingForSet(newSetName, true)
    end

    if PCT.Tracking and type(PCT.Tracking.EnableTrackingForSet) == "function" and (shouldEnable or manuallyEnabled) then
        PCT.Tracking.EnableTrackingForSet(newSetName, true)
    end

    local idText = FormatAbilityIds(newEntry.id)
    return true, string.format("Saved '%s' - id=%s, cooldown=%dms, procDelay=%dms, event=%d, result=%s",
        newSetName,
        idText,
        tonumber(cooldownMs),
        tonumber(procDelayMs),
        tonumber(eventCode),
        newEntry.result ~= nil and tostring(newEntry.result) or "none")
end

function PCT.EquippedSets.RestoreCustomSets()
    local catalog = PCT.Data and PCT.Data.Sets
    local store = EnsureCustomSetStore()
    if type(catalog) ~= "table" or not IsStateContainer(store) then
        return 0
    end

    local restored = 0

    for setName, saved in pairs(store) do
        if type(setName) == "string" and setName ~= "" and type(saved) == "table" then
            local id = NormalizeAbilityIdField(saved.id)
            local cooldown = NormalizeInteger(saved.cooldownDurationMs) or 0
            local eventCode = NormalizeInteger(saved.event) or EVENT_COMBAT_EVENT
            local procDelayMs = NormalizeInteger(saved.procDelayMs) or 0

            if id ~= nil and cooldown > 0 then
                local existing = catalog[setName]
                local restoredEntry = type(existing) == "table" and CloneTable(existing) or {}

                restoredEntry.procType = "set"
                restoredEntry.event = tonumber(eventCode)
                restoredEntry.description = saved.description or restoredEntry.description or string.format("Custom: %s", setName)
                restoredEntry.settingsColor = saved.settingsColor or restoredEntry.settingsColor or "3A97CF"
                restoredEntry.id = id
                restoredEntry.result = tonumber(NormalizeInteger(saved.result))
                restoredEntry.cooldownDurationMs = tonumber(cooldown)
                restoredEntry.procDelayMs = tonumber(procDelayMs)
                restoredEntry.texture = saved.texture or restoredEntry.texture or (GetAbilityIcon(type(id) == "table" and id[1] or id) or "")
                restoredEntry.showFrame = saved.showFrame ~= false
                restoredEntry.enabled = existing and existing.enabled or false
                restoredEntry.onCooldown = existing and existing.onCooldown or false
                restoredEntry.timeOfProc = tonumber(NormalizeInteger(existing and existing.timeOfProc)) or 0
                restoredEntry.customRegistered = true
                restoredEntry.userProc = saved.userProc == true or nil

                catalog[setName] = restoredEntry
                EnsureDefaultSet(setName)
                EnsureInSavedVars(setName)
                EnsureCharacterSetState(setName)

                restored = restored + 1
            end
        end
    end

    return restored
end

-- -----------------------------------------------------------------------------
-- Public: BuildLAMControls
-- Returns a flat list of LAM control definitions to be inserted into the
-- Settings.Init optionsTable.
-- -----------------------------------------------------------------------------
function PCT.EquippedSets.BuildLAMControls()
    local draft = {
        originalSetName = "",
        setName    = "",
        abilityIds = "",
        cooldownMs = "",
        timeOfProcMs = "0",
        resultCode = "2240",
        eventCode  = tostring(EVENT_COMBAT_EVENT),
        texture    = "",
        description = "",
        settingsColor = "3A97CF",
        showFrame = true,
        scanText   = "Press 'Scan Equipped Sets' to detect what you have equipped.",
        statusText = "Use 'Load Set Data' to edit an existing catalog entry, or type a new set and save it.",
    }
    local catalogChoices = BuildCatalogSetChoices()
    local selectedCatalogSet = ""
    local equippedChoices = {}
    local selectedEquippedSet = ""
    local SetStatus

    -- LibAddonMenu only reads a dropdown's choices when it is built, so push
    -- list changes to the live control (if the panel has been opened already).
    local function PushChoices(reference, choices)
        if PCT.Settings and type(PCT.Settings.PushDropdownChoices) == "function" then
            PCT.Settings.PushDropdownChoices(reference, choices)
        end
    end

    local function RefreshCatalogChoices(preferredSetName)
        ReplaceListContents(catalogChoices, BuildCatalogSetChoices())
        PushChoices("PvPCooldownTracker_CatalogDropdown", catalogChoices)

        if preferredSetName and preferredSetName ~= "" then
            selectedCatalogSet = preferredSetName
            return
        end

        if selectedCatalogSet ~= "" and PCT.Data and PCT.Data.Sets and PCT.Data.Sets[selectedCatalogSet] then
            return
        end

        selectedCatalogSet = catalogChoices[1] or ""
    end

    RefreshCatalogChoices()

    local function RefreshEquippedChoices(preferredSetName)
        ReplaceListContents(equippedChoices, BuildEquippedListedChoices(PCT.EquippedSets.lastScanResults))
        PushChoices("PvPCooldownTracker_EquippedDropdown", equippedChoices)

        if preferredSetName and preferredSetName ~= "" then
            for i = 1, #equippedChoices do
                if ExtractChoiceSetName(equippedChoices[i]) == preferredSetName then
                    selectedEquippedSet = equippedChoices[i]
                    return
                end
            end
        end

        if selectedEquippedSet ~= "" then
            local existingName = ExtractChoiceSetName(selectedEquippedSet)
            for i = 1, #equippedChoices do
                if ExtractChoiceSetName(equippedChoices[i]) == existingName then
                    selectedEquippedSet = equippedChoices[i]
                    return
                end
            end
        end

        selectedEquippedSet = equippedChoices[1] or ""
    end

    local function LoadEquippedListedSet(choice)
        local setName = ExtractChoiceSetName(choice)
        if setName == "" then
            SetStatus("Run a scan first to list equipped sets.")
            return
        end

        draft.setName = setName

        if PCT.Data and PCT.Data.Sets and type(PCT.Data.Sets[setName]) == "table" then
            LoadDraftFromEntry(draft, setName, PCT.Data.Sets[setName])
            selectedCatalogSet = setName
            SetStatus(string.format("Loaded equipped set '%s' from the catalog.", setName))
        else
            draft.originalSetName = ""
            SetStatus(string.format("'%s' is equipped but not in the catalog. Fill in the fields and save to create it.", setName))
        end

        selectedEquippedSet = choice or ""
    end

    RefreshEquippedChoices()

    function SetStatus(message)
        draft.statusText = message or ""
    end

    local function LoadCurrentSet()
        local setName = TrimString(draft.setName)
        if setName == "" then
            SetStatus("Enter a set name to load.")
            return
        end

        local entry = PCT.Data and PCT.Data.Sets and PCT.Data.Sets[setName]
        if type(entry) ~= "table" then
            SetStatus(string.format("'%s' is not in the current catalog. Fill out the fields and save to create it.", setName))
            draft.originalSetName = ""
            return
        end

        LoadDraftFromEntry(draft, setName, entry)
        selectedCatalogSet = setName
        SetStatus(string.format("Loaded '%s' for editing.", setName))
    end

    local function SaveCurrentSet()
        local ok, message = PCT.EquippedSets.SaveSetData(draft)
        if ok then
            local setName = TrimString(draft.setName)
            local entry = PCT.Data and PCT.Data.Sets and PCT.Data.Sets[setName]
            if entry then
                LoadDraftFromEntry(draft, setName, entry)
            end
            RefreshCatalogChoices(setName)
            RefreshEquippedChoices(setName)
            if PCT.Settings and type(PCT.Settings.RefreshSetChoices) == "function" then
                PCT.Settings.RefreshSetChoices()
            end
        end

        SetStatus(message)
        d((PCT.prefix or "[PvPCooldownTracker] ") .. message)
    end

    local function RunScan()
        local results = PCT.EquippedSets.Scan()
        local lines   = {}

        if #results.found > 0 then
            lines[#lines + 1] = string.format("|cFFD700Proc catalog match (%d):|r", #results.found)
            for _, e in ipairs(results.found) do
                local cdSec  = string.format("%.1fs", e.cooldownDurationMs / 1000)
                local idStr  = type(e.id) == "table"
                    and table.concat(e.id, ",")
                    or tostring(e.id)
                lines[#lines + 1] = string.format(
                    "  |c7EC8E3%s|r  id=%s  cd=%s  result=%s",
                    e.setName, idStr, cdSec, tostring(e.result))
            end
        end

        if #results.noProc > 0 then
            lines[#lines + 1] = string.format("|cAAAAAASets without proc data (%d):|r", #results.noProc)
            for _, e in ipairs(results.noProc) do
                lines[#lines + 1] = "  " .. e.setName
            end
        end

        if #results.unknown > 0 then
            lines[#lines + 1] = string.format("|cFF6060Not in catalog (%d) — use manual import:|r", #results.unknown)
            for i, e in ipairs(results.unknown) do
                lines[#lines + 1] = "  " .. e.setName
                -- Pre-fill the first unknown set into the manual entry fields.
                if i == 1 and draft.setName == "" then
                    draft.setName = e.setName
                    draft.originalSetName = ""
                end
            end
        end

        if #results.found > 0 and draft.setName == "" then
            draft.setName = results.found[1].setName
            LoadCurrentSet()
        end

        RefreshEquippedChoices(#results.found > 0 and results.found[1].setName or nil)

        draft.scanText = (#lines > 0) and table.concat(lines, "\n")
            or "No equipped sets detected."

        d((PCT.prefix or "[PvPCooldownTracker] ") .. string.format(
            "Scan: %d matched, %d no proc, %d unknown.",
            #results.found, #results.noProc, #results.unknown))
    end

    return {
        {
            type  = "header",
            name  = "|c92C843Equipped Set Scanner|r",
            width = "full",
        },
        {
            type  = "description",
            text  = "Reads your equipped gear and matches item set names against the proc catalog. Matched sets are auto-registered into savedVars (cooldown, proc ID, texture).",
            width = "full",
        },
        {
            type    = "button",
            name    = "Scan Equipped Sets",
            tooltip = "Scan BAG_WORN, cross-reference the proc catalog, and register matching sets.",
            func    = RunScan,
            width   = "half",
        },
        {
            type    = "button",
            name    = "Load Set Data",
            tooltip = "Load the current set name from Data.Sets into the editor fields.",
            func    = LoadCurrentSet,
            width   = "half",
        },
        {
            type       = "dropdown",
            name       = "Catalog Sets",
            tooltip    = "Pick any tracked set from Data.Sets and load it into the editor.",
            choices    = catalogChoices,
            getFunc    = function() return selectedCatalogSet end,
            setFunc    = function(value)
                selectedCatalogSet = value or ""
                draft.setName = selectedCatalogSet
                if selectedCatalogSet ~= "" then
                    LoadCurrentSet()
                end
            end,
            scrollable = true,
            width      = "full",
            reference  = "PvPCooldownTracker_CatalogDropdown",
        },
        {
            type       = "dropdown",
            name       = "Equipped Listed Sets",
            tooltip    = "Pick a set from the latest scan results and load its data into the editor. Unknown sets will prefill the name for manual entry.",
            choices    = equippedChoices,
            getFunc    = function() return selectedEquippedSet end,
            setFunc    = function(value)
                selectedEquippedSet = value or ""
                if selectedEquippedSet ~= "" then
                    LoadEquippedListedSet(selectedEquippedSet)
                end
            end,
            scrollable = true,
            width      = "full",
            reference  = "PvPCooldownTracker_EquippedDropdown",
        },
        {
            type  = "description",
            text  = function() return draft.scanText end,
            width = "full",
        },
        {
            type   = "divider",
            width  = "full",
            height = 8,
            alpha  = 0.20,
        },
        {
            type  = "header",
            name  = "Set Data Editor",
            width = "full",
        },
        {
            type    = "description",
            text    = "Load an existing catalog entry to edit it, or enter a new set name to create one. You can edit ability IDs, cooldown, result, event, texture, description, color, and frame visibility.",
            width   = "full",
        },
        {
            type     = "editbox",
            name     = "Set Name",
            tooltip  = "Exact in-game set name, e.g. Plaguebreak",
            getFunc  = function() return draft.setName end,
            setFunc  = function(v)
                draft.setName = v
                if PCT.Data and PCT.Data.Sets and PCT.Data.Sets[v] then
                    selectedCatalogSet = v
                end
            end,
            width    = "full",
        },
        {
            type    = "editbox",
            name    = "Ability ID(s)",
            tooltip = "One or more numeric proc ability IDs. Separate multiple IDs with commas.",
            getFunc = function() return draft.abilityIds end,
            setFunc = function(v) draft.abilityIds = v end,
            width   = "half",
        },
        {
            type    = "editbox",
            name    = "Cooldown (ms)",
            tooltip = "Cooldown in milliseconds, e.g. 30000 for 30 seconds.",
            getFunc = function() return draft.cooldownMs end,
            setFunc = function(v) draft.cooldownMs = v end,
            width   = "half",
        },
        {
            type    = "editbox",
            name    = "Proc Delay (ms)",
            tooltip = "Delay applied before cooldown starts after the proc event fires. Example: 1000 delays start by 1 second.",
            getFunc = function() return draft.timeOfProcMs end,
            setFunc = function(v) draft.timeOfProcMs = v end,
            width   = "half",
        },
        {
            type    = "button",
            name    = "Set Delay To 0",
            tooltip = "Reset proc delay so cooldown starts immediately when proc event fires.",
            func    = function() draft.timeOfProcMs = "0" end,
            width   = "half",
        },
        {
            type    = "editbox",
            name    = "Result Code",
            tooltip = "Proc result value. 2240=EFFECT_GAINED (most sets), 128=POWER_ENERGIZE (sustain), 16=HEAL, 1=DAMAGE.",
            getFunc = function() return draft.resultCode end,
            setFunc = function(v) draft.resultCode = v end,
            width   = "half",
        },
        {
            type    = "editbox",
            name    = "Event Code",
            tooltip = "Usually 131102 (EVENT_COMBAT_EVENT) or 131181 (EVENT_ABILITY_COOLDOWN_UPDATED).",
            getFunc = function() return draft.eventCode end,
            setFunc = function(v) draft.eventCode = v end,
            width   = "half",
        },
        {
            type    = "checkbox",
            name    = "Show Frame",
            tooltip = "Controls whether the cooldown frame is drawn around the icon.",
            getFunc = function() return draft.showFrame end,
            setFunc = function(v) draft.showFrame = v end,
            width   = "half",
        },
        {
            type    = "editbox",
            name    = "Settings Color",
            tooltip = "Hex color used by the original data schema, e.g. 3A97CF.",
            getFunc = function() return draft.settingsColor end,
            setFunc = function(v) draft.settingsColor = v end,
            width   = "half",
        },
        {
            type    = "editbox",
            name    = "Texture Path",
            tooltip = "Optional icon texture path. Leave blank to use GetAbilityIcon() from the first ability ID.",
            getFunc = function() return draft.texture end,
            setFunc = function(v) draft.texture = v end,
            width   = "full",
        },
        {
            type    = "editbox",
            name    = "Description",
            tooltip = "Optional description for the catalog entry.",
            getFunc = function() return draft.description end,
            setFunc = function(v) draft.description = v end,
            isMultiline = true,
            width   = "full",
        },
        {
            type    = "button",
            name    = "Save Set Data",
            tooltip = "Create a new catalog entry or update the currently loaded one.",
            func    = SaveCurrentSet,
            width = "half",
        },
        {
            type  = "description",
            text  = function() return draft.statusText end,
            width = "full",
        },
    }
end
