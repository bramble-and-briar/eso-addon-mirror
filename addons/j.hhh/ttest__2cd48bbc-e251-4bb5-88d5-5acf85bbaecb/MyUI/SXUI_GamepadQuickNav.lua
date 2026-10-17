-- Satuve Xbox UI - controller navigation for the narrow BUI icon sidebar.
--
-- The sidebar is attached only to ESO's "mainMenuGamepad" scene. Directional
-- actions use native KEYBIND_STRIP callbacks; add-on code never calls
-- DIRECTIONAL_INPUT or IsKeyDown, which are protected by ESO's secure UI.

MyUI = MyUI or {}
MyUI.SidebarGamepad = MyUI.SidebarGamepad or {}
MyUI.GamepadQuickNav = MyUI.SidebarGamepad -- compatibility
local QuickNav = MyUI.SidebarGamepad

QuickNav.enabled = true
QuickNav.active = false
QuickNav.selectedIndex = QuickNav.selectedIndex or 1
QuickNav.lastIndex = QuickNav.lastIndex or 1
QuickNav.items = QuickNav.items or {}
QuickNav.hooked = false
QuickNav.keybindsAdded = false
QuickNav.sceneKeybindsAdded = false

local MAIN_MENU_SCENE_NAME = "mainMenuGamepad"

local function Global(name)
    return rawget(_G, name)
end

local function InGamepadMode()
    local fn = Global("IsInGamepadPreferredMode")
    return type(fn) ~= "function" or fn()
end

local function GetMainMenuScene()
    local scene = Global("MAIN_MENU_GAMEPAD_SCENE")
    if scene then return scene end
    local manager = Global("SCENE_MANAGER")
    return manager and manager.GetScene and manager:GetScene(MAIN_MENU_SCENE_NAME)
end

local function IsMainMenuShowing()
    local scene = GetMainMenuScene()
    if not scene then return false end
    if type(scene.IsShowing) == "function" then
        local ok, showing = pcall(scene.IsShowing, scene)
        if ok and showing then return true end
    end
    if type(scene.GetState) == "function" then
        local state = scene:GetState()
        return state == Global("SCENE_SHOWING") or state == Global("SCENE_SHOWN")
    end
    return false
end

local function GetCurrentList(menu)
    if not menu then return nil end
    if type(menu.GetCurrentList) == "function" then
        local ok, list = pcall(menu.GetCurrentList, menu)
        if ok then return list end
    end
    return menu._currentList or menu.currentList
end

local function IsCurrentList(menu, list)
    if not menu or not list then return false end
    if type(menu.IsCurrentList) == "function" then
        local ok, result = pcall(menu.IsCurrentList, menu, list)
        if ok then return result == true end
    end
    return GetCurrentList(menu) == list
end

local function SetCurrentList(menu, list)
    if not menu or not list or type(menu.SetCurrentList) ~= "function" then return false end
    return pcall(menu.SetCurrentList, menu, list)
end

local function DataIsDisabled(data)
    if not data then return true end
    if type(data.disabled) == "function" then
        local ok, disabled = pcall(data.disabled)
        return not ok or disabled == true
    end
    return data.disabled == true
end

local function ControlIsEnabled(control)
    if not control or type(control.IsEnabled) ~= "function" then return true end
    local ok, enabled = pcall(control.IsEnabled, control)
    return not ok or enabled ~= false
end

local function ButtonOrder(control)
    if control and type(control.GetTop) == "function" then
        local ok, top = pcall(control.GetTop, control)
        if ok and type(top) == "number" then return top end
    end
    if not control or not control.GetName then return 9999 end
    return tonumber(string.match(control:GetName() or "", "(%d+)$")) or 9999
end

function QuickNav:IsAvailable()
    local panel = Global("BUI_Panel")
    return self.enabled and InGamepadMode() and IsMainMenuShowing()
        and panel and panel.IsHidden and not panel:IsHidden()
end

