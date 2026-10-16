local ADDON_NAME = "NoireJinsReticle"
local DISPLAY_NAME = "NoireJin's Reticle"

local defaults = {
    color = { r = 1, g = 0, b = 0, a = 1 },
    size = 4,
    hideDefault = true,
    swap = {
        enabled = true,
        color = { r = 0.2, g = 0.8, b = 1, a = 1 },
        size = 28,
        duration = 600, -- milliseconds
    },
    weapon = {
        enabled = true,
        size = 56,
        distance = 40,
        duration = 3, -- seconds the icon stays visible after a swap
    },
}

local sv
local window -- NoireJinsReticleWindow (top level, defined in the XML)
local dot    -- NoireJinsReticleDot (the texture, defined in the XML)
local glow   -- NoireJinsReticleGlow (swap indicator, defined in the XML)
local glowTimeline
local glowAnim
local lastWeaponPair
local weaponIcon -- NoireJinsReticleWeaponIcon
local weaponGlow -- NoireJinsReticleWeaponGlow

-- One-handed weapon types (anything else in a hand, like a shield, is not a wielded weapon).
local ONE_HANDED = {}
for _, weaponType in pairs({
    AXE = WEAPONTYPE_AXE,
    HAMMER = WEAPONTYPE_HAMMER,
    SWORD = WEAPONTYPE_SWORD,
    DAGGER = WEAPONTYPE_DAGGER,
}) do
    ONE_HANDED[weaponType] = true
end

-- Two-handed weapon types, each with its own icon (texture files: <kind>.dds and <kind>_glow.dds).
local TWO_HANDED_KIND = {
    [WEAPONTYPE_TWO_HANDED_SWORD] = "greatsword",
    [WEAPONTYPE_TWO_HANDED_AXE] = "battleaxe",
    [WEAPONTYPE_TWO_HANDED_HAMMER] = "maul",
}

-- Bow and staves. Each staff also gets a small element badge next to the icon.
-- Restoration staff shows a plain staff icon with no badge.
local BADGE_KIND = {} -- weapon type -> element name ("fire", "ice", "lightning")
local function AddKind(weaponType, kind, element)
    if weaponType == nil then return end -- constant missing on this game version: skip safely
    TWO_HANDED_KIND[weaponType] = kind
    BADGE_KIND[weaponType] = element
end
AddKind(WEAPONTYPE_BOW, "bow")
AddKind(WEAPONTYPE_FIRE_STAFF, "staff", "fire")
AddKind(WEAPONTYPE_FROST_STAFF, "staff", "ice")
AddKind(WEAPONTYPE_LIGHTNING_STAFF, "staff", "lightning")
AddKind(WEAPONTYPE_HEALING_STAFF, "staff")

local BADGE_COLOR = {
    fire = { 1, 0.47, 0.12 },
    lightning = { 1, 0.89, 0.24 },
    ice = { 0.59, 0.88, 1 },
}
local weaponBadge       -- NoireJinsReticleBadge (staff element icon)
local weaponBadgeShadow -- NoireJinsReticleBadgeShadow
local currentElement = nil

local currentKind = "dualwield" -- icon texture currently applied (also used for settings previews)

-- Returns the icon kind ("dualwield", "greatsword", "battleaxe", "maul", "bow", "staff") for the active bar,
-- plus the staff element when there is one. Returns nil for anything else.
-- The game keeps bar 1 in the MAIN/OFF slots and bar 2 in the BACKUP slots permanently,
-- so we have to pick the slots that belong to the bar that is currently active.
local function GetActiveHandTypes(bar)
    local activeBar = bar or GetActiveWeaponPairInfo()
    if activeBar == 2 then
        return GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN), GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_OFF)
    end
    return GetItemWeaponType(BAG_WORN, EQUIP_SLOT_MAIN_HAND), GetItemWeaponType(BAG_WORN, EQUIP_SLOT_OFF_HAND)
