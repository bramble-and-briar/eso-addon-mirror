-- DLC Roulette. Copyright (c) 2026 -Chin. All rights reserved: no copying, sharing, changes or reuse.
-- Core: startup and saved settings.
DLCRoulette = DLCRoulette or {}
local DR = DLCRoulette

DR.name = "DLCRoulette"
DR.version = "1.1.3"

-- Shared by every character on the account. Only the dungeons the player unticked are saved, keyed by zone,
-- so a dungeon from a new DLC is in the roulette until it's unticked, and one untick covers Normal and Veteran.
DR.defaults = {
    excluded = {},
    cooldownHours = 12,
}

-- Cooldowns are the one thing kept apart per megaserver, since a dungeon run on NA says nothing about EU.
-- They go in their own namespace so the settings above stay exactly where they are and nobody's Dungeon
-- list is lost on update.
DR.cdDefaults = {
    normal = {},
    veteran = {},
}

local SAVED_VERSION = 1
local started = false

local function OnPlayerActivated()
    if started then
        return
    end
    started = true
    DR.Settings.Init()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= DR.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(DR.name, EVENT_ADD_ON_LOADED)
    DR.sv = ZO_SavedVars:NewAccountWide("DLCRoulette_SavedVariables", SAVED_VERSION, nil, DR.defaults)
    local world = GetWorldName()
    if not world or world == "" then
        world = "Default"
    end
    DR.cd = ZO_SavedVars:NewAccountWide("DLCRoulette_SavedVariables", SAVED_VERSION, "cooldowns", DR.cdDefaults, world)
    DR.Cooldown.Prune()
    DR.Buttons.Init()
    EVENT_MANAGER:RegisterForEvent(DR.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- Keyboard mode has no button strip in the Dungeon Finder: /dlcroulette vet or /dlcroulette normal
    SLASH_COMMANDS["/dlcroulette"] = function(arg)
        DR.Dungeons.Queue(zo_strlower(arg or "") == "normal" and LFG_ACTIVITY_DUNGEON or LFG_ACTIVITY_MASTER_DUNGEON)
    end
end

EVENT_MANAGER:RegisterForEvent(DR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
