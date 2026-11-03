-- MatchMonitor v1.0.1 (ESO PS5 / Console)
--
-- Shows YOUR OWN Activity Finder / Battleground queue state as plain text on the
-- TV screen (no background, no frame, no icons):
--   * Dungeon Finder / Battleground, request kind (random / single x normal / veteran)
--   * the dungeon name for a single-dungeon request
--   * the state: in queue / match found (ready check) / in progress / ended
--   * the role mix (tank / heal / dps) of your group once you joined it
--
-- Lines whose data is not available (waiting counts, anything about OTHER players'
-- queues) are simply not shown. The diagnostic add-on found no such data in the
-- range it investigated, and nothing is guessed or invented here.
--
-- Design: event driven only. No per-frame handler, no polling, no chat output, no log.
-- Readability without a background: white text with a thin black outline (four
-- offset black copies of the text under the white text). The window itself keeps
-- full alpha; there is no background control at all.
-- The panel position is set from the standard settings screen (LibAddonMenu-2.0
-- sliders, see MatchMonitor_Settings.lua) and saved in SavedVariables.
--
-- STATUS: written without access to a PS5. See README for what is verified from
-- the diagnostic add-on's PS5 screenshots and what is NOT yet verified.

MatchMonitor = MatchMonitor or {}
local MM = MatchMonitor
MM.name = "MatchMonitor"
MM.version = "1.0.1"
MM.SV_VERSION = 1

------------------------------------------------------------------------------
-- Tunables
------------------------------------------------------------------------------
local DEBOUNCE_MS         = 250
local BOOT_SHOW_MS        = 6000
local IN_PROGRESS_HIDE_MS = 30000
local GRACE_BG_MS         = 7000    -- BG goes QUEUED -> NONE -> IN_PROGRESS (~4.6 s gap seen on PS5)
local GRACE_DUNGEON_MS    = 4000
local END_SHOW_MS         = 5000
local PREVIEW_MS          = 8000
local REQUEST_SCAN_CAP    = 64

-- Text-only panel: no background / frame control exists at all.
local PAD         = 2      -- room for the outline only
local LINE_H_EST  = 30     -- fallback sizes, used only if the text cannot be measured
local ASCII_W_EST = 12
local WIDE_W_EST  = 22
local MAX_TEXT_W  = 900    -- wide enough that measuring never wraps
local OUTLINE     = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local FONT_CHAIN  = { "ZoFontGamepad22", "ZoFontGamepad18", "ZoFontGame" }
local COLORS = { queued = "FFD966", good = "8FE38F", muted = "B8B8B8", plain = "FFFFFF" }

-- One entry per panel. Positions are stored per panel id (percent of the free
-- screen area), so more panels can be added later without changing the format.
local PANELS = {
    main = { defaults = { x = 3, y = 12 } },
}
local PANEL_ORDER = { "main" }
MM.panelOrder = PANEL_ORDER
function MM.GetPanelDefaults(id)
    local P = PANELS[id]
    if P then return P.defaults.x, P.defaults.y end
    return nil, nil
end

local EVENT_NAMES = {
    "EVENT_ACTIVITY_FINDER_STATUS_UPDATE",
    "EVENT_GROUPING_TOOLS_READY_CHECK_UPDATED",
    "EVENT_GROUPING_TOOLS_LFG_JOINED",
    "EVENT_ACTIVITY_QUEUE_RESULT",
    "EVENT_GROUP_UPDATE",
    "EVENT_GROUP_MEMBER_JOINED",
}

local BG_TYPE_NAMES = {
    "LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION",
    "LFG_ACTIVITY_BATTLE_GROUND_CHAMPION",
    "LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL",
}

