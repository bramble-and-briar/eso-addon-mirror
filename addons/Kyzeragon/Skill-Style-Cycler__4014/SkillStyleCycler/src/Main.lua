SkillStyleCycler = SkillStyleCycler or {}
local SSC = SkillStyleCycler
SSC.name = "SkillStyleCycler"
SSC.version = "1.4.3"

SSC.Modes = {
    DO_NOTHING = "Do nothing",
    RANDOMIZE_ALL = "Randomize all",
    RANDOMIZE_DIFFERENT = "Randomize different",
    CYCLE = "Cycle",
    CLEAR = "Clear all",
    LAST = "Use last",
}

local defaultOptions = {
    debug = false,
    printChat = true,
    throttle = 10, -- Minimum number of seconds between triggering
    onlyTriggerIfCombat = true,
    cancelRetriesInCombat = true,
    triggers = {
        login = SSC.Modes.DO_NOTHING,
        exitCombat = SSC.Modes.DO_NOTHING,
        loadscreen = SSC.Modes.DO_NOTHING, -- really just on player activated
    },
    -- See IndividualToggles.lua
    enabledStyles = {},
}


---------------------------------------------------------------------------------------------------
local function PrintDebug(message)
    if (SSC.savedOptions.debug) then
        d(message)
    end
end

local function PrintVerbose(message)
    if (SSC.savedOptions.printChat) then
        CHAT_ROUTER:AddSystemMessage(message)
    end
end


---------------------------------------------------------------------
---------------------------------------------------------------------
local BASE_STYLE_ID = -1 -- Just so I stop confusing myself

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

local function CanChangeStyle(collectibleId)
    if (collectibleId == 0) then return true end -- This can happen if there's no style, but want to apply no style
    if (not IsCollectibleBlocked(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER) and IsCollectibleUsable(collectibleId)) then
        return true
    end

    local reason = GetCollectibleBlockReason(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    PrintDebug(string.format("|cFF6600Can't change styles because %s|r", reasons[reason] or "???"))
    return false
end

-- Use all collectibles in the list, then listen for success or failure. On success, cancel the polling
local retries = 0
local function UseCollectibles(collectibleIds)
    if (SSC.savedOptions.cancelRetriesInCombat and IsUnitInCombat("player")) then
        PrintDebug("in combat, stopping")
        inRetries = false
        EVENT_MANAGER:UnregisterForUpdate(SSC.name .. "UseCollectiblesUpdate")
        EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
        EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)
        return
    end

    retries = retries + 1
    if (retries > 10) then
        PrintDebug("too many retries, stopping")
        inRetries = false
        EVENT_MANAGER:UnregisterForUpdate(SSC.name .. "UseCollectiblesUpdate")
        EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
        EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)
        return
    end

    -- Use all at once, because staggering can make them go on cooldown
    local collectibleId = collectibleIds[1]
    if (not CanChangeStyle(collectibleId)) then return end
    for i = 1, #collectibleIds do
        UseCollectible(collectibleIds[i])
    end

    -- Even if the API says the collectible isn't blocked, it could still be because of cooldown
    -- So attempt to use it, and listen for change
    PrintDebug("Listening: |t20:20:" .. GetCollectibleIcon(collectibleId) .. "|t")
    EVENT_MANAGER:RegisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED, function(_, id)
        if (id == collectibleId) then
            EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
            EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)

            -- On success, stop polling
            PrintDebug("was probably successful")
            lastSuccess = GetGameTimeSeconds()
            if (not IsUnitInCombat("player")) then -- The style change could have occurred in combat
                beenInCombat = false
            end
            inRetries = false
            EVENT_MANAGER:UnregisterForUpdate(SSC.name .. "UseCollectiblesUpdate")
        end
    end)

    -- This doesn't provide ID, so we'll just assume it's from ours
    EVENT_MANAGER:RegisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT, function(_, result)
        EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_USE_RESULT)

        -- If the collectible failed, then it won't get updated, so stop listening for it
        if (result ~= COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED) then
            PrintDebug(string.format("|cFF3300Styles failed because %s|r", reasons[result] or "???"))
            EVENT_MANAGER:UnregisterForEvent(SSC.name .. "TestCollectible", EVENT_COLLECTIBLE_UPDATED)
        end
    end)
