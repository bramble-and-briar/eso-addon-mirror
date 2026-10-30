-- My UI: lock only the horizontal dimensions of native ESO player attribute bars.
-- Food and max-stat buffs cause ESO to rebuild the background, fill and frame.
-- Constrain each horizontal component instead of hiding the outline or resizing height.
BUI.AttributeWidth = BUI.AttributeWidth or {}
local M = BUI.AttributeWidth
local names = {"ZO_PlayerAttributeHealth", "ZO_PlayerAttributeMagicka", "ZO_PlayerAttributeStamina"}
local busy = false

local function LockWidth(control, width)
    if not control or not control.SetWidth or not control.GetWidth then return end
    width = math.max(1, width)
    if control.SetDimensionConstraints and control._myuiLockedWidth ~= width then
        -- Zero minimum height and generous maximum height: width only.
        control:SetDimensionConstraints(width, 0, width, 10000)
        control._myuiLockedWidth = width
    end
    if math.abs(control:GetWidth() - width) > 0.01 then control:SetWidth(width) end
end

local function Child(control, suffix)
    if not control then return nil end
    return (control.GetNamedChild and control:GetNamedChild(suffix))
        or (control.GetName and _G[control:GetName() .. suffix])
end

local function LockSegment(control, width, leftName, centerName, rightName)
    if not control then return end
    LockWidth(control, width)
    local left, center, right = Child(control, leftName), Child(control, centerName), Child(control, rightName)
    if center then
        local leftWidth = (left and left.GetWidth and left:GetWidth()) or 0
        local rightWidth = (right and right.GetWidth and right:GetWidth()) or 0
        LockWidth(center, width - leftWidth - rightWidth)
    end
end

local function Reflow(control, width)
    if not control then return end
    LockWidth(control, width)

    -- ESO's normal background and outer frame must have the SAME horizontal width.
    local bg = Child(control, "BgContainer")
    LockSegment(bg, width, "BgLeft", "BgCenter", "BgRight")
    local left, right = Child(control, "FrameLeft"), Child(control, "FrameRight")
    local center = Child(control, "FrameCenter")
    if center then
        local leftWidth = (left and left:GetWidth()) or 0
        local rightWidth = (right and right:GetWidth()) or 0
        LockWidth(center, width - leftWidth - rightWidth)
    end

    -- The status-bar fill is a separate native control; do not allow food to
    -- enlarge it beyond the background while the outer frame stays fixed.
    local fill = Child(control, "Bar")
    if fill then LockWidth(fill, width) end
end

function M.Apply()
    if busy or not (BUI and BUI.Vars) then return end
    busy = true
    local width = math.max(250, math.min(370, tonumber(BUI.Vars.MyUI_NativeAttributeWidth) or 300))
    for _, name in ipairs(names) do
        local control = _G[name]
        if control then Reflow(control, width) end
    end
    busy = false
end

EVENT_MANAGER:RegisterForEvent("MyUI_NativeWidthReady", EVENT_PLAYER_ACTIVATED, function()
    if BUI and BUI.Vars and BUI.Vars.MyUI_NativeAttributeWidth == nil then
        BUI.Vars.MyUI_NativeAttributeWidth = 300
    end
    M.Apply()
    if zo_callLater then zo_callLater(M.Apply, 0); zo_callLater(M.Apply, 100) end
end)

EVENT_MANAGER:RegisterForEvent("MyUI_NativeWidthStats", EVENT_STATS_UPDATED, function()
    M.Apply()
    if zo_callLater then zo_callLater(M.Apply, 0) end
end)

EVENT_MANAGER:RegisterForEvent("MyUI_NativeWidthPower", EVENT_POWER_UPDATE, function(_, unitTag)
    if unitTag == "player" then M.Apply() end
end)
EVENT_MANAGER:AddFilterForEvent("MyUI_NativeWidthPower", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

-- Safety net for deferred native HUD geometry passes. Does not change height,
-- position, scale, colors, or native outline visibility.
EVENT_MANAGER:RegisterForUpdate("MyUI_NativeWidthGuard", 16, M.Apply)