------------------------------------------------------------------------------
-- Text (Japanese client first; English otherwise)
------------------------------------------------------------------------------
local STRINGS = {
    ja = {
        title        = "MatchMonitor",
        previewNote  = "【位置調整プレビュー】サンプル表示です（実際の情報ではありません）",
        boot         = "MatchMonitor：起動しました（申請中に自動表示されます）",
        titleDungeon = "ダンジョン検索",
        titleBG      = "バトルグラウンド",
        titleOther   = "マッチング",
        state        = "状態：",
        st_queued    = "順番待ち",
        st_ready     = "成立（準備確認）",
        st_progress  = "参加中",
        st_forming   = "グループ結成中",
        st_checking  = "確認中…",
        st_ended     = "終了（キャンセルまたは不成立）",
        st_other     = "状態コード %s",
        kind_random_normal   = "ランダム・ノーマル",
        kind_random_veteran  = "ランダム・ベテラン",
        kind_single_normal   = "個別・ノーマル",
        kind_single_veteran  = "個別・ベテラン",
        kind_multi_normal    = "複数選択・ノーマル",
        kind_multi_veteran   = "複数選択・ベテラン",
        kind_unsupported     = "未対応の種別",
        dest_multi   = "%d件選択",
        group        = "グループ：タンク%d / ヒーラー%d / DPS%d",
        sampleKind   = "ランダム・ノーマル",
        sampleState  = "状態：（サンプル）",
        setHeader    = "表示位置",
        setDesc      = "スライダーで表示位置を変更します（0＝左端/上端、100＝右端/下端）。変更中は位置確認用のサンプルを表示します。",
        setX         = "横位置",
        setY         = "縦位置",
        setReset     = "初期位置に戻す",
        setXTip      = "パネルの横位置です。0で左端、100で右端です。",
        setYTip      = "パネルの縦位置です。0で上端、100で下端です。",
        setResetTip  = "横位置・縦位置を初期値に戻します。",
        panelName    = { main = "メインパネル" },
    },
    en = {
        title        = "MatchMonitor",
        previewNote  = "[Position preview] Sample display (not real information)",
        boot         = "MatchMonitor: started (shown automatically while queued)",
        titleDungeon = "Dungeon Finder",
        titleBG      = "Battleground",
        titleOther   = "Matchmaking",
        state        = "Status: ",
        st_queued    = "In queue",
        st_ready     = "Match found (ready check)",
        st_progress  = "In progress",
        st_forming   = "Forming group",
        st_checking  = "Checking...",
        st_ended     = "Ended (cancelled or not formed)",
        st_other     = "Status code %s",
        kind_random_normal   = "Random Normal",
        kind_random_veteran  = "Random Veteran",
        kind_single_normal   = "Specific Normal",
        kind_single_veteran  = "Specific Veteran",
        kind_multi_normal    = "Multiple Normal",
        kind_multi_veteran   = "Multiple Veteran",
        kind_unsupported     = "Unsupported type",
        dest_multi   = "%d selected",
        group        = "Group: Tank %d / Heal %d / DPS %d",
        sampleKind   = "Random Normal",
        sampleState  = "Status: (sample)",
        setHeader    = "Display position",
        setDesc      = "Move the panel with the sliders (0 = left/top, 100 = right/bottom). A sample is shown while you adjust.",
        setX         = "Horizontal position",
        setY         = "Vertical position",
        setReset     = "Reset to default position",
        setXTip      = "Horizontal position. 0 = left edge, 100 = right edge.",
        setYTip      = "Vertical position. 0 = top edge, 100 = bottom edge.",
        setResetTip  = "Restores the default horizontal and vertical position.",
        panelName    = { main = "Main panel" },
    },
}

local function detectLang()
    local f = rawget(_G, "GetCVar")
    if type(f) == "function" then
        local ok, v = pcall(f, "language.2")
        if ok and type(v) == "string" and v ~= "" then
            if v == "ja" then return "ja" end
            return "en"
        end
    end
    return "ja"
end

local T = STRINGS.ja
MM.T = T

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------
local sv
local C = {}                  -- resolved constants
local roles = {}              -- [unitTag] = role (EVENT_GROUP_MEMBER_ROLE_CHANGED)
local lastReq = nil           -- classified request, kept until the queue is over
local lastStatus = nil
local inHud = true            -- fail-open: unknown scene counts as HUD
local refreshPending = false
local hideToken, endToken = 0, 0
local inProgHidden = false
local bootUntil, previewUntil = 0, 0
local pendingUntil, endUntil = 0, 0
local requestRefresh, refreshNow   -- forward declarations

MM.lastErr = nil

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function nowMs()
    local f = rawget(_G, "GetGameTimeMilliseconds")
    if type(f) == "function" then return f() end
    return 0
end

local function getFn(name)
    local f = rawget(_G, name)
    if type(f) == "function" then return f end
    return nil
end

