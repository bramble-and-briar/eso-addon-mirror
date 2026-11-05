local PvPUA = PvPUA
local U = PvPUA.util
local ScreenBounds = U.ScreenBounds

--------------------------------------------------
-- Move / Scale
--------------------------------------------------
local Move = {}
PvPUA.Move = Move

local MOVE_SCENE = "PvPUA_Move"
local MOVE_SPEED = 500

local PLACE_FRAGMENTS = {
    "PLAYER_ATTRIBUTE_BARS_FRAGMENT",
    "BUFF_DEBUFF_FRAGMENT",
    "COMPASS_FRAME_FRAGMENT",
    "UNIT_FRAMES_FRAGMENT",
}

PvPUA.MOVE_TIP = "Move it with the left stick and scale it with the right stick."

function PvPUA:CenterBounds()
    local w, h = ScreenBounds()
    return -w / 2, w / 2, -h / 2, h / 2
end

function PvPUA:ScreenEdges()
    local w, h = ScreenBounds()
    return 0, w, 0, h
end

--------------------------------------------------
-- Input
--------------------------------------------------
Move.input = {}

function Move.input:UpdateDirectionalInput(deltaS)
    local target = Move.target
    if not target then return end
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        Move:SetPosition(Move.x + x * MOVE_SPEED * deltaS, Move.y - y * MOVE_SPEED * deltaS)
    end
    local _, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if scaleY ~= 0 then
        Move:SetSize(Move.size + scaleY * target.sizeSpeed * deltaS)
    end
end

Move.keybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() Move:End(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() Move:ToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() Move:End(false) end,
    },
}

--------------------------------------------------
-- Changes
--------------------------------------------------
function Move:SetPosition(x, y)
    local target = self.target
    local minX, maxX, minY, maxY = target.bounds()
    self.x = zo_clamp(x, minX, maxX)
    self.y = zo_clamp(y, minY, maxY)
    target.setPosition(zo_floor(self.x + 0.5), zo_floor(self.y + 0.5))
end

function Move:SetSize(size)
    local target = self.target
    self.size = zo_clamp(size, target.sizeMin, target.sizeMax)
    local rounded = zo_floor(self.size + 0.5)
    if rounded ~= self.appliedSize then
        self.appliedSize = rounded
        target.setSize(rounded)
    end
end

function Move:ToDefault()
    local target = self.target
    if not target then return end
    self:SetSize(target.defaultSize)
    self:SetPosition(target.defaultX, target.defaultY)
end

local function Raise(controls, raise)
    for i = 1, #controls do
        local control = controls[i]
        if control then
            if raise then
                control.pvpuaTier = control:GetDrawTier()
                control:SetDrawTier(DT_HIGH)
            elseif control.pvpuaTier then
                control:SetDrawTier(control.pvpuaTier)
                control.pvpuaTier = nil
            end
        end
    end
end

--------------------------------------------------
-- Scene
--------------------------------------------------
function Move:GetScene()
    if self.scene then return self.scene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    for i = 1, #PLACE_FRAGMENTS do
        local fragment = rawget(_G, PLACE_FRAGMENTS[i])
        if fragment then scene:AddFragment(fragment) end
    end
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            Move:OnShowing()
        elseif newState == SCENE_HIDDEN then
            Move:OnHidden()
        end
    end)
    self.scene = scene
    return scene
end

function PvPUA:StartMove(target)
    if Move.target or not target then return end
    Move.target = target
    Move.saved = false
    PvPUA.placing = true
    Move:GetScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function Move:OnShowing()
    local target = self.target
    if not target then return end
    self.startX, self.startY = target.getPosition()
    self.startSize = target.getSize()
    self.x, self.y = self.startX, self.startY
    self.size = self.startSize
    self.appliedSize = self.startSize
    PvPUA.placing = true
    target.setMoving(true)
    Raise(target.controls(), true)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
    DIRECTIONAL_INPUT:Activate(self.input, target.controls()[1])
    PvPUA:RefreshPlacing()
end

function Move:OnHidden()
    local target = self.target
    if not target then return end
    DIRECTIONAL_INPUT:Deactivate(self.input)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
    if not self.saved then
        self:SetSize(self.startSize)
        self:SetPosition(self.startX, self.startY)
    end
    Raise(target.controls(), false)
    target.setMoving(false)
    PvPUA.placing = false
    self.target = nil
    if target.onDone then target.onDone() end
    PvPUA:RefreshPlacing()
end

function Move:End(save)
    if not self.target then return end
    self.saved = save == true
    if save then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
end

--------------------------------------------------
-- Placing
--------------------------------------------------
function PvPUA:RefreshPlacing()
    local defs = self.effectAlertDefs
    if defs then
        for i = 1, #defs do
            self:EARefresh(defs[i].key)
        end
    end
    if self.Potion then self.Potion:RefreshDisplay() end
    if self.controls and self.controls.TLW then self:ApplyListVisibility() end
end