end

local function GetWeaponIconKind(bar)
    local main, off = GetActiveHandTypes(bar)
    if ONE_HANDED[main] and ONE_HANDED[off] then
        return "dualwield"
    end
    return TWO_HANDED_KIND[main], BADGE_KIND[main]
end

-- Points the icon and its glow at the textures for the given kind.
local function ApplyWeaponTexture(kind, element)
    if not weaponIcon or not kind then return end
    currentKind = kind
    currentElement = element
    weaponIcon:SetTexture("NoireJinsReticle/" .. kind .. ".dds")
    weaponGlow:SetTexture("NoireJinsReticle/" .. kind .. "_glow.dds")
    if weaponBadge and element then
        weaponBadge:SetTexture("NoireJinsReticle/badge_" .. element .. ".dds")
        weaponBadgeShadow:SetTexture("NoireJinsReticle/badge_" .. element .. "_glow.dds")
        local c = BADGE_COLOR[element]
        if c then weaponBadge:SetColor(c[1], c[2], c[3], 1) end
        weaponBadgeShadow:SetColor(0, 0, 0, 0.8) -- dark outline so the badge stays readable
    end
end

local function ApplyWeaponStyle()
    if not weaponIcon then return end
    local w = sv.weapon
    local offsetY = -w.distance -- negative = above the dot
    -- The icon itself is always white; the glow border uses the shared "Swap glow" color.
    local c = sv.swap.color
    weaponIcon:SetColor(1, 1, 1, 1)
    weaponGlow:SetColor(c.r, c.g, c.b, c.a)
    for _, control in ipairs({ weaponIcon, weaponGlow }) do
        control:SetDimensions(w.size, w.size)
        control:ClearAnchors()
        control:SetAnchor(CENTER, window, CENTER, 0, offsetY)
    end
    if weaponBadge then
        -- Badge is half the icon size and sits just to the right of it.
        local badgeSize = math.floor(w.size / 2)
        local badgeX = math.floor(w.size * 0.34)
        for _, control in ipairs({ weaponBadgeShadow, weaponBadge }) do
            control:SetDimensions(badgeSize, badgeSize)
            control:ClearAnchors()
            control:SetAnchor(CENTER, window, CENTER, badgeX, offsetY)
        end
    end
end

local forceIcon = false -- set by "/nreticle icon" to keep the icon on for testing
local iconToken = 0       -- bumped each time the icon is shown/hidden so old timers are ignored
local fadeTimeline        -- fades the icon out at the end of its time (created in SetupDot)

-- Hides or shows the icon, its glow and (only when the weapon has an element) the badge.
local function SetIconsHidden(hidden)
    weaponIcon:SetHidden(hidden)
    weaponGlow:SetHidden(hidden)
    if weaponBadge then
        local showBadge = (not hidden) and currentElement ~= nil
        weaponBadge:SetHidden(not showBadge)
        weaponBadgeShadow:SetHidden(not showBadge)
    end
end

local function SetIconsAlpha(alpha)
    weaponIcon:SetAlpha(alpha)
    weaponGlow:SetAlpha(alpha)
    if weaponBadge then
        weaponBadge:SetAlpha(alpha)
        weaponBadgeShadow:SetAlpha(alpha)
    end
end

local function HideWeaponIcon()
    iconToken = iconToken + 1
    if fadeTimeline then fadeTimeline:Stop() end
    if weaponIcon then
        SetIconsHidden(true)
        SetIconsAlpha(1)
    end
end

