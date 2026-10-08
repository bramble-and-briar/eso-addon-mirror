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

W.VERSION = "1.1.0"   -- (bump together with "## Version" / "## AddOnVersion" in Questbound.txt)
W.TEX = "Questbound/Textures/"

-- Colors are plain { r, g, b } tables (0..1): ZO_ColorDef came out white in 0.2.0.
local function Hex(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end

-- The UI colors. Everything that follows the color theme (W.ApplyTheme) is changed IN PLACE,
-- so every part holding one of these tables picks up a new theme. The values here are the
-- standard "Questbound gold" theme (THEMES[1] copies them exactly).
W.COLOR = {
    theme = Hex("D9B366"),     -- accent: titles, highlights, the arrow (ESO gold)
    text = Hex("E6E2D6"),
    dim = Hex("8E8C86"),
    done = Hex("7DB87D"),
    warn = Hex("E0603C"),      -- arrow when the objective is behind you
    optional = Hex("8FB0C4"),
    story = Hex("B9A2E6"),     -- main story quests
    gold = Hex("A8915E"),      -- dividers and frame lines
    quest = Hex("C5C29E"),     -- the game's normal text color
    panel = { r = 0.05, g = 0.045, b = 0.035 },    -- window backgrounds
    card = { r = 0.165, g = 0.133, b = 0.082 },    -- the followed quest's card
    coin = { r = 0.08, g = 0.065, b = 0.045 },     -- dark disc behind the header buttons
    hole = { r = 0.07, g = 0.06, b = 0.045 },      -- open stops on the tracker's trail
    disc = { r = 0.10, g = 0.08, b = 0.06 },       -- dark disc of the logo and the arrow badge
    ink = { r = 0.12, g = 0.09, b = 0.05 },        -- dark marks on gold (badge needle, check)
    header = { r = 0.80, g = 0.77, b = 0.68 },     -- tabs and the quest count
    hover = { r = 1, g = 0.93, b = 0.75 },         -- a tab under the mouse
    shade = { r = 0, g = 0, b = 0 },               -- the launcher button's background
    bright = { r = 1, g = 1, b = 1 },              -- the followed quest's name (card)
    cream = { r = 0.98, g = 0.93, b = 0.80 },      -- the followed quest's name (trail look)
}

-- ---------------------------------------------------------------------------
-- Color themes (settings "Colors"). A theme gives three colors: accent, background and
-- frame lines; all text colors are worked out from the background so they always stay
-- readable (contrast like the web's WCAG rules: text 7:1, labels 3.5:1, accent 3.2:1).
-- "custom" = the player's own three colors (sv.theme, sv.customPanel, sv.customFrame).

W.THEMES = {
    { id = "default",   accent = "D9B366", panel = "0D0B09", frame = "A8915E", exact = true },
    { id = "aldmeri",   accent = "E8C547", panel = "0E0D07", frame = "B39A3A" },
    { id = "daggerfall",accent = "5B9BE0", panel = "080B12", frame = "4A6FA0" },
    { id = "ebonheart", accent = "D9534A", panel = "120808", frame = "9E4038" },
    { id = "silver",    accent = "C9CED6", panel = "0B0C0E", frame = "8A9099" },
    { id = "obsidian",  accent = "F0F0F0", panel = "050505", frame = "707070" },
    { id = "bronze",    accent = "C08A4E", panel = "0F0B07", frame = "8C6A42" },
    { id = "copper",    accent = "D97A4A", panel = "110A07", frame = "9C5A3A" },
    { id = "amber",     accent = "F0A030", panel = "100B04", frame = "B07A2C" },
    { id = "ember",     accent = "FF7A3D", panel = "120805", frame = "B85A30" },
    { id = "sunset",    accent = "FF9E5E", panel = "120A08", frame = "B87050" },
    { id = "crimson",   accent = "D23C46", panel = "100607", frame = "8E2A30" },
    { id = "ruby",      accent = "E0445E", panel = "11070A", frame = "A03A4C" },
    { id = "rose",      accent = "E88AA8", panel = "120A0D", frame = "A86A80" },
    { id = "daedric",   accent = "D452C8", panel = "10070F", frame = "9A4592" },
    { id = "amethyst",  accent = "A98BE0", panel = "0C0912", frame = "7A68A3" },
    { id = "violet",    accent = "8A6CF0", panel = "0A0814", frame = "6656B0" },
    { id = "midnight",  accent = "7FA7FF", panel = "04060C", frame = "3A4A70" },
    { id = "sapphire",  accent = "4A7DF0", panel = "070A14", frame = "3E5EAE" },
    { id = "ice",       accent = "9ED8F0", panel = "080D10", frame = "6F9BB0" },
    { id = "teal",      accent = "4FC3C8", panel = "061010", frame = "3E8E92" },
    { id = "psijic",    accent = "6FD6B0", panel = "07100E", frame = "4F9A80" },
    { id = "jade",      accent = "4CC48C", panel = "06100B", frame = "3C8E68" },
    { id = "emerald",   accent = "3DBE5A", panel = "061007", frame = "3A8A48" },
    { id = "forest",    accent = "8BB05A", panel = "0A0D07", frame = "667F45" },
    { id = "olive",     accent = "B5B05A", panel = "0D0C07", frame = "85814A" },
    { id = "dwemer",    accent = "D4A04A", panel = "0B0E10", frame = "8C7244" },
    { id = "slate",     accent = "9AA6B2", panel = "0D0F12", frame = "6B7682" },
    -- (light themes "parchment" / "ivory" were tried and removed: the game's own icons are
    -- white and nearly vanish on a light background)
}
W.THEME_BY_ID = {}
for _, t in ipairs(W.THEMES) do W.THEME_BY_ID[t.id] = t end
W.Hex = Hex

local WHITE, BLACK = { r = 1, g = 1, b = 1 }, { r = 0, g = 0, b = 0 }
local MAX_PANEL_LUM = 0.06   -- brightest background allowed (about a dark grey 45 45 45)

local function Mix(a, b, t)
    return { r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, b = a.b + (b.b - a.b) * t }
end

-- relative luminance and contrast ratio (WCAG formulas)
local function Lin(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
function W.Luminance(c) return 0.2126 * Lin(c.r) + 0.7152 * Lin(c.g) + 0.0722 * Lin(c.b) end
function W.Contrast(a, b)
    local la, lb = W.Luminance(a), W.Luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

-- c pushed toward white (dark background) or black (light background) until it reads
local function Readable(c, bg, minRatio, dark)
    local target = dark and WHITE or BLACK
    for _ = 1, 25 do
        if W.Contrast(c, bg) >= minRatio then break end
        c = Mix(c, target, 0.1)
    end
    return c
end

-- the three colors of the chosen theme (raw, before the readability fixes)
function W.ThemeColors()
    local sv = W.sv
    if sv.colorTheme == "custom" then
        return sv.theme, sv.customPanel, sv.customFrame
    end
    local t = W.THEME_BY_ID[sv.colorTheme] or W.THEMES[1]
    return Hex(t.accent), Hex(t.panel), Hex(t.frame)
end

-- control:SetColor(W.RGBA(color[, alpha]))
function W.RGBA(c, a)
    return c.r, c.g, c.b, a or 1
end

-- "|cRRGGBBtext|r"
function W.Colorize(c, text)
    return string.format("|c%02X%02X%02X%s|r", zo_round(c.r * 255), zo_round(c.g * 255), zo_round(c.b * 255), text)
end

-- The state word in a button's tooltip ("on" / "off", "locked" / "unlocked"), highlighted:
-- green when the thing is on, red when it's off. key = the word's text key.
local STATE_ON = { r = 0.45, g = 0.85, b = 0.45 }
local STATE_OFF = { r = 0.93, g = 0.40, b = 0.33 }
function W.State(isOn, key)
    return W.Colorize(isOn and STATE_ON or STATE_OFF, L(key))
end

-- Lettering. "eso": Trajan headings (the game's logo / zone title letters) and
-- Prose Antique quest names (books, quest journal), clear text for objectives.
W.FONT_STYLES = {
    eso = { title = "$(STONE_TABLET_FONT)", quest = "$(ANTIQUE_FONT)", text = "$(MEDIUM_FONT)" },
    book = { title = "$(ANTIQUE_FONT)", quest = "$(ANTIQUE_FONT)", text = "$(ANTIQUE_FONT)" },
    plain = { title = "$(BOLD_FONT)", quest = "$(BOLD_FONT)", text = "$(MEDIUM_FONT)" },
}

-- kind: "title", "quest" or "text". Prose Antique runs small, so it gets +2.
-- Sharp lettering: the thick soft shadow is a blur that smears into thin strokes at small
-- sizes (Trajan tabs looked fuzzy); the hard 1 px shadow tried next looked grainy. Now text
-- up to 17 gets the thin soft shadow (smooth edges, no smear), only big titles the thick one,
-- and nothing is drawn below MIN_FONT (Trajan at 11 px broke up into pixels).
local MIN_FONT = 12
-- free = true: no minimum (tabs shrinking to fit, the arrow text's own size slider)
function W.Font(kind, size, free)
    local style = W.FONT_STYLES[W.sv.fontStyle] or W.FONT_STYLES.eso
    local face = style[kind] or style.text
    if face == "$(ANTIQUE_FONT)" then size = size + 2 end
    size = zo_round(size)
    if not free then size = math.max(MIN_FONT, size) end
    local effect = size <= 17 and "soft-shadow-thin" or "soft-shadow-thick"
    return face .. "|" .. size .. "|" .. effect
end

local defaults = {
    target = "auto",          -- "auto" (map marker first, else quest), "quest", "waypoint"
    hideGameTracker = true,
    banner = true,            -- "Objective complete / Next: ..." banner for the followed quest
    followNewQuest = true,    -- a newly accepted quest becomes the followed one
    hideAuiTracker = true,    -- hide Advanced UI's quest tracker while ours is shown (a one-time chat note says so)
    auiNoticeShown = false,   -- that note was shown (once per account, never again)
    fontStyle = "eso",        -- see W.FONT_STYLES
    theme = { r = 0.85, g = 0.70, b = 0.40 },   -- accent color of the "custom" theme (ESO gold)
    colorTheme = "default",   -- one of W.THEMES ids, or "custom" (sv.theme + customPanel + customFrame)
    customPanel = { r = 0.05, g = 0.045, b = 0.035 },
    customFrame = { r = 0.66, g = 0.57, b = 0.37 },
    anim = "full",           -- animations: "full", "subtle" or "off"
    npcMarker = true,         -- Skyrim-style marker + golden ring at the NPC to talk to
    killArea = true,          -- red hunting area + crossed swords for kill objectives
    killBadge = true,         -- red badge + count by the crosshair on quest monsters
    combatFade = true,        -- tracker and nameplate step back in combat
    units = "metric",         -- distances: "metric" (m / km) or "imperial" (ft / mi)
    minimap = true,           -- the way on AUI's minimap (when AUI is installed)
    skip = {                  -- "Skip dialogs", see Questbound_Skip.lua (button in the tracker header)
        on = false,
        accept = true,        -- accept quests you're offered
        turnIn = true,        -- hand in finished quests
        choices = true,       -- pick the best answer at decisions (off: they stay yours)
        red = false,          -- red (important) answers may be picked too (off: they stay yours)
        bestReward = true,    -- a reward picked in a conversation: the one that fits your gear
        hideWindow = true,    -- the dialog window is see-through while Questbound answers
        books = false,        -- close quest books / notes at once (opening already counts)
        readNotes = true,     -- "Read the note" steps: the item is used (read) for you
        onlySeen = false,     -- only skip dialogs read before (new story is shown)
        toChat = false,       -- also write what NPCs say to chat (off: only the story window keeps it)
        shiftPause = true,    -- hold Shift when you start talking: read that conversation
        close = true,         -- close the window when nothing new is left to say
        seen = {},            -- dialogs read before (for onlySeen)
        seenN = 0,
        types = {             -- which kinds of quests are skipped (false = read them yourself); all on
            main = true, zone = true, side = true, guild = true, daily = true,
            dungeon = true, companion = true, crafting = true, pvp = true, event = true,
        },
        story = {},           -- skipped conversations per quest (Questbound_Story.lua), newest first
        saved = 0,            -- seconds of dialog skipped so far (estimate, shown in the button's tooltip)
    },
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

-- The chosen color theme into W.COLOR (in place, so every part that holds a color table
-- picks it up). The standard theme uses the hand-picked colors as they always were;
-- other themes work their text colors out from the background.
local STANDARD = {}
for k, v in pairs(W.COLOR) do STANDARD[k] = { r = v.r, g = v.g, b = v.b } end
local FOLLOWS = { "theme", "text", "dim", "quest", "gold", "panel", "card", "coin", "hole", "disc", "ink", "header",
    "hover", "shade", "bright", "cream" }

local function Put(key, c)
    local dst = W.COLOR[key]
    dst.r, dst.g, dst.b = zo_clamp(c.r, 0, 1), zo_clamp(c.g, 0, 1), zo_clamp(c.b, 0, 1)
end

function W.ApplyTheme()
    local sv = W.sv
    local preset = W.THEME_BY_ID[sv.colorTheme]
    if sv.colorTheme ~= "custom" and (not preset or preset.exact) then
        for _, key in ipairs(FOLLOWS) do Put(key, STANDARD[key]) end
        return
    end
    local accent, panel, frame = W.ThemeColors()
    -- backgrounds stay dark: the game's own icons (teleport, map pin, rewards) are white and
    -- vanish on light colors. A too light custom background is darkened, keeping its hue.
    for _ = 1, 30 do
        if W.Luminance(panel) <= MAX_PANEL_LUM then break end
        panel = Mix(panel, BLACK, 0.1)
    end
    -- dark background = light text (always, with the cap above; kept for safety)
    local dark = W.Contrast(WHITE, panel) >= W.Contrast(BLACK, panel)
    local text = dark and STANDARD.text or { r = 0.11, g = 0.10, b = 0.09 }
    local toward = dark and BLACK or WHITE
    Put("panel", panel)
    Put("text", Readable(text, panel, 7, dark))
    Put("quest", Readable(Mix(text, accent, 0.25), panel, 7, dark))
    Put("header", Readable(Mix(text, panel, 0.15), panel, 7, dark))
    Put("dim", Readable(Mix(text, panel, 0.45), panel, 3.5, dark))
    Put("hover", dark and Mix(text, WHITE, 0.6) or Mix(text, BLACK, 0.5))
    Put("theme", Readable(accent, panel, 3.2, dark))
    Put("gold", Readable(frame, panel, 1.6, dark))
    Put("card", Mix(panel, accent, dark and 0.13 or 0.16))
    Put("coin", Mix(panel, accent, dark and 0.035 or 0.08))
    Put("hole", Mix(panel, accent, dark and 0.025 or 0.06))
    Put("disc", dark and Mix(panel, accent, 0.06) or Mix(panel, toward, 0.0))
    Put("ink", dark and Mix(panel, accent, 0.08) or Mix(text, accent, 0.2))
    Put("shade", dark and Mix(panel, BLACK, 0.5) or panel)
    Put("bright", Readable(dark and WHITE or BLACK, W.COLOR.card, 7, dark))
    Put("cream", Readable(Mix(dark and WHITE or BLACK, accent, 0.15), panel, 7, dark))
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
    "lock_body.dds", "lock_shackle.dds", "diamond.dds", "skip.dds",
    -- crisp 32 px copies for the header buttons and logo (make_ui_icons.ps1)
    "rim_ui.dds", "disc_ui.dds", "dot_ui.dds", "search_ui.dds", "skip_ui.dds", "chevron_ui.dds",
    "lock_body_ui.dds", "lock_shackle_ui.dds", "arrow_ui.dds", "logo_fill_ui.dds", "logo_gold_ui.dds",
    "diamond_ui.dds", "compass_ui.dds", "check_ui.dds",
    -- 16 px copies for the tiny tracker row marks
    "arrow_sm.dds", "dot_sm.dds", "check_sm.dds" }

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

-- Small UI pictures: the crisp 32x32 copy "<name>_ui.dds" (_QuestboundDev/make_ui_icons.ps1),
-- or for marks drawn at 16 px or less (size given) the 16x16 "<name>_sm.dds"; once loaded,
-- else the original.
function W.UI(file, size)
    if size and size <= 16 then
        local tiny = string.gsub(file, "%.dds$", "_sm.dds")
        if W.TextureLoaded(tiny) then return W.TEX .. tiny end
    end
    local small = string.gsub(file, "%.dds$", "_ui.dds")
    return W.TEX .. (W.TextureLoaded(small) and small or file)
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
    { section = "path", name = "NAME_PATH", cmd = "/qb nav" },
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
    W.sv.skip.storyPos = nil                      -- story window back in the middle,
    W.sv.skip.storySize = nil                     -- at its standard size
    if W.Story then W.Story.Place() end
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
    elseif args == "nav" or args == "gps" or args == "line" or args == "path" then
        W.TogglePath()
    elseif args == "skip" then
        W.Skip.Toggle()
    elseif args == "story" then
        W.Story.Open()
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
ZO_CreateStringId("SI_BINDING_NAME_QUESTBOUND_SKIP", L("BIND_SKIP"))

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    W.sv = ZO_SavedVars:NewAccountWide("Questbound_SV", 1, nil, defaults)
    -- A fresh install (no uiVersion saved yet) already has today's defaults: none of the
    -- upgrade steps below may touch it. (Only the developer's data from before the
    -- release ever needed them.) Raise UI_VERSION with every new step.
    local UI_VERSION = 19
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
    -- Skip dialogs: picking the best answer at choices became the standard
    if W.sv.uiVersion < 15 then
        W.sv.skip.choices = true
        W.sv.uiVersion = 15
    end
    -- Skip dialogs: red (important) answers stay the player's by default
    if W.sv.uiVersion < 16 then
        W.sv.skip.red = false
        W.sv.uiVersion = 16
    end
    -- Skip dialogs: skipped lines no longer fill the chat (the story window keeps them)
    if W.sv.uiVersion < 17 then
        W.sv.skip.toChat = false
        W.sv.uiVersion = 17
    end
    -- color themes: an accent changed before keeps working as the "custom" theme
    if W.sv.uiVersion < 18 then
        local c = W.sv.theme
        if math.abs(c.r - 0.85) > 0.01 or math.abs(c.g - 0.70) > 0.01 or math.abs(c.b - 0.40) > 0.01 then
            W.sv.colorTheme = "custom"
        end
        W.sv.uiVersion = 18
    end
    -- the light themes were removed: back to the standard colors
    if W.sv.uiVersion < 19 then
        if W.sv.colorTheme == "parchment" or W.sv.colorTheme == "ivory" then W.sv.colorTheme = "default" end
        W.sv.uiVersion = 19
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
    W.Skip.Init()
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
