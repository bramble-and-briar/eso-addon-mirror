-- AEAB Module: Target Attribute Bars Resizer
-- Resizes the target unit frame attribute bars to a size adjustable
-- from the Always Expanded Attribute Bars settings menu
-- (disabled by default).

local AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"

local ApplyTemplate = ApplyTemplateToControl

AEAB.modules = AEAB.modules or {}

local module = {}

function module.IsEnabled()
    return AEAB.savedVars ~= nil and AEAB.savedVars.enableTargetBarsResizer == true
end

-- Apply the fixed-size template to the target unit frame.
-- Safe to call any time; does nothing when the module is disabled.
function module.Apply()
    if not module.IsEnabled() then return end

    local ok, err = pcall(function()
        -- Optionally hide the difficulty brackets (the elite/boss indicator).
        -- They are NOT part of the template, so when the setting is enabled
        -- they stay on the frame with their game anchors (relative to the
        -- BgContainer) and keep showing around the resized bar.
        local sv = AEAB.savedVars
        if sv and sv.showTargetEliteBrackets == false then
            if ZO_TargetUnitFramereticleoverRightBracket then
                ZO_TargetUnitFramereticleoverRightBracket:SetParent(GuiRoot)
            end
            if ZO_TargetUnitFramereticleoverLeftBracket then
                ZO_TargetUnitFramereticleoverLeftBracket:SetParent(GuiRoot)
            end
        end

        -- Apply the template to the target unit frame
        if ZO_TargetUnitFramereticleover then
            ApplyTemplate(ZO_TargetUnitFramereticleover, 'AEAB_TargetUnitFrame')
        end
    end)
    if not ok then
        d("[AEAB] Target bars module error: " .. tostring(err))
    end

    -- Apply the adjustable dimensions (width / height) on top of the template
    module.ApplyDimensions()

    -- Apply the adjustable font on top of the template
    module.ApplyFont()
end

-- Apply the adjustable target bar dimensions (width / height) from the
-- settings menu.
--
-- The game anchors all the decorative pieces relative to the container:
-- the end caps sit at the left/right edges (edge-centered), the frame
-- center and bg center span between their edge pieces, and the bar fill
-- is vertically centered. So we only change the sizes and let the game's
-- anchors do the rest:
--   container height = fill height + 6 (the frame art is 6px taller than
--                                       the fill: 3px overhang per side)
--   bar fill height   = fill height (centered by its own anchors)
--   caps / background = container height
function module.ApplyDimensions()
    if not module.IsEnabled() then return end

    local ok, err = pcall(function()
        local frame = ZO_TargetUnitFramereticleover
        if not frame then return end

        local sv = AEAB.savedVars
        local defaults = AEAB.defaults or {}
        local function Num(value, fallback)
            if type(value) == "number" then return value end
            if type(fallback) == "number" then return fallback end
            return 0
        end
        local width = Num(sv and sv.targetBarWidth, defaults.targetBarWidth)
        local fillHeight = Num(sv and sv.targetBarHeight, defaults.targetBarHeight)
        if width <= 0 then width = 360 end
        if fillHeight <= 0 then fillHeight = 18 end
        local containerHeight = fillHeight + 6

        -- Remove the fixed-size constraints of the template and resize the
        -- container. The bar halves, caps and background pieces keep their
        -- existing anchors, so they follow the new size automatically.
        frame:SetDimensionConstraints(0, 0, 0, 0)
        frame:SetDimensions(width, containerHeight)

        -- Background container fills the frame
        local bg = frame:GetNamedChild("BgContainer")
        if bg then
            bg:SetDimensionConstraints(0, 0, 0, 0)
            bg:ClearAnchors()
            bg:SetAnchor(TOPLEFT, frame, TOPLEFT)
            bg:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT)
        end

        -- Background edge pieces: keep their anchors (corner-anchored to the
        -- background container), only the height changes; the width stays
        -- from the template dimensions
        local bgLeft = frame:GetNamedChild("BgLeft")
        if bgLeft then bgLeft:SetHeight(containerHeight) end
        local bgRight = frame:GetNamedChild("BgRight")
        if bgRight then bgRight:SetHeight(containerHeight) end

        -- Bar fill halves: keep the template anchors (left+7 to center and
        -- center to right-7), only the height changes; the fill stays
        -- vertically centered in the container
        local barLeft = frame:GetNamedChild("BarLeft")
        if barLeft then barLeft:SetHeight(fillHeight) end
        local barRight = frame:GetNamedChild("BarRight")
        if barRight then barRight:SetHeight(fillHeight) end

        -- End caps: keep their edge anchors (left/right edge, vertically
        -- centered), stretch to the container height; width stays 22
        local frameLeft = frame:GetNamedChild("FrameLeft")
        if frameLeft then frameLeft:SetHeight(containerHeight) end
        local frameRight = frame:GetNamedChild("FrameRight")
        if frameRight then frameRight:SetHeight(containerHeight) end

        -- FrameCenter, BgCenter, Warner and the text labels keep the game's
        -- own anchors and follow the resized pieces automatically.

        -- Resource numbers centered on the bar
        local numbers = frame:GetNamedChild("ResourceNumbers")
        if numbers then
            numbers:ClearAnchors()
            numbers:SetAnchor(CENTER, frame, CENTER, 0, 0)
        end
    end)
    if not ok then
        d("[AEAB] Target bars dimensions error: " .. tostring(err))
    end
