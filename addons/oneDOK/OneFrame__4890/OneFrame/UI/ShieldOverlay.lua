local A = OneFrame
local S = { modules = {} }
A.ShieldOverlay = S
-- The native module's local default, API 101050 powershield.lua. No public constant exists.
-- Keep its different endpoint alpha values when enhancements are off.
local vanillaShield = { ZO_ColorDef:New(.5, .5, 1, .3), ZO_ColorDef:New(.25, .25, .5, .5) }
function S:Apply(module, barInfo)
    local tag = module:GetUnitTag()
    if not tag or not tag:match("^group%d+$") then return end
    local frame = UNIT_FRAMES and UNIT_FRAMES:GetFrame(tag)
    if not A.GroupData:IsPlayerFrame(frame) or frame.attributeVisualizer ~= module:GetOwner() then return end
    self.modules[module] = true
    barInfo = barInfo or (module.attributeInfo and module.attributeInfo[ATTRIBUTE_HEALTH])
    if not barInfo or not barInfo.overlayControls then return end
    local gradient = vanillaShield
    if A.active and A.sv.shield then
        local rgb = A.sv.shieldColor
        local color = ZO_ColorDef:New(rgb[1], rgb[2], rgb[3], A.sv.shieldOpacity)
        gradient = { color, color }
    end
    local health = A.active and A:RoleGradient(tag)
        or module.layoutData.fakeHealthGradientOverride
        or ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH]
    local bar = frame.healthBar and frame.healthBar.barControls[1]
    local shieldInfo = barInfo.visualInfo and barInfo.visualInfo[ATTRIBUTE_VISUAL_POWER_SHIELDING]
    -- Keep the native trauma/no-healing children, replacing only the shield fill.
    local custom = bar and A.active and A.sv.shield and #barInfo.overlayControls == 1 and shieldInfo
    if custom and not barInfo.oneFrameFill then
        local fill = WINDOW_MANAGER:CreateControl(nil, barInfo.overlayControls[1], CT_TEXTURE)
        fill:SetMouseEnabled(false)
        fill:SetDrawLayer(DL_OVERLAY)
        barInfo.oneFrameFill = fill
    end
    local fill = barInfo.oneFrameFill
    if fill then
        fill:SetHidden(not custom or shieldInfo.value <= 0)
        if custom then
            local fraction = math.max(0, math.min(1, shieldInfo.value / math.max(1, barInfo.attributeMax or 1)))
            fill:ClearAnchors()
            fill:SetAnchor(TOPLEFT, bar, TOPLEFT)
            fill:SetDimensions(bar:GetWidth() * fraction, bar:GetHeight())
            fill:SetColor(A.sv.shieldColor[1], A.sv.shieldColor[2], A.sv.shieldColor[3], A.sv.shieldOpacity)
            local transparent = ZO_ColorDef:New(0, 0, 0, 0)
            gradient = { transparent, transparent }
        end
    end
    for _, overlay in ipairs(barInfo.overlayControls) do
        ZO_StatusBar_SetGradientColor(overlay, gradient)
        if overlay.fakeHealthBar then ZO_StatusBar_SetGradientColor(overlay.fakeHealthBar, health) end
    end
    -- Native event deltas, visibility and trauma controls remain intact.
    -- Do not hide the parent overlay: its children implement trauma and no-healing indicators.
end
function S:Refresh()
    for module in pairs(self.modules) do self:Apply(module) end
    for frame in pairs(A.Frames.cache) do
        local visualizer = frame.attributeVisualizer
        if visualizer then
            for module in pairs(visualizer.visualModules) do
                if module.attributeInfo and module.attributeInfo[ATTRIBUTE_HEALTH]
                    and module.attributeInfo[ATTRIBUTE_HEALTH].visualInfo then self:Apply(module) end
            end
        end
    end
end
function S:Initialize()
    local class = ZO_UnitVisualizer_PowerShieldModule
    ZO_PostHook(class, "OnStatusBarValueChanged", function(module, _, info) self:Apply(module, info) end)
    ZO_PostHook(class, "ShowOverlay", function(module, _, info) self:Apply(module, info) end)
    ZO_PostHook(class, "ApplyPlatformStyle", function(module) self:Apply(module) end)
end
