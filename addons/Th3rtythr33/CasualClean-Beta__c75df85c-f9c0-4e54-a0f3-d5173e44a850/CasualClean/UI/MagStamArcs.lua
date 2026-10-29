-- =============================================================================
-- CasualClean -- UI/MagStamArcs.lua
-- =============================================================================
-- Magicka (left) and stamina (right) arcs flanking the reticle, plus hiding
-- ESO's own magicka/stamina bars that these replace.
--
-- NO POLLING. Unlike the companion marker in CasualClean.lua, which has to
-- sample a moving world position every tick, these are driven purely by
-- EVENT_POWER_UPDATE filtered to the player and to one power type each --
-- the same filtering ZOS's own attribute bars use. Nothing here runs between
-- resource changes.
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.MagStamArcs = {}
local M = CC.MagStamArcs

local ADDON_NAME = "CasualClean"
local TEXTURE_PATH = "CasualClean/UI/Textures/"

-- Fill directions. Stored in SavedVariables as these numbers; the settings
-- panel maps them to and from the display names below.
M.FILL_BOTTOM_UP = 1
M.FILL_TOP_DOWN = 2
M.FILL_CENTRE_OUT = 3

M.FILL_DIRECTION_NAMES = {
    [M.FILL_BOTTOM_UP] = "Bottom-up",
    [M.FILL_TOP_DOWN] = "Top-down",
    [M.FILL_CENTRE_OUT] = "Centre-out",
}

M.DEFAULT_FILL_DIRECTION = M.FILL_BOTTOM_UP
M.DEFAULT_ARC_OFFSET_X = 64  -- px from screen centre to each arc's centre
M.DEFAULT_ARC_HEIGHT = 128   -- px; the source canvas height, i.e. scale 1.0
-- Defaults on, since the arcs exist to replace those bars -- but it is a
-- setting rather than a hardcoded consequence, so the arcs can be run
-- alongside the stock bars (useful for comparing them, and for anyone who
-- wants the numbers as well as the shape).
M.DEFAULT_HIDE_DEFAULT_BARS = true
-- Master switch (1.6.6). Off means a HARD off: both power-update
-- registrations are removed, the arcs' root is hidden, and the stock bars are
-- restored -- not merely alpha 0 with the events still waking the module.
M.DEFAULT_ENABLED = true

-- Canvas geometry, taken verbatim from `Tools/png2dds.py --pot` output.
-- The source art is tight-cropped and non-power-of-two (border 24x121, fill
-- 22x119), so it was PADDED onto a 32x128 transparent canvas rather than
-- resized -- scaling 24->32 wide but 121->128 tall would have stretched the
-- curve unevenly. Centring both preserved the fill's designed 1px nesting
-- inside the border.
--
-- The fill art therefore does NOT span the full canvas: it occupies rows
-- 4..122 inclusive. Fill fractions must map onto those 119 art rows, not
-- onto the padded 128 -- otherwise the first and last few percent of the
-- range would be spent revealing transparent padding and read as a dead
-- zone at both ends of the bar.
local CANVAS_W, CANVAS_H = 32, 128
local FILL_ART_TOP = 4        -- first art row on the padded fill canvas
local FILL_ART_BOTTOM = 123   -- one PAST the last art row (rows 4..122)
local FILL_ART_H = FILL_ART_BOTTOM - FILL_ART_TOP  -- 119

-- Treated as full, and therefore hidden. Not an exact 1.0 compare: current
-- and effectiveMax are integers, but a max-resource buff expiring can leave
-- current fractionally above effectiveMax for a tick, and float division of
-- two equal integers is exact while the surrounding arithmetic is not.
local FULL_EPSILON = 0.999

local POWER_TYPES = {
    { key = "Magicka", powerType = COMBAT_MECHANIC_FLAGS_MAGICKA, side = -1,
      border = "reticle-left-arc-border.dds", fill = "reticle-left-arc-fill.dds" },
    { key = "Stamina", powerType = COMBAT_MECHANIC_FLAGS_STAMINA, side = 1,
      border = "reticle-right-arc-border.dds", fill = "reticle-right-arc-fill.dds" },
}

local root
local arcs = {}         -- ordered list of arc tables
local arcsByPower = {}  -- powerType -> arc

local function sv()
    return CC.sv
end

