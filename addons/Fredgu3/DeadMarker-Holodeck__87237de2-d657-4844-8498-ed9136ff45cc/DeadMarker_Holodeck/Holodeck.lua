--=====================================================================
-- Holodeck.lua — v0.0.29
--
-- Versioning (DM2 suite): human Version = M.m.p
--   AddOnVersion (manifest) = major*10000 + minor*100 + patch
--   0.0.27 → 27
--
-- Local budget: this file's main chunk shares Lua 5.1's 200-local cap.
-- Count: python .../eso-lua-qa/scripts/local_count_scan.py Holodeck.lua
-- New trial recipes belong in a sibling manifest .lua (new 200), not more
-- `local function` here. Fold tunables into CFG / TEX, not new locals.
--
-- 0.0.59: Library playback is baked meters (no second fit). Scale readout matches the legend. Cyan ring is the boss walk.
-- 0.0.58: vSS Yol (STACK/RIM/BURN IRON) + Lok (TOMB/BLOCK/KILL STORM); HP freeze on fly
-- 0.0.57: Nav QA — park landed boss, LAND!, portal after hide, plant facing, no BASH upstairs
-- 0.0.56: Recipes.lua parse fix (while/then) — 0.0.55 did not load
-- 0.0.55: /hd help card on the legend (scale / rot / flip)
-- 0.0.54: vSS recipe, add looks, legend, /hd help card (scale rot flip)
-- 0.0.53: YOU/add-debuff headmarker uses raw body pos (DeadMarker2), not house-fit local
-- 0.0.52: Boss-only tag = you only + debuff shout; Rakkhat house-fit from boss path
-- 0.0.51: Count boss-only Portal!/pads/tags; Rakkhat Backyard!; time HP bars
-- 0.0.50: Two tag marks per side (lusterbeam)
-- 0.0.49: Portal pads + glow from hops; DPS tag marks; smaller Portal! banner
-- 0.0.48: Portal! from pack hops (not a generic timer); NPC pack has no cue
-- 0.0.47: SWAP! banner on vLC annihilation windows (held ~12s)
-- 0.0.46: Fix vLC pack labels (broken quotes on Blackguard/Lightweaver)
-- 0.0.45: Player facing vs NPC; vLC LTs as mini; Count/Zily tint by name
-- 0.0.44: Facing cones were 180° off (dashes hid it); flashlight +π
-- 0.0.43: Frame dots + filled dashes; flashlight facing; library # separator
-- 0.0.42: Group-test freeze — simplified packs, vLC Count, HUD/frame/facing
-- 0.0.41: Thicker frame dashes; boss facing from movement
-- 0.0.40: Fight frame (center plant, ring, cardinals, split, 30s boss path)
-- 0.0.39: Operator HUD (side legend + library); /hd play; compact on clear
-- 0.0.38: Compact pack tracks until /hd load; recycle pins; idle tick
-- 0.0.37: /hd flip x|z (mirror pack; wrong-way orbits)
-- 0.0.36: MOL-Rakkhat library pack (real fight 35)
-- 0.0.35: Default boss gold (not dead-red); mem meter PC vs console thresholds
-- 0.0.34: Lua mem readout (lower left) during playback
-- 0.0.33: Early first-key (<1s) present at t=0; bosses stay visible when dead
-- 0.0.32: Playback sample has no per-tick alloc (player-pack OOM)
-- 0.0.31: /hd scale N percent (house playback size)
-- 0.0.30: Library picker panel (was saves list)
-- 0.0.29: World-space nameplates; hide until spawn; drop record/save from slash
-- 0.0.28: Boss/mini nameplates + per-entity tint (Twins gold/blue)
-- 0.0.27: Dead-player tint (red) on playback; death flags in packs
-- 0.0.26: Pack metadata + player aspect tint (lunar/shadow) on playback
-- 0.0.25: Boss/elite multi-keyframe paths — map-relative NPC pos when Raw freezes
-- 0.0.24: House-fit at trial scale (~50m, 22m ring) not 6m living-room
-- 0.0.23: House-fit open (pins were ~900m away); record origin = player in-zone
-- 0.0.22: Flat SV save format + hard open/play pin placement
-- 0.0.21: Fix faint/empty role+spot textures; open always re-centers + delayed pin place
-- 0.0.20: Full SPACE_WORLD texture pack (DXT5) for all kinds + path gfx
-- 0.0.8: Stock ESO textures; snap playback flag
--
-- plant = coordinate ZERO (room anchor), NOT automatic boss spawn.
-- Slash = actions; /hdsettings = preferences.
--=====================================================================

local Holodeck = Holodeck or {}
Holodeck.name        = "DeadMarker_Holodeck"
Holodeck.displayName = "Holodeck"
Holodeck.version     = "0.0.59"

Holodeck.Fights = Holodeck.Fights or {}
function Holodeck.RegisterFight(fight)
    if type(fight) == "table" and fight.id then
        Holodeck.Fights[fight.id] = fight
    end
end

-- ============================= Textures / kinds ========================
-- SPACE_WORLD: pack DXT5 256² with mips (same format as DM2 roles ~87KB).
-- Prefer pack; stock ESO = fallback only. No DeadMarker2 install dependency.
-- Leading slash required (same as DeadMarker2) or some clients fail to resolve pack DDS.
-- One table each for paths + tunables so they do not eat the 200-local chunk budget.
local PACK = "/DeadMarker_Holodeck/textures/"
local function PackTex(name) return PACK .. name end
local TEX = {
    FALLBACK   = "/esoui/art/icons/poi/poi_areaofinterest_complete.dds",
    BOSS_ESO   = "/esoui/art/icons/poi/poi_groupboss_complete.dds",
    MINI_ESO   = "/esoui/art/icons/poi/poi_groupinstance_complete.dds",
    TRASH_ESO  = "/esoui/art/icons/poi/poi_delve_complete.dds",
    STACK_ESO  = "/esoui/art/icons/poi/poi_areaofinterest_complete.dds",
    SOAK_ESO   = "/esoui/art/icons/poi/poi_publicdungeon_complete.dds",
    SAFE_ESO   = "/esoui/art/icons/poi/poi_wayshrine_complete.dds",
    PORTAL_ESO = "/esoui/art/icons/poi/poi_portal_complete.dds",
    ORIGIN_ESO = "/esoui/art/icons/mapkey/mapkey_wayshrine.dds",
    RING_ESO   = "/esoui/art/icons/poi/poi_areaofinterest_incomplete.dds",
    DOT_ESO    = "/esoui/art/buttons/radiobuttonup.dds",
    TANK_ESO   = "/esoui/art/icons/poi/poi_groupboss_complete.dds",
    HEALER_ESO = "/esoui/art/icons/poi/poi_wayshrine_complete.dds",
    DPS_ESO    = "/esoui/art/icons/quest_book_001.dds",
    BOSS   = PackTex("hd_boss.dds"),
    MINI   = PackTex("hd_mini.dds"),
    TRASH  = PackTex("hd_trash.dds"),
    STACK  = PackTex("hd_stack.dds"),
    SOAK   = PackTex("hd_soak.dds"),
    SAFE   = PackTex("hd_safe.dds"),
    PORTAL = PackTex("hd_portal.dds"),
    ORIGIN = PackTex("hd_origin.dds"),
    RING   = PackTex("hd_ring.dds"),
    DOT    = PackTex("hd_dot.dds"),
    DASH   = PackTex("hd_dash.dds"),
    FACE   = PackTex("hd_face.dds"),
    TANK   = PackTex("hd_tank.dds"),
    HEALER = PackTex("hd_healer.dds"),
    DPS    = PackTex("hd_dps.dds"),
}
local CFG = {
    ORIGIN_PIN_LOCAL_X = -1.5,
    ORIGIN_PIN_LOCAL_Z = -1.5,
    MIN_TRAVEL_SEC = 0.35,
    PATH_SPEED_M_S = 5.0,
    PATH_Y_M = 0.12,
    PATH_DOT_SPACING = 1.1,
    SNAP_TRAVEL_EPS = 0.05,
    FRAME_LOOKAHEAD_SEC = 30,
    FRAME_RING_DOTS = 28,
    PORTAL_HOLD_SEC = 12,
    SHEET_ROWS = 12,
    HOUSE_OK_DIAMETER_M = 70,
    HOUSE_TARGET_DIAMETER_M = 50,
    HOUSE_ENTITY_PATH_MAX_M = 40,
    HOUSE_RING_RADIUS_M = 22,
    LIBS_PER_PAGE = 12,
    TRIAL_INDEX_AT = 12,
}

-- Public kind set for markers / fight packs / future team roles.
-- group: enemy | role | spot | system
-- texture = preferred path; fallback = ESO stock if preferred fails
local KIND = {
    -- Enemies (recording + packs)
    boss = {
        label = "Boss", group = "enemy",
        texture = TEX.BOSS, fallback = TEX.BOSS_ESO,
        sizeM = 1.8, color = { 1.00, 0.78, 0.18 }, yOffM = 2.2,
    },
    mini = {
        label = "Mini / LT", group = "enemy",
        texture = TEX.MINI, fallback = TEX.MINI_ESO,
        sizeM = 1.45, color = { 1.00, 0.55, 0.12 }, yOffM = 2.0,
    },
    trash = {
        label = "Trash / add", group = "enemy",
        texture = TEX.TRASH, fallback = TEX.TRASH_ESO,
        sizeM = 1.15, color = { 0.75, 0.55, 0.35 }, yOffM = 1.6,
    },
    -- Roles (shipped copies of DM2-style icons — no DM2 install required)
    tank = {
        label = "Tank", group = "role",
        texture = TEX.TANK, fallback = TEX.TANK_ESO,
        sizeM = 1.25, color = { 0.35, 0.55, 1.00 }, yOffM = 1.9,
    },
    healer = {
        label = "Healer", group = "role",
        texture = TEX.HEALER, fallback = TEX.HEALER_ESO,
        sizeM = 1.20, color = { 0.35, 0.95, 0.45 }, yOffM = 1.85,
    },
    dps = {
        label = "DPS", group = "role",
        texture = TEX.DPS, fallback = TEX.DPS_ESO,
        sizeM = 1.15, color = { 0.95, 0.35, 0.55 }, yOffM = 1.8,
    },
    -- Spots (author drops for team walkthrough)
    stack = {
        label = "Stack", group = "spot",
        texture = TEX.STACK, fallback = TEX.STACK_ESO,
        sizeM = 1.15, color = { 0.40, 0.85, 1.00 }, yOffM = 1.4,
    },
    soak = {
        label = "Soak", group = "spot",
        texture = TEX.SOAK, fallback = TEX.SOAK_ESO,
        sizeM = 1.20, color = { 0.85, 0.35, 0.95 }, yOffM = 1.45,
    },
    safe = {
        label = "Safe / out", group = "spot",
        texture = TEX.SAFE, fallback = TEX.SAFE_ESO,
        sizeM = 1.10, color = { 0.55, 1.00, 0.70 }, yOffM = 1.35,
    },
    portal = {
        label = "Portal / door", group = "spot",
        texture = TEX.PORTAL, fallback = TEX.PORTAL_ESO,
        sizeM = 1.25, color = { 0.70, 0.50, 1.00 }, yOffM = 1.55,
    },
    mirror = {
        label = "Mirror", group = "spot",
        texture = TEX.STACK, fallback = TEX.STACK_ESO,
        sizeM = 1.15, color = { 0.78, 0.90, 1.00 }, yOffM = 1.50,
    },
    -- System
    origin = {
        label = "Origin (plant)", group = "system",
        texture = TEX.ORIGIN, fallback = TEX.ORIGIN_ESO,
        sizeM = 0.95, color = { 1.0, 1.0, 0.35 }, yOffM = 0.9,
    },
}
-- Alias only (not listed separately in palette UI)
KIND.miniboss = KIND.mini

-- Twins / marked-player colors (Lunar Aspect = light, Shadow Aspect = dark)
local ASPECT_COLOR = {
    lunar  = { 1.00, 0.92, 0.38 },
    light  = { 1.00, 0.92, 0.38 },
    holy   = { 1.00, 0.92, 0.38 },
    shadow = { 0.28, 0.32, 0.92 },
    dark   = { 0.28, 0.32, 0.92 },
}

local function NormalizeAspect(a)
    if type(a) ~= "string" then return nil end
    a = string.lower(a)
    if a == "" or a == "none" then return nil end
    if a == "light" or a == "holy" then return "lunar" end
    if a == "dark" then return "shadow" end
    if ASPECT_COLOR[a] then return a end
    return nil
end

local DEAD_COLOR = { 0.92, 0.12, 0.10 }

-- Extra dual-boss shades when the pack has no tint and the name is not lunar/shadow.
local BOSS_PALETTE = {
    { 1.00, 0.92, 0.38 },
    { 0.28, 0.32, 0.92 },
    { 0.25, 0.85, 0.55 },
    { 0.95, 0.45, 0.18 },
}

local function InferTintFromName(s)
    if type(s) ~= "string" or s == "" then return nil end
    s = string.lower(s)
    if s:find("vashai", 1, true) or s:find("will of", 1, true) or s:find("zilyesset", 1, true)
        or s:find("lunar", 1, true) then
        return "lunar"
    end
    if s:find("kinrai", 1, true) or s:find("rage of", 1, true) or s:find("ryelaz", 1, true)
        or s:find("shadow", 1, true) then
        return "shadow"
    end
    return nil
end

local function ParseColorTable(c)
    if type(c) ~= "table" then return nil end
    local r, g, b = tonumber(c[1] or c.r), tonumber(c[2] or c.g), tonumber(c[3] or c.b)
    if not r or not g or not b then return nil end
    return { r, g, b }
end

--- Unique-name tint wins (Vashai/Zilyesset lunar, Kinrai/Ryelaz shadow), else pack tint.
local function ResolveEntityColor(def)
    if type(def) ~= "table" then return nil end
    local named = InferTintFromName(def.label) or InferTintFromName(def.id)
    if named and ASPECT_COLOR[named] then return ASPECT_COLOR[named] end
    local t = NormalizeAspect(def.tint)
    if t and ASPECT_COLOR[t] then return ASPECT_COLOR[t] end
    return ParseColorTable(def.color)
end

local function ColorForActor(act)
    if act and act.dead then return DEAD_COLOR end
    local asp = act and NormalizeAspect(act.aspect)
    if asp and ASPECT_COLOR[asp] then return ASPECT_COLOR[asp] end
    if act and act.baseColor then return act.baseColor end
    local def = KIND[act and act.kind] or KIND.stack
    return def.color or { 1, 1, 1 }
end

function Holodeck.NamesMode()
    local s = Holodeck.savedVars
    if type(s) == "table" and type(s.namesMode) == "string" and s.namesMode ~= "" then
        return s.namesMode
    end
    if s and s.namesOn == false then return "off" end
    return "important"
end

local function NamesOn()
    return Holodeck.NamesMode() ~= "off"
end

local function ShouldNameplate(act)
    if not act then return false end
    local mode = Holodeck.NamesMode()
    if act.visible == false then return false end
    local lab = act.label
    if type(lab) ~= "string" or lab == "" or lab == "origin" then return false end
    if act.name == "_you" then return act.tagged == true end
    if mode == "off" then return false end
    if act.guide then
        -- Pad numbers during portal; compass mirror pins; statue S1–S4 stay quiet.
        return act.kind == "portal" or act.kind == "mirror"
    end
    local k = act.kind
    if mode == "all" then
        return k == "boss" or k == "mini" or k == "trash"
            or k == "tank" or k == "healer" or k == "dps"
    end
    if k == "boss" or k == "mini" then return true end
    return act.important == true
end

-- Exact-name → kind (before substring heuristics)
local NAME_TYPE = {
    boss = "boss", lieutenant = "mini", lt = "mini", mini = "mini", miniboss = "mini",
    trash = "trash", add = "trash", adds = "trash",
    tank = "tank", mt = "tank", ot = "tank", tank1 = "tank", tank2 = "tank",
    healer = "healer", heal = "healer", heals = "healer", h1 = "healer", h2 = "healer",
    dps = "dps", dd = "dps", dps1 = "dps",
    stack = "stack", stack_main = "stack", main_stack = "stack",
    soak = "soak", safe = "safe", out = "safe", portal = "portal", door = "portal",
    mirror = "mirror",
    origin = "origin",
}

local KIND_ORDER = {
    "boss", "mini", "trash",
    "tank", "healer", "dps",
    "stack", "soak", "safe", "portal", "mirror",
    "origin",
}

local function NormalizeKind(typ)
    if not typ then return nil end
    typ = string.lower(tostring(typ))
    if typ == "miniboss" or typ == "lt" or typ == "lieutenant" then return "mini" end
    if typ == "heal" or typ == "heals" then return "healer" end
    if typ == "mt" or typ == "ot" or typ == "tanks" then return "tank" end
    if typ == "dd" or typ == "dps_player" then return "dps" end
    if typ == "add" or typ == "adds" or typ == "mob" then return "trash" end
    if typ == "out" or typ == "kited" then return "safe" end
    if typ == "door" or typ == "gate" then return "portal" end
    if KIND[typ] then return typ end
    return nil
end

-- Map LFG / DM2 role labels → Holodeck kind (team capture / demo later)
local function RoleToKind(role)
    if type(role) == "number" then
        if type(LFG_ROLE_TANK) == "number" and role == LFG_ROLE_TANK then return "tank" end
        if type(LFG_ROLE_HEAL) == "number" and role == LFG_ROLE_HEAL then return "healer" end
        if type(LFG_ROLE_DPS) == "number" and role == LFG_ROLE_DPS then return "dps" end
        return "dps"
    end
    local r = string.lower(tostring(role or "dps"))
    if r == "heal" or r == "healer" then return "healer" end
    if r == "tank" then return "tank" end
    return "dps"
end
Holodeck.RoleToKind = RoleToKind
Holodeck.NormalizeKind = NormalizeKind
Holodeck.KIND = KIND
Holodeck.KIND_ORDER = KIND_ORDER

local DEFAULTS = {
    bossSizeM = 1.6, minibossSizeM = 1.25, originSizeM = 0.7, roleSizeM = 1.1,
    yOffsetM = 1.8, opacity = 1.0, debug = false,
    legendOn = true, sheetOn = false, pathOn = true, frameOn = true, namesOn = true,
    namesMode = "important",
    alertsOn = true,
    playScalePct = 100,
    flipXByPack = {},
    flipZByPack = {},
    playMode = "once", -- once (park at end) | loop (power)
    saves = {},        -- name -> fight table
    lastExport = nil,
    sheetX = 40, sheetY = 120,
    listX = nil, listY = nil,
    -- Recorder policy (LAM)
    autoArmInInstances = true,
    recordStartMode = "boss",  -- manual | combat | boss
    recordAutoStop = true,
    recordAutoSave = false,
    recordIntervalMs = 400,
    -- What to sample (training default: bosses only — team walks themselves in house)
    recordCaptureBosses = true,
    recordCaptureSelf = false,
    recordCaptureTeam = false,
    recordCaptureElites = true,   -- reticle Hard/Deadly
    recordEliteTier = 4,          -- 0 off .. 4 any hostile on reticle
    recordRequirePlant = false,
    shareReceiveEnabled = true,
    lastSaveName = nil,
}

-- ============================= State ====================================
Holodeck.savedVars = nil
Holodeck.hudTop = nil
Holodeck.fragment = nil
Holodeck.idseq = 0
Holodeck.wsPins = {}
Holodeck.actors = {}      -- name -> actor pin
Holodeck.ctlPool = {}     -- recycled SPACE_WORLD textures
Holodeck.platePool = {}   -- recycled nameplates
Holodeck.pathGfx = {}     -- list of ring/line controls
Holodeck.origin = nil
Holodeck.fight = nil
Holodeck.fightSource = nil  -- "sandbox" | "save" | "library"
Holodeck.loadedId = nil
Holodeck.workingName = "sandbox" -- display: sandbox or save name
Holodeck.playing = false
Holodeck.playFinished = false   -- once mode ended at last pose
Holodeck.playT = 0
Holodeck.playMode = "once"
Holodeck._lastTickMs = nil
Holodeck._lastPhaseAnnounced = nil
Holodeck._lastCueAnnounced = nil
Holodeck._tickName = "Holodeck_PinTick"
Holodeck._tickMs = 50
Holodeck._tickRunning = false

-- Author workspace
Holodeck.editName = "boss"
Holodeck.clock = 0
Holodeck._lastStopAddMs = nil
Holodeck.stops = {}  -- name -> array of { t, x, z, hold, visible }
Holodeck.types = {}  -- name -> kind

-- UI
Holodeck.legendTLW = nil
Holodeck.legendLabel = nil
Holodeck.legendHint = nil
Holodeck.sheetTLW = nil
Holodeck.sheetLabel = nil
Holodeck.sheetPage = 1
Holodeck.savesPage = 1
Holodeck.texPage = 1

-- ============================= Utils ====================================
local function dhd(msg)
    d(string.format("|c69c0ff[%s]|r %s", Holodeck.displayName, tostring(msg)))
end

local function dbug(msg)
    if Holodeck.savedVars and Holodeck.savedVars.debug then dhd("dbg: " .. tostring(msg)) end
end

local function round2(n)
    return math.floor(((n or 0) * 100) + 0.5) / 100
end

local function sv()
    return Holodeck.savedVars or DEFAULTS
end

local function InferType(name, explicit)
    local nk = NormalizeKind(explicit)
    if nk then return nk end
    local key = string.lower(tostring(name or ""))
    if NAME_TYPE[key] then return NAME_TYPE[key] end
    -- Substring heuristics (entity ids like tank_mt, elite_captain_…, healer_1)
    if key:find("tank", 1, true) or key:find("_mt", 1, true) or key:match("^mt_") or key:match("^ot_") then
        return "tank"
    end
    if key:find("heal", 1, true) then return "healer" end
    if key:find("dps", 1, true) or key:find("_dd", 1, true) then return "dps" end
    if key:find("soak", 1, true) then return "soak" end
    if key:find("safe", 1, true) or key:find("kite", 1, true) then return "safe" end
    if key:find("portal", 1, true) or key:find("door", 1, true) then return "portal" end
    -- Word-ish trash (avoid matching random "add" inside longer ids)
    if key:find("trash", 1, true) or key:match("^add") or key:match("_add") or key:match("adds") then
        return "trash"
    end
    if key:find("stack", 1, true) then return "stack" end
    if key:find("boss", 1, true) and not key:find("mini", 1, true) then return "boss" end
    if key:find("lt", 1, true) or key:find("lieut", 1, true) or key:find("mini", 1, true)
        or key:find("elite_", 1, true) or key:find("captain", 1, true)
        or key:find("blackguard", 1, true) or key:find("lightweaver", 1, true) then
        return "mini"
    end
    if key:find("player", 1, true) or key:find("group", 1, true) then return "dps" end
    return "stack"
end

-- Pack ids are prefixed trash_ even for LTs; promote known mini-boss names.
local function RefineKind(kind, label, id)
    kind = NormalizeKind(kind) or kind
    if kind and kind ~= "trash" then return kind end
    local blob = string.lower(tostring(label or "") .. " " .. tostring(id or ""))
    if blob:find("blackguard", 1, true) or blob:find("lightweaver", 1, true)
        or blob:find("lieutenant", 1, true) or blob:find("deadraiser", 1, true)
        or blob:find("overseer", 1, true) or blob:find("colossus", 1, true)
        or blob:find("miniboss", 1, true)
        or (blob:find("alkosh", 1, true) and blob:find("fate", 1, true))
        or blob:find("iron servant", 1, true) then
        return "mini"
    end
    return kind
end

-- ============================= Safe UI ==================================
local function _SafeCreateTLW(name)
    if not name then return nil end
    if _G[name] then return _G[name] end
    if not WINDOW_MANAGER or not WINDOW_MANAGER.CreateTopLevelWindow then return nil end
    local ok, tlw = pcall(function() return WINDOW_MANAGER:CreateTopLevelWindow(name) end)
    if ok and tlw then return tlw end
    return _G[name]
end