end

-- Apply the adjustable target frame font (face / size / style) from the
-- settings menu to all target frame texts: resource numbers, caption,
-- level and name.
function module.ApplyFont()
    local sv = AEAB.savedVars
    if not sv then return end

    local frame = ZO_TargetUnitFramereticleover
    if not frame then return end

    local fontString = string.format('%s|%d|%s',
        sv.targetFontFace or '$(BOLD_FONT)',
        sv.targetFontSize or 17,
        sv.targetFontStyle or 'soft-shadow-thick')

    pcall(function()
        for _, name in ipairs({ 'ResourceNumbers', 'Caption', 'Level', 'Name' }) do
            local label = frame:GetNamedChild(name)
            if label and label.SetFont then
                label:SetFont(fontString)
            end
        end
    end)
end

----------------------------------------------------------
-- Target bar color by reaction (enemy / neutral / ally / players / self)
-- GetUnitReaction determines the category, the color is applied as a
-- gradient (a flat SetColor is overridden by the stock gradient), and
-- the game's UpdateUnitReaction is the reliable recolor moment.
----------------------------------------------------------

local unitTag = 'reticleover'

-- Map the game's UNIT_REACTION_* constants to our color categories.
-- Built from globals so missing constants never break the addon.
local REACTION_CATEGORIES = { enemy = {}, neutral = {}, ally = {} }
for category, keys in pairs({
    enemy   = { 'HOSTILE', 'PLAYER_ENEMY', 'MONSTER' },
    neutral = { 'NEUTRAL', 'INTERACTIVE' },
    ally    = { 'FRIENDLY', 'NPC_ALLY', 'PLAYER_ALLY', 'COMPANION' },
}) do
    for _, key in ipairs(keys) do
        local value = _G['UNIT_REACTION_' .. key]
        if value then REACTION_CATEGORIES[category][value] = true end
    end
end

-- Which color category the current reticle target belongs to
local function GetTargetCategory()
    if not DoesUnitExist(unitTag) then return nil end
    if AreUnitsEqual(unitTag, 'player') then return 'player' end

    -- Other player characters get their own color so they can be
    -- distinguished from NPCs, regardless of their reaction
    if IsUnitPlayer(unitTag) then return 'playerCharacter' end

    local reaction = GetUnitReaction(unitTag)
    if REACTION_CATEGORIES.enemy[reaction] then return 'enemy' end
    if REACTION_CATEGORIES.neutral[reaction] then return 'neutral' end
    if REACTION_CATEGORIES.ally[reaction] then return 'ally' end
    return nil
end

