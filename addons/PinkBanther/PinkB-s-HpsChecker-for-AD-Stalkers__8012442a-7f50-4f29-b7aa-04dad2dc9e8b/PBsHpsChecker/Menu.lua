PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- The main menu entry and the scene behind it
--
-- Done the way PB's Ultra Detailed Stats does it, which is measured on PS5: the gamepad main menu is a
-- list the client builds from ZO_MENU_ENTRIES, so an entry is added to that list as data (the same
-- thing the client's own CreateEntry makes), with the name of a scene in its `data.scene`; the client
-- pushes that scene when the entry is chosen. The scene is a ZO_Scene of our own with the game's
-- gamepad window fragment group, whose keybinds are added to the keybind strip when it is shown and
-- taken off when it is hidden, and whose one fragment is the screen (Screen.lua).
--
-- Nothing of the client's is hooked or wrapped: an entry is data, and the scene registers beside the
-- client's own callbacks.
--
-- Where the entry goes: right after "ステータス超詳細" (PB's Ultra Detailed Stats) when that is in the
-- list. If it has not been added yet when this add-on loads, this entry goes after the Character
-- entry, and Ultra Detailed Stats, which goes after the Character entry too, then lands between the
-- two: the same order. With neither add-on's neighbour there, the end of the list.
---------------------------------------------------------------------------------------------------

local screen = ADDON.screen

local menu = { sceneName = "pbsHpsCheckerScreen" }
ADDON.menu = menu

local ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_allianceWar.dds"
local REFRESH_MS = 2000
-- The entry to go after, and the one to go after when that is not there.
local ULTRA_SCENE = "pbsUltraDetailedStats"
local ULTRA_ID = "PBsUltraDetailedStats"
local CHARACTER_SCENE = "gamepad_stats_root"

function menu:Open()
    SCENE_MANAGER:Push(self.sceneName)
end

local function IndexOfEntry(match)
    for index, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.data and match(entry) then
            return index
        end
    end
    return nil
end

-- Adds the entry once. Tried at load and again when a loading screen ends, because the list may not
-- be there yet at load.
function menu:InstallMenu()
    if self.menuInstalled or not ZO_MENU_ENTRIES then
        return
    end
    local sceneName = self.sceneName
    if IndexOfEntry(function(entry) return entry.data.scene == sceneName end) then
        self.menuInstalled = true
        return
    end

    local name = GetString(SI_PBSHPS_MENU_NAME)
    local entry = ZO_GamepadEntryData:New(name, ICON)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry:SetEnabled(true)
    -- A string key does not collide with the client's own numeric entry ids.
    entry.id = ADDON.name
    entry.data = { name = name, icon = ICON, scene = sceneName }

    local after = IndexOfEntry(function(e) return e.data.scene == ULTRA_SCENE or e.id == ULTRA_ID end)
        or IndexOfEntry(function(e) return e.data.scene == CHARACTER_SCENE end)
    table.insert(ZO_MENU_ENTRIES, after and (after + 1) or (#ZO_MENU_ENTRIES + 1), entry)
    self.menuInstalled = true
end

function menu:Initialize()
    self.scene = ZO_Scene:New(self.sceneName, SCENE_MANAGER)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)

    local binds = screen:Keybinds()
    self.binds = binds
    -- A on the list of periods comes and goes with the page: the strip is told to look again.
    screen.onPageChanged = function()
        if KEYBIND_STRIP.UpdateKeybindButtonGroup then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(binds)
        end
    end

    self.scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(binds)
            screen:Refresh()
            -- The screen exists once Refresh has built it; it is the scene's fragment from then on.
            if screen.root and not self.fragment then
                self.fragment = ZO_FadeSceneFragment:New(screen.root)
                self.scene:AddFragment(self.fragment)
            end
            -- Polled only while it is on screen.
            EVENT_MANAGER:RegisterForUpdate(ADDON.name .. "Screen", REFRESH_MS, function() screen:Refresh() end)
        elseif state == SCENE_HIDING then
            EVENT_MANAGER:UnregisterForUpdate(ADDON.name .. "Screen")
            KEYBIND_STRIP:RemoveKeybindButtonGroup(binds)
        end
    end)

    self:InstallMenu()
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "Menu", EVENT_PLAYER_ACTIVATED, function() self:InstallMenu() end)
end
