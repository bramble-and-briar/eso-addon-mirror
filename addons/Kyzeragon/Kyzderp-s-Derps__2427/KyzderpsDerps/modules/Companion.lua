local KD = KyzderpsDerps
KD.Companion = KD.Companion or {}
local Companion = KD.Companion

---------------------------------------------------------------------
-- Resummon. Yoinked most collectibles code from SSC
---------------------------------------------------------------------
local lastSuccess = 0
local beenInCombat = true
local inRetries = false

local reasons = {
    [COLLECTIBLE_USAGE_BLOCK_REASON_ACTIVE_DIG_SITE_REQUIRED] = "ACTIVE_DIG_SITE_REQUIRED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_BLACKLISTED] = "BLACKLISTED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_BLOCKED_BY_LEADERBOARD_EVENT] = "BLOCKED_BY_LEADERBOARD_EVENT",
    [COLLECTIBLE_USAGE_BLOCK_REASON_BLOCKED_BY_SUBZONE] = "BLOCKED_BY_SUBZONE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_BLOCKED_BY_ZONE] = "BLOCKED_BY_ZONE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_CATEGORY_REQUIREMENT_FAILED] = "CATEGORY_REQUIREMENT_FAILED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_COLLECTIBLE_ALREADY_QUEUED] = "COLLECTIBLE_ALREADY_QUEUED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_COMPANION_INTRO_QUEST] = "COMPANION_INTRO_QUEST",
    [COLLECTIBLE_USAGE_BLOCK_REASON_COMPANION_INTRO_QUEST_BLOCKED_BY_ZONE] = "COMPANION_INTRO_QUEST_BLOCKED_BY_ZONE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_COMPANION_MENU_REQUIRED] = "COMPANION_MENU_REQUIRED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_DEAD] = "DEAD",
    [COLLECTIBLE_USAGE_BLOCK_REASON_DEFAULT_ALREADY_ACTIVE] = "DEFAULT_ALREADY_ACTIVE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_DUELING] = "DUELING",
    [COLLECTIBLE_USAGE_BLOCK_REASON_GROUP_FULL] = "GROUP_FULL",
    [COLLECTIBLE_USAGE_BLOCK_REASON_HAS_PENDING_COMPANION] = "HAS_PENDING_COMPANION",
    [COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_ALLIANCE] = "INVALID_ALLIANCE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_CLASS] = "INVALID_CLASS",
    [COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_COLLECTIBLE] = "INVALID_COLLECTIBLE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_GENDER] = "INVALID_GENDER",
    [COLLECTIBLE_USAGE_BLOCK_REASON_INVALID_RACE] = "INVALID_RACE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_IN_AIR] = "IN_AIR",
    [COLLECTIBLE_USAGE_BLOCK_REASON_IN_COMBAT] = "IN_COMBAT",
    [COLLECTIBLE_USAGE_BLOCK_REASON_IN_HIDEY_HOLE] = "IN_HIDEY_HOLE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_IN_WATER] = "IN_WATER",
    [COLLECTIBLE_USAGE_BLOCK_REASON_MAX_NUMBER_EQUIPPED] = "MAX_NUMBER_EQUIPPED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_MOUNT_IN_COMBAT] = "MOUNT_IN_COMBAT",
    [COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED] = "NOT_BLOCKED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN] = "ON_COOLDOWN",
    [COLLECTIBLE_USAGE_BLOCK_REASON_ON_MOUNT] = "ON_MOUNT",
    [COLLECTIBLE_USAGE_BLOCK_REASON_PLACED_IN_HOUSE] = "PLACED_IN_HOUSE",
    [COLLECTIBLE_USAGE_BLOCK_REASON_QUEST_FOLLOWER] = "QUEST_FOLLOWER",
    [COLLECTIBLE_USAGE_BLOCK_REASON_TARGET_REQUIRED] = "TARGET_REQUIRED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_TEMPORARILY_DISABLED] = "TEMPORARILY_DISABLED",
    [COLLECTIBLE_USAGE_BLOCK_REASON_UNACQUIRED_SKILL] = "UNACQUIRED_SKILL",
    [COLLECTIBLE_USAGE_BLOCK_REASON_UNUSABLE_BY_COMPANION] = "UNUSABLE_BY_COMPANION",
    [COLLECTIBLE_USAGE_BLOCK_REASON_WORLD_BOSS] = "WORLD_BOSS",
    [COLLECTIBLE_USAGE_BLOCK_REASON_WORLD_EVENT] = "WORLD_EVENT",
}

