local L = LibUser562

--------------------------------------------------
-- Config
--------------------------------------------------
L.STRETCH_MIN = 50
L.STRETCH_MAX = 200

local MOVE_SCENE          = "LibUser562_Move"
local DEFAULT_MOVE_SPEED  = 500
local DEFAULT_SCALE_SPEED = 10
local STRETCH_SPEED       = 60
local RAISED_TIER         = DT_MEDIUM

local PLACE_FRAGMENTS = {
    "PLAYER_ATTRIBUTE_BARS_FRAGMENT",
    "BUFF_DEBUFF_FRAGMENT",
    "COMPASS_FRAME_FRAGMENT",
    "UNIT_FRAMES_FRAGMENT",
}

local active = nil
local saved  = false
local scene  = nil
local state  = {}
local mover  = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function Round(value)
    return zo_floor(value + 0.5)
end

local function Bounds()
    if type(active.bounds) == "function" then
        local minX, maxX, minY, maxY = active.bounds()
        if minX and maxX and minY and maxY then return minX, maxX, minY, maxY end
    end
    local screenW, screenH = GuiRoot:GetDimensions()
    return 0, screenW, 0, screenH
end

local function Raise(raise)
    local controls = active.controls
    if type(controls) == "function" then controls = controls() end
    if type(controls) ~= "table" then return end
    for i = 1, #controls do
        local control = controls[i]
        if control and control.SetDrawTier then
            if raise then
                control.libUser562Tier = control:GetDrawTier()
                control:SetDrawTier(RAISED_TIER)
            elseif control.libUser562Tier then
                control:SetDrawTier(control.libUser562Tier)
                control.libUser562Tier = nil
            end
        end
    end
end

local function InputControl()
    if active.inputControl then return active.inputControl end
    local controls = active.controls
    if type(controls) == "function" then controls = controls() end
    return type(controls) == "table" and controls[1] or nil
end

--------------------------------------------------
-- Values
--------------------------------------------------
local function SetPosition(x, y, force)
    local minX, maxX, minY, maxY = Bounds()
    state.x = zo_clamp(x, minX, maxX)
    state.y = zo_clamp(y, minY, maxY)
    local roundX, roundY = Round(state.x), Round(state.y)
    if force or roundX ~= state.roundX or roundY ~= state.roundY then
        state.roundX, state.roundY = roundX, roundY
        active.setPosition(roundX, roundY)
    end
end

local function SetSize(size, force)
    if type(active.setSize) ~= "function" then return end
    state.size = zo_clamp(size, active.sizeMin or size, active.sizeMax or size)
    local rounded = Round(state.size)
    if force or rounded ~= state.roundSize then
        state.roundSize = rounded
        active.setSize(rounded)
    end
end

local function SetStretch(percent, force)
    if type(active.setStretch) ~= "function" then return end
    state.stretch = zo_clamp(percent, L.STRETCH_MIN, L.STRETCH_MAX)
    local rounded = Round(state.stretch)
    if force or rounded ~= state.roundStretch then
        state.roundStretch = rounded
        active.setStretch(rounded)
    end
end

local function ReadStart()
    local defaults = active.defaults or {}
    local x, y = active.getPosition()
    state.startX = tonumber(x) or defaults.x or 0
    state.startY = tonumber(y) or defaults.y or 0
    state.x, state.y = state.startX, state.startY
    state.roundX, state.roundY = Round(state.x), Round(state.y)

    if type(active.getSize) == "function" then
        state.startSize = tonumber(active.getSize()) or defaults.size or 0
        state.size = state.startSize
        state.roundSize = Round(state.size)
    end

    if type(active.getStretch) == "function" then
        state.startStretch = tonumber(active.getStretch()) or defaults.stretch or 100
        state.stretch = state.startStretch
        state.roundStretch = Round(state.stretch)
    end
end

local function MoveToDefault()
    if not active then return end
    local defaults = active.defaults or {}
    SetStretch(defaults.stretch or 100, true)
    if defaults.size then SetSize(defaults.size, true) end
    if defaults.x and defaults.y then SetPosition(defaults.x, defaults.y, true) end
end

--------------------------------------------------
-- Input
--------------------------------------------------
function mover:UpdateDirectionalInput(deltaS)
    if not active then return end
    local moveSpeed = active.moveSpeed or DEFAULT_MOVE_SPEED
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        SetPosition(state.x + x * moveSpeed * deltaS, state.y - y * moveSpeed * deltaS)
    end
    local stretchX, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if math.abs(stretchX) > math.abs(scaleY) then
        if state.stretch then SetStretch(state.stretch + stretchX * STRETCH_SPEED * deltaS) end
    elseif scaleY ~= 0 and state.size then
        SetSize(state.size + scaleY * (active.scaleSpeed or DEFAULT_SCALE_SPEED) * deltaS)
    end
end

local function EndMove(save)
    if not active then return end
    saved = save == true
    if saved then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
end

local keybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() EndMove(false) end,
    },
}

--------------------------------------------------
-- Scene
--------------------------------------------------
local function OnShowing()
    if not active then return end
    ReadStart()
    Raise(true)
    KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
    DIRECTIONAL_INPUT:Activate(mover, InputControl())
    if type(active.onShow) == "function" then active.onShow() end
end

local function OnHidden()
    if not active then return end
    DIRECTIONAL_INPUT:Deactivate(mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
    if not saved then
        if state.startSize then SetSize(state.startSize, true) end
        if state.startStretch then SetStretch(state.startStretch, true) end
        SetPosition(state.startX, state.startY, true)
    end
    Raise(false)
    local spec, wasSaved = active, saved
    active = nil
    saved = false
    state = {}
    if type(spec.onHide) == "function" then spec.onHide(wasSaved) end
end

local function Scene()
    if scene then return scene end
    scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    for i = 1, #PLACE_FRAGMENTS do
        local fragment = rawget(_G, PLACE_FRAGMENTS[i])
        if fragment then scene:AddFragment(fragment) end
    end
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            OnShowing()
        elseif newState == SCENE_HIDDEN then
            OnHidden()
        end
    end)
    return scene
end

--------------------------------------------------
-- API
--------------------------------------------------
function L:StartMove(spec)
    if active or type(spec) ~= "table" then return false end
    if type(spec.getPosition) ~= "function" or type(spec.setPosition) ~= "function" then return false end
    active = spec
    saved = false
    state = {}
    Scene()
    SCENE_MANAGER:Push(MOVE_SCENE)
    return true
end

function L:IsMoving()
    return active ~= nil
end

function L:ApplyStretch(control, percent, originX, originY)
    if not control or not control.SetTransformScaleX then return end
    local value = zo_clamp(tonumber(percent) or 100, L.STRETCH_MIN, L.STRETCH_MAX) / 100
    if control.SetTransformNormalizedOriginPoint then
        pcall(control.SetTransformNormalizedOriginPoint, control, originX or 0.5, originY or 0.5)
    end
    pcall(control.SetTransformScaleX, control, value)
end
