local ADDON_NAME = "LazyOverlandChallenger"

local RETRY_DELAY_MS = 10000

local lastBossState
local pendingTarget
local pendingChanges = {}
local changeGeneration = 0
local isEnabled = true

local function IsOverlandZone()
    return GetOverlandDifficultyDisabledReason() == OVERLAND_DIFFICULTY_DISABLED_REASON_NONE
end

local function RetryChange()
    if not isEnabled then
        return
    end
    local pending = table.remove(pendingChanges, 1)
    if pending == nil or pending.generation ~= changeGeneration then
        return
    end
    if not IsOverlandZone() then
        return
    end
    if GetOverlandDifficulty() ~= pending.target then
        RequestChangePlayerOverlandDifficulty(pending.target)
    end
end

local function OnDifficultyChanged(_, newValue)
    if pendingTarget == nil or newValue ~= pendingTarget then
        return
    end
    local target = pendingTarget
    pendingTarget = nil
    local targetStrKey
    if target == OVERLAND_DIFFICULTY_TYPE_BASEGAME then
        targetStrKey = SI_OVERLANDDIFFICULTYTYPE0
    elseif target == OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN then
        targetStrKey = SI_OVERLANDDIFFICULTYTYPE1
    end
    local challengeDiffucultyTitle = GetString(SI_CHALLENGE_DIFFICULTY_TITLE)
    local targetDifficulty = GetString(targetStrKey)
    local message = zo_strformat(GetString(SI_KEYBOARD_RETRAIT_COMPLETED_RESULT_FORMATTER), challengeDiffucultyTitle, targetDifficulty)
    CHAT_ROUTER:AddSystemMessage(message)
    local chatSystem = ZO_GetChatSystem()
    chatSystem:Maximize()
    chatSystem.primaryContainer:FadeIn()
end

local function ChangeDifficulty(target)
    changeGeneration = changeGeneration + 1
    pendingTarget = target
    table.insert(pendingChanges, { generation = changeGeneration, target = target })
    RequestChangePlayerOverlandDifficulty(target)
    zo_callLater(RetryChange, RETRY_DELAY_MS + GetLatency())
end

local function ApplyDifficulty()
    if not isEnabled or not IsOverlandZone() then
        return
    end

    local hasBoss = false
    for i = BOSS_RANK_ITERATION_BEGIN, BOSS_RANK_ITERATION_END do
        local unitTag = "boss" .. i
        if DoesUnitExist(unitTag) then
            hasBoss = true
            break
        end
    end

    if lastBossState == nil then
        lastBossState = hasBoss
        return
    end
    if lastBossState == hasBoss then
        return
    end

    lastBossState = hasBoss
    if hasBoss then
        ChangeDifficulty(OVERLAND_DIFFICULTY_TYPE_BASEGAME)
    else
        ChangeDifficulty(OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN)
    end
end

local function ToggleAddon()
    isEnabled = not isEnabled
    if isEnabled then
        lastBossState = nil
        ApplyDifficulty()
    else
        pendingTarget = nil
        pendingChanges = {}
        changeGeneration = changeGeneration + 1
    end
    CHAT_ROUTER:AddSystemMessage("|c215895Lazy |cCC922FOverland Challenger|r " .. (isEnabled and
        "|cce912e" .. GetString(SI_SCREEN_NARRATION_TOGGLE_ON) or
        "|c2e5c8c" .. GetString(SI_SCREEN_NARRATION_TOGGLE_OFF)) .. "|r")
end

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_BOSSES_CHANGED, ApplyDifficulty)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED, ApplyDifficulty)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, ApplyDifficulty)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_OVERLAND_DIFFICULTY_CHANGED, OnDifficultyChanged)
    SLASH_COMMANDS["/lazyoc"] = ToggleAddon
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