local function _SafeCreateControl(name, parent, controlType)
    if not name or not parent or not controlType then return nil end
    if _G[name] then return _G[name] end
    if not WINDOW_MANAGER or not WINDOW_MANAGER.CreateControl then return nil end
    local ok, ctl = pcall(function() return WINDOW_MANAGER:CreateControl(name, parent, controlType) end)
    if ok and ctl then return ctl end
    return _G[name]
end

-- Short control names only — long elite_* entity ids break CreateControl on console.
local function uniqueName(prefix)
    Holodeck.idseq = (Holodeck.idseq or 0) + 1
    local p = tostring(prefix or "hd"):gsub("[^%w_]", "_"):sub(1, 24)
    return string.format("%s_%d_%d", p, Holodeck.idseq, GetFrameTimeMilliseconds() or 0)
end

-- Prefer pack path; try leading-slash variants; then ESO fallback (DM2 pattern).
local function _SetTextureSafe(ctrl, path, fallback)
    if not ctrl then return end
    local function attempt(p)
        if not p or p == "" then return false, "" end
        ctrl:SetTexture(p)
        local loaded = (ctrl.GetTextureFileName and ctrl:GetTextureFileName()) or ""
        return (loaded and loaded ~= ""), loaded
    end
    local candidates = {}
    local function add(p)
        if p and p ~= "" then candidates[#candidates + 1] = p end
    end
    add(path)
    if path and path:sub(1, 1) ~= "/" then add("/" .. path) end
    if path and path:sub(1, 1) == "/" then add(path:sub(2)) end
    add(fallback)
    add(TEX.FALLBACK)
    for i = 1, #candidates do
        local ok, loaded = attempt(candidates[i])
        if ok then return loaded end
    end
    ctrl:SetTexture(TEX.FALLBACK)
    return TEX.FALLBACK
end

local function TextureForKind(kind)
    local def = KIND[kind] or KIND.stack
    return def.texture, def.fallback or TEX.FALLBACK
end

-- ============================= HUD host =================================
local function ensureHUDTop()
    if Holodeck.hudTop then
        local w, h = GuiRoot:GetDimensions()
        Holodeck.hudTop:ClearAnchors()
        Holodeck.hudTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        if w and h then Holodeck.hudTop:SetDimensions(w, h) end
        Holodeck.hudTop:SetHidden(false)
        return Holodeck.hudTop
    end
    local tlw = _SafeCreateTLW("HolodeckHUDTop")
    if not tlw then return nil end
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(300000)
    if tlw.SetTopmost then tlw:SetTopmost(true) end
    local w, h = GuiRoot:GetDimensions()
    tlw:ClearAnchors()
    tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
    if w and h then tlw:SetDimensions(w, h) end
    tlw:SetAlpha(1)
    tlw:SetHidden(false)
    Holodeck.hudTop = tlw
    pcall(function()
        if ZO_SimpleSceneFragment and HUD_SCENE and HUD_UI_SCENE then
            Holodeck.fragment = ZO_SimpleSceneFragment:New(tlw)
            HUD_SCENE:AddFragment(Holodeck.fragment)
            HUD_UI_SCENE:AddFragment(Holodeck.fragment)
        end
    end)
    return tlw
end

-- ============================= World-space ==============================
local function WS_GetRenderOriginWorld()
    local sx, sy, sz = GuiRender3DPositionToWorldPosition(0, 0, 0)
    if not sx then
        local _, px, py, pz = GetUnitRawWorldPosition("player")
        return px, py, pz
    end
    return sx, sy, sz
end

local function WS_SetAtRaw(ctl, x, y, z, pitch, yaw, roll)
    if not ctl then return end
    local sx, sy, sz = WS_GetRenderOriginWorld()
    if not sx then return end
    ctl:SetTransformOffset((x - sx) / 100, (y - sy) / 100, (z - sz) / 100)
    ctl:SetTransformRotation(pitch or 0, yaw or 0, roll or 0)
    ctl:SetHidden(false)
end

local function BillboardYawPitch()
    local fx, fy, fz = GetCameraForward(SPACE_WORLD)
    if not fx or not fz then return 0, 0 end
    return math.atan2(fx, fz) + math.pi, -math.asin(fy or 0)
end

local function WS_CreateTexture(tag, sizeM, texturePath, color, dims, fallback)
    local ok, result = pcall(function()
        -- Do NOT embed long entity ids in the control name (elite_* keys are huge).
        local name = uniqueName("HolodeckWS")
        local parent = ensureHUDTop()
        if not parent then return nil end
        local ctl = _SafeCreateControl(name, parent, CT_TEXTURE)
        if not ctl then return nil end
        ctl:SetHidden(true)
        if SPACE_WORLD and ctl.SetSpace then ctl:SetSpace(SPACE_WORLD) end
        if ctl.SetTransformNormalizedOriginPoint then
            ctl:SetTransformNormalizedOriginPoint(0.5, 0.5)
        end
        ctl:SetDrawLayer(DL_OVERLAY)
        ctl:SetDrawTier(DT_HIGH)
        ctl:SetDrawLevel(360000)
        _SetTextureSafe(ctl, texturePath or TEX.BOSS, fallback or TEX.FALLBACK)
        local r, g, b = 1, 1, 1
        if color then r, g, b = color[1] or 1, color[2] or 1, color[3] or 1 end
        local a = sv().opacity or 1
        if ctl.SetDesaturation then ctl:SetDesaturation(0) end
        ctl:SetColor(r, g, b, a)
        ctl:SetAlpha(a)
        if ctl.SetScale then ctl:SetScale(1 / 100) end
        if ctl.SetTransformScale then ctl:SetTransformScale(sizeM or 1.2) end
        local dw, dh = 128, 128
        if dims then dw, dh = dims[1] or 128, dims[2] or 128 end
        ctl:SetDimensions(dw, dh)
        Holodeck.wsPins[name] = ctl
        return ctl
    end)
    if ok then return result end
    dbug("WS_CreateTexture failed tag=" .. tostring(tag) .. " err=" .. tostring(result))
    return nil
end

local function WS_CreateLabel(sizeM)
    local ok, result = pcall(function()
        local name = uniqueName("HolodeckNL")
        local parent = ensureHUDTop()
        if not parent then return nil end
        local ctl = _SafeCreateControl(name, parent, CT_LABEL)
        if not ctl then return nil end
        ctl:SetHidden(true)
        if SPACE_WORLD and ctl.SetSpace then ctl:SetSpace(SPACE_WORLD) end
        if ctl.SetTransformNormalizedOriginPoint then
            ctl:SetTransformNormalizedOriginPoint(0.5, 1.0)
        end
        ctl:SetDrawLayer(DL_OVERLAY)
        ctl:SetDrawTier(DT_HIGH)
        ctl:SetDrawLevel(370000)
        ctl:SetMouseEnabled(false)
        if TEXT_ALIGN_CENTER then ctl:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        if TEXT_ALIGN_BOTTOM then ctl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM) end
        ctl:SetFont("EsoUI/Common/Fonts/univers57.otf|28|soft-shadow-thick")
        ctl:SetDimensions(520, 56)
        if ctl.SetScale then ctl:SetScale(1 / 100) end
        if ctl.SetTransformScale then ctl:SetTransformScale(sizeM or 2.4) end
        Holodeck.wsPins[name] = ctl
        return ctl
    end)
    if ok then return result end
    dbug("WS_CreateLabel failed err=" .. tostring(result))
    return nil
end

local function PopPool(pool)
    local n = #pool
    if n < 1 then return nil end
    local c = pool[n]
    pool[n] = nil
    return c
end

