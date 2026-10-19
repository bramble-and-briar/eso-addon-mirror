LibAbilityLogger = LibAbilityLogger or {}
local LAL = LibAbilityLogger

LAL.name = "LibAbilityLogger"
LAL.version = "3.0.0"
LAL.debug = false

local CATEGORY_COMBAT = "combat"
local CATEGORY_EFFECT = "effect"

local SCOPES = { all = true, self = true, incoming = true }

-- Saved between sessions. Declared as a SavedVariable in LibAbilityLogger.addon.
local DEFAULT_SETTINGS = {
    combat = true,
    effects = true,
    scope = "all",
    minHitValue = 0,
    historySize = 200,
}

LibAbilityLogger_SavedVars = LibAbilityLogger_SavedVars or {}
for key, value in pairs(DEFAULT_SETTINGS) do
    if LibAbilityLogger_SavedVars[key] == nil then
        LibAbilityLogger_SavedVars[key] = value
    end
end
LibAbilityLogger_SavedVars.ignored = LibAbilityLogger_SavedVars.ignored or {}
LAL.settings = LibAbilityLogger_SavedVars

local history = {}
local stats = {}
local listeners = {}

local function NonEmpty(value, fallback)
    if value == nil or value == "" then
        return fallback
    end
    return value
end

local function EnumString(enumName, index, fallback)
    local stringId = _G[enumName]
    if stringId == nil or index == nil then
        return fallback
    end
    return NonEmpty(GetString(stringId, index), fallback)
end

-- Skips constants that a given game build doesn't define, instead of erroring.
local function MapConstant(map, constant, value)
    if constant ~= nil then
        map[constant] = value
    end
end

local RESULT_INFO = {}
local function AddResult(constant, label, kind, critical)
    MapConstant(RESULT_INFO, constant, { label = label, kind = kind, critical = critical or false })
end
AddResult(ACTION_RESULT_DODGE, "dodged", "other")
AddResult(ACTION_RESULT_BLOCKED, "blocked", "other")
AddResult(ACTION_RESULT_PARRIED, "parried", "other")
AddResult(ACTION_RESULT_ABSORBED, "absorbed", "other")
AddResult(ACTION_RESULT_HEAL_ABSORBED, "absorbed", "other")
AddResult(ACTION_RESULT_MISS, "miss", "other")
AddResult(ACTION_RESULT_IMMUNE, "immune", "other")
AddResult(ACTION_RESULT_RESIST, "resisted", "other")
AddResult(ACTION_RESULT_PARTIAL_RESIST, "resisted", "other")
AddResult(ACTION_RESULT_INTERRUPT, "interrupted", "other")
AddResult(ACTION_RESULT_KILLED_BY_SUBZONE, "died", "other")
AddResult(ACTION_RESULT_DIED, "died", "other")
AddResult(ACTION_RESULT_QUEUED, "queued", "other")
AddResult(ACTION_RESULT_POWER_ENERGIZE, "energized", "other")
AddResult(ACTION_RESULT_POWER_DRAIN, "drained", "other")
AddResult(ACTION_RESULT_EFFECT_GAINED, "effect gained", "effect")
AddResult(ACTION_RESULT_EFFECT_GAINED_DURATION, "effect gained", "effect")
AddResult(ACTION_RESULT_EFFECT_FADED, "effect faded", "effect")
AddResult(ACTION_RESULT_DAMAGE, "damage", "damage")
AddResult(ACTION_RESULT_CRITICAL_DAMAGE, "damage", "damage", true)
AddResult(ACTION_RESULT_DOT_TICK, "damage over time", "damage")
AddResult(ACTION_RESULT_DOT_TICK_CRITICAL, "damage over time", "damage", true)
AddResult(ACTION_RESULT_HEAL, "healing", "healing")
AddResult(ACTION_RESULT_CRITICAL_HEAL, "healing", "healing", true)
AddResult(ACTION_RESULT_HOT_TICK, "healing over time", "healing")
AddResult(ACTION_RESULT_HOT_TICK_CRITICAL, "healing over time", "healing", true)

