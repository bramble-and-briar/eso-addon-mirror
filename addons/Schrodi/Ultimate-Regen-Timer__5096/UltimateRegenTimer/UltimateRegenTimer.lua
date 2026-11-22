-- Ultimate Regen Timer (formerly UltimateRetarded)
--
-- In combat, ultimate is only generated passively for 8 seconds after a light or heavy
-- attack hits, you block an attack, or you dodge one. This shows the seconds left.

local ADDON_NAME = "UltimateRegenTimer"
local WINDOW_MS = 8000
local UPDATE_MS = 100
-- Nudge from the exact middle of the action bar buttons, so the number sits on their visual center.
local DEFAULT_OFFSET_Y = 3

local OUTLINES =
{
    { value = "none", name = "None" },
    { value = "soft-shadow-thin", name = "Thin shadow" },
    { value = "soft-shadow-thick", name = "Thick shadow" },
    { value = "thick-outline", name = "Outline" },
}

local defaults =
{
    showOutOfCombat = true,
    size = 36,
    color = { r = 0, g = 1, b = 1, a = 1 },
    expiredColor = { r = 1, g = 0.25, b = 0.25, a = 1 },
    outline = "thick-outline",
    -- nil = between the last skill slot and the ultimate button; otherwise the label's
    -- center in GuiRoot coordinates
    position = nil,
}

local sv
local container, label, defaultAnchor
local lastTrigger = 0
local inCombat = false
local unlocked = false

--------------------------------------------------------------------------------
-- Appearance and position
--------------------------------------------------------------------------------

local function ApplyFont()
    local font = string.format("$(BOLD_FONT)|%d", sv.size)
    if sv.outline ~= "none" then
        font = font .. "|" .. sv.outline
    end
    label:SetFont(font)
end

local function ApplyPosition()
    label:ClearAnchors()
    if sv.position then
        label:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.position.x, sv.position.y)
    else
        label:SetAnchor(CENTER, defaultAnchor, CENTER, 0, DEFAULT_OFFSET_Y)
    end
end

local function GetSecondsLeft()
    local elapsed = GetGameTimeMilliseconds() - lastTrigger
    return zo_ceil(zo_max(WINDOW_MS - elapsed, 0) / 1000)
end

local function Refresh()
    if unlocked then
        label:SetText("8")
        label:SetColor(sv.color.r, sv.color.g, sv.color.b, sv.color.a)
        label:SetHidden(false)
        return
    end

    local seconds = GetSecondsLeft()
    label:SetText(seconds)
    local color = seconds > 0 and sv.color or sv.expiredColor
    label:SetColor(color.r, color.g, color.b, color.a)
    label:SetHidden(seconds == 0 and not inCombat and not sv.showOutOfCombat)
end

local function IsHudShowing()
    return HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
end

-- Unlocking lasts until it's locked again (or /reloadui), so the timer can be moved on the
-- HUD, next to the action bar, in cursor mode. While unlocked it also shows on top of the
-- settings menu.
local function SetUnlocked(value)
    if unlocked == value then return end
    unlocked = value
    if value then
        -- Dragging works on a plain top-left anchor. Starting from the CENTER anchor
        -- made the first drag jump sideways, so switch to the same spot as top-left first.
        local left, top = label:GetLeft(), label:GetTop()
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        ApplyPosition()
    end
    label:SetMouseEnabled(value)
    label:SetMovable(value)
    container:SetHidden(not value and not IsHudShowing())
    Refresh()
    if value then
        CHAT_ROUTER:AddSystemMessage("|c00FFFFUltimate Regen Timer:|r unlocked. Close the menu, switch to cursor mode and drag the number where you want it. Lock it again with /urt or in the settings.")
    else
        CHAT_ROUTER:AddSystemMessage("|c00FFFFUltimate Regen Timer:|r locked.")
    end
end

