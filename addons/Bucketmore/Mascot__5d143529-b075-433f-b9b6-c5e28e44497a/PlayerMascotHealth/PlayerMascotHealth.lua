-- PlayerMascotHealth v1.3.4-diag  (v1.3.3 + diagnostics only: no change to HP rules, animation or images)
-- Shows one animation per HP state (5 states: NORMAL / CAUTION / DANGER / CRITICAL / ZERO) depending on the PLAYER's own HP. Own HP only (no enemy/NPC/target HP).
-- Each state is either STATIC (one image) or ANIMATION (sprite sheet played by the game engine through
-- ANIMATION_TEXTURE - no Lua timer, no OnUpdate). See STATE_IMAGE below.
-- No OnUpdate / no polling: HP is read on EVENT_POWER_UPDATE (player + health only) and a few
-- rare lifecycle events. The texture is only swapped when the state actually changes.

local ADDON      = "PlayerMascotHealth"
local VERSION    = "1.3.4-diag"
local DEBUG      = true       -- v1.3.1: prints a few "[PMH]" lines (max 12 per session) to find why nothing is shown; set false to silence
local SV_NAME    = "PlayerMascotHealth_SV"
local SV_VERSION = 1

-- PS5 verified: PNG / DDS display with alpha via CT_TEXTURE:SetTexture("<AddOn>/tex/<file>"),
-- 1024x1024 DDS sheet, SetTextureCoords, and ANIMATION_TEXTURE (SetImageData / SetFramerate / loop) playback.
local TEX_DIR = "PlayerMascotHealth/tex/"

-- Image per HP state. type = "STATIC"    : one image (file)
--                     type = "ANIMATION" : sprite sheet (file) cols x rows, frames left->right, top->bottom,
--                                          played at fps in a loop by ANIMATION_TEXTURE.
--   fallback      : static image used if the animation API fails        (ANIMATION only)
--   contentBottom : where the visible character ends (fraction of the image height); the HP% text sits below it
-- To animate another state later, change its entry (e.g. CAUTION = { type = "ANIMATION", file = ".../CAUTION_SHEET.dds",
-- cols = 4, rows = 2, fps = 8, fallback = ".../CAUTION.png", contentBottom = ... }). No other code change is needed.
local STATE_IMAGE = {
    NORMAL   = { type = "ANIMATION", file = TEX_DIR .. "NORMAL_SHEET.dds", cols = 4, rows = 2, fps = 8,
                 fallback = TEX_DIR .. "NORMAL.png", contentBottom = 498 / 512 },
    CAUTION  = { type = "ANIMATION", file = TEX_DIR .. "CAUTION_SHEET.dds", cols = 4, rows = 2, fps = 8,
                 fallback = TEX_DIR .. "CAUTION.png", contentBottom = 498 / 512 },
    DANGER   = { type = "ANIMATION", file = TEX_DIR .. "DANGER_SHEET.dds", cols = 4, rows = 2, fps = 8,
                 fallback = TEX_DIR .. "DANGER.png", contentBottom = 498 / 512 },
    CRITICAL = { type = "ANIMATION", file = TEX_DIR .. "CRITICAL_SHEET.dds", cols = 4, rows = 2, fps = 8,
                 fallback = TEX_DIR .. "CRITICAL.png", contentBottom = 498 / 512 },
    ZERO     = { type = "ANIMATION", file = TEX_DIR .. "ZERO_SHEET.dds", cols = 4, rows = 2, fps = 8,
                 fallback = TEX_DIR .. "ZERO.png", contentBottom = 498 / 512 },
}

local ASPECT    = 2                      -- image is 256x512 -> height = width * 2
local SIZE_MIN, SIZE_MAX, SIZE_STEP = 128, 768, 8   -- size = displayed HEIGHT in UI px
local NORMAL_MIN, NORMAL_MAX = 20, 95
local CAUTION_MIN, CAUTION_MAX = 10, 90
local DANGER_MIN, DANGER_MAX = 5, 80
-- HP% text: sits just under the visible character (per-state contentBottom above)
local DEFAULT_CONTENT_BOTTOM = 404 / 512
local LABEL_GAP, LABEL_H = 2, 40
local FONT_CANDIDATES = { "ZoFontGamepad34", "ZoFontGamepad27", "ZoFontGameBold", "ZoFontGame" }

