PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The main menu entry and the scene behind it
--
-- The way PB's Ultra Detailed Stats does it (measured on PS5): the gamepad main menu is a list the
-- client builds from ZO_MENU_ENTRIES, so an entry is added to that list as data, with the name of our
-- scene in `data.scene`; the client pushes the scene when the entry is chosen. The scene is a ZO_Scene
-- of our own with the game's gamepad window fragment group; its keybinds go onto the keybind strip
-- while it is shown. Nothing of the client's is hooked or wrapped.
--
-- Where the entry goes: after PB's HPS Checker or PB's Ultra Detailed Stats when one of them is in
-- the list, else after the Character entry, else at the end.
---------------------------------------------------------------------------------------------------

local screen = ADDON.screen

local menu = { sceneName = "pbsBattleScrollsScreen" }
ADDON.menu = menu

local ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_character.dds"
local REFRESH_MS = 1000
local AFTER_SCENES = { "pbsHpsCheckerScreen", "pbsUltraDetailedStats", "gamepad_stats_root" }

function menu:Open()
    if SCENE_MANAGER and self.scene then
        SCENE_MANAGER:Push(self.sceneName)
    end
end

local function IndexOfScene(sceneName)
    for index, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.data and entry.data.scene == sceneName then
            return index
        end
    end
    return nil
end

-- Adds the entry once. Tried at load and again when a loading screen ends: the list may not be
-- there yet at load.
function menu:InstallMenu()
    if self.menuInstalled or not ZO_MENU_ENTRIES or not ZO_GamepadEntryData then
        return
    end
    if IndexOfScene(self.sceneName) then
        self.menuInstalled = true
        return
    end
    local name = GetString(SI_PBSBS_MENU_NAME)
    local entry = ZO_GamepadEntryData:New(name, ICON)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry:SetEnabled(true)
    -- A string key does not collide with the client's numeric entry ids.
    entry.id = ADDON.name
    entry.data = { name = name, icon = ICON, scene = self.sceneName }
    local at
    for _, sceneName in ipairs(AFTER_SCENES) do
        at = IndexOfScene(sceneName)
        if at then
            break
        end
    end
    table.insert(ZO_MENU_ENTRIES, at and (at + 1) or (#ZO_MENU_ENTRIES + 1), entry)
    self.menuInstalled = true
end

function menu:Initialize()
    self.scene = ZO_Scene:New(self.sceneName, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    local binds = screen:Keybinds()
    self.binds = binds

    self.scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(binds)
            screen:Refresh()
            if screen.root and not self.fragment then
                self.fragment = ZO_FadeSceneFragment:New(screen.root)
                self.scene:AddFragment(self.fragment)
            end
            -- Redrawn only while it is on screen (a fight going on changes).
            EVENT_MANAGER:RegisterForUpdate(ADDON.name .. "Screen", REFRESH_MS, function() screen:Refresh() end)
        elseif state == SCENE_HIDING then
            EVENT_MANAGER:UnregisterForUpdate(ADDON.name .. "Screen")
            KEYBIND_STRIP:RemoveKeybindButtonGroup(binds)
        end
    end)

    self:InstallMenu()
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "Menu", EVENT_PLAYER_ACTIVATED, function() self:InstallMenu() end)
end
