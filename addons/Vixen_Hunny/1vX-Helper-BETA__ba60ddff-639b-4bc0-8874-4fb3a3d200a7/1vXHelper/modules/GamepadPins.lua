-- 1vX Helper - Gamepad pin screen
-- A gamepad list screen ("1vX Map Pins") inserted into the gamepad main menu directly
-- above Inventory, with: Map Choke Here / Map Safe Here / Kite Here / Remove Nearest Pin.
local addon = OneVXHelper
local G = {}
addon.Gamepad = G

local SCENE_NAME = "OneVXHelper_GamepadPins"
local TITLE      = "1vX Map Pins"
local ICON       = "/esoui/art/mappins/ui_worldmap_pin_customdestination.dds"
local TEMPLATE   = "ZO_GamepadMenuEntryTemplate"

local ACTIONS = {
    { key = "choke",  text = "Map Choke Here" },
    { key = "safe",   text = "Map Safe Here" },
    { key = "kite",   text = "Kite Here" },
    { key = "remove", text = "Remove Nearest Pin" },
}

local function Notify(msg)
    if not msg then return end
    if ZO_Alert then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, msg)
    end
end

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------
if not (ZO_Gamepad_ParametricList_Screen and ZO_Gamepad_ParametricList_Screen.Subclass) then
    function G.Init() error("gamepad list screen not available on this game version") end
    function G.Show() addon.Print("Gamepad pin screen unavailable on this game version.") end
    function G.Apply() end
    return
end

local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()

function Screen:Initialize(control)
    local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, scene)
    self.scene = scene

    local function Add(fragment)
        if fragment and not scene:HasFragment(fragment) then scene:AddFragment(fragment) end
    end
    if FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    end
    Add(ZO_SimpleSceneFragment:New(control))
    Add(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    Add(MINIMIZE_CHAT_FRAGMENT)
    Add(GAMEPAD_MENU_SOUND_FRAGMENT)
    Add(self.headerFragment)

    self.headerData = { titleText = TITLE }

    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_GAMEPAD_SELECT_OPTION),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() self:ActivateSelected() end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end

function Screen:SetupList(list)
    list:AddDataTemplate(TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

function Screen:RefreshHeader()
    local count, mapName = addon.Pins.CountCurrentMap()
    self.headerData.data1HeaderText = "Map"
    self.headerData.data1Text = mapName
    self.headerData.data2HeaderText = "1vX Pins"
    self.headerData.data2Text = tostring(count)
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
end

function Screen:PerformUpdate()
    self.dirty = false
    local list = self:GetMainList()
    list:Clear()
    for _, action in ipairs(ACTIONS) do
        local text = addon.Pins.TYPES[action.key] and addon.Pins.ColorText(action.key, action.text) or action.text
        local entry = ZO_GamepadEntryData:New(text, ICON)
        entry:SetIconTintOnSelection(true)
        entry.oneVXAction = action.key
        list:AddEntry(TEMPLATE, entry)
    end
    list:Commit()
    self:RefreshHeader()
end

function Screen:OnShowing()
    if ZO_Gamepad_ParametricList_Screen.OnShowing then
        ZO_Gamepad_ParametricList_Screen.OnShowing(self)
    end
    self:PerformUpdate()
end

function Screen:ActivateSelected()
    local data = self:GetMainList():GetTargetData()
    if not data or not data.oneVXAction then return end
    local msg
    if data.oneVXAction == "remove" then
        msg = addon.Pins.RemoveNearest()
    else
        msg = addon.Pins.AddAtPlayer(data.oneVXAction)
    end
    Notify(msg)
    self:RefreshHeader()
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function G.Show()
    if not IsInGamepadPreferredMode() then
        addon.Print("The 1vX gamepad screen is for gamepad mode - use the keybinds or /1vx kite|safe|choke on keyboard.")
        return
    end
    if not G.screen then return end
    if not SCENE_MANAGER:IsShowing(SCENE_NAME) then
        SCENE_MANAGER:Push(SCENE_NAME)
    end
end

---------------------------------------------------------------------------
-- Gamepad main menu entry (inserted directly above Inventory)
---------------------------------------------------------------------------
local menuEntry
local inserted, busy = false, false
local lastTemplate

local function IsInventoryEntry(data)
    if type(data) ~= "table" or data == menuEntry then return false end
    if type(data.data) == "table" and data.data.scene == "gamepad_inventory_root" then return true end
    return data.text ~= nil and data.text == GetString(SI_MAIN_MENU_INVENTORY)
end

local function MenuEnabled()
    return addon.sv and addon.sv.gamepad.menuEntry
end

local function WrapList(list)
    if not list or list.oneVXWrapped then return end
    list.oneVXWrapped = true
    local origAdd, origAddHeader = list.AddEntry, list.AddEntryWithHeader

    list.AddEntry = function(self, template, data, ...)
        if not busy then lastTemplate = template end
        if not busy and not inserted and MenuEnabled() and IsInventoryEntry(data) then
            inserted = true
            busy = true
            origAdd(self, template, menuEntry)
            busy = false
        end
        return origAdd(self, template, data, ...)
    end

    if origAddHeader then
        list.AddEntryWithHeader = function(self, template, data, ...)
            if not busy and not inserted and MenuEnabled() and IsInventoryEntry(data) then
                -- our entry takes over the section header, Inventory goes right below it
                inserted = true
                busy = true
                menuEntry.header = data.header
                origAddHeader(self, template, menuEntry, ...)
                origAdd(self, template, data)
                busy = false
                return
            end
            return origAddHeader(self, template, data, ...)
        end
    end
end

local function HookMainMenu()
    local menu = MAIN_MENU_GAMEPAD
    if not (menu and menu.RefreshMainList) then return false end

    menuEntry = ZO_GamepadEntryData:New(TITLE, ICON)
    menuEntry:SetIconTintOnSelection(true)
    menuEntry.data = {
        name = TITLE,
        icon = ICON,
        scene = SCENE_NAME,
        activatedCallback = G.Show,
    }

    ZO_PreHook(menu, "RefreshMainList", function(self)
        inserted = false
        WrapList(self.mainList)
    end)
    SecurePostHook(menu, "RefreshMainList", function(self)
        -- fallback: Inventory entry not found -> append at the end
        if not inserted and lastTemplate and MenuEnabled() and self.mainList then
            inserted = true
            self.mainList:AddEntry(lastTemplate, menuEntry)
            self.mainList:Commit()
        end
    end)
    return true
end

function G.Apply()
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.mainList and SCENE_MANAGER:IsShowing("mainMenuGamepad") then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end
end

function G.Init()
    local control = OneVXHelper_GamepadPinsTL
    if control and ZO_Gamepad_ParametricList_Screen then
        local screen = ZO_Object.New(Screen)
        screen:Initialize(control)
        G.screen = screen
    end
    if G.screen and not HookMainMenu() then
        addon.Print("Couldn't add the gamepad menu entry - use /1vx pad or the keybind instead.")
    end
end