local RESYNC_MS = 150                -- single delayed re-read, only when an event value is unusable AND the direct read failed
local GAP       = 5                      -- each boundary must stay at least this far below the one above it

local DEFAULTS = {
    enabled     = true,
    showPercent = true,  -- HP% text under the image
    x           = 20,
    y           = 240,
    size        = 256,
    normalStart  = 70,   -- HP% >= this              -> NORMAL
    cautionStart = 40,   -- HP% >= this (< normal)   -> CAUTION
    dangerStart  = 20,   -- HP% >= this (< caution)  -> DANGER, below (but HP > 0) -> CRITICAL, HP = 0 -> ZERO
}

-- Power type of the HP resource. The v1.3.1 check "powerType ~= POWERTYPE_HEALTH" rejected every HP event on PS5, so the
-- type is now resolved defensively: any of these numbers counts as health (32 is the engine value of health).
local HEALTH_TYPE = POWERTYPE_HEALTH or COMBAT_MECHANIC_FLAGS_HEALTH or 32
local HEALTH_TYPES = { [32] = true }
if type(POWERTYPE_HEALTH) == "number" then HEALTH_TYPES[POWERTYPE_HEALTH] = true end
if type(COMBAT_MECHANIC_FLAGS_HEALTH) == "number" then HEALTH_TYPES[COMBAT_MECHANIC_FLAGS_HEALTH] = true end

local sv                -- saved variables (sanitized)
local tlw, tex, label   -- top level window / texture control / HP% label (label may stay nil)
local currentState      -- last computed state
local shownState        -- state whose texture is currently set on the control
local currentPercent    -- last computed HP% (integer 0..100)
local shownPercent      -- HP% currently written into the label
local lastEventMax      -- max HP seen in the previous HP event (detects max-HP changes)
local resyncGen = 0     -- cancels a pending delayed re-read as soon as a newer valid value arrives
local timelines = {}    -- state -> animation timeline (created once, then reused: no leak)
local animBroken = {}   -- state -> true when the animation API failed (static fallback is used)
local activeTL          -- timeline that is playing right now (nil = nothing playing)
local rawCur, rawMax, rawEff   -- what GetUnitPower returned last (for the debug line only)
local shownFile            -- file currently set on the control (debug only)
local debugLines, firstEventSeen = 0, false
local evtLines, seenPairs = 0, {}
local loadedSet = {}       -- files for which the engine reported OnTextureLoaded (verified API on PS5)
local preview = false      -- settings preview (runtime only, never saved; OFF after every login)
local hudFragment          -- scene fragment that hides the mascot in menus (nil if it could not be created)

local DEBUG_MAX = 400      -- v1.3.4-diag: was 12
local function NowMs()
    if GetGameTimeMilliseconds then
        local ok, v = pcall(GetGameTimeMilliseconds)
        if ok and type(v) == "number" then return v end
    end
    return 0
end
local t0Ms = NowMs()
local reqSeq, reqFile, reqMs = 0, nil, 0      -- the image request that is currently in flight (for the loaded-event log)
local forcedState          -- diag: state chosen in the settings (nil = automatic from HP); runtime only
local watchdogOff = false  -- diag: stops the "set the image again" watchdog; runtime only

local function Dbg(msg)       -- bounded: never floods the chat
    if not DEBUG then return end
    if debugLines < DEBUG_MAX then
        debugLines = debugLines + 1
        d(("[PMH %.1fs] %s"):format((NowMs() - t0Ms) / 1000, msg))
        if debugLines == DEBUG_MAX then d("[PMH] debug line limit reached") end
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

