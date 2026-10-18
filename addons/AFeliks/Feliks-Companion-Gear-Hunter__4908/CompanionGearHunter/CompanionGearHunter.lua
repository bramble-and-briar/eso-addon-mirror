CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- The addon's one EVENT_ADD_ON_LOADED and one EVENT_PLAYER_ACTIVATED handler.
-- Every other file only defines functions (and constants); this file, loaded
-- last (see the manifest), decides when each runs and in what order, so start-up
-- order never depends on which file happened to register its event first.

local EVENT_NAMESPACE = "CompanionGearHunter"

-- Chat tagging, the row-badge hooks and the slash-command check only need to
-- happen once per session, on the first activation; the companion-gear sync
-- runs on every activation (login, /reloadui, zone change).
local firstActivation = true

local function OnPlayerActivated()
    CompanionGearHunter.Data.OnPlayerActivated()

    if firstActivation then
        firstActivation = false
        CompanionGearHunter.CheckSlashCommandHijack()
        CompanionGearHunter.InstallRowBadgeHooks()
        CompanionGearHunter.InstallChatTagging()
    end
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= CompanionGearHunter.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

    -- Order matters: the saved data first (everything below reads it), then
    -- the window, then the slash command that opens it, then the settings
    -- panel, then the hooks on the game's item lists and tooltips.
    CompanionGearHunter.Data.Initialize()
    CompanionGearHunter.BuildUI()
    CompanionGearHunter.SetSlashCommands()
    CompanionGearHunter.BuildAddonMenu()
    CompanionGearHunter.HookInventories()

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