function QuickNav:RefreshItems()
    local result = {}
    local previousControl = self.items[self.selectedIndex] or self.lastControl
    local panel = Global("BUI_Panel")
    if panel and not panel:IsHidden() and panel.GetNumChildren then
        for index = 1, panel:GetNumChildren() do
            local control = panel:GetChild(index)
            local data = control and control.data
            if control and data and type(data.func) == "function"
                and control.IsHidden and not control:IsHidden()
                and ControlIsEnabled(control) and not DataIsDisabled(data) then
                result[#result + 1] = control
            end
        end
    end
    table.sort(result, function(a, b)
        local aOrder, bOrder = ButtonOrder(a), ButtonOrder(b)
        if aOrder == bOrder and a.GetName and b.GetName then
            return (a:GetName() or "") < (b:GetName() or "")
        end
        return aOrder < bOrder
    end)
    self.items = result

    local restoredIndex
    if previousControl then
        for index, control in ipairs(result) do
            if control == previousControl then
                restoredIndex = index
                break
            end
        end
    end
    if #result == 0 then
        self.selectedIndex = 1
    else
        local wanted = restoredIndex or self.lastIndex or self.selectedIndex or 1
        self.selectedIndex = math.max(1, math.min(wanted, #result))
    end
    return result
end

function QuickNav:CreateHighlight()
    local panel = Global("BUI_Panel")
    local manager = Global("WINDOW_MANAGER")
    if not panel or not manager then return end

    if not self.highlight then
        local highlight = manager:CreateControl("BUI_SidebarGamepadFocus", panel, CT_BACKDROP)
        highlight:SetDrawLayer(DL_OVERLAY)
        highlight:SetDrawLevel(50)
        highlight:SetMouseEnabled(false)
        highlight:SetCenterColor(1, 1, 1, .10)
        highlight:SetEdgeColor(1, 1, 1, 1)
        highlight:SetEdgeTexture("", 8, 2, 2)
        highlight:SetHidden(true)
        self.highlight = highlight
    end

    if not self.selector then
        local selector = manager:CreateControl("BUI_SidebarGamepadSelector", panel, CT_TEXTURE)
        selector:SetDimensions(28, 28)
        selector:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_menu_rightArrow.dds")
        selector:SetTextureCoordsRotation(Global("ZO_PI") or math.pi)
        selector:SetColor(1, 1, 1, 1)
        selector:SetDrawLayer(DL_OVERLAY)
        selector:SetDrawLevel(51)
        selector:SetMouseEnabled(false)
        selector:SetHidden(true)
        self.selector = selector
    end
end

function QuickNav:RefreshHighlight()
    self:CreateHighlight()
    if not self.highlight or not self.selector then return end
    if not self.active then
        self.highlight:SetHidden(true)
        self.selector:SetHidden(true)
        return
    end
    self:RefreshItems()
    local selected = self.items[self.selectedIndex]
    if not selected then
        self.highlight:SetHidden(true)
        self.selector:SetHidden(true)
        return
    end
    self.lastControl = selected
    self.highlight:ClearAnchors()
    self.highlight:SetAnchor(TOPLEFT, selected, TOPLEFT, -4, -4)
    self.highlight:SetAnchor(BOTTOMRIGHT, selected, BOTTOMRIGHT, 4, 4)
    self.highlight:SetHidden(false)
    self.selector:ClearAnchors()
    self.selector:SetAnchor(LEFT, selected, RIGHT, 2, 0)
    self.selector:SetHidden(false)
end

function QuickNav:RefreshKeybinds()
    local strip = Global("KEYBIND_STRIP")
    if self.keybindsAdded and strip and strip.UpdateKeybindButtonGroup then
        strip:UpdateKeybindButtonGroup(self.keybindDescriptor)
    end
    if self.sceneKeybindsAdded and strip and strip.UpdateKeybindButtonGroup then
        strip:UpdateKeybindButtonGroup(self.sceneKeybindDescriptor)
    end
end

function QuickNav:Move(direction)
    if not self.active then return end
    self:RefreshItems()
    if #self.items == 0 then
        self:Deactivate(true)
        return
    end
    local oldIndex = self.selectedIndex
    self.selectedIndex = math.max(1, math.min(self.selectedIndex + direction, #self.items))
    self.lastIndex = self.selectedIndex
    self.lastControl = self.items[self.selectedIndex]
    self:RefreshHighlight()
    if oldIndex ~= self.selectedIndex then PlaySound("Click") end
end

function QuickNav:PauseMainMenu(menu)
    self.previousList = GetCurrentList(menu)
    if type(menu.DeactivateCurrentList) == "function" then
        menu:DeactivateCurrentList()
        self.mainMenuListPaused = true
    elseif self.previousList and type(self.previousList.Deactivate) == "function" then
        self.previousList:Deactivate()
        self.mainMenuListPaused = true
    end
    if type(menu.RemoveListKeybinds) == "function" then
        menu:RemoveListKeybinds()
        self.mainMenuKeybindsRemoved = true
    end
end

function QuickNav:RestoreMainMenu()
    local menu = Global("MAIN_MENU_GAMEPAD")
    if not menu or not IsMainMenuShowing() then return end

    local list = self.previousList or menu.mainList
    if list and not IsCurrentList(menu, list) then
        SetCurrentList(menu, list)
    elseif self.mainMenuListPaused and type(menu.ActivateCurrentList) == "function" then
        menu:ActivateCurrentList()
    elseif self.mainMenuListPaused and list and type(list.Activate) == "function" then
        list:Activate()
    end

    local function RestoreKeybindsAfterCurrentPress()
        if QuickNav.active or not IsMainMenuShowing() then return end
        if type(menu.AddListKeybinds) == "function" then menu:AddListKeybinds() end
        if type(menu.RefreshKeybinds) == "function" then menu:RefreshKeybinds() end
    end
    if self.mainMenuKeybindsRemoved then
        if type(zo_callLater) == "function" then
            zo_callLater(RestoreKeybindsAfterCurrentPress, 0)
        else
            RestoreKeybindsAfterCurrentPress()
        end
    elseif type(menu.RefreshKeybinds) == "function" then
        menu:RefreshKeybinds()
    end
end

function QuickNav:Deactivate(restoreMainMenu)
    if not self.active and not self.keybindsAdded then return end
    self.active = false
    self.lastIndex = self.selectedIndex or self.lastIndex or 1
    self.lastControl = self.items[self.selectedIndex] or self.lastControl

    if self.highlight then self.highlight:SetHidden(true) end
    if self.selector then self.selector:SetHidden(true) end

    local strip = Global("KEYBIND_STRIP")
    if self.keybindsAdded and strip and strip.RemoveKeybindButtonGroup then
        strip:RemoveKeybindButtonGroup(self.keybindDescriptor)
    end
    self.keybindsAdded = false

    if restoreMainMenu then self:RestoreMainMenu() end
    self.previousList = nil
    self.mainMenuListPaused = false
    self.mainMenuKeybindsRemoved = false
    self:RefreshKeybinds()
end

function QuickNav:Activate()
    if self.active or not self:IsAvailable() then return false end
    self:RefreshItems()
    if #self.items == 0 then return false end

    local menu = Global("MAIN_MENU_GAMEPAD")
    if not menu or not IsCurrentList(menu, menu.mainList) then return false end

    if self.lastControl then
        for index, control in ipairs(self.items) do
            if control == self.lastControl then
                self.selectedIndex = index
                break
            end
        end
    end
    self.selectedIndex = math.max(1, math.min(self.selectedIndex or self.lastIndex or 1, #self.items))
    self.lastIndex = self.selectedIndex
    self.active = true
    self:PauseMainMenu(menu)

    local strip = Global("KEYBIND_STRIP")
    if strip and strip.AddKeybindButtonGroup then
        strip:AddKeybindButtonGroup(self.keybindDescriptor)
        self.keybindsAdded = true
    end
    self:RefreshHighlight()
    self:RefreshKeybinds()
    PlaySound("Click")
    return true
end

function QuickNav:ActivateSelected()
    if not self.active or self.activating then return end
    self:RefreshItems()
    local control = self.items[self.selectedIndex]
    if not control then return end
    self.activating = true

    -- Release sidebar ownership first, then call the exact mouse action already
    -- installed by BUI_Panel. The icon itself remains the single action owner.
    self:Deactivate(true)
    local handler = control.GetHandler and control:GetHandler("OnMouseDown")
    if type(handler) == "function" then
        handler(control, Global("MOUSE_BUTTON_INDEX_LEFT") or 1, true)
    elseif control.data and type(control.data.func) == "function" then
        control.data.func(control)
    end

    if type(zo_callLater) == "function" then
        zo_callLater(function() self.activating = false end, 0)
    else
        self.activating = false
    end
end

QuickNav.keybindDescriptor = {
    alignment = Global("KEYBIND_STRIP_ALIGN_LEFT"),
    {
        name = "Select",
        keybind = "UI_SHORTCUT_PRIMARY",
        visible = function() return QuickNav.active end,
        callback = function() QuickNav:ActivateSelected() end,
    },
    {
        name = "Back",
        keybind = "UI_SHORTCUT_NEGATIVE",
        visible = function() return QuickNav.active end,
        callback = function()
            QuickNav:Deactivate(true)
            PlaySound("Click")
        end,
    },
}

QuickNav.sceneKeybindDescriptor = {
    alignment = Global("KEYBIND_STRIP_ALIGN_LEFT"),
    {
        name = "Open Add-on Sidebar",
        keybind = "UI_SHORTCUT_INPUT_LEFT",
        ethereal = true,
        visible = function()
            local menu = Global("MAIN_MENU_GAMEPAD")
            return not QuickNav.active and QuickNav:IsAvailable()
                and menu and IsCurrentList(menu, menu.mainList)
        end,
        callback = function() QuickNav:Activate() end,
    },
    {
        name = "Sidebar Up",
        keybind = "UI_SHORTCUT_INPUT_UP",
        ethereal = true,
        visible = function() return QuickNav.active end,
        callback = function() QuickNav:Move(-1) end,
    },
    {
        name = "Sidebar Down",
        keybind = "UI_SHORTCUT_INPUT_DOWN",
        ethereal = true,
        visible = function() return QuickNav.active end,
        callback = function() QuickNav:Move(1) end,
    },
    {
        name = "Main Menu",
        keybind = "UI_SHORTCUT_INPUT_RIGHT",
        ethereal = true,
        visible = function() return QuickNav.active end,
        callback = function()
            QuickNav:Deactivate(true)
            PlaySound("Click")
        end,
    },
    {
        name = "Keep Sidebar Focus",
        keybind = "UI_SHORTCUT_INPUT_LEFT",
        ethereal = true,
        visible = function() return QuickNav.active end,
        callback = function() end,
    },
}

function QuickNav:StopSceneInput()
    if self.active or self.keybindsAdded then self:Deactivate(false) end
    local strip = Global("KEYBIND_STRIP")
    if self.sceneKeybindsAdded and strip and strip.RemoveKeybindButtonGroup then
        strip:RemoveKeybindButtonGroup(self.sceneKeybindDescriptor)
    end
    self.sceneKeybindsAdded = false
end

function QuickNav:StartSceneInput()
    local strip = Global("KEYBIND_STRIP")
    if strip and strip.AddKeybindButtonGroup and not self.sceneKeybindsAdded then
        strip:AddKeybindButtonGroup(self.sceneKeybindDescriptor)
        self.sceneKeybindsAdded = true
        self:RefreshKeybinds()
    end
end

function QuickNav:Install()
    if self.hooked then return true end
    local menu = Global("MAIN_MENU_GAMEPAD")
    local scene = GetMainMenuScene()
    if not menu or not scene then return false end

    if type(scene.RegisterCallback) == "function" then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == Global("SCENE_SHOWING") or newState == Global("SCENE_SHOWN") then
                QuickNav:StartSceneInput()
            else
                QuickNav:StopSceneInput()
            end
        end)
    end
    if IsMainMenuShowing() then self:StartSceneInput() end
    self.hooked = true
    return true
end

local function TryInstall()
    if QuickNav:Install() then return end
    if type(zo_callLater) == "function" then zo_callLater(TryInstall, 1000) end
end

if EVENT_MANAGER and Global("EVENT_ADD_ON_LOADED") then
    EVENT_MANAGER:RegisterForEvent("SXUI_GamepadQuickNav", EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= "MyUI" then return end
        EVENT_MANAGER:UnregisterForEvent("SXUI_GamepadQuickNav", EVENT_ADD_ON_LOADED)
        TryInstall()
    end)
else
    TryInstall()
end