end

local function PollUseCollectibles(collectibleIds)
    if (#collectibleIds == 0) then return end

    retries = 0
    inRetries = true
    EVENT_MANAGER:RegisterForUpdate(SSC.name .. "UseCollectiblesUpdate", 2000, function() UseCollectibles(collectibleIds) end)
    UseCollectibles(collectibleIds)
end

---------------------------------------------------------------------
-- Core: picks the style
---------------------------------------------------------------------
--[[
A map of progressionId to the collectible IDs, but only if the skill is unlocked and the collectibles are unlocked
{
    progressionId = {
        available = {BASE_STYLE_ID, 139213, 345435},
    }
}
]]
local skillStyleTable = {}

-- 1 ~ num
local function GetRandomNumber(num)
    return math.floor(math.random() * num + 1)
end

-- 1 ~ num except for except
local function GetRandomNumberExcept(num, except)
    local result = GetRandomNumber(num - 1)
    if (result >= except) then
        return result + 1
    end
    return result
end

local function IndexOf(idList, id)
    for k, v in ipairs(idList) do
        if (v == id) then
            return k
        end
    end
    return -1
end

-- Get the icon for this progressionId, i.e. the wanted style
-- collectibleId = BASE_STYLE_ID will return the base style
local function GetIcon(progressionId, collectibleId)
    if (collectibleId == BASE_STYLE_ID) then
        local morph = GetProgressionSkillCurrentMorphSlot(progressionId)
        local abilityId = GetProgressionSkillMorphSlotAbilityId(progressionId, morph)
        return string.format("|t20:20:%s|t", GetAbilityIcon(abilityId))
    else
        return string.format("|t20:20:%s|t", GetCollectibleIcon(collectibleId))
    end
end

-- Returns 0 for collectibleId if no collectible should be used
local function GetCollectibleToUse(progressionId, mode)
    local data = skillStyleTable[progressionId]
    if (not data) then return end

    local newIndex
    local activeCollectibleId = GetActiveProgressionSkillAbilityFxOverrideCollectibleId(progressionId)
    if (activeCollectibleId == 0) then activeCollectibleId = BASE_STYLE_ID end
    local activeIndex = IndexOf(data.available, activeCollectibleId)
    if (activeIndex == -1) then
        -- User has a style currently applied that they have toggled off in settings
        newIndex = 1 -- TODO
    elseif (mode == SSC.Modes.CYCLE) then
        -- Increment, wrapping around if needed
        newIndex = activeIndex + 1
        if (newIndex > #data.available) then
            newIndex = 1
        end
    elseif (mode == SSC.Modes.RANDOMIZE_ALL) then
        -- Pick randomly
        newIndex = GetRandomNumber(#data.available)
    elseif (mode == SSC.Modes.RANDOMIZE_DIFFERENT) then
        -- Pick randomly
        if (#data.available == 1) then -- This can happen if only 1 is enabled
            newIndex = 1
        else
            newIndex = GetRandomNumberExcept(#data.available, activeIndex)
        end
    elseif (mode == SSC.Modes.CLEAR) then
        local icon = GetIcon(progressionId, BASE_STYLE_ID)
        if (activeCollectibleId == BASE_STYLE_ID) then
            return 0, icon
        else
            return activeCollectibleId, icon
        end
    elseif (mode == SSC.Modes.LAST) then
        local numStyles = GetNumProgressionSkillAbilityFxOverrides(progressionId)
        for i = 1, numStyles do
            local fxIndex = numStyles + 1 - i -- Go backwards
            local collectibleId = GetProgressionSkillAbilityFxOverrideCollectibleIdByIndex(progressionId, fxIndex)
            if (IsCollectibleUnlocked(collectibleId)) then
                local icon = GetIcon(progressionId, collectibleId)
                if (collectibleId == activeCollectibleId) then
                    return 0, icon
                else
                    return collectibleId, icon
                end
            end
        end
        return 0, GetIcon(progressionId, BASE_STYLE_ID)
    else
        PrintDebug("|cFF0000????|r")
        return
    end

    -- Find the ID and icon
    local collectibleId, icon
    -- If there is no style change...
    if (newIndex == activeIndex) then
        -- ... do nothing (return 0 for collectibleId), but still provide the icon
        collectibleId = data.available[newIndex]
        icon = GetIcon(progressionId, collectibleId)
        collectibleId = 0
    else
        if (data.available[newIndex] == BASE_STYLE_ID) then
            -- Otherwise, if the desired is the base style, deactivate the previous one
            icon = GetIcon(progressionId, BASE_STYLE_ID)
            collectibleId = activeCollectibleId
        else
            -- Or activate a new one
            collectibleId = data.available[newIndex]
            icon = GetIcon(progressionId, collectibleId)
        end
    end

    return collectibleId, icon
end

local function CycleAll(mode, bypass, message)
    if (bypass ~= true) then
        local elapsed = GetGameTimeSeconds() - lastSuccess
        if (elapsed < SSC.savedOptions.throttle) then
            PrintDebug(string.format("Not cycling styles because it has only been %d seconds since the last change", elapsed))
            return
        end

        if (SSC.savedOptions.onlyTriggerIfCombat and not beenInCombat) then
            PrintDebug("Not cycling styles because you haven't been in combat since the last change")
            return
        end
    end

    if (inRetries) then
        PrintDebug("Not cycling styles because still in retries")
        return
    end

    local collectibleIds = {}
    local appliedIcons = {}
    local line = ""
    local numInLine = 0
    for progressionId, _ in pairs(skillStyleTable) do
        local collectibleId, icon = GetCollectibleToUse(progressionId, mode)
        if (collectibleId ~= 0) then -- It can be 0 if it's already non styled, and no style is rolled again
            table.insert(collectibleIds, collectibleId)
        end

        if (numInLine > 15) then
            table.insert(appliedIcons, line)
            numInLine = 0
            line = ""
        end
        numInLine = numInLine + 1
        line = line .. icon .. " "
    end
    table.insert(appliedIcons, line)

    if (message) then
        PrintVerbose(message)
    end
    -- Split into multiple lines, or too many icons means some get cut off
    for _, line in ipairs(appliedIcons) do
        PrintVerbose(line)
    end

    PollUseCollectibles(collectibleIds)
end
SSC.CycleAll = CycleAll -- /script SkillStyleCycler.CycleAll("Randomize all")


---------------------------------------------------------------------------------------------------
-- Collect valid styles
---------------------------------------------------------------------------------------------------
local function BuildSkillStyleTable()
    EVENT_MANAGER:UnregisterForUpdate(SSC.name .. "ProgressionsUpdatedTimeout")
    PrintDebug("Building skill style table")
    skillStyleTable = {}
    for skillType = 1, GetNumSkillTypes() do
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            -- PrintDebug(GetSkillLineNameById(GetSkillLineId(skillType, skillLineIndex)))
            -- The current class' 3 lines is always returned first, so skip the rest
            -- if (skillType == SKILL_TYPE_CLASS and skillLineIndex > 3) then break end -- This is no longer applicable because of subclassing
            local lineActive = true
            if (skillType == SKILL_TYPE_CLASS) then
                local _, _, isActive = GetSkillLineDynamicInfo(skillType, skillLineIndex)
                lineActive = isActive
                -- if (isActive) then
                --     PrintDebug("Active class line: " .. GetSkillLineNameById(GetSkillLineId(skillType, skillLineIndex)))
                -- end
            end

            if (lineActive) then
                for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                    local progressionId = GetProgressionSkillProgressionId(skillType, skillLineIndex, skillIndex)
                    local numStyles = GetNumProgressionSkillAbilityFxOverrides(progressionId)

                    -- Make sure the skill is unlocked
                    local _, _, _, _, _, purchased, progressionIndex = GetSkillAbilityInfo(skillType, skillLineIndex, skillIndex)

                    if (purchased and progressionIndex ~= nil and numStyles > 0) then
                        -- Collect list of unlocked + enabled styles
                        local unlockedStyles = {}

                        -- Some like Sacrificial Bones have no styles but API returns one as 0
                        local hasEnabledStyles = false -- If all are disabled, then don't add it to the table at all

                        if (SSC.savedOptions.enabledStyles[progressionId][BASE_STYLE_ID] == true) then
                            unlockedStyles = {BASE_STYLE_ID}
                            hasEnabledStyles = true
                        end

                        for fxIndex = 1, numStyles do
                            local collectibleId = GetProgressionSkillAbilityFxOverrideCollectibleIdByIndex(progressionId, fxIndex)
                            if (IsCollectibleUnlocked(collectibleId)) then
                                if (SSC.savedOptions.enabledStyles[progressionId][collectibleId] == true) then
                                    hasEnabledStyles = true
                                    table.insert(unlockedStyles, collectibleId)
                                end
                            end
                        end

                        if (hasEnabledStyles) then
                            skillStyleTable[progressionId] = {
                                available = unlockedStyles,
                            }
                        end
                    end
                end
            end
        end
    end
end
SSC.BuildSkillStyleTable = BuildSkillStyleTable

-- This seems to fire on player activated too, but oh well
local function OnProgressionsUpdated()
    EVENT_MANAGER:RegisterForUpdate(SSC.name .. "ProgressionsUpdatedTimeout", 500, BuildSkillStyleTable)
    PrintDebug("progressions updated")
end

local function OnCollectiblesUnlocked()
    EVENT_MANAGER:RegisterForUpdate(SSC.name .. "ProgressionsUpdatedTimeout", 500, BuildSkillStyleTable)
    PrintDebug("unlock state changed")
end

---------------
-- Combat state
local function OnCombatStateChanged(_, inCombat)
    if (not inCombat and SSC.savedOptions.triggers.exitCombat ~= SSC.Modes.DO_NOTHING) then
        zo_callLater(function()
            if (not IsUnitInCombat("player")) then
                CycleAll(SSC.savedOptions.triggers.exitCombat, false, "Changing styles because exited combat")
            end
        end, 1000)
    elseif (inCombat) then
        beenInCombat = true
    end
end

---------------
-- "Loadscreen"
local function OnPlayerActivated()
    if (SSC.savedOptions.triggers.loadscreen ~= SSC.Modes.DO_NOTHING) then
        zo_callLater(function()
            CycleAll(SSC.savedOptions.triggers.loadscreen, false, "Changing styles because loadscreen")
        end, 1000)
    end
end

-----------------------
-- First time activated
local function OnPlayerActivatedFirstTime()
    EVENT_MANAGER:UnregisterForEvent(SSC.name .. "FirstActivated", EVENT_PLAYER_ACTIVATED)

    BuildSkillStyleTable()

    if (SSC.savedOptions.triggers.login ~= SSC.Modes.DO_NOTHING) then
        CycleAll(SSC.savedOptions.triggers.login, false, "Changing styles because login/reload")
    end

    EVENT_MANAGER:RegisterForEvent(SSC.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    OnPlayerActivated()
end

---------------------------------------------------------------------
-- Initialize
local function Initialize()
    SSC.savedOptions = ZO_SavedVars:NewAccountWide("SkillStyleCyclerSavedVariables", 3, "Options", defaultOptions)

    SSC.CreateSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(SSC.name .. "FirstActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivatedFirstTime)
    EVENT_MANAGER:RegisterForEvent(SSC.name .. "CombatState", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
    EVENT_MANAGER:RegisterForEvent(SSC.name .. "ProgressionsUpdated", EVENT_SKILL_ABILITY_PROGRESSIONS_UPDATED, OnProgressionsUpdated)
    EVENT_MANAGER:RegisterForEvent(SSC.name .. "UnlockState", EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, OnCollectiblesUnlocked)
end

---------------------------------------------------------------------
-- On load
local function OnAddOnLoaded(_, addonName)
    if (addonName == SSC.name) then
        EVENT_MANAGER:UnregisterForEvent(SSC.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(SSC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