-- -----------------------------------------------------------------------------
-- Hiding ZOS's own magicka/stamina bars
-- -----------------------------------------------------------------------------
-- A raw SetHidden(true) is the wrong call, for the same reason it was on the
-- companion frame -- except here the re-assertion is on a TIMER, not an event:
-- every ZO_PlayerAttributeBar runs
--   EVENT_MANAGER:RegisterForUpdate(name .. "FadeUpdate", DELAY_BEFORE_FADING, ...)
-- which recomputes visibility via ShouldContextuallyShow() forever, and would
-- silently undo it.
--
-- SetExternalVisibilityRequirement is ZOS's own hook for "this bar should
-- never show". ShouldContextuallyShow() consults it FIRST, ahead of every
-- other rule -- including the player's own RESOURCE_BARS_SETTING_CHOICE
-- setting and the forceVisible reference count that ZO_UnitAttributeVisualizer
-- drives for shields and armour buffs. It is the same mechanism ZOS uses for
-- its own conditional bars (mount stamina -> IsMounted, werewolf ->
-- IsPlayerInWerewolfForm, siege health -> IsGameCameraSiegeControlled).
--
-- Checked before relying on it: ZOS sets no externalVisibilityRequirement on
-- the magicka or stamina bars, so this clobbers nothing and `nil` restores
-- stock behaviour exactly.
local function NeverShow()
    return false
end

local function GetAttributeBar(powerType)
    if not (PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.bars) then
        return nil
    end
    for _, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
        -- Unambiguous for these two: werewolf and mount stamina carry their
        -- own distinct power types, so neither collides with MAGICKA/STAMINA.
        -- (Health WOULD collide with siege health -- worth knowing before
        -- ever extending this to the health bar.)
        if bar.powerType == powerType then
            return bar
        end
    end
    return nil
end

local function TryApplyDefaultBarHiding(hidden)
    local applied = false
    for _, spec in ipairs(POWER_TYPES) do
        local bar = GetAttributeBar(spec.powerType)
        if bar then
            bar:SetExternalVisibilityRequirement(hidden and NeverShow or nil)
            bar:UpdateContextualFading()
            applied = true
        end
    end
    return applied
end

-- PLAYER_ATTRIBUTE_BARS is built from XML in ZO_PlayerAttribute_OnInitialized,
-- which is not guaranteed to have run by our EVENT_ADD_ON_LOADED. Same retry
-- shape as HideCompanionFrameWithRetry in CasualClean.lua.
local function ApplyDefaultBarHidingWithRetry(hidden, attemptsLeft)
    if TryApplyDefaultBarHiding(hidden) or attemptsLeft <= 0 then
        return
    end
    zo_callLater(function() ApplyDefaultBarHidingWithRetry(hidden, attemptsLeft - 1) end, 250)
end

-- -----------------------------------------------------------------------------
-- Geometry
-- -----------------------------------------------------------------------------
local function ApplyLayout()
    if not root then
        return
    end
    local height = sv().arcHeight
    local scale = height / CANVAS_H
    for _, arc in ipairs(arcs) do
        arc.container:SetDimensions(CANVAS_W * scale, height)
        arc.container:ClearAnchors()
        -- GuiRoot CENTER, never the reticle: reticle.lua hides the reticle
        -- texture in stealth and disguise and the container in several
        -- interaction states, and a child control would inherit that --
        -- vanishing exactly when stamina matters most. ZO_ReticleContainer is
        -- AnchorFill with the reticle anchored CENTER inside it, so the
        -- reticle's centre IS screen centre and this is positionally
        -- identical while depending on nothing first-party.
        arc.container:SetAnchor(CENTER, GuiRoot, CENTER, arc.side * sv().arcOffsetX, 0)
        arc.border:ClearAnchors()
        arc.border:SetAnchorFill(arc.container)
    end
end

-- Crops the fill texture to `fraction` of its ART rows and sizes/anchors the
-- control to match. All three directions are the same three steps -- pick a
-- span of art rows, convert to normalised texture coords, anchor the control
-- so that span lands where those rows sit on the padded canvas.
local function ApplyFill(arc, fraction)
    local height = sv().arcHeight
    local scale = height / CANVAS_H
    local visibleRows = FILL_ART_H * fraction
    local direction = sv().fillDirection

    local topRow, bottomRow, point, offsetY
    if direction == M.FILL_TOP_DOWN then
        topRow = FILL_ART_TOP
        bottomRow = FILL_ART_TOP + visibleRows
        point = TOP
        offsetY = FILL_ART_TOP * scale
    elseif direction == M.FILL_CENTRE_OUT then
        local centreRow = (FILL_ART_TOP + FILL_ART_BOTTOM) / 2
        topRow = centreRow - visibleRows / 2
        bottomRow = centreRow + visibleRows / 2
        point = CENTER
        offsetY = (centreRow - CANVAS_H / 2) * scale
    else -- M.FILL_BOTTOM_UP
        topRow = FILL_ART_BOTTOM - visibleRows
        bottomRow = FILL_ART_BOTTOM
        point = BOTTOM
        -- Negative: the art's bottom edge sits (CANVAS_H - FILL_ART_BOTTOM)
        -- px above the padded canvas's bottom edge.
        offsetY = -(CANVAS_H - FILL_ART_BOTTOM) * scale
    end

    arc.fill:SetTextureCoords(0, 1, topRow / CANVAS_H, bottomRow / CANVAS_H)
    arc.fill:SetDimensions(CANVAS_W * scale, visibleRows * scale)
    arc.fill:ClearAnchors()
    arc.fill:SetAnchor(point, arc.container, point, 0, offsetY)