local function Sanitize()
    if type(sv.enabled) ~= "boolean" then sv.enabled = DEFAULTS.enabled end
    if type(sv.showPercent) ~= "boolean" then sv.showPercent = DEFAULTS.showPercent end
    sv.x    = Num(sv.x, 0, 8000, DEFAULTS.x)
    sv.y    = Num(sv.y, 0, 8000, DEFAULTS.y)
    sv.size = Num(sv.size, SIZE_MIN, SIZE_MAX, DEFAULTS.size)
    sv.normalStart = Num(sv.normalStart, NORMAL_MIN, NORMAL_MAX, DEFAULTS.normalStart)
    local cautionMax = math.min(CAUTION_MAX, sv.normalStart - GAP)
    sv.cautionStart = Num(sv.cautionStart, CAUTION_MIN, cautionMax, math.min(DEFAULTS.cautionStart, cautionMax))
    local dangerMax = math.min(DANGER_MAX, sv.cautionStart - GAP)
    sv.dangerStart = Num(sv.dangerStart, DANGER_MIN, dangerMax, math.min(DEFAULTS.dangerStart, dangerMax))
end

-- v1.2.x saved only 2 boundaries (70 / 30). Their old default 30 (CAUTION/CRITICAL boundary) is now the CAUTION/DANGER
-- area, so it moves to the new default 40; a value the player changed on purpose is kept. Runs once.
local function MigrateThresholds()
    if sv.thrVersion == 2 then return end
    if sv.cautionStart == 30 then sv.cautionStart = DEFAULTS.cautionStart end
    sv.thrVersion = 2
end

---------------------------------------------------------------------------
-- HP state (pure calculation, no UI)
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

-- Integer HP% (rounded down). cur*100/max avoids float artefacts such as 0.29*100 = 28.999...
-- Only call with values that CalcState already accepted (max > 0).
local function CalcPercent(cur, max)
    if cur < 0 then cur = 0 end
    local pct = math.floor(cur * 100 / max)
    if pct > 100 then pct = 100 end
    return pct
end

---------------------------------------------------------------------------
-- Image switching (no HP logic)
---------------------------------------------------------------------------
local function StopAnim()
    if activeTL then
        pcall(activeTL.Stop, activeTL)
        activeTL = nil
    end
end

local function ResetCoords()          -- full texture (static images)
    pcall(tex.SetTextureCoords, tex, 0, 1, 0, 1)
end

-- Same calls as the PS5-verified diagnostic: CreateTimeline / InsertAnimation(ANIMATION_TEXTURE) /
-- SetImageData / SetFramerate / loop / PlayFromStart. The timeline is built once per state and reused.
local function StartAnim(state, cfg)
    if activeTL then return true end
    local ok = pcall(function()
        pcall(tex.SetTextureCoords, tex, 0, 1 / cfg.cols, 0, 1 / cfg.rows)   -- first cell, never the whole sheet
        local tl = timelines[state]
        if not tl then
            tl = ANIMATION_MANAGER:CreateTimeline()
            local a = tl:InsertAnimation(ANIMATION_TEXTURE, tex)
            a:SetImageData(cfg.cols, cfg.rows)
            a:SetFramerate(cfg.fps)
            tl:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
            timelines[state] = tl
        end
        tl:PlayFromStart()
        activeTL = tl
    end)
    return ok
end

local function ShowImage(state, cfg)
    if cfg.type == "ANIMATION" and not animBroken[state] then
        shownFile = cfg.file
        reqSeq = reqSeq + 1; reqFile = shownFile; reqMs = NowMs()
        tex:SetTexture(cfg.file)
        if StartAnim(state, cfg) then return end
        animBroken[state] = true      -- animation API unusable: never retry, use the static fallback
        Dbg("animation FAILED for " .. state .. " -> static fallback")
    end
    shownFile = (cfg.type == "ANIMATION") and cfg.fallback or cfg.file
    reqSeq = reqSeq + 1; reqFile = shownFile; reqMs = NowMs()
    tex:SetTexture(shownFile)
    ResetCoords()
