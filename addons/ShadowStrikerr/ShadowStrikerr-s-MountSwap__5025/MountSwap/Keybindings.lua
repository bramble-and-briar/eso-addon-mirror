-- Optional integration with existing menu/search addons; no foreign code bundled.
local M = MountSwap
local function say(message) M:Chat(message) end
local function findPanel()
    -- Resolve optional addons during navigation, after their startup has completed.
    local addonKeybinds = libAddonKeybinds
    local gameMenu = ZO_GameMenu_InGame
    local menu = gameMenu and gameMenu.gameMenu
    local tree = menu and menu.navigationTree
    if not tree or not tree.ExecuteOnSubTree or not tree.SelectNode then return end
    local addonNode, standardNode
    local controlsName = GetString(SI_GAME_MENU_CONTROLS)
    local keybindingsName = GetString(SI_GAME_MENU_KEYBINDINGS)
    tree:ExecuteOnSubTree(nil, function(node)
        local data = node.data
        if data and data.categoryName == controlsName then
            if addonKeybinds and data.name == 'Addon Keybinds' then addonNode = node end
            if data.name == keybindingsName then standardNode = node end
        end
    end)
    return tree, addonNode or standardNode
end
function M:OpenKeybindings()
    if IsInGamepadPreferredMode() then
        if KEYBINDINGS_SCENE_GAMEPAD and SCENE_MANAGER.Push then
            self:CloseWindows()
            SCENE_MANAGER:Push('keybindings_gamepad')
            return
        end
        say('This shortcut opens keyboard Controls. Switch to keyboard mode and try again.'); return
    end
    self.keybindingsRequest = (self.keybindingsRequest or 0) + 1
    local request = self.keybindingsRequest
    self:ClosePicker()
    self:CloseWindows()
    local attempts = 0
    local function selectPanel()
        if request ~= self.keybindingsRequest then return end
        -- Do not navigate later if the user has already left the menu.
        if not SCENE_MANAGER:IsShowing('gameMenuInGame') then return end
        attempts = attempts + 1
        local tree, node = findPanel()
        if not node then
            if attempts < 10 then zo_callLater(selectPanel, 100)
            else say('Open Controls > Keybindings and search for MountSwap. The menu shortcut could not locate that panel.') end
            return
        end
        tree:SelectNode(node)
        local keybinder = VOTANS_KEYBINDER
        local searchBox = keybinder and keybinder.searchBox
        if searchBox and searchBox.SetText and keybinder.FilterTextChanged then
            searchBox:SetText('MountSwap')
            -- Its text handler is focus-sensitive; explicitly invoke its filter API.
            keybinder:FilterTextChanged()
        else
            say('Keybindings opened. If your screen has a search box, enter MountSwap to find its actions.')
        end
    end
    SCENE_MANAGER:Show('gameMenuInGame')
    zo_callLater(selectPanel, 100)
end
