-- Questbound.lua : start-up, saved settings, colors, slash command.
-- (Called "Wayfinder" inside until 0.18.0; renamed everywhere because an ESOUI addon
-- named Wayfinder already exists.) One global table: Questbound.
-- The parts: Questbound_Nav.lua (where to go), Questbound_Arrow.lua (HUD arrow),
-- Questbound_Path.lua (GPS arrows on the ground), Questbound_Tracker.lua (quest list),
-- Questbound_Launcher.lua (the rounded Questbound button).

local ADDON_NAME = "Questbound"
Questbound = Questbound or {}
local W = Questbound
local L = W.L

-- Shipped route data (Questbound_RouteData.lua, written by the dev script as one plain
-- table): kept in the addon's own table, the temporary global is removed.
W.RouteData = Questbound_RouteData
Questbound_RouteData = nil

W.VERSION = "1.0.1"
W.TEX = "Questbound/Textures/"

-- Colors are plain { r, g, b } tables (0..1): ZO_ColorDef came out white in 0.2.0.
local function Hex(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end

W.COLOR = {
    theme = Hex("D9B366"),     -- ESO gold accent (sv.theme can change it)
    text = Hex("E6E2D6"),
    dim = Hex("8E8C86"),
    done = Hex("7DB87D"),
    warn = Hex("E0603C"),      -- arrow when the objective is behind you
    optional = Hex("8FB0C4"),
    story = Hex("B9A2E6"),     -- main story quests
    gold = Hex("A8915E"),      -- dividers and frame lines
    quest = Hex("C5C29E"),     -- the game's normal text color
}

-- control:SetColor(W.RGBA(color[, alpha]))
function W.RGBA(c, a)
    return c.r, c.g, c.b, a or 1
end

-- "|cRRGGBBtext|r"
function W.Colorize(c, text)
    return string.format("|c%02X%02X%02X%s|r", zo_round(c.r * 255), zo_round(c.g * 255), zo_round(c.b * 255), text)
end

-- Lettering. "eso": Trajan headings (the game's logo / zone title letters) and
-- Prose Antique quest names (books, quest journal), clear text for objectives.
W.FONT_STYLES = {
    eso = { title = "$(STONE_TABLET_FONT)", quest = "$(ANTIQUE_FONT)", text = "$(MEDIUM_FONT)" },
    book = { title = "$(ANTIQUE_FONT)", quest = "$(ANTIQUE_FONT)", text = "$(ANTIQUE_FONT)" },
    plain = { title = "$(BOLD_FONT)", quest = "$(BOLD_FONT)", text = "$(MEDIUM_FONT)" },
}

-- kind: "title", "quest" or "text". Prose Antique runs small, so it gets +2.
function W.Font(kind, size)
    local style = W.FONT_STYLES[W.sv.fontStyle] or W.FONT_STYLES.eso
    local face = style[kind] or style.text
    if face == "$(ANTIQUE_FONT)" then size = size + 2 end
    return face .. "|" .. size .. "|soft-shadow-thick"
end

local defaults = {
    target = "auto",          -- "auto" (map marker first, else quest), "quest", "waypoint"
    hideGameTracker = true,
    banner = true,            -- "Objective complete / Next: ..." banner for the followed quest
    followNewQuest = true,    -- a newly accepted quest becomes the followed one
    hideAuiTracker = true,    -- hide Advanced UI's quest tracker while ours is shown (a one-time chat note says so)
    auiNoticeShown = false,   -- that note was shown (once per account, never again)
    fontStyle = "eso",        -- see W.FONT_STYLES
    theme = { r = 0.85, g = 0.70, b = 0.40 },   -- accent color (ESO gold)
    anim = "full",           -- animations: "full", "subtle" or "off"
    npcMarker = true,         -- Skyrim-style marker + golden ring at the NPC to talk to
    killArea = true,          -- red hunting area + crossed swords for kill objectives
    killBadge = true,         -- red badge + count by the crosshair on quest monsters
    combatFade = true,        -- tracker and nameplate step back in combat
    units = "metric",         -- distances: "metric" (m / km) or "imperial" (ft / mi)
    minimap = true,           -- the way on AUI's minimap (when AUI is installed)
    -- uiVersion: not a default on purpose, nil = saved before 0.2.0
    roads = {},               -- learned streets per zone, see Questbound_Roads.lua
    cal = {},                 -- learned map sizes: [map texture] = { s, ox, oz, sx, sz, base }
    tracker = {
        shown = true,
        x = nil, y = nil,     -- top right corner of the panel
        width = 446,          -- standard size (release layout, 2026-09-30)
        maxHeight = 528,
        height = 528,         -- a height dragged by hand stays; /qb reset = back to fitting the list
        locked = false,
        minimized = false,
        tab = "all",          -- "current", "main", "here", "all", "dungeons", "daily"
        expandAll = false,
        expanded = {},        -- [quest name] = true / false (opened or closed by hand)
        collapsedZones = {},  -- [zone name] = true (folded) / false (opened by hand)
        pins = {},            -- [quest name] = true: in the "Pinned" group on top
        hide = {},            -- [quest name] = true: in the folded "Hidden" group at the end
        showDistance = true,
        showTeleport = true,
        panelStyle = "ledger", -- "ledger" (gold frame, followed quest on a card), "trail" (frameless, gold trail
                               -- linking the quests), "eso" (gold border) or "flat"
        bgAlpha = 0.75,
        fontSize = 15,
    },
    arrow = {
        shown = true,
        x = nil, y = nil,     -- center of the arrow
        size = 56,
        locked = false,
        showName = true,
        showDistance = true,
        colorByAngle = true,
        hideInCombat = false,
        design = "ornate",    -- see Arrow.DESIGNS
        style = "compact",    -- "compact" (small arrow badge inside the text pill) or "classic" (big arrow above the text)
        quiet = false,        -- (removed in 0.13.1: the objective name always stays)
        travelHint = true,    -- "Faster: travel to <wayshrine>" / "click to travel there" in the text
        fx = {                -- compact badge animations (sv.anim "off" turns all off)
            spin = true,      -- spins in on a new objective
            glow = true,      -- halo while you face the objective
            arrive = true,    -- check + green ripple when you're there
            turn = true,      -- light runs round the rim toward the side to turn (objective behind you)
        },
    },
    launcher = {              -- the rounded Questbound button (like Set Hunter's)
        hidden = false,
        compact = false,      -- only the logo (the ‹ / › arrow on the button switches)
        combatHide = true,    -- out of the way while you fight
        x = nil, y = nil,     -- top left once you move it; nil = right above the quest tracker
    },
    label = {                 -- the text panel (objective, distance), separate from the arrow
        shown = true,
        x = nil, y = nil,     -- top center; nil = right under the arrow
        scale = 1,
        locked = false,
        bg = "lines",         -- "lines" (text + gold lines), "dark", "none"
    },
    path = {
        shown = true,
        style = "solid",      -- "solid" (filled chevrons), "chevrons" (dotted), "comet", "dots", "line"
        pillar = false,       -- light pillar on far objectives (off: too distracting; the marker shows instead)
        learn = true,         -- record the streets you walk
        roads = true,         -- the line follows learned streets
        chevFix = 0,          -- /qb chevron: which way the ground chevrons are turned
        length = 30,          -- meters
        width = 0.2,          -- meters
        alpha = 0.9,
        flow = true,
        depth = false,
        marker = true,
        color = { r = 0.85, g = 0.70, b = 0.40 },
    },
}

W.callbacks = ZO_CallbackObject:New()

function W.Print(text)
    d(W.Colorize(W.COLOR.theme, L("PREFIX")) .. " " .. text)
end

-- Accent color from the settings; the ColorDef is changed in place so every
-- part that holds W.COLOR.theme picks it up.
function W.ApplyTheme()
    local c = W.sv.theme
    local theme = W.COLOR.theme
    theme.r, theme.g, theme.b = c.r, c.g, c.b
end

-- Fragment that shows a control only on the normal HUD (hidden in menus, map, dialogs).
-- Turned off = the fragment is taken out of the HUD scenes (fragment:SetHiddenForReason
-- didn't hide anything in-game, so it isn't used).
function W.HudFragment(control)
    local fragment = ZO_HUDFadeSceneFragment:New(control)
    fragment.wfControl = control
    W.ShowOnHud(fragment, true)
    return fragment
end

function W.ShowOnHud(fragment, show)
    if fragment.wfShown ~= show then
        fragment.wfShown = show
        if show then
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
        else
            HUD_SCENE:RemoveFragment(fragment)
            HUD_UI_SCENE:RemoveFragment(fragment)
        end
    end
    fragment.wfControl:SetHidden(not show or not (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()))
end

-- ---------------------------------------------------------------------------
-- Image check. ESO only loads NEW image files when the game starts (not on
-- /reloadui). A tiny probe texture per file tells whether it's really there, so
-- the ground line can fall back to an older image and the player gets told.

local probeWin
local probes = {}
W.NEW_TEXTURES = { "plate.dds", "beam.dds", "arrow_ornate.dds", "marker_tes.dds", "swords.dds", "badge_kill.dds", "disc.dds",
    "logo_fill.dds", "logo_gold.dds", "rim.dds", "pointer.dds", "arc.dds",
    "chev_solid.dds", "chev_shadow.dds", "chev_edge.dds", "search.dds",
    "lock_body.dds", "lock_shackle.dds", "diamond.dds" }

function W.TextureLoaded(file)
    local probe = probes[file]
    if not probe then
        if not probeWin then
            probeWin = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Probe")
            probeWin:SetDimensions(4, 4)
            probeWin:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -50, -50)   -- off screen
        end
        probe = WINDOW_MANAGER:CreateControl(nil, probeWin, CT_TEXTURE)
        probe:SetDimensions(2, 2)
        probe:SetAnchor(TOPLEFT, probeWin, TOPLEFT, 0, 0)
        probe:SetTexture(W.TEX .. file)
        probes[file] = probe
    end
    return probe:IsTextureLoaded()
end

function W.TextureReport()
    local parts = {}
    for _, file in ipairs(W.NEW_TEXTURES) do
        parts[#parts + 1] = file .. (W.TextureLoaded(file) and " ok" or " |cE0603CMISSING|r")
    end
    return "images: " .. table.concat(parts, ", ")
end

local function CheckTextures()
    local missing = {}
    for _, file in ipairs(W.NEW_TEXTURES) do
        if not W.TextureLoaded(file) then missing[#missing + 1] = file end
    end
    if #missing > 0 then W.Print(L("TEX_MISSING")) end
    W.callbacks:FireCallbacks("SettingsChanged")   -- images that loaded meanwhile get used
end

-- Meters as "85 m" / "1.4 km", or with sv.units = "imperial" as "280 ft" / "0.9 mi"
-- (feet up to 1000 ft, then miles, like a car navigation app).
local FEET_PER_M, M_PER_MILE = 3.28084, 1609.344
function W.FormatDistance(meters)
    if W.sv.units == "imperial" then
        local feet = meters * FEET_PER_M
        if feet >= 1000 then return L("DIST_MI", meters / M_PER_MILE) end
        return L("DIST_FT", zo_round(feet))
    end
    if meters >= 1000 then return L("DIST_KM", meters / 1000) end
    return L("DIST_M", zo_round(meters))
end

-- The parts you can hide, with their name and the command that brings them back.
local PARTS = {
    { section = "tracker", name = "NAME_TRACKER", cmd = "/qb" },
    { section = "arrow", name = "NAME_ARROW", cmd = "/qb arrow" },
    { section = "label", name = "NAME_TEXT", cmd = "/qb text" },
    { section = "path", name = "NAME_PATH", cmd = "/qb gps" },
}

local function Toggle(section)
    local sv = W.sv[section]
    sv.shown = not sv.shown
    W.callbacks:FireCallbacks("SettingsChanged")
    for _, p in ipairs(PARTS) do
        if p.section == section then
            -- hidden: say how to get it back (right-click "Hide" gives no other hint)
            W.Print(sv.shown and L("SHOWN", L(p.name)) or L("HIDDEN_HINT", L(p.name), p.cmd))
        end
    end
end

function W.ToggleTracker() Toggle("tracker") end
function W.ToggleArrow() Toggle("arrow") end
function W.TogglePath() Toggle("path") end
function W.ToggleText() Toggle("label") end

-- /qb: brings back the tracker, arrow, arrow text and launcher button when any of
-- them is hidden (hidden by right-click or keybind); true when something was shown again.
function W.ShowHidden()
    local names = {}
    if W.sv.launcher.hidden then
        W.sv.launcher.hidden = false
        names[#names + 1] = L("NAME_LAUNCHER")
    end
    for _, p in ipairs(PARTS) do
        if p.section ~= "path" and not W.sv[p.section].shown then
            W.sv[p.section].shown = true
            names[#names + 1] = L(p.name)
        end
    end
    if #names == 0 then return false end
    W.callbacks:FireCallbacks("SettingsChanged")
    W.Print(L("SHOWN", table.concat(names, ", ")))
    return true
end

function W.ResetPositions()
    W.sv.tracker.x, W.sv.tracker.y = nil, nil
    -- the standard size too (same as the defaults)
    W.sv.tracker.width, W.sv.tracker.height, W.sv.tracker.maxHeight = 446, 528, 528
    W.sv.label.scale = 1
    W.sv.arrow.x, W.sv.arrow.y = nil, nil
    W.sv.label.x, W.sv.label.y = nil, nil
    W.sv.launcher.x, W.sv.launcher.y = nil, nil   -- back above the tracker
    W.callbacks:FireCallbacks("PositionsReset")
    W.Print(L("RESET_DONE"))
end

local function Slash(args)
    args = zo_strlower(zo_strtrim(args or ""))
    if args == "" then
        -- something hidden: bring it back; else show / hide the tracker
        if not W.ShowHidden() then W.ToggleTracker() end
    elseif args == "arrow" then
        W.ToggleArrow()
    elseif args == "text" then
        W.ToggleText()
    elseif args == "gps" or args == "line" or args == "path" then
        W.TogglePath()
    elseif args == "next" then
        W.Nav.AssistNext()
    elseif args == "settings" then
        W.OpenSettings()
    elseif args == "reset" then
        W.ResetPositions()
    elseif args == "banner" then
        W.Banner.Test()
    elseif args == "debug" then
        W.Nav.Debug()
    elseif args == "obj" then
        W.Nav.DebugObjectives()
    else
        W.Print(L("HELP"))
    end
end

ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_TRACKER", L("BIND_TRACKER"))
ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_NEXT", L("BIND_NEXT"))
ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_PATH", L("BIND_PATH"))
ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_ARROW", L("BIND_ARROW"))
ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_TEXT", L("BIND_TEXT"))
ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_TELEPORT", L("BIND_TELEPORT"))

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    W.sv = ZO_SavedVars:NewAccountWide("Questbound_SV", 1, nil, defaults)
    -- A fresh install (no uiVersion saved yet) already has today's defaults: none of the
    -- upgrade steps below may touch it. (Only the developer's data from before the
    -- release ever needed them.) Raise UI_VERSION with every new step.
    local UI_VERSION = 14
    if W.sv.uiVersion == nil then W.sv.uiVersion = UI_VERSION end
    -- saved before 0.2.0: new opaque look
    if W.sv.uiVersion < 2 then
        W.sv.tracker.bgAlpha = 0.95
        W.sv.uiVersion = 2
    end
    -- 0.2.0: teal became violet; a ground line still on the old teal default follows
    if W.sv.uiVersion < 3 then
        local c = W.sv.path.color
        if math.abs(c.r - 0.31) < 0.01 and math.abs(c.g - 0.76) < 0.01 and math.abs(c.b - 0.78) < 0.01 then
            W.sv.path.color = { r = 0.85, g = 0.70, b = 0.40 }
        end
        W.sv.uiVersion = 3
    end
    -- 0.2.1: violet became gold (accent and ground line, if still on the violet default)
    if W.sv.uiVersion < 4 then
        local function IsViolet(c) return math.abs(c.r - 0.64) < 0.01 and math.abs(c.g - 0.55) < 0.01 and math.abs(c.b - 0.98) < 0.01 end
        if IsViolet(W.sv.theme) then W.sv.theme = { r = 0.85, g = 0.70, b = 0.40 } end
        if IsViolet(W.sv.path.color) then W.sv.path.color = { r = 0.85, g = 0.70, b = 0.40 } end
        W.sv.uiVersion = 4
    end
    -- 0.3.0: the chevron line (L3) is the new standard look
    if W.sv.uiVersion < 5 then
        if W.sv.path.style == "line" then W.sv.path.style = "chevrons" end
        W.sv.uiVersion = 5
    end
    -- 0.3.3: the see-through haze came out as a black box: text + gold lines instead
    if W.sv.uiVersion < 6 then
        if W.sv.label.bg == "soft" then W.sv.label.bg = "lines" end
        W.sv.uiVersion = 6
    end
    -- 0.6.0: frameless tracker with the quest trail is the new standard look
    if W.sv.uiVersion < 7 then
        W.sv.tracker.panelStyle = "trail"
        W.sv.tracker.bgAlpha = 0.5
        W.sv.uiVersion = 7
    end
    -- 0.6.2: ground arrows blended into bright ground: brighter and a bit bigger (if still on the old defaults)
    if W.sv.uiVersion < 8 then
        local p = W.sv.path
        if math.abs(p.alpha - 0.55) < 0.01 then p.alpha = 0.9 end
        if math.abs(p.width - 0.16) < 0.01 then p.width = 0.2 end
        W.sv.uiVersion = 8
    end
    -- 0.7.1: the light pillar was too distracting: off (can be turned on again in the settings)
    if W.sv.uiVersion < 9 then
        W.sv.path.pillar = false
        W.sv.uiVersion = 9
    end
    -- 0.10.0: new look picked from sketches: tracker "A ledger", arrow + text "3 compact pill";
    -- six tabs need a bit more width
    if W.sv.uiVersion < 10 then
        local t = W.sv.tracker
        t.panelStyle = "ledger"
        t.bgAlpha = 0.8
        if t.width < 320 then t.width = 320 end
        W.sv.arrow.style = "compact"
        W.sv.arrow.quiet = true
        W.sv.uiVersion = 10
    end
    -- 0.13.0: solid chevrons on the ground (picked from sketches) replace the dotted ones
    if W.sv.uiVersion < 11 then
        if W.sv.path.style == "chevrons" then W.sv.path.style = "solid" end
        W.sv.uiVersion = 11
    end
    -- 0.13.1: the objective name no longer fades out of the arrow text
    if W.sv.uiVersion < 12 then
        W.sv.arrow.quiet = false
        W.sv.uiVersion = 12
    end
    -- 1.0.0: hiding Advanced UI's quest tracker became the standard (was opt-in)
    if W.sv.uiVersion < 13 then
        W.sv.hideAuiTracker = true
        W.sv.uiVersion = 13
    end
    -- 1.0.1: the "nudge when close" animation was removed (it looked like shaking): drop its setting
    if W.sv.uiVersion < 14 then
        W.sv.arrow.fx.nudge = nil
        W.sv.uiVersion = 14
    end
    W.ApplyTheme()
    -- (development: the screen size in UI units, to turn a hand-placed layout into
    -- resolution-independent standard positions)
    W.sv.lastGui = { w = GuiRoot:GetWidth(), h = GuiRoot:GetHeight() }

    W.Nav.Init()
    W.Arrow.Init()
    W.Path.Init()
    W.Beacon.Init()
    W.Minimap.Init()
    W.Reticle.Init()
    W.Dungeon.Init()
    W.Tracker.Init()
    W.Teleport.Init()
    W.Banner.Init()
    W.Launcher.Init()
    W.InitSettings()

    -- ask for the images now, check a few seconds after logging in
    for _, file in ipairs(W.NEW_TEXTURES) do W.TextureLoaded(file) end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Tex", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Tex", EVENT_PLAYER_ACTIVATED)
        zo_callLater(CheckTextures, 5000)
    end)

    -- /questbound always; the short /qb unless another addon already uses it
    SLASH_COMMANDS["/questbound"] = Slash
    if not SLASH_COMMANDS["/qb"] then SLASH_COMMANDS["/qb"] = Slash end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
