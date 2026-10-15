if not IsConsoleUI() then return end

--------------------------------------------------
-- Config
--------------------------------------------------
local ENTRY_ID  = 996
local MENU_ID   = "PvPUA"
local LCM_SCENE = "LibConsoleMenuScene"

local HIDE_FROM_ADDONS = true

local pendingSelect     = false
local added             = false
local preselectHooked   = false
local removedFromAddons = false

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

local function FindPvPUAMenu()
    local lcm = rawget(_G, "LibConsoleMenu")
    if not (lcm and lcm.menus) then return nil end
    for i = 1, #lcm.menus do
        if lcm.menus[i].menuId == MENU_ID then return lcm.menus[i] end
    end
    return nil
end

local function SelectPvPUA()
    local lcm = rawget(_G, "LibConsoleMenu")
    local menu = FindPvPUAMenu()
    if not (lcm and menu) then return end
    menu:Select()
    if lcm.RefreshSceneHeader then lcm:RefreshSceneHeader() end
end

local function HookPreselect()
    local lcm = rawget(_G, "LibConsoleMenu")
    if preselectHooked or not (lcm and lcm.scene) then return end
    preselectHooked = true

    lcm.scene:RegisterCallback("StateChange", function(_, newState)
        if newState ~= SCENE_SHOWING or not pendingSelect then return end
        pendingSelect = false
        SelectPvPUA()
    end)
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
        scene = LCM_SCENE,

        onSelectedCallback = function()
            pendingSelect = true
            HookPreselect()
        end,

        onUnselectedCallback = function()
            pendingSelect = false
        end,
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
-- Add-Ons Menu
--------------------------------------------------
local function RemoveFromAddonsMenu()
    if removedFromAddons or not HIDE_FROM_ADDONS or not ZO_MENU_ENTRIES then return end

    for i = 1, #ZO_MENU_ENTRIES do
        local subMenu = ZO_MENU_ENTRIES[i].subMenu
        if subMenu then
            for j = #subMenu, 1, -1 do
                local data = subMenu[j].data
                if data and data.addon and data.addon.menuId == MENU_ID then
                    table.remove(subMenu, j)
                    removedFromAddons = true
                end
            end
        end
    end

    if removedFromAddons and MAIN_MENU_GAMEPAD then
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
        HookPreselect()
        RemoveFromAddonsMenu()
    end)
end
