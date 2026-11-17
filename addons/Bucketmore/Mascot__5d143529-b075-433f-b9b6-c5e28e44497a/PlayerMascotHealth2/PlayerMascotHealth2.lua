-- PlayerMascotHealth2 v2.0.1  (character library)
-- Base: PlayerMascotHealth v1.5.0 (HP state logic, HP events, animation, HUD fragment, preview, NORMAL load protection are carried over unchanged).
-- New in v2: (1) the standard character is built in and always available; (2) more characters ("packs") come from OTHER addons that
-- append a definition to the global table PMH2_PackQueue (no dependency, no load-order requirement); (3) position / size / opacity /
-- HP% / show are stored PER CHARACTER in sv.chars[id]; the selected id is stored in sv.selectedId.
-- Own addon name, own SavedVariables (PlayerMascotHealth2_SV) and own control names: the stable PlayerMascotHealth v1.5.0 is never touched.
-- Turn PlayerMascotHealth v1.5.0 OFF while using this addon (two mascots would overlap).
-- No OnUpdate / no polling. HP is read on EVENT_POWER_UPDATE (player + health only) and a few rare lifecycle events.

local ADDON      = "PlayerMascotHealth2"
local VERSION    = "2.0.1"
local DEBUG      = false      -- true prints "[PMH2]" debug lines (max DEBUG_MAX per session); off in the release
local SV_NAME    = "PlayerMascotHealth2_SV"
local SV_VERSION = 1

local DEFAULT_ID  = "default"                -- built-in standard character (always present, cannot be removed)
local TEX_DIR     = "PlayerMascotHealth2/tex/"
local QUEUE_NAME  = "PMH2_PackQueue"         -- global table that pack addons append their definition to
local PACK_FORMAT = 1
local MAX_PACKS   = 16                       -- definitions read from the queue (the rest are ignored)

local STATES   = { "NORMAL", "CAUTION", "DANGER", "CRITICAL", "ZERO" }
local IS_STATE = {}
for _, s in ipairs(STATES) do IS_STATE[s] = true end
-- Fixed sheet spec (v1.5.0): 1024x512, 4 x 2 cells of 256x256, 8 FPS. Frames left->right, top->bottom, played by ANIMATION_TEXTURE.
local SHEET_COLS, SHEET_ROWS, SHEET_FPS = 4, 2, 8

local ASPECT    = 1                      -- every frame is 256x256 -> width = height
local SIZE_MIN, SIZE_MAX, SIZE_STEP = 128, 768, 8   -- size = displayed HEIGHT in UI px
local ALPHA_MIN, ALPHA_MAX = 20, 100
local NORMAL_MIN, NORMAL_MAX = 20, 95
local CAUTION_MIN, CAUTION_MAX = 10, 90
local DANGER_MIN, DANGER_MAX = 5, 80
local DEFAULT_CONTENT_BOTTOM = 252 / 256 -- fallback when a pack gives no usable contentBottom
local LABEL_GAP, LABEL_H = 2, 40
local FONT_CANDIDATES = { "ZoFontGamepad34", "ZoFontGamepad27", "ZoFontGameBold", "ZoFontGame" }

local RESYNC_MS = 150                    -- single delayed re-read, only when an event value is unusable AND the direct read failed
local GAP       = 5                      -- each boundary must stay at least this far below the one above it

-- global (not per character) settings
local DEFAULTS = {
    selectedId   = DEFAULT_ID,
    normalStart  = 70,   -- HP% >= this              -> NORMAL
    cautionStart = 40,   -- HP% >= this (< normal)   -> CAUTION
    dangerStart  = 20,   -- HP% >= this (< caution)  -> DANGER, below (but HP > 0) -> CRITICAL, HP = 0 -> ZERO
}
-- per character (= per pack id) settings, stored in sv.chars[id]
local CHAR_DEFAULTS = { enabled = true, showPercent = true, x = 20, y = 240, size = 256, alpha = 100 }

-- Power type of the HP resource (v1.3.2+: resolved defensively, 32 is the engine value of health).
local HEALTH_TYPE = POWERTYPE_HEALTH or COMBAT_MECHANIC_FLAGS_HEALTH or 32
local HEALTH_TYPES = { [32] = true }
if type(POWERTYPE_HEALTH) == "number" then HEALTH_TYPES[POWERTYPE_HEALTH] = true end
if type(COMBAT_MECHANIC_FLAGS_HEALTH) == "number" then HEALTH_TYPES[COMBAT_MECHANIC_FLAGS_HEALTH] = true end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local sv, cs                -- saved variables (global) / settings of the character in use
local tlw, tex, label       -- top level window / texture control / HP% label (label may stay nil)
local currentState          -- last computed state
local shownState            -- state whose texture is currently set on the control
local currentPercent        -- last computed HP% (integer 0..100)
local shownPercent          -- HP% currently written into the label
local lastEventMax          -- max HP seen in the previous HP event (detects max-HP changes)
local resyncGen = 0         -- cancels a pending delayed re-read as soon as a newer valid value arrives
local timelines = {}        -- state -> animation timeline (created once, reused by every character: same sheet spec)
local animBroken = {}       -- "<packId>:<state>" -> true when that sheet was given up this session (still image is used)
local onceDone   = {}       -- state -> true once a one-shot sheet (ZERO) reached its last frame; cleared when the state is left
local activeTL              -- timeline that is playing right now (nil = nothing playing)
local shownFile             -- file currently set on the control
local loadedSet = {}        -- files for which the engine reported OnTextureLoaded
local preview = false       -- settings preview (runtime only, never saved; OFF after every login)
local hudFragment           -- scene fragment that hides the mascot in menus (nil if it could not be created)
local forcedState           -- state chosen in the settings preview dropdown (nil = automatic from HP); runtime only
local firstEventSeen = false

