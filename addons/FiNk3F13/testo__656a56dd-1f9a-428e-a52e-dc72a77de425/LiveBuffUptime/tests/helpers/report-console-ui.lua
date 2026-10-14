return function(env)
local create = WINDOW_MANAGER.CreateTopLevelWindow
function WINDOW_MANAGER:CreateTopLevelWindow(name)
    local control = create(self, name)
    local anchor = control.SetAnchor
    function control:SetAnchor(point, relative, relativePoint, x, y)
        self.anchorRelative = relative
        anchor(self, point, relative, relativePoint, x, y)
    end
    function control:SetScale(value) self.scale = value end
    return control
end
ZO_SharedGamepadNavQuadrant_2_Background = WINDOW_MANAGER:CreateTopLevelWindow("TestQuadrant2")
ZO_SharedGamepadNavQuadrant_2_Background:SetDimensions(420, 850)
function IsConsoleUI() return false end
function IsInGamepadPreferredMode() return true end
FRAGMENT_GROUP = { GAMEPAD_DRIVEN_UI_WINDOW = {} }
local nativeList = { entries = {} }
nativeList.headerFragment = { kind = "header" }
nativeList.listFragment = { kind = "list" }
function nativeList:AddDataTemplate(name) assert(name == "ZO_GamepadMenuEntryTemplate") end
function nativeList:SetNoItemText(text) self.empty = text end
function nativeList:SetOnSelectedDataChangedCallback(callback) self.callback = callback end
function nativeList:Clear() self.entries = {} end
function nativeList:AddEntry(_, entry) self.entries[#self.entries + 1] = entry end
function nativeList:Commit() end
function nativeList:SetSelectedIndex(index)
    self.index = index
    self.callback(self, self.entries[index])
end
function nativeList:GetSelectedIndex() return self.index end
function nativeList:Activate() self.active = true end
function nativeList:Deactivate() self.active = false end
ZO_GamepadEntryData = { New = function(_, text, icon)
    return { text = text, icon = icon, AddSubLabel = function(self, value) self.subtitle = value end }
end }
ZO_SharedGamepadEntry_OnSetup = function() end
ZO_GamepadMenuEntryTemplateParametricListFunction = function() end
local base = {}
ZO_Gamepad_ParametricList_Screen = base
function base:Subclass() return setmetatable({}, { __index = self }) end
function base:New(control)
    local obj = setmetatable({}, { __index = self })
    obj:Initialize(control)
    return obj
end
function base.Initialize(self, control)
    self.control = control
    self:InitializeKeybindStripDescriptors()
end
function base:GetMainList() return nativeList end
function base:GetHeaderFragment() return nativeList.headerFragment end
function base:GetListFragment() return nativeList.listFragment end
function base:SetCurrentList(list) assert(list == nativeList); nativeList.current = true end
ZO_Scene = { New = function()
    local scene = { fragments = {}, AddFragmentGroup = function() end,
        AddFragment = function(self, fragment) self.fragments[fragment] = true end,
        RegisterCallback = function(self, _, callback) self.callback = callback end }
    nativeList.scene = scene
    return scene
end }
ZO_FadeSceneFragment = { New = function(_, control) return control end }
local template
function WINDOW_MANAGER:CreateControlFromVirtual(name, _, value)
    assert(value == "LiveBuffUptimeReportScreenTemplate", "Native list must be instantiated as a top-level screen, not a bare Control")
    template = value
    return self:CreateTopLevelWindow(name)
end
function SCENE_MANAGER:Push(name) self.pushed = name end
function SCENE_MANAGER:Show(name) self.shown = name end


    return nativeList
end

