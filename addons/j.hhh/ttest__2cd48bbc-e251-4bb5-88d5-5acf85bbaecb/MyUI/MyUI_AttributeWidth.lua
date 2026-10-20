-- My UI: native ESO player attribute width (never change height or scale).
BUI.AttributeWidth = BUI.AttributeWidth or {}
local M = BUI.AttributeWidth
local names = {"ZO_PlayerAttributeHealth", "ZO_PlayerAttributeMagicka", "ZO_PlayerAttributeStamina"}
local busy = false

local function Reflow(control, width)
    if not control then return end
    -- Keep the selected width even if ESO refreshes its HUD after food or buffs.
    -- Do not constrain height: retain the existing ESO minimum/maximum height.
    if control.SetDimensionConstraints and control._myuiWidthConstraint ~= width then
        control:SetDimensionConstraints(width, 0, width, 10000)
        control._myuiWidthConstraint = width
    end
    if control:GetWidth() ~= width then control:SetWidth(width) end
    local bg = control.GetNamedChild and control:GetNamedChild("BgContainer")
    if bg then
        if bg:GetWidth() ~= width then bg:SetWidth(width) end
        local left = bg.GetNamedChild and bg:GetNamedChild("BgLeft")
        local right = bg.GetNamedChild and bg:GetNamedChild("BgRight")
        local center = bg.GetNamedChild and bg:GetNamedChild("BgCenter")
        if center then
            local centerWidth=math.max(1, width - (left and left:GetWidth() or 0) - (right and right:GetWidth() or 0))
            if center:GetWidth() ~= centerWidth then center:SetWidth(centerWidth) end
        end
    end
    local middle=control.GetNamedChild and control:GetNamedChild("FrameCenter")
    if middle then
        local left=control:GetNamedChild("FrameLeft")
        local right=control:GetNamedChild("FrameRight")
        local middleWidth=math.max(1,width-(left and left:GetWidth() or 0)-(right and right:GetWidth() or 0))
        if middle:GetWidth() ~= middleWidth then middle:SetWidth(middleWidth) end
    end
end
function M.Apply()
    if busy or not (BUI and BUI.Vars) then return end
    busy=true
    local width=math.max(250,math.min(370,tonumber(BUI.Vars.MyUI_NativeAttributeWidth) or 300))
    for _,name in ipairs(names) do
        local control=rawget(_G,name)
        if control and control.GetWidth and control.SetWidth then
            Reflow(control,width)
        end
    end
    busy=false
end
EVENT_MANAGER:RegisterForEvent("MyUI_NativeWidthReady",EVENT_PLAYER_ACTIVATED,function()
    if BUI and BUI.Vars and BUI.Vars.MyUI_NativeAttributeWidth==nil then
        -- Existing percentage setting remains untouched; the new absolute width
        -- starts at 300 UI units and can be set explicitly in the menu.
        BUI.Vars.MyUI_NativeAttributeWidth=300
    end
    if zo_callLater then zo_callLater(M.Apply,500) else M.Apply() end
end)
EVENT_MANAGER:RegisterForEvent("MyUI_NativeWidthStats",EVENT_STATS_UPDATED,function()
    if zo_callLater then zo_callLater(M.Apply,50) else M.Apply() end
end)

-- Food and other effects can trigger native UI relayouts after the stats event.
-- This per-frame guard reapplies *width only*, without touching height,
-- position, scale or the configured absolute width.
EVENT_MANAGER:RegisterForUpdate("MyUI_NativeWidthGuard", 33, function()
    M.Apply()
end)
EVENT_MANAGER:RegisterForEvent("MyUI_NativeWidthPower", EVENT_POWER_UPDATE, function(_, unitTag)
    if unitTag == "player" then M.Apply() end
end)
EVENT_MANAGER:AddFilterForEvent("MyUI_NativeWidthPower", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