local function constNum(name, fallback)
    local v = rawget(_G, name)
    if type(v) == "number" then return v end
    return fallback
end

-- Fallback numbers = values observed on PS5 with the diagnostic add-on
-- (status 0/1/2/4, activity type 0/2/3/7). Used only if the constant is missing.
local function resolveConstants()
    C.NONE        = constNum("ACTIVITY_FINDER_STATUS_NONE", 0)
    C.QUEUED      = constNum("ACTIVITY_FINDER_STATUS_QUEUED", 1)
    C.IN_PROGRESS = constNum("ACTIVITY_FINDER_STATUS_IN_PROGRESS", 2)
    C.READY_CHECK = constNum("ACTIVITY_FINDER_STATUS_READY_CHECK", 4)
    C.FORMING     = constNum("ACTIVITY_FINDER_STATUS_FORMING_GROUP", nil)
    C.T_INVALID   = constNum("LFG_ACTIVITY_INVALID", 0)
    C.T_DUNGEON   = constNum("LFG_ACTIVITY_DUNGEON", 2)
    C.T_MASTER    = constNum("LFG_ACTIVITY_MASTER_DUNGEON", 3)
    C.BG = {}
    for _, n in ipairs(BG_TYPE_NAMES) do
        local v = rawget(_G, n)
        if type(v) == "number" then C.BG[v] = true end
    end
    if next(C.BG) == nil then C.BG[7] = true end
    -- Roles: only the named constants are trusted (no hard-coded fallback).
    C.R_DPS  = constNum("LFG_ROLE_DPS", nil)
    C.R_TANK = constNum("LFG_ROLE_TANK", nil)
    C.R_HEAL = constNum("LFG_ROLE_HEAL", nil)
end

local function validPct(v)
    return type(v) == "number" and v == v and v >= 0 and v <= 100
end

local function clampPct(v, fallback)
    if type(v) ~= "number" or v ~= v then return fallback end
    if v < 0 then v = 0 elseif v > 100 then v = 100 end
    return math.floor(v + 0.5)
end

------------------------------------------------------------------------------
-- Request classification (own queue only)
------------------------------------------------------------------------------
-- Rules (PS5 observations, see README):
--   dungeon type 2 = normal, type 3 (MASTER_DUNGEON) = veteran, BG type = battleground
--   numReq == 1                    -> single dungeon (name from GetActivityInfo)
--   numReq > 1 + placeholder id    -> RANDOM (placeholder = id whose type is INVALID)
--   numReq > 1, no placeholder     -> several dungeons selected (never observed yet)
local function scanRequests(numReq)
    local fIds  = getFn("GetActivityRequestIds")
    local fType = getFn("GetActivityType")
    local fInfo = getFn("GetActivityInfo")
    if not (fIds and fType) then return nil end

    local nDungeon, nMaster, nBG, nOther = 0, 0, 0, 0
    local placeholder = false
    local name = nil
    local cap = math.min(numReq, REQUEST_SCAN_CAP)
    for i = 1, cap do
        local okI, id = pcall(fIds, i)
        if okI and type(id) == "number" and id ~= 0 then
            local okT, t = pcall(fType, id)
            if okT and type(t) == "number" then
                if t == C.T_DUNGEON then
                    nDungeon = nDungeon + 1
                elseif t == C.T_MASTER then
                    nMaster = nMaster + 1
                elseif C.BG[t] then
                    nBG = nBG + 1
                elseif t == C.T_INVALID then
                    placeholder = true
                else
                    nOther = nOther + 1
                end
                if (t == C.T_DUNGEON or t == C.T_MASTER) and name == nil and fInfo then
                    local okN, nm = pcall(fInfo, id)
                    if okN and type(nm) == "string" and nm ~= "" then name = nm end
                end
            end
        end
    end

    local res = { entries = numReq, name = name, section = "OTHER" }
    local veteran = nil
    if nBG > 0 and nDungeon == 0 and nMaster == 0 and nOther == 0 then
        res.section = "BG"
    elseif nMaster > 0 and nDungeon == 0 and nBG == 0 and nOther == 0 then
        veteran = true
    elseif nDungeon > 0 and nMaster == 0 and nBG == 0 and nOther == 0 then
        veteran = false
    end
    if veteran ~= nil then
        res.section = "DUNGEON"
        res.veteran = veteran
        if numReq == 1 then
            res.mode = "SINGLE"
        elseif placeholder then
            res.mode = "RANDOM"
        else
            res.mode = "MULTI"
        end
    end
    return res