local function RecycleControl(ctl, pool)
    if not ctl then return end
    ctl:SetHidden(true)
    pool[#pool + 1] = ctl
end

local function EnsureNameplate(act)
    if act.plate then return act.plate end
    local sizeM = (act.kind == "boss") and 2.6 or 2.1
    local lbl = PopPool(Holodeck.platePool)
    if not lbl then lbl = WS_CreateLabel(sizeM) end
    act.plate = lbl
    act._plateText = nil
    return lbl
end

local function HideNameplate(act)
    if act and act.plate then act.plate:SetHidden(true) end
end

local function PlaceNameplate(act, wx, wy, wz, pitch, yaw)
    if not ShouldNameplate(act) then
        HideNameplate(act)
        return
    end
    local lbl = EnsureNameplate(act)
    if not lbl then return end
    local col = ColorForActor(act)
    local cr, cg, cb = col[1] or 1, col[2] or 1, col[3] or 1
    if act._plateR ~= cr or act._plateG ~= cg or act._plateB ~= cb then
        lbl:SetColor(cr, cg, cb, 1)
        act._plateR, act._plateG, act._plateB = cr, cg, cb
    end
    if act._plateText ~= act.label then
        lbl:SetText(act.label)
        act._plateText = act.label
    end
    -- YOU is a tight head sticker. Boss plates stay large. Add/mini plates
    -- stay near pin scale (~1.2 m), not 2 m billboards.
    local lift = (act.kind == "boss") and 55 or 28
    if act.name == "_you" then
        lbl:SetDimensions(180, 36)
        if lbl.SetTransformScale then lbl:SetTransformScale(1.25) end
        if lbl.SetTransformNormalizedOriginPoint then
            lbl:SetTransformNormalizedOriginPoint(0.5, 0.5)
        end
        lift = 0
    elseif act.kind == "boss" then
        lbl:SetDimensions(520, 56)
        if lbl.SetTransformScale then lbl:SetTransformScale(2.6) end
        if lbl.SetTransformNormalizedOriginPoint then
            lbl:SetTransformNormalizedOriginPoint(0.5, 1.0)
        end
    else
        lbl:SetDimensions(240, 36)
        if lbl.SetTransformScale then lbl:SetTransformScale(1.15) end
        if lbl.SetTransformNormalizedOriginPoint then
            lbl:SetTransformNormalizedOriginPoint(0.5, 1.0)
        end
    end
    WS_SetAtRaw(lbl, wx, wy + lift, wz, pitch or 0, yaw or 0, 0)
    lbl:SetHidden(false)
end

local function PlayScale()
    local pct = 100
    if Holodeck.savedVars and Holodeck.savedVars.playScalePct then
        pct = tonumber(Holodeck.savedVars.playScalePct) or 100
    end
    if pct < 25 then pct = 25 end
    if pct > 400 then pct = 400 end
    local fit = 1
    -- Library packs are already baked into meters. fitScale would resize them again.
    -- Hand-recorded takes still use it.
    if Holodeck.fightSource ~= "library" then
        local fr = Holodeck.fight and Holodeck.fight._frame
        if type(fr) == "table" and type(fr.fitScale) == "number" and fr.fitScale > 0.2 then
            fit = fr.fitScale
        end
    end
    return (pct / 100) * fit
end

local function PackFlipXZ()
    local fx, fz = false, false
    local s = Holodeck.savedVars
    local id = Holodeck.loadedId
    if type(s) == "table" and type(id) == "string" and id ~= "" then
        if type(s.flipXByPack) == "table" then fx = s.flipXByPack[id] == true end
        if type(s.flipZByPack) == "table" then fz = s.flipZByPack[id] == true end
    end
    return fx, fz
end

-- Library packs: plant is the fight CENTER (midpoint of boss starts), not first-boss feet.
local function PackShiftXZ()
    if Holodeck.fightSource ~= "library" then return 0, 0 end
    local fr = Holodeck.fight and Holodeck.fight._frame
    if type(fr) ~= "table" then return 0, 0 end
    return fr.cx or 0, fr.cz or 0
end

local function LocalToWorld(lx, ly, lz)
    local o = Holodeck.origin
    if not o then return nil end
    local s = PlayScale()
    local sx, sz = PackShiftXZ()
    local x, z = (lx or 0) - sx, (lz or 0) - sz
    local fx, fz = PackFlipXZ()
    if fx then x = -x end
    if fz then z = -z end
    local yaw = o.yaw
    if yaw and yaw ~= 0 then
        local c, si = math.cos(yaw), math.sin(yaw)
        x, z = x * c - z * si, x * si + z * c
    end
    return o.x + x * 100 * s, o.y + (ly or 0) * 100, o.z + z * 100 * s
end

local function WorldYawFromPack(x0, z0, x1, z1)
    local ax, _, az = LocalToWorld(x0, CFG.PATH_Y_M, z0)
    local bx, _, bz = LocalToWorld(x1, CFG.PATH_Y_M, z1)
    if not ax or not bx then return 0 end
    return math.atan2(bx - ax, bz - az)
end

local function PlayerLocalXZ()
    if not Holodeck.origin then return nil end
    local _, px, _, pz = GetUnitRawWorldPosition("player")
    if not px then return nil end
    return round2((px - Holodeck.origin.x) / 100), round2((pz - Holodeck.origin.z) / 100)
end

-- ============================= Actor pins ===============================
local function SizeFor(kind)
    local s = sv()
    kind = NormalizeKind(kind) or kind
    if kind == "boss" then return s.bossSizeM or (KIND.boss.sizeM or 1.6) end
    if kind == "mini" then return s.minibossSizeM or (KIND.mini.sizeM or 1.25) end
    if kind == "origin" then return s.originSizeM or (KIND.origin.sizeM or 0.7) end
    if kind == "tank" or kind == "healer" or kind == "dps" then
        return s.roleSizeM or (KIND[kind] and KIND[kind].sizeM) or 1.1
    end
    return (KIND[kind] and KIND[kind].sizeM) or 1.0
end

local function EnsureActor(name, kind)
    kind = NormalizeKind(kind) or InferType(name)
    local act = Holodeck.actors[name]
    local def = KIND[kind] or KIND.stack
    local tex, fb = def.texture, def.fallback or TEX.FALLBACK
    if act and act.ctl then
        -- Always refresh height/size from KIND (defaults change across versions)
        act.kind = kind
        act.yOffM = def.yOffM
        _SetTextureSafe(act.ctl, tex, fb)
        act.ctl:SetColor(def.color[1], def.color[2], def.color[3], sv().opacity or 1)
        if act.ctl.SetDimensions then act.ctl:SetDimensions(128, 128) end
        if act.ctl.SetTransformScale then act.ctl:SetTransformScale(SizeFor(kind)) end
        -- Facing cones shift origin; recycled pins must sit on center again.
        if act.ctl.SetTransformNormalizedOriginPoint then
            act.ctl:SetTransformNormalizedOriginPoint(0.5, 0.5)
        end
        return act
    end
    local ctl = PopPool(Holodeck.ctlPool)
    if ctl then
        _SetTextureSafe(ctl, tex, fb)
        if ctl.SetDimensions then ctl:SetDimensions(128, 128) end
        if ctl.SetTransformScale then ctl:SetTransformScale(SizeFor(kind)) end
        if ctl.SetTransformNormalizedOriginPoint then
            ctl:SetTransformNormalizedOriginPoint(0.5, 0.5)
        end
    else
        ctl = WS_CreateTexture(name, SizeFor(kind), tex, def.color, nil, fb)
    end
    if not ctl then
        dhd("|cFF5555Pin create failed|r for " .. tostring(name) .. " (" .. tostring(kind) .. ")")
        return nil
    end
    act = { name = name, kind = kind, ctl = ctl, x = 0, z = 0, yOffM = def.yOffM, visible = true }
    Holodeck.actors[name] = act
    return act
end

local function HideFacing(act)
    if act and act.faceCtl then act.faceCtl:SetHidden(true) end
end

local function HideTag(act)
    if act and act.tagCtl then act.tagCtl:SetHidden(true) end
end

local function HidePadRing(act)
    if act and act.ringCtl then act.ringCtl:SetHidden(true) end
end

local function ActorTagged(id, tSec)
    local tags = Holodeck.fight and Holodeck.fight._tags
    if type(tags) ~= "table" or not id then return false end
    tSec = tonumber(tSec) or 0
    local i = 1
    while i <= #tags do
        local g = tags[i]
        if g and tSec >= (g.t0 or 0) and tSec < (g.t1 or 0) then
            local ids = g.ids
            if type(ids) == "table" then
                local j = 1
                while j <= #ids do
                    if id == ids[j] then return true end
                    j = j + 1
                end
            elseif id == g.a or id == g.b then
                return true
            end
        end
        i = i + 1
    end
    return false
end

local function PlaceTag(act, wx, wy, wz, pitch, yaw)
    if not act or not act.tagged then
        HideTag(act)
        return
    end
    local ctl = act.tagCtl
    if not ctl then
        ctl = WS_CreateTexture("tag", 1.05, TEX.SOAK, { 1.00, 0.28, 0.82 }, { 96, 96 }, TEX.SOAK_ESO)
        act.tagCtl = ctl
    end
    if not ctl then return end
    ctl:SetColor(1.00, 0.28, 0.82, 1)
    ctl:SetAlpha(0.95)
    if ctl.SetTransformScale then ctl:SetTransformScale(1.05) end
    -- Pack ghosts: hover just above the actor pin. YOU: wx/wy/wz is already head.
    local extra = (act.name == "_you") and 8 or 38
    WS_SetAtRaw(ctl, wx, wy + extra, wz, pitch or 0, yaw or 0, 0)
    ctl:SetHidden(false)
end

local function PlaceFacing(act)
    if not act or act.visible == false or act.guide then
        HideFacing(act)
        return
    end
    local k = act.kind
    if k == "origin" or k == "stack" or k == "soak" or k == "safe" or k == "portal" then
        HideFacing(act)
        return
    end
    local fdx, fdz = act.fdx, act.fdz
    if not fdx or not fdz then
        HideFacing(act)
        return
    end
    local len = math.sqrt(fdx * fdx + fdz * fdz)
    if len < 0.08 then
        HideFacing(act)
        return
    end
    local ux, uz = fdx / len, fdz / len
    -- Cone origin is the narrow end, planted at the actor's feet.
    local size = (k == "boss") and 3.0 or 2.0
    local lx, lz = act.x or 0, act.z or 0
    local wx, wy, wz = LocalToWorld(lx, CFG.PATH_Y_M, lz)
    if not wx then
        HideFacing(act)
        return
    end
    local ctl = act.faceCtl
    if not ctl then
        local col = ColorForActor(act)
        ctl = WS_CreateTexture("face", size, TEX.FACE, col, { 168, 120 }, TEX.DOT_ESO)
        if ctl and ctl.SetTransformNormalizedOriginPoint then
            -- Left edge of hd_face.dds is the small end (near actor).
            ctl:SetTransformNormalizedOriginPoint(0.08, 0.5)
        end
        act.faceCtl = ctl
    end
    if not ctl then return end
    local col = ColorForActor(act)
    ctl:SetColor(col[1] or 1, col[2] or 1, col[3] or 1, 1)
    ctl:SetAlpha(0.88)
    if ctl.SetDimensions then ctl:SetDimensions(168, 120) end
    if ctl.SetTransformScale then ctl:SetTransformScale(size) end
    -- +π: pitch=π/2 lays the quad on XZ with texture +X opposite atan2(dx, dz).
    -- NPC log heading needs that flip (bosses then face tanks). Player log
    -- heading is already inverted vs NPC, so roles skip the extra π.
    local yaw = WorldYawFromPack(act.x or 0, act.z or 0, (act.x or 0) + ux, (act.z or 0) + uz)
    if k ~= "tank" and k ~= "healer" and k ~= "dps" then
        yaw = yaw + math.pi
    end
    WS_SetAtRaw(ctl, wx, wy, wz, math.pi / 2, yaw, 0)
end

local function PlaceActor(act)
    if not act or not act.ctl or not Holodeck.origin then return end
    if act.visible == false then
        act.ctl:SetHidden(true)
        HideNameplate(act)
        HideFacing(act)
        HideTag(act)
        HidePadRing(act)
        return
    end
    local yOff = act.yOffM or (KIND[act.kind] and KIND[act.kind].yOffM) or 1.8
    local wx, wy, wz = LocalToWorld(act.x or 0, yOff, act.z or 0)
    if not wx then return end
    local col = ColorForActor(act)
    local a = sv().opacity or 1
    local glow = act.padSlot and Holodeck._activeCue and Holodeck._activeCue.slot == act.padSlot
    if glow then
        col = { 1.00, 0.88, 0.22 }
        a = 0.72
        if type(GetFrameTimeMilliseconds) == "function" then
            a = 0.62 + 0.38 * math.sin((GetFrameTimeMilliseconds() or 0) / 180)
        end
        if act.ctl.SetTransformScale then act.ctl:SetTransformScale(1.65) end
    elseif act.padSlot then
        if act.ctl.SetTransformScale then act.ctl:SetTransformScale(1.15) end
        a = 0.55
    end
    act.ctl:SetColor(col[1] or 1, col[2] or 1, col[3] or 1, a)
    local yaw, pitch = BillboardYawPitch()
    WS_SetAtRaw(act.ctl, wx, wy, wz, pitch, yaw, 0)
    act.ctl:SetHidden(false)
    act.ctl:SetAlpha(a)
    if glow then
        local ring = act.ringCtl
        if not ring then
            ring = WS_CreateTexture("pring", 3.1, TEX.RING, { 1.00, 0.90, 0.30 }, { 220, 220 }, TEX.RING_ESO)
            act.ringCtl = ring
        end
        if ring then
            local rx, ry, rz = LocalToWorld(act.x or 0, CFG.PATH_Y_M, act.z or 0)
            if rx then
                ring:SetColor(1.00, 0.90, 0.28, 1)
                ring:SetAlpha(a)
                if ring.SetTransformScale then ring:SetTransformScale(3.1) end
                WS_SetAtRaw(ring, rx, ry, rz, math.pi / 2, 0, 0)
                ring:SetHidden(false)
            end
        end
    else
        HidePadRing(act)
    end
    PlaceNameplate(act, wx, wy, wz, pitch, yaw)
    PlaceFacing(act)
    PlaceTag(act, wx, wy, wz, pitch, yaw)
end

local function EnsureOriginMarker()
    local act = EnsureActor("origin", "origin")
    if not act then return end
    -- Sit on the plant. PackShift maps fight-center → plant, so use pack center coords.
    local sx, sz = PackShiftXZ()
    act.x, act.z = sx, sz
    act.visible = true
    PlaceActor(act)
end

local function DestroyAllActors()
    for _, act in pairs(Holodeck.actors) do
        HideNameplate(act)
        RecycleControl(act.plate, Holodeck.platePool)
        RecycleControl(act.faceCtl, Holodeck.ctlPool)
        RecycleControl(act.tagCtl, Holodeck.ctlPool)
        RecycleControl(act.ringCtl, Holodeck.ctlPool)
        RecycleControl(act.ctl, Holodeck.ctlPool)
    end
    Holodeck.actors = {}
end

-- ============================= Path graphics ============================
local function ClearPathGfx()
    for i = 1, #Holodeck.pathGfx do
        local c = Holodeck.pathGfx[i]
        if c then
            c:SetHidden(true)
            local n = c.GetName and c:GetName()
            if n then Holodeck.wsPins[n] = nil end
        end
    end
    Holodeck.pathGfx = {}
end

local function AddPathControl(ctl)
    if ctl then Holodeck.pathGfx[#Holodeck.pathGfx + 1] = ctl end
    return ctl
end

local function PlaceFlatMarker(tag, lx, lz, texture, col, sizeM, alpha, dims, yaw)
    local ctl = WS_CreateTexture(tag, sizeM or 0.55, texture, col, dims or { 96, 96 })
    if not ctl then return nil end
    ctl:SetAlpha(alpha or 0.85)
    local wx, wy, wz = LocalToWorld(lx, CFG.PATH_Y_M, lz)
    if wx then
        -- Flat on ground. Optional yaw aligns a dash with a pack-space edge.
        WS_SetAtRaw(ctl, wx, wy, wz, math.pi / 2, yaw or 0, 0)
    end
    return AddPathControl(ctl)
end

local function PlaceFlatDash(tag, x0, z0, x1, z1, col, sizeM, alpha)
    local mx, mz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    local yaw = WorldYawFromPack(x0, z0, x1, z1)
    -- Filled rectangle (hd_dash), not a stretched hollow ring.
    return PlaceFlatMarker(tag, mx, mz, TEX.DASH, col, sizeM or 1.8, alpha or 0.95, { 200, 44 }, yaw)
end

local function FirstTrackXZ(track)
    if type(track) ~= "table" then return nil end
    local i = 1
    while i <= #track do
        local k = track[i]
        if k and (k.x ~= nil or k.z ~= nil) then
            return k.x or 0, k.z or 0
        end
        i = i + 1
    end
    return nil
end

local function ComputeFightFrame(fight)
    local ents = fight and fight.entities
    if type(ents) ~= "table" then return nil end
    local bosses = {}
    local i = 1
    while i <= #ents do
        local e = ents[i]
        if e and NormalizeKind(e.kind) == "boss" then
            local x, z = FirstTrackXZ(e.track)
            if x ~= nil then
                bosses[#bosses + 1] = { x = x, z = z, e = e }
            end
        end
        i = i + 1
    end
    local cx, cz, n = 0, 0, 0
    if #bosses > 0 then
        i = 1
        while i <= #bosses do
            cx = cx + bosses[i].x
            cz = cz + bosses[i].z
            n = n + 1
            i = i + 1
        end
    else
        i = 1
        while i <= #ents do
            local x, z = FirstTrackXZ(ents[i] and ents[i].track)
            if x ~= nil then
                cx = cx + x
                cz = cz + z
                n = n + 1
            end
            i = i + 1
        end
    end
    if n == 0 then return nil end
    cx, cz = cx / n, cz / n
    local r2 = 0
    local function acc(track)
        if type(track) ~= "table" then return end
        local j = 1
        while j <= #track do
            local k = track[j]
            if k and k.x ~= nil then
                local dx = k.x - cx
                local dz = (k.z or 0) - cz
                local d = dx * dx + dz * dz
                if d > r2 then r2 = d end
            end
            j = j + 1
        end
    end
    -- Boss path only. Trash/void (Rakkhat backyard) must not set the room size.
    i = 1
    while i <= #ents do
        if NormalizeKind(ents[i] and ents[i].kind) == "boss" then
            acc(ents[i].track)
        end
        i = i + 1
    end
    local r = math.sqrt(r2)
    if r < 4 then r = 4 end
    local fitScale = 1
    local targetR = CFG.HOUSE_RING_RADIUS_M or 22
    if r < targetR * 0.72 then
        fitScale = targetR / r
    elseif r > targetR * 1.7 then
        fitScale = targetR / r
    end
    local splitPx, splitPz = nil, nil
    if #bosses >= 2 then
        local dx = bosses[2].x - bosses[1].x
        local dz = bosses[2].z - bosses[1].z
        local px, pz = -dz, dx
        local plen = math.sqrt(px * px + pz * pz)
        if plen > 0.2 then
            splitPx, splitPz = px / plen, pz / plen
        end
    end
    return { cx = cx, cz = cz, r = r, splitPx = splitPx, splitPz = splitPz, bosses = bosses, fitScale = fitScale }
end

local function FrameOn()
    local s = Holodeck.savedVars
    if s and s.frameOn ~= nil then return s.frameOn == true end
    return true
end

-- Log compass is +x east, +z north. room.door = "south" puts the plant
-- side (higher z on Orphic) at South, with East on the right looking in.
function Holodeck.CompassAxes(fight)
    local door = type(fight) == "table" and type(fight.room) == "table" and fight.room.door
    if door == "south" then
        return 0, -1, -1, 0
    end
    return 0, 1, 1, 0
end

local function PlaceFrameCardinals(fr)
    if not fr or not Holodeck.origin then return end
    local r = fr.r or 8
    local cx, cz = fr.cx or 0, fr.cz or 0
    local nx, nz, ex, ez = Holodeck.CompassAxes(Holodeck.fight)
    local marks = {
        { id = "_frame_N", lab = "N", x = cx + nx * r, z = cz + nz * r },
        { id = "_frame_E", lab = "E", x = cx + ex * r, z = cz + ez * r },
        { id = "_frame_S", lab = "S", x = cx - nx * r, z = cz - nz * r },
        { id = "_frame_W", lab = "W", x = cx - ex * r, z = cz - ez * r },
    }
    local i = 1
    while i <= #marks do
        local m = marks[i]
        local act = EnsureActor(m.id, "origin")
        if act then
            act.guide = true
            act.label = m.lab
            act.x, act.z = m.x, m.z
            act.visible = true
            act.dead = false
            act.aspect = nil
            act.baseColor = KIND.origin.color
            PlaceActor(act)
        end
        i = i + 1
    end
end

local function DrawLibraryFrame()
    if not FrameOn() then return end
    if Holodeck.fightSource ~= "library" then return end
    local fight = Holodeck.fight
    if not fight then return end
    if not fight._frame then
        fight._frame = ComputeFightFrame(fight)
    end
    local fr = fight._frame
    if not fr then return end
    local cx, cz, r = fr.cx or 0, fr.cz or 0, fr.r or 8
    local ringCol = { 0.72, 0.92, 1.00 }
    local i = 1
    local step = (math.pi * 2) / CFG.FRAME_RING_DOTS
    while i <= CFG.FRAME_RING_DOTS do
        local a = (i - 1) * step
        PlaceFlatMarker(
            "frame_ring_" .. i,
            cx + math.cos(a) * r, cz + math.sin(a) * r,
            TEX.DOT, ringCol, 0.48, 0.95, { 64, 64 })
        i = i + 1
    end
    if fr.splitPx then
        local splitCol = { 1.00, 0.94, 0.40 }
        local n = 8
        i = 0
        while i < n do
            local u0 = (i / n) * 2 - 1
            local u1 = ((i + 0.55) / n) * 2 - 1
            PlaceFlatDash(
                "frame_split_" .. i,
                cx + fr.splitPx * r * u0, cz + fr.splitPz * r * u0,
                cx + fr.splitPx * r * u1, cz + fr.splitPz * r * u1,
                splitCol, 1.7, 1.0)
            i = i + 1
        end
    end
    local ents = fight.entities
    if type(ents) == "table" then
        i = 1
        while i <= #ents do
            local e = ents[i]
            if e and NormalizeKind(e.kind) == "boss" and type(e.track) == "table" then
                local col = ResolveEntityColor(e) or KIND.boss.color
                local prev = nil
                local j = 1
                local di = 0
                while j <= #e.track do
                    local k = e.track[j]
                    if k and k.x ~= nil and (k.t or 0) <= CFG.FRAME_LOOKAHEAD_SEC then
                        if prev then
                            local dx, dz = k.x - prev.x, (k.z or 0) - (prev.z or 0)
                            local len = math.sqrt(dx * dx + dz * dz)
                            if len > 0.2 then
                                local steps = math.max(1, math.floor(len / 1.6))
                                local s = 1
                                while s <= steps do
                                    local u = s / (steps + 1)
                                    di = di + 1
                                    PlaceFlatMarker(
                                        "frame_look_" .. i .. "_" .. di,
                                        prev.x + dx * u, (prev.z or 0) + dz * u,
                                        TEX.DOT, col, 0.38, 0.8, { 64, 64 })
                                    s = s + 1
                                end
                            end
                        end
                        prev = k
                    elseif k and (k.t or 0) > CFG.FRAME_LOOKAHEAD_SEC then
                        break
                    end
                    j = j + 1
                end
            end
            i = i + 1
        end
    end
    PlaceFrameCardinals(fr)
end

local function RebuildPathGfx()
    ClearPathGfx()
    if not Holodeck.origin then return end

    DrawLibraryFrame()

    if not sv().pathOn then return end

    for name, list in pairs(Holodeck.stops) do
        if list and #list > 0 then
            local typ = Holodeck.types[name] or InferType(name)
            local def = KIND[typ] or KIND.stack
            local col = def.color or { 1, 1, 1 }
            -- stop rings
            for i = 1, #list do
                local s = list[i]
                if s.visible ~= false and s.x ~= nil then
                    PlaceFlatMarker("ring_" .. name .. "_" .. i, s.x, s.z, TEX.RING, col, 1.15, 0.6, { 200, 200 })
                end
            end
            -- path "lines" = dots every ~1.1m (stretched UI textures often fail in SPACE_WORLD)
            local prev = nil
            for i = 1, #list do
                local s = list[i]
                if s.visible ~= false and s.x ~= nil then
                    if prev and prev.x ~= nil then
                        local x1, z1, x2, z2 = prev.x, prev.z, s.x, s.z
                        local dx, dz = x2 - x1, z2 - z1
                        local len = math.sqrt(dx * dx + dz * dz)
                        if len > 0.15 then
                            local steps = math.max(1, math.floor(len / CFG.PATH_DOT_SPACING))
                            for step = 1, steps do
                                local u = step / (steps + 1)
                                local px = x1 + dx * u
                                local pz = z1 + dz * u
                                PlaceFlatMarker(
                                    "dot_" .. name .. "_" .. i .. "_" .. step,
                                    px, pz, TEX.DOT, col, 0.35, 0.9, { 64, 64 })
                            end
                        end
                    end
                    prev = s
                elseif s.visible == false then
                    prev = nil
                end
            end
        end
    end
end

-- ============================= Stops model ==============================
local function SortStops(list)
    table.sort(list, function(a, b) return (a.t or 0) < (b.t or 0) end)
end

local function HasSandboxStops()
    for _, list in pairs(Holodeck.stops) do
        if list and #list > 0 then return true end
    end
    return false
end

local function CountStops()
    local n = 0
    for _, list in pairs(Holodeck.stops) do n = n + #(list or {}) end
    return n
end

local function ClearStops(quiet)
    Holodeck.stops = {}
    Holodeck.types = {}
    Holodeck.clock = 0
    Holodeck._lastStopAddMs = nil
    ClearPathGfx()
    if not quiet then dhd("Sandbox path cleared.") end
end

local function LastStop(name)
    local list = Holodeck.stops[name]
    if not list or #list == 0 then return nil end
    return list[#list]
end

local function PathEndTime()
    local maxT = 0
    for _, list in pairs(Holodeck.stops) do
        for i = 1, #(list or {}) do
            local s = list[i]
            local endT = (s.t or 0) + (s.hold or 0)
            if endT > maxT then maxT = endT end
        end
    end
    return maxT
end

local function kfAspect(s)
    return s and NormalizeAspect(s.aspect) or nil
end

local function kfDead(s)
    return s and (s.dead == true or s.dead == 1) or false
end

--- Position of one actor at timeline t. Returns x, z, visible, aspect, dead
local function SampleStopsAt(list, t)
    if not list or #list == 0 then return 0, 0, false, nil, false end

    -- Each stop i: arrive t_i, hold until tLeave, then travel (or SNAP) until t_{i+1}
    local first = list[1]
    if t < (first.t or 0) then
        local vis = first.visible
        if vis == nil then vis = true end
        return first.x or 0, first.z or 0, vis, kfAspect(first), kfDead(first)
    end

    for i = 1, #list do
        local s = list[i]
        local tArr = s.t or 0
        local hold = s.hold or 0
        local tLeave = tArr + hold
        local vis = s.visible
        if vis == nil then vis = true end
        local asp = kfAspect(s)
        local dead = kfDead(s)

        local nxt = list[i + 1]
        if not nxt then
            if t >= tArr then
                return s.x or 0, s.z or 0, vis, asp, dead
            end
        else
            local tNext = nxt.t or tLeave
            if tNext < tLeave then tNext = tLeave end

            if t < tArr then
                return s.x or 0, s.z or 0, vis, asp, dead
            end
            -- Inclusive hold: stay on this stop through tLeave
            if t <= tLeave + 1e-6 then
                return s.x or 0, s.z or 0, vis, asp, dead
            end

            local span = tNext - tLeave
            local isSnap = (nxt.snap == true) or (span <= CFG.SNAP_TRAVEL_EPS)

            if isSnap then
                -- Instant travel: do NOT return nxt forever — that stuck playback on stop 2.
                -- After leave, fall through so the next loop iteration owns the pose
                -- (hold on stop 2, then walk/snap to stop 3, etc.).
                -- (no return here)
            elseif t < tNext then
                if s.visible == false then
                    return nxt.x or 0, nxt.z or 0, nxt.visible ~= false, kfAspect(nxt), kfDead(nxt)
                end
                if nxt.visible == false then
                    return s.x or 0, s.z or 0, true, asp, dead
                end
                local u = (span > 1e-6) and ((t - tLeave) / span) or 1
                if u < 0 then u = 0 end
                if u > 1 then u = 1 end
                local x1, z1 = s.x or 0, s.z or 0
                local x2, z2 = nxt.x or 0, nxt.z or 0
                return x1 + (x2 - x1) * u, z1 + (z2 - z1) * u, true, asp, dead
            end
            -- else t >= tNext: continue to next stop in list
        end
    end
    local last = list[#list]
    return last.x or 0, last.z or 0, last.visible ~= false, kfAspect(last), kfDead(last)
end

local function PlaceAllSandboxPins()
    local nPins, nFail = 0, 0
    local names = {}
    for name in pairs(Holodeck.stops) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local list = Holodeck.stops[name]
        if list and #list > 0 then
            local typ = Holodeck.types[name] or InferType(name)
            local act = EnsureActor(name, typ)
            if act then
                local x, z, vis, asp, dead = SampleStopsAt(list, Holodeck.playT or 0)
                act.x = x or 0
                act.z = z or 0
                act.visible = (vis ~= false)
                act.aspect = asp
                act.dead = dead and true or false
                PlaceActor(act)
                nPins = nPins + 1
            else
                nFail = nFail + 1
            end
        end
    end
    EnsureOriginMarker()
    return nPins, nFail
end

local function FightFromSandbox()
    local entities = {}
    for name, list in pairs(Holodeck.stops) do
        if list and #list > 0 then
            local track = {}
            for i = 1, #list do
                local s = list[i]
                track[#track + 1] = {
                    t = s.t, x = s.x, z = s.z, hold = s.hold,
                    visible = s.visible, snap = s.snap,
                }
            end
            entities[#entities + 1] = {
                id = name,
                kind = Holodeck.types[name] or InferType(name),
                label = name,
                track = track,
                _stops = list,
            }
        end
    end
    table.sort(entities, function(a, b) return a.id < b.id end)
    local dur = PathEndTime()
    if dur < 0.5 then dur = 0.5 end
    return {
        id = Holodeck.workingName or "sandbox",
        name = "Path: " .. (Holodeck.workingName or "sandbox"),
        durationSec = dur,
        entities = entities,
        _fromSandbox = true,
        phases = {
            { id = 1, name = "Start", t = 0 },
            { id = 2, name = "Mid", t = dur * 0.5 },
            { id = 3, name = "End", t = dur },
        },
    }
end

--- One pass, no per-tick closures/tables (player packs were OOMing the 100MB addon heap).
local function SampleLibraryTrack(track, tSec)
    if type(track) ~= "table" or #track == 0 then return 0, 0, false, nil, false end
    -- First sample in (0, 1s): treat as on-stage at t=0 (Vashai started at 0.71).
    if tSec < 1 then
        local i = 1
        while i <= #track do
            local k = track[i]
            if k.x ~= nil or k.z ~= nil then
                local ft = k.t or 0
                if ft > 0 and ft < 1 and tSec < ft then
                    tSec = ft
                end
                break
            end
            i = i + 1
        end
    end
    local vis, seen = false, false
    local asp, dead = nil, false
    local face = nil
    local x0, z0, t0 = nil, nil, nil
    local x1, z1, t1 = nil, nil, nil
    for i = 1, #track do
        local k = track[i]
        local kt = k.t or 0
        if kt > tSec then
            if (k.x ~= nil or k.z ~= nil) and x1 == nil then
                x1, z1, t1 = k.x or 0, k.z or 0, kt
                break
            end
        else
            if k.visible ~= nil then
                vis = k.visible and true or false
                seen = true
            elseif k.x ~= nil or k.z ~= nil then
                vis = true
                seen = true
            end
            if k.aspect ~= nil then asp = kfAspect(k) end
            if k.facing ~= nil then face = k.facing end
            dead = kfDead(k)
            if k.x ~= nil or k.z ~= nil then
                x0, z0, t0 = k.x or 0, k.z or 0, kt
            end
        end
    end
    if not seen then vis = false end
    if x0 == nil then return 0, 0, vis, asp, dead end
    local fdx, fdz = nil, nil
    if face ~= nil then
        fdx, fdz = math.sin(face), math.cos(face)
    elseif x1 ~= nil then
        fdx, fdz = x1 - x0, (z1 or 0) - (z0 or 0)
    end
    if x1 == nil or t1 == nil or tSec <= (t0 or 0) then
        return x0, z0, vis, asp, dead, fdx, fdz
    end
    local span = t1 - t0
    local u = (span > 0) and ((tSec - t0) / span) or 0
    return x0 + (x1 - x0) * u, z0 + (z1 - z0) * u, vis, asp, dead, fdx, fdz
end

-- ============================= Portal / cue banner ========================
-- vLC annihilation is a ~12s pad window. Vet is mostly on a clock (~25s then
-- ~60s); HM also forces at 80%/35% HP. Each take still differs, so cues come
-- from this pack's player teleports (~20m hops), not a generic timer.

local function AlertsOn()
    local s = Holodeck.savedVars
    if s and s.alertsOn ~= nil then return s.alertsOn == true end
    return true
end

local function IsCountFight(fight)
    if type(fight) ~= "table" then return false end
    local s = string.lower(tostring(fight.id or "") .. " " .. tostring(fight.boss or "")
        .. " " .. tostring(fight.name or ""))
    return s:find("count", 1, true) or s:find("zily", 1, true)
end

local function FightCues(fight)
    if type(fight) ~= "table" then return nil end
    -- Hop-derived (_cues) wins over authored; each take's teleports are ground truth.
    if type(fight._cues) == "table" and #fight._cues > 0 then return fight._cues end
    if type(fight.cues) == "table" and #fight.cues > 0 then return fight.cues end
    return nil
end

local function CueAt(fight, tSec)
    local cues = FightCues(fight)
    if type(cues) ~= "table" then return nil end
    tSec = tonumber(tSec) or 0
    local best, bestT0, bestLeft = nil, -1, 0
    local i = 1
    while i <= #cues do
        local c = cues[i]
        if type(c) == "table" then
            local t0 = tonumber(c.t) or 0
            local t1 = t0 + (tonumber(c.dur) or CFG.PORTAL_HOLD_SEC)
            if tSec >= t0 and tSec < t1 and t0 >= bestT0 then
                best = c
                bestT0 = t0
                bestLeft = t1 - tSec
            end
        end
        i = i + 1
    end
    return best, bestLeft
end

local function HideSwapBanner()
    if Holodeck.swapTLW then Holodeck.swapTLW:SetHidden(true) end
    Holodeck._swapText = nil
end

local function EnsureSwapBanner()
    if Holodeck.swapTLW and Holodeck.swapLabel then return end
    local tlw = _SafeCreateTLW("HolodeckSwapBanner")
    if not tlw then return end
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(500000)
    tlw:SetDimensions(576, 134)
    tlw:ClearAnchors()
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, 0, -96)
    tlw:SetHidden(true)

    local back = _SafeCreateControl("HolodeckSwapBannerBack", tlw, CT_BACKDROP)
    if back then
        back:SetAnchorFill()
        back:SetCenterColor(0.18, 0.04, 0.02, 0.88)
        back:SetEdgeColor(1.00, 0.82, 0.22, 1)
        if back.SetEdgeTexture then pcall(function() back:SetEdgeTexture(nil, 1, 1, 4) end) end
    end

    local lbl = _SafeCreateControl("HolodeckSwapBannerLabel", tlw, CT_LABEL)
    if lbl then
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, tlw, TOPLEFT, 16, 10)
        lbl:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -16, -10)
        local n = 42
        if type(IsConsoleUI) == "function" then
            local ok, v = pcall(IsConsoleUI)
            if ok and v then n = 46 end
        end
        lbl:SetFont("EsoUI/Common/Fonts/univers57.otf|" .. tostring(n) .. "|thick-outline")
        lbl:SetColor(1, 0.92, 0.35, 1)
        if TEXT_ALIGN_CENTER then lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        if TEXT_ALIGN_CENTER then lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
        lbl:SetText("")
    end
    Holodeck.swapTLW = tlw
    Holodeck.swapLabel = lbl
    Holodeck.swapBack = back
end

local function UpdateSwapBanner(tSec)
    if not AlertsOn() or not Holodeck.origin or not Holodeck.fight then
        HideSwapBanner()
        return
    end
    local cue, remain = CueAt(Holodeck.fight, tSec)
    if not cue then
        HideSwapBanner()
        return
    end
    EnsureSwapBanner()
    if not Holodeck.swapTLW or not Holodeck.swapLabel then return end
    local text = cue.text or "Portal!"
    local line
    if cue.kind == "mirrorswap" then
        line = string.format("|cFFEE55%s|r", text)
    else
        line = string.format("|cFFEE55%s|r\n|cFFFFFF%.0f|r", text, remain or 0)
    end
    if Holodeck._swapText ~= line then
        Holodeck.swapLabel:SetText(line)
        Holodeck._swapText = line
    end
    local pulse = 0.78
    if type(GetFrameTimeMilliseconds) == "function" then
        pulse = 0.72 + 0.28 * math.sin((GetFrameTimeMilliseconds() or 0) / 180)
    end
    Holodeck.swapTLW:SetAlpha(pulse)
    Holodeck.swapTLW:SetHidden(false)
    local cid = (cue.kind or "portal") .. ":" .. tostring(cue.t or 0)
    if Holodeck._lastCueAnnounced ~= cid then
        Holodeck._lastCueAnnounced = cid
        if (cue.kind or "") == "portal" then
            dhd(string.format("|cFFEE55%s|r  %.0fs", text, cue.dur or CFG.PORTAL_HOLD_SEC))
        else
            dhd(string.format("|cFFEE55%s|r", text))
        end
    end
end

local function EnsurePads()
    local fight = Holodeck.fight
    local pads = fight and fight._pads
    if type(pads) ~= "table" or not Holodeck.origin then return end
    local i = 1
    while i <= #pads do
        local p = pads[i]
        if p then
            local pk = p.kind or "portal"
            if not KIND[pk] then pk = "portal" end
            local act = EnsureActor(p.id, pk)
            if act then
                act.guide = true
                act.label = p.label or tostring(p.slot or i)
                act.x, act.z = p.x or 0, p.z or 0
                act.visible = true
                if p.showAt ~= nil and (Holodeck.playT or 0) < p.showAt then
                    act.visible = false
                end
                if p.hideAt ~= nil and (Holodeck.playT or 0) >= p.hideAt then
                    act.visible = false
                end
                act.padSlot = p.slot
                act.dead = false
                act.aspect = nil
                act.baseColor = KIND[pk].color
                PlaceActor(act)
            end
        end
        i = i + 1
    end
end

local function ApplyTimeline(tSec, announce)
    local fight = Holodeck.fight
    if not fight then
        -- Still try sandbox stops if fight table missing
        if not HasSandboxStops() then return end
        fight = FightFromSandbox()
        Holodeck.fight = fight
        Holodeck.fightSource = "sandbox"
    end

    local live = { origin = true }
    Holodeck._activeCue = CueAt(fight, tSec)

    -- Prefer live Holodeck.stops when present (opened saves / authoring)
    if HasSandboxStops() then
        for name, list in pairs(Holodeck.stops) do
            if list and #list > 0 then
                live[name] = true
                local typ = Holodeck.types[name] or InferType(name)
                local act = EnsureActor(name, typ)
                if act then
                    local x, z, vis, asp, dead = SampleStopsAt(list, tSec)
                    act.x, act.z, act.visible, act.aspect = x, z, vis, asp
                    act.dead = dead and true or false
                    if not act.label then act.label = name end
                    local named = InferTintFromName(name)
                    if named and ASPECT_COLOR[named] then act.baseColor = ASPECT_COLOR[named] end
                    PlaceActor(act)
                end
            end
        end
    elseif fight.entities then
        -- Library packs — labels + tint from the entity (or lunar/shadow inferred from name).
        local ents = fight.entities or {}
        local uncoloredBosses = 0
        for i = 1, #ents do
            local def = ents[i]
            if def and NormalizeKind(def.kind) == "boss" and not ResolveEntityColor(def) then
                uncoloredBosses = uncoloredBosses + 1
            end
        end
        local bossPaletteI = 0
        for i = 1, #ents do
            local def = ents[i]
            if def and def.id then
                live[def.id] = true
                local kind = RefineKind(
                    NormalizeKind(def.kind) or InferType(def.id, def.kind) or "stack",
                    def.label, def.id)
                local act = EnsureActor(def.id, kind)
                if act then
                    local x, z, vis, asp, dead, fdx, fdz = SampleLibraryTrack(def.track, tSec)
                    -- Bosses stay planted when dead (red tint). Minis/trash still despawn.
                    if kind == "boss" then vis = true end
                    if kind == "boss" and Holodeck.GroundBossAt then
                        local gx, gz = Holodeck.GroundBossAt(fight, tSec)
                        if gx ~= nil then
                            x, z = gx, gz
                            fdx, fdz = nil, nil
                        end
                    end
                    act.x, act.z, act.visible, act.aspect = x, z, vis, asp
                    if fdx and fdz and (fdx * fdx + fdz * fdz) > 0.01 then
                        act.fdx, act.fdz = fdx, fdz
                    end
                    act.dead = dead and true or false
                    act.tagged = ActorTagged(def.id, tSec)
                    act.label = def.label or def.id
                    local col = ResolveEntityColor(def)
                    if not col and kind == "boss" and uncoloredBosses >= 2 then
                        bossPaletteI = bossPaletteI + 1
                        col = BOSS_PALETTE[((bossPaletteI - 1) % #BOSS_PALETTE) + 1]
                    end
                    act.important = false
                    if Holodeck.LookupActorLook then
                        local look = Holodeck.LookupActorLook(def.label, def.id, kind)
                        if look then
                            act.important = look.important == true
                            if look.short then act.label = look.short end
                            if not col and look.color then col = look.color end
                            if look.tex and act.ctl then
                                _SetTextureSafe(act.ctl, look.tex, look.fb or TEX.TRASH_ESO)
                            end
                            if look.sizeM and act.ctl and act.ctl.SetTransformScale then
                                act.ctl:SetTransformScale(look.sizeM)
                            end
                        end
                    end
                    act.baseColor = col
                    PlaceActor(act)
                end
            end
        end
    end

    EnsurePads()

    if ActorTagged("_you", tSec) then
        -- Attach to the trainer's body in raw cm (DeadMarker2). Do NOT run
        -- PlayerLocalXZ → LocalToWorld: house-fit scale / pack shift / yaw
        -- put the tag on a planter instead of the player.
        local _, px, py, pz = GetUnitRawWorldPosition("player")
        if px and py and pz then
            local you = EnsureActor("_you", "dps")
            if you then
                you.guide = false
                you.visible = true
                you.tagged = true
                you.label = "YOU"
                you.dead = false
                if you.ctl then you.ctl:SetHidden(true) end
                HideFacing(you)
                HidePadRing(you)
                local yOff = (sv().yOffsetM or 1.8) * 100
                local yaw, pitch = BillboardYawPitch()
                PlaceNameplate(you, px, py + yOff, pz, pitch, yaw)
                PlaceTag(you, px, py + yOff, pz, pitch, yaw)
                live["_you"] = true
            end
        end
    end

    -- Hide leftover actors from a previous pack/save (keep plant-frame guides)
    for name, act in pairs(Holodeck.actors) do
        if act and act.guide then
            live[name] = true
            PlaceActor(act)
        elseif not live[name] then
            act.visible = false
            if act.ctl then act.ctl:SetHidden(true) end
            HideNameplate(act)
            HideFacing(act)
            HideTag(act)
            HidePadRing(act)
        end
    end

    EnsureOriginMarker()

    if announce and fight.phases then
        local best = fight.phases[1]
        for i = 1, #fight.phases do
            if (fight.phases[i].t or 0) <= tSec then best = fight.phases[i] end
        end
        if best and best.id ~= Holodeck._lastPhaseAnnounced then
            Holodeck._lastPhaseAnnounced = best.id
            dhd(string.format("Phase %s — %s (t=%.1fs)", tostring(best.id), tostring(best.name), tSec))
        end
    end
    UpdateSwapBanner(tSec)
    if Holodeck.UpdateBossHpBars then Holodeck.UpdateBossHpBars(tSec) end
end

-- ============================= Legend / Sheet ===========================
local function HudFont(size)
    local n = tonumber(size) or 16
    if type(IsConsoleUI) == "function" then
        local ok, v = pcall(IsConsoleUI)
        if ok and v then n = n + 2 end
    end
    return "EsoUI/Common/Fonts/univers57.otf|" .. tostring(n) .. "|soft-shadow-thick"
end

-- Boss HP is the log percent (e.hp) when the pack has hpEnc. Else remaining % = 1 - t/dur.
-- Not a local function — keeps the 200-local chunk budget.
Holodeck.HpTriggers = {
    count = { { pct = 90, label = "Adds" } },
    zily = { { pct = 90, label = "Adds" } },
    rakkhat = { { pct = 11, label = "Execute" } },
    zhajhassa = { { pct = 70, label = "Shield" }, { pct = 30, label = "Shield" } },
    nahviintaas = {
        { pct = 90, label = "Portal" },
        { pct = 80, label = "Fly" },
        { pct = 70, label = "Portal" },
        { pct = 60, label = "Fly" },
        { pct = 50, label = "Portal" },
        { pct = 40, label = "Fly" },
        { pct = 33, label = "Execute" },
    },
    yolnahkriin = {
        { pct = 75, label = "Fly" },
        { pct = 50, label = "Fly" },
        { pct = 25, label = "Fly" },
    },
    lokkestiiz = {
        { pct = 80, label = "Fly" },
        { pct = 50, label = "Fly" },
        { pct = 20, label = "Fly" },
    },
}

function Holodeck.HideBossHpBars()
    if Holodeck.hpTLW then Holodeck.hpTLW:SetHidden(true) end
end

function Holodeck.UpdateBossHpBars(tSec)
    local fight = Holodeck.fight
    if not Holodeck.origin or type(fight) ~= "table" or Holodeck.fightSource ~= "library" then
        Holodeck.HideBossHpBars()
        return
    end
    local bosses = {}
    local ents = fight.entities
    if type(ents) == "table" then
        local i = 1
        while i <= #ents do
            local e = ents[i]
            if e and NormalizeKind(e.kind) == "boss" then
                bosses[#bosses + 1] = e
            end
            i = i + 1
        end
    end
    if #bosses < 1 then
        Holodeck.HideBossHpBars()
        return
    end
    if #bosses > 2 then bosses[3] = nil end
    local dur = tonumber(fight.durationSec) or 0
    if dur < 1 then dur = 1 end
    tSec = tonumber(tSec) or 0
    local remain = 100 * (1 - (tSec / dur))
    if Holodeck.RemainHp then
        local g = Holodeck.RemainHp(fight, tSec)
        if type(g) == "number" then remain = g end
    end
    if remain < 0 then remain = 0 end
    if remain > 100 then remain = 100 end

    if not Holodeck.hpTLW then
        local tlw = _SafeCreateTLW("HolodeckBossHp")
        if not tlw then return end
        tlw:SetMouseEnabled(false)
        tlw:SetClampedToScreen(true)
        tlw:SetDrawLayer(DL_OVERLAY)
        tlw:SetDrawTier(DT_HIGH)
        tlw:SetDrawLevel(430000)
        tlw:SetDimensions(220, 240)
        tlw:ClearAnchors()
        tlw:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 18, -56)
        Holodeck.hpTLW = tlw
        Holodeck.hpCols = {}
    end
    local tlw = Holodeck.hpTLW
    tlw:SetHidden(false)
    local n = #bosses
    local colW = 96
    tlw:SetDimensions(n * colW + 12, 236)
    local key = string.lower(tostring(fight.boss or "") .. " " .. tostring(fight.id or ""))
    local trig = nil
    if key:find("count", 1, true) or key:find("zily", 1, true) then
        trig = Holodeck.HpTriggers.count
    elseif key:find("rakkhat", 1, true) then
        trig = Holodeck.HpTriggers.rakkhat
    elseif key:find("zhaj", 1, true) then
        trig = Holodeck.HpTriggers.zhajhassa
    elseif key:find("nahviintaas", 1, true) then
        trig = Holodeck.HpTriggers.nahviintaas
    elseif key:find("yolnahkriin", 1, true) then
        trig = Holodeck.HpTriggers.yolnahkriin
    elseif key:find("lokkestiiz", 1, true) then
        trig = Holodeck.HpTriggers.lokkestiiz
    end

    local b = 1
    while b <= n do
        local col = Holodeck.hpCols[b]
        if not col then
            local x0 = 8 + (b - 1) * colW
            local name = _SafeCreateControl("HolodeckHpName" .. b, tlw, CT_LABEL)
            if name then
                name:ClearAnchors()
                name:SetAnchor(TOPLEFT, tlw, TOPLEFT, x0, 2)
                name:SetDimensions(colW - 8, 36)
                name:SetFont(HudFont(14))
                name:SetColor(1, 0.92, 0.55, 1)
                if TEXT_ALIGN_CENTER then name:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
            end
            local pctL = _SafeCreateControl("HolodeckHpPct" .. b, tlw, CT_LABEL)
            if pctL then
                pctL:ClearAnchors()
                pctL:SetAnchor(TOPLEFT, tlw, TOPLEFT, x0, 34)
                pctL:SetDimensions(colW - 8, 28)
                pctL:SetFont(HudFont(20))
                pctL:SetColor(1, 1, 1, 1)
                if TEXT_ALIGN_CENTER then pctL:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
            end
            local track = _SafeCreateControl("HolodeckHpTrack" .. b, tlw, CT_BACKDROP)
            if track then
                track:ClearAnchors()
                track:SetAnchor(TOPLEFT, tlw, TOPLEFT, x0 + 28, 64)
                track:SetDimensions(22, 160)
                track:SetCenterColor(0.08, 0.08, 0.08, 0.85)
                track:SetEdgeColor(0.5, 0.5, 0.5, 0.9)
                if track.SetEdgeTexture then pcall(function() track:SetEdgeTexture(nil, 1, 1, 1) end) end
            end
            local fill = _SafeCreateControl("HolodeckHpFill" .. b, tlw, CT_BACKDROP)
            if fill then
                fill:ClearAnchors()
                fill:SetAnchor(BOTTOMLEFT, track or tlw, BOTTOMLEFT, 2, -2)
                fill:SetDimensions(18, 156)
                fill:SetCenterColor(0.85, 0.18, 0.12, 0.95)
                fill:SetEdgeColor(0, 0, 0, 0)
            end
            local trigL = _SafeCreateControl("HolodeckHpTrig" .. b, tlw, CT_LABEL)
            if trigL then
                trigL:ClearAnchors()
                trigL:SetAnchor(TOPLEFT, tlw, TOPLEFT, x0, 224)
                trigL:SetDimensions(colW - 8, 18)
                trigL:SetFont(HudFont(12))
                trigL:SetColor(1, 0.85, 0.4, 1)
                if TEXT_ALIGN_CENTER then trigL:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
            end
            col = { name = name, pct = pctL, fill = fill, trig = trigL }
            Holodeck.hpCols[b] = col
        end
        local e = bosses[b]
        local bossRemain = remain
        if type(e.hp) == "table" and Holodeck.SampleHp then
            local sampled = Holodeck.SampleHp(e.hp, tSec)
            if type(sampled) == "number" then bossRemain = sampled end
        end
        local nm = e.label or e.id or "Boss"
        if col.name and col._nm ~= nm then
            col.name:SetText(nm)
            col._nm = nm
        end
        local pctTxt = string.format("%d%%", math.floor(bossRemain + 0.5))
        if col.pct and col._pct ~= pctTxt then
            col.pct:SetText(pctTxt)
            col._pct = pctTxt
        end
        if col.fill then
            local h = math.floor(156 * (bossRemain / 100) + 0.5)
            if h < 2 then h = 2 end
            col.fill:SetDimensions(18, h)
            local tint = ResolveEntityColor(e)
            if tint then
                col.fill:SetCenterColor(tint[1] or 0.85, tint[2] or 0.18, tint[3] or 0.12, 0.95)
            end
        end
        local mark = ""
        if type(e.hp) == "table" and type(fight.colorChange) == "table" then
            local bars = fight.colorChange
            local ti = 1
            while ti <= #bars do
                local tr = bars[ti]
                if type(tr) == "table" and tr.bar and tr.pct
                    and bossRemain <= (tr.pct or 0) + 0.51
                    and bossRemain > (tr.pct or 0) - 8 then
                    mark = tostring(tr.pct) .. "% " .. tostring(tr.bar)
                end
                ti = ti + 1
            end
        elseif type(trig) == "table" then
            local ti = 1
            while ti <= #trig do
                local tr = trig[ti]
                if tr and bossRemain <= (tr.pct or 0) + 0.51 and bossRemain > (tr.pct or 0) - 8 then
                    mark = tostring(tr.pct) .. "% " .. tostring(tr.label or "")
                end
                ti = ti + 1
            end
        end
        if col.trig and col._mark ~= mark then
            col.trig:SetText(mark)
            col._mark = mark
        end
        b = b + 1
    end
    local extra = Holodeck.hpCols
    if extra then
        local k = n + 1
        while extra[k] do
            if extra[k].name then extra[k].name:SetHidden(true) end
            k = k + 1
        end
    end
end

local function LegendText()
    if Holodeck.helpOpen and Holodeck.HelpCardText then
        return Holodeck.HelpCardText()
    end
    local fight = Holodeck.fight
    local pack = Holodeck.loadedId or (fight and fight.id)
    local title = (fight and fight.name) or pack or "no fight loaded"
    local planted = Holodeck.origin and true or false
    local t = Holodeck.playT or 0
    local dur = (fight and tonumber(fight.durationSec)) or 0
    local phase
    if Holodeck.playing then
        phase = "|c55FF88RUN|r"
    elseif Holodeck.playFinished then
        phase = "|cFFCC55END|r"
    else
        phase = "|c88AACCidle|r"
    end
    local loop = Holodeck.playMode or "once"
    local names = Holodeck.NamesMode and Holodeck.NamesMode() or "important"

    local function clock(sec)
        sec = math.floor((tonumber(sec) or 0) + 0.5)
        if sec < 0 then sec = 0 end
        local m = math.floor(sec / 60)
        return string.format("%d:%02d", m, sec - m * 60)
    end

    local hpBit = ""
    if fight and dur >= 1 then
        local remain = nil
        local ents = fight.entities
        if type(ents) == "table" and Holodeck.SampleHp then
            local ei = 1
            while ei <= #ents and remain == nil do
                local ent = ents[ei]
                if type(ent) == "table" and type(ent.hp) == "table"
                    and NormalizeKind(ent.kind) == "boss" then
                    remain = Holodeck.SampleHp(ent.hp, t)
                end
                ei = ei + 1
            end
        end
        if type(remain) ~= "number" then
            remain = 100 * (1 - (t / dur))
            if Holodeck.RemainHp then
                local g = Holodeck.RemainHp(fight, t)
                if type(g) == "number" then remain = g end
            end
        end
        if remain < 0 then remain = 0 end
        if remain > 100 then remain = 100 end
        hpBit = string.format("  ·  HP %d%%", math.floor(remain + 0.5))
    end

    local scaleBit = "scale 100%"
    if Holodeck.ScaleReadout then
        local pct, span, house = Holodeck.ScaleReadout()
        if span > 0 then
            scaleBit = string.format("scale %d%%  ·  house ~%.0fm", pct, house)
        else
            scaleBit = string.format("scale %d%%", pct)
        end
    end

    local rotBit = "rot —"
    if planted and Holodeck.origin and Holodeck.origin.yaw ~= nil then
        local deg = math.floor((Holodeck.origin.yaw * 180 / math.pi) + 0.5)
        deg = deg % 360
        if deg < 0 then deg = deg + 360 end
        rotBit = string.format("rot %d°", deg)
    end
    local fx, fz = PackFlipXZ()
    local flipBit = "flip off"
    if fx and fz then
        flipBit = "flip xz"
    elseif fx then
        flipBit = "flip x"
    elseif fz then
        flipBit = "flip z"
    end

    local nextLine
    local cue, left = CueAt(fight, t)
    if cue then
        nextLine = string.format("|cFFEE55%s|r  %.0fs", cue.text or "Portal!", left or 0)
    elseif not planted then
        nextLine = "|cFFEE55Stand on the mark|r  →  |cC0E0FF/hd plant|r"
    elseif not pack then
        nextLine = "|cC0E0FF/hd list|r   then   |cC0E0FF/hd load 1|r"
    elseif Holodeck.playing then
        nextLine = "|cC0E0FF/hd pause|r  ·  /hd halt"
    elseif Holodeck.playFinished then
        nextLine = "|cC0E0FF/hd play|r  to restart"
    else
        nextLine = "|cC0E0FF/hd play|r"
    end
    local lookHint = "|cC0E0FF/hd scale 150|r   |cC0E0FF/hd rot 90|r   |cC0E0FF/hd flip z|r   ·  |c888888/hd help|r"

    local tLine
    if dur >= 1 then
        tLine = string.format("%s  ·  t %s / %s%s  ·  plant %s",
            phase, clock(t), clock(dur), hpBit, planted and "SET" or "no")
    else
        tLine = string.format("%s  ·  t %s  ·  plant %s",
            phase, clock(t), planted and "SET" or "no")
    end

    return table.concat({
        string.format("|cAADDFFHolodeck|r  ·  %s  ·  names %s", loop, names),
        planted and ("|cFFFFFF" .. tostring(title) .. "|r") or "|c888888no fight loaded|r",
        tLine,
        string.format("%s  ·  %s  ·  %s", scaleBit, rotBit, flipBit),
        lookHint,
        nextLine,
    }, "\n")
end

local function EnsureLegend()
    if Holodeck.legendTLW and Holodeck.legendLabel then return end
    local tlw = _SafeCreateTLW("HolodeckLegend")
    if not tlw then return end
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(320000)
    tlw:SetDimensions(468, 176)
    tlw:ClearAnchors()
    -- Right side: away from chat + skill bar (controller).
    tlw:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -16, 72)

    local back = _SafeCreateControl("HolodeckLegendBack", tlw, CT_BACKDROP)
    if back then
        back:SetAnchorFill()
        back:SetCenterColor(0, 0, 0, 0.84)
        back:SetEdgeColor(0.45, 0.75, 1, 0.9)
        if back.SetEdgeTexture then pcall(function() back:SetEdgeTexture(nil, 1, 1, 2) end) end
    end

    local lbl = _SafeCreateControl("HolodeckLegendLabel", tlw, CT_LABEL)
    if lbl then
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, tlw, TOPLEFT, 14, 8)
        lbl:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -14, -8)
        lbl:SetFont(HudFont(17))
        lbl:SetColor(0.92, 0.95, 1, 1)
        if TEXT_ALIGN_LEFT then lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if TEXT_ALIGN_TOP then lbl:SetVerticalAlignment(TEXT_ALIGN_TOP) end
        lbl:SetText("")
    end
    Holodeck.legendTLW = tlw
    Holodeck.legendLabel = lbl
    -- No ZO_SimpleSceneFragment: it re-shows the bar after /hd legend off (same bug as sheet).
end

local function IsLegendOn()
    if Holodeck.savedVars and Holodeck.savedVars.legendOn ~= nil then
        return Holodeck.savedVars.legendOn == true
    end
    return true
end

local function ApplyLegendVisibility()
    local on = IsLegendOn()
    if Holodeck.legendTLW then
        Holodeck.legendTLW:SetHidden(not on)
        Holodeck.legendTLW:SetAlpha(on and 1 or 0)
    end
    if Holodeck.legendHint then
        Holodeck.legendHint:SetHidden(true)
    end
    -- Re-assert after chat/layers (console) so off stays off
    zo_callLater(function()
        if not Holodeck.legendTLW then return end
        Holodeck.legendTLW:SetHidden(not IsLegendOn())
        if Holodeck.legendHint then Holodeck.legendHint:SetHidden(true) end
    end, 50)
    zo_callLater(function()
        if not Holodeck.legendTLW then return end
        Holodeck.legendTLW:SetHidden(not IsLegendOn())
        if Holodeck.legendHint then Holodeck.legendHint:SetHidden(true) end
    end, 250)
end

local function UpdateLegend()
    EnsureLegend()
    ApplyLegendVisibility()
    if Holodeck.legendTLW then
        if Holodeck.helpOpen then
            Holodeck.legendTLW:SetDimensions(468, 348)
        else
            Holodeck.legendTLW:SetDimensions(468, 176)
        end
    end
    if IsLegendOn() and Holodeck.legendLabel then
        Holodeck.legendLabel:SetText(LegendText())
    end
end


local function BuildSheetRows()
    local rows = {}
    local names = {}
    for n in pairs(Holodeck.stops) do names[#names + 1] = n end
    table.sort(names)
    for _, name in ipairs(names) do
        local list = Holodeck.stops[name]
        local short = tostring(name)
        if #short > 28 then short = short:sub(1, 12) .. ".." .. short:sub(-12) end
        for i = 1, #(list or {}) do
            local s = list[i]
            local state = (s.visible == false) and "HIDE" or "show"
            rows[#rows + 1] = string.format(
                "%d %s t=%.1f h=%.1f x=%.1f z=%.1f %s",
                i, short, s.t or 0, s.hold or 0, s.x or 0, s.z or 0, state)
        end
    end
    return rows
end

local function SheetText()
    local rows = BuildSheetRows()
    local pages = math.max(1, math.ceil(#rows / CFG.SHEET_ROWS))
    local page = tonumber(Holodeck.sheetPage) or 1
    if page < 1 then page = 1 end
    if page > pages then page = pages end
    Holodeck.sheetPage = page

    local lines = {}
    local wn = tostring(Holodeck.workingName or "sandbox")
    if #wn > 36 then wn = wn:sub(1, 16) .. ".." .. wn:sub(-16) end
    lines[#lines + 1] = string.format("PATH SHEET | %s | clock %.1fs | stops %d",
        wn, Holodeck.clock or 0, CountStops())
    lines[#lines + 1] = string.format("Page %d/%d  ·  /hd sheet next|prev  ·  off", page, pages)
    lines[#lines + 1] = "# name  t hold  x z  state"
    if #rows == 0 then
        lines[#lines + 1] = "(no stops — /hd stopadd or /hd open N)"
    else
        local i0 = (page - 1) * CFG.SHEET_ROWS + 1
        local i1 = math.min(#rows, page * CFG.SHEET_ROWS)
        for i = i0, i1 do
            lines[#lines + 1] = rows[i]
        end
    end
    lines[#lines + 1] = "Full dump: /hd export   ·  drag panel to move"
    return table.concat(lines, "\n")
end

local function EnsureSheet()
    if Holodeck.sheetTLW and Holodeck.sheetLabel then return end
    local tlw = _SafeCreateTLW("HolodeckSheet")
    if not tlw then return end
    tlw:SetMouseEnabled(true)
    tlw:SetMovable(true)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(400000)
    if tlw.SetTopmost then pcall(function() tlw:SetTopmost(true) end) end
    tlw:SetDimensions(580, 360)
    local x, y = sv().sheetX or 40, sv().sheetY or 120
    tlw:ClearAnchors()
    tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)

    local back = _SafeCreateControl("HolodeckSheetBack", tlw, CT_BACKDROP)
    if back then
        back:SetAnchorFill()
        back:SetCenterColor(0, 0, 0, 0.88)
        back:SetEdgeColor(0.5, 0.85, 1, 0.85)
        if back.SetEdgeTexture then pcall(function() back:SetEdgeTexture(nil, 1, 1, 2) end) end
        back:SetDrawLevel(0)
    end

    local lbl = _SafeCreateControl("HolodeckSheetLabel", tlw, CT_LABEL)
    if lbl then
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, tlw, TOPLEFT, 12, 10)
        lbl:SetDimensions(556, 340)
        lbl:SetFont("EsoUI/Common/Fonts/univers57.otf|14|soft-shadow-thin")
        lbl:SetColor(1, 1, 1, 1)
        if TEXT_ALIGN_LEFT then lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if TEXT_ALIGN_TOP then lbl:SetVerticalAlignment(TEXT_ALIGN_TOP) end
        if lbl.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
            pcall(function() lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end)
        end
        lbl:SetDrawLevel(10)
        lbl:SetMouseEnabled(false)
        lbl:SetText("…")
    end
    Holodeck.sheetTLW = tlw
    Holodeck.sheetLabel = lbl
    -- IMPORTANT: do NOT attach ZO_SimpleSceneFragment here.
    -- Fragments fight SetHidden when chat/command layers open (console), which
    -- made the sheet vanish after /hd stopadd until a full scene change (LAM).
    -- Visibility is owned solely by sv().sheetOn (see sheet show/hide helper).
end

local function ApplySheetVisibility()
    local tlw = Holodeck.sheetTLW
    if not tlw then return end
    local on = (Holodeck.savedVars and Holodeck.savedVars.sheetOn) == true
    -- Explicit show/hide; re-assert after every command so chat layers cannot leave us stuck
    tlw:SetHidden(not on)
    tlw:SetAlpha(1)
    if tlw.SetHidden then
        -- second assert next frame after chat/action-layer settles (console)
        zo_callLater(function()
            if not Holodeck.sheetTLW then return end
            local stillOn = (Holodeck.savedVars and Holodeck.savedVars.sheetOn) == true
            Holodeck.sheetTLW:SetHidden(not stillOn)
            if stillOn then Holodeck.sheetTLW:SetAlpha(1) end
        end, 50)
        zo_callLater(function()
            if not Holodeck.sheetTLW then return end
            local stillOn = (Holodeck.savedVars and Holodeck.savedVars.sheetOn) == true
            Holodeck.sheetTLW:SetHidden(not stillOn)
        end, 200)
    end
end

local function UpdateSheet()
    EnsureSheet()
    ApplySheetVisibility()
    if Holodeck.sheetLabel then
        Holodeck.sheetLabel:SetHidden(false)
        Holodeck.sheetLabel:SetText(SheetText())
        Holodeck.sheetLabel:SetDimensions(556, 340)
    end
end

local function RefreshUI()
    UpdateLegend()
    UpdateSheet()
    UpdateSwapBanner(Holodeck.playT or 0)
end

-- Packed keyframes: "tcs xcs zcs flags [facingCs];..."  flags: 1 vis, 2 dead, 4 lunar, 8 shadow.
-- Optional 5th number is log facing in centi-radians. Old 4-field packs still decode.
-- Resident packs keep this string; working tables exist only for the loaded fight.
local function EncodeTrack(track)
    if type(track) ~= "table" or #track == 0 then return "" end
    local parts = {}
    for i = 1, #track do
        local k = track[i]
        local flags = 0
        if k.visible ~= false then flags = flags + 1 end
        if k.dead == true or k.dead == 1 then flags = flags + 2 end
        local asp = k.aspect
        if asp == "lunar" or asp == "light" or asp == "holy" then
            flags = flags + 4
        elseif asp == "shadow" or asp == "dark" then
            flags = flags + 8
        end
        local core = string.format("%d %d %d %d",
            math.floor((k.t or 0) * 100 + 0.5),
            math.floor((k.x or 0) * 100 + 0.5),
            math.floor((k.z or 0) * 100 + 0.5),
            flags)
        if k.facing ~= nil then
            parts[i] = core .. " " .. tostring(math.floor((k.facing or 0) * 100 + 0.5))
        else
            parts[i] = core
        end
    end
    return table.concat(parts, ";")
end

local function DecodeTrack(enc)
    if type(enc) ~= "string" or enc == "" then return {} end
    local track = {}
    for seg in string.gmatch(enc, "[^;]+") do
        local nums = {}
        for n in string.gmatch(seg, "(-?%d+)") do
            nums[#nums + 1] = tonumber(n)
        end
        if #nums >= 4 then
        local flags = nums[4] or 0
        local kf = {
            t = (nums[1] or 0) / 100,
            x = (nums[2] or 0) / 100,
            z = (nums[3] or 0) / 100,
            visible = (flags % 2 == 1),
        }
        if math.floor(flags / 2) % 2 == 1 then kf.dead = true end
        if math.floor(flags / 4) % 2 == 1 then
            kf.aspect = "lunar"
        elseif math.floor(flags / 8) % 2 == 1 then
            kf.aspect = "shadow"
        end
        if nums[5] ~= nil then kf.facing = nums[5] / 100 end
        track[#track + 1] = kf
        end
    end
    return track
end

local function CompactFight(fight)
    local ents = fight and fight.entities
    if type(ents) ~= "table" then return end
    for i = 1, #ents do
        local e = ents[i]
        if type(e) == "table" and type(e.track) == "table" then
            e.trackEnc = EncodeTrack(e.track)
            e.track = nil
        end
        if type(e) == "table" and type(e.hpEnc) == "string" then
            e.hp = nil
        end
    end
    fight._frame = nil
end

local function ExpandFight(fight)
    local ents = fight and fight.entities
    if type(ents) ~= "table" then return end
    for i = 1, #ents do
        local e = ents[i]
        if type(e) == "table" then
            if type(e.track) ~= "table" and type(e.trackEnc) == "string" then
                e.track = DecodeTrack(e.trackEnc)
            end
            if type(e.hpEnc) == "string" and Holodeck.DecodeHp then
                e.hp = Holodeck.DecodeHp(e.hpEnc)
            end
        end
    end
    fight._frame = ComputeFightFrame(fight)
end

-- Portal hops (~20m in <3.5s). Banner = 12s channel ending at the teleport.
-- Floor pads: 3 per side from landing clusters (o^o). Glow the pair this hop used.
-- Authored fight.cues are fallback when no player hops exist.
local function BuildPortalLayout(fight)
    if type(fight) ~= "table" then return end
    fight._pads = nil
    local hops = {}
    local ents = fight.entities
    if type(ents) == "table" then
        local i = 1
        while i <= #ents do
            local e = ents[i]
            local kind = e and RefineKind(NormalizeKind(e.kind) or e.kind, e.label, e.id)
            if kind == "tank" or kind == "healer" or kind == "dps" then
                local tr = e.track
                if type(tr) == "table" then
                    local prev = nil
                    local j = 1
                    while j <= #tr do
                        local kf = tr[j]
                        if kf and kf.x ~= nil then
                            if prev then
                                local dx = (kf.x or 0) - (prev.x or 0)
                                local dz = (kf.z or 0) - (prev.z or 0)
                                local dist = math.sqrt(dx * dx + dz * dz)
                                local dt = (kf.t or 0) - (prev.t or 0)
                                if dist >= 14 and dt >= 0 and dt <= 3.5 then
                                    hops[#hops + 1] = { t = kf.t or 0, x = kf.x or 0, z = kf.z or 0 }
                                end
                            end
                            prev = kf
                        end
                        j = j + 1
                    end
                end
            end
            i = i + 1
        end
    end
    table.sort(hops, function(a, b) return (a.t or 0) < (b.t or 0) end)
    local clusters = {}
    local h = 1
    while h <= #hops do
        local hp = hops[h]
        local cl = clusters[#clusters]
        if not cl or hp.t - cl[1].t >= 8 then
            clusters[#clusters + 1] = { hp }
        else
            cl[#cl + 1] = hp
        end
        h = h + 1
    end
    local idn = string.lower(tostring(fight.id or "") .. " " .. tostring(fight.boss or "")
        .. " " .. tostring(fight.name or ""))
    local isCount = IsCountFight(fight)
    local isRakk = idn:find("rakkhat", 1, true) and true or false

    local cues = {}
    local slotXs, zHi, zLo, nHi, nLo = {}, nil, nil, 0, 0
    local c = 1
    while c <= #clusters do
        local cl = clusters[c]
        local mid = cl[math.floor((#cl + 1) / 2)]
        local tHop = mid.t or 0
        local lead = isRakk and 8 or CFG.PORTAL_HOLD_SEC
        local t0 = tHop - lead
        if t0 < 1 then t0 = 1 end
        local sx, sz, n = 0, 0, #cl
        local zs = {}
        local k = 1
        while k <= n do
            sx = sx + (cl[k].x or 0)
            sz = sz + (cl[k].z or 0)
            zs[k] = cl[k].z or 0
            k = k + 1
        end
        sx, sz = sx / n, sz / n
        local zmid = sz
        local zA, zB, nA, nB = 0, 0, 0, 0
        k = 1
        while k <= n do
            if (zs[k] or 0) >= zmid then
                zA = zA + zs[k]
                nA = nA + 1
            else
                zB = zB + zs[k]
                nB = nB + 1
            end
            k = k + 1
        end
        if nA > 0 then
            zHi = ((zHi or 0) * nHi + zA) / (nHi + nA)
            nHi = nHi + nA
        end
        if nB > 0 then
            zLo = ((zLo or 0) * nLo + zB) / (nLo + nB)
            nLo = nLo + nB
        end
        slotXs[#slotXs + 1] = sx
        if isCount then
            cues[#cues + 1] = {
                t = t0, dur = CFG.PORTAL_HOLD_SEC, kind = "portal", text = "Portal!",
                slotX = sx, hopT = tHop,
            }
        elseif isRakk then
            cues[#cues + 1] = {
                t = t0, dur = lead, kind = "backyard", text = "Backyard!",
                hopT = tHop,
            }
        end
        c = c + 1
    end
    if isCount and #cues == 0 then
        -- Boss-only packs have no player hops. Vet pads: ~25s then every ~60s.
        local dur = tonumber(fight.durationSec) or 0
        local t = 25
        local slot = 1
        while t + 5 < dur do
            cues[#cues + 1] = {
                t = t, dur = CFG.PORTAL_HOLD_SEC, kind = "portal", text = "Portal!",
                slot = slot,
            }
            slot = (slot % 3) + 1
            t = t + 60
        end
    end
    if #cues > 0 then
        fight._cues = cues
    elseif type(fight.cues) == "table" and #fight.cues > 0 then
        fight._cues = fight.cues
    else
        fight._cues = {}
    end

    if not isCount then return end
    local xs = {}
    local u = 1
    while u <= #slotXs do
        local x = slotXs[u]
        local seen = false
        local v = 1
        while v <= #xs do
            if math.abs(xs[v] - x) < 6 then seen = true end
            v = v + 1
        end
        if not seen then xs[#xs + 1] = x end
        u = u + 1
    end
    table.sort(xs)
    if #xs == 2 then
        xs = { xs[1], (xs[1] + xs[2]) * 0.5, xs[2] }
    elseif #xs == 1 then
        local x0 = xs[1]
        xs = { x0 - 11, x0, x0 + 11 }
    elseif #xs == 0 then
        local fr = fight._frame
        if type(fr) ~= "table" or not fr.splitPx then return end
        local half = 11
        xs = { (fr.cx or 0) - half, fr.cx or 0, (fr.cx or 0) + half }
        zHi = (fr.cz or 0) + 10
        zLo = (fr.cz or 0) - 10
        if fr.bosses and fr.bosses[1] and fr.bosses[2] then
            local b1, b2 = fr.bosses[1], fr.bosses[2]
            zHi = math.max(b1.z, b2.z)
            zLo = math.min(b1.z, b2.z)
        end
    end
    if not zHi or not zLo then return end
    -- Shallow o^o: middle pad a bit farther from the mirror (mid-z).
    local zMirr = (zHi + zLo) * 0.5
    local bow = 1.8
    local zHiM = zHi + ((zHi >= zMirr) and bow or -bow)
    local zLoM = zLo + ((zLo < zMirr) and -bow or bow)
    local pads = {}
    local s = 1
    while s <= #xs do
        local zH = (s == 2) and zHiM or zHi
        local zL = (s == 2) and zLoM or zLo
        pads[#pads + 1] = { id = "_pad_" .. s .. "A", x = xs[s], z = zH, slot = s, label = tostring(s) }
        pads[#pads + 1] = { id = "_pad_" .. s .. "B", x = xs[s], z = zL, slot = s, label = tostring(s) }
        s = s + 1
    end
    fight._pads = pads
    local q = 1
    while q <= #cues do
        local cx = cues[q].slotX
        if cx then
            local best, bi, d = 1e9, 1, 0
            s = 1
            while s <= #xs do
                d = math.abs(xs[s] - cx)
                if d < best then best, bi = d, s end
                s = s + 1
            end
            cues[q].slot = bi
        end
        q = q + 1
    end
end

-- Random DPS "tag" marks while adds are up (lusterbeam / make-vulnerable practice).
local function BuildTagAssign(fight)
    if type(fight) ~= "table" then return end
    fight._tags = {}
    if not IsCountFight(fight) then return end
    if type(math.randomseed) == "function" then
        local seed = 1
        if type(GetFrameTimeMilliseconds) == "function" then
            seed = (GetFrameTimeMilliseconds() or 1)
        end
        math.randomseed(math.floor(seed % 2147483646) + 1)
    end
    local ents = fight.entities
    if type(ents) ~= "table" then return end
    local dps, spans = {}, {}
    local i = 1
    while i <= #ents do
        local e = ents[i]
        local kind = e and RefineKind(NormalizeKind(e.kind) or e.kind, e.label, e.id)
        -- Lusterbeam hits two players per side (usually DPS; healers can get it).
        if (kind == "dps" or kind == "healer") and e.id then
            dps[#dps + 1] = e
        elseif (kind == "trash" or kind == "mini") and type(e.track) == "table" then
            local tOn, tOff = nil, nil
            local j = 1
            while j <= #e.track do
                local kf = e.track[j]
                local vis = kf and kf.visible ~= false and not kf.dead and kf.x ~= nil
                if vis then
                    if not tOn then tOn = kf.t or 0 end
                    tOff = kf.t or 0
                elseif tOn then
                    spans[#spans + 1] = { t0 = tOn, t1 = (kf and kf.t) or tOff }
                    tOn = nil
                end
                j = j + 1
            end
            if tOn then spans[#spans + 1] = { t0 = tOn, t1 = (tOff or tOn) + 8 } end
        end
        i = i + 1
    end
    if #spans < 1 then return end
    table.sort(spans, function(a, b) return a.t0 < b.t0 end)
    local waves = {}
    i = 1
    while i <= #spans do
        local sp = spans[i]
        local w = waves[#waves]
        if not w or sp.t0 > (w.t1 + 8) then
            waves[#waves + 1] = { t0 = sp.t0, t1 = sp.t1 }
        else
            if sp.t1 > w.t1 then w.t1 = sp.t1 end
        end
        i = i + 1
    end
    local fr = fight._frame
    local cz = (fr and fr.cz) or 0
    fight._tagStands = nil
    local cues = fight._cues
    if type(cues) ~= "table" then
        cues = {}
        fight._cues = cues
    end
    if #dps < 1 then
        -- Boss-only: tag the trainer only. No dummy heads.
        local w = 1
        while w <= #waves do
            local wv = waves[w]
            fight._tags[#fight._tags + 1] = { t0 = wv.t0, t1 = wv.t1 + 6, ids = { "_you" }, you = true }
            cues[#cues + 1] = { t = wv.t0, dur = 2, kind = "debuff", text = "Debuff the adds!" }
            w = w + 1
        end
        return
    end
    local w = 1
    while w <= #waves do
        local wv = waves[w]
        local sideA, sideB = {}, {}
        i = 1
        while i <= #dps do
            local e = dps[i]
            local x, z, vis = SampleLibraryTrack(e.track, wv.t0 + 0.5)
            if vis ~= false then
                if (z or 0) >= cz then
                    sideA[#sideA + 1] = e.id
                else
                    sideB[#sideB + 1] = e.id
                end
            end
            i = i + 1
        end
        local ids = {}
        local s = 1
        while s <= 2 do
            local side = (s == 1) and sideA or sideB
            local taken1, taken2 = nil, nil
            if #side >= 1 then
                taken1 = math.random(1, #side)
                ids[#ids + 1] = side[taken1]
            end
            if #side >= 2 then
                taken2 = math.random(1, #side - 1)
                if taken1 and taken2 >= taken1 then taken2 = taken2 + 1 end
                ids[#ids + 1] = side[taken2]
            end
            s = s + 1
        end
        if #ids > 0 then
            fight._tags[#fight._tags + 1] = { t0 = wv.t0, t1 = wv.t1 + 6, ids = ids }
            cues[#cues + 1] = { t = wv.t0, dur = 2, kind = "debuff", text = "Debuff the adds!" }
        end
        w = w + 1
    end
end

function Holodeck.RegisterFight(fight)
    if type(fight) == "table" and fight.id then
        CompactFight(fight)
        Holodeck.Fights[fight.id] = fight
    end
end

-- ============================= Load fight ===============================
local function LoadFightTable(fight, source, resetTime)
    if not fight then return false end
    if Holodeck.fight and Holodeck.fight ~= fight then
        CompactFight(Holodeck.fight)
    end
    ExpandFight(fight)
    BuildPortalLayout(fight)
    BuildTagAssign(fight)
    if Holodeck.ApplyRecipe then Holodeck.ApplyRecipe(fight) end
    if Holodeck.ApplyColorChange then Holodeck.ApplyColorChange(fight) end
    if Holodeck.ApplyFleshPortals then Holodeck.ApplyFleshPortals(fight) end
    DestroyAllActors()
    Holodeck.fight = fight
    Holodeck.fightSource = source
    Holodeck.loadedId = fight.id
    if resetTime then
        Holodeck.playT = 0
        Holodeck.playFinished = false
        Holodeck._lastPhaseAnnounced = nil
        Holodeck._lastCueAnnounced = nil
    end
    ApplyTimeline(Holodeck.playT or 0, false)
    EnsureOriginMarker()
    return true
end

local function PreferPlayFight()
    if Holodeck.fight and Holodeck.fightSource == "library" then
        return true
    end
    if HasSandboxStops() then
        local f = FightFromSandbox()
        local src = (Holodeck.workingName == "sandbox") and "sandbox" or "save"
        LoadFightTable(f, src, false)
        return true
    end
    return false
end

-- Total Lua heap (all addons). ESO has no per-addon memory API.
local function ReadLuaKb()
    if type(collectgarbage) ~= "function" then return nil end
    local ok, n = pcall(collectgarbage, "count")
    if ok and type(n) == "number" then return n end
    return nil
end

local function EnsureMemMeter()
    if Holodeck.memTLW and Holodeck.memLabel then return end
    local tlw = _SafeCreateTLW("HolodeckMemMeter")
    if not tlw then return end
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(330000)
    tlw:SetDimensions(280, 36)
    tlw:ClearAnchors()
    tlw:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 18, -18)
    local lbl = _SafeCreateControl("HolodeckMemMeterLabel", tlw, CT_LABEL)
    if lbl then
        lbl:SetAnchor(BOTTOMLEFT, tlw, BOTTOMLEFT, 0, 0)
        lbl:SetDimensions(280, 36)
        lbl:SetFont("EsoUI/Common/Fonts/univers57.otf|18|soft-shadow-thick")
        lbl:SetColor(0.55, 1.0, 0.65, 1)
        if TEXT_ALIGN_LEFT then lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if TEXT_ALIGN_BOTTOM then lbl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM) end
        lbl:SetMouseEnabled(false)
        lbl:SetText("")
    end
    Holodeck.memTLW = tlw
    Holodeck.memLabel = lbl
    tlw:SetHidden(true)
end

local function HideMemMeter()
    if Holodeck.memTLW then Holodeck.memTLW:SetHidden(true) end
end

-- collectgarbage is the whole UI heap. Console cap ~100MB; PC is often 100–400MB without crash.
local function MemWarnLevels()
    local console = false
    if type(IsConsoleUI) == "function" then
        local ok, v = pcall(IsConsoleUI)
        if ok and v then console = true end
    end
    if console then return 70, 90 end
    return 320, 480
end

local function UpdateMemMeter(nowMs)
    local active = Holodeck.playing or Holodeck.playFinished
    if not active then
        HideMemMeter()
        return
    end
    nowMs = tonumber(nowMs) or tonumber(GetFrameTimeMilliseconds()) or 0
    local last = Holodeck._memLastMs or 0
    if (nowMs - last) < 250 and Holodeck._memShown then return end
    Holodeck._memLastMs = nowMs
    local kb = ReadLuaKb()
    if not kb then
        HideMemMeter()
        return
    end
    EnsureMemMeter()
    if not Holodeck.memTLW or not Holodeck.memLabel then return end
    local mb = kb / 1024
    local base = Holodeck._memKbAtPlay
    local line
    if base and base > 0 then
        local dmb = (kb - base) / 1024
        line = string.format("Lua %.1f MB  (%+.1f)", mb, dmb)
    else
        line = string.format("Lua %.1f MB", mb)
    end
    if Holodeck._memText ~= line then
        Holodeck.memLabel:SetText(line)
        Holodeck._memText = line
        local warnAt, badAt = MemWarnLevels()
        local r, g, b = 0.55, 1.0, 0.65
        if mb >= badAt then
            r, g, b = 1.0, 0.25, 0.2
        elseif mb >= warnAt then
            r, g, b = 1.0, 0.75, 0.25
        end
        Holodeck.memLabel:SetColor(r, g, b, 1)
    end
    Holodeck.memTLW:SetHidden(false)
    Holodeck._memShown = true
end

-- ============================= Tick =====================================
local function _StopTick()
    if not Holodeck._tickRunning then return end
    EVENT_MANAGER:UnregisterForUpdate(Holodeck._tickName)
    Holodeck._tickRunning = false
end

local function _StartTick()
    if Holodeck._tickRunning then return end
    Holodeck._lastTickMs = GetFrameTimeMilliseconds()
    EVENT_MANAGER:RegisterForUpdate(Holodeck._tickName, Holodeck._tickMs, function()
        local now = GetFrameTimeMilliseconds()
        local last = Holodeck._lastTickMs or now
        local dt = (now - last) / 1000
        if dt < 0 then dt = 0 end
        if dt > 0.25 then dt = 0.25 end
        Holodeck._lastTickMs = now

        if Holodeck.playing and Holodeck.origin and Holodeck.fight and not Holodeck.playFinished then
            local dur = Holodeck.fight.durationSec or PathEndTime()
            if dur < 0.5 then dur = 0.5 end
            Holodeck.playT = (Holodeck.playT or 0) + dt
            if Holodeck.fightSource == "sandbox" or Holodeck.fightSource == "save" then
                Holodeck.clock = Holodeck.playT
            end

            local mode = Holodeck.playMode or "once"
            if Holodeck.playT >= dur then
                if mode == "loop" then
                    Holodeck.playT = Holodeck.playT - dur
                    Holodeck._lastPhaseAnnounced = nil
                    Holodeck._lastCueAnnounced = nil
                else
                    -- once: park at end
                    Holodeck.playT = dur
                    Holodeck.playing = false
                    Holodeck.playFinished = true
                    dhd("Playback finished — actors stay at end. /hd play to restart.")
                end
            end
            ApplyTimeline(Holodeck.playT, true)
        else
            -- Parked pins: billboard with camera, but not at 20 Hz.
            local idle = Holodeck._idlePlaceMs or 0
            idle = idle + ((now - last) or 0)
            if idle >= 200 then
                idle = 0
                for _, act in pairs(Holodeck.actors) do
                    if act.visible ~= false then PlaceActor(act) end
                end
                if Holodeck.origin then EnsureOriginMarker() end
            end
            Holodeck._idlePlaceMs = idle
        end
        -- light legend refresh while playing (never force-show if user turned it off)
        if (Holodeck.playing or Holodeck.playFinished) and IsLegendOn() and Holodeck.legendLabel then
            Holodeck.legendLabel:SetText(LegendText())
        end
        UpdateSwapBanner(Holodeck.playT or 0)
        if Holodeck.UpdateBossHpBars then Holodeck.UpdateBossHpBars(Holodeck.playT or 0) end
        UpdateMemMeter(now)
    end)
    Holodeck._tickRunning = true
end

-- ============================= Commands =================================
local function CmdPlant()
    local _, x, y, z = GetUnitRawWorldPosition("player")
    if not x then dhd("Could not read position.") return end
    local yaw = 0
    if type(GetPlayerCameraHeading) == "function" then
        yaw = GetPlayerCameraHeading() or 0
    end
    -- Pack +Z follows the camera. (Old +90° made every fight need /hd rot 90.)
    Holodeck.origin = { x = x, y = y, z = z, yaw = yaw }
    Holodeck.playing = false
    Holodeck.playFinished = false
    Holodeck.playT = 0
    EnsureOriginMarker()
    _StartTick()
    if Holodeck.fight and Holodeck.fightSource == "library" then
        ApplyTimeline(0, false)
    end
    RebuildPathGfx()
    RefreshUI()
    dhd("Planted |cFFEE55fight center|r at your feet (facing locked).")
    if Holodeck.fight and Holodeck.fightSource == "library" then
        dhd("Facing = camera. Sideways? |cC0E0FF/hd rot 90|r  ·  orbit backwards? |cC0E0FF/hd flip z|r")
    else
        dhd("Then: |cC0E0FF/hd list|r  ·  |cC0E0FF/hd load <id>|r  ·  |cC0E0FF/hd play|r  ·  |cC0E0FF/hd help|r")
    end
end

local function CmdEdit(arg)
    local name = (arg or ""):match("^(%S+)")
    if not name then
        dhd("Editing: " .. tostring(Holodeck.editName) .. "  — /hd edit <name>  e.g. boss, lieutenant, stack_main")
        return
    end
    Holodeck.editName = string.lower(name)
    Holodeck.types[Holodeck.editName] = Holodeck.types[Holodeck.editName] or InferType(Holodeck.editName)
    dhd("Now editing path for |cC0E0FF" .. Holodeck.editName .. "|r (type " .. Holodeck.types[Holodeck.editName] .. ")")
    RefreshUI()
end

local function CmdClock(arg)
    local n = tonumber(arg)
    if not n or n < 0 then
        dhd(string.format("Clock is %.2fs.  /hd clock <sec> sets absolute time.  /hd clock+ <sec> adds.", Holodeck.clock or 0))
        return
    end
    Holodeck.clock = n
    Holodeck.playT = n
    Holodeck.playFinished = false
    if Holodeck.fight then ApplyTimeline(n, false) end
    dhd(string.format("Clock set to %.2fs (absolute).", n))
    RefreshUI()
end

local function CmdClockPlus(arg)
    local n = tonumber(arg)
    if not n then
        dhd("Usage: /hd clock+ <sec>  e.g. /hd clock+ 10  (add to current clock)")
        return
    end
    CmdClock(tostring((Holodeck.clock or 0) + n))
end

-- mode: nil/"walk" = distance travel; "snap" = true 0s travel (teleport/leap)
local function CmdStopAdd(arg, mode)
    if not Holodeck.origin then dhd("Plant origin first: /hd plant") return end
    mode = mode or "walk"
    local name = (arg or ""):match("^(%S+)") or Holodeck.editName or "boss"
    name = string.lower(name)
    Holodeck.editName = name
    local typ = Holodeck.types[name] or InferType(name)
    Holodeck.types[name] = typ

    local lx, lz = PlayerLocalXZ()
    if not lx then dhd("No player position.") return end

    local nowMs = GetFrameTimeMilliseconds() or 0
    local list = Holodeck.stops[name]
    if not list then list = {} Holodeck.stops[name] = list end

    local t
    local prev = LastStop(name)
    local travelSec = 0
    if mode == "snap" then
        -- True 0s teleport: next arrive = previous leave (or epsilon if hold was 0 so we don't replace)
        local leave = 0
        if prev then
            leave = (prev.t or 0) + (prev.hold or 0)
            t = leave
            -- Same t as previous stop would replace it — keep a new stop with 0-span snap
            if math.abs(t - (prev.t or 0)) < 0.0001 then
                t = (prev.t or 0) + 0.001
            end
        else
            t = Holodeck.clock or 0
        end
        -- Delayed snap only if clock is clearly later (user set clock intentionally)
        if (Holodeck.clock or 0) > leave + 0.05 then
            t = Holodeck.clock
            travelSec = 0  -- still snap: no walk lerp even if clock delayed
        else
            Holodeck.clock = t
            travelSec = 0
        end
    else
        -- Hybrid: default travel = distance / PATH_SPEED
        travelSec = CFG.MIN_TRAVEL_SEC
        if prev and prev.x ~= nil then
            local dx = lx - (prev.x or 0)
            local dz = lz - (prev.z or 0)
            local dist = math.sqrt(dx * dx + dz * dz)
            travelSec = math.max(CFG.MIN_TRAVEL_SEC, dist / CFG.PATH_SPEED_M_S)
        end
        if prev then
            local minNext = (prev.t or 0) + (prev.hold or 0) + CFG.MIN_TRAVEL_SEC
            local autoT = (prev.t or 0) + (prev.hold or 0) + travelSec
            if (Holodeck.clock or 0) > minNext + 0.05 then
                t = Holodeck.clock
                travelSec = math.max(0, t - ((prev.t or 0) + (prev.hold or 0)))
            else
                t = autoT
                Holodeck.clock = t
            end
            if t < minNext then t = minNext Holodeck.clock = t end
        else
            t = Holodeck.clock or 0
            travelSec = 0
        end
    end

    local stop = { t = round2(t), x = lx, z = lz, hold = 0, visible = true, snap = (mode == "snap") }
    local replaced = false
    -- Only replace same-t if same mode intent and very close position (re-mark), not snap over walk
    for i = 1, #list do
        local old = list[i]
        if math.abs((old.t or 0) - stop.t) < 0.0005 then
            local odx = (old.x or 0) - lx
            local odz = (old.z or 0) - lz
            if (odx * odx + odz * odz) < 0.25 or mode ~= "snap" then
                list[i] = stop
                replaced = true
                break
            else
                stop.t = round2((stop.t or 0) + 0.001)
            end
        end
    end
    if not replaced then list[#list + 1] = stop end
    SortStops(list)
    Holodeck._lastStopAddMs = nowMs
    Holodeck.workingName = Holodeck.workingName or "sandbox"
    if Holodeck.workingName ~= "sandbox" and Holodeck.fightSource == "library" then
        Holodeck.workingName = "sandbox"
    end

    local act = EnsureActor(name, typ)
    if act then act.x, act.z, act.visible = lx, lz, true PlaceActor(act) end
    EnsureOriginMarker()
    RebuildPathGfx()
    PreferPlayFight()
    ApplyTimeline(Holodeck.clock or t, false)
    _StartTick()
    if mode == "snap" then
        dhd(string.format(
            "SNAP |cC0E0FF%s|r #%d  t=%.2f  x=%.2f z=%.2f  travel=0s (teleport)  hold=0",
            name, #list, stop.t, lx, lz))
    else
        dhd(string.format(
            "Stop |cC0E0FF%s|r #%d  t=%.2f  x=%.2f z=%.2f  travel~%.1fs  hold=0  (/hd hold <sec> · /hd snap · /hd undo)",
            name, #list, stop.t, lx, lz, travelSec))
    end
    RefreshUI()
end

local function CmdSnap(arg)
    CmdStopAdd(arg, "snap")
end

local function CmdUndo(arg)
    if not HasSandboxStops() then
        dhd("Nothing to undo.")
        return
    end
    local name = (arg or ""):match("^(%S+)")
    if name then
        name = string.lower(name)
    else
        name = Holodeck.editName or "boss"
    end
    local list = Holodeck.stops[name]
    if not list or #list == 0 then
        -- fall back: undo last stop of any actor (most recent by t)
        local bestName, bestI, bestT = nil, nil, -1
        for n, lst in pairs(Holodeck.stops) do
            if lst and #lst > 0 then
                local s = lst[#lst]
                if (s.t or 0) >= bestT then
                    bestT = s.t or 0
                    bestName = n
                    bestI = #lst
                end
            end
        end
        if not bestName then dhd("Nothing to undo.") return end
        name = bestName
        list = Holodeck.stops[name]
    end
    local removed = table.remove(list)
    if #list == 0 then Holodeck.stops[name] = nil end
    if removed then
        Holodeck.clock = removed.t or Holodeck.clock
        dhd(string.format("Undo |cC0E0FF%s|r stop at t=%.2f (x=%.1f z=%.1f). stops left=%d",
            name, removed.t or 0, removed.x or 0, removed.z or 0, list and #list or 0))
    end
    -- hide actor if no stops left for them
    if not Holodeck.stops[name] and Holodeck.actors[name] then
        Holodeck.actors[name].visible = false
        PlaceActor(Holodeck.actors[name])
    end
    RebuildPathGfx()
    PreferPlayFight()
    ApplyTimeline(Holodeck.clock or 0, false)
    RefreshUI()
end

local function CmdHold(arg)
    local n = tonumber(arg)
    if not n or n < 0 then
        dhd("Usage: /hd hold <sec>  — pause at last stop of current edit name")
        return
    end
    local name = Holodeck.editName or "boss"
    local s = LastStop(name)
    if not s then
        dhd("No stop yet for " .. name .. " — /hd stopadd first")
        return
    end
    s.hold = round2(n)
    -- advance clock to end of this hold for next stop convenience
    Holodeck.clock = (s.t or 0) + s.hold
    PreferPlayFight()
    RebuildPathGfx()
    dhd(string.format("Hold %.2fs at %s t=%.2f (clock now %.2fs for next stop)", s.hold, name, s.t or 0, Holodeck.clock))
    RefreshUI()
end

local function CmdStopHide(arg)
    if not Holodeck.origin then dhd("Plant first: /hd plant") return end
    local name = (arg or ""):match("^(%S+)") or Holodeck.editName or "boss"
    name = string.lower(name)
    Holodeck.editName = name
    Holodeck.types[name] = Holodeck.types[name] or InferType(name)
    if not Holodeck.stops[name] then Holodeck.stops[name] = {} end
    local t = Holodeck.clock or 0
    local list = Holodeck.stops[name]
    local stop = { t = round2(t), visible = false, hold = 0 }
    list[#list + 1] = stop
    SortStops(list)
    PreferPlayFight()
    RebuildPathGfx()
    dhd(string.format("Hide |cC0E0FF%s|r at t=%.2f", name, t))
    RefreshUI()
end

local function CmdType(arg)
    local name, typ = arg:match("^(%S+)%s+(%S+)")
    if not name or not typ then
        dhd("Usage: /hd type <name> <kind>")
        dhd("  enemies: boss mini trash")
        dhd("  roles:   tank healer dps")
        dhd("  spots:   stack soak safe portal")
        dhd("  palette: /hd textures")
        return
    end
    name = string.lower(name)
    typ = NormalizeKind(typ)
    if not typ or not KIND[typ] then
        dhd("Unknown kind. /hd textures for the full palette.")
        return
    end
    Holodeck.types[name] = typ
    EnsureActor(name, typ)
    local def = KIND[typ]
    dhd(string.format("%s type = |cC0E0FF%s|r (%s)", name, typ, def.label or typ))
    RebuildPathGfx()
    RefreshUI()
end

local function CmdPlay(arg)
    if not Holodeck.origin then dhd("Plant first: /hd plant") return end
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "once" or arg == "loop" then
        Holodeck.playMode = arg
        if Holodeck.savedVars then Holodeck.savedVars.playMode = arg end
    end
    if not PreferPlayFight() then
        dhd("Nothing to play — |cC0E0FF/hd plant|r then |cC0E0FF/hd load <id>|r  (/hd list)")
        return
    end

    -- Restart from beginning when starting play
    Holodeck.playT = 0
    Holodeck.playFinished = false
    Holodeck._lastPhaseAnnounced = nil
    Holodeck._lastCueAnnounced = nil
    if Holodeck.fight then BuildTagAssign(Holodeck.fight) end
    Holodeck.helpOpen = false
    Holodeck.playing = true
    Holodeck._memKbAtPlay = ReadLuaKb()
    Holodeck._memText = nil
    Holodeck._memShown = false
    ApplyTimeline(0, true)
    _StartTick()
    UpdateMemMeter(GetFrameTimeMilliseconds())
    if Holodeck.savesPanel then Holodeck.savesPanel:SetHidden(true) end
    local mode = Holodeck.playMode or "once"
    local dur = (Holodeck.fight and Holodeck.fight.durationSec) or PathEndTime() or 0
    local park = (mode == "loop") and "Loop restarts at 0." or "Parks at end."
    dhd(string.format("Playing \"%s\"  dur=%.1fs. %s",
        (Holodeck.fight and Holodeck.fight.name) or "?", dur, park))
    if dur < 0.6 then
        dhd("|cFFAA66Short clock|r — markers may look static (single keyframe or tiny duration).")
    end
    RefreshUI()
end

local function CmdMode(arg)
    arg = (arg or ""):lower():match("^(%S+)")
    if arg ~= "once" and arg ~= "loop" then
        dhd("Play mode: " .. tostring(Holodeck.playMode) .. "  — /hd mode once|loop")
        return
    end
    Holodeck.playMode = arg
    if Holodeck.savedVars then Holodeck.savedVars.playMode = arg end
    dhd("Play mode = " .. arg)
    RefreshUI()
end

local function CmdPause()
    if not Holodeck.playing then dhd("Not playing.") return end
    Holodeck.playing = false
    dhd(string.format("Paused t=%.1fs", Holodeck.playT or 0))
    RefreshUI()
end

local function CmdReplay()
    if not Holodeck.origin then dhd("Plant first.") return end
    Holodeck.playT = 0
    Holodeck.playFinished = false
    Holodeck._lastPhaseAnnounced = nil
    Holodeck._lastCueAnnounced = nil
    if PreferPlayFight() then ApplyTimeline(0, true) end
    dhd("Replay position t=0 (start). /hd play to run.")
    RefreshUI()
end

local function CmdHalt()
    Holodeck.playing = false
    Holodeck.playFinished = false
    HideMemMeter()
    -- keep current positions (do not jump home)
    dhd(string.format("Halted at t=%.1fs (poses stay). /hd replay then /hd play to restart from start.", Holodeck.playT or 0))
    RefreshUI()
end

local function CmdPath(arg)
    arg = (arg or ""):lower()
    if arg == "on" then sv().pathOn = true
    elseif arg == "off" then sv().pathOn = false
    else sv().pathOn = not sv().pathOn end
    if Holodeck.savedVars then Holodeck.savedVars.pathOn = sv().pathOn end
    RebuildPathGfx()
    dhd("Path rings/lines: " .. (sv().pathOn and "ON" or "OFF"))
end

local function CmdFrame(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    local s = Holodeck.savedVars
    if not s then return end
    if arg == "on" then
        s.frameOn = true
    elseif arg == "off" then
        s.frameOn = false
    else
        s.frameOn = not FrameOn()
    end
    RebuildPathGfx()
    dhd("Fight frame: |cC0E0FF" .. (FrameOn() and "ON" or "OFF") .. "|r  ·  boss-walk ring / N-E-S-W / split / 30s boss path")
end

local function CmdAlerts(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    local s = Holodeck.savedVars
    if not s then return end
    if arg == "on" then
        s.alertsOn = true
    elseif arg == "off" then
        s.alertsOn = false
    else
        s.alertsOn = not AlertsOn()
    end
    UpdateSwapBanner(Holodeck.playT or 0)
    dhd("Alerts: |cC0E0FF" .. (AlertsOn() and "ON" or "OFF") .. "|r  ·  Portal! on pad windows")
end

local function CmdSheet(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "next" or arg == "+" or arg == "n" then
        Holodeck.sheetPage = (Holodeck.sheetPage or 1) + 1
        if Holodeck.savedVars then Holodeck.savedVars.sheetOn = true end
        UpdateSheet()
        dhd("Sheet page " .. tostring(Holodeck.sheetPage))
        return
    end
    if arg == "prev" or arg == "-" or arg == "p" or arg == "back" then
        Holodeck.sheetPage = math.max(1, (Holodeck.sheetPage or 1) - 1)
        if Holodeck.savedVars then Holodeck.savedVars.sheetOn = true end
        UpdateSheet()
        dhd("Sheet page " .. tostring(Holodeck.sheetPage))
        return
    end
    local pg = tonumber(arg)
    if pg and pg >= 1 then
        Holodeck.sheetPage = math.floor(pg)
        if Holodeck.savedVars then Holodeck.savedVars.sheetOn = true end
        UpdateSheet()
        dhd("Sheet page " .. tostring(Holodeck.sheetPage))
        return
    end
    if arg == "on" then
        if Holodeck.savedVars then Holodeck.savedVars.sheetOn = true end
        Holodeck.sheetPage = 1
    elseif arg == "off" then
        if Holodeck.savedVars then Holodeck.savedVars.sheetOn = false end
    else
        local cur = sv().sheetOn == true
        if Holodeck.savedVars then Holodeck.savedVars.sheetOn = not cur end
        if Holodeck.savedVars.sheetOn then Holodeck.sheetPage = 1 end
    end
    UpdateSheet()
    UpdateLegend()
    dhd("Path sheet: |cC0E0FF" .. ((sv().sheetOn and "ON") or "OFF") .. "|r  ·  /hd sheet next|prev|off")
end

local function CmdLegend(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if not Holodeck.savedVars then return end
    if arg == "on" then
        Holodeck.savedVars.legendOn = true
    elseif arg == "off" then
        Holodeck.savedVars.legendOn = false
    else
        Holodeck.savedVars.legendOn = not IsLegendOn()
    end
    UpdateLegend()
    dhd("Legend: |cC0E0FF" .. (IsLegendOn() and "ON" or "OFF") .. "|r")
end

local function CmdNames(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if not Holodeck.savedVars then return end
    local mode = Holodeck.NamesMode()
    if arg == "off" then
        mode = "off"
    elseif arg == "all" then
        mode = "all"
    elseif arg == "on" or arg == "important" then
        mode = "important"
    else
        if mode == "off" then mode = "important"
        elseif mode == "important" then mode = "all"
        else mode = "off" end
    end
    Holodeck.savedVars.namesMode = mode
    Holodeck.savedVars.namesOn = (mode ~= "off")
    for _, act in pairs(Holodeck.actors) do
        PlaceActor(act)
    end
    UpdateLegend()
    dhd("Pin names: |cC0E0FF" .. mode .. "|r  ·  /hd names off|important|all")
end

local function PackSpanMeters(fight)
    if type(fight) ~= "table" or type(fight.entities) ~= "table" then return 0 end
    local minX, maxX, minZ, maxZ = 1e9, -1e9, 1e9, -1e9
    local n = 0
    for i = 1, #fight.entities do
        local tr = fight.entities[i] and fight.entities[i].track
        if type(tr) == "table" then
            for j = 1, #tr do
                local x, z = tr[j].x, tr[j].z
                if x and z then
                    n = n + 1
                    if x < minX then minX = x end
                    if x > maxX then maxX = x end
                    if z < minZ then minZ = z end
                    if z > maxZ then maxZ = z end
                end
            end
        end
    end
    if n == 0 then return 0 end
    local dx, dz = maxX - minX, maxZ - minZ
    return math.sqrt(dx * dx + dz * dz)
end

-- Same numbers for the legend and /hd scale. Percent is the effective
-- horizontal scale. House span is the baked diagonal times that scale.
function Holodeck.ScaleReadout()
    local eff = PlayScale()
    local pct = math.floor(eff * 100 + 0.5)
    local span = PackSpanMeters(Holodeck.fight)
    return pct, span, span * eff
end

local function RefreshPlaybackPlacement()
    if Holodeck.origin and Holodeck.fight then
        ApplyTimeline(Holodeck.playT or 0, false)
    elseif Holodeck.origin then
        for _, act in pairs(Holodeck.actors) do
            PlaceActor(act)
        end
    end
    RebuildPathGfx()
    RefreshUI()
end

local function ApplyPlayScale(pct)
    pct = math.floor(tonumber(pct) or 100)
    if pct < 25 then pct = 25 end
    if pct > 400 then pct = 400 end
    if not Holodeck.savedVars then return pct end
    Holodeck.savedVars.playScalePct = pct
    RefreshPlaybackPlacement()
    return pct
end

local function CmdScale(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$") or ""
    if arg == "" or arg == "?" then
        local pct, span, house = Holodeck.ScaleReadout()
        if span > 0 then
            dhd(string.format("Scale %d%%  ·  pack ~%.0fm  ·  in house ~%.0fm  ·  /hd scale 150",
                pct, span, house))
        else
            dhd(string.format("Scale %d%% of baked meters. /hd scale 150   (100 = 1 file unit per meter, 25–400)", pct))
        end
        return
    end
    local n = tonumber(arg)
    if not n then
        dhd("Usage: /hd scale 150   (percent of baked pack, 100 = default)")
        return
    end
    ApplyPlayScale(n)
    local pct, span, house = Holodeck.ScaleReadout()
    if span > 0 then
        dhd(string.format("Scale %d%%  ·  pack ~%.0fm  ·  in house ~%.0fm", pct, span, house))
    else
        dhd(string.format("Scale %d%%", pct))
    end
end

local function CmdFlip(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$") or ""
    local id = Holodeck.loadedId
    if type(id) ~= "string" or id == "" then
        dhd("Load a pack first, then /hd flip z  (mirrors orbit direction)")
        return
    end
    local s = Holodeck.savedVars
    if type(s) ~= "table" then return end
    if type(s.flipXByPack) ~= "table" then s.flipXByPack = {} end
    if type(s.flipZByPack) ~= "table" then s.flipZByPack = {} end
    if arg == "off" or arg == "none" or arg == "reset" then
        s.flipXByPack[id] = nil
        s.flipZByPack[id] = nil
    elseif arg == "x" then
        s.flipXByPack[id] = not s.flipXByPack[id]
    elseif arg == "z" or arg == "" then
        s.flipZByPack[id] = not s.flipZByPack[id]
    elseif arg == "xz" or arg == "zx" or arg == "180" then
        local on = not (s.flipXByPack[id] and s.flipZByPack[id])
        s.flipXByPack[id] = on
        s.flipZByPack[id] = on
    else
        dhd("Usage: /hd flip   or  /hd flip z|x|xz|off   (z = reverse orbit)")
        return
    end
    RefreshPlaybackPlacement()
    local fx, fz = PackFlipXZ()
    local bits = "off"
    if fx and fz then
        bits = "x+z (180)"
    elseif fx then
        bits = "x"
    elseif fz then
        bits = "z"
    end
    dhd("Flip " .. bits .. " for |cC0E0FF" .. id .. "|r  ·  /hd flip z|x|off  ·  /hd rot = 90°")
end

local function CmdRot(arg)
    if not Holodeck.origin then dhd("Plant first: /hd plant") return end
    local step = tonumber(arg)
    if not step then step = 90 end
    local rad = step * math.pi / 180
    Holodeck.origin.yaw = (Holodeck.origin.yaw or 0) + rad
    RefreshPlaybackPlacement()
    dhd(string.format("Rotated %d°. /hd rot  again, or /hd rot -90", step))
end

local function CmdNew()
    ClearStops(false)
    Holodeck.workingName = "sandbox"
    Holodeck.playing = false
    Holodeck.playFinished = false
    Holodeck.playT = 0
    Holodeck.clock = 0
    if Holodeck.origin and Holodeck.Fights["house_demo"] then
        LoadFightTable(Holodeck.Fights["house_demo"], "library", true)
    end
    RebuildPathGfx()
    dhd("New SANDBOX path. Not a saved fight until /hd save <name>.")
    RefreshUI()
end

-- ESO SavedVars often corrupts nested arrays. Prefer FLAT rows (one table per keyframe).
-- Always rebuild dense 1..n via pairs + tonumber.
local function NormalizeKeyframeList(raw)
    if type(raw) ~= "table" then return {} end
    local tmp = {}
    for k, s in pairs(raw) do
        if type(s) == "table" and (s.t ~= nil or s.x ~= nil or s.z ~= nil) then
            local idx = tonumber(k)
            if not idx then idx = #tmp + 1 end
            local x = (s.x ~= nil) and tonumber(s.x) or nil
            local z = (s.z ~= nil) and tonumber(s.z) or nil
            -- Missing coords → plant (0,0) so pins still appear
            if x == nil then x = 0 end
            if z == nil then z = 0 end
            local vis = s.visible
            if vis == nil then vis = true end
            tmp[#tmp + 1] = {
                idx = idx,
                t = tonumber(s.t) or 0,
                x = x, z = z,
                hold = tonumber(s.hold) or 0,
                visible = vis and true or false,
                snap = s.snap == true,
                aspect = NormalizeAspect(s.aspect),
                dead = s.dead == true or s.dead == 1,
            }
        end
    end
    table.sort(tmp, function(a, b) return (a.idx or 0) < (b.idx or 0) end)
    local out = {}
    for i = 1, #tmp do
        local s = tmp[i]
        out[i] = {
            t = s.t, x = s.x, z = s.z,
            hold = s.hold, visible = s.visible, snap = s.snap,
            aspect = s.aspect,
            dead = s.dead == true,
        }
    end
    return out
end

local function SpanFromStops()
    local minX, maxX, minZ, maxZ = 1e9, -1e9, 1e9, -1e9
    local nEnt, nStops = 0, 0
    for _, list in pairs(Holodeck.stops) do
        if list and #list > 0 then
            nEnt = nEnt + 1
            for i = 1, #list do
                local s = list[i]
                nStops = nStops + 1
                local x, z = s.x or 0, s.z or 0
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if z < minZ then minZ = z end
                if z > maxZ then maxZ = z end
            end
        end
    end
    if nStops == 0 then minX, maxX, minZ, maxZ = 0, 0, 0, 0 end
    return nEnt, nStops, minX, maxX, minZ, maxZ
end

local function SerializeStops()
    -- Primary: flat[] = { id, kind, t, x, z, hold, visible, snap }  (SV-safe)
    -- Also write entities[] + stops{} for older tooling / dual recovery
    local flat = {}
    local entities = {}
    local stops = {}
    local types = {}
    local names = {}
    for name in pairs(Holodeck.stops) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local list = Holodeck.stops[name]
        if list and #list > 0 then
            local kind = Holodeck.types[name] or InferType(name)
            types[name] = kind
            local track = {}
            stops[name] = {}
            for i = 1, #list do
                local s = list[i]
                local x = (s.x ~= nil) and tonumber(s.x) or 0
                local z = (s.z ~= nil) and tonumber(s.z) or 0
                local kf = {
                    t = tonumber(s.t) or 0,
                    x = x, z = z,
                    hold = tonumber(s.hold) or 0,
                    visible = (s.visible ~= false),
                    snap = s.snap == true,
                    aspect = NormalizeAspect(s.aspect),
                    dead = s.dead == true or s.dead == 1,
                }
                track[i] = kf
                stops[name][i] = {
                    t = kf.t, x = kf.x, z = kf.z,
                    hold = kf.hold, visible = kf.visible, snap = kf.snap,
                    aspect = kf.aspect,
                    dead = kf.dead,
                }
                flat[#flat + 1] = {
                    id = name,
                    kind = kind,
                    t = kf.t, x = kf.x, z = kf.z,
                    hold = kf.hold,
                    visible = kf.visible and 1 or 0, -- number survives SV better than bool
                    snap = kf.snap and 1 or 0,
                    aspect = kf.aspect,
                    dead = kf.dead and 1 or 0,
                }
            end
            entities[#entities + 1] = {
                id = name,
                kind = kind,
                label = name,
                track = track,
            }
        end
    end
    return {
        name = Holodeck.workingName,
        version = Holodeck.version,
        format = 2, -- flat primary
        flat = flat,
        entities = entities,
        stops = stops,
        types = types,
        nFlat = #flat,
        nEnt = #entities,
    }
end

local function IngestFlatRows(flat)
    Holodeck.stops = {}
    Holodeck.types = {}
    if type(flat) ~= "table" then return 0, 0, 0, 0, 0, 0 end
    -- Group rows by id (order preserved via sort by t)
    local byId = {}
    local order = {}
    for _, row in pairs(flat) do
        if type(row) == "table" and row.id then
            local id = tostring(row.id)
            if not byId[id] then
                byId[id] = {}
                order[#order + 1] = id
            end
            byId[id][#byId[id] + 1] = {
                t = tonumber(row.t) or 0,
                x = tonumber(row.x) or 0,
                z = tonumber(row.z) or 0,
                hold = tonumber(row.hold) or 0,
                visible = not (row.visible == 0 or row.visible == false),
                snap = (row.snap == 1 or row.snap == true),
                kind = row.kind,
            }
        end
    end
    for _, id in ipairs(order) do
        local rows = byId[id]
        table.sort(rows, function(a, b) return (a.t or 0) < (b.t or 0) end)
        local track = {}
        local kind = "stack"
        for i = 1, #rows do
            local r = rows[i]
            if r.kind then kind = NormalizeKind(r.kind) or InferType(id, r.kind) end
            track[i] = {
                t = r.t, x = r.x, z = r.z,
                hold = r.hold, visible = r.visible, snap = r.snap,
            }
        end
        if #track > 0 then
            Holodeck.stops[id] = track
            Holodeck.types[id] = kind or InferType(id)
        end
    end
    return SpanFromStops()
end

local function IngestEntitiesIntoSandbox(entities)
    Holodeck.stops = {}
    Holodeck.types = {}
    if type(entities) ~= "table" then return SpanFromStops() end
    local list = {}
    for k, ent in pairs(entities) do
        if type(ent) == "table" and (ent.id or ent.track or ent.stops) then
            local idx = tonumber(k) or (#list + 1000)
            list[#list + 1] = { idx = idx, ent = ent }
        end
    end
    table.sort(list, function(a, b) return a.idx < b.idx end)
    for _, item in ipairs(list) do
        local ent = item.ent
        local id = tostring(ent.id or ent.name or ("ent_" .. tostring(item.idx)))
        local kind = NormalizeKind(ent.kind) or InferType(id, ent.kind)
        local track = NormalizeKeyframeList(ent.track or ent.stops or ent.keyframes or {})
        if #track > 0 then
            Holodeck.stops[id] = track
            Holodeck.types[id] = kind
        end
    end
    return SpanFromStops()
end

local function IngestLegacyStopsMap(stopsMap, typesMap)
    if type(stopsMap) ~= "table" then return SpanFromStops() end
    for name, rawList in pairs(stopsMap) do
        if type(rawList) == "table" then
            local id = tostring(name)
            if not Holodeck.stops[id] or #(Holodeck.stops[id] or {}) == 0 then
                local track = NormalizeKeyframeList(rawList)
                if #track > 0 then
                    Holodeck.stops[id] = track
                    local tk = typesMap and (typesMap[name] or typesMap[id])
                    Holodeck.types[id] = NormalizeKind(tk) or InferType(id, tk)
                end
            end
        end
    end
    return SpanFromStops()
end

-- House layout scale (meters). Trial boss rooms are often 40–60m+;
-- melee ~7m, ranged often 28–40m — 6m was far too tight for review.

-- Make loaded paths visible near plant without crushing to "living room only".
-- Good takes (sane relative meters): translate so player@t0 is plant, keep spacing.
-- Broken takes (|coords| hundreds of m): self-normalize + ring layout at trial scale.
local function FitStopsForHouseDisplay()
    local names = {}
    for name, list in pairs(Holodeck.stops) do
        if list and #list > 0 then names[#names + 1] = name end
    end
    table.sort(names)
    if #names == 0 then return 0, 0, 0, 0, false, 0 end

    local function diameterOf(lists)
        local minX, maxX, minZ, maxZ = 1e9, -1e9, 1e9, -1e9
        for _, list in pairs(lists) do
            for i = 1, #list do
                local x, z = list[i].x or 0, list[i].z or 0
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if z < minZ then minZ = z end
                if z > maxZ then maxZ = z end
            end
        end
        if minX > 1e8 then return 0 end
        local dx, dz = maxX - minX, maxZ - minZ
        return math.sqrt(dx * dx + dz * dz)
    end

    -- Snapshot raw diameter before any transform
    local rawDiam = diameterOf(Holodeck.stops)

    -- Anchor: player first keyframe → plant (0,0) when possible
    local anchorX, anchorZ = 0, 0
    local pl = Holodeck.stops["player"]
    if pl and pl[1] then
        anchorX, anchorZ = pl[1].x or 0, pl[1].z or 0
    else
        -- centroid of all first keyframes
        local sx, sz, c = 0, 0, 0
        for _, name in ipairs(names) do
            local s0 = Holodeck.stops[name][1]
            sx = sx + (s0.x or 0)
            sz = sz + (s0.z or 0)
            c = c + 1
        end
        if c > 0 then anchorX, anchorZ = sx / c, sz / c end
    end
    for _, name in ipairs(names) do
        local list = Holodeck.stops[name]
        for i = 1, #list do
            list[i].x = (list[i].x or 0) - anchorX
            list[i].z = (list[i].z or 0) - anchorZ
        end
    end

    local diam = diameterOf(Holodeck.stops)
    local fitted = false

    if diam > CFG.HOUSE_OK_DIAMETER_M then
        -- Garbage / wrong-origin take: rebuild at trial-like scale
        fitted = true
        local ring = {}
        local ri = 0
        for _, name in ipairs(names) do
            if name ~= "player" then
                ri = ri + 1
                ring[name] = ri
            end
        end
        local nRing = math.max(ri, 1)

        for _, name in ipairs(names) do
            local list = Holodeck.stops[name]
            local x0, z0 = list[1].x or 0, list[1].z or 0
            for i = 1, #list do
                list[i].x = (list[i].x or 0) - x0
                list[i].z = (list[i].z or 0) - z0
            end
            local entExt = 0
            for i = 1, #list do
                local e = math.sqrt((list[i].x or 0)^2 + (list[i].z or 0)^2)
                if e > entExt then entExt = e end
            end
            if entExt > CFG.HOUSE_ENTITY_PATH_MAX_M then
                local sc = CFG.HOUSE_ENTITY_PATH_MAX_M / entExt
                for i = 1, #list do
                    list[i].x = (list[i].x or 0) * sc
                    list[i].z = (list[i].z or 0) * sc
                end
            end
            local bx, bz = 0, 0
            if name ~= "player" and ring[name] then
                local ang = (ring[name] - 1) / nRing * math.pi * 2
                bx = CFG.HOUSE_RING_RADIUS_M * math.cos(ang)
                bz = CFG.HOUSE_RING_RADIUS_M * math.sin(ang)
            end
            for i = 1, #list do
                list[i].x = (list[i].x or 0) + bx
                list[i].z = (list[i].z or 0) + bz
            end
        end
    elseif diam > CFG.HOUSE_TARGET_DIAMETER_M then
        -- Large but plausible room: scale whole formation to ~50m diameter
        fitted = true
        local sc = CFG.HOUSE_TARGET_DIAMETER_M / diam
        for _, name in ipairs(names) do
            local list = Holodeck.stops[name]
            for i = 1, #list do
                list[i].x = (list[i].x or 0) * sc
                list[i].z = (list[i].z or 0) * sc
            end
        end
    end
    -- else: diam already in a good range — player@plant, keep relative layout

    local _, _, minX, maxX, minZ, maxZ = SpanFromStops()
    return minX, maxX, minZ, maxZ, fitted, rawDiam
end

local function LoadSerialized(data, name)
    DestroyAllActors()
    ClearPathGfx()
    Holodeck.stops = {}
    Holodeck.types = {}
    if Holodeck.fight then CompactFight(Holodeck.fight) end
    Holodeck.fight = nil
    Holodeck.fightSource = nil
    Holodeck.loadedId = nil

    if type(data) ~= "table" then
        dhd("|cFF5555Open failed|r — save data missing.")
        return false
    end

    -- Diagnostic: what fields exist on the save blob
    local hasFlat = type(data.flat) == "table"
    local hasEnt = type(data.entities) == "table"
    local hasStops = type(data.stops) == "table"
    local flatN, entN = 0, 0
    if hasFlat then for _ in pairs(data.flat) do flatN = flatN + 1 end end
    if hasEnt then for _ in pairs(data.entities) do entN = entN + 1 end end

    local nEnt, nStops, minX, maxX, minZ, maxZ = 0, 0, 0, 0, 0, 0

    -- 1) Flat rows (most SV-safe)
    if hasFlat and flatN > 0 then
        nEnt, nStops, minX, maxX, minZ, maxZ = IngestFlatRows(data.flat)
    end
    -- 2) entities[]
    if nStops == 0 and hasEnt and entN > 0 then
        nEnt, nStops, minX, maxX, minZ, maxZ = IngestEntitiesIntoSandbox(data.entities)
    end
    -- 3) legacy stops{}
    if nStops == 0 and hasStops then
        Holodeck.stops = {}
        Holodeck.types = {}
        nEnt, nStops, minX, maxX, minZ, maxZ = IngestLegacyStopsMap(data.stops, data.types)
    end

    if nStops == 0 then
        dhd("|cFF5555Open failed|r — no keyframes in save.")
        dhd(string.format("  blob: flat=%s(%d) entities=%s(%d) stops=%s nFlatMeta=%s",
            tostring(hasFlat), flatN, tostring(hasEnt), entN, tostring(hasStops),
            tostring(data.nFlat)))
        dhd("  Fix: re-record, then /hd save test1  (auto-save alone may be empty on old builds)")
        return false
    end

    -- Always fit near plant for house (handles ~900m trial garbage coords)
    local fitted, rawExtent
    minX, maxX, minZ, maxZ, fitted, rawExtent = FitStopsForHouseDisplay()
    nEnt, nStops, minX, maxX, minZ, maxZ = SpanFromStops()

    Holodeck.workingName = name or data.name or "sandbox"
    Holodeck.clock = PathEndTime()
    Holodeck.playT = 0
    Holodeck.playFinished = false
    Holodeck.playing = false

    if not Holodeck.origin then
        dhd("Plant first: |cC0E0FF/hd plant|r then open again — need coord zero.")
        -- Keep stops loaded so plant → open isn't required twice if they plant next
        dhd(string.format("  (loaded %d tracks / %d stops into memory — plant then /hd open last)", nEnt, nStops))
        return false
    end

    PreferPlayFight()
    RebuildPathGfx()
    ApplyTimeline(0, false)
    _StartTick()

    local nPins, nFail = PlaceAllSandboxPins()

    -- Delayed place (HUD / world space ready)
    zo_callLater(function()
        if not Holodeck.origin or not HasSandboxStops() then return end
        PreferPlayFight()
        ApplyTimeline(0, false)
        RebuildPathGfx()
        local n2 = PlaceAllSandboxPins()
        if n2 > nPins then
            dhd(string.format("Pins ready: %d (near yellow origin)", n2))
        end
    end, 150)
    zo_callLater(function()
        if Holodeck.origin and HasSandboxStops() then
            ApplyTimeline(0, false)
            PlaceAllSandboxPins()
        end
    end, 500)

    -- List first few entities so user can verify
    local shown = 0
    for id, list in pairs(Holodeck.stops) do
        if list and list[1] and shown < 4 then
            d(string.format("  · %s [%s] n=%d @ (%.1f, %.1f)",
                id, tostring(Holodeck.types[id] or "?"), #list,
                list[1].x or 0, list[1].z or 0))
            shown = shown + 1
        end
    end

    dhd(string.format("Opened |cC0E0FF%d|r tracks · %d stops · %d pins · clock=%.1fs",
        nEnt, nStops, nPins, Holodeck.clock or 0))
    dhd(string.format("  house-fit span x=[%.1f..%.1f] z=[%.1f..%.1f]%s",
        minX, maxX, minZ, maxZ,
        fitted and string.format(" (raw ~%.0fm → trial-scale near plant)", rawExtent or 0) or " (relative layout kept)"))
    if nFail > 0 then
        dhd("|cFF5555Pin create failed|r for " .. tostring(nFail) .. " tracks")
    end
    if nPins == 0 then
        dhd("|cFF5555No pins|r — /hd sheet on · try /hd load house_demo to confirm plant")
    else
        dhd("/hd play  ·  |cC0E0FFstand at yellow origin|r — pins in ~50m arena (not 6m)")
    end
    -- Rewrite save in flat format so next open is reliable
    if name and Holodeck.savedVars and Holodeck.savedVars.saves and nStops > 0 then
        local prev = Holodeck.savedVars.saves[name]
        local fresh = SerializeStops()
        fresh.name = name
        fresh.displayName = (prev and prev.displayName) or name
        fresh.meta = (prev and prev.meta) or { duration = Holodeck.clock, savedAt = GetTimeStamp and GetTimeStamp() }
        Holodeck.savedVars.saves[name] = fresh
        Holodeck.savedVars.lastSaveName = name
    end
    return true
end

local function CmdSave(arg)
    local name = (arg or ""):match("^(%S+)")
    if not name then
        dhd("Usage: /hd save <name>  — keep current path in SavedVars")
        return
    end
    if not HasSandboxStops() then dhd("No stops to save.") return end
    name = string.lower(name)
    if not Holodeck.savedVars.saves then Holodeck.savedVars.saves = {} end
    local data = SerializeStops()
    data.name = name
    local nEnt = data.nEnt or 0
    local nFlat = data.nFlat or 0
    data.displayName = data.displayName or string.format("%s · %d tracks · %.0fs",
        name, nEnt, tonumber(Holodeck.clock) or PathEndTime() or 0)
    data.meta = data.meta or {
        duration = PathEndTime(),
        savedAt = GetTimeStamp and GetTimeStamp() or GetFrameTimeMilliseconds(),
    }
    Holodeck.savedVars.saves[name] = data
    Holodeck.savedVars.lastSaveName = name
    Holodeck.workingName = name
    dhd(string.format("Saved |cC0E0FF%s|r · %d tracks · %d keyframes", name, nEnt, nFlat))
    dhd("  " .. tostring(data.displayName))
    dhd("  /hd open last  ·  /hd open 1  ·  /hd saves")
    if nFlat == 0 then
        dhd("|cFF5555WARNING|r 0 keyframes written — nothing will play back")
    end
    RefreshUI()
end

local function BuildSavesArray()
    local s = Holodeck.savedVars and Holodeck.savedVars.saves or {}
    local arr = {}
    for name, data in pairs(s) do
        local meta = type(data) == "table" and data.meta
        local dn = type(data) == "table" and data.displayName
        arr[#arr + 1] = {
            name = name,
            display = dn,
            sort = (meta and meta.savedAt) or 0,
            dur = meta and meta.duration,
            zone = meta and meta.zone,
            target = meta and meta.target,
            dense = meta and meta.dense,
        }
    end
    table.sort(arr, function(a, b) return (a.sort or 0) > (b.sort or 0) end)
    return arr
end

-- Always refresh numbered list so /hd open 1 works without panel first.
local function RefreshSavesList()
    local arr = BuildSavesArray()
    Holodeck.savesList = {}
    for i = 1, #arr do
        Holodeck.savesList[i] = arr[i].name
    end
    return arr
end

local function ResolveSaveName(query)
    query = tostring(query or ""):lower():match("^%s*(.-)%s*$") or ""
    if query == "" then return nil, "empty" end

    local saves = Holodeck.savedVars and Holodeck.savedVars.saves or {}
    local arr = RefreshSavesList()

    if query == "last" then
        local last = Holodeck.savedVars and Holodeck.savedVars.lastSaveName
        if last and saves[last] then return last end
        if last and saves[string.lower(last)] then return string.lower(last) end
        -- Fallback: newest by savedAt
        if arr[1] then return arr[1].name end
        return nil, "no last save"
    end

    -- Exact key
    if saves[query] then return query end

    -- Index: /hd open 1
    local idx = tonumber(query)
    if idx and Holodeck.savesList[idx] then
        return Holodeck.savesList[idx]
    end

    -- Fuzzy: displayName / zone / target / partial id
    local hits = {}
    for _, e in ipairs(arr) do
        local id = string.lower(tostring(e.name or ""))
        local dn = string.lower(tostring(e.display or ""))
        local zone = string.lower(tostring(e.zone or ""))
        local tgt = string.lower(tostring(e.target or ""))
        if id == query or dn == query then
            return e.name
        end
        if id:find(query, 1, true) or dn:find(query, 1, true)
            or zone:find(query, 1, true) or tgt:find(query, 1, true) then
            hits[#hits + 1] = e
        end
    end
    if #hits == 1 then return hits[1].name end
    if #hits > 1 then
        dhd("Multiple saves match |cC0E0FF" .. query .. "|r — use number:")
        for i = 1, math.min(8, #hits) do
            local e = hits[i]
            -- find index in full list
            local n = 0
            for j = 1, #arr do if arr[j].name == e.name then n = j break end end
            d(string.format("  %d  %s", n > 0 and n or i, e.display or e.name))
        end
        return nil, "ambiguous"
    end
    return nil, "not found"
end

local function CmdOpen(arg)
    local raw = (arg or ""):match("^(%S+)")
    if not raw then
        dhd("Usage: /hd open <#>|last|<id>  — YOUR saves (not library). /hd saves")
        dhd("  Example: /hd open 1   ·  /hd open last   ·  /hd open ossair")
        return
    end
    local name, err = ResolveSaveName(raw)
    if not name then
        if err == "ambiguous" then return end
        dhd("No save for |cC0E0FF" .. tostring(raw) .. "|r  ·  /hd saves  (use the number on the left)")
        return
    end
    local data = Holodeck.savedVars.saves[name]
    if not data then dhd("Save missing data for " .. name) return end
    if not Holodeck.origin then
        dhd("Plant origin first: |cC0E0FF/hd plant|r  then  |cC0E0FF/hd open " .. name .. "|r")
        return
    end
    if Holodeck.savedVars then Holodeck.savedVars.lastSaveName = name end
    local dn = data.displayName or name
    dhd("Opening |cC0E0FF" .. tostring(raw) .. "|r → " .. name)
    if dn and dn ~= name then d("  " .. tostring(dn)) end
    local ok = LoadSerialized(data, name)
    if not ok then
        dhd("Open aborted.")
    end
    RefreshUI()
end

Holodeck.libraryList = Holodeck.libraryList or {} -- ordered ids for /hd load 1..n
Holodeck.listFilter = nil -- trial/boss substring; /hd list vMoL
Holodeck.savesPanel = nil
Holodeck.savesPanelLabel = nil

local function CountPackKinds(fight)
    local nBoss, nMini, nPlayer = 0, 0, 0
    local ents = fight and fight.entities
    if type(ents) ~= "table" then return 0, 0, 0 end
    for i = 1, #ents do
        local k = NormalizeKind(ents[i] and ents[i].kind)
        if k == "boss" then
            nBoss = nBoss + 1
        elseif k == "mini" or k == "trash" then
            nMini = nMini + 1
        elseif k == "tank" or k == "healer" or k == "dps" then
            nPlayer = nPlayer + 1
        end
    end
    return nBoss, nMini, nPlayer
end

local function BuildLibraryArray()
    local arr = {}
    for id, f in pairs(Holodeck.Fights) do
        if type(f) == "table" then
            local nb, nm, np = CountPackKinds(f)
            arr[#arr + 1] = {
                id = tostring(f.id or id),
                name = f.name or tostring(f.id or id),
                trial = f.trial or "",
                boss = f.boss or "",
                variant = f.variant or "",
                outcome = f.outcome or "",
                dur = tonumber(f.durationSec) or 0,
                nBoss = nb,
                nMini = nm,
                nPlayer = np,
            }
        end
    end
    table.sort(arr, function(a, b)
        if a.trial ~= b.trial then return a.trial < b.trial end
        if a.boss ~= b.boss then return a.boss < b.boss end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return arr
end

local function RefreshLibraryList()
    local arr = BuildLibraryArray()
    Holodeck.libraryList = {}
    for i = 1, #arr do
        Holodeck.libraryList[i] = arr[i].id
    end
    return arr
end


local function TrialKey(e)
    local t = e and e.trial
    if type(t) ~= "string" or t == "" then return "Demo" end
    return t
end

local function FormatFightDur(sec)
    sec = tonumber(sec) or 0
    if sec <= 0 then return "" end
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60 + 0.5)
    if s >= 60 then
        m = m + 1
        s = 0
    end
    if m <= 0 then return string.format("%ds", s) end
    return string.format("%d:%02d", m, s)
end

local function PackMatchesFilter(e, filter)
    if type(filter) ~= "string" or filter == "" then return true end
    local q = string.lower(filter)
    if string.lower(TrialKey(e)):find(q, 1, true) then return true end
    if string.lower(tostring(e.boss or "")):find(q, 1, true) then return true end
    if string.lower(tostring(e.id or "")):find(q, 1, true) then return true end
    return false
end

local function LibraryPanelText()
    local arr = RefreshLibraryList()
    local filter = Holodeck.listFilter
    local loaded = Holodeck.loadedId or ""

    local filtered = {}
    for i = 1, #arr do
        if PackMatchesFilter(arr[i], filter) then
            filtered[#filtered + 1] = i
        end
    end

    local trials, trialOrder = {}, {}
    for i = 1, #arr do
        local k = TrialKey(arr[i])
        if not trials[k] then
            trials[k] = 0
            trialOrder[#trialOrder + 1] = k
        end
        trials[k] = trials[k] + 1
    end

    local showTrials = (not filter or filter == "") and #trialOrder >= 2 and #arr > CFG.TRIAL_INDEX_AT
    if showTrials then
        local lines = {
            "|cAADDFFFIGHT LIBRARY|r",
            "Pick a trial (keeps /hd load N numbers)",
            "|cC0E0FF/hd list vMoL|r  ·  /hd list all  ·  off",
            "",
        }
        for i = 1, #trialOrder do
            local k = trialOrder[i]
            lines[#lines + 1] = string.format("  |cC0E0FF%-10s|r  %d pack%s",
                k, trials[k], trials[k] == 1 and "" or "s")
        end
        return table.concat(lines, "\n")
    end

    local pages = math.max(1, math.ceil(#filtered / CFG.LIBS_PER_PAGE))
    local page = tonumber(Holodeck.savesPage) or 1
    if page < 1 then page = 1 end
    if page > pages then page = pages end
    Holodeck.savesPage = page

    local lines = {
        "|cAADDFFFIGHT LIBRARY|r",
        string.format("Page %d/%d  ·  |cC0E0FF/hd load N|r  ·  list next|prev|off", page, pages),
    }
    if filter and filter ~= "" then
        lines[#lines + 1] = "Filter |cC0E0FF" .. tostring(filter) .. "|r  ·  /hd list all"
    else
        lines[#lines + 1] = "Filter: |cC0E0FF/hd list vMoL|r"
    end
    lines[#lines + 1] = ""

    if #filtered == 0 then
        lines[#lines + 1] = "(no packs — check fights/*.lua in the manifest)"
    else
        local i0 = (page - 1) * CFG.LIBS_PER_PAGE + 1
        local i1 = math.min(#filtered, page * CFG.LIBS_PER_PAGE)
        local lastTrial = nil
        for n = i0, i1 do
            local gi = filtered[n]
            local e = arr[gi]
            local tk = TrialKey(e)
            if tk ~= lastTrial then
                lastTrial = tk
                lines[#lines + 1] = "|c88AACC" .. tk .. "|r"
            end
            local mark = (e.id == loaded) and " |c55FF88[loaded]|r" or ""
            local ply = (e.nPlayer or 0) > 0 and " |cFFAA66players|r" or ""
            local dur = FormatFightDur(e.dur)
            if dur ~= "" then dur = " |cC0E0FF" .. dur .. "|r" end
            local short = e.name or e.id
            if tk ~= "Demo" and type(short) == "string" then
                local pfx = tk .. " · "
                if short:sub(1, #pfx) == pfx then short = short:sub(#pfx + 1) end
            end
            lines[#lines + 1] = string.format("|cFFFFFF%2d|r  ·%s  %s%s%s", gi, dur, short, ply, mark)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Then |cC0E0FF/hd play|r"
    return table.concat(lines, "\n")
end

local function EnsureSavesPanel()
    if Holodeck.savesPanel and Holodeck.savesPanelLabel then return end
    local tlw = _SafeCreateTLW("HolodeckSavesPanel")
    if not tlw then return end
    tlw:SetMouseEnabled(true)
    tlw:SetMovable(true)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(410000)
    if tlw.SetTopmost then pcall(function() tlw:SetTopmost(true) end) end
    tlw:SetDimensions(400, 520)
    tlw:ClearAnchors()
    local lx, ly = sv().listX, sv().listY
    if type(lx) == "number" and type(ly) == "number" then
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, lx, ly)
    else
        -- Left side: room stays visible in the middle; legend is top-right.
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 16, 72)
    end
    if tlw.SetHandler then
        pcall(function()
            tlw:SetHandler("OnMoveStop", function()
                local s = sv()
                if type(s) ~= "table" then return end
                s.listX = math.floor((tlw.GetLeft and tlw:GetLeft()) or 16)
                s.listY = math.floor((tlw.GetTop and tlw:GetTop()) or 72)
            end)
        end)
    end

    local back = _SafeCreateControl("HolodeckSavesPanelBack", tlw, CT_BACKDROP)
    if back then
        back:SetAnchorFill()
        back:SetCenterColor(0, 0, 0, 0.90)
        back:SetEdgeColor(0.45, 0.75, 1, 0.95)
        if back.SetEdgeTexture then pcall(function() back:SetEdgeTexture(nil, 1, 1, 2) end) end
    end

    local lbl = _SafeCreateControl("HolodeckSavesPanelLabel", tlw, CT_LABEL)
    if lbl then
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, tlw, TOPLEFT, 14, 10)
        lbl:SetDimensions(372, 500)
        lbl:SetFont(HudFont(16))
        lbl:SetColor(0.95, 0.97, 1, 1)
        if TEXT_ALIGN_LEFT then lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if TEXT_ALIGN_TOP then lbl:SetVerticalAlignment(TEXT_ALIGN_TOP) end
        if lbl.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
            pcall(function() lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end)
        end
        lbl:SetMouseEnabled(false)
    end
    Holodeck.savesPanel = tlw
    Holodeck.savesPanelLabel = lbl
    tlw:SetHidden(true)
end

local function ShowSavesPanel(show)
    EnsureSavesPanel()
    if not Holodeck.savesPanel then return end
    if show then
        if Holodeck.savesPanelLabel then
            Holodeck.savesPanelLabel:SetText(LibraryPanelText())
            Holodeck.savesPanelLabel:SetDimensions(372, 500)
        end
        Holodeck.savesPanel:SetHidden(false)
        Holodeck.savesPanel:SetAlpha(1)
        zo_callLater(function()
            if Holodeck.savesPanel and not Holodeck.savesPanel:IsHidden() then
                Holodeck.savesPanel:SetHidden(false)
            end
        end, 50)
    else
        Holodeck.savesPanel:SetHidden(true)
    end
end

Holodeck.ShowSavesPanel = ShowSavesPanel

local function CmdList(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "off" or arg == "close" or arg == "hide" then
        ShowSavesPanel(false)
        dhd("Library closed.")
        return
    end
    if arg == "next" or arg == "+" or arg == "n" then
        Holodeck.savesPage = (Holodeck.savesPage or 1) + 1
        ShowSavesPanel(true)
        dhd("Library page " .. tostring(Holodeck.savesPage))
        return
    end
    if arg == "prev" or arg == "-" or arg == "p" or arg == "back" then
        Holodeck.savesPage = math.max(1, (Holodeck.savesPage or 1) - 1)
        ShowSavesPanel(true)
        dhd("Library page " .. tostring(Holodeck.savesPage))
        return
    end
    if arg == "all" or arg == "*" then
        Holodeck.listFilter = nil
        Holodeck.savesPage = 1
        ShowSavesPanel(true)
        dhd("Library — all trials")
        return
    end
    if arg == "chat" then
        local arr = RefreshLibraryList()
        dhd("Library — /hd load N  or  /hd load <id>")
        for i = 1, #arr do
            d(string.format("  %d  %s  (%s)", i, arr[i].name, arr[i].id))
        end
        return
    end
    if arg ~= "" then
        Holodeck.listFilter = arg
        Holodeck.savesPage = 1
        ShowSavesPanel(true)
        dhd("Library filter |cC0E0FF" .. arg .. "|r  ·  /hd list all")
        return
    end
    Holodeck.savesPage = Holodeck.savesPage or 1
    ShowSavesPanel(true)
    dhd("Library — /hd load N  ·  /hd list vMoL  ·  next|prev|off")
end

-- ============================= Texture palette panel ====================
Holodeck.texPanel = nil
Holodeck.texPanelLabel = nil

local function TexturesPanelText()
    local lines = {
        "TEXTURE KINDS  v" .. Holodeck.version,
        "/hd type <name> <kind>  ·  close: /hd textures off",
        "--------------------------------",
    }
    local groups = {
        { key = "enemy", title = "ENEMIES" },
        { key = "role", title = "ROLES (manual / future team)" },
        { key = "spot", title = "SPOTS" },
        { key = "system", title = "SYSTEM" },
    }
    for _, g in ipairs(groups) do
        lines[#lines + 1] = g.title
        for _, k in ipairs(KIND_ORDER) do
            local def = KIND[k]
            if def and def.group == g.key then
                local c = def.color or { 1, 1, 1 }
                local col = string.format("|c%02X%02X%02X",
                    math.floor((c[1] or 1) * 255),
                    math.floor((c[2] or 1) * 255),
                    math.floor((c[3] or 1) * 255))
                lines[#lines + 1] = string.format(" %s●|r %-7s %s", col, k, def.label or k)
            end
        end
    end
    lines[#lines + 1] = "--------------------------------"
    lines[#lines + 1] = "Demo: /hd load house_demo · play"
    lines[#lines + 1] = "Soft-aim reticle samples elites (no hard-lock)."
    return table.concat(lines, "\n")
end

local function EnsureTexturesPanel()
    if Holodeck.texPanel and Holodeck.texPanelLabel then return end
    local tlw = _SafeCreateTLW("HolodeckTexturesPanel")
    if not tlw then return end
    tlw:SetMouseEnabled(true)
    tlw:SetMovable(true)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(411000)
    if tlw.SetTopmost then pcall(function() tlw:SetTopmost(true) end) end
    tlw:SetDimensions(520, 460)
    tlw:ClearAnchors()
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, 40, -30)

    local back = _SafeCreateControl("HolodeckTexturesPanelBack", tlw, CT_BACKDROP)
    if back then
        back:SetAnchorFill()
        back:SetCenterColor(0, 0, 0, 0.94)
        back:SetEdgeColor(0.95, 0.65, 0.25, 0.95)
        if back.SetEdgeTexture then pcall(function() back:SetEdgeTexture(nil, 1, 1, 2) end) end
    end

    local lbl = _SafeCreateControl("HolodeckTexturesPanelLabel", tlw, CT_LABEL)
    if lbl then
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, tlw, TOPLEFT, 16, 14)
        lbl:SetDimensions(488, 430)
        lbl:SetFont("EsoUI/Common/Fonts/univers57.otf|15|soft-shadow-thin")
        lbl:SetColor(0.95, 0.97, 1, 1)
        if TEXT_ALIGN_LEFT then lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if TEXT_ALIGN_TOP then lbl:SetVerticalAlignment(TEXT_ALIGN_TOP) end
        lbl:SetMouseEnabled(false)
    end
    Holodeck.texPanel = tlw
    Holodeck.texPanelLabel = lbl
    tlw:SetHidden(true)
end

local function ShowTexturesPanel(show)
    EnsureTexturesPanel()
    if not Holodeck.texPanel then return end
    if show then
        if Holodeck.texPanelLabel then
            Holodeck.texPanelLabel:SetText(TexturesPanelText())
        end
        Holodeck.texPanel:SetHidden(false)
        Holodeck.texPanel:SetAlpha(1)
    else
        Holodeck.texPanel:SetHidden(true)
    end
end
Holodeck.ShowTexturesPanel = ShowTexturesPanel

local function CmdTextures(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "off" or arg == "close" or arg == "hide" then
        ShowTexturesPanel(false)
        dhd("Texture palette closed.")
        return
    end
    if arg == "chat" then
        dhd("Kinds:")
        for _, k in ipairs(KIND_ORDER) do
            local def = KIND[k]
            if def then
                d(string.format("  %-8s  %-10s  %s", k, def.group or "?", def.label or k))
            end
        end
        return
    end
    ShowTexturesPanel(true)
    dhd("Texture palette open — /hd textures off to close · /hd type name kind")
end

local function CmdExport()
    if not HasSandboxStops() then
        dhd("No stops. Build with /hd stopadd first.")
        return
    end
    local lines = {
        string.format("-- Holodeck export '%s' v%s", Holodeck.workingName or "sandbox", Holodeck.version),
        "-- Paste into fights/<name>.lua offline. Holds are authoring hints; convert to keyframes as needed.",
        "entities = {",
    }
    local names = {}
    for n in pairs(Holodeck.stops) do names[#names + 1] = n end
    table.sort(names)
    for _, name in ipairs(names) do
        local typ = Holodeck.types[name] or InferType(name)
        typ = NormalizeKind(typ) or typ
        -- Prefer canonical kinds (mini not miniboss); packs still accept miniboss alias
        local kindOut = typ
        lines[#lines + 1] = string.format('  { id = "%s", kind = "%s", label = "%s", track = {', name, kindOut, name)
        local list = Holodeck.stops[name]
        for i = 1, #list do
            local s = list[i]
            if s.visible == false then
                lines[#lines + 1] = string.format("    { t = %s, visible = false },", tostring(round2(s.t)))
            else
                lines[#lines + 1] = string.format(
                    "    { t = %s, x = %s, z = %s, hold = %s, visible = true },",
                    tostring(round2(s.t)), tostring(round2(s.x)), tostring(round2(s.z)), tostring(round2(s.hold or 0)))
            end
            -- emit leave keyframe for hold (so library packs without hold still pause-ish)
            if (s.hold or 0) > 0 and s.visible ~= false then
                lines[#lines + 1] = string.format(
                    "    { t = %s, x = %s, z = %s, visible = true },  -- end hold",
                    tostring(round2((s.t or 0) + (s.hold or 0))), tostring(round2(s.x)), tostring(round2(s.z)))
            end
        end
        lines[#lines + 1] = "  } },"
    end
    lines[#lines + 1] = "}"
    local text = table.concat(lines, "\n")
    if Holodeck.savedVars then Holodeck.savedVars.lastExport = text end
    dhd("--- export (also in SavedVars) ---")
    for line in string.gmatch(text .. "\n", "(.-)\n") do d(line) end
    dhd("--- end export ---")
end

local function ResolveLibraryId(raw)
    raw = tostring(raw or ""):match("^%s*(.-)%s*$") or ""
    if raw == "" then return nil end
    RefreshLibraryList()
    local idx = tonumber(raw)
    if idx and raw:match("^%d+$") and Holodeck.libraryList[idx] then
        return Holodeck.libraryList[idx]
    end
    if Holodeck.Fights[raw] then return raw end
    local q = string.lower(raw)
    local hits = {}
    for id, f in pairs(Holodeck.Fights) do
        local fid = string.lower(tostring(id))
        local nm = string.lower(tostring((f and f.name) or ""))
        if fid == q or nm == q then return id end
        if fid:find(q, 1, true) or nm:find(q, 1, true) then
            hits[#hits + 1] = id
        end
    end
    if #hits == 1 then return hits[1] end
    if #hits > 1 then
        dhd("Multiple packs match |cC0E0FF" .. raw .. "|r — use a number from /hd list")
        return nil
    end
    return nil
end

local function CmdLoad(arg)
    local raw = (arg or ""):match("^(%S+)")
    if not raw then
        CmdList("")
        dhd("Usage: /hd load N  or  /hd load <id>")
        return
    end
    if not Holodeck.origin then dhd("Plant first: /hd plant") return end
    local id = ResolveLibraryId(raw)
    if not id then dhd("Unknown pack. /hd list") return end
    local f = Holodeck.Fights[id]
    if not f then dhd("Unknown pack. /hd list") return end
    Holodeck.playing = false
    Holodeck.playFinished = false
    HideMemMeter()
    LoadFightTable(f, "library", true)
    RebuildPathGfx()
    if Holodeck.savesPanel and not Holodeck.savesPanel:IsHidden() then
        ShowSavesPanel(true)
    end
    dhd("Loaded |cC0E0FF" .. id .. "|r  ·  /hd play   ·  wrong size/facing: /hd help")
    if f._frame and f._frame.splitPx then
        dhd("Gold dots = room split (candles). Stand on it, /hd flip z until bosses sit on either side.")
    end
    RefreshUI()
end

local function CmdClear()
    Holodeck.playing = false
    Holodeck.playFinished = false
    if Holodeck.fight then CompactFight(Holodeck.fight) end
    Holodeck.origin = nil
    Holodeck.fight = nil
    Holodeck.loadedId = nil
    Holodeck.fightSource = nil
    Holodeck.workingName = "sandbox"
    ClearStops(true)
    ClearPathGfx()
    DestroyAllActors()
    HideMemMeter()
    HideSwapBanner()
    if Holodeck.HideBossHpBars then Holodeck.HideBossHpBars() end
    _StopTick()
    dhd("Full clear.")
    RefreshUI()
end

local function CmdStatus()
    dhd(string.format("v%s work=%s origin=%s clock=%.1f edit=%s stops=%d playMode=%s playing=%s t=%.1f",
        Holodeck.version, Holodeck.workingName, Holodeck.origin and "yes" or "no",
        Holodeck.clock or 0, Holodeck.editName, CountStops(), Holodeck.playMode,
        tostring(Holodeck.playing), Holodeck.playT or 0))
end

local function CmdHelp(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "off" then
        Holodeck.helpOpen = false
    elseif arg == "on" then
        Holodeck.helpOpen = true
    else
        Holodeck.helpOpen = not Holodeck.helpOpen
    end
    if not IsLegendOn() and Holodeck.helpOpen and Holodeck.savedVars then
        Holodeck.savedVars.legendOn = true
    end
    UpdateLegend()
    if Holodeck.helpOpen then
        dhd("Help is on the legend (top-right). |cC0E0FF/hd help|r again to close.")
    else
        dhd("Help closed.")
    end
end

local function OnSlash(args)
    args = args or ""
    local cmd, rest = args:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    local map = {
        help = function() CmdHelp(rest) end, ["?"] = function() CmdHelp(rest) end,
        plant = CmdPlant, origin = CmdPlant, pin = CmdPlant,
        play = function() CmdPlay(rest) end,
        mode = function() CmdMode(rest) end,
        pause = CmdPause,
        replay = CmdReplay, restart = CmdReplay,
        halt = CmdHalt, stop = CmdHalt,
        legend = function() CmdLegend(rest) end,
        names = function() CmdNames(rest) end,
        name = function() CmdNames(rest) end,
        labels = function() CmdNames(rest) end,
        scale = function() CmdScale(rest) end,
        size = function() CmdScale(rest) end,
        flip = function() CmdFlip(rest) end,
        mirror = function() CmdFlip(rest) end,
        rot = function() CmdRot(rest) end,
        rotate = function() CmdRot(rest) end,
        spin = function() CmdRot(rest) end,
        frame = function() CmdFrame(rest) end,
        alerts = function() CmdAlerts(rest) end,
        alert = function() CmdAlerts(rest) end,
        swap = function() CmdAlerts(rest) end,
        path = function() CmdPath(rest) end,
        textures = function() CmdTextures(rest) end,
        texture = function() CmdTextures(rest) end,
        palette = function() CmdTextures(rest) end,
        kinds = function() CmdTextures(rest) end,
        list = function() CmdList(rest) end,
        packs = function() CmdList(rest) end,
        library = function() CmdList(rest) end,
        saves = function() CmdList(rest) end,
        load = function() CmdLoad(rest) end,
        demo = function() CmdLoad("house_demo") end,
        clear = CmdClear,
        status = CmdStatus, st = CmdStatus,
        settings = function()
            dhd("Open settings: |cC0E0FF/hdsettings|r  (or Esc → Addons → DeadMarker Holodeck)")
            pcall(function()
                if LibAddonMenu2 and LibAddonMenu2.OpenToPanel then
                    LibAddonMenu2:OpenToPanel("HolodeckSettingsPanel")
                end
            end)
        end,
        debug = function()
            if Holodeck.savedVars then
                Holodeck.savedVars.debug = not Holodeck.savedVars.debug
                dhd("debug=" .. tostring(Holodeck.savedVars.debug))
            end
        end,
    }

    if cmd == "" then CmdHelp("") return end
    local fn = map[cmd]
    if fn then
        fn()
    else
        dhd("Unknown: /hd " .. cmd)
        CmdHelp("on")
    end
end

-- ============================= Lifecycle ================================
local function OnAddOnLoaded(_, addonName)
    if addonName ~= Holodeck.name then return end
    EVENT_MANAGER:UnregisterForEvent(Holodeck.name, EVENT_ADD_ON_LOADED)

    Holodeck.savedVars = ZO_SavedVars:NewAccountWide("HolodeckVars", 3, nil, DEFAULTS)
    local s = Holodeck.savedVars
    if s.playMode then Holodeck.playMode = s.playMode end
    if s.bossSizeM then KIND.boss.sizeM = s.bossSizeM end
    if s.legendOn == nil then s.legendOn = true end
    if s.pathOn == nil then s.pathOn = true end
    if s.frameOn == nil then s.frameOn = true end
    if s.namesOn == nil then s.namesOn = true end
    if s.namesMode == nil then
        if s.namesOn == false then s.namesMode = "off" else s.namesMode = "important" end
    end
    if s.playScalePct == nil then s.playScalePct = 100 end
    if type(s.flipXByPack) ~= "table" then s.flipXByPack = {} end
    if type(s.flipZByPack) ~= "table" then s.flipZByPack = {} end
    if s.autoArmInInstances == nil then s.autoArmInInstances = true end
    if s.recordStartMode == nil then s.recordStartMode = "boss" end
    if s.recordAutoStop == nil then s.recordAutoStop = true end
    if s.recordAutoSave == nil then s.recordAutoSave = false end
    if s.recordIntervalMs == nil then s.recordIntervalMs = 400 end
    if s.recordCaptureBosses == nil then s.recordCaptureBosses = true end
    if s.recordCaptureSelf == nil then s.recordCaptureSelf = false end
    if s.recordCaptureTeam == nil then s.recordCaptureTeam = false end
    if s.recordCaptureElites == nil then s.recordCaptureElites = true end
    if s.recordEliteTier == nil then s.recordEliteTier = 4 end
    -- Migrate: old "tier 0 = off" stacked with checkbox; if elites ON, force tier 4
    if tonumber(s.recordEliteTier) == 0 and s.recordCaptureElites ~= false then
        s.recordEliteTier = 4
    end
    if s.recordRequirePlant == nil then s.recordRequirePlant = false end
    if s.shareReceiveEnabled == nil then s.shareReceiveEnabled = true end
    -- Recording/saves are no longer a product path. Drop deserialized takes from SV.
    s.saves = {}

    -- Export helpers for Holodeck_Settings (loaded after this file)
    Holodeck.EnsureOriginMarker = EnsureOriginMarker
    Holodeck.RebuildPathGfx = RebuildPathGfx
    Holodeck.ApplyTimeline = ApplyTimeline
    Holodeck.RefreshUI = RefreshUI
    Holodeck.PreferPlayFight = PreferPlayFight
    Holodeck.SerializeStops = SerializeStops
    Holodeck.ApplySheetVisibility = ApplySheetVisibility

    SLASH_COMMANDS["/hd"] = OnSlash
    SLASH_COMMANDS["/holodeck"] = OnSlash

    EnsureLegend()
    EnsureSheet()
    if Holodeck.sheetTLW then Holodeck.sheetTLW:SetHidden(true) end
    UpdateLegend()
    UpdateSheet()

    pcall(function()
        EVENT_MANAGER:RegisterForEvent(Holodeck.name .. "_LayerPop", EVENT_ACTION_LAYER_POPPED, function()
            -- Always re-assert legend/sheet so OFF stays off after chat
            UpdateLegend()
            if Holodeck.savedVars and Holodeck.savedVars.sheetOn then
                ApplySheetVisibility()
                UpdateSheet()
            elseif Holodeck.sheetTLW then
                Holodeck.sheetTLW:SetHidden(true)
            end
        end)
    end)
    pcall(function()
        if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
            SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
                if newState == SCENE_SHOWN or newState == SCENE_SHOWING then
                    if Holodeck.savedVars and Holodeck.savedVars.sheetOn then
                        zo_callLater(function()
                            ApplySheetVisibility()
                            UpdateSheet()
                        end, 10)
                    end
                end
            end)
        end
    end)

    -- Defer record + LAM until sibling files have loaded
    zo_callLater(function()
        if type(Holodeck.CreateSettingsMenu) == "function" then
            pcall(Holodeck.CreateSettingsMenu)
        end
        UpdateLegend()
    end, 50)

    local n = 0
    for _ in pairs(Holodeck.Fights) do n = n + 1 end
    dhd(string.format("v%s | packs=%d | /hd plant · /hd list · /hd load · /hd play", Holodeck.version, n))
end

EVENT_MANAGER:RegisterForEvent(Holodeck.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

_G.Holodeck = Holodeck