-- Apply the white-blue color for friendly players (when the option is on)
-- or the standard red gradient to both halves of the target health bar.
-- This is the single color path for friendly players, used both when
-- color-by-reaction is enabled and when it is disabled.
local function ApplyFriendlyBlueOrRed(sv, barLeft, barRight)
    if sv.blueForFriendlyPlayers and IsUnitPlayer(unitTag) then
        local reaction = GetUnitReaction(unitTag)
        if reaction ~= UNIT_REACTION_PLAYER_ENEMY then
            -- friendly player (the light blue), applied as a gradient with
            if GetUnitReactionColor then
                local r, g, b = GetUnitReactionColor(unitTag)
                if r then
                    barLeft:SetGradientColors(r * 0.64, g * 0.64, b * 0.64, 1, r * 0.8, g * 0.8, b * 0.8, 1)
                    barRight:SetGradientColors(r * 0.64, g * 0.64, b * 0.64, 1, r * 0.8, g * 0.8, b * 0.8, 1)
                    return
                end
            end
        end
    end

    -- Standard red (health) gradient
    local gradient = ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH]
    if gradient then
        ZO_StatusBar_SetGradientColor(barLeft, gradient)
        ZO_StatusBar_SetGradientColor(barRight, gradient)
    end
end

-- Apply the reaction-based color to both halves of the target health bar.
-- Safe to call any time; does nothing while the setting is disabled.
-- Friendly players are always controlled by the blue-for-friendly-players
-- option; other targets use the custom (priority) or game reaction colors.
function module.ApplyReactionColor()
    local sv = AEAB.savedVars
    if not sv or not sv.targetBarColorByReaction then return end

    local frame = ZO_TargetUnitFramereticleover
    if not frame then return end
    local barLeft = frame:GetNamedChild('BarLeft')
    local barRight = frame:GetNamedChild('BarRight')
    if not barLeft or not barRight then return end

    -- Friendly players: the blue option decides (blue when enabled, standard
    -- red otherwise)
    if IsUnitPlayer(unitTag) and GetUnitReaction(unitTag) ~= UNIT_REACTION_PLAYER_ENEMY then
        ApplyFriendlyBlueOrRed(sv, barLeft, barRight)
        return
    end

    -- Custom per-category colors take priority. Gradient: 0.64 dark -> 0.8
    if sv.targetColorSource ~= 'game' then
        local category = GetTargetCategory()
        if not category then return end

        local color
        if category == 'player' then
            color = sv.targetPlayerColor
        elseif category == 'playerCharacter' then
            color = sv.targetPlayerCharacterColor
        elseif category == 'enemy' then
            color = sv.targetEnemyColor
        elseif category == 'neutral' then
            color = sv.targetNeutralColor
        else
            color = sv.targetAllyColor
        end
        if type(color) ~= 'table' then return end

        local r, g, b, a = color[1], color[2], color[3], color[4] or 1
        barLeft:SetGradientColors(r * 0.64, g * 0.64, b * 0.64, a, r * 0.8, g * 0.8, b * 0.8, a)
        barRight:SetGradientColors(r * 0.64, g * 0.64, b * 0.64, a, r * 0.8, g * 0.8, b * 0.8, a)
        return
    end

    -- The game's own reaction colors (same source as ImprovedAttributeBars).
    -- Gradient: 0.6 dark -> full color, like ImprovedAttributeBars.
    if not GetUnitReactionColor then return end
    local r, g, b = GetUnitReactionColor(unitTag)
    if not r then return end
    barLeft:SetGradientColors(r * 0.6, g * 0.6, b * 0.6, 1, r, g, b, 1)
    barRight:SetGradientColors(r * 0.6, g * 0.6, b * 0.6, 1, r, g, b, 1)
end

-- Restore the stock reaction gradient on the target health bar
function module.RestoreReactionColor()
    pcall(function()
        if not UNIT_FRAMES or not UNIT_FRAMES.GetFrame then return end
        local unitFrame = UNIT_FRAMES:GetFrame(unitTag)
        local bar = unitFrame and unitFrame.healthBar
        if bar and bar.barType then
            bar:SetColor(bar.barType)
        end
    end)
end

-- Apply the standard red gradient to the target health bar, with the optional
-- light blue color for friendly players. Used when color-by-reaction is
-- disabled; when it is enabled the reaction colors take over.
function module.ApplyGradient()
    local sv = AEAB.savedVars
    if not sv then return end
    if sv.targetBarColorByReaction then return end

    local frame = ZO_TargetUnitFramereticleover
    if not frame then return end
    local barLeft = frame:GetNamedChild("BarLeft")
    local barRight = frame:GetNamedChild("BarRight")
    if not barLeft or not barRight then return end

    -- Friendly players get the light blue color when the option is enabled,
    -- the standard red gradient otherwise (same single path as the
    -- color-by-reaction mode)
    ApplyFriendlyBlueOrRed(sv, barLeft, barRight)