end

local function kindLabel(r)
    local side = "normal"
    if r.veteran then side = "veteran" end
    local key = "kind_" .. string.lower(r.mode or "x") .. "_" .. side
    local mapped = {
        kind_random_normal = T.kind_random_normal, kind_random_veteran = T.kind_random_veteran,
        kind_single_normal = T.kind_single_normal, kind_single_veteran = T.kind_single_veteran,
        kind_multi_normal  = T.kind_multi_normal,  kind_multi_veteran  = T.kind_multi_veteran,
    }
    return mapped[key] or T.kind_unsupported
end

local function destLabel(r)
    if r.mode == "SINGLE" then
        return r.name                     -- nil when the name could not be read -> no line
    elseif r.mode == "MULTI" then
        return string.format(T.dest_multi, r.entries)
    end
    return nil                            -- random: no destination line
end

------------------------------------------------------------------------------
-- Group roles (own group only; from the verified role-changed event)
------------------------------------------------------------------------------
local function clearRoles()
    for k in pairs(roles) do roles[k] = nil end
end

local function groupLine()
    if C.R_TANK == nil and C.R_HEAL == nil and C.R_DPS == nil then return nil end
    local tank, heal, dps, total = 0, 0, 0, 0
    for _, r in pairs(roles) do
        if r ~= nil and r == C.R_TANK then
            tank = tank + 1; total = total + 1
        elseif r ~= nil and r == C.R_HEAL then
            heal = heal + 1; total = total + 1
        elseif r ~= nil and r == C.R_DPS then
            dps = dps + 1; total = total + 1
        end
    end
    if total == 0 then return nil end
    return string.format(T.group, tank, heal, dps)
end

------------------------------------------------------------------------------
-- Panels (UI) and position
------------------------------------------------------------------------------
local function applyPosition(id)
    local P = PANELS[id]
    if not P or not P.win or not sv then return end
    local p = sv.panels[id]
    local rootW, rootH = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local maxX = math.max(0, rootW - P.w)
    local maxY = math.max(0, rootH - P.h)
    local x = math.floor(maxX * clampPct(p.x, 0) / 100 + 0.5)
    local y = math.floor(maxY * clampPct(p.y, 0) / 100 + 0.5)
    P.win:ClearAnchors()
    P.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

local function setFont(ctrl, names)
    for _, n in ipairs(names) do
        local ok = pcall(function() ctrl:SetFont(n) end)
        if ok then return end
    end
end

-- Text-only panel: a window (full alpha, nothing drawn) holding four black text
-- copies (outline) and one white text label on top. No background control.
local function buildPanel(id)
    local wm = WINDOW_MANAGER
    local P = PANELS[id]
    local win = wm:CreateTopLevelWindow("MatchMonitor_" .. id .. "_Window")
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetHidden(true)
    P.w, P.h = 10, 10
    win:SetDimensions(P.w, P.h)

    P.shadows = {}
    for i, o in ipairs(OUTLINE) do
        local sh = wm:CreateControl("MatchMonitor_" .. id .. "_Outline" .. i, win, CT_LABEL)
        sh:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + o[1], PAD + o[2])
        sh:SetColor(0, 0, 0, 0.7)
        setFont(sh, FONT_CHAIN)
        P.shadows[i] = sh
    end

    local body = wm:CreateControl("MatchMonitor_" .. id .. "_Body", win, CT_LABEL)
    body:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, PAD)
    body:SetColor(1, 1, 1, 1)
    setFont(body, FONT_CHAIN)

    P.win, P.body = win, body
end

-- Size estimate used only when the label cannot report its text size.
local function estimateSize(plain)
    local maxW, n = 0, 0
    for line in string.gmatch(plain .. "\n", "(.-)\n") do
        n = n + 1
        local w = 0
        for i = 1, #line do
            local b = string.byte(line, i)
            if b < 128 then
                w = w + ASCII_W_EST
            elseif b >= 192 then
                w = w + WIDE_W_EST
            end
        end
        if w > maxW then maxW = w end
    end
    return maxW, n * LINE_H_EST
