-- Global Table definition
YudosKillFeed = {
    name = "YudosKillFeed",
    version = "1.3.5",
    groupCache = {},
    guildCache = {},
    guildUpdateHandle = nil, -- Handle for zo_callLater debouncing
    groupUpdateHandle = nil, -- Handle for group debouncing
    isInitialized = false,
    isPvPZone = false,
    defaults = {
        filterMode = "Group", -- Player, Group, or Guild
        showKills = true,
        showDeaths = true,
        playSoundOnMyKills = false,
        enabledGuilds = {}, -- Stores guildId = boolean
    }
}

-- Localized API for performance
local GetUnitDisplayName = GetUnitDisplayName
local GetGroupSize = GetGroupSize
local GetGroupUnitTagByIndex = GetGroupUnitTagByIndex
local AreUnitsEqual = AreUnitsEqual
local GetNumGuilds = GetNumGuilds
local GetGuildId = GetGuildId
local GetGuildName = GetGuildName
local GetNumGuildMembers = GetNumGuildMembers
local GetGuildMemberInfo = GetGuildMemberInfo
local IsPlayerInAvAWorld = IsPlayerInAvAWorld
local IsActiveWorldBattleground = IsActiveWorldBattleground
local GetWorldName = GetWorldName
local GetGameTimeMilliseconds = GetGameTimeMilliseconds

local YKF = YudosKillFeed
local YKF_addonName = YKF.name
local LAM = LibAddonMenu2
local lastPlaySoundTime = 0
local recentVictims = {}

local function PlayKillingBlowSound(victimName)
    local now = GetGameTimeMilliseconds()
    if (now - lastPlaySoundTime) >= 200 then
        if victimName and victimName ~= "" then
            if recentVictims[victimName] then return end
            recentVictims[victimName] = true
            zo_callLater(function()
                recentVictims[victimName] = nil
            end, 2000)
        end
        lastPlaySoundTime = now
        PlaySound(SOUNDS.DEATH_RECAP_KILLING_BLOW_SHOWN)
    end
end

-----------------------------------------------------------
-- 1. CACHE LOGIC
-----------------------------------------------------------

function YKF.UpdateGroupCache()
    ZO_ClearTable(YKF.groupCache)
    -- Clear cache and abort if we only care about the player OR not in PvP
    if not YKF.savedVars or YKF.savedVars.filterMode == "Player" or not YKF.isPvPZone then
        return
    end

    local size = GetGroupSize()
    if size <= 1 then return end 

    for i = 1, size do
        local unitTag = GetGroupUnitTagByIndex(i)
        if not AreUnitsEqual("player", unitTag) then
            local name = GetUnitDisplayName(unitTag)
            if name and name ~= "" then
                YKF.groupCache[name] = true
            end
        end
    end
end

-- Debounce wrapper for group updates
function YKF.QueueGroupCacheUpdate()
    -- If we aren't in PvP, don't even start the timer
    if not YKF.isPvPZone then
        ZO_ClearTable(YKF.groupCache) -- Keep memory clean while in PvE
        return
    end

    if YKF.groupUpdateHandle then
        zo_removeCallLater(YKF.groupUpdateHandle)
    end
    YKF.groupUpdateHandle = zo_callLater(function()
        YKF.groupUpdateHandle = nil
        YKF.UpdateGroupCache()
    end, 1000)
end

-- Performance optimized update for guild member changes
function YKF.UpdateGuildCache()
    ZO_ClearTable(YKF.guildCache)
    -- Clear cache and abort if filter is not set to Guild OR not in PvP
    if not YKF.savedVars or YKF.savedVars.filterMode ~= "Guild" or not YKF.isPvPZone then
        return
    end
    
    -- Safety check: Ensure SavedVars are loaded
    if not YKF.savedVars.enabledGuilds then return end
    
    local numGuilds = GetNumGuilds()
    local playerName = YKF.playerName

    for i = 1, numGuilds do
        local guildId = GetGuildId(i)
        if YKF.savedVars.enabledGuilds[guildId] then
            local numMembers = GetNumGuildMembers(guildId)
            for j = 1, numMembers do
                local name = GetGuildMemberInfo(guildId, j)
                if name and name ~= "" and name ~= playerName then
                    YKF.guildCache[name] = true
                end
            end
        end
    end
end