local function CanMaybeUseCollectible(collectibleId)
    if (collectibleId == 0) then return true end -- This can happen if there's no style, but want to apply no style
    if (not IsCollectibleBlocked(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER) and IsCollectibleUsable(collectibleId)) then
        return true
    end

    local reason = GetCollectibleBlockReason(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    KD:dbg(string.format("|cFF6600Can't change styles because %s|r", reasons[reason] or "???"))
    return false
end

-- Use all collectibles in the list, then listen for success or failure. On success, cancel the polling
local retries = 0
local function UseCollectibles(collectibleIds, successCallback)
    retries = retries + 1
    if (retries > 10) then
        KD:dbg("too many retries, stopping")
        inRetries = false
        EVENT_MANAGER:UnregisterForUpdate(KD.name .. "UseCollectiblesUpdate")
        EVENT_MANAGER:UnregisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
        EVENT_MANAGER:UnregisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)
        return
    end

    -- Use all at once, because staggering can make them go on cooldown
    local collectibleId = collectibleIds[1]
    if (not CanMaybeUseCollectible(collectibleId)) then return end
    for i = 1, #collectibleIds do
        UseCollectible(collectibleIds[i])
    end

    -- Even if the API says the collectible isn't blocked, it could still be because of cooldown
    -- So attempt to use it, and listen for change
    KD:dbg("Listening: |t20:20:" .. GetCollectibleIcon(collectibleId) .. "|t")
    EVENT_MANAGER:RegisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED, function(_, id)
        if (id == collectibleId) then
            EVENT_MANAGER:UnregisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
            EVENT_MANAGER:UnregisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)

            -- On success, stop polling
            KD:dbg("was probably successful")
            lastSuccess = GetGameTimeSeconds()
            inRetries = false
            EVENT_MANAGER:UnregisterForUpdate(KD.name .. "UseCollectiblesUpdate")

            if (successCallback) then
                successCallback()
            end
        end
    end)

    -- This doesn't provide ID, so we'll just assume it's from ours
    EVENT_MANAGER:RegisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT, function(_, result)
        EVENT_MANAGER:UnregisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)

        -- If the collectible failed, then it won't get updated, so stop listening for it
        if (result ~= COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED) then
            KD:dbg(string.format("|cFF3300Styles failed because %s|r", reasons[result] or "???"))
            EVENT_MANAGER:UnregisterForEvent(KD.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
        end
    end)
end

local function PollUseCollectibles(collectibleIds, successCallback)
    if (#collectibleIds == 0) then return end

    retries = 0
    inRetries = true
    EVENT_MANAGER:RegisterForUpdate(KD.name .. "UseCollectiblesUpdate", 1000, function() UseCollectibles(collectibleIds, successCallback) end)
    UseCollectibles(collectibleIds, successCallback)
end

local assistantId
local function GetUsableAssistant()
    if (assistantId) then return assistantId end
    for i = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_ASSISTANT) do
        local id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_ASSISTANT, i)
        if (IsCollectibleUnlocked(id)) then
            assistantId = id
            return assistantId
        end
    end
    assistantId = -1
end

local function CheeseCompanion()
    if (inRetries) then
        KD:msg("Already trying to resummon.")
        return
    end

    if (not DoesUnitExist("companion")) then
        -- TODO: allow just second half (or resummon?)
        KD:msg("No companion to resummon.")
        return
    end

    local collectibleId = GetUsableAssistant()
    if (collectibleId == -1) then
        KD:msg("No assistants available to cheese companion resummoning.")
        return
    end

    local currCompanion = GetActiveCompanionDefId()
    PollUseCollectibles({collectibleId}, function()
        KD:msg("Success, removing assistant soonTM.")
        zo_callLater(function()
            PollUseCollectibles({collectibleId})
        end, 1000)
    end)
end
Companion.CheeseCompanion = CheeseCompanion -- /script KyzderpsDerps.Companion.CheeseCompanion()