-- characters
local packs     = {}        -- id -> pack
local packList  = {}        -- ids in display order (default first)
local charNames = {}        -- dropdown choices (display names, same order as packList)
local nameToId  = {}        -- display name -> id
local badPacks  = {}        -- id -> true when the pack's files never loaded this session (runtime only, never saved)
local curId, curPack = DEFAULT_ID, nil
local packsReady = false
local settingsBuilt = false

local DEBUG_MAX, debugLines = 400, 0
local function Dbg(msg)       -- bounded: never floods the chat
    if not DEBUG then return end
    if debugLines < DEBUG_MAX then
        debugLines = debugLines + 1
        d("[PMH2] " .. msg)
        if debugLines == DEBUG_MAX then d("[PMH2] debug line limit reached") end
    end
end

---------------------------------------------------------------------------
-- Settings sanitising (bad / old / hand-edited values must never raise errors)
---------------------------------------------------------------------------
local function Num(v, lo, hi, fallback)
    if type(v) ~= "number" or v ~= v then return fallback end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Sanitize()                         -- global settings
    if type(sv.selectedId) ~= "string" then sv.selectedId = DEFAULT_ID end
    sv.normalStart = Num(sv.normalStart, NORMAL_MIN, NORMAL_MAX, DEFAULTS.normalStart)
    local cautionMax = math.min(CAUTION_MAX, sv.normalStart - GAP)
    sv.cautionStart = Num(sv.cautionStart, CAUTION_MIN, cautionMax, math.min(DEFAULTS.cautionStart, cautionMax))
    local dangerMax = math.min(DANGER_MAX, sv.cautionStart - GAP)
    sv.dangerStart = Num(sv.dangerStart, DANGER_MIN, dangerMax, math.min(DEFAULTS.dangerStart, dangerMax))
end

-- Settings of ONE character; created on first use and KEPT when its pack is removed (KEEP), so re-installing the same id restores them.
local function CharSettings(id)
    if type(sv.chars) ~= "table" then sv.chars = {} end
    local c = sv.chars[id]
    if type(c) ~= "table" then c = {}; sv.chars[id] = c end
    if type(c.enabled) ~= "boolean" then c.enabled = CHAR_DEFAULTS.enabled end
    if type(c.showPercent) ~= "boolean" then c.showPercent = CHAR_DEFAULTS.showPercent end
    c.x     = Num(c.x, 0, 8000, CHAR_DEFAULTS.x)
    c.y     = Num(c.y, 0, 8000, CHAR_DEFAULTS.y)
    c.size  = Num(c.size, SIZE_MIN, SIZE_MAX, CHAR_DEFAULTS.size)
    c.alpha = Num(c.alpha, ALPHA_MIN, ALPHA_MAX, CHAR_DEFAULTS.alpha)
    return c
end

---------------------------------------------------------------------------
-- One-time import of the v1.5.0 settings (PlayerMascotHealth_SV). The manifest also lists that SavedVariables name, so the game loads it
-- even when v1.5.0 itself is switched off. It is only READ: nothing is written to it. Runs once (sv.importedV1), only on a fresh v2 save.
---------------------------------------------------------------------------
local function FindV1Table(t, depth)              -- the v1.5.0 settings table sits a few levels down (world / account / $AccountWide ...)
    if type(t) ~= "table" or depth > 5 then return nil end
    if type(t.size) == "number" and type(t.x) == "number" and type(t.y) == "number" then return t end
    for _, v in pairs(t) do
        local r = FindV1Table(v, depth + 1)
        if r then return r end
    end
    return nil
end

local function ImportV1()
    if sv.importedV1 then return end
    sv.importedV1 = true                          -- never tried twice, whatever the result
    if sv.chars ~= nil then return end            -- v2 already has its own settings: keep them
    local ok, old = pcall(function() return FindV1Table(_G["PlayerMascotHealth_SV"], 0) end)
    if not ok or type(old) ~= "table" then return end
    local c = CharSettings(DEFAULT_ID)
    if type(old.enabled) == "boolean" then c.enabled = old.enabled end
    if type(old.showPercent) == "boolean" then c.showPercent = old.showPercent end
    c.x, c.y, c.size = old.x, old.y, old.size     -- clamped by CharSettings below
    if type(old.normalStart) == "number" then sv.normalStart = old.normalStart end
    if type(old.cautionStart) == "number" then sv.cautionStart = old.cautionStart end
    if type(old.dangerStart) == "number" then sv.dangerStart = old.dangerStart end
    CharSettings(DEFAULT_ID)
end

---------------------------------------------------------------------------
-- Characters: built-in standard + packs registered by other addons
---------------------------------------------------------------------------
-- cfg per state: type = "ANIMATION" sheet (file) played by ANIMATION_TEXTURE; fallback = still PNG used if the sheet cannot be used;
-- contentBottom = where the visible character ends (fraction of the image height), the HP% text sits below it;
-- once = played one time and held on the last frame (ZERO); fallbackAfter = after this many unanswered load checks (1 s apart)
-- the sheet is given up for this session and the still image is shown (v1.3.6 NORMAL protection).
local function BuiltinCfg(state, sheet, still, cb, fallbackAfter)
    return { type = "ANIMATION", file = TEX_DIR .. sheet, cols = SHEET_COLS, rows = SHEET_ROWS, fps = SHEET_FPS,
             fallback = TEX_DIR .. still, contentBottom = cb, once = (state == "ZERO") or nil, fallbackAfter = fallbackAfter }
end