end

-- Recolor the bar whenever the game updates the target's reaction.
-- The target unit frame exists from UI load, so the hook is installed
-- once at activation (independent of the resizer module being enabled).
local reactionHookInstalled = false
local function InstallReactionHook()
    if reactionHookInstalled then return end
    if not UNIT_FRAMES or not UNIT_FRAMES.GetFrame then return end
    local unitFrame = UNIT_FRAMES:GetFrame(unitTag)
    if not unitFrame then return end

    SecurePostHook(unitFrame, 'UpdateUnitReaction', function()
        module.ApplyReactionColor()
        module.ApplyGradient()
    end)
    reactionHookInstalled = true
end

----------------------------------------------------------
-- Target power shield overlay
----------------------------------------------------------

SecurePostHook(ZO_UnitVisualizer_PowerShieldModule, 'ShowOverlay', function(_, _, info)
    if not module.IsEnabled() then return end
    if not (info and info.overlayControls and info.overlayControls[1]) then return end

    local name = info.overlayControls[1]:GetName()
    if not (name and string.find(name, "Target", 1, true)) then return end

    -- The shield overlay follows the adjustable target bar size
    local sv = AEAB.savedVars
    local defaults = AEAB.defaults or {}
    local width = (sv and type(sv.targetBarWidth) == "number") and sv.targetBarWidth or defaults.targetBarWidth or 360
    local height = (sv and type(sv.targetBarHeight) == "number") and sv.targetBarHeight or defaults.targetBarHeight or 18

    local function SizeOverlay(overlay)
        if not overlay then return end
        ApplyTemplate(overlay, 'AEAB_TargetPowerShieldBar')
        overlay:SetDimensions(width, height)
        local fakeHealth = overlay.fakeHealthBar or overlay:GetNamedChild("FakeHealth")
        if fakeHealth then
            fakeHealth:ClearAnchors()
            fakeHealth:SetAnchorFill()
        end
    end

    SizeOverlay(info.overlayControls[1])
    SizeOverlay(info.overlayControls[2])
end)

----------------------------------------------------------
-- Apply on unit frame creation and on every player activation
----------------------------------------------------------

-- Re-apply the adjustable target bar size whenever the game might have
-- reset the frame to its standard template (target change, zone change,
-- UI scale change, etc.). Both functions no-op when the module is disabled.
local function ReapplyTargetSize()
    module.ApplyDimensions()
    module.ApplyFont()
end

CALLBACK_MANAGER:RegisterCallback('UnitFramesCreated', function()
    module.Apply()
    InstallReactionHook()
    module.ApplyGradient()
end)

EVENT_MANAGER:RegisterForEvent(AEAB.name .. "_TargetModule_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
    zo_callLater(function()
        module.Apply()
        InstallReactionHook()
        module.ApplyReactionColor()
        module.ApplyGradient()
    end, 50)
    -- The game may re-apply its own target frame template a bit later
    -- (e.g. while the zone finishes loading), which resets the bar to the
    -- standard size, so re-apply the adjustable size again
    zo_callLater(ReapplyTargetSize, 500)
end)

-- The game re-applies the target frame template when the reticle target
-- changes (e.g. to show/hide the elite difficulty brackets or the
-- player-specific elements), which resets the bar to the standard size.
-- Re-apply the adjustable size after the frame update.
EVENT_MANAGER:RegisterForEvent(AEAB.name .. "_TargetModule_ReticleTargetChanged", EVENT_RETICLE_TARGET_CHANGED, function()
    zo_callLater(ReapplyTargetSize, 100)
end)

-- Same for UI scale changes
EVENT_MANAGER:RegisterForEvent(AEAB.name .. "_TargetModule_UiScaleChanged", EVENT_UI_SCALE_CHANGED, function()
    zo_callLater(ReapplyTargetSize, 100)
end)

AEAB.modules.targetBarsResizer = module