-- Debounce wrapper to prevent micro-stutters during mass guild events
function YKF.QueueGuildCacheUpdate()
    -- If we aren't in PvP, don't even start the timer
    if not YKF.isPvPZone then 
        ZO_ClearTable(YKF.guildCache) -- Keep memory clean while in PvE
        return 
    end

    if YKF.guildUpdateHandle then
        zo_removeCallLater(YKF.guildUpdateHandle)
    end
    -- Wait 1 second after last event before rebuilding cache
    YKF.guildUpdateHandle = zo_callLater(function()
        YKF.guildUpdateHandle = nil
        YKF.UpdateGuildCache()
    end, 1000)
end

-----------------------------------------------------------
-- 2. INITIALIZATION LOGIC
-----------------------------------------------------------

function YKF.Initialize()
    YKF.playerName = GetUnitDisplayName("player")
    local worldName = GetWorldName()
    
    -- Load Saved Variables with server-specific profile
    YKF.savedVars = ZO_SavedVars:NewAccountWide("YudosKillFeedVars", 1, nil, YKF.defaults, worldName)
    
    -- Fix #2: Guarantee sub-table existence immediately after load
    YKF.savedVars.enabledGuilds = YKF.savedVars.enabledGuilds or {}

    -- Clean up stale guild IDs no longer in use
    for savedGuildId in pairs(YKF.savedVars.enabledGuilds) do
        -- GetGuildName returns an empty string if you aren't in that guild
        if GetGuildName(savedGuildId) == "" then
            YKF.savedVars.enabledGuilds[savedGuildId] = nil
        end
    end

    -- Group Events
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GROUP_MEMBER_JOINED, function() YKF.QueueGroupCacheUpdate() end)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GROUP_MEMBER_LEFT, function() YKF.QueueGroupCacheUpdate() end)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GROUP_UPDATE, function() YKF.QueueGroupCacheUpdate() end)
    -- Fires when a group member's status (Online/Offline/Zone) changes
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GROUP_MEMBER_CONNECTED_STATUS, function() YKF.QueueGroupCacheUpdate() end)

    -- Guild Events
    -- Targeted member update: check if we care about this specific guild
    local function OnGuildMemberChanged(_, guildId)
        if YKF.savedVars and YKF.savedVars.enabledGuilds[guildId] then
            YKF.QueueGuildCacheUpdate()
        end
    end

    -- Ensure cache builds once guild data is actually sent by the server
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GUILD_DATA_LOADED, function() YKF.QueueGuildCacheUpdate() end)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GUILD_MEMBER_ADDED, OnGuildMemberChanged)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GUILD_MEMBER_REMOVED, OnGuildMemberChanged)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GUILD_SELF_JOINED_GUILD, function() YKF.QueueGuildCacheUpdate() end)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_GUILD_SELF_LEFT_GUILD, function() YKF.QueueGuildCacheUpdate() end)

    YKF.CreateSettingsMenu()
    YKF.HookNativeFeed()
end

function YKF.OnPlayerActivated(eventCode, initialCall)    
    -- Update cached PvP status on every zone change
    YKF.isPvPZone = IsPlayerInAvAWorld() or IsActiveWorldBattleground()

    if not YKF.isInitialized then
        YKF.isInitialized = true
        YKF.Initialize()
    end

    -- When the loading screen ends, check if we need to build or clear caches
    YKF.UpdateGroupCache()
    YKF.UpdateGuildCache()
end