-- Shows the icon for the configured number of seconds, then fades it out.
-- "preview" shows it even when the active bar is not dual wield (used by the settings page).
local function ShowWeaponIcon(preview, bar)
    if not weaponIcon then return end
    local kind, element = GetWeaponIconKind(bar)
    if not sv.weapon.enabled or not (preview or forceIcon or kind ~= nil) then
        HideWeaponIcon()
        return
    end
    if kind then
        ApplyWeaponTexture(kind, element) -- element may be nil (no badge); that must clear the old badge
    else
        ApplyWeaponTexture(currentKind, currentElement) -- settings preview keeps the last icon
    end

    iconToken = iconToken + 1
    local token = iconToken
    if fadeTimeline then fadeTimeline:Stop() end
    SetIconsAlpha(1)
    SetIconsHidden(false)

    if forceIcon then return end -- test mode keeps it on
    zo_callLater(function()
        if token == iconToken and fadeTimeline then
            fadeTimeline:PlayFromStart()
        end
    end, sv.weapon.duration * 1000)
end

-- Hides the icon if it no longer applies (setting off, or a different weapon type). Never shows it.
local function UpdateWeaponIcon()
    if not weaponIcon then return end
    local kind, element = GetWeaponIconKind()
    if not sv.weapon.enabled or not (forceIcon or kind ~= nil) then
        HideWeaponIcon()
    elseif kind and not forceIcon then
        ApplyWeaponTexture(kind, element) -- weapon type changed while the icon is showing
        if not weaponIcon:IsHidden() then SetIconsHidden(false) end -- refresh badge visibility
    end
end

local function ApplyStyle()
    if not dot then return end
    dot:SetColor(sv.color.r, sv.color.g, sv.color.b, sv.color.a)
    dot:SetDimensions(sv.size, sv.size)
    if glow then
        local c = sv.swap.color
        glow:SetColor(c.r, c.g, c.b, c.a)
        glow:SetDimensions(sv.swap.size, sv.swap.size)
    end
    ApplyWeaponStyle()
end

-- Plays the brief glow around the dot (used when a weapon swap happens).
local function PlayGlow()
    if not glow or not glowTimeline then return end
    glowAnim:SetDuration(sv.swap.duration)
    glowTimeline:PlayFromStart()
end

local function OnWeaponPairChanged(_, activeWeaponPair)
    if activeWeaponPair == lastWeaponPair then return end
    lastWeaponPair = activeWeaponPair
    if sv.swap.enabled then
        PlayGlow()
    end
    ShowWeaponIcon(false, activeWeaponPair)
end

-- Hides (or restores) the game's built-in reticle. Alpha is used rather than
-- SetHidden because the game re-shows the reticle whenever the target changes.
local function ApplyDefaultReticle()
    local reticle = ZO_ReticleContainerReticle
    if reticle then
        reticle:SetAlpha(sv.hideDefault and 0 or 1)
    end
end

