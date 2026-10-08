-- An_Daghdha1233 Inventory gamepad menu integration.
-- Hand ESO's native inventory back to its own input route before protected actions.

An_Daghdha1233Inventory = An_Daghdha1233Inventory or {}
local Integration = {}
An_Daghdha1233Inventory.Integration = Integration

local NATIVE_SCENE = "gamepad_inventory_root"
local CUSTOM_SCENE = "An_Daghdha1233InventoryScene"
local OPTIONS_SCENE = "gamepad_options_root"
local MAP_SCENE = "gamepad_worldMap"

Integration.NATIVE_SCENE = NATIVE_SCENE
Integration.CUSTOM_SCENE = CUSTOM_SCENE

local activeEntryData
local mapInfoEntry
local pendingMapInfoTransition = false

local function GetInventoryEntry()
    local ids = ZO_MENU_MAIN_ENTRIES
    local entries = ZO_MENU_ENTRIES
    if type(ids) ~= "table" or type(entries) ~= "table" then
        return nil
    end

    local inventoryId = ids.INVENTORY
    local optionsId = ids.OPTIONS
    if type(inventoryId) ~= "number" or type(optionsId) ~= "number" or inventoryId == optionsId then
        return nil
    end

    local inventoryEntry = entries[inventoryId]
    local optionsEntry = entries[optionsId]
    if type(inventoryEntry) ~= "table" or inventoryEntry.id ~= inventoryId
        or type(inventoryEntry.data) ~= "table"
        or type(optionsEntry) ~= "table" or optionsEntry.id ~= optionsId
        or type(optionsEntry.data) ~= "table"
        or optionsEntry.data == inventoryEntry.data
        or optionsEntry.data.scene ~= OPTIONS_SCENE then
        return nil
    end

    return inventoryEntry
end

local function HasScene(sceneName)
    local manager = SCENE_MANAGER
    return type(manager) == "table" and type(manager.GetScene) == "function" and manager:GetScene(sceneName) ~= nil
end

function Integration.Enable()
    local entry = GetInventoryEntry()
    if entry == nil or not HasScene(CUSTOM_SCENE) or not HasScene(NATIVE_SCENE) then
        return false
    end

    local data = entry.data
    if activeEntryData ~= nil then
        return activeEntryData == data and data.scene == CUSTOM_SCENE
    end

    -- This expected value is a compatibility guard for future game UI changes
    -- and for another add-on that has already claimed the Inventory route.
    if data.scene ~= NATIVE_SCENE or data.sceneGroup ~= nil then
        return false
    end

    data.scene = CUSTOM_SCENE
    activeEntryData = data
    return true
end

function Integration.Disable()
    if activeEntryData == nil then
        return true
    end

    local entry = GetInventoryEntry()
    if entry == nil or entry.data ~= activeEntryData or activeEntryData.scene ~= CUSTOM_SCENE then
        activeEntryData = nil
        return false
    end

    activeEntryData.scene = NATIVE_SCENE
    activeEntryData = nil
    return true
end

function Integration.OpenNativeInventory()
    if not HasScene(NATIVE_SCENE) or type(SCENE_MANAGER.ShowBaseScene) ~= "function" then
        return false
    end
    if not Integration.Disable() then
        return false
    end
    -- ESO's quickslot wheel calls protected functions. Opening its Inventory
    -- scene directly from this add-on taints that path, even after restoring
    -- the menu entry. Leave the custom scene, then let the player's next
    -- Inventory input enter the native scene through ESO's trusted route.
    SCENE_MANAGER:ShowBaseScene()
    return true
end

function Integration.OpenMap()
    if not HasScene(MAP_SCENE) or type(SCENE_MANAGER.Show) ~= "function" then
        return false
    end
    SCENE_MANAGER:Show(MAP_SCENE)
    return true
end

function Integration.EnableMapInfoTab()
    local info = GAMEPAD_WORLD_MAP_INFO
    if type(info) ~= "table" or type(info.tabBarEntries) ~= "table"
        or type(info.baseHeaderData) ~= "table"
        or info.baseHeaderData.tabBarEntries ~= info.tabBarEntries
        or type(info.Hide) ~= "function"
        or not HasScene(MAP_SCENE) or not HasScene(CUSTOM_SCENE)
        or type(SCENE_MANAGER.Show) ~= "function"
        or type(CALLBACK_MANAGER) ~= "table"
        or type(CALLBACK_MANAGER.RegisterCallback) ~= "function"
        or type(ZO_GamepadGenericHeader_SetActiveTabIndex) ~= "function"
        or info.header == nil then
        return false
    end
    if mapInfoEntry then
        for _, entry in ipairs(info.tabBarEntries) do
            if entry == mapInfoEntry then return true end
        end
        return false
    end

    -- Put Inventory immediately before the native first tab, Quests. L1 from
    -- Quests opens Inventory, while R1 still reaches every native tab. ESO's
    -- gamepad tab bar does not wrap from its first tab.
    if type(info.tabBarEntries[1]) ~= "table"
        or info.tabBarEntries[1].text ~= GetString(SI_MAP_INFO_MODE_QUESTS) then
        return false
    end
    -- Map Options removes its own header and content fragments asynchronously.
    -- Starting another scene in the tab callback can strand that header over
    -- the world. Wait for the native Hidden callback before changing scenes.
    CALLBACK_MANAGER:RegisterCallback("WorldMapInfo_Gamepad_Hidden", function()
        if not pendingMapInfoTransition then return end
        pendingMapInfoTransition = false
        -- The native header keeps its last active index across opens. Restore
        -- Quests while hidden so the next Map Options view is consistent.
        ZO_GamepadGenericHeader_SetActiveTabIndex(info.header, 2)
        if HasScene(CUSTOM_SCENE) then
            SCENE_MANAGER:Show(CUSTOM_SCENE)
        end
    end)
    local entry = {
        text = "Inventory",
        callback = function()
            if pendingMapInfoTransition or not HasScene(CUSTOM_SCENE) then return end
            pendingMapInfoTransition = true
            info:Hide()
        end,
    }
    table.insert(info.tabBarEntries, 1, entry)
    mapInfoEntry = entry
    return true
end