end

local function measureText(ctrl, plain)
    local ok, w, h = pcall(function() return ctrl:GetTextDimensions() end)
    if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
        return w, h
    end
    return estimateSize(plain)
end

-- plainLines: text without colour codes (outline copies); coloredLines: same text, state line coloured.
local function applyPanel(id, show, plainLines, coloredLines)
    local P = PANELS[id]
    if not P or not P.win then return end
    if show and plainLines and #plainLines > 0 then
        local plain = table.concat(plainLines, "\n")
        local colored = table.concat(coloredLines or plainLines, "\n")
        P.body:SetDimensions(MAX_TEXT_W, 400)
        P.body:SetText(colored)
        local tw, th = measureText(P.body, plain)
        tw = math.min(math.ceil(tw) + 4, MAX_TEXT_W)     -- width follows the content
        th = math.ceil(th) + 2
        P.body:SetDimensions(tw, th)
        for _, sh in ipairs(P.shadows) do
            sh:SetDimensions(tw, th)
            sh:SetText(plain)
        end
        P.w, P.h = tw + PAD * 2 + 2, th + PAD * 2 + 2
        P.win:SetDimensions(P.w, P.h)
        applyPosition(id)
    end
    P.win:SetHidden(not show)
end

-- Position API (used by the settings screen) ---------------------------------
function MM.GetPos(id)
    if not sv or not sv.panels[id] then return nil, nil end
    local p = sv.panels[id]
    return p.x, p.y
end

function MM.PreviewShow(ms)
    previewUntil = nowMs() + (ms or PREVIEW_MS)
    if refreshNow then refreshNow() else requestRefresh() end   -- immediate: slider changes show at once
    zo_callLater(requestRefresh, (ms or PREVIEW_MS) + 150)
end

function MM.PreviewEnd()
    previewUntil = 0
    if refreshNow then refreshNow() else requestRefresh() end
end

function MM.SetPos(id, x, y)
    if not sv or not PANELS[id] then return end
    local p = sv.panels[id]
    if x ~= nil then p.x = clampPct(x, p.x) end
    if y ~= nil then p.y = clampPct(y, p.y) end
    applyPosition(id)
    MM.PreviewShow(PREVIEW_MS)
end

function MM.ResetPos(id)
    local P = PANELS[id]
    if not sv or not P then return end
    local p = sv.panels[id]
    p.x, p.y = P.defaults.x, P.defaults.y
    applyPosition(id)
    MM.PreviewShow(PREVIEW_MS)
end

local function sanitizeSavedVars()
    if type(sv.panels) ~= "table" then sv.panels = {} end
    for _, id in ipairs(PANEL_ORDER) do
        local def = PANELS[id].defaults
        local p = sv.panels[id]
        if type(p) ~= "table" then
            p = {}
            sv.panels[id] = p
        end
        if validPct(p.x) then p.x = math.floor(p.x + 0.5) else p.x = def.x end
        if validPct(p.y) then p.y = math.floor(p.y + 0.5) else p.y = def.y end
    end
end

------------------------------------------------------------------------------
-- Scene watching: stay out of the way of menus (fail-open if unknown)
------------------------------------------------------------------------------
local function isHudScene(name)
    return name == "hud" or name == "hudui"
end

local function setupSceneWatch()
    local sm = rawget(_G, "SCENE_MANAGER")
    if type(sm) ~= "table" then return end
    pcall(function()
        sm:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
            local showing = rawget(_G, "SCENE_SHOWING")
            local shown = rawget(_G, "SCENE_SHOWN")
            if (showing ~= nil and newState == showing) or (shown ~= nil and newState == shown) then
                local name = nil
                if type(scene) == "table" and scene.GetName then name = scene:GetName() end
                if type(name) == "string" then inHud = isHudScene(name) end
                requestRefresh()
            end
        end)
    end)
    pcall(function()
        local cur = sm:GetCurrentScene()
        if type(cur) == "table" and cur.GetName then
            local name = cur:GetName()
            if type(name) == "string" then inHud = isHudScene(name) end
        end
    end)
end

------------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------------
local function stateText(status)
    if status == C.QUEUED then return T.st_queued end
    if status == C.READY_CHECK then return T.st_ready end
    if status == C.IN_PROGRESS then return T.st_progress end
    if C.FORMING ~= nil and status == C.FORMING then return T.st_forming end
    return string.format(T.st_other, tostring(status))