packs[DEFAULT_ID] = {
    id = DEFAULT_ID, name = "Default", display = "Default (標準)", sortKey = "00",
    cfg = {   -- identical to the v1.5.0 STATE_IMAGE table (only NORMAL has the v1.3.6 fallback protection, as in v1.5.0)
        NORMAL   = BuiltinCfg("NORMAL",   "NORMAL_ANIMATION.dds", "NORMAL.png",   255 / 256, 3),
        CAUTION  = BuiltinCfg("CAUTION",  "CAUTION_SHEET.dds",    "CAUTION.png",  254 / 256),
        DANGER   = BuiltinCfg("DANGER",   "DANGER_SHEET.dds",     "DANGER.png",   252 / 256),
        CRITICAL = BuiltinCfg("CRITICAL", "CRITICAL_SHEET.dds",   "CRITICAL.png", 252 / 256),
        ZERO     = BuiltinCfg("ZERO",     "ZERO_SHEET.dds",       "ZERO.png",     251 / 256),
    },
}
curPack = packs[DEFAULT_ID]

-- A pack definition (a pack addon appends it to the global table PMH2_PackQueue at load time):
--   { format = 1, id = "my_char", name = "Display name", sortKey = "10", dir = "AddonFolder/sub/",
--     states = { NORMAL = { sheet = "x.dds", still = "x.png", contentBottom = 0.99 }, CAUTION = {...}, DANGER = {...}, CRITICAL = {...}, ZERO = {...} } }
-- All 5 states must be declared, otherwise the pack is not registered. Whether the FILES exist cannot be checked from Lua:
-- a missing / broken file is only noticed when it is shown (OnTextureLoaded never arrives, see ScheduleWatch).
local function SafeRel(s)                         -- relative path inside an addon: no "..", no backslash, no drive / absolute path
    return type(s) == "string" and s ~= ""
        and not s:find("..", 1, true) and not s:find("\\", 1, true) and not s:find(":", 1, true) and s:sub(1, 1) ~= "/"
end

local function ValidatePack(def)
    if type(def) ~= "table" then return nil, "not a table" end
    if def.format ~= PACK_FORMAT then return nil, "format" end
    local id = def.id
    if type(id) ~= "string" or #id < 1 or #id > 32 or not id:match("^[%w_]+$") then return nil, "bad id" end
    if id == DEFAULT_ID then return nil, "reserved id" end
    if packs[id] then return nil, "duplicate id" end
    if type(def.name) ~= "string" or def.name == "" or #def.name > 100 then return nil, "bad name" end
    if not SafeRel(def.dir) then return nil, "bad dir" end
    if type(def.states) ~= "table" then return nil, "no states" end
    local dir = def.dir
    if dir:sub(-1) ~= "/" then dir = dir .. "/" end
    local cfg = {}
    for _, st in ipairs(STATES) do
        local e = def.states[st]
        if type(e) ~= "table" then return nil, "missing " .. st end
        if not SafeRel(e.sheet) or not e.sheet:lower():match("%.dds$") then return nil, "sheet " .. st end
        if not SafeRel(e.still) or not e.still:lower():match("%.png$") then return nil, "still " .. st end
        local cb = Num(e.contentBottom, 0.5, 1, DEFAULT_CONTENT_BOTTOM)
        cfg[st] = { type = "ANIMATION", file = dir .. e.sheet, cols = SHEET_COLS, rows = SHEET_ROWS, fps = SHEET_FPS,
                    fallback = dir .. e.still, contentBottom = cb, once = (st == "ZERO") or nil,
                    fallbackAfter = 3 }      -- unproven files: the sheet is given up after 3 unanswered checks (same rule as v1.3.6 NORMAL)
    end
    local sortKey = (type(def.sortKey) == "string" and def.sortKey ~= "") and def.sortKey or def.name
    return { id = id, name = def.name, display = def.name, sortKey = sortKey, cfg = cfg }
end