local function CreateControls()
    container = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Container")
    container:SetDrawLayer(DL_OVERLAY)

    -- Zero-height strip between the last skill slot (ActionButton7) and the ultimate
    -- button (ActionButton8); follows the action bar in keyboard and gamepad layouts.
    defaultAnchor = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "DefaultAnchor", container, CT_CONTROL)
    if ActionButton7 and ActionButton8 then
        defaultAnchor:SetAnchor(LEFT, ActionButton7, RIGHT, 0, 0)
        defaultAnchor:SetAnchor(RIGHT, ActionButton8, LEFT, 0, 0)
    else
        defaultAnchor:SetAnchor(CENTER, GuiRoot, BOTTOM, 0, -120)
        defaultAnchor:SetWidth(1)
    end
    defaultAnchor:SetHeight(1)

    label = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Label", container, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetClampedToScreen(true)
    -- Saved as the center, so a different size or digit width keeps the timer in place.
    -- While unlocked it stays on the top-left anchor the drag left it on.
    label:SetHandler("OnMoveStop", function(control)
        local x, y = control:GetCenter()
        sv.position = { x = zo_round(x), y = zo_round(y) }
    end)


    -- Only on the HUD, like the action bar itself.
    local fragment = ZO_HUDFadeSceneFragment:New(container)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    ApplyFont()
    ApplyPosition()
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    local panelName = ADDON_NAME .. "Settings"
    LAM:RegisterAddonPanel(panelName,
    {
        type = "panel",
        name = "Ultimate Regen Timer",
        author = "Schrodi",
        registerForDefaults = true,
        registerForRefresh = true,
    })

    local outlineNames, outlineValues = {}, {}
    for _, entry in ipairs(OUTLINES) do
        table.insert(outlineNames, entry.name)
        table.insert(outlineValues, entry.value)
    end

    local function ColorOption(name, tooltip, key)
        return
        {
            type = "colorpicker",
            name = name,
            tooltip = tooltip,
            getFunc = function() local c = sv[key] return c.r, c.g, c.b, c.a end,
            setFunc = function(r, g, b, a) sv[key] = { r = r, g = g, b = b, a = a } Refresh() end,
            default = defaults[key],
        }
    end

    LAM:RegisterOptionControls(panelName,
    {
        {
            type = "checkbox",
            name = "Show outside of combat",
            tooltip = "When off, the timer disappears once it reaches 0 outside of combat.",
            getFunc = function() return sv.showOutOfCombat end,
            setFunc = function(value) sv.showOutOfCombat = value Refresh() end,
            default = defaults.showOutOfCombat,
        },
        {
            type = "slider",
            name = "Size",
            min = 14,
            max = 96,
            getFunc = function() return sv.size end,
            setFunc = function(value) sv.size = value ApplyFont() end,
            default = defaults.size,
        },
        ColorOption("Color", "Color while ultimate is being generated.", "color"),
        ColorOption("Color at 0", "Color once the 8 seconds have run out.", "expiredColor"),
        {
            type = "dropdown",
            name = "Outline",
            choices = outlineNames,
            choicesValues = outlineValues,
            getFunc = function() return sv.outline end,
            setFunc = function(value) sv.outline = value ApplyFont() end,
            default = defaults.outline,
        },
        {
            type = "header",
            name = "Position",
        },
        {
            type = "checkbox",
            name = "Unlock to move",
            tooltip = "Stays unlocked after closing the menu: in cursor mode, drag the number next to your action bar, then lock it again here or with /urt.",
            getFunc = function() return unlocked end,
            setFunc = function(value) SetUnlocked(value) end,
        },
        {
            type = "button",
            name = "Reset position",
            tooltip = "Back to the default: between your last skill and the ultimate button.",
            func = function()
                sv.position = nil
                ApplyPosition()
                if unlocked then
                    -- back on a draggable anchor, at the default spot
                    local left, top = label:GetLeft(), label:GetTop()
                    label:ClearAnchors()
                    label:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
                end
            end,
        },
    })

end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local function Trigger()
    lastTrigger = GetGameTimeMilliseconds()
    Refresh()
end

local function OnAttackHit(_, _, _, _, _, abilityActionSlotType)
    if abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK or abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
        Trigger()
    end
end

local function RegisterCombatEvents()
    -- Filtered so only the few relevant combat events reach Lua at all.
    local function Register(suffix, callback, result, unitFilter)
        local name = ADDON_NAME .. suffix
        EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, callback)
        EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_COMBAT_RESULT, result,
            unitFilter, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_IS_ERROR, false)
    end

    Register("Dodge", Trigger, ACTION_RESULT_DODGED, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE)
    Register("Block", Trigger, ACTION_RESULT_BLOCKED_DAMAGE, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE)
    Register("Hit", OnAttackHit, ACTION_RESULT_DAMAGE, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
    Register("Crit", OnAttackHit, ACTION_RESULT_CRITICAL_DAMAGE, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, function(_, isInCombat)
        inCombat = isInCombat
        Refresh()
    end)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("UltimateRegenTimer_SV", 1, nil, defaults)
    inCombat = IsUnitInCombat("player")

    CreateControls()
    CreateSettingsMenu()
    RegisterCombatEvents()
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, UPDATE_MS, Refresh)
    SLASH_COMMANDS["/urt"] = function() SetUnlocked(not unlocked) end
    Refresh()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