end

-- -----------------------------------------------------------------------------
-- Visibility
-- -----------------------------------------------------------------------------
local function SetArcShown(arc, shown)
    if arc.shown == shown then
        return
    end
    arc.shown = shown
    if arc.timeline then
        if shown then
            arc.timeline:PlayForward()
        else
            arc.timeline:PlayBackward()
        end
    else
        -- Only reached if the virtual timeline could not be instantiated.
        -- Degrades to an instant show/hide rather than a dead indicator,
        -- the same philosophy as the pcall'd SetFont in UnderPressure.
        arc.container:SetAlpha(shown and 1 or 0)
    end
end

local function RefreshArc(arc)
    local current, _, effectiveMax = GetUnitPower("player", arc.powerType)
    local fraction = (effectiveMax > 0) and (current / effectiveMax) or 0
    if fraction > 1 then
        fraction = 1
    elseif fraction < 0 then
        fraction = 0
    end
    arc.fraction = fraction
    ApplyFill(arc, fraction)

    -- Deliberately NOT gated on restricted content, unlike the companion
    -- marker. Per explicit request 2026-08-08, the Mag/Stam Arcs run
    -- everywhere -- Cyrodiil, Battlegrounds, and Dungeons/Trials whether
    -- grouped or not. They are a readout of the player's own resources that
    -- replaces UI the game shows in those places anyway, not an informational
    -- overlay about the world, so the reasoning that silences the companion
    -- marker in group and PvP content does not apply to them.
    SetArcShown(arc, fraction < FULL_EPSILON)
end

-- Forward declarations: the event registration helpers are defined below
-- OnPowerUpdate, which they reference, but Refresh needs to call them.
local RegisterPowerEvents, UnregisterPowerEvents

function M.GetEnabled()
    local s = sv()
    if s and s.arcsEnabled ~= nil then
        return s.arcsEnabled
    end
    return M.DEFAULT_ENABLED
end

function M.Refresh()
    if not root then
        return
    end
    if not M.GetEnabled() then
        -- Hard off. Order: stop listening, drop the arcs, give ZOS its bars
        -- back (nil requirement = exact stock behaviour, regardless of the
        -- hide-bars setting, which only has meaning while the arcs replace
        -- them).
        UnregisterPowerEvents()
        for _, arc in ipairs(arcs) do
            SetArcShown(arc, false)
        end
        root:SetHidden(true)
        ApplyDefaultBarHidingWithRetry(false, 4)
        return
    end
    root:SetHidden(false)
    RegisterPowerEvents()
    for _, arc in ipairs(arcs) do
        RefreshArc(arc)
    end
    -- Follows the setting alone, with no restricted-content exception: the
    -- arcs stay up everywhere, so the bars they replace must stay down
    -- everywhere too, or both would show at once in exactly the content where
    -- screen space matters most. Clearing the requirement to nil when the
    -- setting is off is a true restore of ZOS's behaviour rather than a
    -- competing "always show" assertion.
    ApplyDefaultBarHidingWithRetry(sv().hideDefaultBars, 4)
end

-- -----------------------------------------------------------------------------
-- Colour
-- -----------------------------------------------------------------------------
-- ESO's own power colours rather than hardcoded values, so the arcs match the
-- rest of the UI and follow any future ZOS retune for free.
--
-- ZOS's bars use ZO_POWER_BAR_GRADIENT_COLORS[powerType], a two-stop gradient
-- across the bar's length. A solid arc needs ONE colour, and that table's
-- defining file could not be located from here, so this uses the native
-- GetInterfaceColor with the gradient's start stop instead -- documented, and
-- not dependent on a Lua global whose availability to addons is unconfirmed.
-- Whether START or END reads better as a solid fill is a visual question:
-- `/casualclean arcs` prints both so it can be settled in one look.
local function RefreshColors()
    for _, arc in ipairs(arcs) do
        local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_START, arc.powerType)
        arc.fill:SetColor(r, g, b, 1)
    end
    -- The border is deliberately left untinted, at the art's own near-white,
    -- so it reads as a frame around the resource rather than as more of it.
