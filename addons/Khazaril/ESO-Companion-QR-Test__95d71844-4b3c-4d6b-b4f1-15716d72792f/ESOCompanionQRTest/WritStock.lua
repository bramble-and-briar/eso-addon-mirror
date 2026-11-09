-- WritStock.lua
-- Hides "writ stock" (items crafted by any of your characters) from the lists where it gets in
-- the way: the merchant's Sell list, deconstruction at crafting stations, and universal
-- deconstruction (the Ragpicker assistant). Clicking the right stick on those screens shows or
-- hides them again. Gamepad screens only, which is what consoles use.
--
-- Hook points (from ZeniMax's published UI source, game version 12.1.6):
--   * Sell: STORE_WINDOW_GAMEPAD.components[ZO_MODE_STORE_SELL].list.updateFunc builds the list.
--   * Deconstruction: ZO_GamepadExtractionInventory and ZO_UniversalDeconstructionInventory_Gamepad
--     both put their rows on screen through AddFilteredDataToList (inherited from
--     ZO_GamepadCraftingInventory); we override it on those two subclasses only, so crafting
--     creation and improvement lists are untouched.
--   * Toggle button: GAMEPAD_SMITHING_DECONSTRUCT_SCENE and UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE add
--     their buttons on SCENE_SHOWING and remove them on SCENE_HIDDEN; we do the same.

ESOC_WritStock = ESOC_WritStock or {}
local WS = ESOC_WritStock

local settings = { hide = true }
local myNames = nil
WS.hiddenCount = 0

local function norm(name)
    local s = name or ""
    local ok, formatted = pcall(zo_strformat, "<<1>>", s)
    if ok and type(formatted) == "string" then s = formatted end
    return s:lower()
end

-- Names of every character on this account (crafted items record the crafter's character name)
local function loadNames()
    myNames = {}
    pcall(function()
        for i = 1, GetNumCharacters() do
            local name = GetCharacterInfo(i)
            if name and name ~= "" then myNames[norm(name)] = true end
        end
    end)
    pcall(function() myNames[norm(GetUnitName("player"))] = true end)
end

function WS.IsWritStock(bagId, slotIndex)
    if not myNames then loadNames() end
    local ok, creator = pcall(GetItemCreatorName, bagId, slotIndex)
    if not ok or not creator or creator == "" then return false end
    return myNames[norm(creator)] == true
end

function WS.IsHiding()
    return settings.hide
end

---------------------------------------------------------------------------
-- The right-stick toggle, added next to each screen's own buttons
---------------------------------------------------------------------------
local refreshCurrent = nil
local toggleGroup = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = function()
            if settings.hide then
                return WS.hiddenCount > 0 and string.format("Show writ stock (%d)", WS.hiddenCount) or "Show writ stock"
            end
            return "Hide writ stock"
        end,
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        callback = function()
            settings.hide = not settings.hide
            if refreshCurrent then pcall(refreshCurrent) end
            KEYBIND_STRIP:UpdateKeybindButtonGroup(WS.toggleGroup)
        end,
    },
}
WS.toggleGroup = toggleGroup

local function showToggle(refresh)
    refreshCurrent = refresh
    KEYBIND_STRIP:RemoveKeybindButtonGroup(toggleGroup)
    KEYBIND_STRIP:AddKeybindButtonGroup(toggleGroup)
end

local function hideToggle()
    refreshCurrent = nil
    KEYBIND_STRIP:RemoveKeybindButtonGroup(toggleGroup)
end

local function updateToggle()
    pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(toggleGroup) end)
end

---------------------------------------------------------------------------
-- Filtering
---------------------------------------------------------------------------
-- Removes writ stock from a list of item data tables in place; returns how many were removed.
function WS.FilterInPlace(items)
    if not settings.hide then return 0 end
    local kept, removed = 0, 0
    for i = 1, #items do
        local data = items[i]
        if data and data.bagId and data.slotIndex and WS.IsWritStock(data.bagId, data.slotIndex) then
            removed = removed + 1
        else
            kept = kept + 1
            items[kept] = data
        end
    end
    for i = #items, kept + 1, -1 do items[i] = nil end
    return removed
end

local function hookSell()
    local component = STORE_WINDOW_GAMEPAD and STORE_WINDOW_GAMEPAD.components
        and STORE_WINDOW_GAMEPAD.components[ZO_MODE_STORE_SELL]
    local list = component and component.list
    if not list or not list.updateFunc then return false end
    local original = list.updateFunc
    list.updateFunc = function(...)
        local items = original(...)
        WS.hiddenCount = WS.FilterInPlace(items)
        updateToggle()
        return items
    end
    component.fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_SHOWING then
            showToggle(function() list:UpdateList() end)
        elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_HIDING then
            hideToggle()
        end
    end)
    return true
end

local function hookInventoryClass(class)
    if not class then return false end
    local original = class.AddFilteredDataToList -- inherited from ZO_GamepadCraftingInventory
    class.AddFilteredDataToList = function(self, filteredDataTable)
        WS.hiddenCount = WS.FilterInPlace(filteredDataTable)
        updateToggle()
        return original(self, filteredDataTable)
    end
    return true
end

-- The deconstruction screens add their buttons straight from their scene's StateChange callback
-- (they never call their own AddKeybinds), so the toggle follows the scene too.
local function hookScene(scene, panel)
    if not scene or not scene.RegisterCallback or not panel or not panel.inventory then return false end
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            showToggle(function() panel.inventory:PerformFullRefresh() end)
        elseif newState == SCENE_HIDDEN then
            hideToggle()
        end
    end)
    return true
end

-- Called once from the add-on's load event with its saved settings table.
-- Returns a short report of what was hooked, for the status banner.
function WS.Init(saved)
    if saved then
        if saved.hideWritStock == nil then saved.hideWritStock = true end
        settings = setmetatable({}, {
            __index = function(_, k) if k == "hide" then return saved.hideWritStock end end,
            __newindex = function(_, k, v) if k == "hide" then saved.hideWritStock = v end end,
        })
    end
    local done = {}
    local function try(label, fn)
        local ok, result = pcall(fn)
        if ok and result then done[#done + 1] = label end
    end
    try("sell", hookSell)
    try("deconstruct", function()
        local panel = SMITHING_GAMEPAD and SMITHING_GAMEPAD.deconstructionPanel
        return hookInventoryClass(ZO_GamepadExtractionInventory) and hookScene(GAMEPAD_SMITHING_DECONSTRUCT_SCENE, panel)
    end)
    try("ragpicker", function()
        local panel = UNIVERSAL_DECONSTRUCTION_GAMEPAD and UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel
        return hookInventoryClass(ZO_UniversalDeconstructionInventory_Gamepad)
            and hookScene(UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE, panel)
    end)
    return done
end