local function SetupDot()
    window = NoireJinsReticleWindow
    dot = NoireJinsReticleDot
    glow = NoireJinsReticleGlow
    weaponIcon = NoireJinsReticleWeaponIcon
    weaponGlow = NoireJinsReticleWeaponGlow
    weaponBadge = NoireJinsReticleBadge             -- optional: only present with the newer XML
    weaponBadgeShadow = NoireJinsReticleBadgeShadow
    if not window or not dot or not glow or not weaponIcon or not weaponGlow then
        d("[" .. DISPLAY_NAME .. "] ERROR: XML controls were not created. Check that NoireJinsReticle.xml is in the addon folder.")
        return
    end

    -- Fade-out animation for the swap glow: fully visible, then fades to nothing.
    glowTimeline = ANIMATION_MANAGER:CreateTimeline()
    glowAnim = glowTimeline:InsertAnimation(ANIMATION_ALPHA, glow, 0)
    glowAnim:SetAlphaValues(1, 0)
    glowAnim:SetDuration(sv.swap.duration)
    glowTimeline:SetHandler("OnStop", function() glow:SetAlpha(0) end)
    glow:SetAlpha(0) -- the XML alpha is not reliable; start invisible so it only shows during a swap

    -- Show the dot only on the normal gameplay HUD (hidden in menus, maps, etc.)
    local fragment = ZO_SimpleSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)

    -- If the HUD is already showing, the fragment will not trigger until the next
    -- scene change, so show the window now.
    if SCENE_MANAGER:IsShowing("hud") then
        window:SetHidden(false)
    end

    -- Fade-out for the weapon icon: after its time is up, fades to nothing over 0.4s, then hides.
    fadeTimeline = ANIMATION_MANAGER:CreateTimeline()
    local fadeControls = { weaponIcon, weaponGlow }
    if weaponBadge and weaponBadgeShadow then
        fadeControls[#fadeControls + 1] = weaponBadge
        fadeControls[#fadeControls + 1] = weaponBadgeShadow
    end
    for _, control in ipairs(fadeControls) do
        local fade = fadeTimeline:InsertAnimation(ANIMATION_ALPHA, control, 0)
        fade:SetAlphaValues(1, 0)
        fade:SetDuration(400)
    end
    fadeTimeline:SetHandler("OnStop", function(_, completedPlaying)
        if completedPlaying then
            iconToken = iconToken + 1
            SetIconsHidden(true)
            SetIconsAlpha(1)
        end
    end)

    ApplyStyle()
    ApplyWeaponStyle()
    UpdateWeaponIcon()
end

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then
        d("[" .. DISPLAY_NAME .. "] LibAddonMenu-2.0 is not installed, so the settings page is unavailable.")
        return
    end

    LAM:RegisterAddonPanel(ADDON_NAME .. "Panel", {
        type = "panel",
        name = DISPLAY_NAME,
        displayName = DISPLAY_NAME,
        author = "NoireJin",
        version = "1.7.1",
        registerForRefresh = true,
    })

    LAM:RegisterOptionControls(ADDON_NAME .. "Panel", {
        {
            type = "colorpicker",
            name = "Dot Color",
            tooltip = "Choose the color (and opacity) of the reticle dot.",
            getFunc = function()
                return sv.color.r, sv.color.g, sv.color.b, sv.color.a
            end,
            setFunc = function(r, g, b, a)
                sv.color.r, sv.color.g, sv.color.b, sv.color.a = r, g, b, a
                ApplyStyle()
            end,
            default = defaults.color,
            width = "full",
        },
        {
            type = "slider",
            name = "Dot Size",
            tooltip = "Size of the dot in pixels.",
            min = 1,
            max = 16,
            step = 1,
            getFunc = function() return sv.size end,
            setFunc = function(value)
                sv.size = value
                ApplyStyle()
            end,
            default = defaults.size,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Hide Default Reticle",
            tooltip = "Hide the game's built-in reticle so only the dot shows.",
            getFunc = function() return sv.hideDefault end,
            setFunc = function(value)
                sv.hideDefault = value
                ApplyDefaultReticle()
            end,
            default = defaults.hideDefault,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Swap indicator",
            tooltip = "Briefly glow around the reticle when you swap weapons.",
            getFunc = function() return sv.swap.enabled end,
            setFunc = function(value)
                sv.swap.enabled = value
            end,
            default = defaults.swap.enabled,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Swap glow",
            tooltip = "Color (and opacity) of the swap flash around the dot and the border around the weapon icon.",
            getFunc = function()
                local c = sv.swap.color
                return c.r, c.g, c.b, c.a
            end,
            setFunc = function(r, g, b, a)
                local c = sv.swap.color
                c.r, c.g, c.b, c.a = r, g, b, a
                ApplyStyle()
                PlayGlow() -- preview
                ShowWeaponIcon(true) -- preview
            end,
            default = defaults.swap.color,
            disabled = function() return not sv.swap.enabled and not sv.weapon.enabled end,
            width = "full",
        },
        {
            type = "slider",
            name = "Swap Glow Size",
            tooltip = "Size of the swap glow in pixels.",
            min = 8,
            max = 96,
            step = 2,
            getFunc = function() return sv.swap.size end,
            setFunc = function(value)
                sv.swap.size = value
                ApplyStyle()
                PlayGlow() -- preview
            end,
            default = defaults.swap.size,
            disabled = function() return not sv.swap.enabled end,
            width = "full",
        },
        {
            type = "slider",
            name = "Swap Glow Duration (ms)",
            tooltip = "How long the glow lasts before it fades out.",
            min = 200,
            max = 2000,
            step = 100,
            getFunc = function() return sv.swap.duration end,
            setFunc = function(value)
                sv.swap.duration = value
                PlayGlow() -- preview
            end,
            default = defaults.swap.duration,
            disabled = function() return not sv.swap.enabled end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Weapon icon",
            tooltip = "Show a glowing icon by the reticle for your equipped weapon type (dual wield, greatsword, battleaxe, maul, bow, staff).",
            getFunc = function() return sv.weapon.enabled end,
            setFunc = function(value)
                sv.weapon.enabled = value
                if value then ShowWeaponIcon(true) else HideWeaponIcon() end
            end,
            default = defaults.weapon.enabled,
            width = "full",
        },
        {
            type = "slider",
            name = "Weapon Icon Duration (s)",
            tooltip = "How many seconds the icon stays visible after you swap bars, before it fades out.",
            min = 0.5,
            max = 10,
            step = 0.5,
            decimals = 1,
            getFunc = function() return sv.weapon.duration end,
            setFunc = function(value)
                sv.weapon.duration = value
                ShowWeaponIcon(true) -- preview
            end,
            default = defaults.weapon.duration,
            disabled = function() return not sv.weapon.enabled end,
            width = "full",
        },
        {
            type = "slider",
            name = "Weapon Icon Size",
            tooltip = "Size of the weapon icon in pixels.",
            min = 24,
            max = 128,
            step = 4,
            getFunc = function() return sv.weapon.size end,
            setFunc = function(value)
                sv.weapon.size = value
                ApplyWeaponStyle()
                ShowWeaponIcon(true) -- preview
            end,
            default = defaults.weapon.size,
            disabled = function() return not sv.weapon.enabled end,
            width = "full",
        },
        {
            type = "slider",
            name = "Weapon Icon Distance",
            tooltip = "How far above the dot the icon sits, in pixels.",
            min = 10,
            max = 200,
            step = 5,
            getFunc = function() return sv.weapon.distance end,
            setFunc = function(value)
                sv.weapon.distance = value
                ApplyWeaponStyle()
                ShowWeaponIcon(true) -- preview
            end,
            default = defaults.weapon.distance,
            disabled = function() return not sv.weapon.enabled end,
            width = "full",
        },
    })
end

local startupErrors = {} -- errors caught while starting up, shown by /nreticle

-- Typing /nreticle in chat prints the addon's state, for troubleshooting.
-- "/nreticle icon" forces the weapon icon on to test the texture.
local function RegisterDebugCommand()
    SLASH_COMMANDS["/nreticle"] = function(arg)
        d("[" .. DISPLAY_NAME .. "] addon is running (version 1.7.1)")
        for _, err in ipairs(startupErrors) do
            d("[" .. DISPLAY_NAME .. "] STARTUP ERROR " .. err)
        end
        if not (sv and window and dot and weaponIcon and weaponGlow) then
            d("[" .. DISPLAY_NAME .. "] controls missing: window=" .. tostring(window ~= nil) .. " dot=" .. tostring(dot ~= nil)
                .. " weaponIcon=" .. tostring(weaponIcon ~= nil) .. " weaponGlow=" .. tostring(weaponGlow ~= nil)
                .. " (is NoireJinsReticle.xml the latest version?)")
            return
        end
        local cmd, which, elem = string.match(arg or "", "^(%S+)%s*(%S*)%s*(%S*)")
        if cmd == "icon" then
            if which ~= "" then
                ApplyWeaponTexture(which, elem ~= "" and elem or nil) -- e.g. /nreticle icon staff fire
                forceIcon = true
            else
                forceIcon = not forceIcon
            end
            if forceIcon then ShowWeaponIcon(true) else HideWeaponIcon() end
            d("[" .. DISPLAY_NAME .. "] forced icon test: " .. (forceIcon and "ON (icon should be visible)" or "OFF"))
        end
        local activeMain, activeOff = GetActiveHandTypes()
        d(string.format("[%s] ACTIVE bar weapon types: main=%s, off=%s (dual wield = two one-handed; two-handed sword/axe/hammer have own icons)",
            DISPLAY_NAME, tostring(activeMain), tostring(activeOff)))
        d(string.format("[%s] active bar=%s | bar1 main=%s off=%s | bar2 main=%s off=%s",
            DISPLAY_NAME, tostring(GetActiveWeaponPairInfo()),
            tostring(GetItemWeaponType(BAG_WORN, EQUIP_SLOT_MAIN_HAND)),
            tostring(GetItemWeaponType(BAG_WORN, EQUIP_SLOT_OFF_HAND)),
            tostring(GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN)),
            tostring(GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_OFF))))
        local kindNow, elementNow = GetWeaponIconKind()
        d(string.format("[%s] icon kind=%s element=%s (shown texture=%s), enabled=%s, icon hidden=%s, glow hidden=%s",
            DISPLAY_NAME, tostring(kindNow), tostring(elementNow), currentKind, tostring(sv.weapon.enabled),
            tostring(weaponIcon:IsHidden()), tostring(weaponGlow:IsHidden())))
        d(string.format("[%s] window hidden=%s, dot hidden=%s, size=%d, color=%.2f/%.2f/%.2f/%.2f",
            DISPLAY_NAME,
            tostring(window:IsHidden()), tostring(dot:IsHidden()), sv.size,
            sv.color.r, sv.color.g, sv.color.b, sv.color.a))
    end