end

function M.GetColorReport()
    local out = {}
    for _, arc in ipairs(arcs) do
        local sr, sg, sb = GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_START, arc.powerType)
        local er, eg, eb = GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_END, arc.powerType)
        out[#out + 1] = string.format("%s start=(%.2f,%.2f,%.2f) end=(%.2f,%.2f,%.2f) fill=%.0f%%",
            arc.key, sr, sg, sb, er, eg, eb, (arc.fraction or 0) * 100)
    end
    return out
end

-- -----------------------------------------------------------------------------
-- Settings hooks
-- -----------------------------------------------------------------------------
function M.GetFillDirectionName()
    return M.FILL_DIRECTION_NAMES[sv().fillDirection] or M.FILL_DIRECTION_NAMES[M.DEFAULT_FILL_DIRECTION]
end

function M.SetFillDirection(direction)
    sv().fillDirection = direction
    M.Refresh()
end

function M.SetArcOffsetX(value)
    sv().arcOffsetX = value
    ApplyLayout()
    M.Refresh()
end

function M.SetArcHeight(value)
    sv().arcHeight = value
    ApplyLayout()
    M.Refresh()
end

function M.GetHideDefaultBars()
    return sv().hideDefaultBars
end

function M.SetHideDefaultBars(value)
    sv().hideDefaultBars = value
    M.Refresh()
end

function M.SetEnabled(value)
    sv().arcsEnabled = value and true or false
    M.Refresh()
end

-- -----------------------------------------------------------------------------
-- Construction
-- -----------------------------------------------------------------------------
local function CreateControls()
    root = WINDOW_MANAGER:CreateTopLevelWindow("CasualCleanArcsRoot")
    root:SetAnchorFill(GuiRoot)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetDrawLayer(DL_BACKGROUND)
    root:SetDrawTier(DT_LOW)
    root:SetDrawLevel(0)

    for _, spec in ipairs(POWER_TYPES) do
        local name = "CasualCleanArc" .. spec.key
        local container = WINDOW_MANAGER:CreateControl(name, root, CT_CONTROL)
        container:SetAlpha(0)  -- starts hidden; the fade timeline owns alpha

        -- Creation order already puts the border above the fill, but the draw
        -- levels are set explicitly because the ordering is a REQUIREMENT
        -- (border in front, fill behind) rather than an accident of how this
        -- function happens to be written.
        local fill = WINDOW_MANAGER:CreateControl(name .. "Fill", container, CT_TEXTURE)
        fill:SetTexture(TEXTURE_PATH .. spec.fill)
        fill:SetDrawLevel(0)

        local border = WINDOW_MANAGER:CreateControl(name .. "Border", container, CT_TEXTURE)
        border:SetTexture(TEXTURE_PATH .. spec.border)
        border:SetDrawLevel(1)

        local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
            ANIMATION_MANAGER, "CasualCleanArcFade", container)

        local arc = {
            key = spec.key,
            powerType = spec.powerType,
            side = spec.side,
            container = container,
            fill = fill,
            border = border,
            timeline = ok and timeline or nil,
            shown = false,
        }
        arcs[#arcs + 1] = arc
        arcsByPower[spec.powerType] = arc
    end

    -- Hidden outside HUD scenes, on the shared root so both arcs inherit it
    -- through the normal parent-hidden chain.
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function OnPowerUpdate(_, _, _, powerType, current, _, effectiveMax)
    local arc = arcsByPower[powerType]
    if arc then
        RefreshArc(arc)
    end
end

-- One registration per power type, each filtered to the player and to that
-- type -- the same pattern ZOS's own bars use. A single unfiltered
-- registration would wake this code for every power change on every unit in
-- the world. Guarded by a flag so Refresh can call it freely.
local eventsOn = false

RegisterPowerEvents = function()
    if eventsOn then
        return
    end
    for _, spec in ipairs(POWER_TYPES) do
        local eventName = ADDON_NAME .. "Arc" .. spec.key
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_POWER_UPDATE,
            REGISTER_FILTER_UNIT_TAG, "player",
            REGISTER_FILTER_POWER_TYPE, spec.powerType)
    end
    eventsOn = true
end

UnregisterPowerEvents = function()
    if not eventsOn then
        return
    end
    for _, spec in ipairs(POWER_TYPES) do
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Arc" .. spec.key, EVENT_POWER_UPDATE)
    end
    eventsOn = false
end

function M.Init()
    CreateControls()
    ApplyLayout()
    RefreshColors()
    -- Refresh registers the events (or not) according to the master switch.
    M.Refresh()
end