end

-- Re-starts the animation of the shown state (after the control was hidden / re-enabled).
local function EnsurePlayback()
    if activeTL or not shownState then return end
    local cfg = STATE_IMAGE[shownState]
    if cfg and cfg.type == "ANIMATION" and not animBroken[shownState] then
        if not StartAnim(shownState, cfg) then
            animBroken[shownState] = true
            ShowImage(shownState, cfg)
        end
    end
end

-- v1.3.3: on PS5 an image set right after login was never loaded (no OnTextureLoaded, nothing drawn) while an image set a few
-- seconds later was. If the engine has not reported the file as loaded after 1 s, the image is set again (max 6 times,
-- one-shot checks, stops as soon as OnTextureLoaded arrives; a state change cancels the old check).
local LOAD_CHECK_MS, LOAD_CHECK_MAX = 1000, 6
local function ReapplyImage()
    if not tex or not shownState then return end
    StopAnim()
    ShowImage(shownState, STATE_IMAGE[shownState])
end

-- At most ONE check is ever pending; a state change only restarts the attempt counter.
local watchPending, watchAttempt = false, 1
local ScheduleWatch
function ScheduleWatch()
    watchPending = true
    zo_callLater(function()
        watchPending = false
        if watchdogOff then Dbg("watchdog is OFF (diag): not setting the image again") return end
        if not tex or not shownState or not shownFile or loadedSet[shownFile] then return end   -- loaded, or nothing shown
        if watchAttempt >= LOAD_CHECK_MAX then
            Dbg("texture never reported loaded: " .. tostring(shownFile))
            return
        end
        Dbg("texture not loaded yet -> setting it again (" .. watchAttempt .. "): " .. tostring(shownFile))
        if sv.enabled then ReapplyImage() end
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
    if not label or not tlw then return end
    local cfg = STATE_IMAGE[shownState or currentState or "NORMAL"]
    local cb = (cfg and cfg.contentBottom) or DEFAULT_CONTENT_BOTTOM
    local h = sv.size
    label:ClearAnchors()
    label:SetAnchor(TOP, tlw, TOP, 0, math.floor(h * cb) + LABEL_GAP)
    label:SetDimensions(h / ASPECT, LABEL_H)
end

local function ApplyTexture()
    if not tex or not currentState then return end
    if shownState == currentState then return end   -- same state: never reload
    StopAnim()                                      -- nothing of the previous state keeps playing
    shownState = currentState
    Dbg("state -> " .. currentState .. "  file=" .. tostring(STATE_IMAGE[currentState].file))
    ShowImage(currentState, STATE_IMAGE[currentState])
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
    if not tlw or not tex then return end
    local h = sv.size
    local w = h / ASPECT
    local x, y = sv.x, sv.y
    local sw, sh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    if sw and sw > 0 then x = math.min(x, math.max(0, sw - w)) end
    if sh and sh > 0 then y = math.min(y, math.max(0, sh - h)) end
    tlw:ClearAnchors()
    tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    tlw:SetDimensions(w, h)
    if sv.enabled then
        ApplyTexture()
        EnsurePlayback()
    else
        StopAnim()                -- hidden: no animation runs
    end
    tex:SetHidden(not (sv.enabled and shownState ~= nil))

    if label then
        LayoutLabel()
        local want = sv.enabled and sv.showPercent
        if want then ApplyPercent() end
        label:SetHidden(not (want and shownPercent ~= nil))
    end
end

---------------------------------------------------------------------------
-- HP reading
---------------------------------------------------------------------------
local function UpdateState(cur, max)
    local s = CalcState(cur, max)
    if s == nil then return false end   -- HP data not available (yet)
    if forcedState then s = forcedState end      -- diag: the settings dropdown overrides the HP state
    if s ~= currentState then
        currentState = s
        if sv.enabled then ApplyTexture() end
    end
    currentPercent = CalcPercent(cur, max)
    if sv.enabled and sv.showPercent then ApplyPercent() end   -- no-op while the integer is unchanged
    return true
end

-- debug only: lists each (unit, power type) pair the first time an EVENT_POWER_UPDATE shows it (max 8 lines)
local function NoteEvent(unitTag, powerType, value, max)
    local key = tostring(unitTag) .. ":" .. tostring(powerType)
    if seenPairs[key] then return end
    seenPairs[key] = true
    evtLines = evtLines + 1
    d(("[PMH] event unit=%s type=%s value=%s max=%s %s"):format(tostring(unitTag), tostring(powerType), tostring(value), tostring(max),
        (unitTag == "player" and HEALTH_TYPES[powerType]) and "=HEALTH" or ""))
end

-- Full re-read: login / zone change / respawn / death / revive (rare events)
local function ReadHealthNow()
    local cur, max, effMax = GetUnitPower("player", HEALTH_TYPE)
    rawCur, rawMax, rawEff = cur, max, effMax
    if type(effMax) == "number" and effMax > 0 then max = effMax end
    return UpdateState(cur, max)
end

-- One-shot delayed re-read (never repeats itself; cancelled by any newer valid HP event).
-- diag: show one state on purpose (to test every sheet without having to lose HP). Runtime only.
local function SetForcedState(name)
    if name and STATE_IMAGE[name] then
        forcedState = name
        currentState = name
        Dbg("diag: state forced to " .. name)
        if sv.enabled then ApplyTexture(); ApplyLayout() end
    else
        forcedState = nil
        Dbg("diag: state back to automatic (HP)")
        ReadHealthNow()
    end
end

local function ScheduleResync()
    resyncGen = resyncGen + 1
    local gen = resyncGen
    zo_callLater(function()
        if gen ~= resyncGen then return end
        ReadHealthNow()
    end, RESYNC_MS)
end

-- EVENT_POWER_UPDATE(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
-- The handler checks unit AND resource type itself (does not rely on registration filters), so Stamina /
-- Magicka / Ultimate / other units can never reach the image or the % text.
local function OnPowerUpdate(_, unitTag, _, powerType, powerValue, powerMax, powerEffectiveMax)
    if DEBUG and evtLines < 8 then NoteEvent(unitTag, powerType, powerValue, powerMax) end
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
    if ReadHealthNow() then
        Dbg(("HP read ok %s/%s/%s -> %s"):format(tostring(rawCur), tostring(rawMax), tostring(rawEff), tostring(currentState)))
        return
    end
    if triesLeft <= 0 then
        Dbg(("HP UNREADABLE after retries (GetUnitPower returned %s/%s/%s)"):format(tostring(rawCur), tostring(rawMax), tostring(rawEff)))
        if DEBUG then
            local function probe(t) if type(t) ~= "number" then return "n/a" end
                local ok, c, m = pcall(GetUnitPower, "player", t); return ok and (tostring(c) .. "/" .. tostring(m)) or "err" end
            Dbg(("types: HEALTH=%s FLAGS_HEALTH=%s using=%s | API probe health=%s magicka=%s stamina=%s"):format(
                tostring(POWERTYPE_HEALTH), tostring(COMBAT_MECHANIC_FLAGS_HEALTH), tostring(HEALTH_TYPE),
                probe(HEALTH_TYPE), probe(POWERTYPE_MAGICKA), probe(POWERTYPE_STAMINA)))
        end
        if not currentState then          -- never leave the player with an empty screen: show NORMAL until real HP data arrives
            currentState = "NORMAL"
            if sv.enabled then ApplyTexture() end
            Dbg("showing NORMAL as a placeholder")
        end
        return
    end
    zo_callLater(function() ReadWithRetry(triesLeft - 1, gen) end, RETRY_MS)
end

local function OnLifecycle()
    retryGen = retryGen + 1
    ReadWithRetry(RETRY_TRIES, retryGen)
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
            if DEBUG then
                local ok, w, h = pcall(tex.GetTextureFileDimensions, tex)
                Dbg(("texture loaded event: current request=%s (#%d, %d ms ago) size=%s"):format(
                    tostring(shownFile), reqSeq, NowMs() - reqMs, ok and (tostring(w) .. "x" .. tostring(h)) or "?"))
            end
        end)
    end)

    -- Stop the animation whenever the image is not visible (menus, disabled) and resume when visible again.
    -- If these handlers are unavailable the animation simply keeps running while hidden (harmless).
    pcall(function()
        tex:SetHandler("OnEffectivelyHidden", function() StopAnim() end)
        tex:SetHandler("OnEffectivelyShown", function()
            if sv and sv.enabled then
                EnsurePlayback()
                if shownFile and not loadedSet[shownFile] and not watchdogOff then ReapplyImage() end   -- visible now: let the engine load it
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

---------------------------------------------------------------------------
-- DIAGNOSTICS (v1.3.4-diag): nothing here changes HP rules, animation or images unless a diag option is used
---------------------------------------------------------------------------
local STATE_ORDER = { "NORMAL", "CAUTION", "DANGER", "CRITICAL", "ZERO" }
local PROBE_FILES = {}
for _, st in ipairs(STATE_ORDER) do
    PROBE_FILES[#PROBE_FILES + 1] = STATE_IMAGE[st].file
    PROBE_FILES[#PROBE_FILES + 1] = STATE_IMAGE[st].fallback
end
local probeTLW, probes
local function ShortName(path) return tostring(path):match("[^/]+$") or tostring(path) end

-- Loads each of the 10 image files (5 sheets + 5 fallbacks) on its own small control and reports which ones the engine loads.
local function RunProbes()
    local ok, err = pcall(function()
        if not probeTLW then
            probeTLW = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "_ProbeTLW")   -- no scene fragment: visible in menus too
            probeTLW:SetMouseEnabled(false); probeTLW:SetMovable(false)
            probeTLW:SetDimensions(#PROBE_FILES * 34 + 8, 40)
            probeTLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 40, 40)
            probes = {}
            for i, f in ipairs(PROBE_FILES) do
                local c = WINDOW_MANAGER:CreateControl(ADDON .. "_Probe" .. i, probeTLW, CT_TEXTURE)
                c:SetDimensions(28, 28)
                c:SetAnchor(TOPLEFT, probeTLW, TOPLEFT, 4 + (i - 1) * 34, 6)
                probes[i] = { ctl = c, file = f }
                pcall(function()
                    c:SetHandler("OnTextureLoaded", function()
                        local pr = probes[i]
                        if not pr.loaded then
                            pr.loaded = true; pr.ms = NowMs() - pr.t
                            local okd, w, h = pcall(c.GetTextureFileDimensions, c)
                            pr.dims = okd and (tostring(w) .. "x" .. tostring(h)) or "?"
                        end
                    end)
                end)
            end
        end
        probeTLW:SetHidden(false)
        Dbg("probe: loading the 10 image files on separate controls ...")
        for _, pr in ipairs(probes) do
            pr.loaded = false; pr.ms = nil; pr.t = NowMs()
            pr.ctl:SetTexture(pr.file)
        end
        local function summary(tag)
            local bad = 0
            for _, pr in ipairs(probes) do
                if pr.loaded then
                    Dbg(("probe%s %s: LOADED %s in %d ms"):format(tag, ShortName(pr.file), tostring(pr.dims), pr.ms or -1))
                else
                    bad = bad + 1
                    Dbg(("probe%s %s: NOT LOADED"):format(tag, ShortName(pr.file)))
                end
            end
            return bad
        end
        zo_callLater(function()
            local bad = summary("")
            if bad > 0 then
                zo_callLater(function() summary(" (late check)"); if probeTLW then probeTLW:SetHidden(true) end end, 6000)
            elseif probeTLW then
                probeTLW:SetHidden(true)
            end
        end, 4000)
    end)
    if not ok then Dbg("probe error: " .. tostring(err)) end
end

-- Prints the whole status to the chat (not limited by the debug line cap).
local function PrintReport()
    local function say(t) d("[PMH report] " .. t) end
    local function try(f, ...) local r = { pcall(f, ...) }; if r[1] then table.remove(r, 1); return unpack(r) end return "n/a" end
    local lam = collectgarbage("count")
    say(("v%s enabled=%s preview=%s forced=%s watchdogOff=%s"):format(VERSION, tostring(sv and sv.enabled), tostring(preview), tostring(forcedState), tostring(watchdogOff)))
    say(("state current=%s shown=%s | HP raw=%s/%s/%s percent=%s"):format(tostring(currentState), tostring(shownState), tostring(rawCur), tostring(rawMax), tostring(rawEff), tostring(currentPercent)))
    if tex then
        local playing = activeTL and try(activeTL.IsPlaying, activeTL) or false
        local cl, cr, ct, cb = try(tex.GetTextureCoords, tex)
        local w, h = try(tex.GetTextureFileDimensions, tex)
        say(("image file=%s | control hidden=%s tlw hidden=%s | animation playing=%s | coords=%s,%s,%s,%s | file size=%sx%s"):format(
            tostring(shownFile), tostring(try(tex.IsHidden, tex)), tostring(tlw and try(tlw.IsHidden, tlw)), tostring(playing),
            tostring(cl), tostring(cr), tostring(ct), tostring(cb), tostring(w), tostring(h)))
    end
    say(("thresholds: NORMAL >= %s%%, CAUTION >= %s%%, DANGER >= %s%%, CRITICAL = above 0 and below DANGER, ZERO = HP 0"):format(
        tostring(sv and sv.normalStart), tostring(sv and sv.cautionStart), tostring(sv and sv.dangerStart)))
    local created = 0; for _ in pairs(timelines) do created = created + 1 end
    for _, st in ipairs(STATE_ORDER) do
        local cfg = STATE_IMAGE[st]
        say(("map %-8s -> %s | fallback %s | loaded=%s animationBroken=%s timeline=%s"):format(
            st, ShortName(cfg.file), ShortName(cfg.fallback), tostring(loadedSet[cfg.file] == true), tostring(animBroken[st] == true), tostring(timelines[st] ~= nil)))
    end
    say(("Lua memory %.0f KB | game time %d s | timelines %d | debug lines %d/%d"):format(lam, math.floor(NowMs() / 1000), created, debugLines, DEBUG_MAX))
end

-- Throws the current image + animation away and builds them again (for testing recovery after a memory crash).
local function ForceReload()
    if not tex or not shownState then Dbg("diag: re-initialize: nothing is shown yet"); return end
    local st, cfg = shownState, STATE_IMAGE[shownState]
    Dbg("diag: re-initializing " .. st .. " (" .. ShortName(cfg.file) .. ")")
    StopAnim()
    loadedSet[cfg.file] = nil; loadedSet[cfg.fallback] = nil
    animBroken[st] = nil; timelines[st] = nil
    ShowImage(st, cfg)
    tex:SetHidden(not sv.enabled)
    WatchLoad()
end

---------------------------------------------------------------------------
-- Preview: keeps the mascot visible while the settings screen (or any menu) is open, so position / size can be
-- adjusted live. Runtime only (not saved): it is OFF again after every login. No timers, no extra events.
---------------------------------------------------------------------------
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
---------------------------------------------------------------------------
local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "_Panel"
    local panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "PlayerMascotHealth",
        displayName = "PlayerMascotHealth",
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
            type = "checkbox", name = "Show Mascot (表示)",
            getFunc = function() return sv.enabled end,
            setFunc = function(v) sv.enabled = v and true or false; ApplyLayout() end,
            default = DEFAULTS.enabled,
        },
        {
            type = "checkbox", name = "Show HP % (HP割合を表示)",
            getFunc = function() return sv.showPercent end,
            setFunc = function(v) sv.showPercent = v and true or false; ApplyLayout() end,
            default = DEFAULTS.showPercent,
        },
        {
            type = "checkbox", name = "Preview while in menus (プレビュー表示)",
            tooltip = "ON: the mascot stays visible while this settings screen is open, so you can place it. Turns OFF again at the next login.",
            getFunc = function() return preview end,
            setFunc = function(v) SetPreview(v) end,
            default = false,
        },
        {
            type = "slider", name = "Position X (横位置)", min = 0, max = sw, step = 10,
            getFunc = function() return sv.x end,
            setFunc = function(v) sv.x = Num(v, 0, 8000, DEFAULTS.x); ApplyLayout() end,
            default = DEFAULTS.x,
        },
        {
            type = "slider", name = "Position Y (縦位置)", min = 0, max = sh, step = 10,
            getFunc = function() return sv.y end,
            setFunc = function(v) sv.y = Num(v, 0, 8000, DEFAULTS.y); ApplyLayout() end,
            default = DEFAULTS.y,
        },
        {
            type = "slider", name = "Size (大きさ)", min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
            getFunc = function() return sv.size end,
            setFunc = function(v) sv.size = Num(v, SIZE_MIN, SIZE_MAX, DEFAULTS.size); ApplyLayout() end,
            default = DEFAULTS.size,
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
        -- ---------------- diagnostics (v1.3.4-diag) ----------------
        { type = "header", name = "Diagnostics (診断)" },
        {
            type = "dropdown", name = "Diag: show one state (状態を固定して表示)",
            tooltip = "Shows the chosen state's animation regardless of HP, to test every sheet. Back to 'Auto (HP)' at the next login.",
            choices = { "Auto (HP)", "NORMAL", "CAUTION", "DANGER", "CRITICAL", "ZERO" },
            getFunc = function() return forcedState or "Auto (HP)" end,
            setFunc = function(choice) SetForcedState(STATE_IMAGE[choice] and choice or nil) end,
            default = "Auto (HP)",
        },
        {
            type = "checkbox", name = "Diag: stop the re-set watchdog (再設定を止める)",
            tooltip = "ON: the image is not set again when the engine is slow to report it as loaded. Back to OFF at the next login.",
            getFunc = function() return watchdogOff end,
            setFunc = function(v) watchdogOff = v and true or false; Dbg("diag: watchdog " .. (watchdogOff and "OFF" or "ON")) end,
            default = false,
        },
        {
            type = "button", name = "Diag: test-load all 10 image files (全ファイル読み込み確認)",
            tooltip = "Loads the 5 sheets and 5 fallback images on separate small controls and prints LOADED / NOT LOADED for each.",
            func = function() RunProbes() end,
        },
        {
            type = "button", name = "Diag: print status report (状態をチャットに出す)",
            func = function() PrintReport() end,
        },
        {
            type = "button", name = "Diag: re-initialize image + animation (再初期化)",
            tooltip = "Builds the current image and animation again (to test recovery after a crash).",
            func = function() ForceReload() end,
        },
    })
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    local ok, err = pcall(function()
        local namespace = GetWorldName and GetWorldName() or nil
        sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, namespace, DEFAULTS)
        MigrateThresholds()
        Sanitize()

        BuildUI()
        ApplyLayout()

        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, HEALTH_TYPE)

        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED,    OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_DEAD,         OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ALIVE,        OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_REINCARNATED, OnLifecycle)
        Dbg("v" .. VERSION .. " loaded, enabled=" .. tostring(sv.enabled) .. ", size=" .. tostring(sv.size) .. ", pos=" .. tostring(sv.x) .. "," .. tostring(sv.y))
    end)
    if not ok then
        d("[PlayerMascotHealth] init error: " .. tostring(err))   -- one line, only on failure
        return
    end

    -- Settings are optional; a failure here must not stop the mascot itself.
    local sok, serr = pcall(BuildSettings)
    if not sok then d("[PlayerMascotHealth] settings unavailable: " .. tostring(serr)) end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