---------------------------------------------------------------------
-- Summon result
---------------------------------------------------------------------
local function OnSummonResult(_, summonResult, companionId)
    if (not KD.savedOptions.companion.showSummonResult) then return end

    local summonResults = {
        [COMPANION_SUMMON_RESULT_ADDED_FOR_GROUP_PLAYER] = "ADDED_FOR_GROUP_PLAYER",
        [COMPANION_SUMMON_RESULT_BLOCKED_BY_ASSISTANT] = "BLOCKED_BY_ASSISTANT",
        [COMPANION_SUMMON_RESULT_BLOCKED_BY_FOLLOWER] = "BLOCKED_BY_FOLLOWER",
        [COMPANION_SUMMON_RESULT_BLOCKED_BY_SUBZONE] = "BLOCKED_BY_SUBZONE",
        [COMPANION_SUMMON_RESULT_BLOCKED_BY_WORLD_BOSS] = "BLOCKED_BY_WORLD_BOSS",
        [COMPANION_SUMMON_RESULT_BLOCKED_BY_WORLD_EVENT] = "BLOCKED_BY_WORLD_EVENT",
        [COMPANION_SUMMON_RESULT_DATA_NOT_LOADED] = "DATA_NOT_LOADED",
        [COMPANION_SUMMON_RESULT_DEACTIVATED_VANITY_PET] = "DEACTIVATED_VANITY_PET",
        [COMPANION_SUMMON_RESULT_EFFECT_LIMIT] = "EFFECT_LIMIT",
        [COMPANION_SUMMON_RESULT_EXPECTED_DIFFERENT_COMPANION] = "EXPECTED_DIFFERENT_COMPANION",
        [COMPANION_SUMMON_RESULT_GROUP_FULL] = "GROUP_FULL",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_ASSISTANT] = "REMOVED_FOR_ASSISTANT",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_FOLLOWER] = "REMOVED_FOR_FOLLOWER",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_GROUP_PLAYER] = "REMOVED_FOR_GROUP_PLAYER",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_PERF] = "REMOVED_FOR_PERF",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_SUBZONE] = "REMOVED_FOR_SUBZONE",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_VANITY_PET] = "REMOVED_FOR_VANITY_PET",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_WORLD_BOSS] = "REMOVED_FOR_WORLD_BOSS",
        [COMPANION_SUMMON_RESULT_REMOVED_FOR_WORLD_EVENT] = "REMOVED_FOR_WORLD_EVENT",
        [COMPANION_SUMMON_RESULT_SPAWN_FAILED] = "SPAWN_FAILED",
        [COMPANION_SUMMON_RESULT_SUMMON_AUTO_REQUESTED] = "SUMMON_AUTO_REQUESTED",
        [COMPANION_SUMMON_RESULT_SUMMON_FAILED] = "SUMMON_FAILED",
        [COMPANION_SUMMON_RESULT_SUMMON_FAILED_LOW_RAPPORT] = "SUMMON_FAILED_LOW_RAPPORT",
        [COMPANION_SUMMON_RESULT_SUMMON_REQUESTED] = "SUMMON_REQUESTED",
    }
    KD:msg(zo_strformat("Summon result for <<1>>: <<2>>", GetCompanionName(companionId), summonResults[summonResult]))
end

---------------------------------------------------------------------
-- Rapport
---------------------------------------------------------------------
local function OnCompanionRapportUpdated(_, companionId, previousRapport, currentRapport)
    if (not KD.savedOptions.companion.showRapport) then return end

    local arrow = ""
    local change = currentRapport - previousRapport
    if (currentRapport > previousRapport) then
        arrow = "|c00FF00↑ +"
    else
        arrow = "|cFF0000↓ "
    end
    KD:msg(zo_strformat("Rapport changed for <<1>>: <<2>> → <<3>> <<4>><<5>>|r", GetCompanionName(companionId), previousRapport, currentRapport, arrow, change))
end


---------------------------------------------------------------------
-- Called on initial player activated
---------------------------------------------------------------------
function Companion.Initialize()
    KD:dbg("    Initializing Companion module...")

    EVENT_MANAGER:RegisterForEvent(KD.name .. "CompanionSummonResult", EVENT_COMPANION_SUMMON_RESULT, OnSummonResult)
    EVENT_MANAGER:RegisterForEvent(KD.name .. "CompanionRapport", EVENT_COMPANION_RAPPORT_UPDATE, OnCompanionRapportUpdated)

    -- Only for debug for now
    EVENT_MANAGER:RegisterForEvent(KD.name .. "CompanionStateChanged", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function(_, newState, oldState)
        local companionState = {
            [COMPANION_STATE_ACTIVE] = "ACTIVE",
            [COMPANION_STATE_BLOCKED_PERMANENT] = "BLOCKED_PERMANENT",
            [COMPANION_STATE_BLOCKED_TEMPORARY] = "BLOCKED_TEMPORARY",
            [COMPANION_STATE_HIDDEN] = "HIDDEN",
            [COMPANION_STATE_INACTIVE] = "INACTIVE",
            [COMPANION_STATE_INITIALIZED_PENDING] = "INITIALIZED_PENDING",
            [COMPANION_STATE_INITIALIZING] = "INITIALIZING",
            [COMPANION_STATE_PENDING] = "PENDING",
        }
        KD:dbg(zo_strformat("companion state: <<1>> -> <<2>>", companionState[oldState], companionState[newState]))
    end)
end

function Companion.GetSettings()
    return {
        {
            type = "description",
            title = nil,
            text = "You can toggle companions with the |c99FF99/bastian|r, |c99FF99/mirri|r, |c99FF99/ember|r, |c99FF99/isobel|r, |c99FF99/sharp|r, |c99FF99/azandar|r, |c99FF99/tanlorin|r, and |c99FF99/zerith|r commands.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Display rapport changes",
            tooltip = "Shows a message in chat when your companion's rapport changes",
            default = true,
            getFunc = function() return KD.savedOptions.companion.showRapport end,
            setFunc = function(value)
                    KD.savedOptions.companion.showRapport = value
                end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Display unsummon results",
            tooltip = "Shows a message in chat when your companion is unsummoned or cannot be summoned for error reasons",
            default = true,
            getFunc = function() return KD.savedOptions.companion.showSummonResult end,
            setFunc = function(value)
                    KD.savedOptions.companion.showSummonResult = value
                end,
            width = "full",
        },
    }
end