end

local function colorize(hex, text)
    return "|c" .. hex .. text .. "|r"
end

-- Returns plain lines and coloured lines (only the state value is coloured).
-- A line is only added when its data exists.
local function buildActiveLines(stateLabel, stateColor, status)
    local plain, colored = {}, {}
    local function add(p, c)
        plain[#plain + 1] = p
        colored[#colored + 1] = c or p
    end
    local r = lastReq
    if r and r.section == "BG" then
        add(T.titleBG)
    elseif r and r.section == "DUNGEON" then
        add(T.titleDungeon)
        add(kindLabel(r))
        local d = destLabel(r)
        if d then add(d) end
    else
        add(T.titleOther)
        if r then add(T.kind_unsupported) end
    end
    add(T.state .. stateLabel, T.state .. colorize(stateColor, stateLabel))
    if status == C.IN_PROGRESS or status == C.READY_CHECK then
        local g = groupLine()
        if g then add(g) end
    end
    return plain, colored
end

local function previewLines()
    return { T.previewNote, T.titleDungeon, T.sampleKind, T.sampleState }
end

------------------------------------------------------------------------------
-- Refresh (event driven, debounced)
------------------------------------------------------------------------------
local function armInProgressHide()
    hideToken = hideToken + 1
    inProgHidden = false
    local tok = hideToken
    zo_callLater(function()
        if tok == hideToken and lastStatus == C.IN_PROGRESS then
            inProgHidden = true
            requestRefresh()
        end
    end, IN_PROGRESS_HIDE_MS)
end

local function startPending()
    endToken = endToken + 1
    local tok = endToken
    local grace = GRACE_DUNGEON_MS
    if lastReq and lastReq.section == "BG" then grace = GRACE_BG_MS end
    pendingUntil = nowMs() + grace
    endUntil = 0
    zo_callLater(function()
        if tok ~= endToken then return end
        if lastStatus == C.NONE then
            pendingUntil = 0
            endUntil = nowMs() + END_SHOW_MS
            requestRefresh()
            zo_callLater(requestRefresh, END_SHOW_MS + 150)
        end
    end, grace)
end

local function onStatusChanged(prev, cur)
    hideToken = hideToken + 1
    inProgHidden = false
    if cur == C.QUEUED then
        endToken = endToken + 1
        pendingUntil, endUntil = 0, 0
        lastReq = nil
        clearRoles()
    elseif cur == C.IN_PROGRESS then
        endToken = endToken + 1
        pendingUntil, endUntil = 0, 0
        armInProgressHide()
    elseif cur == C.NONE then
        local wasActive = (prev == C.QUEUED or prev == C.READY_CHECK
            or (C.FORMING ~= nil and prev == C.FORMING))
        if wasActive then startPending() end
    end
end

local function doRefresh()
    local t = nowMs()
    local previewing = t < previewUntil

    local status = nil
    local fStatus = getFn("GetActivityFinderStatus")
    if fStatus then
        local ok, v = pcall(fStatus)
        if ok and type(v) == "number" then status = v end
    end

    if status ~= nil and lastStatus ~= status then
        local prev = lastStatus
        lastStatus = status
        onStatusChanged(prev, status)
    end

    -- Classify the request only while it is needed (queued / ready check) and visible-capable.
    if status ~= nil and (status == C.QUEUED or status == C.READY_CHECK) and (inHud or previewing) then
        local numReq = 0
        local fNum = getFn("GetNumActivityRequests")
        if fNum then
            local ok, v = pcall(fNum)
            if ok and type(v) == "number" then numReq = v end
        end
        if numReq > 0 and (lastReq == nil or lastReq.entries ~= numReq) then
            local res = scanRequests(numReq)
            if res then lastReq = res end
        end
    end

    local view = nil
    if status ~= nil then
        if status == C.NONE then
            if pendingUntil ~= 0 and t <= pendingUntil + 1000 then
                view = "pending"   -- the grace timer clears pendingUntil; +1000 only guards a lost timer
            elseif endUntil > t then
                view = "ended"
            else
                lastReq = nil
            end
        elseif status == C.IN_PROGRESS then
            if not inProgHidden then view = "active" end
        else
            view = "active"
        end
    end
    if view == nil and t < bootUntil then view = "boot" end

    local show = previewing or (inHud and view ~= nil)
    local plainLines, coloredLines = nil, nil
    if previewing then
        plainLines = previewLines()
    elseif view == "boot" then
        plainLines = { T.boot }
    elseif view ~= nil then
        local label, color
        if view == "pending" then
            label, color = T.st_checking, COLORS.muted
        elseif view == "ended" then
            label, color = T.st_ended, COLORS.muted
        else
            label = stateText(status)
            if status == C.QUEUED or (C.FORMING ~= nil and status == C.FORMING) then
                color = COLORS.queued
            elseif status == C.READY_CHECK or status == C.IN_PROGRESS then
                color = COLORS.good
            else
                color = COLORS.plain
            end
        end
        plainLines, coloredLines = buildActiveLines(label, color, status)
    end
    for _, id in ipairs(PANEL_ORDER) do
        applyPanel(id, show, plainLines, coloredLines)
    end
end

local function refresh()
    local ok, err = pcall(doRefresh)
    if not ok then
        MM.lastErr = string.sub(tostring(err), 1, 80)
        pcall(applyPanel, "main", true, { T.title .. "  ERROR", MM.lastErr })
    end
end

refreshNow = refresh

requestRefresh = function()
    if refreshPending then return end
    refreshPending = true
    zo_callLater(function()
        refreshPending = false
        refresh()
    end, DEBOUNCE_MS)
end

------------------------------------------------------------------------------
-- Initialisation
------------------------------------------------------------------------------
local function onPlayerActivated()
    bootUntil = nowMs() + BOOT_SHOW_MS
    requestRefresh()
    zo_callLater(requestRefresh, BOOT_SHOW_MS + 150)
end

local function onAddOnLoaded(_, addonName)
    if addonName ~= MM.name then return end
    EVENT_MANAGER:UnregisterForEvent(MM.name, EVENT_ADD_ON_LOADED)

    local lang = detectLang()
    T = STRINGS[lang] or STRINGS.ja
    MM.T = T

    local defaults = { panels = {} }
    for _, id in ipairs(PANEL_ORDER) do
        defaults.panels[id] = { x = PANELS[id].defaults.x, y = PANELS[id].defaults.y }
    end
    sv = ZO_SavedVars:NewAccountWide("MatchMonitor_SV", MM.SV_VERSION, nil, defaults)
    MM.sv = sv
    sanitizeSavedVars()
    resolveConstants()

    for _, id in ipairs(PANEL_ORDER) do
        local ok, err = pcall(buildPanel, id)
        if not ok then MM.lastErr = string.sub(tostring(err), 1, 80) end
    end

    for _, n in ipairs(EVENT_NAMES) do
        local v = rawget(_G, n)
        if type(v) == "number" then
            EVENT_MANAGER:RegisterForEvent(MM.name .. "_" .. n, v, function()
                requestRefresh()
            end)
        end
    end

    local roleEvent = rawget(_G, "EVENT_GROUP_MEMBER_ROLE_CHANGED")
    if type(roleEvent) == "number" then
        EVENT_MANAGER:RegisterForEvent(MM.name .. "_RoleChanged", roleEvent, function(_, unitTag, role)
            if type(unitTag) == "string" and type(role) == "number" then
                roles[unitTag] = role
            end
            requestRefresh()
        end)
    end

    local leftEvent = rawget(_G, "EVENT_GROUP_MEMBER_LEFT")
    if type(leftEvent) == "number" then
        EVENT_MANAGER:RegisterForEvent(MM.name .. "_LeftClear", leftEvent, function()
            clearRoles()
            requestRefresh()
        end)
    end

    setupSceneWatch()
    EVENT_MANAGER:RegisterForEvent(MM.name .. "_Activated", EVENT_PLAYER_ACTIVATED, onPlayerActivated)

    -- Settings screen (LibAddonMenu-2.0, optional). A failure here must never stop the add-on.
    if type(MM.RegisterSettings) == "function" then
        local ok, err = pcall(MM.RegisterSettings)
        if not ok then MM.lastErr = string.sub(tostring(err), 1, 80) end
    end
end

EVENT_MANAGER:RegisterForEvent(MM.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)