end

local reportedStartup = false
local function OnPlayerActivated()
    if not reportedStartup then
        reportedStartup = true
        if #startupErrors > 0 then
            d("[" .. DISPLAY_NAME .. "] had problems starting. Type /nreticle for details.")
        end
    end
    ApplyDefaultReticle()
    ApplyStyle()
    -- After a login/reload/loading screen the swap glow must be invisible (loading in is not a swap).
    if glow and not (glowTimeline and glowTimeline:IsPlaying()) then
        glow:SetAlpha(0)
    end
    -- Record the current weapon bar without glowing (loading in is not a swap).
    lastWeaponPair = GetActiveWeaponPairInfo()
    UpdateWeaponIcon()
    -- Equipped items are not always ready the instant a loading screen ends.
    zo_callLater(UpdateWeaponIcon, 1000)
end

-- Fill in any setting missing from older saved data (e.g. after an update adds new options).
local function EnsureDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                EnsureDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            EnsureDefaults(target[key], value)
        end
    end
end

-- Runs one startup step; if it fails, the error is kept (not lost) so /nreticle can show it.
local function Try(stepName, fn)
    local ok, err = pcall(fn)
    if not ok then
        startupErrors[#startupErrors + 1] = stepName .. ": " .. tostring(err)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Register the troubleshooting command first so it exists even if a later step fails.
    RegisterDebugCommand()

    Try("saved settings", function()
        sv = ZO_SavedVars:NewAccountWide("NoireJinsReticleSV", 2, nil, defaults)
        EnsureDefaults(sv, defaults)
    end)
    if not sv then return end

    Try("create dot", SetupDot)
    Try("settings page", CreateSettings)
    Try("hide default reticle", ApplyDefaultReticle)

    -- Re-apply after loading screens, since the HUD can reset the reticle.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    Try("weapon swap events", function()
        lastWeaponPair = GetActiveWeaponPairInfo()
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Swap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPairChanged)

        -- Re-check the weapon icon when worn gear changes (e.g. equipping a different weapon).
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            UpdateWeaponIcon()
        end)
        EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