-- Runs once, at the first EVENT_PLAYER_ACTIVATED (every addon has finished loading by then, so the queue is complete).
local function PackSetup()
    if packsReady then return end
    packsReady = true
    local order = { DEFAULT_ID }
    local q = _G[QUEUE_NAME]
    if type(q) == "table" then
        for i = 1, #q do
            if i > MAX_PACKS then
                d("[PlayerMascotHealth2] more than " .. MAX_PACKS .. " character packs: the rest are ignored")
                break
            end
            local ok, p, why = pcall(ValidatePack, q[i])
            if ok and p then
                packs[p.id] = p
                order[#order + 1] = p.id
            else
                local rid = (type(q[i]) == "table") and tostring(q[i].id) or "?"
                d(("[PlayerMascotHealth2] character pack '%s' not registered: %s"):format(rid, tostring(ok and why or p)))
            end
        end
    end
    table.sort(order, function(a, b)       -- default first, then the pack's sortKey (Japanese names do not sort by reading), then name, then id
        if a == b then return false end
        if a == DEFAULT_ID then return true end
        if b == DEFAULT_ID then return false end
        local pa, pb = packs[a], packs[b]
        if pa.sortKey ~= pb.sortKey then return pa.sortKey < pb.sortKey end
        if pa.name ~= pb.name then return pa.name < pb.name end
        return a < b
    end)
    packList = order
    charNames, nameToId = {}, {}
    for _, id in ipairs(order) do
        local p = packs[id]
        if nameToId[p.display] then p.display = p.display .. " [" .. id .. "]" end   -- dropdown entries must be unique
        nameToId[p.display] = id
        charNames[#charNames + 1] = p.display
    end
end

-- The id that is shown now. Unknown / removed / failed pack -> standard character; the stored selection stays untouched (KEEP).
local function ResolveId()
    local want = sv.selectedId
    if want and packs[want] and not badPacks[want] then return want end
    return DEFAULT_ID
end

local function CfgOf(state) return curPack and curPack.cfg[state] end
local function BK(state) return curId .. ":" .. state end

---------------------------------------------------------------------------
-- HP state (pure calculation, no UI) - unchanged from v1.5.0
---------------------------------------------------------------------------
-- Integer-safe: compares cur*100 with max*threshold, so the boundaries (70 / 40 / 20 by default) are exact.
local function CalcState(cur, max)
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    if cur < 0 then cur = 0 end
    if cur <= 0 then return "ZERO" end                      -- real zero HP: highest priority
    local scaled = cur * 100
    if scaled >= max * sv.normalStart  then return "NORMAL"  end
    if scaled >= max * sv.cautionStart then return "CAUTION" end
    if scaled >= max * sv.dangerStart  then return "DANGER"  end
    return "CRITICAL"                                       -- HP > 0 but below the DANGER boundary
end

-- Integer HP% (rounded down). Only call with values that CalcState already accepted (max > 0).
local function CalcPercent(cur, max)
    if cur < 0 then cur = 0 end
    local pct = math.floor(cur * 100 / max)
    if pct > 100 then pct = 100 end
    return pct
end

---------------------------------------------------------------------------
-- Image switching (v1.5.0 code; the image configuration now comes from the character in use)
---------------------------------------------------------------------------
local SwitchPack                                  -- forward declaration (used by MarkBadAndRevert)

local function StopAnim()
    if activeTL then
        local tl = activeTL
        activeTL = nil                -- detach first: a late OnStop of this timeline is then ignored
        pcall(tl.Stop, tl)
    end
end

local function ResetCoords()          -- full texture (static images)
    pcall(tex.SetTextureCoords, tex, 0, 1, 0, 1)
end

local function HoldLastFrame(cfg)     -- one-shot sheets: keep showing the final cell (never the whole sheet, never blank)
    pcall(tex.SetTextureCoords, tex, (cfg.cols - 1) / cfg.cols, 1, (cfg.rows - 1) / cfg.rows, 1)
end

local function StartAnim(state, cfg)
    if activeTL then return true end
    if cfg.once and onceDone[state] then HoldLastFrame(cfg); return true end   -- already finished: stay on the last frame
    local ok = pcall(function()
        pcall(tex.SetTextureCoords, tex, 0, 1 / cfg.cols, 0, 1 / cfg.rows)   -- first cell, never the whole sheet
        local tl = timelines[state]
        if not tl then
            tl = ANIMATION_MANAGER:CreateTimeline()
            local a = tl:InsertAnimation(ANIMATION_TEXTURE, tex)
            a:SetImageData(cfg.cols, cfg.rows)
            a:SetFramerate(cfg.fps)
            if cfg.once then
                -- play the sheet once; when it completes (and only then) hold the last frame
                if ANIMATION_PLAYBACK_ONE_SHOT then
                    tl:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
                else
                    tl:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, 1)
                end
                tl:SetHandler("OnStop", function(_, completedPlaying)
                    if activeTL ~= tl or completedPlaying == false then return end   -- stopped by us (state / character change), not finished
                    onceDone[state] = true
                    HoldLastFrame(cfg)
                end)
            else
                tl:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
            end
            timelines[state] = tl
        end
        tl:PlayFromStart()
        activeTL = tl
    end)
    return ok
end

local function ShowImage(state, cfg)
    if cfg.type == "ANIMATION" and not animBroken[BK(state)] then
        shownFile = cfg.file
        tex:SetTexture(cfg.file)
        if StartAnim(state, cfg) then return end
        animBroken[BK(state)] = true      -- animation API unusable: never retry, use the still image
        Dbg("animation FAILED for " .. BK(state) .. " -> still image")
    end
    shownFile = (cfg.type == "ANIMATION") and cfg.fallback or cfg.file
    tex:SetTexture(shownFile)
    ResetCoords()
end

-- Re-starts the animation of the shown state (after the control was hidden / re-enabled).
local function EnsurePlayback()
    if not shownState then return end
    local cfg = CfgOf(shownState)
    if not cfg then return end
    if cfg.once and onceDone[shownState] then HoldLastFrame(cfg); return end   -- finished one-shot: keep the last frame
    if activeTL then return end
    if cfg.type == "ANIMATION" and not animBroken[BK(shownState)] then
        if not StartAnim(shownState, cfg) then
            animBroken[BK(shownState)] = true
            ShowImage(shownState, cfg)
        end
    end
end

local function ReapplyImage()
    if not tex or not shownState then return end
    local cfg = CfgOf(shownState)
    if not cfg then return end
    StopAnim()
    ShowImage(shownState, cfg)
end

-- A window that is not shown may never load its texture (engine behaviour), so a load check made while hidden is NOT counted as
-- a failure; OnEffectivelyShown starts the check again once the mascot is visible.
local function IsShownNow()
    if not tlw or not tex then return false end
    local ok1, h1 = pcall(tlw.IsHidden, tlw)
    if ok1 and h1 then return false end
    local ok2, h2 = pcall(tex.IsHidden, tex)
    if ok2 and h2 then return false end
    return true
end

-- Even the still PNG of a pack never loaded: the pack is unusable this session -> standard character. The stored selection and the
-- per-character settings stay (KEEP); the pack is tried again at the next login, or when it is selected again in the settings.
local function MarkBadAndRevert(id, file)
    if id == DEFAULT_ID then return end
    badPacks[id] = true
    d("[PlayerMascotHealth2] character '" .. id .. "' files did not load (" .. tostring(file) .. ") -> standard character")
    SwitchPack(DEFAULT_ID)
end

-- v1.3.3 / v1.3.6: if the engine has not reported the file as loaded after 1 s, the image is set again (max 6 checks, one-shot,
-- at most ONE pending). A sheet that never reports "loaded" is dropped for this session (fallbackAfter) and the still image is used.
local LOAD_CHECK_MS, LOAD_CHECK_MAX = 1000, 6
local watchPending, watchAttempt = false, 1
local ScheduleWatch
function ScheduleWatch()
    watchPending = true
    zo_callLater(function()
        watchPending = false
        if not tex or not shownState or not shownFile or loadedSet[shownFile] then return end   -- loaded, or nothing shown
        if not IsShownNow() then return end                                                     -- hidden: no verdict, no rescheduling
        local cfg = CfgOf(shownState)
        if cfg and cfg.fallbackAfter and cfg.type == "ANIMATION" and not animBroken[BK(shownState)]
           and shownFile == cfg.file and watchAttempt >= cfg.fallbackAfter then
            d("[PlayerMascotHealth2] " .. BK(shownState) .. " animation sheet was not loaded -> showing the still image instead")
            StopAnim()
            timelines[shownState] = nil
            animBroken[BK(shownState)] = true
            ShowImage(shownState, cfg)
            watchAttempt = 1
            ScheduleWatch()                   -- one more bounded check that the still image itself arrives
            return
        end
        if watchAttempt >= LOAD_CHECK_MAX then
            Dbg("texture never reported loaded: " .. tostring(shownFile))
            if curId ~= DEFAULT_ID then MarkBadAndRevert(curId, shownFile) end
            return
        end
        Dbg("texture not loaded yet -> setting it again (" .. watchAttempt .. "): " .. tostring(shownFile))
        if cs and cs.enabled then ReapplyImage() end
        watchAttempt = watchAttempt + 1
        ScheduleWatch()
    end, LOAD_CHECK_MS)
end

local function WatchLoad()            -- called after every image change
    watchAttempt = 1
    if not shownFile or loadedSet[shownFile] then return end        -- already loaded (e.g. returning to a known state)
    if not watchPending then ScheduleWatch() end
end

local function LayoutLabel()          -- HP% text just below the visible character of the current state
    if not label or not tlw or not cs then return end
    local cfg = CfgOf(shownState or currentState or "NORMAL")
    local cb = (cfg and cfg.contentBottom) or DEFAULT_CONTENT_BOTTOM
    local h = cs.size
    label:ClearAnchors()
    label:SetAnchor(TOP, tlw, TOP, 0, math.floor(h * cb) + LABEL_GAP)
    label:SetDimensions(h / ASPECT, LABEL_H)
end

local function ApplyTexture()
    if not tex or not currentState or not packsReady then return end   -- nothing is shown before the characters are known
    if shownState == currentState then return end   -- same state: never reload
    local cfg = CfgOf(currentState)
    if not cfg then return end
    StopAnim()                                      -- nothing of the previous state keeps playing
    onceDone[currentState] = nil                    -- entering a state = its one-shot (ZERO) starts again from frame 1
    shownState = currentState
    Dbg("state -> " .. currentState .. "  file=" .. tostring(cfg.file))
    ShowImage(currentState, cfg)
    LayoutLabel()
    tex:SetHidden(false)          -- first time the control becomes visible = image already set
    WatchLoad()
end

-- Rewrites the label only when the integer HP% really changed.
local function ApplyPercent()
    if not label or currentPercent == nil then return end
    if shownPercent == currentPercent then return end
    shownPercent = currentPercent
    label:SetText(string.format("%d%%", currentPercent))
    label:SetHidden(false)        -- first time visible = text already set
end

local function ApplyLayout()
    if not tlw or not tex or not cs then return end
    local h = cs.size
    local w = h / ASPECT
    local x, y = cs.x, cs.y
    local sw, sh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    if sw and sw > 0 then x = math.min(x, math.max(0, sw - w)) end
    if sh and sh > 0 then y = math.min(y, math.max(0, sh - h)) end
    tlw:ClearAnchors()
    tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    tlw:SetDimensions(w, h)
    pcall(tlw.SetAlpha, tlw, cs.alpha / 100)      -- opacity of the whole mascot (image + HP%)
    if cs.enabled then
        ApplyTexture()
        EnsurePlayback()
    else
        StopAnim()                -- hidden: no animation runs
    end
    tex:SetHidden(not (cs.enabled and shownState ~= nil))

    if label then
        LayoutLabel()
        local want = cs.enabled and cs.showPercent
        if want then ApplyPercent() end
        label:SetHidden(not (want and shownPercent ~= nil))
    end
end

---------------------------------------------------------------------------
-- HP reading - unchanged from v1.5.0 (sv.enabled / sv.showPercent -> cs.enabled / cs.showPercent)
---------------------------------------------------------------------------
local function UpdateState(cur, max)
    local s = CalcState(cur, max)
    if s == nil then return false end   -- HP data not available (yet)
    if forcedState then s = forcedState end      -- the settings preview dropdown overrides the HP state
    if s ~= currentState then
        currentState = s
        if cs.enabled then ApplyTexture() end
    end
    currentPercent = CalcPercent(cur, max)
    if cs.enabled and cs.showPercent then ApplyPercent() end   -- no-op while the integer is unchanged
    return true
end

-- Full re-read: login / zone change / respawn / death / revive (rare events)
local function ReadHealthNow()
    local cur, max, effMax = GetUnitPower("player", HEALTH_TYPE)
    if type(effMax) == "number" and effMax > 0 then max = effMax end
    return UpdateState(cur, max)
end

-- Settings preview: show one state on purpose (check every animation without having to lose HP). Runtime only, never saved.
local function SetForcedState(name)
    if name and IS_STATE[name] then
        forcedState = name
        currentState = name
        Dbg("preview: state forced to " .. name)
        if cs.enabled then ApplyTexture(); ApplyLayout() end
    else
        forcedState = nil
        Dbg("preview: state back to automatic (HP)")
        ReadHealthNow()
    end
end

-- One-shot delayed re-read (never repeats itself; cancelled by any newer valid HP event).
local function ScheduleResync()
    resyncGen = resyncGen + 1
    local gen = resyncGen
    zo_callLater(function()
        if gen ~= resyncGen then return end
        ReadHealthNow()
    end, RESYNC_MS)
end

-- EVENT_POWER_UPDATE(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
-- The handler checks unit AND resource type itself, so Stamina / Magicka / Ultimate / other units can never reach the image or the % text.
local function OnPowerUpdate(_, unitTag, _, powerType, powerValue, powerMax, powerEffectiveMax)
    if unitTag ~= "player" or not HEALTH_TYPES[powerType] then return end
    if not firstEventSeen then firstEventSeen = true; Dbg("first HP event " .. tostring(powerValue) .. "/" .. tostring(powerMax) .. "/" .. tostring(powerEffectiveMax)) end

    local max = powerMax
    if type(powerEffectiveMax) == "number" and powerEffectiveMax > 0 then max = powerEffectiveMax end

    local maxValid = (type(max) == "number" and max > 0)
    local maxChanged = maxValid and (max ~= lastEventMax)
    if maxValid then lastEventMax = max end     -- an unusable event must not look like a max-HP change later

    -- Unusable / inconsistent event values, or max HP changed: take the authoritative value from the API.
    if maxChanged or type(powerValue) ~= "number" or type(max) ~= "number" or max <= 0 or powerValue > max then
        if ReadHealthNow() then return end
        -- the direct read is unusable (e.g. returns nothing at login): trust the event when it is consistent itself
        if maxValid and type(powerValue) == "number" and powerValue <= max then
            resyncGen = resyncGen + 1
            UpdateState(powerValue, max)
        else
            ScheduleResync()
        end
        return
    end

    resyncGen = resyncGen + 1     -- a valid fresh value supersedes any pending delayed re-read
    UpdateState(powerValue, max)
end

-- At login / reloadui GetUnitPower can still report max = 0. Retry a few times (one-shot, 0.5 s apart,
-- max 10 tries, stops as soon as a valid reading arrives). No permanent polling.
local RETRY_TRIES, RETRY_MS = 10, 500
local retryGen = 0
local function ReadWithRetry(triesLeft, gen)
    if gen ~= retryGen then return end            -- a newer lifecycle event took over
    if ReadHealthNow() then return end
    if triesLeft <= 0 then
        Dbg("HP UNREADABLE after retries")
        if not currentState then          -- never leave the player with an empty screen: show NORMAL until real HP data arrives
            currentState = "NORMAL"
            if cs.enabled then ApplyTexture() end
            Dbg("showing NORMAL as a placeholder")
        end
        return
    end
    zo_callLater(function() ReadWithRetry(triesLeft - 1, gen) end, RETRY_MS)
end

---------------------------------------------------------------------------
-- Character preview strip: the 5 still images (PNG) of the character in use, side by side. Runtime only (OFF after every login).
-- The moving preview is the mascot itself with "Preview state" (one state at a time). The stills are only requested while the strip is ON.
---------------------------------------------------------------------------
local PREV_CELL, PREV_GAP, PREV_LABEL_H = 128, 8, 28
local prevTlw, prevCells = nil, {}
local previewStrip = false

local function BuildPreviewStrip()
    pcall(function()
        local w = #STATES * PREV_CELL + (#STATES - 1) * PREV_GAP
        local h = PREV_CELL + PREV_LABEL_H
        local sw, sh = GuiRoot:GetWidth() or 1920, GuiRoot:GetHeight() or 1080
        prevTlw = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "_PrevTLW")
        prevTlw:SetMouseEnabled(false)
        prevTlw:SetMovable(false)
        prevTlw:SetDimensions(w, h)
        prevTlw:ClearAnchors()
        prevTlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, math.max(0, math.floor((sw - w) / 2)), math.max(0, math.floor(sh - h - 40)))
        prevTlw:SetHidden(true)
        local font = "ZoFontGame"
        for _, name in ipairs(FONT_CANDIDATES) do
            if _G[name] ~= nil then font = name break end
        end
        for i, st in ipairs(STATES) do
            local x = (i - 1) * (PREV_CELL + PREV_GAP)
            local tx = WINDOW_MANAGER:CreateControl(ADDON .. "_PrevTex" .. i, prevTlw, CT_TEXTURE)
            tx:SetDimensions(PREV_CELL, PREV_CELL)
            tx:SetAnchor(TOPLEFT, prevTlw, TOPLEFT, x, 0)
            local lb = WINDOW_MANAGER:CreateControl(ADDON .. "_PrevLbl" .. i, prevTlw, CT_LABEL)
            lb:SetFont(font)
            lb:SetColor(1, 1, 1, 1)
            lb:SetText(st)
            lb:SetDimensions(PREV_CELL, PREV_LABEL_H)
            lb:SetAnchor(TOPLEFT, prevTlw, TOPLEFT, x, PREV_CELL)
            pcall(lb.SetHorizontalAlignment, lb, TEXT_ALIGN_CENTER)
            prevCells[i] = { tex = tx, label = lb }
        end
    end)
