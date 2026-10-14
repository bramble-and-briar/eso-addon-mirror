-- Always Expanded Attribute Bars
-- Modified version with color customization and adjustable bar size

-- Create global namespace
AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"

local ApplyTemplate = ApplyTemplateToControl

----------------------------------------------------------
-- Attribute Bars
----------------------------------------------------------

-- Apply the static (always expanded) bar template to the player attribute
-- bars. Called from AEAB:Initialize() once the saved variables are loaded,
-- so the staticBarSize setting can be honored. When disabled, the bars keep
-- the game's default size and shrink/expand behavior.
function AEAB.ApplyStaticTemplate()
    if AEAB.savedVars == nil or AEAB.savedVars.staticBarSize ~= false then
        ApplyTemplate(ZO_PlayerAttribute, 'ALT_PlayerAttribute')
    end
end

-- Block the armor damage module from reshaping the player bars.
-- Keeping this empty means the bars stay expanded instead of shrinking.
function ZO_UnitVisualizer_ArmorDamage:InitializeBarValues() end

----------------------------------------------------------
-- Max resource change effects (optional disable)
----------------------------------------------------------

local shrinkExpandHooked = false
local shrinkExpandOriginal

-- Re-apply the static bar size after the game's shrink/expand animation
-- resized the bars. The animation runs when the max resource changes and
-- the "Disable Resource Change Effects" option is off; it overrides the
-- static size, so we restore it once the animation has settled.
local function RestoreStaticBarSize()
    if AEAB.savedVars and AEAB.savedVars.staticBarSize ~= false then
        local ok1, err1 = pcall(AEAB.ApplyStaticTemplate)
        local ok2, err2 = pcall(AEAB.ApplyDimensions, AEAB)
        if not ok1 then d("[AEAB] RestoreStaticBarSize template error: " .. tostring(err1)) end
        if not ok2 then d("[AEAB] RestoreStaticBarSize dimensions error: " .. tostring(err2)) end
    end
end

function AEAB.DisableResourceChangeEffects()
    if not AEAB.savedVars or not AEAB.savedVars.disableMaxResourceChangeEffects then return end
    if shrinkExpandHooked then return end
    shrinkExpandOriginal = shrinkExpandOriginal or ZO_UnitVisualizer_ShrinkExpandModule.InitializeBarValues
    ZO_UnitVisualizer_ShrinkExpandModule.InitializeBarValues = function() end
    shrinkExpandHooked = true
end

-- The custom bar height for a stat (health vs. magicka/stamina), with the
-- legacy barHeight fallback, matching AEAB:ApplyDimensions().
local function GetCustomBarHeight(stat)
    local sv = AEAB.savedVars
    if not sv then return 25 end
    if stat == STAT_HEALTH_MAX then
        if type(sv.healthBarHeight) == "number" then return sv.healthBarHeight end
        if type(sv.barHeight) == "number" then return sv.barHeight end
        return 25
    end
    if type(sv.resourceBarHeight) == "number" then return sv.resourceBarHeight end
    if type(sv.barHeight) == "number" then return sv.barHeight end
    return 25
end

-- Apply the custom bar height to the shrink/expand glow animation. The
-- game's ShrinkExpandAnimation template is hardcoded to 23px, so the glow
-- does not match bars with a custom height.
local function ApplyCustomGlowHeight(module)
    if not module or not module.barInfo then return end
    for stat, info in pairs(module.barInfo) do
        if info and info.animation then
            local height = GetCustomBarHeight(stat)
            local anim1 = info.animation:GetAnimation(1)
            local anim2 = info.animation:GetAnimation(2)
            if anim1 and anim1.SetStartAndEndHeight then
                anim1:SetStartAndEndHeight(height, height)
            end
            if anim2 and anim2.SetStartAndEndHeight then
                anim2:SetStartAndEndHeight(height, height)
            end
        end
    end
end

function AEAB.EnableResourceChangeEffects()
    if not shrinkExpandHooked then return end
    if shrinkExpandOriginal then
        -- Full replacement of the game's InitializeBarValues: it creates the
        -- per-bar info tables and animations exactly like the original, but
        -- the glow animation uses the custom bar heights instead of the
        -- hardcoded 23px, and the static size is restored once the animation
        -- has settled.
        ZO_UnitVisualizer_ShrinkExpandModule.InitializeBarValues = function(self)
            local healthBarControl = self.barControls[STAT_HEALTH_MAX]
            local magickaBarControl = self.barControls[STAT_MAGICKA_MAX]
            local staminaBarControl = self.barControls[STAT_STAMINA_MAX]

            local oldBarInfo = self.barInfo
            self.barInfo = {
                [STAT_HEALTH_MAX] = self:CreateInfoTable(healthBarControl, oldBarInfo, STAT_HEALTH_MAX, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH),
                [STAT_MAGICKA_MAX] = self:CreateInfoTable(magickaBarControl, oldBarInfo, STAT_MAGICKA_MAX, ATTRIBUTE_MAGICKA, COMBAT_MECHANIC_FLAGS_MAGICKA),
                [STAT_STAMINA_MAX] = self:CreateInfoTable(staminaBarControl, oldBarInfo, STAT_STAMINA_MAX, ATTRIBUTE_STAMINA, COMBAT_MECHANIC_FLAGS_STAMINA),
            }

            -- The glow animation must match the custom bar heights
            ApplyCustomGlowHeight(self)

            for stat, bar in pairs(self.barControls) do
                self:OnValueChanged(bar, self.barInfo[stat], stat, ANIMATION_INSTANT)
            end

            -- Restore the static size once the animation has settled
            zo_callLater(RestoreStaticBarSize, 500)
        end
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
    -- The shield overlay sits on top of the health bar, so it follows
    -- the health bar size settings (with a fallback to the legacy values)
    local width = (sv and sv.healthBarWidth) or (sv and sv.barWidth) or AEAB.defaults.healthBarWidth
    local height = (sv and sv.healthBarHeight) or (sv and sv.barHeight) or AEAB.defaults.healthBarHeight

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