function YKF.OnAddOnLoaded(eventCode, otherAddOnName)
    if otherAddOnName ~= YKF_addonName then return end 
    EVENT_MANAGER:UnregisterForEvent(YKF_addonName, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_PLAYER_ACTIVATED, YKF.OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(YKF_addonName, EVENT_ADD_ON_LOADED, YKF.OnAddOnLoaded)

-----------------------------------------------------------
-- 3. THE HOOK
-----------------------------------------------------------

function YKF.HookNativeFeed()
    -- Hook the chat router for PvP Kill Feed messages
    ZO_PreHook(CHAT_ROUTER, "FormatAndAddChatMessage", function(self, eventCode, ...)
        -- Dormant check: If not in PvP, exit immediately
        if not YKF.isPvPZone then return false end
        
        -- Filter check: Only handle Kill Feed events
        if eventCode ~= EVENT_PVP_KILL_FEED_DEATH then return false end

        local _, killerDisplayName, _, _, _, victimDisplayName, _, _, _, _ = ...
        local vars = YKF.savedVars
        local playerName = YKF.playerName

        local isMeKiller = (killerDisplayName == playerName)
        local isMeVictim = (victimDisplayName == playerName)

        -- Play sound on player kills if toggle is enabled
        if isMeKiller and vars.playSoundOnMyKills then
            PlayKillingBlowSound(victimDisplayName)
        end

        -- Early exit for "No Filter" mode (Disables all filtering)
        if YKF.savedVars.filterMode == "No Filter" then return false end

        -- Branch 1: Is user involved?
        if isMeKiller or isMeVictim then
            if (isMeKiller and vars.showKills) or (isMeVictim and vars.showDeaths) then
                return false -- Show message
            end
            return true -- Filter out
        end

        -- Branch 2: General Filter Logic
        if vars.filterMode == "Player" then return true end

        if vars.filterMode == "Group" then
            if (YKF.groupCache[killerDisplayName] and vars.showKills) or (YKF.groupCache[victimDisplayName] and vars.showDeaths) then
                return false -- Show message
            end
            return true -- Filter out
        end

        if vars.filterMode == "Guild" then
            -- Note: Guild Mode includes Group tracking by default
            if (YKF.guildCache[killerDisplayName] and vars.showKills) or (YKF.guildCache[victimDisplayName] and vars.showDeaths) or
               (YKF.groupCache[killerDisplayName] and vars.showKills) or (YKF.groupCache[victimDisplayName] and vars.showDeaths) then
                return false -- Show message
            end
            return true -- Filter out
        end

        return true 
    end)
end

-----------------------------------------------------------
-- 4. SETTINGS MENU
-----------------------------------------------------------

function YKF.CreateSettingsMenu()
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Yudo's Kill Feed",
        displayName = "Yudo's Kill Feed",
        author = "YudoAn",
        version = YKF.version,
        website = "https://www.esoui.com/downloads/info4390-YudosKillFeed.html",
        registerForRefresh = true,
    }
    LAM:RegisterAddonPanel("YudosKillFeedPanel", panelData)

    local guildControls = {}
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        local guildName = GetGuildName(guildId)
        
        table.insert(guildControls, {
            type = "checkbox",
            name = guildName,
            getFunc = function() return YKF.savedVars.enabledGuilds[guildId] end,
            setFunc = function(value) 
                YKF.savedVars.enabledGuilds[guildId] = value 
                YKF.UpdateGuildCache()
            end,
            disabled = function() return YKF.savedVars.filterMode ~= "Guild" end,
        })
    end
    
    table.insert(guildControls, {
        type = "description",
        text = "Requires UI reload to update guild list.",
    })

    local optionsData = {
        {
            type = "header",
            name = "General Settings",
        },
        {
            type = "description",
            text = "PvP Kill Feed option must be ON in your Settings -> Social -> Notifications.",
        },
        {
            type = "checkbox",
            name = "Show Kills",
            getFunc = function() return YKF.savedVars.showKills end,
            setFunc = function(value) YKF.savedVars.showKills = value end,
        },
        {
            type = "checkbox",
            name = "Show Deaths",
            getFunc = function() return YKF.savedVars.showDeaths end,
            setFunc = function(value) YKF.savedVars.showDeaths = value end,
        },
        {
            type = "dropdown",
            name = "Filter Mode",
            choices = {"Player", "Group", "Group & Guild", "No Filter"},
            choicesValues = {"Player", "Group", "Guild", "No Filter"},
            getFunc = function() return YKF.savedVars.filterMode end,
            setFunc = function(value) 
                YKF.savedVars.filterMode = value 
                -- Trigger cache updates/clears immediately
                YKF.UpdateGroupCache()
                YKF.UpdateGuildCache()
            end,
        },
        {
            type = "submenu",
            name = "Guild Selection",
            controls = guildControls,
        },
        {
            type = "header",
            name = "More Settings",
        },
        {
            type = "checkbox",
            name = "Player killing blow sound",
            getFunc = function() return YKF.savedVars.playSoundOnMyKills end,
            setFunc = function(value) YKF.savedVars.playSoundOnMyKills = value end,
        },
        {
            type = "button",
            name = "Preview Sound",
            func = function() PlayKillingBlowSound() end,
        },
    }

    LAM:RegisterOptionControls("YudosKillFeedPanel", optionsData)
end