end

local function RefreshPreviewStrip()                 -- called when the strip is switched or the character changes
    if not prevTlw or #prevCells ~= #STATES then return end
    if not previewStrip then prevTlw:SetHidden(true); return end
    for i, st in ipairs(STATES) do
        local cfg = CfgOf(st)
        if cfg then pcall(prevCells[i].tex.SetTexture, prevCells[i].tex, cfg.fallback) end
    end
    prevTlw:SetHidden(false)
end

local function SetPreviewStrip(on)
    previewStrip = on and true or false
    RefreshPreviewStrip()
end

-- Resets ONLY the character in use (position / size / opacity / show / HP%). Other characters and the HP boundaries are untouched.
local function ResetCurrentChar()
    for k, v in pairs(CHAR_DEFAULTS) do cs[k] = v end
    ApplyLayout()
end

---------------------------------------------------------------------------
-- Character switching
---------------------------------------------------------------------------
-- newId: character to show (unknown / removed / failed -> standard). Everything of the old character stops; the new character's own
-- settings are applied; the preview state (if one is forced) is kept so the same state can be compared across characters.
function SwitchPack(newId)
    if not (packs[newId] and not badPacks[newId]) then newId = DEFAULT_ID end
    if newId == curId and curPack then return end
    StopAnim()
    curId = newId
    curPack = packs[newId]
    cs = CharSettings(newId)                      -- settings of THIS character (restored if it was used before)
    onceDone = {}
    shownState = nil                              -- forces a fresh ShowImage with the new character's files
    shownPercent = nil                            -- the label is rewritten for the new character
    if not forcedState then ReadHealthNow() end
    ApplyLayout()
    RefreshPreviewStrip()
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function BuildUI()
    tlw = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "_TLW")
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)

    tex = WINDOW_MANAGER:CreateControl(ADDON .. "_Tex", tlw, CT_TEXTURE)
    tex:SetAnchorFill(tlw)
    tex:SetHidden(true)           -- stays hidden until the first image is set (no white box)

    pcall(function()
        tex:SetHandler("OnTextureLoaded", function()
            if shownFile then loadedSet[shownFile] = true end
        end)
    end)

    -- Stop the animation whenever the image is not visible (menus, disabled) and resume when visible again.
    -- If these handlers are unavailable the animation simply keeps running while hidden (harmless).
    pcall(function()
        tex:SetHandler("OnEffectivelyHidden", function() StopAnim() end)
        tex:SetHandler("OnEffectivelyShown", function()
            if sv and cs and cs.enabled then
                EnsurePlayback()
                if shownFile and not loadedSet[shownFile] then ReapplyImage(); WatchLoad() end   -- visible now: let the engine load it
            end
        end)
    end)

    -- HP% label: isolated, so a failure here can never affect the mascot image itself.
    pcall(function()
        local font = "ZoFontGame"
        for _, name in ipairs(FONT_CANDIDATES) do
            if _G[name] ~= nil then font = name break end
        end
        local l = WINDOW_MANAGER:CreateControl(ADDON .. "_Pct", tlw, CT_LABEL)
        l:SetFont(font)
        l:SetColor(1, 1, 1, 1)
        pcall(l.SetHorizontalAlignment, l, TEXT_ALIGN_CENTER)   -- cosmetic: never lets the label fail
        pcall(l.SetVerticalAlignment, l, TEXT_ALIGN_TOP)
        l:SetMouseEnabled(false)
        l:SetHidden(true)         -- hidden until the first percentage is written
        label = l
    end)

    -- Show only on the HUD (hide in menus). If this fails the image simply stays visible everywhere.
    pcall(function()
        hudFragment = ZO_SimpleSceneFragment:New(tlw)
        HUD_SCENE:AddFragment(hudFragment)
        HUD_UI_SCENE:AddFragment(hudFragment)
    end)
