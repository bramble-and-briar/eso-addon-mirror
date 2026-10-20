local L = LibUser562
if not (L and L.IsSupported() and L.window) then return end

--------------------------------------------------
-- Config
--------------------------------------------------
local ENTRY_PREFIX   = "LibUser562_"
local ADDONS_HOST_ID = "LibUser562_Addons"
local ADDONS_ICON    = "/esoui/art/options/gamepad/gp_options_addons.dds"
local DEFAULT_ICON   = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"
local DEFAULT_AFTER  = "CAMPAIGN"
local ARROW_TEMPLATE = "ZO_GamepadMenuEntryTemplateWithArrow"

local playerActivated = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function ResolveText(value)
    if type(value) == "function" then value = value() end
    if value == nil then return "" end
    return tostring(value)
end

local function AddonsTitle()
    return GetString(SI_GAME_MENU_ADDONS)
end

local function EntryLabel(entry)
    if not entry then return "" end
    local text = entry.text
    if (text == nil or text == "") and entry.data then text = entry.data.name end
    return ResolveText(text)
end

local function SortKey(text)
    local plain = text:gsub("|c%x%x%x%x%x%x", "")
    plain = plain:gsub("|r", "")
    return plain:lower()
end

local function FindEntryIndex(id)
    for i = 1, #ZO_MENU_ENTRIES do
        if ZO_MENU_ENTRIES[i].id == id then return i end
    end
    return nil
end

local function MainIndex(key)
    local enum = ZO_MENU_MAIN_ENTRIES
    local id = enum and enum[key]
    if id == nil then return nil end
    return FindEntryIndex(id)
end

local function FindChild(id)
    for i = 1, #ZO_MENU_ENTRIES do
        local sub = ZO_MENU_ENTRIES[i].subMenu
        if type(sub) == "table" then
            for j = 1, #sub do
                if sub[j].id == id then return sub[j] end
            end
        end
    end
    return nil
end

local function FindAddonsHosts()
    local own, foreign
    local title = AddonsTitle()
    for i = 1, #ZO_MENU_ENTRIES do
        local entry = ZO_MENU_ENTRIES[i]
        if entry.id == ADDONS_HOST_ID then
            own = own or i
        elseif type(entry.subMenu) == "table" and EntryLabel(entry) == title then
            foreign = foreign or i
        end
    end
    return own, foreign
end

local function InsertSorted(list, entry)
    local key = SortKey(EntryLabel(entry))
    for i = 1, #list do
        if SortKey(EntryLabel(list[i])) > key then
            table.insert(list, i, entry)
            return
        end
    end
    list[#list + 1] = entry
end

--------------------------------------------------
-- Entries
--------------------------------------------------
local function NewEntry(id, data)
    local entry = ZO_GamepadEntryData:New(data.name, data.icon)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.id = id
    entry.data = data
    return entry
end

local function PanelEntry(panel)
    local menu = panel.menu
    local id = ENTRY_PREFIX .. panel.name
    return NewEntry(id, {
        id    = id,
        name  = ResolveText(menu.menuTitle or menu.title or panel.name),
        icon  = menu.menuIcon or DEFAULT_ICON,
        scene = panel.SCENE_NAME,
    })
end

local function CreateAddonsHost()
    local host = NewEntry(ADDONS_HOST_ID, {
        id             = ADDONS_HOST_ID,
        name           = AddonsTitle(),
        icon           = ADDONS_ICON,
        customTemplate = ARROW_TEMPLATE,
        subMenu        = {},
    })
    host.subMenu = {}
    local index = MainIndex("ACTIVITY_FINDER")
    if index then
        table.insert(ZO_MENU_ENTRIES, index, host)
    else
        table.insert(ZO_MENU_ENTRIES, host)
    end
    return host
end

--------------------------------------------------
-- Placement
--------------------------------------------------
local function PlaceMain(panel)
    local id = ENTRY_PREFIX .. panel.name
    if FindEntryIndex(id) then return false end
    local entry = PanelEntry(panel)
    local after = MainIndex(panel.menu.menuAfter or DEFAULT_AFTER)
    if after then
        table.insert(ZO_MENU_ENTRIES, after + 1, entry)
    else
        table.insert(ZO_MENU_ENTRIES, entry)
    end
    return true
end

local function PlaceAddons(panel, allowCreate)
    if FindChild(ENTRY_PREFIX .. panel.name) then return false end
    local own, foreign = FindAddonsHosts()
    local host
    if foreign then
        host = ZO_MENU_ENTRIES[foreign]
    elseif own then
        host = ZO_MENU_ENTRIES[own]
    elseif allowCreate then
        host = CreateAddonsHost()
    else
        return false
    end
    InsertSorted(host.subMenu, PanelEntry(panel))
    return true
end

local function Place(panel, allowCreate)
    if panel.menu.placement == "main" then
        return PlaceMain(panel)
    end
    return PlaceAddons(panel, allowCreate)
end

local function MergeAddonsHosts()
    local own, foreign = FindAddonsHosts()
    if not (own and foreign) then return false end
    local children = ZO_MENU_ENTRIES[own].subMenu or {}
    local target = ZO_MENU_ENTRIES[foreign].subMenu
    for i = 1, #children do
        InsertSorted(target, children[i])
    end
    table.remove(ZO_MENU_ENTRIES, own)
    return true
end

local function RefreshMenu()
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.UpdateEntryEnabledStates then
        MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
    end
end

local function PlaceAll(allowCreate)
    if not ZO_MENU_ENTRIES then return end
    local changed = false
    for i = 1, #L.panelList do
        if Place(L.panelList[i], allowCreate) then changed = true end
    end
    if MergeAddonsHosts() then changed = true end
    if changed then RefreshMenu() end
end

function L.PlaceInMenu(panel)
    if not (playerActivated and ZO_MENU_ENTRIES) then return end
    if Place(panel, false) then RefreshMenu() end
end

--------------------------------------------------
-- Wiring
--------------------------------------------------
EVENT_MANAGER:RegisterForEvent("LibUser562_MainMenu", EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent("LibUser562_MainMenu", EVENT_PLAYER_ACTIVATED)
    playerActivated = true
    PlaceAll(false)
end)

local function PlaceAfterBuild()
    PlaceAll(true)
end

if MAIN_MENU_GAMEPAD_SCENE then
    MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState ~= SCENE_SHOWING then return end
        PlaceAll(false)
        zo_callLater(PlaceAfterBuild, 0)
    end)
end
