local ADDON_NAME = "SurveyResetter"
local HOUSE_ID = 68
local JUMP_TIMEOUT_MS = 20000
local RADIAL_ICON = "/esoui/art/ava/ava_resourcestatus_tabicon_production.dds"

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    zo_callLater(ExitInstanceImmediately, GetLatency())
end

function RunSurveyResetter()
    if GetCurrentZoneHouseId() == HOUSE_ID then
        ExitInstanceImmediately()
        return
    end
    if not CanJumpToHouseFromCurrentLocation() then
        CHAT_ROUTER:AddSystemMessage(GetString(SURVEYRESETTER_CANNOT_JUMP))
        return
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    RequestJumpToHouse(HOUSE_ID, false)
end

local function Initialize()
    SLASH_COMMANDS["/surveyr"] = RunSurveyResetter
    if ZO_IsConsoleOrGameCoreUI() and LibRadialMenu then
        LibRadialMenu:RegisterAddon(ADDON_NAME, GetString(SURVEYRESETTER_NAME))
        LibRadialMenu:RegisterEntry(ADDON_NAME, GetString(SI_BINDING_NAME_SURVEYRESETTER_RUN), "run", RADIAL_ICON,
            RunSurveyResetter, GetString(SURVEYRESETTER_DESCRIPTION))
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
