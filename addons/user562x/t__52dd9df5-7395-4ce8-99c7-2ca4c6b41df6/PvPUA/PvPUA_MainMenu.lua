if not IsConsoleUI() then return end

--------------------------------------------------
-- Config
--------------------------------------------------
local ENTRY_ID = 996

local added = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function FindCampaignsIndex()
    if not (ZO_MENU_ENTRIES and ZO_MENU_MAIN_ENTRIES) then return nil end

    local campaignId = ZO_MENU_MAIN_ENTRIES.CAMPAIGN
    if campaignId == nil then return nil end

    for i = 1, #ZO_MENU_ENTRIES do
        if ZO_MENU_ENTRIES[i].id == campaignId then return i end
    end

    return nil
end

local function SettingsSceneName()
    local settings = rawget(_G, "PvPUA_Settings")
    return settings and settings.SCENE_NAME or "PvPUA_SettingsScene"
end

--------------------------------------------------
-- Main Menu Integration
--------------------------------------------------
local function AddToMainMenu()
    if added or not ZO_MENU_ENTRIES then return end

    for i = 1, #ZO_MENU_ENTRIES do
        if ZO_MENU_ENTRIES[i].id == ENTRY_ID then
            added = true
            return
        end
    end

    local title = rawget(_G, "PVPUA_MENU_TITLE_COLORED") or "PvP UA!"
    local icon  = rawget(_G, "PVPUA_ADDON_ICON")
                  or "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_multiplayer.dds"

    local entry = ZO_GamepadEntryData:New(title, icon)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.id = ENTRY_ID

    entry.data = {
        name  = title,
        id    = ENTRY_ID,
        scene = SettingsSceneName(),
    }

    local campaignsIndex = FindCampaignsIndex()
    if campaignsIndex then
        table.insert(ZO_MENU_ENTRIES, campaignsIndex + 1, entry)
    else
        table.insert(ZO_MENU_ENTRIES, entry)
    end

    added = true

    if MAIN_MENU_GAMEPAD then
        MAIN_MENU_GAMEPAD:RefreshLists()
        MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
    end
end

--------------------------------------------------
-- Wiring
--------------------------------------------------
EVENT_MANAGER:RegisterForEvent("PvPUA_MainMenu", EVENT_PLAYER_ACTIVATED, function()
    AddToMainMenu()
    EVENT_MANAGER:UnregisterForEvent("PvPUA_MainMenu", EVENT_PLAYER_ACTIVATED)
end)

if MAIN_MENU_GAMEPAD_SCENE then
    MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState ~= SCENE_SHOWING then return end
        AddToMainMenu()
    end)
end