local EFFECT_CHANGE_LABELS = {}
MapConstant(EFFECT_CHANGE_LABELS, EFFECT_RESULT_GAINED, "gained")
MapConstant(EFFECT_CHANGE_LABELS, EFFECT_RESULT_UPDATED, "updated")
MapConstant(EFFECT_CHANGE_LABELS, EFFECT_RESULT_FADED, "faded")

local function Say(fmt, ...)
    d(string.format("[%s] %s", LAL.name, string.format(fmt, ...)))
end

local function IsSelfSource(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
end

local function PassesScope(scope, sourceType, targetType)
    if scope == "self" then
        return IsSelfSource(sourceType)
    elseif scope == "incoming" then
        return targetType == COMBAT_UNIT_TYPE_PLAYER
    end
    return true
end

local function SourceLabel(name, unitType)
    if unitType == COMBAT_UNIT_TYPE_PLAYER then
        return "You"
    end
    name = NonEmpty(name, "Unknown Source")
    if unitType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return name .. " (pet)"
    end
    return name
end

local function RecordStats(entry)
    if not IsSelfSource(entry.sourceType) then return end
    if entry.kind ~= "damage" and entry.kind ~= "healing" then return end

    local record = stats[entry.abilityId]
    if not record then
        record = { abilityId = entry.abilityId, name = entry.abilityName, damage = 0, damageHits = 0, healing = 0, healingHits = 0 }
        stats[entry.abilityId] = record
    end
    if entry.kind == "damage" then
        record.damage = record.damage + entry.value
        record.damageHits = record.damageHits + 1
    else
        record.healing = record.healing + entry.value
        record.healingHits = record.healingHits + 1
    end
end

local function Dispatch(entry)
    entry.time = GetGameTimeMilliseconds()
    history[#history + 1] = entry
    local limit = tonumber(LAL.settings.historySize) or 200
    while #history > limit do
        table.remove(history, 1)
    end
    RecordStats(entry)
    LAL:Print("[%s] %s", entry.category, entry.message)
    for _, callback in ipairs(listeners) do
        callback(entry)
    end
end

function LAL:Print(...)
    if self.debug then
        d(string.format("[%s] %s", self.name, string.format(...)))
    end
end

function LAL:EnableDebug()
    self.debug = true
    self:Print("Debug enabled")
end

function LAL:DisableDebug()
    self:Print("Debug disabled")
    self.debug = false
end

function LAL:IsDebugEnabled()
    return self.debug
end

function LAL:ToggleDebug()
    if self.debug then
        self:DisableDebug()
    else
        self:EnableDebug()
    end
end

-- callback(entry) runs for each captured entry. Entries are only captured while debug is on.
function LAL:RegisterListener(callback)
    if type(callback) == "function" then
        listeners[#listeners + 1] = callback
    end
end

function LAL:UnregisterListener(callback)
    for index, registered in ipairs(listeners) do
        if registered == callback then
            table.remove(listeners, index)
            return
        end
    end
end

function LAL:GetRecent(count)
    local recent = {}
    for index = math.max(1, #history - (count or 20) + 1), #history do
        recent[#recent + 1] = history[index]
    end
    return recent
end

function LAL:GetStats()
    local sorted = {}
    for _, record in pairs(stats) do
        sorted[#sorted + 1] = record
    end
    table.sort(sorted, function(a, b)
        return (a.damage + a.healing) > (b.damage + b.healing)
    end)
    return sorted
end

function LAL:ResetSession()
    history = {}
    stats = {}
end

local function ShowHelp()
    Say("Commands:")
    Say("/lab - Toggle logging on/off")
    Say("/lab on | off | status - Turn logging on or off, or show current settings")
    Say("/lab combat on|off - Log combat events")
    Say("/lab effects on|off - Log buff and debuff events")
    Say("/lab scope all|self|incoming - self: you or your pet as source, incoming: you as target")
    Say("/lab minhit <value> - Hide combat events below this value")
    Say("/lab ignore <abilityId> | unignore <abilityId>")
    Say("/lab stats [count] - Damage and healing you dealt, per ability")
    Say("/lab recent [count] - Show recent logged entries")
    Say("/lab clear - Clear recent entries and stats")
    Say("/labhelp - Show this help message")
end

local function ShowStatus()
    local settings = LAL.settings
    local ignoredCount = 0
    for _ in pairs(settings.ignored) do
        ignoredCount = ignoredCount + 1
    end
    Say("Logging: %s | combat: %s | effects: %s | scope: %s", LAL.debug and "on" or "off", settings.combat and "on" or "off", settings.effects and "on" or "off", settings.scope)
    Say("Min hit value: %s | ignored abilities: %d | history size: %s", tostring(settings.minHitValue), ignoredCount, tostring(settings.historySize))
end

local function ParseOnOff(value)
    if value == "on" then
        return true
    elseif value == "off" then
        return false
    end
    return nil
end

local function HandleSlashCommand(args)
    local command, rest = string.match(args or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    rest = rest or ""

    if command == "" then
        LAL:ToggleDebug()
    elseif command == "on" then
        LAL:EnableDebug()
    elseif command == "off" then
        LAL:DisableDebug()
    elseif command == "status" then
        ShowStatus()
    elseif command == "combat" or command == "effects" then
        local enabled = ParseOnOff(string.lower(rest))
        if enabled == nil then
            Say("Usage: /lab %s on|off", command)
        else
            LAL.settings[command] = enabled
            Say("%s logging %s", command, enabled and "enabled" or "disabled")
        end
    elseif command == "scope" then
        local scope = string.lower(rest)
        if SCOPES[scope] then
            LAL.settings.scope = scope
            Say("Scope set to %s", scope)
        else
            Say("Usage: /lab scope all|self|incoming")
        end
    elseif command == "minhit" then
        local value = tonumber(rest)
        if value and value >= 0 then
            LAL.settings.minHitValue = value
            Say("Minimum hit value set to %s", tostring(value))
        else
            Say("Usage: /lab minhit <value>")
        end
    elseif command == "ignore" or command == "unignore" then
        local abilityId = tonumber(rest)
        if not abilityId then
            Say("Usage: /lab %s <abilityId>", command)
        elseif command == "ignore" then
            LAL.settings.ignored[abilityId] = true
            Say("Ignoring %s (%d)", NonEmpty(GetAbilityName(abilityId), "unknown ability"), abilityId)
        else
            LAL.settings.ignored[abilityId] = nil
            Say("No longer ignoring %d", abilityId)
        end
    elseif command == "stats" then
        local records = LAL:GetStats()
        if #records == 0 then
            Say("No damage or healing recorded yet. Turn logging on with /lab on.")
        end
        for index = 1, math.min(tonumber(rest) or 10, #records) do
            local record = records[index]
            Say("%s (%d): damage %d in %d hits, healing %d in %d hits", NonEmpty(record.name, "Unknown Ability"), record.abilityId, record.damage, record.damageHits, record.healing, record.healingHits)
        end
    elseif command == "recent" then
        local recent = LAL:GetRecent(tonumber(rest) or 10)
        if #recent == 0 then
            Say("No entries recorded yet.")
        end
        for _, entry in ipairs(recent) do
            Say("[%s] %s", entry.category, entry.message)
        end
    elseif command == "clear" then
        LAL:ResetSession()
        Say("Recent entries and stats cleared.")
    elseif command == "help" then
        ShowHelp()
    else
        Say("Unknown command '%s'. Type /labhelp for a list of commands.", command)
    end
end

SLASH_COMMANDS["/lab"] = HandleSlashCommand
SLASH_COMMANDS["/labhelp"] = ShowHelp

EVENT_MANAGER:RegisterForEvent(LAL.name, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == LAL.name then
        LAL:Print("Loaded version %s /labhelp for help", LAL.version)
        EVENT_MANAGER:UnregisterForEvent(LAL.name, EVENT_ADD_ON_LOADED)
    end
end)
local function OnEffectChanged(...)
    if not LAL.debug or not LAL.settings.effects then return end
    local _, changeType, effectSlot, effectName, unitTag, _, _, stackCount, _, _, _, _, _, unitName, _, abilityId = ...
    -- Effect events carry no source, so non-"all" scopes can only be matched against the player.
    if LAL.settings.scope ~= "all" and unitTag ~= "player" then return end
    abilityId = abilityId or 0
    if LAL.settings.ignored[abilityId] then return end

    local changeLabel = EFFECT_CHANGE_LABELS[changeType] or tostring(changeType)
    local targetLabel = NonEmpty(unitName, NonEmpty(GetUnitName(unitTag), "Unknown Unit"))
    effectName = NonEmpty(effectName, "Unknown Effect")
    local message = string.format("Effect '%s' (%d) %s on %s [%s], slot %d", effectName, abilityId, changeLabel, targetLabel, tostring(unitTag), effectSlot or 0)
    if stackCount and stackCount > 1 then
        message = message .. string.format(", stacks %d", stackCount)
    end

    Dispatch({
        category = CATEGORY_EFFECT,
        kind = "effect",
        abilityId = abilityId,
        abilityName = effectName,
        targetName = targetLabel,
        result = changeLabel,
        message = message,
    })
end

EVENT_MANAGER:RegisterForEvent(LAL.name, EVENT_EFFECT_CHANGED, OnEffectChanged)
local function OnCombatEvent(...)
    if not LAL.debug or not LAL.settings.combat then return end
    local _, actionResult, _, eventAbilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, powerType, _, _, _, _, abilityId = ...
    abilityId = abilityId or 0
    if LAL.settings.ignored[abilityId] then return end
    if not PassesScope(LAL.settings.scope, sourceType, targetType) then return end
    hitValue = hitValue or 0
    if hitValue < LAL.settings.minHitValue then return end

    local info = RESULT_INFO[actionResult]
    local resultLabel = info and info.label or EnumString("SI_COMBATACTIONRESULT", actionResult, tostring(actionResult))
    local kind = info and info.kind or "other"
    local critical = info and info.critical or false
    local abilityName = NonEmpty(GetAbilityName(abilityId), NonEmpty(eventAbilityName, "Unknown Ability"))
    local sourceLabel = SourceLabel(sourceName, sourceType)
    local targetLabel = NonEmpty(targetName, "Unknown Target")

    local details = resultLabel
    if hitValue > 0 then
        details = string.format("%s %d", resultLabel, hitValue)
    end
    if critical then
        details = details .. " (critical)"
    end

    local costText = ""
    if IsSelfSource(sourceType) then
        local cost = GetAbilityCost(abilityId)
        if cost and cost > 0 then
            costText = string.format(", cost %d %s", cost, EnumString("SI_COMBATMECHANICTYPE", powerType, "Unknown"))
        end
    end

    Dispatch({
        category = CATEGORY_COMBAT,
        kind = kind,
        abilityId = abilityId,
        abilityName = abilityName,
        sourceName = sourceName,
        sourceType = sourceType,
        targetName = targetLabel,
        targetType = targetType,
        value = hitValue,
        result = resultLabel,
        critical = critical,
        message = string.format("%s used %s (%d) on %s: %s%s", sourceLabel, abilityName, abilityId, targetLabel, details, costText),
    })
end

EVENT_MANAGER:RegisterForEvent(LAL.name, EVENT_COMBAT_EVENT, OnCombatEvent)
