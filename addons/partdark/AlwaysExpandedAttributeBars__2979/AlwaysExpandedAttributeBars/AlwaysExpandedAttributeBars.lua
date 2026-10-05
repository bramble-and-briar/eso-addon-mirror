-- Always Expanded Attribute Bars
-- Modified version with color customization and adjustable bar size

-- Create global namespace
AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"

local ApplyTemplate = ApplyTemplateToControl

----------------------------------------------------------
-- Attribute Bars
----------------------------------------------------------

-- Templates - only apply to player attribute bars
ApplyTemplate(ZO_PlayerAttribute, 'ALT_PlayerAttribute')

-- Block the armor damage module from reshaping the player bars.
-- Keeping this empty means the bars stay expanded instead of shrinking.
function ZO_UnitVisualizer_ArmorDamage:InitializeBarValues() end

----------------------------------------------------------
-- Max resource change effects (optional disable)
----------------------------------------------------------

local shrinkExpandHooked = false
local shrinkExpandOriginal

function AEAB.DisableResourceChangeEffects()
    if not AEAB.savedVars or not AEAB.savedVars.disableMaxResourceChangeEffects then return end
    if shrinkExpandHooked then return end
    shrinkExpandOriginal = ZO_UnitVisualizer_ShrinkExpandModule.InitializeBarValues
    ZO_UnitVisualizer_ShrinkExpandModule.InitializeBarValues = function() end
    shrinkExpandHooked = true
end

function AEAB.EnableResourceChangeEffects()
    if not shrinkExpandHooked then return end
    if shrinkExpandOriginal then
        ZO_UnitVisualizer_ShrinkExpandModule.InitializeBarValues = shrinkExpandOriginal
    end
    shrinkExpandHooked = false
end

----------------------------------------------------------
-- Power shield overlay customization
----------------------------------------------------------

-- Use the custom template for health bar shields (player only)
SecurePostHook(ZO_UnitVisualizer_PowerShieldModule, 'ShowOverlay', function(_, _, info)
    if not (info and info.overlayControls and info.overlayControls[1]) then return end

    local name = info.overlayControls[1]:GetName()
    if not (name and string.find(name, "ZO_PlayerAttribute", 1, true)) then return end

    local sv = AEAB.savedVars
    local width = (sv and sv.barWidth) or AEAB.defaults.barWidth
    local height = (sv and sv.barHeight) or AEAB.defaults.barHeight

    local function SizeOverlay(overlay)
        if not overlay then return end
        ApplyTemplate(overlay, 'ALT_PowerShieldBar')
        overlay:SetDimensions(width, height)
        local fakeHealth = overlay.fakeHealthBar
        if fakeHealth then
            fakeHealth:ClearAnchors()
            fakeHealth:SetAnchorFill()
        end
    end

    SizeOverlay(info.overlayControls[1])
    SizeOverlay(info.overlayControls[2])

    -- Apply shield color if custom shields are enabled
    if sv and sv.useCustomShieldColor and sv.shieldColor then
        info.overlayControls[1]:SetColor(unpack(sv.shieldColor))
        if info.overlayControls[2] then
            info.overlayControls[2]:SetColor(unpack(sv.shieldColor))
        end
    end

    -- Apply custom color to the fake health bar inside the shield overlay
    if sv and sv.useCustomHealthColor and sv.healthColor then
        if info.overlayControls[1].fakeHealthBar then
            info.overlayControls[1].fakeHealthBar:SetColor(unpack(sv.healthColor))
        end
        if info.overlayControls[2] and info.overlayControls[2].fakeHealthBar then
            info.overlayControls[2].fakeHealthBar:SetColor(unpack(sv.healthColor))
        end

        -- Also apply to the original health bars
        local healthBar = ZO_PlayerAttributeHealth
        if healthBar then
            local barLeft = healthBar:GetNamedChild("BarLeft")
            local barRight = healthBar:GetNamedChild("BarRight")
            if barLeft and barRight then
                barLeft:SetColor(unpack(sv.healthColor))
                barRight:SetColor(unpack(sv.healthColor))
            end
        end
    end
end)

----------------------------------------------------------
-- Borders (added once)
----------------------------------------------------------

function AEAB:AddBorders()
    if AEAB.bordersAdded then return end
    AEAB.bordersAdded = true

    local function AddBorder(control, name, r, g, b, a)
        if control then
            local border = control:GetNamedChild(name)
            if not border then
                border = WINDOW_MANAGER:CreateControl(control:GetName() .. name, control, CT_TEXTURE)
                border:SetAnchorFill()
                border:SetTexture("EsoUI/Art/Miscellaneous/glowBorder.dds")
                border:SetBlendMode(TEX_BLEND_MODE_ADD)
                border:SetDrawLevel(1)
                border:SetColor(r, g, b, a)
            end
        end
    end

    local healthBar = ZO_PlayerAttributeHealth
    if healthBar then
        AddBorder(healthBar:GetNamedChild("BarLeft"), "HealthBorder", 1, 0.3, 0.3, 0.3)
        AddBorder(healthBar:GetNamedChild("BarRight"), "HealthBorder", 1, 0.3, 0.3, 0.3)
    end

    local magickaBar = ZO_PlayerAttributeMagicka
    if magickaBar then
        AddBorder(magickaBar:GetNamedChild("Bar"), "MagickaBorder", 0.3, 0.5, 1, 0.3)
    end

    local staminaBar = ZO_PlayerAttributeStamina
    if staminaBar then
        AddBorder(staminaBar:GetNamedChild("Bar"), "StaminaBorder", 0.5, 0.8, 0.3, 0.3)
    end
end