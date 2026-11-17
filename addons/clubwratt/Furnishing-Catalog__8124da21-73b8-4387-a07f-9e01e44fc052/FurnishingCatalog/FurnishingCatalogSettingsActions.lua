-- FurnishingCatalogSettingsActions.lua: the add-on's entry in the Add-Ons menu, through
-- LibHarvensAddonSettings. On console, typing /furn means opening the chat keyboard, so the
-- entry opens the catalog itself instead of a settings page.
--
-- The library gives every add-on a row in the main menu's Add-Ons list whose activation shows
-- that add-on's settings page. Once the library has built its rows (the first time the main
-- menu shows), this add-on's row is pointed at the catalog. Where that row cannot be found, the
-- settings page stays, holding one Open button.
local FC = FurnishingCatalog

local Settings = {}

local LIBRARY_MENU_ENTRY_ID = "LibHarvensAddonSettings" -- the library's entry in ZO_MENU_ENTRIES

local state = "not set up yet"
local panel = nil

local function OpenFromMenu()
    if FC.Browse then
        FC.Browse.Open(true)
    end
end

---This add-on's row in the library's Add-Ons list.
---@return table|nil rowData the row's data table (the main menu reads its activatedCallback)
local function FindMenuRow()
    local entries = rawget(_G, "ZO_MENU_ENTRIES")
    if type(entries) ~= "table" then
        return nil
    end
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.id == LIBRARY_MENU_ENTRY_ID and type(entry.subMenu) == "table" then
            for _, row in ipairs(entry.subMenu) do
                if type(row) == "table" and type(row.data) == "table" and row.data.addon == panel then
                    return row.data
                end
            end
        end
    end
    return nil
end

---Point this add-on's row in the Add-Ons list at the catalog.
---@return boolean pointed
function Settings.PointMenuRowAtCatalog()
    local rowData = FindMenuRow()
    if not rowData then
        return false
    end
    rowData.activatedCallback = FC.Guard("MenuOpen", OpenFromMenu)
    state = "the Add-Ons menu entry opens the catalog"
    return true
end

---Add the entry, once the saved variables are loaded.
---@return boolean added
function Settings.Initialize()
    local LAS = rawget(_G, "LibHarvensAddonSettings")
    if type(LAS) ~= "table" or not LAS.AddAddon then
        state = "LibHarvensAddonSettings not installed: no menu entry (/furn opens the catalog)"
        return false
    end

    panel = LAS:AddAddon(FC.displayName)
    panel.author = "clubwratt"
    panel.version = "v" .. tostring(FC.version)
    -- The page behind the entry, for a client where the entry cannot be pointed at the catalog.
    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Furnishing Catalog",
        tooltip = "Browse every furnishing with a live 3D preview. The same as typing /furn in chat.",
        buttonText = "Open",
        clickHandler = FC.Guard("SettingsOpen", function()
            if FC.Browse then
                FC.Browse.Open()
            end
        end),
    })
    state = "menu entry added; it opens a page with an Open button until the main menu has shown once"

    -- The library builds its rows the first time the main menu shows; its own handler was
    -- registered first, so the rows exist by the time this one runs (SHOWN covers the other order).
    local menuScene = rawget(_G, "MAIN_MENU_GAMEPAD_SCENE")
    if type(menuScene) == "table" and menuScene.RegisterCallback then
        local OnMenuState
        OnMenuState = FC.Guard("SettingsMenuState", function(_oldState, newState)
            if newState ~= SCENE_SHOWING and newState ~= SCENE_SHOWN then
                return
            end
            local pointed = Settings.PointMenuRowAtCatalog()
            if pointed or LAS.initialized then
                if not pointed then
                    state = "the Add-Ons menu entry opens a page with an Open button (this add-on's row was not found)"
                end
                menuScene:UnregisterCallback("StateChange", OnMenuState)
                FC.Log("settings: %s", state)
            end
        end)
        menuScene:RegisterCallback("StateChange", OnMenuState)
    end
    return true
end

---@return string
function Settings.StateText()
    return state
end

FC.Settings = Settings