end

-- Preview: keeps the mascot visible while the settings screen (or any menu) is open, so position / size can be adjusted live.
-- Runtime only (not saved): it is OFF again after every login. No timers, no extra events.
local function SetPreview(on)
    preview = on and true or false
    if not hudFragment or not tlw then return end          -- no fragment = already visible everywhere
    pcall(function()
        if preview then
            HUD_SCENE:RemoveFragment(hudFragment)
            HUD_UI_SCENE:RemoveFragment(hudFragment)
            tlw:SetHidden(false)
        else
            HUD_SCENE:AddFragment(hudFragment)
            HUD_UI_SCENE:AddFragment(hudFragment)
            local inHud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
            tlw:SetHidden(not inHud)
        end
    end)
    ApplyLayout()
end

---------------------------------------------------------------------------
-- Settings panel (LibAddonMenu-2.0 is OPTIONAL: without it the defaults are used)
-- Built at the first EVENT_PLAYER_ACTIVATED, AFTER the character packs are registered (built earlier, the character list only has "Default").
---------------------------------------------------------------------------
local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "_Panel"
    local panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "PlayerMascotHealth 2",
        displayName = "PlayerMascotHealth 2",
        author = "PlayerMascotHealth project",
        version = VERSION,
    })

    local function Refresh()
        pcall(function() CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end)
    end

    local sw = math.max(200, math.floor(GuiRoot:GetWidth() or 1920))
    local sh = math.max(200, math.floor(GuiRoot:GetHeight() or 1080))

    LAM:RegisterOptionControls(panelName, {
        {
            type = "dropdown", name = "Character (使用キャラ)",
            tooltip = "Applies immediately. The settings below belong to the character that is in use.",
            choices = charNames,
            getFunc = function() return packs[curId].display end,
            setFunc = function(choice)
                local id = nameToId[choice]
                if not id then return end
                sv.selectedId = id
                if badPacks[id] then                      -- chosen again on purpose: give a pack that failed earlier one more try
                    badPacks[id] = nil
                    for _, st in ipairs(STATES) do animBroken[id .. ":" .. st] = nil end
                end
                SwitchPack(ResolveId())
                Refresh()
            end,
            default = packs[DEFAULT_ID].display,
        },
        {
            type = "checkbox", name = "Show Mascot (表示)",
            getFunc = function() return cs.enabled end,
            setFunc = function(v) cs.enabled = v and true or false; ApplyLayout() end,
            default = CHAR_DEFAULTS.enabled,
        },
        {
            type = "checkbox", name = "Show HP % (HP割合を表示)",
            getFunc = function() return cs.showPercent end,
            setFunc = function(v) cs.showPercent = v and true or false; ApplyLayout() end,
            default = CHAR_DEFAULTS.showPercent,
        },
        {
            type = "checkbox", name = "Preview while in menus (プレビュー表示)",
            tooltip = "ON: the mascot stays visible while this settings screen is open, so you can place it. Turns OFF again at the next login.",
            getFunc = function() return preview end,
            setFunc = function(v) SetPreview(v) end,
            default = false,
        },
        {
            type = "checkbox", name = "Character preview (5状態の静止画一覧)",
            tooltip = "ON: shows the 5 still images of the selected character at the bottom of the screen. Use 'Preview state' below to see one state animated. Turns OFF again at the next login.",
            getFunc = function() return previewStrip end,
            setFunc = function(v) SetPreviewStrip(v) end,
            default = false,
        },
        {
            type = "slider", name = "Position X (横位置)", min = 0, max = sw, step = 10,
            getFunc = function() return cs.x end,
            setFunc = function(v) cs.x = Num(v, 0, 8000, CHAR_DEFAULTS.x); ApplyLayout() end,
            default = CHAR_DEFAULTS.x,
        },
        {
            type = "slider", name = "Position Y (縦位置)", min = 0, max = sh, step = 10,
            getFunc = function() return cs.y end,
            setFunc = function(v) cs.y = Num(v, 0, 8000, CHAR_DEFAULTS.y); ApplyLayout() end,
            default = CHAR_DEFAULTS.y,
        },
        {
            type = "slider", name = "Size (大きさ)", min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
            getFunc = function() return cs.size end,
            setFunc = function(v) cs.size = Num(v, SIZE_MIN, SIZE_MAX, CHAR_DEFAULTS.size); ApplyLayout() end,
            default = CHAR_DEFAULTS.size,
        },
        {
            type = "slider", name = "Opacity (透明度 %)", min = ALPHA_MIN, max = ALPHA_MAX, step = 5,
            getFunc = function() return cs.alpha end,
            setFunc = function(v) cs.alpha = Num(v, ALPHA_MIN, ALPHA_MAX, CHAR_DEFAULTS.alpha); ApplyLayout() end,
            default = CHAR_DEFAULTS.alpha,
        },
        {
            type = "slider", name = "NORMAL from HP % (通常)", min = NORMAL_MIN, max = NORMAL_MAX, step = 5,
            getFunc = function() return sv.normalStart end,
            setFunc = function(v)
                sv.normalStart = Num(v, NORMAL_MIN, NORMAL_MAX, DEFAULTS.normalStart)
                Sanitize()          -- pulls cautionStart down if it would overlap
                ReadHealthNow(); Refresh()
            end,
            default = DEFAULTS.normalStart,
        },
        {
            type = "slider", name = "CAUTION from HP % (注意)", min = CAUTION_MIN, max = CAUTION_MAX, step = 5,
            getFunc = function() return sv.cautionStart end,
            setFunc = function(v)
                sv.cautionStart = Num(v, CAUTION_MIN, CAUTION_MAX, DEFAULTS.cautionStart)
                Sanitize()          -- keeps cautionStart <= normalStart - GAP (pulls dangerStart down if needed)
                ReadHealthNow(); Refresh()
            end,
            default = DEFAULTS.cautionStart,
        },
        {
            type = "slider", name = "DANGER from HP % (危険)", min = DANGER_MIN, max = DANGER_MAX, step = 5,
            getFunc = function() return sv.dangerStart end,
            setFunc = function(v)
                sv.dangerStart = Num(v, DANGER_MIN, DANGER_MAX, DEFAULTS.dangerStart)
                Sanitize()          -- keeps dangerStart <= cautionStart - GAP
                ReadHealthNow(); Refresh()
            end,
            default = DEFAULTS.dangerStart,
        },
        -- ---------------- state preview (runtime only) ----------------
        {
            type = "dropdown", name = "Preview state (状態を固定して表示)",
            tooltip = "Shows the chosen state's animation regardless of HP, to check all 5 states. Back to 'Auto (HP)' at the next login.",
            choices = { "Auto (HP)", "NORMAL", "CAUTION", "DANGER", "CRITICAL", "ZERO" },
            getFunc = function() return forcedState or "Auto (HP)" end,
            setFunc = function(choice) SetForcedState(IS_STATE[choice] and choice or nil) end,
            default = "Auto (HP)",
        },
        {
            type = "dropdown", name = "Reset this character (このキャラの設定を初期化)",
            tooltip = "Choose 'Reset' to set show / HP% / position / size / opacity of the character in use back to the defaults. Other characters are not changed.",
            choices = { "-", "Reset" },
            getFunc = function() return "-" end,
            setFunc = function(choice)
                if choice == "Reset" then ResetCurrentChar(); Refresh() end
            end,
            default = "-",
        },
    })
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local function OnLifecycle()
    if not packsReady then                        -- first EVENT_PLAYER_ACTIVATED of this session: all addons are loaded
        PackSetup()
        local want = ResolveId()
        if want ~= curId then SwitchPack(want) else ApplyLayout() end   -- the first image is shown by the HP read below
        if not settingsBuilt then
            settingsBuilt = true
            local sok, serr = pcall(BuildSettings)
            if not sok then d("[PlayerMascotHealth2] settings unavailable: " .. tostring(serr)) end   -- the mascot itself keeps working
        end
    end
    retryGen = retryGen + 1
    ReadWithRetry(RETRY_TRIES, retryGen)
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    local ok, err = pcall(function()
        local namespace = GetWorldName and GetWorldName() or nil
        sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, namespace, DEFAULTS)
        Sanitize()
        pcall(ImportV1)                           -- v1.5.0 settings -> standard character (once)
        Sanitize()
        cs = CharSettings(DEFAULT_ID)             -- until the characters are known, the standard character's settings are in use

        BuildUI()
        BuildPreviewStrip()
        ApplyLayout()

        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, HEALTH_TYPE)

        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED,    OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_DEAD,         OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ALIVE,        OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_REINCARNATED, OnLifecycle)
        Dbg("v" .. VERSION .. " loaded, selected=" .. tostring(sv.selectedId))
    end)
    if not ok then
        d("[PlayerMascotHealth2] init error: " .. tostring(err))   -- one line, only on failure
        return
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
